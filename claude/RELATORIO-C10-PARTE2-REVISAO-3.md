# Relatório — C10 Parte 2, revisão 3 (fechamento)

**Base:** `a600b4e22807cb9da1c5b5e982019d5c6a94cade` (rev.2).
**Escopo:** só os três itens. Nada da lista "não alterar" foi tocado — RuleSpec,
pontuação/morto convertido, derivador de abertura, `compute`/isolate, abertura
composta, compra atômica do lixo, estratégia do bot, servidor/Railway, e o
rollback além da proteção de concorrência já aprovada.
**Sem merge, sem deploy, sem push para `main`.**

**A C10 não fecha com esta entrega:** volta para auditoria e só encerra após
revisão estática + aplicação na branch + Build APK verde.

---

## Item 1 — pausa real após falha técnica da jogada automática

**Era:** `_pararPorFalhaTecnica()` exibia `PARTIDA PAUSADA` e mais nada. O
`Timer.periodic` continuava vivo com `_turnSeconds == 0`, então o tick seguinte
chamava `_autoJogarPorTempo()` outra vez — nova compra, novo descarte, nova
falha técnica. A mensagem não correspondia ao estado do fluxo.

**Ficou:** a pausa virou **estado**, em duas camadas.

1. `Jogo.pausadaPorFalhaTecnica` — ligada quando `jogadaAutomatica` aborta por
   falha técnica e conferida na **entrada** dela. Vale venha a chamada de onde
   vier, e é o que torna a pausa testável sem montar widget;
2. na tela, `_pararPorFalhaTecnica` cancela o relógio e `_startTurnClock` não o
   reinicia enquanto a trava estiver ligada.

Requisitos atendidos: nenhuma nova jogada automática nos ticks seguintes; sem
repetir compra; sem repetir descarte; sem novo incremento automático de
`falhasTecnicas`; sem `_rodarBots`; `ultimaFalhaTecnica` preservada; sem
fallback nem avanço artificial de turno.

> **Escopo deliberado.** A trava fecha só o caminho **automático**. O jogador
> segue livre para agir: a falha foi do piloto automático, e tentar de novo na
> mão é decisão humana — inventar recuperação seria o oposto do que a OS pede.
> `C10-AUTO-PAUSA-02` fixa esse limite para que não seja "corrigido" por engano.

**Teste obrigatório — `C10-AUTO-PAUSA-01`:** com o projetor quebrado, cinco
oportunidades sucessivas de execução automática. Resultado: **uma única
tentativa**, `falhasTecnicas` permanece em **1**, mão intacta, vez em 0,
evidência preservada, snapshot idêntico.

## Item 2 — `jogadaAutomatica()` só retorna `true` se o turno terminou

**Era:** o `return true` no fim do laço. Se todas as cartas fossem recusadas por
regra, a função dizia "concluí" — sem descarte, sem mudança de `vez`, sem fim de
rodada — e a tela seguia como se o turno automático tivesse acontecido.

**Ficou:** o sucesso é **medido**, não presumido:

```dart
return rodadaEncerrada || vez != vezAntes;
```

Cobre os três finais legítimos: descarte normal (vez++), morto indireto (a
estabilização devolve à fase de compra com vez++) e batida/exaustão
(`rodadaEncerrada`). Recusa de regra continua tentando a próxima carta; falha
técnica encerra na hora; nada de inventar descarte ou forçar `_passarVez`.

**Teste obrigatório — `C10-AUTO-CONTRATO-01`:** mão de uma carta, sem morto
disponível e sem canastra que libere a batida — descartar a última carta é
recusado por regra ("esvaziar a mão é regra") e não há outra carta a tentar.
Resultado: `false`, `falhasTecnicas` em 0 (é regra, não falha técnica), sem
pausa técnica, mesma vez, rodada aberta, snapshot intacto.
`C10-AUTO-CONTRATO-02` prova o outro lado: turno concluído de verdade → `true`.

## Item 3 — regressão da trava de concorrência no rollback legado

**O ponto da revisão está certo.** `C10-OCUPADA-01` roda pelo caminho canônico,
onde `estender` desce para `baixarAtomico` — que também barra. Ele sobrevive à
remoção da guarda direta de `Jogo.estender()` e, portanto, não a prova.

`C10-OCUPADA-04` faz o cenário exigido em `MotorConfig.legadoRollback()`, onde
essa segunda camada não existe: extensão legal quando livre → trava ligada →
recusa com `ocupada: true` e **snapshot integralmente intacto** → trava desligada
→ a **mesma** extensão passa pelo legado (mesa de 3 para 4 cartas, mão −1).

---

## Validação final

| Verificação | Resultado |
|---|---|
| `flutter test test/teste_motor.dart` | **383 `test()` — todos verdes** (eram 378) |
| `flutter analyze` (lib + suíte) | **0 erros** |
| Diff de avisos contra `14b8d03` | **idêntico** — nada novo introduzido |

**Tempo de suíte:** medi contra a rev.2 porque uma execução chegou a 41s e valia
descartar regressão. Aquecidas: **rev.2 22,5s × rev.3 21,0s** — sem regressão; a
variação era compilação a frio e ruído de máquina. (Os "00:03" dos relatórios
anteriores são o cronômetro interno do `test`, que não conta compilação.)

### Não-vacuidade dos novos testes

| Removi | Caiu |
|---|---|
| a trava `pausadaPorFalhaTecnica` | `C10-AUTO-PAUSA-01` |
| o retorno medido (voltei ao `return true`) | `C10-AUTO-CONTRATO-01` |
| a guarda direta de `Jogo.estender()` | `C10-OCUPADA-04` — **e `C10-OCUPADA-01` seguiu verde** |

A última linha é a confirmação empírica do diagnóstico da revisão: sem
`OCUPADA-04`, a guarda direta poderia ser removida sem nenhum teste acusar.

## Genealogia

```
14b8d03  base oficial C10 (Parte 1 aprovada)
  └─ 1dfa572  Parte 2 (reprovada)
       └─ dd48ee3  rev.1 (aprovada nos seis itens)
            └─ a600b4e  rev.2 (dois blockers)
                 └─ 4e940cb  rev.3  ← tip desta entrega
```

## Continua fora, por instrução

OS de Inteligência Estratégica do Bot. Segue em aberto o teste de widget da
mesa, inviável enquanto o CI declarar os assets depois do portão de qualidade.
