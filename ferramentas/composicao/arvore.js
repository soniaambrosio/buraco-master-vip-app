'use strict';
/**
 * Leitura da ÁRVORE COMPOSTA para as provas negativas do §19.
 *
 * Duas decisões aqui carregam o peso da não-vacuidade das 15 provas:
 *
 * 1. TUDO É LIDO SEM COMENTÁRIO. Os arquivos desta composição são densamente
 *    comentados, e vários comentários citam textualmente o que é PROIBIDO
 *    ("um `delete resposta.autorUid` deixaria passar...", "voltar a decidir por
 *    `req.auth.token`"). Uma busca sobre o texto cru casaria com a explicação
 *    do defeito e reprovaria o código correto — ou, pior, encontraria a âncora
 *    dentro de um comentário e passaria com o código já removido.
 *
 * 2. TODA PROVA EXIGE ÂNCORA. `exigirAncora` falha quando o que está sendo
 *    guardado não é encontrado. Sem isso, apagar ou renomear o arquivo
 *    guardado deixaria a asserção "o proibido não aparece" verde por ausência —
 *    exatamente o grep vácuo que a OS proíbe.
 */

const fs = require('node:fs');
const path = require('node:path');

const RAIZ = path.resolve(__dirname, '..', '..');

/** Lê um arquivo da árvore composta. Ausência é ERRO, e não string vazia. */
function ler(rel) {
  const p = path.join(RAIZ, rel);
  if (!fs.existsSync(p)) {
    throw new Error(
      `arquivo da composicao ausente: ${rel}. ` +
      'Uma prova negativa NAO pode passar porque o arquivo guardado sumiu.'
    );
  }
  return fs.readFileSync(p, 'utf8');
}

/**
 * Remove comentários de JS/TS preservando o comprimento em linhas.
 *
 * Respeita literais de string e template para não decapitar um `"http://"`.
 * Não é um parser — é um removedor conservador: na dúvida ele PRESERVA o
 * caractere, porque preservar produz falso vermelho (que se investiga) e
 * remover demais produz falso verde (que não se vê).
 */
function semComentarios(fonte) {
  let saida = '';
  let i = 0;
  const n = fonte.length;
  let estado = 'codigo'; // codigo | aspas | linha | bloco
  let aspa = '';

  while (i < n) {
    const c = fonte[i];
    const prox = fonte[i + 1];

    if (estado === 'codigo') {
      if (c === '/' && prox === '/') { estado = 'linha'; i += 2; continue; }
      if (c === '/' && prox === '*') { estado = 'bloco'; i += 2; continue; }
      if (c === '"' || c === "'" || c === '`') { estado = 'aspas'; aspa = c; }
      saida += c;
      i++;
      continue;
    }

    if (estado === 'aspas') {
      saida += c;
      if (c === '\\') { saida += fonte[i + 1] || ''; i += 2; continue; }
      if (c === aspa) estado = 'codigo';
      i++;
      continue;
    }

    if (estado === 'linha') {
      if (c === '\n') { saida += '\n'; estado = 'codigo'; }
      i++;
      continue;
    }

    // bloco
    if (c === '*' && prox === '/') { estado = 'codigo'; i += 2; continue; }
    if (c === '\n') saida += '\n'; // mantem a numeracao de linha utilizavel
    i++;
  }
  return saida;
}

/** Lê um arquivo já sem comentários. */
function codigo(rel) {
  return semComentarios(ler(rel));
}

/**
 * A âncora positiva de uma prova negativa.
 *
 * Antes de afirmar "o proibido não está aqui", provar que "o guardado está
 * aqui". Se a âncora some, a prova REPROVA em vez de ficar verde por vazio.
 */
function exigirAncora(assert, texto, padrao, oQue) {
  const achou = padrao instanceof RegExp ? padrao.test(texto) : texto.includes(padrao);
  assert.ok(
    achou,
    `ANCORA PERDIDA: ${oQue}. A prova negativa correspondente ficaria verde por ` +
    'ausencia, e nao por correcao — reprovando de proposito.'
  );
}

/** As codebases implantáveis, direto do manifesto. */
function codebases() {
  const j = JSON.parse(ler('firebase.json'));
  return j.functions.map((f) => ({ codebase: f.codebase, source: f.source, predeploy: f.predeploy }));
}

/** Todos os arquivos-fonte de uma codebase (sem test/, lib/, node_modules). */
function fontesDe(source) {
  const base = path.join(RAIZ, source);
  const achados = [];
  const andar = (dir) => {
    for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
      const p = path.join(dir, e.name);
      if (e.isDirectory()) {
        if (['node_modules', 'lib', 'test', 'testes', '.git'].includes(e.name)) continue;
        andar(p);
        continue;
      }
      if (/\.(ts|js)$/.test(e.name) && !/\.test\.js$/.test(e.name)) {
        achados.push(path.relative(RAIZ, p).split(path.sep).join('/'));
      }
    }
  };
  andar(base);
  return achados;
}

module.exports = { RAIZ, ler, codigo, semComentarios, exigirAncora, codebases, fontesDe };
