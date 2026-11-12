// seguir.dominio.test.js — o dominio de SEGUIR pelo BUNDLE REAL (SOCIAL-02, C1).
//
// Roda sobre `lib/domain.js` JA COMPILADO, que carrega `lib/domain_bundle.js`
// gerado por `npm run build:domain` (dart compile js de app/lib/social/
// js_bridge.dart). Nada aqui procura texto em codigo: cada caso CHAMA a decisao
// compilada e confere o veredito.
//
// EXIGE O BUNDLE. No CI, o passo 3c roda `build:domain` antes de `npm test`. Sem
// o bundle, `lib/domain.js` falha no carregamento de proposito (ver domain.ts).
//
// O QUE ESTA SUITE NAO PROVA, e nao declara: HTTP, Firestore, regras, transacao,
// concorrencia real, exclusao de conta. Isso e das etapas C2–C4.

'use strict';

const assert = require('node:assert/strict');
const { test, describe } = require('node:test');

const { dominio } = require('../lib/domain.js');

const AGORA = '2026-11-12T12:00:00.000Z';
const T0 = Date.parse(AGORA);
const MIN = 60 * 1000;
const HORA = 60 * MIN;

/// Um instante `ms` milissegundos antes de AGORA, em ISO.
const antes = (ms) => new Date(T0 - ms).toISOString();

/// Comando base: seguir de uidA para uidB, perfil publico, tudo permitido.
function comando(sobre = {}) {
  return {
    operacao: 'seguir',
    atorUid: 'uidA',
    alvoUid: 'uidB',
    intencaoId: 'i1',
    tokenVisto: null,
    atorVip: true,
    alvoVip: true,
    contatoPermitido: true,
    atorEmExclusao: false,
    alvoEmExclusao: false,
    estadoFisico: 'nenhum',
    refAtual: null,
    corteNaCriacao: null,
    corteAtual: null,
    ultimaIntencaoChave: null,
    ultimaIntencaoImpressao: null,
    privacidadeAlvo: null,
    criacoesDoAtor: [],
    criacoesNoPar: [],
    pendentesEnviadosDoAtor: 0,
    agora: AGORA,
    ...sobre,
  };
}

const avaliar = (sobre) => dominio.avaliarComandoSeguir(comando(sobre));

/// Documento de entitlement valido ate `expiraEm`.
const entitlement = (sobre = {}) => ({
  vipAtivo: true,
  estado: 'ativo',
  origem: 'play',
  expiraEm: '2026-12-12T12:00:00.000Z',
  ...sobre,
});

const vigente = (documento, agora = AGORA) =>
  dominio.vigenciaVipDasPontas({
    uidA: 'uidA',
    documentoA: documento,
    uidB: 'uidB',
    documentoB: null,
    agora,
  }).a;

// ===========================================================================

describe('exports preservados', () => {
  test('as 20 exportacoes anteriores continuam no bundle', () => {
    const ponte = globalThis.bmvSocial;
    for (const nome of [
      'idPublicoDeBytes', 'normalizarIdPublico', 'recusaDeConsultaPublica',
      'avaliarAtualizacaoDeApresentacao', 'conferirDocumentoPublico',
      'perfilPublicoInicial', 'avaliarContato', 'chaveDoPar',
      'avaliarSolicitacao', 'avaliarAceite', 'avaliarRecusa',
      'avaliarCancelamento', 'avaliarRemocao', 'vistaDaRelacao',
      'avaliarConsultaDeBusca', 'chaveDeBusca', 'filtrarVisiveisDaBusca',
      'projetarResultadosDeBusca', 'paginarAmigos', 'constantes',
    ]) {
      assert.equal(typeof ponte[nome], 'function', nome);
    }
  });

  test('os limites aprovados (Q4) vem do dominio', () => {
    const c = dominio.constantesSeguir();
    assert.equal(c.maximoCriacoesJanelaCurta, 30);
    assert.equal(c.janelaRitmoCurtaMs, 10 * MIN);
    assert.equal(c.maximoCriacoesJanelaLonga, 300);
    assert.equal(c.janelaRitmoLongaMs, 24 * HORA);
    assert.equal(c.maximoCriacoesPorAlvo, 3);
    assert.equal(c.janelaRitmoPorAlvoMs, 24 * HORA);
    assert.equal(c.tetoPedidosPendentesEnviados, 100);
    assert.equal(c.colecaoCortes, 'cortesDeRelacao');
  });
});

describe('S25 — vigencia VIP pela definicao unica (vigenteEm)', () => {
  test('documento valido e vigente', () => {
    assert.equal(vigente(entitlement()), true);
  });

  test('S25a — vipAtivo:false com estado de acesso e prazo futuro: sem VIP', () => {
    assert.equal(vigente(entitlement({ vipAtivo: false })), false);
  });

  test('S25b — agora == expiraEm: sem VIP (fronteira estrita)', () => {
    assert.equal(vigente(entitlement({ expiraEm: AGORA })), false);
  });

  test('S25c — 1 ms antes de expiraEm: VIP', () => {
    assert.equal(
      vigente(entitlement({ expiraEm: new Date(T0 + 1).toISOString() })),
      true
    );
  });

  test('documento ausente, ilegivel ou terminal: sem VIP', () => {
    assert.equal(vigente(null), false);
    assert.equal(vigente(entitlement({ expiraEm: 'nao-e-data' })), false);
    assert.equal(vigente(entitlement({ expiraEm: null })), false);
    assert.equal(vigente(entitlement({ estado: 'revogado' })), false);
  });

  test('D08 — VIP manual com entitlement canonico valido conta', () => {
    assert.equal(vigente(entitlement({ origem: 'administrativa' })), true);
  });

  test('instante invalido nao concede: a ponte falha', () => {
    assert.throws(() => vigente(entitlement(), 'ontem'));
  });
});

describe('corte do par e estado efetivo', () => {
  test('a chave do corte e simetrica e nao serve ao proprio jogador', () => {
    const ab = dominio.chaveDoParDeCorte('uidA', 'uidB');
    const ba = dominio.chaveDoParDeCorte('uidB', 'uidA');
    assert.equal(ab.chave, ba.chave);
    assert.deepEqual(ab.membros, ['uidA', 'uidB']);
    assert.equal(ab.colecao, 'cortesDeRelacao');
    assert.throws(() => dominio.chaveDoParDeCorte('uidA', 'uidA'));
    assert.throws(() => dominio.chaveDoParDeCorte('uid|A', 'uidB'));
  });

  test('vinculo ativo nascido sob corte antigo esta logicamente encerrado', () => {
    const efetivo = (estadoFisico, corteNaCriacao, corteAtual) =>
      dominio.estadoEfetivoSeguir({ estadoFisico, corteNaCriacao, corteAtual })
        .estadoEfetivo;
    assert.equal(efetivo('confirmado', null, 'c1'), 'encerrado');
    assert.equal(efetivo('pendente', 'c1', 'c2'), 'encerrado');
    assert.equal(efetivo('confirmado', 'c1', 'c1'), 'confirmado');
    assert.equal(efetivo('confirmado', null, null), 'confirmado');
    assert.equal(efetivo('encerrado', null, 'c1'), 'encerrado');
    assert.equal(efetivo(null, null, 'c1'), 'nenhum');
  });

  test('a referencia combina ref e corte, e o par vazio nao tem referencia', () => {
    assert.equal(dominio.tokenSeguir({ ref: 'r1', corte: null }).referencia, 'r1.');
    assert.equal(dominio.tokenSeguir({ ref: 'r1', corte: 'c1' }).referencia, 'r1.c1');
    assert.equal(dominio.tokenSeguir({ ref: null, corte: null }).referencia, null);
  });
});

describe('espelhos P1–P4 (adendo A1)', () => {
  test('cada estado tem exatamente os seus espelhos', () => {
    assert.deepEqual(dominio.espelhosDoEstadoSeguir('confirmado').espelhos.sort(), [
      'seguidoresDoSeguido',
      'seguindoDoSeguidor',
    ]);
    assert.deepEqual(dominio.espelhosDoEstadoSeguir('pendente').espelhos.sort(), [
      'pedidoEnviadoDoSeguidor',
      'pedidoRecebidoDoSeguido',
    ]);
    assert.deepEqual(dominio.espelhosDoEstadoSeguir('encerrado').espelhos, []);
    assert.deepEqual(dominio.espelhosDoEstadoSeguir(null).espelhos, []);
    assert.equal(dominio.espelhosDoEstadoSeguir(null).todos.length, 4);
  });
});

describe('comando — criacao e impedimentos', () => {
  test('O01 — seguir perfil publico confirma e consome ritmo', () => {
    const v = avaliar();
    assert.equal(v.aceita, true);
    assert.equal(v.repeticao, false);
    assert.equal(v.novoEstado, 'confirmado');
    assert.deepEqual(v.espelhos.sort(), ['seguidoresDoSeguido', 'seguindoDoSeguidor']);
    assert.equal(v.deltaPendentes, 0);
    assert.equal(v.consumirRitmo, true);
    assert.deepEqual(v.criacoesDoAtorApos, [AGORA]);
    assert.deepEqual(v.criacoesNoParApos, [AGORA]);
    assert.equal(v.chaveIntencao, 'uidA|i1');
  });

  test('O02 — seguir perfil privado cria pedido e soma ao contador tecnico', () => {
    const v = avaliar({ privacidadeAlvo: 'privado' });
    assert.equal(v.novoEstado, 'pendente');
    assert.equal(v.deltaPendentes, 1);
    assert.deepEqual(v.espelhos.sort(), ['pedidoEnviadoDoSeguidor', 'pedidoRecebidoDoSeguido']);
  });

  test('Q1 — sem escolha e publico; valor desconhecido e lido como privado', () => {
    assert.equal(avaliar({ privacidadeAlvo: null }).novoEstado, 'confirmado');
    assert.equal(avaliar({ privacidadeAlvo: 'publico' }).novoEstado, 'confirmado');
    assert.equal(avaliar({ privacidadeAlvo: '???' }).novoEstado, 'pendente');
  });

  test('S08 — sobre si mesmo', () => {
    assert.equal(avaliar({ alvoUid: 'uidA' }).recusa, 'acaoSobreSiMesmo');
  });

  test('forma invalida: intencao e referencia', () => {
    assert.equal(avaliar({ intencaoId: 'com espaco' }).recusa, 'pedidoInvalido');
    assert.equal(avaliar({ intencaoId: '' }).recusa, 'pedidoInvalido');
    assert.equal(avaliar({ tokenVisto: 'semponto' }).recusa, 'pedidoInvalido');
    assert.equal(avaliar({ tokenVisto: 'a.b.c' }).recusa, 'pedidoInvalido');
    assert.equal(avaliar({ tokenVisto: 42 }).recusa, 'pedidoInvalido');
  });

  test('S01 — ator gratuito: requerVip', () => {
    const v = avaliar({ atorVip: false });
    assert.equal(v.aceita, false);
    assert.equal(v.recusa, 'requerVip');
    assert.equal(v.novoEstado, null);
  });

  test('S02 — alvo gratuito: recusa neutra, igual a contato impedido', () => {
    assert.equal(avaliar({ alvoVip: false }).recusa, 'acaoIndisponivel');
    assert.equal(avaliar({ contatoPermitido: false }).recusa, 'acaoIndisponivel');
  });

  test('ciclo da conta: alvo em exclusao some; ator em exclusao fica indisponivel', () => {
    assert.equal(avaliar({ alvoEmExclusao: true }).recusa, 'perfilPublicoNaoDisponivel');
    assert.equal(avaliar({ atorEmExclusao: true }).recusa, 'acaoIndisponivel');
  });

  test('S26 — aprovar exige o solicitante VIP agora; o pedido fica pendente', () => {
    const v = avaliar({
      operacao: 'aprovarPedido',
      estadoFisico: 'pendente',
      refAtual: 'rP',
      tokenVisto: 'rP.',
      alvoVip: false,
    });
    assert.equal(v.recusa, 'acaoIndisponivel');
    assert.equal(v.novoEstado, null);
  });

  test('O04 — aprovar confirma, tira do contador e NAO consome ritmo', () => {
    const v = avaliar({
      operacao: 'aprovarPedido',
      estadoFisico: 'pendente',
      refAtual: 'rP',
      tokenVisto: 'rP.',
      // Ritmo do ator ja estourado: aprovar nao passa pelo mecanismo.
      criacoesDoAtor: Array.from({ length: 30 }, (_, i) => antes(i * 1000)),
    });
    assert.equal(v.aceita, true);
    assert.equal(v.novoEstado, 'confirmado');
    assert.equal(v.deltaPendentes, -1);
    assert.equal(v.consumirRitmo, false);
    assert.equal(v.criacoesDoAtorApos, null);
  });
});

describe('comando — encerramento (Q2 linha de base e adendo A3)', () => {
  const deixar = (sobre) =>
    avaliar({
      operacao: 'deixarDeSeguir',
      estadoFisico: 'confirmado',
      refAtual: 's1',
      tokenVisto: 's1.',
      ...sobre,
    });

  test('deixar de seguir encerra sem consumir ritmo', () => {
    const v = deixar();
    assert.equal(v.novoEstado, 'encerrado');
    assert.deepEqual(v.espelhos, []);
    assert.equal(v.consumirRitmo, false);
  });

  test('encerrar nao exige nada do outro lado', () => {
    assert.equal(deixar({ alvoVip: false, contatoPermitido: false }).novoEstado, 'encerrado');
  });

  test('Q2 — gestao exige o VIP do ator', () => {
    assert.equal(deixar({ atorVip: false }).recusa, 'requerVip');
  });

  test('A3 — contra conta em exclusao: sem escrita, desfecho nenhum', () => {
    const v = deixar({ alvoEmExclusao: true });
    assert.equal(v.aceita, true);
    assert.equal(v.repeticao, true);
    assert.equal(v.novoEstado, null);
    assert.equal(v.estadoEfetivo, 'nenhum');
  });

  test('ja encerrado: repeticao sem escrita', () => {
    const v = deixar({ estadoFisico: 'encerrado' });
    assert.equal(v.repeticao, true);
    assert.equal(v.novoEstado, null);
  });
});

describe('S28 — acao antiga nao atinge geracao nova', () => {
  test('S28a — aprovacao atrasada do pedido A nao aprova o pedido B', () => {
    const v = avaliar({
      operacao: 'aprovarPedido',
      estadoFisico: 'pendente',
      refAtual: 'rB',
      tokenVisto: 'rA.',
    });
    assert.equal(v.recusa, 'referenciaObsoleta');
    assert.equal(v.novoEstado, null);
  });

  test('S28b — deixar de seguir atrasado nao encerra o vinculo mais novo', () => {
    const v = avaliar({
      operacao: 'deixarDeSeguir',
      estadoFisico: 'confirmado',
      refAtual: 's2',
      tokenVisto: 's1.',
    });
    assert.equal(v.recusa, 'referenciaObsoleta');
  });

  test('S28c — seguir atrasado nao recria depois de deixar de seguir', () => {
    const v = avaliar({
      intencaoId: 'X',
      estadoFisico: 'encerrado',
      refAtual: 'e1',
      tokenVisto: null,
      ultimaIntencaoChave: 'uidA|X2',
      ultimaIntencaoImpressao: 'deixarDeSeguir|saida|s1.',
    });
    assert.equal(v.recusa, 'referenciaObsoleta');
    assert.equal(v.novoEstado, null);
  });

  test('S28d — pedido atrasado nao recria pedido cancelado', () => {
    const v = avaliar({
      intencaoId: 'Y',
      privacidadeAlvo: 'privado',
      estadoFisico: 'encerrado',
      refAtual: 'c1',
      tokenVisto: null,
    });
    assert.equal(v.recusa, 'referenciaObsoleta');
  });
});

describe('S33 — ordem: impedimento, geracao, deduplicacao', () => {
  // O reenvio exato de um "seguir" ja aceito.
  const primeira = avaliar({ intencaoId: 'X' });
  const reenvio = (sobre) =>
    avaliar({
      intencaoId: 'X',
      tokenVisto: null,
      estadoFisico: 'confirmado',
      refAtual: 's1',
      ultimaIntencaoChave: primeira.chaveIntencao,
      ultimaIntencaoImpressao: primeira.impressao,
      ...sobre,
    });

  test('reenvio na mesma geracao: repeticao, sem escrita e sem ritmo', () => {
    const v = reenvio();
    assert.equal(v.repeticao, true);
    assert.equal(v.novoEstado, null);
    assert.equal(v.consumirRitmo, false);
    assert.equal(v.estadoEfetivo, 'confirmado');
  });

  test('S33a — mesma intencao em outro comando: pedidoInvalido', () => {
    const v = reenvio({ operacao: 'deixarDeSeguir', tokenVisto: 's1.' });
    assert.equal(v.recusa, 'pedidoInvalido');
    assert.equal(v.novoEstado, null);
  });

  test('S33b — o reenvio nao atravessa bloqueio, plano nem exclusao', () => {
    assert.equal(reenvio({ contatoPermitido: false }).recusa, 'acaoIndisponivel');
    assert.equal(reenvio({ alvoVip: false }).recusa, 'acaoIndisponivel');
    assert.equal(reenvio({ alvoEmExclusao: true }).recusa, 'perfilPublicoNaoDisponivel');
  });

  test('S33c — intencao anterior a ultima cai na referencia', () => {
    const v = reenvio({
      ultimaIntencaoChave: 'uidA|X3',
      ultimaIntencaoImpressao: 'deixarDeSeguir|saida|s1.',
      estadoFisico: 'encerrado',
      refAtual: 'e2',
    });
    assert.equal(v.recusa, 'referenciaObsoleta');
  });

  test('S33d — reenvio de antes de um bloqueio desfeito: geracao antiga recusada', () => {
    // Bloquear e desbloquear trocaram o corte; a faxina ainda nao rodou.
    const v = reenvio({ corteAtual: 'c1' });
    assert.equal(v.aceita, false);
    assert.equal(v.recusa, 'referenciaObsoleta');
    assert.equal(v.novoEstado, null);
    assert.equal(v.estadoEfetivo, 'encerrado');
  });

  test('depois do corte, um seguir novo com a referencia atual cria vinculo novo', () => {
    const v = avaliar({
      intencaoId: 'Z',
      estadoFisico: 'confirmado',
      refAtual: 's1',
      corteNaCriacao: null,
      corteAtual: 'c1',
      tokenVisto: 's1.c1',
    });
    assert.equal(v.novoEstado, 'confirmado');
  });
});

describe('ritmo — janelas moveis e teto rigido (Q4)', () => {
  const recentes = (n, passoMs) => Array.from({ length: n }, (_, i) => antes((i + 1) * passoMs));

  test('29 criacoes nos ultimos 10 minutos: aceita; 30: ritmoExcedido', () => {
    assert.equal(avaliar({ criacoesDoAtor: recentes(29, 10 * 1000) }).aceita, true);
    assert.equal(avaliar({ criacoesDoAtor: recentes(30, 10 * 1000) }).recusa, 'ritmoExcedido');
  });

  test('janela movel: um instante a exatamente 10 minutos ja saiu', () => {
    const lista = [...recentes(29, 10 * 1000), antes(10 * MIN)];
    assert.equal(avaliar({ criacoesDoAtor: lista }).aceita, true);
  });

  test('instante futuro conta (relogio divergente pesa contra)', () => {
    const lista = [...recentes(29, 10 * 1000), new Date(T0 + 5 * MIN).toISOString()];
    assert.equal(avaliar({ criacoesDoAtor: lista }).recusa, 'ritmoExcedido');
  });

  test('300 nas ultimas 24 horas, espalhadas: ritmoExcedido; 299: aceita', () => {
    // A cada 4 min e 40 s: nunca mais de 3 por 10 minutos, e a 300a fica
    // dentro das 24 horas (300 x 280 s = 23 h 20 min).
    const passo = 280 * 1000;
    assert.equal(avaliar({ criacoesDoAtor: recentes(299, passo) }).aceita, true);
    assert.equal(avaliar({ criacoesDoAtor: recentes(300, passo) }).recusa, 'ritmoExcedido');
  });

  test('3 criacoes para o mesmo alvo em 24 horas: ritmoExcedido', () => {
    assert.equal(avaliar({ criacoesNoPar: recentes(2, HORA) }).aceita, true);
    assert.equal(avaliar({ criacoesNoPar: recentes(3, HORA) }).recusa, 'ritmoExcedido');
    const umaVelha = [antes(HORA), antes(2 * HORA), antes(25 * HORA)];
    assert.equal(avaliar({ criacoesNoPar: umaVelha }).aceita, true);
  });

  test('o historico guardado poda o que saiu da janela e acrescenta agora', () => {
    const v = avaliar({
      criacoesDoAtor: [antes(25 * HORA), antes(HORA)],
      criacoesNoPar: [antes(25 * HORA), antes(2 * HORA)],
    });
    assert.deepEqual(v.criacoesDoAtorApos, [antes(HORA), AGORA]);
    assert.deepEqual(v.criacoesNoParApos, [antes(2 * HORA), AGORA]);
  });

  test('teto rigido de 100 pendentes enviados', () => {
    const pedir = (pendentes) => avaliar({ privacidadeAlvo: 'privado', pendentesEnviadosDoAtor: pendentes });
    assert.equal(pedir(99).aceita, true);
    assert.equal(pedir(100).recusa, 'limitePedidosPendentes');
    assert.equal(pedir(null).recusa, 'limiteIndisponivel');
  });

  test('o teto e de pedidos: seguir um perfil publico nao passa por ele', () => {
    assert.equal(avaliar({ pendentesEnviadosDoAtor: 100 }).novoEstado, 'confirmado');
  });

  test('recriar pedido sobre pedido cortado nao conta duas vezes', () => {
    const v = avaliar({
      privacidadeAlvo: 'privado',
      estadoFisico: 'pendente',
      refAtual: 'rP',
      corteNaCriacao: null,
      corteAtual: 'c1',
      tokenVisto: 'rP.c1',
      pendentesEnviadosDoAtor: 100,
    });
    assert.equal(v.novoEstado, 'pendente');
    assert.equal(v.deltaPendentes, 0);
  });
});

describe('R1 — historico de ritmo ilegivel nao vira historico vazio', () => {
  /// Comando com um campo REMOVIDO (ausente no JSON, e nao `null`).
  const semCampo = (campo, sobre = {}) => {
    const c = comando(sobre);
    delete c[campo];
    return dominio.avaliarComandoSeguir(c);
  };

  /// Nenhuma criacao, nenhum consumo e nenhuma escrita sugerida.
  const negadoSemEfeito = (v) => {
    assert.equal(v.aceita, false);
    assert.equal(v.recusa, 'limiteIndisponivel');
    assert.equal(v.novoEstado, null);
    assert.equal(v.consumirRitmo, false);
    assert.equal(v.criacoesDoAtorApos, null);
    assert.equal(v.criacoesNoParApos, null);
    assert.equal(v.espelhos, null);
  };

  test('historico global em formato invalido: criacao nao autorizada', () => {
    for (const invalido of [{}, 'texto', 42, true, { 0: AGORA }]) {
      negadoSemEfeito(avaliar({ criacoesDoAtor: invalido }));
    }
  });

  test('historico por alvo em formato invalido: criacao nao autorizada', () => {
    for (const invalido of [{}, 'texto', 42, true]) {
      negadoSemEfeito(avaliar({ criacoesNoPar: invalido }));
    }
  });

  test('null ou campo ausente e historico DESCONHECIDO, nao zero', () => {
    negadoSemEfeito(avaliar({ criacoesDoAtor: null }));
    negadoSemEfeito(avaliar({ criacoesNoPar: null }));
    negadoSemEfeito(semCampo('criacoesDoAtor'));
    negadoSemEfeito(semCampo('criacoesNoPar'));
  });

  test('lista vazia explicita e historico conhecido e vazio (ator novo)', () => {
    const v = avaliar({ criacoesDoAtor: [], criacoesNoPar: [] });
    assert.equal(v.aceita, true);
    assert.equal(v.novoEstado, 'confirmado');
    assert.deepEqual(v.criacoesDoAtorApos, [AGORA]);
  });

  test('pedido a perfil privado com historico invalido tambem e negado', () => {
    negadoSemEfeito(avaliar({ privacidadeAlvo: 'privado', criacoesDoAtor: 'x' }));
  });

  test('bordas validas continuam: 30/10 min, 300/24 h e 3/24 h', () => {
    const lista = (n, passoMs) => Array.from({ length: n }, (_, i) => antes((i + 1) * passoMs));
    assert.equal(avaliar({ criacoesDoAtor: lista(29, 10 * 1000) }).aceita, true);
    assert.equal(avaliar({ criacoesDoAtor: lista(30, 10 * 1000) }).recusa, 'ritmoExcedido');
    assert.equal(avaliar({ criacoesDoAtor: lista(299, 280 * 1000) }).aceita, true);
    assert.equal(avaliar({ criacoesDoAtor: lista(300, 280 * 1000) }).recusa, 'ritmoExcedido');
    assert.equal(avaliar({ criacoesNoPar: lista(2, HORA) }).aceita, true);
    assert.equal(avaliar({ criacoesNoPar: lista(3, HORA) }).recusa, 'ritmoExcedido');
  });

  test('operacoes que nao consomem ritmo nao dependem do historico', () => {
    const aprovar = semCampo('criacoesDoAtor', {
      operacao: 'aprovarPedido',
      estadoFisico: 'pendente',
      refAtual: 'rP',
      tokenVisto: 'rP.',
    });
    assert.equal(aprovar.novoEstado, 'confirmado');
    const deixar = avaliar({
      operacao: 'deixarDeSeguir',
      estadoFisico: 'confirmado',
      refAtual: 's1',
      tokenVisto: 's1.',
      criacoesNoPar: 'ilegivel',
    });
    assert.equal(deixar.novoEstado, 'encerrado');
  });
});

describe('R2 — contador de pendentes invalido nao e truncado nem aceito', () => {
  const pedir = (pendentes) =>
    avaliar({ privacidadeAlvo: 'privado', pendentesEnviadosDoAtor: pendentes });

  const negadoSemEfeito = (v) => {
    assert.equal(v.aceita, false);
    assert.equal(v.recusa, 'limiteIndisponivel');
    assert.equal(v.novoEstado, null);
    assert.equal(v.consumirRitmo, false);
    assert.equal(v.deltaPendentes, 0);
  };

  test('negativo, fracionario, nao numerico ou desconhecido: falha fechada', () => {
    for (const invalido of [-1, -0.5, 99.9, 0.5, 100.4, '5', '99', true, {}, [], null]) {
      negadoSemEfeito(pedir(invalido));
    }
  });

  test('campo ausente tambem e desconhecido', () => {
    const c = comando({ privacidadeAlvo: 'privado' });
    delete c.pendentesEnviadosDoAtor;
    negadoSemEfeito(dominio.avaliarComandoSeguir(c));
  });

  test('inteiros validos: 0 e 99 passam; 100 recusa pelo teto', () => {
    const zero = pedir(0);
    assert.equal(zero.novoEstado, 'pendente');
    assert.equal(zero.deltaPendentes, 1);
    assert.equal(pedir(99).novoEstado, 'pendente');
    assert.equal(pedir(100).recusa, 'limitePedidosPendentes');
  });

  test('recriacao sobre pedido cortado e delta por direcao continuam iguais', () => {
    const recriar = avaliar({
      privacidadeAlvo: 'privado',
      estadoFisico: 'pendente',
      refAtual: 'rP',
      corteNaCriacao: null,
      corteAtual: 'c1',
      tokenVisto: 'rP.c1',
      pendentesEnviadosDoAtor: 100,
    });
    assert.equal(recriar.novoEstado, 'pendente');
    assert.equal(recriar.deltaPendentes, 0);
    const aprovar = avaliar({
      operacao: 'aprovarPedido',
      estadoFisico: 'pendente',
      refAtual: 'rP',
      tokenVisto: 'rP.',
      pendentesEnviadosDoAtor: -7,
    });
    // Aprovar nao passa pelo teto do ATOR; o -1 vai para o contador do seguidor.
    assert.equal(aprovar.novoEstado, 'confirmado');
    assert.equal(aprovar.deltaPendentes, -1);
  });

  test('seguir perfil publico nao depende do contador de pedidos', () => {
    assert.equal(
      avaliar({ pendentesEnviadosDoAtor: 'ilegivel' }).novoEstado,
      'confirmado'
    );
  });
});

describe('faxina por corte (S32b no dominio)', () => {
  const faxina = (estadoFisico, corteNaCriacao, corteAtual) =>
    dominio.avaliarFaxinaSeguir({ estadoFisico, corteNaCriacao, corteAtual });

  test('encerra o que nasceu sob corte antigo e acerta o contador', () => {
    assert.deepEqual(faxina('confirmado', null, 'c1'), {
      encerrar: true,
      deltaPendentes: 0,
      espelhos: [],
    });
    assert.equal(faxina('pendente', 'c0', 'c1').deltaPendentes, -1);
  });

  test('nao toca relacao nova, nascida sob o corte atual', () => {
    assert.equal(faxina('confirmado', 'c1', 'c1').encerrar, false);
    assert.equal(faxina('encerrado', null, 'c1').encerrar, false);
  });
});

describe('acoes da visita (D07, opcao B)', () => {
  const acoes = (sobre = {}) =>
    dominio.acoesDeSeguir({
      euMesmo: false,
      observadorVip: true,
      alvoVip: true,
      contatoPermitido: true,
      observadorEmExclusao: false,
      alvoEmExclusao: false,
      privacidadeAlvo: null,
      efetivoSaida: 'nenhum',
      efetivoEntrada: 'nenhum',
      ...sobre,
    }).acoes;

  test('seguir ou solicitar conforme a privacidade', () => {
    assert.deepEqual(acoes(), ['seguir']);
    assert.deepEqual(acoes({ privacidadeAlvo: 'privado' }), ['solicitarSeguir']);
  });

  test('nada para gratuito, proprio perfil, contato impedido ou exclusao', () => {
    assert.deepEqual(acoes({ observadorVip: false }), []);
    assert.deepEqual(acoes({ euMesmo: true }), []);
    assert.deepEqual(acoes({ contatoPermitido: false }), []);
    assert.deepEqual(acoes({ alvoEmExclusao: true }), []);
  });

  test('alvo sem VIP: sem seguir e sem aprovar; recusar continua', () => {
    assert.deepEqual(acoes({ alvoVip: false }), []);
    assert.deepEqual(acoes({ alvoVip: false, efetivoEntrada: 'pendente' }), ['recusarPedidoSeguir']);
  });

  test('estados existentes viram as acoes de encerrar ou aprovar', () => {
    assert.deepEqual(acoes({ efetivoSaida: 'pendente' }), ['cancelarPedidoSeguir']);
    assert.deepEqual(acoes({ efetivoSaida: 'confirmado' }), ['deixarDeSeguir']);
    assert.deepEqual(acoes({ efetivoEntrada: 'pendente' }), [
      'seguir',
      'aprovarPedidoSeguir',
      'recusarPedidoSeguir',
    ]);
    assert.deepEqual(acoes({ efetivoEntrada: 'confirmado' }), ['seguir', 'removerSeguidor']);
  });
});

describe('R3-x — veredito de contato da Moderacao, como e hoje', () => {
  const contato = (sobre) =>
    dominio.avaliarContato({
      origemBloqueouDestino: false,
      destinoBloqueouOrigem: false,
      origemComChatSilenciado: false,
      origemComRestricaoSocial: false,
      ...sobre,
    });

  test('cada entrada do veredito', () => {
    assert.deepEqual(contato({}), { permitido: true, motivo: null });
    assert.equal(contato({ destinoBloqueouOrigem: true }).motivo, 'bloqueadoPeloDestino');
    assert.equal(contato({ origemBloqueouDestino: true }).motivo, 'bloqueouODestino');
    assert.equal(contato({ origemComRestricaoSocial: true }).motivo, 'restricaoSocial');
    assert.equal(contato({ origemComChatSilenciado: true }).motivo, 'chatSilenciadoPorSancao');
  });

  test('suspensao temporaria nao e entrada do veredito (sem ampliacao — R-3)', () => {
    assert.deepEqual(contato({ suspensoAte: '2099-01-01T00:00:00.000Z' }), {
      permitido: true,
      motivo: null,
    });
  });
});
