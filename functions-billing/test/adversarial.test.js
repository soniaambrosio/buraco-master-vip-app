/**
 * adversarial.test.js — MATRIZ A–W da homologacao adversarial do RTDN/VIP.
 *
 * O QUE ESTA SUITE E, E O QUE ELA NAO E
 *
 * Ela nao repete `entitlement.test.js` nem `rtdn.test.js`. Aqueles provam que o
 * desenho funciona quando as coisas acontecem como planejado; esta tenta QUEBRAR
 * o contrato — reentrega, reempacotamento, evento fora de ordem, corrida de dez
 * execucoes, falha no meio do commit, token de terceiro, produto que nao existe,
 * data absurda, payload mutilado — e registra o que resiste.
 *
 * Ela tambem alcanca o que a suite historica nao alcancava: `index.js`. Ate aqui
 * o adaptador era o unico arquivo sem teste, e e nele que moram o catalogo de
 * produtos, o credito de fichas, a ordem "creditar antes de consumir", as duas
 * varreduras administrativas e quatro linhas de log que escrevem `e.message` de
 * terceiro. Ver `apoio/carga_index.js` para como ele e carregado sem rede.
 *
 * NENHUMA CHAMADA REAL. Nao ha `googleapis`, nao ha projeto Firebase, nao ha
 * Pub/Sub, nao ha credencial. Todo token comeca com `token_sintetico_`.
 *
 * A LETRA DE CADA TESTE E A DA MATRIZ DA OS, para conferencia direta.
 */

'use strict';

const test = require('node:test');
const assert = require('node:assert');

const { ESTADO, NOTIFICACAO, interpretarNotificacao } = require('../entitlement');
const { chaveDaCompra } = require('../entitlementStore');
const { vinculoBemFormado } = require('../propriedade');
const {
  PACOTE,
  PRODUTO,
  PRODUTO_ANUAL,
  PRODUTO_FICHAS,
  U1,
  U2,
  TOKEN_A,
  TOKEN_B,
  TOKEN_C,
  VINCULO_U1,
  VINCULO_U2,
  VINCULO_ORFAO,
  HASH_A,
  HASH_B,
  HASH_C,
  T0,
  T1,
  T2,
  T3,
  T4,
  PASSADO,
  FUTURO,
  FUTURO_LONGE,
  publicoDe,
  internoDe,
  eventoDe,
  compraDe,
  mensagem,
  mensagemCrua,
  corpoAssinatura,
  corpoAnulacao,
  cenarioDeModulo,
  cenarioDeIndex,
} = require('./apoio/cenario');
const { FalhaTransitoriaPlay, FalhaPermanentePlay } = require('./apoio/play_falsa');
const { armadilhaDeRede } = require('./apoio/armadilha_de_rede');

/**
 * Armada ANTES de qualquer teste e conferida no fim (X4).
 *
 * A OS exige provar que nenhuma chamada real aconteceu. Isso nao se prova
 * lendo o codigo — se prova quebrando a saida: `http.request`, `https.request`,
 * `net.Socket.prototype.connect`, `dns.lookup` e `fetch` passam a LANCAR. Se
 * alguma coisa nesta suite tentar falar com a Google, com o Firebase ou com o
 * que for, o teste morre em vez de silenciosamente funcionar.
 */
const rede = armadilhaDeRede();

/** Prefixos que este dominio pode escrever. Qualquer outro e invasao. */
const DOMINIO = [
  'playerEntitlements/',
  'billingEvents/',
  'compras/',
  'usuarios/',
  'configuracao/',
  // As duas pontas da vinculacao entre a conta e a compra da Google. Entraram no
  // dominio do billing na correcao de propriedade, e sao fechadas ao cliente.
  'playerBillingIdentity/',
  'billingAccountIndex/',
];

function assertSoEscreveuNoDominio(db) {
  for (const caminho of db.caminhos()) {
    assert.ok(
      DOMINIO.some((p) => caminho.startsWith(p)),
      `escrita fora do dominio do Billing: ${caminho}`
    );
  }
}

/**
 * "Nao concedeu" tem DUAS formas legitimas, e exigir so uma delas transformaria
 * uma recusa mais dura numa falha de teste: ou o entitlement nem chegou a ser
 * escrito (a resposta foi recusada antes da consolidacao), ou ele foi escrito
 * dizendo que nao ha acesso. As duas sao ausencia de direito.
 */
function assertNaoConcedeu(c, uid, rotulo) {
  const pub = c.publico(uid);
  if (pub === null) return;
  assert.equal(pub.vipAtivo, false, `${rotulo}: concedeu VIP`);
}

/** Nem o token nem o hash inteiro podem aparecer no texto dado. */
function assertSemSegredo(texto, { tokens = [TOKEN_A, TOKEN_B, TOKEN_C], hashes = [HASH_A, HASH_B, HASH_C] } = {}) {
  for (const t of tokens) {
    assert.ok(!texto.includes(t), `token bruto vazou: ${t}`);
  }
  for (const h of hashes) {
    assert.ok(!texto.includes(h), `hash inteiro vazou: ${h.slice(0, 8)}…`);
  }
}

// ===========================================================================
// A — concessao inicial valida
// ===========================================================================

test('A concessao inicial valida concede VIP uma unica vez, ao usuario e produto certos', async () => {
  const c = cenarioDeIndex();
  c.play.definirAssinatura(TOKEN_A, {
    estado: c.play.ESTADOS.ATIVA,
    expiraEm: FUTURO,
    inicioEm: PASSADO,
    produtoId: PRODUTO,
  });

  const r = await c.chamar('validarCompraPlay', {
    uid: U1,
    dados: { produtoId: PRODUTO, tokenCompra: TOKEN_A, assinatura: true },
  });

  assert.equal(r.aprovada, true);
  assert.equal(r.jaProcessada, false);
  assert.deepEqual(r.entitlement, { estado: ESTADO.ATIVO, vipAtivo: true });

  const pub = c.publico(U1);
  assert.equal(pub.vipAtivo, true);
  assert.equal(pub.estado, ESTADO.ATIVO);
  assert.equal(pub.produtoId, PRODUTO);
  assert.equal(pub.expiraEm, FUTURO);
  assert.equal(pub.uid, U1);

  // O direito e do titular, e de mais ninguem.
  assert.equal(c.publico(U2), null);

  // Uma unica concessao gravada, e o registro da compra marcado concedido.
  assert.equal(c.db.escritasEm(publicoDe(U1)), 1);
  assert.equal(c.compra(HASH_A).estado, 'concedida');
  assert.equal(c.compra(HASH_A).uid, U1);

  // Fechar junto a Google vem DEPOIS de creditar, e uma vez so.
  assert.deepEqual(
    c.play.fechamentos.map((f) => f.tipo),
    ['acknowledge']
  );
  assertSoEscreveuNoDominio(c.db);
});

test('A2 consumivel credita as fichas do CATALOGO, nao as do payload, e consome depois', async () => {
  const c = cenarioDeIndex();
  c.play.definirProduto(TOKEN_B, { purchaseState: 0, produtoId: PRODUTO_FICHAS });

  const r = await c.chamar('validarCompraPlay', {
    uid: U1,
    dados: {
      produtoId: PRODUTO_FICHAS,
      tokenCompra: TOKEN_B,
      assinatura: false,
      // Payload mentindo: o app nao decide quantas fichas a compra vale.
      fichas: 999999,
    },
  });

  assert.equal(r.aprovada, true);
  assert.equal(r.detalhes.fichasCreditadas, 1000);
  assert.equal(c.usuario(U1).fichas, 1000);
  // Consumivel nao produz entitlement VIP.
  assert.equal(c.publico(U1), null);
  assert.deepEqual(c.play.fechamentos.map((f) => f.tipo), ['consume']);
});

// ===========================================================================
// B — reentrega do mesmo messageId
// ===========================================================================

test('B reentrega do mesmo messageId nao duplica efeito, trilha nem consulta', async () => {
  const c = cenarioDeModulo();
  c.registrarCompra(HASH_A, { uid: U1 });
  c.play.definirAssinatura(TOKEN_A, { estado: c.play.ESTADOS.ATIVA, expiraEm: FUTURO });
  c.db.zerarDiario();

  const corpo = corpoAssinatura(NOTIFICACAO.RENEWED, { token: TOKEN_A });

  const primeira = await c.rtdn.processarNotificacao(mensagem(corpo, 'msg_B'));
  assert.equal(primeira.aplicado, true);

  const depois = [];
  for (let i = 0; i < 3; i += 1) {
    depois.push(await c.rtdn.processarNotificacao(mensagem(corpo, 'msg_B')));
  }

  for (const r of depois) {
    assert.equal(r.aplicado, false, 'reentrega nao pode aplicar de novo');
    assert.equal(r.decisao, 'evento_repetido');
  }

  // Uma consulta a Google, uma escrita de cada documento, um documento de evento.
  assert.equal(c.play.total(TOKEN_A), 1, 'reentrega gastou consulta a Google');
  assert.equal(c.db.escritasEm(publicoDe(U1)), 1);
  assert.equal(c.db.escritasEm(internoDe(U1)), 1);
  assert.equal(c.db.escritasEm(eventoDe('msg_B')), 1);

  const ev = c.evento('msg_B');
  assert.equal(ev.estado, 'concluido');
  assert.equal(ev.aplicado, true);
  assert.equal(ev.uid, U1);
  assert.equal(ev.token.length, 8, 'a trilha guarda rotulo, nao hash inteiro');
});

test('B2 duas entregas SIMULTANEAS do mesmo messageId: so uma atravessa', async () => {
  // O teste B acima passa mesmo com a barreira transacional desligada, porque o
  // atalho de `rtdn.js` responde antes de a transacao ser alcancada. Ou seja: B
  // prova o atalho, e nao a barreira. Este prova a barreira.
  //
  // O cenario e o unico em que ela e a UNICA linha de defesa: duas entregas da
  // mesma mensagem em voo ao mesmo tempo. As duas passam pelo atalho (o evento
  // ainda nao existe), as duas perguntam a Google, e as duas chegam a transacao
  // com carimbos de consulta DIFERENTES — entao a regra de ordem tambem nao as
  // pega. So a marca "ja processei", relida dentro da transacao, segura.
  const c = cenarioDeModulo();
  c.registrarCompra(HASH_A, { uid: U1 });
  c.db.zerarDiario();

  const proposta = (verificadoEm, expiraEm) => ({
    uid: U1, estado: ESTADO.ATIVO, vipAtivo: true, produtoId: PRODUTO,
    inicioEm: PASSADO, expiraEm, renovacaoAutomatica: true, origem: 'play',
    purchaseTokenHash: HASH_A, purchaseToken: TOKEN_A, verificadoEm, fonte: 'rtdn',
  });

  // A SEGUNDA entrega e segurada antes do commit; a primeira commita e cria o
  // documento de evento. Na retentativa, a segunda tem de reconhece-lo.
  let aSegurar = 2;
  let liberar;
  const porta = new Promise((r) => { liberar = r; });
  c.db.pausarAntesDoCommit = async () => {
    aSegurar -= 1;
    if (aSegurar === 0) await porta;
  };

  const primeira = c.store.aplicarProposta(proposta(T1, FUTURO), { id: 'msg_B2' });
  const segunda = c.store.aplicarProposta(proposta(T2, FUTURO_LONGE), { id: 'msg_B2' });
  liberar();
  const [ra, rb] = await Promise.all([primeira, segunda]);

  const motivos = [ra.motivo, rb.motivo];
  assert.ok(
    motivos.includes('evento_repetido'),
    `a barreira de idempotencia da transacao nao atuou: ${JSON.stringify(motivos)}`
  );
  assert.equal(c.db.escritasEm(publicoDe(U1)), 1, 'a mesma mensagem produziu dois efeitos');
  assert.equal(c.db.escritasEm(internoDe(U1)), 1);
  // O prazo gravado e o da entrega que atravessou, e nao uma mistura das duas.
  assert.equal(c.publico(U1).expiraEm, FUTURO);
  assert.ok(c.db.conflitos >= 1, 'nao houve contencao: a corrida nao aconteceu');
});

// ===========================================================================
// C — mesmo token com messageId diferente
// ===========================================================================

test('C reempacotar o MESMO desfecho terminal com outro messageId nao o aplica duas vezes', async () => {
  const c = cenarioDeModulo();
  c.play.definirAssinatura(TOKEN_A, { estado: c.play.ESTADOS.ATIVA, expiraEm: FUTURO });
  c.semearEntitlement(U1, {
    estado: ESTADO.ATIVO,
    vipAtivo: true,
    expiraEm: FUTURO,
    hash: HASH_A,
    token: TOKEN_A,
    verificadoEm: T0,
  });
  c.db.zerarDiario();
  c.relogio.fila(T1, T2);

  const corpo = corpoAnulacao({ token: TOKEN_A });

  const um = await c.rtdn.processarNotificacao(mensagem(corpo, 'msg_C1'));
  assert.equal(um.aplicado, true);
  assert.equal(um.estado, ESTADO.REEMBOLSADO);
  const terminalEm = c.interno(U1).terminalEm;

  // Mesmo fato, envelope novo: a deduplicacao por messageId nao ajuda aqui.
  const dois = await c.rtdn.processarNotificacao(mensagem(corpo, 'msg_C2'));
  assert.equal(dois.aplicado, false);
  assert.equal(dois.decisao, 'terminal_repetido');

  assert.equal(c.db.escritasEm(publicoDe(U1)), 1, 'o estorno foi gravado duas vezes');
  assert.equal(c.interno(U1).terminalEm, terminalEm, 'o instante do estorno andou');
  assert.equal(c.publico(U1).vipAtivo, false);
  // A consulta acontece — e dela que sai o dono —, mas so na entrega que teve
  // efeito. A reentrega do mesmo fato para em `terminal_repetido` DEPOIS de
  // resolver a propriedade, entao sao duas consultas e uma escrita.
  assert.equal(c.play.total(TOKEN_A), 2);
  // A trilha registra os dois envelopes, e o segundo como sem efeito.
  assert.equal(c.evento('msg_C1').aplicado, true);
  assert.equal(c.evento('msg_C2').aplicado, false);
});

test('C2 o mesmo fato economico reempacotado converge, sem segunda concessao', async () => {
  const c = cenarioDeModulo();
  c.registrarCompra(HASH_A, { uid: U1 });
  c.play.definirAssinatura(TOKEN_A, { estado: c.play.ESTADOS.ATIVA, expiraEm: FUTURO });
  c.db.zerarDiario();
  c.relogio.fila(T1, T2);

  const corpo = corpoAssinatura(NOTIFICACAO.RENEWED, { token: TOKEN_A });
  const um = await c.rtdn.processarNotificacao(mensagem(corpo, 'msg_C3'));
  const dois = await c.rtdn.processarNotificacao(mensagem(corpo, 'msg_C4'));

  // O estado converge, e e o mesmo estado — nao ha direito somado nem prazo
  // esticado por reentrega. O que muda e so o carimbo da ultima verificacao.
  assert.equal(um.estado, dois.estado);
  assert.equal(um.vipAtivo, dois.vipAtivo);
  assert.equal(c.publico(U1).expiraEm, FUTURO);
  assert.equal(c.publico(U1).vipAtivo, true);
  assert.equal(c.publico(U1).estado, ESTADO.ATIVO);

  // OBSERVACAO REGISTRADA, e nao escondida: um envelope novo com o mesmo fato
  // REGRAVA o documento (consulta nova, carimbo novo). Isso e write redundante,
  // nao concessao repetida — o valor gravado e absoluto, nunca incremental. O
  // laudo classifica como Medio e explica por que nao ha impacto economico.
  assert.equal(c.db.escritasEm(publicoDe(U1)), 2);
  assert.equal(c.play.total(TOKEN_A), 2, 'cada envelope pergunta a Google de novo');
});

// ===========================================================================
// D — evento antigo depois de evento novo
// ===========================================================================

test('D notificacao atrasada nao rebaixa nem ressuscita o entitlement', async () => {
  const c = cenarioDeModulo();
  c.registrarCompra(HASH_A, { uid: U1 });

  // Renovacao: consulta carimbada em T3, prazo esticado.
  c.play.definirAssinatura(TOKEN_A, { estado: c.play.ESTADOS.ATIVA, expiraEm: FUTURO_LONGE });
  c.relogio.fila(T3);
  const nova = await c.rtdn.processarNotificacao(
    mensagem(corpoAssinatura(NOTIFICACAO.RENEWED, { token: TOKEN_A, eventoMs: 3000 }), 'msg_D_nova')
  );
  assert.equal(nova.aplicado, true);
  assert.equal(c.publico(U1).expiraEm, FUTURO_LONGE);
  c.db.zerarDiario();

  // Agora chega o evento VELHO, cuja consulta saiu em T1 e diz EXPIRED.
  c.play.definirAssinatura(TOKEN_A, { estado: c.play.ESTADOS.EXPIRADA, expiraEm: PASSADO });
  c.relogio.fila(T1);
  const velha = await c.rtdn.processarNotificacao(
    mensagem(corpoAssinatura(NOTIFICACAO.EXPIRED, { token: TOKEN_A, eventoMs: 1000 }), 'msg_D_velha')
  );

  assert.equal(velha.aplicado, false);
  assert.equal(velha.decisao, 'verificacao_antiga');
  assert.equal(c.publico(U1).vipAtivo, true, 'evento antigo derrubou o VIP');
  assert.equal(c.publico(U1).expiraEm, FUTURO_LONGE, 'evento antigo encurtou o prazo');
  assert.equal(c.db.escritasEm(publicoDe(U1)), 0, 'evento antigo escreveu no documento');
  assert.equal(c.evento('msg_D_velha').aplicado, false);
});

test('D2 evento antigo tambem nao RESSUSCITA um direito ja encerrado', async () => {
  const c = cenarioDeModulo();
  c.registrarCompra(HASH_A, { uid: U1 });

  c.play.definirAssinatura(TOKEN_A, { estado: c.play.ESTADOS.EXPIRADA, expiraEm: PASSADO });
  c.relogio.fila(T3);
  await c.rtdn.processarNotificacao(
    mensagem(corpoAssinatura(NOTIFICACAO.EXPIRED, { token: TOKEN_A }), 'msg_D2_nova')
  );
  assert.equal(c.publico(U1).vipAtivo, false);
  c.db.zerarDiario();

  // Um RENEWED atrasado, com consulta velha que ainda dizia ACTIVE.
  c.play.definirAssinatura(TOKEN_A, { estado: c.play.ESTADOS.ATIVA, expiraEm: FUTURO });
  c.relogio.fila(T1);
  const r = await c.rtdn.processarNotificacao(
    mensagem(corpoAssinatura(NOTIFICACAO.RENEWED, { token: TOKEN_A }), 'msg_D2_velha')
  );

  assert.equal(r.aplicado, false);
  assert.equal(r.decisao, 'verificacao_antiga');
  assert.equal(c.publico(U1).vipAtivo, false, 'evento antigo ressuscitou o VIP');
  assert.equal(c.db.escritasEm(publicoDe(U1)), 0);
});

// ===========================================================================
// E — renovacao
// ===========================================================================

test('E renovacao estende o prazo para a frente, sem duplicar o direito', async () => {
  const c = cenarioDeModulo();
  c.registrarCompra(HASH_A, { uid: U1 });

  c.play.definirAssinatura(TOKEN_A, { estado: c.play.ESTADOS.ATIVA, expiraEm: FUTURO });
  c.relogio.fila(T1);
  await c.rtdn.processarNotificacao(
    mensagem(corpoAssinatura(NOTIFICACAO.PURCHASED, { token: TOKEN_A }), 'msg_E1')
  );
  assert.equal(c.publico(U1).expiraEm, FUTURO);

  c.play.definirAssinatura(TOKEN_A, { estado: c.play.ESTADOS.ATIVA, expiraEm: FUTURO_LONGE });
  c.relogio.fila(T2);
  const r = await c.rtdn.processarNotificacao(
    mensagem(corpoAssinatura(NOTIFICACAO.RENEWED, { token: TOKEN_A }), 'msg_E2')
  );

  assert.equal(r.aplicado, true);
  assert.equal(c.publico(U1).expiraEm, FUTURO_LONGE);
  assert.equal(c.publico(U1).estado, ESTADO.ATIVO);
  assert.equal(c.publico(U1).vipAtivo, true);
  // Um unico documento de direito: renovar nao cria um segundo.
  assert.deepEqual(
    c.db.caminhos().filter((p) => p.startsWith('playerEntitlements/')),
    [publicoDe(U1), internoDe(U1)]
  );
  // O token continua o mesmo: renovacao nao troca a compra.
  assert.equal(c.interno(U1).purchaseTokenHash, HASH_A);
});

// ===========================================================================
// F — cancelamento com vigencia restante
// ===========================================================================

test('F cancelamento nao remove o VIP antes do fim do periodo pago', async () => {
  const c = cenarioDeModulo();
  c.registrarCompra(HASH_A, { uid: U1 });
  c.play.definirAssinatura(TOKEN_A, {
    estado: c.play.ESTADOS.CANCELADA,
    expiraEm: FUTURO,
    autoRenovacao: false,
  });
  c.relogio.fila(T1);

  const r = await c.rtdn.processarNotificacao(
    mensagem(corpoAssinatura(NOTIFICACAO.CANCELED, { token: TOKEN_A }), 'msg_F')
  );

  assert.equal(r.aplicado, true);
  assert.equal(c.publico(U1).estado, ESTADO.CANCELADO_VIGENTE);
  assert.equal(c.publico(U1).vipAtivo, true, 'cancelar tirou acesso ja pago');
  assert.equal(c.publico(U1).expiraEm, FUTURO);
  assert.equal(c.publico(U1).renovacaoAutomatica, false);
});

test('F2 cancelamento com o periodo JA vencido nao mantem acesso', async () => {
  const c = cenarioDeModulo();
  c.registrarCompra(HASH_A, { uid: U1 });
  c.play.definirAssinatura(TOKEN_A, {
    estado: c.play.ESTADOS.CANCELADA,
    expiraEm: PASSADO,
    autoRenovacao: false,
  });
  c.relogio.fila(T1);

  await c.rtdn.processarNotificacao(
    mensagem(corpoAssinatura(NOTIFICACAO.CANCELED, { token: TOKEN_A }), 'msg_F2')
  );

  assert.equal(c.publico(U1).estado, ESTADO.EXPIRADO);
  assert.equal(c.publico(U1).vipAtivo, false);
});

// ===========================================================================
// G — periodo de carencia
// ===========================================================================

test('G carencia dentro do prazo mantem acesso; carencia vencida nao vira ativo eterno', async () => {
  const dentro = cenarioDeModulo();
  dentro.registrarCompra(HASH_A, { uid: U1 });
  dentro.play.definirAssinatura(TOKEN_A, { estado: dentro.play.ESTADOS.CARENCIA, expiraEm: FUTURO });
  dentro.relogio.fila(T1);
  await dentro.rtdn.processarNotificacao(
    mensagem(corpoAssinatura(NOTIFICACAO.IN_GRACE_PERIOD, { token: TOKEN_A }), 'msg_G1')
  );
  assert.equal(dentro.publico(U1).estado, ESTADO.EM_CARENCIA);
  assert.equal(dentro.publico(U1).vipAtivo, true);

  const vencida = cenarioDeModulo();
  vencida.registrarCompra(HASH_A, { uid: U1 });
  vencida.play.definirAssinatura(TOKEN_A, { estado: vencida.play.ESTADOS.CARENCIA, expiraEm: PASSADO });
  vencida.relogio.fila(T1);
  await vencida.rtdn.processarNotificacao(
    mensagem(corpoAssinatura(NOTIFICACAO.IN_GRACE_PERIOD, { token: TOKEN_A }), 'msg_G2')
  );
  assert.equal(vencida.publico(U1).estado, ESTADO.EXPIRADO);
  assert.equal(vencida.publico(U1).vipAtivo, false, 'carencia vencida continuou concedendo');
});

// ===========================================================================
// H — account hold
// ===========================================================================

test('H hold produz em_espera sem usar o estado anterior como verdade substituta', async () => {
  const c = cenarioDeModulo();
  c.registrarCompra(HASH_A, { uid: U1 });
  // O jogador ESTAVA ativo com prazo futuro: se o hold herdasse isso, passaria.
  c.semearEntitlement(U1, {
    estado: ESTADO.ATIVO,
    vipAtivo: true,
    expiraEm: FUTURO,
    hash: HASH_A,
    token: TOKEN_A,
    verificadoEm: T0,
  });
  c.play.definirAssinatura(TOKEN_A, { estado: c.play.ESTADOS.ESPERA, expiraEm: FUTURO });
  c.relogio.fila(T1);
  c.db.zerarDiario();

  const r = await c.rtdn.processarNotificacao(
    mensagem(corpoAssinatura(NOTIFICACAO.ON_HOLD, { token: TOKEN_A }), 'msg_H')
  );

  assert.equal(r.aplicado, true);
  assert.equal(c.publico(U1).estado, ESTADO.EM_ESPERA);
  assert.equal(c.publico(U1).vipAtivo, false, 'hold manteve o VIP do estado anterior');
});

test('H2 pausa produz pausado, tambem sem acesso', async () => {
  const c = cenarioDeModulo();
  c.registrarCompra(HASH_A, { uid: U1 });
  c.play.definirAssinatura(TOKEN_A, { estado: c.play.ESTADOS.PAUSADA, expiraEm: FUTURO });
  c.relogio.fila(T1);
  await c.rtdn.processarNotificacao(
    mensagem(corpoAssinatura(NOTIFICACAO.PAUSED, { token: TOKEN_A }), 'msg_H2')
  );
  assert.equal(c.publico(U1).estado, ESTADO.PAUSADO);
  assert.equal(c.publico(U1).vipAtivo, false);
});

// ===========================================================================
// I — recuperacao
// ===========================================================================

test('I recuperacao so restaura DEPOIS da confirmacao autoritativa', async () => {
  const c = cenarioDeModulo();
  c.registrarCompra(HASH_A, { uid: U1 });
  c.semearEntitlement(U1, {
    estado: ESTADO.EM_ESPERA,
    vipAtivo: false,
    expiraEm: FUTURO,
    hash: HASH_A,
    token: TOKEN_A,
    verificadoEm: T0,
  });

  // O evento diz RECOVERED, mas a Google ainda diz ON_HOLD. Vence a Google.
  c.play.definirAssinatura(TOKEN_A, { estado: c.play.ESTADOS.ESPERA, expiraEm: FUTURO });
  c.relogio.fila(T1);
  await c.rtdn.processarNotificacao(
    mensagem(corpoAssinatura(NOTIFICACAO.RECOVERED, { token: TOKEN_A }), 'msg_I1')
  );
  assert.equal(c.publico(U1).vipAtivo, false, 'o payload concedeu sem a Google confirmar');
  assert.equal(c.publico(U1).estado, ESTADO.EM_ESPERA);

  // Agora a Google confirma.
  c.play.definirAssinatura(TOKEN_A, { estado: c.play.ESTADOS.ATIVA, expiraEm: FUTURO_LONGE });
  c.relogio.fila(T2);
  const r = await c.rtdn.processarNotificacao(
    mensagem(corpoAssinatura(NOTIFICACAO.RECOVERED, { token: TOKEN_A }), 'msg_I2')
  );
  assert.equal(r.aplicado, true);
  assert.equal(c.publico(U1).estado, ESTADO.ATIVO);
  assert.equal(c.publico(U1).vipAtivo, true);
  assert.equal(c.publico(U1).expiraEm, FUTURO_LONGE);
  assert.equal(c.interno(U1).purchaseTokenHash, HASH_A, 'a recuperacao trocou o token');
});

// ===========================================================================
// J — expiracao
// ===========================================================================

test('J expiracao encerra o VIP uma vez e nao apaga a trilha de auditoria', async () => {
  const c = cenarioDeModulo();
  c.registrarCompra(HASH_A, { uid: U1 });

  c.play.definirAssinatura(TOKEN_A, { estado: c.play.ESTADOS.ATIVA, expiraEm: FUTURO });
  c.relogio.fila(T1);
  await c.rtdn.processarNotificacao(
    mensagem(corpoAssinatura(NOTIFICACAO.PURCHASED, { token: TOKEN_A }), 'msg_J1')
  );

  c.play.definirAssinatura(TOKEN_A, { estado: c.play.ESTADOS.EXPIRADA, expiraEm: PASSADO });
  c.relogio.fila(T2);
  const r = await c.rtdn.processarNotificacao(
    mensagem(corpoAssinatura(NOTIFICACAO.EXPIRED, { token: TOKEN_A }), 'msg_J2')
  );

  assert.equal(r.aplicado, true);
  assert.equal(c.publico(U1).estado, ESTADO.EXPIRADO);
  assert.equal(c.publico(U1).vipAtivo, false);

  // A trilha dos dois eventos continua inteira.
  assert.equal(c.evento('msg_J1').aplicado, true);
  assert.equal(c.evento('msg_J2').aplicado, true);
  // O token continua guardado: e ele que permite a reconsulta administrativa.
  assert.equal(c.interno(U1).purchaseTokenHash, HASH_A);
  assert.equal(c.interno(U1).purchaseToken, TOKEN_A);
});

test('J2 a varredura por relogio fecha o vencido e NAO reescreve o prazo', async () => {
  const c = cenarioDeIndex();
  c.db.semear(publicoDe(U1), {
    uid: U1,
    vipAtivo: true,
    estado: ESTADO.ATIVO,
    produtoId: PRODUTO,
    origem: 'play',
    inicioEm: PASSADO,
    expiraEm: PASSADO,
    renovacaoAutomatica: true,
    atualizadoEm: PASSADO,
    esquema: 1,
  });
  c.db.semear(internoDe(U1), {
    uid: U1,
    purchaseTokenHash: HASH_A,
    purchaseToken: TOKEN_A,
    produtoId: PRODUTO,
    assinatura: true,
    fonte: 'rtdn',
    ultimaVerificacaoEm: PASSADO,
    esquema: 1,
  });
  // Um jogador ainda vigente nao pode ser tocado pela varredura.
  c.db.semear(publicoDe(U2), {
    uid: U2,
    vipAtivo: true,
    estado: ESTADO.ATIVO,
    produtoId: PRODUTO,
    origem: 'play',
    expiraEm: FUTURO_LONGE,
    renovacaoAutomatica: true,
    atualizadoEm: PASSADO,
    esquema: 1,
  });
  c.db.zerarDiario();

  await c.modulo.reconciliarEntitlements.run({});

  assert.equal(c.publico(U1).vipAtivo, false);
  assert.equal(c.publico(U1).estado, ESTADO.EXPIRADO);
  assert.equal(c.publico(U1).expiraEm, PASSADO, 'a varredura reescreveu o prazo');
  assert.equal(c.publico(U2).vipAtivo, true, 'a varredura tocou quem estava vigente');
  assert.equal(c.db.escritasEm(publicoDe(U2)), 0);
  // A varredura nao consulta a Google: e conclusao do relogio.
  assert.equal(c.play.total(), 0);
  // O token sobrevive ao fechamento — e ele que permite reconsultar depois.
  assert.equal(c.interno(U1).purchaseToken, TOKEN_A);
});

// ===========================================================================
// K — revogacao ou reembolso
// ===========================================================================

test('K revogacao encerra o beneficio sem afetar outro usuario nem outro produto', async () => {
  const c = cenarioDeModulo();
  // A Play responde ATIVA: o estado terminal vem do evento, e a consulta so
  // resolve o dono.
  c.play.definirAssinatura(TOKEN_A, { estado: c.play.ESTADOS.ATIVA, expiraEm: FUTURO });
  c.play.definirAssinatura(TOKEN_B, {
    estado: c.play.ESTADOS.ATIVA, expiraEm: FUTURO, contaOfuscada: VINCULO_U2,
  });
  c.semearEntitlement(U1, {
    estado: ESTADO.ATIVO, vipAtivo: true, expiraEm: FUTURO, hash: HASH_A, token: TOKEN_A, verificadoEm: T0,
  });
  c.semearEntitlement(U2, {
    estado: ESTADO.ATIVO, vipAtivo: true, expiraEm: FUTURO, hash: HASH_B, token: TOKEN_B,
    verificadoEm: T0, produtoId: PRODUTO_ANUAL,
  });
  c.db.zerarDiario();
  c.relogio.fila(T1);

  const r = await c.rtdn.processarNotificacao(
    mensagem(corpoAssinatura(NOTIFICACAO.REVOKED, { token: TOKEN_A }), 'msg_K')
  );

  assert.equal(r.aplicado, true);
  assert.equal(c.publico(U1).estado, ESTADO.REVOGADO);
  assert.equal(c.publico(U1).vipAtivo, false);
  // Revogacao acaba AGORA, e nao no fim do periodo pago.
  assert.equal(c.publico(U1).expiraEm, T1);
  assert.equal(c.interno(U1).terminalEm, T1);

  assert.equal(c.publico(U2).vipAtivo, true, 'a revogacao alcancou outro jogador');
  assert.equal(c.db.escritasEm(publicoDe(U2)), 0);
  // Uma consulta, e so sobre o token revogado: e ela que diz de quem ele e. O
  // token de U2 nao foi tocado, entao a Google nao foi perguntada sobre ele.
  assert.equal(c.play.total(TOKEN_A), 1);
  assert.equal(c.play.total(TOKEN_B), 0, 'consultou por uma compra que nao estava em jogo');
});

test('K2 reembolso e terminal mesmo com prazo futuro gravado, e nao volta atras', async () => {
  const c = cenarioDeModulo();
  c.semearEntitlement(U1, {
    estado: ESTADO.ATIVO, vipAtivo: true, expiraEm: FUTURO_LONGE, hash: HASH_A, token: TOKEN_A, verificadoEm: T0,
  });
  // A Play responde ATIVA o tempo todo — inclusive durante o estorno. E de
  // proposito: o estorno vem do EVENTO, e a consulta serve so para saber de
  // quem e a compra. Se o estado viesse da consulta, este teste nao passaria.
  c.play.definirAssinatura(TOKEN_A, { estado: c.play.ESTADOS.ATIVA, expiraEm: FUTURO_LONGE });
  c.relogio.fila(T1, T2);

  await c.rtdn.processarNotificacao(mensagem(corpoAnulacao({ token: TOKEN_A }), 'msg_K2'));
  assert.equal(c.publico(U1).estado, ESTADO.REEMBOLSADO);

  // Uma leitura atrasada que ainda diz ACTIVE nao ressuscita um estorno.
  const volta = await c.rtdn.processarNotificacao(
    mensagem(corpoAssinatura(NOTIFICACAO.RENEWED, { token: TOKEN_A }), 'msg_K2b')
  );
  assert.equal(volta.aplicado, false);
  assert.equal(volta.decisao, 'terminal_preservado');
  assert.equal(c.publico(U1).vipAtivo, false, 'o estorno foi revertido');
});

// ===========================================================================
// L — payload ausente ou malformado
// ===========================================================================

test('L payload mutilado e rejeitado sem mutacao, sem crash e sem vazar conteudo', async () => {
  const casos = [
    ['nao e base64 de JSON', mensagemCrua(Buffer.from(`{quebrado ${TOKEN_A}`, 'utf8').toString('base64'), 'msg_L1'), 'corpo_ilegivel'],
    ['data ausente', { messageId: 'msg_L2' }, 'corpo_ilegivel'],
    ['corpo nulo', mensagem(null, 'msg_L3'), 'corpo_invalido'],
    ['corpo e string', mensagem('sou um texto', 'msg_L4'), 'corpo_invalido'],
    ['sem secao reconhecida', mensagem({ packageName: PACOTE, version: '1.0' }, 'msg_L5'), 'sem_secao_reconhecida'],
    ['assinatura sem token', mensagem(corpoAssinatura(NOTIFICACAO.RENEWED, { token: null }), 'msg_L6'), 'sem_token'],
    ['anulacao sem token', mensagem(corpoAnulacao({ token: null }), 'msg_L7'), 'sem_token'],
  ];

  for (const [rotulo, msg, decisaoEsperada] of casos) {
    const c = cenarioDeModulo();
    c.registrarCompra(HASH_A, { uid: U1 });
    c.semearEntitlement(U1, {
      estado: ESTADO.ATIVO, vipAtivo: true, expiraEm: FUTURO, hash: HASH_A, token: TOKEN_A, verificadoEm: T0,
    });
    c.play.definirAssinatura(TOKEN_A, { estado: c.play.ESTADOS.ATIVA, expiraEm: FUTURO });
    c.db.zerarDiario();
    c.relogio.fila(T1);

    const r = await c.rtdn.processarNotificacao(msg);

    assert.equal(r.aplicado, false, `${rotulo}: aplicou efeito`);
    if (decisaoEsperada) assert.equal(r.decisao, decisaoEsperada, rotulo);
    assert.equal(c.db.escritasEm(publicoDe(U1)), 0, `${rotulo}: mutou o entitlement`);
    assert.equal(c.publico(U1).vipAtivo, true, `${rotulo}: mexeu no direito`);
    assertSemSegredo(c.textoDosLogs());
  }
});

test('L2 payload truncado no meio do token nao imprime o token em log nem no documento', async () => {
  const c = cenarioDeModulo();
  const truncado = `{"packageName":"${PACOTE}","subscriptionNotification":{"purchaseToken":"${TOKEN_A}`;
  await c.rtdn.processarNotificacao(
    mensagemCrua(Buffer.from(truncado, 'utf8').toString('base64'), 'msg_L2b')
  );
  assertSemSegredo(c.textoDosLogs());
  assertSemSegredo(JSON.stringify(c.db.caminhos()) + JSON.stringify(c.evento('msg_L2b')));
});

// ===========================================================================
// M — consulta por token sem productId
// ===========================================================================

test('M sem productId no item, o produto sai da NOTIFICACAO — nunca inventado', async () => {
  const c = cenarioDeModulo();
  // A Play nao devolve productId no item; a notificacao diz qual e a assinatura.
  c.play.definirCorpoBruto(TOKEN_A, {
    subscriptionState: c.play.ESTADOS.ATIVA,
    startTime: PASSADO,
    lineItems: [{ expiryTime: FUTURO, autoRenewingPlan: { autoRenewEnabled: true } }],
  });
  c.relogio.fila(T1);

  const r = await c.rtdn.processarNotificacao(
    mensagem(corpoAssinatura(NOTIFICACAO.RENEWED, { token: TOKEN_A, produtoId: PRODUTO_ANUAL }), 'msg_M1')
  );

  assert.equal(r.aplicado, true);
  assert.equal(c.publico(U1).produtoId, PRODUTO_ANUAL, 'resolveu para o produto errado');
});

test('M2 sem produto em lugar nenhum, o campo fica nulo em vez de inventado', async () => {
  const c = cenarioDeModulo();
  c.registrarCompra(HASH_A, { uid: U1, produtoId: null });
  c.play.definirCorpoBruto(TOKEN_A, {
    subscriptionState: c.play.ESTADOS.ATIVA,
    startTime: PASSADO,
    lineItems: [{ expiryTime: FUTURO }],
  });
  c.relogio.fila(T1);

  await c.rtdn.processarNotificacao(
    mensagem(corpoAssinatura(NOTIFICACAO.RENEWED, { token: TOKEN_A, produtoId: null }), 'msg_M2')
  );

  assert.equal(c.publico(U1).produtoId, null);
  assert.equal(c.publico(U1).vipAtivo, true);
});

// ===========================================================================
// N — produto desconhecido
// ===========================================================================

test('N produto fora do catalogo nao concede e nao cria configuracao implicita', async () => {
  const c = cenarioDeIndex({ catalogo: { [PRODUTO]: { assinatura: true } } });
  c.play.definirAssinatura(TOKEN_A, { estado: c.play.ESTADOS.ATIVA, expiraEm: FUTURO });
  c.db.zerarDiario();

  await assert.rejects(
    () => c.chamar('validarCompraPlay', {
      uid: U1,
      dados: { produtoId: 'produto_que_ninguem_cadastrou', tokenCompra: TOKEN_A, assinatura: true },
    }),
    (e) => e.code === 'failed-precondition'
  );

  assert.equal(c.publico(U1), null, 'produto desconhecido concedeu VIP');
  assert.equal(c.compra(HASH_A), null, 'registrou a compra antes de conferir o catalogo');
  assert.equal(c.db.ver('configuracao/billing').produtos.produto_que_ninguem_cadastrou, undefined);
  assert.equal(c.play.total(), 0, 'perguntou a Google por um produto que nao existe');
});

test('N2 catalogo vazio recusa tudo, que e o estado atual declarado da base', async () => {
  const c = cenarioDeIndex({ catalogo: {} });
  c.play.definirAssinatura(TOKEN_A, { estado: c.play.ESTADOS.ATIVA, expiraEm: FUTURO });

  await assert.rejects(
    () => c.chamar('validarCompraPlay', {
      uid: U1, dados: { produtoId: PRODUTO, tokenCompra: TOKEN_A, assinatura: true },
    }),
    (e) => e.code === 'failed-precondition'
  );
  assert.equal(c.publico(U1), null);
});

test('N3 tipo divergente entre payload e catalogo e recusado', async () => {
  const c = cenarioDeIndex();
  c.play.definirAssinatura(TOKEN_A, { estado: c.play.ESTADOS.ATIVA, expiraEm: FUTURO });

  await assert.rejects(
    () => c.chamar('validarCompraPlay', {
      // Declarado consumivel, mas o catalogo diz que e assinatura.
      uid: U1, dados: { produtoId: PRODUTO, tokenCompra: TOKEN_A, assinatura: false },
    }),
    (e) => e.code === 'invalid-argument'
  );
  assert.equal(c.publico(U1), null);
});

test('N4 notificacao de produto avulso nao produz entitlement VIP', async () => {
  // O guarda mudou de lugar, e o comportamento nao. Antes, um token registrado
  // como consumivel era barrado por `titularDoToken` (`nao_e_assinatura`) — um
  // guarda que morava na autoridade de propriedade errada. Hoje o proprio tipo
  // da notificacao encerra o caminho: produto avulso credita fichas na validacao
  // e acaba ali, sem ciclo de vida para acompanhar.
  const c = cenarioDeModulo();
  c.relogio.fila(T1);

  const r = await c.rtdn.processarNotificacao(mensagem({
    version: '1.0',
    packageName: PACOTE,
    eventTimeMillis: '1000',
    oneTimeProductNotification: { notificationType: 1, purchaseToken: TOKEN_A, sku: PRODUTO_FICHAS },
  }, 'msg_N4'));

  assert.equal(r.decisao, 'produto_avulso');
  assert.equal(r.aplicado, false);
  assert.equal(c.publico(U1), null);
  assert.equal(c.play.total(), 0, 'gastou consulta por um evento sem ciclo de vida');
});

// ===========================================================================
// O — datas e vigencias invalidas
// ===========================================================================

test('O prazo ausente, absurdo ou no passado nao concede nem estende', async () => {
  const casos = [
    ['expiryTime ausente', undefined],
    ['expiryTime nulo', null],
    ['expiryTime vazio', ''],
    ['expiryTime nao data', 'depois-do-carnaval'],
    ['expiryTime numero negativo', -86400000],
    ['expiryTime no passado', PASSADO],
    ['expiryTime NaN', Number.NaN],
    ['expiryTime objeto', { quando: 'nunca' }],
  ];

  for (const [rotulo, expiraEm] of casos) {
    const c = cenarioDeModulo();
    c.play.definirAssinatura(TOKEN_A, { estado: c.play.ESTADOS.ATIVA, expiraEm });
    c.relogio.fila(T1);

    await c.rtdn.processarNotificacao(
      mensagem(corpoAssinatura(NOTIFICACAO.RENEWED, { token: TOKEN_A }), 'msg_O')
    );

    // Duas recusas legitimas: prazo que a Google mandou e que ja passou vira
    // `expirado` gravado; prazo que nem e data e barrado na conferencia de forma
    // e nao chega a virar documento. Nenhuma das duas concede.
    assertNaoConcedeu(c, U1, rotulo);
    const pub = c.publico(U1);
    if (pub !== null) {
      assert.equal(pub.estado, ESTADO.EXPIRADO, `${rotulo}: estado errado`);
    }
  }
});

test('O2 lineItems ausente, vazio ou de tipo errado nao concede', async () => {
  for (const itens of [undefined, null, [], 'nao e lista', {}]) {
    const c = cenarioDeModulo();
    c.registrarCompra(HASH_A, { uid: U1 });
    c.play.definirCorpoBruto(TOKEN_A, {
      subscriptionState: c.play.ESTADOS.ATIVA,
      startTime: PASSADO,
      lineItems: itens,
    });
    c.relogio.fila(T1);

    await c.rtdn.processarNotificacao(
      mensagem(corpoAssinatura(NOTIFICACAO.RENEWED, { token: TOKEN_A }), 'msg_O2')
    );
    assertNaoConcedeu(c, U1, `lineItems=${JSON.stringify(itens)}`);
  }
});

test('O2b elemento nulo em lineItems e recusado, sem derrubar o processo', async () => {
  // ESTE TESTE ERA O REGISTRO DE UM DEFEITO, E FOI INVERTIDO.
  //
  // Antes: `consolidarAssinatura` protegia o item dentro do laco e usava o mesmo
  // item sem protecao fora dele (`itens[0].productId`), entao um elemento nulo
  // virava TypeError nao tratado. A excecao subia, `retry: true` reentregava, e a
  // mensagem virava pilula envenenada — reentregue ate a retencao do topico
  // expirar, sem nunca produzir decisao auditavel.
  //
  // Agora sao duas defesas: `validarRespostaAssinatura` RECUSA a resposta inteira
  // antes da consolidacao, e `consolidarAssinatura` filtra a colecao antes de
  // percorre-la. A recusa e controlada, entra na trilha, e nao se repete.
  for (const itens of [[null], [undefined], ['nao e objeto'], [[]], [{ expiryTime: 'nunca' }]]) {
    const c = cenarioDeModulo();
    c.semearEntitlement(U1, {
      estado: ESTADO.ATIVO, vipAtivo: true, expiraEm: FUTURO, hash: HASH_A, token: TOKEN_A, verificadoEm: T0,
    });
    c.play.definirCorpoBruto(TOKEN_A, {
      subscriptionState: c.play.ESTADOS.ATIVA,
      startTime: PASSADO,
      lineItems: itens,
    });
    c.db.zerarDiario();
    c.relogio.fila(T1);

    const r = await c.rtdn.processarNotificacao(
      mensagem(corpoAssinatura(NOTIFICACAO.RENEWED, { token: TOKEN_A }), 'msg_O2b')
    );

    const rotulo = JSON.stringify(itens);
    assert.equal(r.aplicado, false, `${rotulo}: aplicou`);
    assert.equal(r.decisao, 'resposta_play_invalida', rotulo);
    // O direito anterior nao foi tocado, e a recusa ficou na trilha.
    assert.equal(c.db.escritasEm(publicoDe(U1)), 0, `${rotulo}: mutou o entitlement`);
    assert.equal(c.publico(U1).vipAtivo, true, rotulo);
    assert.equal(c.evento('msg_O2b').decisao, 'resposta_play_invalida', rotulo);
    assertSemSegredo(c.textoDosLogs());
  }
});

test('O3 estado que a plataforma ainda nao inventou vira desconhecido e NAO concede', async () => {
  for (const bruto of ['SUBSCRIPTION_STATE_QUANTUM', '', null, 42, 'SUBSCRIPTION_STATE_UNSPECIFIED']) {
    const c = cenarioDeModulo();
    c.registrarCompra(HASH_A, { uid: U1 });
    c.play.definirCorpoBruto(TOKEN_A, {
      subscriptionState: bruto,
      startTime: PASSADO,
      lineItems: [{ productId: PRODUTO, expiryTime: FUTURO }],
    });
    c.relogio.fila(T1);

    await c.rtdn.processarNotificacao(
      mensagem(corpoAssinatura(NOTIFICACAO.RENEWED, { token: TOKEN_A }), 'msg_O3')
    );
    assertNaoConcedeu(c, U1, `estado ${bruto}`);
    // Duas recusas legitimas, e as duas valem. Estado de TEXTO que a plataforma
    // nao inventou ainda vira `desconhecido` e fica gravado como recusa
    // investigavel; estado que nem e texto e barrado antes, na conferencia de
    // forma, e nao chega a virar documento. O que nao pode e conceder.
    const pub = c.publico(U1);
    if (pub !== null) {
      assert.equal(pub.estado, ESTADO.DESCONHECIDO, `estado ${bruto} virou outra coisa`);
    } else {
      assert.equal(typeof bruto === 'string', false, `estado ${bruto} devia ter virado documento`);
    }
  }
});

test('O4 corpo de resposta vazio ou nulo nao concede', async () => {
  for (const corpo of [null, undefined, {}, [], 'texto']) {
    const c = cenarioDeModulo();
    c.registrarCompra(HASH_A, { uid: U1 });
    c.play.definirCorpoBruto(TOKEN_A, corpo);
    c.relogio.fila(T1);

    await c.rtdn.processarNotificacao(
      mensagem(corpoAssinatura(NOTIFICACAO.RENEWED, { token: TOKEN_A }), 'msg_O4')
    );
    assertNaoConcedeu(c, U1, `corpo ${JSON.stringify(corpo)}`);
  }
});

// ===========================================================================
// P — timeout ou erro transitorio da Play
// ===========================================================================

test('P falha transitoria da Play SOBE, preserva o estado e nao marca o evento concluido', async () => {
  const c = cenarioDeModulo();
  c.registrarCompra(HASH_A, { uid: U1 });
  c.semearEntitlement(U1, {
    estado: ESTADO.ATIVO, vipAtivo: true, expiraEm: FUTURO, hash: HASH_A, token: TOKEN_A, verificadoEm: T0,
  });
  c.play.definirFalha(TOKEN_A, new FalhaTransitoriaPlay('504 gateway timeout'));
  c.db.zerarDiario();
  c.relogio.fila(T1);

  await assert.rejects(
    () => c.rtdn.processarNotificacao(
      mensagem(corpoAssinatura(NOTIFICACAO.EXPIRED, { token: TOKEN_A }), 'msg_P')
    ),
    (e) => e.transitoria === true
  );

  // Sem consolidar nada, e sem marcar "ja processei" — senao a reentrega do
  // Pub/Sub encontraria o evento concluido e desistiria de um trabalho por fazer.
  assert.equal(c.publico(U1).vipAtivo, true, 'consolidou sobre uma falha');
  assert.equal(c.db.escritasEm(publicoDe(U1)), 0);
  assert.equal(c.evento('msg_P'), null, 'evento marcado concluido sem ter concluido');
  assertSemSegredo(c.textoDosLogs());
});

test('P2 a reentrega depois da falha converge, e o efeito acontece uma vez so', async () => {
  const c = cenarioDeModulo();
  c.registrarCompra(HASH_A, { uid: U1 });
  c.play.definirFalhaSeguidaDeSucesso(
    TOKEN_A,
    new FalhaTransitoriaPlay('503 service unavailable'),
    2,
    { estado: 'SUBSCRIPTION_STATE_ACTIVE', expiraEm: FUTURO, produtoId: PRODUTO }
  );
  c.relogio.fila(T1, T2, T3);
  const msg = mensagem(corpoAssinatura(NOTIFICACAO.RENEWED, { token: TOKEN_A }), 'msg_P2');

  await assert.rejects(() => c.rtdn.processarNotificacao(msg));
  await assert.rejects(() => c.rtdn.processarNotificacao(msg));
  const r = await c.rtdn.processarNotificacao(msg);

  assert.equal(r.aplicado, true);
  assert.equal(c.publico(U1).vipAtivo, true);
  assert.equal(c.db.escritasEm(publicoDe(U1)), 1, 'a reentrega escreveu mais de uma vez');
  assert.equal(c.evento('msg_P2').aplicado, true);
});

test('P3 falha da Play na validacao nao concede e nao marca a compra como recusada', async () => {
  const c = cenarioDeIndex();
  c.play.definirFalha(TOKEN_A, new FalhaTransitoriaPlay('ETIMEDOUT'));
  // O diario zera DEPOIS das sementes (catalogo e vinculos): o que se mede aqui
  // e o que a chamada escreveu, e nao o que o cenario montou.
  c.db.zerarDiario();

  await assert.rejects(
    () => c.chamar('validarCompraPlay', {
      uid: U1, dados: { produtoId: PRODUTO, tokenCompra: TOKEN_A, assinatura: true },
    }),
    (e) => e.code === 'unavailable'
  );

  assert.equal(c.publico(U1), null, 'concedeu sem confirmacao autoritativa');
  // INVERTIDO, e para um resultado MAIS forte. Antes o registro da compra ja
  // existia neste ponto (criado antes da consulta) e o teste so podia exigir que
  // ele nao estivesse marcado `recusada`. Agora nada e gravado enquanto a Google
  // nao confirma, entao nao ha registro nenhum para ficar pendente — e nao ha
  // documento para envenenar o caminho de ninguem.
  assert.equal(c.compra(HASH_A), null, 'gravou a compra sem confirmacao da Google');
  assert.equal(c.db.diario.length, 0, 'escreveu alguma coisa antes de confirmar');
});

// ===========================================================================
// Q — concorrencia sobre o mesmo token
// ===========================================================================

test('Q duas execucoes simultaneas sobre o mesmo token convergem, com uma concessao so', async () => {
  const c = cenarioDeModulo();
  c.registrarCompra(HASH_A, { uid: U1 });
  c.db.zerarDiario();

  // Interleaving deterministico: a primeira transacao e segurada ate a segunda
  // ter lido o mesmo estado. Sem isto, "concorrencia" viraria sorteio.
  let segurar = true;
  let liberar;
  const porta = new Promise((r) => { liberar = r; });
  c.db.pausarAntesDoCommit = async () => {
    if (segurar) { segurar = false; await porta; }
  };

  const a = c.store.aplicarProposta({
    uid: U1, estado: ESTADO.ATIVO, vipAtivo: true, produtoId: PRODUTO,
    inicioEm: PASSADO, expiraEm: FUTURO, renovacaoAutomatica: true, origem: 'play',
    purchaseTokenHash: HASH_A, purchaseToken: TOKEN_A, verificadoEm: T1, fonte: 'rtdn',
  }, { id: 'msg_Q_a', tipo: NOTIFICACAO.RENEWED });

  const b = c.store.aplicarProposta({
    uid: U1, estado: ESTADO.ATIVO, vipAtivo: true, produtoId: PRODUTO,
    inicioEm: PASSADO, expiraEm: FUTURO_LONGE, renovacaoAutomatica: true, origem: 'play',
    purchaseTokenHash: HASH_A, purchaseToken: TOKEN_A, verificadoEm: T2, fonte: 'rtdn',
  }, { id: 'msg_Q_b', tipo: NOTIFICACAO.RENEWED });

  liberar();
  const [ra, rb] = await Promise.all([a, b]);

  assert.ok(c.db.conflitos >= 1, 'a corrida nao chegou a existir: nao houve contencao');
  // Vence quem consultou a Google por ULTIMO, e nao quem commitou por ultimo.
  assert.equal(c.publico(U1).expiraEm, FUTURO_LONGE);
  assert.equal(c.publico(U1).vipAtivo, true);
  assert.equal(c.interno(U1).ultimaVerificacaoEm, T2);
  assert.ok(ra.aplicado || rb.aplicado);
  // Um unico documento de direito, e os dois eventos registrados.
  assert.deepEqual(
    c.db.caminhos().filter((p) => p.startsWith('playerEntitlements/')),
    [publicoDe(U1), internoDe(U1)]
  );
  assert.ok(c.evento('msg_Q_a'));
  assert.ok(c.evento('msg_Q_b'));
});

test('Q2 dez execucoes simultaneas convergem para um unico estado', async () => {
  // `maxTentativas` acima do padrao de 5 de proposito: o Firestore falso nao tem
  // backoff, entao dez transacoes disputando o mesmo documento esgotam o
  // orcamento do SDK real por uma razao que e do MODELO, nao do codigo. Confundir
  // "o fake desistiu" com "o codigo duplicou" seria o pior erro possivel aqui.
  const c = cenarioDeModulo({ maxTentativas: 60 });
  c.registrarCompra(HASH_A, { uid: U1 });
  c.db.zerarDiario();

  const instantes = [T1, T2, T3, T4, '2026-08-16T15:00:00.000Z', '2026-08-16T16:00:00.000Z',
    '2026-08-16T17:00:00.000Z', '2026-08-16T18:00:00.000Z', '2026-08-16T19:00:00.000Z',
    '2026-08-16T20:00:00.000Z'];

  const resultados = await Promise.all(instantes.map((quando, i) =>
    c.store.aplicarProposta({
      uid: U1, estado: ESTADO.ATIVO, vipAtivo: true, produtoId: PRODUTO,
      inicioEm: PASSADO, expiraEm: FUTURO, renovacaoAutomatica: true, origem: 'play',
      purchaseTokenHash: HASH_A, purchaseToken: TOKEN_A, verificadoEm: quando, fonte: 'rtdn',
    }, { id: `msg_Q2_${i}`, tipo: NOTIFICACAO.RENEWED })
  ));

  assert.equal(resultados.length, 10);
  assert.equal(c.publico(U1).vipAtivo, true);
  assert.equal(c.publico(U1).estado, ESTADO.ATIVO);
  // O carimbo final e o da consulta mais nova, venha ela em que ordem vier.
  assert.equal(c.interno(U1).ultimaVerificacaoEm, instantes[instantes.length - 1]);
  assert.deepEqual(
    c.db.caminhos().filter((p) => p.startsWith('playerEntitlements/')),
    [publicoDe(U1), internoDe(U1)]
  );
});

test('Q3 dez validacoes simultaneas do MESMO consumivel creditam as fichas uma vez so', async () => {
  const c = cenarioDeIndex({ maxTentativas: 80 });
  c.play.definirProduto(TOKEN_B, { purchaseState: 0, produtoId: PRODUTO_FICHAS });

  const chamadas = Array.from({ length: 10 }, () =>
    c.chamar('validarCompraPlay', {
      uid: U1, dados: { produtoId: PRODUTO_FICHAS, tokenCompra: TOKEN_B, assinatura: false },
    }).catch((e) => ({ erro: e.code || e.message }))
  );
  const resultados = await Promise.all(chamadas);

  const aprovadas = resultados.filter((r) => r.aprovada === true);
  assert.equal(aprovadas.length, 10, 'alguma execucao concorrente falhou');
  const creditaram = resultados.filter((r) => r.jaProcessada === false);
  assert.equal(creditaram.length, 1, 'mais de uma execucao creditou');
  assert.equal(c.usuario(U1).fichas, 1000, 'as fichas foram creditadas mais de uma vez');
  assert.equal(c.compra(chaveDaCompra(TOKEN_B)).estado, 'concedida');
});

// ===========================================================================
// R — token ja vinculado a outro usuario
// ===========================================================================

test('R token de outro jogador e recusado e o vinculo original e preservado', async () => {
  const c = cenarioDeIndex();
  c.play.definirAssinatura(TOKEN_A, { estado: c.play.ESTADOS.ATIVA, expiraEm: FUTURO });

  const dono = await c.chamar('validarCompraPlay', {
    uid: U1, dados: { produtoId: PRODUTO, tokenCompra: TOKEN_A, assinatura: true },
  });
  assert.equal(dono.aprovada, true);
  c.db.zerarDiario();

  await assert.rejects(
    () => c.chamar('validarCompraPlay', {
      uid: U2, dados: { produtoId: PRODUTO, tokenCompra: TOKEN_A, assinatura: true },
    }),
    (e) => e.code === 'permission-denied'
  );

  assert.equal(c.compra(HASH_A).uid, U1, 'o vinculo trocou de dono');
  assert.equal(c.publico(U2), null, 'o invasor recebeu VIP');
  assert.equal(c.publico(U1).vipAtivo, true, 'o dono perdeu o direito');
  assert.equal(c.db.escritasEm(publicoDe(U1)), 0);
});

test('R2 tambem recusa quando o token esta registrado para outro PRODUTO ou outro tipo', async () => {
  const c = cenarioDeIndex();
  c.play.definirAssinatura(TOKEN_A, { estado: c.play.ESTADOS.ATIVA, expiraEm: FUTURO });
  await c.chamar('validarCompraPlay', {
    uid: U1, dados: { produtoId: PRODUTO, tokenCompra: TOKEN_A, assinatura: true },
  });

  await assert.rejects(
    () => c.chamar('validarCompraPlay', {
      uid: U1, dados: { produtoId: PRODUTO_ANUAL, tokenCompra: TOKEN_A, assinatura: true },
    }),
    (e) => e.code === 'permission-denied'
  );
  assert.equal(c.compra(HASH_A).produtoId, PRODUTO);
});

test('R3 notificacao sobre token de outro dono nao encosta no entitlement alheio', async () => {
  const c = cenarioDeModulo();
  c.semearEntitlement(U1, {
    estado: ESTADO.ATIVO, vipAtivo: true, expiraEm: FUTURO, hash: HASH_A, token: TOKEN_A, verificadoEm: T0,
  });
  // O TOKEN_B pertence a U2, e quem diz isso e a GOOGLE: o identificador que ela
  // devolve e o de U2. Nao ha registro local que possa contradizer.
  c.play.definirAssinatura(TOKEN_B, {
    estado: c.play.ESTADOS.ATIVA, expiraEm: FUTURO, contaOfuscada: VINCULO_U2,
  });
  c.db.zerarDiario();
  c.relogio.fila(T1);

  const r = await c.rtdn.processarNotificacao(mensagem(corpoAnulacao({ token: TOKEN_B }), 'msg_R3'));

  assert.equal(r.uid, U2, 'a notificacao foi atribuida ao jogador errado');
  assert.equal(c.publico(U1).vipAtivo, true, 'o estorno alheio derrubou o VIP do titular');
  assert.equal(c.db.escritasEm(publicoDe(U1)), 0);
  assert.equal(c.publico(U2).estado, ESTADO.REEMBOLSADO);
  assertSemSegredo(c.textoDosLogs());
});

test('R4 vinculo que nao pertence a ninguem falha fechado, sem inventar dono', async () => {
  const c = cenarioDeModulo();
  // Identificador BEM FORMADO, e registrado por ninguem. E o caso que separa
  // "nao sei de quem e" de "e do primeiro que aparecer".
  c.play.definirAssinatura(TOKEN_C, {
    estado: c.play.ESTADOS.ATIVA, expiraEm: FUTURO, contaOfuscada: VINCULO_ORFAO,
  });
  c.relogio.fila(T1);

  const r = await c.rtdn.processarNotificacao(
    mensagem(corpoAssinatura(NOTIFICACAO.RENEWED, { token: TOKEN_C }), 'msg_R4')
  );

  assert.equal(r.decisao, 'vinculo_desconhecido');
  assert.equal(r.aplicado, false);
  assert.deepEqual(c.db.caminhos().filter((p) => p.startsWith('playerEntitlements/')), []);
  assert.equal(c.evento('msg_R4').decisao, 'vinculo_desconhecido');
  assertSemSegredo(c.textoDosLogs());
});

test('R6 quem apresenta o token de outra conta e recusado, e nao deixa rastro', async () => {
  // ESTE TESTE ERA O REGISTRO DO ACHADO A-1, E FOI INVERTIDO. Ele e o motivo
  // desta OS existir, entao vale dizer com precisao o que mudou.
  //
  // ANTES: `compras/{hash}` nascia com o uid de quem chamasse primeiro, ANTES de
  // a Google ser consultada. Quem tivesse o purchaseToken da vitima e chegasse
  // antes ficava com o VIP, e o pagante recebia `permission-denied` para sempre —
  // o mesmo guarda que protege o caso R trabalhava a favor do invasor.
  //
  // AGORA: a propriedade sai do identificador que a Google devolve, e a
  // igualdade com a conta autenticada e exigida ANTES de qualquer escrita.
  const c = cenarioDeIndex();
  // A compra e de U1: e o vinculo DELE que a Google devolve.
  c.play.definirAssinatura(TOKEN_A, {
    estado: c.play.ESTADOS.ATIVA, expiraEm: FUTURO, contaOfuscada: VINCULO_U1,
  });
  c.db.zerarDiario();

  // U2 tem o token de U1 e chega primeiro.
  await assert.rejects(
    () => c.chamar('validarCompraPlay', {
      uid: U2, dados: { produtoId: PRODUTO, tokenCompra: TOKEN_A, assinatura: true },
    }),
    (e) => e.code === 'permission-denied' && e.details.motivo === 'vinculo_divergente'
  );

  // 3) NAO criou `compras/{hash}`.  4) NAO criou entitlement.
  assert.equal(c.compra(HASH_A), null, 'o invasor gravou o registro da compra');
  assert.equal(c.publico(U2), null, 'o invasor recebeu VIP');
  assert.equal(c.publico(U1), null, 'o entitlement do dono foi mexido');
  // Nenhum documento envenenado: a tentativa nao deixou rastro nenhum.
  assert.equal(c.db.diario.length, 0, 'a tentativa escreveu no Firestore');

  // 5) O ATAQUE NAO IMPEDE A VALIDACAO POSTERIOR PELO PROPRIETARIO. Esta e a
  //    metade que faltava: recusar o invasor nao vale nada se a recusa deixar o
  //    dono trancado do lado de fora.
  const dono = await c.chamar('validarCompraPlay', {
    uid: U1, dados: { produtoId: PRODUTO, tokenCompra: TOKEN_A, assinatura: true },
  });
  assert.equal(dono.aprovada, true, 'o ataque trancou o proprietario legitimo');
  assert.equal(c.publico(U1).vipAtivo, true);
  assert.equal(c.compra(HASH_A).uid, U1);
  assert.equal(c.publico(U2), null);

  // 11) E a notificacao daquela compra alimenta o DONO, nunca quem pediu antes.
  await c.entregar(corpoAssinatura(NOTIFICACAO.RENEWED, { token: TOKEN_A }), 'msg_R6');
  assert.equal(c.publico(U1).vipAtivo, true);
  assert.equal(c.publico(U2), null, 'a notificacao alimentou o invasor');
});

test('R6b invasor e proprietario apresentando o mesmo token AO MESMO TEMPO', async () => {
  // O caso 2 da matriz da OS. A recusa do invasor nao pode depender de o dono ter
  // chegado antes — se dependesse, seria de novo uma regra de ordem de chegada,
  // so que invertida.
  const c = cenarioDeIndex({ maxTentativas: 40 });
  c.play.definirAssinatura(TOKEN_A, {
    estado: c.play.ESTADOS.ATIVA, expiraEm: FUTURO, contaOfuscada: VINCULO_U1,
  });

  const tentativa = (uid) => c.chamar('validarCompraPlay', {
    uid, dados: { produtoId: PRODUTO, tokenCompra: TOKEN_A, assinatura: true },
  }).then((r) => ({ uid, ok: true, r }), (e) => ({ uid, ok: false, code: e.code }));

  const [invasor, dono] = await Promise.all([tentativa(U2), tentativa(U1)]);

  assert.equal(invasor.ok, false, 'o invasor foi aprovado');
  assert.equal(invasor.code, 'permission-denied');
  assert.equal(dono.ok, true, 'o dono foi recusado por causa da corrida');
  assert.equal(c.compra(HASH_A).uid, U1);
  assert.equal(c.publico(U1).vipAtivo, true);
  assert.equal(c.publico(U2), null);
});

test('R5 chamada sem autenticacao nao chega a tocar em nada', async () => {
  const c = cenarioDeIndex();
  c.play.definirAssinatura(TOKEN_A, { estado: c.play.ESTADOS.ATIVA, expiraEm: FUTURO });
  c.db.zerarDiario();

  await assert.rejects(
    () => c.chamar('validarCompraPlay', {
      uid: null, dados: { produtoId: PRODUTO, tokenCompra: TOKEN_A, assinatura: true },
    }),
    (e) => e.code === 'unauthenticated'
  );
  assert.equal(c.db.diario.length, 0);
});

// ===========================================================================
// Y — A AUTORIDADE DA VINCULACAO
// ===========================================================================
//
// Os casos que a correcao P0 acrescentou. Nao existiam na matriz A-W porque, ate
// ela, nao existia autoridade nenhuma sobre a propriedade de uma compra.

test('Y1 a preparacao e estavel: chamar de novo devolve o MESMO identificador', async () => {
  const c = cenarioDeIndex({ vincular: false });

  const um = await c.chamar('prepararCompraPlay', { uid: U1 });
  const dois = await c.chamar('prepararCompraPlay', { uid: U1 });
  const tres = await c.chamar('prepararCompraPlay', { uid: U1 });

  assert.equal(um.contaOfuscada, dois.contaOfuscada);
  assert.equal(dois.contaOfuscada, tres.contaOfuscada);
  assert.ok(vinculoBemFormado(um.contaOfuscada), 'identificador mal formado');
  assert.ok(um.contaOfuscada.length <= 64, 'passou do limite da Play Billing Library');
  // Uma conta, um vinculo. A segunda e a terceira chamadas nao escrevem.
  assert.equal(c.db.escritasEm(`playerBillingIdentity/${U1}`), 1);
  assert.equal(c.db.escritasEm(`billingAccountIndex/${um.contaOfuscada}`), 1);
});

test('Y2 contas diferentes recebem identificadores diferentes', async () => {
  const c = cenarioDeIndex({ vincular: false });
  const a = await c.chamar('prepararCompraPlay', { uid: U1 });
  const b = await c.chamar('prepararCompraPlay', { uid: U2 });

  assert.notEqual(a.contaOfuscada, b.contaOfuscada);
  assert.equal(c.db.ver(`billingAccountIndex/${a.contaOfuscada}`).uid, U1);
  assert.equal(c.db.ver(`billingAccountIndex/${b.contaOfuscada}`).uid, U2);
});

test('Y3 criacao CONCORRENTE da vinculacao produz uma autoridade so', async () => {
  // Dez preparacoes simultaneas da mesma conta. Cada uma gera um candidato
  // diferente; a transacao garante que so um vira o vinculo e que as outras nove
  // releem e devolvem esse mesmo. Sem isso, duas compras da mesma pessoa
  // poderiam apontar para identificadores diferentes e uma delas ficaria orfa.
  const c = cenarioDeIndex({ vincular: false, maxTentativas: 60 });

  const respostas = await Promise.all(
    Array.from({ length: 10 }, () => c.chamar('prepararCompraPlay', { uid: U1 }))
  );

  const distintos = new Set(respostas.map((r) => r.contaOfuscada));
  assert.equal(distintos.size, 1, `nasceram ${distintos.size} vinculos para a mesma conta`);
  const vinculo = respostas[0].contaOfuscada;
  assert.equal(c.db.escritasEm(`playerBillingIdentity/${U1}`), 1);
  assert.equal(c.db.ver(`billingAccountIndex/${vinculo}`).uid, U1);
  // E nenhum indice orfao ficou para tras.
  assert.deepEqual(
    c.db.caminhos().filter((p) => p.startsWith('billingAccountIndex/')),
    [`billingAccountIndex/${vinculo}`]
  );
});

test('Y4 o cliente NAO escolhe a vinculacao', async () => {
  const c = cenarioDeIndex({ vincular: false });
  const escolhido = '33'.repeat(24);

  const r = await c.chamar('prepararCompraPlay', {
    uid: U1,
    // O payload tenta ditar o identificador, de tres formas.
    dados: { contaOfuscada: escolhido, obfuscatedAccountId: escolhido, vinculo: escolhido },
  });

  assert.notEqual(r.contaOfuscada, escolhido, 'o cliente escolheu o proprio vinculo');
  assert.equal(c.db.ver(`billingAccountIndex/${escolhido}`), null);
  assert.equal(c.db.ver(`billingAccountIndex/${r.contaOfuscada}`).uid, U1);
});

test('Y5 o identificador nao carrega uid, e-mail nem publicId', async () => {
  const c = cenarioDeIndex({ vincular: false });
  const r = await c.chamar('prepararCompraPlay', { uid: 'uid-de-sonia@exemplo.invalid' });

  const v = r.contaOfuscada;
  for (const agulha of ['uid', 'sonia', 'exemplo', 'invalid', '@', 'jogador', 'publicId']) {
    assert.ok(!v.includes(agulha), `o identificador carrega "${agulha}" em claro`);
  }
  // So hexadecimal: nao ha onde esconder texto.
  assert.match(v, /^[0-9a-f]+$/);
});

test('Y6 identificador MAL FORMADO nao vira sequer uma leitura', async () => {
  const c = cenarioDeModulo({ vincular: false });
  // `uidDoVinculo` recusa pela FORMA antes de consultar o Firestore: um id de
  // documento arbitrario nao deve nem virar leitura.
  c.db.semear('billingAccountIndex/alvo-arbitrario', { uid: U1 });
  const antes = c.db.leiturasSoltas;

  for (const torto of ['alvo-arbitrario', 'MAIUSCULAS'.repeat(4), 'z'.repeat(48), '', null, 'ab', 'f'.repeat(65)]) {
    assert.equal(await c.store.uidDoVinculo(torto), null, `aceitou "${torto}"`);
  }
  assert.equal(c.db.leiturasSoltas, antes, 'um identificador mal formado virou leitura');
});

test('Y7 RTDN que chega ANTES da validacao encontra o proprietario certo', async () => {
  // E a razao pela qual a vinculacao nasce na PREPARACAO e nao na validacao: a
  // notificacao da Google pode chegar antes de o aplicativo voltar a falar com o
  // backend. Se a propriedade dependesse de `validarCompraPlay` ter rodado, este
  // evento nao teria dono — e a versao antiga resolvia isso escolhendo o
  // primeiro solicitante.
  const c = cenarioDeIndex({ vincular: false });
  const { contaOfuscada } = await c.chamar('prepararCompraPlay', { uid: U1 });
  c.play.definirAssinatura(TOKEN_A, {
    estado: c.play.ESTADOS.ATIVA, expiraEm: FUTURO, contaOfuscada,
  });

  // Nenhuma validacao aconteceu: nao ha `compras/{hash}`.
  assert.equal(c.compra(HASH_A), null);

  await c.entregar(corpoAssinatura(NOTIFICACAO.PURCHASED, { token: TOKEN_A }), 'msg_Y7');

  assert.equal(c.publico(U1).vipAtivo, true, 'o RTDN nao achou o dono sem a validacao');
  assert.equal(c.publico(U1).estado, ESTADO.ATIVO);
  assert.equal(c.publico(U2), null);
  // E continua sem registro de compra: o RTDN nao inventa um.
  assert.equal(c.compra(HASH_A), null);
});

test('Y8 troca de plano: linkedPurchaseToken coerente mantem o proprietario', async () => {
  // Sem ler `linkedPurchaseToken`, a proposta pararia em `token_superado` — o
  // entitlement guarda o hash do token velho — e a troca so entraria quando
  // alguem abrisse o aplicativo.
  const c = cenarioDeModulo();
  c.semearEntitlement(U1, {
    estado: ESTADO.ATIVO, vipAtivo: true, expiraEm: FUTURO, hash: HASH_A, token: TOKEN_A, verificadoEm: T0,
  });
  c.play.definirAssinatura(TOKEN_B, {
    estado: c.play.ESTADOS.ATIVA,
    expiraEm: FUTURO_LONGE,
    produtoId: PRODUTO_ANUAL,
    contaOfuscada: VINCULO_U1,
    tokenLigado: TOKEN_A,
  });
  c.relogio.fila(T1);

  const r = await c.rtdn.processarNotificacao(
    mensagem(corpoAssinatura(NOTIFICACAO.PURCHASED, { token: TOKEN_B, produtoId: PRODUTO_ANUAL }), 'msg_Y8')
  );

  assert.equal(r.aplicado, true, 'a troca de plano ficou parada em token_superado');
  assert.equal(r.uid, U1);
  assert.equal(c.publico(U1).produtoId, PRODUTO_ANUAL);
  assert.equal(c.publico(U1).expiraEm, FUTURO_LONGE);
  assert.equal(c.interno(U1).purchaseTokenHash, HASH_B, 'o token vigente nao avancou');
});

test('Y9 token ligado com vinculacao DIVERGENTE nao transfere o direito', async () => {
  // A armadilha: o token novo aponta para o entitlement de U1 pelo
  // `linkedPurchaseToken`, mas a Google diz que a compra e de U2. O elo do token
  // NAO pode servir de atalho de propriedade.
  const c = cenarioDeModulo();
  c.semearEntitlement(U1, {
    estado: ESTADO.ATIVO, vipAtivo: true, expiraEm: FUTURO, hash: HASH_A, token: TOKEN_A, verificadoEm: T0,
  });
  c.play.definirAssinatura(TOKEN_B, {
    estado: c.play.ESTADOS.ATIVA,
    expiraEm: FUTURO_LONGE,
    contaOfuscada: VINCULO_U2,
    tokenLigado: TOKEN_A,
  });
  c.db.zerarDiario();
  c.relogio.fila(T1);

  const r = await c.rtdn.processarNotificacao(
    mensagem(corpoAssinatura(NOTIFICACAO.PURCHASED, { token: TOKEN_B }), 'msg_Y9')
  );

  // O direito vai para U2, que e de quem a compra e.
  assert.equal(r.uid, U2);
  assert.equal(c.publico(U2).vipAtivo, true);
  // E o de U1 nao foi tocado, apesar de o token ligado apontar para ele.
  assert.equal(c.publico(U1).vipAtivo, true);
  assert.equal(c.publico(U1).expiraEm, FUTURO);
  assert.equal(c.interno(U1).purchaseTokenHash, HASH_A);
  assert.equal(c.db.escritasEm(publicoDe(U1)), 0, 'o token ligado moveu o direito de dono');
});

test('Y10 vinculo ausente na VALIDACAO falha fechado, sem gravar nada', async () => {
  // A compra antiga chegando pela validacao: a Google confirma a assinatura, e a
  // resposta nao traz identificador porque o aplicativo nunca preparou o vinculo.
  // Secao 9 da OS — nao concede, nao transfere, nao cria associacao definitiva.
  const c = cenarioDeIndex();
  c.play.definirAssinatura(TOKEN_A, {
    estado: c.play.ESTADOS.ATIVA, expiraEm: FUTURO, contaOfuscada: null,
  });
  c.db.zerarDiario();

  await assert.rejects(
    () => c.chamar('validarCompraPlay', {
      uid: U1, dados: { produtoId: PRODUTO, tokenCompra: TOKEN_A, assinatura: true },
    }),
    (e) => e.code === 'permission-denied' && e.details.motivo === 'vinculo_ausente'
  );

  assert.equal(c.publico(U1), null);
  assert.equal(c.compra(HASH_A), null);
  assert.equal(c.db.diario.length, 0, 'a compra sem vinculo escreveu no Firestore');
});

test('Y11 consumivel tambem tem dono: identificador na RAIZ da resposta', async () => {
  // `ProductPurchase` traz `obfuscatedExternalAccountId` na raiz, e nao aninhado
  // como a assinatura. Ler so um dos formatos deixaria o consumivel sem
  // propriedade verificavel — metade do catalogo.
  const c = cenarioDeIndex();
  c.play.definirProduto(TOKEN_B, {
    purchaseState: 0, produtoId: PRODUTO_FICHAS, contaOfuscada: VINCULO_U2,
  });
  c.db.zerarDiario();

  await assert.rejects(
    () => c.chamar('validarCompraPlay', {
      uid: U1, dados: { produtoId: PRODUTO_FICHAS, tokenCompra: TOKEN_B, assinatura: false },
    }),
    (e) => e.code === 'permission-denied' && e.details.motivo === 'vinculo_divergente'
  );

  assert.equal(c.usuario(U1), null, 'creditou fichas de uma compra alheia');
  assert.equal(c.db.diario.length, 0);
});

test('Y12 a reconciliacao administrativa nao troca o dono de um direito', async () => {
  // O token guardado no documento de U1 responde, pela Google, que a compra e de
  // U2 — divergencia que so pode existir por dado anterior a esta correcao. A
  // saida de emergencia da administracao nao pode ser o caminho por onde o
  // direito muda de dono.
  const c = cenarioDeIndex();
  c.db.semear(publicoDe(U1), {
    uid: U1, vipAtivo: true, estado: ESTADO.ATIVO, produtoId: PRODUTO, origem: 'play',
    expiraEm: FUTURO, renovacaoAutomatica: true, atualizadoEm: T0, esquema: 1,
  });
  c.db.semear(internoDe(U1), {
    uid: U1, purchaseTokenHash: HASH_A, purchaseToken: TOKEN_A, produtoId: PRODUTO,
    assinatura: true, fonte: 'rtdn', ultimaVerificacaoEm: T0, esquema: 1,
  });
  c.play.definirAssinatura(TOKEN_A, {
    estado: c.play.ESTADOS.ATIVA, expiraEm: FUTURO_LONGE, contaOfuscada: VINCULO_U2,
  });
  c.db.zerarDiario();

  await assert.rejects(
    () => c.chamar('reconciliarEntitlementDoJogador', { uid: 'op', admin: true, dados: { uid: U1 } }),
    (e) => e.code === 'failed-precondition' && e.details.motivo === 'vinculo_divergente'
  );

  assert.equal(c.publico(U2), null, 'a reconciliacao concedeu a outra conta');
  assert.equal(c.db.escritasEm(publicoDe(U1)), 0);
});

test('Y14 vinculo DESCONHECIDO na validacao falha fechado, mesmo com sessao valida', async () => {
  // A lacuna que a prova negativa N3 revelou. Y10 cobre vinculo AUSENTE e R4
  // cobre vinculo desconhecido SEM sessao; faltava o caso do meio — sessao
  // valida, identificador bem formado, e ninguem dono dele. E o cenario de uma
  // conta apagada e recriada, ou de um identificador de outro ambiente.
  //
  // A tentacao aqui e obvia: ha um usuario autenticado na frente, entao "deve
  // ser dele". E exatamente essa deducao que devolveria o defeito A-1 por outra
  // porta.
  const c = cenarioDeIndex();
  c.play.definirAssinatura(TOKEN_A, {
    estado: c.play.ESTADOS.ATIVA, expiraEm: FUTURO, contaOfuscada: VINCULO_ORFAO,
  });
  c.db.zerarDiario();

  await assert.rejects(
    () => c.chamar('validarCompraPlay', {
      uid: U1, dados: { produtoId: PRODUTO, tokenCompra: TOKEN_A, assinatura: true },
    }),
    (e) => e.code === 'permission-denied' && e.details.motivo === 'vinculo_desconhecido'
  );

  assert.equal(c.publico(U1), null, 'concedeu a quem estava autenticado');
  assert.equal(c.compra(HASH_A), null);
  assert.equal(c.db.diario.length, 0);
});

test('Y15 a sucessao por token ligado e ESTREITA: so o token que a Google declara', async () => {
  // O complemento de Y8. La se prova que a troca de plano entra; aqui, que ela
  // nao vira uma porta larga: um token que a resposta NAO declara como sucessor
  // continua sendo token superado, e nao derruba a assinatura vigente.
  //
  // Sem isso, `linkedPurchaseToken` viraria "qualquer token substitui qualquer
  // entitlement do mesmo dono" — e a expiracao de uma assinatura velha passaria
  // a derrubar a nova.
  const c = cenarioDeModulo();
  c.semearEntitlement(U1, {
    estado: ESTADO.ATIVO, vipAtivo: true, expiraEm: FUTURO_LONGE, hash: HASH_A, token: TOKEN_A, verificadoEm: T0,
  });
  // TOKEN_B e do mesmo dono, e a resposta NAO declara token ligado nenhum.
  c.play.definirAssinatura(TOKEN_B, {
    estado: c.play.ESTADOS.EXPIRADA, expiraEm: PASSADO, contaOfuscada: VINCULO_U1,
  });
  c.db.zerarDiario();
  c.relogio.fila(T1);

  const r = await c.rtdn.processarNotificacao(
    mensagem(corpoAssinatura(NOTIFICACAO.EXPIRED, { token: TOKEN_B }), 'msg_Y15')
  );

  assert.equal(r.aplicado, false, 'um token nao declarado como sucessor passou');
  assert.equal(r.decisao, 'token_superado');
  assert.equal(c.publico(U1).vipAtivo, true, 'a assinatura vigente foi derrubada');
  assert.equal(c.publico(U1).expiraEm, FUTURO_LONGE);
  assert.equal(c.interno(U1).purchaseTokenHash, HASH_A);
  assert.equal(c.db.escritasEm(publicoDe(U1)), 0);
});

test('Y13 registro de compra com dono divergente do vinculo nao concede', async () => {
  // DEFESA EM PROFUNDIDADE. Este estado nao pode nascer do codigo corrigido: o
  // `compras/{hash}` so e escrito depois de a propriedade bater. Ele PODE ter
  // sobrado de antes da correcao, quando o registro nascia com o uid de quem
  // chamasse primeiro. `conferirTitularidade` continua na transacao final
  // exatamente para esse caso.
  const c = cenarioDeIndex();
  c.play.definirAssinatura(TOKEN_A, {
    estado: c.play.ESTADOS.ATIVA, expiraEm: FUTURO, contaOfuscada: VINCULO_U1,
  });
  // Residuo do regime antigo: o invasor gravou o registro em nome dele.
  c.db.semear(compraDe(HASH_A), {
    uid: U2, produtoId: PRODUTO, assinatura: true, estado: 'em_validacao',
  });
  c.db.zerarDiario();

  // U1 e o dono comprovado pela Google, e mesmo assim a transacao final recusa:
  // o registro descreve outra compra, e sobrescreve-lo apagaria a evidencia.
  await assert.rejects(
    () => c.chamar('validarCompraPlay', {
      uid: U1, dados: { produtoId: PRODUTO, tokenCompra: TOKEN_A, assinatura: true },
    }),
    (e) => e.code === 'permission-denied'
  );
  assert.equal(c.compra(HASH_A).uid, U2, 'o registro residual foi sobrescrito');
});

test('Z1 mensagem de erro de terceiro nao chega ao Firestore nem ao cliente', async () => {
  // O achado M-2. `index.js` gravava `e.message` da googleapis em
  // `compras/{hash}` — documento que o dono le — e o imprimia em log. A garantia
  // de que nao havia token ali era circunstancial: dependia do que uma
  // dependencia de terceiro resolvia colocar num campo livre.
  //
  // A agulha abaixo e o que uma mensagem de terceiro poderia carregar no pior
  // caso. Ela nao pode aparecer em lugar nenhum.
  const AGULHA = 'SEGREDO-DE-TERCEIRO-QUE-NAO-PODE-VAZAR';
  const c = cenarioDeIndex();
  c.play.definirFalha(TOKEN_A, new FalhaTransitoriaPlay(`503 ${AGULHA}`));

  let capturado = null;
  await c.chamar('validarCompraPlay', {
    uid: U1, dados: { produtoId: PRODUTO, tokenCompra: TOKEN_A, assinatura: true },
  }).catch((e) => { capturado = e; });

  assert.ok(capturado, 'a falha da Play devia ter recusado a chamada');
  // Nem na mensagem, nem nos detalhes que voltam ao cliente.
  assert.ok(!JSON.stringify(capturado.message).includes(AGULHA), 'vazou na mensagem');
  assert.ok(!JSON.stringify(capturado.details || {}).includes(AGULHA), 'vazou nos detalhes');
  assert.equal(capturado.details.motivo, 'falha_temporaria_play');
  // Nem em documento nenhum.
  const tudo = JSON.stringify(c.db.caminhos().map((p) => c.db.ver(p)));
  assert.ok(!tudo.includes(AGULHA), 'a mensagem de terceiro foi persistida');

  // Mesmo teste para o fechamento junto a Google, que falha DEPOIS do credito.
  const d = cenarioDeIndex();
  d.play.definirAssinatura(TOKEN_A, { estado: d.play.ESTADOS.ATIVA, expiraEm: FUTURO });
  d.play.definirFalhaDeFechamento(new FalhaTransitoriaPlay(`acknowledge ${AGULHA}`));
  const r = await d.chamar('validarCompraPlay', {
    uid: U1, dados: { produtoId: PRODUTO, tokenCompra: TOKEN_A, assinatura: true },
  });
  assert.equal(r.aprovada, true);
  const tudoD = JSON.stringify(d.db.caminhos().map((p) => d.db.ver(p)));
  assert.ok(!tudoD.includes(AGULHA), 'o aviso de fechamento persistiu texto de terceiro');
  assert.equal(d.compra(HASH_A).avisoFechamento, 'falha_temporaria_play');
});

// ===========================================================================
// S — redacao de segredo
// ===========================================================================

test('S o purchaseToken nao alcanca log, trilha nem documento que o cliente le', async () => {
  const c = cenarioDeModulo();
  c.play.definirAssinatura(TOKEN_A, { estado: c.play.ESTADOS.ATIVA, expiraEm: FUTURO });
  // Token orfao: bem formado, sem dono. Passa pela consulta e para na propriedade.
  c.play.definirAssinatura(TOKEN_C, {
    estado: c.play.ESTADOS.ATIVA, expiraEm: FUTURO, contaOfuscada: VINCULO_ORFAO,
  });
  c.relogio.fila(T1, T2, T3, T4);

  await c.rtdn.processarNotificacao(mensagem(corpoAssinatura(NOTIFICACAO.RENEWED, { token: TOKEN_A }), 's1'));
  await c.rtdn.processarNotificacao(mensagem(corpoAnulacao({ token: TOKEN_A }), 's2'));
  await c.rtdn.processarNotificacao(mensagem(corpoAssinatura(NOTIFICACAO.RENEWED, { token: TOKEN_C }), 's3'));
  await c.rtdn.processarNotificacao(mensagemCrua('nao-e-base64-valido!!', 's4'));

  assertSemSegredo(c.textoDosLogs());

  // O documento que o dono le nao tem nem token nem hash.
  const pub = c.publico(U1);
  assert.equal(pub.purchaseToken, undefined);
  assert.equal(pub.purchaseTokenHash, undefined);
  assertSemSegredo(JSON.stringify(pub));

  // A trilha guarda rotulo de oito caracteres, nunca o hash inteiro.
  for (const id of ['s1', 's2', 's3', 's4']) {
    const ev = c.evento(id);
    if (!ev) continue;
    assertSemSegredo(JSON.stringify(ev));
    if (ev.token) assert.equal(ev.token.length, 8);
  }

  // O token cru existe SO no documento interno, que as regras fecham para todos.
  assert.equal(c.interno(U1).purchaseToken, TOKEN_A);
});

test('S2 nenhuma resposta de callable devolve token ao cliente', async () => {
  const c = cenarioDeIndex();
  c.play.definirAssinatura(TOKEN_A, { estado: c.play.ESTADOS.ATIVA, expiraEm: FUTURO });

  const r = await c.chamar('validarCompraPlay', {
    uid: U1, dados: { produtoId: PRODUTO, tokenCompra: TOKEN_A, assinatura: true },
  });
  assertSemSegredo(JSON.stringify(r));

  const adm = await c.chamar('reconciliarEntitlementDoJogador', {
    uid: 'operador', admin: true, dados: { uid: U1 },
  });
  assertSemSegredo(JSON.stringify(adm));

  // E o documento que o dono le continua sem segredo depois de tudo.
  assertSemSegredo(JSON.stringify(c.publico(U1)));
});

test('S3 o segredo da conta de servico nao aparece em resposta nem em documento', async () => {
  const c = cenarioDeIndex();
  c.play.definirAssinatura(TOKEN_A, { estado: c.play.ESTADOS.ATIVA, expiraEm: FUTURO });
  await c.chamar('validarCompraPlay', {
    uid: U1, dados: { produtoId: PRODUTO, tokenCompra: TOKEN_A, assinatura: true },
  });

  const tudo = JSON.stringify(c.db.caminhos().map((p) => c.db.ver(p)));
  for (const agulha of ['private_key', 'service_account', 'ISTO-NAO-E-UMA-CHAVE-PRIVADA', 'exemplo.invalid']) {
    assert.ok(!tudo.includes(agulha), `credencial vazou para o Firestore: ${agulha}`);
  }
});

// ===========================================================================
// T — reconciliacao idempotente
// ===========================================================================

test('T rodar a reconciliacao administrativa de novo nao muda o estado', async () => {
  const c = cenarioDeIndex();
  c.play.definirAssinatura(TOKEN_A, { estado: c.play.ESTADOS.ATIVA, expiraEm: FUTURO });
  await c.chamar('validarCompraPlay', {
    uid: U1, dados: { produtoId: PRODUTO, tokenCompra: TOKEN_A, assinatura: true },
  });
  const antes = JSON.stringify(c.publico(U1));

  const r1 = await c.chamar('reconciliarEntitlementDoJogador', { uid: 'op', admin: true, dados: { uid: U1 } });
  const r2 = await c.chamar('reconciliarEntitlementDoJogador', { uid: 'op', admin: true, dados: { uid: U1 } });
  const r3 = await c.chamar('reconciliarEntitlementDoJogador', { uid: 'op', admin: true, dados: { uid: U1 } });

  for (const r of [r1, r2, r3]) {
    assert.equal(r.estado, ESTADO.ATIVO);
    assert.equal(r.vipAtivo, true);
  }
  // O estado economico e o mesmo do inicio: nada foi somado nem esticado.
  const depois = JSON.parse(JSON.stringify(c.publico(U1)));
  const antesObj = JSON.parse(antes);
  for (const campo of ['vipAtivo', 'estado', 'produtoId', 'expiraEm', 'inicioEm', 'origem', 'esquema']) {
    assert.deepEqual(depois[campo], antesObj[campo], `campo ${campo} mudou por reconciliacao repetida`);
  }
});

test('T2 a varredura por relogio rodada tres vezes fecha uma vez e para', async () => {
  const c = cenarioDeIndex();
  c.db.semear(publicoDe(U1), {
    uid: U1, vipAtivo: true, estado: ESTADO.ATIVO, produtoId: PRODUTO, origem: 'play',
    inicioEm: PASSADO, expiraEm: PASSADO, renovacaoAutomatica: true, atualizadoEm: PASSADO, esquema: 1,
  });
  c.db.semear(internoDe(U1), {
    uid: U1, purchaseTokenHash: HASH_A, purchaseToken: TOKEN_A, produtoId: PRODUTO,
    assinatura: true, fonte: 'rtdn', ultimaVerificacaoEm: PASSADO, esquema: 1,
  });
  c.db.zerarDiario();

  await c.modulo.reconciliarEntitlements.run({});
  const escritasApos1 = c.db.escritasEm(publicoDe(U1));
  await c.modulo.reconciliarEntitlements.run({});
  await c.modulo.reconciliarEntitlements.run({});

  assert.equal(escritasApos1, 1);
  assert.equal(c.db.escritasEm(publicoDe(U1)), 1, 'a varredura reescreveu um documento ja fechado');
  assert.equal(c.publico(U1).vipAtivo, false);
});

test('T3 a migracao do legado e idempotente e nunca sobrescreve estado ja verificado', async () => {
  const c = cenarioDeIndex();
  c.db.semear(`usuarios/${U1}`, { vip: true, vipExpiraEm: FUTURO, vipProdutoId: PRODUTO });
  c.db.semear(`usuarios/${U2}`, { vip: true, vipExpiraEm: null });

  const p1 = await c.chamar('migrarEntitlementsLegado', { uid: 'op', admin: true, dados: { lote: 50 } });
  assert.equal(p1.migrados, 1);
  assert.equal(p1.semPrazo, 1, 'migrou alguem sem prazo conhecido');
  assert.equal(c.publico(U1).origem, 'legado_usuarios');
  assert.equal(c.publico(U2), null);
  c.db.zerarDiario();

  const p2 = await c.chamar('migrarEntitlementsLegado', { uid: 'op', admin: true, dados: { lote: 50 } });
  assert.equal(p2.migrados, 0);
  assert.equal(p2.jaTinham, 1);
  assert.equal(c.db.escritasEm(publicoDe(U1)), 0, 'a migracao regravou um documento existente');
});

test('T4 a migracao do legado NAO sobrescreve um entitlement ja confirmado pela Google', async () => {
  const c = cenarioDeIndex();
  c.play.definirAssinatura(TOKEN_A, { estado: c.play.ESTADOS.ATIVA, expiraEm: FUTURO_LONGE });
  await c.chamar('validarCompraPlay', {
    uid: U1, dados: { produtoId: PRODUTO, tokenCompra: TOKEN_A, assinatura: true },
  });
  // O legado diz um prazo mais curto e um produto diferente.
  c.db.semear(`usuarios/${U1}`, { vip: true, vipExpiraEm: FUTURO, vipProdutoId: PRODUTO_ANUAL });
  c.db.zerarDiario();

  await c.chamar('migrarEntitlementsLegado', { uid: 'op', admin: true, dados: { lote: 50 } });

  assert.equal(c.publico(U1).expiraEm, FUTURO_LONGE, 'lembranca do legado venceu o fato da Google');
  assert.equal(c.publico(U1).origem, 'play');
  assert.equal(c.db.escritasEm(publicoDe(U1)), 0);
});

test('T5 as duas funcoes administrativas recusam quem nao e admin', async () => {
  const c = cenarioDeIndex();
  for (const nome of ['reconciliarEntitlementDoJogador', 'migrarEntitlementsLegado']) {
    await assert.rejects(
      () => c.chamar(nome, { uid: U1, admin: false, dados: { uid: U1 } }),
      (e) => e.code === 'permission-denied',
      `${nome} aceitou chamada sem privilegio`
    );
    await assert.rejects(
      () => c.chamar(nome, { uid: null, dados: { uid: U1 } }),
      (e) => e.code === 'permission-denied',
      `${nome} aceitou chamada anonima`
    );
  }
});

// ===========================================================================
// U — reconciliacao concorrente com RTDN
// ===========================================================================

test('U RTDN e reconciliacao em ordens opostas convergem para o mesmo estado', async () => {
  /** Roda os dois caminhos numa ordem dada e devolve o estado final. */
  async function rodar(ordem) {
    const c = cenarioDeModulo();
    c.registrarCompra(HASH_A, { uid: U1 });

    const passos = {
      // RTDN de expiracao, consultado em T1 (mais VELHO).
      rtdn: async () => {
        c.play.definirAssinatura(TOKEN_A, { estado: c.play.ESTADOS.EXPIRADA, expiraEm: PASSADO });
        c.relogio.fila(T1);
        return c.rtdn.processarNotificacao(
          mensagem(corpoAssinatura(NOTIFICACAO.EXPIRED, { token: TOKEN_A }), 'msg_U_rtdn')
        );
      },
      // Reconciliacao administrativa, consultada em T2 (mais NOVA).
      reconciliacao: async () => {
        c.play.definirAssinatura(TOKEN_A, { estado: c.play.ESTADOS.ATIVA, expiraEm: FUTURO_LONGE });
        c.relogio.fila(T2);
        return c.reconciliador.reconsultarEAplicar({
          uid: U1, produtoId: PRODUTO, tokenCompra: TOKEN_A, fonte: 'reconciliacao',
        });
      },
    };

    for (const passo of ordem) await passos[passo]();
    return { estado: c.publico(U1).estado, vipAtivo: c.publico(U1).vipAtivo, verificado: c.interno(U1).ultimaVerificacaoEm };
  }

  const primeiroRtdn = await rodar(['rtdn', 'reconciliacao']);
  const primeiroRecon = await rodar(['reconciliacao', 'rtdn']);

  assert.deepEqual(primeiroRtdn, primeiroRecon, 'a ordem de chegada mudou o estado final');
  // Vence quem consultou a Google por ultimo (T2), em ambas as ordens.
  assert.equal(primeiroRtdn.verificado, T2);
  assert.equal(primeiroRtdn.vipAtivo, true);
  assert.equal(primeiroRtdn.estado, ESTADO.ATIVO);
});

test('U2 reconciliacao concorrendo com RTDN sobre o mesmo documento nao perde a mais nova', async () => {
  const c = cenarioDeModulo();
  c.registrarCompra(HASH_A, { uid: U1 });
  c.db.zerarDiario();

  let segurar = true;
  let liberar;
  const porta = new Promise((r) => { liberar = r; });
  c.db.pausarAntesDoCommit = async () => {
    if (segurar) { segurar = false; await porta; }
  };

  // As duas propostas ja consolidadas, para que a corrida seja so a da transacao.
  const antiga = c.store.aplicarProposta({
    uid: U1, estado: ESTADO.EXPIRADO, vipAtivo: false, produtoId: PRODUTO,
    inicioEm: PASSADO, expiraEm: PASSADO, renovacaoAutomatica: false, origem: 'play',
    purchaseTokenHash: HASH_A, purchaseToken: TOKEN_A, verificadoEm: T1, fonte: 'rtdn',
  }, { id: 'msg_U2_rtdn' });

  const nova = c.store.aplicarProposta({
    uid: U1, estado: ESTADO.ATIVO, vipAtivo: true, produtoId: PRODUTO,
    inicioEm: PASSADO, expiraEm: FUTURO_LONGE, renovacaoAutomatica: true, origem: 'play',
    purchaseTokenHash: HASH_A, purchaseToken: TOKEN_A, verificadoEm: T2, fonte: 'reconciliacao',
  });

  liberar();
  await Promise.all([antiga, nova]);

  assert.equal(c.publico(U1).vipAtivo, true, 'a consulta mais velha venceu a mais nova');
  assert.equal(c.interno(U1).ultimaVerificacaoEm, T2);
  assert.ok(c.db.conflitos >= 1, 'nao houve contencao: a corrida nao aconteceu');
});

// ===========================================================================
// V — usuario ou documento ausente
// ===========================================================================

test('V compra sem vinculo nenhum nao autoriza identidade ficticia nem usuario generico', async () => {
  // A COMPRA ANTIGA, encenada: a Google responde, a assinatura e real, e a
  // resposta nao traz identificador de conta porque o aplicativo nao preparou o
  // vinculo. E o caso da secao 9 da OS — nao se concede, nao se transfere
  // propriedade, e acima de tudo nao se escolhe o primeiro solicitante.
  const c = cenarioDeModulo({ vincular: false });
  c.play.definirAssinatura(TOKEN_A, {
    estado: c.play.ESTADOS.ATIVA, expiraEm: FUTURO, contaOfuscada: null,
  });
  c.relogio.fila(T1);

  const r = await c.rtdn.processarNotificacao(
    mensagem(corpoAssinatura(NOTIFICACAO.PURCHASED, { token: TOKEN_A }), 'msg_V1')
  );

  assert.equal(r.decisao, 'vinculo_ausente');
  assert.equal(r.aplicado, false);
  assert.equal(r.uid, undefined, 'inventou um titular');
  assert.deepEqual(c.db.caminhos().filter((p) => p.startsWith('playerEntitlements/')), []);
  assert.deepEqual(c.db.caminhos().filter((p) => p.startsWith('usuarios/')), []);
  // A trilha guarda o codigo fechado, para que a operacao consiga separar
  // "assinante antigo" de "tentativa de tomar compra alheia".
  assert.equal(c.evento('msg_V1').decisao, 'vinculo_ausente');
});

test('V2 indice de vinculo sem uid nao produz direito para ninguem', async () => {
  // Meia relacao: o indice existe, mas nao aponta para conta nenhuma. A producao
  // nao consegue criar isto (as duas pontas nascem na mesma transacao), e por
  // isso mesmo o codigo tem de recusar em vez de deduzir.
  const c = cenarioDeModulo({ vincular: false });
  c.db.semear(`billingAccountIndex/${VINCULO_U1}`, { contaOfuscada: VINCULO_U1 });
  c.play.definirAssinatura(TOKEN_A, { estado: c.play.ESTADOS.ATIVA, expiraEm: FUTURO });
  c.relogio.fila(T1);

  const r = await c.rtdn.processarNotificacao(
    mensagem(corpoAssinatura(NOTIFICACAO.RENEWED, { token: TOKEN_A }), 'msg_V2')
  );

  assert.equal(r.decisao, 'vinculo_desconhecido');
  assert.deepEqual(c.db.caminhos().filter((p) => p.startsWith('playerEntitlements/')), []);
});

test('V3 reconciliacao de jogador sem token guardado falha explicitamente, sem inventar', async () => {
  const c = cenarioDeIndex();

  await assert.rejects(
    () => c.chamar('reconciliarEntitlementDoJogador', { uid: 'op', admin: true, dados: { uid: 'ninguem' } }),
    (e) => e.code === 'failed-precondition'
  );
  assert.equal(c.publico('ninguem'), null);
  assert.equal(c.play.total(), 0);
});

test('V4 a validacao cria o direito do usuario AUTENTICADO, e nao de um uid do payload', async () => {
  const c = cenarioDeIndex();
  c.play.definirAssinatura(TOKEN_A, { estado: c.play.ESTADOS.ATIVA, expiraEm: FUTURO });

  await c.chamar('validarCompraPlay', {
    uid: U1,
    // O payload tenta ditar o dono. O callable ignora: uid vem do token do Auth.
    dados: { produtoId: PRODUTO, tokenCompra: TOKEN_A, assinatura: true, uid: U2 },
  });

  assert.equal(c.publico(U1).vipAtivo, true);
  assert.equal(c.publico(U2), null, 'o payload escolheu o beneficiario');
  assert.equal(c.compra(HASH_A).uid, U1);
});

// ===========================================================================
// W — falha parcial e atomicidade
// ===========================================================================

test('W falha no meio da consolidacao nao deixa entitlement, evento e compra em desacordo', async () => {
  const c = cenarioDeModulo();
  c.registrarCompra(HASH_A, { uid: U1 });
  c.play.definirAssinatura(TOKEN_A, { estado: c.play.ESTADOS.ATIVA, expiraEm: FUTURO });
  c.db.zerarDiario();
  c.relogio.fila(T1, T2);

  // A transacao roda inteira e falha no commit.
  c.db.falhaNoCommit = () => new Error('commit rejeitado pelo servidor');

  await assert.rejects(
    () => c.rtdn.processarNotificacao(
      mensagem(corpoAssinatura(NOTIFICACAO.PURCHASED, { token: TOKEN_A }), 'msg_W')
    )
  );

  // NADA foi gravado: nem o direito, nem a trilha. Meio-caminho nao existe.
  assert.equal(c.db.escritasEm(publicoDe(U1)), 0);
  assert.equal(c.db.escritasEm(internoDe(U1)), 0);
  assert.equal(c.db.escritasEm(eventoDe('msg_W')), 0);
  assert.equal(c.publico(U1), null);
  assert.equal(c.evento('msg_W'), null);

  // A reentrega converge, e o efeito acontece uma vez so.
  c.db.falhaNoCommit = null;
  const r = await c.rtdn.processarNotificacao(
    mensagem(corpoAssinatura(NOTIFICACAO.PURCHASED, { token: TOKEN_A }), 'msg_W')
  );
  assert.equal(r.aplicado, true);
  assert.equal(c.publico(U1).vipAtivo, true);
  assert.equal(c.db.escritasEm(publicoDe(U1)), 1);
  assert.equal(c.db.escritasEm(eventoDe('msg_W')), 1);
});

test('W2 o efeito e a marca de "ja processei" nascem juntos ou nao nascem', async () => {
  const c = cenarioDeModulo();
  c.registrarCompra(HASH_A, { uid: U1 });
  c.play.definirAssinatura(TOKEN_A, { estado: c.play.ESTADOS.ATIVA, expiraEm: FUTURO });
  c.relogio.fila(T1, T2);

  // Falha so na primeira tentativa de commit.
  let primeira = true;
  c.db.falhaNoCommit = () => {
    if (!primeira) return null;
    primeira = false;
    return new Error('queda no commit');
  };

  await assert.rejects(() => c.rtdn.processarNotificacao(
    mensagem(corpoAssinatura(NOTIFICACAO.PURCHASED, { token: TOKEN_A }), 'msg_W2')
  ));

  // O documento de evento NAO existe: se existisse, a reentrega teria desistido
  // de um trabalho que nunca aconteceu.
  assert.equal(c.evento('msg_W2'), null);

  const r = await c.rtdn.processarNotificacao(
    mensagem(corpoAssinatura(NOTIFICACAO.PURCHASED, { token: TOKEN_A }), 'msg_W2')
  );
  assert.equal(r.aplicado, true);
  assert.equal(c.evento('msg_W2').aplicado, true);
  assert.equal(c.publico(U1).vipAtivo, true);
});

test('W3 falha depois de consolidar o entitlement nao deixa o registro da compra mentindo', async () => {
  const c = cenarioDeIndex();
  c.play.definirAssinatura(TOKEN_A, { estado: c.play.ESTADOS.ATIVA, expiraEm: FUTURO });
  // O fechamento junto a Google falha: o jogador ja recebeu, e isso e tolerado.
  c.play.definirFalhaDeFechamento(new FalhaTransitoriaPlay('acknowledge indisponivel'));

  const r = await c.chamar('validarCompraPlay', {
    uid: U1, dados: { produtoId: PRODUTO, tokenCompra: TOKEN_A, assinatura: true },
  });

  assert.equal(r.aprovada, true, 'a falha de fechamento derrubou uma compra ja creditada');
  assert.equal(c.publico(U1).vipAtivo, true);
  assert.equal(c.compra(HASH_A).estado, 'concedida');
  // A falha fica registrada para diagnostico, sem contradizer a concessao.
  assert.ok(c.compra(HASH_A).avisoFechamento);
});

// ===========================================================================
// Fronteira do dominio e superficie de implantacao
// ===========================================================================

test('X1 o Billing nao escreve fora do proprio dominio em nenhum caminho exercitado', async () => {
  const c = cenarioDeIndex();
  c.play.definirAssinatura(TOKEN_A, { estado: c.play.ESTADOS.ATIVA, expiraEm: FUTURO });
  c.play.definirProduto(TOKEN_B, { purchaseState: 0, produtoId: PRODUTO_FICHAS });

  await c.chamar('validarCompraPlay', { uid: U1, dados: { produtoId: PRODUTO, tokenCompra: TOKEN_A, assinatura: true } });
  await c.chamar('validarCompraPlay', { uid: U1, dados: { produtoId: PRODUTO_FICHAS, tokenCompra: TOKEN_B, assinatura: false } });
  await c.entregar(corpoAssinatura(NOTIFICACAO.RENEWED, { token: TOKEN_A }), 'msg_X1');
  await c.modulo.reconciliarEntitlements.run({});

  assertSoEscreveuNoDominio(c.db);
  // Em particular: nada de moderacao, torneio, ranking ou partida.
  // A vinculacao entrou no dominio do billing nesta correcao.
  assert.ok(c.db.caminhos().some((p) => p.startsWith('playerBillingIdentity/')));
  for (const proibido of ['playerModeration/', 'tournaments/', 'rankingLedger/', 'matches/', 'reports/']) {
    assert.ok(!c.db.caminhos().some((p) => p.startsWith(proibido)), `escreveu em ${proibido}`);
  }
});

test('X2 a superficie exportada e exatamente as cinco funcoes declaradas', () => {
  const c = cenarioDeIndex();
  assert.deepEqual(Object.keys(c.modulo).sort(), [
    'migrarEntitlementsLegado',
    'notificacoesPlay',
    'prepararCompraPlay',
    'reconciliarEntitlementDoJogador',
    'reconciliarEntitlements',
    'validarCompraPlay',
  ]);

  // Regiao, plataforma e retry sao contrato de implantacao, e esta OS nao pode
  // altera-los: se um deles mudar nesta branch, o teste denuncia.
  for (const nome of Object.keys(c.modulo)) {
    const ep = c.modulo[nome].__endpoint;
    assert.deepEqual(ep.region, ['us-central1'], `${nome} mudou de regiao`);
    assert.equal(ep.platform, 'gcfv2', `${nome} mudou de plataforma`);
  }
  const rtdn = c.modulo.notificacoesPlay.__endpoint.eventTrigger;
  assert.equal(rtdn.eventFilters.topic, 'play-billing-rtdn');
  assert.equal(rtdn.retry, true, 'sem retry, a falha transitoria vira evento perdido');
  assert.equal(c.modulo.reconciliarEntitlements.__endpoint.scheduleTrigger.schedule, 'every 30 minutes');

  // O segredo da Play so e pedido por quem fala com a Play.
  const comSegredo = Object.keys(c.modulo).filter((n) =>
    (c.modulo[n].__endpoint.secretEnvironmentVariables || []).length > 0);
  assert.deepEqual(comSegredo.sort(), [
    'notificacoesPlay',
    'reconciliarEntitlementDoJogador',
    'validarCompraPlay',
  ]);
  // `prepararCompraPlay` NAO pede o segredo da Play, e a ausencia e o ponto:
  // preparar uma compra nao fala com a Google. Uma funcao que so gera um
  // identificador nao precisa de credencial para faze-lo.
  assert.deepEqual(
    c.modulo.prepararCompraPlay.__endpoint.secretEnvironmentVariables || [],
    []
  );
});

test('X3 a origem da notificacao: so o pacote oficial passa', () => {
  const alheio = interpretarNotificacao(
    { packageName: 'com.outro.app', subscriptionNotification: { notificationType: 2, purchaseToken: TOKEN_A } },
    PACOTE
  );
  assert.equal(alheio.acao, 'ignorar');
  assert.equal(alheio.motivo, 'pacote_divergente');

  // INVERTIDO: era o achado M-3. A condicao antiga (`corpo.packageName && ...`)
  // recusava pacote alheio e deixava passar pacote AUSENTE — ou seja, a unica
  // conferencia de origem ficava desligada justamente para a mensagem que nao
  // declara de onde veio. Hoje ausencia e recusa.
  const semPacote = interpretarNotificacao(
    { subscriptionNotification: { notificationType: 2, purchaseToken: TOKEN_A } },
    PACOTE
  );
  assert.equal(semPacote.acao, 'ignorar');
  assert.equal(semPacote.motivo, 'pacote_divergente');

  // E sem applicationId CONFIGURADO nada e processado: configuracao faltando nao
  // pode virar uma conferencia a menos.
  const semConfiguracao = interpretarNotificacao(
    { packageName: PACOTE, subscriptionNotification: { notificationType: 2, purchaseToken: TOKEN_A } },
    ''
  );
  assert.equal(semConfiguracao.acao, 'ignorar');
  assert.equal(semConfiguracao.motivo, 'pacote_divergente');

  // O pacote oficial, esse, passa.
  const oficial = interpretarNotificacao(
    { packageName: PACOTE, subscriptionNotification: { notificationType: 2, purchaseToken: TOKEN_A } },
    PACOTE
  );
  assert.equal(oficial.acao, 'reconciliar');

  // Notificacao de teste da Play Console: registrada e ignorada.
  const teste = interpretarNotificacao({ packageName: PACOTE, testNotification: { version: '1.0' } }, PACOTE);
  assert.equal(teste.acao, 'ignorar');
  assert.equal(teste.motivo, 'notificacao_de_teste');

  // Tipo de notificacao que nao existe: reconcilia (pergunta a Google) em vez de
  // decidir pelo payload — que e o fail-closed correto para este dominio.
  const desconhecido = interpretarNotificacao(
    { packageName: PACOTE, subscriptionNotification: { notificationType: 9999, purchaseToken: TOKEN_A } },
    PACOTE
  );
  assert.equal(desconhecido.acao, 'reconciliar');

  // OBSERVACAO REGISTRADA: `notificationType` nao numerico vira NaN e escapa do
  // ramo terminal, caindo tambem em `reconciliar`. Para REVOKED isso e uma
  // degradacao — o fato terminal viraria consulta de estado, e a consulta nao
  // expressa revogacao. Nao e defeito explorável: o tipo e numerico por contrato
  // da Google, e quem publica no topico e so a Google. Fica anotado porque a
  // degradacao e SILENCIOSA, e nao porque seja alcancavel.
  const tipoTorto = interpretarNotificacao(
    { packageName: PACOTE, subscriptionNotification: { notificationType: 'REVOKED', purchaseToken: TOKEN_A } },
    PACOTE
  );
  assert.equal(tipoTorto.acao, 'reconciliar');
  assert.ok(Number.isNaN(tipoTorto.tipo));
});

test('X4 a suite inteira rodou sem tocar na rede, e as portas sao mesmo as falsas', () => {
  // A armadilha esta armada desde a carga deste arquivo. Zero aqui significa que
  // nenhum dos 64 testes acima abriu socket, resolveu nome ou fez requisicao.
  assert.deepEqual(
    rede.tentativas,
    [],
    `a suite tentou usar a rede: ${JSON.stringify(rede.tentativas)}`
  );

  // E as portas que `index.js` enxerga sao as plantadas, e nao as reais.
  const { google } = require('googleapis');
  assert.equal(google.auth.GoogleAuth.name, 'GoogleAuthFalso');
  const admin = require('firebase-admin/firestore');
  assert.equal(typeof admin.getFirestore, 'function');
  assert.ok(
    !Object.prototype.hasOwnProperty.call(admin, 'Timestamp'),
    'firebase-admin/firestore real foi carregado: a troca de portas nao valeu'
  );

  // `firebase-functions` continua sendo o pacote REAL — e ele que define o
  // formato dos gatilhos que X2 confere. Trocar isso por imitacao faria a
  // homologacao provar o proprio duble.
  assert.equal(
    typeof require('firebase-functions/v2/https').onCall,
    'function'
  );
});
