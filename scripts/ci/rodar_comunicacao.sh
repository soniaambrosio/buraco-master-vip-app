#!/usr/bin/env bash
#
# EXECUTOR DO GATE `comunicacao` — a suite Flutter E a testemunha do `ESP-02`.
#
#   uso: bash scripts/ci/rodar_comunicacao.sh <suite> <testemunha> [destino]
#
# ---------------------------------------------------------------------------
# POR QUE ISTO E UM ARQUIVO, E NAO UMA FUNCAO DENTRO DO YAML
# ---------------------------------------------------------------------------
#
# Porque uma funcao escrita no `run:` de um passo nao pode ser contratada. O
# contrato de conteudo cobra digest, contagem e afirmacoes de ARQUIVOS; o que
# mora no YAML so tem a linha do `executor` conferida. Provar a composicao dos
# dois exits sobre uma copia extraida do YAML provaria a copia — e o YAML real
# poderia divergir depois, em silencio.
#
# Aqui a composicao e um arquivo versionado, com digest e exigencias proprias, e
# o workflow fica reduzido a uma chamada. A diferenca entre "a logica que eu
# testei" e "a logica que o CI executa" deixa de existir.
#
# ---------------------------------------------------------------------------
# A COMPOSICAO DOS DOIS EXITS
# ---------------------------------------------------------------------------
#
# O gate `comunicacao` passou a ter DUAS perguntas, e elas sao independentes:
#
#   1. a suite Flutter passou?            -> exit real do `flutter test`
#   2. o `ESP-02` rodou mesmo, tres vezes,
#      no arquivo declarado?              -> exit da testemunha externa
#
#   flutter 0 + testemunha 0  ->  gate 0
#   flutter 1 + testemunha 0  ->  gate 1
#   flutter 0 + testemunha 1  ->  gate 1
#   flutter 1 + testemunha 1  ->  gate 1
#
# O MARCADOR `exit_comunicacao` NAO E ESCRITO AQUI: quem o escreve e o workflow,
# a partir do exit DESTE script, como faz com todos os outros gates. Um produtor
# so, e ele visivel na linha viva do YAML.
#
# QUALQUER OUTRO CODIGO E FALHA. Um `2` da testemunha e erro de invocacao — nao
# e "nao se aplica", e muito menos aprovacao. A unica combinacao que aprova e
# zero com zero, escrita por extenso abaixo, e os dois exits saem NOMINALMENTE
# para que uma auditoria possa reconstruir a conta.

set -u

SUITE="${1:-test/comunicacao/comunicacao_test.dart}"
TESTEMUNHA="${2:-scripts/ci/testemunha_esp02.sh}"
DESTINO="${3:-.}"

JSON="$DESTINO/maquina_comunicacao.json"
LOG="$DESTINO/t_comunicacao.log"
CARIMBO="$DESTINO/carimbo_execucao"

# ---------------------------------------------------------------------------
# 1. O RELATORIO ANTERIOR MORRE ANTES DE QUALQUER COISA
# ---------------------------------------------------------------------------
#
# Um `maquina_comunicacao.json` remanescente descreveria tres `ESP-02` que nao
# rodaram nesta corrida. A testemunha ainda confere isso contra o carimbo — sao
# as duas metades, e nao uma.
rm -f "$JSON"

# O carimbo desta corrida. NAO sobrescreve o que ja existir: no CI ele e escrito
# uma vez, no passo zero, e vale para todos os gates — refaze-lo aqui tornaria
# todos os outros logs "anteriores ao carimbo".
if [ ! -f "$CARIMBO" ]; then
  date -u +%Y-%m-%dT%H:%M:%SZ > "$CARIMBO"
fi

if [ ! -f "app_build/$SUITE" ]; then
  printf 'ausente: %s\n' "$SUITE" > "$DESTINO/nao_comunicacao"
  printf 'COMUNICACAO: a suite %s nao existe no overlay\n' "$SUITE"
  exit 1
fi

if [ ! -f "$TESTEMUNHA" ]; then
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
( cd app_build && flutter test "$SUITE" --reporter expanded --file-reporter="json:$JSON" ) 2>&1 | tee "$LOG"
EX_FLUTTER="${PIPESTATUS[0]}"

# ---------------------------------------------------------------------------
# 3. A TESTEMUNHA, COMO PROCESSO EXTERNO
# ---------------------------------------------------------------------------
#
# DEPOIS do Flutter, e num processo proprio. Ela nao e um `testWidgets` dentro
# da suite: uma testemunha que roda dentro daquilo que testemunha desaparece
# junto quando a suite e esvaziada.
bash "$TESTEMUNHA" "$JSON" "$SUITE" "$CARIMBO" 2>&1 | tee -a "$LOG"
EX_TESTEMUNHA="${PIPESTATUS[0]}"

# ---------------------------------------------------------------------------
# 4. A CONTA, NOMINAL
# ---------------------------------------------------------------------------
printf 'COMUNICACAO: exit do flutter    = %s\n' "$EX_FLUTTER" | tee -a "$LOG"
printf 'COMUNICACAO: exit da testemunha = %s\n' "$EX_TESTEMUNHA" | tee -a "$LOG"

if [ "$EX_FLUTTER" = "0" ] && [ "$EX_TESTEMUNHA" = "0" ]; then
  printf 'COMUNICACAO: VERDE (flutter 0 + testemunha 0)\n' | tee -a "$LOG"
  exit 0
fi

printf 'COMUNICACAO: VERMELHO (flutter %s + testemunha %s)\n' "$EX_FLUTTER" "$EX_TESTEMUNHA" | tee -a "$LOG"
exit 1
