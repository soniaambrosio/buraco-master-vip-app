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

# ---------------------------------------------------------------------------
# OS 42-C2 — `torneiobase` FAIL-CLOSED
#
# Os casos acima provam o MECANISMO, e provam-no sobre `comunicacao`. Estes
# provam a APLICACAO dele ao gate que guarda a fundacao P de Torneios V1, e
# existem porque a OS 42-C1 mediu o escape e o deixou aberto por reserva: a
# entrada inteira de `torneiobase` saia da fonte unica, o produtor saia do
# workflow, a suite saia do disco, e o verificador terminava com "tudo no
# lugar". C2-02 e esse escape, agora vermelho.
#
# A regra que cada caso exercita mora em `verificar_contrato_suites.sh`, FORA da
# suite protegida e fora da fonte de dados que ela guarda. E a matriz mora aqui,
# no gate `contratosui`, que tem digest e `exige` proprios na fonte unica — de
# modo que apagar um destes casos para "consertar" uma sabotagem tambem reprova.
# ---------------------------------------------------------------------------

TB_ARQ='app/test/torneios/fundacao_base_p_test.dart'
TB_CMD='roda torneiobase test/torneios/fundacao_base_p_test.dart'

# tirar_entrada <gate> — apaga da fonte a linha do gate E todo o contrato dele.
tirar_entrada() {
  awk -v g="$1" '$0 == g { pulando = 1; next }
                 pulando && /^[[:blank:]]/ { next }
                 { pulando = 0; print }' "$W/$FONTE_W" > "$TMP/f.txt"
  mv "$TMP/f.txt" "$W/$FONTE_W"
}

# tirar_atributo <gate> <atributo> [quantos]
#
# Apaga linhas de atributo DENTRO da entrada pedida — sem <quantos>, todas; com
# um numero, so as primeiras N. Nao casa por VALOR de proposito: o dia em que o
# digest de `torneiobase` for recarimbado ou o piso subir, esta bancada continua
# valendo sem ninguem se lembrar de vir aqui.
tirar_atributo() {
  awk -v g="$1" -v a="$2" -v lim="${3:-0}" '
    /^[^[:blank:]#]/ { dentro = ($0 == g) }
    dentro && /^[[:blank:]]/ && $1 == a && (lim == 0 || n < lim) { n++; next }
    { print }' "$W/$FONTE_W" > "$TMP/f.txt"
  mv "$TMP/f.txt" "$W/$FONTE_W"
}

# trocar_atributo <gate> <atributo> <valor novo>
trocar_atributo() {
  awk -v g="$1" -v a="$2" -v v="$3" '
    /^[^[:blank:]#]/ { dentro = ($0 == g) }
    dentro && /^[[:blank:]]/ && $1 == a { printf "    %-10s %s\n", a, v; next }
    { print }' "$W/$FONTE_W" > "$TMP/f.txt"
  mv "$TMP/f.txt" "$W/$FONTE_W"
}

# escapar_ere <texto> — o literal de `exige` vira agulha de `grep -E`, e
# `group('SEED` sem escape e um parentese aberto: o grep morreria e o caso
# passaria a medir o instrumento, nao a guarda.
escapar_ere() { printf '%s' "$1" | sed -e 's#[][(){}.*+?^$|\\]#\\&#g'; }

# resultados_completos <dir>
#
# Evidencia de um run em que TODO gate com contrato deixou log. A relacao vem da
# FONTE, e nao de uma lista escrita aqui: lista escrita aqui envelhece no
# primeiro gate novo e passa a dar verde por omissao.
#
# NAO substitui `resultados()` e nao mexe nela: T27 continua medindo exatamente
# o que media. Esta e a fixture da campanha da OS 42-C2, que precisa de uma FASE
# B VERDE para depois sabotar UM log e ver a diferenca.
resultados_completos() {
  local d="$1" k
  rm -rf "$d"
  mkdir -p "$d"
  printf 'run C2 — carimbo desta execucao\n' > "$d/carimbo_execucao"
  for k in $(awk '/^[^[:blank:]#]/ { g = $0; next }
                  /^[[:blank:]]/ && g != "" && !(g in vistos) { vistos[g] = 1; print g }' \
                  "$W/$FONTE_W"); do
    printf '00:12 +999: All tests passed! | casos ok: 999 | casos com falha: 0\n' > "$d/t_$k.log"
  done
  touch -d '+1 hour' "$d"/t_*.log 2>/dev/null || touch "$d"/t_*.log
}

# marcadores <dir> — um `exit_<gate>` = 0 para CADA gate da fonte. E o estado em
# que o agregador fica VERDE; as sabotagens tiram ou adulteram exatamente um.
marcadores() {
  local d="$1" k
  rm -rf "$d"
  mkdir -p "$d"
  for k in $(bash "$W/scripts/ci/portao_os_integracao.sh" --listar "$W/$FONTE_W"); do
    printf '0\n' > "$d/exit_$k"
  done
}

# esperar_portao <exit-esperado> <descricao> <regex> <dir de resultados>
esperar_portao() {
  local esperado="$1" desc="$2" agulha="$3" dir="$4" real
  bash "$W/scripts/ci/portao_os_integracao.sh" "$W/$FONTE_W" "$dir" \
    > "$TMP/saida.txt" 2>&1
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

printf '\n== OS 42-C2: torneiobase — o registro na fonte unica ==\n'

reset
sed -i '/^torneiobase$/d' "$W/$FONTE_W"
esperar 1 "C2-01 — so o REGISTRO de torneiobase removido => VERMELHO" 'perdeu o contrato'

reset
tirar_entrada torneiobase
sed -i "\\|^ *$TB_CMD *\$|d" "$W/$YML_W"
esperar 1 "C2-02 — registro e produtor removidos JUNTOS => VERMELHO (o escape da C1)" \
  "'torneiobase' perdeu o contrato"

reset
sed -i 's/^torneiobase$/# torneiobase/' "$W/$FONTE_W"
esperar 1 "C2-03 — gate neutralizado, so o nome sobrando em COMENTARIO => VERMELHO" \
  'perdeu o contrato'

printf '\n== OS 42-C2: torneiobase — a suite e o alvo ==\n'

reset
rm -f "$W/$TB_ARQ"
esperar 1 "C2-04 — suite de torneiobase apagada => VERMELHO" 'removida ou renomeada'

reset
mv "$W/$TB_ARQ" "$W/app/test/torneios/fundacao_base_p_outro_test.dart"
esperar 1 "C2-05 — suite de torneiobase renomeada => VERMELHO" 'removida ou renomeada'

reset
printf "import 'package:flutter_test/flutter_test.dart';\nvoid main() {\n  test('isca', () => expect(1, 1));\n}\n" \
  > "$W/app/test/torneios/isca_test.dart"
trocar_atributo torneiobase executor 'roda torneiobase test/torneios/isca_test.dart'
sed -i "s|$TB_CMD|roda torneiobase test/torneios/isca_test.dart|" "$W/$YML_W"
esperar 1 "C2-06 — executor desviado para suite-ISCA => VERMELHO" 'nao cita a suite'

reset
printf "import 'package:flutter_test/flutter_test.dart';\nvoid main() {\n  test('nada', () => expect(1, 1));\n}\n" \
  > "$W/$TB_ARQ"
esperar 1 "C2-07 — corpo de torneiobase trocado por expect(1, 1) => VERMELHO" \
  'mudou e a assinatura nao'

reset
printf "import 'package:flutter_test/flutter_test.dart';\nvoid main() {\n  test('nada', () => expect(1, 1));\n}\n" \
  > "$W/$TB_ARQ"
trocar_atributo torneiobase sha256 \
  "$(tr -d '\r' < "$W/$TB_ARQ" | sha256sum | awk '{print $1}')"
esperar 1 "C2-08 — conteudo adulterado e digest REALINHADO no mesmo commit => VERMELHO" \
  'declaracoes e o piso e 56'

printf '\n== OS 42-C2: torneiobase — o contrato nao pode encolher ==\n'

reset
tirar_atributo torneiobase sha256
esperar 1 "C2-09 — digest de torneiobase removido => VERMELHO" "nao declara 'sha256'"

reset
tirar_atributo torneiobase provas
esperar 1 "C2-10 — piso de provas removido => VERMELHO" "nao declara 'provas'"

reset
trocar_atributo torneiobase provas 0
esperar 1 "C2-11 — piso de provas ZERADO => VERMELHO" 'piso de provas.*foi baixado'

reset
tirar_atributo torneiobase casos
esperar 1 "C2-12 — piso de casos removido => VERMELHO" "deixou de declarar 'casos'"

reset
trocar_atributo torneiobase casos 1
esperar 1 "C2-13 — piso de casos rebaixado para 1 => VERMELHO" 'piso de casos.*foi baixado'

reset
tirar_atributo torneiobase exige
esperar 1 "C2-14 — TODOS os exige de torneiobase removidos => VERMELHO" \
  "nao declara nenhum 'exige'"

reset
tirar_atributo torneiobase exige 1
esperar 1 "C2-15 — UM exige removido, treze de catorze => VERMELHO" \
  "declara 13 'exige' e o piso e 14"

printf '\n== OS 42-C2: torneiobase — cada bloco normativo, um a um ==\n'

# O laco le os literais da PROPRIA fonte: acrescentar um `exige` acrescenta um
# caso, sem tocar nesta matriz. Aqui `reset` roda uma vez so — a sabotagem e
# sempre no mesmo arquivo, e copiar a bancada inteira catorze vezes e o que faz
# uma matriz deixar de ser rodada antes de commitar.
reset
LITERAIS_TB="$(awk '/^[^[:blank:]#]/ { dentro = ($0 == "torneiobase") }
  dentro && /^[[:blank:]]/ && $1 == "exige" {
    sub(/^[[:blank:]]*exige[[:blank:]]+/, ""); print }' "$BASE/$FONTE_W")"
if [ -z "$LITERAIS_TB" ]; then
  nok "C2-16 — a fonte nao declara nenhum exige para torneiobase"
else
  n_bloco=0
  while IFS= read -r lit; do
    [ -z "$lit" ] && continue
    n_bloco=$((n_bloco + 1))
    grep -vF "$lit" "$BASE/$TB_ARQ" > "$W/$TB_ARQ"
    esperar 1 "C2-16/$n_bloco — bloco [$lit] apagado da suite => VERMELHO" \
      "o bloco $(escapar_ere "$lit") sumiu"
  done <<LITERAIS
$LITERAIS_TB
LITERAIS
fi

printf '\n== OS 42-C2: torneiobase — o produtor no workflow ==\n'

reset
sed -i "\\|^ *$TB_CMD *\$|d" "$W/$YML_W"
esperar 1 "C2-17 — gate declarado e comando REMOVIDO do workflow => VERMELHO" \
  'nao tem a linha do executor'

reset
sed -i "s|^\\( *\\)$TB_CMD\$|\\1# $TB_CMD|" "$W/$YML_W"
esperar 1 "C2-18 — produtor do marcador COMENTADO no workflow => VERMELHO" \
  "nao produz 'exit_torneiobase'"

printf '\n== OS 42-C2: torneiobase — FASE B, a execucao real ==\n'

reset
resultados_completos "$TMP/resc2"
esperar 0 "C2-19 CONTROLE — evidencia datada de TODOS os contratos => VERDE" \
  'ok   casos      torneiobase' "$TMP/resc2"

reset
resultados_completos "$TMP/resc2"
rm -f "$TMP/resc2/t_torneiobase.log"
esperar 1 "C2-20 — marcador de torneiobase sem log => VERMELHO" \
  "gate 'torneiobase' nao deixou log" "$TMP/resc2"

reset
resultados_completos "$TMP/resc2"
touch -d '-1 hour' "$TMP/resc2/t_torneiobase.log"
esperar 1 "C2-21 — log de torneiobase ANTERIOR ao carimbo => VERMELHO" \
  "log de 'torneiobase' e ANTERIOR" "$TMP/resc2"

# O ALVO MAIS ESTREITO passa inteira a FASE A: o executor continua citando a
# suite, e o workflow continua carregando a linha exata. Quem reprova e o piso
# de casos EXECUTADOS — e ele so existe porque `casos` esta na fonte e
# `PISOS_CASOS` o impede de sumir de la.
reset
resultados_completos "$TMP/resc2"
trocar_atributo torneiobase executor "$TB_CMD --plain-name SEED"
sed -i "s|^\\( *\\)$TB_CMD\$|\\1$TB_CMD --plain-name SEED|" "$W/$YML_W"
printf '00:03 +9: All tests passed!\n' > "$TMP/resc2/t_torneiobase.log"
touch -d '+1 hour' "$TMP/resc2/t_torneiobase.log"
esperar 1 "C2-22 — alvo trocado por caminho mais ESTREITO => VERMELHO" \
  "'torneiobase' executou 9 caso" "$TMP/resc2"

printf '\n== OS 42-C2: torneiobase — a participacao no agregador ==\n'

reset
marcadores "$TMP/aggc2"
esperar_portao 0 "C2-23 CONTROLE — todo gate com exit 0 => agregador VERDE" \
  'resultado: VERDE' "$TMP/aggc2"

reset
marcadores "$TMP/aggc2"
printf 'ausente: test/torneios/fundacao_base_p_test.dart\n' > "$TMP/aggc2/nao_torneiobase"
esperar_portao 1 "C2-24 — torneiobase marcado NAO EXECUTADO => agregador VERMELHO" \
  'torneiobase +NAO EXECUTADO' "$TMP/aggc2"

reset
marcadores "$TMP/aggc2"
rm -f "$TMP/aggc2/exit_torneiobase"
esperar_portao 1 "C2-25 — marcador final de torneiobase ausente => agregador VERMELHO" \
  'torneiobase +NAO EXECUTADO' "$TMP/aggc2"

reset
marcadores "$TMP/aggc2"
printf '1\n' > "$TMP/aggc2/exit_torneiobase"
esperar_portao 1 "C2-26 — torneiobase com exit nao zero => agregador VERMELHO" \
  'torneiobase +VERMELHO' "$TMP/aggc2"

# A DIVISAO DE TRABALHO, dita em voz alta. Tirar `torneiobase` da fonte tira-o
# tambem do agregador — que passa a nao ter o que cobrar e fica VERDE. E por
# isso que a regua de contratos minimos existe FORA da fonte: sem ela, este par
# de resultados seria "verde" e "verde".
reset
tirar_entrada torneiobase
sed -i "\\|^ *$TB_CMD *\$|d" "$W/$YML_W"
marcadores "$TMP/aggc2"
bash "$W/scripts/ci/portao_os_integracao.sh" "$W/$FONTE_W" "$TMP/aggc2" \
  > "$TMP/saida.txt" 2>&1
agg_exit=$?
bash "$W/scripts/ci/verificar_contrato_suites.sh" "$W" "$W/$YML_W" \
  > "$TMP/saida2.txt" 2>&1
ver_exit=$?
if [ "$agg_exit" = "0" ] && [ "$ver_exit" = "1" ] &&
   grep -q "o gate 'torneiobase' perdeu o contrato" "$TMP/saida2.txt"; then
  ok "C2-27 — sem a entrada o agregador fica VERDE e quem reprova e a regua (agg 0 / verif 1)"
else
  nok "C2-27 — esperado agregador 0 e verificador 1 com a causa; obtido $agg_exit / $ver_exit"
  sed 's/^/        | /' "$TMP/saida2.txt"
fi

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
