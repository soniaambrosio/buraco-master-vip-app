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
         colecoes/pioneiros_2026; do
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
# nao diz qual e. Criar vazia aqui transforma isso num aviso do proprio Flutter.
while read -r dir; do
  [ -n "$dir" ] && mkdir -p "$DESTINO/$dir"
done < <(sed -n 's|^\s*-\s*\(assets/.*\)/$|\1|p' "$DESTINO/pubspec.yaml")

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
