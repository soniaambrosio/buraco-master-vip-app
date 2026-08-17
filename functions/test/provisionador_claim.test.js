// provisionador_claim.test.js — a DECISÃO do provisionador, sem rede.
//
// Cobre o que não precisa de emulador: análise de argumentos, plano de mutação,
// preservação de claims alheios, idempotência e redação da saída. A prova de
// propagação do token (concessão → token novo → autorização) é integrada e vive
// em `provisionador_claim_integrado.test.js`.
//
// Uso:
//   cd functions && npm run test:provisionador

'use strict';

const { test, describe } = require('node:test');
const assert = require('node:assert/strict');

const prov = require('../scripts/provisionar_claim_motor_partidas.js');
const { analisarArgumentos, planejarMutacao, verificarResultado, mascararUid, CLAIM } = prov;

/** Os argumentos de um grant válido, para cada teste alterar só o que importa. */
const OK = ['grant', '--project', 'bmv-teste', '--uid', 'uid-motor'];

// ===========================================================================
describe('PROV/ARGUMENTOS', () => {
  test('ARG-01: ensaio é o padrão — sem --commit, commit é falso', () => {
    const a = analisarArgumentos(OK);
    assert.equal(a.erro, undefined);
    assert.equal(a.commit, false, 'o padrão seguro é NÃO escrever');
    assert.equal(a.operacao, 'grant');
    assert.equal(a.projectId, 'bmv-teste');
    assert.equal(a.uid, 'uid-motor');
  });

  test('ARG-02: operação desconhecida é recusada', () => {
    for (const op of ['conceder', 'GRANT', '', 'drop', undefined]) {
      const a = analisarArgumentos([op, '--project', 'bmv-teste', '--uid', 'u']);
      assert.ok(a.erro, 'operação "' + op + '" não podia ser aceita');
    }
  });

  test('ARG-03: --project e --uid são obrigatórios', () => {
    assert.ok(analisarArgumentos(['grant', '--uid', 'u']).erro);
    assert.ok(analisarArgumentos(['grant', '--project', 'bmv-teste']).erro);
  });

  test('ARG-04: projeto com forma inválida é recusado antes de qualquer SDK', () => {
    for (const p of ['BMV-Teste', 'bmv teste', 'bmv/teste', 'ab', '../outro', '-bmv']) {
      const a = analisarArgumentos(['grant', '--project', p, '--uid', 'u']);
      assert.ok(a.erro, 'projeto "' + p + '" não podia passar');
    }
  });

  test('ARG-05: --commit exige --confirmar-projeto idêntico (dupla digitação)', () => {
    assert.ok(analisarArgumentos([...OK, '--commit']).erro,
      'sem confirmação, gravar não pode ser permitido');
    assert.ok(analisarArgumentos([...OK, '--commit', '--confirmar-projeto', 'bmv-producao']).erro,
      'confirmação divergente é justamente o acidente que se quer impedir');
    const bom = analisarArgumentos([...OK, '--commit', '--confirmar-projeto', 'bmv-teste']);
    assert.equal(bom.erro, undefined);
    assert.equal(bom.commit, true);
  });

  test('ARG-06: inspect nunca aceita --commit', () => {
    const a = analisarArgumentos(['inspect', '--project', 'bmv-teste', '--uid', 'u',
      '--commit', '--confirmar-projeto', 'bmv-teste']);
    assert.ok(a.erro, 'inspect não escreve; aceitar a flag ensinaria que ela é inofensiva');
  });
});

// ===========================================================================
describe('PROV/PLANO', () => {
  test('PLA-01: grant em quem não tem nada concede', () => {
    const p = planejarMutacao('grant', {});
    assert.equal(p.acao, 'escrever');
    assert.equal(p.resultado, 'concedido');
    assert.equal(p.claimsFinais[CLAIM], true);
    assert.equal(typeof p.claimsFinais[CLAIM], 'boolean', 'tem de ser BOOLEANO, não string');
  });

  test('PLA-02: grant repetido não escreve — idempotente', () => {
    const p = planejarMutacao('grant', { [CLAIM]: true });
    assert.equal(p.acao, 'nenhuma');
    assert.equal(p.resultado, 'ja_concedido');
    assert.equal(p.claimsFinais, null);
  });

  test('PLA-03: revoke remove a chave em vez de gravar false', () => {
    const p = planejarMutacao('revoke', { [CLAIM]: true });
    assert.equal(p.acao, 'escrever');
    assert.equal(p.resultado, 'revogado');
    assert.equal(Object.prototype.hasOwnProperty.call(p.claimsFinais, CLAIM), false,
      'revogar deixa o mapa limpo, e não uma lápide `false`');
  });

  test('PLA-04: revoke repetido não escreve — idempotente', () => {
    const p = planejarMutacao('revoke', { admin: true });
    assert.equal(p.acao, 'nenhuma');
    assert.equal(p.resultado, 'ja_revogado');
  });

  test('PLA-05: claims alheios são PRESERVADOS, e só o alvo muda', () => {
    const antes = { admin: true, suporte: true, pioneiro: 'ouro', [CLAIM]: false };
    const p = planejarMutacao('grant', antes);
    assert.deepEqual(p.claimsFinais, {
      admin: true, suporte: true, pioneiro: 'ouro', [CLAIM]: true,
    }, 'setCustomUserClaims SOBRESCREVE o mapa: perder admin aqui seria remover uma permissão real');
    assert.deepEqual(p.preservados, ['admin', 'pioneiro', 'suporte']);
    assert.deepEqual(antes[CLAIM], false, 'o mapa de entrada não pode ser mutado');
  });

  test('PLA-06: revoke também preserva o resto', () => {
    const p = planejarMutacao('revoke', { admin: true, [CLAIM]: true });
    assert.deepEqual(p.claimsFinais, { admin: true });
  });

  test('PLA-07: claim com TIPO ERRADO é corrigido, não aceito', () => {
    // É o estrago que um provisionamento manual produz. A guarda exige `=== true`,
    // então nenhum destes autoriza — e todos precisam ser reescritos.
    for (const ruim of ['true', 1, '1', 'sim', false, null, 0]) {
      const p = planejarMutacao('grant', { [CLAIM]: ruim });
      assert.equal(p.acao, 'escrever',
        'valor ' + JSON.stringify(ruim) + ' não autoriza e tinha de ser corrigido');
      assert.equal(p.claimsFinais[CLAIM], true);
    }
  });

  test('PLA-08: inspect nunca produz escrita', () => {
    for (const claims of [{}, { [CLAIM]: true }, { [CLAIM]: 'true' }, { admin: true }]) {
      assert.equal(planejarMutacao('inspect', claims).acao, 'nenhuma');
      assert.equal(planejarMutacao('inspect', claims).claimsFinais, null);
    }
  });

  test('PLA-09: inspect relata autorização por BOOLEANO, não por presença', () => {
    assert.equal(planejarMutacao('inspect', { [CLAIM]: true }).resultado, 'concedido');
    assert.equal(planejarMutacao('inspect', { [CLAIM]: 'true' }).resultado, 'ausente');
    assert.equal(planejarMutacao('inspect', { [CLAIM]: false }).resultado, 'ausente');
    assert.equal(planejarMutacao('inspect', {}).resultado, 'ausente');
  });

  test('PLA-10: claims ausentes ou malformados não derrubam o plano', () => {
    for (const nada of [null, undefined, 'texto', 42]) {
      const p = planejarMutacao('grant', nada);
      assert.equal(p.acao, 'escrever');
      assert.equal(p.claimsFinais[CLAIM], true);
    }
  });
});

// ===========================================================================
describe('PROV/VERIFICACAO', () => {
  test('VER-01: grant só passa se o claim ficou booleano true', () => {
    assert.equal(verificarResultado('grant', { [CLAIM]: true }).ok, true);
    for (const ruim of [{}, { [CLAIM]: 'true' }, { [CLAIM]: 1 }, { [CLAIM]: false }]) {
      assert.equal(verificarResultado('grant', ruim).ok, false);
    }
  });

  test('VER-02: revoke só passa se o claim parou de autorizar', () => {
    assert.equal(verificarResultado('revoke', {}).ok, true);
    assert.equal(verificarResultado('revoke', { admin: true }).ok, true);
    assert.equal(verificarResultado('revoke', { [CLAIM]: true }).ok, false);
  });
});

// ===========================================================================
describe('PROV/REDACAO', () => {
  test('RED-01: o UID sai mascarado, e o suficiente para conferir', () => {
    const m = mascararUid('motor-de-partidas-9f3a71');
    assert.equal(m.includes('motor-de-partidas-9f3a71'), false, 'o uid inteiro não pode sair');
    assert.match(m, /^moto….{2}$/);
  });

  test('RED-02: uid curto e uid vazio não vazam nem quebram', () => {
    assert.equal(mascararUid(''), '(vazio)');
    assert.equal(mascararUid(null), '(vazio)');
    assert.equal(mascararUid('abc').includes('b'), false);
  });

  test('RED-03: nada no módulo carrega segredo, token ou chave', () => {
    const fonte = require('node:fs')
      .readFileSync(require.resolve('../scripts/provisionar_claim_motor_partidas.js'), 'utf8');
    for (const proibido of ['BEGIN PRIVATE KEY', 'private_key', 'serviceAccount.json',
      'AIza', 'Bearer ', 'client_secret', 'refresh_token']) {
      assert.equal(fonte.includes(proibido), false,
        'o provisionador não pode conter `' + proibido + '`');
    }
  });
});
