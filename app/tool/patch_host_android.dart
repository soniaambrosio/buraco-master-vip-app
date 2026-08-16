// patch_host_android.dart — aplica o remendo no projeto Android efêmero.
//
// Toda a decisão mora em `app/lib/observability/host_android_gradle.dart`, que
// é puro e testado. Este arquivo só faz I/O: lê, chama, escreve, confere.
//
// Uso:
//   dart run app/tool/patch_host_android.dart \
//     --projeto=app_build \
//     --applicationId=io.github.soniaambrosio.buracomastervip \
//     --versionCode=141 --versionName=1.0.0
//
// Exit: 0 PASS · 1 remendo reprovado · 2 erro de uso/ambiente.

import 'dart:io';

import '../lib/observability/host_android_gradle.dart';

void main(List<String> args) {
  String? valor(String nome) {
    for (final a in args) {
      if (a.startsWith('--$nome=')) return a.substring(nome.length + 3);
    }
    return null;
  }

  final projeto = valor('projeto') ?? 'app_build';
  final applicationId = valor('applicationId');
  final versionCode = int.tryParse(valor('versionCode') ?? '');
  final versionName = valor('versionName');

  if (applicationId == null || versionCode == null || versionName == null) {
    stderr.writeln('uso: --projeto=<dir> --applicationId=<id> '
        '--versionCode=<n> --versionName=<x.y.z>');
    exit(2);
  }

  final config = ConfiguracaoHostAndroid(
    applicationId: applicationId,
    versionCode: versionCode,
    versionName: versionName,
  );

  final raiz = Directory(projeto);
  if (!raiz.existsSync()) {
    stderr.writeln('ERRO: projeto Android não encontrado: $projeto');
    stderr.writeln('Rode o `flutter create` antes deste passo.');
    exit(2);
  }

  stdout.writeln('===== HOST ANDROID =====');
  stdout.writeln('projeto:        $projeto');
  stdout.writeln('applicationId:  ${config.applicationId}');
  stdout.writeln('namespace:      ${config.namespace}');
  stdout.writeln('SDKs:           compile ${config.compileSdk} · '
      'target ${config.targetSdk} · min ${config.minSdk}');
  stdout.writeln('versão:         ${config.versionName} (${config.versionCode})');
  stdout.writeln('plugins:        google-services ${config.versaoPluginGoogleServices} · '
      'crashlytics ${config.versaoPluginCrashlytics}');
  stdout.writeln('------------------------');

  try {
    // --- settings.gradle.kts ---------------------------------------------
    final settings = File('$projeto/android/settings.gradle.kts');
    _exigir(settings, 'android/settings.gradle.kts');
    final settingsNovo =
        patchSettingsGradle(settings.readAsStringSync(), config);
    settings.writeAsStringSync(settingsNovo);

    // --- app/build.gradle.kts --------------------------------------------
    final appGradle = File('$projeto/android/app/build.gradle.kts');
    _exigir(appGradle, 'android/app/build.gradle.kts');
    final appNovo = patchAppGradle(appGradle.readAsStringSync(), config);
    appGradle.writeAsStringSync(appNovo);

    // --- MainActivity ------------------------------------------------------
    _moverMainActivity(projeto, config);

    // --- conferência do resultado ----------------------------------------
    // Não basta o remendo "ter rodado": o que vale é o Gradle que sai dele.
    final problemas = <String>[
      ...conferirSettingsGradle(settingsNovo).map((p) => 'settings.gradle.kts: $p'),
      ...conferirAppGradle(appNovo, config).map((p) => 'app/build.gradle.kts: $p'),
    ];
    if (problemas.isNotEmpty) {
      stdout.writeln('FAIL — o Gradle resultante está errado:');
      for (final p in problemas) {
        stdout.writeln('  · $p');
        stdout.writeln('::error title=host Android::$p');
      }
      exit(1);
    }

    stdout.writeln('PASS — host Android remendado e conferido');
    exit(0);
  } on PatchNaoCasou catch (e) {
    stdout.writeln('FAIL — $e');
    stdout.writeln('::error title=host Android::${e.arquivo}: não achei ${e.procurado}');
    exit(1);
  }
}

void _exigir(File f, String rotulo) {
  if (!f.existsSync()) {
    stderr.writeln('ERRO: $rotulo não existe no projeto gerado.');
    stderr.writeln('O `flutter create` mudou de layout — o remendo precisa ser revisto.');
    exit(2);
  }
}

/// Move o `MainActivity.kt` para o pacote do novo namespace.
///
/// O Android carrega `<namespace>.MainActivity` por nome. Trocar o namespace e
/// deixar a classe no pacote antigo compila normalmente e quebra no arranque
/// com `ClassNotFoundException` — erro caro, porque só aparece no aparelho.
void _moverMainActivity(String projeto, ConfiguracaoHostAndroid config) {
  final base = Directory('$projeto/android/app/src/main/kotlin');
  if (!base.existsSync()) {
    stderr.writeln('ERRO: $projeto/android/app/src/main/kotlin não existe.');
    exit(2);
  }

  final atuais = base
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('MainActivity.kt'))
      .toList();
  if (atuais.isEmpty) {
    stderr.writeln('ERRO: MainActivity.kt não encontrado sob ${base.path}.');
    exit(2);
  }

  final destino = File('$projeto/${caminhoMainActivity(config.namespace)}');
  final origem = atuais.first;
  final conteudo = patchMainActivity(origem.readAsStringSync(), config);

  destino.parent.createSync(recursive: true);
  destino.writeAsStringSync(conteudo);

  // Remove a árvore antiga, senão sobram duas MainActivity e o Kotlin compila
  // as duas — a errada inclusive.
  if (_normalizar(origem.path) != _normalizar(destino.path)) {
    for (final f in atuais) {
      if (_normalizar(f.path) != _normalizar(destino.path)) f.deleteSync();
    }
    _podarVazios(base);
    stdout.writeln('MainActivity movida para ${config.namespace}');
  } else {
    stdout.writeln('MainActivity já está em ${config.namespace}');
  }
}

/// Apaga diretórios que ficaram sem nenhum arquivo depois da mudança.
void _podarVazios(Directory raiz) {
  bool podouAlgum = true;
  while (podouAlgum) {
    podouAlgum = false;
    for (final d in raiz.listSync(recursive: true).whereType<Directory>()) {
      if (!d.existsSync()) continue;
      if (d.listSync().isEmpty) {
        d.deleteSync();
        podouAlgum = true;
      }
    }
  }
}

String _normalizar(String p) => p.replaceAll('\\', '/').toLowerCase();
