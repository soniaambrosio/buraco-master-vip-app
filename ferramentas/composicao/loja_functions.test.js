'use strict';
/**
 * §6 — O GATE DA COMPOSIÇÃO LOJA/CASCA ↔ FUNCTIONS CANÔNICAS.
 *
 * ============================================================================
 * O QUE ESTE ARQUIVO É
 * ============================================================================
 *
 * `negativas.test.js`, ao lado, guarda as invariantes da composição das NOVE
 * codebases de Functions. Este guarda a costura de UM nível acima: a árvore em
 * que a Loja publicável (folha `integracao/loja-casca-v2-v1`) e as Functions
 * canônicas (folha `integracao/functions-producao-canonica-v1`) passam a
 * coexistir.
 *
 * As duas folhas divergiram do MESMO ponto e nunca se viram. Cada uma tem
 * suíte própria, verde, e nenhuma delas pode enxergar o que segue — porque o
 * que segue só existe DEPOIS da união:
 *
 *   · que a árvore descende das duas, e não de uma com o texto da outra colado;
 *   · que nenhum dos dois lados entrou apenas como documento;
 *   · que os gates dos dois lados sobreviveram à união da fonte única;
 *   · que a Loja, ao virar alcançável, não trouxe um segundo dono de sessão,
 *     nem dado de maquete para o caminho publicável;
 *   · que a decisão `playerCourtesyPass = APAGAR` continua ligada ao executor
 *     da exclusão de conta, e não só à prosa da OS que a decidiu.
 *
 * ============================================================================
 * A FORMA DE CADA CASO, E A NÃO-VACUIDADE
 * ============================================================================
 *
 * Mesma disciplina de `negativas.test.js`, e pelo mesmo motivo: estes arquivos
 * CITAM em prosa aquilo que proíbem. Toda leitura passa por `arvore.js`, que
 * remove comentários, e toda prova negativa exige ÂNCORA POSITIVA antes de
 * afirmar a ausência. Apagar o arquivo guardado REPROVA, em vez de ficar verde
 * por vazio.
 *
 * O CRITÉRIO CENTRAL DESTE GATE: ele tem de ficar VERMELHO se QUALQUER UM DOS
 * DOIS LADOS for removido. Um gate de composição que sobrevive à amputação de
 * metade da composição não é gate — é decoração.
 */

const { test, describe } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { execFileSync } = require('node:child_process');

const A = require('./arvore.js');

// ---------------------------------------------------------------------------
// AS DUAS ENTRADAS CONGELADAS DA COMPOSIÇÃO
// ---------------------------------------------------------------------------
//
// Escritos por extenso, e não por prefixo: prefixo curto casa com mais de um
// commit à medida que o repositório cresce, e uma prova de ancestralidade que
// casa com "algum commit que começa assim" não prova ancestralidade nenhuma.

/** A folha da Loja ligada à Casca V2. */
const SHA_LOJA = '44883788c5808b3ea7a48966ac181f4e426e9995';

/** A folha das Functions canônicas de produção (nove codebases). */
const SHA_FUNCTIONS = '8e89ea795c829d98a3ceda66fa5b9c743adac5f0';

const CODEBASES = A.codebases();

/** `git` na raiz da composição. Devolve `null` quando o comando falha. */
function git(...args) {
  try {
    return execFileSync('git', ['-c', 'safe.directory=*', '-C', A.RAIZ, ...args], {
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'pipe'],
    }).trim();
  } catch (_) {
    return null;
  }
}

/** Os gates da fonte única (mesma leitura de PN-10/PN-12). */
function gatesDaFonte() {
  return A.ler('scripts/ci/gates_os_integracao.txt')
    .split(/\r?\n/)
    .map((l) => l.trim())
    .filter((l) => l && !l.startsWith('#'));
}

/** Todo arquivo `.dart` sob um diretório da árvore composta. */
function dartsDe(rel) {
  const base = path.join(A.RAIZ, rel);
  const achados = [];
  const andar = (dir) => {
    for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
      const p = path.join(dir, e.name);
      if (e.isDirectory()) { andar(p); continue; }
      if (e.name.endsWith('.dart')) achados.push(path.relative(A.RAIZ, p).split(path.sep).join('/'));
    }
  };
  andar(base);
  return achados;
}

// ---------------------------------------------------------------------------
// CL-01
// ---------------------------------------------------------------------------

describe('CL-01 — a arvore que so PARECE composta', () => {
  // invariante ...... o HEAD descende das DUAS folhas
  // autoridade ...... o grafo do git, e nao um manifesto escrito a mao
  // proibido ........ reconstruir o conteudo de um lado por copia, ou refazer
  //                   a composicao a partir de uma folha so. O texto ficaria
  //                   igual e a proveniencia estaria perdida — e proveniencia
  //                   perdida e o que faz um defeito ja corrigido voltar
  // prova ........... `merge-base --is-ancestor` para cada uma das duas
  test('as duas folhas de origem sao ancestrais do HEAD', () => {
    const head = git('rev-parse', 'HEAD');
    assert.ok(head, 'ANCORA PERDIDA: `git rev-parse HEAD` nao respondeu na raiz da composicao');

    // Historico raso reprova de proposito. Num clone `--depth 1` o
    // `merge-base` responde "nao e ancestral" para QUALQUER commit, e um gate
    // que aceitasse isso ficaria verde exatamente onde nao pode medir.
    assert.equal(
      git('rev-parse', '--is-shallow-repository'),
      'false',
      'HISTORICO RASO: nao da para provar ancestralidade num clone raso. O passo ' +
        'de checkout do workflow precisa de `fetch-depth: 0`.'
    );

    for (const [nome, sha] of [['Loja/Casca V2', SHA_LOJA], ['Functions canonicas', SHA_FUNCTIONS]]) {
      assert.ok(
        git('cat-file', '-e', sha + '^{commit}') !== null,
        `ANCORA PERDIDA: o commit da folha ${nome} (${sha}) nao existe neste repositorio`
      );
      assert.ok(
        git('merge-base', '--is-ancestor', sha, 'HEAD') !== null,
        `ANCESTRALIDADE PERDIDA: ${sha} (${nome}) nao e ancestral do HEAD. A arvore ` +
          'pode ate ter o texto dos dois lados, mas a composicao nao aconteceu.'
      );
    }
  });
});

// ---------------------------------------------------------------------------
// CL-02
// ---------------------------------------------------------------------------

describe('CL-02 — um lado entrando so como documento', () => {
  // invariante ...... o COMPORTAMENTO dos dois lados existe na arvore
  // autoridade ...... os arquivos que cada folha trouxe, e que a outra nao tem
  // proibido ........ publicar a composicao com o relatorio da Loja e sem a
  //                   Loja, ou com as Functions descritas e sem `ferramentas/`
  // prova ........... os arquivos-assinatura dos dois lados existem, e cada um
  //                   carrega a ancora do que o torna executavel
  const ASSINATURAS = [
    // --- lado LOJA/CASCA ---------------------------------------------------
    ['app/lib/casca/loja_de_producao.dart', /class\s+LojaDeProducao\b/],
    ['app/lib/billing/vinculo_firebase.dart', /class\s+\w*Firebase\b/],
    ['app/test/casca/loja_de_producao_test.dart', /void\s+main\s*\(/],
    // --- lado FUNCTIONS ----------------------------------------------------
    ['ferramentas/proveniencia/gerar.js', /module\.exports/],
    ['ferramentas/proveniencia/verificar.js', /module\.exports/],
    ['ferramentas/composicao/negativas.test.js', /describe\s*\(\s*['"]PN-01/],
    ['functions-billing/test/apoio/superficie.js', /SUPERFICIE_PRODUCAO/],
    ['functions-conta/src/inventario.ts', /playerCourtesyPass/],
  ];

  for (const [rel, ancora] of ASSINATURAS) {
    test(`${rel} existe e e a coisa, nao a mencao`, () => {
      A.exigirAncora(assert, A.codigo(rel), ancora, `${rel} sem a ancora que o torna executavel`);
    });
  }

  test('o relatorio da Loja acompanha a Loja, e nao a substitui', () => {
    // O documento e bem-vindo; o que nao pode e ser a UNICA coisa que sobrou de
    // um lado. Por isso a prova e condicional: documento sem codigo REPROVA.
    A.exigirAncora(assert, A.ler('docs/LIGACAO-LOJA-CASCA-V2-V1.md'), 'Loja', 'o relatorio da Loja');
    assert.ok(
      fs.existsSync(path.join(A.RAIZ, 'app/lib/casca/loja_de_producao.dart')),
      'DOCUMENTO SEM COMPORTAMENTO: sobrou o relatorio da Loja e sumiu a Loja.'
    );
  });
});

// ---------------------------------------------------------------------------
// CL-03 · CL-04
// ---------------------------------------------------------------------------

/** O ponto de entrada implantado de cada codebase. */
const ENTRADAS = {
  'firebase/functions': 'firebase/functions/index.js',
  'functions-billing': 'functions-billing/index.js',
  'functions': 'functions/src/index.ts',
  'functions-economia': 'functions-economia/index.js',
  'functions-moderacao': 'functions-moderacao/src/index.ts',
  'functions-ranking': 'functions-ranking/src/index.ts',
  'functions-social': 'functions-social/src/index.ts',
  'functions-conta': 'functions-conta/src/index.ts',
  'functions-mesas': 'functions-mesas/src/index.ts',
};

/** A superfície implantada, congelada por codebase. */
const EXPORTS = {
  'firebase/functions': ['claimPioneerKit', 'grantPioneerEligibility', 'revokePioneerKit'],
  'functions-billing': [
    'backfillPurchaseTokenHash', 'concederFichasMensais', 'diagnosticarMetadadosLegados',
    'diagnosticarPopulacaoVip', 'notificacoesPlay', 'prepararCompraPlay',
    'reconciliarEntitlementDoJogador', 'reconciliarEntitlements', 'validarCompraPlay',
  ],
  'functions': [
    'aoConcluirEdicao', 'cancelarInscricaoTorneio', 'consolidarConvitesDaTemporada',
    'inscreverEmTorneio', 'receberResultadoPartida', 'responderConviteEncerramento',
    'tickTorneios',
  ],
  'functions-economia': [
    'aoRegistrarPartida', 'garantirBonusDeBoasVindas', 'reprocessarResultadoDaPartida',
  ],
  'functions-moderacao': [
    'aplicarSancao', 'bloquearJogador', 'consultarContato', 'definirCanalDeChat',
    'desbloquearJogador', 'enviarMensagemChat', 'enviarMensagemChatPeloMotor',
    'registrarDenuncia', 'revogarSancao',
  ],
  'functions-ranking': [
    'abrirRanking', 'abrirTemporadaDeRanking', 'aoRegistrarResultadoOficial', 'apurarRanking',
    'consultarHall', 'consultarJogadorPorIdPublico', 'diagnosticarRanking',
    'encerrarTemporadaDeRanking', 'paginarRanking', 'processarResultado',
    'reprocessarBacklogDeRanking',
  ],
  'functions-social': [
    'aceitarSolicitacaoAmizade', 'aoBloquearJogador', 'atualizarPerfilPublico',
    'buscarJogadoresPorApelido', 'cancelarSolicitacaoAmizade', 'enviarSolicitacaoAmizade',
    'listarAmigos', 'listarSolicitacoesEnviadas', 'listarSolicitacoesRecebidas',
    'localizarJogadorPorIdentidade', 'obterMinhaIdentidade', 'reconciliarPerfilSocial',
    'recusarSolicitacaoAmizade', 'removerAmizade', 'verPerfilPublico',
  ],
  'functions-conta': ['excluirMinhaConta', 'resumirExclusaoDeConta'],
  'functions-mesas': [
    'admitirEmMesaVip', 'consultarPasseDeCortesia', 'registrarMesaPrivada',
    'resolverConviteDeMesaPrivada',
  ],
};

/** O que uma entrada de fato exporta, lida sem comentário. */
function exportsDe(rel) {
  const s = A.codigo(rel);
  const set = new Set();
  for (const m of s.matchAll(/^\s*export\s+const\s+([A-Za-z0-9_]+)/gm)) set.add(m[1]);
  for (const m of s.matchAll(/exports\.([A-Za-z0-9_]+)\s*=/g)) set.add(m[1]);
  return [...set].sort();
}

describe('CL-03 — uma codebase perdida na uniao', () => {
  // invariante ...... a composicao carrega as NOVE codebases da folha canonica
  // autoridade ...... firebase.json x o disco
  // proibido ........ compor a Loja sobre uma base de Functions mais velha e
  //                   sair com oito. O `firebase.json` de CADA linhagem declara
  //                   um subconjunto diferente, entao "quantas existem" nao se
  //                   responde por contagem numa branch qualquer
  // prova ........... o conjunto do manifesto e exatamente o esperado, e cada
  //                   `source` tem ponto de entrada no disco
  test('as nove codebases da folha canonica atravessaram a composicao', () => {
    assert.deepEqual(
      CODEBASES.map((c) => c.source).sort(),
      Object.keys(ENTRADAS).sort(),
      'CODEBASE PERDIDA (ou inventada) NA COMPOSICAO.'
    );
    for (const rel of Object.values(ENTRADAS)) {
      assert.ok(
        fs.existsSync(path.join(A.RAIZ, rel)),
        `ponto de entrada ausente no disco: ${rel}`
      );
    }
  });
});

describe('CL-04 — um export sumindo na uniao', () => {
  // invariante ...... a superficie implantada e a mesma dos dois lados
  // autoridade ...... o `index` de cada codebase
  // proibido ........ um merge que resolve um `index.ts` pelo lado errado e
  //                   deixa a codebase compilando com uma funcao a menos: nao
  //                   quebra teste nenhum da folha, e some do deploy em silencio
  // prova ........... conjunto fechado, e nao "contem" — ausencia casa com
  //                   renomeacao acidental, e sobra casa com export esquecido
  for (const [codebase, esperados] of Object.entries(EXPORTS)) {
    test(`${codebase} exporta exatamente as ${esperados.length} de sempre`, () => {
      assert.deepEqual(
        exportsDe(ENTRADAS[codebase]),
        [...esperados].sort(),
        `SUPERFICIE ALTERADA em ${codebase}. Mudar a lista aqui e decisao de produto.`
      );
    });
  }
});

// ---------------------------------------------------------------------------
// CL-05
// ---------------------------------------------------------------------------

describe('CL-05 — um lado perdendo os gates na uniao da fonte unica', () => {
  // invariante ...... os gates das DUAS folhas sobrevivem a uniao
  // autoridade ...... scripts/ci/gates_os_integracao.txt
  // proibido ........ resolver a fonte unica por um lado so. Os dois lados
  //                   editaram ESTE arquivo, em hunks diferentes: um `ours` ou
  //                   um `theirs` sobre o arquivo inteiro apagaria os gates do
  //                   outro sem produzir conflito nenhum para investigar
  // prova ........... os dois conjuntos-assinatura estao na fonte, e o gate
  //                   fica VERMELHO se qualquer um dos dois for amputado

  /** O que so a folha da Loja/Casca traz. Sem `cascaloja`, a Loja saiu. */
  const DA_LOJA = ['casca', 'cascaaud', 'cascav2', 'cascaligacao', 'cascamesa', 'cascaporta', 'cascaloja'];

  /** O que so a folha das Functions canonicas traz. */
  const DAS_FUNCTIONS = ['contafn', 'contaemu', 'mesasfn', 'economiafn', 'proveni', 'composneg', 'colecoesemu'];

  test('os gates da folha da Loja/Casca continuam obrigatorios', () => {
    const gates = new Set(gatesDaFonte());
    assert.deepEqual(
      DA_LOJA.filter((g) => !gates.has(g)),
      [],
      'LADO DA LOJA AMPUTADO: a fonte unica perdeu gate que so aquela folha trazia.'
    );
  });

  test('os gates da folha das Functions canonicas continuam obrigatorios', () => {
    const gates = new Set(gatesDaFonte());
    assert.deepEqual(
      DAS_FUNCTIONS.filter((g) => !gates.has(g)),
      [],
      'LADO DAS FUNCTIONS AMPUTADO: a fonte unica perdeu gate que so aquela folha trazia.'
    );
  });

  test('`regras` nao volta: o gate das Rules atende por `colecoesemu`', () => {
    // A lapide importa. Se o nome velho voltar, volta junto o fantasma: gate
    // declarado obrigatorio que passo nenhum produz, e portao incapaz de ficar
    // verde — que e a pressao que leva alguem a afrouxar o agregador.
    assert.ok(!gatesDaFonte().includes('regras'), 'o gate fantasma `regras` voltou a fonte unica');
  });
});

// ---------------------------------------------------------------------------
// CL-06
// ---------------------------------------------------------------------------

describe('CL-06 — o gate da Loja declarado e sem suite por tras', () => {
  // invariante ...... `cascaloja` aponta para a suite da Loja publicavel
  // autoridade ...... o workflow x o arquivo de teste
  // proibido ........ manter o nome do gate depois de apagar ou renomear a
  //                   suite. PN-10 ja impede gate sem produtor; isto impede
  //                   produtor sem ALVO, que e o degrau seguinte
  // prova ........... o passo cita o caminho, e o caminho existe com a suite
  test('`cascaloja` roda a suite da Loja de producao, e ela existe', () => {
    A.exigirAncora(
      assert,
      A.ler('.github/workflows/ci-os-integracao.yml'),
      /roda\s+cascaloja\s+test\/casca\/loja_de_producao_test\.dart/,
      'o workflow produz `cascaloja` a partir da suite da Loja'
    );
    A.exigirAncora(
      assert,
      A.codigo('app/test/casca/loja_de_producao_test.dart'),
      /void\s+main\s*\(/,
      'a suite da Loja tem ponto de entrada'
    );
  });
});

// ---------------------------------------------------------------------------
// CL-07 — RANKING-01
// ---------------------------------------------------------------------------

describe('CL-07 — o Ranking de maquete voltando pela composicao', () => {
  // invariante ...... RANKING-01: nenhuma fabrica de ranking ficticio no app
  // autoridade ...... app/lib/screens/ranking_screen.dart
  // proibido ........ `RankingVM.mock()` de volta, ou uma fabrica equivalente
  //                   com outro nome. A ausencia de fonte tem de virar estado
  //                   vazio; um merge limpo pode reintroduzir a fabrica sem
  //                   produzir conflito nenhum
  // prova ........... ancora positiva (a classe guardada existe) e varredura
  //                   SEM COMENTARIO por qualquer `<Tipo>.mock(` de ranking em
  //                   TODO o `app/lib`
  test('nenhuma fabrica de ranking de maquete no codigo do app', () => {
    A.exigirAncora(
      assert,
      A.codigo('app/lib/screens/ranking_screen.dart'),
      /class\s+RankingVM\b/,
      'a classe RankingVM ainda existe para ser medida'
    );

    const reincidentes = [];
    for (const rel of dartsDe('app/lib')) {
      const src = A.codigo(rel);
      for (const m of src.matchAll(/\b([A-Za-z0-9_]*Ranking[A-Za-z0-9_]*)\s*\.\s*mock\s*\(/g)) {
        reincidentes.push(`${rel} :: ${m[1]}.mock(`);
      }
      for (const m of src.matchAll(/factory\s+([A-Za-z0-9_]*Ranking[A-Za-z0-9_]*)\s*\.\s*mock\b/g)) {
        reincidentes.push(`${rel} :: factory ${m[1]}.mock`);
      }
    }
    assert.deepEqual(
      reincidentes,
      [],
      'RANKING-01 VIOLADA: fabrica de ranking ficticio no app. Sem fonte real, a ' +
        'tela tem de dizer que nao ha ranking publicado — nome, liga, colocacao e ' +
        'pontuacao inventados sao afirmacao falsa sobre uma pessoa.'
    );
  });

  test('a fonte embarcada de producao recusa, e nao inventa', () => {
    // A ancora do outro lado da mesma invariante: existe a fonte que responde
    // "nao ha ranking publicado". Sem ela, o estado vazio nao teria produtor e
    // a prova de cima ficaria verde sobre uma tela que nem abre.
    A.exigirAncora(
      assert,
      A.codigo('app/lib/services/ranking_service.dart'),
      /class\s+RankingSemFonte\b/,
      'a fonte de producao sem ranking publicado'
    );
  });
});

// ---------------------------------------------------------------------------
// CL-08
// ---------------------------------------------------------------------------

describe('CL-08 — a prova de `const RankingPage()` sem fonte fora do portao', () => {
  // invariante ...... o caso comportamental existe E e percorrido pelo portao
  // autoridade ...... app/test/ranking_page_test.dart x o workflow
  // proibido ........ a situacao encontrada NESTA composicao: o unico caso que
  //                   monta `const RankingPage()` — a construcao real das duas
  //                   telas que abrem o Ranking — morava num arquivo que passo
  //                   nenhum do workflow rodava. E o defeito CI-01, na suite
  //                   que guarda justamente RANKING-01
  // prova ........... o caso existe no arquivo, e o arquivo tem gate proprio
  test('o caso monta `const RankingPage()` e exige o estado indisponivel', () => {
    const suite = A.codigo('app/test/ranking_page_test.dart');
    A.exigirAncora(assert, suite, /const\s+RankingPage\s*\(\s*\)/, 'o caso monta a pagina SEM fonte injetada');
    A.exigirAncora(assert, suite, /RankingEstado\.erro/, 'o caso exige o estado de indisponibilidade');
    A.exigirAncora(
      assert,
      A.ler('app/test/ranking_page_test.dart'),
      'O ranking oficial ainda não está sendo publicado.',
      'o caso exige a frase que substitui o dado inventado'
    );
  });

  test('as duas telas que abrem o Ranking constroem `const RankingPage()`', () => {
    // Sem esta ancora o caso de cima seria sobre uma construcao que ninguem
    // faz — prova verdadeira e irrelevante.
    for (const rel of ['app/lib/pages/hall_page.dart', 'app/lib/pages/perfil_page.dart']) {
      A.exigirAncora(
        assert,
        A.codigo(rel),
        /const\s+RankingPage\s*\(\s*\)/,
        `${rel} abre o Ranking sem injetar fonte`
      );
    }
  });

  test('`rkpagina` percorre a suite, e a fonte unica o declara', () => {
    A.exigirAncora(
      assert,
      A.ler('.github/workflows/ci-os-integracao.yml'),
      /roda\s+rkpagina\s+test\/ranking_page_test\.dart/,
      'o workflow produz `rkpagina` a partir da suite da pagina de Ranking'
    );
    assert.ok(
      gatesDaFonte().includes('rkpagina'),
      'CI-01: a suite que guarda RANKING-01 roda e o portao final nao a percorre.'
    );
  });
});

// ---------------------------------------------------------------------------
// CL-09
// ---------------------------------------------------------------------------

describe('CL-09 — um segundo dono de sessao entrando com a Loja', () => {
  // invariante ...... um unico assinante de `authStateChanges` no app inteiro
  // autoridade ...... app/lib/sessao/sessao_firebase.dart
  // proibido ........ a Loja, ao virar alcancavel, ler identidade por conta
  //                   propria. Foi esse o defeito que a Casca de Producao
  //                   extirpou do `main.dart` de previas, e a composicao e a
  //                   hora em que ele pode voltar de carona
  // prova ........... conjunto fechado de assinantes, lido sem comentario
  test('so a camada de sessao assina o estado de autenticacao', () => {
    const donos = [];
    for (const rel of dartsDe('app/lib')) {
      if (/\bauthStateChanges\s*\(|\bidTokenChanges\s*\(/.test(A.codigo(rel))) donos.push(rel);
    }
    assert.deepEqual(
      donos,
      ['app/lib/sessao/sessao_firebase.dart'],
      'SEGUNDA AUTORIDADE DE SESSAO. Dois assinantes divergem em ordem e em ' +
        'momento de logout, e a divergencia aparece como tela de outra pessoa.'
    );
  });

  test('a Loja de producao nao fala com o provedor de identidade', () => {
    const loja = A.codigo('app/lib/casca/loja_de_producao.dart');
    A.exigirAncora(assert, loja, /class\s+LojaDeProducao\b/, 'a Loja de producao existe para ser medida');
    assert.ok(
      !/FirebaseAuth\s*\.\s*instance/.test(loja),
      'a Loja voltou a ler `FirebaseAuth.instance` direto, criando o segundo dono.'
    );
  });
});

// ---------------------------------------------------------------------------
// CL-10
// ---------------------------------------------------------------------------

describe('CL-10 — `playerCourtesyPass` sobrevivendo a exclusao de conta', () => {
  // invariante ...... a decisao `playerCourtesyPass = APAGAR` esta LIGADA ao
  //                   executor da exclusao, e nao so escrita na OS que decidiu
  // autoridade ...... functions-conta/src/inventario.ts
  // proibido ........ a colecao do passe de cortesia sair da matriz de
  //                   retencao. Ela nasceu numa folha (o Passe) e a exclusao
  //                   nasceu noutra: sem a uniao, ninguem podia notar a falta
  // prova ........... a entrada existe na matriz, classificada APAGAR, e a
  //                   suite de emulador da exclusao afirma a remocao
  test('a matriz de retencao classifica o passe de cortesia como APAGAR', () => {
    const inv = A.codigo('functions-conta/src/inventario.ts');
    A.exigirAncora(assert, inv, /CLASSE\s*\.\s*APAGAR/, 'a matriz de retencao usa a classe APAGAR');

    const bloco = inv.match(/playerCourtesyPass[\s\S]{0,800}?classe\s*:\s*CLASSE\.([A-Z]+)/);
    assert.ok(bloco, 'ENTRADA AUSENTE: `playerCourtesyPass` saiu da matriz de retencao da exclusao.');
    assert.equal(bloco[1], 'APAGAR', 'o passe de cortesia deixou de ser apagado na exclusao de conta.');
  });

  test('a suite de emulador da exclusao afirma a remocao, e preserva a de terceiro', () => {
    const suite = A.codigo('functions-conta/test/integracao.emulador.test.js');
    A.exigirAncora(assert, suite, /playerCourtesyPass/, 'a suite exercita a colecao do passe');
    A.exigirAncora(
      assert,
      suite,
      /existe\("playerCourtesyPass\/"\s*\+\s*ALVO\)[\s\S]{0,40}false/,
      'a suite exige que o documento do ALVO deixe de existir'
    );
    A.exigirAncora(
      assert,
      suite,
      /existe\("playerCourtesyPass\/"\s*\+\s*TERCEIRO\)[\s\S]{0,40}true/,
      'a suite exige que o documento de TERCEIRO seja preservado'
    );
  });
});

// ---------------------------------------------------------------------------
// CL-11
// ---------------------------------------------------------------------------

describe('CL-11 — dado de maquete no caminho publicavel da Loja', () => {
  // invariante ...... a casca de producao nao constroi VM de maquete
  // autoridade ...... app/lib/casca/
  // proibido ........ um `LojaVM.mock()` no host publicavel. A maquete segue
  //                   inteira em `app/lib/screens/` de proposito — o que nao
  //                   pode e ela ser ALCANCAVEL. Saldo de maquete e afirmacao
  //                   sobre a carteira de quem instalou; pacote com preco e
  //                   oferta de produto que nao existe
  // prova ........... nenhuma chamada `<Tipo>.mock(` sob `app/lib/casca/`, com
  //                   ancora de que a Loja de producao esta la para ser medida
  test('nenhum arquivo da casca de producao constroi `.mock()`', () => {
    A.exigirAncora(
      assert,
      A.codigo('app/lib/casca/loja_de_producao.dart'),
      /class\s+LojaDeProducao\b/,
      'a Loja publicavel esta na casca'
    );

    const maquete = [];
    for (const rel of dartsDe('app/lib/casca')) {
      const src = A.codigo(rel);
      for (const m of src.matchAll(/\b([A-Z][A-Za-z0-9_]*)\s*\.\s*mock\s*\(/g)) {
        maquete.push(`${rel} :: ${m[1]}.mock(`);
      }
    }
    assert.deepEqual(maquete, [], 'MAQUETE NO CAMINHO PUBLICAVEL.');
  });
});
