# Relatório — C10 Parte 2: promoção do consumidor real

> **REPROVADO na revisão.** As correções estão em
> `RELATORIO-C10-PARTE2-REVISAO-1.md`. Três afirmações deste documento ficaram
> obsoletas: (a) a §8.3 aqui descrita — conversão isentando o -100 — foi
> **rejeitada** como regra; (b) o §5.1 (abertura múltipla pendente de decisão)
> foi **resolvido**: o consumidor humano existe, pelo gesto aprovado; (c) o §1.6
> alegava execução fora do frame com `Future`, o que **não** procede — hoje é
> `compute`, em outro isolate. O resto deste relatório continua válido.

**Base:** `14b8d032732866631715504707fb32aad2c82f51` (Parte 1 aprovada, no `origin/auditoria/regras-bmv`).
**Escopo:** partida **LOCAL**. Online/Railway continua fora do C10 (§15).
**RuleSpec:** `bmv-regras-2026.08` — **inalterada**.
**Status:** entregue para revisão + CI. **Sem merge, sem deploy, sem publicação.**

A Parte 1 provou o **contrato**. A Parte 2 promove o **fluxo**: a partida local
nasce canônica, deixa de existir qualquer fallback, e os consumidores reais
(mesa e robô) passam a consumir a autoridade em vez de contorná-la.

---

## 1. O que mudou, item a item da OS

### 1.1 Flip do ROOT — a partida nasce em `MotorConfig.producao()`
`MesaScreen._novoJogo` constrói o `Jogo` com `widget.configEfetivaDoMotor`, que
é `motorConfig ?? MotorConfig.producao()`. Autoridade ON desde a primeira
jogada; sombra OFF e independente.

**Rollback** é o novo parâmetro opcional `MesaScreen.motorConfig`. É
**configuração pré-transação**: escolhido antes da partida existir, imutável
depois (o `Jogo` recebe a config no construtor, em campo `final`). Nenhuma
jogada, recusa ou falha pode trocá-la no meio do caminho.

Nada foi redesenhado: só um parâmetro opcional entrou no widget.

### 1.2 Autoridade única — falha técnica é fail-closed
Antes, o desfecho `falhaTecnica` roteava para o legado. Agora não roteia para
lugar nenhum: a jogada é **recusada** com o `Jogo` intacto (a autoridade só
falha antes de qualquer efeito observável) e a evidência fica em
`ultimaFalhaTecnica` (motivo + Replay/telemetria).

- `_registrarFallbackTecnico` → `_falharFechado` (registra **e** devolve a recusa);
- `ultimoFallbackTecnico` → `ultimaFalhaTecnica` — o nome antigo descrevia uma
  rota que deixou de existir;
- aplicado nos quatro pontos: `comprarMonte`, `comprarLixo`, `baixar`, `descartar`
  (e, por consequência, `estender`, que agora passa por `baixarAtomico`).

`C9D-FALLBACK-TECNICO-ROTEADO` foi ajustado ao contrato C10, como a OS pediu:
prova agora o oposto do que provava — recusa, mão/monte/turno intactos,
evidência preservada.

### 1.3 `estender` roteado pela autoridade
Era o último furo: validava e mutava o `Jogo` direto. Agora é uma **baixada
canônica com extensões**.

Entrou `Jogo.baixarAtomico(assento, {jogosNovos, extensoes})` — uma transação
canônica única. `baixar` e `estender` viraram casos particulares dela. É também
a forma pela qual a **abertura múltipla (EXC-02)** existe no modelo.

`_desfechoBaixada` reconstrói do **pós-estado já commitado** as três chaves de
feedback que a mesa aprovada consome (`tipo`, `pegouMorto`, `bateu`). Isso não é
regra — a regra já decidiu; é leitura do resultado. **Sem isso o flip do ROOT
teria calado canastra, batida e morto na UI**: o ramo canônico do C9-D devolvia
só `{ok:true}`, o que era inofensivo com a flag OFF e mudo com ela ON.

### 1.4 Pontuação canônica no fim de rodada — EXC-04 fechada
`contarPontos()` conta por `pontuacao_canonica.pontuarRodada` +
`meld_validator.validarJogoMesa`. `pontosMesaAoVivo` acompanha, para o placar
exibido durante a rodada não discordar do final.

A EXC-04 (grupo só de ases) já estava reconciliada em **estado**; o que sobrava
era **classificação na hora de pontuar** (`de_as` do classificador legado ×
`trinca` do canônico), fora da assinatura de estado. Com um único classificador
no caminho da pontuação, não há mais duas respostas possíveis.

O formato de `pontosRodada[dupla]` é o mesmo que a tela de resultado já lê
(`total`, `canastras`, `bonusBatida`, `penalidadeMorto`, `descontoMao`,
`detalhe`), inclusive o sinal negativo das subtrações. §8.3 preservada.

Costura nova: `motor/pontuacao_costura.dart`. Nenhuma regra e nenhuma tabela de
pontos vive lá — só a conversão `Carta` → `CartaSnapshot`, a chamada à
autoridade e o formato que a UI já consome. `modalidadeCanonicaDe` foi exposta
em `projecao_estado.dart` para a spec da pontuação ser a **mesma** da
autoridade, não uma cópia.

`tipoCanonicoDeMeld` reproduz o degrau de tamanho do legado ('aberta' abaixo de
7; trinca mantém o rótulo 'trinca'), então tarja, som e celebração **não mudam
de comportamento** — muda quem classifica.

### 1.5 Consumo real dos candidatos do lixo — 0 / 1 / 2+
O derivador da Parte 1 saiu do teste e entrou no fluxo.

No modelo:
- `Jogo.candidatosCompraLixo(assento)` — enumera pela autoridade (topo visível +
  mão + jogos expostos; enterradas fora). No Aberto devolve vazio, porque lá a
  compra é livre;
- `Jogo.comprarLixoAtomico(assento, escolha)` — recolhe o lixo **e**
  baixa/estende no mesmo commit;
- `comprarLixo` aplica o contrato: **0 → recusa**, **1 → executa**, **2+ →
  devolve `escolhaNecessaria` + candidatos**, sem escolher pelo jogador.

No consumidor (`_tapLixo`): seletor mínimo (bottom sheet) quando há 2+ usos
legais do topo. A lista vem **inteira** da autoridade; a folha só apresenta, e
cancelar não compra nada. O feedback reflete o desfecho real — a mesma transação
pode baixar, virar canastra, pegar o morto ou até bater.

`_tapMonte` passou a fechar a contagem na **exaustão**: sob o canônico, monte e
mortos vazios é uma transição legal que encerra a rodada sem comprar carta, e a
rodada morreria sem placar.

### 1.6 Responsividade (ponto de atenção da OS)
> **OBSOLETO (rev.1).** O parágrafo abaixo descrevia `Future` como responsável
> pela responsividade. Não é: `Future` só adia a execução no MESMO isolate. Hoje
> a derivação roda em `compute` — isolate separado nas plataformas nativas; na
> web, que não tem isolates, degrada para o mesmo event loop. Ver
> `RELATORIO-C10-PARTE2-REVISAO-1.md` §4. A flag `_derivandoLixo` também não
> existe mais: virou `_mesaOcupadaPorDerivacao`, espelhando a trava do modelo.

A derivação é **agendada fora do frame do toque** (`Future`), com a mesa marcada
como ocupada (`_derivandoLixo`) e reentrância bloqueada. A flag continua ligada
enquanto o seletor está aberto, o que impede a jogada automática do cronômetro
de mexer no estado por baixo da escolha do jogador. A espera usa o canal de
mensagem que já existe — nenhum elemento novo entrou no layout aprovado.

**Nenhum cap semântico foi introduzido.** O conjunto de candidatos legais é
exatamente o mesmo; mudou *quando* a travessia roda, não *o que* ela produz.

### 1.7 Auditoria do robô
Fronteira explícita: a **heurística escolhe a intenção** e, entre candidatos já
legais, **qual**; a **legalidade e a aplicação são sempre do canônico**.

- `_botCompra` usa `candidatosCompraLixo` no Fechado/STBL — a existência de
  candidato já é a legalidade e a utilidade (todo candidato põe o topo na mesa).
  `_botEscolheCompraLixo` prefere a transação que põe mais cartas na mesa, com
  desempate determinístico pela ordem da própria derivação;
- as duas redes que chamavam `_passarVez()` direto viraram
  `_botMaoVaziaSemSaida`. Sob autoridade única esse estado é **impossível** —
  toda ação que zeraria a mão é recusada ou estabilizada em morto/batida. Em vez
  de mutar vez/morto/envelope por fora, registra falha técnica e para;
- o bloco 2.7 (obrigação do topo) ficou reservado ao rollback legado. Sob C10 a
  pendência **não nasce** (compra atômica), e a "rede absoluta" dele limpava o
  envelope por fora da autoridade;
- `_rodarBots` ganhou **guarda de progresso**: turno que termina sem a vez
  avançar para o laço com aviso, em vez de girar para sempre. É a rede que
  substitui a mutação ilegal por uma parada visível.

### 1.8 Sombra exclusivamente diagnóstica
`MotorConfig.producao()` nasce com `sombraAtiva: false`, e `mesa.dart` nunca
consulta `sombraAtiva` — só `canonicoAtivo`. O modo sombra não tem chamador de
runtime no fluxo real: continua ferramenta de diagnóstico. Provado por
`C10-PROD-02` e pelo `C9D-SOMBRA-INDEP` já existente.

---

## 2. Consequência estrutural: `lixoTopoObrigatorio` morreu sob o canônico

Vale registrar porque é a prova de que o §5 foi respeitado. A obrigação diferida
do topo era um estado de envelope que nascia na compra e era cobrado no
descarte. Com a compra **atômica**, o topo já está na mesa no mesmo commit:

- o canônico nunca escreve `lixoTopoObrigatorio` (o envelope faz pass-through);
- ninguém o lê no caminho canônico;
- ele permanece **nulo a rodada inteira**.

O comportamento diferido do legado não foi reproduzido em lugar nenhum —
exatamente o que o §5 proíbe. `C9D-ANTI-MASCARAMENTO` (reescrito) e
`C10-ATOMIC-01` provam isso lado a lado com o legado.

---

## 3. Verificação

Reproduzi localmente o **overlay do CI** (scaffold + `cp -R app/lib`,
`cp -R app/test`) e rodei o mesmo comando do portão de qualidade.

| Verificação | Resultado |
|---|---|
| `flutter test test/teste_motor.dart` | **358 `test()` — todos verdes** |
| `flutter analyze` (lib + suíte) | **0 erros** |
| Diff de avisos contra `14b8d03` | **idêntico** — nada novo introduzido |

**Isto não substitui o portão §16.** Nada é considerado concluído sem **Build
APK verde no CI + revisão da Sônia**.

### Testes novos (21)
`C10-PROD-02`, `C10-ROLLBACK-01`, `C10-NO-FALLBACK-01/02`,
`C10-ATOMIC-01/02/03`, `C10-ESTENDER-01`, `C10-ABERTURA-01`,
`C10-SCORE-01/02`, `C10-MORTO-01/02`, `C10-BATIDA-01`, `C10-CONVERSAO-01`,
`C10-EXAUSTAO-01`, `C10-BOT-01/02`, `C10-UI-01`, `C10-LEGACY-01`
(+ `C9D-ANTI-MASCARAMENTO` reescrito, + `C9D-FALLBACK-TECNICO-ROTEADO`
ajustado).

Os cenários de lixo da Parte 2 usam helpers **próprios**, em config de produção.
Os homônimos da Parte 1 nascem em config legada de propósito: lá o alvo era o
derivador chamado direto; aqui é o consumidor, que só existe com a autoridade
ligada. Isso é deliberado — se eu tivesse reusado os helpers da Parte 1, três
testes passariam pelo motivo errado (pelo caminho legado).

---

## 4. Dois testes existentes precisaram mudar — e por quê

Os dois pertenciam ao grupo C9-D e foram escritos para um contrato que o C10
substituiu. Nenhum foi afrouxado: os dois passaram a provar **mais**.

**`C9D-FALLBACK-TECNICO-ROTEADO`** provava que a falha técnica caía no legado.
A OS mandou ajustá-lo; agora prova o fail-closed (recusa + estado intacto +
evidência).

**`C9D-ANTI-MASCARAMENTO`** falhou ao rodar a suíte, e falhou pelo motivo certo.
Fora escrito quando a `Acao ComprarLixo` não carregava jogos: no Fechado o
canônico só sabia recusar, e a prova de anti-mascaramento era a recusa. Com o
contrato atômico, os dois motores **aceitam** a mesma compra. A divergência real
passou a ser mais funda — o legado compra para a mão e **defere** a obrigação; o
canônico só compra com o topo já na mesa. É esse diferimento que o §5 proíbe, e
é ele que o teste passa a provar.

---

## 5. Pontos para a Sônia decidir (não contornados)

### 5.1 Abertura múltipla no gesto da mesa — decisão de produto
O motor faz abertura múltipla atômica; `baixarAtomico` a expõe; a compra do lixo
já a usa de verdade (um candidato pode carregar vários jogos). **Mas o gesto da
tela aprovada baixa um jogo por toque**: seleciona cartas → toca no feltro →
`baixar(ids)` valida aquilo como **um** meld.

Consequência prática: uma dupla vulnerável cujos dois melds só **juntos**
atingem o mínimo consegue abrir pela compra do lixo, mas **não** pelo gesto de
baixar. Essa é a EXC-02 vista do lado da UI.

Fazer o gesto tentar particionar a seleção em vários melds seria **inventar
comportamento de produto** numa tela aprovada. Por §18, **parei e reporto** em
vez de contornar. Opções, para a Sônia escolher:
1. deixar como está (a abertura múltipla existe via lixo; o gesto segue 1 meld);
2. o feltro passa a aceitar seleção que forme 2+ melds, particionando
   automaticamente (mesmo gesto, mais permissivo);
3. um gesto explícito de "abrir com vários jogos".

**Não implementei nenhuma das três.** Nada aqui está bloqueado por esta decisão.

### 5.2 Teste de widget da mesa — melhoria opcional no CI
Um `testWidgets` de `MesaScreen` seria a prova mais forte do ROOT, mas hoje
**não passa no portão**: o passo "Declare assets in pubspec" roda **depois** do
"PORTÃO DE QUALIDADE", então o baralho não está declarado quando a suíte roda e
o `AssetImage` estoura. Verifiquei empiricamente.

Contornei expondo `MesaScreen.configEfetivaDoMotor` — a **mesma expressão** que
o ROOT usa — e testando-a diretamente. Se a Sônia quiser a prova visual no
portão, basta mover o passo de declarar assets para antes do gate; é mudança de
CI, não de código, e não fiz por conta própria.

---

## 6. Arquivos tocados

| Arquivo | O quê |
|---|---|
| `app/lib/mesa.dart` | flip do ROOT, fail-closed, `baixarAtomico`, `estender` roteado, candidatos do lixo, pontuação canônica, seletor, robô, guarda de progresso |
| `app/lib/motor/pontuacao_costura.dart` | **novo** — classificação e pontuação canônicas no formato da UI |
| `app/lib/motor/projecao_estado.dart` | `modalidadeCanonicaDe` exposta (spec única) |
| `app/test/teste_motor.dart` | grupo C10 Parte 2 (21 testes) + 2 testes C9-D ajustados |
| `claude/RELATORIO-C10-PARTE2-PROMOCAO.md` | **novo** — este documento |
| `claude/STATUS-MOTOR-CANONICO.md` | índice vivo atualizado |

`app/lib/rules/` **não foi tocado**: a regra canônica é fonte única e estava
completa. Todo o trabalho foi de costura e de consumidor.

## 7. Commits (pequenos e auditáveis, §17)

1. flip do ROOT
2. autoridade única — fail-closed
3. `estender` roteado + baixada atômica composta
4. pontuação canônica no fim de rodada
5. consumo real dos candidatos do lixo
6. auditoria do robô
7. `C9D-ANTI-MASCARAMENTO` ajustado
8. suíte da Parte 2
9. documentação (este arquivo)
