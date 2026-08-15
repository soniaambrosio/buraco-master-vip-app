# Prontidão de produção VIP — legado, migração e RTDN v1

Base auditada: `homologacao/play-billing-comercial` @ `0ea96c2` (superconjunto de
`integracao/rtdn-vip-producao`, `correcao/p0-elegibilidade-vip-lifecycle` e
`integracao/play-billing-flutter`; o que existe fora dela nas outras branches é
documentação).

Esta OS **não** executou migração, deploy, publicação de infraestrutura, concessão
ou revogação de VIP real, nem tocou em usuário de produção. O que foi acrescentado
ao código é uma ferramenta **somente leitura** e cobertura de teste.

---

## Parte 1 — Legado

### 1.1 As fontes de estado VIP encontradas

| # | Fonte | Situação | Ainda tem consumidor? |
|---|---|---|---|
| 1 | `playerEntitlements/{uid}` | **Canônica.** Escrita só por `functions-billing` via Admin SDK; `allow write: if false` para cliente e admin | Sim — é a fonte |
| 2 | `playerEntitlements/{uid}/interno/billing` | Token e carimbos. Fechado para todos (`read, write: if false`) | Só o Admin SDK |
| 3 | `usuarios/{uid}` — `vip`, `vipExpiraEm`, `vipProdutoId`, `vipAtualizadoEm` | **Legado.** O Billing **parou de escrever** VIP aqui | Só `migrarEntitlementsLegado` (leitura) |
| 4 | `usuarios/{uid}` — `fichas`, `fichasAtualizadoEm` | Legado **ativo por decisão** — fichas seguem no namespace antigo | `fichasStore.js:89` (escrita) |
| 5 | `players/{uid}` | **Morta.** Removida do código; `firebase/testes/entitlement.test.js` (ENT-21) quebra se renascer | Nenhum |
| 6 | `compras/{hash}` | Titularidade do token. Guarda o **hash**, nunca o token | `titularDoToken` |
| 7 | **Cliente Flutter — `ehVip` local** | **Ativa e concedendo.** Ver 1.4 | Sim — três telas |

Confronto com a canônica: os consumidores reais (`functions/src/index.ts:106`
para elegibilidade de torneios; `app/lib/billing/entitlement_repositorio.dart`
para a UI) leem **apenas** `playerEntitlements`. Do lado do backend, não sobrou
nenhum leitor de VIP legado. `usuarios/{uid}.vip` é hoje só *entrada* de migração.

### 1.2 A população que precisa de migração

Não é conhecida, e não podia ser conhecida: não havia ferramenta que a contasse.
`migrarEntitlementsLegado` só devolve `migrados / jaTinham / semPrazo` **depois de
escrever**, e o que ela escreve passa a ser protegido por `legado_nao_sobrescreve`
— ou seja, descobrir o tamanho do problema rodando a migração é uma decisão sem
volta.

Por isso esta OS acrescentou `diagnosticarEntitlementsLegado`
([diagnosticoLegado.js](functions-billing/diagnosticoLegado.js)), callable de
admin, **somente leitura**, com cursor. Ela varre `usuarios/` **inteira** — e não
`where('vip','==',true)` como a migração, de propósito: o filtro da migração é uma
hipótese sobre como o legado marcou assinante, e um diagnóstico que herda a
hipótese do que audita não consegue desmenti-la.

A ausência de escrita é **estrutural, não uma promessa**: o módulo recebe apenas
`lerPaginaLegado` e `lerEntitlement`. Não há `db`, não há transação, não há
`aplicarProposta`. Conferir a garantia é `grep`, não leitura de fluxo (teste
`DL-13`).

Categorias projetadas, com o que a migração faria com cada uma:

| Categoria | Ação da migração | Efeito no jogador |
|---|---|---|
| `fora_da_populacao` | nada | nenhum |
| `ja_coberto_pela_play` | nada (`legado_nao_sobrescreve`) | nenhum |
| `ja_migrado` | nada | nenhum |
| `migravel_vigente` | grava `ativo` até `vipExpiraEm` | mantém VIP |
| `migravel_vencido` | grava `expirado` | **sem VIP** |
| `bloqueado_sem_prazo` | **pula** | **sem VIP e sem registro nenhum** |

### 1.3 Os três danos que a migração causa, e que agora têm nome e contagem

1. **`bloqueado_sem_prazo` — sumiço silencioso.** `vip: true` sem `vipExpiraEm`
   utilizável é pulado. Não nasce entitlement nem como expirado: o jogador
   desaparece do relatório depois do número `semPrazo` e não reaparece em lugar
   nenhum.
2. **`migravel_vencido` — possível pagante rebaixado.** Prazo vencido no legado
   pode ser um ex-assinante (correto) ou um assinante que renovou depois da última
   escrita do legado (incorreto). **Sem token, os dois casos são indistinguíveis.**
3. **Todo migrado nasce sem `purchaseTokenHash`.** Consequências, ambas reais:
   `concederFichasMensais` exige o hash para ter livro-razão idempotente e cai no
   ramo `semPlano` (`index.js:737-743`) — **o migrado mantém o VIP e não recebe a
   parcela mensal de fichas que a política promete**; e
   `reconciliarEntitlementDoJogador` não tem o que consultar.

### 1.4 Achado novo: o cliente ainda concede VIP sozinho

`6f39697` corrigiu **um** host — a Loja. Os outros três não foram tocados, e todos
são alcançáveis pela navegação do app publicado (`main.dart` é o entrypoint real:
`Firebase.initializeApp` com o projeto `buraco-master-vip` e Google Sign-In real).

| Local | O que faz | Efeito |
|---|---|---|
| [main.dart:403](app/lib/main.dart:403) | `SaguaoVM.mock(sala: …, ehVip: true)` fixo | Salão VIP, chat VIP e presentes VIP liberados para **todos** |
| [main.dart:1493](app/lib/main.dart:1493) | `ConfigMesaVM.mock(tipo:)` — o default do factory é `ehVip: true` ([configurar_mesa_screen.dart:97](app/lib/screens/configurar_mesa_screen.dart:97)) | Mesas VIP/privadas desbloqueadas ([:470](app/lib/screens/configurar_mesa_screen.dart:470) — `blocked = !vm.ehVip && …`) |
| [main.dart:601](app/lib/main.dart:601) | `onAssinar` → `copyWith(ehVip: true)` | "Assinar" liga o VIP **localmente, sem servidor nenhum** |

O selo VIP tem fonte real desde `6f39697`. Os **benefícios** não. Como o backend
de partida é Node/Railway e fora deste repositório, não há segunda barreira
servidor-side para o Salão VIP nem para a mesa privada: o gate do cliente é o
único que existe.

Menor, mas registrado: `app/lib/app/lib/` contém uma cópia órfã de
`amigos_screen.dart` e `convite_vip.dart` (aninhamento acidental de caminho). E
`ASSINATURA-VIP-INFRA.md`, citado em três comentários, não existe na árvore —
`conta.vip / ehVip()` nunca foi implementado como infra.

---

## Parte 2 — RTDN

### 2.1 O fluxo, conferido de ponta a ponta

```
Google Play
  └─ RTDN → tópico Pub/Sub `play-billing-rtdn`
       └─ notificacoesPlay (onMessagePublished, retry: true)   index.js
            └─ criarProcessadorRtdn.processarNotificacao       rtdn.js
                 ├─ interpretarNotificacao (payload → o que PERGUNTAR)  entitlement.js
                 ├─ titularDoToken (compras/{hash} → uid)      entitlementStore.js
                 ├─ terminal?  → consolidarTerminal            (sem consultar)
                 └─ senão      → reconsultarEAplicar           reconciliacao.js
                                   └─ Android Publisher: purchases.subscriptionsv2.get
                                        └─ consolidarAssinatura → decidirAtualizacao
                                             └─ aplicarProposta (TRANSAÇÃO)
                                                  ├─ playerEntitlements/{uid}
                                                  ├─ …/interno/billing
                                                  └─ billingEvents/{messageId}
```

**A autoridade é o backend**, e isso é verificável em três pontos: o app não
concede nada (`validacao.dart` — o app descobre lendo o Firestore); o payload da
notificação não decide estado econômico (só manda perguntar); e a escrita de
`playerEntitlements` é `allow write: if false` para cliente **e para admin**.

As duas exceções à reconsulta são declaradas e corretas: revogação (tipo 12) e
`voidedPurchase` são **fatos** que `subscriptionState` não expressa — esperar a
consulta deixaria uma janela em que o estornado continua VIP.

### 2.2 Cobertura por cenário da OS

Suíte `functions-billing`: **122/122 verdes** (`npm test`), sem `node_modules`.

| Cenário da OS | Provado por | Comportamento |
|---|---|---|
| compra | RTDN-01, CV-01 | consulta autoritativa → concede |
| renovação | RTDN-02, CV-10 | **estende** o prazo (era o defeito P0-3) |
| cancelamento | RTDN-03, CV-03/04 | mantém até `expiraEm`; depois expira |
| expiração | RTDN-04, CV-05 | não concede; relógio desmente o estado |
| revogação | RTDN-05, DA-09 | terminal, tirado do evento, sem consultar |
| reembolso | RTDN-06, DA-07/08 | terminal; leitura atrasada não ressuscita |
| **grace period** | **RTDN-22** (novo), CV-02 | **mantém o acesso** |
| **espera (hold)** | **RTDN-23** (novo), CV-06 | **corta o acesso, mesmo com prazo futuro** |
| **recuperação** | **RTDN-24** (novo) | volta a valer, com prazo novo |
| **pausa/retomada** | **RTDN-25** (novo) | pausado sem acesso; retomado volta |
| **ciclo completo** | **RTDN-26** (novo) | 7 estados encadeados, um token só, sem resíduo |
| evento repetido | RTDN-07, 07b | dedup no atalho **e** dentro da transação |
| evento atrasado | RTDN-08, DA-03 | não regride o estado |
| evento fora de ordem | RTDN-09, RTDN-21, DA-14 | vence quem **consultou** por último |

Os cinco novos fecham a lista da OS. Carência e espera ganharam casos separados
porque são o par que se confunde, e a diferença vale dinheiro: em carência a
Google ainda está cobrando e o acesso **continua**; em espera a cobrança falhou
de vez e o acesso **acaba**. Trocar os dois entrega VIP de graça ou tira VIP de
quem pagou.

### 2.3 Idempotência

Provada em três camadas independentes:

1. **Atalho** — `eventoConcluido(messageId)` antes de gastar rede (RTDN-07);
2. **Transação** — `billingEvents/{messageId}` é escrito **na mesma transação** do
   efeito: ou os dois acontecem, ou nenhum. RTDN-07b prova que a barreira real é
   essa, desligando o atalho;
3. **Convergência** — reprocessar a mesma consulta não muda nada
   (`verificacao_antiga`, `terminal_repetido`), então mensagem sem `messageId`
   ainda é segura (RTDN-20).

Falha da Play API **sobe** (RTDN-11), e subir é o contrato: `retry: true` a
transforma em reentrega. Como a marca de "já processei" só nasce junto com o
efeito, a reentrega encontra trabalho a fazer.

### 2.4 O que os testes NÃO provam

Declarado, não contornado: que o tópico existe e entrega; que a Play Console está
apontada para ele; que `firestore.rules` recusa o que se espera (precisa de
emulador); e que a resposta **real** da Google traz os campos que este código lê.
**Nenhum evento real da Play atravessou o sistema ainda.**

---

## Gates pendentes

### A — Implantação (nenhum é código; nada aqui está feito)

- **A1.** O tópico Pub/Sub `play-billing-rtdn` **não existe**. Sem ele, **reembolso
  e revogação não retiram VIP** — só a expiração funciona, pela varredura de
  relógio.
- **A2.** `roles/pubsub.publisher` não concedido a
  `google-play-developer-notifications@system.gserviceaccount.com`.
- **A3.** Play Console não aponta para o tópico.
- **A4.** Secret `PLAY_SERVICE_ACCOUNT_JSON` não populado. Sem ele
  `androidPublisher()` lança em **toda** consulta — nenhuma validação e nenhuma
  reconciliação funcionam.
- **A5.** `configuracao/billing` está **vazio**, e por isso `validarCompraPlay`
  recusa **toda** compra. É o comportamento correto (melhor recusar que conceder o
  indefinido), mas é bloqueio absoluto de venda.
- **A6.** `firebase deploy --only functions:billing` nunca rodou.
- **A7.** Nada disso está mesclado em `main`; as branches estão publicadas sem merge.

### B — Legado e migração

- **B1.** A migração nunca rodou, e **precisa rodar antes de qualquer torneio VIP
  abrir inscrição** — senão assinante antigo entra como "sem VIP".
- **B2.** O diagnóstico agora existe, mas **executá-lo depende de A4/A6** (é uma
  callable de admin). A população legada segue **desconhecida** até lá. Nenhum
  número desta OS afirma tamanho de base.
- **B3.** `bloqueado_sem_prazo` não tem tratamento decidido: hoje esses jogadores
  são pulados em silêncio. É decisão de produto, não de código.
- **B4.** `migravel_vencido` pode rebaixar pagante, e o sistema não tem como saber
  — não há token para perguntar à Google.
- **B5.** Todo migrado fica **sem ficha mensal** e **sem reconsulta possível**
  (1.3, item 3). Se a política de fichas vale para o legado, isso é código a
  escrever, não configuração.

### C — Cliente Flutter (bloqueia ativação comercial)

- **C1.** [main.dart:403](app/lib/main.dart:403) — Salão VIP liberado para todos.
- **C2.** [main.dart:1493](app/lib/main.dart:1493) — mesas VIP/privadas liberadas
  para todos.
- **C3.** [main.dart:601](app/lib/main.dart:601) — "Assinar" concede VIP local, sem
  servidor.

Vender assinatura cujo benefício já é gratuito no cliente é o problema comercial
mais direto desta lista, e é o único gate aqui que é **só código deste repositório**.

### D — Escala

- **D1.** `concederFichasMensais` ([index.js:709](functions-billing/index.js:709))
  usa `.limit(500)` **sem cursor**, e a consulta (`vipAtivo == true`) **não é
  auto-drenante**: quem recebeu continua no resultado. Acima de 500 VIPs ativos, os
  mesmos 500 primeiros por uid recebem para sempre e o resto **nunca** recebe.
  Invisível abaixo de 500 — e some do radar exatamente quando o negócio dá certo.
- **D2.** `reconciliarEntitlements` usa `.limit(200)` a cada 30 min, mas **é**
  auto-drenante (o documento fechado sai da consulta). Suporta ~9.600
  expirações/dia. Sem ação por ora; registrado.

### E — Cobertura

- **E1.** `migrarEntitlementsLegado` e `reconciliarEntitlements` continuam **sem
  teste automatizado** — são as duas únicas funções exportadas nessa situação.
- **E2.** `firestore.rules` não é exercitado por esta suíte (precisa de emulador).

---

## PRONTO PARA PRODUÇÃO: NÃO

Bloqueiam, em ordem de precedência:

1. **A4, A5, A6** — sem secret, sem catálogo e sem deploy, **nenhuma compra é
   sequer aceita**. Nada a jusante importa antes disso.
2. **A1, A2, A3** — sem o tópico RTDN, **reembolso e revogação não retiram VIP**.
   Vender nesse estado é vender direito que não se consegue retirar.
3. **C1, C2, C3** — o cliente entrega os benefícios VIP de graça. Vender
   assinatura cujo benefício já é gratuito não se sustenta comercialmente.
4. **B1** — migração não executada; assinante antigo entra como "sem VIP".
5. **B3, B4, B5** — decisões de produto ainda não tomadas sobre quem a migração
   deixa para trás.
6. **D1** — teto silencioso de 500 assinantes na entrega de fichas.
7. **A7, E1, E2** — merge e lacunas de cobertura.

O que **não** bloqueia, e está provado: o ciclo de vida do entitlement, a
autoridade do backend, a idempotência do RTDN e o comportamento sob evento
repetido, atrasado e fora de ordem. O motor está pronto. O que falta é console,
catálogo, uma migração informada e três linhas de cliente.
