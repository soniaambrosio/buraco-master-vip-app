/**
 * nao_vacuidade.js — o teste do teste.
 *
 * O PROBLEMA QUE ISTO RESOLVE
 *
 * Um teste verde prova uma de duas coisas: que a protecao funciona, ou que o
 * teste nunca chegou perto dela. As duas sao indistinguiveis pela suite. Um
 * laudo que diga "idempotencia provada" sem separar as duas nao vale nada — e o
 * modo mais comum de uma homologacao mentir sem que ninguem tenha mentido.
 *
 * COMO ISTO SEPARA AS DUAS
 *
 * Para cada risco critico, uma protecao de PRODUCAO e neutralizada numa copia
 * temporaria do arquivo, os testes correspondentes rodam, e o esperado e que
 * fiquem VERMELHOS. Se ficarem verdes com a protecao desligada, o teste nao
 * estava provando aquilo, e o laudo tem de dizer isso.
 *
 * REGRAS DESTA FERRAMENTA
 *
 *   - a arvore precisa estar LIMPA antes de comecar, e volta limpa no fim,
 *     inclusive se algo explodir no meio (o restauro esta em `finally`);
 *   - nenhuma mutacao e commitada — o que fica versionado e a DESCRICAO dela,
 *     que e o que torna a prova reproduzivel;
 *   - se o restauro falhar, o processo termina com codigo 2 e grita, porque uma
 *     arvore com codigo de producao mutilado e pior do que nenhuma prova.
 *
 * USO
 *   node test/apoio/nao_vacuidade.js          (ou `npm run prova:nao-vacuidade`)
 */

'use strict';

const fs = require('node:fs');
const path = require('node:path');
const { execFileSync, spawnSync } = require('node:child_process');

const RAIZ = path.resolve(__dirname, '..', '..');

/**
 * Cada prova nomeia: o risco, o arquivo de producao, o trecho que implementa a
 * protecao, o trecho que a desliga, e os testes que TEM de ficar vermelhos.
 *
 * O `de`/`para` e substituicao literal e unica: se o trecho nao existir mais,
 * a prova falha com "ancora nao encontrada" em vez de passar por engano.
 */
const PROVAS = [
  {
    caso: 'B',
    risco: 'reentrega do mesmo messageId gasta consulta a Google de novo',
    arquivo: 'rtdn.js',
    protecao: 'atalho `eventoConcluido` antes de gastar chamada de rede',
    de: 'if (await store.eventoConcluido(messageId)) {',
    para: 'if (false && await store.eventoConcluido(messageId)) {',
    testes: ['^B '],
  },
  {
    caso: 'B',
    risco: 'reentrega do mesmo messageId aplica o efeito duas vezes',
    arquivo: 'entitlementStore.js',
    protecao: 'barreira de idempotencia DENTRO da transacao',
    de: "if (ev && ev.exists && ev.data().estado === 'concluido') {",
    para: "if (false && ev && ev.exists && ev.data().estado === 'concluido') {",
    // B sozinho NAO serve de prova aqui: com esta barreira desligada ele ainda
    // passa, porque o atalho de `rtdn.js` responde antes de a transacao ser
    // alcancada. B2 e o cenario em que a barreira e a unica defesa — duas
    // entregas do mesmo messageId em voo, com carimbos de consulta diferentes,
    // que escapam tanto do atalho quanto da regra de ordem.
    testes: ['^B2 '],
  },
  {
    caso: 'C',
    risco: 'reempacotar o mesmo estorno com outro messageId o aplica de novo',
    arquivo: 'entitlement.js',
    protecao: 'desfecho terminal repetido e convergente, sem efeito novo',
    de: "return { aplicar: false, motivo: 'terminal_repetido' };",
    para: "return { aplicar: true, motivo: 'terminal_repetido' };",
    testes: ['^C '],
  },
  {
    caso: 'D',
    risco: 'evento antigo regride o estado',
    arquivo: 'entitlement.js',
    protecao: 'regra de ORDEM pelo carimbo da consulta autoritativa',
    de: "return { aplicar: false, motivo: 'verificacao_antiga' };",
    para: "return { aplicar: true, motivo: 'verificacao_antiga' };",
    testes: ['^D ', '^D2 '],
  },
  {
    caso: 'P',
    risco: 'falha da Play vira decisao em vez de reentrega',
    arquivo: 'reconciliacao.js',
    protecao: 'a excecao SOBE, para o Pub/Sub reentregar',
    de: 'const resposta = await consultarAssinatura(tokenCompra);',
    para:
      'let resposta; try { resposta = await consultarAssinatura(tokenCompra); } '
      + 'catch (e) { resposta = {}; }',
    testes: ['^P ', '^P2 '],
  },
  {
    caso: 'Q',
    risco: 'duas execucoes simultaneas decidem sobre um estado velho',
    arquivo: 'entitlementStore.js',
    protecao: 'o documento e RELIDO DENTRO da transacao',
    de: `    return db.runTransaction(async (tx) => {
      const [pub, int, ev] = await Promise.all([
        tx.get(publico),
        tx.get(interno),
        refEvento ? tx.get(refEvento) : Promise.resolve(null),
      ]);`,
    para: `    const [pubFora, intFora, evFora] = await Promise.all([
      publico.get(),
      interno.get(),
      refEvento ? refEvento.get() : Promise.resolve(null),
    ]);
    return db.runTransaction(async (tx) => {
      const [pub, int, ev] = [pubFora, intFora, evFora];`,
    testes: ['^Q ', '^U2 '],
  },
  {
    caso: 'R',
    risco: 'token registrado para outro jogador devolve concessao alheia',
    arquivo: 'idempotencia.js',
    protecao: 'conferencia de titularidade antes do estado',
    de: 'if (registro.uid !== ctx.uid) {',
    para: 'if (false && registro.uid !== ctx.uid) {',
    testes: ['^R '],
  },
  {
    caso: 'S',
    risco: 'identificador de compra vaza inteiro para log e trilha',
    arquivo: 'entitlement.js',
    protecao: 'rotulo de oito caracteres em vez do hash',
    de: 'return hash.slice(0, 8);',
    para: 'return hash;',
    testes: ['^S '],
  },
  {
    caso: 'U',
    risco: 'RTDN e reconciliacao em ordens opostas terminam diferente',
    arquivo: 'entitlement.js',
    protecao: 'regra de ORDEM pelo carimbo da consulta autoritativa',
    de: "return { aplicar: false, motivo: 'verificacao_antiga' };",
    para: "return { aplicar: true, motivo: 'verificacao_antiga' };",
    testes: ['^U '],
  },
  {
    caso: 'W',
    risco: 'falha no commit deixa entitlement gravado e trilha ausente',
    arquivo: 'entitlementStore.js',
    protecao: 'as escritas do entitlement sao BUFFERIZADAS na transacao',
    de: `        tx.set(publico, docs.publico);
        tx.set(interno, docs.interno);`,
    para: `        await publico.set(docs.publico);
        await interno.set(docs.interno);`,
    testes: ['^W ', '^W2 '],
  },
];

function git(...args) {
  return execFileSync('git', ['-C', RAIZ, ...args], { encoding: 'utf8' }).trim();
}

function arvoreLimpa() {
  return git('status', '--porcelain') === '';
}

function rodar(padroes) {
  const args = ['--test'];
  for (const p of padroes) args.push('--test-name-pattern', p);
  args.push('test/adversarial.test.js');
  const r = spawnSync(process.execPath, args, { cwd: RAIZ, encoding: 'utf8' });
  const saida = `${r.stdout || ''}${r.stderr || ''}`;
  // O `node --test` resume com o reporter TAP (`# pass N`) ou com o spec
  // (`ℹ pass N`), conforme a versao e o terminal. Ler so um dos dois faria TODA
  // prova parecer vacua — que e exatamente o falso negativo mais perigoso aqui.
  const contar = (rotulo) => {
    const m = new RegExp(`^(?:#|\\u2139) ${rotulo} (\\d+)$`, 'm').exec(saida);
    return m == null ? null : Number(m[1]);
  };
  return { codigo: r.status, tests: contar('tests'), fail: contar('fail') };
}

function main() {
  if (!arvoreLimpa()) {
    console.error('ABORTADO: a arvore precisa estar limpa antes da prova.');
    console.error(git('status', '--porcelain'));
    process.exit(2);
  }

  const linhas = [];
  let vacuos = 0;

  for (const prova of PROVAS) {
    const alvo = path.join(RAIZ, prova.arquivo);
    const original = fs.readFileSync(alvo, 'utf8');

    // As ancoras sao escritas com `\n`; a arvore desta maquina esta em CRLF.
    // Traduzir aqui e o que impede a prova de abortar por final de linha —
    // falhar por isso seria falhar pelo motivo errado.
    const eol = original.includes('\r\n') ? '\r\n' : '\n';
    const de = prova.de.split('\n').join(eol);
    const para = prova.para.split('\n').join(eol);

    const ocorrencias = original.split(de).length - 1;
    if (ocorrencias !== 1) {
      console.error(
        `ABORTADO: ancora ${ocorrencias === 0 ? 'nao encontrada' : 'ambigua'} em ${prova.arquivo} `
        + `para o caso ${prova.caso} (${ocorrencias} ocorrencias).`
      );
      process.exit(2);
    }

    let resultado;
    try {
      fs.writeFileSync(alvo, original.replace(de, para), 'utf8');
      resultado = rodar(prova.testes);
    } finally {
      fs.writeFileSync(alvo, original, 'utf8');
    }

    if (!arvoreLimpa()) {
      console.error(`FALHA DE RESTAURO apos o caso ${prova.caso}. Arvore suja:`);
      console.error(git('status', '--porcelain'));
      process.exit(2);
    }

    // Um padrao que nao casa com teste nenhum devolve "zero falhas" e passaria
    // por prova. Aqui isso e erro duro, e nao resultado.
    if (!resultado.tests) {
      console.error(
        `ABORTADO: o padrao ${prova.testes.join(' ')} nao selecionou nenhum teste `
        + `(caso ${prova.caso}). O nome do teste mudou?`
      );
      process.exit(2);
    }

    const ficouVermelho = resultado.fail > 0;
    if (!ficouVermelho) vacuos += 1;
    linhas.push({
      caso: prova.caso,
      arquivo: prova.arquivo,
      protecao: prova.protecao,
      testes: prova.testes.join(' '),
      rodados: resultado.tests,
      fail: resultado.fail,
      veredito: ficouVermelho ? 'NAO VACUO' : 'VACUO',
    });
  }

  console.log('\n| caso | arquivo | protecao desligada | padrao | rodados | vermelhos | veredito |');
  console.log('| --- | --- | --- | --- | ---: | ---: | --- |');
  for (const l of linhas) {
    console.log(
      `| ${l.caso} | \`${l.arquivo}\` | ${l.protecao} | \`${l.testes}\` | ${l.rodados} | ${l.fail} | **${l.veredito}** |`
    );
  }

  console.log(`\narvore limpa no fim: ${arvoreLimpa() ? 'sim' : 'NAO'}`);
  if (vacuos > 0) {
    console.error(`\n${vacuos} prova(s) VACUA(s): o teste passa com a protecao desligada.`);
    process.exit(1);
  }
  console.log('\nTodas as protecoes criticas sao necessarias: nenhum teste passou sem elas.');
}

main();
