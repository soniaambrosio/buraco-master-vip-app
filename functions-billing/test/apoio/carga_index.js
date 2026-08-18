/**
 * carga_index.js — carrega `index.js` DE VERDADE, com as portas trocadas.
 *
 * O PROBLEMA QUE ISTO RESOLVE
 *
 * `entitlementStore.js`, `reconciliacao.js` e `rtdn.js` recebem as dependencias
 * por parametro, e por isso a suite historica os alcanca. `index.js` NAO: ele e o
 * adaptador, e e ele quem chama `getFirestore()`, `google.androidpublisher()` e
 * `defineSecret(...).value()` direto. Consequencia pratica: o catalogo de
 * produtos, o credito de fichas, a ordem "creditar antes de consumir", as duas
 * varreduras administrativas e a redacao dos logs DAQUELE arquivo ficavam fora de
 * qualquer teste local — justamente os casos A, N, O, V e W da matriz.
 *
 * A SAIDA, SEM TOCAR EM CODIGO DE PRODUCAO
 *
 * As tres dependencias externas sao plantadas no `require.cache` ANTES de
 * `index.js` ser carregado. Quando ele faz `require('firebase-admin/firestore')`,
 * o Node devolve o objeto que este arquivo colocou la. Nenhuma linha de
 * `index.js` muda; o que muda e o que existe do outro lado do `require`.
 *
 * NADA AQUI ALCANCA A REDE, E ISSO E VERIFICAVEL
 *
 *   googleapis            substituido por inteiro — `google.auth.GoogleAuth` e um
 *                         objeto inerte e `androidpublisher()` devolve a Play
 *                         falsa. Nenhum socket, nenhum OAuth, nenhum token real.
 *   firebase-admin/app    `initializeApp` vira no-op.
 *   firebase-admin/firestore  `getFirestore()` devolve o Firestore falso.
 *
 * `firebase-functions` continua sendo o PACOTE REAL: e ele que define o formato
 * de `onCall`/`onMessagePublished`/`onSchedule` e o `.run()` que os testes usam
 * para entrar no handler. Trocar isso por uma imitacao faria a homologacao provar
 * o proprio dublê em vez do contrato da plataforma.
 *
 * O SEGREDO E SINTETICO E INUTIL. `PLAY_SERVICE_ACCOUNT_JSON` recebe um JSON com
 * dominio `.invalid` e sem chave — ele existe so porque `androidPublisher()` faz
 * `JSON.parse` antes de montar o cliente, e o cliente montado e o falso. Nenhum
 * segredo real e lido, e nenhum arquivo de credencial e procurado.
 */

'use strict';

const path = require('node:path');

const {
  FirestoreAdversarial,
  FieldValueFalso,
  FieldPathFalso,
} = require('./firestore_adversarial');
const { criarPlayFalsa } = require('./play_falsa');

const CAMINHO_INDEX = require.resolve('../../index.js');

/**
 * Conta de servico SINTETICA. Dominio `.invalid` e reservado por RFC 2606 e nunca
 * resolve; a "chave" e uma frase. Nada disto autentica em lugar nenhum.
 */
const SEGREDO_SINTETICO = JSON.stringify({
  type: 'service_account',
  project_id: 'projeto-de-homologacao-local',
  client_email: 'conta-de-servico-sintetica@exemplo.invalid',
  private_key: 'ISTO-NAO-E-UMA-CHAVE-PRIVADA',
});

/** O que `getFirestore()` deve devolver na proxima carga. Trocado por cenario. */
const estado = { db: null, play: null };

function plantar(especificador, exportacoes) {
  const alvo = require.resolve(especificador);
  require.cache[alvo] = {
    id: alvo,
    filename: alvo,
    path: path.dirname(alvo),
    loaded: true,
    exports: exportacoes,
    children: [],
    paths: [],
  };
}

let plantado = false;

function plantarPortas() {
  if (plantado) return;

  plantar('firebase-admin/app', { initializeApp: () => ({ name: '[DEFAULT]' }) });

  plantar('firebase-admin/firestore', {
    getFirestore: () => {
      if (!estado.db) throw new Error('carga_index: nenhum Firestore falso ativo');
      return estado.db;
    },
    FieldValue: FieldValueFalso,
    FieldPath: FieldPathFalso,
  });

  plantar('googleapis', {
    google: {
      auth: {
        // Inerte de proposito: se algum dia alguem trocar isto por algo que
        // resolve credencial, o teste passa a depender de ambiente e para de ser
        // prova. Guardar as opcoes permite conferir o escopo pedido.
        GoogleAuth: class GoogleAuthFalso {
          constructor(opcoes) {
            this.opcoes = opcoes;
          }
        },
      },
      androidpublisher() {
        const play = estado.play;
        if (!play) throw new Error('carga_index: nenhuma Play falsa ativa');
        return {
          purchases: {
            subscriptionsv2: {
              async get({ packageName, token }) {
                return { data: await play.consultarAssinatura(token, { packageName }) };
              },
            },
            products: {
              async get({ productId, token }) {
                return { data: await play.consultarProduto(productId, token) };
              },
              async consume({ productId, token }) {
                return play.consumir(productId, token);
              },
            },
            subscriptions: {
              async acknowledge({ subscriptionId, token }) {
                return play.reconhecer(subscriptionId, token);
              },
            },
          },
        };
      },
    },
  });

  plantado = true;
}

/**
 * Um cenario novo: Firestore falso vazio, Play falsa vazia e `index.js`
 * RECARREGADO.
 *
 * A recarga nao e detalhe: `index.js` guarda `clientePlay` e `infra` em
 * variaveis de modulo, montadas uma unica vez sob demanda. Sem descartar o
 * modulo, o segundo cenario continuaria escrevendo no Firestore do primeiro — e
 * um teste de idempotencia contaminado por outro teste nao prova coisa alguma.
 */
function carregarIndex({ maxTentativas } = {}) {
  plantarPortas();

  process.env.PLAY_SERVICE_ACCOUNT_JSON = SEGREDO_SINTETICO;
  if (!process.env.GCLOUD_PROJECT) process.env.GCLOUD_PROJECT = 'projeto-de-homologacao-local';

  const db = new FirestoreAdversarial({ maxTentativas });
  const play = criarPlayFalsa();
  estado.db = db;
  estado.play = play;

  delete require.cache[CAMINHO_INDEX];
  const modulo = require(CAMINHO_INDEX);

  return { modulo, db, play };
}

module.exports = { carregarIndex, SEGREDO_SINTETICO, CAMINHO_INDEX };
