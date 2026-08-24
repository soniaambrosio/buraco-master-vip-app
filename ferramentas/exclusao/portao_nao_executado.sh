#!/usr/bin/env bash
#
# portao_nao_executado.sh — A TERCEIRA SABOTAGEM DA OS 48.
#
#   uso (a partir da raiz do repositorio):
#     bash ferramentas/exclusao/portao_nao_executado.sh
#
# ===========================================================================
# POR QUE ESTA SABOTAGEM E DIFERENTE DAS OUTRAS DEZOITO
# ===========================================================================
#
# As mutacoes de `campanha_chat_ritmo.js` atacam o CODIGO: tiram o tratamento,
# desviam o UID, trocam a classe. Todas partem do mesmo pressuposto — que a
# suite RODOU. Esta ataca o pressuposto.
#
# O modo mais barato de uma correcao parecer entregue e a suite que a prova
# nunca ser executada: o passo do CI pula, nao deixa `exit_<gate>`, e um
# agregador ingenuo le "sem reprovacao registrada" como "verde". `chatRitmo`
# entra nessa categoria por construcao — `contaemu` e o UNICO lugar onde o
# apagamento acontece de verdade, e ele depende de emulador, que e exatamente
# o tipo de passo que "pula quando o ambiente nao esta pronto".
#
# O agregador `scripts/ci/portao_os_integracao.sh` ja fecha essa porta (CI-03 no
# cabecalho dele) e ja tem teste proprio. O QUE ESTE ARQUIVO ACRESCENTA e a
# afirmacao NOMINAL sobre os dois gates desta correcao: nao basta o mecanismo
# existir — `contafn` e `contaemu` precisam estar na fonte unica, e precisam
# reprovar em cada uma das cinco formas de "nao executado".
#
# Sem esta parte, tirar `contafn` da fonte unica deixaria a campanha inteira de
# mutacao verde e sem valor nenhum: dezoito sabotagens pegas por um portao que
# o CI nao percorre.

set -u

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FONTE="$RAIZ/scripts/ci/gates_os_integracao.txt"
AGREGADOR="$RAIZ/scripts/ci/portao_os_integracao.sh"

GATES_DESTA_OS="contafn contaemu"

falhas=0
casos=0

ok()   { casos=$((casos + 1)); printf '  OK    %s\n' "$1"; }
nok()  { casos=$((casos + 1)); falhas=$((falhas + 1)); printf '  FALHA %s\n' "$1"; }

# ---------------------------------------------------------------------------
# Monta um diretorio de resultados com TODOS os gates verdes.
# ---------------------------------------------------------------------------
# A VARIAVEL DE LACO E `local`, E NAO POR ESTILO: sem isso o `read -r gate`
# desta funcao sobrescreve o `gate` do laco de fora, e cada caso passa a montar
# o arquivo `exit_` de um gate de nome VAZIO. O agregador entao nunca ve o gate
# sabotado, aprova, e o arnes relata dez sobreviventes que nao existem — um
# laudo mentiroso nas duas direcoes.
montar_verde() {
  local dir="$1"
  local g
  rm -rf "$dir"
  mkdir -p "$dir"
  while IFS= read -r g; do
    printf '0\n' > "$dir/exit_$g"
  done < <(bash "$AGREGADOR" --listar "$FONTE")
}

veredito() {
  bash "$AGREGADOR" "$FONTE" "$1" >/dev/null 2>&1
  printf '%s' "$?"
}

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

printf '%s\n' "=============================================================================="
printf '%s\n' "SABOTAGEM: 'NAO EXECUTADO' tratado como verde"
printf '%s\n' "=============================================================================="

# ---------------------------------------------------------------------------
# 0. Os dois gates existem na fonte unica.
# ---------------------------------------------------------------------------
lista="$(bash "$AGREGADOR" --listar "$FONTE")"
for gate in $GATES_DESTA_OS; do
  if printf '%s\n' "$lista" | grep -qx "$gate"; then
    ok "'$gate' esta na fonte unica de gates obrigatorios"
  else
    nok "'$gate' NAO esta na fonte unica: a campanha de mutacao nao guarda nada"
  fi
done

# ---------------------------------------------------------------------------
# 1. Cerco: com tudo verde, o agregador aprova.
# ---------------------------------------------------------------------------
dir="$TMP/base"
montar_verde "$dir"
if [ "$(veredito "$dir")" = "0" ]; then
  ok "com todos os gates em 0, o agregador aprova (o cerco do teste)"
else
  nok "o agregador reprova ate o caso verde — os casos abaixo nao provariam nada"
fi

# ---------------------------------------------------------------------------
# 2. As cinco formas de 'nao executado', para cada gate desta OS.
# ---------------------------------------------------------------------------
for gate in $GATES_DESTA_OS; do
  printf '%s\n' "-- $gate"

  # (a) o passo pulou e deixou o marcador de nao-execucao
  dir="$TMP/nao_$gate"
  montar_verde "$dir"
  rm -f "$dir/exit_$gate"
  printf 'emulador indisponivel\n' > "$dir/nao_$gate"
  if [ "$(veredito "$dir")" = "1" ]; then
    ok "marcador 'nao_$gate' REPROVA"
  else
    nok "marcador 'nao_$gate' passou como verde"
  fi

  # (b) o passo sumiu sem deixar nada
  dir="$TMP/ausente_$gate"
  montar_verde "$dir"
  rm -f "$dir/exit_$gate"
  if [ "$(veredito "$dir")" = "1" ]; then
    ok "resultado AUSENTE de '$gate' REPROVA"
  else
    nok "a ausencia de resultado de '$gate' passou como verde"
  fi

  # (c) o passo escreveu um arquivo vazio
  dir="$TMP/vazio_$gate"
  montar_verde "$dir"
  : > "$dir/exit_$gate"
  if [ "$(veredito "$dir")" = "1" ]; then
    ok "exit vazio de '$gate' REPROVA"
  else
    nok "exit vazio de '$gate' passou como verde"
  fi

  # (d) o passo escreveu algo que nao e numero
  dir="$TMP/ilegivel_$gate"
  montar_verde "$dir"
  printf 'ok\n' > "$dir/exit_$gate"
  if [ "$(veredito "$dir")" = "1" ]; then
    ok "exit nao numerico de '$gate' REPROVA"
  else
    nok "exit nao numerico de '$gate' passou como verde"
  fi

  # (e) a suite rodou e reprovou
  dir="$TMP/vermelho_$gate"
  montar_verde "$dir"
  printf '1\n' > "$dir/exit_$gate"
  if [ "$(veredito "$dir")" = "1" ]; then
    ok "exit 1 de '$gate' REPROVA"
  else
    nok "exit 1 de '$gate' passou como verde"
  fi
done

printf '%s\n' "=============================================================================="
printf 'casos: %s   falhas: %s\n' "$casos" "$falhas"
if [ "$falhas" -ne 0 ]; then
  printf '%s\n' "SABOTAGEM SOBREVIVEU."
  exit 1
fi
printf '%s\n' "SABOTAGEM PEGA em todas as formas."
exit 0
