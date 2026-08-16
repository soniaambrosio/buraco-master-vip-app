/**
 * Testes do BENEFICIO ECONOMICO da assinatura — as fichas.
 *
 * `node --test`, sem emulador, sem rede e sem relogio real. Duas camadas, com a
 * fronteira declarada para nao chamar de integracao o que nao e:
 *
 *   CALENDARIO (fichas.js, puro)
 *     Quantas parcelas venceram e quanto cada uma vale. As datas entram como
 *     literais. E aqui que a POLITICA COMERCIAL aprovada e amarrada em teste:
 *     FICHAS-15 falha se alguem trocar 1.500 por outro numero sem decidir.
 *
 *   LIVRO-RAZAO (fichasStore.js, contra o Firestore falso)
 *     A garantia que custa dinheiro: a mesma parcela nao e paga duas vezes, nem
 *     sob dois ticks concorrentes. O Firestore falso implementa contencao
 *     otimista de verdade, entao FICHAS-18 e FICHAS-21 provam interleaving, e
 *     nao apenas chamada sequencial.
 *
 *   FORA DE ALCANCE
 *     O agendador em si (`concederFichasMensais`), que e adaptador do Cloud
 *     Scheduler dentro de `index.js`. O que ele decide — quais indices, quanto
 *     cada um vale, e a barreira de idempotencia — esta todo coberto aqui.
 */

'use strict';

const test = require('node:test');
const assert = require('node:assert');

const {
  mesesDecorridos,
  planoDoCatalogo,
  fichasDoIndice,
  indicesDevidos,
  chaveConcessao,
} = require('../fichas');

const { criarLivroDeFichas } = require('../fichasStore');
const { FirestoreFalso, CARIMBO } = require('./apoio/firestore_falso');

// ---------------------------------------------------------------------------
// A politica comercial aprovada, como ela vai ser escrita em `configuracao/billing`.
// ---------------------------------------------------------------------------

const PLANOS = {
  monthly_auto: { mesesDoCiclo: 1, ativacao: 1500, mensal: 1000 },
  quarterly_auto: { mesesDoCiclo: 3, ativacao: 2700, mensal: 1200 },
  yearly_auto: { mesesDoCiclo: 12, ativacao: 6500, mensal: 1500 },
};

const DEFINICAO = { assinatura: true, planos: PLANOS };

const UID = 'jogador-1';
const HASH = 'a'.repeat(64);

function porta() {
  let abrir;
  const aberta = new Promise((r) => {
    abrir = r;
  });
  return { aberta, abrir };
}

function montarLivro() {
  const db = new FirestoreFalso();
  const livro = criarLivroDeFichas({
    db,
    carimbo: () => CARIMBO,
    incremento: (n) => ({ __incremento: n }),
  });
  return { db, livro };
}

// ===========================================================================
// CALENDARIO
// ===========================================================================

test('FICHAS-01 no dia da compra nenhum mes decorreu', () => {
  assert.strictEqual(
    mesesDecorridos('2026-03-10T12:00:00Z', '2026-03-10T12:00:00Z'),
    0
  );
  assert.strictEqual(
    mesesDecorridos('2026-03-10T12:00:00Z', '2026-04-09T23:59:59Z'),
    0
  );
});

test('FICHAS-02 o mesversario exato conta como mes completo', () => {
  assert.strictEqual(
    mesesDecorridos('2026-03-10T12:00:00Z', '2026-04-10T12:00:00Z'),
    1
  );
  assert.strictEqual(
    mesesDecorridos('2026-03-10T12:00:00Z', '2027-03-10T12:00:00Z'),
    12
  );
});

test('FICHAS-03 a virada do mes NAO e mesversario', () => {
  // 20 de janeiro -> 1o de marco cruzou duas viradas de calendario, mas o mes 2
  // so vence em 20 de marco. Contar viradas pagaria uma parcela adiantada.
  assert.strictEqual(
    mesesDecorridos('2026-01-20T00:00:00Z', '2026-03-01T00:00:00Z'),
    1
  );
});

test('FICHAS-04 mes curto: quem assinou em 31 de janeiro vence em 28 de fevereiro', () => {
  // Sem o grude no ultimo dia, `Date.UTC(ano, 1, 31)` transborda para 3 de marco
  // e o jogador esperaria tres dias a mais pela parcela dele.
  assert.strictEqual(
    mesesDecorridos('2026-01-31T10:00:00Z', '2026-02-28T10:00:00Z'),
    1
  );
  assert.strictEqual(
    mesesDecorridos('2026-01-31T10:00:00Z', '2026-02-28T09:59:59Z'),
    0
  );
});

test('FICHAS-05 data ausente ou invalida nao concede parcela nenhuma', () => {
  assert.strictEqual(mesesDecorridos(null, '2026-03-10T00:00:00Z'), -1);
  assert.strictEqual(mesesDecorridos('nao-e-data', '2026-03-10T00:00:00Z'), -1);
  assert.strictEqual(mesesDecorridos('2026-03-10T00:00:00Z', null), -1);
  assert.deepStrictEqual(
    indicesDevidos({ inicioEm: null, agora: '2026-03-10T00:00:00Z' }).indices,
    []
  );
});

test('FICHAS-06 relogio atras do inicio nao concede', () => {
  assert.strictEqual(
    mesesDecorridos('2026-03-10T00:00:00Z', '2026-03-09T00:00:00Z'),
    -1
  );
});

// ===========================================================================
// VALOR DA PARCELA
// ===========================================================================

test('FICHAS-07 o indice 0 e a ativacao', () => {
  assert.strictEqual(fichasDoIndice(PLANOS.monthly_auto, 0), 1500);
  assert.strictEqual(fichasDoIndice(PLANOS.quarterly_auto, 0), 2700);
  assert.strictEqual(fichasDoIndice(PLANOS.yearly_auto, 0), 6500);
});

test('FICHAS-08 os demais indices valem a parcela mensal', () => {
  assert.strictEqual(fichasDoIndice(PLANOS.monthly_auto, 1), 1000);
  assert.strictEqual(fichasDoIndice(PLANOS.quarterly_auto, 2), 1200);
  assert.strictEqual(fichasDoIndice(PLANOS.yearly_auto, 11), 1500);
});

test('FICHAS-09 por padrao a renovacao NAO repete o bonus de ativacao', () => {
  // A leitura coerente com o plano mensal, que recebe 1.500 na ativacao e 1.000
  // nos meses seguintes: se renovar fosse ativar, o mensal receberia 1.500 todo
  // mes e "1.000 nos meses seguintes" nao se aplicaria a ninguem.
  assert.strictEqual(fichasDoIndice(PLANOS.monthly_auto, 1), 1000);
  assert.strictEqual(fichasDoIndice(PLANOS.quarterly_auto, 3), 1200);
  assert.strictEqual(fichasDoIndice(PLANOS.yearly_auto, 12), 1500);
});

test('FICHAS-10 `ativacaoPorCiclo` liga a outra leitura, sem deploy', () => {
  const trimestral = { ...PLANOS.quarterly_auto, ativacaoPorCiclo: true };
  assert.strictEqual(fichasDoIndice(trimestral, 1), 1200);
  assert.strictEqual(fichasDoIndice(trimestral, 2), 1200);
  assert.strictEqual(fichasDoIndice(trimestral, 3), 2700); // inicio do 2o ciclo
  assert.strictEqual(fichasDoIndice(trimestral, 6), 2700);
});

test('FICHAS-11 plano ausente ou valor invalido vale zero, nunca NaN', () => {
  assert.strictEqual(fichasDoIndice(null, 0), 0);
  assert.strictEqual(fichasDoIndice({}, 0), 0);
  assert.strictEqual(fichasDoIndice({ ativacao: 'muitas' }, 0), 0);
  assert.strictEqual(fichasDoIndice({ ativacao: -50 }, 0), 0);
  assert.strictEqual(fichasDoIndice(PLANOS.monthly_auto, -1), 0);
});

test('FICHAS-12 plano-base fora do catalogo devolve null, e nao um objeto vazio', () => {
  assert.strictEqual(planoDoCatalogo(DEFINICAO, 'monthly_auto'), PLANOS.monthly_auto);
  assert.strictEqual(planoDoCatalogo(DEFINICAO, 'weekly_auto'), null);
  assert.strictEqual(planoDoCatalogo(DEFINICAO, null), null);
  assert.strictEqual(planoDoCatalogo(null, 'monthly_auto'), null);
  assert.strictEqual(planoDoCatalogo({ assinatura: true }, 'monthly_auto'), null);
});

// ===========================================================================
// PARCELAS DEVIDAS
// ===========================================================================

test('FICHAS-13 as parcelas devidas vao de 0 ate o mes decorrido', () => {
  const r = indicesDevidos({
    inicioEm: '2026-01-10T00:00:00Z',
    agora: '2026-04-10T00:00:00Z',
  });
  assert.deepStrictEqual(r.indices, [0, 1, 2, 3]);
  assert.strictEqual(r.truncado, false);
});

test('FICHAS-14 o teto por tick e sinalizado, nunca silencioso', () => {
  const r = indicesDevidos({
    inicioEm: '2020-01-10T00:00:00Z',
    agora: '2026-01-10T00:00:00Z',
    teto: 5,
  });
  assert.strictEqual(r.indices.length, 5);
  assert.strictEqual(r.truncado, true);
  // O que sobrou nao se perde: o tick seguinte reencontra as mesmas parcelas em
  // aberto, porque quem manda e o indice do mes e nao o momento do job.
  assert.strictEqual(r.decorridos, 72);
});

test('FICHAS-15 a politica comercial aprovada, mes a mes', () => {
  const sequencia = (basePlanId, meses) => {
    const plano = planoDoCatalogo(DEFINICAO, basePlanId);
    assert.ok(plano, `${basePlanId} precisa existir no catalogo`);
    return Array.from({ length: meses }, (_, i) => fichasDoIndice(plano, i));
  };

  // Mensal: 1.500 na ativacao, 1.000 nos meses seguintes.
  assert.deepStrictEqual(sequencia('monthly_auto', 4), [1500, 1000, 1000, 1000]);

  // Trimestral: 2.700 na ativacao, 1.200 no 2o mes, 1.200 no 3o.
  assert.deepStrictEqual(sequencia('quarterly_auto', 3), [2700, 1200, 1200]);

  // Anual: 6.500 na ativacao, 1.500 por mes nos 11 meses seguintes.
  const anual = sequencia('yearly_auto', 12);
  assert.strictEqual(anual[0], 6500);
  assert.deepStrictEqual(anual.slice(1), Array(11).fill(1500));
  assert.strictEqual(
    anual.reduce((a, b) => a + b, 0),
    6500 + 11 * 1500
  );
});

// ===========================================================================
// LIVRO-RAZAO
// ===========================================================================

test('FICHAS-16 a parcela liquidada credita o saldo e deixa a linha', async () => {
  const { db, livro } = montarLivro();

  const r = await livro.liquidarParcela({
    uid: UID,
    purchaseTokenHash: HASH,
    indice: 0,
    fichas: 1500,
    produtoId: 'master_vip',
    planoBase: 'monthly_auto',
    origem: 'validacao',
  });

  assert.strictEqual(r.creditado, 1500);
  assert.strictEqual(r.motivo, 'parcela_liquidada');

  const linha = db.ver(`fichasConcessoes/${chaveConcessao(HASH, 0)}`);
  assert.strictEqual(linha.uid, UID);
  assert.strictEqual(linha.indice, 0);
  assert.strictEqual(linha.fichas, 1500);
  assert.strictEqual(linha.origem, 'validacao');
  assert.strictEqual(linha.planoBase, 'monthly_auto');

  assert.deepStrictEqual(db.ver(`usuarios/${UID}`).fichas, { __incremento: 1500 });
});

test('FICHAS-17 repetir a mesma parcela nao credita de novo', async () => {
  const { db, livro } = montarLivro();
  const parcela = {
    uid: UID,
    purchaseTokenHash: HASH,
    indice: 3,
    fichas: 1200,
  };

  const primeira = await livro.liquidarParcela(parcela);
  const segunda = await livro.liquidarParcela(parcela);
  const terceira = await livro.liquidarParcela(parcela);

  assert.strictEqual(primeira.creditado, 1200);
  assert.strictEqual(segunda.creditado, 0);
  assert.strictEqual(segunda.motivo, 'parcela_ja_paga');
  assert.strictEqual(terceira.creditado, 0);

  assert.strictEqual(db.commits, 3); // as tres transacoes commitaram...
  assert.deepStrictEqual(
    db.caminhos().filter((c) => c.startsWith('fichasConcessoes/')),
    [`fichasConcessoes/${chaveConcessao(HASH, 3)}`] // ...e ha UMA linha so.
  );
});

test('FICHAS-18 dois ticks concorrentes na MESMA parcela creditam uma vez so', async () => {
  const { db, livro } = montarLivro();
  const parcela = { uid: UID, purchaseTokenHash: HASH, indice: 1, fichas: 1000 };

  const chegou = porta();
  const liberado = porta();
  let primeira = true;
  db.pausarAntesDoCommit = async () => {
    if (!primeira) return;
    primeira = false;
    chegou.abrir();
    await liberado.aberta;
  };

  // A entra, le a parcela em aberto, e para na porta do commit.
  const pA = livro.liquidarParcela(parcela);
  await chegou.aberta;

  // B corre inteiro por dentro e commita primeiro.
  const rB = await livro.liquidarParcela(parcela);

  liberado.abrir();
  const rA = await pA;

  // A perdeu a corrida: o documento que ela leu mudou, a transacao rodou de novo
  // e da segunda vez a linha ja existia.
  assert.strictEqual(rB.creditado, 1000);
  assert.strictEqual(rA.creditado, 0);
  assert.strictEqual(rA.motivo, 'parcela_ja_paga');
  assert.ok(db.conflitos >= 1, 'a corrida precisa ter sido detectada de verdade');

  assert.deepStrictEqual(
    db.caminhos().filter((c) => c.startsWith('fichasConcessoes/')),
    [`fichasConcessoes/${chaveConcessao(HASH, 1)}`]
  );
});

test('FICHAS-19 parcelas de indices diferentes nao se atrapalham', async () => {
  const { db, livro } = montarLivro();
  const base = { uid: UID, purchaseTokenHash: HASH, fichas: 1500 };

  const r = await Promise.all([
    livro.liquidarParcela({ ...base, indice: 0 }),
    livro.liquidarParcela({ ...base, indice: 1 }),
    livro.liquidarParcela({ ...base, indice: 2 }),
  ]);

  assert.deepStrictEqual(r.map((x) => x.creditado), [1500, 1500, 1500]);
  assert.strictEqual(
    db.caminhos().filter((c) => c.startsWith('fichasConcessoes/')).length,
    3
  );
});

test('FICHAS-20 parcela sem valor nao vira linha no livro', async () => {
  const { db, livro } = montarLivro();

  const zero = await livro.liquidarParcela({
    uid: UID,
    purchaseTokenHash: HASH,
    indice: 5,
    fichas: 0,
  });
  assert.strictEqual(zero.creditado, 0);
  assert.strictEqual(zero.motivo, 'parcela_sem_valor');

  const malFormada = await livro.liquidarParcela({
    uid: null,
    purchaseTokenHash: HASH,
    indice: 5,
    fichas: 100,
  });
  assert.strictEqual(malFormada.motivo, 'parcela_mal_formada');

  // Nenhuma escrita: uma linha de zero afirmaria que a parcela foi paga, e o
  // tick seguinte deixaria de pagar se o catalogo passasse a valer algo.
  assert.deepStrictEqual(db.caminhos(), []);
});

test('FICHAS-21 validacao e agendador na mesma parcela: um credito so', async () => {
  // A prova do desenho: a ativacao NAO e creditada dentro da transacao de
  // concessao justamente para passar por este mesmo livro. Se o agendador
  // chegar antes, a validacao encontra a linha — e vice-versa. E o que torna o
  // agendador uma rede de seguranca sem existir codigo de reparo.
  const { db, livro } = montarLivro();
  const parcela = { uid: UID, purchaseTokenHash: HASH, indice: 0, fichas: 1500 };

  const doAgendador = await livro.liquidarParcela({ ...parcela, origem: 'agendador' });
  const daValidacao = await livro.liquidarParcela({ ...parcela, origem: 'validacao' });

  assert.strictEqual(doAgendador.creditado, 1500);
  assert.strictEqual(daValidacao.creditado, 0);
  assert.strictEqual(db.ver(`fichasConcessoes/${chaveConcessao(HASH, 0)}`).origem, 'agendador');
});

test('FICHAS-22 reassinatura traz token novo, e com ele um livro novo', async () => {
  // Quem deixa expirar e assina de novo recebe token novo da Play, portanto
  // chave nova — e volta a ter direito ao bonus de ativacao. Se a chave fosse
  // por uid, o segundo contrato nunca receberia a ativacao dele.
  const { db, livro } = montarLivro();
  const HASH2 = 'b'.repeat(64);

  const primeira = await livro.liquidarParcela({
    uid: UID, purchaseTokenHash: HASH, indice: 0, fichas: 1500,
  });
  const segunda = await livro.liquidarParcela({
    uid: UID, purchaseTokenHash: HASH2, indice: 0, fichas: 1500,
  });

  assert.strictEqual(primeira.creditado, 1500);
  assert.strictEqual(segunda.creditado, 1500);
  assert.strictEqual(
    db.caminhos().filter((c) => c.startsWith('fichasConcessoes/')).length,
    2
  );
});
