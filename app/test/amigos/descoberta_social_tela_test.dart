// descoberta_social_tela_test.dart — as duas superfícies do grafo social.
//
// A tela de Amigos e a faixa do Perfil visitado, exercitadas contra o transporte
// falso. O que se prova aqui é o que só aparece quando há widget: que o botão
// desenhado é o que o servidor ofereceu, que o toque leva ao Perfil daquele
// `publicId` e de nenhum outro, e que a resposta da autoridade volta para a
// tela depois da ação.
//
// SUPERFÍCIE DE TELEFONE em toda a suíte: o padrão do `flutter_test` é 800x600,
// que é paisagem de desktop e faz estas telas estourarem em overflow.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:buraco_master_vip/amigos/escopo_social.dart';
import 'package:buraco_master_vip/amigos/estado_social.dart';
import 'package:buraco_master_vip/amigos/leitor_social.dart';
import 'package:buraco_master_vip/casca/amigos_de_producao.dart';
import 'package:buraco_master_vip/pages/perfil_page.dart';
import 'package:buraco_master_vip/sessao/escopo_sessao.dart';
import 'package:buraco_master_vip/sessao/fonte_identidade.dart';
import 'package:buraco_master_vip/sessao/identidade_publica_sessao.dart';
import 'package:buraco_master_vip/sessao/sessao_do_jogador.dart';

import 'bancada_social.dart';

class _FonteFalsa implements FonteDeIdentidade {
  @override
  Future<IdentidadePublica> obterMinhaIdentidade() async => IdentidadePublica(
    publicId: 'P0EUMESMO0001',
    apelido: 'Ana',
    avatarRef: null,
    criada: false,
    estado: EstadoPerfil.ativo,
    limites: LimitesSociais.desconhecidos,
    // `apelidoMinimo: 3` é o que o backend publica; a tela usa este número, e
    // não uma constante local, como freio de ida ao servidor.
    edicao: const MetadadosDeEdicao(
      apelidoMinimo: 3,
      apelidoMaximo: 24,
      catalogoDeAvatarDisponivel: false,
    ),
  );
}

/// Deixa a tela ASSENTAR de verdade.
///
/// `pumpAndSettle` sozinho NÃO basta aqui, e não é manha de teste: o
/// `PerfilService` tem um atraso artificial de 350 ms, e o `pumpAndSettle`
/// volta assim que a árvore para de se mexer — o que acontece ANTES de esse
/// atraso terminar. Sem o pulo no tempo, o Perfil é medido ainda no
/// esqueleto, e a faixa social — que só nasce depois da carga — nunca existiu
/// no instante da asserção.
///
/// Que o pulo não MASCARA nada se comprova removendo-o: os casos do Perfil
/// passam a falhar por asserção sobre estado que não chegou, e não por
/// timeout.
Future<void> _assentar(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
}

void main() {
  late TransporteSocialFalso t;
  late LeitorSocial social;
  late SessaoDoJogador sessao;
  late StreamController<String?> uids;

  setUp(() {
    t = TransporteSocialFalso();
    social = LeitorSocial(transporte: t);
    uids = StreamController<String?>.broadcast();
    sessao = SessaoDoJogador(
      fonte: _FonteFalsa(),
      uids: uids.stream,
      uidInicial: 'uid-A',
    );
  });

  tearDown(() {
    social.dispose();
    sessao.dispose();
    uids.close();
  });

  Future<void> montar(
    WidgetTester tester,
    Widget tela, {
    bool assentar = true,
  }) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      EscopoSessao(
        sessao: sessao,
        child: EscopoSocial(
          social: social,
          child: MaterialApp(home: tela),
        ),
      ),
    );
    //  para os casos que precisam OLHAR o estado de
    // carregamento: enquanto o  está na tela, a
    // árvore nunca para de se mexer e  estoura por tempo. Não é
    // limitação do teste — é a animação existindo, que é o que se quer ver.
    if (assentar) await _assentar(tester);
  }


  String textoDaTela(WidgetTester tester) => tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data ?? '')
      .join(' | ');

  // =========================================================================
  // A tela de Amigos
  // =========================================================================
  group('Amigos — as listas vêm da autoridade', () {
    testWidgets('a lista desenha quem o servidor devolveu, e emite UMA consulta', (
      tester,
    ) async {
      t.respostaAmigos = paginaFalsa([
        jogadorFalso('P1', apelido: 'Bia'),
        jogadorFalso('P2', apelido: 'Caio'),
      ]);
      await montar(tester, const AmigosDeProducao());

      expect(find.text('Bia'), findsOneWidget);
      expect(find.text('Caio'), findsOneWidget);
      expect(t.chamadasDe('listarAmigos'), 1);
    });

    testWidgets('nenhum nome da maquete chega à tela', (tester) async {
      // A maquete tem seis pessoas escritas dentro. Se um dia ela voltar ao
      // caminho, é aqui que se vê.
      await montar(tester, const AmigosDeProducao());
      final texto = textoDaTela(tester);
      for (final daMaquete in const [
        'Cláudia',
        'Beto',
        'Fernanda',
        'Mateus',
        'Sofia',
        'Larissa',
        'SONIA-RAINHA',
      ]) {
        expect(texto, isNot(contains(daMaquete)), reason: daMaquete);
      }
    });

    testWidgets('lista vazia CONFIRMADA diz que está vazia; carregando, não', (
      tester,
    ) async {
      t.manual = true;
      await montar(tester, const AmigosDeProducao(), assentar: false);
      // Dois quadros: o primeiro monta, o segundo entrega a notificação que o
      // leitor publica por microtask (ver ).
      await tester.pump();
      await tester.pump();

      final carregando = textoDaTela(tester);
      expect(carregando, contains('Carregando'));
      expect(
        carregando,
        isNot(contains('ainda não tem amigos')),
        reason: 'afirmou "sem amigos" antes de a autoridade responder',
      );

      t.responder(0, PaginaSocial.vazia);
      await _assentar(tester);
      expect(textoDaTela(tester), contains('ainda não tem amigos'));
    });

    testWidgets('trocar de aba consulta a aba nova, e só ela', (tester) async {
      t.respostaRecebidas = paginaFalsa([jogadorFalso('PR', apelido: 'Duda')]);
      await montar(tester, const AmigosDeProducao());
      expect(t.chamadasDe('listarRecebidas'), 0);

      await tester.tap(find.text('Recebidos'));
      await _assentar(tester);

      expect(find.text('Duda'), findsOneWidget);
      expect(t.chamadasDe('listarRecebidas'), 1);
      expect(t.chamadasDe('listarAmigos'), 1, reason: 'consultou de novo à toa');
    });

    testWidgets('o botão da aba de recebidas é o VERBO da ação', (tester) async {
      t.respostaRecebidas = paginaFalsa([jogadorFalso('PR', apelido: 'Duda')]);
      await montar(tester, const AmigosDeProducao());
      await tester.tap(find.text('Recebidos'));
      await _assentar(tester);

      expect(find.text('Aceitar'), findsOneWidget);
      expect(find.text('Recusar'), findsOneWidget);
      // E nada de ações que a lista não implica.
      expect(find.text('Remover'), findsNothing);
    });
  });

  // =========================================================================
  // Busca
  // =========================================================================
  group('busca — os botões são os do servidor, e o estado volta', () {
    testWidgets('termo curto demais nem sai do aparelho', (tester) async {
      await montar(tester, const AmigosDeProducao());
      await tester.enterText(find.byType(TextField), 'an');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await _assentar(tester);
      expect(
        t.chamadasDe('buscar'),
        0,
        reason: 'gastou chamada com termo abaixo do mínimo que o servidor publicou',
      );
    });

    testWidgets('a tela desenha SÓ as ações que a autoridade ofereceu', (
      tester,
    ) async {
      // Duas linhas, mesma tela: uma em que o servidor ofereceu "adicionar", e
      // outra em que ele NÃO ofereceu nada (o caso do bloqueio/sanção). Deduzir
      // pela relação daria botão às duas.
      t.respostaDaBusca = ResultadosDeBusca(
        termo: 'ana',
        itens: [
          resultadoFalso(
            'P1',
            apelido: 'Ana',
            relacao: RelacaoSocial.nenhuma,
            acoes: const [AcaoSocial.adicionarAmigo],
          ),
          resultadoFalso(
            'P2',
            apelido: 'Aninha',
            relacao: RelacaoSocial.indisponivel,
            acoes: const [],
          ),
        ],
        truncado: false,
        modo: ModoDeBusca.prefixo,
      );
      await montar(tester, const AmigosDeProducao());
      await tester.enterText(find.byType(TextField), 'ana');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await _assentar(tester);

      expect(find.text('Ana'), findsOneWidget);
      expect(find.text('Aninha'), findsOneWidget);
      expect(
        find.text('Adicionar'),
        findsOneWidget,
        reason: 'a linha sem ações do servidor também ganhou botão',
      );
      expect(find.text('Indisponível'), findsOneWidget);
    });

    testWidgets('adicionar reflete a vista NOVA da autoridade na mesma linha', (
      tester,
    ) async {
      t.respostaDaBusca = ResultadosDeBusca(
        termo: 'ana',
        itens: [
          resultadoFalso(
            'P1',
            apelido: 'Ana',
            relacao: RelacaoSocial.nenhuma,
            acoes: const [AcaoSocial.adicionarAmigo],
          ),
        ],
        truncado: false,
        modo: ModoDeBusca.prefixo,
      );
      t.perfis['P1'] = resultadoFalso(
        'P1',
        apelido: 'Ana',
        relacao: RelacaoSocial.solicitacaoEnviada,
        acoes: const [AcaoSocial.cancelarSolicitacao],
      );
      await montar(tester, const AmigosDeProducao());
      await tester.enterText(find.byType(TextField), 'ana');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await _assentar(tester);

      await tester.tap(find.text('Adicionar'));
      await _assentar(tester);

      expect(find.text('Pedido enviado'), findsOneWidget);
      expect(find.text('Cancelar'), findsOneWidget);
      expect(find.text('Adicionar'), findsNothing);
      // A ação chegou ao transporte com o publicId — nunca com a posição.
      final acao = t.chamadas.lastWhere((c) => c.metodo == 'agir');
      expect(acao.publicId, 'P1');
      expect(acao.acao, AcaoSocial.adicionarAmigo);
    });

    testWidgets('busca truncada convida a refinar, e não oferece "mais"', (
      tester,
    ) async {
      t.respostaDaBusca = ResultadosDeBusca(
        termo: 'an',
        itens: [resultadoFalso('P1', apelido: 'Ana')],
        truncado: true,
        modo: ModoDeBusca.prefixo,
      );
      await montar(tester, const AmigosDeProducao());
      await tester.enterText(find.byType(TextField), 'ana');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await _assentar(tester);

      expect(textoDaTela(tester), contains('apelido completo'));
      expect(
        find.text('Carregar mais'),
        findsNothing,
        reason: 'a busca não tem cursor, e oferecer "mais" prometeria uma '
            'paginação que o contrato não tem',
      );
    });

    testWidgets('recusa de termo curto vira recado sobre o TEXTO', (tester) async {
      await montar(tester, const AmigosDeProducao());
      // DEPOIS de montar:  vale para UMA chamada, e a carga da
      // lista de amigos que a abertura dispara a consumiria antes da busca.
      t.proximaFalha = const FalhaSocial(
        MotivoFalhaSocial.pedidoInvalido,
        'consultaMuitoCurta',
      );
      await tester.enterText(find.byType(TextField), 'ana');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await _assentar(tester);

      expect(textoDaTela(tester), contains('Escreva um pouco mais'));
      expect(
        find.text('Tentar de novo'),
        findsNothing,
        reason: 'ofereceu insistir num termo que sempre será recusado',
      );
    });
  });

  // =========================================================================
  // Navegação ao Perfil
  // =========================================================================
  group('navegação — o publicId, e nunca a posição', () {
    testWidgets('tocar num amigo abre o Perfil daquele publicId', (tester) async {
      t.respostaAmigos = paginaFalsa([
        jogadorFalso('P1', apelido: 'Bia'),
        jogadorFalso('P2', apelido: 'Caio'),
      ]);
      await montar(tester, const AmigosDeProducao());

      // O SEGUNDO da lista, de propósito: se a navegação usasse índice ou o
      // primeiro item, este caso passaria com o perfil errado.
      await tester.tap(find.text('Caio'));
      await _assentar(tester);

      final pagina = tester.widget<PerfilPage>(find.byType(PerfilPage));
      expect(pagina.publicIdVisitado, 'P2');
      expect(pagina.ehMeuPerfil, isFalse);
    });

    testWidgets('um resultado que É você abre o perfil do DONO', (tester) async {
      // `souEu` vem da autoridade (relação `euMesmo`), e não de comparar o
      // publicId local — que no intervalo de troca de sessão já é o da conta
      // nova enquanto a lista ainda é da antiga.
      t.respostaDaBusca = ResultadosDeBusca(
        termo: 'ana',
        itens: [
          resultadoFalso(
            'P0EUMESMO0001',
            apelido: 'Ana',
            relacao: RelacaoSocial.euMesmo,
            acoes: const [AcaoSocial.editarPerfil],
          ),
        ],
        truncado: false,
        modo: ModoDeBusca.prefixo,
      );
      await montar(tester, const AmigosDeProducao());
      await tester.enterText(find.byType(TextField), 'ana');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await _assentar(tester);

      await tester.tap(find.text('Ana'));
      await _assentar(tester);

      final pagina = tester.widget<PerfilPage>(find.byType(PerfilPage));
      expect(pagina.ehMeuPerfil, isTrue);
      expect(
        pagina.publicIdVisitado,
        isNull,
        reason: 'o próprio jogador foi consultado pela porta de terceiro',
      );
    });
  });

  // =========================================================================
  // A faixa do Perfil visitado
  // =========================================================================
  group('Perfil visitado — a relação vem do social, e volta depois da ação', () {
    testWidgets('a faixa mostra o rótulo e os botões da autoridade', (
      tester,
    ) async {
      t.perfis['P2'] = resultadoFalso(
        'P2',
        apelido: 'Caio',
        relacao: RelacaoSocial.amigos,
        acoes: const [AcaoSocial.removerAmigo, AcaoSocial.bloquear],
      );
      await montar(tester, const PerfilPage(publicIdVisitado: 'P2'));

      expect(find.text('Amigos'), findsOneWidget);
      expect(find.text('Remover'), findsOneWidget);
      // `bloquear` é do codebase de MODERAÇÃO; o social só reage a ele por
      // gatilho, e um botão sem porta seria promessa não cumprida.
      expect(find.text('Bloquear'), findsNothing);
      expect(t.chamadasDe('verPerfil'), 1);
    });

    testWidgets('o perfil do DONO não tem faixa social nem consulta relação', (
      tester,
    ) async {
      await montar(tester, const PerfilPage());
      expect(
        t.chamadasDe('verPerfil'),
        0,
        reason: 'o dono foi consultado pela porta de terceiro',
      );
      expect(find.text('Adicionar'), findsNothing);
      expect(find.text('Remover'), findsNothing);
    });

    testWidgets('remover reflete a relação nova, vinda da autoridade', (
      tester,
    ) async {
      t.perfis['P2'] = resultadoFalso(
        'P2',
        apelido: 'Caio',
        relacao: RelacaoSocial.amigos,
        acoes: const [AcaoSocial.removerAmigo],
      );
      await montar(tester, const PerfilPage(publicIdVisitado: 'P2'));
      expect(find.text('Remover'), findsOneWidget);

      // Depois da ação, a autoridade passa a dizer outra coisa.
      t.perfis['P2'] = resultadoFalso(
        'P2',
        apelido: 'Caio',
        relacao: RelacaoSocial.nenhuma,
        acoes: const [AcaoSocial.adicionarAmigo],
      );
      await tester.tap(find.text('Remover'));
      await _assentar(tester);

      expect(find.text('Adicionar'), findsOneWidget);
      expect(find.text('Remover'), findsNothing);
      expect(find.text('Amigos'), findsNothing);
    });

    testWidgets('social fora do ar NÃO derruba o Perfil — só tira a faixa', (
      tester,
    ) async {
      t.falhaFixa = const FalhaSocial(MotivoFalhaSocial.indisponivel);
      await montar(tester, const PerfilPage(publicIdVisitado: 'P2'));

      // A tela existe, e não há faixa afirmando relação nenhuma.
      expect(find.byType(PerfilPage), findsOneWidget);
      expect(find.text('Adicionar'), findsNothing);
      expect(find.text('Amigos'), findsNothing);
    });

    testWidgets('relação sem rótulo E sem ação não desenha faixa', (tester) async {
      // O caso de quem não pode interagir por motivo que o contrato esconde.
      // Uma faixa vazia com moldura seria, ela mesma, a informação de que há
      // algo do outro lado.
      t.perfis['P2'] = resultadoFalso(
        'P2',
        apelido: 'Caio',
        relacao: RelacaoSocial.nenhuma,
        acoes: const [],
      );
      await montar(tester, const PerfilPage(publicIdVisitado: 'P2'));
      expect(find.text('Adicionar'), findsNothing);
      expect(find.text('Indisponível'), findsNothing);
    });
  });
}
