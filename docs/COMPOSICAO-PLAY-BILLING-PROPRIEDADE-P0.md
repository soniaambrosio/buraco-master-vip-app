# Composição — Play Billing Flutter + propriedade autoritativa da compra

**Veredito: `PASS — PLAY BILLING FLUTTER COMPOSTO À PROPRIEDADE AUTORITATIVA DA COMPRA P0`**

A cadeia fecha ponta a ponta: conta autenticada → vínculo opaco do backend →
parâmetro da compra Google Play → resposta da Google → verificação no backend →
mesmo UID → entitlement e fichas. Nenhuma etapa infere propriedade pelo
`purchaseToken`.

---

## 1. Identificação

| | |
| --- | --- |
| Branch | `integracao/play-billing-propriedade-compra-p0-v1` |
| Folha A (base) | `correcao/rtdn-vip-propriedade-compra-p0` — `25b20cca96ad9ddc3784a75303074ea3ad745565` |
| Folha B | `homologacao/play-billing-comercial` — `0ea96c292f5c9f21ae0a884507c79a4bed3b3d20` |
| **merge-base real** | `a2622d59c09156e1e9fb80aa52d0a6fc51b3c9f9` |
| Método | branch a partir de A, `git merge --no-ff` de B — sem squash, rebase ou cherry-pick |

Os dois SHAs foram resolvidos remotamente em duas consultas independentes e
bateram exatamente com os da OS. O `merge-base` não foi presumido: é
`a2622d5` — a própria produção que a homologação adversarial auditou. As duas
folhas são irmãs sobre o ponto auditado, e nenhuma delas foi alterada.

**Commits exclusivos:** 10 na folha A (homologação + correção P0), 10 na folha B
(cliente Flutter, planos-base, selo VIP, ciclo de vida, fichas).

---

## 2. A auditoria do plugin, antes de escrever qualquer linha

A OS proíbe presumir o nome do parâmetro. Na versão **realmente resolvida pelo
lockfile** — `in_app_purchase 3.3.0`, `in_app_purchase_android 0.5.0` — o caminho
é este, e cada salto foi lido no código do pacote:

| Camada | Símbolo | Arquivo |
| --- | --- | --- |
| API pública | `PurchaseParam.applicationUserName` | `in_app_purchase_platform_interface` |
| Android | `GooglePlayPurchaseParam(super.applicationUserName)` | `types/google_play_purchase_param.dart:14` |
| Transformação | `accountId: purchaseParam.applicationUserName` | `in_app_purchase_android_platform.dart:184` |
| Ponte | `PlatformBillingFlowParams(accountId:)` | `billing_client_wrappers/billing_client_wrapper.dart` |
| Nativo | `paramsBuilder.setObfuscatedAccountId(params.getAccountId())` | `MethodCallHandlerImpl.java:333` |

**O nome engana e isso importa:** `applicationUserName` não é um nome de usuário.
A própria documentação de `launchBillingFlow` avisa que dado em claro nesse campo
faz a Google **bloquear a compra**, e recomenda hash ou cifra. O valor que
passamos é um identificador opaco de 48 caracteres hexadecimais concedido pelo
backend.

**Upgrade e downgrade usam o mesmo objeto.** `GooglePlayPurchaseParam` carrega
`applicationUserName` e `changeSubscriptionParam` lado a lado — não existe um
segundo caminho de compra onde a amarra pudesse ter sido esquecida. Isso foi
verificado no construtor, não suposto.

Nenhum `MethodChannel` próprio foi criado e nenhuma dependência foi atualizada.

---

## 3. Gate Zero — baselines das duas folhas

| Referência da OS | Reproduzido |
| --- | --- |
| A — Billing 161/161 | ✅ 161/161 |
| A — Rules 97/97 | ✅ 97/97 |
| A — provas negativas 22/22 | ✅ 22/22 não vácuas |
| B — Functions Billing 103/103 | ✅ 103/103 |
| B — Flutter Billing 66/66 | ✅ 66/66 |
| B — `flutter analyze` 0 erros | ✅ 0 erros (42 `info`) |
| B — Flutter total 602/602 | ⚠️ **1061/1061** |

**A única referência que não reproduz é a de 602, e ela reproduz maior e verde.**
A divergência é de *quais arquivos entram na contagem*, não de algo falhando, e
tem duas causas verificadas na árvore:

* **6 suítes usam prefixo `teste_`** e ficam fora do glob padrão de `flutter test`
  (25 arquivos de teste no total, 17 casam `*_test.dart`);
* **4 suítes dependem de seeds** que o CI copia de `app/data/` para
  `test/colecoes/data/` e `test/torneios/data/` (`ci-os-integracao.yml:82-83`) —
  sem a cópia, elas falham em `Failed to load`.

Reproduzindo o overlay do CI localmente e incluindo os `teste_*`, a folha B dá
**1061/1061, zero falhas**. É esse o baseline usado como referência.

### Conflitos previstos e o que realmente aconteceu

`git merge-tree` antes de criar a branch previu **um** conflito. Foi exatamente
um: `functions-billing/package.json` — cada lado acrescentou o próprio arquivo ao
alvo `test`. **Resolvido por união**, porque ficar com um dos lados apagaria uma
suíte inteira sem nenhum conflito aparecer depois.

Os três arquivos que auto-mesclaram eram o risco de verdade, e a auditoria achou
o que o git não acha — ver a seção 4.

---

## 4. O que o merge limpo tentou levar embora

**`index.js` voltou a ter `e.message` de terceiro em log, em dois pontos.** O
código de fichas da folha B registrava a mensagem crua da exceção; o achado M-2
da homologação tinha eliminado isso do codebase inteiro. Saiu de novo, agora com
código fechado (`propriedade.js: MOTIVO`).

**A parcela de ativação creditava ao `uid` do chamador.** Na linhagem comercial
chamador e dono eram a mesma coisa *por construção*, porque não havia autoridade
de propriedade. Aqui existe, e a parcela passou a sair de `propriedade.uid`. Os
dois valores são iguais hoje — o passo 6 recusa quando divergem —, e escrever o
certo é o que impede a igualdade implícita de virar, amanhã, uma parcela na conta
errada. **O livro-razão não é uma segunda autoridade de propriedade.**

**`X2` falhou no merge**, e falhar era o trabalho dele: a composição acrescenta
`concederFichasMensais`, e um export a mais é uma Cloud Function a mais
implantada. A lista foi decidida (5 → 7), não herdada em silêncio.

---

## 5. O caminho completo do vínculo

```
prepararCompraPlay (callable autenticada)
  │  24 bytes aleatórios → 48 caracteres hexadecimais
  │  playerBillingIdentity/{uid} + billingAccountIndex/{contaOfuscada}
  ▼
PreparadorDeCompra.preparar()                    app/lib/billing/vinculo.dart
  │  valida forma antes de devolver
  ▼
ServicoBilling.comprar()                         o PORTÃO
  │  sem sessão → não abre.  sem vínculo → não abre.  forma inválida → não abre.
  ▼
LojaPlay.comprarAssinatura(vinculoDaConta:)      app/lib/billing/loja_play.dart
  │  applicationUserName: vinculoDaConta
  ▼
BillingFlowParams.setObfuscatedAccountId         nativo
  ▼
Google Play
  │  externalAccountIdentifiers.obfuscatedExternalAccountId  (assinatura)
  │  obfuscatedExternalAccountId na raiz                     (produto avulso)
  ▼
validarCompraPlay  → decidirPropriedade({identificador, uidResolvido, uidEsperado})
  │  igualdade EXIGIDA com o uid autenticado, antes da primeira escrita
  ▼
entitlement + parcela de fichas, ambos no nome de propriedade.uid
```

**Não existe "compra primeiro, vincula depois".** Uma compra que chega à Play sem
amarra é uma compra que o backend vai recusar — a Google devolveria a resposta sem
identificador, e sem ele não há dono comprovável. O jogador teria pago para
receber `permission-denied`. Por isso as três recusas acontecem **antes** do
diálogo, e nenhuma delas cobra nada.

### Logout e troca de conta

O vínculo vive **em memória e escopado ao uid**. `encerrar()` o apaga junto com o
resto do painel. Numa troca A → B dentro do mesmo processo — sem `encerrar()`, o
caso mais hostil — o cache percebe que o uid mudou e descarta. Persistir em disco
criaria a única falha que este desenho não pode ter: o identificador de A
sobrevivendo ao logout e sendo usado numa compra de B.

### RTDN antes e depois da validação

O vínculo nasce na **preparação**, não na validação, e é exatamente por isso que a
notificação da Google pode chegar antes de o aplicativo voltar a falar com o
backend. `Y7` encena isso: preparação feita, nenhuma validação, notificação
entregue — o direito vai para a conta certa e `compras/{hash}` continua não
existindo. Se a propriedade dependesse de `validarCompraPlay` ter rodado, esse
evento não teria dono, e a versão antiga resolvia isso escolhendo o primeiro
solicitante.

### Compras antigas

Resposta sem identificador → `vinculo_ausente`: não concede, não transfere
propriedade, não cria associação, e **nada é gravado**. Restore não fabrica
vínculo — `VINC-15` prova que restaurar não chama a preparação. A sessão atual
nunca serve de prova de propriedade de uma compra antiga.

---

## 6. Resultados

| Portão | Folha A | Folha B | Composição |
| --- | ---: | ---: | ---: |
| Functions Billing | 161/161 | 103/103 | **189/189** |
| Rules (emulador) | 97/97 | — | **97/97** |
| Flutter Billing | — | 66/66 | **83/83** |
| Flutter total | — | 1061/1061 | **1078/1078** |
| `flutter analyze` | — | 0 erros | **0 erros** (42 `info`) |
| `dart analyze lib/billing test/billing` | — | — | **sem nenhuma questão** |
| Provas de não-vacuidade | 22/22 | — | **29/29** |
| Exports | 6 | 6 | **7** |
| Skips | 0 | 0 | **0** |
| Tentativas de rede nos testes | 0 | — | **0** (`X4`) |
| Segredos/tokens no diff | — | — | **nenhum**; só `token_sintetico_A/B/C` |

**17 testes Flutter novos** (`test/billing/vinculo_compra_test.dart`) e **4
backend novos** (`FI1`–`FI4`).

Os 17 não são decoração: a linhagem comercial entregou o cliente inteiro e
**nenhum teste dela chamava `comprar()`**. Os contadores `assinaturasAbertas` e
`consumiveisAbertos` existiam no dublê e nunca eram afirmados. O caminho por onde
o dinheiro entra era o único sem prova.

---

## 7. As mutações

29 provas negativas, cada uma desligando uma proteção de **produção** em cópia
temporária não commitada e exigindo vermelho. Todas **NÃO VÁCUAS**. Árvore limpa
antes, entre cada caso e depois.

As 22 da folha P0 continuam. As 7 da composição:

| | Risco reintroduzido | Onde | Morto por |
| --- | --- | --- | --- |
| C1 | a parcela segue o chamador | `index.js` + `propriedade.js` | `FI1` |
| C2 | fichas para quem apresentou o token | `propriedade.js` | `FI1`, `R6` |
| C3 | ignorar o identificador da Google | `propriedade.js` | `FI1`, `Y7` |
| C4 | associar o token antes da consulta | `index.js` | `FI1`, `R6` |
| C5 | parcela deixar de ser idempotente | `fichasStore.js` | `FI4` |
| C6 | tirar o identificador do parâmetro Flutter | `loja_play.dart` | `VINC-4c` |
| C7 | comprar mesmo com a preparação falhando | `servico_billing.dart` | `VINC-1..3` |

As duas do cliente são **executáveis**, não descritas: o runner passou a saber
mutar Dart e rodar `flutter test`.

### Três nasceram vácuas, e cada uma consertou um teste

**C1** passava com a proteção desligada, porque `uid` e `propriedade.uid` são
iguais em toda execução alcançável. Virou **mutação combinada**: desliga a
conferência de propriedade junto, que é a única janela em que a diferença
aparece. O runner ganhou `edicoes` para isso.

**C5** revelou que `FI4` não provava idempotência nenhuma. Ele reapresentava a
mesma compra e conferia o saldo — e passava com a barreira do livro-razão
desligada, porque a segunda validação volta cedo em `JA_CONCEDIDA` e nunca chega
a liquidar. **O teste media um retorno antecipado.** Reescrito para a corrida
real: a validação paga a parcela 0, o agendador varre e tenta pagar de novo. Na
primeira versão correta ele acusou 3900 em vez de 2700 — e estava certo: com
`inicioEm` de um mês atrás o agendador pagava também a parcela mensal 1, que era
devida. A asserção é que estava errada.

**C6** revelou uma lacuna de cobertura real: apagar `applicationUserName` de
`loja_play.dart` deixava os 15 testes verdes, porque todos passam pelo dublê e
`LojaPlayReal` chama `InAppPurchase.instance` direto. `VINC-4c` fecha por
estrutura, varrendo o arquivo **sem os comentários** — o cabeçalho dele cita
`applicationUserName` três vezes explicando o que faz, e um teste estrutural que
se satisfaz com a própria prosa não prova nada.

---

## 8. O gate oficial estava prestes a ficar vermelho

A inspeção do workflow que a seção 18 exige achou um problema concreto: os dois
portões de Billing rodavam a suíte **sem `npm install`**, e o comentário em
`release-aab.yml` dizia que isso era deliberado — *"o codebase nao tem dependencia
de teste, de proposito"*.

Era verdade quando foi escrito. Deixou de ser quando a matriz adversarial passou
a carregar `index.js` com `firebase-admin` e `googleapis` trocados no
`require.cache`: para trocar um pacote, o pacote real precisa existir.

**Medido, não suposto:** sem `node_modules`, **42 dos 86 casos** de
`adversarial.test.js` falham por módulo ausente.

Os dois passos ganharam `npm ci`, e `release-aab.yml` passou a usar `npm test` em
vez de `node --test` solto — os alvos são explícitos no `package.json` justamente
para que um arquivo novo não entre na suíte sem alguém decidir. Três das cinco
suítes continuam sem dependência nenhuma, e `test:baseline` segue reproduzindo os
79 históricos sem instalar nada.

**Nenhum gatilho, branch ou permissão foi tocado** — só a instalação de
dependência dentro de um passo que já existia.

Os testes novos são alcançados pelo gate: `vinculo_compra_test.dart` está em
`app/test/billing/`, que `release-aab.yml:261` copia e roda por diretório;
`adversarial.test.js` está no alvo `test` do `package.json`, que os dois gates
invocam.

---

## 9. Invariantes preservadas

**Da folha A** — nenhuma associação token → UID antes da consulta; propriedade
pelo vínculo opaco; `obfuscatedExternalAccountId` conferido; igualdade com o uid
autenticado exigida; invasor não cria compra, entitlement nem documento
envenenado; proprietário valida depois do ataque; RTDN resolve pelo vínculo e
funciona antes da validação; `packageName` obrigatório; `lineItems` malformado
falha controlado; nenhum `e.message` persistido; logs sem token bruto;
`linkedPurchaseToken` não transfere autoridade; compras antigas não vão para
"quem chegar primeiro". **`R6` continua verde e invertido.**

**Da folha B** — cliente Flutter íntegro; Play isolada atrás do serviço único;
`purchaseToken` nunca concede VIP no cliente; logout zera o painel; troca A → B
não herda VIP; produto único com três planos-base; `planoBase` preservado; entrega
econômica da assinatura; livro-razão idempotente; ativação uma única vez; parcelas
mensais posteriores; scheduler de fichas; nenhum crédito antecipado.
**`fichas.js` e `fichasStore.js` não foram recriados** — vieram da folha B
intactos, e nenhuma carteira paralela foi criada.

---

## 10. Limitações e riscos residuais

1. **`LojaPlayReal` não tem teste de comportamento.** Ela chama
   `InAppPurchase.instance` direto e exige canal de plataforma. `VINC-4c` prova
   por leitura de código, o que é mais fraco. Fechar isso exige injetar o plugin
   na classe — mudança de desenho que esta OS não autoriza.

2. **A resposta real da Google nunca foi vista.** Que ela devolva
   `externalAccountIdentifiers.obfuscatedExternalAccountId` para assinatura e
   `obfuscatedExternalAccountId` na raiz para produto avulso é leitura do
   contrato, não observação. Se a forma real divergir, nenhuma compra passa —
   falha fechada, detectável na primeira compra de teste licenciada.

3. **O baseline de 602 da OS não reproduz.** Reproduz 1061 e verde; a diferença é
   de contagem de arquivos, não de falha. Documentado na seção 3.

4. **`CatalogoBilling.oficial` continua vazio.** Sem produto na Play Console,
   nenhuma compra é possível — e a composição não muda isso.

5. **Ambiente com I/O patológico.** Durante a OS, a mesma carga de módulo variou
   entre 24 s e 3 min 8 s. Nenhum resultado deste laudo depende de tempo, mas uma
   execução falsamente vermelha por dependência ainda instalando já aconteceu
   nesta linhagem e vai reaparecer.

---

## 11. O que esta OS não fez

Nenhum PR, merge em `main`, deploy, compra real, publicação de AAB, alteração de
preço ou de benefício comercial, acesso ao Play Console, escrita em
`configuracao/billing` de produção, criação de `master_vip`, nem toque em Pub/Sub
real. As duas folhas continuam intactas nos SHAs de origem.
