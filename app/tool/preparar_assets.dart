// preparar_assets.dart — copia os assets e os declara no pubspec gerado.
//
// O `build.yml` faz isso com um passo escrito à mão por pasta, e por isso ele
// precisa ser editado toda vez que nasce uma pasta de arte nova — quem esquece
// descobre pelo app com quadrado branco na tela. Aqui a lista sai do disco.
//
// O Flutter NÃO inclui subdiretórios recursivamente: cada pasta com arquivo
// precisa da própria linha no pubspec. É a regra que mais causa asset faltando
// em release, e é por isso que a varredura desce a árvore inteira.
//
// Uso:
//   dart run app/tool/preparar_assets.dart --origem=app/assets --projeto=app_build

import 'dart:io';

void main(List<String> args) {
  String? valor(String nome) {
    for (final a in args) {
      if (a.startsWith('--$nome=')) return a.substring(nome.length + 3);
    }
    return null;
  }

  final origem = Directory(valor('origem') ?? 'app/assets');
  final projeto = valor('projeto') ?? 'app_build';

  if (!origem.existsSync()) {
    stderr.writeln('ERRO: pasta de assets não encontrada: ${origem.path}');
    exit(2);
  }
  final pubspec = File('$projeto/pubspec.yaml');
  if (!pubspec.existsSync()) {
    stderr.writeln('ERRO: $projeto/pubspec.yaml não existe. Rode o `flutter create` antes.');
    exit(2);
  }

  // --- copiar ------------------------------------------------------------
  var arquivos = 0;
  final pastasComArquivo = <String>{};
  for (final e in origem.listSync(recursive: true)) {
    if (e is! File) continue;
    final rel = _rel(origem.path, e.path);
    final destino = File('$projeto/assets/$rel');
    destino.parent.createSync(recursive: true);
    destino.writeAsBytesSync(e.readAsBytesSync());
    arquivos++;
    final pasta = rel.contains('/') ? rel.substring(0, rel.lastIndexOf('/')) : '';
    pastasComArquivo.add(pasta.isEmpty ? 'assets/' : 'assets/$pasta/');
  }

  if (arquivos == 0) {
    stderr.writeln('ERRO: nenhum asset copiado de ${origem.path}.');
    exit(1);
  }

  // --- declarar ----------------------------------------------------------
  final declaracoes = pastasComArquivo.toList()..sort();
  final linhas = pubspec.readAsStringSync().split('\n');
  final i = linhas.indexWhere((l) => l.trimRight() == 'flutter:');
  if (i < 0) {
    stderr.writeln('ERRO: não achei a seção `flutter:` de nível 0 no pubspec gerado.');
    exit(1);
  }
  // Remove qualquer bloco `assets:` anterior, para ser idempotente.
  final semAssets = <String>[];
  var pulando = false;
  for (var k = 0; k < linhas.length; k++) {
    final l = linhas[k];
    if (l.trimRight() == '  assets:') {
      pulando = true;
      continue;
    }
    if (pulando) {
      if (l.startsWith('    - ')) continue;
      pulando = false;
    }
    semAssets.add(l);
  }
  final j = semAssets.indexWhere((l) => l.trimRight() == 'flutter:');
  semAssets.insertAll(j + 1, <String>[
    '  assets:',
    ...declaracoes.map((d) => '    - $d'),
  ]);
  pubspec.writeAsStringSync(semAssets.join('\n'));

  stdout.writeln('assets copiados: $arquivos arquivo(s) em '
      '${declaracoes.length} pasta(s)');
  for (final d in declaracoes) {
    stdout.writeln('  · $d');
  }
}

String _rel(String base, String caminho) {
  final b = base.replaceAll('\\', '/');
  final c = caminho.replaceAll('\\', '/');
  return c.startsWith('$b/') ? c.substring(b.length + 1) : c;
}
