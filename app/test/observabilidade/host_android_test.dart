// Conferência do host Android e da configuração Firebase.
//
// O que estes testes protegem é específico: este repositório NÃO versiona a
// pasta `android/`. Ela é criada por `flutter create` a cada run do CI e
// remendada. Um remendo que deixa de casar em silêncio produz um APK que
// compila, instala, roda — e não reporta nada. É a pior classe de defeito que
// existe numa camada de observabilidade, porque ela some justamente quando
// alguém precisa dela.
//
// Por isso os testes afirmam sobre o GRADLE RESULTANTE, e não sobre o script.

import 'package:buraco_master_vip/observability/config_firebase.dart';
import 'package:buraco_master_vip/observability/host_android_gradle.dart';
import 'package:flutter_test/flutter_test.dart';

/// Cópia fiel do `android/settings.gradle.kts` gerado pelo `flutter create`.
const String settingsScaffold = '''
pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("\$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.11.1" apply false
    id("org.jetbrains.kotlin.android") version "2.2.20" apply false
}

include(":app")
''';

/// Cópia fiel do `android/app/build.gradle.kts` gerado pelo `flutter create`.
const String appScaffold = '''
plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.buracomastervip.poc.buraco_master_vip"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.buracomastervip.poc.buraco_master_vip"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }
}

flutter {
    source = "../.."
}
''';

const config = ConfiguracaoHostAndroid(
  applicationId: 'io.github.soniaambrosio.buracomastervip',
  versionCode: 141,
  versionName: '1.0.0',
);

void main() {
  group('settings.gradle.kts', () {
    test('declara os dois plugins do Firebase, com versão e apply false', () {
      final s = patchSettingsGradle(settingsScaffold, config);
      expect(s, contains('id("com.google.gms.google-services") version "4.4.4" apply false'));
      expect(s, contains('id("com.google.firebase.crashlytics") version "3.0.7" apply false'));
      expect(conferirSettingsGradle(s), isEmpty);
    });

    test('é idempotente — rodar duas vezes não duplica', () {
      final uma = patchSettingsGradle(settingsScaffold, config);
      final duas = patchSettingsGradle(uma, config);
      expect(duas, uma);
      expect(conferirSettingsGradle(duas), isEmpty);
    });

    test('REPROVA em silêncio nunca: sem a âncora, lança', () {
      const semKotlin = 'plugins {\n    id("com.android.application")\n}\n';
      expect(
        () => patchSettingsGradle(semKotlin, config),
        throwsA(isA<PatchNaoCasou>().having(
          (e) => e.toString(),
          'mensagem',
          allOf(contains('settings.gradle.kts'), contains('scaffold')),
        )),
      );
    });
  });

  group('app/build.gradle.kts', () {
    test('aplica os plugins DEPOIS do plugin do Flutter', () {
      final s = patchAppGradle(appScaffold, config);
      final iFlutter = s.indexOf('dev.flutter.flutter-gradle-plugin');
      final iGms = s.indexOf('com.google.gms.google-services');
      final iCrash = s.indexOf('com.google.firebase.crashlytics');
      expect(iFlutter, greaterThan(-1));
      // Crashlytics lê o que o google-services registra: a ordem importa.
      expect(iGms, greaterThan(iFlutter));
      expect(iCrash, greaterThan(iGms));
    });

    test('fixa identidade oficial e SDKs aprovados', () {
      final s = patchAppGradle(appScaffold, config);
      expect(s, contains('namespace = "io.github.soniaambrosio.buracomastervip"'));
      expect(s, contains('applicationId = "io.github.soniaambrosio.buracomastervip"'));
      expect(s, contains('compileSdk = 36'));
      expect(s, contains('targetSdk = 36'));
      expect(s, contains('minSdk = 24'));
      expect(s, contains('versionCode = 141'));
      expect(s, contains('versionName = "1.0.0"'));
      expect(conferirAppGradle(s, config), isEmpty);
    });

    test('o applicationId de PoC não sobrevive ao remendo', () {
      final s = patchAppGradle(appScaffold, config);
      expect(s, isNot(contains('com.buracomastervip.poc')));
    });

    test('nenhum SDK fica preso ao Flutter — o alvo não muda sozinho', () {
      final s = patchAppGradle(appScaffold, config);
      expect(s, isNot(contains('flutter.targetSdkVersion')));
      expect(s, isNot(contains('flutter.minSdkVersion')));
      expect(s, isNot(contains('flutter.compileSdkVersion')));
    });

    test('é idempotente — e a conferência pega plugin duplicado', () {
      final uma = patchAppGradle(appScaffold, config);
      final duas = patchAppGradle(uma, config);
      expect(duas, uma);
      expect(conferirAppGradle(duas, config), isEmpty);

      // Duplicação forçada: o Gradle rejeita, e a conferência precisa ver antes.
      final duplicado = uma.replaceFirst(
        '    id("com.google.firebase.crashlytics")',
        '    id("com.google.firebase.crashlytics")\n    id("com.google.firebase.crashlytics")',
      );
      expect(conferirAppGradle(duplicado, config),
          contains(contains('aplicado 2 vezes')));
    });

    test('REPROVA em silêncio nunca: sem applicationId, lança', () {
      final semAppId = appScaffold.replaceAll(
          RegExp(r'applicationId = "[^"]*"'), '// applicationId removido');
      expect(() => patchAppGradle(semAppId, config), throwsA(isA<PatchNaoCasou>()));
    });

    test('a conferência denuncia Gradle que não foi remendado', () {
      final problemas = conferirAppGradle(appScaffold, config);
      expect(problemas, isNotEmpty);
      expect(problemas.join(), contains('não foi aplicado'));
      expect(problemas.join(), contains('applicationId'));
    });
  });

  group('MainActivity acompanha o namespace', () {
    test('o pacote é reescrito junto', () {
      const kt = 'package com.buracomastervip.poc.buraco_master_vip\n\n'
          'import io.flutter.embedding.android.FlutterActivity\n\n'
          'class MainActivity : FlutterActivity()\n';
      final s = patchMainActivity(kt, config);
      expect(s, startsWith('package io.github.soniaambrosio.buracomastervip'));
      expect(s, contains('class MainActivity : FlutterActivity()'));
    });

    test('o caminho do arquivo segue o pacote', () {
      expect(
        caminhoMainActivity('io.github.soniaambrosio.buracomastervip'),
        'android/app/src/main/kotlin/io/github/soniaambrosio/buracomastervip/MainActivity.kt',
      );
    });

    test('sem declaração de package, lança', () {
      expect(() => patchMainActivity('class X\n', config),
          throwsA(isA<PatchNaoCasou>()));
    });
  });

  group('google-services.json', () {
    const esperado = AppFirebaseEsperado(
      projectId: 'buraco-master-vip',
      projectNumber: '203886484007',
      packageName: 'io.github.soniaambrosio.buracomastervip',
      mobilesdkAppId: '1:203886484007:android:b1cd95baa0b9e6e629cc02',
    );

    /// Monta um google-services.json de teste. A `api_key` é sintética.
    String montar({
      String projectId = 'buraco-master-vip',
      String projectNumber = '203886484007',
      List<List<String>> apps = const [
        ['io.github.soniaambrosio.buracomastervip',
         '1:203886484007:android:b1cd95baa0b9e6e629cc02'],
      ],
      bool comChave = true,
    }) {
      final clientes = apps.map((a) => '''
    {
      "client_info": {
        "mobilesdk_app_id": "${a[1]}",
        "android_client_info": { "package_name": "${a[0]}" }
      },
      "api_key": ${comChave ? '[ { "current_key": "CHAVE_SINTETICA_DE_TESTE" } ]' : '[]'}
    }''').join(',\n');
      return '''
{
  "project_info": {
    "project_number": "$projectNumber",
    "project_id": "$projectId"
  },
  "client": [
$clientes
  ]
}
''';
    }

    test('configuração correta passa', () {
      final r = validarGoogleServices(conteudoJson: montar(), esperado: esperado);
      expect(r.aprovado, isTrue, reason: r.veredito);
      expect(r.codigoDeSaida, 0);
    });

    test('arquivo de projeto com vários apps passa, se o certo estiver lá', () {
      // É o formato real: um google-services.json traz todos os apps Android
      // do projeto, e o plugin escolhe pelo applicationId.
      final r = validarGoogleServices(
        conteudoJson: montar(apps: const [
          ['com.buracomastervip.app', '1:203886484007:android:1a8d60872d33e3d229cc02'],
          ['com.buracomastervip.poc.buraco_master_vip', '1:203886484007:android:734aaa61ca5ca68b29cc02'],
          ['com.mycompany.buracomastervip', '1:203886484007:android:7d871ec415fc46d729cc02'],
          ['io.github.soniaambrosio.buracomastervip', '1:203886484007:android:b1cd95baa0b9e6e629cc02'],
        ]),
        esperado: esperado,
      );
      expect(r.aprovado, isTrue, reason: r.veredito);
      expect(r.clientesEncontrados, 4);
    });

    test('CONFIGURAÇÃO AUSENTE reprova', () {
      for (final vazio in const ['', '   ', '\n']) {
        final r = validarGoogleServices(conteudoJson: vazio, esperado: esperado);
        expect(r.aprovado, isFalse);
        expect(r.reprovacoes.join(), contains('vazio ou ausente'));
      }
    });

    test('CONFIGURAÇÃO INVÁLIDA reprova sem ecoar o arquivo', () {
      final r = validarGoogleServices(
        conteudoJson: '{ "project_info": { truncado',
        esperado: esperado,
      );
      expect(r.aprovado, isFalse);
      expect(r.reprovacoes.join(), contains('não é JSON válido'));
      // A mensagem do parser cita o trecho onde falhou, e esse trecho pode ser
      // uma chave. Nada do conteúdo pode aparecer.
      expect(r.reprovacoes.join(), isNot(contains('truncado')));
    });

    test('JSON válido mas que não é objeto reprova', () {
      final r = validarGoogleServices(conteudoJson: '[1,2,3]', esperado: esperado);
      expect(r.aprovado, isFalse);
    });

    test('PACOTE DIVERGENTE reprova, e diz quais achou', () {
      final r = validarGoogleServices(
        conteudoJson: montar(apps: const [
          ['com.buracomastervip.poc.buraco_master_vip',
           '1:203886484007:android:734aaa61ca5ca68b29cc02'],
        ]),
        esperado: esperado,
      );
      expect(r.aprovado, isFalse);
      expect(r.reprovacoes.join(), contains('não declara o pacote'));
      expect(r.reprovacoes.join(), contains('com.buracomastervip.poc'));
      expect(r.pacotesEncontrados, ['com.buracomastervip.poc.buraco_master_vip']);
    });

    test('App ID divergente para o pacote certo reprova', () {
      final r = validarGoogleServices(
        conteudoJson: montar(apps: const [
          ['io.github.soniaambrosio.buracomastervip',
           '1:203886484007:android:734aaa61ca5ca68b29cc02'],
        ]),
        esperado: esperado,
      );
      expect(r.aprovado, isFalse);
      expect(r.reprovacoes.join(), contains('mobilesdk_app_id'));
      // Só o esperado aparece; o encontrado não vira inventário do projeto.
      expect(r.reprovacoes.join(), isNot(contains('734aaa61')));
    });

    test('projeto errado reprova', () {
      final r = validarGoogleServices(
        conteudoJson: montar(projectId: 'outro-projeto'),
        esperado: esperado,
      );
      expect(r.aprovado, isFalse);
      expect(r.reprovacoes.join(), contains('project_id diverge'));
    });

    test('project_number errado reprova', () {
      final r = validarGoogleServices(
        conteudoJson: montar(projectNumber: '999999999'),
        esperado: esperado,
      );
      expect(r.aprovado, isFalse);
      expect(r.reprovacoes.join(), contains('project_number diverge'));
    });

    test('sem api_key reprova', () {
      final r = validarGoogleServices(
        conteudoJson: montar(comChave: false),
        esperado: esperado,
      );
      expect(r.aprovado, isFalse);
      expect(r.reprovacoes.join(), contains('api_key'));
    });

    test('sem bloco client reprova', () {
      final r = validarGoogleServices(
        conteudoJson: '{"project_info":{"project_id":"buraco-master-vip",'
            '"project_number":"203886484007"}}',
        esperado: esperado,
      );
      expect(r.aprovado, isFalse);
      expect(r.reprovacoes.join(), contains('nenhum aplicativo'));
    });

    test('nenhuma mensagem carrega chave de API', () {
      final r = validarGoogleServices(
        conteudoJson: montar(projectId: 'errado'),
        esperado: esperado,
      );
      expect(r.veredito, isNot(contains('CHAVE_SINTETICA_DE_TESTE')));
    });

    test('o descritor do app oficial é lido do JSON versionado', () {
      const descritor = '''
{
  "projectId": "buraco-master-vip",
  "projectNumber": "203886484007",
  "packageName": "io.github.soniaambrosio.buracomastervip",
  "mobilesdkAppId": "1:203886484007:android:b1cd95baa0b9e6e629cc02",
  "displayName": "Buraco Master VIP Oficial"
}
''';
      final lido = AppFirebaseEsperado.deJson(descritor);
      expect(lido.packageName, esperado.packageName);
      expect(lido.mobilesdkAppId, esperado.mobilesdkAppId);
      expect(lido.toString(), contains('io.github.soniaambrosio.buracomastervip'));
    });
  });
}
