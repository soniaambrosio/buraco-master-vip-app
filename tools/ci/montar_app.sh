#!/usr/bin/env bash
# montar_app.sh — monta o projeto Flutter compilavel a partir das fontes do repo.
#
# O repositorio guarda apenas fontes (app/lib, app/assets, app/pubspec.yaml). O
# projeto Flutter de verdade — android/, ios/, .dart_tool — e gerado. Este script
# concentra essa montagem para que o build de tamanho e o build de APK executem
# EXATAMENTE os mesmos passos: comparar dois artefatos montados de jeitos
# diferentes nao mediria a colecao, mediria a diferenca de procedimento.
#
# Uso: montar_app.sh <dir-do-repo> <dir-de-saida>
#
# Depois de rodar, `cd <dir-de-saida> && flutter build appbundle --release`.

set -euo pipefail

REPO="${1:?informe o diretorio do repositorio}"
DESTINO="${2:?informe o diretorio de saida}"

echo "==> montando $DESTINO a partir de $REPO"

rm -rf "$DESTINO"
flutter create --org com.buracomastervip.poc --project-name buraco_master_vip "$DESTINO" > /dev/null

cp -R "$REPO/app/lib/." "$DESTINO/lib/"

# Assets: copia toda pasta que exista. A lista de pastas DECLARADAS vive no
# pubspec versionado; aqui so se copia o que ha.
copiar() {
  local sub="$1"
  if [ -d "$REPO/app/assets/$sub" ]; then
    mkdir -p "$DESTINO/assets/$sub"
    cp -R "$REPO/app/assets/$sub/." "$DESTINO/assets/$sub/"
  fi
}
for d in splash sons baralho perfil ranking ranking/selos hall inicio \
         configurar_mesa mesa_vip loja torneios/capas \
         torneios/premiacao/coroas torneios/premiacao/selos \
         colecoes/pioneiros_2026 ajustes/real; do
  copiar "$d"
done

# pubspec VERSIONADO no lugar do gerado. Com o lock junto, `pub get` resolve
# exatamente as mesmas versoes em qualquer maquina e em qualquer dia — que e o
# ponto de existir um lock.
if [ ! -f "$REPO/app/pubspec.yaml" ] || [ ! -f "$REPO/app/pubspec.lock" ]; then
  echo "ERRO: app/pubspec.yaml e app/pubspec.lock sao obrigatorios." >&2
  exit 1
fi
cp "$REPO/app/pubspec.yaml" "$DESTINO/pubspec.yaml"
cp "$REPO/app/pubspec.lock" "$DESTINO/pubspec.lock"

# Toda pasta declarada precisa EXISTIR, senao o build falha com uma mensagem que
# nao diz qual e.
#
# E PRECISA CHEGAR CHEIA. Criar vazia e seguir era um buraco SILENCIOSO: uma
# pasta declarada no pubspec e ausente da lista de copia acima virava diretorio
# vazio, o `flutter build` passava, e a arte simplesmente nao entrava no bundle —
# o defeito so aparecia no aparelho do jogador. Foi o que aconteceu com
# `assets/loja/`, e o que quase aconteceu com `assets/ajustes/real/`: 28 icones
# declarados, zero empacotados, e o Tema Real VIP caindo para o Padrao em
# silencio, porque o fallback dele e POR CONJUNTO — um assinante em dia veria a
# tela publica e ninguem saberia por que.
#
# Agora a divergencia entre as duas listas REPROVA a montagem, com o nome da
# pasta na mensagem.
faltando=""
while read -r dir; do
  [ -z "$dir" ] && continue
  mkdir -p "$DESTINO/$dir"
  if [ -z "$(find "$DESTINO/$dir" -type f -print -quit 2>/dev/null)" ]; then
    faltando="$faltando $dir"
  fi
done < <(sed -n 's|^\s*-\s*\(assets/.*\)/$|\1|p' "$DESTINO/pubspec.yaml")
if [ -n "$faltando" ]; then
  echo "ERRO: pasta declarada no pubspec e VAZIA apos a copia:$faltando" >&2
  echo "      acrescente-a a lista \`for d in ...\` no topo deste script." >&2
  exit 1
fi

cd "$DESTINO"
flutter pub get > /dev/null

# minSdk 23: exigencia do Firebase.
sed -i 's/minSdk = flutter.minSdkVersion/minSdk = 23/' android/app/build.gradle.kts

# Impeller desligado: bug conhecido que renderiza WEBP com alfa em branco no
# release. Mesma correcao ja aplicada no build de APK.
MANIFESTO=android/app/src/main/AndroidManifest.xml
if ! grep -q "EnableImpeller" "$MANIFESTO"; then
  sed -i 's|</application>|    <meta-data android:name="io.flutter.embedding.android.EnableImpeller" android:value="false" />\n    </application>|' "$MANIFESTO"
fi

echo "==> pronto: $DESTINO"
echo "    assets empacotados: $(find assets -type f 2>/dev/null | wc -l) arquivos"
