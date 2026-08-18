// entitlement.test.js — prova as regras do BLOCO 2b/3 (entitlement VIP).
//
// O QUE ESTE ARQUIVO PROVA, e que nenhum teste em Dart ou em `node --test`
// consegue provar: quem ESCREVE o direito e quem consegue LE-LO.
//
// A logica do ciclo de vida esta coberta em `functions-billing/test/entitlement.test.js`
// e a costura com o torneio em `app/test/elegibilidade/costura_p0_test.dart`. As
// duas suites, porem, so respondem "dado este documento, o que acontece". Elas
// nao respondem a pergunta que decide se o produto pago vale alguma coisa:
//
//     o proprio jogador consegue escrever esse documento?
//
// Se conseguir, todo o resto e decoracao — bastaria um `setDoc` com
// `vipAtivo: true` para entrar de graca em torneio VIP, e um `expiraEm` no ano
// que vem para nunca mais sair.
//
// Uso:
//   cd firebase/testes && npm install
//   npm run emulador-regras
//
// Numa maquina sem Java no PATH mas com Android Studio instalado:
//   JAVA_HOME="C:/Program Files/Android/Android Studio/jbr" npm run emulador-regras

'use strict';

const fs = require('fs');
const path = require('path');
const { test, before, after, describe } = require('node:test');

const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require('@firebase/rules-unit-testing');

const { doc, getDoc, setDoc, updateDoc, deleteDoc } = require('firebase/firestore');

const PROJETO = process.env.GCLOUD_PROJECT || 'buraco-master-vip-testes';

const DONO = 'uidAssinante';
const OUTRO = 'uidCurioso';
const ADMIN = 'uidAdmin';

const AGORA = '2026-08-11T20:00:00.000Z';
const FUTURO = '2027-08-11T20:00:00.000Z';

let ambiente;

/** O documento como o Billing o grava. */
function entitlement(extra = {}) {
  return {
    uid: DONO,
    vipAtivo: true,
    estado: 'ativo',
    produtoId: 'master_vip_mensal',
    origem: 'play',
    inicioEm: '2026-08-01T20:00:00.000Z',
    expiraEm: FUTURO,
    renovacaoAutomatica: true,
    atualizadoEm: AGORA,
    esquema: 1,
    ...extra,
  };
}

before(async () => {
  ambiente = await initializeTestEnvironment({
    projectId: PROJETO,
    firestore: {
      rules: fs.readFileSync(path.resolve(__dirname, '..', 'firestore.rules'), 'utf8'),
    },
  });

  // Semeia como o backend semearia: com as regras desligadas, que e exatamente
  // o privilegio que o Admin SDK tem em producao.
  await ambiente.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();

    await setDoc(doc(db, `playerEntitlements/${DONO}`), entitlement());
    await setDoc(doc(db, `playerEntitlements/${DONO}/interno/billing`), {
      uid: DONO,
      purchaseToken: 'token-cru-que-ninguem-pode-ler',
      purchaseTokenHash: 'a'.repeat(64),
      produtoId: 'master_vip_mensal',
      assinatura: true,
      fonte: 'validacao',
      ultimaVerificacaoEm: AGORA,
      ultimoEventoEm: null,
      ultimoEventoTipo: null,
      esquema: 1,
    });

    await setDoc(doc(db, 'billingEvents/mensagem-1'), {
      messageId: 'mensagem-1',
      estado: 'concluido',
      aplicado: true,
      uid: DONO,
      token: 'aaaaaaaa',
    });
  });
});

after(async () => {
  if (ambiente) await ambiente.cleanup();
});

const comoDono = () => ambiente.authenticatedContext(DONO).firestore();
const comoOutro = () => ambiente.authenticatedContext(OUTRO).firestore();
const comoAdmin = () => ambiente.authenticatedContext(ADMIN, { admin: true }).firestore();
const semLogin = () => ambiente.unauthenticatedContext().firestore();

describe('ENT — leitura do entitlement', () => {
  test('ENT-01 o dono le o proprio estado de VIP', async () => {
    await assertSucceeds(getDoc(doc(comoDono(), `playerEntitlements/${DONO}`)));
  });

  test('ENT-02 outro jogador NAO le o entitlement alheio', async () => {
    // Sem isto, varrer a colecao daria o mapa de quem paga.
    await assertFails(getDoc(doc(comoOutro(), `playerEntitlements/${DONO}`)));
  });

  test('ENT-03 sem autenticacao ninguem le', async () => {
    await assertFails(getDoc(doc(semLogin(), `playerEntitlements/${DONO}`)));
  });

  test('ENT-04 admin le, para poder investigar', async () => {
    await assertSucceeds(getDoc(doc(comoAdmin(), `playerEntitlements/${DONO}`)));
  });
});

describe('ENT — escrita do entitlement (o portao do produto pago)', () => {
  test('ENT-05 o jogador NAO cria o proprio entitlement', async () => {
    await assertFails(
      setDoc(doc(comoOutro(), `playerEntitlements/${OUTRO}`), entitlement({ uid: OUTRO }))
    );
  });

  test('ENT-06 o jogador NAO se concede VIP no proprio documento', async () => {
    await assertFails(
      updateDoc(doc(comoDono(), `playerEntitlements/${DONO}`), { vipAtivo: true })
    );
  });

  test('ENT-07 o jogador NAO estende a propria expiracao', async () => {
    await assertFails(
      updateDoc(doc(comoDono(), `playerEntitlements/${DONO}`), {
        expiraEm: '2099-01-01T00:00:00.000Z',
      })
    );
  });

  test('ENT-08 o jogador NAO troca o estado nem desfaz uma revogacao', async () => {
    await assertFails(
      updateDoc(doc(comoDono(), `playerEntitlements/${DONO}`), { estado: 'ativo' })
    );
  });

  test('ENT-09 o jogador NAO troca o produto', async () => {
    await assertFails(
      updateDoc(doc(comoDono(), `playerEntitlements/${DONO}`), { produtoId: 'plano_eterno' })
    );
  });

  test('ENT-10 o jogador NAO apaga o proprio entitlement', async () => {
    // Apagar seria a maneira mais simples de sumir com uma revogacao.
    await assertFails(deleteDoc(doc(comoDono(), `playerEntitlements/${DONO}`)));
  });

  test('ENT-11 nem o ADMIN escreve pelo cliente', async () => {
    // Concessao administrativa, se um dia existir, e Cloud Function: assim ela
    // nasce auditada e passando pelo mesmo ciclo de vida.
    await assertFails(
      updateDoc(doc(comoAdmin(), `playerEntitlements/${DONO}`), { vipAtivo: true })
    );
    await assertFails(
      setDoc(doc(comoAdmin(), `playerEntitlements/${OUTRO}`), entitlement({ uid: OUTRO }))
    );
  });

  test('ENT-12 escrever em entitlement de terceiro tambem falha', async () => {
    await assertFails(
      setDoc(doc(comoOutro(), `playerEntitlements/${DONO}`), entitlement())
    );
  });
});

describe('ENT — o documento interno', () => {
  test('ENT-13 o purchaseToken nao vaza nem para o dono', async () => {
    await assertFails(
      getDoc(doc(comoDono(), `playerEntitlements/${DONO}/interno/billing`))
    );
  });

  test('ENT-14 nem para o admin', async () => {
    // Operar nao exige o token: a reconciliacao manual e Cloud Function.
    await assertFails(
      getDoc(doc(comoAdmin(), `playerEntitlements/${DONO}/interno/billing`))
    );
  });

  test('ENT-15 ninguem escreve no interno', async () => {
    await assertFails(
      setDoc(doc(comoDono(), `playerEntitlements/${DONO}/interno/billing`), {
        purchaseToken: 'meu-token-falso',
      })
    );
    await assertFails(
      setDoc(doc(comoOutro(), `playerEntitlements/${OUTRO}/interno/billing`), {
        purchaseToken: 'x',
      })
    );
  });

  test('ENT-16 ler o pai nao abre a subcolecao', async () => {
    // As regras nao sao hereditarias, mas isto e o tipo de coisa que se acredita
    // saber ate o dia em que se erra.
    await assertSucceeds(getDoc(doc(comoDono(), `playerEntitlements/${DONO}`)));
    await assertFails(
      getDoc(doc(comoDono(), `playerEntitlements/${DONO}/interno/billing`))
    );
  });
});

describe('ENT — trilha de notificacoes', () => {
  test('ENT-17 o jogador nao le a trilha de eventos', async () => {
    await assertFails(getDoc(doc(comoDono(), 'billingEvents/mensagem-1')));
  });

  test('ENT-18 o admin le, para investigar', async () => {
    await assertSucceeds(getDoc(doc(comoAdmin(), 'billingEvents/mensagem-1')));
  });

  test('ENT-19 ninguem cria evento: seria descartar um estorno como repetido', async () => {
    // A barreira de idempotencia do RTDN e o ID deste documento. Um cliente que
    // pudesse cria-lo faria o sistema ignorar a notificacao real quando ela
    // chegasse.
    await assertFails(
      setDoc(doc(comoDono(), 'billingEvents/mensagem-futura'), { estado: 'concluido' })
    );
    await assertFails(
      setDoc(doc(comoAdmin(), 'billingEvents/mensagem-futura'), { estado: 'concluido' })
    );
  });
});

describe('ENT — o legado nao virou porta dos fundos', () => {
  test('ENT-20 `usuarios/{uid}` continua barrando campos de servidor', async () => {
    // Regressao: o bloco de `usuarios/` nao foi tocado por esta OS, e o campo
    // `vip` de la deixou de ter consumidor. A regra continua valendo.
    await assertFails(
      setDoc(doc(comoOutro(), `usuarios/${OUTRO}`), { vip: true, apelido: 'eu' })
    );
    await assertFails(
      setDoc(doc(comoOutro(), `usuarios/${OUTRO}`), {
        vipExpiraEm: '2099-01-01T00:00:00.000Z',
      })
    );
  });

  test('ENT-21 `players/{uid}` continua sem existir, e negado', async () => {
    // A colecao fantasma que o consumidor lia. Nenhuma regra foi criada para
    // ela: o fecho padrao nega, e e assim que ela deve permanecer.
    await assertFails(getDoc(doc(comoDono(), `players/${DONO}`)));
    await assertFails(
      setDoc(doc(comoDono(), `players/${DONO}`), { assinaturaAtiva: true, suspenso: false })
    );
  });

  test('ENT-22 `playerModeration/{uid}` continua fechado para escrita', async () => {
    // Regressao da moderacao: o dono le o proprio efeito, mas nao o apaga.
    await assertFails(
      setDoc(doc(comoDono(), `playerModeration/${DONO}`), {
        userId: DONO,
        suspensaoPermanente: false,
        esquema: 1,
      })
    );
  });
});

describe('ENT — a porta do BACKEND continua aberta', () => {
  // A metade que faltava. Os testes acima provam que `allow write: if false`
  // fecha a porta do aplicativo; nenhum deles prova que ela nao fechou a porta
  // de quem PRECISA escrever. Uma regra que barra todo mundo, inclusive o
  // Billing, passaria em todos os `assertFails` acima e quebraria o produto —
  // e o sintoma seria "ninguem consegue ser VIP", descoberto em producao.
  //
  // `withSecurityRulesDisabled` e exatamente o privilegio que o Admin SDK tem:
  // as Cloud Functions de Billing ignoram estas regras. Provar isso aqui e o
  // que transforma "o cliente nao escreve" em "so o servidor escreve".

  test('ENT-23 o backend CRIA e ATUALIZA o entitlement', async () => {
    await ambiente.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();

      // Criacao — o caminho de `validarCompraPlay`.
      await assertSucceeds(
        setDoc(doc(db, 'playerEntitlements/uidNovoAssinante'),
          entitlement({ uid: 'uidNovoAssinante' }))
      );

      // Revogacao — o caminho da RTDN. E a operacao que o cliente jamais pode
      // fazer, e que o servidor precisa poder fazer a qualquer momento.
      await assertSucceeds(
        updateDoc(doc(db, 'playerEntitlements/uidNovoAssinante'), {
          vipAtivo: false,
          estado: 'revogado',
        })
      );
    });
  });

  test('ENT-24 o backend escreve o documento INTERNO que ninguem le', async () => {
    await ambiente.withSecurityRulesDisabled(async (ctx) => {
      await assertSucceeds(
        setDoc(
          doc(ctx.firestore(), 'playerEntitlements/uidNovoAssinante/interno/billing'),
          { uid: 'uidNovoAssinante', purchaseToken: 'token-cru', esquema: 1 }
        )
      );
    });

    // E continua ilegivel pelo dono — a separacao em dois documentos existe
    // porque regra do Firestore libera o DOCUMENTO INTEIRO.
    await assertFails(
      getDoc(doc(comoDono(), 'playerEntitlements/uidNovoAssinante/interno/billing'))
    );
  });

  test('ENT-25 o backend registra a trilha de notificacoes ja processadas', async () => {
    // A barreira de idempotencia do RTDN. Se as regras a fechassem para o
    // backend tambem, um estorno reprocessado seria descartado como repetido.
    await ambiente.withSecurityRulesDisabled(async (ctx) => {
      await assertSucceeds(
        setDoc(doc(ctx.firestore(), 'billingEvents/mensagem-2'), {
          messageId: 'mensagem-2',
          estado: 'concluido',
          aplicado: true,
        })
      );
    });
  });
});

describe('ENT — a vinculacao entre a conta e a compra da Google', () => {
  // BLOCO NOVO, da correcao P0 da propriedade da compra.
  //
  // Ate ela, a resposta para "de quem e esta compra?" era *de quem apresentou o
  // purchaseToken primeiro*: `compras/{hash}` nascia com o uid de quem chamasse,
  // antes de a Google ser consultada. Quem tivesse o token da vitima e chegasse
  // antes ficava com o VIP, e o pagante recebia `permission-denied` para sempre.
  //
  // A correcao amarrou a compra a conta por um identificador opaco, entregue a
  // Play como `obfuscatedAccountId` e devolvido pela Google na resposta
  // autoritativa. As duas pontas dessa amarra vivem nestas colecoes, e o que
  // este bloco prova e que NENHUM cliente as alcanca.
  //
  // Por que importa que nem o dono leia: o identificador nao concede nada
  // sozinho, mas poder le-lo permitiria correlacionar conta e compra de fora, e
  // poder escreve-lo permitiria apontar o vinculo de um jogador para a conta de
  // outro — que e exatamente a porta que acabou de ser fechada.

  const VINCULO = '11'.repeat(24);

  test('ENT-23 nem o dono le a propria vinculacao', async () => {
    await assertFails(getDoc(doc(comoDono(), `playerBillingIdentity/${DONO}`)));
    await assertFails(getDoc(doc(comoAdmin(), `playerBillingIdentity/${DONO}`)));
    await assertFails(getDoc(doc(semLogin(), `playerBillingIdentity/${DONO}`)));
  });

  test('ENT-24 ninguem escreve a propria vinculacao', async () => {
    // Escrever aqui seria escolher o identificador que a Google vai devolver —
    // ou seja, escolher de quem e a compra. E a Cloud Function
    // `prepararCompraPlay` que o gera, com a identidade ja verificada.
    await assertFails(
      setDoc(doc(comoDono(), `playerBillingIdentity/${DONO}`), {
        uid: DONO,
        contaOfuscada: VINCULO,
      })
    );
    await assertFails(
      setDoc(doc(comoAdmin(), `playerBillingIdentity/${DONO}`), {
        uid: DONO,
        contaOfuscada: VINCULO,
      })
    );
  });

  test('ENT-25 o indice reverso e fechado para leitura e para escrita', async () => {
    // Este e o documento que responde "qual conta e dona deste identificador?".
    // Poder escrever nele e poder redirecionar a compra de qualquer pessoa.
    await assertFails(getDoc(doc(comoDono(), `billingAccountIndex/${VINCULO}`)));
    await assertFails(getDoc(doc(comoAdmin(), `billingAccountIndex/${VINCULO}`)));
    await assertFails(
      setDoc(doc(comoDono(), `billingAccountIndex/${VINCULO}`), { uid: DONO })
    );
    await assertFails(
      setDoc(doc(comoOutro(), `billingAccountIndex/${VINCULO}`), { uid: OUTRO })
    );
  });

  test('ENT-26 nem apagar: remover o vinculo devolveria a compra ao primeiro que aparecesse', async () => {
    await ambiente.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await setDoc(doc(db, `playerBillingIdentity/${DONO}`), { uid: DONO, contaOfuscada: VINCULO });
      await setDoc(doc(db, `billingAccountIndex/${VINCULO}`), { uid: DONO, contaOfuscada: VINCULO });
    });

    await assertFails(deleteDoc(doc(comoDono(), `playerBillingIdentity/${DONO}`)));
    await assertFails(deleteDoc(doc(comoOutro(), `billingAccountIndex/${VINCULO}`)));
    await assertFails(
      updateDoc(doc(comoOutro(), `billingAccountIndex/${VINCULO}`), { uid: OUTRO })
    );
  });
});
