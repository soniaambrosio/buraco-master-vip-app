// gate_identidade_build.dart — o portão entre "compilou" e "pode sair".
//
// Roda sem pubspec, por `dart run`, porque este repositório não versiona um
// projeto Flutter (o CI monta um com `flutter create`). Toda a regra de
// julgamento mora em `app/lib/observability/manifesto_build.dart`, que é o
// MESMO arquivo que o app usa em tempo de execução — o gate e o app não podem
// discordar sobre o que é uma identidade válida.
//
// Uso:
//   dart run app/tool/gate_identidade_build.dart [opções]
//
//   --repo=<dir>          raiz do repositório (padrão: diretório atual)
//   --ambiente=<nome>     desenvolvimento|teste|homologacao|producao
//   --versionName=<x.y.z> padrão: lido de app/data/observabilidade/versao.txt
//   --artefato=<caminho>  artefato a hashear (repetível)
//   --simbolos=<dir>      diretório de --split-debug-info (repetível)
//   --manifesto=<caminho> onde gravar o manifesto
//   --registrar           grava o versionCode no livro-razão (só após PASS)
//   --defines             imprime as linhas --dart-define para o build
//   --permitir-arvore-suja   diagnóstico local; NUNCA em release
//   --sem-artefatos       valida identidade antes de compilar (modo pré-build)
//
// Exit code: 0 = PASS, 1 = FAIL, 2 = erro de uso/ambiente.

import 'dart:io';

import '../lib/observability/identidade_build.dart';
import '../lib/observability/manifesto_build.dart';
import '../lib/observability/sha256.dart';

const String _caminhoLivro = 'app/data/observabilidade/versioncode_ledger.json';
const String _caminhoVersao = 'app/data/observabilidade/versao.txt';

void main(List<String> args) {
  if (args.contains('--help') || args.contains('-h')) {
    stdout.writeln(_ajuda);
    exit(0);
  }

  final opcoes = _Opcoes.de(args);
  final repo = Directory(opcoes.repo);
  if (!repo.existsSync()) {
    stderr.writeln('ERRO: repositório não encontrado: ${opcoes.repo}');
    exit(2);
  }

  final git = _Git(opcoes.repo);
  if (!git.disponivel) {
    stderr.writeln('ERRO: `git` indisponível — a identidade de build não pode '
        'ser provada sem ele. Nenhuma release sai daqui.');
    exit(2);
  }

  // --- identidade -------------------------------------------------------
  final sha = git.texto(['rev-parse', 'HEAD']);
  final branch = git.texto(['rev-parse', '--abbrev-ref', 'HEAD']);

  // Sujeira inclui arquivo NOVO não commitado: um `.dart` solto muda o que é
  // compilado tanto quanto uma linha editada, e o SHA não o descreveria.
  // O que o `.gitignore` cobre não conta — é assim que `app_build/`, que o CI
  // gera a cada run, não reprova a própria release.
  final sujeira = git
      .texto(['status', '--porcelain'])
      .split('\n')
      .where((l) => l.trim().isNotEmpty)
      .toList();
  final arvoreLimpa = sujeira.isEmpty;

  // FONTE DETERMINÍSTICA DO versionCode: a contagem de commits até este SHA.
  // Não é digitado por ninguém, não depende do número do run do CI e não muda
  // se a mesma release for recompilada. Mesmo commit -> mesmo versionCode.
  final contagem = git.texto(['rev-list', '--count', 'HEAD']);
  final versionCode = int.tryParse(contagem) ?? 0;

  final versionName = opcoes.versionName ?? _lerVersionName(opcoes.repo);
  final ferramentas = _versoesDeFerramenta();

  final identidade = IdentidadeBuild(
    versionName: versionName,
    versionCode: versionCode,
    sha: sha.toLowerCase(),
    branch: branch,
    ambiente: AmbienteBuild.porNome(opcoes.ambiente),
    flutterVersion: ferramentas.flutter,
    dartVersion: ferramentas.dart,
  );

  if (opcoes.defines) {
    for (final linha in _linhasDeDefine(identidade)) {
      stdout.writeln(linha);
    }
    // `--defines` é consulta, não julgamento: ainda assim exige identidade
    // provável, senão imprimiria defines que o gate reprovaria depois.
    if (!identidade.provavel) {
      stderr.writeln('FAIL — identidade improvável: ${identidade.pendencias.join('; ')}');
      exit(1);
    }
    exit(0);
  }

  // --- manifesto --------------------------------------------------------
  final artefatos = <String, String>{};
  for (final caminho in opcoes.artefatos) {
    final f = File(_juntar(opcoes.repo, caminho));
    if (!f.existsSync()) {
      stderr.writeln('ERRO: artefato declarado não existe: $caminho');
      exit(2);
    }
    artefatos[_normalizar(caminho)] = sha256Hex(f.readAsBytesSync());
  }

  final simbolos = <String, String>{};
  for (final dir in opcoes.simbolos) {
    final d = Directory(_juntar(opcoes.repo, dir));
    if (!d.existsSync()) {
      stderr.writeln('ERRO: diretório de símbolos não existe: $dir');
      exit(2);
    }
    for (final e in d.listSync(recursive: true).whereType<File>()) {
      final rel = _normalizar(e.path.substring(opcoes.repo.length).replaceAll('\\', '/'));
      simbolos[rel] = sha256Hex(e.readAsBytesSync());
    }
  }

  final manifesto = ManifestoBuild(
    identidade: identidade,
    artefatos: artefatos,
    simbolos: simbolos,
  );

  // --- livro-razão e veredito ------------------------------------------
  final arquivoLivro = File(_juntar(opcoes.repo, _caminhoLivro));
  final livro = arquivoLivro.existsSync()
      ? LivroDeVersionCode.deJson(arquivoLivro.readAsStringSync())
      : LivroDeVersionCode.vazio();

  final resultado = avaliarGate(
    identidade: identidade,
    arvoreLimpa: arvoreLimpa || opcoes.permitirArvoreSuja,
    livro: livro,
    manifesto: manifesto,
    exigirArtefatos: !opcoes.semArtefatos,
  );

  stdout.writeln('===== GATE DE IDENTIDADE DE BUILD =====');
  stdout.writeln('build:        ${identidade.resumo}');
  stdout.writeln('sha:          ${identidade.sha}');
  stdout.writeln('branch:       ${identidade.branch}');
  stdout.writeln('flutter/dart: ${ferramentas.flutter} / ${ferramentas.dart}');
  stdout.writeln('árvore:       ${arvoreLimpa ? 'limpa' : 'SUJA (${sujeira.length})'}'
      '${opcoes.permitirArvoreSuja && !arvoreLimpa ? ' (tolerada por --permitir-arvore-suja)' : ''}');
  for (final linha in sujeira.take(10)) {
    stdout.writeln('              $linha');
  }
  if (sujeira.length > 10) {
    stdout.writeln('              … e mais ${sujeira.length - 10}');
  }
  stdout.writeln('artefatos:    ${artefatos.length}');
  stdout.writeln('símbolos:     ${simbolos.length}');
  stdout.writeln('manifesto:    ${manifesto.impressaoDigital}');
  stdout.writeln('livro:        ${livro.registros.length} registro(s), maior=${livro.maiorVersionCode}');
  stdout.writeln('---------------------------------------');
  stdout.writeln(resultado.veredito);

  if (!resultado.aprovado) exit(resultado.codigoDeSaida);

  if (opcoes.manifesto != null) {
    final destino = File(_juntar(opcoes.repo, opcoes.manifesto!));
    destino.parent.createSync(recursive: true);
    destino.writeAsStringSync('${manifesto.paraJsonCanonico()}\n');
    stdout.writeln('manifesto gravado em ${opcoes.manifesto}');
  }

  if (opcoes.registrar) {
    final novo = livro.com(RegistroVersionCode(
      versionCode: identidade.versionCode,
      sha: identidade.sha,
      branch: identidade.branch,
    ));
    arquivoLivro.parent.createSync(recursive: true);
    arquivoLivro.writeAsStringSync('${novo.paraJsonCanonico()}\n');
    stdout.writeln('versionCode ${identidade.versionCode} registrado no livro-razão');
  }

  exit(0);
}

// --- apoio --------------------------------------------------------------

class _Opcoes {
  _Opcoes({
    required this.repo,
    required this.ambiente,
    required this.versionName,
    required this.artefatos,
    required this.simbolos,
    required this.manifesto,
    required this.registrar,
    required this.defines,
    required this.permitirArvoreSuja,
    required this.semArtefatos,
  });

  final String repo;
  final String ambiente;
  final String? versionName;
  final List<String> artefatos;
  final List<String> simbolos;
  final String? manifesto;
  final bool registrar;
  final bool defines;
  final bool permitirArvoreSuja;
  final bool semArtefatos;

  static _Opcoes de(List<String> args) {
    String? valor(String nome) {
      for (final a in args) {
        if (a.startsWith('--$nome=')) return a.substring(nome.length + 3);
      }
      return null;
    }

    List<String> todos(String nome) => args
        .where((a) => a.startsWith('--$nome='))
        .map((a) => a.substring(nome.length + 3))
        .toList();

    var repo = valor('repo') ?? Directory.current.path;
    repo = repo.replaceAll('\\', '/');
    if (repo.endsWith('/')) repo = repo.substring(0, repo.length - 1);

    return _Opcoes(
      repo: repo,
      ambiente: valor('ambiente') ?? 'desenvolvimento',
      versionName: valor('versionName'),
      artefatos: todos('artefato'),
      simbolos: todos('simbolos'),
      manifesto: valor('manifesto'),
      registrar: args.contains('--registrar'),
      defines: args.contains('--defines'),
      permitirArvoreSuja: args.contains('--permitir-arvore-suja'),
      semArtefatos: args.contains('--sem-artefatos'),
    );
  }
}

class _Git {
  _Git(this.repo);
  final String repo;

  bool get disponivel {
    try {
      return Process.runSync('git', ['-C', repo, 'rev-parse', '--git-dir'])
              .exitCode ==
          0;
    } catch (_) {
      return false;
    }
  }

  String texto(List<String> argumentos) {
    final r = Process.runSync('git', ['-C', repo, ...argumentos]);
    if (r.exitCode != 0) return '';
    return (r.stdout as String).trim();
  }
}

class _Ferramentas {
  const _Ferramentas(this.flutter, this.dart);
  final String flutter;
  final String dart;
}

/// Versões de Flutter e Dart que estão compilando. Ficam no manifesto porque
/// "mesmo commit, outro Flutter" é outro artefato, e isso já explicou
/// regressão antes.
_Ferramentas _versoesDeFerramenta() {
  var flutter = '';
  try {
    final r = Process.runSync('flutter', ['--version'], runInShell: true);
    if (r.exitCode == 0) {
      final m = RegExp(r'Flutter (\d+\.\d+\.\d+)').firstMatch('${r.stdout}');
      flutter = m?.group(1) ?? '';
    }
  } catch (_) {
    // Sem Flutter no PATH (ex.: gate rodando só sobre identidade). Não é fatal.
  }
  final dart = RegExp(r'^(\d+\.\d+\.\d+)').firstMatch(Platform.version)?.group(1) ?? '';
  return _Ferramentas(flutter, dart);
}

String _lerVersionName(String repo) {
  final f = File(_juntar(repo, _caminhoVersao));
  if (!f.existsSync()) return '';
  return f.readAsStringSync().trim();
}

List<String> _linhasDeDefine(IdentidadeBuild id) => <String>[
      '--dart-define=${IdentidadeBuild.chaveVersionName}=${id.versionName}',
      '--dart-define=${IdentidadeBuild.chaveVersionCode}=${id.versionCode}',
      '--dart-define=${IdentidadeBuild.chaveSha}=${id.sha}',
      '--dart-define=${IdentidadeBuild.chaveBranch}=${id.branch}',
      '--dart-define=${IdentidadeBuild.chaveAmbiente}=${id.ambiente.name}',
      '--dart-define=${IdentidadeBuild.chaveFlutter}=${id.flutterVersion}',
      '--dart-define=${IdentidadeBuild.chaveDart}=${id.dartVersion}',
    ];

String _juntar(String base, String relativo) =>
    relativo.startsWith('/') || RegExp(r'^[A-Za-z]:').hasMatch(relativo)
        ? relativo
        : '$base/$relativo';

String _normalizar(String caminho) {
  var c = caminho.replaceAll('\\', '/');
  while (c.startsWith('/')) {
    c = c.substring(1);
  }
  return c;
}

const String _ajuda = '''
gate_identidade_build — prova que este artefato é este commit.

  dart run app/tool/gate_identidade_build.dart --ambiente=producao \\
      --artefato=app_build/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk \\
      --simbolos=app_build/build/simbolos \\
      --manifesto=app/data/observabilidade/MANIFESTO-BUILD.json --registrar

Exit code: 0 PASS · 1 FAIL · 2 erro de uso/ambiente.
''';
