// host_android_gradle.dart — transforma o scaffold do `flutter create` no host
// Android de homologação do Buraco Master VIP.
//
// Este repositório não versiona a pasta `android/`: o CI cria um projeto novo a
// cada run e o remenda. Isso mantém o repositório enxuto, mas cria um risco
// específico — quando o Flutter muda o scaffold, o remendo deixa de casar. Se
// ele deixar de casar em SILÊNCIO, sai um APK sem Crashlytics, sem plugin, ou
// com o applicationId de teste. Compila, instala, roda, e não reporta nada.
//
// Por isso todo casamento aqui é obrigatório: quando a âncora não aparece, a
// função LANÇA [PatchNaoCasou] com o nome do arquivo, o que se procurava e o
// que fazer. Não existe caminho silencioso.
//
// As funções são puras (texto entra, texto sai). É o que permite testar o
// RESULTADO — o Gradle que vai ser compilado — e não apenas o script.
//
// Dart puro, sem `package:flutter`: roda em `dart run` dentro do CI.

/// O remendo não encontrou o que esperava. Quase sempre significa que o
/// scaffold do Flutter mudou de forma.
class PatchNaoCasou implements Exception {
  PatchNaoCasou(this.arquivo, this.procurado, this.sugestao);

  final String arquivo;
  final String procurado;
  final String sugestao;

  @override
  String toString() => 'PatchNaoCasou: em `$arquivo` não achei $procurado.\n'
      'O scaffold do `flutter create` provavelmente mudou.\n'
      '$sugestao';
}

/// Tudo que o host Android precisa saber para virar o app oficial.
class ConfiguracaoHostAndroid {
  const ConfiguracaoHostAndroid({
    required this.applicationId,
    required this.versionCode,
    required this.versionName,
    String? namespace,
    this.compileSdk = 36,
    this.targetSdk = 36,
    this.minSdk = 24,
    this.versaoPluginGoogleServices = '4.4.4',
    this.versaoPluginCrashlytics = '3.0.7',
  }) : namespace = namespace ?? applicationId;

  final String applicationId;

  /// Pacote das classes Kotlin. Tem de ser o mesmo do `MainActivity`, senão o
  /// app compila e quebra no arranque com `ClassNotFoundException`.
  final String namespace;

  final int versionCode;
  final String versionName;

  /// Fixos, e não `flutter.targetSdkVersion`: o alvo da release não pode mudar
  /// sozinho quando alguém atualizar o Flutter.
  final int compileSdk;
  final int targetSdk;

  /// 24 é o piso do próprio engine do Flutter. Abaixo disso o build passa e o
  /// app quebra no aparelho antigo.
  final int minSdk;

  final String versaoPluginGoogleServices;
  final String versaoPluginCrashlytics;

  static const idPluginGoogleServices = 'com.google.gms.google-services';
  static const idPluginCrashlytics = 'com.google.firebase.crashlytics';
}

/// Declara os plugins do Firebase no `android/settings.gradle.kts`.
///
/// Vão com `apply false`: aqui só se declara a versão; aplicar é no módulo.
String patchSettingsGradle(String original, ConfiguracaoHostAndroid c) {
  var s = original;

  const ancora = 'id("org.jetbrains.kotlin.android")';
  if (!s.contains(ancora)) {
    throw PatchNaoCasou(
      'android/settings.gradle.kts',
      'a declaração `$ancora` dentro do bloco `plugins`',
      'Confira o bloco `plugins` do settings.gradle.kts gerado e ajuste a '
          'âncora em host_android_gradle.dart.',
    );
  }

  final novas = <String>[
    if (!s.contains(ConfiguracaoHostAndroid.idPluginGoogleServices))
      '    id("${ConfiguracaoHostAndroid.idPluginGoogleServices}") version "${c.versaoPluginGoogleServices}" apply false',
    if (!s.contains(ConfiguracaoHostAndroid.idPluginCrashlytics))
      '    id("${ConfiguracaoHostAndroid.idPluginCrashlytics}") version "${c.versaoPluginCrashlytics}" apply false',
  ];
  if (novas.isEmpty) return s; // já remendado — idempotente

  // Insere depois da LINHA INTEIRA da âncora, preservando o que vier nela.
  final linhas = s.split('\n');
  final i = linhas.indexWhere((l) => l.contains(ancora));
  linhas.insertAll(i + 1, novas);
  s = linhas.join('\n');
  return s;
}

/// Aplica os plugins e fixa identidade e SDKs no `android/app/build.gradle.kts`.
String patchAppGradle(String original, ConfiguracaoHostAndroid c) {
  var s = original;

  // --- 1. aplicar os plugins, DEPOIS do plugin do Flutter ---------------
  const ancoraFlutter = 'id("dev.flutter.flutter-gradle-plugin")';
  if (!s.contains(ancoraFlutter)) {
    throw PatchNaoCasou(
      'android/app/build.gradle.kts',
      'a declaração `$ancoraFlutter` dentro do bloco `plugins`',
      'O plugin do Firebase precisa ser aplicado DEPOIS do plugin do Flutter.',
    );
  }
  final aplicar = <String>[
    if (!s.contains('id("${ConfiguracaoHostAndroid.idPluginGoogleServices}")'))
      '    id("${ConfiguracaoHostAndroid.idPluginGoogleServices}")',
    // Crashlytics DEPOIS de google-services: ele lê a configuração que o outro
    // registra. Invertido, o build falha com mensagem que não diz isso.
    if (!s.contains('id("${ConfiguracaoHostAndroid.idPluginCrashlytics}")'))
      '    id("${ConfiguracaoHostAndroid.idPluginCrashlytics}")',
  ];
  if (aplicar.isNotEmpty) {
    final linhas = s.split('\n');
    final i = linhas.indexWhere((l) => l.contains(ancoraFlutter));
    linhas.insertAll(i + 1, aplicar);
    s = linhas.join('\n');
  }

  // --- 2. identidade ----------------------------------------------------
  s = _trocarObrigatorio(
    s,
    RegExp(r'namespace\s*=\s*"[^"]*"'),
    'namespace = "${c.namespace}"',
    'namespace',
  );
  s = _trocarObrigatorio(
    s,
    RegExp(r'applicationId\s*=\s*"[^"]*"'),
    'applicationId = "${c.applicationId}"',
    'applicationId',
  );

  // --- 3. SDKs e versão -------------------------------------------------
  // Cada regex aceita tanto a forma do scaffold (`flutter.xxx`) quanto um
  // literal já remendado. É o que torna o remendo idempotente sem deixar de
  // reprovar quando a propriedade some de vez.
  s = _trocarObrigatorio(
    s,
    RegExp(r'compileSdk\s*=\s*(?:flutter\.compileSdkVersion|\d+)'),
    'compileSdk = ${c.compileSdk}',
    'compileSdk',
  );
  s = _trocarObrigatorio(
    s,
    RegExp(r'minSdk\s*=\s*(?:flutter\.minSdkVersion|\d+)'),
    'minSdk = ${c.minSdk}',
    'minSdk',
  );
  s = _trocarObrigatorio(
    s,
    RegExp(r'targetSdk\s*=\s*(?:flutter\.targetSdkVersion|\d+)'),
    'targetSdk = ${c.targetSdk}',
    'targetSdk',
  );
  s = _trocarObrigatorio(
    s,
    RegExp(r'versionCode\s*=\s*(?:flutter\.versionCode|\d+)'),
    'versionCode = ${c.versionCode}',
    'versionCode',
  );
  s = _trocarObrigatorio(
    s,
    RegExp(r'versionName\s*=\s*(?:flutter\.versionName|"[^"]*")'),
    'versionName = "${c.versionName}"',
    'versionName',
  );

  return s;
}

/// Caminho do `MainActivity.kt` para um pacote.
///
/// Trocar o `namespace` sem mover a classe junto compila e quebra no arranque —
/// o Android procura `<namespace>.MainActivity` e não acha.
String caminhoMainActivity(String pacote) =>
    'android/app/src/main/kotlin/${pacote.replaceAll('.', '/')}/MainActivity.kt';

/// Reescreve a linha `package` do `MainActivity.kt`.
String patchMainActivity(String original, ConfiguracaoHostAndroid c) {
  final re = RegExp(r'^package\s+[A-Za-z0-9_.]+', multiLine: true);
  if (!re.hasMatch(original)) {
    throw PatchNaoCasou(
      'MainActivity.kt',
      'a declaração `package`',
      'Sem ela não dá para mover a classe junto com o namespace.',
    );
  }
  return original.replaceFirst(re, 'package ${c.namespace}');
}

/// Confere o Gradle JÁ REMENDADO. É a trava contra o remendo que "passou" mas
/// deixou o arquivo errado — e contra aplicar o mesmo plugin duas vezes, que o
/// Gradle rejeita com erro obscuro.
List<String> conferirAppGradle(String remendado, ConfiguracaoHostAndroid c) {
  final problemas = <String>[];

  int contar(String agulha) => agulha.allMatches(remendado).length;

  for (final id in const [
    ConfiguracaoHostAndroid.idPluginGoogleServices,
    ConfiguracaoHostAndroid.idPluginCrashlytics,
  ]) {
    final n = contar('id("$id")');
    if (n == 0) problemas.add('plugin `$id` não foi aplicado');
    if (n > 1) problemas.add('plugin `$id` aplicado $n vezes');
  }

  if (!remendado.contains('namespace = "${c.namespace}"')) {
    problemas.add('namespace não é `${c.namespace}`');
  }
  if (!remendado.contains('applicationId = "${c.applicationId}"')) {
    problemas.add('applicationId não é `${c.applicationId}`');
  }
  if (!remendado.contains('targetSdk = ${c.targetSdk}')) {
    problemas.add('targetSdk não é ${c.targetSdk}');
  }
  if (!remendado.contains('minSdk = ${c.minSdk}')) {
    problemas.add('minSdk não é ${c.minSdk}');
  }
  if (!remendado.contains('versionCode = ${c.versionCode}')) {
    problemas.add('versionCode não é ${c.versionCode}');
  }
  if (remendado.contains('flutter.targetSdkVersion') ||
      remendado.contains('flutter.minSdkVersion') ||
      remendado.contains('flutter.compileSdkVersion')) {
    problemas.add('sobrou referência a `flutter.*SdkVersion`: o alvo da '
        'release mudaria sozinho na próxima atualização do Flutter');
  }
  return problemas;
}

/// Confere o `settings.gradle.kts` já remendado.
List<String> conferirSettingsGradle(String remendado) {
  final problemas = <String>[];
  for (final id in const [
    ConfiguracaoHostAndroid.idPluginGoogleServices,
    ConfiguracaoHostAndroid.idPluginCrashlytics,
  ]) {
    final n = 'id("$id")'.allMatches(remendado).length;
    if (n == 0) problemas.add('plugin `$id` não foi declarado');
    if (n > 1) problemas.add('plugin `$id` declarado $n vezes');
  }
  return problemas;
}

String _trocarObrigatorio(
  String s,
  RegExp re,
  String substituto,
  String nome,
) {
  if (!re.hasMatch(s)) {
    throw PatchNaoCasou(
      'android/app/build.gradle.kts',
      'a propriedade `$nome`',
      'O scaffold deixou de declarar `$nome` no formato esperado.',
    );
  }
  return s.replaceAll(re, substituto);
}
