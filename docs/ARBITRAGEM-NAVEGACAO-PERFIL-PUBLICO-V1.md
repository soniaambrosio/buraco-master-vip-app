# ARBITRAGEM — NAVEGAÇÃO PRODUTIVA PARA PERFIL PÚBLICO V1

**Repositório:** `soniaambrosio/buraco-master-vip-app`
**Base:** `integracao/perfil-publicavel-mesa-online-ranking-real-v2-v1`
**SHA:** `6e428e8575e2df4a504148a948305838cf3ff2d4` — *docs: laudo da composicao Perfil + Mesa Online + Ranking Real V2* (2026-08-17)
**Branch documental:** `auditoria/navegacao-perfil-publico-v1`
**Natureza:** arbitragem **somente leitura**. Nenhum arquivo de produção, teste ou configuração foi alterado.

---

## VEREDITO

> ### `BLOCKED — DEPENDE DE FEATURE/CONTRATO AUSENTE`

Nenhuma superfície alcançável a partir de `main.dart` possui, hoje, o `publicId`
de **outra pessoa**. A escolha canônica de §5 não pode ser feita porque o
primeiro critério — *"já possui `publicId` autêntico"* — falha em todas as onze
superfícies inventariadas.

**O veredito mais estreito `BLOCKED — NÃO HÁ PUBLICID ALCANÇÁVEL` também é
literalmente verdadeiro deste build**, e foi descartado por ser enganoso: ele
sugere que a autoridade não sabe emitir o identificador. Ela sabe. O backend
publica `publicPlayerId` de terceiros na MESMA callable que o aplicativo já
chama, já autenticado, em `abrirRanking → resumo.podio[]` e
`abrirRanking → primeiraPagina` (`functions-ranking/src/projecao.ts:87`,
`functions-ranking/src/index.ts:449` e `:454`). Quem descarta esses dois campos
é o **cliente**: `FotografiaRanking.daAbertura` lê `resumo.eu` e mais nada
(`app/lib/ranking/ranking_transporte.dart:173`).

O que falta, portanto, não é contrato de servidor nem consulta nova. É uma
**feature de cliente em duas partes**, e é isso que o veredito nomeia:

1. um **leitor de lista de ranking** — não existe tipo, não existe método em
   `TransporteRanking`, não existe estado;
2. uma **tela de Ranking alcançável** — a que existe é maquete
   (`RankingVM.mock()`), está desligada na grade da Home (`disponivel: false`) e
   o toque na linha devolve `int posicao`, não um identificador.

Enquanto as duas não existirem, qualquer rota para `PerfilPage(publicIdVisitado:
…)` teria de inventar o alvo — que é exatamente o que o construtor foi escrito
para impedir.

---

## 1. GATE ZERO

| Exigência | Resultado | Evidência |
|---|---|---|
| Confirmar a base **duas vezes** | ✅ | (a) `git rev-parse origin/integracao/perfil-publicavel-mesa-online-ranking-real-v2-v1` → `6e428e8575e2df4a504148a948305838cf3ff2d4`; (b) `git cat-file -t 6e428e857…` → `commit`. `HEAD` da branch documental confere byte a byte com o SHA da OS. |
| Recalcular o fecho produtivo desde `main.dart` | ✅ | **44 arquivos** de 121 em `app/lib`. Ver §2. |
| `PerfilPage` admite `publicIdVisitado` | ✅ | `app/lib/pages/perfil_page.dart:22` e `:38` — `final String? publicIdVisitado`. |
| `consultarJogadorPorIdPublico` está ligada | ✅ | `app/lib/ranking/ranking_transporte_firebase.dart:45` declara a callable; `LeitorDeRanking.rankingPublico` a alcança (`leitor_ranking.dart:223`); `EscopoRanking` é montado na raiz produtiva com `TransporteRankingFirebase` real (`casca/raiz_do_aplicativo.dart:130-132`, `:179`). |
| Ausência de chamador produtivo | ✅ | O único construtor de `PerfilPage` em produção é `casca/home_de_producao.dart:238` — `const PerfilPage()`, sem argumento. Os únicos usos de `publicIdVisitado` fora de comentários estão em `app/test/composicao/composicao_perfil_ranking_test.dart:343`. |
| Não incorporar avatar, CI ou encerramento da UI | ✅ | Nada desses assuntos entra neste laudo. |

**Observação de higiene, fora do escopo desta OS e não corrigida aqui:** o
repositório versiona uma árvore aninhada duplicada com dois arquivos —
`app/lib/app/lib/screens/amigos_screen.dart` e
`app/lib/app/lib/widgets/convite_vip.dart`. Nenhum dos dois está no fecho
produtivo, e nenhum contém `publicId`. Registrado porque uma busca por texto os
devolve em dobro e pode fazer um leitor futuro contar duas fontes onde há uma.

---

## 2. GRAFO ATUAL

### 2.1 O fecho produtivo

Fecho transitivo de `import`/`export` a partir de `app/lib/main.dart`:
**44 arquivos**. As 21 telas de `app/lib/screens/` contribuem apenas 7; as
outras 14 (Ranking, Hall, Amigos, Saguão, Loja, Recompensas, Torneios, Mesa VIP,
Configurar Mesa, Preparando Partida…) continuam compilando como catálogo visual
e material de teste, e **nenhuma rota que nasça em `main()` chega a elas**.

```
main.dart
└── casca/raiz_do_aplicativo.dart
    EscopoSessao ▸ EscopoAutenticacao ▸ EscopoTransporte ▸ EscopoRanking
    (os quatro ACIMA do MaterialApp — toda rota empurrada os herda)
    └── casca/casca_de_producao.dart
        ├── casca/login_de_producao.dart          (sem sessão)
        └── casca/home_de_producao.dart           (com sessão)  ◄── HOME PRODUTIVA
            ├── menu 'perfil'  / nav 'perfil'  ──► pages/perfil_page.dart
            │                                       └── screens/perfil_screen.dart
            ├── menu 'jogar'                   ──► casca/onde_jogar_de_producao.dart
            │                                       ├── 'treino'  ──► mesa.dart (MesaScreen)
            │                                       │                  └── screens/resultado_partida_screen.dart
            │                                       └── 'privada' ──► casca/lobby_online.dart
            │                                                          └── mesa_online/mesa_online_screen.dart
            ├── menu 'tutorial'                ──► screens/como_jogar_screen.dart ──► mesa.dart
            ├── menu 'ajustes'                 ──► casca/configuracoes_de_producao.dart
            ├── menu 'ranking'                 ──► SnackBar "ainda não está disponível"
            ├── menu 'recompensas'             ──► SnackBar
            ├── menu 'amigos'                  ──► SnackBar
            ├── menu 'loja'                    ──► SnackBar
            ├── onHistorico                    ──► SnackBar "Histórico de partidas"
            ├── onAbrirTemporada / onAbrirLobby──► inalcançáveis (temporada e lobby são null no VM)
            └── nav 'ranking' / nav 'loja'     ──► SnackBar
```

### 2.2 A cadeia de leitura remota — completa, e sem quem a acione

```
PerfilPage(ehMeuPerfil: false, publicIdVisitado: X)
  └─ _rankingVisitado()                                   perfil_page.dart:117
       └─ EscopoRanking.talvezDe(context)!.leitor         escopo_ranking.dart:27
            └─ LeitorDeRanking.rankingPublico(            leitor_ranking.dart:223
                 contaPublicId: <da sessão>, alvoPublicId: X)
                 └─ TransporteRankingFirebase
                      .rankingPorIdPublico(X)             ranking_transporte_firebase.dart:45
                      └─ callable `consultarJogadorPorIdPublico`
                           região southamerica-east1
```

Cada elo existe, está montado na árvore produtiva e é coberto por teste
(`composicao_perfil_ranking_test.dart`, casos C3, C4, C5, C7, C12, C13). **O que
não existe é o primeiro elo: o gesto que produz `X`.**

---

## 3. TODAS AS FONTES DE `publicId`

`publicId` aparece em 16 arquivos de `app/lib`. Separados por alcance:

### 3.1 No fecho produtivo — e todos falam do PRÓPRIO jogador

| Arquivo | O que carrega | Terceiro? |
|---|---|---|
| `sessao/identidade_publica_sessao.dart:215` | `IdentidadePublica.publicId` — autoridade única, vinda de `social:obterMinhaIdentidade` | ❌ próprio |
| `sessao/sessao_do_jogador.dart` | expõe `estado.publicId` da sessão viva | ❌ próprio |
| `casca/raiz_do_aplicativo.dart:162` | repassa o `publicId` da sessão a `RankingDaSessao.aoMudarSessao` | ❌ próprio |
| `casca/home_de_producao.dart:187` | usa o `publicId` como **fallback de apresentação** quando não há apelido | ❌ próprio |
| `casca/configuracoes_de_producao.dart:97` | mesmo fallback, na tela de Ajustes | ❌ próprio |
| `services/perfil_service.dart:109` | mesmo fallback, no VM do Perfil | ❌ próprio |
| `ranking/ranking_da_sessao.dart:52,68` | `_publicId` da conta; dispara `meuRanking` | ❌ próprio |
| `ranking/leitor_ranking.dart:74-81` | `_Chave(contaPublicId, alvo, alvoPublicId)` — **sabe** falar de terceiro | ⚠️ **capaz, nunca acionado** |
| `ranking/ranking_transporte.dart:294` | `rankingPorIdPublico(String publicId)` | ⚠️ **capaz, nunca acionado** |
| `ranking/ranking_transporte_firebase.dart:45` | a callable de terceiro | ⚠️ **capaz, nunca acionado** |
| `pages/perfil_page.dart:38,118` | `publicIdVisitado` — o parâmetro que esta OS quer alimentar | ⚠️ **capaz, nunca acionado** |

### 3.2 Fora do fecho produtivo

| Arquivo | O que carrega | Por que não serve |
|---|---|---|
| `social/listagem_social.dart:68` | `EntradaSocial.publicId` — **é um `publicId` real de terceiro** | **É BACKEND.** `social/js_bridge.dart` compila esta camada para `functions-social/lib/domain_bundle.js` via `dart compile js`. Roda em Cloud Functions, não no aparelho. Nenhuma tela a importa. |
| `social/apresentacao.dart:242` | `PerfilPublico.publicId` | idem — domínio compilado para Node |
| `social/identidade_publica.dart` | validação de formato de id | idem |
| `social/amizade.dart` | regras de vínculo | idem |

**Não existe, em nenhum lugar do cliente, um `publicId` de terceiro.** A camada
que os manipula não roda no aparelho; a que roda no aparelho só conhece o dono
da sessão.

### 3.3 A fonte real que o cliente joga fora

O backend **já publica** identificadores de terceiro na callable que o app já
usa:

```ts
// functions-ranking/src/projecao.ts:85-87
export interface JogadorPublicado {
  /// `RankingJogador.id`. E o `publicPlayerId`, NUNCA o uid.
  readonly id: string;
```

```ts
// functions-ranking/src/index.ts:449,454
      podio: podio.map((l) => projetarJogador(l, uid)),
    primeiraPagina: paginaPublicada(pagina, uid),
```

`CAMPOS_PUBLICADOS` (`projecao.ts:198`) confirma `"id"` na lista autorizada, e
`projetarJogador` publica também `souEu` (`:178`) — *"A comparacao acontece nesta
linha, e em nenhuma outra do sistema"* —, que é a distinção próprio/visitado
resolvida **pela autoridade**, e não pelo cliente comparando strings.

Há ainda `paginarRanking` (`index.ts:459`) para as páginas seguintes.

**O cliente descarta tudo isso.** `FotografiaRanking.daAbertura` abre a resposta,
lê `resumo.temporadaId` e `resumo.eu`, e devolve uma fotografia de **um** jogador
(`ranking_transporte.dart:173-190`). `podio` e `primeiraPagina` nunca são
tocados. `FotografiaRanking` não tem campo de id. `TransporteRanking` tem dois
métodos, e nenhum devolve lista (`ranking_transporte.dart:282-295`).

---

## 4. INVENTÁRIO DAS SUPERFÍCIES (§4)

Legenda de alcance: **P** = no fecho produtivo, alcançável por gesto; **C** =
compila, sem rota; **B** = backend, não roda no aparelho.

### 4.1 Ranking

| | |
|---|---|
| **Arquivo** | `app/lib/screens/ranking_screen.dart` (1178 linhas) |
| **Alcance** | **C** — `menu 'ranking'` tem `disponivel: false` e o toque cai em `_aindaNao` (`home_de_producao.dart:136`, `:211`); `nav 'ranking'` idem (`:230`) |
| **Origem do identificador** | `RankingVM.mock()` (`:111`) — dados escritos no código |
| **`publicId` ou UID?** | **Nenhum dos dois.** `RankingEntryVM` e `PodioVM` têm `posicao`, `nome`, `avatar`, `moldura`, `pontos`, `liga`, `delta`, `selo`. Sem id. |
| **Ação atual ao toque** | `onTap: () => onVerJogador(entry.posicao)` (`:658`, `:780`) — o callback é `ValueChanged<int>` (`:255`). **Passa a colocação.** |
| **Acessibilidade** | linhas são `InkWell`/`GestureDetector` sem `Semantics` de ação nomeada |
| **Dependências** | leitor de lista inexistente; tela nunca ligada a autoridade |
| **Risco de segunda autoridade** | **ALTO.** Ligar `onVerJogador(int)` a um perfil exigiria traduzir posição→identidade no cliente. Isso é a segunda autoridade de identidade que a base inteira foi escrita para impedir. |

### 4.2 Pódio

Mesmo arquivo, mesma maquete. `PodioVM` (`ranking_screen.dart:34-38`):
`posicao`, `nome`, `avatar`, `moldura`, `pontos`. Sem id. Alcance **C**.
No backend, `resumo.podio[]` **tem** `id` — a perda acontece na fronteira do
cliente, não na origem.

### 4.3 Hall da Fama

| | |
|---|---|
| **Arquivo** | `app/lib/screens/hall_screen.dart` |
| **Alcance** | **C** — só se abre por `onAbrirHall` de `ranking_screen.dart:435`, que já é inalcançável |
| **Origem** | mock: `id: 'aurora'`, `'aurora-claudia'`, `'beto'`, `'marina'`, `'ricardo'` (`:45-74`) |
| **`publicId` ou UID?** | **Nenhum.** São *slugs* de maquete. |
| **Ação ao toque** | `widget.onVerPerfil(honrado.id)` — `ValueChanged<String>` (`:104`, `:389`). **A assinatura é a certa e o valor é falso.** |
| **Risco** | **CRÍTICO se usado.** É a armadilha mais perigosa do inventário: o tipo casa com `publicIdVisitado`, compila, e manda `'beto'` para a autoridade. A callable responde `not-found` ou `invalid-argument`, e a tela teria de explicar uma falha que é dado de maquete. |

### 4.4 Amizades

| | |
|---|---|
| **Arquivos** | `app/lib/screens/amigos_screen.dart` (**C**) · `app/lib/social/amizade.dart` (**B**) |
| **Origem** | mock: `Amigo(id: 'claudia', …)`, `'beto'`, `'fernanda'`, `'mateus'`, `'sofia'`, `'voce'` (`:151-161`) |
| **`publicId` ou UID?** | **Nenhum** na tela. O `publicId` real existe só no domínio compilado para Node. |
| **Ação ao toque** | `onAbrirAmigo`, `onConvidar`, `onAssistir` — todos `ValueChanged<String>` (`:189-194`) |
| **Dependências** | não há callable de listagem de amizades no cliente; nenhum arquivo de `app/lib/` importa `social/listagem_social.dart` |
| **Risco** | mesma armadilha do Hall |

### 4.5 Convites

`app/lib/widgets/convite_vip.dart` — importado apenas por `amigos_screen.dart`
(**C**). Não contém `publicId`. Na mesa online, o convite é o **código da mesa**
(`BURACO-0001`), que identifica sala, não pessoa.

### 4.6 Lobby (mesa privada online) — **a única superfície alcançável com gente real**

| | |
|---|---|
| **Arquivo** | `app/lib/casca/lobby_online.dart` |
| **Alcance** | **P** — Home ▸ Jogar ▸ "privada" (`onde_jogar_de_producao.dart:89`) |
| **Origem do identificador** | `v['assentos']` da visão do servidor Node, lida crua (`:395`) |
| **`publicId` ou UID?** | **Nenhum dos dois chega à tela.** O que se lê é `a['apelido']` e `a['ehVoce']` (`:426-427`). E o `apelido` é **texto livre digitado pela própria pessoa** no campo "Seu apelido", com valor inicial `'Você'` (`:81`, `:326`), enviado em `criarMesa`/`entrarMesa` (`:345`, `:380`). Não é identidade — é rótulo autodeclarado e não verificado. |
| **Ação ao toque** | **não há.** As cadeiras são `Container`, sem gesto. |
| **Acessibilidade** | sem `Semantics` |
| **Risco** | **ALTO.** Ver §4.7. |

### 4.7 Participantes da mesa online

| | |
|---|---|
| **Arquivos** | `casca/mesa_online/estado_mesa_online.dart` · `mesa_online_screen.dart` |
| **Alcance** | **P** — o lobby troca de corpo quando a partida começa (`lobby_online.dart:167-181`) |
| **Origem** | visão por assento do servidor Node |
| **`publicId` ou UID?** | **UID — e ele é barrado de propósito na fronteira.** `AssentoOnline` carrega `indice`, `apelido`, `ehBot`, `dupla`, `qtdCartas`, `ehVoce` (`estado_mesa_online.dart:162-180`). O cabeçalho declara: *"`jogadorId` e os campos de avatar também ficam de fora: eles chegam na visão (o servidor injeta para a mesa desenhar foto), mas esta fatia não desenha avatar, e transportar identificador que ninguém usa é superfície de vazamento sem contrapartida"* (`:41-44`). |
| **O que o servidor injeta** | conferido em `F:/Projetos/buraco-servidor@85d0eee`: `assentosDaVisao[i].jogadorId = sj.jogadorId` (`server.js:4419`, `:4480`), e `jogadorId` **é o UID do Firebase** — `const jogadorIdDoUid = opts.jogadorIdDoUid \|\| ((uid) => uid)` (`:5249`); a lista de assentos publica o campo com o nome `uid` (`:3979`). |
| **O servidor conhece `publicId`?** | **NÃO.** `grep -c 'publicId' server.js` → **0**. `grep -c 'publicPlayerId'` → **0**. |
| **Ação ao toque** | **não há.** Os assentos são `Text` (`mesa_online_screen.dart:366`). |
| **Risco** | **PROIBIDO por §4.** Usar este caminho significa usar UID como substituto de `publicId`. Além da proibição, seria um retrocesso duplo: reabre um campo que a fatia fechou por decisão escrita, e exporia o UID a uma tela — o mesmo dado que `home_de_producao.dart:183` promete que "nunca aparece aqui". Traduzir UID→`publicId` no cliente criaria a segunda autoridade de identidade. Traduzi-lo no servidor exigiria ensinar `publicId` a um processo que hoje não sabe que ele existe. |

### 4.8 Histórico

Não existe tela. `onHistorico` cai em `_aindaNao(context, 'Histórico de partidas')`
(`home_de_producao.dart:76`). Sem arquivo, sem fonte, sem identificador.

### 4.9 Busca por apelido

**Não existe no cliente.** A busca entregue vive no backend
(`functions-social`); `app/lib` não tem callable de busca, e a única tela com
`onBuscar` é `amigos_screen.dart:188` (**C**, mock). Registrado também um fato
relevante para §7: a busca do backend **não tem limite de taxa** — expor uma
porta de descoberta de identidade antes disso seria antecipar um risco conhecido.

### 4.10 Compartilhamento

`PerfilPage.textoDeCompartilhamento` (`perfil_page.dart:58`) monta um convite e
`_compartilhar` o copia para a área de transferência (`:192-197`). É superfície
**de saída**: produz texto sobre o dono, e não consome identificador de ninguém.
Não carrega `publicId` — e não deve: o texto sai do aparelho.

### 4.11 Perfil próprio

| | |
|---|---|
| **Arquivo** | `app/lib/pages/perfil_page.dart` |
| **Alcance** | **P** — Home ▸ menu 'perfil' ou nav 'perfil' (`home_de_producao.dart:236`) |
| **Origem** | `EscopoSessao.identidadeDe(context).publicId` — autoridade canônica |
| **`publicId` ou UID?** | **`publicId`, autêntico** — mas **do próprio jogador** |
| **Ação ao toque** | já é a tela |
| **Risco** | usá-lo como alvo violaria §7: *"não consulta perfil próprio pela porta remota quando o estado local já é autoridade"*. Ver §7.9 para o mecanismo exato. |

### 4.12 Quadro-resumo

| Superfície | Alcance | Tem `publicId` de terceiro? | Toque hoje |
|---|---|---|---|
| Ranking | C | não (mock, sem id) | `onVerJogador(int posicao)` |
| Pódio | C | não (mock, sem id) | `onVerJogador(int posicao)` |
| Hall | C | não (slug de mock) | `onVerPerfil(String id-falso)` |
| Amizades | C | não (slug de mock) | `onAbrirAmigo(String id-falso)` |
| Convites | C | não | — |
| Lobby | **P** | não (apelido autodeclarado) | nenhum |
| Participantes da mesa | **P** | não (só UID, barrado) | nenhum |
| Histórico | — | tela inexistente | — |
| Busca | — | não existe no cliente | — |
| Compartilhamento | **P** | não (superfície de saída) | copiar texto |
| Perfil próprio | **P** | não — é o próprio | já é a tela |

**Zero superfícies alcançáveis com `publicId` autêntico de terceiro.**

---

## 5. ESCOLHA CANÔNICA

Aplicando os oito critérios de §5 aos únicos dois candidatos que sobrevivem ao
filtro de alcance:

| Critério | Mesa/Lobby online (**P**) | Ranking (**C**) |
|---|---|---|
| já possui `publicId` autêntico | ❌ só UID, e barrado | ❌ mock sem id |
| alcançável da Home produtiva | ✅ | ❌ `disponivel: false` |
| não exige backend novo | ❌ o servidor Node não conhece `publicId` | ✅ `abrirRanking` já publica |
| não abre segunda consulta de identidade | ❌ exigiria UID→`publicId` | ✅ o `id` vem na mesma resposta |
| não cria roteador paralelo | ✅ | ✅ |
| gesto visual natural | ⚠️ assento é `Text` | ✅ linha de lista |
| preserva retorno e estado | ⚠️ a mesa é corpo de rota, não rota | ✅ `push` comum |
| distingue próprio de visitado | ⚠️ só `ehVoce` local | ✅ `souEu` da autoridade |

**Nenhum dos dois satisfaz.** §5 manda retornar BLOCKED.

### 5.1 O caminho recomendado para a PRÓXIMA OS

Não é uma escolha canônica — é o pré-requisito dela. **Ranking** é a superfície
correta, e está a duas peças de existir. Fica registrado porque a diferença entre
"impossível" e "faltam duas peças nomeadas" é o que a próxima OS precisa saber:

1. **Leitor de lista.** Um `FotografiaRankingLista` (ou nome equivalente) com os
   campos já autorizados por `CAMPOS_PUBLICADOS`, um terceiro método em
   `TransporteRanking`, e o caminho correspondente em `LeitorDeRanking` — com as
   **mesmas três guardas** de `_executar` (geração, sequência por chave,
   barreira temporal), porque uma lista está exposta a exatamente a mesma classe
   de resposta vencida que a fotografia.
2. **Tela de Ranking real.** Trocar `RankingVM.mock()` por estado vindo do
   leitor, mudar `onVerJogador` de `ValueChanged<int>` para `ValueChanged<String>`
   carregando o `id`, e ligar o item do menu (`disponivel: true`).

Só depois disso a navegação desta OS vira uma linha, e o contrato de §6 se aplica
sem inventar nada.

---

## 6. CONTRATO DA NAVEGAÇÃO FUTURA

Especificado como exigido, para valer no dia em que §5.1 estiver pronto.

| Item | Contrato |
|---|---|
| **Widget de origem** | a linha de ranking (`_LinhaRanking` / `_ItemPodio` em `ranking_screen.dart`), envolvida por um `InkWell` que já é a superfície do toque |
| **Callback** | `onVerJogador`, com assinatura mudada de `ValueChanged<int>` para `ValueChanged<String>` |
| **Parâmetro exato** | `JogadorPublicado.id` — o `publicPlayerId` da resposta, repassado **sem transformação**. Nada de `posicao`, nada de índice de lista, nada de nome. |
| **Construção da rota** | `Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => PerfilPage(ehMeuPerfil: false, publicIdVisitado: id)))`. `push` comum, `MaterialPageRoute`, sem rota nomeada e sem tabela de rotas — a base não tem roteador e criar um seria o "roteador paralelo" que §5 proíbe. |
| **Botão voltar** | comportamento padrão do `Navigator`. `PerfilScreen.onVoltar` já é `maybePop` (`perfil_page.dart:220`), e `NavDestino.inicio` também (`:245`). A tela de Ranking permanece na pilha com seu estado — nada de `pushReplacement`, nada de `popUntil`. |
| **Perfil próprio** | se `id` for o `publicId` da sessão — ou se a linha vier com `souEu: true` —, a rota **não** é a visitada: abre-se `PerfilPage()` (dono), ou não se abre nada. Ver §7.9. **A decisão usa `souEu` da autoridade**, com a comparação local com o `publicId` da sessão apenas como segunda barreira. |
| **Alvo vazio ou inválido** | linha sem `id`, ou com `id` vazio após `trim`, **não é tocável**: o `InkWell` recebe `onTap: null`. Nada de empurrar `PerfilPage(ehMeuPerfil: false, publicIdVisitado: null)`, que já tem semântica própria e definida (`perfil_page.dart:35-37`: mostra o resto e não afirma ranking). |
| **Troca de sessão durante a consulta** | já resolvido e **não deve ser reimplementado**. `LeitorDeRanking.aoMudarSessao` invalida geração, voos, cache e temporada aceita (`leitor_ranking.dart:195-207`); a guarda de geração descarta a resposta antes de qualquer escrita (`:302`); e a chave do `MaterialApp` em `raiz_do_aplicativo.dart` **apaga a pilha inteira** na troca de sessão, então a rota visitada morre junto. |
| **Resposta vencida** | idem: guarda de sequência por chave (`:306`) e barreira temporal global (`:310`). `null` significa **descarte** — quem chama não publica nada. `perfil_page.dart:145-147` já trata `null` caindo em `rankingDaCascaPublicavel`. |
| **Acesso recusado / App Check** | `MotivoFalhaRanking.credencialOuAtestacao` → `EstadoRanking` neutro de `acessoRecusado`, com botão de tentar de novo, **sem** afirmar sessão expirada e **sem** derrubar a sessão. Já implementado; o contrato é não regredir. |
| **Retry** | `PerfilScreen.onRecarregar` já recarrega as duas metades (`perfil_page.dart:237-240`). Idempotente por construção: `_emVoo` dedupa por chave (`leitor_ranking.dart:242-243`), e o caso C13 prova que três retries produzem **uma** chamada. |
| **Loading** | `PerfilEstado.carregando` com o esqueleto que `PerfilScreen` já desenha. Nada de valor de placeholder que pareça dado. |
| **Acessibilidade do elemento tocável** | o `InkWell` recebe `Semantics(button: true, label: …)` anunciando **a ação**, não só o conteúdo — algo como *"Ver perfil de ‹apelido›"*. Linha sem `id` não anuncia ação nenhuma, porque não tem. |
| **Prevenção de toques duplicados** | duas camadas. (a) Na origem: o handler ignora o toque se já houver rota visitada no topo — ou o `InkWell` é desabilitado enquanto o `push` está em curso. (b) Por baixo, o dedupe por chave do leitor já garante que N toques no MESMO alvo não viram N chamadas. Três toques rápidos em alvos **diferentes** são três pedidos legítimos e concorrentes, e o leitor os trata por chave separada de propósito (`leitor_ranking.dart:110-114`) — o que não pode acontecer é empilhar três rotas. |
| **Ausência de consulta no `build`** | preservada. `PerfilPage` só consulta em `didChangeDependencies`, e só quando o `publicId` canônico **muda** (`:100-107`). O `build` lê estado, nunca dispara I/O (`:212-214`). O contrato para a lista de ranking é o mesmo. |

---

## 7. PRIVACIDADE E SEGURANÇA

Prova, item a item de §7, de que a rota futura assim especificada satisfaz cada
exigência — e onde a prova depende de disciplina em vez de mecanismo.

1. **Recebe somente `publicId`.** `PerfilPage` tem três parâmetros: `key`,
   `ehMeuPerfil` e `publicIdVisitado`. Não há por onde passar outra coisa. O caso
   C3 já prova que *"o visitado é escolhido SÓ pelo `publicIdVisitado`"*.
2. **Não expõe UID.** O UID não entra na rota, não entra no VM e não entra na
   tela. A única superfície do cliente que **tem** UID de terceiro é a visão da
   mesa online, e ela o barra na fronteira por decisão escrita
   (`estado_mesa_online.dart:41-44`). Do lado remoto, `projetarJogador` publica
   `souEu` como resultado da comparação e **não** o `uid` que a fez.
3. **Não carrega e-mail.** Nenhum campo de `JogadorPublicado` é e-mail, e
   `CAMPOS_PUBLICADOS` é uma lista fechada e testada. A Home já suprime o e-mail
   do próprio dono (`home_de_producao.dart:99-101`); um visitado tem menos, não
   mais.
4. **Não permite consulta sem sessão.** Três travas independentes:
   `consultarJogadorPorIdPublico` exige autenticação e App Check no backend;
   `_rankingVisitado` retorna sem chamar quando `contaPublicId == null`
   (`perfil_page.dart:122-124`, caso C5); e a casca sequer monta a Home sem
   sessão.
5. **Respeita o contrato público.** O cliente lê os campos que
   `CAMPOS_PUBLICADOS` autoriza, e a leitura é estrita: forma errada vira
   `respostaInvalida`, nunca uma fotografia meio preenchida
   (`ranking_transporte.dart:169-172`).
6. **Não inventa liga, nível, colocação ou avatar.** `EstadoRanking` é a
   autoridade única de tradução, `liga` chega como rótulo pronto do backend, e
   os casos C8, C9 e C10 já vedam `Nível null`, `Bronze` e `#0`/`#1` fabricados.
   Para um **visitado**, a regra é ainda mais estrita: `_carregar` só usa o
   ranking remoto e nunca o do escopo, porque o do escopo é do dono
   (`perfil_page.dart:145-147`).
7. **Não transforma falha de App Check em logout.** A ambiguidade do
   `unauthenticated` está documentada e resolvida onde se conhece a sessão:
   com sessão local viva o estado é `acessoRecusado`, e nada é inventado
   (`ranking_transporte_firebase.dart:19-31`, `leitor_ranking.dart:274-277`).
8. **Não mistura cache entre contas ou alvos.** `_Chave` é
   `(contaPublicId, alvo, alvoPublicId)` — as duas partes obrigatórias, com a
   razão escrita no arquivo (`leitor_ranking.dart:66-72`) — e `aoMudarSessao`
   limpa o cache inteiro.
9. **Não consulta o perfil próprio pela porta remota.** **Esta é a única
   exigência de §7 sem mecanismo, e o laudo a nomeia como tal.** Hoje,
   `rankingPublico(contaPublicId: X, alvoPublicId: X)` **chama**
   `consultarJogadorPorIdPublico(X)`: `_chaveDe` colapsa o alvo próprio na chave
   `_Alvo.proprio` (`leitor_ranking.dart:231-234`) — o que é um acerto, porque
   faz o dedupe reaproveitar um voo de `meuRanking` em curso —, mas o *thunk*
   passado a `_ler` já é o da callable de terceiro
   (`leitor_ranking.dart:223-229`). Sem voo em curso, a chamada sai.
   **Portanto a proteção tem de estar na navegação**, e é por isso que §6 a
   torna contrato: uma linha com `souEu: true` nunca empurra
   `PerfilPage(ehMeuPerfil: false, …)`. Um teste estrutural deve fixar isso, e
   está na matriz como T2/T13.

---

## 8. MATRIZ DE TESTES PROPOSTA

Desenhada para a implementação futura. Nenhum destes casos existe hoje — os que
já existem estão referenciados na coluna da direita para que a próxima OS **não
os duplique**.

| # | Caso | O que deve ocorrer | Já coberto? |
|---|---|---|---|
| T1 | tocar um jogador no ranking | uma rota empurrada, `PerfilPage` com `ehMeuPerfil: false` e `publicIdVisitado` == o `id` **daquela** linha | — |
| T2 | tocar o próprio jogador (`souEu: true`) | **nenhuma** chamada a `consultarJogadorPorIdPublico`; ou abre o perfil do dono, ou não navega. Assertiva sobre `chamadasEmitidas` | — |
| T3 | alvo válido | a fotografia do visitado aparece; o ranking do **dono** não é tocado | parcial: C3 |
| T4 | alvo vazio (`''` ou só espaços) | a linha não é tocável; nenhuma rota, nenhuma chamada | — |
| T5 | alvo inexistente (`not-found`) | estado de erro **do visitado**, com retry; nada de "sem colocação", que é resposta legítima e diferente | — |
| T6 | acesso recusado (`unauthenticated`) | `acessoRecusado` neutro, com retry, **sem** logout e **sem** afirmar sessão expirada | parcial |
| T7 | falha recuperável seguida de retry | segunda tentativa emite **uma** chamada e publica o resultado | parcial: C13 |
| T8 | resposta chega **depois** da troca de conta | `null` (descarte). Nada na tela, nada no cache. Como a chave do `MaterialApp` derruba a pilha, a rota visitada também deixa de existir | parcial: leitor |
| T9 | duas respostas fora de ordem (mesmo alvo) | só a do pedido mais recente é aplicada | parcial: C7 |
| T10 | três toques rápidos no **mesmo** jogador | **uma** rota empilhada e **uma** chamada emitida | — |
| T11 | três toques rápidos em jogadores **diferentes** | no máximo uma rota; e se as três consultas correrem, são três chaves distintas — nenhuma cancela a outra | — |
| T12 | voltar do perfil visitado | a tela de Ranking reaparece **com a mesma lista e a mesma posição de rolagem**; nenhuma recarga disparada pelo retorno | — |
| T13 | leitor de tela anuncia a ação | o elemento tocável expõe `Semantics(button: true)` com rótulo que nomeia a ação; linha sem `id` não anuncia ação | — |
| T14 | zero, Bronze, Nível 1, `#0` ou `#1` fabricados | nenhum deles aparece na tela do visitado nem no texto de compartilhamento | parcial: C8, C9, C10 |
| T15 | (estrutural) autoridade única de navegação | um único ponto no código constrói `PerfilPage` com `publicIdVisitado`, e o argumento vem do `id` da resposta — não de `posicao`, índice ou nome | — |
| T16 | (estrutural) o `build` não consulta | reconstruir a rota visitada **N** vezes mantém `chamadasEmitidas` constante | parcial: C12 |

**Nota de execução, para a próxima OS não perder tempo:** o CI e o
`flutter test` só enxergam arquivos no glob padrão — suítes com prefixo
`teste_` ficam de fora. E testes de widget desta base exigem superfície de
telefone; 800×600 derruba a tela e a fonte substituta inventa *overflow*.

---

## 9. RISCOS

| # | Risco | Gravidade | Nota |
|---|---|---|---|
| R1 | **Assinatura que casa com valor falso.** `hall_screen.dart:389` e `amigos_screen.dart` já emitem `ValueChanged<String>` com ids de maquete (`'beto'`, `'claudia'`). Ligá-los a `publicIdVisitado` **compila** e passa em revisão desatenta. | **CRÍTICO** | Nenhuma dessas telas deve ser a origem enquanto sua fonte for `.mock()`. |
| R2 | **UID como substituto de `publicId`.** O único identificador real de terceiro alcançável no cliente é o UID da mesa online, e §4 o proíbe. | **CRÍTICO** | A fronteira que o barra é uma decisão escrita, não um acidente. Reabri-la é regressão. |
| R3 | **Posição usada como identidade.** `onVerJogador(entry.posicao)` convida a traduzir colocação→jogador no cliente. | **ALTO** | Seria a segunda autoridade de identidade. A correção é mudar a assinatura, não interpretar o inteiro. |
| R4 | **Perfil próprio pela porta remota.** Sem guarda na navegação, um alvo igual ao da conta emite `consultarJogadorPorIdPublico` sobre o próprio jogador. | **ALTO** | §7.9. Guarda é de navegação; teste T2. |
| R5 | **Lista sem as três guardas do leitor.** Um leitor de lista escrito do zero, sem geração/sequência/barreira temporal, reabre a classe inteira de defeitos que a barreira temporal V2 fechou. | **ALTO** | A lista precisa da mesma disciplina da fotografia. |
| R6 | **Descoberta de identidade sem limite de taxa.** A busca do backend não tem *rate limit*; qualquer superfície nova de descoberta amplia esse risco antes de ele estar tratado. | **MÉDIO** | Não bloqueia a navegação por ranking (a lista já é pública por contrato), mas bloqueia uma busca no cliente. |
| R7 | **Apelido vazio na lista.** `projecao.ts:88` declara *"VAZIO HOJE"*; `firestore.ts:742` já preenche a partir de `publicProfiles`, mas só na apuração. Numa temporada sem apuração recente a lista pode vir com nomes em branco. | **MÉDIO** | Comentário e código divergem — conferir antes de desenhar a lista. Nome vazio **não** autoriza fallback inventado. |
| R8 | **Empilhamento de rotas por toque repetido.** Sem trava de origem, três toques viram três `PerfilPage` na pilha. | **MÉDIO** | T10/T11. |
| R9 | **Árvore duplicada versionada.** `app/lib/app/lib/` com dois arquivos faz busca por texto devolver fontes em dobro. | **BAIXO** | Fora do escopo desta OS; não corrigido aqui. |

---

## 10. DEPENDÊNCIAS EXTERNAS

| Dependência | Estado | Efeito |
|---|---|---|
| **App Check não ativado** | `firebase_app_check` está no `pubspec` e **não** é ativado; `opcoesCliente` do backend traz `enforceAppCheck: true` | **Em produção, as duas callables de ranking recusam.** A recusa chega como `unauthenticated`, indistinguível de credencial inválida. Enquanto assim, um perfil visitado nunca mostra ranking em produção — e a tela dirá `acessoRecusado`, corretamente, sem inventar nada. Pendência de ativação, não de código. |
| **`abrirRanking` como fonte de lista** | contrato publicado e implantado; o cliente **não** o lê | Nenhum trabalho de backend é necessário. O trabalho é de cliente. |
| **`paginarRanking`** | existe (`index.ts:459`) | Necessária a partir da segunda página; não bloqueia a V1. |
| **Temporada vigente** | `abrirRanking` responde `failed-precondition` sem temporada | Sem temporada não há lista e não há de quem partir. A tela precisa dizer isso, não desenhar lista vazia. |
| **Região `southamerica-east1`** | precisa casar com `functions-ranking/src/index.ts` | Região errada devolve `not-found`, que aqui viraria "jogador não encontrado" — indistinguível de um id que de fato não existe. |
| **Servidor Node (`buraco-servidor@85d0eee`)** | não conhece `publicId` (0 ocorrências) | Só importa se alguém insistir na mesa como origem. Para o caminho do ranking, irrelevante. |
| **Fonte de apelido/avatar do ranking** | projeção preenchida na apuração, a partir de `publicProfiles` | Ver R7. |

---

## 11. ARQUIVOS QUE A IMPLEMENTAÇÃO FUTURA TOCARIA

Nenhum deles foi alterado por esta OS.

**Pré-requisito — leitor de lista (§5.1, item 1)**

| Arquivo | Mudança prevista |
|---|---|
| `app/lib/ranking/ranking_transporte.dart` | tipo de lista + terceiro método em `TransporteRanking` |
| `app/lib/ranking/ranking_transporte_firebase.dart` | adaptador da lista (e de `paginarRanking`, se a V1 paginar) |
| `app/lib/ranking/leitor_ranking.dart` | caminho de lista sob as **mesmas** três guardas |
| `app/lib/ranking/estado_ranking.dart` | tradução de lista, se o estado de lista for necessário |
| `app/lib/ranking/ranking_da_sessao.dart` | exposição do estado de lista ao escopo, se aplicável |

**Pré-requisito — tela alcançável (§5.1, item 2)**

| Arquivo | Mudança prevista |
|---|---|
| `app/lib/screens/ranking_screen.dart` | `RankingVM.mock()` → estado real; `onVerJogador` de `ValueChanged<int>` para `ValueChanged<String>`; `Semantics` no elemento tocável |
| **novo** `app/lib/casca/ranking_de_producao.dart` | o *page* que liga a tela ao escopo — o par de `home_de_producao.dart` e `configuracoes_de_producao.dart` |
| `app/lib/casca/home_de_producao.dart` | `menu 'ranking'` para `disponivel: true`; `_menu`/`_nav` empurram a nova rota em vez de `_aindaNao` |

**A navegação desta OS**

| Arquivo | Mudança prevista |
|---|---|
| `app/lib/casca/ranking_de_producao.dart` | o `push` de `PerfilPage(ehMeuPerfil: false, publicIdVisitado: id)` e a guarda de `souEu` |

`app/lib/pages/perfil_page.dart` **não é tocado**: ele já admite o parâmetro e já
trata alvo nulo, sessão ausente, resposta vencida, erro e retry.

**Testes**

| Arquivo | Mudança prevista |
|---|---|
| **novo** `app/test/composicao/navegacao_perfil_publico_test.dart` | T1–T16 |
| `app/test/composicao/composicao_perfil_ranking_test.dart` | o caso C15 (*"a cadeia Home → PerfilPage → PerfilScreen é única"*) e o C17 (*"o ranking é alcançável pela raiz, e por um caminho só"*) passam a ter uma segunda origem legítima e precisarão ser atualizados — **conscientemente**, não por conveniência |

---

## 12. RESUMO EXECUTIVO

O leitor remoto de perfil visitado está **inteiro, montado e testado** na árvore
produtiva. O que falta não é ele.

Falta **de quem visitar**. Das onze superfícies de §4, quatro são alcançáveis
(Perfil próprio, Lobby, Mesa online, Compartilhamento) e nenhuma delas carrega o
`publicId` de outra pessoa: o Perfil e o Compartilhamento falam do dono; o Lobby
mostra um apelido que a própria pessoa digitou; a Mesa recebe UID e o barra de
propósito na fronteira. As sete restantes — Ranking, Pódio, Hall, Amizades,
Convites, Histórico, Busca — ou não têm rota, ou são maquete com id inventado, ou
não existem como tela.

A saída é curta e está inteiramente do lado do cliente: **o backend já entrega o
`publicPlayerId` de terceiros na mesma callable que o app já chama, e o cliente
joga os dois campos fora.** Ligar o leitor de lista e tornar o Ranking alcançável
transforma esta navegação em uma linha de código — sob o contrato de §6, com a
guarda de perfil próprio de §7.9 e a matriz de §8.

---

*Laudo somente leitura. Nenhum arquivo de produção foi alterado.*
