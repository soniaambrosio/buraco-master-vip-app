# PLANO DE EXECUÇÃO — Ranking, Ligas e Hall dos Imortais

Segue `docs/MAPA-INTEGRACAO-RANKING-LIGAS-HALL.md`. O mapa já registrou o que
decide a forma deste plano:

1. **não há UI a portar** — a base é superconjunto de `codex/ranking-ui` (mapa §A);
2. **não há fonte autoritativa** de Ranking, Liga ou Hall em lugar nenhum que o
   app alcance (mapa §G) — então o entregável é a **fronteira de dados**, e o
   caminho de produção mostra ausência em vez de inventar número (OS §5/§6).

Ordem de trabalho e o que cada passo entrega.

---

## Passo 1 — Contratos (nenhuma UI ainda)

`app/lib/ranking/ranking_contract.dart`

- `RankingEscopo { temporada, global, amigos }` — espelha as abas sem depender da UI.
- `RankingJogador` — `id` público, apelido, avatar, `liga`, pontos, `posicao`,
  `direcao`, `delta`, `selo?`, `souEu`. **Nada de e-mail** (OS §12).
- `RankingLiga` / `RankingDivisao` — Liga oficial **recebida**, com a escada e qual
  é a atual. O cliente não deduz nada disso (OS §7).
- `RankingPagina` — `itens`, `cursorProxima?`, `fim`. Cursor opaco: quem manda no
  corte é a fonte.
- `RankingResumo` — divisão atual + pódio + escada + faixa de tempo da temporada.
- `RankingIndisponivel` — exceção tipada com motivo legível.

`app/lib/hall/hall_contract.dart`

- `HallQuadro` — lista de `HallHonrado` por categoria, com estatísticas **já
  formatadas pela fonte** (o cliente não calcula “quem é imortal”).
- `HallIndisponivel` — idem.

## Passo 2 — Serviços (interface + implementação honesta)

`app/lib/services/ranking_service.dart`
- `abstract class RankingService { Future<RankingResumo> resumo(...); Future<RankingPagina> pagina(...); }`
- `class RankingSemFonte implements RankingService` — **a implementação que vai no
  APK hoje**: lança `RankingIndisponivel('ranking ainda não publicado por uma fonte oficial')`.

`app/lib/services/hall_service.dart` — mesmo desenho, `HallSemFonte`.

Trocar por uma fonte real depois é substituir a implementação injetada no host.

## Passo 3 — Paginação e apresentação (lógica pura, testável sem widget)

`app/lib/ranking/ranking_paginacao.dart`
- acumulador de páginas com **deduplicação por id** e ordem estável;
- trava de concorrência: pedido em voo não dispara outro igual;
- `fim` reconhecido; **erro na página N não apaga as anteriores** (OS §10);
- `refresh` substitui o conjunto em vez de concatenar.

`app/lib/ranking/ranking_apresentacao.dart`
- `RankingVM` a partir do resumo + páginas. É tradução, **não decisão**: a posição
  exibida é a que veio; nenhuma reordenação, nenhum recálculo de pontos.

## Passo 4 — Ranking ligado

`app/lib/pages/ranking_page.dart` — controlador no molde de `pages/perfil_page.dart`:
estados (`carregando`/`normal`/`vazio`/`erro`), retry, pull-to-refresh, troca de
aba (cada aba com seu próprio acumulador), “Carregar mais”, `dispose` cancelando o
que estiver em voo e ignorando resposta atrasada (`!mounted`).

`RankingScreen` recebe apenas: campo `jogadorId` aditivo em `RankingRow`/`PodioEntry`
e a remoção de `RankingVM.mock()`. **Layout intocado.**

## Passo 5 — Perfil

- `PerfilPage({String? jogadorId})` e `PerfilService.carregar({String? jogadorId})`.
- Ranking → perfil: o host resolve `posicao → jogadorId` na página que já tem;
  id vazio não navega. Sem duplicar lógica de perfil (OS §8).

## Passo 6 — Hall ligado

`app/lib/pages/hall_page.dart` + parâmetros aditivos de estado em `HallScreen`
(`carregando`, `disponivel`, `vazio`, `erro`, `indisponivel`), com a arte
preservada. `HallVM.mock()` sai de `lib/`.

## Passo 7 — `main.dart`

Trocar `_RankingPreviewHost` nos cinco pontos de chamada (`:272`, `:812`, `:894`,
`:995`, `:1614`) e `_HallPreviewHost` no seu (`:2047`). Remover os dois hosts de
prévia. Nenhuma outra rota muda.

## Passo 8 — Testes (`app/test/`)

Cobertura mínima da OS §15, com fakes vivendo **só aqui**: loading · lista
carregada · vazio · erro · retry · jogador local · outro jogador · abertura de
perfil · paginação · fim da paginação · refresh · deduplicação · erro durante
paginação · dispose/listener · Liga vinda do contrato · Hall disponível/vazio/erro
· e o teste explícito de que **a UI não recalcula classificação**: fonte devolve
ordem fora de sequência e a tela repete exatamente o que recebeu.

Superfície de telefone via `app/test/superficie_de_teste.dart` (390×844 e 320×640).

## Passo 9 — Verificação e regressão

- `flutter analyze` e `flutter test` contra a baseline **0 erros · 13 warnings ·
  138 infos** e **151 verdes**;
- regressão visual em 390×844 e 320×640: pódio, abas, cards, nomes longos,
  posição de 1/2/3+ dígitos, scroll, loading, vazio, erro, cabeçalho — sem
  overflow silencioso;
- regressão da Mesa: os 151 testes da base continuam verdes, sem tocar em
  `mesa.dart` nem nos contratos de Mesa.

## Passo 10 — Publicação

Commits temáticos e `git push -u origin integracao/ranking-ligas-hall`.
Sem merge, sem deploy, sem release, sem APK.

---

## O que este plano deliberadamente **não** faz

Nenhum cálculo de posição, pontos, liga, temporada, promoção, rebaixamento,
premiação ou elegibilidade entra no cliente — nem “provisoriamente”. Enquanto não
houver fonte, a tela diz que não há, e o contrato fica pronto para receber.
