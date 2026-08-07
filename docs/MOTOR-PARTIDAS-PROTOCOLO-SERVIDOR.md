# Protocolo esperado do servidor Node/Railway

Contrato entre o app (`app/lib/motor/`) e o servidor de partidas
(`servidor/servidor.js`, hospedado no Railway — **fora deste repositório**).

O app já implementa o lado dele. Este documento é a lista do que falta do outro
lado. Nada aqui foi implementado por adivinhação: as quatro regras que não
estavam definidas no projeto foram levantadas como pendência e **decididas em
07/08/2026** — estão marcadas como DECISÃO 1 a 4, nas seções 3 e 5.

**A especificação está fechada.** Não há item aguardando decisão.

## Princípio

> A autoridade da partida é o servidor. O cliente propõe; o servidor decide;
> o cliente exibe o que o servidor decidiu.

O app nunca altera o próprio estado de partida por conta própria. Ele monta
comandos, recebe visões versionadas e as exibe.

## Protocolo atual (o que já existe)

`app/lib/services/online_service.dart` fala hoje:

```
cliente → servidor:  criarMesa · entrarMesa · iniciarPartida · jogada · sair
servidor → cliente:  entrou{codigo,assento} · estado{visao} · erro{motivo}
```

O protocolo abaixo **estende** esse, não o substitui. Mensagens antigas
continuam válidas; os campos novos são aditivos.

---

## 1. Jogada com identidade e trava de versão

### cliente → servidor

```json
{
  "tipo": "jogada",
  "jogada": {
    "eventoId": "u42-1730-17",
    "assento": 0,
    "tipo": "descartar",
    "ids": ["c37"],
    "versaoEsperada": 128
  }
}
```

`tipo` ∈ `comprarMonte · comprarLixo · baixar · estender · descartar · ordenarMao`.
`indiceJogo` acompanha `estender`. Formato exato:
`ComandoPartida.toJson()` em `app/lib/motor/comando_partida.dart`.

### servidor → cliente

```json
{
  "tipo": "resultadoJogada",
  "resultado": {
    "eventoId": "u42-1730-17",
    "status": "aplicado",
    "versaoEstado": 129,
    "codigoErro": null,
    "mensagem": null,
    "efeitos": { "vezAgora": 1, "rodadaEncerrada": false }
  }
}
```

`status` ∈ `aplicado · duplicado · rejeitado`. Códigos de erro estáveis em
`ErroComando`: `ESTADO_CORROMPIDO`, `VERSAO_DESATUALIZADA`, `FORA_DE_TURNO`,
`RODADA_ENCERRADA`, `PARTIDA_ENCERRADA`, `ASSENTO_INVALIDO`, `COMANDO_INVALIDO`,
`REGRA`.

### O que o servidor precisa fazer

1. **Memorizar `eventoId` por partida.** Se já foi aplicado, responder
   `duplicado` com o resultado **original** e não reexecutar nada. Janela
   mínima recomendada: 256 eventos, ou a rodada inteira.
2. **Conferir `versaoEsperada` DEPOIS da checagem de duplicidade.** Essa ordem
   não é detalhe: um reenvio após queda carrega a versão antiga; conferir versão
   primeiro faria o cliente concluir que a jogada se perdeu. Ver `CONC-04` em
   `app/test/teste_motor_resiliencia.dart`.
3. **Incrementar `versaoEstado` em exatamente 1 por mutação aceita**, e em nada
   mais.
4. **Nunca alterar estado num comando recusado** — nem estado, nem versão, nem
   cache de idempotência.
5. **Aplicar a jogada com as travas na ordem** documentada em
   `MOTOR-PARTIDAS-ARQUITETURA.md` §3.

## 2. Visão de estado por assento

O servidor deve enviar, para cada assento, **apenas o que aquele assento pode
ver**. Nunca o estado completo.

```json
{ "tipo": "estado", "visao": { "versaoEstado": 129, "assento": 0, "...": "..." } }
```

Formato exato: `VisaoAssento.de(jogo, assento)` em
`app/lib/motor/visao_assento.dart`. Campos obrigatórios para a retomada (§9 da
OS): `assento`, `dupla`, `parceiro`, `adversarios`, `jogadores`, `modalidade`,
`metaPontos`, `rodada`, `vez`, `jaComprou`, `mao`, `impressaoDaMao`, `lixo`,
`jogosNos`, `jogosEles`, `cartasNaMao`, `monteRestante`, `mortosRestantes`,
`mortoPegoNos`, `mortoPegoEles`, `placarNos`, `placarEles`,
`minimoParaDescerNos`, `minimoParaDescerEles`, `relogio`, `presenca`.

Regras:

- **`mao` só do próprio assento.** As mãos alheias entram apenas como contagem
  em `cartasNaMao`.
- **`monte` e `mortos` nunca em conteúdo** — só `monteRestante`,
  `mortosRestantes`, `mortosTamanhos`.
- **`idTopoObrigatorio` só para quem tem a carta.** Os demais recebem apenas
  `obrigacaoTopoPendente: true`.
- **`mesaBloqueada` é booleano.** O código auditável da integridade fica no log
  do servidor, nunca na tela de quem poderia explorá-lo.
- Toda visão carrega `versaoEstado`. O cliente **descarta** visão com versão
  menor ou igual à que já aplicou — é o que impede a carta de "voltar" na tela
  depois de uma reconexão fora de ordem.

Se o servidor rodar o motor Dart, `MotorPartida.visaoDe(assento)` já produz isso
pronto. Se rodar o motor JS, o formato precisa ser espelhado campo a campo.

## 3. Relógio de turno

O cronômetro **definitivo** é do servidor.

```json
{
  "tipo": "estado",
  "visao": {
    "relogio": {
      "assento": 1,
      "inicioMs": 1730000000000,
      "duracaoMs": 45000,
      "versaoEstado": 129,
      "fonte": "servidor"
    }
  }
}
```

- Enviar **prazo** (`inicioMs` + `duracaoMs`), nunca "segundos restantes". O
  cliente recalcula a cada quadro e acerta sozinho ao voltar do segundo plano.
- `inicioMs` em epoch ms **do servidor**.
- Reemitir a cada troca de turno, com o `versaoEstado` correspondente.

### Calibração do relógio

Para o cliente traduzir o relógio do aparelho (que pode estar minutos errado):

```
cliente → servidor:  { "tipo": "ping",  "enviadoEm": 1730000000000 }
servidor → cliente:  { "tipo": "pong",  "enviadoEm": 1730000000000, "servidorEm": 1730000000120 }
```

O cliente já implementa a matemática (`SincronizacaoRelogio`): guarda a amostra
de menor ida-e-volta. O servidor só precisa devolver o `enviadoEm` recebido mais
o próprio carimbo.

### Expiração

Quando o prazo estoura, **o servidor** decide e informa:

```json
{
  "tipo": "expiracaoTurno",
  "expiracao": {
    "assento": 1, "rodada": 3, "emMs": 1730000045000,
    "acao": "jogadaAutomatica", "versaoEstado": 130
  }
}
```

`acao` ∈ `jogadaAutomatica · turnoPerdido · substituidoPorRobo · partidaEncerrada`.

### DECISÃO 1 — ação na expiração (07/08/2026)

**A jogada automática mínima que o motor já faz vira a regra oficial inicial.**
O servidor usa `acao: "jogadaAutomatica"`.

Quando o prazo estoura:

1. **o servidor assume a autoridade** — o cliente nunca decide sozinho que o
   tempo acabou, e um cliente que ache que estourou apenas para de esperar
   jogada e mostra "aguardando o servidor";
2. o servidor executa a jogada automática mínima já prevista pelo motor —
   **hoje: compra do monte + descarte automático**;
3. essa ação **passa pelas mesmas validações de uma jogada normal**. Ela não é
   um atalho: entra pelo mesmo `MotorPartida.aplicar`, com as mesmas travas de
   turno, integridade e regra;
4. ela **gera `eventoId` próprio** (do servidor, não do cliente),
   **incrementa `versaoEstado`** e **entra no diário estruturado**.

#### Namespace de eventoId por origem (decidido em 07/08/2026)

Eventos originados no servidor usam **namespace próprio: `srv-<uuid>`**.

**O prefixo declara a ORIGEM AUTORITATIVA do evento — não é convenção de
nomenclatura.** A distinção é semântica e tem três consequências operacionais:

1. **Idempotência.** Sem namespaces separados, o cache não consegue distinguir
   "o servidor jogou por você" de "você reenviou sua jogada". Um cliente que
   volta de uma queda e reenvia a fila poderia colidir com o `eventoId` da
   jogada automática que o servidor já executou no lugar dele.
2. **Auditoria.** Ao ler o diário de uma reclamação, a origem do evento é a
   primeira pergunta: a carta saiu porque o jogador mandou, ou porque o tempo
   dele acabou? O namespace responde isso sem consultar mais nada.
3. **Autoridade.** Um `srv-` chegando **do** cliente é, por definição,
   falsificação de origem. O servidor deve **recusar** com `COMANDO_INVALIDO`
   qualquer comando cujo `eventoId` use o namespace do servidor.

`<uuid>` — e não um contador — porque o servidor pode reiniciar, e um contador
reiniciado reemitiria ids já usados, fazendo o cache tratar evento novo como
duplicado.

O cliente gera os dele por `GeradorEventoId` (`app/lib/motor/sessao_reconexao.dart`),
cujo prefixo é a sessão do jogador. Os dois espaços não se cruzam.

**Não criar a regra "perdeu o turno" nesta fase.** O valor `turnoPerdido`
continua no enum porque o contrato precisa comportar a evolução, mas nenhuma
modalidade o emite hoje.

Referência da implementação atual: `_autoJogarPorTempo` em `app/lib/mesa.dart`.

## 4. Presença e heartbeat

```
cliente → servidor:  { "tipo": "heartbeat", "emMs": 1730000000000 }
```

Cadência sugerida: `intervaloHeartbeatMs` (padrão 5 s).

O servidor devolve a presença de todos os assentos dentro da visão:

```json
{
  "presenca": {
    "parametros": {
      "intervaloHeartbeatMs": 5000,
      "toleranciaInstavelMs": 12000,
      "toleranciaAusenteMs": 45000,
      "prazoAbandonoMs": 180000
    },
    "assentos": [
      { "assento": 1, "estado": "instavel", "ultimoHeartbeatMs": 1729999988000, "desdeMs": 1730000000000 }
    ]
  }
}
```

`estado` ∈ `online · instavel · ausente · abandonou · substituidoPorRobo`.

- O servidor **manda os parâmetros** que ele mesmo usa, para as duas pontas
  contarem igual.
- Os degraus intermediários (`instavel`, `ausente`) existem para atender ao §8
  da OS: "evitar declarar abandono imediatamente em pequenas oscilações". Uma
  queda de 11 s não pode custar a partida de ninguém.
- **Só o servidor emite `abandonou` e `substituidoPorRobo`.** O cliente é
  incapaz de produzi-los.

## 5. Abandono e substituição

```json
{
  "tipo": "abandono",
  "registro": {
    "partidaId": "m-771", "assento": 2, "motivo": "ausenciaProlongada",
    "emMs": 1730000225000, "rodada": 3,
    "substituidoPorRobo": true, "retornoPermitido": true,
    "penalidadePontos": null
  }
}
```

`motivo` ∈ `voluntario · ausenciaProlongada · removidoPeloServidor ·
inviabilidadeDaPartida`.

`penalidadePontos: null` significa **"o servidor não informou"**, não zero. O
cliente não calcula penalidade.

### DECISÃO 2 — penalidade por abandono (07/08/2026)

**Nesta primeira versão, abandono não desconta pontos da partida.** O servidor
envia `penalidadePontos: null` sempre.

A razão é de integridade do jogo: mexer no placar do Buraco por um motivo que
não é do Buraco corrompe a apuração da rodada. Um jogador que caiu no metrô não
pode ter a canastra da dupla anulada por isso.

O abandono é registrado **separadamente**, para estatística e histórico de
comportamento do jogador. Esse registro é o `RegistroAbandono` — ele já existe e
já viaja completo (motivo, instante, rodada, se houve substituição).

O campo `penalidadePontos` **permanece no contrato** para uma política
configurável futura, especialmente em ranking e torneios. Enquanto ela não
existir, `null` é a resposta correta — e o cliente continua tratando `null` como
"não informado", nunca como zero.

> Política de penalidade em **ranking e torneios** é da camada de torneios, não
> do Motor de Partidas. Ver DECISÃO 4.

### DECISÃO 3 — retorno após substituição por robô (07/08/2026)

**Sim, o jogador recupera o assento original.** Condições:

1. **só enquanto a partida estiver ativa** — partida encerrada não devolve
   assento;
2. **só no assento originalmente daquele usuário** — a identidade do dono do
   assento precisa sobreviver à substituição, então o servidor guarda o vínculo
   `assento → usuário` mesmo com o robô no comando;
3. **o robô conclui apenas a ação atômica em curso.** Não se interrompe um
   `botJoga` pela metade: interromper entre a compra e o descarte deixaria o
   assento num estado que nenhuma regra prevê;
4. **a devolução ocorre em ponto seguro do estado** — na prática, na fronteira
   de turno, com a versão estável;
5. **o servidor envia snapshot/visão atualizada ANTES de liberar comandos.** O
   jogador não pode mandar jogada sobre um estado que ele ainda não viu;
6. **os comandos antigos pendentes do cliente continuam sujeitos a `eventoId` e
   `versaoEsperada`.** É exatamente aqui que a idempotência paga: o cliente que
   voltou pode reenviar o que tinha na fila sem risco de a jogada valer duas
   vezes, e a trava de versão recusa o que foi pensado sobre um estado que o
   robô já mudou;
7. **abandono explícito definitivo pode impedir a retomada** — sair pela porta
   (`motivo: "voluntario"`) é diferente de cair (`ausenciaProlongada`). O campo
   `retornoPermitido` do `RegistroAbandono` carrega essa distinção, e quem a
   decide é o servidor.

### DECISÃO 4 — continuidade e encerramento (07/08/2026)

**Uma mesa não encerra porque alguém caiu.** A substituição por robô existe
justamente para preservar a partida — encerrar por queda desperdiçaria o
mecanismo e puniria os três jogadores que ficaram.

Regra da versão inicial:

- 1 jogador ausente → **robô substitui**;
- mais de um ausente → **robôs substituem**, sem limite fixo;
- **enquanto houver ao menos um humano ativo** e a modalidade permitir
  continuidade, **a partida prossegue**;
- **se todos os humanos abandonarem definitivamente, o servidor encerra**.

Encerramento por abandono **não inventa placar esportivo**. O servidor não
arbitra vencedor, não aplica W.O. e não completa rodada. Ele apenas:

1. **salva o último snapshot** (`MotorPartida.snapshot()`), e
2. **registra o motivo** do encerramento.

```json
{
  "tipo": "partidaEncerrada",
  "encerramento": {
    "partidaId": "m-771",
    "motivo": "sem_jogadores_humanos",
    "emMs": 1730000900000,
    "versaoEstado": 187,
    "rodada": 4,
    "placarApurado": false
  }
}
```

`motivo` inicial ∈ `meta_atingida · sem_jogadores_humanos`.
`placarApurado: false` diz explicitamente que o placar **não** foi fechado como
resultado esportivo — é o que impede a camada de cima de ler um encerramento
administrativo como vitória de alguém.

> **Fronteira.** W.O., pontuação administrativa e eliminação em torneio são da
> **camada de torneios**, e não podem ser embutidos no Motor de Partidas. O motor
> entrega o snapshot e o motivo; quem transforma isso em consequência esportiva é
> quem tem as regras do torneio.

> **Contrato ainda sem modelo Dart.** A mensagem `partidaEncerrada` acima é a
> única das quatro decisões que não tem classe correspondente em
> `app/lib/motor/` — as outras três couberam nos contratos existentes
> (`AcaoPorExpiracao`, `RegistroAbandono.penalidadePontos`,
> `RegistroAbandono.retornoPermitido`). Criar o leitor dela é trabalho da OS de
> ligação com o `online_service.dart`, quando o protocolo real do Node estiver
> disponível.

## 6. Retomada completa

Quando o cliente reconecta, ele **sempre** pede o estado inteiro antes de
confiar em qualquer coisa (`SessaoReconexao.aoReconectar`).

```
cliente → servidor:  { "tipo": "retomar", "codigo": "ABCD", "assento": 0 }
servidor → cliente:  { "tipo": "estado", "visao": { ... } }        // versão atual
```

Em seguida o cliente reenvia os comandos pendentes com o **mesmo `eventoId`** —
seguro justamente por causa da idempotência do item 1.

O servidor deve devolver o jogador ao **assento original** da mesa. A visão já
carrega tudo que a retomada exige; o cliente não reconstrói nada.

## 7. Persistência do estado

Para o servidor sobreviver a reinício sem perder partidas em andamento, o
snapshot precisa ser persistido. Formato pronto:
`MotorPartida.snapshot()` — inclui o estado do jogo, a versão **e a janela de
idempotência**.

A janela é a parte que costuma ser esquecida: sem ela, um servidor que reiniciou
aceita de novo comandos que já valeram, e o jogador que estava reenviando compra
duas vezes.

Restaurar deve recusar snapshot corrompido em vez de abrir a mesa —
`SnapshotPartida.restaurar` já faz isso rodando a auditoria de integridade do
motor.

## 8. Regras de segurança (§16 da OS)

O servidor precisa recusar, vindo do cliente, qualquer tentativa de:

- editar pontuação;
- mudar o jogador da vez;
- inserir, retirar ou mover cartas fora de um comando válido;
- ler ou modificar a mão de outro assento;
- conceder vitória, alterar prêmio ou finalizar a partida.

A superfície de comandos é fechada por construção: `TipoComando` tem seis
valores e nenhum deles toca em placar, turno ou baralho diretamente. Comando
fora dessa lista é `COMANDO_INVALIDO`.

`iniciarPartida`, `apurarRodada` e `iniciarNovaRodada` **não são comandos de
jogador** — são transições que a autoridade conduz.

## Resumo do que falta no servidor

Em 07/08/2026 as quatro pendências de regra foram decididas. **A especificação
está fechada** — não há mais nada esperando decisão.

| # | Item | Onde |
| --- | --- | --- |
| 1 | Cache de `eventoId` por partida, com resposta `duplicado` | §1 |
| 2 | `versaoEstado` monotônica e trava `versaoEsperada` | §1 |
| 3 | Ordem das checagens (duplicidade **antes** de versão) | §1 |
| 4 | Visão recortada por assento | §2 |
| 5 | `ping`/`pong` com carimbo do servidor | §3 |
| 6 | Prazo de turno como instante, reemitido a cada turno | §3 |
| 7 | Jogada automática na expiração, com `eventoId` no namespace `srv-<uuid>` | §3 · DECISÃO 1 |
| 7b | Recusar comando do cliente que use o namespace `srv-` | §3 · DECISÃO 1 |
| 8 | `heartbeat` + máquina de presença com degraus | §4 |
| 9 | `penalidadePontos: null` e registro de abandono à parte | §5 · DECISÃO 2 |
| 10 | Vínculo `assento → usuário` sobrevivendo à substituição por robô | §5 · DECISÃO 3 |
| 11 | Devolução do assento em ponto seguro, visão antes dos comandos | §5 · DECISÃO 3 |
| 12 | Continuidade com robôs; encerrar só sem humanos ativos | §5 · DECISÃO 4 |
| 13 | `partidaEncerrada` com motivo e `placarApurado: false` | §5 · DECISÃO 4 |
| 14 | Persistência do snapshot **com a janela de idempotência** | §7 |
| 15 | `retomar` devolvendo o assento original | §6 |

Fora do escopo do Motor de Partidas, por decisão: W.O., pontuação
administrativa e eliminação em torneio pertencem à camada de torneios.
