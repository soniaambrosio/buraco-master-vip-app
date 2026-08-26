#!/usr/bin/env bash
#
# TESTEMUNHA EXTERNA DO CASO `ESP-02`, sobre o relatorio de maquina do Flutter.
#
#   uso: bash scripts/ci/testemunha_esp02.sh <relatorio.json> [suite] [carimbo]
#
# ---------------------------------------------------------------------------
# POR QUE ELA EXISTE
# ---------------------------------------------------------------------------
#
# `verificar_contrato_suites.sh` prova que `ESP-02` esta DECLARADO em codigo e
# que o corpo dele ainda afirma o comportamento. Nao prova que ele RODOU — e a
# OS 40-R3 mostrou que as duas coisas se separam: o caso saiu do arquivo, a
# redacao dele ficou num literal morto e um caso-isca conservou a contagem.
#
# O `+81` do reporter expandido tambem nao serve: ele conta casos, e nao diz
# QUAIS. Tres iscas com o mesmo nome dao o mesmo `+81`.
#
# Esta testemunha le o relatorio de MAQUINA (`--file-reporter=json:...`), que
# nomeia cada caso, diz de qual arquivo ele veio e como ele terminou. E exige:
#
#   1. que o relatorio seja DESTA corrida, e que tenha TERMINADO;
#   2. que existam EXATAMENTE tres instancias de `ESP-02` — o caso e gerado em
#      laco, uma por mesa, e tres e o numero que o laco produz;
#   3. que as tres tenham nomes DISTINTOS, porque instancias geradas diferem
#      pela interpolacao que as gera;
#   4. que as tres tenham concluido APROVADAS, e nenhuma escondida;
#   5. que haja ZERO `ESP-02` FORA do arquivo declarado.
#
# A quinta e a que fecha a isca: as tres legitimas moram DENTRO do arquivo de
# Comunicacao, e o que nao pode existir e uma quarta em outro lugar emprestando
# o nome para atravessar a contagem.
#
# ---------------------------------------------------------------------------
# POR QUE EM BASH, E NAO EM `awk`
# ---------------------------------------------------------------------------
#
# Porque `codigo_executavel.awk` trata o corpo de um programa `awk` embutido
# entre aspas simples como TEXTO INERTE — e esta certissimo. Se a logica
# morasse la dentro, nenhuma exigencia de conteudo alcancaria uma linha sequer
# dela, e a guarda desta testemunha seria so o digest. Em bash, cada afirmacao
# aqui e codigo que o contrato consegue cobrar.

set -u

RELATORIO="${1:-}"
SUITE_ESPERADA="${2:-test/comunicacao/comunicacao_test.dart}"
CARIMBO="${3:-}"
# O CAMINHO CANONICO DO GRUPO, CONGELADO AQUI.
#
# A homologacao da OS 40-C3 plantou uma isca no PROPRIO arquivo declarado: duas
# instancias legitimas e uma terceira chamada
# "CONTROLE variante ESP-02 nao canonica em Mesa VIP", dentro do mesmo grupo.
# Casar o identificador "depois de qualquer espaco" contava a isca, repunha a
# terceira instancia e devolvia VERDE — com um controle legitimo a menos.
#
# Entao o que vale nao e "o nome contem ESP-02": e o CAMINHO COMPLETO. O grupo
# esta escrito por extenso, fora do arquivo que ele guarda, e o caso tem de
# comecar logo depois dele. Renomear o grupo, mover o caso para outro grupo ou
# rebatizar a folha reprovam todos pelo mesmo caminho.
readonly GRUPO_CANONICO='ESP — espectador não fala em ambiente nenhum'
readonly PREFIXO="ESP-02"
readonly INSTANCIAS_ESPERADAS=3

if [ -z "$RELATORIO" ] || [ ! -s "$RELATORIO" ]; then
  printf 'TESTEMUNHA ESP-02: relatorio de maquina ausente ou vazio: %s\n' "${RELATORIO:-(vazio)}"
  exit 2
fi

# ---------------------------------------------------------------------------
# O RELATORIO E DESTA CORRIDA, E ELE TERMINOU
# ---------------------------------------------------------------------------
#
# Duas formas de um relatorio mentir sem ter uma linha falsa. A primeira e ser
# VELHO: um `maquina_comunicacao.json` deixado por outra execucao descreve tres
# `ESP-02` que nao rodaram aqui. A segunda e estar TRUNCADO: o reporter de
# maquina fecha com um evento `done`, e sem ele o que existe e uma execucao
# interrompida no meio — onde "nenhuma instancia reprovou" nao quer dizer nada.
if [ -n "$CARIMBO" ]; then
  if [ ! -f "$CARIMBO" ]; then
    printf 'TESTEMUNHA ESP-02: carimbo da corrida ausente em %s\n' "$CARIMBO"
    exit 2
  fi
  if [ "$CARIMBO" -nt "$RELATORIO" ]; then
    printf 'TESTEMUNHA ESP-02: o relatorio e ANTERIOR ao carimbo desta corrida — evidencia de outra execucao\n'
    exit 1
  fi
fi

if ! grep -q '"type":"done"' "$RELATORIO"; then
  printf 'TESTEMUNHA ESP-02: o relatorio nao tem evento `done` — execucao truncada, e nao ha o que testemunhar\n'
  exit 1
fi

# ---------------------------------------------------------------------------
# A LEITURA
# ---------------------------------------------------------------------------
#
# Uma linha de JSON por evento, e os campos que interessam sao planos. A leitura
# e por expansao de parametro — sem dependencia nova, e sem programa embutido
# que o contrato nao consiga cobrar.
CAMPO=''
campo() {
  local l="$1" k="$2" resto
  CAMPO=''
  case "$l" in
    *"\"$k\":\""*) ;;
    *) return 1 ;;
  esac
  resto="${l#*\"$k\":\"}"
  CAMPO="${resto%%\"*}"
}

NUM=''
numero() {
  local l="$1" k="$2" resto
  NUM=''
  case "$l" in
    *"\"$k\":"*) ;;
    *) return 1 ;;
  esac
  resto="${l#*\"$k\":}"
  resto="${resto%%,*}"
  resto="${resto%%\}*}"
  NUM="$resto"
}

declare -A caminho_da_suite
declare -A nome_do_teste
declare -A suite_do_teste
declare -A resultado
declare -A escondido
declare -A ja_visto_o_nome

instancias=''
total_com_o_nome=0

while IFS= read -r linha || [ -n "$linha" ]; do
  case "$linha" in
    *'"type":"suite"'*)
      numero "$linha" 'id' || continue
      sid="$NUM"
      campo "$linha" 'path' || continue
      caminho_da_suite["$sid"]="${CAMPO//\\\\//}"
      ;;
    *'"type":"testStart"'*)
      numero "$linha" 'id' || continue
      tid="$NUM"
      campo "$linha" 'name' || continue
      nome="$CAMPO"
      numero "$linha" 'suiteID' || continue
      nome_do_teste["$tid"]="$nome"
      suite_do_teste["$tid"]="$NUM"
      # O NOME QUE O FLUTTER GRAVA E QUALIFICADO PELO GRUPO. No relatorio de
      # maquina, `name` e a juncao dos grupos com o nome do caso — o `ESP-02`
      # real chega como "ESP — espectador nao fala em ambiente nenhum ESP-02
      # CONTROLE: ...". Casar so por PREFIXO dava zero instancia contra o
      # relatorio verdadeiro, e passava contra fixture escrita a mao: esta
      # testemunha foi provada em onze cenarios sinteticos e em nenhuma corrida
      # real ate a homologacao da OS 40-C3.
      #
      # A regra continua sendo "a FOLHA comeca com o identificador": ou o nome
      # inteiro comeca com ele, ou ele vem depois de um espaco — que e como o
      # Flutter separa grupo de caso.
      case "$nome" in
        "$GRUPO_CANONICO $PREFIXO"*)
          instancias="$instancias $tid"
          total_com_o_nome=$((total_com_o_nome + 1))
          ;;
      esac
      ;;
    *'"type":"testDone"'*)
      numero "$linha" 'testID' || continue
      did="$NUM"
      campo "$linha" 'result' || continue
      resultado["$did"]="$CAMPO"
      case "$linha" in
        *'"hidden":true'*) escondido["$did"]=1 ;;
      esac
      ;;
  esac
done < "$RELATORIO"

# ---------------------------------------------------------------------------
# O VEREDITO
# ---------------------------------------------------------------------------
falhas=0
fora=0
aprovadas=0
distintas=0

recusa() {
  printf 'TESTEMUNHA ESP-02: %s\n' "$*"
  falhas=$((falhas + 1))
}

if [ "$total_com_o_nome" -ne "$INSTANCIAS_ESPERADAS" ]; then
  recusa "o relatorio traz $total_com_o_nome instancia(s) de $PREFIXO e o esperado e $INSTANCIAS_ESPERADAS"
fi

for tid in $instancias; do
  nome="${nome_do_teste[$tid]}"
  sid="${suite_do_teste[$tid]}"
  caminho="${caminho_da_suite[$sid]:-}"

  if [ -z "$caminho" ]; then
    recusa "a instancia \"$nome\" nao tem ORIGEM declarada no relatorio"
    fora=$((fora + 1))
  else
    case "$caminho" in
      *"$SUITE_ESPERADA"*) ;;
      *)
        recusa "a instancia \"$nome\" veio de FORA do arquivo declarado: $caminho"
        fora=$((fora + 1))
        ;;
    esac
  fi

  if [ "${escondido[$tid]:-0}" = "1" ]; then
    recusa "a instancia \"$nome\" esta marcada como escondida"
  fi

  case "${resultado[$tid]:-}" in
    '') recusa "a instancia \"$nome\" COMECOU e nao concluiu" ;;
    success) aprovadas=$((aprovadas + 1)) ;;
    *) recusa "a instancia \"$nome\" concluiu como ${resultado[$tid]}" ;;
  esac

  if [ "${ja_visto_o_nome[$nome]:-0}" = "1" ]; then
    recusa "o nome \"$nome\" aparece em mais de uma instancia"
  fi
  ja_visto_o_nome["$nome"]=1
  distintas=$((distintas + 1))
done

if [ "$distintas" -ne "$INSTANCIAS_ESPERADAS" ]; then
  recusa "$distintas instancia(s) distinta(s), e o laco gera $INSTANCIAS_ESPERADAS"
fi

if [ "$fora" -gt 0 ]; then
  recusa "$fora instancia(s) de $PREFIXO FORA do arquivo declarado — o esperado e zero"
fi

if [ "$falhas" -eq 0 ]; then
  printf 'ok   esp02      %s instancia(s) de %s, distintas, aprovadas, zero fora de %s\n' \
    "$aprovadas" "$PREFIXO" "$SUITE_ESPERADA"
  printf 'TESTEMUNHA ESP-02: VERDE\n'
  exit 0
fi

printf 'TESTEMUNHA ESP-02: VERMELHO\n'
exit 1
