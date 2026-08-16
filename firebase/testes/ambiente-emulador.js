// ambiente-emulador.js — garante que UMA execucao por vez use os emuladores.
//
// O PROBLEMA CONCRETO:
//
// Os tres alvos (`social`, `moderacao`, `colecoes`) sobem o MESMO Emulator
// Suite, nas MESMAS portas, com o MESMO projectId `demo-bmv`. Eles nao sao
// alternativas independentes: sao usuarios do mesmo recurso exclusivo. Duas
// execucoes sobrepostas disputam a porta, e o perdedor nao morre limpo — ele
// sobe pela metade. Foi o que se viu nesta arvore: um `assertFails` passando
// (falhou por porta, e nao por regra — e "falhou" e o que ele pede), dezenas de
// casos sociais cancelados, e a mesma arvore verde quando repetida sozinha.
//
// Um `assertFails` que passa pelo motivo errado e pior que um teste vermelho:
// ele nao chama ninguem para conferir.
//
// DUAS FRENTES, porque uma so nao fecha:
//
//   TRAVA — pega as execucoes que este runner conhece, ANTES de qualquer
//   processo subir, e da mensagem util ("o alvo X, pid N, comecou as HH:MM").
//   Nao enxerga quem ocupa a porta sem passar por aqui.
//
//   PORTA — pega qualquer ocupante, inclusive um `firebase emulators:start`
//   solto, um Jenkins ou um emulador orfao de uma execucao morta a Ctrl+C.
//   Nao sabe dizer de quem e.
//
// Sozinha, a trava deixa passar o orfao; sozinha, a porta da uma mensagem que
// nao ajuda ninguem. Juntas, cobrem o caso real.

'use strict';

const fs = require('node:fs');
const net = require('node:net');
const os = require('node:os');
const path = require('node:path');
const { execFileSync } = require('node:child_process');

const ESPERA_ENTRE_TENTATIVAS_MS = 1000;

/// Uma porta esta ocupada se NAO der para escutar nela.
///
/// O teste e de BIND, e nao de connect nem de leitura do `netstat`, e a
/// diferenca importa nesta maquina. `emulators:exec` deixa para tras uma penca
/// de sockets de CLIENTE em TIME_WAIT na 8080 e na 4400 — foram 20 no momento
/// em que esta OS comecou. Nenhum deles impede o emulador de subir, mas todos
/// aparecem num `netstat | grep :8080`. Um portao que lesse o netstat acusaria
/// ambiente ocupado num ambiente livre, e a primeira reacao de quem fosse
/// bloqueado seria desligar o portao.
///
/// `bind` responde a pergunta certa, que e "o emulador consegue subir aqui?".
/// SO_REUSEADDR — que o node liga por padrao — deixa passar justamente o
/// TIME_WAIT, e continua barrando quem esta REALMENTE escutando.
function portaOcupada(porta, host = '127.0.0.1') {
  return new Promise((resolve) => {
    const servidor = net.createServer();
    servidor.once('error', (erro) => {
      servidor.close();
      // EADDRINUSE e EACCES sao "nao da para usar". Qualquer outro erro tambem
      // impede o emulador de subir, entao tratar como ocupado e o lado seguro.
      resolve({ ocupada: true, codigo: erro.code || 'ERRO' });
    });
    servidor.once('listening', () => {
      servidor.close(() => resolve({ ocupada: false, codigo: null }));
    });
    servidor.listen(porta, host);
  });
}

async function portasOcupadas(portas, host = '127.0.0.1') {
  const ocupadas = [];
  for (const { porta, nome } of portas) {
    const r = await portaOcupada(porta, host);
    if (r.ocupada) ocupadas.push({ porta, nome, codigo: r.codigo });
  }
  return ocupadas;
}

const dorme = (ms) => new Promise((r) => setTimeout(r, ms));

/// Espera LIMITADA. `timeoutMs = 0` e a politica fail-fast.
///
/// O limite nao e opcional: um loop infinito aqui trocaria um falso verde por um
/// portao que trava para sempre, que e o mesmo problema com outro nome — nos dois
/// casos ninguem recebe resposta.
async function esperarPortasLivres(portas, opcoes = {}) {
  const { timeoutMs = 0, aoTentar = () => {}, agora = () => Date.now() } = opcoes;
  const limite = agora() + timeoutMs;
  let tentativa = 0;

  for (;;) {
    const ocupadas = await portasOcupadas(portas);
    if (ocupadas.length === 0) return { livre: true, ocupadas: [], tentativas: tentativa };

    tentativa += 1;
    if (agora() >= limite) return { livre: false, ocupadas, tentativas: tentativa };

    aoTentar(ocupadas, Math.max(0, limite - agora()));
    await dorme(ESPERA_ENTRE_TENTATIVAS_MS);
  }
}

/// O processo `pid` ainda existe?
///
/// `kill(pid, 0)` nao envia sinal nenhum: so pergunta. `ESRCH` e "nao existe";
/// `EPERM` e "existe, mas e de outro usuario" — que, para o que importa aqui,
/// conta como vivo.
function processoVivo(pid) {
  if (!Number.isInteger(pid) || pid <= 0) return false;
  try {
    process.kill(pid, 0);
    return true;
  } catch (erro) {
    return erro.code === 'EPERM';
  }
}

function caminhoDaTrava(chave = 'demo-bmv') {
  return path.join(os.tmpdir(), `bmv-emulador-${chave}.lock`);
}

/// Tenta pegar a trava. Nao espera: quem espera e `esperarTrava`.
///
/// `wx` porque o `open` com `wx` e atomico no sistema de arquivos — duas
/// execucoes que cheguem no mesmo instante nao podem ganhar as duas. Um
/// `existsSync` seguido de `writeFileSync` teria a janela de corrida exatamente
/// no ponto que esta funcao existe para fechar.
///
/// A trava guarda PID. Uma execucao morta a Ctrl+C que nao chegue ao `finally`
/// deixa arquivo para tras, e uma trava sem dono vivo nao pode bloquear o
/// projeto para sempre: se o PID nao responde, a trava e obsoleta e vai embora.
function adquirirTrava(caminho, dados = {}) {
  const conteudo = JSON.stringify({ pid: process.pid, ...dados }, null, 2);

  for (let volta = 0; volta < 3; volta += 1) {
    try {
      const fd = fs.openSync(caminho, 'wx');
      fs.writeSync(fd, conteudo);
      fs.closeSync(fd);
      return { ok: true, caminho, liberar: () => liberarTrava(caminho) };
    } catch (erro) {
      if (erro.code !== 'EEXIST') throw erro;

      let dono = null;
      try {
        dono = JSON.parse(fs.readFileSync(caminho, 'utf8'));
      } catch {
        dono = null; // arquivo truncado/corrompido: trata como obsoleto
      }

      if (dono && processoVivo(dono.pid)) {
        return { ok: false, caminho, dono };
      }

      // Sem dono vivo: obsoleta. Remove e tenta de novo.
      try {
        fs.unlinkSync(caminho);
      } catch (e) {
        if (e.code !== 'ENOENT') throw e;
      }
    }
  }
  return { ok: false, caminho, dono: null, motivo: 'disputa' };
}

function liberarTrava(caminho) {
  // So remove a trava se ela ainda for NOSSA. Sem esta conferencia, uma execucao
  // que perdeu a corrida (ou cujo `finally` correu tarde) apagaria a trava do
  // vizinho e liberaria o ambiente para um terceiro no meio da suite alheia.
  try {
    const dono = JSON.parse(fs.readFileSync(caminho, 'utf8'));
    if (dono.pid !== process.pid) return false;
  } catch (erro) {
    if (erro.code === 'ENOENT') return false;
    // Ilegivel: e lixo, pode ir.
  }
  try {
    fs.unlinkSync(caminho);
    return true;
  } catch (erro) {
    if (erro.code === 'ENOENT') return false;
    throw erro;
  }
}

async function esperarTrava(caminho, dados, opcoes = {}) {
  const { timeoutMs = 0, aoTentar = () => {}, agora = () => Date.now() } = opcoes;
  const limite = agora() + timeoutMs;

  for (;;) {
    const t = adquirirTrava(caminho, dados);
    if (t.ok) return t;
    if (agora() >= limite) return t;
    aoTentar(t.dono, Math.max(0, limite - agora()));
    await dorme(ESPERA_ENTRE_TENTATIVAS_MS);
  }
}

/// Mata o processo E os netos.
///
/// No Windows, matar o `firebase` nao mata a JVM do Firestore que ele abriu: ela
/// vira orfa segurando a 8080, e a proxima execucao encontra "ambiente ocupado"
/// sem ninguem para culpar. `taskkill /T` desce a arvore inteira. No POSIX o
/// equivalente e o grupo de processos.
function matarArvore(pid) {
  if (!pid) return;
  try {
    if (process.platform === 'win32') {
      execFileSync('taskkill', ['/pid', String(pid), '/T', '/F'], { stdio: 'ignore' });
    } else {
      process.kill(-pid, 'SIGKILL');
    }
  } catch {
    // Ja morreu — que e o estado desejado.
  }
}

module.exports = {
  portaOcupada,
  portasOcupadas,
  esperarPortasLivres,
  processoVivo,
  caminhoDaTrava,
  adquirirTrava,
  liberarTrava,
  esperarTrava,
  matarArvore,
  ESPERA_ENTRE_TENTATIVAS_MS,
};
