#!/usr/bin/env node
'use strict';
/**
 * CAMPANHA DE MUTAÇÃO DO §6 — a não-vacuidade do gate da composição
 * Loja/Casca ↔ Functions canônicas.
 *
 *   uso: node ferramentas/composicao/mutacoes_loja.js
 *
 * Mesma doutrina de `mutacoes.js`, ao lado, e pelo mesmo motivo: 34 casos
 * verdes não provam nada enquanto ninguém mostrar que eles sabem ficar
 * vermelhos. Cada mutação aqui REMOVE da árvore composta exatamente aquilo que
 * a OS manda provar removível — uma codebase, um export, um gate de
 * proveniência, um gate da Loja, a ligação da sessão, o estado vazio do
 * Ranking, a ausência de `RankingVM.mock()`, a exclusão de
 * `playerCourtesyPass` — e exige que o caso correspondente reprove.
 *
 * Três desfechos, e só um é aceitável:
 *
 *   DETECTADA ............ o caso esperado ficou vermelho
 *   SOBREVIVEU ........... a suíte seguiu verde: o caso é vazio
 *   INSTRUMENTO QUEBRADO . a mutação não pegou no arquivo (âncora ausente ou
 *                          ambígua). Não conta como detectada NEM como
 *                          sobrevivente: significa que a campanha não mediu.
 *
 * A NONA remoção que a OS exige — a de uma das ANCESTRALIDADES — não cabe aqui,
 * e não por esquecimento: ela não é uma edição de arquivo. Prova-se rodando
 * este mesmo `loja_functions.test.js` a partir de uma árvore que descende de
 * UMA das folhas só; CL-01 reprova lá, e o relatório da OS registra o comando.
 *
 * Restaura sempre, inclusive em falha.
 */

const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const RAIZ = path.resolve(__dirname, '..', '..');
const SUITE = path.join(__dirname, 'loja_functions.test.js');

const MUTACOES = [
  {
    id: 'ML-01',
    espera: 'CL-03',
    arquivo: 'firebase.json',
    o_que: 'uma codebase some do manifesto (a da exclusao de conta)',
    de: '"source": "functions-conta",',
    para: '"source": "functions-conta-DESLIGADA",',
  },
  {
    id: 'ML-02',
    espera: 'CL-04',
    arquivo: 'functions-conta/src/index.ts',
    o_que: 'um export some da superficie implantada',
    de: 'export const resumirExclusaoDeConta',
    para: 'const resumirExclusaoDeConta',
  },
  {
    id: 'ML-03',
    espera: 'CL-05',
    arquivo: 'scripts/ci/gates_os_integracao.txt',
    o_que: 'o gate de proveniencia sai da fonte unica (lado das Functions)',
    de: '\nproveni\n',
    para: '\n',
  },
  {
    id: 'ML-04',
    espera: 'CL-05',
    arquivo: 'scripts/ci/gates_os_integracao.txt',
    o_que: 'o gate da Loja sai da fonte unica (lado da Loja)',
    de: '\ncascaloja\n',
    para: '\n',
  },
  {
    id: 'ML-05',
    espera: 'CL-02',
    arquivo: 'ferramentas/proveniencia/gerar.js',
    o_que: 'o gerador de proveniencia vira casca sem superficie',
    de: 'module.exports',
    para: 'const naoExporta',
  },
  {
    id: 'ML-06',
    espera: 'CL-09',
    arquivo: 'app/lib/casca/loja_de_producao.dart',
    o_que: 'a Loja passa a assinar o estado de autenticacao por conta propria',
    de: 'class LojaDeProducao',
    para:
      'void _segundoDono() {\n' +
      '  FirebaseAuth.instance.authStateChanges().listen((u) {});\n' +
      '}\n\n' +
      'class LojaDeProducao',
  },
  {
    id: 'ML-07',
    espera: 'CL-07',
    arquivo: 'app/lib/screens/ranking_screen.dart',
    o_que: 'a fabrica de ranking de maquete volta ao app',
    de: 'class RankingVM',
    para:
      'RankingVM _rankingDeMaquete() => RankingVM.mock();\n\n' +
      'class RankingVM',
  },
  {
    id: 'ML-08',
    espera: 'CL-07',
    arquivo: 'app/lib/services/ranking_service.dart',
    o_que: 'o estado vazio do Ranking perde a fonte que o produz',
    de: 'class RankingSemFonte',
    para: 'class RankingComAlgumaCoisa',
  },
  {
    id: 'ML-09',
    espera: 'CL-10',
    arquivo: 'functions-conta/src/inventario.ts',
    o_que: 'o passe de cortesia deixa de ser apagado na exclusao de conta',
    de: 'playerCourtesyPass',
    para: 'playerCourtesyPassDESLIGADO',
    todas: true,
  },
  {
    id: 'ML-10',
    espera: 'CL-08',
    arquivo: '.github/workflows/ci-os-integracao.yml',
    o_que: 'a suite de `const RankingPage()` sem fonte perde o produtor',
    de: 'roda rkpagina     test/ranking_page_test.dart',
    para: '# roda rkpagina removido',
  },
  {
    id: 'ML-11',
    espera: 'CL-11',
    arquivo: 'app/lib/casca/loja_de_producao.dart',
    o_que: 'dado de maquete entra no caminho publicavel da Loja',
    de: 'class LojaDeProducao',
    para:
      'final _vitrineDeMaquete = LojaVM.mock();\n\n' +
      'class LojaDeProducao',
  },
];

function rodarSuite() {
  const r = spawnSync(process.execPath, ['--test', SUITE], {
    cwd: RAIZ,
    encoding: 'utf8',
    shell: false,
  });
  const saida = (r.stdout || '') + (r.stderr || '');
  const num = (re) => {
    const m = saida.match(re);
    return m ? Number(m[1]) : NaN;
  };
  // Igual a `mutacoes.js`: o prefixo `CL-xx` só existe no título do `describe`,
  // e o resumo do runner lista os `describe` reprovados.
  const reprovados = new Set();
  for (const linha of saida.split('\n')) {
    const m = linha.match(/^✖ (CL-\d+)/);
    if (m) reprovados.add(m[1]);
  }
  return {
    testes: num(/tests (\d+)/),
    passou: num(/pass (\d+)/),
    falhou: num(/fail (\d+)/),
    reprovados: [...reprovados],
  };
}

const originais = new Map();
for (const nome of new Set(MUTACOES.map((m) => m.arquivo))) {
  originais.set(nome, fs.readFileSync(path.join(RAIZ, nome), 'utf8'));
}
const restaurar = () => {
  for (const [nome, texto] of originais) fs.writeFileSync(path.join(RAIZ, nome), texto, 'utf8');
};

/** Normaliza o fim de linha do alvo ao do arquivo — CRLF já custou caro aqui. */
function paraEol(texto, alvo) {
  return alvo.includes('\r\n') ? texto.replace(/\r?\n/g, '\r\n') : texto.replace(/\r\n/g, '\n');
}

function aplicar(m) {
  const texto = originais.get(m.arquivo);
  const de = paraEol(m.de, texto);
  const para = paraEol(m.para, texto);
  const n = texto.split(de).length - 1;
  if (n === 0) return { erro: `alvo ausente: ${JSON.stringify(m.de.slice(0, 50))}` };
  if (!m.todas && n !== 1) return { erro: `alvo aparece ${n}x (esperado 1): ${JSON.stringify(m.de.slice(0, 50))}` };
  const saida = m.todas ? texto.split(de).join(para) : texto.replace(de, para);
  if (saida === texto) return { erro: 'a troca nao alterou o arquivo' };
  fs.writeFileSync(path.join(RAIZ, m.arquivo), saida, 'utf8');
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
  let foraDoAlvo = 0;

  for (const m of MUTACOES) {
    const r = aplicar(m);
    if (r.erro) {
      console.log(`${m.id}  INSTRUMENTO QUEBRADO — ${r.erro}`);
      quebradas++;
      restaurar();
      continue;
    }
    const res = rodarSuite();
    const noAlvo = res.reprovados.includes(m.espera);
    const alguma = Number.isFinite(res.falhou) ? res.falhou > 0 : true;

    let veredito;
    if (noAlvo) veredito = 'DETECTADA';
    else if (alguma) { veredito = 'FORA DO ALVO'; foraDoAlvo++; }
    else { veredito = '*** SOBREVIVEU ***'; sobreviventes++; }

    console.log(
      `${m.id}  ${veredito.padEnd(18)} espera ${m.espera} | reprovou ${res.reprovados.join(',') || '(nada)'} | ${m.o_que}`
    );
    restaurar();
  }

  const depois = rodarSuite();
  console.log('');
  console.log(`RESTAURADO: ${depois.passou}/${depois.testes} passam, ${depois.falhou} falham`);
  console.log(
    `sobreviventes: ${sobreviventes} | fora do alvo: ${foraDoAlvo} | instrumentos quebrados: ${quebradas}`
  );
  if (sobreviventes > 0 || quebradas > 0 || foraDoAlvo > 0 || depois.falhou !== 0) return 1;
  console.log('OK: o gate da composicao reprova cada remocao que a OS manda provar removivel.');
  return 0;
}

try {
  process.exit(principal());
} catch (e) {
  restaurar();
  throw e;
}
