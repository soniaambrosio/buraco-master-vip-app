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
