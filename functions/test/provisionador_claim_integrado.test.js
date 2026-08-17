// provisionador_claim_integrado.test.js — a CADEIA INTEIRA, contra o emulador.
//
// O que esta suíte prova, e que nenhum teste puro consegue: que o claim
// concedido pelo provisionador chega de fato a um ID token, que ele só chega
// num token NOVO, e que a guarda de produção o aceita — e volta a recusar
// depois da revogação.
//
// A guarda exercitada é a REAL: `lib/autoridade.js`, compilada de
// `src/autoridade.ts`, que é a mesma função que `exigirAutoridadeDePartida`
// chama. Reimplementar o predicado aqui provaria apenas que sei escrever
// `=== true` duas vezes.
//
// Nenhuma partida é gravada e nenhuma conquista é concedida: esta OS provisiona
// identidade, e não joga. Só o emulador de Auth é usado — nem Firestore, nem
// Functions.
//
// Uso:
//   cd functions && npm run emulador:provisionador

'use strict';

const { test, describe, before, after } = require('node:test');
const assert = require('node:assert/strict');
const { execFileSync } = require('node:child_process');
const path = require('node:path');

const admin = require('firebase-admin');
const { autorizaComoMotorDePartidas, CLAIM_MOTOR_DE_PARTIDAS } = require('../lib/autoridade.js');
const provisionador = require('../scripts/provisionar_claim_motor_partidas.js');

const HOST = process.env.FIREBASE_AUTH_EMULATOR_HOST;
const PROJETO = process.env.GCLOUD_PROJECT || process.env.GOOGLE_CLOUD_PROJECT || 'bmv-prov-teste';
const SCRIPT = path.resolve(__dirname, '..', 'scripts', 'provisionar_claim_motor_partidas.js');

// Chave de API é irrelevante no emulador, mas o endpoint exige o parâmetro.
const CHAVE_FALSA = 'chave-de-emulador';

if (!HOST) {
  throw new Error(
    'FIREBASE_AUTH_EMULATOR_HOST não definido. Esta suíte precisa do emulador: ' +
    'rode `npm run emulador:provisionador`. Falhar alto aqui é deliberado — ' +
    'uma suíte de segurança que se auto-pula é uma suíte que ninguém percebe que parou de rodar.'
  );
}

let auth;
const criados = [];

/** Identidade de teste, descartável, criada e removida por esta suíte. */
async function novaIdentidade(rotulo, claims) {
  const uid = 'prov-' + rotulo + '-' + Math.floor(Math.random() * 1e9).toString(36);
  await auth.createUser({ uid });
  if (claims) await auth.setCustomUserClaims(uid, claims);
  criados.push(uid);
  return uid;
}

/** Primeira emissão: token de custom → par (idToken, refreshToken). */
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

/** RENOVAÇÃO — é aqui que um claim novo entra no token. */
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

/** Os claims como a Function os veria, decodificados pelo SDK de verdade. */
async function claimsDoToken(idToken) {
  return auth.verifyIdToken(idToken);
}

/**
 * Revoga as sessões e só devolve quando o corte é DE FATO posterior ao token.
 *
 * `tokensValidAfterTime` tem resolução de UM SEGUNDO, e a verificação só recusa
 * quando `auth_time < validSince`. Revogar no mesmo segundo em que o token foi
 * emitido deixa os dois valores iguais — medido: `auth_time` e `validSince`
 * caíram ambos em 1786937626 — e a comparação não dispara. O teste então
 * passaria a impressão de que a revogação de sessão não funciona, quando o que
 * faltou foi cruzar a borda do segundo.
 *
 * Um `sleep` fixo resolveria na maioria das vezes e falharia de vez em quando.
 * Este laço espera pelo FATO, e não por um prazo: revoga de novo até o carimbo
 * ultrapassar o token, ou desiste alto.
 *
 * Vale para produção, e não só para o emulador: quem cortar acesso e conferir
 * no mesmo segundo vai concluir, errado, que o corte falhou.
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

/** Roda o provisionador REAL, como o operador rodaria. */
function rodar(args, { esperaFalha = false } = {}) {
  try {
    const saida = execFileSync(process.execPath, [SCRIPT, ...args], {
      encoding: 'utf8',
      env: process.env,
      stdio: ['ignore', 'pipe', 'pipe'],
    });
    assert.equal(esperaFalha, false, 'esperava código de saída diferente de zero, e o script passou');
    return { codigo: 0, saida };
  } catch (e) {
    assert.equal(esperaFalha, true, 'o provisionador falhou inesperadamente:\n' + (e.stderr || e.message));
    return { codigo: e.status, saida: (e.stdout || '') + (e.stderr || '') };
  }
}

const base = (uid) => ['--project', PROJETO, '--uid', uid];
const gravando = (uid) => [...base(uid), '--commit', '--confirmar-projeto', PROJETO];

before(() => {
  if (admin.apps.length === 0) admin.initializeApp({ projectId: PROJETO });
  auth = admin.auth();
});

after(async () => {
  for (const uid of criados) {
    try { await auth.deleteUser(uid); } catch (_) { /* fixture já removida */ }
  }
});

// ===========================================================================
describe('INT/CADEIA', () => {
  test('INT-01: a cadeia inteira — negado, concedido, renovado, aceito, revogado, negado', async () => {
    const uid = await novaIdentidade('cadeia');

    // 1-3. Token SEM o claim: a guarda recusa.
    const t0 = await emitirTokens(uid);
    const c0 = await claimsDoToken(t0.idToken);
    assert.equal(c0[CLAIM_MOTOR_DE_PARTIDAS], undefined, 'a identidade nasce sem autoridade');
    assert.equal(autorizaComoMotorDePartidas(c0), false, 'sem claim, a guarda TEM de recusar');

    // 4. Concessão pelo provisionador real.
    const g = rodar(['grant', ...gravando(uid)]);
    assert.equal(g.codigo, 0);
    assert.match(g.saida, /gravado e verificado/);

    // O token JÁ EMITIDO não ganha o claim por mágica — é o ponto da §8.
    const aindaVelho = await claimsDoToken(t0.idToken);
    assert.equal(autorizaComoMotorDePartidas(aindaVelho), false,
      'um token emitido antes da concessão NÃO passa a autorizar sozinho');

    // 5-7. Renovar, e só então a guarda aceita.
    const t1 = await renovar(t0.refreshToken);
    const c1 = await claimsDoToken(t1.idToken);
    assert.equal(c1[CLAIM_MOTOR_DE_PARTIDAS], true);
    assert.equal(typeof c1[CLAIM_MOTOR_DE_PARTIDAS], 'boolean', 'tem de ser BOOLEANO no token');
    assert.equal(autorizaComoMotorDePartidas(c1), true, 'a guarda de produção tem de aceitar');

    // 8. Concessão repetida é idempotente e não escreve.
    const g2 = rodar(['grant', ...gravando(uid)]);
    assert.equal(g2.codigo, 0);
    assert.match(g2.saida, /nada a fazer \(ja_concedido\)/);

    // 9-11. Revogar, renovar, e a porta fecha de novo.
    const r = rodar(['revoke', ...gravando(uid)]);
    assert.equal(r.codigo, 0);
    const t2 = await renovar(t1.refreshToken);
    const c2 = await claimsDoToken(t2.idToken);
    assert.equal(c2[CLAIM_MOTOR_DE_PARTIDAS], undefined, 'revogar remove a chave');
    assert.equal(autorizaComoMotorDePartidas(c2), false, 'depois de revogar, a guarda recusa de novo');

    const r2 = rodar(['revoke', ...gravando(uid)]);
    assert.match(r2.saida, /nada a fazer \(ja_revogado\)/, 'revogação repetida é idempotente');
  });

  test('INT-02: o token anterior à revogação pode ser invalidado explicitamente', async () => {
    // Revogar o claim NÃO derruba um ID token já emitido: ele vale até expirar.
    // Quem precisa cortar o acesso na hora tem de revogar as sessões também — e
    // o consumidor tem de conferir. É o contrato que o transporte vai herdar.
    const uid = await novaIdentidade('sessao');
    rodar(['grant', ...gravando(uid)]);
    const t = await renovar((await emitirTokens(uid)).refreshToken);
    assert.equal(autorizaComoMotorDePartidas(await claimsDoToken(t.idToken)), true);

    rodar(['revoke', ...gravando(uid)]);
    await revogarSessoesDepoisDe(uid, (await claimsDoToken(t.idToken)).auth_time);

    // O QUE SE AFIRMA: pedindo a checagem, o token emitido antes do corte é
    // recusado. É o mecanismo que o transporte terá de usar quando precisar
    // cortar acesso antes de o token expirar sozinho.
    await assert.rejects(
      () => auth.verifyIdToken(t.idToken, true),
      (e) => /revoked/i.test(e.code || e.message),
      'com checkRevoked, o token anterior TEM de ser recusado'
    );

    // O QUE NÃO SE AFIRMA, E POR QUÊ.
    //
    // Medido: neste emulador, `verifyIdToken` recusa o token revogado MESMO SEM
    // `checkRevoked` — a chamada sem a flag lançou `auth/id-token-revoked`. Em
    // produção o SDK só consulta revogação quando a flag é `true`; sem ela, um
    // token revogado continua verificando até expirar.
    //
    // A divergência fica REGISTRADA e não virou asserção, nos dois sentidos:
    // fixar o comportamento do emulador prenderia a suíte a um detalhe de
    // implementação do firebase-tools, e fixar o de produção faria a suíte
    // falhar aqui. O que importa para quem for escrever o transporte é a regra
    // conservadora: NÃO conte com recusa automática — passe `true`.
  });

  test('INT-02b: revogar o CLAIM não invalida, sozinho, um token já emitido', async () => {
    // Distinção que o transporte precisa herdar: `revoke` mexe no claim, e o
    // claim vive DENTRO do token. Um token emitido antes continua carregando o
    // claim antigo até ser renovado — revogar não o alcança.
    const uid = await novaIdentidade('claimvelho');
    rodar(['grant', ...gravando(uid)]);
    const t = await renovar((await emitirTokens(uid)).refreshToken);
    assert.equal(autorizaComoMotorDePartidas(await claimsDoToken(t.idToken)), true);

    rodar(['revoke', ...gravando(uid)]);

    // O claim já saiu da conta...
    assert.deepEqual((await auth.getUser(uid)).customClaims || {}, {});
    // ...e mesmo assim o token velho AINDA autoriza.
    assert.equal(autorizaComoMotorDePartidas(await claimsDoToken(t.idToken)), true,
      'o token emitido antes carrega o claim antigo — revogar não o alcança');
    // Só a renovação fecha a porta.
    assert.equal(
      autorizaComoMotorDePartidas(await claimsDoToken((await renovar(t.refreshToken)).idToken)),
      false, 'depois de renovar, a autoridade acabou');
  });
});

// ===========================================================================
describe('INT/SEGURANCA', () => {
  test('INT-03: ensaio não escreve nada', async () => {
    const uid = await novaIdentidade('ensaio');
    const e = rodar(['grant', ...base(uid)]);
    assert.equal(e.codigo, 0);
    assert.match(e.saida, /ENSAIO/);

    const depois = (await auth.getUser(uid)).customClaims || {};
    assert.deepEqual(depois, {}, 'o ensaio gravou — que é justamente o que ele não pode fazer');
    const c = await claimsDoToken((await emitirTokens(uid)).idToken);
    assert.equal(autorizaComoMotorDePartidas(c), false);
  });

  test('INT-04: --commit sem confirmação do projeto não escreve', async () => {
    const uid = await novaIdentidade('semconf');
    const f = rodar(['grant', ...base(uid), '--commit'], { esperaFalha: true });
    assert.notEqual(f.codigo, 0, 'falha tem de sair com código diferente de zero');
    assert.deepEqual((await auth.getUser(uid)).customClaims || {}, {});
  });

  test('INT-05: confirmação de projeto DIVERGENTE não escreve', async () => {
    const uid = await novaIdentidade('projerrado');
    const f = rodar(
      ['grant', ...base(uid), '--commit', '--confirmar-projeto', 'outro-projeto-qualquer'],
      { esperaFalha: true }
    );
    assert.notEqual(f.codigo, 0);
    assert.deepEqual((await auth.getUser(uid)).customClaims || {}, {},
      'escrever no projeto errado é o acidente mais caro possível aqui');
  });

  test('INT-06: UID inexistente falha alto e não cria ninguém', async () => {
    const fantasma = 'prov-nao-existe-' + Math.floor(Math.random() * 1e9).toString(36);
    const f = rodar(['grant', '--project', PROJETO, '--uid', fantasma,
      '--commit', '--confirmar-projeto', PROJETO], { esperaFalha: true });
    assert.notEqual(f.codigo, 0);
    await assert.rejects(() => auth.getUser(fantasma), 'o provisionador não pode CRIAR identidade');
  });

  test('INT-07: claims alheios sobrevivem à concessão e à revogação', async () => {
    // `setCustomUserClaims` sobrescreve o mapa inteiro. Se o provisionador
    // montasse `{motorDePartidas:true}` do zero, este `admin` desapareceria — e
    // ninguém notaria até alguém perder acesso administrativo.
    const uid = await novaIdentidade('preserva', { admin: true, suporte: true });

    rodar(['grant', ...gravando(uid)]);
    let claims = (await auth.getUser(uid)).customClaims;
    assert.deepEqual(claims, { admin: true, suporte: true, [CLAIM_MOTOR_DE_PARTIDAS]: true });

    rodar(['revoke', ...gravando(uid)]);
    claims = (await auth.getUser(uid)).customClaims;
    assert.deepEqual(claims, { admin: true, suporte: true },
      'a revogação tirou permissão que não era dela');
  });

  test('INT-08: claim com tipo errado não autoriza, e é corrigido', async () => {
    // O estrago que um provisionamento manual produz: a string "true".
    const uid = await novaIdentidade('tipoerrado', { [CLAIM_MOTOR_DE_PARTIDAS]: 'true' });
    const c0 = await claimsDoToken((await emitirTokens(uid)).idToken);
    assert.equal(c0[CLAIM_MOTOR_DE_PARTIDAS], 'true');
    assert.equal(autorizaComoMotorDePartidas(c0), false,
      'a string "true" NÃO pode autorizar — é o defeito que a guarda estrita existe para pegar');

    rodar(['grant', ...gravando(uid)]);
    const c1 = await claimsDoToken((await renovar((await emitirTokens(uid)).refreshToken)).idToken);
    assert.equal(c1[CLAIM_MOTOR_DE_PARTIDAS], true);
    assert.equal(autorizaComoMotorDePartidas(c1), true);
  });

  test('INT-09: jogador comum não autoriza, e o admin humano autoriza por OUTRO papel', async () => {
    const jogador = await novaIdentidade('jogador');
    const cj = await claimsDoToken((await emitirTokens(jogador)).idToken);
    assert.equal(autorizaComoMotorDePartidas(cj), false, 'jogador comum não manda no encerramento');

    // `admin` é papel de autoridade por decisão anterior a esta OS (é a saída de
    // emergência). Fica FIXADO aqui para que ninguém o remova sem perceber, e
    // para deixar explícito que não é o provisionador que o concede.
    const humano = await novaIdentidade('admin', { admin: true });
    const ch = await claimsDoToken((await emitirTokens(humano)).idToken);
    assert.equal(autorizaComoMotorDePartidas(ch), true);
    assert.equal(ch[CLAIM_MOTOR_DE_PARTIDAS], undefined,
      'o admin autoriza pelo papel dele, e NÃO por ter ganhado o claim do motor');
  });

  test('INT-10: token inválido é recusado pelo SDK', async () => {
    await assert.rejects(() => auth.verifyIdToken('nao.e.um.token'));
    await assert.rejects(() => auth.verifyIdToken(''));
  });

  test('INT-11: inspect não escreve e relata o estado real', async () => {
    const uid = await novaIdentidade('inspect');
    const i0 = rodar(['inspect', ...base(uid)]);
    assert.match(i0.saida, /autoriza\?\s*:\s*NÃO/);

    rodar(['grant', ...gravando(uid)]);
    const i1 = rodar(['inspect', ...base(uid)]);
    assert.match(i1.saida, /autoriza\?\s*:\s*SIM/);
    assert.deepEqual((await auth.getUser(uid)).customClaims, { [CLAIM_MOTOR_DE_PARTIDAS]: true },
      'inspect não pode ter mudado nada');
  });

  test('INT-12: a saída não vaza o UID inteiro nem segredo algum', async () => {
    const uid = await novaIdentidade('redacao');
    const s = rodar(['inspect', ...base(uid)]).saida + rodar(['grant', ...gravando(uid)]).saida;
    assert.equal(s.includes(uid), false, 'o UID técnico não pode sair inteiro no log');
    assert.match(s, /mascarado/);
    for (const proibido of ['eyJ', 'Bearer', 'private_key', 'refresh_token']) {
      assert.equal(s.includes(proibido), false, 'a saída vazou `' + proibido + '`');
    }
  });

  test('INT-13: a grafia do claim é a MESMA nos dois lados', () => {
    // Um erro de digitação aqui produziria um claim que nada lê e uma
    // autoridade que nunca funciona — sem erro em lugar nenhum.
    assert.equal(provisionador.CLAIM, CLAIM_MOTOR_DE_PARTIDAS);
  });
});
