// analisar_m4.dart — o analisador de CAUSALIDADE do caso M4.
//
// uso:
//   dart --packages=<package_config> scripts/ci/analisar_m4.dart <matriz.dart> <produto.dart>
//
// Escreve JSON em stdout. Sai 0 quando conseguiu analisar; qualquer outra coisa
// — arquivo ausente, fonte com erro de sintaxe, argumento faltando — sai
// diferente de zero, e quem chama trata isso como REPROVAÇÃO, nunca como
// conformidade.
//
// ---------------------------------------------------------------------------
// POR QUE ELE EXISTE, E POR QUE NÃO É UM `grep`
// ---------------------------------------------------------------------------
//
// Contar tokens responde "o texto está lá?". É uma pergunta sobre o arquivo, e
// não sobre a execução. Dá para conservar TODOS os tokens e desligar a
// causalidade:
//
//   * movendo a medição para comentário, para dentro de uma string ou para um
//     helper que ninguém chama;
//   * pondo um `return` antes da afirmação;
//   * calculando `getRect` e a razão, e entregando OUTRA coisa ao `expect`;
//   * medindo de verdade e afirmando, em seguida, uma constante escrita à mão.
//
// Nos quatro casos o `grep` fica verde. O que este utilitário confere é a
// CADEIA: o retângulo real da `ListView` alimenta a razão, a razão é dividida
// pela viewport medida na árvore, e é ESSA razão que chega ao `expect`, contra
// o piso, num ponto do corpo alcançável antes de qualquer retorno.
//
// Ele usa a AST OFICIAL do Dart (`package:analyzer`). Não há lexer artesanal:
// quem separa comentário de linha, comentário de bloco aninhado, string simples,
// dupla, multilinha, crua, interpolação e chave dentro de literal é o parser da
// linguagem — e um lexer de fim de semana erra em todos esses.

import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

void main(List<String> args) {
  if (args.length < 2) {
    stderr.writeln('uso: analisar_m4.dart <matriz.dart> <produto.dart>');
    exit(2);
  }
  final matriz = File(args[0]);
  final produto = File(args[1]);
  if (!matriz.existsSync()) {
    stderr.writeln('matriz ausente: ${args[0]}');
    exit(2);
  }
  if (!produto.existsSync()) {
    stderr.writeln('produto ausente: ${args[1]}');
    exit(2);
  }

  final uMatriz = _analisar(matriz);
  final uProduto = _analisar(produto);

  final constantes = <String, double?>{
    '_fracaoMinimaDaLista': _constante(uMatriz, '_fracaoMinimaDaLista'),
    '_alturaReal': _constante(uMatriz, '_alturaReal'),
    '_alturaDeMedida': _constante(uMatriz, '_alturaDeMedida'),
    '_fracaoMaximaDoCabecalho': _constante(uProduto, '_fracaoMaximaDoCabecalho'),
  };

  final m4 = _AnaliseDeM4(uMatriz).correr();

  stdout.writeln(
    const JsonEncoder.withIndent('  ').convert({
      'ok': true,
      'constantes': constantes,
      'm4': m4,
    }),
  );
  exit(0);
}

CompilationUnit _analisar(File f) {
  final r = parseString(content: f.readAsStringSync(), throwIfDiagnostics: false);
  final erros = r.errors.where((e) => e.severity.name == 'ERROR').toList();
  if (erros.isNotEmpty) {
    // Fonte que não parseia NÃO é conformidade: é reprovação.
    stderr.writeln('erro de sintaxe em ${f.path}: ${erros.first}');
    exit(3);
  }
  return r.unit;
}

/// O valor de uma constante de topo `const ... nome = <numero>;`.
double? _constante(CompilationUnit u, String nome) {
  for (final d in u.declarations) {
    if (d is! TopLevelVariableDeclaration) continue;
    for (final v in d.variables.variables) {
      if (v.name.lexeme != nome) continue;
      final i = v.initializer;
      if (i is DoubleLiteral) return i.value;
      if (i is IntegerLiteral) return i.value?.toDouble();
    }
  }
  return null;
}

/// O prefixo literal de um nome de caso, com as interpolações fora.
String _textoLiteral(Expression e) {
  if (e is SimpleStringLiteral) return e.value;
  if (e is AdjacentStrings) return e.strings.map(_textoLiteral).join();
  if (e is StringInterpolation) {
    return e.elements.whereType<InterpolationString>().map((s) => s.value).join();
  }
  return '';
}

class _Chamadas extends RecursiveAstVisitor<void> {
  _Chamadas(this.nome);
  final String nome;
  final achadas = <MethodInvocation>[];
  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == nome) achadas.add(node);
    super.visitMethodInvocation(node);
  }
}

List<MethodInvocation> _chamadas(AstNode raiz, String nome) {
  final v = _Chamadas(nome);
  raiz.accept(v);
  return v.achadas;
}

/// A fonte de um nó, sem espaço redundante — só para o relatório.
String _fonte(AstNode n) => n.toSource();

class _AnaliseDeM4 {
  _AnaliseDeM4(this.unidade);
  final CompilationUnit unidade;

  Map<String, Object?> correr() {
    // 1. O SÍTIO. `testWidgets(` como CHAMADA de verdade — um texto igual
    //    dentro de comentário ou de string não é `MethodInvocation`, e por isso
    //    não aparece aqui.
    final sitios = _chamadas(unidade, 'testWidgets')
        .where((c) =>
            c.argumentList.arguments.isNotEmpty &&
            _textoLiteral(c.argumentList.arguments.first).trimLeft().startsWith('M4 —'))
        .toList();

    if (sitios.isEmpty) {
      return {'encontrado': false, 'motivo': 'nenhum sitio testWidgets com nome iniciando em "M4 —"'};
    }
    if (sitios.length > 1) {
      // Um segundo `testWidgets` isca, com o mesmo prefixo, tornaria ambíguo
      // qual deles decide. Isso é reprovação, e não escolha do primeiro.
      return {
        'encontrado': false,
        'motivo': '${sitios.length} sitios testWidgets com nome iniciando em "M4 —"',
      };
    }

    final sitio = sitios.single;
    final nome = _textoLiteral(sitio.argumentList.arguments.first);
    final args = sitio.argumentList.arguments;
    if (args.length < 2) {
      return {'encontrado': false, 'motivo': 'o sitio de M4 nao tem corpo'};
    }
    final corpo = args[1];
    if (corpo is! FunctionExpression) {
      return {'encontrado': false, 'motivo': 'o segundo argumento de M4 nao e uma funcao'};
    }
    final bloco = corpo.body;
    if (bloco is! BlockFunctionBody) {
      return {'encontrado': false, 'motivo': 'o corpo de M4 nao e um bloco'};
    }

    // 2. A CADEIA, procurada primeiro no corpo e, se preciso, dentro de um
    //    helper que M4 COMPROVADAMENTE chama. Fatorar a medição num auxiliar
    //    chamado é refatoração legítima; helper declarado e nunca chamado, não.
    final r = _cadeia(bloco.block.statements, nome, null);
    if (r['cadeiaCompleta'] != true) {
      for (final chamada in _todasAsChamadas(bloco)) {
        final f = _funcaoDeTopo(chamada);
        if (f == null) continue;
        final fb = f.functionExpression.body;
        if (fb is! BlockFunctionBody) continue;
        final alt = _cadeia(fb.block.statements, nome, f.name.lexeme);
        if (alt['cadeiaCompleta'] == true) return alt;
      }
    }
    return r;
  }

  List<MethodInvocation> _todasAsChamadas(AstNode raiz) {
    final v = _TodasAsChamadas();
    raiz.accept(v);
    return v.achadas;
  }

  FunctionDeclaration? _funcaoDeTopo(MethodInvocation chamada) {
    if (chamada.target != null) return null;
    for (final d in unidade.declarations) {
      if (d is FunctionDeclaration && d.name.lexeme == chamada.methodName.name) return d;
    }
    return null;
  }

  Map<String, Object?> _cadeia(
    List<Statement> instrucoes,
    String nome,
    String? viaHelper,
  ) {
    String? listaVar;
    String? viewportVar;
    String? fracaoVar;
    String? fonteDaLista;
    String? fonteDaViewport;
    String? fonteDaFracao;

    for (final s in instrucoes) {
      if (s is! VariableDeclarationStatement) continue;
      for (final v in s.variables.variables) {
        final ini = v.initializer;
        if (ini == null) continue;

        // a lista, pelo RETÂNGULO REAL
        if (listaVar == null && _mede(ini, 'getRect', 'ListView')) {
          listaVar = v.name.lexeme;
          fonteDaLista = _fonte(ini);
          continue;
        }
        // a viewport, MEDIDA NA ÁRVORE
        if (viewportVar == null && _mede(ini, 'getSize', null)) {
          viewportVar = v.name.lexeme;
          fonteDaViewport = _fonte(ini);
          continue;
        }
        // a razão entre as duas
        if (fracaoVar == null &&
            listaVar != null &&
            viewportVar != null &&
            _ehRazao(ini, listaVar, viewportVar)) {
          fracaoVar = v.name.lexeme;
          fonteDaFracao = _fonte(ini);
        }
      }
    }

    // 3. O `expect` QUE CONSOME A RAZÃO — e não outra coisa parecida.
    var indiceDoExpect = -1;
    String? matcher;
    String? piso;
    for (var i = 0; i < instrucoes.length; i++) {
      final s = instrucoes[i];
      if (s is! ExpressionStatement) continue;
      final e = s.expression;
      if (e is! MethodInvocation || e.methodName.name != 'expect') continue;
      final a = e.argumentList.arguments;
      if (a.isEmpty) continue;
      final primeiro = a.first;
      if (fracaoVar == null || primeiro is! SimpleIdentifier || primeiro.name != fracaoVar) {
        continue;
      }
      indiceDoExpect = i;
      if (a.length > 1) {
        final m = a[1];
        if (m is MethodInvocation) {
          matcher = m.methodName.name;
          if (m.argumentList.arguments.isNotEmpty) {
            piso = _fonte(m.argumentList.arguments.first);
          }
        }
      }
      break;
    }

    // 4. ALCANÇABILIDADE. Só instruções de PROFUNDIDADE ZERO deste bloco: um
    //    `return` dentro de uma closure interna é instrução de OUTRO bloco, e a
    //    AST já o entrega separado — é por isso que a análise não confunde os
    //    dois.
    var indiceDoRetorno = -1;
    for (var i = 0; i < instrucoes.length; i++) {
      final s = instrucoes[i];
      if (s is ReturnStatement) { indiceDoRetorno = i; break; }
      if (s is ExpressionStatement && s.expression is ThrowExpression) { indiceDoRetorno = i; break; }
    }

    // 5. COM QUE ALTURA M4 MONTA. Trocar `_alturaReal` pela superfície de
    //    medida de 2000 faria a lista caber com folga e a prova ficaria verde
    //    sem provar nada sobre telefone nenhum.
    String? alturaMontada;
    for (final s in instrucoes) {
      for (final c in _todasAsChamadas(s)) {
        if (c.methodName.name != 'montar') continue;
        for (final a in c.argumentList.arguments) {
          if (a is NamedExpression && a.name.label.name == 'altura') {
            alturaMontada = _fonte(a.expression);
          }
        }
      }
    }

    // 6. A afirmação que amarra a superfície ao telefone contratado.
    var afirmaViewport = false;
    for (final s in instrucoes) {
      if (s is! ExpressionStatement) continue;
      final e = s.expression;
      if (e is! MethodInvocation || e.methodName.name != 'expect') continue;
      final a = e.argumentList.arguments;
      if (a.isEmpty) continue;
      final p = a.first;
      if (viewportVar != null && p is SimpleIdentifier && p.name == viewportVar) {
        afirmaViewport = true;
      }
    }

    final alcancavel = indiceDoExpect >= 0 &&
        (indiceDoRetorno < 0 || indiceDoExpect < indiceDoRetorno);

    return {
      'encontrado': true,
      'nome': nome,
      'viaHelper': viaHelper,
      'listaVar': listaVar,
      'fonteDaLista': fonteDaLista,
      'viewportVar': viewportVar,
      'fonteDaViewport': fonteDaViewport,
      'fracaoVar': fracaoVar,
      'fonteDaFracao': fonteDaFracao,
      'expectRecebeAFracao': indiceDoExpect >= 0,
      'matcher': matcher,
      'piso': piso,
      'alturaMontada': alturaMontada,
      'afirmaViewportContratada': afirmaViewport,
      'indiceDoExpect': indiceDoExpect,
      'indiceDoRetorno': indiceDoRetorno,
      'alcancavel': alcancavel,
      'cadeiaCompleta': listaVar != null &&
          viewportVar != null &&
          fracaoVar != null &&
          indiceDoExpect >= 0 &&
          alcancavel &&
          afirmaViewport,
    };
  }

  /// [e] é uma medição real — `tester.getRect(find.byType(X))` — e não um
  /// número escrito à mão?
  bool _mede(Expression e, String metodo, String? tipo) {
    final chamadas = _todasAsChamadas(e).where((c) => c.methodName.name == metodo);
    if (chamadas.isEmpty) return false;
    if (tipo == null) return true;
    for (final c in chamadas) {
      final porTipo = _todasAsChamadas(c).where((x) => x.methodName.name == 'byType');
      for (final t in porTipo) {
        final a = t.argumentList.arguments;
        if (a.isNotEmpty && _fonte(a.first) == tipo) return true;
      }
    }
    return false;
  }

  /// [e] é `<algo derivado de lista> / <viewport>`?
  bool _ehRazao(Expression e, String listaVar, String viewportVar) {
    if (e is! BinaryExpression || e.operator.lexeme != '/') return false;
    final esq = _fonte(e.leftOperand);
    final dir = _fonte(e.rightOperand);
    return esq.startsWith('$listaVar.') && dir == viewportVar;
  }
}

class _TodasAsChamadas extends RecursiveAstVisitor<void> {
  final achadas = <MethodInvocation>[];
  @override
  void visitMethodInvocation(MethodInvocation node) {
    achadas.add(node);
    super.visitMethodInvocation(node);
  }
}
