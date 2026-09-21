# Evidência CI — run 24

- branch: `rc/bmv-rc1-prehom`
- commit: `8a87814fb511e0699f9969235498bfbd7698a514`
- data UTC: 2026-09-21T22:55:36Z

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
appcheckandroid VERDE          exit 0

obrigatórios: 65 | verdes: 65 | fora da fonte: 0
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
| appcheckandroid | EXECUTADO | 0 |

Fora do portão: `evidencias_visuais` exit `0` (gerador de PNG).

## flutter analyze (tail)
```
   info • Can't use a relative path to import a library in 'lib'. Try fixing the relative path or changing the import to a 'package:' import • test/mesa_orientacao_runtime_test.dart:5:8 • avoid_relative_lib_imports
   info • Can't use a relative path to import a library in 'lib'. Try fixing the relative path or changing the import to a 'package:' import • test/mesa_orientacao_runtime_test.dart:6:8 • avoid_relative_lib_imports
   info • Can't use a relative path to import a library in 'lib'. Try fixing the relative path or changing the import to a 'package:' import • test/mesa_orientacao_runtime_test.dart:7:8 • avoid_relative_lib_imports
   info • Can't use a relative path to import a library in 'lib'. Try fixing the relative path or changing the import to a 'package:' import • test/mesa_orientation_contract_test.dart:6:8 • avoid_relative_lib_imports
   info • Can't use a relative path to import a library in 'lib'. Try fixing the relative path or changing the import to a 'package:' import • test/mesa_orientation_contract_test.dart:7:8 • avoid_relative_lib_imports
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

198 issues found. (ran in 10.9s)
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
#3      main.<anonymous closure>.<anonymous closure> (file:///home/runner/work/buraco-master-vip-app/buraco-master-vip-app/app_build/test/casca/casca_producao_test.dart:645:20)
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
00:02 +24: transporte inicialização autenticada não abre socket nenhum
00:02 +25: transporte abrir o lobby conecta UMA vez, mesmo com o status mudando
00:02 +26: transporte logout fecha o socket e cancela a reconexão
00:03 +27: transporte a credencial não aparece em lugar nenhum da interface
00:03 +28: sem conexão, o ciclo automático desiste e diz isso
00:03 +29: endereço de servidor inválido é falha terminal, não tentativa
00:03 +30: All tests passed!
```
## cascaaud (tail)
```
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
00:00 +17: o portão da identidade visitada a suíte existe na árvore
00:00 +18: o portão da identidade visitada o workflow a executa e a considera no portão
00:00 +19: o portão da atestação Android a suíte existe na árvore
00:00 +20: o portão da atestação Android o workflow a executa e a considera no portão
00:00 +21: o portão da atestação Android o verificador de contrato exige o gate e não deixa o piso cair
00:00 +22: (tearDownAll)
00:00 +22: All tests passed!
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
To make this warning fatal, set WidgetController.hitTestWarningShouldBeFatal to true.


Warning: A call to tap() with finder "Found 1 widget with text "Recompensas" (ignoring all but first): [
  Text("Recompensas", inherit: true, color: Color(alpha: 0.7000, red: 1.0000, green: 1.0000, blue: 1.0000, colorSpace: ColorSpace.sRGB), size: 10.4, height: 1.1x, textAlign: center, overflow: ellipsis, maxLines: 2, dependencies: [DefaultSelectionStyle, DefaultTextStyle, MediaQuery, _ScrollableScope]),
]" derived an Offset (Offset(222.1, 437.4)) that would not hit test on the specified widget.
Maybe the widget is actually off-screen, or another widget is obscuring it, or the widget cannot receive pointer events.
The finder corresponds to this RenderBox: RenderParagraph#37ea2 relayoutBoundary=up5
The hit test result at that offset is: HitTestResult(HitTestEntry<HitTestTarget>#39e01(TextSpan(debugLabel: ((englishLike bodyMedium 2021).merge((whiteMountainView bodyMedium).apply)).merge(unknown), inherit: false, color: Color(alpha: 0.3400, red: 1.0000, green: 1.0000, blue: 1.0000, colorSpace: ColorSpace.sRGB), family: Roboto, size: 8.4, weight: 700, letterSpacing: 0.3, baseline: alphabetic, height: 1.4x, leadingDistribution: even, decoration: Color(alpha: 1.0000, red: 0.9020, green: 0.8784, blue: 0.9137, colorSpace: ColorSpace.sRGB) TextDecoration.none, "em breve")), RenderParagraph#968fb@Offset(36.6, 2.6), RenderStack#40735@Offset(36.6, 57.4), RenderPadding#78549@Offset(37.6, 58.4), RenderPointerListener#7dd14@Offset(37.6, 58.4), RenderSemanticsAnnotations#8449a@Offset(37.6, 58.4), RenderMouseRegion#c6462@Offset(37.6, 58.4), RenderSemanticsAnnotations#d4468@Offset(37.6, 58.4), _RenderInkFeatures#bbba2@Offset(37.6, 58.4), RenderPhysicalModel#62f17@Offset(37.6, 58.4), RenderRepaintBoundary#e4530@Offset(37.6, 58.4), RenderIndexedSemantics#f2b86@Offset(37.6, 58.4), RenderSliverGrid@(mainAxis: 58.38725490196077, crossAxis: 206.125), RenderSliverPadding@(mainAxis: 58.38725490196077, crossAxis: 206.125), RenderShrinkWrappingViewport#79dd5@Offset(206.1, 58.4), RenderIgnorePointer#05f0f@Offset(206.1, 58.4), RenderSemanticsAnnotations#fec4e@Offset(206.1, 58.4), RenderPointerListener#9302e@Offset(206.1, 58.4), RenderSemanticsGestureHandler#71cf1@Offset(206.1, 58.4), RenderPointerListener#3019c@Offset(206.1, 58.4), _RenderScrollSemantics#3eb8d@Offset(206.1, 58.4), RenderClipRect#4d3c7@Offset(206.1, 58.4), RenderRepaintBoundary#1eda2@Offset(206.1, 58.4), RenderIndexedSemantics#ab3ed@Offset(206.1, 58.4), RenderSliverList@(mainAxis: 429.3872549019608, crossAxis: 206.125), RenderSliverPadding@(mainAxis: 437.3872549019608, crossAxis: 222.125), RenderViewport#468d5@Offset(222.1, 437.4), RenderIgnorePointer#5258d@Offset(222.1, 437.4), RenderSemanticsAnnotations#43f52@Offset(222.1, 437.4), RenderPointerListener#8b929@Offset(222.1, 437.4), RenderSemanticsGestureHandler#d55f3@Offset(222.1, 437.4), RenderPointerListener#d5c3e@Offset(222.1, 437.4), _RenderScrollSemantics#cf11b@Offset(222.1, 437.4), RenderClipRect#d09a3@Offset(222.1, 437.4), _RenderLayoutBuilder#0b9ab@Offset(222.1, 437.4), RenderStack#03209@Offset(222.1, 437.4), RenderFlex#24b60@Offset(222.1, 437.4), RenderConstrainedBox#be6f7@Offset(222.1, 437.4), RenderPositionedBox#1920f@Offset(222.1, 437.4), RenderPadding#1d32a@Offset(222.1, 437.4), RenderDecoratedBox#8ebfa@Offset(222.1, 437.4), RenderCustomMultiChildLayoutBox#f1c55@Offset(222.1, 437.4), _RenderInkFeatures#7628c@Offset(222.1, 437.4), RenderPhysicalModel#baf61@Offset(222.1, 437.4), RenderSemanticsAnnotations#2c86c@Offset(222.1, 437.4), RenderRepaintBoundary#03fc4@Offset(222.1, 437.4), RenderIgnorePointer#91e51@Offset(222.1, 437.4), RenderAnimatedOpacity#0508e@Offset(222.1, 437.4), RenderAnimatedOpacity#116d8@Offset(222.1, 437.4), _RenderColoredBox#fb014@Offset(222.1, 437.4), RenderAnimatedOpacity#1fb3f@Offset(222.1, 437.4), RenderIgnorePointer#c0b70@Offset(222.1, 437.4), RenderAnimatedOpacity#40824@Offset(222.1, 437.4), RenderRepaintBoundary#41e58@Offset(222.1, 437.4), RenderSemanticsAnnotations#42434@Offset(222.1, 437.4), RenderOffstage#65876@Offset(222.1, 437.4), RenderSemanticsAnnotations#12d12@Offset(222.1, 437.4), _RenderTheater#873d9@Offset(222.1, 437.4), RenderAbsorbPointer#839aa@Offset(222.1, 437.4), RenderPointerListener#b8fa5@Offset(222.1, 437.4), RenderSemanticsAnnotations#bfbb5@Offset(222.1, 437.4), RenderSemanticsAnnotations#d2aa9@Offset(222.1, 437.4), RenderSemanticsAnnotations#6be1a@Offset(222.1, 437.4), RenderSemanticsAnnotations#3d4bf@Offset(222.1, 437.4), RenderTapRegionSurface#37ec8@Offset(222.1, 437.4), RenderSemanticsAnnotations#4a75a@Offset(222.1, 437.4), RenderSemanticsAnnotations#3688e@Offset(222.1, 437.4), HitTestEntry<HitTestTarget>#5ea77(_ReusableRenderView#9e1b0), HitTestEntry<HitTestTarget>#3b530(<AutomatedTestWidgetsFlutterBinding>))
#0      WidgetController._getElementPoint (package:flutter_test/src/controller.dart:2165:25)
#1      WidgetController.getCenter (package:flutter_test/src/controller.dart:1947:12)
#2      WidgetController.tap (package:flutter_test/src/controller.dart:1080:7)
#3      main.<anonymous closure> (file:///home/runner/work/buraco-master-vip-app/buraco-master-vip-app/app_build/test/casca/homologacao_casca_v2_test.dart:644:20)
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
00:00 +0: loading /home/runner/work/buraco-master-vip-app/buraco-master-vip-app/app_build/test/casca/ligacao_mesa_caracterizacao_test.dart
00:00 +0: treino Home autenticada abre Onde Jogar
00:00 +1: treino Treino abre a MesaScreen jogável de lib/mesa.dart
00:01 +2: treino Treino não abre socket e não pede credencial
00:01 +3: transporte Mesa por código usa o OnlineService da raiz
00:01 +4: transporte abrir e fechar o lobby não constrói um segundo transporte
00:01 +5: transporte logout no lobby derruba a pilha e a capacidade de jogar
00:01 +6: All tests passed!
```
## cascamesa (tail)
```
00:02 +9: a visão que não descreve uma mesa a visão mais nova atualiza a mesa
00:02 +10: a visão que não descreve uma mesa a mesma visão duas vezes não acumula nada
00:03 +11: a mão alheia não aparece só a própria mão é desenhada; das outras, a contagem
00:03 +12: a mão alheia não aparece cartas de outros assentos na visão não vazam para a tela
00:03 +13: comandos comprar do monte manda a jogada do protocolo
00:03 +14: comandos duplo toque não envia duas intenções
00:03 +15: comandos a intenção pendente aparece na tela
00:04 +16: comandos descartar exige uma carta selecionada e manda o id dela
00:04 +17: comandos baixar manda a lista de ids selecionados
00:04 +18: comandos fora da minha vez não há ação oferecida
00:04 +19: comandos recusa de regra preserva o estado autoritativo
00:05 +20: queda e retomada a queda bloqueia ações novas e avisa
00:05 +21: queda e retomada a mesa continua desenhada durante a reconexão
00:05 +22: queda e retomada a retomada substitui a mesa pela visão nova
00:05 +23: sessão e saída logout EM PARTIDA encerra a capacidade de jogar
00:05 +24: sessão e saída trocar de conta elimina a pilha e o estado visual anterior
00:05 +25: sessão e saída sair da mesa não é sair da conta
00:06 +26: sessão e saída falha terminal oferece ação explícita, sem laço
00:06 +27: desfecho o encerramento autoritativo mostra o resultado uma vez
00:06 +28: desfecho quem bateu é lido do servidor, não do placar
00:06 +29: desfecho partida encerrada sem quem bateu não anuncia vencedor
00:06 +30: desfecho encerrada a partida, nenhuma ação é oferecida
00:06 +31: nada de segredo na tela a credencial não aparece em texto nenhum da mesa
00:06 +32: nada de segredo na tela nenhuma conquista é concedida por inferência do cliente
00:06 +33: All tests passed!
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
00:01 +13: o VIP vem do backend, e só dele a Loja fechada não deixa escuta aberta
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
00:00 +38: auditoria — o literal competitivo não pode nascer no cliente nenhum arquivo do ranking imprime identificador
00:00 +39: auditoria — o literal competitivo não pode nascer no cliente só o adaptador de Firebase conhece cloud_functions
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
00:00 +20: B — a tela não promete o que o botão não cumpre B12 — a sessão realmente inválida continua sem prometer retry
00:00 +21: B — a tela não promete o que o botão não cumpre B13 — nenhum estado de falha afirma liga, nem para exibição
00:00 +22: All tests passed!
```
## composicao (tail)
```
00:00 +0: loading /home/runner/work/buraco-master-vip-app/buraco-master-vip-app/app_build/test/composicao/composicao_perfil_ranking_test.dart
00:00 +0: C1 — o Perfil próprio bebe do escopo de ranking C1 — o Perfil próprio recebe o ranking REAL do escopo
00:00 +1: C1 — o Perfil próprio bebe do escopo de ranking C2 — o ranking chega DEPOIS e a tela acompanha, sem recarregar o perfil
00:00 +2: C1 — o Perfil próprio bebe do escopo de ranking C12 — uma reconstrução não abre callable nova
00:00 +3: C1 — o Perfil próprio bebe do escopo de ranking C13 — três retries concorrentes produzem UMA chamada
00:00 +4: C1 — o Perfil próprio bebe do escopo de ranking C6 — resposta antiga, depois da troca de sessão, não aparece
00:00 +5: C1 — o Perfil próprio bebe do escopo de ranking C7 — resposta de temporada vencida não aparece
00:00 +6: C1 — o Perfil próprio bebe do escopo de ranking C3 — o visitado é escolhido SÓ pelo publicIdVisitado
00:00 +7: C1 — o Perfil próprio bebe do escopo de ranking C4 — visitado SEM alvo não chama o transporte
00:00 +8: C1 — o Perfil próprio bebe do escopo de ranking C5 — visitado SEM sessão não chama o transporte
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
TESTEMUNHA: desafio desta corrida: testemunha-4947-20260921T224413Z
TESTEMUNHA: matriz sob observacao: scripts/ci/teste_contrato_suites.sh
ok   sonda      caso inexistente T99 recusado (exit 2)
ok   reciproca  88 caso(s), mesma relacao e mesma ordem
ok   contratos  18 gate(s) contratados, conjunto exato

----------------------------------------
TESTEMUNHA: 88 caso(s) observados | 88 verde(s) | 0 vermelho(s)
TESTEMUNHA: desafio testemunha-4947-20260921T224413Z
casos ok: 88 | casos com falha: 0
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
casos ok: 105 | casos com falha: 0
AUTORIDADE DOS VERIFICADORES: VERDE
```
## billing (tail)
```
  ...
# Subtest: VARR-13 assinante com prazo VENCIDO nao recebe, mesmo com vipAtivo true
ok 413 - VARR-13 assinante com prazo VENCIDO nao recebe, mesmo com vipAtivo true
  ---
  duration_ms: 0.324939
  ...
# Subtest: VARR-14 assinante sem token nao vira pagamento, e e CONTADO
ok 414 - VARR-14 assinante sem token nao vira pagamento, e e CONTADO
  ---
  duration_ms: 0.246972
  ...
# Subtest: VARR-15 o saldo do jogador sobe uma vez por parcela, e so uma
ok 415 - VARR-15 o saldo do jogador sobe uma vez por parcela, e so uma
  ---
  duration_ms: 0.290567
  ...
1..415
# tests 415
# suites 0
# pass 415
# fail 0
# cancelled 0
# skipped 0
# todo 0
# duration_ms 1059.044167
```
## torneiosfn (tail)
```
```
## socialdom (tail)
```

> build:domain
> cd .. && dart compile js -O2 -o functions-social/lib/domain_bundle.js app/lib/social/js_bridge.dart

Compiled 10,446,208 input bytes (5,381,931 characters source) to 87,989 characters JavaScript in 0.62 seconds
```
## socialfn (tail)
```
  ---
  duration_ms: 1.650575
  type: 'suite'
  ...
# Subtest: colecoes: os tres documentos de identidade sao separados
    # Subtest: cada papel tem a sua colecao
    ok 1 - cada papel tem a sua colecao
      ---
      duration_ms: 0.18614
      ...
    1..1
ok 17 - colecoes: os tres documentos de identidade sao separados
  ---
  duration_ms: 0.284038
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
# duration_ms 96.337782
```
## socialemu (tail)
```
[36m[1mi  functions:[22m[39m Finished "southamerica-east1-aoBloquearJogador" in 7.19301ms
[36m[1mi  functions:[22m[39m Beginning execution of "southamerica-east1-aoBloquearJogador"
[90m> [39m {"desfez":false,"severity":"INFO","message":"faxina social por bloqueio"}
[36m[1mi  functions:[22m[39m Finished "southamerica-east1-aoBloquearJogador" in 7.420193ms
[36m[1mi  functions:[22m[39m Beginning execution of "southamerica-east1-aoBloquearJogador"
[90m> [39m {"desfez":false,"severity":"INFO","message":"faxina social por bloqueio"}
[36m[1mi  functions:[22m[39m Finished "southamerica-east1-aoBloquearJogador" in 7.457759ms
[36m[1mi  functions:[22m[39m Beginning execution of "southamerica-east1-aoBloquearJogador"
[90m> [39m {"desfez":false,"severity":"INFO","message":"faxina social por bloqueio"}
[36m[1mi  functions:[22m[39m Finished "southamerica-east1-aoBloquearJogador" in 9.44402ms
[36m[1mi  functions:[22m[39m Beginning execution of "southamerica-east1-aoBloquearJogador"
[90m> [39m {"desfez":false,"severity":"INFO","message":"faxina social por bloqueio"}
[36m[1mi  functions:[22m[39m Finished "southamerica-east1-aoBloquearJogador" in 8.429442ms
[36m[1mi  functions:[22m[39m Beginning execution of "southamerica-east1-aoBloquearJogador"
[90m> [39m {"desfez":false,"severity":"INFO","message":"faxina social por bloqueio"}
[36m[1mi  functions:[22m[39m Finished "southamerica-east1-aoBloquearJogador" in 7.673043ms
[36m[1mi  functions:[22m[39m Beginning execution of "southamerica-east1-aoBloquearJogador"
[90m> [39m {"desfez":false,"severity":"INFO","message":"faxina social por bloqueio"}
[36m[1mi  functions:[22m[39m Finished "southamerica-east1-aoBloquearJogador" in 7.543598ms
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
      duration_ms: 49.880961
      ...
    1..2
ok 5 - PASSE-EMU/FRONTEIRA — o que NÃO foi tocado
  ---
  duration_ms: 101.084265
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
# duration_ms 8763.285611
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
      duration_ms: 0.073511
      ...
    # Subtest: data ilegivel nao quebra a tela
    ok 7 - data ilegivel nao quebra a tela
      ---
      duration_ms: 0.071888
      ...
    1..7
ok 91 - temporada: a faixa de tempo que o cliente exibe
  ---
  duration_ms: 1.018824
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
# duration_ms 663.169317
```
## rankingint (tail)
```
    # Subtest: temporada nova e soft reset NAO trocam o publicId (§22.14 e §22.15)
    ok 3 - temporada nova e soft reset NAO trocam o publicId (§22.14 e §22.15)
      ---
      duration_ms: 485.296824
      ...
    1..3
ok 8 - integracao: encerramento, consolidacao e a temporada seguinte
  ---
  duration_ms: 932.889574
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
# duration_ms 13128.933952
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
      duration_ms: 168.425957
      ...
    1..3
ok 3 - a integracao nao mexeu no que nao e dela (§12, §13, §14)
  ---
  duration_ms: 437.903328
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
# duration_ms 10907.588794
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
      duration_ms: 0.164217
      ...
    # Subtest: a mesma denuncia reenviada (toque duplo, retry) converge
    ok 2 - a mesma denuncia reenviada (toque duplo, retry) converge
      ---
      duration_ms: 0.103295
      ...
    1..2
ok 53 - decidirSobreReserva — denuncia reaproveitada
  ---
  duration_ms: 0.408495
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
# duration_ms 317.052224
```
## chatemu (tail)
```
      ...
    1..8
ok 8 - INT-H — adaptadores da autoridade
  ---
  duration_ms: 323.135882
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
# duration_ms 8021.064583
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
# duration_ms 7600.505365

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
# Subtest: Functions sociais
ok 58 - Functions sociais # SKIP
  ---
  duration_ms: 0.204969
  type: 'suite'
  ...
1..58
# tests 290
# suites 58
# pass 290
# fail 0
# cancelled 0
# skipped 0
# todo 0
# duration_ms 10642.59809
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
      duration_ms: 0.181543
      ...
    # Subtest: qualquer outra coisa nao confere
    ok 3 - qualquer outra coisa nao confere
      ---
      duration_ms: 0.174653
      ...
    1..3
ok 18 - palavra de confirmacao
  ---
  duration_ms: 0.659463
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
# duration_ms 150.39333
```
## contaemu (tail)
```
    ok 5 - nenhuma sancao ou denuncia e apagada por consequencia
      ---
      duration_ms: 187.185626
      ...
    1..5
ok 13 - ritmo de fala do chat
  ---
  duration_ms: 958.401315
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
# duration_ms 11609.795826
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
      duration_ms: 0.246181
      ...
    # Subtest: TAX-15 cortesia nunca implica ranking, e ranking nunca implica cortesia sozinho
    ok 4 - TAX-15 cortesia nunca implica ranking, e ranking nunca implica cortesia sozinho
      ---
      duration_ms: 0.152299
      ...
    1..4
ok 29 - TAX — elegibilidade e cortesia divergem na Privada
  ---
  duration_ms: 1.063682
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
# duration_ms 230.688048
```
## economiafn (tail)
```
  ...
# Subtest: ECO-30 humano sem userId, sem assento ou participante torto invalida tudo
ok 61 - ECO-30 humano sem userId, sem assento ou participante torto invalida tudo
  ---
  duration_ms: 0.164657
  ...
# Subtest: ECO-31 O CLIENTE NAO ESCOLHE O RESULTADO: campos extras sao ignorados
ok 62 - ECO-31 O CLIENTE NAO ESCOLHE O RESULTADO: campos extras sao ignorados
  ---
  duration_ms: 0.272209
  ...
# Subtest: ECO-32 nenhum movimento sai fora dos dois valores da politica
ok 63 - ECO-32 nenhum movimento sai fora dos dois valores da politica
  ---
  duration_ms: 0.258449
  ...
1..63
# tests 63
# suites 0
# pass 63
# fail 0
# cancelled 0
# skipped 0
# todo 0
# duration_ms 95.503188
```
## proveni (tail)
```
    # Subtest: PROV-13 o predeploy de TODA codebase carrega os dois passos, na frente
    ok 2 - PROV-13 o predeploy de TODA codebase carrega os dois passos, na frente
      ---
      duration_ms: 0.329506
      ...
    # Subtest: PROV-12 toda source existe, e nenhum `ignore` exclui o carimbo
    ok 3 - PROV-12 toda source existe, e nenhum `ignore` exclui o carimbo
      ---
      duration_ms: 0.319682
      ...
    1..3
ok 3 - §16 — a arvore REAL desta composicao
  ---
  duration_ms: 1.899891
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
# duration_ms 701.097788
```
## composneg (tail)
```
    # Subtest: o gerador recusa SHA por argumento e por ambiente
    ok 1 - o gerador recusa SHA por argumento e por ambiente
      ---
      duration_ms: 49.896116
      ...
    # Subtest: nenhuma codebase pode ser implantada sem atravessar a proveniencia
    ok 2 - nenhuma codebase pode ser implantada sem atravessar a proveniencia
      ---
      duration_ms: 0.187522
      ...
    1..2
ok 16 - PN-15 — a prova de SHA aceitando valor manual
  ---
  duration_ms: 50.183148
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
# duration_ms 221.164603
```
## rkpagina (tail)
```
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
  duration_ms: 1.838668
  type: 'suite'
  ...
# Subtest: CL-11 — dado de maquete no caminho publicavel da Loja
    # Subtest: nenhum arquivo da casca de producao constroi `.mock()`
    ok 1 - nenhum arquivo da casca de producao constroi `.mock()`
      ---
      duration_ms: 3.506169
      ...
    1..1
ok 11 - CL-11 — dado de maquete no caminho publicavel da Loja
  ---
  duration_ms: 3.564677
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
# duration_ms 262.399727
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
00:02 +31: auditoria estrutural M21 nenhum literal Bronze reaparece no fecho alcançável
00:02 +32: auditoria estrutural M21b e nenhuma liga é AFIRMADA pelo caminho publicável
00:02 +33: auditoria estrutural o fecho cresceu só pelo componente previsto
00:02 +34: auditoria estrutural o Hall continua alcançável, e por um produtor de verdade
00:02 +35: auditoria estrutural nada do que a OS proíbe entrou no fecho
00:02 +36: auditoria estrutural M18 authStateChanges continua com um assinante só
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
00:01 +25: H-D identidade em movimento H-D04 logout com as telas montadas apaga o avatar na hora
00:02 +26: H-D identidade em movimento H-D05 na janela da troca A→B o avatar de A não pisca
00:02 +27: H-D identidade em movimento H-D06 resposta ATRASADA da conta A não contamina a conta B
00:02 +28: H-D identidade em movimento H-D07 válida→inválida e inválida→válida, nos dois sentidos
00:02 +29: H-D identidade em movimento H-D08 60 reconstruções de cada tela não emitem chamada
00:03 +30: H-D identidade em movimento H-D09 abrir e fechar o Perfil 6 vezes não emite chamada
00:03 +31: H-D identidade em movimento H-D11 a troca de avatar não devolve o Perfil ao esqueleto
00:03 +32: H-D identidade em movimento H-D10 falha de identidade não inventa avatar
00:03 +33: H-E auditoria estrutural (setUpAll)
00:03 +33: H-E auditoria estrutural H-E01 main.dart continua byte a byte o da base
00:03 +34: H-E auditoria estrutural H-E02 authStateChanges tem UM assinante, e é a sessão
00:03 +35: H-E auditoria estrutural H-E03 obterMinhaIdentidade é chamado de UM lugar só
00:03 +36: H-E auditoria estrutural H-E04 nem Home nem Perfil alcançam Firestore ou publicProfiles
00:03 +37: H-E auditoria estrutural H-E05 o fecho cresceu só pelo resolvedor
00:03 +38: H-E auditoria estrutural H-E06 a coroa tem UM dono NA FUNÇÃO DE AVATAR
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
00:00 +8: A visita B V8 o avatar de A NUNCA aparece no perfil de B
00:00 +9: A visita B V-cruzado os QUATRO campos são de B, ao mesmo tempo
00:00 +10: assíncrono V9 resposta atrasada de B não sobrescreve C
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
00:01 +34: N12–N13 — nada de maquete no caminho N13c — o Perfil VISITADO é construído num lugar só
00:01 +35: N12–N13 — nada de maquete no caminho N13d — a tela do ranking não tem jogador escrito dentro
00:01 +36: N12–N13 — nada de maquete no caminho (tearDownAll)
00:01 +36: N16 — o Perfil abre o ranking real N16a — a linha competitiva leva ao ranking
00:02 +37: N16 — o Perfil abre o ranking real N16b — sem callback, a linha competitiva não vira botão
00:02 +38: All tests passed!
```
## compavrank (tail)
```
00:00 +0: loading /home/runner/work/buraco-master-vip-app/buraco-master-vip-app/app_build/test/composicao/composicao_avatar_ranking_test.dart
00:00 +0: Home — as duas autoridades no mesmo cabeçalho identidade válida: o avatar vem da autoridade canônica
00:00 +1: Home — as duas autoridades no mesmo cabeçalho avatar ausente: o fallback é da autoridade, não da tela
00:00 +2: Home — as duas autoridades no mesmo cabeçalho Ranking real: a liga é exibível
00:00 +3: Home — as duas autoridades no mesmo cabeçalho Ranking provisório: a liga é omitida
00:00 +4: Home — as duas autoridades no mesmo cabeçalho sem autoridade de ranking a liga some, e o avatar fica
00:00 +5: Perfil — um VM só, enriquecido duas vezes perfil próprio: ranking E avatar presentes no mesmo VM
00:01 +6: Perfil — um VM só, enriquecido duas vezes Home e Perfil concordam no avatar E no estado competitivo
00:01 +7: Perfil — um VM só, enriquecido duas vezes avatar ausente: Home e Perfil caem no MESMO fallback
00:01 +8: Perfil — um VM só, enriquecido duas vezes perfil de terceiro: o Ranking é o do publicId visitado
00:01 +9: Perfil — um VM só, enriquecido duas vezes perfil de terceiro sem publicId não afirma ranking nenhum
00:01 +10: troca de identidade A → B nem avatar nem Ranking de A permanecem na Home
00:01 +11: troca de identidade A → B nem avatar nem Ranking de A permanecem no Perfil aberto
00:01 +12: troca de identidade A → B logout apaga o avatar e o Ranking de uma vez
00:01 +13: navegação preserva o publicId o Perfil aberto por publicId consulta AQUELE publicId
00:01 +14: navegação preserva o publicId visitar dois perfis diferentes consulta os dois ids
00:01 +15: navegação preserva o publicId abrir o próprio Perfil usa a identidade autenticada
00:01 +16: árvore produtiva a Home não decide o fallback do avatar
00:01 +17: árvore produtiva a Home não decide sozinha o que é liga de verdade
00:01 +18: árvore produtiva os dois enriquecimentos do Perfil coexistem no VM
00:01 +19: árvore produtiva a página aplica os DOIS ao mesmo Perfil
00:01 +20: árvore produtiva a autoridade do avatar continua sendo uma só
00:01 +21: All tests passed!
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
00:00 +9: C5–C11 — jogadores públicos, sem uid e sem palpite C7 o proprietário abre o próprio Perfil sem callable de terceiro
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
00:00 +0: loading /home/runner/work/buraco-master-vip-app/buraco-master-vip-app/app_build/test/amigos/descoberta_social_tela_test.dart
00:00 +0: Amigos — as listas vêm da autoridade a lista desenha quem o servidor devolveu, e emite UMA consulta
00:00 +1: Amigos — as listas vêm da autoridade nenhum nome da maquete chega à tela
00:00 +2: Amigos — as listas vêm da autoridade lista vazia CONFIRMADA diz que está vazia; carregando, não
00:00 +3: Amigos — as listas vêm da autoridade trocar de aba consulta a aba nova, e só ela
00:00 +4: Amigos — as listas vêm da autoridade o botão da aba de recebidas é o VERBO da ação
00:00 +5: busca — os botões são os do servidor, e o estado volta termo curto demais nem sai do aparelho
00:01 +6: busca — os botões são os do servidor, e o estado volta a tela desenha SÓ as ações que a autoridade ofereceu
00:01 +7: busca — os botões são os do servidor, e o estado volta adicionar reflete a vista NOVA da autoridade na mesma linha
00:01 +8: busca — os botões são os do servidor, e o estado volta busca truncada convida a refinar, e não oferece "mais"
00:01 +9: busca — os botões são os do servidor, e o estado volta recusa de termo curto vira recado sobre o TEXTO
00:01 +10: navegação — o publicId, e nunca a posição tocar num amigo abre o Perfil daquele publicId
00:01 +11: navegação — o publicId, e nunca a posição um resultado que É você abre o perfil do DONO
00:01 +12: Perfil visitado — a relação vem do social, e volta depois da ação a faixa mostra o rótulo e os botões da autoridade
00:01 +13: Perfil visitado — a relação vem do social, e volta depois da ação o perfil do DONO não tem faixa social nem consulta relação
00:01 +14: Perfil visitado — a relação vem do social, e volta depois da ação `ehMeuPerfil` VENCE um `publicIdVisitado` escrito junto
00:01 +15: Perfil visitado — a relação vem do social, e volta depois da ação remover reflete a relação nova, vinda da autoridade
00:01 +16: Perfil visitado — a relação vem do social, e volta depois da ação social fora do ar NÃO derruba o Perfil — só tira a faixa
00:01 +17: Perfil visitado — a relação vem do social, e volta depois da ação relação sem rótulo E sem ação não desenha faixa
00:01 +18: All tests passed!
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
00:04 +51: 4 — a semântica exemplar continua de pé 4g — nenhum UID na árvore — busca com resultado
00:04 +52: 4 — a semântica exemplar continua de pé 4e — nenhum anúncio duplicado — busca truncada
00:04 +53: 4 — a semântica exemplar continua de pé 4f — a ordem de foco desce a tela — busca truncada
00:04 +54: 4 — a semântica exemplar continua de pé 4g — nenhum UID na árvore — busca truncada
00:04 +55: 4 — a semântica exemplar continua de pé 4e — nenhum anúncio duplicado — falha de lista
00:05 +56: 4 — a semântica exemplar continua de pé 4f — a ordem de foco desce a tela — falha de lista
00:05 +57: 4 — a semântica exemplar continua de pé 4g — nenhum UID na árvore — falha de lista
00:05 +58: 4 — a semântica exemplar continua de pé 4e — nenhum anúncio duplicado — falha de busca
00:05 +59: 4 — a semântica exemplar continua de pé 4f — a ordem de foco desce a tela — falha de busca
00:05 +60: 4 — a semântica exemplar continua de pé 4g — nenhum UID na árvore — falha de busca
00:05 +61: 4 — a semântica exemplar continua de pé 4e — nenhum anúncio duplicado — vazio
00:05 +62: 4 — a semântica exemplar continua de pé 4f — a ordem de foco desce a tela — vazio
00:05 +63: 4 — a semântica exemplar continua de pé 4g — nenhum UID na árvore — vazio
00:05 +64: 4 — a semântica exemplar continua de pé 4e — nenhum anúncio duplicado — carregando
00:05 +65: 4 — a semântica exemplar continua de pé 4f — a ordem de foco desce a tela — carregando
00:05 +66: 4 — a semântica exemplar continua de pé 4g — nenhum UID na árvore — carregando
00:05 +67: 4 — a semântica exemplar continua de pé 4e — nenhum anúncio duplicado — fora do escopo
00:05 +68: 4 — a semântica exemplar continua de pé 4f — a ordem de foco desce a tela — fora do escopo
00:05 +69: 4 — a semântica exemplar continua de pé 4g — nenhum UID na árvore — fora do escopo
00:05 +70: 5 — vazio, carregando, erro e conteúdo 5a — vazio diz a frase da aba, e não desenha alvo de lista
00:05 +71: 5 — vazio, carregando, erro e conteúdo 5b — carregando mostra o progresso
00:05 +72: 5 — vazio, carregando, erro e conteúdo 5c — erro oferece Tentar de novo, no piso
00:05 +73: 5 — vazio, carregando, erro e conteúdo 5d — conteúdo continua desenhando quem o servidor mandou
00:05 +74: 5 — vazio, carregando, erro e conteúdo 5e — fora do escopo diz o motivo, e o Voltar continua no piso
00:05 +75: All tests passed!
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
