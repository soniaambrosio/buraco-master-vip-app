// homologacao_encerramento_pendente_ack_test.dart — a prova independente de
// que o aviso de fim NÃO é dado por consumido antes de aparecer.
//
// ===========================================================================
// O QUE ESTA SUÍTE É, E O QUE ELA NÃO É
// ===========================================================================
//
// É a bateria de uma HOMOLOGAÇÃO, escrita contra a candidata sem olhar para as
// asserções que ela já traz. Os cenários foram remontados do zero: bancada
// própria (`Trilho`), apresentadores próprios e uma sequência de pumps próprios.
// Onde a suíte da entrega e esta chegam à mesma conclusão, é porque a conclusão
// é do código — não porque a asserção foi copiada.
//
// NÃO É correção. Nenhum arquivo de `app/lib/` é tocado por esta entrega. Um
// caso que reprove aqui é um FAIL de laudo, e a correção é outra OS.
//
// ===========================================================================
// A PERGUNTA QUE GOVERNA CADA CASO
// ===========================================================================
//
// A suíte antiga da casca provava que o encerramento aparece UMA vez. Isso não
// exclui ZERO. O defeito que esta bateria persegue é a perda silenciosa: o
// servidor declara o fim, o livro anota, e ninguém nunca apresenta — sem erro,
// sem log e sem teste vermelho.
//
// Por isso quase todo caso aqui mede DUAS coisas, e as duas são necessárias:
//
//   quantos anúncios aconteceram   → prova que não houve dois;
//   em que estado o livro ficou    → prova que o que não apareceu ainda vai.
//
// Medir só a primeira é o que deixava o defeito passar.
//
// ===========================================================================
// O QUE É FALSO AQUI
// ===========================================================================
//
// Duas coisas, e só duas: o socket (`CanalFalso`, da bancada compartilhada) e o
// APRESENTADOR. `OnlineService`, `OrdemDaVisao`, `LivroDeEfeitosTerminais` e
// `LobbyOnline` são os de produção — a costura entre eles é o objeto do
// julgamento, e trocar qualquer um por dublê provaria o dublê.
//
// Nenhum caso abre rede, toca relógio de verdade ou fala com Firebase.

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:buraco_master_vip/casca/escopo_transporte.dart';
import 'package:buraco_master_vip/casca/lobby_online.dart';
import 'package:buraco_master_vip/casca/mesa_online/encerramento_da_mesa.dart';
import 'package:buraco_master_vip/services/online_service.dart';

import 'bancada_online.dart';

// ===========================================================================
// Bancada desta homologação
// ===========================================================================

/// Um apresentador que responde o que se mandar e guarda tudo o que viu.
///
/// Registra a tentativa MESMO quando recusa: sem isso não há como separar
/// "ninguém tentou" de "tentou e não deu", que é a distinção inteira dos casos
/// de falha.
class ApresentadorDeBancada implements ApresentadorDeEncerramento {
  ApresentadorDeBancada([this.resposta = ResultadoDaApresentacao.apresentado]);

  ResultadoDaApresentacao resposta;

  final List<EncerramentoAutoritativo> vistos = <EncerramentoAutoritativo>[];
  final List<VoidCallback> saidas = <VoidCallback>[];

  int get tentativas => vistos.length;

  List<String?> get eventos => vistos.map((e) => e.eventoId).toList();

  @override
  Future<ResultadoDaApresentacao> apresentar(
    BuildContext context,
    EncerramentoAutoritativo encerramento, {
    required VoidCallback aoSairDaMesa,
  }) async {
    vistos.add(encerramento);
    saidas.add(aoSairDaMesa);
    return resposta;
  }
}

/// Como um apresentador pode explodir.
///
/// A distinção entre as duas formas não é preciosismo: um `throw` antes de o
/// futuro existir estoura na CHAMADA, e um futuro que completa com erro estoura
/// no `await`. São dois pontos diferentes no código de quem chama, e um `try`
/// mal posicionado pega um e deixa o outro passar.
enum FormaDoEstouro { naNaChamada, noFuturo, nenhum }

/// Um apresentador que estoura de propósito — e que sabe parar de estourar.
class ApresentadorInstavel implements ApresentadorDeEncerramento {
  ApresentadorInstavel(this.forma);

  FormaDoEstouro forma;

  /// Quantas vezes foi CHAMADO, inclusive as chamadas que estouraram.
  int chamadas = 0;

  /// O que efetivamente chegou a ser apresentado.
  final List<EncerramentoAutoritativo> vistos = <EncerramentoAutoritativo>[];

  @override
  // SEM `async` DE PROPÓSITO: um corpo `async` converteria todo `throw` em erro
  // de futuro, e a forma síncrona deixaria de existir neste arquivo.
  Future<ResultadoDaApresentacao> apresentar(
    BuildContext context,
    EncerramentoAutoritativo encerramento, {
    required VoidCallback aoSairDaMesa,
  }) {
    chamadas++;
    switch (forma) {
      case FormaDoEstouro.naNaChamada:
        throw StateError('estourei antes de devolver o futuro');
      case FormaDoEstouro.noFuturo:
        return Future<ResultadoDaApresentacao>.error(
          StateError('estourei depois de devolver o futuro'),
        );
      case FormaDoEstouro.nenhum:
        vistos.add(encerramento);
        return Future<ResultadoDaApresentacao>.value(
          ResultadoDaApresentacao.apresentado,
        );
    }
  }
}

/// O transporte de produção com o socket falso na ponta.
class Trilho {
  Trilho() {
    servico = OnlineService(
      obterIdToken: () async => 'token-de-homologacao',
      endpoint: Uri.parse(kEndpointDeTeste),
      abrirCanal: (_) {
        final novo = CanalFalso();
        canais.add(novo);
        return novo;
      },
    );
  }

  final List<CanalFalso> canais = <CanalFalso>[];
  late final OnlineService servico;

  CanalFalso get canal => canais.last;
  LivroDeEfeitosTerminais get livro => servico.efeitosTerminais;

  EstadoDoEfeito? estado([String? eventoId]) => livro.estadoDe(eventoId);

  void encerrar() => servico.dispose();
}

/// A árvore COM a rota da mesa: é ela que assina o encerramento.
Widget comAMesa(OnlineService servico, ApresentadorDeEncerramento ap) =>
    EscopoTransporte(
      online: servico,
      child: MaterialApp(home: LobbyOnline(apresentador: ap)),
    );

/// A mesma árvore SEM a rota da mesa.
///
/// O transporte segue vivo — ele é da raiz, e sair desta tela não o derruba. O
/// que desaparece é o CONSUMIDOR, que é exatamente a condição que o desenho
/// antigo não sobrevivia.
Widget semAMesa(OnlineService servico) => EscopoTransporte(
  online: servico,
  child: const MaterialApp(home: Scaffold(body: SizedBox.shrink())),
);

/// Superfície de telefone. Os 800x600 do `flutter_test` não cabem a mesa, e o
/// estouro de layout viraria falha de caso sem relação com o que se julga.
void superficieDeTelefone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

/// O servidor aceita a credencial e dá o assento.
Future<void> sentar(WidgetTester tester, Trilho t, {int assento = 0}) async {
  t.canal.servidorEnvia(<String, dynamic>{'tipo': 'autenticado'});
  await tester.pumpAndSettle();
  t.canal.servidorEnvia(<String, dynamic>{
    'tipo': 'entrou',
    'codigo': 'BURACO-0001',
    'assento': assento,
  });
  await tester.pumpAndSettle();
}

/// Monta a tela da mesa e leva a conexão até o assento.
Future<void> abrir(
  WidgetTester tester,
  Trilho t,
  ApresentadorDeEncerramento ap,
) async {
  superficieDeTelefone(tester);
  await tester.pumpWidget(comAMesa(t.servico, ap));
  await tester.pumpAndSettle();
  await sentar(tester, t);
}

/// Monta a árvore SEM a mesa e leva a conexão até o assento.
///
/// É o caminho de quem está no aplicativo mas não está na tela do online — a
/// condição em que o slot `aoEncerrar` fica vazio o tempo todo.
Future<void> abrirLongeDaMesa(WidgetTester tester, Trilho t) async {
  superficieDeTelefone(tester);
  await tester.pumpWidget(semAMesa(t.servico));
  await tester.pumpAndSettle();
  t.servico.conectar();
  await tester.pumpAndSettle();
  await sentar(tester, t);
}

/// O servidor manda um envelope de estado e o quadro roda.
Future<void> manda(
  WidgetTester tester,
  Trilho t,
  Map<String, dynamic> visao, {
  int? versaoEstado,
  String? eventoId,
}) async {
  t.canal.servidorEnvia(
    envelopeEstado(visao, versaoEstado: versaoEstado, eventoId: eventoId),
  );
  await tester.pumpAndSettle();
}

/// O servidor manda, a mensagem é ENTREGUE, e NENHUM quadro roda.
///
/// É a lupa desta suíte. `idle()` drena as microtarefas sem pintar, então o que
/// se observa depois dela é o estado do livro no intervalo entre a chegada do
/// envelope e a apresentação — que é onde vive a reivindicação, e onde o
/// desenho antigo já dava o aviso por consumido.
Future<void> mandaSemQuadro(
  WidgetTester tester,
  Trilho t,
  Map<String, dynamic> visao, {
  int? versaoEstado,
  String? eventoId,
}) async {
  t.canal.servidorEnvia(
    envelopeEstado(visao, versaoEstado: versaoEstado, eventoId: eventoId),
  );
  await tester.idle();
}

/// A visão que o servidor emite quando a partida acabou.
Map<String, dynamic> fim({int assento = 0}) => visaoDeJogo(
  voceAssento: assento,
  suaVez: false,
  encerrada: true,
  rodadaEncerrada: true,
  duplaQueBateu: 'nos',
  placar: <String, dynamic>{'nos': 3040, 'eles': 980},
);

/// Uma visão de jogo COMUM — nada terminal nela.
Map<String, dynamic> emAndamento({int rodada = 1}) =>
    visaoDeJogo(voceAssento: 0, rodada: rodada);

/// Um aviso FABRICADO, que o livro nunca viu.
///
/// Serve a um caso só, e é o caso que prova que o parâmetro da cutucada não é
/// fonte: se a tela apresentasse o que recebe, ela apresentaria isto.
EncerramentoAutoritativo avisoForjado(String id) => EncerramentoAutoritativo(
  versaoEstado: 999,
  eventoId: id,
  visao: fim(),
);

/// O arquivo sem comentários nem literais de texto.
///
/// Uma varredura crua acusaria a documentação de ser a violação que ela
/// descreve: o comentário que EXPLICA por que não se usa `print` contém a
/// palavra `print`.
String semComentarios(File arquivo) {
  final fonte = arquivo.readAsStringSync();
  final saida = StringBuffer();
  var i = 0;
  String? aspa;
  while (i < fonte.length) {
    final c = fonte[i];
    final proximo = i + 1 < fonte.length ? fonte[i + 1] : '';
    if (aspa != null) {
      if (c == r'\') {
        i += 2;
        continue;
      }
      if (c == aspa) {
        aspa = null;
        saida.write(c);
      }
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
      while (i + 1 < fonte.length &&
          !(fonte[i] == '*' && fonte[i + 1] == '/')) {
        i++;
      }
      i += 2;
      continue;
    }
    if (c == "'" || c == '"') {
      aspa = c;
      saida.write(c);
      i++;
      continue;
    }
    saida.write(c);
    i++;
  }
  return saida.toString();
}

File fonteDeProducao(String caminho) {
  final arquivo = File('lib/$caminho');
  if (!arquivo.existsSync()) {
    throw StateError('não achei lib/$caminho — a suíte roda a partir de app/');
  }
  return arquivo;
}

/// O trecho de [codigo] que vai da primeira ocorrência de [marca] até o
/// fechamento do bloco que se abre depois dela, por contagem de chaves.
///
/// Grosseiro de propósito: não é um analisador de Dart, e não precisa ser. O que
/// se pergunta é se um identificador aparece DENTRO de um método, e para isso
/// contar chaves basta — desde que a fonte já esteja sem comentários e sem
/// literais de texto, que é o que [semComentarios] garante.
String corpoDe(String codigo, RegExp marca) {
  final achado = marca.firstMatch(codigo);
  if (achado == null) {
    throw StateError('não achei ${marca.pattern} no arquivo');
  }
  var i = codigo.indexOf('{', achado.end);
  if (i < 0) throw StateError('${marca.pattern} sem corpo');
  final inicio = i;
  var profundidade = 0;
  while (i < codigo.length) {
    if (codigo[i] == '{') profundidade++;
    if (codigo[i] == '}') {
      profundidade--;
      if (profundidade == 0) return codigo.substring(inicio, i + 1);
    }
    i++;
  }
  throw StateError('${marca.pattern} sem fechamento');
}

String corpoDoBuild(String codigo) => corpoDe(codigo, RegExp(r'Widget\s+build\s*\('));

void main() {
  // =========================================================================
  // A — a fonte do efeito é o envelope autoritativo, e nada mais
  // =========================================================================
  group('A — a fonte é o envelope, e o livro é a única drenagem', () {
    // H01
    testWidgets('H01 o fim chega SEM consumidor e fica pendente', (
      tester,
    ) async {
      final t = Trilho();
      addTearDown(t.encerrar);

      await abrirLongeDaMesa(tester, t);
      await manda(tester, t, fim(), versaoEstado: 4, eventoId: 'fim-A');

      expect(
        t.livro.conhecidos,
        1,
        reason: 'o envelope terminal tem de ser ANOTADO mesmo sem consumidor',
      );
      expect(
        t.estado('fim-A'),
        EstadoDoEfeito.pendente,
        reason: 'sem consumidor não há apresentação — e não há descarte',
      );
    });

    // H02
    testWidgets('H02 o consumidor entra DEPOIS e drena o pendente', (
      tester,
    ) async {
      final t = Trilho();
      addTearDown(t.encerrar);
      final ap = ApresentadorDeBancada();

      await abrirLongeDaMesa(tester, t);
      await manda(tester, t, fim(), versaoEstado: 4, eventoId: 'fim-A');
      expect(t.estado('fim-A'), EstadoDoEfeito.pendente);
      expect(ap.tentativas, 0);

      // A pessoa entra na rota da mesa. Nenhuma mensagem nova do servidor.
      await tester.pumpWidget(comAMesa(t.servico, ap));
      await tester.pumpAndSettle();

      expect(ap.tentativas, 1, reason: 'a entrada drena o livro');
      expect(ap.eventos, <String?>['fim-A']);
      expect(t.estado('fim-A'), EstadoDoEfeito.apresentado);
    });

    // H03
    testWidgets('H03 visão em andamento não registra efeito nenhum', (
      tester,
    ) async {
      final t = Trilho();
      addTearDown(t.encerrar);
      final ap = ApresentadorDeBancada();

      await abrir(tester, t, ap);
      await manda(tester, t, emAndamento(), versaoEstado: 2, eventoId: 'v-2');
      await manda(
        tester,
        t,
        emAndamento(rodada: 2),
        versaoEstado: 3,
        eventoId: 'v-3',
      );

      expect(t.livro.conhecidos, 0, reason: 'só `encerrada` cria efeito');
      expect(ap.tentativas, 0);
    });

    // H04
    testWidgets('H04 o reenvio do retrato terminal não reapresenta', (
      tester,
    ) async {
      final t = Trilho();
      addTearDown(t.encerrar);
      final ap = ApresentadorDeBancada();

      await abrir(tester, t, ap);
      await manda(tester, t, fim(), versaoEstado: 9, eventoId: 'fim-B');
      expect(ap.tentativas, 1);
      expect(t.estado('fim-B'), EstadoDoEfeito.apresentado);

      // Três reenvios do MESMO fim. O retrato é obrigado a se repetir; o efeito
      // não pode.
      for (var i = 0; i < 3; i++) {
        await manda(tester, t, fim(), versaoEstado: 9, eventoId: 'fim-B');
      }

      expect(ap.tentativas, 1, reason: 'reenvio de fim conhecido não apresenta');
      expect(t.estado('fim-B'), EstadoDoEfeito.apresentado);
      expect(t.livro.conhecidos, 1);
    });

    // H05
    testWidgets('H05 a queda e a volta não reapresentam o fim já apresentado', (
      tester,
    ) async {
      final t = Trilho();
      addTearDown(t.encerrar);
      final ap = ApresentadorDeBancada();

      await abrir(tester, t, ap);
      await manda(tester, t, fim(), versaoEstado: 5, eventoId: 'fim-C');
      expect(ap.tentativas, 1);

      // A conexão cai e volta: o socket é outro, e o servidor remanda a mesa
      // inteira — inclusive o fim.
      t.canal.servidorDerruba();
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
      await sentar(tester, t);
      await manda(tester, t, fim(), versaoEstado: 5, eventoId: 'fim-C');

      expect(
        ap.tentativas,
        1,
        reason: 'quem só caiu e voltou não vê o aviso de novo',
      );
      expect(t.estado('fim-C'), EstadoDoEfeito.apresentado);
    });

    // H06
    testWidgets('H06 a cutucada NÃO é fonte: aviso forjado não é apresentado', (
      tester,
    ) async {
      final t = Trilho();
      addTearDown(t.encerrar);
      final ap = ApresentadorDeBancada();

      await abrir(tester, t, ap);
      final cutucar = t.servico.aoEncerrar;
      expect(cutucar, isNotNull, reason: 'a tela ocupa o slot');

      // O livro está VAZIO. Se a tela apresentasse o parâmetro, apresentaria
      // isto — que nunca veio de envelope nenhum.
      cutucar!(avisoForjado('forjado-1'));
      await tester.pumpAndSettle();

      expect(ap.tentativas, 0, reason: 'o parâmetro não é uma segunda fonte');
      expect(t.livro.conhecidos, 0, reason: 'a cutucada não escreve no livro');
    });

    // H07
    testWidgets('H07 com pendente no livro, a cutucada forjada apresenta o '
        'aviso DO LIVRO', (tester) async {
      final t = Trilho();
      addTearDown(t.encerrar);
      final ap = ApresentadorDeBancada();

      await abrirLongeDaMesa(tester, t);
      await manda(tester, t, fim(), versaoEstado: 6, eventoId: 'fim-real');

      // Entra na mesa com um apresentador que recusa, para deixar o efeito
      // pendente e a tela montada ao mesmo tempo.
      ap.resposta = ResultadoDaApresentacao.recusado;
      await tester.pumpWidget(comAMesa(t.servico, ap));
      await tester.pumpAndSettle();
      expect(t.estado('fim-real'), EstadoDoEfeito.pendente);
      final recusas = ap.tentativas;

      ap.resposta = ResultadoDaApresentacao.apresentado;
      t.servico.aoEncerrar!(avisoForjado('forjado-2'));
      await tester.pumpAndSettle();

      expect(ap.tentativas, recusas + 1);
      expect(
        ap.vistos.last.eventoId,
        'fim-real',
        reason: 'o que se apresenta é o do livro, não o do parâmetro',
      );
      expect(t.estado('fim-real'), EstadoDoEfeito.apresentado);
      expect(t.livro.conhecidos, 1, reason: 'o forjado nunca entrou no livro');
    });
  });

  // =========================================================================
  // B — o modo legado, que não tem carimbo e não pode ganhar um
  // =========================================================================
  group('B — modo legado', () {
    // H08
    testWidgets('H08 envelope sem carimbo apresenta uma vez e não fabrica id', (
      tester,
    ) async {
      final t = Trilho();
      addTearDown(t.encerrar);
      final ap = ApresentadorDeBancada();

      await abrir(tester, t, ap);
      await manda(tester, t, fim());

      expect(ap.tentativas, 1);
      expect(
        ap.vistos.single.eventoId,
        isNull,
        reason: 'inventar um id aqui seria fingir autoridade do servidor',
      );
      expect(ap.vistos.single.versaoEstado, isNull);
      expect(t.estado(), EstadoDoEfeito.apresentado);
    });

    // H09
    testWidgets('H09 o legado também espera por consumidor', (tester) async {
      final t = Trilho();
      addTearDown(t.encerrar);
      final ap = ApresentadorDeBancada();

      await abrirLongeDaMesa(tester, t);
      await manda(tester, t, fim());
      expect(
        t.estado(),
        EstadoDoEfeito.pendente,
        reason: 'sem carimbo continua sendo um fim, e um fim espera',
      );

      await tester.pumpWidget(comAMesa(t.servico, ap));
      await tester.pumpAndSettle();

      expect(ap.tentativas, 1);
      expect(t.estado(), EstadoDoEfeito.apresentado);
    });

    // H10
    testWidgets('H10 dois legados na mesma mesa colapsam num efeito', (
      tester,
    ) async {
      final t = Trilho();
      addTearDown(t.encerrar);
      final ap = ApresentadorDeBancada();

      await abrir(tester, t, ap);
      await manda(tester, t, fim());
      await manda(tester, t, fim());
      await manda(tester, t, fim());

      expect(ap.tentativas, 1);
      expect(
        t.livro.conhecidos,
        1,
        reason: 'a dedup do legado é mais fraca, e está declarada como tal',
      );
    });

    // H11
    testWidgets('H11 legado e carimbado não colidem entre si', (tester) async {
      final t = Trilho();
      addTearDown(t.encerrar);
      final ap = ApresentadorDeBancada();

      await abrir(tester, t, ap);
      await manda(tester, t, fim());
      await manda(tester, t, fim(), versaoEstado: 12, eventoId: 'fim-D');

      expect(ap.tentativas, 2);
      expect(ap.eventos, <String?>[null, 'fim-D']);
      expect(t.estado(), EstadoDoEfeito.apresentado);
      expect(t.estado('fim-D'), EstadoDoEfeito.apresentado);
      expect(t.livro.conhecidos, 2);
    });
  });

  // =========================================================================
  // C — toda forma de apresentação que não acontece devolve o efeito
  // =========================================================================
  group('C — a falha adia, não perde', () {
    // H12
    testWidgets('H12 recusa devolve o efeito, e a reentrada apresenta', (
      tester,
    ) async {
      final t = Trilho();
      addTearDown(t.encerrar);
      final ap = ApresentadorDeBancada(ResultadoDaApresentacao.recusado);

      await abrir(tester, t, ap);
      await manda(tester, t, fim(), versaoEstado: 3, eventoId: 'fim-E');

      expect(ap.tentativas, 1, reason: 'tentou');
      expect(
        t.estado('fim-E'),
        EstadoDoEfeito.pendente,
        reason: 'não deu — então volta a esperar',
      );

      ap.resposta = ResultadoDaApresentacao.apresentado;
      await tester.pumpWidget(semAMesa(t.servico));
      await tester.pumpAndSettle();
      await tester.pumpWidget(comAMesa(t.servico, ap));
      await tester.pumpAndSettle();

      expect(ap.tentativas, 2);
      expect(ap.vistos.last.eventoId, 'fim-E');
      expect(t.estado('fim-E'), EstadoDoEfeito.apresentado);
    });

    // H13
    testWidgets('H13 cancelamento devolve o efeito, e a reentrada apresenta', (
      tester,
    ) async {
      final t = Trilho();
      addTearDown(t.encerrar);
      final ap = ApresentadorDeBancada(ResultadoDaApresentacao.cancelado);

      await abrir(tester, t, ap);
      await manda(tester, t, fim(), versaoEstado: 3, eventoId: 'fim-F');

      expect(ap.tentativas, 1);
      expect(t.estado('fim-F'), EstadoDoEfeito.pendente);

      ap.resposta = ResultadoDaApresentacao.apresentado;
      await tester.pumpWidget(semAMesa(t.servico));
      await tester.pumpAndSettle();
      await tester.pumpWidget(comAMesa(t.servico, ap));
      await tester.pumpAndSettle();

      expect(ap.tentativas, 2);
      expect(t.estado('fim-F'), EstadoDoEfeito.apresentado);
    });

    // H14
    testWidgets('H14 dispose ANTES do quadro devolve o efeito', (tester) async {
      final t = Trilho();
      addTearDown(t.encerrar);
      final ap = ApresentadorDeBancada();

      await abrir(tester, t, ap);
      // Chegou e foi REIVINDICADO; nenhum quadro rodou ainda.
      await mandaSemQuadro(tester, t, fim(), versaoEstado: 8, eventoId: 'fim-G');
      expect(t.estado('fim-G'), EstadoDoEfeito.reivindicado);
      expect(ap.tentativas, 0, reason: 'reivindicar não é apresentar');

      // A tela morre no meio do caminho.
      await tester.pumpWidget(semAMesa(t.servico));
      await tester.pumpAndSettle();

      expect(ap.tentativas, 0, reason: 'ninguém apresentou nada');
      expect(
        t.estado('fim-G'),
        EstadoDoEfeito.pendente,
        reason: 'o dispose devolve o que tinha reivindicado',
      );

      await tester.pumpWidget(comAMesa(t.servico, ap));
      await tester.pumpAndSettle();
      expect(ap.tentativas, 1);
      expect(t.estado('fim-G'), EstadoDoEfeito.apresentado);
    });

    // H15
    testWidgets('H15 a troca de transporte devolve o efeito do transporte '
        'anterior', (tester) async {
      final antigo = Trilho();
      final novo = Trilho();
      addTearDown(antigo.encerrar);
      addTearDown(novo.encerrar);
      final ap = ApresentadorDeBancada();

      await abrir(tester, antigo, ap);
      await mandaSemQuadro(
        tester,
        antigo,
        fim(),
        versaoEstado: 2,
        eventoId: 'fim-H',
      );
      expect(antigo.estado('fim-H'), EstadoDoEfeito.reivindicado);

      // Outro transporte no mesmo lugar da árvore.
      await tester.pumpWidget(comAMesa(novo.servico, ap));
      await tester.pumpAndSettle();

      expect(ap.tentativas, 0);
      expect(
        antigo.estado('fim-H'),
        EstadoDoEfeito.pendente,
        reason: 'a posse do vínculo anterior voltou ao livro dele',
      );
      expect(
        novo.livro.conhecidos,
        0,
        reason: 'o livro é do transporte — o novo nasce vazio',
      );

      // Voltar ao transporte antigo drena o que ficou.
      await tester.pumpWidget(comAMesa(antigo.servico, ap));
      await tester.pumpAndSettle();
      expect(ap.tentativas, 1);
      expect(ap.vistos.single.eventoId, 'fim-H');
      expect(antigo.estado('fim-H'), EstadoDoEfeito.apresentado);
    });

    // H16
    testWidgets('H16 exceção SÍNCRONA do apresentador devolve o efeito', (
      tester,
    ) async {
      final t = Trilho();
      addTearDown(t.encerrar);
      final ap = ApresentadorInstavel(FormaDoEstouro.naNaChamada);

      await abrir(tester, t, ap);
      await manda(tester, t, fim(), versaoEstado: 7, eventoId: 'fim-I');

      expect(ap.chamadas, 1, reason: 'foi chamado');
      expect(ap.vistos, isEmpty, reason: 'e nada apresentou');
      expect(
        t.estado('fim-I'),
        EstadoDoEfeito.pendente,
        reason: 'a exceção não pode levar a reivindicação com ela',
      );
      expect(
        tester.takeException(),
        isStateError,
        reason: 'o estouro é RELATADO, e não engolido',
      );

      // Reentrada com um apresentador saudável: o MESMO evento aparece.
      ap.forma = FormaDoEstouro.nenhum;
      await tester.pumpWidget(semAMesa(t.servico));
      await tester.pumpAndSettle();
      await tester.pumpWidget(comAMesa(t.servico, ap));
      await tester.pumpAndSettle();

      expect(ap.chamadas, 2);
      expect(ap.vistos.single.eventoId, 'fim-I');
      expect(t.estado('fim-I'), EstadoDoEfeito.apresentado);
      expect(
        tester.takeException(),
        isNull,
        reason: 'nenhuma exceção antiga reaparece',
      );
    });

    // H17
    testWidgets('H17 futuro do apresentador com ERRO devolve o efeito', (
      tester,
    ) async {
      final t = Trilho();
      addTearDown(t.encerrar);
      final ap = ApresentadorInstavel(FormaDoEstouro.noFuturo);

      await abrir(tester, t, ap);
      await manda(tester, t, fim(), versaoEstado: 7, eventoId: 'fim-J');

      expect(ap.chamadas, 1);
      expect(ap.vistos, isEmpty);
      expect(t.estado('fim-J'), EstadoDoEfeito.pendente);
      expect(tester.takeException(), isStateError);

      ap.forma = FormaDoEstouro.nenhum;
      await tester.pumpWidget(semAMesa(t.servico));
      await tester.pumpAndSettle();
      await tester.pumpWidget(comAMesa(t.servico, ap));
      await tester.pumpAndSettle();

      expect(ap.chamadas, 2);
      expect(ap.vistos.single.eventoId, 'fim-J');
      expect(t.estado('fim-J'), EstadoDoEfeito.apresentado);
      expect(tester.takeException(), isNull);
    });

    // H18 — o caso obrigatório: o CANAL DE RELATO também falha.
    //
    // A ordem é o objeto do caso. `liberar` vem ANTES de `reportError`; se
    // alguém invertesse para "relatar antes de liberar", a exceção do relato
    // pularia a devolução e o efeito ficaria travado em `reivindicado` por um
    // dono que já desistiu — a perda silenciosa desta OS, por outra porta.
    //
    // A exceção do relato escapa por um `addPostFrameCallback`, isto é, num
    // futuro que ninguém aguarda. O `flutter_test` reprova o teste em qualquer
    // erro assíncrono não tratado, então o pump que roda o quadro acontece
    // dentro de uma zona guardada — a fuga é CAPTURADA e ASSERTADA aqui, em vez
    // de derrubar o caso.
    testWidgets('H18 quando o próprio relato estoura, o efeito já voltou a '
        'pendente', (tester) async {
      final t = Trilho();
      addTearDown(t.encerrar);
      final ap = ApresentadorInstavel(FormaDoEstouro.naNaChamada);

      await abrir(tester, t, ap);

      final manipuladorOriginal = FlutterError.onError;
      addTearDown(() => FlutterError.onError = manipuladorOriginal);
      final relatados = <Object>[];
      FlutterError.onError = (detalhes) {
        relatados.add(detalhes.exception);
        throw StateError('o canal de relato também falhou');
      };

      final fugas = <Object>[];
      t.canal.servidorEnvia(
        envelopeEstado(fim(), versaoEstado: 11, eventoId: 'fim-K'),
      );
      await runZonedGuarded(() async {
        await tester.idle();
        await tester.pump();
        await tester.idle();
      }, (erro, _) => fugas.add(erro))!;

      // O manipulador global volta ao lugar ANTES de qualquer `expect`: um
      // `expect` que falhasse com o gancho quebrado no lugar viraria um estouro
      // dentro do estouro, e o laudo perderia a informação.
      FlutterError.onError = manipuladorOriginal;

      expect(ap.chamadas, 1, reason: 'o apresentador foi chamado e estourou');
      expect(
        relatados,
        hasLength(1),
        reason: 'o estouro do apresentador foi relatado uma vez',
      );
      expect(relatados.single, isStateError);
      expect(
        fugas.single,
        isStateError,
        reason: 'a falha DO RELATO escapou — é o que o caso instalou',
      );
      expect(
        (fugas.single as StateError).message,
        contains('relato'),
        reason: 'a fuga é a do canal de relato, não a do apresentador',
      );
      expect(
        t.estado('fim-K'),
        EstadoDoEfeito.pendente,
        reason: 'a devolução acontece ANTES do relato — esta é a ordem sob '
            'julgamento',
      );

      // Reentrada com apresentador saudável e canal de relato de volta ao
      // normal: o MESMO evento é apresentado e confirmado.
      ap.forma = FormaDoEstouro.nenhum;
      await tester.pumpWidget(semAMesa(t.servico));
      await tester.pumpAndSettle();
      await tester.pumpWidget(comAMesa(t.servico, ap));
      await tester.pumpAndSettle();

      expect(ap.chamadas, 2);
      expect(ap.vistos.single.eventoId, 'fim-K');
      expect(t.estado('fim-K'), EstadoDoEfeito.apresentado);
      expect(
        tester.takeException(),
        isNull,
        reason: 'nada de velho reaparece depois da recuperação',
      );
    });

    // H19
    testWidgets('H19 a segunda tentativa bem-sucedida confirma UMA vez só', (
      tester,
    ) async {
      final t = Trilho();
      addTearDown(t.encerrar);
      final ap = ApresentadorDeBancada(ResultadoDaApresentacao.recusado);

      await abrir(tester, t, ap);
      await manda(tester, t, fim(), versaoEstado: 4, eventoId: 'fim-L');
      expect(t.estado('fim-L'), EstadoDoEfeito.pendente);

      ap.resposta = ResultadoDaApresentacao.apresentado;
      await tester.pumpWidget(semAMesa(t.servico));
      await tester.pumpAndSettle();
      await tester.pumpWidget(comAMesa(t.servico, ap));
      await tester.pumpAndSettle();
      expect(t.estado('fim-L'), EstadoDoEfeito.apresentado);

      // Mais reentradas e mais reenvios: nada acontece de novo.
      for (var i = 0; i < 2; i++) {
        await tester.pumpWidget(semAMesa(t.servico));
        await tester.pumpAndSettle();
        await tester.pumpWidget(comAMesa(t.servico, ap));
        await tester.pumpAndSettle();
        await manda(tester, t, fim(), versaoEstado: 4, eventoId: 'fim-L');
      }

      expect(
        ap.tentativas,
        2,
        reason: 'uma recusa e uma apresentação — e mais nada',
      );
      expect(t.estado('fim-L'), EstadoDoEfeito.apresentado);
    });
  });

  // =========================================================================
  // D — a posse: um dono antigo não mexe no efeito de um dono novo
  // =========================================================================
  group('D — posse', () {
    // H20 — a posse morta encontra um vínculo vivo do outro lado.
    //
    // A ordem é o caso todo, e ela é estreita. Uma chave nova força um `State`
    // novo no MESMO lugar da árvore, e num pump só acontecem, nesta ordem: o
    // vínculo 2 nasce (fase de build), o vínculo 1 é descartado (finalizeTree) e
    // só então o quadro que a posse 1 havia agendado roda. É a única sequência
    // em que o callback da posse morta chega depois de existir um dono novo.
    //
    // Duas idas e voltas normais de rota NÃO produzem esta ordem: ali o
    // `dispose` cai num quadro anterior ao da montagem seguinte, e é o que os
    // casos H14 e H30 percorrem.
    testWidgets('H20 a posse antiga não confirma nem perde o efeito quando o '
        'vínculo novo já nasceu', (tester) async {
      final t = Trilho();
      addTearDown(t.encerrar);
      final ap = ApresentadorDeBancada();

      await abrir(tester, t, ap);
      // A posse 1 reivindica; o quadro dela está agendado e não rodou.
      await mandaSemQuadro(tester, t, fim(), versaoEstado: 2, eventoId: 'fim-M');
      expect(t.estado('fim-M'), EstadoDoEfeito.reivindicado);

      await tester.pumpWidget(
        EscopoTransporte(
          online: t.servico,
          child: MaterialApp(
            home: LobbyOnline(
              key: const ValueKey<String>('vinculo-2'),
              apresentador: ap,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        ap.tentativas,
        0,
        reason: 'a posse morta não abriu diálogo nenhum',
      );
      expect(
        t.estado('fim-M'),
        EstadoDoEfeito.pendente,
        reason: 'nem confirmou: o efeito voltou a esperar, e não se perdeu',
      );
      expect(t.livro.conhecidos, 1);

      // A próxima entrada legítima o encontra e o apresenta — uma vez.
      await tester.pumpWidget(semAMesa(t.servico));
      await tester.pumpAndSettle();
      await tester.pumpWidget(comAMesa(t.servico, ap));
      await tester.pumpAndSettle();

      expect(ap.tentativas, 1);
      expect(ap.vistos.single.eventoId, 'fim-M');
      expect(t.estado('fim-M'), EstadoDoEfeito.apresentado);
    });

    // H21 — unidade do livro. A posse é o invariante, e aqui ela é medida sem
    // widget nenhum: um `confirmar` de dono errado não pode mudar nada.
    test('H21 confirmar e liberar exigem a MESMA posse', () {
      final livro = LivroDeEfeitosTerminais();
      final aviso = EncerramentoAutoritativo(
        versaoEstado: 1,
        eventoId: 'x',
        visao: <String, dynamic>{'encerrada': true},
      );
      expect(livro.registrar(aviso), same(aviso));
      expect(livro.registrar(aviso), isNull, reason: 'já era conhecido');

      final dono = PosseDoEfeito();
      final intruso = PosseDoEfeito();
      expect(livro.reivindicar(dono), same(aviso));
      expect(livro.estadoDe('x'), EstadoDoEfeito.reivindicado);

      expect(livro.reivindicar(intruso), isNull, reason: 'não há pendente');
      expect(livro.confirmar(intruso, aviso), isFalse);
      expect(
        livro.estadoDe('x'),
        EstadoDoEfeito.reivindicado,
        reason: 'o intruso não confirma o que não é dele',
      );
      expect(livro.liberar(intruso, aviso), isFalse);
      expect(livro.estadoDe('x'), EstadoDoEfeito.reivindicado);
      expect(livro.liberarTudoDe(intruso), 0);
      expect(livro.estadoDe('x'), EstadoDoEfeito.reivindicado);

      expect(livro.confirmar(dono, aviso), isTrue);
      expect(livro.estadoDe('x'), EstadoDoEfeito.apresentado);
      expect(
        livro.confirmar(dono, aviso),
        isFalse,
        reason: 'apresentado é fim de linha',
      );
      expect(livro.liberar(dono, aviso), isFalse);
      expect(livro.estadoDe('x'), EstadoDoEfeito.apresentado);
      expect(livro.temPendente, isFalse);
    });

    // H22
    test('H22 liberarTudoDe solta só o que é do dono', () {
      final livro = LivroDeEfeitosTerminais();
      final um = EncerramentoAutoritativo(
        versaoEstado: 1,
        eventoId: 'um',
        visao: const <String, dynamic>{},
      );
      final dois = EncerramentoAutoritativo(
        versaoEstado: 2,
        eventoId: 'dois',
        visao: const <String, dynamic>{},
      );
      livro.registrar(um);
      livro.registrar(dois);

      final a = PosseDoEfeito();
      final b = PosseDoEfeito();
      expect(livro.reivindicar(a), same(um), reason: 'o mais antigo primeiro');
      expect(livro.reivindicar(b), same(dois));

      expect(livro.liberarTudoDe(a), 1);
      expect(livro.estadoDe('um'), EstadoDoEfeito.pendente);
      expect(
        livro.estadoDe('dois'),
        EstadoDoEfeito.reivindicado,
        reason: 'o efeito de B não é da alçada de A',
      );

      livro.limpar();
      expect(livro.conhecidos, 0);
      expect(livro.temPendente, isFalse);
    });
  });

  // =========================================================================
  // E — duplicatas e independência entre eventos
  // =========================================================================
  group('E — idempotência e independência', () {
    // H23
    testWidgets('H23 duplicata ANTES da confirmação não abre um segundo', (
      tester,
    ) async {
      final t = Trilho();
      addTearDown(t.encerrar);
      final ap = ApresentadorDeBancada();

      await abrir(tester, t, ap);
      await mandaSemQuadro(tester, t, fim(), versaoEstado: 5, eventoId: 'fim-N');
      expect(t.estado('fim-N'), EstadoDoEfeito.reivindicado);

      // Duas duplicatas na janela entre a reivindicação e o quadro.
      await mandaSemQuadro(tester, t, fim(), versaoEstado: 5, eventoId: 'fim-N');
      await mandaSemQuadro(tester, t, fim(), versaoEstado: 5, eventoId: 'fim-N');
      expect(ap.tentativas, 0);

      await tester.pumpAndSettle();
      expect(ap.tentativas, 1, reason: 'uma reivindicação, uma apresentação');
      expect(t.estado('fim-N'), EstadoDoEfeito.apresentado);
      expect(t.livro.conhecidos, 1);
    });

    // H24
    testWidgets('H24 dois eventos distintos são apresentados e não colidem', (
      tester,
    ) async {
      final t = Trilho();
      addTearDown(t.encerrar);
      final ap = ApresentadorDeBancada();

      await abrir(tester, t, ap);
      await manda(tester, t, fim(), versaoEstado: 20, eventoId: 'fim-O');
      await manda(tester, t, fim(), versaoEstado: 21, eventoId: 'fim-P');

      expect(ap.eventos, <String?>['fim-O', 'fim-P']);
      expect(t.estado('fim-O'), EstadoDoEfeito.apresentado);
      expect(t.estado('fim-P'), EstadoDoEfeito.apresentado);
      expect(t.livro.conhecidos, 2);
    });

    // H25
    testWidgets('H25 dois eventos no MESMO quadro saem ambos, em ordem', (
      tester,
    ) async {
      final t = Trilho();
      addTearDown(t.encerrar);
      final ap = ApresentadorDeBancada();

      await abrir(tester, t, ap);
      await mandaSemQuadro(tester, t, fim(), versaoEstado: 30, eventoId: 'p-1');
      await mandaSemQuadro(tester, t, fim(), versaoEstado: 31, eventoId: 'p-2');
      expect(t.livro.conhecidos, 2);
      expect(ap.tentativas, 0);

      await tester.pumpAndSettle();

      expect(
        ap.eventos,
        <String?>['p-1', 'p-2'],
        reason: 'a ordem é a da declaração do servidor',
      );
      expect(t.estado('p-1'), EstadoDoEfeito.apresentado);
      expect(t.estado('p-2'), EstadoDoEfeito.apresentado);
    });

    // H26
    testWidgets('H26 um evento recusado não contamina o outro', (tester) async {
      final t = Trilho();
      addTearDown(t.encerrar);
      final ap = ApresentadorDeBancada(ResultadoDaApresentacao.recusado);

      await abrir(tester, t, ap);
      await manda(tester, t, fim(), versaoEstado: 40, eventoId: 'q-1');
      expect(t.estado('q-1'), EstadoDoEfeito.pendente);

      ap.resposta = ResultadoDaApresentacao.apresentado;
      await manda(tester, t, fim(), versaoEstado: 41, eventoId: 'q-2');

      expect(
        t.estado('q-2'),
        EstadoDoEfeito.apresentado,
        reason: 'o segundo é um efeito próprio',
      );
      // A cutucada de `q-2` drena o livro pelo MAIS ANTIGO pendente, que é
      // `q-1`. Independência não significa ordem invertida: os dois saem, e
      // saem na ordem em que o servidor os declarou.
      expect(t.estado('q-1'), EstadoDoEfeito.apresentado);
      expect(ap.eventos, <String?>['q-1', 'q-1', 'q-2']);
    });

    // H27
    testWidgets('H27 sair da mesa zera o livro; a próxima mesa é outra', (
      tester,
    ) async {
      final t = Trilho();
      addTearDown(t.encerrar);
      final ap = ApresentadorDeBancada();

      await abrir(tester, t, ap);
      await manda(tester, t, fim(), versaoEstado: 50, eventoId: 'r-1');
      expect(t.livro.conhecidos, 1);

      t.servico.sair();
      await tester.pumpAndSettle();
      expect(
        t.livro.conhecidos,
        0,
        reason: 'o livro é da MESA, e a mesa acabou para esta pessoa',
      );

      // A mesa nova pode reusar o mesmo id — é outro contador.
      await sentar(tester, t);
      await manda(tester, t, fim(), versaoEstado: 50, eventoId: 'r-1');
      expect(ap.tentativas, 2, reason: 'outra mesa, outro fim');
      expect(t.estado('r-1'), EstadoDoEfeito.apresentado);
    });

    // H28
    test('H28 dois transportes têm livros independentes', () {
      final a = Trilho();
      final b = Trilho();
      addTearDown(a.encerrar);
      addTearDown(b.encerrar);

      expect(
        identical(a.livro, b.livro),
        isFalse,
        reason: 'o livro é por transporte, conforme o contrato declarado',
      );
      final aviso = EncerramentoAutoritativo(
        versaoEstado: 1,
        eventoId: 'z',
        visao: const <String, dynamic>{},
      );
      a.livro.registrar(aviso);
      expect(a.livro.conhecidos, 1);
      expect(b.livro.conhecidos, 0);
    });
  });

  // =========================================================================
  // F — o ciclo de vida da assinatura
  // =========================================================================
  group('F — assinatura', () {
    // H29
    testWidgets('H29 reconstruções repetidas não criam assinatura a mais', (
      tester,
    ) async {
      final t = Trilho();
      addTearDown(t.encerrar);
      final ap = ApresentadorDeBancada();

      await abrir(tester, t, ap);
      final assinaturaInicial = t.servico.aoEncerrar;
      expect(assinaturaInicial, isNotNull);

      // Doze reconstruções por caminhos diferentes: notificação do transporte,
      // quadro solto e a MESMA árvore pumpada de novo.
      for (var i = 0; i < 4; i++) {
        await manda(
          tester,
          t,
          emAndamento(rodada: i + 1),
          versaoEstado: 100 + i,
          eventoId: 'and-$i',
        );
        await tester.pump();
        await tester.pumpWidget(comAMesa(t.servico, ap));
        await tester.pumpAndSettle();
      }

      expect(
        identical(t.servico.aoEncerrar, assinaturaInicial),
        isTrue,
        reason: 'o vínculo nasce em didChangeDependencies, não em build',
      );

      await manda(tester, t, fim(), versaoEstado: 200, eventoId: 'fim-Q');
      expect(
        ap.tentativas,
        1,
        reason: 'assinatura duplicada apareceria como diálogo duplicado',
      );
    });

    // H30
    testWidgets('H30 a ausência temporária de tela não descarta o evento', (
      tester,
    ) async {
      final t = Trilho();
      addTearDown(t.encerrar);
      final ap = ApresentadorDeBancada();

      await abrir(tester, t, ap);
      // Sai da rota da mesa. O transporte continua vivo.
      await tester.pumpWidget(semAMesa(t.servico));
      await tester.pumpAndSettle();
      expect(
        t.servico.aoEncerrar,
        isNull,
        reason: 'o slot ficou vazio — é a janela do defeito',
      );

      await manda(tester, t, fim(), versaoEstado: 60, eventoId: 'fim-R');
      expect(ap.tentativas, 0);
      expect(t.estado('fim-R'), EstadoDoEfeito.pendente);

      // Três idas e voltas: o efeito continua esperando até que alguém o veja.
      for (var i = 0; i < 2; i++) {
        await tester.pumpWidget(semAMesa(t.servico));
        await tester.pumpAndSettle();
      }
      expect(t.estado('fim-R'), EstadoDoEfeito.pendente);

      await tester.pumpWidget(comAMesa(t.servico, ap));
      await tester.pumpAndSettle();
      expect(ap.tentativas, 1);
      expect(t.estado('fim-R'), EstadoDoEfeito.apresentado);
    });

    // H31 — varredura de fonte. Não é substituto dos casos acima; é o que os
    // protege de uma reescrita futura que os satisfaça por acidente.
    test('H31 a assinatura não é escrita dentro de build()', () {
      final codigo = semComentarios(fonteDeProducao('casca/lobby_online.dart'));
      final corpo = corpoDoBuild(codigo);

      expect(
        corpo.contains('aoEncerrar'),
        isFalse,
        reason: 'escrever no slot dentro de build criaria uma assinatura por '
            'quadro',
      );
      expect(corpo.contains('_ligarAoEncerramento'), isFalse);
      expect(corpo.contains('reivindicar'), isFalse);
      expect(corpo.contains('PosseDoEfeito'), isFalse);
      expect(
        codigo.contains('_ligarAoEncerramento(srv)'),
        isTrue,
        reason: 'e o vínculo tem de nascer em algum lugar',
      );
    });
  });

  // =========================================================================
  // G — esta camada não escreve log
  // =========================================================================
  group('G — sem log e sem telemetria nesta camada', () {
    // H32
    //
    // A auditoria proíbe log aqui porque por esta camada passam ids de carta.
    // O que se prova é ausência de escrita DIRETA: `FlutterError.reportError`
    // não é log — é o canal do framework, e o manipulador que a aplicação
    // instalar pode muito bem mandar a ocorrência para o console ou para o
    // Crashlytics. Afirmar "não há registro nenhum" seria falso.
    test('H32 nenhum print, debugPrint, log ou telemetria direta', () {
      final arquivos = <String>[
        'casca/lobby_online.dart',
        'casca/mesa_online/encerramento_da_mesa.dart',
        'services/livro_de_efeitos_terminais.dart',
        'services/ordem_da_visao.dart',
      ];
      final proibidos = <RegExp>[
        RegExp(r'\bprint\s*\('),
        RegExp(r'\bdebugPrint\b'),
        RegExp(r'(^|[^.\w])log\s*\('),
        RegExp(r'\bdeveloper\.log\b'),
        RegExp(r'\bCrashlytics\b', caseSensitive: false),
        RegExp(r'\bAnalytics\b', caseSensitive: false),
        RegExp(r'\bstderr\b'),
        RegExp(r'\bstdout\b'),
      ];

      for (final caminho in arquivos) {
        final codigo = semComentarios(fonteDeProducao(caminho));
        for (final padrao in proibidos) {
          expect(
            padrao.hasMatch(codigo),
            isFalse,
            reason: '$caminho não pode escrever log: casou com ${padrao.pattern}',
          );
        }
      }
    });

    // H33
    test('H33 o efeito terminal não nasce da visão, e o livro é a drenagem', () {
      final lobby = semComentarios(fonteDeProducao('casca/lobby_online.dart'));

      // A palavra `encerrada` não aparece em código nenhum desta tela: o efeito
      // não tem como ser inferido do retrato, que é o que repetiria o aviso a
      // cada reconexão. `lobby_online.dart` é a tela INTEIRA do online, então
      // este é um escopo largo de propósito — e ele passa.
      expect(
        lobby.contains('encerrada'),
        isFalse,
        reason: 'nenhum caminho desta tela lê o campo terminal da visão',
      );

      // Os três métodos do efeito, e SÓ eles. A tela desenha a mesa a partir de
      // `srv.visao`, e isso é retrato — legítimo, e fora do que se julga aqui.
      // Medir o arquivo todo confundiria as duas coisas.
      for (final marca in <RegExp>[
        RegExp(r'void\s+_drenar\s*\('),
        RegExp(r'Future<void>\s+_apresentar\s*\('),
        RegExp(r'void\s+_ligarAoEncerramento\s*\('),
      ]) {
        final corpo = corpoDe(lobby, marca);
        expect(
          RegExp(r'\.visao\b').hasMatch(corpo),
          isFalse,
          reason: '${marca.pattern} não pode ler a visão crua',
        );
      }

      // A drenagem é pelo livro, e é a única.
      expect(
        RegExp(r'efeitosTerminais\.reivindicar').allMatches(lobby).length,
        1,
        reason: 'uma só porta de entrada do efeito',
      );
      expect(
        corpoDe(lobby, RegExp(r'void\s+_drenar\s*\(')),
        contains('efeitosTerminais.reivindicar'),
      );

      final apresentador = semComentarios(
        fonteDeProducao('casca/mesa_online/encerramento_da_mesa.dart'),
      );
      expect(
        RegExp(r'encerramento\.visao').hasMatch(apresentador),
        isFalse,
        reason: 'o apresentador não interpreta o resultado',
      );

      // O livro só é escrito por um ponto, e é o de ordem.
      final ordem = semComentarios(
        fonteDeProducao('services/ordem_da_visao.dart'),
      );
      expect(
        RegExp(r'efeitos\.registrar').allMatches(ordem).length,
        1,
        reason: 'um só escritor de encerramento no livro',
      );
      expect(
        corpoDe(ordem, RegExp(r'talvezEncerramento\s*\(')),
        contains('efeitos.registrar'),
      );
    });
  });
}
