# Composição — Avatar Público canônico + Ranking Real V2

**Veredito:** `PASS — AVATAR PÚBLICO E RANKING REAL V2 COMPOSTOS EM LINHAGEM ÚNICA`

Branch efetiva: `integracao/avatar-publico-ranking-real-v2-v1`

---

## 1. Entradas, e a divergência que elas tinham

| Papel | Ref | SHA completo |
| --- | --- | --- |
| Base (linhagem B) | `claude/contrato-estatisticas-oficiais-perfil-v1` | `fda063bf4605405ef462e129ed00fda180f06fda` |
| Folha (linhagem A) | `homologacao/avatar-publico-home-perfil-v1` | `8a66b308c4d2011a4cf972d2cdc69132b53388d1` |
| Merge-base | `integracao/perfil-publicavel-mesa-online-casca-v2-v1` | `d738f458f1f115ab8f47efea7a80bef26675e2ca` |
| Leitor de Ranking Real V2 | `correcao/leitor-ranking-real-casca-v2-v2` | `e1923f19907a72626a39b1cd5e91724747613d29` |
| Autoridade do avatar | (em A) | `92344edf7b6a512b07220f5ebcbd06f41a333faf` |
| Composição anterior contida em B | `integracao/perfil-publicavel-mesa-online-ranking-real-v2-v1` | `6e428e8575e2df4a504148a948305838cf3ff2d4` |
| Publicação original de A | `claude/avatar-publico-home-perfil-v1` | `295f5569239780e292a62249bf0d58af77bcc485` |

HEAD inicial do worktree: `fb9edb5c6963964161f1e8834b57f50fe77074a1` (`main`, placeholder).
HEAD após criar a branch a partir de B: `fda063bf...`.
HEAD final: `e52e5977e59b52c8a734d84f681c1beaf299e3a3`.

### A lacuna que esta OS fecha

Varredura sobre as 143 refs remotas:

* `92344ed` aparecia em **2** refs — as duas do avatar;
* `e1923f19` aparecia em **9** refs — todas da linhagem de Ranking;
* **interseção: vazia.**

Nenhuma ref publicada continha as duas correções ao mesmo tempo. É por isso que
nenhuma das duas suítes de origem conseguia provar a interseção: cada uma foi
homologada contra uma árvore em que a outra não existia.

---

## 2. Gate Zero

| # | Verificação | Resultado |
| --- | --- | --- |
| 1 | Refs remotas consultadas duas vezes, por meios independentes (`ls-remote` + `fetch`/`branch -r`) | OK |
| 2 | `fda063bf` descende de `6e428e8` | PASS |
| 3 | Folha A contém `92344ed` | PASS |
| 4 | Nenhuma ref publicada contém `92344ed` **e** `e1923f19` | PASS (interseção vazia) |
| 5 | Merge-base entre as linhagens é `d738f45` | PASS |
| 6 | `git merge-tree --write-tree` somente leitura | executado |
| 7 | Arquivos disputados e conflitos registrados | ver §3 |
| 8 | Worktree isolado a partir de `fda063bf` | OK |
| 9 | Árvore limpa | OK |
| 10 | Worktree original não alterado | OK |

### Duas observações que o Gate Zero levantou

**(a) A ponta de B avançou depois do SHA congelado.**
`claude/contrato-estatisticas-oficiais-perfil-v1` está hoje em `79063e07`, e não
em `fda063bf`. Os dois commits a mais são posteriores e não foram incluídos:

```
581bd91  torneio vira modalidade conhecida e explicitamente inelegivel
79063e0  docs: laudo atualizado para torneio conhecido e inelegivel
```

`fda063bf` continua existindo, é ancestral de `79063e07`, e satisfaz todas as
provas do Gate Zero. A OS manda partir do **SHA**, não da ponta da branch, e foi
o SHA que se usou. Fica registrado para decisão da Sônia se os dois commits
devem entrar depois.

**(b) Existe uma terceira linhagem irmã, e ela NÃO foi incluída.**
`claude/ranking-navegacao-perfil-publico-v1-5ffffa` (`53105ab`) sai de `6e428e8`
— irmã de `fda063bf`, não ancestral dela — e é quem traz
`app/lib/casca/navegacao_perfil_publico.dart` e
`app/test/ranking/navegacao_perfil_publico_test.dart`.

Consequência direta: **a suíte `navegacao_perfil_publico_test.dart`, listada na
§9 da OS, não existe em nenhuma das duas entradas congeladas** e portanto não
foi executada. Ela não pode ser executada nesta composição sem trazer junto uma
terceira linhagem, o que a §3 e a §5 não autorizam.

Não é linhagem *concorrente*: ela mexe na navegação do Ranking, e não na
autoridade do avatar — os conflitos desta composição não a tocam. Compor
`53105ab` é trabalho de uma OS seguinte.

---

## 3. Conflitos e resolução

Saída do `merge-tree` (somente leitura), confirmada depois pelo merge real:

```
Auto-merging  app/lib/casca/home_de_producao.dart
Auto-merging  app/lib/pages/perfil_page.dart
CONFLICT (content): Merge conflict in app/lib/pages/perfil_page.dart
Auto-merging  app/lib/screens/perfil_screen.dart
CONFLICT (content): Merge conflict in app/lib/screens/perfil_screen.dart
Auto-merging  app/lib/services/perfil_service.dart
```

Quatro arquivos disputados, **dois conflitos reais**. Os dois conflitos são o
mesmo acidente em dois lugares: as duas linhagens escreveram no mesmo ponto do
Perfil, e o Git empilhou os corpos.

### 3.1 `app/lib/screens/perfil_screen.dart` — conflito real

O Git fundiu os dois métodos num só, com o cabeçalho de um e o corpo do outro:
`comRanking(...)` abria a assinatura e `comAvatarPublico` fechava o corpo.
Aceitar o resultado, ou escolher um lado, apagaria metade de uma correção já
homologada.

**Resolvido preservando os dois métodos, escritos por extenso.** Eles não
competem: `comRanking` escreve só `ranking`, `comAvatarPublico` escreve só
`avatar`, e nenhum lê o campo do outro — encadeá-los em qualquer ordem dá o
mesmo VM.

### 3.2 `app/lib/pages/perfil_page.dart` — conflito real

Cada linhagem reescreveu a linha `final vm = ...` do `build`.

**Resolvido como encadeamento sobre um VM só**, exatamente a forma que a §6.2
exige:

```
base
  → comRanking(EscopoRanking.meuEstadoDe(context))   // só quando é o próprio
  → comAvatarPublico(avatarPublicoDaIdentidade(identidade))
```

Não há dois ViewModels paralelos nem escolha conforme a origem da navegação.

Duas assimetrias deliberadas, e o porquê de cada uma:

* `comRanking` **mantém** a guarda `ehMeuPerfil` que a linhagem B lhe deu. O
  perfil visitado conserva o ranking consultado pelo seu `publicIdVisitado`;
  sobrescrevê-lo com o estado da sessão mostraria a liga de quem está olhando no
  perfil de quem é olhado.
* `comAvatarPublico` é aplicado **sem** guarda. Não há de onde tirar avatar de
  terceiro nesta árvore: o `PerfilService` monta o VM visitado a partir da
  identidade da SESSÃO — nome inclusive —, então o campo já chegaria com este
  mesmo valor. Guardar a reaplicação daria a impressão de proteger um dado de
  terceiro que ninguém buscou, e só tiraria a reatividade do próprio perfil.
  **Limitação pré-existente às duas linhagens, registrada e fora do escopo
  desta OS.**

### 3.3 `app/lib/casca/home_de_producao.dart` — auto-merge, auditado

Resultado final do `CabecalhoJogador`, com os dois lados vivos:

```dart
avatar: avatarPublicoDaIdentidade(identidade),
...
liga: ranking.ehLigaDeVerdade ? ranking.liga : null,
```

`grep` confirma que `avatarRef ??` **não existe** no arquivo: o fallback direto
não voltou à trilha produtiva. A Home não decide mais o fallback do avatar nem o
que conta como liga.

### 3.4 `app/lib/services/perfil_service.dart` — auto-merge, auditado

`_montar` passou a receber `avatar` (de A) **e** `ranking` (de B); `carregar`
repassa os dois. O `avatar: '👑'` fixo saiu. Os `'👑'` restantes no arquivo são
`tituloEmoji` de fixture de demonstração e prosa de comentário — não é a
segunda autoridade.

---

## 4. As duas auditorias estruturais reancoradas

As **únicas** duas suítes que a composição derrubou são auditorias estruturais
da linhagem do avatar, e nenhuma reprovou por comportamento: as duas mediam a
árvore de ANTES do Ranking Real e continuaram medindo-a depois de ele entrar.

### 4.1 `o fecho cresceu só pelo componente previsto`

`hasLength(40)` → `hasLength(40 + doRankingReal.length)`, com os cinco arquivos
exigidos **nominalmente**. Medição feita antes de tocar no teste:

| Conjunto | Resultado |
| --- | --- |
| fecho(composto) − fecho(B) | `lib/sessao/avatar_publico.dart` |
| fecho(A) − fecho(base) | `lib/sessao/avatar_publico.dart` |
| fecho(B) − fecho(base) | os 5 de `lib/ranking/` |
| fecho(B) − fecho(composto) | vazio |

Ou seja: a linhagem do avatar continua acrescentando **um** arquivo — que é
exatamente o que o teste afirma — e nada se perdeu. O total virou expressão em
vez de número mágico: quem crescer o fecho de novo não escapa ajustando o
número, tem de nomear o que entrou.

### 4.2 `M20 o Perfil não abriu consulta nova a publicProfiles`

`recarregar()` estava na lista de termos proibidos como procuração para "o
Perfil foi buscar identidade de novo". Com o Ranking na tela existe um
`recarregar()` que não é isso: o botão de tentar de novo manda a autoridade de
**Ranking** refazer a consulta dela. Recusá-lo deixaria o retry pela metade — o
Perfil recarregaria e a liga continuaria falhada.

A exceção é o **texto exato da chamada**, não o termo solto, e veio acompanhada
de **duas asserções novas**: que ela ocorre uma única vez, e que os outros três
arquivos do Perfil não têm nenhum `recarregar()`. O teste terminou mais estrito
do que começou — antes, um segundo `recarregar()` em `perfil_page.dart` era
indistinguível do primeiro.

**Nenhum caso foi removido, renomeado ou enfraquecido, e nenhuma asserção de
comportamento foi tocada.**

---

## 5. Invariantes (§7)

| # | Invariante | Como se prova |
| --- | --- | --- |
| 1 | Uma autoridade de avatar | `avatar_publico.dart` é o único ponto; auditoria estrutural + caso "a autoridade do avatar continua sendo uma só" |
| 2 | Um leitor produtivo de Ranking | uma consulta serve Home e Perfil (`chamadasProprio == 1`) |
| 3 | Home e Perfil, mesma resolução de avatar | caso "Home e Perfil concordam no avatar E no estado competitivo" |
| 4 | Perfil e Ranking, mesmo estado competitivo | mesmo caso, comparando `liga` das duas telas |
| 5 | Liga fictícia não aparece | `ligaId` nulo → liga omitida na Home |
| 6 | Identidade antiga não contamina sessão nova | troca A→B na Home e no Perfil ABERTO |
| 7 | Ranking → Perfil preserva `publicId` | `idsConsultados` conferido por id |
| 8 | Home → próprio Perfil usa a identidade autenticada | `chamadasPublico == 0` |
| 9 | Nenhuma fixture na raiz produtiva | auditorias herdadas seguem verdes |
| 10 | Estatísticas oficiais não ativadas | contrato apenas definido; nenhum ponto de consumo criado |

---

## 6. Testes

### Flutter (overlay do CI, reproduzido local)

`flutter create` + `pubspec.yaml`/`pubspec.lock` do repo + `lib` + assets por
subpasta + `test` + seeds de `app/data`, com o `widget_test.dart` do scaffold
removido como o CI faz.

```
flutter analyze --no-fatal-infos --no-fatal-warnings   exit 0   101 issues (só info)
flutter test                                            exit 0   1093 passando, 0 falhas
```

As 101 informações são a linha de base conhecida do `flutter_lints` — **zero
diagnósticos novos** (medido comparando sem linha e coluna; o único info novo
que apareceu foi um `unnecessary_import` no arquivo de teste desta OS, já
removido).

Suítes exigidas pela §9, individualmente:

| Suíte | Casos |
| --- | --- |
| `avatar_publico_canonico_test.dart` | 37 |
| `homologacao_avatar_publico_test.dart` | 42 |
| `composicao_perfil_ranking_test.dart` | 19 |
| **`composicao_avatar_ranking_test.dart`** (nova) | **21** |
| `leitor_ranking_real_test.dart` | 41 |
| `regressao_leitor_ranking_test.dart` | 22 |
| `barreira_temporal_ranking_test.dart` | 23 |
| `homologacao_perfil_publicavel_test.dart` | 16 |
| `estado_canonico_ranking_test.dart` | 43 |
| `telas_consomem_identidade_test.dart` | 10 |
| `casca_producao_test.dart` | 30 |
| `homologacao_casca_v2_test.dart` | 12 |
| `mesa_online_test.dart` | 33 |
| `auditoria_casca_test.dart` | 17 |

`navegacao_perfil_publico_test.dart` — **não executada, porque não existe nesta
linhagem** (ver §2b).

### Contrato das estatísticas oficiais (Node)

```
functions-ranking: npm test    exit 0    399 passando, 0 falhas, 83 suítes
```

### A suíte nova — matriz da §9

| Caso | Resultado |
| --- | --- |
| Home com identidade válida | avatar resolvido pela autoridade canônica |
| Home com avatar ausente | fallback da autoridade (nulo, vazio e só-espaços) |
| Home com Ranking real | liga real exibível |
| Home com Ranking provisório/falso | liga omitida |
| Perfil próprio | ranking e avatar no mesmo VM |
| Perfil de terceiro | ranking do `publicId` correto, consulta conferida por id |
| Troca A → B | nada de A permanece, inclusive com o Perfil ABERTO |
| Navegação Ranking → Perfil | o id público decide a consulta |
| Árvore produtiva | sem `avatarRef ??` na Home; a página não constrói `PerfilVM` |

---

## 7. Commits produzidos

```
fb1eb35  merge: compor o avatar público canônico com o Ranking Real V2
db1b89c  test(avatar): reancorar as duas auditorias estruturais que a composição moveu
e52e597  test(composicao): provar o que só existe depois da união avatar + Ranking Real
```

`fb1eb35` é merge de verdade — dois pais: `fda063bf` e `8a66b30`.

Arquivos alterados pela composição (fora o que a folha A trouxe inteiro):

```
app/lib/casca/home_de_producao.dart          (auto-merge auditado)
app/lib/pages/perfil_page.dart               (conflito resolvido)
app/lib/screens/perfil_screen.dart           (conflito resolvido)
app/lib/services/perfil_service.dart         (auto-merge auditado)
app/test/casca/avatar_publico_canonico_test.dart   (auditorias reancoradas)
app/test/composicao/composicao_avatar_ranking_test.dart  (novo, 21 casos)
docs/COMPOSICAO-AVATAR-PUBLICO-RANKING-REAL-V2-V1.md     (este laudo)
```

---

## 8. Aceite (§12)

```
git merge-base --is-ancestor 92344ed HEAD      PASS
git merge-base --is-ancestor e1923f19 HEAD     PASS
git merge-base --is-ancestor fda063bf HEAD     PASS
git merge-base --is-ancestor 8a66b30 HEAD      PASS
```

* Home usa avatar canônico **e** Ranking real simultaneamente — sim;
* Perfil preserva `comRanking` **e** `comAvatarPublico` — sim;
* navegação de Perfil Público segue funcional (por `publicIdVisitado`) — sim;
* todas as suítes existentes verdes — sim;
* análise estática verde, sem diagnóstico novo — sim;
* árvore limpa — sim;
* branch local e remota no mesmo SHA — sim;
* nenhuma branch de entrada alterada — reconferido no remoto ao final;
* nenhum PR, merge externo ou deploy — nenhum foi executado.

---

## 9. O que esta OS deliberadamente NÃO fez

* não implementou o novo visual da Home (era o objetivo declarado: criar a base);
* não trouxe a terceira linhagem `53105ab` (navegação Ranking → Perfil);
* não incluiu os dois commits que B ganhou depois de `fda063bf`;
* não ativou as estatísticas oficiais — o contrato segue apenas definido;
* não buscou avatar de terceiro (limitação pré-existente, registrada em §3.2);
* nada de servidor, Billing, App Check ou deploy.
