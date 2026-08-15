// recibo.js — a identidade e a prova documental de UMA execucao do portao.
//
// O DEFEITO QUE ESTE ARQUIVO EXISTE PARA IMPEDIR:
//
// Um recibo e um arquivo. Arquivos sobrevivem a execucao que os escreveu — a um
// Ctrl+C, a um `git checkout` de outra branch, a uma semana de feriado. No
// instante em que alguem (ou um passo de pipeline) le `ultimo.json` e conclui
// "a RC passou", a pergunta que importa deixou de ser "o que o recibo diz?" e
// passou a ser "o recibo e DESTA execucao?".
//
// Esse e o falso verde mais silencioso de todos, porque ele vem com documento.
// Um portao que falha ruidosamente e menos perigoso que um recibo de terca lido
// na sexta.
//
// TRES AMARRAS, e as tres precisam bater:
//
//   1. execucaoId — sorteado no inicio de CADA corrida. Nunca se repete. E o que
//      responde "este arquivo foi escrito por MIM?".
//   2. commit + arvoreSuja — respondem "sobre QUAL codigo?". Um recibo verde do
//      commit anterior nao diz nada sobre o commit atual.
//   3. terminadoEm — responde "QUANDO?". Recibo sem hora de termino e recibo de
//      execucao que nao acabou.
//
// E a amarra que fecha o circuito: o portao APAGA qualquer recibo anterior antes
// de comecar. Se, ao terminar, encontrar no lugar um recibo com outro
// `execucaoId`, houve duas corridas concorrentes sobre a mesma arvore — e
// nenhuma das duas pode assinar a RC, porque as duas se atrapalharam.

'use strict';

const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const crypto = require('node:crypto');
const { execFileSync } = require('node:child_process');

/// Onde os recibos moram. Dentro da arvore de proposito — um recibo que so
/// existisse no /tmp seria apagado pelo sistema justamente entre a execucao e a
/// auditoria. `.gitignore` cuida para que ele nao vire commit.
const PASTA = '.portao-rc';
const PONTEIRO = 'ultimo.json';

/// Idade a partir da qual um recibo deixa de descrever "agora". Nao e uma regra
/// de negocio sobre RC: e a defesa contra o recibo de terca lido na sexta. Doze
/// horas cobrem uma execucao completa (que leva dezenas de minutos) com folga de
/// turno, sem chegar perto de um dia de trabalho seguinte.
const VALIDADE_PADRAO_MS = 12 * 60 * 60 * 1000;

function pasta(raiz) {
  return path.join(raiz, PASTA);
}

/// Identidade da corrida. Sorteada UMA vez, no comeco, e carregada por todo o
/// resto da execucao.
///
/// `randomUUID` e nao timestamp+pid: dois processos que comecem no mesmo
/// milissegundo em maquinas diferentes de um mesmo runner colidiriam, e a
/// colisao apareceria como "recibo conflitante" num lugar onde nao houve
/// concorrencia — um portao que acusa problema inexistente e desligado tao
/// rapido quanto um que esconde problema real.
function abrirExecucao(raiz, opcoes = {}) {
  const { perfil = 'completo', argumentos = [] } = opcoes;
  return {
    execucaoId: crypto.randomUUID(),
    iniciadoEm: new Date().toISOString(),
    perfil,
    argumentos,
    maquina: { plataforma: process.platform, node: process.version, host: os.hostname() },
    git: lerGit(raiz),
  };
}

/// O commit sob teste, e se a arvore estava suja ANTES de o portao mexer nela.
///
/// A sujeira de PARTIDA e registrada separada da sujeira de CHEGADA (que o
/// cleanup mede) porque as duas tem culpados diferentes: comecar sujo e escolha
/// de quem rodou; terminar sujo e defeito do portao. Confundi-las faria o portao
/// se acusar de lixo que ele nao criou.
function lerGit(raiz) {
  const git = (args) => {
    try {
      return execFileSync('git', ['-C', raiz, ...args], {
        encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'],
      }).trim();
    } catch {
      return null;
    }
  };
  const sujeira = git(['status', '--porcelain']);
  return {
    commit: git(['rev-parse', 'HEAD']),
    branch: git(['rev-parse', '--abbrev-ref', 'HEAD']),
    arvoreSujaAoIniciar: sujeira === null ? null : sujeira.length > 0,
    sujeiraAoIniciar: sujeira ? sujeira.split('\n').filter(Boolean) : [],
  };
}

/// Apaga recibos anteriores. Chamado ANTES da execucao.
///
/// Nao e higiene: e a metade que torna a conferencia do fim significativa. Sem
/// isto, encontrar um recibo ao final nao provaria nada — ele poderia ser o de
/// ontem, e o portao nao teria como saber.
function limparAnteriores(raiz) {
  const dir = pasta(raiz);
  const removidos = [];
  if (!fs.existsSync(dir)) return removidos;
  for (const nome of fs.readdirSync(dir)) {
    if (!/^(recibo-.*\.json|ultimo\.json)$/.test(nome)) continue;
    try {
      fs.unlinkSync(path.join(dir, nome));
      removidos.push(nome);
    } catch { /* concorrente ja removeu: o estado desejado */ }
  }
  return removidos;
}

/// Ha um recibo de OUTRA corrida onde o desta deveria estar?
///
/// Consultado ANTES de decidir, e nao durante a gravacao. A ordem importa: o
/// veredito precisa conhecer o conflito para poder reprovar por ele, e o arquivo
/// gravado precisa conter o veredito FINAL. Decidindo depois de gravar, o recibo
/// no disco diria PASS enquanto a tela dizia FAIL — e o documento e justamente o
/// que sobrevive para ser lido depois.
function conflitoAnterior(raiz, execucaoId) {
  const anterior = lerPonteiro(raiz);
  return anterior && anterior.execucao && anterior.execucao.execucaoId !== execucaoId
    ? anterior.execucao.execucaoId
    : null;
}

/// Grava o recibo e o ponteiro `ultimo.json`.
function gravar(raiz, execucao, corpo) {
  const dir = pasta(raiz);
  fs.mkdirSync(dir, { recursive: true });

  const conflitante = conflitoAnterior(raiz, execucao.execucaoId);

  const recibo = {
    formato: 'portao-rc/1',
    execucao: { ...execucao, terminadoEm: new Date().toISOString() },
    ...corpo,
  };

  const alvo = path.join(dir, `recibo-${execucao.execucaoId}.json`);
  fs.writeFileSync(alvo, JSON.stringify(recibo, null, 2));
  fs.writeFileSync(path.join(dir, PONTEIRO), JSON.stringify(recibo, null, 2));

  return { caminho: alvo, ponteiro: path.join(dir, PONTEIRO), reciboConflitante: conflitante };
}

function lerPonteiro(raiz) {
  const p = path.join(pasta(raiz), PONTEIRO);
  try {
    return JSON.parse(fs.readFileSync(p, 'utf8'));
  } catch {
    return null;
  }
}

/// Confere se um recibo pode ser lido como "o resultado de agora".
///
/// FUNCAO PURA (recebe `agora` e o commit atual), para que o teste consiga fixar
/// "recibo de outro commit nao vale" sem viajar no tempo nem trocar de branch.
///
/// A ordem das recusas importa: `ausente` antes de `commit`, porque um recibo
/// que nao existe nao tem commit para comparar, e uma mensagem sobre commit
/// divergente mandaria procurar a branch errada.
function conferirValidade(recibo, contexto = {}) {
  const {
    commitAtual = null,
    agora = Date.now(),
    validadeMs = VALIDADE_PADRAO_MS,
  } = contexto;

  const recusas = [];

  if (!recibo || recibo.formato !== 'portao-rc/1') {
    return {
      valido: false,
      recusas: ['Nao ha recibo legivel em `.portao-rc/ultimo.json`.\n'
        + '  Ausencia de recibo NAO e aprovacao: e a prova de que o portao nao\n'
        + '  rodou nesta arvore, ou de que a execucao morreu antes de assinar.'],
    };
  }

  const ex = recibo.execucao || {};

  if (!ex.terminadoEm) {
    recusas.push('O recibo nao tem `terminadoEm`: a execucao que o abriu nunca chegou\n'
      + '  ao fim. Um recibo sem hora de termino descreve uma corrida interrompida.');
  }

  if (commitAtual && ex.git && ex.git.commit && ex.git.commit !== commitAtual) {
    recusas.push('O recibo e de OUTRO COMMIT:\n'
      + `    recibo  ${ex.git.commit}\n`
      + `    arvore  ${commitAtual}\n`
      + '  Um verde do commit anterior nao diz nada sobre este. E o caso mais\n'
      + '  comum do recibo antigo: o portao rodou, alguem commitou por cima, e o\n'
      + '  arquivo continuou la dizendo PASS.');
  }

  if (ex.terminadoEm) {
    const idade = agora - Date.parse(ex.terminadoEm);
    if (Number.isFinite(idade) && idade > validadeMs) {
      const horas = Math.round(idade / 3_600_000);
      recusas.push(`O recibo tem ${horas}h (limite ${Math.round(validadeMs / 3_600_000)}h).\n`
        + '  A arvore, as dependencias e a maquina mudaram desde entao; o que ele\n'
        + '  descreve nao e mais o estado atual.');
    }
  }

  if (ex.perfil && ex.perfil !== 'completo') {
    recusas.push(`O recibo e de uma execucao PARCIAL (perfil \`${ex.perfil}\`).\n`
      + '  Execucao restrita serve para depurar, e nao para assinar RC.');
  }

  return { valido: recusas.length === 0, recusas, recibo };
}

module.exports = {
  PASTA, PONTEIRO, VALIDADE_PADRAO_MS,
  abrirExecucao, limparAnteriores, gravar, lerPonteiro, conferirValidade, lerGit, pasta,
  conflitoAnterior,
};
