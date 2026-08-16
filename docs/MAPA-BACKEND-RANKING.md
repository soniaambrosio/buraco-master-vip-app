# MAPA — Backend autoritativo de Ranking, Ligas e Temporadas

> **ATUALIZADO PELA OS DA POLÍTICA COMPETITIVA V1.** Este documento é o retrato
> da investigação da OS **anterior**, e foi mantido porque explica por que as
> peças têm a forma que têm. Três das ausências que ele registra foram
> **resolvidas** — fórmula de pontuação, faixas de liga e desempate competitivo —
> e estão marcadas abaixo. As demais continuam abertas.
>
> A regra que passou a valer está em
> [`POLITICA-COMPETITIVA-V1.md`](POLITICA-COMPETITIVA-V1.md).
>
> **Divergência de árvore registrada nesta OS:** `integracao/ranking-ligas-hall`
> (`428c458`) **não contém** `af57fe8` — são duas linhas paralelas. Aquela é
> cliente (contratos, telas, Hall) sobre `7a75bab`; esta é backend sobre
> `f9814f9`. Nenhuma foi mesclada na outra, e esta OS não tocou no cliente.

---

Investigação exigida pela seção 5 da OS, feita **antes** de alterar qualquer
arquivo. Registra o que existe, onde existe e o que não existe.

- Repositório: `buraco-master-vip-app`
- Branch de trabalho: `claude/ranking-ligas-backend-auth-ea5ceb`
- Base: `f9814f95ec675d920ff285a135f01154d5cffb48` (`homologacao/p0-integrada-a90557`)

---

## 1. A base, e por que não é `main`

`origin/main` está em `fb9edb5` — um commit chamado *"chore: remover arquivo noop
criado por engano"*, cujo conteúdo é o esqueleto de um projeto Flutter de
exemplo. **Não contém `firebase/`, `functions/` nem `app/lib/`.** A branch desta
OS nasceu dele, como todas as branches de worktree deste repositório, e a
primeira coisa que a investigação fez foi trocar a base.

A seção 5.3 pede uma base em que rastreabilidade, moderação, Functions, Rules,
índices e resultado oficial **coexistam**. Ela já existe, e não foi preciso
montar nenhuma integração nova. Verificado por ancestralidade:

| contém | commit | branch de origem |
|---|---|---|
| consolidação Firebase (Rules + índices + 3 codebases) | `1dc26dd` | `claude/os-integracao-final-backend-flutter-f7aa07` |
| rastreabilidade de partidas | `c2e34ad` | `claude/buraco-vip-game-traceability-3eb66c` |
| moderação | `f25026e` | `claude/moderation-reports-blocking-social-08ef72` |

Os três são **ancestrais** de `f9814f9`. O hash `c2e34adb785c2ee10cb2dfff81cc621160489c2f`
citado na OS é exatamente o da rastreabilidade, e ele já está dentro da base.

> A OS mencionou que a branch de rastreabilidade "pode ser irmã de outras
> implementações". Era: rastreabilidade e moderação eram irmãs sobre o mesmo pai,
> e a homologação P0 as uniu. O cabeçalho de `firebase/firestore.rules` documenta
> a resolução como "conflito de ANEXO, não de conteúdo".

**Consultadas sem merge:** `integracao/ranking-ligas-hall` (`428c458`, só leitura
dos contratos do cliente), `claude/spectator-view-server-enforcement-c154ee`,
`claude/ws-auth-identidade-1fc213`, `origin/codex/ranking-ui`.

---

## 2. Resultado oficial de partida (seção 5.1)

Existe, é completo e é auditável. As respostas às perguntas da OS:

| pergunta | resposta |
|---|---|
| onde a partida é considerada encerrada | `matches/{matchId}`, campo `estado` ∈ `finalizada` / `abandonada` / `cancelada` |
| quem declara o vencedor | a autoridade da partida — o servidor Node/Railway — gravando `ladoVencedor` |
| onde fica a pontuação final | `matches/{matchId}.placar[]`, por lado da mesa |
| identificador único da partida | `matchId`, **adotado** e não cunhado (é o mesmo de `VinculoDeMesa` e `MotorPartida.partidaId`) |
| identificador dos participantes | `participantes[].userId`, com `classe` ∈ `humano` / `robo` / `espectador` |
| pode ser reprocessado | sim, o documento é permanente; a re-escrita divergente é recusada |
| evento final auditável | sim, `matches/{matchId}/events/{eventId}` |

**Quem escreve:** `registrarEncerramentoPartida`, em
[`functions/src/rastreabilidade.ts`](../functions/src/rastreabilidade.ts), exigindo
o claim `motorDePartidas` ou `admin`. Grava registro, eventos, lançamentos, sinais
e histórico do jogador **numa transação só**.

**Formato:** `RegistroDePartida.toJson()`, em
[`app/lib/rastreabilidade/registro_partida.dart`](../app/lib/rastreabilidade/registro_partida.dart).

**Convergência já implementada:** um segundo encerramento **idêntico** responde
sucesso sem regravar; um **divergente** é recusado com `failed-precondition`.

O campo que decide se a partida entra no ranking é `alteraRanking`, denormalizado
na gravação e calculado pelo domínio como `identidade.alteraRanking && estado.valeu`.
`TipoDePartida.alteraRanking` é `publicaRanqueada || torneio` — casual, privada,
treino e contra-robôs nunca pontuam.

---

## 3. Rastreabilidade (seção 5.2)

A camada existe em `app/lib/rastreabilidade/` (8 arquivos, ~160 KB) com 131 testes
em `app/test/rastreabilidade/`. O que interessa a esta OS:

**`rankingLedger` já existe.** A OS pediu, na seção 6, um "registro de contribuição
ao ranking" com antes/delta/depois. Ele estava construído desde a OS anterior:

- coleção `rankingLedger`, id do documento = `matchId|userId|motivo`;
- campos `rankingBefore`, `rankingDelta`, `rankingAfter`, `politica`, `registradoEm`;
- invariante `antes + delta == depois` conferida na construção **e na releitura**;
- Rules já negam toda escrita do cliente.

Esta OS **escreve** nessa coleção e não a redefine.

**A fórmula não existe, e isso está escrito.**
[`ledger_competitivo.dart`](../app/lib/rastreabilidade/ledger_competitivo.dart)
declara:

```dart
static const PoliticaDeRanking pendente =
    PoliticaDeRanking(id: 'nao_definida', versao: 0);
```

com o comentário *"Esta constante é uma PENDÊNCIA DECLARADA, não um valor de
trabalho. O projeto ainda não definiu quantos pontos vale uma vitória"*. Há um
`typedef CalculoDeDelta` com a assinatura pronta e **sem implementação**, e uma
função `deltaZero` marcada como exclusiva de teste.

Ou seja: a seção 7 da OS ("verificar se a fórmula já foi definida") tem resposta
**não**, e a resposta é anterior a esta OS.

> **Resolvido na Política Competitiva v1.** `PoliticaDeRanking.pendente` continua
> existindo como valor legítimo ("ainda não decidido"), mas deixou de ser a
> resposta do projeto: ao lado dela há agora
> `PoliticaDeRanking.competitivaV1 = (id: 'competitiva', versao: 1)`, espelhando
> `POLITICA_COMPETITIVA_V1` do servidor. O `typedef CalculoDeDelta` do Dart
> **continua sem implementação de produção**, e deve continuar: quem calcula
> delta é a autoridade, nunca o cliente (§28).

---

## 4. Consolidação Firebase (seção 5.3)

Tudo presente na base:

```
firebase.json              4 codebases declarados (agora 5)
firebase/firestore.rules   685 linhas, 5 blocos (agora 6)
firebase/firestore.indexes.json
firebase/functions/        codebase `colecoes`  (JS)
functions/                 codebase `torneios`  (TS + ponte Dart)
functions-billing/         codebase `billing`   (JS)
functions-moderacao/       codebase `moderacao` (TS + ponte Dart)
firebase/testes/           suítes de Rules contra o emulador
```

O princípio declarado no `firebase.json` é que cada frente é **unidade de
implantação independente** — *"um deploy de moderação não pode derrubar a
inscrição em torneio nem a validação de compra"*. Esta OS acrescenta um quinto
codebase, `functions-ranking`, pelo mesmo motivo.

O fecho de `firestore.rules` já antecipava esta OS por escrito: *"Qualquer caminho
não declarado acima é negado, inclusive coleções futuras de perfil, amigos, loja
ou **ranking**. Cada uma precisará do próprio bloco `match`."*

---

## 5. O que NÃO existia

A investigação confirmou a seção 4 da OS, e foi além dela.

> **Estado atualizado após a Política Competitiva v1:** as linhas de *fórmula de
> pontuação* e *liga* foram **resolvidas** — há Elo v1 versionado em
> `functions-ranking/src/elo.ts` e as sete faixas oficiais em `DEGRAUS_V1`. Todas
> as outras linhas da tabela **continuam como estão**: identidade pública já
> existia desde a OS anterior; Hall, fonte de apelido/avatar e grafo social
> continuam sem existir, e esta OS não os criou.

| conceito | situação encontrada |
|---|---|
| fórmula de pontuação | **não existe**, e está declarada como pendente no domínio — *resolvido na v1* |
| temporada de ranking | **não existe**. `temporada` aparece em `annualQualifications` e `closingInvites`, mas ali é um campo de **texto livre** que o Motor de Torneios usa como rótulo de agrupamento anual — não é uma entidade, não tem início, fim nem status |
| liga | **não existe** como dado. Existem 7 arquivos de arte (`liga_bronze` … `liga_lenda`) na branch do cliente, e nada mais. Sem lista oficial, sem faixas, sem promoção/rebaixamento |
| posição oficial | **não existe** |
| classificação consolidada | **não existe**. Há o ledger (a sequência), não há o saldo consolidado nem a lista ordenável |
| identificador público | **não existe**. `publicPlayerId` aparece só em modelos de tela de torneios |
| Hall dos Imortais | **não existe**, em nenhuma forma |
| fonte de apelido/avatar | **não existe no backend**. `users/{uid}` só tem subcoleções (inventário, histórico, bloqueios); nenhum documento de perfil com nome ou avatar |
| grafo social (amigos) | **não existe**. `users/{uid}/blocks` e `/mutes` são da moderação e listam quem o jogador **não** quer ver — o oposto de uma lista de amigos |

As três últimas linhas não estavam na OS e são dependências reais do contrato do
cliente. Estão no relatório final como pendências.

---

## 6. O que o cliente já espera receber

Lido de `integracao/ranking-ligas-hall` (`428c458`), **sem modificar a branch**.

- [`app/lib/ranking/ranking_contract.dart`](#) — `RankingJogador`, `RankingPagina`,
  `RankingResumo`, `RankingAbertura`, `RankingIndisponivel`, enums `RankingEscopo`
  (`temporada`/`global`/`amigos`) e `RankingDirecao` (`subiu`/`desceu`/`estavel`).
- `app/lib/services/ranking_service.dart` — a interface `RankingService` com
  `abrir(escopo)` e `proximaPagina(escopo, cursor)`. Implementação embarcada:
  `RankingSemFonte`, que **declara a ausência**.
- `app/lib/hall/hall_contract.dart` — `HallCategoria` (5 valores), `HallHonrado`,
  `HallQuadro`, `HallIndisponivel`.
- `app/lib/services/hall_service.dart` — `HallService.quadro()`, com `HallSemFonte`.

O contrato do cliente já resolve, por conta própria, três coisas que esta OS
precisava respeitar: paginação por cursor opaco com dedupe, `souEu` vindo da fonte
(*"o cliente não adivinha por apelido"*) e `fim` como **afirmação da fonte** e não
dedução de página vazia.

O mapeamento completo backend → contrato está em
[`CONTRATO-RANKING-CLIENTE.md`](CONTRATO-RANKING-CLIENTE.md).

---

## 7. Decisões que a investigação forçou

**Temporada de ranking ≠ temporada de torneios.** Não foram unificadas. Fundir as
duas exigiria decidir que a virada do ranking acontece junto com o encerramento
anual de torneios — decisão de produto que não consta em lugar nenhum. Ficam
separadas, e a pergunta fica registrada.

**A posição é atribuída, não calculada na leitura.** O Firestore não tem `rank()`,
e contar quantos estão acima de um jogador custa uma leitura por jogador acima
dele — a varredura que a seção 19 proíbe. A posição sai de uma passagem de
apuração e é lida pronta. A consequência honesta: a posição é a da última
apuração, não a deste milissegundo. É também o que torna `direcao` e `delta` do
contrato do cliente definíveis.

**A regra competitiva é código, não configuração.** Uma fórmula digitada num
documento do Firestore seria editável sem revisão, sem teste e sem histórico, e
mudaria a pontuação de todo mundo entre duas leituras. O que fica em documento é
**qual** política uma temporada usa; o que ela calcula entra por deploy versionado.

> A v1 estendeu essa mesma decisão às **faixas de Liga**: `lerEscada` consulta o
> registro em código **antes** do Firestore, para que um documento adulterado em
> `rankingLadders` não consiga rebaixar ninguém.

---

## 8. Arquivos fora de lugar

Nenhum novo. Os dois `.dart` dentro de `app/assets/` registrados pela OS anterior
continuam lá e continuam não removidos — esta OS não tocou em `app/`.
