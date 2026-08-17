// encerramento_na_ui_test.dart — o primeiro consumidor real do efeito terminal.
//
// A suíte irmã (`mesa_online_test.dart`, grupo "efeito terminal") já provava que
// o TRANSPORTE despacha o encerramento uma vez por `eventoId`. O que se prova
// aqui é o outro lado da ligação: que a INTERFACE consome esse despacho uma vez,
// e que ela não volta a inferir o fim por conta própria.
//
// A pergunta que organiza o arquivo é "de quem é este aviso?". Um efeito
// terminal errado quase nunca é um efeito que não acontece — é um que acontece
// duas vezes (o reenvio, a reconexão), ou que acontece para a mesa errada (o
// callback preso numa closure de uma sessão que já acabou).
//
// ---------------------------------------------------------------------------
// O QUE É FALSO AQUI
// ---------------------------------------------------------------------------
//
// Duas coisas: o SOCKET (`CanalFalso`, emprestado da bancada) e o APRESENTADOR
// do efeito. O `OnlineService` é o de produção, com a `OrdemDaVisao` de
// produção, e a tela é a `LobbyOnline` de produção. Trocar o serviço por um
// dublê provaria o dublê — e é justamente a costura entre os dois que está sob
// julgamento.
//
// O apresentador falso é um CONTADOR, e isso é de propósito: "quantas vezes o
// efeito aconteceu" é a pergunta do arquivo inteiro, e um contador responde
// melhor do que procurar diálogo desenhado numa árvore. O diálogo de produção
// tem um grupo só para ele no fim.
//
// Nenhum caso abre rede, toca relógio de verdade ou fala com Firebase.

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

/// O apresentador do teste: conta, guarda e não desenha nada.
class ApresentadorFalso implements ApresentadorDeEncerramento {
  final List<EncerramentoAutoritativo> anuncios = [];

  /// A saída que cada aviso ofereceu. Guardada para o caso que a exercita.
  final List<VoidCallback> saidas = [];

  int get quantos => anuncios.length;

  @override
  Future<ResultadoDaApresentacao> apresentar(
    BuildContext context,
    EncerramentoAutoritativo encerramento, {
    required VoidCallback aoSairDaMesa,
  }) async {
    anuncios.add(encerramento);
    saidas.add(aoSairDaMesa);
    // Adaptação mecânica à assinatura nova: este contador SEMPRE consegue
    // apresentar, que é o que ele já fazia quando o retorno era `void`. Nenhuma
    // asserção deste arquivo muda por causa disto — quem exercita recusa e
    // cancelamento é a suíte do pendente, que traz o seu próprio apresentador.
    return ResultadoDaApresentacao.apresentado;
  }
}

/// Um transporte de produção com o socket falso.
///
/// Não usa a `Bancada` inteira porque estes casos precisam TROCAR o transporte
/// por baixo da tela — que é o cenário do "callback do serviço anterior" —, e a
/// bancada monta o aplicativo com um transporte só.
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

  void fechar() => online.dispose();
}

Widget arvore(OnlineService srv, ApresentadorDeEncerramento ap) =>
    EscopoTransporte(
      online: srv,
      child: MaterialApp(home: LobbyOnline(apresentador: ap)),
    );

/// Monta a tela e leva a conexão até o assento — o mesmo caminho da pessoa.
Future<void> abrirAMesa(
  WidgetTester tester,
  Fio f,
  ApresentadorFalso ap, {
  int assento = 0,
}) async {
  // Superfície de telefone: a mesa não cabe nos 800x600 do `flutter_test`.
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(arvore(f.online, ap));
  await tester.pumpAndSettle();
  await entrarNaMesa(tester, f, assento: assento);
}

/// O servidor aceita a credencial e dá um assento.
Future<void> entrarNaMesa(
  WidgetTester tester,
  Fio f, {
  int assento = 0,
}) async {
  f.canal.servidorEnvia({'tipo': 'autenticado'});
  await tester.pumpAndSettle();
  f.canal.servidorEnvia({
    'tipo': 'entrou',
    'codigo': 'BURACO-0001',
    'assento': assento,
  });
  await tester.pumpAndSettle();
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

/// A visão que o servidor emite quando a partida acabou.
Map<String, dynamic> visaoTerminal({int voceAssento = 0}) => visaoDeJogo(
  voceAssento: voceAssento,
  encerrada: true,
  rodadaEncerrada: true,
  duplaQueBateu: 'nos',
  suaVez: false,
  placar: {'nos': 3010, 'eles': 1200},
);

/// Um encerramento montado à mão, para os casos que chamam o consumidor
/// diretamente — callback antigo, callback depois do `dispose`.
EncerramentoAutoritativo encerramentoAvulso([String evento = 'avulso']) =>
    EncerramentoAutoritativo(
      versaoEstado: 99,
      eventoId: evento,
      visao: visaoTerminal(),
    );

void main() {
  // =========================================================================
  // O caminho feliz, e a repetição que não pode acontecer
  // =========================================================================
  group('uma apresentação por encerramento', () {
    testWidgets('o primeiro eventoId terminal apresenta uma vez', (
      tester,
    ) async {
      final f = Fio();
      addTearDown(f.fechar);
      final ap = ApresentadorFalso();

      await abrirAMesa(tester, f, ap);
      await servidorManda(tester, f, visaoDeJogo(), versaoEstado: 1, eventoId: 'e1');
      expect(ap.quantos, 0, reason: 'partida em andamento não é encerramento');

      await servidorManda(
        tester,
        f,
        visaoTerminal(),
        versaoEstado: 2,
        eventoId: 'fim-2',
      );

      expect(ap.quantos, 1);
      expect(ap.anuncios.single.eventoId, 'fim-2');
      expect(ap.anuncios.single.versaoEstado, 2);
      // E a mesa continua desenhada, com o retrato terminal.
      expect(find.byType(MesaOnlineScreen), findsOneWidget);
      expect(find.text('Partida encerrada'), findsOneWidget);
    });

    testWidgets('o mesmo eventoId reenviado não apresenta de novo', (
      tester,
    ) async {
      final f = Fio();
      addTearDown(f.fechar);
      final ap = ApresentadorFalso();

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

      expect(
        ap.quantos,
        1,
        reason: 'o reenvio do encerramento é o mesmo fim, não um fim novo',
      );
    });

    testWidgets('a visão vigente reenviada na reconexão não apresenta de novo', (
      tester,
    ) async {
      final f = Fio();
      addTearDown(f.fechar);
      final ap = ApresentadorFalso();

      await abrirAMesa(tester, f, ap);
      await servidorManda(
        tester,
        f,
        visaoTerminal(),
        versaoEstado: 7,
        eventoId: 'fim-7',
      );
      expect(ap.quantos, 1);

      // Cai e volta. O servidor NÃO cria versão nova para quem reconecta — ele
      // reenvia a vigente, que é justamente a terminal.
      f.canal.servidorDerruba();
      await tester.pump(const Duration(seconds: 1));
      f.online.tentarNovamente();
      await tester.pumpAndSettle();
      await entrarNaMesa(tester, f);
      await servidorManda(
        tester,
        f,
        visaoTerminal(),
        versaoEstado: 7,
        eventoId: 'fim-7',
      );

      expect(find.byType(MesaOnlineScreen), findsOneWidget);
      expect(find.text('Partida encerrada'), findsOneWidget);
      expect(
        ap.quantos,
        1,
        reason: 'quem só caiu e voltou já viu o resultado uma vez',
      );
    });

    testWidgets('um eventoId novo, de uma partida nova, apresenta de novo', (
      tester,
    ) async {
      final f = Fio();
      addTearDown(f.fechar);
      final ap = ApresentadorFalso();

      await abrirAMesa(tester, f, ap);
      await servidorManda(
        tester,
        f,
        visaoTerminal(),
        versaoEstado: 7,
        eventoId: 'fim-7',
      );
      expect(ap.quantos, 1);

      // A pessoa sai da mesa e entra em outra. A sala nova tem contador
      // próprio, e o `versaoEstado` dela pode até ser menor.
      await tester.tap(find.text('Sair'));
      await tester.pumpAndSettle();
      f.canal.servidorEnvia({
        'tipo': 'entrou',
        'codigo': 'BURACO-0002',
        'assento': 0,
      });
      await tester.pumpAndSettle();
      await servidorManda(
        tester,
        f,
        visaoTerminal(),
        versaoEstado: 3,
        eventoId: 'fim-da-outra-mesa',
      );

      expect(ap.quantos, 2);
      expect(ap.anuncios.last.eventoId, 'fim-da-outra-mesa');
    });
  });

  // =========================================================================
  // O que NÃO pode virar encerramento
  // =========================================================================
  group('o efeito nasce só do ponto de saída autoritativo', () {
    testWidgets('visão atrasada não produz efeito terminal novo', (
      tester,
    ) async {
      final f = Fio();
      addTearDown(f.fechar);
      final ap = ApresentadorFalso();

      await abrirAMesa(tester, f, ap);
      await servidorManda(
        tester,
        f,
        visaoTerminal(),
        versaoEstado: 20,
        eventoId: 'fim-20',
      );
      expect(ap.quantos, 1);

      // Uma retomada atrasada, terminal, com identidade diferente. Ela é
      // descartada INTEIRA pela ordem — e o efeito vai junto.
      await servidorManda(
        tester,
        f,
        visaoTerminal(),
        versaoEstado: 12,
        eventoId: 'fim-12-atrasado',
      );

      expect(ap.quantos, 1);
    });

    testWidgets('visão recusada por carimbo ilegível não produz efeito', (
      tester,
    ) async {
      final f = Fio();
      addTearDown(f.fechar);
      final ap = ApresentadorFalso();

      await abrirAMesa(tester, f, ap);
      // Carimbo que não descreve carimbo nenhum: a emissão não tem autoridade.
      f.canal.servidorEnvia({
        'tipo': 'estado',
        'visao': visaoTerminal(),
        'versaoEstado': 'não é número',
        'eventoId': 'fim-ilegivel',
      });
      await tester.pumpAndSettle();

      expect(ap.quantos, 0);
    });

    testWidgets('o evento legado `fim`, sozinho, não apresenta nada', (
      tester,
    ) async {
      final f = Fio();
      addTearDown(f.fechar);
      final ap = ApresentadorFalso();

      await abrirAMesa(tester, f, ap);
      await servidorManda(tester, f, visaoDeJogo(), versaoEstado: 4, eventoId: 'e4');

      // O `fim` do protocolo legado não carrega carimbo e nunca foi tratado
      // pelo cliente. Se um dia ele ganhar efeito próprio, vai precisar de
      // identidade para ser deduplicado — e não é esta OS que o liga.
      f.canal.servidorEnvia({
        'tipo': 'fim',
        'resumo': 'a partida acabou',
        'placar': {'nos': 3010, 'eles': 1200},
      });
      await tester.pumpAndSettle();

      expect(ap.quantos, 0);
    });

    testWidgets('rodada encerrada não é partida encerrada', (tester) async {
      final f = Fio();
      addTearDown(f.fechar);
      final ap = ApresentadorFalso();

      await abrirAMesa(tester, f, ap);
      await servidorManda(
        tester,
        f,
        visaoDeJogo(
          rodadaEncerrada: true,
          duplaQueBateu: 'nos',
          suaVez: false,
          placar: {'nos': 9999, 'eles': 0},
        ),
        versaoEstado: 5,
        eventoId: 'ev-5',
      );

      expect(ap.quantos, 0);
    });
  });

  // =========================================================================
  // Ciclo de vida — de quem é este callback?
  // =========================================================================
  group('o vínculo pertence a esta tela', () {
    testWidgets('reconstruções sucessivas não empilham assinaturas', (
      tester,
    ) async {
      final f = Fio();
      addTearDown(f.fechar);
      final ap = ApresentadorFalso();

      await abrirAMesa(tester, f, ap);

      // A árvore é reconstruída várias vezes — e o `didChangeDependencies`
      // roda a cada notificação do escopo, que é o transporte inteiro.
      for (var i = 0; i < 5; i++) {
        await tester.pumpWidget(arvore(f.online, ap));
        await tester.pumpAndSettle();
      }

      expect(f.online.aoEncerrar, isNotNull, reason: 'a assinatura sobrevive');
      await servidorManda(
        tester,
        f,
        visaoTerminal(),
        versaoEstado: 9,
        eventoId: 'fim-9',
      );

      expect(
        ap.quantos,
        1,
        reason: 'cinco reconstruções não são cinco donos do fim',
      );
    });

    testWidgets('callback do serviço anterior é inerte', (tester) async {
      final antigo = Fio();
      addTearDown(antigo.fechar);
      final novo = Fio();
      addTearDown(novo.fechar);
      final ap = ApresentadorFalso();

      await abrirAMesa(tester, antigo, ap);
      final consumidorAntigo = antigo.online.aoEncerrar;
      expect(consumidorAntigo, isNotNull);

      // O transporte é trocado por baixo da tela.
      await tester.pumpWidget(arvore(novo.online, ap));
      await tester.pumpAndSettle();

      expect(
        antigo.online.aoEncerrar,
        isNull,
        reason: 'o vínculo anterior foi devolvido ao ser trocado',
      );

      // E a closure que sobrou na mão de quem a guardou não faz nada.
      consumidorAntigo!(encerramentoAvulso('do-servico-antigo'));
      await tester.pumpAndSettle();

      expect(ap.quantos, 0);
    });

    testWidgets('callback depois do dispose é inerte', (tester) async {
      final f = Fio();
      addTearDown(f.fechar);
      final ap = ApresentadorFalso();

      await abrirAMesa(tester, f, ap);
      final consumidor = f.online.aoEncerrar;
      expect(consumidor, isNotNull);

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();

      expect(
        f.online.aoEncerrar,
        isNull,
        reason: 'a tela devolveu o ponto de saída ao morrer',
      );

      consumidor!(encerramentoAvulso('depois-do-dispose'));
      await tester.pumpAndSettle();

      expect(ap.quantos, 0);
    });

    testWidgets('a tela não apaga a assinatura de outro dono', (tester) async {
      final f = Fio();
      addTearDown(f.fechar);
      final ap = ApresentadorFalso();

      await abrirAMesa(tester, f, ap);

      // Alguém de fora ocupa o slot depois de nós — é o que a suíte irmã faz
      // para medir o transporte.
      final deOutro = <EncerramentoAutoritativo>[];
      f.online.aoEncerrar = deOutro.add;

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();

      expect(
        f.online.aoEncerrar,
        isNotNull,
        reason: 'zerar sem conferir identidade apagaria a assinatura alheia',
      );
    });
  });

  // =========================================================================
  // A espera entre o aviso e o efeito
  // =========================================================================
  group('a continuação assíncrona confere de novo', () {
    testWidgets('consumidor ainda montado conclui o fluxo', (tester) async {
      final f = Fio();
      addTearDown(f.fechar);
      final ap = ApresentadorFalso();

      await abrirAMesa(tester, f, ap);

      // A CUTUCADA VEM DO SERVIDOR, e não mais de um encerramento montado à
      // mão. Quando este caso foi escrito, o aviso chegava PELO parâmetro do
      // callback, e um objeto avulso bastava para exercitá-lo. Hoje o parâmetro
      // é só um toque no ombro: o que se apresenta é o que está pendente no
      // livro dos efeitos, e um encerramento que nunca passou pela autoridade
      // da ordem não está lá — nem pode estar, senão qualquer chamador viraria
      // uma segunda fonte do mesmo efeito, que é a porta pela qual o aviso
      // duplicado voltaria.
      //
      // O que o caso MEDE não mudou, e as asserções são as mesmas: com o
      // consumidor montado, a continuação assíncrona chega ao fim, uma vez, com
      // a identidade certa.
      await servidorManda(
        tester,
        f,
        visaoTerminal(),
        versaoEstado: 99,
        eventoId: 'espera-montado',
      );

      expect(ap.quantos, 1);
      expect(ap.anuncios.single.eventoId, 'espera-montado');
    });

    testWidgets('consumidor desmontado durante a espera não apresenta nada', (
      tester,
    ) async {
      final f = Fio();
      addTearDown(f.fechar);
      final ap = ApresentadorFalso();

      await abrirAMesa(tester, f, ap);
      final consumidor = f.online.aoEncerrar!;

      // O aviso chega e o efeito fica agendado para depois do quadro. A tela
      // morre nesse intervalo: nada de diálogo, som ou navegação tardia.
      consumidor(encerramentoAvulso('espera-desmontado'));
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();

      expect(ap.quantos, 0);
    });

    testWidgets('a saída oferecida pelo aviso sai pela porta de comandos', (
      tester,
    ) async {
      final f = Fio();
      addTearDown(f.fechar);
      final ap = ApresentadorFalso();

      await abrirAMesa(tester, f, ap);
      await servidorManda(
        tester,
        f,
        visaoTerminal(),
        versaoEstado: 11,
        eventoId: 'fim-11',
      );
      expect(ap.quantos, 1);

      ap.saidas.single();
      await tester.pumpAndSettle();

      expect(
        f.canal.doTipo('sair'),
        hasLength(1),
        reason: 'sair da mesa é comando, e comando sai por uma porta só',
      );
      expect(find.byType(MesaOnlineScreen), findsNothing);
    });
  });

  // =========================================================================
  // O aviso de produção
  // =========================================================================
  group('o diálogo de produção', () {
    testWidgets('o encerramento abre o aviso uma vez, sobre a mesa', (
      tester,
    ) async {
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);

      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

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

      // Nenhum aviso antes do fim.
      b.canal.servidorEnvia(
        envelopeEstado(visaoDeJogo(), versaoEstado: 1, eventoId: 'e1'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Fim da partida'), findsNothing);

      b.canal.servidorEnvia(
        envelopeEstado(visaoTerminal(), versaoEstado: 2, eventoId: 'fim-2'),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Fim da partida'), findsOneWidget);
      // O resultado continua sendo o da mesa, e não uma segunda contagem.
      expect(find.text('🏆 Sua dupla venceu'), findsOneWidget);

      // Fechar o aviso devolve a mesa, com o retrato terminal inteiro.
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
  });
}
