#!/usr/bin/env bash
#
# TESTE DO CONTRATO DE CONTEUDO — gate `contratosui` de `ci-os-integracao.yml`.
#
#   uso: bash scripts/ci/teste_contrato_suites.sh
#
# Roda sem GitHub Actions, sem rede, sem Flutter e sem Node: so bash e um
# diretorio temporario. E o unico lugar onde `verificar_contrato_suites.sh` — a
# peca que decide se as suites protegidas ainda PROVAM — e ele mesmo verificado.
#
# CADA CASO E UMA SABOTAGEM APLICADA A UMA COPIA. A arvore de trabalho nunca e
# tocada: tudo acontece sob `mktemp -d`, e o caso e considerado bom quando o
# verificador fica VERMELHO por conta propria.
#
# Prova que sobrevive a quebra da propria guarda e prova vazia. Por isso o T01 e
# o T30 sao CONTROLES verdes: sem eles, um verificador que reprovasse SEMPRE
# passaria nesta matriz inteira.
#
# Exit 0 = matriz inteira passou. Exit 1 = ao menos um caso falhou.

set -u

AQUI="$(cd "$(dirname "$0")" && pwd)"
RAIZ="$(cd "$AQUI/../.." && pwd)"
VERIF="$AQUI/verificar_contrato_suites.sh"
PORTAO="$AQUI/portao_os_integracao.sh"
FONTE="$AQUI/gates_os_integracao.txt"
YML="$RAIZ/.github/workflows/ci-os-integracao.yml"

for arquivo in "$VERIF" "$PORTAO" "$FONTE" "$YML"; do
  if [ ! -f "$arquivo" ]; then
    printf 'teste do contrato: arquivo obrigatorio ausente: %s\n' "$arquivo" >&2
    exit 1
  fi
done

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
BASE="$TMP/base"
W="$TMP/w"

passou=0
falhou=0

ok()  { passou=$((passou + 1)); printf '  ok    %s\n' "$1"; }
nok() { falhou=$((falhou + 1)); printf '  FALHA %s\n' "$1"; }

# ---------------------------------------------------------------------------
# A bancada
#
# So o que o verificador le: os scripts, a fonte unica, o workflow e as suites
# citadas pelos contratos. As suites vem da propria fonte, e nao de uma lista
# escrita aqui — uma lista escrita aqui seria a segunda relacao que esta OS
# existe para nao ter.
# ---------------------------------------------------------------------------

mkdir -p "$BASE/scripts/ci" "$BASE/.github/workflows"
cp "$VERIF" "$PORTAO" "$FONTE" "$AQUI/teste_portao_os_integracao.sh" "$BASE/scripts/ci/"
cp "$0" "$BASE/scripts/ci/teste_contrato_suites.sh"
cp "$YML" "$BASE/.github/workflows/ci-os-integracao.yml"

SUITES="$(sed -e 's/\r$//' "$FONTE" | awk '$1 == "suite" { print $2 }')"
if [ -z "$SUITES" ]; then
  printf 'teste do contrato: a fonte unica nao declara nenhuma `suite`\n' >&2
  exit 1
fi
for s in $SUITES; do
  case "$s" in
    scripts/ci/*) continue ;;  # ja copiado acima
  esac
  if [ ! -f "$RAIZ/$s" ]; then
    printf 'teste do contrato: suite declarada e ausente no disco: %s\n' "$s" >&2
    exit 1
  fi
  mkdir -p "$BASE/$(dirname "$s")"
  cp "$RAIZ/$s" "$BASE/$s"
done

FONTE_W="scripts/ci/gates_os_integracao.txt"
YML_W=".github/workflows/ci-os-integracao.yml"

# reset — devolve a bancada ao estado integro antes de cada sabotagem.
reset() {
  rm -rf "$W"
  cp -r "$BASE" "$W"
}

# resultados <dir> — monta a evidencia de um run bem-sucedido, na ordem certa:
# o carimbo primeiro, os logs depois.
resultados() {
  local d="$1" k
  rm -rf "$d"
  mkdir -p "$d"
  printf 'run 1 — carimbo desta execucao\n' > "$d/carimbo_execucao"
  printf '00:12 +81: All tests passed!\n' > "$d/t_comunicacao.log"
  printf '00:09 +137: All tests passed!\n' > "$d/t_chatdom.log"
  printf 'casos ok: 38 | casos com falha: 0\nTESTE DO PORTAO: VERDE\n' > "$d/t_portaoci.log"
  printf 'casos ok: 34 | casos com falha: 0\nTESTE DO CONTRATO: VERDE\n' > "$d/t_contratosui.log"
  printf '00:12 +22: All tests passed!
' > "$d/t_treinosan.log"
  # `sleep 1` nao: a bancada precisa ser rapida. Um deslocamento explicito faz a
  # ordem carimbo -> log ficar inequivoca sem esperar o relogio.
  touch -d '+1 hour' "$d"/t_*.log 2>/dev/null || touch "$d"/t_*.log
}

# esperar <exit-esperado> <descricao> [regex que a saida DEVE conter]
esperar() {
  local esperado="$1" desc="$2" agulha="${3:-}" real dir="${4:-}"
  if [ -n "$dir" ]; then
    bash "$W/scripts/ci/verificar_contrato_suites.sh" "$W" "$W/$YML_W" "$dir" \
      > "$TMP/saida.txt" 2>&1
  else
    bash "$W/scripts/ci/verificar_contrato_suites.sh" "$W" "$W/$YML_W" \
      > "$TMP/saida.txt" 2>&1
  fi
  real=$?
  if [ "$real" != "$esperado" ]; then
    nok "$desc — esperado exit $esperado, obtido $real"
    sed 's/^/        | /' "$TMP/saida.txt"
    return
  fi
  if [ -n "$agulha" ] && ! grep -qE "$agulha" "$TMP/saida.txt"; then
    nok "$desc — exit $real correto, mas a saida nao diz por que (/$agulha/)"
    sed 's/^/        | /' "$TMP/saida.txt"
    return
  fi
  ok "$desc (exit $real)"
}

printf '== controle ==\n'

reset
esperar 0 "T01 CONTROLE — arvore integra => VERDE" 'tudo no lugar'

printf '\n== a autoridade e seus leitores ==\n'

reset
rm -f "$W/$FONTE_W"
esperar 1 "T02 — fonte unica apagada => VERMELHO (N1)" 'fonte unica ausente'

reset
rm -f "$W/scripts/ci/portao_os_integracao.sh"
esperar 1 "T03 — agregador (unico leitor) apagado => VERMELHO (N2)" 'agregador ausente'

reset
printf 'analyze\nanalyze\n' > "$W/$FONTE_W"
esperar 1 "T04 — fonte com gate duplicado => VERMELHO (o leitor recusa)" 'recusou a fonte'

reset
: > "$W/$FONTE_W"
esperar 1 "T05 — fonte esvaziada => VERMELHO (N20)" 'recusou a fonte'

printf '\n== a suite existe ==\n'

reset
rm -f "$W/app/test/comunicacao/comunicacao_test.dart"
esperar 1 "T06 — suite protegida apagada => VERMELHO (N9)" 'removida ou renomeada'

reset
mv "$W/app/test/comunicacao/comunicacao_test.dart" \
   "$W/app/test/comunicacao/comunicacao_outro_test.dart"
esperar 1 "T07 — suite protegida renomeada => VERMELHO (N10)" 'removida ou renomeada'

printf '\n== a suite ainda PROVA ==\n'

reset
printf "import 'package:flutter_test/flutter_test.dart';\nvoid main() {\n  test('nada', () => expect(1, 1));\n}\n" \
  > "$W/app/test/comunicacao/comunicacao_test.dart"
esperar 1 "T08 — suite trocada por expect(1, 1) => VERMELHO (N11)" 'mudou e a assinatura nao'

reset
sed -i "s/group('ESP/group('XXX/" "$W/app/test/comunicacao/comunicacao_test.dart"
esperar 1 "T09 — bloco obrigatorio removido da suite => VERMELHO (N12)" 'sumiu de'

reset
sed -i 's/^    provas     71$/    provas     3/' "$W/$FONTE_W"
esperar 1 "T10 — piso de provas rebaixado na fonte => VERMELHO (N13)" 'piso de provas'

reset
sed -i 's/^    casos      81$/    casos      2/' "$W/$FONTE_W"
esperar 1 "T11 — piso de casos rebaixado na fonte => VERMELHO (N13)" 'piso de casos'

reset
sed -i 's/^\(    sha256     \)[0-9a-f]\{64\}$/\10000000000000000000000000000000000000000000000000000000000000000/' \
  "$W/$FONTE_W"
esperar 1 "T12 — assinatura adulterada => VERMELHO" 'mudou e a assinatura nao'

reset
# A forja mais barata contra busca textual: repetir o literal num COMENTARIO.
printf "import 'package:flutter_test/flutter_test.dart';\n// group('MAT group('CTR group('PRI group('ESP\n// ('MAT-01 ('CTR-02 ('PRI-19 ('ESP-01 'ESP-02 CONTROLE ['mesa_privada/completo']\nvoid main() {\n  test('nada', () => expect(1, 1));\n}\n" \
  > "$W/app/test/comunicacao/comunicacao_test.dart"
esperar 1 "T13 — literais so em COMENTARIO nao satisfazem o contrato => VERMELHO" 'sumiu de'

printf '\n== o contrato tem de estar completo ==\n'

reset
sed -i '/^    sha256     /d' "$W/$FONTE_W"
esperar 1 "T14 — contrato sem sha256 => VERMELHO" "nao declara 'sha256'"

reset
sed -i '/^    exige      /d' "$W/$FONTE_W"
esperar 1 "T15 — contrato sem nenhum exige => VERMELHO" "nao declara nenhum 'exige'"

reset
sed -i '/^    provas     /d' "$W/$FONTE_W"
esperar 1 "T16 — contrato sem provas => VERMELHO" "nao declara 'provas'"

reset
sed -i '/^    suite      /d' "$W/$FONTE_W"
esperar 1 "T17 — contrato sem suite => VERMELHO" "nao declara 'suite'"

reset
sed -i 's/^    provas     71$/    plantao    71/' "$W/$FONTE_W"
esperar 1 "T18 — atributo desconhecido no contrato => VERMELHO" 'atributo desconhecido'

reset
sed -i 's/^    provas     71$/    provas/' "$W/$FONTE_W"
esperar 1 "T19 — atributo sem valor => VERMELHO (o leitor recusa)" 'recusou a fonte'

reset
sed -i 's/^    provas     71$/    provas     71\n    provas     71/' "$W/$FONTE_W"
esperar 1 "T20 — atributo repetido => VERMELHO" "'provas' repetido"

printf '\n== o contrato nao pode encolher ==\n'

reset
sed -i '/^    \(suite\|executor\|sha256\|provas\|casos\|conta\|contador\|exige\) /d' "$W/$FONTE_W"
esperar 1 "T21 — TODOS os contratos removidos => VERMELHO (N20)" 'protecao de conteudo foi esvaziada'

reset
awk '/^comunicacao$/ { pulando = 1; next }
     pulando && /^[[:blank:]]/ { next }
     { pulando = 0; print }' "$BASE/$FONTE_W" > "$W/$FONTE_W"
esperar 1 "T22 — gate protegido removido da fonte => VERMELHO (N6)" "perdeu o contrato"

reset
printf '\ngatequenaoexiste\n    suite      app/test/chat/chat_test.dart\n    executor   roda gatequenaoexiste test/chat/chat_test.dart\n    sha256     0000000000000000000000000000000000000000000000000000000000000000\n    provas     1\n    exige      void main\n' \
  >> "$W/$FONTE_W"
esperar 1 "T23 — contrato num gate que a fonte nao declara => impossivel: ele VIRA gate" 'nao produz'

printf '\n== o executor, o marcador e a propria invocacao ==\n'

reset
sed -i 's|^\( *\)roda comunicacao  test/comunicacao/comunicacao_test.dart|\1roda comunicacao  test/comunicacao/outro_test.dart|' "$W/$YML_W"
esperar 1 "T24 — executor removido do workflow => VERMELHO (N18)" 'nao tem a linha do executor'

reset
sed -i 's|^    executor   roda comunicacao test/comunicacao/comunicacao_test.dart$|    executor   roda comunicacao test/chat/chat_test.dart|' "$W/$FONTE_W"
esperar 1 "T25 — executor apontando para OUTRA suite => VERMELHO" 'nao cita a suite'

reset
sed -i 's|scripts/ci/verificar_contrato_suites.sh|scripts/ci/nada.sh|g' "$W/$YML_W"
esperar 1 "T26 — o workflow deixou de invocar o verificador => VERMELHO (§17)" 'nao invoca mais'

printf '\n== FASE B: o log da execucao ==\n'

reset
resultados "$TMP/res"
esperar 0 "T27 CONTROLE — evidencia completa e datada => VERDE" 'posterior ao carimbo' "$TMP/res"

reset
resultados "$TMP/res"
rm -f "$TMP/res/t_comunicacao.log"
esperar 1 "T28 — marcador fabricado, sem log => VERMELHO (N16)" 'marcador sem execucao' "$TMP/res"

reset
resultados "$TMP/res"
printf '00:12 +81: All tests passed!\n' > "$TMP/res/t_comunicacao.log"
touch -d '-1 hour' "$TMP/res/t_comunicacao.log"
esperar 1 "T29 — log ANTERIOR ao carimbo => VERMELHO (N19)" 'outra execucao' "$TMP/res"

reset
resultados "$TMP/res"
rm -f "$TMP/res/carimbo_execucao"
esperar 1 "T30 — carimbo do run ausente => VERMELHO" 'carimbo de execucao ausente' "$TMP/res"

reset
resultados "$TMP/res"
printf '00:00 +3: All tests passed!\n' > "$TMP/res/t_comunicacao.log"
touch -d '+1 hour' "$TMP/res/t_comunicacao.log"
esperar 1 "T31 — suite executou 3 casos e o piso e 81 => VERMELHO (N13/N14)" 'a suite encolheu' "$TMP/res"

reset
resultados "$TMP/res"
: > "$TMP/res/t_portaoci.log"
esperar 1 "T32 — log vazio nao e evidencia => VERMELHO (N14)" 'marcador sem execucao' "$TMP/res"

printf '\n== a margem continua sendo a autoridade ==\n'

reset
sed -i 's/^comunicacao$/  comunicacao/' "$W/$FONTE_W"
esperar 1 "T33 — gate indentado por engano => VERMELHO, e nao some em silencio" 'recusou a fonte'

printf '\n== controle final ==\n'

reset
esperar 0 "T34 CONTROLE — arvore restaurada => VERDE de novo" 'tudo no lugar'

printf '\n----------------------------------------\n'
printf 'casos ok: %d | casos com falha: %d\n' "$passou" "$falhou"

if [ "$falhou" -eq 0 ]; then
  printf 'TESTE DO CONTRATO: VERDE\n'
  exit 0
fi

printf 'TESTE DO CONTRATO: VERMELHO\n'
exit 1
