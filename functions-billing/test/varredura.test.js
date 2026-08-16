/**
 * Testes da VARREDURA — o alcance da entrega mensal de fichas.
 *
 * O QUE ESTA SUITE EXISTE PARA IMPEDIR
 *
 * O defeito que ela cobre atravessou a homologacao inteira sem nenhum teste
 * falhar, porque nao havia teste que pudesse falhar: a selecao dos assinantes
 * era `.where('vipAtivo','==',true).limit(500)` dentro de `index.js`, e importar
 * `index.js` puxa `firebase-functions`. O codigo que decidia quem recebia
 * dinheiro era, na pratica, inalcancavel.
 *
 * Com `varredura.js` e `fichasVarredura.js` separados, as perguntas que valem
 * dinheiro viraram assercao:
 *
 *   ALCANCE     todo elegivel e visitado, inclusive o 501o e o 1.200o;
 *   SEM REPETIR a pagina 2 nao revisita a pagina 1;
 *   IDEMPOTENCIA rodar de novo no mesmo periodo nao paga de novo;
 *   RETOMADA    interromper no meio e rodar de novo termina certo.
 *
 * O Firestore falso ganhou `where`/`orderBy`/`limit`/`startAfter` para isto, com
 * a mesma disciplina do resto do arquivo: consultas IMUTAVEIS e encadeaveis. Se
 * elas mutassem, uma varredura que reaproveitasse o objeto base acumularia
 * cursores e o teste passaria a provar o contrario do que pretende.
 */

'use strict';

const test = require('node:test');
const assert = require('node:assert');

const { varrerPaginado } = require('../varredura');
const {
  concederFichasDeTodosOsAssinantes,
} = require('../fichasVarredura');
const { criarLivroDeFichas } = require('../fichasStore');
const {
  FirestoreFalso,
  CARIMBO,
  FieldPathFalso,
} = require('./apoio/firestore_falso');

// ---------------------------------------------------------------------------
// Mesa

const COL = 'playerEntitlements';
const AGORA = '2026-08-15T12:00:00.000Z';

/** A politica economica aprovada, como ela vive em `configuracao/billing`. */
const CATALOGO = {
  vip_assinatura: {
    planos: {
      mensal: { ativacao: 1500, mensal: 1000 },
    },
  },
};

/** `anteriorA(a, b)` — `a` acontece antes de `b`. */
const anteriorA = (a, b) => String(a) < String(b);

/**
 * Semeia [quantos] assinantes ativos, com ids de largura fixa.
 *
 * A largura fixa importa: `assinante-9` e `assinante-10` ordenam ao contrario do
 * esperado em ordem lexicografica, e um cursor por id ordena LEXICOGRAFICAMENTE.
 * Ids de tamanho irregular fariam o teste passar ou falhar por um detalhe do
 * gerador de dados, e nao pela varredura.
 */
function semearAssinantes(db, quantos, { inicioEm = '2026-06-15T12:00:00.000Z' } = {}) {
  const uids = [];
  for (let i = 0; i < quantos; i += 1) {
    const uid = `assinante-${String(i).padStart(5, '0')}`;
    uids.push(uid);
    db.semear(`${COL}/${uid}`, {
      vipAtivo: true,
      estado: 'ativo',
      produtoId: 'vip_assinatura',
      planoBase: 'mensal',
      inicioEm,
      expiraEm: '2027-01-01T00:00:00.000Z',
    });
    db.semear(`${COL}/${uid}/interno/billing`, {
      purchaseTokenHash: `hash-${uid}`,
    });
  }
  return uids;
}

/** Monta a varredura sobre um banco, com o livro-razao de verdade. */
function montar(db, extras = {}) {
  const livro = criarLivroDeFichas({
    db,
    carimbo: () => CARIMBO,
    // O Firestore falso nao tem `FieldValue.increment`; o sentinel abaixo soma
    // de verdade sobre o que ja estava gravado, que e o que os testes de saldo
    // precisam observar.
    incremento: (n) => ({ __incremento: n }),
  });

  return () =>
    concederFichasDeTodosOsAssinantes({
      db,
      FieldPath: FieldPathFalso,
      colecaoEntitlement: COL,
      catalogo: CATALOGO,
      agora: AGORA,
      anteriorA,
      lerInterno: async (uid) => db.ver(`${COL}/${uid}/interno/billing`),
      liquidarParcela: (p) => livro.liquidarParcela(p),
      ...extras,
    });
}

/** Quantas linhas de livro-razao existem para um jogador. */
function parcelasDe(db, uid) {
  return db
    .caminhos()
    .filter((c) => c.startsWith('fichasConcessoes/hash-' + uid + '_'));
}

// ---------------------------------------------------------------------------
// A mecanica do cursor, sem fichas no meio

test('VARR-01 uma colecao menor que a pagina e visitada inteira', async () => {
  const db = new FirestoreFalso();
  semearAssinantes(db, 7);

  const vistos = [];
  const r = await varrerPaginado({
    consulta: () => db.collection(COL).where('vipAtivo', '==', true),
    FieldPath: FieldPathFalso,
    tamanhoPagina: 100,
    aoVisitar: async (d) => vistos.push(d.id),
  });

  assert.equal(vistos.length, 7);
  assert.equal(r.paginas, 1);
  assert.equal(r.esgotou, true);
});

test('VARR-02 a pagina 2 comeca onde a 1 parou, sem repetir e sem pular', async () => {
  const db = new FirestoreFalso();
  const uids = semearAssinantes(db, 250);

  const vistos = [];
  await varrerPaginado({
    consulta: () => db.collection(COL).where('vipAtivo', '==', true),
    FieldPath: FieldPathFalso,
    tamanhoPagina: 100,
    aoVisitar: async (d) => vistos.push(d.id),
  });

  assert.equal(vistos.length, 250);
  assert.equal(new Set(vistos).size, 250, 'nenhum documento visitado duas vezes');
  assert.deepEqual(vistos, [...uids].sort(), 'todos, na ordem estavel do id');
});

test('VARR-03 uma colecao com multiplo exato do lote nao para cedo nem tarde', async () => {
  const db = new FirestoreFalso();
  semearAssinantes(db, 200);

  const vistos = [];
  const r = await varrerPaginado({
    consulta: () => db.collection(COL).where('vipAtivo', '==', true),
    FieldPath: FieldPathFalso,
    tamanhoPagina: 100,
    aoVisitar: async (d) => vistos.push(d.id),
  });

  // 100 + 100 + uma terceira pagina VAZIA: com multiplo exato, a segunda pagina
  // vem cheia e nao serve de prova de que acabou.
  assert.equal(vistos.length, 200);
  assert.equal(r.paginas, 3);
  assert.equal(r.esgotou, true);
});

test('VARR-04 o filtro e respeitado: quem nao esta ativo nao e visitado', async () => {
  const db = new FirestoreFalso();
  semearAssinantes(db, 5);
  db.semear(`${COL}/inativo-1`, { vipAtivo: false, estado: 'expirado' });
  db.semear(`${COL}/inativo-2`, { vipAtivo: false, estado: 'revogado' });

  const vistos = [];
  await varrerPaginado({
    consulta: () => db.collection(COL).where('vipAtivo', '==', true),
    FieldPath: FieldPathFalso,
    tamanhoPagina: 100,
    aoVisitar: async (d) => vistos.push(d.id),
  });

  assert.equal(vistos.length, 5);
  assert.ok(!vistos.includes('inativo-1'));
});

test('VARR-05 um jogador problematico nao impede que os seguintes recebam', async () => {
  const db = new FirestoreFalso();
  const uids = semearAssinantes(db, 10);

  // A garantia mora em `fichasVarredura`, que envolve o trabalho de CADA
  // jogador num `try` — e nao no iterador, que deixa a excecao subir de
  // proposito para nao esconder falha de infraestrutura.
  const varrer = montar(db, {
    tamanhoPagina: 4,
    lerInterno: async (uid) => {
      if (uid.endsWith('00003')) throw new Error('documento problematico');
      return db.ver(`${COL}/${uid}/interno/billing`);
    },
  });

  const r = await varrer();

  assert.equal(r.candidatos, 10, 'a varredura chegou ao fim');
  assert.equal(r.esgotou, true);
  assert.equal(r.comFalha, 1, 'a falha foi contada, e nao engolida');
  assert.equal(r.jogadores, 9, 'os outros nove receberam');
  assert.equal(parcelasDe(db, uids[3]).length, 0);
  assert.equal(parcelasDe(db, uids[9]).length, 3, 'inclusive quem vinha depois');
});

test('VARR-06 o teto de paginas DEVOLVE cursor, e nao corta em silencio', async () => {
  const db = new FirestoreFalso();
  semearAssinantes(db, 500);

  const vistos = [];
  const r = await varrerPaginado({
    consulta: () => db.collection(COL).where('vipAtivo', '==', true),
    FieldPath: FieldPathFalso,
    tamanhoPagina: 100,
    maxPaginas: 2,
    aoVisitar: async (d) => vistos.push(d.id),
  });

  assert.equal(vistos.length, 200);
  assert.equal(r.esgotou, false, 'o corte precisa se declarar');
  assert.ok(r.cursor, 'e precisa dizer de onde continuar');

  // E continuar de la termina o servico.
  const resto = [];
  const r2 = await varrerPaginado({
    consulta: () => db.collection(COL).where('vipAtivo', '==', true),
    FieldPath: FieldPathFalso,
    tamanhoPagina: 100,
    cursorInicial: r.cursor,
    aoVisitar: async (d) => resto.push(d.id),
  });

  assert.equal(r2.esgotou, true);
  assert.equal(vistos.length + resto.length, 500);
  assert.equal(new Set([...vistos, ...resto]).size, 500);
});

// ---------------------------------------------------------------------------
// Os casos que a OS enumera: 499, 500, 501, 1.200

for (const total of [499, 500, 501, 1200]) {
  test(`VARR-07 (${total} assinantes) TODOS recebem, e cada um uma vez so`, async () => {
    const db = new FirestoreFalso();
    const uids = semearAssinantes(db, total);
    const varrer = montar(db);

    const r = await varrer();

    assert.equal(r.candidatos, total, 'todos foram visitados');
    assert.equal(r.jogadores, total, 'todos receberam');
    assert.equal(r.esgotou, true);

    // A conta do dinheiro: inicio em 15/06, agora 15/08 -> indices 0, 1 e 2.
    // 1.500 (ativacao) + 1.000 + 1.000 = 3.500 por jogador.
    assert.equal(r.parcelas, total * 3);
    assert.equal(r.fichas, total * 3500);

    // E o 501o (ou o 1.200o) existe MESMO — nao e um numero agregado.
    const ultimo = uids[uids.length - 1];
    assert.equal(
      parcelasDe(db, ultimo).length,
      3,
      `o ultimo assinante (${ultimo}) precisa ter recebido`
    );
  });
}

test('VARR-08 o 501o assinante e o que o teto antigo deixava de fora', async () => {
  const db = new FirestoreFalso();
  const uids = semearAssinantes(db, 501);
  const varrer = montar(db);

  await varrer();

  // O defeito original: `.limit(500)` sem cursor devolvia sempre os 500
  // primeiros ids em ordem estavel. O 501o em ordem lexicografica e este.
  const orfaoDoTetoAntigo = [...uids].sort()[500];
  assert.equal(
    parcelasDe(db, orfaoDoTetoAntigo).length,
    3,
    'o 501o assinante recebeu'
  );
});

// ---------------------------------------------------------------------------
// Idempotencia: reexecucao e retomada

test('VARR-09 rodar de novo no mesmo periodo NAO paga de novo', async () => {
  const db = new FirestoreFalso();
  semearAssinantes(db, 501);
  const varrer = montar(db);

  const primeira = await varrer();
  const linhasApos1 = db.caminhos().filter((c) => c.startsWith('fichasConcessoes/'));

  const segunda = await varrer();
  const linhasApos2 = db.caminhos().filter((c) => c.startsWith('fichasConcessoes/'));

  assert.equal(primeira.parcelas, 501 * 3);
  assert.equal(segunda.parcelas, 0, 'a segunda passagem nao credita nada');
  assert.equal(segunda.fichas, 0);
  assert.equal(segunda.jogadores, 0);

  // A segunda passagem VISITOU todo mundo — ela nao ficou barata por ter
  // deixado de olhar, e sim por ter encontrado tudo pago.
  assert.equal(segunda.candidatos, 501);
  assert.deepEqual(linhasApos2, linhasApos1, 'nenhuma linha nova no livro-razao');
});

test('VARR-10 tres execucoes seguidas mantem o total exato', async () => {
  const db = new FirestoreFalso();
  semearAssinantes(db, 250);
  const varrer = montar(db);

  await varrer();
  await varrer();
  await varrer();

  const linhas = db.caminhos().filter((c) => c.startsWith('fichasConcessoes/'));
  assert.equal(linhas.length, 250 * 3, 'uma linha por parcela, e so uma');
});

test('VARR-11 interrupcao no meio e nova execucao terminam sem duplicar', async () => {
  const db = new FirestoreFalso();
  const uids = semearAssinantes(db, 501);
  const livro = criarLivroDeFichas({
    db,
    carimbo: () => CARIMBO,
    incremento: (n) => ({ __incremento: n }),
  });

  // Primeira execucao: cai depois de UMA pagina, como se a Cloud Function
  // tivesse estourado o tempo. Nada de checkpoint e gravado.
  let visitados = 0;
  await assert.rejects(
    concederFichasDeTodosOsAssinantes({
      db,
      FieldPath: FieldPathFalso,
      colecaoEntitlement: COL,
      catalogo: CATALOGO,
      agora: AGORA,
      anteriorA,
      tamanhoPagina: 100,
      lerInterno: async (uid) => {
        visitados += 1;
        if (visitados > 100) throw new Error('tempo esgotado');
        return db.ver(`${COL}/${uid}/interno/billing`);
      },
      liquidarParcela: (p) => livro.liquidarParcela(p),
      // Sem `registrarErro` engolindo: a excecao de `lerInterno` e capturada
      // pela varredura por jogador, entao forcamos a queda de outro jeito.
      registrarErro: (m) => {
        if (m === 'tempo esgotado') throw new Error('execucao interrompida');
      },
    }),
    /execucao interrompida/
  );

  const parciais = db.caminhos().filter((c) => c.startsWith('fichasConcessoes/'));
  assert.ok(parciais.length > 0, 'a primeira execucao pagou alguem');
  assert.ok(parciais.length < 501 * 3, 'e nao chegou ao fim');

  // Segunda execucao: do zero, sem saber de nada. O livro-razao e o unico
  // estado que atravessa — e ele basta.
  const varrer = montar(db);
  const r = await varrer();

  assert.equal(r.esgotou, true);
  const finais = db.caminhos().filter((c) => c.startsWith('fichasConcessoes/'));
  assert.equal(finais.length, 501 * 3, 'todas as parcelas, cada uma uma vez');

  for (const uid of [uids[0], uids[250], uids[500]]) {
    assert.equal(parcelasDe(db, uid).length, 3, `${uid} recebeu exatamente 3`);
  }
});

test('VARR-12 a idempotencia nao depende do tamanho da pagina', async () => {
  const db = new FirestoreFalso();
  semearAssinantes(db, 60);

  // Duas execucoes com paginacoes DIFERENTES: se a barreira dependesse da
  // fronteira das paginas em vez do livro-razao, isto duplicaria.
  await montar(db, { tamanhoPagina: 7 })();
  await montar(db, { tamanhoPagina: 25 })();

  const linhas = db.caminhos().filter((c) => c.startsWith('fichasConcessoes/'));
  assert.equal(linhas.length, 60 * 3);
});

// ---------------------------------------------------------------------------
// A politica economica continua sendo obedecida em escala

test('VARR-13 assinante com prazo VENCIDO nao recebe, mesmo com vipAtivo true', async () => {
  const db = new FirestoreFalso();
  semearAssinantes(db, 3);
  db.semear(`${COL}/vencido-1`, {
    vipAtivo: true,
    estado: 'ativo',
    produtoId: 'vip_assinatura',
    planoBase: 'mensal',
    inicioEm: '2026-06-15T12:00:00.000Z',
    // A varredura de vencimento pode nao ter passado ainda.
    expiraEm: '2026-07-01T00:00:00.000Z',
  });
  db.semear(`${COL}/vencido-1/interno/billing`, { purchaseTokenHash: 'hash-vencido-1' });

  const r = await montar(db)();

  assert.equal(r.candidatos, 4, 'ele foi VISITADO');
  assert.equal(r.jogadores, 3, 'mas nao recebeu');
  assert.equal(parcelasDe(db, 'vencido-1').length, 0);
});

test('VARR-14 assinante sem token nao vira pagamento, e e CONTADO', async () => {
  const db = new FirestoreFalso();
  semearAssinantes(db, 2);
  // Direito migrado do legado: nunca teve compra registrada por este codebase,
  // entao nao ha livro-razao estavel — e sem ele nao existe idempotencia.
  db.semear(`${COL}/legado-1`, {
    vipAtivo: true,
    estado: 'ativo',
    produtoId: 'vip_assinatura',
    planoBase: 'mensal',
    inicioEm: '2026-06-15T12:00:00.000Z',
    expiraEm: '2027-01-01T00:00:00.000Z',
    origem: 'legado_usuarios',
  });

  const r = await montar(db)();

  assert.equal(r.semPlano, 1, 'o caso e contado, e nao engolido');
  assert.equal(r.jogadores, 2);
});

test('VARR-15 o saldo do jogador sobe uma vez por parcela, e so uma', async () => {
  const db = new FirestoreFalso();
  semearAssinantes(db, 1);
  const varrer = montar(db);

  await varrer();
  const depoisDe1 = db.ver('usuarios/assinante-00000');
  await varrer();
  const depoisDe2 = db.ver('usuarios/assinante-00000');

  assert.deepEqual(depoisDe2, depoisDe1, 'a segunda passagem nao toca no saldo');
});
