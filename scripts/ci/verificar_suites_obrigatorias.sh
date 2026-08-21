#!/usr/bin/env bash
# verificar_suites_obrigatorias.sh — impede que uma suite obrigatoria seja
# desligada em silencio, e que ela seja ESVAZIADA em silencio.
#
# uso: verificar_suites_obrigatorias.sh <raiz_do_app> [workflow]
#
#   raiz_do_app  arvore em que as suites vivem — `app_build` no CI, `app` num
#                checkout normal.
#   workflow     opcional. Quando dado, as checagens de registro no CI tambem
#                rodam. No CI ele e sempre dado.
#
# ---------------------------------------------------------------------------
# O QUE ELE FECHA
# ---------------------------------------------------------------------------
#
# O auxiliar `roda` do workflow escreve `nao_<chave>` quando a suite nao esta
# no disco, e o portao trata isso como NAO EXECUTADO — que nao reprova. Para os
# gates que dependem de codebase opcional isso e o comportamento certo, e este
# script NAO o altera: ele nao olha os outros gates. Ele olha so a lista de
# `test/suites_obrigatorias.txt`, e para essa lista a ausencia e falha.
#
# ELE FALHA POR CONTA PROPRIA, com exit diferente de zero, em vez de depender de
# ser somado num portao la na frente. Um verificador cuja reprovacao precisa de
# outro passo para virar vermelho herda o defeito que veio consertar.
#
# ---------------------------------------------------------------------------
# O QUE A OS 30-C2 ACRESCENTOU: O CONTEUDO
# ---------------------------------------------------------------------------
#
# Provar que o ARQUIVO esta no disco nao prova que ele ainda PROVA. A
# rehomologacao mediu: trocar o corpo da suite de Ajustes por um unico
# `expect(1, 1)` — mantendo nome, caminho e registro — deixava os cinco portoes
# verdes, com trinta e quatro provas a menos no run.
#
# Por isso cada entrada do manifesto passou a carregar um CONTRATO, em linhas
# indentadas logo abaixo dela:
#
#   sha256   a assinatura do conteudo, normalizado sem CR
#   provas   o piso de declaracoes `test(` / `testWidgets(`
#   exige    um literal de codigo que tem de continuar na suite (uma por linha)
#
# As tres sao conferidas aqui, ANTES de qualquer teste rodar, e sem executar a
# suite que elas guardam — a contagem e estatica de proposito. Entrada sem
# contrato completo e erro: um contrato que pode ser omitido nao e contrato.
#
# ---------------------------------------------------------------------------
# POR QUE NORMALIZAR O CR ANTES DE ASSINAR
# ---------------------------------------------------------------------------
#
# O indice do git guarda LF; com `core.autocrlf=true` a arvore de trabalho no
# Windows tem CRLF, e o runner do Actions ve LF. Uma assinatura sobre os bytes
# crus valeria numa plataforma e mentiria na outra. Aqui e sempre `tr -d '\r'`,
# e o gate Dart faz `replaceAll('\r', '')` — a mesma conta, byte a byte.
#
# ---------------------------------------------------------------------------
# ATE ONDE ELE ALCANCA
# ---------------------------------------------------------------------------
#
# Ele pega: apagar a suite, renomea-la, tirar a linha `roda` do workflow, tirar
# a chave de uma das duas listas de gate, esvaziar o manifesto, apagar o
# manifesto, esvaziar a SUITE, encolhe-la abaixo do piso, remover um bloco
# obrigatorio e adulterar a assinatura.
#
# Ele NAO pega quem apagar o passo que o invoca. Nenhuma verificacao dentro de
# um workflow pode cobrir a propria remocao do workflow — a raiz de confianca
# termina ali, e o que a defende e o diff, nao um script.

set -u

raiz="${1:-app_build}"
workflow="${2:-}"
manifesto="$raiz/test/suites_obrigatorias.txt"

# A chave que ESTE script existe para proteger. Escrita aqui, e nao so no
# manifesto, para que esvaziar o manifesto nao seja uma saida: o arquivo pode
# crescer com decisoes futuras, mas nao pode encolher ate zero.
readonly CHAVE_MINIMA="a11yconf"

# O piso de provas que ESTA OS declarou, pela mesma razao: baixar `provas` no
# manifesto seria a saida silenciosa que o resto do arquivo veio fechar.
# Formato: <chave>:<piso>, separados por espaco.
readonly PISOS="a11yconf:35 suitesobrig:9 ligas7:40"

falhas=0
erro() {
  echo "SUITE OBRIGATORIA: $*"
  falhas=1
}

piso_declarado() {
  local alvo="$1" par
  for par in $PISOS; do
    case "$par" in
      "$alvo":*)
        printf '%s' "${par#*:}"
        return 0
        ;;
    esac
  done
  printf '%s' ''
}

if [ ! -f "$manifesto" ]; then
  echo "SUITE OBRIGATORIA: manifesto ausente em '$manifesto'"
  exit 1
fi

conteudo_workflow=""
if [ -n "$workflow" ]; then
  if [ ! -f "$workflow" ]; then
    echo "SUITE OBRIGATORIA: workflow ausente em '$workflow'"
    exit 1
  fi
  conteudo_workflow="$(tr -d '\r' < "$workflow")"
fi

entradas=0
tem_chave_minima=0

# Estado da entrada corrente. Uma entrada so e conferida quando a proxima
# comeca — ou no fim do arquivo —, porque o contrato dela vem depois dela.
chave=''
caminho=''
sha_esperado=''
provas_esperadas=''
exige_lista=''

conferir_entrada() {
  [ -z "$chave" ] && return 0

  entradas=$((entradas + 1))
  [ "$chave" = "$CHAVE_MINIMA" ] && tem_chave_minima=1

  local arquivo="$raiz/$caminho"

  if [ -f "$arquivo" ]; then
    echo "ok   arquivo    $chave  $arquivo"
  else
    erro "suite removida ou renomeada: '$arquivo' (gate $chave)"
    # Sem o arquivo no disco nao ha o que assinar nem o que contar; o registro
    # no workflow ainda vale a pena conferir, e e o que vem depois.
    arquivo=''
  fi

  # ---- o CONTRATO tem de existir ----------------------------------------
  if [ -z "$sha_esperado" ]; then
    erro "a entrada '$chave' nao declara 'sha256'"
  elif ! printf '%s' "$sha_esperado" | grep -Eq '^[0-9a-f]{64}$'; then
    erro "o 'sha256' de '$chave' nao e um digest de 64 hex: '$sha_esperado'"
  fi
  if [ -z "$provas_esperadas" ]; then
    erro "a entrada '$chave' nao declara 'provas'"
  elif ! printf '%s' "$provas_esperadas" | grep -Eq '^[0-9]+$'; then
    erro "o 'provas' de '$chave' nao e um numero: '$provas_esperadas'"
    provas_esperadas=''
  fi
  if [ -z "$exige_lista" ]; then
    erro "a entrada '$chave' nao declara nenhum 'exige'"
  fi

  # ---- o piso escrito AQUI nao pode ser rebaixado no manifesto ----------
  local piso
  piso="$(piso_declarado "$chave")"
  if [ -n "$piso" ] && [ -n "$provas_esperadas" ]; then
    if [ "$provas_esperadas" -lt "$piso" ]; then
      erro "o piso de '$chave' foi baixado de $piso para $provas_esperadas no manifesto"
    else
      echo "ok   piso       $chave  $provas_esperadas >= $piso"
    fi
  fi

  # ---- assinatura, contagem e blocos ------------------------------------
  if [ -n "$arquivo" ]; then
    local sha_real
    sha_real="$(tr -d '\r' < "$arquivo" | sha256sum | awk '{print $1}')"
    if [ -n "$sha_esperado" ]; then
      if [ "$sha_real" = "$sha_esperado" ]; then
        echo "ok   assinatura $chave  ${sha_real:0:16}..."
      else
        erro "o conteudo de '$arquivo' (gate $chave) mudou e a assinatura nao."
        erro "  esperado $sha_esperado"
        erro "  no disco $sha_real"
        erro "  se a mudanca e legitima, atualize 'sha256' no manifesto no mesmo commit"
      fi
    fi

    local provas_reais
    provas_reais="$(tr -d '\r' < "$arquivo" |
      grep -cE '^[[:blank:]]*(test|testWidgets)\(')" || provas_reais=0
    if [ -n "$provas_esperadas" ]; then
      if [ "$provas_reais" -ge "$provas_esperadas" ]; then
        echo "ok   provas     $chave  $provas_reais >= $provas_esperadas"
      else
        erro "'$arquivo' (gate $chave) tem $provas_reais provas e o piso e $provas_esperadas"
      fi
    fi

    # A busca do `exige` ignora linhas de comentario. Sem isso, uma suite
    # esvaziada cujos comentarios repetissem os literais satisfaria o contrato
    # sem provar nada — a forja mais barata que existe contra busca textual.
    local faltando=0 padrao
    while IFS= read -r padrao; do
      [ -z "$padrao" ] && continue
      if ! tr -d '\r' < "$arquivo" | grep -vE '^[[:blank:]]*//' |
        grep -Fq -- "$padrao"; then
        erro "o bloco $padrao sumiu de '$arquivo' (gate $chave)"
        faltando=$((faltando + 1))
      fi
    done <<EOF
$exige_lista
EOF
    if [ "$faltando" -eq 0 ] && [ -n "$exige_lista" ]; then
      echo "ok   blocos     $chave  $(printf '%s\n' "$exige_lista" | grep -c .) conferido(s)"
    fi
  fi

  # ---- registro no workflow ---------------------------------------------
  [ -z "$conteudo_workflow" ] && return 0

  if printf '%s\n' "$conteudo_workflow" |
    grep -Eq "^[[:space:]]*roda[[:space:]]+$chave[[:space:]]+$caminho[[:space:]]*$"; then
    echo "ok   roda       $chave  $caminho"
  else
    erro "o workflow nao tem a linha 'roda $chave $caminho'"
  fi

  if printf '%s\n' "$conteudo_workflow" | grep -E '^[[:space:]]*GATES="' |
    grep -qw -- "$chave"; then
    echo "ok   evidencia  $chave"
  else
    erro "a chave '$chave' esta fora da lista GATES da evidencia"
  fi

  if printf '%s\n' "$conteudo_workflow" | grep -E '^[[:space:]]*for k in ' |
    grep -qw -- "$chave"; then
    echo "ok   portao     $chave"
  else
    erro "a chave '$chave' esta fora da lista do portao"
  fi
}

while IFS= read -r bruta || [ -n "$bruta" ]; do
  linha="$(printf '%s' "$bruta" | tr -d '\r')"
  nu="$(printf '%s' "$linha" | sed 's/^[[:space:]]*//')"
  case "$nu" in
    '' | '#'*) continue ;;
  esac

  # Linha indentada e ATRIBUTO da entrada de cima; linha na margem e ENTRADA.
  case "$linha" in
    [[:space:]]*)
      if [ -z "$chave" ]; then
        erro "atributo antes de qualquer entrada: '$linha'"
        continue
      fi
      nome="$(printf '%s\n' "$nu" | awk '{print $1}')"
      valor="$(printf '%s\n' "$nu" | sed 's/^[^[:space:]]*[[:space:]]*//')"
      if [ -z "$valor" ]; then
        erro "atributo sem valor no manifesto: '$linha'"
        continue
      fi
      case "$nome" in
        sha256) sha_esperado="$valor" ;;
        provas) provas_esperadas="$valor" ;;
        exige)
          if [ -z "$exige_lista" ]; then
            exige_lista="$valor"
          else
            exige_lista="$exige_lista
$valor"
          fi
          ;;
        *) erro "atributo desconhecido '$nome' no manifesto" ;;
      esac
      continue
      ;;
  esac

  conferir_entrada

  nova_chave="$(printf '%s\n' "$linha" | awk '{print $1}')"
  novo_caminho="$(printf '%s\n' "$linha" | awk '{print $2}')"
  sobra="$(printf '%s\n' "$linha" | awk '{print $3}')"

  chave=''
  caminho=''
  sha_esperado=''
  provas_esperadas=''
  exige_lista=''

  if [ -z "$nova_chave" ] || [ -z "$novo_caminho" ] || [ -n "$sobra" ]; then
    erro "linha malformada no manifesto: '$linha'"
    continue
  fi

  chave="$nova_chave"
  caminho="$novo_caminho"
done < "$manifesto"

conferir_entrada

if [ "$entradas" -eq 0 ]; then
  erro "manifesto sem nenhuma entrada — a lista foi esvaziada"
fi

if [ "$tem_chave_minima" -eq 0 ]; then
  erro "o manifesto nao lista mais o gate '$CHAVE_MINIMA'"
fi

if [ "$falhas" -eq 0 ]; then
  echo "suites obrigatorias: $entradas conferida(s), tudo no lugar"
else
  echo "suites obrigatorias: REPROVADO"
fi

exit "$falhas"
