# Protocolo esperado do servidor Node/Railway

Contrato entre o app (`app/lib/motor/`) e o servidor de partidas
(`servidor/servidor.js`, hospedado no Railway — **fora deste repositório**).

O app já implementa o lado dele. Este documento é a lista do que falta do outro
lado. Nada aqui foi implementado por adivinhação: onde a regra não está definida
no projeto, está marcado como **pendência**, não como comportamento inventado.

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

> **Pendência de regra.** A mesa local hoje faz "compra do monte + descarte
> automático" quando o cronômetro zera (`_autoJogarPorTempo`, `mesa.dart`). Se a
> regra oficial da modalidade for outra — turno perdido, por exemplo — ela
> precisa ser definida antes de o servidor implementar. Não foi inventada aqui.

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

> **Pendências de regra** (§10 da OS — "não implementar regras arbitrárias"):
>
> 1. **Penalidade por abandono.** Não há valor especificado no projeto.
> 2. **Retorno após abandono.** Se o jogador pode retomar o assento depois de
>    substituído por robô, e até quando.
> 3. **Encerramento por inviabilidade.** Quantos abandonos encerram a mesa, e
>    como o placar é apurado nesse caso.
>
> As três precisam de decisão antes da implementação no servidor.

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

| # | Item | Depende de decisão? |
| --- | --- | --- |
| 1 | Cache de `eventoId` por partida, com resposta `duplicado` | não |
| 2 | `versaoEstado` monotônica e trava `versaoEsperada` | não |
| 3 | Ordem das checagens (duplicidade antes de versão) | não |
| 4 | Visão recortada por assento | não |
| 5 | `ping`/`pong` com carimbo do servidor | não |
| 6 | Prazo de turno como instante, reemitido a cada turno | não |
| 7 | `heartbeat` + máquina de presença com degraus | não |
| 8 | Persistência do snapshot **com a janela de idempotência** | não |
| 9 | `retomar` devolvendo o assento original | não |
| 10 | Ação na expiração do turno | **sim** — regra da modalidade |
| 11 | Penalidade por abandono | **sim** |
| 12 | Retorno após substituição por robô | **sim** |
| 13 | Encerramento por inviabilidade e apuração nesse caso | **sim** |
