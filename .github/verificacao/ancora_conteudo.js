#!/usr/bin/env node
// ancora_conteudo.js — a autoridade externa INDEPENDENTE de conteúdo e piso da
// âncora das provas visuais da carta obrigatória do lixo (OS 29-C7).
//
// POR QUE ELE EXISTE, SE JÁ HÁ DIGEST.
//
// A OS 29-C6 prendeu a âncora por digest, com dois donos — o alvo oficial e o
// contrato. Isso prova que ela NÃO MUDOU. Não prova que ela AFIRMA alguma
// coisa. No dia em que os dois donos forem realinhados no mesmo commit — um
// gesto de três arquivos, que a própria C6 registrou como limite aberto —, uma
// âncora de dezesseis casos vazios passa nos dois.
//
// Este arquivo mede o que o digest não mede: quantos casos a âncora declara,
// quantas afirmações NÃO TRIVIAIS ela faz, e se as declarações sem as quais ela
// não confere nada continuam lá. Ele é escrito noutra linguagem, com varredor
// próprio e cópia própria dos números, exatamente para não cair no mesmo gesto
// que derrubaria a âncora.
//
// Ele NÃO é um segundo agregador: não tem lista de gates, não emite veredito de
// portão e não decide nada além de si mesmo. Ele é um passo do portão que já
// existe, e sai 0 ou 1.
//
// uso: node .github/verificacao/ancora_conteudo.js [raiz]

'use strict';

const fs = require('fs');
const path = require('path');

const RAIZ = process.argv[2] || '.';
const ALVO = path.join(RAIZ, 'app/test/casca/ancora_provas_visuais_test.dart');
const CONTRATO = path.join(RAIZ, 'docs/ANCORA-PROVAS-VISUAIS-CARTA-OBRIGATORIA-V1.md');

// --- os números, em cópia própria ------------------------------------------

const PISO_DE_CASOS = 18;
const PISO_DE_AFIRMACOES = 60;

const DECLARACOES = [
  'Map<String, List<String>> passosDo(String yml)',
  'List<String> comandosVivos(List<String> corpo)',
  'List<String> comandosDoPasso(String yml, String passo)',
  'int vezesNoPasso(String yml, String passo, String comando)',
  'int posicaoNoPasso(String yml, String passo, String comando)',
  'List<String> atribuicoesVivas(String yml, String passo, String nome)',
  'String atribuicaoUnica(String yml, String passo, String nome)',
  'const List<String> kVetoresDoContrato',
  'const String kCaminhoDoVerificador',
  'const String kPassoDasSuites',
  'const int kPisoDoPortaoDaCasca',
  'const String kMarcadorDaCasca',
  'kDigestDoCodigoDaGuarda',
  'kDigestDoCodigoDaReciprocidade',
];

const VETORES = [];
for (let i = 1; i <= 20; i++) VETORES.push('C6-' + String(i).padStart(2, '0'));

// --- varredor próprio -------------------------------------------------------
//
// Mesma ideia da âncora, implementação independente: quem trivializasse a
// âncora não trivializa junto o instrumento que a mede.

function aspaCrua(fonte, k) {
  return k > 0 && fonte[k - 1] === 'r' &&
    (k === 1 || !/[A-Za-z0-9_$]/.test(fonte[k - 2]));
}

function semComentarios(fonte) {
  let saida = '';
  let i = 0;
  let aspa = null;
  let crua = false;
  while (i < fonte.length) {
    const c = fonte[i];
    const p = i + 1 < fonte.length ? fonte[i + 1] : '';
    if (aspa !== null) {
      saida += c;
      if (c === '\\' && !crua) { if (p) saida += p; i += 2; continue; }
      if (c === aspa) aspa = null;
      i++;
      continue;
    }
    if (c === '/' && p === '/') { while (i < fonte.length && fonte[i] !== '\n') i++; continue; }
    if (c === '/' && p === '*') {
      i += 2;
      while (i < fonte.length && !(fonte[i] === '*' && fonte[i + 1] === '/')) i++;
      i += 2;
      continue;
    }
    if (c === "'" || c === '"') { aspa = c; crua = aspaCrua(fonte, i); }
    saida += c;
    i++;
  }
  return saida;
}

function semTextoDeString(fonte) {
  let saida = '';
  let i = 0;
  let aspa = null;
  let crua = false;
  while (i < fonte.length) {
    const c = fonte[i];
    if (aspa !== null) {
      if (c === '\\' && !crua) { i += 2; continue; }
      if (c === aspa) { aspa = null; saida += c; }
      i++;
      continue;
    }
    if (c === "'" || c === '"') { aspa = c; crua = aspaCrua(fonte, i); saida += c; i++; continue; }
    saida += c;
    i++;
  }
  return saida;
}

function argumentosDeExpect(corpo) {
  const CHAMADA = 'expect(';
  const saida = [];
  let i = 0;
  for (;;) {
    const k = corpo.indexOf(CHAMADA, i);
    if (k < 0) break;
    if (k > 0 && /[A-Za-z0-9_$.]/.test(corpo[k - 1])) { i = k + CHAMADA.length; continue; }
    let p = k + CHAMADA.length;
    let nivel = 1;
    let aspa = null;
    let crua = false;
    while (p < corpo.length && nivel > 0) {
      const c = corpo[p];
      if (aspa !== null) {
        if (c === '\\' && !crua) { p += 2; continue; }
        if (c === aspa) aspa = null;
      } else if (c === "'" || c === '"') { aspa = c; crua = aspaCrua(corpo, p); }
      else if (c === '(') nivel++;
      else if (c === ')') nivel--;
      p++;
    }
    saida.push(corpo.substring(k + CHAMADA.length, p - 1));
    i = p;
  }
  return saida;
}

function primeiroPosicional(argumentos) {
  let nivel = 0;
  let aspa = null;
  let crua = false;
  for (let p = 0; p < argumentos.length; p++) {
    const c = argumentos[p];
    if (aspa !== null) {
      if (c === '\\' && !crua) { p++; continue; }
      if (c === aspa) aspa = null;
      continue;
    }
    if (c === "'" || c === '"') { aspa = c; crua = aspaCrua(argumentos, p); continue; }
    if (c === '(' || c === '[' || c === '{') nivel++;
    if (c === ')' || c === ']' || c === '}') nivel--;
    if (c === ',' && nivel === 0) return argumentos.substring(0, p);
  }
  return argumentos;
}

function trivial(a) {
  const t = a.trim();
  if (!t) return true;
  if (/^'[^']*'$/.test(t) || /^"[^"]*"$/.test(t)) return true;
  if (/^-?[0-9]+(\.[0-9]+)?$/.test(t)) return true;
  if (t === 'true' || t === 'false' || t === 'null') return true;
  if (/^([A-Za-z_][A-Za-z0-9_]*)\s*\|\|\s*!\1$/.test(t)) return true;
  if (/^!([A-Za-z_][A-Za-z0-9_]*)\s*\|\|\s*\1$/.test(t)) return true;
  return false;
}

// --- as conferências --------------------------------------------------------

const falhas = [];
function exigir(condicao, mensagem) {
  if (!condicao) falhas.push(mensagem);
}

if (!fs.existsSync(ALVO)) {
  console.error('VERIFICADOR: a âncora não está em ' + ALVO);
  process.exit(1);
}
if (!fs.existsSync(CONTRATO)) {
  console.error('VERIFICADOR: o contrato não está em ' + CONTRATO);
  process.exit(1);
}

const bruto = fs.readFileSync(ALVO, 'utf8').replace(/\r\n/g, '\n').replace(/\r/g, '\n');
const contrato = fs.readFileSync(CONTRATO, 'utf8');

// 1 — quantos casos a âncora declara.
const casos = [];
for (const l of bruto.split('\n')) {
  const t = l.replace(/^\s+/, '');
  if (t.startsWith('//')) continue;
  const m = /^(?:testWidgets|test)\('((?:[^'\\]|\\.)*)'/.exec(t);
  if (m) casos.push(m[1]);
}
exigir(casos.length >= PISO_DE_CASOS,
  'a âncora declara ' + casos.length + ' casos, e o piso é ' + PISO_DE_CASOS);
exigir(new Set(casos).size === casos.length,
  'dois casos da âncora têm o mesmo nome');

// 2 — quantas afirmações NÃO TRIVIAIS ela faz. É o que o digest não mede.
//
// ANTES DISSO, O PONTO CEGO DECLARADO. Nem este varredor nem o da âncora
// entendem aspa tripla: os dois leriam a segunda aspa como fechamento, e a
// partir dali o arquivo inteiro vira "texto". Uma medição feita assim disse
// 3 afirmações onde havia 74 — e teria dito o mesmo de uma âncora esvaziada.
// Em vez de ensinar aspa tripla aos dois, o formato é PROIBIDO no arquivo
// medido, e a proibição é conferida aqui.
// A proibição cobre as DUAS aspas e as variantes cruas. `r'''`, `R'''`, `r"""`
// e `R"""` contêm a tripla, então a busca pela tripla já os alcança — e ela
// varre o arquivo INTEIRO, antes e depois do trecho medido, porque um ponto
// cego aberto no topo cega tudo o que vem abaixo.
const TRIPLA_S = "'".repeat(3);
const TRIPLA_D = '"'.repeat(3);
const ondeS = bruto.indexOf(TRIPLA_S);
const ondeD = bruto.indexOf(TRIPLA_D);
exigir(ondeS < 0 && ondeD < 0,
  'a âncora usa aspa tripla (posição ' + (ondeS < 0 ? ondeD : ondeS) + '), que ' +
  'este varredor não entende: a medição de afirmações ficaria cega do ponto em ' +
  'diante e aprovaria uma âncora vazia. As variantes cruas r/R contêm a mesma ' +
  'tripla e caem na mesma proibição');

// E a âncora tem de continuar exigindo esta proibição DE VOLTA. Sem isto,
// apagar as quatro linhas acima devolveria o ponto cego em silêncio — que é
// exatamente a forma do defeito que elas existem para impedir.
const RECIPROCA = [
  'kCaminhoDoVerificador',
  'TRIPLA_S',
  'TRIPLA_D',
];
const fonteDaAncora = bruto;
for (const t of RECIPROCA) {
  exigir(fonteDaAncora.includes(t),
    'a âncora deixou de nomear "' + t + '": ela é quem cobra de volta que esta ' +
    'proibição continue escrita aqui');
}

const limpo = semTextoDeString(semComentarios(bruto));
const afirmacoes = argumentosDeExpect(limpo).map(primeiroPosicional);
const naoTriviais = afirmacoes.filter((a) => !trivial(a));
exigir(naoTriviais.length >= PISO_DE_AFIRMACOES,
  'a âncora faz ' + naoTriviais.length + ' afirmações que olham para o programa, ' +
  'de ' + afirmacoes.length + ' expect, e o piso é ' + PISO_DE_AFIRMACOES +
  ': o resto é literal, tautologia ou string');

// 3 — as declarações sem as quais ela não confere nada.
const codigo = bruto.split('\n').filter((l) => !l.replace(/^\s+/, '').startsWith('//')).join('\n');
for (const d of DECLARACOES) {
  exigir(codigo.includes(d), 'a âncora perdeu a declaração "' + d + '"');
}

// 4 — os dois digests do código das metades continuam declarados e são sha256.
for (const nome of ['kDigestDoCodigoDaGuarda', 'kDigestDoCodigoDaReciprocidade']) {
  const m = new RegExp('const String ' + nome + "\\s*=\\s*\\n?\\s*'([0-9a-f]{64})'").exec(bruto);
  exigir(m !== null, 'a âncora não declara ' + nome + ' como um sha256 de 64 hex');
}

// 5 — os vinte vetores contratuais continuam congelados no contrato.
for (const v of VETORES) {
  exigir(contrato.includes(v), 'o contrato deixou de registrar o vetor ' + v);
}

// --- veredito ---------------------------------------------------------------

if (falhas.length > 0) {
  console.error('VERIFICADOR DE CONTEÚDO DA ÂNCORA: VERMELHO');
  for (const f of falhas) console.error('  - ' + f);
  process.exit(1);
}
console.log('VERIFICADOR DE CONTEÚDO DA ÂNCORA: VERDE — ' + casos.length +
  ' casos, ' + naoTriviais.length + ' afirmações não triviais, ' +
  DECLARACOES.length + ' declarações, ' + VETORES.length + ' vetores no contrato');
process.exit(0);
