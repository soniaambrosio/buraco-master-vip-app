// auditoria_identidade_test.dart — a prova ESTRUTURAL (§19 e caso N).
//
// Os outros dois arquivos provam COMPORTAMENTO: dado um estado, o que acontece.
// Este prova AUSÊNCIA: que não existe, em lugar nenhum do cliente, uma fórmula
// local de `publicId`, um fallback para `uid` ou uma chamada à callable
// aposentada.
//
// POR QUE UM TESTE, E NÃO UM `grep` NO FECHAMENTO. Um grep prova o dia em que
// foi rodado. Este arquivo roda no CI junto com o resto, então a proibição
// continua valendo depois que esta OS fechar — que é a única forma de uma regra
// arquitetural sobreviver a refatorações futuras.
//
// ---------------------------------------------------------------------------
// A FRONTEIRA QUE ESTA AUDITORIA RESPEITA: `lib/social/` NÃO É CLIENTE
// ---------------------------------------------------------------------------
//
// `app/lib/social/` é o domínio das Cloud Functions sociais escrito em Dart e
// compilado para JS (`dart compile js -o functions-social/lib/domain_bundle.js
// app/lib/social/js_bridge.dart`). É código de SERVIDOR que mora nesta pasta.
// É lá que vive `idPublicoDeBytes`, o gerador — e ele é a AUTORIDADE, não uma
// cópia local dela.
//
// O teste `lib/social não é alcançável pelo app` abaixo é o que sustenta essa
// afirmação: se algum dia uma tela importar aquele domínio, a fronteira quebra
// e a auditoria falha, em vez de o comentário envelhecer em silêncio.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Arquivos `.dart` do CLIENTE — tudo em `lib/`, menos o bundle do servidor.
List<File> _fontesDoCliente() =>
    Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) => !_ehBundleDoServidor(f.path))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

bool _ehBundleDoServidor(String caminho) {
  final n = caminho.replaceAll(r'\', '/');
  // `lib/social/` compila para as Functions; `lib/moderacao/` e `lib/torneios/`
  // fazem o mesmo por seus próprios bridges. Nenhum deles é executado no app.
  return n.contains('/social/') || n.endsWith('js_bridge.dart');
}

String _texto(File f) => f.readAsStringSync();

/// O arquivo SEM comentários.
///
/// Auditoria que lê comentário se auto-sabota: este próprio módulo explica, em
/// prosa, por que `garantirIdentidadePublica` não pode ser chamada — e uma
/// varredura ingênua acusaria essa explicação como violação. Pior: o jeito de
/// "consertar" seria apagar a documentação, deixando a regra sem motivo escrito.
///
/// O que interessa é o CÓDIGO. O varredor abaixo derruba `//` e `/* */`
/// respeitando aspas, para que uma `//` dentro de string literal (uma URL, por
/// exemplo) não seja confundida com início de comentário.
String _codigo(File f) {
  final fonte = _texto(f);
  final saida = StringBuffer();
  var i = 0;
  String? aspa; // a aspa que abriu a string corrente, ou null fora de string
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
      while (i < fonte.length &&
          !(fonte[i] == '*' && i + 1 < fonte.length && fonte[i + 1] == '/')) {
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

void main() {
  late List<File> cliente;

  setUpAll(() {
    cliente = _fontesDoCliente();
    // Se a varredura não achou nada, o teste inteiro seria um verde falso.
    expect(cliente, isNotEmpty, reason: 'a auditoria precisa ter o que ler');
  });

  // =========================================================================
  // §14 — a callable aposentada
  // =========================================================================
  group('§14 — garantirIdentidadePublica', () {
    test('nenhum arquivo Dart do app a menciona', () {
      final ocorrencias = <String>[];
      for (final f in _fontesDoCliente()) {
        if (_codigo(f).contains('garantirIdentidadePublica')) {
          ocorrencias.add(f.path);
        }
      }
      expect(
        ocorrencias,
        isEmpty,
        reason:
            'a callable foi removida do backend e não tem substituto '
            'local; qualquer menção aqui é dependência de código morto',
      );
    });

    test('nenhum verbo de criação de identidade existe no cliente', () {
      // A OS proíbe também o wrapper renomeado. Estes são os nomes que uma
      // "garantia" disfarçada tenderia a assumir.
      const proibidos = [
        'garantirIdentidade',
        'criarIdentidadePublica',
        'inicializarIdentidade',
        'assegurarIdentidade',
      ];
      final achados = <String>[];
      for (final f in _fontesDoCliente()) {
        final conteudo = _codigo(f);
        for (final termo in proibidos) {
          if (conteudo.contains(termo)) achados.add('${f.path}: $termo');
        }
      }
      expect(achados, isEmpty);
    });
  });

  // =========================================================================
  // CASO N — nenhum publicId calculado localmente
  // =========================================================================
  group('CASO N — publicId não é calculado no cliente', () {
    test('o cliente não conhece alfabeto, comprimento nem prefixo do id', () {
      // As três constantes que compõem a fórmula do servidor. Se qualquer uma
      // aparecer no cliente, existe uma fórmula local — ainda que ninguém a
      // chame hoje.
      const marcasDaFormula = [
        'kAlfabetoIdPublico',
        'kComprimentoIdPublico',
        'kPrefixoIdPublico',
        'idPublicoDeBytes',
        '0123456789ABCDEFGHJKMNPQRSTVWXYZ',
      ];
      final achados = <String>[];
      for (final f in _fontesDoCliente()) {
        final conteudo = _codigo(f);
        for (final marca in marcasDaFormula) {
          if (conteudo.contains(marca)) achados.add('${f.path}: $marca');
        }
      }
      expect(
        achados,
        isEmpty,
        reason:
            'a fórmula é do servidor; o cliente trata publicId como '
            'string opaca',
      );
    });

    test('lib/social (o bundle das Functions) não é alcançável pelo app', () {
      // A prova de que o gerador que existe em `lib/social/identidade_publica
      // .dart` é código de SERVIDOR: nenhum arquivo do cliente o importa. Se
      // um dia importar, este teste cai — e é para cair.
      final importadores = <String>[];
      for (final f in _fontesDoCliente()) {
        final conteudo = _codigo(f);
        final importaSocial = RegExp(
          r'''import\s+['"][^'"]*social/[^'"]*\.dart['"]''',
        ).hasMatch(conteudo);
        if (importaSocial) importadores.add(f.path);
      }
      expect(
        importadores,
        isEmpty,
        reason:
            'o domínio social compila para as Functions; puxá-lo para o '
            'app traria a fórmula de geração junto',
      );
    });

    test('o gerador do servidor continua existindo onde deve', () {
      // O contrapeso do teste acima: a auditoria não pode passar por o arquivo
      // ter sido apagado. §15 proíbe mexer no backend, e o gerador é backend.
      final dominio = File('lib/social/identidade_publica.dart');
      expect(dominio.existsSync(), isTrue);
      expect(dominio.readAsStringSync(), contains('idPublicoDeBytes'));
    });
  });

  // =========================================================================
  // CASO M / §19 — nenhum fallback silencioso para uid
  // =========================================================================
  group('CASO M — nenhum fallback publicId → uid', () {
    test('não existe `publicId ?? uid` nem suas variantes', () {
      // Os padrões que §19 nomeia, mais os equivalentes por operador ternário.
      final padroes = <RegExp>[
        RegExp(r'publicId\s*\?\?\s*\w*[Uu]id'),
        RegExp(r'publicId[^\n]{0,40}\.isEmpty\s*\?\s*\w*[Uu]id'),
        RegExp(r'publicId\s*==\s*null\s*\?\s*\w*[Uu]id'),
        RegExp(r'[Uu]id\s+as\s+publicId'),
        RegExp(r'publicId\s*[:=]\s*\w*[Uu]id\b'),
      ];
      final achados = <String>[];
      for (final f in _fontesDoCliente()) {
        final conteudo = _codigo(f);
        for (final p in padroes) {
          final m = p.firstMatch(conteudo);
          if (m != null) achados.add('${f.path}: ${m.group(0)}');
        }
      }
      expect(achados, isEmpty);
    });

    test('a camada de sessão não menciona uid como valor de identidade', () {
      // `sessao_do_jogador.dart` e o estado guardam o uid (precisam saber de
      // QUEM é a sessão), mas o `publicId` nunca é lido dele. A checagem é
      // sobre o getter: ele só devolve `identidade?.publicId`.
      final estado = File(
        'lib/sessao/identidade_publica_sessao.dart',
      ).readAsStringSync();
      final getter = RegExp(
        r'String\?\s+get\s+publicId\s*=>([\s\S]{0,160}?);',
      ).firstMatch(estado);
      expect(getter, isNotNull, reason: 'o getter canônico precisa existir');
      expect(getter!.group(1), isNot(contains('uid')));
    });
  });

  // =========================================================================
  // §8 — nenhuma persistência nova de identidade
  // =========================================================================
  group('§8 — cache só em memória', () {
    test('a camada de sessão não usa armazenamento persistente', () {
      const persistencias = [
        'shared_preferences',
        'SharedPreferences',
        'sqflite',
        'Hive',
        'File(',
        'localStorage',
      ];
      final achados = <String>[];
      for (final f in Directory(
        'lib/sessao',
      ).listSync(recursive: true).whereType<File>()) {
        final conteudo = _codigo(f);
        for (final termo in persistencias) {
          if (conteudo.contains(termo)) achados.add('${f.path}: $termo');
        }
      }
      expect(
        achados,
        isEmpty,
        reason:
            'persistir identidade criaria uma segunda fonte de verdade '
            'com política de invalidação não especificada',
      );
    });
  });

  // =========================================================================
  // §4 — a entrada canônica
  // =========================================================================
  group('§4 — obterMinhaIdentidade é a entrada única', () {
    test('a callable é nomeada em um só lugar do cliente', () {
      final arquivos = <String>[];
      for (final f in _fontesDoCliente()) {
        if (_codigo(f).contains("'obterMinhaIdentidade'")) {
          arquivos.add(f.path.replaceAll(r'\', '/'));
        }
      }
      expect(arquivos, hasLength(1));
      expect(
        arquivos.single,
        endsWith('lib/sessao/fonte_identidade_firebase.dart'),
      );
    });

    test(
      'só o adaptador da sessão conhece cloud_functions para identidade',
      () {
        // `colecoes/colecao_firebase.dart` também usa cloud_functions, para o
        // resgate do Kit Pioneiros — outro assunto. O que importa aqui é que
        // nenhuma TELA chame Functions de identidade por conta própria.
        final telas = _fontesDoCliente().where((f) {
          final n = f.path.replaceAll(r'\', '/');
          return n.contains('/screens/') || n.contains('/pages/');
        });
        final achados = <String>[];
        for (final f in telas) {
          final conteudo = _codigo(f);
          if (conteudo.contains('httpsCallable') ||
              conteudo.contains('cloud_functions')) {
            achados.add(f.path);
          }
        }
        expect(achados, isEmpty);
      },
    );
  });

  // =========================================================================
  // §16 / §20 — a chamada não nasce de lifecycle de tela
  // =========================================================================
  group('§16 — a identidade não é efeito colateral de tela', () {
    test('nenhuma tela chama obterMinhaIdentidade, recarregar ou garantir', () {
      final achados = <String>[];
      for (final f in _fontesDoCliente()) {
        final n = f.path.replaceAll(r'\', '/');
        if (!n.contains('/screens/') && !n.contains('/pages/')) continue;
        final conteudo = _codigo(f);
        for (final termo in ['obterMinhaIdentidade', 'garantirCarregada']) {
          if (conteudo.contains(termo)) achados.add('$n: $termo');
        }
      }
      expect(
        achados,
        isEmpty,
        reason: 'telas consomem o estado; quem o busca é a sessão',
      );
    });

    test('o gatilho está na camada de sessão, e é o fluxo de autenticação', () {
      final controller = _codigo(File('lib/sessao/sessao_do_jogador.dart'));
      // O disparo pendura no stream de uids, não num lifecycle de widget.
      expect(controller, contains('uids.listen(_aplicarSessao)'));
      expect(controller, isNot(contains('initState')));
      expect(controller, isNot(contains('didChangeDependencies')));

      final montagem = _codigo(File('lib/sessao/sessao_firebase.dart'));
      expect(montagem, contains('authStateChanges()'));
    });
  });
}
