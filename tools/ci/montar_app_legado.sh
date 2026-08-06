#!/usr/bin/env bash
# montar_app_legado.sh — monta um commit ANTERIOR ao pubspec versionado.
#
# Existe por um motivo so: para a comparacao de tamanho ser honesta, o lado
# "antes" precisa ser montado do jeito que ERA naquele commit. Montar os dois
# lados com o procedimento novo mediria a mudanca de pipeline junto com a
# colecao, e o delta deixaria de significar o que promete significar.
#
# Reproduz o que o build.yml fazia antes: `flutter create`, overlay das fontes,
# copia de assets, `flutter pub add` e injecao do bloco `assets` no pubspec.
#
# Uso: montar_app_legado.sh <dir-do-repo-antigo> <dir-de-saida>

set -euo pipefail

REPO="${1:?informe o diretorio do repositorio}"
DESTINO="${2:?informe o diretorio de saida}"

PASTAS="splash sons baralho perfil ranking ranking/selos hall inicio
        configurar_mesa mesa_vip loja torneios/capas
        torneios/premiacao/coroas torneios/premiacao/selos"

echo "==> montando (procedimento legado) $DESTINO a partir de $REPO"

rm -rf "$DESTINO"
flutter create --org com.buracomastervip.poc --project-name buraco_master_vip "$DESTINO" > /dev/null
cp -R "$REPO/app/lib/." "$DESTINO/lib/"

cd "$DESTINO"
DECLARAR=""
for d in $PASTAS; do
  if [ -d "$REPO/app/assets/$d" ]; then
    mkdir -p "assets/$d"
    cp -R "$REPO/app/assets/$d/." "assets/$d/"
    DECLARAR="$DECLARAR $d"
  fi
done

flutter pub add firebase_core firebase_auth "google_sign_in:^6.2.1" \
  audioplayers web_socket_channel shared_preferences > /dev/null
printf '\ndependency_overrides:\n  jni: 1.0.0\n' >> pubspec.yaml
flutter pub get > /dev/null

sed -i 's/minSdk = flutter.minSdkVersion/minSdk = 23/' android/app/build.gradle.kts

MANIFESTO=android/app/src/main/AndroidManifest.xml
if ! grep -q "EnableImpeller" "$MANIFESTO"; then
  sed -i 's|</application>|    <meta-data android:name="io.flutter.embedding.android.EnableImpeller" android:value="false" />\n    </application>|' "$MANIFESTO"
fi

# Injeta o bloco `assets` logo apos a linha `flutter:` de nivel zero — o mesmo
# ponto que o script Python do workflow antigo usava.
{
  echo "  assets:"
  for d in $DECLARAR; do echo "    - assets/$d/"; done
} > /tmp/bloco_assets.txt

awk '
  /^flutter:$/ && !feito { print; while ((getline l < "/tmp/bloco_assets.txt") > 0) print l; feito=1; next }
  { print }
' pubspec.yaml > pubspec.novo && mv pubspec.novo pubspec.yaml

sed -n '/^flutter:/,$p' pubspec.yaml
flutter pub get > /dev/null

echo "==> pronto (legado): $DESTINO"
echo "    assets empacotados: $(find assets -type f 2>/dev/null | wc -l) arquivos"
