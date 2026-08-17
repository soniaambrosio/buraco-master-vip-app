// revogacao_receptor.test.js — A MATRIZ DO RECEPTOR (§12 da OS).
//
// Prova a guarda REAL, `lib/autoridade.js`, compilada de `src/autoridade.ts` —
// a mesma que `exigirAutoridadeDePartida` chama. Reimplementar o predicado aqui
// provaria apenas que sei escrever `=== true` duas vezes.
//
// O QUE ESTA SUÍTE EXISTE PARA IMPEDIR, e vale ler antes de mexer nela:
//
//   O protocolo callable JÁ verifica o ID token e preenche `request.auth`. O que
//   ele NÃO faz é consultar revogação. Um token de sessão revogada continua
//   chegando com `req.auth.token.motorDePartidas === true` até expirar — até uma
//   hora depois de alguém ter cortado o acesso.
//
//   No EMULADOR isso não aparece: lá `verifyIdToken` recusa o token revogado
//   mesmo sem a flag. Por isso a prova que MANDA aqui não é "o emulador
//   recusou" — é que o código chama a verificação com `checkRevoked: true`, e
//   isso é afirmado sobre um dublê que REGISTRA os argumentos recebidos. Um
//   `false` acidental quebra este arquivo em produção-equivalente, e não só na
//   máquina de quem tem emulador.
//
// Sem rede, sem emulador, sem projeto: `node --test test/revogacao_receptor.test.js`.

'use strict';

const { test, describe } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const {
  RECUSA,
  extrairBearer,
  verificadorComRevogacao,
  conferirAutoridadeDePartida,
  autorizaComoMotorDePartidas,
  CLAIM_MOTOR_DE_PARTIDAS,
} = require('../lib/autoridade.js');

const UID = 'uid-do-motor';

/// Verificador de mentira que devolve o que o teste mandar — e registra tudo.
function verificadorFalso({ uid = UID, claims = {}, erro = null } = {}) {
  const chamadas = [];
  const fn = async (token) => {
    chamadas.push(token);
    if (erro) throw erro;
    return { uid, claims };
  };
  fn.chamadas = chamadas;
  return fn;
}

function bearer(token) {
  return 'Bearer ' + token;
}

async function conferir({ cabecalho, uidDoProtocolo = UID, verificar }) {
  return conferirAutoridadeDePartida({
    cabecalhoAuthorization: cabecalho,
    uidDoProtocolo,
    verificar,
  });
}

/// Erro no formato do que o Admin SDK lança.
function erroDoSdk(codigo) {
  return Object.assign(new Error(codigo), { code: codigo });
}

// ---------------------------------------------------------------------------
// O BEARER
// ---------------------------------------------------------------------------

describe('REC/BEARER', () => {
  test('REC-01: bearer ausente é recusado', async () => {
    const v = verificadorFalso();
    for (const nada of [undefined, null]) {
      const r = await conferir({ cabecalho: nada, verificar: v });
      assert.equal(r.ok, false);
      assert.equal(r.motivo, RECUSA.SEM_BEARER);
    }
    assert.equal(v.chamadas.length, 0, 'sem cabeçalho não há o que verificar');
  });

  test('REC-02: bearer malformado é recusado', async () => {
    const v = verificadorFalso();
    const ruins = [
      '',                    // vazio
      'abc',                 // sem esquema
      'Bearer',              // esquema sem token
      'Bearer ',             // espaço e nada
      'bearer abc',          // minúsculo — não é o que a nossa própria chamada emite
      'Basic abc',           // outro esquema
      'Bearer a b',          // dois tokens
      'Bearer  abc',         // espaço duplo
      'Token abc',
      42,                    // nem string
      {},
      ['Bearer abc'],
    ];
    for (const ruim of ruins) {
      const r = await conferir({ cabecalho: ruim, verificar: v });
      assert.equal(r.ok, false, 'deveria recusar ' + JSON.stringify(ruim));
      assert.equal(r.motivo, RECUSA.BEARER_MALFORMADO, 'motivo errado para ' + JSON.stringify(ruim));
    }
    assert.equal(v.chamadas.length, 0, 'nada malformado pode chegar ao verificador');
  });

  test('REC-02b: extrairBearer devolve exatamente o token', () => {
    assert.equal(extrairBearer('Bearer abc.def.ghi'), 'abc.def.ghi');
    assert.equal(extrairBearer('Bearer x'), 'x');
    assert.equal(extrairBearer(undefined), null);
  });

  test('REC-02c: o token entregue ao verificador é o do cabeçalho, sem sobras', async () => {
    const v = verificadorFalso({ claims: { [CLAIM_MOTOR_DE_PARTIDAS]: true } });
    await conferir({ cabecalho: bearer('token.de.verdade'), verificar: v });
    assert.deepEqual(v.chamadas, ['token.de.verdade'], 'nem "Bearer " nem espaço podem viajar junto');
  });
});

// ---------------------------------------------------------------------------
// A VERIFICAÇÃO
// ---------------------------------------------------------------------------

describe('REC/VERIFICACAO', () => {
  test('REC-03: token inválido é recusado', async () => {
    const r = await conferir({
      cabecalho: bearer('nao.e.um.token'),
      verificar: verificadorFalso({ erro: erroDoSdk('auth/argument-error') }),
    });
    assert.equal(r.ok, false);
    assert.equal(r.motivo, RECUSA.TOKEN_RECUSADO);
  });

  test('REC-04: token expirado é recusado', async () => {
    const r = await conferir({
      cabecalho: bearer('t'),
      verificar: verificadorFalso({ erro: erroDoSdk('auth/id-token-expired') }),
    });
    assert.equal(r.ok, false);
    assert.equal(r.motivo, RECUSA.TOKEN_RECUSADO);
  });

  test('REC-05: token REVOGADO é recusado', async () => {
    // É o caso que dá nome a esta entrega. Sem `checkRevoked`, o SDK nem lança:
    // devolve o token decodificado e a autoridade é concedida.
    const r = await conferir({
      cabecalho: bearer('t'),
      verificar: verificadorFalso({ erro: erroDoSdk('auth/id-token-revoked') }),
    });
    assert.equal(r.ok, false);
    assert.equal(r.motivo, RECUSA.TOKEN_RECUSADO);
  });

  test('REC-05b: a recusa não distingue os motivos para quem chamou', async () => {
    // Os três casos acima dão no MESMO motivo interno. Detalhar "sessão
    // revogada" versus "sem o claim" descreveria a defesa para quem a estivesse
    // sondando — e o servidor de partidas não precisa da diferença: ele renova o
    // token e tenta de novo, seja qual for.
    const motivos = new Set();
    for (const codigo of ['auth/argument-error', 'auth/id-token-expired', 'auth/id-token-revoked']) {
      const r = await conferir({ cabecalho: bearer('t'), verificar: verificadorFalso({ erro: erroDoSdk(codigo) }) });
      motivos.add(r.motivo);
    }
    assert.deepEqual([...motivos], [RECUSA.TOKEN_RECUSADO]);
  });

  test('REC-06: verifyIdToken é chamado com o segundo argumento `true`', async () => {
    // A PROVA OBRIGATÓRIA DA §12. Não é grep na fonte: é o dublê registrando o
    // que recebeu do código de produção.
    const recebidos = [];
    const auth = {
      async verifyIdToken(token, checkRevoked) {
        recebidos.push([token, checkRevoked]);
        return { uid: UID, [CLAIM_MOTOR_DE_PARTIDAS]: true };
      },
    };

    const r = await conferir({ cabecalho: bearer('tok'), verificar: verificadorComRevogacao(auth) });

    assert.equal(r.ok, true);
    assert.equal(recebidos.length, 1);
    assert.equal(recebidos[0][0], 'tok');
    assert.equal(recebidos[0][1], true, 'checkRevoked TEM de ser true — sem isso o corte não vale em produção');
    // `=== true`, e não "truthy": um `1` aqui seria aceito pelo SDK e passaria
    // despercebido numa asserção frouxa.
    assert.strictEqual(recebidos[0][1], true);
  });

  test('REC-06b: os claims saem do token VERIFICADO, e não de outro lugar', async () => {
    // O Admin SDK entrega os custom claims no mesmo nível de `sub`/`aud`/`iss`.
    const auth = {
      async verifyIdToken() {
        return { uid: UID, sub: UID, aud: 'proj', [CLAIM_MOTOR_DE_PARTIDAS]: true };
      },
    };
    const verificado = await verificadorComRevogacao(auth)('tok');
    assert.equal(verificado.uid, UID);
    assert.equal(autorizaComoMotorDePartidas(verificado.claims), true);
  });
});

// ---------------------------------------------------------------------------
// AS DUAS IDENTIDADES
// ---------------------------------------------------------------------------

describe('REC/IDENTIDADE', () => {
  test('REC-07: UID verificado divergente de req.auth.uid é recusado', async () => {
    const r = await conferir({
      cabecalho: bearer('t'),
      uidDoProtocolo: 'uid-do-protocolo',
      verificar: verificadorFalso({ uid: 'uid-do-token', claims: { [CLAIM_MOTOR_DE_PARTIDAS]: true } }),
    });
    assert.equal(r.ok, false);
    assert.equal(r.motivo, RECUSA.IDENTIDADE_DIVERGENTE);
  });

  test('REC-07b: UID vazio dos DOIS lados não passa por "coincidem"', async () => {
    // `'' === ''` é verdadeiro, e uma comparação escrita só como igualdade
    // concederia autoridade a uma identidade vazia. Chamado sem o arnês de
    // propósito: os parâmetros com valor padrão de `conferir()` absorveriam o
    // `undefined` e o teste provaria outra coisa.
    for (const vazio of ['', undefined, null]) {
      const r = await conferirAutoridadeDePartida({
        cabecalhoAuthorization: bearer('t'),
        uidDoProtocolo: vazio,
        verificar: verificadorFalso({ uid: vazio, claims: { [CLAIM_MOTOR_DE_PARTIDAS]: true } }),
      });
      assert.equal(r.ok, false, 'uid vazio (' + JSON.stringify(vazio) + ') não pode autorizar');
      assert.equal(r.motivo, RECUSA.IDENTIDADE_DIVERGENTE);
    }
  });

  test('REC-07c: o uid devolvido é o VERIFICADO', async () => {
    const r = await conferir({
      cabecalho: bearer('t'),
      verificar: verificadorFalso({ uid: UID, claims: { [CLAIM_MOTOR_DE_PARTIDAS]: true } }),
    });
    assert.equal(r.ok, true);
    assert.equal(r.uid, UID);
  });
});

// ---------------------------------------------------------------------------
// O PAPEL
// ---------------------------------------------------------------------------

describe('REC/PAPEL', () => {
  const casos = [
    ['REC-08: claim ausente', {}, false],
    ['REC-09: claim false', { [CLAIM_MOTOR_DE_PARTIDAS]: false }, false],
    ['REC-10: claim string "true"', { [CLAIM_MOTOR_DE_PARTIDAS]: 'true' }, false],
    ['REC-11: claim número 1', { [CLAIM_MOTOR_DE_PARTIDAS]: 1 }, false],
    ['REC-11b: claim string "1"', { [CLAIM_MOTOR_DE_PARTIDAS]: '1' }, false],
    ['REC-12: jogador comum (só suporte)', { suporte: true }, false],
    ['REC-12b: jogador comum (nada)', undefined, false],
    ['REC-13: motorDePartidas: true', { [CLAIM_MOTOR_DE_PARTIDAS]: true }, true],
    ['REC-14: admin: true (papel próprio, anterior a esta OS)', { admin: true }, true],
    ['REC-14b: admin: true junto de motorDePartidas: false', { admin: true, [CLAIM_MOTOR_DE_PARTIDAS]: false }, true],
  ];

  for (const [nome, claims, esperado] of casos) {
    test(nome, async () => {
      const r = await conferir({
        cabecalho: bearer('t'),
        verificar: verificadorFalso({ uid: UID, claims }),
      });
      assert.equal(r.ok, esperado, nome);
      if (!esperado) assert.equal(r.motivo, RECUSA.SEM_AUTORIDADE);
    });
  }

  test('REC-14c: `admin` continua autorizando — e está FIXADO aqui de propósito', () => {
    // Não é descuido nem herança esquecida: é a saída de emergência, decidida
    // antes desta entrega. Fica em teste para que ninguém a remova sem perceber,
    // e para deixar explícito que não é o bootstrap que a concede.
    assert.equal(autorizaComoMotorDePartidas({ admin: true }), true);
  });
});

// ---------------------------------------------------------------------------
// O QUE NÃO PODE TER MUDADO
// ---------------------------------------------------------------------------

const RASTREABILIDADE = fs.readFileSync(path.resolve(__dirname, '../src/rastreabilidade.ts'), 'utf8');

/// O corpo de `registrarEncerramentoPartida` a partir da transação.
function corpoDaTransacao() {
  const i = RASTREABILIDADE.indexOf('return db().runTransaction');
  assert.notEqual(i, -1, 'a transação sumiu de rastreabilidade.ts');
  const fim = RASTREABILIDADE.indexOf('function ehTerminal', i);
  assert.notEqual(fim, -1);
  return RASTREABILIDADE.slice(i, fim);
}

describe('REC/FRONTEIRA', () => {
  test('REC-15: a guarda não vê, não recebe e não toca o plano', async () => {
    // A superfície da guarda é o cabeçalho e o uid — `req.data` não entra nela,
    // e não há como ela alterar o que não recebe.
    const plano = { registro: { matchId: 'm1', estado: 'finalizada' }, eventos: [{ eventId: 'e1' }] };
    const copia = JSON.parse(JSON.stringify(plano));

    const r = await conferir({
      cabecalho: bearer('t'),
      verificar: verificadorFalso({ uid: UID, claims: { [CLAIM_MOTOR_DE_PARTIDAS]: true } }),
    });

    assert.equal(r.ok, true);
    assert.deepEqual(plano, copia, 'nada do plano pode ter mudado');
    // E a guarda, na fonte, não menciona o payload de negócio.
    const guarda = RASTREABILIDADE.slice(
      RASTREABILIDADE.indexOf('async function exigirAutoridadeDePartida'),
      RASTREABILIDADE.indexOf('function exigirAdmin')
    );
    assert.equal(/req\.data|plano|registro/.test(guarda), false, 'a guarda não pode tocar o payload');
  });

  test('REC-16: a transação não foi tocada por esta entrega', () => {
    const corpo = corpoDaTransacao();
    // Nenhum símbolo novo entrou no corpo transacional: a verificação acontece
    // ANTES, e o que roda dentro da transação é byte a byte o de antes.
    for (const novo of ['conferirAutoridadeDePartida', 'verificadorComRevogacao', 'getAuth', 'cabecalhoAuthorization', 'checkRevoked']) {
      assert.equal(corpo.includes(novo), false, 'a transação passou a mencionar ' + novo);
    }
    // E as escritas continuam sendo as mesmas cinco coleções.
    for (const escrita of ['matchRef', 'collection("events")', 'rankingLedger', 'fraudSignals', 'matchHistory']) {
      assert.ok(corpo.includes(escrita), 'a transação perdeu ' + escrita);
    }
    assert.ok(corpo.includes('aplicarPlanoDeConquista'), 'a conquista saiu da transação');
  });

  test('REC-16b: a autoridade é conferida ANTES de abrir a transação', () => {
    const iGuarda = RASTREABILIDADE.indexOf('await exigirAutoridadeDePartida(req)');
    const iTx = RASTREABILIDADE.indexOf('return db().runTransaction');
    assert.notEqual(iGuarda, -1, 'a guarda tem de ser aguardada');
    assert.ok(iGuarda < iTx, 'verificar dentro da transação a faria durar uma ida à rede a mais');
  });

  test('REC-17: o entrypoint continua exportando exatamente 11 símbolos', () => {
    // A CONTAGEM É ESTRUTURAL, sobre a fonte: `index.ts` faz
    // `export * from "./rastreabilidade"`, e o Firebase trata CADA export do
    // entrypoint como uma Cloud Function a implantar. Um `export` a mais em
    // qualquer um dos dois arquivos vira função nova sem ninguém decidir.
    const dir = path.resolve(__dirname, '..', 'src');
    const nomes = new Set();
    const visitar = (arquivo) => {
      const fonte = fs.readFileSync(path.join(dir, arquivo + '.ts'), 'utf8');
      for (const m of fonte.matchAll(/^export\s+(?:const|function|async function|class)\s+([A-Za-z0-9_$]+)/gm)) {
        nomes.add(m[1]);
      }
      for (const m of fonte.matchAll(/^export\s+\*\s+from\s+"\.\/([A-Za-z0-9_$]+)"/gm)) {
        visitar(m[1]);
      }
    };
    visitar('index');

    assert.deepEqual([...nomes].sort(), [
      'aoConcluirEdicao',
      'cancelarInscricaoTorneio',
      'consolidarConvitesDaTemporada',
      'consultarExtratoCompetitivo',
      'consultarPartidaPorMatchId',
      'inscreverEmTorneio',
      'receberResultadoPartida',
      'registrarEncerramentoPartida',
      'registrarSinalAntifraude',
      'responderConviteEncerramento',
      'tickTorneios',
    ]);
    assert.equal(nomes.size, 11);
  });

  test('REC-17b: `autoridade.ts` NÃO é reexportado pelo entrypoint', () => {
    // É o que mantém a guarda como biblioteca. Um `export * from "./autoridade"`
    // transformaria `conferirAutoridadeDePartida`, `extrairBearer` e o resto em
    // Cloud Functions vazias — e o `tsc` não acusaria nada.
    const index = fs.readFileSync(path.resolve(__dirname, '../src/index.ts'), 'utf8');
    assert.equal(/export\s+\*\s+from\s+"\.\/autoridade"/.test(index), false);
    assert.equal(/export\s+.*from\s+"\.\/autoridade"/.test(RASTREABILIDADE), false);
  });

  test('REC-17c: App Check NÃO foi exigido do servidor', () => {
    // Quem chama `registrarEncerramentoPartida` é o servidor de partidas, não um
    // aparelho. Exigir App Check aqui quebraria o transporte antes de ele nascer.
    const decl = RASTREABILIDADE.slice(
      RASTREABILIDADE.indexOf('export const registrarEncerramentoPartida'),
      RASTREABILIDADE.indexOf('export const registrarEncerramentoPartida') + 120
    );
    assert.match(decl, /onCall\(opcoesServidor/);
    assert.match(RASTREABILIDADE, /const opcoesServidor = \{ region: "southamerica-east1" \}/);
  });

  test('REC-17d: as funções do APLICATIVO não passaram a verificar revogação', () => {
    // §12.12: a verificação extra é do receptor do servidor, e só dele. Aplicá-la
    // às funções que o aparelho chama trocaria latência de toda a base de
    // jogadores por uma garantia que só a identidade técnica precisa.
    for (const doApp of ['consultarPartidaPorMatchId', 'consultarExtratoCompetitivo', 'registrarSinalAntifraude']) {
      const i = RASTREABILIDADE.indexOf('export const ' + doApp);
      const fim = RASTREABILIDADE.indexOf('\nexport const ', i + 1);
      const corpo = RASTREABILIDADE.slice(i, fim === -1 ? undefined : fim);
      assert.equal(corpo.includes('conferirAutoridadeDePartida'), false, doApp + ' passou a verificar revogação');
      assert.equal(corpo.includes('verificadorComRevogacao'), false, doApp + ' passou a verificar revogação');
    }
  });
});
