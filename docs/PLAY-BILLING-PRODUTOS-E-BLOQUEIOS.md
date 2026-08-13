# Produtos VIP na Play Console — decisões tomadas e o que continua bloqueado

Este documento nasceu perguntando três coisas. As três foram respondidas, e o
que era bloqueio de CÓDIGO deixou de existir. O que sobrou é gate externo:
Play Console, e nada mais.

| decisão | resposta |
|---|---|
| 1. Estrutura dos produtos | **Um** produto de assinatura, **três** planos-base |
| 2. Fichas | **Completo** — ativação *e* entrega mensal. Implementado |
| 3. Workflow para `main` | A Sônia leva `release-aab.yml` para a branch padrão |

---

## 1. A correspondência dos identificadores

`monthly_auto` / `quarterly_auto` / `yearly_auto` são **base plan IDs**, não
product IDs. Conferido no contrato real, não presumido:

- `validarCompraPlay` recebe `produtoId` e procura em `configuracao/billing`.
  Esse `produtoId` vem de `PurchaseDetails.productID`, que no Android é o ID do
  **produto de assinatura** — nunca o do plano-base.
- O plano-base chega por outro caminho:
  `item.offerDetails.basePlanId`, na resposta da Play Developer API.
- `queryProductDetails` devolve **uma entrada por plano-base**, todas com o
  **mesmo `ProductDetails.id`**. Quem distingue mensal de anual é o `basePlanId`.
  Coberto por `app/test/billing/plano_vip_test.dart`.
- O sufixo `_auto` é a convenção do próprio Google para plano-base de renovação
  automática.

### A estrutura a criar

```
produto de assinatura (product ID)   ->  master_vip          [1 produto]
   plano-base (base plan ID)         ->  monthly_auto        R$  19,90   P1M
   plano-base (base plan ID)         ->  quarterly_auto      R$  49,90   P3M
   plano-base (base plan ID)         ->  yearly_auto         R$ 149,90   P1Y
```

Um produto, três planos-base: é o modelo canônico do Google para periodicidades
da mesma assinatura, é o que os identificadores `_auto` já pressupõem, e é o
único que suporta upgrade/downgrade limpo entre mensal e anual.

**`master_vip` ainda não existe.** Product ID do Google Play é IMUTÁVEL depois de
criado e não pode ser apagado — só desativado. Confirmar o nome antes de clicar.

---

## 2. A tabela de conferência (exigida antes de escrever `configuracao/billing`)

| plano | product ID | base plan ID | período | preço BR | tipo no backend | ativação | mensal |
|---|---|---|---|---|---|---|---|
| Mensal | `master_vip` | `monthly_auto` | P1M | R$ 19,90 | `assinatura: true` | 1.500 | 1.000 |
| Trimestral | `master_vip` | `quarterly_auto` | P3M | R$ 49,90 | `assinatura: true` | 2.700 | 1.200 |
| Anual | `master_vip` | `yearly_auto` | P1Y | R$ 149,90 | `assinatura: true` | 6.500 | 1.500 |

Brasil somente. Sem trial, sem preço introdutório, sem oferta promocional, sem
pacotes de fichas avulsos nesta leva.

### O documento a escrever, no schema que o backend realmente lê

```js
// configuracao/billing
{
  produtos: {
    master_vip: {
      assinatura: true,
      planos: {
        monthly_auto:   { mesesDoCiclo:  1, ativacao: 1500, mensal: 1000 },
        quarterly_auto: { mesesDoCiclo:  3, ativacao: 2700, mensal: 1200 },
        yearly_auto:    { mesesDoCiclo: 12, ativacao: 6500, mensal: 1500 },
      },
    },
  },
}
```

`assinatura: true` é conferido contra o campo `assinatura` da chamada e recusa
com `invalid-argument` se divergir. `planos` é lido por plano-base pela entrega
de fichas. Nenhum campo a mais — `fichas` (raiz) continua existindo, mas só para
produto avulso, e não há nenhum nesta leva.

### O único valor comercial ainda em aberto

A definição diz *"2.700 na ativação, 1.200 no 2º mês, 1.200 no 3º"* — que
descreve **um** ciclo trimestral e não diz o que acontece no **mês 4**, quando a
assinatura renova. Duas leituras cabem, e a diferença vale dinheiro.

O padrão implementado é: **o bônus de ativação acontece uma vez só.** Não é
palpite — é a única leitura coerente com o plano mensal, que na mesma definição
recebe 1.500 na ativação e 1.000 nos meses seguintes. Se renovar fosse ativar, o
mensal receberia 1.500 todo mês e a frase "1.000 nos meses seguintes" não teria a
quem se aplicar.

A outra leitura é uma linha de configuração, não um deploy:
`ativacaoPorCiclo: true` no plano. Coberto por `FICHAS-10`.

---

## 3. Fichas: era bloqueio, virou subsistema

**O defeito:** assinatura creditava ZERO fichas — nem as da ativação. O ramo
`ehAssinatura` de `validarCompraPlay` gravava `vip`, prazo e plano-base, e nada
de econômico; o único crédito de fichas que existia era o de produto avulso. Um
jogador que pagasse R$ 19,90 receberia acesso e nenhuma ficha.

**Por que não era um `increment` a mais:** a Play **não emite evento mensal** para
os planos trimestral e anual. A RTDN de renovação chega a cada ciclo de cobrança
— de 3 em 3 meses, de 12 em 12. Não existe notificação para "mês 2 do plano
anual". A entrega mensal não pode ser reativa a evento.

### O desenho

| arquivo | papel |
|---|---|
| `functions-billing/fichas.js` | calendário e valor da parcela. Puro, sem Firestore |
| `functions-billing/fichasStore.js` | a transação que paga a parcela, com o `db` injetado |
| `concederFichasMensais` (`index.js`) | agendador diário que liquida o que venceu |

**O índice do mês é a unidade de tudo.** Índice 0 é a ativação; índice N é o
N-ésimo mês decorrido desde o início da assinatura, em meses de **calendário**
(quem assinou em 31 de janeiro completa o mês 1 em 28 de fevereiro).

Com isso a ativação deixa de ser caso especial: ela é o índice 0, passa pelo
mesmo livro-razão, e o agendador vira — **sem existir código de reparo** — a rede
de segurança da ativação. A validação credita o índice 0 na hora para o jogador
não esperar; se falhar, o próximo tick paga. Nenhum dos dois credita duas vezes.

**A idempotência:** uma linha por parcela, com chave determinística
`fichasConcessoes/{purchaseTokenHash}_{indice}`. Criar a linha e creditar o saldo
são a MESMA transação — a disciplina que `idempotencia.js` já impunha à concessão
da compra. O `uid` não entra na chave de propósito: o titular de um token é único
e já conferido, e se o uid entrasse, dois usuários disputando o mesmo token
produziriam duas linhas e o crédito sairia dobrado.

**`planoBase` passou a ser público em `playerEntitlements/{uid}`.** Com um produto
só, é o único campo que diz se o jogador é mensal, trimestral ou anual — e é o
que o agendador lê para saber quanto deve. Adição compatível: `EntitlementVip
.fromMap` lê chaves nomeadas e ignora as demais, então nenhum consumidor Dart
muda.

### Portões

`functions-billing`: **103/103** (`npm test`), partindo de 79 reais.

> A baseline registrada como "80/80" vinha de `node --test` sem alvos, que
> executa `test/apoio/firestore_falso.js` como se fosse arquivo de teste e conta
> +1 fantasma. Os alvos explícitos de `package.json` são o número honesto.

22 casos novos em `test/fichas.test.js`, mais `DOC-07`/`DOC-08`. Os que carregam
o peso:

- `FICHAS-15` amarra a política comercial mês a mês — falha se alguém trocar
  1.500 por outro número sem decidir;
- `FICHAS-18` prova dois ticks **concorrentes** na mesma parcela creditando uma
  vez só, com interleaving real contra a contenção otimista do Firestore falso;
- `FICHAS-21` prova validação e agendador convergindo na parcela de ativação;
- `FICHAS-04` o mês curto (31/01 → 28/02), que sem o grude no último dia atrasaria
  a parcela em três dias;
- `DOC-07` o `planoBase` sobrevivendo à varredura por relógio — perdê-lo
  suspenderia em silêncio as parcelas de um jogador adimplente.

Nenhum arquivo Dart foi tocado: as baselines do Flutter (602/602, `analyze` com
42 issues / 0 erros) seguem válidas por construção.

---

## 4. O que continua bloqueado — e é só a Play

### 4.1 O AAB não é disparável de onde está

- `workflow_dispatch` só é oferecido para workflows presentes na **branch
  padrão**;
- a branch padrão é `main`, e `main` tem apenas `build.yml`;
- não há `gh` CLI nem credencial do GitHub nesta máquina.

**Decidido:** a Sônia leva `.github/workflows/release-aab.yml` para `main` — um
commit de um arquivo, sem tocar em código de app. Depois disso o workflow aparece
em Actions e roda com `versionCode = 3` (o último aceito pela Play foi 2).

### 4.2 Nada abaixo disto é executável por um agente

Criar produto na Play Console, instalar pela trilha interna, comprar com conta de
teste e observar a RTDN real exigem a conta Google da Sônia, um aparelho físico e
um instrumento de pagamento. Não são coisas que eu contorne — e a OS manda parar
no gate em vez de improvisar.

### A sequência, na ordem

1. `release-aab.yml` para `main`.
2. Rodar o workflow: `versionCode 3`, `versionName 1.0.1`.
3. Baixar `bmv-aab-teste-interno` → enviar em **Teste interno**. Nunca produção.
4. Processado, conferir *Monetizar → Assinaturas*: o bloqueio deve ter sumido.
5. Criar `master_vip` com os três planos-base da tabela da seção 2. Brasil.
   Sem trial, sem oferta.
6. Escrever `configuracao/billing` exatamente como a seção 2.
7. **Só então** colar `master_vip` em `CatalogoBilling.oficial.assinaturas`
   (`app/lib/billing/catalogo.dart`) e gerar o AAB seguinte, com
   `versionCode = 4`.
8. Compra real de teste — mensal, o de menor impacto.

O passo 7 é o motivo de o catálogo do cliente continuar **vazio** nesta branch:
um ID que ainda não existe na Play faria o app consultar produto inexistente, e o
vazio é comportamento testado (`configurado == false` → "nenhum produto
disponível"). O primeiro AAB precisa exibir exatamente isso.
