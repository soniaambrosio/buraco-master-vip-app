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
# Prova que sobrevive a quebra da propria guarda e prova vazia. Por isso ha
# CONTROLES VERDES — T01, T27, T34 e T42: sem eles, um verificador que reprovasse
# SEMPRE passaria nesta matriz inteira.
#
# Exit 0 = matriz inteira passou. Exit 1 = ao menos um caso falhou.

set -u

AQUI="$(cd "$(dirname "$0")" && pwd)"
RAIZ="$(cd "$AQUI/../.." && pwd)"
VERIF="$AQUI/verificar_contrato_suites.sh"
PORTAO="$AQUI/portao_os_integracao.sh"
LEXICO="$AQUI/codigo_executavel.awk"
FONTE="$AQUI/gates_os_integracao.txt"
YML="$RAIZ/.github/workflows/ci-os-integracao.yml"

for arquivo in "$VERIF" "$PORTAO" "$LEXICO" "$FONTE" "$YML"; do
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
cp "$VERIF" "$PORTAO" "$LEXICO" "$FONTE" "$AQUI/teste_portao_os_integracao.sh" "$BASE/scripts/ci/"
cp "$0" "$BASE/scripts/ci/teste_contrato_suites.sh"
cp "$YML" "$BASE/.github/workflows/ci-os-integracao.yml"

SUITES="$(sed -e 's/\r$//' "$FONTE" | awk '$1 == "suite" { print $2 }')"
if [ -z "$SUITES" ]; then
  printf 'teste do contrato: a fonte unica nao declara nenhuma `suite`\n' >&2
  exit 1
fi

# Os ALVOS entram pela mesma porta que as suites, e pela mesma razao: eles saem
# da FONTE, e nao de uma lista escrita aqui. Um gate de codebase declara o
# manifesto que o executor roda (`alvo`), e sem ele na bancada o verificador
# reprovaria por ausencia de arquivo em TODOS os casos — inclusive nos controles,
# que e o jeito mais rapido de uma matriz inteira deixar de medir.
ALVOS="$(sed -e 's/\r$//' "$FONTE" | awk '$1 == "alvo" { print $2 }')"

for s in $SUITES $ALVOS; do
  case "$s" in
    scripts/ci/*) continue ;;  # ja copiado acima
  esac
  if [ ! -f "$RAIZ/$s" ]; then
    printf 'teste do contrato: arquivo declarado e ausente no disco: %s\n' "$s" >&2
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

# ---------------------------------------------------------------------------
# A EVIDENCIA DA FASE B NASCE DA FONTE — E O ORACULO NAO
# ---------------------------------------------------------------------------
#
# Ate a OS 40-C2, `resultados()` escrevia log para QUATRO gates, por uma lista
# escrita a mao aqui dentro. A FASE B exige log de TODO gate contratado, e os
# contratados eram dezesseis: `T27 CONTROLE` reprovava por doze logs que a
# bancada nunca escreveu, e o `casos ok: 34` fabricado ainda batia contra um piso
# que ja era 40. Um CONTROLE que reprova nao mede mais nada — e todos os casos de
# FASE B ficam medindo a falha do controle, e nao a propria sabotagem.
#
# A evidencia passa a ser DERIVADA da relacao de contratados da fonte, com o
# numero de casos de cada gate lido do proprio contrato dele. Nenhuma lista de
# gates escrita a mao, e nenhum numero fabricado.
#
# E A DERIVACAO CRIA UM BURACO NOVO, QUE E FECHADO LOGO ABAIXO: se a fixture sai
# da fonte, tirar um gate da fonte encolhe A EVIDENCIA E O ORACULO no mesmo
# movimento, e a matriz continua verde medindo menos. Por isso o conjunto
# AUTORITATIVO de contratados esta congelado aqui, por extenso, FORA da relacao
# derivada — e `T42` compara os dois. Gate novo com contrato, gate que perdeu o
# contrato, ou gate renomeado: um dos tres lados muda, e o caso reprova.
CONTRATADOS="$(sed -e 's/\r$//' "$FONTE" | awk '
  /^[^ \t#]/ { g = $1; next }
  /^[ \t]+(suite|executor|casos|contador|alvo|exigealvo)[ \t]/ {
    if (g != "" && !(g in visto)) { visto[g] = 1; print g }
  }
')"

CONTRATADOS_CONGELADOS="comunicacao chatdom portaoci contratosui rankingfn \
avatarcanon avatarhml perfilvis rknavpub compavrank compnavpub \
socialestado socialleitor socialtela audsocial a11yamigos"

# `casos_de <gate>` — o piso de casos EXECUTADOS declarado no contrato dele.
casos_de() {
  sed -e 's/\r$//' "$FONTE" | awk -v alvo="$1" '
    /^[^ \t#]/ { g = $1; next }
    g == alvo && $1 == "casos" { print $2; exit }
  '
}

# resultados <dir> — monta a evidencia de um run bem-sucedido, na ordem certa:
# o carimbo primeiro, os logs depois. UM LOG POR GATE CONTRATADO.
#
# Cada log carrega as tres formas de contador que os contratos deste repositorio
# usam — o `+N` do Flutter, o `casos ok: N` das bancadas de shell e o `pass N` do
# `node --test` —, todas com o numero do proprio contrato. Escrever so a forma de
# um deles obrigaria esta funcao a saber qual gate usa qual, que e a lista escrita
# a mao voltando pela porta dos fundos.
resultados() {
  local d="$1" k n
  rm -rf "$d"
  mkdir -p "$d"
  printf 'run 1 — carimbo desta execucao\n' > "$d/carimbo_execucao"
  for k in $CONTRATADOS; do
    n="$(casos_de "$k")"
    [ -z "$n" ] && n=1
    {
      printf '00:12 +%s: All tests passed!\n' "$n"
      printf 'casos ok: %s | casos com falha: 0\n' "$n"
      printf 'pass %s\n' "$n"
    } > "$d/t_$k.log"
  done
  # `sleep 1` nao: a bancada precisa ser rapida. Um deslocamento explicito faz a
  # ordem carimbo -> log ficar inequivoca sem esperar o relogio.
  touch -d '+1 hour' "$d"/t_*.log 2>/dev/null || touch "$d"/t_*.log
}

# recarimbar <suite> — realinha o `sha256` daquela suite na fonte de $W.
#
# Sem isto, TODA sabotagem de conteudo reprovaria pela assinatura, e nenhum caso
# de conteudo mediria conteudo: seriam catorze copias do T12. Quem trivializa uma
# suite le o digest que o verificador imprime e o escreve na fonte no mesmo
# commit — a bancada tem de sabotar do mesmo jeito.
recarimbar() {
  local s="$1" novo
  novo="$(tr -d '\r' < "$W/$s" | sha256sum | awk '{print $1}')"
  awk -v s="$s" -v novo="$novo" '
    { l = $0; sub(/\r$/, "", l) }
    l ~ /^[ \t]+suite[ \t]/ { n = l; sub(/^[ \t]+suite[ \t]+/, "", n); mira = (n == s) }
    mira && l ~ /^[ \t]+sha256[ \t]/ && !feito { print "    sha256     " novo; feito = 1; next }
    { print l }
    END { if (!feito) exit 3 }
  ' "$W/$FONTE_W" > "$W/$FONTE_W.novo" || {
    printf 'teste do contrato: recarimbo de %s nao pegou\n' "$s" >&2
    return 1
  }
  mv "$W/$FONTE_W.novo" "$W/$FONTE_W"
}

# trocar_linha <arquivo> <linha exata> <linha nova> — sabotagem com ANCORA
# VERIFICADA. Um `sed` que nao pegou produz caso verde que nao mediu nada.
trocar_linha() {
  local arq="$1" tmp
  tmp="$TMP/troca.txt"
  VELHA="$2" NOVA="$3" awk '
    { l = $0; sub(/\r$/, "", l) }
    l == ENVIRON["VELHA"] { print ENVIRON["NOVA"]; achou++; next }
    { print l }
    END { if (!achou) exit 3 }
  ' "$arq" > "$tmp" || {
    printf 'teste do contrato: ANCORA NAO CASOU em %s: %s\n' "$arq" "$2" >&2
    return 1
  }
  mv "$tmp" "$arq"
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
# QUALQUER atributo indentado, e nao uma lista de nomes. A lista escrita a mao
# ficou para tras quando a OS 40-C1 acrescentou `alvo` e `exigealvo`: o caso
# continuava vermelho, mas por OUTRO motivo — sobrava contrato, e a mensagem
# "a protecao de conteudo foi esvaziada" nunca saia. Um caso que reprova pelo
# motivo errado e um caso que deixou de medir.
sed -i '/^    [a-z][a-z0-9_]* /d' "$W/$FONTE_W"
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

printf '\n== `alvo`: o executor roda o codebase, o codebase roda as suites ==\n'

# A CADEIA DE `rankingfn`, ELO POR ELO. Ate a OS 40-C1 o vocabulario so sabia
# falar de um arquivo por gate, e um passo que roda `npm test` nao cita arquivo
# nenhum — quem nomeia as suites e o `package.json`. Estes seis casos sao a
# matriz do elo novo: se ele puder ser desligado em silencio, o contrato de
# `rankingfn` vira decoracao.

reset
sed -i 's| test/superficie.test.js||' "$W/functions-ranking/package.json"
esperar 1 "T35 — suite tirada do alvo oficial => VERMELHO" 'nao roda a suite'

reset
sed -i 's|test/composicao.test.js"|test/composicao.test.js test/isca.test.js"|' \
  "$W/functions-ranking/package.json"
esperar 1 "T36 — suite-isca acrescentada ao alvo => VERMELHO" 'sumiu do alvo'

reset
rm -f "$W/functions-ranking/package.json"
esperar 1 "T37 — alvo apagado => VERMELHO" "'alvo' de 'rankingfn' nao existe"

reset
sed -i '/^    alvo       /d' "$W/$FONTE_W"
esperar 1 "T38 — exigealvo sem alvo => VERMELHO" "tem 'exigealvo' e nao declara 'alvo'"

reset
sed -i '/^    exigealvo  /d' "$W/$FONTE_W"
esperar 1 "T39 — alvo sem nenhum exigealvo => VERMELHO" 'alvo sem congelamento'

reset
awk '/^    suite      functions-ranking\/test\/superficie\.test\.js$/ { pulando = 1; next }
     pulando && /^[[:blank:]]/ { next }
     { pulando = 0; print }' "$BASE/$FONTE_W" > "$W/$FONTE_W"
esperar 1 "T40 — segunda suite do gate removida da fonte => VERMELHO (o piso e a SOMA)" 'piso de provas'

reset
awk '/^rankingfn$/ { pulando = 1; print; next }
     pulando && /^[[:blank:]]/ { next }
     { pulando = 0; print }' "$BASE/$FONTE_W" > "$W/$FONTE_W"
esperar 1 "T41 — contrato de rankingfn esvaziado => VERMELHO (N6)" "perdeu o contrato"

printf '\n== o oraculo da evidencia mora FORA da relacao derivada ==\n'

# `resultados()` monta os logs a partir dos gates contratados NA FONTE. Sozinho,
# isso fecharia o buraco do T27 e abriria outro: tirar um gate da fonte encolheria
# a evidencia E o oraculo no mesmo movimento, e a matriz seguiria verde medindo
# menos. Este caso e o oraculo que nao deriva de nada — o conjunto autoritativo
# de contratados, escrito por extenso.
if [ "$(printf '%s\n' $CONTRATADOS | sort | tr '\n' ' ')" = \
     "$(printf '%s\n' $CONTRATADOS_CONGELADOS | sort | tr '\n' ' ')" ]; then
  ok "T42 — a relacao de contratados da fonte e EXATAMENTE a congelada"
else
  nok "T42 — a relacao de contratados da fonte divergiu da congelada"
  printf '        | na fonte  %s\n' "$(printf '%s\n' $CONTRATADOS | sort | tr '\n' ' ')"
  printf '        | congelada %s\n' "$(printf '%s\n' $CONTRATADOS_CONGELADOS | sort | tr '\n' ' ')"
fi

printf '\n== a agulha tem de estar em CODIGO, e nao em texto que o imita ==\n'

# AS SEIS FORMAS DE MOVER A AGULHA PARA REGIAO INERTE. Todas recarimbam o
# `sha256` no mesmo movimento — quem trivializa uma suite le o digest que o
# verificador imprime e o escreve na fonte, e uma bancada que nao recarimbasse
# mediria a assinatura seis vezes em vez de medir o lexer uma.
#
# A versao anterior desta guarda removia LINHAS de comentario por expressao
# regular. Destas seis, ela pegava zero: nenhuma e linha de comentario inteira.
# Era esse o escape que a OS 40-R2 mediu.
SF_JS="functions-ranking/test/superficie.test.js"
SOCIALTELA="app/test/amigos/descoberta_social_tela_test.dart"

reset
trocar_linha "$W/$SF_JS" '      pkg.scripts.test,' '      /* pkg.scripts.test, */ 0,' && recarimbar "$SF_JS"
esperar 1 "T43 — agulha so em comentario de BLOCO => VERMELHO" 'nao codigo executavel'

reset
trocar_linha "$W/$SF_JS" '      pkg.scripts.test,' '      "pkg.scripts.test,",' && recarimbar "$SF_JS"
esperar 1 "T44 — agulha so em string => VERMELHO" 'nao codigo executavel'

reset
trocar_linha "$W/$SF_JS" '      pkg.scripts.test,' '      `pkg.scripts.test,`,' && recarimbar "$SF_JS"
esperar 1 "T45 — agulha so em texto de template => VERMELHO" 'nao codigo executavel'

reset
trocar_linha "$W/$SF_JS" '      pkg.scripts.test,' '      String(/pkg.scripts.test,/),' && recarimbar "$SF_JS"
esperar 1 "T46 — agulha so em expressao regular => VERMELHO" 'nao codigo executavel'

reset
trocar_linha "$W/$SF_JS" '      pkg.scripts.test,' '      0, // pkg.scripts.test,' && recarimbar "$SF_JS"
esperar 1 "T47 — agulha so em comentario NO FIM de linha de codigo => VERMELHO" 'nao codigo executavel'

reset
trocar_linha "$W/$SOCIALTELA" \
  "  group('Amigos — as listas vêm da autoridade', () {" \
  "  group('OUTRA COISA', () { // group('Amigos — as listas vêm da autoridade', () {" &&
  recarimbar "$SOCIALTELA"
esperar 1 "T48 — a mesma forja no dart, em comentario de fim de linha => VERMELHO" 'nao codigo executavel'

reset
rm -f "$W/scripts/ci/codigo_executavel.awk"
esperar 1 "T49 — analisador lexico apagado => VERMELHO, e nao permissivo" 'analisador lexico ausente'

reset
mv "$W/app/test/comunicacao/comunicacao_test.dart" "$W/app/test/comunicacao/comunicacao_test.txt"
sed -i 's|^\( *suite  *\)app/test/comunicacao/comunicacao_test.dart$|\1app/test/comunicacao/comunicacao_test.txt|' "$W/$FONTE_W"
esperar 1 "T50 — suite com extensao que o lexer nao conhece => VERMELHO" 'nao sabe ler'

printf '\n== as relacoes de conteudo, guardadas de FORA do manifesto que elas guardam ==\n'

# O SEGUNDO ESCAPE DA OS 40-R2. As relacoes protegiam a suite, e nada protegia as
# relacoes: retirar uma linha da fonte nao reprovava coisa nenhuma, e com a
# afirmacao apagada no mesmo commit a arvore ficava verde de ponta a ponta.

reset
sed -i '/^    exige      corpoDoCaso(GUARDA, "SF-01")$/d' "$W/$FONTE_W"
esperar 1 "T51 — relacao de conteudo retirada da fonte => VERMELHO" 'sumiu da fonte'

reset
sed -i 's|^    exige      corpoDoCaso(GUARDA, "SF-01")$|    exige      corpoDoCaso(GUARDA, "SF-99")|' "$W/$FONTE_W"
esperar 1 "T52 — relacao de conteudo renomeada => VERMELHO" 'nao esta congelada'

reset
sed -i 's|^    exige      test("SF-01:$|    exige      test("SF-01:\n    exige      test("SF-01:|' "$W/$FONTE_W"
esperar 1 "T53 — relacao duplicada para conservar a quantidade => VERMELHO" 'cardinalidade mudou'

reset
sed -i 's|^    suite      functions-ranking/test/superficie.test.js$|    suite      functions-ranking/test/composicao.test.js|' "$W/$FONTE_W"
esperar 1 "T54 — a segunda suite do gate trocada na fonte => VERMELHO" 'nao sao as congeladas'

reset
sed -i 's|^    alvo       functions-ranking/package.json$|    alvo       package.json|' "$W/$FONTE_W"
esperar 1 "T55 — o alvo trocado na fonte => VERMELHO" 'nao e o congelado'

reset
sed -i '/^    exige      corpoDoCaso(GUARDA, "SF-02")$/d' "$W/$FONTE_W"
sed -i '/corpoDoCaso(GUARDA, "SF-02")/d' "$W/functions-ranking/test/passe.test.js"
recarimbar "functions-ranking/test/passe.test.js"
esperar 1 "T56 — relacao E afirmacao retiradas juntas, com digest recarimbado => VERMELHO" 'sumiu da fonte'

printf '\n== a FASE B cobra log de TODO gate contratado, e a relacao vem da fonte ==\n'

reset
resultados "$TMP/res"
awk '{ l = $0; sub(/\r$/, "", l); print l }
     l == "analyze" && !f { print "    casos      1"; print "    contador   pass [0-9]+"; f = 1 }' \
  "$BASE/$FONTE_W" > "$W/$FONTE_W"
esperar 1 "T57 — gate que ganhou contrato e nao tem log => VERMELHO" 'nao deixou log' "$TMP/res"

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
