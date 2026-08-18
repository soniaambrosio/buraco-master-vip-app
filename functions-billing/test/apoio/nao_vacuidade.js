/**
 * nao_vacuidade.js — o teste do teste.
 *
 * O PROBLEMA QUE ISTO RESOLVE
 *
 * Um teste verde prova uma de duas coisas: que a protecao funciona, ou que o
 * teste nunca chegou perto dela. As duas sao indistinguiveis pela suite. Um
 * laudo que diga "idempotencia provada" sem separar as duas nao vale nada — e o
 * modo mais comum de uma homologacao mentir sem que ninguem tenha mentido.
 *
 * COMO ISTO SEPARA AS DUAS
 *
 * Para cada risco critico, uma protecao de PRODUCAO e neutralizada numa copia
 * temporaria do arquivo, os testes correspondentes rodam, e o esperado e que
 * fiquem VERMELHOS. Se ficarem verdes com a protecao desligada, o teste nao
 * estava provando aquilo, e o laudo tem de dizer isso.
 *
 * REGRAS DESTA FERRAMENTA
 *
 *   - a arvore precisa estar LIMPA antes de comecar, e volta limpa no fim,
 *     inclusive se algo explodir no meio (o restauro esta em `finally`);
 *   - nenhuma mutacao e commitada — o que fica versionado e a DESCRICAO dela,
 *     que e o que torna a prova reproduzivel;
 *   - se o restauro falhar, o processo termina com codigo 2 e grita, porque uma
 *     arvore com codigo de producao mutilado e pior do que nenhuma prova.
 *
 * USO
 *   node test/apoio/nao_vacuidade.js          (ou `npm run prova:nao-vacuidade`)
 */

'use strict';

const fs = require('node:fs');
const path = require('node:path');
const { execFileSync, spawnSync } = require('node:child_process');

const RAIZ = path.resolve(__dirname, '..', '..');

/** Quebra de linha, montada assim para nao existir escape dentro das ancoras. */
const NOVA_LINHA = String.fromCharCode(10);
const CRLF = String.fromCharCode(13) + NOVA_LINHA;

/**
 * Onde mora o arquivo de uma edicao.
 *
 * As provas do backend citam caminhos do codebase (`index.js`); as do cliente
 * citam caminhos do REPOSITORIO (`app/lib/...`), porque o aplicativo nao esta
 * dentro de functions-billing. Resolver os dois com a mesma raiz procuraria o
 * Dart dentro do backend — que foi exatamente o que aconteceu na primeira
 * tentativa.
 */
function caminhoDe(arquivo) {
  return arquivo.startsWith('app/')
    ? path.resolve(RAIZ, '..', arquivo)
    : path.join(RAIZ, arquivo);
}

/**
 * Cada prova nomeia: o risco, o arquivo de producao, o trecho que implementa a
 * protecao, o trecho que a desliga, e os testes que TEM de ficar vermelhos.
 *
 * O `de`/`para` e substituicao literal e unica: se o trecho nao existir mais,
 * a prova falha com "ancora nao encontrada" em vez de passar por engano.
 */
const PROVAS = [
  {
    caso: 'B',
    risco: 'reentrega do mesmo messageId gasta consulta a Google de novo',
    arquivo: 'rtdn.js',
    protecao: 'atalho `eventoConcluido` antes de gastar chamada de rede',
    de: 'if (await store.eventoConcluido(messageId)) {',
    para: 'if (false && await store.eventoConcluido(messageId)) {',
    testes: ['^B '],
  },
  {
    caso: 'B',
    risco: 'reentrega do mesmo messageId aplica o efeito duas vezes',
    arquivo: 'entitlementStore.js',
    protecao: 'barreira de idempotencia DENTRO da transacao',
    de: "if (ev && ev.exists && ev.data().estado === 'concluido') {",
    para: "if (false && ev && ev.exists && ev.data().estado === 'concluido') {",
    // B sozinho NAO serve de prova aqui: com esta barreira desligada ele ainda
    // passa, porque o atalho de `rtdn.js` responde antes de a transacao ser
    // alcancada. B2 e o cenario em que a barreira e a unica defesa — duas
    // entregas do mesmo messageId em voo, com carimbos de consulta diferentes,
    // que escapam tanto do atalho quanto da regra de ordem.
    testes: ['^B2 '],
  },
  {
    caso: 'C',
    risco: 'reempacotar o mesmo estorno com outro messageId o aplica de novo',
    arquivo: 'entitlement.js',
    protecao: 'desfecho terminal repetido e convergente, sem efeito novo',
    de: "return { aplicar: false, motivo: 'terminal_repetido' };",
    para: "return { aplicar: true, motivo: 'terminal_repetido' };",
    testes: ['^C '],
  },
  {
    caso: 'D',
    risco: 'evento antigo regride o estado',
    arquivo: 'entitlement.js',
    protecao: 'regra de ORDEM pelo carimbo da consulta autoritativa',
    de: "return { aplicar: false, motivo: 'verificacao_antiga' };",
    para: "return { aplicar: true, motivo: 'verificacao_antiga' };",
    testes: ['^D ', '^D2 '],
  },
  {
    caso: 'P',
    risco: 'falha da Play vira decisao em vez de reentrega',
    arquivo: 'reconciliacao.js',
    protecao: 'a excecao SOBE, para o Pub/Sub reentregar',
    de: 'const resposta = await consultarAssinatura(tokenCompra);',
    para:
      'let resposta; try { resposta = await consultarAssinatura(tokenCompra); } '
      + 'catch (e) { resposta = {}; }',
    testes: ['^P ', '^P2 '],
  },
  {
    caso: 'Q',
    risco: 'duas execucoes simultaneas decidem sobre um estado velho',
    arquivo: 'entitlementStore.js',
    protecao: 'o documento e RELIDO DENTRO da transacao',
    de: `    return db.runTransaction(async (tx) => {
      const [pub, int, ev] = await Promise.all([
        tx.get(publico),
        tx.get(interno),
        refEvento ? tx.get(refEvento) : Promise.resolve(null),
      ]);`,
    para: `    const [pubFora, intFora, evFora] = await Promise.all([
      publico.get(),
      interno.get(),
      refEvento ? refEvento.get() : Promise.resolve(null),
    ]);
    return db.runTransaction(async (tx) => {
      const [pub, int, ev] = [pubFora, intFora, evFora];`,
    testes: ['^Q ', '^U2 '],
  },
  {
    caso: 'R',
    risco: 'registro de compra residual com dono divergente devolve concessao alheia',
    arquivo: 'idempotencia.js',
    protecao: 'conferencia de titularidade antes do estado',
    de: 'if (registro.uid !== ctx.uid) {',
    para: 'if (false && registro.uid !== ctx.uid) {',
    // REPONTADA na correcao P0, e a mudanca vale registro. Com `^R ` esta prova
    // ficou VACUA: a conferencia de propriedade (passo 6 de `validarCompraPlay`)
    // recusa o invasor ANTES de a transacao ser alcancada, entao desligar este
    // guarda nao quebra mais o caso R. Ele deixou de ser a defesa primaria e
    // virou defesa em profundidade — e o unico cenario que ainda depende dele e
    // um `compras/{hash}` residual do regime antigo, que Y13 encena.
    testes: ['^Y13 '],
  },
  {
    caso: 'S',
    risco: 'identificador de compra vaza inteiro para log e trilha',
    arquivo: 'entitlement.js',
    protecao: 'rotulo de oito caracteres em vez do hash',
    de: 'return hash.slice(0, 8);',
    para: 'return hash;',
    testes: ['^S '],
  },
  {
    caso: 'U',
    risco: 'RTDN e reconciliacao em ordens opostas terminam diferente',
    arquivo: 'entitlement.js',
    protecao: 'regra de ORDEM pelo carimbo da consulta autoritativa',
    de: "return { aplicar: false, motivo: 'verificacao_antiga' };",
    para: "return { aplicar: true, motivo: 'verificacao_antiga' };",
    testes: ['^U '],
  },
  {
    caso: 'W',
    risco: 'falha no commit deixa entitlement gravado e trilha ausente',
    arquivo: 'entitlementStore.js',
    protecao: 'as escritas do entitlement sao BUFFERIZADAS na transacao',
    de: `        tx.set(publico, docs.publico);
        tx.set(interno, docs.interno);`,
    para: `        await publico.set(docs.publico);
        await interno.set(docs.interno);`,
    testes: ['^W ', '^W2 '],
  },
  // =========================================================================
  // AS DOZE PROVAS NEGATIVAS DA CORRECAO DE PROPRIEDADE (secao 14 da OS)
  // =========================================================================
  //
  // Cada uma reintroduz, em codigo de PRODUCAO, a decisao errada que a correcao
  // desfez, e exige que um teste COMPORTAMENTAL a mate. A ordem e a da OS.
  {
    caso: 'N1',
    risco: 'voltar a gravar a compra ANTES da consulta a Google',
    arquivo: 'index.js',
    protecao: 'nenhuma persistencia antes da confirmacao autoritativa',
    de: '    const consultadoEm = new Date().toISOString();',
    para: [
      '    await refCompra.set({ uid, produtoId, estado: ESTADO.EM_VALIDACAO }, { merge: true });',
      '    const consultadoEm = new Date().toISOString();',
    ].join(NOVA_LINHA),
    testes: ['^R6 ', '^P3 ', '^Y10 '],
  },
  {
    caso: 'N2',
    risco: 'ignorar o identificador que a Google devolve na raiz da resposta',
    arquivo: 'propriedade.js',
    protecao: 'leitura do obfuscatedExternalAccountId nos DOIS formatos',
    de: '  const raiz = resposta.obfuscatedExternalAccountId;',
    para: '  const raiz = undefined;',
    testes: ['^Y11 '],
  },
  {
    caso: 'N3',
    risco: 'confiar no uid de quem chamou quando o vinculo nao resolve',
    arquivo: 'propriedade.js',
    protecao: 'vinculo desconhecido falha fechado, mesmo com sessao valida',
    de: '    return { ok: false, motivo: MOTIVO.VINCULO_DESCONHECIDO };',
    para: '    return uidEsperado ? { ok: true, uid: uidEsperado } : { ok: false, motivo: MOTIVO.VINCULO_DESCONHECIDO };',
    // `^R4 ` nao serve: la nao ha sessao, entao a deducao "e de quem chamou" nao
    // tem de quem deduzir. Y14 e o caso do meio, e foi escrito porque ESTA prova
    // negativa mostrou que ele faltava na matriz.
    testes: ['^Y14 '],
  },
  {
    caso: 'N4',
    risco: 'deixar o cliente escolher a propria vinculacao',
    arquivo: 'index.js',
    protecao: 'o identificador e gerado no servidor; o payload nao e lido',
    de: '    const { contaOfuscada, criado } = await dependencias().store.garantirVinculo(uid);',
    para: [
      '    const escolhido = request.data && request.data.contaOfuscada;',
      '    const { contaOfuscada, criado } = escolhido',
      '      ? { contaOfuscada: escolhido, criado: false }',
      '      : await dependencias().store.garantirVinculo(uid);',
    ].join(NOVA_LINHA),
    testes: ['^Y4 '],
  },
  {
    caso: 'N5',
    risco: 'aceitar compra sem vinculacao nenhuma',
    arquivo: 'propriedade.js',
    protecao: 'identificador ausente ou mal formado e recusa',
    de: '  if (!vinculoBemFormado(identificador)) {',
    para: '  if (false && !vinculoBemFormado(identificador)) {',
    testes: ['^Y10 ', '^V '],
  },
  {
    caso: 'N6',
    risco: 'tornar packageName opcional de novo',
    arquivo: 'entitlement.js',
    protecao: 'a mensagem tem de DIZER de qual pacote veio',
    de: '  if (corpo.packageName !== pacote) {',
    para: '  if (corpo.packageName && corpo.packageName !== pacote) {',
    testes: ['^X3 '],
  },
  {
    caso: 'N7',
    risco: 'aceitar notificacao de pacote divergente',
    arquivo: 'entitlement.js',
    protecao: 'so o applicationId oficial passa',
    de: "    return { acao: 'ignorar', motivo: MOTIVO.PACOTE_DIVERGENTE };",
    para: "    return { acao: 'reconciliar', motivo: MOTIVO.PACOTE_DIVERGENTE };",
    testes: ['^X3 '],
  },
  {
    caso: 'N8',
    risco: 'ignorar item malformado dentro de lineItems',
    arquivo: 'propriedade.js',
    protecao: 'a resposta inteira e recusada antes da consolidacao',
    de: '  for (let i = 0; i < itens.length; i += 1) {',
    para: '  for (let i = 0; i < 0; i += 1) {',
    testes: ['^O2b '],
  },
  {
    caso: 'N9',
    risco: 'persistir a mensagem de erro de terceiro',
    arquivo: 'index.js',
    protecao: 'so codigo fechado sai do fechamento junto a Google',
    de: '    return { ok: false, motivo: MOTIVO.FALHA_TEMPORARIA_PLAY };',
    para: '    return { ok: false, motivo: e && e.message };',
    testes: ['^Z1 '],
  },
  {
    caso: 'N10',
    risco: 'expor o token bruto em log',
    arquivo: 'rtdn.js',
    protecao: 'rotulo curto do hash, nunca o token',
    de: [
      "    registro.warn('[billing] RTDN sem propriedade comprovavel', {",
      '      messageId,',
      '      motivo,',
      '      token: rotuloToken(hash),',
    ].join(NOVA_LINHA),
    para: [
      "    registro.warn('[billing] RTDN sem propriedade comprovavel', {",
      '      messageId,',
      '      motivo,',
      '      token: hash,',
    ].join(NOVA_LINHA),
    testes: ['^S '],
  },
  {
    caso: 'N11',
    risco: 'herdar o dono do token ligado, sem conferir propriedade',
    arquivo: 'entitlementStore.js',
    arquivo: 'entitlement.js',
    protecao: 'a sucessao vale so para o token que a Google declara como ligado',
    de: '    atual.purchaseTokenHash === proposta.purchaseTokenHashLigado;',
    para: '    true;',
    // A MUTACAO MUDOU DE LUGAR, e a razao esta no laudo. "Herdar o dono do token
    // ligado" nao e representavel como mutacao local em `entitlementStore.js`: os
    // documentos sao escolhidos por `proposta.uid` ANTES da transacao, entao
    // nenhuma logica de dentro dela consegue redirecionar a escrita para outra
    // conta. O que E representavel — e o risco de verdade — e a sucessao virar
    // larga: qualquer token substituindo qualquer entitlement do mesmo dono.
    testes: ['^Y15 '],
  },
  {
    caso: 'N12',
    risco: 'fazer o RTDN depender de validacao anterior pelo aplicativo',
    arquivo: 'reconciliacao.js',
    protecao: 'a propriedade e resolvida sem sessao, so pelo vinculo',
    de: '    const uidResolvido = await uidDoVinculo(identificador);',
    para: '    const uidResolvido = uidEsperado ? await uidDoVinculo(identificador) : null;',
    testes: ['^Y7 '],
  },
  // =========================================================================
  // AS SETE MUTACOES DA COMPOSICAO (secao 17 da OS)
  // =========================================================================
  //
  // As cinco do backend ficam aqui. As duas do cliente Flutter (remover o
  // identificador do parametro de compra, e comprar mesmo com a preparacao
  // falhando) vivem em `app/test/billing/prova_negativa_vinculo.md`, porque este
  // runner so alcanca `node --test` — declarado la e no laudo, para que a
  // ausencia seja uma decisao registrada e nao um esquecimento.
  {
    caso: 'C1',
    risco: 'creditar a parcela de fichas antes de a propriedade ser comprovada',
    arquivo: 'index.js',
    protecao: 'a parcela sai do dono RESOLVIDO, e nao do chamador',
    // DUAS EDICOES, e a razao esta no resultado da primeira tentativa: com
    // `uid` no lugar de `propriedade.uid` o teste passava, porque o passo 6 ja
    // tinha recusado quem diverge — os dois valores sao iguais em toda execucao
    // alcancavel. A mutacao sozinha era VACUA e nao contava.
    //
    // Desligar o passo 6 JUNTO e o que abre a unica janela em que a diferenca
    // aparece: com a conferencia de propriedade fora, `uid` e do invasor e
    // `propriedade.uid` continua sendo o do dono. Se a parcela seguisse o
    // chamador, o livro-razao estaria decidindo propriedade por conta propria —
    // que e exatamente a segunda autoridade que esta OS proibe.
    edicoes: [
      {
        arquivo: 'propriedade.js',
        de: '  if (uidEsperado != null && uidResolvido !== uidEsperado) {',
        para: '  if (false && uidEsperado != null && uidResolvido !== uidEsperado) {',
      },
      {
        arquivo: 'index.js',
        de: [
          '          const r = await dependencias().livroFichas.liquidarParcela({',
          '            uid: propriedade.uid,',
        ].join(NOVA_LINHA),
        para: [
          '          const r = await dependencias().livroFichas.liquidarParcela({',
          '            uid,',
        ].join(NOVA_LINHA),
      },
    ],
    testes: ['^FI1 '],
  },
  {
    caso: 'C2',
    risco: 'voltar a creditar fichas a quem apresentou o token',
    arquivo: 'propriedade.js',
    protecao: 'igualdade exigida entre o dono resolvido e a conta autenticada',
    de: '  if (uidEsperado != null && uidResolvido !== uidEsperado) {',
    para: '  if (false && uidEsperado != null && uidResolvido !== uidEsperado) {',
    testes: ['^FI1 ', '^R6 '],
  },
  {
    caso: 'C3',
    risco: 'ignorar o identificador que a Google devolve na assinatura',
    arquivo: 'propriedade.js',
    protecao: 'leitura do identificador aninhado em externalAccountIdentifiers',
    de: '    const aninhado = externos.obfuscatedExternalAccountId;',
    para: '    const aninhado = undefined;',
    testes: ['^FI1 ', '^Y7 '],
  },
  {
    caso: 'C4',
    risco: 'associar o token ao uid antes da consulta a Google',
    arquivo: 'index.js',
    protecao: 'nenhuma persistencia antes da confirmacao autoritativa',
    de: '    const consultadoEm = new Date().toISOString();',
    para: [
      '    await refCompra.set({ uid, produtoId, estado: ESTADO.EM_VALIDACAO }, { merge: true });',
      '    const consultadoEm = new Date().toISOString();',
    ].join(NOVA_LINHA),
    testes: ['^FI1 ', '^R6 '],
  },
  {
    caso: 'C6',
    risco: 'remover o identificador do parametro de compra do Flutter',
    arquivo: 'app/lib/billing/loja_play.dart',
    protecao: 'o vinculo viaja como applicationUserName ate setObfuscatedAccountId',
    de: '        applicationUserName: vinculoDaConta,' + NOVA_LINHA
      + '      ),' + NOVA_LINHA
      + '    );' + NOVA_LINHA
      + '  }' + NOVA_LINHA + NOVA_LINHA
      + '  @override' + NOVA_LINHA
      + '  Future<bool> comprarConsumivel(',
    para: '      ),' + NOVA_LINHA
      + '    );' + NOVA_LINHA
      + '  }' + NOVA_LINHA + NOVA_LINHA
      + '  @override' + NOVA_LINHA
      + '  Future<bool> comprarConsumivel(',
    flutter: 'test/billing/vinculo_compra_test.dart',
    testes: ['(flutter)'],
  },
  {
    caso: 'C7',
    risco: 'abrir a compra mesmo quando a preparacao falha',
    arquivo: 'app/lib/billing/servico_billing.dart',
    protecao: 'sem vinculo, o dialogo da Play nao abre',
    de: '    final vinculo = await _vinculoDaSessao();' + NOVA_LINHA
      + '    if (vinculo == null) return false;',
    para: "    final vinculo = await _vinculoDaSessao() ?? 'a' * 48;",
    flutter: 'test/billing/vinculo_compra_test.dart',
    testes: ['(flutter)'],
  },
  {
    caso: 'C5',
    risco: 'a parcela de ativacao deixar de ser idempotente',
    arquivo: 'fichasStore.js',
    protecao: 'a linha ja existente do livro-razao barra o segundo credito',
    de: "      if (snap.exists) return { creditado: 0, motivo: 'parcela_ja_paga' };",
    para: "      if (false) return { creditado: 0, motivo: 'parcela_ja_paga' };",
    // A barreira e do LIVRO-RAZAO, e nao de `compras/{hash}`: e por isso que a
    // validacao e o agendador podem liquidar a mesma parcela sem combinarem
    // nada. Desligar aqui tem de pagar a ativacao duas vezes.
    testes: ['^FI4 '],
  },
  // =========================================================================
  // AS DEZ PROVAS DO SEAM DA LOJA PLAY REAL
  // =========================================================================
  //
  // Todas apontam para a bateria COMPORTAMENTAL, nunca para o teste estrutural.
  // As duas de remocao do vinculo (S1 e S5) sao as que importam mais: antes do
  // seam, apagar `applicationUserName` de `loja_play.dart` deixava os quinze
  // testes de vinculo VERDES, e so `VINC-4c` — que le o codigo-fonte — acusava.
  // Se S1 e S5 so ficassem vermelhas pelo estrutural, o seam nao teria fechado
  // lacuna nenhuma.
  {
    caso: 'S1',
    risco: 'remover applicationUserName da assinatura',
    arquivo: 'app/lib/billing/loja_play.dart',
    protecao: 'o vinculo viaja no GooglePlayPurchaseParam',
    de: ['        offerToken: ofertaPlanoBase,',
         '        applicationUserName: vinculoDaConta,'].join(NOVA_LINHA),
    para: '        offerToken: ofertaPlanoBase,',
    flutter: 'test/billing/loja_play_real_test.dart',
    testes: ['(comportamental)'],
  },
  {
    caso: 'S2',
    risco: 'substituir o vinculo por uma string fixa',
    arquivo: 'app/lib/billing/loja_play.dart',
    protecao: 'o valor entregue e o recebido, sem substituicao',
    de: ['        offerToken: ofertaPlanoBase,',
         '        applicationUserName: vinculoDaConta,'].join(NOVA_LINHA),
    para: ['        offerToken: ofertaPlanoBase,',
           "        applicationUserName: 'conta-fixa',"].join(NOVA_LINHA),
    flutter: 'test/billing/loja_play_real_test.dart',
    testes: ['(comportamental)'],
  },
  {
    caso: 'S3',
    risco: 'alterar um unico caractere do vinculo',
    arquivo: 'app/lib/billing/loja_play.dart',
    protecao: 'o vinculo chega caractere a caractere',
    de: ['        offerToken: ofertaPlanoBase,',
         '        applicationUserName: vinculoDaConta,'].join(NOVA_LINHA),
    para: ['        offerToken: ofertaPlanoBase,',
           "        applicationUserName: 'x' + vinculoDaConta.substring(1),"].join(NOVA_LINHA),
    flutter: 'test/billing/loja_play_real_test.dart',
    testes: ['(comportamental)'],
  },
  {
    caso: 'S4',
    risco: 'remover o offerToken do plano-base escolhido',
    arquivo: 'app/lib/billing/loja_play.dart',
    protecao: 'o plano-base escolhido chega a Play',
    de: '        offerToken: ofertaPlanoBase,',
    para: '        offerToken: null,',
    flutter: 'test/billing/loja_play_real_test.dart',
    testes: ['(comportamental)'],
  },
  {
    caso: 'S5',
    risco: 'remover o vinculo do consumivel',
    arquivo: 'app/lib/billing/loja_play.dart',
    protecao: 'o avulso tambem carrega a amarra da conta',
    de: ['        productDetails: produto,',
         '        applicationUserName: vinculoDaConta,',
         '      ),',
         '      autoConsume: false,'].join(NOVA_LINHA),
    para: ['        productDetails: produto,',
           '      ),',
           '      autoConsume: false,'].join(NOVA_LINHA),
    flutter: 'test/billing/loja_play_real_test.dart',
    testes: ['(comportamental)'],
  },
  {
    caso: 'S6',
    risco: 'consumir antes de o backend creditar',
    arquivo: 'app/lib/billing/loja_play.dart',
    protecao: 'autoConsume permanece false',
    de: '      autoConsume: false,',
    para: '      autoConsume: true,',
    flutter: 'test/billing/loja_play_real_test.dart',
    testes: ['(comportamental)'],
  },
  {
    caso: 'S7',
    risco: 'a assinatura contornar o seam e ir direto ao singleton',
    arquivo: 'app/lib/billing/loja_play.dart',
    protecao: 'as sete operacoes atravessam a porta',
    de: '    return _plugin.buyNonConsumable(',
    para: '    return InAppPurchase.instance.buyNonConsumable(',
    flutter: 'test/billing/loja_play_real_test.dart',
    testes: ['(comportamental)'],
  },
  {
    caso: 'S8',
    risco: 'o consumivel contornar o seam',
    arquivo: 'app/lib/billing/loja_play.dart',
    protecao: 'as sete operacoes atravessam a porta',
    de: '    return _plugin.buyConsumable(',
    para: '    return InAppPurchase.instance.buyConsumable(',
    flutter: 'test/billing/loja_play_real_test.dart',
    testes: ['(comportamental)'],
  },
  {
    caso: 'S9',
    risco: 'finalizar completar uma compra diferente da recebida',
    arquivo: 'app/lib/billing/loja_play.dart',
    protecao: 'a compra entregue e exatamente a recebida',
    de: '      _plugin.completePurchase(compra);',
    para: '      _plugin.completePurchase(PurchaseDetails(productID: compra.productID + Object().hashCode.toString(), verificationData: compra.verificationData, transactionDate: null, status: compra.status));',
    flutter: 'test/billing/loja_play_real_test.dart',
    testes: ['(comportamental)'],
  },
  {
    caso: 'S10',
    risco: 'restaurar nao chamar a porta',
    arquivo: 'app/lib/billing/loja_play.dart',
    protecao: 'restore acontece, e uma vez so',
    de: '  Future<void> restaurar() => _plugin.restorePurchases();',
    para: '  Future<void> restaurar() async {}',
    flutter: 'test/billing/loja_play_real_test.dart',
    testes: ['(comportamental)'],
  },
];

function git(...args) {
  return execFileSync('git', ['-C', RAIZ, ...args], { encoding: 'utf8' }).trim();
}

function arvoreLimpa() {
  return git('status', '--porcelain') === '';
}

/**
 * A suite Flutter do cliente, para as provas que mutam Dart.
 *
 * Nao e luxo: duas das sete mutacoes da composicao vivem no aplicativo — tirar o
 * identificador do parametro de compra, e deixar a compra abrir mesmo com a
 * preparacao falhando. Deixa-las so descritas num documento seria descrever uma
 * prova em vez de produzi-la, e o valor inteiro desta ferramenta esta em produzir.
 */
function rodarFlutter(alvo) {
  const r = spawnSync(
    'flutter',
    ['test', alvo, '--no-pub', '--reporter', 'compact'],
    { cwd: path.join(RAIZ, '..', 'app'), encoding: 'utf8', shell: true }
  );
  const saida = `${r.stdout || ''}${r.stderr || ''}`;
  // Compilar e falhar CONTA como vermelho: uma mutacao que quebra o contrato a
  // ponto de o Dart recusar tambem foi morta pelo teste.
  const m = new RegExp('\\+(\\d+)(?: -(\\d+))?', 'g');
  let ultimo = null;
  for (const achado of saida.matchAll(m)) ultimo = achado;
  const passou = ultimo ? Number(ultimo[1]) : 0;
  const falhou = ultimo && ultimo[2] ? Number(ultimo[2]) : 0;
  const quebrou = /Failed to load|Compilation failed|Error:/.test(saida);
  return {
    codigo: r.status,
    tests: passou + falhou || (quebrou ? 1 : 0),
    fail: falhou || (quebrou ? 1 : 0),
  };
}

function rodar(padroes) {
  const args = ['--test'];
  for (const p of padroes) args.push('--test-name-pattern', p);
  args.push('test/adversarial.test.js');
  const r = spawnSync(process.execPath, args, { cwd: RAIZ, encoding: 'utf8' });
  const saida = `${r.stdout || ''}${r.stderr || ''}`;
  // O `node --test` resume com o reporter TAP (`# pass N`) ou com o spec
  // (`ℹ pass N`), conforme a versao e o terminal. Ler so um dos dois faria TODA
  // prova parecer vacua — que e exatamente o falso negativo mais perigoso aqui.
  const contar = (rotulo) => {
    const m = new RegExp(`^(?:#|\\u2139) ${rotulo} (\\d+)$`, 'm').exec(saida);
    return m == null ? null : Number(m[1]);
  };
  return { codigo: r.status, tests: contar('tests'), fail: contar('fail') };
}

function main() {
  if (!arvoreLimpa()) {
    console.error('ABORTADO: a arvore precisa estar limpa antes da prova.');
    console.error(git('status', '--porcelain'));
    process.exit(2);
  }

  const linhas = [];
  let vacuos = 0;

  for (const prova of PROVAS) {
    // Uma prova pode precisar de MAIS DE UMA edicao, e nao por conveniencia.
    // Ha protecoes que so sao observaveis em conjunto: desligar uma sozinha nao
    // muda nada porque a outra ja recusou antes. `edicoes` existe para esses
    // casos — ver C1, onde a parcela so pode ir para a conta errada se a
    // conferencia de propriedade tambem estiver desligada.
    const edicoes = prova.edicoes
      || [{ arquivo: prova.arquivo, de: prova.de, para: prova.para }];
    const originais = new Map();
    for (const e of edicoes) {
      const cam = caminhoDe(e.arquivo);
      if (!originais.has(cam)) originais.set(cam, fs.readFileSync(cam, "utf8"));
    }
    const alvo = caminhoDe(edicoes[0].arquivo);
    const original = originais.get(alvo);

    let resultado;
    try {
      for (const e of edicoes) {
        const cam = caminhoDe(e.arquivo);
        const atual = fs.readFileSync(cam, "utf8");
        const eolA = atual.includes(CRLF) ? CRLF : NOVA_LINHA;
        const norm = (t) => t.split(CRLF).join(NOVA_LINHA).split(NOVA_LINHA).join(eolA);
        const dE = norm(e.de);
        if (atual.split(dE).length - 1 !== 1) {
          console.error(`ABORTADO: ancora de ${e.arquivo} nao e unica no caso ${prova.caso}.`);
          for (const [c2, v2] of originais) fs.writeFileSync(c2, v2, "utf8");
          process.exit(2);
        }
        fs.writeFileSync(cam, atual.replace(dE, norm(e.para)), "utf8");
      }
      resultado = prova.flutter
        ? rodarFlutter(prova.flutter)
        : rodar(prova.testes);
    } finally {
      for (const [cam, conteudo] of originais) fs.writeFileSync(cam, conteudo, 'utf8');
    }

    if (!arvoreLimpa()) {
      console.error(`FALHA DE RESTAURO apos o caso ${prova.caso}. Arvore suja:`);
      console.error(git('status', '--porcelain'));
      process.exit(2);
    }

    // Um padrao que nao casa com teste nenhum devolve "zero falhas" e passaria
    // por prova. Aqui isso e erro duro, e nao resultado.
    if (!resultado.tests) {
      console.error(
        `ABORTADO: o padrao ${prova.testes.join(' ')} nao selecionou nenhum teste `
        + `(caso ${prova.caso}). O nome do teste mudou?`
      );
      process.exit(2);
    }

    const ficouVermelho = resultado.fail > 0;
    if (!ficouVermelho) vacuos += 1;
    linhas.push({
      caso: prova.caso,
      arquivo: prova.arquivo,
      protecao: prova.protecao,
      testes: prova.testes.join(' '),
      rodados: resultado.tests,
      fail: resultado.fail,
      veredito: ficouVermelho ? 'NAO VACUO' : 'VACUO',
    });
  }

  console.log('\n| caso | arquivo | protecao desligada | padrao | rodados | vermelhos | veredito |');
  console.log('| --- | --- | --- | --- | ---: | ---: | --- |');
  for (const l of linhas) {
    console.log(
      `| ${l.caso} | \`${l.arquivo}\` | ${l.protecao} | \`${l.testes}\` | ${l.rodados} | ${l.fail} | **${l.veredito}** |`
    );
  }

  console.log(`\narvore limpa no fim: ${arvoreLimpa() ? 'sim' : 'NAO'}`);
  if (vacuos > 0) {
    console.error(`\n${vacuos} prova(s) VACUA(s): o teste passa com a protecao desligada.`);
    process.exit(1);
  }
  console.log('\nTodas as protecoes criticas sao necessarias: nenhum teste passou sem elas.');
}

main();
