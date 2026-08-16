// leitores.js — transformam a saida crua de cada runner em contagem auditavel.
//
// O PORTAO NAO ACREDITA EM EXIT CODE. Exit code responde "alguma coisa falhou?",
// e o portao precisa de "o que exatamente rodou?". As duas perguntas divergem
// justamente nos casos que interessam: suite pulada, suite cancelada, suite que
// encolheu, runner que morreu antes do rodape. Todos saem 0.
//
// Cada leitor aqui e PURO — texto entra, numero sai — para que o teste do portao
// consiga fixar "esta saida significa suite incompleta" sem rodar Flutter nem
// subir emulador.
//
// A leitura do `node --test` NAO e reimplementada: ela ja existe, provada, em
// `firebase/testes/relatorio-testes.js`. Uma segunda copia divergiria da
// primeira no dia em que o node mudasse o rodape — e as duas continuariam
// verdes enquanto divergiam.

'use strict';

const path = require('node:path');

const RAIZ = path.resolve(__dirname, '..', '..');
const { lerRelatorio } = require(path.join(RAIZ, 'firebase', 'testes', 'relatorio-testes.js'));

/// Contagem canonica do portao. Todo leitor devolve esta forma, para que
/// `veredito.js` nao precise saber de qual runner o numero veio.
function contagem({ testes = null, passou = 0, falhou = 0, pulou = 0, cancelou = 0 } = {}) {
  return { testes, passou, falhou, pulou, cancelou };
}

// ---------------------------------------------------------------------------
// node --test
// ---------------------------------------------------------------------------

/// Le o rodape do `node --test` e diz se a suite se PROVOU inteira.
///
/// `esperado` e PISO, e nao igualdade, pela mesma razao documentada em
/// `relatorio-testes.js`: um caso novo legitimo nao pode ficar devendo uma
/// edicao de configuracao para o portao voltar a fechar, mas um caso que SOME
/// tem que derrubar.
/// O nome do caso numa linha de diretiva SKIP do `node --test`:
///
///     ﹣ registrarDenuncia (0.422ms) # SKIP
///
/// Extrair o NOME, e nao so contar linhas, e o que permite distinguir um pulo
/// declarado de um pulo novo. Contagem sozinha nao distingue: quatro pulos
/// esperados e quatro pulos diferentes dao o mesmo numero.
const NOME_DO_PULO = /^\s*\S*\s*(.+?)\s*\([\d.]+\s*ms\)\s*#\s*SKIP/i;

function nomeDoPulo(linha) {
  const m = String(linha).match(NOME_DO_PULO);
  return m ? m[1].trim() : String(linha).replace(/#\s*SKIP.*$/i, '').trim();
}

function lerNodeTest(texto, opcoes = {}) {
  const { esperado = null, pulosPermitidos = [] } = opcoes;
  const r = lerRelatorio(texto);
  const problemas = [];

  if (r.tests === null) {
    return {
      integra: false,
      contagem: contagem({ testes: null }),
      problemas: ['O `node --test` nao deixou rodape: a execucao nao chegou ao fim.\n'
        + '  Processo morto, emulador derrubado no meio ou saida truncada. Sem\n'
        + '  rodape nao ha o que aprovar.'],
    };
  }

  const c = contagem({
    testes: r.tests,
    passou: r.pass ?? 0,
    falhou: r.fail ?? 0,
    pulou: r.skipped ?? 0,
    cancelou: r.cancelled ?? 0,
  });

  if (c.cancelou > 0 || r.linhasCanceladas.length > 0) {
    problemas.push(`${c.cancelou} caso(s) CANCELADO(S) — abandonados quando o pai morreu.`);
  }
  // PULO DECLARADO x PULO NOVO.
  //
  // Alguns alvos desta arvore pulam blocos DE PROPOSITO, e a decisao esta
  // documentada no `package.json` deles: `emulador:integrado` sobe apenas o
  // Firestore, entao os blocos que CHAMAM Cloud Function saem `# SKIP` ali — e
  // sao provados de verdade pelos alvos `social/moderacao/colecoes`, que sobem
  // Functions e que este portao tambem executa, como obrigatorios.
  //
  // A excecao e NOMINAL, e nunca um contador: cada pulo permitido e declarado
  // pelo nome, no catalogo, junto da suite que o cobre. Um pulo NOVO — bloco que
  // alguem desativou na pressa — nao esta na lista e derruba. Permitir "ate N
  // pulos" nao distinguiria os dois casos, que e a diferenca inteira.
  const permitido = (nome) => pulosPermitidos.some(
    (p) => (p instanceof RegExp ? p.test(nome) : String(p) === nome),
  );
  const pulosVistos = r.diretivasSkip.map(nomeDoPulo);
  const pulosNovos = pulosVistos.filter((n) => !permitido(n));

  if (pulosNovos.length > 0) {
    problemas.push(`${pulosNovos.length} caso(s) PULADO(S) sem declaracao no catalogo:\n`
      + pulosNovos.map((n) => `    ﹣ ${n}`).join('\n')
      + '\n  Este alvo alega provar o que pulou. Um pulo novo e ausencia de prova;\n'
      + '  se ele for legitimo, declare-o em `pulosPermitidos` com a suite que o cobre.');
  }

  // O rodape enxerga um subconjunto do que as diretivas enxergam (um `describe`
  // pulado inteiro nao soma em `skipped`). Se ele acusar MAIS pulos do que as
  // diretivas declaradas explicam, ha pulo que nem apareceu como diretiva.
  if (c.pulou > pulosVistos.length) {
    problemas.push(`O rodape acusa ${c.pulou} pulo(s) e so ${pulosVistos.length} diretiva(s) `
      + 'SKIP apareceram na saida: ha pulo que nao se declarou.');
  }
  if (esperado !== null && c.testes < esperado) {
    problemas.push(`A suite rodou ${c.testes} caso(s) e o piso e ${esperado}: faltou suite.\n`
      + '  Um `describe` pulado inteiro nao soma no rodape, entao o total e a\n'
      + '  UNICA frente que enxerga esse buraco.');
  }

  return { integra: problemas.length === 0, contagem: c, problemas };
}

// ---------------------------------------------------------------------------
// carga dos codebases no Emulator Suite
// ---------------------------------------------------------------------------

/// O EMULADOR PODE SUBIR COM UM CODEBASE QUEBRADO, e a suite so descobre isso
/// como `not-found` em cada chamada.
///
/// Foi medido nesta arvore: `functions-moderacao` estourou o limite de 10s para
/// declarar o backend, o emulador seguiu de pe sem ele, e as 16 chamadas a
/// `registrarDenuncia`/`bloquearJogador` voltaram `FirebaseError: not-found`. O
/// `runner-emulador.js` classificou, com razao pelo que ele enxerga, como
/// FALHA-FUNCIONAL: a suite rodou inteira e as asercoes falharam.
///
/// So que o diagnostico manda para o lugar errado. Ninguem vai achar defeito em
/// `registrarDenuncia` — a Function nunca chegou a existir. Reclassificar isto
/// como IMPEDIDA nao esconde nada (obrigatoria impedida REPROVA do mesmo jeito,
/// exit 4 em vez de 1); muda para onde quem le o vermelho vai olhar.
///
/// A ATRIBUICAO E O PONTO DIFICIL. `--only functions:<codebase>` NAO restringe o
/// carregamento no firebase-tools 15: o emulador percorre TODOS os codebases do
/// `firebase.json`, e varios falham de propositoiu por nao estarem compilados —
/// `functions/lib/index.js` nao existe quando ninguem pediu torneios. Contar
/// qualquer falha de carga como impedimento reprovaria toda execucao, inclusive
/// as que passaram. Por isso a falha e amarrada ao diretorio da linha
/// `Watching "<dir>"` que a precede, e so vale a do codebase sob teste.
const WATCHING = /Watching\s+"([^"]+)"\s+for Cloud Functions/i;
const FALHA_DE_CARGA = /Failed to load function definition from source:\s*(.*)$/i;

function lerCargaDeCodebases(texto) {
  const falhas = [];
  let atual = null;

  for (const linha of String(texto).split('\n')) {
    const w = linha.match(WATCHING);
    if (w) {
      atual = path.basename(w[1].replace(/[\\/]+$/, ''));
      continue;
    }
    const f = linha.match(FALHA_DE_CARGA);
    if (f && atual) falhas.push({ codebase: atual, erro: f[1].trim() });
  }
  return falhas;
}

// ---------------------------------------------------------------------------
// flutter test --machine
// ---------------------------------------------------------------------------

/// `--machine` e nao o reporter humano, e a diferenca decide o portao.
///
/// O reporter `expanded` imprime `+10: All tests passed!`, que e um resumo — e
/// um resumo nao distingue "10 casos passaram" de "10 casos passaram e 4 nem
/// foram descobertos porque o arquivo nao casou com o glob". O `--machine`
/// emite um evento `suite` por ARQUIVO carregado e um `testDone` por caso, o que
/// deixa o portao conferir as duas coisas: quantos casos correram, e se todos os
/// arquivos que ele mandou rodar apareceram.
///
/// `hidden: true` marca as tarefas internas do runner ("loading <arquivo>"), que
/// nao sao teste de ninguem. Conta-las inflaria o total com uma unidade por
/// arquivo — e um total inflado e a maneira mais discreta de esconder uma suite
/// que encolheu.
function lerFlutterMachine(texto, opcoes = {}) {
  const { esperado = null, arquivosPedidos = [] } = opcoes;

  const suites = new Map();   // suiteID -> caminho
  const testes = new Map();   // testID  -> { nome, suiteID, oculto }
  const erros = [];
  let done = null;

  for (const linha of String(texto).split('\n')) {
    const corte = linha.indexOf('{');
    if (corte === -1) continue;
    let e;
    try {
      e = JSON.parse(linha.slice(corte));
    } catch {
      continue; // linha de `pub get`, aviso do toolchain, lixo do shell
    }

    if (e.type === 'suite' && e.suite) {
      suites.set(e.suite.id, e.suite.path);
    } else if (e.type === 'testStart' && e.test) {
      // `oculto` so e conhecido no `testDone`, que e quem traz o campo `hidden`.
      // Aqui ele nasce falso e e corrigido la; um caso que comece e nunca
      // termine fica sem `resultado` e e descartado da contagem logo abaixo.
      testes.set(e.test.id, { nome: e.test.name, suiteID: e.test.suiteID, oculto: false });
    } else if (e.type === 'testDone') {
      const t = testes.get(e.testID);
      if (t) {
        t.oculto = Boolean(e.hidden);
        t.resultado = e.result;
        t.pulado = Boolean(e.skipped);
      }
    } else if (e.type === 'error') {
      erros.push({
        testID: e.testID,
        erro: String(e.error || ''),
        pilha: String(e.stackTrace || ''),
      });
    } else if (e.type === 'done') {
      done = e;
    }
  }

  const visiveis = [...testes.values()].filter((t) => !t.oculto && t.resultado !== undefined);
  const passou = visiveis.filter((t) => t.resultado === 'success' && !t.pulado).length;
  const pulou = visiveis.filter((t) => t.pulado).length;
  const falhou = visiveis.filter((t) => t.resultado !== 'success').length;

  const c = contagem({ testes: visiveis.length, passou, falhou, pulou });
  const problemas = [];

  // AUSENCIA DO EVENTO `done` e o equivalente exato do rodape faltando no
  // `node --test`: o runner morreu no meio. Sem ele, qualquer contagem parcial
  // acima e um retrato de uma execucao que nao terminou.
  if (done === null) {
    return {
      integra: false,
      contagem: c,
      arquivos: [...suites.values()],
      falhaOriginal: null,
      problemas: ['O `flutter test` nao emitiu o evento `done`: a execucao nao chegou\n'
        + '  ao fim. Contagem parcial nao e resultado.'],
    };
  }

  if (pulou > 0) {
    problemas.push(`${pulou} caso(s) PULADO(S) na suite Dart.`);
  }

  // OS ARQUIVOS PEDIDOS TEM QUE TER APARECIDO. Este e o defeito concreto que a
  // arvore ja teve: `flutter test` descobre `*_test.dart` e ignora `teste_*.dart`,
  // e sete arquivos versionados usam o prefixo. Rodados por caminho explicito
  // eles passam — o buraco era de DESCOBERTA, e um portao que so olhasse o exit
  // code nunca o veria. Aqui, um arquivo que foi mandado rodar e nao emitiu
  // evento `suite` derruba a execucao.
  const vistos = new Set([...suites.values()].map((p) => path.resolve(p).toLowerCase()));
  const faltando = arquivosPedidos.filter(
    (a) => !vistos.has(path.resolve(a).toLowerCase()),
  );
  if (faltando.length > 0) {
    problemas.push('Arquivo(s) de teste pedidos que NAO foram carregados pelo runner:\n'
      + faltando.map((f) => `    ${path.relative(RAIZ, f)}`).join('\n')
      + '\n  Este e o buraco de descoberta que ja custou 459 casos invisiveis nesta\n'
      + '  arvore: o runner so acha `*_test.dart`, e ha arquivos `teste_*.dart`.');
  }

  if (esperado !== null && c.testes < esperado) {
    problemas.push(`A suite Dart rodou ${c.testes} caso(s) e o piso e ${esperado}.`);
  }

  // `done.success === false` e falha de asercao: NAO entra em `problemas`, que e
  // a lista de "nao provou". Ela e um veredito legitimo sobre o codigo, e quem
  // decide o que fazer com ela e `veredito.js`. Misturar as duas faria falha
  // funcional ser rotulada como suite incompleta — mandando procurar defeito de
  // ambiente onde ha defeito de codigo.
  const falhaOriginal = erros.length > 0
    ? erros.slice(0, 3).map((e) => {
      const t = testes.get(e.testID);
      const onde = t ? `${t.nome}` : `testID ${e.testID}`;
      return `  ✗ ${onde}\n${e.erro.split('\n').map((l) => `      ${l}`).join('\n')}`;
    }).join('\n\n')
    : null;

  return {
    integra: problemas.length === 0,
    contagem: c,
    arquivos: [...suites.values()],
    falhaOriginal,
    sucesso: done.success !== false,
    problemas,
  };
}

// ---------------------------------------------------------------------------
// flutter analyze
// ---------------------------------------------------------------------------

/// `flutter analyze` nao tem contagem de casos: ele tem achados. O portao usa a
/// mesma politica do CI desta arvore — ERROR reprova, warning e info nao —, e
/// isso e uma decisao registrada, e nao um afrouxamento: a arvore tem avisos
/// conhecidos e pre-existentes, e um portao que reprovasse por eles seria
/// desligado na primeira semana em vez de consertado.
function lerFlutterAnalyze(texto) {
  const linhas = String(texto).split('\n');
  const erros = linhas.filter((l) => /^\s*error\s+•/i.test(l));
  const avisos = linhas.filter((l) => /^\s*warning\s+•/i.test(l));
  const infos = linhas.filter((l) => /^\s*info\s+•/i.test(l));

  return {
    integra: true, // analyze sempre "roda inteiro"; o que varia e o achado
    contagem: contagem({
      testes: erros.length + avisos.length + infos.length,
      passou: avisos.length + infos.length,
      falhou: erros.length,
    }),
    erros,
    avisos: avisos.length,
    infos: infos.length,
    falhaOriginal: erros.length > 0 ? erros.slice(0, 10).map((l) => `  ${l.trim()}`).join('\n') : null,
    problemas: [],
  };
}

// ---------------------------------------------------------------------------
// typecheck (tsc --noEmit)
// ---------------------------------------------------------------------------

/// `tsc --noEmit` nao produz teste nenhum: ele produz ou silencio, ou erros.
/// O portao registra isso como contagem zero DE PROPOSITO, e nao como "1 teste
/// que passou": inventar um caso faria a soma de testes da RC crescer sem que
/// nenhum caso a mais tivesse sido provado.
function lerTypecheck(texto) {
  const erros = String(texto).split('\n').filter((l) => /error TS\d+:/.test(l));
  return {
    integra: true,
    contagem: contagem({ testes: 0, falhou: erros.length }),
    falhaOriginal: erros.length > 0 ? erros.slice(0, 10).map((l) => `  ${l.trim()}`).join('\n') : null,
    problemas: [],
  };
}

module.exports = {
  contagem, lerNodeTest, lerFlutterMachine, lerFlutterAnalyze, lerTypecheck,
  lerCargaDeCodebases, nomeDoPulo, RAIZ,
};
