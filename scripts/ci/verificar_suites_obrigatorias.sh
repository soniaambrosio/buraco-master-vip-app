#!/usr/bin/env bash
# verificar_suites_obrigatorias.sh — impede que uma suite obrigatoria seja
# desligada em silencio.
#
# uso: verificar_suites_obrigatorias.sh <raiz_do_app> [workflow]
#
#   raiz_do_app  arvore em que as suites vivem — `app_build` no CI, `app` num
#                checkout normal.
#   workflow     opcional. Quando dado, as checagens de registro no CI tambem
#                rodam. No CI ele e sempre dado.
#
# ---------------------------------------------------------------------------
# O QUE ELE FECHA
# ---------------------------------------------------------------------------
#
# O auxiliar `roda` do workflow escreve `nao_<chave>` quando a suite nao esta
# no disco, e o portao trata isso como NAO EXECUTADO — que nao reprova. Para os
# gates que dependem de codebase opcional isso e o comportamento certo, e este
# script NAO o altera: ele nao olha os outros gates. Ele olha so a lista de
# `test/suites_obrigatorias.txt`, e para essa lista a ausencia e falha.
#
# ELE FALHA POR CONTA PROPRIA, com exit diferente de zero, em vez de depender de
# ser somado num portao la na frente. Um verificador cuja reprovacao precisa de
# outro passo para virar vermelho herda o defeito que veio consertar.
#
# ---------------------------------------------------------------------------
# ATE ONDE ELE ALCANCA
# ---------------------------------------------------------------------------
#
# Ele pega: apagar a suite, renomea-la, tirar a linha `roda` do workflow, tirar
# a chave de uma das duas listas de gate, esvaziar o manifesto e apagar o
# manifesto.
#
# Ele NAO pega quem apagar o passo que o invoca. Nenhuma verificacao dentro de
# um workflow pode cobrir a propria remocao do workflow — a raiz de confianca
# termina ali, e o que a defende e o diff, nao um script.

set -u

raiz="${1:-app_build}"
workflow="${2:-}"
manifesto="$raiz/test/suites_obrigatorias.txt"

# A chave que ESTE script existe para proteger. Escrita aqui, e nao so no
# manifesto, para que esvaziar o manifesto nao seja uma saida: o arquivo pode
# crescer com decisoes futuras, mas nao pode encolher ate zero.
readonly CHAVE_MINIMA="a11yamigos"

falhas=0
erro() {
  echo "SUITE OBRIGATORIA: $*"
  falhas=1
}

if [ ! -f "$manifesto" ]; then
  echo "SUITE OBRIGATORIA: manifesto ausente em '$manifesto'"
  exit 1
fi

conteudo_workflow=""
if [ -n "$workflow" ]; then
  if [ ! -f "$workflow" ]; then
    echo "SUITE OBRIGATORIA: workflow ausente em '$workflow'"
    exit 1
  fi
  conteudo_workflow="$(tr -d '\r' < "$workflow")"
fi

entradas=0
tem_chave_minima=0

while IFS= read -r bruta || [ -n "$bruta" ]; do
  linha="$(printf '%s' "$bruta" | tr -d '\r')"
  case "$linha" in
    '' | '#'*) continue ;;
  esac

  chave="$(printf '%s\n' "$linha" | awk '{print $1}')"
  caminho="$(printf '%s\n' "$linha" | awk '{print $2}')"
  sobra="$(printf '%s\n' "$linha" | awk '{print $3}')"

  if [ -z "$chave" ] || [ -z "$caminho" ] || [ -n "$sobra" ]; then
    erro "linha malformada no manifesto: '$linha'"
    continue
  fi

  entradas=$((entradas + 1))
  [ "$chave" = "$CHAVE_MINIMA" ] && tem_chave_minima=1

  if [ -f "$raiz/$caminho" ]; then
    echo "ok   arquivo    $chave  $raiz/$caminho"
  else
    erro "suite removida ou renomeada: '$raiz/$caminho' (gate $chave)"
  fi

  [ -z "$conteudo_workflow" ] && continue

  if printf '%s\n' "$conteudo_workflow" |
    grep -Eq "^[[:space:]]*roda[[:space:]]+$chave[[:space:]]+$caminho[[:space:]]*$"; then
    echo "ok   roda       $chave  $caminho"
  else
    erro "o workflow nao tem a linha 'roda $chave $caminho'"
  fi

  if printf '%s\n' "$conteudo_workflow" | grep -E '^[[:space:]]*GATES="' |
    grep -qw -- "$chave"; then
    echo "ok   evidencia  $chave"
  else
    erro "a chave '$chave' esta fora da lista GATES da evidencia"
  fi

  if printf '%s\n' "$conteudo_workflow" | grep -E '^[[:space:]]*for k in ' |
    grep -qw -- "$chave"; then
    echo "ok   portao     $chave"
  else
    erro "a chave '$chave' esta fora da lista do portao"
  fi
done < "$manifesto"

if [ "$entradas" -eq 0 ]; then
  erro "manifesto sem nenhuma entrada — a lista foi esvaziada"
fi

if [ "$tem_chave_minima" -eq 0 ]; then
  erro "o manifesto nao lista mais o gate '$CHAVE_MINIMA'"
fi

if [ "$falhas" -eq 0 ]; then
  echo "suites obrigatorias: $entradas conferida(s), tudo no lugar"
else
  echo "suites obrigatorias: REPROVADO"
fi

exit "$falhas"
