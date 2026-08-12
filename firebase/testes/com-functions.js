// com-functions.js — roda uma suite EXIGINDO o emulador de Functions.
//
// POR QUE ISTO EXISTE, e o defeito concreto que ele conserta:
//
// `firebase emulators:exec` exporta `FIRESTORE_EMULATOR_HOST`,
// `FIREBASE_AUTH_EMULATOR_HOST` e `GCLOUD_PROJECT` para o script — mas NAO
// exporta nada equivalente para Functions. Uma suite que decide rodar os testes
// de Function com `skip: !process.env.FUNCTIONS_EMULATOR_HOST` fica, portanto,
// PERMANENTEMENTE PULADA, mesmo com o emulador de Functions no ar e as funcoes
// carregadas. O relatorio diz "verde", o portao fica verde, e nenhuma chamada
// foi feita.
//
// §37 da OS proibe exatamente esse desfecho: "Nao declarar teste de integracao
// se apenas funcao pura foi testada."
//
// Este runner faz as duas coisas que faltavam:
//   1. CONFERE que o emulador de Functions esta atendendo, e FALHA se nao
//      estiver — em vez de pular em silencio;
//   2. exporta `FUNCTIONS_EMULATOR_HOST` para a suite, que entao roda de fato.
//
// Uso:  node com-functions.js [--codebase=<nome>] social.test.js
//
// `--codebase` so muda a MENSAGEM DE ERRO: cada suite depende de um codebase
// diferente (`functions-social`, `functions-moderacao`), e mandar quem esbarrou
// no erro compilar o bundle errado gasta o tempo de quem ja esta bloqueado. A
// verificacao em si e a mesma para todas: a porta 5001 atende ou nao atende.

'use strict';

const net = require('node:net');
const { spawn } = require('node:child_process');

const HOST = process.env.FUNCTIONS_EMULATOR_HOST || '127.0.0.1:5001';
const [host, porta] = HOST.split(':');

const argumentos = process.argv.slice(2);
const codebase = (argumentos.find((a) => a.startsWith('--codebase=')) || '')
  .split('=')[1] || null;
const alvos = argumentos.filter((a) => !a.startsWith('--'));

if (alvos.length === 0) {
  console.error('uso: node com-functions.js [--codebase=<nome>] <arquivo de teste> [...]');
  process.exit(2);
}

function comoSubir() {
  if (!codebase) {
    return '  suba o emulador com o codebase de Functions que esta suite exige.\n';
  }
  return (
    `  cd functions-${codebase} && npm run build:domain && npm run build\n` +
    `  cd firebase/testes && npm run emulador:${codebase}\n`
  );
}

/// Conexao TCP crua, e nao um HTTP GET: o emulador de Functions responde 404 a
/// qualquer caminho desconhecido, entao um GET bem-sucedido nao provaria mais do
/// que a porta aberta ja prova — e um GET malsucedido seria ambiguo entre "nao
/// esta no ar" e "rota errada".
function portaAberta() {
  return new Promise((resolve) => {
    const socket = net.connect({ host, port: Number(porta) });
    const fim = (ok) => {
      socket.destroy();
      resolve(ok);
    };
    socket.setTimeout(3000);
    socket.once('connect', () => fim(true));
    socket.once('timeout', () => fim(false));
    socket.once('error', () => fim(false));
  });
}

(async () => {
  if (!(await portaAberta())) {
    console.error(
      `\nO emulador de Functions nao esta atendendo em ${HOST}.\n` +
      'Esta suite prova CHAMADAS REAIS as Cloud Functions; rodar sem elas seria\n' +
      'declarar integracao onde so houve funcao pura. Suba assim:\n\n' +
      comoSubir(),
    );
    process.exit(1);
  }

  const filho = spawn(
    process.execPath,
    ['--test', ...alvos],
    { stdio: 'inherit', env: { ...process.env, FUNCTIONS_EMULATOR_HOST: HOST } },
  );
  filho.on('exit', (codigo) => process.exit(codigo ?? 1));
})();
