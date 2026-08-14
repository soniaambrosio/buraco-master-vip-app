// runner-emulador.test.js — prova a logica DETERMINISTICA do portao.
//
// O que se prova aqui e o que da para provar sem subir o Emulator Suite: leitura
// de relatorio, deteccao de porta, trava com PID, e o comportamento ponta a ponta
// do `com-functions.js` contra um servidor TCP de mentira no lugar do emulador de
// Functions. O que NAO da para provar aqui — que a suite social passa contra as
// Functions reais — e provado pelo proprio alvo `emulador:social`, e duplicar
// isso num teste unitario so criaria um segundo lugar para mentir.
//
// Roda sem emulador, sem java e sem rede externa: `npm run test:runner`.

'use strict';

const { test, describe } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const net = require('node:net');
const os = require('node:os');
const path = require('node:path');
const { spawn } = require('node:child_process');

const {
  portaOcupada,
  esperarPortasLivres,
  processoVivo,
  adquirirTrava,
  liberarTrava,
} = require('./ambiente-emulador');
const {
  lerRelatorio, conferirRelatorio, classificar, CLASSE,
} = require('./relatorio-testes');

// ---------------------------------------------------------------------------
// utilitarios
// ---------------------------------------------------------------------------

/// Sobe um listener numa porta livre escolhida pelo SO e devolve a porta. E o
/// mesmo papel que o emulador faz na vida real: segurar a porta.
function ocupar() {
  return new Promise((resolve) => {
    const servidor = net.createServer();
    servidor.listen(0, '127.0.0.1', () => {
      resolve({ porta: servidor.address().port, fechar: () => new Promise((r) => servidor.close(r)) });
    });
  });
}

/// Pasta descartavel do CASO que a pediu. O `t.after` e o cleanup em si, e nao
/// um lembrete: o node roda o hook quando o caso termina de qualquer jeito —
/// asercao quebrada, comando testado devolvendo erro, excecao no meio, timeout.
/// Era exatamente isso que faltava: `mkdtemp` criava e ninguem removia, entao
/// cada `npm run test:runner` deixava uma duzia de `bmv-trava-*` e `bmv-comfn-*`
/// em `os.tmpdir()` para sempre.
///
/// A pasta e removida pelo CAMINHO que este processo criou, e nunca por padrao:
/// varrer `bmv-*` apagaria o sandbox de uma execucao paralela no meio do uso.
///
/// `force` cobre a pasta que ja sumiu — o cleanup roda mesmo quando o caso
/// falhou antes de terminar de montar o sandbox. Erro de remocao de verdade
/// (arquivo preso, permissao) continua estourando: nao vale trocar lixo real por
/// silencio. Como e hook, e nao corpo do teste, a falha do caso original
/// continua no relatorio ao lado — uma nao apaga a outra.
function pastaTemp(t, nome) {
  const p = fs.mkdtempSync(path.join(os.tmpdir(), `bmv-${nome}-`));
  t.after(() => { fs.rmSync(p, { recursive: true, force: true }); });
  return p;
}

/// Roda `com-functions.js` como processo filho, com um servidor TCP de mentira
/// no lugar do emulador de Functions, e devolve exit code, saida e recibo.
function rodarComFunctions({ t, conteudoDoTeste, esperado, hostFalso }) {
  const dir = pastaTemp(t, 'comfn');
  const arquivo = path.join(dir, 'sintetico.test.js');
  fs.writeFileSync(arquivo, conteudoDoTeste);
  const recibo = path.join(dir, 'recibo.json');

  const args = ['com-functions.js', '--codebase=social'];
  if (esperado !== undefined) args.push(`--esperado=${esperado}`);
  args.push(arquivo);

  // `NODE_TEST_CONTEXT` sai fora. Este arquivo JA roda sob `node --test`, e o
  // neto que o `com-functions.js` abre herdaria a marca: o node veria `--test`
  // dentro de `--test`, avisaria "run() is being called recursively" e nao
  // rodaria arquivo nenhum. O relatorio voltaria vazio — e o portao acusaria
  // corretamente "sem rodape", provando a rede errada.
  const env = { ...process.env, FUNCTIONS_EMULATOR_HOST: hostFalso, BMV_RELATORIO_SAIDA: recibo };
  delete env.NODE_TEST_CONTEXT;

  return new Promise((resolve) => {
    const filho = spawn(process.execPath, args, {
      cwd: __dirname,
      env,
      stdio: ['ignore', 'pipe', 'pipe'],
    });
    let saida = '';
    filho.stdout.on('data', (d) => { saida += d; });
    filho.stderr.on('data', (d) => { saida += d; });
    filho.on('close', (codigo) => {
      const temRecibo = fs.existsSync(recibo);
      resolve({
        codigo,
        saida,
        recibo: temRecibo ? JSON.parse(fs.readFileSync(recibo, 'utf8')) : null,
      });
    });
  });
}

// ---------------------------------------------------------------------------
// leitura do relatorio
// ---------------------------------------------------------------------------

describe('relatorio-testes', () => {
  const rodape = (campos) => Object.entries(campos)
    .map(([k, v]) => `ℹ ${k} ${v}`).join('\n');

  test('le o rodape do reporter spec', () => {
    const r = lerRelatorio(rodape({
      tests: 67, suites: 8, pass: 67, fail: 0, cancelled: 0, skipped: 0, todo: 0,
    }));
    assert.equal(r.tests, 67);
    assert.equal(r.pass, 67);
    assert.equal(r.cancelled, 0);
  });

  test('le o rodape do reporter TAP, com o prefixo #', () => {
    const r = lerRelatorio('# tests 20\n# pass 20\n# fail 0\n# skipped 0\n# cancelled 0\n');
    assert.equal(r.tests, 20);
    assert.equal(r.skipped, 0);
  });

  test('ambiente saudavel: suite integra vira verde', () => {
    const r = lerRelatorio(rodape({ tests: 67, pass: 67, fail: 0, cancelled: 0, skipped: 0 }));
    const c = conferirRelatorio(r, { esperado: 67, alvo: 'social' });
    assert.equal(c.ok, true, c.problemas.join('\n'));
  });

  test('mais casos que o piso continua verde: o piso e piso, e nao igualdade', () => {
    const r = lerRelatorio(rodape({ tests: 70, pass: 70, fail: 0, cancelled: 0, skipped: 0 }));
    assert.equal(conferirRelatorio(r, { esperado: 67 }).ok, true);
  });

  test('CANCELAMENTO no rodape derruba o portao', () => {
    const r = lerRelatorio(rodape({ tests: 67, pass: 60, fail: 0, cancelled: 7, skipped: 0 }));
    const c = conferirRelatorio(r, { esperado: 67 });
    assert.equal(c.ok, false);
    assert.match(c.problemas.join('\n'), /CANCELADO/);
  });

  test('cancelamento marcado NA LINHA derruba mesmo com rodape zerado', () => {
    // O caso real da linha de base desta OS: o pai morreu, os filhos sairam com
    // a marca na linha. Confiar so no rodape deixaria passar.
    const texto = "✖ §18 — bloquear desfaz a amizade\n"
      + "  'test did not finish before its parent and was cancelled'\n"
      + rodape({ tests: 67, pass: 67, fail: 0, cancelled: 0, skipped: 0 });
    const c = conferirRelatorio(lerRelatorio(texto), { esperado: 67 });
    assert.equal(c.ok, false);
    assert.match(c.problemas.join('\n'), /CANCELADO/);
  });

  test('teste PULADO derruba o portao', () => {
    const texto = '﹣ claimPioneerKit (1.1ms) # SKIP\n'
      + rodape({ tests: 20, pass: 19, fail: 0, cancelled: 0, skipped: 1 });
    const c = conferirRelatorio(lerRelatorio(texto), { esperado: 20 });
    assert.equal(c.ok, false);
    assert.match(c.problemas.join('\n'), /PULADO/);
  });

  test('suite ENCURTADA derruba, mesmo sem pulo nem cancelamento no rodape', () => {
    // O buraco cego: um `describe({skip:true})` inteiro nao soma em contador
    // nenhum. Nada aqui denuncia o sumico, exceto o total contra o piso.
    const r = lerRelatorio(rodape({ tests: 61, pass: 61, fail: 0, cancelled: 0, skipped: 0 }));
    const c = conferirRelatorio(r, { esperado: 67, alvo: 'social' });
    assert.equal(c.ok, false);
    assert.match(c.problemas.join('\n'), /rodou 61 caso\(s\), e o piso e 67/);
  });

  test('relatorio SEM rodape e execucao interrompida, e nao aprovacao', () => {
    const c = conferirRelatorio(lerRelatorio('✔ um caso\n✔ outro caso\n'), { esperado: 2 });
    assert.equal(c.ok, false);
    assert.match(c.problemas.join('\n'), /nao chegou ao fim/);
  });

  test('falha de asercao aparece como falha, e nao como problema de ambiente', () => {
    const r = lerRelatorio(rodape({ tests: 67, pass: 66, fail: 1, cancelled: 0, skipped: 0 }));
    const c = conferirRelatorio(r, { esperado: 67 });
    assert.equal(c.ok, false);
    assert.match(c.problemas.join('\n'), /1 teste\(s\) falharam/);
  });
});

// ---------------------------------------------------------------------------
// as tres classes de desfecho
// ---------------------------------------------------------------------------

describe('classificar — falha funcional x infraestrutura x suite incompleta', () => {
  const rodape = (c) => lerRelatorio(
    Object.entries({
      tests: 67, suites: 7, pass: 67, fail: 0, cancelled: 0, skipped: 0, todo: 0, ...c,
    }).map(([k, v]) => `ℹ ${k} ${v}`).join('\n'),
  );
  const caso = (extra = {}) => classificar({
    relatorio: rodape(extra.contadores || {}),
    esperado: 67,
    alvo: 'social',
    codigo: extra.codigo === undefined ? 0 : extra.codigo,
    temRecibo: extra.temRecibo === undefined ? true : extra.temRecibo,
  });

  test('OK: suite integra e verde', () => {
    const v = caso();
    assert.equal(v.classe, CLASSE.OK);
    assert.equal(v.exit, 0);
  });

  test('INFRAESTRUTURA: saiu diferente de zero e nao deixou recibo', () => {
    // A suite nunca rodou. Rotular de `tests=fail` mandaria alguem procurar
    // asercao quebrada onde nao houve teste.
    const v = classificar({ relatorio: null, esperado: null, codigo: 1, temRecibo: false });
    assert.equal(v.classe, CLASSE.INFRA);
    assert.equal(v.exit, 3);
    assert.match(v.problemas.join('\n'), /NAO e uma falha de teste/);
  });

  test('SUITE-INCOMPLETA: saiu ZERO e nao deixou recibo', () => {
    const v = classificar({ relatorio: null, esperado: null, codigo: 0, temRecibo: false });
    assert.equal(v.classe, CLASSE.INCOMPLETA);
    assert.equal(v.exit, 5);
  });

  test('SUITE-INCOMPLETA: piso ausente afrouxaria o portao em silencio', () => {
    const v = classificar({ relatorio: rodape(), esperado: null, codigo: 0, temRecibo: true });
    assert.equal(v.classe, CLASSE.INCOMPLETA);
    assert.equal(v.exit, 5);
  });

  test('FALHA-FUNCIONAL: rodou inteira e uma asercao quebrou', () => {
    const v = caso({ contadores: { pass: 66, fail: 1 }, codigo: 1 });
    assert.equal(v.classe, CLASSE.FUNCIONAL);
    assert.equal(v.exit, 1);
  });

  test('SUITE-INCOMPLETA: cancelamento VENCE falha', () => {
    // A regra que a linha de base desta OS ensinou: bundle ausente -> Function
    // `not-found` -> o pai estoura (fail=1) e 60+ filhos sao cancelados. Se
    // `fail` viesse primeiro, aquilo sairia rotulado como defeito de codigo.
    const v = caso({ contadores: { pass: 6, fail: 1, cancelled: 60 }, codigo: 1 });
    assert.equal(v.classe, CLASSE.INCOMPLETA);
    assert.equal(v.exit, 5);
    assert.match(v.problemas.join('\n'), /CANCELADO/);
    // e a falha real nao pode sumir do relatorio (§11)
    assert.match(v.problemas.join('\n'), /TAMBEM 1 falha\(s\) de asercao/);
  });

  test('SUITE-INCOMPLETA: node saiu ZERO com a suite encolhida', () => {
    // O falso verde mais forte: `node --test` diz 0, rodape sem fail, sem
    // cancelled e ate sem skipped — porque um `describe` pulado inteiro nao
    // soma em contador nenhum. So o piso enxerga.
    const v = caso({ contadores: { tests: 34, pass: 34 }, codigo: 0 });
    assert.equal(v.classe, CLASSE.INCOMPLETA);
    assert.equal(v.exit, 5);
    assert.match(v.problemas.join('\n'), /rodou 34 caso\(s\), e o piso e 67/);
  });

  test('INDETERMINADA: relatorio integro e exit diferente de zero', () => {
    const v = caso({ codigo: 7 });
    assert.equal(v.classe, CLASSE.INDETERMINADA);
    assert.equal(v.exit, 7);
  });

  // ---- dreno ----------------------------------------------------------------

  test('OK: suite passou E as portas drenaram', () => {
    const v = classificar({
      relatorio: rodape(), esperado: 67, alvo: 'social', codigo: 0, temRecibo: true,
      dreno: { ok: true, ocupadas: [] },
    });
    assert.equal(v.classe, CLASSE.OK);
    assert.equal(v.exit, 0);
  });

  test('CLEANUP-INCOMPLETO: suite passou e as portas NAO drenaram', () => {
    // O caso que esta correcao existe para pegar: tudo verde na suite, e a
    // execucao termina prendendo porta. Avisar e sair 0 seria dizer "pode
    // seguir" sobre um ambiente que nao pode receber ninguem.
    const v = classificar({
      relatorio: rodape(), esperado: 67, alvo: 'social', codigo: 0, temRecibo: true,
      dreno: { ok: false, ocupadas: [{ nome: 'firestore', porta: 8080 }] },
    });
    assert.equal(v.classe, CLASSE.CLEANUP);
    assert.notEqual(v.exit, 0);
    assert.equal(v.exit, 6);

    const texto = v.problemas.join('\n');
    // o resultado da suite tem que continuar legivel...
    assert.match(texto, /OS TESTES PASSARAM/);
    assert.match(texto, /tests=67 pass=67 fail=0/);
    // ...e a porta presa tem que estar NOMEADA
    assert.match(texto, /firestore\s+8080/);
    assert.match(texto, /nao pode ser apresentada como sucesso/i);
  });

  test('o dreno nomeia TODAS as portas que ficaram presas', () => {
    const v = classificar({
      relatorio: rodape(), esperado: 67, codigo: 0, temRecibo: true,
      dreno: {
        ok: false,
        ocupadas: [{ nome: 'firestore', porta: 8080 }, { nome: 'hub', porta: 4400 }],
      },
    });
    const texto = v.problemas.join('\n');
    assert.match(texto, /firestore\s+8080/);
    assert.match(texto, /hub\s+4400/);
  });

  test('dreno estourado NAO reescreve um vermelho que ja existia', () => {
    // O dreno vem por ultimo e so age sobre o que ja seria verde: uma asercao
    // quebrada continua sendo FALHA-FUNCIONAL, e nao vira problema de cleanup.
    const v = classificar({
      relatorio: rodape({ pass: 66, fail: 1 }), esperado: 67, codigo: 1, temRecibo: true,
      dreno: { ok: false, ocupadas: [{ nome: 'firestore', porta: 8080 }] },
    });
    assert.equal(v.classe, CLASSE.FUNCIONAL);
    assert.equal(v.exit, 1);
  });

  test('dreno estourado NAO encobre suite incompleta', () => {
    const v = classificar({
      relatorio: rodape({ tests: 34, pass: 34 }), esperado: 67, codigo: 0, temRecibo: true,
      dreno: { ok: false, ocupadas: [{ nome: 'firestore', porta: 8080 }] },
    });
    assert.equal(v.classe, CLASSE.INCOMPLETA);
    assert.equal(v.exit, 5);
  });
});

// ---------------------------------------------------------------------------
// portas
// ---------------------------------------------------------------------------

describe('ambiente-emulador — portas', () => {
  test('ambiente LIVRE: porta sem ninguem escutando', async () => {
    const { porta, fechar } = await ocupar();
    await fechar(); // acabou de vagar
    const r = await portaOcupada(porta);
    assert.equal(r.ocupada, false);
  });

  test('ambiente OCUPADO: porta com listener e detectada', async () => {
    const { porta, fechar } = await ocupar();
    try {
      const r = await portaOcupada(porta);
      assert.equal(r.ocupada, true);
      assert.equal(r.codigo, 'EADDRINUSE');
    } finally {
      await fechar();
    }
  });

  test('fail-fast: timeout 0 desiste na hora e diz QUAL porta', async () => {
    const { porta, fechar } = await ocupar();
    try {
      const r = await esperarPortasLivres([{ nome: 'firestore', porta }], { timeoutMs: 0 });
      assert.equal(r.livre, false);
      assert.equal(r.ocupadas[0].porta, porta);
    } finally {
      await fechar();
    }
  });

  test('espera LIMITADA: entra assim que a porta vaga', async () => {
    const { porta, fechar } = await ocupar();
    setTimeout(fechar, 300);
    const r = await esperarPortasLivres([{ nome: 'firestore', porta }], { timeoutMs: 15_000 });
    assert.equal(r.livre, true);
    assert.ok(r.tentativas >= 1, 'devia ter esperado ao menos uma volta');
  });

  test('a espera nao e infinita: estoura o limite e devolve o ocupante', async () => {
    const { porta, fechar } = await ocupar();
    try {
      const inicio = Date.now();
      const r = await esperarPortasLivres([{ nome: 'firestore', porta }], { timeoutMs: 1200 });
      assert.equal(r.livre, false);
      assert.ok(Date.now() - inicio < 15_000, 'nao pode virar loop infinito');
    } finally {
      await fechar();
    }
  });
});

// ---------------------------------------------------------------------------
// trava
// ---------------------------------------------------------------------------

describe('ambiente-emulador — trava', () => {
  // Pasta nova a cada chamada, e o dono e o caso que chamou: dois casos deste
  // bloco nunca compartilham arquivo de trava, e nenhum limpa o do outro.
  // `ctx`, e nao `t`: neste bloco `t` ja e a trava devolvida por `adquirirTrava`.
  const novoCaminho = (ctx) => path.join(pastaTemp(ctx, 'trava'), 'emulador.lock');

  test('pega a trava quando ninguem esta segurando', (ctx) => {
    const c = novoCaminho(ctx);
    const t = adquirirTrava(c, { alvo: 'social' });
    assert.equal(t.ok, true);
    assert.equal(fs.existsSync(c), true);
    t.liberar();
    assert.equal(fs.existsSync(c), false);
  });

  test('NAO pega quando o dono ainda esta vivo, e diz quem e', (ctx) => {
    const c = novoCaminho(ctx);
    // Dono vivo de verdade: o proprio processo de teste, com outro PID seria
    // chute. `process.pid` esta vivo por definicao enquanto isto roda.
    fs.writeFileSync(c, JSON.stringify({ pid: process.pid, alvo: 'moderacao' }));
    const t = adquirirTrava(c, { alvo: 'social' });
    assert.equal(t.ok, false);
    assert.equal(t.dono.alvo, 'moderacao');
  });

  test('trava OBSOLETA nao bloqueia para sempre: PID morto e roubado', (ctx) => {
    const c = novoCaminho(ctx);
    // PID que com certeza nao existe. `processoVivo` confirma antes de a gente
    // afirmar qualquer coisa sobre ele.
    let pidMorto = 999_999;
    while (processoVivo(pidMorto)) pidMorto -= 1;

    fs.writeFileSync(c, JSON.stringify({ pid: pidMorto, alvo: 'antiga' }));
    const t = adquirirTrava(c, { alvo: 'social' });
    assert.equal(t.ok, true, 'uma execucao morta a Ctrl+C nao pode travar o projeto');
    assert.equal(JSON.parse(fs.readFileSync(c, 'utf8')).alvo, 'social');
    t.liberar();
  });

  test('trava CORROMPIDA e tratada como obsoleta', (ctx) => {
    const c = novoCaminho(ctx);
    fs.writeFileSync(c, 'isto nao e json');
    const t = adquirirTrava(c, { alvo: 'social' });
    assert.equal(t.ok, true);
    t.liberar();
  });

  test('cleanup nao rouba a trava do vizinho', (ctx) => {
    const c = novoCaminho(ctx);
    fs.writeFileSync(c, JSON.stringify({ pid: process.pid + 1, alvo: 'vizinha' }));
    assert.equal(liberarTrava(c), false, 'so o dono pode liberar');
    assert.equal(fs.existsSync(c), true);
  });

  test('liberar uma trava que ja sumiu nao explode', (ctx) => {
    assert.equal(liberarTrava(novoCaminho(ctx)), false);
  });
});

// ---------------------------------------------------------------------------
// com-functions ponta a ponta
// ---------------------------------------------------------------------------

describe('com-functions — portao e recibo', () => {
  test('emulador AUSENTE: falha, e nao pula em silencio', async (t) => {
    // Porta que acabou de vagar: ninguem atende.
    const { porta, fechar } = await ocupar();
    await fechar();
    const r = await rodarComFunctions({
      t,
      conteudoDoTeste: "require('node:test').test('x', () => {});",
      esperado: 1,
      hostFalso: `127.0.0.1:${porta}`,
    });
    assert.notEqual(r.codigo, 0);
    assert.match(r.saida, /nao esta atendendo/);
  });

  test('filho retorna 0 e a suite esta integra: verde COM recibo', async (t) => {
    const { porta, fechar } = await ocupar();
    try {
      const r = await rodarComFunctions({
        t,
        conteudoDoTeste: "const {test}=require('node:test');test('a',()=>{});test('b',()=>{});",
        esperado: 2,
        hostFalso: `127.0.0.1:${porta}`,
      });
      assert.equal(r.codigo, 0, r.saida);
      assert.equal(r.recibo.ok, true);
      assert.equal(r.recibo.relatorio.tests, 2);
      assert.equal(r.recibo.esperado, 2);
    } finally {
      await fechar();
    }
  });

  test('filho retorna ERRO: exit repassado, e o recibo registra a falha', async (t) => {
    const { porta, fechar } = await ocupar();
    try {
      const r = await rodarComFunctions({
        t,
        conteudoDoTeste:
          "const {test}=require('node:test');test('a',()=>{});"
          + "test('quebra',()=>{throw new Error('asercao de negocio')});",
        esperado: 2,
        hostFalso: `127.0.0.1:${porta}`,
      });
      assert.notEqual(r.codigo, 0);
      // §11: a falha real tem que continuar visivel, e nao virar erro generico.
      assert.match(r.saida, /asercao de negocio/);
      assert.equal(r.recibo.ok, false);
      assert.equal(r.recibo.relatorio.fail, 1);
    } finally {
      await fechar();
    }
  });

  test('suite PULADA: exit 0 do node vira vermelho aqui', async (t) => {
    const { porta, fechar } = await ocupar();
    try {
      const r = await rodarComFunctions({
        t,
        conteudoDoTeste:
          "const {test,describe}=require('node:test');"
          + "describe('bloco',{skip:true},()=>{test('um',()=>{});test('dois',()=>{})});"
          + "test('roda',()=>{});",
        esperado: 3,
        hostFalso: `127.0.0.1:${porta}`,
      });
      assert.notEqual(r.codigo, 0, 'pular e falhar neste alvo');
      assert.match(r.saida, /PULADO/);
    } finally {
      await fechar();
    }
  });

  test('suite ENCURTADA abaixo do piso: vermelho', async (t) => {
    const { porta, fechar } = await ocupar();
    try {
      const r = await rodarComFunctions({
        t,
        conteudoDoTeste: "require('node:test').test('so um',()=>{});",
        esperado: 67,
        hostFalso: `127.0.0.1:${porta}`,
      });
      assert.notEqual(r.codigo, 0);
      assert.match(r.saida, /piso e 67/);
    } finally {
      await fechar();
    }
  });

  test('CANCELAMENTO real derruba o portao', async (t) => {
    const { porta, fechar } = await ocupar();
    try {
      // Reproduz o mecanismo da linha de base: o pai estoura e os filhos sao
      // cancelados. Nao e um marcador simulado — e o node cancelando de verdade.
      const r = await rodarComFunctions({
        t,
        conteudoDoTeste:
          "const {test}=require('node:test');"
          + "test('pai',async (t)=>{"
          + "  t.test('filho lento',async()=>{await new Promise(r=>setTimeout(r,5000))});"
          + "  throw new Error('pai morreu antes dos filhos');"
          + "});",
        esperado: 1,
        hostFalso: `127.0.0.1:${porta}`,
      });
      assert.notEqual(r.codigo, 0);
      assert.match(r.saida, /cancelled|pai morreu/i);
    } finally {
      await fechar();
    }
  });
});
