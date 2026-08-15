/**
 * diagnosticoLegado.js — o RAIO-X da migracao, antes de migrar.
 *
 * POR QUE ESTE ARQUIVO EXISTE
 *
 * `migrarEntitlementsLegado` (index.js) sabe migrar, mas nao sabe RESPONDER se
 * deve. Rodar a migracao para descobrir quantos jogadores ela atinge e o tipo de
 * decisao que nao da para desfazer: a migracao grava, e o que ela grava vira o
 * `atual` que `decidirAtualizacao` protege dali em diante com
 * `legado_nao_sobrescreve`. Um numero errado descoberto depois da escrita custa
 * uma limpeza manual em documento de jogador pagante.
 *
 * Entao esta e a pergunta que faltava ter resposta: QUEM exatamente esta em
 * `usuarios/{uid}` com `vip: true`, o que a migracao faria com cada um, e quantos
 * dos casos terminam com o jogador em situacao pior do que a de hoje.
 *
 * ZERO ESCRITA, E ISSO E ESTRUTURAL — NAO UMA PROMESSA
 *
 * Este modulo nao recebe nenhuma porta capaz de escrever. Nao ha `aplicarProposta`,
 * nao ha `db`, nao ha transacao: as unicas dependencias injetadas sao
 * `lerPaginaLegado` e `lerEntitlement`. Um `dry-run` que compartilha o caminho de
 * escrita com um `flag` booleano depende de o flag estar certo em toda chamada;
 * este depende de o codigo de escrita nao existir aqui dentro. A revisao da
 * garantia e `grep`, e nao leitura de fluxo.
 *
 * A PERGUNTA QUE O DIAGNOSTICO EXISTE PARA RESPONDER
 *
 * A migracao so consegue reconstruir o direito a partir de `vipExpiraEm`, porque
 * `compras/{hash}` guarda o HASH do token e nunca o token (ver o cabecalho de
 * `migrarEntitlementsLegado`). Disso decorrem tres consequencias que o operador
 * precisa ver ANTES, com nome e contagem — e nenhuma delas aparece no retorno da
 * migracao, que so conta `migrados`, `jaTinham` e `semPrazo`:
 *
 *   1. quem tem `vip: true` e prazo VENCIDO entra como expirado. Se a assinatura
 *      renovou depois da ultima gravacao do legado, o jogador e um pagante que
 *      perde o acesso na virada, e o sistema nao tem como saber disso sozinho:
 *      sem token, nao ha o que perguntar a Google;
 *   2. quem tem `vip: true` e NENHUM prazo e simplesmente PULADO. Nao ganha
 *      entitlement nenhum — nem ativo, nem expirado —, entao some do relatorio da
 *      migracao depois do numero `semPrazo` e nunca mais aparece em lugar nenhum;
 *   3. todo direito migrado nasce sem `purchaseTokenHash`, e
 *      `concederFichasMensais` exige o hash para ter livro-razao idempotente
 *      (index.js, ramo `semPlano`). O migrado mantem o VIP e NAO recebe a parcela
 *      mensal de fichas que a politica promete.
 *
 * O QUE ESTE ARQUIVO NAO FAZ
 *
 * Nao consulta a Google (nao ha token com que consultar — e justamente o problema
 * que ele mede), nao decide politica e nao migra. Ele projeta o que a migracao
 * FARIA, usando a mesma regra que ela usa, e conta.
 */

'use strict';

const { ESTADO, instante, anteriorA } = require('./entitlement');

/**
 * Categorias da populacao legada.
 *
 * Sao EXCLUSIVAS e cobrem todo `usuarios/{uid}`: cada documento examinado cai em
 * exatamente uma, e a soma das contagens fecha com `examinados`. Uma categoria
 * `outros` que absorvesse o que nao encaixa esconderia justamente o caso que
 * ninguem previu — que e o caso que interessa num diagnostico.
 */
const CATEGORIA = {
  /** `vip` nao e `true`: fora da populacao de migracao. */
  FORA_DA_POPULACAO: 'fora_da_populacao',
  /** Ja tem entitlement vindo da Play (validacao ou RTDN). Migracao nao toca. */
  JA_COBERTO_PELA_PLAY: 'ja_coberto_pela_play',
  /** Ja tem entitlement de origem `legado_usuarios`. Migracao ja passou por aqui. */
  JA_MIGRADO: 'ja_migrado',
  /** Sem entitlement, prazo no futuro: a migracao concede VIP ate o prazo. */
  MIGRAVEL_VIGENTE: 'migravel_vigente',
  /** Sem entitlement, prazo no passado: a migracao grava expirado, sem VIP. */
  MIGRAVEL_VENCIDO: 'migravel_vencido',
  /** Sem entitlement e sem prazo utilizavel: a migracao PULA e nada e gravado. */
  BLOQUEADO_SEM_PRAZO: 'bloqueado_sem_prazo',
};

/**
 * Alertas por jogador. Nao sao erros: sao consequencias conhecidas da migracao
 * que precisam ser contadas para virar decisao de negocio.
 */
const ALERTA = {
  /** Migrado nasce sem token: `concederFichasMensais` vai pular este jogador. */
  SEM_FICHA_MENSAL: 'sem_ficha_mensal',
  /** Sem token guardado, `reconciliarEntitlementDoJogador` nao tem o que consultar. */
  SEM_RECONSULTA_POSSIVEL: 'sem_reconsulta_possivel',
  /** Prazo vencido no legado pode ser assinatura renovada que o legado nao viu. */
  POSSIVEL_PAGANTE_REBAIXADO: 'possivel_pagante_rebaixado',
  /** A migracao nao grava nada: o jogador fica sem registro de VIP em lugar nenhum. */
  SUMICO_SILENCIOSO: 'sumico_silencioso',
  /** Legado promete prazo MAIOR que o entitlement ja gravado. Merece olho humano. */
  DIVERGENCIA_DE_PRAZO: 'divergencia_de_prazo',
};

/** O que `migrarEntitlementsLegado` faria com este documento. */
const ACAO_DA_MIGRACAO = {
  NADA_FORA_DA_POPULACAO: 'nada_fora_da_populacao',
  NADA_LEGADO_NAO_SOBRESCREVE: 'nada_legado_nao_sobrescreve',
  PULAR_SEM_PRAZO: 'pular_sem_prazo',
  GRAVAR_ATIVO: 'gravar_ativo',
  GRAVAR_EXPIRADO: 'gravar_expirado',
};

/**
 * Classifica UM jogador. Pura: sem I/O, sem relogio proprio.
 *
 * A projecao de `acao` espelha, de proposito, a ordem de decisao real —
 * `decidirAtualizacao` recusa `fonte: 'migracao'` sobre qualquer documento ja
 * existente (`legado_nao_sobrescreve`), e so depois disso a migracao olha o
 * prazo. Inverter a ordem aqui faria o diagnostico prometer escrita onde a
 * migracao nao escreve.
 *
 * @param {object} args
 * @param {string} args.uid
 * @param {object|null} args.legado    `usuarios/{uid}`
 * @param {object|null} args.publico   `playerEntitlements/{uid}`
 * @param {object|null} args.interno   `playerEntitlements/{uid}/interno/billing`
 * @param {string} args.agora          ISO-8601
 */
function classificarJogador({ uid, legado, publico, interno, agora }) {
  const dados = legado || {};
  const alertas = [];

  if (dados.vip !== true) {
    return {
      uid,
      categoria: CATEGORIA.FORA_DA_POPULACAO,
      acao: ACAO_DA_MIGRACAO.NADA_FORA_DA_POPULACAO,
      expiraEmLegado: null,
      alertas,
    };
  }

  const expiraEmLegado = instante(dados.vipExpiraEm);

  // --- Ja existe entitlement -----------------------------------------------
  //
  // `decidirAtualizacao` recusa toda proposta de `fonte: 'migracao'` quando ha
  // documento — nao importa a origem dele. Entao a acao e a mesma nos dois ramos;
  // o que muda e o DIAGNOSTICO, porque um entitlement vindo da Play tem token e
  // um vindo do legado nao tem.
  if (publico) {
    const origemLegado = publico.origem === 'legado_usuarios';
    const temToken = Boolean(interno && interno.purchaseTokenHash);

    if (!temToken) {
      alertas.push(ALERTA.SEM_RECONSULTA_POSSIVEL);
      alertas.push(ALERTA.SEM_FICHA_MENSAL);
    }

    // O legado diz que o direito vai mais longe do que o entitlement afirma. Nao
    // e a migracao que resolve (ela nao sobrescreve): e caso de reconciliacao
    // manual, e por isso vira alerta e nao categoria.
    if (
      expiraEmLegado &&
      publico.expiraEm &&
      anteriorA(publico.expiraEm, expiraEmLegado) &&
      anteriorA(agora, expiraEmLegado)
    ) {
      alertas.push(ALERTA.DIVERGENCIA_DE_PRAZO);
    }

    return {
      uid,
      categoria: origemLegado
        ? CATEGORIA.JA_MIGRADO
        : CATEGORIA.JA_COBERTO_PELA_PLAY,
      acao: ACAO_DA_MIGRACAO.NADA_LEGADO_NAO_SOBRESCREVE,
      expiraEmLegado,
      estadoAtual: publico.estado || null,
      vipAtivoAtual: publico.vipAtivo === true,
      alertas,
    };
  }

  // --- Nao existe entitlement ----------------------------------------------
  //
  // Daqui para baixo a migracao E a unica coisa que vai existir sobre este
  // jogador, e ela so tem `vipExpiraEm` para trabalhar.

  if (!expiraEmLegado) {
    // O pior caso, e o mais facil de nao notar: a migracao incrementa `semPrazo`
    // e segue. Nenhum documento nasce, entao o jogador nao aparece nem como
    // expirado — ele simplesmente nao existe para o consumidor.
    alertas.push(ALERTA.SUMICO_SILENCIOSO);
    return {
      uid,
      categoria: CATEGORIA.BLOQUEADO_SEM_PRAZO,
      acao: ACAO_DA_MIGRACAO.PULAR_SEM_PRAZO,
      expiraEmLegado: null,
      alertas,
    };
  }

  const vigente = anteriorA(agora, expiraEmLegado);

  // Sem token, nem a reconsulta manual nem a parcela de fichas alcancam este
  // jogador — valha o direito ou nao.
  alertas.push(ALERTA.SEM_RECONSULTA_POSSIVEL);
  if (vigente) alertas.push(ALERTA.SEM_FICHA_MENSAL);

  if (!vigente) {
    // Pode ser um ex-assinante (correto) ou um assinante que renovou depois da
    // ultima escrita do legado (incorreto, e invisivel daqui). Os dois casos sao
    // indistinguiveis SEM O TOKEN — e essa indistinguibilidade e exatamente o
    // numero que o operador precisa ver antes de decidir migrar.
    alertas.push(ALERTA.POSSIVEL_PAGANTE_REBAIXADO);
  }

  return {
    uid,
    categoria: vigente
      ? CATEGORIA.MIGRAVEL_VIGENTE
      : CATEGORIA.MIGRAVEL_VENCIDO,
    acao: vigente
      ? ACAO_DA_MIGRACAO.GRAVAR_ATIVO
      : ACAO_DA_MIGRACAO.GRAVAR_EXPIRADO,
    expiraEmLegado,
    estadoProjetado: vigente ? ESTADO.ATIVO : ESTADO.EXPIRADO,
    vipAtivoProjetado: vigente,
    alertas,
  };
}

/** Somatorio vazio, com todas as chaves presentes desde o inicio. */
function resumoZerado() {
  const porCategoria = {};
  for (const c of Object.values(CATEGORIA)) porCategoria[c] = 0;
  const porAlerta = {};
  for (const a of Object.values(ALERTA)) porAlerta[a] = 0;
  return { examinados: 0, porCategoria, porAlerta };
}

/**
 * Acumula uma classificacao no resumo. Separado de `varrer` para que o teste
 * consiga somar sem montar portas.
 */
function acumular(resumo, classificacao) {
  resumo.examinados += 1;
  resumo.porCategoria[classificacao.categoria] += 1;
  for (const a of classificacao.alertas) resumo.porAlerta[a] += 1;
  return resumo;
}

/**
 * @param {object} portas
 * @param {function({cursor: string|null, lote: number}): Promise<{docs: Array<{uid: string, dados: object}>, fim: boolean}>} portas.lerPaginaLegado
 * @param {function(string): Promise<{publico: object|null, interno: object|null}>} portas.lerEntitlement
 * @param {function(): string} [portas.agora]
 *
 * NAO existe porta de escrita, e a ausencia e a garantia. Ver o cabecalho.
 */
function criarDiagnosticoLegado({ lerPaginaLegado, lerEntitlement, agora }) {
  const relogio = agora || (() => new Date().toISOString());

  /**
   * Varre uma pagina da populacao legada e projeta o efeito da migracao.
   *
   * @param {object} [args]
   * @param {string|null} [args.cursor]
   * @param {number} [args.lote]
   * @param {number} [args.amostrasPorCategoria]
   *        quantos uids guardar por categoria, para o operador conseguir
   *        conferir casos concretos sem despejar a base inteira no retorno.
   */
  async function varrer({ cursor = null, lote = 100, amostrasPorCategoria = 5 } = {}) {
    const instanteDaVarredura = relogio();
    const pagina = await lerPaginaLegado({ cursor, lote });
    const docs = (pagina && pagina.docs) || [];

    const resumo = resumoZerado();
    const amostras = {};
    let ultimo = cursor;

    for (const doc of docs) {
      ultimo = doc.uid;
      const { publico, interno } = await lerEntitlement(doc.uid);
      const classificacao = classificarJogador({
        uid: doc.uid,
        legado: doc.dados,
        publico,
        interno,
        agora: instanteDaVarredura,
      });

      acumular(resumo, classificacao);

      const balde = (amostras[classificacao.categoria] ||= []);
      if (balde.length < amostrasPorCategoria) balde.push(classificacao);
    }

    return {
      ...resumo,
      amostras,
      // `null` quando acabou. A pagina incompleta e o unico sinal confiavel de
      // fim: contar documentos nao distingue "acabou" de "lote exatamente cheio".
      cursor: pagina && pagina.fim ? null : ultimo,
      varridoEm: instanteDaVarredura,
    };
  }

  return { varrer };
}

module.exports = {
  CATEGORIA,
  ALERTA,
  ACAO_DA_MIGRACAO,
  classificarJogador,
  resumoZerado,
  acumular,
  criarDiagnosticoLegado,
};
