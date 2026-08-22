# Composição Perfil/Social funcional sobre a raiz P — V1

    Branch : integracao/perfil-social-funcional-raiz-p-v1
    Base   : 5aa8263469d5abbf19f40e4fd0b35e20560c3944  (integracao/os32-fonte-unica-gates-p-v1)
    Fonte  : 365190eebffd938ca28af59171bb84e117ff8cba  (codex/amigos-funcional-seguro-v1)
    Absorvida no ponto 3d475d3ecc3e224e24f574fc49c59b723f18e87d

## 1. O que entrou, e o que ficou de fora

A família funcional é `bf5a9e7` mais **três** commits:

| commit | assunto | decisão |
|---|---|---|
| `3d475d3` | a11y — piso de 48dp nos alvos de Amigos | **absorvido** |
| `e0d9e37` | mecanismo de gate da família M | **recusado** (§7) |
| `365190e` | indicação + presença + convites de mesa | **fora de escopo** |

O tip não entrou porque §4.2 não lista nenhum dos três assuntos, §5 só autoriza
export "necessário às responsabilidades desta OS" e §9 põe Billing fora — e o
codebase `functions-indicacao` que ele traz credita fichas, por origem contábil
própria. Consequência medida: **o delta de `functions-social` é ZERO** — os
quatro `.ts` são byte a byte os da raiz P, e os 273 insertions/6 exports do tip
(presença e convites) ficaram todos do lado de fora.

## 2. Classificação dos 68 arquivos

| classe | nº | o que é |
|---|---|---|
| idênticos à raiz P | 13 | P já os tinha por cherry-pick fiel (busca por apelido, `functions-social/src`, Rules, índice, `firebase.json`) |
| absorção direta | 45 | P estava parado no merge-base |
| união semântica | 10 | os dois lados mexeram — 5 com delta zero, 5 de verdade |

Nenhum arquivo foi resolvido por `ours`/`theirs`.

## 3. As uniões que importam

**`home_de_producao.dart`** — P ligou a Loja, a fonte ligou Amigos e o avatar
público. Ficam as três; o cabeçalho passou de "cinco destinos reais" a seis.

**`perfil_page.dart`** — e aqui a primeira tentativa estava **errada**. Mandar
`NavDestino.ranking` para o host novo tirava `ranking_page.dart` do fecho, e com
ele **o Hall inteiro** (`hall_page`, `hall_screen`, `hall_service`,
`hall_contract`) mais cinco arquivos de Ranking. `perfil_page.dart:249` era o
único ponto de produção que construía `RankingPage`, e `RankingPage` é a única
porta para `HallPage`. As duas portas ficam: o cartão abre a tabela de fonte
real, a barra inferior abre a página que hospeda o Hall.

**As duas suítes de casca** — cada lado afirmava que a entrega do outro ainda
era maquete (`loja=true/amigos=false` contra `amigos=true/loja=false`). A união
é os dois verdadeiros, com Ranking e Recompensas como as duas prévias restantes.

## 4. Reancoragem das auditorias, e o controle que a justifica

Seis auditorias absorvidas descrevem a árvore da linhagem funcional, que não
tinha billing, bot, motor, chat, conta, economia, mesas, Loja nem Hall.

**Controle executado:** a raiz P **sozinha**, com zero desta composição, já
reprova as seis. Elas envelheceram; não acusam regressão desta folha.

O fecho foi reancorado **por conjunto**, não por contagem:

    fecho(composição) − fecho(raiz P) = exatamente 11 arquivos
    fecho(raiz P) − fecho(composição) = VAZIO

Foi a segunda metade que denunciou o defeito do Hall — dava dez.

## 5. Gates

As onze suítes entraram na fonte única `scripts/ci/gates_os_integracao.txt` com
contrato completo: `suite`, `executor`, `sha256`, `provas`, `casos` e `exige`.

O mecanismo M **não** veio junto: ele exige `GATES="…"` e `for k in …` dentro do
YAML, que é a lista paralela que esta raiz aboliu por ser o defeito CI-02. O
caso de `auditoria_casca_test.dart` que cobrava as duas listas foi **convertido**
para cobrar o registro e o contrato na fonte única — mais forte, porque o
mecanismo M não conferia digest nem piso.

## 6. Provas

    analyze ............ 0 erros (base P 0). 197 × 192 issues; +5 lints, todos
                         dentro de arquivos absorvidos byte a byte; nada sumiu.
    11 suítes novas .... 358 casos, todos verdes
    17 suítes da raiz P  600 casos, todos verdes
    functions-social ... 55/55
    functions-ranking .. 461/462  (a única falha é PRÉ-EXISTENTE — ver §7)
    contrato de suítes . 15 conferidos, tudo no lugar
    portão agregador ... 38/38 VERDE
    campanha negativa .. 10 mutações, 10 detectadas

## 7. Bloqueio residual — NÃO é regressão desta folha

`functions-ranking/test/passe.test.js`, caso **PF-01** ("NENHUMA Cloud Function
produtiva nova é exportada"), espera 9 exports e encontra 11.

Reproduzido no alvo de teste **da própria raiz P**, sem o `composicao.test.js`
que esta OS acrescentou, e com `functions-ranking/src` byte a byte o de P. O
gate `rankingfn` já está vermelho na raiz. Corrigir é OS própria: ou os dois
exports novos são legítimos e o piso sobe, ou não deviam ter sido exportados.

## 8. Fora de escopo, registrado

- indicação, presença e convites de mesa (o tip `365190e`);
- unificar as duas portas de Ranking e decidir onde o Hall passa a morar;
- a trava de 30 dias do apelido — **não implementada**, como §4.4 exige.
