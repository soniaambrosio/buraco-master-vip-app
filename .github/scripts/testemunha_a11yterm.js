// testemunha_a11yterm.js — o gate `a11yterm` lido pelo que ele PRODUZIU.
//
// ---------------------------------------------------------------------------
// POR QUE UMA TESTEMUNHA, SE O GATE JÁ É OBRIGATÓRIO
// ---------------------------------------------------------------------------
//
// `roda_obrigatorio` responde uma pergunta só: o passo rodou? Um `echo "+21:
// All tests passed!"` responde essa pergunta do mesmo jeito que a execução de
// verdade. Esta testemunha responde a seguinte — o que a execução produziu —, e
// ela não aceita nada escrito à mão:
//
//   * o marcador `exit_<gate>` existe e vale zero;
//   * o log existe, não está vazio e é MAIS NOVO que o carimbo gravado antes
//     da execução (log velho é resultado reaproveitado);
//   * o relatório de máquina do Flutter existe e diz `"success": true`;
//   * o placar real tem no mínimo o piso de casos, zero falhas e zero
//     desligados;
//   * TODOS os casos vieram do caminho canônico — nenhum de arquivo isca com
//     os mesmos nomes;
//   * cada caso da relação nominal RODOU E PASSOU.
//
// ---------------------------------------------------------------------------
// A LISTA NOMINAL NÃO MORA AQUI
// ---------------------------------------------------------------------------
//
// Ela mora em `app/test/casca/auditoria_casca_test.dart`, que é a fonte única
// de gates. Este arquivo a LÊ de lá. Uma cópia da lista aqui seria uma segunda
// fonte: no dia em que as duas divergissem, nenhuma seria autoridade — e a
// forma mais barata de burlar as duas é editar só a que ninguém está olhando.
//
// Consequência deliberada: apagar a lista da fonte única não afrouxa esta
// testemunha, faz ela reprovar por não encontrar o contrato.
//
// Uso:
//   node .github/scripts/testemunha_a11yterm.js <dirDosArtefatos> <fonteDeGates>
//
// Sai 0 se tudo bate; 1 com o motivo impresso, em qualquer outro caso.

'use strict';

const fs = require('fs');
const path = require('path');

const GATE = 'a11yterm';
const PISO = 21;

const [dirArtefatos, fonteDeGates] = process.argv.slice(2);

const erros = [];
const reprova = (m) => erros.push(m);

/// O conteúdo do arquivo, ou `null` se ele NÃO EXISTE.
///
/// A distinção importa: "não existe" é um veredito — significa que o gate não
/// produziu a prova. Qualquer outro erro de leitura é outra coisa, e tratá-lo
/// como ausência faria a testemunha acusar um sumiço que não houve. Um arquivo
/// que o processo de teste acabou de soltar pode recusar a primeira leitura;
/// ele é tentado de novo, e se ainda assim não abrir, o motivo REAL é
/// reportado.
function ler(p) {
  let ultimo;
  for (let i = 0; i < 5; i++) {
    try {
      return fs.readFileSync(p, 'utf8');
    } catch (e) {
      if (e.code === 'ENOENT') return null;
      ultimo = e;
      const t = Date.now();
      while (Date.now() - t < 150) {
        /* espera curta, sem depender de temporizador */
      }
    }
  }
  reprova(`não consegui ler ${p}: ${ultimo && ultimo.code}`);
  return null;
}

// ---------------------------------------------------------------------------
// 1. O contrato, lido da fonte única
// ---------------------------------------------------------------------------

/// Os literais de uma lista `const List<String> nome = <String>[ ... ];`.
function listaDeStrings(fonte, nome) {
  const abre = fonte.indexOf(`${nome} = <String>[`);
  if (abre < 0) return null;
  const fim = fonte.indexOf('];', abre);
  if (fim < 0) return null;
  const corpo = fonte.slice(abre, fim);
  const itens = [];
  // Um item por linha, entre aspas simples e terminado em vírgula. É a forma
  // em que a fonte única declara a lista, e ela é conferida como texto porque
  // este processo não executa Dart.
  for (const linha of corpo.split(/\r?\n/)) {
    const m = /^\s*'(.*)',\s*$/.exec(linha);
    if (m) itens.push(m[1]);
  }
  return itens;
}

function constanteTexto(fonte, nome) {
  const m = new RegExp(`${nome}\\s*=\\s*'([^']*)'`).exec(fonte);
  return m ? m[1] : null;
}

const contrato = ler(fonteDeGates);
if (contrato === null) {
  reprova(
    `a fonte única de gates não foi encontrada em ${fonteDeGates} — sem ela ` +
      `não existe contrato para conferir`,
  );
}

const caminhoCanonico = contrato && constanteTexto(contrato, 'kCaminhoA11yTerm');
const nominais = contrato && listaDeStrings(contrato, 'kCasosOriginaisA11yTerm');

if (contrato !== null && !caminhoCanonico) {
  reprova('kCaminhoA11yTerm sumiu da fonte única de gates');
}
if (contrato !== null && (!nominais || nominais.length < PISO)) {
  reprova(
    `kCasosOriginaisA11yTerm tem ${nominais ? nominais.length : 0} casos na ` +
      `fonte única, e o contrato são ${PISO}`,
  );
}

// ---------------------------------------------------------------------------
// 2. Os artefatos que a execução deixou
// ---------------------------------------------------------------------------

const pExit = path.join(dirArtefatos, `exit_${GATE}`);
const pLog = path.join(dirArtefatos, `t_${GATE}.log`);
const pRel = path.join(dirArtefatos, `rel_${GATE}.json`);
const pCarimbo = path.join(dirArtefatos, `carimbo_${GATE}`);

const marcador = ler(pExit);
if (marcador === null) {
  reprova(`não existe ${pExit} — o gate não chegou a ser executado`);
} else if (marcador.trim() !== '0') {
  reprova(`${pExit} = ${marcador.trim()} (a suíte falhou)`);
}

const log = ler(pLog);
if (!log || !log.trim()) {
  reprova(`${pLog} ausente ou vazio — marcador sem log não é prova`);
}

const carimbo = ler(pCarimbo);
if (carimbo === null) {
  reprova(`${pCarimbo} ausente — sem ele não dá para datar o log`);
} else if (log) {
  const inicio = Number(carimbo.trim());
  const gravado = Math.floor(fs.statSync(pLog).mtimeMs / 1000);
  if (!(gravado > inicio)) {
    reprova(
      `${pLog} (${gravado}) não é mais novo que o carimbo (${inicio}) — ` +
        `resultado reaproveitado de outra execução`,
    );
  }
}

// ---------------------------------------------------------------------------
// 3. O relatório de máquina: nomes, origem e placar
// ---------------------------------------------------------------------------

const relBruto = ler(pRel);
if (!relBruto || !relBruto.trim()) {
  reprova(
    `${pRel} ausente — sem o relatório de máquina não há como conferir nomes ` +
      `nem origem dos casos`,
  );
} else {
  const casos = new Map();
  let concluiu = null;
  for (const linha of relBruto.split(/\r?\n/)) {
    if (!linha.trim()) continue;
    let e;
    try {
      e = JSON.parse(linha);
    } catch {
      continue;
    }
    if (e.type === 'testStart' && !/^loading /.test(e.test.name)) {
      casos.set(e.test.id, {
        nome: e.test.name,
        origem: String(e.test.root_url || e.test.url || '').replace(/\\/g, '/'),
        desligado: !!(e.test.metadata && e.test.metadata.skip),
        resultado: null,
      });
    }
    if (e.type === 'testDone' && casos.has(e.testID)) {
      const c = casos.get(e.testID);
      c.resultado = e.skipped ? 'skipped' : e.result;
    }
    if (e.type === 'done') concluiu = e.success;
  }

  const todos = [...casos.values()];

  if (concluiu !== true) {
    reprova('o relatório de máquina não diz "success": true');
  }
  if (todos.length < PISO) {
    reprova(`placar real: ${todos.length} casos, e o piso é ${PISO}`);
  }

  const ruins = todos.filter((c) => c.resultado !== 'success');
  if (ruins.length) {
    reprova(`casos que não passaram: ${ruins.map((c) => c.nome).join(' | ')}`);
  }

  const pulados = todos.filter((c) => c.desligado || c.resultado === 'skipped');
  if (pulados.length) {
    reprova(`casos desligados: ${pulados.map((c) => c.nome).join(' | ')}`);
  }

  if (caminhoCanonico) {
    const forasteiros = todos.filter((c) => !c.origem.endsWith(caminhoCanonico));
    if (forasteiros.length) {
      reprova(
        'casos vindos de FORA do caminho canônico: ' +
          forasteiros.map((c) => `${c.nome} <- ${c.origem}`).join(' | '),
      );
    }
  }

  const nomes = new Set(todos.map((c) => c.nome));
  if (nomes.size !== todos.length) {
    reprova(
      `há nome repetido no resultado (${todos.length} casos, ${nomes.size} ` +
        `nomes) — duplicar repõe contagem sem repor prova`,
    );
  }

  if (nominais) {
    // Contra o RESULTADO, e não contra o código-fonte: é a diferença entre "o
    // nome está escrito no arquivo" e "o caso com esse nome rodou e passou".
    const passaram = new Set(
      todos.filter((c) => c.resultado === 'success').map((c) => c.nome),
    );
    const faltando = nominais.filter((n) => !passaram.has(n));
    if (faltando.length) {
      reprova(
        `casos da relação nominal que não rodaram e passaram: ` +
          faltando.join(' | '),
      );
    }
  }
}

// ---------------------------------------------------------------------------
// 4. O log, que é o que uma pessoa lê
// ---------------------------------------------------------------------------

if (log && caminhoCanonico) {
  if (!log.includes(caminhoCanonico)) {
    reprova(
      `o log não menciona ${caminhoCanonico} — outro arquivo foi executado no ` +
        `lugar da suíte canônica`,
    );
  }
  if (!/^\d{2}:\d{2} \+\d+: All tests passed!/m.test(log)) {
    reprova(`o log não termina em "All tests passed!"`);
  }
}

// ---------------------------------------------------------------------------

if (erros.length) {
  for (const e of erros) console.log(`TESTEMUNHA ${GATE} REPROVOU: ${e}`);
  process.exit(1);
}
console.log(
  `testemunha ${GATE}: resultado real conferido contra ${nominais.length} ` +
    `casos nominais de ${caminhoCanonico}`,
);
