// seed_pioneiros_2026.js — publica catalogo e campanha no Firestore.
//
// Le os MESMOS arquivos que o aplicativo e os testes leem
// (app/data/colecoes/*.json), para que Firestore, bundle e suite de testes nunca
// contem historias diferentes.
//
// IDEMPOTENTE: roda quantas vezes for preciso. Usa ids deterministicos e
// `merge: true`, entao reexecutar atualiza em vez de duplicar.
//
// NAO ATIVA A CAMPANHA. O seed publica `status: draft` com visibilidade
// `hidden`, exatamente como esta no arquivo versionado. Ligar a campanha e
// decisao da Sonia e se faz editando o documento (ou pelo painel), sem novo
// build e sem rodar este script de novo.
//
// Uso:
//   cd firebase && node scripts/seed_pioneiros_2026.js --project <id> [--commit]
//
// Sem --commit, o script apenas IMPRIME o que faria (ensaio). A gravacao so
// acontece com a flag explicita.

const fs = require('fs');
const path = require('path');
// firebase-admin e carregado sob demanda, para que o ensaio (sem --commit) rode
// em qualquer maquina com Node, antes mesmo de instalar dependencias.

const RAIZ_DADOS = path.resolve(__dirname, '..', '..', 'app', 'data', 'colecoes');

function lerJson(nome) {
  return JSON.parse(fs.readFileSync(path.join(RAIZ_DADOS, nome), 'utf8'));
}

function argumento(nome) {
  const i = process.argv.indexOf(nome);
  return i >= 0 ? process.argv[i + 1] : null;
}

async function main() {
  const projectId = argumento('--project');
  const gravar = process.argv.includes('--commit');
  if (!projectId) {
    console.error('uso: node scripts/seed_pioneiros_2026.js --project <id> [--commit]');
    process.exit(1);
  }

  const catalogo = lerJson('catalogo.seed.json');
  const envelope = lerJson('campanha_pioneiros_2026.seed.json');
  const campanha = envelope.campanha;
  const manifesto = lerJson('pioneiros_2026.manifest.json');

  // Trava de integridade antes de qualquer gravacao: a campanha nao pode
  // prometer item que o catalogo nao tem, nem o catalogo apontar para arte fora
  // do manifesto. Descobrir isso aqui e barato; descobrir em producao, nao.
  const colecao = catalogo.colecoes.find((c) => c.collectionId === campanha.collectionId);
  if (!colecao) throw new Error(`catalogo sem a colecao ${campanha.collectionId}`);

  const noCatalogo = colecao.itens.map((i) => i.itemId).sort();
  const naCampanha = [...campanha.rewardIds].sort();
  if (JSON.stringify(noCatalogo) !== JSON.stringify(naCampanha)) {
    throw new Error('rewardIds da campanha divergem dos itens do catalogo');
  }

  const noManifesto = new Set(manifesto.items.map((i) => i.file));
  for (const item of colecao.itens) {
    const arquivo = item.assetPath.split('/').pop();
    if (!noManifesto.has(arquivo)) {
      throw new Error(`${item.itemId} aponta para arte fora do manifesto: ${arquivo}`);
    }
  }
  console.log(`integridade OK: ${colecao.itens.length} itens conferidos contra manifesto e campanha`);

  const documentos = [
    [`collections/${colecao.collectionId}`, {
      collectionId: colecao.collectionId,
      displayName: colecao.displayName,
      rarity: colecao.rarity,
      permanente: colecao.permanente,
      purchasable: false,
      transferable: false,
      tradable: false,
      revocable: false,
      visibleInStore: false,
      enabled: true,
    }],
    [`campaigns/${campanha.campaignId}`, campanha],
  ];

  for (const item of colecao.itens) {
    documentos.push([`collections/${colecao.collectionId}/items/${item.itemId}`, {
      ...item,
      purchasable: false,
      transferable: false,
      tradable: false,
      visibleInStore: false,
    }]);
  }

  // A feature flag nasce DESLIGADA: publicar o catalogo nao pode, sozinho,
  // fazer a campanha aparecer para ninguem.
  documentos.push(['config/featureFlags', { [campanha.featureFlag]: false }]);

  if (!gravar) {
    console.log('\n--- ENSAIO (sem --commit, nada sera gravado) ---');
    for (const [caminho] of documentos) console.log('  gravaria:', caminho);
    console.log(`\ntotal: ${documentos.length} documentos`);
    return;
  }

  const admin = require('firebase-admin');
  admin.initializeApp({ projectId });
  const db = admin.firestore();
  const batch = db.batch();
  for (const [caminho, dados] of documentos) {
    batch.set(db.doc(caminho), dados, { merge: true });
  }
  await batch.commit();

  console.log(`\n${documentos.length} documentos publicados em ${projectId}.`);
  console.log(`campanha em status "${campanha.status}" e flag "${campanha.featureFlag}" desligada.`);
  console.log('A ativacao e uma decisao separada, feita no documento da campanha.');
}

main().catch((e) => {
  console.error('FALHOU:', e.message);
  process.exit(1);
});
