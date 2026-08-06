// index.js — camada segura do Kit Pioneiros 2026.
//
// Espelha, em servidor, exatamente as regras que vivem em
// app/lib/colecoes/colecao_campanha.dart e colecao_resgate.dart. O cliente
// calcula as mesmas coisas para saber QUAL TELA desenhar; aqui e o unico lugar
// que AUTORIZA gravacao.
//
// Se a regra mudar de um lado, precisa mudar do outro. A duplicacao e deliberada
// e tem preco conhecido: a alternativa seria confiar num veredito calculado no
// aparelho do jogador, que e exatamente o que a ordem de servico proibe.
//
// TUDO OU NADA: comprovante e itens sao gravados numa unica transacao. Falha no
// meio nao deixa item parcial; a proxima chamada replaneja do zero ou reconcilia.

const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { logger } = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();
const db = admin.firestore();

const CAMPAIGN_ID = 'pioneiros_2026';
const DOC_FLAGS = 'config/featureFlags';

// App Check: barra chamadas que nao venham de um binario legitimo do aplicativo.
//
// Entregue DESLIGADO de proposito. Ligar antes de o aplicativo publicar uma
// versao com App Check configurado derrubaria o resgate de todo mundo, inclusive
// do teste fechado. A ativacao e um passo do runbook, imediatamente antes da
// abertura publica, e nao exige alterar codigo: basta a variavel de ambiente.
//
//   firebase functions:config unset / firebase deploy --only functions
//   ENFORCE_APP_CHECK=true
const EXIGIR_APP_CHECK = process.env.ENFORCE_APP_CHECK === 'true';

/** Opcoes comuns a todas as funcoes deste arquivo. */
const OPCOES = {
  region: 'southamerica-east1',
  enforceAppCheck: EXIGIR_APP_CHECK,
};

/** Estados devolvidos ao cliente. Espelham SituacaoResgate no Dart. */
const RESULTADO = {
  concedido: 'claimed',
  reconciliado: 'reconciled',
  jaResgatado: 'alreadyClaimed',
};

// ---------------------------------------------------------------------------
// Elegibilidade — espelho de avaliarElegibilidade (colecao_campanha.dart).
// ---------------------------------------------------------------------------

/**
 * Converte Timestamp do Firestore, string ISO ou null num Date em UTC.
 * Recusa string sem fuso pela mesma razao do Dart: data ambigua seria lida com
 * o relogio de quem processa.
 */
function instante(valor, campo) {
  if (valor === null || valor === undefined) return null;
  if (typeof valor.toDate === 'function') return valor.toDate();
  if (typeof valor === 'string') {
    if (!/(Z|[+-]\d{2}:?\d{2})$/.test(valor)) {
      throw new HttpsError('failed-precondition', `campanha: ${campo} sem fuso horario explicito`);
    }
    const d = new Date(valor);
    if (Number.isNaN(d.getTime())) {
      throw new HttpsError('failed-precondition', `campanha: ${campo} nao e ISO-8601 valido`);
    }
    return d;
  }
  throw new HttpsError('failed-precondition', `campanha: ${campo} em formato inesperado`);
}

/**
 * Decide se o UID tem direito. `agora` e SEMPRE o relogio do servidor: nenhum
 * instante vindo do cliente entra nesta conta.
 */
function avaliarElegibilidade({ campanha, evidencia, flagLigada, agora }) {
  if (!flagLigada) return { elegivel: false, recusa: 'feature_flag_desligada' };
  if (campanha.status !== 'active') return { elegivel: false, recusa: 'campanha_inativa' };

  const inicio = instante(campanha.startAt, 'startAt');
  if (inicio && agora < inicio) return { elegivel: false, recusa: 'fora_da_janela_antes' };

  // Janela fechada no inicio e aberta no fim, igual ao Dart.
  const fim = instante(campanha.endAt, 'endAt');
  if (fim && agora >= fim) return { elegivel: false, recusa: 'fora_da_janela_depois' };

  const prazo = instante(campanha.claimDeadline, 'claimDeadline');
  if (prazo && agora >= prazo) return { elegivel: false, recusa: 'prazo_de_resgate_encerrado' };

  // Concessao administrativa vale em qualquer modo: e a valvula de correcao
  // caso a caso, sem alterar a campanha nem publicar versao nova.
  if (evidencia.concessaoAdministrativa) return { elegivel: true };

  const satisfaz = {
    allowlist: evidencia.naAllowlist,
    closedTest: evidencia.participouTesteFechado,
    matchInWindow: evidencia.concluiuPartidaNaJanela,
    hybrid: evidencia.naAllowlist || evidencia.participouTesteFechado || evidencia.concluiuPartidaNaJanela,
    adminGrant: false,
  }[campanha.eligibilityMode];

  if (satisfaz === undefined) {
    throw new HttpsError('failed-precondition', `eligibilityMode desconhecido: ${campanha.eligibilityMode}`);
  }
  return satisfaz ? { elegivel: true } : { elegivel: false, recusa: 'sem_evidencia' };
}

/**
 * Le a evidencia das fontes confiaveis. O jogador nao consegue escrever em
 * nenhuma delas (ver firestore.rules); o que ele mandar no payload da chamada e
 * ignorado de proposito — a funcao nao aceita evidencia por parametro.
 */
async function lerEvidencia(uid, tx) {
  const refElegivel = db.doc(`campaigns/${CAMPAIGN_ID}/eligible/${uid}`);
  const snap = await tx.get(refElegivel);
  if (!snap.exists) {
    return {
      naAllowlist: false,
      participouTesteFechado: false,
      concluiuPartidaNaJanela: false,
      concessaoAdministrativa: false,
    };
  }
  const d = snap.data();
  return {
    naAllowlist: d.naAllowlist === true,
    participouTesteFechado: d.participouTesteFechado === true,
    concluiuPartidaNaJanela: d.concluiuPartidaNaJanela === true,
    concessaoAdministrativa: d.concessaoAdministrativa === true,
  };
}

/** Chave determinista: `campaignId|version|userId`. Espelha ChaveResgate. */
function chaveIdempotencia(campaignId, version, uid) {
  for (const [campo, valor] of [['campaignId', campaignId], ['userId', uid]]) {
    if (!valor || String(valor).includes('|')) {
      throw new HttpsError('failed-precondition', `${campo} invalido para a chave de idempotencia`);
    }
  }
  return `${campaignId}|${version}|${uid}`;
}

/** Valida a composicao antes de gravar: nove itens onde o contrato diz dez e erro. */
function exigirComposicao(campanha) {
  const ids = campanha.rewardIds;
  if (!Array.isArray(ids) || ids.length === 0) {
    throw new HttpsError('failed-precondition', 'campanha sem rewardIds');
  }
  if (new Set(ids).size !== ids.length) {
    throw new HttpsError('failed-precondition', 'rewardIds com item repetido');
  }
  return ids;
}

// ---------------------------------------------------------------------------
// claimPioneerKit — a unica porta de concessao.
// ---------------------------------------------------------------------------

exports.claimPioneerKit = onCall(OPCOES, async (request) => {
  const uid = request.auth && request.auth.uid;
  if (!uid) {
    throw new HttpsError('unauthenticated', 'e preciso estar autenticado para resgatar');
  }

  const refCampanha = db.doc(`campaigns/${CAMPAIGN_ID}`);
  const refComprovante = db.doc(`users/${uid}/campaign_claims/${CAMPAIGN_ID}`);
  const refFlags = db.doc(DOC_FLAGS);

  const resultado = await db.runTransaction(async (tx) => {
    // Leituras primeiro: o Firestore exige todas as leituras antes de qualquer
    // escrita dentro da transacao.
    const [snapCampanha, snapFlags, snapComprovante] = await Promise.all([
      tx.get(refCampanha),
      tx.get(refFlags),
      tx.get(refComprovante),
    ]);

    if (!snapCampanha.exists) {
      throw new HttpsError('not-found', 'campanha nao configurada');
    }
    const campanha = snapCampanha.data();
    const rewardIds = exigirComposicao(campanha);
    const version = campanha.version;
    if (!Number.isInteger(version) || version < 1) {
      throw new HttpsError('failed-precondition', 'campanha com version invalida');
    }

    const evidencia = await lerEvidencia(uid, tx);

    // Quais itens o jogador ja tem. Lido DENTRO da transacao: ler fora abriria
    // janela para duas chamadas simultaneas planejarem a mesma concessao.
    const refsItens = rewardIds.map((id) => db.doc(`users/${uid}/inventory/${id}`));
    const snapsItens = await tx.getAll(...refsItens);
    const faltando = rewardIds.filter((_, i) => !snapsItens[i].exists);

    // --- Comprovante existente: o direito ja foi exercido. -----------------
    if (snapComprovante.exists) {
      const anterior = snapComprovante.data();

      // Estado ambiguo: pode ser reedicao legitima ou migracao mal feita.
      // Nao arbitrar — devolver erro e deixar a decisao para a administracao.
      if (anterior.campaignVersion !== version) {
        throw new HttpsError(
          'failed-precondition',
          'comprovante de outra versao da campanha; requer decisao administrativa',
        );
      }

      if (faltando.length === 0) {
        return { status: RESULTADO.jaResgatado, itemIds: rewardIds, gravados: 0 };
      }

      // Reconciliacao: acontece ANTES de checar elegibilidade, para que quem ja
      // recebeu nao perca itens porque a campanha encerrou ou a flag caiu.
      // `unlockedAt` reusa o instante do comprovante: o item que faltava foi
      // conquistado no dia do resgate, nao hoje.
      gravarItens(tx, { uid, itemIds: faltando, campanha, version, unlockedAt: anterior.claimedAt });
      return { status: RESULTADO.reconciliado, itemIds: rewardIds, gravados: faltando.length };
    }

    // --- Primeiro resgate: aqui a elegibilidade e obrigatoria. -------------
    const flagLigada = snapFlags.exists && snapFlags.data()[campanha.featureFlag] === true;
    const veredicto = avaliarElegibilidade({
      campanha,
      evidencia,
      flagLigada,
      agora: new Date(),
    });
    if (!veredicto.elegivel) {
      logger.info('resgate recusado', { uid, campaignId: CAMPAIGN_ID, recusa: veredicto.recusa });
      throw new HttpsError('permission-denied', veredicto.recusa);
    }

    const agora = admin.firestore.FieldValue.serverTimestamp();
    tx.set(refComprovante, {
      userId: uid,
      campaignId: CAMPAIGN_ID,
      campaignVersion: version,
      claimedAt: agora,
      itemIds: rewardIds,
      chaveIdempotencia: chaveIdempotencia(CAMPAIGN_ID, version, uid),
    });
    gravarItens(tx, { uid, itemIds: rewardIds, campanha, version, unlockedAt: agora });

    return { status: RESULTADO.concedido, itemIds: rewardIds, gravados: rewardIds.length };
  });

  logger.info('resgate concluido', {
    uid,
    campaignId: CAMPAIGN_ID,
    status: resultado.status,
    gravados: resultado.gravados,
  });
  return resultado;
});

/**
 * Grava os documentos de inventario com id DETERMINISTICO (`{itemId}`).
 *
 * `merge: true` de proposito: se o item ja existir por corrida ou retry, a
 * gravacao converge em vez de duplicar, e `equipped` escolhido pelo jogador nao
 * e sobrescrito — por isso ele nao aparece aqui.
 */
function gravarItens(tx, { uid, itemIds, campanha, version, unlockedAt }) {
  for (const itemId of itemIds) {
    tx.set(
      db.doc(`users/${uid}/inventory/${itemId}`),
      {
        userId: uid,
        itemId,
        collectionId: campanha.collectionId,
        source: 'campanha',
        campaignId: CAMPAIGN_ID,
        campaignVersion: version,
        unlockedAt,
      },
      { merge: true },
    );
  }
}

// ---------------------------------------------------------------------------
// Administracao. Duas funcoes, ambas exigindo claim `admin` e ambas auditadas.
// ---------------------------------------------------------------------------

function exigirAdmin(request) {
  const token = request.auth && request.auth.token;
  if (!token || token.admin !== true) {
    throw new HttpsError('permission-denied', 'acao restrita a administracao');
  }
  return request.auth.uid;
}

function registrarAuditoria(batchOuTx, { acao, autor, alvo, detalhe }) {
  batchOuTx.set(db.collection('audit').doc(), {
    acao,
    autor,
    alvo,
    campaignId: CAMPAIGN_ID,
    detalhe: detalhe || null,
    em: admin.firestore.FieldValue.serverTimestamp(),
  });
}

/**
 * Marca um UID como elegivel por decisao administrativa, sem alterar o codigo do
 * aplicativo nem o modo da campanha. Nao concede o kit: o jogador ainda resgata
 * pelo fluxo normal, o que mantem uma unica porta de gravacao de inventario.
 */
exports.grantPioneerEligibility = onCall(OPCOES, async (request) => {
  const autor = exigirAdmin(request);
  const alvo = request.data && request.data.uid;
  if (!alvo || typeof alvo !== 'string') {
    throw new HttpsError('invalid-argument', 'informe o uid do jogador');
  }

  const batch = db.batch();
  batch.set(
    db.doc(`campaigns/${CAMPAIGN_ID}/eligible/${alvo}`),
    {
      concessaoAdministrativa: true,
      concedidaPor: autor,
      concedidaEm: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
  registrarAuditoria(batch, { acao: 'grant_eligibility', autor, alvo, detalhe: request.data.motivo });
  await batch.commit();

  logger.info('elegibilidade administrativa concedida', { autor, alvo });
  return { status: 'ok', uid: alvo };
});

/**
 * Revogacao. NAO faz parte do fluxo comum — existe apenas como ferramenta de
 * correcao, exige acao administrativa explicita (`confirmar: true`) e deixa
 * trilha. Remove os itens e o comprovante numa unica transacao, para nao deixar
 * o jogador num estado meio concedido.
 */
exports.revokePioneerKit = onCall(OPCOES, async (request) => {
  const autor = exigirAdmin(request);
  const alvo = request.data && request.data.uid;
  if (!alvo || typeof alvo !== 'string') {
    throw new HttpsError('invalid-argument', 'informe o uid do jogador');
  }
  if (request.data.confirmar !== true) {
    throw new HttpsError('failed-precondition', 'revogacao exige confirmar: true');
  }
  const motivo = request.data.motivo;
  if (!motivo || typeof motivo !== 'string') {
    throw new HttpsError('invalid-argument', 'revogacao exige motivo registrado em auditoria');
  }

  const removidos = await db.runTransaction(async (tx) => {
    const refComprovante = db.doc(`users/${alvo}/campaign_claims/${CAMPAIGN_ID}`);
    const snapComprovante = await tx.get(refComprovante);
    if (!snapComprovante.exists) {
      throw new HttpsError('not-found', 'nao ha resgate a revogar para este jogador');
    }
    const itemIds = snapComprovante.data().itemIds || [];

    for (const itemId of itemIds) {
      tx.delete(db.doc(`users/${alvo}/inventory/${itemId}`));
    }
    tx.delete(refComprovante);
    registrarAuditoria(tx, { acao: 'revoke_kit', autor, alvo, detalhe: motivo });
    return itemIds.length;
  });

  logger.warn('kit revogado', { autor, alvo, removidos, motivo });
  return { status: 'ok', uid: alvo, removidos };
});
