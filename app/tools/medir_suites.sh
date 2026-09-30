#!/usr/bin/env bash
# medir_suites.sh — roda as suítes Flutter do portão UMA POR VEZ e resume.
#
# EM SÉRIE DE PROPÓSITO. `flutter test` sem argumento roda os arquivos em
# paralelo no MESMO diretório de build, e dois deles disputando
# `build/unit_test_assets` travam sem mensagem útil — foi o que fez a medição
# global desta base parar no arquivo 229 e ficar pendurada. O CI já chama uma
# suíte por vez; isto reproduz o CI, e não o atalho.
#
# O EXIT CODE VEM DO `flutter test`, NUNCA DO PIPE.
#
# `cod=$?` depois de `x="$(cmd | tr ...)"` captura o `tr`, que sempre dá zero —
# e a medição inteira passaria a dizer `exit=0` para suíte vermelha. O relatório
# vai para arquivo primeiro; o código é lido do próprio comando.
#
# Uso: bash tools/medir_suites.sh <lista> <saida>
#   <lista>  arquivo com "chave caminho" por linha
#   <saida>  arquivo de resumo
set -u

LISTA="$1"
SAIDA="$2"
# NÃO chamar esta variável de TMP: no Windows ela É a variável de ambiente que
# aponta o diretório temporário, e o `flutter` (programa Windows) a lê. Um
# `TMP=$(mktemp)` a faz apontar para um ARQUIVO, e toda invocação morre com
# "Your system temp directory does not exist" — 27 suítes verdes reportadas
# como vermelhas.
RELATORIO="$(mktemp)"
: > "$SAIDA"

while read -r chave caminho; do
  [ -z "${chave:-}" ] && continue
  if [ ! -f "$caminho" ]; then
    echo "AUSENTE $chave $caminho" >> "$SAIDA"
    continue
  fi
  # `< /dev/null` NÃO É ZELO. Dentro de um `while read ... done < lista`, todo
  # comando do corpo herda a LISTA como entrada padrão — e o `flutter` é um
  # `.bat` que lê stdin. O resultado foi 27 suítes reportando `exit=1 pass=0`
  # enquanto cada uma delas, chamada à mão, passava. Uma medição que reprova
  # tudo é tão inútil quanto uma que aprova tudo.
  flutter test "$caminho" --reporter compact > "$RELATORIO" 2>&1 < /dev/null
  cod=$?
  bruto="$(tr '\r' '\n' < "$RELATORIO")"
  # No relatório compacto, a última linha de progresso traz "+N" (casos que
  # passaram) e, quando há falha, "-N".
  #
  # O CONTADOR É ANCORADO NO PREFIXO, e isso não é preciosismo: o formato é
  # `MM:SS +N -M: <nome do caso>`, e um nome de caso com hífen e número —
  # `LIX-23`, que existe na suíte do motor — casa com qualquer busca solta por
  # `-[0-9]+`. Na primeira medição desta OS isso reportou "23 falhas" numa
  # suíte 458/458 verde.
  ultima="$(printf '%s\n' "$bruto" | grep -E '^[0-9]{2}:[0-9]{2} \+[0-9]+' | tail -1)"
  prefixo="$(printf '%s\n' "$ultima" | sed -E 's/^([0-9]{2}:[0-9]{2} [+0-9 -]*):.*$/\1/')"
  passou="$(printf '%s\n' "$prefixo" | grep -oE '\+[0-9]+' | head -1 | tr -d '+')"
  falhou="$(printf '%s\n' "$prefixo" | grep -oE ' -[0-9]+' | head -1 | tr -d ' -')"
  printf '%s %s exit=%s pass=%s fail=%s\n' \
    "$chave" "$caminho" "$cod" "${passou:-0}" "${falhou:-0}" >> "$SAIDA"
done < "$LISTA"

rm -f "$RELATORIO"
echo "FIM" >> "$SAIDA"
