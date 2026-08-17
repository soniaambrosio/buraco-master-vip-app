#!/usr/bin/env bash
#
# TESTE DO PRÓPRIO PORTÃO — gate `portaoci` de `ci-os-integracao.yml`.
#
#   uso: bash scripts/ci/teste_portao_os_integracao.sh
#
# Roda sem GitHub Actions, sem rede, sem Flutter e sem Node: só bash e um
# diretório temporário. É o único lugar onde o agregador — a peça que decide se
# TODO o resto foi verde — é ele mesmo verificado.
#
# A matriz cobre os treze casos exigidos pela OS, mais as invariantes de fonte
# única. Cada caso é identificável por nome na saída, para que uma mutação
# derrube um caso nomeado e não apenas "o teste".
#
# Exit 0 = matriz inteira passou. Exit 1 = ao menos um caso falhou.

set -u

AQUI="$(cd "$(dirname "$0")" && pwd)"
RAIZ="$(cd "$AQUI/../.." && pwd)"
PORTAO="$AQUI/portao_os_integracao.sh"
FONTE="$AQUI/gates_os_integracao.txt"
YML="$RAIZ/.github/workflows/ci-os-integracao.yml"

for arquivo in "$PORTAO" "$FONTE" "$YML"; do
  if [ ! -f "$arquivo" ]; then
    printf 'teste do portão: arquivo obrigatório ausente: %s\n' "$arquivo" >&2
    exit 1
  fi
done

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
RES="$TMP/resultados"

passou=0
falhou=0

ok()  { passou=$((passou + 1)); printf '  ok    %s\n' "$1"; }
nok() { falhou=$((falhou + 1)); printf '  FALHA %s\n' "$1"; }

# Mesma regra de leitura do agregador: sem comentário de fim de linha, sem CR,
# aparando início e fim. Se divergir do agregador, os casos 1 e 13 quebram.
gates_da_fonte() {
  sed -e 's/\r$//' "$FONTE" \
    | awk '{ gsub(/^[ \t]+|[ \t]+$/, "") } NF && substr($0,1,1) != "#" { print }'
}

# Lido UMA vez: `reset_verde` roda a cada caso, e reabrir sed+awk vinte vezes
# custa mais que a matriz inteira em máquina onde `fork` é caro.
GATES_FONTE="$(gates_da_fonte)"

reset_verde() {
  rm -rf "$RES"
  mkdir -p "$RES"
  local g
  for g in $GATES_FONTE; do
    printf '0\n' > "$RES/exit_$g"
  done
}

# esperar <exit-esperado> <descrição> [regex que a saída DEVE conter]
esperar() {
  local esperado="$1" desc="$2" agulha="${3:-}" real
  bash "$PORTAO" "$FONTE" "$RES" > "$TMP/saida.txt" 2>&1
  real=$?
  if [ "$real" != "$esperado" ]; then
    nok "$desc — esperado exit $esperado, obtido $real"
    sed 's/^/        | /' "$TMP/saida.txt"
    return
  fi
  if [ -n "$agulha" ] && ! grep -qE "$agulha" "$TMP/saida.txt"; then
    nok "$desc — exit $real correto, mas a saída não identifica o gate (/$agulha/)"
    sed 's/^/        | /' "$TMP/saida.txt"
    return
  fi
  ok "$desc (exit $real)"
}

contem_gate() {
  local g
  for g in $GATES_FONTE; do [ "$g" = "$1" ] && return 0; done
  return 1
}

printf '== invariantes da fonte única ==\n'

# A fonte tem que continuar declarando TODO gate que já era obrigatório antes
# desta OS. Remover um deles é uma regressão silenciosa de cobertura.
HERDADOS="analyze motor resil encerr torneios mtorneios integr colarte colfire \
colkit social casca cascaaud billing torneiosfn socialdom socialfn socialemu regras"
faltando=""
for g in $HERDADOS; do
  contem_gate "$g" || faltando="$faltando $g"
done
if [ -z "$faltando" ]; then
  ok "I1 — os 19 gates herdados continuam na fonte única"
else
  nok "I1 — gate herdado removido da fonte única:$faltando"
fi

# Os quatro do defeito CI-02: executavam e o agregador não os percorria.
faltando=""
for g in rankingfn rankingint identint auditident; do
  contem_gate "$g" || faltando="$faltando $g"
done
if [ -z "$faltando" ]; then
  ok "I2 — rankingfn/rankingint/identint/auditident são obrigatórios (CI-02)"
else
  nok "I2 — gate do CI-02 fora da fonte única:$faltando"
fi

# As suítes que esta OS traz para dentro do portão (CI-01).
faltando=""
for g in cascavisao cascamesaaud cascav2 cascaligacao cascamesa cascaporta \
         rkbarreira rkestado rkperfil rkleitor rkregressao composicao portaoci; do
  contem_gate "$g" || faltando="$faltando $g"
done
if [ -z "$faltando" ]; then
  ok "I3 — as 12 suítes novas + o teste do portão são obrigatórios (CI-01)"
else
  nok "I3 — suíte nova fora da fonte única:$faltando"
fi

# O gerador de PNG continua FORA do portão, como decidido antes desta OS.
if contem_gate colevid; then
  nok "I4 — colevid entrou no portão; ele é informativo por decisão registrada"
else
  ok "I4 — colevid segue informativo, fora da fonte única"
fi

# Fonte única de verdade: o YAML não pode carregar uma segunda cópia da lista.
# Este é o caso que a mutação "manter listas diferentes entre evidência e
# agregador" derruba.
if grep -qE 'for k in [a-z]+ [a-z]+ [a-z]+' "$YML" \
   || grep -qE 'GATES="[a-z]+ [a-z]+' "$YML"; then
  nok "I5 — o YAML ainda tem uma lista de gates embutida; a fonte deixou de ser única"
else
  ok "I5 — o YAML não embute lista de gates"
fi

if grep -q 'scripts/ci/gates_os_integracao.txt' "$YML" \
   && grep -q 'scripts/ci/portao_os_integracao.sh' "$YML"; then
  ok "I6 — evidência e agregador apontam para a fonte única no YAML"
else
  nok "I6 — o YAML não referencia a fonte única e/ou o agregador"
fi

printf '\n== matriz do agregador ==\n'

# 1 — todos os gates com exit 0 -> verde.
reset_verde
esperar 0 "C01 — todos os obrigatórios em exit 0 => VERDE"

# 2 — gate Flutter de ranking com exit 1 -> vermelho.
reset_verde
printf '1\n' > "$RES/exit_rkleitor"
esperar 1 "C02 — suíte Flutter de ranking (rkleitor) exit 1 => VERMELHO" \
          'rkleitor +VERMELHO'

# 3 — gate da composição com exit 1 -> vermelho.
reset_verde
printf '1\n' > "$RES/exit_composicao"
esperar 1 "C03 — composicao exit 1 => VERMELHO" 'composicao +VERMELHO'

# 4..7 — os quatro gates que escapavam do agregador antes desta OS.
for g in rankingfn rankingint identint auditident; do
  reset_verde
  printf '1\n' > "$RES/exit_$g"
  esperar 1 "C0? — $g exit 1 => VERMELHO (CI-02)" "$g +VERMELHO"
done

# 8 — marcador nao_<gate> -> vermelho.
reset_verde
rm -f "$RES/exit_regras"
printf 'firebase/testes/package.json ausente\n' > "$RES/nao_regras"
esperar 1 "C08 — marcador nao_regras => VERMELHO (CI-03)" 'regras +NAO EXECUTADO'

# 8b — marcador CONVIVENDO com um exit 0 remanescente: o marcador vence.
reset_verde
printf 'passo abortou antes de rodar\n' > "$RES/nao_socialemu"
esperar 1 "C08b — nao_socialemu ao lado de exit 0 => VERMELHO" 'socialemu +NAO EXECUTADO'

# 9 — gate sem exit e sem marcador -> vermelho.
reset_verde
rm -f "$RES/exit_casca"
esperar 1 "C09 — casca sem exit e sem marcador => VERMELHO (CI-03)" 'casca +NAO EXECUTADO'

# 10 — exit vazio -> vermelho.
reset_verde
: > "$RES/exit_motor"
esperar 1 "C10 — exit_motor vazio => VERMELHO" 'motor +INVALIDO'

# 10b — exit só com espaço em branco também é vazio.
reset_verde
printf '   \n\n' > "$RES/exit_motor"
esperar 1 "C10b — exit_motor só com espaços => VERMELHO" 'motor +INVALIDO'

# 11 — exit não numérico -> vermelho.
reset_verde
printf 'ok\n' > "$RES/exit_analyze"
esperar 1 "C11 — exit_analyze não numérico => VERMELHO" 'analyze +INVALIDO'

# 11b — conteúdo que tentaria virar comando se algo fosse interpretado.
reset_verde
printf '0; rm -rf /\n' > "$RES/exit_billing"
esperar 1 "C11b — exit_billing com injeção de comando => VERMELHO, sem interpretar" \
          'billing +INVALIDO'

# 12 — gate desconhecido não apaga nem substitui um obrigatório.
reset_verde
printf '1\n' > "$RES/exit_gate_fantasma"
esperar 0 "C12a — gate desconhecido vermelho NÃO reprova o portão" 'gate_fantasma +IGNORADO'

reset_verde
rm -f "$RES/exit_composicao"
printf '0\n' > "$RES/exit_composicao_extra"
esperar 1 "C12b — gate desconhecido verde NÃO substitui composicao ausente" \
          'composicao +NAO EXECUTADO'

# 13 — tudo restaurado para zero -> verde de novo.
reset_verde
esperar 0 "C13 — obrigatórios restaurados em exit 0 => VERDE novamente"

printf '\n== fonte única inválida (falha fechada) ==\n'

# Fonte vazia não pode ser "nenhum obrigatório, logo verde".
reset_verde
: > "$TMP/vazia.txt"
bash "$PORTAO" "$TMP/vazia.txt" "$RES" > /dev/null 2>&1
[ "$?" = "2" ] && ok "C14 — fonte sem nenhum gate => exit 2 (reprova)" \
                || nok "C14 — fonte sem nenhum gate deveria dar exit 2"

# Nome com travessia de caminho reprova antes de virar leitura de arquivo.
printf '../../etc/passwd\n' > "$TMP/travessia.txt"
bash "$PORTAO" "$TMP/travessia.txt" "$RES" > /dev/null 2>&1
[ "$?" = "2" ] && ok "C15 — nome de gate com travessia de caminho => exit 2" \
                || nok "C15 — nome de gate com travessia deveria dar exit 2"

# Gate duplicado na fonte é erro de manutenção, não silêncio.
printf 'analyze\nanalyze\n' > "$TMP/dup.txt"
bash "$PORTAO" "$TMP/dup.txt" "$RES" > /dev/null 2>&1
[ "$?" = "2" ] && ok "C16 — gate duplicado na fonte => exit 2" \
                || nok "C16 — gate duplicado deveria dar exit 2"

# Fonte inexistente reprova.
bash "$PORTAO" "$TMP/nao_existe.txt" "$RES" > /dev/null 2>&1
[ "$?" = "2" ] && ok "C17 — fonte única ausente => exit 2" \
                || nok "C17 — fonte única ausente deveria dar exit 2"

# Diretório de resultados inexistente reprova.
bash "$PORTAO" "$FONTE" "$TMP/sem_dir" > /dev/null 2>&1
[ "$?" = "2" ] && ok "C18 — diretório de resultados ausente => exit 2" \
                || nok "C18 — diretório ausente deveria dar exit 2"

printf '\n----------------------------------------\n'
printf 'casos ok: %d | casos com falha: %d\n' "$passou" "$falhou"

if [ "$falhou" -eq 0 ]; then
  printf 'TESTE DO PORTÃO: VERDE\n'
  exit 0
fi

printf 'TESTE DO PORTÃO: VERMELHO\n'
exit 1
