# Homologação adversarial do RTDN/VIP — P0

**Veredito: `FAIL — RTDN/VIP VIOLA IDEMPOTÊNCIA, AUTORIDADE, CICLO DE VIDA OU SEGURANÇA`**

O motivo do `FAIL` é **um achado Alto**, e só um: a titularidade de uma compra
nasce no primeiro `validarCompraPlay` que apresentar o token, sem nenhuma amarra
entre a compra da Google e a conta do aplicativo. Pela seção 10 da OS, achado
Alto não pode ser classificado como risco residual não bloqueante.

Isso precisa ser lido junto com o resto, porque o resto passou. Idempotência sob
reentrega e sob concorrência, regra de ordem, ciclo de vida completo da
assinatura, atomicidade da consolidação e redação de segredo resistiram a 65
testes escritos para quebrá-los — e as dez proteções críticas foram provadas
**necessárias**, uma a uma, desligando cada uma e exigindo vermelho. O desenho
está certo. O que falta é uma amarra que nunca foi construída.

---

## 1. Identificação

| | |
| --- | --- |
| OS | Homologação adversarial do RTDN/VIP — P0 |
| Repositório | `soniaambrosio/buraco-master-vip-app` |
| Base | `origin/integracao/rtdn-vip-producao` |
| SHA da base | `a2622d59c09156e1e9fb80aa52d0a6fc51b3c9f9` |
| Branch de saída | `homologacao/rtdn-vip-adversarial-p0` |
| Ancestral exigido | `bcb55c7512bd64bb33aaae984f8c0c7647a5a820` (`correcao/p0-elegibilidade-vip-lifecycle`) |
| Ancestralidade | **confirmada** — `merge-base` devolve o próprio `bcb55c7`, a 3 commits da base |

### Gate zero

Duas leituras independentes de `git ls-remote`, ambas antes de qualquer edição:

```
a2622d59c09156e1e9fb80aa52d0a6fc51b3c9f9  refs/heads/integracao/rtdn-vip-producao
```

A OS registra que um quadro anterior citou `b2c3d91` como topo desta branch. A
ref remota não aponta para esse valor em nenhuma das duas leituras. O SHA
comprovado foi usado, e `b2c3d91` não foi procurado nem seguido.

**Baseline histórico, conferido antes de editar qualquer arquivo:**

```bash
node --test test/idempotencia.test.js test/entitlement.test.js test/rtdn.test.js
```

`79 testes, 79 pass, 0 fail, 0 skip, 234 ms`. Reproduz o baseline declarado.

---

## 2. Mapa do fluxo, da notificação ao direito

```
Google Play
    │  Real-time Developer Notification (Pub/Sub, entrega "pelo menos uma vez")
    ▼
tópico play-billing-rtdn
    │  Eventarc
    ▼
notificacoesPlay  (index.js:516)  ── retry: true
    │  messageId := message.messageId ?? event.id
    ▼
rtdn.processarNotificacao  (rtdn.js:84)
    │
    ├─ 1. base64 → JSON .................... falhou? corpo_ilegivel, sem log do conteúdo
    ├─ 2. interpretarNotificacao ........... pacote alheio / teste / avulso → ignorar
    ├─ 3. purchaseToken presente? .......... não → sem_token
    ├─ 4. eventoConcluido(messageId) ....... atalho barato, ANTES de gastar rede
    ├─ 5. titularDoToken(sha256(token)) .... compras/{hash} → uid, ou descarta
    │
    ├─ 6a. TERMINAL (revogação / anulação)
    │      consolidarTerminal → aplicarProposta      ── NÃO consulta a Google
    │
    └─ 6b. ECONÔMICO (todo o resto, inclusive tipo desconhecido)
           reconciliador.reconsultarEAplicar  (reconciliacao.js:57)
               │  consultadoEm := agora()      ← ANTES da rede, de propósito
               │  resposta := Play.subscriptionsv2.get(token)
               │  consolidarAssinatura(resposta, consultadoEm)
               ▼
           store.aplicarProposta  (entitlementStore.js:94)
               │  UMA transação:
               │    lê playerEntitlements/{uid}, .../interno/billing, billingEvents/{id}
               │    evento já concluído?         → sai sem efeito
               │    decidirAtualizacao(atual, proposta)   (entitlement.js:321)
               │    grava público + interno + evento, ou nenhum dos três
               ▼
           playerEntitlements/{uid}          o dono lê
           playerEntitlements/{uid}/interno/billing   ninguém lê (regra: if false)
           billingEvents/{messageId}         só admin lê
```

Três outras entradas alimentam o mesmo núcleo: `validarCompraPlay` (renovação
chegando pelo app), `reconciliarEntitlementDoJogador` (saída de emergência
administrativa) e `reconciliarEntitlements` (varredura por relógio, a única que
**não** consulta a Google — ela conclui pelo prazo que a Google já informara).

## 3. Tabela de autoridades

| Pergunta | Quem responde | Onde |
| --- | --- | --- |
| A assinatura está válida agora? | **Google Play Developer API** | `purchases.subscriptionsv2.get` |
| A compra foi estornada/revogada? | **payload da notificação** — a consulta de estado não expressa estorno | `interpretarNotificacao`, `consolidarTerminal` |
| De quem é este `purchaseToken`? | **`compras/{hash}`**, gravado com o uid autenticado | `titularDoToken` |
| Quem é o chamador? | **Firebase Auth**, via `request.auth.uid`; nunca o payload | `index.js:236` |
| Quanto vale cada produto? | **`configuracao/billing`**, no servidor; nunca o payload | `lerCatalogo` |
| Esta proposta entra? | **`decidirAtualizacao`**, com o documento relido dentro da transação | `entitlement.js:321` |
| O jogador tem VIP neste instante? | **o consumidor**, combinando estado e prazo | `app/lib/elegibilidade/` |
| Já processei esta mensagem? | **`billingEvents/{messageId}`**, escrito na mesma transação do efeito | `entitlementStore.js:124` |

Uma autoridade **ausente**, e é o achado A-1: nada responde *"esta compra
pertence a esta conta?"*. A pergunta é respondida por ordem de chegada.

## 4. O modelo dos falsos

Nenhuma peça de infraestrutura real é tocada. Tudo em `functions-billing/test/apoio/`.

| Falso | O que modela | O que deliberadamente não modela |
| --- | --- | --- |
| `play_falsa.js` | resposta por token, os 9 estados de assinatura, produto avulso, `acknowledge`/`consume`, falha transitória e permanente como exceção, latência, contagem de chamadas | OAuth, rede, formato real de erro da Gaxios |
| `firestore_adversarial.js` | estende o `firestore_falso.js` histórico: concorrência otimista, recusa de leitura-após-escrita, retry limitado — mais diário de escritas, falha no commit, commit truncado, orçamento de retry configurável, consulta e `FieldValue` | regra de segurança, índice composto, transação distribuída |
| `relogio_falso.js` | instantes ditados, para que consulta lenta possa terminar depois de consulta rápida | — |
| `carga_index.js` | `index.js` carregado de verdade, com `firebase-admin` e `googleapis` plantados no `require.cache` | `firebase-functions` é o **pacote real**, de propósito |
| `armadilha_de_rede.js` | `http`, `https`, `net`, `dns` e `fetch` substituídos por versões que lançam | — |

Duas decisões merecem destaque, porque são o que separa este harness de um mock:

**O Firestore falso não devolve o que o teste mandar.** Ele implementa
concorrência otimista de verdade: cada documento tem versão, a transação anota o
que leu, e no commit descarta o trabalho inteiro se alguma versão mudou. É por
isso que "reler o documento dentro da transação" significa alguma coisa nos casos
Q e U — sem isso, um teste de corrida provaria apenas que o autor sabia o
resultado que queria.

**O `index.js` é o real.** Até esta OS ele era o único arquivo do codebase sem
teste, porque importa `firebase-functions`, `firebase-admin` e `googleapis`, e a
suite roda sem `node_modules` de propósito. Plantar as três dependências no
`require.cache` antes de carregá-lo destravou o catálogo de produtos, o crédito de
fichas, a ordem "creditar antes de consumir", as duas varreduras administrativas e
os logs daquele arquivo — que são exatamente os casos A, N, O, V e W da matriz.
Nenhuma linha de produção mudou; mudou o que existe do outro lado do `require`.

Todos os tokens do harness começam com `token_sintetico_`. Nenhum `purchaseToken`
da Google tem esse formato, então a varredura por segredo no diff nunca precisa
julgar se aquilo era credencial de verdade.

---

## 5. Matriz A–W

`✅` = comportamento exigido, provado. `⚠️` = comportamento correto, com
observação registrada. `❌` = defeito.

| | Caso | Resultado | Evidência e o que resistiu |
| --- | --- | --- | --- |
| **A** | Concessão inicial válida | ✅ | `A`, `A2`. Uma concessão, ao uid autenticado e ao produto do catálogo; `U2` intocado; `acknowledge` **depois** do crédito. Consumível credita as fichas do servidor (1000) e ignora as do payload (999999). |
| **B** | Reentrega do mesmo `messageId` | ✅ | `B`, `B2`. Três reentregas: 1 consulta à Google, 1 escrita de cada documento, 1 evento. `B2` cobre o caso em que o atalho não ajuda — duas entregas do mesmo id **em voo ao mesmo tempo**, com carimbos diferentes; só a barreira transacional segura. |
| **C** | Mesmo token, `messageId` diferente | ⚠️ | `C`, `C2`. Estorno reempacotado → `terminal_repetido`, uma escrita, `terminalEm` imóvel, zero consultas. No caso **econômico** o estado converge, mas o documento é regravado (**OBS-2**). |
| **D** | Evento antigo depois do novo | ✅ | `D`, `D2`. Nos dois sentidos: o atrasado não rebaixa (`vipAtivo` fica `true`, prazo intacto, zero escritas) e não ressuscita um direito já encerrado. |
| **E** | Renovação | ✅ | `E`. Prazo anda para a frente, um único documento de direito, token inalterado. |
| **F** | Cancelamento com vigência restante | ✅ | `F`, `F2`. `cancelado_vigente` mantém acesso até o prazo; com o período já vencido vira `expirado`. |
| **G** | Carência | ✅ | `G`. Dentro do prazo concede; **vencida não vira ativo eterno** — cai em `expirado`. |
| **H** | Account hold | ✅ | `H`, `H2`. Partindo de `ativo/true` com prazo futuro: o hold produz `em_espera` e `vipAtivo: false`. Não herda o estado anterior. Pausa idem. |
| **I** | Recuperação | ✅ | `I`. `RECOVERED` com a Google ainda dizendo `ON_HOLD` **não** concede. Só depois da confirmação autoritativa o direito volta, e o token é preservado. |
| **J** | Expiração | ✅ | `J`, `J2`. Encerra uma vez; a trilha dos eventos anteriores continua inteira e o token permanece guardado. A varredura por relógio fecha o vencido **sem reescrever o prazo** e sem tocar em quem está vigente. |
| **K** | Revogação / reembolso | ✅ | `K`, `K2`. Encerra **agora**, não no fim do período pago; zero consultas; `U2` e o outro produto intocados. Leitura atrasada dizendo `ACTIVE` → `terminal_preservado`. |
| **L** | Payload ausente ou malformado | ✅ | `L` (7 variantes), `L2`. Rejeição sem mutação, sem crash, sem conteúdo do payload em log. Payload truncado no meio do token não imprime o token. |
| **M** | Lookup por token sem `productId` | ✅ | `M`, `M1`, `M2`. Resolve pelo registro da compra; sem produto em lugar nenhum, grava `null` — não inventa. |
| **N** | Produto desconhecido | ✅ | `N`, `N2`, `N3`, `N4`. Recusa **antes** de gravar `compras/` e antes de perguntar à Google; catálogo vazio recusa tudo; tipo divergente recusado; token que não é de assinatura não produz entitlement. |
| **O** | Datas e vigências inválidas | ⚠️ | `O` (8 variantes), `O2`, `O3` (5), `O4` (5). Ausente, vazia, negativa, `NaN`, objeto, no passado: nenhuma concede. Estado que a plataforma ainda não inventou → `desconhecido`, sem acesso. **Elemento nulo em `lineItems` derruba a consolidação — achado M-1** (`O2b`). |
| **P** | Timeout / erro transitório | ✅ | `P`, `P2`, `P3`. A exceção **sobe** (é isso que vira reentrega), o estado anterior fica, e o evento **não** é marcado concluído. Duas falhas seguidas de sucesso: uma escrita só. Na validação, não concede e não marca a compra como recusada. |
| **Q** | Concorrência sobre o mesmo token | ✅ | `Q`, `Q2`, `Q3`. Corrida de 2 com interleaving determinístico: vence quem **consultou** por último, não quem commitou por último. 10 simultâneas convergem. 10 validações do mesmo consumível creditam **1000 fichas, não 10000**. |
| **R** | Token já vinculado a outro usuário | ❌ | `R`, `R2`, `R3`, `R4`, `R5` provam a metade que funciona: vínculo existente não troca de dono, produto e tipo divergentes recusados, notificação alheia não encosta no titular, token sem dono descartado, chamada anônima barrada. **`R6` prova a metade que falta — achado A-1.** |
| **S** | Redação de segredo | ✅ | `S`, `S2`, `S3`. Em quatro caminhos (sucesso, terminal, sem titular, payload ilegível): nem token nem hash inteiro em log, trilha ou documento do cliente. Trilha guarda rótulo de 8 caracteres. Nenhuma resposta de callable devolve token. A credencial sintética não alcança o Firestore. |
| **T** | Reconciliação idempotente | ✅ | `T`, `T2`, `T3`, `T4`, `T5`. Três reconciliações administrativas não mudam o estado econômico. Três varreduras por relógio fecham **uma vez** e param. A migração do legado não regrava e **não sobrescreve fato já confirmado pela Google**. As duas administrativas recusam não-admin e anônimo. |
| **U** | Reconciliação concorrente com RTDN | ✅ | `U`, `U2`. As duas ordens de chegada produzem estado final **idêntico**, e vence a consulta mais nova. Sob contenção real, a mais nova não é perdida. |
| **V** | Usuário ou documento ausente | ✅ | `V`, `V2`, `V3`, `V4`. Sem pré-cadastro não inventa titular nem escreve nada; registro sem uid não produz direito; reconciliação sem token falha explicitamente; o uid vem do Auth, não do payload que tenta ditá-lo. |
| **W** | Falha parcial e atomicidade | ✅ | `W`, `W2`, `W3`. Falha no commit: **zero** escritas — nem direito, nem trilha. A reentrega converge com efeito único. O evento não é marcado concluído sem o efeito. Falha no fechamento junto à Google não derruba compra já creditada. |

Fora da matriz, quatro testes de fronteira: `X1` (o Billing não escreve em
moderação, torneio, ranking ou partida), `X2` (cinco exports, `us-central1`,
`gcfv2`, tópico `play-billing-rtdn`, `retry: true`, segredo só para quem fala com
a Play), `X3` (origem da notificação) e `X4` (rede e portas).

---

## 6. Não-vacuidade

Um teste verde prova uma de duas coisas: que a proteção funciona, ou que o teste
nunca chegou perto dela. Cada proteção crítica foi **desligada** em cópia
temporária não commitada, e o esperado era vermelho.

```bash
npm run prova:nao-vacuidade
```

| Caso | Arquivo | Proteção desligada | Padrão | Rodados | Vermelhos | Veredito |
| --- | --- | --- | --- | ---: | ---: | --- |
| B | `rtdn.js` | atalho `eventoConcluido` antes de gastar rede | `^B ` | 1 | 1 | **NÃO VÁCUO** |
| B | `entitlementStore.js` | barreira de idempotência dentro da transação | `^B2 ` | 1 | 1 | **NÃO VÁCUO** |
| C | `entitlement.js` | terminal repetido é convergente | `^C ` | 1 | 1 | **NÃO VÁCUO** |
| D | `entitlement.js` | regra de ordem pelo carimbo da consulta | `^D ` `^D2 ` | 2 | 2 | **NÃO VÁCUO** |
| P | `reconciliacao.js` | a exceção sobe, para o Pub/Sub reentregar | `^P ` `^P2 ` | 2 | 2 | **NÃO VÁCUO** |
| Q | `entitlementStore.js` | o documento é relido **dentro** da transação | `^Q ` `^U2 ` | 2 | 2 | **NÃO VÁCUO** |
| R | `idempotencia.js` | titularidade conferida antes do estado | `^R ` | 1 | 1 | **NÃO VÁCUO** |
| S | `entitlement.js` | rótulo de 8 caracteres em vez do hash | `^S ` | 1 | 1 | **NÃO VÁCUO** |
| U | `entitlement.js` | regra de ordem pelo carimbo da consulta | `^U ` | 1 | 1 | **NÃO VÁCUO** |
| W | `entitlementStore.js` | escritas bufferizadas na transação | `^W ` `^W2 ` | 2 | 2 | **NÃO VÁCUO** |

Árvore limpa antes, entre cada caso e depois. Nenhuma mutação foi commitada; o
que fica versionado é a **descrição** de cada uma, que é o que torna a prova
repetível.

**Uma prova nasceu vácua e foi consertada.** A barreira de idempotência dentro da
transação (`entitlementStore.js:107`) podia ser desligada sem o teste `B` ficar
vermelho — porque o atalho de `rtdn.js` responde antes de a transação ser
alcançada. `B` provava o atalho, não a barreira. `B2` foi escrito para o único
cenário em que ela é a única defesa: duas entregas do mesmo `messageId` em voo ao
mesmo tempo, que escapam do atalho **e** da regra de ordem porque cada uma traz
seu próprio carimbo de consulta. Com `B2`, a barreira ficou não-vácua.

Três proteções resistiram a duas mutações independentes cada (a regra de ordem
cobre D e U; a transação cobre Q, U2 e W), o que é evidência adicional de que não
são redundantes entre si.

---

## 7. Achados

### A-1 — **Alto** — a titularidade da compra é por primeiro reivindicante

| | |
| --- | --- |
| Arquivo | `functions-billing/index.js:266-285`, e a ausência em `consolidarAssinatura` |
| Símbolo | `validarCompraPlay`, passo 4 |
| Teste | `R6 DEFEITO REGISTRADO quem apresenta o token PRIMEIRO vira o dono dele` |

Não existe vínculo entre a **compra** da Google e a **conta** do aplicativo. O
elo é criado no primeiro `validarCompraPlay` que apresentar o token, com o uid de
quem chamou, **antes** de a Google ser consultada. A resposta da Play é lida
depois e não é conferida contra identidade nenhuma: `consolidarAssinatura` extrai
estado, prazo e produto, e ignora `externalAccountIdentifiers`.

Cenário reproduzível, encenado no teste:

1. `U2` chama `validarCompraPlay` com o `purchaseToken` de `U1`;
2. `compras/{hash}` nasce com `uid: U2`; a Play confirma `ACTIVE`; `U2` recebe VIP;
3. `U1`, que pagou, passa a receber `permission-denied` — **para sempre**, sem
   caminho de autoatendimento;
4. as notificações seguintes daquela assinatura passam a alimentar `U2`.

O guarda que protege o caso R — "não troque o dono do vínculo" — trabalha aqui a
favor do invasor, porque o vínculo errado já é o primeiro.

**Precondição, dita sem maquiagem:** é preciso já possuir o token da vítima. Ele
é credencial ao portador e só sai do aparelho dela. Isto **não** é escalada
anônima nem remota. É a ausência da amarra que a Google documenta para exatamente
este risco, e é o que separa "o token vazou" de "o token vazou e a assinatura
mudou de dono".

**Patch recomendado — não aplicado nesta OS** (seção 11 da OS proíbe corrigir
produção aqui). Nas duas pontas, porque uma sem a outra não funciona:

1. **cliente**: passar `obfuscatedAccountId` (um hash estável do uid) no fluxo de
   compra do Play Billing;
2. **servidor**: em `validarCompraPlay`, recusar quando
   `compra.externalAccountIdentifiers.obfuscatedExternalAccountId` não bater com o
   uid autenticado — e fazer essa conferência **antes** de gravar `compras/{hash}`,
   senão o vínculo indevido continua nascendo.

Nesta base o cliente Flutter de Billing **não existe** (`grep -rl validarCompraPlay app/`
não devolve nada), então as duas pontas estão abertas. Isso torna o patch mais
barato agora do que depois de a loja abrir.

### M-1 — **Médio** — elemento nulo em `lineItems` derruba a consolidação

| | |
| --- | --- |
| Arquivo | `functions-billing/entitlement.js:181` |
| Símbolo | `consolidarAssinatura` |
| Teste | `O2b DEFEITO REGISTRADO elemento nulo em lineItems derruba a consolidacao` |

A linha 172 protege o item (`item && item.expiryTime`); a linha 181 usa o mesmo
item sem proteção (`itens[0].productId`). Um elemento nulo vira `TypeError` não
tratado.

O que **não** é: não concede VIP, não muta documento, não vaza segredo. A exceção
sobe e `retry: true` reentrega, então o estado fica preservado — provado no teste.

O que **é**: a mensagem vira pílula envenenada. Ela não melhora com reentrega, o
Pub/Sub a redistribui até a retenção do tópico expirar, e o operador vê pilha de
`TypeError` em vez de decisão auditável. Alcançável apenas se a Play devolver
elemento nulo dentro do array, o que o contrato documentado não prevê.

```diff
-  if (!produtoId && itens.length > 0) produtoId = itens[0].productId || null;
+  if (!produtoId && itens.length > 0) produtoId = (itens[0] && itens[0].productId) || null;
```

### M-2 — **Médio** — mensagem de erro de terceiro persistida em documento do cliente

| | |
| --- | --- |
| Arquivo | `functions-billing/index.js:216-217, 317, 340, 343, 485, 587` |

Cinco pontos de `index.js` registram `e.message` de `googleapis` sem redação, e
dois deles **gravam** essa string em `compras/{hash}` — documento que a regra
libera para o dono ler (`firestore.rules:251`):

```js
await refCompra.set({ ultimoErro: e.message }, { merge: true });      // index.js:343
await refCompra.set({ avisoFechamento: fechamento.erro }, { merge: true }); // index.js:485
```

Isto contradiz a invariante que o próprio codebase declara em
`entitlement.js:446`: *"nenhum log deste codebase o imprime (todo log usa
`rotuloToken`)"*. `rtdn.js:96-106` aplica a disciplina e explica por quê — um
`SyntaxError` cita um trecho da entrada e imprimiria o token pela porta dos
fundos. `index.js` não aplica a mesma disciplina aos erros da Play API.

**Não há vazamento demonstrado, e a verificação foi feita e não presumida.** Na
versão instalada (`gaxios@6.7.1`), `GaxiosError.message` é `Request failed with
status code ${status}` ou a mensagem do erro de rede do Node; nem `googleapis-common`
nem `apirequest.js` reescrevem a mensagem com o corpo da resposta, e a URL — que
carrega o token no caminho — fica em `config.url`, não em `.message`. Ou seja: a
garantia hoje existe, mas é **circunstancial**, dependendo do que uma dependência
de terceiro resolve colocar num campo livre. Uma atualização de `gaxios` pode
mudá-la sem que nada neste repositório mude.

Patch recomendado: aplicar em `index.js` a mesma disciplina de `rtdn.js` —
registrar `e.name`, `e.code` e o status, nunca `e.message` cru, e nunca persistir
string de terceiro em documento que o cliente lê.

### M-3 — **Médio** — a conferência de origem é opcional por omissão

| | |
| --- | --- |
| Arquivo | `functions-billing/entitlement.js:246` |
| Teste | `X3 a origem da notificacao: pacote alheio e recusado` |

```js
if (corpo.packageName && pacote && corpo.packageName !== pacote) {
```

Pacote **alheio** é recusado; pacote **ausente** passa. O controle primário é o
IAM do tópico — só a Google publica nele —, e esta é a defesa em profundidade,
que fica desligada justamente para a mensagem que não declara origem. Importa
porque o caminho terminal (revogação, anulação) **não** consulta a Google: para
ele o payload é o veredito, e uma mensagem sem `packageName` chegaria à
consolidação de estorno com a única conferência de origem desativada.

Patch recomendado: exigir `corpo.packageName === pacote`, tratando ausência como
recusa.

### Observações registradas (sem severidade atribuível)

**OBS-1 — `notificationType` não numérico degrada terminal em reconciliação.**
`Number('REVOKED')` é `NaN`, escapa do ramo terminal e cai em `reconciliar`. Para
uma revogação isso é degradação, porque a consulta de estado não expressa
revogação. Não é explorável: o tipo é numérico por contrato e quem publica é a
Google. Fica anotado porque a degradação é **silenciosa**. (`X3`)

**OBS-2 — write redundante em reempacotamento econômico.** O mesmo fato econômico
com `messageId` novo regrava `playerEntitlements/{uid}` (consulta nova, carimbo
novo). Não há impacto financeiro: o valor gravado é absoluto, nunca incremental, e
o estado converge — provado em `C2`. Custo é de escrita, não de dinheiro.

**OBS-3 — `ultimoEventoTipo` é zerado por fontes sem evento.**
`documentosDeEntitlement` preserva `ultimoEventoEm` (via `maisRecente`) mas grava
`ultimoEventoTipo: null` quando a proposta não traz tipo — validação, relógio,
migração. A trilha fica assimétrica: sabe-se *quando* foi o último evento, não *o
quê*. Perda de auditoria, não de correção. (`entitlement.js:460`, não exercitado)

### Severidades não encontradas

Nenhum achado **Crítico**. Especificamente, e cada um com teste: VIP não é
concedido sem confirmação autoritativa (`P3`, `I`); não há duplicação de
concessão (`B`, `B2`, `Q3`); token bruto não é exposto (`S`, `S2`, `S3`); evento
antigo não ressuscita entitlement (`D2`, `K2`); falha parcial não deixa benefício
indevido (`W`, `W2`); código de teste não toca produção (seção 9).

---

## 8. Comandos e resultados

| Comando | Testes | Pass | Fail | Skip | Duração |
| --- | ---: | ---: | ---: | ---: | ---: |
| `npm ci` | — | — | — | — | 245 pacotes, 2 min |
| `npm run test:baseline` | 79 | 79 | 0 | **0** | 193 ms |
| `npm run test:adversarial` | 65 | 65 | 0 | **0** | 436 ms |
| `npm test` (os dois) | 144 | 144 | 0 | **0** | 497 ms |
| `npm run prova:nao-vacuidade` | 10 provas | — | — | — | 10/10 não vácuas |

**Zero skips.** Nenhum caso A–W foi pulado, marcado `todo` ou mascarado por
`catch` vazio ou retry infinito — conferido por varredura no diff.

`npm ci` é exigido apenas por `test:adversarial`, que carrega `index.js`. Os três
alvos históricos continuam rodando sem `node_modules`, como a base decidiu.

**Nenhuma rede foi usada, e isso é medido, não afirmado.** `armadilha_de_rede.js`
substitui `http.request`, `https.request`, `net.Socket.prototype.connect`,
`dns.lookup` e `fetch` por versões que lançam, armada na carga do arquivo de
teste. `X4` confere o contador no fim: **0 tentativas em 65 testes**, e confirma
que as portas que `index.js` enxerga são as plantadas.

---

## 9. Inspeção estática

| Verificação da OS | Resultado |
| --- | --- |
| Escritas em `compras`, `playerEntitlements`, `billingEvents` e equivalentes | Mapeadas. `X1` prova que nada é escrito fora de `playerEntitlements/`, `billingEvents/`, `compras/`, `usuarios/`, `configuracao/` — em particular, nada em moderação, torneio, ranking, partida ou denúncia. |
| Documento acessível ao cliente recebe token bruto? | **Não.** O token cru vive só em `playerEntitlements/{uid}/interno/billing`, com `allow read, write: if false` para cliente **e** admin. Mas `compras/{hash}`, legível pelo dono, recebe string de erro de terceiro — **M-2**. |
| Idempotência usa só `messageId` ou protege o fato de domínio? | **Ambos.** `messageId` em `billingEvents`, escrito na mesma transação do efeito; e o fato de domínio em `decidirAtualizacao` (terminal repetido, token superado, verificação antiga). Provado por `C` (ids diferentes, mesmo fato) e `B2`. |
| Ordem consulta → decisão → transação | Correta. `consultadoEm` é capturado **antes** da rede (`reconciliacao.js:66`), e é esse carimbo que `decidirAtualizacao` compara. Inverter as duas linhas reintroduziria o defeito de ordem — o baseline já guarda `RTDN-21` para isso. |
| Evento desconhecido é fail-closed? | Sim, e no sentido certo: tipo desconhecido **reconcilia** (pergunta à autoridade) em vez de decidir pelo payload. Estado de assinatura desconhecido → `desconhecido`, sem acesso (`O3`). Ver **OBS-1** e **M-3**. |
| Reconciliação consulta estado autoritativo? | `reconciliarEntitlementDoJogador` sim. `reconciliarEntitlements` **deliberadamente não** — é conclusão do relógio sobre prazo que a Google já informara, e é a rede de segurança de quando a notificação nunca chega. Documentado na base e provado em `J2`. |
| Erro transitório distinguível de evento terminal? | Sim, estruturalmente: transitório é **exceção que sobe** (vira reentrega); terminal é **estado gravado**. `P` e `K` provam os dois lados. |
| Runtime e região alterados nesta branch? | **Não.** `X2` fixa `us-central1`, `gcfv2`, tópico `play-billing-rtdn`, `retry: true`, `every 30 minutes`, e o segredo só nas três funções que falam com a Play. O diff de `package.json` não toca `engines` nem `dependencies`. |
| Funções administrativas protegidas? | Sim. As duas exigem `request.auth.token.admin === true`; `T5` prova recusa para não-admin **e** para anônimo. `migrarEntitlementsLegado` corretamente não pede o segredo da Play — ela não consulta a Google. |
| Testes mascaram falha? | Não. Zero `skip`, zero `todo`, zero `catch` vazio, zero `while(true)`. O único `.catch` no diff (`Q3`) captura erros **para dentro das asserções**, e o teste exige as 10 aprovações. |
| Logs usam rótulo/hash? | Em `rtdn.js`, `entitlementStore.js` e nos quatro logs "de decisão" de `index.js`: sim, `rotuloToken` corta em 8 caracteres. Nos cinco logs de erro de `index.js`: passam `e.message` cru — **M-2**. |
| Índice composto da varredura declarado? | Sim. `firebase/firestore.indexes.json` traz `playerEntitlements (vipAtivo ASC, expiraEm ASC)`, que é exatamente a consulta de `reconciliarEntitlements`. **O falso não cobra índice**, então isto foi conferido por leitura, não por execução. |

---

## 10. Limitações e riscos residuais

Estas são fronteiras do método, não do código, e nenhuma delas foi disfarçada de
cobertura.

1. **Nada aqui prova `firestore.rules`.** O Firestore falso não tem regra de
   segurança. As afirmações sobre quem lê `compras/`, `playerEntitlements/` e
   `interno/billing` vieram de leitura do arquivo de regras. Provar isso exige o
   emulador com `@firebase/rules-unit-testing` — que `firebase/testes/` já usa
   para outros domínios e onde este bloco caberia.

2. **O tópico, o Eventarc, o IAM e a Play Console não foram tocados.** A OS
   proíbe, e este laudo não afirma nada sobre eles. `X2` prova que o **código**
   declara `play-billing-rtdn` com `retry: true`; que o tópico existe, que a Play
   Console aponta para ele e que a service account tem as permissões, isso é
   ambiente e continua pendente.

3. **A resposta REAL da Google nunca foi vista.** Os corpos de
   `purchases.subscriptionsv2` entram como literais no formato documentado. Se o
   campo real tiver outro nome ou outro tipo, nenhum teste desta suite perceberia.
   Só uma compra de teste licenciada fecharia isso, e ela está fora do escopo.

4. **`index.js` não tem relógio injetável.** Ele chama `new Date()` direto, então
   os casos de **ordem** (D, U) foram provados no caminho de módulo, onde o
   relógio é porta. Nenhum caso de ordem depende do caminho de `index.js`.

5. **A concorrência de 10 execuções roda com orçamento de retry elevado.** O
   Firestore falso não tem backoff, então dez transações disputando o mesmo
   documento esgotam as 5 tentativas do SDK real por uma razão que é do **modelo**,
   não do código. `Q2` e `Q3` usam 60 e 80 tentativas, e isso está dito aqui para
   que ninguém leia "converge sob 10 concorrentes" como promessa de que o SDK real
   não abortaria alguma delas por contenção. A corrida de 2, com interleaving
   determinístico (`Q`, `U2`, `B2`), roda no orçamento padrão.

6. **O consumidor do direito não foi exercitado.** Este laudo cobre o produtor. A
   pergunta "o jogador tem VIP neste instante?" é respondida em
   `app/lib/elegibilidade/`, que a OS proíbe tocar.

7. **A migração do legado herda uma janela conhecida, e ela não é defeito desta
   base.** Sem o token guardado, um direito migrado vale até o prazo já gravado e
   nem um minuto além. `T3` e `T4` provam que ela é idempotente e que não
   sobrescreve fato confirmado; não provam que o prazo migrado esteja correto,
   porque não há com o que comparar.

8. **A ausência de vazamento em M-2 é circunstancial.** Ela depende do que
   `gaxios@6.7.1` coloca em `.message`. Conferido nesta versão; não é garantia
   estrutural.

---

## 11. Fronteira de alterações

Nenhum arquivo de produção foi alterado. Diff completo contra
`a2622d59c09156e1e9fb80aa52d0a6fc51b3c9f9`:

```
 functions-billing/package.json                      |   10 +-   (só `scripts`)
 functions-billing/test/adversarial.test.js          | 1799 +
 functions-billing/test/apoio/armadilha_de_rede.js   |   62 +
 functions-billing/test/apoio/carga_index.js         |  166 +
 functions-billing/test/apoio/cenario.js             |  246 +
 functions-billing/test/apoio/firestore_adversarial.js |  335 +
 functions-billing/test/apoio/nao_vacuidade.js       |  266 +
 functions-billing/test/apoio/play_falsa.js          |  243 +
 functions-billing/test/apoio/relogio_falso.js       |   65 +
 docs/HOMOLOGACAO-ADVERSARIAL-RTDN-VIP-P0.md         |  este arquivo
```

`index.js`, `entitlement.js`, `entitlementStore.js`, `rtdn.js`,
`reconciliacao.js`, `idempotencia.js`, `firebase/`, `app/`, `functions/` e
`functions-moderacao/` estão **byte a byte idênticos à base**. A única mudança
fora de `test/` é o bloco `scripts` do `package.json`: `engines`, `main` e
`dependencies` não foram tocados.

Os dois defeitos encontrados **não foram corrigidos**, conforme a seção 11 da OS.
Cada um tem teste reproduzível na branch, o patch recomendado escrito no corpo do
próprio teste, e a instrução explícita de que o teste precisa ser **invertido**
quando o patch entrar — para que um conserto futuro não passe despercebido por
deixar verde um teste que afirmava o defeito.

---

## 12. O que este veredito não diz

Este `FAIL` é de homologação adversarial local. Ele **não** afirma que o Billing
comercial esteja reprovado, que a compra real tenha sido testada ou que o backend
esteja implantado — nenhuma dessas coisas foi exercitada, porque a OS as proíbe.

Um `PASS` aqui também não teria significado compra real homologada, produto
comercial criado ou deploy feito.

O caminho para o `PASS`: corrigir A-1 nas duas pontas, corrigir M-1 (uma linha),
aplicar a disciplina de redação de `rtdn.js` a `index.js` (M-2), fechar a
conferência de origem (M-3), inverter `R6` e `O2b`, e rodar a suíte de novo. Os
três Médios são pequenos; o Alto é o que exige decisão de produto, porque envolve
o cliente Flutter de Billing, que nesta base ainda não existe.
