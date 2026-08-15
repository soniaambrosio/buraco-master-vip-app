// catalogo.js — QUAIS suites compoem uma Release Candidate, e quais delas sao
// obrigatorias.
//
// ESTE ARQUIVO E A POLITICA. O orquestrador so executa o que esta declarado
// aqui; o veredito so julga o que o orquestrador devolveu. Manter a politica
// separada da mecanica e o que permite responder "por que a RC reprovou?" com
// uma linha deste arquivo, em vez de com um traco de execucao.
//
// DUAS REGRAS DE HONESTIDADE, herdadas do `ci-os-integracao.yml`:
//
//   1. NADA sai como "nao executado" por erro de DESCOBERTA. Cada suite tem
//      caminho fixo, declarado. Se o caminho existe e a suite mesmo assim nao
//      roda, o motivo e impresso e a RC reprova.
//
//   2. Suite ausente da arvore e DECLARADA, e nao omitida. As frentes que vivem
//      noutro repositorio ou noutra branch aparecem no catalogo com o endereco
//      delas. Uma RC que nao cobre o servidor precisa DIZER que nao cobre o
//      servidor — o silencio seria lido como cobertura.

'use strict';

const fs = require('node:fs');
const path = require('node:path');

const RAIZ = path.resolve(__dirname, '..', '..');

// ---------------------------------------------------------------------------
// descoberta da suite Dart
// ---------------------------------------------------------------------------

/// Arquivos que estao em `app/test/` e NAO sao suite de teste.
///
/// A lista e por DECISAO, com motivo, e nunca por conveniencia. `evidencias_visuais`
/// e o caso real: ela gera PNG e depende de fonte do sistema, entao um vermelho
/// dela nao afirma regressao de produto — e o proprio cabecalho do arquivo
/// registra isso. Ela continua rodando fora do portao, e o relatorio a mostra.
const EXCLUIDOS = {
  'test/colecoes/evidencias_visuais_test.dart':
    'gerador de evidencia visual: produz PNG e depende de fonte do sistema. '
    + 'Vermelho aqui nao afirma regressao — decisao registrada no cabecalho do '
    + 'proprio arquivo e no ci-os-integracao.yml.',
};

/// Um arquivo `.dart` sob `app/test/` e uma SUITE quando tem `main(` e ao menos
/// um caso. Sem isto, `test/rastreabilidade/ferramentas.dart` — que e biblioteca
/// de apoio — entraria na lista e o `flutter test` reprovaria por arquivo sem
/// teste, num vermelho que nao fala de produto nenhum.
function pareceSuite(texto) {
  return /\bmain\s*\(/.test(texto)
    && /\b(test|testWidgets|group)\s*\(/.test(texto);
}

/// Varre `app/test/` inteiro.
///
/// POR QUE VARRER, e nao listar a mao: a lista escrita a mao e o defeito
/// concreto desta arvore. O `ci-os-integracao.yml` chama as suites Dart por
/// caminho, numa lista literal, e a lista ficou para tras — `test/moderacao/`,
/// `test/motor/` e `test/rastreabilidade/` inteiros estao FORA do portao do CI
/// hoje, sem que nada fique vermelho. E o `flutter test` sozinho tambem nao
/// resolve: ele descobre `*_test.dart` e ignora `teste_*.dart`, prefixo usado
/// por sete arquivos versionados aqui.
///
/// Varrendo, um arquivo novo entra no portao no dia em que e escrito, e um
/// arquivo que some derruba o piso. Nenhuma das duas coisas depende de alguem
/// lembrar de editar uma lista.
function descobrirSuitesDart(raiz = RAIZ) {
  const base = path.join(raiz, 'app', 'test');
  const achados = [];
  const ignorados = [];

  if (!fs.existsSync(base)) return { achados, ignorados };

  const andar = (dir) => {
    for (const nome of fs.readdirSync(dir, { withFileTypes: true })) {
      const abs = path.join(dir, nome.name);
      if (nome.isDirectory()) {
        // `data/` e encenacao do portao (seeds copiadas), `evidencias/` e saida
        // gerada. Nenhuma das duas contem suite.
        if (nome.name === 'data' || nome.name === 'evidencias') continue;
        andar(abs);
        continue;
      }
      if (!nome.name.endsWith('.dart')) continue;

      const rel = path.relative(path.join(raiz, 'app'), abs).split(path.sep).join('/');
      if (EXCLUIDOS[rel]) {
        ignorados.push({ caminho: rel, motivo: EXCLUIDOS[rel], porDecisao: true });
        continue;
      }
      if (!pareceSuite(fs.readFileSync(abs, 'utf8'))) {
        ignorados.push({ caminho: rel, motivo: 'sem `main(` com casos: arquivo de apoio.', porDecisao: false });
        continue;
      }
      achados.push({ caminho: rel, absoluto: abs, prefixoTeste: /(^|\/)teste_[^/]*\.dart$/.test(rel) });
    }
  };

  andar(base);
  achados.sort((a, b) => a.caminho.localeCompare(b.caminho));
  ignorados.sort((a, b) => a.caminho.localeCompare(b.caminho));
  return { achados, ignorados };
}

// ---------------------------------------------------------------------------
// o catalogo
// ---------------------------------------------------------------------------

/// `piso` e o numero MINIMO de casos que a suite tem que rodar para o portao
/// aceitar que ela rodou inteira. E piso, e nao igualdade, pelo mesmo motivo
/// documentado em `relatorio-testes.js`: teste novo nao pode ficar devendo uma
/// edicao aqui, mas teste que SOME tem que derrubar.
///
/// Os pisos das suites de emulador NAO moram aqui: eles ja moram no `--esperado=N`
/// dos alvos internos de `firebase/testes/package.json`, e o runner os aciona.
/// Uma segunda copia divergiria na primeira vez que alguem acrescentasse um caso.
const SUITES = [
  // ---- Flutter -----------------------------------------------------------
  {
    chave: 'flutter-analyze',
    titulo: 'Flutter analyze',
    frente: 'Flutter',
    obrigatoria: true,
    tipo: 'flutter-analyze',
    cwd: 'app',
    requerArquivos: ['app/pubspec.yaml'],
    requerFerramenta: 'flutter',
    // A politica e a do CI desta arvore: ERROR reprova, warning/info nao. E
    // decisao registrada, e nao afrouxamento — a arvore tem avisos conhecidos e
    // pre-existentes, e um portao que reprovasse por eles seria desligado em vez
    // de consertado.
    comando: 'flutter analyze --no-fatal-infos --no-fatal-warnings',
  },
  {
    chave: 'flutter-testes',
    titulo: 'Flutter tests (suite Dart inteira, por varredura)',
    frente: 'Flutter',
    obrigatoria: true,
    tipo: 'flutter-machine',
    cwd: 'app',
    requerArquivos: ['app/pubspec.yaml'],
    requerFerramenta: 'flutter',
    precisaEncenacao: true,
    piso: 1052,
  },

  // ---- codebases Node, sem emulador --------------------------------------
  {
    chave: 'billing',
    titulo: 'Billing (functions-billing)',
    frente: 'Billing',
    obrigatoria: true,
    tipo: 'node-test',
    cwd: 'functions-billing',
    requerArquivos: ['functions-billing/package.json'],
    preparo: ['npm install --no-audit --no-fund'],
    comando: 'npm test',
    piso: 13,
  },
  {
    chave: 'functions-torneios',
    titulo: 'Functions/Torneios (typecheck tsc --noEmit)',
    frente: 'Functions',
    obrigatoria: true,
    tipo: 'typecheck',
    cwd: 'functions',
    requerArquivos: ['functions/package.json'],
    preparo: ['npm install --no-audit --no-fund'],
    comando: 'npx tsc --noEmit',
  },
  {
    chave: 'social-puro',
    titulo: 'Social — dominio puro (functions-social)',
    frente: 'Social',
    obrigatoria: true,
    tipo: 'node-test',
    cwd: 'functions-social',
    requerArquivos: ['functions-social/package.json'],
    preparo: ['npm install --no-audit --no-fund'],
    comando: 'npm test',
    piso: 19,
  },
  {
    chave: 'moderacao-puro',
    titulo: 'Moderacao — barreira de idempotencia (functions-moderacao)',
    frente: 'Moderacao',
    obrigatoria: true,
    tipo: 'node-test',
    cwd: 'functions-moderacao',
    requerArquivos: ['functions-moderacao/package.json'],
    preparo: ['npm install --no-audit --no-fund'],
    comando: 'npm test',
    piso: 13,
  },
  {
    chave: 'runners-emulador',
    titulo: 'Runners de emulador — a logica do proprio portao de suite',
    frente: 'Runners de emulador',
    obrigatoria: true,
    tipo: 'node-test',
    cwd: 'firebase/testes',
    requerArquivos: ['firebase/testes/runner-emulador.test.js'],
    // Nao sobe emulador e nao precisa de java DE PROPOSITO: se o alvo que
    // confere o ambiente dependesse do ambiente que ele existe para conferir,
    // ele nao serviria de rede.
    comando: 'npm run test:runner',
    piso: 40,
  },
  {
    chave: 'portao-rc',
    titulo: 'Portao de RC — testes do proprio portao',
    frente: 'Portao',
    obrigatoria: true,
    tipo: 'node-test',
    cwd: 'ferramentas/portao-rc',
    requerArquivos: ['ferramentas/portao-rc/portao-rc.test.js'],
    // Um portao que nao se prova nao pode reprovar ninguem. Roda cedo e sem
    // dependencia de ambiente.
    comando: 'node --test portao-rc.test.js',
    piso: 66,
  },

  // ---- Emulator Suite ----------------------------------------------------
  // Os quatro sao SEQUENCIAIS e exclusivos: mesmas oito portas, mesmo projectId
  // `demo-bmv`. Duas execucoes sobrepostas nao se revezam — sobem pela metade, e
  // o estrago aparece como teste cancelado, e nao como erro de porta.
  {
    chave: 'regras-firestore',
    titulo: 'Firestore Rules — os quatro blocos no MESMO firestore.rules',
    frente: 'Firestore Rules',
    obrigatoria: true,
    tipo: 'node-test',
    cwd: 'firebase/testes',
    requerArquivos: ['firebase/firestore.rules', 'firebase/testes/package.json'],
    requerJava: true,
    usaEmulador: true,
    preparo: ['npm install --no-audit --no-fund'],
    // `test:integrado` e nao `test`: prova as QUATRO suites de regras, incluindo
    // `rastreabilidade.test.js`, que o alvo `npm test` deixa de fora.
    comando: 'npm run emulador:integrado',
    piso: 105,
    // OS QUATRO PULOS DECLARADOS DESTE ALVO.
    //
    // `emulador:integrado` sobe SO o Firestore — de proposito: provar regra de
    // rastreabilidade nao pode depender de compilar o dominio de torneios, o de
    // moderacao e o social. Consequencia: os blocos que CHAMAM Cloud Function
    // saem `# SKIP` aqui, e o proprio `package.json` registra cada um.
    //
    // Eles NAO ficam sem prova. Cada um e coberto por uma suite de emulador que
    // este mesmo portao executa, como OBRIGATORIA — e por isso a excecao e
    // aceitavel: ela nao dispensa a prova, ela diz onde a prova mora. Se
    // qualquer uma dessas tres suites sumir do catalogo ou deixar de ser
    // obrigatoria, estes quatro pulos viram buraco real.
    //
    // O rodape do `node --test` marca `skipped 0` nesta execucao: os quatro sao
    // `describe` inteiros, que nao somam no contador. Sem a leitura por
    // DIRETIVA, o portao nao os enxergaria.
    pulosPermitidos: [
      'registrarDenuncia',      // provado por `moderacao-emulador`
      'bloqueio pela Function', // provado por `moderacao-emulador`
      'claimPioneerKit',        // provado por `colecoes-emulador`
      'Functions sociais',      // provado por `social-emulador`
    ],
    cobertoPor: ['moderacao-emulador', 'colecoes-emulador', 'social-emulador'],
  },
  {
    chave: 'social-emulador',
    titulo: 'Social — Functions reais no Emulator Suite',
    frente: 'Social',
    obrigatoria: true,
    tipo: 'runner-emulador',
    cwd: 'firebase/testes',
    requerArquivos: ['functions-social/package.json', 'firebase/testes/package.json'],
    requerJava: true,
    usaEmulador: true,
    preparo: ['npm install --no-audit --no-fund'],
    // Diretorio do codebase que o Emulator Suite tem que carregar. Se ELE
    // falhar na carga, a suite reprova como IMPEDIDA e nao como falha de
    // asercao (ver `lerCargaDeCodebases`).
    codebaseDir: 'functions-social',
    comando: 'npm run emulador:social',
  },
  {
    chave: 'moderacao-emulador',
    titulo: 'Moderacao — Functions reais no Emulator Suite',
    frente: 'Moderacao',
    obrigatoria: true,
    tipo: 'runner-emulador',
    cwd: 'firebase/testes',
    requerArquivos: ['functions-moderacao/package.json', 'firebase/testes/package.json'],
    requerJava: true,
    usaEmulador: true,
    preparo: ['npm install --no-audit --no-fund'],
    // Diretorio do codebase que o Emulator Suite tem que carregar. Se ELE
    // falhar na carga, a suite reprova como IMPEDIDA e nao como falha de
    // asercao (ver `lerCargaDeCodebases`).
    codebaseDir: 'functions-moderacao',
    comando: 'npm run emulador:moderacao',
  },
  {
    chave: 'colecoes-emulador',
    titulo: 'Integracao — Colecoes/Kit Pioneiros: regras + Functions reais',
    frente: 'Integracao',
    obrigatoria: true,
    tipo: 'runner-emulador',
    cwd: 'firebase/testes',
    requerArquivos: ['firebase/functions/index.js', 'firebase/testes/package.json'],
    requerJava: true,
    usaEmulador: true,
    preparo: ['npm install --no-audit --no-fund'],
    // Diretorio do codebase que o Emulator Suite tem que carregar. Se ELE
    // falhar na carga, a suite reprova como IMPEDIDA e nao como falha de
    // asercao (ver `lerCargaDeCodebases`).
    codebaseDir: 'functions',
    comando: 'npm run emulador:colecoes',
  },

  // ---- frentes que NAO vivem nesta arvore --------------------------------
  //
  // Declaradas, e nao omitidas. Elas nao reprovam a RC porque o codigo delas nao
  // esta neste commit — reprovar seria acusar esta base de um buraco que ela nao
  // tem. Mas elas APARECEM, com endereco, na secao COBERTURA do relatorio: uma
  // RC assinada aqui nao cobre estas frentes, e quem assina precisa saber disso.
  //
  // `--exigir=<chave>` promove qualquer uma a obrigatoria, e ai a ausencia
  // reprova. E o que se usa no dia em que a base passar a conter a frente.
  {
    chave: 'servidor',
    titulo: 'Servidor de partida (Node/Railway)',
    frente: 'Servidor',
    obrigatoria: false,
    foraDaBase: {
      onde: 'repositorio `buraco-servidor` (bundle Node publicado, fora deste git)',
      motivo: 'a autoridade da partida nao mora neste repositorio; aqui o Firebase '
        + 'cobre so Auth e persistencia.',
    },
  },
  {
    chave: 'ranking',
    titulo: 'Ranking (functions-ranking)',
    frente: 'Ranking',
    obrigatoria: false,
    requerArquivos: ['functions-ranking/package.json'],
    foraDaBase: {
      onde: 'branch `claude/player-account-deletion-flow-d04d45` (linhagem de identidade/ranking)',
      motivo: 'a linhagem de runners desta base e a de ranking divergiram sem merge; '
        + 'o codebase `functions-ranking/` nao existe neste commit.',
    },
  },
  {
    chave: 'economia',
    titulo: 'Economia (functions-economia)',
    frente: 'Economia',
    obrigatoria: false,
    requerArquivos: ['functions-economia/package.json'],
    foraDaBase: {
      onde: 'branch `feat/economia-boas-vindas-vitorias`',
      motivo: 'codebase de economia publicado noutra frente, sem merge nesta base.',
    },
  },
];

/// Detecta o estado de uma suite ANTES de tentar roda-la.
///
/// Separado da execucao para que o relatorio consiga dizer "ausente" sem ter
/// gasto um minuto tentando — e para que a ausencia tenha o mesmo peso de
/// evidencia que uma falha.
function detectar(suite, contexto = {}) {
  const { raiz = RAIZ, java = { achado: true }, ferramentas = {} } = contexto;

  const faltando = (suite.requerArquivos || [])
    .filter((rel) => !fs.existsSync(path.join(raiz, rel)));

  if (faltando.length > 0 || (suite.foraDaBase && !suite.requerArquivos)) {
    const onde = suite.foraDaBase ? `\n  vive em: ${suite.foraDaBase.onde}` : '';
    const porque = suite.foraDaBase ? `\n  ${suite.foraDaBase.motivo}` : '';
    return {
      presente: false,
      estado: 'AUSENTE',
      motivo: (faltando.length
        ? `caminho(s) ausente(s) nesta arvore: ${faltando.join(', ')}`
        : 'a frente nao esta nesta arvore') + onde + porque,
    };
  }

  if (suite.requerJava && !java.achado) {
    return {
      presente: true,
      estado: 'IMPEDIDA',
      motivo: 'o emulador do Firestore roda numa JVM e nao ha `java` nesta maquina.\n'
        + '  Procurado no PATH, em JAVA_HOME e no JBR do Android Studio.',
    };
  }

  if (suite.requerFerramenta && ferramentas[suite.requerFerramenta] === false) {
    return {
      presente: true,
      estado: 'IMPEDIDA',
      motivo: `a ferramenta \`${suite.requerFerramenta}\` nao esta disponivel nesta maquina.`,
    };
  }

  return { presente: true, estado: 'PRONTA', motivo: null };
}

module.exports = { SUITES, EXCLUIDOS, RAIZ, descobrirSuitesDart, detectar, pareceSuite };
