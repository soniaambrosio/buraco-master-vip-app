// functions/test/plano_ativacao_completude.test.js — O PLANO NÃO PODE ENCOLHER.
//
// Este teste não prova comportamento de código. Ele existe por um motivo
// operacional: um roteiro de ativação perde utilidade em silêncio. Alguém
// "limpa" a documentação, apaga o bloco de rollback ou o smoke negativo, e o
// documento continua parecendo completo — até a janela operacional, quando falta
// justamente a metade que ninguém leu.
//
// Cada asserção aqui corresponde a uma linha da tabela de completude do §15 do
// plano. Se um bloco sumir, esta suíte fica vermelha e diz QUAL sumiu.
//
// Não valida prosa: valida a presença dos blocos, dos passos numerados e dos
// invariantes que não podem desaparecer sem alguém decidir explicitamente.

'use strict';

const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const PLANO = path.resolve(
  __dirname,
  '..',
  '..',
  'docs',
  'PLANO-ATIVACAO-CONTROLADA-CREDENCIAL-MOTOR-V1.md'
);

const texto = fs.readFileSync(PLANO, 'utf8');

/// Os doze blocos do §15. Cada um tem um marcador que só existe se o bloco
/// existir de verdade — não basta a palavra aparecer numa tabela de índice.
const BLOCOS = [
  ['pré-condição', /##\s*2\.\s*A pré-condição que bloqueia/],
  ['ativação', /##\s*5\.\s*Sequência de ativação/],
  ['smoke positivo', /##\s*6\.\s*Smoke positivo/],
  ['smoke negativo', /##\s*7\.\s*Smoke negativo/],
  ['revogação', /Passo 13 — Revogação de teste/],
  ['rotação', /Passo 15 — A credencial nova volta a funcionar/],
  ['vazamento', /##\s*9\.\s*Vazamento/],
  ['rollback', /##\s*11\.\s*Rollback/],
  ['censo', /Passo 1 — Censo ANTES/],
  ['logs', /##\s*8\.\s*Logs/],
  ['limpeza', /Passo 11 — Limpeza/],
  ['PASS final', /##\s*16\.\s*PASS final da janela/],
];

for (const [nome, marcador] of BLOCOS) {
  test('bloco obrigatório presente: ' + nome, () => {
    assert.match(texto, marcador, 'o bloco "' + nome + '" sumiu do plano');
  });
}

test('os 15 passos da sequência existem, e em ordem', () => {
  const encontrados = [...texto.matchAll(/###\s*Passo\s+(\d+)\s+—/g)].map((m) => Number(m[1]));
  assert.deepEqual(
    encontrados,
    [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15],
    'a sequência de ativação tem de ter os 15 passos, sem buraco e sem troca de ordem'
  );
});

test('cada smoke negativo obrigatório está previsto', () => {
  for (const caso of [
    'sem claim',
    'claim truthy inválido',
    'token expirado',
    'sessão revogada',
    'UID divergente',
    'bearer ausente/malformado',
    'credencial antiga após rotação',
  ]) {
    assert.ok(texto.includes(caso), 'smoke negativo ausente: ' + caso);
  }
});

test('a resposta a vazamento mantém os seis tempos', () => {
  for (const t of ['T+0', 'T+1', 'T+2', 'T+3', 'T+4', 'T+5']) {
    assert.ok(texto.includes(t), 'tempo ausente na resposta a vazamento: ' + t);
  }
});

test('o rollback cobre os nove cenários da OS', () => {
  for (const cenario of [
    'variável do Railway errada',
    'token não obtido',
    'chamada recusada',
    'identidade errada',
    'log suspeito',
    'credencial vazada',
    'revogação acidental',
    'servidor não inicializa',
    'receptor indisponível',
  ]) {
    assert.ok(texto.includes(cenario), 'cenário de rollback ausente: ' + cenario);
  }
});

test('a armadilha do revokeRefreshTokens continua escrita, e com a reemissão posicionada', () => {
  assert.match(texto, /derruba a identidade INTEIRA/i);
  assert.match(texto, /revogar antiga\s*→\s*descobrir que revogou a nova junto/);
  assert.match(
    texto,
    /reemissão é \*\*passo obrigatório do roteiro\*\*/,
    'sem isto, alguém trata a reemissão como opcional e fica sem credencial'
  );
});

test('o checklist de padrões proibidos em log não encolheu', () => {
  for (const padrao of ['refresh token', 'ID token', 'custom token', 'ya29', 'Authorization:', 'PRIVATE KEY']) {
    assert.ok(texto.includes(padrao), 'padrão proibido sumiu do checklist de log: ' + padrao);
  }
});

test('os critérios de ABORT continuam presentes', () => {
  for (const criterio of [
    'SHA operacional diferente',
    'credencial desconhecida',
    'identidade **não documentada**',
    'fora** da lista permitida',
    'continuar autorizando',
    'alteração de código',
    'PROJETO_DIVERGENTE',
  ]) {
    assert.ok(texto.includes(criterio), 'critério de ABORT ausente: ' + criterio);
  }
});

test('nenhum segredo real foi escrito no plano', () => {
  // O plano é público dentro do repositório. Um valor real aqui é o mesmo
  // acidente que o bootstrap existe para evitar.
  const proibidos = [
    /AIza[0-9A-Za-z_-]{30,}/,
    /ya29\.[0-9A-Za-z_-]{20,}/,
    /-----BEGIN [A-Z ]*PRIVATE KEY/,
    /"private_key"\s*:/,
  ];
  for (const p of proibidos) {
    assert.equal(p.test(texto), false, 'o plano parece conter segredo real: ' + p);
  }
});

test('os SHAs de entrada estão registrados por extenso', () => {
  assert.ok(texto.includes('c3d6ab98795ca49deaaa9e2e974c95d07bfe8467'), 'SHA do app ausente');
  assert.ok(texto.includes('c8ab95c427cfb66d3cd6d6c991a3ff617b45a637'), 'SHA do servidor ausente');
});

test('o plano continua declarando que não ativa nada', () => {
  assert.match(texto, /Este documento não ativa nada/);
  assert.match(texto, /BLOCKED — PRÉ-CONDIÇÃO OPERACIONAL NÃO COMPROVADA/);
});
