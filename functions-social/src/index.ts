// index.ts — Cloud Functions de identidade publica e grafo social.
//
// A MESMA REPARTICAO DE PAPEIS DOS OUTROS CODEBASES:
//
//   QUEM DECIDE  -> o dominio Dart (app/lib/social/), via domain.ts. O que e
//                   apelido valido, quem pode aceitar, quando o limite estoura,
//                   que acoes a tela pode oferecer.
//   QUEM EXECUTA -> repositorio.ts. Transacao, leitura e escrita.
//   QUEM ATENDE  -> este arquivo. Autenticacao, forma do payload e traducao de
//                   recusa em erro.
//
// Se um `if` de politica social aparecer aqui, ele esta no lugar errado.
//
// DUAS COISAS QUE O CLIENTE NUNCA ESCOLHE, e que por isso jamais sao lidas do
// payload: o UID de quem chama (vem de `req.auth`) e o instante (vem do
// servidor). Aceitar qualquer um dos dois deixaria uma pessoa pedir amizade em
// nome de outra, ou datar uma solicitacao para tras.
//
// O CLIENTE SO FALA EM `publicId` (§13, §21, §31-D). Nenhuma funcao aqui aceita
// UID de terceiro no payload, e nenhuma devolve UID em resposta nenhuma — a
// trava de `exigirRespostaSegura` transforma um vazamento acidental em erro.

import { initializeApp } from "firebase-admin/app";
import { Timestamp } from "firebase-admin/firestore";
import { logger } from "firebase-functions";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { CallableRequest, HttpsError, onCall } from "firebase-functions/v2/https";
import { createHash } from "node:crypto";

import {
  C_AMIZADES,
  C_PERFIS_PUBLICOS,
  C_USUARIOS,
  entradaDeBusca,
  entradaPublica,
  exigirRespostaSegura,
} from "./chaves";
import {
  CandidatoDeBusca,
  LIMITES,
  VereditoAmizade,
  agoraUtc,
  dominio,
} from "./domain";
import {
  desfazerPorBloqueio,
  db,
  estadoDeContato,
  exigirDocumentoPublicoLimpo,
  garantirIdentidade,
  lerPerfilPublico,
  lerPerfisPublicos,
  operarRelacao,
  paginaDeAmigos,
  paginaDeSolicitacoes,
  propagarApelidoParaAmigos,
  publicIdDe,
  reconciliarProjecoes,
  relacoesParaBusca,
  resolverUid,
  varrerVisiveis,
} from "./repositorio";

initializeApp();

/// App Check EXIGIDO em producao, dispensado sob o emulador.
///
/// `FUNCTIONS_EMULATOR` e posto pelo proprio emulador e nunca vale "true" numa
/// instancia implantada — nao ha caminho pelo qual um cliente real desligue esta
/// verificacao, porque ela nao le nada que venha do pedido. Mesma decisao, pelo
/// mesmo motivo, que `functions-moderacao/src/index.ts`.
const exigirAppCheck = process.env.FUNCTIONS_EMULATOR !== "true";

const opcoesCliente = {
  enforceAppCheck: exigirAppCheck,
  region: "southamerica-east1",
};

// --------------------------------------------------------------- autenticacao

function exigirAutenticacao(req: CallableRequest): string {
  const uid = req.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "E preciso estar autenticado.");
  }
  return uid;
}

function exigirAdmin(req: CallableRequest): string {
  const uid = exigirAutenticacao(req);
  if (req.auth?.token?.admin !== true) {
    throw new HttpsError("permission-denied", "Operacao restrita a administracao.");
  }
  return uid;
}

/// O apelido sugerido no primeiro acesso vem do TOKEN, nunca do payload.
///
/// `req.auth.token.name` e o `displayName` que o provedor de identidade (Google,
/// por exemplo) atestou. Ler o apelido inicial do payload deixaria o cliente
/// escolher o proprio nome antes de qualquer validacao ter rodado — o que, alias,
/// ele PODE fazer depois, por `atualizarPerfilPublico`, que valida.
function apelidoDoToken(req: CallableRequest): string {
  const nome = req.auth?.token?.name;
  return typeof nome === "string" ? nome : "";
}

// ------------------------------------------------------------------- recusas

/// Traduz um codigo do dominio numa `HttpsError`.
///
/// O codigo vai em `details.recusa` porque o cliente precisa distinguir
/// "ja sao amigos" de "limite atingido" para escrever a mensagem certa na tela —
/// e §35 proibe que ele dependa do TEXTO. O texto e para o log humano.
function recusar(recusa: string | null): never {
  const naoEncontrado =
    recusa === "identidadeNaoEncontrada" ||
    recusa === "perfilPublicoNaoDisponivel" ||
    recusa === "perfilPublicoInvalido";

  // Recusas de FORMA do pedido de busca. `invalid-argument`, e nao
  // `failed-precondition`: o servidor nao esta num estado que impede a
  // operacao — o pedido e que nao tem forma de pedido. A distincao importa para
  // o cliente saber se vale a pena tentar de novo com o mesmo texto (nao vale).
  const pedidoMalformado =
    recusa === "consultaInvalida" ||
    recusa === "consultaMuitoCurta" ||
    recusa === "consultaMuitoLonga";

  throw new HttpsError(
    naoEncontrado
      ? "not-found"
      : pedidoMalformado
        ? "invalid-argument"
        : "failed-precondition",
    recusa ?? "pedido recusado",
    { recusa }
  );
}

/// Resolve o `publicId` que veio do cliente para um UID interno.
///
/// TODA rota social passa por aqui. E o unico ponto do sistema que faz
/// `publicId -> uid`, e §31-D exige que ele seja exatamente isso: interno ao
/// backend, invisivel para Ranking, Hall e cliente.
///
/// A resposta para "id malformado" e para "id que nao existe" e a MESMA
/// (`not-found`), de proposito: diferencia-las daria um oraculo de quais ids ja
/// foram cunhados, que e meia enumeracao de graca.
async function exigirUidDoPublicId(bruto: unknown): Promise<string> {
  if (typeof bruto !== "string") {
    throw new HttpsError("invalid-argument", "publicId e obrigatorio.");
  }
  const normalizado = dominio.normalizarIdPublico(bruto).publicId;
  if (!normalizado) recusar("perfilPublicoInvalido");
  const uid = await resolverUid(normalizado);
  if (!uid) recusar("perfilPublicoNaoDisponivel");
  return uid;
}

// ===========================================================================
// IDENTIDADE E PERFIL PROPRIO (§10, §11, §31-E)
// ===========================================================================

/// Obtem — criando na primeira vez — a identidade publica de quem chama (§10).
///
/// IDEMPOTENTE: duas chamadas simultaneas nao criam duas identidades. Ver
/// `garantirIdentidade`.
///
/// §31-E: a resposta do PROPRIO perfil carrega o que a tela de edicao precisa
/// (os limites de apelido, se o avatar tem catalogo), e esses campos NAO existem
/// na resposta publica destinada a terceiros — sao respostas de funcoes
/// diferentes, montadas de fontes diferentes, e nao um documento so com recorte.
export const obterMinhaIdentidade = onCall(opcoesCliente, async (req) => {
  const uid = exigirAutenticacao(req);
  const { publicId, criada } = await garantirIdentidade(uid, apelidoDoToken(req));
  const perfil = await lerPerfilPublico(publicId);

  return exigirRespostaSegura({
    publicId,
    criada,
    perfil: entradaPublica(perfil, publicId, null),
    estado: typeof perfil?.estado === "string" ? perfil.estado : "ativo",
    // Metadados de EDICAO. Sao do dono e so viajam nesta funcao.
    edicao: {
      apelidoMinimo: LIMITES.apelidoMinimo,
      apelidoMaximo: LIMITES.apelidoMaximo,
      // Catalogo vazio hoje: nao ha fonte canonica de avatar nesta arvore. §8
      // manda tratar a ausencia, e o contrato registra a pendencia.
      catalogoDeAvatarDisponivel: false,
    },
    limites: {
      amigos: LIMITES.limiteAmigos,
      solicitacoesEnviadas: LIMITES.limiteSolicitacoesEnviadas,
      paginaMaxima: LIMITES.paginaMaxima,
    },
  });
});

/// Altera apelido e/ou avatar (§11).
///
/// A ALTERACAO PASSA PELA AUTORIDADE, e nao pelo cliente escrevendo direto em
/// `publicProfiles`, por duas razoes que as Rules nao cobririam: a normalizacao
/// do apelido (que produz `apelidoOrdenacao`) e o leque para as projecoes dos
/// amigos. Uma regra do Firestore nao normaliza texto nem escreve em 200
/// documentos.
///
/// O cliente NAO pode alterar `publicId`, `criadoEm` nem `esquema`: o mapa de
/// campos vem do dominio e simplesmente nao os produz.
export const atualizarPerfilPublico = onCall(opcoesCliente, async (req) => {
  const uid = exigirAutenticacao(req);
  const { apelido, avatarRef, removerAvatar } = (req.data ?? {}) as Record<
    string,
    unknown
  >;

  const publicId = await publicIdDe(uid);
  if (!publicId) recusar("identidadeNaoEncontrada");

  const veredito = dominio.avaliarAtualizacaoDeApresentacao({
    apelido: typeof apelido === "string" ? apelido : null,
    avatarRef,
    removerAvatar: removerAvatar === true,
    agora: agoraUtc(),
  });
  if (!veredito.aceita || !veredito.campos) recusar(veredito.recusa);

  const campos = veredito.campos;
  exigirDocumentoPublicoLimpo(campos);
  await db().collection(C_PERFIS_PUBLICOS).doc(publicId).set(campos, {
    merge: true,
  });

  // O leque de §22: so a CHAVE DE ORDENACAO das projecoes. O apelido exibido
  // continua vindo de `publicProfiles`, entao esta propagacao nunca e o que faz
  // o nome novo aparecer — §31-I ja vale sem ela.
  let projecoes = 0;
  if (typeof campos.apelidoOrdenacao === "string") {
    projecoes = await propagarApelidoParaAmigos(uid, campos.apelidoOrdenacao);
  }

  return exigirRespostaSegura({
    atualizado: true,
    publicId,
    projecoesAtualizadas: projecoes,
  });
});

// ===========================================================================
// VER PERFIL (§31-A a §31-J)
// ===========================================================================

/// Abre o perfil publico de outro jogador — ou o proprio — por `publicId`.
///
/// A PORTA UNICA de §31-C: Ranking, Hall, lista de amigos, solicitacoes,
/// participantes de mesa e o proprio Perfil chamam ESTA funcao. Nao ha um
/// endpoint de perfil por tela.
///
/// UID NAO E NECESSARIO NO CLIENTE e nao aparece na resposta (§31-D e §31-F).
export const verPerfilPublico = onCall(opcoesCliente, async (req) => {
  const uid = exigirAutenticacao(req);
  const { publicId } = (req.data ?? {}) as Record<string, unknown>;

  const normalizado =
    typeof publicId === "string"
      ? dominio.normalizarIdPublico(publicId).publicId
      : null;
  if (!normalizado) recusar("perfilPublicoInvalido");

  const perfil = await lerPerfilPublico(normalizado);
  const recusaDeLeitura = dominio.recusaDeConsultaPublica({
    publicId: normalizado,
    existe: perfil !== undefined,
    estado: typeof perfil?.estado === "string" ? perfil.estado : null,
  }).recusa;
  if (recusaDeLeitura) {
    // §31-G: conta removida e conta inexistente respondem igual. O log guarda a
    // diferenca; a resposta nao.
    logger.info("perfil publico indisponivel", { recusa: recusaDeLeitura });
    recusar("perfilPublicoNaoDisponivel");
  }

  const alvoUid = await resolverUid(normalizado);
  if (!alvoUid) recusar("perfilPublicoNaoDisponivel");

  // O proprio perfil: nao ha relacao a compor, e nao ha bloqueio de si mesmo.
  if (alvoUid === uid) {
    return exigirRespostaSegura({
      perfil: entradaPublica(perfil, normalizado, null),
      relacao: "euMesmo",
      acoes: ["editarPerfil"],
    });
  }

  const { pairKey } = dominio.chaveDoPar(uid, alvoUid);
  const [relDoc, contato] = await Promise.all([
    db().collection(C_AMIZADES).doc(pairKey).get(),
    estadoDeContato(uid, alvoUid),
  ]);

  const dadosRel = relDoc.exists
    ? (relDoc.data() as Record<string, unknown>)
    : undefined;
  const estado =
    dadosRel?.estado === "amigos" || dadosRel?.estado === "pendente"
      ? dadosRel.estado
      : "nenhuma";

  const vista = dominio.vistaDaRelacao({
    uidObservador: uid,
    uidAlvo: alvoUid,
    estado,
    solicitanteUid:
      typeof dadosRel?.solicitanteUid === "string" ? dadosRel.solicitanteUid : null,
    euBloqueeiOAlvo: contato.euBloqueeiOAlvo,
    contatoPermitido: contato.permitido,
  });

  return exigirRespostaSegura({
    perfil: entradaPublica(perfil, normalizado, null),
    relacao: vista.relacao,
    acoes: vista.acoes,
    // `amigosDesde` so viaja quando a relacao e de amizade: numa relacao
    // bloqueada ou inexistente ele nao existe, e inventa-lo daria informacao.
    amigosDesde:
      vista.relacao === "amigos" && typeof dadosRel?.amigosDesde === "string"
        ? dadosRel.amigosDesde
        : null,
  });
});

/// Localiza um jogador por identidade publica (§28 e §34).
///
/// Versao MAGRA de `verPerfilPublico`: devolve so a apresentacao, sem compor
/// relacao nem consultar bloqueio. E o que a tela de "adicionar por codigo" usa
/// para confirmar "e esta pessoa?" antes de enviar o pedido.
export const localizarJogadorPorIdentidade = onCall(
  opcoesCliente,
  async (req) => {
    exigirAutenticacao(req);
    const { publicId } = (req.data ?? {}) as Record<string, unknown>;

    const normalizado =
      typeof publicId === "string"
        ? dominio.normalizarIdPublico(publicId).publicId
        : null;
    if (!normalizado) recusar("perfilPublicoInvalido");

    const perfil = await lerPerfilPublico(normalizado);
    const recusaDeLeitura = dominio.recusaDeConsultaPublica({
      publicId: normalizado,
      existe: perfil !== undefined,
      estado: typeof perfil?.estado === "string" ? perfil.estado : null,
    }).recusa;
    if (recusaDeLeitura) recusar("perfilPublicoNaoDisponivel");

    return exigirRespostaSegura({
      perfil: entradaPublica(perfil, normalizado, null),
    });
  }
);

// ===========================================================================
// BUSCA POR APELIDO (OS de Busca e Descoberta Social)
// ===========================================================================

/// Procura jogadores pelo apelido publico.
///
/// POR QUE A BUSCA E UMA FUNCTION, e nao uma consulta do cliente ao Firestore
/// (§11): as Rules nao conseguem impor teto de resultados, nem exigir tamanho
/// minimo de termo, nem esconder de mim quem me bloqueou. Uma regra libera ou
/// nega a consulta inteira — e uma consulta liberada e o diretorio inteiro,
/// paginavel. Por isso o `list` de `publicProfiles` foi fechado ao cliente na
/// mesma OS que abriu esta porta: a leitura por ID continua publica (e o que
/// sustenta `Ranking -> publicId -> Ver Perfil`), a VARREDURA nao.
///
/// A CADEIA, e o que cada elo protege:
///
///   1. dominio valida o termo ............ minimo, maximo, controle, modo (§9)
///   2. faixa sobre `apelidoOrdenacao` .... campo derivado que ja existia (§4)
///   3. varredura ate `limite + 1` VISIVEIS. o bloqueado nao mexe em nada (§8)
///   4. `publicId -> uid` em lote ......... so aqui, e so no servidor (§3)
///   5. teto + `truncado`, sem cursor ..... a busca nao percorre a base (§9)
///   6. dominio projeta relacao e acoes ... estado social sanitizado (§10)
///   7. allowlist explicita na resposta ... defesa em profundidade (§7)
///   8. `exigirRespostaSegura` ............ a trava, de novo, sobre o todo (§3)
///
/// O ELO 3 E O QUE FAZ A §8 VALER ATE NO METADADO. Calcular `truncado` sobre o
/// lote bruto — que e o que uma consulta unica faria — deixaria um candidato
/// bloqueado dizer "havia mais" num resultado completo, e um bloqueado entre os
/// primeiros roubaria a vaga de um jogador legitimo. Para quem procura, o
/// bloqueado nao existe; e um inexistente nao altera contagem, ordem nem
/// metadado. Ver `varrerVisiveis`.
///
/// NAO EXISTE ROTA "LISTAR TODOS". Nao ha parametro que devolva a base, nao ha
/// termo vazio que case com tudo e nao ha curinga: `*` e `%` sao caracteres
/// comuns num apelido, e a faixa os compara literalmente.
export const buscarJogadoresPorApelido = onCall(opcoesCliente, async (req) => {
  const uid = exigirAutenticacao(req);
  const { termo, modo, limite } = (req.data ?? {}) as Record<string, unknown>;

  // O MESMO campo de busca aceita um `publicId` exato. A decisão de formato é
  // do domínio no servidor — o cliente não copia prefixo nem comprimento.
  // Bloqueio continua indistinguível de inexistência: um ID exato não vira
  // oráculo lateral só porque veio no lugar de um apelido.
  const idExato = typeof termo === "string"
    ? dominio.normalizarIdPublico(termo).publicId
    : null;
  if (idExato) {
    const [perfil, alvoUid] = await Promise.all([
      lerPerfilPublico(idExato),
      resolverUid(idExato),
    ]);
    if (!perfil || !alvoUid || perfil.estado !== "ativo") {
      return exigirRespostaSegura({ itens: [], truncado: false, modo: "exato" });
    }
    const contato = await estadoDeContato(uid, alvoUid);
    if (!contato.permitido) {
      return exigirRespostaSegura({ itens: [], truncado: false, modo: "exato" });
    }
    const relacoes = await relacoesParaBusca(uid, [alvoUid]);
    const rel = relacoes.get(alvoUid);
    const projetados = dominio.projetarResultadosDeBusca({
      uidObservador: uid,
      candidatos: [{
        publicId: idExato,
        uidAlvo: alvoUid,
        estado: rel?.estado ?? "nenhuma",
        solicitanteUid: rel?.solicitanteUid ?? null,
        euBloqueeiOAlvo: contato.euBloqueeiOAlvo,
        alvoMeBloqueou: false,
      }],
    });
    return exigirRespostaSegura({
      itens: projetados.itens.map((r) =>
        entradaDeBusca(perfil, r.publicId, r.relacao, r.acoes)
      ),
      truncado: false,
      modo: "exato",
    });
  }

  const consulta = dominio.avaliarConsultaDeBusca({ termo, modo, limite });
  if (!consulta.aceita) recusar(consulta.recusa);

  // A varredura ja resolve `publicId -> uid` e o bloqueio: os dois decidem QUEM
  // aparece, e por isso acontecem antes de qualquer decisao sobre a pagina.
  const pagina = await varrerVisiveis(
    uid,
    consulta.chaveInicio,
    consulta.chaveFim,
    consulta.modo === "exato",
    consulta.limite
  );

  // Nenhum candidato visivel: encerra sem gastar a leitura das relacoes.
  //
  // ESTE E O MESMO CAMINHO de tres situacoes diferentes — apelido inexistente,
  // todos os candidatos bloqueados, e candidatos com dado inconsistente — e a
  // resposta e identica nos tres. §8: a ausencia por bloqueio nao pode ser
  // distinguivel da ausencia por nao existir.
  //
  // E responde LISTA VAZIA, nao erro: §14 pede o caso, e um `not-found` aqui
  // contaria com um codigo o que a lista ja conta com um comprimento.
  if (pagina.candidatos.length === 0) {
    return exigirRespostaSegura({
      itens: [],
      truncado: pagina.truncado,
      modo: consulta.modo,
    });
  }

  // A relacao de amizade e lida SO PARA QUEM VAI APARECER. Ela decora o
  // resultado; ela nunca decide se ele existe.
  const relacoes = await relacoesParaBusca(uid, [
    ...pagina.uidPorPublicId.values(),
  ]);

  const candidatos: CandidatoDeBusca[] = pagina.candidatos.map((c) => {
    const alvoUid = pagina.uidPorPublicId.get(c.publicId) as string;
    const rel = relacoes.get(alvoUid);
    const bloqueio = pagina.bloqueios.get(c.publicId);
    return {
      publicId: c.publicId,
      uidAlvo: alvoUid,
      estado: rel?.estado ?? "nenhuma",
      solicitanteUid: rel?.solicitanteUid ?? null,
      euBloqueeiOAlvo: bloqueio?.euBloqueeiOAlvo === true,
      alvoMeBloqueou: bloqueio?.alvoMeBloqueou === true,
    };
  });

  const projetados = dominio.projetarResultadosDeBusca({
    uidObservador: uid,
    candidatos,
    observadorComChatSilenciado: pagina.sancao.chatSilenciado,
    observadorComRestricaoSocial: pagina.sancao.restricaoSocial,
  });

  const perfis = new Map(
    pagina.candidatos.map((c) => [c.publicId, c.perfil] as const)
  );

  return exigirRespostaSegura({
    itens: projetados.itens.map((r) =>
      entradaDeBusca(perfis.get(r.publicId), r.publicId, r.relacao, r.acoes)
    ),
    /// Havia mais VISIVEIS do que o teto. O cliente refina o termo — nao ha
    /// cursor, e a ausencia dele e a decisao antienumeracao de §9.
    truncado: pagina.truncado,
    modo: consulta.modo,
  });
});

// ===========================================================================
// GRAFO SOCIAL (§13 a §17)
// ===========================================================================

/// Resposta padrao de uma operacao sobre a relacao.
///
/// `repeticao: true` significa "o desfecho pedido ja valia" — e vai como SUCESSO,
/// nunca como erro. Devolver erro faria o cliente tentar de novo, e a proxima
/// tentativa tambem "falharia": um laco que so termina quando o jogador desiste.
/// Mesmo padrao de `jaRegistrada: true` na denuncia.
function respostaDaOperacao(veredito: VereditoAmizade, estadoFinal: string) {
  if (!veredito.aceita && !veredito.repeticao) recusar(veredito.recusa);
  return exigirRespostaSegura({
    ok: true,
    repeticao: veredito.repeticao,
    motivo: veredito.repeticao ? veredito.recusa : null,
    estado: estadoFinal,
  });
}

/// Envia um pedido de amizade (§13) — ou aceita o inverso (§27).
export const enviarSolicitacaoAmizade = onCall(opcoesCliente, async (req) => {
  const uid = exigirAutenticacao(req);
  const alvoUid = await exigirUidDoPublicId(
    (req.data as Record<string, unknown> | undefined)?.publicId
  );

  if (alvoUid === uid) recusar("autoAmizadeInvalida");

  const { veredito, estadoFinal } = await operarRelacao(uid, alvoUid, (ctx) =>
    dominio.avaliarSolicitacao({
      solicitanteUid: uid,
      destinatarioUid: alvoUid,
      estadoAtual: ctx.relacao.estado,
      solicitantePendenteUid: ctx.relacao.solicitanteUid,
      contatoPermitido: ctx.contato.permitido,
      amigosDoSolicitante: ctx.contadoresChamador.amigos,
      amigosDoDestinatario: ctx.contadoresOutro.amigos,
      pendentesEnviadasDoSolicitante:
        ctx.contadoresChamador.solicitacoesEnviadas,
    })
  );

  return respostaDaOperacao(veredito, estadoFinal);
});

/// Aceita uma solicitacao recebida (§14). Somente o destinatario.
export const aceitarSolicitacaoAmizade = onCall(opcoesCliente, async (req) => {
  const uid = exigirAutenticacao(req);
  const alvoUid = await exigirUidDoPublicId(
    (req.data as Record<string, unknown> | undefined)?.publicId
  );

  const { veredito, estadoFinal } = await operarRelacao(uid, alvoUid, (ctx) =>
    dominio.avaliarAceite({
      uidQueAceita: uid,
      estadoAtual: ctx.relacao.estado,
      destinatarioPendenteUid: ctx.relacao.destinatarioUid,
      contatoPermitido: ctx.contato.permitido,
      amigosDeQuemAceita: ctx.contadoresChamador.amigos,
      amigosDoOutro: ctx.contadoresOutro.amigos,
    })
  );

  return respostaDaOperacao(veredito, estadoFinal);
});

/// Recusa uma solicitacao recebida (§15). Nao pune e nao bloqueia.
export const recusarSolicitacaoAmizade = onCall(opcoesCliente, async (req) => {
  const uid = exigirAutenticacao(req);
  const alvoUid = await exigirUidDoPublicId(
    (req.data as Record<string, unknown> | undefined)?.publicId
  );

  const { veredito, estadoFinal } = await operarRelacao(uid, alvoUid, (ctx) =>
    dominio.avaliarRecusa({
      uidQueRecusa: uid,
      estadoAtual: ctx.relacao.estado,
      destinatarioPendenteUid: ctx.relacao.destinatarioUid,
    })
  );

  return respostaDaOperacao(veredito, estadoFinal);
});

/// Cancela uma solicitacao enviada (§16). Somente o remetente.
export const cancelarSolicitacaoAmizade = onCall(opcoesCliente, async (req) => {
  const uid = exigirAutenticacao(req);
  const alvoUid = await exigirUidDoPublicId(
    (req.data as Record<string, unknown> | undefined)?.publicId
  );

  const { veredito, estadoFinal } = await operarRelacao(uid, alvoUid, (ctx) =>
    dominio.avaliarCancelamento({
      uidQueCancela: uid,
      estadoAtual: ctx.relacao.estado,
      solicitantePendenteUid: ctx.relacao.solicitanteUid,
    })
  );

  return respostaDaOperacao(veredito, estadoFinal);
});

/// Desfaz a amizade (§17). Bilateral: some dos dois lados.
export const removerAmizade = onCall(opcoesCliente, async (req) => {
  const uid = exigirAutenticacao(req);
  const alvoUid = await exigirUidDoPublicId(
    (req.data as Record<string, unknown> | undefined)?.publicId
  );

  const { veredito, estadoFinal } = await operarRelacao(uid, alvoUid, (ctx) =>
    dominio.avaliarRemocao({
      uidQueRemove: uid,
      estadoAtual: ctx.relacao.estado,
      ehMembro: ctx.relacao.membros.includes(uid),
    })
  );

  return respostaDaOperacao(veredito, estadoFinal);
});

// ===========================================================================
// LISTAS (§22, §23, §24)
// ===========================================================================

/// Resolve uma pagina crua (publicIds) na apresentacao publica de cada item.
///
/// O APELIDO E LIDO AGORA, e nao copiado da projecao. E o que faz §31-I valer por
/// construcao: quem trocou de nome ontem aparece com o nome novo hoje, sem
/// depender de nenhuma propagacao ter dado certo.
async function resolverPagina(pagina: {
  itens: { publicId: string; desde: string | null }[];
  proximoCursor: string | null;
}) {
  const perfis = await lerPerfisPublicos(pagina.itens.map((i) => i.publicId));
  return exigirRespostaSegura({
    itens: pagina.itens.map((i) =>
      entradaPublica(perfis.get(i.publicId), i.publicId, i.desde)
    ),
    proximoCursor: pagina.proximoCursor,
  });
}

function limiteDoPedido(data: unknown): number {
  const bruto = (data as Record<string, unknown> | undefined)?.limite;
  const n = typeof bruto === "number" ? Math.floor(bruto) : 0;
  if (n <= 0) return LIMITES.paginaPadrao;
  return Math.min(n, LIMITES.paginaMaxima);
}

function cursorDoPedido(data: unknown): string | null {
  const bruto = (data as Record<string, unknown> | undefined)?.cursor;
  return typeof bruto === "string" && bruto.length > 0 ? bruto : null;
}

/// Lista os amigos, paginado e ordenado por apelido (§22).
export const listarAmigos = onCall(opcoesCliente, async (req) => {
  const uid = exigirAutenticacao(req);
  const pagina = await paginaDeAmigos(
    uid,
    cursorDoPedido(req.data),
    limiteDoPedido(req.data)
  );
  return resolverPagina(pagina);
});

// ===========================================================================
// PRESENÇA — visível somente entre amigos
// ===========================================================================

const JANELA_PRESENCA_MS = 90_000;

/// Renova a presença da própria sessão. O cliente não escolhe UID nem prazo.
export const atualizarPresencaSocial = onCall(opcoesCliente, async (req) => {
  const uid = exigirAutenticacao(req);
  const privacidade = await db().collection("socialPrivacy").doc(uid).get();
  if (privacidade.data()?.aparecerOffline === true) {
    await db().collection("socialPresence").doc(uid).delete();
    return { online: false, aparecerOffline: true };
  }
  const agora = Date.now();
  await db().collection("socialPresence").doc(uid).set({
    uid,
    onlineAte: Timestamp.fromMillis(agora + JANELA_PRESENCA_MS),
    atualizadoEm: Timestamp.fromMillis(agora),
    esquema: 1,
  });
  return { online: true, aparecerOffline: false };
});

/// Preferência autoritativa "Aparecer offline". Quando ligada, a presença
/// corrente é apagada na mesma operação lógica; o próximo heartbeat também
/// respeita a preferência e não a recria.
export const definirAparecerOffline = onCall(opcoesCliente, async (req) => {
  const uid = exigirAutenticacao(req);
  const aparecerOffline = req.data?.aparecerOffline === true;
  const lote = db().batch();
  lote.set(db().collection("socialPrivacy").doc(uid), {
    aparecerOffline,
    atualizadoEm: Timestamp.now(),
  }, { merge: true });
  if (aparecerOffline) lote.delete(db().collection("socialPresence").doc(uid));
  await lote.commit();
  return { aparecerOffline };
});

/// Lista apenas amigos cuja presença ainda está viva. Nenhum UID sai; cada
/// candidato passa novamente pelo bloqueio para fechar a janela entre um
/// bloqueio e a faxina assíncrona da amizade.
export const listarAmigosOnline = onCall(opcoesCliente, async (req) => {
  const uid = exigirAutenticacao(req);
  const snap = await db()
    .collection(C_USUARIOS)
    .doc(uid)
    .collection("friends")
    .limit(LIMITES.limiteAmigos)
    .get();
  if (snap.empty) return exigirRespostaSegura({ itens: [] });

  const refs = snap.docs.map((d) => db().collection("socialPresence").doc(d.id));
  const presencas = await db().getAll(...refs);
  const agora = Date.now();
  const candidatos = presencas
    .map((p, i) => ({ p, amigo: snap.docs[i] }))
    .filter(({ p }) => {
      const ate = p.data()?.onlineAte;
      return p.exists && ate instanceof Timestamp && ate.toMillis() > agora;
    });

  const visiveis = [] as Array<{ publicId: string; desde: string | null }>;
  for (const { amigo } of candidatos) {
    const contato = await estadoDeContato(uid, amigo.id);
    if (!contato.permitido) continue;
    visiveis.push({
      publicId: `${amigo.data().publicId ?? ""}`,
      desde: typeof amigo.data().amigosDesde === "string"
        ? amigo.data().amigosDesde : null,
    });
  }
  const perfis = await lerPerfisPublicos(visiveis.map((i) => i.publicId));
  return exigirRespostaSegura({
    itens: visiveis
      .map((i) => entradaPublica(perfis.get(i.publicId), i.publicId, i.desde))
      .filter((i) => i.publicId.length > 0),
  });
});

// ===========================================================================
// CONVITES DE MESA — amizade real, prazo curto e código opaco ao restante
// ===========================================================================

const PRAZO_CONVITE_MESA_MS = 15 * 60_000;

function idConviteMesa(inviterUid: string, inviteeUid: string, codigo: string): string {
  return createHash("sha256")
    .update(`${inviterUid}|${inviteeUid}|${codigo}`)
    .digest("hex")
    .slice(0, 32);
}

async function exigirAmizadeSemBloqueio(uid: string, alvoUid: string): Promise<void> {
  const contato = await estadoDeContato(uid, alvoUid);
  if (!contato.permitido) recusar("contatoIndisponivel");
  const par = dominio.chaveDoPar(uid, alvoUid).pairKey;
  const rel = await db().collection(C_AMIZADES).doc(par).get();
  if (!rel.exists || rel.data()?.estado !== "amigos") recusar("amizadeNecessaria");
}

/// Envia ou renova um convite para uma mesa já criada. O servidor de jogo
/// continua sendo quem valida se o código existe, se a mesa aceita entrada e se
/// o destinatário tem VIP; este documento só entrega o convite ao amigo certo.
export const enviarConviteMesa = onCall(opcoesCliente, async (req) => {
  const inviterUid = exigirAutenticacao(req);
  const publicId = req.data?.publicId;
  const codigo = typeof req.data?.codigo === "string"
    ? req.data.codigo.trim().toUpperCase() : "";
  const tipoMesa = typeof req.data?.tipoMesa === "string"
    ? req.data.tipoMesa : "privada";
  if (!/^[A-Z0-9-]{4,32}$/.test(codigo)) {
    throw new HttpsError("invalid-argument", "Código de mesa inválido.");
  }
  if (!["publica", "vip", "privada"].includes(tipoMesa)) {
    throw new HttpsError("invalid-argument", "Tipo de mesa inválido.");
  }
  const inviteeUid = await exigirUidDoPublicId(publicId);
  if (inviteeUid === inviterUid) recusar("autoConviteInvalido");
  await exigirAmizadeSemBloqueio(inviterUid, inviteeUid);

  const inviterPublicId = await publicIdDe(inviterUid);
  if (!inviterPublicId) recusar("identidadeNaoEncontrada");
  const conviteId = idConviteMesa(inviterUid, inviteeUid, codigo);
  const agora = Date.now();
  await db().collection("gameInvites").doc(conviteId).set({
    conviteId,
    inviterUid,
    inviteeUid,
    inviterPublicId,
    inviteePublicId: publicId,
    codigo,
    tipoMesa,
    status: "pendente",
    criadoEm: Timestamp.fromMillis(agora),
    expiraEm: Timestamp.fromMillis(agora + PRAZO_CONVITE_MESA_MS),
    esquema: 1,
  });
  return exigirRespostaSegura({ enviado: true, conviteId });
});

export const listarConvitesMesa = onCall(opcoesCliente, async (req) => {
  const inviteeUid = exigirAutenticacao(req);
  const snap = await db().collection("gameInvites")
    .where("inviteeUid", "==", inviteeUid)
    .where("status", "==", "pendente")
    .orderBy("criadoEm", "desc")
    .limit(25)
    .get();
  const agora = Date.now();
  const candidatos = snap.docs.filter((d) => {
    const expira = d.data().expiraEm;
    return expira instanceof Timestamp && expira.toMillis() > agora;
  });
  const saida = [] as Array<Record<string, unknown>>;
  for (const d of candidatos) {
    const e = d.data();
    const inviterUid = e.inviterUid;
    if (typeof inviterUid !== "string") continue;
    const contato = await estadoDeContato(inviteeUid, inviterUid);
    if (!contato.permitido) continue;
    const par = dominio.chaveDoPar(inviteeUid, inviterUid).pairKey;
    const relacao = await db().collection(C_AMIZADES).doc(par).get();
    if (!relacao.exists || relacao.data()?.estado !== "amigos") continue;
    const perfil = await lerPerfilPublico(`${e.inviterPublicId ?? ""}`);
    saida.push({
      conviteId: d.id,
      codigo: `${e.codigo ?? ""}`,
      tipoMesa: `${e.tipoMesa ?? "privada"}`,
      expiraEm: (e.expiraEm as Timestamp).toDate().toISOString(),
      remetente: entradaPublica(perfil, `${e.inviterPublicId ?? ""}`, null),
    });
  }
  return exigirRespostaSegura({ itens: saida });
});

export const responderConviteMesa = onCall(opcoesCliente, async (req) => {
  const inviteeUid = exigirAutenticacao(req);
  const conviteId = typeof req.data?.conviteId === "string" ? req.data.conviteId : "";
  const aceitar = req.data?.aceitar === true;
  if (!/^[a-f0-9]{32}$/.test(conviteId)) {
    throw new HttpsError("invalid-argument", "Convite inválido.");
  }
  const ref = db().collection("gameInvites").doc(conviteId);
  return db().runTransaction(async (tx) => {
    const doc = await tx.get(ref);
    const e = doc.data();
    if (!doc.exists || e?.inviteeUid !== inviteeUid) recusar("conviteIndisponivel");
    const inviterUid = e?.inviterUid;
    if (typeof inviterUid !== "string") recusar("conviteIndisponivel");
    const contato = await estadoDeContato(inviteeUid, inviterUid, tx);
    const par = dominio.chaveDoPar(inviteeUid, inviterUid).pairKey;
    const relacao = await tx.get(db().collection(C_AMIZADES).doc(par));
    if (!contato.permitido || !relacao.exists || relacao.data()?.estado !== "amigos") {
      recusar("conviteIndisponivel");
    }
    if (e?.status !== "pendente") {
      return exigirRespostaSegura({
        aceito: e?.status === "aceito",
        repeticao: true,
        codigo: e?.status === "aceito" ? `${e.codigo ?? ""}` : null,
        tipoMesa: e?.status === "aceito" ? `${e.tipoMesa ?? "privada"}` : null,
      });
    }
    const expira = e.expiraEm;
    if (!(expira instanceof Timestamp) || expira.toMillis() <= Date.now()) {
      tx.update(ref, { status: "expirado", respondidoEm: Timestamp.now() });
      return exigirRespostaSegura({
        aceito: false,
        repeticao: false,
        expirado: true,
        codigo: null,
        tipoMesa: null,
      });
    }
    tx.update(ref, {
      status: aceitar ? "aceito" : "recusado",
      respondidoEm: Timestamp.now(),
    });
    return exigirRespostaSegura({
      aceito: aceitar,
      repeticao: false,
      codigo: aceitar ? `${e.codigo ?? ""}` : null,
      tipoMesa: aceitar ? `${e.tipoMesa ?? "privada"}` : null,
    });
  });
});

/// Lista as solicitacoes RECEBIDAS pendentes (§23).
export const listarSolicitacoesRecebidas = onCall(opcoesCliente, async (req) => {
  const uid = exigirAutenticacao(req);
  const pagina = await paginaDeSolicitacoes(
    uid,
    "recebida",
    cursorDoPedido(req.data),
    limiteDoPedido(req.data)
  );
  return resolverPagina(pagina);
});

/// Lista as solicitacoes ENVIADAS pendentes (§24).
export const listarSolicitacoesEnviadas = onCall(opcoesCliente, async (req) => {
  const uid = exigirAutenticacao(req);
  const pagina = await paginaDeSolicitacoes(
    uid,
    "enviada",
    cursorDoPedido(req.data),
    limiteDoPedido(req.data)
  );
  return resolverPagina(pagina);
});

// ===========================================================================
// BLOQUEIO: A FAXINA (§18)
// ===========================================================================

/// Reage ao bloqueio criado pelo codebase de MODERACAO.
///
/// POR QUE UM GATILHO, e nao uma chamada dentro de `bloquearJogador`: os dois
/// codebases sao unidades de implantacao independentes (ver o cabecalho de
/// firebase.json), e fazer a moderacao chamar o social significaria que um deploy
/// quebrado do social derrubaria a capacidade de BLOQUEAR alguem — que e a
/// ferramenta de protecao mais urgente do aplicativo. A dependencia tem que
/// apontar para o lado seguro: o social reage, a moderacao nao espera.
///
/// A JANELA ENTRE O BLOQUEIO E ESTA FAXINA NAO E EXPLORAVEL. Toda operacao
/// social le o bloqueio DENTRO da propria transacao, entao durante a janela a
/// amizade existe no banco mas nenhuma acao passa. A faxina alinha o banco com a
/// realidade; ela nao e o que produz a realidade.
export const aoBloquearJogador = onDocumentCreated(
  {
    document: "users/{bloqueadorUid}/blocks/{bloqueadoUid}",
    region: "southamerica-east1",
  },
  async (evento) => {
    const { bloqueadorUid, bloqueadoUid } = evento.params;
    if (!bloqueadorUid || !bloqueadoUid || bloqueadorUid === bloqueadoUid) return;

    try {
      const { desfez } = await desfazerPorBloqueio(bloqueadorUid, bloqueadoUid);
      logger.info("faxina social por bloqueio", { desfez });
    } catch (erro) {
      // NAO relanca: falhar aqui reprocessaria o gatilho, e a segunda passagem
      // encontraria a relacao ja apagada. O log e o que importa, porque a
      // seguranca ja esta garantida pela checagem em cada operacao.
      logger.error("falha na faxina social por bloqueio", { erro: `${erro}` });
    }
  }
);

// ===========================================================================
// ADMINISTRACAO
// ===========================================================================

/// Reconstroi as projecoes de um jogador a partir da fonte de verdade (§20).
///
/// SO ADMIN. E a ferramenta de reparo que §20 pede quando existem projecoes, e
/// tambem a resposta honesta a "e se o leque de apelido falhar no meio?".
export const reconciliarPerfilSocial = onCall(opcoesCliente, async (req) => {
  exigirAdmin(req);
  const { publicId } = (req.data ?? {}) as Record<string, unknown>;
  const alvoUid = await exigirUidDoPublicId(publicId);
  const resultado = await reconciliarProjecoes(alvoUid);
  return { reconciliado: true, ...resultado };
});
