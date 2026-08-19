#!/usr/bin/env node
'use strict';
/**
 * GERADOR da proveniência. Roda no build, IMEDIATAMENTE ANTES do deploy.
 *
 *   uso: node ferramentas/proveniencia/gerar.js [--raiz <dir>]
 *
 * `--raiz` escolhe ONDE gerar, e nunca O QUÊ gerar. Não existe — e não pode
 * passar a existir — nenhuma forma de informar o SHA: ele sai de
 * `git rev-parse HEAD` na raiz escolhida, e mais nada. A recusa a qualquer
 * outro argumento e às variáveis de ambiente que "parecem" carregar versão está
 * logo abaixo, e é medida por PN-15 em `proveniencia.test.js`.
 *
 * A razão de recusar variável de ambiente é concreta: no GitHub Actions
 * `GITHUB_SHA` está SEMPRE definida, e num `pull_request` ela aponta para o
 * merge sintético — não para o commit que está sendo implantado. Aceitá-la
 * como atalho carimbaria o artefato com um SHA que não existe em lugar nenhum.
 */

const fs = require('node:fs');
const path = require('node:path');
const P = require('./proveniencia.js');

const AMBIENTE_PROIBIDO = [
  'PROVENIENCIA_SHA',
  'SHA',
  'GIT_SHA',
  'GITHUB_SHA',
  'COMMIT_SHA',
  'VERSAO',
  'VERSION',
];

function principal(argv) {
  let raiz = P.RAIZ;

  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === '--raiz') {
      raiz = path.resolve(argv[++i] || '');
      continue;
    }
    // FALHA FECHADO. Não há flag "desconhecida e inofensiva": a única forma de
    // um valor manual entrar aqui seria por uma flag que este laço tolerasse.
    throw new Error(
      `argumento nao aceito: ${JSON.stringify(argv[i])}. ` +
      'O SHA NAO e informavel — ele sai de `git rev-parse HEAD`.'
    );
  }

  const definidas = AMBIENTE_PROIBIDO.filter((k) => process.env[k] !== undefined);
  if (definidas.length > 0) {
    throw new Error(
      `variavel(is) de ambiente que poderiam ser confundidas com a origem do ` +
      `valor estao definidas: ${definidas.join(', ')}. ` +
      'Este gerador NAO as le, e recusa rodar com elas presentes para que ' +
      'ninguem conclua que leu. Desdefina-as antes do build.'
    );
  }

  if (P.arvoreSuja(raiz)) {
    throw new Error(
      'arvore com alteracao nao commitada: o SHA descreveria um codigo que nao ' +
      'e o do artefato. Commite ou limpe antes de gerar proveniencia.'
    );
  }

  const sha = P.shaDaArvore(raiz);
  const lista = P.codebases(raiz);

  for (const { codebase, source } of lista) {
    const destino = P.caminho(raiz, source);
    if (!fs.existsSync(path.dirname(destino))) {
      throw new Error(`source declarada em firebase.json nao existe no disco: ${source}`);
    }
    fs.writeFileSync(destino, P.conteudo({ sha, codebase, source }), 'utf8');
    console.log(`proveniencia: ${source}/${P.NOME_DO_ARQUIVO} -> ${sha}`);
  }

  console.log(`proveniencia: ${lista.length} codebase(s) carimbada(s) com ${sha}`);
  return 0;
}

if (require.main === module) {
  try {
    process.exit(principal(process.argv.slice(2)));
  } catch (e) {
    console.error(`gerar.js: ${e.message}`);
    process.exit(1);
  }
}

module.exports = { principal, AMBIENTE_PROIBIDO };
