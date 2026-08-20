#!/usr/bin/env bash
# copiar_assets_de_dados.sh - copia os assets DECLARADOS NO PUBSPEC que sao
# ARQUIVO, e nao pasta.
#
# POR QUE ISTO EXISTE, e nao mais uma linha `cp` em cada workflow.
#
# O bloco `flutter: assets:` aceita duas formas: pasta (com barra no fim) e
# arquivo avulso (sem barra). Toda a montagem do repositorio so sabia da
# primeira: `montar_app.sh`, `release-aab.yml` e `web.yml` copiam pastas de arte
# e conferem a declaracao com um `sed` que exige prefixo `assets/` E barra final.
# Um arquivo avulso fora de `assets/` some das tres listas ao mesmo tempo, sem
# que nenhum portao reclame - e o build morre longe da causa:
#
#     Error detected in pubspec.yaml:
#     No file or variants found for asset: data/colecoes/catalogo.seed.json.
#     Error: Failed to build asset bundle
#
# Foi o que aconteceu com o catalogo de colecoes: declarado no pubspec, copiado
# so pelo `build.yml`, ausente nos outros tres caminhos - inclusive no
# `release-aab.yml`, que e o unico pipeline oficial de publicacao.
#
# A correcao nao podia ser um quarto `cp` digitado a mao: seria repetir o
# defeito, que e lista paralela. Este script LE A DECLARACAO e obedece a ela, de
# modo que declarar no pubspec passa a bastar.
#
# Uso: copiar_assets_de_dados.sh <dir-do-repo> <dir-do-projeto-montado>

set -euo pipefail

REPO="${1:?informe o diretorio do repositorio}"
DESTINO="${2:?informe o diretorio do projeto montado}"
PUBSPEC="$REPO/app/pubspec.yaml"

if [ ! -f "$PUBSPEC" ]; then
  echo "ERRO: $PUBSPEC nao existe." >&2
  exit 1
fi

# Le SO o bloco `assets:` de dentro de `flutter:`. Sair no primeiro item de
# nivel igual ou menor evita capturar listas de outras secoes (`fonts:`, por
# exemplo) caso alguma seja acrescentada depois.
entradas=$(awk '
  /^[[:space:]]*assets:[[:space:]]*$/ { dentro = 1; next }
  dentro && /^[[:space:]]*-[[:space:]]/ { sub(/^[[:space:]]*-[[:space:]]*/, ""); sub(/[[:space:]]*$/, ""); print; next }
  dentro && /^[[:space:]]*[^[:space:]#-]/ { dentro = 0 }
' "$PUBSPEC")

copiados=0
while IFS= read -r entrada; do
  [ -n "$entrada" ] || continue
  case "$entrada" in
    */) continue ;;   # pasta: quem copia e a montagem de assets de arte
  esac

  origem="$REPO/app/$entrada"
  if [ ! -f "$origem" ]; then
    echo "ERRO: o pubspec declara o asset '$entrada', que nao existe em app/." >&2
    echo "      Ou o arquivo entra no repositorio, ou a linha sai do pubspec." >&2
    exit 1
  fi

  mkdir -p "$DESTINO/$(dirname "$entrada")"
  cp "$origem" "$DESTINO/$entrada"
  echo "  asset de dados: $entrada ($(wc -c < "$origem") bytes)"
  copiados=$((copiados + 1))
done <<< "$entradas"

echo "==> $copiados asset(s) de dados copiado(s) para $DESTINO"
