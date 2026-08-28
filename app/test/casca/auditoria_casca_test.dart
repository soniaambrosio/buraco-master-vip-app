// auditoria_casca_test.dart — a prova de AUSÊNCIA.
//
// A suíte irmã prova comportamento: dado um estado, o que a casca faz. Esta
// prova o que NÃO existe — e existe porque as três coisas que ela persegue já
// estiveram no código e voltariam sozinhas na primeira refatoração distraída:
//
//   * um segundo dono de autenticação (uma tela chamando `FirebaseAuth` ou
//     `GoogleSignIn` por conta própria);
//   * uma rota de produção que alcança maquete;
//   * dado pessoal de uma pessoa real escrito no código distribuído.
//
// POR QUE UM TESTE, E NÃO UM `grep` NO FECHAMENTO. Um grep prova o dia em que
// foi rodado. Este arquivo roda no CI junto com o resto, então a proibição
// continua valendo depois que esta OS fechar.
//
// A técnica de despojar comentários antes de varrer é a mesma de
// `sessao/auditoria_identidade_test.dart`, e pelo mesmo motivo: uma auditoria
// que lê comentário se auto-sabota. Este próprio módulo explica, em prosa, o
// que é proibido — e uma varredura ingênua acusaria a explicação como violação.
// Pior: o jeito de "consertar" seria apagar a documentação.

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

// ===========================================================================
// Ferramentas
// ===========================================================================

String _barras(String caminho) => caminho.replaceAll(r'\', '/');

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

/// Junta um caminho relativo ao diretório de quem importa, resolvendo `..`.
String _resolver(String deQuem, String importado) {
  if (importado.startsWith('package:buraco_master_vip/')) {
    return 'lib/${importado.substring('package:buraco_master_vip/'.length)}';
  }
  final base = _barras(deQuem).split('/')..removeLast();
  for (final parte in importado.split('/')) {
    if (parte == '.' || parte.isEmpty) continue;
    if (parte == '..') {
      if (base.isNotEmpty) base.removeLast();
      continue;
    }
    base.add(parte);
  }
  return base.join('/');
}

final RegExp _import = RegExp(r'''import\s+['"]([^'"]+)['"]''');

/// O fecho transitivo dos imports a partir de `lib/main.dart`.
///
/// É ISTO que "alcançável pela raiz de produção" significa nesta auditoria:
/// não o que existe em `lib/`, e sim o que o binário publicado consegue chegar
/// a executar partindo de `main()`.
Set<String> _alcancaveisDaRaiz() {
  final vistos = <String>{};
  final fila = <String>['lib/main.dart'];
  while (fila.isNotEmpty) {
    final atual = fila.removeLast();
    if (!vistos.add(atual)) continue;
    final f = File(atual);
    if (!f.existsSync()) continue;
    for (final m in _import.allMatches(_codigo(f))) {
      final alvo = m.group(1)!;
      // Pacotes externos (`package:flutter/...`) e `dart:` não são nossos.
      if (alvo.startsWith('dart:')) continue;
      if (alvo.startsWith('package:') &&
          !alvo.startsWith('package:buraco_master_vip/')) {
        continue;
      }
      fila.add(_resolver(atual, alvo));
    }
  }
  return vistos;
}

/// Todos os `.dart` do cliente — tudo em `lib/`, menos os bundles que compilam
/// para as Cloud Functions e nunca rodam no aplicativo.
List<File> _fontesDoCliente() =>
    Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) {
          final n = _barras(f.path);
          return !n.contains('/social/') &&
              !n.contains('/moderacao/') &&
              !n.endsWith('js_bridge.dart');
        })
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

// ===========================================================================
// FONTE ÚNICA DE GATES — o que o portão `a11yterm` é, declarado num lugar só
// ===========================================================================
//
// POR QUE AQUI, E NÃO NUM ARQUIVO NOVO.
//
// Este arquivo já é a autoridade que diz o que TEM de existir na casca, já roda
// num gate obrigatório dos dois portões, e já carrega o mesmo contrato para a
// suíte do Perfil visitado. Uma segunda fonte de gates seria uma segunda
// verdade: no dia em que as duas divergissem, nenhuma seria autoridade.
//
// O que estas constantes declaram — e o grupo lá embaixo cobra — é a
// identidade inteira do gate: caminho, nome, piso, os nomes dos casos, a
// origem deles, quem os executa, que marcador deixam, que log produzem e em
// que listas dos dois workflows o gate aparece.

/// O caminho canônico da suíte protegida, a partir da raiz do app.
const String kCaminhoA11yTerm = 'test/casca/a11y_estados_terminais_test.dart';

/// O identificador do gate nos dois portões.
const String kGateA11yTerm = 'a11yterm';

/// O identificador da TESTEMUNHA — o passo que lê o resultado real.
const String kGateA11yTermAtestado = 'a11ytermat';

/// O identificador da AUTORIDADE EXTERNA — o passo que lê a cadeia inteira.
const String kGateA11yTermAutoridade = 'a11yaut';

/// O manifesto da cadeia, a partir da raiz do repositório.
///
/// OS 20-C2. Ele é a SEGUNDA NATUREZA do contrato: dados, não programa, e lido
/// por um verificador que não é Dart e não roda no executor do Flutter. É nele
/// que mora a obrigação material de cada um dos vinte e um casos homologados —
/// as operações que cada um exercita e os resultados que observa.
///
/// POR QUE OBRIGAÇÃO, E NÃO DIGEST. A OS 20-R2 trocou os vinte e um corpos por
/// `expect(1, 1)` e recarimbou [kAssinaturaDosCasosOriginaisA11yTerm]: os dois
/// portões seguiram verdes. Um digest é recalculável por quem edita — ele
/// registra que alguém mexeu, não impede que a matéria suma. Uma obrigação
/// nominal, não: nenhum `expect(1, 1)` contém `_atravessarOTeto`.
const String kManifestoA11yTerm = '.github/gates/a11yterm.manifesto.json';

/// O verificador externo e fail-closed da cadeia.
const String kAutoridadeA11yTerm = '.github/scripts/autoridade_a11yterm.js';

/// Os vinte e um casos da entrega original, com o nome COMPLETO — grupo e
/// caso —, exatamente como o executor os reporta.
///
/// ESTA LISTA É O CONTRATO. Ela não descreve a suíte: ela a define. Um caso
/// que sai daqui só sai por decisão explícita de quem edita esta lista, e o
/// diff mostra qual. Uma suíte trivial com o caminho certo não satisfaz
/// nenhuma das vinte e uma linhas.
///
/// Os nomes ficam aqui, e não lá, porque uma relação nominal guardada dentro
/// do arquivo que ela guarda morre junto com ele.
const List<String> kCasosOriginaisA11yTerm = <String>[
  'espera estourada o título é anunciado, e como cabeçalho',
  'espera estourada o cabeçalho é ÚNICO — a mensagem não é cabeçalho',
  'espera estourada a mensagem chega inteira e sem jargão',
  'espera estourada a ampulheta NÃO entra na árvore',
  'espera estourada nada de gráfico sobra sem descrição',
  'espera estourada a ordem de foco é título, mensagem, ação',
  'espera estourada a ação tem nome, papel e estado',
  'espera estourada o callback continua sendo o de antes: volta a esperar',
  'espera estourada nada de sensível na árvore',
  'mudança dinâmica a transição é anunciada — e UMA vez',
  'mudança dinâmica o estado de abertura da rota NÃO é anunciado por cima',
  'mudança dinâmica descartada antes do teto, a casca não fala depois',
  'mudança dinâmica descartada depois de falar, não repete',
  'aviso terminal título é cabeçalho, detalhe não, e nenhuma ação é oferecida',
  'aviso terminal o triângulo NÃO entra na árvore',
  'escala de texto espera estourada em 100%: sem estouro, e operável',
  'escala de texto aviso terminal em 100%: sem estouro',
  'escala de texto espera estourada em 150%: sem estouro, e operável',
  'escala de texto aviso terminal em 150%: sem estouro',
  'escala de texto espera estourada em 200%: sem estouro, e operável',
  'escala de texto aviso terminal em 200%: sem estouro',
];

/// Os casos que a OS 20-C1 acrescentou, também pelo nome completo.
///
/// Separados dos originais de propósito: os de cima são a entrega homologada e
/// não podem encolher; os de baixo são a correção, e o dia em que um deles
/// mudar de nome tem de ser um dia em que alguém editou ESTA lista.
const List<String> kCasosDaCorrecaoA11yTerm = <String>[
  'moldura semântica espera estourada: a moldura é um container semântico PRÓPRIO',
  'moldura semântica espera estourada: TRÊS filhos explícitos, na ordem de leitura',
  'moldura semântica aviso terminal: a moldura é um container semântico PRÓPRIO',
  'moldura semântica aviso terminal: DOIS filhos explícitos, e nenhuma ação',
  'moldura semântica os filhos não são fundidos: cada texto é um nó',
  'moldura semântica o emoji não é filho do container em nenhum dos dois estados',
  'relógio da espera o relógio nasce armado com o teto configurado',
  'relógio da espera descartada a casca, o relógio da espera é CANCELADO',
  'o portão desta suíte o verificador externo existe',
  'o portão desta suíte o verificador externo cobra ESTA suíte pelo nome',
];

/// As três larguras e as três escalas da matriz responsiva.
///
/// Dezoito casos nascem delas — três por três por dois estados — e por isso os
/// nomes não cabem numa lista literal. O que se cobra é a MATRIZ: tirar 320 dp,
/// ou tirar a escala de 200%, muda estas duas linhas, e a contagem cai junto.
const List<String> kLargurasDaMatrizA11yTerm = <String>['320', '360', '412'];
const List<String> kEscalasDaMatrizA11yTerm = <String>['1.0', '1.5', '2.0'];

/// Um caso declarado no arquivo, com nome completo e corpo.
class _CasoDeclarado {
  _CasoDeclarado({
    required this.nome,
    required this.literal,
    required this.corpo,
  });

  /// O nome completo — grupos e caso, unidos por espaço, como o executor o
  /// reporta.
  final String nome;

  /// O nome veio de um literal simples, sem interpolação.
  ///
  /// Um nome interpolado (`'... em $onde: ...'`) não pode ser cobrado por
  /// igualdade: ele só existe depois de executado. Os casos da matriz são
  /// assim de propósito; os vinte e um originais NÃO podem ser.
  final bool literal;

  /// O corpo do closure, já sem comentários.
  final String corpo;
}

/// Lê um literal de string simples a partir de [i], se houver um ali.
///
/// Devolve `null` quando o que está no lugar do nome não é uma string literal —
/// uma variável, uma soma, uma chamada. Isso importa: um nome que não é
/// literal não pode ser conferido sem executar o arquivo.
({String texto, int fim})? _literalEm(String s, int i) {
  while (i < s.length && (s[i] == ' ' || s[i] == '\n' || s[i] == '\r')) {
    i++;
  }
  if (i >= s.length) return null;
  final String aspa = s[i];
  if (aspa != "'" && aspa != '"') return null;
  final b = StringBuffer();
  i++;
  while (i < s.length) {
    final c = s[i];
    if (c == r'\') {
      if (i + 1 < s.length) b.write(s[i + 1]);
      i += 2;
      continue;
    }
    if (c == aspa) return (texto: b.toString(), fim: i + 1);
    b.write(c);
    i++;
  }
  return null;
}

/// Do `{` em [i] até a chave que o fecha, pulando strings.
int _fimDoBloco(String s, int i) {
  var nivel = 0;
  String? aspa;
  while (i < s.length) {
    final c = s[i];
    if (aspa != null) {
      if (c == r'\') {
        i += 2;
        continue;
      }
      if (c == aspa) aspa = null;
      i++;
      continue;
    }
    if (c == "'" || c == '"') {
      aspa = c;
      i++;
      continue;
    }
    if (c == '{') nivel++;
    if (c == '}') {
      nivel--;
      if (nivel == 0) return i;
    }
    i++;
  }
  return s.length;
}

final RegExp _declaracao = RegExp(r'\b(group|testWidgets|test)\s*\(');

/// Todos os casos declarados no código, com o nome completo montado a partir
/// dos grupos que os contêm.
///
/// Trabalha sobre o código JÁ DESPOJADO DE COMENTÁRIOS. É o que impede a
/// sabotagem mais barata de todas: escrever os vinte e um nomes num bloco de
/// comentário e apagar a suíte.
List<_CasoDeclarado> _casosDeclarados(String codigo) {
  final saida = <_CasoDeclarado>[];
  // (nome do grupo, índice em que o bloco dele termina)
  final grupos = <({String nome, int fim})>[];

  for (final m in _declaracao.allMatches(codigo)) {
    // Grupos cujo bloco já terminou antes desta declaração saem da pilha.
    grupos.removeWhere((g) => g.fim < m.start);

    final lido = _literalEm(codigo, m.end);
    if (lido == null) continue;

    var j = lido.fim;
    while (j < codigo.length && codigo[j] != '{') {
      // O corpo é o primeiro bloco depois do nome. Um `)` antes dele quer
      // dizer que a chamada acabou sem corpo — não é declaração de caso.
      if (codigo[j] == ';') break;
      j++;
    }
    if (j >= codigo.length || codigo[j] != '{') continue;
    final int fim = _fimDoBloco(codigo, j);

    if (m.group(1) == 'group') {
      grupos.add((nome: lido.texto, fim: fim));
      continue;
    }
    final String prefixo = grupos.map((g) => g.nome).join(' ');
    saida.add(
      _CasoDeclarado(
        nome: prefixo.isEmpty ? lido.texto : '$prefixo ${lido.texto}',
        literal: !lido.texto.contains(r'$'),
        corpo: codigo.substring(j + 1, fim),
      ),
    );
  }
  return saida;
}

/// O corpo do auxiliar privado [nome], se ele existir no mesmo arquivo.
///
/// Um caso pode delegar o que afirma a um auxiliar — é o que os seis casos de
/// escala fazem, para caber por extenso sem repetir trinta linhas seis vezes.
/// A auditoria segue essa delegação UM nível: o suficiente para não confundir
/// delegação com esvaziamento, e raso o bastante para não virar um
/// interpretador de Dart.
String? _corpoDoAuxiliar(String codigo, String nome) {
  // A DECLARAÇÃO, e não a chamada: é a que tem corpo logo depois dos
  // parâmetros. Percorre todas as ocorrências e fica com a primeira seguida
  // de `{` antes de qualquer `;`.
  for (final o in RegExp('\\b$nome\\s*\\(').allMatches(codigo)) {
    var j = o.end;
    var nivel = 1;
    while (j < codigo.length && nivel > 0) {
      if (codigo[j] == '(') nivel++;
      if (codigo[j] == ')') nivel--;
      j++;
    }
    while (j < codigo.length && codigo[j] != '{' && codigo[j] != ';') {
      j++;
    }
    if (j < codigo.length && codigo[j] == '{') {
      return codigo.substring(j + 1, _fimDoBloco(codigo, j));
    }
  }
  return null;
}

final RegExp _chamadaPrivada = RegExp(r'\b(_[A-Za-z0-9_]+)\s*\(');

/// O corpo, mais o dos auxiliares privados que ele chama.
String _corpoEstendido(String corpo, String codigo) {
  final b = StringBuffer(corpo);
  for (final m in _chamadaPrivada.allMatches(corpo)) {
    final String? auxiliar = _corpoDoAuxiliar(codigo, m.group(1)!);
    if (auxiliar != null) b.write(auxiliar);
  }
  return b.toString();
}

/// O caso afirma alguma coisa — direto, ou pelo auxiliar que chama.
bool _afirmaAlgo(String corpo, String codigo) =>
    _corpoEstendido(corpo, codigo).contains('expect(');

/// Quanto programa há no corpo do PRÓPRIO caso.
///
/// Sem estender pelos auxiliares: estendido, o número inflaria com o corpo de
/// `_lendoATela` e passaria a aprovar um caso literalmente vazio. Quem cobra a
/// afirmação é [_afirmaAlgo]; este número só pega o corpo que não escreve nada.
int _materiaDoCorpo(String corpo) =>
    corpo.replaceAll(RegExp(r'\s+'), '').length;

/// A assinatura material dos vinte e um casos da entrega original.
///
/// É o SHA-256 dos corpos deles, sem comentários e com o espaço em branco
/// colapsado — para que reescrever a prosa ou passar o formatador não vire
/// vermelho, e mexer no programa vire.
///
/// COBRE OS BLOCOS PROTEGIDOS, E NÃO O ARQUIVO: acrescentar casos novos, como
/// os dez da OS 20-C1, não pede recarimbo. Mexer no que já foi homologado
/// pede — e o recarimbo aparece no diff, ao lado da mudança que o motivou.
const String kAssinaturaDosCasosOriginaisA11yTerm =
    '19b7480ab4647995c253bef032142132f8c17be62e934befc3a6249af08498cf';

void main() {
  late Set<String> alcancaveis;

  setUpAll(() {
    alcancaveis = _alcancaveisDaRaiz();
    // Se a varredura não achou nada, o arquivo inteiro seria um verde falso.
    expect(
      alcancaveis,
      contains('lib/main.dart'),
      reason: 'a auditoria precisa ter o que ler',
    );
    expect(alcancaveis.length, greaterThan(5));
  });

  // =========================================================================
  // §4.1 — um dono de autenticação, e um só
  // =========================================================================
  group('não existe segundo dono de autenticação', () {
    test('authStateChanges é assinado num lugar só do cliente', () {
      final assinantes = <String>[];
      for (final f in _fontesDoCliente()) {
        if (_codigo(f).contains('authStateChanges')) {
          assinantes.add(_barras(f.path));
        }
      }
      expect(
        assinantes,
        hasLength(1),
        reason:
            'dois observadores do fluxo de autenticação são dois donos de '
            'sessão, e o segundo nunca conhece a geração do primeiro',
      );
      expect(assinantes.single, endsWith('lib/sessao/sessao_firebase.dart'));
    });

    test('só a camada de sessão importa firebase_auth ou google_sign_in', () {
      final permitidos = {
        'lib/sessao/sessao_firebase.dart',
        'lib/sessao/autenticacao_firebase.dart',
      };
      final infratores = <String>[];
      for (final f in _fontesDoCliente()) {
        final n = _barras(f.path);
        if (permitidos.contains(n)) continue;
        final conteudo = _codigo(f);
        if (conteudo.contains('firebase_auth') ||
            conteudo.contains('google_sign_in')) {
          infratores.add(n);
        }
      }
      expect(
        infratores,
        isEmpty,
        reason:
            'uma tela que sabe acionar o provedor de autenticação decide '
            'sozinha o que fazer com o resultado — e é isso que faz dela um '
            'segundo dono, mesmo sem guardar estado',
      );
    });

    test('nenhuma tela alcançável guarda o usuário do provedor', () {
      final infratores = <String>[];
      for (final caminho in alcancaveis) {
        final f = File(caminho);
        if (!f.existsSync()) continue;
        if (caminho.startsWith('lib/sessao/')) continue;
        final conteudo = _codigo(f);
        for (final termo in [
          'currentUser',
          'signInWithCredential',
          'signOut(',
        ]) {
          if (conteudo.contains(termo)) infratores.add('$caminho: $termo');
        }
      }
      expect(infratores, isEmpty);
    });

    test('o transporte continua sem saber falar com o provedor', () {
      // A garantia que a folha da conexão publicável já tinha, e que a casca
      // não pode ter afrouxado ao subir o transporte para a raiz.
      final transporte = _codigo(File('lib/services/online_service.dart'));
      expect(transporte, isNot(contains('firebase_auth')));
      expect(transporte, isNot(contains('FirebaseAuth')));
    });
  });

  // =========================================================================
  // §2 e §4.4 — nenhuma rota de produção alcança maquete
  // =========================================================================
  group('a raiz de produção não alcança maquete', () {
    test('nenhum arquivo alcançável CONSTRÓI um .mock()', () {
      // A DEFINIÇÃO de `.mock()` continua permitida: as telas seguem no
      // repositório como catálogo visual, e a auditoria não as proíbe de
      // existir. O que ela proíbe é alguém CHAMAR uma delas num caminho que
      // nasce em `main()`.
      final definicao = RegExp(r'factory\s+\w+\.mock');
      final chamada = RegExp(r'\b[A-Z]\w*\.mock\s*\(');
      final infratores = <String>[];
      for (final caminho in alcancaveis) {
        final f = File(caminho);
        if (!f.existsSync()) continue;
        final semDefinicoes = _codigo(f).replaceAll(definicao, '');
        final achado = chamada.firstMatch(semDefinicoes);
        if (achado != null) infratores.add('$caminho: ${achado.group(0)}');
      }
      expect(
        infratores,
        isEmpty,
        reason:
            'dado de maquete alcançável pela raiz é dado inventado exibido '
            'como se fosse do jogador',
      );
    });

    test('main.dart não hospeda host de pré-visualização', () {
      final raiz = _codigo(File('lib/main.dart'));
      expect(raiz, isNot(contains('PreviewHost')));
      expect(raiz, isNot(contains('Preview')));
      // E continua enxuto: era este arquivo que crescia a cada tela nova.
      expect(
        File('lib/main.dart').readAsLinesSync().length,
        lessThan(120),
        reason: 'a porta de entrada não é lugar de tela',
      );
    });

    test('nenhuma tela de prévia declarada é alcançável', () {
      const maquetes = [
        'TorneiosPreviewPage',
        'MesaVipPreviewScreen',
        'LojaCosmeticosScreen',
        'ModeloTorneioScreen',
        'AdminTorneiosScreen',
      ];
      final infratores = <String>[];
      for (final caminho in alcancaveis) {
        final f = File(caminho);
        if (!f.existsSync()) continue;
        final conteudo = _codigo(f);
        for (final maquete in maquetes) {
          // A própria declaração não conta — o que conta é alguém alcançá-la.
          if (conteudo.contains('class $maquete')) continue;
          if (conteudo.contains(maquete)) {
            infratores.add('$caminho: $maquete');
          }
        }
      }
      expect(infratores, isEmpty);
    });

    test('o Perfil alcançável não exibe números de demonstração', () {
      final servico = _codigo(File('lib/services/perfil_service.dart'));
      expect(
        servico,
        contains('static const bool statsDemo = false'),
        reason:
            'com a chave ligada, todo mundo abria o próprio perfil e via os '
            'números de outra pessoa',
      );
    });

    test('o ramo publicável do Perfil não escreve valor nenhum', () {
      // ESTE É O TESTE QUE FALTAVA, e a folha `casca-producao-auth-roteamento-v2`
      // é quem o trouxe. O caso acima checava só `statsDemo == false`, e era
      // EXATAMENTE por isso que o defeito passava por ele: desligar a chave
      // resolvia os números de marketing e deixava intacto o outro ramo do
      // ternário, que escrevia nível 1, título 'Novato(a)', quatro zeros de
      // estatística, zero presentes e oito conquistas travadas.
      //
      // A prova é do FORMATO do literal, e por isso é estrutural: um dia esses
      // campos vão receber valor do Firestore, e aí quem manda é o teste de
      // comportamento (`casca_producao_test.dart` e a suíte de ranking). O que
      // não pode voltar é a CONSTANTE escrita no código.
      //
      // A comparação normaliza espaços porque o formatador quebra estas linhas
      // de jeitos diferentes conforme o comprimento.
      final servico = _codigo(
        File('lib/services/perfil_service.dart'),
      ).replaceAll(RegExp(r'\s+'), ' ');

      const proibidos = [
        "liga: demo ? 'Diamante' : 'Bronze'",
        'posicaoMundial: demo ? 128 : 0',
        'nivel: demo ? 24 : 1',
        "titulo: demo ? 'Rainha da Canastra' : 'Novato(a)'",
        'presentesCount: demo ? 12 : 0',
        'conquistas: demo ? _catalogoDemo : _catalogoTravado',
      ];
      for (final linha in proibidos) {
        expect(
          servico,
          isNot(contains(linha)),
          reason: 'voltou a inventar valor para jogador sem fonte: $linha',
        );
      }

      final ausencias = <Pattern>[
        'nivel: demo ? 24 : null',
        'xpAtual: demo ? 3240 : null',
        'xpProximo: demo ? 5000 : null',
        "titulo: demo ? 'Rainha da Canastra' : null",
        'presentesCount: demo ? 12 : null',
        'conquistas: demo ? _catalogoDemo : null',
        // `stats` é o único cujo ramo demo tem vírgulas dentro, então a âncora
        // é o fim do construtor. A vírgula final é opcional (o formatador a
        // acrescenta quando quebra a linha), e por isso entra no casamento.
        RegExp(r'aproveitamento: 68,? ?\) : null'),
      ];
      for (final ausencia in ausencias) {
        expect(
          servico,
          contains(ausencia),
          reason: 'sem fonte, o campo precisa chegar AUSENTE: $ausencia',
        );
      }

      // E o catálogo "tudo travado" não pode reaparecer por nenhuma porta: oito
      // troféus apagados afirmam que a pessoa não ganhou nenhum, e quem sabe
      // isso é o backend de recompensas, que o cliente ainda não lê.
      expect(servico, isNot(contains('_catalogoTravado')));
    });

    test('o convite copiado não carrega valor inventado', () {
      // O `_compartilhar` montava 'Nível ${vm?.nivel ?? 1} · Liga
      // ${vm?.liga ?? 'Bronze'}'. Com os `??`, a afirmação inventada saía do
      // aplicativo pela área de transferência — o pior destino possível, porque
      // vai parar na conversa de outra pessoa.
      final pagina = _codigo(File('lib/pages/perfil_page.dart'));
      expect(pagina, isNot(contains("?? 'Bronze'")));
      expect(pagina, isNot(contains('?? 1')));
      expect(pagina, isNot(contains('Bronze')));
    });
  });

  // =========================================================================
  // §5 — nenhum dado pessoal real no código distribuído
  // =========================================================================
  group('nenhum dado pessoal real em lib/', () {
    test('nenhum e-mail de domínio real aparece no código', () {
      // `.invalido` e `.invalid` são reservados justamente para fixture, e por
      // isso são o único domínio aceito aqui.
      final email = RegExp(
        r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b',
      );
      final infratores = <String>[];
      for (final f in _fontesDoCliente()) {
        for (final m in email.allMatches(_codigo(f))) {
          final achado = m.group(0)!;
          if (achado.endsWith('.invalido') || achado.endsWith('.invalid')) {
            continue;
          }
          infratores.add('${_barras(f.path)}: $achado');
        }
      }
      expect(infratores, isEmpty);
    });

    test('os dados pessoais conhecidos sumiram do código', () {
      // A lista é dos valores que ESTAVAM no código e iam embarcados em todo
      // APK: o nome de perfil e o e-mail da dona do projeto.
      const conhecidos = ['Sônia Rainha', 'soniia', 'soniia.ambrosio'];
      final infratores = <String>[];
      for (final f in _fontesDoCliente()) {
        final conteudo = _codigo(f);
        for (final dado in conhecidos) {
          if (conteudo.contains(dado)) {
            infratores.add('${_barras(f.path)}: $dado');
          }
        }
      }
      expect(infratores, isEmpty);
    });

    test('a Home de produção não exibe o e-mail da conta', () {
      final home = _codigo(File('lib/casca/home_de_producao.dart'));
      // O campo existe no contrato da tela e é preenchido vazio de propósito.
      expect(home, contains("email: ''"));
    });
  });

  // =========================================================================
  // §4.5 — o transporte não nasce conectado nem duplicado
  // =========================================================================
  group('transporte único', () {
    test('só a raiz constrói OnlineService no código alcançável', () {
      final construtores = <String>[];
      for (final caminho in alcancaveis) {
        final f = File(caminho);
        if (!f.existsSync()) continue;
        if (caminho == 'lib/services/online_service.dart') continue;
        if (caminho == 'lib/services/ponte_sessao_online.dart') continue;
        final conteudo = _codigo(f);
        if (conteudo.contains('OnlineService(') ||
            conteudo.contains('criarOnlineServiceDaSessao(')) {
          construtores.add(_barras(caminho));
        }
      }
      expect(
        construtores,
        hasLength(1),
        reason: 'um transporte por tela é um socket por tela',
      );
      expect(construtores.single, 'lib/casca/raiz_do_aplicativo.dart');
    });

    test('a raiz monta a ponte de sessão', () {
      final raiz = _codigo(File('lib/casca/raiz_do_aplicativo.dart'));
      expect(
        raiz,
        contains('PonteSessaoOnline('),
        reason:
            'sem ponte montada na raiz, um logout fora do lobby não derruba '
            'socket nenhum',
      );
    });

    test('a raiz não conecta o transporte sozinha', () {
      final raiz = _codigo(File('lib/casca/raiz_do_aplicativo.dart'));
      expect(
        raiz,
        isNot(contains('.conectar()')),
        reason:
            'subir o transporte não é conectar: quem pede é o jogador, ao '
            'escolher jogar online',
      );
    });
  });

  // =========================================================================
  // §7 — nada de `print` novo nas camadas sensíveis
  // =========================================================================
  test('sessão, casca e transporte não escrevem em log', () {
    final infratores = <String>[];
    for (final f in _fontesDoCliente()) {
      final n = _barras(f.path);
      final sensivel =
          n.contains('/sessao/') ||
          n.contains('/casca/') ||
          n.endsWith('online_service.dart') ||
          n.endsWith('ponte_sessao_online.dart');
      if (!sensivel) continue;
      final conteudo = _codigo(f);
      // Fronteira de palavra obrigatória: sem ela, `showDialog(` acusa `log(`
      // e a auditoria reprova uma caixa de diálogo por escrever em log.
      for (final termo in [r'\bprint\(', r'\bdebugPrint\(', r'\blog\(']) {
        if (RegExp(termo).hasMatch(conteudo)) infratores.add('$n: $termo');
      }
    }
    expect(
      infratores,
      isEmpty,
      reason: 'é por log que credencial e identidade vazam sem ninguém ver',
    );
  });

  // =========================================================================
  // O PORTÃO DA IDENTIDADE VISITADA EXISTE, E A AUSÊNCIA DELE REPROVA
  // =========================================================================
  //
  // POR QUE ESTA PROVA MORA AQUI, E NÃO NA SUÍTE QUE ELA PROTEGE.
  //
  // O workflow trata arquivo de teste ausente como NÃO EXECUTADO, e NÃO
  // EXECUTADO não derruba o portão — é uma decisão antiga e deliberada, para que
  // um artefato que não existe naquele recorte não invente vermelho. O efeito
  // colateral é que apagar um arquivo de suíte SILENCIA o gate dele em vez de
  // quebrá-lo.
  //
  // Uma prova escrita dentro da própria suíte morreria junto com ela. Escrita
  // aqui — num gate que já é obrigatório e que fala de outro assunto — ela
  // sobrevive ao apagamento e o denuncia. É a mesma ideia do resto deste
  // arquivo: a garantia tem de morar fora do que ela garante.
  group('o portão da identidade visitada', () {
    final workflow = File('../.github/workflows/ci-os-integracao.yml');

    test('a suíte existe na árvore', () {
      expect(
        File('test/perfil/identidade_visitada_test.dart').existsSync(),
        isTrue,
        reason: 'a suíte que prova o Perfil visitado sumiu — e some em silêncio, '
            'porque ausência vira NÃO EXECUTADO no portão',
      );
    });

    test('o workflow a executa e a considera no portão', () {
      // O overlay do CI roda a partir de `app_build/`, e o workflow fica dois
      // níveis acima. Fora do CI o arquivo pode não estar alcançável — e aí o
      // caso não tem o que afirmar, em vez de afirmar errado.
      if (!workflow.existsSync()) return;
      final texto = workflow.readAsStringSync();

      expect(
        texto,
        contains('roda perfilvis  test/perfil/identidade_visitada_test.dart'),
        reason: 'o gate perfilvis não executa mais a suíte',
      );
      // Nas DUAS listas: a da evidência publicada e a que decide verde/vermelho.
      // Estar só na primeira faria o gate aparecer no relatório e não reprovar.
      expect(
        RegExp(r'GATES="[^"]*\bperfilvis\b').hasMatch(texto),
        isTrue,
        reason: 'perfilvis saiu da evidência publicada',
      );
      expect(
        RegExp(r'for k in [^;]*\bperfilvis\b[^;]*; do').hasMatch(texto),
        isTrue,
        reason: 'perfilvis saiu do portão verde/vermelho — passaria a rodar '
            'sem poder reprovar',
      );
    });
  });

  // =========================================================================
  // O PORTÃO DOS ESTADOS TERMINAIS SEMÂNTICOS — `a11yterm`
  // =========================================================================
  //
  // OS 20-C1. O bloco acima protege a suíte do Perfil visitado contra o
  // apagamento; este vai além, porque o ataque contra um gate de
  // acessibilidade não precisa apagar nada: basta esvaziar.
  //
  // O defeito que a suíte `a11yterm` fecha é invisível para quem enxerga a
  // tela. Ninguém tropeça nele por acidente, e ninguém percebe quando ele
  // volta. Uma suíte com o caminho certo, os arquivos no lugar e vinte e um
  // `testWidgets` de corpo vazio deixaria o portão verde e a tela quebrada.
  //
  // Por isso o que se cobra aqui não é a existência de um arquivo, e sim a
  // identidade inteira do gate: o caminho, os NOMES dos casos, a origem deles,
  // a contagem, a matéria dos corpos, quem os executa nos dois portões, o
  // marcador que deixam e a testemunha que lê o resultado real.
  group('o portão dos estados terminais semânticos', () {
    final File suite = File(kCaminhoA11yTerm);
    final File portao = File('../.github/workflows/ci-os-integracao.yml');
    final File construcao = File('../.github/workflows/build.yml');

    /// Os casos declarados na suíte canônica, lidos do código sem comentários.
    List<_CasoDeclarado> lerCasos() => _casosDeclarados(_codigo(suite));

    /// O texto do workflow, ou a reprovação por ele não existir.
    ///
    /// OS 20-C2 §5 — O DEFEITO QUE ESTE MÉTODO FECHA.
    ///
    /// Até a OS 20-C1 estas afirmações começavam com
    /// `if (!arquivo.existsSync()) return;`. A intenção era não afirmar
    /// besteira quando a raiz do repositório não estivesse alcançável. O efeito
    /// foi outro: apagar, mover ou renomear um workflow virou CONFORMIDADE.
    ///
    /// E não é uma conformidade inofensiva. O provedor continua executando
    /// `.github/workflows/apk.yml` depois de `build.yml` ser renomeado —
    /// quem para de existir é a fiscalização, não o pipeline.
    ///
    /// Ausência agora é vermelho. Nas duas situações em que este arquivo roda
    /// de verdade — `app/` no repositório e `app_build/` no CI — a raiz ESTÁ
    /// um nível acima, e o arquivo está lá. Se não estiver, alguém o tirou.
    String exigirWorkflow(File f, String porque) {
      if (!f.existsSync()) {
        fail(
          'o workflow ${_barras(f.path)} não existe. Apagar, mover, renomear '
          'ou trocar a extensão são a mesma coisa daqui, e nenhuma delas é '
          'conformidade: o provedor segue executando o arquivo renomeado e '
          'só a fiscalização para. $porque',
        );
      }
      final String t = f.readAsStringSync();
      if (t.trim().isEmpty) {
        fail('o workflow ${_barras(f.path)} está vazio — esvaziar é apagar '
            'com o caminho preservado');
      }
      return t;
    }

    test('a suíte existe no caminho canônico', () {
      expect(
        suite.existsSync(),
        isTrue,
        reason:
            'a suíte $kCaminhoA11yTerm sumiu. Apagar, renomear ou mover são a '
            'mesma coisa daqui: o gate $kGateA11yTerm passa a não ter o que '
            'executar. Se o arquivo mudou de nome, mude kCaminhoA11yTerm no '
            'MESMO commit.',
      );
    });

    test('os vinte e um casos originais estão lá, um por um, pelo nome', () {
      // O tamanho da lista é cobrado contra um literal, e não contra ela
      // mesma: uma relação nominal que se mede pelo próprio comprimento
      // aprova qualquer encolhimento.
      expect(
        kCasosOriginaisA11yTerm,
        hasLength(21),
        reason: 'a relação nominal da entrega original tem VINTE E UM casos',
      );

      final Set<String> declarados =
          lerCasos().map((c) => c.nome).toSet();
      final List<String> faltando = kCasosOriginaisA11yTerm
          .where((n) => !declarados.contains(n))
          .toList();
      expect(
        faltando,
        isEmpty,
        reason:
            'estes casos da entrega original não são mais declarados na suíte '
            'canônica: $faltando',
      );
    });

    test('os casos da correção também estão lá, pelo nome', () {
      expect(kCasosDaCorrecaoA11yTerm, hasLength(10));
      final Set<String> declarados = lerCasos().map((c) => c.nome).toSet();
      final List<String> faltando = kCasosDaCorrecaoA11yTerm
          .where((n) => !declarados.contains(n))
          .toList();
      expect(faltando, isEmpty, reason: 'casos da OS 20-C1 ausentes: $faltando');
    });

    test('os nomes protegidos são literais, e não interpolação', () {
      final Map<String, bool> literalPorNome = <String, bool>{
        for (final c in lerCasos()) c.nome: c.literal,
      };
      for (final n in <String>[
        ...kCasosOriginaisA11yTerm,
        ...kCasosDaCorrecaoA11yTerm,
      ]) {
        expect(
          literalPorNome[n],
          isTrue,
          reason:
              'o caso "$n" deixou de ser um nome escrito por extenso. Nome '
              'montado em tempo de execução não pode ser cobrado sem executar '
              'a suíte — e é assim que um laço esconde a remoção de um caso.',
        );
      }
    });

    test('nenhum nome se repete', () {
      final List<String> nomes = lerCasos().map((c) => c.nome).toList();
      final Set<String> unicos = nomes.toSet();
      expect(
        unicos,
        hasLength(nomes.length),
        reason:
            'há nome duplicado na suíte. Duplicar é o jeito barato de repor '
            'contagem sem repor prova: '
            '${nomes.where((n) => nomes.where((o) => o == n).length > 1).toSet()}',
      );
    });

    test('a suíte tem pelo menos os quarenta e nove casos que declara', () {
      // A CONTA, POR EXTENSO. Trinta e um casos são escritos por nome — os 21
      // originais e os 10 da correção. Dois são escritos uma vez e nascem
      // dezoito vezes, um por combinação da matriz responsiva. 31 + 18 = 49.
      //
      // Os números são literais de propósito. Um piso derivado do tamanho das
      // próprias listas encolhe junto com elas e aprova qualquer remoção.
      final List<_CasoDeclarado> casos = lerCasos();
      final int porNome = casos.where((c) => c.literal).length;
      final int porMatriz = casos.where((c) => !c.literal).length;

      expect(
        porNome,
        greaterThanOrEqualTo(31),
        reason:
            'a suíte tem $porNome casos escritos por nome, e o piso é 31 '
            '(21 originais + 10 da OS 20-C1)',
      );
      expect(
        porMatriz,
        2,
        reason:
            'os casos gerados pela matriz responsiva são DOIS — um por estado '
            'terminal. Vieram $porMatriz.',
      );

      final int combinacoes =
          kLargurasDaMatrizA11yTerm.length * kEscalasDaMatrizA11yTerm.length;
      expect(combinacoes, 9, reason: 'três larguras por três escalas');
      expect(
        porNome + porMatriz * combinacoes,
        greaterThanOrEqualTo(49),
        reason:
            'a suíte $kCaminhoA11yTerm caiu abaixo do piso de 49 casos '
            'executados',
      );
    });

    test('a matriz responsiva mantém as três larguras e as três escalas', () {
      final String codigo = _codigo(suite);
      for (final l in kLargurasDaMatrizA11yTerm) {
        expect(
          codigo,
          contains(l),
          reason: 'a largura de $l dp saiu da matriz responsiva',
        );
      }
      for (final e in kEscalasDaMatrizA11yTerm) {
        expect(
          codigo,
          contains(e),
          reason: 'a escala de $e saiu da matriz responsiva',
        );
      }
      // As duas listas juntas, e não só os números soltos pelo arquivo.
      expect(
        codigo.replaceAll(' ', ''),
        contains('<double>[320,360,412]'),
        reason: 'a lista de larguras da matriz mudou',
      );
      expect(
        codigo.replaceAll(' ', ''),
        contains('<double>[1.0,1.5,2.0]'),
        reason: 'a lista de escalas da matriz mudou',
      );
    });

    test('nenhum caso protegido está desligado', () {
      final String codigo = _codigo(suite);
      expect(
        RegExp(r'\bskip\s*:').hasMatch(codigo),
        isFalse,
        reason:
            'a suíte ganhou um `skip`. Caso desligado continua contando na '
            'lista de nomes e não prova nada.',
      );
      expect(
        RegExp(r'\bsolo\s*:\s*true').hasMatch(codigo),
        isFalse,
        reason: 'um `solo: true` cala todos os outros casos do arquivo',
      );
    });

    test('os corpos dos casos protegidos têm matéria', () {
      final String codigo = _codigo(suite);
      final Map<String, String> corpoPorNome = <String, String>{
        for (final c in lerCasos()) c.nome: c.corpo,
      };
      for (final n in <String>[
        ...kCasosOriginaisA11yTerm,
        ...kCasosDaCorrecaoA11yTerm,
      ]) {
        final String corpo = (corpoPorNome[n] ?? '').trim();
        expect(
          _afirmaAlgo(corpo, codigo),
          isTrue,
          reason:
              'o caso "$n" não afirma nada — nem no próprio corpo, nem no '
              'auxiliar que ele chama. Nome preservado e corpo esvaziado é o '
              'ataque que a contagem sozinha não vê.',
        );
        expect(
          _materiaDoCorpo(corpo),
          greaterThan(20),
          reason: 'o corpo do caso "$n" foi reduzido a quase nada',
        );
      }
    });

    test('os nomes protegidos vivem SÓ no caminho canônico', () {
      // Repartir os vinte e um nomes por um arquivo isca faz a contagem
      // total continuar batendo enquanto a suíte canônica esvazia. O que
      // impede isso é a ORIGEM: quem declara cada nome.
      final List<File> outros = Directory('test')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('_test.dart'))
          .where((f) => _barras(f.path) != _barras(suite.path))
          .where((f) => !_barras(f.path).endsWith(kCaminhoA11yTerm))
          .toList();

      final infratores = <String>[];
      for (final f in outros) {
        final Set<String> nomes =
            _casosDeclarados(_codigo(f)).map((c) => c.nome).toSet();
        for (final n in <String>[
          ...kCasosOriginaisA11yTerm,
          ...kCasosDaCorrecaoA11yTerm,
        ]) {
          if (nomes.contains(n)) infratores.add('${_barras(f.path)}: "$n"');
        }
      }
      expect(
        infratores,
        isEmpty,
        reason:
            'estes casos são declarados FORA do caminho canônico — o portão '
            'executaria um arquivo e a prova estaria em outro: $infratores',
      );
    });

    test('a assinatura material dos casos originais não mudou', () {
      // O digest cobre os CORPOS dos vinte e um casos da entrega homologada, e
      // não o arquivo inteiro: acrescentar casos novos não pede recarimbo,
      // mexer no que já foi aprovado pede.
      //
      // Recarimbar não é escapatória. Trivializar um corpo muda o digest, e
      // quem recarimbar continua reprovando em `os corpos dos casos protegidos
      // têm matéria` e na relação nominal — que não dependem deste número.
      final Map<String, String> corpoPorNome = <String, String>{
        for (final c in lerCasos()) c.nome: c.corpo,
      };
      final b = StringBuffer();
      for (final n in kCasosOriginaisA11yTerm) {
        b.write(n);
        b.write(' ');
        b.write((corpoPorNome[n] ?? '').replaceAll(RegExp(r'\s+'), ' ').trim());
      }
      expect(
        sha256.convert(utf8.encode(b.toString())).toString(),
        kAssinaturaDosCasosOriginaisA11yTerm,
        reason:
            'o corpo de algum dos vinte e um casos originais mudou. Se a '
            'mudança é deliberada, recarimbe kAssinaturaDosCasosOriginaisA11yTerm '
            'no MESMO commit — e explique no assunto do commit o que mudou.',
      );
    });

    // -----------------------------------------------------------------------
    // A fiação: os dois portões
    // -----------------------------------------------------------------------
    //
    // Rodando de `app/`, ou de `app_build/` no CI, os workflows ficam um nível
    // acima. Fora dessas duas situações o arquivo pode não estar alcançável — e
    // aí o caso não tem o que afirmar, em vez de afirmar errado. No CI ELE
    // ESTÁ alcançável, porque `app_build` nasce ao lado de `.github`.

    test('o build.yml executa a suíte e reprova a ausência dela', () {
      final String texto = exigirWorkflow(
        construcao,
        'É ele que executa a suíte pelo NOME no portão do APK.',
      );
      expect(
        texto,
        contains('app/$kCaminhoA11yTerm'),
        reason:
            'o passo da casca no build.yml parou de conferir o caminho da '
            'suíte. `flutter test test/casca` é um DIRETÓRIO: ele fica verde '
            'com o diretório vazio.',
      );
      expect(
        texto,
        contains('flutter test test/casca'),
        reason: 'o passo que roda a casca sumiu do build.yml',
      );
      expect(
        texto,
        contains('app/test/casca/auditoria_casca_test.dart'),
        reason:
            'o build.yml parou de conferir o caminho DESTE arquivo — sem isso, '
            'apagar o verificador some com o contrato inteiro em silêncio',
      );
      // A execução NOMINAL, no portão do APK. `flutter test test/casca` roda
      // um diretório: ele não distingue "a suíte passou" de "a suíte foi
      // esvaziada", e é esse o ataque contra um gate de acessibilidade.
      expect(
        texto,
        contains(r'flutter test "$SUITE" --reporter expanded'),
        reason:
            'o build.yml deixou de chamar a suíte PELO NOME, e voltou a '
            'depender só da execução do diretório',
      );
      expect(
        texto,
        contains('SUITE=$kCaminhoA11yTerm'),
        reason: 'a chamada nominal do build.yml aponta para outro arquivo',
      );
      expect(
        texto,
        contains('.github/scripts/testemunha_a11yterm.js'),
        reason: 'a testemunha material saiu do build.yml',
      );
      // A GUARDA DO OVERLAY, que é a outra porta do mesmo passo. Sem ela, uma
      // suíte que não chega ao `app_build` faz o `flutter test` reclamar de
      // arquivo inexistente — e reclamar é o melhor caso. Este `if` transforma
      // "não chegou" em vermelho com nome, antes de qualquer outra coisa.
      expect(
        texto,
        contains(r'if [ ! -f "app_build/$SUITE" ]; then'),
        reason:
            'o passo de acessibilidade parou de conferir que a suíte chegou ao '
            'overlay',
      );
    });

    test('o ci-os-integracao executa a suíte como OBRIGATÓRIA', () {
      final String texto = exigirWorkflow(
        portao,
        'É ele que roda o gate $kGateA11yTerm como OBRIGATÓRIO.',
      );

      expect(
        texto,
        contains('roda_obrigatorio $kGateA11yTerm $kCaminhoA11yTerm'),
        reason:
            'o gate $kGateA11yTerm não executa mais a suíte canônica, ou '
            'deixou de ser obrigatório. `roda` trata arquivo ausente como NÃO '
            'EXECUTADO, e NÃO EXECUTADO não reprova.',
      );
      // Este arquivo — o verificador — também não pode sumir em silêncio.
      expect(
        texto,
        contains('roda_obrigatorio cascaaud test/casca/auditoria_casca_test.dart'),
        reason:
            'o gate cascaaud voltou a ser opcional. Ele é quem carrega o '
            'contrato nominal: apagado, o portão seguiria verde sem contrato.',
      );
    });

    test('o gate está nas TRÊS listas do portão', () {
      final String texto = exigirWorkflow(
        portao,
        'São as três listas dele que transformam gate vermelho em run vermelho.',
      );

      // O laço que decide verde/vermelho, e não qualquer `for k in`.
      //
      // Este arquivo tem QUATRO laços sobre chaves de gate, e três deles não
      // decidem nada: dois montam a evidência publicada e um cobra marcador
      // dos obrigatórios. A primeira versão desta prova perguntava se a chave
      // aparecia em ALGUM laço — e a resposta continuava sim depois de ela sair
      // deste, porque seguia na lista dos obrigatórios logo abaixo.
      //
      // O laço que decide é reconhecido pelo que faz: é o único que levanta
      // `fail`. É por ele que o run fica vermelho.
      final RegExp lacoPrincipal = RegExp(
        r'for k in ([^;]*); do\s*\n\s*if \[ -f "exit_\$k" \]; then\s*\n'
        r'\s*v=\$\(cat "exit_\$k"\)[^\n]*\n\s*\[ "\$v" = "0" \] \|\| fail=1',
      );
      final Match? principal = lacoPrincipal.firstMatch(texto);
      expect(
        principal,
        isNotNull,
        reason:
            'o laço que decide verde/vermelho sumiu do portão — sem ele nenhum '
            'gate reprova coisa nenhuma',
      );

      for (final k in <String>[
        kGateA11yTerm,
        kGateA11yTermAtestado,
        'cascaaud',
      ]) {
        expect(
          RegExp('GATES="[^"]*\\b$k\\b').hasMatch(texto),
          isTrue,
          reason: '$k saiu da evidência publicada',
        );
        expect(
          principal!.group(1)!.split(RegExp(r'\s+')),
          contains(k),
          reason:
              '$k saiu do portão verde/vermelho — passaria a rodar sem poder '
              'reprovar',
        );
      }
      // A terceira lista: a dos obrigatórios, que é o que transforma
      // "marcador ausente" em vermelho. Sem ela, matar o passo antes da hora
      // devolve o run ao verde.
      final RegExp obrigatorios = RegExp(
        r'for k in ([^;]*); do\s*\n\s*if \[ ! -f "exit_\$k" \]',
      );
      final Match? m = obrigatorios.firstMatch(texto);
      expect(
        m,
        isNotNull,
        reason:
            'o laço que reprova gate SEM MARCADOR sumiu do portão. Ele é o que '
            'impede o passo morrer cedo e o run continuar verde.',
      );
      for (final k in <String>[
        kGateA11yTerm,
        kGateA11yTermAtestado,
        'cascaaud',
      ]) {
        expect(
          m!.group(1)!.split(RegExp(r'\s+')),
          contains(k),
          reason: '$k saiu da lista dos gates obrigatórios',
        );
      }

      // E A DECISÃO CHEGA À SAÍDA DO PASSO.
      //
      // As três listas não valem nada se o passo terminar em `exit 0`: a
      // tabela sai vermelha no log e o run segue verde. É a sabotagem mais
      // barata do arquivo inteiro — um caractere — e a única prova contra ela
      // é cobrar que a última palavra do portão seja o contador de falhas.
      expect(
        RegExp(r'echo "resultado: \$\(\[ \$fail -eq 0 \][^\n]*\n\s*exit \$fail')
            .hasMatch(texto),
        isTrue,
        reason:
            'o portão verde/vermelho não termina mais em `exit \$fail`. '
            'Trocado por `exit 0`, ele imprime o veredito e não o aplica.',
      );
    });

    test('a execução deixa as provas que a testemunha precisa ler', () {
      final String texto = exigirWorkflow(
        portao,
        'É ele que produz carimbo, log, marcador e relatório de máquina.',
      );

      // Cada literal abaixo é uma prova que a execução tem de PRODUZIR. Sem
      // ela, a testemunha fica sem o que conferir e o gate volta a acreditar
      // no próprio código de saída.
      for (final marca in <String>[
        r'date -u +%s > "carimbo_$k"', // o instante ANTES da execução
        r'"json:../rel_$k.json"', // o relatório de máquina do Flutter
        r'echo ${PIPESTATUS[0]} > "exit_$k"', // o marcador de execução
        r'tee "t_$k.log"', // o log real
      ]) {
        expect(
          texto,
          contains(marca),
          reason:
              '`roda_obrigatorio` parou de produzir `$marca` — sem essa prova '
              'a testemunha material não tem o que conferir',
        );
      }
      // A limpeza é parte da prova: sem ela, artefato de execução anterior —
      // ou plantado à mão — passaria por resultado desta.
      expect(
        texto,
        contains(r'rm -f "exit_$k" "t_$k.log" "rel_$k.json" "carimbo_$k"'),
        reason: '`roda_obrigatorio` parou de limpar os artefatos antes de rodar',
      );
    });

    test('a testemunha material existe e é chamada nos DOIS portões', () {
      final File testemunha =
          File('../.github/scripts/testemunha_a11yterm.js');
      const String chamada =
          'node .github/scripts/testemunha_a11yterm.js . '
          'app_build/test/casca/auditoria_casca_test.dart';

      // Se a raiz do repositório está alcançável — e no CI ela está, porque
      // `app_build` nasce ao lado de `.github` —, a ausência da testemunha é
      // vermelho, e não silêncio.
      // OS 20-C2: era aqui que a ausência virava silêncio. A testemunha só
      // era cobrada SE algum workflow existisse — e quem apagasse os dois
      // levava, de brinde, a dispensa de ter testemunha.
      {
        expect(
          testemunha.existsSync(),
          isTrue,
          reason:
              '.github/scripts/testemunha_a11yterm.js sumiu. Sem ela os dois '
              'portões voltam a acreditar no próprio código de saída.',
        );
      }

      {
        final String js = testemunha.readAsStringSync();
        // Ela lê a relação nominal DAQUI, e não de uma cópia. É isso que
        // impede a segunda fonte de gates: apagar a lista desta fonte faz a
        // testemunha reprovar, e não afrouxar.
        expect(
          js,
          contains('kCasosOriginaisA11yTerm'),
          reason:
              'a testemunha parou de ler a relação nominal da fonte única — '
              'ou passou a carregar uma cópia própria',
        );
        expect(
          js,
          contains('kCaminhoA11yTerm'),
          reason: 'a testemunha parou de ler o caminho canônico daqui',
        );
        // O PISO DELA NÃO É MAIS ESCRITO NELA.
        //
        // OS 20-C2 §6. Ele valia 21 aqui, 21 na testemunha e 21 na autoridade:
        // três números para a mesma coisa. A OS 20-R2 baixou os três numa
        // passada só e os dois portões ficaram verdes com seis casos a menos.
        // Agora a testemunha lê o piso do manifesto, que é conferido contra
        // esta fonte E contra a autoridade externa.
        expect(
          js,
          contains(kManifestoA11yTerm),
          reason:
              'a testemunha voltou a carregar um piso próprio. Um número '
              'escrito à mão no arquivo que ele protege é a constante mais '
              'barata de baixar que existe.',
        );
        expect(
          RegExp(r'const PISO = \d+;').hasMatch(js),
          isFalse,
          reason:
              'a testemunha reintroduziu um piso literal — é a terceira '
              'verdade que a OS 20-C2 tirou de circulação',
        );
        for (final marca in <String>[
          'exit_\${GATE}',
          't_\${GATE}.log',
          'rel_\${GATE}.json',
          'carimbo_\${GATE}',
        ]) {
          expect(
            js,
            contains(marca),
            reason: 'a testemunha parou de olhar para `$marca`',
          );
        }
      }

      {
        final String texto = exigirWorkflow(
          portao,
          'É um dos dois portadores da testemunha material.',
        );
        expect(
          texto,
          contains(chamada),
          reason:
              'o ci-os-integracao parou de chamar a testemunha material do '
              'gate $kGateA11yTerm',
        );
        expect(
          texto,
          contains('echo "\$v" > exit_$kGateA11yTermAtestado'),
          reason:
              'a testemunha deixou de gravar o próprio marcador — sem ele, '
              'matar o passo antes da hora devolve o run ao verde',
        );
      }

      {
        final String texto = exigirWorkflow(
          construcao,
          'É o outro portador da testemunha material.',
        );
        expect(
          texto,
          contains(chamada),
          reason: 'o build.yml parou de chamar a testemunha material',
        );
        expect(
          texto,
          contains('date -u +%s > carimbo_a11yterm'),
          reason: 'o build.yml parou de carimbar a execução',
        );
        expect(
          texto,
          contains('"json:../rel_a11yterm.json"'),
          reason: 'o build.yml parou de produzir o relatório de máquina',
        );
      }
    });

    // -----------------------------------------------------------------------
    // OS 20-C2 — A SEGUNDA NATUREZA
    // -----------------------------------------------------------------------
    //
    // Até aqui o contrato era Dart, e só. Uma suíte que aprova os próprios
    // nomes, a própria cardinalidade, os próprios pisos e a própria assinatura
    // é uma autoridade que se confirma sozinha — e a OS 20-R2 mostrou o preço:
    // baixar 21 para 15 em duas listas coordenadas, ou trocar os vinte e um
    // corpos por `expect(1, 1)` e recarimbar o digest, deixou os dois portões
    // verdes.
    //
    // O que estas provas fixam é a OUTRA natureza: um manifesto de DADOS, lido
    // por um verificador que não é Dart, não roda no executor do Flutter e não
    // depende desta suíte para nada. Os números vivem nos dois lados, e os dois
    // lados se cobram: baixar um piso numa peça só passa a ser divergência, e
    // divergência é vermelho nas duas.

    final File manifesto = File('../$kManifestoA11yTerm');
    final File autoridade = File('../$kAutoridadeA11yTerm');

    /// O manifesto decodificado, ou a reprovação por ele não estar lá.
    Map<String, dynamic> lerManifesto() {
      if (!manifesto.existsSync()) {
        fail(
          '$kManifestoA11yTerm não existe. Ele é a autoridade externa da '
          'cadeia: nele moram a obrigação material de cada um dos vinte e um '
          'casos e os pisos que esta fonte repete. Sem ele não há o que '
          'conferir — e "nada a conferir" não é aprovação.',
        );
      }
      final String bruto = manifesto.readAsStringSync();
      if (bruto.trim().isEmpty) {
        fail('$kManifestoA11yTerm está vazio — manifesto vazio não é manifesto');
      }
      final Object? lido = jsonDecode(bruto);
      if (lido is! Map<String, dynamic>) {
        fail('$kManifestoA11yTerm não é um objeto JSON');
      }
      return lido;
    }

    test('o manifesto da cadeia existe, é legível e declara suas seções', () {
      final Map<String, dynamic> m = lerManifesto();
      for (final chave in <String>[
        'caminhoCanonicoDaSuite',
        'fonteUnicaDeGates',
        'testemunha',
        'autoridade',
        'marcasDaCadeia',
        'workflowsCanonicos',
        'invocacoes',
        'invocacoesCompartilhadas',
        'cruzamento',
        'pisos',
        'minimos',
        'casosProtegidos',
      ]) {
        expect(
          m.containsKey(chave),
          isTrue,
          reason:
              'o manifesto perdeu a seção "$chave". Reduzi-lo a um objeto sem '
              'obrigações deixaria a autoridade externa sem trabalho, e um '
              'verificador sem trabalho é sempre verde.',
        );
      }
      expect(
        m['caminhoCanonicoDaSuite'],
        kCaminhoA11yTerm,
        reason:
            'o manifesto e esta fonte apontam para arquivos diferentes — '
            'enquanto isso durar, nenhum dos dois é autoridade',
      );
    });

    test('o manifesto protege os VINTE E UM casos, pelo nome e na ordem', () {
      final List<dynamic> protegidos =
          lerManifesto()['casosProtegidos'] as List<dynamic>;
      // Contra um literal, e não contra o tamanho da própria lista: uma
      // cardinalidade que se mede por si mesma aprova qualquer encolhimento.
      expect(
        protegidos,
        hasLength(21),
        reason:
            'o manifesto declara ${protegidos.length} casos protegidos, e a '
            'relação homologada são VINTE E UM. Reduzir a relação é o ataque, '
            'não a correção dele.',
      );
      final List<String> doManifesto = protegidos
          .map((e) => (e as Map<String, dynamic>)['nome'] as String)
          .toList();
      expect(
        doManifesto,
        kCasosOriginaisA11yTerm,
        reason:
            'a relação nominal do manifesto divergiu da desta fonte. As duas '
            'são a mesma lista escrita em duas naturezas, e é a igualdade '
            'delas que impede o recarimbo coordenado de uma peça só.',
      );
    });

    test('cada caso protegido carrega obrigação material própria', () {
      final List<dynamic> protegidos =
          lerManifesto()['casosProtegidos'] as List<dynamic>;
      final Set<String> vistos = <String>{};
      for (final dynamic bruto in protegidos) {
        final Map<String, dynamic> c = bruto as Map<String, dynamic>;
        final String nome = c['nome'] as String;
        final List<dynamic> exige = (c['exige'] ?? <dynamic>[]) as List<dynamic>;
        // A OBRIGAÇÃO É O QUE NÃO SE RECARIMBA. Um digest some com a matéria e
        // volta a ser verde por recálculo; uma lista de operações exigidas,
        // não: `expect(1, 1)` não contém `_atravessarOTeto`.
        expect(
          exige.length,
          greaterThanOrEqualTo(3),
          reason:
              'o caso "$nome" ficou com ${exige.length} obrigações materiais. '
              'Esvaziar a lista `exige` é autorizar a trivialização do corpo '
              'sem tocar em contagem nenhuma.',
        );
        expect(
          (c['afirmacoesMinimas'] as int?) ?? 0,
          greaterThanOrEqualTo(1),
          reason: 'o caso "$nome" deixou de exigir qualquer afirmação',
        );
        expect(
          (c['porque'] as String?)?.trim().isNotEmpty,
          isTrue,
          reason:
              'o caso "$nome" perdeu a explicação do que se perde quando a '
              'obrigação dele cai',
        );
        expect(
          vistos.add(nome),
          isTrue,
          reason:
              'o caso "$nome" aparece duas vezes no manifesto — duplicar repõe '
              'contagem sem repor obrigação',
        );
      }
    });

    test('os pisos do manifesto batem com os literais desta fonte', () {
      final Map<String, dynamic> pisos =
          lerManifesto()['pisos'] as Map<String, dynamic>;
      // Os mesmos números que os casos acima cobram por extenso. Escritos aqui
      // de novo, de propósito: baixar um piso passa a exigir editar o
      // manifesto, esta fonte e a autoridade externa, e as três se conferem.
      const Map<String, int> homologados = <String, int>{
        'a11yterm': 49,
        'relacaoNominalOriginal': 21,
        'casosDaCorrecao': 10,
        'casosPorNome': 31,
        'casosDaMatriz': 2,
        'combinacoesDaMatriz': 9,
        'testemunha': 21,
      };
      homologados.forEach((String k, int v) {
        expect(
          pisos[k],
          v,
          reason:
              'o piso "$k" vale $v aqui e ${pisos[k]} no manifesto. '
              'Divergiram: baixar o piso numa peça só é exatamente o ataque '
              'que a OS 20-R2 executou.',
        );
      });
      expect(
        kCasosOriginaisA11yTerm,
        hasLength(homologados['relacaoNominalOriginal']),
      );
      expect(
        kCasosDaCorrecaoA11yTerm,
        hasLength(homologados['casosDaCorrecao']),
      );
    });

    test('a autoridade externa existe e é chamada VIVA nos dois portões', () {
      const String chamada = 'node $kAutoridadeA11yTerm .';

      expect(
        autoridade.existsSync(),
        isTrue,
        reason:
            '$kAutoridadeA11yTerm sumiu. Ela é o único caminho executável que '
            'permanece alcançável quando um dos workflows desaparece: sem ela, '
            'apagar `build.yml` volta a ser conformidade.',
      );

      final String daConstrucao = exigirWorkflow(
        construcao,
        'É um dos dois portadores da autoridade externa.',
      );
      final String doPortao = exigirWorkflow(
        portao,
        'É o outro portador da autoridade externa.',
      );

      // NOS DOIS, DE PROPÓSITO. Apagado o `ci-os-integracao.yml`, quem ainda
      // executa no provedor é o `build.yml` — e é por ele que a ausência do
      // companheiro fica vermelha. Apagado o `build.yml`, vale o inverso.
      // Apagados os dois, nada executa lá: essa é uma dependência da raiz
      // integrada, e nenhuma folha a fecha sozinha.
      expect(
        daConstrucao,
        contains(chamada),
        reason:
            'o build.yml parou de chamar a autoridade externa — sem ela, o '
            'sumiço do ci-os-integracao.yml deixa de ter caminho que reprove',
      );
      expect(
        doPortao,
        contains(chamada),
        reason:
            'o ci-os-integracao parou de chamar a autoridade externa — sem '
            'ela, o sumiço do build.yml deixa de ter caminho que reprove',
      );
      expect(
        doPortao,
        contains('echo "\$v" > exit_$kGateA11yTermAutoridade'),
        reason:
            'a autoridade deixou de gravar o próprio marcador — sem ele, '
            'matar o passo antes da hora devolve o run ao verde',
      );
    });

    test('a autoridade externa não pode ser ESVAZIADA', () {
      // O ATAQUE QUE ELA NÃO PEGA SOZINHA.
      //
      // Apagar a autoridade é vermelho: os dois workflows conferem o caminho
      // antes de chamá-la, e a prova acima cobra a existência. Mas TROCAR o
      // conteúdo dela por `process.exit(0)` deixa o arquivo no lugar, a
      // chamada viva nos dois portões e o exit em zero — e ela nunca chega a
      // conferir nada, nem a si mesma.
      //
      // Quem pega isso precisa ser de outra natureza e rodar num gate que não
      // dependa dela. É este arquivo, em Dart, no gate `cascaaud`, que é
      // obrigatório nos dois portões.
      final Map<String, dynamic> m = lerManifesto();
      final List<dynamic> exige =
          (m['autoridadeExige'] ?? <dynamic>[]) as List<dynamic>;
      expect(
        exige.length,
        greaterThanOrEqualTo(10),
        reason:
            'o manifesto declara ${exige.length} marcas da autoridade, e o '
            'homologado são DEZ. Encurtar a lista é autorizar o esvaziamento.',
      );

      expect(autoridade.existsSync(), isTrue, reason: 'a autoridade sumiu');
      final String js = autoridade.readAsStringSync();
      for (final dynamic bruto in exige) {
        final Map<String, dynamic> marca = bruto as Map<String, dynamic>;
        expect(
          js,
          contains(marca['texto'] as String),
          reason:
              'a autoridade externa perdeu "${marca['texto']}" — '
              '${marca['porque']}',
        );
      }

      // Os pisos homologados também vivem LÁ, como literais. É a terceira
      // natureza: baixar um número exige editar o manifesto, esta fonte e a
      // autoridade, e as três se conferem.
      for (final String literal in <String>[
        'a11yterm: 49,',
        'relacaoNominalOriginal: 21,',
        'casosPorNome: 31,',
        'obrigacoesMateriais: 21,',
      ]) {
        expect(
          js,
          contains(literal),
          reason:
              'o piso "$literal" saiu da autoridade externa — as três '
              'naturezas divergiram, e enquanto isso durar nenhuma é autoridade',
        );
      }
    });

    test('o gate da autoridade está nas TRÊS listas do portão', () {
      final String texto = exigirWorkflow(
        portao,
        'São as três listas dele que transformam gate vermelho em run vermelho.',
      );
      expect(
        RegExp('GATES="[^"]*\\b$kGateA11yTermAutoridade\\b').hasMatch(texto),
        isTrue,
        reason: '$kGateA11yTermAutoridade saiu da evidência publicada',
      );
      // O LACO QUE DECIDE, e nao qualquer `for k in`. Sao quatro os laços
      // sobre chaves de gate neste arquivo, e três não decidem nada: dois
      // montam a evidência publicada — e o `in` deles é `$GATES`, não a
      // lista — e um cobra marcador dos obrigatórios. O que decide é o único
      // que levanta `fail`.
      final RegExp lacoPrincipal = RegExp(
        r'for k in ([^;]*); do\s*\n\s*if \[ -f "exit_\$k" \]; then\s*\n'
        r'\s*v=\$\(cat "exit_\$k"\)[^\n]*\n\s*\[ "\$v" = "0" \] \|\| fail=1',
      );
      expect(
        lacoPrincipal.firstMatch(texto)?.group(1)?.split(RegExp(r'\s+')),
        contains(kGateA11yTermAutoridade),
        reason:
            '$kGateA11yTermAutoridade saiu do portão verde/vermelho — passaria '
            'a rodar sem poder reprovar',
      );
      final RegExp obrigatorios = RegExp(
        r'for k in ([^;]*); do\s*\n\s*if \[ ! -f "exit_\$k" \]',
      );
      expect(
        obrigatorios.firstMatch(texto)?.group(1)?.split(RegExp(r'\s+')),
        contains(kGateA11yTermAutoridade),
        reason:
            '$kGateA11yTermAutoridade saiu da lista dos obrigatórios — matar o '
            'passo antes da hora voltaria a devolver o run ao verde',
      );
    });
  });
}
