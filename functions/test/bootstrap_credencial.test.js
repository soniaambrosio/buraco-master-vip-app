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
    const r = validarDestino('/repo/functions/../app/cred.env', raiz, false);
    assert.equal(r.ok, false);
    const fora = validarDestino('/repo/../fora/cred.env', raiz, false);
    assert.equal(fora.ok, true);
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
