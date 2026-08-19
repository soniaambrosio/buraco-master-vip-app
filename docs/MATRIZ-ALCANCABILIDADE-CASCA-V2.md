# Matriz de alcançabilidade — Casca V2 como raiz da composição canônica

> Produzida **antes** de resolver os seis conflitos Flutter do merge da
> moderação, por exigência da OS de composição canônica das Functions.
>
> **Decisão da proprietária:** a composição adota a Casca V2 como raiz do
> aplicativo. `main.dart` fica no modelo de bootstrap mínimo; os hosts de prévia
> do `main.dart` antigo **não** ressuscitam; nenhuma tela de catálogo vira
> produção só para resolver conflito.

---

## 1. As duas raízes em disputa

| | `main.dart` do HEAD | `main.dart` da Casca V2 |
|---|---|---|
| linhas | 2.172 | 58 |
| o que faz | inicializa Firebase **e** hospeda 15 prévias, uma `SplashScreen` antiga e uma `HomeScreen` com o segundo `authStateChanges` do app | inicializa binding e Firebase, e entrega a `RaizDoAplicativo` |
| quem decide a tela | o próprio `main.dart` | `casca/casca_de_producao.dart` |
| quem monta sessão/transporte | `main.dart` | `casca/raiz_do_aplicativo.dart` |

A Casca V2 vence por decisão. O que segue é o mapa do que isso custa e do que
precisa ser costurado.

## 2. O que a Casca V2 alcança hoje

`LoginDeProducao` → `HomeDeProducao` → { `OndeJogarDeProducao` → `LobbyOnline` →
`MesaOnlineScreen` · `PerfilPage` · `ConfiguracoesDeProducao` → `ConfiguracoesScreen`
→ `ComoJogarScreen` } · `MesaScreen` (partida local) · `InicioScreen`.

## 3. A matriz

Legenda de classificação:

- **alcançável** — tem rota produtiva na Casca V2;
- **backend-only** — a autoridade é de servidor/Functions; não existe nem deve
  existir tela;
- **órfã/preview** — catálogo visual e material de teste, deliberadamente **não**
  produtiva;
- **COSTURAR** — superfície produtiva que só o HEAD tem e que precisa entrar.

| Superfície | No HEAD | Na Casca V2 | Rota produtiva final | Prova | Classificação |
|---|---|---|---|---|---|
| Login | via `main.dart` | `LoginDeProducao` | raiz → login | suíte da casca | **alcançável** |
| Home | `HomeScreen` (2º `authStateChanges`) | `HomeDeProducao` | raiz → home | suíte da casca | **alcançável** (a `HomeScreen` do HEAD é **órfã**: referenciada só pelo `main.dart` antigo) |
| Onde jogar / Lobby / Mesa online | `OndeJogarScreen` | `OndeJogarDeProducao` → `LobbyOnline` → `MesaOnlineScreen` | home → onde jogar → lobby → mesa | `mesa_online/` + suítes | **alcançável** |
| Mesa local | `MesaScreen` | `MesaScreen` (7 referências fora do main) | home → mesa | suítes de mesa | **alcançável** |
| Perfil | `PerfilPage` | `PerfilPage` | home → perfil | suíte de perfil | **alcançável** |
| Ranking | `RankingPage` | — | perfil/hall → `RankingPage` | `perfil_page.dart` e `hall_page.dart` referenciam | **alcançável por Perfil** |
| Configurações | `ConfiguracoesScreen` | `ConfiguracoesDeProducao` | home → configurações | suíte da casca | **alcançável** |
| Como jogar / regras | `ComoJogarScreen` | `ComoJogarScreen` | configurações → regras | suíte da casca | **alcançável** |
| **Excluir conta** | `ExcluirContaScreen` | **ausente** | configurações → excluir conta | §4 | **COSTURAR** |
| Loja / assinatura VIP | `LojaScreen`, `LojaCategoriaScreen`, `loja_vip_adaptador` | `_aviso('ainda não está disponível')` | — | §5 | **ver §5** |
| Passe VIP quinzenal | — | — | — | `functions-ranking` | **backend-only** |
| Billing / RTDN / propriedade da compra | serviços em `app/lib/billing/` | consumidos pela sessão | — | 324/324 em `functions-billing` | **backend-only** (a *venda* é a Loja, §5) |
| Chat livre | `app/lib/chat/` (porta, mensagem, superfície) | sem UI na mesa online | — | `functions-moderacao` + `chat.test.js` | **backend-only hoje** — a camada cliente existe, a superfície de mesa ainda não a consome |
| Moderação / bloqueio | — | `onBloqueados` → aviso | — | `functions-moderacao` | **backend-only** |
| Economia / moedas | — | `onMoedasCompras` → aviso | — | `functions-economia` | **backend-only** |
| Conquistas | — | — | — | `functions/` (torneios) | **backend-only** |
| Saguão, Recompensas, Amigos, Torneios, `PerfilScreen`, `InicioScreen` (host), Configurar Mesa, Preparando Partida | hosts de prévia no `main.dart` | — | — | referenciadas só pelo `main.dart` antigo, por `mesa_flow_preview_host` ou por testes | **órfã/preview** |

## 4. A costura obrigatória — Excluir conta

**Não é escolha de arquitetura: é quebra de compilação.**

`ConfiguracoesCallbacks` (do HEAD, linhagem de exclusão de conta) declara
`required this.onExcluirConta`. A `ConfiguracoesDeProducao` da Casca V2 constrói
esse objeto **sem** o campo — ela é anterior à exclusão de conta. Depois do merge,
a árvore não compila.

Some-se a isso que o caminho de exclusão em aplicativo é **exigência da Play**, e
que a autoridade de servidor já entrou nesta composição (`functions-conta`, nono
codebase). Logo a costura é obrigatória e não abre decisão de produto: a
superfície existe, o backend existe, e a regra externa a exige.

Costura: `ConfiguracoesDeProducao` passa `onExcluirConta` empurrando
`ExcluirContaScreen`. Nada do roteamento antigo é recuperado.

## 5. Loja / assinatura VIP — **não costurada, e por quê**

A Casca V2 responde `_aviso('A assinatura VIP ainda não está disponível.')`, e o
comentário dela explica: *"não há autoridade de assinatura nem de economia
alcançável pelo cliente"*. Isso era verdade quando foi escrito.

Hoje a autoridade **existe** nesta composição (Billing, 324/324, com propriedade
opaca da compra). Ainda assim a Loja **não** é costurada nesta OS, e a razão não é
arquitetural:

> Abrir a Loja criaria uma superfície produtiva que **falha em tempo de
> execução**: o produto `master_vip` não existe na Play Console, e sem ele a
> compra não completa. Costurar aqui entregaria um botão que leva a um erro.

Classificação: **backend-only por ora**, com a autoridade pronta e a venda barrada
por pré-condição externa — não por falta de código. Ligar a Loja é decisão de
produto (e de Play Console), e por isso fica declarada aqui em vez de ser tomada
de contrabando dentro de um merge.

**Isto não dispara o STOP da OS**: a Loja não é superfície *necessária* para a
composição fechar, e a Casca já a trata explicitamente. O STOP existiria se ela
fosse necessária e impossível de costurar sem segunda autoridade de sessão — não
é o caso.

## 6. O que NÃO foi feito, de propósito

- Nenhum host de prévia virou rota produtiva.
- Nenhuma tela de catálogo foi promovida para resolver conflito.
- Nenhuma tela foi criada para superfície backend-only.
- O roteamento antigo do `main.dart` não foi recuperado em nenhum ponto.
