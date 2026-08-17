#!/usr/bin/env bash
#
# AGREGADOR FINAL do workflow `ci-os-integracao.yml`.
#
#   uso: portao_os_integracao.sh <arquivo-de-gates> <diretorio-de-resultados>
#
# Lê a fonte única `scripts/ci/gates_os_integracao.txt` e decide, sobre os
# arquivos `exit_<gate>` / `nao_<gate>` deixados pelos passos do CI, se o
# portão é VERDE ou VERMELHO.
#
# FALHA FECHADO. As três formas de ficar verde por omissão que existiam antes
# desta OS estão bloqueadas aqui, e cada uma tem caso próprio no teste
# `teste_portao_os_integracao.sh`:
#
#   CI-02  gate que roda e é ignorado  -> impossível: a lista vem da MESMA
#          fonte que a evidência publica, não de uma cópia dentro do YAML.
#   CI-03  "NÃO EXECUTADO" como sucesso -> impossível: ausência de resultado e
#          marcador `nao_<gate>` reprovam.
#   exit ilegível como sucesso          -> impossível: só o inteiro `0` passa;
#          vazio, não numérico ou arquivo ilegível reprovam.
#
# SEGURANÇA: nada vindo de arquivo é interpretado. Sem `eval`, sem expansão de
# comando sobre conteúdo, sem `source`. O motivo de um `nao_<gate>` é impresso
# com `printf '%s'`, e nome de gate fora de `[A-Za-z0-9_]` reprova a fonte
# inteira antes de virar caminho — um nome com `/` ou `..` nunca é lido.
#
# Exit codes DESTE script:
#   0  todos os gates obrigatórios verdes
#   1  ao menos um gate obrigatório reprovado
#   2  erro de uso ou fonte de gates inválida (também reprova o CI)

set -u

PROG="$(basename "$0")"

erro() { printf '%s: %s\n' "$PROG" "$1" >&2; }

arquivo_gates="${1:-}"
dir_resultados="${2:-}"

if [ -z "$arquivo_gates" ] || [ -z "$dir_resultados" ]; then
  erro "uso: $PROG <arquivo-de-gates> <diretorio-de-resultados>"
  exit 2
fi

if [ ! -f "$arquivo_gates" ] || [ ! -r "$arquivo_gates" ]; then
  erro "fonte única de gates ausente ou ilegível: $arquivo_gates"
  exit 2
fi

if [ ! -d "$dir_resultados" ]; then
  erro "diretório de resultados ausente: $dir_resultados"
  exit 2
fi

# ---------------------------------------------------------------------------
# 1. Leitura da fonte única.
# ---------------------------------------------------------------------------

gates=()
n=0

while IFS= read -r linha || [ -n "$linha" ]; do
  n=$((n + 1))
  linha="${linha%$'\r'}"
  # apara início e fim, sem tocar no miolo: espaço no meio de um nome é erro,
  # e tem que ser visto como erro.
  linha="${linha#"${linha%%[![:space:]]*}"}"
  linha="${linha%"${linha##*[![:space:]]}"}"

  [ -z "$linha" ] && continue
  case "$linha" in '#'*) continue ;; esac

  case "$linha" in
    *[!A-Za-z0-9_]*)
      erro "nome de gate inválido em $arquivo_gates linha $n"
      exit 2
      ;;
  esac

  for existente in ${gates[@]+"${gates[@]}"}; do
    if [ "$existente" = "$linha" ]; then
      erro "gate duplicado em $arquivo_gates linha $n: $linha"
      exit 2
    fi
  done

  gates+=("$linha")
done < "$arquivo_gates"

if [ "${#gates[@]}" -eq 0 ]; then
  erro "fonte única não declara nenhum gate obrigatório — portão sem lista é portão inexistente"
  exit 2
fi

eh_obrigatorio() {
  local alvo="$1" g
  for g in "${gates[@]}"; do
    [ "$g" = "$alvo" ] && return 0
  done
  return 1
}

# ---------------------------------------------------------------------------
# 2. Veredito por gate obrigatório.
# ---------------------------------------------------------------------------

printf 'portão OS Integração — fonte: %s\n' "$arquivo_gates"
printf 'resultados em: %s\n\n' "$dir_resultados"

falhou=0
verdes=0

for g in "${gates[@]}"; do
  f_exit="$dir_resultados/exit_$g"
  f_nao="$dir_resultados/nao_$g"

  # O marcador vence, mesmo que haja um exit ao lado: um gate que se declarou
  # não executado não pode ser resgatado por um resultado remanescente.
  if [ -e "$f_nao" ]; then
    motivo='marcador presente'
    if [ -f "$f_nao" ] && [ -r "$f_nao" ]; then
      # `read -d ''` lê o arquivo inteiro sem abrir subprocesso; devolve não-zero
      # no EOF, o que aqui é o caso normal e não é erro.
      cru=''
      IFS= read -r -d '' cru < "$f_nao" || :
      cru="${cru//[$'\r\n\t']/ }"
      cru="${cru:0:200}"
      [ -n "$cru" ] && motivo="$cru" || motivo='marcador vazio'
    fi
    printf '%-14s NAO EXECUTADO  ' "$g"
    printf '%s\n' "$motivo"
    falhou=1
    continue
  fi

  if [ ! -e "$f_exit" ]; then
    printf '%-14s NAO EXECUTADO  sem exit_%s e sem nao_%s — o passo não chegou a rodar\n' "$g" "$g" "$g"
    falhou=1
    continue
  fi

  if [ ! -f "$f_exit" ] || [ ! -r "$f_exit" ]; then
    printf '%-14s ILEGIVEL       exit_%s existe mas não pode ser lido\n' "$g" "$g"
    falhou=1
    continue
  fi

  bruto=''
  IFS= read -r -d '' bruto < "$f_exit" || :
  valor="${bruto//[$' \t\r\n']/}"

  if [ -z "$valor" ]; then
    printf '%-14s INVALIDO       exit_%s vazio\n' "$g" "$g"
    falhou=1
    continue
  fi

  case "$valor" in
    *[!0-9]*)
      printf '%-14s INVALIDO       exit_%s não é inteiro: ' "$g" "$g"
      printf '%s\n' "${valor:0:40}"
      falhou=1
      continue
      ;;
  esac

  if [ "$valor" = "0" ]; then
    printf '%-14s VERDE          exit 0\n' "$g"
    verdes=$((verdes + 1))
  else
    printf '%-14s VERMELHO       exit %s\n' "$g" "$valor"
    falhou=1
  fi
done

# ---------------------------------------------------------------------------
# 3. Resultados que não constam da fonte única.
#
# São informativos por construção: o laço acima percorre SOMENTE a fonte, então
# um `exit_qualquercoisa=0` nunca substitui um obrigatório ausente nem apaga um
# obrigatório vermelho. Ficam impressos para que ninguém confunda "não está no
# portão" com "não existe".
# ---------------------------------------------------------------------------

extras=0
for f in "$dir_resultados"/exit_* "$dir_resultados"/nao_*; do
  [ -f "$f" ] || continue
  base="${f##*/}"
  nome="${base#exit_}"
  nome="${nome#nao_}"
  if ! eh_obrigatorio "$nome"; then
    printf '%-14s IGNORADO       fora da fonte única (%s)\n' "$nome" "$base"
    extras=$((extras + 1))
  fi
done

# ---------------------------------------------------------------------------
# 4. Veredito.
# ---------------------------------------------------------------------------

printf '\nobrigatórios: %d | verdes: %d | fora da fonte: %d\n' \
  "${#gates[@]}" "$verdes" "$extras"

if [ "$falhou" -eq 0 ]; then
  printf 'resultado: VERDE\n'
  exit 0
fi

printf 'resultado: VERMELHO\n'
exit 1
