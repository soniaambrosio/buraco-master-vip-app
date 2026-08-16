# CENSO DE TELAS E PRONTIDÃO VISUAL/FUNCIONAL V1

**Buraco Master VIP** — auditoria e diagnóstico.
Data de apuração: **2026-08-15**.
Natureza: **somente auditoria**. Nenhuma tela foi corrigida, nenhum merge feito,
nenhum deploy executado. Ver §20 da OS e a seção 16 deste documento.

---

## 1. RESUMO EXECUTIVO

O Buraco Master VIP tem **27 telas ativas**. Destas, **2 estão prontas**,
6 estão quase prontas, 3 estão implementadas sem homologação e **16 são
incompletas ou placeholders**. Existem ainda **6 telas órfãs** que não fazem
parte do produto alcançável e não entram na contagem.

O achado central não é a contagem. É a **natureza do `main.dart`**:

> O aplicativo não tem uma casca de produção. Ele tem uma **bancada de prévias**.
> A raiz monta `SplashOficialScreen(proximaTela: _InicioPreviewHost())`, e
> praticamente todo destino do menu é um `_XxxPreviewHost` que desenha um
> `VM.mock()`. Os nomes das classes dizem isso literalmente.

Dez das doze superfícies principais do menu são alimentadas por
`InicioVM.mock()`, `SaguaoVM.mock()`, `AmigosVM.mock()`, `LojaVM.mock()`,
`LojaCategoriaVM.mock()`, `HallVM.mock()`, `OndeJogarVM.mock()`,
`RecompensasVM.mock()`, `ConfigMesaVM.mock()`, `PreparandoPartidaVM.mock()`,
`RankingVM.mock()` e `PerfilService.statsDemo = true`.

Três consequências que mudam a leitura do produto:

1. **Não existe tela de login alcançável.** O único formulário de entrada com
   Google Sign-In vive na classe `HomeScreen` (`main.dart:1851`), que **nenhum
   código referencia**. O app abre direto na Home.
2. **A Home exibe dados pessoais fixos.** `InicioVM.mock()` traz
   `'Sônia Rainha'`, `soniia.ambrosio@gmail.com`, `1000` moedas e liga
   `'Diamante'` — para qualquer pessoa que instalar o aplicativo.
3. **O produto não existe inteiro em nenhuma branch.** Confirmado pelo
   `RC-V1-MANIFESTO-DE-COMPOSICAO.md` e reconfirmado aqui: a UI de Ranking/Hall
   está numa linhagem, a arte da Loja em outra, o motor canônico numa terceira.

Não há, hoje, um artefato único que possa ser publicado.

---

## 2. BASE AUDITADA

A OS proibiu presumir a base. A investigação confirmou o que o manifesto da RC
V1 já registrava.

```text
main                          fb9edb5c6963964161f1e8834b57f50fe77074a1   PLACEHOLDER
consolidacao/apk-geral-bmv    0cea0d6d68f2c93613b985f4aa85800d77cf42d7   BASE AUTORIZADA
```

`main` carrega 5 commits exclusivos, todos placeholder declarado
(`Add files via upload`, `Update print statement to say 'Goodbye World'`,
`Update main.dart`, `noop`, `chore: remover arquivo noop criado por engano`).
A consolidação carrega 90 commits exclusivos de produto.

**Branch desta auditoria:** `auditoria/censo-telas-prontidao-v1`, criada a partir
de `0cea0d6` — a base autorizada, não de `main`.

### 2.1 O produto não cabe numa branch

Nenhuma branch isolada contém o produto. O censo foi feito sobre a **união** das
linhagens, com procedência registrada por tela. Snapshots extraídos por
`git archive` (leitura pura — nenhum merge):

| ID | Branch | `app/lib/**.dart` | Papel no censo |
| --- | --- | --: | --- |
| **A** | `claude/account-deletion-google-play-compliance-b94769` | 114 | Linhagem principal mais profunda. Contém billing, conta, sessão, coleções, moderação, social, torneios, e as 6 codebases de Functions. |
| **B** | `integracao/ranking-ligas-hall` | 56 | Única com `RankingPage`/`HallPage` reais e com o fluxo de mesa evoluído. 82 commits fora de A. |
| **C** | `claude/kit-pioneiros-2026-1b56ed` | 42 | Folha órfã. Domínio de coleções + 10 artes. **Zero UI.** |
| **D** | `claude/buraco-c10-parte-2-5eb70e` | 54 | Motor canônico de regra ligado dentro de `mesa.dart`. 68 commits fora de A. |
| **E** | `integracao/motores-torneios-partidas-v1` | 62 | Motor de sessão de partida. |
| **F** | `correcao/assets-loja-v1` | 94 | **Única** que contém as 46 artes de `assets/loja/`. |
| **G** | `consolidacao/apk-geral-bmv` | 34 | Base autorizada. |

Contenção medida com `git rev-list --count <folha> --not A`:

```text
claude/identidade-sessao-canonica-flutter          0   (A já contém)
homologacao/p0-final-integrada                     1
claude/spectator-view-server-enforcement-c154ee    1
claude/ws-auth-identidade-1fc213                   2
homologacao/play-billing-comercial                 2
feat/economia-boas-vindas-vitorias                 4
homologacao/billing-vip-comercial                  4
claude/busca-apelido-descoberta-social-b56465      5
feat/play-billing-aab-interno                      5
correcao/assets-loja-v1                            7
claude/runner-sandbox-cleanup-c0461a               9
integracao/motores-torneios-partidas-v1           11
claude/kit-pioneiros-2026-1b56ed                  19
claude/buraco-c10-parte-2-5eb70e                  68
integracao/ranking-ligas-hall                     82
```

---

## 3. METODOLOGIA

O censo não confiou em árvore de arquivos. Cruzou:

- **Grafo de imports real** — para cada arquivo de `screens/` e `pages/`,
  quem o referencia, com casamento de caminho exato.
  *(A primeira varredura, por substring, escondeu dois órfãos:
  `configurar_mesa_screen.dart` contém a cadeia `mesa_screen.dart`. Corrigido.)*
- **Navegação** — todo `MaterialPageRoute`, `PageRouteBuilder`, `pushReplacement`
  e o `home:` do `MaterialApp`.
- **Fonte de dados por tela** — `VM.mock()` × repositório real × serviço honesto
  de "sem fonte".
- **Consumo de domínio** — quais pacotes de `lib/` têm algum consumidor de UI.
- **Assets** — cada `assets/**` citado no código conferido contra o disco, por
  linhagem, e contra o `pubspec.yaml`.
- **Compilação** — `flutter analyze` na linhagem A.
- **Testes** — suítes de A e de B executadas de verdade.

### 3.1 Evidência de execução

```text
Flutter 3.41.4 • stable • revision ff37bef603

flutter analyze (linhagem A)         42 issues, 0 errors        (17,2 s)
flutter test    (linhagem A)         411 passed, 4 load-fail
  └─ as 4 falhas são o overlay de seeds do CI (`test/torneios/data/`).
     Reproduzindo o overlay a partir de `app/data/`:
     flutter test test/torneios/ test/colecoes/   ->  376 passed, 0 falhas
flutter test    (linhagem B)         135 passed, 1 load-fail (mesmo overlay)
```

> **Achado de build, não de tela.** A linhagem B **não tem `pubspec.yaml`**.
> Foi preciso copiar o de A para conseguir rodar seus 10 arquivos de teste de
> widget. A branch que detém a UI de Ranking/Hall e a melhor cobertura de teste
> de tela do projeto **não é construível isoladamente**.

---

## 4. REGRA DE CONTAGEM

**Conta como tela** o destino navegacional ou estado principal independente
percebido pelo usuário.

**Não conta como tela**: dialog, bottom sheet, menu, snackbar, tooltip, overlay,
zoom, card, componente reutilizável, aba interna sem navegação própria, e os
estados loading/error/empty da mesma tela. Todos inventariados na seção 8.

**Rota parametrizada é uma tela.** `PerfilPage(ehMeuPerfil: true|false)` conta
uma vez.

**Código morto não entra na contagem principal.** As 6 telas órfãs estão na
seção 10.

**Sobre as 7 telas de torneio.** `torneios_screens.dart` declara sete destinos
com `Navigator.push` próprio, título próprio e `onVoltar` próprio — Central,
Detalhes, Sala de Espera, Classificação, Resultado, Admin e Modelo. São sete
telas pela regra, ainda que todas partilhem o mesmo mock. Não inflam o
resultado: as sete estão classificadas 🔴.

---

## 5. TOTAL DE TELAS

```text
TELAS ATIVAS TOTAIS: 27

🟢 Prontas:                          2
🟡 Quase prontas:                    6
🟠 Implementadas/não homologadas:    3
🔴 Incompletas/placeholders:        16
                                   ---
                        soma:       27   ✓ fecha

⚫ Telas órfãs/mortas:                6   (fora da contagem principal)

SUPERFÍCIES AUXILIARES:             23   (+ 42 pontos de snackbar)

Fluxos críticos (7):
  PASS:         1
  PARCIAL:      2
  FAIL:         4
  INEXISTENTES: 0
```

---

## 6. CLASSIFICAÇÃO COMPLETA

| Estado | Telas |
| --- | --- |
| 🟢 **Pronta** | T001 Splash Oficial · T019 Excluir Conta |
| 🟡 **Quase pronta** | T003 Onde Jogar · T009 Mesa de Jogo · T010 Resultado da Partida · T014 Perfil · T018 Configurações · T020 Como Jogar |
| 🟠 **Implementada, não homologada** | T005 Jogar Online · T006 Configurar Mesa · T007 Mesa Privada Social |
| 🔴 **Incompleta / placeholder** | T002 Início · T004 Saguão · T008 Preparando Partida · T011 Ranking · T012 Hall da Imortalidade · T013 Amigos · T015 Loja · T016 Loja — Categoria · T017 Recompensas · T021–T027 Torneios (7 telas) |

**Critério aplicado para separar 🟡 de 🔴 em telas com mock.**
Se o conteúdo é estático por natureza (menu de opções, tutorial), o mock é
configuração legítima → 🟡. Se o conteúdo deveria ser dado vivo (jogadores,
ranking, itens de loja, recompensas, pareamento) e é mock → 🔴.

---

## 7. MATRIZ PRINCIPAL

Coluna **Linh.** = linhagem de onde a evidência foi lida (§2.1).

| ID | Domínio | Tela | Arquivo/componente | Linh. | Entrada (origem → ação) | Backend | Estado | Pendência | Sev. |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| T001 | Entrada | Splash Oficial | `screens/splash_oficial_screen.dart` | A | `MaterialApp.home` (raiz) | — | 🟢 | — | — |
| T002 | Home | Início | `screens/inicio_screen.dart` + `_InicioPreviewHost` | A | Splash → auto | nenhum | 🔴 | `InicioVM.mock()` com **dados pessoais fixos** ("Sônia Rainha", e-mail real, 1000 moedas, liga Diamante). `onHistorico` é snackbar. | **P0** |
| T003 | Home | Onde Jogar | `screens/onde_jogar_screen.dart` | A | Início → "Jogar" | nenhum | 🟡 | `OndeJogarVM.mock()`, mas é menu estático e roteia certo. | P2 |
| T004 | Home | Saguão | `screens/saguao_screen.dart` | A | Início → menu → Lobby | nenhum | 🔴 | `SaguaoVM.mock(ehVip: true)` — **VIP ligado à força**. Presentear, convidar, assistir e entrar por código são snackbars. | P1 |
| T005 | Mesa | Jogar Online (lobby por código) | `_OnlineLobbyHost` (`main.dart:1362`) | A | Onde Jogar → "Privada" | **WebSocket Railway** (`services/online_service.dart`) | 🟠 | Conexão real e nunca exercitada ponta a ponta. O próprio comentário diz que renderizar a partida do servidor "é a próxima fatia (A2)". | P1 |
| T006 | Mesa | Configurar Mesa | `screens/configurar_mesa_screen.dart` (+ `mesa_config_contract/validator`, `mesa_flow_*` em B) | A+B | Onde Jogar → Pública/VIP/Privada | nenhum | 🟠 | Em A é `ConfigMesaVM.mock()`. Em B há contrato, validador, plano de fluxo e **8 arquivos de teste** — mas B não está composta. | P1 |
| T007 | Mesa | Mesa Privada — Social | `screens/mesa_privada_social.dart` | B | Configurar Mesa (privada) | nenhum | 🟠 | Existe só em B, com teste de contrato. Não composta. | P1 |
| T008 | Mesa | Preparando Partida | `screens/preparando_partida_screen.dart` | A | Configurar Mesa → confirmar | nenhum | 🔴 | `PreparandoPartidaVM.mock()` — adversários falsos no pareamento. `_AnuncioPlaceholder` ocupa o slot de anúncio. | P1 |
| T009 | Mesa | Mesa de Jogo | `mesa.dart` → `class MesaScreen` (3434 linhas) | A / D | Onde Jogar → "Treino"; Como Jogar → "Jogar treino" | local (`class Jogo`) | 🟡 | **É o coração real e jogável** contra 3 robôs. Sem autoridade de servidor. O motor canônico de regra só existe em D. 5 avisos de código morto no analyze. | P1 |
| T010 | Mesa | Resultado da Partida | `screens/resultado_partida_screen.dart` | A | `mesa.dart:3407` ao encerrar | local | 🟡 | Alimentado por dado real da partida. **Nada persiste**: não credita fichas, não pontua ranking, não grava histórico. | P1 |
| T011 | Ranking | Ranking | `screens/ranking_screen.dart` · `pages/ranking_page.dart` (B) | A / B | Início → Ranking; nav inferior | **`functions-ranking` existe em A** | 🔴 | Em A: `RankingVM.mock()`. Em B: `RankingPage` honesta com `RankingSemFonte` → *"O ranking oficial ainda não está sendo publicado."* **Nenhuma branch do repositório tem um `RankingService` ligado a Firestore/Functions** (varredura em 87 branches). | **P0** |
| T012 | Ranking | Hall da Imortalidade | `screens/hall_screen.dart` · `pages/hall_page.dart` (B) | A / B | Início → Hall | nenhum ligado | 🔴 | `HallVM.mock()` em A; `HallSemFonte` em B. "Estatísticas" e "Presentes" são snackbars *"integração fica com o Claude"*. | P1 |
| T013 | Social | Amigos | `screens/amigos_screen.dart` | A | Início → menu → Amigos | **`lib/social/` + `functions-social` existem** | 🔴 | 100% `AmigosVM.mock()`. Pedido, aceite, recusa, convite, assistir e opções são snackbars — vários dizem *"vira real com o Firestore — Fase B"*. O domínio social não tem **nenhum** consumidor de UI. | **P0** |
| T014 | Perfil | Perfil | `pages/perfil_page.dart` + `screens/perfil_screen.dart` | A | Início → Perfil; nav inferior | Firebase Auth + identidade pública | 🟡 | Identidade real (nome e `publicId`). **Números são demonstração**: `PerfilService.statsDemo = true` → nível 24, 3240 XP, "Rainha da Canastra". | P1 |
| T015 | Loja | Loja | `screens/loja_screen.dart` + `loja_vip_adaptador.dart` | A | Início → Loja; nav inferior | **Play Billing + entitlement reais** | 🔴 | A fatia VIP é real (`ServicoBilling`, `EntitlementRepositorio`, 8 estados de compra). Todo o resto é `LojaVM.mock()`: comprar cosmético, comprar moedas e presentear são snackbars. **46 artes ausentes.** | **P0** |
| T016 | Loja | Loja — Categoria | `screens/loja_categoria_screen.dart` | A | Loja → categoria | nenhum | 🔴 | `LojaCategoriaVM.mock()`. Referencia as 46 artes ausentes. Sem ampliação ao toque (§9). | **P0** |
| T017 | Recompensas | Recompensas | `screens/recompensas_screen.dart` | A | Início → menu → Recompensas | nenhum | 🔴 | `RecompensasVM.mock()`. Resgatar missão, login diário e Baú Real são snackbars *"resgate fica com o Claude"*. | P1 |
| T018 | Conta | Configurações | `screens/configuracoes_screen.dart` | A | Início → menu → Ajustes | **SharedPreferences (real)** | 🟡 | Persiste de verdade. Mas Bloqueados, Suporte, **Termos e privacidade** e Avaliar são *"em breve"*. | P1 |
| T019 | Conta | Excluir Conta | `screens/excluir_conta_screen.dart` + `conta/` | A | Configurações → Excluir conta | **`functions-conta` (real)** | 🟢 | — | — |
| T020 | Conta | Como Jogar | `screens/como_jogar_screen.dart` | A | Início → menu → Tutorial; Configurações → Regras | — | 🟡 | Conteúdo completo (passos, canastras, modalidades, tabela de pontos). Abre o treino real, mas antes mostra o snackbar de desenvolvimento *"criação real fica com o Claude"*. | P2 |
| T021 | Torneios | Central de Torneios | `screens/torneios_screens.dart` → `CentralTorneiosScreen` | A | Início → banner de temporada | **`lib/torneios/` completo** | 🔴 | `TorneiosMockData.cards()`. Expõe **`mostrarAdmin: true`** e um bottom sheet **"Cenários mock"** na UI de produção. | **P0** |
| T022 | Torneios | Torneio — Detalhes | `TorneioDetalhesScreen` | A | Central → card | domínio pronto | 🔴 | Mock. Inscrever/cancelar são toasts. | P1 |
| T023 | Torneios | Torneio — Sala de Espera | `SalaEsperaTorneioScreen` | A | Detalhes → check-in | domínio pronto | 🔴 | Mock. Check-in é toast. | P1 |
| T024 | Torneios | Torneio — Classificação | `ClassificacaoTorneioScreen` | A | Central/Detalhes → classificação | domínio pronto | 🔴 | Mock. | P1 |
| T025 | Torneios | Torneio — Resultado | `ResultadoTorneioScreen` | A | Central → resultado | domínio pronto | 🔴 | Mock. Resgatar prêmio e compartilhar são toasts. | P1 |
| T026 | Torneios | Torneio — Admin | `AdminTorneiosScreen` | A | Central → Admin | domínio pronto | 🔴 | **Sem qualquer verificação de papel.** Ações administrativas são toasts. | **P0** |
| T027 | Torneios | Torneio — Modelo (criar/editar) | `screens/torneio_modelo_screen.dart` | A | Central → criar/editar modelo | domínio pronto | 🔴 | Mock. `onSalvarModelo` é toast *"pronto para persistência"*. | P1 |

Todas as 27 telas contadas aparecem individualmente. Nenhuma entrou só no total.

---

## 8. SUPERFÍCIES AUXILIARES

Contagem separada, para não chamar tudo de "tela" nem deixar sumir parte da UX.

| Tipo | Qtd. | Observação |
| --- | --: | --- |
| Bottom sheets (chamadas ativas) | 14 | +2 em tela órfã, não contadas |
| Diálogos (`AlertDialog`) | 5 | "Sair da conta?", confirmação de torneio, regras e presentes do Hall |
| Tooltips | 2 | |
| Celebração de vitória | 1 | `screens/vitoria_celebracao.dart` — só na linhagem B |
| Faixa de torneio na mesa | 1 | `FaixaTorneioMesa` |
| **Total de superfícies auxiliares** | **23** | |
| Pontos de snackbar | 42 | contados à parte; a maioria é ação-stub |

### Modais nomeados

`_ModalRegrasHall` · `_ModalPresentesHall` · `_CompraSheet` (Loja) ·
`_PresenteSheet` (Loja) · `_CompraSheet` (Loja Categoria) · `_PresenteSheet`
(Loja Categoria) · `InscricaoTorneioModal` · `_ModalAlert` (Torneios) ·
sheet de Convite VIP (`widgets/convite_vip.dart`) · sheet de Configurações ·
sheet do Saguão · sheet do Perfil · **sheet "Cenários mock"**.

> O último não deveria existir num aplicativo publicado. É um seletor de
> cenários de desenvolvimento acessível pela Central de Torneios.

---

## 9. MATRIZ DE FLUXOS

| Fluxo | Passos esperados | Passos existentes | Resultado | Onde quebra |
| --- | --- | --- | --- | --- |
| **1 · Novo usuário** | instalação → cadastro/auth → identidade → bônus inicial → home → jogo | 2 de 6 | **FAIL** | **No passo 2.** Não existe tela de login alcançável. O app vai do Splash direto à Home com identidade mockada. O formulário de Google Sign-In existe em `HomeScreen` (`main.dart:1851`), órfã. |
| **2 · Jogador casual** | Home → Mesa Pública → config/pareamento → partida → resultado → fichas | 5 de 6 | **PARCIAL** | **No passo 6.** A partida local contra robôs funciona ponta a ponta e o resultado aparece. Nada credita fichas: a economia é a folha `feat/economia-boas-vindas-vitorias`, não composta, e `resultado_partida_screen` não persiste nada. |
| **3 · Competitivo/VIP** | Home → VIP/Ranqueada → elegibilidade → mesa → resultado → ranking/liga/temporada | 3 de 6 | **FAIL** | **No passo 6, e antes dele.** Não há mesa ranqueada distinta. O Ranking não tem fonte em nenhuma branch (`RankingSemFonte`). Sem fórmula registrada, nada pontua. |
| **4 · Compra VIP** | oferta → plano → Google Play → processamento → confirmação backend → entitlement → UI VIP | 7 de 7 em código | **PARCIAL** | **Fora do código.** A cadeia é real e honesta (`ServicoBilling` → `validacao_firebase` → `EntitlementRepositorio.observar(uid)`), incluindo `aguardandoRevalidacao`. Nunca exercitada ponta a ponta; depende de Play Console e do RTDN não ativado. |
| **5 · Loja** | Loja → categoria → inspeção ampliada → item → aquisição/equipar → Perfil reflete | 2 de 6 | **FAIL** | **No passo 3.** A ampliação temporária ao toque **não existe em nenhuma branch** (§12.1). Comprar cosmético é snackbar, não há equipar, o Perfil não reflete, e as 46 artes estão ausentes na linhagem principal. |
| **6 · Social** | busca/descoberta → perfil público → amizade → estado resultante | 1 de 4 | **FAIL** | **No passo 1.** `amigos_screen` é 100% mock. `lib/social/` e `functions-social` existem e **nenhuma tela os consome**. Não há rota que abra o perfil público de outro jogador. |
| **7 · Conta** | Configurações → conta → exclusão → confirmação → comportamento posterior | 5 de 5 | **PASS** | — |

---

## 10. TELAS ÓRFÃS / MORTAS

Fora da contagem principal. Verificado por casamento de caminho exato em `lib/`
e `test/`.

| # | Arquivo / classe | Linhas | Situação |
| --- | --- | --: | --- |
| O1 | `screens/mesa_screen.dart` → `class MesaScreen` | 1581 | **Colisão de nome com a mesa real.** `mesa.dart:1331` também declara `MesaScreen`. `main.dart` importa só `mesa.dart` — a mesa jogável vence. Este arquivo é a maquete visual do Codex, substituída, e **nada o referencia**. O analyze confirma (`painelEscuro` não usado). |
| O2 | `screens/mesa_vip_preview_screen.dart` | 1015 | Zero referências em A e em B. Guarda 2 bottom sheets. É a única razão pela qual `assets/mesa_vip/` está no `pubspec.yaml`. |
| O3 | `main.dart` → `class HomeScreen` | ~370 | **Contém o único login do aplicativo** (Google Sign-In, card de perfil, banner de boas-vindas, logout). Nada a referencia. |
| O4 | `main.dart` → `class SplashScreen` | ~115 | Splash de partículas, substituída por `SplashOficialScreen`. É quem referencia `assets/splash.jpg`, arquivo ausente. |
| O5 | `lib/app/lib/screens/amigos_screen.dart` | 773 | **Duplicata aninhada byte a byte** de `lib/screens/amigos_screen.dart` (`diff` sem diferenças). Caminho inalcançável por import relativo. |
| O6 | `lib/app/lib/widgets/convite_vip.dart` | — | Mesma duplicação aninhada. |

**Rotas mortas:** nenhuma. O aplicativo não usa rotas nomeadas — toda navegação
é `MaterialPageRoute` direto, então não há entrada de rota sem destino.

---

## 11. TELAS FALTANTES

> Considerando o que o produto já promete e os backends já implementados, há
> alguma tela necessária que ainda não existe?

**Sim — dez.**

| # | Tela sugerida | Por quê | Fluxo dependente | Backend | Prior. |
| --- | --- | --- | --- | --- | --- |
| F1 | **Login / Entrada** | O app não tem porta de entrada. Sem ela, tudo que depende de `uid` (VIP, exclusão, identidade, social) só funciona por acidente. | 1, 3, 4, 6 | **Existe** (Firebase Auth). O código de UI existe na órfã O3. | **P0** |
| F2 | **Termos e Privacidade** | Exigência da Google Play. Hoje é *"em breve"*. | 7, publicação | Só precisa de conteúdo e URL | **P0** |
| F3 | **Denúncia** | Exigência da Play para app com interação social. | 6 | **Existe** (`lib/moderacao/denuncia.dart` + `functions-moderacao`) | **P0** |
| F4 | **Jogadores bloqueados** | Hoje é *"em breve"* nas Configurações. | 6, 7 | **Existe** (`moderacao/relacao_social.dart`) | P1 |
| F5 | **Coleções / Inventário (Kit Pioneiro)** | 2678 linhas de domínio e 10 artes entregues, **sem uma única tela**. Há até um `colecao_ui_contract.dart` esperando consumidor. | 5 | **Existe** (linhagens A e C) | P1 |
| F6 | **Busca de jogadores / Descoberta** | A folha de busca por apelido foi entregue e nada a consome. | 6 | **Existe** (`functions-social`, `apelidoOrdenacao`) | P1 |
| F7 | **Perfil público de outro jogador** | `PerfilPage(ehMeuPerfil: false)` já sabe se desenhar; nenhuma rota chega nele. | 6 | **Existe** (identidade pública) | P1 |
| F8 | **Inspeção ampliada de item (zoom ao toque)** | Requisito aprovado da Loja e do Perfil. Não existe em nenhuma branch. | 5 | Não precisa | P1 |
| F9 | **Onboarding / escolha de identidade pública** | O `publicId` é gerado sem que a pessoa participe. | 1 | **Existe** | P1 |
| F10 | **Suporte** | *"em breve"*. | 7 | Não existe | P2 |

---

## 12. PROBLEMAS VISUAIS

Nenhuma tela foi redesenhada. Registro apenas o que impede fechamento.

### Bloqueadores

| # | Problema | Evidência |
| --- | --- | --- |
| V1 | **46 artes da Loja referenciadas e ausentes** na linhagem principal. Molduras, dorsos, avatares, mascotes, emojis e efeitos renderizariam quebrados. | Conferência arquivo a arquivo: 47 ausências em A, B e G; **1** em F. |
| V2 | **Dados pessoais reais fixos na Home** — nome, e-mail, moedas e liga de uma pessoa específica visíveis para qualquer usuário. | `screens/inicio_screen.dart:78` |
| V3 | **Bottom sheet "Cenários mock"** exposto na Central de Torneios. | `pages/torneios_preview_page.dart` |
| V4 | **Tela de Admin de Torneios sem verificação de papel.** | `mostrarAdmin: true` em `torneios_preview_page.dart` |

### Importantes

| # | Problema | Evidência |
| --- | --- | --- |
| V5 | `assets/splash.jpg` referenciado e ausente — hoje inócuo porque só a splash órfã O4 o usa. Deixa de ser inócuo se alguém reativar a classe. | `main.dart:221` |
| V6 | Slot de anúncio com `_AnuncioPlaceholder` visível no Preparando Partida. | `preparando_partida_screen.dart:1034` |
| V7 | Quatro itens *"em breve"* nas Configurações, um deles exigido pela Play. | `main.dart:934-938` |
| V8 | `assets/mesa_vip/` só é usado pela tela órfã O2 — peso morto no bundle. | `pubspec.yaml` |

### Cosméticos

| # | Problema |
| --- | --- |
| V9 | 42 issues no analyze: 5 declarações mortas em `mesa.dart`, campos não usados em `configurar_mesa_screen`, `mesa_screen`, `saguao_screen`, `splash_oficial_screen`, `mesa_vip_preview_screen`. |
| V10 | ~20 usos de `withOpacity` depreciado; `activeColor`, `groupValue` e `value` depreciados nas telas de torneio. |
| V11 | Snackbar de desenvolvimento *"criação real fica com o Claude"* aparece ao iniciar o treino pelo Como Jogar. |

> **Responsividade não é ponto fraco.** A linhagem B tem testes de superfície de
> telefone que passam (`mesa_orientacao_runtime_test`,
> `ranking_regressao_visual_test`, "telefone comum (390x844)"). Nenhum overflow
> detectado nas suítes executadas.

### 12.1 Busca da ampliação ao toque — prova de ausência

Varredura por `InteractiveViewer|onLongPress|ampliar|Ampliar|ampliacao|ampliação`
em `app/lib/screens/*` e `app/lib/pages/*` nas **91 branches locais** (contagem no
momento da varredura; 92 depois de criada a branch desta auditoria). Os únicos
resultados são `torneios_models.dart` e `torneios_screens.dart` — nenhum na Loja
nem no Perfil. **O requisito aprovado não existe no repositório.**

---

## 13. PROBLEMAS FUNCIONAIS

| # | Problema | Impacto |
| --- | --- | --- |
| FN1 | Não há login alcançável. | Todo o produto opera sem identidade real. |
| FN2 | Dez telas alimentadas por `VM.mock()`. | O menu inteiro é maquete. |
| FN3 | O resultado da partida não persiste nada. | Jogar não muda o estado do jogador. |
| FN4 | O Saguão liga VIP à força (`SaguaoVM.mock(ehVip: true)`). | Contradiz o enforcement de VIP entregue. |
| FN5 | Admin de torneios sem controle de acesso. | Qualquer pessoa abre. |
| FN6 | `lib/rastreabilidade/` não tem **nenhum** consumidor no aplicativo. | Camada inteira sem uso. |
| FN7 | O Motor C (`MotorPartida`) não é usado pela mesa jogável — só por `integracao/registro_partidas.dart`. | A mesa jogada não passa pelo motor de sessão. |
| FN8 | Cobertura de teste de tela desequilibrada: 3 arquivos com `testWidgets` em A, 10 em B. | A linhagem mais profunda é a menos testada visualmente. |

---

## 14. INTEGRAÇÕES AUSENTES

### 14.1 Backend pronto, tela faltante ou desligada

| Backend | Onde vive | Situação da UI |
| --- | --- | --- |
| `functions-ranking` | linhagem A | Nenhum `RankingService` ligado a Firestore em **nenhuma** branch. A UI usa `RankingSemFonte`. |
| `lib/colecoes/` + `functions-social` (coleções) | A, C | **Zero telas.** Existe `colecao_ui_contract.dart` sem consumidor. |
| `lib/moderacao/` + `functions-moderacao` | A | **Zero telas.** Consumido só por `elegibilidade/` e `social/`. |
| `lib/social/` + `functions-social` | A | **Zero telas.** Consumido só por `sessao/fonte_identidade_firebase.dart`. |
| `lib/rastreabilidade/` | A | **Zero consumidores**, de UI ou de qualquer outra camada. |
| `lib/torneios/` (motor completo) | A | 7 telas existem, todas em `TorneiosMockData`. |

### 14.2 Tela pronta, backend faltante

Ranking, Hall, Amigos, Saguão, Recompensas, Início, Preparando Partida,
cosméticos da Loja, e as 7 telas de torneio.

### 14.3 Existem os dois lados, mas não estão conectados

| Caso | Ponta A | Ponta B | Falta |
| --- | --- | --- | --- |
| Ranking | `functions-ranking` (linhagem A) | `RankingPage` (linhagem B) | **Estão em branches diferentes.** Nem a composição resolve sozinha: falta um `RankingService` de Firestore, que não existe em lugar nenhum (varredura por `class Ranking(Firebase\|Firestore\|Remoto\|Oficial)` em todas as branches: zero resultados). |
| Loja | 46 artes (linhagem F) | `loja_categoria_screen` (todas) | Composição da linhagem F. |
| Coleções | domínio + artes (A, C) | — | A tela. |
| Motor canônico | `mesa.dart` reescrito (D) | mesa jogável (A) | Composição da linhagem D. |

### 14.4 Implementado em branch isolada

Para não classificar como inexistente o que já foi produzido:
`integracao/ranking-ligas-hall` (Ranking, Hall, fluxo de mesa, 10 testes de
widget) · `correcao/assets-loja-v1` (46 artes) ·
`claude/buraco-c10-parte-2-5eb70e` (motor canônico) ·
`claude/kit-pioneiros-2026-1b56ed` (coleções) ·
`feat/economia-boas-vindas-vitorias` (economia) ·
`claude/busca-apelido-descoberta-social-b56465` (descoberta social).

---

## 15. PENDÊNCIAS

### P0 — bloqueador de lançamento

1. **Não existe tela de login alcançável** (F1 / O3).
2. **Home exibe dados pessoais reais fixos** (V2).
3. **46 artes da Loja ausentes** na linhagem principal (V1).
4. **Ranking sem fonte em qualquer branch** (T011).
5. **Admin de Torneios acessível a qualquer usuário** (V4).
6. **Bottom sheet "Cenários mock" exposto** (V3).
7. **Termos e Privacidade inexistentes** (F2) — exigência da Play.
8. **Sem tela de denúncia** (F3) — exigência da Play para app social.
9. **O produto não existe em uma única branch** — não há artefato a publicar.

### P1 — importante antes do lançamento

10. Substituir os dez `VM.mock()` por fontes reais.
11. Ligar o resultado da partida à economia (fichas) e ao ranking.
12. Telas de Coleções/Inventário (F5), Bloqueados (F4), Descoberta (F6),
    Perfil público (F7), Onboarding (F9).
13. Ampliação ao toque na Loja e no Perfil (F8).
14. Trocar `PerfilService.statsDemo = true` por números reais.
15. Ligar as 7 telas de torneio ao motor já pronto.
16. Corrigir `SaguaoVM.mock(ehVip: true)`.
17. Homologar ponta a ponta o Jogar Online (fatia A2) e a compra VIP.
18. Dar `pubspec.yaml` à linhagem B, ou compô-la.

### P2 — acabamento

19. Remover as 6 telas órfãs (~3800 linhas) e a duplicata aninhada.
20. Resolver os 42 issues do analyze e as APIs depreciadas.
21. Remover o snackbar de desenvolvimento do Como Jogar (V11).
22. Tirar `assets/mesa_vip/` do bundle se O2 for removida.
23. Tela de Suporte (F10).
24. Ajustar os 4 arquivos de teste que dependem do overlay de seeds do CI.

---

## 16. RECOMENDAÇÃO DE PRÓXIMA SEQUÊNCIA

A ordem abaixo é deliberada: **não adianta corrigir tela antes de existir um
alvo único onde a correção valha.**

1. **OS de Composição da RC V1.** Sem isso, todo conserto acontece numa branch
   que talvez não entre. Usar a ordem já proposta no manifesto, e incluir
   `correcao/assets-loja-v1` (as 46 artes) e a linhagem de exclusão de conta,
   que hoje estão fora das 13 folhas.
2. **OS de Casca de Produção.** Trocar a bancada de prévias por uma casca real:
   ressuscitar o login de `HomeScreen`, criar o gate de autenticação, e apagar
   `InicioVM.mock()`. Resolve P0 1 e 2.
3. **OS de Conformidade Play.** Termos, denúncia, bloqueados, e remoção do Admin
   e do sheet de cenários mock da UI. Resolve P0 5, 6, 7, 8.
4. **OS de Fonte de Dados.** Um `RankingService` de Firestore ligando
   `functions-ranking` à `RankingPage`, e a substituição dos mocks restantes.
   Depende da fórmula de ranking, que continua pendente de decisão.
5. **OS de Economia e Persistência.** Fechar o Fluxo 2: resultado → fichas.
6. **OS de Telas Faltantes.** Coleções, descoberta, perfil público, zoom.
7. **OS de Limpeza.** Órfãs, duplicata aninhada, analyze.

---

## 17. ENTREGA EXECUTIVA

### 1 · Quantas telas ativas o Buraco Master VIP possui hoje?

**27 telas ativas**, mais 6 órfãs fora da contagem.

### 2 · Quantas estão realmente prontas para lançamento?

**2** — Splash Oficial e Excluir Conta.

### 3 · Qual percentual de prontidão por telas?

```text
Prontidão real:            2 / 27  =   7,4 %
Cobertura visual/funcional
avançada (🟢 + 🟡):        8 / 27  =  29,6 %
```

O segundo número **não** significa telas prontas. Significa telas cuja pendência
é localizada e conhecida.

### 4 · Quantas superfícies auxiliares existem?

**23**, mais 42 pontos de snackbar contados à parte.

### 5 · Quais telas ainda impedem considerar o aplicativo fechado?

A ausente **Login**; **Início** (dados pessoais fixos); **Loja** e **Loja —
Categoria** (46 artes ausentes, compra que não compra); **Ranking** (sem fonte);
**Amigos** (social 100% mock); **Torneio — Admin** e **Central de Torneios**
(admin aberto e sheet de cenários mock); e as ausentes **Termos** e **Denúncia**.

### 6 · Há funcionalidades backend já prontas sem UI correspondente?

**Sim, seis:** `functions-ranking`, coleções (Kit Pioneiro), moderação, grafo
social, rastreabilidade (sem consumidor algum) e o motor de torneios.

### 7 · Há UI aparentemente pronta apoiada em mock ou backend inexistente?

**Sim, dezesseis telas.** Todo o menu principal, o Saguão, as Recompensas, os
cosméticos da Loja e as 7 telas de torneio.

### 8 · Há telas prontas em branches isoladas que precisam entrar na composição?

**Sim.** `integracao/ranking-ligas-hall` traz `RankingPage`, `HallPage`, o fluxo
de mesa evoluído e 10 arquivos de teste de widget — 82 commits fora da linhagem
principal. `correcao/assets-loja-v1` traz as 46 artes. `claude/buraco-c10-parte-2`
traz o motor canônico. `claude/kit-pioneiros-2026` traz o domínio de coleções.

### 9 · Quais são os próximos trabalhos, em ordem?

Ver seção 16. Em uma linha: **compor a RC → construir a casca de produção →
conformidade Play → ligar as fontes de dados → economia → telas faltantes →
limpeza.**

---

## 18. O QUE ESTA OS NÃO FEZ

```text
correção de tela:                              NÃO
implementação de funcionalidade:               NÃO
merge / rebase / cherry-pick:                  NÃO
push em main ou consolidacao:                  NÃO
deploy / AAB / Play Console / Firebase:        NÃO
alteração de banco / VIP / migração:           NÃO
```

O overlay de seeds e o `pubspec.yaml` copiado para a linhagem B existiram apenas
no diretório temporário desta sessão, para permitir executar as suítes. Nada
disso foi versionado.
