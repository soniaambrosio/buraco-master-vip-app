#!/usr/bin/env bash
#
# TESTEMUNHA EXTERNA DO GATE `contratosui`.
#
#   uso: bash scripts/ci/testemunha_contratosui.sh <matriz> [dir_evidencia]
#
# ---------------------------------------------------------------------------
# POR QUE ELA EXISTE
# ---------------------------------------------------------------------------
#
# Ate a OS 40-C3, `teste_contrato_suites.sh` produzia sozinho a evidencia que o
# julgava: ele contava os proprios casos, escrevia o proprio rodape e devolvia o
# proprio exit. A rehomologacao OS 40-R3 mediu o que isso custa — vinte e sete
# casos apagados, a contagem de `provas` reposta por um heredoc e um rodape
# `casos ok: 57 | casos com falha: 0` forjado no fim do arquivo. O gate ficou
# VERDE com a matriz destruida, e um dos casos reais chegou a imprimir
# `contrato de suites: REPROVADO` no meio do caminho.
#
# Uma peca que emite o proprio boletim nao e verificada por ninguem. Esta
# testemunha e a segunda assinatura: ela nao pergunta a matriz como foi, ela
# EXECUTA caso por caso e OLHA o exit de cada processo.
#
# ---------------------------------------------------------------------------
# DE ONDE VEM A AUTORIDADE
# ---------------------------------------------------------------------------
#
# O inventario dos casos obrigatorios esta ESCRITO AQUI, por extenso, e nao e
# derivado da matriz. Isso e a diferenca entre testemunhar e repetir: uma lista
# lida da matriz encolheria junto com ela, e vinte e sete casos apagados
# passariam a ser "os casos que existem".
#
# `--listar-casos` NAO e a fonte dos identificadores. Ele e PROVA RECIPROCA: a
# testemunha compara o que a matriz anuncia com o que ela propria exige, e
# recusa ausente, duplicado, estranho e ordem trocada. As duas relacoes tem de
# coincidir; quando divergem, quem manda e esta.
#
# E a matriz tambem nao decide se um caso rodou: cada `--caso <ID>` tem de
# ANUNCIAR o identificador que recebeu (`ATIVO <id>`), sair com codigo proprio,
# e nao imprimir placar nenhum. Um caso que nao existe tem de sair diferente de
# zero — e isso e testado com um identificador fabricado ANTES de confiar nos
# sessenta e oito.
#
# ---------------------------------------------------------------------------
# O QUE ELA RECUSA
# ---------------------------------------------------------------------------
#
#   * identificador do inventario que a matriz nao declara
#   * identificador que a matriz declara e o inventario nao tem
#   * identificador repetido na relacao da matriz
#   * ordem de execucao diferente da congelada
#   * caso que sai zero sem ter sido alcancado (testado por sonda)
#   * caso cujo anuncio `ATIVO` nao bate com o identificador pedido
#   * caso que imprime linha de placar (`casos ok:`) sozinho
#   * gate contratado na fonte que o inventario de gates nao tem, e vice-versa
#
# O rodape da matriz, quando existe, e DESCARTADO: ele e diagnostico humano. O
# placar desta testemunha e contado aqui, depois das sessenta e oito execucoes.

set -u

MATRIZ="${1:-}"
DIR_EVIDENCIA="${2:-}"

if [ -z "$MATRIZ" ] || [ ! -f "$MATRIZ" ]; then
  printf 'TESTEMUNHA: a matriz nao foi informada ou nao existe: %s\n' "${MATRIZ:-(vazio)}"
  exit 2
fi

AQUI="$(cd "$(dirname "$0")" && pwd)"
FONTE="$AQUI/gates_os_integracao.txt"

if [ ! -f "$FONTE" ]; then
  printf 'TESTEMUNHA: fonte unica ausente em %s\n' "$FONTE"
  exit 2
fi

# ---------------------------------------------------------------------------
# O INVENTARIO CONGELADO — nominal, ordenado, e fora da matriz
# ---------------------------------------------------------------------------
readonly CASOS_OBRIGATORIOS="\
T01 T02 T03 T04 T05 T06 T07 T08 T09 T10 T11 T12 T13 T14 T15 T16 T17 T18 T19 \
T20 T21 T22 T23 T24 T25 T26 T27 T28 T29 T30 T31 T32 T33 T35 T36 T37 T38 T39 \
T40 T41 T42 T43 T44 T45 T46 T47 T48 T49 T50 T51 T52 T53 T54 T55 T56 T57 T67 \
T60 T61 T62 T63 T64 T68 T65 T66 T58 T59 \
T69 T70 T71 T72 T73 T74 T75 T76 T77 T78 T79 T80 T81 T82 T83 T84 T85 T86 T87 \
T88 T34"

# A relacao dos gates que carregam contrato. E o mesmo conjunto que o `T42` da
# matriz confere — e e de proposito: a matriz confere de dentro, esta
# testemunha confere de fora, e nenhuma das duas responde pela outra.
readonly GATES_CONTRATADOS="\
comunicacao chatdom portaoci contratosui rankingfn avatarcanon avatarhml \
perfilvis rknavpub compavrank compnavpub socialestado socialleitor socialtela \
audsocial a11yamigos autverif"

# Identificador que NAO pode existir. A sonda que o usa prova, antes de qualquer
# outra coisa, que a matriz sabe recusar um caso inexistente: sem isso, um modo
# `--caso` complacente devolveria zero para os sessenta e oito sem rodar nada.
readonly ID_FABRICADO="T99"

TMPT="$(mktemp -d)" || { printf 'TESTEMUNHA: sem diretorio temporario\n'; exit 2; }
trap 'rm -rf "$TMPT"' EXIT

falhas=0
recusa() {
  printf 'TESTEMUNHA: %s\n' "$*"
  falhas=$((falhas + 1))
}

# `placar_para_o_log <verdes> <vermelhos>` — O CONTADOR QUE O RUN GUARDA.
#
# `t_contratosui.log` e o `tee` DESTE stdout: o workflow chama
# `bash scripts/ci/testemunha_contratosui.sh <matriz> 2>&1 | tee t_contratosui.log`
# e NAO passa diretorio de evidencia. O selo da secao 6 e para quem passa um, e
# nao substitui esta linha — foi por confundir os dois que o gate ficou SEM
# contador no log do run: a FASE B procurava `casos ok:` no `tee`, achava zero
# caso executado, e reprovava contra um piso de sessenta e oito. Antes da OS
# 40-C3 o executor era a propria matriz em modo completo, que imprime o rodape;
# ao trocar o executor pela testemunha, o numero foi junto para o selo.
#
# O numero e o que ESTA testemunha contou, depois de observar processo por
# processo. Nenhum caso pode injeta-lo: a saida de cada `--caso` vai para um
# arquivo proprio, e a testemunha recusa qualquer caso que imprima placar.
placar_para_o_log() {
  printf 'casos ok: %s | casos com falha: %s\n' "$1" "$2"
}

# ---------------------------------------------------------------------------
# O DESAFIO DA CORRIDA
# ---------------------------------------------------------------------------
#
# Um valor que so existe nesta execucao, escrito ANTES de qualquer medicao. A
# evidencia selada no fim tem de ser posterior a ele; evidencia que ja existia
# antes do desafio e evidencia de outra corrida.
DESAFIO="testemunha-$$-$(date -u +%Y%m%dT%H%M%SZ)"
printf '%s\n' "$DESAFIO" > "$TMPT/desafio"
printf 'TESTEMUNHA: desafio desta corrida: %s\n' "$DESAFIO"
printf 'TESTEMUNHA: matriz sob observacao: %s\n' "$MATRIZ"

# ---------------------------------------------------------------------------
# 1. A SONDA DO IDENTIFICADOR FABRICADO
# ---------------------------------------------------------------------------
bash "$MATRIZ" --caso "$ID_FABRICADO" > "$TMPT/sonda.txt" 2>&1
sonda=$?
if [ "$sonda" -eq 0 ]; then
  recusa "a matriz devolveu ZERO para o caso inexistente '$ID_FABRICADO' — o modo --caso nao distingue caso que rodou de caso que nao existe"
else
  printf 'ok   sonda      caso inexistente %s recusado (exit %s)\n' "$ID_FABRICADO" "$sonda"
fi

# ---------------------------------------------------------------------------
# 2. A PROVA RECIPROCA — o que a matriz anuncia contra o que esta congelado
# ---------------------------------------------------------------------------
bash "$MATRIZ" --listar-casos 2>/dev/null | awk -F'\t' '$1 == "CASO" { print $2 }' > "$TMPT/anunciados"
printf '%s\n' $CASOS_OBRIGATORIOS > "$TMPT/congelados"

n_anun="$(grep -c . "$TMPT/anunciados")" || n_anun=0
n_cong="$(grep -c . "$TMPT/congelados")" || n_cong=0

while IFS= read -r id; do
  [ -z "$id" ] && continue
  recusa "o caso '$id' esta no inventario congelado e a matriz NAO o declara"
done <<AUSENTES
$(grep -Fxv -f "$TMPT/anunciados" "$TMPT/congelados")
AUSENTES

while IFS= read -r id; do
  [ -z "$id" ] && continue
  recusa "a matriz declara o caso '$id', que NAO esta no inventario congelado"
done <<ESTRANHOS
$(grep -Fxv -f "$TMPT/congelados" "$TMPT/anunciados")
ESTRANHOS

while IFS= read -r id; do
  [ -z "$id" ] && continue
  recusa "a matriz declara o caso '$id' MAIS DE UMA VEZ"
done <<DUPLICADOS
$(sort "$TMPT/anunciados" | uniq -d)
DUPLICADOS

if [ "$n_anun" -ne "$n_cong" ]; then
  recusa "a matriz declara $n_anun caso(s) e o inventario congelado tem $n_cong"
fi

if ! cmp -s "$TMPT/anunciados" "$TMPT/congelados"; then
  recusa "a ORDEM de execucao da matriz nao e a congelada"
else
  printf 'ok   reciproca  %s caso(s), mesma relacao e mesma ordem\n' "$n_cong"
fi

# ---------------------------------------------------------------------------
# 3. O CONJUNTO CONTRATADO — derivado da fonte, comparado com o congelado
# ---------------------------------------------------------------------------
sed -e 's/\r$//' "$FONTE" | awk '
  /^[^ \t#]/ { g = $1; next }
  /^[ \t]+(suite|executor|casos|contador|alvo|exigealvo)[ \t]/ {
    if (g != "" && !(g in visto)) { visto[g] = 1; print g }
  }
' | sort > "$TMPT/gates_fonte"
printf '%s\n' $GATES_CONTRATADOS | sort > "$TMPT/gates_congelados"

while IFS= read -r g; do
  [ -z "$g" ] && continue
  recusa "o gate '$g' e contratado na fonte unica e NAO esta no inventario de gates da testemunha"
done <<GATE_ESTRANHO
$(grep -Fxv -f "$TMPT/gates_congelados" "$TMPT/gates_fonte")
GATE_ESTRANHO

while IFS= read -r g; do
  [ -z "$g" ] && continue
  recusa "o gate '$g' esta no inventario da testemunha e PERDEU o contrato na fonte unica"
done <<GATE_AUSENTE
$(grep -Fxv -f "$TMPT/gates_fonte" "$TMPT/gates_congelados")
GATE_AUSENTE

if cmp -s "$TMPT/gates_fonte" "$TMPT/gates_congelados"; then
  printf 'ok   contratos  %s gate(s) contratados, conjunto exato\n' "$(grep -c . "$TMPT/gates_congelados")"
fi

# ---------------------------------------------------------------------------
# 4. AS EXECUCOES — uma por caso, e o exit lido do processo
# ---------------------------------------------------------------------------
observados=0
verdes=0
vermelhos=0

for id in $CASOS_OBRIGATORIOS; do
  saida="$TMPT/caso_$id.txt"
  bash "$MATRIZ" --caso "$id" > "$saida" 2>&1
  ex=$?
  observados=$((observados + 1))

  if ! grep -q "^ATIVO	$id\$" "$saida"; then
    recusa "o caso '$id' nao ANUNCIOU o identificador pedido — o embrulho e o pedido divergem"
  fi
  if grep -q 'casos ok:' "$saida"; then
    recusa "o caso '$id' imprimiu linha de PLACAR sozinho — rodape fabricado dentro de um caso"
  fi

  case "$ex" in
    0)
      if ! grep -q "^  ok    $id " "$saida"; then
        recusa "o caso '$id' saiu ZERO sem registrar resultado proprio"
      else
        verdes=$((verdes + 1))
      fi
      ;;
    1)
      vermelhos=$((vermelhos + 1))
      recusa "o caso '$id' REPROVOU"
      sed -n '1,6p' "$saida" | sed 's/^/           | /'
      ;;
    *)
      recusa "o caso '$id' terminou com exit $ex — nao foi alcancado, ou a matriz quebrou"
      ;;
  esac
done

# ---------------------------------------------------------------------------
# 5. O PLACAR — contado AQUI, depois de observar os processos
# ---------------------------------------------------------------------------
printf '\n----------------------------------------\n'
printf 'TESTEMUNHA: %s caso(s) observados | %s verde(s) | %s vermelho(s)\n' \
  "$observados" "$verdes" "$vermelhos"
printf 'TESTEMUNHA: desafio %s\n' "$DESAFIO"
placar_para_o_log "$verdes" "$vermelhos"

if [ "$observados" -ne "$n_cong" ]; then
  recusa "observou $observados caso(s) e o inventario exige $n_cong"
fi

# ---------------------------------------------------------------------------
# 6. A EVIDENCIA, SELADA DEPOIS
# ---------------------------------------------------------------------------
#
# So aqui, e so se tudo acima fechou. O caminho e escolhido por quem chama esta
# testemunha, e NUNCA e entregue a matriz: a peca medida nao pode saber onde a
# evidencia sobre ela vai ser gravada.
if [ -n "$DIR_EVIDENCIA" ]; then
  mkdir -p "$DIR_EVIDENCIA"
  if [ ! -f "$DIR_EVIDENCIA/carimbo_execucao" ]; then
    printf '%s\n' "$DESAFIO" > "$DIR_EVIDENCIA/carimbo_execucao"
  fi
  {
    printf 'desafio %s\n' "$DESAFIO"
    printf 'casos ok: %s | casos com falha: %s\n' "$verdes" "$vermelhos"
  } > "$DIR_EVIDENCIA/t_contratosui.log"
  printf '%s\n' "$falhas" > "$DIR_EVIDENCIA/exit_contratosui"
fi

if [ "$falhas" -eq 0 ]; then
  printf 'TESTEMUNHA DO CONTRATO: VERDE\n'
  exit 0
fi

printf 'TESTEMUNHA DO CONTRATO: VERMELHO\n'
exit 1
