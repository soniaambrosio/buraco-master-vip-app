// encerramento_pendente_test.dart — o aviso de fim espera por quem o veja.
//
// ---------------------------------------------------------------------------
// O DEFEITO QUE ESTE ARQUIVO PERSEGUE
// ---------------------------------------------------------------------------
//
// A suíte irmã (`encerramento_na_ui_test.dart`) prova que o encerramento é
// apresentado UMA vez. Ela não prova que ele é apresentado ALGUMA vez, e a
// diferença é uma janela real: o slot `aoEncerrar` fica vazio entre o `dispose`
// de um vínculo e o `didChangeDependencies` do seguinte, e fica vazio o tempo
// todo enquanto a pessoa não está na rota da mesa.
//
// Nessa janela, o desenho antigo marcava o efeito como resolvido e ninguém o
// via. O defeito não deixa rastro: nenhum erro, nenhum log, nenhum teste
// vermelho — um diálogo que simplesmente não aparece. É por isso que quase todo
// caso aqui mede ESTADO do livro, e não só quantidade de diálogos: contar
// diálogos prova que não houve dois; só o estado prova que o que não apareceu
// ainda vai aparecer.
//
// ---------------------------------------------------------------------------
// O QUE É FALSO AQUI
// ---------------------------------------------------------------------------
//
// O socket (`CanalFalso`, emprestado da bancada) e o APRESENTADOR. O
// `OnlineService`, a `OrdemDaVisao`, o `LivroDeEfeitosTerminais` e a
// `LobbyOnline` são os de produção — é justamente a costura entre eles que está
// sob julgamento, e trocar qualquer um por dublê provaria o dublê.
//
// O apresentador daqui, ao contrário do da suíte irmã, sabe RECUSAR: sem isso
// não há como provar que uma apresentação que não acontece devolve o efeito ao
// livro em vez de engoli-lo.
//
// Nenhum caso abre rede, toca relógio de verdade ou fala com Firebase.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:buraco_master_vip/casca/escopo_transporte.dart';
import 'package:buraco_master_vip/casca/lobby_online.dart';
import 'package:buraco_master_vip/casca/mesa_online/encerramento_da_mesa.dart';
import 'package:buraco_master_vip/casca/mesa_online/mesa_online_screen.dart';
import 'package:buraco_master_vip/services/online_service.dart';

import 'bancada_online.dart';

// ===========================================================================
// A bancada desta suíte
// ===========================================================================

/// O apresentador do teste: conta, guarda e responde o que mandarem.
class ApresentadorControlado implements ApresentadorDeEncerramento {
  ApresentadorControlado([this.resposta = ResultadoDaApresentacao.apresentado]);

  /// O que a próxima apresentação vai responder. Mutável de propósito: é assim
  /// que um caso prova "falhou, e depois conseguiu".
  ResultadoDaApresentacao resposta;

  final List<EncerramentoAutoritativo> anuncios = [];
  final List<VoidCallback> saidas = [];

  int get quantos => anuncios.length;

  @override
  Future<ResultadoDaApresentacao> apresentar(
    BuildContext context,
    EncerramentoAutoritativo encerramento, {
    required VoidCallback aoSairDaMesa,
  }) async {
    // A TENTATIVA É REGISTRADA MESMO QUANDO RECUSA. Contar só os sucessos
    // esconderia a diferença entre "ninguém tentou" e "tentou e não deu", que é
    // a distinção que o caso da falha precisa fazer.
    anuncios.add(encerramento);
    saidas.add(aoSairDaMesa);
    return resposta;
  }
}

/// Um transporte de produção com o socket falso.
class Fio {
  Fio() {
    online = OnlineService(
      obterIdToken: () async => 'token-de-teste',
      endpoint: Uri.parse(kEndpointDeTeste),
      abrirCanal: (_) {
        final c = CanalFalso();
        canais.add(c);
        return c;
      },
    );
  }

  final List<CanalFalso> canais = [];
  late final OnlineService online;

  CanalFalso get canal => canais.last;
  LivroDeEfeitosTerminais get livro => online.efeitosTerminais;

  void fechar() => online.dispose();
}

/// A árvore COM a rota da mesa.
Widget arvore(OnlineService srv, ApresentadorDeEncerramento ap) =>
    EscopoTransporte(
      online: srv,
      child: MaterialApp(home: LobbyOnline(apresentador: ap)),
    );

/// A mesma árvore SEM a rota da mesa.
///
/// O transporte continua vivo — ele é da raiz, e sair da tela do online não o
/// derruba. O que some é o CONSUMIDOR, que é exatamente a condição que o
/// desenho antigo não sobrevivia.
Widget arvoreSemAMesa(OnlineService srv) => EscopoTransporte(
  online: srv,
  child: const MaterialApp(home: Scaffold(body: SizedBox())),
);

/// Superfície de telefone: a mesa não cabe nos 800x600 do `flutter_test`.
void telefone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

/// O servidor aceita a credencial e dá um assento.
Future<void> entrarNaMesa(WidgetTester tester, Fio f, {int assento = 0}) async {
  f.canal.servidorEnvia({'tipo': 'autenticado'});
  await tester.pumpAndSettle();
  f.canal.servidorEnvia({
    'tipo': 'entrou',
    'codigo': 'BURACO-0001',
    'assento': assento,
  });
  await tester.pumpAndSettle();
}

/// Monta a tela e leva a conexão até o assento — o mesmo caminho da pessoa.
Future<void> abrirAMesa(
  WidgetTester tester,
  Fio f,
  ApresentadorDeEncerramento ap,
) async {
  telefone(tester);
  await tester.pumpWidget(arvore(f.online, ap));
  await tester.pumpAndSettle();
  await entrarNaMesa(tester, f);
}

Future<void> servidorManda(
  WidgetTester tester,
  Fio f,
  Map<String, dynamic> visao, {
  int? versaoEstado,
  String? eventoId,
}) async {
  f.canal.servidorEnvia(
    envelopeEstado(visao, versaoEstado: versaoEstado, eventoId: eventoId),
  );
  await tester.pumpAndSettle();
}

/// O servidor manda e a mensagem é ENTREGUE, mas nenhum quadro roda.
///
/// É a lupa desta suíte. `idle()` esvazia a fila de microtarefas sem pintar
/// nada, então o que se vê depois dela é exatamente o estado do livro entre a
/// chegada do envelope e a apresentação — que é onde mora a reivindicação, e
/// onde o desenho antigo já dava o efeito por consumido.
Future<void> servidorMandaSemQuadro(
  WidgetTester tester,
  Fio f,
  Map<String, dynamic> visao, {
  int? versaoEstado,
  String? eventoId,
}) async {
  f.canal.servidorEnvia(
    envelopeEstado(visao, versaoEstado: versaoEstado, eventoId: eventoId),
  );
  await tester.idle();
}

/// A visão que o servidor emite quando a partida acabou.
Map<String, dynamic> visaoTerminal({int voceAssento = 0}) => visaoDeJogo(
  voceAssento: voceAssento,
  encerrada: true,
  rodadaEncerrada: true,
  duplaQueBateu: 'nos',
  suaVez: false,
  placar: {'nos': 3010, 'eles': 1200},
);

Map<String, dynamic> encerramentoAvulso() => visaoTerminal();

/// O arquivo sem comentários. Mesma técnica das auditorias da casca, e pelo
/// mesmo motivo: uma varredura que lê comentário acusa a documentação de ser a
/// violação que ela explica.
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
      while (i + 1 < fonte.length &&
          !(fonte[i] == '*' && fonte[i + 1] == '/')) {
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
  // =========================================================================
  // 1 — o caminho feliz, e as duplicatas nos dois lados da confirmação
  // =========================================================================
  group('apresentar uma vez, com consumidor ativo', () {
    // CASO 1
    testWidgets('evento carimbado com consumidor ativo apresenta uma vez', (
      tester,
    ) async {
      final f = Fio();
      addTearDown(f.fechar);
      final ap = ApresentadorControlado();

      await abrirAMesa(tester, f, ap);
      await servidorManda(
        tester,
        f,
        visaoTerminal(),
        versaoEstado: 2,
        eventoId: 'fim-2',
      );

      expect(ap.quantos, 1);
      expect(ap.anuncios.single.eventoId, 'fim-2');
      expect(f.livro.estadoDe('fim-2'), EstadoDoEfeito.apresentado);
    });

    // CASO 2
    testWidgets('duplicata ANTES da confirmação não abre outro diálogo', (
      tester,
    ) async {
      final f = Fio();
      addTearDown(f.fechar);
      final ap = ApresentadorControlado();

      await abrirAMesa(tester, f, ap);

      // O fim chega e é REIVINDICADO, mas nenhum quadro rodou: a apresentação
      // ainda não aconteceu. É a janela em que uma segunda cutucada abriria o
      // segundo diálogo, se a reivindicação viesse depois do quadro.
      await servidorMandaSemQuadro(
        tester,
        f,
        visaoTerminal(),
        versaoEstado: 7,
        eventoId: 'fim-7',
      );
      expect(f.livro.estadoDe('fim-7'), EstadoDoEfeito.reivindicado);
      expect(ap.quantos, 0, reason: 'reivindicar não é apresentar');

      // O servidor reenvia exatamente o mesmo fim, ainda sem quadro.
      await servidorMandaSemQuadro(
        tester,
        f,
        visaoTerminal(),
        versaoEstado: 7,
        eventoId: 'fim-7',
      );
      await tester.pumpAndSettle();

      expect(ap.quantos, 1);
      expect(f.livro.estadoDe('fim-7'), EstadoDoEfeito.apresentado);
    });

    // CASO 3
    testWidgets('duplicata DEPOIS da confirmação não repete', (tester) async {
      final f = Fio();
      addTearDown(f.fechar);
      final ap = ApresentadorControlado();

      await abrirAMesa(tester, f, ap);
      for (var i = 0; i < 4; i++) {
        await servidorManda(
          tester,
          f,
          visaoTerminal(),
          versaoEstado: 7,
          eventoId: 'fim-7',
        );
      }

      expect(ap.quantos, 1);
      expect(f.livro.estadoDe('fim-7'), EstadoDoEfeito.apresentado);
    });

    // CASO 15
    testWidgets('dois eventoId distintos não são confundidos', (tester) async {
      final f = Fio();
      addTearDown(f.fechar);
      final ap = ApresentadorControlado();

      await abrirAMesa(tester, f, ap);
      await servidorManda(
        tester,
        f,
        visaoTerminal(),
        versaoEstado: 7,
        eventoId: 'fim-A',
      );
      await servidorManda(
        tester,
        f,
        visaoTerminal(),
        versaoEstado: 8,
        eventoId: 'fim-B',
      );

      expect(ap.quantos, 2);
      expect(
        ap.anuncios.map((a) => a.eventoId),
        ['fim-A', 'fim-B'],
        reason: 'a ordem é a da declaração do servidor',
      );
      expect(f.livro.estadoDe('fim-A'), EstadoDoEfeito.apresentado);
      expect(f.livro.estadoDe('fim-B'), EstadoDoEfeito.apresentado);
    });
  });

  // =========================================================================
  // 2 — a janela sem consumidor: o coração desta OS
  // =========================================================================
  group('sem consumidor, o efeito espera', () {
    // CASO 4
    testWidgets('evento recebido sem consumidor permanece pendente', (
      tester,
    ) async {
      final f = Fio();
      addTearDown(f.fechar);
      final ap = ApresentadorControlado();

      await abrirAMesa(tester, f, ap);
      // A pessoa sai da rota da mesa. O transporte continua vivo.
      await tester.pumpWidget(arvoreSemAMesa(f.online));
      await tester.pumpAndSettle();
      expect(f.online.aoEncerrar, isNull, reason: 'não há mais consumidor');

      await servidorManda(
        tester,
        f,
        visaoTerminal(),
        versaoEstado: 7,
        eventoId: 'fim-7',
      );

      expect(ap.quantos, 0);
      expect(
        f.livro.estadoDe('fim-7'),
        EstadoDoEfeito.pendente,
        reason:
            'chegar não é ser visto — anotar como resolvido aqui é o defeito '
            'que esta OS corrige',
      );
    });

    // CASO 5
    testWidgets('a assinatura posterior apresenta o pendente', (tester) async {
      final f = Fio();
      addTearDown(f.fechar);
      final ap = ApresentadorControlado();

      await abrirAMesa(tester, f, ap);
      await tester.pumpWidget(arvoreSemAMesa(f.online));
      await tester.pumpAndSettle();
      await servidorManda(
        tester,
        f,
        visaoTerminal(),
        versaoEstado: 7,
        eventoId: 'fim-7',
      );
      expect(ap.quantos, 0);

      // A pessoa volta para a mesa.
      await tester.pumpWidget(arvore(f.online, ap));
      await tester.pumpAndSettle();

      expect(ap.quantos, 1, reason: 'o aviso estava esperando por ela');
      expect(ap.anuncios.single.eventoId, 'fim-7');
      expect(f.livro.estadoDe('fim-7'), EstadoDoEfeito.apresentado);
      expect(find.byType(MesaOnlineScreen), findsOneWidget);
    });

    // CASO 17
    testWidgets('reconexão repetindo a visão não cria efeito novo', (
      tester,
    ) async {
      final f = Fio();
      addTearDown(f.fechar);
      final ap = ApresentadorControlado();

      await abrirAMesa(tester, f, ap);
      await tester.pumpWidget(arvoreSemAMesa(f.online));
      await tester.pumpAndSettle();
      await servidorManda(
        tester,
        f,
        visaoTerminal(),
        versaoEstado: 7,
        eventoId: 'fim-7',
      );

      // Cai e volta. O servidor não cria versão nova para quem reconecta — ele
      // reenvia a vigente, que é a terminal. Com o efeito AINDA pendente, um
      // livro que contasse chegadas em vez de fins registraria dois.
      f.canal.servidorDerruba();
      await tester.pump(const Duration(seconds: 1));
      f.online.tentarNovamente();
      await tester.pumpAndSettle();
      f.canal.servidorEnvia({'tipo': 'autenticado'});
      await tester.pumpAndSettle();
      f.canal.servidorEnvia({
        'tipo': 'entrou',
        'codigo': 'BURACO-0001',
        'assento': 0,
      });
      await tester.pumpAndSettle();
      await servidorManda(
        tester,
        f,
        visaoTerminal(),
        versaoEstado: 7,
        eventoId: 'fim-7',
      );

      expect(f.livro.conhecidos, 1, reason: 'é o mesmo fim, não dois');
      expect(f.livro.estadoDe('fim-7'), EstadoDoEfeito.pendente);

      // E quando alguém volta, ele é apresentado UMA vez.
      await tester.pumpWidget(arvore(f.online, ap));
      await tester.pumpAndSettle();
      expect(ap.quantos, 1);
    });

    // CASO 14
    testWidgets('duas mesas mantêm livros independentes', (tester) async {
      final a = Fio();
      addTearDown(a.fechar);
      final b = Fio();
      addTearDown(b.fechar);
      final ap = ApresentadorControlado();

      await abrirAMesa(tester, a, ap);
      await tester.pumpWidget(arvoreSemAMesa(a.online));
      await tester.pumpAndSettle();
      await servidorManda(
        tester,
        a,
        visaoTerminal(),
        versaoEstado: 7,
        eventoId: 'fim-da-mesa-A',
      );

      expect(a.livro.estadoDe('fim-da-mesa-A'), EstadoDoEfeito.pendente);
      expect(
        b.livro.estadoDe('fim-da-mesa-A'),
        isNull,
        reason: 'o fim de uma mesa não existe no livro da outra',
      );
      expect(b.livro.conhecidos, 0);
      expect(b.livro.temPendente, isFalse);
    });
  });

  // =========================================================================
  // 3 — reivindicar é promessa: quem não cumpre, devolve
  // =========================================================================
  group('a reivindicação volta ao livro', () {
    // CASO 7
    testWidgets('sair da rota antes da apresentação libera a reivindicação', (
      tester,
    ) async {
      final f = Fio();
      addTearDown(f.fechar);
      final ap = ApresentadorControlado();

      await abrirAMesa(tester, f, ap);
      await servidorMandaSemQuadro(
        tester,
        f,
        visaoTerminal(),
        versaoEstado: 7,
        eventoId: 'fim-7',
      );
      expect(f.livro.estadoDe('fim-7'), EstadoDoEfeito.reivindicado);

      // A rota morre com a promessa em pé.
      await tester.pumpWidget(arvoreSemAMesa(f.online));
      await tester.pumpAndSettle();

      expect(ap.quantos, 0);
      expect(
        f.livro.estadoDe('fim-7'),
        EstadoDoEfeito.pendente,
        reason:
            'um efeito preso em `reivindicado` por um dono que não existe mais '
            'é o defeito original de volta pela porta nova',
      );
    });

    // CASO 8
    testWidgets('o retorno posterior apresenta o evento liberado', (
      tester,
    ) async {
      final f = Fio();
      addTearDown(f.fechar);
      final ap = ApresentadorControlado();

      await abrirAMesa(tester, f, ap);
      await servidorMandaSemQuadro(
        tester,
        f,
        visaoTerminal(),
        versaoEstado: 7,
        eventoId: 'fim-7',
      );
      await tester.pumpWidget(arvoreSemAMesa(f.online));
      await tester.pumpAndSettle();
      expect(ap.quantos, 0);

      await tester.pumpWidget(arvore(f.online, ap));
      await tester.pumpAndSettle();

      expect(ap.quantos, 1);
      expect(f.livro.estadoDe('fim-7'), EstadoDoEfeito.apresentado);
    });

    // CASO 9
    testWidgets('sair DEPOIS da apresentação não devolve o evento', (
      tester,
    ) async {
      final f = Fio();
      addTearDown(f.fechar);
      final ap = ApresentadorControlado();

      await abrirAMesa(tester, f, ap);
      await servidorManda(
        tester,
        f,
        visaoTerminal(),
        versaoEstado: 7,
        eventoId: 'fim-7',
      );
      expect(f.livro.estadoDe('fim-7'), EstadoDoEfeito.apresentado);

      await tester.pumpWidget(arvoreSemAMesa(f.online));
      await tester.pumpAndSettle();
      expect(
        f.livro.estadoDe('fim-7'),
        EstadoDoEfeito.apresentado,
        reason: 'apresentado é fim de linha; daqui não se volta',
      );

      // E voltar para a mesa não traz o aviso de novo.
      await tester.pumpWidget(arvore(f.online, ap));
      await tester.pumpAndSettle();
      expect(ap.quantos, 1);
    });

    // CASO 12
    testWidgets('a falha do apresentador mantém o evento pendente', (
      tester,
    ) async {
      final f = Fio();
      addTearDown(f.fechar);
      final ap = ApresentadorControlado(ResultadoDaApresentacao.recusado);

      await abrirAMesa(tester, f, ap);
      await servidorManda(
        tester,
        f,
        visaoTerminal(),
        versaoEstado: 7,
        eventoId: 'fim-7',
      );

      expect(ap.quantos, 1, reason: 'tentou');
      expect(
        f.livro.estadoDe('fim-7'),
        EstadoDoEfeito.pendente,
        reason: 'e não conseguiu — então o aviso continua devendo aparecer',
      );
    });

    // CASO 13
    testWidgets('a reentrada depois da falha consegue apresentar', (
      tester,
    ) async {
      final f = Fio();
      addTearDown(f.fechar);
      final ap = ApresentadorControlado(ResultadoDaApresentacao.recusado);

      await abrirAMesa(tester, f, ap);
      await servidorManda(
        tester,
        f,
        visaoTerminal(),
        versaoEstado: 7,
        eventoId: 'fim-7',
      );
      expect(f.livro.estadoDe('fim-7'), EstadoDoEfeito.pendente);

      // O apresentador volta a funcionar e a pessoa reentra na mesa.
      ap.resposta = ResultadoDaApresentacao.apresentado;
      await tester.pumpWidget(arvoreSemAMesa(f.online));
      await tester.pumpAndSettle();
      await tester.pumpWidget(arvore(f.online, ap));
      await tester.pumpAndSettle();

      expect(ap.quantos, 2, reason: 'uma recusa e uma apresentação');
      expect(f.livro.estadoDe('fim-7'), EstadoDoEfeito.apresentado);
    });

    // CASO 21
    testWidgets('o dispose impede o efeito tardio', (tester) async {
      final f = Fio();
      addTearDown(f.fechar);
      final ap = ApresentadorControlado();

      await abrirAMesa(tester, f, ap);
      await servidorMandaSemQuadro(
        tester,
        f,
        visaoTerminal(),
        versaoEstado: 7,
        eventoId: 'fim-7',
      );

      // A tela some inteira — nem a árvore sobra.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();

      expect(ap.quantos, 0, reason: 'nada de diálogo por um contexto morto');
      expect(f.online.aoEncerrar, isNull);
      expect(f.livro.estadoDe('fim-7'), EstadoDoEfeito.pendente);
    });
  });

  // =========================================================================
  // 4 — de quem é esta reivindicação?
  // =========================================================================
  group('a posse é de quem reivindicou', () {
    // CASO 6
    testWidgets('dois rebuilds não criam dois consumidores', (tester) async {
      final f = Fio();
      addTearDown(f.fechar);
      final ap = ApresentadorControlado();

      await abrirAMesa(tester, f, ap);
      for (var i = 0; i < 5; i++) {
        await tester.pumpWidget(arvore(f.online, ap));
        await tester.pumpAndSettle();
      }
      expect(f.online.aoEncerrar, isNotNull);

      await servidorManda(
        tester,
        f,
        visaoTerminal(),
        versaoEstado: 9,
        eventoId: 'fim-9',
      );

      expect(ap.quantos, 1, reason: 'cinco reconstruções não são cinco donos');
      expect(f.livro.estadoDe('fim-9'), EstadoDoEfeito.apresentado);
    });

    // CASO 10
    testWidgets('a troca de transporte cancela o proprietário anterior', (
      tester,
    ) async {
      final antigo = Fio();
      addTearDown(antigo.fechar);
      final novo = Fio();
      addTearDown(novo.fechar);
      final ap = ApresentadorControlado();

      await abrirAMesa(tester, antigo, ap);
      await servidorMandaSemQuadro(
        tester,
        antigo,
        visaoTerminal(),
        versaoEstado: 7,
        eventoId: 'fim-7',
      );
      expect(antigo.livro.estadoDe('fim-7'), EstadoDoEfeito.reivindicado);

      // O transporte vira por baixo da tela.
      await tester.pumpWidget(arvore(novo.online, ap));
      await tester.pumpAndSettle();

      expect(antigo.online.aoEncerrar, isNull);
      expect(
        antigo.livro.estadoDe('fim-7'),
        EstadoDoEfeito.pendente,
        reason: 'a reivindicação do vínculo trocado voltou ao livro dele',
      );
      expect(ap.quantos, 0);
    });

    // CASO 11 — no widget
    testWidgets('callback atrasado do transporte anterior não mexe no novo', (
      tester,
    ) async {
      final antigo = Fio();
      addTearDown(antigo.fechar);
      final novo = Fio();
      addTearDown(novo.fechar);
      final ap = ApresentadorControlado();

      await abrirAMesa(tester, antigo, ap);
      final consumidorAntigo = antigo.online.aoEncerrar;
      expect(consumidorAntigo, isNotNull);

      await tester.pumpWidget(arvore(novo.online, ap));
      await tester.pumpAndSettle();
      // A CONEXÃO É PEDIDA À MÃO. Trocar o transporte por baixo reaproveita o
      // `State` da tela (mesmo tipo, mesma posição), e o pedido de conexão
      // acontece uma vez por `State` — não por transporte. É comportamento do
      // ciclo de vida da conexão, anterior a esta OS e fora do escopo dela;
      // aqui interessa só ter a mesa nova de pé para medir o efeito.
      novo.online.conectar();
      await tester.pumpAndSettle();
      await entrarNaMesa(tester, novo);

      // O vínculo novo reivindica um fim seu, e ainda não apresentou.
      await servidorMandaSemQuadro(
        tester,
        novo,
        visaoTerminal(),
        versaoEstado: 3,
        eventoId: 'fim-do-novo',
      );
      expect(novo.livro.estadoDe('fim-do-novo'), EstadoDoEfeito.reivindicado);

      // A closure que sobrou na mão de quem a guardou dispara agora.
      consumidorAntigo!(
        EncerramentoAutoritativo(
          versaoEstado: 99,
          eventoId: 'do-servico-antigo',
          visao: encerramentoAvulso(),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        ap.quantos,
        1,
        reason: 'só o fim do vínculo novo foi apresentado, e uma vez',
      );
      expect(ap.anuncios.single.eventoId, 'fim-do-novo');
      expect(novo.livro.estadoDe('fim-do-novo'), EstadoDoEfeito.apresentado);
      expect(
        antigo.livro.estadoDe('do-servico-antigo'),
        isNull,
        reason: 'a cutucada avulsa não escreve no livro de ninguém',
      );
    });

    // CASO 11 — no livro
    test('confirmar e liberar exigem a posse que reivindicou', () {
      final livro = LivroDeEfeitosTerminais();
      final aviso = EncerramentoAutoritativo(
        versaoEstado: 5,
        eventoId: 'fim-5',
        visao: encerramentoAvulso(),
      );
      livro.registrar(aviso);

      final velho = PosseDoEfeito();
      final novo = PosseDoEfeito();

      expect(livro.reivindicar(velho), isNotNull);
      // O dono antigo sai de cena e o novo assume.
      expect(livro.liberarTudoDe(velho), 1);
      expect(livro.reivindicar(novo), isNotNull);
      expect(livro.estadoDe('fim-5'), EstadoDoEfeito.reivindicado);

      // A confirmação atrasada do antigo chega agora.
      expect(
        livro.confirmar(velho, aviso),
        isFalse,
        reason: 'o dono antigo não encerra o efeito que o novo vai apresentar',
      );
      expect(livro.estadoDe('fim-5'), EstadoDoEfeito.reivindicado);
      expect(
        livro.liberar(velho, aviso),
        isFalse,
        reason: 'nem devolve ao livro o que já não é dele',
      );
      expect(livro.estadoDe('fim-5'), EstadoDoEfeito.reivindicado);

      // O dono de verdade confirma.
      expect(livro.confirmar(novo, aviso), isTrue);
      expect(livro.estadoDe('fim-5'), EstadoDoEfeito.apresentado);
      expect(livro.temPendente, isFalse);
    });

    // CASO 11 — no livro, só a liberação
    test('o dono antigo não devolve ao livro a reivindicação do novo', () {
      // Separado do caso acima de propósito: com os dois numa asserção só,
      // tirar a conferência de posse de UM dos dois métodos derrubaria o mesmo
      // caso e ninguém saberia qual dos dois guardas caiu.
      final livro = LivroDeEfeitosTerminais();
      final aviso = EncerramentoAutoritativo(
        versaoEstado: 5,
        eventoId: 'fim-5',
        visao: encerramentoAvulso(),
      );
      livro.registrar(aviso);

      final velho = PosseDoEfeito();
      final novo = PosseDoEfeito();
      livro.reivindicar(velho);
      livro.liberarTudoDe(velho);
      livro.reivindicar(novo);

      expect(livro.liberar(velho, aviso), isFalse);
      expect(
        livro.estadoDe('fim-5'),
        EstadoDoEfeito.reivindicado,
        reason:
            'devolver ao livro o que é de outro abriria a porta para um '
            'segundo dono reivindicar o mesmo fim',
      );
    });

    // CASO 11 — no livro, a saída em massa
    test('a saída de um dono não solta a reivindicação do outro', () {
      final livro = LivroDeEfeitosTerminais();
      final a = EncerramentoAutoritativo(
        versaoEstado: 1,
        eventoId: 'fim-A',
        visao: encerramentoAvulso(),
      );
      final b = EncerramentoAutoritativo(
        versaoEstado: 2,
        eventoId: 'fim-B',
        visao: encerramentoAvulso(),
      );
      livro.registrar(a);
      livro.registrar(b);

      final um = PosseDoEfeito();
      final outro = PosseDoEfeito();
      expect(livro.reivindicar(um)?.eventoId, 'fim-A');
      expect(livro.reivindicar(outro)?.eventoId, 'fim-B');

      expect(livro.liberarTudoDe(um), 1, reason: 'só o que era dele');
      expect(livro.estadoDe('fim-A'), EstadoDoEfeito.pendente);
      expect(livro.estadoDe('fim-B'), EstadoDoEfeito.reivindicado);
    });

    test('a reivindicação é exclusiva enquanto durar', () {
      final livro = LivroDeEfeitosTerminais();
      final aviso = EncerramentoAutoritativo(
        versaoEstado: 5,
        eventoId: 'fim-5',
        visao: encerramentoAvulso(),
      );
      livro.registrar(aviso);

      final a = PosseDoEfeito();
      final b = PosseDoEfeito();
      expect(livro.reivindicar(a), isNotNull);
      expect(
        livro.reivindicar(b),
        isNull,
        reason: 'dois donos simultâneos seriam dois diálogos',
      );
    });
  });

  // =========================================================================
  // 5 — o modo legado, sem identidade inventada
  // =========================================================================
  group('o encerramento sem carimbo', () {
    // CASO 18
    testWidgets('evento legado sem consumidor permanece pendente', (
      tester,
    ) async {
      final f = Fio();
      addTearDown(f.fechar);
      final ap = ApresentadorControlado();

      await abrirAMesa(tester, f, ap);
      await tester.pumpWidget(arvoreSemAMesa(f.online));
      await tester.pumpAndSettle();

      // Envelope SEM `versaoEstado` e SEM `eventoId`: o servidor de produção.
      await servidorManda(tester, f, visaoTerminal());

      expect(ap.quantos, 0);
      expect(
        f.livro.estadoDe(null),
        EstadoDoEfeito.pendente,
        reason:
            'sem carimbo o efeito espera igual — a identidade é que é mais '
            'fraca, não a garantia de que alguém vai vê-lo',
      );
    });

    // CASO 19
    testWidgets('o evento legado é apresentado uma única vez ao assinar', (
      tester,
    ) async {
      final f = Fio();
      addTearDown(f.fechar);
      final ap = ApresentadorControlado();

      await abrirAMesa(tester, f, ap);
      await tester.pumpWidget(arvoreSemAMesa(f.online));
      await tester.pumpAndSettle();
      await servidorManda(tester, f, visaoTerminal());

      await tester.pumpWidget(arvore(f.online, ap));
      await tester.pumpAndSettle();

      expect(ap.quantos, 1);
      expect(
        ap.anuncios.single.eventoId,
        isNull,
        reason: 'não se fabrica identidade de servidor no cliente',
      );
      expect(ap.anuncios.single.versaoEstado, isNull);
      expect(f.livro.estadoDe(null), EstadoDoEfeito.apresentado);
    });

    // CASO 20
    testWidgets('a repetição legada depois da confirmação não repete', (
      tester,
    ) async {
      final f = Fio();
      addTearDown(f.fechar);
      final ap = ApresentadorControlado();

      await abrirAMesa(tester, f, ap);
      for (var i = 0; i < 3; i++) {
        await servidorManda(tester, f, visaoTerminal());
      }

      expect(ap.quantos, 1);
      expect(f.livro.conhecidos, 1);
      expect(f.livro.estadoDe(null), EstadoDoEfeito.apresentado);
    });
  });

  // =========================================================================
  // 6 — o efeito não nasce do retrato
  // =========================================================================
  group('estado terminal não é efeito', () {
    // CASO 16
    testWidgets('visão terminal sem envelope de efeito não abre diálogo', (
      tester,
    ) async {
      final f = Fio();
      addTearDown(f.fechar);
      final ap = ApresentadorControlado();

      await abrirAMesa(tester, f, ap);
      // Carimbo ilegível: a emissão não tem autoridade, e o efeito não nasce —
      // mesmo a visão dizendo `encerrada: true`.
      f.canal.servidorEnvia({
        'tipo': 'estado',
        'visao': visaoTerminal(),
        'versaoEstado': 'não é número',
        'eventoId': 'fim-ilegivel',
      });
      await tester.pumpAndSettle();

      expect(ap.quantos, 0);
      expect(f.livro.conhecidos, 0);
      expect(f.livro.temPendente, isFalse);
    });

    testWidgets('a mesa terminal redesenhada não reabre o aviso', (
      tester,
    ) async {
      final f = Fio();
      addTearDown(f.fechar);
      final ap = ApresentadorControlado();

      await abrirAMesa(tester, f, ap);
      await servidorManda(
        tester,
        f,
        visaoTerminal(),
        versaoEstado: 7,
        eventoId: 'fim-7',
      );
      expect(ap.quantos, 1);

      // A pessoa sai da rota e volta. O retrato terminal se repete — ele é
      // obrigado a se repetir —, e o efeito não.
      await tester.pumpWidget(arvoreSemAMesa(f.online));
      await tester.pumpAndSettle();
      await tester.pumpWidget(arvore(f.online, ap));
      await tester.pumpAndSettle();

      expect(find.text('Partida encerrada'), findsOneWidget);
      expect(ap.quantos, 1);
    });

    // CASO 24
    testWidgets('a apresentação agenda o próprio quadro', (tester) async {
      final f = Fio();
      addTearDown(f.fechar);
      final ap = ApresentadorControlado();

      await abrirAMesa(tester, f, ap);
      // Um estado NÃO terminal fixa o marcador em (7, ev-7).
      await servidorManda(
        tester,
        f,
        visaoDeJogo(),
        versaoEstado: 7,
        eventoId: 'ev-7',
      );
      expect(tester.binding.hasScheduledFrame, isFalse);

      // Agora o MESMO carimbo com a visão terminal. Pela ordem isso é
      // `duplicada`: o retrato não é reaplicado e o transporte volta ANTES de
      // notificar ninguém. É o único caminho em que o efeito não tem vizinho
      // nenhum sujando a árvore por ele — e é aqui que `addPostFrameCallback`
      // sozinho ficaria pendurado para sempre.
      f.canal.servidorEnvia(
        envelopeEstado(visaoTerminal(), versaoEstado: 7, eventoId: 'ev-7'),
      );
      await tester.idle();

      expect(
        tester.binding.hasScheduledFrame,
        isTrue,
        reason:
            'o efeito PEDE o quadro em que vai acontecer; contar com o de '
            'outra pessoa deixa o aviso pendurado sem erro e sem rastro',
      );

      await tester.pumpAndSettle();
      expect(ap.quantos, 1);
    });
  });

  // =========================================================================
  // 7 — o diálogo de produção, e as duas ações que não mudam
  // =========================================================================
  group('o diálogo de produção', () {
    /// Leva a bancada inteira até a mesa e encerra a partida.
    Future<Bancada> mesaEncerrada(WidgetTester tester) async {
      final b = Bancada(uidInicial: 'uid-A');
      telefone(tester);

      await tester.pumpWidget(b.aplicativo);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Jogar').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mesa por código'));
      await tester.pumpAndSettle();
      b.canal.servidorEnvia({'tipo': 'autenticado'});
      await tester.pumpAndSettle();
      await tester.tap(find.text('Criar mesa'));
      await tester.pumpAndSettle();
      b.canal.servidorEnvia({
        'tipo': 'entrou',
        'codigo': 'BURACO-0001',
        'assento': 0,
      });
      await tester.pumpAndSettle();
      b.canal.servidorEnvia(
        envelopeEstado(visaoTerminal(), versaoEstado: 2, eventoId: 'fim-2'),
      );
      await tester.pumpAndSettle();
      return b;
    }

    // CASO 22
    testWidgets('"Ver a mesa" mantém o comportamento anterior', (tester) async {
      final b = await mesaEncerrada(tester);
      addTearDown(b.fechar);

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Fim da partida'), findsOneWidget);
      expect(
        b.online.efeitosTerminais.estadoDe('fim-2'),
        EstadoDoEfeito.apresentado,
        reason: 'o diálogo entrou na árvore — só isso confirma o consumo',
      );

      await tester.tap(find.text('Ver a mesa'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Partida encerrada'), findsOneWidget);

      // E o reenvio não traz o aviso de volta.
      b.canal.servidorEnvia(
        envelopeEstado(visaoTerminal(), versaoEstado: 2, eventoId: 'fim-2'),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);

      b.online.desligar();
      await tester.pumpAndSettle();
    });

    // CASO 23
    testWidgets('"Sair da mesa" continua saindo pela porta de comandos', (
      tester,
    ) async {
      final b = await mesaEncerrada(tester);
      addTearDown(b.fechar);

      await tester.tap(find.text('Sair da mesa'));
      await tester.pumpAndSettle();

      expect(
        b.canal.doTipo('sair'),
        hasLength(1),
        reason: 'sair da mesa é comando, e comando sai por uma porta só',
      );
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(MesaOnlineScreen), findsNothing);

      b.online.desligar();
      await tester.pumpAndSettle();
    });

    testWidgets('o aviso não confirma consumo quando não há navegador', (
      tester,
    ) async {
      // O apresentador de produção, exercitado fora de uma rota. É o caso que
      // separa "chamei" de "apareceu": sem `Navigator` não há onde inserir o
      // diálogo, e devolver `apresentado` aqui marcaria como visto um aviso
      // que não existe.
      late BuildContext solto;
      await tester.pumpWidget(
        Builder(
          builder: (c) {
            solto = c;
            return const SizedBox();
          },
        ),
      );

      final resultado = await const DialogoDeEncerramento().apresentar(
        solto,
        EncerramentoAutoritativo(
          versaoEstado: 1,
          eventoId: 'sem-rota',
          visao: encerramentoAvulso(),
        ),
        aoSairDaMesa: () {},
      );

      expect(resultado, ResultadoDaApresentacao.recusado);
      expect(find.byType(AlertDialog), findsNothing);
    });
  });

  // =========================================================================
  // 8 — a prova de ausência
  // =========================================================================
  group('nada disto virou global', () {
    /// Todo `.dart` do cliente, menos os testes.
    List<File> fontes() => Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();

    String barras(String p) => p.replaceAll(r'\', '/');

    // CASO 25
    test('só a rota da mesa consome o efeito terminal', () {
      final donos = <String>[];
      for (final f in fontes()) {
        final nome = barras(f.path);
        final codigo = _codigo(f);
        final consome =
            RegExp(r'(^|[^A-Za-z0-9_])aoEncerrar\s*=').hasMatch(codigo) ||
            codigo.contains('efeitosTerminais') ||
            codigo.contains('ApresentadorDeEncerramento') ||
            codigo.contains('DialogoDeEncerramento');
        if (consome) donos.add(nome);
      }

      expect(
        donos.toSet(),
        {
          'lib/casca/lobby_online.dart',
          // Declara o contrato e o diálogo; não assina nada.
          'lib/casca/mesa_online/encerramento_da_mesa.dart',
          // Expõe o livro; não apresenta nada.
          'lib/services/online_service.dart',
        },
        reason:
            'um consumidor na raiz, no MaterialApp ou na Home poria o aviso '
            'sobre Login, Perfil ou Loja — sobre qualquer tela que estivesse '
            'por cima, menos a mesa de que ele fala',
      );
    });

    test('a raiz e a casca não sabem o que é encerramento', () {
      for (final caminho in const [
        'lib/casca/raiz_do_aplicativo.dart',
        'lib/casca/casca_de_producao.dart',
      ]) {
        final codigo = _codigo(File(caminho));
        for (final proibido in const [
          'aoEncerrar',
          'efeitosTerminais',
          'Encerramento',
        ]) {
          expect(
            codigo.contains(proibido),
            isFalse,
            reason: '$caminho menciona $proibido — o efeito subiu de escopo',
          );
        }
      }
    });

    test('a apresentação pede o próprio quadro antes de agendar', () {
      // O comportamento tem caso próprio (o do carimbo repetido). Isto fixa o
      // MECANISMO: quem tirar o `ensureVisualUpdate` para "simplificar" não faz
      // nada quebrar hoje, porque quase sempre existe um vizinho sujando a
      // árvore — e quebra em produção, na única vez em que não existe.
      const chamada = 'ensureVisualUpdate()';
      final codigo = _codigo(File('lib/casca/lobby_online.dart'));
      final pede = codigo.indexOf(chamada);
      expect(pede, greaterThan(-1), reason: 'o efeito não pede mais o quadro');

      // O PRIMEIRO agendamento DEPOIS do pedido, e não o primeiro do arquivo:
      // a tela também agenda o `conectar()` para depois do quadro, e esse não
      // tem nada a ver com o efeito terminal.
      final agenda = codigo.indexOf('addPostFrameCallback', pede);
      expect(agenda, greaterThan(-1), reason: 'o efeito não agenda mais nada');
      // Entre as duas só pode sobrar o receptor do agendamento.
      final entre = codigo
          .substring(pede + chamada.length, agenda)
          .replaceAll('WidgetsBinding.instance.', '')
          .replaceAll(RegExp(r'[\s;]'), '');
      expect(
        entre,
        isEmpty,
        reason:
            'entre pedir o quadro e agendar o efeito não pode se meter nada — '
            'um desvio ali é um caminho em que o aviso fica pendurado',
      );
    });

    test('o livro dos efeitos não é persistido em lugar nenhum', () {
      final codigo = _codigo(
        File('lib/services/livro_de_efeitos_terminais.dart'),
      );
      for (final proibido in const [
        'Firebase',
        'Firestore',
        'SharedPreferences',
        'http',
      ]) {
        expect(
          codigo.contains(proibido),
          isFalse,
          reason:
              'o ciclo de vida de um aviso de interface é do cliente; uma '
              'marca de "já apresentei" gravada fora dele descreveria uma sala '
              'que talvez nem exista mais',
        );
      }
    });
  });
}
