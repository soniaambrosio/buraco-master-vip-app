#!/usr/bin/env node
'use strict';
/**
 * CAMPANHA DE MUTAÇÃO DO §16 — a não-vacuidade das provas de proveniência.
 *
 *   uso: node ferramentas/proveniencia/mutacoes.js
 *
 * Doze casos verdes não valem nada enquanto ninguém mostrar que eles sabem
 * ficar vermelhos. Cada mutação aqui quebra UMA guarda do mecanismo e exige que
 * a suíte reprove. Uma mutação que não é detectada é uma prova vazia; uma
 * mutação que não pega no arquivo é INSTRUMENTO QUEBRADO, e não conta como
 * nenhuma das duas coisas.
 *
 * Restaura sempre, inclusive em falha.
 */

const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const AQUI = __dirname;
const SUITE = path.join(AQUI, 'proveniencia.test.js');

const MUTACOES = [
  {
    id: 'MP1-CAMPO-EM-VEZ-DE-BYTE',
    arquivo: 'verificar.js',
    o_que: 'comparar so o campo `sha` em vez dos bytes — deixaria passar edicao a mao',
    de: '    if (lido !== esperado) {',
    para: '    if (JSON.parse(lido).sha !== sha) {',
  },
  {
    id: 'MP2-AUSENTE-E-OK',
    arquivo: 'verificar.js',
    o_que: 'codebase sem carimbo vira "nada a verificar"',
    de: "      problemas.push(`${codebase}: SEM proveniencia (${source}/${P.NOME_DO_ARQUIVO} ausente)`);",
    para: '      /* [MUTACAO] ausencia tolerada */',
  },
  {
    id: 'MP3-SEM-SOBRANDO',
    arquivo: 'verificar.js',
    o_que: 'carimbo de pasta fora do manifesto deixa de reprovar',
    de: "      problemas.push(`${entrada.name}: proveniencia SOBRANDO — a pasta nao esta em firebase.json`);",
    para: '      /* [MUTACAO] sobra tolerada */',
  },
  {
    id: 'MP4-ARVORE-SUJA-OK',
    arquivo: 'gerar.js',
    o_que: 'carimbar sobre arvore com alteracao nao commitada',
    de: '  if (P.arvoreSuja(raiz)) {',
    para: '  if (false && P.arvoreSuja(raiz)) {',
  },
  {
    id: 'MP5-FLAG-TOLERADA',
    arquivo: 'gerar.js',
    o_que: 'flag desconhecida passa a ser ignorada em silencio — a porta do valor manual',
    de: '    throw new Error(\n      `argumento nao aceito: ${JSON.stringify(argv[i])}. ` +',
    para: '    if (argv[i]) continue;\n    throw new Error(\n      `argumento nao aceito: ${JSON.stringify(argv[i])}. ` +',
  },
  {
    id: 'MP6-AMBIENTE-MANDA',
    arquivo: 'gerar.js',
    o_que: 'ambiente passa a poder informar o SHA — a segunda autoridade de versao',
    de: '  const sha = P.shaDaArvore(raiz);',
    para: '  const sha = process.env.PROVENIENCIA_SHA || P.shaDaArvore(raiz);',
    // O bloco de recusa tambem sai, senao o processo morre antes de chegar aqui.
    tambem: {
      de: '  if (definidas.length > 0) {',
      para: '  if (false && definidas.length > 0) {',
    },
  },
  {
    id: 'MP7-CARIMBO-DE-TEMPO',
    arquivo: 'proveniencia.js',
    o_que: 'conteudo deixa de ser puro — um timestamp destroi a verificacao por re-render',
    de: '    origemDoValor: \'git rev-parse HEAD\',',
    para: "    origemDoValor: 'git rev-parse HEAD',\n    geradoEm: new Date().toISOString(),",
  },
  {
    id: 'MP8-LISTA-A-MAO',
    arquivo: 'proveniencia.js',
    o_que: 'a relacao de codebases vira lista escrita a mao, e nao mais firebase.json',
    de: '  const entradas = manifesto.functions;',
    para:
      '  const entradas = [{ codebase: "billing", source: "functions-billing" },\n' +
      '                    { codebase: "conta", source: "functions-conta" }];\n' +
      '  void manifesto;',
  },
  {
    id: 'MP9-SHA-CONSTANTE',
    arquivo: 'proveniencia.js',
    o_que: 'o SHA deixa de sair do git e vira constante',
    de: "  const r = spawnSync('git', ['rev-parse', 'HEAD'], {",
    para: "  if (raiz) return 'd'.repeat(40);\n  const r = spawnSync('git', ['rev-parse', 'HEAD'], {",
  },
];

function rodarSuite() {
  const r = spawnSync(process.execPath, ['--test', SUITE], {
    cwd: path.resolve(AQUI, '..', '..'),
    encoding: 'utf8',
    shell: false,
  });
  const saida = (r.stdout || '') + (r.stderr || '');
  const num = (re) => {
    const m = saida.match(re);
    return m ? Number(m[1]) : NaN;
  };
  const quaisFalharam = [...saida.matchAll(/✖ (PROV-\d+)/g)].map((m) => m[1]);
  return {
    testes: num(/tests (\d+)/),
    passou: num(/pass (\d+)/),
    falhou: num(/fail (\d+)/),
    quaisFalharam,
  };
}

const originais = new Map();
for (const nome of new Set(MUTACOES.map((m) => m.arquivo))) {
  originais.set(nome, fs.readFileSync(path.join(AQUI, nome), 'utf8'));
}
const restaurar = () => {
  for (const [nome, texto] of originais) fs.writeFileSync(path.join(AQUI, nome), texto, 'utf8');
};

/**
 * Normaliza o fim de linha do alvo ao do arquivo.
 *
 * O repositorio e checado fora com CRLF no Windows, e uma ancora escrita com
 * `\n` simplesmente NAO CASA. A mutacao vira INSTRUMENTO QUEBRADO e a campanha
 * deixa de medir aquela guarda — sem que nada fique vermelho, que e o modo mais
 * caro de falhar: a campanha se declara completa tendo pulado uma prova.
 *
 * Foi exatamente o que aconteceu com `MP5` — a porta do valor manual — quando
 * esta campanha rodou pela primeira vez fora do disco de trabalho.
 */
function paraEol(texto, alvo) {
  return alvo.includes('\r\n')
    ? texto.replace(/\r?\n/g, '\r\n')
    : texto.replace(/\r\n/g, '\n');
}

function aplicar(m) {
  const texto = originais.get(m.arquivo);
  const trocas = [{ de: m.de, para: m.para }].concat(m.tambem ? [m.tambem] : []);
  let saida = texto;
  for (const bruta of trocas) {
    const t = { de: paraEol(bruta.de, texto), para: paraEol(bruta.para, texto) };
    const ocorrencias = saida.split(t.de).length - 1;
    if (ocorrencias !== 1) {
      return { erro: `alvo aparece ${ocorrencias}x (esperado 1): ${JSON.stringify(t.de.slice(0, 40))}` };
    }
    saida = saida.replace(t.de, t.para);
  }
  if (saida === texto) return { erro: 'a troca nao alterou o arquivo' };
  fs.writeFileSync(path.join(AQUI, m.arquivo), saida, 'utf8');
  return {};
}

function principal() {
  restaurar();
  const base = rodarSuite();
  console.log(`BASE: ${base.passou}/${base.testes} passam, ${base.falhou} falham`);
  if (!Number.isFinite(base.testes) || base.falhou !== 0) {
    console.error('ABORTADO: a base nao nasce verde — medir mutacao contra vermelho nao diz nada.');
    return 1;
  }
  console.log('');

  let sobreviventes = 0;
  let quebradas = 0;

  for (const m of MUTACOES) {
    const r = aplicar(m);
    if (r.erro) {
      console.log(`${m.id.padEnd(26)} INSTRUMENTO QUEBRADO — ${r.erro}`);
      quebradas++;
      restaurar();
      continue;
    }
    const res = rodarSuite();
    const detectada = Number.isFinite(res.falhou) ? res.falhou > 0 : true;
    if (!detectada) sobreviventes++;
    const quem = res.quaisFalharam.length ? res.quaisFalharam.join(',') : '(carga nao subiu)';
    console.log(
      `${m.id.padEnd(26)} ${detectada ? 'DETECTADA' : '*** SOBREVIVEU ***'}  por ${quem.padEnd(20)} | ${m.o_que}`
    );
    restaurar();
  }

  const depois = rodarSuite();
  console.log('');
  console.log(`RESTAURADO: ${depois.passou}/${depois.testes} passam, ${depois.falhou} falham`);
  console.log(`sobreviventes: ${sobreviventes} | instrumentos quebrados: ${quebradas}`);
  if (sobreviventes > 0 || quebradas > 0 || depois.falhou !== 0) return 1;
  console.log('OK: as nove guardas do mecanismo de proveniencia sao todas provadas.');
  return 0;
}

try {
  process.exit(principal());
} catch (e) {
  restaurar();
  throw e;
}
