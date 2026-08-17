// bootstrap_credencial.test.js — A MATRIZ DO BOOTSTRAP DA CREDENCIAL DO MOTOR.
//
// Cobre a §10 da OS inteira, caso a caso, SEM rede, SEM Admin SDK real e SEM
// projeto Firebase. O `main` do script recebe suas dependências por injeção
// exatamente para isto: o que se prova aqui é o caminho de produção, com dublês
// só nas bordas (SDK, HTTP, relógio) — nenhuma decisão foi reimplementada.
//
// O QUE MERECE ATENÇÃO NESTA SUÍTE, porque não é a asserção óbvia:
//
//   - os dublês CONTAM chamadas. "O ensaio não emite token" não é provado
//     lendo a saída; é provado afirmando que `createCustomToken` foi chamado
//     zero vez. Uma versão futura que imprimisse "ENSAIO" e emitisse assim
//     mesmo passaria no teste de saída e falha neste;
//
//   - os tokens de mentira desta suíte são reconhecíveis por um prefixo próprio
//     (`SEGREDO-DE-TESTE-`). É o que permite varrer stdout e stderr atrás de
//     vazamento sem depender de o token ter alguma forma especial.

'use strict';

const { test, describe } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

const bootstrap = require('../scripts/bootstrap_credencial_motor.js');
const {
  CLAIM,
  analisarArgumentos,
  sondarDestino,
  validarDestino,
  avaliarClaim,
  decodificarPayload,
  conferirIdentidade,
  conferirRespostaDaTroca,
  materialDeBootstrap,
  gravarMaterial,
  main,
} = bootstrap;

// ---------------------------------------------------------------------------
// ARNÊS
// ---------------------------------------------------------------------------

const PROJETO = 'bmv-bootstrap-teste';
const UID = 'uid-motor-de-partidas-tecnico';

/// Prefixo dos segredos falsos. Toda varredura de vazamento procura por ele.
const MARCA = 'SEGREDO-DE-TESTE-';
const CUSTOM_TOKEN = MARCA + 'custom-token';
const REFRESH_TOKEN = MARCA + 'refresh-token';

function b64url(valor) {
  return Buffer.from(valor).toString('base64')
    .replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

/// Monta um ID token com o formato de um do Firebase. NÃO é assinado: nada nesta
/// suíte verifica assinatura — quem verifica é o Admin SDK, que aqui é dublê.
/// O que o script faz com este valor é DECODIFICAR, e é isso que se exercita.
function idTokenFalso(payload = {}) {
  const corpo = Object.assign(
    {
      sub: UID,
      aud: PROJETO,
      iss: 'https://securetoken.google.com/' + PROJETO,
      exp: Math.floor(Date.now() / 1000) + 3600,
      [CLAIM]: true,
    },
    payload
  );
  return [b64url(JSON.stringify({ alg: 'RS256', typ: 'JWT' })), b64url(JSON.stringify(corpo)), MARCA + 'assinatura'].join('.');
}

/// Admin SDK de mentira, que CONTA o que foi pedido a ele.
function adminFalso({
  claims = { [CLAIM]: true },
  usuarioExiste = true,
  projetoResolvido = PROJETO,
  erroAoEmitir = null,
  erroAoVerificar = null,
} = {}) {
  const chamadas = { getUser: 0, createCustomToken: 0, verifyIdToken: 0, argsVerify: [] };
  return {
    chamadas,
    apps: [{}],
    initializeApp() { throw new Error('nao deveria reinicializar'); },
    app: () => ({ options: { projectId: projetoResolvido } }),
    auth: () => ({
      async getUser(uid) {
        chamadas.getUser++;
        if (!usuarioExiste) {
          const e = new Error('nao encontrado');
          e.code = 'auth/user-not-found';
          throw e;
        }
        return { uid, customClaims: claims };
      },
      async createCustomToken() {
        chamadas.createCustomToken++;
        if (erroAoEmitir) throw erroAoEmitir;
        return CUSTOM_TOKEN;
      },
      async verifyIdToken(token, checkRevoked) {
        chamadas.verifyIdToken++;
        chamadas.argsVerify.push([token, checkRevoked]);
        if (erroAoVerificar) throw erroAoVerificar;
        return { uid: UID };
      },
    }),
  };
}

/// Executa `main` com todas as bordas dubladas, capturando a saída.
async function rodar(argv, opcoes = {}) {
  const saidaLog = [];
  const saidaErro = [];
  const admin = opcoes.admin || adminFalso(opcoes.adminOpts);
  const trocasFeitas = [];
  const trocar = opcoes.trocar || (async (p) => {
    trocasFeitas.push(p);
    return opcoes.resposta || { idToken: idTokenFalso(), refreshToken: REFRESH_TOKEN, expiresIn: '3600' };
  });
  const codigo = await main(argv, {
    admin,
    trocar,
    fs: opcoes.fs || fs,
    log: (m) => saidaLog.push(String(m)),
    erro: (m) => saidaErro.push(String(m)),
    env: opcoes.env || { FIREBASE_WEB_API_KEY: MARCA + 'api-key' },
    raizRepo: opcoes.raizRepo || path.resolve(__dirname, '..', '..'),
    plataforma: opcoes.plataforma || process.platform,
    agora: () => new Date('2026-08-17T12:00:00.000Z'),
  });
  return {
    codigo,
    admin,
    trocasFeitas,
    log: saidaLog.join('\n'),
    erro: saidaErro.join('\n'),
    tudo: saidaLog.concat(saidaErro).join('\n'),
  };
}

/// Diretório de trabalho FORA do repositório, para os casos que tocam disco.
function pastaTemporaria() {
  return fs.mkdtempSync(path.join(os.tmpdir(), 'bmv-bootstrap-'));
}

/// Uma sonda de disco válida, para exercitar a DECISÃO sem tocar disco.
///
/// O padrão é o caso feliz: destino inexistente, pai existente, gravável e
/// privado (0700). Cada caso quebra só o campo que está medindo — assim a falha
/// aponta para uma barreira, e não para o arnês.
function sondaBoa(extra = {}) {
  return Object.assign(
    {
      existe: false,
      pai: { caminho: '/fora', existe: true, ehDiretorio: true, gravavel: true, modo: 0o700 },
    },
    extra
  );
}

function argsPadrao(saida, extras = []) {
  return ['--project', PROJETO, '--uid', UID, '--saida', saida].concat(extras);
}

function argsCommit(saida) {
  return argsPadrao(saida, ['--commit', '--confirmar-projeto', PROJETO]);
}

// ---------------------------------------------------------------------------
// ENSAIO — o padrão, e o que ele garante
// ---------------------------------------------------------------------------

describe('BOOT/ENSAIO', () => {
  test('BOOT-01: o ensaio NÃO emite token nenhum', async () => {
    const dir = pastaTemporaria();
    const r = await rodar(argsPadrao(path.join(dir, 'cred.env')));

    assert.equal(r.codigo, 0, 'o ensaio de um caso válido deve terminar bem');
    // A prova não é a mensagem "ENSAIO" — é o contador.
    assert.equal(r.admin.chamadas.createCustomToken, 0, 'nenhum custom token pode ser emitido em ensaio');
    assert.equal(r.trocasFeitas.length, 0, 'nenhuma troca REST pode acontecer em ensaio');
    assert.match(r.log, /ENSAIO/);
  });

  test('BOOT-02: o ensaio NÃO cria arquivo', async () => {
    const dir = pastaTemporaria();
    const alvo = path.join(dir, 'cred.env');
    const chamadas = [];
    const fsEspiao = Object.assign(Object.create(fs), {
      existsSync: (p) => fs.existsSync(p),
      openSync: (...a) => { chamadas.push(['openSync', ...a]); throw new Error('nao deveria abrir'); },
      writeFileSync: (...a) => { chamadas.push(['writeFileSync', ...a]); },
    });

    const r = await rodar(argsPadrao(alvo), { fs: fsEspiao });

    assert.equal(r.codigo, 0);
    assert.deepEqual(chamadas, [], 'o ensaio não pode tocar o disco');
    assert.equal(fs.existsSync(alvo), false, 'o destino não pode existir depois de um ensaio');
  });

  test('BOOT-01b: o ensaio nem exige a Web API Key', async () => {
    // Deliberado: sem `--commit` não há troca, e exigir a chave para ensaiar
    // empurraria o operador a exportá-la antes de saber se o plano está certo.
    const dir = pastaTemporaria();
    const r = await rodar(argsPadrao(path.join(dir, 'cred.env')), { env: {} });
    assert.equal(r.codigo, 0);
  });

  test('BOOT-01c: com --commit, a Web API Key ausente para ANTES de emitir', async () => {
    const dir = pastaTemporaria();
    const r = await rodar(argsCommit(path.join(dir, 'cred.env')), { env: {} });
    assert.equal(r.codigo, 1);
    assert.equal(r.admin.chamadas.createCustomToken, 0);
    assert.match(r.erro, /FIREBASE_WEB_API_KEY/);
  });
});

// ---------------------------------------------------------------------------
// ARGUMENTOS
// ---------------------------------------------------------------------------

describe('BOOT/ARGUMENTOS', () => {
  test('BOOT-03: projeto ausente', () => {
    const r = analisarArgumentos(['--uid', UID, '--saida', '/fora/cred.env']);
    assert.match(r.erro, /--project é obrigatório/);
  });

  test('BOOT-04: UID ausente', () => {
    const r = analisarArgumentos(['--project', PROJETO, '--saida', '/fora/cred.env']);
    assert.match(r.erro, /--uid é obrigatório/);
  });

  test('BOOT-05: projeto com forma inválida', () => {
    for (const ruim of ['Projeto', 'com espaço', 'a', '../outro', 'proj/eto', '']) {
      const r = analisarArgumentos(['--project', ruim, '--uid', UID, '--saida', '/fora/c.env']);
      assert.ok(r.erro, 'deveria recusar --project=' + JSON.stringify(ruim));
    }
  });

  test('BOOT-06: --commit com confirmação divergente (e ausente)', () => {
    const base = ['--project', PROJETO, '--uid', UID, '--saida', '/fora/c.env', '--commit'];
    const divergente = analisarArgumentos(base.concat(['--confirmar-projeto', 'outro-projeto']));
    assert.match(divergente.erro, /--confirmar-projeto/);
    const ausente = analisarArgumentos(base);
    assert.match(ausente.erro, /\(ausente\)/);
    const certo = analisarArgumentos(base.concat(['--confirmar-projeto', PROJETO]));
    assert.equal(certo.erro, undefined);
    assert.equal(certo.commit, true);
  });

  test('BOOT-06b: --saida é exigida mesmo em ensaio', () => {
    const r = analisarArgumentos(['--project', PROJETO, '--uid', UID]);
    assert.match(r.erro, /--saida é obrigatório/);
  });
});

// ---------------------------------------------------------------------------
// IDENTIDADE E CLAIM
// ---------------------------------------------------------------------------

describe('BOOT/IDENTIDADE', () => {
  test('BOOT-07: usuário inexistente para tudo, sem emitir', async () => {
    const dir = pastaTemporaria();
    const r = await rodar(argsCommit(path.join(dir, 'c.env')), {
      adminOpts: { usuarioExiste: false },
    });
    assert.equal(r.codigo, 1);
    assert.equal(r.admin.chamadas.createCustomToken, 0);
    assert.match(r.erro, /NÃO cria identidade/);
  });

  test('BOOT-08: claim ausente não autoriza', async () => {
    const dir = pastaTemporaria();
    const r = await rodar(argsCommit(path.join(dir, 'c.env')), { adminOpts: { claims: {} } });
    assert.equal(r.codigo, 1);
    assert.equal(r.admin.chamadas.createCustomToken, 0);
    assert.match(r.erro, /não tem o claim/);
  });

  test('BOOT-09/10/11: claim com tipo errado não autoriza', async () => {
    // `false`, a string `"true"` e o número `1` são exatamente o que um
    // provisionamento manual desleixado produz. Nenhum deles autoriza — e o
    // script recusa em vez de "corrigir", porque conceder é do provisionador.
    for (const errado of [false, 'true', 1, '1', 0, null]) {
      const dir = pastaTemporaria();
      const r = await rodar(argsCommit(path.join(dir, 'c.env')), {
        adminOpts: { claims: { [CLAIM]: errado } },
      });
      assert.equal(r.codigo, 1, 'deveria recusar ' + JSON.stringify(errado));
      assert.equal(r.admin.chamadas.createCustomToken, 0);
    }
  });

  test('BOOT-12: claim booleano true autoriza e o fluxo completa', async () => {
    const dir = pastaTemporaria();
    const alvo = path.join(dir, 'c.env');
    const r = await rodar(argsCommit(alvo), { adminOpts: { claims: { [CLAIM]: true } } });

    assert.equal(r.codigo, 0, r.erro);
    assert.equal(r.admin.chamadas.createCustomToken, 1);
    assert.equal(r.trocasFeitas.length, 1);
    assert.equal(fs.existsSync(alvo), true);
    const conteudo = fs.readFileSync(alvo, 'utf8');
    assert.match(conteudo, new RegExp('FIREBASE_MOTOR_REFRESH_TOKEN=' + REFRESH_TOKEN));
    assert.match(conteudo, new RegExp('FIREBASE_PROJECT_ID=' + PROJETO));
    assert.match(conteudo, new RegExp('FIREBASE_MOTOR_UID=' + UID));
  });

  test('BOOT-12b: o bootstrap também verifica com checkRevoked', async () => {
    // Não é só o receptor. Entregar ao Railway uma credencial cuja sessão já
    // está revogada produziria um servidor que nunca autentica, e o operador
    // procuraria o defeito no lugar errado.
    const dir = pastaTemporaria();
    const r = await rodar(argsCommit(path.join(dir, 'c.env')));
    assert.equal(r.codigo, 0, r.erro);
    assert.equal(r.admin.chamadas.verifyIdToken, 1);
    assert.equal(r.admin.chamadas.argsVerify[0][1], true, 'checkRevoked tem de ser true');
  });

  test('BOOT-12c: ID token recusado pelo SDK não vira arquivo', async () => {
    const dir = pastaTemporaria();
    const alvo = path.join(dir, 'c.env');
    const r = await rodar(argsCommit(alvo), {
      adminOpts: { erroAoVerificar: Object.assign(new Error('revogado'), { code: 'auth/id-token-revoked' }) },
    });
    assert.equal(r.codigo, 1);
    assert.equal(fs.existsSync(alvo), false);
  });

  test('BOOT-13: projeto resolvido pelo SDK divergente', async () => {
    const dir = pastaTemporaria();
    const r = await rodar(argsCommit(path.join(dir, 'c.env')), {
      adminOpts: { projetoResolvido: 'outro-projeto-qualquer' },
    });
    assert.equal(r.codigo, 1);
    assert.equal(r.admin.chamadas.getUser, 0, 'nem deveria ter lido o usuário');
    assert.equal(r.admin.chamadas.createCustomToken, 0);
    assert.match(r.erro, /o SDK resolveu o projeto/);
  });
});

// ---------------------------------------------------------------------------
// EMISSÃO E TROCA
// ---------------------------------------------------------------------------

describe('BOOT/TROCA', () => {
  test('BOOT-14: erro na emissão do custom token', async () => {
    const dir = pastaTemporaria();
    const alvo = path.join(dir, 'c.env');
    const r = await rodar(argsCommit(alvo), {
      adminOpts: { erroAoEmitir: Object.assign(new Error('sem permissão'), { code: 'auth/insufficient-permission' }) },
    });
    assert.equal(r.codigo, 1);
    assert.equal(r.trocasFeitas.length, 0);
    assert.equal(fs.existsSync(alvo), false);
  });

  test('BOOT-15: erro na troca REST', async () => {
    const dir = pastaTemporaria();
    const alvo = path.join(dir, 'c.env');
    const r = await rodar(argsCommit(alvo), {
      trocar: async () => { throw new Error('a troca falhou com HTTP 400'); },
    });
    assert.equal(r.codigo, 1);
    assert.match(r.erro, /HTTP 400/);
    assert.equal(fs.existsSync(alvo), false);
  });

  test('BOOT-16: resposta sem refresh token', async () => {
    const dir = pastaTemporaria();
    const alvo = path.join(dir, 'c.env');
    const r = await rodar(argsCommit(alvo), {
      resposta: { idToken: idTokenFalso(), expiresIn: '3600' },
    });
    assert.equal(r.codigo, 1);
    assert.match(r.erro, /não trouxe refreshToken/);
    assert.equal(fs.existsSync(alvo), false);
  });

  test('BOOT-16b: resposta sem idToken', async () => {
    const dir = pastaTemporaria();
    const r = await rodar(argsCommit(path.join(dir, 'c.env')), {
      resposta: { refreshToken: REFRESH_TOKEN },
    });
    assert.equal(r.codigo, 1);
    assert.match(r.erro, /não trouxe idToken/);
  });

  test('BOOT-17: UID retornado divergente', async () => {
    const dir = pastaTemporaria();
    const alvo = path.join(dir, 'c.env');
    const r = await rodar(argsCommit(alvo), {
      resposta: { idToken: idTokenFalso({ sub: 'uid-de-outra-pessoa' }), refreshToken: REFRESH_TOKEN },
    });
    assert.equal(r.codigo, 1);
    assert.match(r.erro, /pertence a OUTRO usuário/);
    assert.equal(fs.existsSync(alvo), false);
  });

  test('BOOT-18: projeto retornado divergente (aud e iss)', async () => {
    const dir = pastaTemporaria();
    for (const quebra of [{ aud: 'outro-projeto' }, { iss: 'https://securetoken.google.com/outro-projeto' }]) {
      const alvo = path.join(dir, 'c-' + Object.keys(quebra)[0] + '.env');
      const r = await rodar(argsCommit(alvo), {
        resposta: { idToken: idTokenFalso(quebra), refreshToken: REFRESH_TOKEN },
      });
      assert.equal(r.codigo, 1, 'deveria recusar ' + JSON.stringify(quebra));
      assert.equal(fs.existsSync(alvo), false);
    }
  });

  test('BOOT-18b: ID token devolvido sem o claim', async () => {
    // O caso real: o claim foi concedido DEPOIS de a sessão nascer. A conta tem
    // o claim (o passo anterior confirmou), mas o token não — e é o token que o
    // receptor vai ver.
    const dir = pastaTemporaria();
    const r = await rodar(argsCommit(path.join(dir, 'c.env')), {
      resposta: { idToken: idTokenFalso({ [CLAIM]: undefined }), refreshToken: REFRESH_TOKEN },
    });
    assert.equal(r.codigo, 1);
    assert.match(r.erro, new RegExp('NÃO carrega'));
  });
});

// ---------------------------------------------------------------------------
// DESTINO E ESCRITA
// ---------------------------------------------------------------------------

describe('BOOT/DESTINO', () => {
  test('BOOT-19: destino DENTRO do repositório é recusado', async () => {
    const raiz = path.resolve(__dirname, '..', '..');
    for (const dentro of ['functions/cred.env', 'cred.env', 'functions/scripts/sub/cred.env']) {
      const r = await rodar(argsCommit(path.join(raiz, dentro)), { raizRepo: raiz });
      assert.equal(r.codigo, 1, 'deveria recusar ' + dentro);
      assert.match(r.erro, /DENTRO do repositório/);
      assert.equal(r.admin.chamadas.createCustomToken, 0, 'não pode emitir antes de validar o destino');
    }
  });

  test('BOOT-19b: a recusa é por caminho resolvido, não por texto', () => {
    const raiz = path.resolve('/repo');
    // `..` que sai e volta continua dentro, e é a forma mais fácil de furar uma
    // checagem escrita com `startsWith` sobre a string crua.
    const r = validarDestino('/repo/functions/../app/cred.env', raiz, sondaBoa());
    assert.equal(r.ok, false);
    assert.match(r.erro, /DENTRO do repositório/);
    const fora = validarDestino('/repo/../fora/cred.env', raiz, sondaBoa());
    assert.equal(fora.ok, true);
  });

  test('BOOT-19c: a PRÓPRIA RAIZ do repositório é recusada, com motivo próprio', () => {
    // `path.relative(raiz, raiz)` é a string vazia. A V1 exigia `relativo !== ''`
    // para considerar "dentro", então a raiz escapava da primeira barreira e só
    // era barrada pela segunda (o destino já existe). Defesa em profundidade que
    // perde uma camada é defesa simples.
    const raiz = path.resolve('/repo');
    for (const forma of ['/repo', '/repo/', '/repo/functions/..']) {
      const r = validarDestino(forma, raiz, sondaBoa({ existe: true }));
      assert.equal(r.ok, false, forma);
      assert.match(r.erro, /PRÓPRIA RAIZ/, forma);
    }
    // E a recusa não depende de a raiz existir no disco: é a primeira barreira.
    const semExistir = validarDestino('/repo', raiz, sondaBoa({ existe: false }));
    assert.equal(semExistir.ok, false);
    assert.match(semExistir.erro, /PRÓPRIA RAIZ/);
  });

  test('BOOT-19d: a raiz do repositório é recusada pelo caminho completo, sem emitir', async () => {
    const raiz = path.resolve(__dirname, '..', '..');
    const r = await rodar(argsCommit(raiz), { raizRepo: raiz });
    assert.equal(r.codigo, 1);
    assert.match(r.erro, /PRÓPRIA RAIZ/);
    assert.equal(r.admin.chamadas.createCustomToken, 0, 'não pode emitir para recusar a raiz');
  });

  test('BOOT-25: diretório-pai INEXISTENTE recusa ANTES de emitir', async () => {
    // Medido na homologação: a V1 emitia o custom token, fazia a troca e só então
    // falhava no `openSync`. Um erro de digitação no caminho materializava uma
    // credencial de longa duração que ninguém guardou — e que ninguém sabe que
    // precisa revogar.
    const dir = pastaTemporaria();
    const alvo = path.join(dir, 'nao-existe', 'ainda-menos', 'c.env');

    const r = await rodar(argsCommit(alvo));

    assert.equal(r.codigo, 1, 'tem de recusar, e com o código de "nada foi emitido"');
    assert.match(r.erro, /diretório de destino não existe/);
    assert.match(r.erro, /Nada foi emitido/);
    assert.equal(r.admin.chamadas.createCustomToken, 0, 'NENHUM custom token pode ter sido emitido');
    assert.equal(r.trocasFeitas.length, 0, 'NENHUMA troca REST pode ter acontecido');
    assert.equal(fs.existsSync(path.dirname(alvo)), false, 'o script não pode criar o diretório');
    assert.deepEqual(fs.readdirSync(dir), [], 'nada pode ter sido criado');
  });

  test('BOOT-25b: pai que NÃO é diretório é recusado, sem emitir', async () => {
    const dir = pastaTemporaria();
    const arquivo = path.join(dir, 'sou-um-arquivo');
    fs.writeFileSync(arquivo, 'x');

    const r = await rodar(argsCommit(path.join(arquivo, 'c.env')));

    assert.equal(r.codigo, 1);
    assert.equal(r.admin.chamadas.createCustomToken, 0);
    // Alguns sistemas resolvem "arquivo/sub" como inexistente, outros como
    // ENOTDIR; as duas leituras recusam, e é isso que importa.
    assert.match(r.erro, /não existe|não é um diretório/);
  });

  test('BOOT-25c: pai não gravável é recusado (decisão pura)', () => {
    const r = validarDestino('/fora/c.env', path.resolve('/repo'),
      sondaBoa({ pai: { caminho: '/fora', existe: true, ehDiretorio: true, gravavel: false, modo: 0o700 } }));
    assert.equal(r.ok, false);
    assert.match(r.erro, /não é gravável/);
  });

  test('BOOT-25d: sonda ausente ou incompleta recusa — o preflight falha FECHADO', () => {
    // Um chamador futuro que esqueça de sondar o disco não pode obter "ok".
    const raiz = path.resolve('/repo');
    for (const sonda of [undefined, {}, { existe: false }, { pai: {} }]) {
      const r = validarDestino('/fora/c.env', raiz, sonda);
      assert.equal(r.ok, false, JSON.stringify(sonda));
      assert.match(r.erro, /não existe/);
    }
  });

  test('BOOT-26: POSIX — diretório gravável por outros é RECUSADO', () => {
    const raiz = path.resolve('/repo');
    for (const modo of [0o777, 0o770, 0o707, 0o1777]) {
      const r = validarDestino('/fora/c.env', raiz,
        sondaBoa({ pai: { caminho: '/fora', existe: true, ehDiretorio: true, gravavel: true, modo } }),
        'linux');
      assert.equal(r.ok, false, 'modo 0' + modo.toString(8));
      assert.match(r.erro, /gravável por grupo ou por outros/);
      // Inclusive com o bit sticky (0o1777, o modo do /tmp): sticky impede
      // apagar arquivo alheio, e não impede nada quanto ao que ainda não existe.
    }
  });

  test('BOOT-26b: POSIX — diretório apenas LEGÍVEL por outros AVISA, não recusa', () => {
    // 0755 é o modo do `~` de quase toda máquina POSIX. Recusar ali empurraria o
    // operador a improvisar. O que vaza é o NOME do arquivo: o conteúdo é 0600.
    const r = validarDestino('/fora/c.env', path.resolve('/repo'),
      sondaBoa({ pai: { caminho: '/fora', existe: true, ehDiretorio: true, gravavel: true, modo: 0o755 } }),
      'linux');
    assert.equal(r.ok, true);
    assert.equal(r.avisos.length, 1);
    assert.match(r.avisos[0], /legível por outros/);
    assert.match(r.avisos[0], /o que vaza é o NOME/i);

    const privado = validarDestino('/fora/c.env', path.resolve('/repo'),
      sondaBoa({ pai: { caminho: '/fora', existe: true, ehDiretorio: true, gravavel: true, modo: 0o700 } }),
      'linux');
    assert.equal(privado.ok, true);
    assert.deepEqual(privado.avisos, [], 'diretório privado não tem o que avisar');
  });

  test('BOOT-26c: Windows — a proteção é ACL, e 0700 NÃO é prometido', () => {
    const r = validarDestino('C:/fora/c.env', path.resolve('/repo'),
      sondaBoa({ pai: { caminho: 'C:/fora', existe: true, ehDiretorio: true, gravavel: true, modo: 0o666 } }),
      'win32');
    // O modo permissivo NÃO recusa no Windows: ele não quer dizer nada ali, e
    // recusar por um número inventado seria teatro.
    assert.equal(r.ok, true);
    assert.equal(r.avisos.length, 1);
    assert.match(r.avisos[0], /ACL/);
    // O único jeito de "0700" aparecer aqui é dentro da NEGAÇÃO. Prometer o modo
    // numa plataforma que o ignora é a mentira que a §6 proíbe.
    assert.match(r.avisos[0], /NÃO promete 0700/);
    assert.equal(/garante|assegura/.test(r.avisos[0]), false);
    assert.equal(r.avisos[0].split('0700').length - 1, 1, '0700 só pode aparecer na negação');
  });

  test('BOOT-26d: no Windows a saída não afirma que 0600 valeu', async () => {
    const dir = pastaTemporaria();
    const r = await rodar(argsCommit(path.join(dir, 'c.env')), { plataforma: 'win32' });
    assert.equal(r.codigo, 0, r.erro);
    assert.match(r.log, /modo pedido/, 'no Windows o modo é PEDIDO, não obtido');
    assert.match(r.log, /IGNORA O MODO POSIX/);
    assert.equal(/^modo *: 0600$/m.test(r.log), false, 'não pode afirmar o modo seco');
  });

  test('BOOT-27: sondarDestino lê o disco e não julga nada', () => {
    const dir = pastaTemporaria();
    const alvo = path.join(dir, 'c.env');

    const antes = sondarDestino({ saida: alvo });
    assert.equal(antes.alvo, path.resolve(alvo));
    assert.equal(antes.existe, false);
    assert.equal(antes.pai.existe, true);
    assert.equal(antes.pai.ehDiretorio, true);
    assert.equal(antes.pai.gravavel, true);

    fs.writeFileSync(alvo, 'x');
    assert.equal(sondarDestino({ saida: alvo }).existe, true);

    // Pai inexistente: sonda responde, não lança.
    const orfao = sondarDestino({ saida: path.join(dir, 'nao-existe', 'c.env') });
    assert.equal(orfao.pai.existe, false);
    assert.equal(orfao.pai.gravavel, false);

    // Um `fs` que explode em tudo também não derruba a sonda — e o resultado
    // leva a recusa, que é o lado seguro.
    const fsQueExplode = {
      existsSync() { throw new Error('sem permissão'); },
      statSync() { throw new Error('sem permissão'); },
      accessSync() { throw new Error('sem permissão'); },
    };
    const cego = sondarDestino({ saida: alvo, fs: fsQueExplode });
    assert.equal(cego.existe, false);
    assert.equal(cego.pai.existe, false);
    assert.equal(validarDestino(alvo, path.resolve('/repo'), cego).ok, false);
  });

  test('BOOT-28: TODA recusa de destino acontece antes de qualquer emissão', async () => {
    // A garantia que junta os casos acima: nenhum motivo de recusa de destino
    // pode ter custado um custom token. É o alvo direto da mutação "emitir a
    // credencial antes do preflight".
    const dir = pastaTemporaria();
    const arquivoExistente = path.join(dir, 'ja-existe.env');
    fs.writeFileSync(arquivoExistente, 'ANTERIOR\n');
    const raiz = path.resolve(__dirname, '..', '..');

    const recusas = [
      ['raiz do repositório', raiz],
      ['dentro do repositório', path.join(raiz, 'cred.env')],
      ['pai inexistente', path.join(dir, 'nao-existe', 'c.env')],
      ['destino já existe', arquivoExistente],
    ];
    for (const [nome, alvo] of recusas) {
      const r = await rodar(argsCommit(alvo), { raizRepo: raiz });
      assert.equal(r.codigo, 1, nome);
      assert.equal(r.admin.chamadas.createCustomToken, 0, nome + ': emitiu antes de validar');
      assert.equal(r.admin.chamadas.verifyIdToken, 0, nome);
      assert.equal(r.trocasFeitas.length, 0, nome + ': trocou antes de validar');
    }
    assert.equal(fs.readFileSync(arquivoExistente, 'utf8'), 'ANTERIOR\n');
  });

  test('BOOT-20: destino já existente é recusado, sem emitir', async () => {
    const dir = pastaTemporaria();
    const alvo = path.join(dir, 'ja-existe.env');
    fs.writeFileSync(alvo, 'CREDENCIAL ANTERIOR EM USO\n');

    const r = await rodar(argsCommit(alvo));

    assert.equal(r.codigo, 1);
    assert.match(r.erro, /já existe/);
    assert.equal(r.admin.chamadas.createCustomToken, 0);
    assert.equal(fs.readFileSync(alvo, 'utf8'), 'CREDENCIAL ANTERIOR EM USO\n', 'o arquivo anterior tem de ficar intacto');
  });

  test('BOOT-21: o arquivo é criado com permissão restrita', async () => {
    const dir = pastaTemporaria();
    const alvo = path.join(dir, 'c.env');
    const aberturas = [];
    const fsEspiao = Object.assign(Object.create(fs), {
      openSync: (p, flags, modo) => { aberturas.push({ p, flags, modo }); return fs.openSync(p, flags, modo); },
    });

    const r = await rodar(argsCommit(alvo), { fs: fsEspiao });
    assert.equal(r.codigo, 0, r.erro);

    // Prova 1 — INDEPENDENTE DE PLATAFORMA: o modo pedido é 0600 e a criação é
    // exclusiva (`wx`). É o que o código garante em qualquer sistema.
    assert.equal(aberturas.length, 1);
    assert.equal(aberturas[0].flags, 'wx', 'a criação tem de ser exclusiva');
    assert.equal(aberturas[0].modo, 0o600);

    // Prova 2 — só onde o sistema de arquivos sustenta modo POSIX. No Windows o
    // `fs` ignora o modo, e afirmar 0600 lá seria afirmar o que não é verdade.
    if (process.platform !== 'win32') {
      assert.equal(fs.statSync(alvo).mode & 0o777, 0o600);
    } else {
      assert.match(r.log, /IGNORA O MODO POSIX/, 'no Windows o script tem de AVISAR');
    }
  });

  test('BOOT-23: falha no meio da gravação não deixa arquivo parcial', async () => {
    const dir = pastaTemporaria();
    const alvo = path.join(dir, 'c.env');
    const fsQuebrado = Object.assign(Object.create(fs), {
      writeFileSync: () => { throw new Error('disco cheio no meio da escrita'); },
    });

    const r = await rodar(argsCommit(alvo), { fs: fsQuebrado });

    assert.equal(r.codigo, 2, 'falha DEPOIS de emitir sai com código próprio');
    assert.equal(fs.existsSync(alvo), false, 'o destino não pode existir');
    const restos = fs.readdirSync(dir);
    assert.deepEqual(restos, [], 'nenhum temporário pode sobreviver: ' + restos.join(', '));
    assert.match(r.erro, /revogue as sessões/, 'o operador precisa saber que a credencial FOI emitida');
  });

  test('BOOT-23b: gravarMaterial não sobrescreve por meio do temporário', () => {
    const dir = pastaTemporaria();
    const alvo = path.join(dir, 'c.env');
    gravarMaterial({ alvo, conteudo: 'PRIMEIRO\n' });
    assert.equal(fs.readFileSync(alvo, 'utf8'), 'PRIMEIRO\n');
    // `rename` sobrescreveria; quem impede a segunda gravação é `validarDestino`,
    // e é por isso que ela roda ANTES de qualquer emissão. Aqui só se fixa que a
    // função de escrita, sozinha, não é a barreira — para ninguém remover a
    // validação achando que a escrita protege.
    assert.equal(fs.readdirSync(dir).length, 1);
  });
});

// ---------------------------------------------------------------------------
// RUNBOOK — os procedimentos operacionais são parte da entrega
// ---------------------------------------------------------------------------
//
// A homologação independente reprovou com o runbook em 9 de 12: sem os itens 6,
// 9 e 11, o operador ativa a credencial e não tem como saber se funcionou, nem
// como confirmar que o corte de emergência de fato cortou.
//
// Um procedimento que só existe em Markdown pode ser apagado num commit de
// "limpeza" sem nada ficar vermelho. Estes casos são a barreira contra isso.
// Eles NÃO afirmam prosa: afirmam a presença dos elementos que tornam cada
// procedimento executável — pré-requisito, passo, critério de sucesso, reversão.
describe('BOOT/RUNBOOK', () => {
  const RUNBOOK = fs.readFileSync(
    path.resolve(__dirname, '..', '..', 'docs', 'CREDENCIAL-MOTOR-BOOTSTRAP-E-REVOGACAO-V1.md'),
    'utf8'
  );

  /// Recorta uma seção pelo título, até o próximo título de mesmo nível ou maior.
  function secao(titulo) {
    const i = RUNBOOK.indexOf(titulo);
    assert.notEqual(i, -1, 'seção ausente do runbook: ' + titulo);
    const resto = RUNBOOK.slice(i + titulo.length);
    const fim = resto.search(/\n#{1,3} /);
    return fim === -1 ? resto : resto.slice(0, fim);
  }

  test('BOOT-29: o SMOKE AUTENTICADO existe, e prova as cinco coisas exigidas', () => {
    const s = secao('### 7.1 Smoke autenticado');
    const exigencias = [
      [/obterIdToken/, 'como o token é obtido'],
      [/registrarEncerramentoPartida/, 'a chamada autorizada'],
      [/UID do motor/, 'a identidade esperada no documento gravado'],
      [/zero|\bZERO\b/i, 'o critério de "nenhum segredo no log"'],
      [/refresh token, ID token, API key/i, 'o que se varre no log'],
      [/smoke-<AAAAMMDD>/, 'a operação de teste identificável'],
      [/Revers[ãa]o/i, 'a reversão'],
      [/censo/i, 'a conferência de que a reversão de fato reverteu'],
      [/Pré-requisitos/i, 'os pré-requisitos'],
    ];
    for (const [padrao, oQue] of exigencias) {
      assert.match(s, padrao, 'o smoke perdeu ' + oQue);
    }
    // A reversão tem de listar as coleções, e não só dizer "apague".
    for (const colecao of ['matches', 'rankingLedger', 'fraudSignals', 'matchHistory']) {
      assert.ok(s.includes(colecao), 'a reversão do smoke não menciona ' + colecao);
    }
  });

  test('BOOT-30: o corte com TOKEN CACHEADO existe, com os sete passos', () => {
    const s = secao('### 8.2 Verificar que o token CACHEADO passa a ser recusado');
    const exigencias = [
      [/instante, NUNCA o token/i, 'registrar o instante sem registrar o token'],
      [/revokeRefreshTokens/, 'a revogação das sessões'],
      [/revoke --commit/, 'a remoção da claim'],
      [/sem forçar renovação/i, 'a chamada com o token AINDA cacheado'],
      [/recusa/i, 'a exigência de recusa'],
      [/renovacoes/, 'a prova de que foi o token velho que passou'],
      [/Forçar renovação/i, 'a renovação forçada'],
      [/não.{0,3} carrega .motorDePartidas|também não tem autoridade/i,
        'a exigência de que a emissão nova também não tenha autoridade'],
      [/Restauração/i, 'como voltar'],
    ];
    for (const [padrao, oQue] of exigencias) {
      assert.match(s, padrao, 'o procedimento do cache perdeu ' + oQue);
    }
  });

  test('BOOT-31: ROTAÇÃO e RESPOSTA A VAZAMENTO existem, e são executáveis', () => {
    const s = secao('### 8.3 Rotação periódica e resposta a vazamento');
    const exigencias = [
      [/Periodicidade/i, 'a periodicidade'],
      [/90 dias/, 'o número da periodicidade'],
      [/Responsável/i, 'o responsável'],
      [/bootstrap_credencial_motor\.js/, 'a geração da credencial nova'],
      [/SUBSTITUIR/, 'a substituição no Railway'],
      [/VALIDAR/, 'a validação'],
      [/REVOGAR A ANTERIOR/, 'a revogação da anterior'],
      [/T\+0\s+CORTAR/, 'a resposta emergencial'],
      [/INSPECIONAR/, 'a inspeção de logs'],
      [/Cloud Logging/, 'onde inspecionar'],
      [/Rollback/i, 'o rollback'],
    ];
    for (const [padrao, oQue] of exigencias) {
      assert.match(s, padrao, 'a rotação/vazamento perdeu ' + oQue);
    }
    // O placeholder é obrigatório, e o valor real é proibido.
    assert.ok(s.includes('<PROJETO>') && s.includes('<UID_DO_MOTOR>'), 'sumiram os placeholders');
  });

  test('BOOT-32: a prontidão operacional marca 12 de 12, sem item ausente', () => {
    const s = secao('## 11. Prontidão operacional');
    const linhas = s.split('\n').filter((l) => /^\| \d+ \|/.test(l));
    assert.equal(linhas.length, 12, 'a tabela de prontidão tem de ter os doze itens');
    for (const l of linhas) {
      assert.match(l, /✅/, 'item não fechado: ' + l);
      assert.equal(/❌|ausente/i.test(l), false, 'item ainda ausente: ' + l);
    }
    // E a limitação do emulador continua registrada como limitação — não pode
    // virar "teste verde" nem sumir.
    const lim = secao('## 10. Limitação do emulador');
    assert.match(lim, /alg.{0,4}: ?.?none/i, 'sumiu o fato de o emulador não assinar');
    assert.match(lim, /smoke com token real da §7\.1 é\s*\*\*obrigatório\*\*|obrigatório/i);
  });

  test('BOOT-33: o runbook não carrega valor real de segredo', () => {
    for (const p of [/AIza[0-9A-Za-z_-]{10,}/, /eyJ[A-Za-z0-9_-]{20,}\./, /BEGIN [A-Z ]*PRIVATE KEY/]) {
      assert.equal(p.test(RUNBOOK), false, 'o runbook casa com ' + p);
    }
  });
});

// ---------------------------------------------------------------------------
// SEGREDO — o que NUNCA pode sair
// ---------------------------------------------------------------------------

describe('BOOT/SEGREDO', () => {
  test('BOOT-22: nenhum token aparece em stdout ou stderr', async () => {
    const dir = pastaTemporaria();
    const r = await rodar(argsCommit(path.join(dir, 'c.env')));
    assert.equal(r.codigo, 0, r.erro);

    // Nenhum dos três segredos que passaram pelo processo pode estar na saída.
    for (const segredo of [CUSTOM_TOKEN, REFRESH_TOKEN, MARCA + 'api-key']) {
      assert.equal(r.tudo.includes(segredo), false, 'vazou na saída: ' + segredo);
    }
    // Nem um pedaço. Um prefixo de refresh token já identifica o projeto.
    assert.equal(r.tudo.includes(MARCA), false, 'nenhum fragmento de segredo pode sair');
    // O UID sai mascarado, nunca inteiro.
    assert.equal(r.tudo.includes(UID), false, 'o UID inteiro não pode sair');
    assert.match(r.tudo, /uid-…co/);
  });

  test('BOOT-22b: nem no caminho de erro depois da troca', async () => {
    const dir = pastaTemporaria();
    const r = await rodar(argsCommit(path.join(dir, 'c.env')), {
      resposta: { idToken: idTokenFalso({ sub: 'outro' }), refreshToken: REFRESH_TOKEN },
    });
    assert.equal(r.codigo, 1);
    assert.equal(r.tudo.includes(MARCA), false, 'a mensagem de erro não pode carregar segredo');
  });

  test('BOOT-22c: o comprimento é o único fato publicado sobre um segredo', () => {
    const d = bootstrap.descreverSegredo('abcdefghij');
    assert.equal(d, '(10 caracteres, não impresso)');
    assert.equal(d.includes('abc'), false);
    assert.equal(bootstrap.descreverSegredo(''), '(ausente)');
    assert.equal(bootstrap.descreverSegredo(undefined), '(ausente)');
  });

  test('BOOT-24: a fonte não carrega valor real nenhum', () => {
    const fonte = fs.readFileSync(path.resolve(__dirname, '../scripts/bootstrap_credencial_motor.js'), 'utf8');
    const proibidos = [
      /BEGIN [A-Z ]*PRIVATE KEY/,
      /private_key/,
      /AIza[0-9A-Za-z_-]{10,}/,   // formato de Web API Key do Google
      /client_secret/,
      /"refresh_token"\s*:\s*"[^"]+"/,
      /[0-9]{6,}-[0-9a-z]{20,}\.apps\.googleusercontent\.com/,
      /eyJ[A-Za-z0-9_-]{20,}\./, // um JWT literal embutido
    ];
    for (const p of proibidos) {
      assert.equal(p.test(fonte), false, 'a fonte casa com ' + p);
    }
    // E a chave de API não pode ser lida de argumento: só do ambiente.
    assert.equal(/--api-key|--web-api-key/.test(fonte), false, 'a chave não pode vir por argumento');
    assert.match(fonte, /env\.FIREBASE_WEB_API_KEY/);
  });

  test('BOOT-24b: o material gravado não carrega ID token nem custom token', () => {
    const material = materialDeBootstrap({
      projectId: PROJETO, uid: UID, refreshToken: REFRESH_TOKEN, carimbo: '2026-08-17T12:00:00.000Z',
    });
    assert.match(material, /FIREBASE_MOTOR_REFRESH_TOKEN=/);
    assert.equal(/FIREBASE_MOTOR_ID_TOKEN|CUSTOM_TOKEN|FIREBASE_WEB_API_KEY=/.test(material), false);
    // O aviso de que revogar a sessão é o que corta acesso não é decoração: sem
    // ele o operador troca o arquivo e acha que cortou.
    assert.match(material, /revokeRefreshTokens/);
  });

  test('BOOT-24c: a grafia do claim é a MESMA nos três lados', () => {
    const provisionador = require('../scripts/provisionar_claim_motor_partidas.js');
    const guarda = require('../lib/autoridade.js');
    assert.equal(CLAIM, provisionador.CLAIM);
    assert.equal(CLAIM, guarda.CLAIM_MOTOR_DE_PARTIDAS);
  });
});

// ---------------------------------------------------------------------------
// DECISÕES PURAS
// ---------------------------------------------------------------------------

describe('BOOT/PURO', () => {
  test('avaliarClaim aceita só o booleano true', () => {
    assert.equal(avaliarClaim({ [CLAIM]: true }).ok, true);
    for (const errado of [undefined, false, 'true', 1, '1', 0, null, {}]) {
      assert.equal(avaliarClaim({ [CLAIM]: errado }).ok, false, JSON.stringify(errado));
    }
    assert.equal(avaliarClaim(null).ok, false);
    assert.equal(avaliarClaim(undefined).ok, false);
  });

  test('decodificarPayload devolve null para o que não é JWT', () => {
    for (const ruim of ['', 'a.b', 'a.b.c.d', null, 42, 'a.@@@.c']) {
      assert.equal(decodificarPayload(ruim), null, JSON.stringify(ruim));
    }
    assert.deepEqual(decodificarPayload(idTokenFalso({ sub: 'x' })).sub, 'x');
  });

  test('conferirIdentidade recusa payload ilegível', () => {
    const r = conferirIdentidade(null, { uid: UID, projectId: PROJETO });
    assert.equal(r.ok, false);
  });

  test('conferirRespostaDaTroca recusa o que não é objeto', () => {
    for (const ruim of [null, undefined, 'texto', 42]) {
      assert.equal(conferirRespostaDaTroca(ruim).ok, false);
    }
  });
});
