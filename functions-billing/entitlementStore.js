/**
 * entitlementStore.js — as ESCRITAS do entitlement, com o Firestore injetado.
 *
 * POR QUE ESTE ARQUIVO NASCEU
 *
 * Ate aqui, `aplicarProposta` e `titularDoToken` moravam dentro de `index.js`,
 * coladas em `getFirestore()`. Isso deixava a parte mais delicada do desenho —
 * a TRANSACAO que decide e marca "ja processei" no mesmo commit — como a unica
 * coisa do codebase que nenhum teste alcancava: importar `index.js` puxa
 * `firebase-functions`, `firebase-admin` e `googleapis`, e este projeto roda
 * `node --test` sem `node_modules` de proposito (ver `package.json`).
 *
 * A correcao nao e "mockar o firebase-admin". E parar de chamar o singleton:
 * `criarStore` recebe o `db` e o carimbo de servidor por parametro. Em producao
 * entram `getFirestore()` e `FieldValue.serverTimestamp()`; no teste entra o
 * Firestore falso de `test/apoio/firestore_falso.js`, que implementa contencao
 * de verdade e por isso consegue provar duas notificacoes concorrentes.
 *
 * NENHUMA REGRA ECONOMICA MUDOU AQUI. O corpo das funcoes e o mesmo que estava
 * em `index.js`; o que mudou foi de onde vem o `db`. As decisoes continuam todas
 * em `entitlement.js`, puras.
 */

'use strict';

const crypto = require('crypto');

const {
  decidirAtualizacao,
  documentosDeEntitlement,
  rotuloToken,
} = require('./entitlement');
const { vinculoBemFormado, TAMANHO_MAXIMO_VINCULO } = require('./propriedade');

/** Fonte canonica do direito VIP. Escrita SO por este codebase. */
const COL_ENTITLEMENT = 'playerEntitlements';

/** Trilha de notificacoes processadas — id do documento = messageId do Pub/Sub. */
const COL_EVENTOS = 'billingEvents';

/**
 * Registro da COMPRA — id = hash do token.
 *
 * MUDOU DE PAPEL na correcao de propriedade. Ele era a autoridade de
 * titularidade: quem estivesse gravado aqui era o dono, e quem gravasse
 * primeiro ficava gravado. Era exatamente esse o achado A-1.
 *
 * Hoje ele e o registro de "esta compra ja foi creditada", e mais nada. Quem
 * responde "de quem e?" e o indice de vinculacao abaixo, alimentado pelo
 * identificador que a Google devolve. O uid continua gravado aqui, porem como
 * CONSEQUENCIA da verificacao, nunca como fonte dela.
 */
const COL_COMPRAS = 'compras';

/**
 * A VINCULACAO CANONICA entre a conta do aplicativo e a compra da Google.
 *
 *   playerBillingIdentity/{uid}         -> { contaOfuscada }
 *   billingAccountIndex/{contaOfuscada} -> { uid }
 *
 * Duas colecoes para a mesma relacao, e nao uma, porque as duas perguntas sao
 * feitas em momentos opostos e por caminhos opostos: `prepararCompraPlay` sabe o
 * uid e quer o identificador; o RTDN so tem o identificador que a Google
 * devolveu e quer o uid — e o RTDN nao tem sessao, entao nao ha por onde varrer
 * sem indice. As duas sao escritas SEMPRE juntas, na mesma transacao.
 *
 * Fechadas ao cliente em `firestore.rules` (`if false` para leitura e escrita). O
 * identificador nao e segredo de autenticacao — sozinho ele nao concede nada —,
 * mas expo-lo permitiria correlacionar conta e compra de fora, e nao ha motivo
 * para isso ser possivel.
 */
const COL_IDENTIDADE_BILLING = 'playerBillingIdentity';
const COL_INDICE_VINCULO = 'billingAccountIndex';

/**
 * Um identificador de vinculacao novo.
 *
 * Bytes aleatorios, e nao derivacao do uid, por duas razoes. A primeira e que
 * uma derivacao precisaria ser invertida para o RTDN resolver o dono, e hash nao
 * se inverte — ou seja, o indice reverso seria necessario de qualquer jeito. A
 * segunda e que, existindo o indice, um valor aleatorio nao carrega correlacao
 * nenhuma com a conta, nem mesmo para quem conheca a formula.
 *
 * 24 bytes viram 48 caracteres hexadecimais: bem dentro do limite de 64 da Play
 * Billing Library, e 192 bits de espaco — colisao nao acontece, e ainda assim a
 * transacao confere.
 */
function gerarVinculo() {
  return crypto.randomBytes(24).toString('hex');
}

/**
 * Chave do registro de compra. Hash do token porque o token e longo demais
 * para ID de documento do Firestore (limite de 1500 bytes) e nao ha motivo
 * para guardar o valor bruto como identificador.
 *
 * Mora AQUI, e nao em `entitlement.js`, porque isto e identidade de DOCUMENTO:
 * e a chave de `compras/{hash}` e o `purchaseTokenHash` do entitlement. `crypto`
 * e modulo embutido do Node, entao este arquivo continua carregavel por
 * `node --test` sem `node_modules`.
 */
function chaveDaCompra(tokenCompra) {
  return crypto.createHash('sha256').update(tokenCompra).digest('hex');
}

/**
 * @param {object} deps
 * @param {object} deps.db      Firestore (Admin SDK) ou equivalente
 * @param {function} deps.carimbo  produz o sentinel de timestamp do servidor
 */
function criarStore({ db, carimbo }) {
  /**
   * Os dois documentos do entitlement de um jogador.
   *
   *   playerEntitlements/{uid}                   o dono le: estado, prazo, produto
   *   playerEntitlements/{uid}/interno/billing   ninguem le: token e verificacao
   *
   * Dois porque regra do Firestore libera o documento INTEIRO. A separacao repete
   * a que a moderacao fez entre `reports` e `reportReceipts`, pelo mesmo motivo.
   */
  function refsEntitlement(uid) {
    const publico = db.collection(COL_ENTITLEMENT).doc(uid);
    return { publico, interno: publico.collection('interno').doc('billing') };
  }

  /**
   * Grava a proposta, se ela puder ser gravada.
   *
   * TODA escrita de entitlement passa por aqui, e por uma razao so: a decisao
   * precisa ser tomada com o documento RELIDO DENTRO DA TRANSACAO. Ler o estado,
   * decidir fora e escrever depois deixaria duas notificacoes simultaneas — ou uma
   * validacao manual concorrendo com um RTDN — gravarem estados que ignoram um ao
   * outro, e a ultima a commitar venceria mesmo tendo consultado a Google primeiro.
   *
   * `set` sem `merge` e deliberado: o estado consolidado e completo, e um merge
   * deixaria campo velho de um estado anterior sobrevivendo ao lado do novo.
   *
   * @param {object} proposta ver `decidirAtualizacao` em entitlement.js
   * @param {{id: string, tipo?: number|null}} [evento]
   *        notificacao que originou a proposta. Registrada na MESMA transacao: o
   *        efeito e a marca de "ja processei" nascem juntos, ou nao nascem.
   */
  async function aplicarProposta(proposta, evento) {
    const { publico, interno } = refsEntitlement(proposta.uid);
    const refEvento = evento ? db.collection(COL_EVENTOS).doc(evento.id) : null;

    return db.runTransaction(async (tx) => {
      const [pub, int, ev] = await Promise.all([
        tx.get(publico),
        tx.get(interno),
        refEvento ? tx.get(refEvento) : Promise.resolve(null),
      ]);

      // Reentrega do Pub/Sub. A entrega e "pelo menos uma vez" por contrato, entao
      // ver a mesma mensagem duas vezes e rotina, nao anomalia.
      if (ev && ev.exists && ev.data().estado === 'concluido') {
        return { aplicado: false, motivo: 'evento_repetido' };
      }

      const atual =
        pub.exists || int.exists
          ? { ...(pub.data() || {}), ...(int.data() || {}) }
          : null;

      const decisao = decidirAtualizacao(atual, proposta);

      if (decisao.aplicar) {
        const docs = documentosDeEntitlement(atual, proposta);
        tx.set(publico, docs.publico);
        tx.set(interno, docs.interno);
      }

      if (refEvento) {
        tx.set(refEvento, {
          messageId: evento.id,
          estado: 'concluido',
          tipo: evento.tipo != null ? evento.tipo : null,
          decisao: decisao.motivo,
          aplicado: decisao.aplicar,
          uid: proposta.uid,
          // Rotulo curto do hash — nunca o token, nunca o hash inteiro.
          token: rotuloToken(proposta.purchaseTokenHash),
          processadoEm: carimbo(),
        });
      }

      return {
        aplicado: decisao.aplicar,
        motivo: decisao.motivo,
        estado: decisao.aplicar ? proposta.estado : atual && atual.estado,
        vipAtivo: decisao.aplicar
          ? proposta.vipAtivo === true
          : Boolean(atual && atual.vipAtivo),
      };
    });
  }

  /**
   * O identificador de vinculacao desta conta, criando-o se ainda nao houver.
   *
   * ESTA E A PREPARACAO DA COMPRA. Ela roda ANTES de o dialogo da Play abrir, com
   * o uid ja autenticado, e o valor que devolve e o que o aplicativo entrega a
   * Google como `obfuscatedAccountId`. E por ele que a Google, mais tarde, dira
   * de quem e a compra.
   *
   * ESTAVEL: chamada de novo, devolve o mesmo valor. Uma conta tem UM vinculo, e
   * um vinculo pertence a UMA conta — as duas direcoes escritas na mesma
   * transacao, para que nunca exista meia relacao.
   *
   * CONCORRENTE: duas chamadas simultaneas geram identificadores diferentes, mas
   * so uma commita; a outra perde a versao do documento, relê e devolve o que ja
   * existe. Uma autoridade, nao duas — provado no teste de concorrencia.
   *
   * O identificador GERADO ANTES das leituras de proposito: o Firestore exige
   * todas as leituras antes de qualquer escrita, e o documento do indice so pode
   * ser lido depois de existir o id que o nomeia. Gerar e descartar um valor
   * aleatorio nao custa nada; ler depois de escrever seria erro de transacao.
   *
   * @param {string} uid
   * @param {function(): string} [gerar] injetavel, para o teste ditar colisao
   */
  async function garantirVinculo(uid, gerar) {
    if (typeof uid !== 'string' || uid === '') {
      throw new Error('garantirVinculo exige uid');
    }
    const refIdentidade = db.collection(COL_IDENTIDADE_BILLING).doc(uid);

    return db.runTransaction(async (tx) => {
      const candidato = (gerar || gerarVinculo)();
      if (!vinculoBemFormado(candidato)) {
        throw new Error('gerador produziu vinculo com forma invalida');
      }
      const refIndice = db.collection(COL_INDICE_VINCULO).doc(candidato);

      const [identidade, indice] = await Promise.all([
        tx.get(refIdentidade),
        tx.get(refIndice),
      ]);

      const jaTem = identidade.exists ? identidade.data().contaOfuscada : null;
      if (vinculoBemFormado(jaTem)) {
        return { contaOfuscada: jaTem, criado: false };
      }

      // Colisao de 192 bits nao acontece; se acontecer, isto para em vez de
      // apontar o vinculo de um jogador para a conta de outro.
      if (indice.exists && indice.data().uid !== uid) {
        throw new Error('colisao de vinculo de billing');
      }

      tx.set(refIdentidade, { uid, contaOfuscada: candidato, criadoEm: carimbo() });
      tx.set(refIndice, { uid, contaOfuscada: candidato, criadoEm: carimbo() });
      return { contaOfuscada: candidato, criado: true };
    });
  }

  /**
   * De quem e este identificador de vinculacao?
   *
   * A UNICA porta de propriedade que o RTDN tem. Ele nao tem sessao, nao sabe o
   * que e um UID do Firebase e so recebe o que a Google devolveu — entao a
   * resposta vem daqui ou nao vem de lugar nenhum. Devolver `null` faz o chamador
   * FALHAR FECHADO, que e o comportamento correto: sem dono comprovavel, nao ha
   * direito a conceder nem a retirar.
   *
   * A conferencia de forma vem antes da leitura de proposito. Um identificador
   * com outra forma nao foi emitido por esta autoridade, e um id de documento
   * arbitrario nao deve nem virar uma leitura.
   */
  async function uidDoVinculo(contaOfuscada) {
    if (!vinculoBemFormado(contaOfuscada)) return null;
    const doc = await db.collection(COL_INDICE_VINCULO).doc(contaOfuscada).get();
    if (!doc.exists) return null;
    const uid = doc.data().uid;
    return typeof uid === 'string' && uid !== '' ? uid : null;
  }

  /**
   * A mensagem ja foi processada ate o fim?
   *
   * Atalho barato, cobrado ANTES de gastar uma chamada de rede. NAO e a barreira
   * de idempotencia — essa esta dentro da transacao de `aplicarProposta`, que e
   * onde a corrida existe de verdade.
   */
  async function eventoConcluido(messageId) {
    if (!messageId) return false;
    const doc = await db.collection(COL_EVENTOS).doc(messageId).get();
    return doc.exists && doc.data().estado === 'concluido';
  }

  /** Anota um evento que nao produziu efeito, para a trilha nao ter buraco. */
  async function registrarEventoSemEfeito(messageId, dados) {
    if (!messageId) return;
    await db.collection(COL_EVENTOS).doc(messageId).set(
      {
        messageId,
        estado: 'concluido',
        aplicado: false,
        processadoEm: carimbo(),
        ...dados,
      },
      { merge: true }
    );
  }

  return {
    refsEntitlement,
    aplicarProposta,
    garantirVinculo,
    uidDoVinculo,
    eventoConcluido,
    registrarEventoSemEfeito,
  };
}

module.exports = {
  COL_ENTITLEMENT,
  COL_EVENTOS,
  COL_COMPRAS,
  COL_IDENTIDADE_BILLING,
  COL_INDICE_VINCULO,
  TAMANHO_MAXIMO_VINCULO,
  chaveDaCompra,
  gerarVinculo,
  criarStore,
};
