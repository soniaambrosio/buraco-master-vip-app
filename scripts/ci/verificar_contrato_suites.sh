#!/usr/bin/env bash
#
# CONTRATO DE CONTEUDO DAS SUITES PROTEGIDAS — gate `contratosui`.
#
#   uso: verificar_contrato_suites.sh <raiz> [workflow] [dir_resultados]
#
#     raiz            raiz do repositorio (`.` num checkout normal).
#     workflow        opcional. Sem ele, as conferencias de registro no CI nao
#                     rodam. No CI ele e SEMPRE dado.
#     dir_resultados  opcional. Com ele, roda tambem a FASE B (abaixo).
#
# ---------------------------------------------------------------------------
# POR QUE ESTE ARQUIVO EXISTE
# ---------------------------------------------------------------------------
#
# A fonte unica `scripts/ci/gates_os_integracao.txt` ja respondia duas das tres
# perguntas que um portao precisa responder sobre uma suite obrigatoria:
#
#   1. o ARQUIVO esta la?  -> o auxiliar `roda` escreve `nao_<gate>` quando nao
#                             esta, e o agregador reprova NAO EXECUTADO
#   2. ela foi EXECUTADA?  -> so `exit_<gate>` valendo exatamente `0` passa
#   3. ela ainda PROVA?    -> NINGUEM PERGUNTAVA
#
# A terceira e o buraco que a rehomologacao da OS 30 mediu em outra linhagem:
# trocar o corpo de uma suite obrigatoria por um unico `expect(1, 1)` — mantendo
# nome, caminho, sufixo `_test.dart` e o registro no workflow — deixava TODOS os
# portoes verdes, com dezenas de provas a menos no run. Arquivo presente,
# execucao registrada, conteudo esvaziado.
#
# Este script fecha a terceira pergunta, e a fecha DENTRO da autoridade que ja
# existe: o contrato mora em linhas indentadas sob o gate, na fonte unica de
# sempre. Nao ha segundo manifesto e nao ha segunda relacao de gates — a relacao
# vem de `portao_os_integracao.sh --listar`, o unico leitor.
#
# ---------------------------------------------------------------------------
# O CONTRATO
# ---------------------------------------------------------------------------
#
#   <gate>                                  <- na margem, como sempre
#       suite      <caminho relativo a raiz do repo>
#       executor   <trecho literal que o workflow tem de conter>
#       sha256     <64 hex do conteudo, com TODO CR removido>
#       provas     <piso ESTATICO de declaracoes de caso>
#       conta      <ERE das declaracoes>     (opcional; padrao = Dart)
#       casos      <piso de casos EXECUTADOS, lido do log>   (opcional)
#       contador   <ERE com numero, no log>  (opcional; padrao = `+N` do Flutter)
#       exige      <literal de codigo que tem de continuar la>   (repetivel)
#
# `provas` e ESTATICO de proposito: a guarda precisa reprovar sem executar a
# suite que ela guarda, e ANTES dela. `casos` e o mesmo piso do outro lado — lido
# do log da execucao — e existe porque contagem estatica nao ve caso gerado em
# laco: a suite da Comunicacao declara 71 `test(` e executa 81.
#
# `exige` casa por literal INCLUINDO o parentese da chamada, e a busca IGNORA
# linha de comentario. Sem isso, uma suite esvaziada cujos comentarios
# repetissem os literais satisfaria o contrato sem provar nada — a forja mais
# barata que existe contra busca textual.
#
# A assinatura e sobre o conteudo com TODO CR removido: o indice do git guarda
# LF, a arvore de trabalho no Windows tem CRLF (`core.autocrlf=true`) e o runner
# do Actions ve LF. Assinar os bytes crus valeria numa plataforma e mentiria na
# outra.
#
# ---------------------------------------------------------------------------
# AS DUAS FASES
# ---------------------------------------------------------------------------
#
# FASE A (sempre) — estatica. Roda ANTES de Flutter, de Node e de emulador, e
# FALHA POR CONTA PROPRIA, com exit diferente de zero. Um verificador cuja
# reprovacao precisa ser somada num portao la na frente herda o defeito que veio
# consertar.
#
# FASE B (so com <dir_resultados>) — o log. Fecha as duas formas de ficar verde
# sem ter rodado: marcador FABRICADO (um `exit_<gate>` com `0` dentro e nenhum
# log ao lado) e evidencia de OUTRA EXECUCAO (um log mais velho que o carimbo que
# o proprio run escreveu). E onde `casos` e conferido.
#
# ---------------------------------------------------------------------------
# ATE ONDE ELE ALCANCA
# ---------------------------------------------------------------------------
#
# Ele NAO pega quem apagar o passo que o invoca do workflow — nenhuma
# verificacao dentro de um workflow cobre a propria remocao do workflow. O que
# ele faz e nao deixar isso ser silencioso: a chave `contratosui` esta na fonte
# unica, o agregador reprova por ausencia de resultado, e a FASE A exige que a
# propria invocacao continue escrita no YAML.

set -u

raiz="${1:-.}"
workflow="${2:-}"
dir_resultados="${3:-}"

fonte="$raiz/scripts/ci/gates_os_integracao.txt"
agregador="$raiz/scripts/ci/portao_os_integracao.sh"

# ---------------------------------------------------------------------------
# O QUE ESTE SCRIPT EXIGE DE SI MESMO
#
# Escrito AQUI, e nao so na fonte unica, pela mesma razao que a fonte unica nao
# se guarda sozinha: esvaziar o contrato no arquivo de dados seria a saida
# silenciosa que este script veio fechar. A fonte pode CRESCER com decisoes
# futuras; nao pode encolher ate zero, nem perder estas chaves, nem rebaixar
# estes pisos.
# ---------------------------------------------------------------------------
# `admvip` guarda a origem do entitlement que a admissao em Torneios consome.
# Ele entrou nesta regua porque a campanha negativa da OS 42-C1 mediu o buraco:
# tirar a entrada inteira da fonte unica passava em SILENCIO, e um gate que some
# sem reprovar e um gate que nao existe.
#
# `torneiobase` tem o MESMO buraco e NAO foi acrescentado aqui: a canonizacao
# daquela suite (recarimbo do digest e elevacao do piso) e reserva declarada da
# OS 42-C2, e mexer na protecao dela agora invadiria essa reserva. A divida fica
# medida e registrada, nao esquecida.
readonly CONTRATOS_MINIMOS="comunicacao chatdom portaoci contratosui admvip"
readonly PISOS_PROVAS="comunicacao:71 chatdom:60 portaoci:49 contratosui:37 admvip:48"
readonly PISOS_CASOS="comunicacao:81 portaoci:38 contratosui:34 admvip:48"

readonly CONTA_PADRAO='^[[:blank:]]*(test|testWidgets)\('
readonly CONTADOR_PADRAO='\+[0-9]+'

# A propria invocacao, que o workflow tem de continuar carregando.
readonly INVOCACAO='scripts/ci/verificar_contrato_suites.sh'

falhas=0
erro() {
  printf 'CONTRATO DE SUITE: %s\n' "$*"
  falhas=1
}

piso_de() {
  local tabela="$1" alvo="$2" par
  for par in $tabela; do
    case "$par" in
      "$alvo":*) printf '%s' "${par#*:}"; return 0 ;;
    esac
  done
  printf '%s' ''
}

# Espaco em branco espremido: o YAML alinha `roda <gate>  <caminho>` em colunas,
# e um contrato que dependesse da largura do alinhamento reprovaria na proxima
# vez que alguem alinhasse a tabela.
espremer() {
  printf '%s' "$1" | tr -s '[:blank:]' ' ' | sed -e 's/^ //' -e 's/ $//'
}

if [ ! -f "$fonte" ] || [ ! -r "$fonte" ]; then
  printf 'CONTRATO DE SUITE: fonte unica ausente ou ilegivel em %s\n' "$fonte"
  exit 1
fi

if [ ! -f "$agregador" ] || [ ! -r "$agregador" ]; then
  printf 'CONTRATO DE SUITE: agregador ausente em %s\n' "$agregador"
  exit 1
fi

# A RELACAO DE GATES VEM DO AGREGADOR, nao de um `sed | awk` local. Reimplementar
# a leitura aqui criaria o segundo leitor, e dois leitores sao duas autoridades
# em potencial: foi de duas listas escritas a mao que o CI-02 nasceu.
if ! GATES_DA_FONTE="$(bash "$agregador" --listar "$fonte" 2>&1)"; then
  printf 'CONTRATO DE SUITE: o agregador recusou a fonte unica:\n%s\n' "$GATES_DA_FONTE"
  exit 1
fi

eh_gate() {
  local g
  for g in $GATES_DA_FONTE; do [ "$g" = "$1" ] && return 0; done
  return 1
}

conteudo_workflow=''
workflow_espremido=''
if [ -n "$workflow" ]; then
  if [ ! -f "$workflow" ]; then
    printf 'CONTRATO DE SUITE: workflow ausente em %s\n' "$workflow"
    exit 1
  fi
  conteudo_workflow="$(tr -d '\r' < "$workflow")"
  # Normalizado UMA vez, e comparado depois com casamento de padrao do proprio
  # bash. Um `grep` por entrada custava quatro processos sobre quarenta KB, e
  # esta guarda e chamada trinta e quatro vezes pela matriz que a verifica.
  workflow_espremido=$'\n'"$(printf '%s\n' "$conteudo_workflow" |
    tr -s '[:blank:]' ' ' | sed -e 's/^ //' -e 's/ $//')"$'\n'
fi

# ---------------------------------------------------------------------------
# FASE A — o contrato, conferido sem executar nada
# ---------------------------------------------------------------------------

contratados=''
com_contrato=0

conferir_entrada() {
  [ -z "$chave" ] && return 0
  if [ -z "$suite$executor$sha_esperado$provas_esperadas$exige_lista$casos_esperados$conta_ere$contador_ere" ]; then
    return 0
  fi

  com_contrato=$((com_contrato + 1))
  contratados="$contratados $chave"

  if ! eh_gate "$chave"; then
    erro "'$chave' tem contrato e NAO e um gate obrigatorio da fonte unica"
  fi

  # ---- a suite -----------------------------------------------------------
  local arquivo=''
  if [ -z "$suite" ]; then
    erro "a entrada '$chave' nao declara 'suite'"
  else
    arquivo="$raiz/$suite"
    if [ -f "$arquivo" ]; then
      printf 'ok   arquivo    %-12s %s\n' "$chave" "$suite"
    else
      erro "suite removida ou renomeada: '$suite' (gate $chave)"
      arquivo=''
    fi
  fi

  # ---- o executor --------------------------------------------------------
  if [ -z "$executor" ]; then
    erro "a entrada '$chave' nao declara 'executor'"
  elif [ -n "$suite" ]; then
    # O executor tem de apontar para a suite que ele diz rodar. Sem isto, o
    # contrato aceitaria um passo que roda outra coisa: produtor sem alvo, que e
    # o degrau seguinte ao gate fantasma.
    local alvo="${suite#app/}"
    case "$executor" in
      *"$alvo"*) ;;
      *) erro "o 'executor' de '$chave' nao cita a suite '$alvo'" ;;
    esac
  fi

  if [ -n "$conteudo_workflow" ] && [ -n "$executor" ]; then
    local alvo_esp
    alvo_esp="$(espremer "$executor")"
    case "$workflow_espremido" in
      *$'\n'"$alvo_esp"$'\n'*)
        printf 'ok   executor   %-12s %s\n' "$chave" "$alvo_esp"
        ;;
      *) erro "o workflow nao tem a linha do executor de '$chave': '$alvo_esp'" ;;
    esac

    # O marcador pode ser escrito LITERALMENTE (`echo ... > exit_proveni`) ou
    # pelo auxiliar `roda`, que o monta como "exit_$k". Aceitar so a forma
    # literal reprovaria toda suite Flutter do workflow — e reprovar por engano
    # e a pressao que leva alguem a afrouxar a guarda.
    case "$conteudo_workflow$workflow_espremido" in
      *"exit_$chave"* | *$'\n'"roda $chave "*)
        printf 'ok   marcador   %-12s exit_%s\n' "$chave" "$chave"
        ;;
      *) erro "o workflow nao produz 'exit_$chave' — gate declarado sem produtor" ;;
    esac
  fi

  # ---- o contrato tem de estar COMPLETO ----------------------------------
  if [ -z "$sha_esperado" ]; then
    erro "a entrada '$chave' nao declara 'sha256'"
  elif ! printf '%s' "$sha_esperado" | grep -Eq '^[0-9a-f]{64}$'; then
    erro "o 'sha256' de '$chave' nao e um digest de 64 hex: '$sha_esperado'"
    sha_esperado=''
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

  # ---- os pisos escritos AQUI nao podem ser rebaixados na fonte ----------
  local piso
  piso="$(piso_de "$PISOS_PROVAS" "$chave")"
  if [ -n "$piso" ] && [ -n "$provas_esperadas" ]; then
    if [ "$provas_esperadas" -lt "$piso" ]; then
      erro "o piso de provas de '$chave' foi baixado de $piso para $provas_esperadas na fonte"
    else
      printf 'ok   piso       %-12s provas %s >= %s\n' "$chave" "$provas_esperadas" "$piso"
    fi
  fi
  piso="$(piso_de "$PISOS_CASOS" "$chave")"
  if [ -n "$piso" ]; then
    if [ -z "$casos_esperados" ]; then
      erro "a entrada '$chave' deixou de declarar 'casos' (piso $piso)"
    elif ! printf '%s' "$casos_esperados" | grep -Eq '^[0-9]+$'; then
      erro "o 'casos' de '$chave' nao e um numero: '$casos_esperados'"
      casos_esperados=''
    elif [ "$casos_esperados" -lt "$piso" ]; then
      erro "o piso de casos de '$chave' foi baixado de $piso para $casos_esperados na fonte"
    else
      printf 'ok   piso       %-12s casos %s >= %s\n' "$chave" "$casos_esperados" "$piso"
    fi
  fi

  # ---- assinatura, contagem e blocos ------------------------------------
  if [ -n "$arquivo" ]; then
    local sha_real
    sha_real="$(tr -d '\r' < "$arquivo" | sha256sum | awk '{print $1}')"
    if [ -n "$sha_esperado" ]; then
      if [ "$sha_real" = "$sha_esperado" ]; then
        printf 'ok   assinatura %-12s %s...\n' "$chave" "${sha_real:0:16}"
      else
        erro "o conteudo de '$suite' (gate $chave) mudou e a assinatura nao."
        erro "  esperado $sha_esperado"
        erro "  no disco $sha_real"
        erro "  se a mudanca e legitima, atualize 'sha256' na fonte NO MESMO commit"
      fi
    fi

    local ere_conta provas_reais
    ere_conta="${conta_ere:-$CONTA_PADRAO}"
    provas_reais="$(tr -d '\r' < "$arquivo" | grep -acE "$ere_conta")" || provas_reais=0
    if [ -n "$provas_esperadas" ]; then
      if [ "$provas_reais" -ge "$provas_esperadas" ]; then
        printf 'ok   provas     %-12s %s >= %s\n' "$chave" "$provas_reais" "$provas_esperadas"
      else
        erro "'$suite' (gate $chave) tem $provas_reais declaracoes e o piso e $provas_esperadas"
      fi
    fi

    # O corpo SEM COMENTARIO, lido uma vez so. A busca ignora linha de
    # comentario porque repetir os literais num comentario e a forja mais barata
    # que existe contra busca textual — e uma suite esvaziada com os comentarios
    # intactos satisfaria o contrato sem provar nada.
    local codigo faltando=0 padrao
    # O byte NUL sai junto com o CR: ha .dart neste repositorio com NUL no meio
    # de um literal (a suite da Comunicacao prova a recusa de caractere de
    # controle usando o proprio caractere de controle), e sem isto o bash avisa
    # que ignorou o byte — barulho que nao muda o casamento de literal nenhum.
    # A ASSINATURA NAO PASSA POR AQUI: ela le o arquivo direto, byte a byte.
    codigo="$(tr -d '\r\000' < "$arquivo" | grep -avE '^[[:blank:]]*(//|#)')"
    while IFS= read -r padrao; do
      [ -z "$padrao" ] && continue
      case "$codigo" in
        *"$padrao"*) ;;
        *)
          erro "o bloco $padrao sumiu de '$suite' (gate $chave)"
          faltando=$((faltando + 1))
          ;;
      esac
    done <<CONTRATO_EXIGE
$exige_lista
CONTRATO_EXIGE
    if [ "$faltando" -eq 0 ] && [ -n "$exige_lista" ]; then
      printf 'ok   blocos     %-12s %s conferido(s)\n' "$chave" \
        "$(printf '%s\n' "$exige_lista" | grep -c .)"
    fi
  fi

  # ---- FASE B — o log da execucao ---------------------------------------
  [ -z "$dir_resultados" ] && return 0

  local log="$dir_resultados/t_$chave.log"
  if [ ! -s "$log" ]; then
    erro "o gate '$chave' nao deixou log ('$log' ausente ou vazio) — marcador sem execucao"
    return 0
  fi

  local carimbo="$dir_resultados/carimbo_execucao"
  if [ ! -f "$carimbo" ]; then
    erro "carimbo de execucao ausente em '$carimbo' — sem ele nao ha como datar a evidencia"
  elif [ "$carimbo" -nt "$log" ]; then
    erro "o log de '$chave' e ANTERIOR ao carimbo deste run: evidencia de outra execucao"
  else
    printf 'ok   log        %-12s posterior ao carimbo\n' "$chave"
  fi

  if [ -n "$casos_esperados" ]; then
    local ere_contador maior n
    ere_contador="${contador_ere:-$CONTADOR_PADRAO}"
    maior=0
    for n in $(grep -aoE "$ere_contador" "$log" | grep -oE '[0-9]+'); do
      [ "$n" -gt "$maior" ] && maior="$n"
    done
    if [ "$maior" -ge "$casos_esperados" ]; then
      printf 'ok   casos      %-12s %s >= %s (no log)\n' "$chave" "$maior" "$casos_esperados"
    else
      erro "'$chave' executou $maior caso(s) e o piso e $casos_esperados — a suite encolheu"
    fi
  fi
}

chave=''
suite=''
executor=''
sha_esperado=''
provas_esperadas=''
casos_esperados=''
conta_ere=''
contador_ere=''
exige_lista=''

# A leitura e feita SO com expansao de parametro, sem `sed`/`awk`/`tr` por
# linha. Nao e microotimizacao: a versao com um pipe por linha custava ~800
# processos por execucao, e esta guarda e chamada trinta e quatro vezes pela
# propria matriz de `teste_contrato_suites.sh` — uma bancada que leva vinte
# minutos e uma bancada que ninguem roda antes de commitar.
while IFS= read -r bruta || [ -n "$bruta" ]; do
  linha="${bruta//$'\r'/}"
  nu="${linha#"${linha%%[![:blank:]]*}"}"
  case "$nu" in
    '' | '#'*) continue ;;
  esac

  case "$linha" in
    [[:blank:]]*)
      if [ -z "$chave" ]; then
        erro "atributo de contrato antes de qualquer gate: '$linha'"
        continue
      fi
      nome="${nu%%[[:blank:]]*}"
      valor="${nu#"$nome"}"
      valor="${valor#"${valor%%[![:blank:]]*}"}"
      valor="${valor%"${valor##*[![:blank:]]}"}"
      if [ -z "$valor" ]; then
        erro "atributo '$nome' sem valor no contrato de '$chave'"
        continue
      fi
      case "$nome" in
        suite)
          [ -n "$suite" ] && erro "'suite' repetido em '$chave'"
          suite="$valor"
          ;;
        executor)
          [ -n "$executor" ] && erro "'executor' repetido em '$chave'"
          executor="$valor"
          ;;
        sha256)
          [ -n "$sha_esperado" ] && erro "'sha256' repetido em '$chave'"
          sha_esperado="$valor"
          ;;
        provas)
          [ -n "$provas_esperadas" ] && erro "'provas' repetido em '$chave'"
          provas_esperadas="$valor"
          ;;
        casos)
          [ -n "$casos_esperados" ] && erro "'casos' repetido em '$chave'"
          casos_esperados="$valor"
          ;;
        conta)
          [ -n "$conta_ere" ] && erro "'conta' repetido em '$chave'"
          conta_ere="$valor"
          ;;
        contador)
          [ -n "$contador_ere" ] && erro "'contador' repetido em '$chave'"
          contador_ere="$valor"
          ;;
        exige)
          if [ -z "$exige_lista" ]; then
            exige_lista="$valor"
          else
            exige_lista="$exige_lista
$valor"
          fi
          ;;
        *) erro "atributo desconhecido '$nome' no contrato de '$chave'" ;;
      esac
      continue
      ;;
  esac

  conferir_entrada

  chave="$nu"
  suite=''
  executor=''
  sha_esperado=''
  provas_esperadas=''
  casos_esperados=''
  conta_ere=''
  contador_ere=''
  exige_lista=''
done < "$fonte"

conferir_entrada

# ---------------------------------------------------------------------------
# O contrato nao pode encolher ate zero, nem perder as chaves minimas
# ---------------------------------------------------------------------------

if [ "$com_contrato" -eq 0 ]; then
  erro "nenhum gate da fonte unica carrega contrato — a protecao de conteudo foi esvaziada"
fi

for k in $CONTRATOS_MINIMOS; do
  achou=0
  for c in $contratados; do
    [ "$c" = "$k" ] && achou=1
  done
  if [ "$achou" -eq 0 ]; then
    erro "o gate '$k' perdeu o contrato de conteudo na fonte unica"
  fi
done

# ---------------------------------------------------------------------------
# A propria invocacao continua no workflow
# ---------------------------------------------------------------------------

if [ -n "$conteudo_workflow" ]; then
  if printf '%s\n' "$conteudo_workflow" | grep -Fq -- "$INVOCACAO"; then
    printf 'ok   invocacao  %-12s %s\n' '(este)' "$INVOCACAO"
  else
    erro "o workflow nao invoca mais '$INVOCACAO' — a guarda foi desligada"
  fi
fi

if [ "$falhas" -eq 0 ]; then
  printf 'contrato de suites: %d conferido(s), tudo no lugar\n' "$com_contrato"
else
  printf 'contrato de suites: REPROVADO\n'
fi

exit "$falhas"
