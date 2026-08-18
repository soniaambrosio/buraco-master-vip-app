/**
 * propriedade.js — DE QUEM E ESTA COMPRA. Logica pura, sem Firestore e sem rede.
 *
 * O DEFEITO QUE ESTE ARQUIVO EXISTE PARA FECHAR
 *
 * Ate a homologacao adversarial, a resposta para "de quem e esta compra?" era
 * *de quem apresentou o token primeiro*. `validarCompraPlay` gravava
 * `compras/{hash}` com o uid do chamador ANTES de perguntar a Google, e a
 * resposta da Google nunca era conferida contra identidade nenhuma. Quem tivesse
 * o `purchaseToken` de outra pessoa e chegasse antes ficava com o VIP, e o
 * pagante recebia `permission-denied` para sempre. Era o achado A-1.
 *
 * A correcao nao e "gravar depois". E TER UMA AUTORIDADE: um identificador opaco
 * que o backend concede a conta autenticada ANTES da compra, que o aplicativo
 * entrega a Play como `obfuscatedAccountId`, e que a Google devolve dentro da
 * resposta autoritativa. A propriedade passa a vir de onde sempre deveria ter
 * vindo — do que a Google diz sobre a compra —, e nao da ordem de chegada.
 *
 * O QUE ESTE ARQUIVO FAZ, E SO ISSO
 *
 *   - le o identificador nas DUAS formas de resposta da Play, que sao diferentes;
 *   - valida a resposta antes de qualquer acesso a campo;
 *   - decide o veredito de propriedade dado um uid esperado e um uid resolvido.
 *
 * Ele nao fala com o Firestore (quem resolve identificador para uid e o store) e
 * nao fala com a Google (quem consulta e `index.js`). Sendo puro, `node --test`
 * o exercita sem `node_modules`, que e a disciplina do resto deste codebase.
 *
 * OS CODIGOS SAO FECHADOS, E ESSA E A OUTRA METADE DA CORRECAO
 *
 * `MOTIVO` e o conjunto COMPLETO do que pode ser persistido ou devolvido como
 * causa. Nenhuma string de terceiro entra: nem `e.message` da `googleapis`, nem
 * corpo de resposta, nem texto livre. Era o achado M-2 — `index.js` gravava
 * `e.message` em `compras/{hash}`, documento que o dono le.
 *
 * A grafia e `minusculas_com_sublinhado` porque e a que este codebase ja usa para
 * causa persistida (`token_superado`, `verificacao_antiga`, `corpo_ilegivel`,
 * `em_validacao`). A OS listou exemplos em maiuscula e mandou, na mesma secao,
 * seguir o padrao existente; seguir o padrao e o que evita duas convencoes de
 * nome convivendo dentro do mesmo documento.
 */

'use strict';

/**
 * Todo motivo fechado que pode ser gravado no Firestore, devolvido ao cliente ou
 * registrado em log. Conjunto FECHADO: se um caso novo aparecer, ele entra aqui
 * com nome proprio, e nao como texto solto.
 */
const MOTIVO = {
  /** A Google nao confirmou a compra (estado invalido, produto nao comprado). */
  COMPRA_NAO_CONFIRMADA: 'compra_nao_confirmada',
  /** A resposta da Google nao trouxe identificador de conta. Compra sem dono. */
  VINCULO_AUSENTE: 'vinculo_ausente',
  /** O identificador veio, mas nao pertence a nenhuma conta conhecida. */
  VINCULO_DESCONHECIDO: 'vinculo_desconhecido',
  /** O identificador pertence a OUTRA conta que nao a autenticada. */
  VINCULO_DIVERGENTE: 'vinculo_divergente',
  /** A notificacao nao e do applicationId oficial, ou nao declara qual e. */
  PACOTE_DIVERGENTE: 'pacote_divergente',
  /** A resposta da Google nao tem a forma que o contrato descreve. */
  RESPOSTA_PLAY_INVALIDA: 'resposta_play_invalida',
  /** A Play Developer API falhou de um jeito que retentar resolve. */
  FALHA_TEMPORARIA_PLAY: 'falha_temporaria_play',
};

const MOTIVOS_CONHECIDOS = new Set(Object.values(MOTIVO));

/** Um motivo pode ser persistido? Guarda contra texto livre entrar por descuido. */
function motivoValido(codigo) {
  return typeof codigo === 'string' && MOTIVOS_CONHECIDOS.has(codigo);
}

/**
 * Tamanho maximo do `obfuscatedAccountId` aceito pela Play Billing Library.
 * Nao e escolha nossa: e o limite da plataforma, e um identificador maior seria
 * truncado na compra e nunca mais bateria com o que esta gravado aqui.
 */
const TAMANHO_MAXIMO_VINCULO = 64;

/** Formato aceito: hexadecimal, para que nada alem de bytes aleatorios caiba. */
const FORMATO_VINCULO = /^[0-9a-f]{32,64}$/;

/**
 * O identificador tem a forma que ESTA autoridade emite?
 *
 * Vale para o que chega da Google, e nao so para o que sai daqui: um
 * identificador com outra forma nao foi emitido por nos, e trata-lo como
 * "provavelmente e nosso" seria reabrir a porta pelo lado de dentro.
 */
function vinculoBemFormado(valor) {
  return (
    typeof valor === 'string'
    && valor.length <= TAMANHO_MAXIMO_VINCULO
    && FORMATO_VINCULO.test(valor)
  );
}

/**
 * O identificador de conta que a Google devolveu, ou `null`.
 *
 * AS DUAS RESPOSTAS TEM FORMATOS DIFERENTES, e ler so uma delas deixaria metade
 * do catalogo sem propriedade verificavel:
 *
 *   SubscriptionPurchaseV2  externalAccountIdentifiers.obfuscatedExternalAccountId
 *   ProductPurchase         obfuscatedExternalAccountId  (na raiz)
 *
 * A leitura e defensiva de ponta a ponta porque esta funcao roda sobre um corpo
 * de terceiro: qualquer campo pode faltar, ser nulo ou ter outro tipo.
 */
function identificadorDaResposta(resposta) {
  if (!resposta || typeof resposta !== 'object' || Array.isArray(resposta)) return null;

  const raiz = resposta.obfuscatedExternalAccountId;
  if (typeof raiz === 'string' && raiz !== '') return raiz;

  const externos = resposta.externalAccountIdentifiers;
  if (externos && typeof externos === 'object' && !Array.isArray(externos)) {
    const aninhado = externos.obfuscatedExternalAccountId;
    if (typeof aninhado === 'string' && aninhado !== '') return aninhado;
  }
  return null;
}

/**
 * O token que esta compra SUBSTITUI, quando ha upgrade, downgrade ou reassinatura.
 *
 * A Google encadeia assinaturas por `linkedPurchaseToken`: o token novo aponta
 * para o antigo. Sem ler isso, uma troca de plano ficaria parada em
 * `token_superado` — o entitlement guarda o hash do token velho e recusaria o
 * novo — ate alguem abrir o aplicativo. Com isso, a troca entra pela notificacao.
 *
 * O QUE ISTO NAO AUTORIZA: herdar dono. A propriedade continua saindo do
 * identificador da resposta ATUAL. O token ligado so diz qual entitlement esta
 * sendo substituido, nunca de quem ele e.
 */
function tokenLigadoDaResposta(resposta) {
  if (!resposta || typeof resposta !== 'object' || Array.isArray(resposta)) return null;
  const ligado = resposta.linkedPurchaseToken;
  return typeof ligado === 'string' && ligado !== '' ? ligado : null;
}

/**
 * A resposta de assinatura tem a forma que o contrato descreve?
 *
 * Roda ANTES de qualquer acesso a campo, e e a correcao do achado M-1: a
 * consolidacao protegia o item dentro do laco e usava o mesmo item sem protecao
 * fora dele, entao um elemento nulo em `lineItems` virava TypeError nao tratado —
 * e a mensagem virava pilula envenenada, reentregue pelo Pub/Sub ate a retencao
 * do topico expirar.
 *
 * Recusa CONTROLADA, e nunca mutacao parcial: quem chama recebe `{ok: false}` e
 * decide, em vez de receber uma excecao no meio de uma consolidacao.
 *
 * @returns {{ok: true}|{ok: false, motivo: string, detalhe: string}}
 */
function validarRespostaAssinatura(resposta) {
  const recusa = (detalhe) => ({ ok: false, motivo: MOTIVO.RESPOSTA_PLAY_INVALIDA, detalhe });

  if (!resposta || typeof resposta !== 'object' || Array.isArray(resposta)) {
    return recusa('corpo_nao_e_objeto');
  }
  if (resposta.subscriptionState != null && typeof resposta.subscriptionState !== 'string') {
    return recusa('estado_nao_e_texto');
  }

  const itens = resposta.lineItems;
  // Ausente e caso legitimo: assinatura sem item e assinatura sem prazo, e
  // `consolidarAssinatura` ja a trata como sem acesso. O que nao pode e a
  // colecao EXISTIR malformada e ser percorrida como se estivesse certa.
  if (itens == null) return { ok: true };
  if (!Array.isArray(itens)) return recusa('lineItems_nao_e_lista');

  for (let i = 0; i < itens.length; i += 1) {
    const item = itens[i];
    if (item == null) return recusa(`lineItems_${i}_nulo`);
    if (typeof item !== 'object' || Array.isArray(item)) return recusa(`lineItems_${i}_nao_e_objeto`);
    if (item.productId != null && typeof item.productId !== 'string') {
      return recusa(`lineItems_${i}_produto_nao_e_texto`);
    }
    if (item.expiryTime != null) {
      const t = new Date(item.expiryTime).getTime();
      if (Number.isNaN(t)) return recusa(`lineItems_${i}_prazo_incoerente`);
    }
  }
  return { ok: true };
}

/** Mesma conferencia, para a resposta de produto avulso. */
function validarRespostaProduto(resposta) {
  const recusa = (detalhe) => ({ ok: false, motivo: MOTIVO.RESPOSTA_PLAY_INVALIDA, detalhe });
  if (!resposta || typeof resposta !== 'object' || Array.isArray(resposta)) {
    return recusa('corpo_nao_e_objeto');
  }
  if (resposta.purchaseState != null && typeof resposta.purchaseState !== 'number') {
    return recusa('purchaseState_nao_e_numero');
  }
  return { ok: true };
}

/**
 * O veredito de propriedade.
 *
 * Tres recusas distintas, e a distincao importa para quem opera: compra sem
 * identificador (legado, ou aplicativo que nao preparou a compra), identificador
 * que nao conhecemos, e identificador de OUTRA conta. Colapsar as tres num
 * "negado" faria a operacao nao conseguir separar "assinante antigo" de
 * "tentativa de tomar compra alheia".
 *
 * @param {object} args
 * @param {string|null} args.identificador  o que a Google devolveu
 * @param {string|null} args.uidResolvido   quem a autoridade interna diz ser o dono
 * @param {string|null} [args.uidEsperado]  a conta autenticada, quando existe uma
 * @returns {{ok: true, uid: string}|{ok: false, motivo: string}}
 */
function decidirPropriedade({ identificador, uidResolvido, uidEsperado = null }) {
  if (!vinculoBemFormado(identificador)) {
    return { ok: false, motivo: MOTIVO.VINCULO_AUSENTE };
  }
  if (typeof uidResolvido !== 'string' || uidResolvido === '') {
    return { ok: false, motivo: MOTIVO.VINCULO_DESCONHECIDO };
  }
  // Quando ha sessao, a compra tem de ser DELA. Quando nao ha (RTDN), o dono e
  // simplesmente quem a autoridade resolveu — nunca quem pediu primeiro.
  if (uidEsperado != null && uidResolvido !== uidEsperado) {
    return { ok: false, motivo: MOTIVO.VINCULO_DIVERGENTE };
  }
  return { ok: true, uid: uidResolvido };
}

module.exports = {
  MOTIVO,
  MOTIVOS_CONHECIDOS,
  TAMANHO_MAXIMO_VINCULO,
  FORMATO_VINCULO,
  motivoValido,
  vinculoBemFormado,
  identificadorDaResposta,
  tokenLigadoDaResposta,
  validarRespostaAssinatura,
  validarRespostaProduto,
  decidirPropriedade,
};
