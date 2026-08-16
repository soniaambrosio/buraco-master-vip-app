// Transforma o scaffold do `flutter create` no projeto Android de PRODUCAO.
//
// Roda identico no GitHub Actions e na maquina de quem estiver conferindo — e
// essa e a razao de existir (ver o comentario do pubspec.yaml ao lado).
//
// Uso:
//   dart run tools/android/bin/preparar_release.dart \
//     --scaffold=app_build --application-id=io.github.soniaambrosio.buracomastervip \
//     --version-code=3 --version-name=1.0.1
//
// Cada passo CONFERE o proprio resultado e aborta com mensagem nomeada. A regra
// aqui e nunca ter fallback "esperto": um patch que erra o alvo e segue em
// frente produz um AAB que compila, parece pronto, e esta assinado com a chave
// errada ou apontando para o pacote errado. Falhar custa dez minutos; nao
// falhar custa uma publicacao permanente sob o pacote errado.
import 'dart:io';

const _corSplash = '#050201';

/// minSdk do projeto. 24 e o piso do proprio Flutter (`FlutterExtension
/// .minSdkVersion`), e nao uma escolha nossa: o engine nao suporta menos.
///
/// Este valor era 23 no workflow anterior, herdado da epoca em que o Firebase
/// pedia 23 e o Flutter ainda aceitava. Fixar 23 hoje coloca o projeto ABAIXO
/// do piso do engine — o Flutter Gradle Plugin reclama, e o que passar dali
/// roda em aparelho que o engine nao suporta.
const int minSdk = 24;

/// compileSdk e targetSdk fixos, e nao herdados de `flutter.targetSdkVersion`.
///
/// Herdar parece conveniente e e justamente o problema: o alvo do artefato
/// passaria a mudar sozinho a cada bump do canal stable do Flutter, sem
/// ninguem decidir. Como a Play exige um alvo minimo que sobe todo ano e
/// recusa upload abaixo dele, o numero precisa ser uma decisao registrada.
const int targetSdk = 36;
const int compileSdk = 36;

void main(List<String> argumentos) {
  final args = _Argumentos(argumentos);
  final scaffold = Directory(args.obrigatorio('scaffold'));
  final appId = args.obrigatorio('application-id');
  final versionCode = args.obrigatorio('version-code');
  final versionName = args.obrigatorio('version-name');
  final icone = Directory(args.opcional('icone') ?? 'android/launcher-icon/res');

  if (!scaffold.existsSync()) {
    _abortar('scaffold nao encontrado: ${scaffold.path}');
  }

  _patchGradle(scaffold, appId, versionCode, versionName);
  _patchNamespace(scaffold, appId);
  _instalarIcone(scaffold, icone);
  _patchManifesto(scaffold);
  _telaDeAberturaEscura(scaffold);

  stdout.writeln('\nPreparacao concluida. applicationId e namespace = $appId');
}

// ---------------------------------------------------------------------------
// build.gradle.kts
// ---------------------------------------------------------------------------

void _patchGradle(
  Directory scaffold,
  String appId,
  String versionCode,
  String versionName,
) {
  _titulo('build.gradle.kts');
  final arquivo = File('${scaffold.path}/android/app/build.gradle.kts');
  var s = _lerNormalizado(arquivo);

  if (!s.contains('import java.util.Properties')) {
    s = 'import java.util.Properties\nimport java.io.FileInputStream\n$s';
  }

  // Carrega key.properties antes do bloco `android { }`. O arquivo e escrito
  // pelo workflow a partir de Secrets e nunca e versionado.
  if (!s.contains('val keystoreProperties')) {
    const loader = 'val keystoreProperties = Properties()\n'
        'val keystorePropertiesFile = rootProject.file("key.properties")\n'
        'if (keystorePropertiesFile.exists()) {\n'
        '    keystoreProperties.load(FileInputStream(keystorePropertiesFile))\n'
        '}\n\n';
    s = _substituirUmaVez(
      s,
      RegExp(r'\nandroid\s*\{'),
      '\n${loader}android {',
      'nao localizei o bloco `android {` para inserir a leitura de key.properties',
    );
  }

  if (!s.contains('create("upload")')) {
    const assinatura = '\n    signingConfigs {\n'
        '        create("upload") {\n'
        '            keyAlias = keystoreProperties["keyAlias"] as String\n'
        '            keyPassword = keystoreProperties["keyPassword"] as String\n'
        '            storeFile = file(keystoreProperties["storeFile"] as String)\n'
        '            storePassword = keystoreProperties["storePassword"] as String\n'
        '        }\n'
        '    }\n';
    s = _substituirUmaVez(
      s,
      RegExp(r'android\s*\{'),
      'android {$assinatura',
      'nao localizei o bloco `android {` para inserir signingConfigs',
    );
  }

  // Release assinado com a chave de upload. Sem minify: o codigo do
  // BillingClient precisa continuar legivel para a analise da Play Console.
  const buildTypes = '    buildTypes {\n'
      '        getByName("release") {\n'
      '            signingConfig = signingConfigs.getByName("upload")\n'
      '            isMinifyEnabled = false\n'
      '            isShrinkResources = false\n'
      '            isDebuggable = false\n'
      '        }\n'
      '    }\n';
  s = _substituirUmaVez(
    s,
    RegExp(r'buildTypes\s*\{.*?\n    \}\n', dotAll: true),
    buildTypes,
    'nao localizei o bloco buildTypes do scaffold — o template do Flutter '
        'mudou de formato. Ajuste este patch ANTES de gerar qualquer AAB: sem '
        'ele o release sai assinado com a chave de debug.',
  );

  s = _substituirUmaVez(
    s,
    RegExp(r'applicationId\s*=\s*"[^"]*"'),
    'applicationId = "$appId"',
    'nao encontrei applicationId no build.gradle.kts',
  );
  s = _substituirUmaVez(
    s,
    RegExp(r'namespace\s*=\s*"[^"]*"'),
    'namespace = "$appId"',
    'nao encontrei namespace no build.gradle.kts',
  );
  s = _substituirUmaVez(
    s,
    RegExp(r'compileSdk\s*=\s*[A-Za-z0-9_.]+'),
    'compileSdk = $compileSdk',
    'nao encontrei compileSdk no build.gradle.kts',
  );
  s = _substituirUmaVez(
    s,
    RegExp(r'minSdk\s*=\s*[A-Za-z0-9_.]+'),
    'minSdk = $minSdk',
    'nao encontrei minSdk no build.gradle.kts',
  );
  s = _substituirUmaVez(
    s,
    RegExp(r'targetSdk\s*=\s*[A-Za-z0-9_.]+'),
    'targetSdk = $targetSdk',
    'nao encontrei targetSdk no build.gradle.kts',
  );
  s = _substituirUmaVez(
    s,
    RegExp(r'versionCode\s*=\s*[A-Za-z0-9_.]+'),
    'versionCode = $versionCode',
    'nao encontrei versionCode no build.gradle.kts',
  );
  s = _substituirUmaVez(
    s,
    RegExp(r'versionName\s*=\s*[A-Za-z0-9_."]+'),
    'versionName = "$versionName"',
    'nao encontrei versionName no build.gradle.kts',
  );

  arquivo.writeAsStringSync(s);

  _conferir(s, {
    'applicationId = "$appId"': true,
    'namespace = "$appId"': true,
    'compileSdk = $compileSdk': true,
    'minSdk = $minSdk': true,
    'targetSdk = $targetSdk': true,
    'versionCode = $versionCode': true,
    'versionName = "$versionName"': true,
    'create("upload")': true,
    'signingConfig = signingConfigs.getByName("upload")': true,
    'isDebuggable = false': true,
    'signingConfigs.getByName("debug")': false,
    'com.buracomastervip.poc': false,
    'flutter.targetSdkVersion': false,
    'flutter.minSdkVersion': false,
  });
}

// ---------------------------------------------------------------------------
// namespace: move a MainActivity para o pacote oficial
// ---------------------------------------------------------------------------

/// O `namespace` do Gradle e o pacote Java/Kotlin onde `R` e `BuildConfig` sao
/// gerados, e e a base a partir da qual o manifesto resolve nomes relativos —
/// `android:name=".MainActivity"` vira `<namespace>.MainActivity`.
///
/// Trocar o namespace no Gradle sem mover a classe produz um app que compila e
/// morre com ClassNotFoundException ao abrir. Por isso os dois andam juntos
/// aqui, num passo so, com conferencia no fim.
///
/// Poderia-se deixar o namespace no pacote do scaffold (`com.buracomastervip
/// .poc...`) — o Android aceita namespace != applicationId. Optou-se por
/// alinhar os dois porque o nome do pacote do PoC sobreviveria dentro do
/// artefato final como nome de classe da Activity, e a OS pede que o pacote de
/// PoC nao seja identidade efetiva de nada na build de producao.
void _patchNamespace(Directory scaffold, String appId) {
  _titulo('namespace e MainActivity');
  final base = Directory('${scaffold.path}/android/app/src/main/kotlin');
  if (!base.existsSync()) _abortar('nao encontrei ${base.path}');

  final fontes = base
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('MainActivity.kt'))
      .toList();
  if (fontes.length != 1) {
    _abortar(
      'esperava exatamente 1 MainActivity.kt no scaffold, achei ${fontes.length}',
    );
  }

  final origem = fontes.single;
  final conteudo = _lerNormalizado(origem);
  final pacoteAntigo =
      RegExp(r'^package\s+([\w.]+)', multiLine: true).firstMatch(conteudo);
  if (pacoteAntigo == null) {
    _abortar('nao encontrei a declaracao `package` em ${origem.path}');
  }
  stdout.writeln('  pacote do scaffold : ${pacoteAntigo!.group(1)}');

  final destino = File(
    '${base.path}/${appId.split('.').join('/')}/MainActivity.kt',
  );
  destino.parent.createSync(recursive: true);
  destino.writeAsStringSync(
    conteudo.replaceFirst(pacoteAntigo.group(0)!, 'package $appId'),
  );

  // Remove a arvore antiga inteira, e nao so o arquivo: uma pasta
  // `com/buracomastervip/poc/` vazia sobrevivendo no scaffold e exatamente o
  // tipo de residuo que faz uma busca por "poc" acusar algo depois.
  final raizAntiga =
      Directory('${base.path}/${pacoteAntigo.group(1)!.split('.').first}');
  if (raizAntiga.existsSync() &&
      !destino.path.startsWith('${raizAntiga.path}/') &&
      raizAntiga.path != destino.parent.path) {
    raizAntiga.deleteSync(recursive: true);
  }

  final restantes = base
      .listSync(recursive: true)
      .whereType<File>()
      .map((f) => f.path.replaceAll('\\', '/'))
      .toList();
  if (restantes.length != 1 || !restantes.single.endsWith('MainActivity.kt')) {
    _abortar('arvore kotlin inesperada apos a migracao: $restantes');
  }
  stdout.writeln('  pacote de producao : $appId');
  stdout.writeln('  arquivo            : ${restantes.single}');
}

// ---------------------------------------------------------------------------
// icone oficial
// ---------------------------------------------------------------------------

/// Instala o launcher icon oficial e APAGA os mipmaps do scaffold.
///
/// Apagar antes de copiar nao e zelo: as densidades geradas e as do scaffold
/// tem os mesmos nomes de arquivo, entao copiar por cima resolveria o
/// `ic_launcher.png` — mas qualquer densidade que a arte oficial nao cubra
/// ficaria com o icone padrao do Flutter, e o Android escolhe por densidade do
/// aparelho. O resultado seria o icone certo na maioria dos telefones e o
/// icone do Flutter em alguns.
void _instalarIcone(Directory scaffold, Directory icone) {
  _titulo('launcher icon oficial');
  if (!icone.existsSync()) {
    _abortar(
      'recursos de icone nao encontrados em ${icone.path}. '
      'Gere com: dart run tools/icone/bin/gerar.dart',
    );
  }

  final res = Directory('${scaffold.path}/android/app/src/main/res');
  var apagados = 0;
  for (final dir in res.listSync().whereType<Directory>()) {
    if (!dir.path.replaceAll('\\', '/').split('/').last.startsWith('mipmap-')) {
      continue;
    }
    for (final f in dir.listSync().whereType<File>()) {
      f.deleteSync();
      apagados++;
    }
  }
  stdout.writeln('  mipmaps do scaffold apagados: $apagados');

  var copiados = 0;
  for (final f in icone.listSync(recursive: true).whereType<File>()) {
    final relativo = f.path
        .replaceAll('\\', '/')
        .substring(icone.path.replaceAll('\\', '/').length + 1);
    final destino = File('${res.path}/$relativo');
    destino.parent.createSync(recursive: true);
    destino.writeAsBytesSync(f.readAsBytesSync());
    copiados++;
  }
  stdout.writeln('  recursos oficiais copiados  : $copiados');

  for (final exigido in [
    'mipmap-mdpi/ic_launcher.png',
    'mipmap-xxxhdpi/ic_launcher.png',
    'mipmap-anydpi-v26/ic_launcher.xml',
    'mipmap-xxxhdpi/ic_launcher_foreground.png',
    'values/ic_launcher_background.xml',
  ]) {
    if (!File('${res.path}/$exigido').existsSync()) {
      _abortar('faltou o recurso de icone $exigido');
    }
  }
  stdout.writeln('  adaptive icon + 5 densidades confirmados');
}

// ---------------------------------------------------------------------------
// AndroidManifest.xml de origem
// ---------------------------------------------------------------------------

void _patchManifesto(Directory scaffold) {
  _titulo('AndroidManifest.xml');
  final arquivo =
      File('${scaffold.path}/android/app/src/main/AndroidManifest.xml');
  var s = _lerNormalizado(arquivo);

  // A permissao de Billing ja entra sozinha pelo merge do manifesto do
  // in_app_purchase_android. Declarar aqui deixa a intencao registrada no
  // fonte e sobrevive a uma troca de plugin.
  if (!s.contains('com.android.vending.BILLING')) {
    final app = RegExp(r'^([ \t]*)<application\b', multiLine: true).firstMatch(s);
    if (app == null) _abortar('nao encontrei <application> no manifesto');
    s = s.replaceRange(
      app!.start,
      app.start,
      '${app.group(1)}<uses-permission android:name="com.android.vending.BILLING" />\n',
    );
  }

  s = _substituirUmaVez(
    s,
    RegExp(r'android:label="[^"]*"'),
    'android:label="Buraco Master VIP"',
    'nao encontrei android:label no manifesto',
  );

  // Impeller desligado: o app carrega webp com transparencia, que o Skia
  // renderiza corretamente e o Impeller, nesta versao do engine, nao.
  if (!s.contains('EnableImpeller')) {
    s = s.replaceFirst(
      '</application>',
      '        <meta-data android:name="io.flutter.embedding.android.EnableImpeller" '
          'android:value="false" />\n    </application>',
    );
  }

  arquivo.writeAsStringSync(s);
  _conferir(s, {
    'com.android.vending.BILLING': true,
    'android:label="Buraco Master VIP"': true,
    'EnableImpeller': true,
    'android:icon="@mipmap/ic_launcher"': true,
  });
}

/// Fundo escuro na tela nativa de abertura, para nao piscar branco antes do
/// splash do app.
void _telaDeAberturaEscura(Directory scaffold) {
  _titulo('tela nativa de abertura');
  final res = Directory('${scaffold.path}/android/app/src/main/res');
  for (final rel in ['values/colors.xml', 'values-night/colors.xml']) {
    final p = File('${res.path}/$rel');
    p.parent.createSync(recursive: true);
    if (p.existsSync()) {
      final s = _lerNormalizado(p);
      if (!s.contains('splash_background')) {
        p.writeAsStringSync(s.replaceFirst(
          '</resources>',
          '    <color name="splash_background">$_corSplash</color>\n</resources>',
        ));
      }
    } else {
      p.writeAsStringSync(
        '<?xml version="1.0" encoding="utf-8"?>\n<resources>\n'
        '    <color name="splash_background">$_corSplash</color>\n</resources>\n',
      );
    }
  }
  for (final rel in [
    'drawable/launch_background.xml',
    'drawable-v21/launch_background.xml',
  ]) {
    final p = File('${res.path}/$rel');
    p.parent.createSync(recursive: true);
    p.writeAsStringSync(
      '<?xml version="1.0" encoding="utf-8"?>\n'
      '<layer-list xmlns:android="http://schemas.android.com/apk/res/android">\n'
      '    <item android:drawable="@color/splash_background" />\n'
      '</layer-list>\n',
    );
  }
  stdout.writeln('  fundo $_corSplash aplicado');
}

// ---------------------------------------------------------------------------
// apoio
// ---------------------------------------------------------------------------

String _lerNormalizado(File f) =>
    f.readAsStringSync().replaceAll('\r\n', '\n');

String _substituirUmaVez(
  String fonte,
  RegExp alvo,
  String novo,
  String mensagemDeErro,
) {
  if (!alvo.hasMatch(fonte)) _abortar(mensagemDeErro);
  return fonte.replaceFirst(alvo, novo);
}

void _conferir(String conteudo, Map<String, bool> esperado) {
  var falhou = false;
  esperado.forEach((trecho, deveConter) {
    final tem = conteudo.contains(trecho);
    final ok = tem == deveConter;
    if (!ok) falhou = true;
    stdout.writeln(
      '  ${ok ? 'OK   ' : 'FALHA'} ${deveConter ? 'contem' : 'nao contem'}: $trecho',
    );
  });
  if (falhou) _abortar('conferencia do patch reprovada');
}

void _titulo(String t) => stdout.writeln('\n--- $t ---');

Never _abortar(String mensagem) {
  stderr.writeln('ERRO: $mensagem');
  exit(1);
}

class _Argumentos {
  _Argumentos(List<String> brutos) {
    for (final a in brutos) {
      final i = a.indexOf('=');
      if (a.startsWith('--') && i > 2) {
        _mapa[a.substring(2, i)] = a.substring(i + 1);
      }
    }
  }

  final Map<String, String> _mapa = {};

  String obrigatorio(String nome) {
    final v = _mapa[nome];
    if (v == null || v.isEmpty) _abortar('faltou o argumento --$nome=...');
    return v!;
  }

  String? opcional(String nome) => _mapa[nome];
}
