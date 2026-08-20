# OS — Coleções e Inventário do Jogador V1

Primeira superfície produtiva do módulo de coleções. O domínio e o contrato
existiam desde o Kit Pioneiros 2026 e **nenhuma tela os consumia**: o jogador
recebia os itens e não tinha onde vê-los.

## Gate Zero — o que foi encontrado

| Item | Onde | Situação |
| --- | --- | --- |
| `lib/colecoes/` | `app/lib/colecoes/` — 8 arquivos | existe |
| `colecao_ui_contract.dart` | `app/lib/colecoes/colecao_ui_contract.dart` | existe |
| Linhagem do Kit Pioneiros | `claude/kit-pioneiros-2026-1b56ed` (publicada), contida em `claude/autoridade-tipos-mesa-permissoes-v1` | existe |
| Autoridade de posse | `ColecaoRepositorio.carregarInventario` → `users/{uid}/inventory`; predicados em `InventarioUsuario.possui` / `.estaEquipado` | **existe e é canônica** |
| Assets canônicos | `app/assets/colecoes/pioneiros_2026/` — 10 PNGs, já declarados no `pubspec.yaml` | existem |

Censo confirmado: antes desta entrega, `colecao_ui_contract.dart` era importado
apenas por si mesmo e por `test/colecoes/`. Zero telas.

**Não houve BLOCKED.** A UI não adivinha posse em nenhum ponto: quem afirma que
um item é do jogador é o Firestore, por leitura do repositório.

## Base

`claude/colecoes-inventario-jogador-v1`, criada de
`claude/autoridade-tipos-mesa-permissoes-v1` (`c0bd150`).

A branch original da OS (`claude/colecoes-inventario-jogador-67b062`) nascera de
um `main` obsoleto e **não continha o módulo de coleções** — só os commits de
ruído (`noop`, `Goodbye World`). Não foi mesclada: traria o ruído de volta.

## O que foi entregue

### 1. Projeção pura — `colecao_ui_contract.dart` (acrescentado)

`EstadoInventario`, `GrupoInventario`, `InventarioVM`, `InventarioCallbacks` e
`montarInventarioVM(catalogo:, inventario:)`.

A decisão que sustenta a OS: **a projeção itera o INVENTÁRIO, nunca o catálogo.**
Varrer o catálogo e perguntar "possui?" produziria a lista de tudo que existe
com os não possuídos marcados — que é a estrutura de uma loja, e mais cedo ou
mais tarde alguém desenharia os cadeados. Partindo do inventário, um item que o
jogador não tem simplesmente não existe na tela, nem como silhueta.

Itens possuídos que o catálogo desta versão não conhece são **contados e não
desenhados** (`itensSemDefinicao`): sem definição não há nome nem arte, e um card
com id cru seria pior do que dizer que falta atualizar. Escondê-los faria o
jogador contar menos itens do que tem e concluir que perdeu alguma coisa.

### 2. `services/inventario_service.dart` (novo)

Compõe as duas autoridades que nunca haviam se encontrado numa tela: o catálogo
do bundle (quais itens existem) e o inventário do Firestore (o que é do jogador).

- lê por **UID do Firebase**, não por `publicId` — aquele é opaco e consultaria
  um caminho que não existe;
- `uid` nulo devolve `semSessao`, e não "vazio": não ter itens e não saber se tem
  são coisas diferentes;
- esquece o acervo do dono anterior **antes** da leitura seguinte, para que
  trocar de conta não mostre o acervo alheio no frame intermediário;
- equipar: o domínio decide (`InventarioUsuario.equipar`), o servidor grava
  (`aplicarEquipagem`), e só então o estado em memória muda.

### 3. `pages/inventario_page.dart` (novo)

Consome `RegrasDeExibicao` do contrato em vez de repetir os valores:
`BoxFit.contain`, margem de `paddingVisualMinimo`, sem placa atrás da arte, fundo
escuro neutro, sem precache em massa.

Estado vazio é vazio: nenhuma oferta, nenhum "veja o que você poderia ter".
Item não equipável ganha rótulo do que ele é, não botão cinza — botão desabilitado
convida a insistir numa ação que não existe.

### 4. Navegação

`perfil_page.dart`: `onTrocarVitrine` deixou de ser `_breve('…')` e abre o
Inventário. Era o seam já existente — "trocar itens da vitrine" É a pergunta "o
que eu tenho para pôr aqui?".

O Perfil continua sem saber de posse: ele navega, não consulta. Ligar
`PerfilService._vitrinePadrao` ao inventário real é outra fatia; fazê-la de
carona aqui criaria uma segunda origem de posse.

## Não entregue, e por quê

**Desequipar puro não existe nesta versão — por falta de autoridade, não de
escopo.** `InventarioUsuario.desequipar` existe e decide certo, mas
`ColecaoRepositorio.aplicarEquipagem` — o único caminho de escrita — sempre marca
um item como equipado no mesmo lote. Não há como persistir um desequipar puro.

Um botão assim mudaria a interface e não o servidor: o item voltaria equipado na
leitura seguinte, e o jogador leria isso como perda do item. Por isso
`InventarioCallbacks` **não declara `onUnequip`**.

Na prática ninguém fica preso: todo slot desta coleção tem `maxAtivos: 1`, então
equipar outra peça do mesmo slot troca a ativa — e a troca tem caminho de escrita.

Também ficaram de fora, deliberadamente: compra, preço, saldo, concessão/resgate,
e o zoom de cosméticos (responsabilidade própria, fora desta OS).

## Infraestrutura que precisou mudar

O catálogo (`app/data/colecoes/catalogo.seed.json`) já era a fonte da verdade do
módulo, mas **só os testes o liam, direto do disco**. Em execução, o aplicativo
levantava o inventário e não tinha de onde saber o nome de uma peça.

- `pubspec.yaml`: declara `data/colecoes/catalogo.seed.json` — arquivo a arquivo,
  não a pasta, para que manifesto de arte e relatório de PNG não pesem no APK;
- `.github/workflows/build.yml`: passo novo copiando o catálogo para
  `app_build/data/colecoes/`. Sem ele o próprio `flutter build` quebraria — o
  pubspec copiado declara o arquivo, e asset declarado que não existe é erro de
  build. As duas suítes novas entraram no portão do Kit Pioneiros;
- `app/tools/overlay_local.ps1`: mesma cópia, mais os seeds de coleções em
  `test/colecoes/data/`, para o overlay local reproduzir o CI;
- `tools/android/bin/verificar_assets.dart`: o portão conferia a existência do
  que é declarado contra uma varredura que só enxerga `app/assets/`. Toda
  declaração fora dali era reprovada por definição — a pasta existia, o build
  passava, e o portão acusava falha. Agora lê o disco, que é a pergunta que ele
  realmente faz.

## Verificação

- `flutter analyze` nos 6 arquivos novos/alterados: **No issues found**.
  Árvore inteira: 54 issues, **nenhuma** em arquivo desta entrega (pré-existentes,
  concentradas em `tools/print_mesa.dart`, `loja_categoria_screen.dart` e telas de mesa).
- `test/colecoes/inventario_vm_test.dart` — 13 casos, verde.
- `test/colecoes/inventario_page_test.dart` — 9 casos, verde.
- Suítes de coleções pré-existentes (kit_pioneiros, colecao_arte, colecao_firebase,
  evidencias_visuais): verdes.
- Portão de assets: **APROVADO**.

### Mutações injetadas (a cobertura foi provada, não presumida)

| Mutação | Resultado |
| --- | --- |
| projeção varre `catalogo.itens` em vez de `inventario.itens` (vira loja) | **12 testes quebram** |
| escrita de equipagem perde `itemIdsDesequipados` | **1 teste quebra** (o da troca de slot) |
| pubspec declara pasta inexistente | portão de assets **reprova** |

## Pendência encontrada, fora do escopo

`test/sessao/telas_consomem_identidade_test.dart` **não compila** na base:
chama `RankingVM.mock()`, removida de propósito em uma integração anterior
(o comentário em `ranking_screen.dart:106` registra a remoção). É anterior a esta
OS e não foi tocada.

## Procedência do UID (auditoria de encerramento)

**PASS — a identidade vem da sessão canônica, sem leitura independente de auth.**

Varredura por `FirebaseAuth` / `currentUser` / `authStateChanges` /
`firebase_auth` em `lib/services/inventario_service.dart`,
`lib/pages/inventario_page.dart` e `lib/colecoes/*.dart`: **nenhuma ocorrência.**

A cadeia é:

```
SessaoDoJogador.estado.uid
  → EscopoSessao.identidadeDe(context).uid        (inventario_page.dart)
    → InventarioService.carregar(uid) / .equipar(uid, …)
      → ColecaoRepositorio.carregarInventario(uid:)  → users/{uid}/inventory
```

O serviço **não descobre** o UID: recebe-o por parâmetro e não importa
`firebase_auth`. A página lê `EscopoSessao`, que é o `InheritedNotifier` da
`SessaoDoJogador`. `publicId` não é usado como chave em ponto nenhum — é opaco e
apontaria para um caminho inexistente.

### Defeito encontrado nesta auditoria e corrigido

Seguindo esse fio apareceu uma corrida real, presente no commit anterior
(`3829066`): `carregar()` escrevia `_inventario` e `_uidCarregado` **depois do
`await`, sem verificar se outra leitura a havia superado**.

`Future` não se cancela em Dart. A leitura de A continua e termina mesmo depois
da troca de conta — então uma resposta lenta de A que chegasse **depois** da de B
sobrescrevia o estado com o de A: B via o acervo de A, e `equipar` passava a
aceitar item de A em nome de B.

Correção: contador de geração. `carregar` numera o pedido, e a resposta que não
for a do pedido corrente é **descartada** (devolve `null`) em vez de aplicada —
inclusive no caminho de erro, para que a falha de A não apareça na tela de B.
`equipar` recusa o *commit* em memória se a sessão virou durante a escrita (a
gravação no servidor foi de A, no caminho de A, e estava correta — o que não pode
é ela virar estado de B). A página ignora `null` e lê o UID da sessão **no
momento do toque**, não de um campo desenhado antes.

### Prova

Repositório com portão por UID, tornando a corrida determinística (sem portão o
teste passaria por sorte). Cinco casos em `inventario_page_test.dart`:

| Caso | Garante |
| --- | --- |
| acervo de A não APARECE depois de B carregar | leitura superada devolve `null` |
| acervo de A não é ACEITO em B | `equipar` segue operando como B |
| item de A nunca é aceito em nome de B | recusa `itemNaoPossuido`, nada vai ao servidor |
| sair da conta durante a leitura | resposta descartada, nada fica em memória |
| erro de leitura superada | não vira erro na tela de B |

Mutação: **removida a trava de geração, 4 dos 5 casos quebram.**

Total do portão de coleções: **140 casos, verdes.**

---

## OS 27-C1 — asset produtivo do catálogo e portão real do Inventário

A arbitragem da OS 27 confirmou a autoridade de identidade (a cadeia
`FirebaseAuth.authStateChanges → SessaoDoJogador → EscopoSessao → InventarioService`,
sem segunda autoridade e sem leitura direta de `currentUser`), mas reprovou a
folha por **regressão de build** e por **portão que não alcançava a entrega**.

### 1. O catálogo era declarado em um lugar e copiado em outro

`app/pubspec.yaml` passou a declarar `data/colecoes/catalogo.seed.json` — um
asset **fora de `assets/`**. O passo de cópia entrou só no `build.yml`. As outras
três superfícies de montagem copiam o pubspec versionado e conferem a declaração
com um `sed` que exige prefixo `assets/` **e** barra final, de modo que um
arquivo avulso some das três ao mesmo tempo, em silêncio:

| Superfície | Antes | Consequência |
| --- | --- | --- |
| `tools/ci/montar_app.sh` | não copiava | `tamanho-aab.yml` — o **único** workflow que dispara em `claude/**` — quebrava |
| `release-aab.yml` | não copiava | o **único pipeline oficial de publicação** quebrava |
| `web.yml` | não copiava | `flutter build web` quebrava |

Reproduzido: `No file or variants found for asset: data/colecoes/catalogo.seed.json`
/ `Failed to build asset bundle`. Removida a declaração, o bundle volta a montar —
ou seja, o defeito nasceu com a declaração.

A correção **não** foi um quarto `cp` digitado à mão, porque o defeito É a lista
paralela. `tools/ci/copiar_assets_de_dados.sh` lê o bloco `assets:` do pubspec,
copia toda entrada que seja ARQUIVO e reprova se a fonte não existir. As quatro
superfícies passam a chamá-lo, e `overlay_local.ps1` aplica a mesma regra.
Declarar no pubspec passa a bastar.

### 2. O portão não alcançava a entrega

As duas suítes do Inventário entraram só no `build.yml`, que dispara em
`main/master/codex/inicio-ui`. Nas folhas quem roda é o `tamanho-aab.yml`, e ele
rodava a lista antiga de três suítes: **a prova de troca A→B nunca executou em
CI**. A causa era a mesma — duas listas digitadas (uma no `cp`, outra no
`flutter test`) que divergiram sem que nada acusasse.

Agora os dois portões **derivam** a lista do diretório, excluem o gerador de
evidências e são fail-closed. Provas negativas, com `exit=1` em todas:

| Sabotagem | Resultado |
| --- | --- |
| suíte obrigatória trocada por outra (contagem intacta) | reprova nomeando a suíte perdida |
| contagem abaixo de 5 | reprova |
| diretório de suítes vazio | reprova |

### 3. Cobertura que media desenho, não comportamento

A arbitragem mostrou que três proteções podiam ser **apagadas** com a suíte
inteira verde. Os casos que faltavam foram escritos, e a matriz de mutação
fechou:

| Mutação | Antes | Agora |
| --- | --- | --- |
| trava de geração em `carregar` | morre (4 de 5) | morre |
| guarda do caminho de erro | morre | morre |
| guarda pós-escrita de `equipar` | **sobrevivia** | morre |
| checagem de dono na entrada de `equipar` | **sobrevivia** | morre |
| página lê o UID do campo, não da sessão no toque | **sobrevivia** | morre |

A janela da guarda pós-escrita só é alcançável com a conta virando no meio da
gravação, então o repositório de teste ganhou portão de ESCRITA e o sinal
`escritaComecou`: sem ele, `carregar` do outro UID esquece o inventário antes de
`equipar` lê-lo, e o teste mediria a guarda de entrada.

Total do portão de coleções: **143 casos, verdes**. `flutter analyze`: 117 issues,
**0 erros** — idêntico à base.
