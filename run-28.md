# Evidência CI — run 28

- branch: `composicao/bmv-pub-c1-comp1-candidata-play-v1`
- commit: `4bd20cca669432548a192d5d8ff69977000a2ed4`
- data UTC: 2026-10-01T17:47:19Z

## Veredito do agregador (`scripts/ci/portao_os_integracao.sh`)

Portão final: exit `1` — NÃO EXECUTADO reprova, exit vazio ou não numérico reprova.

```
portão OS Integração — fonte: scripts/ci/gates_os_integracao.txt
resultados em: .

analyze        VERDE          exit 0
motor          VERDE          exit 0
resil          VERDE          exit 0
encerr         VERDE          exit 0
torneios       VERDE          exit 0
mtorneios      VERMELHO       exit 1
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
cascaloja      VERDE          exit 0
rkbarreira     VERDE          exit 0
rkestado       VERDE          exit 0
rkperfil       VERDE          exit 0
rkleitor       VERDE          exit 0
rkregressao    VERDE          exit 0
composicao     VERDE          exit 0
chatdom        VERDE          exit 0
comunicacao    VERDE          exit 0
portaoci       VERDE          exit 0
contratosui    VERDE          exit 0
autverif       VERDE          exit 0
billing        VERDE          exit 0
torneiosfn     VERDE          exit 0
socialdom      VERDE          exit 0
socialfn       VERDE          exit 0
socialemu      VERDE          exit 0
passeint       VERDE          exit 0
rankingfn      VERDE          exit 0
rankingint     VERDE          exit 0
identint       VERDE          exit 0
auditident     VERDE          exit 0
moderacaofn    VERDE          exit 0
chatemu        VERDE          exit 0
moderacaoemu   VERDE          exit 0
colecoesemu    VERDE          exit 0
contafn        VERDE          exit 0
contaemu       VERDE          exit 0
mesasfn        VERDE          exit 0
economiafn     VERDE          exit 0
proveni        VERDE          exit 0
composneg      VERDE          exit 0
rkpagina       VERDE          exit 0
composloja     VERDE          exit 0
avatarcanon    VERDE          exit 0
avatarhml      VERDE          exit 0
perfilvis      VERDE          exit 0
rknavpub       VERDE          exit 0
compavrank     VERDE          exit 0
compnavpub     VERDE          exit 0
socialestado   VERDE          exit 0
socialleitor   VERDE          exit 0
socialtela     VERDE          exit 0
audsocial      VERDE          exit 0
a11yamigos     VERDE          exit 0
torneiobase    VERMELHO       exit 1
admvip         VERDE          exit 0
appcheckandroid VERDE          exit 0
temavip        VERDE          exit 0
treinosan      VERDE          exit 0
lojaa11y       VERDE          exit 0
descstbl       VERDE          exit 0
descadapt      VERDE          exit 0
descestado     VERDE          exit 0
desclobby      VERDE          exit 0
deschome       VERDE          exit 0
ingrcontrato   VERMELHO       exit 1
ingrassento    VERDE          exit 0
ingrnav        VERDE          exit 0
ingrtransp     VERDE          exit 0
encui          VERDE          exit 0
encpend        VERDE          exit 0
encpendack     VERDE          exit 0
ordemvisao     VERDE          exit 0
obscaptura     VERDE          exit 0
obsgatilho     VERDE          exit 0
obsidentidade  VERDE          exit 0
obsredacao     VERDE          exit 0
obsredurl      VERDE          exit 0
mesaa11y       VERDE          exit 0
a11yestados    VERDE          exit 0
a11yconf       VERDE          exit 0

obrigatórios: 91 | verdes: 88 | fora da fonte: 0
resultado: VERMELHO
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
| mtorneios | **FALHOU** | 1 |
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
| cascaloja | EXECUTADO | 0 |
| rkbarreira | EXECUTADO | 0 |
| rkestado | EXECUTADO | 0 |
| rkperfil | EXECUTADO | 0 |
| rkleitor | EXECUTADO | 0 |
| rkregressao | EXECUTADO | 0 |
| composicao | EXECUTADO | 0 |
| chatdom | EXECUTADO | 0 |
| comunicacao | EXECUTADO | 0 |
| portaoci | EXECUTADO | 0 |
| contratosui | EXECUTADO | 0 |
| autverif | EXECUTADO | 0 |
| billing | EXECUTADO | 0 |
| torneiosfn | EXECUTADO | 0 |
| socialdom | EXECUTADO | 0 |
| socialfn | EXECUTADO | 0 |
| socialemu | EXECUTADO | 0 |
| passeint | EXECUTADO | 0 |
| rankingfn | EXECUTADO | 0 |
| rankingint | EXECUTADO | 0 |
| identint | EXECUTADO | 0 |
| auditident | EXECUTADO | 0 |
| moderacaofn | EXECUTADO | 0 |
| chatemu | EXECUTADO | 0 |
| moderacaoemu | EXECUTADO | 0 |
| colecoesemu | EXECUTADO | 0 |
| contafn | EXECUTADO | 0 |
| contaemu | EXECUTADO | 0 |
| mesasfn | EXECUTADO | 0 |
| economiafn | EXECUTADO | 0 |
| proveni | EXECUTADO | 0 |
| composneg | EXECUTADO | 0 |
| rkpagina | EXECUTADO | 0 |
| composloja | EXECUTADO | 0 |
| avatarcanon | EXECUTADO | 0 |
| avatarhml | EXECUTADO | 0 |
| perfilvis | EXECUTADO | 0 |
| rknavpub | EXECUTADO | 0 |
| compavrank | EXECUTADO | 0 |
| compnavpub | EXECUTADO | 0 |
| socialestado | EXECUTADO | 0 |
| socialleitor | EXECUTADO | 0 |
| socialtela | EXECUTADO | 0 |
| audsocial | EXECUTADO | 0 |
| a11yamigos | EXECUTADO | 0 |
| torneiobase | **FALHOU** | 1 |
| admvip | EXECUTADO | 0 |
| appcheckandroid | EXECUTADO | 0 |
| temavip | EXECUTADO | 0 |
| treinosan | EXECUTADO | 0 |
| lojaa11y | EXECUTADO | 0 |
| descstbl | EXECUTADO | 0 |
| descadapt | EXECUTADO | 0 |
| descestado | EXECUTADO | 0 |
| desclobby | EXECUTADO | 0 |
| deschome | EXECUTADO | 0 |
| ingrcontrato | **FALHOU** | 1 |
| ingrassento | EXECUTADO | 0 |
| ingrnav | EXECUTADO | 0 |
| ingrtransp | EXECUTADO | 0 |
| encui | EXECUTADO | 0 |
| encpend | EXECUTADO | 0 |
| encpendack | EXECUTADO | 0 |
| ordemvisao | EXECUTADO | 0 |
| obscaptura | EXECUTADO | 0 |
| obsgatilho | EXECUTADO | 0 |
| obsidentidade | EXECUTADO | 0 |
| obsredacao | EXECUTADO | 0 |
| obsredurl | EXECUTADO | 0 |
| mesaa11y | EXECUTADO | 0 |
| a11yestados | EXECUTADO | 0 |
| a11yconf | EXECUTADO | 0 |

Fora do portão: `evidencias_visuais` exit `0` (gerador de PNG).

## flutter analyze (tail)
```
   info • Can't use a relative path to import a library in 'lib'. Try fixing the relative path or changing the import to a 'package:' import • test/mesa_orientacao_runtime_test.dart:6:8 • avoid_relative_lib_imports
   info • Can't use a relative path to import a library in 'lib'. Try fixing the relative path or changing the import to a 'package:' import • test/mesa_orientacao_runtime_test.dart:7:8 • avoid_relative_lib_imports
   info • Can't use a relative path to import a library in 'lib'. Try fixing the relative path or changing the import to a 'package:' import • test/mesa_orientation_contract_test.dart:6:8 • avoid_relative_lib_imports
   info • Can't use a relative path to import a library in 'lib'. Try fixing the relative path or changing the import to a 'package:' import • test/mesa_orientation_contract_test.dart:7:8 • avoid_relative_lib_imports
   info • The import of 'dart:ui' is unnecessary because all of the used elements are also provided by the import of 'package:flutter/foundation.dart'. Try removing the import directive • test/observabilidade/captura_test.dart:9:8 • unnecessary_import
   info • Can't use a relative path to import a library in 'lib'. Try fixing the relative path or changing the import to a 'package:' import • test/preparando_partida_config_adapter_test.dart:3:8 • avoid_relative_lib_imports
   info • Can't use a relative path to import a library in 'lib'. Try fixing the relative path or changing the import to a 'package:' import • test/preparando_partida_config_adapter_test.dart:4:8 • avoid_relative_lib_imports
   info • Can't use a relative path to import a library in 'lib'. Try fixing the relative path or changing the import to a 'package:' import • test/preparando_partida_config_adapter_test.dart:5:8 • avoid_relative_lib_imports
   info • Can't use a relative path to import a library in 'lib'. Try fixing the relative path or changing the import to a 'package:' import • test/preparando_partida_ui_contract_test.dart:4:8 • avoid_relative_lib_imports
   info • Can't use a relative path to import a library in 'lib'. Try fixing the relative path or changing the import to a 'package:' import • test/ranking_apresentacao_test.dart:3:8 • avoid_relative_lib_imports
   info • Can't use a relative path to import a library in 'lib'. Try fixing the relative path or changing the import to a 'package:' import • test/ranking_apresentacao_test.dart:4:8 • avoid_relative_lib_imports
   info • Can't use a relative path to import a library in 'lib'. Try fixing the relative path or changing the import to a 'package:' import • test/ranking_apresentacao_test.dart:5:8 • avoid_relative_lib_imports
   info • Can't use a relative path to import a library in 'lib'. Try fixing the relative path or changing the import to a 'package:' import • test/ranking_fixtures.dart:3:8 • avoid_relative_lib_imports
   info • Can't use a relative path to import a library in 'lib'. Try fixing the relative path or changing the import to a 'package:' import • test/ranking_fixtures.dart:4:8 • avoid_relative_lib_imports
   info • Can't use a relative path to import a library in 'lib'. Try fixing the relative path or changing the import to a 'package:' import • test/ranking_fixtures.dart:5:8 • avoid_relative_lib_imports
   info • Can't use a relative path to import a library in 'lib'. Try fixing the relative path or changing the import to a 'package:' import • test/ranking_fixtures.dart:6:8 • avoid_relative_lib_imports
   info • Can't use a relative path to import a library in 'lib'. Try fixing the relative path or changing the import to a 'package:' import • test/ranking_page_test.dart:4:8 • avoid_relative_lib_imports
   info • Can't use a relative path to import a library in 'lib'. Try fixing the relative path or changing the import to a 'package:' import • test/ranking_page_test.dart:5:8 • avoid_relative_lib_imports
   info • Can't use a relative path to import a library in 'lib'. Try fixing the relative path or changing the import to a 'package:' import • test/ranking_page_test.dart:6:8 • avoid_relative_lib_imports
   info • Can't use a relative path to import a library in 'lib'. Try fixing the relative path or changing the import to a 'package:' import • test/ranking_page_test.dart:7:8 • avoid_relative_lib_imports
   info • Can't use a relative path to import a library in 'lib'. Try fixing the relative path or changing the import to a 'package:' import • test/ranking_paginacao_test.dart:3:8 • avoid_relative_lib_imports
   info • Can't use a relative path to import a library in 'lib'. Try fixing the relative path or changing the import to a 'package:' import • test/ranking_paginacao_test.dart:4:8 • avoid_relative_lib_imports
   info • Can't use a relative path to import a library in 'lib'. Try fixing the relative path or changing the import to a 'package:' import • test/ranking_regressao_visual_test.dart:4:8 • avoid_relative_lib_imports
   info • Can't use a relative path to import a library in 'lib'. Try fixing the relative path or changing the import to a 'package:' import • test/ranking_regressao_visual_test.dart:5:8 • avoid_relative_lib_imports
   info • Can't use a relative path to import a library in 'lib'. Try fixing the relative path or changing the import to a 'package:' import • test/ranking_regressao_visual_test.dart:6:8 • avoid_relative_lib_imports
   info • Can't use a relative path to import a library in 'lib'. Try fixing the relative path or changing the import to a 'package:' import • test/ranking_regressao_visual_test.dart:7:8 • avoid_relative_lib_imports
   info • Can't use a relative path to import a library in 'lib'. Try fixing the relative path or changing the import to a 'package:' import • test/ranking_regressao_visual_test.dart:8:8 • avoid_relative_lib_imports
   info • Can't use a relative path to import a library in 'lib'. Try fixing the relative path or changing the import to a 'package:' import • test/ranking_regressao_visual_test.dart:9:8 • avoid_relative_lib_imports
   info • Unnecessary use of multiple underscores. Try using '_' • test/sessao/telas_consomem_identidade_test.dart:108:30 • unnecessary_underscores
   info • The local variable '_assin' starts with an underscore. Try renaming the variable to not start with an underscore • test/teste_motor.dart:4264:12 • no_leading_underscores_for_local_identifiers
   info • The local variable '_snapshotProjecao' starts with an underscore. Try renaming the variable to not start with an underscore • test/teste_motor.dart:4270:12 • no_leading_underscores_for_local_identifiers
   info • The local variable '_snap' starts with an underscore. Try renaming the variable to not start with an underscore • test/teste_motor.dart:4500:12 • no_leading_underscores_for_local_identifiers
   info • The local variable '_idsDosCandidatos' starts with an underscore. Try renaming the variable to not start with an underscore • test/teste_motor.dart:4512:17 • no_leading_underscores_for_local_identifiers
   info • Can't use a relative path to import a library in 'lib'. Try fixing the relative path or changing the import to a 'package:' import • test/vitoria_celebracao_contract_test.dart:3:8 • avoid_relative_lib_imports
   info • Can't use a relative path to import a library in 'lib'. Try fixing the relative path or changing the import to a 'package:' import • test/vitoria_celebracao_contract_test.dart:4:8 • avoid_relative_lib_imports
   info • Can't use a relative path to import a library in 'lib'. Try fixing the relative path or changing the import to a 'package:' import • test/vitoria_celebracao_runtime_test.dart:4:8 • avoid_relative_lib_imports
   info • Can't use a relative path to import a library in 'lib'. Try fixing the relative path or changing the import to a 'package:' import • test/vitoria_celebracao_runtime_test.dart:5:8 • avoid_relative_lib_imports
   info • Can't use a relative path to import a library in 'lib'. Try fixing the relative path or changing the import to a 'package:' import • test/vitoria_celebracao_runtime_test.dart:6:8 • avoid_relative_lib_imports

208 issues found. (ran in 11.6s)
```
## motor (tail)
```
00:07 +434: OS LIXO CANÔNICO V1 — §5.2 canonizada LIX-C05 um SNAPSHOT do estado canônico é AUTOSSUFICIENTE para reproduzir a posição
00:07 +435: OS LIXO CANÔNICO V1 — regra do ABERTO LIX-01 compra do MONTE não cria trava nenhuma
00:07 +436: OS LIXO CANÔNICO V1 — regra do ABERTO LIX-02 compra do LIXO com UMA carta cria a trava naquela carta
00:07 +437: OS LIXO CANÔNICO V1 — regra do ABERTO LIX-03 compra do LIXO com DUAS OU MAIS cartas NÃO cria trava
00:07 +438: OS LIXO CANÔNICO V1 — regra do ABERTO LIX-04 no FECHADO/STBL a compra é atômica e não gera trava
00:07 +439: OS LIXO CANÔNICO V1 — regra do ABERTO LIX-05 a trava recusa SÓ o descarte daquela carta
00:07 +440: OS LIXO CANÔNICO V1 — regra do ABERTO LIX-06 a carta travada pode ser BAIXADA e ESTENDIDA — só não descartada
00:07 +441: OS LIXO CANÔNICO V1 — regra do ABERTO LIX-07 a recusa é fechada: nada muda e o reasonCode é estável
00:07 +442: OS LIXO CANÔNICO V1 — regra do ABERTO LIX-08 a informação do lixo MUDA a continuação possível do turno
00:07 +443: OS LIXO CANÔNICO V1 — regra do ABERTO LIX-09 o MESMO estado sem a trava aceita a mesma baixada — a única diferença é o campo canônico
00:07 +444: OS LIXO CANÔNICO V1 — regra do ABERTO LIX-10 o invariante de encerramento continua válido DEPOIS da canonização: nenhuma ação aceita cria beco
00:07 +445: OS LIXO CANÔNICO V1 — regra do ABERTO LIX-11 a trava MORRE quando a vez passa (descarte normal)
00:07 +446: OS LIXO CANÔNICO V1 — regra do ABERTO LIX-12 a trava SOBREVIVE às ações intermediárias do próprio turno
00:07 +447: OS LIXO CANÔNICO V1 — regra do ABERTO LIX-13 morto DIRETO mantém a trava (mesma vez); morto INDIRETO a apaga (a vez passa)
00:07 +448: OS LIXO CANÔNICO V1 — regra do ABERTO LIX-14 a BATIDA encerra a rodada e apaga a trava
00:07 +449: OS LIXO CANÔNICO V1 — regra do ABERTO LIX-15 a compra do turno SEGUINTE zera qualquer resíduo
00:07 +450: OS LIXO CANÔNICO V1 — regra do ABERTO LIX-16 clone, normalização e copyWith preservam a trava
00:07 +451: OS LIXO CANÔNICO V1 — regra do ABERTO LIX-17 estados canônicos IGUAIS decidem IGUAL; estados que só diferem na trava não são iguais
00:07 +452: OS LIXO CANÔNICO V1 — regra do ABERTO LIX-18 round-trip Jogo -> canônico -> Jogo preserva a trava
00:07 +453: OS LIXO CANÔNICO V1 — regra do ABERTO LIX-19 o snapshot de Replay carrega a trava e o motor a recupera
00:07 +454: OS LIXO CANÔNICO V1 — regra do ABERTO LIX-20 o BOT respeita a §5.2 sem nenhuma regra especial
00:07 +455: OS LIXO CANÔNICO V1 — regra do ABERTO LIX-21 clone/simulação do bot conserva a trava
00:07 +456: OS LIXO CANÔNICO V1 — regra do ABERTO LIX-22 gerador e aplicador NÃO divergem para o humano nem para o bot
00:07 +457: OS LIXO CANÔNICO V1 — regra do ABERTO LIX-23 varredura de BARALHOS REAIS: a trava nunca vaza e nunca cria beco
00:07 +458: All tests passed!
```
## resil (tail)
```
00:00 +172: MODAL — Aberto, Fechado e STBL MODAL-04 STBL usa a trava do Fechado para o lixo
00:00 +173: MODAL — Aberto, Fechado e STBL MODAL-05-ABERTO snapshot preserva a modalidade e as regras
00:00 +174: MODAL — Aberto, Fechado e STBL MODAL-05-FECHADO snapshot preserva a modalidade e as regras
00:00 +175: MODAL — Aberto, Fechado e STBL MODAL-05-SBTL snapshot preserva a modalidade e as regras
00:00 +176: E2E — partida completa pelo MotorPartida E2E-ABERTO robôs jogam 200 turnos com estado sempre íntegro
00:00 +177: E2E — partida completa pelo MotorPartida E2E-FECHADO robôs jogam 200 turnos com estado sempre íntegro
00:00 +178: E2E — partida completa pelo MotorPartida E2E-SBTL robôs jogam 200 turnos com estado sempre íntegro
00:00 +179: E2E — partida completa pelo MotorPartida E2E-SNAP retomada no meio de uma partida de robôs mantém tudo
00:00 +180: E2E — partida completa pelo MotorPartida E2E-VISAO durante uma partida de robôs nada vaza para o assento 0
00:00 +181: CANASTRAS — acumulador de canastras limpas CAN-01 rodada não apurada: nada a somar, acumulador em zero
00:00 +182: CANASTRAS — acumulador de canastras limpas CAN-02 uma canastra limpa de "nos" soma só para "nos"
00:00 +183: CANASTRAS — acumulador de canastras limpas CAN-03 acumula ao longo de mais de uma rodada
00:00 +184: CANASTRAS — acumulador de canastras limpas CAN-04 rodada com zero canastras não mexe no acumulador
00:00 +185: CANASTRAS — acumulador de canastras limpas CAN-05 apuração repetida NÃO duplica a contagem (retry)
00:00 +186: CANASTRAS — acumulador de canastras limpas CAN-06 snapshot e restauração preservam o acumulado
00:00 +187: CANASTRAS — acumulador de canastras limpas CAN-07 snapshot ANTIGO, sem a chave, restaura compatível (zero)
00:00 +188: CANASTRAS — acumulador de canastras limpas CAN-08 valor inválido no envelope é ignorado, não vira lixo
00:00 +189: CANASTRAS — acumulador de canastras limpas CAN-09 o acumulador NÃO recalcula regra: espelha o que o Jogo apurou
00:00 +190: IMPRESSAO-PARTIDA — identidade competitiva da partida IMPP-01 é determinística: duas leituras seguidas batem
00:00 +191: IMPRESSAO-PARTIDA — identidade competitiva da partida IMPP-02 mesmo jogo e mesmas canastras: mesma impressão
00:00 +192: IMPRESSAO-PARTIDA — identidade competitiva da partida IMPP-03 mesmo Jogo, canastras DIFERENTES: impressão diferente
00:00 +193: IMPRESSAO-PARTIDA — identidade competitiva da partida IMPP-04 ordem das chaves do envelope não altera a impressão
00:00 +194: IMPRESSAO-PARTIDA — identidade competitiva da partida IMPP-05 comando RECUSADO não altera impressao nem impressaoPartida
00:00 +195: IMPRESSAO-PARTIDA — identidade competitiva da partida IMPP-06 snapshot e restauração preservam a impressão da partida
00:00 +196: All tests passed!
```
## encerr (tail)
```
  synchronized 3.4.0+1 (3.4.2 available)
  test_api 0.7.11 (0.7.14 available)
  url_launcher_android 6.3.30 (6.3.33 available)
  url_launcher_ios 6.4.1 (6.4.2 available)
  url_launcher_linux 3.2.2 (3.2.3 available)
  url_launcher_macos 3.2.5 (3.2.6 available)
  url_launcher_windows 3.1.5 (3.1.6 available)
  vector_math 2.2.0 (2.4.3 available)
  vm_service 15.2.0 (15.3.0 available)
  yaml 3.1.3 (3.1.4 available)
Got dependencies!
65 packages have newer versions incompatible with dependency constraints.
Try `flutter pub outdated` for more information.
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
  
00:00 +158 -5: extra: hidratacao e invariantes participanteId de dupla mal formado e recusado
00:00 +159 -5: extra: hidratacao e invariantes membro com o separador e recusado
00:00 +160 -5: contratos para Flutter a correspondencia de status dominio <-> UI e 1:1
00:00 +161 -5: contratos para Flutter a correspondencia de participante dominio <-> UI cobre a UI inteira
00:00 +162 -5: contratos para Flutter a correspondencia de recusa de inscricao cobre a UI inteira
00:00 +163 -5: contratos para Flutter modalidade e participacao mapeiam para a UI
00:00 +164 -5: contratos para Flutter a secao da central deriva do estado
00:00 +165 -5: contratos para Flutter os botoes vem do dominio, nao do widget
00:00 +166 -5: contratos para Flutter o card monta a partir do dominio
00:00 +167 -5: contratos para Flutter a linha de classificacao mapeia para a UI
00:00 +168 -5: contratos para Flutter o confronto mapeia para a UI
00:00 +169 -5: contrato com o Motor de Partidas a solicitacao carrega tudo que a mesa precisa e nada alem
00:00 +170 -5: contrato com o Motor de Partidas o matchId e derivado da mesa: reenviar nao abre duas mesas
00:00 +171 -5: contrato com o Motor de Partidas mesa com participante repetido e recusada
00:00 +172 -5: contrato com o Motor de Partidas mesa com menos de dois lados e recusada
00:00 +173 -5: contrato com o Motor de Partidas as interfaces do contrato existem e sao implementaveis
00:00 +174 -5: Some tests failed.

Failing tests:
  /home/runner/work/buraco-master-vip-app/buraco-master-vip-app/app_build/test/torneios/motor_torneios_test.dart: extra: hidratacao e invariantes a modalidade da edicao vem da politica, sem inventar valor
  /home/runner/work/buraco-master-vip-app/buraco-master-vip-app/app_build/test/torneios/motor_torneios_test.dart: seed aprovado a entrada em duas etapas cobra a partir da edicao certa
  /home/runner/work/buraco-master-vip-app/buraco-master-vip-app/app_build/test/torneios/motor_torneios_test.dart: seed aprovado a modalidade em politica resolve por edicao, sem inventar valor
  /home/runner/work/buraco-master-vip-app/buraco-master-vip-app/app_build/test/torneios/motor_torneios_test.dart: seed aprovado a trilha de classificado do mensal e gratuita e a paga esta desligada
  /home/runner/work/buraco-master-vip-app/buraco-master-vip-app/app_build/test/torneios/motor_torneios_test.dart: seed aprovado o acesso do seed vira criterio de elegibilidade, sem campo duplicado
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
  url_launcher_linux 3.2.2 (3.2.3 available)
  url_launcher_macos 3.2.5 (3.2.6 available)
  url_launcher_windows 3.1.5 (3.1.6 available)
  vector_math 2.2.0 (2.4.3 available)
  vm_service 15.2.0 (15.3.0 available)
  yaml 3.1.3 (3.1.4 available)
Got dependencies!
65 packages have newer versions incompatible with dependency constraints.
Try `flutter pub outdated` for more information.
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
  yaml 3.1.3 (3.1.4 available)
Got dependencies!
65 packages have newer versions incompatible with dependency constraints.
Try `flutter pub outdated` for more information.
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
00:02 +20: o Perfil alcançável só afirma o que tem fonte o convite copiado do Perfil alcançável não inventa nada
00:02 +21: o Perfil alcançável só afirma o que tem fonte o VM do Perfil alcançável não é a maquete
00:02 +22: estados honestos da tela pública build sem provedor operacional é terminal e sem botão
00:02 +23: estados honestos da tela pública erro de login aparece redigido
00:02 +24: transporte inicialização autenticada abre UM socket, sem ir ao Lobby
00:02 +25: transporte sem sessão NÃO há socket — conectar exige quem autenticar
00:02 +26: transporte abrir o lobby NÃO abre um segundo socket
00:03 +27: transporte logout fecha o socket e cancela a reconexão
00:03 +28: transporte a credencial não aparece em lugar nenhum da interface
00:03 +29: sem conexão, o ciclo automático desiste e diz isso
00:03 +30: endereço de servidor inválido é falha terminal, não tentativa
00:03 +31: All tests passed!
```
## cascaaud (tail)
```
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
00:00 +17: o portão da identidade visitada a suíte existe na árvore
00:00 +18: o portão da identidade visitada o workflow a executa e a considera no portão
00:00 +19: o portão da atestação Android a suíte existe na árvore
00:00 +20: o portão dos estados anunciados a suíte existe na árvore
00:00 +21: o portão dos estados anunciados a suíte ainda cobre os cenários obrigatórios
00:00 +22: o portão dos estados anunciados a suíte não foi esvaziada
00:00 +23: o portão dos estados anunciados o passo do build.yml copia e executa o DIRETÓRIO inteiro
00:00 +24: o portão cascaaud cascaaud executa ESTA auditoria
00:00 +25: o portão cascaaud cascaaud está na fonte única que o portão percorre
00:00 +26: o portão cascaaud cascaaud não está duplicado nem registrado morto
00:00 +27: as explicações refutadas pela OS 37 não voltam lib/casca/mesa_online/mesa_online_screen.dart não afirma de novo o que foi medido falso
00:00 +28: as explicações refutadas pela OS 37 não voltam lib/casca/login_de_producao.dart não afirma de novo o que foi medido falso
00:00 +29: as explicações refutadas pela OS 37 não voltam lib/casca/lobby_online.dart não afirma de novo o que foi medido falso
00:00 +30: (tearDownAll)
00:00 +30: All tests passed!
```
## cascavisao (tail)
```
00:00 +8: visão inválida é recusada, não completada sem assento declarado
00:00 +9: visão inválida é recusada, não completada assento da visão diferente do assento da conexão
00:00 +10: visão inválida é recusada, não completada mão ilegível
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
00:00 +30: a ordem não mora nesta camada um versaoEstado plantado dentro da visão é ignorado
00:00 +31: a ordem não mora nesta camada a leitura é uma função pura da visão, sem memória entre chamadas
00:00 +32: All tests passed!
```
## cascamesaaud (tail)
```
  shared_preferences_foundation 2.5.6 (2.5.7 available)
  stack_trace 1.12.1 (1.12.2 available)
  synchronized 3.4.0+1 (3.4.2 available)
  test_api 0.7.11 (0.7.14 available)
  url_launcher_android 6.3.30 (6.3.33 available)
  url_launcher_ios 6.4.1 (6.4.2 available)
  url_launcher_linux 3.2.2 (3.2.3 available)
  url_launcher_macos 3.2.5 (3.2.6 available)
  url_launcher_windows 3.1.5 (3.1.6 available)
  vector_math 2.2.0 (2.4.3 available)
  vm_service 15.2.0 (15.3.0 available)
  yaml 3.1.3 (3.1.4 available)
Got dependencies!
65 packages have newer versions incompatible with dependency constraints.
Try `flutter pub outdated` for more information.
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
To make this warning fatal, set WidgetController.hitTestWarningShouldBeFatal to true.


Warning: A call to tap() with finder "Found 1 widget with text "Recompensas" (ignoring all but first): [
  Text("Recompensas", inherit: true, color: Color(alpha: 0.7000, red: 1.0000, green: 1.0000, blue: 1.0000, colorSpace: ColorSpace.sRGB), size: 10.4, height: 1.1x, textAlign: center, overflow: ellipsis, maxLines: 2, dependencies: [DefaultSelectionStyle, DefaultTextStyle, MediaQuery, _ScrollableScope]),
]" derived an Offset (Offset(222.1, 437.4)) that would not hit test on the specified widget.
Maybe the widget is actually off-screen, or another widget is obscuring it, or the widget cannot receive pointer events.
The finder corresponds to this RenderBox: RenderParagraph#2329f relayoutBoundary=up5
The hit test result at that offset is: HitTestResult(HitTestEntry<HitTestTarget>#3782f(TextSpan(debugLabel: ((englishLike bodyMedium 2021).merge((whiteMountainView bodyMedium).apply)).merge(unknown), inherit: false, color: Color(alpha: 0.3400, red: 1.0000, green: 1.0000, blue: 1.0000, colorSpace: ColorSpace.sRGB), family: Roboto, size: 8.4, weight: 700, letterSpacing: 0.3, baseline: alphabetic, height: 1.4x, leadingDistribution: even, decoration: Color(alpha: 1.0000, red: 0.9020, green: 0.8784, blue: 0.9137, colorSpace: ColorSpace.sRGB) TextDecoration.none, "em breve")), RenderParagraph#75f11@Offset(36.6, 2.6), RenderStack#c93df@Offset(36.6, 57.4), RenderPadding#69b87@Offset(37.6, 58.4), RenderPointerListener#870c9@Offset(37.6, 58.4), RenderSemanticsAnnotations#f3fde@Offset(37.6, 58.4), RenderMouseRegion#8926c@Offset(37.6, 58.4), RenderSemanticsAnnotations#20f4a@Offset(37.6, 58.4), _RenderInkFeatures#ab946@Offset(37.6, 58.4), RenderPhysicalModel#08366@Offset(37.6, 58.4), RenderRepaintBoundary#5be58@Offset(37.6, 58.4), RenderIndexedSemantics#2f55f@Offset(37.6, 58.4), RenderSliverGrid@(mainAxis: 58.38725490196077, crossAxis: 206.125), RenderSliverPadding@(mainAxis: 58.38725490196077, crossAxis: 206.125), RenderShrinkWrappingViewport#b08be@Offset(206.1, 58.4), RenderIgnorePointer#79420@Offset(206.1, 58.4), RenderSemanticsAnnotations#8bfe6@Offset(206.1, 58.4), RenderPointerListener#15e63@Offset(206.1, 58.4), RenderSemanticsGestureHandler#1141b@Offset(206.1, 58.4), RenderPointerListener#4cf02@Offset(206.1, 58.4), _RenderScrollSemantics#72fa7@Offset(206.1, 58.4), RenderClipRect#8e2ee@Offset(206.1, 58.4), RenderRepaintBoundary#3bee0@Offset(206.1, 58.4), RenderIndexedSemantics#5b066@Offset(206.1, 58.4), RenderSliverList@(mainAxis: 429.3872549019608, crossAxis: 206.125), RenderSliverPadding@(mainAxis: 437.3872549019608, crossAxis: 222.125), RenderViewport#4d31c@Offset(222.1, 437.4), RenderIgnorePointer#02c0c@Offset(222.1, 437.4), RenderSemanticsAnnotations#dff67@Offset(222.1, 437.4), RenderPointerListener#f1c26@Offset(222.1, 437.4), RenderSemanticsGestureHandler#fd5fb@Offset(222.1, 437.4), RenderPointerListener#2676d@Offset(222.1, 437.4), _RenderScrollSemantics#d6ed2@Offset(222.1, 437.4), RenderClipRect#c4508@Offset(222.1, 437.4), _RenderLayoutBuilder#5446b@Offset(222.1, 437.4), RenderStack#01937@Offset(222.1, 437.4), RenderFlex#9b69f@Offset(222.1, 437.4), RenderConstrainedBox#a922c@Offset(222.1, 437.4), RenderPositionedBox#c642c@Offset(222.1, 437.4), RenderPadding#74383@Offset(222.1, 437.4), RenderDecoratedBox#1534d@Offset(222.1, 437.4), RenderCustomMultiChildLayoutBox#67108@Offset(222.1, 437.4), _RenderInkFeatures#8d701@Offset(222.1, 437.4), RenderPhysicalModel#6bc44@Offset(222.1, 437.4), RenderSemanticsAnnotations#a3ff8@Offset(222.1, 437.4), RenderRepaintBoundary#bd8ae@Offset(222.1, 437.4), RenderIgnorePointer#8e8a1@Offset(222.1, 437.4), RenderAnimatedOpacity#ee522@Offset(222.1, 437.4), RenderAnimatedOpacity#21fb7@Offset(222.1, 437.4), _RenderColoredBox#844c8@Offset(222.1, 437.4), RenderAnimatedOpacity#0ec71@Offset(222.1, 437.4), RenderIgnorePointer#68ccf@Offset(222.1, 437.4), RenderAnimatedOpacity#ec49d@Offset(222.1, 437.4), RenderRepaintBoundary#c6d2b@Offset(222.1, 437.4), RenderSemanticsAnnotations#6e00a@Offset(222.1, 437.4), RenderOffstage#f6e4e@Offset(222.1, 437.4), RenderSemanticsAnnotations#1d908@Offset(222.1, 437.4), _RenderTheater#c725b@Offset(222.1, 437.4), RenderAbsorbPointer#8111b@Offset(222.1, 437.4), RenderPointerListener#3a2fa@Offset(222.1, 437.4), RenderSemanticsAnnotations#d3585@Offset(222.1, 437.4), RenderSemanticsAnnotations#49797@Offset(222.1, 437.4), RenderSemanticsAnnotations#ac674@Offset(222.1, 437.4), RenderSemanticsAnnotations#5f869@Offset(222.1, 437.4), RenderTapRegionSurface#dd73d@Offset(222.1, 437.4), RenderSemanticsAnnotations#7d675@Offset(222.1, 437.4), RenderSemanticsAnnotations#bb459@Offset(222.1, 437.4), HitTestEntry<HitTestTarget>#687ef(_ReusableRenderView#8925a), HitTestEntry<HitTestTarget>#f5dc6(<AutomatedTestWidgetsFlutterBinding>))
#0      WidgetController._getElementPoint (package:flutter_test/src/controller.dart:2165:25)
#1      WidgetController.getCenter (package:flutter_test/src/controller.dart:1947:12)
#2      WidgetController.tap (package:flutter_test/src/controller.dart:1080:7)
#3      main.<anonymous closure> (file:///home/runner/work/buraco-master-vip-app/buraco-master-vip-app/app_build/test/casca/homologacao_casca_v2_test.dart:665:20)
<asynchronous suspension>
#4      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#5      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1952:5)
<asynchronous suspension>
#6      StackZoneSpecification._registerCallback.<anonymous closure> (package:stack_trace/src/stack_zone_specification.dart:114:42)
<asynchronous suspension>
To silence this warning, pass "warnIfMissed: false" to "tap()".
To make this warning fatal, set WidgetController.hitTestWarningShouldBeFatal to true.

00:02 +12: Amigos navega, e o que abre consulta a autoridade
00:02 +13: All tests passed!
```
## cascaligacao (tail)
```
  record_use 0.6.0 (1.1.1 available)
  shared_preferences_android 2.4.23 (2.4.28 available)
  shared_preferences_foundation 2.5.6 (2.5.7 available)
  stack_trace 1.12.1 (1.12.2 available)
  synchronized 3.4.0+1 (3.4.2 available)
  test_api 0.7.11 (0.7.14 available)
  url_launcher_android 6.3.30 (6.3.33 available)
  url_launcher_ios 6.4.1 (6.4.2 available)
  url_launcher_linux 3.2.2 (3.2.3 available)
  url_launcher_macos 3.2.5 (3.2.6 available)
  url_launcher_windows 3.1.5 (3.1.6 available)
  vector_math 2.2.0 (2.4.3 available)
  vm_service 15.2.0 (15.3.0 available)
  yaml 3.1.3 (3.1.4 available)
Got dependencies!
65 packages have newer versions incompatible with dependency constraints.
Try `flutter pub outdated` for more information.
00:00 +0: loading /home/runner/work/buraco-master-vip-app/buraco-master-vip-app/app_build/test/casca/ligacao_mesa_caracterizacao_test.dart
00:00 +0: treino Home autenticada abre Onde Jogar
00:00 +1: treino Treino abre a MesaScreen jogável de lib/mesa.dart
00:01 +2: treino Treino não fala com o servidor
00:01 +3: transporte Mesa por código usa o OnlineService da raiz
00:01 +4: transporte abrir e fechar o lobby não constrói um segundo transporte
00:01 +5: transporte logout no lobby derruba a pilha e a capacidade de jogar
00:02 +6: All tests passed!
```
## cascamesa (tail)
```
00:10 +43: desfecho encerrada a partida, nenhuma ação é oferecida

Warning: A call to tap() with finder "Found 1 widget with text "Monte · 60": [
  Text("Monte · 60", inherit: true, color: Color(alpha: 1.0000, red: 0.6039, green: 0.5490, blue: 0.4235, colorSpace: ColorSpace.sRGB), size: 10.5, overflow: ellipsis, maxLines: 1, dependencies: [DefaultSelectionStyle, DefaultTextStyle, MediaQuery]),
]" derived an Offset (Offset(78.8, 381.2)) that would not hit test on the specified widget.
Maybe the widget is actually off-screen, or another widget is obscuring it, or the widget cannot receive pointer events.
The finder corresponds to this RenderBox: RenderParagraph#7e213 relayoutBoundary=up21
The hit test result at that offset is: HitTestResult(HitTestEntry<HitTestTarget>#f2863(TextSpan(debugLabel: ((englishLike bodyMedium 2021).merge((whiteMountainView bodyMedium).apply)).merge(unknown), inherit: false, color: Color(alpha: 1.0000, red: 0.9373, green: 0.8902, blue: 0.8000, colorSpace: ColorSpace.sRGB), family: Roboto, size: 13.0, weight: 400, letterSpacing: 0.3, baseline: alphabetic, height: 1.4x, leadingDistribution: even, decoration: Color(alpha: 1.0000, red: 0.9020, green: 0.8784, blue: 0.9137, colorSpace: ColorSpace.sRGB) TextDecoration.none, "O servidor encerrou esta partida. O resultado está na mesa, atrás deste aviso.")), RenderParagraph#3a73f@Offset(14.8, 65.2), RenderSemanticsAnnotations#ae0c0@Offset(14.8, 65.2), RenderPadding#211c9@Offset(38.8, 81.2), RenderFlex#2e5ad@Offset(38.8, 169.2), RenderIntrinsicWidth#92493@Offset(38.8, 169.2), RenderSemanticsAnnotations#9f917@Offset(38.8, 169.2), _RenderInkFeatures#b3440@Offset(38.8, 169.2), RenderCustomPaint#39e46@Offset(38.8, 169.2), RenderPhysicalShape#143a8@Offset(38.8, 169.2), RenderConstrainedBox#caaab@Offset(38.8, 169.2), RenderPositionedBox#5a518@Offset(38.8, 357.2), RenderPadding#a58b7@Offset(78.8, 381.2), RenderSemanticsAnnotations#5531d@Offset(78.8, 381.2), RenderPadding#3953e@Offset(78.8, 381.2), RenderSemanticsAnnotations#d3fdd@Offset(78.8, 381.2), RenderPadding#cef0a@Offset(78.8, 381.2), RenderSemanticsAnnotations#79c73@Offset(78.8, 381.2), RenderRepaintBoundary#1e14c@Offset(78.8, 381.2), RenderIgnorePointer#ed59e@Offset(78.8, 381.2), RenderAnimatedOpacity#77b29@Offset(78.8, 381.2), RenderRepaintBoundary#aefed@Offset(78.8, 381.2), RenderSemanticsAnnotations#b61fe@Offset(78.8, 381.2), RenderOffstage#4b6e3@Offset(78.8, 381.2), RenderSemanticsAnnotations#e4b8c@Offset(78.8, 381.2), _RenderTheater#c7c61@Offset(78.8, 381.2), RenderAbsorbPointer#f280c@Offset(78.8, 381.2), RenderPointerListener#cfe48@Offset(78.8, 381.2), RenderSemanticsAnnotations#a384e@Offset(78.8, 381.2), RenderSemanticsAnnotations#35fde@Offset(78.8, 381.2), RenderSemanticsAnnotations#04b9f@Offset(78.8, 381.2), RenderSemanticsAnnotations#b7212@Offset(78.8, 381.2), RenderTapRegionSurface#9ce15@Offset(78.8, 381.2), RenderSemanticsAnnotations#dd0a3@Offset(78.8, 381.2), RenderSemanticsAnnotations#c40f6@Offset(78.8, 381.2), HitTestEntry<HitTestTarget>#b8123(_ReusableRenderView#a7685), HitTestEntry<HitTestTarget>#fe039(<AutomatedTestWidgetsFlutterBinding>))
#0      WidgetController._getElementPoint (package:flutter_test/src/controller.dart:2165:25)
#1      WidgetController.getCenter (package:flutter_test/src/controller.dart:1947:12)
#2      WidgetController.tap (package:flutter_test/src/controller.dart:1080:7)
#3      main.<anonymous closure>.<anonymous closure> (file:///home/runner/work/buraco-master-vip-app/buraco-master-vip-app/app_build/test/casca/mesa_online_test.dart:1336:20)
<asynchronous suspension>
#4      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#5      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1952:5)
<asynchronous suspension>
#6      StackZoneSpecification._registerCallback.<anonymous closure> (package:stack_trace/src/stack_zone_specification.dart:114:42)
<asynchronous suspension>
To silence this warning, pass "warnIfMissed: false" to "tap()".
To make this warning fatal, set WidgetController.hitTestWarningShouldBeFatal to true.

00:10 +44: nada de segredo na tela a credencial não aparece em texto nenhum da mesa
00:10 +45: nada de segredo na tela nenhuma conquista é concedida por inferência do cliente
00:10 +46: All tests passed!
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
## cascaloja (tail)
```
  url_launcher_windows 3.1.5 (3.1.6 available)
  vector_math 2.2.0 (2.4.3 available)
  vm_service 15.2.0 (15.3.0 available)
  yaml 3.1.3 (3.1.4 available)
Got dependencies!
65 packages have newer versions incompatible with dependency constraints.
Try `flutter pub outdated` for more information.
00:00 +0: loading /home/runner/work/buraco-master-vip-app/buraco-master-vip-app/app_build/test/casca/loja_de_producao_test.dart
00:00 +0: a Loja é alcançável a partir da casca a grade da Home leva à Loja de produção
00:00 +1: a Loja é alcançável a partir da casca o item da Loja não está mais apagado na grade
00:00 +2: a Loja é alcançável a partir da casca os Ajustes também abrem a Loja
00:01 +3: a Loja é alcançável a partir da casca o ‹ da Loja volta para a Home, que continua viva
00:01 +4: a Loja respeita a sessão o Billing é montado com o uid da sessão canônica
00:01 +5: a Loja respeita a sessão sair da conta com a Loja aberta descarta a Loja
00:01 +6: a Loja respeita a sessão sem sessão a Loja nem é alcançável
00:01 +7: a Loja de produção não desenha dado sem fonte o VM não traz carteira, pacote, cosmético nem amigo
00:01 +8: a Loja de produção não desenha dado sem fonte as seções de maquete não chegam à tela
00:01 +9: a Loja de produção não desenha dado sem fonte sem planos, a vitrine explica em vez de ficar vazia
00:01 +10: o VIP vem do backend, e só dele a Loja abre sem VIP quando não há documento
00:01 +11: o VIP vem do backend, e só dele o entitlement do backend acende o selo
00:01 +12: o VIP vem do backend, e só dele tocar em assinar NÃO acende o VIP
00:02 +13: o VIP vem do backend, e só dele a Loja fechada não deixa escuta aberta
00:02 +14: fora do escopo, a montagem é a de PRODUÇÃO
00:02 +15: a Loja está no fecho de imports da raiz de produção
00:02 +16: All tests passed!
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
00:01 +24: PerfilService — o produtor o perfil publicável não recebe progressão, placar nem troféu
00:01 +25: PerfilService — o produtor o VM de carregamento diz carregando, e não indisponível
00:01 +26: compartilhamento sem ranking, o convite não cita liga nem colocação
00:01 +27: compartilhamento com ranking real, liga e colocação são preservadas
00:01 +28: compartilhamento liga real sem colocação compartilha só a liga
00:01 +29: compartilhamento colocação zero não vira #0 no texto público
00:01 +30: compartilhamento sem nível, o convite também não cita nível
00:01 +31: compartilhamento sem VM carregado, o convite não afirma nem nome
00:01 +32: Home e Perfil leem a mesma interpretação a casca publicável não tem autoridade de ranking, e diz isso uma vez só
00:01 +33: Home e Perfil leem a mesma interpretação o que a Home põe no cabeçalho é o que o Perfil recebe
00:02 +34: Home e Perfil leem a mesma interpretação a Home não desenha liga, e o Perfil não desenha Bronze
00:02 +35: sessão — nada sobrevive à troca logout não deixa estado competitivo anterior
00:02 +36: sessão — nada sobrevive à troca troca de conta sem logout não reaproveita nada da geração anterior
00:02 +37: sessão — nada sobrevive à troca o compartilhamento após a troca também não afirma nada
00:02 +38: auditoria — o literal não pode voltar (setUpAll)
00:02 +38: auditoria — o literal não pode voltar nenhum arquivo alcançável escreve Bronze como liga
00:02 +39: auditoria — o literal não pode voltar o texto de compartilhamento não tem fallback de liga
00:02 +40: auditoria — o literal não pode voltar nenhum arquivo alcançável interpola posição sem checar se ela existe
00:02 +41: auditoria — o literal não pode voltar a demonstração do Perfil não é alcançável pela raiz publicável
00:02 +42: auditoria — o literal não pode voltar a interpretação de "sem ranking" mora num lugar só
00:02 +43: auditoria — o literal não pode voltar (tearDownAll)
00:02 +43: All tests passed!
```
## rkperfil (tail)
```
  url_launcher_windows 3.1.5 (3.1.6 available)
  vector_math 2.2.0 (2.4.3 available)
  vm_service 15.2.0 (15.3.0 available)
  yaml 3.1.3 (3.1.4 available)
Got dependencies!
65 packages have newer versions incompatible with dependency constraints.
Try `flutter pub outdated` for more information.
00:00 +0: loading /home/runner/work/buraco-master-vip-app/buraco-master-vip-app/app_build/test/ranking/homologacao_perfil_publicavel_test.dart
00:00 +0: PROBE — higienização do estado canônico posicaoMundial 0, negativa e liga em branco viram ausência
00:00 +1: PROBE — higienização do estado canônico fora de disponivel, nem liga nem colocação atravessam
00:00 +2: PROBE — higienização do estado canônico ranking REAL atravessa sem substituição
00:00 +3: PROBE — a tela não desenha o que não tem fonte sem classificação: identidade e vitrine ficam, "💎 Liga —"
00:00 +4: PROBE — a tela não desenha o que não tem fonte nível/XP/título/placar/presentes/conquistas somem
00:00 +5: PROBE — a tela não desenha o que não tem fonte conquistas null = não consultado; [] = consultado e vazio
00:00 +6: PROBE — a tela não desenha o que não tem fonte XP exige os TRÊS campos: nenhum subconjunto desenha barra
00:00 +7: PROBE — a tela não desenha o que não tem fonte título sem emoji não vira "null Campeã"
00:00 +8: PROBE — carregando e erro carregando: esqueleto, sem nome nem número inventado
00:00 +9: PROBE — carregando e erro erro: pede recarga e NÃO reaproveita o VM anterior
00:00 +10: PROBE — o convite que sai do aparelho sem nada competitivo, fecha em "Sou {nome} 👑" sem órfão
00:00 +11: PROBE — o convite que sai do aparelho com dado real, o convite volta a afirmar — e pontua certo
00:00 +12: PROBE — o convite que sai do aparelho colocação 0 vinda da fonte não vira "#0" no convite
00:00 +13: PROBE — o convite que sai do aparelho sem VM não afirma nem nome
00:00 +14: PROBE — a mesma fonte canônica em toda superfície Home, Perfil e convite leem a MESMA instância
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
00:00 +32: a linha competitiva é anunciada, e não soletrada CASO 21d — atualização em andamento
00:00 +33: a linha competitiva é anunciada, e não soletrada CASO 21e — falha com ação de tentar novamente
00:00 +34: a linha competitiva é anunciada, e não soletrada sessão inválida não promete retry
00:00 +35: a linha competitiva é anunciada, e não soletrada sem colocação nenhuma: "ainda não classificado"
00:00 +36: a linha competitiva é anunciada, e não soletrada CASO 18 — nenhum fallback aparece na tela sem autoridade
00:00 +37: auditoria — o literal competitivo não pode nascer no cliente (setUpAll)
00:00 +37: auditoria — o literal competitivo não pode nascer no cliente nenhum nome de liga é escrito no módulo de ranking
00:01 +38: auditoria — o literal competitivo não pode nascer no cliente nenhum arquivo do ranking imprime identificador
00:01 +39: auditoria — o literal competitivo não pode nascer no cliente só o adaptador de Firebase conhece cloud_functions
00:01 +40: auditoria — o literal competitivo não pode nascer no cliente a região das callables casa com a do backend
00:01 +41: auditoria — o literal competitivo não pode nascer no cliente (tearDownAll)
00:01 +41: All tests passed!
```
## rkregressao (tail)
```
Try `flutter pub outdated` for more information.
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
00:00 +20: B — a tela não promete o que o botão não cumpre B12 — a sessão realmente inválida continua sem prometer retry
00:00 +21: B — a tela não promete o que o botão não cumpre B13 — nenhum estado de falha afirma liga, nem para exibição
00:00 +22: All tests passed!
```
## composicao (tail)
```
65 packages have newer versions incompatible with dependency constraints.
Try `flutter pub outdated` for more information.
00:00 +0: loading /home/runner/work/buraco-master-vip-app/buraco-master-vip-app/app_build/test/composicao/composicao_perfil_ranking_test.dart
00:00 +0: C1 — o Perfil próprio bebe do escopo de ranking C1 — o Perfil próprio recebe o ranking REAL do escopo
00:00 +1: C1 — o Perfil próprio bebe do escopo de ranking C2 — o ranking chega DEPOIS e a tela acompanha, sem recarregar o perfil
00:00 +2: C1 — o Perfil próprio bebe do escopo de ranking C12 — uma reconstrução não abre callable nova
00:00 +3: C1 — o Perfil próprio bebe do escopo de ranking C13 — três retries concorrentes produzem UMA chamada
00:00 +4: C1 — o Perfil próprio bebe do escopo de ranking C6 — resposta antiga, depois da troca de sessão, não aparece
00:00 +5: C1 — o Perfil próprio bebe do escopo de ranking C7 — resposta de temporada vencida não aparece
00:00 +6: C1 — o Perfil próprio bebe do escopo de ranking C3 — o visitado é escolhido SÓ pelo publicIdVisitado
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
## chatdom (tail)
```
00:00 +36: SAN — sanção SAN-01 chat silenciado impede o envio para a mesa INTEIRA
00:00 +37: SAN — sanção SAN-02 restrição social impede o envio
00:00 +38: SAN — sanção SAN-03 suspensão impede o envio, com recusa própria
00:00 +39: SAN — sanção SAN-04 sem sanção, envio permitido
00:00 +40: SAN — sanção SAN-05 sanção vence bloqueio na recusa reportada
00:00 +41: CAN — canal e papel CAN-01 canal ausente é recusa, não criação
00:00 +42: CAN — canal e papel CAN-02 canal fechado não aceita fala
00:00 +43: CAN — canal e papel CAN-03 superfície pedida tem que bater com a do canal
00:00 +44: CAN — canal e papel CAN-04 ESPECTADOR NÃO FALA
00:00 +45: CAN — canal e papel CAN-05 ESPECTADOR NÃO RECEBE
00:00 +46: CAN — canal e papel CAN-06 quem não está no canal não fala
00:00 +47: CAN — canal e papel CAN-07 mesa sem mais ninguém sentado: sem destinatários
00:00 +48: CAN — canal e papel CAN-08 só espectadores na mesa: sem destinatários
00:00 +49: CAN — canal e papel CAN-09 o autor nunca é destinatário de si mesmo
00:00 +50: PRJ — projeção e vazamento PRJ-01 a projeção não carrega UID interno
00:00 +51: PRJ — projeção e vazamento PRJ-02 a projeção não carrega token, socket nem IP
00:00 +52: PRJ — projeção e vazamento PRJ-03 a projeção não carrega destinatários nem participantes
00:00 +53: PRJ — projeção e vazamento PRJ-04 a projeção tem EXATAMENTE os campos previstos
00:00 +54: PRJ — projeção e vazamento PRJ-05 a trava acha vazamento EM PROFUNDIDADE
00:00 +55: PRJ — projeção e vazamento PRJ-06 a trava acha vazamento dentro de lista
00:00 +56: PRJ — projeção e vazamento PRJ-07 estado administrativo de terceiro é vazamento
00:00 +57: PRJ — projeção e vazamento PRJ-08 a projeção não sugere marcação ativa
00:00 +58: TRV — coerência das listas de trava TRV-01 o que é proibido na entrega é proibido no envio
00:00 +59: TRV — coerência das listas de trava TRV-02 os campos legítimos do pedido não estão na trava de envio
00:00 +60: All tests passed!
```
## comunicacao (tail)
```
00:00 +63: SIS — eventos de sistema (§14.5) SIS-63 o jogador não fabrica selo, título nem texto de sistema
00:00 +64: SIS — eventos de sistema (§14.5) SIS-64 evento de sistema adulterado é recusado
00:00 +65: SIS — eventos de sistema (§14.5) SIS-65 o evento carrega SIGNIFICADO, não frase do remetente
00:00 +66: SIS — eventos de sistema (§14.5) SIS-66 todo item tem chave E fallback oficial
00:00 +67: SIS — eventos de sistema (§14.5) SIS-67 evento fora do ambiente dele é recusado
00:00 +68: SIS — eventos de sistema (§14.5) SIS-68 Treino não recebe nem evento de sistema
00:00 +69: CAT — o catálogo autoritativo (§6.2) CAT-01 ids são únicos e estáveis no formato
00:00 +70: CAT — o catálogo autoritativo (§6.2) CAT-02 item premium não aparece no Saguão Público
00:00 +71: CAT — o catálogo autoritativo (§6.2) CAT-03 nenhum item é liberado no Treino
00:00 +72: CAT — o catálogo autoritativo (§6.2) CAT-04 as categorias aprovadas nos protótipos estão todas presentes
00:00 +73: CAT — o catálogo autoritativo (§6.2) CAT-05 item desativado carrega a data de desativação
00:00 +74: RIT — o ritmo (§6.5) RIT-01 o teto por janela recusa o excedente
00:00 +75: RIT — o ritmo (§6.5) RIT-02 recusas seguidas acionam o bloqueio temporário por abuso
00:00 +76: RIT — o ritmo (§6.5) RIT-03 o bloqueio em vigor recusa sem se renovar sozinho
00:00 +77: RIT — o ritmo (§6.5) RIT-04 estado ilegível vira estado VAZIO, nunca restrição
00:00 +78: RIT — o ritmo (§6.5) RIT-05 o estado devolvido não guarda conteúdo de mensagem
00:00 +79: PRV — o que a resposta NÃO carrega (§11) PRV-01 o veredito aceito não expõe UID de terceiro fora da entrega
00:00 +80: PRV — o que a resposta NÃO carrega (§11) PRV-02 o messageId não deriva do UID de forma legível
00:00 +81: All tests passed!
ok   esp02      3 instancia(s) de ESP-02, distintas, aprovadas, zero fora de test/comunicacao/comunicacao_test.dart
TESTEMUNHA ESP-02: VERDE
COMUNICACAO: exit do flutter    = 0
COMUNICACAO: exit do relatorio  = 0
COMUNICACAO: exit da testemunha = 0
COMUNICACAO: VERDE (flutter 0 + relatorio 0 + testemunha 0)
```
## portaoci (tail)
```
  ok    RB08 [vivas] — codigo apos o terminador presente (vivas_de: SIM)
  ok    RB09 [vivas] — a string com run: | presente (e codigo) (vivas_de: SIM)
  ok    RB09 [vivas] — a carga seguinte presente (vivas_de: SIM)
  ok    RB10 [vivas] — carga do primeiro bloco presente (vivas_de: SIM)
  ok    RB10 [vivas] — carga do segundo bloco presente (vivas_de: SIM)
  ok    RB11 [vivas] — o comentario AUSENTE (vivas_de: NAO)
  ok    RB11 [vivas] — a carga apos vazia+comentario presente (vivas_de: SIM)
  ok    RB12 [vivas] — corpo do heredoc no .sh AUSENTE (vivas_de: NAO)
  ok    RB12 [vivas] — codigo apos o terminador presente (vivas_de: SIM)
  ok    RB13 [vivas] — vivas_de recusa pela ambiguidade (RC=1) E analisa o bloco B (carga presente)
  ok    RB14 [vivas] — carga do segundo bloco presente (vivas_de: SIM)
  ok    RB14 [vivas] — carga do terceiro bloco presente (vivas_de: SIM)

== autoprotecao C10: a cobertura de vivas_de e a do shell real estao vivas ==
  ok    AUTO-C — sem o reset em vivas_de, RB02/RB04/RB14 perdem a carga do bloco B (intacta SIM, mutada NAO)
  ok    AUTO-D — RB08 adulterado (a linha-corpo saiu do heredoc) e o shell real DETECTA a execucao (shell real: EXISTE)

== autoprotecao: a correcao de fronteira esta viva (OS 40-C9) ==
  ok    AUTO-0 — copia extraida INTACTA classifica a carga do bloco B como CODIGO
  ok    AUTO-A — sem o reset da fronteira o bloco B some como HEREDOC: a correcao e load-bearing
  ok    AUTO-B — reset indiscriminado por texto transforma corpo de heredoc em codigo: RB07 pega

----------------------------------------
casos ok: 320 | casos com falha: 0
TESTE DO PORTÃO: VERDE
```
## contratosui (tail)
```
TESTEMUNHA: desafio desta corrida: testemunha-5094-20261001T173137Z
TESTEMUNHA: matriz sob observacao: scripts/ci/teste_contrato_suites.sh
ok   motor      as funcoes de asercao e fixture da matriz sao as congeladas
ok   motorvivo  as sete funcoes que o BASH carregou sao as congeladas (declare -f)
ok   carregador nenhum eval/source/dot-source em execucao viva na matriz
ok   sonda      caso inexistente T99 recusado (exit 2)
ok   reciproca  88 caso(s), mesma relacao e mesma ordem
ok   contratos  17 gate(s) contratados, conjunto exato

----------------------------------------
TESTEMUNHA: 88 caso(s) observados | 88 verde(s) | 0 vermelho(s)
TESTEMUNHA: desafio testemunha-5094-20261001T173137Z
casos ok: 88 | casos com falha: 0
ok   autoridade o pacote externo e o registro dos pares sao os congelados
           | PROVENIENCIA: esperados 66  observados 66  ausentes 0  extras 0  duplicados 0
           | PROVENIENCIA: conjunto esperado veio de: registro externo /home/runner/work/_temp/bmv-prov/proveniencia-esperada-e12.tsv
           | PROVENIENCIA: VERDE — 66/66 execucoes esperadas observadas, conjuntos identicos, toda evidencia com proveniencia
PROVENIENCIA OBRIGATORIA: esperados 66  observados 66  ausentes 0  extras 0  duplicados 0  divergentes 0
PROVENIENCIA OBRIGATORIA: VERDE — 66/66 execucoes esperadas observadas, conjuntos identicos
ok   proveniencia  execucao de todos os gates esperados observada pela autoridade externa
TESTEMUNHA DO CONTRATO: VERDE
```
## autverif (tail)
```
ok   piso         PISOS_EXIGENOCASO  contratosui 5 >= 5

== 5. o tratamento do codigo de saida ==
ok   saida        o verificador nao tem nenhum 'exit 0' antecipado
ok   saida        o verificador termina em exit "$falhas"
ok   saida        o agregador reprova com exit 1 (1 ocorrencia(s))
ok   saida        o agregador reprova com exit 2 (9 ocorrencia(s))

== 6. o lexer, medido por COMPORTAMENTO ==
ok   sonda        agulha em codigo executavel e aceita
ok   sonda        agulha so em comentario e recusada como INERTE
ok   sonda        comentario de bloco sem fechar responde ABERTO
ok   sonda        extensao fora do vocabulario responde SEMLINGUA

== 7. os tres, e esta autoridade, no caminho oficial ==
ok   fonte        o gate 'autverif' continua declarado na fonte unica
ok   workflow     scripts/ci/verificar_contrato_suites.sh continua no caminho oficial
ok   workflow     scripts/ci/portao_os_integracao.sh continua no caminho oficial
ok   workflow     scripts/ci/teste_portao_os_integracao.sh continua no caminho oficial
ok   workflow     scripts/ci/autoridade_verificadores.sh continua no caminho oficial
ok   workflow     o passo produz exit_autverif

----------------------------------------
casos ok: 115 | casos com falha: 0
AUTORIDADE DOS VERIFICADORES: VERDE
```
## billing (tail)
```
  ...
# Subtest: VARR-13 assinante com prazo VENCIDO nao recebe, mesmo com vipAtivo true
ok 413 - VARR-13 assinante com prazo VENCIDO nao recebe, mesmo com vipAtivo true
  ---
  duration_ms: 0.346001
  ...
# Subtest: VARR-14 assinante sem token nao vira pagamento, e e CONTADO
ok 414 - VARR-14 assinante sem token nao vira pagamento, e e CONTADO
  ---
  duration_ms: 0.282004
  ...
# Subtest: VARR-15 o saldo do jogador sobe uma vez por parcela, e so uma
ok 415 - VARR-15 o saldo do jogador sobe uma vez por parcela, e so uma
  ---
  duration_ms: 0.32631
  ...
1..415
# tests 415
# suites 0
# pass 415
# fail 0
# cancelled 0
# skipped 0
# todo 0
# duration_ms 1164.916807
```
## torneiosfn (tail)
```
```
## socialdom (tail)
```

> build:domain
> cd .. && dart compile js -O2 -o functions-social/lib/domain_bundle.js app/lib/social/js_bridge.dart

Compiled 10,446,653 input bytes (5,381,931 characters source) to 87,989 characters JavaScript in 0.72 seconds
```
## socialfn (tail)
```
  ---
  duration_ms: 2.429594
  type: 'suite'
  ...
# Subtest: colecoes: os tres documentos de identidade sao separados
    # Subtest: cada papel tem a sua colecao
    ok 1 - cada papel tem a sua colecao
      ---
      duration_ms: 0.190487
      ...
    1..1
ok 17 - colecoes: os tres documentos de identidade sao separados
  ---
  duration_ms: 0.294723
  type: 'suite'
  ...
1..17
# tests 55
# suites 17
# pass 55
# fail 0
# cancelled 0
# skipped 0
# todo 0
# duration_ms 110.904477
```
## socialemu (tail)
```
[36m[1mi  functions:[22m[39m Finished "southamerica-east1-aoBloquearJogador" in 9.220144ms
[36m[1mi  functions:[22m[39m Beginning execution of "southamerica-east1-aoBloquearJogador"
[90m> [39m {"desfez":false,"severity":"INFO","message":"faxina social por bloqueio"}
[36m[1mi  functions:[22m[39m Finished "southamerica-east1-aoBloquearJogador" in 11.859767ms
[36m[1mi  functions:[22m[39m Beginning execution of "southamerica-east1-aoBloquearJogador"
[90m> [39m {"desfez":false,"severity":"INFO","message":"faxina social por bloqueio"}
[36m[1mi  functions:[22m[39m Finished "southamerica-east1-aoBloquearJogador" in 12.991175ms
[36m[1mi  functions:[22m[39m Beginning execution of "southamerica-east1-aoBloquearJogador"
[90m> [39m {"desfez":false,"severity":"INFO","message":"faxina social por bloqueio"}
[36m[1mi  functions:[22m[39m Finished "southamerica-east1-aoBloquearJogador" in 11.945678ms
[36m[1mi  functions:[22m[39m Beginning execution of "southamerica-east1-aoBloquearJogador"
[90m> [39m {"desfez":false,"severity":"INFO","message":"faxina social por bloqueio"}
[36m[1mi  functions:[22m[39m Finished "southamerica-east1-aoBloquearJogador" in 10.766299ms
[36m[1mi  functions:[22m[39m Beginning execution of "southamerica-east1-aoBloquearJogador"
[90m> [39m {"desfez":false,"severity":"INFO","message":"faxina social por bloqueio"}
[36m[1mi  functions:[22m[39m Finished "southamerica-east1-aoBloquearJogador" in 13.737567ms
[36m[1mi  functions:[22m[39m Beginning execution of "southamerica-east1-aoBloquearJogador"
[90m> [39m {"desfez":false,"severity":"INFO","message":"faxina social por bloqueio"}
[36m[1mi  functions:[22m[39m Finished "southamerica-east1-aoBloquearJogador" in 9.762406ms
[36m[1mi  firestore:[22m[39m Stopping Firestore Emulator
[36m[1mi  auth:[22m[39m Stopping Authentication Emulator
[36m[1mi  eventarc:[22m[39m Stopping Eventarc Emulator
[36m[1mi  tasks:[22m[39m Stopping Cloud Tasks Emulator
[36m[1mi  hub:[22m[39m Stopping emulator hub
[36m[1mi  logging:[22m[39m Stopping Logging Emulator
```
## passeint (tail)
```
    # Subtest: PEF-02: a materialização escreve SÓ nas duas coleções do passe
    ok 2 - PEF-02: a materialização escreve SÓ nas duas coleções do passe
      ---
      duration_ms: 66.959678
      ...
    1..2
ok 5 - PASSE-EMU/FRONTEIRA — o que NÃO foi tocado
  ---
  duration_ms: 133.260299
  type: 'suite'
  ...
1..5
# tests 18
# suites 5
# pass 18
# fail 0
# cancelled 0
# skipped 0
# todo 0
# duration_ms 9024.435107
[32m[1m✔ [22m[39m Script exited successfully (code 0)
[36m[1mi  emulators:[22m[39m Shutting down emulators.
[36m[1mi  firestore:[22m[39m Stopping Firestore Emulator
[36m[1mi  hub:[22m[39m Stopping emulator hub
[36m[1mi  logging:[22m[39m Stopping Logging Emulator
```
## rankingfn (tail)
```
    # Subtest: temporada sem data de termino nao exibe contagem
    ok 6 - temporada sem data de termino nao exibe contagem
      ---
      duration_ms: 0.076845
      ...
    # Subtest: data ilegivel nao quebra a tela
    ok 7 - data ilegivel nao quebra a tela
      ---
      duration_ms: 0.065168
      ...
    1..7
ok 91 - temporada: a faixa de tempo que o cliente exibe
  ---
  duration_ms: 1.077621
  type: 'suite'
  ...
1..91
# tests 465
# suites 91
# pass 465
# fail 0
# cancelled 0
# skipped 0
# todo 0
# duration_ms 636.085372
```
## rankingint (tail)
```
    # Subtest: temporada nova e soft reset NAO trocam o publicId (§22.14 e §22.15)
    ok 3 - temporada nova e soft reset NAO trocam o publicId (§22.14 e §22.15)
      ---
      duration_ms: 524.731508
      ...
    1..3
ok 8 - integracao: encerramento, consolidacao e a temporada seguinte
  ---
  duration_ms: 1037.95864
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
# duration_ms 14206.741503
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
      duration_ms: 156.048722
      ...
    1..3
ok 3 - a integracao nao mexeu no que nao e dela (§12, §13, §14)
  ---
  duration_ms: 441.776768
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
# duration_ms 11276.421239
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
## moderacaofn (tail)
```
    # Subtest: DEFEITO P0: mesma intencao apontada para outra pessoa e CONFLITO
    ok 1 - DEFEITO P0: mesma intencao apontada para outra pessoa e CONFLITO
      ---
      duration_ms: 0.137147
      ...
    # Subtest: a mesma denuncia reenviada (toque duplo, retry) converge
    ok 2 - a mesma denuncia reenviada (toque duplo, retry) converge
      ---
      duration_ms: 0.120483
      ...
    1..2
ok 53 - decidirSobreReserva — denuncia reaproveitada
  ---
  duration_ms: 0.397011
  type: 'suite'
  ...
1..53
# tests 78
# suites 14
# pass 78
# fail 0
# cancelled 0
# skipped 0
# todo 0
# duration_ms 328.21686
```
## chatemu (tail)
```
      ...
    1..8
ok 8 - INT-H — adaptadores da autoridade
  ---
  duration_ms: 319.039248
  type: 'suite'
  ...
1..8
# tests 42
# suites 8
# pass 42
# fail 0
# cancelled 0
# skipped 0
# todo 0
# duration_ms 7873.786038
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
## moderacaoemu (tail)
```
  type: 'suite'
  ...
1..9
# tests 45
# suites 9
# pass 45
# fail 0
# cancelled 0
# skipped 0
# todo 0
# duration_ms 7423.526745

[com-functions] tests=45 pass=45 fail=0 skipped=0 cancelled=0 todo=0 — suite integra.
[32m[1m✔ [22m[39m Script exited successfully (code 0)
[36m[1mi  emulators:[22m[39m Shutting down emulators.
[36m[1mi  functions:[22m[39m Stopping Functions Emulator
[36m[1mi  firestore:[22m[39m Stopping Firestore Emulator
[36m[1mi  auth:[22m[39m Stopping Authentication Emulator
[36m[1mi  eventarc:[22m[39m Stopping Eventarc Emulator
[36m[1mi  tasks:[22m[39m Stopping Cloud Tasks Emulator
[36m[1mi  hub:[22m[39m Stopping emulator hub
[36m[1mi  logging:[22m[39m Stopping Logging Emulator
[emulator-runner] cleanup=ok ports=released
[emulator-runner] report tests=45 pass=45 fail=0 skipped=0 cancelled=0 todo=0 esperado>=45 exit_node=0 exit_exec=0
[emulator-runner] target=moderacao class=OK tests=ok exit=0
```
## colecoesemu (tail)
```
      ...
    1..2
ok 59 - TRN-RULES/AUTORIDADE — a porta certa continua aberta
  ---
  duration_ms: 43.089061
  type: 'suite'
  ...
1..59
# tests 275
# suites 59
# pass 275
# fail 0
# cancelled 0
# skipped 0
# todo 0
# duration_ms 11291.416833
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
## contafn (tail)
```
    # Subtest: minuscula e espaco em volta conferem
    ok 2 - minuscula e espaco em volta conferem
      ---
      duration_ms: 0.180111
      ...
    # Subtest: qualquer outra coisa nao confere
    ok 3 - qualquer outra coisa nao confere
      ---
      duration_ms: 0.133971
      ...
    1..3
ok 18 - palavra de confirmacao
  ---
  duration_ms: 0.627524
  type: 'suite'
  ...
1..18
# tests 86
# suites 18
# pass 86
# fail 0
# cancelled 0
# skipped 0
# todo 0
# duration_ms 157.664422
```
## contaemu (tail)
```
    ok 5 - nenhuma sancao ou denuncia e apagada por consequencia
      ---
      duration_ms: 195.839436
      ...
    1..5
ok 13 - ritmo de fala do chat
  ---
  duration_ms: 948.327088
  type: 'suite'
  ...
1..13
# tests 42
# suites 13
# pass 42
# fail 0
# cancelled 0
# skipped 0
# todo 0
# duration_ms 11713.578839
[32m[1m✔ [22m[39m Script exited successfully (code 0)
[36m[1mi  emulators:[22m[39m Shutting down emulators.
[36m[1mi  firestore:[22m[39m Stopping Firestore Emulator
[36m[1mi  auth:[22m[39m Stopping Authentication Emulator
[36m[1mi  hub:[22m[39m Stopping emulator hub
[36m[1mi  logging:[22m[39m Stopping Logging Emulator
```
## mesasfn (tail)
```
    # Subtest: TAX-14 as duas perguntas NAO sao a mesma — a Privada e a prova
    ok 3 - TAX-14 as duas perguntas NAO sao a mesma — a Privada e a prova
      ---
      duration_ms: 0.187973
      ...
    # Subtest: TAX-15 cortesia nunca implica ranking, e ranking nunca implica cortesia sozinho
    ok 4 - TAX-15 cortesia nunca implica ranking, e ranking nunca implica cortesia sozinho
      ---
      duration_ms: 0.114352
      ...
    1..4
ok 29 - TAX — elegibilidade e cortesia divergem na Privada
  ---
  duration_ms: 0.77753
  type: 'suite'
  ...
1..29
# tests 148
# suites 29
# pass 148
# fail 0
# cancelled 0
# skipped 0
# todo 0
# duration_ms 232.041016
```
## economiafn (tail)
```
  ...
# Subtest: ECO-30 humano sem userId, sem assento ou participante torto invalida tudo
ok 61 - ECO-30 humano sem userId, sem assento ou participante torto invalida tudo
  ---
  duration_ms: 0.112499
  ...
# Subtest: ECO-31 O CLIENTE NAO ESCOLHE O RESULTADO: campos extras sao ignorados
ok 62 - ECO-31 O CLIENTE NAO ESCOLHE O RESULTADO: campos extras sao ignorados
  ---
  duration_ms: 0.197356
  ...
# Subtest: ECO-32 nenhum movimento sai fora dos dois valores da politica
ok 63 - ECO-32 nenhum movimento sai fora dos dois valores da politica
  ---
  duration_ms: 0.20594
  ...
1..63
# tests 63
# suites 0
# pass 63
# fail 0
# cancelled 0
# skipped 0
# todo 0
# duration_ms 95.250119
```
## proveni (tail)
```
    # Subtest: PROV-13 o predeploy de TODA codebase carrega os dois passos, na frente
    ok 2 - PROV-13 o predeploy de TODA codebase carrega os dois passos, na frente
      ---
      duration_ms: 0.329546
      ...
    # Subtest: PROV-12 toda source existe, e nenhum `ignore` exclui o carimbo
    ok 3 - PROV-12 toda source existe, e nenhum `ignore` exclui o carimbo
      ---
      duration_ms: 0.328624
      ...
    1..3
ok 3 - §16 — a arvore REAL desta composicao
  ---
  duration_ms: 1.96308
  type: 'suite'
  ...
1..3
# tests 13
# suites 3
# pass 13
# fail 0
# cancelled 0
# skipped 0
# todo 0
# duration_ms 704.115826
```
## composneg (tail)
```
    # Subtest: o gerador recusa SHA por argumento e por ambiente
    ok 1 - o gerador recusa SHA por argumento e por ambiente
      ---
      duration_ms: 49.85079
      ...
    # Subtest: nenhuma codebase pode ser implantada sem atravessar a proveniencia
    ok 2 - nenhuma codebase pode ser implantada sem atravessar a proveniencia
      ---
      duration_ms: 0.197517
      ...
    1..2
ok 16 - PN-15 — a prova de SHA aceitando valor manual
  ---
  duration_ms: 50.154897
  type: 'suite'
  ...
1..16
# tests 21
# suites 16
# pass 21
# fail 0
# cancelled 0
# skipped 0
# todo 0
# duration_ms 231.814729
```
## rkpagina (tail)
```
  url_launcher_windows 3.1.5 (3.1.6 available)
  vector_math 2.2.0 (2.4.3 available)
  vm_service 15.2.0 (15.3.0 available)
  yaml 3.1.3 (3.1.4 available)
Got dependencies!
65 packages have newer versions incompatible with dependency constraints.
Try `flutter pub outdated` for more information.
00:00 +0: loading /home/runner/work/buraco-master-vip-app/buraco-master-vip-app/app_build/test/ranking_page_test.dart
00:00 +0: estados carregando: esqueleto, e nenhum nome na tela
00:00 +1: estados lista carregada mostra apelido, posicao e liga
00:00 +2: estados ranking vazio tem texto proprio, nao erro
00:00 +3: estados erro mostra o motivo da fonte e o botao de tentar de novo
00:00 +4: estados tentar de novo refaz a busca e recupera a lista
00:00 +5: sem fonte oficial (caminho de producao) a tela diz que nao ha ranking publicado, sem inventar nome
00:00 +6: jogador local x outro jogador so a linha marcada pela fonte recebe o selo VOCE
00:00 +7: jogador local x outro jogador tocar em outro jogador abre o perfil dele pelo id publico
00:01 +8: jogador local x outro jogador tocar em si mesmo abre o proprio perfil
00:01 +9: jogador local x outro jogador jogador sem id publicado nao navega
00:01 +10: paginacao na tela sem proxima pagina, o botao nem aparece
00:01 +11: paginacao na tela carregar mais concatena e some no fim da lista
00:01 +12: paginacao na tela erro na segunda pagina nao apaga a primeira
00:01 +13: abas trocar de aba busca a nova, e voltar nao rebusca
00:01 +14: descarte sair da tela antes da resposta nao quebra nada
00:01 +15: superficie pequena 320x640 desenha a lista sem estouro
00:01 +16: All tests passed!
```
## composloja (tail)
```
  ---
  duration_ms: 1.87366
  type: 'suite'
  ...
# Subtest: CL-11 — dado de maquete no caminho publicavel da Loja
    # Subtest: nenhum arquivo da casca de producao constroi `.mock()`
    ok 1 - nenhum arquivo da casca de producao constroi `.mock()`
      ---
      duration_ms: 4.652691
      ...
    1..1
ok 11 - CL-11 — dado de maquete no caminho publicavel da Loja
  ---
  duration_ms: 4.732721
  type: 'suite'
  ...
1..11
# tests 35
# suites 11
# pass 35
# fail 0
# cancelled 0
# skipped 0
# todo 0
# duration_ms 262.248347
```
## avatarcanon (tail)
```
00:02 +16: reatividade M13 logout remove o avatar anterior
00:02 +17: reatividade M13b logout COM O PERFIL ABERTO apaga o avatar na hora
00:02 +18: reatividade M14b troca de jogador COM O PERFIL ABERTO não vaza o antigo
00:02 +19: reatividade M14 login de outro jogador não mostra o avatar do anterior
00:02 +20: reatividade M15 mudança de publicId invalida o estado anterior
00:02 +21: reatividade M16 Perfil em carregamento não inventa avatar definitivo
00:02 +22: reatividade referência válida que depois fica inválida cai no fallback
00:02 +23: o que não podia mudar M17 nome, ranking e moldura seguem intactos
00:02 +24: o que não podia mudar M23 o convite compartilhado continua funcional e sem o avatar
00:02 +25: o que não podia mudar M19 main.dart continua byte a byte o da base
00:02 +26: o que não podia mudar M22 Mesa Online e Mesa de Treino ficam fora do assunto
00:02 +27: o que não podia mudar M24 as coroas ornamentais continuam onde estavam
00:02 +28: auditoria estrutural (setUpAll)
00:02 +28: auditoria estrutural M20 o Perfil não abriu consulta nova a publicProfiles
00:02 +29: auditoria estrutural a autoridade do avatar é UMA, e mora no resolvedor
00:02 +30: auditoria estrutural o fallback é literal em um lugar só do fecho alcançável
00:03 +31: auditoria estrutural M21 nenhum literal Bronze reaparece no fecho alcançável
00:03 +32: auditoria estrutural M21b e nenhuma liga é AFIRMADA pelo caminho publicável
00:03 +33: auditoria estrutural o fecho cresceu só pelo componente previsto
00:03 +34: auditoria estrutural o Hall continua alcançável, e por um produtor de verdade
00:03 +35: auditoria estrutural nada do que a OS proíbe entrou no fecho
00:03 +36: auditoria estrutural M18 authStateChanges continua com um assinante só
00:03 +37: auditoria estrutural o resolvedor não conhece Flutter, Firebase nem armazenamento
00:03 +38: auditoria estrutural (tearDownAll)
00:03 +38: All tests passed!
```
## avatarhml (tail)
```
00:01 +20: H-C Perfil H-C05 o serviço resolve o avatar pela identidade, não por constante
00:01 +21: H-C Perfil H-C06 o Perfil não busca nome nem avatar no Firebase Auth
00:01 +22: H-D identidade em movimento H-D01 chegada tardia: fallback antes, referência depois
00:01 +23: H-D identidade em movimento H-D02 avatarRef muda com o MESMO publicId
00:01 +24: H-D identidade em movimento H-D03 Home e Perfil montados juntos concordam em 8 estados
00:02 +25: H-D identidade em movimento H-D04 logout com as telas montadas apaga o avatar na hora
00:02 +26: H-D identidade em movimento H-D05 na janela da troca A→B o avatar de A não pisca
00:02 +27: H-D identidade em movimento H-D06 resposta ATRASADA da conta A não contamina a conta B
00:02 +28: H-D identidade em movimento H-D07 válida→inválida e inválida→válida, nos dois sentidos
00:02 +29: H-D identidade em movimento H-D08 60 reconstruções de cada tela não emitem chamada
00:03 +30: H-D identidade em movimento H-D09 abrir e fechar o Perfil 6 vezes não emite chamada
00:03 +31: H-D identidade em movimento H-D11 a troca de avatar não devolve o Perfil ao esqueleto
00:03 +32: H-D identidade em movimento H-D10 falha de identidade não inventa avatar
00:04 +33: H-E auditoria estrutural (setUpAll)
00:04 +33: H-E auditoria estrutural H-E01 main.dart continua byte a byte o da base
00:04 +34: H-E auditoria estrutural H-E02 authStateChanges tem UM assinante, e é a sessão
00:04 +35: H-E auditoria estrutural H-E03 obterMinhaIdentidade é chamado de UM lugar só
00:04 +36: H-E auditoria estrutural H-E04 nem Home nem Perfil alcançam Firestore ou publicProfiles
00:04 +37: H-E auditoria estrutural H-E05 o fecho cresceu só pelo resolvedor
00:04 +38: H-E auditoria estrutural H-E06 a coroa tem UM dono NA FUNÇÃO DE AVATAR
00:04 +39: H-E auditoria estrutural H-E07 nenhuma tela inventa catálogo nem mapeia referência a arquivo
00:04 +40: H-E auditoria estrutural H-E09 nenhum produtor de produção escreve um avatar literal
00:04 +41: H-E auditoria estrutural H-E08 o delta não carrega credencial, segredo nem dado pessoal
00:04 +42: H-E auditoria estrutural (tearDownAll)
00:04 +42: All tests passed!
```
## perfilvis (tail)
```
00:00 +1: perfil próprio V2 meu perfil mostra o MEU avatar
00:00 +2: perfil próprio V18 meu perfil continua funcional de ponta a ponta
00:00 +3: A visita B V3 o nome é o de B
00:00 +4: A visita B V4 o avatar é o de B
00:00 +5: A visita B V5 a liga é a de B
00:00 +6: A visita B V6 as estatísticas são as de B
00:00 +7: A visita B V7 o nome de A NUNCA aparece no perfil de B
00:01 +8: A visita B V8 o avatar de A NUNCA aparece no perfil de B
00:01 +9: A visita B V-cruzado os QUATRO campos são de B, ao mesmo tempo
00:01 +10: assíncrono V9 resposta atrasada de B não sobrescreve C
00:01 +11: assíncrono V10 três toques em B produzem UMA consulta
00:01 +12: a chave é o publicId V11 publicId vazio não navega nem consulta
00:01 +13: a chave é o publicId V12 apelido não vira chave
00:01 +14: a chave é o publicId V13 posição não vira chave
00:01 +15: a chave é o publicId V14 índice de lista não vira chave
00:01 +16: a chave é o publicId V-mesmo-id o próprio publicId pela porta pública converge
00:01 +17: falha, fallback e privacidade V15 falha na leitura pública NÃO cai para a sessão
00:01 +18: falha, fallback e privacidade V15b classificado:false também não vaza a visitante
00:01 +19: falha, fallback e privacidade V16 avatar ausente do visitado usa o fallback PÚBLICO
00:01 +20: falha, fallback e privacidade V16b referência malformada cai no mesmo fallback
00:01 +21: falha, fallback e privacidade V17 a projeção pública não tem campo privado
00:01 +22: falha, fallback e privacidade V17b nada de privado chega à tela do visitado
00:01 +23: guarda estrutural V-guarda o caminho visitado não alcança a identidade da sessão
00:01 +24: guarda estrutural V-guarda o serviço não tem segunda fonte de identidade
00:01 +25: All tests passed!
```
## rknavpub (tail)
```
00:01 +16: N3–N10 — a decisão de qual Perfil abrir N14 — voltar do Perfil público preserva o ranking
00:01 +17: N3–N10 — a decisão de qual Perfil abrir N15 — cada linha é um botão com área de toque suficiente
00:01 +18: N6–N9 — voo, cache e troca de sessão N6 — três toques no MESMO terceiro reutilizam o voo
00:01 +19: N6–N9 — voo, cache e troca de sessão N6b — abertura e projeção compartilham UM voo
00:01 +20: N6–N9 — voo, cache e troca de sessão N7 — dois terceiros NÃO compartilham cache nem voo
00:01 +21: N6–N9 — voo, cache e troca de sessão N8 — troca de sessão esvazia cache e desarma os voos antigos
00:01 +22: N6–N9 — voo, cache e troca de sessão N9 — resposta antiga não substitui a sessão nova
00:01 +23: N6–N9 — voo, cache e troca de sessão N8b — a tabela morre junto com a sessão
00:01 +24: N11 — os estados da tela N11a — CARREGANDO não desenha lista nem "ninguém"
00:01 +25: N11 — os estados da tela N11b — VAZIO só é dito quando a autoridade respondeu
00:01 +26: N11 — os estados da tela N11c — ACESSO RECUSADO é neutro e oferece insistir
00:01 +27: N11 — os estados da tela N11d — o retry emite UMA chamada nova, não três
00:01 +28: N11 — os estados da tela N11e — SEM TEMPORADA não vira erro nem botão
00:01 +29: N11 — os estados da tela N11f — SUCESSO desenha o que veio, e `posicao: 0` vira —
00:01 +30: N11 — os estados da tela N11g — fora do escopo de ranking a tela não afirma nada
00:01 +31: N12–N13 — nada de maquete no caminho (setUpAll)
00:01 +31: N12–N13 — nada de maquete no caminho N12 — Hall, Amigos e a tela de Ranking de maquete ficam de fora
00:01 +32: N12–N13 — nada de maquete no caminho N13 — nenhum slug de maquete existe no código alcançável
00:01 +33: N12–N13 — nada de maquete no caminho N13b — `publicIdVisitado` só recebe o campo da projeção
00:02 +34: N12–N13 — nada de maquete no caminho N13c — o Perfil VISITADO é construído num lugar só
00:02 +35: N12–N13 — nada de maquete no caminho N13d — a tela do ranking não tem jogador escrito dentro
00:02 +36: N12–N13 — nada de maquete no caminho (tearDownAll)
00:02 +36: N16 — o Perfil abre o ranking real N16a — a linha competitiva leva ao ranking
00:02 +37: N16 — o Perfil abre o ranking real N16b — sem callback, a linha competitiva não vira botão
00:02 +38: All tests passed!
```
## compavrank (tail)
```
65 packages have newer versions incompatible with dependency constraints.
Try `flutter pub outdated` for more information.
00:00 +0: loading /home/runner/work/buraco-master-vip-app/buraco-master-vip-app/app_build/test/composicao/composicao_avatar_ranking_test.dart
00:00 +0: Home — as duas autoridades no mesmo cabeçalho identidade válida: o avatar vem da autoridade canônica
00:00 +1: Home — as duas autoridades no mesmo cabeçalho avatar ausente: o fallback é da autoridade, não da tela
00:00 +2: Home — as duas autoridades no mesmo cabeçalho Ranking real: a liga é exibível
00:00 +3: Home — as duas autoridades no mesmo cabeçalho Ranking provisório: a liga é omitida
00:01 +4: Home — as duas autoridades no mesmo cabeçalho sem autoridade de ranking a liga some, e o avatar fica
00:01 +5: Perfil — um VM só, enriquecido duas vezes perfil próprio: ranking E avatar presentes no mesmo VM
00:01 +6: Perfil — um VM só, enriquecido duas vezes Home e Perfil concordam no avatar E no estado competitivo
00:01 +7: Perfil — um VM só, enriquecido duas vezes avatar ausente: Home e Perfil caem no MESMO fallback
00:01 +8: Perfil — um VM só, enriquecido duas vezes perfil de terceiro: o Ranking é o do publicId visitado
00:01 +9: Perfil — um VM só, enriquecido duas vezes perfil de terceiro sem publicId não afirma ranking nenhum
00:01 +10: troca de identidade A → B nem avatar nem Ranking de A permanecem na Home
00:01 +11: troca de identidade A → B nem avatar nem Ranking de A permanecem no Perfil aberto
00:01 +12: troca de identidade A → B logout apaga o avatar e o Ranking de uma vez
00:01 +13: navegação preserva o publicId o Perfil aberto por publicId consulta AQUELE publicId
00:01 +14: navegação preserva o publicId visitar dois perfis diferentes consulta os dois ids
00:02 +15: navegação preserva o publicId abrir o próprio Perfil usa a identidade autenticada
00:02 +16: árvore produtiva a Home não decide o fallback do avatar
00:02 +17: árvore produtiva a Home não decide sozinha o que é liga de verdade
00:02 +18: árvore produtiva os dois enriquecimentos do Perfil coexistem no VM
00:02 +19: árvore produtiva a página aplica os DOIS ao mesmo Perfil
00:02 +20: árvore produtiva a autoridade do avatar continua sendo uma só
00:02 +21: All tests passed!
```
## compnavpub (tail)
```
00:00 +0: C1 — as quatro entregas no mesmo fecho (setUpAll)
00:00 +0: C1 — as quatro entregas no mesmo fecho C1 avatar e Ranking Real coexistem, e a navegação com eles
00:00 +1: C1 — as quatro entregas no mesmo fecho C17 os cinco arquivos nominais do Ranking continuam no fecho
00:00 +2: C1 — as quatro entregas no mesmo fecho C18 o avatar acrescenta só a sua dependência legítima
00:00 +3: C1 — as quatro entregas no mesmo fecho C16 nenhuma superfície de maquete assume autoridade
00:00 +4: C1 — as quatro entregas no mesmo fecho C12 o avatar não volta ao emoji fixo na trilha produtiva
00:00 +5: C1 — as quatro entregas no mesmo fecho C19 nenhuma suíte das entradas foi removida
00:00 +6: C1 — as quatro entregas no mesmo fecho C20 nenhuma contagem rígida envelhecida sobrou nas auditorias
00:00 +7: C1 — as quatro entregas no mesmo fecho (tearDownAll)
00:00 +7: C5–C11 — jogadores públicos, sem uid e sem palpite C5 a tabela usa jogadores públicos SEM uid
00:00 +8: C5–C11 — jogadores públicos, sem uid e sem palpite C6 o terceiro navega pelo publicId, e por ele só
00:01 +9: C5–C11 — jogadores públicos, sem uid e sem palpite C7 o proprietário abre o próprio Perfil sem callable de terceiro
00:01 +10: C5–C11 — jogadores públicos, sem uid e sem palpite C8 publicId vazio não navega
00:01 +11: C5–C11 — jogadores públicos, sem uid e sem palpite C9 apelido não vira identificador
00:01 +12: C5–C11 — jogadores públicos, sem uid e sem palpite C10 posição não vira identificador
00:01 +13: C5–C11 — jogadores públicos, sem uid e sem palpite C11 índice de lista não vira identificador
00:01 +14: C5–C11 — jogadores públicos, sem uid e sem palpite C6b duas visitas seguidas consultam os DOIS ids
00:01 +15: C12–C15 — as invariantes da base sob a tabela nova C12 o avatar canônico segue no cabeçalho da Home
00:01 +16: C12–C15 — as invariantes da base sob a tabela nova C12b avatar ausente cai no fallback DA AUTORIDADE
00:01 +17: C12–C15 — as invariantes da base sob a tabela nova C13 ranking ausente não vira Bronze nem colocação zero
00:01 +18: C12–C15 — as invariantes da base sob a tabela nova C14 a barreira temporal continua de pé sob o abrirRanking novo
00:01 +19: C12–C15 — as invariantes da base sob a tabela nova C15 três toques simultâneos abrem UMA consulta
00:01 +20: a identidade do terceiro — pendência RESOLVIDA o perfil visitado é do visitado, nos quatro campos
00:01 +21: a identidade do terceiro — pendência RESOLVIDA a liga da sessão NÃO mascara a do visitado
00:01 +22: All tests passed!
```
## socialestado (tail)
```
00:00 +4: AcaoSocial — a lista que autoriza os botões a ORDEM do servidor é preservada
00:00 +5: AcaoSocial — a lista que autoriza os botões repetição não vira dois botões iguais
00:00 +6: AcaoSocial — a lista que autoriza os botões o que não é lista vira lista vazia, e não explode
00:00 +7: AcaoSocial — a lista que autoriza os botões a lista devolvida é imutável
00:00 +8: JogadorPublico — apresentação sem identidade inventada apelido vazio NÃO vira o rótulo genérico enquanto houver publicId
00:00 +9: JogadorPublico — apresentação sem identidade inventada só sem apelido E sem id aparece o rótulo genérico
00:00 +10: JogadorPublico — apresentação sem identidade inventada a checagem de id para em "não vazio" — não confere a FORMA
00:00 +11: JogadorPublico — apresentação sem identidade inventada campo de outro tipo não vira texto do tipo errado
00:00 +12: PaginaSocial — concatenar, subtrair, e o cursor opaco itens que não são objeto são DESCARTADOS, e o resto fica
00:00 +13: PaginaSocial — concatenar, subtrair, e o cursor opaco cursor ausente é fim de lista
00:00 +14: PaginaSocial — concatenar, subtrair, e o cursor opaco `seguida` concatena preservando a ordem e deduplicando
00:00 +15: PaginaSocial — concatenar, subtrair, e o cursor opaco `sem` subtrai, e subtrair é a única mutação local permitida
00:00 +16: PaginaSocial — concatenar, subtrair, e o cursor opaco subtrair quem não está na lista não muda nada
00:00 +17: ResultadoSocial — a busca e o perfil produzem o MESMO tipo a busca hidrata jogador, relação e ações do mesmo objeto
00:00 +18: ResultadoSocial — a busca e o perfil produzem o MESMO tipo `verPerfilPublico` aninha o perfil, e mesmo assim vira o mesmo tipo
00:00 +19: ResultadoSocial — a busca e o perfil produzem o MESMO tipo perfil ausente na resposta não vira jogador inventado
00:00 +20: ResultadosDeBusca — truncado, modo e o termo que os produziu o termo viaja junto do resultado
00:00 +21: ResultadosDeBusca — truncado, modo e o termo que os produziu `truncado` só é verdade quando o servidor diz que é
00:00 +22: ResultadosDeBusca — truncado, modo e o termo que os produziu modo desconhecido cai em prefixo, que é o mais amplo
00:00 +23: ResultadosDeBusca — truncado, modo e o termo que os produziu NÃO existe cursor na resposta de busca
00:00 +24: DesfechoSocial e FalhaSocial `repeticao` é sucesso, e vem do servidor
00:00 +25: DesfechoSocial e FalhaSocial sem `repeticao` no fio, o padrão é falso
00:00 +26: DesfechoSocial e FalhaSocial só rede e desconhecido justificam "tentar de novo"
00:00 +27: DesfechoSocial e FalhaSocial o código de recusa é guardado CRU
00:00 +28: All tests passed!
```
## socialleitor (tail)
```
00:00 +5: resposta vencida — quem chega por último não é quem manda falhar no "carregar mais" NÃO derruba a lista que está na tela
00:00 +6: resposta vencida — quem chega por último não é quem manda `carregarMais` manda o cursor OPACO, exatamente como veio
00:00 +7: resposta vencida — quem chega por último não é quem manda um RECARREGAR substitui a página; não concatena
00:00 +8: troca de sessão — nada de A sobra para B as três listas e a busca são esvaziadas
00:00 +9: troca de sessão — nada de A sobra para B a mesma geração não reinicia nada
00:00 +10: troca de sessão — nada de A sobra para B a vista de UM jogador em voo não atravessa a troca
00:00 +11: busca — o termo, o vencido e o vazio termo vazio não gasta chamada
00:00 +12: busca — o termo, o vencido e o vazio o termo vai APARADO, mas não normalizado
00:00 +13: busca — o termo, o vencido e o vazio os resultados anteriores FICAM enquanto a nova consulta corre
00:00 +14: busca — o termo, o vencido e o vazio a resposta de um termo abandonado não aparece
00:00 +15: busca — o termo, o vencido e o vazio "ninguém encontrado" só existe com a fase pronta
00:00 +16: busca — o termo, o vencido e o vazio limpar a busca descarta o que estava em voo
00:00 +17: ação aceita — subtrai, relê, e NUNCA adiciona aceitar SUBTRAI da lista de recebidas
00:00 +18: ação aceita — subtrai, relê, e NUNCA adiciona aceitar NÃO adiciona ninguém à lista de amigos
00:00 +19: ação aceita — subtrai, relê, e NUNCA adiciona a vista devolvida vem da AUTORIDADE, e não do desfecho
00:00 +20: ação aceita — subtrai, relê, e NUNCA adiciona a releitura que falha vira "não sei" — nunca uma relação deduzida
00:00 +21: ação aceita — subtrai, relê, e NUNCA adiciona `repeticao` chega como sucesso, e não como erro
00:00 +22: ação aceita — subtrai, relê, e NUNCA adiciona a ação recusada PROPAGA a falha — não some em silêncio
00:00 +23: ação aceita — subtrai, relê, e NUNCA adiciona publicId vazio nem sai do aparelho
00:00 +24: ação aceita — subtrai, relê, e NUNCA adiciona `adicionarAmigo` não subtrai de lista nenhuma
00:00 +25: ação aceita — subtrai, relê, e NUNCA adiciona a linha da BUSCA é trocada pela vista nova da autoridade
00:00 +26: vistaDe — a relação de UM, sem cache dois pedidos simultâneos do mesmo id compartilham a chamada
00:00 +27: vistaDe — a relação de UM, sem cache pedidos SEQUENCIAIS consultam de novo — não há cache
00:00 +28: vistaDe — a relação de UM, sem cache id vazio não consulta
00:00 +29: All tests passed!
```
## socialtela (tail)
```
  vm_service 15.2.0 (15.3.0 available)
  yaml 3.1.3 (3.1.4 available)
Got dependencies!
65 packages have newer versions incompatible with dependency constraints.
Try `flutter pub outdated` for more information.
00:00 +0: loading /home/runner/work/buraco-master-vip-app/buraco-master-vip-app/app_build/test/amigos/descoberta_social_tela_test.dart
00:00 +0: Amigos — as listas vêm da autoridade a lista desenha quem o servidor devolveu, e emite UMA consulta
00:00 +1: Amigos — as listas vêm da autoridade nenhum nome da maquete chega à tela
00:00 +2: Amigos — as listas vêm da autoridade lista vazia CONFIRMADA diz que está vazia; carregando, não
00:00 +3: Amigos — as listas vêm da autoridade trocar de aba consulta a aba nova, e só ela
00:00 +4: Amigos — as listas vêm da autoridade o botão da aba de recebidas é o VERBO da ação
00:01 +5: busca — os botões são os do servidor, e o estado volta termo curto demais nem sai do aparelho
00:01 +6: busca — os botões são os do servidor, e o estado volta a tela desenha SÓ as ações que a autoridade ofereceu
00:01 +7: busca — os botões são os do servidor, e o estado volta adicionar reflete a vista NOVA da autoridade na mesma linha
00:01 +8: busca — os botões são os do servidor, e o estado volta busca truncada convida a refinar, e não oferece "mais"
00:01 +9: busca — os botões são os do servidor, e o estado volta recusa de termo curto vira recado sobre o TEXTO
00:01 +10: navegação — o publicId, e nunca a posição tocar num amigo abre o Perfil daquele publicId
00:01 +11: navegação — o publicId, e nunca a posição um resultado que É você abre o perfil do DONO
00:01 +12: Perfil visitado — a relação vem do social, e volta depois da ação a faixa mostra o rótulo e os botões da autoridade
00:01 +13: Perfil visitado — a relação vem do social, e volta depois da ação o perfil do DONO não tem faixa social nem consulta relação
00:01 +14: Perfil visitado — a relação vem do social, e volta depois da ação `ehMeuPerfil` VENCE um `publicIdVisitado` escrito junto
00:02 +15: Perfil visitado — a relação vem do social, e volta depois da ação remover reflete a relação nova, vinda da autoridade
00:02 +16: Perfil visitado — a relação vem do social, e volta depois da ação social fora do ar NÃO derruba o Perfil — só tira a faixa
00:02 +17: Perfil visitado — a relação vem do social, e volta depois da ação relação sem rótulo E sem ação não desenha faixa
00:02 +18: All tests passed!
```
## audsocial (tail)
```
00:00 +0: apelido não é identificador nenhuma chamada de ação ou de perfil viaja com apelido
00:00 +1: apelido não é identificador a decisão de qual Perfil abrir não vê apelido
00:00 +2: posição e índice não identificam ninguém a navegação não conhece posição nem índice de lista
00:00 +3: posição e índice não identificam ninguém as telas sociais passam o publicId, e nunca um índice
00:00 +4: UID não atravessa a fronteira nenhum arquivo do módulo social do cliente menciona uid
00:00 +5: UID não atravessa a fronteira `JogadorPublico` não tem campo de identidade interna
00:00 +6: o cliente não guarda grafo o leitor não guarda relação em memória — nem índice, nem cache
00:00 +7: o cliente não guarda grafo nada no cliente ADICIONA jogador a uma lista social
00:00 +8: as ações vêm do servidor nenhuma tela deriva ação a partir da relação
00:00 +9: as ações vêm do servidor os botões saem de `acoes`, e são filtrados pelo que há porta
00:00 +10: as ações vêm do servidor `bloquear` e `desbloquear` não têm caminho neste módulo
00:00 +11: a fronteira com `lib/social/` nenhum arquivo do módulo importa o domínio das Functions
00:00 +12: a fronteira com `lib/social/` nada calcula, valida ou repara a FORMA de um publicId
00:00 +13: a fronteira com `lib/social/` a checagem de id utilizável para em "não vazio"
00:00 +14: o bloqueio não é decidido nem revelado pelo cliente o cliente não tem vocabulário para saber quem o bloqueou
00:00 +15: o bloqueio não é decidido nem revelado pelo cliente nenhuma frase da tela distingue bloqueio de sanção
00:00 +16: o bloqueio não é decidido nem revelado pelo cliente o código de recusa só é LIDO para escolher a frase, nunca exibido
00:00 +17: a maquete de Amigos não voltou a tela de produção não importa nem constrói a maquete
00:00 +18: a maquete de Amigos não voltou nenhum identificador da maquete existe no módulo ou nas telas
00:00 +19: a maquete de Amigos não voltou a maquete continua existindo — ninguém a apagou para calar a regra
00:00 +20: só um arquivo conhece Firebase `cloud_functions` entra por um ponto só do módulo
00:00 +21: só um arquivo conhece Firebase a região é IMPORTADA da identidade, e não recopiada
00:00 +22: só um arquivo conhece Firebase os nomes das callables são os que o backend exporta
00:00 +23: (tearDownAll)
00:00 +23: All tests passed!
```
## a11yamigos (tail)
```
00:05 +51: 4 — a semântica exemplar continua de pé 4g — nenhum UID na árvore — busca com resultado
00:05 +52: 4 — a semântica exemplar continua de pé 4e — nenhum anúncio duplicado — busca truncada
00:05 +53: 4 — a semântica exemplar continua de pé 4f — a ordem de foco desce a tela — busca truncada
00:05 +54: 4 — a semântica exemplar continua de pé 4g — nenhum UID na árvore — busca truncada
00:05 +55: 4 — a semântica exemplar continua de pé 4e — nenhum anúncio duplicado — falha de lista
00:05 +56: 4 — a semântica exemplar continua de pé 4f — a ordem de foco desce a tela — falha de lista
00:05 +57: 4 — a semântica exemplar continua de pé 4g — nenhum UID na árvore — falha de lista
00:05 +58: 4 — a semântica exemplar continua de pé 4e — nenhum anúncio duplicado — falha de busca
00:06 +59: 4 — a semântica exemplar continua de pé 4f — a ordem de foco desce a tela — falha de busca
00:06 +60: 4 — a semântica exemplar continua de pé 4g — nenhum UID na árvore — falha de busca
00:06 +61: 4 — a semântica exemplar continua de pé 4e — nenhum anúncio duplicado — vazio
00:06 +62: 4 — a semântica exemplar continua de pé 4f — a ordem de foco desce a tela — vazio
00:06 +63: 4 — a semântica exemplar continua de pé 4g — nenhum UID na árvore — vazio
00:06 +64: 4 — a semântica exemplar continua de pé 4e — nenhum anúncio duplicado — carregando
00:06 +65: 4 — a semântica exemplar continua de pé 4f — a ordem de foco desce a tela — carregando
00:06 +66: 4 — a semântica exemplar continua de pé 4g — nenhum UID na árvore — carregando
00:06 +67: 4 — a semântica exemplar continua de pé 4e — nenhum anúncio duplicado — fora do escopo
00:06 +68: 4 — a semântica exemplar continua de pé 4f — a ordem de foco desce a tela — fora do escopo
00:06 +69: 4 — a semântica exemplar continua de pé 4g — nenhum UID na árvore — fora do escopo
00:06 +70: 5 — vazio, carregando, erro e conteúdo 5a — vazio diz a frase da aba, e não desenha alvo de lista
00:06 +71: 5 — vazio, carregando, erro e conteúdo 5b — carregando mostra o progresso
00:06 +72: 5 — vazio, carregando, erro e conteúdo 5c — erro oferece Tentar de novo, no piso
00:06 +73: 5 — vazio, carregando, erro e conteúdo 5d — conteúdo continua desenhando quem o servidor mandou
00:06 +74: 5 — vazio, carregando, erro e conteúdo 5e — fora do escopo diz o motivo, e o Voltar continua no piso
00:06 +75: All tests passed!
```
## torneiobase (tail)
```
00:00 +34 -3: CICL CICL-05 criador aprovando a propria edicao e RECUSADO
00:00 +35 -3: CICL CICL-06 aprovador ausente e RECUSADO
00:00 +36 -3: CICL CICL-07 criador ausente e RECUSADO
00:00 +37 -3: CICL CICL-08 o cliente nao aprova, nem com os dois nomes certos
00:00 +38 -3: CICL CICL-09 a automacao nao submete a revisao nem aprova
00:00 +39 -3: CICL CICL-10 rejeitar devolve ao rascunho, e nao cancela
00:00 +40 -3: CICL CICL-11 transicao regressiva indevida e recusada
00:00 +41 -3: CICL CICL-12 estado desconhecido nao vira estado
00:00 +42 -3: CICL CICL-13 em_revisao nao e publico e nao aceita inscricao
00:00 +43 -3: ECON ECON-01 a fundacao nao escolheu carteira nenhuma
00:00 +44 -3: ECON ECON-02 o contrato recusa premiacao que aponte destino
00:00 +45 -3: ECON ECON-03 o seed ativo declara premiacao SEM destino
00:00 +46 -3: JOBS JOBS-01 o dominio nao consome nem marca a fila de tarefas
00:00 +47 -3: JOBS JOBS-02 esta fundacao nao criou consumidor de jobs
00:00 +48 -3: HALL HALL-01 o dominio nao produz candidatura ao Hall
00:00 +49 -3: HALL HALL-02 o seed cita o Hall como PREMIO, e nunca como evento
00:00 +50 -3: CLI CLI-01 nenhum arquivo de Torneios esta no fecho de main()
00:00 +51 -3: CLI CLI-02 a bancada de previa continua sem importador
00:00 +52 -3: CLI CLI-03 nenhuma tela de torneio ganhou porta de inscricao
00:00 +53 -3: Some tests failed.

Failing tests:
  /home/runner/work/buraco-master-vip-app/buraco-master-vip-app/app_build/test/torneios/fundacao_base_p_test.dart: CTR CTR-04 os dois templates do legado sao recusados pelo contrato
  /home/runner/work/buraco-master-vip-app/buraco-master-vip-app/app_build/test/torneios/fundacao_base_p_test.dart: SEED SEED-12 os superseested foram PRESERVADOS no legado, como estavam
  /home/runner/work/buraco-master-vip-app/buraco-master-vip-app/app_build/test/torneios/fundacao_base_p_test.dart: SEED SEED-14 um superseded de volta ao seed ativo DERRUBA a carga
```
## admvip (tail)
```
00:00 +24: CLI CLI-05 nenhuma tela decide elegibilidade de torneio por conta propria
00:00 +25: CONV CONV-01 `somente_convidados` deriva OS DOIS criterios
00:00 +26: CONV CONV-02 os criterios de `somente_convidados` PARSEIAM
00:00 +27: CONV CONV-03 convite SEM VIP nao entra
00:00 +28: CONV CONV-04 VIP SEM convite nao entra no torneio de convidados
00:00 +29: CONV CONV-05 VIP integral COM convite proprio entra
00:00 +30: CONV CONV-06 convite de OUTRO torneio nao habilita este
00:00 +31: CONV CONV-07 convite INEXISTENTE e convite EXPIRADO chegam iguais: ausentes
00:00 +32: CONV CONV-08 o Encerramento e EventoEncerramento, e NAO um template
00:00 +33: AUT AUT-01 documento MALFORMADO nao concede — e nao passa batido
00:00 +34: AUT AUT-02 a ponte devolve ERRO TIPADO, e nunca um perfil de consolo
00:00 +35: AUT AUT-03 a porta NAO tem fallback: falha de leitura derruba a chamada
00:00 +36: AUT AUT-04 a decisao da admissao e UMA, e ela e do dominio
00:00 +37: RULES RULES-01 `registrations` continua FECHADA para o cliente
00:00 +38: RULES RULES-02 `editions` continua fechada para escrita do cliente
00:00 +39: RULES RULES-03 o cliente nao escreve o proprio entitlement
00:00 +40: GRD GRD-01 os acessos admitidos da V1 continuam dois
00:00 +41: GRD GRD-02 os superseded continuam FORA do catalogo ativo
00:00 +42: GRD GRD-03 `em_revisao` continua no caminho, e o salto continua RECUSADO
00:00 +43: GRD GRD-04 `criadoPor` continua obrigatorio, e o criador nao se aprova
00:00 +44: GRD GRD-05 o jogador continua sem mover status
00:00 +45: GRD GRD-06 esta correcao nao ligou nenhum cliente de Torneios
00:00 +46: GRD GRD-07 Billing e Comunicacao NAO mudaram de resposta
00:00 +47: GRD GRD-08 a fundacao nao ganhou carteira nem fila nova
00:00 +48: All tests passed!
```
## appcheckandroid (tail)
```
00:00 +2: a ativação de App Check na porta de entrada N03 a ativação vem DEPOIS de Firebase.initializeApp
00:00 +3: a ativação de App Check na porta de entrada N04 a ativação vem ANTES de runApp
00:00 +4: a ativação de App Check na porta de entrada N05 runApp é a última instrução de main()
00:00 +5: a ativação de App Check na porta de entrada N06 a ativação tem try/catch PRÓPRIO
00:00 +6: a ativação de App Check na porta de entrada N07 o provedor é constante de compilação sobre kReleaseMode
00:00 +7: a ativação de App Check na porta de entrada N08 o release usa Play Integrity, e só ele
00:00 +8: a ativação de App Check na porta de entrada N09 a depuração usa o provedor de depuração, e só ela
00:00 +9: a ativação de App Check na porta de entrada N10 a escolha não é feita em tempo de execução
00:00 +10: a ativação de App Check na porta de entrada N11 nenhum token de depuração entra no repositório
00:00 +11: a ativação de App Check na porta de entrada N12 o fonte continua apontando para o registro de TESTE
00:00 +12: o pipeline de release aponta o registro oficial N13 o serverClientId é procurado onde ele realmente vive
00:00 +13: o pipeline de release aponta o registro oficial N14 o serverClientId NÃO é procurado em main.dart
00:00 +14: o pipeline de release aponta o registro oficial N15 o Web client existe uma vez no arquivo conferido
00:00 +15: o pipeline de release aponta o registro oficial N16 a substituição acontece, e exige exatamente uma ocorrência
00:00 +16: o pipeline de release aponta o registro oficial N17 o passo confere o próprio resultado
00:00 +17: o pipeline de release aponta o registro oficial N18 os dois appIds continuam nomeados no ambiente do workflow
00:00 +18: a recusa de atestação é neutra, e admite nova tentativa N19 o transporte não conclui nada sobre a sessão
00:00 +19: a recusa de atestação é neutra, e admite nova tentativa N20 com sessão viva, credencial-ou-atestação admite nova tentativa
00:00 +20: a recusa de atestação é neutra, e admite nova tentativa N21 sem sessão local, a recusa é terminal
00:00 +21: a recusa de atestação é neutra, e admite nova tentativa N22 soluço e desconhecido admitem, com ou sem sessão
00:00 +22: a recusa de atestação é neutra, e admite nova tentativa N23 recusa explícita e resposta inválida não admitem
00:00 +23: a recusa de atestação é neutra, e admite nova tentativa N24 o estado de falha com sessão viva oferece tentar de novo
00:00 +24: a recusa de atestação é neutra, e admite nova tentativa N25 a falha de atestação NÃO derruba a sessão
00:00 +25: a recusa de atestação é neutra, e admite nova tentativa N26 o predicado de motivo sozinho NÃO responde por atestação
00:00 +26: All tests passed!
```
## temavip (tail)
```
00:02 +33: NRG — as autoridades vizinhas ficaram fora do alcance NRG-34 catálogo e inventário não ganharam o tema
00:02 +34: NRG — as autoridades vizinhas ficaram fora do alcance NRG-35 o Billing não passou a decidir tema
00:02 +35: NRG — as autoridades vizinhas ficaram fora do alcance NRG-36 o passe de cortesia não foi ampliado
00:02 +36: NRG — as autoridades vizinhas ficaram fora do alcance NRG-37 as regras de mesa não foram tocadas pelo tema
00:02 +37: NRG — as autoridades vizinhas ficaram fora do alcance NRG-38 a superfície do tema é só a tela de Ajustes
00:02 +38: ART — a arte aprovada ART-01 o diretório tem os 28 exigidos, e nada além
00:02 +39: ART — a arte aprovada ART-02 cada arquivo confere com o SHA-256 aprovado
00:02 +40: ART — a arte aprovada ART-03 todos são WebP LOSSLESS 256x256 com alfa declarado
00:02 +41: ART — a arte aprovada ART-04 os 28 decodificam de verdade, em 256x256
00:02 +42: ART — a arte aprovada ART-05 o alfa é REAL: há pixel transparente e pixel opaco
00:02 +43: ART — a arte aprovada ART-06 nenhum é uma folha em branco
00:02 +44: ART — a arte aprovada ART-07 nenhum traz fundo branco ou xadrez embutido
00:02 +45: ART — a arte aprovada ART-08 continuam legíveis reduzidos a 18 px
00:03 +46: ART — a arte aprovada ART-09 a declaração da arte é única, e a lista de arquivos não se repete
00:03 +47: ART — a arte aprovada ART-10 a chave está ligada e o conjunto inteiro abre
00:03 +48: ART — a arte aprovada ART-11 corromper UM arquivo derruba o conjunto inteiro
00:03 +49: ART — a arte aprovada ART-12 ATIVAÇÃO: o VIP vigente recebe o Tema Real pelo caminho de produção
00:03 +50: ART — a arte aprovada ART-13 e o público continua no Padrão pelo mesmo caminho
00:03 +51: ART — a arte aprovada ART-14 nenhum dos dois temas estoura ou corta em 320/360/412 dp a 100/150/200%, e inverter a ordem não muda o resultado
00:05 +52: ART — a arte aprovada ART-16 CONTROLE: a medição enxerga estouro plantado em CADA tema, inclusive no SEGUNDO medido
00:05 +53: ART — a arte aprovada ART-15 toda pasta declarada é REALMENTE empacotada pelos montadores
00:05 +54: ART — a arte aprovada ART-17 a matriz de 108 células: zero estouro, zero corte e nenhum acionável abaixo de 48 dp
00:08 +55: ART — a arte aprovada ART-19 o saldo desce SÓ quando não cabe: ao lado em 360 dp a 100%, embaixo em 320 dp a 200%
00:08 +56: ART — a arte aprovada ART-18 a pastilha VIP continua na tela em toda a matriz, e só quando há direito
00:10 +57: All tests passed!
```
## treinosan (tail)
```
00:00 +0: SAN — a promessa economica saiu da tela de Resultado SAN-01 nenhum rotulo semantico fala em fichas
00:00 +1: SAN — a promessa economica saiu da tela de Resultado SAN-02 nenhum rotulo semantico fala em anuncio
00:00 +2: SAN — a promessa economica saiu da tela de Resultado SAN-03 nenhum rotulo semantico declara recompensa
00:00 +3: SAN — a promessa economica saiu da tela de Resultado SAN-04 nenhuma promessa proibida na fala da tela
00:00 +4: SAN — a promessa economica saiu da tela de Resultado SAN-05 nenhum botao oferece o gesto do anuncio
00:00 +5: SAN — a promessa economica saiu da tela de Resultado SAN-06 a LISTA EXATA de rotulos e a esperada
00:00 +6: SAN — a promessa economica saiu da tela de Resultado SAN-07 o texto DESENHADO tambem nao promete
00:00 +7: SAN — a promessa economica saiu da tela de Resultado SAN-08 a tela nao declara concessao por outras palavras
00:00 +8: CON — a continuidade normal do Treino permanece CON-01 montar a tela nao aciona callback nenhum
00:00 +9: CON — a continuidade normal do Treino permanece CON-02 antes do convite, o botao principal CONVIDA
00:01 +10: CON — a continuidade normal do Treino permanece CON-02b depois do convite, ele JOGA NOVAMENTE UMA vez
00:01 +11: CON — a continuidade normal do Treino permanece CON-03 "VOLTAR AO LOBBY" aciona a saida UMA vez
00:01 +12: CON — a continuidade normal do Treino permanece CON-04 "CONVIDAR" aciona a revanche UMA vez
00:01 +13: CON — a continuidade normal do Treino permanece CON-05 "+ AMIGO" leva o assento certo
00:01 +14: CON — a continuidade normal do Treino permanece CON-06 fim de rodada mantem "PROXIMA RODADA"
00:01 +15: CON — a continuidade normal do Treino permanece CON-07 o placar e o detalhamento continuam na tela
00:01 +16: EST — o falso fluxo nao volta pelo codigo nem por dependencia EST-01 a tela de Resultado nao contem simbolo do falso fluxo
00:01 +17: EST — o falso fluxo nao volta pelo codigo nem por dependencia EST-02 a Mesa de Treino nao contem simbolo do falso fluxo
00:01 +18: EST — o falso fluxo nao volta pelo codigo nem por dependencia EST-03 nenhuma promessa literal no codigo das superficies
00:01 +19: EST — o falso fluxo nao volta pelo codigo nem por dependencia EST-04 o Treino nao alcanca carteira nem economia
00:01 +20: EST — o falso fluxo nao volta pelo codigo nem por dependencia EST-05 nenhuma dependencia publicitaria no pubspec
00:01 +21: EST — o falso fluxo nao volta pelo codigo nem por dependencia EST-06 nenhum metadata publicitario no manifesto Android
00:01 +22: EST — o falso fluxo nao volta pelo codigo nem por dependencia EST-08 nenhuma concessao declarada no codigo das superficies
00:01 +23: EST — o falso fluxo nao volta pelo codigo nem por dependencia EST-07 a suite ainda aponta para os arquivos que ela guarda
00:01 +24: All tests passed!
```
## lojaa11y (tail)
```
00:02 +48: PROVA-16 · a matriz obrigatória da folha de confirmação 320 dp @ 100%
00:02 +49: PROVA-16 · a matriz obrigatória da folha de confirmação 320 dp @ 130%
00:02 +50: PROVA-16 · a matriz obrigatória da folha de confirmação 320 dp @ 150%
00:03 +51: PROVA-16 · a matriz obrigatória da folha de confirmação 320 dp @ 175%
00:03 +52: PROVA-16 · a matriz obrigatória da folha de confirmação 320 dp @ 200%
00:03 +53: PROVA-16 · a matriz obrigatória da folha de confirmação 360 dp @ 100%
00:03 +54: PROVA-16 · a matriz obrigatória da folha de confirmação 360 dp @ 130%
00:03 +55: PROVA-16 · a matriz obrigatória da folha de confirmação 360 dp @ 150%
00:03 +56: PROVA-16 · a matriz obrigatória da folha de confirmação 360 dp @ 175%
00:03 +57: PROVA-16 · a matriz obrigatória da folha de confirmação 360 dp @ 200%
00:03 +58: PROVA-16 · a matriz obrigatória da folha de confirmação 412 dp @ 100%
00:03 +59: PROVA-16 · a matriz obrigatória da folha de confirmação 412 dp @ 130%
00:03 +60: PROVA-16 · a matriz obrigatória da folha de confirmação 412 dp @ 150%
00:04 +61: PROVA-16 · a matriz obrigatória da folha de confirmação 412 dp @ 175%
00:04 +62: PROVA-16 · a matriz obrigatória da folha de confirmação 412 dp @ 200%
00:04 +63: PROVA-17 · rolagem real, e não presença na árvore a folha ganhou UMA região de rolagem, e só uma
00:04 +64: PROVA-17 · rolagem real, e não presença na árvore no pior caso, Continuar começa FORA e a rolagem o traz
00:04 +65: PROVA-17 · rolagem real, e não presença na árvore rolar NÃO inicia pagamento
00:04 +66: PROVA-17 · rolagem real, e não presença na árvore navegar por foco NÃO inicia pagamento
00:04 +67: PROVA-17 · rolagem real, e não presença na árvore cancelar depois de rolar fecha e NÃO paga
00:04 +68: PROVA-17 · rolagem real, e não presença na árvore fechar pelo "X" depois de rolar também não paga
00:04 +69: PROVA-17 · rolagem real, e não presença na árvore três toques em Continuar, depois de rolar, produzem UMA
00:04 +70: PROVA-17 · rolagem real, e não presença na árvore em tela ampla a folha NÃO rola artificialmente
00:04 +71: PROVA-17 · rolagem real, e não presença na árvore a folha de presente também rola, sem perder o "X"
00:04 +72: All tests passed!
```
## descstbl (tail)
```
  synchronized 3.4.0+1 (3.4.2 available)
  test_api 0.7.11 (0.7.14 available)
  url_launcher_android 6.3.30 (6.3.33 available)
  url_launcher_ios 6.4.1 (6.4.2 available)
  url_launcher_linux 3.2.2 (3.2.3 available)
  url_launcher_macos 3.2.5 (3.2.6 available)
  url_launcher_windows 3.1.5 (3.1.6 available)
  vector_math 2.2.0 (2.4.3 available)
  vm_service 15.2.0 (15.3.0 available)
  yaml 3.1.3 (3.1.4 available)
Got dependencies!
65 packages have newer versions incompatible with dependency constraints.
Try `flutter pub outdated` for more information.
00:00 +0: loading /home/runner/work/buraco-master-vip-app/buraco-master-vip-app/app_build/test/descoberta/apresentacao_stbl_test.dart
00:00 +0: §3.2 — A CHAVE E O RÓTULO ST-01 a tradução é exatamente a da tabela da OS
00:00 +1: §3.2 — A CHAVE E O RÓTULO ST-02 nenhum rótulo é a chave crua, e nenhum é nome inventado
00:00 +2: §3.2 — A CHAVE E O RÓTULO ST-03 o FILTRO tira o rótulo do modelo, não de um literal próprio
00:00 +3: §3.2 — A CHAVE E O RÓTULO ST-04 a chave continua sendo o que o servidor entende
00:00 +4: §14.3 — VARREDURA GLOBAL DO CÓDIGO ST-05 a chave crua não existe no CÓDIGO da apresentação
00:00 +5: §14.3 — VARREDURA GLOBAL DO CÓDIGO ST-06 dentro de lib/descoberta, só os três arquivos da fronteira
00:00 +6: §14.3 — VARREDURA GLOBAL DO CÓDIGO ST-07 a varredura ENXERGA o que deve enxergar (controle)
00:00 +7: §14.3 — NA TELA ST-08 filtros, cards e semântica dizem STBL
00:00 +8: §14.3 — NA TELA ST-09 NENHUM texto visível contém a chave crua
00:00 +9: §14.3 — NA TELA ST-10 o filtro STBL seleciona as mesas de chave `sbtl`
00:00 +10: All tests passed!
```
## descadapt (tail)
```
00:00 +12: ADAPTADOR — o que entra AD-03 os quatro assentos chegam na ordem, com livre e ocupado
00:00 +13: ADAPTADOR — o que entra AD-04 bot é ocupante e NÃO é jogador
00:00 +14: ADAPTADOR — o que entra AD-05 avatar de galeria atravessa; ausência vira nulo
00:00 +15: ADAPTADOR — o que entra AD-06 `aguardandoHaMs` vira Duration
00:00 +16: ADAPTADOR — o que NÃO entra (fail-closed) AD-07 não-mapa
00:00 +17: ADAPTADOR — o que NÃO entra (fail-closed) AD-08 esquema desconhecido
00:00 +18: ADAPTADOR — o que NÃO entra (fail-closed) AD-09 campo obrigatório ausente
00:00 +19: ADAPTADOR — o que NÃO entra (fail-closed) AD-10 campo DESCONHECIDO reprova — sobrar é tão grave quanto faltar
00:00 +20: ADAPTADOR — o que NÃO entra (fail-closed) AD-11 tipo incorreto: número que veio como texto
00:00 +21: ADAPTADOR — o que NÃO entra (fail-closed) AD-12 CHAVE PROIBIDA em qualquer profundidade
00:00 +22: ADAPTADOR — o que NÃO entra (fail-closed) AD-13 estado do motor no payload também é recusado
00:00 +23: ADAPTADOR — o que NÃO entra (fail-closed) AD-14 número negativo
00:00 +24: ADAPTADOR — o que NÃO entra (fail-closed) AD-15 capacidade diferente de quatro
00:00 +25: ADAPTADOR — o que NÃO entra (fail-closed) AD-16 vetor de assentos com tamanho errado
00:00 +26: ADAPTADOR — o que NÃO entra (fail-closed) AD-17 índice do assento que não bate com a posição
00:00 +27: ADAPTADOR — o que NÃO entra (fail-closed) AD-18 assento LIVRE carregando apelido é fantasma
00:00 +28: ADAPTADOR — o que NÃO entra (fail-closed) AD-19 modalidade desconhecida
00:00 +29: ADAPTADOR — o que NÃO entra (fail-closed) AD-20 estado de ingresso desconhecido
00:00 +30: ADAPTADOR — o que NÃO entra (fail-closed) AD-21 aritmética da mesa que não fecha
00:00 +31: ADAPTADOR — o que NÃO entra (fail-closed) AD-22 presença incoerente: público maior que o total
00:00 +32: ADAPTADOR — o que NÃO entra (fail-closed) AD-23 presença incoerente: os pedaços não somam o todo
00:00 +33: ADAPTADOR — o que NÃO entra (fail-closed) AD-24 presença incoerente: mesasPublicas discorda da lista
00:00 +34: ADAPTADOR — o que NÃO entra (fail-closed) AD-25 falta uma modalidade em porModalidade
00:00 +35: ADAPTADOR — o que NÃO entra (fail-closed) AD-26 uma recusa NÃO produz retrato pela metade
00:00 +36: All tests passed!
```
## descestado (tail)
```
00:00 +1: §7 — GERAÇÃO E REVISÃO ES-02 mesma geração e revisão MAIOR: aceita
00:00 +2: §7 — GERAÇÃO E REVISÃO ES-03 mesma geração e revisão IGUAL: descarta
00:00 +3: §7 — GERAÇÃO E REVISÃO ES-04 mesma geração e revisão MENOR: descarta
00:00 +4: §7 — GERAÇÃO E REVISÃO ES-05 RESPOSTA ATRASADA: o retrato velho não desfaz o novo
00:00 +5: §7 — GERAÇÃO E REVISÃO ES-06 GERAÇÃO DIFERENTE substitui integralmente, mesmo indo para trás
00:00 +6: §7 — GERAÇÃO E REVISÃO ES-07 TRANSPORTE ANTERIOR: descartado antes de qualquer leitura
00:00 +7: §7 — GERAÇÃO E REVISÃO ES-08 retrato INVÁLIDO não substitui o válido anterior
00:00 +8: §7 — GERAÇÃO E REVISÃO ES-09 sem retrato anterior, um inválido vira estado explícito
00:00 +9: §7 — GERAÇÃO E REVISÃO ES-10 LOGOUT apaga tudo — é o único caminho que apaga
00:00 +10: §7 — GERAÇÃO E REVISÃO ES-11 TROCA A→B: nada de A sobrevive, nem por revisão alta
00:00 +11: §7 — GERAÇÃO E REVISÃO ES-12 desconhecido NÃO é zero
00:00 +12: §7 — GERAÇÃO E REVISÃO ES-13 vazio real e sem-ingressáveis são estados distintos
00:00 +13: §7 — GERAÇÃO E REVISÃO ES-14 fases de transporte preservam o retrato
00:00 +14: §7 — GERAÇÃO E REVISÃO ES-15 pedido em voo vira "carregando" só quando não há retrato
00:00 +15: §8.3 — RITMO AG-16 iniciar pede a lista e pulsa IMEDIATAMENTE
00:00 +16: §8.3 — RITMO AG-17 iniciar DUAS vezes não cria dois pares de timers
00:00 +17: §8.3 — RITMO AG-18 a lista é pedida no período, e não a cada quadro
00:00 +18: §8.3 — RITMO AG-19 o botão Atualizar respeita o piso de 1 s do servidor
00:00 +19: §8.3 — RITMO AG-20 o pulso respeita o piso de 5 s
00:00 +20: §8.3 — RITMO AG-21 o intervalo do pulso passa a ser o SUGERIDO pelo servidor
00:00 +21: §8.3 — RITMO AG-22 sugestão abaixo do piso é elevada ao piso
00:00 +22: §8.3 — RITMO AG-23 parar cancela os DOIS timers — nenhum órfão
00:00 +23: §8.3 — RITMO AG-24 depois de DESCARTAR, iniciar não religa nada
00:00 +24: §8.3 — RITMO AG-25 parar e iniciar de novo volta a pedir, sem duplicar
00:00 +25: All tests passed!
```
## desclobby (tail)
```
00:01 +19: §11.3 — INGRESSO NÃO PERTENCE A ESTA OS LB-20 sem callback, o card NÃO é botão
00:01 +20: §11.3 — INGRESSO NÃO PERTENCE A ESTA OS LB-21 o callback recebe o CÓDIGO OPACO — e nada mais
00:01 +21: §13 — ACESSIBILIDADE A11Y-22 o Voltar tem nome
00:01 +22: §13 — ACESSIBILIDADE A11Y-23 os filtros têm PAPEL e ESTADO de seleção
00:01 +23: §13 — ACESSIBILIDADE A11Y-24 o card é UMA frase, sem duplicação
00:01 +24: §13 — ACESSIBILIDADE A11Y-25 nenhum nó tocável é anônimo
00:01 +25: §13 — ACESSIBILIDADE A11Y-26 todo alvo de toque tem 48 dp ou mais
00:01 +26: §13 — ACESSIBILIDADE A11Y-27 os assentos são nomeados um a um
00:01 +27: §13 — ACESSIBILIDADE A11Y-28 a ordem de foco é a ordem da tela
00:01 +28: §14.5 — RESPONSIVIDADE RS-29 320 dp a 100%: sem estouro e com tudo alcançável
00:02 +29: §14.5 — RESPONSIVIDADE RS-29 320 dp a 130%: sem estouro e com tudo alcançável
00:02 +30: §14.5 — RESPONSIVIDADE RS-29 320 dp a 150%: sem estouro e com tudo alcançável
00:02 +31: §14.5 — RESPONSIVIDADE RS-29 320 dp a 175%: sem estouro e com tudo alcançável
00:02 +32: §14.5 — RESPONSIVIDADE RS-29 320 dp a 200%: sem estouro e com tudo alcançável
00:02 +33: §14.5 — RESPONSIVIDADE RS-29 360 dp a 100%: sem estouro e com tudo alcançável
00:02 +34: §14.5 — RESPONSIVIDADE RS-29 360 dp a 130%: sem estouro e com tudo alcançável
00:02 +35: §14.5 — RESPONSIVIDADE RS-29 360 dp a 150%: sem estouro e com tudo alcançável
00:02 +36: §14.5 — RESPONSIVIDADE RS-29 360 dp a 175%: sem estouro e com tudo alcançável
00:02 +37: §14.5 — RESPONSIVIDADE RS-29 360 dp a 200%: sem estouro e com tudo alcançável
00:02 +38: §14.5 — RESPONSIVIDADE RS-29 412 dp a 100%: sem estouro e com tudo alcançável
00:02 +39: §14.5 — RESPONSIVIDADE RS-29 412 dp a 130%: sem estouro e com tudo alcançável
00:02 +40: §14.5 — RESPONSIVIDADE RS-29 412 dp a 150%: sem estouro e com tudo alcançável
00:02 +41: §14.5 — RESPONSIVIDADE RS-29 412 dp a 175%: sem estouro e com tudo alcançável
00:02 +42: §14.5 — RESPONSIVIDADE RS-29 412 dp a 200%: sem estouro e com tudo alcançável
00:02 +43: All tests passed!
```
## deschome (tail)
```
  vector_math 2.2.0 (2.4.3 available)
  vm_service 15.2.0 (15.3.0 available)
  yaml 3.1.3 (3.1.4 available)
Got dependencies!
65 packages have newer versions incompatible with dependency constraints.
Try `flutter pub outdated` for more information.
00:00 +0: loading /home/runner/work/buraco-master-vip-app/buraco-master-vip-app/app_build/test/descoberta/presenca_na_home_test.dart
00:00 +0: §3.1 — A PRESENÇA NASCE NA HOME P0-01 partida fria autenticada: conecta, autentica e pede a lista
00:00 +1: §3.1 — A PRESENÇA NASCE NA HOME P0-02 a presença PERMANECE com a Home parada
00:00 +2: §3.1 — A PRESENÇA NASCE NA HOME P0-03 abrir e fechar rotas NÃO cria um segundo socket
00:01 +3: §3.1 — A PRESENÇA NASCE NA HOME P0-04 sair do Lobby não derruba a presença
00:01 +4: §3.1 — A PRESENÇA NASCE NA HOME P0-05 LOGIN inicia a conexão e a presença
00:01 +5: §3.1 — A PRESENÇA NASCE NA HOME P0-06 LOGOUT encerra a conexão e limpa o retrato
00:01 +6: §3.1 — A PRESENÇA NASCE NA HOME P0-07 TROCA A→B: uma transição, credencial nova, zero de A
00:02 +7: §3.1 — A PRESENÇA NASCE NA HOME P0-08 nenhuma resposta `mesas` toca a projeção da MESA
00:02 +8: §3.1 — A PRESENÇA NASCE NA HOME P0-08b o Lobby de produção NÃO envia ingresso: abre o seletor
00:02 +9: §9 — O NÚMERO DA HOME HM-09 o total vem do servidor, e é o `jogadoresOnlineTotal`
00:02 +10: §9 — O NÚMERO DA HOME HM-10 DESCONHECIDO não vira zero — a linha inteira some
00:02 +11: §9 — O NÚMERO DA HOME HM-11 ZERO REAL é exibido como zero
00:02 +12: §9 — O NÚMERO DA HOME HM-11b a TELA também omite o número quando ele é desconhecido
00:02 +13: §9 — O NÚMERO DA HOME HM-12 singular e plural
00:02 +14: §9 — O NÚMERO DA HOME HM-13 um retrato inválido não apaga o número que valia
00:02 +15: §9 — O NÚMERO DA HOME HM-14 tocar no acesso leva ao Lobby Público
00:02 +16: §9 — O NÚMERO DA HOME HM-15 nenhuma identidade é exibida no acesso
00:03 +17: All tests passed!
```
## ingrcontrato (tail)
```
00:00 +23: ESTADO — uma intenção, e nenhum assento concedido pelo cliente EI-09 RESPOSTA FORA DE ORDEM: a recusa depois do ACK não desfaz
00:00 +24: ESTADO — uma intenção, e nenhum assento concedido pelo cliente EI-10 RESPOSTA ATRASADA de outra geração é descartada
00:00 +25: ESTADO — uma intenção, e nenhum assento concedido pelo cliente EI-11 SAIR DA TELA invalida o pedido
00:00 +26: ESTADO — uma intenção, e nenhum assento concedido pelo cliente EI-12 TROCA DE CONTA apaga até confirmação não consumida
00:00 +27: ESTADO — uma intenção, e nenhum assento concedido pelo cliente EI-13 recusa TIPADA de ocupado não produz segunda tentativa
00:00 +28: ESTADO — uma intenção, e nenhum assento concedido pelo cliente EI-14 recusa de assento INVÁLIDO não altera estado local
00:00 +29: ESTADO — uma intenção, e nenhum assento concedido pelo cliente EI-15 recusas de ciclo de vida chegam SEM código e são lidas
00:00 +30: ESTADO — uma intenção, e nenhum assento concedido pelo cliente EI-16 pedido de assento INVÁLIDO nem chega a sair
00:00 +31: ESTADO — uma intenção, e nenhum assento concedido pelo cliente EI-18 ACK de geração ALHEIA é recusado na FRONTEIRA da classe
00:00 +32: ESTADO — uma intenção, e nenhum assento concedido pelo cliente EI-17 pedido AUTOMÁTICO não tem assento, e não vira assento 0
00:00 +33: §17 — REGISTRO: as suítes desta OS estão no portão RG-01 as quatro suítes do ingresso existem na árvore
00:00 +34: §17 — REGISTRO: as suítes desta OS estão no portão RG-04 a campanha de sabotagem desta OS existe e carrega mutações
00:00 +34 -1: §17 — REGISTRO: as suítes desta OS estão no portão RG-04 a campanha de sabotagem desta OS existe e carrega mutações [E]
  Expected: true
    Actual: <false>
  as provas negativas da §16 vivem nesta campanha. Sem ela, a suíte afirma o que existe e não afirma que a defesa é NECESSÁRIA.
  
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/ingresso/contrato_e_estado_test.dart 651:7     main.<fn>.<fn>
  
00:00 +34 -1: Some tests failed.

Failing tests:
  /home/runner/work/buraco-master-vip-app/buraco-master-vip-app/app_build/test/ingresso/contrato_e_estado_test.dart: §17 — REGISTRO: as suítes desta OS estão no portão RG-04 a campanha de sabotagem desta OS existe e carrega mutações
```
## ingrassento (tail)
```
00:01 +14: §11 — ESTADOS HONESTOS EA-15 a mesa SUMIU da lista: a tela diz, e não desenha velho
00:01 +15: §11 — ESTADOS HONESTOS EA-16 ainda CARREGANDO não é "mesa sumiu"
00:01 +16: §11 — ESTADOS HONESTOS EA-17 a tela mostra os números do SERVIDOR, sem recalcular
00:01 +17: §11 — ESTADOS HONESTOS EA-18 a chave do servidor NÃO aparece
00:01 +18: §11 — ESTADOS HONESTOS EA-19 nada de identidade interna atravessa para a tela
00:01 +19: §13 — ACESSIBILIDADE A11Y-20 o Voltar e o Atualizar têm nome e piso de toque
00:01 +20: §13 — ACESSIBILIDADE A11Y-21 a cadeira escolhível é BOTÃO, com ação de toque
00:01 +21: §13 — ACESSIBILIDADE A11Y-22 cada cadeira tem 48 dp de altura
00:01 +22: §13 — ACESSIBILIDADE A11Y-23 não há nó semântico DUPLICADO por cadeira
00:01 +23: §13 — ACESSIBILIDADE RS-24 320 dp a 100%: sem estouro e com tudo alcançável
00:01 +24: §13 — ACESSIBILIDADE RS-24 320 dp a 130%: sem estouro e com tudo alcançável
00:01 +25: §13 — ACESSIBILIDADE RS-24 320 dp a 150%: sem estouro e com tudo alcançável
00:01 +26: §13 — ACESSIBILIDADE RS-24 320 dp a 175%: sem estouro e com tudo alcançável
00:01 +27: §13 — ACESSIBILIDADE RS-24 320 dp a 200%: sem estouro e com tudo alcançável
00:01 +28: §13 — ACESSIBILIDADE RS-24 360 dp a 100%: sem estouro e com tudo alcançável
00:01 +29: §13 — ACESSIBILIDADE RS-24 360 dp a 130%: sem estouro e com tudo alcançável
00:01 +30: §13 — ACESSIBILIDADE RS-24 360 dp a 150%: sem estouro e com tudo alcançável
00:01 +31: §13 — ACESSIBILIDADE RS-24 360 dp a 175%: sem estouro e com tudo alcançável
00:01 +32: §13 — ACESSIBILIDADE RS-24 360 dp a 200%: sem estouro e com tudo alcançável
00:01 +33: §13 — ACESSIBILIDADE RS-24 412 dp a 100%: sem estouro e com tudo alcançável
00:01 +34: §13 — ACESSIBILIDADE RS-24 412 dp a 130%: sem estouro e com tudo alcançável
00:01 +35: §13 — ACESSIBILIDADE RS-24 412 dp a 150%: sem estouro e com tudo alcançável
00:02 +36: §13 — ACESSIBILIDADE RS-24 412 dp a 175%: sem estouro e com tudo alcançável
00:02 +37: §13 — ACESSIBILIDADE RS-24 412 dp a 200%: sem estouro e com tudo alcançável
00:02 +38: All tests passed!
```
## ingrnav (tail)
```
  url_launcher_macos 3.2.5 (3.2.6 available)
  url_launcher_windows 3.1.5 (3.1.6 available)
  vector_math 2.2.0 (2.4.3 available)
  vm_service 15.2.0 (15.3.0 available)
  yaml 3.1.3 (3.1.4 available)
Got dependencies!
65 packages have newer versions incompatible with dependency constraints.
Try `flutter pub outdated` for more information.
00:00 +0: loading /home/runner/work/buraco-master-vip-app/buraco-master-vip-app/app_build/test/ingresso/navegacao_ingresso_test.dart
00:00 +0: §2 · §12 — O CAMINHO NV-01 Lobby → card → SELETOR DE ASSENTO (e não a mesa)
00:01 +1: §2 · §12 — O CAMINHO NV-02 mesa EM ANDAMENTO: o card nem é botão
00:01 +2: §2 · §12 — O CAMINHO NV-03 o toque na cadeira manda o pedido — e SÓ ele
00:01 +3: §8.2 · §15.4 — NAVEGAÇÃO SÓ DEPOIS DO ACK NV-04 pedido em voo NÃO navega
00:01 +4: §8.2 · §15.4 — NAVEGAÇÃO SÓ DEPOIS DO ACK NV-05 ACK positivo navega UMA vez, para a mesa
00:02 +5: §8.2 · §15.4 — NAVEGAÇÃO SÓ DEPOIS DO ACK NV-06 ACK DUPLICADO não empilha um segundo destino
00:02 +6: §8.2 · §15.4 — NAVEGAÇÃO SÓ DEPOIS DO ACK NV-07 o DESTINO recebe a mesa e o assento CONFIRMADOS
00:02 +7: §8.2 · §15.4 — NAVEGAÇÃO SÓ DEPOIS DO ACK NV-08 a RECUSA não navega, e a pessoa fica no seletor
00:03 +8: §8.2 · §15.4 — NAVEGAÇÃO SÓ DEPOIS DO ACK NV-09 depois da recusa, a pessoa escolhe OUTRA cadeira
00:03 +9: §8.2 · §15.4 — NAVEGAÇÃO SÓ DEPOIS DO ACK NV-10 SAIR do seletor invalida o pedido: o ACK tardio não navega
00:03 +10: §8.2 · §15.4 — NAVEGAÇÃO SÓ DEPOIS DO ACK NV-15 sair do seletor LIBERA a próxima escolha
00:03 +11: §8.2 · §15.4 — NAVEGAÇÃO SÓ DEPOIS DO ACK NV-11 TROCA DE CONTA no meio do pedido não navega
00:04 +12: §8.2 · §15.4 — NAVEGAÇÃO SÓ DEPOIS DO ACK NV-12 SESSÃO ENCERRADA não navega
00:04 +13: §14 — O QUE A INTERFACE NÃO MOSTRA NV-13 zero identidade interna na tela do seletor
00:04 +14: §14 — O QUE A INTERFACE NÃO MOSTRA NV-14 o ingresso NÃO toca a projeção da descoberta
00:04 +15: All tests passed!
```
## ingrtransp (tail)
```
00:00 +0: loading /home/runner/work/buraco-master-vip-app/buraco-master-vip-app/app_build/test/ingresso/transporte_ingresso_test.dart
00:00 +0: §8.1 — O QUE SAI NO FIO TR-01 o pedido EXPLÍCITO leva o assento escolhido
00:00 +1: §8.1 — O QUE SAI NO FIO TR-02 o ingresso AUTOMÁTICO OMITE a chave `assento`
00:00 +2: §8.1 — O QUE SAI NO FIO TR-03 nenhuma mensagem carrega identidade interna
00:01 +3: §8.1 — O QUE SAI NO FIO TR-04 sem conexão autenticada, NADA sai
00:01 +4: §8.1 — O QUE SAI NO FIO TR-05 o pedido NÃO fica na fila para quando a conexão voltar
00:01 +5: §8.1 — O QUE SAI NO FIO TR-06 assento fora de 0..3 nem chega a sair
00:01 +6: §8.2 — O ACK, E SÓ ELE, CONFIRMA TR-07 ACK positivo confirma o assento SOLICITADO
00:01 +7: §8.2 — O ACK, E SÓ ELE, CONFIRMA TR-08 ACK com assento DIFERENTE do pedido não confirma
00:01 +8: §8.3 · §8.4 — RECUSA TIPADA, SEM FALLBACK TR-09 ASSENTO_OCUPADO: recusa, e NENHUM segundo pedido
00:01 +9: §8.3 · §8.4 — RECUSA TIPADA, SEM FALLBACK TR-10 ASSENTO_INVALIDO: recusa tipada, sem estado local
00:01 +10: §8.3 · §8.4 — RECUSA TIPADA, SEM FALLBACK TR-11 recusa SEM código também é classificada
00:01 +11: §8.3 · §8.4 — RECUSA TIPADA, SEM FALLBACK TR-12 um `erro` SEM pedido em voo não vira recusa de ingresso
00:01 +12: §8.5 — CONCORRÊNCIA: um vencedor, e o outro NÃO é realocado TR-13 dois clientes pedem a MESMA cadeira
00:01 +13: §8.1 · §14 — TOQUE DUPLO, DUPLICATA E FORA DE ORDEM TR-14 TOQUE DUPLO manda UM pedido
00:02 +14: §8.1 · §14 — TOQUE DUPLO, DUPLICATA E FORA DE ORDEM TR-15 ACK DUPLICADO confirma uma vez só
00:02 +15: §8.1 · §14 — TOQUE DUPLO, DUPLICATA E FORA DE ORDEM TR-16 recusa FORA DE ORDEM depois do ACK não desfaz
00:02 +16: §8.1 · §14 — TOQUE DUPLO, DUPLICATA E FORA DE ORDEM TR-17 ACK de OUTRA mesa não responde a este pedido
00:02 +17: §10 — RECONEXÃO E PROPRIEDADE DO ASSENTO TR-18 a reentrada automática NÃO manda preferência
00:02 +18: §10 — RECONEXÃO E PROPRIEDADE DO ASSENTO TR-19 a RECONEXÃO pode confirmar um assento diferente
00:02 +19: §10 — RECONEXÃO E PROPRIEDADE DO ASSENTO TR-20a a QUEDA do socket mata o pedido em voo
00:02 +20: §10 — RECONEXÃO E PROPRIEDADE DO ASSENTO TR-20 a queda da conexão MATA o pedido em voo
00:02 +21: §14 — TROCA DE CONTA: A NÃO ATRAVESSA PARA B TR-21 a resposta ATRASADA de A não senta B
00:02 +22: §14 — TROCA DE CONTA: A NÃO ATRAVESSA PARA B TR-22 a CONFIRMAÇÃO de A não sobrevive à troca
00:02 +23: All tests passed!
```
## encui (tail)
```
  url_launcher_windows 3.1.5 (3.1.6 available)
  vector_math 2.2.0 (2.4.3 available)
  vm_service 15.2.0 (15.3.0 available)
  yaml 3.1.3 (3.1.4 available)
Got dependencies!
65 packages have newer versions incompatible with dependency constraints.
Try `flutter pub outdated` for more information.
00:00 +0: loading /home/runner/work/buraco-master-vip-app/buraco-master-vip-app/app_build/test/casca/encerramento_na_ui_test.dart
00:00 +0: uma apresentação por encerramento o primeiro eventoId terminal apresenta uma vez
00:00 +1: uma apresentação por encerramento o mesmo eventoId reenviado não apresenta de novo
00:01 +2: uma apresentação por encerramento a visão vigente reenviada na reconexão não apresenta de novo
00:01 +3: uma apresentação por encerramento um eventoId novo, de uma partida nova, apresenta de novo
00:01 +4: o efeito nasce só do ponto de saída autoritativo visão atrasada não produz efeito terminal novo
00:01 +5: o efeito nasce só do ponto de saída autoritativo visão recusada por carimbo ilegível não produz efeito
00:01 +6: o efeito nasce só do ponto de saída autoritativo o evento legado `fim`, sozinho, não apresenta nada
00:02 +7: o efeito nasce só do ponto de saída autoritativo rodada encerrada não é partida encerrada
00:02 +8: o vínculo pertence a esta tela reconstruções sucessivas não empilham assinaturas
00:02 +9: o vínculo pertence a esta tela callback do serviço anterior é inerte
00:02 +10: o vínculo pertence a esta tela callback depois do dispose é inerte
00:02 +11: o vínculo pertence a esta tela a tela não apaga a assinatura de outro dono
00:02 +12: a continuação assíncrona confere de novo consumidor ainda montado conclui o fluxo
00:02 +13: a continuação assíncrona confere de novo consumidor desmontado durante a espera não apresenta nada
00:02 +14: a continuação assíncrona confere de novo a saída oferecida pelo aviso sai pela porta de comandos
00:02 +15: o diálogo de produção o encerramento abre o aviso uma vez, sobre a mesa
00:03 +16: All tests passed!
```
## encpend (tail)
```
00:02 +13: a reivindicação volta ao livro o estouro SÍNCRONO do apresentador não consome o aviso
00:02 +14: a reivindicação volta ao livro o futuro com erro do apresentador não consome o aviso
00:02 +15: a reivindicação volta ao livro a reentrada depois do estouro apresenta o aviso
00:02 +16: a reivindicação volta ao livro o dispose impede o efeito tardio
00:02 +17: a posse é de quem reivindicou dois rebuilds não criam dois consumidores
00:03 +18: a posse é de quem reivindicou a troca de transporte cancela o proprietário anterior
00:03 +19: a posse é de quem reivindicou callback atrasado do transporte anterior não mexe no novo
00:03 +20: a posse é de quem reivindicou confirmar e liberar exigem a posse que reivindicou
00:03 +21: a posse é de quem reivindicou o dono antigo não devolve ao livro a reivindicação do novo
00:03 +22: a posse é de quem reivindicou a saída de um dono não solta a reivindicação do outro
00:03 +23: a posse é de quem reivindicou a reivindicação é exclusiva enquanto durar
00:03 +24: o encerramento sem carimbo evento legado sem consumidor permanece pendente
00:03 +25: o encerramento sem carimbo o evento legado é apresentado uma única vez ao assinar
00:03 +26: o encerramento sem carimbo a repetição legada depois da confirmação não repete
00:03 +27: estado terminal não é efeito visão terminal sem envelope de efeito não abre diálogo
00:03 +28: estado terminal não é efeito a mesa terminal redesenhada não reabre o aviso
00:03 +29: estado terminal não é efeito a apresentação agenda o próprio quadro
00:03 +30: o diálogo de produção "Ver a mesa" mantém o comportamento anterior
00:04 +31: o diálogo de produção "Sair da mesa" continua saindo pela porta de comandos
00:04 +32: o diálogo de produção o aviso não confirma consumo quando não há navegador
00:04 +33: nada disto virou global só a rota da mesa consome o efeito terminal
00:04 +34: nada disto virou global a raiz e a casca não sabem o que é encerramento
00:04 +35: nada disto virou global a apresentação pede o próprio quadro antes de agendar
00:04 +36: nada disto virou global o livro dos efeitos não é persistido em lugar nenhum
00:04 +37: All tests passed!
```
## encpendack (tail)
```
00:01 +9: B — modo legado H10 dois legados na mesma mesa colapsam num efeito
00:01 +10: B — modo legado H11 legado e carimbado não colidem entre si
00:01 +11: C — a falha adia, não perde H12 recusa devolve o efeito, e a reentrada apresenta
00:02 +12: C — a falha adia, não perde H13 cancelamento devolve o efeito, e a reentrada apresenta
00:02 +13: C — a falha adia, não perde H14 dispose ANTES do quadro devolve o efeito
00:02 +14: C — a falha adia, não perde H15 a troca de transporte devolve o efeito do transporte anterior
00:02 +15: C — a falha adia, não perde H16 exceção SÍNCRONA do apresentador devolve o efeito
00:02 +16: C — a falha adia, não perde H17 futuro do apresentador com ERRO devolve o efeito
00:02 +17: C — a falha adia, não perde H18 quando o próprio relato estoura, o efeito já voltou a pendente
00:02 +18: C — a falha adia, não perde H19 a segunda tentativa bem-sucedida confirma UMA vez só
00:03 +19: D — posse H20 a posse antiga não confirma nem perde o efeito quando o vínculo novo já nasceu
00:03 +20: D — posse H21 confirmar e liberar exigem a MESMA posse
00:03 +21: D — posse H22 liberarTudoDe solta só o que é do dono
00:03 +22: E — idempotência e independência H23 duplicata ANTES da confirmação não abre um segundo
00:03 +23: E — idempotência e independência H24 dois eventos distintos são apresentados e não colidem
00:03 +24: E — idempotência e independência H25 dois eventos no MESMO quadro saem ambos, em ordem
00:03 +25: E — idempotência e independência H26 um evento recusado não contamina o outro
00:03 +26: E — idempotência e independência H27 sair da mesa zera o livro; a próxima mesa é outra
00:03 +27: E — idempotência e independência H28 dois transportes têm livros independentes
00:03 +28: F — assinatura H29 reconstruções repetidas não criam assinatura a mais
00:04 +29: F — assinatura H30 a ausência temporária de tela não descarta o evento
00:04 +30: F — assinatura H31 a assinatura não é escrita dentro de build()
00:04 +31: G — sem log e sem telemetria nesta camada H32 nenhum print, debugPrint, log ou telemetria direta
00:04 +32: G — sem log e sem telemetria nesta camada H33 o efeito terminal não nasce da visão, e o livro é a drenagem
00:04 +33: All tests passed!
```
## ordemvisao (tail)
```
00:00 +10: ordem 10 → 12 → 11: a atrasada é descartada e não move o marcador
00:00 +11: ordem duplicata exata não reaplica
00:00 +12: ordem mesma versão com outro eventoId não substitui o estado
00:00 +13: ordem metadados malformados não contaminam o marcador nem o estado
00:00 +14: ordem (0, null) é descartado sem mexer no marcador
00:00 +15: ordem a decisão nunca fabrica versão nem eventoId
00:00 +16: modo legado sem carimbo nenhum, tudo entra — é o servidor de produção de hoje
00:00 +17: modo legado visão sem carimbo DEPOIS de uma carimbada é recusada
00:00 +18: modo legado a tolerância volta quando a projeção reinicia
00:00 +19: modo legado legado e carimbado na mesma projeção: o carimbado fecha a porta
00:00 +20: escopo do marcador reiniciar a projeção aceita o reenvio da versão vigente
00:00 +21: escopo do marcador mesa nova pode começar com versão numericamente MENOR
00:00 +22: escopo do marcador dentro da MESMA geração o marcador não reinicia sozinho
00:00 +23: encerramento a visão não terminal não despacha nada
00:00 +24: encerramento um único envelope terminal aplica o snapshot E despacha o efeito
00:00 +25: encerramento encerramento retransmitido não despacha de novo
00:00 +26: encerramento o efeito NÃO é descartado só por a visão já ter sido aplicada
00:00 +27: encerramento reconexão reaplica o retrato terminal sem repetir o efeito
00:00 +28: encerramento sair da mesa libera o efeito da PRÓXIMA partida
00:00 +29: encerramento visão atrasada ou ilegível não despacha encerramento
00:00 +30: encerramento no modo legado o efeito sai uma vez, sem eventoId inventado
00:00 +31: encerramento dois encerramentos distintos despacham dois avisos
00:00 +32: versaoEstadoFinal não participa da ordenação o número de rodada do encerramento não ordena coisa nenhuma
00:00 +33: versaoEstadoFinal não participa da ordenação versaoEstadoFinal sozinho não é carimbo
00:00 +34: All tests passed!
```
## obscaptura (tail)
```
00:00 +4: porta 4 — registro explícito padrão é não fatal e aceita contexto
00:00 +5: porta 4 — registro explícito fatal e não fatal chegam classificados e separáveis
00:00 +6: deduplicação o mesmo erro por duas portas emite uma vez só
00:00 +7: deduplicação passada a janela, o mesmo erro volta a ser emitido
00:00 +8: deduplicação erros diferentes não se deduplicam entre si
00:00 +9: deduplicação severidade diferente não é o mesmo evento
00:00 +10: coletor indisponível coletor que falha ao iniciar não impede o startup
00:00 +11: coletor indisponível coletor que explode no envio não propaga o erro
00:00 +12: coletor indisponível coletor que explode SÍNCRONO também é contido
00:00 +13: coletor indisponível o erro original não é mascarado quando o coletor está quebrado
00:00 +14: coleta desligada em debug/teste sem forçar, a suíte nunca liga o coletor real
00:00 +15: coleta desligada em debug/teste a regra de autorização, ramo a ramo
00:00 +16: identidade e trilha em todo evento todo evento carrega versão, versionCode, ambiente e SHA
00:00 +17: identidade e trilha em todo evento a trilha acompanha a falha, na ordem em que aconteceu
00:00 +18: identidade e trilha em todo evento a trilha não cresce sem limite
00:00 +19: identidade e trilha em todo evento nenhum evento carrega chave que identifique jogador
00:00 +20: coletor adiado — o Firebase ainda não subiu adiado, o coletor NÃO é iniciado durante a instalação
00:00 +21: coletor adiado — o Firebase ainda não subiu o que falhar na janela é guardado e entregue depois
00:00 +22: coletor adiado — o Firebase ainda não subiu depois de ligado, evento novo vai direto
00:00 +23: coletor adiado — o Firebase ainda não subiu o buffer não cresce sem limite
00:00 +24: coletor adiado — o Firebase ainda não subiu coletor que falha ao ligar não derruba nada
00:00 +25: coletor adiado — o Firebase ainda não subiu ligar de novo, sem pendência, é inofensivo
00:00 +26: coletor adiado — o Firebase ainda não subiu sem adiar, o comportamento antigo continua valendo
00:00 +27: a instância inerte antes de instalar é segura
00:00 +28: All tests passed!
```
## obsgatilho (tail)
```
  record_use 0.6.0 (1.1.1 available)
  shared_preferences_android 2.4.23 (2.4.28 available)
  shared_preferences_foundation 2.5.6 (2.5.7 available)
  stack_trace 1.12.1 (1.12.2 available)
  synchronized 3.4.0+1 (3.4.2 available)
  test_api 0.7.11 (0.7.14 available)
  url_launcher_android 6.3.30 (6.3.33 available)
  url_launcher_ios 6.4.1 (6.4.2 available)
  url_launcher_linux 3.2.2 (3.2.3 available)
  url_launcher_macos 3.2.5 (3.2.6 available)
  url_launcher_windows 3.1.5 (3.1.6 available)
  vector_math 2.2.0 (2.4.3 available)
  vm_service 15.2.0 (15.3.0 available)
  yaml 3.1.3 (3.1.4 available)
Got dependencies!
65 packages have newer versions incompatible with dependency constraints.
Try `flutter pub outdated` for more information.
00:00 +0: loading /home/runner/work/buraco-master-vip-app/buraco-master-vip-app/app_build/test/observabilidade/gatilho_homologacao_test.dart
00:00 +0: sem o --dart-define, o gatilho está DESARMADO
00:00 +1: desarmado, armarSePedido não faz absolutamente nada
00:00 +2: o marcador sobrevive à redação
00:00 +3: a exceção tem tipo próprio, para o painel agrupar e filtrar
00:00 +4: a espera dá tempo do Crashlytics nativo iniciar
00:00 +5: a descrição avisa quando a build está armada
00:00 +6: All tests passed!
```
## obsidentidade (tail)
```
00:00 +8: identidade de build a identidade gravada por --dart-define chega ao binário
  Skip: sem --dart-define; ver docs/OBSERVABILIDADE-EVIDENCIA-V1.md
00:00 +8 ~1: manifesto reprodutível o mesmo commit e os mesmos artefatos dão bytes idênticos
00:00 +9 ~1: manifesto reprodutível a ordem de inserção das chaves não muda o resultado
00:00 +10 ~1: manifesto reprodutível outro commit dá outra impressão digital
00:00 +11 ~1: manifesto reprodutível o manifesto não carrega segredo
00:00 +12 ~1: manifesto reprodutível o manifesto contém o que a investigação precisa
00:00 +13 ~1: livro-razão de versionCode lê e escreve JSON de forma estável
00:00 +14 ~1: livro-razão de versionCode livro vazio ou texto vazio não quebram
00:00 +15 ~1: livro-razão de versionCode registrar o mesmo par (versionCode, sha) é idempotente
00:00 +16 ~1: livro-razão de versionCode novo registro entra ordenado
00:00 +17 ~1: gate de release build íntegra passa, e o exit code é 0
00:00 +18 ~1: gate de release REPROVA árvore suja
00:00 +19 ~1: gate de release REPROVA SHA ausente
00:00 +20 ~1: gate de release REPROVA versionCode repetido com outro commit
00:00 +21 ~1: gate de release ACEITA reemitir o mesmo versionCode para o MESMO commit
00:00 +22 ~1: gate de release REPROVA versionCode regressivo
00:00 +23 ~1: gate de release REPROVA versionCode inválido
00:00 +24 ~1: gate de release REPROVA artefato sem hash de 64 hex
00:00 +25 ~1: gate de release REPROVA mapa de símbolos sem hash válido
00:00 +26 ~1: gate de release REPROVA quando não há artefato para provar identidade
00:00 +27 ~1: gate de release REPROVA manifesto ausente quando artefatos são exigidos
00:00 +28 ~1: gate de release modo pré-build valida identidade sem exigir artefato
00:00 +29 ~1: gate de release acumula todas as reprovações, não para na primeira
00:00 +30 ~1: All tests passed!
```
## obsredacao (tail)
```
Got dependencies!
65 packages have newer versions incompatible with dependency constraints.
Try `flutter pub outdated` for more information.
00:00 +0: loading /home/runner/work/buraco-master-vip-app/buraco-master-vip-app/app_build/test/observabilidade/redacao_test.dart
00:00 +0: negação por forma — o segredo some mesmo sem chave por perto ID token do Firebase (JWT)
00:00 +1: negação por forma — o segredo some mesmo sem chave por perto chave de API do Google
00:00 +2: negação por forma — o segredo some mesmo sem chave por perto e-mail
00:00 +3: negação por forma — o segredo some mesmo sem chave por perto UID cru do Firebase, solto no texto
00:00 +4: negação por forma — o segredo some mesmo sem chave por perto purchaseToken da Play
00:00 +5: negação por forma — o segredo some mesmo sem chave por perto cabeçalho Authorization
00:00 +6: negação por forma — o segredo some mesmo sem chave por perto número longo (cartão/documento)
00:00 +7: negação por forma — o segredo some mesmo sem chave por perto mão privada de cartas
00:00 +8: negação por forma — o segredo some mesmo sem chave por perto client id OAuth
00:00 +9: negação por chave — o valor some porque o campo se chama assim chaves proibidas viram marca, e a linha sobrevive
00:00 +10: negação por chave — o valor some porque o campo se chama assim chave proibida esconde o valor mesmo que o valor pareça inofensivo
00:00 +11: negação por chave — o valor some porque o campo se chama assim par nomeado dentro de texto livre
00:00 +12: exceção aninhada segredo três níveis abaixo não escapa
00:00 +13: exceção aninhada ciclo de causas não trava a redação
00:00 +14: exceção aninhada erro sem campo de causa não quebra nada
00:00 +15: o que NÃO pode ser destruído SHA de commit sobrevive — é a resposta de "qual build quebrou?"
00:00 +16: o que NÃO pode ser destruído stack trace preserva pacote, arquivo e linha
00:00 +17: o que NÃO pode ser destruído stack trace ainda perde segredo embutido
00:00 +18: redigir duas vezes dá o mesmo resultado (idempotente)
00:00 +19: entrada vazia ou nula não explode
00:00 +20: All tests passed!
```
## obsredurl (tail)
```
Got dependencies!
65 packages have newer versions incompatible with dependency constraints.
Try `flutter pub outdated` for more information.
00:00 +0: loading /home/runner/work/buraco-master-vip-app/buraco-master-vip-app/app_build/test/observabilidade/redacao_url_test.dart
00:00 +0: regressão positiva — o valor de parâmetro sempre some o caso do laudo: token e uid na mesma URL
00:00 +1: regressão positiva — o valor de parâmetro sempre some não depende do nome do parâmetro — a defesa é pela posição
00:00 +2: regressão positiva — o valor de parâmetro sempre some parâmetros sensíveis, um por um
00:00 +3: regressão positiva — o valor de parâmetro sempre some fragmento também carrega credencial (OAuth implícito)
00:00 +4: regressão positiva — o valor de parâmetro sempre some todos os parâmetros somem, não só o primeiro
00:00 +5: regressão positiva — o valor de parâmetro sempre some valor percent-encoded não escapa
00:00 +6: regressão positiva — o valor de parâmetro sempre some a URL some dentro de uma exceção aninhada
00:00 +7: regressão positiva — o valor de parâmetro sempre some a URL some dentro de um valor de contexto
00:00 +8: regressão positiva — o valor de parâmetro sempre some a URL some dentro de um stack trace
00:00 +9: regressão positiva — o valor de parâmetro sempre some redigir duas vezes dá o mesmo resultado
00:00 +10: regressão negativa — o diagnóstico continua legível esquema, host e caminho sobrevivem
00:00 +11: regressão negativa — o diagnóstico continua legível o NOME do parâmetro sobrevive — saber que havia um token é legítimo
00:00 +12: regressão negativa — o diagnóstico continua legível a saída completa, fixada — o formato é contrato, não acaso
00:00 +13: regressão negativa — o diagnóstico continua legível URL sem parâmetro nenhum não é tocada
00:00 +14: regressão negativa — o diagnóstico continua legível prosa com interrogação não vira redação
00:00 +15: regressão negativa — o diagnóstico continua legível SHA de commit continua inteiro
00:00 +16: regressão negativa — o diagnóstico continua legível stack trace preserva pacote, arquivo e linha
00:00 +17: regressão negativa — o diagnóstico continua legível o manifesto de build continua sem segredos — o gate não passa a reprovar
00:00 +18: prova até o coletor — o que chega ao destino nenhuma URL sensível chega intacta ao coletor
00:00 +19: prova até o coletor — o que chega ao destino o evento montado direto por EventoFalha.de também está limpo
00:00 +20: All tests passed!
```
## mesaa11y (tail)
```
  url_launcher_ios 6.4.1 (6.4.2 available)
  url_launcher_linux 3.2.2 (3.2.3 available)
  url_launcher_macos 3.2.5 (3.2.6 available)
  url_launcher_windows 3.1.5 (3.1.6 available)
  vector_math 2.2.0 (2.4.3 available)
  vm_service 15.2.0 (15.3.0 available)
  yaml 3.1.3 (3.1.4 available)
Got dependencies!
65 packages have newer versions incompatible with dependency constraints.
Try `flutter pub outdated` for more information.
00:00 +0: loading /home/runner/work/buraco-master-vip-app/buraco-master-vip-app/app_build/test/casca/mesa_treino_a11y_test.dart
00:00 +0: o nome falável da carta (autoridade única) figuras viram palavras; números ficam para o sintetizador
00:00 +1: o nome falável da carta (autoridade única) curinga e naipe desconhecido não viram código na fala
00:00 +2: geometria visual atual (o desenho aprovado não se mexe) os três discos da lateral: 38 × 38, passo de 45, mesma coluna
00:01 +3: geometria visual atual (o desenho aprovado não se mexe) o disco de baixo termina 8 acima do rodapé, e a coluna a 4 da borda
00:01 +4: geometria visual atual (o desenho aprovado não se mexe) o HUD compacto do jogador continua com 42 e avatar de 40
00:01 +5: alvo interativo (piso de 48 onde o desenho permite) cada controle lateral tem 48 × 48, e os três não se sobrepõem
00:01 +6: alvo interativo (piso de 48 onde o desenho permite) o toque na borda da faixa aciona o controle dela
00:01 +7: alvo interativo (piso de 48 onde o desenho permite) monte, lixo e os dois mortos passam do piso
00:02 +8: semântica nó tocável nenhum fica sem nome
00:02 +9: semântica a lateral diz o nome, e o som diz o estado
00:02 +10: semântica o centro fala nome e contagem, uma vez cada
00:02 +11: semântica cada jogador é UM nó, e o avatar não vira o segundo
00:02 +12: semântica a mão fala cada carta, com posição, na ordem da mão
00:02 +13: All tests passed!
```
## a11yestados (tail)
```
00:05 +15: a entrada na mesa o foco sai do lobby removido e pousa na mesa
00:05 +16: a entrada na mesa sair da tela impede qualquer anúncio atrasado
00:05 +17: o protocolo e a partida não mudaram o fio leva exatamente as mesmas mensagens
00:06 +18: o protocolo e a partida não mudaram a queda e a volta não acrescentam mensagem nenhuma
00:06 +19: o protocolo e a partida não mudaram o assento e a reconexão continuam sendo do transporte
00:06 +20: o monte e os mortos cada pilha tem UM rótulo falável, e ele é o escrito por extenso
00:06 +21: o monte e os mortos o monte comprável é um botão com ação e com a pilha inteira de alvo
00:07 +22: o monte e os mortos as duas portas do toque compram do monte
00:07 +23: o monte e os mortos o monte que não se pode comprar não se declara botão
00:07 +24: o monte e os mortos os mortos são leitura, não controle
00:07 +25: a recusa do lobby, tentativa a tentativa a primeira recusa é região viva e não vira anúncio solto
00:08 +26: a recusa do lobby, tentativa a tentativa reconstruir não é uma recusa nova
00:08 +27: a recusa do lobby, tentativa a tentativa reemitir a mesma recusa sem tentativa nova não fala de novo
00:08 +28: a recusa do lobby, tentativa a tentativa uma TENTATIVA nova recusada pelo mesmo motivo volta a falar
00:08 +29: a recusa do lobby, tentativa a tentativa uma recusa com motivo diferente continua perceptível
00:08 +30: a recusa do lobby, tentativa a tentativa o sucesso depois da recusa não é suprimido
00:09 +31: a recusa do lobby, tentativa a tentativa sair do lobby e voltar não anuncia a recusa de antes
00:09 +32: a recusa do lobby, tentativa a tentativa a tela descartada não recebe callback atrasado
00:09 +33: a recusa do lobby, tentativa a tentativa aviso do transporte depois da volta não ressuscita a recusa antiga — e a recusa legítima seguinte ainda fala
00:09 +34: a recusa do lobby ao criar mesa a primeira recusa de criação é região viva
00:09 +35: a recusa do lobby ao criar mesa reconstruir não é uma criação nova
00:10 +36: a recusa do lobby ao criar mesa uma CRIAÇÃO nova recusada pelo mesmo motivo volta a falar
00:10 +37: a recusa do lobby ao criar mesa a criação aceita depois da recusa não é suprimida, e nada a mais vai ao fio
00:10 +38: a recusa do lobby ao criar mesa sair e voltar não anuncia a recusa de criação de antes
00:10 +39: All tests passed!
```
## a11yconf (tail)
```
00:01 +11: a árvore inteira, sem lista de controles conhecidos há exatamente nove nós de liga/desliga
00:02 +12: a árvore inteira, sem lista de controles conhecidos nenhum título de seção gruda num controle
00:02 +13: a árvore inteira, sem lista de controles conhecidos o botão de voltar continua nomeado e funcionando
00:02 +14: a árvore inteira, sem lista de controles conhecidos sair da conta continua sendo um controle nomeado
00:02 +15: a folha de escolha marca a opção corrente a opção atual sai como selecionada, e só ela
00:02 +16: a folha de escolha marca a opção corrente as outras dizem que NÃO estão selecionadas
00:02 +17: a folha de escolha marca a opção corrente a marca acompanha o valor, e não a posição na lista
00:02 +18: a folha de escolha marca a opção corrente a mão dominante também marca a opção corrente
00:02 +19: a folha de escolha marca a opção corrente escolher pelo canal semântico troca o valor e fecha
00:02 +20: a folha de escolha marca a opção corrente fechar a folha sem escolher não altera nada
00:02 +21: a folha de escolha marca a opção corrente escolher a opção que já vale não dispara alteração
00:03 +22: o toque com o dedo continua igual tocar no texto da preferência alterna
00:03 +23: o toque com o dedo continua igual tocar no próprio interruptor alterna
00:03 +24: o toque com o dedo continua igual tocar numa linha de navegação chama o destino dela
00:03 +25: o toque com o dedo continua igual tocar numa escolha abre a folha, e a opção troca o valor
00:03 +26: o toque com o dedo continua igual tocar em sair chama o único caminho de saída
00:03 +27: a superfície existe antes de qualquer conclusão sobre ela P1 — os vinte e dois controles esperados estão na árvore
00:03 +28: a superfície existe antes de qualquer conclusão sobre ela P2 — uma tela vazia reprova o piso
00:03 +29: cada controle expõe o contrato de interação inteiro I1 — todo controle acionável se declara habilitado
00:03 +30: cada controle expõe o contrato de interação inteiro I2 — todo controle acionável participa do foco de entrada
00:03 +31: cada controle expõe o contrato de interação inteiro I3 — focar pelo canal semântico move o foco DE VERDADE
00:03 +32: cada controle expõe o contrato de interação inteiro I4 — focar um controle não altera preferência nenhuma
00:03 +33: cada controle expõe o contrato de interação inteiro I5 — nenhum controle voltou a se partir em dois nós
00:03 +34: cada controle expõe o contrato de interação inteiro I6 — as opções da folha também têm habilitação e foco
00:03 +35: All tests passed!
```
