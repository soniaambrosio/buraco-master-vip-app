// runner-emulador.js — o portao unico dos alvos que sobem o Emulator Suite.
//
// O QUE ELE CONSERTA
//
// 1. BUILD ESCONDIDO. `emulador:social` nao compilava nada: quem rodasse o
//    comando documentado, sozinho, provava o bundle de ONTEM — ou, se nunca
//    tivesse compilado, nao provava nada. Na linha de base desta OS,
//    `functions-social/lib/` nem existia, e o alvo respondia `functions/not-found`
//    com 60+ casos cancelados embaixo. Um alvo de homologacao que exige preparo
//    manual nao documentado no proprio alvo nao e reproduzivel.
//
// 2. COLISAO DE AMBIENTE. Os tres alvos usam as MESMAS portas e o MESMO
//    projectId. Duas execucoes sobrepostas nao se revezam: elas se atrapalham, e
//    o estrago aparece como resultado de TESTE, e nao como erro de ambiente —
//    `assertFails` passando por motivo errado, casos cancelados aos montes.
//
// 3. VERDE SEM PROVA. Exit code 0 do `node --test` responde "nada falhou", e nao
//    "tudo rodou". Ver `relatorio-testes.js`.
//
// A ORDEM IMPORTA, e e esta:
//
//    java? -> preparo/build -> artefatos existem? -> TRAVA -> portas livres?
//          -> emulators:exec -> confere o recibo -> cleanup (sempre)
//
// O build vem ANTES da trava de proposito. Compilar leva dezenas de segundos e
// nao toca em porta nenhuma; segurar o ambiente durante o build faria uma
// execucao vizinha esperar por um recurso que ninguem esta usando. A trava cobre
// so a janela em que o emulador esta de pe.
//
// TRES CLASSES DE DESFECHO, e nao uma so. Quem le um portao vermelho pergunta
// antes de tudo "e defeito meu ou da maquina?", e um rotulo unico obriga a ler o
// log inteiro para descobrir. Cada classe tem rotulo (`class=`) e faixa de exit
// code proprios:
//
//    class=OK ................ 0  suite rodou INTEIRA e passou
//    class=FALHA-FUNCIONAL ... 1  subiu, rodou inteira, e uma asercao falhou.
//                                 Unico caso em que o vermelho fala do codigo.
//                                 O exit vem do filho, sem reinterpretar (§11).
//    class=INFRAESTRUTURA .... 3  ambiente ocupado (trava ou porta), ou a suite
//                                 nem chegou a rodar
//                            4  preparo falhou: java, npm install, build ou
//                                 artefato ausente
//    class=SUITE-INCOMPLETA .. 5  subiu e rodou, mas nao inteira: pulou,
//                                 cancelou, encolheu ou nao deixou recibo.
//                                 Nao e defeito de codigo nem de maquina — e
//                                 ausencia de prova, o falso verde desta OS.
//    class=CLEANUP-INCOMPLETO  6  a suite passou, mas a execucao terminou com
//                                 porta presa. Nao e verde: ela acabou de
//                                 sabotar a proxima execucao.
//    class=INDETERMINADA ..... n  relatorio integro e mesmo assim exit != 0.
//                                 Repassa o codigo: inventar classe seria chute.

'use strict';

const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawn, spawnSync } = require('node:child_process');

const {
  esperarPortasLivres,
  caminhoDaTrava,
  esperarTrava,
  matarArvore,
} = require('./ambiente-emulador');
const { classificar, resumir, CLASSE } = require('./relatorio-testes');

const RAIZ = path.resolve(__dirname, '..', '..');
const PROJETO = 'demo-bmv';

/// Espera antes de desistir do ambiente. 90s cobre o caso real que motivou a
/// espera — o rabo de alguns segundos em que o emulador anterior ja devolveu o
/// terminal mas ainda esta soltando as portas nesta maquina — sem virar um
/// portao que trava a tarde de alguem quando o ocupante e uma suite inteira.
/// `BMV_EMULADOR_ESPERA_MS=0` da a politica fail-fast.
const ESPERA_MS = process.env.BMV_EMULADOR_ESPERA_MS !== undefined
  ? Number(process.env.BMV_EMULADOR_ESPERA_MS)
  : 90_000;

/// Quanto se espera, DEPOIS da suite, as portas voltarem. Estourar isto reprova
/// a execucao: ver o ramo de dreno em `classificar`. 30s e folgado para o rabo de
/// alguns segundos que o `emulators:exec` costuma deixar nesta maquina — se
/// passar disso, nao e mais rabo de encerramento, e recurso preso.
/// `BMV_EMULADOR_DRENO_MS` existe para os testes conseguirem provocar o estouro
/// sem esperar meio minuto.
const DRENO_MS = process.env.BMV_EMULADOR_DRENO_MS !== undefined
  ? Number(process.env.BMV_EMULADOR_DRENO_MS)
  : 30_000;

/// As portas que o Emulator Suite reserva. As quatro primeiras estao declaradas
/// em `firebase.json`; hub, logging, eventarc e tasks o CLI sobe sozinho, com
/// porta fixa, sem aparecer na configuracao — e foram vistas no log de
/// encerramento desta arvore. Ficar de fora da conferencia so as tornaria
/// invisiveis, nao inofensivas.
const PORTAS = [
  { nome: 'firestore', porta: 8080 },
  { nome: 'functions', porta: 5001 },
  { nome: 'auth', porta: 9099 },
  { nome: 'ui', porta: 4000 },
  { nome: 'hub', porta: 4400 },
  { nome: 'logging', porta: 4500 },
  { nome: 'eventarc', porta: 9299 },
  { nome: 'tasks', porta: 9499 },
];

/// Cada alvo declara o que PRECISA, e o runner executa. O `preparo` nao e
/// documentacao: e a receita que roda.
///
/// O PISO de casos da suite (§9 da OS) NAO esta aqui: mora no `--esperado=N` do
/// alvo interno, em `package.json`, porque o CI chama aqueles alvos direto sem
/// passar por este runner. Duas copias do numero divergiriam na primeira vez que
/// alguem acrescentasse um teste.
const ALVOS = {
  social: {
    codebase: 'social',
    only: 'firestore,auth,functions:social',
    script: 'test:social:functions',
    // `install` antes do build porque `build` e `tsc`, que mora em
    // devDependencies: sem install o build morre com "tsc nao encontrado", e a
    // mensagem nao aponta para a causa.
    preparo: [
      ['npm', ['--prefix', 'functions-social', 'install', '--no-audit', '--no-fund']],
      ['npm', ['--prefix', 'functions-social', 'run', 'build:domain']],
      ['npm', ['--prefix', 'functions-social', 'run', 'build']],
    ],
    artefatos: ['functions-social/lib/index.js', 'functions-social/lib/domain_bundle.js'],
  },
  moderacao: {
    codebase: 'moderacao',
    only: 'firestore,auth,functions:moderacao',
    script: 'test:moderacao:functions',
    preparo: [
      ['npm', ['--prefix', 'functions-moderacao', 'install', '--no-audit', '--no-fund']],
      ['npm', ['--prefix', 'functions-moderacao', 'run', 'build:domain']],
      ['npm', ['--prefix', 'functions-moderacao', 'run', 'build']],
    ],
    artefatos: ['functions-moderacao/lib/index.js', 'functions-moderacao/lib/domain_bundle.js'],
  },
  colecoes: {
    codebase: 'colecoes',
    only: 'firestore,auth,functions:colecoes',
    script: 'test:colecoes:functions',
    // NAO ha build aqui, e inventar um seria mentira: `firebase/functions/package.json`
    // declara `main: index.js`, entao o emulador carrega o ARQUIVO DA ARVORE.
    // Nao existe bundle que possa envelhecer. O que pode faltar sao as
    // dependencias — sem `firebase-functions` o codebase nao carrega, a 5001
    // abre assim mesmo e a chamada vira um 404 disfarcado de erro de teste.
    preparo: [
      ['npm', ['--prefix', 'firebase/functions', 'install', '--no-audit', '--no-fund']],
    ],
    artefatos: ['firebase/functions/index.js', 'firebase/functions/node_modules/firebase-functions'],
  },
};

const log = (msg) => console.log(`[emulator-runner] ${msg}`);
const erro = (msg) => console.error(`[emulator-runner] ${msg}`);

function sair(codigo, titulo, corpo) {
  console.error(`\n[emulator-runner] ${titulo}\n`);
  if (corpo) console.error(`${corpo}\n`);
  process.exit(codigo);
}

/// `shell: true` e obrigatorio no Windows — `npm` e `firebase` sao `.cmd`, e o
/// `spawn` cru nao os executa. Mas `shell: true` COM lista de argumentos e
/// deprecado (DEP0190): o node concatena os argumentos sem escapar, entao a
/// lista da uma falsa sensacao de seguranca. Por isso a linha e montada aqui,
/// explicitamente, e passada como comando unico. Os tokens sao todos literais
/// deste arquivo — nenhum vem de fora —, entao nao ha o que escapar.
function shell(linha, opcoes = {}) {
  return spawnSync(linha, { shell: true, ...opcoes });
}

/// O emulador do Firestore e uma JVM. Sem java, `emulators:exec` morre com
/// "Could not spawn `java -version`" DEPOIS de ja ter compilado tudo — e essa
/// mensagem nao diz onde arrumar java nesta maquina.
function conferirJava() {
  return shell('java -version', { stdio: 'ignore' }).status === 0;
}

function rodarPreparo(passos) {
  for (const [comando, args] of passos) {
    const linha = `${comando} ${args.join(' ')}`;
    log(`preparo: ${linha}`);
    const r = shell(linha, { cwd: RAIZ, stdio: 'inherit' });
    if (r.status !== 0) return { ok: false, passo: linha, codigo: r.status };
  }
  return { ok: true };
}

function conferirArtefatos(artefatos) {
  const faltando = [];
  const presentes = [];
  for (const rel of artefatos) {
    const abs = path.join(RAIZ, rel);
    if (!fs.existsSync(abs)) {
      faltando.push(rel);
    } else {
      presentes.push({ rel, mtime: fs.statSync(abs).mtime.toISOString() });
    }
  }
  return { faltando, presentes };
}

async function principal() {
  const args = process.argv.slice(2);
  const nome = (args.find((a) => a.startsWith('--alvo=')) || '').split('=')[1];
  const alvo = ALVOS[nome];

  if (!alvo) {
    sair(2, `alvo desconhecido: ${nome || '(nenhum)'}`,
      `uso: node runner-emulador.js --alvo=<${Object.keys(ALVOS).join('|')}>`);
  }

  log(`target=${nome}`);

  // ---- 1. java -------------------------------------------------------------
  if (!conferirJava()) {
    sair(4, `target=${nome} class=INFRAESTRUTURA environment=unusable reason=java ausente`,
      'O emulador do Firestore roda numa JVM, e `java` nao esta no PATH deste\n' +
      'shell. O emulador morreria DEPOIS do build, com uma mensagem que nao diz\n' +
      'onde achar java nesta maquina.\n\n' +
      'Se voce tem o Android Studio, o JDK dele serve:\n' +
      '  export JAVA_HOME="/c/Program Files/Android/Android Studio/jbr"\n' +
      '  export PATH="$JAVA_HOME/bin:$PATH"');
  }
  log('java=ok');

  // ---- 2. preparo ----------------------------------------------------------
  const preparo = rodarPreparo(alvo.preparo);
  if (!preparo.ok) {
    sair(4, `target=${nome} class=INFRAESTRUTURA build=fail`,
      `O passo de preparo falhou (codigo ${preparo.codigo}):\n  ${preparo.passo}\n\n` +
      'Nenhum emulador subiu e nenhum teste foi considerado valido. Rodar a suite\n' +
      'com o build quebrado provaria o bundle antigo — que e o defeito que este\n' +
      'runner existe para impedir.');
  }

  const { faltando, presentes } = conferirArtefatos(alvo.artefatos);
  if (faltando.length > 0) {
    sair(4, `target=${nome} class=INFRAESTRUTURA build=fail reason=artefato ausente`,
      `O preparo terminou com codigo 0, mas os artefatos que o emulador vai\n` +
      `carregar nao existem:\n\n${faltando.map((f) => `  ${f}`).join('\n')}\n\n` +
      'Um build "bem-sucedido" que nao deixa saida e um build que nao aconteceu.');
  }
  log('build=ok');
  for (const a of presentes) log(`  artefato ${a.rel} mtime=${a.mtime}`);

  // ---- 3. trava ------------------------------------------------------------
  const caminho = caminhoDaTrava(PROJETO);
  const trava = await esperarTrava(
    caminho,
    { alvo: nome, iniciado: new Date().toISOString(), cwd: RAIZ },
    {
      timeoutMs: ESPERA_MS,
      aoTentar: (dono, resta) => log(
        `environment=busy lock=${dono ? `${dono.alvo}#${dono.pid}` : 'disputa'} ` +
        `aguardando restam=${Math.round(resta / 1000)}s`,
      ),
    },
  );

  if (!trava.ok) {
    const d = trava.dono;
    sair(3, `target=${nome} class=INFRAESTRUTURA environment=busy reason=execucao concorrente`,
      (d
        ? `Outra execucao do Emulator Suite esta no ar:\n` +
          `  alvo   ${d.alvo}\n  pid    ${d.pid}\n  desde  ${d.iniciado}\n\n`
        : 'Outra execucao pegou a trava no mesmo instante.\n\n') +
      `Os tres alvos compartilham portas e projectId \`${PROJETO}\`: subir por cima\n` +
      'da outra execucao nao daria dois ambientes, daria dois meios-ambientes — e o\n' +
      'estrago apareceria como teste cancelado, e nao como erro de porta.\n\n' +
      `Esperei ${Math.round(ESPERA_MS / 1000)}s. NENHUM teste rodou; nada aqui e verde nem\n` +
      'vermelho de teste. Espere a outra execucao terminar e rode de novo.');
  }

  // O recibo. O relatorio e conferido DENTRO do emulador, por `com-functions.js`;
  // este arquivo e como o resultado dessa conferencia atravessa a fronteira do
  // `emulators:exec` de volta para ca. Sem ele, um `emulators:exec` que saisse 0
  // sem sequer rodar o comando — script vazio, shell que engoliu o erro — seria
  // indistinguivel de uma suite verde.
  //
  // Declarado ANTES do cleanup, e nao junto da execucao, para que o `limpar`
  // consiga apaga-lo: um Ctrl+C no meio da suite deixaria para tras um recibo
  // com contagens de uma execucao que ninguem terminou.
  const recibo = path.join(os.tmpdir(), `bmv-relatorio-${nome}-${process.pid}.json`);
  const apagarRecibo = () => {
    try { fs.unlinkSync(recibo); } catch { /* nao existia, que e o esperado */ }
  };

  // A partir daqui a trava e nossa: TODO caminho de saida passa pelo cleanup.
  let filho = null;
  let encerrando = false;
  let portasPresas = [];

  const limpar = () => {
    if (filho && filho.exitCode === null && filho.signalCode === null) {
      matarArvore(filho.pid);
    }
    apagarRecibo();

    // A trava CAI mesmo com porta presa, e de proposito: uma trava sem dono vivo
    // so bloquearia o projeto sem proteger nada — o que ainda protege e o teste de
    // bind, que a proxima execucao faz nas oito portas e que enxerga o ocupante
    // independentemente de quem seja. O que nao pode acontecer e a liberacao ser
    // LIDA como "ambiente saudavel": por isso ela e anunciada com o estrago junto.
    if (portasPresas.length > 0) {
      erro(`cleanup=FAIL lock=liberado ports_presas=${portasPresas.map((o) => `${o.nome}:${o.porta}`).join(',')}`
        + ' — a trava saiu, mas o ambiente NAO esta livre; a proxima execucao vai esbarrar nestas portas.');
    }
    trava.liberar();
  };

  // Ctrl+C e SIGTERM tambem passam pelo cleanup: sem isso, a trava sobreviveria
  // a execucao e o emulador ficaria orfao segurando a 8080. A trava tem defesa
  // contra obsolescencia (PID), mas o emulador orfao nao — matar a arvore aqui e
  // o que evita "porta ocupada" na proxima execucao.
  for (const sinal of ['SIGINT', 'SIGTERM', 'SIGHUP', 'SIGBREAK']) {
    process.on(sinal, () => {
      if (encerrando) return;
      encerrando = true;
      erro(`\ntarget=${nome} interrompido por ${sinal} — limpando ambiente.`);
      limpar();
      process.exit(130);
    });
  }
  process.on('exit', limpar);

  log(`lock=ok pid=${process.pid}`);

  // ---- 4. portas -----------------------------------------------------------
  const portas = await esperarPortasLivres(PORTAS, {
    timeoutMs: ESPERA_MS,
    aoTentar: (ocupadas, resta) => log(
      `environment=busy ports=${ocupadas.map((o) => `${o.nome}:${o.porta}`).join(',')} ` +
      `aguardando restam=${Math.round(resta / 1000)}s`,
    ),
  });

  if (!portas.livre) {
    const lista = portas.ocupadas.map((o) => `  ${o.nome.padEnd(10)} ${o.porta}  (${o.codigo})`).join('\n');
    sair(3, `target=${nome} class=INFRAESTRUTURA environment=busy reason=port ${portas.ocupadas[0].porta} already in use`,
      `Nao foi possivel iniciar o emulador de ${nome}: porta(s) ja ocupada(s).\n\n${lista}\n\n` +
      'A trava deste runner estava livre, entao o ocupante nao passou por aqui:\n' +
      'pode ser um `firebase emulators:start` solto, um emulador orfao de uma\n' +
      'execucao encerrada a Ctrl+C, ou outro servico na mesma porta.\n\n' +
      `Esperei ${Math.round(ESPERA_MS / 1000)}s. NENHUM teste foi executado e nenhum resultado\n` +
      'parcial e valido. Libere a porta e rode de novo.');
  }
  log(`environment=ready ports=free (${PORTAS.map((p) => p.porta).join(',')})`);

  // ---- 5. execucao ---------------------------------------------------------
  const interno = `cd firebase/testes && npm run ${alvo.script}`;
  const comando = `firebase emulators:exec --only ${alvo.only} --project ${PROJETO} "${interno}"`;

  log(`tests=start script=${alvo.script}`);
  log(`exec: ${comando}`);

  function tentar() {
    // Apaga antes de cada tentativa: um recibo sobrevivente da PRIMEIRA tentativa
    // faria a segunda ser julgada pelo relatorio da primeira.
    apagarRecibo();
    return new Promise((resolve) => {
      // `pipe` no stdout, e nao `inherit`: e o unico jeito de LER o motivo de o
      // emulador nao ter subido. Cada pedaco e reescrito na saida na hora em que
      // chega, entao o acompanhamento ao vivo continua igual.
      filho = spawn(comando, {
        cwd: RAIZ,
        shell: true,
        stdio: ['inherit', 'pipe', 'pipe'],
        env: { ...process.env, BMV_RELATORIO_SAIDA: recibo },
        // No POSIX, o proprio grupo permite matar os netos (a JVM do Firestore).
        // No Windows quem faz esse papel e o `taskkill /T` de `matarArvore`.
        detached: process.platform !== 'win32',
      });
      let texto = '';
      for (const [fluxo, saida] of [[filho.stdout, process.stdout], [filho.stderr, process.stderr]]) {
        fluxo.on('data', (p) => { saida.write(p); texto += p; });
      }
      filho.on('close', (c) => resolve({ codigo: c ?? 1, texto, temRecibo: fs.existsSync(recibo) }));
    });
  }

  /// O emulador reclamando de porta, com as palavras dele. A checagem previa
  /// deste runner e um instante; o `emulators:exec` so vai amarrar a 8080 uns
  /// 15s depois, quando ja subiu functions e auth. A janela entre as duas coisas
  /// e estreita e real — foi observada nesta arvore, com a checagem dizendo
  /// `ports=free` e o Firestore respondendo `Port 8080 is not open` em seguida.
  const MARCAS_DE_AMBIENTE = [
    /Port \d+ is not open/i,
    /could not start .*emulator/i,
    /port taken/i,
    /EADDRINUSE/i,
  ];
  const falhouPorAmbiente = (r) => !r.temRecibo
    && MARCAS_DE_AMBIENTE.some((m) => m.test(r.texto));

  let execucao = await tentar();

  // UMA repescagem, e so quando o emulador nao chegou a subir. Nao e para
  // mascarar instabilidade: e para nao transformar uma janela de 15s de porta
  // num vermelho que nao fala de teste nenhum. Os limites que a tornam honesta:
  //
  //   ﹣ so entra aqui quem NAO deixou recibo. Suite que rodou e falhou nunca e
  //     repetida — repetir teste vermelho ate passar e a definicao de portao
  //     mentiroso, e §11 proibe;
  //   ﹣ so entra quem trouxe a reclamacao de porta do proprio emulador;
  //   ﹣ uma vez. Duas tentativas, e nao um laco.
  if (falhouPorAmbiente(execucao)) {
    log('environment=busy reason=o emulador nao subiu por porta — aguardando dreno e repetindo UMA vez');
    const livre = await esperarPortasLivres(PORTAS, {
      timeoutMs: ESPERA_MS,
      aoTentar: (ocupadas, resta) => log(
        `environment=busy ports=${ocupadas.map((o) => `${o.nome}:${o.porta}`).join(',')} `
        + `aguardando restam=${Math.round(resta / 1000)}s`,
      ),
    });
    if (!livre.livre) {
      sair(3, `target=${nome} class=INFRAESTRUTURA environment=busy reason=port ${livre.ocupadas[0].porta} already in use`,
        `O emulador de ${nome} nao subiu por porta ocupada, e as portas continuaram\n` +
        `presas por ${Math.round(ESPERA_MS / 1000)}s:\n\n` +
        livre.ocupadas.map((o) => `  ${o.nome.padEnd(10)} ${o.porta}`).join('\n') + '\n\n' +
        'NENHUM teste foi executado. Nada aqui e verde nem vermelho de teste.');
    }
    log('environment=ready ports=free — segunda e ultima tentativa');
    execucao = await tentar();
  }

  const { codigo, temRecibo } = execucao;

  // ---- 6. dreno ------------------------------------------------------------
  // `emulators:exec` DEVOLVE O TERMINAL antes de os emuladores soltarem as
  // portas. Medido nesta maquina: com o exec ja retornado e o exit code na mao,
  // o `firebase` e a JVM do Firestore continuaram escutando 8080/5001/9099/4400/
  // 4500/9299/9499 por alguns segundos. Nao sao orfaos — morrem sozinhos —, mas
  // no intervalo eles sao indistinguiveis de uma execucao concorrente.
  //
  // A trava so cai DEPOIS do dreno. Sem isto, `emulador:social && emulador:moderacao`
  // faria o segundo alvo pegar a trava livre e esbarrar nas portas do primeiro,
  // que e exatamente a colisao que este runner existe para eliminar — so que
  // provocada por ele mesmo.
  //
  // Estourar o dreno REPROVA a execucao (classe CLEANUP-INCOMPLETO, exit 6).
  // Avisar e sair 0 seria dizer "pode seguir" sobre um ambiente que nao pode
  // receber ninguem — e quem paga e a execucao seguinte, que encontra as portas
  // presas. Quem decide e `classificar`, no fim: aqui so se mede.
  const dreno = await esperarPortasLivres(PORTAS, {
    timeoutMs: DRENO_MS,
    aoTentar: (ocupadas) => log(
      `cleanup=aguardando dreno das portas ${ocupadas.map((o) => o.porta).join(',')}`,
    ),
  });
  portasPresas = dreno.livre ? [] : dreno.ocupadas;
  log(dreno.livre
    ? 'cleanup=ok ports=released'
    : `cleanup=FAIL ports=${dreno.ocupadas.map((o) => `${o.nome}:${o.porta}`).join(',')} `
      + `(ainda escutando apos ${Math.round(DRENO_MS / 1000)}s)`);

  // ---- 7. o recibo ---------------------------------------------------------
  //
  // O RECIBO E O QUE SEPARA "a suite rodou e falhou" de "a suite nunca rodou".
  // Do lado de fora do `emulators:exec` so atravessa um exit code, e o mesmo `1`
  // sai das duas situacoes — uma asercao de negocio quebrada e um Firestore que
  // nem subiu. Chamar as duas de `tests=fail` manda quem le procurar um defeito
  // de teste onde houve defeito de ambiente. Como `com-functions.js` escreve o
  // recibo SEMPRE, inclusive quando a suite falha, a presenca dele responde a
  // pergunta sem ambiguidade — e quem le a resposta e `classificar`, logo abaixo.
  const dados = temRecibo ? JSON.parse(fs.readFileSync(recibo, 'utf8')) : null;
  if (temRecibo) fs.unlinkSync(recibo);

  if (dados) {
    log(`report ${resumir(dados.relatorio)} esperado>=${dados.esperado} `
      + `exit_node=${dados.exitFilho} exit_exec=${codigo}`);
  }

  // A decisao inteira mora em `classificar`, que e pura e tem teste unitario. Se
  // a precedencia entre as classes vivesse aqui, dentro de um caminho que so roda
  // com o Emulator Suite de pe, provar que "cancelamento vence falha" custaria
  // subir o emulador — e regra que so da para provar caro acaba nao sendo provada.
  const veredito = classificar({
    relatorio: dados ? dados.relatorio : null,
    esperado: dados ? dados.esperado : null,
    alvo: nome,
    codigo,
    temRecibo,
    dreno: { ok: dreno.livre, ocupadas: dreno.ocupadas },
  });

  if (veredito.classe === CLASSE.OK) {
    log(`target=${nome} class=OK tests=ok exit=0`);
    process.exit(0);
  }

  // FUNCIONAL nao passa por `sair`: a falha real ja foi impressa pelo `node --test`
  // logo acima, com arquivo, linha e diff. Repetir aqui um bloco de explicacao
  // empurraria essa saida para fora da tela — que e o oposto do que §11 pede.
  if (veredito.classe === CLASSE.FUNCIONAL) {
    erro(`target=${nome} class=FALHA-FUNCIONAL tests=fail fail=${dados.relatorio.fail} `
      + `exit=${veredito.exit} (a suite rodou inteira; a falha e de asercao)`);
    process.exit(veredito.exit);
  }

  // `tests=unverified` seria mentira no caso do dreno: ali a suite RODOU e
  // PASSOU, e o que falhou foi o encerramento. Rotular os dois iguais mandaria
  // procurar defeito de teste onde o teste esta verde.
  const rotulo = veredito.classe === CLASSE.CLEANUP
    ? 'tests=pass cleanup=fail'
    : 'tests=unverified';

  sair(veredito.exit, `target=${nome} class=${veredito.classe} ${rotulo}`,
    veredito.problemas.join('\n\n'));
}

principal().catch((e) => {
  erro(`erro inesperado no runner: ${e && e.stack ? e.stack : e}`);
  process.exit(1);
});
