# Evidência CI — run 15

- branch: `correcao/ci-composicao-perfil-mesa-ranking-v2-v1`
- commit: `dae65bac1e17f1b868546937e69b397b3b65c199`
- data UTC: 2026-08-17T23:58:38Z

## Veredito do agregador (`scripts/ci/portao_os_integracao.sh`)

Portão final: exit `0` — NÃO EXECUTADO reprova, exit vazio ou não numérico reprova.

```
portão OS Integração — fonte: scripts/ci/gates_os_integracao.txt
resultados em: .

analyze        VERDE          exit 0
motor          VERDE          exit 0
resil          VERDE          exit 0
encerr         VERDE          exit 0
torneios       VERDE          exit 0
mtorneios      VERDE          exit 0
integr         VERDE          exit 0
colarte        VERDE          exit 0
colfire        VERDE          exit 0
colkit         VERDE          exit 0
social         VERDE          exit 0
casca          VERDE          exit 0
cascaaud       VERDE          exit 0
cascavisao     VERDE          exit 0
cascamesaaud   VERDE          exit 0
cascav2        VERDE          exit 0
cascaligacao   VERDE          exit 0
cascamesa      VERDE          exit 0
cascaporta     VERDE          exit 0
rkbarreira     VERDE          exit 0
rkestado       VERDE          exit 0
rkperfil       VERDE          exit 0
rkleitor       VERDE          exit 0
rkregressao    VERDE          exit 0
composicao     VERDE          exit 0
portaoci       VERDE          exit 0
billing        VERDE          exit 0
torneiosfn     VERDE          exit 0
socialdom      VERDE          exit 0
socialfn       VERDE          exit 0
socialemu      VERDE          exit 0
regras         VERDE          exit 0
rankingfn      VERDE          exit 0
rankingint     VERDE          exit 0
identint       VERDE          exit 0
auditident     VERDE          exit 0

obrigatórios: 36 | verdes: 36 | fora da fonte: 0
resultado: VERDE
```

## Resultado por gate

Gates obrigatórios lidos de `scripts/ci/gates_os_integracao.txt` — a mesma fonte do agregador.

| gate | status | exit |
|---|---|---|
| analyze | EXECUTADO | 0 |
| motor | EXECUTADO | 0 |
| resil | EXECUTADO | 0 |
| encerr | EXECUTADO | 0 |
| torneios | EXECUTADO | 0 |
| mtorneios | EXECUTADO | 0 |
| integr | EXECUTADO | 0 |
| colarte | EXECUTADO | 0 |
| colfire | EXECUTADO | 0 |
| colkit | EXECUTADO | 0 |
| social | EXECUTADO | 0 |
| casca | EXECUTADO | 0 |
| cascaaud | EXECUTADO | 0 |
| cascavisao | EXECUTADO | 0 |
| cascamesaaud | EXECUTADO | 0 |
| cascav2 | EXECUTADO | 0 |
| cascaligacao | EXECUTADO | 0 |
| cascamesa | EXECUTADO | 0 |
| cascaporta | EXECUTADO | 0 |
| rkbarreira | EXECUTADO | 0 |
| rkestado | EXECUTADO | 0 |
| rkperfil | EXECUTADO | 0 |
| rkleitor | EXECUTADO | 0 |
| rkregressao | EXECUTADO | 0 |
| composicao | EXECUTADO | 0 |
| portaoci | EXECUTADO | 0 |
| billing | EXECUTADO | 0 |
| torneiosfn | EXECUTADO | 0 |
| socialdom | EXECUTADO | 0 |
| socialfn | EXECUTADO | 0 |
| socialemu | EXECUTADO | 0 |
| regras | EXECUTADO | 0 |
| rankingfn | EXECUTADO | 0 |
| rankingint | EXECUTADO | 0 |
| identint | EXECUTADO | 0 |
| auditident | EXECUTADO | 0 |

Fora do portão: `evidencias_visuais` exit `0` (gerador de PNG).

## flutter analyze (tail)
```
   info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss. Try replacing the use of the deprecated member with the replacement • lib/screens/preparando_partida_screen.dart:1229:45 • deprecated_member_use
   info • Unnecessary use of multiple underscores. Try using '_' • lib/screens/ranking_screen.dart:699:47 • unnecessary_underscores
   info • Unnecessary use of multiple underscores. Try using '_' • lib/screens/ranking_screen.dart:699:51 • unnecessary_underscores
   info • Unnecessary use of multiple underscores. Try using '_' • lib/screens/ranking_screen.dart:846:47 • unnecessary_underscores
   info • Unnecessary use of multiple underscores. Try using '_' • lib/screens/ranking_screen.dart:846:51 • unnecessary_underscores
   info • Unnecessary use of multiple underscores. Try using '_' • lib/screens/ranking_screen.dart:1127:27 • unnecessary_underscores
   info • Unnecessary use of multiple underscores. Try using '_' • lib/screens/ranking_screen.dart:1127:31 • unnecessary_underscores
   info • Unnecessary use of multiple underscores. Try using '_' • lib/screens/ranking_screen.dart:1136:27 • unnecessary_underscores
   info • Unnecessary use of multiple underscores. Try using '_' • lib/screens/ranking_screen.dart:1136:31 • unnecessary_underscores
   info • Unnecessary use of multiple underscores. Try using '_' • lib/screens/ranking_screen.dart:1148:25 • unnecessary_underscores
   info • Unnecessary use of multiple underscores. Try using '_' • lib/screens/ranking_screen.dart:1148:29 • unnecessary_underscores
   info • 'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss. Try replacing the use of the deprecated member with the replacement • lib/screens/resultado_partida_screen.dart:275:41 • deprecated_member_use
warning • The value of the field '_muted' isn't used. Try removing the field, or using it • lib/screens/saguao_screen.dart:560:16 • unused_field
warning • The value of the field '_ouro' isn't used. Try removing the field, or using it • lib/screens/splash_oficial_screen.dart:44:16 • unused_field
   info • Unnecessary use of multiple underscores. Try using '_' • lib/screens/splash_oficial_screen.dart:136:26 • unnecessary_underscores
   info • Unnecessary use of multiple underscores. Try using '_' • lib/screens/splash_oficial_screen.dart:136:30 • unnecessary_underscores
   info • Unnecessary use of multiple underscores. Try using '_' • lib/screens/splash_oficial_screen.dart:137:44 • unnecessary_underscores
   info • 'activeColor' is deprecated and shouldn't be used. Use activeThumbColor instead. This feature was deprecated after v3.31.0-2.0.pre. Try replacing the use of the deprecated member with the replacement • lib/screens/torneio_modelo_screen.dart:307:79 • deprecated_member_use
   info • 'value' is deprecated and shouldn't be used. Use initialValue instead. This will set the initial value for the form field. This feature was deprecated after v3.33.0-1.0.pre. Try replacing the use of the deprecated member with the replacement • lib/screens/torneio_modelo_screen.dart:379:7 • deprecated_member_use
   info • 'activeColor' is deprecated and shouldn't be used. Use activeThumbColor instead. This feature was deprecated after v3.31.0-2.0.pre. Try replacing the use of the deprecated member with the replacement • lib/screens/torneio_modelo_screen.dart:402:7 • deprecated_member_use
   info • 'onReorder' is deprecated and shouldn't be used. Use the onReorderItem callback instead. The onReorderItem callback adjusts the newIndex parameter for a removed item at the oldIndex. This feature was deprecated after v3.41.0-0.0.pre. Try replacing the use of the deprecated member with the replacement • lib/screens/torneio_modelo_screen.dart:460:9 • deprecated_member_use
   info • 'activeColor' is deprecated and shouldn't be used. Use activeThumbColor instead. This feature was deprecated after v3.31.0-2.0.pre. Try replacing the use of the deprecated member with the replacement • lib/screens/torneio_modelo_screen.dart:497:15 • deprecated_member_use
   info • Use the null-aware marker '?' rather than a null check via an 'if'. Try using '?' • lib/screens/torneios_screens.dart:144:19 • use_null_aware_elements
   info • Unnecessary use of multiple underscores. Try using '_' • lib/screens/torneios_screens.dart:434:43 • unnecessary_underscores
   info • Unnecessary use of multiple underscores. Try using '_' • lib/screens/torneios_screens.dart:641:41 • unnecessary_underscores
   info • Unnecessary use of multiple underscores. Try using '_' • lib/screens/torneios_screens.dart:641:45 • unnecessary_underscores
   info • Unnecessary use of multiple underscores. Try using '_' • lib/screens/torneios_screens.dart:873:41 • unnecessary_underscores
   info • Unnecessary use of multiple underscores. Try using '_' • lib/screens/torneios_screens.dart:873:45 • unnecessary_underscores
   info • 'groupValue' is deprecated and shouldn't be used. Use a RadioGroup ancestor to manage group value instead. This feature was deprecated after v3.32.0-0.0.pre. Try replacing the use of the deprecated member with the replacement • lib/screens/torneios_screens.dart:1220:21 • deprecated_member_use
   info • 'onChanged' is deprecated and shouldn't be used. Use RadioGroup to handle value change instead. This feature was deprecated after v3.32.0-0.0.pre. Try replacing the use of the deprecated member with the replacement • lib/screens/torneios_screens.dart:1221:21 • deprecated_member_use
   info • Unnecessary use of multiple underscores. Try using '_' • lib/screens/torneios_screens.dart:1536:29 • unnecessary_underscores
   info • Unnecessary use of multiple underscores. Try using '_' • lib/screens/torneios_screens.dart:1576:29 • unnecessary_underscores
   info • 'activeColor' is deprecated and shouldn't be used. Use activeThumbColor instead. This feature was deprecated after v3.31.0-2.0.pre. Try replacing the use of the deprecated member with the replacement • lib/screens/torneios_screens.dart:1775:13 • deprecated_member_use
   info • Unnecessary use of multiple underscores. Try using '_' • lib/screens/torneios_screens.dart:1782:37 • unnecessary_underscores
   info • Use the null-aware marker '?' rather than a null check via an 'if'. Try using '?' • test/casca/bancada_online.dart:379:3 • use_null_aware_elements
   info • Use the null-aware marker '?' rather than a null check via an 'if'. Try using '?' • test/casca/porta_de_comandos_online_test.dart:38:5 • use_null_aware_elements
   info • Invalid use of a private type in a public API. Try making the private type public, or making the API that uses the private type also be private • test/casca/porta_de_comandos_online_test.dart:52:28 • library_private_types_in_public_api
   info • Unnecessary use of multiple underscores. Try using '_' • test/sessao/telas_consomem_identidade_test.dart:100:30 • unnecessary_underscores

102 issues found. (ran in 11.3s)
```
## motor (tail)
```
00:00 +108: TRX-01 baixada inválida: NADA muda
00:00 +109: TRX-02 MELD-002: extensão inválida → jogo original PRESERVADO
00:00 +110: TRX-03 descarte inválido preserva mão e lixo
00:00 +111: TRX-04 compra do lixo recusada preserva lixo e mão
00:00 +112: TRX-05 comando repetido: 2º descarte da mesma carta falha e não duplica
00:00 +113: TRX-06 comando repetido: 2ª compra falha e não tira 2ª carta
00:00 +114: TRX-07 baixar com id repetido é recusado sem efeito
00:00 +115: TRX-08 baixar com carta fora da mão é recusado sem efeito
00:00 +116: TRX-09 corrupção entre jogadas é detectada no fim do turno
00:00 +117: TRX-10 rodada completa de bots termina ÍNTEGRA
00:00 +118: FLUX-21 conversão do morto da dupla correspondente isenta o -100 (fluxo real)
00:00 +119: NOME-01 STBL e SBTL: as duas grafias aplicam regras IDÊNTICAS
00:00 +120: PARTIDA-ABERTO-1 completa: íntegra, 108 cartas e com vencedor
00:00 +121: PARTIDA-ABERTO-2 completa: íntegra, 108 cartas e com vencedor
00:00 +122: PARTIDA-ABERTO-3 completa: íntegra, 108 cartas e com vencedor
00:00 +123: PARTIDA-ABERTO-4 completa: íntegra, 108 cartas e com vencedor
00:00 +124: PARTIDA-FECHADO-1 completa: íntegra, 108 cartas e com vencedor
00:00 +125: PARTIDA-FECHADO-2 completa: íntegra, 108 cartas e com vencedor
00:00 +126: PARTIDA-FECHADO-3 completa: íntegra, 108 cartas e com vencedor
00:00 +127: PARTIDA-FECHADO-4 completa: íntegra, 108 cartas e com vencedor
00:00 +128: PARTIDA-SBTL-1 completa: íntegra, 108 cartas e com vencedor
00:00 +129: PARTIDA-SBTL-2 completa: íntegra, 108 cartas e com vencedor
00:01 +130: PARTIDA-SBTL-3 completa: íntegra, 108 cartas e com vencedor
00:01 +131: PARTIDA-SBTL-4 completa: íntegra, 108 cartas e com vencedor
00:01 +132: All tests passed!
```
## resil (tail)
```
00:01 +172: MODAL — Aberto, Fechado e STBL MODAL-04 STBL usa a trava do Fechado para o lixo
00:01 +173: MODAL — Aberto, Fechado e STBL MODAL-05-ABERTO snapshot preserva a modalidade e as regras
00:01 +174: MODAL — Aberto, Fechado e STBL MODAL-05-FECHADO snapshot preserva a modalidade e as regras
00:01 +175: MODAL — Aberto, Fechado e STBL MODAL-05-SBTL snapshot preserva a modalidade e as regras
00:01 +176: E2E — partida completa pelo MotorPartida E2E-ABERTO robôs jogam 200 turnos com estado sempre íntegro
00:01 +177: E2E — partida completa pelo MotorPartida E2E-FECHADO robôs jogam 200 turnos com estado sempre íntegro
00:01 +178: E2E — partida completa pelo MotorPartida E2E-SBTL robôs jogam 200 turnos com estado sempre íntegro
00:01 +179: E2E — partida completa pelo MotorPartida E2E-SNAP retomada no meio de uma partida de robôs mantém tudo
00:01 +180: E2E — partida completa pelo MotorPartida E2E-VISAO durante uma partida de robôs nada vaza para o assento 0
00:01 +181: CANASTRAS — acumulador de canastras limpas CAN-01 rodada não apurada: nada a somar, acumulador em zero
00:01 +182: CANASTRAS — acumulador de canastras limpas CAN-02 uma canastra limpa de "nos" soma só para "nos"
00:01 +183: CANASTRAS — acumulador de canastras limpas CAN-03 acumula ao longo de mais de uma rodada
00:01 +184: CANASTRAS — acumulador de canastras limpas CAN-04 rodada com zero canastras não mexe no acumulador
00:01 +185: CANASTRAS — acumulador de canastras limpas CAN-05 apuração repetida NÃO duplica a contagem (retry)
00:01 +186: CANASTRAS — acumulador de canastras limpas CAN-06 snapshot e restauração preservam o acumulado
00:01 +187: CANASTRAS — acumulador de canastras limpas CAN-07 snapshot ANTIGO, sem a chave, restaura compatível (zero)
00:01 +188: CANASTRAS — acumulador de canastras limpas CAN-08 valor inválido no envelope é ignorado, não vira lixo
00:01 +189: CANASTRAS — acumulador de canastras limpas CAN-09 o acumulador NÃO recalcula regra: espelha o que o Jogo apurou
00:01 +190: IMPRESSAO-PARTIDA — identidade competitiva da partida IMPP-01 é determinística: duas leituras seguidas batem
00:01 +191: IMPRESSAO-PARTIDA — identidade competitiva da partida IMPP-02 mesmo jogo e mesmas canastras: mesma impressão
00:01 +192: IMPRESSAO-PARTIDA — identidade competitiva da partida IMPP-03 mesmo Jogo, canastras DIFERENTES: impressão diferente
00:01 +193: IMPRESSAO-PARTIDA — identidade competitiva da partida IMPP-04 ordem das chaves do envelope não altera a impressão
00:01 +194: IMPRESSAO-PARTIDA — identidade competitiva da partida IMPP-05 comando RECUSADO não altera impressao nem impressaoPartida
00:01 +195: IMPRESSAO-PARTIDA — identidade competitiva da partida IMPP-06 snapshot e restauração preservam a impressão da partida
00:01 +196: All tests passed!
```
## encerr (tail)
```
00:00 +0: loading /home/runner/work/buraco-master-vip-app/buraco-master-vip-app/app_build/test/teste_encerramento.dart
00:00 +0: ENCERR — porta canônica de encerramento ENCERR-01 partida não encerrada: desfecho existe, mas não é conclusivo
00:00 +1: ENCERR — porta canônica de encerramento ENCERR-02 encerrada: vencedor é a dupla de maior placar (nos)
00:00 +2: ENCERR — porta canônica de encerramento ENCERR-03 vencedor vem do PLACAR, não de quem bateu a última rodada
00:00 +3: ENCERR — porta canônica de encerramento ENCERR-04 metaPontos, modalidade e rodada atravessam para o DTO
00:00 +4: ENCERR — porta canônica de encerramento ENCERR-05 toJson/deJson ida e volta preserva o desfecho
00:00 +5: ENCERR — porta canônica de encerramento ENCERR-06 deJson recusa envelope inválido, em vez de completar
00:00 +6: ENCERR — porta canônica de encerramento ENCERR-07 o desfecho NÃO expõe nenhum id de carta (varredura)
00:00 +7: ENCERR — porta canônica de encerramento ENCERR-08 empate é estrito: nada de vencedor deduzido em silêncio
00:00 +8: ENCERR — porta canônica de encerramento ENCERR-09 encerramento natural entrega os totais de canastras
00:00 +9: ENCERR — porta canônica de encerramento ENCERR-10 mesmo placar e canastras diferentes: impressões diferentes
00:00 +10: All tests passed!
```
## torneios (tail)
```
00:00 +56: janela de validade inativa antes de grantedAt
00:00 +57: janela de validade ativa exatamente em grantedAt
00:00 +58: janela de validade ativa dentro do prazo
00:00 +59: janela de validade inativa exatamente em expiresAt
00:00 +60: janela de validade inativa depois de expiresAt
00:00 +61: janela de validade permanente tambem so vale a partir de grantedAt
00:00 +62: resolucao de validade — casos de borda fixed_duration sem duracao e recusada
00:00 +63: resolucao de validade — casos de borda duracao nao positiva e recusada
00:00 +64: resolucao de validade — casos de borda proxima edicao anterior a concessao e recusada
00:00 +65: resolucao de validade — casos de borda proxima edicao igual a concessao e recusada
00:00 +66: resolucao de validade — casos de borda permanent ignora a proxima edicao
00:00 +67: normalizacao e invariantes grantedAt e expiresAt sao normalizados para UTC
00:00 +68: normalizacao e invariantes motivo por colocacao exige colocacao
00:00 +69: normalizacao e invariantes colocacao nao vale em motivo que nao a admite
00:00 +70: normalizacao e invariantes toJson expoe os campos auditaveis
00:00 +71: hidratacao de registros persistidos 1. round-trip toJson -> fromMap preserva todos os campos
00:00 +72: hidratacao de registros persistidos 2. recompensa permanente volta permanente
00:00 +73: hidratacao de registros persistidos 3. recompensa temporaria volta com a mesma janela
00:00 +74: hidratacao de registros persistidos 4. hidratacao nao consulta a politica atual
00:00 +75: hidratacao de registros persistidos 5. data invalida e recusada
00:00 +76: hidratacao de registros persistidos 6. campo obrigatorio ausente e recusado
00:00 +77: hidratacao de registros persistidos 7. enum invalido e recusado
00:00 +78: hidratacao de registros persistidos 8. chave de idempotencia incompativel e recusada
00:00 +79: hidratacao de registros persistidos hidratada em lote alimenta o contador como a original
00:00 +80: All tests passed!
```
## mtorneios (tail)
```
00:00 +155: extra: cancelamento de inscricao cancelar sem inscricao e recusado
00:00 +156: extra: hidratacao e invariantes round-trip da inscricao
00:00 +157: extra: hidratacao e invariantes inscricao com chave adulterada e recusada
00:00 +158: extra: hidratacao e invariantes round-trip da edicao
00:00 +159: extra: hidratacao e invariantes edicao com data sem sufixo Z e recusada
00:00 +160: extra: hidratacao e invariantes a janela de inscricao e fechada no inicio e aberta no fim
00:00 +161: extra: hidratacao e invariantes a janela de inscricao e explicita, nunca derivada do check-in
00:00 +162: extra: hidratacao e invariantes a modalidade da edicao vem da politica, sem inventar valor
00:00 +163: extra: hidratacao e invariantes participanteId de dupla mal formado e recusado
00:00 +164: extra: hidratacao e invariantes membro com o separador e recusado
00:00 +165: contratos para Flutter a correspondencia de status dominio <-> UI e 1:1
00:00 +166: contratos para Flutter a correspondencia de participante dominio <-> UI cobre a UI inteira
00:00 +167: contratos para Flutter a correspondencia de recusa de inscricao cobre a UI inteira
00:00 +168: contratos para Flutter modalidade e participacao mapeiam para a UI
00:00 +169: contratos para Flutter a secao da central deriva do estado
00:00 +170: contratos para Flutter os botoes vem do dominio, nao do widget
00:00 +171: contratos para Flutter o card monta a partir do dominio
00:00 +172: contratos para Flutter a linha de classificacao mapeia para a UI
00:00 +173: contratos para Flutter o confronto mapeia para a UI
00:00 +174: contrato com o Motor de Partidas a solicitacao carrega tudo que a mesa precisa e nada alem
00:00 +175: contrato com o Motor de Partidas o matchId e derivado da mesa: reenviar nao abre duas mesas
00:00 +176: contrato com o Motor de Partidas mesa com participante repetido e recusada
00:00 +177: contrato com o Motor de Partidas mesa com menos de dois lados e recusada
00:00 +178: contrato com o Motor de Partidas as interfaces do contrato existem e sao implementaveis
00:00 +179: All tests passed!
```
## integr (tail)
```
00:00 +40: INT-11/12 — pontuação e canastras vêm prontas do Motor de Partidas INT-12 as canastras limpas do torneio são exatamente as do motor
00:00 +41: INT-11/12 — pontuação e canastras vêm prontas do Motor de Partidas INT-12 uma canastra limpa real atravessa a fronteira com o valor 1
00:00 +42: INT-11/12 — pontuação e canastras vêm prontas do Motor de Partidas o acumulado de canastras atravessa o snapshot
00:00 +43: INT-11/12 — pontuação e canastras vêm prontas do Motor de Partidas reapurar a mesma rodada não soma canastra duas vezes
00:00 +44: INT-11/12 — pontuação e canastras vêm prontas do Motor de Partidas canastra suja não entra na conta
00:00 +45: INT-11/12 — pontuação e canastras vêm prontas do Motor de Partidas sem rodada apurada o acumulado é zero, não um palpite
00:00 +46: INT-13 — dois processamentos simultâneos só um dos dois produz efeito; o outro é jaProcessado
00:00 +47: INT-13 — dois processamentos simultâneos cinco chegadas simultâneas continuam produzindo um efeito só
00:00 +48: INT-13 — dois processamentos simultâneos resultado recusado não ocupa a chave de idempotência
00:00 +49: INT-13 — dois processamentos simultâneos as duas camadas de idempotência são independentes
00:00 +50: SORTEIO — versão do algoritmo determinístico a versão 1 é o xorshift32 atual e não muda nesta OS
00:00 +51: SORTEIO — versão do algoritmo determinístico TESTE-OURO: a versão 1 mantém EXATAMENTE a distribuição atual
00:00 +52: SORTEIO — versão do algoritmo determinístico pedir a versão 1 explicitamente dá o mesmo que não pedir nada
00:00 +53: SORTEIO — versão do algoritmo determinístico versão desconhecida falha alto em vez de sortear com a atual
00:00 +54: SORTEIO — versão do algoritmo determinístico a fase grava a versão junto da semente
00:00 +55: SORTEIO — versão do algoritmo determinístico a versão sobrevive ao round-trip da fase
00:00 +56: SORTEIO — versão do algoritmo determinístico fase gravada ANTES desta OS é lida como versão 1
00:00 +57: SORTEIO — versão do algoritmo determinístico fase gravada por uma versão futura é recusada na leitura
00:00 +58: SORTEIO — versão do algoritmo determinístico a semente continua reproduzindo, e sementes diferentes divergem
00:00 +59: FRONTEIRA — os domínios continuam separados o desfecho canônico não fala de torneio
00:00 +60: FRONTEIRA — os domínios continuam separados o resultado do torneio não fala de baralho
00:00 +61: FRONTEIRA — os domínios continuam separados o adaptador implementa o contrato declarado em torneios
00:00 +62: FRONTEIRA — os domínios continuam separados cancelar uma partida inexistente é silencioso
00:00 +63: FRONTEIRA — os domínios continuam separados cancelar desfaz a mesa e o vínculo juntos
00:00 +64: All tests passed!
```
## colarte (tail)
```
00:00 +0: loading /home/runner/work/buraco-master-vip-app/buraco-master-vip-app/app_build/test/colecoes/colecao_arte_test.dart
00:00 +0: fonte de arte bundle guarda o caminho e dispensa checksum
00:00 +1: fonte de arte remota exige url e checksum
00:00 +2: fonte de arte a chave de cache vem da origem, nao do itemId
00:00 +3: fonte de arte le a forma antiga (assetPath solto) como bundle
00:00 +4: fonte de arte le a forma nova (arte: {...})
00:00 +5: fonte de arte declarar as duas formas ao mesmo tempo e recusado
00:00 +6: fonte de arte arte remota sem sha256 no seed e recusada
00:00 +7: fonte de arte tipo desconhecido e recusado em vez de virar bundle
00:00 +8: fonte de arte sobrevive a ida e volta por JSON
00:00 +9: resolvedor resolve arte de bundle sem tocar rede nem disco
00:00 +10: resolvedor recusa arte remota em vez de devolver algo pela metade
00:00 +11: catalogo com origem remota o catalogo aceita item com arte remota
00:00 +12: catalogo com origem remota itens de origens diferentes convivem no mesmo catalogo
00:00 +13: catalogo com origem remota duas entradas para a mesma arte remota sao recusadas
00:00 +14: All tests passed!
```
## colfire (tail)
```
00:00 +0: loading /home/runner/work/buraco-master-vip-app/buraco-master-vip-app/app_build/test/colecoes/colecao_firebase_test.dart
00:00 +0: campanha le o documento e converte Timestamp em ISO com Z
00:00 +1: campanha campanha ausente vira naoEncontrado, e nao null silencioso
00:00 +2: campanha campanha malformada vira precondicaoFalhou, nao erro de rede
00:00 +3: feature flag documento ausente significa desligada
00:00 +4: feature flag so `true` liga: valor ausente ou de outro tipo mantem desligada
00:00 +5: evidencia de elegibilidade sem documento, nenhuma evidencia
00:00 +6: evidencia de elegibilidade le as quatro evidencias da subcolecao
00:00 +7: evidencia de elegibilidade a evidencia de um jogador nao vaza para outro
00:00 +8: inventario hidrata os itens e converte o server timestamp
00:00 +9: inventario filtra por colecao
00:00 +10: inventario um documento corrompido nao esconde os outros nove
[colecoes] inventario: documento pioneer_2026_vortex ignorado (inventario: source deve ser string nao vazia (recebido: ).)
00:00 +11: inventario inventario vazio nao e erro
00:00 +12: equipagem grava a troca de slot em lote
00:00 +13: equipagem a gravacao so toca o campo equipped
00:00 +14: resposta do resgate traduz os tres estados do wire
00:00 +15: resposta do resgate status desconhecido nao vira sucesso
00:00 +16: resposta do resgate resposta sem itemIds e recusada
00:00 +17: resposta do resgate so indisponibilidade convida a repetir
00:00 +18: All tests passed!
```
## colkit (tail)
```
00:00 +57: inventario e equipagem item nao possuido nao pode ser equipado
00:00 +58: inventario e equipagem itemId desconhecido e recusado
00:00 +59: inventario e equipagem equipar duas vezes o mesmo item e recusa explicita
00:00 +60: inventario e equipagem desequipar libera o slot
00:00 +61: inventario e equipagem desequipar o que nao estava equipado e recusa explicita
00:00 +62: inventario e equipagem a equipagem permanece apos ida e volta pelo documento
00:00 +63: inventario e equipagem inventario nao aceita item de outro jogador
00:00 +64: contrato de UI com a flag desligada a campanha nao aparece
00:00 +65: contrato de UI nao elegivel em modo hidden nao ve a campanha
00:00 +66: contrato de UI nao elegivel em modo teaser ve a colecao bloqueada
00:00 +67: contrato de UI elegivel sem resgate ve o convite com as dez pecas
00:00 +68: contrato de UI as recompensas saem na ordem de apresentacao
00:00 +69: contrato de UI durante a chamada o botao fica bloqueado
00:00 +70: contrato de UI erro recuperavel traz a mensagem que promete nao duplicar
00:00 +71: contrato de UI resgate concluido agora dispara a revelacao
00:00 +72: contrato de UI quem ja tinha resgatado cai em alreadyClaimed, sem revelacao
00:00 +73: contrato de UI o inventario continua visivel depois da campanha encerrada
00:00 +74: contrato de UI canEquip separa possuido de equipavel
00:00 +75: contrato de UI item equipado deixa de oferecer equipar
00:00 +76: contrato de UI toda recompensa tem rotulo de acessibilidade
00:00 +77: contrato de UI os textos provisorios estao no contrato, nao soltos em widget
00:00 +78: telemetria os sete eventos previstos existem com o nome acordado
00:00 +79: telemetria o payload carrega so identificadores tecnicos
00:00 +80: telemetria campos ausentes sao omitidos em vez de irem nulos
00:00 +81: All tests passed!
```
## social (tail)
```
00:00 +66: PAR — a chave canônica do par PAR-04 identificador que quebraria a chave é recusado
00:00 +67: PAR — a chave canônica do par PAR-05 membros saem ordenados e a relação sabe quem é o outro
00:00 +68: PAR — a chave canônica do par PAR-06 releitura do documento canônico preserva o estado
00:00 +69: PAR — a chave canônica do par PAR-07 estado desconhecido num documento vira "nenhuma"
00:00 +70: VER — ver perfil de outro jogador VER-01 sem relação: pode adicionar
00:00 +71: VER — ver perfil de outro jogador VER-02 solicitação enviada: pode cancelar, não aceitar
00:00 +72: VER — ver perfil de outro jogador VER-03 solicitação recebida: pode aceitar e recusar
00:00 +73: VER — ver perfil de outro jogador VER-04 amigos: pode remover
00:00 +74: VER — ver perfil de outro jogador VER-05 bloqueado por mim: só desbloquear
00:00 +75: VER — ver perfil de outro jogador VER-06 bloqueio do OUTRO lado não se distingue de indisponível
00:00 +76: VER — ver perfil de outro jogador VER-07 bloqueio prevalece sobre amizade ainda não desfeita
00:00 +77: VER — ver perfil de outro jogador VER-08 perfil próprio é reconhecido e não oferece ação social
00:00 +78: VER — ver perfil de outro jogador VER-09 mute NÃO aparece na vista (§19)
00:00 +79: LST — listagem e paginação LST-01 ordena por apelido normalizado, publicId desempata
00:00 +80: LST — listagem e paginação LST-01b apelido que é prefixo de outro vem primeiro
00:00 +81: LST — listagem e paginação LST-02 paginação percorre a lista inteira sem repetir nem pular
00:00 +82: LST — listagem e paginação LST-03 a última página não devolve cursor
00:00 +83: LST — listagem e paginação LST-04 lista vazia é página vazia, não erro
00:00 +84: LST — listagem e paginação LST-05 nenhuma entrada carrega UID ou e-mail
00:00 +85: LST — listagem e paginação LST-06 o tamanho de página tem teto
00:00 +86: LST — listagem e paginação LST-07 o teto de amigos cabe numa lista carregada de uma vez
00:00 +87: LST — listagem e paginação LST-08 não há teto de solicitações recebidas (§25, anti-DoS)
00:00 +88: ERR — códigos de domínio estáveis ERR-01 todo código exigido pela OS existe
00:00 +89: ERR — códigos de domínio estáveis ERR-02 o esquema dos documentos sociais está declarado
00:00 +90: All tests passed!
```
## casca (tail)
```
#3      main.<anonymous closure>.<anonymous closure> (file:///home/runner/work/buraco-master-vip-app/buraco-master-vip-app/app_build/test/casca/casca_producao_test.dart:630:20)
<asynchronous suspension>
#4      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#5      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1952:5)
<asynchronous suspension>
#6      StackZoneSpecification._registerCallback.<anonymous closure> (package:stack_trace/src/stack_zone_specification.dart:114:42)
<asynchronous suspension>
To silence this warning, pass "warnIfMissed: false" to "tap()".
To make this warning fatal, set WidgetController.hitTestWarningShouldBeFatal to true.

00:02 +17: o Perfil alcançável só afirma o que tem fonte o Perfil é alcançável a partir da Home
00:02 +18: o Perfil alcançável só afirma o que tem fonte sem autoridade de ranking, nada de Bronze nem de #0
00:02 +19: o Perfil alcançável só afirma o que tem fonte progressão, estatísticas e conquistas ficam ausentes
00:03 +20: o Perfil alcançável só afirma o que tem fonte o convite copiado do Perfil alcançável não inventa nada
00:03 +21: o Perfil alcançável só afirma o que tem fonte o VM do Perfil alcançável não é a maquete
00:03 +22: estados honestos da tela pública build sem provedor operacional é terminal e sem botão
00:03 +23: estados honestos da tela pública erro de login aparece redigido
00:03 +24: transporte inicialização autenticada não abre socket nenhum
00:03 +25: transporte abrir o lobby conecta UMA vez, mesmo com o status mudando
00:03 +26: transporte logout fecha o socket e cancela a reconexão
00:04 +27: transporte a credencial não aparece em lugar nenhum da interface
00:04 +28: sem conexão, o ciclo automático desiste e diz isso
00:04 +29: endereço de servidor inválido é falha terminal, não tentativa
00:04 +30: All tests passed!
```
## cascaaud (tail)
```
00:00 +0: loading /home/runner/work/buraco-master-vip-app/buraco-master-vip-app/app_build/test/casca/auditoria_casca_test.dart
00:00 +0: (setUpAll)
00:00 +0: não existe segundo dono de autenticação authStateChanges é assinado num lugar só do cliente
00:00 +1: não existe segundo dono de autenticação só a camada de sessão importa firebase_auth ou google_sign_in
00:00 +2: não existe segundo dono de autenticação nenhuma tela alcançável guarda o usuário do provedor
00:00 +3: não existe segundo dono de autenticação o transporte continua sem saber falar com o provedor
00:00 +4: a raiz de produção não alcança maquete nenhum arquivo alcançável CONSTRÓI um .mock()
00:00 +5: a raiz de produção não alcança maquete main.dart não hospeda host de pré-visualização
00:00 +6: a raiz de produção não alcança maquete nenhuma tela de prévia declarada é alcançável
00:00 +7: a raiz de produção não alcança maquete o Perfil alcançável não exibe números de demonstração
00:00 +8: a raiz de produção não alcança maquete o ramo publicável do Perfil não escreve valor nenhum
00:00 +9: a raiz de produção não alcança maquete o convite copiado não carrega valor inventado
00:00 +10: nenhum dado pessoal real em lib/ nenhum e-mail de domínio real aparece no código
00:00 +11: nenhum dado pessoal real em lib/ os dados pessoais conhecidos sumiram do código
00:00 +12: nenhum dado pessoal real em lib/ a Home de produção não exibe o e-mail da conta
00:00 +13: transporte único só a raiz constrói OnlineService no código alcançável
00:00 +14: transporte único a raiz monta a ponte de sessão
00:00 +15: transporte único a raiz não conecta o transporte sozinha
00:00 +16: sessão, casca e transporte não escrevem em log
00:00 +17: (tearDownAll)
00:00 +17: All tests passed!
```
## cascavisao (tail)
```
00:00 +11: visão inválida é recusada, não completada uma carta quebrada invalida a mão inteira
00:00 +12: visão inválida é recusada, não completada placar sem uma das duplas
00:00 +13: visão inválida é recusada, não completada placar com texto no lugar do número
00:00 +14: visão inválida é recusada, não completada contagens negativas ou ausentes
00:00 +15: visão inválida é recusada, não completada sem modalidade, sem rodada, sem vez
00:00 +16: visão inválida é recusada, não completada lugares da mesa incompletos
00:00 +17: visão inválida é recusada, não completada jogos baixados ilegíveis
00:00 +18: visão inválida é recusada, não completada topo do lixo presente mas ilegível
00:00 +19: visão inválida é recusada, não completada topo do lixo ausente é lixo vazio, e isso é legítimo
00:00 +20: visão inválida é recusada, não completada a recusa não cita conteúdo da visão
00:00 +21: carta alheia não atravessa do outro assento só vem a contagem
00:00 +22: carta alheia não atravessa um campo com a mão alheia na visão é simplesmente ignorado
00:00 +23: carta alheia não atravessa jogadorId e avatar não entram no estado de apresentação
00:00 +24: capacidades minha vez, ainda não comprei: compro e não descarto
00:00 +25: capacidades minha vez, já comprei: baixo e descarto, não compro de novo
00:00 +26: capacidades vez de outro: nada
00:00 +27: capacidades rodada ou partida encerrada barram tudo, mesmo sendo minha vez
00:00 +28: capacidades sem conexão autenticada não há capacidade nenhuma
00:00 +29: capacidades a obrigação do topo destaca a carta, mas não bloqueia o descarte
00:00 +30: ordem sem versão declarada, a mais nova é a última que chegou
00:00 +31: ordem com versão declarada, a maior substitui
00:00 +32: ordem com versão declarada, a menor é recusada
00:00 +33: ordem versão igual passa — é a retransmissão depois de reconectar
00:00 +34: ordem a primeira visão sempre entra
00:00 +35: All tests passed!
```
## cascamesaaud (tail)
```
00:00 +0: loading /home/runner/work/buraco-master-vip-app/buraco-master-vip-app/app_build/test/casca/auditoria_mesa_online_test.dart
00:00 +0: não existe partida local sob a conexão online nada no caminho online constrói um Jogo
00:00 +1: não existe partida local sob a conexão online a mesa online não importa o módulo da partida local
00:00 +2: nenhuma tela da mesa online observa autenticação por conta própria
00:00 +3: a mesa online não registra nada em log
00:00 +4: a arte das cartas a convenção do online é a mesma do treino
00:00 +5: a arte das cartas toda arte de carta referenciada existe no repositório
00:00 +6: a arte das cartas a pasta da arte está declarada no pubspec
00:00 +7: só o adaptador lê a visão crua
00:00 +8: All tests passed!
```
## cascav2 (tail)
```
To silence this warning, pass "warnIfMissed: false" to "tap()".
To make this warning fatal, set WidgetController.hitTestWarningShouldBeFatal to true.


Warning: A call to tap() with finder "Found 1 widget with text "Loja VIP" (ignoring all but first): [
  Text("Loja VIP", inherit: true, color: Color(alpha: 0.7000, red: 1.0000, green: 1.0000, blue: 1.0000, colorSpace: ColorSpace.sRGB), size: 10.4, height: 1.1x, textAlign: center, overflow: ellipsis, maxLines: 2, dependencies: [DefaultSelectionStyle, DefaultTextStyle, MediaQuery, _ScrollableScope]),
]" derived an Offset (Offset(53.6, 520.2)) that would not hit test on the specified widget.
Maybe the widget is actually off-screen, or another widget is obscuring it, or the widget cannot receive pointer events.
The finder corresponds to this RenderBox: RenderParagraph#6f414 relayoutBoundary=up5
The hit test result at that offset is: HitTestResult(HitTestEntry<HitTestTarget>#f78cf(TextSpan(debugLabel: ((englishLike bodyMedium 2021).merge((whiteMountainView bodyMedium).apply)).merge(unknown), inherit: false, color: Color(alpha: 0.3400, red: 1.0000, green: 1.0000, blue: 1.0000, colorSpace: ColorSpace.sRGB), family: Roboto, size: 8.4, weight: 700, letterSpacing: 0.3, baseline: alphabetic, height: 1.4x, leadingDistribution: even, decoration: Color(alpha: 1.0000, red: 0.9020, green: 0.8784, blue: 0.9137, colorSpace: ColorSpace.sRGB) TextDecoration.none, "em breve")), RenderParagraph#32f2d@Offset(36.6, 2.6), RenderStack#129e3@Offset(36.6, 57.4), RenderPadding#404f5@Offset(37.6, 58.4), RenderPointerListener#8cdc8@Offset(37.6, 58.4), RenderSemanticsAnnotations#7ce73@Offset(37.6, 58.4), RenderMouseRegion#bfe62@Offset(37.6, 58.4), RenderSemanticsAnnotations#fa827@Offset(37.6, 58.4), _RenderInkFeatures#bdb66@Offset(37.6, 58.4), RenderPhysicalModel#41567@Offset(37.6, 58.4), RenderRepaintBoundary#a552d@Offset(37.6, 58.4), RenderIndexedSemantics#d333e@Offset(37.6, 58.4), RenderSliverGrid@(mainAxis: 141.16176470588232, crossAxis: 37.625), RenderSliverPadding@(mainAxis: 141.16176470588232, crossAxis: 37.625), RenderShrinkWrappingViewport#61e74@Offset(37.6, 141.2), RenderIgnorePointer#f1efb@Offset(37.6, 141.2), RenderSemanticsAnnotations#4ac49@Offset(37.6, 141.2), RenderPointerListener#c7a9a@Offset(37.6, 141.2), RenderSemanticsGestureHandler#5536d@Offset(37.6, 141.2), RenderPointerListener#a1fab@Offset(37.6, 141.2), _RenderScrollSemantics#a8560@Offset(37.6, 141.2), RenderClipRect#2f5a1@Offset(37.6, 141.2), RenderRepaintBoundary#49215@Offset(37.6, 141.2), RenderIndexedSemantics#ba721@Offset(37.6, 141.2), RenderSliverList@(mainAxis: 512.1617647058823, crossAxis: 37.625), RenderSliverPadding@(mainAxis: 520.1617647058823, crossAxis: 53.625), RenderViewport#311a6@Offset(53.6, 520.2), RenderIgnorePointer#f3445@Offset(53.6, 520.2), RenderSemanticsAnnotations#287ab@Offset(53.6, 520.2), RenderPointerListener#95d2d@Offset(53.6, 520.2), RenderSemanticsGestureHandler#5b6cb@Offset(53.6, 520.2), RenderPointerListener#154df@Offset(53.6, 520.2), _RenderScrollSemantics#6fb2d@Offset(53.6, 520.2), RenderClipRect#f2f54@Offset(53.6, 520.2), _RenderLayoutBuilder#562e6@Offset(53.6, 520.2), RenderStack#1f762@Offset(53.6, 520.2), RenderFlex#6ae8c@Offset(53.6, 520.2), RenderConstrainedBox#fcdba@Offset(53.6, 520.2), RenderPositionedBox#469f4@Offset(53.6, 520.2), RenderPadding#de66d@Offset(53.6, 520.2), RenderDecoratedBox#46137@Offset(53.6, 520.2), RenderCustomMultiChildLayoutBox#d0bea@Offset(53.6, 520.2), _RenderInkFeatures#72d7b@Offset(53.6, 520.2), RenderPhysicalModel#2d2ae@Offset(53.6, 520.2), RenderSemanticsAnnotations#11126@Offset(53.6, 520.2), RenderRepaintBoundary#5f3e7@Offset(53.6, 520.2), RenderIgnorePointer#23da2@Offset(53.6, 520.2), RenderAnimatedOpacity#9462c@Offset(53.6, 520.2), RenderAnimatedOpacity#87463@Offset(53.6, 520.2), _RenderColoredBox#8b69b@Offset(53.6, 520.2), RenderAnimatedOpacity#a4554@Offset(53.6, 520.2), RenderIgnorePointer#6881b@Offset(53.6, 520.2), RenderAnimatedOpacity#c3fb2@Offset(53.6, 520.2), RenderRepaintBoundary#f8c44@Offset(53.6, 520.2), RenderSemanticsAnnotations#f7916@Offset(53.6, 520.2), RenderOffstage#0d546@Offset(53.6, 520.2), RenderSemanticsAnnotations#e945e@Offset(53.6, 520.2), _RenderTheater#4908d@Offset(53.6, 520.2), RenderAbsorbPointer#b864b@Offset(53.6, 520.2), RenderPointerListener#b168e@Offset(53.6, 520.2), RenderSemanticsAnnotations#1d138@Offset(53.6, 520.2), RenderSemanticsAnnotations#7462d@Offset(53.6, 520.2), RenderSemanticsAnnotations#ee238@Offset(53.6, 520.2), RenderSemanticsAnnotations#d8499@Offset(53.6, 520.2), RenderTapRegionSurface#c154e@Offset(53.6, 520.2), RenderSemanticsAnnotations#32ffd@Offset(53.6, 520.2), RenderSemanticsAnnotations#1655a@Offset(53.6, 520.2), HitTestEntry<HitTestTarget>#9c61a(_ReusableRenderView#b51af), HitTestEntry<HitTestTarget>#b9a2c(<AutomatedTestWidgetsFlutterBinding>))
#0      WidgetController._getElementPoint (package:flutter_test/src/controller.dart:2165:25)
#1      WidgetController.getCenter (package:flutter_test/src/controller.dart:1947:12)
#2      WidgetController.tap (package:flutter_test/src/controller.dart:1080:7)
#3      main.<anonymous closure> (file:///home/runner/work/buraco-master-vip-app/buraco-master-vip-app/app_build/test/casca/homologacao_casca_v2_test.dart:611:20)
<asynchronous suspension>
#4      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#5      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1952:5)
<asynchronous suspension>
#6      StackZoneSpecification._registerCallback.<anonymous closure> (package:stack_trace/src/stack_zone_specification.dart:114:42)
<asynchronous suspension>
To silence this warning, pass "warnIfMissed: false" to "tap()".
To make this warning fatal, set WidgetController.hitTestWarningShouldBeFatal to true.

00:03 +12: All tests passed!
```
## cascaligacao (tail)
```
00:00 +0: loading /home/runner/work/buraco-master-vip-app/buraco-master-vip-app/app_build/test/casca/ligacao_mesa_caracterizacao_test.dart
00:00 +0: treino Home autenticada abre Onde Jogar
00:01 +1: treino Treino abre a MesaScreen jogável de lib/mesa.dart
00:01 +2: treino Treino não abre socket e não pede credencial
00:01 +3: transporte Mesa por código usa o OnlineService da raiz
00:01 +4: transporte abrir e fechar o lobby não constrói um segundo transporte
00:02 +5: transporte logout no lobby derruba a pilha e a capacidade de jogar
00:02 +6: All tests passed!
```
## cascamesa (tail)
```
00:03 +9: a visão que não descreve uma mesa a visão mais nova atualiza a mesa
00:03 +10: a visão que não descreve uma mesa a mesma visão duas vezes não acumula nada
00:03 +11: a mão alheia não aparece só a própria mão é desenhada; das outras, a contagem
00:04 +12: a mão alheia não aparece cartas de outros assentos na visão não vazam para a tela
00:04 +13: comandos comprar do monte manda a jogada do protocolo
00:04 +14: comandos duplo toque não envia duas intenções
00:04 +15: comandos a intenção pendente aparece na tela
00:05 +16: comandos descartar exige uma carta selecionada e manda o id dela
00:05 +17: comandos baixar manda a lista de ids selecionados
00:05 +18: comandos fora da minha vez não há ação oferecida
00:06 +19: comandos recusa de regra preserva o estado autoritativo
00:06 +20: queda e retomada a queda bloqueia ações novas e avisa
00:06 +21: queda e retomada a mesa continua desenhada durante a reconexão
00:06 +22: queda e retomada a retomada substitui a mesa pela visão nova
00:06 +23: sessão e saída logout EM PARTIDA encerra a capacidade de jogar
00:07 +24: sessão e saída trocar de conta elimina a pilha e o estado visual anterior
00:07 +25: sessão e saída sair da mesa não é sair da conta
00:07 +26: sessão e saída falha terminal oferece ação explícita, sem laço
00:07 +27: desfecho o encerramento autoritativo mostra o resultado uma vez
00:07 +28: desfecho quem bateu é lido do servidor, não do placar
00:07 +29: desfecho partida encerrada sem quem bateu não anuncia vencedor
00:08 +30: desfecho encerrada a partida, nenhuma ação é oferecida
00:08 +31: nada de segredo na tela a credencial não aparece em texto nenhum da mesa
00:08 +32: nada de segredo na tela nenhuma conquista é concedida por inferência do cliente
00:08 +33: All tests passed!
```
## cascaporta (tail)
```
00:00 +0: o gesto vira o comando do protocolo comprar do monte
00:00 +1: o gesto vira o comando do protocolo comprar o lixo
00:00 +2: o gesto vira o comando do protocolo descartar leva o id da carta
00:00 +3: o gesto vira o comando do protocolo baixar leva a lista de ids
00:00 +4: o gesto vira o comando do protocolo estender leva o índice do jogo e os ids
00:00 +5: o gesto vira o comando do protocolo baixar e estender vazios nem saem
00:00 +6: o gesto vira o comando do protocolo sair da mesa não é logout
00:00 +7: duplo toque dois toques iguais viram UMA mensagem
00:00 +8: duplo toque a trava vale para intenções DIFERENTES também
00:00 +9: duplo toque a intenção pendente é identificável pela tela
00:00 +10: duplo toque sair passa por cima da trava — é a saída de emergência
00:00 +11: a trava só sai por autoridade visão nova libera a próxima intenção
00:00 +12: a trava só sai por autoridade recusa do servidor libera, e o motivo fica na tela
00:00 +13: a trava só sai por autoridade o teto de espera destrava sem aplicar nada
00:00 +14: a trava só sai por autoridade a queda da conexão destrava e não reenvia
00:00 +15: a trava só sai por autoridade sem conexão autenticada o comando nem sai
00:00 +16: classificação da recusa recusa sem código é regra do Buraco
00:00 +17: classificação da recusa credencial expirada não é recusa de regra
00:00 +18: classificação da recusa identidade divergente também é autenticação
00:00 +19: classificação da recusa o código de uma recusa não contamina a seguinte
00:00 +20: classificação da recusa dispensar a recusa limpa o aviso e não reenvia nada
00:00 +21: nenhuma mutação local a visão do transporte é a mesma antes e depois de um comando
00:00 +22: nenhuma mutação local a recusa preserva o estado autoritativo
00:00 +23: nenhuma mutação local a mesma visão entregue duas vezes não acumula nada
00:00 +24: All tests passed!
```
## rkbarreira (tail)
```
00:00 +0: loading /home/runner/work/buraco-master-vip-app/buraco-master-vip-app/app_build/test/ranking/barreira_temporal_ranking_test.dart
00:00 +0: R1 — a virada chega pelo pedido de número MENOR R1a — T1 do pedido #2 não derruba T2 do pedido #1
00:00 +1: R1 — a virada chega pelo pedido de número MENOR R1b — a ordem original continua fechada
00:00 +2: R1 — a virada chega pelo pedido de número MENOR R1c — a virada sequencial LEGÍTIMA continua sendo aceita
00:00 +3: R2 — confirmar a temporada move a âncora R2a — depois de confirmada, o contemporâneo divergente não passa
00:00 +4: R2 — confirmar a temporada move a âncora R2b — a confirmação NÃO despeja o cache da própria temporada
00:00 +5: R2 — confirmar a temporada move a âncora R2c — depois de reancorada, um pedido REALMENTE posterior vira
00:00 +6: R3 — resposta divergente cujo pedido EMPATA com a barreira R3a — empate não é posterior: a divergente não passa
00:00 +7: R3 — resposta divergente cujo pedido EMPATA com a barreira R3b — e o empate não deixa a barreira envenenada
00:00 +8: R4 — `temporadaId` nulo é ausência de notícia R4a — nulo não estabelece, não derruba e não despeja
00:00 +9: R4 — `temporadaId` nulo é ausência de notícia R4b — nulo não move a âncora
00:00 +10: R4 — `temporadaId` nulo é ausência de notícia R4c — fotografia sem temporada sobrevive a uma virada
00:00 +11: R5 — a falha não mexe na autoridade temporal R5a — falha não estabelece nem derruba temporada
00:00 +12: R5 — a falha não mexe na autoridade temporal R5b — depois da falha, a virada legítima ainda é aceita
00:00 +13: R5 — a falha não mexe na autoridade temporal R5c — exceção fora do vocabulário também não move nada
00:00 +14: R6 — recusar é não tocar em nada R6a — retorno, cache e fotografia ficam exatamente como estavam
00:00 +15: R6 — recusar é não tocar em nada R6b — a recusa não muda a temporada aceita
00:00 +16: R7 — o voo velho termina depois do novo R7a — a resposta da conta anterior não é aplicada nem guardada
00:00 +17: R7 — o voo velho termina depois do novo R7b — o voo velho não leva a temporada da conta anterior junto
00:00 +18: R7 — o voo velho termina depois do novo R7d — MESMA conta, geração nova: o velho não despeja o novo
00:00 +19: R7 — o voo velho termina depois do novo R7c — o voo velho não remove o voo novo do mapa de dedupe
00:00 +20: R8 — o retry continua idempotente R8a — três toques seguidos produzem UMA chamada
00:00 +21: R8 — o retry continua idempotente R8b — três toques DEPOIS de uma troca de sessão também
00:00 +22: R8 — o retry continua idempotente R8c — depois de resolver, um toque novo emite chamada nova
00:00 +23: All tests passed!
```
## rkestado (tail)
```
00:01 +21: carregando e erro não viram dado erro depois de carregado não deixa resto do perfil na tela
00:01 +22: PerfilService — o produtor a chave de demonstração segue desligada
00:01 +23: PerfilService — o produtor o perfil publicável não recebe liga nem colocação
00:02 +24: PerfilService — o produtor o perfil publicável não recebe progressão, placar nem troféu
00:02 +25: PerfilService — o produtor o VM de carregamento diz carregando, e não indisponível
00:02 +26: compartilhamento sem ranking, o convite não cita liga nem colocação
00:02 +27: compartilhamento com ranking real, liga e colocação são preservadas
00:02 +28: compartilhamento liga real sem colocação compartilha só a liga
00:02 +29: compartilhamento colocação zero não vira #0 no texto público
00:02 +30: compartilhamento sem nível, o convite também não cita nível
00:02 +31: compartilhamento sem VM carregado, o convite não afirma nem nome
00:02 +32: Home e Perfil leem a mesma interpretação a casca publicável não tem autoridade de ranking, e diz isso uma vez só
00:02 +33: Home e Perfil leem a mesma interpretação o que a Home põe no cabeçalho é o que o Perfil recebe
00:02 +34: Home e Perfil leem a mesma interpretação a Home não desenha liga, e o Perfil não desenha Bronze
00:02 +35: sessão — nada sobrevive à troca logout não deixa estado competitivo anterior
00:02 +36: sessão — nada sobrevive à troca troca de conta sem logout não reaproveita nada da geração anterior
00:03 +37: sessão — nada sobrevive à troca o compartilhamento após a troca também não afirma nada
00:03 +38: auditoria — o literal não pode voltar (setUpAll)
00:03 +38: auditoria — o literal não pode voltar nenhum arquivo alcançável escreve Bronze como liga
00:03 +39: auditoria — o literal não pode voltar o texto de compartilhamento não tem fallback de liga
00:03 +40: auditoria — o literal não pode voltar nenhum arquivo alcançável interpola posição sem checar se ela existe
00:03 +41: auditoria — o literal não pode voltar a demonstração do Perfil não é alcançável pela raiz publicável
00:03 +42: auditoria — o literal não pode voltar a interpretação de "sem ranking" mora num lugar só
00:03 +43: auditoria — o literal não pode voltar (tearDownAll)
00:03 +43: All tests passed!
```
## rkperfil (tail)
```
00:00 +0: loading /home/runner/work/buraco-master-vip-app/buraco-master-vip-app/app_build/test/ranking/homologacao_perfil_publicavel_test.dart
00:00 +0: PROBE — higienização do estado canônico posicaoMundial 0, negativa e liga em branco viram ausência
00:00 +1: PROBE — higienização do estado canônico fora de disponivel, nem liga nem colocação atravessam
00:00 +2: PROBE — higienização do estado canônico ranking REAL atravessa sem substituição
00:00 +3: PROBE — a tela não desenha o que não tem fonte sem classificação: identidade e vitrine ficam, "💎 Liga —"
00:00 +4: PROBE — a tela não desenha o que não tem fonte nível/XP/título/placar/presentes/conquistas somem
00:00 +5: PROBE — a tela não desenha o que não tem fonte conquistas null = não consultado; [] = consultado e vazio
00:00 +6: PROBE — a tela não desenha o que não tem fonte XP exige os TRÊS campos: nenhum subconjunto desenha barra
00:01 +7: PROBE — a tela não desenha o que não tem fonte título sem emoji não vira "null Campeã"
00:01 +8: PROBE — carregando e erro carregando: esqueleto, sem nome nem número inventado
00:01 +9: PROBE — carregando e erro erro: pede recarga e NÃO reaproveita o VM anterior
00:01 +10: PROBE — o convite que sai do aparelho sem nada competitivo, fecha em "Sou {nome} 👑" sem órfão
00:01 +11: PROBE — o convite que sai do aparelho com dado real, o convite volta a afirmar — e pontua certo
00:01 +12: PROBE — o convite que sai do aparelho colocação 0 vinda da fonte não vira "#0" no convite
00:01 +13: PROBE — o convite que sai do aparelho sem VM não afirma nem nome
00:01 +14: PROBE — a mesma fonte canônica em toda superfície Home, Perfil e convite leem a MESMA instância
00:01 +15: PROBE — a mesma fonte canônica em toda superfície o serviço publicável não entrega nenhum dos oito absorvidos
00:02 +16: All tests passed!
```
## rkleitor (tail)
```
00:00 +19: o leitor protege a resposta contra o tempo CASO 12 — dois publicId simultâneos não se atropelam
00:00 +20: o leitor protege a resposta contra o tempo CASO 13 — o cache não vaza entre jogadores
00:00 +21: o leitor protege a resposta contra o tempo o perfil próprio e o visitado não dividem entrada
00:00 +22: o leitor protege a resposta contra o tempo CASO 14 — virada de temporada invalida a fotografia anterior
00:00 +23: o leitor protege a resposta contra o tempo exceção fora do vocabulário não derruba quem chamou
00:00 +24: Home e Perfil leem a mesma autoridade CASO 19 — o mesmo objeto alimenta as duas
00:00 +25: Home e Perfil leem a mesma autoridade a Home não mostra rótulo de qualificação como liga
00:00 +26: Home e Perfil leem a mesma autoridade CASO 20 — sem autoridade, o convite não cita liga
00:00 +27: Home e Perfil leem a mesma autoridade com autoridade, o convite cita o que ela disse
00:00 +28: Home e Perfil leem a mesma autoridade posição zero da autoridade não sai do aparelho
00:00 +29: a linha competitiva é anunciada, e não soletrada CASO 21a — liga com posição
00:00 +30: a linha competitiva é anunciada, e não soletrada CASO 21b — liga sem posição válida
00:00 +31: a linha competitiva é anunciada, e não soletrada CASO 21c — ranking indisponível
00:01 +32: a linha competitiva é anunciada, e não soletrada CASO 21d — atualização em andamento
00:01 +33: a linha competitiva é anunciada, e não soletrada CASO 21e — falha com ação de tentar novamente
00:01 +34: a linha competitiva é anunciada, e não soletrada sessão inválida não promete retry
00:01 +35: a linha competitiva é anunciada, e não soletrada sem colocação nenhuma: "ainda não classificado"
00:01 +36: a linha competitiva é anunciada, e não soletrada CASO 18 — nenhum fallback aparece na tela sem autoridade
00:01 +37: auditoria — o literal competitivo não pode nascer no cliente (setUpAll)
00:01 +37: auditoria — o literal competitivo não pode nascer no cliente nenhum nome de liga é escrito no módulo de ranking
00:01 +38: auditoria — o literal competitivo não pode nascer no cliente nenhum arquivo do ranking imprime identificador
00:01 +39: auditoria — o literal competitivo não pode nascer no cliente só o adaptador de Firebase conhece cloud_functions
00:01 +40: auditoria — o literal competitivo não pode nascer no cliente a região das callables casa com a do backend
00:01 +41: auditoria — o literal competitivo não pode nascer no cliente (tearDownAll)
00:01 +41: All tests passed!
```
## rkregressao (tail)
```
00:00 +0: loading /home/runner/work/buraco-master-vip-app/buraco-master-vip-app/app_build/test/ranking/regressao_leitor_ranking_test.dart
00:00 +0: A — resposta de temporada vencida, entre chaves diferentes A1 — a resposta atrasada de T1 não é devolvida nem armazenada, e o cache de T2 fica intacto
00:00 +1: A — resposta de temporada vencida, entre chaves diferentes A2 — o cenário inverso: o pedido posterior INAUGURA T2
00:00 +2: A — resposta de temporada vencida, entre chaves diferentes A3 — três chaves simultâneas, a do meio inaugura T2
00:00 +3: A — resposta de temporada vencida, entre chaves diferentes A4 — a MESMA temporada em chaves diferentes continua válida
00:00 +4: A — resposta de temporada vencida, entre chaves diferentes A5 — temporada nula não apaga a conhecida nem envenena o cache
00:00 +5: A — resposta de temporada vencida, entre chaves diferentes A6 — logout durante as chamadas descarta tudo o que estava em voo
00:00 +6: A — resposta de temporada vencida, entre chaves diferentes A7 — a troca de jogador zera também a autoridade temporal
00:00 +7: A — resposta de temporada vencida, entre chaves diferentes A8 — resposta antiga da MESMA chave continua sendo descartada
00:00 +8: A — resposta de temporada vencida, entre chaves diferentes A9 — isolamento entre contas sobrevive à proteção temporal
00:00 +9: B — credencial ou atestação recusada B1 — sem sessão local, `unauthenticated` É sessão inválida
00:00 +10: B — credencial ou atestação recusada B2 — com sessão local ativa, `unauthenticated` é acesso recusado, e NÃO sessão expirada
00:00 +11: B — credencial ou atestação recusada B3 — a falha de App Check é INDISTINGUÍVEL da de credencial, e cai no mesmo estado neutro
00:00 +12: B — credencial ou atestação recusada B4 — `permission-denied` com sessão ativa também é neutro
00:00 +13: B — credencial ou atestação recusada B5 — falhas recuperáveis continuam sendo falha com retry
00:00 +14: B — credencial ou atestação recusada B6 — payload inválido é falha, e não ausência
00:00 +15: B — credencial ou atestação recusada B7 — nenhuma falha entra no cache
00:00 +16: B — credencial ou atestação recusada B8 — nenhuma fase de falha carrega liga ou posição
00:00 +17: B — credencial ou atestação recusada B9 — três toques no retry produzem UMA chamada nova
00:00 +18: B — a tela não promete o que o botão não cumpre B10 — o acesso recusado tem mensagem neutra
00:00 +19: B — a tela não promete o que o botão não cumpre B11 — o acesso recusado oferece tentar de novo, e o botão da tela é o que cumpre a promessa
00:01 +20: B — a tela não promete o que o botão não cumpre B12 — a sessão realmente inválida continua sem prometer retry
00:01 +21: B — a tela não promete o que o botão não cumpre B13 — nenhum estado de falha afirma liga, nem para exibição
00:01 +22: All tests passed!
```
## composicao (tail)
```
00:00 +0: loading /home/runner/work/buraco-master-vip-app/buraco-master-vip-app/app_build/test/composicao/composicao_perfil_ranking_test.dart
00:00 +0: C1 — o Perfil próprio bebe do escopo de ranking C1 — o Perfil próprio recebe o ranking REAL do escopo
00:00 +1: C1 — o Perfil próprio bebe do escopo de ranking C2 — o ranking chega DEPOIS e a tela acompanha, sem recarregar o perfil
00:00 +2: C1 — o Perfil próprio bebe do escopo de ranking C12 — uma reconstrução não abre callable nova
00:01 +3: C1 — o Perfil próprio bebe do escopo de ranking C13 — três retries concorrentes produzem UMA chamada
00:01 +4: C1 — o Perfil próprio bebe do escopo de ranking C6 — resposta antiga, depois da troca de sessão, não aparece
00:01 +5: C1 — o Perfil próprio bebe do escopo de ranking C7 — resposta de temporada vencida não aparece
00:01 +6: C1 — o Perfil próprio bebe do escopo de ranking C3 — o visitado é escolhido SÓ pelo publicIdVisitado
00:01 +7: C1 — o Perfil próprio bebe do escopo de ranking C4 — visitado SEM alvo não chama o transporte
00:01 +8: C1 — o Perfil próprio bebe do escopo de ranking C5 — visitado SEM sessão não chama o transporte
00:01 +9: C1 — o Perfil próprio bebe do escopo de ranking C8 — sem nível, nada de "Nível null" na tela nem no convite
00:01 +10: C1 — o Perfil próprio bebe do escopo de ranking C9 — sem liga, nada de Bronze na tela nem no convite
00:01 +11: C1 — o Perfil próprio bebe do escopo de ranking C10 — sem colocação, nada de #0 nem de #1
00:01 +12: C11–C16 — as autoridades continuam únicas (setUpAll)
00:01 +12: C11–C16 — as autoridades continuam únicas C11 — o PerfilService não consulta ranking
00:01 +13: C11–C16 — as autoridades continuam únicas C11b — só o adaptador de Firebase conhece cloud_functions
00:01 +14: C11–C16 — as autoridades continuam únicas C11c — só a cadeia de sessão observa o Firebase Auth
00:01 +15: C11–C16 — as autoridades continuam únicas C14 — a Mesa Online mantém as portas únicas
00:01 +16: C11–C16 — as autoridades continuam únicas C15 — a cadeia Home → PerfilPage → PerfilScreen é única
00:01 +17: C11–C16 — as autoridades continuam únicas C16 — main.dart permanece byte a byte o das duas entradas
00:01 +18: C11–C16 — as autoridades continuam únicas C17 — o ranking é alcançável pela raiz, e por um caminho só
00:01 +19: C11–C16 — as autoridades continuam únicas (tearDownAll)
00:01 +19: All tests passed!
```
## portaoci (tail)
```
  ok    C0? — rankingfn exit 1 => VERMELHO (CI-02) (exit 1)
  ok    C0? — rankingint exit 1 => VERMELHO (CI-02) (exit 1)
  ok    C0? — identint exit 1 => VERMELHO (CI-02) (exit 1)
  ok    C0? — auditident exit 1 => VERMELHO (CI-02) (exit 1)
  ok    C08 — marcador nao_regras => VERMELHO (CI-03) (exit 1)
  ok    C08b — nao_socialemu ao lado de exit 0 => VERMELHO (exit 1)
  ok    C09 — casca sem exit e sem marcador => VERMELHO (CI-03) (exit 1)
  ok    C10 — exit_motor vazio => VERMELHO (exit 1)
  ok    C10b — exit_motor só com espaços => VERMELHO (exit 1)
  ok    C11 — exit_analyze não numérico => VERMELHO (exit 1)
  ok    C11b — exit_billing com injeção de comando => VERMELHO, sem interpretar (exit 1)
  ok    C12a — gate desconhecido vermelho NÃO reprova o portão (exit 0)
  ok    C12b — gate desconhecido verde NÃO substitui composicao ausente (exit 1)
  ok    C13 — obrigatórios restaurados em exit 0 => VERDE novamente (exit 0)

== fonte única inválida (falha fechada) ==
  ok    C14 — fonte sem nenhum gate => exit 2 (reprova)
  ok    C15 — nome de gate com travessia de caminho => exit 2
  ok    C16 — gate duplicado na fonte => exit 2
  ok    C17 — fonte única ausente => exit 2
  ok    C18 — diretório de resultados ausente => exit 2

----------------------------------------
casos ok: 29 | casos com falha: 0
TESTE DO PORTÃO: VERDE
```
## billing (tail)
```
  ...
# Subtest: concorrência: duas entregas do mesmo token creditam UMA vez
ok 11 - concorrência: duas entregas do mesmo token creditam UMA vez
  ---
  duration_ms: 0.269701
  ...
# Subtest: concorrência: reentregas repetidas não acumulam saldo
ok 12 - concorrência: reentregas repetidas não acumulam saldo
  ---
  duration_ms: 0.18791
  ...
# Subtest: concorrência: documento inexistente ainda credita uma vez só
ok 13 - concorrência: documento inexistente ainda credita uma vez só
  ---
  duration_ms: 0.20459
  ...
1..13
# tests 13
# suites 0
# pass 13
# fail 0
# cancelled 0
# skipped 0
# todo 0
# duration_ms 67.281135
```
## torneiosfn (tail)
```
```
## socialdom (tail)
```

> build:domain
> cd .. && dart compile js -O2 -o functions-social/lib/domain_bundle.js app/lib/social/js_bridge.dart

Compiled 10,417,716 input bytes (5,356,094 characters source) to 83,430 characters JavaScript in 0.75 seconds
```
## socialfn (tail)
```
  ---
  duration_ms: 1.674334
  type: 'suite'
  ...
# Subtest: colecoes: os tres documentos de identidade sao separados
    # Subtest: cada papel tem a sua colecao
    ok 1 - cada papel tem a sua colecao
      ---
      duration_ms: 0.150369
      ...
    1..1
ok 15 - colecoes: os tres documentos de identidade sao separados
  ---
  duration_ms: 0.235177
  type: 'suite'
  ...
1..15
# tests 45
# suites 15
# pass 45
# fail 0
# cancelled 0
# skipped 0
# todo 0
# duration_ms 105.194382
```
## socialemu (tail)
```
      ...
    1..33
ok 7 - Functions sociais
  ---
  duration_ms: 16395.801612
  type: 'suite'
  ...
1..7
# tests 67
# suites 7
# pass 67
# fail 0
# cancelled 0
# skipped 0
# todo 0
# duration_ms 19224.86965
[32m[1m✔ [22m[39m Script exited successfully (code 0)
[36m[1mi  emulators:[22m[39m Shutting down emulators.
[36m[1mi  functions:[22m[39m Stopping Functions Emulator
[36m[1mi  firestore:[22m[39m Stopping Firestore Emulator
[36m[1mi  auth:[22m[39m Stopping Authentication Emulator
[36m[1mi  eventarc:[22m[39m Stopping Eventarc Emulator
[36m[1mi  tasks:[22m[39m Stopping Cloud Tasks Emulator
[36m[1mi  hub:[22m[39m Stopping emulator hub
[36m[1mi  logging:[22m[39m Stopping Logging Emulator
```
## regras (tail)
```
  ...
# Subtest: Functions sociais
ok 34 - Functions sociais # SKIP
  ---
  duration_ms: 0.074178
  type: 'suite'
  ...
1..34
# tests 147
# suites 34
# pass 147
# fail 0
# cancelled 0
# skipped 0
# todo 0
# duration_ms 7818.139552
[32m[1m✔ [22m[39m Script exited successfully (code 0)
[36m[1mi  emulators:[22m[39m Shutting down emulators.
[36m[1mi  functions:[22m[39m Stopping Functions Emulator
[36m[1mi  firestore:[22m[39m Stopping Firestore Emulator
[36m[1mi  auth:[22m[39m Stopping Authentication Emulator
[36m[1mi  eventarc:[22m[39m Stopping Eventarc Emulator
[36m[1mi  tasks:[22m[39m Stopping Cloud Tasks Emulator
[36m[1mi  hub:[22m[39m Stopping emulator hub
[36m[1mi  logging:[22m[39m Stopping Logging Emulator
```
## rankingfn (tail)
```
    # Subtest: temporada sem data de termino nao exibe contagem
    ok 6 - temporada sem data de termino nao exibe contagem
      ---
      duration_ms: 0.109503
      ...
    # Subtest: data ilegivel nao quebra a tela
    ok 7 - data ilegivel nao quebra a tela
      ---
      duration_ms: 0.109042
      ...
    1..7
ok 73 - temporada: a faixa de tempo que o cliente exibe
  ---
  duration_ms: 4.15727
  type: 'suite'
  ...
1..73
# tests 330
# suites 73
# pass 330
# fail 0
# cancelled 0
# skipped 0
# todo 0
# duration_ms 612.072954
```
## rankingint (tail)
```
    # Subtest: temporada nova e soft reset NAO trocam o publicId (§22.14 e §22.15)
    ok 3 - temporada nova e soft reset NAO trocam o publicId (§22.14 e §22.15)
      ---
      duration_ms: 525.859431
      ...
    1..3
ok 8 - integracao: encerramento, consolidacao e a temporada seguinte
  ---
  duration_ms: 1064.394496
  type: 'suite'
  ...
1..8
# tests 27
# suites 8
# pass 27
# fail 0
# cancelled 0
# skipped 0
# todo 0
# duration_ms 14691.592505
[32m[1m✔ [22m[39m Script exited successfully (code 0)
[36m[1mi  emulators:[22m[39m Shutting down emulators.
[36m[1mi  firestore:[22m[39m Stopping Firestore Emulator
[36m[1mi  hub:[22m[39m Stopping emulator hub
[36m[1mi  logging:[22m[39m Stopping Logging Emulator
```
## identint (tail)
```
    # Subtest: §14 — identidade publica existe sem VIP e nao da vantagem nenhuma
    ok 3 - §14 — identidade publica existe sem VIP e nao da vantagem nenhuma
      ---
      duration_ms: 193.935837
      ...
    1..3
ok 3 - a integracao nao mexeu no que nao e dela (§12, §13, §14)
  ---
  duration_ms: 536.788301
  type: 'suite'
  ...
1..3
# tests 14
# suites 3
# pass 14
# fail 0
# cancelled 0
# skipped 0
# todo 0
# duration_ms 11871.68717
[32m[1m✔ [22m[39m Script exited successfully (code 0)
[36m[1mi  emulators:[22m[39m Shutting down emulators.
[36m[1mi  firestore:[22m[39m Stopping Firestore Emulator
[36m[1mi  hub:[22m[39m Stopping emulator hub
[36m[1mi  logging:[22m[39m Stopping Logging Emulator
```
## auditident (tail)
```
[36m[1mi  emulators:[22m[39m Starting emulators: firestore
[36m[1mi  emulators:[22m[39m Detected demo project ID "demo-bmv", emulated services will use a demo configuration and attempts to access non-emulated services for this project will fail.
[36m[1mi  firestore:[22m[39m Firestore Emulator logging to [1mfirestore-debug.log[22m
[32m[1m✔  firestore:[22m[39m Firestore Emulator was started in standard edition.
[32m[1m✔  firestore:[22m[39m Firestore Emulator UI websocket is running on 9150.
[36m[1mi [22m[39m Running script: [1mcd functions-social && node scripts/auditar-identidade.js[22m
AUDITORIA DE IDENTIDADE PUBLICA — DRY-RUN (nada foi alterado)

conferidos: 0 identidades, 0 reversos, 0 perfis, 0 projecoes competitivas, 0 uids conhecidos.

NENHUM ACHADO. As duas linhas convergem para a mesma identidade.
[32m[1m✔ [22m[39m Script exited successfully (code 0)
[36m[1mi  emulators:[22m[39m Shutting down emulators.
[36m[1mi  firestore:[22m[39m Stopping Firestore Emulator
[36m[1mi  hub:[22m[39m Stopping emulator hub
[36m[1mi  logging:[22m[39m Stopping Logging Emulator
```
