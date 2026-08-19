/**
 * superficieDeploy.test.js — o que este codebase EXPOE, e o que ele IMPLANTA.
 *
 * POR QUE ESTE ARQUIVO EXISTE
 *
 * A OS de ativacao do Billing encontrou producao com cinco funcoes que NAO
 * correspondiam a nenhum commit: tres de uma geracao de deploy, duas de outra,
 * `concederFichasMensais` ausente e `migrarEntitlementsLegado` — ferramenta de
 * migracao — viva como callable. Nada disso foi detectado por teste, porque
 * ate aqui nenhum teste olhava para a SUPERFICIE: so para a logica de dentro.
 *
 * Os dois defeitos que este arquivo fixa sao de natureza diferente e nenhum dos
 * dois quebra `require('./index.js')`:
 *
 *   1. `diagnosticarMetadadosLegados` chamava `criarDiagnosticoMetadados` sem
 *      que o `require` correspondente existisse. Identificador livre dentro de
 *      um handler nao e avaliado na carga do modulo — entao a descoberta do
 *      deploy passa, a funcao e implantada, e ela quebra com ReferenceError na
 *      PRIMEIRA invocacao real. `SUP-01` procura essa classe inteira, e nao o
 *      caso conhecido: qualquer fabrica `criarX` usada sem estar ligada falha.
 *
 *   2. o alvo de deploy do `package.json` era `firebase deploy --only functions`,
 *      que nao e "o billing": e os QUATRO codebases do `firebase.json`. Um
 *      deploy de billing levaria torneios e moderacao junto, e arrastaria as
 *      ferramentas administrativas so por dividirem o mesmo `index.js`.
 *
 * Estes testes leem o FONTE de proposito. Importar `index.js` exigiria
 * `firebase-functions`, `firebase-admin` e `googleapis`, e este codebase roda a
 * suite sem `node_modules` — que e justamente a disciplina que mantem a logica
 * testavel. A superficie, entao, se prova por leitura.
 */

'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const CAMINHO_INDEX = path.join(__dirname, '..', 'index.js');
const CAMINHO_PACOTE = path.join(__dirname, '..', 'package.json');

const fonteIndex = fs.readFileSync(CAMINHO_INDEX, 'utf8');
const pacote = JSON.parse(fs.readFileSync(CAMINHO_PACOTE, 'utf8'));

// A relacao NAO mora mais aqui: ela e uma so, em test/apoio/superficie.js.
// Antes desta correcao existiam DUAS listas escritas a mao para a mesma
// superficie — esta e a do caso `X2` de adversarial.test.js —, e a segunda
// ainda descrevia a linhagem comercial. Duas autoridades para a mesma coisa
// e o defeito; qual das duas mente nao e decidivel lendo o codigo.
const { SUPERFICIE_PRODUCAO, FERRAMENTAS_ADMIN } = require('./apoio/superficie');

/** Remove comentarios e literais de string, que produzem falso positivo. */
function corpoExecutavel(fonte) {
  return fonte
    .replace(/\/\*[\s\S]*?\*\//g, ' ')
    .replace(/(^|[^:])\/\/[^\n]*/g, '$1 ')
    .replace(/'(?:[^'\\\n]|\\.)*'/g, "''")
    .replace(/"(?:[^"\\\n]|\\.)*"/g, '""')
    .replace(/`(?:[^`\\]|\\.)*`/g, '``');
}

/** Nomes ligados por `const { a, b } = require(...)` ou `const x = require(...)`. */
function nomesImportados(fonte) {
  const nomes = new Set();
  const destruturado = /const\s*\{([^}]*)\}\s*=\s*require\(/g;
  let m;
  while ((m = destruturado.exec(fonte)) !== null) {
    for (const parte of m[1].split(',')) {
      const nome = parte.split(':').pop().trim();
      if (nome) nomes.add(nome);
    }
  }
  const direto = /const\s+([A-Za-z_$][\w$]*)\s*=\s*require\(/g;
  while ((m = direto.exec(fonte)) !== null) nomes.add(m[1]);
  return nomes;
}

/** Nomes declarados no proprio arquivo. */
function nomesDeclarados(fonte) {
  const nomes = new Set();
  for (const re of [
    /function\s+([A-Za-z_$][\w$]*)/g,
    /const\s+([A-Za-z_$][\w$]*)\s*=/g,
    /let\s+([A-Za-z_$][\w$]*)/g,
  ]) {
    let m;
    while ((m = re.exec(fonte)) !== null) nomes.add(m[1]);
  }
  return nomes;
}

test('SUP-01 toda fabrica `criarX` usada no index esta ligada a um require', () => {
  const corpo = corpoExecutavel(fonteIndex);
  const ligados = new Set([...nomesImportados(corpo), ...nomesDeclarados(corpo)]);

  // `criarX(` nao precedido de ponto: chamada de fabrica, nao metodo de objeto.
  const usados = new Set();
  const chamada = /(^|[^.\w$])(criar[A-Z][\w$]*)\s*\(/g;
  let m;
  while ((m = chamada.exec(corpo)) !== null) usados.add(m[2]);

  // O teste so vale se ele estiver de fato olhando para alguma coisa.
  assert.ok(usados.size >= 4, `esperava varias fabricas em uso, achei ${usados.size}`);

  const soltos = [...usados].filter((nome) => !ligados.has(nome));
  assert.deepEqual(
    soltos,
    [],
    `fabrica usada sem require/declaracao (ReferenceError na 1a invocacao): ${soltos.join(', ')}`
  );
});

test('SUP-02 `migrarEntitlementsLegado` nao e mais exportada', () => {
  const corpo = corpoExecutavel(fonteIndex);
  assert.ok(
    !/exports\.migrarEntitlementsLegado\s*=/.test(corpo),
    'a callable de migracao voltou a ser exportada: populacao legada e ZERO e ' +
      'ferramenta de migracao exposta e superficie de ataque sem finalidade'
  );
  // A lapide precisa continuar la: sem ela, a proxima pessoa reintroduz a funcao
  // por achar que a ausencia foi esquecimento.
  assert.ok(
    /LAPIDE\s+—\s+`migrarEntitlementsLegado`/.test(fonteIndex),
    'a lapide que explica a remocao sumiu'
  );
});

test('SUP-03 o index exporta exatamente a producao mais as ferramentas de admin', () => {
  const corpo = corpoExecutavel(fonteIndex);
  const exportados = [];
  const re = /exports\.([A-Za-z_$][\w$]*)\s*=/g;
  let m;
  while ((m = re.exec(corpo)) !== null) exportados.push(m[1]);

  for (const nome of SUPERFICIE_PRODUCAO) {
    assert.ok(exportados.includes(nome), `funcao de producao ausente do index: ${nome}`);
  }

  const inesperados = exportados.filter(
    (n) => !SUPERFICIE_PRODUCAO.includes(n) && !FERRAMENTAS_ADMIN.includes(n)
  );
  assert.deepEqual(
    inesperados,
    [],
    `export novo sem decisao de superficie: ${inesperados.join(', ')}`
  );
});

test('SUP-04 o alvo de deploy nomeia a producao e nada alem dela', () => {
  const alvo = pacote.scripts['deploy:producao'];
  assert.ok(alvo, 'o script `deploy:producao` sumiu do package.json');

  for (const nome of SUPERFICIE_PRODUCAO) {
    assert.ok(
      alvo.includes(`functions:billing:${nome}`),
      `o alvo de deploy nao nomeia ${nome}`
    );
  }
  for (const nome of FERRAMENTAS_ADMIN) {
    assert.ok(
      !alvo.includes(nome),
      `ferramenta administrativa dentro do alvo de deploy: ${nome}`
    );
  }
});

test('SUP-05 nenhum script publica os quatro codebases de uma vez', () => {
  for (const [nome, comando] of Object.entries(pacote.scripts)) {
    if (nome.startsWith('//')) continue; // as chaves `//x` sao documentacao
    assert.ok(
      !/firebase\s+deploy\s+--only\s+functions\s*$/.test(comando.trim()),
      `o script \`${nome}\` publica TODOS os codebases (colecoes, billing, ` +
        `torneios, moderacao), e nao so o billing`
    );
  }
});
