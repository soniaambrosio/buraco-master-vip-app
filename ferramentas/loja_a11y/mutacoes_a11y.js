#!/usr/bin/env node
'use strict';
/**
 * CAMPANHA DE MUTAÇÃO DO §12 — a não-vacuidade do gate `lojaa11y`.
 *
 *   uso: node ferramentas/loja_a11y/mutacoes_a11y.js
 *
 * Mesma doutrina de `ferramentas/composicao/mutacoes.js` e `mutacoes_loja.js`,
 * e pelo mesmo motivo: 43 casos verdes não provam nada enquanto ninguém
 * mostrar que eles sabem ficar vermelhos. Cada mutação aqui DESFAZ exatamente
 * uma das correções que a OS 14-C1 mandou fazer, e exige que a suíte reprove.
 *
 * Três desfechos, e só um é aceitável:
 *
 *   DETECTADA ............ a suíte ficou vermelha
 *   SOBREVIVEU ........... a suíte seguiu verde: o caso correspondente é vazio
 *   INSTRUMENTO QUEBRADO . a âncora não casou, ou casou em mais de um lugar.
 *                          Não conta como detectada NEM como sobrevivente:
 *                          significa que a campanha não mediu nada ali.
 *
 * A distinção do terceiro desfecho é o que impede a campanha de mentir. Uma
 * âncora que não casa produz "suíte verde" — indistinguível, sem esta
 * verificação, de uma mutação que sobreviveu.
 *
 * Restaura sempre, inclusive em falha.
 */

const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const RAIZ = path.resolve(__dirname, '..', '..');
const APP = path.join(RAIZ, 'app');
const SUITE = 'test/casca/loja_a11y_comercial_test.dart';

const TELA = 'app/lib/screens/loja_screen.dart';
const CASCA = 'app/lib/casca/loja_de_producao.dart';

const MUTACOES = [
  {
    id: 'MA-01',
    espera: 'PROVA-01',
    o_que: 'o botão de voltar perde o nome',
    arquivo: TELA,
    de: "            label: 'Voltar',\n",
    para: '',
  },
  {
    id: 'MA-02',
    espera: 'PROVA-03',
    o_que: 'o card de plano volta a chamar a compra direto',
    arquivo: TELA,
    de: '    widget.onSelecionarPlano?.call(plano.id);',
    para: '    widget.onAssinar(plano.id);',
  },
  {
    id: 'MA-03',
    espera: 'PROVA-06',
    o_que: 'a trava de múltiplos toques sai do caminho',
    arquivo: TELA,
    de: '  bool get _travado => _intencaoEnviada || widget.estadoDaCompra.emCurso;',
    para: '  bool get _travado => false;',
  },
  {
    id: 'MA-04',
    espera: 'PROVA-04',
    o_que: 'o `selected` do card de plano desaparece',
    arquivo: TELA,
    de: '      button: true,\n      selected: selected,\n      label: _rotulo,',
    para: '      button: true,\n      label: _rotulo,',
  },
  {
    id: 'MA-05',
    espera: 'PROVA-07 / PROVA-08',
    o_que: 'o resultado da compra deixa de chegar à tela',
    arquivo: CASCA,
    de: '      estadoDaCompra: estadoDaCompraParaLoja(_painel.compra),',
    para: '      // estadoDaCompra: removido pela campanha',
  },
  {
    id: 'MA-06',
    espera: 'PROVA-07 / PROVA-08 / PROVA-10',
    o_que: 'o anúncio de transição é removido',
    arquivo: TELA,
    de: '    _anunciarTransicoes(oldWidget);',
    para: '    // _anunciarTransicoes(oldWidget); removido pela campanha',
  },
  {
    id: 'MA-07',
    espera: 'PROVA-12',
    o_que: 'o card de plano volta à altura fixa que estoura em 200%',
    arquivo: TELA,
    // `IntrinsicHeight(child: …)` e `SizedBox(height: 132, child: …)` têm a
    // MESMA estrutura de parênteses, então a troca é local e o arquivo continua
    // compilando. É o que separa "a suíte pegou a regressão" de "a suíte pegou
    // um erro de sintaxe" — a primeira versão desta mutação não compilava, e
    // uma mutação que não compila não prova que o caso de escala funciona.
    de: '          IntrinsicHeight(\n            child: Row(',
    para: '          SizedBox(\n            height: 132,\n            child: Row(',
  },
  {
    id: 'MA-08',
    espera: 'PROVA-13',
    o_que: 'o contraste do desconto volta ao valor auditado',
    arquivo: TELA,
    de: "                                ? const Color(0xFF0F3D2A)",
    para: "                                ? const Color(0xFF5BE0A2)",
  },
  {
    id: 'MA-09',
    espera: 'PROVA-02',
    o_que: 'o botão de fechar a folha perde o nome',
    arquivo: TELA,
    de: '              label: rotuloFechar,\n',
    para: '',
  },
  {
    id: 'MA-10',
    espera: 'PROVA-11',
    o_que: 'a navegação inferior volta a ficar abaixo de 48 dp',
    arquivo: TELA,
    de: '            constraints: const BoxConstraints(minHeight: 48),',
    // `maxHeight` junto, e não só o mínimo derrubado: o conteúdo do item já
    // soma mais de 48 sozinho, então baixar apenas o piso não encolhe nada — a
    // primeira versão desta mutação sobreviveu exatamente por isso, e a
    // sobrevivência estava certa: ela não mudava o que o caso mede.
    para:
        '            constraints: const BoxConstraints(minHeight: 20, maxHeight: 30),',
  },
  {
    id: 'MA-11',
    espera: 'PROVA-11',
    o_que: 'o rótulo inativo da navegação volta ao contraste auditado',
    arquivo: TELA,
    de: '                        : Colors.white.withValues(alpha: .55),',
    para: '                        : Colors.white.withValues(alpha: .26),',
    // Este par não é medido pela árvore, e sim pelo caso de contraste que lê a
    // COMPOSIÇÃO. Ver a observação no relatório: ele é detectado por PROVA-13.
    esperaAlternativa: 'PROVA-13',
  },
  {
    id: 'MA-12',
    espera: 'PROVA-09',
    o_que: 'o texto de compra concluída passa a afirmar VIP',
    arquivo: TELA,
    de: "      'Compra confirmada. Seu acesso VIP é liberado assim que o servidor '\n          'terminar de registrar.',",
    para: "      'Compra confirmada. Você é VIP.',",
  },
];

// ---------------------------------------------------------------------------

function rodarSuite() {
  const r = spawnSync(
    'flutter',
    ['test', SUITE, '-r', 'compact'],
    { cwd: APP, encoding: 'utf8', shell: true }
  );
  return {
    codigo: r.status,
    saida: (r.stdout || '') + (r.stderr || ''),
  };
}

/** Quais PROVA-xx reprovaram, lidas da saída. */
function provasVermelhas(saida) {
  const nomes = new Set();
  for (const m of saida.matchAll(/(PROVA-\d+)/g)) {
    // Só interessa o que aparece junto de falha; a saída compacta lista o caso
    // corrente em cada linha, então filtramos pelas linhas de erro.
    nomes.add(m[1]);
  }
  const vermelhas = new Set();
  for (const linha of saida.split(/\r?\n/)) {
    if (!/\[E\]|Test failed|TestFailure/.test(linha)) continue;
    for (const m of linha.matchAll(/(PROVA-\d+)/g)) vermelhas.add(m[1]);
  }
  return { todas: [...nomes], vermelhas: [...vermelhas] };
}

console.log('CAMPANHA DE MUTAÇÃO DO GATE `lojaa11y` — §12');
console.log('='.repeat(78));

// Antes de tudo: a suíte tem de estar VERDE, senão a campanha não mede nada.
const base = rodarSuite();
if (base.codigo !== 0) {
  console.error('A suíte já está vermelha SEM mutação. A campanha não mede nada.');
  console.error(base.saida.slice(-3000));
  process.exit(2);
}
console.log('base: suíte verde antes de qualquer mutação\n');

let detectadas = 0;
let sobreviveram = 0;
let quebradas = 0;

/**
 * Ajusta a âncora ao fim-de-linha REAL do arquivo.
 *
 * Os `.dart` de `app/` estão em CRLF, e uma âncora escrita com `\n` casa ZERO
 * vezes num deles. Na primeira rodada desta campanha isso derrubou cinco das
 * doze mutações como "instrumento quebrado" — que é o desfecho certo (elas não
 * mediram nada), mas por um motivo trivial e evitável.
 */
function normalizarEol(texto, arquivoTexto) {
  const crlf = /\r\n/.test(arquivoTexto);
  if (!crlf) return texto;
  return texto.replace(/\r?\n/g, '\r\n');
}

for (const m of MUTACOES) {
  const alvo = path.join(RAIZ, m.arquivo);
  const original = fs.readFileSync(alvo, 'utf8');
  m.de = normalizarEol(m.de, original);
  m.para = normalizarEol(m.para, original);

  const ocorrencias = original.split(m.de).length - 1;
  if (ocorrencias !== 1) {
    quebradas++;
    console.log(
      `INSTRUMENTO QUEBRADO ${m.id} — âncora casou ${ocorrencias}x em ${m.arquivo}`
    );
    console.log(`        ${m.o_que}\n`);
    continue;
  }

  try {
    let mutado = original.replace(m.de, m.para);
    if (m.ajuste) mutado = m.ajuste(mutado);
    fs.writeFileSync(alvo, mutado);

    const r = rodarSuite();
    const { vermelhas } = provasVermelhas(r.saida);

    if (r.codigo === 0) {
      sobreviveram++;
      console.log(`SOBREVIVEU ${m.id} — ${m.o_que}`);
      console.log(`        esperava ${m.espera} vermelha; a suíte ficou verde\n`);
    } else {
      detectadas++;
      const esperadas = [m.espera, m.esperaAlternativa]
        .filter(Boolean)
        .flatMap((e) => e.split(' / '));
      const bateu = esperadas.some((e) => vermelhas.includes(e));
      console.log(`DETECTADA  ${m.id} — ${m.o_que}`);
      console.log(
        `        reprovou: ${vermelhas.join(', ') || '(compilação)'}` +
          (bateu ? '' : `  [esperava ${m.espera}]`)
      );
      console.log('');
    }
  } finally {
    fs.writeFileSync(alvo, original);
  }
}

console.log('='.repeat(78));
console.log(
  `DETECTADAS ${detectadas}   SOBREVIVERAM ${sobreviveram}   ` +
    `INSTRUMENTO QUEBRADO ${quebradas}`
);

// Confere que a árvore voltou ao estado original.
const conferencia = rodarSuite();
console.log(
  conferencia.codigo === 0
    ? 'restauração conferida: a suíte voltou a passar'
    : 'ATENÇÃO: a árvore NÃO foi restaurada corretamente'
);

process.exit(sobreviveram === 0 && quebradas === 0 && conferencia.codigo === 0 ? 0 : 1);
