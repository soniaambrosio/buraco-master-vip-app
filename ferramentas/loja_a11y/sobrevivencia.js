#!/usr/bin/env node
'use strict';
/**
 * PROVA DE SOBREVIVÊNCIA DO GATE `lojaa11y` — §13 da OS 14-C1.
 *
 *   uso: node ferramentas/loja_a11y/sobrevivencia.js
 *
 * A OS não pede um mecanismo novo: pede que a suíte da Loja seja protegida pela
 * arquitetura canônica que já existe nesta linhagem, e que a proteção seja
 * DEMONSTRADA nos dois sentidos. É isso que este script faz — ele não inventa
 * portão nenhum, ele exercita o portão de verdade:
 *
 *   * `scripts/ci/portao_os_integracao.sh`, o agregador final;
 *   * `scripts/ci/gates_os_integracao.txt`, a fonte única;
 *   * `ferramentas/composicao/negativas.test.js`, que guarda a bijeção entre a
 *     fonte única e os produtores do workflow (PN-10 e PN-12).
 *
 * POR QUE ISTO NÃO É UM GATE. Pelo mesmo critério de `mutacoes.js` e
 * `mutacoes_loja.js`, ao lado: é campanha, não regressão. Ela roda uma vez, na
 * OS que a exige, e o relatório registra o resultado. Um gate que rodasse a
 * campanha a cada CI faria o portão depender de si mesmo.
 *
 * Nenhum arquivo do repositório é modificado de forma permanente: as mutações
 * de fonte são restauradas no `finally`, inclusive em falha.
 */

const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const RAIZ = path.resolve(__dirname, '..', '..');
const AGREGADOR = path.join(RAIZ, 'scripts', 'ci', 'portao_os_integracao.sh');
const FONTE = path.join(RAIZ, 'scripts', 'ci', 'gates_os_integracao.txt');
const WORKFLOW = path.join(RAIZ, '.github', 'workflows', 'ci-os-integracao.yml');
const NEGATIVAS = path.join(
  RAIZ, 'ferramentas', 'composicao', 'negativas.test.js'
);

const GATE = 'lojaa11y';
const SUITE = 'app/test/casca/loja_a11y_comercial_test.dart';

// ---------------------------------------------------------------------------
// Ferramentas
// ---------------------------------------------------------------------------

function gatesDaFonte() {
  return fs
    .readFileSync(FONTE, 'utf8')
    .split(/\r?\n/)
    .map((l) => l.trim())
    .filter((l) => l && !l.startsWith('#'));
}

/**
 * Monta um diretório de resultados com TODOS os gates verdes, e devolve o
 * caminho. Cada caso depois estraga só o que quer medir.
 */
function resultadosVerdes() {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'portao-'));
  for (const g of gatesDaFonte()) {
    fs.writeFileSync(path.join(dir, `exit_${g}`), '0\n');
  }
  return dir;
}

function rodarAgregador(dir) {
  const r = spawnSync('bash', [AGREGADOR, FONTE, dir], {
    cwd: RAIZ,
    encoding: 'utf8',
  });
  return { codigo: r.status, saida: (r.stdout || '') + (r.stderr || '') };
}

/**
 * O que o passo `roda` do workflow faz quando o arquivo da suíte não existe.
 *
 * Copiado do próprio workflow, e a cópia é intencional: se aquele trecho mudar,
 * esta prova deixa de descrever o CI e tem de ser revista junto.
 *
 *     roda() { k=$1; t=$2
 *       if [ ! -f "app_build/$t" ]; then echo "ausente: $t" > "nao_$k"; return; fi
 *       ... echo ${PIPESTATUS[0]} > "exit_$k"
 *     }
 */
function simularRoda(dir, gate, caminhoDaSuite) {
  const existe = fs.existsSync(path.join(RAIZ, caminhoDaSuite));
  if (!existe) {
    fs.rmSync(path.join(dir, `exit_${gate}`), { force: true });
    fs.writeFileSync(path.join(dir, `nao_${gate}`), `ausente: ${caminhoDaSuite}\n`);
    return 'nao';
  }
  fs.writeFileSync(path.join(dir, `exit_${gate}`), '0\n');
  return 'exit';
}

function rodarNegativas() {
  const r = spawnSync(process.execPath, ['--test', NEGATIVAS], {
    cwd: RAIZ,
    encoding: 'utf8',
  });
  return { codigo: r.status, saida: (r.stdout || '') + (r.stderr || '') };
}

// ---------------------------------------------------------------------------
// Os seis caminhos
// ---------------------------------------------------------------------------

const casos = [];
function caso(id, oQue, esperado, executar) {
  casos.push({ id, oQue, esperado, executar });
}

caso(
  'S-1',
  'estado normal: suíte presente, gate produzido, tudo verde',
  'VERDE',
  () => {
    const dir = resultadosVerdes();
    simularRoda(dir, GATE, SUITE);
    const { codigo } = rodarAgregador(dir);
    fs.rmSync(dir, { recursive: true, force: true });
    return codigo === 0 ? 'VERDE' : `VERMELHO (exit ${codigo})`;
  }
);

caso(
  'S-2',
  'a suíte é APAGADA do repositório',
  'VERMELHO',
  () => {
    const alvo = path.join(RAIZ, SUITE);
    const guardado = fs.readFileSync(alvo);
    try {
      fs.rmSync(alvo);
      const dir = resultadosVerdes();
      // O passo do CI descobre a ausência e escreve o marcador `nao_`.
      const marcador = simularRoda(dir, GATE, SUITE);
      const { codigo, saida } = rodarAgregador(dir);
      fs.rmSync(dir, { recursive: true, force: true });
      if (marcador !== 'nao') return 'INSTRUMENTO QUEBRADO (roda não marcou)';
      return codigo !== 0 && /lojaa11y/.test(saida)
        ? 'VERMELHO'
        : `VERDE (exit ${codigo}) — o portão não viu a ausência`;
    } finally {
      fs.writeFileSync(alvo, guardado);
    }
  }
);

caso(
  'S-3',
  'a suíte é RENOMEADA e o workflow continua apontando para o nome velho',
  'VERMELHO',
  () => {
    const alvo = path.join(RAIZ, SUITE);
    const novo = path.join(RAIZ, 'app/test/casca/loja_a11y_renomeada_test.dart');
    fs.renameSync(alvo, novo);
    try {
      const dir = resultadosVerdes();
      const marcador = simularRoda(dir, GATE, SUITE);
      const { codigo } = rodarAgregador(dir);
      fs.rmSync(dir, { recursive: true, force: true });
      if (marcador !== 'nao') return 'INSTRUMENTO QUEBRADO (roda não marcou)';
      return codigo !== 0 ? 'VERMELHO' : `VERDE (exit ${codigo})`;
    } finally {
      fs.renameSync(novo, alvo);
    }
  }
);

caso(
  'S-4',
  'o gate NÃO É EXECUTADO: nenhum resultado é deixado para ele',
  'VERMELHO',
  () => {
    const dir = resultadosVerdes();
    fs.rmSync(path.join(dir, `exit_${GATE}`), { force: true });
    const { codigo, saida } = rodarAgregador(dir);
    fs.rmSync(dir, { recursive: true, force: true });
    return codigo !== 0 && /lojaa11y/.test(saida)
      ? 'VERMELHO'
      : `VERDE (exit ${codigo}) — ausência de resultado passou`;
  }
);

caso(
  'S-5',
  'o REGISTRO some da fonte única (o gate deixa de ser percorrido)',
  'VERMELHO',
  () => {
    const guardado = fs.readFileSync(FONTE, 'utf8');
    try {
      // Tira a linha do gate, deixando o produtor no workflow: é o CI-02, o
      // defeito de "a suíte roda, fica vermelha, e o portão segue verde".
      const semGate = guardado
        .split(/\r?\n/)
        .filter((l) => l.trim() !== GATE)
        .join('\n');
      fs.writeFileSync(FONTE, semGate);
      const { codigo, saida } = rodarNegativas();
      return codigo !== 0 && /CI-02|PN-12/.test(saida)
        ? 'VERMELHO'
        : `VERDE (exit ${codigo}) — a bijeção não pegou`;
    } finally {
      fs.writeFileSync(FONTE, guardado);
    }
  }
);

caso(
  'S-5b',
  'o PRODUTOR some do workflow (o gate vira fantasma)',
  'VERMELHO',
  () => {
    const guardado = fs.readFileSync(WORKFLOW, 'utf8');
    try {
      const semProdutor = guardado.replace(
        `roda ${GATE}     test/casca/loja_a11y_comercial_test.dart`,
        '# produtor removido pela campanha'
      );
      if (semProdutor === guardado) return 'INSTRUMENTO QUEBRADO (âncora)';
      fs.writeFileSync(WORKFLOW, semProdutor);
      const { codigo, saida } = rodarNegativas();
      return codigo !== 0 && /FANTASMA|PN-10/.test(saida)
        ? 'VERMELHO'
        : `VERDE (exit ${codigo}) — o fantasma passou`;
    } finally {
      fs.writeFileSync(WORKFLOW, guardado);
    }
  }
);

caso(
  'S-6',
  'a suíte RODA E FALHA',
  'VERMELHO',
  () => {
    const dir = resultadosVerdes();
    fs.writeFileSync(path.join(dir, `exit_${GATE}`), '1\n');
    const { codigo, saida } = rodarAgregador(dir);
    fs.rmSync(dir, { recursive: true, force: true });
    return codigo !== 0 && /lojaa11y/.test(saida) ? 'VERMELHO' : `VERDE (exit ${codigo})`;
  }
);

caso(
  'S-7',
  'o resultado do gate é ILEGÍVEL (exit vazio)',
  'VERMELHO',
  () => {
    const dir = resultadosVerdes();
    fs.writeFileSync(path.join(dir, `exit_${GATE}`), '');
    const { codigo } = rodarAgregador(dir);
    fs.rmSync(dir, { recursive: true, force: true });
    return codigo !== 0 ? 'VERMELHO' : `VERDE (exit ${codigo})`;
  }
);

// ---------------------------------------------------------------------------

let falhas = 0;
console.log('SOBREVIVÊNCIA DO GATE `lojaa11y` — §13');
console.log('='.repeat(78));
for (const c of casos) {
  let obtido;
  try {
    obtido = c.executar();
  } catch (e) {
    obtido = `ERRO: ${e.message}`;
  }
  const ok = obtido === c.esperado;
  if (!ok) falhas++;
  console.log(
    `${ok ? 'OK  ' : 'FALHA'} ${c.id.padEnd(5)} ${c.oQue}`
  );
  console.log(`        esperado=${c.esperado}  obtido=${obtido}`);
}
console.log('='.repeat(78));
console.log(
  falhas === 0
    ? `TODOS OS ${casos.length} CAMINHOS SE COMPORTAM COMO A OS EXIGE`
    : `${falhas} CAMINHO(S) NÃO FECHARAM`
);
process.exit(falhas === 0 ? 0 : 1);
