#!/usr/bin/env bash
# portao_os16.sh — o PORTÃO da OS 16 (Resultado Legível e Tocável).
#
# ---------------------------------------------------------------------------
# POR QUE ESTE ARQUIVO EXISTE
# ---------------------------------------------------------------------------
#
# A OS 16 entregou tela corrigida e suíte que mede a árvore renderizada. O que
# faltava era a CATRACA: nada impedia que a suíte fosse trocada por
# `expect(1+1, 2)`, que os pisos de 48 dp e 11 pt caíssem para 24 e 6, ou que
# os workflows sumissem — porque a ausência era tratada como conformidade.
#
# Este script é o verificador nomeado no contrato. Ele NÃO deriva nenhum valor
# esperado do artefato que audita:
#
#   * os pisos 48 e 11 estão fixados AQUI, em literal, fora do arquivo que os
#     declara (a tela) e fora do arquivo que os usa (a suíte);
#   * a identidade da suíte, sua cardinalidade, os nomes dos casos e o digest
#     dos bytes protegidos vêm do CONTRATO, que é externo à suíte e aos
#     workflows;
#   * o digest do próprio contrato é conferido contra a constante gravada na
#     AUTORIDADE (`auditoria_casca_test.dart`), que já é reconhecida pelos
#     gates. Recarimbar o contrato junto com a sabotagem não basta: seria
#     preciso recarimbar também a autoridade, e mesmo assim os pisos literais
#     deste arquivo continuariam reprovando.
#
# REGRA DURA: ausência é REPROVAÇÃO. Não existe caminho neste script em que um
# arquivo que não está lá produza saída zero.
#
# E a partir da OS 16-C2 a decisão sobre o PASSO dos workflows não é mais
# textual. A R2 reprovou a C1 porque cinco gestos de uma linha —
# `continue-on-error: true` depois de `run:`, `if: false` antes ou depois, e
# `exit 0` na linha seguinte dentro do mesmo `run:` — mantinham o caminho
# oficial verde sem o portão decidir nada. A seção 6b delega essa decisão à
# autoridade estrutural nomeada no contrato, que lê os três workflows com um
# parser YAML de verdade. Ela é o MESMO arquivo que a autoridade Dart dos gates
# importa: uma implementação, dois consumidores.
#
# Uso:   bash ferramentas/ci/portao_os16.sh [raiz-do-repositorio]
# Saída: 0 = VERDE.  1 = VERMELHO (todas as falhas são listadas).

set -uo pipefail

RAIZ="${1:-.}"
cd "$RAIZ" || { echo "PORTÃO OS 16: raiz '$RAIZ' inacessível."; exit 1; }

# ===========================================================================
# RÉGUA FIXA — fora de quem declara e de quem usa
# ===========================================================================
PISO_ALVO=48
PISO_FONTE=11
CONTRATO_ID='os16-resultado-legivel-tocavel'
CONTRATO_VERSAO='1.1.0'
CONTRATO='app/test/casca/contrato_os16_resultado.txt'
EU='ferramentas/ci/portao_os16.sh'

FALHAS=0
reprova() { echo "REPROVA [$1] $2"; FALHAS=$((FALHAS + 1)); }
ok()      { echo "  ok  $1"; }

# ===========================================================================
# FERRAMENTAS
# ===========================================================================

# Despoja um fonte Dart de comentários, respeitando aspas.
#   modo=nomes  -> mantém o conteúdo das strings (para achar nome de caso)
#   modo=codigo -> esvazia o conteúdo das strings (para contar código de
#                  verdade: um `test(` escrito DENTRO de string vira '' e some)
despoja() {
  awk -v modo="$2" '
    BEGIN { AS = sprintf("%c", 39); AD = "\""; bloco = 0; aspa = "" }
    {
      linha = $0; saida = ""; i = 1; n = length(linha)
      while (i <= n) {
        c = substr(linha, i, 1); d = (i < n) ? substr(linha, i + 1, 1) : ""
        if (bloco == 1) {
          if (c == "*" && d == "/") { bloco = 0; i += 2 } else { i += 1 }
          continue
        }
        if (aspa != "") {
          if (c == "\\") {
            if (modo == "nomes") { saida = saida c d }
            i += 2; continue
          }
          if (c == aspa) { aspa = ""; saida = saida c; i += 1; continue }
          if (modo == "nomes") { saida = saida c }
          i += 1; continue
        }
        if (c == "/" && d == "/") { break }
        if (c == "/" && d == "*") { bloco = 1; i += 2; continue }
        if (c == AS || c == AD) { aspa = c; saida = saida c; i += 1; continue }
        saida = saida c; i += 1
      }
      print saida
    }
  ' "$1"
}

# Digest dos bytes protegidos, com o CR fora. O repositório está em
# `core.autocrlf=true`: o MESMO commit chega em CRLF no Windows e em LF no
# runner do CI. Sem normalizar, o portão reprovaria a árvore íntegra numa das
# duas plataformas — e um portão que reprova o certo é tão inútil quanto um que
# aprova o errado. O que o digest protege é o CONTEÚDO, não o final de linha.
digest() { tr -d '\r' < "$1" | sha256sum | awk '{print $1}'; }

# O contrato é lido de uma cópia SEM CR, nunca do arquivo cru.
#
# Isto não é preciosismo: com `core.autocrlf=true` o mesmo commit chega em LF no
# runner e em CRLF no Windows. Os campos deste contrato são partidos por
# `awk '{print $3}'`, por `cut -d' ' -f3-` e por `-F'|'`, e nenhum deles trata
# `\r` como espaço — o último campo de cada linha viria com um CR grudado, e o
# portão reprovaria a árvore ÍNTEGRA. Um portão que reprova o certo destrói a
# confiança na catraca tão rápido quanto um que aprova o errado.
LIDO=$(mktemp)
trap 'rm -f "$LIDO"' EXIT
[ -f "$CONTRATO" ] && tr -d '\r' < "$CONTRATO" > "$LIDO"

# Valores do contrato. `campo <chave>` devolve a ÚNICA linha `chave: valor`.
campo() { sed -n -E "s/^${1}:[[:space:]]*(.*[^[:space:]])[[:space:]]*\$/\1/p" "$LIDO"; }
quantos() { grep -cE "^${1}:" "$LIDO" || true; }

# ===========================================================================
# 1. O CONTRATO EXISTE, É ÚNICO E É O ESPERADO
# ===========================================================================
echo "== 1. contrato externo"
if [ ! -f "$CONTRATO" ]; then
  reprova C01 "contrato ausente: $CONTRATO"
  echo; echo "PORTÃO OS 16: VERMELHO ($FALHAS falha(s)) — sem contrato não há o que verificar."
  exit 1
fi
if [ ! -s "$CONTRATO" ]; then
  reprova C02 "contrato vazio: $CONTRATO"
  echo; echo "PORTÃO OS 16: VERMELHO ($FALHAS falha(s))."
  exit 1
fi

for chave in contrato versao verificador autoridade suite suite_digest_sha256 \
             suite_casos suite_casos_executaveis produtivo \
             produtivo_digest_sha256 piso_alvo_dp \
             piso_fonte_pt invocacao instrumento_max_rolagens \
             instrumento_timeout_s passo_autoridade \
             passo_autoridade_digest_sha256 passo_cli \
             passo_cli_digest_sha256 passo_cli_invocacao; do
  n=$(quantos "$chave")
  [ "$n" = "1" ] || reprova C03 "chave '$chave' aparece $n vez(es) no contrato — esperava exatamente 1"
done

[ "$(campo contrato)" = "$CONTRATO_ID" ] \
  || reprova C04 "identidade do contrato divergente: '$(campo contrato)' != '$CONTRATO_ID'"
[ "$(campo versao)" = "$CONTRATO_VERSAO" ] \
  || reprova C05 "versão do contrato inesperada: '$(campo versao)' != '$CONTRATO_VERSAO'"
[ "$(campo verificador)" = "$EU" ] \
  || reprova C06 "o contrato aponta outro verificador: '$(campo verificador)' != '$EU'"
[ -f "$EU" ] || reprova C07 "o verificador nomeado no contrato não está na árvore: $EU"
[ "$FALHAS" = "0" ] && ok "contrato $CONTRATO_ID v$CONTRATO_VERSAO íntegro"

# ===========================================================================
# 2. PISOS — 48 dp e 11 pt, fixados aqui
# ===========================================================================
echo "== 2. pisos"
[ "$(campo piso_alvo_dp)" = "$PISO_ALVO" ] \
  || reprova P01 "piso de alvo tocável no contrato é '$(campo piso_alvo_dp)' — a régua deste portão é $PISO_ALVO"
[ "$(campo piso_fonte_pt)" = "$PISO_FONTE" ] \
  || reprova P02 "piso tipográfico no contrato é '$(campo piso_fonte_pt)' — a régua deste portão é $PISO_FONTE"

# Cada `declaracao:` é `<arquivo> <simbolo> <valor>`. O valor tem de bater com
# a régua FIXA acima, e o símbolo tem de ter UMA única atribuição no arquivo —
# é isso que impede a atribuição-isca (a legítima escondida atrás de outra).
DECLS=$(sed -n -E 's/^declaracao:[[:space:]]*//p' "$LIDO")
[ -n "$DECLS" ] || reprova P03 "o contrato não declara nenhuma atribuição de piso"
while IFS= read -r linha; do
  [ -n "$linha" ] || continue
  arq=$(echo "$linha" | awk '{print $1}')
  sim=$(echo "$linha" | awk '{print $2}')
  val=$(echo "$linha" | awk '{print $3}')
  if [ ! -f "$arq" ]; then reprova P04 "declaração aponta arquivo ausente: $arq"; continue; fi
  case "$val" in
    "$PISO_ALVO"|"$PISO_FONTE") ;;
    *) reprova P05 "declaração '$sim' do contrato vale '$val', fora da régua ($PISO_ALVO / $PISO_FONTE)" ;;
  esac
  vista=$(despoja "$arq" codigo)
  achadas=$(echo "$vista" | grep -E "(^|[^A-Za-z0-9_])${sim}[[:space:]]*=[^=]" || true)
  n=$(echo "$achadas" | grep -c . || true)
  if [ "$n" != "1" ]; then
    reprova P06 "'$sim' tem $n atribuição(ões) efetiva(s) em $arq — esperava exatamente 1"
    continue
  fi
  bruto=$(echo "$achadas" | sed -E "s/.*${sim}[[:space:]]*=[[:space:]]*([0-9]+(\.[0-9]+)?).*/\1/")
  norm=$(awk -v v="$bruto" 'BEGIN { printf "%g", v + 0 }')
  if [ "$norm" != "$val" ]; then
    reprova P07 "'$sim' em $arq vale $norm — o contrato e a régua exigem $val"
  else
    ok "$sim = $norm em $arq"
  fi
done <<EOF
$DECLS
EOF

# ===========================================================================
# 3. A SUÍTE OFICIAL — caminho, digest, cardinalidade, nomes
# ===========================================================================
echo "== 3. suíte oficial"
SUITE=$(campo suite)
SUITE_ESPERADA='app/test/casca/a11y_resultado_partida_test.dart'
[ "$SUITE" = "$SUITE_ESPERADA" ] \
  || reprova S01 "caminho da suíte redirecionado: '$SUITE' != '$SUITE_ESPERADA'"
if [ ! -f "$SUITE_ESPERADA" ]; then
  reprova S02 "suíte oficial ausente: $SUITE_ESPERADA"
else
  d=$(digest "$SUITE_ESPERADA")
  [ "$d" = "$(campo suite_digest_sha256)" ] \
    || reprova S03 "digest da suíte divergente: $d != $(campo suite_digest_sha256)"

  codigo=$(despoja "$SUITE_ESPERADA" codigo)
  nomes=$(despoja "$SUITE_ESPERADA" nomes)

  casos=$(echo "$codigo" | grep -oE "(^|[^A-Za-z0-9_])(testWidgets|test)[[:space:]]*\(" | grep -c . || true)
  esperados=$(campo suite_casos)
  [ "$casos" = "$esperados" ] \
    || reprova S04 "cardinalidade da suíte: $casos caso(s) executável(is), o contrato exige $esperados"

  declarados=$(quantos caso)
  [ "$declarados" = "$esperados" ] \
    || reprova S05 "o contrato lista $declarados nome(s) de caso para uma cardinalidade de $esperados"

  # Uma passada só: cada nome do contrato tem de casar EXATAMENTE uma vez no
  # fonte despojado. (Um `grep` por nome custaria 36 processos — nesta máquina
  # isso é minuto, não milissegundo.)
  # O fonte vai por ARQUIVO, nunca por `awk -v`: `-v` interpreta sequências de
  # escape, e um `\s` de RegExp dentro da suíte chegaria adulterado ao alvo da
  # busca. O comparador tem de ver os bytes que existem.
  vista_nomes=$(mktemp)
  printf '%s\n' "$nomes" > "$vista_nomes"
  problemas=$(sed -n -E 's/^caso:[[:space:]]*//p' "$LIDO" \
    | awk -v arq="$vista_nomes" '
        BEGIN { alvo = ""; while ((getline l < arq) > 0) alvo = alvo l "\n" }
        { if ($0 == "") next
          n = 0; resto = alvo
          while ((p = index(resto, $0)) > 0) { n++; resto = substr(resto, p + length($0)) }
          if (n != 1) printf "%d\t%s\n", n, $0
        }')
  rm -f "$vista_nomes"
  if [ -n "$problemas" ]; then
    while IFS=$'\t' read -r n nome; do
      [ -n "$nome" ] || continue
      if [ "$n" = "0" ]; then reprova S06 "caso obrigatório ausente ou renomeado: $nome"
      else reprova S07 "caso obrigatório aparece $n vezes: $nome"; fi
    done <<EOF
$problemas
EOF
  else
    ok "$esperados casos nominais presentes e únicos"
  fi

  # Exigências de comportamento: o piso tem de ser COBRADO, não só declarado.
  # Sem isto, trocar `greaterThanOrEqualTo(kAlvoMinimo)` por um número solto
  # deixaria a constante intacta e a prova oca.
  while IFS= read -r linha; do
    [ -n "$linha" ] || continue
    arq=$(echo "$linha" | awk '{print $1}')
    min=$(echo "$linha" | awk '{print $2}')
    exp=$(echo "$linha" | cut -d' ' -f3-)
    if [ ! -f "$arq" ]; then reprova S08 "exigência aponta arquivo ausente: $arq"; continue; fi
    n=$(despoja "$arq" codigo | grep -cF -- "$exp" || true)
    if [ "$n" -lt "$min" ]; then
      reprova S09 "'$exp' aparece $n vez(es) em $arq — o contrato exige ao menos $min"
    else
      ok "'$exp' x$n em $(basename "$arq")"
    fi
  done <<EOF
$(sed -n -E 's/^exigencia:[[:space:]]*//p' "$LIDO")
EOF
fi

# ===========================================================================
# 4. O PRODUTO — byte a byte igual ao que a OS 16 aprovou
# ===========================================================================
echo "== 4. produto"
PROD=$(campo produtivo)
PROD_ESPERADO='app/lib/screens/resultado_partida_screen.dart'
[ "$PROD" = "$PROD_ESPERADO" ] \
  || reprova T01 "caminho do produtivo redirecionado: '$PROD' != '$PROD_ESPERADO'"
if [ ! -f "$PROD_ESPERADO" ]; then
  reprova T02 "tela produtiva ausente: $PROD_ESPERADO"
else
  d=$(digest "$PROD_ESPERADO")
  if [ "$d" = "$(campo produtivo_digest_sha256)" ]; then
    ok "tela produtiva intacta"
  else
    reprova T03 "digest da tela produtiva divergente: $d != $(campo produtivo_digest_sha256)"
  fi
fi

# ===========================================================================
# 5. A AUTORIDADE INDEPENDENTE CARIMBA O CONTRATO
# ===========================================================================
echo "== 5. autoridade"
AUT=$(campo autoridade)
AUT_ESPERADA='app/test/casca/auditoria_casca_test.dart'
[ "$AUT" = "$AUT_ESPERADA" ] \
  || reprova A01 "autoridade redirecionada: '$AUT' != '$AUT_ESPERADA'"
if [ ! -f "$AUT_ESPERADA" ]; then
  reprova A02 "autoridade ausente: $AUT_ESPERADA — é ela que roda nos gates"
else
  dc=$(digest "$CONTRATO")
  vista=$(despoja "$AUT_ESPERADA" nomes)
  n=$(echo "$vista" | grep -cF -- "$dc" || true)
  if [ "$n" -lt 1 ]; then
    reprova A03 "a autoridade não carimba o digest deste contrato ($dc) — recarimbar o contrato sozinho passaria despercebido"
  else
    ok "autoridade carimba o contrato ($dc)"
  fi
  echo "$vista" | grep -qF "kPisoAlvoOS16 = $PISO_ALVO" \
    || reprova A04 "a autoridade não fixa o piso de alvo em $PISO_ALVO"
  echo "$vista" | grep -qF "kPisoFonteOS16 = $PISO_FONTE" \
    || reprova A05 "a autoridade não fixa o piso tipográfico em $PISO_FONTE"
  echo "$vista" | grep -qF "kVersaoContratoOS16 = " \
    || reprova A06 "a autoridade não fixa a versão do contrato"
  echo "$vista" | grep -qF "$CONTRATO_VERSAO" \
    || reprova A07 "a autoridade não conhece a versão $CONTRATO_VERSAO do contrato"
fi

# ===========================================================================
# 6. OS TRÊS WORKFLOWS — ausência REPROVA
# ===========================================================================
echo "== 6. workflows"
INVOC=$(campo invocacao)
LINHAS_WF=$(sed -n -E 's/^workflow:[[:space:]]*//p' "$LIDO")
n_wf=$(echo "$LINHAS_WF" | grep -c . || true)
if [ "$n_wf" != "3" ]; then
  reprova W00 "o contrato enumera $n_wf workflow(s) — a OS 16 protege exatamente 3"
fi
while IFS= read -r linha; do
  [ -n "$linha" ] || continue
  arq=$(echo "$linha"   | awk -F'|' '{gsub(/^ +| +$/,"",$1); print $1}')
  passo=$(echo "$linha" | awk -F'|' '{gsub(/^ +| +$/,"",$2); print $2}')
  ancora=$(echo "$linha" | awk -F'|' '{gsub(/^ +| +$/,"",$3); print $3}')

  if [ ! -f "$arq" ]; then
    reprova W01 "workflow ausente: $arq — ausência NÃO é conformidade"
    continue
  fi

  f0=$FALHAS

  # Invocação VIVA: linha de comando, não comentário, não texto de echo/printf,
  # não corpo de heredoc, sem `|| true` e sem redirecionar a decisão.
  vivas=$(grep -nF -- "$INVOC" "$arq" | awk -F: -v inv="$INVOC" '
    BEGIN { AS = sprintf("%c", 39) }
    {
      ln = $1
      linha = $0
      sub(/^[0-9]+:/, "", linha)
      corte = linha
      gsub(/^[[:space:]]+/, "", corte)
      if (substr(corte, 1, 1) == "#") next
      p = index(linha, inv)
      if (p == 0) next
      antes = substr(linha, 1, p - 1)
      if (antes ~ /echo|printf|<</) next
      nd = 0; ns = 0
      for (k = 1; k <= length(antes); k++) {
        ch = substr(antes, k, 1)
        if (ch == "\"") nd++
        if (ch == AS) ns++
      }
      if (nd % 2 == 1) next
      if (ns % 2 == 1) next
      print ln
    }')
  n=$(echo "$vivas" | grep -c . || true)
  if [ "$n" = "0" ]; then
    reprova W02 "$arq não invoca o portão da OS 16 ('$INVOC') de forma viva"
    continue
  fi
  if [ "$n" != "1" ]; then
    reprova W03 "$arq invoca o portão $n vezes — invocação duplicada"
    continue
  fi
  ln=$(echo "$vivas" | head -1)
  texto=$(sed -n "${ln}p" "$arq")
  case "$texto" in
    *"|| true"*|*"|| :"*|*"||:"*|*"|| echo"*|*"/bin/true"*|*"; true"*|*"|| exit 0"*|*"|| continue"*)
      reprova W04 "$arq:$ln neutraliza a saída do portão: $texto" ;;
    *">/dev/null"*|*"> /dev/null"*)
      reprova W05 "$arq:$ln redireciona a saída do portão: $texto" ;;
    *)
      ;;
  esac

  # PASSO CORRETO: a invocação vive dentro do passo nomeado pelo contrato, e
  # esse passo vem ANTES da âncora (o que o workflow produz e que não pode sair
  # sem o portão ter rodado).
  ln_passo=$(grep -nF -- "$passo" "$arq" | head -1 | cut -d: -f1)
  if [ -z "$ln_passo" ]; then
    reprova W06 "$arq não tem o passo '$passo' exigido pelo contrato"
  elif [ "$ln" -lt "$ln_passo" ]; then
    reprova W07 "$arq: a invocação (linha $ln) está fora do passo '$passo' (linha $ln_passo)"
  fi
  ln_ancora=$(grep -nF -- "$ancora" "$arq" | head -1 | cut -d: -f1)
  if [ -z "$ln_ancora" ]; then
    reprova W08 "$arq perdeu a âncora '$ancora' — o portão não guarda mais nada"
  elif [ "$ln" -gt "$ln_ancora" ]; then
    reprova W09 "$arq: o portão (linha $ln) foi deslocado para DEPOIS de '$ancora' (linha $ln_ancora)"
  fi

  # A decisão final não pode ser convertida em verde por configuração do passo.
  if [ -n "$ln_passo" ]; then
    if awk -v a="$ln_passo" -v b="$ln" 'NR >= a && NR <= b' "$arq" \
         | grep -qE "continue-on-error:[[:space:]]*true"; then
      reprova W10 "$arq: o passo do portão está com continue-on-error: true"
    fi
  fi

  [ "$FALHAS" = "$f0" ] \
    && ok "$arq: portão vivo na linha $ln, dentro de '$passo', antes de '$ancora'"
done <<EOF
$LINHAS_WF
EOF

# ===========================================================================
# 6b. O PASSO LIDO COMO YAML — a decisão que a OS 16-R2 exigiu
# ===========================================================================
#
# A seção 6 acima é TEXTUAL: linha, substring, janela entre o nome do passo e a
# invocação. Ela continua valendo — é barata e pega o grosso —, mas a R2 provou
# que ela não basta. Cinco gestos de uma linha mantinham o caminho oficial
# verde:
#
#   `continue-on-error: true` DEPOIS de `run:` (fora da janela), `if: false`
#   antes ou depois dele (ninguém olhava `if:`), e `exit 0` na linha seguinte
#   dentro do mesmo `run:` (a linha da invocação continuava impecável).
#
# `if:`, `continue-on-error:` e o corpo de um `run:` não são texto próximo: são
# NÓS de um documento YAML. Bash não tem parser YAML — Dart tem, e o SDK está no
# PATH dos três workflows, que configuram o Flutter antes deste passo.
#
# A decisão é delegada à autoridade estrutural do contrato. Ela NÃO é uma
# segunda implementação: é o MESMO arquivo que `auditoria_casca_test.dart`
# importa. As duas autoridades não têm como discordar porque não são duas.
#
# Ausência de ferramenta é REPROVAÇÃO. Não há caminho aqui em que `dart`
# faltando, pacote não resolvido ou exceção do parser produza saída zero.
echo "== 6b. estrutura do passo (YAML real)"
PASSO_AUT=$(campo passo_autoridade)
PASSO_CLI=$(campo passo_cli)
PASSO_INV=$(campo passo_cli_invocacao)
PASSO_AUT_ESPERADA='app/test/casca/passo_os16_yaml.dart'
PASSO_CLI_ESPERADA='ferramentas/ci/passo_os16/bin/passo_os16.dart'
PASSO_INV_ESPERADA='dart run ferramentas/ci/passo_os16/bin/passo_os16.dart'
PASSO_PKG='ferramentas/ci/passo_os16'

f0=$FALHAS

[ "$PASSO_AUT" = "$PASSO_AUT_ESPERADA" ] \
  || reprova E01 "autoridade estrutural redirecionada: '$PASSO_AUT' != '$PASSO_AUT_ESPERADA'"
[ "$PASSO_CLI" = "$PASSO_CLI_ESPERADA" ] \
  || reprova E02 "CLI da autoridade estrutural redirecionada: '$PASSO_CLI' != '$PASSO_CLI_ESPERADA'"
[ "$PASSO_INV" = "$PASSO_INV_ESPERADA" ] \
  || reprova E03 "invocação contratada da CLI divergente: '$PASSO_INV' != '$PASSO_INV_ESPERADA'"

# Os bytes das duas peças, contra o contrato. Esvaziar a autoridade estrutural
# tem de reprovar tão rápido quanto sabotar o workflow.
for par in "$PASSO_AUT_ESPERADA|passo_autoridade_digest_sha256" \
           "$PASSO_CLI_ESPERADA|passo_cli_digest_sha256"; do
  arq=${par%%|*}
  chave=${par##*|}
  if [ ! -f "$arq" ]; then
    reprova E04 "peça da autoridade estrutural ausente: $arq — ausência NÃO é conformidade"
    continue
  fi
  d=$(digest "$arq")
  [ "$d" = "$(campo "$chave")" ] \
    || reprova E05 "digest de $arq divergente: $d != $(campo "$chave")"
done

[ -f "$PASSO_PKG/pubspec.yaml" ] \
  || reprova E06 "o pacote que dá package:yaml sumiu: $PASSO_PKG/pubspec.yaml"

# A CLI tem de IMPORTAR a autoridade, não reimplementá-la por conta própria.
if [ -f "$PASSO_CLI_ESPERADA" ]; then
  grep -qF -- 'passo_os16_yaml.dart' "$PASSO_CLI_ESPERADA" \
    || reprova E07 "a CLI não importa mais $PASSO_AUT_ESPERADA — viraria uma segunda opinião"
fi

if ! command -v dart >/dev/null 2>&1; then
  reprova E08 "o SDK do Dart não está no PATH — sem ele NÃO há leitura estrutural do YAML, e ferramenta ausente é REPROVAÇÃO, nunca conformidade"
elif [ ! -f "$PASSO_CLI_ESPERADA" ] || [ ! -f "$PASSO_AUT_ESPERADA" ]; then
  reprova E09 "a autoridade estrutural não está na árvore — nada a executar"
else
  if ! ( cd "$PASSO_PKG" && { dart pub get --offline || dart pub get; } ) >/dev/null 2>&1; then
    reprova E10 "package:yaml não pôde ser resolvido para $PASSO_PKG — a leitura estrutural NÃO roda, e isso é vermelho"
  fi
  SAIDA_PASSO=$(dart run ferramentas/ci/passo_os16/bin/passo_os16.dart . 2>&1)
  RC_PASSO=$?
  printf '%s\n' "$SAIDA_PASSO" | sed 's/^/  /'
  [ "$RC_PASSO" = "0" ] \
    || reprova E11 "a autoridade estrutural do passo REPROVOU (saída $RC_PASSO)"
fi

[ "$FALHAS" = "$f0" ] && ok "os três passos são canônicos pela leitura do YAML"

# ===========================================================================
# 7. INSTRUMENTO — os tetos ficam registrados no contrato
# ===========================================================================
echo "== 7. instrumento"
for k in instrumento_max_rolagens instrumento_timeout_s; do
  v=$(campo "$k")
  case "$v" in
    ''|*[!0-9]*) reprova I01 "'$k' não é um teto numérico: '$v'" ;;
    *) [ "$v" -gt 0 ] || reprova I02 "'$k' tem de ser positivo: '$v'" ;;
  esac
done
MAXROL=$(campo instrumento_max_rolagens)
if [ -f "$SUITE_ESPERADA" ]; then
  vs=$(despoja "$SUITE_ESPERADA" codigo)
  n_scroll=$(echo "$vs" | grep -cF 'scrollUntilVisible' || true)
  n_teto=$(echo "$vs" | grep -cF 'maxScrolls:' || true)
  if [ "$n_scroll" != "$n_teto" ]; then
    reprova I03 "a suíte tem $n_scroll rolagem(ns) e $n_teto teto(s) 'maxScrolls:' — repetição sem teto pode travar"
  else
    ok "$n_scroll rolagem(ns), todas com teto declarado"
  fi
  achadas=$(echo "$vs" | grep -E "(^|[^A-Za-z0-9_])kMaxRolagens[[:space:]]*=[^=]" || true)
  n=$(echo "$achadas" | grep -c . || true)
  if [ "$n" != "1" ]; then
    reprova I04 "'kMaxRolagens' tem $n atribuição(ões) na suíte — esperava exatamente 1"
  else
    v=$(echo "$achadas" | sed -E 's/.*kMaxRolagens[[:space:]]*=[[:space:]]*([0-9]+).*/\1/')
    [ "$v" = "$MAXROL" ] \
      || reprova I05 "o teto de rolagem da suíte é $v e o contrato registra $MAXROL"
  fi
  echo "$vs" | grep -q '@Timeout' \
    || reprova I06 "a suíte não declara @Timeout — o limite tem de viajar com o arquivo"
fi

# ===========================================================================
echo
if [ "$FALHAS" = "0" ]; then
  echo "PORTÃO OS 16: VERDE — contrato $CONTRATO_ID v$CONTRATO_VERSAO, pisos $PISO_ALVO dp / $PISO_FONTE pt, 3 passos canônicos lidos como YAML."
  exit 0
fi
echo "PORTÃO OS 16: VERMELHO — $FALHAS falha(s)."
exit 1
