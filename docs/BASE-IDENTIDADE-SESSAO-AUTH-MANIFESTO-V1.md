# Base canônica de identidade, sessão e autenticação — Manifesto V1

Este documento diz **o que foi composto, a partir de quê, em que ordem**, e com
qual classificação. É o registro que permite a qualquer pessoa reconstruir esta
branch do zero e chegar exatamente na mesma árvore.

---

## 1. Por que esta base existe

A OS `CASCA REAL DE PRODUÇÃO, AUTENTICAÇÃO E ROTEAMENTO V1` parou no Gate zero
com `FAIL — BASE OU PRÉ-REQUISITO DIVERGENTE`. O diagnóstico estava certo: a
base real do aplicativo (`consolidacao/apk-geral-bmv`) é estável, mas **não
contém sessão, autenticação nem login canônicos**. As duas peças que faltavam
existiam, publicadas e protegidas, em duas branches separadas — e nenhuma delas
alcançava a outra.

Esta entrega compõe as duas numa base nova. Ela **não** implementa a Casca de
Produção; ela cria o chão em que a Casca poderá ser reiniciada.

---

## 2. Entradas congeladas

| Papel | Ref | SHA |
|---|---|---|
| **Base** | `origin/consolidacao/apk-geral-bmv` | `0cea0d6d68f2c93613b985f4aa85800d77cf42d7` |
| **Folha A** — identidade e sessão canônica | `origin/claude/identidade-sessao-canonica-flutter` | `3c6eb8da7da59fd2f6823d770b9eeb67ddf94d69` |
| **Folha B** — cliente autenticado WebSocket | `origin/claude/ws-auth-identidade-1fc213` | `13582ddfa0f9b8cccc81b20e51705bf666ca8754` |

`main @ fb9edb5c6963964161f1e8834b57f50fe77074a1` é placeholder e **base
proibida**. Não foi usado, tocado nem consultado como origem.

**Branch de saída:** `integracao/identidade-sessao-ws-auth-v1` — o nome pedido
pela OS estava livre, local e remotamente, no momento da criação. Não foi
preciso sufixo.

---

## 3. Topologia — a prova de que os dois merges eram necessários

```
git merge-base 0cea0d6d 3c6eb8da  ->  0cea0d6d      (a base É o merge-base)
git merge-base 0cea0d6d 13582ddf  ->  0cea0d6d      (a base É o merge-base)
git merge-base 3c6eb8da 13582ddf  ->  0cea0d6d      (as folhas divergem NA base)
git merge-base --all 3c6eb8da 13582ddf -> 0cea0d6d  (base única, sem criss-cross)

base ancestral de A?  SIM
base ancestral de B?  SIM
A alcança B?          NÃO
B alcança A?          NÃO
```

Topologia limpa em Y: as duas folhas nascem do **mesmo** commit e nenhuma
contém a outra.

### Classificação

| Folha | Classificação | Justificativa |
|---|---|---|
| Folha A | **MERGED** | Não alcançável pela base nem pela Folha B. Merge explícito. |
| Folha B | **MERGED** | Não alcançável pela base nem pela Folha A. Merge de três pontas real. |

**Nenhuma folha foi classificada `REACHABLE`.** A hipótese da OS §5 ("se a
topologia provar que uma folha já contém integralmente a outra") foi testada e
**refutada** pelos dois `merge-base --is-ancestor` acima.

**Nenhum cherry-pick foi usado.** Não houve impedimento técnico que justificasse
esconder ancestralidade — os dois merges casaram, e a ancestralidade está
inteira no grafo.

---

## 4. Superfície de cada folha

| Folha | Commits exclusivos | Arquivos tocados |
|---|---|---|
| Folha A | 49 | 213 |
| Folha B | 2 | 5 |

**Folha B, arquivos (os cinco):**

```
M  .github/workflows/build.yml
M  app/lib/main.dart
M  app/lib/services/online_service.dart
A  app/test/online_auth_test.dart
A  docs/WS-AUTH-IDENTIDADE-APP.md
```

**Sobreposição entre as duas folhas — exatamente dois arquivos:**

```
.github/workflows/build.yml
app/lib/main.dart
```

Identificados **antes** de qualquer mutação, como a OS §4.9 exige. Nenhum
arquivo de bootstrap, sessão, autenticação ou dependência ficou fora dessa
conta: a Folha B não toca `lib/sessao/` (que não existia no SHA dela) e a Folha
A não toca `lib/services/online_service.dart`.

---

## 5. Ordem de composição executada

```
1.  branch criada em 0cea0d6d                       HEAD inicial
2.  merge --no-ff Folha A (3c6eb8da)             ->  d6cd313
3.  testes focados de sessão                         51 verdes
4.  merge --no-ff Folha B (13582ddf)             ->  9d6d7af
5.  reconciliação dos contratos conjuntos        ->  72c8a9b
6.  suíte da união (§8.1..§8.13)                 ->  81b48d6
7.  documentação                                 ->  (este commit)
```

O passo 2 usou `--no-ff` de propósito. Como a base é ancestral exata da Folha A,
um merge normal teria feito fast-forward e a branch ficaria indistinguível da
folha; o merge explícito registra na topologia que **esta branch é a composição
de duas folhas**, e não uma delas com um remendo.

Prova de que o passo 2 não perdeu nada: `tree(d6cd313) == tree(3c6eb8da)`.

---

## 6. O que esta base entrega

* **Uma** `SessaoDoJogador`, criada na raiz do app e pendurada acima do
  `MaterialApp` por `EscopoSessao`. Identidade pública, `publicId`,
  elegibilidade e agora **credencial** saem todos dela.
* Transporte WebSocket em **protocolo 2**: o app apresenta credencial e o
  servidor deriva a identidade. Nenhum `jogadorId` sai do cliente.
* Um **seam explícito** (`PonteSessaoOnline`) entre sessão e transporte, que é
  por onde a Casca de Produção vai consumir os dois.

O que esta base **não** entrega, e de propósito: tela de login, Home, menu,
tabela de rotas, ou qualquer decisão de produto sobre quando conectar. Isso é a
Casca, e a Casca é outra OS.

---

## 7. Recibo para a OS da Casca

A OS `CASCA REAL DE PRODUÇÃO, AUTENTICAÇÃO E ROTEAMENTO V1` deve ser
**reiniciada em branch nova** a partir do HEAD final desta branch. A branch
bloqueada da Casca não deve ser continuada como se o pré-requisito já
existisse — ela nasceu de uma base que não tinha sessão.

O SHA exato está em
[`BASE-IDENTIDADE-SESSAO-AUTH-EVIDENCIA-V1.md`](BASE-IDENTIDADE-SESSAO-AUTH-EVIDENCIA-V1.md),
seção "Recibo final", junto da prova `local == remoto`.
