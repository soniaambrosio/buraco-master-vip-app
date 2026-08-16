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
const DOMINIO = ['playerEntitlements/', 'billingEvents/', 'compras/', 'usuarios/', 'configuracao/'];

function assertSoEscreveuNoDominio(db) {
  for (const caminho of db.caminhos()) {
    assert.ok(
      DOMINIO.some((p) => caminho.startsWith(p)),
      `escrita fora do dominio do Billing: ${caminho}`
    );
  }
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
  c.registrarCompra(HASH_A, { uid: U1 });
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
  // Terminal nao consulta a Google: o fato esta no payload.
  assert.equal(c.play.total(TOKEN_A), 0);
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
  c.registrarCompra(HASH_A, { uid: U1, produtoId: PRODUTO });
  c.registrarCompra(HASH_B, { uid: U2, produtoId: PRODUTO_ANUAL });
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
  assert.equal(c.play.total(), 0, 'terminal nao precisa consultar a Google');
});

test('K2 reembolso e terminal mesmo com prazo futuro gravado, e nao volta atras', async () => {
  const c = cenarioDeModulo();
  c.registrarCompra(HASH_A, { uid: U1 });
  c.semearEntitlement(U1, {
    estado: ESTADO.ATIVO, vipAtivo: true, expiraEm: FUTURO_LONGE, hash: HASH_A, token: TOKEN_A, verificadoEm: T0,
  });
  c.relogio.fila(T1, T2);

  await c.rtdn.processarNotificacao(mensagem(corpoAnulacao({ token: TOKEN_A }), 'msg_K2'));
  assert.equal(c.publico(U1).estado, ESTADO.REEMBOLSADO);

  // Uma leitura atrasada que ainda diz ACTIVE nao ressuscita um estorno.
  c.play.definirAssinatura(TOKEN_A, { estado: c.play.ESTADOS.ATIVA, expiraEm: FUTURO_LONGE });
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

test('M sem productId no evento, o produto sai do registro de compra — nunca inventado', async () => {
  const c = cenarioDeModulo();
  c.registrarCompra(HASH_A, { uid: U1, produtoId: PRODUTO_ANUAL });
  // A Play tambem nao devolve productId no item: sobra so o registro local.
  c.play.definirCorpoBruto(TOKEN_A, {
    subscriptionState: c.play.ESTADOS.ATIVA,
    startTime: PASSADO,
    lineItems: [{ expiryTime: FUTURO, autoRenewingPlan: { autoRenewEnabled: true } }],
  });
  c.relogio.fila(T1);

  const r = await c.rtdn.processarNotificacao(
    mensagem(corpoAssinatura(NOTIFICACAO.RENEWED, { token: TOKEN_A, produtoId: null }), 'msg_M1')
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

test('N4 notificacao sobre token que nao e de assinatura nao produz entitlement', async () => {
  const c = cenarioDeModulo();
  c.registrarCompra(HASH_A, { uid: U1, assinatura: false });
  c.relogio.fila(T1);

  const r = await c.rtdn.processarNotificacao(
    mensagem(corpoAssinatura(NOTIFICACAO.RENEWED, { token: TOKEN_A }), 'msg_N4')
  );

  assert.equal(r.decisao, 'nao_e_assinatura');
  assert.equal(r.aplicado, false);
  assert.equal(c.publico(U1), null);
  assert.equal(c.play.total(), 0);
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
    c.registrarCompra(HASH_A, { uid: U1 });
    c.play.definirAssinatura(TOKEN_A, { estado: c.play.ESTADOS.ATIVA, expiraEm });
    c.relogio.fila(T1);

    await c.rtdn.processarNotificacao(
      mensagem(corpoAssinatura(NOTIFICACAO.RENEWED, { token: TOKEN_A }), 'msg_O')
    );

    assert.equal(c.publico(U1).vipAtivo, false, `${rotulo}: concedeu VIP`);
    assert.equal(c.publico(U1).estado, ESTADO.EXPIRADO, `${rotulo}: estado errado`);
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
    assert.equal(c.publico(U1).vipAtivo, false, `lineItems=${JSON.stringify(itens)} concedeu`);
  }
});

test('O2b DEFEITO REGISTRADO elemento nulo em lineItems derruba a consolidacao', async () => {
  // ACHADO M-1 do laudo. `consolidarAssinatura` protege o item dentro do laco
  // (`item && item.expiryTime`, entitlement.js:172) e NAO protege o mesmo item
  // fora dele (`itens[0].productId`, entitlement.js:181). Um elemento nulo em
  // `lineItems` vira TypeError nao tratado.
  //
  // O QUE ISSO NAO E: nao concede VIP, nao muta documento, nao vaza segredo. A
  // excecao sobe, `retry: true` reentrega — o estado fica preservado.
  //
  // O QUE ISSO E: a mensagem vira pilula envenenada. Ela nao melhora com
  // reentrega, entao o Pub/Sub a redistribui ate a retencao do topico expirar, e
  // o operador ve uma pilha de TypeError em vez de uma decisao auditavel. E uma
  // inconsistencia defensiva de uma linha, nao um furo economico.
  //
  // PATCH RECOMENDADO (nao aplicado nesta OS — ver secao 11 da OS):
  //   -  if (!produtoId && itens.length > 0) produtoId = itens[0].productId || null;
  //   +  if (!produtoId && itens.length > 0) produtoId = (itens[0] && itens[0].productId) || null;
  //
  // QUANDO O PATCH ENTRAR, ESTE TESTE TEM DE SER INVERTIDO: passa a valer o
  // ramo `nao concede`, igual ao O2 acima.
  for (const itens of [[null], [undefined]]) {
    const c = cenarioDeModulo();
    c.registrarCompra(HASH_A, { uid: U1 });
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

    await assert.rejects(
      () => c.rtdn.processarNotificacao(
        mensagem(corpoAssinatura(NOTIFICACAO.RENEWED, { token: TOKEN_A }), 'msg_O2b')
      ),
      (e) => e instanceof TypeError,
      `lineItems=${JSON.stringify(itens)} deixou de lancar — o patch entrou? inverta este teste`
    );

    // O que importa para o veredito economico continua valendo: nada mudou.
    assert.equal(c.db.escritasEm(publicoDe(U1)), 0, 'a falha mutou o entitlement');
    assert.equal(c.publico(U1).vipAtivo, true);
    assert.equal(c.evento('msg_O2b'), null, 'marcou concluido um evento que falhou');
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
    assert.equal(c.publico(U1).vipAtivo, false, `estado ${bruto} concedeu VIP`);
    assert.equal(c.publico(U1).estado, ESTADO.DESCONHECIDO);
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
    assert.equal(c.publico(U1).vipAtivo, false, `corpo ${JSON.stringify(corpo)} concedeu VIP`);
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

  await assert.rejects(
    () => c.chamar('validarCompraPlay', {
      uid: U1, dados: { produtoId: PRODUTO, tokenCompra: TOKEN_A, assinatura: true },
    }),
    (e) => e.code === 'unavailable'
  );

  assert.equal(c.publico(U1), null, 'concedeu sem confirmacao autoritativa');
  // O registro fica pendente, e nao recusado: recusar travaria a retentativa.
  assert.notEqual(c.compra(HASH_A).estado, 'recusada');
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
  c.registrarCompra(HASH_A, { uid: U1 });
  c.registrarCompra(HASH_B, { uid: U2 });
  c.semearEntitlement(U1, {
    estado: ESTADO.ATIVO, vipAtivo: true, expiraEm: FUTURO, hash: HASH_A, token: TOKEN_A, verificadoEm: T0,
  });
  c.db.zerarDiario();
  c.relogio.fila(T1);

  const r = await c.rtdn.processarNotificacao(mensagem(corpoAnulacao({ token: TOKEN_B }), 'msg_R3'));

  assert.equal(r.uid, U2, 'a notificacao foi atribuida ao jogador errado');
  assert.equal(c.publico(U1).vipAtivo, true, 'o estorno alheio derrubou o VIP do titular');
  assert.equal(c.db.escritasEm(publicoDe(U1)), 0);
  assert.equal(c.publico(U2).estado, ESTADO.REVOGADO === undefined ? undefined : ESTADO.REEMBOLSADO);
  assertSemSegredo(c.textoDosLogs());
});

test('R4 notificacao sobre token sem titular comprovavel e descartada, sem inventar dono', async () => {
  const c = cenarioDeModulo();
  c.relogio.fila(T1);

  const r = await c.rtdn.processarNotificacao(
    mensagem(corpoAssinatura(NOTIFICACAO.RENEWED, { token: TOKEN_C }), 'msg_R4')
  );

  assert.equal(r.decisao, 'compra_desconhecida');
  assert.equal(r.aplicado, false);
  assert.deepEqual(c.db.caminhos().filter((p) => p.startsWith('playerEntitlements/')), []);
  assert.equal(c.play.total(), 0, 'consultou a Google por um token sem dono');
  assertSemSegredo(c.textoDosLogs());
});

test('R6 DEFEITO REGISTRADO quem apresenta o token PRIMEIRO vira o dono dele', async () => {
  // ACHADO A-1 do laudo. Nao ha vinculo entre a COMPRA da Google e a CONTA do
  // aplicativo. A titularidade nasce em `compras/{hash}` no primeiro
  // `validarCompraPlay` que chegar (index.js:271-285), com o uid de quem chamou.
  // A resposta da Play e consultada DEPOIS, e ela nao e conferida contra
  // identidade nenhuma: `consolidarAssinatura` le estado, prazo e produto, e
  // ignora `externalAccountIdentifiers`.
  //
  // Consequencia, encenada abaixo: quem tiver o `purchaseToken` de outra pessoa
  // e chegar antes do dono fica com o VIP, e o dono passa a receber
  // `permission-denied` para sempre — o mesmo guarda que protege o caso R
  // trabalha, aqui, a favor do invasor.
  //
  // PRECONDICAO, dita sem maquiagem: e preciso JA possuir o token da vitima. Ele
  // e credencial ao portador e so sai do aparelho dela. Isto nao e escalada
  // anonima; e a ausencia da amarra que a Google documenta para exatamente este
  // risco.
  //
  // PATCH RECOMENDADO (nao aplicado — ver secao 11 da OS), nas duas pontas:
  //   1. cliente: passar `obfuscatedAccountId` = hash do uid no fluxo de compra;
  //   2. servidor: recusar quando
  //      `compra.externalAccountIdentifiers.obfuscatedExternalAccountId`
  //      nao bater com o uid autenticado, ANTES de gravar `compras/{hash}`.
  // Sem (1) a conferencia de (2) nao tem com o que comparar. Nesta base o
  // cliente Flutter de Billing nao existe, entao as duas pontas estao abertas.
  const c = cenarioDeIndex();
  c.play.definirAssinatura(TOKEN_A, { estado: c.play.ESTADOS.ATIVA, expiraEm: FUTURO });

  // U2 nao pagou nada: so tem o token de U1.
  const invasor = await c.chamar('validarCompraPlay', {
    uid: U2, dados: { produtoId: PRODUTO, tokenCompra: TOKEN_A, assinatura: true },
  });

  assert.equal(invasor.aprovada, true, 'o comportamento mudou — o patch entrou? inverta este teste');
  assert.equal(c.publico(U2).vipAtivo, true, 'idem');
  assert.equal(c.compra(HASH_A).uid, U2);

  // E o pagante fica de fora, definitivamente.
  await assert.rejects(
    () => c.chamar('validarCompraPlay', {
      uid: U1, dados: { produtoId: PRODUTO, tokenCompra: TOKEN_A, assinatura: true },
    }),
    (e) => e.code === 'permission-denied'
  );
  assert.equal(c.publico(U1), null);

  // E a notificacao da Play sobre essa compra passa a alimentar o invasor.
  await c.entregar(corpoAssinatura(NOTIFICACAO.RENEWED, { token: TOKEN_A }), 'msg_R6');
  assert.equal(c.publico(U2).vipAtivo, true);
  assert.equal(c.publico(U1), null);
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
// S — redacao de segredo
// ===========================================================================

test('S o purchaseToken nao alcanca log, trilha nem documento que o cliente le', async () => {
  const c = cenarioDeModulo();
  c.registrarCompra(HASH_A, { uid: U1 });
  c.registrarCompra(HASH_B, { uid: U2 });
  c.play.definirAssinatura(TOKEN_A, { estado: c.play.ESTADOS.ATIVA, expiraEm: FUTURO });
  c.play.definirFalha(TOKEN_B, new FalhaPermanentePlay('400 invalid token'));
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

test('V ausencia de pre-cadastro nao autoriza identidade ficticia nem usuario generico', async () => {
  const c = cenarioDeModulo();
  // Nenhum `compras/`, nenhum `usuarios/`, nenhum entitlement.
  c.relogio.fila(T1);

  const r = await c.rtdn.processarNotificacao(
    mensagem(corpoAssinatura(NOTIFICACAO.PURCHASED, { token: TOKEN_A }), 'msg_V1')
  );

  assert.equal(r.decisao, 'compra_desconhecida');
  assert.equal(r.uid, undefined, 'inventou um titular');
  assert.deepEqual(c.db.caminhos().filter((p) => p.startsWith('playerEntitlements/')), []);
  assert.deepEqual(c.db.caminhos().filter((p) => p.startsWith('usuarios/')), []);
});

test('V2 registro de compra sem uid nao produz direito para ninguem', async () => {
  const c = cenarioDeModulo();
  c.db.semear(compraDe(HASH_A), { produtoId: PRODUTO, assinatura: true, estado: 'concedida' });
  c.relogio.fila(T1);

  const r = await c.rtdn.processarNotificacao(
    mensagem(corpoAssinatura(NOTIFICACAO.RENEWED, { token: TOKEN_A }), 'msg_V2')
  );

  assert.equal(r.decisao, 'registro_sem_uid');
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
  for (const proibido of ['playerModeration/', 'tournaments/', 'rankingLedger/', 'matches/', 'reports/']) {
    assert.ok(!c.db.caminhos().some((p) => p.startsWith(proibido)), `escreveu em ${proibido}`);
  }
});

test('X2 a superficie exportada e exatamente as cinco funcoes declaradas', () => {
  const c = cenarioDeIndex();
  assert.deepEqual(Object.keys(c.modulo).sort(), [
    'migrarEntitlementsLegado',
    'notificacoesPlay',
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
});

test('X3 a origem da notificacao: pacote alheio e recusado', () => {
  const alheio = interpretarNotificacao(
    { packageName: 'com.outro.app', subscriptionNotification: { notificationType: 2, purchaseToken: TOKEN_A } },
    PACOTE
  );
  assert.equal(alheio.acao, 'ignorar');
  assert.equal(alheio.motivo, 'pacote_alheio');

  // OBSERVACAO REGISTRADA: a mensagem SEM `packageName` nao e recusada — a
  // condicao e `corpo.packageName && ...`. O controle primario e o IAM do topico
  // (so a Google publica); esta e a defesa em profundidade, e ela e opcional por
  // omissao. Anotado no laudo como achado Medio, com o patch recomendado.
  const semPacote = interpretarNotificacao(
    { subscriptionNotification: { notificationType: 2, purchaseToken: TOKEN_A } },
    PACOTE
  );
  assert.equal(semPacote.acao, 'reconciliar');

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
