# Backfill de `purchaseTokenHash` a partir de `compras/{hash}` — v1

**Estado: MECANISMO PRONTO, NENHUMA ESCRITA EXECUTADA.**

Este documento descreve um mecanismo projetado, implementado e homologado
tecnicamente. Ele **não foi executado** contra dado nenhum de produção, e a OS
que o produziu não autorizava executá-lo. O que existe é a capacidade de decidir,
depois do censo real, se e quando executar.

| | |
|---|---|
| Branch | `claude/backfill-purchasetokenhash-4f3365` |
| Base | `e9c2aa1` (`claude/legacy-vip-population-diagnosis-fc64f7`) |
| Módulos novos | `functions-billing/backfillHash.js`, `functions-billing/backfillHashStore.js` |
| Callable | `backfillPurchaseTokenHash` (só admin, dry-run por padrão) |
| Testes | `test/backfillHash.test.js` (50), `test/backfillEfeitos.test.js` (20) |
| Deploy | nenhum |
| Backfill real | nenhum |

---

## A. Por que `compras/{hash}` é fonte válida

`chaveDaCompra` (`entitlementStore.js:53`) é `sha256(token)` em hex, e **o
resultado dela é o id do documento** de `compras/{hash}`. Isso vale desde
`fe4cdb5`, o commit que criou este codebase: a mesma transação que gravava
`usuarios/{uid}.vip = true` gravava `compras/{sha256(token)}` com o `uid` do
comprador, o `produtoId`, `assinatura`, `estado` e — na concessão — o bloco
`concessao` com `vipExpiraEm` e `planoBase`.

O valor recuperado não é reconstrução, aproximação ou palpite: é **exatamente o
mesmo valor que `chaveDaCompra` produziria** se o token estivesse à mão. Ele é
lido de onde sempre esteve — a chave do documento —, e não derivado de nada.

A migração grava `purchaseTokenHash: null` (`migracaoLegado.js:122`) sobre um
dado que existe. O cabeçalho de `migrarEntitlementsLegado` justifica isso dizendo
que `compras/` guarda o hash e nunca o token, e portanto não há como reconsultar
a Google. **A primeira metade é verdade; a conclusão não cobre o campo que ela
apaga** — ver a seção B.

## B. Hash × token: são campos diferentes e servem a coisas diferentes

Foi a confusão entre os dois que fez a ficha mensal do migrado parecer
irreparável em duas OS seguidas.

| | `purchaseTokenHash` | `purchaseToken` |
|---|---|---|
| O que é | identificador persistido | credencial de consulta |
| Onde mora | `interno/billing.purchaseTokenHash` | `interno/billing.purchaseToken` |
| Serve para | chavear `fichasConcessoes/{hash}_{indice}`; identificar titularidade em `mesmoToken` | perguntar o estado à Play Developer API |
| Recuperável do legado? | **sim** — é o id de `compras/{hash}` | **não** — nunca foi gravado para compra antiga |
| Quem precisa dele | `concederFichasMensais`, `decidirAtualizacao` | `reconciliarEntitlementDoJogador` |

`concederFichasMensais` **não usa o token**. Ela usa o hash, e só ele, para montar
a chave determinística do livro-razão. Por isso a perda da ficha mensal do
migrado é evitável, e a impossibilidade de reconsultar a Google não é.

## C. Critério AUTO — a regra exata

Implementada em `classificarBackfill` (`backfillHash.js`), pura, sem I/O, e usada
**pelos três caminhos**: dry-run, execução real e a revalidação dentro da
transação de escrita. Não há uma segunda implementação de elegibilidade
(fixado em `BFH-44`).

Um uid é **AUTO** quando as oito perguntas passam, nesta ordem:

1. existe `playerEntitlements/{uid}` (há onde gravar);
2. existe `playerEntitlements/{uid}/interno/billing` (o backfill não inventa documento);
3. o valor já gravado, se houver, tem forma de sha256 hex (`/^[0-9a-f]{64}$/`);
4. `purchaseTokenHash` está **ausente**;
5. a correlação com `compras/` foi executada;
6. nenhum registro devolvido para este uid pertence a outro titular;
7. existe **exatamente um** `compras/{hash}` *atribuível* a este uid, e ele está
   `concedida`;
8. o token em claro, se existir no documento, **concorda** com esse hash.

**"Atribuível" é definido como o critério de `titularDoToken`** — `dados.uid ===
uid` e `dados.assinatura === true` —, e essa escolha é o que fecha o risco de
regressão descrito na seção E. `titularDoToken` (`entitlementStore.js:161`) é o
portão por onde **toda RTDN passa** antes de chegar a `decidirAtualizacao`: uma
notificação só encontra dono se existir `compras/{hash}` com `uid` e
`assinatura: true`. Logo, se este uid tem um só `compras/` atribuível, toda RTDN
capaz de alcançar o entitlement dele carrega **esse mesmo hash**.

Note a assimetria deliberada entre os passos 7 e a contagem: `estado:
'concedida'` **não** entra na definição de "atribuível". Uma compra parada em
`em_validacao` não serve de fonte (não provou ter concedido direito), mas **ainda
conta para a ambiguidade**, porque `titularDoToken` não olha o estado e ela ainda
pode trazer uma RTDN. Excluí-la da contagem faria um uid com duas compras parecer
inequívoco e reabriria exatamente o risco que o parágrafo acima fecha. Fixado em
`BFH-08`.

### O que é proibido, e onde a proibição é verificável

Nenhum hash é gerado, derivado ou escolhido. O único valor gravado é o
`documentId` de `compras/{hash}`:

- não há hash derivado de uid (`BFH-02`);
- não há placeholder, UUID ou valor sintético (o formato é conferido e a fonte é
  a chave do documento);
- não há re-hash de informação não equivalente ao token (o token em claro só
  **desmente**, nunca cria um AUTO — `BFH-18`);
- não há seleção arbitrária entre candidatos (`BFH-04`, `BFH-05`).

### Divergência deliberada em relação ao diagnóstico

`diagnosticoPopulacao.js` **desempata** dois candidatos comparando
`compras/{hash}.concessao.vipExpiraEm` com o prazo do legado. Este módulo **não
desempata**: dois candidatos são AMBÍGUO, sempre (`BFH-05`).

As duas perguntas não merecem o mesmo limiar. O diagnóstico **conta** quantos
hashes são recuperáveis em princípio; o backfill **grava** em documento de
pagante. Um desempate que acerta em 99% dos casos chaveia o livro-razão do 1%
restante na assinatura errada, para sempre.

## D. Ambiguidades — como cada uma é tratada

As classes são exclusivas e cobrem todo o universo varrido: a soma fecha com
`examinados` (`BFH-25`). **Somente `AUTO` é candidata a escrita.**

| Classe | Situação | Tratamento |
|---|---|---|
| `AUTO` | correlação inequívoca | único caso gravável |
| `AMBIGUO` | 2+ compras atribuíveis | contado; nunca escrito; exige decisão humana |
| `CONFLITO` | o que está gravado discorda das fontes históricas | contado; **nunca sobrescrito**; caso a caso |
| `SEM_FONTE` | nenhum `compras/` correlacionável, ou a única não foi concedida | contado; para este jogador o hash não existe nesta árvore |
| `JA_PREENCHIDO` | já tem hash e nada o contradiz | intocado |
| `FORA_DO_ESCOPO` | não há entitlement ou não há documento interno | intocado |
| `NAO_INVESTIGADO` | a correlação não rodou | **não** vira "sem fonte" — a ausência de investigação é declarada |

`CONFLITO` cobre cinco situações distintas, cada uma com `motivo` próprio: hash
gravado fora de formato; hash gravado que não está em `compras/`; hash gravado
que discorda do token em claro; candidato que discorda do token em claro; e
registro de compra de outro titular no lote. Nenhuma delas produz escrita.

## E. Impacto em `mesmoToken` — antes e depois

`mesmoToken` (`entitlement.js:348` e `:419`) governa três decisões. A tabela
abaixo é o mesmo conteúdo de `IMP-20`, que a verifica caso a caso — se o
comportamento mudar, o teste quebra junto com este documento.

### O que o campo nulo significa hoje

Um entitlement **sem** hash não tem, hoje, nenhuma das duas proteções:

- **titularidade**: `if (!mesmoToken && fonte !== 'validacao') { if
  (atual.purchaseTokenHash) ... }` não dispara quando o campo é nulo. Um evento
  de **qualquer** token entra (`IMP-01`);
- **desfecho terminal**: `terminalVigente` exige `mesmoToken`, que com hash nulo
  é sempre falso. Uma leitura atrasada que ainda diga `ACTIVE` **ressuscita um
  direito estornado** (`IMP-02`).

Preencher o hash **liga as duas**.

### Os quatorze cenários

| # | Cenário | Antes | Depois | Mudou? |
|---|---|---|---|---|
| 1 | entitlement legado sem hash | `estado_atualizado` | `estado_atualizado` | — |
| 2 | hash preenchido com correspondente histórico | `estado_atualizado` | `estado_atualizado` | — |
| 3 | evento posterior do mesmo token/hash | `estado_atualizado` | `estado_atualizado` | — |
| 4 | evento de token diferente | `estado_atualizado` | `token_superado` | **sim, restringe** |
| 5 | renovação | `estado_atualizado` | `estado_atualizado` | — |
| 6 | cancelamento | `estado_atualizado` | `estado_atualizado` | — |
| 7 | revogação | `terminal` | `terminal` | — |
| 8 | reembolso | `terminal` | `terminal` | — |
| 9 | RTDN atrasada | `verificacao_antiga` | `verificacao_antiga` | — |
| 10 | evento duplicado | `verificacao_antiga` | `verificacao_antiga` | — |
| 11 | evento fora de ordem | `verificacao_antiga` | `verificacao_antiga` | — |
| 12 | entitlement expirado | `estado_atualizado` | `estado_atualizado` | — |
| 13 | entitlement ativo | `estado_atualizado` | `estado_atualizado` | — |
| 14 | hash conflitante sobre estado terminal | `estado_atualizado` | `token_superado` | **sim, restringe** |

**Dois de quatorze mudam de veredito, os dois na direção restritiva, e os dois
envolvem um token que não é o do direito.**

### As respostas que a OS pede

**O backfill passa a fazer o sistema considerar o evento como `mesmoToken`?**
Sim, para os eventos da assinatura correlacionada — que são, pelo argumento da
seção C, os únicos que conseguem alcançar aquele entitlement por RTDN.

**Isso é desejado?** Sim. É o comportamento que o desenho sempre pretendeu: o
direito é identificado pelo token, e o migrado estava sem identidade.

**Alguma atualização antes aceita passa a ser ignorada?** Sim — cenários 4 e 14:
evento de um token que **não** é o do direito. Antes eram aceitos porque a
ausência de hash desligava o portão de titularidade; passam a ser recusados com
`token_superado`.

**Alguma antes ignorada passa a ser aceita?** Não. `IMP-21` varre exaustivamente
6 estados atuais × 6 estados propostos × 4 fontes × 2 hashes × 3 carimbos (864
combinações) e afirma que **zero** delas sai de recusado para aceito. O backfill
só restringe.

**Há risco de ressuscitar direito?** Não — o risco existe **hoje** e o backfill o
**fecha** (`IMP-02`, `IMP-16`, `IMP-17`). Um estorno gravado sobre entitlement sem
hash é reversível por leitura atrasada; com hash, `terminal_preservado` o segura.

**Há risco de bloquear renovação?** Não, por dois caminhos independentes:
(a) a renovação da mesma assinatura traz o mesmo `purchaseToken`, logo o mesmo
hash (`IMP-14`); (b) uma reassinatura com token novo chega por
`validarCompraPlay`, e `fonte: 'validacao'` atravessa `token_superado` por
desenho (`IMP-13`). Uma RTDN de token novo só alcançaria o entitlement se
existisse `compras/{hash}` para ela — e nesse caso o uid teria dois candidatos e
**não** seria AUTO.

**Há risco de afetar cancelamento/revogação?** Não. Cancelamento continua não
tirando acesso (o prazo é que manda — `IMP-15`); revogação e reembolso continuam
entrando e passam a ser **irreversíveis**, que é o comportamento correto.

**Há risco de duplicar ficha?** Não. A barreira é
`fichasConcessoes/{hash}_{indice}`, criada na **mesma transação** que credita o
saldo (`fichasStore.js`). Um hash preenchido cria linhas **novas** para parcelas
que nunca foram pagas; ele não pode recriar uma linha existente. `IMP-32` prova
que reexecutar não duplica e que períodos diferentes geram concessões distintas.

### Fichas mensais: o antes e o depois

| | Antes do backfill | Depois |
|---|---|---|
| entitlement válido | sim | sim |
| `purchaseTokenHash` | ausente | hash histórico verdadeiro |
| chave determinística | não existe | `fichasConcessoes/{hash}_{indice}` |
| concessão mensal | **não** (ramo `semPlano`) | **sim** |
| reexecução | — | não duplica |
| períodos distintos | — | concessões distintas |

Fixado em `IMP-30` (antes), `IMP-31` (depois) e `IMP-32` (idempotência e
períodos). **Nenhuma política comercial foi alterada**: os valores continuam
vindo de `configuracao/billing`.

## F. Achado bloqueante: o hash é necessário e **não é suficiente**

`IMP-33`. Para o direito **migrado**, preencher o hash sozinho **não** restaura a
ficha mensal. `migrarPaginaDeLegado` grava `inicioEm: null` e não grava
`planoBase`, e cada ausência bloqueia por um caminho diferente:

| Campo ausente | Efeito em `concederFichasMensais` | Visível? |
|---|---|---|
| `purchaseTokenHash` | ramo `semPlano` | sim, contado |
| `planoBase` | `planoDoCatalogo` devolve `null` → `semPlano` | sim, contado |
| `inicioEm` | `mesesDecorridos` devolve `-1` → nenhum índice vence | **não** — nem `semPlano` acusa |

O dry-run **mede** isso: `resumo.autoAptoAFicha` conta os AUTO que ficariam de
fato aptos, e `resumo.autoSemPlanoOuInicio` conta os que não (`BFH-46`). Um
relatório que dissesse apenas "N seriam preenchidos" seria lido como "N voltam a
receber ficha", e a diferença entre as duas frases é a decisão inteira.

Os dois campos são recuperáveis da **mesma fonte** —
`compras/{hash}.concessao.planoBase` existe desde `fe4cdb5`, e `criadoEm` aproxima
`inicioEm` —, mas preenchê-los está **fora do escopo desta OS**, que autoriza
exclusivamente `purchaseTokenHash`. Fica registrado como gate: **prometer a ficha
mensal ao jogador migrado depende de uma segunda decisão, não deste backfill.**

## G. Plano de execução futura

Nada abaixo foi executado.

**0. Pré-requisitos** — o backfill depende de deploy de `functions-billing`, e o
deploy está bloqueado pelos mesmos gates de sempre (secret, catálogo
`configuracao/billing`, tópico RTDN). O censo real (`diagnosticarPopulacaoVip`)
também nunca rodou pelo mesmo motivo.

**1. Dry-run real.** `backfillPurchaseTokenHash` sem argumento nenhum. Zero
escrita, garantida estruturalmente. Produz: examinados, as sete classes, motivos,
já corretos, seriam alterados, permaneceriam intocados, `autoAptoAFicha`, cursor
e `esgotou`.

**2. Comparação com o censo.** O `AUTO` daqui deve ser um **subconjunto** do
`HASH_RECUPERAVEL_DE_COMPRAS` do diagnóstico — este módulo é estritamente mais
conservador (não desempata, exige `concedida`, exige `uid` explícito). Se o
backfill classificar mais AUTO que o diagnóstico classificou recuperáveis, há
divergência a investigar **antes** de escrever.

**3. Lote piloto.** `modo: 'escrever'`, `confirmacao:
'EXECUTAR_BACKFILL_PURCHASETOKENHASH'`, `maxEscritas: 10`. A varredura para no
teto, devolve `esgotou: false` e o cursor exato de retomada (`BFH-37`).

**4. Validação do piloto.** Conferir, nos dez: o hash gravado é o id de
`compras/{hash}` daquele uid; `purchaseTokenHashOrigem === 'backfill_compras'`; o
documento **público** não mudou; e o tick seguinte de `concederFichasMensais`
liquidou as parcelas devidas sem duplicar.

**5. Expansão.** Aumentar `maxEscritas` por lotes, retomando pelo cursor. Um
segundo passe sobre a mesma faixa não altera nada (`BFH-34`, `BFH-35`).

**6. Rollback e contingência.** A marca `purchaseTokenHashOrigem:
'backfill_compras'` torna todo valor escrito por esta operação identificável —
sem ela, desfazer exigiria adivinhar quais campos vieram daqui. O rollback é
apagar `purchaseTokenHash` onde a marca estiver presente, o que devolve o
documento ao estado anterior exato (nenhum outro campo é tocado). Duas ressalvas
honestas: (a) parcelas de ficha já liquidadas **não** são desfeitas pelo rollback
— elas são crédito ao jogador, e o livro-razão as protege de repetição, não de
reversão; (b) se um evento posterior já tiver sobrescrito o hash pela via normal,
a marca terá sido substituída junto, e aquele documento não é mais um caso de
rollback.

---

## Proteções da execução real

| Camada | Mecanismo |
|---|---|
| Autenticação | `request.auth.token.admin !== true` → `permission-denied` |
| Modo padrão | dry-run por **omissão**; ler não exige argumento nenhum |
| Escrita | exige `modo: 'escrever'` **e** `confirmacao` com a frase exata |
| Acidente | um `modo` sem a confirmação → `failed-precondition`, sem escrita |
| Estrutural | a porta de escrita só é **construída** quando as duas condições passam; sem ela `backfillHash.js` não tem expressão capaz de escrever (`BFH-43`) |
| Autorização × existência | o claim de admin abre a função; a frase abre a escrita. Quem tem o primeiro não ganha o segundo |
| Logs | contagens e `rotuloHash` (8 caracteres). Nenhum uid, nenhum token, nenhum hash inteiro (`BFH-22`) |
| Escopo da escrita | 3 campos, `merge: true`, só no documento **interno**. O público não é tocado (`BFH-33`) |

## Idempotência, paginação e concorrência

- **Idempotente por precondição relida na transação**, e não por memória: o
  gravador rele `publico`, `interno` e `compras/{hash}` **dentro** do commit e
  reaplica a regra. Um campo já preenchido nunca é sobrescrito — nem pelo mesmo
  valor, nem por outro (`BFH-38`, `BFH-39`).
- **Segunda execução não altera nada**: o banco sai idêntico documento a
  documento e versão a versão (`BFH-34`, `BFH-35`).
- **Interrupção parcial retoma** pelo cursor, sem duplicar e sem pular
  (`BFH-36`). O cursor de parada é o último documento **concluído**, e não o
  último visitado — do contrário o teto de escritas pularia em silêncio o AUTO
  que não chegou a ser gravado.
- **Tamanho de página não muda resultado**: verificado com 1, 2, 7, 53, 54 e 500
  sobre a mesma base (`BFH-27`).
- **Paginação por cursor sobre `documentId()`**, ordem estável, parada por
  **esgotamento**. Nenhum `.limit(N)` isolado como teto. Fronteiras testadas em
  0, 1, 199, 200 e 201, derivadas de `TAMANHO_PAGINA` (`BFH-26`).
- **Teto declarado, nunca silencioso**: `esgotou: false` + `cursor` + `parada`
  (`teto_de_paginas` ou `teto_de_escritas`) — `BFH-28`, `BFH-37`.
- **Concorrência**: duas execuções simultâneas disputam a transação; exatamente
  uma grava e a outra recusa com `ja_preenchido`, sem corrupção (`BFH-40`). Uma
  compra validada no meio do caminho **vence** o backfill e não é sobrescrita
  (`BFH-41`).
- **Falha no commit não deixa escrita parcial** (`BFH-42`).

## Testes

| Suíte | Antes | Depois |
|---|---|---|
| `functions-billing` (`npm test`) | 179 | **249** |
| `functions-billing` (`node --test`, como o CI de release) | 180 | **250** |

70 casos novos: 50 em `backfillHash.test.js` (BFH-01..BFH-47, com BFH-26 e BFH-27
parametrizados) e 20 em `backfillEfeitos.test.js` (IMP-01..IMP-34).

**Rules e Dart não foram executados, e não foram tocados.** `firestore.rules` não
mudou: `playerEntitlements/{uid}/interno/**` já é `allow read, write: if false`
para cliente e para admin, e só o Admin SDK alcança — que é exatamente o caminho
deste backfill. Nenhum arquivo Dart foi alterado: o campo não atravessa a
fronteira do cliente (`purchaseTokenHash` mora no documento interno, que o
jogador não lê), e o documento público sai desta operação byte a byte igual
(`BFH-33`).
