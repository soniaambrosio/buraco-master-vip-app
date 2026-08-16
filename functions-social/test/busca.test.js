// busca.test.js — a PROJECAO do resultado de busca, sobre o modulo puro.
//
// Roda sobre `lib/chaves.js` JA COMPILADO, como `chaves.test.js`, e pelo mesmo
// motivo: o alvo do teste e o que vai para producao. Nao precisa de emulador nem
// de `domain_bundle.js` — a decisao (o que e um termo valido, quem e filtrado
// pelo bloqueio) mora no dominio Dart e e provada em
// `app/test/social/busca_apelido_test.dart`. O que se prova AQUI e a ultima
// camada antes do fio: o resultado nao carrega nada alem do que foi autorizado.
//
// A DIVISAO DE PROVA DESTA OS, para nao haver dupla contagem:
//
//   Dart puro ............ normalizacao, limites, filtro de bloqueio, relacao
//   Node puro (aqui) ..... a forma da resposta e a trava de vazamento
//   Emulator Suite ....... regras, indice, chamada real e ausencia de UID no fio

'use strict';

const assert = require('node:assert/strict');
const { test, describe } = require('node:test');

const {
  CAMPOS_DO_RESULTADO,
  VazamentoPublico,
  entradaDeBusca,
  exigirRespostaSegura,
} = require('../lib/chaves.js');

const PUBLIC_ID = 'P0123456789AB';
const OUTRO_ID = 'PCDEFGHJKMNPQ';
const UID = 'uidJogadorA';

const perfilCompleto = {
  publicId: PUBLIC_ID,
  apelido: 'Dona Maria',
  apelidoOrdenacao: 'dona maria',
  avatarRef: 'coruja_dourada',
  estado: 'ativo',
  criadoEm: '2026-01-01T00:00:00.000Z',
  atualizadoEm: '2026-02-01T00:00:00.000Z',
  esquema: 1,
};

describe('entradaDeBusca: a allowlist da resposta (§7)', () => {
  test('o resultado tem EXATAMENTE os campos declarados', () => {
    const e = entradaDeBusca(perfilCompleto, PUBLIC_ID, 'nenhuma', [
      'adicionarAmigo',
      'bloquear',
    ]);
    assert.deepEqual(Object.keys(e).sort(), [...CAMPOS_DO_RESULTADO].sort());
    assert.deepEqual(e, {
      publicId: PUBLIC_ID,
      apelido: 'Dona Maria',
      avatarRef: 'coruja_dourada',
      relacao: 'nenhuma',
      acoes: ['adicionarAmigo', 'bloquear'],
    });
  });

  test('os campos INTERNOS do perfil publico nao viajam', () => {
    // Nenhum deles e privado — e nenhum deles e assunto de quem procura.
    // `apelidoOrdenacao` e a chave de busca (detalhe de indice),
    // `estado` so pode ser 'ativo' aqui (a consulta ja filtrou), e `esquema` e
    // versao de documento. Copiar o perfil inteiro entregaria os quatro sem
    // que ninguem tivesse decidido isso.
    const e = entradaDeBusca(perfilCompleto, PUBLIC_ID, 'nenhuma', []);
    for (const interno of [
      'apelidoOrdenacao',
      'estado',
      'criadoEm',
      'atualizadoEm',
      'esquema',
      'desde',
    ]) {
      assert.equal(e[interno], undefined, `${interno} vazou no resultado`);
    }
  });

  test('perfil ausente vira apelido VAZIO, nunca o publicId no lugar do nome', () => {
    const e = entradaDeBusca(undefined, PUBLIC_ID, 'nenhuma', []);
    assert.equal(e.apelido, '');
    assert.equal(e.avatarRef, null);
    assert.equal(e.publicId, PUBLIC_ID);
  });

  test('o publicId conhecido prevalece quando o documento discorda', () => {
    // O ID DO DOCUMENTO e a identidade; um campo `publicId` divergente dentro
    // dele seria dado corrompido. A entrada usa o do documento quando ele e
    // string — mesma tolerancia de `entradaPublica` — e o conhecido quando nao.
    const e = entradaDeBusca({ apelido: 'Bia' }, OUTRO_ID, 'amigos', []);
    assert.equal(e.publicId, OUTRO_ID);
  });

  test('a lista de acoes e COPIADA, e nao compartilhada', () => {
    // O dominio devolve a mesma lista para varios resultados quando a relacao e
    // igual. Guardar a referencia faria uma mutacao acidental num item
    // reescrever a acao de todos os outros.
    const acoes = ['adicionarAmigo'];
    const e = entradaDeBusca(perfilCompleto, PUBLIC_ID, 'nenhuma', acoes);
    acoes.push('bloquear');
    assert.deepEqual(e.acoes, ['adicionarAmigo']);
  });

  test('apelido nao-string nao vira o valor bruto', () => {
    for (const lixo of [42, null, {}, ['Maria']]) {
      const e = entradaDeBusca({ apelido: lixo }, PUBLIC_ID, 'nenhuma', []);
      assert.equal(e.apelido, '', `${JSON.stringify(lixo)} passou como apelido`);
    }
  });
});

describe('a trava de vazamento vale para a busca (§3, §7)', () => {
  test('uma pagina de resultados limpa passa inalterada', () => {
    const resposta = {
      itens: [
        entradaDeBusca(perfilCompleto, PUBLIC_ID, 'amigos', ['removerAmigo']),
        entradaDeBusca({ apelido: 'Bia' }, OUTRO_ID, 'nenhuma', ['bloquear']),
      ],
      truncado: false,
      modo: 'prefixo',
    };
    assert.deepEqual(exigirRespostaSegura(resposta), resposta);
    assert.equal(JSON.stringify(resposta).includes(UID), false);
  });

  test('UID dentro de UM item da pagina derruba a resposta inteira', () => {
    // O acidente concreto que esta trava pega: alguem acrescenta o uid ao item
    // "so para depurar" e a busca passa a publicar identidade interna de todo
    // jogador que aparecer num resultado.
    const resposta = {
      itens: [
        entradaDeBusca(perfilCompleto, PUBLIC_ID, 'amigos', []),
        { ...entradaDeBusca({ apelido: 'Bia' }, OUTRO_ID, 'nenhuma', []), uid: UID },
      ],
    };
    assert.throws(() => exigirRespostaSegura(resposta), (e) => {
      assert.ok(e instanceof VazamentoPublico);
      assert.deepEqual(e.caminhos, ['itens[1].uid']);
      return true;
    });
  });

  test('espalhar o perfil do candidato na resposta e barrado se ele tiver uid', () => {
    // `publicProfiles` nao tem uid hoje. Se um dia tiver — por defeito de
    // escrita ou por documento semeado a mao —, a busca nao o repassa.
    const respostaSuja = { itens: [{ ...perfilCompleto, uid: UID }] };
    assert.throws(() => exigirRespostaSegura(respostaSuja), VazamentoPublico);
  });

  test('a resposta de busca nao tem cursor, e isso e verificavel', () => {
    // §9: a ausencia de paginacao e a decisao antienumeracao. Uma ausencia nao
    // aparece num diff; este teste e o lugar onde ela e afirmada do lado do
    // servidor. O par no dominio e `LIM-05`.
    const resposta = { itens: [], truncado: false, modo: 'prefixo' };
    assert.deepEqual(Object.keys(resposta).sort(), ['itens', 'modo', 'truncado']);
    assert.equal('cursor' in resposta, false);
    assert.equal('proximoCursor' in resposta, false);
  });
});
