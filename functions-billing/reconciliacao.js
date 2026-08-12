/**
 * reconciliacao.js — CONSULTA AUTORITATIVA + consolidacao + gravacao.
 *
 * O NUCLEO QUE TODO CAMINHO ATRAVESSA
 *
 * Quatro entradas diferentes precisam da mesma coisa — perguntar a Google qual e
 * o estado da assinatura AGORA e gravar o que ela responder:
 *
 *   validarCompraPlay                 renovacao chegando pelo app
 *   notificacoesPlay (RTDN)           evento vindo do Pub/Sub
 *   reconciliarEntitlementDoJogador   saida de emergencia da administracao
 *
 * Ter tres copias disso seria ter tres politicas economicas se afastando com o
 * tempo. Ha uma so, aqui, e as tres entradas a chamam.
 *
 * ISTO NAO E UM SEGUNDO MOTOR DE ASSINATURA. Quem traduz a resposta da Google e
 * `consolidarAssinatura` (entitlement.js); quem decide se a traducao entra e
 * `decidirAtualizacao` (entitlement.js), avaliada dentro da transacao do store.
 * Este arquivo so encadeia os tres passos na ordem certa — e a ordem e o ponto.
 *
 * O CARIMBO VEM ANTES DA REDE, E ISSO E A REGRA DE ORDEM INTEIRA
 *
 * `consultadoEm` e capturado ANTES da chamada, de proposito: uma resposta que
 * demorou dez segundos descreve o mundo de dez segundos atras. Carimba-la com o
 * instante da VOLTA a faria ganhar de uma consulta mais nova que respondeu
 * rapido — e `decidirAtualizacao` compara exatamente esse carimbo. Inverter as
 * duas linhas abaixo reintroduz o defeito de ordem sem que nenhum teste de
 * dominio perceba, porque o dominio recebe o carimbo pronto. Por isso o teste
 * `RTDN-18` prova a ordem daqui, e nao de la.
 */

'use strict';

const { consolidarAssinatura } = require('./entitlement');
const { chaveDaCompra } = require('./entitlementStore');

/**
 * @param {object} portas
 * @param {function(string): Promise<object>} portas.consultarAssinatura
 *        pergunta a Google Play Developer API pelo token. Pode LANCAR — e
 *        lancar e o comportamento desejado: ver o cabecalho de `rtdn.js`.
 * @param {function(object, object=): Promise<object>} portas.aplicarProposta
 *        `criarStore(...).aplicarProposta`
 * @param {function(): string} [portas.agora] relogio, em ISO-8601
 */
function criarReconciliador({ consultarAssinatura, aplicarProposta, agora }) {
  const relogio = agora || (() => new Date().toISOString());

  /**
   * Consulta autoritativa + consolidacao + gravacao, para um token de assinatura.
   *
   * @param {object} args
   * @param {string} args.uid
   * @param {string} args.tokenCompra  o token CRU — e a credencial de consulta
   * @param {string} args.fonte        'validacao' | 'rtdn' | 'reconciliacao'
   */
  async function reconsultarEAplicar({
    uid,
    produtoId,
    tokenCompra,
    fonte,
    eventoEm = null,
    eventoTipo = null,
    evento = null,
  }) {
    const consultadoEm = relogio();
    const resposta = await consultarAssinatura(tokenCompra);
    const consolidado = consolidarAssinatura(resposta, consultadoEm);

    return aplicarProposta(
      {
        uid,
        ...consolidado,
        produtoId: consolidado.produtoId || produtoId || null,
        origem: 'play',
        purchaseTokenHash: chaveDaCompra(tokenCompra),
        purchaseToken: tokenCompra,
        verificadoEm: consultadoEm,
        eventoEm,
        eventoTipo,
        fonte,
      },
      evento
    );
  }

  return { reconsultarEAplicar };
}

module.exports = { criarReconciliador };
