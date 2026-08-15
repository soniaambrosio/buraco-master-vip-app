// exclusao_conta_test.dart — O FLUXO DE EXCLUSÃO, do aviso ao logout.
//
// OS de Exclusão de Conta e Dados do Jogador v1.
//
// O que esta suíte prova, e o que ela deliberadamente NÃO prova.
//
// PROVA: a ordem do fluxo (aviso → confirmação → reautenticação quando
// necessária → execução → encerramento da sessão), e cada desvio dela — a
// recusa por torneio, a palavra errada, a reautenticação vencida, a desistência
// no seletor de conta, a falha parcial, o duplo toque e a chamada repetida.
//
// NÃO PROVA que o dado saiu do banco: isso é `functions-conta/test/
// integracao.emulador.test.js`, e não teria como ser aqui — não existe fake
// oficial de `cloud_functions`, que é justamente a razão de a porta
// `FonteDeExclusaoDeConta` existir.
//
// A `FonteRoteirizada` abaixo segue a convenção da casa (`FonteEspia` em
// test/sessao, `ValidadorRoteirizado` em test/billing): dublê escrito à mão que
// implementa a porta e CONTA chamadas, para que as afirmações sobre o duplo
// toque sejam sobre um número, e não sobre uma impressão.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:buraco_master_vip/billing/gerenciar_assinatura.dart';
import 'package:buraco_master_vip/conta/controlador_exclusao.dart';
import 'package:buraco_master_vip/conta/exclusao_de_conta.dart';
import 'package:buraco_master_vip/conta/fonte_exclusao.dart';
import 'package:buraco_master_vip/screens/excluir_conta_screen.dart';

// ===========================================================================
// DUBLÊS
// ===========================================================================

ResumoDaExclusao resumoPadrao({
  bool podeExcluir = true,
  String? recusa,
  List<BloqueioDeTorneio> bloqueios = const [],
}) {
  return ResumoDaExclusao(
    podeExcluir: podeExcluir,
    recusa: recusa,
    bloqueios: bloqueios,
    palavraDeConfirmacao: 'EXCLUIR',
    apagado: const [
      LinhaDoAviso(
        caminho: 'users/{uid}',
        dominio: 'conta',
        porque: 'o documento raiz do jogador',
      ),
    ],
    anonimizado: const [
      LinhaDoAviso(
        caminho: 'rankingStandings/{seasonId|uid}',
        dominio: 'ranking',
        porque: 'a linha fica, o rosto sai',
      ),
    ],
    desvinculado: const [
      LinhaDoAviso(
        caminho: 'compras/{hash}',
        dominio: 'billing',
        porque: 'integridade financeira',
      ),
    ],
    retido: const [
      LinhaDoAviso(
        caminho: 'playerModeration/{uid}',
        dominio: 'moderacao',
        porque: 'não se apaga a própria punição',
      ),
    ],
  );
}

/// Dublê da porta, com o roteiro na mão do teste.
class FonteRoteirizada implements FonteDeExclusaoDeConta {
  FonteRoteirizada({ResumoDaExclusao? resumo}) : _resumo = resumo ?? resumoPadrao();

  final ResumoDaExclusao _resumo;

  /// As respostas de `excluir`, em ordem. Cada chamada consome uma; a última
  /// se repete quando a lista acaba — é o que permite escrever "falha, depois
  /// sucesso" sem inventar uma terceira entrada.
  List<Object> respostas = [
    const ResultadoDaExclusao(concluida: true, repeticao: false),
  ];

  FalhaExclusao? falhaAoResumir;

  int chamadasResumir = 0;
  int chamadasExcluir = 0;
  final List<String> confirmacoesRecebidas = [];

  /// Quando não-nulo, `excluir` fica pendurado até o teste completar. É como se
  /// encena o duplo toque com uma chamada realmente em voo.
  Completer<void>? travaDoExcluir;

  @override
  Future<ResumoDaExclusao> resumir() async {
    chamadasResumir++;
    final falha = falhaAoResumir;
    if (falha != null) throw falha;
    return _resumo;
  }

  @override
  Future<ResultadoDaExclusao> excluir({required String confirmacao}) async {
    chamadasExcluir++;
    confirmacoesRecebidas.add(confirmacao);

    final trava = travaDoExcluir;
    if (trava != null) await trava.future;

    final resposta = respostas.length > 1
        ? respostas.removeAt(0)
        : respostas.first;
    if (resposta is FalhaExclusao) throw resposta;
    return resposta as ResultadoDaExclusao;
  }
}

void main() {
  late FonteRoteirizada fonte;
  late int encerramentos;
  late int reautenticacoes;
  late bool reautenticacaoAceita;

  /// Os endereços que o controlador mandou abrir, em ordem. Lista, e não
  /// contador: o teste do deep link precisa afirmar PARA ONDE se foi, e não só
  /// que se foi.
  late List<Uri> linksAbertos;
  late bool aberturaDeLinkAceita;

  setUp(() {
    fonte = FonteRoteirizada();
    encerramentos = 0;
    reautenticacoes = 0;
    reautenticacaoAceita = true;
    linksAbertos = <Uri>[];
    aberturaDeLinkAceita = true;
  });

  ControladorDeExclusao criar({
    FonteRoteirizada? comFonte,
    AssinaturaParaGerenciar assinatura = AssinaturaParaGerenciar.nenhuma,
    Object? erroAoLerAssinatura,
    Object? erroAoAbrirLink,
  }) {
    final c = ControladorDeExclusao(
      fonte: comFonte ?? fonte,
      reautenticar: () async {
        reautenticacoes++;
        return reautenticacaoAceita;
      },
      encerrarSessao: () async {
        encerramentos++;
      },
      lerAssinatura: () async {
        if (erroAoLerAssinatura != null) throw erroAoLerAssinatura;
        return assinatura;
      },
      abrirLinkExterno: (destino) async {
        linksAbertos.add(destino);
        if (erroAoAbrirLink != null) throw erroAoAbrirLink;
        return aberturaDeLinkAceita;
      },
    );
    addTearDown(c.dispose);
    return c;
  }

  // =========================================================================
  // O CAMINHO FELIZ
  // =========================================================================
  group('aviso → confirmação → execução → sessão encerrada', () {
    test('o aviso vem do servidor, e não de uma lista escrita no aplicativo', () async {
      final c = criar();
      await c.carregarAviso();

      expect(c.fase, FaseDaExclusao.aguardandoConfirmacao);
      // As quatro listas chegam separadas: o que some, o que fica sem nome, o
      // que fica sem vínculo e o que fica. A quarta é a que responde a pergunta
      // que o jogador realmente tem.
      expect(c.resumo!.apagado, hasLength(1));
      expect(c.resumo!.anonimizado, hasLength(1));
      expect(c.resumo!.desvinculado, hasLength(1));
      expect(c.resumo!.retido, hasLength(1));
      expect(c.resumo!.retido.first.porque, contains('punição'));
    });

    test('a palavra certa executa e encerra a sessão, nesta ordem', () async {
      final c = criar();
      await c.carregarAviso();
      await c.confirmar('EXCLUIR');

      expect(fonte.chamadasExcluir, 1);
      expect(encerramentos, 1);
      expect(c.fase, FaseDaExclusao.concluida);
    });

    test('a sessão NÃO é encerrada antes de o backend confirmar', () async {
      // Encerrar antes deixaria o jogador deslogado de uma conta que continua
      // existindo, sem saber o que aconteceu.
      fonte.travaDoExcluir = Completer<void>();
      final c = criar();
      await c.carregarAviso();

      final futuro = c.confirmar('EXCLUIR');
      await Future<void>.delayed(Duration.zero);

      expect(c.fase, FaseDaExclusao.excluindo);
      expect(encerramentos, 0, reason: 'ainda não houve confirmação do servidor');

      fonte.travaDoExcluir!.complete();
      await futuro;
      expect(encerramentos, 1);
    });

    test('a palavra é normalizada, e é a digitada que vai para o servidor', () async {
      final c = criar();
      await c.carregarAviso();
      await c.confirmar('  excluir  ');

      expect(fonte.chamadasExcluir, 1);
      expect(c.fase, FaseDaExclusao.concluida);
    });

    test('carregar o aviso duas vezes não abre duas requisições', () async {
      final c = criar();
      await Future.wait([c.carregarAviso(), c.carregarAviso()]);
      expect(fonte.chamadasResumir, 1);
    });
  });

  // =========================================================================
  // A CONFIRMAÇÃO
  // =========================================================================
  group('a palavra de confirmação', () {
    test('a palavra errada não chega ao servidor', () async {
      final c = criar();
      await c.carregarAviso();
      await c.confirmar('EXCLUI');

      expect(fonte.chamadasExcluir, 0, reason: 'nem sai do aplicativo');
      expect(c.fase, FaseDaExclusao.falhou);
      expect(c.falha!.motivo, MotivoFalhaExclusao.confirmacaoInvalida);
    });

    test('sem resumo carregado, nenhuma palavra confere', () async {
      // Não há palavra esperada, então o botão não pode acender por acidente.
      final c = criar();
      expect(c.confirmacaoConfere('EXCLUIR'), isFalse);
    });

    test('a conferência local é conveniência: o servidor confere de novo', () async {
      // Encena um aplicativo modificado que mandou a palavra errada mesmo assim.
      fonte.respostas = [
        const FalhaExclusao(
          MotivoFalhaExclusao.confirmacaoInvalida,
          'recusado no servidor',
        ),
      ];
      final c = criar();
      await c.carregarAviso();
      await c.confirmar('EXCLUIR');

      expect(c.fase, FaseDaExclusao.falhou);
      expect(c.falha!.motivo, MotivoFalhaExclusao.confirmacaoInvalida);
    });
  });

  // =========================================================================
  // REAUTENTICAÇÃO
  // =========================================================================
  group('reautenticação', () {
    test('só é pedida quando o servidor diz que precisa', () async {
      final c = criar();
      await c.carregarAviso();
      await c.confirmar('EXCLUIR');

      expect(reautenticacoes, 0, reason: 'pedir sempre faria digitar a senha à toa');
    });

    test('recusa por sessão antiga pede a credencial e repete UMA vez', () async {
      fonte.respostas = [
        const FalhaExclusao(
          MotivoFalhaExclusao.reautenticacaoNecessaria,
          'auth_time velho',
        ),
        const ResultadoDaExclusao(concluida: true, repeticao: false),
      ];
      final c = criar();
      await c.carregarAviso();
      await c.confirmar('EXCLUIR');

      expect(reautenticacoes, 1);
      expect(fonte.chamadasExcluir, 2);
      expect(c.fase, FaseDaExclusao.concluida);
      expect(encerramentos, 1);
    });

    test('desistir no seletor de conta volta ao aviso, com a conta intacta', () async {
      reautenticacaoAceita = false;
      fonte.respostas = [
        const FalhaExclusao(
          MotivoFalhaExclusao.reautenticacaoNecessaria,
          'auth_time velho',
        ),
      ];
      final c = criar();
      await c.carregarAviso();
      await c.confirmar('EXCLUIR');

      expect(c.fase, FaseDaExclusao.aguardandoConfirmacao);
      expect(c.falha, isNull, reason: 'desistir não é falha a reportar');
      expect(encerramentos, 0);
      expect(fonte.chamadasExcluir, 1);
    });

    test('se a segunda tentativa também recusar, para — e não vira laço', () async {
      // Relógio do aparelho fora de hora, provedor devolvendo credencial velha:
      // nada que a pessoa resolva apertando de novo. Um laço aqui seria um
      // pedido de senha infinito.
      fonte.respostas = [
        const FalhaExclusao(
          MotivoFalhaExclusao.reautenticacaoNecessaria,
          'de novo',
        ),
      ];
      final c = criar();
      await c.carregarAviso();
      await c.confirmar('EXCLUIR');

      expect(reautenticacoes, 1);
      expect(fonte.chamadasExcluir, 2);
      expect(c.fase, FaseDaExclusao.falhou);
      expect(c.falha!.motivo, MotivoFalhaExclusao.reautenticacaoNecessaria);
    });

    test('exceção no fluxo de reautenticação é tratada como desistência', () async {
      final c = ControladorDeExclusao(
        fonte: fonte,
        reautenticar: () async => throw StateError('provedor caiu'),
        encerrarSessao: () async => encerramentos++,
        lerAssinatura: () async => AssinaturaParaGerenciar.nenhuma,
        abrirLinkExterno: (_) async => true,
      );
      addTearDown(c.dispose);
      fonte.respostas = [
        const FalhaExclusao(MotivoFalhaExclusao.reautenticacaoNecessaria, 'x'),
      ];

      await c.carregarAviso();
      await c.confirmar('EXCLUIR');

      expect(c.fase, FaseDaExclusao.aguardandoConfirmacao);
      expect(encerramentos, 0);
    });
  });

  // =========================================================================
  // RECUSAS E FALHAS
  // =========================================================================
  group('recusas do servidor', () {
    test('torneio em andamento bloqueia antes de a pessoa digitar', () async {
      final travado = FonteRoteirizada(
        resumo: resumoPadrao(
          podeExcluir: false,
          recusa: 'torneioEmAndamento',
          bloqueios: const [
            BloqueioDeTorneio(
              tournamentId: 'copa-verao',
              editionId: 'e3',
              status: 'inscrito',
            ),
          ],
        ),
      );
      final c = criar(comFonte: travado);
      await c.carregarAviso();

      expect(c.fase, FaseDaExclusao.bloqueada);
      expect(c.resumo!.bloqueios.single.tournamentId, 'copa-verao');
    });

    test('falha parcial é retomável, e o aplicativo sabe disso', () async {
      fonte.respostas = [
        const FalhaExclusao(MotivoFalhaExclusao.parcial, 'parou no meio'),
      ];
      final c = criar();
      await c.carregarAviso();
      await c.confirmar('EXCLUIR');

      expect(c.fase, FaseDaExclusao.falhou);
      expect(c.falha!.motivo, MotivoFalhaExclusao.parcial);
      expect(
        c.falha!.vaiAdiantarTentarDeNovo,
        isTrue,
        reason: 'o backend retoma de onde parou — repetir é a ação certa',
      );
      expect(encerramentos, 0);
    });

    test('depois da falha parcial, tentar de novo conclui', () async {
      fonte.respostas = [
        const FalhaExclusao(MotivoFalhaExclusao.parcial, 'parou no meio'),
        const ResultadoDaExclusao(concluida: true, repeticao: false),
      ];
      final c = criar();
      await c.carregarAviso();
      await c.confirmar('EXCLUIR');

      c.tentarDeNovo();
      expect(c.fase, FaseDaExclusao.aguardandoConfirmacao);

      await c.confirmar('EXCLUIR');
      expect(c.fase, FaseDaExclusao.concluida);
      expect(encerramentos, 1);
    });

    test('a palavra errada NÃO é retomável', () async {
      final c = criar();
      await c.carregarAviso();
      await c.confirmar('nada a ver');
      expect(c.falha!.vaiAdiantarTentarDeNovo, isFalse);
    });

    test('falha ao carregar o aviso não derruba a tela', () async {
      fonte.falhaAoResumir = const FalhaExclusao(
        MotivoFalhaExclusao.indisponivel,
        'rede',
      );
      final c = criar();
      await c.carregarAviso();

      expect(c.fase, FaseDaExclusao.falhou);
      expect(c.falha!.vaiAdiantarTentarDeNovo, isTrue);
    });

    test('uma fonte que escapa do contrato vira falha de domínio', () async {
      fonte.respostas = [];
      final quebrada = FonteRoteirizada();
      quebrada.respostas = [];
      final c = criar(comFonte: quebrada);
      await c.carregarAviso();
      await c.confirmar('EXCLUIR');

      expect(c.fase, FaseDaExclusao.falhou);
      expect(c.falha, isNotNull);
    });
  });

  // =========================================================================
  // CHAMADA DUPLICADA
  // =========================================================================
  group('chamada duplicada', () {
    test('dois toques no botão abrem UMA chamada', () async {
      fonte.travaDoExcluir = Completer<void>();
      final c = criar();
      await c.carregarAviso();

      final primeiro = c.confirmar('EXCLUIR');
      final segundo = c.confirmar('EXCLUIR');

      fonte.travaDoExcluir!.complete();
      await Future.wait([primeiro, segundo]);

      expect(c.execucoesEmitidas, 1);
      expect(fonte.chamadasExcluir, 1);
      expect(encerramentos, 1, reason: 'e a sessão é encerrada uma vez só');
    });

    test('repeticao: true é SUCESSO, e não erro', () async {
      // Acontece quando a rede cai entre a execução e a resposta: o backend já
      // tinha terminado. Tratar como erro deixaria o jogador olhando uma falha
      // de uma conta que já não existe.
      fonte.respostas = [
        const ResultadoDaExclusao(concluida: false, repeticao: true),
      ];
      final c = criar();
      await c.carregarAviso();
      await c.confirmar('EXCLUIR');

      expect(c.fase, FaseDaExclusao.concluida);
      expect(encerramentos, 1);
    });

    test('confirmar depois de concluída não faz nada', () async {
      final c = criar();
      await c.carregarAviso();
      await c.confirmar('EXCLUIR');
      await c.confirmar('EXCLUIR');

      expect(fonte.chamadasExcluir, 1);
      expect(encerramentos, 1);
    });

    test('falha ao encerrar a sessão não desmente a exclusão', () async {
      // A conta já foi apagada no servidor. O token local que sobrou está morto
      // de qualquer forma; marcar falha aqui faria a tela mentir.
      final c = ControladorDeExclusao(
        fonte: fonte,
        reautenticar: () async => true,
        encerrarSessao: () async => throw StateError('signOut falhou'),
        lerAssinatura: () async => AssinaturaParaGerenciar.nenhuma,
        abrirLinkExterno: (_) async => true,
      );
      addTearDown(c.dispose);

      await c.carregarAviso();
      await c.confirmar('EXCLUIR');

      expect(c.fase, FaseDaExclusao.concluida);
    });
  });

  // =========================================================================
  // A TELA
  // =========================================================================
  group('a tela', () {
    /// Superfície de telefone. O padrão 800x600 do `flutter_test` derruba estas
    /// telas com overflow — é a mesma montagem de test/sessao.
    Future<void> montar(WidgetTester tester, ControladorDeExclusao c) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: ExcluirContaScreen(
            controlador: c,
            onVoltar: () {},
            onConcluida: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('abre pedindo o aviso ao servidor', (tester) async {
      final c = criar();
      await montar(tester, c);

      expect(fonte.chamadasResumir, 1);
      expect(find.byKey(const Key('exclusao-aviso')), findsOneWidget);
    });

    testWidgets('mostra as advertências que não vêm da matriz', (tester) async {
      // A assinatura da Play e a ausência de desfazer: nenhuma classificação de
      // coleção as produziria, e as duas são o que evita uma cobrança surpresa.
      final c = criar();
      await montar(tester, c);

      expect(find.textContaining('Google Play'), findsOneWidget);
      expect(find.textContaining('Não há como desfazer'), findsOneWidget);
    });

    testWidgets('mostra os quatro grupos, inclusive o que é guardado', (
      tester,
    ) async {
      final c = criar();
      await montar(tester, c);

      // `scrollUntilVisible` para cada um: a lista é preguiçosa e só constrói o
      // que cabe na tela. Sem rolar, o grupo "retido" — que é o último e o mais
      // importante deles — simplesmente não existiria na árvore.
      for (final grupo in ['apagado', 'anonimizado', 'desvinculado', 'retido']) {
        final alvo = find.byKey(Key('exclusao-grupo-$grupo'));
        await tester.scrollUntilVisible(alvo, 300);
        expect(alvo, findsOneWidget, reason: 'o grupo $grupo precisa aparecer');
      }
    });

    testWidgets('o botão só acende com a palavra digitada', (tester) async {
      final c = criar();
      await montar(tester, c);

      final botao = find.byKey(const Key('exclusao-botao-confirmar'));
      await tester.scrollUntilVisible(botao, 300);

      expect(tester.widget<FilledButton>(botao).onPressed, isNull);

      await tester.enterText(
        find.byKey(const Key('exclusao-campo-confirmacao')),
        'EXCLUIR',
      );
      await tester.pumpAndSettle();

      expect(tester.widget<FilledButton>(botao).onPressed, isNotNull);
    });

    testWidgets('tocar no botão executa e a tela mostra o desfecho', (
      tester,
    ) async {
      final c = criar();
      await montar(tester, c);

      final botao = find.byKey(const Key('exclusao-botao-confirmar'));
      await tester.scrollUntilVisible(botao, 300);
      await tester.enterText(
        find.byKey(const Key('exclusao-campo-confirmacao')),
        'EXCLUIR',
      );
      await tester.pumpAndSettle();
      await tester.tap(botao);
      await tester.pumpAndSettle();

      expect(fonte.chamadasExcluir, 1);
      expect(encerramentos, 1);
      expect(find.byKey(const Key('exclusao-concluida')), findsOneWidget);
    });

    testWidgets('torneio em andamento mostra a pendência, e não o campo', (
      tester,
    ) async {
      final travado = FonteRoteirizada(
        resumo: resumoPadrao(
          podeExcluir: false,
          recusa: 'torneioEmAndamento',
          bloqueios: const [
            BloqueioDeTorneio(
              tournamentId: 'copa-verao',
              editionId: 'e3',
              status: 'inscrito',
            ),
          ],
        ),
      );
      final c = criar(comFonte: travado);
      await montar(tester, c);

      expect(find.byKey(const Key('exclusao-bloqueada')), findsOneWidget);
      expect(
        find.byKey(const Key('exclusao-campo-confirmacao')),
        findsNothing,
        reason: 'não se pede a palavra para depois recusar',
      );
      // NOMEIA a inscrição: "cancele suas inscrições" sem dizer quais manda a
      // pessoa procurar.
      expect(find.textContaining('copa-verao'), findsOneWidget);
    });

    testWidgets('a falha parcial diz que parte já foi excluída', (tester) async {
      fonte.respostas = [
        const FalhaExclusao(MotivoFalhaExclusao.parcial, 'parou no meio'),
      ];
      final c = criar();
      await montar(tester, c);

      final botao = find.byKey(const Key('exclusao-botao-confirmar'));
      await tester.scrollUntilVisible(botao, 300);
      await tester.enterText(
        find.byKey(const Key('exclusao-campo-confirmacao')),
        'EXCLUIR',
      );
      await tester.pumpAndSettle();
      await tester.tap(botao);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('exclusao-falhou')), findsOneWidget);
      // Dizer "não foi possível" faria a pessoa supor que nada aconteceu.
      expect(find.textContaining('começou e não terminou'), findsOneWidget);
      expect(
        find.byKey(const Key('exclusao-botao-tentar-de-novo')),
        findsOneWidget,
      );
    });

    testWidgets('durante a execução não há botão de voltar', (tester) async {
      // Sair da tela não cancela as etapas do backend. Oferecer um cancelamento
      // que não existe seria pior do que não oferecer nenhum.
      fonte.travaDoExcluir = Completer<void>();
      final c = criar();
      await montar(tester, c);

      final botao = find.byKey(const Key('exclusao-botao-confirmar'));
      await tester.scrollUntilVisible(botao, 300);
      await tester.enterText(
        find.byKey(const Key('exclusao-campo-confirmacao')),
        'EXCLUIR',
      );
      await tester.pumpAndSettle();
      await tester.tap(botao);
      await tester.pump();

      expect(find.byKey(const Key('exclusao-executando')), findsOneWidget);
      final voltar = tester.widget<IconButton>(find.byType(IconButton));
      expect(voltar.onPressed, isNull);

      fonte.travaDoExcluir!.complete();
      await tester.pumpAndSettle();
    });
  });

  // =========================================================================
  // A ASSINATURA DA GOOGLE PLAY
  //
  // OS de Conformidade de Exclusão de Conta, §7.
  //
  // O que este grupo existe para impedir, em uma frase: que a saída oferecida
  // para o problema da cobrança vire, por descuido, mais um caminho para
  // excluir a conta. Toda afirmação abaixo sobre "gerenciar" vem acompanhada da
  // afirmação de que NADA foi excluído — porque é a combinação das duas que
  // prova o ponto, e não cada uma sozinha.
  // =========================================================================
  group('gerenciar a assinatura', () {
    AssinaturaParaGerenciar vip({
      bool renovacaoAutomatica = true,
      String? produtoId = 'master_vip_mensal',
    }) {
      return AssinaturaParaGerenciar(
        situacao: SituacaoDaAssinatura.vigente,
        produtoId: produtoId,
        renovacaoAutomatica: renovacaoAutomatica,
      );
    }

    test('o assinante ativo tem o caminho para a Play', () async {
      final c = criar(assinatura: vip());
      await c.carregarAviso();

      expect(c.assinatura.situacao, SituacaoDaAssinatura.vigente);
      expect(c.assinatura.ofereceGerenciamento, isTrue);
    });

    test('quem nunca assinou não recebe estado enganoso', () async {
      // Sem assinatura, o controlador não oferece gerenciamento nenhum — e a
      // tela, por consequência, não desenha um botão que sugeriria uma
      // assinatura inexistente.
      final c = criar();
      await c.carregarAviso();

      expect(c.assinatura.situacao, SituacaoDaAssinatura.nenhuma);
      expect(c.assinatura.ofereceGerenciamento, isFalse);
      expect(c.assinatura.produtoId, isNull);
    });

    test('falha ao LER a assinatura não impede o aviso, e não inventa VIP', () async {
      // O billing cair não pode trancar a porta de saída da conta.
      final c = criar(erroAoLerAssinatura: StateError('firestore fora do ar'));
      await c.carregarAviso();

      expect(c.fase, FaseDaExclusao.aguardandoConfirmacao);
      expect(c.assinatura.ofereceGerenciamento, isFalse);
    });

    test('abrir a Play NÃO executa exclusão', () async {
      final c = criar(assinatura: vip());
      await c.carregarAviso();

      final abriu = await c.abrirGerenciamentoDaAssinatura();

      expect(abriu, isTrue);
      expect(c.aberturasDeAssinatura, 1);
      // Os três números que provam que nada da exclusão aconteceu.
      expect(c.execucoesEmitidas, 0);
      expect(fonte.chamadasExcluir, 0);
      expect(encerramentos, 0);
      // E a fase não se mexeu: quem volta da loja encontra a tela como deixou.
      expect(c.fase, FaseDaExclusao.aguardandoConfirmacao);
    });

    test('falha ao ABRIR a Play não executa exclusão e não trava o fluxo', () async {
      aberturaDeLinkAceita = false;
      final c = criar(assinatura: vip());
      await c.carregarAviso();

      final abriu = await c.abrirGerenciamentoDaAssinatura();

      expect(abriu, isFalse);
      expect(c.falhouAoAbrirAssinatura, isTrue);
      expect(c.execucoesEmitidas, 0);
      expect(fonte.chamadasExcluir, 0);
      // O FLUXO CONTINUA INTEIRO: a exclusão ainda é possível depois da falha.
      expect(c.fase, FaseDaExclusao.aguardandoConfirmacao);
      await c.confirmar('EXCLUIR');
      expect(fonte.chamadasExcluir, 1);
    });

    test('exceção do canal de plataforma vira "não abriu", e não crash', () async {
      final c = criar(
        assinatura: vip(),
        erroAoAbrirLink: StateError('MissingPluginException'),
      );
      await c.carregarAviso();

      expect(await c.abrirGerenciamentoDaAssinatura(), isFalse);
      expect(c.falhouAoAbrirAssinatura, isTrue);
      expect(c.execucoesEmitidas, 0);
    });

    test('com produto conhecido, vai para o deep link do produto', () async {
      final c = criar(assinatura: vip(produtoId: 'master_vip_mensal'));
      await c.carregarAviso();
      await c.abrirGerenciamentoDaAssinatura();

      expect(linksAbertos, hasLength(1));
      final destino = linksAbertos.single;
      expect(destino.host, 'play.google.com');
      expect(destino.queryParameters['sku'], 'master_vip_mensal');
      expect(destino.queryParameters['package'], kPacotePlayOficial);
    });

    test('sem produto confiável, vai para a central geral', () async {
      final c = criar(assinatura: vip(produtoId: null));
      await c.carregarAviso();
      await c.abrirGerenciamentoDaAssinatura();

      expect(linksAbertos.single.toString(), kCentralDeAssinaturasPlay);
    });

    test('a exclusão NÃO depende de cancelar a assinatura', () async {
      // O ponto da OS: ter assinatura viva não é impedimento. Ninguém precisa
      // tocar em "gerenciar" para poder sair.
      final c = criar(assinatura: vip());
      await c.carregarAviso();

      expect(c.fase, FaseDaExclusao.aguardandoConfirmacao);
      await c.confirmar('EXCLUIR');

      expect(fonte.chamadasExcluir, 1);
      expect(c.fase, FaseDaExclusao.concluida);
      // E nada foi cancelado por baixo do pano: a Play nem foi aberta.
      expect(c.aberturasDeAssinatura, 0);
      expect(linksAbertos, isEmpty);
    });

    testWidgets('a tela mostra a ação ao assinante, e tocar nela não exclui',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      final c = criar(assinatura: vip());
      await tester.pumpWidget(
        MaterialApp(
          home: ExcluirContaScreen(
            controlador: c,
            onVoltar: () {},
            onConcluida: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final botao = find.byKey(
        const Key('exclusao-botao-gerenciar-assinatura'),
      );
      expect(botao, findsOneWidget);
      expect(find.textContaining('renovação automática'), findsOneWidget);

      await tester.tap(botao);
      await tester.pumpAndSettle();

      expect(c.aberturasDeAssinatura, 1);
      // O QUE MAIS IMPORTA NESTE TESTE: o toque abriu a loja e não moveu a
      // exclusão um milímetro.
      expect(fonte.chamadasExcluir, 0);
      expect(encerramentos, 0);
      expect(find.byKey(const Key('exclusao-concluida')), findsNothing);
      // E o portão da palavra continua fechado: o botão de excluir segue
      // desabilitado, porque ninguém digitou nada.
      final excluir = find.byKey(const Key('exclusao-botao-confirmar'));
      await tester.scrollUntilVisible(excluir, 300);
      expect(tester.widget<FilledButton>(excluir).onPressed, isNull);
    });

    testWidgets('a tela NÃO mostra a ação a quem não tem assinatura',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      final c = criar();
      await tester.pumpWidget(
        MaterialApp(
          home: ExcluirContaScreen(
            controlador: c,
            onVoltar: () {},
            onConcluida: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('exclusao-assinatura')), findsNothing);
      // O aviso de texto, esse, continua para TODO MUNDO: quem tem assinatura
      // e não sabe também precisa lê-lo.
      expect(find.textContaining('NÃO é cancelada'), findsOneWidget);
    });

    testWidgets('quando a Play não abre, a tela diz — e a exclusão segue viável',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      aberturaDeLinkAceita = false;
      final c = criar(assinatura: vip());
      await tester.pumpWidget(
        MaterialApp(
          home: ExcluirContaScreen(
            controlador: c,
            onVoltar: () {},
            onConcluida: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('exclusao-botao-gerenciar-assinatura')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('exclusao-assinatura-falhou')),
        findsOneWidget,
      );
      // NÃO virou a tela de erro do fluxo: nada da exclusão falhou.
      expect(find.byKey(const Key('exclusao-falhou')), findsNothing);
      expect(find.byKey(const Key('exclusao-aviso')), findsOneWidget);
      expect(fonte.chamadasExcluir, 0);
    });
  });
}
