# Composição — Perfil Publicável + Mesa Online/Casca V2 (V1)

Composição das duas linhagens já homologadas, na ordem tecnicamente aprovada:
**Mesa Online/Casca V2 primeiro, Perfil Publicável depois**. Nenhuma linha de
código de produção foi escrita, corrigida ou redesenhada aqui. O único arquivo
criado por esta OS é este documento.

Data: 2026-08-17.

### Procedência deste documento — duas execuções independentes

Esta OS foi executada **duas vezes, em paralelo, por duas sessões distintas no
mesmo worktree**, sem que uma soubesse da outra. A primeira commitou seu laudo em
`30f3803` e publicou a branch; a segunda produziu o laudo que você está lendo,
sobre o mesmo merge (`5b979c0`).

Isso não é acidente que enfraquece o resultado — é corroboração. As duas
execuções mediram, cada uma por conta própria: os mesmos dois SHAs de entrada, o
mesmo merge-base, a mesma árvore prevista por `merge-tree`
(`10a0329…`), os mesmos 35/39/35/**39** arquivos alcançáveis, as mesmas contagens
749/855/782/**888**, os mesmos 98/101/98/**101** diagnósticos com zero erro, os
mesmos **549** casos fora do glob, os mesmos **212** das suítes sensíveis, a
mesma ressalva do Flutter 3.41.4 contra o pin 3.44.8, e o mesmo veredito.
Nenhuma divergência numérica entre as duas.

Este documento é a **fusão** dos dois laudos: mantém o que só a primeira execução
havia registrado (tamanho dos deltas de B, `substitui` sem chamador,
`rodadasVulneravel`/`mortoPego` como omissões declaradas, a porta única de
leitura) e acrescenta o que só a segunda registrou (contagem **por arquivo** das
sete suítes `teste_*` e a passagem **sem** overlay de seeds — §7.2 e §7.4 da OS).
O laudo original da primeira execução permanece íntegro no histórico, em
`30f3803`.

---

## 1. Topologia

| Papel | Ref | SHA completo |
|---|---|---|
| Entrada B (absorvida 1º) | `origin/homologacao/ligacao-motor-canonico-casca-v2-p0` | `cf8fe37b0c232ad6dd35556ddac7f3e4bb729aa9` |
| Entrada A (absorvida 2º) | `origin/homologacao/perfil-publicavel-canonico-v1` | `4d24dbdb23dbf068d2f857d51907021174b23a46` |
| Merge-base (único) | — | `bc74e30a148a56b00ca7db691a378584efaa5207` |

Branch efetiva: `integracao/perfil-publicavel-mesa-online-casca-v2-v1`.

* HEAD inicial da sessão: `fb9edb5c6963964161f1e8834b57f50fe77074a1`
  (branch de worktree `claude/perfil-mesa-online-casca-v2-02d213`, descartada —
  a branch de integração nasceu **direto no SHA da Entrada B**, não dela).
* HEAD após criar a branch: `cf8fe37b0c232ad6dd35556ddac7f3e4bb729aa9`.
* HEAD final: `5b979c0ba7488b4d98e7648d7ff5ce802ac84d10`.

### Gate Zero

Os dois SHAs foram lidos por **duas consultas independentes** de `git ls-remote`
(a segunda sem filtro de ref, varrendo o remoto inteiro) e bateram. O refspec de
fetch está completo — `+refs/heads/*:refs/remotes/origin/*` — e cada ref foi
buscada explicitamente, não por `fetch --all`.

| # | Verificação | Resultado |
|---|---|---|
| 5 | `4b3c460…` ancestral da Entrada B | ✅ |
| 6 | `e87dd18…` ancestral da Entrada A | ✅ |
| 7 | merge-base único e igual a `bc74e30…` | ✅ (`merge-base --all` devolveu 1 linha) |
| 8 | nenhuma entrada é ancestral da outra | ✅ nos dois sentidos |
| 9 | `b246c072…` **não** incorporado | ✅ não é ancestral de A, de B nem do HEAD |
| 10 | árvore limpa | ✅ |
| 11 | `merge-tree` contra os SHAs finais | ✅ exit 0, zero conflito, árvore `10a0329…` |
| 12 | interseção de arquivos entre as entradas | ✅ **vazia** |
| 13 | grafo alcançável | ✅ **39** |

### Tamanho de cada entrada

| Delta | Arquivos | Linhas |
|---|---:|---|
| Funcional de B (`bc74e30 → 4b3c460`, 5 commits) | 13 | `+5254 / −71` |
| Bruto da entrada B homologada (`bc74e30 → cf8fe37`) | 14 | `+5422 / −71` |
| Entrada A homologada (`bc74e30 → 4d24dbd`) | 9 | ver §1 abaixo |

### Delta de homologação de cada entrada

Entrada B, sobre `4b3c460…` — **exclusivamente documental**:

```
8236091  docs(ligacao): declarar rodadasVulneravel, mortoPego e o substitui sem chamador
cf8fe37  docs(homologacao): laudo da homologacao independente da ligacao do motor
```

Toca `docs/LIGACAO-MOTOR-CANONICO-CASCA-V2-P0.md` e
`docs/HOMOLOGACAO-LIGACAO-MOTOR-CANONICO-CASCA-V2-P0.md`, e nada mais. Nenhum
código, nenhum teste.

Entrada A, sobre `e87dd18…` — **exatamente o delta previsto pela OS**:

```
c97ffb3  testes: a matriz da OS de homologação conferida por fora   (396 linhas, suíte nova)
4d24dbd  docs: o laudo da homologação independente do Perfil Publicável V1
```

Toca somente `app/test/ranking/homologacao_perfil_publicavel_test.dart` e
`docs/HOMOLOGACAO-PERFIL-PUBLICAVEL-CANONICO-V1.md`. **Zero alteração em
`app/lib/`.**

### Interseção vazia

Os arquivos funcionais das duas entregas não se tocam:

| Entrada B | Entrada A |
|---|---|
| `lib/casca/lobby_online.dart` (M) | `lib/pages/perfil_page.dart` (M) |
| `lib/casca/mesa_online/arte_das_cartas.dart` (A) | `lib/screens/perfil_screen.dart` (M) |
| `lib/casca/mesa_online/estado_mesa_online.dart` (A) | `lib/services/perfil_service.dart` (M) |
| `lib/casca/mesa_online/mesa_online_screen.dart` (A) | `test/casca/auditoria_casca_test.dart` (M) |
| `lib/casca/mesa_online/porta_de_comandos_online.dart` (A) | `test/casca/casca_producao_test.dart` (M) |
| `lib/services/online_service.dart` (M) | `test/ranking/estado_canonico_ranking_test.dart` (M) |
| 6 arquivos de teste em `test/casca/` | `test/ranking/homologacao_perfil_publicavel_test.dart` (A) |

Interseção: **∅**. É por isso que o merge é textualmente trivial — não por sorte,
e não por resolução manual.

---

## 2. Ordem e método

A branch foi criada **no SHA final homologado da Entrada B** e a Entrada A entrou
por merge explícito:

```
git checkout -b integracao/perfil-publicavel-mesa-online-casca-v2-v1 cf8fe37…
git merge --no-ff 4d24dbd…
```

Sem squash, sem rebase, sem cherry-pick, sem reconstrução manual de commit, sem
edição de código de produção. Os pais do merge comprovam a ordem no histórico:

```
5b979c0  ←  pai 1: cf8fe37 (Mesa Online/Casca V2)
         ←  pai 2: 4d24dbd (Perfil Publicável)
```

Primeiro pai = Mesa/Casca. A leitura `Mesa Online/Casca V2 → Perfil Publicável`
está gravada na topologia, não só na mensagem.

### Ancestralidade preservada

| SHA | Ancestral do HEAD final |
|---|---|
| `cf8fe37…` (homologação B) | ✅ |
| `4d24dbd…` (homologação A) | ✅ |
| `4b3c460…` (entrega B) | ✅ |
| `e87dd18…` (entrega A) | ✅ |
| `bc74e30…` (base comum) | ✅ |
| `b246c072…` | ❌ não-ancestral (como exigido) |

### O merge não inventou nada

A árvore do HEAD final é `10a0329864e7cc8c96a45cb037b4eb3007624087` — **idêntica à
que `git merge-tree` previu no Gate Zero**, antes de qualquer escrita. E os
diffs cruzados fecham:

* `diff cf8fe37 → HEAD` = exatamente os 9 arquivos do delta de A;
* `diff 4d24dbd → HEAD` = exatamente os 14 arquivos do delta de B.

Nenhum arquivo terceiro apareceu.

---

## 3. Ambiente de medição

Overlay do CI reproduzido fielmente a partir de
`.github/workflows/ci-os-integracao.yml`, em diretório de rascunho **fora do
repositório** (o repo nunca foi sujo pela execução das suítes):

```
flutter create --org com.buracomastervip.poc --project-name buraco_master_vip app_build
cp app/pubspec.yaml app/pubspec.lock app_build/ && flutter pub get
cp -R app/lib/. app_build/lib/
cd app && find assets -type f ! -name '*.dart' -exec … cp …        # .dart soltos excluídos
cp -R app/test/. app_build/test/
cp app/data/torneios/*.json  app_build/test/torneios/data/
cp app/data/colecoes/*.json  app_build/test/colecoes/data/
rm -f app_build/test/widget_test.dart
```

Foram construídos **quatro** overlays independentes — base, Entrada B, Entrada A
e composição — para que toda comparação fosse feita no mesmo ambiente. O
`pubspec.yaml` e o `pubspec.lock` são **blobs idênticos nas quatro árvores**
(`06e1225…` / `8723a30…`), então a resolução de dependências é provadamente a
mesma em todas as medições.

### Ressalvas ambientais

1. **Flutter local 3.41.4, pin do CI 3.44.8.** O pin não está disponível nesta
   máquina. Como a OS manda, a divergência fica registrada: as contagens abaixo
   são todas do **mesmo** Flutter 3.41.4, então as comparações entre entradas e
   composição são válidas; o valor absoluto contra o CI não é garantido.
2. **`flutter pub get` sai com código ≠ 0 nesta máquina.** A resolução conclui
   (`Got dependencies!`, 107 pacotes em `.dart_tool/package_config.json`); o que
   falha depois é a geração de registrantes de plugin nativo, que exige symlink
   (Modo de Desenvolvedor do Windows). `flutter analyze` e `flutter test` rodam
   na VM do host e não dependem desse passo. O overlay exige o
   `package_config.json` como prova real, em vez do exit code.
3. **`ShaderCompilerException` transitória.** A primeira execução da suíte padrão
   da composição abortou dentro do *tool* do Flutter em
   `TestCommand._buildTestAsset`, **antes de qualquer teste rodar** (zero casos
   executados, zero falhas de teste). A reexecução, sem nenhuma alteração de
   árvore, deu verde. É crash de ferramenta, não regressão — mas fica registrado.

---

## 4. Contagens

### 4.1 Suíte padrão (`flutter test`)

| Árvore | Referência da OS | Medido | |
|---|---:|---:|---|
| Base `bc74e30…` | 749 | **749** | ✅ |
| Entrada B final | 855 | **855** | ✅ |
| Entrada A final | 782 | **782** | ✅ |
| Composição | 888 | **888** | ✅ |

A aritmética fecha exatamente como a OS previu:

```
749  base
+106  Mesa/Casca  (855 − 749)
 +17  Perfil      (entrega A)
 +16  homologação (suíte de c97ffb3)
────
 888
```

E fecha também pelo outro lado: a Entrada A mede 782 = 749 + 17 + 16, isto é,
os 33 casos que A traz sobre a base. 855 + 33 = 888. Todas as quatro árvores
deram `All tests passed!`, exit 0.

### 4.2 Suítes fora do glob (`teste_*`)

Descobertas por comando (`find test -name 'teste_*.dart'`), não por lista
herdada. Executadas **uma a uma**, explicitamente:

| Arquivo | Casos |
|---|---:|
| `test/integracao/teste_integracao_motores.dart` | 64 |
| `test/moderacao/teste_moderacao.dart` | 42 |
| `test/motor/teste_visao_espectador.dart` | 15 |
| `test/social/teste_social.dart` | 90 |
| `test/teste_encerramento.dart` | 10 |
| `test/teste_motor.dart` | 132 |
| `test/teste_motor_resiliencia.dart` | 196 |
| **7 arquivos** | **549** |

Todas verdes, exit 0. Total **549**, como conhecido.

#### Resolução de "seis versus sete"

**São sete, e sempre foram sete.** A divergência é um erro de prosa no laudo da
Entrada A, contradito pelo próprio laudo duas linhas abaixo:
`docs/HOMOLOGACAO-PERFIL-PUBLICAVEL-CANONICO-V1.md:115` escreve "estas **seis**
usam o prefixo `teste_`" e em seguida, nas linhas 118–124, **enumera sete
arquivos**, cujos casos somam 64+42+15+90+10+132+196 = **549** — o mesmo total
que a pré-arbitragem registrou e o mesmo que foi medido agora.

Isto é, o número de arquivos estava errado; a enumeração e o total estavam
certos, e concordam com a pré-arbitragem. Nenhuma suíte foi perdida nem
acrescentada.

Confirmado por contagem direta na árvore, e o valor é **invariante**: base,
`4b3c460`, `cf8fe37`, `e87dd18`, `4d24dbd` e a composição têm **7 arquivos
`teste_*` cada**, os mesmos sete. Nenhuma das duas entradas mexeu nessa família.

### 4.3 Suítes sensíveis à composição

Executadas explicitamente sobre a composição:

| Suíte | Casos | |
|---|---:|---|
| `test/casca/auditoria_casca_test.dart` | 17 | ✅ |
| `test/casca/casca_producao_test.dart` | 30 | ✅ |
| `test/ranking/estado_canonico_ranking_test.dart` | 43 | ✅ |
| `test/casca/adaptador_visao_online_test.dart` | 35 | ✅ |
| `test/casca/mesa_online_test.dart` | 33 | ✅ |
| `test/casca/porta_de_comandos_online_test.dart` | 24 | ✅ |
| `test/casca/auditoria_mesa_online_test.dart` | 8 | ✅ |
| `test/casca/ligacao_mesa_caracterizacao_test.dart` | 6 | ✅ |
| `test/ranking/homologacao_perfil_publicavel_test.dart` (de `c97ffb3`) | 16 | ✅ |

Todas exit 0, sem nenhuma marca de falha. A suíte independente introduzida por
`c97ffb3` mede os **16 casos** que a OS declara. Somadas: **212 casos**.

### Total

```
888 (suíte padrão) + 549 (fora do glob) = 1.437 casos verdes
```

### 4.4 Seeds

Além da passagem com overlay de seeds (que produz os números acima), foi feita
uma passagem **sem** o overlay, nas três árvores, sobre as suítes que dependem
dele (`test/torneios`, `test/colecoes`):

| Árvore | Resultado sem seeds |
|---|---|
| Entrada B | `+32 -4`, 2 × `Cannot open file` |
| Entrada A | `+32 -4`, 2 × `Cannot open file` |
| Composição | `+32 -4`, 2 × `Cannot open file` |

A assinatura de falha é **idêntica** nas três (mesmos 4 testes, mesmos erros) —
confirmando que a falha é ambiental (ausência do seed) e que a composição não
introduz sensibilidade nova. Os seeds não foram versionados.

### 4.5 Análise estática

`flutter analyze --no-fatal-infos --no-fatal-warnings`, mesmo Flutter (3.41.4),
nos quatro overlays. Comparação por **lista normalizada** — cada ocorrência
reduzida a `severidade - mensagem - arquivo - regra`, com `:linha:coluna`
removidos, ordenada:

| Árvore | Ocorrências | Erros |
|---|---:|---:|
| Base | 98 | 0 |
| Entrada B | 101 | 0 |
| Entrada A | 98 | 0 |
| **Composição** | **101** | **0** |

Resultado da comparação normalizada:

* **composição ≡ Entrada B** — as listas são idênticas, linha a linha, nos dois
  sentidos;
* **base ≡ Entrada A** — a Entrada A não acrescenta **nenhum** diagnóstico;
* base → composição acrescenta **exatamente 3** ocorrências, que são as 3 da
  Entrada B, todas `info`, todas em arquivos de **teste da própria Entrada B**:

```
info - Invalid use of a private type in a public API   - test\casca\porta_de_comandos_online_test.dart - library_private_types_in_public_api
info - Use the null-aware marker '?' rather than …     - test\casca\bancada_online.dart                - use_null_aware_elements
info - Use the null-aware marker '?' rather than …     - test\casca\porta_de_comandos_online_test.dart - use_null_aware_elements
```

Composição: **zero erro, zero diagnóstico novo, nenhuma ocorrência nova em
arquivo tocado pela composição** — e a composição não tocou arquivo nenhum por
conta própria. Os 101 são 91 `info` + 10 `warning`.

O número 98 aparece aqui como a contagem da base e da Entrada A neste Flutter;
**não** foi usado como verdade universal, e sim medido em cada árvore.

---

## 5. Grafo alcançável e inventário

Fecho transitivo dos imports a partir de `lib/main.dart`, reproduzindo o
algoritmo de `_alcancaveisDaRaiz()` em `app/test/casca/auditoria_casca_test.dart`
(ignora `dart:` e pacotes externos; mapeia `package:buraco_master_vip/X → lib/X`;
despreza comentários).

| Árvore | Alcançáveis |
|---|---:|
| Base | 35 |
| Entrada B | 39 |
| Entrada A | 35 |
| **Composição** | **39** ✅ |

O grafo da composição é **idêntico ao da Entrada B**. A Entrada A não acrescenta
nenhum arquivo alcançável (ela modifica arquivos do Perfil que já eram
alcançáveis). Os 4 arquivos que a base ganha são exatamente o módulo da Mesa
Online da Entrada B:

```
lib/casca/mesa_online/arte_das_cartas.dart
lib/casca/mesa_online/estado_mesa_online.dart
lib/casca/mesa_online/mesa_online_screen.dart
lib/casca/mesa_online/porta_de_comandos_online.dart
```

### Inventário final — 39 arquivos

```
 1  lib/casca/casca_de_producao.dart          21  lib/screens/onde_jogar_screen.dart
 2  lib/casca/configuracoes_de_producao.dart  22  lib/screens/perfil_screen.dart
 3  lib/casca/escopo_autenticacao.dart        23  lib/screens/resultado_partida_screen.dart
 4  lib/casca/escopo_transporte.dart          24  lib/screens/splash_oficial_screen.dart
 5  lib/casca/home_de_producao.dart           25  lib/services/configuracoes_service.dart
 6  lib/casca/lobby_online.dart               26  lib/services/endpoint_servidor.dart
 7  lib/casca/login_de_producao.dart          27  lib/services/online_service.dart
 8  lib/casca/mesa_online/arte_das_cartas.dart        28  lib/services/perfil_service.dart
 9  lib/casca/mesa_online/estado_mesa_online.dart     29  lib/services/ponte_sessao_online.dart
10  lib/casca/mesa_online/mesa_online_screen.dart     30  lib/services/redacao_segredos.dart
11  lib/casca/mesa_online/porta_de_comandos_online.dart  31  lib/sessao/autenticacao_firebase.dart
12  lib/casca/onde_jogar_de_producao.dart     32  lib/sessao/comandos_de_autenticacao.dart
13  lib/casca/raiz_do_aplicativo.dart         33  lib/sessao/credencial_de_sessao.dart
14  lib/main.dart                             34  lib/sessao/escopo_sessao.dart
15  lib/mesa.dart                             35  lib/sessao/fonte_identidade.dart
16  lib/pages/perfil_page.dart                36  lib/sessao/fonte_identidade_firebase.dart
17  lib/ranking/estado_ranking.dart           37  lib/sessao/identidade_publica_sessao.dart
18  lib/screens/como_jogar_screen.dart        38  lib/sessao/sessao_do_jogador.dart
19  lib/screens/configuracoes_screen.dart     39  lib/sessao/sessao_firebase.dart
20  lib/screens/inicio_screen.dart
```

---

## 6. Autoridades verificadas

As auditorias estruturais das duas entradas continuam verdes na composição
(`auditoria_casca_test` 17, `auditoria_mesa_online_test` 8,
`casca_producao_test` 30, `estado_canonico_ranking_test` 43). Além delas, foram
feitas verificações independentes sobre o **código sem comentários** dos 39
arquivos alcançáveis (12.518 linhas), usando o mesmo removedor de comentários da
auditoria — necessário porque este repositório documenta defeitos removidos em
comentário, e uma varredura ingênua acusa falso positivo.

### Sessão e autenticação

* `FirebaseAuth` / `GoogleSignIn` aparecem em **código** em exatamente dois
  arquivos, ambos em `lib/sessao/`: `autenticacao_firebase.dart` e
  `sessao_firebase.dart`. Único dono. ✅
* Os mesmos dois são os únicos alcançáveis que importam `package:firebase_auth`
  ou `package:google_sign_in`. ✅
* As 7 outras ocorrências de `FirebaseAuth` no grafo (em `main.dart`,
  `lobby_online.dart`, `online_service.dart`, `perfil_service.dart`,
  `configuracoes_de_producao.dart`, `credencial_de_sessao.dart`,
  `sessao_do_jogador.dart`) são **comentários** que registram o defeito removido
  — zero delas é código. ✅
* `PonteSessaoOnline` segue como tradutor único para o transporte. ✅

### Mesa online

* `PortaDeComandosOnline` é **definida uma vez**
  (`mesa_online/porta_de_comandos_online.dart:100`) e **instanciada uma vez**
  (`lobby_online.dart:102`); as telas apenas a recebem como campo. Porta única de
  intenção. ✅
* `CapacidadesDaMesa` é definida uma vez em `estado_mesa_online.dart:213`,
  produzida por `capacidades({required bool conectado})` e consumida **só como
  campo de widget** — política de apresentação, não autoridade de legalidade. ✅
* `AdaptadorVisaoOnline` é a **porta única de leitura**: definida uma vez
  (`estado_mesa_online.dart:415`), e `.ler()` é chamado em **um só lugar**
  (`lobby_online.dart:160`). Só o adaptador lê a visão crua. ✅
* Nenhum motor de jogo cliente no caminho online: `auditoria_mesa_online_test`
  prova "nada no caminho online constrói um `Jogo`" e "a mesa online não importa
  o módulo da partida local". ✅
* `EstadoMesaOnline.substitui` (`estado_mesa_online.dart:373`) segue **sem
  chamador em produção** — verificado sobre o código sem comentários dos 39
  alcançáveis: a única outra ocorrência do texto "substitui" é a palavra
  portuguesa dentro de uma string em `lib/mesa.dart:500`. Permanece como estava
  na Entrada B; a composição não lhe deu uso novo. ✅
* `rodadasVulneravel` e `mortoPego` continuam **omissões declaradas** da mesa
  online (declaradas no commit `8236091` da homologação de B). Existem apenas em
  `lib/mesa.dart` — o motor local, do caminho Treino — e em nenhum arquivo do
  caminho online. ✅

**Ponto que exige leitura exata — `lib/mesa.dart` é alcançável (item 15).** Isso
é verdade na composição, e é igualmente verdade na **base**, na Entrada A e na
Entrada B — o conjunto alcançável da composição é idêntico ao da Entrada B. Não
é efeito desta composição. O laudo homologado da Entrada B já registra o fato
(§2, linhas 62–66): os dois arquivos de produção que importam `lib/mesa.dart` —
`home_de_producao.dart` e `onde_jogar_de_producao.dart` — o fazem **só para o
botão Treino**, que é o caminho local e não fala com rede. A invariante da OS
("a mesa local continua inalcançável") vale para o **caminho online**, e é essa
que a auditoria prova. A mesa local segue alcançável pela raiz via Treino,
exatamente como nas duas entradas aprovadas.

### Ranking

* `EstadoRanking` (`lib/ranking/estado_ranking.dart`) permanece autoridade única. ✅
* **Zero** literal `'Bronze'` em código alcançável — as 5 ocorrências do texto são
  todas comentários narrando o defeito eliminado. ✅
* Nenhum fallback de colocação (`?? 1`) em código alcançável. ✅
* Nenhum arquivo da mesa produz liga ou colocação. ✅

### Perfil

* Cadeia única confirmada: `home_de_producao.dart:36 → pages/perfil_page.dart:4 →
  screens/perfil_screen.dart`. ✅
* **Não existe Perfil concorrente**: `find lib -iname "*perfil*"` devolve
  exatamente 3 arquivos (`pages/perfil_page.dart`, `screens/perfil_screen.dart`,
  `services/perfil_service.dart`). ✅
* Ausência de dado demonstrativo, de VM antiga durante erro/carregamento,
  compartilhamento sem liga/colocação inventada e troca de sessão sem
  reaproveitamento visual: provadas pelas 43 + 16 + 30 + 17 asserções das suítes
  do Perfil/ranking/casca, todas verdes. ✅

### Raiz e roteamento

* `lib/main.dart` é **byte-idêntico ao da base** (`diff` vazio). Intocado. ✅
* Nenhuma Preview ou maquete alcançável — `mesa_vip_preview_screen.dart` e as
  demais telas de prévia estão fora dos 39. ✅
* Lobby → Mesa segue troca de corpo, não rota concorrente. ✅

---

## 7. Riscos residuais

1. **Flutter 3.41.4 ≠ pin 3.44.8.** Todas as comparações são internamente
   consistentes (mesmo binário nas quatro árvores), mas os valores absolutos —
   888 casos e 101 diagnósticos — não estão confirmados contra o pin do CI. A
   confirmação no pin depende de execução no CI.
2. **`ShaderCompilerException` transitória** no *tool* do Flutter (ressalva §3.3).
   Não afetou nenhum teste, mas pode reaparecer e ser confundida com falha de
   suíte por quem ler só o exit code.
3. **`lib/mesa.dart` alcançável pela raiz** (§6). Herdado da base e das duas
   entradas homologadas, restrito ao botão Treino. Não é regressão desta
   composição; fica registrado porque a redação da OS, lida sem o laudo da
   Entrada B ao lado, sugere o contrário.
4. **Erro de prosa no laudo da Entrada A** ("seis" onde são sete arquivos
   `teste_*`, §4.2). O laudo não foi editado — a OS proíbe tocar em qualquer
   arquivo além deste documento. Fica corrigido aqui, no registro.
5. **`flutter pub get` com exit ≠ 0** nesta máquina (ressalva §3.2). Não afeta a
   medição, mas quebra scripts que confiem no código de saída.
6. As duas branches homologadas continuam existindo e **não foram mescladas em
   branch protegida**; esta composição não as substitui.
7. **Duas sessões rodaram esta OS em paralelo no mesmo worktree** (ver
   Procedência, acima). O risco não é do resultado — que é concordante — e sim
   de processo: duas sessões concorrentes no mesmo diretório de trabalho podem
   sobrescrever arquivo uma da outra entre o `Read` e o `Write`. Aqui isso de
   fato ocorreu com este documento, e foi resolvido por fusão, sem perda: o
   laudo original está preservado em `30f3803`. Convém não despachar a mesma OS
   para dois worktrees iguais.

---

## 8. Resultado

Nenhuma condição de parada da §8 da OS ocorreu: sem conflito textual, sem edição
manual em `app/lib/`, grafo em 39, auditorias/ranking/mesa verdes, contagem final
em 888, as sete suítes `teste_*` verdes, analyzer sem diagnóstico novo, nenhuma
segunda autoridade de sessão, ranking, Perfil ou mesa, e ancestralidade das duas
homologações preservada.

```
PASS — PERFIL PUBLICÁVEL E MESA ONLINE/CASCA V2 COMPOSTOS EM LINHAGEM CANÔNICA
```

Sem RC, sem deploy, sem alteração no servidor, sem PR e sem merge em branch
protegida. A integração segue para homologação independente da composição.
