'use strict';
/**
 * PROVENIÊNCIA DO CÓDIGO IMPLANTADO DAS FUNCTIONS — a autoridade ÚNICA.
 *
 * ============================================================================
 * O PROBLEMA
 * ============================================================================
 *
 * O servidor de partidas responde `GET /versao` com o commit que está rodando.
 * As Functions não têm equivalente: depois de um deploy, nada no projeto diz
 * QUAL código está lá. Nove codebases sobem separadamente, então "a versão em
 * produção" pode ser nove coisas diferentes — e essa divergência é silenciosa.
 *
 * ============================================================================
 * A SOLUÇÃO, E AS TRÊS COISAS QUE ELA SE RECUSA A SER
 * ============================================================================
 *
 * O artefato de cada codebase passa a CARREGAR o SHA da composição, num arquivo
 * `proveniencia.json` gerado no build. Um operador lê esse arquivo do artefato
 * já implantado pelos caminhos administrativos que JÁ existem (o download do
 * código-fonte da função). Nenhum endpoint novo, nenhum callable novo.
 *
 *   1. NÃO É UMA SEGUNDA AUTORIDADE DE VERSÃO. A única origem do valor é
 *      `git rev-parse HEAD`. Não há campo em `package.json`, constante em
 *      código, variável de ambiente ou argumento de linha de comando que possa
 *      informá-lo. Ver `shaDaArvore()`, e a recusa explícita em `gerar.js`.
 *
 *   2. NÃO É UM VALOR MANUAL. O conteúdo é função PURA de (sha, codebase):
 *      mesma entrada, mesmos bytes. Por isso a verificação não "confere campos"
 *      — ela RE-RENDERIZA e compara byte a byte. Editar o arquivo à mão é
 *      detectável porque qualquer byte diferente reprova, inclusive um SHA
 *      plausível digitado por alguém.
 *
 *   3. NÃO PODE ESQUECER UMA CODEBASE. A relação de codebases não é uma lista
 *      escrita aqui: sai de `firebase.json`, a MESMA fonte que o `deploy` lê.
 *      Uma codebase nova entra na proveniência no mesmo commit em que passa a
 *      ser implantável — e uma que saia do manifesto deixa de ser exigida.
 *      Manter uma cópia da lista aqui seria reencenar o defeito CI-02.
 *
 * ============================================================================
 * POR QUE O ARQUIVO NÃO É VERSIONADO
 * ============================================================================
 *
 * Não pode ser. Um arquivo que contém o SHA do commit que o contém é
 * impossível: escrevê-lo muda a árvore e, portanto, muda o SHA. Proveniência é
 * ARTEFATO DE BUILD, gerada imediatamente antes do deploy, e é justamente por
 * ser regenerada a cada build que ela não tem como divergir do código.
 *
 * Consequência aceita de propósito: esta ferramenta prova o MECANISMO e o
 * artefato-a-implantar. Ela não prova, e não pode provar sem um deploy, o que
 * há hoje em produção — o que está em linha com a OS, que proíbe deploy.
 */

const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const NOME_DO_ARQUIVO = 'proveniencia.json';
const GERADOR = 'ferramentas/proveniencia/gerar.js';
const SHA_VALIDO = /^[0-9a-f]{40}$/;

/**
 * A raiz do repositório, deduzida da posição deste arquivo.
 * `ferramentas/proveniencia/proveniencia.js` -> duas pastas acima.
 */
const RAIZ = path.resolve(__dirname, '..', '..');

/**
 * O SHA da composição. ÚNICA origem do valor em todo o mecanismo.
 *
 * `git` é executado com argumentos fixos, sem shell e sem nada vindo de
 * ambiente ou de argv — não há por onde injetar um valor.
 *
 * Falha FECHADO: sem git, fora de repositório, ou com resposta que não seja um
 * SHA completo de 40 hexadecimais, LANÇA. Nunca devolve string vazia, `null`,
 * `'desconhecido'` ou qualquer valor de consolo — um placeholder que atravessa
 * o build vira exatamente a divergência silenciosa que isto existe para impedir.
 */
function shaDaArvore(raiz = RAIZ) {
  const r = spawnSync('git', ['rev-parse', 'HEAD'], {
    cwd: raiz,
    encoding: 'utf8',
    shell: false,
  });
  if (r.error) throw new Error(`git indisponivel: ${r.error.message}`);
  if (r.status !== 0) {
    throw new Error(`git rev-parse HEAD falhou (status ${r.status}): ${(r.stderr || '').trim()}`);
  }
  const sha = (r.stdout || '').trim();
  if (!SHA_VALIDO.test(sha)) {
    throw new Error(`git devolveu algo que nao e um SHA completo: ${JSON.stringify(sha)}`);
  }
  return sha;
}

/**
 * Se a árvore tem alteração NÃO COMMITADA em arquivo rastreado.
 *
 * O SHA descreve o commit, e não o disco. Gerar proveniência sobre árvore suja
 * carimbaria um artefato com o nome de um código que não é o dele — mentira
 * pior que a ausência. Arquivo ignorado (inclusive a própria proveniência) não
 * conta: `--porcelain` sem `--ignored` não os enxerga.
 */
function arvoreSuja(raiz = RAIZ) {
  const r = spawnSync('git', ['status', '--porcelain', '--untracked-files=no'], {
    cwd: raiz,
    encoding: 'utf8',
    shell: false,
  });
  if (r.error) throw new Error(`git indisponivel: ${r.error.message}`);
  if (r.status !== 0) throw new Error(`git status falhou (status ${r.status})`);
  return (r.stdout || '').trim().length > 0;
}

/**
 * As codebases implantáveis, LIDAS DE `firebase.json` — a mesma fonte do deploy.
 *
 * Ordenadas por nome para que o resultado não dependa da ordem do manifesto.
 */
function codebases(raiz = RAIZ) {
  const manifesto = JSON.parse(fs.readFileSync(path.join(raiz, 'firebase.json'), 'utf8'));
  const entradas = manifesto.functions;
  if (!Array.isArray(entradas) || entradas.length === 0) {
    throw new Error('firebase.json nao declara nenhuma codebase de functions');
  }
  const vistas = new Set();
  const lista = entradas.map((e) => {
    if (!e.codebase || !e.source) {
      throw new Error(`entrada de functions sem codebase/source: ${JSON.stringify(e)}`);
    }
    if (vistas.has(e.codebase)) throw new Error(`codebase duplicada em firebase.json: ${e.codebase}`);
    vistas.add(e.codebase);
    return { codebase: String(e.codebase), source: String(e.source) };
  });
  return lista.sort((a, b) => (a.codebase < b.codebase ? -1 : a.codebase > b.codebase ? 1 : 0));
}

/**
 * O conteúdo do arquivo — função PURA de (sha, codebase, source).
 *
 * Sem carimbo de tempo, sem nome de máquina, sem usuário, sem nada de ambiente:
 * é essa pureza que permite verificar por RE-RENDERIZAÇÃO em vez de por
 * conferência de campos, e é a re-renderização que fecha a porta do valor
 * manual. Um timestamp aqui destruiria a prova.
 *
 * Sem segredo: os únicos dados são um SHA público, o nome da codebase e o
 * caminho da pasta — todos já visíveis no repositório.
 */
function conteudo({ sha, codebase, source }) {
  if (!SHA_VALIDO.test(sha)) throw new Error(`sha invalido: ${JSON.stringify(sha)}`);
  const doc = {
    _aviso: 'ARQUIVO GERADO NO BUILD. Nao editar a mao, nao versionar: ' +
      'e regenerado a cada build e conferido byte a byte por ' +
      'ferramentas/proveniencia/verificar.js.',
    sha,
    codebase,
    source,
    gerador: GERADOR,
    origemDoValor: 'git rev-parse HEAD',
  };
  return JSON.stringify(doc, null, 2) + '\n';
}

/** O caminho do arquivo de proveniência de uma codebase. */
function caminho(raiz, source) {
  return path.join(raiz, source, NOME_DO_ARQUIVO);
}

module.exports = {
  NOME_DO_ARQUIVO,
  GERADOR,
  SHA_VALIDO,
  RAIZ,
  shaDaArvore,
  arvoreSuja,
  codebases,
  conteudo,
  caminho,
};
