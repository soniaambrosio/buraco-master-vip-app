// rastreabilidade.ts — Cloud Functions da rastreabilidade de partidas.
//
// MESMA DIVISAO DE TRABALHO DO RESTO DESTE CODEBASE (ver o cabecalho de
// index.ts), e ela e a coisa mais importante deste arquivo:
//
//   QUEM DECIDE  -> o dominio Dart, em app/lib/rastreabilidade/. Identidade,
//                   validacao do envelope, convergencia de encerramentos
//                   concorrentes, coerencia do plano e before/delta/after saem
//                   de la, do MESMO codigo que o app executa e que os 131 testes
//                   de app/test/rastreabilidade/ cobrem.
//   QUEM EXECUTA -> este arquivo. Autenticacao, transacao, leitura e escrita.
//
// POR QUE O DOMINIO NAO E CHAMADO DIRETAMENTE AQUI, e isto e uma limitacao
// DECLARADA e nao um esquecimento: a ponte `dart compile js` deste codebase
// (functions/lib/domain_bundle.js, gerada de app/lib/torneios/js_bridge.dart)
// exporta o dominio de TORNEIOS. Levar a rastreabilidade para dentro dela
// exigiria mexer no js_bridge.dart de torneios, que pertence a outra frente.
//
// A consequencia pratica esta escrita em cada funcao abaixo: o que este arquivo
// executa e a parte MECANICA (transacao, idempotencia por id de documento,
// projecao do historico), e a validacao semantica que o dominio faz continua
// sendo executada no produtor do envelope — o servidor de partidas Node/Railway,
// que roda o mesmo contrato. A pendencia de unificar as duas pontes esta
// registrada em docs/OS-RASTREABILIDADE-PARTIDAS.md.
//
// SECAO 24 EM UMA LINHA: o `firestore.rules` nega TODA escrita do cliente em
// `matches`, `matches/{id}/events`, `rankingLedger`, `fraudSignals` e
// `users/{uid}/matchHistory`. Este arquivo e a unica porta.

import { getFirestore, Transaction } from "firebase-admin/firestore";
import { onCall, HttpsError, CallableRequest } from "firebase-functions/v2/https";
import { logger } from "firebase-functions";

import { aplicarPlanoDeConquista, planejarPrimeiraBatidaReal } from "./conquistas";
// [PROVISIONADOR] A regra de autoridade saiu daqui para `autoridade.ts`, que
// NAO e reexportado por index.ts — logo continua sendo biblioteca, e nao
// superficie de implantacao. `import` nao acrescenta export a este modulo, e o
// contorno implantado deste arquivo segue identico.
import { autorizaComoMotorDePartidas, type ClaimsDoToken } from "./autoridade";

const db = () => getFirestore();

// `initializeApp()` NAO e chamado aqui: index.ts ja o chama uma vez, e chamar
// duas vezes no mesmo processo lanca. Este modulo e sempre carregado por ele.

const opcoesServidor = { region: "southamerica-east1" };
const opcoesCliente = { enforceAppCheck: true, region: "southamerica-east1" };

function claimsDe(req: CallableRequest): ClaimsDoToken {
  return (req.auth?.token ?? {}) as ClaimsDoToken;
}

function exigirAutenticacao(req: CallableRequest): string {
  const uid = req.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "E preciso estar autenticado.");
  }
  return uid;
}

function exigirAutoridadeDePartida(req: CallableRequest): string {
  const uid = exigirAutenticacao(req);
  if (!autorizaComoMotorDePartidas(claimsDe(req))) {
    // A mesma recusa que o dominio devolve como `semAutoridade`. Deixar esta
    // porta aberta permitiria a qualquer cliente autenticado escrever o proprio
    // resultado — que e o item mais caro da secao 24.
    throw new HttpsError(
      "permission-denied",
      "somente a autoridade da partida registra encerramento."
    );
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

/// Nivel de acesso do chamador, no vocabulario de `NivelAcesso` do dominio.
function nivelDe(req: CallableRequest): "jogador" | "suporte" | "administrador" {
  const token = claimsDe(req);
  if (token.admin === true) return "administrador";
  if (token.suporte === true) return "suporte";
  return "jogador";
}

// ---------------------------------------------------------------------------
// ESCRITA — registrar o encerramento de uma partida (secoes 5, 8, 12, 21)
// ---------------------------------------------------------------------------

/// Recebe o plano de encerramento ja montado pela autoridade da partida.
///
/// NAO exige App Check, pelo mesmo motivo de `receberResultadoPartida`: quem
/// chama e o servidor de partidas, nao um aparelho. Exige, em compensacao, o
/// claim `motorDePartidas` (ou `admin`).
///
/// ATOMICIDADE (secao 21): registro, eventos, lancamentos e sinais entram numa
/// transacao so. Nao existe caminho que grave o ranking sem fechar a partida,
/// nem que feche a partida sem gravar a trilha.
///
/// IDEMPOTENCIA (secao 10): TODA escrita aqui usa id de documento determinado
/// pelo dominio —
///   matches/{matchId}
///   matches/{matchId}/events/{eventId}
///   rankingLedger/{matchId|userId|motivo}
///   fraudSignals/{matchId|tipo|alvos}
///   users/{uid}/matchHistory/{matchId}
/// Gravar duas vezes o mesmo dado e a MESMA escrita. A duplicidade fica
/// impossivel por construcao, e nao por checagem — a disciplina que
/// `rewardGrants` ja usa neste projeto.
export const registrarEncerramentoPartida = onCall(opcoesServidor, async (req) => {
  const autor = exigirAutoridadeDePartida(req);

  const plano = req.data?.plano as Record<string, unknown> | undefined;
  if (!plano) {
    throw new HttpsError("invalid-argument", "plano e obrigatorio.");
  }
  const registro = plano.registro as Record<string, unknown> | undefined;
  if (!registro) {
    throw new HttpsError("invalid-argument", "plano.registro e obrigatorio.");
  }
  const matchId = registro.matchId;
  if (typeof matchId !== "string" || matchId.length === 0) {
    throw new HttpsError("invalid-argument", "registro.matchId e obrigatorio.");
  }
  const estado = registro.estado;
  if (typeof estado !== "string") {
    throw new HttpsError("invalid-argument", "registro.estado e obrigatorio.");
  }

  const eventos = Array.isArray(plano.eventos) ? plano.eventos : [];
  const lancamentos = Array.isArray(plano.lancamentos) ? plano.lancamentos : [];
  const sinais = Array.isArray(plano.sinais) ? plano.sinais : [];

  const matchRef = db().collection("matches").doc(matchId);

  return db().runTransaction(async (tx: Transaction) => {
    const atual = await tx.get(matchRef);

    // CONVERGENCIA (secao 20). O dominio ja decidiu isto — o plano so chega
    // aqui se ele aceitou. Esta e a segunda barreira, no nivel do banco: dois
    // encerramentos concorrentes que passaram pelo dominio em processos
    // diferentes ainda chegariam os dois ate aqui.
    const gravado = atual.data();
    if (gravado && ehTerminal(gravado.estado as string)) {
      const mesmo =
        gravado.motivoEncerramento === registro.motivoEncerramento &&
        gravado.ladoVencedor === registro.ladoVencedor &&
        gravado.impressaoEstado === registro.impressaoEstado;
      if (!mesmo) {
        throw new HttpsError(
          "failed-precondition",
          `a partida ${matchId} ja encerrou como ${gravado.estado}; um segundo ` +
            "desfecho divergente nao reescreve resultado publicado."
        );
      }
      // Reenvio identico: sucesso, sem regravar. Este e o caminho do retry e do
      // callback repetido — reenvio nao e falha.
      //
      // A conquista e avaliada AQUI TAMBEM, e nao so no caminho novo. Duas
      // razoes: o reenvio precisa convergir para o mesmo estado final (se a
      // concessao da primeira vez se perdeu, esta a repara), e uma partida
      // fechada antes desta funcionalidade existir passa a poder receber a
      // conquista ao ser reenviada — sem nunca duplicar, porque o id do
      // documento e fixo por jogador.
      const conquistaReenvio = await planejarPrimeiraBatidaReal(tx, registro, matchId);
      aplicarPlanoDeConquista(tx, conquistaReenvio);
      logger.info("conquista avaliada em reenvio", {
        matchId,
        conquista: "primeira_batida_real",
        resultado: conquistaReenvio.resultado,
        motivo: conquistaReenvio.motivo,
      });
      return { aceito: true, jaRegistrado: true, matchId };
    }

    // ULTIMA LEITURA da transacao. Tudo abaixo e escrita, e o Firestore recusa
    // uma leitura depois da primeira escrita.
    const conquista = await planejarPrimeiraBatidaReal(tx, registro, matchId);

    tx.set(matchRef, { ...registro, registradoPor: autor });

    for (const evento of eventos as Array<Record<string, unknown>>) {
      const eventId = evento.eventId;
      if (typeof eventId !== "string" || eventId.length === 0) continue;
      // `set`, e nao `create`: `create` falharia no reenvio e transformaria uma
      // repeticao benigna em erro. `set` com o mesmo conteudo e convergente.
      tx.set(matchRef.collection("events").doc(eventId), evento);
    }

    for (const lancamento of lancamentos as Array<Record<string, unknown>>) {
      const chave = lancamento.chaveIdempotencia;
      if (typeof chave !== "string" || chave.length === 0) continue;
      tx.set(db().collection("rankingLedger").doc(chave), lancamento);
    }

    for (const sinal of sinais as Array<Record<string, unknown>>) {
      const chave = sinal.chaveIdempotencia;
      if (typeof chave !== "string" || chave.length === 0) continue;
      tx.set(db().collection("fraudSignals").doc(chave), sinal);
    }

    // HISTORICO DO JOGADOR (secao 11). Projecao por jogador, gravada no mesmo
    // passo do registro — e o que impede o estado em que a partida terminou mas
    // o historico dela nao existe (secao 21).
    //
    // O CONTEUDO vem do plano, montado pelo dominio (`projetarParaJogador`), e
    // nao e remontado aqui: reprojetar em TypeScript criaria uma segunda regra
    // de privacidade que divergiria da primeira.
    const historico = (plano.historico ?? {}) as Record<string, unknown>;
    for (const [uid, entrada] of Object.entries(historico)) {
      tx.set(
        db().collection("users").doc(uid).collection("matchHistory").doc(matchId),
        entrada as Record<string, unknown>
      );
    }

    aplicarPlanoDeConquista(tx, conquista);

    logger.info("encerramento de partida registrado", {
      matchId,
      estado,
      eventos: eventos.length,
      lancamentos: lancamentos.length,
      sinais: sinais.length,
    });
    // Log proprio, e nao um campo no anterior: o operador precisa conseguir
    // filtrar so a conquista. Sem uid, sem apelido, sem e-mail e sem carta —
    // so o que responde "por que fulano nao recebeu?" quando alguem perguntar,
    // e a partida ja e identificada pelo matchId da linha de cima.
    logger.info("conquista avaliada no encerramento", {
      matchId,
      conquista: "primeira_batida_real",
      versaoContrato: 1,
      resultado: conquista.resultado,
      motivo: conquista.motivo,
    });
    return { aceito: true, jaRegistrado: false, matchId };
  });
});

/// Espelha `EstadoDaPartida.terminal` do dominio Dart.
function ehTerminal(estado: string | undefined): boolean {
  return estado === "finalizada" || estado === "abandonada" || estado === "cancelada";
}

// ---------------------------------------------------------------------------
// LEITURA — consulta administrativa por matchId (secao 14)
// ---------------------------------------------------------------------------

/// Localiza uma partida por `matchId` e devolve o recorte permitido ao nivel do
/// chamador.
///
/// SECAO 14, LITERALMENTE: "o jogador comum nao deve ganhar acesso
/// administrativo so por conhecer um matchId". O nivel vem do CLAIM do token,
/// nunca do payload, e `jogador` e recusado aqui — inclusive quando ele
/// participou da partida. O historico dele e outra porta:
/// `users/{uid}/matchHistory`, que ele le direto pelas Rules.
///
/// A projecao por nivel espelha `montarVisaoAdministrativa` do dominio:
///   suporte       -> registro + eventos
///   administrador -> registro + eventos + lancamentos + sinais
export const consultarPartidaPorMatchId = onCall(opcoesCliente, async (req) => {
  exigirAutenticacao(req);
  const nivel = nivelDe(req);
  if (nivel === "jogador") {
    throw new HttpsError(
      "permission-denied",
      "consulta administrativa restrita a suporte e administracao."
    );
  }

  const matchId = req.data?.matchId;
  if (typeof matchId !== "string" || matchId.length === 0) {
    throw new HttpsError("invalid-argument", "matchId e obrigatorio.");
  }

  const matchRef = db().collection("matches").doc(matchId);
  const doc = await matchRef.get();
  if (!doc.exists) {
    // Erro seguro: nao diz se o id nunca existiu ou se foi arquivado, e nao
    // vaza nada sobre partidas vizinhas.
    throw new HttpsError("not-found", "partida nao encontrada.");
  }

  const eventos = await matchRef
    .collection("events")
    .orderBy("emServidor", "asc")
    .get();

  const base = {
    nivel,
    partida: doc.data(),
    eventos: eventos.docs.map((d) => d.data()),
  };

  if (nivel !== "administrador") return { ...base, lancamentos: [], sinais: [] };

  const [lancamentos, sinais] = await Promise.all([
    db().collection("rankingLedger").where("matchId", "==", matchId).get(),
    db().collection("fraudSignals").where("matchId", "==", matchId).get(),
  ]);

  return {
    ...base,
    lancamentos: lancamentos.docs.map((d) => d.data()),
    sinais: sinais.docs.map((d) => d.data()),
  };
});

/// Extrato competitivo de um jogador: a sequencia que explica a pontuacao dele.
///
/// O proprio jogador le o proprio extrato — e direito dele saber por que a
/// pontuacao mudou, e esconder isso so gera chamado de suporte. O administrador
/// le o de qualquer um. Ninguem le o de terceiros.
///
/// Devolve tambem a CONFERENCIA da cadeia: se algum lancamento nao encadeia
/// (`antes` != `depois` do anterior), o campo `rupturaEm` diz onde. E o que
/// permite ao suporte afirmar "este saldo e explicavel" sem ler linha a linha.
export const consultarExtratoCompetitivo = onCall(opcoesCliente, async (req) => {
  const uid = exigirAutenticacao(req);
  const alvo = typeof req.data?.userId === "string" ? req.data.userId : uid;
  if (alvo !== uid && req.auth?.token?.admin !== true) {
    throw new HttpsError("permission-denied", "extrato de outro jogador.");
  }

  const limite = Math.min(Number(req.data?.limite ?? 50) || 50, 200);
  const snapshot = await db()
    .collection("rankingLedger")
    .where("userId", "==", alvo)
    .orderBy("registradoEm", "asc")
    .limit(limite)
    .get();

  const lancamentos = snapshot.docs.map((d) => d.data());

  // A conferencia e a mesma de `LedgerCompetitivo.conferir()`, aplicada a
  // pagina lida. Nao substitui a do dominio; e a leitura barata que o operador
  // ve no painel.
  let rupturaEm: string | null = null;
  let esperado: number | null = null;
  for (const l of lancamentos) {
    const antes = l.rankingBefore as number;
    const delta = l.rankingDelta as number;
    const depois = l.rankingAfter as number;
    if (antes + delta !== depois) {
      rupturaEm = l.chaveIdempotencia as string;
      break;
    }
    if (esperado !== null && antes !== esperado) {
      rupturaEm = l.chaveIdempotencia as string;
      break;
    }
    esperado = depois;
  }

  return {
    userId: alvo,
    lancamentos,
    saldo: esperado,
    rupturaEm,
    // Sinaliza que a pagina pode nao ser a cadeia inteira: um saldo lido de uma
    // pagina truncada nao e o saldo do jogador, e quem consome precisa saber.
    truncado: snapshot.size === limite,
  };
});

/// Registra um sinal antifraude ja calculado.
///
/// SECAO 17, NO CODIGO: esta funcao grava OBSERVACAO, e nao veredito. Ela nao
/// suspende, nao bloqueia, nao marca conta e nao chama nada que o faca — o
/// unico efeito e um documento em `fraudSignals`. O campo `geraPunicao` do
/// proprio documento e sempre `false`.
///
/// Restrita a administracao porque um sinal plantado por terceiro seria a forma
/// mais barata de acusar alguem (secao 35: "jogador nao cria flag
/// administrativa contra terceiros"). O caminho automatico e outro: os sinais
/// que a ingestao observa viajam dentro do plano de encerramento.
export const registrarSinalAntifraude = onCall(opcoesCliente, async (req) => {
  const autor = exigirAdmin(req);

  const sinal = req.data?.sinal as Record<string, unknown> | undefined;
  if (!sinal) {
    throw new HttpsError("invalid-argument", "sinal e obrigatorio.");
  }
  const chave = sinal.chaveIdempotencia;
  const matchId = sinal.matchId;
  if (typeof chave !== "string" || chave.length === 0) {
    throw new HttpsError("invalid-argument", "sinal.chaveIdempotencia e obrigatoria.");
  }
  if (typeof matchId !== "string" || matchId.length === 0) {
    // Secao 35: "sinal e associado ao matchId". Sem partida, nao ha o que
    // investigar depois.
    throw new HttpsError("invalid-argument", "sinal.matchId e obrigatorio.");
  }
  if (sinal.suspectedPattern === undefined) {
    throw new HttpsError("invalid-argument", "sinal.suspectedPattern e obrigatorio.");
  }

  const ref = db().collection("fraudSignals").doc(chave);
  await ref.set({
    ...sinal,
    // Reafirmado na escrita, e nao so confiado ao produtor: o documento no
    // banco precisa dizer sozinho que nao e uma condenacao.
    geraPunicao: false,
    registradoPor: autor,
  });

  logger.info("sinal antifraude registrado", {
    matchId,
    padrao: sinal.suspectedPattern,
    // O alvo NAO vai para o log: log de observabilidade nao e lugar de lista de
    // suspeitos (secao 37).
  });
  return { registrado: true, chaveIdempotencia: chave };
});
