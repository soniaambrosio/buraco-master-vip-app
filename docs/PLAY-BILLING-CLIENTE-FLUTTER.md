# Cliente Google Play Billing no Flutter

Estado: **cliente implementado e testado**. O que falta não é código — é acesso à
Play Console e uma decisão comercial. As duas coisas estão nomeadas no fim deste
documento.

Base: `integracao/rtdn-vip-producao` @ `a2622d5`, que é a branch que carrega a
implementação Billing aprovada (a correção P0 do ciclo de vida em `f2b06c1` e a
RTDN em `4ef296e`). O backend **não foi reescrito**: nenhum arquivo de
`functions-billing/` foi tocado por esta OS.

---

## 1. A cadeia de autoridade

```
Flutter                        abre o fluxo, recebe o purchaseToken
   |
Google Play                    cobra e devolve a compra
   |
Firebase Auth                  identifica o jogador (request.auth.uid)
   |
validarCompraPlay              pergunta à Google Play Developer API
   |
compras/{hash}                 registro de titularidade, idempotente por token
   |
playerEntitlements/{uid}       o DIREITO — escrito só pelo backend
   |
o app lê                       e só então mostra o selo VIP
```

A regra que organiza tudo: **o cliente inicia a compra e entrega a prova; o
servidor decide.** O aplicativo nunca concede VIP, nunca concede fichas, nunca
escreve `playerEntitlements`, nunca escreve `compras/{hash}` e nunca conclui "o
jogador é VIP porque a Play respondeu `purchased`".

---

## 2. Arquivos

| arquivo | papel | depende de |
|---|---|---|
| `app/lib/billing/catalogo.dart` | os IDs que o app consulta — **vazio** | nada |
| `app/lib/billing/validacao.dart` | contrato + a decisão que custa dinheiro | `crypto` |
| `app/lib/billing/validacao_firebase.dart` | transporte: a callable | `cloud_functions` |
| `app/lib/billing/loja_play.dart` | porta para a Play Store | `in_app_purchase` |
| `app/lib/billing/sessao.dart` | porta de identidade | `firebase_auth` |
| `app/lib/billing/estado_ui.dart` | os estados que a interface distingue | nada |
| `app/lib/billing/servico_billing.dart` | o orquestrador | as portas acima |
| `app/lib/billing/entitlement_repositorio.dart` | lê `playerEntitlements/{uid}` | `cloud_firestore` |
| `app/lib/billing/plano_vip.dart` | planos-base e preços, como a Play os descreve | `in_app_purchase_android` |
| `app/lib/screens/loja_vip_adaptador.dart` | traduz os planos para a vitrine | os dois acima |

As três portas (`LojaPlay`, `ValidadorDeCompra`, `SessaoJogador`) existem para
que a parte que decide o destino de uma compra paga rode em `flutter test` sem
aparelho, sem rede e sem emulador. É a mesma disciplina de
`criarStore({db, carimbo})` no backend.

### Dependência

`in_app_purchase: ^3.3.0` → resolve `in_app_purchase_android 0.5.0`, que embute a
Google Play Billing Library e **declara `com.android.vending.BILLING` no próprio
manifesto do plugin**. É o merge desse manifesto que faz a Play Console
reconhecer o AAB como capaz de faturar.

`crypto` subiu de `dev_dependencies` para `dependencies`: passou a rodar em
produção, derivando o rótulo mascarado de token. Nenhuma outra dependência foi
alterada, e não houve upgrade global.

---

## 3. A ordem entre validar, reconhecer e finalizar

Esta é a decisão de projeto mais importante do cliente, e ela é deliberada:

1. a Play Store entrega a compra pelo `purchaseStream`;
2. o app manda o `purchaseToken` para `validarCompraPlay`;
3. **o backend credita e só então chama** `acknowledge` (assinatura) ou
   `consume` (consumível), em `fecharComAGoogle`;
4. o app chama `completePurchase`, que é local e apenas encerra a pendência no
   plugin.

O reconhecimento junto à Google é **do servidor**, porque é o servidor que sabe
se creditou. Se o cliente reconhecesse antes, uma falha entre reconhecer e
creditar deixaria a Play satisfeita e o jogador sem nada — e a Play não
reentregaria mais. Na ordem acima, qualquer morte do app antes do passo 4 termina
numa reentrega, que a idempotência de `compras/{hash}` absorve.

O prazo de 3 dias da Play (assinatura não reconhecida é estornada) é atendido no
passo 3 e **não depende de o app continuar aberto**.

Assinatura usa `buyNonConsumable`; consumível usa `buyConsumable(autoConsume:
false)`. Assinatura nunca é consumida.

---

## 4. A classificação de erro — e os dois defeitos que ela corrige

O cliente escolhe entre três destinos, e errar em qualquer direção custa dinheiro:

- **finalizar** uma compra que não foi validada faz a Play parar de reentregá-la:
  o jogador pagou e nunca recebe;
- **não finalizar** uma compra definitivamente recusada faz a Play reentregar
  para sempre.

Por isso a lista de códigos **definitivos** é fechada, curta e justificada, e
tudo que não está nela é tratado como transitório — a direção segura.

| código | destino | porquê |
|---|---|---|
| `permission-denied` | recusa | o token pertence a outra conta Firebase; repetir dá o mesmo |
| `invalid-argument` | recusa | payload malformado ou tipo divergente; reenviar o mesmo dá o mesmo |
| **`unauthenticated`** | **adia** | a sessão caiu entre a compra e a validação. A compra é boa |
| **`failed-precondition`** | **adia** | o produto não está em `configuracao/billing` — lacuna de configuração |
| `not-found`, `unimplemented` | adia | a função ainda não foi publicada |
| `unavailable`, `deadline-exceeded`, `internal`, `aborted`, `resource-exhausted` | adia | infraestrutura |

As duas linhas em negrito são correções de defeito, e não preferência de estilo.
Na versão anterior deste cliente (branch `feat/play-billing-aab-interno`) ambas
caíam em recusa definitiva, que finaliza a compra:

- **`unauthenticated`** queimaria a compra de quem pagou com a sessão expirada.
  Além da reclassificação, foi adicionado um **portão de sessão** antes da
  chamada: sem `uid`, a callable nem é gastada e a compra fica pendente para o
  próximo login (BILLING-FLUTTER-12).
- **`failed-precondition`** é o erro **esperado durante todo o bootstrap desta
  OS**, porque `configuracao/billing` está vazio de propósito. Descartar aqui
  perderia exatamente a primeira compra real de teste.

---

## 5. VIP vem do entitlement, nunca da compra

`EstadoCompra.validada` significa "o servidor aceitou esta compra". Não significa
"o jogador é VIP". As duas coisas estão em campos separados de `PainelBilling`, e
`mostrarComoVip(agora)` **não olha o estado da compra** — pergunta ao
`EntitlementVip` lido de `playerEntitlements/{uid}`, com o relógio aplicado na
leitura:

```
vigente = vipAtivo && estado concede acesso && agora < expiraEm
```

Não existe uma segunda noção de "ser VIP" neste projeto: é a mesma
`EntitlementVip.vigenteEm` que os torneios usam.

Consequências verificadas em teste: um jogador pode estar em `validada` e não ser
VIP (assinatura em `ON_HOLD`, direito expirado, documento ainda não propagado); e
pode ser VIP sem nenhuma compra nesta sessão, que é o caso normal de quem só
abriu o app. Cancelamento com período pago vigente **continua** VIP.

`playerEntitlements/{uid}` é `allow read: if ehDono(uid)` e `allow write: if
false` — o repositório só lê, e uma escrita seria recusada pelo servidor.

---

## 6. Estados de interface

`EstadoCatalogo`: `naoIniciado`, `carregando`, `indisponivel`, `semProdutos`,
`pronto`.

`EstadoCompra`: `ociosa`, `emAndamento`, `pendente`, `cancelada`, `erroDaPlay`,
`aguardandoValidacao`, `validada`, `recusada`, `aguardandoRevalidacao`.

`EstadoRestauracao`: `ociosa`, `emAndamento`, `concluida`, `nadaARestaurar`.

`aguardandoRevalidacao` é o estado que merece atenção de texto: significa
"pagamos, o servidor ainda não confirmou, **a compra não foi perdida**".

### A Loja, ligada à fonte real

`app/lib/screens/loja_screen.dart` era uma maquete: `LojaVM.mock()` com planos e
preços fixos no código, e `onAssinar` fazendo `setState(() => _ehVip = true)`
depois de 550 ms — VIP concedido por decisão local, que é o primeiro critério de
reprovação da OS.

Agora:

- **VIP** vem de `playerEntitlements/{uid}`, observado por `snapshots()`. Não
  existe caminho em `main.dart` que ligue o selo sem o servidor ter ligado antes.
- **Planos** vêm do que a Play devolveu, extraídos por
  `lib/billing/plano_vip.dart`. Enquanto o catálogo estiver vazio, a lista sai
  vazia e a grade não aparece.
- **Preço** é o `formattedPrice` da Play, já localizado. Não há preço em código.
  `porMes` e o selo de desconto são **derivados por aritmética** desses valores —
  os `-16%` e `-37%` que hoje aparecem são calculados, e casam com os preços
  aprovados por coincidência aritmética, não por estarem escritos.
- **Cosméticos, pacotes de moedas e amigos** continuam sendo `LojaVM.mock()`: não
  têm fonte real ainda, e `LojaVM.copiarCom` troca só o que tem.

O `basePlanId` é o identificador que a vitrine usa e que `onAssinar` recebe, e o
`offerToken` do plano escolhido é passado à Play — sem ele, quem escolhesse
"Anual" poderia acabar assinando o mensal.

---

## 7. Testes

Comandos e resultados, na máquina local (Flutter 3.41.4 / Dart 3.11.1):

| comando | baseline | depois |
|---|---|---|
| `flutter test` (app) | 536 | **596** |
| `flutter test test/teste_motor.dart` | 132 | 132 |
| `flutter test test/teste_motor_resiliencia.dart` | 196 | 196 |
| `flutter test test/teste_encerramento.dart` | 10 | 10 |
| `flutter analyze --no-fatal-infos --no-fatal-warnings` | 42 issues, 0 erros | 42 issues, 0 erros |
| `node --test` (functions-billing) | 80/80 | **80/80** |

Os 60 testes novos sao `app/test/billing/`. Nenhuma regressão; o analyze não
ganhou nenhum item.

`flutter test` continua **não vendo** as três suítes com prefixo `teste_` (o glob
padrão do `flutter test` só pega `*_test.dart`), por isso elas aparecem em linha
própria acima. Isso é anterior a esta OS.

Quatro suítes precisam do overlay de seeds do CI para rodar localmente:

```bash
cd app && mkdir -p test/torneios/data test/colecoes/data && cp data/torneios/*.json test/torneios/data/ && cp data/colecoes/*.json test/colecoes/data/
```

Essas cópias **não são versionadas** e foram removidas da árvore antes do commit.
Duas evidências PNG (`app/test/colecoes/evidencias/`) são regeradas pela suíte e
foram restauradas com `git checkout`.

### Os quinze casos exigidos

| caso | onde |
|---|---|
| 01 Billing indisponível | `billing_flutter_test.dart` |
| 02 Catálogo vazio | idem — e afirma que o catálogo **oficial** está vazio |
| 03 Produto carregado | idem, com catálogo injetado |
| 04 Compra cancelada | idem |
| 05 Compra pendente | idem — não valida e **não finaliza** |
| 06 Compra concluída e enviada | idem — confere o payload contra o contrato |
| 07 Backend valida com sucesso | idem — inclui reentrega já processada |
| 08 Backend rejeita produto | idem — e varre a tabela de códigos |
| 09 Erro transitório | idem — **não finaliza**, e revalida na reentrega |
| 10 Callback duplicado | idem — duas entregas em voo viram uma validação |
| 11 Restore de compra conhecida | idem — passa pela validação, não concede sozinho |
| 12 Usuário não autenticado | idem — adia, e valida quando o login chega |
| 13 Listener não duplica | idem — inclusive sob `iniciar()` concorrente |
| 14 Token nunca em log | idem — caminho feliz, adiado, recusado, e erro de fluxo |
| 15 VIP só após server-side | idem — sete asserções sobre estados de entitlement |

---

## 8. Segurança do `purchaseToken`

O token não é impresso, não é registrado, não vai para analytics e não é
persistido. Para correlacionar app e servidor existe `rotuloDoToken`, que é
**exatamente o mesmo cálculo** do backend (`rotuloToken` em `entitlement.js`): os
8 primeiros caracteres hex do SHA-256. Uma linha de log do app e uma do servidor
falam da mesma compra sem que o token exista em nenhuma das duas.

Defesas verificadas por teste:

- `CompraParaValidar.toString()` imprime o rótulo, nunca o token;
- `redigirToken` remove o token de textos escritos por terceiros (SDK, plugin),
  que podem ecoar o payload que receberam;
- o `catch` genérico do validador registra só `e.runtimeType`, nunca `$e`;
- o `onError` do `purchaseStream` registra só o tipo, porque o objeto de erro do
  plugin pode carregar os dados da compra.

Nenhum segredo entra no repositório: keystore de upload e `google-services.json`
vêm de GitHub Secrets no workflow.

---

## 9. O AAB

`.github/workflows/release-aab.yml`, `workflow_dispatch` com `version_code` e
`version_name`. Preserva o processo aprovado (portões, patch do Gradle,
`google-services`, manifesto, assinatura de upload) e moderniza a montagem:
`pubspec.yaml`/`pubspec.lock` do repositório em vez de `flutter pub add`, e o
overlay de assets por `find` em vez de lista manual.

O workflow **falha antes de construir** se: o `versionCode` não for maior que 2
(o último aceito pela Play Console), faltar qualquer secret da chave de upload,
faltar o `google-services.json`, ou **o `pubspec.yaml` não declarar
`in_app_purchase`** — este último é novo, e existe porque um AAB sem a Billing
Library compila, sobe, e não destrava nada.

Depois de construir, ele **abre o `.aab`** e confere: `applicationId`,
`versionCode`, `versionName`, a permissão `com.android.vending.BILLING` no
manifesto real, e a presença das classes `com/android/billingclient` no bundle.
Imprime o SHA-256 do artefato e as impressões digitais da chave.

**Não publica.** O artefato `bmv-aab-teste-interno` é baixado e enviado
manualmente à faixa de **Teste interno**.

---

## 10. O que esta OS NÃO entregou, e por quê

### Bloqueado por acesso — só Sonia pode executar

Estes passos exigem a Play Console e o GitHub Actions, aos quais esta sessão não
tem acesso. Nenhum deles é trabalho de código:

1. disparar `Release AAB (Teste interno)` com `version_code: 3`;
2. baixar o artefato e enviá-lo à faixa de Teste interno;
3. confirmar que a Play passou a reconhecer Billing e liberou a área de produtos.

Se a Play continuar bloqueando produtos, **registrar a mensagem literal** antes
de qualquer improviso.

> **Atualização.** Os preços e planos foram definidos, e a análise dos
> identificadores e do que ainda impede a criação dos produtos está em
> [PLAY-BILLING-PRODUTOS-E-BLOQUEIOS.md](PLAY-BILLING-PRODUTOS-E-BLOQUEIOS.md).
> Em resumo: `monthly_auto`/`quarterly_auto`/`yearly_auto` são **planos-base** de
> um produto de assinatura, o AAB não é disparável da branch atual, e o benefício
> de fichas aprovado **não tem produtor no backend**.

### Bloqueado por definição comercial

**Não existe, em lugar nenhum deste repositório, uma fonte autoritativa de preços
e planos.** Foi procurado: `docs/` não define preço, `configuracao/billing` está
vazio, e os únicos valores em código estão dentro de `LojaVM.mock()` — uma
maquete. A OS proíbe inferir preço de código de protótipo, e o critério de
reprovação nomeia "preço inventado".

Para destravar, é preciso decidir e registrar:

- quantos planos-base (mensal? trimestral? anual?);
- o preço de cada um, em BRL;
- os países;
- se há oferta introdutória ou trial — e, se houver, qual;
- os benefícios de cada plano;
- se haverá pacotes de fichas consumíveis nesta primeira leva, e quais.

Só depois disso: criar os produtos, colher os IDs reais, colá-los em
`CatalogoBilling.oficial`, popular `configuracao/billing` no formato que
`validarCompraPlay` lê (`{ produtos: { "<id>": { assinatura: bool, fichas: int } } }`),
gerar novo AAB e fazer a compra real de teste.

### Fora de escopo por decisão da própria OS

Node.js 20 e dead-letter da RTDN continuam pendentes e **não** foram tocados.
