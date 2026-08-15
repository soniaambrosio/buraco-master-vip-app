# Produtos VIP na Play Console — correspondência de identificadores e dois bloqueios

Documento exigido pela autorização de continuação: *"Não tratar `monthly_auto`,
`quarterly_auto` ou `yearly_auto` automaticamente como product ID se a
arquitetura implementada os utiliza como base plan ID ou outro identificador
interno. Conferir o contrato real e documentar a correspondência antes da criação
definitiva."*

Conferi. A correspondência está na seção 2. E ao conferir, apareceu uma segunda
coisa que precisa de decisão antes de qualquer produto existir: **o benefício de
fichas aprovado não tem produtor no backend.** Seção 3.

---

## 1. As definições recebidas

| plano | identificador | preço BR | fichas na ativação | fichas nos meses seguintes |
|---|---|---|---|---|
| Mensal | `monthly_auto` | R$ 19,90 | 1.500 | 1.000/mês |
| Trimestral | `quarterly_auto` | R$ 49,90 | 2.700 | 1.200 no 2º, 1.200 no 3º |
| Anual | `yearly_auto` | R$ 149,90 | 6.500 | 1.500/mês por 11 meses |

Brasil somente. Sem trial, sem preço introdutório, sem oferta promocional. Sem
pacotes de fichas avulsos nesta leva.

---

## 2. Correspondência: `monthly_auto` é **base plan ID**, não product ID

### O que o contrato real diz

`validarCompraPlay` (`functions-billing/index.js`, passo 3) recebe `produtoId` e
procura em `configuracao/billing`:

```js
const catalogo = await lerCatalogo();        // configuracao/billing .produtos
const definicao = catalogo[produtoId];
if (!definicao) throw new HttpsError('failed-precondition', ...);
```

O `produtoId` que chega vem do cliente, e o cliente o tira de
`PurchaseDetails.productID` — que no Android é o **ID do produto de assinatura**,
nunca o do plano-base.

O plano-base aparece em outro lugar, e só como registro histórico:

```js
concessao.planoBase = item.offerDetails.basePlanId;   // gravado em compras/{hash}
```

**Nenhuma regra econômica do servidor decide por `basePlanId` hoje.**

### O que o plugin entrega

Confirmado lendo `in_app_purchase_android` 0.5.0 e coberto por teste
(`app/test/billing/plano_vip_test.dart`): `queryProductDetails` devolve **uma
entrada por plano-base**, e todas carregam o **mesmo `ProductDetails.id`**. Quem
distingue mensal de anual é `subscriptionOfferDetails[subscriptionIndex].basePlanId`.

O sufixo `_auto` é a convenção do próprio Google para plano-base de renovação
automática. Os três nomes que você passou são, portanto, **base plan IDs**.

### A correspondência a adotar

```
produto de assinatura (product ID)   ->  master_vip          [1 produto]
   plano-base (base plan ID)         ->  monthly_auto        R$ 19,90   P1M
   plano-base (base plan ID)         ->  quarterly_auto      R$ 49,90   P3M
   plano-base (base plan ID)         ->  yearly_auto         R$ 149,90  P1Y

configuracao/billing                 ->  { produtos: { "master_vip": { assinatura: true } } }
CatalogoBilling.oficial.assinaturas  ->  { 'master_vip' }
```

Um produto, três planos-base. É a modelagem que o Google Play recomenda, é a que
seus identificadores já pressupõem, e **funciona com o backend como ele está
hoje**: os três planos concedem o mesmo direito (VIP), e o prazo de cada um vem
da resposta da Google, não do catálogo. O servidor não precisa distinguir plano
para conceder VIP corretamente.

`master_vip` é sugestão — o product ID é imutável depois de criado, então vale
confirmar o nome antes. O que **não** é sugestão é a estrutura: os três não podem
ser três produtos se os identificadores forem `*_auto`, e não podem ser
plano-base sem existir um produto acima deles.

### A consequência que precisa ficar registrada

Com um produto só, `validarCompraPlay` recebe `produtoId: "master_vip"` nas três
compras. **O servidor não consegue saber qual plano foi comprado a partir do
catálogo** — só sabe pelo `basePlanId` que a Google devolve, e que hoje ele
apenas grava.

Para VIP isso não é problema. Para fichas por plano, é — e é exatamente o
bloqueio da seção seguinte.

---

## 3. Bloqueio: o benefício de fichas não tem produtor

Procurei o crédito de fichas em `functions-billing` inteiro. Ele existe **num
lugar só**, e é o ramo de produto avulso:

```js
if (ehAssinatura) {
  concessao.vip = true;
  concessao.vipExpiraEm = item ? item.expiryTime : null;
  concessao.planoBase = ...;
} else {
  const fichas = Number(definicao.fichas || 0);      // <- só aqui
  tx.set(refJogador, { fichas: FieldValue.increment(fichas), ... }, { merge: true });
}
```

Ou seja:

1. **Assinatura não credita ficha nenhuma hoje** — nem na ativação. O ramo
   `ehAssinatura` grava `vip`, prazo e plano-base, e nada de econômico.
2. `definicao.fichas` em `configuracao/billing` **só é lido para consumível**.
   Escrever `fichas: 1500` no documento de uma assinatura seria um campo
   silenciosamente ignorado.
3. A RTDN não credita fichas. `rtdn.js` chama `aplicarProposta`, que escreve
   `playerEntitlements/{uid}` e `billingEvents` — e só.
4. A varredura `reconciliarEntitlements` também não: ela fecha direito vencido.

E há um problema estrutural além da ausência de código: **a Play não emite evento
mensal para planos trimestral e anual.** A RTDN de renovação chega a cada ciclo
de cobrança — de 3 em 3 meses, de 12 em 12. Não existe notificação para "mês 2 do
plano anual". As entregas mensais de 1.200 e 1.500 fichas exigiriam um
**concessor agendado**, com idempotência por (uid, plano, índice do mês), para
não creditar duas vezes quando o job rodar de novo.

Isso é subsistema novo, não configuração. E a OS em vigor proíbe alterar a
política econômica.

### Por que isso trava a criação dos produtos

Se os três produtos forem criados e `configuracao/billing` for preenchido agora,
o resultado observável é: o jogador paga R$ 19,90, **recebe VIP e zero fichas** —
nem as 1.500 da ativação. A Play Console, o `configuracao/billing` e o backend
estariam em desacordo, que é a condição que a OS manda parar e reportar em vez de
ajustar em silêncio.

---

## 4. Bloqueio: o AAB não é disparável de onde está

O workflow existe e está pronto (`.github/workflows/release-aab.yml`), mas:

- o GitHub só oferece `workflow_dispatch` para workflows presentes na **branch
  padrão**;
- a branch padrão deste repositório é `main`, e `main` tem apenas `build.yml`;
- esta OS proíbe merge em `main`;
- não há `gh` CLI nem credencial do GitHub nesta máquina — não consigo disparar
  nem pela API.

Então gerar o primeiro AAB depende de uma decisão sua: levar **apenas o arquivo
de workflow** para `main` (um commit de um arquivo, sem tocar em código de app),
ou disparar o build por outro caminho.

Não fiz isso por conta própria porque mexer em `main` está explicitamente
proibido — inclusive para um arquivo só.

---

## 5. O que decidir

**Decisão 1 — estrutura dos produtos.** Confirmar `master_vip` (ou outro nome)
como product ID, com `monthly_auto` / `quarterly_auto` / `yearly_auto` como
planos-base. O product ID é imutável depois de criado.

**Decisão 2 — fichas.** Três caminhos, em ordem de esforço:

- **(a) Adiar as fichas.** Criar os produtos, homologar a compra real com VIP
  apenas, e tratar o crédito de fichas como OS seguinte. É o caminho que destrava
  a homologação comercial agora, e não exige mudar a política econômica — só
  reconhecer que ela ainda não foi implementada.
- **(b) Só a ativação.** Implementar o crédito de ativação (1.500 / 2.700 /
  6.500), que é keyed por `basePlanId` e cabe dentro de `validarCompraPlay`.
  Exige mudar o backend e o formato de `configuracao/billing`.
- **(c) Completo.** (b) mais o concessor mensal agendado com idempotência por
  mês. É o maior dos três e o único que entrega o benefício como está aprovado.

**Decisão 3 — o workflow em `main`.** Autorizar (ou não) levar
`release-aab.yml` para a branch padrão, que é o que torna o AAB disparável.

Sem a 1 e a 3, nenhum produto pode ser criado. Sem a 2, os produtos podem ser
criados, mas a compra real entregará menos do que a definição comercial promete —
e isso precisa ser uma escolha registrada, não uma surpresa na homologação.
