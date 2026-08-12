# RTDN de produção — fechamento do ciclo VIP

Relatório técnico da OS **RTDN DE PRODUÇÃO / FECHAMENTO DO CICLO VIP**.

**Veredito: IMPLEMENTAÇÃO RTDN APROVADA — ATIVAÇÃO DE INFRAESTRUTURA PENDENTE.**

O caminho RTDN está implementado, ligado ao domínio econômico já homologado no P0
e provado por 24 testes automatizados que exercitam a orquestração inteira. Nada
disso remove o bloqueio de produção: o tópico Pub/Sub não existe, a Play Console
não está apontada para ele, o IAM não foi concedido e a Function não foi
implantada. Nenhum evento real da Google atravessou este sistema. Ver §13 e §15.

---

## 1. Arquitetura encontrada

O RTDN **já existia** na base aprovada (`bcb55c7`), e essa foi a primeira
descoberta relevante desta OS. `functions-billing/index.js` já trazia:

- `notificacoesPlay` — consumidor `onMessagePublished` do tópico `play-billing-rtdn`,
  com `retry: true`;
- `interpretarNotificacao`, `consolidarAssinatura`, `consolidarTerminal`,
  `decidirAtualizacao`, `documentosDeEntitlement`, `rotuloToken` — o domínio puro
  em `entitlement.js`, com 42 testes;
- `aplicarProposta` — a transação que decide e marca "já processei" no mesmo
  commit;
- `titularDoToken` — o elo `purchaseToken → uid` via `compras/{hash}`;
- `reconciliarEntitlements` (varredura por relógio) e
  `reconciliarEntitlementDoJogador` (reconsulta administrativa).

**O que faltava não era a lógica: era a prova.** Todo o corpo de `notificacoesPlay`
morava dentro do gatilho do Pub/Sub, e importar `index.js` puxa
`firebase-functions`, `firebase-admin` e `googleapis`. Este codebase roda
`node --test` **sem `node_modules`**, por decisão registrada no próprio
`package.json`. Consequência: o caminho mais delicado do Billing era o único sem
cobertura — provado apenas no nível das funções puras que ele chama, nunca na
orquestração, na transação, na falha de rede ou no vazamento de segredo.

## 2. Arquitetura final

A correção não foi "mockar o firebase-admin". Foi **parar de chamar o singleton**:
as dependências entram por parâmetro, e `index.js` vira o adaptador que as liga.

```text
Google Play
   │
   ▼  Pub/Sub, tópico play-billing-rtdn
index.js  ─ exports.notificacoesPlay ─ o ADAPTADOR (onMessagePublished, retry: true)
   │        liga as portas reais em dependencias(): getFirestore, FieldValue,
   │        consultarAssinatura (googleapis), console
   ▼
rtdn.js   ─ processarNotificacao(mensagem)          o CAMINHO
   │  1. decodifica base64 → JSON
   │  2. interpretarNotificacao(corpo, PACOTE)      ← entitlement.js (puro)
   │  3. atalho de deduplicação: billingEvents/{messageId}
   │  4. titularidade: compras/{sha256(token)} → uid
   │  5a. terminal (revogado/reembolsado) → consolidarTerminal
   │  5b. demais → reconciliacao.js
   ▼
reconciliacao.js ─ reconsultarEAplicar()            a AUTORIDADE
   │  carimba consultadoEm ANTES da rede
   │  consulta purchases.subscriptionsv2.get
   │  consolidarAssinatura(resposta, consultadoEm)  ← entitlement.js (puro)
   ▼
entitlementStore.js ─ aplicarProposta()             a TRANSAÇÃO
   │  relê playerEntitlements/{uid} + interno + billingEvents/{id}
   │  decidirAtualizacao(atual, proposta)           ← entitlement.js (puro)
   │  grava efeito e marca de "já processei" NO MESMO COMMIT
   ▼
playerEntitlements/{uid}            (o dono lê)
playerEntitlements/{uid}/interno/billing  (ninguém lê — nem admin)
billingEvents/{messageId}           (trilha; só admin lê)
```

**Nenhuma regra econômica mudou.** O corpo das funções extraídas é o mesmo que
estava em `index.js`; mudou de onde vem o `db`. Todas as decisões continuam em
`entitlement.js`, puras e inalteradas — o arquivo não foi tocado nesta OS.

O único ponto em que o comportamento de produção mudou de propósito é o log de
payload ilegível, descrito em §10.

## 3. Arquivos alterados

### Criados

| arquivo | motivo |
|---|---|
| `functions-billing/rtdn.js` | O caminho da notificação, com portas injetadas. Extraído do corpo de `notificacoesPlay` para virar testável. |
| `functions-billing/reconciliacao.js` | `reconsultarEAplicar` — consulta autoritativa + consolidação + gravação. Extraído porque **quatro** entradas o usam (validação, RTDN, reconciliação administrativa) e três cópias seriam três políticas se afastando. |
| `functions-billing/entitlementStore.js` | `aplicarProposta`, `titularDoToken`, `eventoConcluido`, `registrarEventoSemEfeito`, `chaveDaCompra`, `refsEntitlement`, com `db` e carimbo injetados. |
| `functions-billing/test/rtdn.test.js` | Os 18 cenários da OS + 6 acréscimos descobertos na implementação. 24 testes. |
| `functions-billing/test/apoio/firestore_falso.js` | Firestore em memória com **concorrência otimista real** — versão por documento, conflito, retry e um gancho de interleaving determinístico. |
| `docs/RTDN-VIP-PRODUCAO.md` | Este relatório. |

### Modificados

| arquivo | motivo |
|---|---|
| `functions-billing/index.js` | −244 linhas líquidas. As implementações saíram para os módulos acima; `notificacoesPlay` virou adaptador de 8 linhas; `dependencias()` liga as portas reais de forma preguiçosa (o mesmo motivo de `androidPublisher()`: `getFirestore()` exige `initializeApp()` antes). |
| `functions-billing/package.json` | `test` passa a incluir `test/rtdn.test.js`. Alvos explícitos, mantendo a disciplina já documentada no arquivo. |

`entitlement.js` e `idempotencia.js` **não foram tocados**.

## 4. Fluxo RTDN

Como a mensagem entra, em ordem:

1. **Entrada** — `onMessagePublished({topic: 'play-billing-rtdn', retry: true})`.
   O adaptador extrai `messageId` (com `event.id` como rede de segurança) e o
   payload base64.
2. **Decodificação** — `JSON.parse(Buffer.from(data, 'base64'))`. Falha aqui é
   terminal para a mensagem: registra e segue (§8).
3. **Interpretação** — `interpretarNotificacao(corpo, PACOTE)` confere o
   `packageName` e classifica em `ignorar` / `aplicar_terminal` / `reconciliar`.
4. **Deduplicação barata** — lê `billingEvents/{messageId}`. Não é a barreira de
   idempotência; é economia de uma chamada de rede.
5. **Titularidade** — `sha256(purchaseToken)` → `compras/{hash}` → `uid`. A Google
   não sabe o que é um UID do Firebase; o elo é o registro que `validarCompraPlay`
   gravou com identidade **autenticada**. Sem titular comprovável, o evento é
   descartado (RTDN-19).
6. **Consulta autoritativa** — `purchases.subscriptionsv2.get`, exceto nos dois
   desfechos terminais (§5).
7. **Consolidação** — `consolidarAssinatura(resposta, consultadoEm)`.
8. **Gravação** — `aplicarProposta`, dentro de transação.

## 5. Semântica de cada evento suportado

| evento | tratamento | estado resultante | teste |
|---|---|---|---|
| `PURCHASED` (4) | reconsulta | `ativo` se dentro do prazo | RTDN-01 |
| `RENEWED` (2) | reconsulta | `ativo`, **prazo estendido** | RTDN-02 |
| `CANCELED` (3) | reconsulta | `cancelado_vigente` — mantém VIP até `expiraEm` | RTDN-03 |
| `EXPIRED` (13) | reconsulta | `expirado`, sem VIP | RTDN-04 |
| `REVOKED` (12) | **terminal, do payload** | `revogado`, `expiraEm = agora` | RTDN-05 |
| `voidedPurchaseNotification` | **terminal, do payload** | `reembolsado`, `expiraEm = agora` | RTDN-06 |
| `IN_GRACE_PERIOD` (6) | reconsulta | `em_carencia` — **mantém** VIP | CV-02 |
| `ON_HOLD` (5), `PAUSED` (10) | reconsulta | `em_espera` / `pausado`, sem VIP | CV-06 |
| `RECOVERED`, `RESTARTED`, `DEFERRED`, `PRICE_CHANGE_CONFIRMED`, `PAUSE_SCHEDULE_CHANGED` | reconsulta | o que a Play responder | RTDN-18 |
| `testNotification` | ignora, registra | inalterado | RTDN-13 |
| `oneTimeProductNotification` | ignora, registra | inalterado — produto avulso não gera entitlement | RTDN-13 |
| `packageName` alheio | ignora, registra | inalterado | RTDN-13 |
| seção desconhecida | ignora, registra | inalterado | RTDN-13 |

**Por que revogação e reembolso não reconsultam:** a Google não devolve um
`subscriptionState` que diga "estornado". Esperar pela consulta deixaria uma
janela em que o reembolsado continua VIP. O fato está no payload, e só nesses
dois casos ele é aceito como fato.

**Estado novo que a plataforma inventar amanhã** cai em `desconhecido`, que **não
concede** — não há `default` permissivo (CV-07).

## 6. Idempotência

Entrega *at least once* é tratada como rotina, em duas camadas:

1. **Atalho** — `billingEvents/{messageId}` lido antes de gastar rede. Poupa a
   chamada, mas **não** é a garantia (RTDN-07).
2. **Barreira real** — dentro da transação de `aplicarProposta`, o documento de
   evento é relido e o efeito só acontece se ele ainda não estiver `concluido`.
   O efeito e a marca nascem no **mesmo commit**, ou nenhum dos dois nasce
   (RTDN-07b prova isso com o atalho neutralizado).

Terceira camada, independente do `messageId`: `decidirAtualizacao` é idempotente
por natureza — reprocessar a mesma verificação devolve `verificacao_antiga` e não
muda nada (DA-04).

**Mensagem sem `messageId`** ainda é processada, sem trilha de deduplicação: o
efeito importa mais que a trilha, e a terceira camada continua valendo (RTDN-20).

## 7. Ordem

O carimbo comparado **não é o do evento** — é o da **consulta** que produziu a
proposta (`verificadoEm`). Isso é o que faz o desenho não depender de ordem de
entrega: um evento antigo que chega depois dispara uma consulta **nova**, e
consulta nova nunca regride.

| cenário | resultado | teste |
|---|---|---|
| evento antigo chega depois de estado mais novo | `verificacao_antiga`, nada muda | RTDN-08 |
| estado terminal + renovação antiga chegando depois | `terminal_preservado` | RTDN-17 |
| evento sobre token da assinatura anterior | `token_superado` — não derruba a vigente | RTDN-17b |
| consulta à Play mais nova que o evento sugere | o estado da Play vence | RTDN-18 |

`RTDN-21` prova o detalhe que sustenta tudo isso: `consultadoEm` é capturado
**antes** da chamada de rede. Se fosse capturado na volta, uma resposta lenta
ganharia de uma consulta mais nova que respondeu rápido — e nenhum teste de
domínio perceberia, porque o domínio recebe o carimbo pronto.

## 8. Concorrência

Provada contra um Firestore falso com **concorrência otimista real** (versão por
documento, detecção de conflito, retry), não contra um mock que devolve o que o
teste pede. `test/apoio/firestore_falso.js` também recusa o que o Firestore
recusa: leitura depois de escrita na mesma transação, e retry infinito.

| cenário | resultado | teste |
|---|---|---|
| dois RTDN concorrentes sobre o mesmo token | quem consultou depois vence; o outro relê, reconhece que envelheceu e não regride | RTDN-09 |
| RTDN concorrendo com `validarCompraPlay` | convergente — um único estado, o mais recentemente verificado | RTDN-10 |

Os dois testes verificam `db.conflitos >= 1`, ou seja: a contenção **aconteceu de
verdade**, e o retry da transação foi exercitado.

## 9. Retries e falha temporária da Google Play API

Quando a Play Developer API falha, `processarNotificacao` **deixa a exceção
subir**. Isso é metade do tratamento; a outra metade é `retry: true` no gatilho.
Uma sem a outra não funciona — sem `retry`, a exceção viraria mensagem perdida;
sem a exceção, o `retry` nunca dispararia.

`RTDN-11` prova o ciclo inteiro:

- a chamada rejeita;
- o entitlement **continua o que era** — ausência de resposta não vira decisão
  econômica, e ninguém perde VIP por instabilidade de rede;
- `billingEvents/{messageId}` **não é criado** — se fosse, a reentrega seria
  descartada pelo atalho e o estado nunca mais seria conferido;
- na reentrega, com a API de volta, o efeito acontece normalmente.

Rede de segurança independente: `reconciliarEntitlements` (a cada 30 min) fecha
direitos vencidos **sem consultar a Google** — funciona mesmo com o tópico mal
configurado ou a API fora do ar.

**Dead-letter:** não há, e não foi inventado. O projeto não tem arquitetura de
DLQ em nenhum codebase. Registrado como pendência em §14.

## 10. Segurança

| garantia | como | prova |
|---|---|---|
| token bruto **não** vai para logs | todo log usa `rotuloToken` (8 caracteres do hash) | RTDN-14, nos 4 caminhos que logam |
| token bruto **não** vai para o cliente | `documentosDeEntitlement` separa público e interno; `firestore.rules` fecha `interno` para dono **e** admin | RTDN-15 + ENT-14/15/16 (emulador) |
| payload **não** é autoridade econômica | só os dois terminais vêm do payload; o resto reconsulta | RTDN-18 |
| identidade não vem do cliente | `uid` sai de `compras/{hash}`, gravado com contexto autenticado | RTDN-19 |
| origem conferida | `packageName` conferido contra `PACOTE` | RTDN-13 |
| nenhuma credencial commitada | conta de serviço em `defineSecret('PLAY_SERVICE_ACCOUNT_JSON')`, Secret Manager | — |

### Defeito encontrado e corrigido nesta OS

`RTDN-12` reprovou na primeira execução, e o achado é real:

```js
// antes
console.error('[billing] RTDN ilegivel:', e.message, { messageId });
```

O `SyntaxError` do V8 **cita um trecho da entrada** — `Unexpected token 'i',
"isto nao e..." is not valid JSON`. Um payload truncado no meio de um
`purchaseToken` imprimiria a credencial de consulta no log pela porta dos fundos.

Corrigido: o log passa a registrar `e.name` e o tamanho em bytes, nunca a
mensagem. O diagnóstico continua possível (chegou, era ilegível, tinha N bytes) e
o conteúdo não vaza. `RTDN-12b` prova exatamente o vetor: JSON cortado com o token
dentro do trecho citado.

Esta é a **única** mudança de comportamento de produção desta OS.

## 11. Observabilidade

Usa o padrão já existente (`console.*` com prefixo `[billing]` e objeto
estruturado), injetado como porta `log` — o que também torna os logs assertáveis
nos testes.

Registrado: `messageId`, tipo normalizado do evento, `uid`, estado resultante,
`vipAtivo`, decisão (`primeiro_registro`, `estado_atualizado`,
`verificacao_antiga`, `token_superado`, `terminal_preservado`,
`terminal_repetido`, `evento_repetido`, `legado_nao_sobrescreve`) e `rotuloToken`
para correlação.

Nunca registrado: `purchaseToken`, hash inteiro, credenciais, payload íntegro,
texto de exceção de parsing.

A trilha em `billingEvents/{messageId}` guarda a decisão de cada mensagem,
inclusive das que não produziram efeito — a trilha não tem buraco.

## 12. Testes

| suíte | comando | aprovados | falhos | skips |
|---|---|---|---|---|
| Billing — idempotência | `node --test test/idempotencia.test.js` | 13 | 0 | 0 |
| Billing — ciclo de vida (P0) | `node --test test/entitlement.test.js` | 42 | 0 | 0 |
| **Billing — RTDN (nova)** | `node --test test/rtdn.test.js` | **24** | **0** | **0** |
| **Billing — total** | `npm test` | **79** | **0** | **0** |
| Moderação (tsc + testes) | `npm test` em `functions-moderacao` | 13 | 0 | 0 |
| Torneios — TypeScript | `npx tsc --noEmit` em `functions` | 0 erros | 0 | — |
| Regras do Firestore (emulador) | `firebase emulators:exec --only firestore` → `npm test` em `firebase/testes` | 65 | 0 | 0 |
| App Flutter | `flutter test` em `app` | 536 | 0 | 0 |
| App Flutter — análise | `flutter analyze` | 42 issues, **0 erros** | — | — |

`flutter analyze` devolveu **42 issues, 0 erros — idêntico à baseline** da
rehomologação.

Carga do módulo implantável verificada: `require('./index.js')` com as
dependências reais registra as cinco Functions (`validarCompraPlay`,
`notificacoesPlay`, `reconciliarEntitlements`,
`reconciliarEntitlementDoJogador`, `migrarEntitlementsLegado`).

### Mapa OS → teste

| OS | teste | OS | teste |
|---|---|---|---|
| RTDN-01 | RTDN-01 | RTDN-10 | RTDN-10 |
| RTDN-02 | RTDN-02 | RTDN-11 | RTDN-11 |
| RTDN-03 | RTDN-03 | RTDN-12 | RTDN-12, RTDN-12b |
| RTDN-04 | RTDN-04 | RTDN-13 | RTDN-13 (4 variantes) |
| RTDN-05 | RTDN-05 | RTDN-14 | RTDN-14 (4 caminhos) |
| RTDN-06 | RTDN-06 | RTDN-15 | RTDN-15 |
| RTDN-07 | RTDN-07, RTDN-07b | RTDN-16 | RTDN-16 + `costura_p0_test.dart` A-01 |
| RTDN-08 | RTDN-08 | RTDN-17 | RTDN-17, RTDN-17b |
| RTDN-09 | RTDN-09 | RTDN-18 | RTDN-18, RTDN-21 |

Acrescentados durante a implementação: `RTDN-07b` (barreira transacional sem o
atalho), `RTDN-12b` (token em payload truncado), `RTDN-17b` (token superado),
`RTDN-19` (sem titular comprovável), `RTDN-20` (sem `messageId`), `RTDN-21`
(carimbo antes da rede).

### Sobre RTDN-16 — moderação

O RTDN **reconhece** o direito econômico de um jogador suspenso: a assinatura foi
paga, e fingir que não foi seria mentir sobre o dinheiro. O que ele não faz — e
não tem como fazer — é conceder **acesso**. Elegibilidade é composição, feita na
leitura por `comporPerfil` (`app/lib/elegibilidade/composicao.dart`), onde a
sanção vence qualquer critério.

A prova está dividida, de propósito, nos dois lados da fronteira:

- **backend** (RTDN-16): o Billing não escreve fora do seu domínio —
  `playerModeration/{uid}` fica intacto, e os caminhos escritos são só
  `playerEntitlements/*` e `billingEvents/*`;
- **Dart** (`app/test/elegibilidade/costura_p0_test.dart`, A-01): VIP ativo +
  suspensão vigente ⇒ inscrição recusada com `perfilSuspenso`.

## 13. Configuração externa necessária

Nada abaixo foi executado. Cada item exige console da Google, credencial ou
projeto implantado.

| # | passo | onde | estado |
|---|---|---|---|
| 1 | Criar o tópico Pub/Sub `play-billing-rtdn` no projeto Firebase | Google Cloud Console | **pendente** |
| 2 | Conceder `roles/pubsub.publisher` no tópico a `google-play-developer-notifications@system.gserviceaccount.com` | IAM do tópico | **pendente** |
| 3 | Colar o nome completo do tópico em Play Console → Monetizar → Configuração de monetização → Real-time developer notifications | Play Console | **pendente** |
| 4 | Enviar a *test notification* da Play Console e conferir que ela chega como `notificacao_de_teste` | Play Console + logs | **pendente** |
| 5 | Popular o secret `PLAY_SERVICE_ACCOUNT_JSON` no Secret Manager | GCP | **pendente** |
| 6 | Conceder à conta de serviço acesso à Google Play Developer API (permissão de visualização financeira na Play Console) | Play Console | **pendente** |
| 7 | Publicar o catálogo em `configuracao/billing` — hoje vazio, e por isso toda compra é recusada | Firestore | **pendente** |
| 8 | `firebase deploy --only functions:billing` | CI ou local | **pendente** |

O nome do tópico esperado pelo código é `play-billing-rtdn`
(`functions-billing/index.js`, constante `TOPICO_RTDN`); o `applicationId`
conferido é `io.github.soniaambrosio.buracomastervip`.

## 14. O que foi efetivamente provado

- A orquestração completa do RTDN, do payload base64 aos documentos gravados,
  contra um Firestore com contenção real.
- Os 18 cenários exigidos pela OS, mais 6 descobertos na implementação.
- Que a consulta autoritativa acontece, e que o payload não decide estado
  econômico fora dos dois terminais.
- Idempotência em três camadas, incluindo a barreira transacional isolada.
- Que falha da Play API não vira decisão econômica e volta como reentrega.
- Que o `purchaseToken` não alcança log nem documento de cliente — inclusive pelo
  caminho da exceção de parsing, que **vazava** e foi corrigido.
- Que as regras do Firestore fecham `playerEntitlements/{uid}/interno` para dono
  e para admin (emulador, 65 testes).
- Que o módulo implantável carrega e registra as cinco Functions.

## 15. O que ainda depende de ambiente

- **Que o tópico exista e entregue.** Não há tópico.
- **Que a Play Console esteja apontada para ele.** Não está.
- **Que a resposta real da Google tenha os campos que este código lê.** As
  respostas nos testes são literais no formato documentado de
  `purchases.subscriptionsv2`. Um teste de contrato exigiria credencial de conta
  de serviço e uma compra de teste.
- **Um evento real de ponta a ponta.** Nenhum ocorreu.
- **Deploy.** Nenhum.

## 16. Limitações

- O Firestore falso não é o Firestore: não tem consulta, índice, regra de
  segurança nem `FieldValue.increment`. Ele prova a lógica de transação, que é
  onde a corrida mora — nada além disso.
- `rastreabilidade.test.js` (suíte de regras) fixa a porta 8080 no código e não
  rodou: a porta estava ocupada por outra sessão e não foi tocada. As outras três
  suítes de regras rodaram em 8085 contra o **mesmo** `firestore.rules`.
- `flutter test` executa 536 testes; os demais ficam fora da descoberta padrão.
  É o P1 já formalizado, **não corrigido aqui** (§17 da OS). Não foi necessário
  tocar no CI para provar esta OS.
- Quatro suítes Flutter dependem de seeds que o CI copia para
  `test/**/data/` a partir de `app/data/`. Localmente foi preciso reproduzir essa
  cópia; os arquivos copiados foram removidos e **não** foram commitados.

## 17. Riscos residuais

1. **O tópico é o ponto único de falha operacional.** Se ele não for criado, o
   ciclo de vida continua dependendo de `reconciliarEntitlements` (que só fecha
   por vencimento) e da abertura do app. Reembolso e revogação **não** chegam.
2. **Sem dead-letter.** Uma mensagem que falhe repetidamente é reentregue até o
   Pub/Sub desistir, e então some. O `retry: true` cobre a falha transitória, não
   a permanente.
3. **`compras/{hash}` é obrigatório.** Um RTDN sobre compra que nunca passou por
   `validarCompraPlay` é descartado por falta de titular. Isso inclui as compras
   legadas — que é exatamente o que a OS de migração vai enfrentar, e o motivo
   pelo qual ela não pode ser feita por reconsulta.
4. **Catálogo vazio.** `configuracao/billing` sem produtos recusa toda compra.
   Comportamento correto, mas bloqueia a validação de ponta a ponta.

## 18. Hash final

- Base: `bcb55c7512bd64bb33aaae984f8c0c7647a5a820` (`correcao/p0-elegibilidade-vip-lifecycle`, local == remoto)
- Branch desta OS: `integracao/rtdn-vip-producao`
- Commit final: registrado no fecho da OS (ver a entrega final da sessão)

## 19. Estado de push

Ver a entrega final da sessão. A branch é exclusiva desta OS e não tem upstream
até que o push seja autorizado e executado.

## 20. Declaração de merge/deploy

- **Merge:** nenhum. Não houve merge em `main`, em `consolidacao/apk-geral-bmv`,
  em branch de homologação nem em branch de outra sessão.
- **Deploy:** nenhum. Nenhuma Function foi implantada.
- **Force push:** nenhum.
- **Tag de release:** nenhuma.
- **Play Console:** não tocada.
- **Produção:** não tocada. Nenhum registro legado foi alterado, nenhum backfill
  disparado, nenhum `vipExpiraEm` modificado. A migração do legado continua
  bloqueada, como manda a OS.
