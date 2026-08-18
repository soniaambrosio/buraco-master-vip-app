# Seam da Loja Play Real — prova comportamental do vínculo

**Veredito: `PASS — LOJA PLAY REAL COMPORTAMENTALMENTE TESTÁVEL E VÍNCULO DE COMPRA PROVADO NA FRONTEIRA DO PLUGIN`**

---

## 1. Identificação

| | |
| --- | --- |
| Repositório | `soniaambrosio/buraco-master-vip-app` |
| Base | `integracao/play-billing-propriedade-compra-p0-v1` — `5fa2d96df349b89e6b3a68479c6c6511907dc839` |
| Branch | `claude/loja-play-real-prova-comportamental-v1` |
| Arquivo de produção alterado | **um**: `app/lib/billing/loja_play.dart` |
| Arquivos de teste | `app/test/billing/loja_play_real_test.dart` (novo), `vinculo_compra_test.dart`, `functions-billing/test/apoio/nao_vacuidade.js` |

### Gate Zero

SHA resolvido remotamente por duas vias, idêntico nas duas. Árvore limpa.
`25b20cca…` e `0ea96c2…` confirmados ancestrais da composição.

**Contrato do plugin reconferido, não recordado.** Versões resolvidas no
lockfile: `in_app_purchase 3.3.0`, `in_app_purchase_android 0.5.0` — exatamente
as que a OS exige. Os dois saltos foram relidos no pacote:
`in_app_purchase_android_platform.dart:184` (`accountId: purchaseParam.applicationUserName`)
e `MethodCallHandlerImpl.java:333` (`paramsBuilder.setObfuscatedAccountId(...)`).
Sem divergência — nenhum `BLOCKED`.

Baselines reproduzidos: **189/189** backend, **97/97** Rules, **83/83** Billing
Flutter, **1078/1078** Flutter total, **0 erros** no analyzer, **29/29** mutações.

---

## 2. O problema, medido e não teorizado

A composição anterior já tinha registrado a lacuna com número: apagar
`applicationUserName` de `loja_play.dart` deixava os **quinze** testes de vínculo
**verdes**, e só `VINC-4c` — que lê o próprio código-fonte — acusava.

A causa é estrutural. `ServicoBilling` é testável porque depende da interface
`LojaPlay`. Mas `LojaPlayReal` chamava `InAppPurchase.instance` direto, e esse
getter lança quando não há plataforma registrada — que é a situação de
`flutter test`. A última seta do desenho era a única sem prova de execução.

---

## 3. O seam, e por que ele é mínimo

```dart
abstract class PluginDaPlay {          // sete operações, nada além
  Future<bool> isAvailable();
  Stream<List<PurchaseDetails>> get purchaseStream;
  Future<ProductDetailsResponse> queryProductDetails(Set<String> identifiers);
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam});
  Future<bool> buyConsumable({required PurchaseParam purchaseParam, required bool autoConsume});
  Future<void> restorePurchases();
  Future<void> completePurchase(PurchaseDetails purchase);
}

class PluginDaPlayReal implements PluginDaPlay { const PluginDaPlayReal(); … }

class LojaPlayReal implements LojaPlay {
  const LojaPlayReal({PluginDaPlay plugin = const PluginDaPlayReal()}) : _plugin = plugin;
}
```

**Os métodos têm os nomes do plugin, de propósito.** Assim a leitura de
`LojaPlayReal` mostra o mapeamento 1:1 — `comprarAssinatura → buyNonConsumable` —
e não dissimula uma segunda camada de decisão onde só há encanamento. A porta
não conhece uid, sessão, entitlement, vínculo nem propriedade da compra.

**A arquitetura pública não mudou.** Continua
`ServicoBilling → LojaPlay → LojaPlayReal → plugin`. Não há segundo
`ServicoBilling`, segundo caminho de compra, `MethodChannel` próprio, wrapper de
propriedade nem nova autoridade sobre vínculo.

### Produção continua no singleton — provado, não afirmado

O parâmetro tem valor padrão `const PluginDaPlayReal()`, e cada método daquela
classe resolve `InAppPurchase.instance` **dentro** da chamada.

* `const LojaPlayReal()` continua válido (`SEAM-14` prova que duas instâncias
  const são canonizadas — o que só vale se o construtor não faz trabalho);
* `ServicoBilling(loja: null)` continua montando a classe sem configuração nova;
* **`SEAM-15` prova o outro lado**: sem porta injetada, `real.disponivel()`
  **falha** em `flutter test`. Se passasse, o padrão teria virado um dublê.

---

## 4. Os quinze testes comportamentais

`app/test/billing/loja_play_real_test.dart` — executa `LojaPlayReal` com um dublê
injetado e inspeciona o objeto **realmente construído em runtime**.

| | O que prova |
| --- | --- |
| SEAM-1 | o parâmetro entregue é `GooglePlayPurchaseParam` |
| SEAM-2 | `productDetails` é o produto solicitado, por identidade |
| SEAM-3 | **`applicationUserName` é o vínculo, caractere a caractere** |
| SEAM-4 | `offerToken` preservado com plano; `null` sem plano — nada inventado |
| SEAM-5 | consumível: produto e vínculo corretos |
| SEAM-6 | **`autoConsume` é `false`** |
| SEAM-7 | consumível não vira `GooglePlayPurchaseParam` por engano |
| SEAM-8 | `disponivel` devolve o que a porta respondeu |
| SEAM-9 | `fluxoDeCompras` expõe o stream da porta, por identidade |
| SEAM-10 | `consultarProdutos` encaminha o conjunto de ids sem alterar |
| SEAM-11 | `restaurar` chama a porta **uma** vez |
| SEAM-12 | `finalizar` entrega exatamente o `PurchaseDetails` recebido |
| SEAM-13 | **bypass**: as sete operações numa execução, sete chamadas registradas |
| SEAM-14 | construir não toca a plataforma |
| SEAM-15 | o padrão de produção continua sendo o plugin real |

**O vínculo de teste é `a1b2c3d4…` (48 hexadecimais), e não `uid123`.** Um
defeito que trocasse o vínculo pelo uid poderia passar despercebido contra um
valor curto e parecido com identificador de usuário. A comparação é texto a
texto, e `SEAM-3` ainda verifica que o valor casa `^[0-9a-f]{48}$` e não contém
`@` nem `token_sintetico`.

**`SEAM-6` tem razão econômica, não estética.** Consumir é o que libera o token
para nova compra. Se o cliente consumisse, consumiria **antes** de o backend
creditar — e o cliente pode ser morto a qualquer instante. O jogador pagaria e
não receberia.

**`SEAM-13` é o teste de bypass.** Se algum método contornar a porta, o dublê não
registra e a lista de sete não fecha; e, em `flutter test`, o singleton ainda
lança. O seam não pode ser acrescentado e depois ignorado em silêncio.

Nenhuma asserção olha comentário: todas inspecionam o objeto entregue em runtime.

---

## 5. As dez provas negativas

Todas apontam para a bateria **comportamental** (`flutter: loja_play_real_test.dart`),
nunca para o estrutural.

| | Defeito reintroduzido | Testes mortos |
| --- | --- | ---: |
| S1 | remover `applicationUserName` da assinatura | **2** |
| S2 | substituir o vínculo por string fixa | **2** |
| S3 | alterar um único caractere do vínculo | **2** |
| S4 | remover o `offerToken` do plano-base | **1** |
| S5 | remover o vínculo do consumível | **1** |
| S6 | `autoConsume: false` → `true` | **1** |
| S7 | assinatura contornar o seam e ir ao singleton | **5** |
| S8 | consumível contornar o seam | **4** |
| S9 | `finalizar` completar compra diferente da recebida | **1** |
| S10 | `restaurar` não chamar a porta | **2** |

**S1 e S5 são a prova de que a lacuna fechou.** Antes desta OS elas só ficariam
vermelhas pelo teste estrutural. Agora morrem pela bateria comportamental — que
era exatamente o que a seção 16 exigia.

**Total: 40/40 provas não vácuas** (as 29 anteriores + as 10 do seam; o runner
conta 40 entradas porque `B` tem duas). Árvore limpa antes, entre cada caso e
depois.

---

## 6. `VINC-4c` — preservado, e repontado

Não foi apagado. Passa a ser defesa em profundidade, e agora existem duas
camadas: prova estrutural do contrato **e** prova comportamental do objeto.

Ele precisou de dois ajustes, e ambos valem registro porque a causa é a mesma:

**`VINC-4c-b` contava `InAppPurchase.instance.buy`.** O seam moveu essas chamadas
para `PluginDaPlayReal`, que não monta parâmetro nenhum — contar o singleton
passou a medir transporte em vez de regra. Agora conta `_plugin.buy`, que é onde
a decisão está.

**O helper passou a colapsar espaços.** Uma chamada quebrada em duas linhas
(`InAppPurchase.instance` numa, `.buyConsumable(` na outra) virava
`x.instance .metodo(` depois do `join(' ')` e escapava da busca. Foi exatamente
assim que este teste ficou vermelho quando o seam entrou — o teste estava certo
em falhar, mas pelo motivo errado.

---

## 7. Regressão integral

| Portão | Antes | Depois |
| --- | ---: | ---: |
| Functions Billing | 189/189 | **189/189** |
| Rules (emulador) | 97/97 | **97/97** |
| Billing Flutter | 83/83 | **98/98** |
| Flutter total | 1078/1078 | **1093/1093** |
| `flutter analyze` | 0 erros | **0 erros** (42 `info`) |
| `dart analyze lib/billing test/billing` | limpo | **sem nenhuma questão** |
| Provas não vácuas | 29/29 | **40/40** |
| Skips | 0 | **0** |

**O portão superior não foi enfraquecido.** Os casos de `vinculo_compra_test.dart`
continuam verdes: sem sessão não abre, preparação falhada não abre, vínculo
inválido não abre, troca A → B descarta o vínculo, restore não fabrica vínculo.

### Alcance pelo gate oficial

`release-aab.yml:259-261` copia `app/test/billing/.` inteiro e roda
`flutter test test/billing/` **por diretório**. O arquivo novo está versionado
nesse diretório (`git ls-files app/test/billing/` o lista), então é alcançado sem
nenhuma mudança de workflow. Nenhum gatilho, branch, permissão ou secret foi
tocado.

Excluir o arquivo do diretório removeria dele os quinze casos e, com isso, as dez
provas negativas ficariam sem alvo — o runner aborta com "o padrão não selecionou
nenhum teste" em vez de passar em silêncio.

---

## 8. O que esta OS prova, e o que **não** prova

**Prova:** que o nosso código entrega ao plugin um `PurchaseParam` cujo
`applicationUserName` é exatamente o vínculo concedido pelo backend, com o
produto certo, o `offerToken` preservado e `autoConsume: false`; e que as sete
operações atravessam a mesma fronteira.

**Não prova:** que a Play Store real recebeu esse campo, nem que a Google
devolverá `externalAccountIdentifiers.obfuscatedExternalAccountId` na forma
esperada. A fronteira provada é **Dart → plugin**. O outro lado continua
reservado a uma compra licenciada controlada, e a composição já registra que a
resposta real da Google nunca foi observada.

Isto não é teste de integração e não deve ser lido como um.

---

## 9. Riscos residuais

1. **A fronteira provada para no plugin.** O que acontece dentro de
   `in_app_purchase_android` e da Billing Library continua coberto apenas pela
   leitura do código do pacote, feita no Gate Zero.

2. **`PluginDaPlayReal` não tem teste de comportamento** — ela é o transporte, e
   testá-la exigiria a plataforma. `SEAM-15` prova indiretamente que ela é o
   padrão (a chamada falha sem plataforma), o que é o máximo alcançável offline.

3. **`CatalogoBilling.oficial` continua vazio** e `master_vip` não existe na Play
   Console. Nenhuma compra é possível, e esta OS não muda isso.

4. **Ambiente com I/O errático.** Durante a OS, o runner de provas abortou uma vez
   por árvore suja — causada por um portão de Rules que eu rodei em paralelo. Ele
   se recusou a continuar em vez de restaurar errado, que é o comportamento certo;
   fica o registro de que as duas coisas não podem correr juntas.

---

## 10. Confirmações

Zero Play Console. Zero compra real. Zero deploy. Zero PR, merge em `main` ou
publicação de AAB. Nenhuma dependência atualizada. Nenhum mocking framework
acrescentado — o dublê é Dart escrito à mão. Nenhuma mudança comercial: preços,
planos, catálogo, UI, login, sessão, backend, Rules, RTDN, fichas e entitlement
permanecem exatamente como estavam. A branch de entrada continua intocada.
