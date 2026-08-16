# OS — CANONIZAÇÃO DO ESTADO DE COMPRA DO LIXO V1

**Veredito: PASS.**

Branch `claude/canonizacao-estado-lixo-v1-75a307`, base `4c3cd6f`.

---

## 1. Causa raiz

`_lixoUnicoCompradoId` é a §5.2 do ABERTO: *quem compra um lixo de UMA carta só
não pode devolver essa mesma carta como descarte no mesmo turno* (anti "turno
nulo"). Ele nasceu como campo privado do `Jogo` legado, e quando o C9-B separou
o estado canônico do resto, foi classificado como **RUNTIME ENVELOPE** — junto
com `cont`, `mortosConvertidos`, `iniciadorRodada`, `rodada`, `placar` e os
campos de UI.

Essa classificação é o defeito. Todo o resto do envelope é operacional ou
cosmético; `lixoUnicoCompradoId` era **o único campo do envelope que decidia
legalidade**. E o motor que decide (`lib/rules/`) nunca enxergou o envelope: por
contrato, `rules/` não importa `mesa.dart` e recebe só o `EstadoJogo`.

O risco não era teórico. Desde o C10 a configuração de produção é
`MotorConfig.producao()` (autoridade canônica ON), e nesse caminho:

- `comprarLixo` no ABERTO roteia para `comprarLixoAtomico` → `aplicarComAutoridade`;
- `_envelopePos` copia `lixoUnicoCompradoId` do pré-estado **sem alterá-lo** —
  a trava nunca nascia;
- `descartar` roteia para a autoridade canônica, que não tinha a regra.

Ou seja: **a §5.2 não estava sendo aplicada na partida real**. Comprar um lixo de
uma carta e devolver a mesma carta era aceito, e o turno inteiro não acontecia —
exatamente o que a regra existe para impedir. A auditoria anterior classificou o
caminho como "teórico e não alcançável em produção"; a verificação exigida pelo
§3 desta OS mostrou o contrário. Isso está fotografado em código no commit de
caracterização (`LIX-C02`), que rodava **verde na base** afirmando o defeito.

## 2. Resposta à pergunta central (§4)

**A informação é estado normativo e NÃO é derivável — logo, canonização (opção A).**

Eliminar (opção B) foi descartado com evidência: depois da compra, a carta está
misturada na mão e o lixo ficou vazio. "Lixo vazio na fase de jogo" também é a
situação do início da rodada, quando trava nenhuma existe — as duas posições são
indistinguíveis pelo resto do estado, e nenhuma delas diz *qual* carta estaria
travada. Não há de onde reconstruir a decisão.

## 3. Autoridade final

`EstadoJogo.lixoUnicoCompradoId` (`app/lib/rules/estado.dart`), decidido
exclusivamente pelo gerador único (`app/lib/rules/gerador/gerador.dart`).

O campo saiu do `EnvelopeRuntime` — não foi duplicado. `Jogo._lixoUnicoCompradoId`
continua existindo por dois motivos declarados, nenhum deles "segunda verdade":
o motor legado de rollback precisa do próprio slot, e sob autoridade canônica ele
é **projeção** escrita por `aplicarEmJogo` a partir do estado canônico — o mesmo
padrão já usado para a fase.

## 4. Antes × depois (cenário concreto)

Mesa ABERTO, assento 0 na fase de compra, lixo = `[lxUnico]` (uma carta), mão
`[m1, m2, m3]`, configuração de **produção**:

| passo | antes (base `4c3cd6f`) | depois |
|---|---|---|
| `comprarLixo(0)` | ok; trava **não nasce** (fica `null`) | ok; trava nasce em `lxUnico` |
| `descartar(0,'lxUnico')` | **aceito** | **recusado** (`descarte_devolve_lixo_unico`) |
| estado final | lixo `[lxUnico]`, vez = 1 — turno nulo consumado | lixo vazio, vez = 0, turno segue |

## 5. Regra do ABERTO preservada

A regra não mudou de conteúdo; mudou de lugar e passou a valer onde não valia. A
mensagem ao jogador é literalmente a mesma que o legado já mostrava. Fixado por
teste em ambos os motores:

- nasce só no **ABERTO** e só com lixo de **exatamente uma** carta (`LIX-02`);
- lixo de 2+ cartas não trava (`LIX-03`) — com duas, devolver o topo ainda deixa
  a outra carta na mão, o turno aconteceu;
- Fechado/STBL não trava (`LIX-04`): lá a compra é atômica e o topo já foi usado
  no mesmo commit;
- proíbe **só o descarte** daquela carta — baixar e estender com ela continuam
  legais (`LIX-06`);
- o motor legado (rollback) segue idêntico ao que sempre foi (`LIX-C01`).

## 6. Snapshots

Sim, um snapshot passou a ser autossuficiente. O campo entrou em `cloneProfundo`,
`normalizar`, `assinatura`, `copyWith`, `serializarEstado`/`desserializarEstado` e
na comparação de paridade do modo sombra.

`copyWith` ganhou uma **sentinela** (`_naoInformado`): sem ela, "não informado" e
"informado como `null`" seriam indistinguíveis e a trava jamais poderia ser
limpa por cópia — que é justamente o que a passagem da vez precisa fazer.

Dois efeitos verificados: `EnvelopeRuntime.vazio()` (a porta do `AdaptadorLegado`,
que recebe só o canônico) **deixou de perder a informação** (`LIX-C04`, que na
base provava a perda), e o snapshot de Replay carrega a trava sem deixar cópia no
envelope (`LIX-19`).

## 7. Bot

Nenhuma regra especial, nenhuma compensação. O bot planeja sobre o mesmo
`EstadoJogo` e valida cada plano com a mesma `aplicarLegal` — com a trava dentro
do estado, ela chega ao bot de graça. Verificado: o bot nunca devolve a carta
travada, tudo o que ele decide a autoridade aceita, e clonar a posição para
simular preserva a decisão bit a bit (`LIX-20`, `LIX-21`). Pesos estratégicos
intocados.

## 8. Encerramento de turno (§9)

A garantia da OS anterior continua válida — e ganhou alcance. Cenário `LIX-08`:
depois de comprar o lixo de uma carta, baixar a mão inteira deixaria como única
carta justamente a travada. Não há descarte legal, não há morto a pegar com a mão
cheia, não há extensão possível: o turno ficaria **sem conclusão**. A baixada é
recusada com `acao_deixaria_turno_sem_conclusao_legal`, e o gerador único não a
oferece.

`LIX-09` isola a variável: o **mesmo** estado com a trava limpa aceita a mesma
baixada. A diferença é um campo canônico e nada mais.

Isso é a prova mais forte de que a canonização era necessária: esse beco era
**indetectável** antes, porque `existeConclusaoLegalDoTurno` só enxerga o
`EstadoJogo` — e a informação que o cria estava fora dele.

## 9. Exploração (§14)

Varredura determinística sobre baralhos reais do ABERTO (12 sementes, até 60
passos), preferindo a compra do lixo sempre que existir, para cair no regime onde
a trava nasce:

| métrica | valor |
|---|---|
| estados visitados | **720** |
| ações avaliadas | **110.183** |
| nascimentos de trava exercitados | **308** |
| achados **antes** (base) | a varredura não podia rodar: `travasNascidas = 0`, porque a trava nunca nascia |
| achados **depois** | **0** |

Verificações a cada passo aceito: origem da trava, ausência de vazamento entre
turnos, ausência de estado morto, e gerador ≡ aplicador.

**Não-vacuidade provada por mutação:** removendo a limpeza da trava no descarte
normal, esta mesma varredura acusa `trava VAZOU para o turno seguinte` já na
primeira semente. (A mutação foi feita só no overlay de teste e revertida; nada
disso foi commitado.)

Achado de método registrado: `Acao` não implementa `toString`, então comparar
ações por `'$acao'` colapsa todas as instâncias de um tipo em
`Instance of 'Descartar'` — o que faz qualquer teste de paridade gerador×aplicador
passar por acidente. As comparações usam `toJson` (helper `_acaoChave`). A
primeira versão de `LIX-22`/`LIX-23` caiu nisso e teria dado um falso verde.

## 10. Testes e analyzer

| | valor |
|---|---|
| baseline (`4c3cd6f`) | **430** |
| após caracterização | 435 |
| **total final** | **458** (todos verdes) |
| testes existentes apagados ou relaxados | **0** |
| analyzer base | 0 erros · 26 warnings · 101 infos |
| analyzer final | 0 erros · 26 warnings · 101 infos (**delta 0**) |

Os warnings são todos do overlay de execução local (diretórios de asset que o CI
declara depois do portão de qualidade) e do código pré-existente — nenhum novo.

Rodado no overlay limpo do scratchpad (`app/` não tem `pubspec.yaml`; o CI monta
o projeto e sobrepõe `lib/` e `test/`). O portão oficial continua sendo o Build
APK do CI.

## 11. Git

| | |
|---|---|
| branch | `claude/canonizacao-estado-lixo-v1-75a307` |
| SHA da base | `4c3cd6f50faae03c6f6275a274c15a93092e7e49` |
| ancestralidade conferida | `4c3cd6f` ⊃ `89fca38` ⊃ `88d12ac` ✔ |
| HEAD inicial (worktree) | `fb9edb5` (placeholder de `main`, descartado) |
| HEAD final | `c7f4a57` |

Commits por responsabilidade:

1. `5eaa586` — testes de caracterização (fotografam o defeito na base);
2. `25e8d17` — canonização + remoção do campo do envelope;
3. `c7f4a57` — bateria de regra, ciclo de vida, cópia, bot e varredura.

Confirmações: nenhum merge · nenhum deploy · nenhum force push · `origin/main`
intocado · árvore limpa · local == remoto.

## 12. Pendências

Nenhum risco novo em aberto foi descoberto nesta OS. Dois registros de auditoria,
ambos **verificados e sem ação necessária**:

1. **`lixoTopoObrigatorio` não é um segundo estado lateral normativo.** É o
   irmão da §5.3 (Fechado/STBL) e também vive no envelope, mas sob a autoridade
   canônica ele nunca nasce: a compra do lixo no Fechado/STBL é atômica e o topo
   já é usado no mesmo commit. O único bloco que o consome já está guardado por
   `!motorConfig.canonicoAtivo`. Não há regra perdida ali.

2. **O motor legado permanece com a sua própria cópia da §5.2.** É deliberado —
   é o caminho de rollback, e ele é a referência que fixa qual era a regra a
   preservar (`LIX-C01`). Sob produção, o campo do `Jogo` é escrito a partir do
   canônico.
