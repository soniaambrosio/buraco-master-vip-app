/**
 * Testes da MIGRACAO DO LEGADO — `usuarios/{uid}.vip` -> `playerEntitlements`.
 *
 * A auditoria de prontidao registrou esta funcao como sem cobertura suficiente.
 * A ausencia tinha causa estrutural: o corpo morava dentro do callable em
 * `index.js`, e importar `index.js` puxa `firebase-functions`, `firebase-admin` e
 * `googleapis`. Com `migracaoLegado.js` separado, a decisao por documento virou
 * assercao.
 *
 * NENHUMA POLITICA NOVA E DECIDIDA AQUI.
 *
 * Os dois casos ambiguos que a auditoria levantou — legado `vip: true` SEM prazo,
 * e legado com prazo ja VENCIDO — sao testados como se COMPORTAM HOJE, e nao como
 * alguem gostaria que se comportassem:
 *
 *   sem prazo   MIG-04: nao migra, e e contado em `semPrazo`.
 *   vencido     MIG-05: migra como `expirado`, sem conceder acesso.
 *
 * Escolher entre "dar cortesia" e "nao migrar" para o primeiro caso depende de
 * saber quantos jogadores estao nele, e esse diagnostico e um gate posterior.
 * O papel destes testes e impedir que o comportamento mude por acidente ANTES
 * da decisao comercial — nao antecipa-la.
 *
 * NADA AQUI EXECUTA MIGRACAO REAL: o banco e o Firestore falso, em memoria.
 */

'use strict';

const test = require('node:test');
const assert = require('node:assert');

const { migrarPaginaDeLegado, LOTE_MAXIMO } = require('../migracaoLegado');
const { ESTADO, decidirAtualizacao } = require('../entitlement');
const { FirestoreFalso, FieldPathFalso } = require('./apoio/firestore_falso');

const AGORA = '2026-08-15T12:00:00.000Z';
const FUTURO = '2026-12-01T00:00:00.000Z';
const PASSADO = '2026-01-01T00:00:00.000Z';

/**
 * Um `aplicarProposta` que registra o que recebeu e obedece a mesma regra de
 * precedencia do store de verdade (`decidirAtualizacao`), inclusive
 * `legado_nao_sobrescreve`.
 *
 * Nao e um mock que devolve o que o teste manda: ele guarda o estado aplicado e
 * consulta a regra REAL para decidir se a proposta seguinte entra. E o que faz
 * MIG-06 e MIG-07 provarem alguma coisa.
 */
function criarAplicadorEspiao(existentes = {}) {
  const estado = { ...existentes };
  const recebidas = [];

  return {
    estado,
    recebidas,
    async aplicarProposta(proposta) {
      recebidas.push(proposta);
      const atual = estado[proposta.uid] || null;
      const decisao = decidirAtualizacao(atual, proposta);
      if (decisao.aplicar) {
        estado[proposta.uid] = { ...proposta };
      }
      return { aplicado: decisao.aplicar, motivo: decisao.motivo };
    },
  };
}

function migrar(db, aplicador, extras = {}) {
  return migrarPaginaDeLegado({
    db,
    FieldPath: FieldPathFalso,
    aplicarProposta: aplicador.aplicarProposta,
    ESTADO_VIP: ESTADO,
    agora: AGORA,
    ...extras,
  });
}

// ---------------------------------------------------------------------------

test('MIG-01 base sem legado nenhum: nada a fazer, e o cursor diz que acabou', async () => {
  const db = new FirestoreFalso();
  const aplicador = criarAplicadorEspiao();

  const r = await migrar(db, aplicador);

  assert.equal(r.examinados, 0);
  assert.equal(r.migrados, 0);
  assert.equal(r.cursor, null);
  assert.equal(aplicador.recebidas.length, 0);
});

test('MIG-02 usuario com vip:false nao e sequer examinado', async () => {
  const db = new FirestoreFalso();
  db.semear('usuarios/nao-vip', { vip: false, vipExpiraEm: FUTURO });
  db.semear('usuarios/sem-campo', { fichas: 100 });
  const aplicador = criarAplicadorEspiao();

  const r = await migrar(db, aplicador);

  // O filtro e da consulta: quem nunca foi VIP nao entra na migracao.
  assert.equal(r.examinados, 0);
  assert.equal(aplicador.recebidas.length, 0);
});

test('MIG-03 vip:true com prazo VALIDO migra como ativo', async () => {
  const db = new FirestoreFalso();
  db.semear('usuarios/pagante', {
    vip: true,
    vipExpiraEm: FUTURO,
    vipProdutoId: 'vip_assinatura',
  });
  const aplicador = criarAplicadorEspiao();

  const r = await migrar(db, aplicador);

  assert.equal(r.examinados, 1);
  assert.equal(r.migrados, 1);
  assert.equal(r.semPrazo, 0);

  const p = aplicador.recebidas[0];
  assert.equal(p.estado, ESTADO.ATIVO);
  assert.equal(p.vipAtivo, true);
  assert.equal(p.expiraEm, FUTURO);
  assert.equal(p.produtoId, 'vip_assinatura');
  assert.equal(p.origem, 'legado_usuarios');
  // Sem token: nao existe, em lugar nenhum desta arvore, o valor com que se
  // perguntaria a Play sobre esta compra.
  assert.equal(p.purchaseTokenHash, null);
  // O legado nao registra se a renovacao estava ligada. `false` nao promete nada.
  assert.equal(p.renovacaoAutomatica, false);
  assert.equal(p.inicioEm, null);
});

test('MIG-04 vip:true SEM prazo nao migra, e o caso e CONTADO', async () => {
  const db = new FirestoreFalso();
  db.semear('usuarios/sem-prazo', { vip: true });
  db.semear('usuarios/prazo-vazio', { vip: true, vipExpiraEm: '' });
  db.semear('usuarios/prazo-nulo', { vip: true, vipExpiraEm: null });
  const aplicador = criarAplicadorEspiao();

  const r = await migrar(db, aplicador);

  // COMPORTAMENTO DE HOJE, registrado e nao decidido: sem prazo nao da para
  // afirmar que o direito vale, e o codebase inteiro recusa na duvida. Se a
  // decisao comercial for outra depois do diagnostico da base, e aqui que ela
  // aparece — este teste falha de proposito nesse dia.
  assert.equal(r.examinados, 3);
  assert.equal(r.migrados, 0);
  assert.equal(r.semPrazo, 3);
  assert.equal(aplicador.recebidas.length, 0, 'nem chega a propor');
});

test('MIG-05 vip:true com prazo VENCIDO migra como expirado, sem conceder', async () => {
  const db = new FirestoreFalso();
  db.semear('usuarios/vencido', { vip: true, vipExpiraEm: PASSADO });
  const aplicador = criarAplicadorEspiao();

  const r = await migrar(db, aplicador);

  // Tambem comportamento de hoje: o documento passa a existir e a contar a
  // verdade, em vez de nao existir. Ninguem ganha acesso com isso.
  assert.equal(r.migrados, 1);
  const p = aplicador.recebidas[0];
  assert.equal(p.estado, ESTADO.EXPIRADO);
  assert.equal(p.vipAtivo, false);
  // O prazo NAO e reescrito: ele e o fato que produziu a conclusao.
  assert.equal(p.expiraEm, PASSADO);
});

test('MIG-06 `legado_nao_sobrescreve`: quem ja tem direito verificado nao e tocado', async () => {
  const db = new FirestoreFalso();
  db.semear('usuarios/ja-migrado', { vip: true, vipExpiraEm: PASSADO });

  // O jogador ja tem entitlement vindo da Play, verificado DEPOIS.
  const aplicador = criarAplicadorEspiao({
    'ja-migrado': {
      uid: 'ja-migrado',
      estado: ESTADO.ATIVO,
      vipAtivo: true,
      expiraEm: FUTURO,
      origem: 'play',
      verificadoEm: '2026-08-14T00:00:00.000Z',
    },
  });

  const r = await migrar(db, aplicador);

  assert.equal(r.examinados, 1);
  assert.equal(r.migrados, 0);
  assert.equal(r.jaTinham, 1, 'a proposta foi feita e RECUSADA pela regra');

  // E o direito bom continua de pe: a migracao nao rebaixou um assinante
  // pagante para o prazo velho do legado.
  assert.equal(aplicador.estado['ja-migrado'].origem, 'play');
  assert.equal(aplicador.estado['ja-migrado'].expiraEm, FUTURO);
});

test('MIG-07 executar a migracao DUAS vezes nao muda o resultado', async () => {
  const db = new FirestoreFalso();
  db.semear('usuarios/a', { vip: true, vipExpiraEm: FUTURO });
  db.semear('usuarios/b', { vip: true, vipExpiraEm: PASSADO });
  db.semear('usuarios/c', { vip: true });
  const aplicador = criarAplicadorEspiao();

  const primeira = await migrar(db, aplicador);
  const estadoApos1 = JSON.parse(JSON.stringify(aplicador.estado));

  const segunda = await migrar(db, aplicador);

  assert.equal(primeira.migrados, 2);
  assert.equal(segunda.migrados, 0, 'a segunda passagem nao aplica nada novo');
  assert.equal(segunda.jaTinham, 2);
  assert.equal(segunda.semPrazo, 1);
  assert.deepEqual(aplicador.estado, estadoApos1, 'o estado final e o mesmo');
});

test('MIG-08 registro incompleto nao derruba a pagina', async () => {
  const db = new FirestoreFalso();
  db.semear('usuarios/a', { vip: true, vipExpiraEm: FUTURO });
  db.semear('usuarios/b', { vip: true, vipExpiraEm: 'nao-e-data' });
  db.semear('usuarios/c', { vip: true, vipExpiraEm: FUTURO, vipProdutoId: null });
  const aplicador = criarAplicadorEspiao();

  const r = await migrar(db, aplicador);

  // A data ilegivel cai em `semPrazo` — `instante()` devolve `null` para o que
  // nao consegue interpretar, e a duvida recusa.
  assert.equal(r.examinados, 3);
  assert.equal(r.migrados, 2);
  assert.equal(r.semPrazo, 1);
});

// ---------------------------------------------------------------------------
// Paginacao da migracao

test('MIG-09 a pagina cheia devolve cursor; a incompleta devolve null', async () => {
  const db = new FirestoreFalso();
  for (let i = 0; i < 7; i += 1) {
    db.semear(`usuarios/u-${String(i).padStart(3, '0')}`, {
      vip: true,
      vipExpiraEm: FUTURO,
    });
  }
  const aplicador = criarAplicadorEspiao();

  const p1 = await migrar(db, aplicador, { lote: 3 });
  assert.equal(p1.examinados, 3);
  assert.ok(p1.cursor, 'pagina cheia: ha mais');

  const p2 = await migrar(db, aplicador, { lote: 3, cursor: p1.cursor });
  assert.equal(p2.examinados, 3);
  assert.ok(p2.cursor);

  const p3 = await migrar(db, aplicador, { lote: 3, cursor: p2.cursor });
  assert.equal(p3.examinados, 1);
  assert.equal(p3.cursor, null, 'pagina incompleta: acabou');

  assert.equal(Object.keys(aplicador.estado).length, 7, 'todos migrados');
});

test('MIG-10 as paginas nao se sobrepoem', async () => {
  const db = new FirestoreFalso();
  for (let i = 0; i < 10; i += 1) {
    db.semear(`usuarios/u-${String(i).padStart(3, '0')}`, {
      vip: true,
      vipExpiraEm: FUTURO,
    });
  }
  const aplicador = criarAplicadorEspiao();

  let cursor = null;
  do {
    const r = await migrar(db, aplicador, { lote: 4, cursor });
    cursor = r.cursor;
  } while (cursor);

  const uids = aplicador.recebidas.map((p) => p.uid);
  assert.equal(uids.length, 10);
  assert.equal(new Set(uids).size, 10, 'nenhum uid proposto duas vezes');
});

test('MIG-11 o lote pedido pelo cliente e limitado', async () => {
  const db = new FirestoreFalso();
  for (let i = 0; i < 5; i += 1) {
    db.semear(`usuarios/u-${i}`, { vip: true, vipExpiraEm: FUTURO });
  }
  const aplicador = criarAplicadorEspiao();

  // Um cliente pedindo a colecao inteira de uma vez nao consegue.
  const r = await migrar(db, aplicador, { lote: 100000 });
  assert.equal(r.examinados, 5);
  // Com 5 documentos e teto de 400, a pagina veio incompleta: acabou.
  assert.equal(r.cursor, null);
  assert.ok(LOTE_MAXIMO <= 400);
});
