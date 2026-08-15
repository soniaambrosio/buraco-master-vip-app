// ambiente.js — o que o portao confere ANTES de comecar e DEPOIS de terminar.
//
// A metade esquecida de um portao de release e o ENCERRAMENTO. Um pipeline que
// pergunta so "os testes passaram?" aprova uma execucao que deixou a JVM do
// Firestore segurando a 8080, a trava do emulador no /tmp e trinta megabytes de
// seed copiada dentro de `app/test/`. Os testes passaram mesmo — e a proxima
// execucao vai falhar por um motivo que nao tem nada a ver com o codigo dela.
//
// As primitivas de porta e de trava NAO sao reimplementadas aqui: elas vem de
// `firebase/testes/ambiente-emulador.js`, que ja resolve o caso dificil (teste
// de BIND e nao leitura de netstat, para nao confundir TIME_WAIT com ocupacao) e
// tem teste proprio. Este arquivo acrescenta o que e do nivel da RC: descoberta
// de java, orfaos desta execucao, e a limpeza da encenacao de CI.

'use strict';

const fs = require('node:fs');
const path = require('node:path');
const { execFileSync, spawnSync } = require('node:child_process');

const RAIZ = path.resolve(__dirname, '..', '..');
const {
  esperarPortasLivres, caminhoDaTrava, processoVivo, matarArvore,
} = require(path.join(RAIZ, 'firebase', 'testes', 'ambiente-emulador.js'));

/// As mesmas oito portas do `runner-emulador.js`. Repetidas aqui e nao
/// importadas porque aquele arquivo nao as exporta; divergir seria um risco, e
/// por isso o teste do portao confere que as duas listas batem.
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

const PROJETO = 'demo-bmv';

/// Dreno pos-execucao. Mesma folga do runner de suite: o `emulators:exec`
/// devolve o terminal antes de soltar as portas, e o rabo dura segundos.
const DRENO_MS = process.env.BMV_PORTAO_DRENO_MS !== undefined
  ? Number(process.env.BMV_PORTAO_DRENO_MS)
  : 45_000;

// ---------------------------------------------------------------------------
// java
// ---------------------------------------------------------------------------

/// O emulador do Firestore e uma JVM. Nesta maquina `java` NAO esta no PATH do
/// shell, mas o JDK 21 do Android Studio esta instalado — e mandar quem rodou o
/// portao instalar um JDK que ele ja tem e desperdicio de turno.
///
/// Procurar nao e afrouxar: se nao houver java em lugar nenhum, as suites de
/// emulador ficam IMPEDIDAS e, por serem obrigatorias, REPROVAM. O que a busca
/// evita e reprovar por configuracao de PATH quando a ferramenta existe.
const CANDIDATOS_JAVA = [
  process.env.JAVA_HOME && path.join(process.env.JAVA_HOME, 'bin', 'java'),
  'C:/Program Files/Android/Android Studio/jbr/bin/java.exe',
  'C:/Program Files/Android/Android Studio1/jbr/bin/java.exe',
  '/usr/lib/jvm/default-java/bin/java',
].filter(Boolean);

function acharJava() {
  if (spawnSync('java -version', { shell: true, stdio: 'ignore' }).status === 0) {
    return { achado: true, caminho: 'java', javaHome: process.env.JAVA_HOME || null, doPath: true };
  }
  for (const c of CANDIDATOS_JAVA) {
    if (!fs.existsSync(c)) continue;
    if (spawnSync(`"${c}" -version`, { shell: true, stdio: 'ignore' }).status !== 0) continue;
    return {
      achado: true,
      caminho: c,
      javaHome: path.resolve(path.dirname(c), '..'),
      doPath: false,
    };
  }
  return { achado: false, caminho: null, javaHome: null, doPath: false };
}

/// Quanto tempo o firebase-tools espera um codebase DECLARAR o backend dele
/// (`FUNCTIONS_DISCOVERY_TIMEOUT`, em segundos; o padrao sao 10s).
///
/// POR QUE ISTO EXISTE, e por que NAO e afrouxar teste:
///
/// Medido nesta arvore, em duas execucoes independentes — pelo portao e pelo
/// comando documentado `npm run emulador:moderacao`, sozinho: `functions-moderacao`
/// estoura os 10s e o emulador sobe SEM ele. Todas as 16 chamadas a
/// `registrarDenuncia`/`bloquearJogador` voltam `FirebaseError: not-found`, e a
/// suite reprova por asercao — apontando um defeito numa Function que nunca
/// chegou a existir naquela execucao.
///
/// A causa e tamanho de carga, e nao logica: cada codebase carrega um
/// `domain_bundle.js` de ~80 KB gerado por `dart compile js`, e o
/// firebase-tools 15 percorre TODOS os codebases do `firebase.json` mesmo com
/// `--only functions:<um>`.
///
/// Esperar mais NAO torna teste nenhum mais facil de passar: nenhuma asercao
/// muda, nenhum piso baixa, nenhum pulo e perdoado. O que muda e a Function
/// EXISTIR, para que a suite possa ter veredito. Se o codebase continuar sem
/// carregar, o portao reprova como IMPEDIDA — ver `lerCargaDeCodebases`.
///
/// Mesma natureza da busca por java no JBR logo acima: acomodacao de ambiente,
/// para que o vermelho fale do produto e nao da maquina.
const DESCOBERTA_S = process.env.FUNCTIONS_DISCOVERY_TIMEOUT || '120';

/// Devolve o `env` que os filhos devem herdar: java no PATH quando ele so
/// existia fora dele, e a folga de descoberta dos codebases.
function ambienteComJava(java, base = process.env) {
  const env = { ...base, FUNCTIONS_DISCOVERY_TIMEOUT: DESCOBERTA_S };
  if (!java.achado || java.doPath) return env;
  const bin = path.dirname(java.caminho);
  return {
    ...env,
    JAVA_HOME: java.javaHome,
    PATH: `${bin}${path.delimiter}${base.PATH || ''}`,
    Path: `${bin}${path.delimiter}${base.Path || base.PATH || ''}`,
  };
}

// ---------------------------------------------------------------------------
// orfaos
// ---------------------------------------------------------------------------

/// Um orfao e um processo que ESTA execucao subiu e nao derrubou.
///
/// A definicao e deliberadamente estreita. Um portao que varresse a maquina
/// atras de qualquer `java.exe` reprovaria por causa do Android Studio aberto
/// na outra janela — e a primeira reacao de quem fosse barrado assim seria
/// desligar a verificacao. So conta o que saiu daqui.
///
/// O registro e feito pelo orquestrador, que anota o pid de cada filho que
/// spawna; aqui se confere quais continuam vivos e se derruba a arvore deles.
///
/// FILHO QUE JA FECHOU E PULADO, e nao reconferido pelo PID. O motivo e reuso:
/// numa execucao de dezenas de minutos, o sistema recicla PIDs, e um filho que
/// terminou aos cinco minutos pode ter o numero dele ocupado por um processo
/// alheio aos vinte. Reconferir acusaria orfao onde nao ha nenhum — e um portao
/// que reprova por engano e desligado tao rapido quanto um que esconde defeito.
///
/// O que escapa por aqui (um NETO que sobreviveu ao filho — tipicamente a JVM do
/// Firestore) e coberto pela outra frente, o teste de bind nas oito portas, que
/// enxerga o ocupante independentemente de quem seja. E a mesma divisao de
/// trabalho documentada em `ambiente-emulador.js`: trava e porta cobrem buracos
/// diferentes, e nenhuma das duas sozinha fecha o caso.
function conferirOrfaos(pidsRegistrados) {
  const vivos = [];
  for (const reg of pidsRegistrados) {
    if (!reg || !reg.pid || reg.morto) continue;
    if (!processoVivo(reg.pid)) continue;
    vivos.push({ pid: reg.pid, descricao: reg.descricao || 'filho do portao' });
  }
  return vivos;
}

/// Derruba os orfaos encontrados. O portao MATA antes de reprovar, e reprova
/// mesmo assim.
///
/// Os dois passos sao necessarios e nao se substituem: matar protege a proxima
/// execucao (que e o dano concreto), e reprovar protege a verdade do recibo
/// (uma execucao que precisou de faxina nao foi uma execucao limpa). Um portao
/// que so matasse esconderia um vazamento de processo que vai piorar; um que so
/// reprovasse deixaria a maquina quebrada para o proximo.
function derrubarOrfaos(orfaos) {
  for (const o of orfaos) matarArvore(o.pid);
}

// ---------------------------------------------------------------------------
// trava
// ---------------------------------------------------------------------------

/// A trava residual do Emulator Suite. Ela e do `runner-emulador.js`, e nao
/// deste portao — o portao chama os alvos `emulador:*`, que a pegam e a soltam.
/// Encontra-la de pe DEPOIS que todos terminaram significa que algum runner
/// morreu sem passar pelo `finally`.
function conferirTrava() {
  const caminho = caminhoDaTrava(PROJETO);
  if (!fs.existsSync(caminho)) return { residual: false, caminho, dono: null };
  let dono = null;
  try {
    dono = JSON.parse(fs.readFileSync(caminho, 'utf8'));
  } catch { /* truncada: continua sendo residuo */ }
  return { residual: true, caminho, dono };
}

/// Remove a trava residual, pelo mesmo motivo de `derrubarOrfaos`: a proxima
/// execucao nao pode herdar o estrago, e esta continua reprovada.
function limparTrava(trava) {
  if (!trava.residual) return false;
  try {
    fs.unlinkSync(trava.caminho);
    return true;
  } catch {
    return false;
  }
}

// ---------------------------------------------------------------------------
// portas
// ---------------------------------------------------------------------------

/// Espera o dreno. `aplicavel` e falso quando nenhuma suite de emulador rodou:
/// cobrar dreno de uma execucao que nunca abriu porta seria reprovar por um
/// recurso que ela nao tocou.
async function conferirDreno(aplicavel, aoTentar = () => {}) {
  if (!aplicavel) return { aplicavel: false, drenadas: true, presas: [] };
  const r = await esperarPortasLivres(PORTAS, { timeoutMs: DRENO_MS, aoTentar });
  return { aplicavel: true, drenadas: r.livre, presas: r.ocupadas };
}

// ---------------------------------------------------------------------------
// arvore
// ---------------------------------------------------------------------------

/// O portao ENCENA o ambiente do CI para rodar a suite Dart: copia as seeds de
/// `app/data/` para `app/test/**/data/`, que e onde os testes as procuram. A
/// encenacao e obrigatoria (sem ela quatro suites falham por arquivo ausente) e
/// e lixo (essas copias nunca podem virar commit).
///
/// Portanto ela e desfeita SEMPRE, inclusive quando a execucao falha no meio —
/// e o que sobrar aparece como arvore suja, que reprova. Um portao que sujasse a
/// arvore para se provar verde seria o mesmo defeito da OS, do lado do
/// versionamento.
const ENCENACAO = [
  { de: 'app/data/torneios', para: 'app/test/torneios/data', padrao: /\.json$/ },
  { de: 'app/data/colecoes', para: 'app/test/colecoes/data', padrao: /\.json$/ },
];

function montarEncenacao(raiz = RAIZ) {
  const criados = [];
  for (const { de, para, padrao } of ENCENACAO) {
    const origem = path.join(raiz, de);
    const destino = path.join(raiz, para);
    if (!fs.existsSync(origem)) continue;
    const jaExistia = fs.existsSync(destino);
    if (!jaExistia) fs.mkdirSync(destino, { recursive: true });
    // A PASTA ENTRA NA LISTA ANTES DOS ARQUIVOS que ela vai conter, porque
    // `desmontarEncenacao` percorre a lista ao contrario. Invertido, o `rmdir`
    // da pasta acontecia com os arquivos ainda dentro, falhava em silencio, e a
    // pasta vazia sobrevivia a execucao — arvore suja, e reprovacao por lixo que
    // o proprio portao deixou.
    if (!jaExistia) criados.push(destino);
    for (const nome of fs.readdirSync(origem)) {
      if (!padrao.test(nome)) continue;
      const alvo = path.join(destino, nome);
      // Nao sobrescreve arquivo que ja era da arvore: se um dia a seed for
      // versionada no destino, copiar por cima e depois apagar removeria fonte.
      if (fs.existsSync(alvo)) continue;
      fs.copyFileSync(path.join(origem, nome), alvo);
      criados.push(alvo);
    }
  }
  return criados;
}

/// Desmonta na ordem inversa: arquivos antes das pastas que os contem.
function desmontarEncenacao(criados) {
  const removidos = [];
  for (const alvo of [...criados].reverse()) {
    try {
      const st = fs.statSync(alvo);
      if (st.isDirectory()) fs.rmdirSync(alvo);
      else fs.unlinkSync(alvo);
      removidos.push(alvo);
    } catch { /* ja nao existe, ou pasta com conteudo alheio: fica */ }
  }
  return removidos;
}

/// A arvore esta como comecou?
///
/// `sujeiraAoIniciar` entra como perdao: quem rodou o portao com trabalho em
/// andamento nao pode ser acusado do proprio rascunho. O que reprova e a
/// DIFERENCA — o que apareceu durante a execucao.
function conferirArvore(raiz, sujeiraAoIniciar = []) {
  let atual;
  try {
    atual = execFileSync('git', ['-C', raiz, 'status', '--porcelain'], {
      encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'],
    }).trim();
  } catch {
    return { limpa: true, sujeira: [], indisponivel: true };
  }
  const linhas = atual ? atual.split('\n').filter(Boolean) : [];
  const antes = new Set(sujeiraAoIniciar);
  const nova = linhas.filter((l) => !antes.has(l));
  return { limpa: nova.length === 0, sujeira: nova, indisponivel: false };
}

module.exports = {
  PORTAS, PROJETO, DRENO_MS, RAIZ, DESCOBERTA_S,
  acharJava, ambienteComJava,
  conferirOrfaos, derrubarOrfaos,
  conferirTrava, limparTrava,
  conferirDreno,
  montarEncenacao, desmontarEncenacao, conferirArvore, ENCENACAO,
};
