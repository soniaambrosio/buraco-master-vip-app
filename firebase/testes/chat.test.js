// chat.test.js — prova as REGRAS do bloco de CHAT LIVRE (OS do Chat §4 e §13).
//
// O QUE ESTE ARQUIVO PROVA, e que nem o Dart nem o teste puro do TypeScript
// conseguem provar: quem LE e quem ESCREVE. O domínio decide se uma mensagem é
// válida; a regra decide se um jogador consegue GRAVAR uma mensagem sem passar
// pela autoridade, e se consegue LER o documento que carrega `autorUid` e
// `destinatarios`.
//
// A pergunta central deste arquivo é a da §4: "mensagem de chat não nasce como
// documento gravável pelo cliente". Isso não é uma afirmação sobre a Cloud
// Function — é uma afirmação sobre as REGRAS, e só aqui ela se prova. Se
// `chatMessages` aceitasse escrita de cliente, toda a porta única do domínio
// seria contornável com um `setDoc`, e nenhum teste de domínio notaria.
//
// Uso:
//   cd firebase/testes && npm install
//   npm run emulador-regras
//
// Numa máquina sem Java no PATH mas com Android Studio instalado:
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

const {
  doc, getDoc, setDoc, updateDoc, deleteDoc, collection, getDocs,
} = require('firebase/firestore');

const PROJETO = process.env.GCLOUD_PROJECT || 'buraco-master-vip-testes';

const AUTOR = 'uidAutorChat';
const COLEGA = 'uidColegaChat';
const PLATEIA = 'uidPlateiaChat';
const ESTRANHO = 'uidEstranhoChat';
const ADMIN = 'uidAdminChat';
const MOTOR = 'uidMotorPartidas';

const CANAL = 'sala7';
// Opaco de propósito: é o formato que o domínio deriva (sha256 truncado). Um id
// que carregasse o UID já seria vazamento antes de qualquer regra.
const MSG = 'd0d9544f7185ad8d945ce892865a471c';

let ambiente;

before(async () => {
  ambiente = await initializeTestEnvironment({
    projectId: PROJETO,
    firestore: {
      rules: fs.readFileSync(path.resolve(__dirname, '..', 'firestore.rules'), 'utf8'),
    },
  });

  // Semeia como a AUTORIDADE semearia: regras desligadas. É o ponto da coisa —
  // este é o único caminho por onde estes documentos nascem.
  await ambiente.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();

    await setDoc(doc(db, `chatChannels/${CANAL}`), {
      canalId: CANAL,
      superficie: 'mesa_de_partida',
      participantes: [
        { uid: AUTOR, papel: 'jogador_sentado' },
        { uid: COLEGA, papel: 'jogador_sentado' },
        { uid: PLATEIA, papel: 'espectador' },
      ],
      aberto: true,
      atualizadoEm: new Date().toISOString(),
      atualizadoPor: MOTOR,
      esquema: 1,
    });

    await setDoc(doc(db, `chatMessages/${MSG}`), {
      messageId: MSG,
      canalId: CANAL,
      superficie: 'mesa_de_partida',
      autorUid: AUTOR,
      autorPublicId: 'BMV-7K2M',
      conteudo: 'boa jogada',
      destinatarios: [COLEGA],
      enviadaEm: new Date().toISOString(),
      esquema: 1,
    });
  });
});

after(async () => {
  await ambiente.cleanup();
});

const comoAutor = () => ambiente.authenticatedContext(AUTOR).firestore();
const comoColega = () => ambiente.authenticatedContext(COLEGA).firestore();
const comoPlateia = () => ambiente.authenticatedContext(PLATEIA).firestore();
const comoEstranho = () => ambiente.authenticatedContext(ESTRANHO).firestore();
const comoAdmin = () =>
  ambiente.authenticatedContext(ADMIN, { admin: true }).firestore();
// Claim do motor de partidas: tem autoridade nas Functions, e NENHUMA nas regras.
const comoMotor = () =>
  ambiente.authenticatedContext(MOTOR, { motorDePartidas: true }).firestore();
const semLogin = () => ambiente.unauthenticatedContext().firestore();

// ===========================================================================
// CHAT-W — escrita de mensagem: NINGUÉM, por caminho nenhum
// ===========================================================================
describe('CHAT-W — mensagem não nasce do cliente', () => {
  test('CHAT-W-01 autor não cria a própria mensagem', async () => {
    // O caso que sustenta a porta única: se este `setDoc` passasse, o domínio
    // inteiro seria contornável — autor, horário, canal e conteúdo escolhidos por
    // quem escreve, sem consultar bloqueio nem sanção.
    await assertFails(
      setDoc(doc(comoAutor(), 'chatMessages/forjada1'), {
        messageId: 'forjada1',
        canalId: CANAL,
        superficie: 'mesa_de_partida',
        autorUid: AUTOR,
        autorPublicId: 'BMV-7K2M',
        conteudo: 'gravei sozinho',
        destinatarios: [COLEGA],
        enviadaEm: new Date().toISOString(),
        esquema: 1,
      })
    );
  });

  test('CHAT-W-02 ninguém grava mensagem em nome de outro', async () => {
    await assertFails(
      setDoc(doc(comoEstranho(), 'chatMessages/forjada2'), {
        messageId: 'forjada2',
        canalId: CANAL,
        autorUid: AUTOR,
        conteudo: 'isto seria falsificação de remetente',
      })
    );
  });

  test('CHAT-W-03 anônimo não grava', async () => {
    await assertFails(
      setDoc(doc(semLogin(), 'chatMessages/forjada3'), { conteudo: 'oi' })
    );
  });

  test('CHAT-W-04 nem admin nem motor gravam pelo cliente', async () => {
    // Mesma disciplina de `reports` e `moderationAudit`: quem grava é a Function,
    // com o instante do servidor e o autor tirado do contexto autenticado. Uma
    // porta de admin aqui seria uma porta de mensagem datada à mão.
    await assertFails(
      setDoc(doc(comoAdmin(), 'chatMessages/forjada4'), { conteudo: 'oi' })
    );
    await assertFails(
      setDoc(doc(comoMotor(), 'chatMessages/forjada5'), { conteudo: 'oi' })
    );
  });

  test('CHAT-W-05 ninguém edita nem apaga mensagem existente', async () => {
    // Apagar seria apagar a evidência de uma denúncia (§12); editar seria trocar
    // o que a moderação vai ler pelo que o autor gostaria de ter escrito.
    await assertFails(
      updateDoc(doc(comoAutor(), `chatMessages/${MSG}`), { conteudo: 'mudei' })
    );
    await assertFails(deleteDoc(doc(comoAutor(), `chatMessages/${MSG}`)));
    await assertFails(deleteDoc(doc(comoAdmin(), `chatMessages/${MSG}`)));
  });
});

// ===========================================================================
// CHAT-R — leitura de mensagem: nem os participantes
// ===========================================================================
describe('CHAT-R — o documento não é a entrega', () => {
  test('CHAT-R-01 o autor não lê o próprio documento', async () => {
    // Parece severo, e é deliberado: o documento carrega `destinatarios`, que diz
    // quem NÃO recebeu — o mesmo que publicar quem bloqueou quem. A entrega ao
    // jogador é a PROJEÇÃO, montada por `projetarMensagem`.
    await assertFails(getDoc(doc(comoAutor(), `chatMessages/${MSG}`)));
  });

  test('CHAT-R-02 o destinatário não lê o documento', async () => {
    await assertFails(getDoc(doc(comoColega(), `chatMessages/${MSG}`)));
  });

  test('CHAT-R-03 espectador não lê mensagem de jogador', async () => {
    // §11: não basta impedir o espectador de falar; ele também não recebe.
    await assertFails(getDoc(doc(comoPlateia(), `chatMessages/${MSG}`)));
  });

  test('CHAT-R-04 estranho e anônimo não leem', async () => {
    await assertFails(getDoc(doc(comoEstranho(), `chatMessages/${MSG}`)));
    await assertFails(getDoc(doc(semLogin(), `chatMessages/${MSG}`)));
  });

  test('CHAT-R-05 a coleção não é varrível', async () => {
    // `get` negado e `list` liberado deixaria alguém baixar a mesa inteira sem
    // conhecer um único id. Foi exatamente o defeito de `publicProfiles`.
    await assertFails(getDocs(collection(comoAutor(), 'chatMessages')));
    await assertFails(getDocs(collection(comoColega(), 'chatMessages')));
    await assertFails(getDocs(collection(comoEstranho(), 'chatMessages')));
  });

  test('CHAT-R-06 admin lê, porque é quem julga denúncia', async () => {
    // A evidência de uma mensagem denunciada é lida daqui (§12). Sem esta
    // permissão, a denúncia de mensagem voltaria a depender do que o aparelho de
    // quem denuncia afirma.
    await assertSucceeds(getDoc(doc(comoAdmin(), `chatMessages/${MSG}`)));
  });
});

// ===========================================================================
// CHAT-C — canal: quem declara quem está sentado
// ===========================================================================
describe('CHAT-C — canal', () => {
  test('CHAT-C-01 jogador não cria canal', async () => {
    // Se criasse, escolheria quem está sentado — e o filtro de bloqueio da §7
    // passaria a depender de uma lista escrita pelo próprio remetente. O caso
    // concreto: declarar-se sozinho na mesa para escapar do filtro.
    await assertFails(
      setDoc(doc(comoAutor(), 'chatChannels/salaInventada'), {
        canalId: 'salaInventada',
        superficie: 'mesa_de_partida',
        participantes: [{ uid: AUTOR, papel: 'jogador_sentado' }],
        aberto: true,
      })
    );
  });

  test('CHAT-C-02 jogador não se acrescenta a canal existente', async () => {
    await assertFails(
      updateDoc(doc(comoEstranho(), `chatChannels/${CANAL}`), {
        participantes: [{ uid: ESTRANHO, papel: 'jogador_sentado' }],
      })
    );
  });

  test('CHAT-C-03 espectador não se promove a sentado', async () => {
    // A promoção de papel é a forma mais direta de ganhar direito de fala.
    await assertFails(
      updateDoc(doc(comoPlateia(), `chatChannels/${CANAL}`), {
        participantes: [{ uid: PLATEIA, papel: 'jogador_sentado' }],
      })
    );
  });

  test('CHAT-C-04 nem o motor escreve canal pelo cliente', async () => {
    // O claim `motorDePartidas` tem autoridade na CHAMADA (`definirCanalDeChat`),
    // e nenhuma na regra. A diferença importa: pela Function, a superfície é
    // conferida contra a classificação da §11 e os ids são validados; por um
    // `setDoc` cru, nada disso aconteceria.
    await assertFails(
      setDoc(doc(comoMotor(), 'chatChannels/salaDoMotor'), {
        canalId: 'salaDoMotor',
        superficie: 'saguao_publico',
        participantes: [],
        aberto: true,
      })
    );
  });

  test('CHAT-C-05 jogador não lê o canal: participantes são UIDs', async () => {
    await assertFails(getDoc(doc(comoAutor(), `chatChannels/${CANAL}`)));
    await assertFails(getDoc(doc(comoColega(), `chatChannels/${CANAL}`)));
    await assertFails(getDocs(collection(comoAutor(), 'chatChannels')));
  });

  test('CHAT-C-06 admin lê o canal', async () => {
    await assertSucceeds(getDoc(doc(comoAdmin(), `chatChannels/${CANAL}`)));
  });

  test('CHAT-C-07 ninguém fecha o canal pelo cliente', async () => {
    // Fechar o canal alheio silenciaria a mesa inteira; reabrir um canal fechado
    // deixaria falar numa partida encerrada.
    await assertFails(
      updateDoc(doc(comoAutor(), `chatChannels/${CANAL}`), { aberto: false })
    );
    await assertFails(
      updateDoc(doc(comoEstranho(), `chatChannels/${CANAL}`), { aberto: true })
    );
  });
});

// ===========================================================================
// CHAT-V — o bloco novo não afrouxou o vizinho
// ===========================================================================
describe('CHAT-V — vizinhança', () => {
  test('CHAT-V-01 bloqueio continua sendo escrita fechada', async () => {
    // O chat CONSOME `users/{uid}/blocks`. Um bloco novo que afrouxasse a
    // gravação de bloqueio deixaria o jogador editar a própria lista — e o filtro
    // da §7 passaria a consultar dado que ele controla.
    await assertFails(
      setDoc(doc(comoAutor(), `users/${AUTOR}/blocks/${COLEGA}`), {
        bloqueadorUid: AUTOR,
        bloqueadoUid: COLEGA,
        criadoEm: new Date(),
        esquema: 1,
      })
    );
  });

  test('CHAT-V-02 playerModeration continua fechado para escrita', async () => {
    // O ponto exato onde morre "apagar a própria punição" — e, com o chat, também
    // "destravar o próprio silenciamento".
    await assertFails(
      setDoc(doc(comoAutor(), `playerModeration/${AUTOR}`), {
        userId: AUTOR,
        chatSilenciadoAte: null,
        suspensaoPermanente: false,
      })
    );
  });

  test('CHAT-V-03 o dono continua lendo o próprio estado disciplinar', async () => {
    // A tela precisa poder dizer "você está silenciado até tal hora" em vez de
    // falhar sem explicação. O bloco de chat não pode ter fechado isto.
    await assertSucceeds(getDoc(doc(comoAutor(), `playerModeration/${AUTOR}`)));
  });
});
