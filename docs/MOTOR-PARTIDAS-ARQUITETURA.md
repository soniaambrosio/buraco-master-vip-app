# Motor de Partidas e Resiliência — arquitetura

Ordem de serviço 01. Branch `claude/motor-partidas-resiliencia-3a775f`, baseada em
`consolidacao/apk-geral-bmv` (`0cea0d6`).

## O problema

O `Jogo`, em `app/lib/mesa.dart`, é um motor de buraco completo e bem testado:
108 cartas com auditoria de integridade, mortos, canastras, batida,
vulnerabilidade, pontuação e robô, nas três modalidades. O que ele não tem — e
não deveria ter — é qualquer noção de rede.

Isso deixava um vão. Numa partida online as perguntas que aparecem não são de
buraco, são de transporte:

| Pergunta | Quem respondia antes |
| --- | --- |
| Esse comando já chegou antes? | ninguém |
| Sobre qual estado ele foi pensado? | ninguém |
| O que este assento pode ver? | ninguém — o estado inteiro trafegava |
| Onde exatamente a mão mudou? | ninguém |
| Como devolvo o jogador ao lugar certo? | o cliente, adivinhando |

Cada linha em branco dessa tabela é uma reclamação de jogador: *"eu descartei e
a carta voltou"*, *"caí e quando voltei minha mão estava diferente"*.

## A forma da solução

Uma camada nova em `app/lib/motor/`, **em volta** do `Jogo` — não dentro dele.
O motor de regras não mudou de comportamento: nenhuma linha preexistente de
`mesa.dart` foi removida ou modificada; ele apenas ganhou dois métodos de
serialização e um getter (ver "Alterações em mesa.dart").

```
                        ┌─────────────────────────────┐
   servidor Node ──────►│      SessaoReconexao        │  lado do app
   (autoridade)         │  fila idempotente, versão,  │
        ▲               │  descarte de estado velho   │
        │               └──────────────┬──────────────┘
        │                              │
   ComandoPartida                 VisaoAssento
   (eventoId, versão)             (recorte por assento)
        │                              ▲
        ▼                              │
   ┌────────────────────────────────────────────────┐
   │                MotorPartida                    │
   │  versão do estado · idempotência por eventoId  │
   │  travas de turno · diário · snapshot           │
   └───────────────────────┬────────────────────────┘
                           │
                     ┌─────▼──────┐
                     │    Jogo    │   mesa.dart — REGRAS, intocado
                     └────────────┘
```

## Os arquivos

| Arquivo | Responsabilidade |
| --- | --- |
| `motor/snapshot_partida.dart` | Serializa e restaura o estado inteiro. Determinístico. Recusa snapshot impossível. Produz impressões digitais. |
| `motor/visao_assento.dart` | Recorta o estado por assento. Mão própria inteira; do resto, só o que está na mesa e a contagem do que está oculto. |
| `motor/comando_partida.dart` | Envelope de jogada (`eventoId`, `versaoEsperada`) e resultado, com códigos de erro estáveis. |
| `motor/motor_partida.dart` | Aplica comandos com controle de versão, idempotência e travas de turno. Porta única para humano e robô. |
| `motor/relogio_turno.dart` | Prazo do turno como instante, não contador. Tradução do relógio do aparelho para o do servidor. |
| `motor/presenca.dart` | Presença, tolerância a oscilação, contratos de abandono e substituição. |
| `motor/diagnostico.dart` | Diário técnico circular, sem conteúdo de carta. |
| `motor/sessao_reconexao.dart` | Lado do app: fila de comandos pendentes, reenvio idempotente, descarte de visão velha. |

## As cinco garantias

### 1. Snapshot determinístico e fiel (§9)

`SnapshotPartida.capturar` produz o mesmo mapa para o mesmo estado, sempre, com
as chaves na mesma ordem. Duas capturas viram a mesma impressão digital — é
assim que se prova que o estado *não* mudou entre dois instantes.

Fidelidade importa mais do que parece. O motor guarda cinco escalares privados
que não aparecem em nenhuma zona de cartas mas mudam o que é legal no turno:
obrigação do topo do lixo, carta que não pode ser devolvida, mortos convertidos
em monte, iniciador da rodada e "rodada já contada". Sem eles a partida retomada
*parece* igual e *joga* diferente. Eles viajam no bloco `interno`.

Restaurar roda a auditoria de integridade do próprio motor. Snapshot corrompido
levanta `ErroSnapshot` — não abre a mesa em silêncio e não inventa carta.

### 2. Nada vaza para quem não deveria ver (§11, §16)

`VisaoAssento.de(jogo, assento)` devolve a mão própria por inteiro, o que está
na mesa (lixo, jogos baixados, placar) e apenas a **contagem** do que está
oculto: mãos alheias, monte, mortos.

A contagem não é vazamento — é o que qualquer jogador conta com os olhos numa
mesa real, e é do que o robô já dependia para decidir se bate agora ou espera o
parceiro.

O teste dessa garantia varre a estrutura inteira em vez de conferir campo a
campo: um campo novo com carta dentro reprova sozinho.

### 3. O mesmo comando não vale duas vezes (§6)

Todo comando carrega um `eventoId` gerado pelo cliente e estável entre reenvios.
`MotorPartida` memoriza os eventoIds aplicados; ao reconhecer um, devolve o
resultado **original** marcado como `duplicado` e não refaz nada.

A ordem das checagens em `aplicar` é deliberada e testada:

1. envelope estrutural → `COMANDO_INVALIDO`
2. **eventoId já aplicado** → `duplicado`
3. mesa bloqueada → `ESTADO_CORROMPIDO`
4. **versão esperada** → `VERSAO_DESATUALIZADA`
5. assento válido → `ASSENTO_INVALIDO`
6. rodada/partida vivas → `RODADA_ENCERRADA` / `PARTIDA_ENCERRADA`
7. é a vez dele → `FORA_DE_TURNO`
8. o motor decide → `REGRA`

O passo 2 vem antes do 4 porque um reenvio depois de queda carrega a versão
*antiga*. Se a versão fosse conferida primeiro, o reenvio da jogada que já valeu
seria recusado como desatualizado e o cliente concluiria que a jogada se perdeu —
exatamente o bug que esta camada existe para impedir. Há teste de regressão
(`CONC-04`).

Comandos **recusados** não entram no cache: eles podem valer depois, quando a vez
chegar. Só resultados aplicados são memorizados.

### 4. Dois jogadores ao mesmo tempo (§6)

`versaoEstado` sobe exatamente 1 por mutação aceita, e em nada mais. Um comando
pode declarar `versaoEsperada`: se o estado já avançou, ele é recusado sem tocar
em nada. `SessaoReconexao.novoComando` preenche esse campo sozinho com a versão
que o jogador tinha na tela quando tocou — a trava otimista sai de graça.

### 5. Investigável depois do fato (§13)

`DiarioPartida` registra comando, turno, versão antes e depois, resultado e erro.
No lugar do conteúdo das mãos, guarda uma **impressão digital**: entradas com a
mesma impressão provam que a mão não mudou; impressões diferentes apontam
exatamente entre quais dois eventos ela mudou.

A censura é mecânica, não é convenção: `EventoDiagnostico` filtra chaves
sensíveis na construção e só aceita escalares — estrutura aninhada é o caminho
mais fácil para uma carta escapar sem ninguém perceber. O teste `LOG-04` varre o
despejo inteiro procurando qualquer id de carta da partida.

## A fronteira com o servidor

Decisão desta ordem de serviço: **o cliente pode desconfiar, só o servidor
declara.**

O app calcula, a partir do último heartbeat, se um assento parece oscilando ou
sumido — para a tela mostrar "conexão instável" e esmaecer o avatar. O app nunca
conclui que alguém abandonou, nunca troca ninguém por robô e nunca encerra
partida.

Essa fronteira é mecânica: `PoliticaPresenca` **não sabe produzir** os estados
terminais. Ela só devolve `online | instavel | ausente`. Os estados `abandonou` e
`substituidoPorRobo` só entram no mapa por `aplicarDoServidor`, e um heartbeat
não desfaz o que o servidor declarou.

O mesmo vale para o tempo. `RelogioTurno` guarda um **prazo** (instante de fim na
linha do tempo do servidor), não um contador. Quem guarda contador perde tempo
quando o app vai para segundo plano; quem guarda prazo apenas relê o relógio e
acerta sozinho — o que resolve "app em background" e "reconexão durante timer"
sem lógica extra. `SincronizacaoRelogio` traduz o relógio do aparelho, que pode
estar minutos errado, usando a amostra de menor ida-e-volta.

O que o servidor precisa implementar do outro lado está em
[`MOTOR-PARTIDAS-PROTOCOLO-SERVIDOR.md`](MOTOR-PARTIDAS-PROTOCOLO-SERVIDOR.md).

## Alterações em `mesa.dart`

**Nenhuma linha preexistente de `mesa.dart` foi removida ou modificada; houve
apenas 29 linhas adicionadas.** Três adições, todas na seção do motor, nenhuma
na UI:

- `estadoInternoParaSnapshot()` — expõe os cinco escalares privados;
- `aplicarEstadoInternoDeSnapshot(Map)` — reaplica-os;
- `descarteProibidoId` — getter da carta que o §5.2 do Aberto impede de devolver.

Os dois primeiros existem só para o codec de snapshot; não são API de tela.

Como o patch é estritamente aditivo (`git diff --numstat` → `29 0`), as 132
asserções da suíte de regras continuam exercitando exatamente o mesmo
comportamento de antes.

## Testes

| Suíte | Testes | Escopo |
| --- | ---: | --- |
| `app/test/teste_motor.dart` | 132 | regras (pré-existente, intocada) |
| `app/test/teste_motor_resiliencia.dart` | 130 | resiliência (nova) |
| `app/test/torneios/reward_grants_test.dart` | 80 | torneios (pré-existente, intocada) |

Grupos da suíte nova: `SNAP` (20), `VISAO` (14), `IDEM` (10), `CONC` (7),
`TURNO` (10), `RELOGIO` (13), `PRES` (14), `RECON` (17), `LOG` (13), `MODAL` (7),
`E2E` (5).

Nenhum teste espera tempo real passar — o relógio é injetado (`FonteDeTempo`),
o que os torna determinísticos e instantâneos.

O CI ganhou um segundo portão em `.github/workflows/build.yml`, irmão do portão
do motor: nenhum APK é gerado se a resiliência quebrar.

## O que esta camada não faz

Por decisão explícita da ordem de serviço, e não por falta:

- não decide expiração de turno;
- não declara jogador offline nem abandono;
- não substitui ninguém por robô por ausência;
- não encerra partida por inviabilidade;
- não fala Firebase, e não substituiu o backend WebSocket por outra arquitetura.

As quatro regras que faltavam para essas decisões — ação na expiração,
penalidade por abandono, retorno após substituição e encerramento por
inviabilidade — foram decididas em 07/08/2026 e estão em
[`MOTOR-PARTIDAS-PROTOCOLO-SERVIDOR.md`](MOTOR-PARTIDAS-PROTOCOLO-SERVIDOR.md)
como DECISÃO 1 a 4. Elas descrevem o que o **servidor** faz; esta camada
continua sem tomá-las.

A ligação com `online_service.dart` é OS própria, quando o protocolo real do
Node/Railway estiver disponível.
