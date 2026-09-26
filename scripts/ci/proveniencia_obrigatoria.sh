#!/usr/bin/env bash
#
# PROVENIENCIA OBRIGATORIA — execucao EFETIVA dos gates (BMV-PUB-C1-D1-C4).
#
#   uso:
#     proveniencia_obrigatoria.sh conferir <raiz> [relatorio.tsv]
#         exige, no ambiente, os dois insumos EXTERNOS:
#           BMV_PROV_AUTORIDADE  diretorio do pacote BMV-PUB-C1-D1-C3-AUTH1-R2
#                                extraido, FORA da arvore
#           BMV_PROV_REGISTRO    registro dos pares (gate, caminho) esperados,
#                                FORA da arvore
#     proveniencia_obrigatoria.sh validar <esperados> <observados> <livro> [relatorio.tsv]
#         so a comparacao de identidade, sobre arquivos ja produzidos.
#
#   exit 0 = VERDE. Qualquer outro estado e 1 = VERMELHO, inclusive insumo
#   ausente, vazio, truncado, ilegivel ou com hash diferente do congelado.
#
# ---------------------------------------------------------------------------
# POR QUE ESTE ARQUIVO EXISTE
# ---------------------------------------------------------------------------
#
# Ate a C3 a cadeia interna — FASE A, FASE B, agregador, `autverif` — decidia
# se um gate tinha rodado olhando TEXTO: a declaracao no workflow, o executor,
# o log, o marcador `exit_<gate>`. A guarda de alcance da C3 tentou decidir, por
# leitura estatica, se a linha do executor seria alcancada. A auditoria externa
# mostrou que essa leitura tem teto: ha passos em que o texto parece certo, a
# cadeia inteira fica verde e o gate nao roda. So a autoridade de proveniencia,
# que EXECUTA o passo e observa cada `flutter test`, distinguia os dois estados
# (39/39 no controle integro, menos que isso no objeto reduzido).
#
# A regra passa a ser:
#
#     texto parece correto  +  execucao nao observada  =  FAIL
#
# e a ordem de autoridade, do mais forte para o mais fraco:
#
#     1. execucao realmente observada          (este arquivo)
#     2. integridade da autoridade externa     (este arquivo, pinos abaixo)
#     3. integridade estrutural da candidata   (autverif, cadeia)
#     4. analise textual / alcance             (verificar_contrato_suites.sh)
#
# A 4 continua existindo, como defesa AUXILIAR. Nao e mais prova final.
#
# ---------------------------------------------------------------------------
# A AUTORIDADE NAO MORA NESTA ARVORE
# ---------------------------------------------------------------------------
#
# Quem observa a execucao e `proveniencia/auth1_proveniencia.sh` do pacote
# AUTH1-R2, congelado pelo auditor, fora do repositorio. Este arquivo nao
# reimplementa a observacao: ele confere que o pacote e o congelado, executa a
# autoridade dele e depois RECALCULA a identidade dos conjuntos por conta
# propria, sem confiar no texto do veredito que ela imprime.
#
# O conjunto ESPERADO tambem vem de fora: sao os 39 pares que a propria AUTH1-R2
# registra sobre a arvore integra `e54ff4aaeed5b0a4c67c107d10a29dadfc21491b`.
# Qualquer um reproduz esses bytes a partir do commit imutavel e do pacote
# congelado. A copia `scripts/ci/proveniencia_esperada.tsv` existe para leitura
# humana e tem de ser IDENTICA ao registro externo: adulterar so a copia da
# arvore reprova.
#
# Os tres pinos abaixo moram na arvore, e uma candidata pode trocar os tres.
# Nao adianta: o registro e o pacote que ela recebe continuam os de fora, e os
# bytes deles deixam de casar com os pinos novos. Mudar o que significa 39/39
# exige mudar coisa que esta FORA da candidata.
#
# ---------------------------------------------------------------------------
# A PROVA E DE IDENTIDADE, NAO DE CONTAGEM
# ---------------------------------------------------------------------------
#
#     esperados == observados, como CONJUNTOS de pares (gate, caminho)
#     ausentes 0 ; extras 0 ; duplicados 0 ; divergentes 0
#
# `contador >= 39` nunca basta: 39 linhas com um gate duplicado e outro ausente
# tem o mesmo total e reprovam como duplicado + ausente. Uma execucao que o
# livro-razao nao liga a gate nenhum e EXTRA, nao informativa. Uma execucao com
# exit diferente de zero, sem hash, ou que o livro e a lista de observados
# contam de forma diferente e DIVERGENTE.
#
# O relatorio opcional sai em TSV com as colunas ID, ESPERADO, OBSERVADO,
# RESULTADO e EVIDENCIA, uma linha por par esperado e uma por extra.

set -u

readonly PIN_MANIFESTO='048f387e63f6630aaf6660a44eca89c1ed3e158ea346f13c036d2a33d16b8cc4'
readonly PIN_AUTORIDADE='078d1da13c3f16300cd528e93b368920786275641d22ab247897f257213f3bad'
readonly PIN_REGISTRO='bf251db35fafa00cb49990e556e7f9e1f6d416f2714043d41a689358e5c58d2e'
readonly AUTORIDADE_REL='proveniencia/auth1_proveniencia.sh'
readonly COPIA_REL='scripts/ci/proveniencia_esperada.tsv'
readonly TAB="$(printf '\t')"

falhas=0
recusa_prov() {
  printf 'PROVENIENCIA OBRIGATORIA: %s\n' "$*"
  falhas=$((falhas + 1))
}

vermelho() {
  printf 'PROVENIENCIA OBRIGATORIA: VERMELHO — %s problema(s); gate declarado nao e gate executado\n' "$falhas"
  exit 1
}

sha_de() { sha256sum "$1" | cut -d' ' -f1; }

# `insumo <arquivo> <papel> <forma>` — ausente, ilegivel, vazio, sem fim de
# linha no ultimo registro (truncado) ou com linha fora da forma: VERMELHO.
# forma `par`   : gate<TAB>caminho
# forma `livro` : EXEC<TAB>gate<TAB>caminho<TAB>exit<TAB>sha256
insumo() {
  local arq="$1" papel="$2" forma="$3" ruins
  if [ ! -e "$arq" ]; then recusa_prov "$papel ausente: $arq"; return 1; fi
  if [ ! -f "$arq" ] || [ ! -r "$arq" ]; then recusa_prov "$papel ilegivel: $arq"; return 1; fi
  if [ ! -s "$arq" ]; then recusa_prov "$papel vazio: $arq"; return 1; fi
  if [ "$(tail -c 1 "$arq" | od -An -tx1 | tr -d ' \n')" != '0a' ]; then
    recusa_prov "$papel truncado: o ultimo registro nao termina em fim de linha ($arq)"; return 1
  fi
  if [ "$forma" = par ]; then
    ruins="$(LC_ALL=C awk -F'\t' 'NF != 2 || $1 !~ /^[a-z0-9]+$/ || $2 !~ /^[^[:space:]]+$/ { n++ } END { print n + 0 }' "$arq")"
  else
    ruins="$(LC_ALL=C awk -F'\t' 'NF != 5 || $1 != "EXEC" || $3 !~ /^[^[:space:]]+$/ { n++ } END { print n + 0 }' "$arq")"
  fi
  if [ "$ruins" -ne 0 ]; then
    recusa_prov "$papel com $ruins linha(s) fora da forma '$forma' — ilegivel ou truncado ($arq)"; return 1
  fi
  return 0
}

# ---------------------------------------------------------------------------
# validar <esperados> <observados> <livro> [relatorio]
# ---------------------------------------------------------------------------
validar() {
  local esp="$1" obs="$2" livro="$3" rel="${4:-}" t
  insumo "$esp" 'conjunto esperado' par
  insumo "$obs" 'lista de observados' par
  insumo "$livro" 'livro-razao da execucao' livro
  [ "$falhas" -eq 0 ] || vermelho

  t="$(mktemp -d)" || { recusa_prov 'sem diretorio temporario'; vermelho; }
  LC_ALL=C sort "$esp" > "$t/esp_todos"
  LC_ALL=C sort -u "$esp" > "$t/esp"
  LC_ALL=C sort "$obs" > "$t/obs_todos"
  LC_ALL=C sort -u "$obs" > "$t/obs"
  LC_ALL=C awk -F'\t' '{ print $2 FS $3 }' "$livro" | LC_ALL=C sort > "$t/livro_pares"

  LC_ALL=C comm -23 "$t/esp" "$t/obs" > "$t/ausentes"
  LC_ALL=C comm -13 "$t/esp" "$t/obs" > "$t/extras"
  LC_ALL=C uniq -d "$t/obs_todos" > "$t/duplicados"
  LC_ALL=C uniq -d "$t/esp_todos" > "$t/esp_dup"

  local n_esp n_obs n_aus n_ext n_dup n_div=0
  n_esp=$(wc -l < "$t/esp" | tr -d ' ')
  n_obs=$(wc -l < "$t/obs_todos" | tr -d ' ')
  n_aus=$(wc -l < "$t/ausentes" | tr -d ' ')
  n_ext=$(wc -l < "$t/extras" | tr -d ' ')
  n_dup=$(wc -l < "$t/duplicados" | tr -d ' ')

  if [ -s "$t/esp_dup" ]; then
    recusa_prov "o conjunto ESPERADO tem par repetido — um conjunto nao repete elemento"
  fi

  # O livro e a lista de observados sao duas contagens da MESMA corrida. Se
  # discordam em qualquer par, a evidencia nao descreve uma execucao so.
  if ! cmp -s "$t/livro_pares" "$t/obs_todos"; then
    n_div=$((n_div + 1))
    recusa_prov "DIVERGENTE: o livro-razao e a lista de observados nao descrevem a mesma corrida"
  fi
  # execucao sem gate, com exit nao-zero ou sem hash de conteudo
  while IFS="$TAB" read -r _ g c e h; do
    if [ "$g" = '?' ]; then
      n_ext=$((n_ext + 1))
      recusa_prov "EXTRA: execucao observada sem gate associado: $c"
    elif [ "$e" != 0 ]; then
      n_div=$((n_div + 1))
      recusa_prov "DIVERGENTE: '$g' executou $c com exit $e"
    elif ! printf '%s' "$h" | grep -qE '^[0-9a-f]{64}$'; then
      n_div=$((n_div + 1))
      recusa_prov "DIVERGENTE: '$g' executou $c sem hash de conteudo produzido"
    fi
  done < "$livro"

  if [ "$n_esp" -ne "$n_obs" ]; then
    recusa_prov "CARDINALIDADE: esperados $n_esp, observados $n_obs"
  fi
  while IFS="$TAB" read -r g c; do
    [ -z "${g:-}" ] && continue
    recusa_prov "AUSENTE: '$g' ($c) era esperado e NAO foi observado executando"
  done < "$t/ausentes"
  while IFS="$TAB" read -r g c; do
    [ -z "${g:-}" ] && continue
    recusa_prov "EXTRA: '$g' ($c) foi observado e NAO era esperado"
  done < "$t/extras"
  while IFS="$TAB" read -r g c; do
    [ -z "${g:-}" ] && continue
    recusa_prov "DUPLICADO: '$g' ($c) foi executado mais de uma vez"
  done < "$t/duplicados"

  if [ -n "$rel" ]; then
    {
      printf 'ID\tESPERADO\tOBSERVADO\tRESULTADO\tEVIDENCIA\n'
      while IFS="$TAB" read -r g c; do
        local k ev res
        k=$(LC_ALL=C grep -cxF "$g$TAB$c" "$t/obs_todos")
        ev=$(LC_ALL=C awk -F'\t' -v g="$g" -v c="$c" '$2 == g && $3 == c { print $5; exit }' "$livro")
        case "$k" in 1) res=OK ;; 0) res=AUSENTE ;; *) res=DUPLICADO ;; esac
        printf '%s\t%s\t%s\t%s\t%s\n' "$g" "$c" "$k" "$res" "${ev:--}"
      done < "$t/esp"
      while IFS="$TAB" read -r g c; do
        [ -z "${g:-}" ] && continue
        printf '%s\t-\t%s\tEXTRA\t%s\n' "$g" "$(LC_ALL=C grep -cxF "$g$TAB$c" "$t/obs_todos")" "$c"
      done < "$t/extras"
    } > "$rel"
  fi
  rm -rf "$t"

  printf 'PROVENIENCIA OBRIGATORIA: esperados %s  observados %s  ausentes %s  extras %s  duplicados %s  divergentes %s\n' \
    "$n_esp" "$n_obs" "$n_aus" "$n_ext" "$n_dup" "$n_div"
  if [ "$falhas" -eq 0 ] && [ "$n_esp" -gt 0 ] && [ "$n_esp" -eq "$n_obs" ] && \
     [ "$n_aus" -eq 0 ] && [ "$n_ext" -eq 0 ] && [ "$n_dup" -eq 0 ] && [ "$n_div" -eq 0 ]; then
    printf 'PROVENIENCIA OBRIGATORIA: VERDE — %s/%s execucoes esperadas observadas, conjuntos identicos\n' "$n_obs" "$n_esp"
    return 0
  fi
  vermelho
}

# ---------------------------------------------------------------------------
# conferir <raiz> [relatorio]
# ---------------------------------------------------------------------------
fora_da_arvore() { # <caminho> <raiz>: o insumo externo nao pode morar dentro da raiz
  local p r
  p="$(cd "$(dirname "$1")" 2>/dev/null && pwd -P)/$(basename "$1")"
  r="$(cd "$2" 2>/dev/null && pwd -P)"
  case "$p/" in "$r"/*) return 1 ;; esac
  return 0
}

conferir() {
  local raiz="$1" rel="${2:-}"
  local aut="${BMV_PROV_AUTORIDADE:-}" reg="${BMV_PROV_REGISTRO:-}"
  if [ -z "$raiz" ] || [ ! -d "$raiz" ]; then recusa_prov "raiz ausente: ${raiz:-(vazia)}"; vermelho; fi
  if [ -z "$aut" ]; then recusa_prov 'BMV_PROV_AUTORIDADE nao informado — sem autoridade externa nao ha execucao provada'; fi
  if [ -z "$reg" ]; then recusa_prov 'BMV_PROV_REGISTRO nao informado — sem conjunto esperado externo nao ha identidade a provar'; fi
  [ "$falhas" -eq 0 ] || vermelho

  # 2. integridade da autoridade externa
  if [ ! -d "$aut" ]; then recusa_prov "autoridade externa ausente: $aut"; vermelho; fi
  fora_da_arvore "$aut" "$raiz" || recusa_prov "a autoridade externa mora DENTRO da arvore julgada: $aut"
  fora_da_arvore "$reg" "$raiz" || recusa_prov "o registro externo mora DENTRO da arvore julgada: $reg"
  if [ ! -f "$aut/MANIFEST-SHA256.txt" ]; then
    recusa_prov "autoridade externa sem manifesto: $aut/MANIFEST-SHA256.txt"
  elif [ "$(sha_de "$aut/MANIFEST-SHA256.txt")" != "$PIN_MANIFESTO" ]; then
    recusa_prov "o manifesto da autoridade externa nao e o congelado (sha256 $(sha_de "$aut/MANIFEST-SHA256.txt"))"
  elif ! ( cd "$aut" && grep -E '^[0-9a-f]{64}  ' MANIFEST-SHA256.txt | sha256sum -c --quiet --strict ) > /dev/null 2>&1; then
    recusa_prov 'algum arquivo da autoridade externa difere do seu manifesto congelado'
  fi
  if [ ! -f "$aut/$AUTORIDADE_REL" ] || [ "$(sha_de "$aut/$AUTORIDADE_REL")" != "$PIN_AUTORIDADE" ]; then
    recusa_prov "a autoridade de proveniencia nao e a congelada: $aut/$AUTORIDADE_REL"
  fi
  if insumo "$reg" 'registro externo do conjunto esperado' par; then
    [ "$(sha_de "$reg")" = "$PIN_REGISTRO" ] || \
      recusa_prov "o registro externo nao e o congelado (sha256 $(sha_de "$reg"))"
  fi
  # a copia da arvore responde ao registro externo, nunca o contrario
  if [ ! -f "$raiz/$COPIA_REL" ]; then
    recusa_prov "a copia do conjunto esperado sumiu da arvore: $COPIA_REL"
  elif ! cmp -s "$raiz/$COPIA_REL" "$reg"; then
    recusa_prov "a copia do conjunto esperado na arvore ($COPIA_REL) difere do registro externo — adulterada"
  fi
  [ "$falhas" -eq 0 ] || vermelho
  printf 'ok   autoridade o pacote externo e o registro dos pares sao os congelados\n'

  # 1. execucao realmente observada
  local t ea
  t="$(mktemp -d)" || { recusa_prov 'sem diretorio temporario'; vermelho; }
  bash "$aut/$AUTORIDADE_REL" conferir "$raiz" "$reg" "$t/saida" > "$t/autoridade.txt" 2>&1
  ea=$?
  sed 's/^/           | /' "$t/autoridade.txt" | grep -E '\| PROVENIENCIA: ' | head -60
  if [ "$ea" -ne 0 ]; then
    recusa_prov "a autoridade externa reprovou a execucao observada (exit $ea)"
  fi
  if grep -q '^PROVENIENCIA: AVISO' "$t/autoridade.txt"; then
    recusa_prov 'a autoridade externa mediu contra a declaracao da propria arvore, nao contra o registro'
  fi
  validar "$reg" "$t/saida/observados.tsv" "$t/saida/livro.tsv" "$rel"
  rm -rf "$t"
  [ "$falhas" -eq 0 ] || vermelho
  return 0
}

case "${1:-}" in
  conferir) conferir "${2:-}" "${3:-}" ;;
  validar)  validar "${2:-}" "${3:-}" "${4:-}" "${5:-}" ;;
  *) printf 'uso: %s conferir <raiz> [relatorio] | validar <esperados> <observados> <livro> [relatorio]\n' "$0"; exit 1 ;;
esac
