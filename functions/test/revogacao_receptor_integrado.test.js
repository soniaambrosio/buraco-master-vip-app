// revogacao_receptor_integrado.test.js — A GUARDA REAL CONTRA O SDK REAL.
//
// O QUE ESTA SUÍTE PROVA, e é bom ser exato:
//
//   Que `conferirAutoridadeDePartida` + `verificadorComRevogacao(admin.auth())`
//   FUNCIONAM juntos contra o Admin SDK de verdade — que os claims saem onde a
//   guarda os procura, que o `uid` verificado é o que se compara, que um token
//   de outra identidade é recusado, e que a cadeia inteira (conceder → renovar →
//   autorizar → revogar sessão → recusar) fecha.
//
// O QUE ELA **NÃO** PROVA, e por isso não é a prova principal desta entrega:
//
//   Que `checkRevoked: true` é o que faz a diferença. NESTE EMULADOR
//   `verifyIdToken` recusa o token revogado MESMO SEM a flag — está medido na OS
//   anterior (§4 de docs/PROVISIONAMENTO-CLAIM-MOTOR-PARTIDAS-V1.md) e é
//   reafirmado aqui como OBSERVAÇÃO, não como asserção. Em produção é o
//   contrário: sem a flag, o token revogado continua verificando até expirar.
//
//   Fixar o comportamento do emulador prenderia a suíte a um detalhe do
//   `firebase-tools`; fixar o de produção faria a suíte falhar aqui. A prova que
//   MANDA está em `revogacao_receptor.test.js` (REC-06): o dublê registra os
//   argumentos e afirma o `true`.
//
// Roda com: npm run emulador:revogacao

'use strict';

const { test, describe, before, after } = require('node:test');
const assert = require('node:assert/strict');

const admin = require('firebase-admin');
const {
  RECUSA,
  conferirAutoridadeDePartida,
  verificadorComRevogacao,
  CLAIM_MOTOR_DE_PARTIDAS,
} = require('../lib/autoridade.js');

const HOST = process.env.FIREBASE_AUTH_EMULATOR_HOST;
const PROJETO = process.env.GCLOUD_PROJECT || process.env.GOOGLE_CLOUD_PROJECT || 'bmv-prov-teste';
const CHAVE_FALSA = 'chave-de-emulador';

if (!HOST) {
  throw new Error(
    'FIREBASE_AUTH_EMULATOR_HOST não definido. Esta suíte precisa do emulador: ' +
    'rode `npm run emulador:revogacao`. Falhar alto aqui é deliberado — ' +
    'uma suíte de segurança que se auto-pula é uma suíte que ninguém percebe que parou de rodar.'
  );
}

let auth;
let verificar;
const criados = [];

before(() => {
  if (admin.apps.length === 0) admin.initializeApp({ projectId: PROJETO });
  auth = admin.auth();
  // O verificador DE PRODUÇÃO, montado sobre o `auth` de verdade. Nenhum
  // envelope de teste: é a mesma expressão que `rastreabilidade.ts` executa.
  verificar = verificadorComRevogacao(auth);
});

after(async () => {
  for (const uid of criados) {
    try { await auth.deleteUser(uid); } catch (_) { /* já sumiu */ }
  }
});

async function novaIdentidade(rotulo, claims) {
  const uid = 'rec-' + rotulo + '-' + Math.floor(Math.random() * 1e9).toString(36);
  await auth.createUser({ uid });
  if (claims) await auth.setCustomUserClaims(uid, claims);
  criados.push(uid);
  return uid;
}

/** Primeira emissão: custom token → par (idToken, refreshToken). */
async function emitirTokens(uid) {
  const custom = await auth.createCustomToken(uid);
  const r = await fetch(
    `http://${HOST}/identitytoolkit.googleapis.com/v1/accounts:signInWithCustomToken?key=${CHAVE_FALSA}`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ token: custom, returnSecureToken: true }),
    }
  );
  assert.equal(r.ok, true, 'o emulador recusou a troca do custom token');
  const j = await r.json();
  return { idToken: j.idToken, refreshToken: j.refreshToken };
}

/** RENOVAÇÃO — é aqui que um claim concedido depois entra no token. */
async function renovar(refreshToken) {
  const r = await fetch(`http://${HOST}/securetoken.googleapis.com/v1/token?key=${CHAVE_FALSA}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({ grant_type: 'refresh_token', refresh_token: refreshToken }),
  });
  assert.equal(r.ok, true, 'o emulador recusou a renovação');
  const j = await r.json();
  return { idToken: j.id_token, refreshToken: j.refresh_token };
}

/**
 * Revoga as sessões e só devolve quando o corte é DE FATO posterior ao token.
 *
 * `tokensValidAfterTime` tem resolução de UM SEGUNDO, e a recusa só dispara
 * quando `auth_time < validSince`. Revogar no mesmo segundo em que o token
 * nasceu deixa os dois iguais, e a checagem não dispara — quem conferir no mesmo
 * segundo conclui, errado, que o corte falhou. Este laço espera pelo FATO.
 */
async function revogarSessoesDepoisDe(uid, authTime) {
  for (let tentativa = 0; tentativa < 5; tentativa++) {
    await auth.revokeRefreshTokens(uid);
    const u = await auth.getUser(uid);
    const validSince = Math.floor(new Date(u.tokensValidAfterTime).getTime() / 1000);
    if (validSince > authTime) return validSince;
    await new Promise((r) => setTimeout(r, 600));
  }
  throw new Error('o carimbo de revogação não ultrapassou o auth_time do token');
}

/** A guarda de produção, como o receptor a chama. */
function guarda(idToken, uidDoProtocolo) {
  return conferirAutoridadeDePartida({
    cabecalhoAuthorization: idToken === null ? undefined : 'Bearer ' + idToken,
    uidDoProtocolo,
    verificar,
  });
}

describe('RECINT/CADEIA', () => {
  test('RECINT-01: a credencial do motor autoriza pela guarda real', async () => {
    const uid = await novaIdentidade('motor', { [CLAIM_MOTOR_DE_PARTIDAS]: true });
    const t = await renovar((await emitirTokens(uid)).refreshToken);

    const r = await guarda(t.idToken, uid);
    assert.equal(r.ok, true, 'a credencial do motor tem de autorizar');
    assert.equal(r.uid, uid);
  });

  test('RECINT-02: revogar a SESSÃO derruba o token na hora, pela guarda real', async () => {
    const uid = await novaIdentidade('corte', { [CLAIM_MOTOR_DE_PARTIDAS]: true });
    const t = await renovar((await emitirTokens(uid)).refreshToken);

    const antes = await guarda(t.idToken, uid);
    assert.equal(antes.ok, true, 'antes do corte, autoriza');

    const decodificado = await auth.verifyIdToken(t.idToken);
    await revogarSessoesDepoisDe(uid, decodificado.auth_time);

    const depois = await guarda(t.idToken, uid);
    assert.equal(depois.ok, false, 'depois do corte, o MESMO token não pode mais autorizar');
    assert.equal(depois.motivo, RECUSA.TOKEN_RECUSADO);

    // OBSERVAÇÃO, não asserção: este emulador recusa o token revogado mesmo sem
    // a flag. Em produção, não. O que garante o corte lá é o `checkRevoked:
    // true` que REC-06 fixa, e é por isso que aquele teste é o obrigatório.
    let recusouSemFlag = false;
    try { await auth.verifyIdToken(t.idToken); } catch (_) { recusouSemFlag = true; }
    console.log(
      '  [observado] sem checkRevoked, este emulador ' +
      (recusouSemFlag ? 'TAMBÉM recusa' : 'ACEITA') +
      ' o token revogado. Em produção ele ACEITA — daí a flag.'
    );
  });

  test('RECINT-03: revogar só o CLAIM não derruba o token já emitido', async () => {
    // O outro lado da moeda, e a razão de o runbook mandar fazer as DUAS coisas.
    const uid = await novaIdentidade('claim', { [CLAIM_MOTOR_DE_PARTIDAS]: true });
    const t = await renovar((await emitirTokens(uid)).refreshToken);
    assert.equal((await guarda(t.idToken, uid)).ok, true);

    await auth.setCustomUserClaims(uid, {});

    const depois = await guarda(t.idToken, uid);
    assert.equal(depois.ok, true, 'tirar o claim NÃO invalida um token já emitido — é por isso que se revoga a sessão');
  });

  test('RECINT-04: o claim entra pela RENOVAÇÃO, não pela concessão', async () => {
    const uid = await novaIdentidade('renov');
    const par = await emitirTokens(uid);

    const velho = await renovar(par.refreshToken);
    assert.equal((await guarda(velho.idToken, uid)).ok, false, 'sem o claim, não autoriza');

    await auth.setCustomUserClaims(uid, { [CLAIM_MOTOR_DE_PARTIDAS]: true });
    assert.equal(
      (await guarda(velho.idToken, uid)).ok,
      false,
      'o token ANTERIOR à concessão continua sem o claim'
    );

    const novo = await renovar(velho.refreshToken);
    assert.equal((await guarda(novo.idToken, uid)).ok, true, 'só o token RENOVADO carrega o claim');
  });
});

describe('RECINT/SEGURANCA', () => {
  test('RECINT-05: jogador comum não autoriza', async () => {
    const uid = await novaIdentidade('jogador');
    const t = await renovar((await emitirTokens(uid)).refreshToken);
    const r = await guarda(t.idToken, uid);
    assert.equal(r.ok, false);
    assert.equal(r.motivo, RECUSA.SEM_AUTORIDADE);
  });

  test('RECINT-06: token de OUTRA identidade é recusado por divergência', async () => {
    // O ataque direto: a identidade técnica apresenta o próprio token, mas o
    // protocolo callable diz que quem chama é outro. Sem esta comparação, a
    // autoridade sairia do token e a atribuição de autoria sairia do protocolo —
    // e `registradoPor` gravaria a pessoa errada.
    const motor = await novaIdentidade('duplo', { [CLAIM_MOTOR_DE_PARTIDAS]: true });
    const outro = await novaIdentidade('outro');
    const t = await renovar((await emitirTokens(motor)).refreshToken);

    const r = await guarda(t.idToken, outro);
    assert.equal(r.ok, false);
    assert.equal(r.motivo, RECUSA.IDENTIDADE_DIVERGENTE);
  });

  test('RECINT-07: bearer ausente, malformado e token inválido', async () => {
    assert.equal((await guarda(null, 'quem-quer-que-seja')).motivo, RECUSA.SEM_BEARER);

    const soLixo = await conferirAutoridadeDePartida({
      cabecalhoAuthorization: 'Bearer',
      uidDoProtocolo: 'x',
      verificar,
    });
    assert.equal(soLixo.motivo, RECUSA.BEARER_MALFORMADO);

    const invalido = await guarda('nao.e.um.token', 'x');
    assert.equal(invalido.motivo, RECUSA.TOKEN_RECUSADO);
  });

  test('RECINT-08: claim com tipo errado não autoriza, mesmo em token renovado', async () => {
    for (const errado of [false, 'true', 1]) {
      const uid = await novaIdentidade('tipo', { [CLAIM_MOTOR_DE_PARTIDAS]: errado });
      const t = await renovar((await emitirTokens(uid)).refreshToken);
      const r = await guarda(t.idToken, uid);
      assert.equal(r.ok, false, 'claim ' + JSON.stringify(errado) + ' não pode autorizar');
      assert.equal(r.motivo, RECUSA.SEM_AUTORIDADE);
    }
  });

  test('RECINT-09: `admin` autoriza por papel próprio, sem o claim novo', async () => {
    const uid = await novaIdentidade('admin', { admin: true });
    const t = await renovar((await emitirTokens(uid)).refreshToken);
    assert.equal((await guarda(t.idToken, uid)).ok, true);
  });
});
