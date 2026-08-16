# RESULTADO — Integração de Ranking, Ligas e Hall dos Imortais

Fecha o ciclo aberto por `docs/MAPA-INTEGRACAO-RANKING-LIGAS-HALL.md` e
`docs/PLANO-EXECUCAO-RANKING-LIGAS-HALL.md`.

- Branch: `integracao/ranking-ligas-hall`
- Base: `7a75bab49ca18a2876f43f69996de4903b9d6ccc` (`origin/integracao/fluxo-mesas`)
- Fonte visual de referência: `5b8ccc0ddaddb1432424f53015b4355022e67204` (`codex/ranking-ui`) — **não mesclada, e não foi preciso portar nada dela**
- Sem merge, sem deploy, sem release, sem APK/AAB. `main`, `consolidacao/apk-geral-bmv`, motor, servidor, Billing, economia e moderação não foram tocados.

---

## 1. O que a integração encontrou, e o que isso mudou

Duas descobertas do mapa moldaram toda a entrega.

**A fonte visual estava atrás da base.** A branch `codex/ranking-ui` tem os nomes
de arquivo embaralhados (a `RankingScreen` está salva como `nav_ranking.webp`, o
`main.dart` daquela fatia como `liga_bronze.webp`, e o `RANKING-UI-CODEX.md` é
uma imagem). Descompactado o embaralhamento, a tela de lá é **subconjunto** da
que já está na base: falta o selo na linha da lista e faltam as ligas Platina e
Imperial. Não havia componente visual a portar — e por isso a proibição de
mesclar aquela branch não custou nada.

**Não existe fonte autoritativa de Ranking, Liga ou Hall.** Não é uma fonte
incompleta; é a ausência da fonte: `cloud_firestore` não está nas dependências
do CI, nenhum arquivo em `app/lib/` o importa, e a varredura no `server.js` do
servidor Node (4102 linhas) não achou endpoint, mensagem ou coleção de ranking.
O próprio `perfil_service.dart:8` já registrava que “sem Cloud Firestore, a mesa
não grava resultados”.

Então o trabalho desta OS não foi “trocar mock por dado real” — foi **construir a
fronteira por onde o dado real vai entrar**, e tirar o dado fictício do caminho
de produção sem inventar substituto.

---

## 2. O que passou a funcionar

**Ranking por contrato.** `RankingPage` pede tudo ao `RankingService`. A
`RankingScreen` continua sendo uma `StatelessWidget` que recebe VM e devolve
toques — **o código de layout dela não mudou uma linha** (seção 5).

**Paginação de verdade.** `RankingPaginador` (`lib/ranking/ranking_paginacao.dart`)
acumula página por página com cursor opaco. Nunca pede o universo inteiro,
deduplica por identificador, preserva a ordem de chegada, reconhece o fim tanto
por `fim` quanto por cursor nulo, ignora chamada concorrente e, quando uma página
posterior falha, **mantém o que já estava na tela** e repete o mesmo cursor na
próxima tentativa.

**Idempotência.** Voltar para a tela, reconstruir o widget ou chamar `abrir()`
duas vezes dispara **uma** busca. Refresh substitui a lista em vez de concatenar.
Uma aba já carregada não rebusca ao voltar nela. No `dispose`, todos os
paginadores são descartados e a resposta que ainda estiver viajando é jogada fora
ao chegar — inclusive a de um refresh anterior que chegue depois de um mais novo.

**Perfil por identificador público.** A tela entrega a **posição** tocada — a API
aprovada não mudou — e o host resolve `posição → id` na página que já tem em mãos.
`RankingRow` e `PodioEntry` ganharam um campo `jogadorId` aditivo, com padrão
vazio. Sem id publicado, não se navega: posição muda a cada apuração e não pode
virar chave. O carregamento continua sendo do `PerfilService`, que ganhou o seam
`jogadorId` — o Ranking não duplica nada de perfil.

**Hall com os cinco estados.** `carregando`, `disponível`, `vazio`, `erro` e
`indisponível`, numa camada que entra **entre a arte e as zonas de toque**, para
que voltar e ver as regras continuem funcionando mesmo com o quadro fora do ar.
Nenhuma coordenada percentual da arte oficial mudou.

**Defeito corrigido de passagem.** O host antigo do Hall abria um segundo diálogo
de “Regras do Hall” por cima do que a própria tela já abre — dois diálogos
empilhados a cada toque. Agora é um.

---

## 3. Autoridade — a resposta pedida pela OS §21

**Nenhum cálculo oficial de Ranking permaneceu no cliente.**

O cliente não decide posição, pontos, subida ou queda de liga, desempate,
fechamento de temporada, promoção, rebaixamento, premiação, elegibilidade,
punição, exclusão de partida nem validade de resultado. Nem provisoriamente.

Isso está preso por teste, e não só por intenção: a fonte devolve uma lista fora
de ordem, com posições 42/3/17 e buracos na numeração, e a tela mostra exatamente
aquilo (`ranking_apresentacao_test.dart`). Se alguém um dia ordenar ou renumerar
no cliente, o teste quebra. “Sou eu” também vem da fonte, e não de comparar
apelido.

O que o cliente escolhe é só decoração: qual moldura de pódio cai em qual posição
recebida.

---

## 4. Nenhum dado fictício no caminho de produção

As duas `factory .mock()` **saíram de `lib/`**:

- `RankingVM.mock()` (135 linhas de pódio, lista, divisão e escada inventados);
- `HallVM.mock()` (cinco homenageados inventados).

Elas não eram “fallback silencioso” — eram a **única** origem dos dados das duas
telas, e viajavam dentro do APK. Dado de exemplo agora vive num lugar só do
repositório: `app/test/ranking_fixtures.dart`.

No caminho de produção, `RankingPage` e `HallPage` sem serviço injetado usam
`RankingSemFonte`/`HallSemFonte`, que **declaram a ausência** em vez de devolver
lista vazia (que a tela leria como “não tem ninguém”) ou número inventado. O
jogador vê o estado honesto, com botão de tentar de novo. Coberto por teste, que
verifica inclusive que nenhum nome de exemplo aparece na tela.

> Fora do escopo, registrado: as outras telas (Início, Loja, Amigos, Recompensas,
> Saguão, Onde Jogar, Configurar Mesa, Preparando, Perfil) continuam com os seus
> próprios `VM.mock()`, e `PerfilService.statsDemo` segue `true`. São linhagens
> diferentes; esta OS não mexeu nelas.

---

## 5. Regressão visual (OS §17)

**A tela de Ranking é idêntica à da base, por construção.** Todos os trechos
alterados em `ranking_screen.dart` estão **antes** da declaração
`class RankingScreen` — são os modelos e o comentário. O corpo inteiro do widget
(`build`, `_topo`, `_hall`, `_abas`, `_divisao`, `_podio`, `_lista`, `_escada`,
`_navInferior`, esqueletos, cartões de estado) não teve uma linha modificada.

No Hall, o único trecho de árvore que mudou foi indentação: as zonas de presente
e de perfil entraram dentro de um `if (_interativo)`. Todos os percentuais de
posicionamento estão idênticos — conferido linha a linha no diff.

`app/test/ranking_regressao_visual_test.dart` mede as duas superfícies exigidas,
**sem o filtro de overflow** que os outros testes de widget usam (aqui o que se
mede é justamente estouro):

| | 390×844 | 320×640 |
|---|---|---|
| cabeçalho + faixa de temporada longa | ok | ok |
| pódio (3 colunas, nome de 28 caracteres) | ok | ok |
| abas | ok | ok |
| cards da lista, nome de 53 caracteres | ok | ok |
| posição com 1, 2, 3 e 5 dígitos | ok | ok |
| pontuação com separador (1.234.567) | ok | ok |
| selos na linha | ok | ok |
| escada de ligas | ok | ok |
| rolagem até o fim | ok | ok |
| loading (esqueleto) | ok | ok |
| vazio | ok | ok |
| erro com mensagem longa | ok | ok |
| Hall com nomes extensos nas 5 categorias | ok | ok |
| Hall indisponível | ok | ok |

**Nenhum overflow em nenhuma das combinações.**

---

## 6. Regressão da Mesa (OS §14)

Os **151 testes da base** continuam verdes, incluindo os da OS de Mesas:
configuração → runtime, orientação V/H/A, menu da Mesa, rail de ações e
celebração. Nenhum arquivo daquela linhagem foi tocado — `mesa.dart`, os
contratos `mesa_*`, `preparando_partida_*`, `resultado_*` e
`vitoria_celebracao.dart` não aparecem no diff.

---

## 7. Verificação

Scaffold do CI reproduzido localmente (`app/tools/overlay_local.ps1`), Flutter
3.41.4 / Dart 3.11.1 — o CI fixa 3.44.8, e a diferença mexe em contagem de `info`
do analyzer, não no comportamento entregue.

| | base `7a75bab` | HEAD desta branch |
|---|---|---|
| `flutter analyze` | 0 erros · 13 warnings · **138** infos | 0 erros · 13 warnings · **160** infos |
| `flutter test` | **151** verdes · 0 falhas | **215** verdes · 0 falhas · 0 pulados |

**Zero erro novo. Zero warning novo.** Os 22 infos novos são todos
`avoid_relative_lib_imports`, dos arquivos de teste novos — a mesma convenção
`../lib/...` que os 11 arquivos de teste já existentes seguem. Nenhum arquivo de
`lib/` introduziu um único `info`.

Os 64 testes novos cobrem a lista da OS §15 inteira: loading, lista carregada,
vazio, erro, retry, jogador local, outro jogador, abertura de perfil, paginação,
fim da paginação, refresh, deduplicação, erro durante paginação, dispose, Liga
vinda do contrato, Hall disponível/vazio/erro — e o teste explícito de que a UI
não recalcula classificação.

> **Nota sobre o overlay local.** O CI copia os assets **subdiretório por
> subdiretório**. Copiar `app/assets/` inteiro arrasta dois `.dart` soltos que
> estão lá dentro (seção 9) e o analyzer passa a acusar **16 erros que o CI não
> tem**. O script replica o comportamento do CI; sem isso, a comparação com a
> baseline seria falsa.

---

## 8. Dependências externas não resolvidas

Nenhuma foi improvisada no cliente.

1. **Fonte oficial de Ranking** — quem publica posição, pontos, direção, delta e
   selo por escopo (temporada/global/amigos), com paginação por cursor.
   Implementar `RankingService`.
2. **Liga oficial** — qual liga e qual divisão o jogador ocupa, a escada completa
   e qual degrau é o atual. Faz parte do mesmo contrato.
3. **Faixa de temporada** — o texto de contagem regressiva vem pronto da fonte; o
   cliente não calcula prazo de temporada.
4. **Fonte oficial do Hall** — quem é imortal em cada uma das cinco categorias, e
   as estatísticas já formatadas. Implementar `HallService`.
5. **Perfil de terceiro** — hoje só existe a identidade do próprio jogador
   (Firebase Auth). `PerfilService.carregar(jogadorId:)` falha honestamente para
   jogador de fora; falta a origem.
6. **Marcação de “sou eu”** — quem compara o jogador da lista com a identidade
   autenticada é a fonte, não o cliente.

Linhagem adjacente que provavelmente resolve (1) e (2): a camada de
rastreabilidade em `claude/buraco-vip-game-traceability-3eb66c`, onde a fórmula
de ranking está em aberto. Fechar a fórmula e publicar o quadro é trabalho de
autoridade, fora desta OS.

Ligar qualquer uma delas é trocar a implementação injetada em
`RankingPage(service: ...)` / `HallPage(service: ...)`. Nenhuma linha de tela
muda.

---

## 9. Arquivos fora de lugar (registrados, **não apagados**)

Além dos já listados em `docs/MAPA-INTEGRACAO-FLUXO-MESAS.md`, esta varredura
achou mais dois, relevantes porque quebram o analyzer se o overlay não imitar o
CI:

1. `app/assets/loja_categoria_screen.dart` (58 KB) — código Dart dentro de `assets/`;
2. `app/assets/loja_categoria_screen_1.dart` (58 KB) — cópia byte a byte do anterior.

Nenhum é referenciado por `app/lib/`. Nenhum foi removido.

---

## 10. Encerramento

- sem merge (`codex/ranking-ui` não foi mesclada; `main` e `consolidacao` intactas);
- sem deploy Firebase;
- sem release, sem APK/AAB, sem Play Console;
- sem alteração de motor, regras do Buraco, STBL, vulnerabilidade, embaralhamento ou pontuação de partida;
- sem alteração de Billing, economia, saldo/fichas ou entitlement VIP;
- sem alteração de moderação, matchmaking, espectadores ou servidor de partidas;
- sem alteração de regras de Firebase ou Functions.

Arquivos de outras linhagens tocados: **nenhum**.
