// identidade_build.dart — quem é esta build.
//
// Responde "qual build quebrou?" sem depender de log de CI. Todo evento de
// falha carrega esta identidade, e ela é a MESMA que o manifesto de release
// grava em disco (ver manifesto_build.dart). O elo entre o crash e o commit é
// o SHA imutável.
//
// A identidade NÃO é lida de arquivo em tempo de execução: ela é gravada no
// binário por `--dart-define` na hora do build. Isso torna impossível um APK
// mentir sobre a própria origem — não há caminho de código que a altere.
//
// Nada aqui é PII: versão, número de build, ambiente, SHA e branch descrevem o
// ARTEFATO, nunca o jogador.
//
// Dart puro de propósito, sem `package:flutter`: o gate de release
// (`app/tool/gate_identidade_build.dart`) roda em `dart run`, fora de
// qualquer pubspec, e precisa julgar identidade com EXATAMENTE as mesmas
// regras que o app aplica em tempo de execução. Uma regra só, um arquivo só.

/// Onde esta build roda. Determina se o coletor real pode ser ligado.
enum AmbienteBuild {
  desenvolvimento,
  teste,
  homologacao,
  producao;

  static AmbienteBuild porNome(String nome) {
    for (final a in AmbienteBuild.values) {
      if (a.name == nome) return a;
    }
    return AmbienteBuild.desenvolvimento;
  }

  /// Só homologação e produção podem falar com um coletor real.
  bool get aceitaColetorReal =>
      this == AmbienteBuild.homologacao || this == AmbienteBuild.producao;
}

/// Identidade reproduzível de uma build. Imutável por construção.
class IdentidadeBuild {
  /// Nome de versão visível ao jogador (ex.: `1.4.0`).
  final String versionName;

  /// Número de build do Android. Determinístico por commit (ver o gate).
  final int versionCode;

  /// SHA completo do commit de origem. 40 hex, minúsculo.
  final String sha;

  /// Branch de origem no momento do build. Informativo — o SHA é a verdade.
  final String branch;

  final AmbienteBuild ambiente;

  /// Versão do Flutter que compilou (ex.: `3.44.8`).
  final String flutterVersion;

  /// Versão do Dart que compilou (ex.: `3.11.1`).
  final String dartVersion;

  const IdentidadeBuild({
    required this.versionName,
    required this.versionCode,
    required this.sha,
    required this.branch,
    required this.ambiente,
    this.flutterVersion = '',
    this.dartVersion = '',
  });

  /// Chaves de `--dart-define` que gravam a identidade no binário.
  static const chaveVersionName = 'BMV_VERSION_NAME';
  static const chaveVersionCode = 'BMV_VERSION_CODE';
  static const chaveSha = 'BMV_GIT_SHA';
  static const chaveBranch = 'BMV_GIT_BRANCH';
  static const chaveAmbiente = 'BMV_AMBIENTE';
  static const chaveFlutter = 'BMV_FLUTTER_VERSION';
  static const chaveDart = 'BMV_DART_VERSION';

  /// Lê a identidade gravada no binário. Sem I/O, sem async, sem falha:
  /// campo ausente vira vazio e é denunciado por [pendencias].
  factory IdentidadeBuild.doBinario() {
    return IdentidadeBuild(
      versionName: const String.fromEnvironment(chaveVersionName),
      versionCode: const int.fromEnvironment(chaveVersionCode),
      sha: const String.fromEnvironment(chaveSha).toLowerCase(),
      branch: const String.fromEnvironment(chaveBranch),
      ambiente: AmbienteBuild.porNome(
        const String.fromEnvironment(chaveAmbiente,
            defaultValue: 'desenvolvimento'),
      ),
      flutterVersion: const String.fromEnvironment(chaveFlutter),
      dartVersion: const String.fromEnvironment(chaveDart),
    );
  }

  static final RegExp _sha40 = RegExp(r'^[0-9a-f]{40}$');
  static final RegExp _semver = RegExp(r'^\d+\.\d+\.\d+([+-][0-9A-Za-z.\-]+)?$');

  /// O que falta para esta identidade ser provável. Vazio == provável.
  ///
  /// É a mesma lista que o gate de release consulta, então o app e o CI
  /// nunca discordam sobre o que conta como identidade válida.
  List<String> get pendencias {
    final faltas = <String>[];
    if (sha.isEmpty) {
      faltas.add('SHA ausente');
    } else if (!_sha40.hasMatch(sha)) {
      faltas.add('SHA malformado (esperado 40 hex minúsculo)');
    }
    if (versionName.isEmpty) {
      faltas.add('versionName ausente');
    } else if (!_semver.hasMatch(versionName)) {
      faltas.add('versionName fora de x.y.z');
    }
    if (versionCode <= 0) faltas.add('versionCode inválido (<= 0)');
    if (branch.isEmpty) faltas.add('branch ausente');
    return faltas;
  }

  bool get provavel => pendencias.isEmpty;

  /// SHA curto para leitura humana em runbook e ticket.
  String get shaCurto => sha.length >= 7 ? sha.substring(0, 7) : sha;

  /// Uma linha que identifica a build inteira. Vai no topo de todo relatório.
  String get resumo =>
      '$versionName ($versionCode) · ${shaCurto.isEmpty ? 'sem-sha' : shaCurto} · ${ambiente.name}';

  /// Contexto anexado a TODO evento de falha.
  ///
  /// Baixa cardinalidade por construção: são cinco chaves fixas cujos valores
  /// mudam uma vez por release, não uma vez por jogador ou por sessão.
  Map<String, String> paraContexto() => <String, String>{
        'build.versionName': versionName,
        'build.versionCode': '$versionCode',
        'build.sha': sha,
        'build.branch': branch,
        'build.ambiente': ambiente.name,
      };

  Map<String, Object?> paraJson() => <String, Object?>{
        'versionName': versionName,
        'versionCode': versionCode,
        'sha': sha,
        'branch': branch,
        'ambiente': ambiente.name,
        'flutter': flutterVersion,
        'dart': dartVersion,
      };

  factory IdentidadeBuild.deJson(Map<String, Object?> j) => IdentidadeBuild(
        versionName: (j['versionName'] as String?) ?? '',
        versionCode: (j['versionCode'] as num?)?.toInt() ?? 0,
        sha: ((j['sha'] as String?) ?? '').toLowerCase(),
        branch: (j['branch'] as String?) ?? '',
        ambiente: AmbienteBuild.porNome((j['ambiente'] as String?) ?? ''),
        flutterVersion: (j['flutter'] as String?) ?? '',
        dartVersion: (j['dart'] as String?) ?? '',
      );

  @override
  bool operator ==(Object other) =>
      other is IdentidadeBuild &&
      other.versionName == versionName &&
      other.versionCode == versionCode &&
      other.sha == sha &&
      other.branch == branch &&
      other.ambiente == ambiente &&
      other.flutterVersion == flutterVersion &&
      other.dartVersion == dartVersion;

  @override
  int get hashCode => Object.hash(
      versionName, versionCode, sha, branch, ambiente, flutterVersion, dartVersion);

  @override
  String toString() => 'IdentidadeBuild($resumo)';
}
