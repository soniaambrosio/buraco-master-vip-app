/**
 * reconciliacao.js — CONSULTA AUTORITATIVA + PROPRIEDADE + consolidacao + gravacao.
 *
 * O NUCLEO QUE TODO CAMINHO ATRAVESSA
 *
 * Tres entradas diferentes precisam da mesma coisa — perguntar a Google qual e o
 * estado da assinatura AGORA, descobrir DE QUEM ela e, e gravar o que ela
 * responder:
 *
 *   validarCompraPlay                 compra ou renovacao chegando pelo app
 *   notificacoesPlay (RTDN)           evento vindo do Pub/Sub
 *   reconciliarEntitlementDoJogador   saida de emergencia da administracao
 *
 * Ter tres copias disso seria ter tres politicas economicas se afastando com o
 * tempo. Ha uma so, aqui, e as tres entradas a chamam.
 *
 * O QUE MUDOU NA CORRECAO DE PROPRIEDADE
 *
 * Antes, o `uid` era PARAMETRO: quem chamava dizia de quem era a compra, e
 * `validarCompraPlay` dizia "de quem me chamou". Era por ali que o achado A-1
 * entrava — o primeiro portador do token escolhia o beneficiario.
 *
 * Agora o `uid` e RESULTADO. Ele sai do `obfuscatedExternalAccountId` que a
 * Google devolve dentro da propria resposta autoritativa, resolvido contra o
 * indice de vinculacao. Quem tem sessao (validacao, reconciliacao manual) passa
 * `uidEsperado`, e a igualdade e EXIGIDA; quem nao tem (RTDN) recebe o dono que a
 * autoridade resolver, e nunca o primeiro que aparecer.
 *
 * Sem identificador, com vinculo desconhecido ou com vinculo de outra conta,
 * nada e gravado. Falha fechada: sem dono comprovavel nao ha direito a conceder
 * nem a retirar.
 *
 * O CARIMBO VEM ANTES DA REDE, E ISSO E A REGRA DE ORDEM INTEIRA
 *
 * `consultadoEm` e capturado ANTES da chamada, de proposito: uma resposta que
 * demorou dez segundos descreve o mundo de dez segundos atras. Carimba-la com o
 * instante da VOLTA a faria ganhar de uma consulta mais nova que respondeu
 * rapido — e `decidirAtualizacao` compara exatamente esse carimbo. Inverter as
 * duas linhas reintroduz o defeito de ordem sem que nenhum teste de dominio
 * perceba, porque o dominio recebe o carimbo pronto. Por isso o teste `RTDN-18`
 * prova a ordem daqui, e nao de la.
 */

'use strict';

const { consolidarAssinatura } = require('./entitlement');
const { chaveDaCompra } = require('./entitlementStore');
const {
  identificadorDaResposta,
  tokenLigadoDaResposta,
  validarRespostaAssinatura,
  decidirPropriedade,
} = require('./propriedade');

/**
 * @param {object} portas
 * @param {function(string): Promise<object>} portas.consultarAssinatura
 *        pergunta a Google Play Developer API pelo token. Pode LANCAR — e
 *        lancar e o comportamento desejado: ver o cabecalho de `rtdn.js`.
 * @param {function(string|null): Promise<string|null>} portas.uidDoVinculo
 *        `criarStore(...).uidDoVinculo` — a autoridade de propriedade
 * @param {function(object, object=): Promise<object>} portas.aplicarProposta
 *        `criarStore(...).aplicarProposta`
 * @param {function(): string} [portas.agora] relogio, em ISO-8601
 */
function criarReconciliador({ consultarAssinatura, uidDoVinculo, aplicarProposta, agora }) {
  const relogio = agora || (() => new Date().toISOString());

  if (typeof uidDoVinculo !== 'function') {
    // Sem a porta de propriedade este modulo nao tem como saber de quem e a
    // compra, e a unica alternativa seria adivinhar — que e o defeito que a
    // correcao veio fechar. Melhor nao existir.
    throw new Error('criarReconciliador exige a porta uidDoVinculo');
  }

  /**
   * De quem e a compra que esta resposta descreve?
   *
   * Serve para assinatura e para produto avulso: os dois corpos carregam o
   * identificador, em lugares diferentes, e `identificadorDaResposta` conhece os
   * dois. Nao consulta a Google — recebe a resposta ja obtida, porque quem chama
   * costuma precisar dela para outra coisa tambem, e uma segunda consulta seria
   * uma segunda oportunidade de divergir.
   *
   * @param {object} resposta          corpo devolvido pela Play Developer API
   * @param {string|null} uidEsperado  a conta autenticada, quando existe uma
   * @returns {{ok: true, uid: string, identificador: string}|{ok: false, motivo: string}}
   */
  async function resolverPropriedade(resposta, uidEsperado = null) {
    const identificador = identificadorDaResposta(resposta);
    const uidResolvido = await uidDoVinculo(identificador);
    const veredito = decidirPropriedade({ identificador, uidResolvido, uidEsperado });
    return veredito.ok ? { ...veredito, identificador } : veredito;
  }

  /**
   * Consulta a Google e resolve a propriedade, sem gravar nada.
   *
   * O caminho TERMINAL do RTDN precisa exatamente disto e de mais nada: o estado
   * economico ele tira do proprio evento (a Google nao devolve um estado que
   * diga "estornado"), mas o DONO ele nao tem como saber sozinho. Deixar a
   * consulta aqui, e nao la, mantem uma so porta para a Play Developer API.
   *
   * @returns {{ok: true, uid, identificador, resposta, consultadoEm}
   *          |{ok: false, motivo: string, detalhe?: string}}
   */
  async function verificarToken(tokenCompra, uidEsperado = null) {
    const consultadoEm = relogio();
    const resposta = await consultarAssinatura(tokenCompra);

    const forma = validarRespostaAssinatura(resposta);
    if (!forma.ok) return forma;

    const dono = await resolverPropriedade(resposta, uidEsperado);
    if (!dono.ok) return dono;

    return { ...dono, resposta, consultadoEm };
  }

  /**
   * Grava o que uma resposta JA VERIFICADA diz, para um dono JA RESOLVIDO.
   *
   * Existe separada de `reconsultarEAplicar` por um motivo estreito e concreto:
   * `validarCompraPlay` precisa consultar a Google ANTES de qualquer persistencia
   * — e essa e a correcao de ordem do A-1 — e depois usa a MESMA resposta para
   * montar o registro da compra. Fazer esta funcao consultar de novo produziria
   * duas respostas para uma compra so, e a segunda poderia contradizer a
   * primeira.
   */
  async function aplicarRespostaVerificada({
    uid,
    resposta,
    consultadoEm,
    tokenCompra,
    produtoId,
    fonte,
    eventoEm = null,
    eventoTipo = null,
    evento = null,
  }) {
    const consolidado = consolidarAssinatura(resposta, consultadoEm);
    const ligado = tokenLigadoDaResposta(resposta);

    // O `uid` volta junto porque quem chamou nao o escolheu — ele foi RESOLVIDO.
    // Sem devolve-lo, o chamador teria de adivinhar em quem gravou.
    const resultado = await aplicarProposta(
      {
        uid,
        ...consolidado,
        produtoId: consolidado.produtoId || produtoId || null,
        origem: 'play',
        purchaseTokenHash: chaveDaCompra(tokenCompra),
        // O token que ESTA compra substitui, quando ha troca de plano. Ele nunca
        // transfere dono — ver `decidirAtualizacao` em entitlement.js.
        purchaseTokenHashLigado: ligado ? chaveDaCompra(ligado) : null,
        purchaseToken: tokenCompra,
        verificadoEm: consultadoEm,
        eventoEm,
        eventoTipo,
        fonte,
      },
      evento
    );
    return { ...resultado, uid };
  }

  /**
   * Consulta autoritativa + forma + propriedade + consolidacao + gravacao.
   *
   * A ORDEM E O CONTEUDO desta funcao: consultar antes de decidir, conferir a
   * forma antes de ler campo, resolver o dono antes de gravar, gravar so no fim.
   *
   * @param {object} args
   * @param {string} args.tokenCompra         o token CRU — e a credencial de consulta
   * @param {string|null} [args.uidEsperado]  exigido igual, quando ha sessao
   * @param {string} args.fonte               'validacao' | 'rtdn' | 'reconciliacao'
   */
  async function reconsultarEAplicar({
    uidEsperado = null,
    produtoId,
    tokenCompra,
    fonte,
    eventoEm = null,
    eventoTipo = null,
    evento = null,
  }) {
    const dono = await verificarToken(tokenCompra, uidEsperado);
    if (!dono.ok) {
      return { aplicado: false, motivo: dono.motivo, detalhe: dono.detalhe };
    }

    return aplicarRespostaVerificada({
      uid: dono.uid,
      resposta: dono.resposta,
      consultadoEm: dono.consultadoEm,
      tokenCompra,
      produtoId,
      fonte,
      eventoEm,
      eventoTipo,
      evento,
    });
  }

  return {
    resolverPropriedade,
    verificarToken,
    aplicarRespostaVerificada,
    reconsultarEAplicar,
  };
}

module.exports = { criarReconciliador };
