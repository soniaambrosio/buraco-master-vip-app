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
// diferente (`functions-social`, `functions-moderacao`, `firebase/functions`), e
// mandar quem esbarrou no erro compilar o bundle errado — ou compilar um bundle
// que nem existe — gasta o tempo de quem ja esta bloqueado. A verificacao em si
// e a mesma para todas: a porta 5001 atende ou nao atende.
//
// E ele CONFERE O RELATORIO depois de rodar. O portao de porta aberta prova que
// o emulador atende; nao prova que a suite chamou alguma coisa. Um `describe`
// inteiro sob `skip` sai do `node --test` com codigo 0 — e, dependendo de onde o
// skip esta, sem sequer somar no contador `# skipped`. A leitura completa mora
// em `relatorio-testes.js`, que confere pulo, CANCELAMENTO e piso de casos.
// Neste runner, pular e falhar: quem quer pular roda o alvo de Regras, que nao
// alega provar Function nenhuma.
//
// E ele deixa RECIBO. Este processo roda DENTRO do `firebase emulators:exec`, e
// dali para fora so atravessa um exit code. `runner-emulador.js` precisa saber a
// diferenca entre "a suite rodou inteira e passou" e "o comando interno nem
// comecou, e o exec saiu 0 assim mesmo" — as duas coisas chegam la como zero. O
// recibo em `BMV_RELATORIO_SAIDA` e o que separa as duas.

'use strict';

const fs = require('node:fs');
const net = require('node:net');
const { spawn } = require('node:child_process');
const { lerRelatorio, conferirRelatorio, resumir } = require('./relatorio-testes');

const HOST = process.env.FUNCTIONS_EMULATOR_HOST || '127.0.0.1:5001';
const [host, porta] = HOST.split(':');

const argumentos = process.argv.slice(2);
const codebase = (argumentos.find((a) => a.startsWith('--codebase=')) || '')
  .split('=')[1] || null;
const esperadoBruto = (argumentos.find((a) => a.startsWith('--esperado=')) || '')
  .split('=')[1];
const esperado = esperadoBruto === undefined ? null : Number(esperadoBruto);
const alvos = argumentos.filter((a) => !a.startsWith('--'));

if (alvos.length === 0) {
  console.error('uso: node com-functions.js [--codebase=<nome>] <arquivo de teste> [...]');
  process.exit(2);
}

/// Como subir cada codebase. Nao da para derivar de uma regra so: `colecoes`
/// mora em `firebase/functions`, e nao em `functions-colecoes`, e seu `main` e
/// `index.js` direto — nao tem `build:domain`, nao tem tsc e nao tem `lib/`.
/// Imprimir a receita dos outros dois mandaria quem esta bloqueado rodar um
/// build inexistente numa pasta inexistente.
const RECEITA = {
  colecoes: '  cd firebase/functions && npm install\n',
  moderacao: '  cd functions-moderacao && npm run build:domain && npm run build\n',
  social: '  cd functions-social && npm run build:domain && npm run build\n',
};

function comoSubir() {
  if (!codebase) {
    return '  suba o emulador com o codebase de Functions que esta suite exige.\n';
  }
  const preparo = RECEITA[codebase]
    || `  prepare o codebase \`${codebase}\` conforme o firebase.json\n`;
  return preparo + `  cd firebase/testes && npm run emulador:${codebase}\n`;
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

  // `pipe` e nao `inherit`: e o unico jeito de LER o relatorio. Cada pedaco e
  // reescrito na saida na hora em que chega, entao o acompanhamento ao vivo
  // continua igual ao de antes.
  const filho = spawn(
    process.execPath,
    ['--test', ...alvos],
    { stdio: ['inherit', 'pipe', 'inherit'], env: { ...process.env, FUNCTIONS_EMULATOR_HOST: HOST } },
  );

  let relatorio = '';
  filho.stdout.on('data', (pedaco) => {
    process.stdout.write(pedaco);
    relatorio += pedaco;
  });

  // `close`, e nao `exit`: `exit` avisa quando o processo morreu, o que pode ser
  // ANTES de a ultima leva do stdout chegar aqui. Conferir o relatorio nesse
  // instante seria conferir um relatorio truncado — e o pedaco que falta e
  // justamente o rodape.
  filho.on('close', (codigo) => {
    const lido = lerRelatorio(relatorio);
    const conferencia = conferirRelatorio(lido, { esperado, alvo: codebase });

    // O recibo sai SEMPRE, inclusive na falha: quem le do lado de fora do
    // `emulators:exec` so recebe um exit code, e um recibo que so existisse no
    // caminho feliz nao distinguiria "falhou" de "nao rodou".
    if (process.env.BMV_RELATORIO_SAIDA) {
      try {
        fs.writeFileSync(process.env.BMV_RELATORIO_SAIDA, JSON.stringify({
          codebase,
          esperado,
          exitFilho: codigo,
          relatorio: lido,
          ok: conferencia.ok && codigo === 0,
        }, null, 2));
      } catch (e) {
        console.error(`\nNao consegui escrever o recibo do relatorio: ${e.message}`);
        process.exit(1);
      }
    }

    // Falha real de asercao passa direto, com o codigo que o `node --test` deu.
    // §11 da OS: a camada de robustez nao pode transformar falha funcional em
    // erro generico de infraestrutura.
    if (codigo !== 0) process.exit(codigo ?? 1);

    if (!conferencia.ok) {
      console.error(
        `\nA suite terminou com codigo 0, mas o relatorio nao prova execucao\n` +
        `integral. ${resumir(lido)}\n\n` +
        conferencia.problemas.join('\n\n') + '\n',
      );
      process.exit(1);
    }

    console.log(`\n[com-functions] ${resumir(lido)} — suite integra.`);
    process.exit(0);
  });
})();
