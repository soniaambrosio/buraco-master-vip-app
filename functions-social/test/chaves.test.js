// chaves.test.js — a TRAVA DE VAZAMENTO e a leitura dos documentos canonicos.
//
// Roda sobre `lib/chaves.js` JA COMPILADO (por isso o script `test` faz `tsc`
// antes), e nao sobre o fonte: o alvo do teste e o que vai para producao.
//
// Nao precisa do emulador nem do `domain_bundle.js`: `chaves.ts` e puro de
// proposito, exatamente para que esta suite possa rodar com `node --test` num
// portao de CI que nao tem Java nem Dart. Mesma disciplina de
// `functions-moderacao/test/idempotencia.test.js`.

'use strict';

const assert = require('node:assert/strict');
const { test, describe } = require('node:test');

const {
  CHAVES_PROIBIDAS,
  VazamentoPublico,
  caminhosProibidos,
  entradaPublica,
  exigirRespostaSegura,
  lerContadores,
  lerRelacao,
  C_AMIZADES,
  C_IDENTIDADES,
  C_INDICE_PUBLICO,
  C_PERFIS_PUBLICOS,
} = require('../lib/chaves.js');

const PUBLIC_ID = 'P0123456789AB';
const UID_A = 'uidJogadorA';
const UID_B = 'uidJogadorB';

describe('trava de vazamento (§21, §31-F)', () => {
  test('resposta limpa passa inalterada', () => {
    const resposta = {
      perfil: { publicId: PUBLIC_ID, apelido: 'Maria', avatarRef: null, desde: null },
      relacao: 'amigos',
      acoes: ['removerAmigo', 'bloquear'],
    };
    assert.deepEqual(exigirRespostaSegura(resposta), resposta);
  });

  test('UID no topo da resposta e barrado', () => {
    assert.throws(
      () => exigirRespostaSegura({ publicId: PUBLIC_ID, uid: UID_A }),
      VazamentoPublico,
    );
  });

  test('UID ANINHADO e barrado — que e onde o vazamento real mora', () => {
    // O acidente tipico: alguem espalha a relacao canonica dentro da resposta
    // ("...relacao") e leva `membros`, que sao UIDs, um nivel abaixo de onde
    // qualquer revisao olharia.
    const resposta = {
      perfil: { publicId: PUBLIC_ID, apelido: 'Maria' },
      relacao: { estado: 'amigos', membros: [UID_A, UID_B] },
    };
    assert.throws(() => exigirRespostaSegura(resposta), (e) => {
      assert.ok(e instanceof VazamentoPublico);
      assert.deepEqual(e.caminhos, ['relacao.membros']);
      return true;
    });
  });

  test('UID dentro de LISTA de itens e barrado', () => {
    const resposta = {
      itens: [
        { publicId: PUBLIC_ID, apelido: 'Maria' },
        { publicId: 'PCDEFGHJKMNPQ', apelido: 'Bia', userId: UID_B },
      ],
    };
    assert.throws(() => exigirRespostaSegura(resposta), (e) => {
      assert.deepEqual(e.caminhos, ['itens[1].userId']);
      return true;
    });
  });

  test('e-mail, Billing, moderacao e denuncia sao barrados', () => {
    for (const chave of [
      'email',
      'telefone',
      'providerId',
      'claims',
      'vip',
      'billing',
      'entitlement',
      'assinatura',
      'fichas',
      'reports',
      'sanctions',
      'playerModeration',
      'suspensoAte',
      'cpf',
    ]) {
      assert.throws(
        () => exigirRespostaSegura({ perfil: { [chave]: 'x' } }),
        VazamentoPublico,
        `${chave} tinha que ser barrado`,
      );
    }
  });

  test('os campos internos da relacao canonica sao todos proibidos', () => {
    // Sao os quatro que uma resposta descuidada carregaria junto com o estado.
    for (const chave of ['pairKey', 'membros', 'solicitanteUid', 'destinatarioUid', 'publicIds']) {
      assert.ok(CHAVES_PROIBIDAS.has(chave), `${chave} precisa estar na lista`);
    }
  });

  test('publicId, apelido e avatarRef NAO sao proibidos', () => {
    // A contrapartida: a trava nao pode ser tao larga que impeca a resposta de
    // ter conteudo.
    for (const chave of ['publicId', 'apelido', 'avatarRef', 'desde', 'relacao', 'acoes']) {
      assert.ok(!CHAVES_PROIBIDAS.has(chave), `${chave} nao pode estar na lista`);
    }
  });

  test('caminhosProibidos aguenta null, primitivo e vazio sem estourar', () => {
    assert.deepEqual(caminhosProibidos(null), []);
    assert.deepEqual(caminhosProibidos(42), []);
    assert.deepEqual(caminhosProibidos('texto'), []);
    assert.deepEqual(caminhosProibidos({}), []);
    assert.deepEqual(caminhosProibidos([]), []);
  });
});

describe('entradaPublica: o UID nunca vira fallback (§31-F)', () => {
  test('perfil completo e projetado inteiro', () => {
    const e = entradaPublica(
      { publicId: PUBLIC_ID, apelido: 'Maria', avatarRef: 'coruja_dourada' },
      PUBLIC_ID,
      '2026-01-01T00:00:00.000Z',
    );
    assert.deepEqual(e, {
      publicId: PUBLIC_ID,
      apelido: 'Maria',
      avatarRef: 'coruja_dourada',
      desde: '2026-01-01T00:00:00.000Z',
    });
  });

  test('perfil ausente devolve apelido VAZIO, nunca o uid', () => {
    const e = entradaPublica(undefined, PUBLIC_ID, null);
    assert.equal(e.apelido, '');
    assert.equal(e.avatarRef, null);
    assert.equal(e.publicId, PUBLIC_ID);
    assert.equal(JSON.stringify(e).includes(UID_A), false);
  });

  test('a entrada tem exatamente quatro chaves', () => {
    const e = entradaPublica({ apelido: 'Bia' }, PUBLIC_ID, null);
    assert.deepEqual(Object.keys(e).sort(), ['apelido', 'avatarRef', 'desde', 'publicId']);
  });
});

describe('lerRelacao: a ausencia do documento tem forma', () => {
  test('documento ausente vira estado "nenhuma"', () => {
    const r = lerRelacao(undefined);
    assert.equal(r.estado, 'nenhuma');
    assert.equal(r.solicitanteUid, null);
    assert.deepEqual(r.membros, []);
    assert.deepEqual(r.publicIds, {});
  });

  test('estado desconhecido vira "nenhuma" em vez de passar adiante', () => {
    assert.equal(lerRelacao({ estado: 'bloqueada' }).estado, 'nenhuma');
    assert.equal(lerRelacao({ estado: 42 }).estado, 'nenhuma');
  });

  test('documento pendente e lido inteiro', () => {
    const r = lerRelacao({
      estado: 'pendente',
      solicitanteUid: UID_A,
      destinatarioUid: UID_B,
      solicitadaEm: '2026-01-01T00:00:00.000Z',
      membros: [UID_A, UID_B],
      publicIds: { [UID_A]: PUBLIC_ID, [UID_B]: 'PCDEFGHJKMNPQ', lixo: 7 },
    });
    assert.equal(r.estado, 'pendente');
    assert.equal(r.solicitanteUid, UID_A);
    assert.deepEqual(r.membros, [UID_A, UID_B]);
    assert.deepEqual(r.publicIds, { [UID_A]: PUBLIC_ID, [UID_B]: 'PCDEFGHJKMNPQ' });
  });

  test('membros nao-string sao descartados', () => {
    assert.deepEqual(lerRelacao({ membros: [UID_A, 42, null] }).membros, [UID_A]);
  });
});

describe('lerContadores: o zero e o padrao, e negativo nao passa', () => {
  test('documento ausente conta zero', () => {
    assert.deepEqual(lerContadores(undefined), { amigos: 0, solicitacoesEnviadas: 0 });
  });

  test('valor negativo ou absurdo e tratado como zero', () => {
    // Um contador negativo abriria o teto para sempre.
    assert.deepEqual(
      lerContadores({ amigos: -5, solicitacoesEnviadas: NaN }),
      { amigos: 0, solicitacoesEnviadas: 0 },
    );
    assert.deepEqual(
      lerContadores({ amigos: 'muitos', solicitacoesEnviadas: Infinity }),
      { amigos: 0, solicitacoesEnviadas: 0 },
    );
  });

  test('valor valido passa', () => {
    assert.deepEqual(
      lerContadores({ amigos: 12, solicitacoesEnviadas: 3 }),
      { amigos: 12, solicitacoesEnviadas: 3 },
    );
  });
});

describe('colecoes: os tres documentos de identidade sao separados', () => {
  test('cada papel tem a sua colecao', () => {
    // O documento PUBLICO e o mapa reverso nao podem ser o mesmo: o segundo
    // carrega uid, e regra do Firestore libera ou nega o documento inteiro.
    const nomes = [C_IDENTIDADES, C_INDICE_PUBLICO, C_PERFIS_PUBLICOS, C_AMIZADES];
    assert.equal(new Set(nomes).size, nomes.length);
    assert.equal(C_PERFIS_PUBLICOS, 'publicProfiles');
    assert.equal(C_INDICE_PUBLICO, 'publicIdIndex');
  });
});
