# Relatório — C10 Parte 2, revisão 2 (dois blockers)

**Base:** `dd48ee30000b75a58bf257308f56421f646c4fed` (rev.1, aprovada nos seis itens).
**Escopo:** só os dois blockers + a clareza documental. Nada das correções
aprovadas foi reaberto: RuleSpec, servidor/Railway, pontuação, morto,
abertura/derivador, rollback e estratégia do bot ficaram intactos.
**Sem merge, deploy ou publicação. C10 não fecha antes desta revisão + APK verde.**

Local: **378 `test()` verdes** (eram 371); `flutter analyze` com **0 erros** e
diff de avisos **idêntico** ao de `14b8d03`.

---

## Blocker 1 — fail-closed da jogada automática por timeout

**Era:** a rev.1 corrigiu o robô e deixou este caminho de fora. `_autoJogarPorTempo`
comprava o monte, falhava tecnicamente e **mesmo assim** entrava no laço de
descarte varrendo a mão inteira; no fim chamava `_rodarBots`, como se o turno
automático tivesse terminado normalmente.

**Ficou:** a jogada automática virou **`Jogo.jogadaAutomatica(assento)`**, ao lado
de `botJoga`. Usa a mesma marca monotônica de `falhasTecnicas`: na primeira falha
técnica **para**, sem tentar a próxima carta e sem concluir o turno. A tela
compara o contador antes e depois e, se houve falha, exibe a parada em vez de
acionar os robôs. `ultimaFalhaTecnica` é preservada.

Recusa de **regra** continua seguindo para a carta seguinte — a mão pode ter
cartas que não se pode descartar, e isso é legítimo. Só a falha técnica encerra.

> **Por que a lógica saiu da tela.** Não foi estética: em `_MesaScreenState` ela
> era **intestável** — o portão de qualidade não monta widget (os assets do
> baralho só entram no pubspec depois do gate). Comprar e descartar é lógica de
> jogo, e no modelo a regressão que a revisão exigiu passou a ser possível.

**Testes:** `C10-AUTO-FC-01` — a regressão pedida: falha técnica no **primeiro**
descarte automático não provoca um segundo (exatamente uma falha registrada, mão
intacta, vez não passa, evidência preservada). `C10-AUTO-FC-02` (falha na compra
não desce para o descarte), `C10-AUTO-01` (turno normal conclui), `C10-AUTO-02`
(mesa ocupada não deixa rodar, e isso **não** é contabilizado como falha técnica).

## Blocker 2 — concorrência durante derivação/seletor

**Era:** `_tapMonte`, `_tapLixo` e `_baixar` respeitavam `_derivandoLixo`;
`_estender` **não**. Dava para alterar a mesa por baixo de um seletor aberto.

**Ficou:** em vez de acrescentar mais uma checagem de UI, a trava desceu para o
**modelo** — `Jogo.mesaOcupadaPorDerivacao` recusa as **sete** entradas mutantes:
`comprarMonte`, `comprarLixo`, `comprarLixoAtomico`, `baixar`, `baixarAtomico`,
`estender` e `descartar`.

> Uma guarda de UI depende de **todo** ponto de entrada lembrar de checá-la — foi
> exatamente assim que `estender` ficou de fora na rev.1. No modelo é invariante:
> vale para os consumidores de hoje e para qualquer um que apareça depois.

Na tela, a condição virou **uma só**: `_minhaVezAtiva` passou a incluir a
ocupação, e as checagens espalhadas saíram. `_ocuparMesa` / `_liberarMesa` são o
par único que liga e desliga (modelo + espelho de tela).

Quem deriva **libera antes de aplicar** a jogada escolhida: terminada a escolha, a
janela de risco acabou e a transação é síncrona. Se não liberasse, a própria
trava recusaria a jogada que o jogador acabou de escolher.

**Testes:** `C10-OCUPADA-01` — o obrigatório: com a mesa ocupada, uma extensão
que seria legal é recusada e **mão e mesa ficam idênticas**; liberada, a mesma
extensão passa (a recusa era da trava, não da regra). `C10-OCUPADA-02` cobre as
sete entradas de uma vez — se um caminho novo aparecer sem a guarda, ele cai.
`C10-OCUPADA-03` prova que **derivar não tranca**: derivação é leitura pura e não
pode deixar a mesa presa.

## Item 3 — clareza documental

- `_derivandoLixo` → **`_mesaOcupadaPorDerivacao`**. O nome antigo descrevia
  metade dos casos desde que a abertura múltipla passou a derivar também;
- comentários de responsividade corrigidos onde ainda atribuíam o mérito ao
  `Future`. A redação agora é a correta: **`compute` usa isolate separado nas
  plataformas nativas; na web, que não tem isolates, degrada honestamente para o
  mesmo event loop** — e em nenhum dos dois casos o conjunto de resultados muda;
- os relatórios anteriores ganharam marcação de obsolescência nos parágrafos que
  a revisão invalidou, em vez de serem reescritos (o histórico do que se afirmou
  errado tem valor de auditoria).

As menções restantes a `_derivandoLixo` e a `Future(() => ...)` no código são
**históricas e intencionais** — explicam por que o nome/alegação mudaram.

---

## Verificação de não-vacuidade

Cada teste obrigatório foi conferido removendo a proteção que ele cobre:

| Removi | Caiu |
|---|---|
| a parada no descarte automático | `C10-AUTO-FC-01` |
| a trava de `estender` **e** a de `baixarAtomico` | `C10-OCUPADA-01`, `C10-OCUPADA-02` |

Registro honesto: removendo **só** a trava de `estender`, os testes continuam
passando — sob a autoridade canônica `estender` desce para `baixarAtomico`, que
já barra. A guarda em `estender` é defesa em profundidade ali, mas é a que vale
sob **rollback legado**, onde `estender` não passa por `baixarAtomico`. Por isso
as duas ficaram.

## Commits

| SHA | O quê |
|---|---|
| `9a9d356` | blockers 1 e 2: fail-closed da jogada automática + trava única de concorrência |
| *(este)* | clareza documental + relatório |

## Continua fora, por instrução

OS de Inteligência Estratégica do Bot. E segue em aberto o teste de widget da
mesa, inviável enquanto o CI declarar os assets depois do portão de qualidade.
