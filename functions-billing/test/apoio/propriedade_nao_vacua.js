#!/usr/bin/env node
/**
 * PROVA DE NAO-VACUIDADE DA PROPRIEDADE EM `reconciliacao.test.js`.
 *
 * POR QUE ESTE ARQUIVO EXISTE
 *
 * `test/reconciliacao.test.js` nasceu na linhagem de fichas/legado, antes de a
 * compra ter dono comprovavel. A composicao com a correcao P0 tornou
 * `uidDoVinculo` uma porta OBRIGATORIA de `criarReconciliador`, e os 13 casos
 * daquela suite ficaram vermelhos de uma vez.
 *
 * Havia um atalho para apaga-los: `uidDoVinculo: async () => UID_DONO`. Ele faz
 * a suite inteira passar e NAO resolve propriedade nenhuma — todo vinculo, bem
 * ou mal formado, conhecido ou nao, viraria o mesmo dono. A suite passaria a
 * provar o contrario do que a correcao fechou, e ninguem veria, porque o verde
 * seria o mesmo verde.
 *
 * O arnes foi adaptado a autoridade REAL: guarda de forma + consulta ao indice
 * `billingAccountIndex`, espelhando `criarStore(...).uidDoVinculo`. Este script
 * prova que a adaptacao vale, do unico jeito que se prova: aplicando o atalho e
 * exigindo VERMELHO.
 *
 * Muta uma COPIA, na mesma pasta (para os `require('../...')` continuarem
 * valendo), e apaga a copia sempre — inclusive quando falha.
 */

'use strict';

const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const DIR_TESTE = path.resolve(__dirname, '..');
const ORIGINAL = path.join(DIR_TESTE, 'reconciliacao.test.js');
const COPIA = path.join(DIR_TESTE, '_mutante_propriedade.test.js');

/**
 * As mutacoes. Cada uma e um jeito plausivel de "consertar" o arnes que na
 * verdade o esvazia — e cada uma tem de derrubar pelo menos um caso.
 *
 * O QUE NAO ESTA AQUI, E POR QUE. Uma quarta mutacao foi tentada e RETIRADA:
 * remover a guarda `vinculoBemFormado` do resolver do arnes. Ela sobreviveu, e
 * sobreviveu com razao — `decidirPropriedade` confere a forma do identificador
 * por conta propria (propriedade.js), entao a guarda do arnes e redundante DE
 * PROPOSITO: ela existe para o dublê espelhar `criarStore(...).uidDoVinculo`
 * linha a linha, e nao para decidir nada. Uma mutacao que nao muda
 * comportamento observavel nao e sobrevivente nem detectada — e instrumento
 * errado, e conta-la como sobrevivente diria que a suite e fraca quando o que
 * ha e defesa em profundidade.
 */
const MUTACOES = [
  {
    id: 'M-CONST',
    o_que: 'o resolver vira constante: todo vinculo devolve o dono',
    de: /const uid = indice\[contaOfuscada\];/,
    para: 'const uid = UID_DONO;',
  },
  {
    id: 'M-INDICE-FROUXO',
    o_que: 'o indice passa a conhecer o vinculo alheio: compra de outro vira sua',
    de: /  indice = \{ \[VINCULO_DONO\]: UID_DONO \},/,
    para: '  indice = { [VINCULO_DONO]: UID_DONO, [VINCULO_ALHEIO]: UID_DONO },',
  },
  {
    id: 'M-SEM-VINCULO',
    o_que: 'a resposta sem vinculo passa a receber o do dono assim mesmo',
    de: /  if \(vinculo === null\) return resposta;/,
    para: '  if (vinculo === null) vinculo = VINCULO_DONO;',
  },
];

function limpar() {
  try { fs.rmSync(COPIA, { force: true }); } catch (_) { /* nada a fazer */ }
}

function rodar(arquivo) {
  const r = spawnSync(process.execPath, ['--test', arquivo], {
    cwd: DIR_TESTE,
    encoding: 'utf8',
  });
  const saida = (r.stdout || '') + (r.stderr || '');
  const num = (re) => {
    const m = saida.match(re);
    return m ? Number(m[1]) : NaN;
  };
  return { testes: num(/tests (\d+)/), passou: num(/pass (\d+)/), falhou: num(/fail (\d+)/) };
}

function principal() {
  limpar();
  const fonte = fs.readFileSync(ORIGINAL, 'utf8');

  // A base tem de nascer verde. Se nao nascer, o instrumento esta errado — e
  // medir mutacao contra uma base vermelha nao diz nada.
  fs.writeFileSync(COPIA, fonte, 'utf8');
  const base = rodar(COPIA);
  if (!Number.isFinite(base.testes) || base.falhou !== 0) {
    limpar();
    console.error(`ABORTADO: a copia limpa nao nasce verde (${base.passou}/${base.testes}, ${base.falhou} falhas).`);
    process.exit(1);
  }
  console.log(`BASE: ${base.passou}/${base.testes} passam, ${base.falhou} falham`);
  console.log('');

  let sobreviventes = 0;
  let vacuas = 0;

  for (const m of MUTACOES) {
    if (!m.de.test(fonte)) {
      console.log(`${m.id}  INSTRUMENTO QUEBRADO — alvo nao encontrado`);
      vacuas++;
      continue;
    }
    const mutado = fonte.replace(m.de, m.para);
    if (mutado === fonte) {
      console.log(`${m.id}  INSTRUMENTO QUEBRADO — a troca nao alterou nada`);
      vacuas++;
      continue;
    }
    fs.writeFileSync(COPIA, mutado, 'utf8');
    const r = rodar(COPIA);
    const detectada = r.falhou > 0;
    if (!detectada) sobreviventes++;
    console.log(
      `${m.id}  ${detectada ? 'DETECTADA' : '*** SOBREVIVEU ***'}  ` +
      `| derrubou ${r.falhou} de ${r.testes} | ${m.o_que}`
    );
  }

  limpar();
  console.log('');
  console.log(`sobreviventes: ${sobreviventes} | instrumentos quebrados: ${vacuas}`);
  if (sobreviventes > 0 || vacuas > 0) {
    console.error('FALHOU: a propriedade nesta suite nao esta sendo realmente resolvida.');
    process.exit(1);
  }
  console.log('OK: a propriedade e resolvida pela autoridade real, e nao por atalho.');
}

try {
  principal();
} catch (e) {
  limpar();
  throw e;
}
