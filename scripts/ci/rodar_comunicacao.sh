#!/usr/bin/env bash
#
# EXECUTOR DO GATE `comunicacao` — a suite Flutter E a testemunha do `ESP-02`.
#
#   uso: bash scripts/ci/rodar_comunicacao.sh <suite> <testemunha>
#
# ---------------------------------------------------------------------------
# POR QUE ISTO E UM ARQUIVO, E NAO UMA FUNCAO DENTRO DO YAML
# ---------------------------------------------------------------------------
#
# Porque uma funcao escrita no `run:` de um passo nao pode ser contratada. O
# contrato de conteudo cobra digest, contagem e afirmacoes de ARQUIVOS; o que
# mora no YAML so tem a linha do `executor` conferida. Provar a composicao dos
# exits sobre uma copia extraida do YAML provaria a copia — e o YAML real
# poderia divergir depois, em silencio.
#
# Aqui a composicao e um arquivo versionado, com digest e exigencias proprias, e
# o workflow fica reduzido a uma chamada. A diferenca entre "a logica que eu
# testei" e "a logica que o CI executa" deixa de existir.
#
# ---------------------------------------------------------------------------
# O CAMINHO DO RELATORIO E ABSOLUTO, E NAO E ESCOLHIDO POR QUEM CHAMA (OS 40-C4)
# ---------------------------------------------------------------------------
#
# Ate a OS 40-C3 o destino era um TERCEIRO ARGUMENTO com `.` de padrao, e o
# `--file-reporter` recebia esse caminho RELATIVO. O Flutter, porem, roda dentro
# de `app_build`: `./maquina_comunicacao.json` era reinterpretado depois do `cd`
# e nascia em `app_build/maquina_comunicacao.json`, enquanto o `rm -f` e a
# testemunha continuavam olhando a raiz. A rehomologacao OS 40-R4 mediu o
# resultado — o Flutter passava 81/81, a testemunha saia com 2 por relatorio
# ausente, e o gate `comunicacao` era VERMELHO em qualquer plataforma. Um gate
# que nao tem como ficar verde no caminho oficial nao guarda nada: ele so espera
# ser afrouxado.
#
# A correcao nao e "consertar a barra". E tirar a escolha de quem chama:
#
#   * a raiz sai do PROPRIO caminho deste arquivo, e nao do diretorio corrente;
#   * o relatorio, o log, o carimbo e a marca tem caminho ABSOLUTO, resolvido
#     ANTES de qualquer troca de diretorio;
#   * o caminho entregue ao Flutter e escrito PARA O DIRETORIO EM QUE O FLUTTER
#     RODA (`app_build`), e nao para a raiz — e o mesmo arquivo, dito da posicao
#     certa;
#   * e o resultado e COBRADO no caminho absoluto. Se as duas pontas deixarem
#     de nomear o mesmo arquivo fisico, a conferencia da secao 3 reprova: a
#     igualdade e provada a cada corrida, e nao suposta.
#   * NAO HA MAIS TERCEIRO ARGUMENTO. Um destino configuravel seria o atalho de
#     bancada mais barato que existe — apontar o executor para um diretorio
#     preparado e colher VERDE sem ter rodado no caminho oficial.
#
# NAO ADIANTA ENTREGAR O ABSOLUTO AO FLUTTER, e isto foi medido: o `flutter` de
# Windows nao entende o caminho absoluto do shell POSIX desta bancada
# (`/c/...`), sai com ZERO e nao escreve relatorio nenhum. Um executor que so
# funcionasse no runner do Actions seria um executor que ninguem consegue
# exercitar antes de commitar — que e como esta linhagem perdeu tres corridas.
#
# ---------------------------------------------------------------------------
# O RELATORIO TEM DE SER DESTA INVOCACAO — AS TRES PERGUNTAS
# ---------------------------------------------------------------------------
#
# Existir nao basta, e ser recente tambem nao. Um `maquina_comunicacao.json`
# qualquer, colocado na raiz por qualquer motivo, descreveria tres `ESP-02` que
# esta corrida nao produziu. As tres perguntas, e as tres sao independentes:
#
#   1. EXISTE e nao esta vazio?  -> `[ -s ]`, depois do `rm -f` que precede o
#                                   Flutter
#   2. E ATUAL?                  -> nao pode ser anterior a `marca_comunicacao`,
#                                   escrita por ESTA invocacao antes do Flutter
#   3. PERTENCE a esta execucao? -> nomeia a suite que ESTA invocacao mandou
#                                   rodar, E o numero de casos aprovados que ele
#                                   descreve e o mesmo `+N` que o reporter
#                                   expandido gravou no log desta corrida
#
# A terceira e a que fecha o relatorio de OUTRA corrida: os dois artefatos — o
# log expandido e o relatorio de maquina — saem do MESMO processo `flutter
# test`, e um relatorio trocado por outro nao tem como concordar com o log que
# ficou. Nenhuma das tres depende de fixture: as duas evidencias sao produzidas
# aqui, nesta invocacao, pelo caminho oficial.
#
# ---------------------------------------------------------------------------
# A COMPOSICAO DOS EXITS
# ---------------------------------------------------------------------------
#
# O gate `comunicacao` tem TRES perguntas, e elas sao independentes:
#
#   1. a suite Flutter passou?             -> exit real do `flutter test`
#   2. o relatorio de maquina e DESTA
#      execucao?                           -> exit da conferencia de relatorio
#   3. o `ESP-02` rodou mesmo, tres vezes,
#      no arquivo declarado?               -> exit da testemunha externa
#
# A UNICA combinacao que aprova e zero com zero com zero, escrita por extenso
# abaixo, e os tres exits saem NOMINALMENTE para que uma auditoria possa
# reconstruir a conta.
#
# O MARCADOR `exit_comunicacao` NAO E ESCRITO AQUI: quem o escreve e o workflow,
# a partir do exit DESTE script, como faz com todos os outros gates. Um produtor
# so, e ele visivel na linha viva do YAML.
#
# QUALQUER OUTRO CODIGO E FALHA. Um `2` da testemunha e erro de invocacao — nao
# e "nao se aplica", e muito menos aprovacao.

set -u

AQUI="$(cd "$(dirname "$0")" && pwd)"
RAIZ="$(cd "$AQUI/../.." && pwd)"

SUITE="${1:-test/comunicacao/comunicacao_test.dart}"
TESTEMUNHA="${2:-scripts/ci/testemunha_esp02.sh}"

# TERCEIRO ARGUMENTO E ERRO DE INVOCACAO, e nao "destino alternativo". Ver o
# bloco do cabecalho: o destino configuravel era o atalho de bancada.
if [ "$#" -gt 2 ]; then
  printf 'COMUNICACAO: este executor nao aceita destino; o relatorio nasce e e lido em %s\n' "$RAIZ"
  exit 1
fi

# CAMINHOS ABSOLUTOS, RESOLVIDOS ANTES DE QUALQUER `cd`. E o defeito que a OS
# 40-R4 mediu: um caminho relativo aqui e reinterpretado la dentro.
JSON="$RAIZ/maquina_comunicacao.json"
LOG="$RAIZ/t_comunicacao.log"
CARIMBO="$RAIZ/carimbo_execucao"
MARCA="$RAIZ/marca_comunicacao"

# O MESMO ARQUIVO, DITO DA POSICAO DO FLUTTER. Ele roda com o diretorio corrente
# em `$RAIZ/app_build`, e `..` dali e `$RAIZ` — sempre, em qualquer plataforma.
# Quem prova que as duas pontas nomeiam o mesmo arquivo fisico e a conferencia
# da secao 3, que cobra o resultado em `$JSON`.
JSON_PARA_O_FLUTTER='../maquina_comunicacao.json'

# ---------------------------------------------------------------------------
# 1. O RELATORIO ANTERIOR MORRE ANTES DE QUALQUER COISA
# ---------------------------------------------------------------------------
#
# Um `maquina_comunicacao.json` remanescente descreveria tres `ESP-02` que nao
# rodaram nesta corrida. A testemunha ainda confere isso contra o carimbo — sao
# as duas metades, e nao uma.
rm -f "$JSON"

# A MARCA DESTA INVOCACAO, escrita depois da remocao e antes do Flutter. Tudo o
# que for anterior a ela e de outra corrida, por definicao.
date -u +%Y-%m-%dT%H:%M:%SZ > "$MARCA"

# O carimbo desta corrida. NAO sobrescreve o que ja existir: no CI ele e escrito
# uma vez, no passo zero, e vale para todos os gates — refaze-lo aqui tornaria
# todos os outros logs "anteriores ao carimbo".
if [ ! -f "$CARIMBO" ]; then
  date -u +%Y-%m-%dT%H:%M:%SZ > "$CARIMBO"
fi

if [ ! -f "$RAIZ/app_build/$SUITE" ]; then
  printf 'ausente: %s\n' "$SUITE" > "$RAIZ/nao_comunicacao"
  printf 'COMUNICACAO: a suite %s nao existe no overlay\n' "$SUITE"
  exit 1
fi

if [ ! -f "$RAIZ/$TESTEMUNHA" ]; then
  printf 'COMUNICACAO: a testemunha do ESP-02 nao existe em %s\n' "$TESTEMUNHA"
  exit 1
fi

# ---------------------------------------------------------------------------
# 2. O FLUTTER, COM OS DOIS RELATORIOS
# ---------------------------------------------------------------------------
#
# O reporter expandido continua escrevendo `t_comunicacao.log`, e e dele que a
# FASE B le o `+81`. O `--file-reporter` e ADICIONAL: ele nao troca o reporter,
# acrescenta um segundo. Trocar um pelo outro apagaria o contador que a FASE B
# cobra.
#
# O caminho do `--file-reporter` e escrito PARA O DIRETORIO EM QUE O FLUTTER
# RODA. O que o `cd` deste subshell nao pode mais fazer e reinterpretar um
# caminho escrito para OUTRO diretorio — que era o defeito.
( cd "$RAIZ/app_build" && flutter test "$SUITE" --reporter expanded --file-reporter="json:$JSON_PARA_O_FLUTTER" ) 2>&1 | tee "$LOG"
EX_FLUTTER="${PIPESTATUS[0]}"

# ---------------------------------------------------------------------------
# 3. O RELATORIO E DESTA INVOCACAO — EXISTENCIA, ATUALIDADE E PERTENCIMENTO
# ---------------------------------------------------------------------------
EX_RELATORIO=0
recusar_relatorio() {
  printf 'COMUNICACAO: %s\n' "$*" | tee -a "$LOG"
  EX_RELATORIO=1
}

if [ ! -s "$JSON" ]; then
  recusar_relatorio "o relatorio de maquina nao foi produzido em $JSON"
elif [ "$MARCA" -nt "$JSON" ]; then
  recusar_relatorio "o relatorio de maquina e ANTERIOR a esta invocacao — evidencia de outra corrida"
else
  # PERTENCIMENTO, primeira metade: o relatorio nomeia a suite que ESTA
  # invocacao mandou rodar. Um relatorio de outro arquivo nao serve de evidencia
  # sobre este.
  if ! grep -q "\"path\":\"[^\"]*$SUITE\"" "$JSON"; then
    recusar_relatorio "o relatorio de maquina nao declara a suite $SUITE — ele e de outra execucao"
  fi
  # PERTENCIMENTO, segunda metade: os dois artefatos saem do MESMO processo, e
  # tem de concordar. O log traz o `+N` do reporter expandido; o relatorio traz
  # um `testDone` aprovado e nao escondido por caso.
  APROVADOS_JSON="$(grep -c '"result":"success"' "$JSON")" || APROVADOS_JSON=0
  ESCONDIDOS_JSON="$(grep '"result":"success"' "$JSON" | grep -c '"hidden":true')" || ESCONDIDOS_JSON=0
  VISIVEIS_JSON=$((APROVADOS_JSON - ESCONDIDOS_JSON))
  PICO_LOG=0
  for n in $(grep -aoE '[+][0-9]+' "$LOG" | grep -oE '[0-9]+'); do
    [ "$n" -gt "$PICO_LOG" ] && PICO_LOG="$n"
  done
  if [ "$VISIVEIS_JSON" -ne "$PICO_LOG" ]; then
    recusar_relatorio "o relatorio descreve $VISIVEIS_JSON caso(s) aprovado(s) e o log desta corrida marcou $PICO_LOG — os dois artefatos nao sao da mesma execucao"
  fi
fi

# ---------------------------------------------------------------------------
# 4. A TESTEMUNHA, COMO PROCESSO EXTERNO
# ---------------------------------------------------------------------------
#
# DEPOIS do Flutter, e num processo proprio. Ela nao e um `testWidgets` dentro
# da suite: uma testemunha que roda dentro daquilo que testemunha desaparece
# junto quando a suite e esvaziada. E ela recebe o caminho EXATO do relatorio
# que acabou de ser produzido — o mesmo arquivo fisico, e nao um homonimo.
bash "$RAIZ/$TESTEMUNHA" "$JSON" "$SUITE" "$CARIMBO" 2>&1 | tee -a "$LOG"
EX_TESTEMUNHA="${PIPESTATUS[0]}"

# ---------------------------------------------------------------------------
# 5. A CONTA, NOMINAL
# ---------------------------------------------------------------------------
printf 'COMUNICACAO: exit do flutter    = %s\n' "$EX_FLUTTER" | tee -a "$LOG"
printf 'COMUNICACAO: exit do relatorio  = %s\n' "$EX_RELATORIO" | tee -a "$LOG"
printf 'COMUNICACAO: exit da testemunha = %s\n' "$EX_TESTEMUNHA" | tee -a "$LOG"

if [ "$EX_FLUTTER" = "0" ] && [ "$EX_RELATORIO" = "0" ] && [ "$EX_TESTEMUNHA" = "0" ]; then
  printf 'COMUNICACAO: VERDE (flutter 0 + relatorio 0 + testemunha 0)\n' | tee -a "$LOG"
  exit 0
fi

printf 'COMUNICACAO: VERMELHO (flutter %s + relatorio %s + testemunha %s)\n' \
  "$EX_FLUTTER" "$EX_RELATORIO" "$EX_TESTEMUNHA" | tee -a "$LOG"
exit 1
