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
TESTEMUNHA="$AQUI/testemunha_contratosui.sh"
FONTE="$AQUI/gates_os_integracao.txt"
YML="$RAIZ/.github/workflows/ci-os-integracao.yml"

for arquivo in "$VERIF" "$PORTAO" "$LEXICO" "$TESTEMUNHA" "$FONTE" "$YML"; do
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
executou=0

# ---------------------------------------------------------------------------
# OS TRES MODOS (OS 40-C3)
# ---------------------------------------------------------------------------
#
# A matriz deixou de ser o caminho ate o placar. Quem responde pelo gate
# `contratosui` e a TESTEMUNHA EXTERNA (`testemunha_contratosui.sh`), e ela
# precisa de duas coisas que uma execucao linear nao entrega: a RELACAO dos
# casos que a matriz declara, e o EXIT REAL de cada caso, um por um.
#
#   (sem argumento)   roda a matriz inteira — diagnostico humano
#   --listar-casos    imprime o identificador de cada caso, na ordem de execucao
#   --caso <ID>       roda SO aquele caso, e sai com o resultado DELE
#
# A relacao do `--listar-casos` sai da EXECUCAO, e nao de uma varredura do
# proprio texto: o laco corre inteiro e cada caso se anuncia ao ser alcancado.
# Um caso que o fluxo nao alcanca nao aparece na lista, e e disso que a
# testemunha precisa para recusar identificador fabricado.
#
# O modo `--caso` pula a copia da bancada nos casos que nao sao o alvo: sem isso
# seriam sessenta e sete copias por invocacao, e a testemunha custaria o dobro.
# As sabotagens dos casos pulados ate rodam, sobre uma arvore que ninguem mede —
# e nao medir e justamente o ponto.
#
# O RODAPE SO SAI NO MODO COMPLETO. Um caso sozinho nao tem placar, e a
# testemunha recusa qualquer linha de placar dentro de uma execucao de um caso.
MODO='completo'
SO_CASO=''
case "${1:-}" in
  --listar-casos) MODO='listar' ;;
  --caso)
    MODO='caso'
    SO_CASO="${2:-}"
    if [ -z "$SO_CASO" ]; then
      printf 'teste do contrato: --caso exige um identificador\n' >&2
      exit 2
    fi
    ;;
esac

# `alvo_do_caso <id>` — este caso deve mesmo rodar agora?
alvo_do_caso() {
  [ "$MODO" = 'completo' ] && return 0
  [ "$MODO" = 'caso' ] && [ "$1" = "$SO_CASO" ] && return 0
  return 1
}
# `caso_ativo <id>` — o embrulho de cada caso. No modo `listar` ele ANUNCIA o
# identificador e recusa a execucao; no modo `--caso` ele so deixa passar o
# alvo. E o que faz um caso que nao vai ser medido custar zero processo.
#
# Ele tambem FIXA quem esta ativo: `esperar`/`ok`/`nok` recusam anunciar um
# identificador diferente do embrulho, para que a relacao do `--listar-casos`
# nao possa divergir do caso que de fato roda.
CASO_ATIVO=''
# `esperar_igual <descricao> <derivado> <congelado>` — a comparacao MORA nos
# argumentos do caso, e nao num `if` acima dele.
#
# Antes ela ficava no `if` que escolhia entre `ok` e `nok`, ou seja FORA do
# corpo do caso — e `exigenocaso` nao alcanca o que esta fora. A OS 40-R3 mediu
# o custo: trocar aquele `if` inteiro por `if true` deixava o `ok "T42 ..."`
# intacto e a matriz inteira verde. Aqui os dois conjuntos sao ARGUMENTOS, e
# apagar qualquer um deles apaga o caso.
esperar_igual() {
  local desc="$1" derivado="$2" congelado="$3"
  local id="${desc%% *}"
  [ "$MODO" = 'listar' ] && return 0
  if [ -n "$CASO_ATIVO" ] && [ "$id" != "$CASO_ATIVO" ]; then
    printf 'teste do contrato: o caso %s anuncia %s — o embrulho e o anuncio divergem\n' "$CASO_ATIVO" "$id" >&2
    exit 2
  fi
  alvo_do_caso "$id" || return 0
  executou=1
  # A MESMA DECLARACAO OBRIGATORIA DO `esperar`. Sem ela, o unico caso que
  # termina por aqui seria o unico da matriz cuja declaracao ninguem cobra: o
  # auditor de cobertura e pre-voo, e nao autoridade. Um vetor que compara dois
  # conjuntos tambem precisa dizer o que pretende atingir — no caso do oraculo,
  # dizer que NAO toca a bancada, e essa afirmacao so vale nos controles
  # congelados.
  if [ "$INSTRUMENTO_DECLARADO" -eq 0 ]; then
    invalido "o vetor nao declarou 'ancora' nem 'sem_mutacao'"
  fi
  if [ "$INSTRUMENTO" -eq 0 ]; then
    nok "$desc — INSTRUMENTO INVALIDO: $MOTIVO_INSTRUMENTO"
    return
  fi
  if [ "$derivado" = "$congelado" ]; then
    ok "$desc"
  else
    nok "$desc"
    printf '        | derivado  %s\n' "$derivado"
    printf '        | congelado %s\n' "$congelado"
  fi
}
caso_ativo() {
  CASO_ATIVO="$1"
  if [ "$MODO" = 'listar' ]; then printf 'CASO\t%s\n' "$1"; return 1; fi
  # No modo `--caso` o embrulho ANUNCIA quem ele e. A testemunha exige que o
  # anuncio bata com o identificador que ela pediu: sem isso, um embrulho podia
  # rodar um caso e responder pelo nome de outro.
  if [ "$MODO" = 'caso' ] && [ "$1" = "$SO_CASO" ]; then printf 'ATIVO\t%s\n' "$1"; fi
  alvo_do_caso "$1"
}

ok() {
  local id="${1%% *}"
  [ "$MODO" = 'listar' ] && return 0
  if [ -n "$CASO_ATIVO" ] && [ "$id" != "$CASO_ATIVO" ]; then
    printf 'teste do contrato: o caso %s anuncia %s — o embrulho e o anuncio divergem\n' "$CASO_ATIVO" "$id" >&2
    exit 2
  fi
  alvo_do_caso "$id" || return 0
  executou=1
  veredito_unico "$1" || return 0
  passou=$((passou + 1))
  printf '  ok    %s\n' "$1"
}

nok() {
  local id="${1%% *}"
  [ "$MODO" = 'listar' ] && return 0
  if [ -n "$CASO_ATIVO" ] && [ "$id" != "$CASO_ATIVO" ]; then
    printf 'teste do contrato: o caso %s anuncia %s — o embrulho e o anuncio divergem\n' "$CASO_ATIVO" "$id" >&2
    exit 2
  fi
  alvo_do_caso "$id" || return 0
  executou=1
  veredito_unico "$1" || return 0
  falhou=$((falhou + 1))
  printf '  FALHA %s\n' "$1"
}

# ---------------------------------------------------------------------------
# A bancada
#
# So o que o verificador le: os scripts, a fonte unica, o workflow e as suites
# citadas pelos contratos. As suites vem da propria fonte, e nao de uma lista
# escrita aqui — uma lista escrita aqui seria a segunda relacao que esta OS
# existe para nao ter.
# ---------------------------------------------------------------------------

mkdir -p "$BASE/scripts/ci" "$BASE/.github/workflows"
cp "$VERIF" "$PORTAO" "$LEXICO" "$TESTEMUNHA" "$FONTE" "$AQUI/teste_portao_os_integracao.sh" "$BASE/scripts/ci/"
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
  # SEM EXCECAO PARA `scripts/ci/`. A versao anterior pulava esses caminhos
  # supondo que a lista escrita a mao acima ja os tinha copiado — e essa suposicao
  # falhou DUAS vezes nesta OS: primeiro com a testemunha do `contratosui`,
  # depois com as duas pecas novas de `comunicacao`. Quem sabe o que e suite e a
  # FONTE; copiar duas vezes o mesmo arquivo nao custa nada, e esquecer um custa
  # uma corrida inteira.
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
# `sem_mutacao <motivo>` — SO NOS CONTROLES NOMINALMENTE CONGELADOS.
#
# Aceitar `sem_mutacao` em qualquer caso abriria a saida mais barata de todas:
# trocar a sabotagem por "nao mexo em nada" e continuar verde. A relacao abaixo
# esta escrita por extenso, e `T68` prova que um caso fora dela e recusado.
readonly CONTROLES_SEM_MUTACAO="T01 T27 T34 T42 T66 T77"

# `veredito_unico <desc>` — cada caso produz UM veredito terminal.
#
# Sem isto, um bloco podia reprovar por instrumento invalido e, mais adiante, um
# `ok` do mesmo caso sobrescrever o placar. O primeiro veredito manda; o segundo
# e ele proprio uma falha, porque significa que o fluxo do caso nao terminou
# onde deveria. `T66` prova a recusa.
veredito_unico() {
  if [ "$VEREDITO_DADO" -eq 1 ]; then
    falhou=$((falhou + 1))
    printf '  FALHA %s — SEGUNDO VEREDITO para o mesmo caso\n' "$1"
    return 1
  fi
  VEREDITO_DADO=1
  return 0
}

# ---------------------------------------------------------------------------
# OS VETORES QUE MEXEM NA EVIDENCIA, E NAO NA BANCADA
# ---------------------------------------------------------------------------
#
# Os casos de FASE B nao sabotam a arvore: eles sabotam o `t_<gate>.log`, o
# carimbo, a data. Declarar `sem_mutacao` neles seria dizer que nao mexem em
# nada — falso, e exatamente o tipo de declaracao frouxa que o instrumento
# existe para recusar. Entao eles tem declarador proprio, com a mesma forma:
# estado ANTES, transformacao, estado DEPOIS.
EVID_REL=''
EVID_DIGESTO=''

ancora_evidencia() {
  local rel="$1"
  INSTRUMENTO_DECLARADO=1
  EVID_REL="$rel"
  EVID_DIGESTO=''
  if [ ! -s "$TMP/res/$rel" ]; then
    invalido "a evidencia '$rel' devia existir e nao existe — a fixture nao a produziu"
    return 1
  fi
  EVID_DIGESTO="$(sha256sum < "$TMP/res/$rel" | cut -d' ' -f1)"
  return 0
}

# `efeito_evidencia <ausente|vazio|mudado>` — a pos-condicao do alvo de evidencia.
efeito_evidencia() {
  local esperado="$1" agora
  [ "$INSTRUMENTO" -eq 1 ] || return 1
  if [ -z "$EVID_DIGESTO" ]; then
    invalido "pos-condicao de evidencia pedida sem ancora de evidencia"
    return 1
  fi
  case "$esperado" in
    ausente)
      [ -e "$TMP/res/$EVID_REL" ] && { invalido "a evidencia '$EVID_REL' continua la depois da remocao"; return 1; }
      ;;
    vazio)
      [ -e "$TMP/res/$EVID_REL" ] || { invalido "a evidencia '$EVID_REL' sumiu, e o vetor queria esvazia-la"; return 1; }
      [ -s "$TMP/res/$EVID_REL" ] && { invalido "a evidencia '$EVID_REL' nao ficou vazia"; return 1; }
      ;;
    mudado)
      [ -s "$TMP/res/$EVID_REL" ] || { invalido "a evidencia '$EVID_REL' sumiu ou esvaziou, e o vetor queria altera-la"; return 1; }
      agora="$(sha256sum < "$TMP/res/$EVID_REL" | cut -d' ' -f1)"
      [ "$agora" = "$EVID_DIGESTO" ] && { invalido "a evidencia '$EVID_REL' nao mudou um byte"; return 1; }
      ;;
    *)
      invalido "estado desconhecido em efeito_evidencia: '$esperado'"
      return 1
      ;;
  esac
  return 0
}

sem_mutacao() {
  INSTRUMENTO_DECLARADO=1
  ANCORA_REL=''
  ANCORA_DIGESTO=''
  case " $CONTROLES_SEM_MUTACAO " in
    *" $CASO_ATIVO "*) ;;
    *)
      invalido "'sem_mutacao' so vale nos controles congelados ($CONTROLES_SEM_MUTACAO); '$CASO_ATIVO' nao e um deles"
      return 1
      ;;
  esac
  SEM_MUTACAO="${1:-controle}"
  return 0
}

# `conferir_restauracao <rel>` — o alvo do vetor anterior voltou byte a byte?
# Usada pelo `reset` e, de proposito, tambem pelo autocontrole que prova que ela
# recusa: uma conferencia que nunca reprovou nao e conferencia.
conferir_restauracao() {
  local rel="$1"
  [ -n "$rel" ] || return 0
  [ -f "$BASE/$rel" ] || return 0
  if ! cmp -s "$BASE/$rel" "$W/$rel"; then
    invalido "a restauracao de '$rel' nao devolveu o conteudo original"
    return 1
  fi
  return 0
}

# `esperar_instrumento_invalido <desc> <agulha>` — o veredito dos AUTOCONTROLES.
#
# Eles nao medem o verificador: medem se o INSTRUMENTO recusa quando a
# declaracao do vetor nao bate com a arvore. Um instrumento que aceita
# declaracao falsa deixa passar sabotagem que nunca aconteceu — e foi assim que
# duas corridas desta OS produziram casos que nao mediram nada.
esperar_instrumento_invalido() {
  local desc="$1" agulha="$2"
  local id="${desc%% *}"
  [ "$MODO" = 'listar' ] && return 0
  if [ -n "$CASO_ATIVO" ] && [ "$id" != "$CASO_ATIVO" ]; then
    printf 'teste do contrato: o caso %s anuncia %s — o embrulho e o anuncio divergem\n' "$CASO_ATIVO" "$id" >&2
    exit 2
  fi
  alvo_do_caso "$id" || return 0
  executou=1
  # DECLARACAO OBRIGATORIA. Um bloco que nao diz o que pretende atingir — nem
  # `ancora`, nem `sem_mutacao` — nao pode ser medido: ninguem sabe se a
  # sabotagem aconteceu, porque ninguem sabe qual era.
  if [ "$INSTRUMENTO_DECLARADO" -eq 0 ]; then
    invalido "o vetor nao declarou 'ancora' nem 'sem_mutacao'"
  fi
  if [ "$INSTRUMENTO" -eq 1 ]; then
    nok "$desc — o instrumento ACEITOU uma declaracao falsa"
    return
  fi
  case "$MOTIVO_INSTRUMENTO" in
    *"$agulha"*) ok "$desc" ;;
    *) nok "$desc — recusou, mas por outro motivo: $MOTIVO_INSTRUMENTO" ;;
  esac
}
# ---------------------------------------------------------------------------
# O INSTRUMENTO — uma sabotagem que NAO ACONTECEU nao pode virar verde
# ---------------------------------------------------------------------------
#
# A OS 40-C3 perdeu duas corridas inteiras por isto: `T24` e `T25` sabotavam a
# linha `roda comunicacao ...`, que deixou de existir quando o executor virou
# uma chamada a `rodar_comunicacao.sh`. O `sed` parou de casar, nada mudou, o
# verificador continuou verde — e o caso, que esperava VERMELHO, reprovou. Deu
# sorte: se o caso esperasse VERDE, ele teria ficado verde SEM TER MEDIDO NADA.
#
# Isso e DECADENCIA DE ANCORA, e nao forja. O alvo muda de forma e a sabotagem
# envelhece em silencio. Nenhuma guarda desta arvore via isso, porque todas
# olham para o resultado do detector, e nenhuma olhava para o instrumento.
#
# Daqui em diante cada vetor DECLARA o que pretende atingir, e o instrumento
# recusa medir quando a declaracao nao bate:
#
#   ancora  <arquivo> <ere> <cardinalidade> [gate]   antes da mutacao
#   <a mutacao>
#   efeito  <ere> <cardinalidade> [gate]             depois da mutacao
#
# `ancora` exige EXATAMENTE a cardinalidade declarada. Zero e ancora que
# envelheceu; mais do que o declarado e sabotagem que atinge mais do que diz.
# Os dois sao INSTRUMENTO INVALIDO, e `esperar` recusa reportar verde.
#
# `efeito` exige que o digest do alvo TENHA MUDADO — nao basta o `sed` sair com
# zero — e que a pos-condicao ESTRUTURAL esteja la, na quantidade declarada.
# "Algum byte mudou" nao prova que mudou o que se queria mudar.
#
# PADRAO GENERICO NAO CORRE SOBRE O ARQUIVO INTEIRO. `sha256`, `exige` e os
# demais atributos so sao contados DENTRO do bloco nominal do gate, recortado
# por `recorte_do_gate`. Contar `exige` na fonte toda diria trinta e tantos e
# nao provaria nada sobre o gate que o vetor pretende atingir.
#
# E `reset` fecha o ciclo: alem de restaurar, ele CONFERE que o arquivo tocado
# pelo vetor anterior voltou byte a byte ao que estava em `$BASE`.
INSTRUMENTO=1
INSTRUMENTO_DECLARADO=0
VEREDITO_DADO=0
SEM_MUTACAO=''
MOTIVO_INSTRUMENTO=''
ANCORA_REL=''
ANCORA_DIGESTO=''

invalido() {
  INSTRUMENTO=0
  MOTIVO_INSTRUMENTO="$*"
}

# `recorte_do_gate <arquivo> <gate>` — so as linhas indentadas daquele gate.
recorte_do_gate() {
  awk -v g="$2" '
    { l = $0; sub(/\r$/, "", l) }
    l == g { dentro = 1; next }
    l ~ /^[^ \t#]/ { dentro = 0 }
    dentro { print l }
  ' "$W/$1"
}

conta_em() {
  local rel="$1" ere="$2" gate="${3:-}" n
  if [ -n "$gate" ]; then
    n="$(recorte_do_gate "$rel" "$gate" | grep -cE "$ere")" || n=0
  else
    n="$(grep -cE "$ere" "$W/$rel")" || n=0
  fi
  printf '%s' "$n"
}

ancora() {
  local rel="$1" ere="$2" n="$3" gate="${4:-}" viu
  INSTRUMENTO_DECLARADO=1
  ANCORA_REL="$rel"
  # CARDINALIDADE ZERO NAO E ANCORA. Uma ancora que casa zero vezes e uma ancora
  # ENVELHECIDA — e essa e exatamente a propriedade que `T60` prova. Aceitar
  # `ancora ... 0` transformaria a deteccao em permissao. Para os vetores que
  # INSEREM algo que nao pode existir antes, existe `ausencia`, abaixo.
  if [ "$n" -lt 1 ]; then
    invalido "'ancora' exige cardinalidade >= 1; para insercao use 'ausencia'"
    return 1
  fi
  ANCORA_DIGESTO=''
  if [ ! -f "$W/$rel" ]; then
    invalido "o alvo '$rel' nao existe na bancada"
    return 1
  fi
  viu="$(conta_em "$rel" "$ere" "$gate")"
  if [ "$viu" -ne "$n" ]; then
    invalido "a ancora /$ere/ casa $viu vez(es)${gate:+ no bloco '$gate'} de '$rel', e o vetor declara $n"
    return 1
  fi
  ANCORA_DIGESTO="$(tr -d '\r' < "$W/$rel" | sha256sum | cut -d' ' -f1)"
  return 0
}

# `ancora_arquivo <rel>` — para as sabotagens que APAGAM ou RENOMEIAM o alvo:
# nao ha padrao a contar, so a existencia a registrar.

# `ausencia <arquivo> <ere> [gate]` — para os vetores que INSEREM algo que nao
# pode existir antes.
#
# `ancora` recusa cardinalidade zero de proposito: zero e ancora envelhecida, e
# e isso que `T60` prova. Mas ha sabotagens legitimas cuja pre-condicao E a
# ausencia — acrescentar um gate que a fonte nao declara, por exemplo. Elas
# declaram `ausencia`, que exige EXATAMENTE zero antes; a pos-condicao continua
# sendo cobrada por `efeito`, como em qualquer outro vetor.
#
# A separacao importa: sem ela, "ausencia esperada para criacao" viraria
# permissao para ancora que envelheceu.
ausencia() {
  local rel="$1" ere="$2" gate="${3:-}" viu
  INSTRUMENTO_DECLARADO=1
  ANCORA_REL="$rel"
  ANCORA_DIGESTO=''
  if [ ! -f "$W/$rel" ]; then
    invalido "o alvo '$rel' nao existe na bancada"
    return 1
  fi
  viu="$(conta_em "$rel" "$ere" "$gate")"
  if [ "$viu" -ne 0 ]; then
    invalido "a ausencia /$ere/ ja aparece $viu vez(es)${gate:+ no bloco '$gate'} de '$rel' — a insercao nao inseriria nada novo"
    return 1
  fi
  ANCORA_DIGESTO="$(tr -d '\r' < "$W/$rel" | sha256sum | cut -d' ' -f1)"
  return 0
}
ancora_arquivo() {
  ANCORA_REL="$1"
  INSTRUMENTO_DECLARADO=1
  ANCORA_DIGESTO=''
  if [ ! -f "$W/$1" ]; then
    invalido "o alvo '$1' nao existe na bancada"
    return 1
  fi
  ANCORA_DIGESTO="$(tr -d '\r' < "$W/$1" | sha256sum | cut -d' ' -f1)"
  return 0
}

efeito() {
  local ere="$1" n="$2" gate="${3:-}" agora viu
  [ "$INSTRUMENTO" -eq 1 ] || return 1
  if [ -z "$ANCORA_DIGESTO" ]; then
    invalido "pos-condicao pedida sem ancora registrada"
    return 1
  fi
  if [ ! -f "$W/$ANCORA_REL" ]; then
    invalido "o alvo '$ANCORA_REL' sumiu, e o vetor esperava altera-lo"
    return 1
  fi
  agora="$(tr -d '\r' < "$W/$ANCORA_REL" | sha256sum | cut -d' ' -f1)"
  if [ "$agora" = "$ANCORA_DIGESTO" ]; then
    invalido "a sabotagem nao mudou um byte de '$ANCORA_REL' — a ancora envelheceu"
    return 1
  fi
  viu="$(conta_em "$ANCORA_REL" "$ere" "$gate")"
  if [ "$viu" -ne "$n" ]; then
    invalido "a pos-condicao /$ere/ aparece $viu vez(es)${gate:+ no bloco '$gate'}, e o vetor declara $n"
    return 1
  fi
  return 0
}

# `efeito_sumiu` — pos-condicao das sabotagens que apagam ou renomeiam.
efeito_sumiu() {
  [ "$INSTRUMENTO" -eq 1 ] || return 1
  if [ -f "$W/$ANCORA_REL" ]; then
    invalido "'$ANCORA_REL' continua no lugar depois da remocao"
    return 1
  fi
  return 0
}
reset() {
  local id="${1:-}"
  alvo_do_caso "$id" || return 0

  # A RESTAURACAO E CONFERIDA, e nao suposta: o arquivo tocado pelo vetor
  # ANTERIOR tem de voltar byte a byte ao que estava em `$BASE`. Uma bancada que
  # nao volta ao original faz o proximo caso medir a sobra do anterior — e a
  # conferencia e feita pela MESMA funcao que o autocontrole usa para provar que
  # ela sabe recusar.
  local anterior="$ANCORA_REL"

  rm -rf "$W"
  cp -r "$BASE" "$W"

  conferir_restauracao "$anterior" || return 0

  INSTRUMENTO=1
  INSTRUMENTO_DECLARADO=0
  VEREDITO_DADO=0
  SEM_MUTACAO=''
  MOTIVO_INSTRUMENTO=''
  ANCORA_REL=''
  ANCORA_DIGESTO=''
  EVID_REL=''
  EVID_DIGESTO=''
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
socialestado socialleitor socialtela audsocial a11yamigos autverif"

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

# recarimbar_autoridade <arquivo> — realinha o digesto daquele arquivo DENTRO da
# autoridade externa, em $W.
#
# Existe pela mesma razao que `recarimbar`: quem adultera um verificador atualiza
# o digesto no mesmo commit, e uma bancada que nao fizesse isso mediria sempre o
# digesto e nunca a DECISAO. E o RECARIMBO COORDENADO que a OS 40-C4 manda
# exercitar — o vetor entrega ao atacante tudo o que ele controla, e cobra que a
# autoridade continue reprovando pelo que ele NAO controla.
recarimbar_autoridade() {
  local alvo="$1" novo
  novo="$(tr -d '\r' < "$W/$alvo" | sha256sum | awk '{print $1}')"
  ALVO_DIG="$alvo" NOVO_DIG="$novo" awk '
    { l = $0; sub(/\r$/, "", l); nf = split(l, c, " ") }
    nf == 2 && c[1] == ENVIRON["ALVO_DIG"] && c[2] ~ /^[0-9a-f]{64}$/ {
      print ENVIRON["ALVO_DIG"] " " ENVIRON["NOVO_DIG"]; feito = 1; next
    }
    { print l }
    END { if (!feito) exit 3 }
  ' "$W/scripts/ci/autoridade_verificadores.sh" > "$TMP/aut.novo" || {
    printf 'teste do contrato: recarimbo da autoridade para %s nao pegou\n' "$alvo" >&2
    return 1
  }
  mv "$TMP/aut.novo" "$W/scripts/ci/autoridade_verificadores.sh"
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
  local id="${desc%% *}"
  [ "$MODO" = 'listar' ] && return 0
  if [ -n "$CASO_ATIVO" ] && [ "$id" != "$CASO_ATIVO" ]; then
    printf 'teste do contrato: o caso %s anuncia %s — o embrulho e o anuncio divergem\n' "$CASO_ATIVO" "$id" >&2
    exit 2
  fi
  alvo_do_caso "$id" || return 0
  executou=1
  # DECLARACAO OBRIGATORIA. Um bloco que nao diz o que pretende atingir — nem
  # `ancora`, nem `sem_mutacao` — nao pode ser medido: ninguem sabe se a
  # sabotagem aconteceu, porque ninguem sabe qual era.
  if [ "$INSTRUMENTO_DECLARADO" -eq 0 ]; then
    invalido "o vetor nao declarou 'ancora' nem 'sem_mutacao'"
  fi

  # UMA SABOTAGEM QUE NAO ACONTECEU NAO PODE VIRAR VERDE. Se o instrumento
  # recusou — ancora com cardinalidade errada, digest que nao mudou,
  # pos-condicao ausente ou restauracao suja — o caso reprova como INSTRUMENTO
  # INVALIDO, e nunca como aprovado. Foi por nao ter isto que a OS 40-C3 perdeu
  # duas corridas inteiras com ancoras envelhecidas.
  if [ "$INSTRUMENTO" -eq 0 ]; then
    nok "$desc — INSTRUMENTO INVALIDO: $MOTIVO_INSTRUMENTO"
    return
  fi
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

# `esperar_autoridade <exit> <desc> [agulha]` — o mesmo veredito, sobre a
# AUTORIDADE EXTERNA DOS VERIFICADORES (OS 40-C4).
#
# Ela e a peca que responde pelos tres arquivos que DECIDEM — o verificador de
# conteudo, o agregador e o analisador lexico —, e por isso nao pode ser medida
# pelo mesmo `esperar` que roda o verificador: o que se pergunta aqui e outra
# coisa. Fora isso o instrumento e o MESMO: declaracao obrigatoria, ancora
# conferida, pos-condicao cobrada, e recusa de reportar verde quando a sabotagem
# nao aconteceu.
esperar_autoridade() {
  local esperado="$1" desc="$2" agulha="${3:-}" real
  local id="${desc%% *}"
  [ "$MODO" = 'listar' ] && return 0
  if [ -n "$CASO_ATIVO" ] && [ "$id" != "$CASO_ATIVO" ]; then
    printf 'teste do contrato: o caso %s anuncia %s — o embrulho e o anuncio divergem\n' "$CASO_ATIVO" "$id" >&2
    exit 2
  fi
  alvo_do_caso "$id" || return 0
  executou=1
  if [ "$INSTRUMENTO_DECLARADO" -eq 0 ]; then
    invalido "o vetor nao declarou 'ancora' nem 'sem_mutacao'"
  fi
  if [ "$INSTRUMENTO" -eq 0 ]; then
    nok "$desc — INSTRUMENTO INVALIDO: $MOTIVO_INSTRUMENTO"
    return
  fi
  bash "$W/scripts/ci/autoridade_verificadores.sh" "$W" "$W/$YML_W" \
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

printf '== controle ==\n'

if caso_ativo T01; then
  reset T01
  sem_mutacao 'CONTROLE: a arvore integra nao e sabotada'
  esperar 0 "T01 CONTROLE — arvore integra => VERDE" 'tudo no lugar'
fi

printf '\n== a autoridade e seus leitores ==\n'

if caso_ativo T02; then
  reset T02
  ancora_arquivo "$FONTE_W"
  rm -f "$W/$FONTE_W"
  efeito_sumiu
  esperar 1 "T02 — fonte unica apagada => VERMELHO (N1)" 'fonte unica ausente'
fi

if caso_ativo T03; then
  reset T03
  ancora_arquivo "scripts/ci/portao_os_integracao.sh"
  rm -f "$W/scripts/ci/portao_os_integracao.sh"
  efeito_sumiu
  esperar 1 "T03 — agregador (unico leitor) apagado => VERMELHO (N2)" 'agregador ausente'
fi

if caso_ativo T04; then
  reset T04
  ancora "$FONTE_W" '^[a-z]' 64
  printf 'analyze\nanalyze\n' > "$W/$FONTE_W"
  efeito '^analyze$' 2
  esperar 1 "T04 — fonte com gate duplicado => VERMELHO (o leitor recusa)" 'recusou a fonte'
fi

if caso_ativo T05; then
  reset T05
  ancora "$FONTE_W" '^[a-z]' 64
  : > "$W/$FONTE_W"
  efeito '.' 0
  esperar 1 "T05 — fonte esvaziada => VERMELHO (N20)" 'recusou a fonte'
fi

printf '\n== a suite existe ==\n'

if caso_ativo T06; then
  reset T06
  ancora_arquivo "app/test/comunicacao/comunicacao_test.dart"
  rm -f "$W/app/test/comunicacao/comunicacao_test.dart"
  efeito_sumiu
  esperar 1 "T06 — suite protegida apagada => VERMELHO (N9)" 'removida ou renomeada'
fi

if caso_ativo T07; then
  reset T07
  ancora_arquivo "app/test/comunicacao/comunicacao_test.dart"
  mv "$W/app/test/comunicacao/comunicacao_test.dart" \
     "$W/app/test/comunicacao/comunicacao_outro_test.dart"
  efeito_sumiu
  esperar 1 "T07 — suite protegida renomeada => VERMELHO (N10)" 'removida ou renomeada'
fi

printf '\n== a suite ainda PROVA ==\n'

if caso_ativo T08; then
  reset T08
  ancora "app/test/comunicacao/comunicacao_test.dart" "group\\('ESP" 1
  printf "import 'package:flutter_test/flutter_test.dart';\nvoid main() {\n  test('nada', () => expect(1, 1));\n}\n" \
    > "$W/app/test/comunicacao/comunicacao_test.dart"
  efeito "expect\\(1, 1\\)" 1
  esperar 1 "T08 — suite trocada por expect(1, 1) => VERMELHO (N11)" 'mudou e a assinatura nao'
fi

if caso_ativo T09; then
  reset T09
  ancora "app/test/comunicacao/comunicacao_test.dart" "group\\('ESP" 1
  sed -i "s/group('ESP/group('XXX/" "$W/app/test/comunicacao/comunicacao_test.dart"
  efeito "group\\('XXX" 1
  esperar 1 "T09 — bloco obrigatorio removido da suite => VERMELHO (N12)" 'sumiu de'
fi

if caso_ativo T10; then
  reset T10
  ancora "$FONTE_W" '^    provas     71$' 1 comunicacao
  sed -i 's/^    provas     71$/    provas     3/' "$W/$FONTE_W"
  efeito '^    provas     3$' 1 comunicacao
  esperar 1 "T10 — piso de provas rebaixado na fonte => VERMELHO (N13)" 'piso de provas'
fi

if caso_ativo T11; then
  reset T11
  ancora "$FONTE_W" '^    casos      81$' 1
  sed -i 's/^    casos      81$/    casos      2/' "$W/$FONTE_W"
  efeito '^    casos      2$' 1
  esperar 1 "T11 — piso de casos rebaixado na fonte => VERMELHO (N13)" 'piso de casos'
fi

if caso_ativo T12; then
  reset T12
  ancora "$FONTE_W" '^    sha256     [0-9a-f]{64}$' 21
  sed -i 's/^\(    sha256     \)[0-9a-f]\{64\}$/\10000000000000000000000000000000000000000000000000000000000000000/' \
    "$W/$FONTE_W"
  efeito '^    sha256     0{64}$' 21
  esperar 1 "T12 — assinatura adulterada => VERMELHO" 'mudou e a assinatura nao'
fi

if caso_ativo T13; then
  reset T13
  ancora "app/test/comunicacao/comunicacao_test.dart" "group\\('ESP" 1
  # A forja mais barata contra busca textual: repetir o literal num COMENTARIO.
  printf "import 'package:flutter_test/flutter_test.dart';\n// group('MAT group('CTR group('PRI group('ESP\n// ('MAT-01 ('CTR-02 ('PRI-19 ('ESP-01 'ESP-02 CONTROLE ['mesa_privada/completo']\nvoid main() {\n  test('nada', () => expect(1, 1));\n}\n" \
    > "$W/app/test/comunicacao/comunicacao_test.dart"
  efeito "// group\\('MAT" 1
  esperar 1 "T13 — literais so em COMENTARIO nao satisfazem o contrato => VERMELHO" 'sumiu de'
fi

printf '\n== o contrato tem de estar completo ==\n'

if caso_ativo T14; then
  reset T14
  ancora "$FONTE_W" '^    sha256     ' 21
  sed -i '/^    sha256     /d' "$W/$FONTE_W"
  efeito '^    sha256     ' 0
  esperar 1 "T14 — contrato sem sha256 => VERMELHO" "nao declara 'sha256'"
fi

if caso_ativo T15; then
  reset T15
  ancora "$FONTE_W" '^    exige      ' 139
  sed -i '/^    exige      /d' "$W/$FONTE_W"
  efeito '^    exige      ' 0
  esperar 1 "T15 — contrato sem nenhum exige => VERMELHO" "nao declara nenhum 'exige'"
fi

if caso_ativo T16; then
  reset T16
  ancora "$FONTE_W" '^    provas     ' 21
  sed -i '/^    provas     /d' "$W/$FONTE_W"
  efeito '^    provas     ' 0
  esperar 1 "T16 — contrato sem provas => VERMELHO" "nao declara 'provas'"
fi

if caso_ativo T17; then
  reset T17
  ancora "$FONTE_W" '^    suite      ' 21
  sed -i '/^    suite      /d' "$W/$FONTE_W"
  efeito '^    suite      ' 0
  esperar 1 "T17 — contrato sem suite => VERMELHO" "nao declara 'suite'"
fi

if caso_ativo T18; then
  reset T18
  ancora "$FONTE_W" '^    provas     71$' 1 comunicacao
  sed -i 's/^    provas     71$/    plantao    71/' "$W/$FONTE_W"
  efeito '^    plantao    71$' 1 comunicacao
  esperar 1 "T18 — atributo desconhecido no contrato => VERMELHO" 'atributo desconhecido'
fi

if caso_ativo T19; then
  reset T19
  ancora "$FONTE_W" '^    provas     71$' 1 comunicacao
  sed -i 's/^    provas     71$/    provas/' "$W/$FONTE_W"
  efeito '^    provas$' 1 comunicacao
  esperar 1 "T19 — atributo sem valor => VERMELHO (o leitor recusa)" 'recusou a fonte'
fi

if caso_ativo T20; then
  reset T20
  ancora "$FONTE_W" '^    provas     71$' 1 comunicacao
  sed -i 's/^    provas     71$/    provas     71\n    provas     71/' "$W/$FONTE_W"
  efeito '^    provas     71$' 2 comunicacao
  esperar 1 "T20 — atributo repetido => VERMELHO" "'provas' repetido"
fi

printf '\n== o contrato nao pode encolher ==\n'

if caso_ativo T21; then
  reset T21
  ancora "$FONTE_W" '^    [a-z][a-z0-9_]* ' 260
  # QUALQUER atributo indentado, e nao uma lista de nomes. A lista escrita a mao
  # ficou para tras quando a OS 40-C1 acrescentou `alvo` e `exigealvo`: o caso
  # continuava vermelho, mas por OUTRO motivo — sobrava contrato, e a mensagem
  # "a protecao de conteudo foi esvaziada" nunca saia. Um caso que reprova pelo
  # motivo errado e um caso que deixou de medir.
  sed -i '/^    [a-z][a-z0-9_]* /d' "$W/$FONTE_W"
  efeito '^    [a-z][a-z0-9_]* ' 0
  esperar 1 "T21 — TODOS os contratos removidos => VERMELHO (N20)" 'protecao de conteudo foi esvaziada'
fi

if caso_ativo T22; then
  reset T22
  ancora "$FONTE_W" '^comunicacao$' 1
  awk '/^comunicacao$/ { pulando = 1; next }
       pulando && /^[[:blank:]]/ { next }
       { pulando = 0; print }' "$BASE/$FONTE_W" > "$W/$FONTE_W"
  efeito '^comunicacao$' 0
  esperar 1 "T22 — gate protegido removido da fonte => VERMELHO (N6)" "perdeu o contrato"
fi

if caso_ativo T23; then
  reset T23
  ausencia "$FONTE_W" '^gatequenaoexiste$'
  printf '\ngatequenaoexiste\n    suite      app/test/chat/chat_test.dart\n    executor   roda gatequenaoexiste test/chat/chat_test.dart\n    sha256     0000000000000000000000000000000000000000000000000000000000000000\n    provas     1\n    exige      void main\n' \
    >> "$W/$FONTE_W"
  efeito '^gatequenaoexiste$' 1
  esperar 1 "T23 — contrato num gate que a fonte nao declara => impossivel: ele VIRA gate" 'nao produz'
fi

printf '\n== o executor, o marcador e a propria invocacao ==\n'

if caso_ativo T24; then
  reset T24
  ancora "$YML_W" 'rodar_comunicacao\.sh test/comunicacao/comunicacao_test\.dart' 1
  sed -i 's|rodar_comunicacao.sh test/comunicacao/comunicacao_test.dart|rodar_comunicacao.sh test/comunicacao/outro_test.dart|' "$W/$YML_W"
  efeito 'rodar_comunicacao\.sh test/comunicacao/outro_test\.dart' 1
  esperar 1 "T24 — executor removido do workflow => VERMELHO (N18)" 'nao tem a linha do executor'
fi

if caso_ativo T25; then
  reset T25
  ancora "$FONTE_W" '^    executor   bash scripts/ci/rodar_comunicacao\.sh ' 1 comunicacao
  sed -i 's|^    executor   bash scripts/ci/rodar_comunicacao.sh .*$|    executor   bash scripts/ci/rodar_comunicacao.sh test/chat/chat_test.dart scripts/ci/testemunha_esp02.sh|' "$W/$FONTE_W"
  efeito 'rodar_comunicacao\.sh test/chat/chat_test\.dart' 1 comunicacao
  esperar 1 "T25 — executor apontando para OUTRA suite => VERMELHO" 'nao cita a suite'
fi

if caso_ativo T26; then
  reset T26
  ancora "$YML_W" 'scripts/ci/verificar_contrato_suites\.sh' 2
  sed -i 's|scripts/ci/verificar_contrato_suites.sh|scripts/ci/nada.sh|g' "$W/$YML_W"
  efeito 'scripts/ci/nada\.sh' 2
  esperar 1 "T26 — o workflow deixou de invocar o verificador => VERMELHO (§17)" 'nao invoca mais'
fi

printf '\n== FASE B: o log da execucao ==\n'

if caso_ativo T27; then
  reset T27
  resultados "$TMP/res"
  sem_mutacao 'CONTROLE: a evidencia integra nao e sabotada'
  esperar 0 "T27 CONTROLE — evidencia completa e datada => VERDE" 'posterior ao carimbo' "$TMP/res"
fi

if caso_ativo T28; then
  reset T28
  resultados "$TMP/res"
  ancora_evidencia 't_comunicacao.log'
  rm -f "$TMP/res/t_comunicacao.log"
  efeito_evidencia ausente
  esperar 1 "T28 — marcador fabricado, sem log => VERMELHO (N16)" 'marcador sem execucao' "$TMP/res"
fi

if caso_ativo T29; then
  reset T29
  resultados "$TMP/res"
  ancora_evidencia 't_comunicacao.log'
  printf '00:12 +81: All tests passed!\n' > "$TMP/res/t_comunicacao.log"
  touch -d '-1 hour' "$TMP/res/t_comunicacao.log"
  efeito_evidencia mudado
  esperar 1 "T29 — log ANTERIOR ao carimbo => VERMELHO (N19)" 'outra execucao' "$TMP/res"
fi

if caso_ativo T30; then
  reset T30
  resultados "$TMP/res"
  ancora_evidencia 'carimbo_execucao'
  rm -f "$TMP/res/carimbo_execucao"
  efeito_evidencia ausente
  esperar 1 "T30 — carimbo do run ausente => VERMELHO" 'carimbo de execucao ausente' "$TMP/res"
fi

if caso_ativo T31; then
  reset T31
  resultados "$TMP/res"
  ancora_evidencia 't_comunicacao.log'
  printf '00:00 +3: All tests passed!\n' > "$TMP/res/t_comunicacao.log"
  touch -d '+1 hour' "$TMP/res/t_comunicacao.log"
  efeito_evidencia mudado
  esperar 1 "T31 — suite executou 3 casos e o piso e 81 => VERMELHO (N13/N14)" 'a suite encolheu' "$TMP/res"
fi

if caso_ativo T32; then
  reset T32
  resultados "$TMP/res"
  ancora_evidencia 't_portaoci.log'
  : > "$TMP/res/t_portaoci.log"
  efeito_evidencia vazio
  esperar 1 "T32 — log vazio nao e evidencia => VERMELHO (N14)" 'marcador sem execucao' "$TMP/res"
fi

printf '\n== a margem continua sendo a autoridade ==\n'

if caso_ativo T33; then
  reset T33
  ancora "$FONTE_W" '^comunicacao$' 1
  sed -i 's/^comunicacao$/  comunicacao/' "$W/$FONTE_W"
  efeito '^  comunicacao$' 1
  esperar 1 "T33 — gate indentado por engano => VERMELHO, e nao some em silencio" 'recusou a fonte'
fi

printf '\n== `alvo`: o executor roda o codebase, o codebase roda as suites ==\n'

# A CADEIA DE `rankingfn`, ELO POR ELO. Ate a OS 40-C1 o vocabulario so sabia
# falar de um arquivo por gate, e um passo que roda `npm test` nao cita arquivo
# nenhum — quem nomeia as suites e o `package.json`. Estes seis casos sao a
# matriz do elo novo: se ele puder ser desligado em silencio, o contrato de
# `rankingfn` vira decoracao.

if caso_ativo T35; then
  reset T35
  ancora "functions-ranking/package.json" ' test/superficie\.test\.js' 1
  sed -i 's| test/superficie.test.js||' "$W/functions-ranking/package.json"
  efeito ' test/superficie\.test\.js' 0
  esperar 1 "T35 — suite tirada do alvo oficial => VERMELHO" 'nao roda a suite'
fi

if caso_ativo T36; then
  reset T36
  ancora "functions-ranking/package.json" 'test/composicao\.test\.js"' 1
  sed -i 's|test/composicao.test.js"|test/composicao.test.js test/isca.test.js"|' \
    "$W/functions-ranking/package.json"
  efeito 'test/isca\.test\.js' 1
  esperar 1 "T36 — suite-isca acrescentada ao alvo => VERMELHO" 'sumiu do alvo'
fi

if caso_ativo T37; then
  reset T37
  ancora_arquivo "functions-ranking/package.json"
  rm -f "$W/functions-ranking/package.json"
  efeito_sumiu
  esperar 1 "T37 — alvo apagado => VERMELHO" "'alvo' de 'rankingfn' nao existe"
fi

if caso_ativo T38; then
  reset T38
  ancora "$FONTE_W" '^    alvo       ' 1
  sed -i '/^    alvo       /d' "$W/$FONTE_W"
  efeito '^    alvo       ' 0
  esperar 1 "T38 — exigealvo sem alvo => VERMELHO" "tem 'exigealvo' e nao declara 'alvo'"
fi

if caso_ativo T39; then
  reset T39
  ancora "$FONTE_W" '^    exigealvo  ' 1
  sed -i '/^    exigealvo  /d' "$W/$FONTE_W"
  efeito '^    exigealvo  ' 0
  esperar 1 "T39 — alvo sem nenhum exigealvo => VERMELHO" 'alvo sem congelamento'
fi

if caso_ativo T40; then
  reset T40
  ancora "$FONTE_W" '^    suite      functions-ranking/test/superficie\.test\.js$' 1
  awk '/^    suite      functions-ranking\/test\/superficie\.test\.js$/ { pulando = 1; next }
       pulando && /^[[:blank:]]/ { next }
       { pulando = 0; print }' "$BASE/$FONTE_W" > "$W/$FONTE_W"
  efeito '^    suite      functions-ranking/test/superficie\.test\.js$' 0
  esperar 1 "T40 — segunda suite do gate removida da fonte => VERMELHO (o piso e a SOMA)" 'piso de provas'
fi

if caso_ativo T41; then
  reset T41
  ancora "$FONTE_W" '^    [a-z]' 26 rankingfn
  awk '/^rankingfn$/ { pulando = 1; print; next }
       pulando && /^[[:blank:]]/ { next }
       { pulando = 0; print }' "$BASE/$FONTE_W" > "$W/$FONTE_W"
  efeito '^    [a-z]' 0 rankingfn
  esperar 1 "T41 — contrato de rankingfn esvaziado => VERMELHO (N6)" "perdeu o contrato"
fi

printf '\n== o oraculo da evidencia mora FORA da relacao derivada ==\n'

# `resultados()` monta os logs a partir dos gates contratados NA FONTE. Sozinho,
# isso fecharia o buraco do T27 e abriria outro: tirar um gate da fonte encolheria
# a evidencia E o oraculo no mesmo movimento, e a matriz seguiria verde medindo
# menos. Este caso e o oraculo que nao deriva de nada — o conjunto autoritativo
# de contratados, escrito por extenso.
if caso_ativo T42; then
  reset T42
  sem_mutacao 'ORACULO: compara dois conjuntos congelados, sem tocar a bancada'
  esperar_igual "T42 — a relacao de contratados da fonte e EXATAMENTE a congelada" \
    "$(printf '%s\n' $CONTRATADOS | sort | tr '\n' ' ')" \
    "$(printf '%s\n' $CONTRATADOS_CONGELADOS | sort | tr '\n' ' ')"
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

if caso_ativo T43; then
  reset T43
  ancora "$SF_JS" '^      pkg\.scripts\.test,$' 1
  trocar_linha "$W/$SF_JS" '      pkg.scripts.test,' '      /* pkg.scripts.test, */ 0,' && recarimbar "$SF_JS"
  efeito '^      /\* pkg\.scripts\.test, \*/ 0,$' 1
  esperar 1 "T43 — agulha so em comentario de BLOCO => VERMELHO" 'nao codigo executavel'
fi

if caso_ativo T44; then
  reset T44
  ancora "$SF_JS" '^      pkg\.scripts\.test,$' 1
  trocar_linha "$W/$SF_JS" '      pkg.scripts.test,' '      "pkg.scripts.test,",' && recarimbar "$SF_JS"
  efeito '^      "pkg\.scripts\.test,",$' 1
  esperar 1 "T44 — agulha so em string => VERMELHO" 'nao codigo executavel'
fi

if caso_ativo T45; then
  reset T45
  ancora "$SF_JS" '^      pkg\.scripts\.test,$' 1
  trocar_linha "$W/$SF_JS" '      pkg.scripts.test,' '      `pkg.scripts.test,`,' && recarimbar "$SF_JS"
  efeito '^      `pkg\.scripts\.test,`,$' 1
  esperar 1 "T45 — agulha so em texto de template => VERMELHO" 'nao codigo executavel'
fi

if caso_ativo T46; then
  reset T46
  ancora "$SF_JS" '^      pkg\.scripts\.test,$' 1
  trocar_linha "$W/$SF_JS" '      pkg.scripts.test,' '      String(/pkg.scripts.test,/),' && recarimbar "$SF_JS"
  efeito '^      String\(/pkg\.scripts\.test,/\),$' 1
  esperar 1 "T46 — agulha so em expressao regular => VERMELHO" 'nao codigo executavel'
fi

if caso_ativo T47; then
  reset T47
  ancora "$SF_JS" '^      pkg\.scripts\.test,$' 1
  trocar_linha "$W/$SF_JS" '      pkg.scripts.test,' '      0, // pkg.scripts.test,' && recarimbar "$SF_JS"
  efeito '^      0, // pkg\.scripts\.test,$' 1
  esperar 1 "T47 — agulha so em comentario NO FIM de linha de codigo => VERMELHO" 'nao codigo executavel'
fi

if caso_ativo T48; then
  reset T48
  ancora "$SOCIALTELA" "^  group\('Amigos" 1
  trocar_linha "$W/$SOCIALTELA" \
    "  group('Amigos — as listas vêm da autoridade', () {" \
    "  group('OUTRA COISA', () { // group('Amigos — as listas vêm da autoridade', () {" &&
    recarimbar "$SOCIALTELA"
  efeito "^  group\('OUTRA COISA'" 1
  esperar 1 "T48 — a mesma forja no dart, em comentario de fim de linha => VERMELHO" 'nao codigo executavel'
fi

if caso_ativo T49; then
  reset T49
  ancora_arquivo "scripts/ci/codigo_executavel.awk"
  rm -f "$W/scripts/ci/codigo_executavel.awk"
  efeito_sumiu
  esperar 1 "T49 — analisador lexico apagado => VERMELHO, e nao permissivo" 'analisador lexico ausente'
fi

if caso_ativo T50; then
  reset T50
  ancora_arquivo "app/test/comunicacao/comunicacao_test.dart"
  mv "$W/app/test/comunicacao/comunicacao_test.dart" "$W/app/test/comunicacao/comunicacao_test.txt"
  sed -i 's|^\( *suite  *\)app/test/comunicacao/comunicacao_test.dart$|\1app/test/comunicacao/comunicacao_test.txt|' "$W/$FONTE_W"
  efeito_sumiu
  esperar 1 "T50 — suite com extensao que o lexer nao conhece => VERMELHO" 'nao sabe ler'
fi

printf '\n== as relacoes de conteudo, guardadas de FORA do manifesto que elas guardam ==\n'

# O SEGUNDO ESCAPE DA OS 40-R2. As relacoes protegiam a suite, e nada protegia as
# relacoes: retirar uma linha da fonte nao reprovava coisa nenhuma, e com a
# afirmacao apagada no mesmo commit a arvore ficava verde de ponta a ponta.

if caso_ativo T51; then
  reset T51
  ancora "$FONTE_W" '^    exige      corpoDoCaso\(GUARDA, "SF-01"\)$' 1
  sed -i '/^    exige      corpoDoCaso(GUARDA, "SF-01")$/d' "$W/$FONTE_W"
  efeito '^    exige      corpoDoCaso\(GUARDA, "SF-01"\)$' 0
  esperar 1 "T51 — relacao de conteudo retirada da fonte => VERMELHO" 'sumiu da fonte'
fi

if caso_ativo T52; then
  reset T52
  ancora "$FONTE_W" '^    exige      corpoDoCaso\(GUARDA, "SF-01"\)$' 1
  sed -i 's|^    exige      corpoDoCaso(GUARDA, "SF-01")$|    exige      corpoDoCaso(GUARDA, "SF-99")|' "$W/$FONTE_W"
  efeito '^    exige      corpoDoCaso\(GUARDA, "SF-99"\)$' 1
  esperar 1 "T52 — relacao de conteudo renomeada => VERMELHO" 'nao esta congelada'
fi

if caso_ativo T53; then
  reset T53
  ancora "$FONTE_W" '^    exige      test\("SF-01:$' 1
  sed -i 's|^    exige      test("SF-01:$|    exige      test("SF-01:\n    exige      test("SF-01:|' "$W/$FONTE_W"
  efeito '^    exige      test\("SF-01:$' 2
  esperar 1 "T53 — relacao duplicada para conservar a quantidade => VERMELHO" 'cardinalidade mudou'
fi

if caso_ativo T54; then
  reset T54
  ancora "$FONTE_W" '^    suite      functions-ranking/test/superficie\.test\.js$' 1
  sed -i 's|^    suite      functions-ranking/test/superficie.test.js$|    suite      functions-ranking/test/composicao.test.js|' "$W/$FONTE_W"
  efeito '^    suite      functions-ranking/test/composicao\.test\.js$' 1
  esperar 1 "T54 — a segunda suite do gate trocada na fonte => VERMELHO" 'nao sao as congeladas'
fi

if caso_ativo T55; then
  reset T55
  ancora "$FONTE_W" '^    alvo       functions-ranking/package\.json$' 1
  sed -i 's|^    alvo       functions-ranking/package.json$|    alvo       package.json|' "$W/$FONTE_W"
  efeito '^    alvo       package\.json$' 1
  esperar 1 "T55 — o alvo trocado na fonte => VERMELHO" 'nao e o congelado'
fi

if caso_ativo T56; then
  reset T56
  ancora "$FONTE_W" '^    exige      corpoDoCaso\(GUARDA, "SF-02"\)$' 1
  sed -i '/^    exige      corpoDoCaso(GUARDA, "SF-02")$/d' "$W/$FONTE_W"
  sed -i '/corpoDoCaso(GUARDA, "SF-02")/d' "$W/functions-ranking/test/passe.test.js"
  recarimbar "functions-ranking/test/passe.test.js"
  efeito '^    exige      corpoDoCaso\(GUARDA, "SF-02"\)$' 0
  esperar 1 "T56 — relacao E afirmacao retiradas juntas, com digest recarimbado => VERMELHO" 'sumiu da fonte'
fi

printf '\n== a FASE B cobra log de TODO gate contratado, e a relacao vem da fonte ==\n'

if caso_ativo T57; then
  reset T57
  resultados "$TMP/res"
  ausencia "$FONTE_W" '^    casos      ' analyze
  awk '{ l = $0; sub(/\r$/, "", l); print l }
       l == "analyze" && !f { print "    casos      1"; print "    contador   pass [0-9]+"; f = 1 }' \
    "$BASE/$FONTE_W" > "$W/$FONTE_W"
  efeito '^    casos      1$' 1 analyze
  esperar 1 "T57 — gate que ganhou contrato e nao tem log => VERMELHO" 'nao deixou log' "$TMP/res"
fi

printf '\n== os AUTOCONTROLES do proprio instrumento ==\n'

if caso_ativo T67; then
  reset T67
  # `^comunicacao$` existe UMA vez na fonte. Declarar `ausencia` sobre algo
  # PRESENTE e mentira do vetor — e a insercao nao inseriria nada novo. Sem esta
  # recusa, `ausencia` viraria a porta de saida que `ancora 0` deixou de ser.
  ausencia "$FONTE_W" '^comunicacao$'
  esperar_instrumento_invalido "T67 — ausencia declarada sobre algo PRESENTE => INSTRUMENTO INVALIDO" 'ja aparece 1 vez(es)'
fi

# O INSTRUMENTO TAMBEM PRECISA SER MEDIDO. Ele existe para recusar sabotagem que
# nao aconteceu; um instrumento complacente devolveria "aconteceu" para tudo, e
# os sessenta e oito casos voltariam a poder medir nada. Estes nove provam que
# ele recusa — e cada um mede UM mecanismo, para que a rehomologacao possa
# julgar separadamente.

if caso_ativo T60; then
  reset T60
  ancora "$FONTE_W" '^    ancora_que_nunca_existiu$' 1
  esperar_instrumento_invalido "T60 — ancora com ZERO ocorrencias => INSTRUMENTO INVALIDO" 'casa 0 vez(es)'
fi

if caso_ativo T61; then
  reset T61
  # o bloco de `comunicacao` tem VINTE E SEIS `exige`; o vetor declara UM.
  ancora "$FONTE_W" '^    exige      ' 1 comunicacao
  esperar_instrumento_invalido "T61 — ancora com ocorrencias DEMAIS => INSTRUMENTO INVALIDO" 'e o vetor declara 1'
fi

if caso_ativo T62; then
  reset T62
  ancora "$FONTE_W" '^comunicacao$' 1
  # de proposito: NENHUMA transformacao entre a ancora e a pos-condicao.
  efeito '^comunicacao$' 1
  esperar_instrumento_invalido "T62 — transformacao que nao muda o digest => INSTRUMENTO INVALIDO" 'nao mudou um byte'
fi

if caso_ativo T63; then
  reset T63
  ancora "$FONTE_W" '^comunicacao$' 1
  sed -i 's/^comunicacao$/comunicacaoX/' "$W/$FONTE_W"
  # o digest MUDOU, mas a pos-condicao declarada nao aconteceu.
  efeito '^pos_condicao_que_nunca_acontece$' 1
  esperar_instrumento_invalido "T63 — digest muda e a pos-condicao NAO acontece => INSTRUMENTO INVALIDO" 'a pos-condicao'
fi

if caso_ativo T64; then
  reset T64
  # T64 SABOTA de verdade — e por isso declara `ausencia`/`efeito`, e nao
  # `sem_mutacao`. O que ele mede e a etapa SEGUINTE: a conferencia de
  # restauracao recusa quando a bancada nao volta ao original.
  ausencia "$FONTE_W" '^linha que a bancada nunca teve$'
  printf '\nlinha que a bancada nunca teve\n' >> "$W/$FONTE_W"
  efeito '^linha que a bancada nunca teve$' 1
  conferir_restauracao "$FONTE_W"
  esperar_instrumento_invalido "T64 — restauracao diferente do BASE => INSTRUMENTO INVALIDO" 'nao devolveu o conteudo original'
fi

if caso_ativo T68; then
  reset T68
  # `sem_mutacao` fora da relacao congelada de controles. Sem esta recusa, todo
  # vetor poderia trocar a propria sabotagem por "nao mexo em nada".
  sem_mutacao 'declaracao indevida, de proposito'
  esperar_instrumento_invalido "T68 — sem_mutacao fora dos controles congelados => INSTRUMENTO INVALIDO" 'so vale nos controles congelados'
fi

if caso_ativo T65; then
  reset T65
  # de proposito: NEM `ancora`, NEM `sem_mutacao`.
  esperar_instrumento_invalido "T65 — bloco sem ancora nem sem_mutacao => INSTRUMENTO INVALIDO" "nao declarou 'ancora' nem 'sem_mutacao'"
fi

if caso_ativo T66; then
  reset T66
  sem_mutacao 'o vetor mede o veredito unico, e nao o verificador'
  # SONDA: a primeira emissao passa, a segunda tem de ser recusada. O placar da
  # sonda e desfeito antes do veredito real — senao a propria prova contaminaria
  # a contagem que ela existe para proteger.
  T66_FALHOU_ANTES="$falhou"
  veredito_unico "sonda do veredito unico" > /dev/null
  if veredito_unico "segunda emissao" > /dev/null; then
    T66_ACEITOU=1
  else
    T66_ACEITOU=0
  fi
  falhou="$T66_FALHOU_ANTES"
  VEREDITO_DADO=0
  if [ "$T66_ACEITOU" -eq 1 ]; then
    nok "T66 — veredito unico: a SEGUNDA emissao foi aceita"
  else
    ok "T66 — veredito unico: a segunda emissao foi recusada"
  fi
fi


printf '\n== a matriz guarda a presenca da testemunha que a observa ==\n'

# A RECIPROCIDADE, DESTE LADO. A testemunha guarda a execucao integral da
# matriz; a matriz guarda a PRESENCA da testemunha. Nenhuma das duas afirma a
# propria execucao — cada uma responde pela outra.

if caso_ativo T58; then
  reset T58
  ancora_arquivo "scripts/ci/testemunha_contratosui.sh"
  rm -f "$W/scripts/ci/testemunha_contratosui.sh"
  efeito_sumiu
  esperar 1 "T58 — testemunha externa apagada => VERMELHO" 'removida ou renomeada'
fi

if caso_ativo T59; then
  reset T59
  ancora "$YML_W" 'scripts/ci/testemunha_contratosui\.sh' 3
  sed -i 's|scripts/ci/testemunha_contratosui.sh|scripts/ci/isca.sh|g' "$W/$YML_W"
  efeito 'scripts/ci/isca\.sh' 3
  esperar 1 "T59 — workflow deixou de invocar a testemunha => VERMELHO" 'nao tem a linha do executor'
fi

printf '\n== `exigenocaso` deixou de ser acumulado e ignorado (OS 40-C4) ==\n'

# O TERCEIRO ESCAPE DA FAMILIA, e o que a OS 40-R4 mediu como `S10`. As relacoes
# POR CASO eram lidas e acumuladas em `exigenocaso_do_gate` — e aquele numero
# nunca era comparado com coisa alguma. A guarda que distingue "o titulo e a
# afirmacao estao no mesmo caso" de "estao em dois casos-isca" podia ser
# desmontada uma linha por vez, e com a afirmacao trivializada ao lado a arvore
# ficava verde de ponta a ponta.

if caso_ativo T69; then
  reset T69
  # S10, INTEIRO: a relacao sai da fonte, a afirmacao funcional vira trivial na
  # suite, e o digest e recarimbado — tudo o que o atacante controla.
  ancora "$FONTE_W" '^    exigenocaso expect\(v\.aceita, isTrue,$' 1
  sed -i '/^    exigenocaso expect(v.aceita, isTrue,$/d' "$W/$FONTE_W"
  sed -i 's|^          expect(v.aceita, isTrue,$|          expect(true, isTrue,|' \
    "$W/app/test/comunicacao/comunicacao_test.dart"
  recarimbar "app/test/comunicacao/comunicacao_test.dart"
  efeito '^    exigenocaso expect\(v\.aceita, isTrue,$' 0
  esperar 1 "T69 — S10: relacao POR CASO retirada + afirmacao trivializada + recarimbo => VERMELHO" \
    'sumiu da fonte'
fi

if caso_ativo T70; then
  reset T70
  # A relacao sai da fonte E o piso generico e rebaixado no verificador. Quem
  # reprova aqui e o conjunto NOMINAL — a outra metade da defesa.
  ancora "$FONTE_W" '^    exigenocaso canal: canalDe' 1
  sed -i '/^    exigenocaso canal: canalDe/d' "$W/$FONTE_W"
  sed -i 's|^readonly PISOS_EXIGENOCASO="comunicacao:3 |readonly PISOS_EXIGENOCASO="comunicacao:2 |' \
    "$W/scripts/ci/verificar_contrato_suites.sh"
  efeito '^    exigenocaso canal: canalDe' 0
  esperar 1 "T70 — relacao retirada da fonte com o piso rebaixado junto => VERMELHO (conjunto nominal)" \
    'nao sao as congeladas'
fi

if caso_ativo T71; then
  reset T71
  # A entrada sai do conjunto NOMINAL e da fonte, juntas. Quem reprova agora e o
  # PISO — a primeira metade. As duas se cobrem.
  ancora "$FONTE_W" '^    exigenocaso for \(final especie in catalogados\.entries\) \{$' 1
  sed -i '/^    exigenocaso for (final especie in catalogados.entries) {$/d' "$W/$FONTE_W"
  sed -i '/^for (final especie in catalogados.entries) {$/d' \
    "$W/scripts/ci/verificar_contrato_suites.sh"
  efeito '^    exigenocaso for \(final especie in catalogados\.entries\) \{$' 0
  esperar 1 "T71 — entrada retirada do conjunto nominal E da fonte => VERMELHO (piso)" \
    'piso de relacoes POR CASO'
fi

if caso_ativo T72; then
  reset T72
  ancora "$FONTE_W" '^    exigenocaso expect\(v\.aceita, isTrue,$' 1
  awk '
    { l = $0; sub(/\r$/, "", l) }
    { print l }
    l == "    exigenocaso expect(v.aceita, isTrue," { print l }
  ' "$BASE/$FONTE_W" > "$W/$FONTE_W"
  efeito '^    exigenocaso expect\(v\.aceita, isTrue,$' 2
  esperar 1 "T72 — relacao POR CASO duplicada na fonte => VERMELHO" \
    'cardinalidade por caso mudou'
fi

if caso_ativo T73; then
  reset T73
  # A relacao continua na fonte, no gate certo, na suite certa — e sob OUTRO
  # caso. E a forma que uma contagem sozinha nunca pegaria.
  ancora "$FONTE_W" '^    exigenocaso .posterior ao carimbo.' 1
  awk '
    { l = $0; sub(/\r$/, "", l) }
    index(l, "exigenocaso ") == 5 && index(l, "posterior ao carimbo") > 0 { guardada = l; next }
    { print l }
    l == "    caso        T42" && guardada != "" { print guardada; guardada = "" }
  ' "$BASE/$FONTE_W" > "$W/$FONTE_W"
  efeito '^    exigenocaso .posterior ao carimbo.' 1
  esperar 1 "T73 — relacao POR CASO movida para outro caso => VERMELHO" \
    'nao sao as congeladas'
fi

if caso_ativo T74; then
  reset T74
  # A agulha continua no arquivo, e so como COMENTARIO. Busca plana aceitaria.
  ancora_arquivo "app/test/comunicacao/comunicacao_test.dart"
  sed -i 's|^          expect(v.aceita, isTrue,$|          // expect(v.aceita, isTrue,|' \
    "$W/app/test/comunicacao/comunicacao_test.dart"
  recarimbar "app/test/comunicacao/comunicacao_test.dart"
  efeito '^          // expect\(v\.aceita, isTrue,$' 1
  esperar 1 "T74 — a afirmacao do caso mantida SO em comentario => VERMELHO" \
    'SO como comentario'
fi

if caso_ativo T75; then
  reset T75
  # A afirmacao trocada por uma trivial, com a fonte INTACTA e o digest
  # recarimbado: o corpo do caso deixa de conter o que o contrato cobra.
  ancora_arquivo "app/test/comunicacao/comunicacao_test.dart"
  sed -i 's|^          expect(v.aceita, isTrue,$|          expect(true, isTrue,|' \
    "$W/app/test/comunicacao/comunicacao_test.dart"
  recarimbar "app/test/comunicacao/comunicacao_test.dart"
  efeito '^          expect\(true, isTrue,$' 1
  esperar 1 "T75 — afirmacao trocada por expect(true, isTrue, com recarimbo => VERMELHO" \
    'sumiu do CORPO do caso'
fi

if caso_ativo T76; then
  reset T76
  # `caso`/`exigenocaso` ACRESCENTADOS numa suite que nao tem conjunto congelado.
  # Sem esta recusa, a guarda por caso poderia ser diluida em suites novas.
  ausencia "$FONTE_W" '^    caso        AUT-01$'
  awk '
    { l = $0; sub(/\r$/, "", l) }
    { print l }
    l == "    provas     60" { print "    caso        AUT-01"; print "    exigenocaso expect(1, 1);" }
  ' "$BASE/$FONTE_W" > "$W/$FONTE_W"
  efeito '^    caso        AUT-01$' 1
  esperar 1 "T76 — caso/exigenocaso acrescentados fora do conjunto congelado => VERMELHO" \
    'NAO esta no conjunto congelado'
fi

printf '\n== a AUTORIDADE EXTERNA dos tres verificadores (OS 40-C4) ==\n'

# `V01`–`V10` da OS 40-R4 mediram o que faltava: as tres pecas que DECIDEM —
# `verificar_contrato_suites.sh`, `portao_os_integracao.sh` e
# `codigo_executavel.awk` — nao tinham digesto proprio, inventario proprio nem
# prova de que suas decisoes materiais continuam la.
#
# TODO VETOR ABAIXO RECARIMBA O QUE O ATACANTE CONTROLA. Sem isso, cada caso
# reprovaria pelo digesto e nenhum mediria a decisao — seriam onze copias do
# mesmo T12.

if caso_ativo T77; then
  reset T77
  sem_mutacao 'CONTROLE: a autoridade sobre a arvore integra'
  esperar_autoridade 0 "T77 CONTROLE — autoridade sobre a arvore integra => VERDE" 'AUTORIDADE DOS VERIFICADORES: VERDE'
fi

if caso_ativo T78; then
  reset T78
  # V04 — `contratosui` retirado dos mapas de piso. A chave some, `piso_de`
  # devolve vazio, a comparacao nao roda, e nada reprova.
  ancora "scripts/ci/verificar_contrato_suites.sh" 'contratosui:[0-9]' 4
  sed -i 's/ contratosui:[0-9]*//g' "$W/scripts/ci/verificar_contrato_suites.sh"
  recarimbar_autoridade "scripts/ci/verificar_contrato_suites.sh"
  efeito 'contratosui:[0-9]' 0
  esperar_autoridade 1 "T78 — V04: contratosui retirado dos mapas de piso => VERMELHO" \
    "saiu de 'PISOS_"
fi

if caso_ativo T79; then
  reset T79
  # V06 — a comparacao de piso neutralizada. Os mapas ficam, as mensagens ficam,
  # e nenhum piso e cobrado.
  ancora "scripts/ci/verificar_contrato_suites.sh" '[-]lt "\$piso"' 4
  sed -i 's/-lt "\$piso"/-lt 0/g' "$W/scripts/ci/verificar_contrato_suites.sh"
  recarimbar_autoridade "scripts/ci/verificar_contrato_suites.sh"
  efeito '[-]lt "\$piso"' 0
  esperar_autoridade 1 "T79 — V06: comparacao de piso neutralizada => VERMELHO" \
    'decisao material'
fi

if caso_ativo T80; then
  reset T80
  # V06 + E01 — a comparacao neutralizada, E os literais repostos dentro de um
  # heredoc. Uma busca textual acharia os quatro; o leitor de codigo VIVO, que e
  # o desta autoridade, nao acha nenhum.
  ancora "scripts/ci/verificar_contrato_suites.sh" '[-]lt "\$piso"' 4
  sed -i 's/-lt "\$piso"/-lt 0/g' "$W/scripts/ci/verificar_contrato_suites.sh"
  {
    printf '\n'
    printf 'cat <<HEREDOC_DA_FORJA > /dev/null\n'
    printf '  if [ "$exige_do_gate" -lt "$piso" ]; then\n'
    printf '  if [ "$exigenocaso_do_gate" -lt "$piso" ]; then\n'
    printf '  if [ "$provas_do_gate" -lt "$piso" ]; then\n'
    printf '  elif [ "$casos_esperados" -lt "$piso" ]; then\n'
    printf 'HEREDOC_DA_FORJA\n'
  } >> "$W/scripts/ci/verificar_contrato_suites.sh"
  recarimbar_autoridade "scripts/ci/verificar_contrato_suites.sh"
  efeito '[-]lt "\$piso"' 4
  esperar_autoridade 1 "T80 — V06+E01: comparacao neutralizada e literais repostos em heredoc => VERMELHO" \
    'decisao material'
fi

if caso_ativo T81; then
  reset T81
  # V07 — `erro()` esvaziado, com a MENSAGEM preservada. O verificador continua
  # imprimindo tudo o que imprimia, e nunca mais reprova.
  ancora "scripts/ci/verificar_contrato_suites.sh" '^  falhas=1$' 1
  sed -i '/^  falhas=1$/d' "$W/scripts/ci/verificar_contrato_suites.sh"
  recarimbar_autoridade "scripts/ci/verificar_contrato_suites.sh"
  efeito '^  falhas=1$' 0
  esperar_autoridade 1 "T81 — V07: erro() esvaziado com as mensagens preservadas => VERMELHO" \
    'decisao material'
fi

if caso_ativo T82; then
  reset T82
  # V08 — saida antecipada verde. Uma linha, e tudo o que vinha depois aprova.
  ausencia "scripts/ci/verificar_contrato_suites.sh" '^exit 0$'
  sed -i '0,/^set -u$/s//set -u\nexit 0/' "$W/scripts/ci/verificar_contrato_suites.sh"
  recarimbar_autoridade "scripts/ci/verificar_contrato_suites.sh"
  efeito '^exit 0$' 1
  esperar_autoridade 1 "T82 — V08: exit 0 antecipado no verificador => VERMELHO" \
    'saida antecipada verde'
fi

if caso_ativo T83; then
  reset T83
  # V09 — o lexer trocado por busca textual simples: o laco que responde por
  # agulha e desligado, e TODAS as declaracoes materiais continuam la, vivas.
  # Quem pega e a SONDA DE COMPORTAMENTO — nenhum recarimbo satisfaz uma resposta
  # que precisa ser calculada.
  ancora "scripts/ci/codigo_executavel.awk" '^  for \(j = 1; j <= n; j\+\+\) \{$' 1
  sed -i 's|^  for (j = 1; j <= n; j++) {$|  for (j = 1; j <= n \&\& 0; j++) {|' \
    "$W/scripts/ci/codigo_executavel.awk"
  recarimbar_autoridade "scripts/ci/codigo_executavel.awk"
  efeito '^  for \(j = 1; j <= n && 0; j\+\+\) \{$' 1
  esperar_autoridade 1 "T83 — V09: lexer trocado por busca textual simples => VERMELHO" \
    'ele virou busca textual'
fi

if caso_ativo T84; then
  reset T84
  # O piso de `exigenocaso` rebaixado NO VERIFICADOR. A matriz nao pega isso —
  # o verificador e quem declara o piso, e um piso menor continua satisfeito.
  # Quem pega e esta autoridade, de fora.
  ancora "scripts/ci/verificar_contrato_suites.sh" '^readonly PISOS_EXIGENOCASO="comunicacao:3' 1
  sed -i 's|^readonly PISOS_EXIGENOCASO="comunicacao:3 |readonly PISOS_EXIGENOCASO="comunicacao:1 |' \
    "$W/scripts/ci/verificar_contrato_suites.sh"
  recarimbar_autoridade "scripts/ci/verificar_contrato_suites.sh"
  efeito '^readonly PISOS_EXIGENOCASO="comunicacao:1 ' 1
  esperar_autoridade 1 "T84 — piso de exigenocaso rebaixado no verificador => VERMELHO" \
    'caiu de 3 para 1'
fi

if caso_ativo T85; then
  reset T85
  # O agregador esvaziado: `falhou=1` some das seis decisoes, e o portao passa a
  # ficar verde sobre gate vermelho. Com o digesto recarimbado no mesmo golpe.
  ancora "scripts/ci/portao_os_integracao.sh" '^ +falhou=1$' 6
  sed -i '/^ *falhou=1$/d' "$W/scripts/ci/portao_os_integracao.sh"
  recarimbar_autoridade "scripts/ci/portao_os_integracao.sh"
  efeito '^ +falhou=1$' 0
  esperar_autoridade 1 "T85 — agregador esvaziado com o digesto recarimbado => VERMELHO" \
    'decisao material'
fi

if caso_ativo T86; then
  reset T86
  # O verificador RETIRADO do inventario da autoridade. Sem registro nao ha
  # digesto, e sem digesto a peca deixaria de ser guardada em silencio.
  ancora "scripts/ci/autoridade_verificadores.sh" '^scripts/ci/portao_os_integracao\.sh [0-9a-f]' 1
  sed -i '/^scripts\/ci\/portao_os_integracao\.sh [0-9a-f]/d' \
    "$W/scripts/ci/autoridade_verificadores.sh"
  efeito '^scripts/ci/portao_os_integracao\.sh [0-9a-f]' 0
  esperar_autoridade 1 "T86 — verificador retirado do inventario da autoridade => VERMELHO" \
    'NAO tem digesto no inventario'
fi

if caso_ativo T87; then
  reset T87
  # DOIS registros para o mesmo caminho: a comparacao passaria a depender de qual
  # deles fosse lido primeiro.
  ancora "scripts/ci/autoridade_verificadores.sh" '^scripts/ci/codigo_executavel\.awk [0-9a-f]' 1
  awk '
    { l = $0; sub(/\r$/, "", l) }
    { print l }
    l ~ /^scripts\/ci\/codigo_executavel\.awk [0-9a-f]/ { print "scripts/ci/codigo_executavel.awk 0000000000000000000000000000000000000000000000000000000000000000" }
  ' "$BASE/scripts/ci/autoridade_verificadores.sh" > "$W/scripts/ci/autoridade_verificadores.sh"
  efeito '^scripts/ci/codigo_executavel\.awk [0-9a-f]' 2
  esperar_autoridade 1 "T87 — digesto duplicado no inventario => VERMELHO" \
    'registros de digesto'
fi

if caso_ativo T88; then
  reset T88
  # A tentativa de neutralizar a PROPRIA autoridade. Ela nao se guarda — quem
  # responde por ela e o contrato de conteudo, com digesto e `exige` na fonte.
  ancora "scripts/ci/autoridade_verificadores.sh" '^readonly MINIMOS_EXIGENOCASO=' 1
  sed -i '/^readonly MINIMOS_EXIGENOCASO=/d' "$W/scripts/ci/autoridade_verificadores.sh"
  efeito '^readonly MINIMOS_EXIGENOCASO=' 0
  esperar 1 "T88 — a propria autoridade adulterada => VERMELHO no contrato de conteudo" \
    'mudou e a assinatura nao'
fi

printf '\n== controle final ==\n'
if caso_ativo T34; then
  reset T34
  sem_mutacao 'CONTROLE final: a arvore restaurada nao e sabotada'
  esperar 0 "T34 CONTROLE — arvore restaurada => VERDE de novo" 'tudo no lugar'
fi

# O PLACAR SO SAI NO MODO COMPLETO, e ele e DIAGNOSTICO HUMANO — nao autoridade.
# Quem responde pelo gate conta os casos por conta propria, um a um, e recusa
# qualquer linha de placar que apareca dentro da execucao de um caso sozinho.
if [ "$MODO" = 'completo' ]; then
  printf '\n----------------------------------------\n'
  printf 'casos ok: %d | casos com falha: %d\n' "$passou" "$falhou"
  printf 'este placar e diagnostico: a autoridade e testemunha_contratosui.sh\n'
fi

# No modo `--caso`, um identificador que o fluxo nao alcanca nao pode sair com
# zero: seria "passou" para um caso que nunca existiu.
if [ "$MODO" = 'caso' ] && [ "$executou" -eq 0 ]; then
  printf 'teste do contrato: o caso %s NAO FOI ALCANCADO pelo fluxo\n' "$SO_CASO" >&2
  exit 2
fi

if [ "$falhou" -eq 0 ]; then
  [ "$MODO" = 'completo' ] && printf 'TESTE DO CONTRATO: VERDE\n'
  exit 0
fi

[ "$MODO" = 'completo' ] && printf 'TESTE DO CONTRATO: VERMELHO\n'
exit 1
