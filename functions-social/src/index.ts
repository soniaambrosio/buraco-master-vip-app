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
import { logger } from "firebase-functions";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { CallableRequest, HttpsError, onCall } from "firebase-functions/v2/https";

import {
  C_AMIZADES,
  C_PERFIS_PUBLICOS,
  entradaDeBusca,
  entradaPublica,
  exigirRespostaSegura,
} from "./chaves";
import {
  CandidatoDeBusca,
  LIMITES,
  OperacaoSeguir,
  VereditoAmizade,
  agoraUtc,
  dominio,
} from "./domain";
import {
  AutorizacaoDoDono,
  ContaEmExclusao,
  DESFECHOS_PERMANENTES,
  ListaDeSeguir,
  SeguirSemContagem,
  SeguirSemIdentidade,
  VistaDeSeguir,
  classificarFalha,
  contadoresProprios,
  desfazerPorBloqueio,
  faxinaSeguirDaDirecao,
  db,
  estadoDeContato,
  estadoPublicoDeSeguir,
  exigirDocumentoPublicoLimpo,
  garantirIdentidade,
  gravarPrivacidadeSocial,
  ladoDaOperacao,
  lerPerfilPublico,
  lerPerfisPublicos,
  operarRelacao,
  operarSeguir,
  paginaDeAmigos,
  paginaDeSeguir,
  paginaDeSolicitacoes,
  propagarApelidoParaAmigos,
  publicIdDe,
  reconciliarPerfil,
  relacoesParaBusca,
  resolverUid,
  varrerVisiveis,
  vistaDeSeguir,
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
      // SOCIAL-02 C3: o proprio perfil nao tem relacao de seguir consigo.
      seguir: null,
      detalhes: null,
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

  // SOCIAL-02 C3 (O12): o bloco de seguir, com permissao e conteudo lidos no
  // MESMO snapshot transacional (ver `vistaDeSeguir`). A amizade acima fica
  // como estava (B1/B2 sao outra OS). Falha aqui nao derruba o perfil publico:
  // o bloco vira `null` e nenhuma acao de seguir e oferecida.
  let seguir: VistaDeSeguir = { bloco: null, acoes: [] };
  try {
    seguir = await vistaDeSeguir(uid, alvoUid);
  } catch (erro) {
    logger.error("vista de seguir indisponivel", { erro: `${erro}` });
  }

  return exigirRespostaSegura({
    perfil: entradaPublica(perfil, normalizado, null),
    relacao: vista.relacao,
    acoes: [...vista.acoes, ...seguir.acoes],
    // `amigosDesde` so viaja quando a relacao e de amizade: numa relacao
    // bloqueada ou inexistente ele nao existe, e inventa-lo daria informacao.
    amigosDesde:
      vista.relacao === "amigos" && typeof dadosRel?.amigosDesde === "string"
        ? dadosRel.amigosDesde
        : null,
    // Ausente (`null`) para observador sem VIP, conta em exclusao ou contato
    // impedido — sem dizer qual.
    seguir: seguir.bloco,
    // Nao ha fonte de detalhes contratada (D04): `null`, sem leitura e sem
    // demonstracao.
    detalhes: null,
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
// SEGUIR (SOCIAL-02, etapa C3)
// ===========================================================================
//
// O ator vem SEMPRE da sessao. O payload so traz o `publicId` do outro, a
// `referencia` vista (opaca) e o `intencaoId`; nunca UID, plano, instante,
// corte, contador ou estado. Quem decide e o dominio C1, dentro da transacao.

/// Traduz uma recusa de seguir numa `HttpsError` NEUTRA: o codigo vai em
/// `details.recusa`, e nada diz qual ponta, qual plano ou qual bloqueio.
function recusarSeguir(recusa: string | null): never {
  const codigo =
    recusa === "perfilPublicoNaoDisponivel"
      ? "not-found"
      : recusa === "ritmoExcedido" || recusa === "limitePedidosPendentes"
        ? "resource-exhausted"
        : recusa === "pedidoInvalido"
          ? "invalid-argument"
          : "failed-precondition";
  throw new HttpsError(codigo, recusa ?? "pedido recusado", { recusa });
}

/// Falha interna sem detalhe. O log guarda o motivo; a resposta, nao.
function falhaDeSeguir(erro: unknown): never {
  if (erro instanceof HttpsError) throw erro;
  if (erro instanceof SeguirSemContagem) recusarSeguir("limiteIndisponivel");
  if (erro instanceof SeguirSemIdentidade) recusarSeguir("acaoIndisponivel");
  logger.error("falha em operacao de seguir", { erro: `${erro}` });
  throw new HttpsError("internal", "falha interna");
}

/// O01–O07: uma callable por operacao, todas pelo mesmo caminho.
function comandoDeSeguir(op: OperacaoSeguir) {
  return onCall(opcoesCliente, async (req) => {
    const uid = exigirAutenticacao(req);
    const entrada = (req.data ?? {}) as Record<string, unknown>;
    const alvoUid = await exigirUidDoPublicId(entrada.publicId);
    if (alvoUid === uid) recusarSeguir("acaoSobreSiMesmo");

    try {
      const { veredito, referencia } = await operarSeguir(
        op,
        uid,
        alvoUid,
        entrada.referencia ?? null,
        typeof entrada.intencaoId === "string" ? entrada.intencaoId : ""
      );
      if (!veredito.aceita) recusarSeguir(veredito.recusa);
      return exigirRespostaSegura({
        ok: true,
        repeticao: veredito.repeticao,
        estado: estadoPublicoDeSeguir(veredito.estadoEfetivo, ladoDaOperacao(op)),
        referencia,
      });
    } catch (erro) {
      falhaDeSeguir(erro);
    }
  });
}

/// O01/O02 — o servidor escolhe vinculo imediato ou pedido pela privacidade.
export const seguirJogador = comandoDeSeguir("seguir");
/// O03 — o remetente desiste do proprio pedido.
export const cancelarPedidoSeguir = comandoDeSeguir("cancelarPedido");
/// O04 — o seguido aprova. Revalida as duas pontas; nao consome ritmo.
export const aprovarPedidoSeguir = comandoDeSeguir("aprovarPedido");
/// O05 — o seguido recusa. Sem punicao e sem bloqueio.
export const recusarPedidoSeguir = comandoDeSeguir("recusarPedido");
/// O06 — o seguidor encerra o vinculo.
export const deixarDeSeguir = comandoDeSeguir("deixarDeSeguir");
/// O07 — o seguido encerra o vinculo do outro.
export const removerSeguidor = comandoDeSeguir("removerSeguidor");

function exigirDonoAutorizado(autorizacao: AutorizacaoDoDono): void {
  if (autorizacao === "requerVip") recusarSeguir("requerVip");
  if (autorizacao === "indisponivel") recusarSeguir("acaoIndisponivel");
}

/// O08 — as quatro listas proprias, com apelido e avatar FRESCOS.
function listaDeSeguir(lista: ListaDeSeguir) {
  const campoData =
    lista === "seguidores" || lista === "seguindo" ? "desde" : "solicitadoEm";
  return onCall(opcoesCliente, async (req) => {
    const uid = exigirAutenticacao(req);
    const pagina = await paginaDeSeguir(
      uid,
      lista,
      cursorDoPedido(req.data),
      limiteDoPedido(req.data)
    );
    exigirDonoAutorizado(pagina.autorizacao);
    const perfis = await lerPerfisPublicos(pagina.itens.map((i) => i.publicId));
    return exigirRespostaSegura({
      itens: pagina.itens.map((i) => {
        const p = entradaPublica(perfis.get(i.publicId), i.publicId, null);
        return {
          publicId: p.publicId,
          apelido: p.apelido,
          avatarRef: p.avatarRef,
          [campoData]: i.desde,
          referencia: i.referencia,
        };
      }),
      proximoCursor: pagina.proximoCursor,
    });
  });
}

export const listarSeguidores = listaDeSeguir("seguidores");
export const listarSeguindo = listaDeSeguir("seguindo");
export const listarPedidosSeguirRecebidos = listaDeSeguir("pedidosSeguirRecebidos");
export const listarPedidosSeguirEnviados = listaDeSeguir("pedidosSeguirEnviados");

/// O09 — publico ou privado. Fechar mantem seguidores; abrir nao aprova.
export const definirPrivacidadeSocial = onCall(opcoesCliente, async (req) => {
  const uid = exigirAutenticacao(req);
  const bruto = (req.data as Record<string, unknown> | undefined)?.privacidade;
  const valor = bruto === "publico" ? "publico" : bruto === "privado" ? "privado" : null;
  if (valor === null) recusarSeguir("pedidoInvalido");
  const r = await gravarPrivacidadeSocial(uid, valor);
  exigirDonoAutorizado(r.autorizacao);
  return exigirRespostaSegura({
    ok: true,
    repeticao: r.repeticao,
    privacidade: r.privacidade,
  });
});

/// O13 — os contadores do proprio dono. Indisponivel e `null`, nunca zero.
export const consultarContadoresSociais = onCall(opcoesCliente, async (req) => {
  const uid = exigirAutenticacao(req);
  const r = await contadoresProprios(uid);
  exigirDonoAutorizado(r.autorizacao);
  return exigirRespostaSegura({ contadores: r.valores });
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
///
/// SOCIAL-02 C4 — TRES UNIDADES INDEPENDENTES, COM NOVA TENTATIVA:
///   1. amizade (faxina legada, agora protegida pelos diarios das duas pontas);
///   2. seguir bloqueador -> bloqueado;
///   3. seguir bloqueado -> bloqueador.
/// Todas sao tentadas mesmo quando uma falha. Cada uma relê o estado e o corte
/// atuais, entao rodar de novo e inofensivo: a segunda passagem nao encontra o
/// que ja foi arrumado, e uma relacao nascida sob o corte atual nunca e tocada.
///
/// ERROS:
///   * desfecho PERMANENTE conhecido (contador do remetente invalido, ritmo
///     ausente com pedido pendente, canonico ilegivel): RETORNADO pela unidade,
///     so registrado. A direcao continua negada pelo corte; o reparo e
///     `reconciliarPerfilSocial` do remetente;
///   * falha LANCADA (transitoria pelo codigo do SDK, ou nao classificada):
///     registrada e RELANCADA ao final, para a plataforma tentar de novo
///     (`retry: true`). Nada lancado e tratado como corrupcao conhecida.
/// Configurar `retry: true` nao prova a entrega automatica da plataforma.
export const aoBloquearJogador = onDocumentCreated(
  {
    document: "users/{bloqueadorUid}/blocks/{bloqueadoUid}",
    region: "southamerica-east1",
    retry: true,
  },
  async (evento) => {
    const { bloqueadorUid, bloqueadoUid } = evento.params;
    if (!bloqueadorUid || !bloqueadoUid || bloqueadorUid === bloqueadoUid) return;

    const falhas: unknown[] = [];

    try {
      const { desfez, impedidaPorExclusao } = await desfazerPorBloqueio(
        bloqueadorUid,
        bloqueadoUid
      );
      logger.info("faxina social por bloqueio", { desfez, impedidaPorExclusao });
    } catch (erro) {
      falhas.push(erro);
      logger.error("falha na faxina de amizade por bloqueio", {
        classe: classificarFalha(erro),
        erro: `${erro}`,
      });
    }

    for (const [seguidor, seguido] of [
      [bloqueadorUid, bloqueadoUid],
      [bloqueadoUid, bloqueadorUid],
    ]) {
      const sentido = seguidor === bloqueadorUid ? "doBloqueador" : "paraOBloqueador";
      try {
        const desfecho = await faxinaSeguirDaDirecao(seguidor, seguido);
        if (DESFECHOS_PERMANENTES.has(desfecho)) {
          logger.error("faxina de seguir: erro permanente", { sentido, desfecho });
        } else {
          logger.info("faxina de seguir por bloqueio", { sentido, desfecho });
        }
      } catch (erro) {
        falhas.push(erro);
        logger.error("falha na faxina de seguir por bloqueio", {
          sentido,
          classe: classificarFalha(erro),
          erro: `${erro}`,
        });
      }
    }

    if (falhas.length > 0) throw falhas[0];
  }
);

// ===========================================================================
// ADMINISTRACAO
// ===========================================================================

/// Reconstroi as projecoes de um jogador a partir da fonte de verdade (§20).
///
/// SO ADMIN. E a ferramenta de reparo que §20 pede quando existem projecoes, e
/// tambem a resposta honesta a "e se o leque de apelido falhar no meio?".
///
/// SOCIAL-02 C4 (adendo R1 §5): cobre tambem seguir, na ordem recontagem do
/// proprio ritmo -> direcoes -> amizade -> residuos, cada unidade numa
/// transacao que le os diarios que a protegem. Diario do jogador ja presente:
/// erro administrativo `contaEmExclusao`, nenhuma escrita. Diario surgido no
/// meio: para, sem desfazer o que foi confirmado antes. A resposta nao tem UID;
/// `amigos` e `solicitacoes` continuam no topo, como antes.
export const reconciliarPerfilSocial = onCall(opcoesCliente, async (req) => {
  exigirAdmin(req);
  const { publicId } = (req.data ?? {}) as Record<string, unknown>;
  const alvoUid = await exigirUidDoPublicId(publicId);
  try {
    const r = await reconciliarPerfil(alvoUid);
    return exigirRespostaSegura({
      reconciliado: true,
      amigos: r.amizade.amigos,
      solicitacoes: r.amizade.solicitacoes,
      amizade: r.amizade,
      seguir: r.seguir,
    });
  } catch (erro) {
    if (erro instanceof ContaEmExclusao) {
      throw new HttpsError("failed-precondition", "contaEmExclusao", {
        recusa: "contaEmExclusao",
        parcial: erro.unidadesConfirmadas > 0,
        unidadesConfirmadas: erro.unidadesConfirmadas,
      });
    }
    throw erro;
  }
});
