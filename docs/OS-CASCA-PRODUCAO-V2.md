# OS Casca real de produção, autenticação e roteamento — V2

Base: `origin/integracao/identidade-sessao-auth-producao-v2` @ `a0d33015f302aae2f2fc2ed5f853c8894f8af548`.

Este documento é a caracterização exigida pela §3.6 (grafo alcançável e
inventário) e §10 (relatório). O que ele registra é o estado do aplicativo
ANTES e DEPOIS — não o que se pretende fazer.

---

## 1. O que estava errado

`main()` inicializava o Firebase e abria
`SplashOficialScreen(proximaTela: _InicioPreviewHost)`. O `_InicioPreviewHost`
construía `InicioVM.mock()`, e o `mock` trazia, escritos no código-fonte e
embarcados em todo APK gerado:

| campo | valor no código |
|---|---|
| `nome` | o nome de perfil da dona do projeto |
| `email` | o e-mail pessoal dela |
| `moedas` | `1000` |
| `liga` | `Diamante` |

Qualquer pessoa que instalasse o aplicativo abria a Home e via aqueles dados
como se fossem os seus. A `SessaoDoJogador` estava montada corretamente acima
do `MaterialApp` — e não mandava em nada: nenhuma decisão de tela dependia
dela.

Além disso, `main.dart` tinha 2.172 linhas e hospedava quinze hosts de
pré-visualização, duas classes órfãs (uma delas com o segundo
`authStateChanges().listen` do aplicativo) e o caminho para todas as maquetes.

---

## 2. Grafo alcançável — ANTES

```
main()
└── BuracoApp  →  EscopoSessao(sessão canônica)  →  MaterialApp
    └── SplashOficialScreen(proximaTela: _InicioPreviewHost)
        └── _InicioPreviewHost  →  InicioScreen(vm: InicioVM.mock())      MOCK
            ├── perfil / nav perfil  →  PerfilPage                        REAL parcial
            │                            └── PerfilService.statsDemo=true MOCK
            ├── ranking / nav ranking →  _RankingPreviewHost              MOCK
            │                            └── _HallPreviewHost             MOCK
            ├── recompensas          →  _RecompensasPreviewHost           MOCK
            ├── amigos               →  _AmigosPreviewHost                MOCK
            ├── loja / nav loja      →  _LojaPreviewHost                  MOCK
            │                            └── _LojaCategoriaPreviewHost    MOCK
            ├── ajustes              →  _ConfiguracoesPreviewHost         REAL parcial
            │                            (lia FirebaseAuth.currentUser e
            │                             chamava signOut por conta própria)
            ├── tutorial             →  ComoJogarScreen  →  MesaScreen    REAL
            ├── jogar / botão JOGAR  →  _OndeJogarPreviewHost             MOCK
            │      ├── treino        →  MesaScreen (motor local)          REAL
            │      ├── privada       →  _OnlineLobbyHost                  REAL
            │      └── publica/vip   →  _ConfigMesaPreviewHost
            │                            →  PreparandoPartidaScreen
            │                            →  MesaScreen (partida LOCAL)    MAQUETE
            ├── banner temporada     →  TorneiosPreviewPage               MOCK
            └── banner lobby         →  _SaguaoPreviewHost                MOCK
```

## 3. Grafo alcançável — DEPOIS

```
main()                                    (57 linhas; só binding e Firebase)
└── RaizDoAplicativo
    ├── EscopoSessao          SessaoDoJogador           }  acima do
    ├── EscopoAutenticacao    AutenticacaoFirebase      }  MaterialApp,
    ├── EscopoTransporte      OnlineService + Ponte     }  fora da chave
    └── MaterialApp(key: geração da sessão)
        └── CascaDeProducao
            ├── sessão não resolvida        →  SplashOficialScreen        REAL
            │     └── teto estourado        →  estado explícito + retry   REAL
            ├── resolvida, sem sessão       →  LoginDeProducao            REAL
            │     └── sem provedor          →  estado terminal honesto    REAL
            └── resolvida, autenticada      →  HomeDeProducao             REAL
                ├── perfil / nav perfil     →  PerfilPage                 REAL
                ├── jogar                   →  OndeJogarDeProducao        REAL
                │     ├── treino            →  MesaScreen (motor local)   REAL
                │     ├── mesa por código   →  LobbyOnline                REAL
                │     └── pública / VIP     →  bloqueadas, com o motivo
                ├── tutorial                →  ComoJogarScreen            REAL
                ├── ajustes                 →  ConfiguracoesDeProducao    REAL
                │     ├── sair              →  comando canônico
                │     └── regras            →  ComoJogarScreen            REAL
                └── ranking / recompensas / amigos / loja
                                            →  apagados, com selo, e o
                                               toque avisa (não navega)
```

---

## 4. Inventário

### REAL — alcançável e honesto

| superfície | por que é real |
|---|---|
| `casca/raiz_do_aplicativo.dart` | monta os quatro objetos canônicos |
| `casca/casca_de_producao.dart` | decide a tela lendo a sessão |
| `casca/login_de_producao.dart` | só provedor que este build aciona |
| `casca/home_de_producao.dart` | VM montado da identidade da sessão |
| `casca/onde_jogar_de_producao.dart` | catálogo do que existe |
| `casca/configuracoes_de_producao.dart` | preferências persistidas; logout canônico |
| `casca/lobby_online.dart` | transporte autenticado, servidor real |
| `screens/splash_oficial_screen.dart` | tela visual, sem afirmação sobre dados |
| `screens/como_jogar_screen.dart` | conteúdo estático de regras |
| `mesa.dart` (`MesaScreen`) | motor de partidas de verdade |
| `pages/perfil_page.dart` | consome a identidade canônica |
| `services/perfil_service.dart` | com `statsDemo = false`, estado de jogador novo |
| `sessao/*` | sessão, credencial, identidade, comandos |
| `services/online_service.dart`, `ponte_sessao_online.dart`, `endpoint_servidor.dart`, `redacao_segredos.dart` | transporte canônico |
| `services/configuracoes_service.dart` | lê e grava no disco |

### MOCK — existe, compila, NÃO é alcançável pela raiz

Continuam no repositório como catálogo visual e material de teste. Nenhuma é
alcançada por rota que nasça em `main()`, e a auditoria estrutural falha se
alguma voltar a ser.

`screens/ranking_screen.dart` · `screens/recompensas_screen.dart` ·
`screens/amigos_screen.dart` · `screens/saguao_screen.dart` ·
`screens/loja_screen.dart` · `screens/loja_categoria_screen.dart` ·
`screens/hall_screen.dart` · `screens/configurar_mesa_screen.dart` ·
`screens/preparando_partida_screen.dart` · `screens/torneios_screens.dart` ·
`screens/torneios_models.dart` · `screens/torneio_modelo_screen.dart` ·
`pages/torneios_preview_page.dart` · `screens/perfil_screen.dart` (o `.mock()`;
a tela em si é consumida pelo `PerfilPage` com dados reais)

### ÓRFÃ — não referenciada por ninguém, antes e depois

| arquivo | observação |
|---|---|
| `screens/mesa_vip_preview_screen.dart` | prévia visual da mesa VIP |
| `screens/mesa_screen.dart` (`MesaScreen`, `LojaCosmeticosScreen`) | camada visual pura; a mesa jogável é a de `mesa.dart` |
| `screens/resultado_partida_screen.dart` | só alcançada de dentro de `mesa.dart` |
| `widgets/convite_vip.dart` | usado só por `amigos_screen.dart`, que é mock |

### CÓDIGO MORTO — removido nesta OS

| o que era | onde estava |
|---|---|
| `SplashScreen` + `_PontinhosPainter` + `_Particula` | `main.dart`; substituída pela splash oficial |
| `HomeScreen` | `main.dart`; carregava o **segundo** `authStateChanges().listen` e um cabeçalho com `🪙 1.000 · Liga Diamante` |
| quinze `_*PreviewHost` | `main.dart` |

### CÓDIGO MORTO — registrado, NÃO removido

`lib/app/lib/screens/amigos_screen.dart` e `lib/app/lib/widgets/convite_vip.dart`
são cópias duplicadas dentro de `lib/app/`, não importadas por ninguém. São
anteriores a esta OS, não contêm dado pessoal e removê-las está fora do escopo
declarado. Ficam registradas aqui para não se perderem.

---

## 5. Autoridade efetiva depois da OS

| responsabilidade | dono único |
|---|---|
| quem está logado, geração, credencial | `SessaoDoJogador` |
| observar o fluxo de autenticação | `sessao/sessao_firebase.dart` — **um** `authStateChanges()` |
| entrar e sair | `ComandosDeAutenticacao` / `AutenticacaoFirebase` |
| identidade pública | `obterMinhaIdentidade`, via a sessão |
| conexão com o servidor | `OnlineService`, montado **só** pela raiz |
| traduzir troca de sessão em transição do transporte | `PonteSessaoOnline`, montada na raiz |
| decidir a tela | `CascaDeProducao` |

---

## 6. As duas decisões que merecem revisão

**A chave do `MaterialApp`.** Trocar a tela de baixo não esvazia a pilha:
`Navigator.push` empilha rotas SOBRE a `home`, e quem saísse da conta com
Ajustes ou o lobby abertos continuaria olhando para telas privadas de uma
sessão encerrada. O `MaterialApp` passou a ser chaveado pela geração da sessão,
então login, logout e troca de conta descartam a navegação inteira. A
alternativa imperativa (`popUntil` no logout) devolveria a decisão para cada
superfície futura de logout se lembrar, e não cobriria troca de conta sem
logout.

**O transporte na raiz.** Ele nascia dentro da tela do lobby. Um logout
disparado nos Ajustes não encontrava ponte montada para derrubar o socket — ele
morria junto com a tela, por acidente de ciclo de vida. Subir para a raiz
resolve, e a regra que impede o efeito colateral indesejado é explícita: subir
não é conectar. O transporte fica desconectado até o jogador escolher jogar
online.

---

## 7. Fora do escopo, e por quê

Nada aqui foi feito, por proibição expressa da OS §9: deploy, APK, AAB, Play
Console, produtos de Billing, a conquista "Primeira Batida Real", a segunda
Splash/Rive, ranking, economia, loja, telas novas, merge em `main` ou em
`consolidacao/apk-geral-bmv`, e force push.

O item mais visível que fica em aberto é consequência direta da §4.4: quatro
itens de menu (Ranking, Recompensas, Amigos, Loja) só têm prévia visual, e
prévia não é destino. Eles seguem apagados e com selo até existir autoridade
que os alimente.
