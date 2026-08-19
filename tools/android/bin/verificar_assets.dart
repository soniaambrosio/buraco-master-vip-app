// Cruza TRES listas que precisam concordar e, hoje, nao concordam:
//
//   (a) os caminhos `assets/...` citados no codigo Dart;
//   (b) os arquivos que existem em `app/assets/`;
//   (c) as pastas declaradas no bloco `flutter: assets:` do `app/pubspec.yaml`.
//
// Qualquer par desses que divirja produz um defeito que NENHUM erro de
// compilacao acusa:
//
//   citado mas inexistente ....... a tela abre e a imagem falha em tempo de
//                                  execucao (widget de erro, ou excecao se o
//                                  `Image.asset` nao tiver `errorBuilder`);
//   existe mas nao declarado ..... o arquivo simplesmente nao entra no bundle;
//   declarado mas inexistente .... `flutter build` falha — este e o unico dos
//                                  tres que ja avisa sozinho.
//
// Foi assim que 46 caminhos de `assets/loja/` passaram a ser citados por
// `loja_categoria_screen.dart` sem que a pasta existisse ou fosse declarada.
//
// Uso:
//   dart run tools/android/bin/verificar_assets.dart --app=app
//   dart run tools/android/bin/verificar_assets.dart --app=app --tolerar-ausentes=assets/loja/
//
// `--tolerar-ausentes` recebe prefixos separados por virgula e serve para
// registrar, de forma explicita e visivel, uma arte que ainda nao chegou. E
// deliberadamente chato de usar: a divida fica escrita no comando, e nao
// escondida num `|| true`.
import 'dart:io';

void main(List<String> argumentos) {
  final args = _Argumentos(argumentos);
  final app = Directory(args.opcional('app') ?? 'app');
  final tolerados = (args.opcional('tolerar-ausentes') ?? '')
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  final lib = Directory('${app.path}/lib');
  final assets = Directory('${app.path}/assets');
  final pubspec = File('${app.path}/pubspec.yaml');
  for (final e in [lib, assets]) {
    if (!e.existsSync()) _abortar('nao encontrei ${e.path}');
  }
  if (!pubspec.existsSync()) _abortar('nao encontrei ${pubspec.path}');

  // (a) caminhos citados no codigo
  final citados = <String, Set<String>>{};
  // Aceita apenas caminho com extensao de arquivo. Sem isso, o padrao casaria
  // com prosa de comentario ("copie assets/... para o build") e com fragmentos
  // montados em tempo de execucao, produzindo alarme falso.
  final padrao = RegExp(r'assets/[A-Za-z0-9_./-]+\.[A-Za-z0-9]{2,5}');
  for (final f in lib.listSync(recursive: true).whereType<File>()) {
    if (!f.path.endsWith('.dart')) continue;
    final relativo = f.path.replaceAll('\\', '/');
    for (final linha in f.readAsLinesSync()) {
      if (_ehComentario(linha)) continue;
      for (final m in padrao.allMatches(linha)) {
        citados.putIfAbsent(m.group(0)!, () => <String>{}).add(relativo);
      }
    }
  }

  // (b) arquivos que existem
  final existentes = assets
      .listSync(recursive: true)
      .whereType<File>()
      .map((f) => 'assets/${f.path.replaceAll('\\', '/').substring(assets.path.replaceAll('\\', '/').length + 1)}')
      .toSet();

  // (c) pastas declaradas no pubspec
  final declaradas = _pastasDeclaradas(pubspec);

  stdout.writeln('citados no codigo : ${citados.length} caminho(s)');
  stdout.writeln('existem em disco  : ${existentes.length} arquivo(s)');
  stdout.writeln('declarados        : ${declaradas.length} pasta(s)');

  final falhas = <String>[];

  _secao('citados no codigo mas AUSENTES do repositorio');
  final ausentes = citados.keys.where((c) => !existentes.contains(c)).toList()
    ..sort();
  if (ausentes.isEmpty) {
    stdout.writeln('  nenhum');
  } else {
    final porPrefixo = <String, List<String>>{};
    for (final a in ausentes) {
      final pasta = a.substring(0, a.lastIndexOf('/') + 1);
      porPrefixo.putIfAbsent(pasta, () => []).add(a);
    }
    for (final entrada in porPrefixo.entries) {
      final tolerado =
          tolerados.any((p) => entrada.key.startsWith(p));
      final marca = tolerado ? 'TOLERADO' : 'FALHA   ';
      stdout.writeln('  $marca ${entrada.key} — ${entrada.value.length} arquivo(s)');
      for (final a in entrada.value.take(3)) {
        stdout.writeln('           $a  (citado em ${citados[a]!.first})');
      }
      if (entrada.value.length > 3) {
        stdout.writeln('           ... e mais ${entrada.value.length - 3}');
      }
      if (!tolerado) {
        falhas.add(
          '${entrada.value.length} asset(s) citados em ${entrada.key} nao existem',
        );
      }
    }
  }

  _secao('existem em disco mas NAO SERAO EMPACOTADOS');
  // Um arquivo entra no bundle se a pasta que o contem estiver declarada.
  // Flutter nao inclui subpasta recursivamente: `assets/ranking/` nao arrasta
  // `assets/ranking/selos/`, e e por isso que a comparacao e por pasta exata.
  final naoEmpacotados = existentes
      .where((f) => !declaradas.contains(f.substring(0, f.lastIndexOf('/') + 1)))
      .toList()
    ..sort();
  if (naoEmpacotados.isEmpty) {
    stdout.writeln('  nenhum');
  } else {
    final pastas = naoEmpacotados
        .map((f) => f.substring(0, f.lastIndexOf('/') + 1))
        .toSet()
        .toList()
      ..sort();
    for (final p in pastas) {
      final n = naoEmpacotados.where((f) => f.startsWith(p)).length;
      final citada = citados.keys.any((c) => c.startsWith(p));
      stdout.writeln('  ${citada ? 'FALHA   ' : 'AVISO   '} $p — $n arquivo(s)'
          '${citada ? ' (E CITADA no codigo)' : ' (nao citada no codigo)'}');
      if (citada) {
        falhas.add('$p tem arquivo citado no codigo e nao esta declarada no pubspec');
      }
    }
  }

  _secao('declarados no pubspec mas INEXISTENTES');
  // A existencia e conferida NO DISCO, e nao contra a varredura de `existentes`.
  //
  // Aquela varredura so enxerga `app/assets/`, o que era suficiente enquanto
  // tudo que o pubspec declarava vivia la. Deixou de ser: o catalogo de colecoes
  // e declarado como `data/colecoes/catalogo.seed.json` — ele nao e arte, e a
  // fonte de dados que `InventarioService` le do bundle, e duplica-lo dentro de
  // `assets/` criaria uma segunda copia do catalogo, que e exatamente o que o
  // modulo evita.
  //
  // Com a checagem antiga, toda declaracao fora de `assets/` era reprovada por
  // definicao: a pasta existia, o build passava, e o portao acusava falha. Ler o
  // disco responde a pergunta que o portao realmente faz — "o `flutter build`
  // vai achar isto?" — para qualquer pasta declarada.
  final declaradasVazias = declaradas
      .where((d) => !_temArquivo(Directory('${app.path}/$d')))
      .toList()
    ..sort();
  if (declaradasVazias.isEmpty) {
    stdout.writeln('  nenhuma');
  } else {
    for (final d in declaradasVazias) {
      stdout.writeln('  FALHA    $d');
      falhas.add('$d declarada no pubspec e nao existe — `flutter build` falha');
    }
  }

  stdout.writeln('\n${'=' * 70}');
  if (falhas.isEmpty) {
    stdout.writeln('PORTAO DE ASSETS APROVADO');
    exit(0);
  }
  stdout.writeln('PORTAO DE ASSETS REPROVADO — ${falhas.length} problema(s):');
  for (final f in falhas) {
    stdout.writeln('  - $f');
  }
  exit(1);
}

/// Linha que é só comentário — `//`, `///` ou corpo de bloco `/* ... */`.
///
/// A varredura pula essas linhas porque comentário não carrega asset: o
/// caminho citado ali é prosa, e o build nunca vai buscá-lo. Sem isso, escrever
/// "removida a tela que carregava assets/splash.jpg" num comentário faz o
/// próprio portão reprovar o commit que corrigiu o problema.
///
/// O corte é por linha INTEIRA, e não por `//` em qualquer posição, de
/// propósito: recortar a partir do primeiro `//` da linha destruiria qualquer
/// URL dentro de string (`'https://...'`) e criaria um alarme falso pior que o
/// que resolve. Referência de asset real nunca mora numa linha que começa com
/// comentário.
bool _ehComentario(String linha) {
  final t = linha.trimLeft();
  return t.startsWith('//') || t.startsWith('*') || t.startsWith('/*');
}

/// Le as linhas do bloco `flutter: assets:` do pubspec.
///
/// Parser proposital de uma linha so, em vez de um pacote de YAML: o bloco tem
/// forma fixa (`    - assets/xxx/`) e nao vale arrastar dependencia por isso.
/// Uma entrada que aponte para arquivo, e nao pasta, e normalizada para a pasta
/// que a contem.
Set<String> _pastasDeclaradas(File pubspec) {
  final linhas = pubspec.readAsLinesSync();
  final pastas = <String>{};
  var dentro = false;
  for (final linha in linhas) {
    final semComentario = linha.split('#').first;
    if (RegExp(r'^\s*assets:\s*$').hasMatch(semComentario)) {
      dentro = true;
      continue;
    }
    if (!dentro) continue;
    final item = RegExp(r'^\s*-\s*(\S+)\s*$').firstMatch(semComentario);
    if (item == null) {
      // Sai do bloco na primeira linha nao vazia que nao seja item de lista.
      if (semComentario.trim().isNotEmpty) dentro = false;
      continue;
    }
    final valor = item.group(1)!;
    pastas.add(valor.endsWith('/')
        ? valor
        : valor.substring(0, valor.lastIndexOf('/') + 1));
  }
  return pastas;
}

/// A pasta existe e tem ao menos um arquivo DIRETO.
///
/// Nao recursivo de proposito: o Flutter tambem nao e. Uma pasta declarada que
/// so contenha subpastas nao empacota nada, e o portao deve dizer isso em vez de
/// dar por boa uma declaracao que nao entrega arquivo nenhum.
bool _temArquivo(Directory pasta) =>
    pasta.existsSync() && pasta.listSync().whereType<File>().isNotEmpty;

void _secao(String t) => stdout.writeln('\n--- $t ---');

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

  String? opcional(String nome) => _mapa[nome];
}
