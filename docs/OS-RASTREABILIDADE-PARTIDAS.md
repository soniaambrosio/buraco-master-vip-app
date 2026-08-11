# Rastreabilidade de Partidas, Histórico Auditável e Base Antifraude

Documentação técnica da OS de Rastreabilidade (§38). Cobre identidade, ciclo de
vida, histórico, ranking, idempotência, antifraude, segurança e dependências.

A pergunta que esta camada existe para responder, sem depender da palavra do
cliente:

> **O que aconteceu nesta partida, quem participou, qual foi o resultado e por
> que o ranking deste jogador mudou?**

E, para antifraude: **registrar evidência primeiro, julgar depois.**

---

## 0. Mapa da auditoria inicial (§2)

Levantado antes de escrever qualquer código, sobre
`claude/os-integracao-final-backend-flutter-f7aa07` (`1dc26dd`).

| Item auditado | Antes | Onde estava |
|---|---|---|
| Onde nasce uma partida | **Parcial** | 3 nascedouros: torneio (`matchIdDaMesa` → `AdaptadorMotorDePartidas.solicitarPartida` → `RegistroDePartidas.abrir`); `Jogo` local sem id; servidor Node via `online_service.dart` (mesa por código, fora do repo) |
| Identificador da partida | **Parcial** | `matchId` só no caminho de torneio, derivado do `mesaId` (`match-<mesaId>`). Casual/privada/treino: **inexistente** |
| Onde termina | **Existe** | `capturarDesfecho` → `DesfechoCanonicoPartida` |
| Participantes persistidos | **Parcial** | `VinculoDeMesa` existe e é explícito, mas vive em memória e não é persistido |
| Modalidade / tipo de sala | **Parcial** | `Jogo.modalidade` (`ABERTO`/`FECHADO`/`SBTL`). Tipo competitivo da partida: **inexistente** |
| Pontuação calculada | **Existe** | `Jogo.contarPontos()` |
| Ranking alterado | **Inexistente** | `ranking_screen.dart` é maquete de UI. Sem coleção, sem ledger, sem `before/delta/after` |
| Abandono / desconexão | **Parcial** | `MotivoSaida` e `RegistroAbandono` existem como DTO lido do servidor; nada persiste |
| Reconexão | **Existe** | `SessaoReconexao`, idempotência por `eventoId`, monotonia de `versaoEstado` |
| Eventos do Motor | **Existe** | `DiarioPartida`, circular (400), em memória, **não persiste** |
| Dados após encerramento | **Parcial** | Só torneio: `results/{chave}` e `tournamentHistory` |
| Histórico do jogador | **Inexistente** | Só existia histórico de **edição de torneio** |
| Histórico administrativo | **Parcial** | `tournamentAudit`, só transições de edição |
| Registros de início/fim | **Parcial** | `encerradaEm` existia; `createdAt`/`startedAt` **inexistentes** |
| IDs de rodada | **Parcial** | `Jogo.rodada` + `MotorPartida.versaoEstado`; sem `roundId` |
| Casual / ranqueada / privada / torneio / robôs | **Inexistente** | Nenhuma distinção em lugar nenhum |
| Trilha de alterações de score/ranking | **Inexistente** | — |
| Estrutura antifraude | **Inexistente** | — |

**Consequência de projeto:** o que existia era *sólido e não foi refeito*
(identidade de torneio, desfecho canônico, vínculo, diário, idempotência do
motor). O que faltava era tudo que vive **depois** do fim da partida.

---

## 1. Identidade (§3, §4)

### Antes

`SolicitacaoPartida.matchId` era gerado pelo **torneio** (`matchIdDaMesa`, em
`seating.dart`, como `match-<mesaId>`) e atravessava `MotorPartida.partidaId`,
`VinculoDeMesa.matchId` e `ResultadoPartida.matchId` — o mesmo texto, um
namespace só. Reconexão já mantinha o id porque `RegistroDePartidasEmMemoria.abrir`
devolve a mesa existente em vez de abrir outra.

Faltava: id para partida **não-torneio**, validação de formato, e registro de
**quem cunhou** o id.

### Agora

`IdentidadePartida` (`app/lib/rastreabilidade/identidade_partida.dart`):

```dart
IdentidadePartida.cunhada(matchId:, tipo:, origem:, modalidade:, criadaEm:)
IdentidadePartida.deTorneio(matchId:, modalidade:, criadaEm:)   // ADOTA o id do torneio
IdentidadePartida.doCliente(proposto)                            // SEMPRE lança
```

- **Um namespace só.** `deTorneio` adota o `matchId` existente; não há tradução,
  prefixo novo nem mapa de-para.
- **Formato validado:** `^[a-z0-9][a-z0-9_-]{7,63}$`. O alfabeto exclui `@`,
  `.`, `/` e `:` — os caracteres de e-mail, caminho e URL, que é como dado
  sensível entra num identificador.
- **Prefixos reservados:** `admin-`, `sistema-`, `srv-`, `suporte-`.
- **`doCliente` sempre lança.** É função, e não comentário, para ser testável e
  para que quem ligar um endpoint novo encontre o símbolo em vez de improvisar.
- **Origem declarada:** `torneio` | `servidor` | `local`. Identidade `local`
  **não pode** valer ranking — recusa no construtor.

### Rodada

`IdentidadeRodada` é **derivada, nunca cunhada**:

```
roundId = "<matchId>#r<numero>"
```

Deriva de `Jogo.rodada` e `MotorPartida.versaoEstado`, que já existiam. **Nenhum
campo novo foi pedido ao Motor** (§4 proíbe alterar o protocolo por causa desta
OS). O `#` está fora do alfabeto de `matchId`, então um `roundId` nunca é
confundido com um `matchId`.

`versaoEstado` viaja ao lado do id, e não dentro dele: o id precisa ser estável
durante a rodada inteira, e a versão sobe a cada jogada.

---

## 2. Ciclo de vida (§22, §23)

```
criada ──▶ aguardando ──▶ ativa ──▶ reconectando
   │            │           │  │         │
   │            │           │  └────◀────┘
   ▼            ▼           ▼
cancelada   abandonada   finalizada / abandonada / cancelada
```

- `ativa → aguardando` **não existe**: assento que esvaziou no meio é
  `reconectando`; voltar a `aguardando` faria a mesa parecer que nunca começou.
- Estado terminal (`finalizada`, `abandonada`, `cancelada`) **não transiciona
  mais** (§23). Não há setter para placar, vencedor, participantes ou tipo.
- `transicionarPara(mesmoEstado)` é idempotente — devolve o próprio registro.
- Correção administrativa é fluxo separado e auditável, **não implementado nesta
  OS** de propósito. O motivo `MotivoLancamento.correcaoAdministrativa` já existe
  no ledger para quando ele chegar.

O mapeamento de `MotivoEncerramento` (do Motor) para estado é total e explícito:

| `MotivoEncerramento` | `EstadoDaPartida` | Vale? | Pontua? |
|---|---|---|---|
| `metaAtingida` | `finalizada` | sim | se o tipo pontuar |
| `encerradaPorAdmin` | `finalizada` | sim | se o tipo pontuar |
| `abandono` | `abandonada` | sim | se o tipo pontuar |
| `anulada` | `cancelada` | **não** | **não** |

---

## 3. Modelo do registro da partida (§5)

`matches/{matchId}` — **todos os campos server-owned.**

| Campo | Origem |
|---|---|
| `matchId`, `identidade{tipo, origem, modalidade, criadaEm}` | `IdentidadePartida` |
| `estado` | grafo de `EstadoDaPartida` |
| `participantes[]` | `VinculoDeMesa` (torneio) ou declaração explícita |
| `userIdsCompetidores[]` | denormalizado — `array-contains` não alcança campo aninhado |
| `criadaEm`, `iniciadaEm`, `encerradaEm` | servidor |
| `motivoEncerramento`, `autoridadeDoEncerramento` | `DesfechoCanonicoPartida` / `OrdemDeEncerramento` |
| `ladoVencedor`, `placar[]` (pontos, canastras, assentos) | **copiados** do desfecho |
| `metaPontos`, `rodadas`, `versaoEstadoFinal`, `impressaoEstado` | desfecho |
| `temRobo`, `alteraRanking` | derivados |
| `tournamentId`, `editionId`, `faseId`, `mesaId` | vínculo, só em torneio |

**Nada é recalculado.** Placar, vencedor e canastras são cópias — se aparecer uma
conta neste arquivo, ela está no lugar errado.

### Tipo da partida (§6)

`TipoDePartida`: `publica_casual`, `publica_ranqueada`, `privada`, `torneio`,
`treinamento`, `contra_robos`.

`alteraRanking` é **verdadeiro só** para `publica_ranqueada` e `torneio`. Esta é
a **única** definição de "vale ranking" no sistema. O tipo é dado de **criação**,
imutável, e nunca inferido do resultado.

`privada` não pontua de propósito: quem cria a sala escolhe os adversários, o que
torna a pontuação combinável por construção. `contra_robos` não pontua porque
seria a forma mais barata de farmar ranking que existe.

### Participantes (§7)

`ClasseDeParticipante`: `humano` | `robo` | `convidado` | `espectador`.

Invariantes travadas no construtor:

- competidor **exige** assento 0..3; espectador **não pode** ter assento;
- robô **exige** `botId` e **não pode** ter `userId` (humano disfarçado no
  relatório);
- humano **exige** `userId` e **não pode** ter `botId`;
- a mesma conta não ocupa dois assentos (auto-jogo);
- dois participantes não declaram o mesmo assento;
- um assento que o torneio deu a uma pessoa **não pode** ser declarado robô.

`pontuavel` é verdadeiro **só** para `humano`.

---

## 4. Eventos auditáveis (§8, §9)

**§9 é o arquivo inteiro.** O Motor já tem `eventoId`, janela de idempotência,
`versaoEstado` e trilha técnica (`DiarioPartida`). Nada disso foi redefinido.

`eventos_auditaveis.dart` é um **adaptador de persistência**: pega o que o diário
já produziu, seleciona o que merece sobreviver ao fim da partida, e carimba o que
o diário (memória, circular, por partida) não tem como saber.

| Campo | De onde vem |
|---|---|
| `eventId` | reaproveita o `eventoId` do Motor quando existe; senão deriva de `partida:acao:rodada:versao:seq` |
| `matchId` | `EventoDiagnostico.partidaId` — mesmo namespace |
| `tipo` | classificação por **momento de vida**, não por natureza técnica |
| `emServidor` | carimbo **autoritativo**, aplicado na ingestão |
| `tsMotor` | o carimbo do diário, guardado **ao lado** — a diferença entre os dois é sinal técnico |
| `ator` | `{classe, id, assento}` |
| `rodada`, `versaoEstado` | do diário |
| `dados` | sanitizado (ver Privacidade) |
| `esquema` | versão do formato |

`TipoEventoAuditavel`: `criacao`, `inicio`, `entrada_participante`,
`inicio_rodada`, `fim_rodada`, `desconexao`, `reconexao`, `abandono`,
`encerramento`, `resultado`, `alteracao_competitiva`, `integridade`,
`restauracao`.

**O que fica de fora, de propósito:** jogada a jogada. São centenas por partida e
o valor de auditoria delas é a reclamação em tempo real, que o diário já atende
enquanto a partida vive. O que sobrevive é o esqueleto. A seleção é **lista
branca** (`_classificar`): ação nova do Motor cai fora até alguém decidir que
pertence à trilha.

O encerramento gera **dois** eventos, não um: `encerramento` (por que a mesa
fechou) e `resultado` (qual foi o placar). Perguntas diferentes não devem depender
do mesmo registro.

---

## 5. Histórico (§11, §15)

Duas **projeções** do mesmo registro, construídas por funções distintas — não é
filtro de tela:

### Visão do jogador — `users/{uid}/matchHistory/{matchId}`

`projetarParaJogador(registro:, userId:, lancamento:)` → `EntradaHistorico`:
`matchId`, `data`, `tipo`, `modalidade`, `resultado`, `pontosMeuLado`,
`pontosOutroLado`, `rankingDelta`, `houveAbandono`, `abandonoFoiMeu`, `assento`,
`lado`, `competidores` (contagem), `robos` (contagem), `tournamentId`,
`editionId`.

**O jogador NUNCA vê**, nem do próprio histórico: `impressaoEstado`,
`versaoEstadoFinal`, `autoridadeDoEncerramento`, a lista de participantes,
eventos técnicos, sinais antifraude, ou o ledger de terceiros.

**UID de terceiros não entra.** Só contagens. Quem resolve apelido é a camada de
perfil, com a política de privacidade dela — não uma consulta de histórico que
qualquer um faria em massa.

`rankingDelta` é `null` em partida que não pontua. **`null` significa "não se
aplica", nunca zero.**

### Visão administrativa — `matches/{matchId}`

`montarVisaoAdministrativa(autenticado:, nivel:, registro:, ...)`:

| `NivelAcesso` | registro | eventos | lançamentos | sinais |
|---|---|---|---|---|
| `jogador` | **recusado** | — | — | — |
| `suporte` | sim | sim | não | não |
| `administrador` | sim | sim | sim | sim |

**§14 literalmente:** `NivelAcesso.jogador` é recusado **sem exceção**, inclusive
quando ele participou da partida. Conhecer o `matchId` não abre nada.

---

## 6. Ranking: before / delta / after (§12, §13)

`rankingLedger/{matchId|userId|motivo}` — modelo **ledger**, não saldo.

```
rankingBefore + rankingDelta = rankingAfter
```

Conferido **no construtor**, não documentado e torcido para dar certo. Um
lançamento incoerente gravado uma vez envenena todo saldo derivado dele.

Campos: `chaveIdempotencia`, `matchId`, `userId`, `motivo`, `rankingBefore`,
`rankingDelta`, `rankingAfter`, `registradoEm`, `politica{id, versao}`,
`autoridade`.

- **O saldo é a dobra da sequência.** Não há campo `_saldo` a manter em sincronia
  — o que não existe não pode divergir.
- `LedgerCompetitivo.reconstruir` recusa **cadeia rompida**: o `antes` de cada
  lançamento tem que ser o `depois` do anterior. Transforma "a soma bate" em "a
  SEQUÊNCIA bate".
- `conferir()` devolve o primeiro ponto de ruptura, ou `null`.
- **Estorno é lançamento novo, de sinal contrário, com autoridade declarada** —
  nunca apagamento. Apagar histórico é o oposto de ledger.
- `MotivoLancamento`: `resultado_de_partida`, `abandono_declarado`,
  `correcao_administrativa`, `estorno`. Os dois últimos **exigem** autoridade; os
  dois primeiros **não podem** tê-la.

### Escopo

**Só pontuação competitiva / ranking / estatística de partida.** Fichas,
economia, entitlement, VIP e catálogo **não passam** por aqui — são do Play
Billing, em `functions-billing/`, que esta OS não tocou.

### Pendência declarada de produto

`PoliticaDeRanking.pendente` — **a fórmula não existe.** Quanto vale uma vitória,
quanto custa um abandono, se há proteção de série ou piso de divisão: tudo isso é
decisão de produto e §17 proíbe inventar regra sem validação.

A infraestrutura está pronta e testada; o caminho de produção fica **desligado**.
Com `politica.definida == false`, `ingerirEncerramento` **não produz lançamento
nenhum** e a partida encerra normalmente. Nenhum número é inventado.

O tipo `CalculoDeDelta` declara a assinatura esperada para quem for implementar:

```dart
typedef CalculoDeDelta = int Function({
  required RegistroDePartida registro,
  required String userId,
  required int saldoAtual,
});
```

---

## 7. Idempotência (§10)

**Toda escrita tem id de documento determinístico.** Gravar duas vezes o mesmo
dado é a mesma escrita — a duplicidade é impossível **por construção**, não por
checagem. É a disciplina que `rewardGrants` e `tournamentTasks` já usam.

| Coleção | Id do documento |
|---|---|
| `matches` | `matchId` |
| `matches/{id}/events` | `eventId` |
| `rankingLedger` | `matchId\|userId\|motivo` |
| `fraudSignals` | `matchId\|tipo\|alvos-ordenados` |
| `users/{uid}/matchHistory` | `matchId` |

Detalhes que fazem diferença:

- O `eventId` do encerramento usa sufixo **`v<versaoEstado>`**, não contador:
  dois encerramentos concorrentes tirados do mesmo estado produzem o **mesmo**
  `eventId`.
- A chave do ledger inclui o **motivo**, para que estorno e resultado da mesma
  partida sejam lançamentos distintos.
- A chave do sinal ordena os alvos, então `[b, a]` e `[a, b]` colidem — como
  devem.

---

## 8. Concorrência e finalização atômica (§20, §21)

`ingerirEncerramento(...)` devolve um **`PlanoDeEncerramento`**: registro,
eventos, lançamentos e sinais, já coerentes entre si. O servidor grava numa
transação — se falhar, nada foi gravado; se passar, tudo foi.

`PlanoDeEncerramento.conferir()` roda **antes de qualquer gravação** e falha alto
(`StateError`, não recusa) se o plano for incoerente: plano incoerente não é
entrada ruim do cliente, é defeito desta camada, e devolver "recusado" esconderia
um bug atrás de uma mensagem de validação.

### Regra de convergência

| Situação | Resultado |
|---|---|
| Partida aberta | encerra, `houveMudanca: true` |
| Terminal, **mesmo** desfecho | `houveMudanca: false`, sem eventos, sem lançamentos, **sem erro** |
| Terminal, desfecho **divergente** | `RecusaIngestao.desfechoDivergente` |

"Mesmo desfecho" = mesmo motivo **e** mesmo `ladoVencedor` **e** mesma
`impressaoEstado`. A impressão é o que impede um desfecho de outro momento da
partida passar por idêntico.

**Duas barreiras independentes** para ranking duplo: a do registro (terminal não
reencerra) e a do ledger (chave já lançada). Testadas separadamente — `DUP-05`
prova que o ledger segura mesmo se o registro fosse "esquecido".

A mesma regra de convergência está repetida na Cloud Function, no nível do banco,
porque dois processos diferentes chegariam os dois até a transação.

---

## 9. Reconexão (§19, §32)

`registrarReconexao(...)` **devolve um evento**, não um registro. Não existe
caminho por onde ela crie partida, gere segundo `matchId`, duplique participante
ou reabra mesa — **não porque tenha um `if`, mas porque a assinatura não permite**:
ela recebe a identidade pronta e retorna `EventoAuditavel`.

- Reconexão sobre partida encerrada é evento **normal**, não erro: o cliente que
  estava offline quando a mesa fechou precisa descobrir isso.
- O sufixo do `eventId` inclui `t<tentativa>`, porque múltiplas reconexões do
  mesmo assento são eventos **diferentes** — colapsá-las esconderia uma conexão
  instável.
- A mesma reconexão reenviada é idempotente.
- Fila antiga reenviada depois do fim: `houveMudanca: false`, ranking intacto
  (teste `REC-07`, com três reenvios).

O que já existia e foi **reutilizado, não refeito**: `SessaoReconexao`
(reenvio com `eventoId` estável), a janela de idempotência de `MotorPartida`, e a
recusa de visão com versão menor.

---

## 10. Abandono (§18, §33)

**Desconexão não é abandono.** A trava é herdada do Motor e é mecânica:
`PoliticaPresenca` **não sabe produzir** estados terminais — `abandonou` e
`substituidoPorRobo` são inalcançáveis a partir de silêncio de rede.

`ClassificacaoDeSaida` é a face de auditoria de `MotivoSaida`:

| Classificação | `podeSerAbandono` | Vira evento |
|---|---|---|
| `voluntaria` | sim | `abandono` |
| `queda_de_conexao` | **não** | `desconexao` |
| `timeout_de_turno` | **não** | `desconexao` |
| `nao_retornou` | sim | `abandono` |
| `encerramento_normal` | não | `abandono` (registro, não decisão) |
| `encerramento_administrativo` | não | idem |
| `falha_tecnica` | não | idem |

E mesmo `podeSerAbandono == true` **não encerra nada**: quem produz
`MotivoEncerramento.abandono` é a `OrdemDeEncerramento`, emitida por autoridade
explícita. `registrarSaida` grava `encerraPartida: false` no próprio evento, para
que quem ler o documento no banco saiba que ele não decidiu nada.

Abandono e reconexão concorrentes: o encerramento por ordem vence, a reconexão
fica na trilha, e a história inteira é reconstituível (teste `ABA-06`).

---

## 11. Antifraude (§16, §17, §35)

**Registrar evidência primeiro, julgar depois.**

`fraudSignals/{chave}` — `SinalAntifraude`: `suspectedPattern`, `matchId`
(obrigatório), `alvos[]`, `observadoEm` (server-side, UTC), `intensidade`,
`evidencia{}`, `observacao`, `origem`, **`geraPunicao: false`**.

O campo `geraPunicao` é gravado no documento de propósito: um leitor futuro não
precisa conhecer este código para saber que o registro não é uma condenação.

O nome do campo é **`suspectedPattern`**, e não `pattern`, exatamente como §17
pede — quem ler o documento cru lê "suspeita", não "fato".

### Padrões estruturados

`mesma_dupla_recorrente`, `resultados_concentrados`, `abandono_coordenado`,
`abandono_ao_perder`, `contas_correlacionadas`, `ganho_de_ranking_atipico`,
`sequencia_improvavel`, `robo_em_partida_pontuada`,
`manipulacao_de_evento_tentada`, `divergencia_de_relogio`.

O vocabulário descreve o **dado**, nunca a pessoa: `mesmaDuplaRecorrente`, não
`conluio`. Há teste que varre os nomes procurando "fraude", "trapaça", "culpado",
"punição", "suspenso".

### Detectores implementados

Só os que os dados **desta OS** já sustentam sem depender de regra de produto:

1. **`observarRoboEmPartidaPontuada`** — observável só agora, porque §7 passou a
   distinguir robô de humano e §6 passou a registrar se a partida pontua. Antes
   desta OS a pergunta era irrespondível. Não é acusação: há motivos legítimos
   (substituição autoritativa por ausência).
2. **`observarMesmaDuplaRecorrente`** — recebe as contagens por parâmetro; quem
   conta é a consulta indexada, fora do caminho crítico (§36).
3. **`observarManipulacaoTentada`** — nasce de recusa da validação server-side.

`sinalDeRecusa` só emite para recusas que `sugereManipulacao`:
`semAutoridade`, `matchIdDivergente`, `desfechoDivergente`, `estadoDivergente`.
**Não emite** para `naoAutenticado`, `campoInvalido`, `campoDesconhecido`,
`partidaInexistente`, `jaIngerido` — app desatualizado produz exatamente isso, e
transformar bug em suspeita é o oposto do que §17 pede.

### O que propositalmente NÃO gera punição

**Nada gera.** Não existe, em lugar nenhum desta camada:

- campo `culpado`, `fraudador`, `trapaceiro`, `multiConta`, `userIsFraudster`;
- função que suspenda, bloqueie, remova, penalize ou desclassifique;
- limiar que transforme score em decisão;
- qualquer escrita fora de `SinalAntifraude` e `RegistroDeSinais`.

`IntensidadeSinal` (`baixa`/`media`/`alta`) é **prioridade de fila de
investigação**, não probabilidade de culpa. Não existe um quarto grau que
signifique "confirmado" — e há teste que afirma isso.

---

## 12. Segurança (§24, §25, §26)

### Firestore Rules — bloco 4/4

**Não há um único `allow write` verdadeiro no bloco.** Resposta a §24, item por
item:

| §24 exige que o jogador não possa | Onde é negado |
|---|---|
| criar partida finalizada falsa | `matches` create |
| editar resultado | `matches` update |
| editar histórico | `users/{uid}/matchHistory` |
| aumentar a própria pontuação | `rankingLedger` write |
| diminuir a de terceiros | idem |
| alterar participantes | `matches` update |
| criar evento administrativo | `matches/{id}/events` write |
| apagar partidas | `matches` delete |
| apagar trilha competitiva | `rankingLedger` delete |
| marcar-se vencedor | `matches` write |
| consultar dados administrativos de terceiros | leituras restritas abaixo |

| Coleção | Leitura |
|---|---|
| `matches` | **só admin** — nem o participante da partida |
| `matches/{id}/events` | só admin |
| `rankingLedger` | o dono do lançamento, ou admin |
| `fraudSignals` | **só admin** — nem o próprio citado |
| `users/{uid}/matchHistory` | o dono, ou admin |

`fraudSignals` restrito ao admin **protege o alvo**: sinal é suspeita, e expô-la
ao citado ou a terceiros transformaria observação estatística em acusação.

Escrita negada **também para o admin pelo cliente**: a trilha não pode ser
plantada nem limpa por quem for investigado ou investigar. Toda escrita passa
pelo Admin SDK, que ignora estas regras.

### Validação server-side (§25)

`validarEnvelope(envelope, chamador:)`:

- autenticação e **papel** (`motorDePartidas` | `admin`) — do **claim do token**,
  nunca de campo no payload;
- **campo desconhecido é RECUSA**, não "ignorado". Lista branca
  (`camposDeEncerramento`), não lista negra — lista negra envelhece mal, porque
  campo novo do atacante nunca está nela;
- `matchId` presente e não vazio; desfecho presente e **conclusivo**;
- o desfecho é validado por `DesfechoCanonicoPartida.deJson`, que já existe e é
  testado — reescrever a validação criaria uma segunda definição de "desfecho
  válido".

### Anti-tampering (§26)

- **vencedor / placar / canastras:** copiados do desfecho do Motor, nunca do
  cliente;
- **`rankingDelta`:** o cliente não o envia; ele é calculado pela política a
  partir do saldo lido no servidor. Sem política, não há delta;
- **troca de `matchId`:** o desfecho é confrontado com o registro; divergência é
  recusa;
- **resultado de outra partida:** idem;
- **assento no lado errado:** o desfecho é confrontado com os assentos do
  registro (`estadoDivergente`);
- **reaplicar resultado antigo em partida nova:** recusado por `matchId`;
- **trocar o tipo da partida:** não há setter, e o tipo viaja dentro da
  identidade imutável.

---

## 13. Índices (§27)

### Criados (`firebase/firestore.indexes.json`)

| Coleção | Campos | Para quê |
|---|---|---|
| `matches` | `userIdsCompetidores` (array) + `encerradaEm` ↓ | partidas de um jogador |
| `matches` | `userIdsCompetidores` (array) + `tipo` + `encerradaEm` ↓ | ganho de ranking atípico |
| `matches` | `estado` + `encerradaEm` ↓ | mesas presas / volume por janela |
| `matches` | `motivoEncerramento` + `encerradaEm` ↓ | abandonos por período |
| `rankingLedger` | `userId` + `registradoEm` ↑ | o extrato, na ordem de leitura |
| `rankingLedger` | `matchId` + `registradoEm` ↑ | lançamentos de uma partida |
| `fraudSignals` | `alvos` (array) + `observadoEm` ↓ | fila de investigação |
| `fraudSignals` | `suspectedPattern` + `intensidade` + `observadoEm` ↓ | priorização do operador |

### Não criados de propósito

Servidos pelos **índices automáticos de campo único** do Firestore — declará-los
seria criar índice que o Firestore já mantém:

- `users/{uid}/matchHistory` ordenado por `data`;
- `matches/{id}/events` ordenado por `emServidor`;
- `fraudSignals` filtrado por `matchId`.

### Recomendados, ainda sem consulta correspondente

Documentados aqui e **não criados**, porque índice sem consulta é custo de
escrita sem benefício:

- `matches`: `tournamentId` + `editionId` + `encerradaEm` — auditoria por edição,
  quando o painel administrativo de torneio existir;
- `matches`: `tipo` + `estado` + `criadaEm` — painel operacional por modalidade;
- `rankingLedger`: `userId` + `motivo` + `registradoEm` — extrato filtrado por
  tipo de lançamento, quando houver correção administrativa em produção;
- `fraudSignals`: `origem` + `observadoEm` — revisão de tudo que um detector
  específico produziu, necessária quando um detector for corrigido.

---

## 14. Retenção (§28)

**Nenhuma política destrutiva foi implementada.** Nada apaga dado nesta OS.
Levantamento, para decisão de produto:

| Registro | Necessário para | Cresce | Recomendação |
|---|---|---|---|
| `matches` | suporte, histórico, competição | linear com partidas jogadas | manter; é a espinha da auditoria |
| `matches/{id}/events` | investigação técnica | ~10–30 por partida (só o esqueleto) | **candidato a TTL** — 12 a 24 meses cobre qualquer chamado |
| `rankingLedger` | explicar a pontuação | 1 por jogador por partida ranqueada | manter enquanto a temporada valer; arquivar por temporada |
| `users/{uid}/matchHistory` | histórico do jogador | linear por jogador | manter; é produto |
| `fraudSignals` | integridade competitiva | esparso | manter; volume baixo e valor alto |

**Proposta, não implementada:** TTL no Firestore para `matches/{id}/events` e
arquivamento por temporada do `rankingLedger`. Requer decisão de produto sobre
prazos legais e de suporte.

---

## 15. Observabilidade (§37)

Reutiliza o `logger` de `firebase-functions` que as Functions já usam. **Nenhum
sistema de log concorrente foi criado.**

Os logs desta OS carregam: `matchId`, `estado`, contagens de eventos/lançamentos/
sinais, e o padrão do sinal. **Não carregam:** token, credencial, conteúdo de
carta, e-mail — e, no log de sinal antifraude, **nem o alvo**: log de
observabilidade não é lugar de lista de suspeitos.

O `EventoAuditavel` aplica uma **segunda barreira** de sanitização sobre a que o
`DiarioPartida` já faz. As duas listas são independentes de propósito: exportar a
do Motor exigiria mexer nele, o que §1 proíbe. A desta camada é um
**superconjunto** (acrescenta `nome`, `avatar`, `ip`), e há teste que prova a
cobertura. **Dependência declarada:** se a lista do Motor crescer, esta precisa
crescer junto.

---

## 16. Privacidade (§15)

- **Visão do jogador** e **visão administrativa** são funções distintas com
  saídas distintas, não um filtro.
- UID de terceiros não entra no histórico do jogador — só contagens.
- Cartas, mãos, monte, morto e baralho **nunca** são persistidos. O diário do
  Motor já os censurava; a camada de persistência censura de novo.
- Onde a mão precisa ser referenciada tecnicamente, o que viaja é a **impressão
  digital** (`impressaoDaMao`, `impressaoEstado`) — prova que o estado não mudou
  entre dois pontos sem expor carta nenhuma.
- Não há repositório indiscriminado de informação privada: a evidência antifraude
  é sanitizada com lista própria (`SinalAntifraude.chavesProibidas`), porque é
  justamente o lugar onde alguém seria tentado a "guardar tudo por via das
  dúvidas".

---

## 17. Dependências e fronteiras

### O que continua sendo do Motor de Partidas

- regras do buraco, distribuição, pontuação de rodada, canastras (`mesa.dart`);
- `eventoId`, janela de idempotência, `versaoEstado`, `DiarioPartida`;
- `capturarDesfecho` e `DesfechoCanonicoPartida` — a porta canônica de
  encerramento;
- `PoliticaPresenca` e a fronteira "o cliente desconfia, o servidor declara".

**Nenhum arquivo de `app/lib/motor/` ou `app/lib/integracao/` foi alterado.** A
seta aponta em um sentido só: `rastreabilidade` lê `motor` e `integracao`; eles
não sabem que ela existe.

### O que é do servidor Node/Railway (fora deste repositório)

A autoridade da partida. Ele é quem:

- cunha o `matchId` das partidas não-torneio (`IdentidadePartida.cunhada`);
- declara abandono, encerramento administrativo e anulação
  (`OrdemDeEncerramento`);
- monta o `PlanoDeEncerramento` e chama `registrarEncerramentoPartida`.

Contrato do que ele precisa implementar: `docs/MOTOR-PARTIDAS-PROTOCOLO-SERVIDOR.md`
mais as funções deste documento.

### O que é do Motor de Torneios

Classificação, fase, premiação, `tournamentHistory`. A rastreabilidade **guarda
os identificadores** (`tournamentId`, `editionId`, `faseId`, `mesaId`) e não
decide nada esportivo.

### O que é do Billing / economia

Fichas, VIP, entitlement, catálogo, loja, Kit Pioneiros. **Intocados.** O ledger
desta OS é exclusivamente de pontuação competitiva.

### O que é da Moderação

Denúncia, bloqueio, política disciplinar. **Intocados.** Esta OS produz *sinais*;
qualquer decisão disciplinar é de lá, e não existe caminho automático entre as
duas.

### Limitação declarada: a ponte Dart → JS

`functions/src/rastreabilidade.ts` executa a parte **mecânica** (transação,
idempotência por id de documento, projeção do histórico). A validação semântica
que o domínio Dart faz continua sendo executada no **produtor** do envelope — o
servidor de partidas.

**Por quê:** a ponte `dart compile js` deste codebase
(`functions/lib/domain_bundle.js`, gerada de `app/lib/torneios/js_bridge.dart`)
exporta o domínio de **torneios**. Levar a rastreabilidade para dentro dela
exigiria alterar o `js_bridge.dart` de torneios, que pertence a outra frente.

**Consequência:** duas constantes estão duplicadas entre Dart e TypeScript —
`papeisDeAutoridade` e o predicado `terminal`. Estão anotadas nos dois lados.
Unificá-las (criando `app/lib/rastreabilidade/js_bridge_rastreabilidade.dart` e
um segundo bundle) é a próxima OS natural desta frente.

---

## 18. Decisões de produto pendentes

1. **Fórmula de ranking.** Quanto vale vitória, derrota e abandono. Sem ela,
   `PoliticaDeRanking.pendente` mantém o caminho desligado e **nenhum lançamento
   é produzido**.
2. **Quais modos são ranqueados.** Hoje: `publica_ranqueada` e `torneio`.
   `privada` e `contra_robos` estão fora por argumento técnico (combinável /
   farmável), não por decisão registrada.
3. **Regras formais de integridade.** Quais combinações de sinais merecem
   investigação, e qual é o fluxo disciplinar. §17 proíbe inventá-las aqui.
4. **Retenção.** Prazos de TTL e arquivamento (§14 deste documento).
5. **Fluxo de correção administrativa.** `MotivoLancamento.correcaoAdministrativa`
   existe no modelo; a interface e a autorização não foram implementadas.
6. **Convidado sem conta.** `ClasseDeParticipante.convidado` existe no modelo
   porque a distinção é barata agora e cara depois; o produto ainda não decidiu
   se convidado existirá.

---

## 19. Testes

| Suíte | Casos | Cobre |
|---|---|---|
| `app/test/rastreabilidade/identidade_test.dart` | 22 | §29 identidade, §4 rodada, §7 participantes |
| `app/test/rastreabilidade/resultado_test.dart` | 22 | §30 resultado, §20 concorrência, §21 atomicidade, §22/§23 estados |
| `app/test/rastreabilidade/historico_test.dart` | 26 | §31 histórico, §12/§13 ledger, §27/§36 consulta e paginação |
| `app/test/rastreabilidade/reconexao_e_abandono_test.dart` | 21 | §32 reconexão, §33 abandono, §9 trilha |
| `app/test/rastreabilidade/seguranca_test.dart` | 23 | §34 segurança, §25 validação, §26 anti-tampering, §14 acesso |
| `app/test/rastreabilidade/antifraude_test.dart` | 17 | §35 antifraude |
| **Dart, total** | **131** | |
| `firebase/testes/rastreabilidade.test.js` | 28 | §24 Rules, contra o emulador |
| **Total** | **159** | |

Executar:

```bash
cd app && flutter test test/rastreabilidade
```

```bash
cd firebase/testes && npm install && npm run emulador:rastreabilidade
```
