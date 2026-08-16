// auditoria_mesa_online_test.dart — a prova de AUSÊNCIA da mesa online.
//
// A suíte irmã (`mesa_online_test.dart`) prova comportamento: dado um estado, o
// que a tela faz. Esta prova o que NÃO existe, e persegue quatro coisas que
// voltariam sozinhas na primeira refatoração distraída:
//
//   * um motor local por baixo da conexão online — `Jogo` instanciado no
//     caminho do servidor, que é o híbrido silencioso que a OS proíbe;
//   * um segundo dono de autenticação (`FirebaseAuth` numa tela);
//   * um log de diagnóstico onde passam ids de carta e recusas do servidor que
//     citam carta;
//   * a divergência da arte entre o treino e o online.
//
// POR QUE UM TESTE, E NÃO UM `grep` NO FECHAMENTO. Um grep prova o dia em que
// foi rodado. Este arquivo roda no CI junto com o resto, então a proibição
// continua valendo depois que esta OS fechar.
//
// A técnica de despojar comentários antes de varrer é a de
// `auditoria_casca_test.dart`, e pelo mesmo motivo: uma auditoria que lê
// comentário se auto-sabota. Os módulos aqui EXPLICAM, em prosa, que não
// aplicam jogada local — e uma varredura ingênua acusaria a explicação como
// violação. Pior: o jeito de "consertar" seria apagar a documentação.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// ===========================================================================
// Ferramentas
// ===========================================================================

/// O arquivo SEM comentários, respeitando aspas para que uma `//` dentro de
/// string literal não seja confundida com início de comentário.
String _codigo(File f) {
  final fonte = f.readAsStringSync();
  final saida = StringBuffer();
  var i = 0;
  String? aspa;
  while (i < fonte.length) {
    final c = fonte[i];
    final proximo = i + 1 < fonte.length ? fonte[i + 1] : '';

    if (aspa != null) {
      saida.write(c);
      if (c == r'\') {
        if (proximo.isNotEmpty) saida.write(proximo);
        i += 2;
        continue;
      }
      if (c == aspa) aspa = null;
      i++;
      continue;
    }

    if (c == '/' && proximo == '/') {
      while (i < fonte.length && fonte[i] != '\n') {
        i++;
      }
      continue;
    }
    if (c == '/' && proximo == '*') {
      i += 2;
      while (i + 1 < fonte.length && !(fonte[i] == '*' && fonte[i + 1] == '/')) {
        i++;
      }
      i += 2;
      continue;
    }
    if (c == "'" || c == '"') aspa = c;
    saida.write(c);
    i++;
  }
  return saida.toString();
}

/// Os arquivos que compõem a superfície online desta OS.
List<File> _arquivosDaMesaOnline() {
  final dir = Directory('lib/casca/mesa_online');
  expect(
    dir.existsSync(),
    isTrue,
    reason: 'a pasta da mesa online tem de existir para ser auditada',
  );
  return [
    ...dir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart')),
    File('lib/casca/lobby_online.dart'),
  ];
}

String _nome(File f) => f.path.replaceAll(r'\', '/');

/// Uma construção `Tipo(` que NÃO é o final de um nome maior.
///
/// A borda importa: sem ela, `VisaoDeJogo(` — que é o resultado da LEITURA da
/// visão, e a coisa mais distante possível de um motor local — acusaria a
/// construção de `Jogo(`. Uma auditoria que dá alarme falso é desligada, e aí
/// não audita mais nada.
RegExp _constroi(String tipo) =>
    RegExp('(^|[^A-Za-z0-9_])$tipo\\(', multiLine: true);

void main() {
  // =========================================================================
  // 1 — nenhum motor local por baixo do online
  // =========================================================================
  group('não existe partida local sob a conexão online', () {
    test('nada no caminho online constrói um Jogo', () {
      for (final f in _arquivosDaMesaOnline()) {
        final codigo = _codigo(f);
        expect(
          _constroi('Jogo').hasMatch(codigo),
          isFalse,
          reason:
              '${_nome(f)} instancia o motor local. Em partida online o '
              'servidor é a autoridade: um segundo baralho aqui é o híbrido '
              'silencioso — a pessoa acha que joga contra gente e joga contra '
              'o próprio aparelho.',
        );
        expect(
          _constroi('MotorPartida').hasMatch(codigo),
          isFalse,
          reason: '${_nome(f)} instancia o motor canônico',
        );
      }
    });

    test('a mesa online não importa o módulo da partida local', () {
      for (final f in _arquivosDaMesaOnline()) {
        final codigo = _codigo(f);
        for (final proibido in const [
          "import '../../mesa.dart'",
          "import '../mesa.dart'",
          "package:buraco_master_vip/mesa.dart",
          "import '../../motor/",
          "import '../motor/",
        ]) {
          expect(
            codigo.contains(proibido),
            isFalse,
            reason: '${_nome(f)} importa $proibido',
          );
        }
      }
    });
  });

  // =========================================================================
  // 2 — um dono só de autenticação
  // =========================================================================
  test('nenhuma tela da mesa online observa autenticação por conta própria', () {
    for (final f in _arquivosDaMesaOnline()) {
      final codigo = _codigo(f);
      for (final proibido in const [
        'FirebaseAuth',
        'firebase_auth',
        'authStateChanges',
        'GoogleSignIn',
      ]) {
        expect(
          codigo.contains(proibido),
          isFalse,
          reason:
              '${_nome(f)} menciona $proibido. Quem observa a sessão e traduz '
              'cada troca numa transição do transporte é a PonteSessaoOnline, '
              'montada na raiz — uma tela com opinião própria sobre quem está '
              'logado é um segundo dono de credencial.',
        );
      }
    }
  });

  // =========================================================================
  // 3 — nada é registrado
  // =========================================================================
  test('a mesa online não registra nada em log', () {
    for (final f in _arquivosDaMesaOnline()) {
      final codigo = _codigo(f);
      for (final proibido in const [
        'print(',
        'debugPrint(',
        'log(',
        'developer.log',
      ]) {
        expect(
          codigo.contains(proibido),
          isFalse,
          reason:
              '${_nome(f)} registra em log. Por esta camada passam ids de '
              'carta — que são a mão da pessoa — e recusas do servidor que '
              'citam carta ("o topo é o X"). Um log de diagnóstico aqui é a '
              'mão inteira num arquivo.',
        );
      }
    }
  });

  // =========================================================================
  // 4 — a arte não pode divergir do treino
  // =========================================================================
  group('a arte das cartas', () {
    /// Todo caminho de `assets/baralho/` citado num arquivo.
    Set<String> caminhos(File f) => RegExp(r"assets/baralho/[^']*")
        .allMatches(f.readAsStringSync())
        .map((m) => m.group(0)!)
        .toSet();

    test('a convenção do online é a mesma do treino', () {
      final doTreino = caminhos(File('lib/mesa.dart'));
      final doOnline = caminhos(File('lib/casca/mesa_online/arte_das_cartas.dart'));

      // A extração dessas funções para um módulo comum não foi feita nesta OS:
      // `lib/mesa.dart` tem três mil e quatrocentas linhas e é a única
      // superfície de jogo que funciona de ponta a ponta hoje. O preço dessa
      // decisão é a divergência, e é este caso que a cobra.
      expect(
        doOnline.difference(doTreino),
        isEmpty,
        reason:
            'o online passou a usar arte que o treino não conhece — as duas '
            'convenções divergiram. Ver o cabeçalho de arte_das_cartas.dart.',
      );

      // O treino usa um dorso a mais (`dorso_publico`) que a mesa online não
      // desenha. É diferença legítima e conhecida; qualquer OUTRA sobra
      // significa que o treino ganhou arte nova e o online ficou para trás.
      expect(
        doTreino.difference(doOnline),
        {'assets/baralho/dorso_publico.webp'},
        reason:
            'a lista de arte do treino mudou. Confira se a mesa online deve '
            'acompanhar.',
      );
    });

    test('toda arte de carta referenciada existe no repositório', () {
      const naipes = ['copas', 'ouros', 'paus', 'espadas'];
      const valores = [
        'A', '2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K',
      ];
      final faltando = <String>[];
      for (final n in naipes) {
        for (final v in valores) {
          final caminho = 'assets/baralho/${n}_$v.webp';
          if (!File(caminho).existsSync()) faltando.add(caminho);
        }
      }
      for (final fixa in const [
        'assets/baralho/dorso.webp',
        'assets/baralho/joker.webp',
        'assets/baralho/joker2.webp',
      ]) {
        if (!File(fixa).existsSync()) faltando.add(fixa);
      }
      expect(faltando, isEmpty);
    });

    test('a pasta da arte está declarada no pubspec', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(
        pubspec.contains('assets/baralho/'),
        isTrue,
        reason:
            'sem a declaração, o build sai sem as cartas e a mesa desenha o '
            'texto de emergência em vez da arte',
      );
    });
  });

  // =========================================================================
  // 5 — a leitura da visão é uma porta só
  // =========================================================================
  test('só o adaptador lê a visão crua', () {
    // A tela recebe `EstadoMesaOnline` pronto. Se ela voltar a indexar o mapa
    // do servidor por conta própria, volta junto o `?? 0` que inventa placar.
    final tela = _codigo(File('lib/casca/mesa_online/mesa_online_screen.dart'));
    for (final proibido in const [
      "['suaMao']",
      "['placar']",
      "['assentos']",
      "['voceAssento']",
      "['jogosDupla']",
      'srv.visao',
      'online.visao',
    ]) {
      expect(
        tela.contains(proibido),
        isFalse,
        reason: 'mesa_online_screen.dart lê a visão crua em $proibido',
      );
    }
  });
}
