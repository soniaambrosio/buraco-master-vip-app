# RECONCILIAÇÃO DO ESTADO DE PRODUÇÃO E PLANO DE DEPLOY ATÔMICO — V1

Auditoria do que está **realmente rodando** no projeto `buraco-master-vip`
(203886484007) em 2026-08-15, e preparação do primeiro deploy unificado.

**Nenhum deploy foi executado. Nenhum recurso de produção foi criado, alterado ou
removido. Nenhum dado foi escrito.** A confirmação formal está no §14.

**Data de apuração:** 2026-08-15, 20:50–21:10 UTC (17:50–18:10 BRT).
**Janela importante:** o Billing foi implantado hoje, 18:49–18:51 UTC — **duas
horas antes** desta auditoria. O censo abaixo é posterior a esse deploy.

---

## VEREDITO

### O estado de produção é reproduzível a partir de um único commit?

# NÃO

Mas **não pelo motivo que a OS supunha.** As cinco Functions em produção são
reproduzíveis a partir de um único commit — isso está **provado
criptograficamente** no §2. A hipótese de "produção híbrida entre Functions" foi
**refutada** (§3).

Produção não é reproduzível de um único commit por três razões diferentes:

1. As **Firestore Rules** em produção foram publicadas em **2026-02-24** e sua
   fonte **não existe em nenhum objeto deste repositório** (§4.1). Origem fora do
   repositório — provavelmente o Console, na era FlutterFlow.
2. O **servidor WebSocket** (Railway) roda uma versão **anterior à autenticação
   de handshake**, que não corresponde ao HEAD de nenhuma branch de trabalho, e
   sua fonte `cliente/` está perdida (§8).
3. Os dois vivem em **repositórios diferentes**, sem pipeline que os amarre.

Produção não é um commit. É **três eras sobrepostas**: Rules de fevereiro,
servidor de julho, Functions de hoje.

### Se fizermos o próximo deploy a partir da Release Candidate, é possível unificar produção com segurança?

# NÃO

Não com a RC **como está hoje definida**. O manifesto `RC-V1-MANIFESTO-DE-COMPOSICAO.md`
(base + 13 folhas) **não contém o código de Billing que está em produção agora**:
faltam 8 commits (§9.1). Deployar essa RC **regride** produção — inclusive
apagando `concederFichasMensais`.

O que falta resolver está enumerado, com precisão, no §13.

---

## §0. MÉTODO E LIMITES DA APURAÇÃO

### O que foi usado

| Ferramenta | Estado | Uso |
| --- | --- | --- |
| `firebase-tools` 15.26.0 | autenticado como `soniia.ambrosio@gmail.com` (roles/owner) | `functions:list`, `firestore:indexes`, `apps:list`, `hosting:sites:list` |
| Cliente HTTP autenticado do próprio CLI (`lib/apiv2`) | idem | **somente GET e `:getIamPolicy`/`:test`** contra as APIs do Google |
| `gcloud` | **AUSENTE nesta máquina** | — |

Sem `gcloud`, Scheduler / Pub/Sub / Secret Manager / IAM foram lidos pela **API
REST**, com as credenciais que o próprio CLI já usa. Nenhuma credencial foi
impressa, copiada ou gravada. **Nenhum valor de secret foi acessado** — apenas
metadados (`versions.list`, nunca `:access`).

### O que não foi possível apurar

| Componente | Motivo |
| --- | --- |
| Play Console (produto `master_vip`, faixas, versões) | sem acesso programático |
| Railway (variáveis, volume, commit implantado, histórico) | sem token/CLI; o serviço só pôde ser sondado de fora |
| Distinção `main@1828d42` × `transporte-srv2@2fdeda5` no servidor | discriminante é comportamento de regra de jogo; exigiria partida completa (§8.2) |

---

## §1. CENSO DO QUE ESTÁ EM PRODUÇÃO

### 1.1 Firebase Functions — 5 funções, todas do codebase `billing`

Fonte: `GET cloudfunctions.googleapis.com/v2/.../functions` (resposta bruta
capturada via `--debug`).

| Function | Trigger | Revision | updateTime (UTC) | createTime | Secret |
| --- | --- | --- | --- | --- | --- |
| `validarCompraPlay` | callable (HTTP) | `validarcompraplay-00002-not` | 2026-08-15T18:51:18Z | 2026-08-12T02:09:14Z | `PLAY_SERVICE_ACCOUNT_JSON` v1 |
| `notificacoesPlay` | Pub/Sub `play-billing-rtdn` | `notificacoesplay-00002-cer` | 2026-08-15T18:51:18Z | 2026-08-12T02:10:20Z | `PLAY_SERVICE_ACCOUNT_JSON` v1 |
| `reconciliarEntitlementDoJogador` | callable | `reconciliarentitlementdojogador-00002-kaj` | 2026-08-15T18:51:17Z | 2026-08-12T02:10:19Z | `PLAY_SERVICE_ACCOUNT_JSON` v1 |
| `reconciliarEntitlements` | scheduled | `reconciliarentitlements-00002-pub` | 2026-08-15T18:51:16Z | 2026-08-12T02:10:19Z | — |
| `concederFichasMensais` | scheduled | `concederfichasmensais-00001-fop` | 2026-08-15T18:50:59Z | **2026-08-15T18:49:25Z** | — |

**Comum a todas:** geração **GEN_2**, região **us-central1**, runtime
**nodejs20**, memória **256Mi**, timeout **60s**, CPU **1**, concorrência **80**,
`ingressSettings: ALLOW_ALL`, `allTrafficOnLatestRevision: true`,
`deployment-tool: cli-firebase`, `firebase-functions-codebase: billing`.

**Service account (todas, build e runtime):**
`203886484007-compute@developer.gserviceaccount.com`.

**Diferenças reais entre elas — apenas duas:**

- `maxInstanceCount: 20` em quatro delas; **`concederFichasMensais` não declara
  limite** (fica no default da plataforma). Divergência de configuração real.
- `retryPolicy: RETRY_POLICY_RETRY` existe só em `notificacoesPlay` (é a única
  com event trigger).

`concederFichasMensais` é a única em `revision 00001` porque **nasceu hoje**.

### 1.2 O que NÃO está em produção

Nenhuma função de: **torneios, moderação, ranking, social, identidade, coleções
(Kit Pioneiros) ou exclusão de conta.** Também não há Hosting publicado.

O `firebase.json` da branch mais completa (`1acc5f9`) declara **7 codebases /
48 funções**. Produção tem **5**. Detalhe no §9.2.

---

## §2. LINHAGEM — PROVADA, NÃO INFERIDA

A OS pediu para não inferir commit por semelhança. Não foi inferido: foi
**verificado byte a byte**.

### 2.1 O artefato

Cada Function GEN_2 guarda o zip de origem no bucket
`gcf-v2-sources-203886484007-us-central1`. Os metadados dos objetos mostram:

| Objeto | generation | tamanho | MD5 |
| --- | --- | --- | --- |
| `validarCompraPlay/function-source.zip` | 1786819833078269 | 200 991 | `fX2nKVS9DHinhDbfQ3F+5w==` |
| `concederFichasMensais/function-source.zip` | 1786819764993564 | 200 991 | `fX2nKVS9DHinhDbfQ3F+5w==` |

**MD5 idêntico.** Mesmo tendo sido enviados com 68 s de diferença, os artefatos
são o **mesmo arquivo**. Uma única fonte gerou todas as funções.

O objeto foi baixado (196 KB, leitura apenas, para o scratchpad da sessão; nada
foi executado) e seu MD5 local confere: `fX2nKVS9DHinhDbfQ3F+5w==`.

### 2.2 A correspondência com o commit

O zip contém **31 arquivos**. Comparando o conteúdo de cada um com
`git show <commit>:functions-billing/<arquivo>` (normalizando CRLF→LF, porque o
zip foi montado a partir da árvore de trabalho no Windows):

| Commit candidato | Arquivos idênticos | Divergências |
| --- | --- | --- |
| **`c9409dc`** | **31 / 31** | nenhuma |
| **`125ec96`** (tip da branch) | **31 / 31** | nenhuma |
| `d00e394` | 28 / 31 | `index.js`, `package.json` diferentes; `test/superficieDeploy.test.js` inexistente |
| `92a9fa0` | 0 / 31 | 4 arquivos inexistentes |
| `625769d` (folha da RC) | 0 / 31 | **19 arquivos inexistentes** |
| `bbba26d` (folha da RC) | 0 / 31 | não tem `functions-billing/` |

**Conclusão provada:** o código de Billing em produção é o de
`claude/billing-vip-production-activation-525b63`, commit **`c9409dc`**.
`125ec96` empata porque acrescenta **apenas** `docs/ATIVACAO-BILLING-PRODUCAO-V1.md`
— nenhuma linha de código. Produção é, portanto, idêntica ao **tip** dessa branch.

**Corroboração independente:** o cabeçalho de `docs/ATIVACAO-BILLING-PRODUCAO-V1.md`
declara "Base de código: `c9409dc`", escrito pela sessão que fez o deploy, sem
conhecimento desta apuração.

**Existe código posterior não implantado?** Para o Billing, **não**. A branch não
avançou em código depois do deploy.

---

## §3. PRODUÇÃO HÍBRIDA — HIPÓTESE REFUTADA

A OS partiu de um indício concreto: "diferentes Functions executando artefatos
com hashes distintos". O indício é real, e existem mesmo **dois** hashes:

| `firebase-functions-hash` | Functions |
| --- | --- |
| `9a3aaf13dc8e4308eba8e6e7e7941f30213e2a21` | `validarCompraPlay`, `notificacoesPlay`, `reconciliarEntitlementDoJogador` |
| `cffdf38e340fff732a0eb43543adc70a654579d9` | `reconciliarEntitlements`, `concederFichasMensais` |

**Mas esse label não é hash de deploy — é hash de *endpoint*.** O algoritmo está
em `firebase-tools/lib/deploy/functions/cache/hash.js`:

```js
getEndpointHash(sourceHash, envHash, secretsHash)
  = sha1( sourceHash + envHash + secretsHash )

getSecretsHash(endpoint) = sha1( JSON.stringify(secretVersions) )
```

`sourceHash` e `envHash` são **do codebase inteiro**; `secretsHash` é **por
função**. Duas funções do mesmo deploy divergem no label **se, e somente se,
tiverem conjuntos de secrets diferentes**.

E é exatamente o corte observado: as três do hash A declaram
`PLAY_SERVICE_ACCOUNT_JSON:1`; as duas do hash B **não declaram secret nenhum**.
A partição é do secret, não do deploy.

### As quatro provas independentes de que houve UM único deploy

1. **Artefato idêntico** — mesmo MD5 nos objetos de origem (§2.1).
2. **Build único** — todas as cinco apontam para
   `builds/6f402ab5-baf0-4c0c-9383-55b6c7dfdae3`, status **SUCCESS**,
   criado 18:49:25Z, concluído 18:50:13Z.
3. **Janela de 19 segundos** — `updateTime` de 18:50:59Z a 18:51:18Z.
4. **Revisões coerentes** — quatro em `00002` (segunda implantação, sobre a de
   12/08), uma em `00001` (criada agora).

> **CONFIRMAÇÃO: não há produção híbrida entre as Firebase Functions.**
> As cinco vieram do mesmo commit, no mesmo deploy, hoje.
>
> **Há hibridismo entre camadas** — Functions (hoje) × Rules (fevereiro) ×
> servidor (anterior a julho). Esse é o hibridismo real, e é maior.

Registro de método: este diagnóstico já foi errado uma vez em sessão anterior,
lendo os dois hashes como dois deploys. O label sozinho **não** prova
divergência de deploy — o artefato prova.

---

## §4. FIRESTORE

Banco `(default)` · tipo `FIRESTORE_NATIVE` · local **`southamerica-east1`** ·
`PESSIMISTIC` · **PITR DESABILITADO** · **proteção contra exclusão DESABILITADA**.

> As Functions estão em `us-central1` e o Firestore em `southamerica-east1`.
> Cada leitura/escrita atravessa o continente. É decisão herdada, não defeito
> novo — mas é custo de latência em toda transação de billing.

### 4.1 Rules — a divergência mais grave da auditoria

Só existem **duas rulesets na história inteira do projeto**, ambas de
**2026-02-24**. O release `cloud.firestore` aponta para
`rulesets/e5b63447-2ddf-46ea-954a-03d13eca6fba`, `updateTime`
**2026-02-24T05:04:19Z**.

**As Rules nunca foram implantadas desde fevereiro.**

O conteúdo publicado tem **33 linhas / 707 bytes** e cobre 6 coleções:
`users`, `global_chat`, `tables`, `seasons`, `leaderboards`, `store_products`.

O arquivo da RC (`firebase/firestore.rules` em `1acc5f9`) tem **1 093 linhas /
54 438 bytes** e cobre **62** caminhos.

| | Produção | RC |
| --- | --- | --- |
| bytes | 707 | 54 438 |
| coleções cobertas | 6 | 62 |
| `playerEntitlements` | **ausente** | presente |
| `compras`, `publicProfiles`, `rankingLedger`, `reports`, `friendships`… | **ausentes** | presentes |

**Procedência do que está publicado: NÃO DETERMINÁVEL.** O blob do arquivo
publicado (`9998472182dbb923058b222b6a4aa77b4094ee3f`, normalizado) **não existe
no banco de objetos deste repositório** — `git cat-file -t` não o encontra. Não é
nenhum commit desta base: é anterior ao repositório atual, da era FlutterFlow.

**Consequência operacional imediata.** Rules do Firestore negam por omissão. O
app lê `playerEntitlements/{uid}` **direto do Firestore**
(`app/lib/billing/entitlement_repositorio.dart:35`). Com as Rules de hoje, essa
leitura é **PERMISSION_DENIED**.

> Se uma compra real acontecesse agora, `validarCompraPlay` creditaria o direito
> corretamente no servidor — e **o aplicativo jamais conseguiria lê-lo**.
> O VIP seria cobrado e não apareceria.

Isso contradiz frontalmente a afirmação de `ATIVACAO-BILLING-PRODUCAO-V1.md`
("as Rules... estão operacionais e provados"). A afirmação vale para o
**emulador**, onde as Rules da RC foram testadas. Ela **não vale para produção**,
onde essas Rules nunca chegaram. É a divergência mais cara do inventário.

### 4.2 Índices

| | Produção | RC (`1acc5f9`) |
| --- | --- | --- |
| índices compostos | **1** | **38** |
| fieldOverrides | 0 | 2 |

O único índice em produção é
`playerEntitlements (vipAtivo ASC, expiraEm ASC, __name__ ASC)` — exatamente o
que `reconciliarEntitlements` precisa para varrer vencidos. Coerente com o
Billing implantado.

Os 37 restantes cobrem `matches`, `rankingLedger`, `reports`, `friends`,
`editions`, `registrations`, `rankingStandings`, `fraudSignals` etc. Toda query
dessas frentes falharia hoje por índice inexistente.

### 4.3 Coleções que realmente existem

`listCollectionIds` + `runAggregationQuery` (COUNT) na raiz:

| Coleção | Documentos |
| --- | --- |
| `users` | 1 (`teste_user`) |
| `store_products` | 1 (`pack_starter`) |
| `billingEvents` | 1 |
| `global_chat`, `leaderboards`, `seasons`, `tables` | 1 cada |

**Total: 7 coleções, 7 documentos.** Não existem `playerEntitlements`,
`compras`, `fichasConcessoes`, `usuarios`, `publicProfiles`, `rankingLedger`,
nem qualquer coleção das frentes novas.

> **O Firestore de produção está vazio de conteúdo real.** Nunca houve compra,
> entitlement ou jogador nele. Isso é a melhor notícia da auditoria: **não há
> dado de produção em risco no Firestore** (§11).

O único documento de `billingEvents` corresponde ao teste de RTDN registrado em
sessão anterior — prova de que o caminho Play → Pub/Sub → Function já funcionou
de ponta a ponta.

---

## §5. PUB/SUB E RTDN — **EXISTE EM PRODUÇÃO**

A distinção que a OS pediu (existe em produção × existe no repositório) resolve
para **existe em produção**, com a cadeia inteira montada:

| Item | Estado real |
| --- | --- |
| Tópico | `projects/buraco-master-vip/topics/play-billing-rtdn` — **único tópico do projeto** |
| Publisher da Play | `roles/pubsub.publisher` → `google-play-developer-notifications@system.gserviceaccount.com` ✅ |
| Subscription | `eventarc-us-central1-notificacoesplay-139516-sub-065`, estado **ACTIVE** |
| Tipo | push (Eventarc) → `https://notificacoesplay-eh344ewefa-uc.a.run.app` |
| Trigger Eventarc | `notificacoesplay-139516`, `google.cloud.pubsub.topic.v1.messagePublished` |
| Retry | `RETRY_POLICY_RETRY`; backoff 10 s → 600 s |
| Ack deadline | 600 s |
| Retenção | 86 400 s (24 h) |
| **Dead-letter** | **NÃO EXISTE** |
| Consumidor | `notificacoesPlay`, autenticada por OIDC do SA de compute |

**Único ponto aberto:** sem dead-letter topic, uma mensagem que falhe por 24 h é
**descartada em silêncio**. Como o desenho reconsulta a Google em vez de confiar
no evento, a perda é recuperável pela reconciliação de 30 min — mas a perda não
gera alarme. Ver gate G-7.

---

## §6. CLOUD SCHEDULER

Dois jobs, ambos `ENABLED`, em `us-central1`:

| Job | Frequência | TZ | Alvo | Última execução | Resultado |
| --- | --- | --- | --- | --- | --- |
| `firebase-schedule-reconciliarEntitlements-us-central1` | `every 30 minutes` | UTC | `reconciliarentitlements…run.app` | **2026-08-15T20:51:03Z** | `status: {}` → **OK** |
| `firebase-schedule-concederFichasMensais-us-central1` | `every day 09:00` | **America/Sao_Paulo** | `…cloudfunctions.net/concederFichasMensais` | **nunca** | `status.code: -1` |

Ambos usam OIDC com o SA de compute. `attemptDeadline: 180s`.

- A reconciliação de entitlement **está rodando e passando** — última tentativa
  minutos antes deste censo, sem erro.
- **`concederFichasMensais` nunca executou.** Foi criada às 18:49Z de hoje; a
  primeira execução será **2026-08-16T12:00Z (09:00 BRT de amanhã)**. Não há
  histórico que prove que ela funciona em produção. Ver gate G-6.

Os alvos são inconsistentes entre si (um aponta para `run.app`, outro para
`cloudfunctions.net`); é como o CLI gerou, e não afeta funcionamento.

---

## §7. SECRETS E IAM

### 7.1 Secret

| Campo | Valor |
| --- | --- |
| Nome | `projects/203886484007/secrets/PLAY_SERVICE_ACCOUNT_JSON` |
| Criado | 2026-08-07T10:26:56Z |
| Replicação | automática |
| Label | `firebase-managed: functions` |
| Versões | **1**, estado **ENABLED**, criada 2026-08-07T10:27:20Z |
| Binding | `roles/secretmanager.secretAccessor` → `203886484007-compute@…` |

Nenhum valor de secret foi lido. Só metadados.

### 7.2 IAM do projeto — 20 bindings

Cadeia funcional **completa e correta**:

- `roles/run.invoker` e `roles/eventarc.eventReceiver` → SA de compute (Scheduler
  e Eventarc conseguem invocar);
- `roles/iam.serviceAccountTokenCreator` → SA do Pub/Sub (push OIDC);
- `roles/pubsub.publisher` no tópico → SA da Google Play.

**Dois achados de privilégio (não bloqueiam o deploy, mas devem ser decididos):**

1. **`group:firebase@flutterflow.io` tem `roles/editor` no projeto de produção.**
   Um grupo externo, herdado da era FlutterFlow, com permissão de escrita em
   Firestore, Functions e Rules. Não há uso conhecido. Recomendo remover — mas
   **fora desta OS**, que é proibida de alterar IAM.
2. As Functions rodam com o **SA default de compute**, que também carrega
   `roles/editor`. Menor privilégio recomendaria um SA dedicado. Trocar SA de
   função é mudança de deploy, não de auditoria.

---

## §8. SERVIDOR / WEBSOCKET

Repositório separado: `F:/Projetos/buraco-servidor`
(`github.com/soniaambrosio/buraco-servidor`). Alvo:
**`wss://buraco-servidor-production.up.railway.app`**, referenciado em
`app/lib/services/online_service.dart:23`.

### 8.1 Está no ar

`GET https://buraco-servidor-production.up.railway.app/` → **404 `not found`**,
`server: railway-hikari`, edge `mia1`. Serviço vivo.

### 8.2 Versão publicada — sondagem sem efeito colateral

Duas sondas WebSocket somente-leitura (nenhuma mesa criada, nenhum estado
alterado):

| Sonda | Resposta do servidor | O que prova |
| --- | --- | --- |
| `{tipo:"auth", protocolo:1, token:"probe-invalido"}` | `{"tipo":"erro","motivo":"tipo desconhecido: auth"}` | **não conhece `auth`** → é **anterior** a `b6d2a57` (autenticação de handshake) |
| `{tipo:"assistirMesa", codigo:"ZZZZZZ"}` | `{"tipo":"erro","motivo":"tipo desconhecido: assistirMesa"}` | **não conhece `assistirMesa`** → **não** contém `3c8b07e` (enforcement de espectador) |

**Conclusão:** o servidor em produção fala **protocolo 1** — sem autenticação. O
cliente declara a própria identidade e o servidor aceita.

**Correspondência de commit: PARCIALMENTE DETERMINÁVEL.**
Provado: é anterior a `b6d2a57` e não contém `3c8b07e`. Restam dois candidatos —
`origin/main@1828d42` e `origin/transporte-srv2@2fdeda5` — cujo único
discriminante observável é classificação de canastra ás-a-ás, que exigiria jogar
uma partida completa para distinguir. `main` é o mais provável (é o
`origin/HEAD`, e `transporte-srv2` é regressão de um patch já mesclado), mas
**não está provado**. Some-se que a fonte `cliente/` do bundle está perdida: o
`server.js` versionado é artefato gerado, não fonte completa.

### 8.3 Compatibilidade com o cliente da RC — quebra dura

O HEAD local (`seguranca/ws-auth-identidade@71199e8`) declara
`PROTOCOLO_ATUAL = 2` e **`PROTOCOLO_MINIMO = 2`**.

| Combinação | Resultado |
| --- | --- |
| cliente RC (protocolo 2) × servidor de produção (protocolo 1) | **cliente manda `auth`, servidor responde "tipo desconhecido"** → online quebrado |
| cliente antigo (protocolo 1) × servidor RC (protocolo 2) | servidor responde `ATUALIZACAO_OBRIGATORIA` e fecha |

**Não há janela de compatibilidade.** Servidor e cliente têm de virar juntos.
Hoje isso é barato, porque **não há cliente distribuído** (§9.4) — depois da
primeira publicação na Play, deixa de ser.

### 8.4 O dado que existe no servidor — e não existe no Firestore

Consulta `{tipo:"ranking"}` (leitura pura):

- **17 contas** registradas;
- **12 partidas** no total, **4 contas** com ao menos uma partida;
- **1 016 459 moedas** em poder dos jogadores;
- campos: `moedas, xp, nivel, partidas, vitorias, derrotas, canastras, avatar…`

Persistência: `DADOS_DIR/contas.json`, escrita atômica (`.tmp` + rename), num
Volume do Railway. **Não foi possível confirmar que o Volume está montado** — se
não estiver, o sistema de arquivos do Railway é efêmero e esses dados morrem no
próximo deploy do servidor.

> Esta é a **única população real do produto**: 17 contas com economia própria,
> em `contas.json`, sem correspondência nenhuma em Firestore. A RC move
> identidade e economia para o Firebase. Ninguém decidiu o que acontece com
> essas 17 contas. Ver gate G-8.

---

## §9. MATRIZ PRODUÇÃO × RELEASE CANDIDATE

### 9.1 A RC, como definida hoje, regride produção

`RC-V1-MANIFESTO-DE-COMPOSICAO.md` (apurado em 2026-08-15, 00:48 BRT) define a RC
como `consolidacao/apk-geral-bmv@0cea0d6` + 13 folhas.

Medindo o commit que está em produção contra esse conjunto:

```
git rev-list --count 125ec96 --not <13 folhas> consolidacao  →  8
```

**8 commits em produção estão fora da RC:**

```
125ec96  docs(billing): a cadeia tecnica fechou, a comercial nao
c9409dc  fix(billing): o require que faltava, e a migracao que sobrava
d00e394  diag(billing): planoBase e recuperavel, inicioEm nao
92a9fa0  feat(billing): recuperar o purchaseTokenHash que a migracao gravou null
e9c2aa1  diag(billing): medir a populacao legada, e o hash
921f3fd  test(rules): provar tambem que a porta do BACKEND continua aberta
f1c6279  fix(billing): a entrega mensal de fichas deixa de ter teto de 500
8e47d4d  fix(vip): o cliente deixa de conceder VIP, e passa apenas a refleti-lo
```

A folha de Billing da RC (`homologacao/billing-vip-comercial@625769d`) tem **12
arquivos** em `functions-billing/`; produção tem **31**. Deployar a RC como
definida **apagaria `concederFichasMensais`**, reintroduziria
`migrarEntitlementsLegado` e reverteria o vazamento de VIP entre contas
corrigido em `319bb8f`/`8e47d4d`.

**O manifesto da RC está desatualizado em um dia de trabalho.** Além do Billing,
ficaram de fora: exclusão de conta (`functions-conta` + `web/`), bot estratégico,
garantia de encerramento de turno e artes da Loja — todos posteriores a 00:48.

### 9.2 Matriz por componente

Legenda: **≠** diverge · **=** igual · **∅** inexistente em produção

| Componente | Produção hoje | Linhagem | RC pretendida | Δ | Ação |
| --- | --- | --- | --- | --- | --- |
| Functions `billing` (5) | `c9409dc`, 15/08 18:51Z | **PROVADA** | ⚠ RC tem `625769d` (mais antigo) | ≠ | **corrigir a RC**, depois redeploy |
| Functions `colecoes` (3) | ∅ | — | `firebase/functions` | ∅ | deploy novo |
| Functions `torneios` (7) | ∅ | — | `functions/` (TS) | ∅ | deploy novo |
| Functions `moderacao` (6) | ∅ | — | `functions-moderacao` (TS) | ∅ | deploy novo |
| Functions `ranking` (11) | ∅ | — | `functions-ranking` (TS) | ∅ | deploy novo |
| Functions `social` (14) | ∅ | — | `functions-social` (TS) | ∅ | deploy novo |
| Functions `conta` (2) | ∅ | — | `functions-conta` (TS) | ∅ | deploy novo — **fora da RC** |
| Firestore Rules | ruleset de **2026-02-24**, 707 B | **NÃO DETERMINÁVEL** (fora do repo) | 54 438 B, 62 caminhos | ≠ | **deploy obrigatório** |
| Índices compostos | **1** | coerente c/ billing | **38** | ≠ | deploy obrigatório |
| Tópico `play-billing-rtdn` | existe, publisher OK | — | igual | = | **nenhuma ação** |
| Subscription Eventarc | ACTIVE, retry, sem DLQ | — | igual | = | avaliar DLQ |
| Scheduler (2 jobs) | ENABLED | — | igual | = | nenhuma ação |
| Secret `PLAY_SERVICE_ACCOUNT_JSON` | v1 ENABLED, binding OK | — | igual | = | nenhuma ação |
| IAM | funcional; `flutterflow.io` = editor | — | — | ⚠ | decisão separada |
| Hosting (exclusão de conta) | **0 releases** | — | site + `web/` | ∅ | deploy novo |
| Servidor WebSocket | protocolo **1**, sem auth | parcial (§8.2) | protocolo **2** | ≠ | deploy coordenado |
| Cliente Android | **nada publicado** | — | 1.0.0+1 | ∅ | publicação nova |
| Produto `master_vip` na Play | **não existe** | — | necessário | ∅ | ação humana |

### 9.3 Confirmação sobre hibridismo

- **Entre Functions:** não há. Provado no §3.
- **Entre camadas:** há, e é severo — Rules de fevereiro, servidor pré-auth,
  Functions de hoje.

### 9.4 Cliente

`app/pubspec.yaml`: `version: 1.0.0+1`. Não há diretório `android/` versionado (o
alvo vem do pin do Flutter). Não há release publicada na Play. **Não existe
cliente em produção** — o que torna toda quebra de protocolo barata agora.

---

## §10. PLANO DE DEPLOY UNIFICADO

Ordem derivada das dependências reais medidas nesta auditoria, **não** de um
roteiro genérico. O princípio: **nada que o cliente leia pode chegar depois do
cliente**, e **as Rules têm de preceder qualquer função que grave o que o cliente
lerá**.

### Fase 0 — Correções que precedem qualquer deploy

**0.1** Recompor a RC incluindo os 8 commits de Billing (§9.1). Sem isso, o
primeiro deploy é uma regressão.
**0.2** Decidir se `functions-conta` + `web/` (exclusão de conta) entram na RC.
A Google Play **exige** o recurso web; sem ele a publicação é recusada.
**0.3** Resolver `concederFichasMensais` × `migrarEntitlementsLegado`: a RC
composta não pode ressuscitar a migração removida em `c9409dc`.
**0.4** Congelar refs. Metade das branches se moveu hoje; o manifesto da RC já
nasceu velho.

### Fase 1 — Pré-validações (sem tocar em produção)

**1.1** `firebase deploy --only firestore:rules` **NÃO**; usar
`firebaserules.projects.test` — já executado nesta OS, 0 issues (§12).
**1.2** Compilar os 5 codebases TypeScript (`npm run build:domain && npm run build`).
Um `tsc` que falha em deploy deixa o conjunto pela metade.
**1.3** Rodar o portão de RC (`PORTAO-RC.md`) sobre a RC composta.
**1.4** Conferir que `firebase.json` da RC declara os **7** codebases.

### Fase 2 — Rules e índices (primeiro, e sozinhos)

**2.1** Deploy dos **índices** antes das Rules. Índice demora a construir; Rules
são instantâneas. Índice faltando derruba query em runtime.
**2.2** Aguardar `READY` em todos os 38.
**2.3** Deploy das **Rules**.

> Ao publicar, `global_chat`, `leaderboards`, `seasons` e `store_products` deixam
> de ter regra e passam a negar. São 4 documentos placeholder e **nenhum cliente
> publicado os lê**. Perda aceitável — mas é perda, e tem de ser decidida, não
> descoberta.

**2.4** Verificar: leitura de `playerEntitlements/{uid}` pelo próprio dono passa a
ser permitida; leitura por terceiro continua negada.

### Fase 3 — Backend, por codebase, do mais isolado ao mais acoplado

Um codebase por vez, verificando entre eles (`firebase deploy --only functions:<codebase>`):

**3.1** `colecoes` — sem dependentes.
**3.2** `social` — identidade pública; sustenta ranking e moderação.
**3.3** `ranking` — depende de identidade.
**3.4** `moderacao` — depende de identidade.
**3.5** `torneios` — o mais acoplado; depende de ranking e economia.
**3.6** `conta` — exclusão; depende de **todas** as coleções existirem (a matriz
de retenção quebra se uma coleção faltar).
**3.7** `billing` — **por último**, e só se a RC composta contiver `c9409dc`.
Se a RC ficar igual ao que já está em produção, **não redeployar**: o
`firebase-functions-hash` idêntico faz o CLI pular, e pular é o resultado certo.

### Fase 4 — Hosting

**4.1** Deploy do site com `web/` (exclusão de conta + política de privacidade).
**4.2** Anotar a URL — a Play a exige no formulário.

### Fase 5 — Servidor WebSocket

**5.1** Confirmar que o Volume do Railway está montado e que `contas.json`
persiste (§8.4). **Fazer backup do `contas.json` antes.**
**5.2** Decidir o destino das 17 contas (migrar ou descartar) — G-8.
**5.3** Deploy do servidor protocolo 2.
**5.4** A partir daqui **todo cliente antigo perde o online.** Como não há
cliente publicado, o custo é zero — hoje.

### Fase 6 — Cliente

**6.1** Build do AAB da RC composta.
**6.2** Faixa **interna** primeiro, nunca produção direta.
**6.3** Smoke test em aparelho real contra o backend já implantado.

### Fase 7 — Smoke tests em produção

Antes de qualquer venda: login → identidade pública → entrar em mesa online →
partida completa → resultado gravado → ranking pontua → leitura de
`playerEntitlements` sem PERMISSION_DENIED.

### Fase 8 — Ativação comercial

**Só depois de tudo acima.** Criar `master_vip` na Play Console, e então executar
o roteiro N.1–N.8 de `ATIVACAO-BILLING-PRODUCAO-V1.md` com uma compra de teste
real.

---

## §11. ROLLBACK

### 11.1 O que ajuda

O Firestore de produção tem **7 documentos placeholder** (§4.3). **Não há dado de
usuário para perder.** Esta é a janela mais segura que este projeto terá para
unificar produção — e ela fecha na primeira venda.

### 11.2 O que não ajuda

**PITR está DESABILITADO.** Não existe recuperação a ponto no tempo. Uma escrita
errada de migração é **irreversível**. Recomendação: **habilitar PITR antes da
Fase 3** — é criação de configuração, portanto fora desta OS, e deve entrar como
primeiro item do deploy.

### 11.3 Por etapa

| Etapa | Como detectar falha | Rollback | Seguro prosseguir? |
| --- | --- | --- | --- |
| Índices | estado ≠ `READY` | remover índice novo; nada consome ainda | sim, é aditivo |
| **Rules** | leitura legítima negada / leitura indevida permitida | **republicar o ruleset `e5b63447`** — ele continua existindo e é recuperável pelo id | sim, reversível em segundos |
| `colecoes`/`social`/`ranking`/`moderacao` | erro no deploy; `functions:log` | `firebase functions:delete <fn>`; nada depende delas ainda | sim |
| `torneios` | idem | delete; **mas** se já houver inscrição gravada, o dado fica órfão | só após verificar |
| `conta` | exclusão parcial | **NÃO REVERSÍVEL** — conta excluída não volta | **NÃO prosseguir** sem teste em conta descartável |
| `billing` | compra recusada; RTDN sem consumo | redeploy do commit anterior (`c9409dc` está provado e reproduzível) | sim, **enquanto não houver venda** |
| Hosting | página 404 | `hosting:rollback` (release anterior) | sim |
| **Servidor** | `atualizacaoObrigatoria` em massa; queda de sessões | redeploy da imagem anterior no Railway | **depende do Volume** |
| Cliente | crash / online morto | despublicar faixa interna | sim, enquanto for interna |

### 11.4 O que não se reverte

1. **Exclusão de conta executada** — por desenho. `publicIdIndex` vira lápide.
2. **Escrita de entitlement após venda real** — dinheiro trocou de mãos; reverter
   estado não reverte a cobrança. Estorno é pela Play, e a decisão registrada é
   que **fichas já concedidas não são estornadas**.
3. **`contas.json` do servidor perdido** — se o Volume não estiver montado, as 17
   contas somem no deploy e não há backup automático.
4. **Fichas concedidas por `concederFichasMensais`** — o livro-razão por índice de
   mês impede reconcessão, mas não desfaz concessão.

### 11.5 Dados a preservar antes de começar

- `contas.json` + `avatares/` do Volume do Railway (**único dado real**);
- export do Firestore (7 documentos — barato, e vira baseline);
- o id do ruleset atual, `e5b63447-2ddf-46ea-954a-03d13eca6fba`, para rollback de
  Rules em um comando.

---

## §12. DRY-RUN EXECUTADO

Nada foi publicado. O que foi validado de fato:

| Validação | Método | Resultado |
| --- | --- | --- |
| Rules da RC compilam | `firebaserules.projects.test` (valida sem criar ruleset nem release) | **0 issues** |
| Rules de produção compilam | idem | 0 issues (controle) |
| Artefato de produção × commit | download do zip de origem + diff de 31 arquivos | **31/31 idênticos a `c9409dc`** |
| Corte dos hashes | leitura do algoritmo em `cache/hash.js` | partição por secret, confirmada |
| Deploy único | build id + `updateTime` + MD5 dos objetos | confirmado |
| Servidor no ar e protocolo | HTTP GET + 2 sondas WS sem efeito colateral | protocolo 1, sem auth |
| Superfície do Firestore | `listCollectionIds` + COUNT | 7 coleções, 7 documentos |
| Índices publicados | `firebase firestore:indexes` | 1 índice |

Não foi possível validar: `tsc` dos 5 codebases TypeScript (exigiria
`npm install` em cada um) e o portão de RC (exige a RC composta, que ainda não
existe). Ambos ficam na Fase 1.

---

## §13. GATES PRÉVIOS AO DEPLOY

Cada gate é uma pergunta com resposta binária. Nenhum deles é código.

| # | Gate | Estado | Bloqueia |
| --- | --- | --- | --- |
| **G-1** | A RC contém os 8 commits de Billing que estão em produção? | **NÃO** | tudo |
| **G-2** | A RC contém `functions-conta` + `web/` (exigência da Play)? | **NÃO** | publicação |
| **G-3** | As Rules da RC foram implantadas? | **NÃO** — produção está em 2026-02-24 | qualquer leitura do cliente |
| **G-4** | Os 38 índices foram implantados? | **NÃO** — há 1 | ranking, torneios, moderação |
| **G-5** | PITR habilitado antes de qualquer migração? | **NÃO** | Fase 3 |
| **G-6** | `concederFichasMensais` já executou ao menos uma vez? | **NÃO** — primeira em 16/08 09:00 BRT | venda VIP |
| **G-7** | Existe dead-letter para o RTDN? | **NÃO** | (recomendado, não bloqueante) |
| **G-8** | Decidido o destino das 17 contas do servidor? | **NÃO** | Fase 5 |
| **G-9** | Volume do Railway confirmado e `contas.json` copiado? | **NÃO VERIFICADO** | Fase 5 |
| **G-10** | Produto `master_vip` existe na Play Console? | **NÃO** | venda |
| **G-11** | `group:firebase@flutterflow.io` deve manter `roles/editor`? | **NÃO DECIDIDO** | (segurança, não bloqueante) |
| **G-12** | Refs congeladas para compor a RC? | **NÃO** | reprodutibilidade |

**Nenhum dos 12 gates está fechado.** Sete são decisão humana ou ação externa,
não código.

---

## §14. REGISTRO DA SESSÃO

| Item | Valor |
| --- | --- |
| Branch de documentação | `claude/production-state-audit-84542f` |
| Base | `consolidacao/apk-geral-bmv` @ `0cea0d6d68f2c93613b985f4aa85800d77cf42d7` |
| HEAD ao iniciar | `fb9edb5` (linhagem placeholder de `main`) — **rebaixada para a base autorizada** |
| Árvore de trabalho | limpa antes e depois |
| Merge / rebase / cherry-pick / force-push | **nenhum** |
| Commits desta OS | 1 (este documento) |

### Comandos de leitura executados contra produção

```
firebase login:list · firebase projects:list
firebase functions:list --project buraco-master-vip [--debug]
firebase firestore:indexes · firebase apps:list · firebase hosting:sites:list
GET  cloudfunctions/v2 · cloudscheduler/v1 · pubsub/v1 (topics, subscriptions)
GET  secretmanager/v1 (secrets, versions — nunca :access)
GET  firebaserules/v1 (releases, rulesets) · eventarc/v1 · run/v2
GET  cloudbuild/v1 · serviceusage/v1 · firestore/v1 (databases)
GET  storage/v1 (metadados + 1 objeto de origem, 196 KB)
GET  pubsub :getIamPolicy · POST cloudresourcemanager :getIamPolicy
POST firestore :listCollectionIds · :runAggregationQuery (COUNT)
POST firebaserules :test (valida sem criar)
```

### Confirmação explícita

> **Nenhum deploy foi executado.**
> Não foi executado `firebase deploy` nem `gcloud functions deploy`. Não houve
> deploy de servidor. Nenhuma Rule de produção foi alterada. Nenhum recurso foi
> criado ou excluído. Scheduler, Pub/Sub, IAM e secrets não foram modificados.
> Nenhum dado foi migrado, escrito ou apagado. Nenhum VIP foi concedido ou
> revogado. Nenhum merge, nenhum force-push.
>
> Todas as chamadas foram de leitura, com duas exceções que **não escrevem**:
> `:getIamPolicy` (lê política) e `firebaserules:test` (valida fonte sem criar
> ruleset nem release).
>
> Nenhum valor de secret, chave privada, token ou credencial foi lido, impresso
> ou gravado em arquivo.
