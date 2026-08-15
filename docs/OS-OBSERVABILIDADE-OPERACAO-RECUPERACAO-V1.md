# OS — Observabilidade, Operação e Recuperação de Produção V1

Auditoria **somente leitura**. Nenhum deploy, nenhuma alteração em produção,
nenhum merge, nenhum incidente gerado, nenhum log excluído, nenhum secret
rotacionado, nenhuma mudança em Billing ou economia.

---

## 0. Sobre a base desta auditoria (leia primeiro)

O projeto **não tem uma árvore única**. O código dos subsistemas vive em
branches paralelas que nunca foram integradas, e por isso esta auditoria não
pôde ser feita sobre um único checkout. Cada afirmação abaixo cita a árvore de
onde foi lida:

| Sigla | Branch | HEAD | O que ela carrega de mais avançado |
|---|---|---|---|
| **A** | `claude/account-deletion-google-play-compliance-b94769` | `1acc5f9` | ranking, social, conta, moderação, torneios, rules, `web/` |
| **B** | `claude/billing-vip-production-activation-525b63` | `125ec96` | billing (29 arquivos — o mais avançado) |
| **C** | `correcao/assets-loja-v1` | `e65495d` | app Flutter + `android/` + workflow do AAB |
| **D** | `claude/gate-automatizado-rc-v1-819647` | `836b042` | portão de RC, `ferramentas/` |
| **E** | `feat/economia-boas-vindas-vitorias` | `42928c3` | `functions-economia` (existe **só** aqui) |
| **WS** | `claude/ws-auth-identidade-1fc213` | `1615979` | único cliente Flutter que autentica no WebSocket |
| **SRV** | `buraco-servidor` @ `seguranca/ws-auth-identidade` | `71199e8` | servidor Node/WebSocket |

Esta fragmentação **não é um detalhe de organização: é o achado operacional
mais grave desta auditoria**, e reaparece em quase todas as seções. Ver §12.

---

## 1. Inventário de observabilidade

### 1.1 O que existe

| Camada | Logging | Crash | Métricas | Tracing | Alertas | Health check |
|---|---|---|---|---|---|---|
| App Flutter/Android | **NÃO** (2 `print` em ~330 arquivos) | **NÃO** | NÃO | NÃO | NÃO | n/a |
| Functions — billing | SIM (21 chamadas) | herda GCP | NÃO | NÃO | NÃO | NÃO |
| Functions — ranking | fraco (5 em 27 arq.) | herda GCP | NÃO | NÃO | NÃO | `diagnosticarRanking` |
| Functions — social | fraco (5) | herda GCP | NÃO | NÃO | NÃO | NÃO |
| Functions — conta | razoável (6) | herda GCP | NÃO | NÃO | NÃO | NÃO |
| Functions — moderação | fraco (4) | herda GCP | NÃO | NÃO | NÃO | NÃO |
| Functions — torneios | razoável (7) | herda GCP | NÃO | NÃO | NÃO | NÃO |
| Functions — coleções | razoável (4) | herda GCP | NÃO | NÃO | NÃO | NÃO |
| Functions — economia | **NENHUM log** | herda GCP | NÃO | NÃO | NÃO | NÃO |
| Firestore | Cloud Logging (padrão GCP) | n/a | NÃO | NÃO | NÃO | n/a |
| Authentication | Cloud Logging (padrão GCP) | n/a | NÃO | NÃO | NÃO | n/a |
| Servidor/WebSocket | **10 linhas em 4.538** | **NÃO** | NÃO | NÃO | NÃO | `/health` estático |
| Play Billing | via Functions | n/a | NÃO | NÃO | NÃO | NÃO |
| RTDN/Pub-Sub | **SIM, bom** | herda GCP | NÃO | NÃO | NÃO | NÃO |

### 1.2 Varredura por configuração de monitoramento

Busca por `alerting`, `alertPolicy`, `uptime check`, `cloud monitoring`,
`opentelemetry`, `sentry`, `firebase_analytics`, `firebase_performance`,
`logBasedMetric` nas cinco árvores: **zero ocorrências em código ou
configuração**. Os únicos acertos são `package-lock.json` (dependências
transitivas do `firebase-functions`) e uma linha de `docs/PUBLICACAO-GOOGLE-PLAY-V1.md`
que já registrava a ausência.

**Não existe nenhuma configuração de alerta, métrica ou uptime check
versionada neste projeto.**

### 1.3 O que existe e é bom (crédito devido)

Há um **conjunto real de ferramentas administrativas de diagnóstico e
recuperação**, que é a parte mais madura da operação:

- `diagnosticarPopulacaoVip` (billing, callable admin)
- `diagnosticarMetadadosLegados` (billing, callable admin)
- `reconciliarEntitlementDoJogador` (billing, callable admin — reconciliação manual por jogador)
- `backfillPurchaseTokenHash` (billing, callable admin)
- `diagnosticarRanking` (ranking, callable)
- `reprocessarBacklogDeRanking` (ranking, callable)
- `reconciliarEntitlements` (billing, `onSchedule` — varredura periódica)

E há **trilhas de auditoria persistidas em Firestore**, que valem mais que log
para investigação porque não expiram na retenção do Cloud Logging:
`billingEvents`, `compras`, `fichasConcessoes`, `economiaLedger`,
`rankingLedger`, `rankingAudit`, `moderationAudit`, `audit`.

---

## 2. Crash do aplicativo

### 2.1 Veredito: NÃO EXISTE

Provado por código, não por ausência de memória:

- **`app/pubspec.yaml` (árvore C, 138 linhas)** — não declara
  `firebase_crashlytics`, `firebase_analytics`, `firebase_performance`,
  `sentry_flutter` nem qualquer equivalente. As dependências Firebase são
  exatamente `firebase_core`, `firebase_auth`, `cloud_firestore`,
  `cloud_functions`, `firebase_app_check`.
- **Varredura por "crashlytics" em todas as branches do repositório**: 3
  acertos, todos no mesmo arquivo de documentação
  (`docs/PUBLICACAO-GOOGLE-PLAY-V1.md`), e ambos afirmando a ausência —
  *"Sem `firebase_crashlytics`"* e *"**sem** analytics, **sem** crashlytics"*.

### 2.2 Tratamento de erro Flutter: também NÃO EXISTE

Varredura por `FlutterError.onError`, `runZonedGuarded`,
`PlatformDispatcher.instance.onError` e `recordError` em `app/lib` **de todas
as branches locais e remotas**: **zero ocorrências**. Nenhuma branch do projeto
instala tratador global de erro.

O `main()` (`app/lib/main.dart:54-73`, árvore C) faz
`WidgetsFlutterBinding.ensureInitialized()` e `Firebase.initializeApp(...)` e
mais nada. Não há zona guardada, não há `onError`.

### 2.3 O erro que o app engole na inicialização

```dart
try {
  await Firebase.initializeApp(options: const FirebaseOptions(...));
} catch (_) {
  // Ambiente sem Firebase configurado (ex.: web de teste) — segue o jogo.
}
```
— `app/lib/main.dart:59-71`

O comentário justifica o `catch` vazio pelo **navegador de teste**. Mas o
`catch` não distingue ambiente: **no aparelho do jogador**, uma falha de
inicialização do Firebase (config errada, Play Services quebrado, relógio
fora de hora) faz o app subir sem Auth, sem Firestore e sem Functions — sem
crash, sem log, sem aviso. O jogador vê um app que "não loga" e ninguém do
outro lado fica sabendo.

Outros quatro erros engolidos sem registro: `main.dart:573`, `main.dart:576`,
`main.dart:689` (`onError: (Object _) {}`), `main.dart:1594`, `mesa.dart:1500`.

### 2.4 Identificação da versão do app: NÃO EXISTE

`pubspec.yaml` declara `version: 1.0.0+1`, mas o workflow de release
(`.github/workflows/release-aab.yml:51-59`) recebe `version_code` e
`version_name` como **entradas de `workflow_dispatch`** — digitadas na hora do
build. O que foi publicado não fica registrado em lugar nenhum do repositório.

Consequência combinada com §2.1: **não há como atribuir uma falha a um build.**
Mesmo que houvesse crash reporting, não haveria a que versão associar.

### 2.5 Relacionar falha a usuário sem expor dado indevido

Não aplicável hoje (não há crash reporting). Quando houver: o projeto já tem a
convenção certa para isso — `uid` do Firebase Auth no log e nunca e-mail nem
nome. Ver §11, onde essa disciplina se confirma em todo o backend.

---

## 3. Backend — logs de Functions e servidor

### 3.1 Functions

Todas as codebases usam ou `logger.*` do `firebase-functions` (TypeScript) ou
`console.*` (JavaScript). Ambos chegam ao Cloud Logging com severidade e com os
campos de contexto do GCP (nome da função, `execution_id`, `trace`, duração,
resultado). Portanto:

| Capacidade pedida pela OS | Situação | Origem |
|---|---|---|
| função / operação | **EXISTE** | metadado automático do Cloud Functions |
| request | **EXISTE PARCIALMENTE** | `execution_id` automático; nenhum id de correlação próprio |
| usuário | **EXISTE** | `uid` explícito em quase todo log relevante |
| `publicId` | **EXISTE PARCIALMENTE** | só no ranking (`firestore.ts:559`) |
| partida | **EXISTE** | `matchId` em rastreabilidade e economia |
| purchaseToken de forma segura | **EXISTE, exemplar** | ver §3.3 |
| evento RTDN | **EXISTE** | `messageId` em todos os ramos de `rtdn.js` |
| erro | **EXISTE PARCIALMENTE** | erro é logado; sucesso muitas vezes não |
| resultado | **EXISTE PARCIALMENTE** | idem |
| duração | **EXISTE** | metadado automático do Cloud Functions |

**Lacuna real:** não há **id de correlação próprio** atravessando app →
callable → gatilho → agendador. O `execution_id` do GCP não cruza fronteira de
função. Investigar um caso que passa por `validarCompraPlay` →
`aoRegistrarResultadoOficial` → `concederFichasMensais` exige juntar as pontas
por `uid` e horário, na mão.

**Lacuna real:** `functions-economia` (árvore E) **não tem uma única chamada de
log**. É a codebase que mexe no saldo do jogador.

### 3.2 Servidor

`server.js` tem **10 chamadas de log em 4.538 linhas**:

- 4 de persistência de contas (`[contas]`, `[salas]`)
- 5 de autenticação (`[auth]` — expiração, protocolo, recusa, divergência de identidade, `FIREBASE_PROJECT_ID` ausente)
- 1 de boot (`listen`)

**Não há log de**: conexão aberta, desconexão, reconexão, criação de mesa,
início de partida, fim de partida, abandono, erro de protocolo fora do
handshake, exceção não tratada.

**Não há `process.on('uncaughtException')`, `process.on('unhandledRejection')`
nem tratador de `SIGTERM`** (varredura em `server.js`: zero ocorrências). Uma
exceção não tratada mata o processo; o Railway reinicia; **todas as partidas em
curso somem e não fica registro nenhum de que houve queda nem de por quê.**

### 3.3 Segredos e tokens em log — disciplina exemplar

Este é o ponto mais forte da auditoria. As decisões são deliberadas e estão
documentadas no próprio código:

- `rotuloToken(hash)` devolve **8 caracteres do SHA-256** do token
  (`functions-billing/entitlement.js:494-497`). É o rótulo usado em log dos
  dois lados — o cliente Flutter deriva o mesmo rótulo (`crypto` foi promovido a
  dependência de produção justamente para isso, `pubspec.yaml:72-77`). Permite
  correlacionar uma compra entre app e servidor **sem o token aparecer em lugar
  nenhum**.
- `rtdn.js:95-106` — o `e.message` de um JSON inválido é **deliberadamente
  omitido** do log, porque o `SyntaxError` do V8 cita um trecho da entrada e um
  payload truncado no meio de um `purchaseToken` imprimiria o token "pela porta
  dos fundos". Loga-se `e.name` e o tamanho em bytes.
- `server.js:3965-3967` — *"NUNCA registra o token em log (§19)"*; o motivo
  detalhado da recusa fica só no log do servidor e o cliente recebe motivo
  genérico, para não permitir enumeração.
- `server.js:4480-4484` — a credencial vai no **cabeçalho do upgrade**, nunca em
  query string, *"então não cai em log de acesso, proxy ou métrica"*.
- `functions/src/rastreabilidade.ts:391-396` — o alvo de um sinal antifraude
  **não vai para o log**: *"log de observabilidade não é lugar de lista de
  suspeitos"*.

---

## 4. Billing — "Paguei e não virei VIP"

### 4.1 Reconstrução ponta a ponta: EXISTE, e é a melhor cadeia do projeto

| # | Etapa | Evidência | Onde |
|---|---|---|---|
| 1 | compra apresentada pelo app | doc `compras/{sha256(token)}` com `uid`, `produtoId`, `orderId`, `estado: em_validacao`, `criadoEm` | `index.js:307-325` |
| 2 | validação recebida | mesmo doc + rejeição por titularidade logada | `index.js:311-330` |
| 3 | chamada ao Google | `consultadoEm` capturado **antes** da chamada; falha grava `ultimoErro` no doc e loga | `index.js:373-385` |
| 4 | estado retornado | `subscriptionState` / `purchaseState` consolidados | `index.js:387-397` |
| 5 | escrita do entitlement | `console.info('[billing] entitlement consolidado na validacao', {uid, estado, vipAtivo, decisao, token})` | `index.js:420-426` |
| 6 | RTDN posterior | `billingEvents/{messageId}` + log com `messageId`, `uid`, `tipo`, `estado`, `vipAtivo`, `decisao`, `token` | `rtdn.js:176-211` |
| 7 | estado final | `playerEntitlements/{uid}` legível pelo dono e por admin | `firestore.rules:303-305` |

Duas escolhas de projeto tornam essa cadeia investigável meses depois:

- **O estado é gravado mesmo quando a compra não vale** (`index.js:399-427`):
  uma assinatura que a Google diz estar `EXPIRED` vira "sem VIP" no documento,
  em vez de virar um `aprovada: false` que ninguém persiste.
- **A trilha vive no Firestore, não só no log**, e portanto não expira com a
  retenção do Cloud Logging.

E existe a ferramenta de conserto: **`reconciliarEntitlementDoJogador`**
(`index.js:789`), que reconsulta a Google usando o `purchaseToken` guardado e
reaplica o estado — é a ação corretiva para exatamente este caso.

### 4.2 Lacunas

1. **O primeiro passo da cadeia não tem evidência do lado do app.** Se o jogador
   pagou mas `validarCompraPlay` nunca foi chamada (app fechou, rede caiu,
   exceção no cliente), **não existe registro nenhum** — o `compras/` só nasce
   dentro da função. O caso "pagou e o app nunca avisou o backend" é
   invisível. Sem crash reporting (§2), é invisível também pelo lado do crash.
2. **Não há alerta.** `console.error('[billing] Play Developer API falhou')` e
   `'[billing] conflito de titularidade de token'` são exatamente os eventos que
   deveriam acordar alguém, e não acordam ninguém (§8).
3. **`concederFichasMensais` não está implantada** (registro anterior do
   projeto; a cadeia técnica existe, a função não está em produção). Um VIP
   ativo pode não receber ficha e a única evidência será a **ausência** de linha
   em `fichasConcessoes` — ausência é a evidência mais cara de investigar.
4. **Bloqueio externo, não técnico:** o produto `master_vip` não existe na Play
   Console, então a cadeia inteira está sem tráfego real. Ela nunca foi
   exercitada com uma compra de verdade.

---

## 5. Economia — "Minhas fichas sumiram"

### 5.1 Achado principal: há DOIS livros-razão escrevendo o MESMO saldo

Ambos gravam o campo `fichas` do documento `usuarios/{uid}`:

| | `functions-economia` (árvore E) | `functions-billing/fichas` (árvore B) |
|---|---|---|
| Livro-razão | `economiaLedger` | `fichasConcessoes` |
| Chave | `partida\|{matchId}\|{uid}\|{motivo}` e `boas_vindas\|{uid}` | `{purchaseTokenHash}\|{indice}` |
| Escrita no saldo | **absoluta** — `{fichas: depois}` | **incremental** — `FieldValue.increment(fichas)` |
| Registra `saldoAntes` | **SIM** | **NÃO** |
| Registra `saldoDepois` | **SIM** | **NÃO** |
| Registra `motivo` | **SIM** | não (implícito no nome da coleção) |
| Registra `matchId` | **SIM** | n/a |
| Log | **nenhum** | `console.info('[billing] parcela de ativacao')` |

Referências: `functions-economia/economiaStore.js:118-142` e
`functions-economia/economia.js:68-73`; `functions-billing/fichasStore.js:72-95`
e `functions-billing/fichas.js:58`.

**As duas codebases nunca coexistiram numa mesma árvore.** `functions-economia`
existe apenas em E; `fichas.js` existe apenas em B. A interação entre elas
— duas semânticas de escrita diferentes sobre o mesmo campo — **nunca foi
testada e nunca rodou junta**.

### 5.2 Capacidade de investigação, por caminho

| Evidência pedida pela OS | Caminho economia | Caminho billing |
|---|---|---|
| saldo anterior | **SIM** (`saldoAntes`) | **NÃO** |
| causa da mutação | **SIM** (`motivo`) | parcial (coleção + `origem`) |
| partida | **SIM** (`matchId`) | n/a |
| recompensa | **SIM** | **SIM** (`fichas`, `indice`, `planoBase`) |
| débito | **SIM** (`delta` e `deltaNominal` separados, com piso em 0) | n/a (só credita) |
| proteção contra duplicação | **SIM** (recibo na mesma transação) | **SIM** (`parcela_ja_paga`) |

O caminho da economia é **exemplar**: guarda `deltaNominal` (o que a regra
mandou) e `delta` (o que de fato coube depois do piso de zero), de modo que
`saldoAntes + delta == saldoDepois` é invariante verdadeira em toda linha
(`economia.js:212-227`).

**Veredito:** "minhas fichas sumiram" é investigável **para mutações de
partida e boas-vindas**, e **não é reconstruível** para parcelas de assinatura —
e nenhum dos dois lados sabe da existência do outro, então **não há uma
linha do tempo única do saldo de um jogador**.

*Nada do modelo econômico foi alterado, conforme a OS.*

---

## 6. Partidas / servidor — diagnóstico

| Situação | Diagnosticável hoje? | Evidência disponível |
|---|---|---|
| desconexão | **NÃO** | `desconectar()` não loga |
| reconexão | **NÃO** | `_agendarReconexao` no cliente não loga; servidor não distingue |
| queda do servidor | **NÃO** | sem `uncaughtException`, sem `SIGTERM`; só reinício silencioso |
| handshake recusado | **SIM** | `console.warn("[auth] conexão N recusada: " + codigo)` — `server.js:4047` |
| sessão expirada | **SIM** | `server.js:3954` + `authExpirou` com `carenciaMs` ao cliente |
| partida abandonada | **NÃO** | nenhum log de ciclo de vida de mesa/partida |
| erro de protocolo | **PARCIAL** | só a recusa por versão (`server.js:3978`); JSON inválido responde ao cliente e **não loga** (`server.js:4494`) |
| cliente incompatível | **SIM no servidor, ver §6.1** | `atualizacaoObrigatoria` + `console.warn` |

### 6.1 O cliente que vai na loja não fala com o servidor que está no ar

O servidor exige `PROTOCOLO_MINIMO = 2` e trata cliente sem `auth` como app
velho por definição (`server.js:3862, 3976-3990`).

O `online_service.dart` da **árvore C — que é a árvore com `android/` e com o
workflow do AAB, ou seja, a que geraria o binário publicável** — não manda
`auth`, não manda protocolo, e no `_aoReceber` tem `default: return`
(`online_service.dart:187-188`). Ou seja: recebe `atualizacaoObrigatoria`,
**descarta em silêncio**, cai, e reagenda reconexão a cada 2–12s para sempre,
mostrando ao jogador `"conexão instável"`.

O cliente correto existe — `claude/ws-auth-identidade-1fc213`, que trata
`authFalhou`, `authExpirou` e `atualizacaoObrigatoria` e tem um
`OnlineStatus.atualizacaoObrigatoria` próprio — mas **está isolado**: varredura
em todas as branches por cliente que mande `{tipo:'auth'}` retorna **só essa
uma**, e ela não está em A, B, C, D nem E.

Isto não é um achado de observabilidade: **é um bloqueador de lançamento**, e o
sintoma que ele produz é indistinguível de "servidor fora do ar" — que é
precisamente o problema de diagnóstico que esta OS existe para resolver.

### 6.2 O servidor também não tem uma ponta única

`seguranca/ws-auth-identidade` (`71199e8`) e `enforcement/visao-espectador`
(`3c8b07e`) **não se contêm mutuamente** — verificado por
`git merge-base --is-ancestor` nas duas direções. Não há um `server.js`
implantável que tenha autenticação **e** enforcement de espectador.

---

## 7. Health checks

### 7.1 O que existe

**Servidor:** `/health` e `/healthz` (`server.js:4440-4442`):

```js
if (req.url === "/health" || req.url === "/healthz") {
  res.writeHead(200, { "content-type": "text/plain" }); return res.end("ok");
}
```

**É um health check que mente.** Responde `200 ok` incondicionalmente, antes de
qualquer verificação. Um servidor que subiu **sem `FIREBASE_PROJECT_ID`** — e
que portanto, por decisão explícita de *fail closed*, **não autentica ninguém**
(`server.js:4432-4435`) — responde `200 ok`. O monitor diz "saudável" enquanto
nenhum jogador consegue entrar.

**Firebase:** nenhum health check. Não há endpoint, função de ping nem sinal
sintético para Functions, Firestore ou Auth.

### 7.2 Conjunto mínimo proposto (proposta, não implementação)

| Sinal | Responde o quê | Forma sugerida |
|---|---|---|
| `/health` (raso) | o processo está de pé | manter como está — é o que o Railway precisa |
| `/readyz` (fundo) | o servidor consegue **atender** | `200` só se `FIREBASE_PROJECT_ID` estiver definido **e** os certificados x509 do Google tiverem sido obtidos ao menos uma vez; `503` caso contrário |
| `/version` | qual build está no ar | `PROTOCOLO_ATUAL`, `PROTOCOLO_MINIMO`, SHA do commit, `uptime` |
| ping de backend | Functions responde | uma callable trivial autenticada, chamada de fora por rotina |
| ping de dependência | Firestore responde | leitura de um doc fixo dentro da callable acima |

**Restrição respeitada:** nenhum desses expõe operação administrativa. `/readyz`
e `/version` devolvem **booleano e identificador de build**, nunca contagem de
jogadores, nunca lista de mesas, nunca configuração, e não aceitam parâmetro.
Health check não pode virar porta de administração — e a contagem de conexões,
que seria útil, fica **de fora** de propósito por ser informação de negócio num
endpoint sem autenticação.

---

## 8. Alertas

**Nenhum alerta existe hoje.** Classificação do que deveria existir:

### P0 — acordar alguém, a qualquer hora

| Situação | Sinal detectável | Existe hoje? |
|---|---|---|
| servidor indisponível | `/readyz` falhando, ou `/health` sem resposta | endpoint sim, alerta **não** |
| autenticação quebrada globalmente | taxa de `[auth] ... recusada: CREDENCIAL_INVALIDA` ou `ERRO_INTERNO` acima do normal | log existe, métrica **não** |
| partidas impossíveis | queda a zero de escritas em `matches` | **nenhuma métrica** |
| compras cobradas sem entitlement em escala | `compras` com `estado: em_validacao` envelhecendo, ou taxa de `'[billing] Play Developer API falhou'` | dado existe no Firestore, alerta **não** |
| corrupção de economia | saldo negativo, ou `economiaLedger` com `saldoAntes + delta != saldoDepois` | invariante existe no código, **não é monitorada** |
| crash generalizado após release | — | **impossível hoje**: não há crash reporting (§2) |

### P1 — no mesmo dia útil

- taxa de erro elevada numa função relevante (`validarCompraPlay`, `processarResultado`, `registrarDenuncia`)
- RTDN interrompido — **detectável por ausência**: nenhum documento novo em `billingEvents` numa janela em que houve compras
- Social indisponível (`functions-social` com erro sustentado)
- ranking sem atualização — `rankingBacklog` crescendo sem drenar; já há `logger.warn("partida sem identidade publica canonica foi para o backlog")`
- degradação relevante de latência

### P2 — backlog

- erro isolado sem repetição
- falha cosmética
- recurso secundário (Hall, prévia de torneios)

**Observação sobre custo:** P0 e P1 são quase todos alcançáveis com *log-based
metrics* do Cloud Logging sobre logs **que já existem**, mais uma rotina externa
batendo em `/readyz`. O que falta é configuração, não instrumentação — com três
exceções que exigem código: crash do app, "partidas impossíveis" e a invariante
da economia.

---

## 9. Recuperação

Mapeamento sem execução. Classificação conforme pedido pela OS.

| Mecanismo | Situação | Fundamento |
|---|---|---|
| **Rollback do app** | **EXISTE PARCIALMENTE** | A Play Console permite reverter para um `versionCode` anterior, mas o AAB anterior precisa existir e o repositório **não registra qual `versionCode` corresponde a qual commit** (§2.4). Rollback vira arqueologia. |
| **Rollback/deploy de Functions** | **EXISTE PARCIALMENTE** | Não há deploy automatizado — `firebase-tools` aparece no CI **apenas para emulador**, nunca para deploy. Deploy é manual, de estação de trabalho. Reverter = `firebase deploy` de um commit anterior, **mas não há registro de qual commit está em produção**. |
| **Rollback do servidor** | **EXISTE PARCIALMENTE** | Railway mantém deploys anteriores e permite redeploy. O `server.js` é bundle sem fonte, então o rollback é do artefato inteiro — não dá para reverter um pedaço. |
| **Reversão de Rules** | **EXISTE PARCIALMENTE** | O Firebase Console guarda histórico de Rules e permite reverter pela UI. `firebase/firestore.rules` está versionado, então há a que voltar. Manual, sem automação. |
| **Suspender funcionalidade problemática** | **NÃO EXISTE** (genérico) | `config/featureFlags` existe mas governa **exclusivamente** `kitPioneiros2026Enabled` (`firebase/functions/index.js:36,237`). Não há flag para partida, ranking, social, loja ou torneio. |
| **Impedir vendas VIP** | **EXISTE** (de fato, não documentado) | `lerCatalogo()` lê `configuracao/billing.produtos` do Firestore (`functions-billing/index.js:198-202`) e produto fora do catálogo é recusado com `failed-precondition` (`index.js:296-301`). **Esvaziar esse documento interrompe toda venda imediatamente, sem deploy.** É o kill switch mais eficaz que o projeto tem, e ninguém o registrou como tal. |
| **Preservar dados durante incidente** | **EXISTE PARCIALMENTE** | As trilhas em Firestore (§1.3) sobrevivem a qualquer rollback de código, e as escritas críticas são transacionais e idempotentes. **Não há backup/export agendado do Firestore configurado no repositório**, e o `dados/` do servidor depende de um Volume do Railway com fallback silencioso para memória (`server.js:4425-4427`). |

**Nenhum kill switch foi inventado.** O único que existe é o do catálogo, e ele
existe por consequência do desenho, não por intenção declarada.

### Recomendação de classificação

- **RECOMENDADO ANTES DO LANÇAMENTO:** registro de qual commit/`versionCode`
  está em produção (Functions, servidor e app); documentar o kill switch do
  catálogo como procedimento; `/readyz` no servidor.
- **PODE FICAR PARA DEPOIS:** feature flags genéricas; deploy automatizado;
  export agendado do Firestore.

---

## 10. Runbook de lançamento — primeiras horas e dias

> Regra geral que vale para todos os incidentes abaixo:
> **primeiro preservar evidência, depois agir.** Trilha em Firestore não se
> apaga, log do Cloud Logging expira — extraia antes de mexer.

### 10.1 Pico de crashes

- **Evidência:** *não existe.* Play Console → Vitals → ANRs e travamentos é a
  **única** fonte, e ela só mostra o que o Android capturou, sem stack de Dart.
- **Serviço:** app.
- **Ação inicial segura:** interromper o rollout na Play Console (*halt
  rollout*) — não requer novo build. Só então investigar.
- **NÃO fazer:** publicar correção às cegas. Sem crash reporting você não sabe
  o que quebrou, e cada envio novo é mais uma versão sem diagnóstico.

### 10.2 Usuários sem conseguir entrar

- **Evidência:** Firebase Console → Authentication (contagem de sign-ins);
  Cloud Logging filtrando `[auth]` no servidor; verificar se
  `FIREBASE_PROJECT_ID` está definido no Railway.
- **Serviço:** Authentication, servidor.
- **Ação inicial segura:** confirmar a variável de ambiente. Ela ausente é
  *fail closed* por desenho e derruba 100% das autenticações — e o `/health`
  continua respondendo `ok` (§7.1), então **não confie no health check aqui**.
- **NÃO fazer:** baixar `PROTOCOLO_MINIMO` para "deixar entrar". Isso reabre a
  confiança em `jogadorId` vindo do cliente, que é a impersonação que a
  autenticação fecha.

### 10.3 Servidor offline

- **Evidência:** Railway → Deployments e logs do processo; `/health` de fora.
- **Serviço:** servidor.
- **Ação inicial segura:** redeploy da revisão anterior conhecida pelo Railway.
- **NÃO fazer:** editar `server.js` direto para "consertar rápido". É bundle
  sem fonte; um erro de digitação em produção não tem revisão de código que o
  pegue.
- **Atenção:** sem `uncaughtException` (§3.2), o processo pode ter morrido e
  reiniciado várias vezes **sem deixar rastro do motivo**. Procure o padrão de
  reinício, não a mensagem de erro — ela não existe.

### 10.4 Partida travada

- **Evidência:** `matches` no Firestore; `rankingBacklog`; log
  `"encerramento de partida registrado"` (`rastreabilidade.ts:213`).
- **Serviço:** servidor + Functions (torneios/ranking).
- **Ação inicial segura:** identificar se a partida chegou a ser registrada. Se
  chegou, o problema é de apuração; se não chegou, é do servidor.
- **NÃO fazer:** escrever em `matches` na mão. O ranking reage a **toda**
  escrita nessa coleção e uma escrita manual vira pontuação real.

### 10.5 Compra VIP não reconhecida

- **Evidência, nesta ordem:** `compras/{sha256(token)}` → campo `estado` e
  `ultimoErro`; `playerEntitlements/{uid}`; `billingEvents` (RTDN);
  Cloud Logging filtrando `[billing]` e o rótulo de 8 caracteres do token.
- **Serviço:** billing, Play.
- **Ação inicial segura:** chamar **`reconciliarEntitlementDoJogador`** — ela
  reconsulta a Google e reaplica o estado. É a ação corretiva desenhada para
  este caso e é idempotente.
- **NÃO fazer:** editar `playerEntitlements/{uid}` na mão. O documento é escrito
  por transação com regras de titularidade; uma edição manual pode conceder VIP
  a quem estornou, e não deixa linha em trilha nenhuma.
- **NÃO fazer:** pedir o `purchaseToken` ao jogador. Ele não tem, e o token
  completo não deve circular. O rótulo de 8 caracteres basta para correlacionar.

### 10.6 Saldo de ficha inconsistente

- **Evidência:** `economiaLedger` (tem `saldoAntes`/`saldoDepois`/`motivo`/`matchId`)
  **e** `fichasConcessoes` (parcelas de assinatura). **Consulte os dois** — §5.1.
- **Serviço:** economia, billing.
- **Ação inicial segura:** reconstruir a linha do tempo somando as duas
  coleções e comparar com `usuarios/{uid}.fichas`. A divergência entre a soma e
  o saldo é o diagnóstico.
- **NÃO fazer:** corrigir o saldo escrevendo em `usuarios/{uid}.fichas`.
  Isso quebra a invariante `saldoAntes + delta == saldoDepois` de todas as
  linhas futuras do `economiaLedger` e destrói a capacidade de auditar aquele
  jogador para sempre.

### 10.7 RTDN parado

- **Evidência:** ausência de documentos novos em `billingEvents`; GCP →
  Pub/Sub → subscription → *unacked messages* e *oldest unacked message age*.
- **Serviço:** Pub/Sub, billing.
- **Ação inicial segura:** confirmar que o tópico existe e que o Play Console
  aponta para ele; a varredura agendada `reconciliarEntitlements` cobre parte do
  atraso sozinha, então **o serviço degrada, não quebra**.
- **NÃO fazer:** apagar mensagens da fila para "destravar". Elas são a única
  notícia de estorno e cancelamento que o sistema recebe.

### 10.8 Denúncias graves

- **Evidência:** `reports` (admin), `moderationAudit`, `sanctions`.
- **Serviço:** moderação.
- **Ação inicial segura:** `aplicarSancao` pela callable.
- **NÃO fazer:** ler `reports` e repassar conteúdo para fora do console. O
  desenho separa `reports` (interno) de `reportReceipts` (do denunciante) de
  propósito (`firestore.rules:622-636`), e conteúdo de denúncia é dado sensível.

### 10.9 Regressão introduzida pela nova versão

- **Evidência:** Play Console → Vitals comparando `versionCode`; **mas** §2.4:
  o repositório não diz qual commit gerou qual `versionCode`.
- **Serviço:** app.
- **Ação inicial segura:** *halt rollout* e reverter para o `versionCode`
  anterior.
- **NÃO fazer:** assumir que a regressão é do app. Sem correlação de versão,
  uma mudança de backend implantada no mesmo dia é indistinguível de uma
  regressão de cliente.

---

## 11. Privacidade dos logs

Varredura por vazamento de token Firebase, `purchaseToken` completo,
credenciais, secrets, e-mail, dados pessoais e conteúdo de denúncia, em todas as
codebases e no servidor.

| Categoria | Resultado |
|---|---|
| token Firebase (ID token) | **Nenhum vazamento.** `server.js:3965-3967` declara e cumpre a regra; o token vai no cabeçalho do upgrade, nunca em URL (`server.js:4480-4484`). |
| `purchaseToken` completo | **Nenhum vazamento.** Só o rótulo de 8 caracteres do SHA-256 aparece em log. O token cru é persistido em `playerEntitlements/{uid}/interno/{doc}`, que é `allow read, write: if false` — **fechado inclusive para admin** (`firestore.rules:316-318`). |
| credenciais / secrets | **Nenhum vazamento.** A conta de serviço da Play entra por `secrets: [CONTA_SERVICO_PLAY]`; o servidor usa só `FIREBASE_PROJECT_ID`, que não é segredo, e não carrega service account nenhuma. |
| e-mail / dados pessoais | **Nenhum vazamento.** Nenhum log de backend contém `email`, `displayName`, `apelido` ou telefone — busca dirigida retornou zero. Os logs identificam por `uid`. |
| conteúdo de denúncia | **Nenhum vazamento.** `logger.info("denuncia recusada", ...)` não carrega texto; o alvo de sinal antifraude é omitido de propósito (`rastreabilidade.ts:391-396`). |

### Veredito de privacidade

**Nenhum vazamento real foi encontrado.** Não há, portanto, problema de
segurança a classificar nesta seção. Esta é a área mais bem executada do
projeto: as decisões não são acidentais — estão comentadas, justificadas e
referenciadas a seções de OS anteriores.

**Um ponto de atenção que não é vazamento:** o `apiKey` do Firebase está
embutido em `app/lib/main.dart:62`. Isso é **correto e esperado** — a apiKey do
Firebase é identificador público, não credencial, e a proteção real é Rules +
App Check. Registrado aqui só para que não seja "descoberto" durante um
incidente e tratado como incidente de segurança.

**Uma exposição menor, fora de log:** o endpoint `/avatar/<jogadorId>` do
servidor (`server.js:4444-4451`) serve a foto de qualquer jogador **sem
autenticação**, com `access-control-allow-origin: *`. Requer conhecer o
`jogadorId`. É P2, e é de superfície pública — não de log.

---

## 12. O achado transversal: não se sabe o que está em produção

Todas as seções acima esbarram no mesmo muro, e ele merece ser dito sozinho.

1. **Não há uma árvore integrada.** Sete codebases de Functions existem, mas
   **nenhum `firebase.json` declara todas**. O da árvore A declara sete
   (`colecoes`, `billing`, `torneios`, `moderacao`, `ranking`, `social`,
   `conta`) e **não declara `economia`**. O da árvore E declara cinco
   (`colecoes`, `billing`, `torneios`, `economia`, `moderacao`) e **não declara
   `ranking`, `social` nem `conta`**. Deployar a partir de qualquer uma perde
   funções da outra.
2. **Não há deploy automatizado nem registro de deploy.** `firebase-tools` só
   aparece no CI para emulador. Nada no repositório diz qual commit está em
   produção, em nenhum dos três alvos (Functions, servidor, app).
3. **O servidor tem duas pontas incompatíveis** que não se contêm (§6.2).
4. **O cliente publicável não fala com o servidor implantado** (§6.1).

Consequência operacional direta: **num incidente, a primeira pergunta —
"o que mudou?" — não tem resposta.** Nenhuma quantidade de logging conserta
isso, porque o problema não é de instrumentação; é de não existir um artefato
identificável do qual os logs falem.

---

## PRONTIDÃO OPERACIONAL PARA LANÇAMENTO

# NÃO

O motivo não é a qualidade do que existe. Billing, RTDN, economia de partida,
Rules e disciplina de privacidade estão **acima da média** e foram construídos
por quem pensou em investigação futura. O motivo é que **as três perguntas
mínimas de uma operação — "quebrou?", "onde?", "o que mudou?" — não têm
resposta hoje**, e uma delas (crash do app) não tem sequer o mecanismo de
coleta.

### Bloqueadores P0

| # | Bloqueador | Seção |
|---|---|---|
| **P0-1** | **Sem crash reporting.** Nenhuma branch tem `firebase_crashlytics` nem tratador global (`FlutterError.onError`/`runZonedGuarded`) — varredura em todas as branches: zero. Um pico de travamento após o lançamento é indetectável a não ser pelo Play Vitals, sem stack de Dart. | §2 |
| **P0-2** | **O cliente publicável não conecta ao servidor implantado.** A árvore com `android/` e o workflow do AAB não manda `auth`, e o servidor exige protocolo ≥ 2. O sintoma para o jogador é reconexão infinita com "conexão instável", indistinguível de servidor fora do ar. | §6.1 |
| **P0-3** | **Nenhum `firebase.json` declara todas as codebases.** Deployar de A perde `economia`; deployar de E perde `ranking`, `social` e `conta`. Não existe deploy correto possível hoje. | §12 |
| **P0-4** | **Nenhum alerta, de nenhuma severidade.** Zero configuração de alerta, métrica ou uptime check no repositório. Todo P0 da §8 seria descoberto por reclamação de jogador. | §1.2, §8 |
| **P0-5** | **Servidor sem tratador de exceção.** Sem `uncaughtException`/`unhandledRejection`/`SIGTERM`: uma exceção derruba todas as partidas em curso e não deixa registro do motivo. | §3.2 |
| **P0-6** | **`/health` mente.** Responde `200 ok` mesmo com `FIREBASE_PROJECT_ID` ausente, situação em que nenhum jogador autentica. Um monitor ligado nele reportaria saúde durante uma indisponibilidade total. | §7.1 |

### Correções recomendadas antes do lançamento

1. **Registrar o que está em produção** — commit/`versionCode` para app,
   Functions e servidor. É a correção de maior efeito e a mais barata; sem ela,
   nenhuma das outras rende o que promete.
2. **`/readyz` e `/version` no servidor**, com a restrição da §7.2 (booleano e
   build; nada de contagem, nada de configuração, nada de parâmetro).
3. **Log de ciclo de vida no servidor** — conexão, desconexão, criação de mesa,
   início e fim de partida, erro de protocolo. Hoje são 10 linhas em 4.538.
4. **Alertas P0 da §8**, quase todos alcançáveis com *log-based metrics* sobre
   logs que já existem.
5. **Documentar o kill switch de vendas** (esvaziar `configuracao/billing.produtos`)
   como procedimento operacional. Ele já funciona; ninguém sabe que existe.
6. **Log em `functions-economia`** — é a codebase que mexe no saldo e não tem
   nenhuma chamada de log.
7. **Decidir a autoridade do saldo de fichas** antes que as duas codebases
   coexistam em produção: `economiaLedger` (absoluto, com `saldoAntes`/`saldoDepois`)
   e `fichasConcessoes` (incremental, sem before/after) escrevem o mesmo campo e
   nunca rodaram juntas. **Isto é matéria de outra OS** — a presente proíbe
   alterar o modelo econômico —, mas precisa ser resolvido antes de abrir venda VIP.
8. **Não engolir a falha de `Firebase.initializeApp` no aparelho** (`main.dart:69`);
   distinguir o caso "web de teste" do caso "aparelho do jogador".

### Melhorias que podem ficar para pós-lançamento

- Id de correlação próprio atravessando app → callable → gatilho → agendador.
- Feature flags genéricas para suspender funcionalidade (hoje só existe a do Kit Pioneiros).
- Deploy automatizado de Functions e Rules.
- Export agendado do Firestore.
- Métricas de latência e tracing distribuído.
- Enriquecer o log de `functions-ranking` (5 chamadas em 27 arquivos) e de `functions-social`.
- Autenticar `/avatar/<jogadorId>` no servidor (P2, §11).

---

## Encerramento — dados exigidos pela OS

| Item | Valor |
|---|---|
| **Branch** | `claude/observabilidade-buraco-vip-f3cd12` |
| **Base** | `fb9edb5` (`main`) — ver ressalva abaixo |
| **HEAD final** | `e6de8e8` (auditoria) seguido de um commit de registro deste próprio quadro — a ponta da branch é o segundo |
| **Hash remoto** | **nenhum** — a branch não foi publicada |
| **Arquivos alterados** | 1, criado: `docs/OS-OBSERVABILIDADE-OPERACAO-RECUPERACAO-V1.md` |
| **Testes executados** | **nenhum** — auditoria de leitura; nenhum código de produto foi tocado |
| **Árvore limpa** | sim |
| **Merge / deploy** | **nenhum**, em nenhum repositório |

**Ressalva sobre a base.** A tentativa de rebasear esta branch para uma árvore
real (`claude/account-deletion-google-play-compliance-b94769`) foi **bloqueada
pelo ambiente**. A auditoria foi então conduzida inteiramente por leitura direta
de objetos git (`git archive` / `git grep` por branch), o que **não afeta a
validade de nenhum achado** — todas as citações trazem árvore, arquivo e linha —
mas deixa este documento sobre a base placeholder. Rebasear para uma árvore real
continua recomendado antes de qualquer integração.

### Repositórios e refs auditados

- `buraco-master-vip-app` — branches A, B, C, D, E, WS (tabela §0), mais varredura
  por padrão em **todas** as branches locais e remotas para os achados negativos
  (Crashlytics, `FlutterError.onError`, cliente WS autenticado).
- `buraco-servidor` — `seguranca/ws-auth-identidade` (`71199e8`) e
  `enforcement/visao-espectador` (`3c8b07e`).
