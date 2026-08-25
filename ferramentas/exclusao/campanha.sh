#!/usr/bin/env bash
#
# campanha.sh — sobe o emulador UMA vez e roda a campanha negativa inteira.
#
#   uso (a partir da raiz do repositorio):
#     bash ferramentas/exclusao/campanha.sh
#
# ===========================================================================
# POR QUE UM `emulators:exec` SO
# ===========================================================================
#
# Cada `firebase emulators:exec` custa quase dois minutos so de subida — o
# tempo dos testes e uma fracao disso. Com dezoito mutacoes, encadear um exec
# por mutacao seria meia hora de espera para dois minutos de medicao.
#
# E ha um custo pior que o tempo: nesta arvore, encadear `emulators:exec`
# deixa a porta 8080 presa entre as execucoes, e a chamada seguinte falha por
# porta ocupada — o que o arnes leria como mutacao INVALIDA, e um laudo com
# dezoito invalidas nao mede cobertura nenhuma.
#
# Entao o emulador sobe uma vez e o arnes roda inteiro dentro dele.
#
# ===========================================================================
# JAVA
# ===========================================================================
#
# `java` nao esta no PATH desta maquina, e `JAVA_HOME` vem vazio. O JDK que
# funciona e o JBR do Android Studio. O bloco abaixo so preenche o que faltar:
# uma maquina que ja tenha Java no PATH passa direto.

set -u

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$RAIZ" || exit 2

if ! command -v java >/dev/null 2>&1 && [ -z "${JAVA_HOME:-}" ]; then
  JBR="/c/Program Files/Android/Android Studio/jbr"
  if [ -x "$JBR/bin/java.exe" ]; then
    export JAVA_HOME="C:/Program Files/Android/Android Studio/jbr"
    export PATH="$JBR/bin:$PATH"
  else
    printf 'campanha.sh: nao achei Java. O Firestore Emulator nao sobe sem ele.\n' >&2
    exit 2
  fi
fi

# A SABOTAGEM DO PORTAO VEM PRIMEIRO, e de proposito: ela nao precisa de
# emulador, e se ela reprovar nao ha razao para gastar dois minutos subindo um.
# Um `contafn`/`contaemu` fora da fonte unica esvazia as dezoito mutacoes.
bash ferramentas/exclusao/portao_nao_executado.sh || exit 1
printf '\n'

exec firebase emulators:exec --only firestore,auth --project demo-bmv \
  "node ferramentas/exclusao/campanha_chat_ritmo.js"
