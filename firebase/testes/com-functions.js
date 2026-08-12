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
// skip esta, sem sequer somar no contador `# skipped`. Por isso a leitura e
// feita nas duas frentes: qualquer linha `# SKIP` e qualquer `# skipped` maior
// que zero derrubam a execucao. Neste runner, pular e falhar: quem quer pular
// roda o alvo de Regras, que nao alega provar Function nenhuma.

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
    if (codigo !== 0) process.exit(codigo ?? 1);

    // Duas leituras porque o rodape SOZINHO nao serve. Medido no node 24, com um
    // `describe({skip:true})` de dois casos e um `test({skip:true})` solto:
    //
    //   ﹣ bloco pulado inteiro (1.1ms) # SKIP     <- describe com DOIS casos
    //   ﹣ caso pulado solto (0.5ms) # SKIP
    //   ✔ caso que roda (0.1ms)
    //   ℹ tests 2
    //   ℹ skipped 1
    //
    // `tests 2` e `skipped 1` contam o caso solto e o que rodou. Os DOIS casos
    // de dentro do describe pulado nao entram em contador nenhum: o bloco inteiro
    // sai de cena sem deixar numero. Foi o que aconteceu com `claimPioneerKit` no
    // alvo de Regras — seis casos pulados, rodape dizendo `skipped 0`.
    //
    // Por isso a leitura principal e a diretiva `# SKIP`, que marca cada linha
    // pulada; o rodape entra so como segunda rede.
    //
    // O prefixo do rodape muda com o reporter — `#` no TAP, `ℹ` no spec, que e o
    // padrao desde o node 22 mesmo com a saida redirecionada. Aceitar so o `#`
    // era, ele proprio, um portao que nunca fecharia.
    const pulados = relatorio.split('\n').filter((l) => /#\s*SKIP\b/i.test(l));
    const rodape = relatorio.match(/^\s*(?:#|ℹ)\s*skipped\s+(\d+)\s*$/m);
    const contados = rodape ? Number(rodape[1]) : 0;

    if (pulados.length > 0 || contados > 0) {
      console.error(
        `\nA suite terminou verde, mas com teste PULADO — ${contados} no rodape,` +
        ` ${pulados.length} com diretiva SKIP.\n` +
        'Este alvo alega provar chamada real as Cloud Functions' +
        (codebase ? ` do codebase \`${codebase}\`` : '') + '; um caso pulado aqui\n' +
        'e exatamente o falso verde que ele existe para impedir. Primeiras linhas:\n\n' +
        pulados.slice(0, 10).map((l) => `  ${l.trim()}`).join('\n') + '\n',
      );
      process.exit(1);
    }
    process.exit(0);
  });
})();
