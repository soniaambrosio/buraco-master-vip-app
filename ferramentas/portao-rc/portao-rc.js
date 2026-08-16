#!/usr/bin/env node
// portao-rc.js — o portao unico de Release Candidate do Buraco Master VIP.
//
// UMA PERGUNTA, UMA RESPOSTA:
//
//     esta Release Candidate esta apta a prosseguir?
//
// e a resposta e PASS ou FAIL, com codigo de saida correspondente, a lista do
// que rodou, a lista do que NAO rodou, quantos casos foram provados, a falha
// original preservada, o estado do encerramento e um recibo assinado desta
// execucao — e nao de nenhuma outra.
//
// USO
//
//   node ferramentas/portao-rc/portao-rc.js               execucao completa
//   node ferramentas/portao-rc/portao-rc.js --sem-emulador  so o que nao precisa de JVM
//   node ferramentas/portao-rc/portao-rc.js --apenas=billing,social-puro
//   node ferramentas/portao-rc/portao-rc.js --exigir=ranking
//   node ferramentas/portao-rc/portao-rc.js --conferir     le o ultimo recibo
//   node ferramentas/portao-rc/portao-rc.js --listar       mostra o catalogo
//
// EXECUCAO PARCIAL NUNCA E PASS. `--apenas` e `--sem-emulador` existem para
// depurar, e o portao continua respondendo a mesma pergunta: as suites
// obrigatorias que ficaram de fora entram no relatorio como NAO SOLICITADAS e
// reprovam, com exit 5. Um perfil que pudesse sair verde seria um interruptor
// para desligar o portao, e um portao com interruptor nao e portao.
//
// O QUE ESTE ARQUIVO NAO FAZ, de proposito:
//
//   ﹣ nao reescreve falha de teste. O texto original do runner atravessa inteiro
//     ate o relatorio. A camada de agregacao nao pode transformar falha funcional
//     em erro generico;
//   ﹣ nao repete suite vermelha. Repetir teste ate passar e a definicao de
//     portao mentiroso. A UNICA repeticao que existe nesta arvore e a do
//     `runner-emulador.js`, para o caso em que o emulador nao chegou a subir por
//     porta — e ela e limitada a uma vez e so para quem nao deixou recibo;
//   ﹣ nao tem default de sucesso. Nada aqui usa `?? 0` sobre exit code: um
//     default de zero e exatamente a construcao que transforma ausencia em
//     aprovacao.

'use strict';

const fs = require('node:fs');
const path = require('node:path');
const { spawn } = require('node:child_process');

const RAIZ = path.resolve(__dirname, '..', '..');
const catalogo = require('./catalogo');
const leitores = require('./leitores');
const ambiente = require('./ambiente');
const recibos = require('./recibo');
const { ESTADO, SUITE, SAIDA, decidir } = require('./veredito');

const cor = process.stdout.isTTY && !process.env.NO_COLOR;
const c = {
  verde: (s) => (cor ? `\x1b[32m${s}\x1b[0m` : s),
  vermelho: (s) => (cor ? `\x1b[31m${s}\x1b[0m` : s),
  amarelo: (s) => (cor ? `\x1b[33m${s}\x1b[0m` : s),
  cinza: (s) => (cor ? `\x1b[90m${s}\x1b[0m` : s),
  forte: (s) => (cor ? `\x1b[1m${s}\x1b[0m` : s),
};

const log = (m = '') => console.log(m);
const passo = (m) => console.log(c.cinza(`[portao-rc] ${m}`));

// ---------------------------------------------------------------------------
// execucao de um comando
// ---------------------------------------------------------------------------

/// Todo filho e REGISTRADO antes de nascer e conferido no fim (ver `conferirOrfaos`).
/// O registro e a unica forma honesta de detectar orfao: varrer a maquina atras
/// de `java.exe` acusaria o Android Studio da outra janela.
const filhosRegistrados = [];

/// `shell: true` com linha unica, e nao lista de argumentos. Mesma razao do
/// `runner-emulador.js`: no Windows `npm`, `npx`, `flutter` e `firebase` sao
/// `.cmd` e o `spawn` cru nao os executa; e `shell:true` COM lista e deprecado
/// (DEP0190) porque o node concatena sem escapar. Os tokens sao literais do
/// catalogo — nenhum vem de entrada de usuario.
function rodar(linha, opcoes = {}) {
  const { cwd = RAIZ, env = process.env, descricao = linha, aoVivo = true } = opcoes;
  return new Promise((resolve) => {
    const filho = spawn(linha, { cwd, shell: true, env, stdio: ['ignore', 'pipe', 'pipe'] });
    const reg = { pid: filho.pid, descricao };
    filhosRegistrados.push(reg);

    let saida = '';
    for (const [fluxo, destino] of [[filho.stdout, process.stdout], [filho.stderr, process.stderr]]) {
      fluxo.on('data', (p) => {
        saida += p;
        if (aoVivo) destino.write(p);
      });
    }
    filho.on('error', (e) => {
      reg.morto = true;
      resolve({ codigo: 127, saida: `${saida}\n${e.message}`, erroDeSpawn: true });
    });
    filho.on('close', (codigo) => {
      reg.morto = true;
      resolve({ codigo: codigo === null ? 1 : codigo, saida, erroDeSpawn: false });
    });
  });
}

// ---------------------------------------------------------------------------
// tradutores de resultado
// ---------------------------------------------------------------------------

/// Os codigos do `runner-emulador.js`, traduzidos para o vocabulario do portao.
///
/// A traducao e explicita e total — sem `default: PASS`. Um codigo novo que
/// aparecesse ali e nao estivesse aqui cai em INCOMPLETA, que e o lado seguro:
/// o portao declara que nao sabe interpretar, em vez de assumir sucesso.
function traduzirRunner(codigo) {
  switch (codigo) {
    case 0: return { veredito: SUITE.PASS, cleanupFalhou: false };
    case 1: return { veredito: SUITE.FALHA, cleanupFalhou: false };
    // 3 e 4 sao INFRAESTRUTURA no runner: ambiente ocupado, ou preparo/java/
    // build que falhou. Nenhum teste rodou, entao nao ha veredito de codigo.
    case 3: case 4: return { veredito: null, estado: ESTADO.IMPEDIDA, cleanupFalhou: false };
    case 5: return { veredito: SUITE.INCOMPLETA, cleanupFalhou: false };
    // 6: a suite passou INTEIRA e o encerramento e que falhou. E exatamente o
    // "teste verde + cleanup vermelho" da OS: a suite fica PASS, e a reprovacao
    // entra pelo eixo do cleanup. Rotular a suite de FALHA aqui mandaria
    // procurar asercao quebrada onde nao ha nenhuma.
    case 6: return { veredito: SUITE.PASS, cleanupFalhou: true };
    default:
      return { veredito: SUITE.INCOMPLETA, cleanupFalhou: false, desconhecido: codigo };
  }
}

/// Extrai o trecho de falha ORIGINAL, sem reescrever. O portao agrega; ele nao
/// interpreta a falha alheia.
function falhaOriginalDoTexto(texto, limite = 40) {
  const linhas = String(texto).split('\n');
  const inicio = linhas.findIndex((l) => /^\s*(not ok|✖|✗|●|FAIL|Error:)/i.test(l));
  if (inicio === -1) return linhas.slice(-limite).join('\n').trim() || null;
  return linhas.slice(inicio, inicio + limite).join('\n').trim();
}

// ---------------------------------------------------------------------------
// execucao de uma suite
// ---------------------------------------------------------------------------

async function executarSuite(suite, ctx) {
  const inicio = Date.now();
  const base = {
    chave: suite.chave,
    titulo: suite.titulo,
    frente: suite.frente,
    obrigatoria: suite.obrigatoria,
    usaEmulador: Boolean(suite.usaEmulador),
  };

  const det = catalogo.detectar(suite, ctx);
  if (det.estado !== 'PRONTA') {
    return {
      ...base,
      estado: det.estado === 'AUSENTE' ? ESTADO.AUSENTE : ESTADO.IMPEDIDA,
      motivo: det.motivo,
      veredito: null, contagem: null, falhaOriginal: null, exit: null,
      duracaoMs: Date.now() - inicio,
      foraDaBase: suite.foraDaBase || null,
    };
  }

  const cwd = path.join(RAIZ, suite.cwd || '.');
  const env = ambiente.ambienteComJava(ctx.java);

  // ---- preparo ------------------------------------------------------------
  // Falha de preparo e IMPEDIDA, e nao FALHA: nenhum teste rodou. Chamar isso de
  // vermelho de teste mandaria procurar defeito de produto onde ha defeito de
  // dependencia.
  for (const linha of suite.preparo || []) {
    passo(`${suite.chave}: preparo — ${linha}`);
    const r = await rodar(linha, { cwd, env, aoVivo: false });
    if (r.codigo !== 0) {
      return {
        ...base,
        estado: ESTADO.IMPEDIDA,
        motivo: `o preparo falhou (codigo ${r.codigo}):\n  ${linha}\n\n`
          + falhaOriginalDoTexto(r.saida, 20),
        veredito: null, contagem: null, falhaOriginal: null, exit: r.codigo,
        duracaoMs: Date.now() - inicio,
      };
    }
  }

  // ---- comando ------------------------------------------------------------
  let linha = suite.comando;
  let arquivosPedidos = [];

  if (suite.tipo === 'flutter-machine') {
    const { achados } = catalogo.descobrirSuitesDart(RAIZ);
    if (achados.length === 0) {
      return {
        ...base,
        estado: ESTADO.IMPEDIDA,
        motivo: 'a varredura de `app/test/` nao achou nenhuma suite Dart.',
        veredito: null, contagem: null, falhaOriginal: null, exit: null,
        duracaoMs: Date.now() - inicio,
      };
    }
    arquivosPedidos = achados.map((a) => a.absoluto);
    // Caminhos EXPLICITOS, e nunca `flutter test` solto: o runner descobre
    // apenas `*_test.dart`, e sete arquivos versionados usam `teste_`. Passando
    // a lista da varredura, os dois padroes entram — e `lerFlutterMachine`
    // confere que todos apareceram.
    linha = `flutter test ${achados.map((a) => `"${a.caminho}"`).join(' ')} --machine`;
  }

  passo(`${suite.chave}: ${linha}`);
  // `--machine` nao vai ao vivo: e NDJSON, e despejar isso na tela esconde o
  // resto do relatorio. As outras suites vao ao vivo porque o log delas e o que
  // a pessoa de plantao le quando algo quebra.
  const r = await rodar(linha, { cwd, env, aoVivo: suite.tipo !== 'flutter-machine' });

  // ---- leitura ------------------------------------------------------------
  let lido;
  let veredito;
  let cleanupFalhou = false;

  if (suite.tipo === 'flutter-analyze') {
    lido = leitores.lerFlutterAnalyze(r.saida);
    veredito = lido.contagem.falhou > 0 ? SUITE.FALHA : SUITE.PASS;
  } else if (suite.tipo === 'typecheck') {
    lido = leitores.lerTypecheck(r.saida);
    veredito = r.codigo !== 0 || lido.contagem.falhou > 0 ? SUITE.FALHA : SUITE.PASS;
  } else if (suite.tipo === 'flutter-machine') {
    lido = leitores.lerFlutterMachine(r.saida, { esperado: suite.piso, arquivosPedidos });
    if (!lido.integra) veredito = SUITE.INCOMPLETA;
    else veredito = (lido.sucesso && r.codigo === 0) ? SUITE.PASS : SUITE.FALHA;
  } else if (suite.tipo === 'runner-emulador') {
    lido = leitores.lerNodeTest(r.saida, { esperado: null });

    // ANTES de aceitar o veredito do runner: o codebase sob teste chegou a
    // carregar? Se nao chegou, toda chamada voltou `not-found` e as asercoes
    // falharam por ausencia da Function, e nao por defeito dela. Continua
    // REPROVANDO (obrigatoria impedida, exit 4) — o que muda e para onde o
    // vermelho aponta.
    const cargas = leitores.lerCargaDeCodebases(r.saida);
    const minha = suite.codebaseDir
      ? cargas.filter((c) => c.codebase === suite.codebaseDir)
      : [];
    if (minha.length > 0 && r.codigo !== 0) {
      return {
        ...base,
        estado: ESTADO.IMPEDIDA,
        motivo: `o codebase \`${suite.codebaseDir}\` NAO CARREGOU no Emulator Suite:\n`
          + minha.map((m) => `  ${m.erro}`).join('\n')
          + '\n\n  O emulador subiu sem ele, entao as chamadas voltaram `not-found` e a\n'
          + '  suite reprovou por asercao. A falha NAO e da Function: ela nunca chegou\n'
          + '  a existir nesta execucao. Nenhum veredito sobre o codigo desta frente e\n'
          + '  valido aqui.',
        veredito: null,
        contagem: lido.contagem.testes === null ? null : lido.contagem,
        falhaOriginal: null,
        exit: r.codigo,
        duracaoMs: Date.now() - inicio,
      };
    }

    const t = traduzirRunner(r.codigo);
    cleanupFalhou = t.cleanupFalhou;
    if (t.estado === ESTADO.IMPEDIDA) {
      return {
        ...base,
        estado: ESTADO.IMPEDIDA,
        motivo: `o runner de emulador classificou como INFRAESTRUTURA (exit ${r.codigo}).\n\n`
          + falhaOriginalDoTexto(r.saida, 25),
        veredito: null,
        contagem: lido.contagem.testes === null ? null : lido.contagem,
        falhaOriginal: null, exit: r.codigo,
        duracaoMs: Date.now() - inicio,
      };
    }
    veredito = t.veredito;
  } else {
    lido = leitores.lerNodeTest(r.saida, {
      esperado: suite.piso,
      pulosPermitidos: suite.pulosPermitidos || [],
    });
    if (r.codigo !== 0) veredito = lido.contagem.falhou > 0 ? SUITE.FALHA : SUITE.INCOMPLETA;
    else veredito = lido.integra ? SUITE.PASS : SUITE.INCOMPLETA;
  }

  return {
    ...base,
    estado: ESTADO.EXECUTADA,
    motivo: null,
    veredito,
    contagem: lido.contagem,
    problemas: lido.problemas || [],
    falhaOriginal: veredito === SUITE.FALHA
      ? (lido.falhaOriginal || falhaOriginalDoTexto(r.saida))
      : null,
    exit: r.codigo,
    cleanupFalhou,
    arquivos: lido.arquivos || null,
    duracaoMs: Date.now() - inicio,
  };
}

// ---------------------------------------------------------------------------
// relatorio
// ---------------------------------------------------------------------------

function simbolo(s) {
  if (s.estado !== ESTADO.EXECUTADA) return c.amarelo('○');
  if (s.veredito === SUITE.PASS) return c.verde('✔');
  if (s.veredito === SUITE.FALHA) return c.vermelho('✖');
  return c.vermelho('⊘');
}

function rotulo(s) {
  if (s.estado === ESTADO.EXECUTADA) {
    return { [SUITE.PASS]: 'PASS', [SUITE.FALHA]: 'FALHA', [SUITE.INCOMPLETA]: 'INCOMPLETA' }[s.veredito];
  }
  return { [ESTADO.AUSENTE]: 'AUSENTE', [ESTADO.IMPEDIDA]: 'IMPEDIDA', [ESTADO.NAO_SOLICITADA]: 'NAO SOLICITADA' }[s.estado];
}

function duracao(ms) {
  if (ms === null || ms === undefined) return '';
  return ms >= 60_000 ? `${(ms / 60_000).toFixed(1)}min` : `${(ms / 1000).toFixed(1)}s`;
}

function imprimirRelatorio(d, suites, amb, execucao, extras) {
  const barra = '═'.repeat(78);
  log();
  log(c.forte(barra));
  log(c.forte('  PORTAO DE RELEASE CANDIDATE — BURACO MASTER VIP'));
  log(c.forte(barra));
  log();
  log(`  commit    ${execucao.git.commit || '(sem git)'}`);
  log(`  branch    ${execucao.git.branch || '(sem git)'}`);
  log(`  execucao  ${execucao.execucaoId}`);
  log(`  perfil    ${execucao.perfil}`);
  log(`  inicio    ${execucao.iniciadoEm}`);
  log();

  // ---- suites ----
  log(c.forte('  SUITES'));
  log(`  ${'-'.repeat(74)}`);
  for (const s of suites) {
    const obr = s.obrigatoria ? 'obrig.' : 'opcion.';
    const n = s.contagem && s.contagem.testes !== null ? `${s.contagem.testes} casos` : '—';
    log(`  ${simbolo(s)} ${s.chave.padEnd(20)} ${String(rotulo(s)).padEnd(15)} ${obr.padEnd(8)} ${String(n).padStart(10)}  ${c.cinza(duracao(s.duracaoMs))}`);
  }
  log();

  // ---- nao executadas ----
  const fora = suites.filter((s) => s.estado !== ESTADO.EXECUTADA);
  if (fora.length) {
    log(c.forte('  SUITES NAO EXECUTADAS'));
    log(`  ${'-'.repeat(74)}`);
    for (const s of fora) {
      const marca = s.obrigatoria ? c.vermelho('REPROVA') : c.cinza('nao reprova');
      log(`  ○ ${c.forte(s.chave)} — ${rotulo(s)} [${marca}]`);
      for (const l of String(s.motivo || '').split('\n')) log(`      ${l}`);
      log();
    }
  }

  // ---- cobertura ----
  const declaradasFora = suites.filter((s) => s.foraDaBase && !s.obrigatoria);
  if (declaradasFora.length) {
    log(c.amarelo(c.forte('  COBERTURA — frentes que esta RC NAO cobre')));
    log(`  ${'-'.repeat(74)}`);
    log(c.cinza('  Nao reprovam (o codigo nao esta neste commit), mas quem assina a RC'));
    log(c.cinza('  precisa saber que elas ficaram de fora. `--exigir=<chave>` as promove.'));
    log();
    for (const s of declaradasFora) log(`  ▸ ${s.chave.padEnd(12)} ${s.foraDaBase.onde}`);
    log();
  }

  // ---- descoberta Dart ----
  if (extras.dart) {
    const { achados, ignorados } = extras.dart;
    const comPrefixo = achados.filter((a) => a.prefixoTeste);
    log(c.forte('  DESCOBERTA DA SUITE DART'));
    log(`  ${'-'.repeat(74)}`);
    log(`  ${achados.length} arquivo(s) de suite varridos em app/test/`);
    log(c.cinza(`  ${comPrefixo.length} deles usam o prefixo \`teste_\` e seriam INVISIVEIS ao`));
    log(c.cinza('  `flutter test` solto, que so descobre `*_test.dart`.'));
    for (const i of ignorados) {
      log(`  ${c.cinza('—')} fora: ${i.caminho} ${c.cinza(i.porDecisao ? '(por decisao)' : '(apoio)')}`);
    }
    log();
  }

  // ---- cleanup ----
  log(c.forte('  CLEANUP'));
  log(`  ${'-'.repeat(74)}`);
  const ok = (b) => (b ? c.verde('ok') : c.vermelho('FALHA'));
  log(`  trava do emulador   ${ok(!amb.trava.residual)}${amb.trava.residual ? `  ${amb.trava.caminho}` : ''}`);
  log(`  processos orfaos    ${ok(amb.orfaos.length === 0)}${amb.orfaos.length ? `  ${amb.orfaos.length} vivo(s)` : ''}`);
  log(`  dreno das portas    ${amb.portas.aplicavel ? ok(amb.portas.drenadas) : c.cinza('nao aplicavel (nenhum emulador subiu)')}`);
  const ruins = amb.suitesComCleanupRuim || [];
  log(`  encerramento das suites ${ok(ruins.length === 0)}${ruins.length ? `  ${ruins.length} suite(s) prenderam o ambiente` : ''}`);
  log(`  arvore de trabalho  ${ok(amb.arvore.limpa)}${amb.arvore.limpa ? '' : `  ${amb.arvore.sujeira.length} entrada(s) nova(s)`}`);
  log();

  // ---- numeros ----
  const R = d.resumo;
  log(c.forte('  NUMEROS'));
  log(`  ${'-'.repeat(74)}`);
  log(`  suites no catalogo        ${R.total}`);
  log(`  executadas                ${R.executadas}`);
  log(`  nao executadas            ${R.naoExecutadas}${R.obrigatoriasNaoExecutadas ? c.vermelho(`  (${R.obrigatoriasNaoExecutadas} obrigatoria(s))`) : ''}`);
  log(`  casos de teste provados   ${R.testes}`);
  log(`  casos com falha           ${R.falhas > 0 ? c.vermelho(String(R.falhas)) : '0'}`);
  log();

  // ---- reprovacoes ----
  if (d.reprovacoes.length) {
    log(c.vermelho(c.forte('  MOTIVOS DA REPROVACAO')));
    log(`  ${'-'.repeat(74)}`);
    d.reprovacoes.forEach((r, i) => {
      log(`  ${i + 1}. ${c.vermelho(c.forte(r.titulo))}`);
      for (const l of String(r.detalhe || '').split('\n')) log(`     ${l}`);
      log();
    });
  }

  // ---- veredito ----
  log(c.forte(barra));
  if (d.veredito === 'PASS') {
    log(c.verde(c.forte('  VEREDITO: PASS — a Release Candidate esta apta a prosseguir.')));
  } else {
    log(c.vermelho(c.forte('  VEREDITO: FAIL — a Release Candidate NAO esta apta a prosseguir.')));
  }
  log(c.forte(`  exit ${d.saida}   recibo ${extras.recibo || '(nao gravado)'}`));
  log(c.forte(barra));
  log();
}

// ---------------------------------------------------------------------------
// subcomandos
// ---------------------------------------------------------------------------

function listar() {
  const { achados, ignorados } = catalogo.descobrirSuitesDart(RAIZ);
  log();
  log(c.forte('  CATALOGO DO PORTAO DE RC'));
  log();
  for (const s of catalogo.SUITES) {
    const marca = s.obrigatoria ? c.vermelho('obrigatoria') : c.cinza('opcional');
    log(`  ${s.chave.padEnd(20)} ${String(s.frente).padEnd(20)} ${marca}`);
    log(c.cinza(`      ${s.titulo}`));
    if (s.foraDaBase) log(c.cinza(`      fora desta base: ${s.foraDaBase.onde}`));
  }
  log();
  log(c.forte(`  SUITE DART VARRIDA — ${achados.length} arquivo(s)`));
  for (const a of achados) {
    log(`    ${a.prefixoTeste ? c.amarelo('teste_') : c.cinza('_test ')} ${a.caminho}`);
  }
  for (const i of ignorados) log(c.cinza(`    fora    ${i.caminho} — ${i.motivo}`));
  log();
  return 0;
}

function conferir() {
  const recibo = recibos.lerPonteiro(RAIZ);
  const git = recibos.lerGit(RAIZ);
  const v = recibos.conferirValidade(recibo, { commitAtual: git.commit });

  log();
  log(c.forte('  CONFERENCIA DO ULTIMO RECIBO'));
  log();
  if (recibo && recibo.execucao) {
    log(`  execucao   ${recibo.execucao.execucaoId}`);
    log(`  commit     ${recibo.execucao.git ? recibo.execucao.git.commit : '?'}`);
    log(`  terminou   ${recibo.execucao.terminadoEm || c.vermelho('(nunca terminou)')}`);
    log(`  veredito   ${recibo.veredito === 'PASS' ? c.verde('PASS') : c.vermelho(String(recibo.veredito))}`);
    log();
  }
  log(`  arvore     ${git.commit}`);
  log();

  if (v.valido) {
    log(c.verde(c.forte('  RECIBO VALIDO para esta arvore.')));
    log(`  Ele descreve o commit atual e a execucao terminou.`);
    log();
    // Um recibo valido que diz FAIL continua sendo FAIL: a conferencia responde
    // "este documento vale?", e nao "a RC passou?". Repassar o veredito do
    // recibo e o que torna `--conferir` utilizavel como portao de pipeline.
    return recibo.veredito === 'PASS' ? 0 : recibo.saida || SAIDA.FALHA_FUNCIONAL;
  }

  log(c.vermelho(c.forte('  RECIBO NAO VALE PARA ESTA ARVORE.')));
  log();
  for (const r of v.recusas) {
    log(`  ${c.vermelho('•')} ${r}`);
    log();
  }
  log(c.cinza('  Rode o portao de novo: `node ferramentas/portao-rc/portao-rc.js`'));
  log();
  return SAIDA.SEM_PROVA;
}

// ---------------------------------------------------------------------------
// principal
// ---------------------------------------------------------------------------

async function principal() {
  const args = process.argv.slice(2);
  const valor = (nome) => {
    const a = args.find((x) => x.startsWith(`${nome}=`));
    return a ? a.split('=')[1].split(',').filter(Boolean) : null;
  };

  if (args.includes('--listar')) return listar();
  if (args.includes('--conferir')) return conferir();

  const apenas = valor('--apenas');
  const pular = valor('--pular') || [];
  const exigir = valor('--exigir') || [];
  const semEmulador = args.includes('--sem-emulador');

  const desconhecidos = [...(apenas || []), ...pular, ...exigir]
    .filter((k) => !catalogo.SUITES.some((s) => s.chave === k));
  if (desconhecidos.length) {
    console.error(`\n[portao-rc] chave(s) desconhecida(s): ${desconhecidos.join(', ')}`);
    console.error('Use --listar para ver o catalogo.\n');
    return SAIDA.USO;
  }

  const perfil = (apenas || pular.length || semEmulador) ? 'parcial' : 'completo';
  const execucao = recibos.abrirExecucao(RAIZ, { perfil, argumentos: args });

  // O recibo anterior morre ANTES de qualquer coisa. Sem isto, encontrar um
  // recibo ao final nao provaria nada — poderia ser o de ontem.
  const removidos = recibos.limparAnteriores(RAIZ);

  log();
  log(c.forte(`[portao-rc] execucao ${execucao.execucaoId}`));
  log(c.cinza(`[portao-rc] commit ${execucao.git.commit} (${execucao.git.branch})`));
  if (removidos.length) log(c.cinza(`[portao-rc] recibos anteriores removidos: ${removidos.join(', ')}`));
  if (execucao.git.arvoreSujaAoIniciar) {
    log(c.amarelo(`[portao-rc] a arvore JA estava suja ao iniciar (${execucao.git.sujeiraAoIniciar.length} entrada(s));`));
    log(c.amarelo('[portao-rc] o cleanup so cobra o que apareceu DURANTE a execucao.'));
  }

  // ---- ambiente -----------------------------------------------------------
  const java = ambiente.acharJava();
  passo(java.achado
    ? `java=${java.doPath ? 'PATH' : java.caminho}`
    : 'java=AUSENTE — as suites de Emulator Suite ficarao IMPEDIDAS');

  const ferramentas = {
    flutter: (await rodar('flutter --version', { aoVivo: false })).codigo === 0,
  };
  passo(`flutter=${ferramentas.flutter ? 'ok' : 'AUSENTE'}`);

  const ctx = { raiz: RAIZ, java, ferramentas };
  const dart = catalogo.descobrirSuitesDart(RAIZ);
  passo(`suite Dart: ${dart.achados.length} arquivo(s) varridos, `
    + `${dart.achados.filter((a) => a.prefixoTeste).length} com prefixo \`teste_\``);

  // ---- encenacao ----------------------------------------------------------
  // Montada aqui e desmontada no `finally`, sempre — inclusive se a execucao
  // morrer no meio. Encenacao que sobrevive vira commit acidental.
  let encenacao = [];
  let usouEmulador = false;
  const resultados = [];

  try {
    if (catalogo.SUITES.some((s) => s.precisaEncenacao)) {
      encenacao = ambiente.montarEncenacao(RAIZ);
      if (encenacao.length) passo(`encenacao de CI montada: ${encenacao.length} caminho(s) (seeds de app/data)`);
    }

    // ---- as suites --------------------------------------------------------
    for (const suite of catalogo.SUITES) {
      const obrigatoria = suite.obrigatoria || exigir.includes(suite.chave);
      const s = { ...suite, obrigatoria };

      const foraDoPerfil = (apenas && !apenas.includes(s.chave))
        || pular.includes(s.chave)
        || (semEmulador && s.usaEmulador);

      if (foraDoPerfil) {
        resultados.push({
          chave: s.chave, titulo: s.titulo, frente: s.frente, obrigatoria,
          usaEmulador: Boolean(s.usaEmulador),
          estado: ESTADO.NAO_SOLICITADA,
          motivo: semEmulador && s.usaEmulador
            ? 'excluida por `--sem-emulador`'
            : 'fora do recorte pedido em `--apenas`/`--pular`',
          veredito: null, contagem: null, falhaOriginal: null, exit: null, duracaoMs: 0,
          foraDaBase: s.foraDaBase || null,
        });
        continue;
      }

      // DRENO ENTRE SUITES DE EMULADOR. As quatro usam as mesmas oito portas e o
      // mesmo projectId; encadea-las sem esperar o dreno faria a segunda esbarrar
      // nas portas da primeira — que e exatamente a colisao que o
      // `runner-emulador.js` existe para eliminar, so que provocada por quem o
      // chama. O runner drena as DELE; quem nao passa por ele (o alvo integrado)
      // nao drena, e por isso a espera mora aqui.
      if (s.usaEmulador && usouEmulador) {
        passo('aguardando dreno das portas antes da proxima suite de emulador');
        const d = await ambiente.conferirDreno(true, (o) => passo(`  ainda presas: ${o.map((x) => x.porta).join(',')}`));
        if (!d.drenadas) passo(c.amarelo(`  portas ainda presas: ${d.presas.map((x) => x.porta).join(',')}`));
      }

      const r = await executarSuite(s, ctx);
      if (s.usaEmulador && r.estado === ESTADO.EXECUTADA) usouEmulador = true;
      resultados.push(r);

      const marca = r.estado === ESTADO.EXECUTADA
        ? `${rotulo(r)} (${r.contagem && r.contagem.testes !== null ? r.contagem.testes : '?'} casos)`
        : rotulo(r);
      passo(`${s.chave}: ${marca} em ${duracao(r.duracaoMs)}`);
    }
  } finally {
    if (encenacao.length) {
      const desfeitos = ambiente.desmontarEncenacao(encenacao);
      passo(`encenacao desfeita: ${desfeitos.length}/${encenacao.length} caminho(s)`);
    }
  }

  // ---- cleanup ------------------------------------------------------------
  passo('conferindo encerramento (orfaos, trava, dreno, arvore)');

  const orfaos = ambiente.conferirOrfaos(filhosRegistrados);
  if (orfaos.length) ambiente.derrubarOrfaos(orfaos);

  const trava = ambiente.conferirTrava();
  if (trava.residual) ambiente.limparTrava(trava);

  const portas = await ambiente.conferirDreno(usouEmulador,
    (o) => passo(`  dreno: ainda escutando ${o.map((x) => `${x.nome}:${x.porta}`).join(',')}`));

  const arvore = ambiente.conferirArvore(RAIZ, execucao.git.sujeiraAoIniciar);

  // Um runner que saiu 6 (suite verde, portas presas) reprova pelo eixo de
  // cleanup mesmo que o dreno do portao, mais tarde, ja tenha encontrado tudo
  // livre: o estrago aconteceu, e o recibo nao pode esconde-lo.
  const amb = {
    trava,
    orfaos,
    portas,
    suitesComCleanupRuim: resultados
      .filter((r) => r.cleanupFalhou)
      .map((r) => `${r.chave}: o runner saiu com classe CLEANUP-INCOMPLETO (exit 6)`),
    arvore,
  };

  // ---- veredito -----------------------------------------------------------
  //
  // O conflito de recibo e consultado ANTES de decidir: o veredito precisa
  // conhece-lo para reprovar por ele, e o arquivo gravado precisa conter o
  // veredito FINAL. Na ordem inversa, o recibo no disco diria PASS enquanto a
  // tela dizia FAIL — e o documento e justamente o que sobrevive para ser lido
  // depois.
  const reciboConflitante = recibos.conflitoAnterior(RAIZ, execucao.execucaoId);
  const dFinal = decidir({
    suites: resultados,
    ambiente: amb,
    execucao: { ...execucao, reciboConflitante },
  });

  const gravado = recibos.gravar(RAIZ, execucao, {
    veredito: dFinal.veredito,
    saida: dFinal.saida,
    resumo: dFinal.resumo,
    suites: resultados,
    cleanup: amb,
    descobertaDart: dart,
    reprovacoes: dFinal.reprovacoes,
  });

  imprimirRelatorio(dFinal, resultados, amb, execucao, {
    dart,
    recibo: path.relative(RAIZ, gravado.ponteiro).split(path.sep).join('/'),
  });

  return dFinal.saida;
}

principal()
  .then((codigo) => process.exit(codigo))
  .catch((e) => {
    console.error(`\n[portao-rc] erro inesperado: ${e && e.stack ? e.stack : e}`);
    // Erro do proprio portao NAO e aprovacao. Sai pela faixa de "sem prova":
    // nada aqui foi provado, e o motivo esta acima.
    process.exit(SAIDA.SEM_PROVA);
  });
