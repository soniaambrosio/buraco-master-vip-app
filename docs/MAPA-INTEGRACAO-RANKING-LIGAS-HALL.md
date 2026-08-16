# MAPA DE INTEGRAÇÃO — Ranking, Ligas e Hall dos Imortais (OS §4)

> Entregável obrigatório da seção 4, **antes** de qualquer alteração de código.
> Levantamento feito na máquina local, com Flutter instalado e o scaffold do CI
> reproduzido (seção B).

- Data: 11/08/2026
- Branch de trabalho: `integracao/ranking-ligas-hall`
- Base: `7a75bab49ca18a2876f43f69996de4903b9d6ccc` (`origin/integracao/fluxo-mesas`) — **conferida, bate com a OS**
- Fonte visual: `5b8ccc0ddaddb1432424f53015b4355022e67204` (`origin/codex/ranking-ui`) — **conferida, bate com a OS**
- Nenhum merge feito. `git merge codex/ranking-ui` **não** foi executado.

---

## A. A descoberta que muda o plano: a base já está à frente da fonte visual

A OS parte do princípio de que a UI de Ranking está em `codex/ranking-ui` e precisa
ser **portada** para a base. Conferido arquivo a arquivo, **não é o caso**: a base
já contém a mesma tela, em versão **estritamente mais nova**.

### A.1 A branch `codex/ranking-ui` está com os nomes de arquivo embaralhados

Os arquivos na raiz daquela branch não têm o conteúdo que o nome anuncia
(conferido por `git show` e por hash de blob):

| Caminho em `5b8ccc0` | Conteúdo real |
|---|---|
| `nav_ranking.webp` (36 KB) | **código Dart** — a `RankingScreen` |
| `liga_bronze.webp` (101 KB) | **código Dart** — o `main.dart` daquela fatia, com `_RankingPreviewHost` na linha 629 |
| `main.dart` (16 KB) | **YAML** — um workflow `name: Build APK` |
| `RANKING-UI-CODEX.md` (27 KB) | **imagem WEBP** (`RIFF…WEBPVP8X`) |
| `divisao_diamante.webp`, `liga_diamante.webp`, `liga_lenda.webp`, `liga_ouro.webp`, `nav_loja.webp`, `podio_ouro.webp` | webp de verdade, mas **deslocados um nome** em relação à arte correta |

A prova do deslocamento está nos hashes de blob: `5b8ccc0:divisao_diamante.webp` =
`b83ce1e6…` = `7a75bab:app/assets/ranking/liga_bronze.webp`; `5b8ccc0:liga_diamante.webp`
= `8e44e0f0…` = `7a75bab:app/assets/ranking/liga_prata.webp`; `5b8ccc0:podio_ouro.webp`
= `253fd317…` = `7a75bab:app/assets/ranking/podio_bronze.webp`. **A base tem os nomes certos.**

### A.2 A `RankingScreen` da base é superconjunto da do Codex

`git diff` entre `7a75bab:app/lib/screens/ranking_screen.dart` e o Dart escondido em
`5b8ccc0:nav_ranking.webp` dá 24 linhas, **todas de coisa que a base tem a mais**:

- o campo `selo` de `RankingRow` e a renderização do selo na linha da lista
  (`ranking_screen.dart:60`, `839-848`) — inexistente no Codex;
- as ligas **Platina** e **Imperial** na escada (`ranking_screen.dart:228-242`) —
  o Codex só ia até Diamante e depois “Lenda”.

O mesmo vale para o host: o `_RankingPreviewHost` da base já abre o Hall de verdade
(`main.dart:2046-2048`), enquanto o do Codex mostrava um aviso
(“Hall dos Imortais — conexão entra com o Claude”).

### A.3 Consequência para a OS

**Não há componente visual a portar.** O item “fonte visual” da OS §3 está
satisfeito pela própria base. O trabalho desta OS é inteiramente o outro lado:
**tirar o mock do caminho de produção e pôr um contrato de dados no lugar**,
preservando a tela como está. Isso também elimina qualquer risco em torno da
proibição de mesclar `codex/ranking-ui`: nada dela é necessário.

---

## B. Ambiente de verificação (baseline medida, não estimada)

O repositório **não versiona `pubspec.yaml`** — o projeto Flutter é gerado no CI
(`.github/workflows/build.yml:49-53`) por `flutter create` + overlay de
`app/lib`, `app/test`, `app/assets`. `/app_build/` está no `.gitignore`.

O scaffold foi reproduzido localmente e o overlay automatizado em
`app/tools/overlay_local.ps1` (fora de `app/lib/`, então nunca entra no APK).

Uma diferença importante entre o overlay ingênuo e o do CI ficou registrada no
próprio script: o CI copia os assets **subdiretório por subdiretório**
(`build.yml:55-143`), nunca `app/assets/` inteiro. Existem dois `.dart` soltos na
raiz de `app/assets/` (seção J) que, copiados junto, fazem o analyzer acusar
**16 erros que o CI não tem**. O script replica o comportamento do CI.

**Baseline em `7a75bab`, Flutter 3.41.4 / Dart 3.11.1** (o CI fixa 3.44.8):

| | resultado |
|---|---|
| `flutter analyze` | **0 erros · 13 warnings · 138 infos** (151 issues) |
| `flutter test` | **151 verdes · 0 falhas · 0 pulados** |

Números idênticos aos registrados no fechamento da OS de Mesas
(`docs/RESULTADO-INTEGRACAO-FLUXO-MESAS.md:66-67`) — a base está íntegra.

---

## C. Inventário da UI de Ranking (`app/lib/screens/ranking_screen.dart`, 1179 linhas)

Tela **`StatelessWidget` pura**: recebe VM + estado + callbacks, não busca dado
nenhum. É a fronteira ideal — nada nela precisa mudar de aparência.

| Item da OS §4 | Onde está | Observação |
|---|---|---|
| Tela de Ranking | `ranking_screen.dart:248-1162` | `RankingScreen` |
| Abas | `:7` (`enum RankingAba {temporada, global, amigos}`), `:484-538` | troca por `onTrocarAba` |
| Pódio | `:627-759` | posições 2/1/3, molduras por asset, `_PodioSpec` fixo |
| Lista de jogadores | `:761-879` | linha com posição, avatar, liga, pontos, direção, selo |
| Estados loading/empty/error | `:9` (`enum RankingEstado`), `:332-359`, `:1005-1101` | **já existem os quatro**: `carregando`, `normal`, `erro`, `vazio` |
| Retry | `:337-343` | botão “Tentar de novo” → `onRecarregar` |
| Pull-to-refresh | `:303-306` | `RefreshIndicator` → `onRecarregar` |
| Paginação | `:257`, `:355`, `:892-901` | botão “Carregar mais” → `onCarregarMais` (`VoidCallback?`) |
| Navegação para perfil | `:255`, `:658`, `:780` | `onVerJogador(int posicao)` — ver conflito **M.1** |
| Referência ao Hall | `:314`, `:429-482` | card roxo “Hall dos Imortais” → `onAbrirHall`, escondido por `vm.mostrarHall` |
| Escada de Ligas | `:75-85` (`LigaEscada`), `:903-955` | “SUAS LIGAS”, com `atual: bool` |
| Divisão atual | `:13-31` (`DivisaoAtual`), `:540-625` | nome, pontos, faltam, próxima, `posicaoLiga`, barra de progresso |
| Nav inferior | `:957-1003` | `NavDestino` (importado de `perfil_screen.dart:5`) |

### C.1 Modelos de apresentação já existentes

`DivisaoAtual` (`:13`), `PodioEntry` (`:33`), `RankingRow` (`:51`), `LigaEscada`
(`:75`), `RankingVM` (`:92`). O comentário em `:87-91` registra a intenção do
autor: “os tipos ficam temporariamente neste arquivo… na integração, o Claude
pode movê-los para `lib/models/` preservando exatamente esta API pública”.

---

## D. Inventário do Hall dos Imortais (`app/lib/screens/hall_screen.dart`, 627 linhas)

| Item | Onde está |
|---|---|
| Tela | `hall_screen.dart:89-417` (`HallScreen`, `StatefulWidget`) |
| Categorias | `:3-9` — `campeaoHoje`, `melhorDupla`, `maiorSequencia`, `reiRainhaSemana`, `lendaMes` |
| Modelos | `:11-14` `EstatHall`, `:16-34` `HonradoHall` (tem `id`, `nome`, `avatar`, `avatar2`, `stats`, **`vazio`**), `:36-82` `HallVM` |
| Arte | `:191` `assets/hall/painel_gloria.webp` — layout inteiro é a arte; a tela só posiciona avatar/nome/valor por percentual |
| Perfil | `:104` `onVerPerfil(String id)`, zonas em `:244-248` |
| Regras | `:123-130`, modal em `:447-512` |
| Presentes | `:132-143`, modal em `:522-626` |
| Navegação | `:107` `onNav(String)` — strings `'ranking'`, `'estatisticas'`, `'presentes'`, `'perfil'` (`:251-258`) |

**Estados: só existe “vazio por categoria”** (`HonradoHall.vazio`, tratado em
`:280`, `:313`, `:353`). Não há `carregando`, `erro` nem “indisponível” — os cinco
estados exigidos pela OS §9 **não estão implementados**.

---

## E. Dados mockados / hardcoded hoje no caminho de produção

| Onde | O quê |
|---|---|
| `ranking_screen.dart:111-245` | `RankingVM.mock()` — 3 pódios, 5 linhas, 6 ligas, divisão “Diamante III”, “Temporada acaba em 12d 6h”, nomes “Sônia Rainha/Marina/Beto/Cláudia/Ricardo/Fernanda/Paulo” |
| `main.dart:2040` | o host **chama** esse mock a cada build — é o que o jogador vê hoje |
| `main.dart:2049` | `onVerJogador` só mostra snackbar “Perfil da posição #N” |
| `main.dart:2050` | `onRecarregar` é `setState(() {})` — não recarrega nada |
| `main.dart:2051` | `onCarregarMais: null` — paginação desligada |
| `hall_screen.dart:40-81` | `HallVM.mock()` — 5 honrados fixos com estatísticas inventadas |
| `main.dart:984` | o host do Hall **chama** esse mock |
| `main.dart:987-990` | perfil e presentes do Hall só mostram snackbar |
| `perfil_service.dart:20` | `statsDemo = true` — números do Perfil são de demonstração (fora do escopo desta OS; ver **M.3**) |

Isso é exatamente o que a OS §6 proíbe manter: dado fictício no caminho de
produção. Nenhum deles é “fallback silencioso” hoje — é a **única** fonte.

---

## F. Serviços e interfaces existentes

| Arquivo | O que oferece | Serve para Ranking/Hall? |
|---|---|---|
| `services/perfil_service.dart` | `PerfilService.carregar({ehMeuPerfil})` → `PerfilVM`; identidade real do Firebase Auth (`:62-66`) | **parcialmente** — é o caminho de perfil, mas não aceita id de outro jogador |
| `services/online_service.dart` | WebSocket do servidor de partidas (Railway) | **não** — protocolo é `criarMesa/entrarMesa/iniciarPartida/jogada/sair` (`:102-143`); não há mensagem de ranking |
| `services/configuracoes_service.dart` | preferências locais (SharedPreferences) | não |
| `services/mesa_orientation_service.dart` | preferência de orientação | não |
| `pages/perfil_page.dart` | controlador do Perfil: estados, retry, 14 callbacks | **é o modelo a seguir** para o Ranking |

**Não existe `RankingService`, `LigaService` nem `HallService`.**

---

## G. Origem real disponível para cada dado — o achado central

Levantamento das fontes que o app **realmente alcança hoje**:

1. **Firebase Auth** — única peça de Firebase ativa (`main.dart:6-8, 57-63`).
   Dá `uid` e `displayName`. Não dá ranking.
2. **Sem Cloud Firestore.** O CI declara as dependências em `build.yml:146`:
   `firebase_core`, `firebase_auth`, `google_sign_in`, `audioplayers`,
   `web_socket_channel`, `shared_preferences`. **`cloud_firestore` não está lá**,
   e nenhum arquivo em `app/lib/` o importa.
3. **Servidor Node (Railway)** — `wss://buraco-servidor-production.up.railway.app`
   (`online_service.dart:22-23`). Varredura no `server.js` (4102 linhas) por
   `ranking|leaderboard|classifica|hall|imortal|liga|temporada`: **nenhum
   endpoint, mensagem ou coleção de ranking**. É o motor de partida e o lobby.
4. **Sem persistência de resultado.** O próprio `perfil_service.dart:8` registra:
   “sem Cloud Firestore, a mesa não grava resultados”.

**Conclusão: não existe hoje nenhuma fonte autoritativa de posição de Ranking,
de Liga oficial ou de quadro do Hall.** Não é uma fonte incompleta — é a ausência
da fonte.

Pela OS §5, isso não autoriza calcular nada no cliente. Autoriza exatamente o que
está na lista da própria seção: **modelo, interface, adapter/seam, fake só em
teste, e a dependência documentada**.

---

## H. Contratos ausentes (o que esta OS precisa criar)

| Contrato | Por que é necessário |
|---|---|
| `RankingConsulta` (escopo + cursor) | a UI tem 3 abas e paginação; sem cursor não há como pedir “a próxima página desta aba” |
| `RankingPagina` (itens + cursor seguinte + fim) | OS §10: ordem estável, fim de lista reconhecido, sem duplicar |
| `RankingJogador` (id público, apelido, avatar, liga, pontos, posição, direção, delta, selo) | a linha da UI precisa de **id** — hoje só tem posição (ver **M.1**) |
| `LigaOficial` / `DivisaoOficial` | OS §7: a Liga vem da fonte, o cliente não descobre |
| `RankingService` (interface) | fronteira única de dados; injetável |
| `HallQuadro` / `HallHonrado` (id público + estatísticas já formatadas pela fonte) | OS §9: o cliente não escolhe imortal |
| `HallService` (interface) | idem |
| `PerfilService.carregar(jogadorId:)` | OS §8: abrir o perfil de **outro** jogador pelo fluxo real, sem duplicar lógica |

---

## I. Conflitos entre a UI atual e a arquitetura — e como reconciliar

### I.1 `onVerJogador(int posicao)` não carrega identidade — **bloqueante para a OS §8/§12**

`ranking_screen.dart:255` entrega **a posição**, e `RankingRow`/`PodioEntry` não
têm campo de identificador. Posição não identifica ninguém: muda a cada
atualização e não serve de chave de navegação.

**Reconciliação sem mexer no visual e sem quebrar a API pública:** acrescentar um
campo `jogadorId` (com valor padrão `''`) a `RankingRow` e `PodioEntry`, e o host
resolve `posicao → jogadorId` na página que ele mesmo tem em mãos. A assinatura
`ValueChanged<int> onVerJogador` fica **intacta**, nenhum widget muda, e o id
público (UID, nunca e-mail — OS §12) atravessa para o Perfil. Linha sem id
resolvido não navega.

### I.2 O Hall não tem estados

`HallScreen` (`hall_screen.dart:89-111`) só aceita `vm`. A OS §9 exige cinco
estados. Reconciliação: parâmetros **aditivos** com padrão que preserva o
comportamento atual (`estado: HallEstado.normal`), mais uma camada de
carregando/erro/indisponível por cima da arte. Nenhuma coordenada percentual muda.

### I.3 `HallScreen.onNav(String)` é destino por string

`hall_screen.dart:107` usa `'ranking' | 'estatisticas' | 'presentes' | 'perfil'`,
enquanto o resto do app usa `enum NavDestino` (`perfil_screen.dart:5`). Não é
bloqueante — o host traduz. Trocar o tipo mudaria a API pública da tela sem
ganho para esta OS. **Fica como está, traduzido no host.**

### I.4 `RankingVM.mock()` e `HallVM.mock()` vivem em `lib/`

Enquanto estiverem em `app/lib/`, viajam dentro do APK. A OS §6 manda que dado
fictício exista “exclusivamente em testes”. Reconciliação: remover as duas
`factory .mock()` de `lib/` e recriar as mesmas fixtures em `app/test/`, onde
elas passam a servir aos testes de UI. Os **modelos** ficam onde estão.

### I.5 Navegação: `_RankingPreviewHost` é chamado de cinco lugares

`main.dart:272`, `:812`, `:894`, `:995`, `:1614`. O host novo precisa entrar em
**todos**, senão sobra caminho para o mock. `_HallPreviewHost` é chamado de um só
lugar (`main.dart:2047`).

### I.6 Sem rotas nomeadas

Navegação é imperativa por `MaterialPageRoute` em todo o `main.dart`. Não há
`routes:`/`onGenerateRoute`. O host novo segue o mesmo padrão — introduzir rotas
nomeadas agora seria mudança de arquitetura fora do pedido.

---

## J. Arquivos fora de lugar (registrar, **não apagar** — mesma regra da OS anterior)

Além dos já registrados em `docs/MAPA-INTEGRACAO-FLUXO-MESAS.md:184-192`, esta
varredura achou mais dois, **relevantes porque quebram o analyzer** se o overlay
não imitar o CI (seção B):

1. `app/assets/loja_categoria_screen.dart` (58 KB) — código Dart dentro de `assets/`;
2. `app/assets/loja_categoria_screen_1.dart` (58 KB) — cópia byte a byte do anterior.

Nenhum dos dois é referenciado por `app/lib/`. Nenhum foi removido.

---

## K. Arquivos que serão alterados

| Arquivo | Alteração |
|---|---|
| `app/lib/screens/ranking_screen.dart` | **aditiva**: campo `jogadorId` em `RankingRow`/`PodioEntry`; **remoção** de `RankingVM.mock()`. Zero mudança de layout. |
| `app/lib/screens/hall_screen.dart` | **aditiva**: `estado`/`mensagemErro`/`onRecarregar` com padrão; **remoção** de `HallVM.mock()`. Coordenadas intocadas. |
| `app/lib/main.dart` | trocar `_RankingPreviewHost` e `_HallPreviewHost` pelas páginas novas nos 6 pontos de chamada |
| `app/lib/pages/perfil_page.dart` | parâmetro `jogadorId` opcional |
| `app/lib/services/perfil_service.dart` | `carregar({jogadorId})` — seam para perfil de terceiro |
| **novos** | `app/lib/ranking/ranking_contract.dart`, `app/lib/ranking/ranking_paginacao.dart`, `app/lib/ranking/ranking_apresentacao.dart`, `app/lib/services/ranking_service.dart`, `app/lib/pages/ranking_page.dart`, `app/lib/hall/hall_contract.dart`, `app/lib/services/hall_service.dart`, `app/lib/pages/hall_page.dart` |
| **novos (teste)** | `app/test/ranking_*_test.dart`, `app/test/hall_*_test.dart` |

## L. Áreas que permanecem intocadas

`app/lib/mesa.dart` · `screens/mesa_*.dart` · `screens/preparando_partida_*.dart`
· `screens/resultado_*.dart` · `screens/vitoria_celebracao.dart` ·
`screens/configurar_mesa_screen.dart` · `screens/onde_jogar_screen.dart` ·
`services/mesa_orientation_service.dart` · `services/online_service.dart` ·
`app/lib/torneios/**` · `screens/loja*.dart` · `screens/recompensas_screen.dart`
· `.github/workflows/build.yml` · `keystore/**` · qualquer coisa de Billing,
economia, moderação, motor ou servidor.

Os 151 testes da base rodam de novo ao final para provar que a OS de Mesas não
regrediu (OS §14).

---

## M. Dependências e pontos de parada (OS §4, regra de parada)

### M.1 — resolvido dentro desta OS
O id do jogador no Ranking: resolvido por campo aditivo (seção I.1), sem tocar
motor nem backend.

### M.2 — **dependência externa, não resolvível aqui**: não existe fonte de Ranking/Liga/Hall
Provado na seção G. Consequências, dentro do que a OS §5 autoriza:

- o contrato e o `RankingService`/`HallService` são criados e a UI passa a
  trabalhar **por contrato**;
- a implementação embarcada no caminho de produção é a que declara **ausência de
  fonte** — a tela mostra o estado honesto (“indisponível”), com retry;
- **nenhum número é inventado**: sem mock, sem fallback, sem cálculo local;
- implementações de teste (fakes) existem **só** em `app/test/`;
- ligar a fonte real, quando existir, é trocar **uma** implementação de interface.

Linhagem adjacente que provavelmente resolverá isso (registro, não uso):
a camada de rastreabilidade em `claude/buraco-vip-game-traceability-3eb66c`
(`app/lib/rastreabilidade/`) nasceu para carimbar resultado de partida — e a
fórmula de ranking está lá **em aberto**. Fechar a fórmula e publicar o quadro é
trabalho de autoridade, fora desta OS.

### M.3 — fora do escopo, registrada
`PerfilService.statsDemo = true` (`perfil_service.dart:20`) mantém números de
demonstração no Perfil. É a linhagem do Perfil, não a do Ranking; esta OS **não**
mexe nisso, só passa a poder abrir o perfil de outro jogador.

### M.4 — o que esta OS **não** vai fazer
Nada de: posição oficial, pontos oficiais, subida/queda de Liga, desempate,
fechamento de temporada, promoção, rebaixamento, premiação, elegibilidade,
punição, exclusão de partida, validade de resultado. Nenhum desses cálculos
entra no cliente — nem provisoriamente.

---

## N. Confirmação de isolamento

Nenhum merge. `main`, `consolidacao/apk-geral-bmv`, `codex/ranking-ui`, as
branches de motor/backend e o Firebase não foram tocados. A branch
`integracao/ranking-ligas-hall` nasceu exatamente de `7a75bab…`.
