// portao-rc.test.js — os testes do proprio portao.
//
// UM PORTAO QUE NAO SE PROVA NAO PODE REPROVAR NINGUEM. E o argumento e mais
// forte aqui do que numa suite comum: este codigo e o que decide se uma RC sai.
// Um defeito nele nao aparece como bug de produto — aparece como release
// aprovada que nao devia ter saido, e ninguem procura por ela.
//
// NADA AQUI SOBE EMULADOR, chama Flutter ou toca a rede. E deliberado: a regra
// "teste verde + cleanup vermelho reprova" precisa ser barata de provar, senao
// nao e provada. As entradas sao dados; as saidas sao vereditos.

'use strict';

const { test, describe } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

const { ESTADO, SUITE, SAIDA, decidir, avaliarSuite, avaliarCleanup } = require('./veredito');
const leitores = require('./leitores');
const recibos = require('./recibo');
const catalogo = require('./catalogo');
const ambiente = require('./ambiente');

// ---------------------------------------------------------------------------
// fabricas — so o que cada teste precisa dizer fica explicito
// ---------------------------------------------------------------------------

const suiteOk = (extra = {}) => ({
  chave: 'x', titulo: 'X', obrigatoria: true,
  estado: ESTADO.EXECUTADA, veredito: SUITE.PASS,
  contagem: { testes: 10, passou: 10, falhou: 0, pulou: 0, cancelou: 0 },
  ...extra,
});

const limpo = {
  trava: { residual: false, caminho: '/tmp/x.lock', dono: null },
  orfaos: [],
  portas: { aplicavel: true, drenadas: true, presas: [] },
  arvore: { limpa: true, sujeira: [] },
};

// ---------------------------------------------------------------------------

describe('veredito — o caminho verde', () => {
  test('tudo executado e passando: PASS com exit 0', () => {
    const d = decidir({ suites: [suiteOk(), suiteOk({ chave: 'y' })], ambiente: limpo });
    assert.equal(d.veredito, 'PASS');
    assert.equal(d.saida, SAIDA.PASS);
    assert.deepEqual(d.reprovacoes, []);
  });

  test('o resumo soma casos SO das suites que executaram', () => {
    const d = decidir({
      suites: [
        suiteOk({ contagem: { testes: 7, passou: 7, falhou: 0, pulou: 0, cancelou: 0 } }),
        // Uma suite ausente nao pode emprestar numero nenhum ao total: seria dar
        // a uma RC sem prova a aparencia estatistica de uma RC testada.
        { chave: 'z', obrigatoria: false, estado: ESTADO.AUSENTE, contagem: null },
      ],
      ambiente: limpo,
    });
    assert.equal(d.resumo.testes, 7);
    assert.equal(d.resumo.executadas, 1);
    assert.equal(d.resumo.naoExecutadas, 1);
  });
});

describe('veredito — falha funcional', () => {
  test('suite que rodou inteira e falhou: FAIL com exit 1', () => {
    const d = decidir({
      suites: [suiteOk({ veredito: SUITE.FALHA, falhaOriginal: 'esperado 3, recebido 4' })],
      ambiente: limpo,
    });
    assert.equal(d.veredito, 'FAIL');
    assert.equal(d.saida, SAIDA.FALHA_FUNCIONAL);
  });

  test('a falha ORIGINAL atravessa sem ser reescrita', () => {
    const original = 'AssertionError: apelido normalizado divergiu\n  em chaves.test.js:88';
    const [r] = avaliarSuite(suiteOk({ veredito: SUITE.FALHA, falhaOriginal: original }));
    assert.ok(r.detalhe.includes(original),
      'o portao agrega; ele nao pode traduzir a falha alheia');
  });
});

describe('veredito — ausencia de prova (a regra central)', () => {
  test('suite OBRIGATORIA ausente da arvore: FAIL com exit 5', () => {
    const d = decidir({
      suites: [suiteOk(), { chave: 'ranking', obrigatoria: true, estado: ESTADO.AUSENTE, motivo: 'nao existe aqui' }],
      ambiente: limpo,
    });
    assert.equal(d.veredito, 'FAIL');
    assert.equal(d.saida, SAIDA.SEM_PROVA);
  });

  test('suite OPCIONAL ausente NAO reprova', () => {
    const d = decidir({
      suites: [suiteOk(), { chave: 'ranking', obrigatoria: false, estado: ESTADO.AUSENTE, motivo: 'noutra branch' }],
      ambiente: limpo,
    });
    assert.equal(d.veredito, 'PASS');
  });

  test('suite obrigatoria IMPEDIDA pelo ambiente: FAIL com exit 4', () => {
    const d = decidir({
      suites: [{ chave: 'social-emulador', obrigatoria: true, estado: ESTADO.IMPEDIDA, motivo: 'java ausente' }],
      ambiente: limpo,
    });
    assert.equal(d.saida, SAIDA.AMBIENTE);
  });

  test('execucao PARCIAL nunca vira verde: obrigatoria nao solicitada reprova', () => {
    const d = decidir({
      suites: [suiteOk(), { chave: 'colecoes-emulador', obrigatoria: true, estado: ESTADO.NAO_SOLICITADA, motivo: '--sem-emulador' }],
      ambiente: limpo,
    });
    assert.equal(d.veredito, 'FAIL');
    assert.equal(d.saida, SAIDA.SEM_PROVA);
  });

  test('suite que rodou INCOMPLETA (pulou/cancelou) reprova com exit 5', () => {
    const d = decidir({
      suites: [suiteOk({ veredito: SUITE.INCOMPLETA, problemas: ['3 casos pulados'] })],
      ambiente: limpo,
    });
    assert.equal(d.saida, SAIDA.SEM_PROVA);
    assert.ok(d.reprovacoes[0].detalhe.includes('3 casos pulados'));
  });
});

describe('veredito — cleanup reprova ainda que tudo esteja verde', () => {
  // A regra literal da OS: "teste verde + cleanup vermelho = release reprovada".
  test('trava residual derruba uma execucao inteiramente verde', () => {
    const d = decidir({
      suites: [suiteOk()],
      ambiente: { ...limpo, trava: { residual: true, caminho: '/tmp/bmv.lock', dono: { alvo: 'social', pid: 42 } } },
    });
    assert.equal(d.veredito, 'FAIL');
    assert.equal(d.saida, SAIDA.CLEANUP);
  });

  test('processo orfao derruba', () => {
    const d = decidir({
      suites: [suiteOk()],
      ambiente: { ...limpo, orfaos: [{ pid: 991, descricao: 'firebase emulators' }] },
    });
    assert.equal(d.saida, SAIDA.CLEANUP);
    assert.ok(d.reprovacoes[0].detalhe.includes('991'));
  });

  test('porta nao drenada derruba QUANDO APLICAVEL', () => {
    const d = decidir({
      suites: [suiteOk()],
      ambiente: { ...limpo, portas: { aplicavel: true, drenadas: false, presas: [{ nome: 'firestore', porta: 8080 }] } },
    });
    assert.equal(d.saida, SAIDA.CLEANUP);
  });

  test('porta nao drenada NAO derruba quando nenhum emulador subiu', () => {
    // Cobrar dreno de uma execucao que nunca abriu porta seria reprovar por um
    // recurso que ela nao tocou — e o primeiro reflexo de quem fosse barrado
    // assim seria desligar o portao.
    const d = decidir({
      suites: [suiteOk()],
      ambiente: { ...limpo, portas: { aplicavel: false, drenadas: false, presas: [{ nome: 'firestore', porta: 8080 }] } },
    });
    assert.equal(d.veredito, 'PASS');
  });

  test('arvore suja ao fim derruba', () => {
    const d = decidir({
      suites: [suiteOk()],
      ambiente: { ...limpo, arvore: { limpa: false, sujeira: ['?? app/test/torneios/data/x.json'] } },
    });
    assert.equal(d.saida, SAIDA.CLEANUP);
    assert.ok(d.reprovacoes[0].detalhe.includes('app/test/torneios/data/x.json'));
  });

  test('suite que saiu com CLEANUP-INCOMPLETO derruba, ainda que as portas tenham drenado depois', () => {
    // O portao mede as portas no FIM de tudo, e ate la elas ja drenaram — o rabo
    // dura segundos. Se so o retrato final valesse, o estrago sumiria do recibo.
    const d = decidir({
      suites: [suiteOk()],
      ambiente: {
        ...limpo,
        portas: { aplicavel: true, drenadas: true, presas: [] },
        suitesComCleanupRuim: ['social-emulador: o runner saiu com classe CLEANUP-INCOMPLETO (exit 6)'],
      },
    });
    assert.equal(d.veredito, 'FAIL');
    assert.equal(d.saida, SAIDA.CLEANUP);
    assert.ok(d.reprovacoes[0].detalhe.includes('social-emulador'));
  });

  test('os cinco sinais de cleanup sao independentes e somam', () => {
    const fora = avaliarCleanup({
      trava: { residual: true, caminho: '/t', dono: null },
      orfaos: [{ pid: 1 }],
      portas: { aplicavel: true, drenadas: false, presas: [{ nome: 'a', porta: 1 }] },
      suitesComCleanupRuim: ['x: exit 6'],
      arvore: { limpa: false, sujeira: ['x'] },
    });
    assert.equal(fora.length, 5);
  });
});

describe('veredito — precedencia do codigo de saida', () => {
  test('ausencia de prova vence falha funcional', () => {
    // Anunciar "falha funcional" numa execucao com suite obrigatoria faltando
    // mandaria cacar asercao quebrada — e, pior, declararia que o resto foi
    // provado.
    const d = decidir({
      suites: [
        suiteOk({ chave: 'a', veredito: SUITE.FALHA, falhaOriginal: 'x' }),
        { chave: 'b', obrigatoria: true, estado: ESTADO.AUSENTE, motivo: 'sumiu' },
      ],
      ambiente: limpo,
    });
    assert.equal(d.saida, SAIDA.SEM_PROVA);
    assert.equal(d.reprovacoes.length, 2, 'os dois motivos continuam no relatorio');
  });

  test('falha funcional vence cleanup', () => {
    const d = decidir({
      suites: [suiteOk({ veredito: SUITE.FALHA, falhaOriginal: 'x' })],
      ambiente: { ...limpo, trava: { residual: true, caminho: '/t', dono: null } },
    });
    assert.equal(d.saida, SAIDA.FALHA_FUNCIONAL);
  });

  test('a ordem das suites na lista NAO muda a classe do vermelho', () => {
    const a = { chave: 'a', obrigatoria: true, estado: ESTADO.AUSENTE, motivo: 'x' };
    const b = suiteOk({ chave: 'b', veredito: SUITE.FALHA, falhaOriginal: 'y' });
    assert.equal(
      decidir({ suites: [a, b], ambiente: limpo }).saida,
      decidir({ suites: [b, a], ambiente: limpo }).saida,
    );
  });
});

describe('recibo — antigo nao pode passar por atual', () => {
  const base = (extra = {}) => ({
    formato: 'portao-rc/1',
    veredito: 'PASS',
    execucao: {
      execucaoId: 'abc',
      terminadoEm: new Date('2026-08-14T10:00:00Z').toISOString(),
      perfil: 'completo',
      git: { commit: 'commit-atual' },
      ...extra,
    },
  });
  const agora = Date.parse('2026-08-14T11:00:00Z');

  test('recibo do commit atual, recente e completo: vale', () => {
    const v = recibos.conferirValidade(base(), { commitAtual: 'commit-atual', agora });
    assert.equal(v.valido, true);
  });

  test('recibo de OUTRO COMMIT nao vale', () => {
    const v = recibos.conferirValidade(base(), { commitAtual: 'outro-commit', agora });
    assert.equal(v.valido, false);
    assert.ok(v.recusas.some((r) => r.includes('OUTRO COMMIT')));
  });

  test('recibo VELHO demais nao vale', () => {
    const v = recibos.conferirValidade(base(), {
      commitAtual: 'commit-atual',
      agora: Date.parse('2026-08-16T11:00:00Z'),
    });
    assert.equal(v.valido, false);
    assert.ok(v.recusas.some((r) => /\dh \(limite/.test(r)));
  });

  test('recibo sem `terminadoEm` e de execucao que nao acabou', () => {
    const r = base();
    delete r.execucao.terminadoEm;
    const v = recibos.conferirValidade(r, { commitAtual: 'commit-atual', agora });
    assert.equal(v.valido, false);
  });

  test('recibo de execucao PARCIAL nao assina RC', () => {
    const v = recibos.conferirValidade(base({ perfil: 'parcial' }), { commitAtual: 'commit-atual', agora });
    assert.equal(v.valido, false);
  });

  test('ausencia de recibo NAO e aprovacao', () => {
    assert.equal(recibos.conferirValidade(null, {}).valido, false);
    assert.equal(recibos.conferirValidade({ formato: 'outro' }, {}).valido, false);
  });

  test('recibo de OUTRA execucao no lugar do desta reprova a corrida', () => {
    const d = decidir({
      suites: [suiteOk()],
      ambiente: limpo,
      execucao: { execucaoId: 'meu', reciboConflitante: 'de-outra-corrida' },
    });
    assert.equal(d.veredito, 'FAIL');
    assert.equal(d.saida, SAIDA.SEM_PROVA);
  });

  test('o conflito e visto ANTES de gravar, e o arquivo guarda o veredito final', () => {
    // Na ordem inversa, o recibo no disco diria PASS enquanto a tela dizia FAIL
    // — e o documento e justamente o que sobrevive para ser lido depois.
    const raiz = fs.mkdtempSync(path.join(os.tmpdir(), 'portao-rc-conflito-'));
    try {
      fs.mkdirSync(path.join(raiz, '.portao-rc'));
      fs.writeFileSync(path.join(raiz, '.portao-rc', 'ultimo.json'), JSON.stringify({
        formato: 'portao-rc/1', veredito: 'PASS', execucao: { execucaoId: 'de-outra-corrida' },
      }));

      assert.equal(recibos.conflitoAnterior(raiz, 'a-minha'), 'de-outra-corrida');
      assert.equal(recibos.conflitoAnterior(raiz, 'de-outra-corrida'), null);

      const d = decidir({
        suites: [suiteOk()],
        ambiente: limpo,
        execucao: { execucaoId: 'a-minha', reciboConflitante: 'de-outra-corrida' },
      });
      recibos.gravar(raiz, { execucaoId: 'a-minha', git: {} }, { veredito: d.veredito, saida: d.saida });

      const gravado = JSON.parse(fs.readFileSync(path.join(raiz, '.portao-rc', 'ultimo.json'), 'utf8'));
      assert.equal(gravado.veredito, 'FAIL');
      assert.equal(gravado.saida, SAIDA.SEM_PROVA);
    } finally {
      fs.rmSync(raiz, { recursive: true, force: true });
    }
  });

  test('limparAnteriores remove recibo e ponteiro', () => {
    const raiz = fs.mkdtempSync(path.join(os.tmpdir(), 'portao-rc-teste-'));
    try {
      fs.mkdirSync(path.join(raiz, '.portao-rc'));
      fs.writeFileSync(path.join(raiz, '.portao-rc', 'recibo-velho.json'), '{}');
      fs.writeFileSync(path.join(raiz, '.portao-rc', 'ultimo.json'), '{}');
      const removidos = recibos.limparAnteriores(raiz);
      assert.equal(removidos.length, 2);
      assert.equal(fs.readdirSync(path.join(raiz, '.portao-rc')).length, 0);
    } finally {
      fs.rmSync(raiz, { recursive: true, force: true });
    }
  });
});

describe('leitores — flutter test --machine', () => {
  const evento = (o) => `${JSON.stringify(o)}\n`;
  const corrida = ({ arquivos = ['/r/app/test/a_test.dart'], casos = [], done = true } = {}) => {
    let t = '';
    arquivos.forEach((p, i) => { t += evento({ type: 'suite', suite: { id: i, path: p } }); });
    casos.forEach((cs, i) => {
      t += evento({ type: 'testStart', test: { id: i + 1, name: cs.nome, suiteID: 0 } });
      if (cs.erro) t += evento({ type: 'error', testID: i + 1, error: cs.erro });
      t += evento({ type: 'testDone', testID: i + 1, result: cs.resultado || 'success', hidden: Boolean(cs.oculto), skipped: Boolean(cs.pulado) });
    });
    if (done) t += evento({ type: 'done', success: casos.every((cs) => (cs.resultado || 'success') === 'success') });
    return t;
  };

  test('conta so casos visiveis; tarefas `hidden` do runner nao entram', () => {
    const r = leitores.lerFlutterMachine(corrida({
      casos: [{ nome: 'loading a', oculto: true }, { nome: 'ENCERR-01' }, { nome: 'ENCERR-02' }],
    }));
    assert.equal(r.contagem.testes, 2, 'as tarefas de carregamento nao sao teste de ninguem');
    assert.equal(r.contagem.passou, 2);
    assert.equal(r.integra, true);
  });

  test('sem evento `done`, a execucao nao chegou ao fim', () => {
    const r = leitores.lerFlutterMachine(corrida({ casos: [{ nome: 'a' }], done: false }));
    assert.equal(r.integra, false);
    assert.ok(r.problemas[0].includes('done'));
  });

  test('arquivo pedido que o runner NAO carregou derruba', () => {
    // O buraco de descoberta desta arvore: `flutter test` acha `*_test.dart` e
    // ignora `teste_*.dart`. Sem esta frente, 459 casos ficavam invisiveis e o
    // portao continuava verde.
    const r = leitores.lerFlutterMachine(
      corrida({ arquivos: ['/r/app/test/a_test.dart'], casos: [{ nome: 'a' }] }),
      { arquivosPedidos: ['/r/app/test/a_test.dart', '/r/app/test/teste_motor.dart'] },
    );
    assert.equal(r.integra, false);
    assert.ok(r.problemas.some((p) => p.includes('teste_motor.dart')));
  });

  test('caso pulado derruba a integridade', () => {
    const r = leitores.lerFlutterMachine(corrida({ casos: [{ nome: 'a', pulado: true }] }));
    assert.equal(r.contagem.pulou, 1);
    assert.equal(r.integra, false);
  });

  test('falha de asercao NAO e suite incompleta: e veredito sobre o codigo', () => {
    const r = leitores.lerFlutterMachine(corrida({
      casos: [{ nome: 'ENCERR-03', resultado: 'failure', erro: 'Expected: 3\n  Actual: 4' }],
    }));
    assert.equal(r.integra, true, 'a suite rodou inteira');
    assert.equal(r.sucesso, false);
    assert.equal(r.contagem.falhou, 1);
    assert.ok(r.falhaOriginal.includes('Actual: 4'));
  });

  test('piso: suite que encolheu derruba', () => {
    const r = leitores.lerFlutterMachine(corrida({ casos: [{ nome: 'a' }] }), { esperado: 900 });
    assert.equal(r.integra, false);
  });
});

describe('leitores — node --test', () => {
  const rodape = (o) => Object.entries(o).map(([k, v]) => `ℹ ${k} ${v}`).join('\n');

  test('rodape integro vira PASS', () => {
    const r = leitores.lerNodeTest(rodape({ tests: 40, pass: 40, fail: 0, cancelled: 0, skipped: 0, todo: 0 }));
    assert.equal(r.integra, true);
    assert.equal(r.contagem.testes, 40);
  });

  test('sem rodape, a execucao nao chegou ao fim', () => {
    const r = leitores.lerNodeTest('✔ um caso qualquer\n');
    assert.equal(r.integra, false);
    assert.equal(r.contagem.testes, null);
  });

  test('caso pulado e caso cancelado derrubam a integridade', () => {
    const pulado = leitores.lerNodeTest(rodape({ tests: 10, pass: 9, fail: 0, cancelled: 0, skipped: 1, todo: 0 }));
    assert.equal(pulado.integra, false);
    const cancelado = leitores.lerNodeTest(rodape({ tests: 10, pass: 9, fail: 0, cancelled: 1, skipped: 0, todo: 0 }));
    assert.equal(cancelado.integra, false);
  });

  test('pulo DECLARADO no catalogo nao derruba; pulo NOVO derruba', () => {
    // `emulador:integrado` sobe so o Firestore, entao os blocos que chamam
    // Cloud Function saem `# SKIP` de proposito — e sao provados pelas outras
    // tres suites de emulador. A excecao e nominal: ela nao dispensa a prova,
    // diz onde a prova mora.
    const saida = [
      '﹣ registrarDenuncia (0.422ms) # SKIP',
      '﹣ claimPioneerKit (0.199ms) # SKIP',
      rodape({ tests: 105, pass: 105, fail: 0, cancelled: 0, skipped: 0, todo: 0 }),
    ].join('\n');

    const declarados = leitores.lerNodeTest(saida, {
      esperado: 105, pulosPermitidos: ['registrarDenuncia', 'claimPioneerKit'],
    });
    assert.equal(declarados.integra, true);

    const semDeclarar = leitores.lerNodeTest(saida, {
      esperado: 105, pulosPermitidos: ['registrarDenuncia'],
    });
    assert.equal(semDeclarar.integra, false);
    assert.ok(semDeclarar.problemas[0].includes('claimPioneerKit'));
  });

  test('permitir e por NOME, e nunca por contagem', () => {
    // Quatro pulos esperados e quatro pulos DIFERENTES dao o mesmo numero. Um
    // portao que contasse aceitaria a troca sem ver.
    const saida = [
      '﹣ um bloco novo que alguem desativou (0.4ms) # SKIP',
      rodape({ tests: 105, pass: 105, fail: 0, cancelled: 0, skipped: 0, todo: 0 }),
    ].join('\n');
    const r = leitores.lerNodeTest(saida, { esperado: 105, pulosPermitidos: ['registrarDenuncia'] });
    assert.equal(r.integra, false);
  });

  test('rodape que acusa mais pulos do que as diretivas explicam derruba', () => {
    const r = leitores.lerNodeTest(
      rodape({ tests: 10, pass: 9, fail: 0, cancelled: 0, skipped: 3, todo: 0 }),
      { pulosPermitidos: [/./] },
    );
    assert.equal(r.integra, false);
    assert.ok(r.problemas.some((p) => p.includes('nao se declarou')));
  });

  test('cancelamento NUNCA e perdoavel, nem com pulo declarado', () => {
    const r = leitores.lerNodeTest(
      rodape({ tests: 10, pass: 9, fail: 0, cancelled: 1, skipped: 0, todo: 0 }),
      { pulosPermitidos: [/./] },
    );
    assert.equal(r.integra, false);
  });

  test('piso: suite abaixo do minimo derruba mesmo com tudo passando', () => {
    const r = leitores.lerNodeTest(
      rodape({ tests: 3, pass: 3, fail: 0, cancelled: 0, skipped: 0, todo: 0 }), { esperado: 40 },
    );
    assert.equal(r.integra, false);
    assert.ok(r.problemas[0].includes('piso'));
  });
});

describe('leitores — carga dos codebases no Emulator Suite', () => {
  // O caso real, medido nesta arvore: `functions-moderacao` estourou o limite
  // de 10s para declarar o backend, o emulador seguiu de pe SEM ele, e as 16
  // chamadas voltaram `not-found`. O runner classificou como FALHA-FUNCIONAL,
  // mandando procurar defeito numa Function que nunca existiu naquela execucao.
  const saida = [
    'i  functions: Watching "F:\\repo\\firebase\\functions" for Cloud Functions...',
    "!!  functions: Failed to load function definition from source: Error: Cannot find module 'firebase-functions'",
    'i  functions: Watching "F:\\repo\\functions-moderacao" for Cloud Functions...',
    '!!  functions: Failed to load function definition from source: FirebaseError: User code failed to load. Timeout after 10000.',
    'i  functions: Watching "F:\\repo\\functions-social" for Cloud Functions...',
    'i  functions: Loaded functions definitions from source: enviarSolicitacaoAmizade.',
  ].join('\n');

  test('atribui cada falha de carga ao codebase da linha `Watching` anterior', () => {
    const falhas = leitores.lerCargaDeCodebases(saida);
    assert.deepEqual(falhas.map((f) => f.codebase), ['functions', 'functions-moderacao']);
    assert.ok(falhas[1].erro.includes('Timeout after 10000'));
  });

  test('codebase que carregou nao aparece como falha', () => {
    const falhas = leitores.lerCargaDeCodebases(saida);
    assert.equal(falhas.some((f) => f.codebase === 'functions-social'), false);
  });

  test('falha de carga de OUTRO codebase nao pode condenar o alvo', () => {
    // `--only functions:<x>` nao restringe o carregamento no firebase-tools 15:
    // o emulador percorre todos os codebases, e varios falham de propósito por
    // nao estarem compilados. Contar qualquer falha reprovaria ate as execucoes
    // que passaram — inclusive a do social, que rodou 67 casos verdes com estas
    // mesmas linhas na saida.
    const falhas = leitores.lerCargaDeCodebases(saida);
    const doSocial = falhas.filter((f) => f.codebase === 'functions-social');
    assert.deepEqual(doSocial, []);
  });

  test('saida sem `Watching` nao inventa atribuicao', () => {
    const falhas = leitores.lerCargaDeCodebases(
      '!!  functions: Failed to load function definition from source: qualquer coisa',
    );
    assert.deepEqual(falhas, []);
  });
});

describe('leitores — analyze e typecheck', () => {
  test('analyze: ERROR reprova, warning e info nao', () => {
    const r = leitores.lerFlutterAnalyze([
      '   info • Unused import • lib/a.dart:1:1 • unused_import',
      '   warning • Dead code • lib/b.dart:9:3 • dead_code',
      '   error • Undefined name "x" • lib/c.dart:4:2 • undefined_identifier',
    ].join('\n'));
    assert.equal(r.contagem.falhou, 1);
    assert.equal(r.avisos, 1);
    assert.equal(r.infos, 1);
    assert.ok(r.falhaOriginal.includes('Undefined name'));
  });

  test('typecheck limpo nao inventa caso de teste', () => {
    // Contar `tsc --noEmit` como "1 teste que passou" faria a soma de casos da
    // RC crescer sem que nada a mais tivesse sido provado.
    const r = leitores.lerTypecheck('');
    assert.equal(r.contagem.testes, 0);
    assert.equal(r.contagem.falhou, 0);
  });

  test('typecheck com erro TS reprova', () => {
    const r = leitores.lerTypecheck("src/a.ts(4,9): error TS2322: Type 'string' is not assignable.");
    assert.equal(r.contagem.falhou, 1);
  });
});

describe('catalogo — descoberta da suite Dart', () => {
  const { achados, ignorados } = catalogo.descobrirSuitesDart(leitores.RAIZ);

  test('acha os arquivos com prefixo `teste_`, invisiveis ao glob do flutter', () => {
    const comPrefixo = achados.filter((a) => a.prefixoTeste);
    assert.ok(comPrefixo.length >= 6,
      `esperava >=6 arquivos \`teste_\`, achei ${comPrefixo.length}`);
    assert.ok(achados.some((a) => a.caminho === 'test/teste_motor.dart'));
    assert.ok(achados.some((a) => a.caminho === 'test/moderacao/teste_moderacao.dart'));
  });

  test('acha tambem os `*_test.dart` que o CI escrito a mao esqueceu', () => {
    // `test/rastreabilidade/` inteiro esta fora da lista literal do
    // ci-os-integracao.yml. A varredura o traz de volta sem depender de alguem
    // lembrar de editar uma lista.
    assert.ok(achados.some((a) => a.caminho.startsWith('test/rastreabilidade/')));
  });

  test('arquivo de apoio sem casos fica de fora, e o motivo e registrado', () => {
    const f = ignorados.find((i) => i.caminho === 'test/rastreabilidade/ferramentas.dart');
    assert.ok(f, 'ferramentas.dart e biblioteca, nao suite');
    assert.equal(f.porDecisao, false);
  });

  test('exclusao por DECISAO carrega motivo e e distinguivel de apoio', () => {
    const e = ignorados.find((i) => i.caminho === 'test/colecoes/evidencias_visuais_test.dart');
    assert.ok(e);
    assert.equal(e.porDecisao, true);
    assert.ok(e.motivo.includes('fonte do sistema'));
  });

  test('pareceSuite separa biblioteca de suite', () => {
    assert.equal(catalogo.pareceSuite('void main() { test("a", () {}); }'), true);
    assert.equal(catalogo.pareceSuite('String ajuda() => "x";'), false);
    assert.equal(catalogo.pareceSuite('void main() { print("sem casos"); }'), false);
  });
});

describe('catalogo — politica', () => {
  test('toda suite obrigatoria declara como ser detectada', () => {
    for (const s of catalogo.SUITES.filter((x) => x.obrigatoria)) {
      assert.ok(s.requerArquivos && s.requerArquivos.length,
        `${s.chave}: sem \`requerArquivos\`, o portao nao saberia distinguir `
        + 'ausente de quebrado — e "nao executado por erro de descoberta" e '
        + 'exatamente o que a politica proibe');
    }
  });

  test('toda frente fora da base declara ONDE ela vive', () => {
    for (const s of catalogo.SUITES.filter((x) => x.foraDaBase)) {
      assert.ok(s.foraDaBase.onde && s.foraDaBase.motivo,
        `${s.chave}: ausencia declarada sem endereco vira silencio, e silencio e lido como cobertura`);
    }
  });

  test('todo pulo declarado aponta uma suite que o cobre, e ela e OBRIGATORIA', () => {
    // Esta e a amarra que torna `pulosPermitidos` honesto. A excecao so vale
    // porque o bloco pulado e provado por OUTRA suite deste mesmo portao. Se
    // essa suite sumisse do catalogo, ou deixasse de ser obrigatoria, os pulos
    // virariam buraco real — e o portao continuaria verde sem esta conferencia.
    for (const s of catalogo.SUITES.filter((x) => x.pulosPermitidos)) {
      assert.ok(s.cobertoPor && s.cobertoPor.length,
        `${s.chave}: declara pulos sem dizer quem os cobre`);
      for (const chave of s.cobertoPor) {
        const cobre = catalogo.SUITES.find((x) => x.chave === chave);
        assert.ok(cobre, `${s.chave}: aponta \`${chave}\`, que nao existe no catalogo`);
        assert.equal(cobre.obrigatoria, true,
          `${s.chave}: \`${chave}\` cobre um pulo declarado, entao nao pode ser opcional`);
      }
    }
  });

  test('as chaves sao unicas', () => {
    const chaves = catalogo.SUITES.map((s) => s.chave);
    assert.equal(new Set(chaves).size, chaves.length);
  });

  test('as frentes da OS estao todas no catalogo', () => {
    const frentes = new Set(catalogo.SUITES.map((s) => s.frente));
    for (const f of ['Flutter', 'Servidor', 'Ranking', 'Social', 'Moderacao',
      'Billing', 'Functions', 'Firestore Rules', 'Integracao', 'Runners de emulador']) {
      assert.ok(frentes.has(f), `frente ausente do catalogo: ${f}`);
    }
  });
});

describe('ambiente', () => {
  test('a lista de portas do portao bate com a do runner-emulador', () => {
    // Duplicacao consciente (o runner nao exporta a lista). Este teste e o que
    // impede as duas de divergirem em silencio — uma porta a menos aqui faria o
    // portao declarar dreno ok sobre um emulador ainda de pe.
    const fonte = fs.readFileSync(
      path.join(leitores.RAIZ, 'firebase', 'testes', 'runner-emulador.js'), 'utf8',
    );
    const bloco = fonte.slice(fonte.indexOf('const PORTAS = ['), fonte.indexOf('];', fonte.indexOf('const PORTAS = [')));
    const doRunner = [...bloco.matchAll(/porta:\s*(\d+)/g)].map((m) => Number(m[1]));
    assert.deepEqual(
      ambiente.PORTAS.map((p) => p.porta).sort((a, b) => a - b),
      doRunner.sort((a, b) => a - b),
    );
  });

  test('o env dos filhos leva a folga de descoberta dos codebases', () => {
    // Sem ela, `functions-moderacao` estoura os 10s padrao, o emulador sobe sem
    // o codebase e as chamadas voltam `not-found` — reprovando por asercao uma
    // Function que nunca existiu. Nao afrouxa nada: nenhuma asercao muda, e um
    // codebase que ainda assim nao carregar reprova como IMPEDIDA.
    const env = ambiente.ambienteComJava({ achado: true, doPath: true }, { PATH: '/bin' });
    assert.equal(env.FUNCTIONS_DISCOVERY_TIMEOUT, ambiente.DESCOBERTA_S);
    assert.ok(Number(env.FUNCTIONS_DISCOVERY_TIMEOUT) > 10,
      'o padrao do firebase-tools e 10s, que e justamente o que nao basta aqui');
  });

  test('java fora do PATH entra no PATH dos filhos, sem perder a folga', () => {
    const env = ambiente.ambienteComJava(
      { achado: true, doPath: false, caminho: 'C:/jdk/bin/java.exe', javaHome: 'C:/jdk' },
      { PATH: '/bin' },
    );
    assert.equal(env.JAVA_HOME, 'C:/jdk');
    assert.ok(env.PATH.includes('jdk'));
    assert.equal(env.FUNCTIONS_DISCOVERY_TIMEOUT, ambiente.DESCOBERTA_S);
  });

  test('conferirOrfaos so acusa processo que o portao registrou e que segue vivo', () => {
    assert.deepEqual(ambiente.conferirOrfaos([{ pid: 999_999_999, descricao: 'inexistente' }]), []);
    const vivos = ambiente.conferirOrfaos([{ pid: process.pid, descricao: 'este processo' }]);
    assert.equal(vivos.length, 1);
  });

  test('filho que ja fechou nao e reconferido: PID reusado nao vira orfao', () => {
    // Numa execucao de dezenas de minutos o sistema recicla PIDs. Reconferir um
    // filho ja encerrado acusaria orfao onde ha um processo alheio que apenas
    // herdou o numero. O que escapa daqui (neto sobrevivente, tipicamente a JVM
    // do Firestore) e pego pelo teste de bind nas portas.
    const fechado = { pid: process.pid, descricao: 'fechou faz tempo', morto: true };
    assert.deepEqual(ambiente.conferirOrfaos([fechado]), []);
  });

  test('conferirArvore perdoa a sujeira de PARTIDA e cobra so a nova', () => {
    // Quem roda o portao com trabalho em andamento nao pode ser acusado do
    // proprio rascunho; o portao responde pelo que ELE sujou.
    const raiz = fs.mkdtempSync(path.join(os.tmpdir(), 'portao-rc-arvore-'));
    try {
      const { execFileSync } = require('node:child_process');
      const git = (...a) => execFileSync('git', ['-C', raiz, ...a], { stdio: 'ignore' });
      git('init', '-q');
      git('config', 'user.email', 'x@y.z');
      git('config', 'user.name', 'teste');
      fs.writeFileSync(path.join(raiz, 'a.txt'), 'a');
      git('add', '.');
      git('commit', '-qm', 'base');

      fs.writeFileSync(path.join(raiz, 'rascunho.txt'), 'do usuario');
      const antes = ['?? rascunho.txt'];
      assert.equal(ambiente.conferirArvore(raiz, antes).limpa, true);

      fs.writeFileSync(path.join(raiz, 'lixo-do-portao.txt'), 'encenacao esquecida');
      const depois = ambiente.conferirArvore(raiz, antes);
      assert.equal(depois.limpa, false);
      assert.deepEqual(depois.sujeira, ['?? lixo-do-portao.txt']);
    } finally {
      fs.rmSync(raiz, { recursive: true, force: true });
    }
  });

  test('encenacao montada e desmontada nao deixa rastro', () => {
    const raiz = fs.mkdtempSync(path.join(os.tmpdir(), 'portao-rc-cena-'));
    try {
      fs.mkdirSync(path.join(raiz, 'app', 'data', 'torneios'), { recursive: true });
      fs.mkdirSync(path.join(raiz, 'app', 'test', 'torneios'), { recursive: true });
      fs.writeFileSync(path.join(raiz, 'app', 'data', 'torneios', 'seed.json'), '{}');

      const criados = ambiente.montarEncenacao(raiz);
      assert.ok(fs.existsSync(path.join(raiz, 'app', 'test', 'torneios', 'data', 'seed.json')));

      ambiente.desmontarEncenacao(criados);
      assert.equal(fs.existsSync(path.join(raiz, 'app', 'test', 'torneios', 'data')), false);
    } finally {
      fs.rmSync(raiz, { recursive: true, force: true });
    }
  });
});
