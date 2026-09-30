// manifesto_build.dart — a prova documental de quem é o artefato.
//
// O manifesto é o outro lado do elo que o crash usa. O evento de falha diz
// "quebrei na build X"; o manifesto diz "a build X é o commit Y, compilada
// com o Flutter Z, e estes são os hashes do APK e do mapa de símbolos".
// Sem ele, o SHA num crash é um número sem nada com que cruzar.
//
// REPRODUTIBILIDADE é o requisito que dita o formato: nenhum campo de
// timestamp, nenhuma ordem dependente de plataforma. Duas execuções do gate
// no mesmo commit, com os mesmos artefatos, produzem bytes idênticos — e por
// isso `impressaoDigital` é uma afirmação verificável, não decorativa.
//
// Dart puro: roda tanto dentro do app quanto no `dart run` do gate.

import 'dart:convert';

import 'identidade_build.dart';
import 'redacao.dart';
import 'sha256.dart';

/// Uma linha do livro-razão de `versionCode`.
class RegistroVersionCode {
  const RegistroVersionCode({
    required this.versionCode,
    required this.sha,
    required this.branch,
  });

  final int versionCode;
  final String sha;
  final String branch;

  Map<String, Object?> paraJson() => <String, Object?>{
        'versionCode': versionCode,
        'sha': sha,
        'branch': branch,
      };

  factory RegistroVersionCode.deJson(Map<String, Object?> j) =>
      RegistroVersionCode(
        versionCode: (j['versionCode'] as num?)?.toInt() ?? 0,
        sha: ((j['sha'] as String?) ?? '').toLowerCase(),
        branch: (j['branch'] as String?) ?? '',
      );

  @override
  String toString() => '$versionCode -> ${sha.length >= 7 ? sha.substring(0, 7) : sha}';
}

/// Livro-razão de `versionCode` já emitidos.
///
/// Existe porque `versionCode` é a única coisa que a Play usa para ordenar
/// builds, e um repetido ou regressivo é irrecuperável depois de publicado:
/// não dá para "desemitir" um número. O livro é versionado no repositório
/// justamente para que a conferência aconteça no code review, e não na Play.
class LivroDeVersionCode {
  LivroDeVersionCode(List<RegistroVersionCode> registros)
      : registros = List<RegistroVersionCode>.unmodifiable(registros);

  final List<RegistroVersionCode> registros;

  static LivroDeVersionCode vazio() => LivroDeVersionCode(const []);

  factory LivroDeVersionCode.deJson(String texto) {
    if (texto.trim().isEmpty) return LivroDeVersionCode.vazio();
    final bruto = jsonDecode(texto);
    final lista = bruto is Map ? (bruto['registros'] as List? ?? const []) : (bruto as List);
    return LivroDeVersionCode(
      lista
          .cast<Map<String, Object?>>()
          .map(RegistroVersionCode.deJson)
          .toList(growable: false),
    );
  }

  int get maiorVersionCode =>
      registros.fold<int>(0, (m, r) => r.versionCode > m ? r.versionCode : m);

  RegistroVersionCode? porVersionCode(int vc) {
    for (final r in registros) {
      if (r.versionCode == vc) return r;
    }
    return null;
  }

  /// Novo livro com [registro] acrescentado, ordenado por `versionCode`.
  /// Reemitir o MESMO par (versionCode, sha) é idempotente.
  LivroDeVersionCode com(RegistroVersionCode registro) {
    final existente = porVersionCode(registro.versionCode);
    if (existente != null && existente.sha == registro.sha) return this;
    final novos = <RegistroVersionCode>[...registros, registro]
      ..sort((a, b) => a.versionCode.compareTo(b.versionCode));
    return LivroDeVersionCode(novos);
  }

  String paraJsonCanonico() => _jsonCanonico(<String, Object?>{
        'registros': registros.map((r) => r.paraJson()).toList(),
      });
}

/// O manifesto de uma build.
class ManifestoBuild {
  ManifestoBuild({
    required this.identidade,
    Map<String, String> artefatos = const <String, String>{},
    Map<String, String> simbolos = const <String, String>{},
  })  : artefatos = Map<String, String>.unmodifiable(artefatos),
        simbolos = Map<String, String>.unmodifiable(simbolos);

  final IdentidadeBuild identidade;

  /// Caminho relativo do artefato -> sha256 do conteúdo.
  final Map<String, String> artefatos;

  /// Caminho relativo do mapa de símbolos -> sha256 do conteúdo.
  ///
  /// São os arquivos de `--split-debug-info` (e o `mapping.txt` do R8, quando
  /// houver). Ficam AQUI, e não num diretório solto, para que a associação
  /// símbolo↔build seja a mesma linha que o crash cita.
  final Map<String, String> simbolos;

  /// Versão do esquema. Muda se o formato mudar, para que um manifesto antigo
  /// continue legível durante uma investigação.
  static const int esquema = 1;

  String paraJsonCanonico() => _jsonCanonico(<String, Object?>{
        'esquema': esquema,
        'identidade': identidade.paraJson(),
        'artefatos': artefatos,
        'simbolos': simbolos,
      });

  /// Hash do próprio manifesto. Igual para o mesmo commit e os mesmos
  /// artefatos, em qualquer máquina.
  String get impressaoDigital => sha256DoTexto(paraJsonCanonico());

  /// `true` se nada com forma de segredo (JWT, chave de API, e-mail, número
  /// longo) está dentro do manifesto. Auto-teste do próprio gate.
  bool get semSegredos {
    final json = paraJsonCanonico();
    return const Redator().formasInequivocas(json) == json;
  }
}

/// O veredito do gate.
class ResultadoGate {
  ResultadoGate(List<String> reprovacoes)
      : reprovacoes = List<String>.unmodifiable(reprovacoes);

  final List<String> reprovacoes;

  bool get aprovado => reprovacoes.isEmpty;

  /// `0` aprovado, `1` reprovado — é o exit code do gate.
  int get codigoDeSaida => aprovado ? 0 : 1;

  String get veredito => aprovado
      ? 'PASS — identidade de build provada'
      : 'FAIL — ${reprovacoes.length} reprovação(ões):\n  · ${reprovacoes.join('\n  · ')}';
}

/// Avalia se uma build pode ser liberada.
///
/// Reprova, e cada regra existe por um motivo distinto:
///   · identidade incompleta — o crash não teria com que cruzar;
///   · árvore suja — o SHA não descreveria o que foi compilado;
///   · versionCode repetido — dois artefatos diferentes com o mesmo número;
///   · versionCode regressivo — a Play recusa, ou pior, aceita e confunde;
///   · artefato sem hash — não dá para provar que o APK é o desta build;
///   · segredo no manifesto — o manifesto é publicado junto do artefato.
ResultadoGate avaliarGate({
  required IdentidadeBuild identidade,
  required bool arvoreLimpa,
  required LivroDeVersionCode livro,
  ManifestoBuild? manifesto,
  bool exigirArtefatos = true,
}) {
  final reprovacoes = <String>[];

  for (final p in identidade.pendencias) {
    reprovacoes.add('identidade: $p');
  }

  if (!arvoreLimpa) {
    reprovacoes.add(
        'árvore suja: há mudança não commitada; o SHA não descreveria o que foi compilado');
  }

  final vc = identidade.versionCode;
  if (vc > 0) {
    final jaEmitido = livro.porVersionCode(vc);
    if (jaEmitido != null && jaEmitido.sha != identidade.sha) {
      reprovacoes.add(
          'versionCode repetido: $vc já foi emitido para ${jaEmitido.sha} e agora viria de ${identidade.sha}');
    }
    if (vc < livro.maiorVersionCode) {
      reprovacoes.add(
          'versionCode regressivo: $vc é menor que o maior já emitido (${livro.maiorVersionCode})');
    }
  }

  if (manifesto != null) {
    if (exigirArtefatos && manifesto.artefatos.isEmpty) {
      reprovacoes.add(
          'identidade do artefato não provada: o manifesto não declara nenhum artefato');
    }
    manifesto.artefatos.forEach((caminho, hash) {
      if (hash.length != 64) {
        reprovacoes.add('artefato sem sha256 válido: $caminho');
      }
    });
    manifesto.simbolos.forEach((caminho, hash) {
      if (hash.length != 64) {
        reprovacoes.add('mapa de símbolos sem sha256 válido: $caminho');
      }
    });
    if (!manifesto.semSegredos) {
      reprovacoes.add('segredo detectado dentro do manifesto de build');
    }
  } else if (exigirArtefatos) {
    reprovacoes.add('identidade do artefato não provada: manifesto ausente');
  }

  return ResultadoGate(reprovacoes);
}

/// JSON com chaves ordenadas e indentação fixa. É o que torna o manifesto
/// comparável byte a byte entre duas execuções.
String _jsonCanonico(Object? valor) =>
    const JsonEncoder.withIndent('  ').convert(_ordenar(valor));

Object? _ordenar(Object? v) {
  if (v is Map) {
    final chaves = v.keys.map((k) => '$k').toList()..sort();
    return <String, Object?>{
      for (final k in chaves) k: _ordenar(v[k]),
    };
  }
  if (v is List) return v.map(_ordenar).toList();
  return v;
}
