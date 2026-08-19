# Composição — Perfil Publicável + Mesa Online/Casca V2 + Leitor Real de Ranking V2

## 1. Entradas

| Papel | Branch | SHA |
|---|---|---|
| Primeiro pai | `integracao/perfil-publicavel-mesa-online-casca-v2-v1` | `d738f458f1f115ab8f47efea7a80bef26675e2ca` |
| Segundo pai | `correcao/leitor-ranking-real-casca-v2-v2` | `e1923f19907a72626a39b1cd5e91724747613d29` |

Cada SHA foi conferido por duas consultas remotas independentes (`ls-remote` via `origin` e via URL completa).

## 2. Merge-base

`bc74e30a148a56b00ca7db691a378584efaa5207`, e **único** — `git merge-base --all` devolve exatamente uma linha. As duas entradas descendem dele.

A Entrada A contém **um** merge interno (`5b979c0`, "compor Perfil Publicavel Canonico V1 sobre a Mesa Online/Casca V2"), porque ela própria é uma composição. A Entrada B é **linear**, sem merge nenhum — que era o exigido.

## 3. Pais do merge

```
bcdee18  merge: compor o Leitor Real de Ranking V2 sobre Perfil Publicavel + Mesa Online
  1º pai: d738f458f1f115ab8f47efea7a80bef26675e2ca
  2º pai: e1923f19907a72626a39b1cd5e91724747613d29
```

Merge explícito. Sem rebase, sem cherry-pick.

## 4. Previsão do `merge-tree`, e conflitos

Antes de tocar a árvore, `git merge-tree --write-tree --messages` previu:

```
tree e3584eab35b926ecab07a8a7793cf7cc0fe12623
Auto-merging app/lib/pages/perfil_page.dart
Auto-merging app/lib/screens/perfil_screen.dart
Auto-merging app/lib/services/perfil_service.dart
```

**Zero conflitos previstos, zero conflitos reais.**

E isso não vale como prova de nada. Nesta linhagem um merge sem conflito já reintroduziu um segundo dono de autenticação por um hunk que o git juntou sozinho. Os três arquivos foram lidos linha a linha contra **os dois** pais antes do commit, e a suíte da seção 8 existe para que a união passe a ser afirmada por teste.

## 5. Inventário

Contra `bc74e30`:

| | arquivos |
|---|---|
| Entrada A | **24** |
| Entrada B | **16** |
| Interseção | **3** |

A interseção é exatamente a declarada:

```
app/lib/pages/perfil_page.dart
app/lib/screens/perfil_screen.dart
app/lib/services/perfil_service.dart
```

Nenhuma das duas entradas toca backend, Functions, Rules, índices ou servidor — as duas ficam inteiramente em `app/` e `docs/`.

`app/lib/main.dart` tem o **mesmo blob** (`57d8ab1e`) no merge-base e nas duas entradas, e continua intocado na composição.

## 6. Resolução dos três arquivos

Nenhum foi resolvido por `ours` nem por `theirs`. O que a união carrega de cada lado:

### `perfil_service.dart`

| De A | De B |
|---|---|
| `nivel`, `xpAtual`, `xpProximo`, `titulo`, `tituloEmoji`, `stats`, `presentesCount` e `conquistas` **nulos** fora da demonstração | o parâmetro `EstadoRanking? ranking`, recebido pronto |
| o catálogo "tudo travado" continua removido | o repasse do ranking ao `PerfilVM` |
| identidade só de `IdentidadePublica`; sem Firebase Auth para obter nome | — |

O serviço **não consulta ranking** — a consulta é do leitor, a montagem é do serviço.

### `perfil_page.dart`

| De A | De B |
|---|---|
| identidade exclusivamente de `EscopoSessao` | `publicIdVisitado` no construtor |
| recarga em `didChangeDependencies`, nunca no `build` | perfil próprio lendo `EscopoRanking.meuEstadoDe` no `build`, via `comRanking` |
| convite sem `Nível null`, sem liga e sem colocação inventadas | perfil visitado por `rankingPublico`, com alvo decidido **só** por `publicIdVisitado` |
| convite fechando no nome quando não há trecho competitivo | descarte temporal (`null`) virando "não sei" |
| — | retry ligado ao leitor |

O construtor final admite `ehMeuPerfil` e `publicIdVisitado`.

### `perfil_screen.dart`

| De A | De B |
|---|---|
| campos anuláveis do `PerfilVM` | `PerfilVM.comRanking` |
| desenho que omite o que não tem fonte — nada de nível 1, zero ou 'Novato(a)' | `_linhaCompetitiva` e o anúncio acessível cobrindo as **seis** fases de `EstadoRanking`, incluindo `acessoRecusado` |
| cadeia visual do Perfil intacta | prefixo "Liga" só diante de uma Liga de verdade |

Não há segundo `EstadoRanking` nem modelo duplicado: o arquivo do estado vem inteiro da Entrada B (não pertence à interseção).

## 7. Fecho de imports — recalculado do zero

A partir de `lib/main.dart`, ignorando comentários:

| Árvore | alcançáveis |
|---|---|
| Entrada A | **39** |
| Entrada B | **40** |
| **Composição** | **44** |

Diferença contra A (+5, todos de ranking):

```
lib/ranking/escopo_ranking.dart
lib/ranking/leitor_ranking.dart
lib/ranking/ranking_da_sessao.dart
lib/ranking/ranking_transporte.dart
lib/ranking/ranking_transporte_firebase.dart
```

Diferença contra B (+4, todos de Mesa Online):

```
lib/casca/mesa_online/arte_das_cartas.dart
lib/casca/mesa_online/estado_mesa_online.dart
lib/casca/mesa_online/mesa_online_screen.dart
lib/casca/mesa_online/porta_de_comandos_online.dart
```

**Nada se perdeu de nenhum dos dois lados.** A contagem histórica de 39 era a da Entrada A e não vale mais para esta árvore.

## 8. Autoridades — provadas sobre o fecho alcançável

| Autoridade | Quem é | Prova |
|---|---|---|
| Firebase Auth | só a cadeia `lib/sessao/` | C11c + `auditoria_casca_test` |
| Identidade pública | `EscopoSessao`; o Perfil não cria outra fonte | C11 |
| `cloud_functions` | só os adaptadores `*_firebase.dart` | C11b |
| Estado do próprio jogador | `RankingDaSessao` | C1, C2 |
| Leitura remota de ranking | `LeitorDeRanking`, instanciado **só** por `raiz_do_aplicativo.dart` | C17 |
| Montagem do Perfil | `PerfilService`, que não consulta ranking | C11 |
| Apresentação | `PerfilScreen`, construída **só** por `perfil_page.dart` | C15 |
| Comandos da mesa online | `PortaDeComandosOnline` | C14 + `auditoria_mesa_online_test` |
| Interpretação da visão | `AdaptadorVisaoOnline` | `adaptador_visao_online_test` |
| Raiz | `main.dart`, byte a byte o das entradas | C16 (SHA-256 fixado no teste) |

O caminho online não constrói o motor da partida local; o botão Treino continua alcançando `lib/mesa.dart` sem socket.

## 9. Contagens

| Árvore | glob padrão | fora do glob | total |
|---|---|---|---|
| merge-base `bc74e30` | 749 | 549 | 1298 |
| Entrada A `d738f45` | 888 | 549 | 1437 |
| Entrada B `e1923f1` | 835 | 549 | 1384 |
| **Composição, antes dos testes novos** | **974** | **549** | **1523** |
| **Composição, com os 19 testes novos** | **993** | **549** | **1542** |

O piso de 1523 foi atingido exatamente. Nenhum teste removido, pulado, comentado ou neutralizado.

Suítes conferidas separadamente, todas verdes: Perfil publicável (16), Mesa Online (33), Porta de comandos (24), Adaptador de visão (35), Auditoria da Mesa Online (8), Casca V2 (30), Auditoria da casca (17), Leitor real (41), Regressão de acesso (22), Barreira temporal (23), Estado canônico (43), e as sete suítes `teste_*.dart` (549).

## 10. Analyzer

**Flutter 3.41.4 · Dart 3.11.1** (o CI pina 3.44.8; o valor absoluto não é reproduzível entre os dois, então as três árvores foram medidas no mesmo binário e no mesmo overlay).

| Árvore | issues | erros |
|---|---|---|
| Entrada A | **101** | 0 |
| Entrada B | **98** | 0 |
| **Composição** | **101** | **0** |

Normalizando por severidade, regra e arquivo (ignorando só o deslocamento de linha), **nenhum diagnóstico da composição está fora da união normalizada das duas entradas**.

`dart format --set-exit-if-changed` limpo no arquivo novo.

## 11. Mutações — 10 injetadas, 10 detectadas

Em cópia descartável, uma de cada vez, restaurada e conferida ao final.

| # | Mutação | Testes que morreram |
|---|---|---|
| 1 | `PerfilPage` inteira da Entrada A | falha de compilação da suíte de composição (`publicIdVisitado` não existe) |
| 2 | `PerfilPage` inteira da Entrada B | C8, `casca_producao` (convite), `estado_canonico` (convite sem nível), 2× `homologacao_perfil_publicavel` |
| 3 | remover o ranking injetado em `PerfilService` | C3 |
| 4 | restaurar `Bronze` como fallback | 3× `estado_canonico` (inclusive a auditoria do literal), `homologacao_perfil_publicavel` |
| 5 | restaurar nível `1` | C8, 2× `casca_producao`, `auditoria_casca`, 2× `estado_canonico`, `homologacao_perfil_publicavel` |
| 6 | abrir consulta de ranking no `build` | C1, C2, C3, C4, C8, C9, C10, C12, C13 e 5× `casca_producao` |
| 7 | aceitar resposta temporalmente vencida | C7, 6× `barreira_temporal`, 2× `regressao_leitor_ranking` |
| 8 | remover a guarda de propriedade do voo | `barreira_temporal` R7d |
| 9 | segunda leitura de Firebase Auth no Perfil | C11c e `auditoria_casca` |
| 10 | quebrar a porta única da Mesa Online | C14 e `auditoria_mesa_online` |

Nenhuma mutação sobreviveu. Nenhum defeito injetado permaneceu na árvore final — a `lib/` da cópia foi restaurada e conferida contra o repositório após cada rodada.

## 12. Riscos residuais

1. **As suítes de ranking e de composição não têm portão próprio no CI.** `ci-os-integracao.yml` roda alvos explícitos, e nenhum deles é de `test/ranking/` — isso já valia para `leitor_ranking_real`, `regressao_leitor_ranking`, `barreira_temporal`, `estado_canonico` e `homologacao_perfil_publicavel` antes desta composição, e agora vale também para `test/composicao/`. **É condição pré-existente, não introduzida aqui**, e mexer no workflow estaria fora do escopo declarado (§6 e §20). Fica registrada porque o verde local não é verde de CI.
2. **`C16` fixa um SHA-256 de `main.dart` no teste.** É proposital — o arquivo deve ser imutável nesta linhagem —, mas quem legitimamente alterar a raiz no futuro precisa atualizar a constante junto, e o teste diz isso na mensagem de falha.
3. **O trade-off conservador da barreira temporal continua valendo:** entre respostas contemporâneas divergentes o leitor mantém o que sabe e espera a próxima pergunta. Herdado da Entrada B, homologado lá.

## 13. Pendências que esta composição NÃO resolve

1. **Ativação do App Check.** Nenhuma chamada a `FirebaseAppCheck` em `app/lib/`; só a dependência no `pubspec.yaml`. Bloqueio externo de produção.
2. **Navegação produtiva para perfil público visitado.** `home_de_producao.dart` constrói `const PerfilPage()` sem `publicIdVisitado`; `consultarJogadorPorIdPublico` continua ligada e sem chamador de produção. A composição prova que o caminho funciona quando alguém o usar — não que já esteja em uso.
3. **Avatar real no Perfil.**
4. **Entrega excepcional do encerramento da UI.**
5. **Deploy ou release.**

Nenhuma delas foi absorvida silenciosamente.

## 14. Publicação

Branch `integracao/perfil-publicavel-mesa-online-ranking-real-v2-v1`, publicada com push normal, **sem `--force`**. Sem merge em `main`, sem PR, sem deploy, sem APK/AAB, sem alteração no servidor e sem ativação de App Check.
