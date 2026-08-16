#!/usr/bin/env node
/**
 * auditar-identidade.js — RUNNER DRY-RUN da auditoria de identidade publica.
 *
 * OS de integracao Identidade Publica x Ranking v1, secao 15.
 *
 * ESTE ARQUIVO SO LE. Nao ha, em nenhuma linha abaixo, `set`, `update`,
 * `create`, `delete`, `add` ou `commit`. A conferencia em si mora em
 * `lib/auditoria.js`, que e um modulo puro sem acesso ao banco; aqui so se
 * monta o inventario e se imprime o resultado.
 *
 * A garantia nao depende de boa vontade: `test/auditoria.test.js` le ESTE
 * arquivo e falha se um verbo de escrita aparecer nele.
 *
 * COMO RODAR — contra o EMULADOR (o caminho normal):
 *
 *   FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 \
 *   GCLOUD_PROJECT=demo-bmv \
 *   node scripts/auditar-identidade.js
 *
 * CONTRA PRODUCAO: o script recusa a rodar sem `--eu-sei-que-e-producao`, e
 * mesmo assim continua sendo read-only. A trava existe porque um `getAll` sobre
 * a base inteira e caro, e nao porque ele seja perigoso.
 *
 * SAIDA: texto no stdout e codigo de saida 0 SEMPRE que a auditoria conseguiu
 * rodar — inclusive com achados. Achado nao e falha do script; e informacao. Um
 * exit code diferente de zero aqui faria a auditoria parecer quebrada num CI
 * justamente quando ela esta funcionando. Use `--falhar-se-critico` para o
 * comportamento oposto, quando ela for portao.
 */

'use strict';

const { initializeApp, applicationDefault } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');

const { auditar, relatorioComoTexto } = require('../lib/auditoria');

const C_IDENTIDADES = 'playerIdentities';
const C_INDICE_PUBLICO = 'publicIdIndex';
const C_PERFIS_PUBLICOS = 'publicProfiles';
const C_USUARIOS = 'users';
const C_RANKING_PLAYERS = 'rankingPlayers';
const C_RANKING_STANDINGS = 'rankingStandings';

/// A chave de `rankingStandings` e `seasonId|uid`. Quando o documento nao traz
/// `uid` no corpo (dado antigo), o id ainda diz de quem ele e.
function uidDoStanding(documentoId, corpo) {
  if (typeof corpo.uid === 'string' && corpo.uid.length > 0) return corpo.uid;
  const barra = documentoId.indexOf('|');
  return barra > 0 ? documentoId.slice(barra + 1) : null;
}

async function coletar() {
  const db = getFirestore();

  const [identidades, reversos, perfis, usuarios, players, standings] =
    await Promise.all([
      db.collection(C_IDENTIDADES).get(),
      db.collection(C_INDICE_PUBLICO).get(),
      db.collection(C_PERFIS_PUBLICOS).get(),
      db.collection(C_USUARIOS).get(),
      db.collection(C_RANKING_PLAYERS).get(),
      db.collection(C_RANKING_STANDINGS).get(),
    ]);

  const projecoes = [];
  for (const d of players.docs) {
    const dado = d.data();
    projecoes.push({
      colecao: C_RANKING_PLAYERS,
      documentoId: d.id,
      uid: typeof dado.uid === 'string' && dado.uid.length > 0 ? dado.uid : d.id,
      publicPlayerId:
        typeof dado.publicPlayerId === 'string' ? dado.publicPlayerId : null,
    });
  }
  for (const d of standings.docs) {
    const dado = d.data();
    projecoes.push({
      colecao: C_RANKING_STANDINGS,
      documentoId: d.id,
      uid: uidDoStanding(d.id, dado),
      publicPlayerId:
        typeof dado.publicPlayerId === 'string' ? dado.publicPlayerId : null,
    });
  }

  return {
    identidades: identidades.docs.map((d) => ({
      uid: d.id,
      publicId: typeof d.data().publicId === 'string' ? d.data().publicId : null,
    })),
    reversos: reversos.docs.map((d) => ({
      publicId: d.id,
      uid: typeof d.data().uid === 'string' ? d.data().uid : null,
    })),
    perfis: perfis.docs.map((d) => ({ publicId: d.id })),
    projecoes,
    uidsConhecidos: usuarios.docs.map((d) => d.id),
  };
}

async function principal() {
  const args = process.argv.slice(2);
  const noEmulador = typeof process.env.FIRESTORE_EMULATOR_HOST === 'string';
  const autorizadoEmProducao = args.includes('--eu-sei-que-e-producao');

  if (!noEmulador && !autorizadoEmProducao) {
    console.error(
      'RECUSADO: FIRESTORE_EMULATOR_HOST nao esta definido.\n' +
        'Esta auditoria e read-only, mas varre colecoes inteiras. Para rodar\n' +
        'contra um projeto real, passe --eu-sei-que-e-producao.'
    );
    process.exitCode = 2;
    return;
  }

  initializeApp(noEmulador ? {} : { credential: applicationDefault() });

  const relatorio = auditar(await coletar());
  console.log(relatorioComoTexto(relatorio));

  if (args.includes('--json')) {
    console.log('\n--- JSON ---');
    console.log(JSON.stringify(relatorio, null, 2));
  }

  if (args.includes('--falhar-se-critico') && relatorio.criticos > 0) {
    process.exitCode = 1;
  }
}

principal().catch((erro) => {
  console.error('a auditoria nao conseguiu rodar:', erro);
  process.exitCode = 3;
});
