#!/usr/bin/env node
'use strict';
/**
 * CAMPANHA DE MUTAÇÃO DO §19 — a não-vacuidade das 15 provas negativas.
 *
 *   uso: node ferramentas/composicao/mutacoes.js
 *
 * Quinze casos verdes não provam nada enquanto ninguém mostrar que eles sabem
 * ficar vermelhos. Cada mutação aqui INTRODUZ, no código real da árvore
 * composta, exatamente o cenário proibido que a prova correspondente descreve —
 * e exige que aquela prova, nominalmente, reprove.
 *
 * Três desfechos, e só um deles é aceitável:
 *
 *   DETECTADA ............ a prova esperada ficou vermelha
 *   SOBREVIVEU ........... a suíte seguiu verde: a prova e vazia
 *   INSTRUMENTO QUEBRADO . a mutação não pegou no arquivo (âncora ausente ou
 *                          ambígua). Não conta como detectada NEM como
 *                          sobrevivente: significa que a campanha não mediu nada.
 *
 * Restaura sempre, inclusive em falha.
 */

const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const RAIZ = path.resolve(__dirname, '..', '..');
const SUITE = path.join(__dirname, 'negativas.test.js');

const MUTACOES = [
  {
    id: 'MC-01',
    espera: 'PN-01',
    arquivo: 'functions-mesas/src/index.ts',
    o_que: 'a verificacao de token deixa de conferir revogacao',
    de: 'getAuth().verifyIdToken(token, true);',
    para: 'getAuth().verifyIdToken(token);',
  },
  {
    id: 'MC-02',
    espera: 'PN-02',
    arquivo: 'functions-ranking/src/index.ts',
    o_que: 'o claim do motor passa a ser aceito por veracidade',
    de: 'if (token.motorDePartidas !== true && token.admin !== true) {',
    para: 'if (!token.motorDePartidas && token.admin !== true) {',
  },
  {
    id: 'MC-03',
    espera: 'PN-03',
    arquivo: 'functions/src/rastreabilidade.ts',
    o_que: 'uma autoridade interna vaza para a superficie pelo `export *`',
    de: 'export const registrarSinalAntifraude = onCall(',
    para:
      'export const reprocessarTudoSemConferir = onCall(opcoesCliente, async () => ({ ok: true }));\n' +
      'export const registrarSinalAntifraude = onCall(',
  },
  {
    id: 'MC-04',
    espera: 'PN-04',
    arquivo: 'functions-billing/propriedade.js',
    o_que: 'a decisao de propriedade volta a alcancar o chamador',
    de: 'function decidirPropriedade({ identificador, uidResolvido, uidEsperado = null }) {',
    para:
      'function decidirPropriedade({ identificador, uidResolvido, uidEsperado = null, req = null }) {\n' +
      '  if (req && req.auth) uidResolvido = req.auth.uid;',
  },
  {
    id: 'MC-05',
    espera: 'PN-05',
    arquivo: 'functions-billing/entitlementStore.js',
    o_que: 'o uid volta a ser derivado do token de compra',
    de: 'const COL_INDICE_VINCULO = ',
    para:
      'function resolverUidPorToken(purchaseToken) { return String(purchaseToken).slice(0, 28); }\n' +
      'void resolverUidPorToken;\n' +
      'const COL_INDICE_VINCULO = ',
  },
  {
    id: 'MC-06',
    espera: 'PN-06',
    arquivo: 'functions-ranking/src/passe.ts',
    o_que: 'a cortesia passa a escrever no direito pago',
    de: 'export interface ContextoEstavelDoRecibo {',
    para:
      'export async function concederPorCortesia(db: any, uid: string) {\n' +
      '  await db.collection("playerEntitlements").doc(uid).set({ vip: true });\n' +
      '}\n' +
      'export interface ContextoEstavelDoRecibo {',
  },
  {
    id: 'MC-07',
    espera: 'PN-07',
    arquivo: '.github/workflows/ci-os-integracao.yml',
    o_que: 'uma codebase implantavel volta a ficar sem passo no CI',
    de: '          ( cd functions-mesas && npm test ) 2>&1 | tee t_mesasfn.log\n          echo ${PIPESTATUS[0]} > exit_mesasfn',
    para: '          echo "pulado" > exit_mesasfn',
    // O passo ainda cita a pasta na guarda de existência; a mutação tira o que
    // de fato a exercita. Para PN-07 medir isso, tiramos as menções também.
    tambem: {
      de: '          if [ ! -f functions-mesas/package.json ]; then\n            echo "functions-mesas/package.json ausente" > nao_mesasfn; exit 0\n          fi\n          ( cd functions-mesas && npm install 2>&1 | tail -3 )\n',
      para: '',
    },
  },
  {
    id: 'MC-08',
    espera: 'PN-08',
    arquivo: 'functions-moderacao/src/chat.ts',
    o_que: 'a projecao volta a espalhar o documento do Firestore',
    de: '  return exigirEntregaSegura({\n    messageId: doc.messageId,',
    para: '  return exigirEntregaSegura({\n    ...(doc as unknown as Record<string, unknown>),\n    messageId: doc.messageId,',
  },
  {
    id: 'MC-09',
    espera: 'PN-09',
    arquivo: 'firebase/firestore.rules',
    o_que: 'as Rules abrem escrita numa colecao reservada',
    de: 'match /billingAccountIndex/{contaOfuscada} {',
    para: 'match /billingAccountIndex/{contaOfuscada} {\n      allow write: if request.auth != null;',
  },
  {
    id: 'MC-10',
    espera: 'PN-10',
    arquivo: 'scripts/ci/gates_os_integracao.txt',
    o_que: 'um gate FANTASMA volta para a fonte unica',
    // Ancora no FIM do arquivo, e nao no nome do gate: `composneg` aparece
    // tres vezes, duas delas na prosa que explica o gate.
    de: '\nproveni\ncomposneg\n',
    para: '\nproveni\ncomposneg\nregras\n',
  },
  {
    id: 'MC-11',
    espera: 'PN-11',
    arquivo: 'functions-ranking/src/passe.ts',
    o_que: 'contexto guardado AUSENTE volta a passar por "mesmo contexto"',
    de: '  if (guardado === null || guardado === undefined) return false;',
    para: '  if (guardado === undefined) return false;',
  },
  {
    id: 'MC-12',
    espera: 'PN-12',
    arquivo: 'scripts/ci/gates_os_integracao.txt',
    o_que: 'um gate que RODA sai da fonte unica — o defeito CI-02 original',
    de: '\npasseint\n',
    para: '\n',
  },
  {
    id: 'MC-13',
    espera: 'PN-13',
    arquivo: 'firebase.json',
    o_que: 'o manifesto deixa de apontar para uma pasta que existe no disco',
    // A primeira versao renomeava `codebase`, e PN-13 sobreviveu com razao:
    // ele compara `source`, que e o que decide QUE PASTA sobe. Renomear o
    // rotulo nao tira a pasta do deploy; apontar a `source` para outro lugar,
    // sim — e e assim que uma codebase para de subir sem ninguem notar.
    de: '"source": "functions-economia",',
    para: '"source": "functions-economia-antigo",',
  },
  {
    id: 'MC-14',
    espera: 'PN-14',
    arquivo: 'functions/src/rastreabilidade.ts',
    o_que: 'o encerramento volta a decidir a autoridade do motor por `req.auth.token`',
    de: 'async function exigirAutoridadeDePartida(req: CallableRequest): Promise<string> {\n  const uid = exigirAutenticacao(req);',
    para:
      'async function exigirAutoridadeDePartida(req: CallableRequest): Promise<string> {\n' +
      '  const uid = exigirAutenticacao(req);\n' +
      '  if (req.auth?.token?.motorDePartidas === true) return uid;',
  },
  {
    id: 'MC-15',
    espera: 'PN-15',
    arquivo: 'firebase.json',
    o_que: 'uma codebase passa a poder ser implantada sem proveniencia',
    // Ancora qualificada pela codebase: a forma de DOIS passos aparece tres
    // vezes no manifesto (colecoes, billing e economia).
    de: '"predeploy": ["node ferramentas/proveniencia/gerar.js", "node ferramentas/proveniencia/verificar.js"],\r\n      "ignore": ["node_modules", ".git", "firebase-debug.log"',
    para: '"predeploy": [],\r\n      "ignore": ["node_modules", ".git", "firebase-debug.log"',
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
  // Os nomes dos casos não carregam o prefixo PN — ele está no `describe`. O
  // resumo final do runner lista os `describe` reprovados, e é dali que sai a
  // atribuição. Buscar no texto inteiro basta: `PN-xx` só aparece em título.
  const reprovados = new Set();
  for (const bloco of saida.split('\n')) {
    const m = bloco.match(/^✖ (PN-\d+)/);
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
  const trocas = [{ de: m.de, para: m.para }].concat(m.tambem ? [m.tambem] : []);
  let saida = texto;
  for (const t of trocas) {
    const de = paraEol(t.de, texto);
    const para = paraEol(t.para, texto);
    const n = saida.split(de).length - 1;
    if (n !== 1) return { erro: `alvo aparece ${n}x (esperado 1): ${JSON.stringify(t.de.slice(0, 50))}` };
    saida = saida.replace(de, para);
  }
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
  console.log('OK: as 15 provas negativas reprovam o cenario que cada uma descreve.');
  return 0;
}

try {
  process.exit(principal());
} catch (e) {
  restaurar();
  throw e;
}
