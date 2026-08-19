'use strict';
/**
 * §19 — AS 15 PROVAS NEGATIVAS DA COMPOSIÇÃO.
 *
 * ============================================================================
 * O QUE ESTE ARQUIVO É, E O QUE ELE NÃO É
 * ============================================================================
 *
 * NÃO é uma recontagem das suítes das folhas. Cada codebase já prova a própria
 * regra, e nenhuma delas pode provar o que segue, por um motivo estrutural: uma
 * suíte de folha só enxerga a sua linhagem. `functions-ranking` não sabe que
 * `functions-billing` existe; `functions-mesas` não sabe quem mais escreve na
 * coleção que ele lê; a suíte da moderação não sabe se a moderação está no
 * portão do CI.
 *
 * As invariantes aqui só existem DEPOIS da união — e portanto só podem quebrar
 * depois da união. É por isso que elas são provas *da composição*.
 *
 * ============================================================================
 * A FORMA DE CADA CASO
 * ============================================================================
 *
 *   invariante ......... o que tem de continuar verdadeiro
 *   autoridade ......... quem decide, e onde
 *   cenário proibido ... a regressão concreta que se quer impedir
 *   prova .............. o que este caso mede
 *
 * ============================================================================
 * COMO A VACUIDADE FOI FECHADA
 * ============================================================================
 *
 * 1. ÂNCORA POSITIVA em todo caso. Antes de afirmar "o proibido não está aqui",
 *    prova-se "o guardado está aqui". Apagar ou renomear o arquivo guardado
 *    REPROVA, em vez de ficar verde por ausência.
 *
 * 2. LEITURA SEM COMENTÁRIO. Estes arquivos citam textualmente o que é proibido
 *    ("um `delete resposta.autorUid` deixaria passar...", "voltar a decidir por
 *    `req.auth.token`"). Buscar sobre o texto cru acharia a explicação do
 *    defeito e reprovaria o código correto — ou acharia a âncora dentro de um
 *    comentário e passaria com o código já removido.
 *
 * 3. CONJUNTOS FECHADOS, e não "não contém". Onde é possível, o caso compara
 *    conjuntos inteiros (exports, gates, codebases) em vez de procurar a
 *    ausência de uma string — porque ausência casa com renomeação acidental.
 *
 * 4. MUTAÇÃO DIRIGIDA. `mutacoes.js`, ao lado, quebra cada guarda e exige que
 *    pelo menos um caso fique vermelho. Prova que sobrevive à quebra da própria
 *    guarda é prova vazia, e é tratada como falha da campanha.
 */

const { test, describe } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const A = require('./arvore.js');

const CODEBASES = A.codebases();

// ---------------------------------------------------------------------------
// PN-01
// ---------------------------------------------------------------------------

describe('PN-01 — a guarda da credencial do motor sem `checkRevoked`', () => {
  // invariante ...... revogar a sessão do motor tira o acesso NA HORA
  // autoridade ...... functions/src/autoridade.ts (e o espelho em
  //                   functions-mesas/src/index.ts, que verifica por conta
  //                   própria porque é outra unidade de implantação)
  // proibido ........ trocar `verifyIdToken(token, true)` por
  //                   `verifyIdToken(token)` — o token revogado continuaria
  //                   valendo até expirar, ou seja, até uma hora
  // prova ........... TODA chamada de verificação da árvore composta passa o
  //                   segundo argumento; e existe ao menos uma para achar
  test('toda chamada de verificacao confere revogacao, nas 9 codebases', () => {
    const chamadas = [];
    for (const { source } of CODEBASES) {
      for (const rel of A.fontesDe(source)) {
        const src = A.codigo(rel);
        for (const m of src.matchAll(/\.verifyIdToken\s*\(([^;]*?)\)\s*;/gs)) {
          chamadas.push({ rel, args: m[1].replace(/\s+/g, ' ').trim() });
        }
      }
    }

    // ÂNCORA: se ninguém mais verifica token nesta árvore, a prova não pode
    // ficar verde — ela perdeu o objeto.
    assert.ok(
      chamadas.length >= 2,
      'ANCORA PERDIDA: a composicao tinha DUAS verificacoes de token (torneios e ' +
        `mesas) e agora tem ${chamadas.length}. Sem chamada, "todas conferem ` +
        'revogacao" e verdade por vazio.'
    );

    for (const c of chamadas) {
      assert.match(
        c.args,
        /,\s*true\s*$/,
        `${c.rel}: verifyIdToken(${c.args}) — sem \`checkRevoked\`, revogar a ` +
          'credencial do motor so faria efeito quando o token expirasse.'
      );
    }
  });
});

// ---------------------------------------------------------------------------
// PN-02
// ---------------------------------------------------------------------------

describe('PN-02 — o claim de autoridade aceito por veracidade, e nao por valor', () => {
  // invariante ...... `motorDePartidas` só concede autoridade quando vale
  //                   exatamente `true`
  // autoridade ...... QUATRO codebases decidem isso, cada uma por si:
  //                   torneios, mesas, ranking e moderação
  // proibido ........ `if (token.motorDePartidas)` — um claim valendo a string
  //                   "false", o número 1 ou um objeto vazio passaria
  // prova ........... nenhuma das quatro usa o claim em posição de verdade;
  //                   todas comparam com `true` estrito
  //
  // ESTA É UMA INVARIANTE DE COMPOSIÇÃO no sentido mais literal: as quatro
  // implementações são independentes e nenhuma suíte de folha compara uma com a
  // outra. Basta UMA afrouxar para a autoridade do motor ter dois padrões.
  const CONSUMIDORES = [
    'functions/src/autoridade.ts',
    'functions-mesas/src/index.ts',
    'functions-ranking/src/index.ts',
    'functions-moderacao/src/index.ts',
  ];

  // A composição decide isto em DUAS formas, e as duas precisam ser medidas —
  // medir só uma deixa metade das codebases sem prova:
  //
  //   direta ...... `token.motorDePartidas !== true`   (ranking, moderação)
  //   indireta .... `PAPEIS.some((papel) => token[papel] === true)`
  //                                                    (torneios, mesas)
  //
  // MEDIR A LINHA INTEIRA NÃO SERVE, e isto foi descoberto por mutação, não por
  // leitura: `if (!token.motorDePartidas && token.admin !== true)` é a
  // regressão exata que este caso existe para pegar, e uma busca por "há
  // comparação estrita nesta linha" a aprova — o `!== true` do `admin`, ao
  // lado, satisfaz a busca. O que se mede aqui é o que vem IMEDIATAMENTE DEPOIS
  // do claim.
  test('as quatro codebases comparam com `true` estrito', () => {
    let sitiosDiretos = 0;
    let sitiosIndiretos = 0;

    for (const rel of CONSUMIDORES) {
      const src = A.codigo(rel);
      A.exigirAncora(assert, src, 'motorDePartidas', `${rel} consome o claim`);

      // FORMA DIRETA — acesso por propriedade (`.motorDePartidas`). A ocorrência
      // entre aspas é declaração de nome, e não decisão.
      for (const m of src.matchAll(/\.motorDePartidas([\s\S]{0,24})/g)) {
        sitiosDiretos++;
        assert.match(
          m[1],
          /^\s*(===|!==)\s*true/,
          `${rel}: o claim e usado como \`.motorDePartidas${m[1].split('\n')[0]}\`, sem ` +
            'comparacao estrita imediata. Um claim valendo "false" (string), 1 ou ' +
            '{} concederia autoridade do motor.'
        );
      }

      // FORMA INDIRETA — o papel indexado. Vale a mesma exigência.
      for (const m of src.matchAll(/\[papel\]([\s\S]{0,24})/g)) {
        sitiosIndiretos++;
        assert.match(
          m[1],
          /^\s*(===|!==)\s*true/,
          `${rel}: o papel indexado e usado sem comparacao estrita imediata.`
        );
      }
    }

    // ÂNCORA: as duas formas têm de continuar existindo. Se uma sumir, o laço
    // correspondente roda zero vezes e "todas comparam estrito" vira verdade
    // por vazio — que é precisamente o grep vácuo que a OS proíbe.
    assert.ok(sitiosDiretos >= 2, `ANCORA PERDIDA: so ${sitiosDiretos} decisoes diretas`);
    assert.ok(sitiosIndiretos >= 2, `ANCORA PERDIDA: so ${sitiosIndiretos} decisoes indiretas`);
  });

  test('o nome do claim e o MESMO nas quatro', () => {
    // Um `motorDePartida` sem o `s` numa delas produziria uma codebase que
    // recusa todo mundo, calada — e o defeito seria atribuido a credencial.
    for (const rel of CONSUMIDORES) {
      const src = A.codigo(rel);
      const nomes = new Set([...src.matchAll(/\bmotorDePartida\w*/g)].map((m) => m[0]));
      assert.deepEqual([...nomes], ['motorDePartidas'], `${rel}: variacao no nome do claim`);
    }
  });
});

// ---------------------------------------------------------------------------
// PN-03
// ---------------------------------------------------------------------------

describe('PN-03 — export acidental de autoridade pela superficie de implantacao', () => {
  // invariante ...... a superfície implantada de cada codebase é uma relação
  //                   FECHADA e decidida
  // autoridade ...... o `index.ts`/`index.js` de cada codebase
  // proibido ........ `export * from "./modulo"` faz de QUALQUER símbolo novo
  //                   daquele módulo uma Function pública — inclusive uma
  //                   função interna de autoridade que alguém exportou só para
  //                   testar
  // prova ........... o inventário abaixo é comparado por CONJUNTO com o que a
  //                   árvore realmente exporta; símbolo novo reprova até ser
  //                   declarado aqui
  //
  // O caso decisivo é `functions/src/index.ts`, que faz
  // `export * from "./rastreabilidade"`. Nada impede que um símbolo novo lá
  // vire callable — a não ser este caso.
  const INVENTARIO = {
    'functions/src/index.ts': [
      'inscreverEmTorneio',
      'cancelarInscricaoTorneio',
      'receberResultadoPartida',
      'tickTorneios',
      'aoConcluirEdicao',
      'consolidarConvitesDaTemporada',
      'responderConviteEncerramento',
      // vindos do `export *`, e por isso declarados aqui um a um
      'registrarEncerramentoPartida',
      'consultarPartidaPorMatchId',
      'consultarExtratoCompetitivo',
      'registrarSinalAntifraude',
    ],
  };

  test('a superficie de `functions` e exatamente a declarada', () => {
    const rel = 'functions/src/index.ts';
    const src = A.codigo(rel);

    // ÂNCORA: a reexportação existe. Se ela sumir, o inventário abaixo passa a
    // descrever uma superfície que não é mais essa, e o caso avisa.
    A.exigirAncora(assert, src, /export\s+\*\s+from\s+["']\.\/rastreabilidade["']/, `${rel} reexporta rastreabilidade`);

    const daqui = [...src.matchAll(/^export\s+const\s+(\w+)\s*=\s*on\w+\s*\(/gm)].map((m) => m[1]);
    const reexportados = [
      ...A.codigo('functions/src/rastreabilidade.ts').matchAll(
        /^export\s+const\s+(\w+)\s*=\s*on\w+\s*\(/gm
      ),
    ].map((m) => m[1]);

    assert.deepEqual(
      [...daqui, ...reexportados].sort(),
      [...INVENTARIO[rel]].sort(),
      'A SUPERFICIE IMPLANTADA MUDOU. Isto nao e um teste a atualizar sem pensar: ' +
        'cada nome aqui e uma Function publica, alcancavel por qualquer cliente ' +
        'autenticado. Se o nome novo e mesmo para ser publico, declare-o; se e ' +
        'autoridade interna que vazou pelo `export *`, tire o export.'
    );
  });

  test('nenhuma outra codebase reexporta em bloco sem inventario', () => {
    for (const { source } of CODEBASES) {
      for (const rel of A.fontesDe(source)) {
        if (!/\/index\.(ts|js)$/.test(rel)) continue;
        const src = A.codigo(rel);
        for (const m of src.matchAll(/export\s+\*\s+from\s+["']([^"']+)["']/g)) {
          assert.ok(
            INVENTARIO[rel],
            `${rel}: reexporta \`${m[1]}\` em bloco e NAO tem inventario declarado ` +
              'em PN-03. Toda superficie de implantacao aberta em bloco precisa de ' +
              'uma relacao fechada, senao um simbolo novo vira Function publica sozinho.'
          );
        }
      }
    }
  });
});

// ---------------------------------------------------------------------------
// PN-04
// ---------------------------------------------------------------------------

describe('PN-04 — Billing voltando a tratar o chamador como dono da compra', () => {
  // invariante ...... quem é dono da compra é o que a Google devolve, e não
  //                   quem está ligando
  // autoridade ...... functions-billing/propriedade.js
  // proibido ........ `decidirPropriedade` usar `req.auth.uid` — qualquer
  //                   pessoa autenticada reivindicaria a assinatura de outra
  //                   apresentando um token de compra alheio
  // prova ........... o módulo da propriedade não conhece o chamador: nada de
  //                   `auth`, `context` ou `req` na decisão
  test('a decisao de propriedade nao alcanca o chamador', () => {
    const rel = 'functions-billing/propriedade.js';
    const src = A.codigo(rel);

    // A ancora exige o parentese de proposito: sem ele, `decidirPropriedade`
    // casaria com `decidirPropriedadeFrouxo`, e RENOMEAR a funcao deixaria
    // esta prova verde sobre uma decisao que ja nao existe. Casamento por
    // prefixo foi um sobrevivente REAL da campanha de mutacao.
    A.exigirAncora(assert, src, /\bfunction decidirPropriedade\s*\(/, `${rel} decide a propriedade`);
    A.exigirAncora(
      assert,
      src,
      'obfuscatedExternalAccountId',
      `${rel} le o identificador que a Google devolve`
    );

    for (const proibido of ['req.auth', 'context.auth', 'request.auth', 'callerUid', 'uidDoChamador']) {
      assert.ok(
        !src.includes(proibido),
        `${rel}: a decisao de propriedade alcanca \`${proibido}\`. O dono da compra ` +
          'passaria a ser quem esta ligando — e o token de compra de outra pessoa ' +
          'viraria assinatura propria.'
      );
    }
  });
});

// ---------------------------------------------------------------------------
// PN-05
// ---------------------------------------------------------------------------

describe('PN-05 — `purchaseToken` voltando a decidir propriedade', () => {
  // invariante ...... o token de compra prova QUE houve compra, e nunca DE QUEM
  // autoridade ...... functions-billing/propriedade.js + entitlementStore.js
  // proibido ........ derivar o uid do `purchaseToken` (ou do hash dele) — o
  //                   token é reapresentável, e quem o obtivesse herdaria a conta
  // prova ........... o identificador de propriedade sai do par
  //                   `playerBillingIdentity` / `billingAccountIndex`, e o
  //                   token não aparece na resolução do uid
  test('o uid sai do indice de vinculo, e nunca do token', () => {
    const rel = 'functions-billing/entitlementStore.js';
    const src = A.codigo(rel);

    A.exigirAncora(assert, src, 'billingAccountIndex', `${rel} mantem o indice de vinculo`);
    A.exigirAncora(assert, src, 'playerBillingIdentity', `${rel} mantem a identidade de billing`);

    // A regressão concreta: uma função que recebe token e devolve uid.
    for (const m of src.matchAll(/function\s+(\w*[Uu]id\w*)\s*\(([^)]*)\)/g)) {
      assert.ok(
        !/purchaseToken|purchaseTokenHash/.test(m[2]),
        `${rel}: \`${m[1]}\` resolve uid a partir do token de compra. O token e ` +
          'reapresentavel: quem o obtivesse herdaria a conta.'
      );
    }
  });
});

// ---------------------------------------------------------------------------
// PN-06
// ---------------------------------------------------------------------------

describe('PN-06 — direito pago escrito por caminho paralelo', () => {
  // invariante ...... `playerEntitlements` tem UM autor, e é o billing
  // autoridade ...... functions-billing
  // proibido ........ ranking (passe de cortesia), mesas (admissão) ou qualquer
  //                   outra codebase ESCREVEREM ali — seria conceder assinatura
  //                   sem compra, por um caminho que a reconciliação com a Play
  //                   nunca visita
  // prova ........... varredura das nove codebases: fora do billing, ninguém
  //                   escreve na coleção
  //
  // A ÚNICA exceção é `functions-conta`, e ela não escreve: APAGA, na exclusão
  // de conta, e só através da matriz de retenção — que é dado, e não código
  // solto. O caso confere isso explicitamente em vez de abrir uma exceção muda.
  test('so o billing escreve `playerEntitlements`', () => {
    const COLECAO = 'playerEntitlements';
    let vistaNoBilling = false;

    for (const { codebase, source } of CODEBASES) {
      for (const rel of A.fontesDe(source)) {
        const src = A.codigo(rel);
        if (!src.includes(COLECAO)) continue;
        if (source === 'functions-billing') { vistaNoBilling = true; continue; }

        // `functions-conta` alcança a coleção pela matriz de retenção. Matriz é
        // DADO: `caminho`/`alcance` descrevem o que apagar, e nenhuma escrita
        // acontece ali. Um `.set(`/`.update(` nesse arquivo seria outra coisa.
        const escritas = [
          ...src.matchAll(new RegExp(`${COLECAO}[^\\n]*`, 'g')),
        ].map((m) => m[0]);
        for (const trecho of escritas) {
          assert.ok(
            !/\.(set|update|create)\s*\(/.test(trecho),
            `${codebase} (${rel}) escreve em ${COLECAO}: "${trecho.trim().slice(0, 90)}". ` +
              'Seria conceder assinatura por um caminho que a reconciliacao com a ' +
              'Play nunca visita.'
          );
        }
      }
    }

    // ÂNCORA: se o billing parou de mencionar a coleção, a varredura acima
    // estaria vigiando uma coleção que ninguém mais usa.
    assert.ok(vistaNoBilling, 'ANCORA PERDIDA: o billing nao menciona mais `playerEntitlements`');
  });

  test('o passe de cortesia mora FORA da autoridade da assinatura', () => {
    // A tentação inversa: o passe quinzenal escrever em `playerEntitlements`
    // para "reaproveitar" quem já lê dali. Seria uma cortesia indistinguível de
    // uma compra, e sem `purchaseToken` para reconciliar.
    const src = A.codigo('functions-ranking/src/passe.ts');
    // A ancora tem de estar no CODIGO, e nao na prosa: `A.codigo()` remove
    // comentarios, e `passe.ts` menciona `playerEntitlements` justamente para
    // explicar por que NAO escreve la. Ancorar num comentario faria a prova
    // depender de um texto que ninguem executa — e a primeira versao deste
    // caso ancorava exatamente assim.
    A.exigirAncora(
      assert,
      src,
      /\bexport const VERSAO_CONTRATO_PASSE\b/,
      'functions-ranking/src/passe.ts e a autoridade do passe de cortesia'
    );
    assert.ok(
      !/playerEntitlements/.test(src),
      'o passe de cortesia alcanca `playerEntitlements` — cortesia viraria compra'
    );
  });
});

// ---------------------------------------------------------------------------
// PN-07 · PN-10 · PN-12 — as TRÊS direções do mesmo defeito de portão
// ---------------------------------------------------------------------------

/** Os gates da fonte única. */
function gatesDaFonte() {
  return A.ler('scripts/ci/gates_os_integracao.txt')
    .split(/\r?\n/)
    .map((l) => l.trim())
    .filter((l) => l && !l.startsWith('#'));
}

/** Quem o workflow de fato produz: `exit_<gate>` e as chamadas `roda <gate>`. */
function gatesProduzidos() {
  const w = A.ler('.github/workflows/ci-os-integracao.yml');
  const p = new Set([...w.matchAll(/exit_([A-Za-z0-9_]+)/g)].map((m) => m[1]));
  for (const m of w.matchAll(/^\s*roda\s+([A-Za-z0-9_]+)\s/gm)) p.add(m[1]);
  return p;
}

describe('PN-07 — uma codebase implantavel fora do portao', () => {
  // invariante ...... toda codebase que sobe é exercida pelo CI
  // autoridade ...... firebase.json (o que sobe) × o workflow (o que roda)
  // proibido ........ uma codebase deployável sem passo nenhum — pior que o
  //                   CI-02, porque não gera nem evidência
  // prova ........... para cada `source` do manifesto existe ao menos um passo
  //                   do workflow que a exercita e escreve um marcador
  test('as 9 codebases de firebase.json tem passo no workflow', () => {
    const w = A.ler('.github/workflows/ci-os-integracao.yml');
    const blocos = w.split(/^ {6}- name:/m);
    assert.ok(blocos.length > 10, 'ANCORA PERDIDA: o workflow nao tem passos reconheciveis');

    const semPortao = [];
    for (const { codebase, source } of CODEBASES) {
      const gates = new Set();
      for (const b of blocos) {
        // O passo tem de CITAR a pasta e produzir marcador — citar sem produzir
        // e mencao, nao portao.
        if (!b.includes(source + '/') && !b.includes(source + ' ')) continue;
        for (const m of b.matchAll(/exit_([A-Za-z0-9_]+)/g)) gates.add(m[1]);
      }
      if (gates.size === 0) semPortao.push(`${codebase} (${source})`);
    }

    assert.deepEqual(
      semPortao,
      [],
      'CODEBASE IMPLANTAVEL SEM PORTAO. Ela sobe em producao e o CI nunca a ' +
        'executa — nem evidencia existe. Foi assim que `functions-conta`, ' +
        '`functions-mesas` e `functions-economia` ficaram de fora ate a composicao.'
    );
  });
});

describe('PN-10 — gate declarado que ninguem produz', () => {
  // invariante ...... todo gate obrigatório tem produtor
  // autoridade ...... scripts/ci/gates_os_integracao.txt × o workflow
  // proibido ........ um nome de gate sem passo que o produza. O agregador
  //                   falha fechado sobre ausência — corretamente —, e o portão
  //                   fica incapaz de ficar verde por um FANTASMA, que é como
  //                   se cria pressão para afrouxar o agregador
  // prova ........... a fonte única ⊆ os produtores do workflow
  //
  // Foi o caso real de `regras`: renomeado para `colecoesemu`, o nome velho
  // ficou na fonte e nunca teve produtor. E de `passeint`, que o §19 nomeia:
  // tirá-lo do workflow mantendo-o aqui produziria o mesmo fantasma.
  test('todo gate da fonte unica e produzido pelo workflow', () => {
    const gates = gatesDaFonte();
    const produzidos = gatesProduzidos();
    assert.ok(gates.length >= 40, `ANCORA PERDIDA: a fonte unica tem so ${gates.length} gates`);
    assert.deepEqual(
      gates.filter((g) => !produzidos.has(g)),
      [],
      'GATE FANTASMA: declarado obrigatorio e sem passo que o produza.'
    );
  });
});

describe('PN-12 — gate que roda e o agregador nao percorre (CI-02)', () => {
  // invariante ...... todo resultado produzido é percorrido pelo agregador
  // autoridade ...... o workflow × scripts/ci/gates_os_integracao.txt
  // proibido ........ um passo escrever `exit_rankingfn` e o agregador não ler
  //                   aquele nome: a suíte roda, fica vermelha, e o portão
  //                   segue verde. É o defeito CI-02 na sua forma original
  // prova ........... os produtores do workflow ⊆ a fonte única
  test('todo resultado produzido e percorrido', () => {
    const gates = new Set(gatesDaFonte());
    const produzidos = [...gatesProduzidos()];
    assert.ok(produzidos.length >= 40, `ANCORA PERDIDA: o workflow produz so ${produzidos.length}`);
    assert.deepEqual(
      produzidos.filter((g) => !gates.has(g)),
      [],
      'CI-02: a suite roda, pode ficar vermelha, e o portao final nao a percorre.'
    );
  });
});

// ---------------------------------------------------------------------------
// PN-08
// ---------------------------------------------------------------------------

describe('PN-08 — o chat projetando UID para outro jogador', () => {
  // invariante ...... a mensagem entregue carrega `autorPublicId`, jamais UID
  // autoridade ...... functions-moderacao/src/chat.ts
  // proibido ........ um `...doc` na projeção, ou um campo de identidade
  //                   interna na lista de permissão. O UID é a chave que liga
  //                   a pessoa a tudo o mais no banco
  // prova ........... a projeção é lista de permissão fechada, e nenhuma das
  //                   chaves permitidas está na lista de proibidas
  test('`projetarMensagem` e lista de permissao, sem espalhar o documento', () => {
    const rel = 'functions-moderacao/src/chat.ts';
    const src = A.codigo(rel);

    // A ancora exige o parentese de proposito: sem ele, `X` casaria com
    // `XFrouxo`, e RENOMEAR a funcao deixaria esta prova verde sobre uma
    // decisao que ja nao existe. Casamento por prefixo foi um sobrevivente
    // REAL da campanha de mutacao — nao uma precaucao teorica.
    A.exigirAncora(assert, src, /\bexport function projetarMensagem\s*\(/, `${rel} projeta a mensagem`);
    A.exigirAncora(assert, src, 'CHAVES_PROIBIDAS_NA_ENTREGA', `${rel} declara as chaves proibidas`);

    const corpo = src.slice(src.search(/\bexport function projetarMensagem\s*\(/));
    const fim = corpo.indexOf('\n}');
    const trecho = corpo.slice(0, fim);

    assert.ok(
      !/\.\.\./.test(trecho),
      `${rel}: ha um spread dentro de \`projetarMensagem\`. Basta um \`...doc.data()\` ` +
        'para o `autorUid` viajar junto — e o campo novo de amanha viaja tambem.'
    );

    const permitidas = [...trecho.matchAll(/^\s*(\w+):/gm)].map((m) => m[1]);
    assert.ok(permitidas.length >= 5, `ANCORA PERDIDA: a projecao tem so ${permitidas.length} campos`);

    const proibidas = new Set(
      [...src.matchAll(/CHAVES_PROIBIDAS_NA_ENTREGA[\s\S]*?\]\)/g)]
        .flatMap((m) => [...m[0].matchAll(/"(\w+)"/g)])
        .map((m) => m[1])
    );
    assert.ok(proibidas.size >= 10, `ANCORA PERDIDA: so ${proibidas.size} chaves proibidas`);

    for (const campo of permitidas) {
      assert.ok(
        !proibidas.has(campo),
        `${rel}: a projecao entrega \`${campo}\`, que esta na lista de proibidas.`
      );
    }
  });
});

// ---------------------------------------------------------------------------
// PN-09
// ---------------------------------------------------------------------------

describe('PN-09 — as Rules abrindo uma colecao reservada', () => {
  // invariante ...... o que só o Admin SDK escreve continua fechado ao cliente,
  //                   e o banco continua negando por padrão
  // autoridade ...... firebase/firestore.rules — arquivo ÚNICO, no qual seis
  //                   linhagens diferentes acrescentaram blocos
  // proibido ........ um bloco novo abrir escrita em direito pago, no índice de
  //                   vínculo de billing ou no passe de cortesia; ou o fecho
  //                   `match /{documento=**}` deixar de ser o último
  // prova ........... cada coleção reservada tem bloco, e nele a escrita é
  //                   `if false`; e o fecho de negação é o último match
  //
  // É prova de composição porque o arquivo é um só: um bloco acrescentado por
  // uma linhagem pode afrouxar o que outra linhagem fechou, e nenhuma suíte de
  // folha lê o arquivo inteiro.
  const RESERVADAS = [
    'playerEntitlements',
    'playerBillingIdentity',
    'billingAccountIndex',
    'playerCourtesyPass',
    'rankingLedger',
  ];

  test('as colecoes reservadas continuam fechadas a escrita do cliente', () => {
    const rules = A.ler('firebase/firestore.rules');

    for (const colecao of RESERVADAS) {
      const i = rules.indexOf(`match /${colecao}/`);
      assert.notEqual(i, -1, `ANCORA PERDIDA: a colecao ${colecao} nao tem bloco nas Rules`);

      // Do bloco até o próximo `match` de primeiro nível.
      const resto = rules.slice(i);
      const prox = resto.slice(1).search(/\n {4}match \//);
      const bloco = prox === -1 ? resto : resto.slice(0, prox);

      const escritas = [...bloco.matchAll(/allow\s+([a-z, ]*write[a-z, ]*):\s*if\s+([^;]+);/g)];
      assert.ok(escritas.length >= 1, `${colecao}: nenhuma regra de escrita declarada`);
      for (const e of escritas) {
        assert.match(
          e[2].trim(),
          /^false$/,
          `${colecao}: escrita liberada por "${e[2].trim()}". Esta colecao e escrita ` +
            'pelo Admin SDK e por mais ninguem.'
        );
      }
    }
  });

  test('o fecho de negacao padrao continua sendo o ULTIMO match', () => {
    const rules = A.ler('firebase/firestore.rules');
    // `{documento=**}` tem chaves no proprio nome: capturar `[^\s{]+` pararia
    // no `{` e o fecho viraria uma string vazia — que casaria com qualquer
    // coisa e faria esta prova mentir.
    const todos = [...rules.matchAll(/match\s+\/(\{[^}]*\}|[^\s{]+)/g)].map((m) => m[1]);
    assert.ok(todos.length > 40, `ANCORA PERDIDA: so ${todos.length} blocos nas Rules`);
    assert.equal(
      todos[todos.length - 1],
      '{documento=**}',
      'o fecho de negacao padrao deixou de ser o ultimo. Um bloco depois dele nao ' +
        'seria alcancado, e uma colecao nova ficaria sem a negacao que se supunha.'
    );
  });
});

// ---------------------------------------------------------------------------
// PN-11
// ---------------------------------------------------------------------------

describe('PN-11 — o contexto estavel do recibo do Passe removido', () => {
  // invariante ...... a idempotência do passe é "mesma tentativa NO MESMO
  //                   contexto", e não "mesma string"
  // autoridade ...... functions-ranking/src/passe.ts
  // proibido ........ apagar o contexto estável do recibo. A `tentativaEntradaId`
  //                   sozinha faria um recibo antigo valer para uma entrada
  //                   nova — o passe viraria decorativo
  // prova ........... o contexto existe, é comparado, e ausência NÃO coincide
  test('o contexto estavel existe, e ausencia nao coincide com nada', () => {
    const rel = 'functions-ranking/src/passe.ts';
    const src = A.codigo(rel);

    A.exigirAncora(assert, src, 'ContextoEstavelDoRecibo', `${rel} declara o contexto estavel`);
    A.exigirAncora(assert, src, /\bexport function contextoEstavelDe\s*\(/, `${rel} extrai a parte estavel`);
    A.exigirAncora(assert, src, /\bexport function contextosCoincidem\s*\(/, `${rel} compara contextos`);

    // O recibo tem de CARREGAR o contexto: um recibo sem contexto e um recibo
    // que so sabe dizer "ja vi essa string".
    A.exigirAncora(assert, src, /\bcontextoDoRecibo\s*[:?]/, `${rel} guarda o contexto no recibo`);

    // E o motivo de recusa por divergência precisa continuar existindo — sem
    // ele, comparar não decide nada.
    A.exigirAncora(assert, src, 'contexto_divergente', `${rel} recusa por contexto divergente`);

    // A regressão silenciosa: `guardado` ausente passar por "igual".
    const corpo = src.slice(src.search(/\bexport function contextosCoincidem\s*\(/));
    const trecho = corpo.slice(0, corpo.indexOf('\n}') + 2);
    assert.match(
      trecho,
      /(guardado\s*(===|==)\s*null|!guardado|guardado\s*==\s*null|null\s*(===|==)\s*guardado)/,
      `${rel}: \`contextosCoincidem\` nao trata contexto guardado AUSENTE. Documento ` +
        'antigo ou escrita incompleta passaria por "mesmo contexto".'
    );
  });
});

// ---------------------------------------------------------------------------
// PN-13
// ---------------------------------------------------------------------------

describe('PN-13 — uma codebase sumindo de firebase.json', () => {
  // invariante ...... toda pasta de Functions da árvore é declarada no manifesto
  // autoridade ...... firebase.json
  // proibido ........ uma pasta `functions-*` com código e sem entrada: ela
  //                   simplesmente para de subir, e nada avisa — o código
  //                   continua no repositório, com testes verdes, sem existir
  //                   em produção
  // prova ........... o conjunto de pastas no disco == o conjunto de `source`
  //                   do manifesto
  test('as pastas de Functions no disco e no manifesto sao o mesmo conjunto', () => {
    const noDisco = fs
      .readdirSync(A.RAIZ, { withFileTypes: true })
      .filter((e) => e.isDirectory() && /^functions(-|$)/.test(e.name))
      .filter((e) => fs.existsSync(path.join(A.RAIZ, e.name, 'package.json')))
      .map((e) => e.name);
    // `firebase/functions` (a codebase `colecoes`) não mora na raiz.
    if (fs.existsSync(path.join(A.RAIZ, 'firebase', 'functions', 'package.json'))) {
      noDisco.push('firebase/functions');
    }

    assert.ok(noDisco.length >= 8, `ANCORA PERDIDA: so ${noDisco.length} pastas de Functions`);
    assert.deepEqual(
      noDisco.sort(),
      CODEBASES.map((c) => c.source).sort(),
      'PASTA DE FUNCTIONS FORA DO MANIFESTO (ou o contrario). Uma pasta nao ' +
        'declarada para de subir em silencio: o codigo fica no repositorio, com ' +
        'teste verde, e nao existe em producao.'
    );
  });
});

// ---------------------------------------------------------------------------
// PN-14
// ---------------------------------------------------------------------------

describe('PN-14 — `rastreabilidade.ts` voltando a decidir autoridade sozinho', () => {
  // invariante ...... a autoridade da partida é decidida em UM lugar
  // autoridade ...... functions/src/autoridade.ts
  // proibido ........ a versão anterior de `rastreabilidade.ts` lia
  //                   `req.auth.token` e concluía sozinha. Voltar a isso
  //                   reintroduz o defeito que a credencial V2 corrigiu:
  //                   revogação sem efeito, porque `req.auth.token` chega
  //                   preenchido mesmo com a sessão revogada
  // prova ........... o registro de encerramento passa pela conferência
  //                   compartilhada, e não lê o claim do motor por conta própria
  test('o encerramento delega a conferencia, e nao le o claim do motor', () => {
    const rel = 'functions/src/rastreabilidade.ts';
    const src = A.codigo(rel);

    A.exigirAncora(assert, src, /\bconferirAutoridadeDePartida\s*\(/, `${rel} delega a conferencia`);
    A.exigirAncora(assert, src, /\bverificadorComRevogacao\s*\(/, `${rel} usa o verificador com revogacao`);
    A.exigirAncora(assert, src, /\bregistrarEncerramentoPartida\s*=/, `${rel} registra o encerramento`);

    // A regressão é específica: decidir a autoridade DO MOTOR pelo claim que
    // chega em `req.auth`. O `admin` continua podendo ser lido assim — ele é
    // outra coisa, e é o próprio arquivo que o usa para suporte.
    for (const linha of src.split('\n')) {
      if (!/req\.auth\?\.token|req\.auth\.token/.test(linha)) continue;
      assert.ok(
        !linha.includes('motorDePartidas'),
        `${rel}: "${linha.trim()}" decide a autoridade do motor por \`req.auth.token\`. ` +
          'E exatamente o defeito que a credencial V2 corrigiu: o claim chega ' +
          'preenchido mesmo depois de `revokeRefreshTokens`.'
      );
    }
  });
});

// ---------------------------------------------------------------------------
// PN-15
// ---------------------------------------------------------------------------

describe('PN-15 — a prova de SHA aceitando valor manual', () => {
  // invariante ...... o SHA carimbado no artefato sai de `git rev-parse HEAD`,
  //                   e de mais nada
  // autoridade ...... ferramentas/proveniencia/
  // proibido ........ um operador digitar o SHA que depois será "provado" — a
  //                   prova passaria a atestar o que alguém quis dizer, e não o
  //                   que foi implantado
  // prova ........... o gerador recusa argumento e ambiente; e os dois passos
  //                   estão no `predeploy` de TODAS as codebases, para que
  //                   ninguém implante sem passar por eles
  //
  // Amarra o §16 ao §19 de propósito: sem esta prova, o §16 seria uma ferramenta
  // que existe, e não uma ferramenta que o deploy é obrigado a atravessar.
  test('o gerador recusa SHA por argumento e por ambiente', () => {
    const { spawnSync } = require('node:child_process');
    const GERAR = path.join(A.RAIZ, 'ferramentas', 'proveniencia', 'gerar.js');
    assert.ok(fs.existsSync(GERAR), 'ANCORA PERDIDA: o gerador de proveniencia sumiu');

    const porArg = spawnSync(process.execPath, [GERAR, '--sha', 'e'.repeat(40)], {
      cwd: A.RAIZ,
      encoding: 'utf8',
      shell: false,
    });
    assert.notEqual(porArg.status, 0, 'o gerador aceitou um SHA por argumento');

    const limpo = Object.assign({}, process.env);
    for (const k of require('../proveniencia/gerar.js').AMBIENTE_PROIBIDO) delete limpo[k];
    const porEnv = spawnSync(process.execPath, [GERAR], {
      cwd: A.RAIZ,
      encoding: 'utf8',
      shell: false,
      env: Object.assign(limpo, { PROVENIENCIA_SHA: 'f'.repeat(40) }),
    });
    assert.notEqual(porEnv.status, 0, 'o gerador aceitou um SHA por ambiente');
  });

  test('nenhuma codebase pode ser implantada sem atravessar a proveniencia', () => {
    for (const { codebase, predeploy } of CODEBASES) {
      assert.deepEqual(
        (predeploy || []).slice(0, 2),
        ['node ferramentas/proveniencia/gerar.js', 'node ferramentas/proveniencia/verificar.js'],
        `${codebase}: o deploy nao atravessa a proveniencia. Sem isso o mecanismo do ` +
          '§16 existe e e OPCIONAL, que e o mesmo que nao existir.'
      );
    }
  });
});
