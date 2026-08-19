// telas_consomem_identidade_test.dart — os casos que precisam de tela.
//
// Cobre B (Ranking direto), C (Social direto), D (Perfil direto), a metade
// visual de E (ordem independente) e O (Ranking não cria identidade).
//
// A PROVA CENTRAL DE TODOS ELES É A MESMA CONTAGEM: a `FonteEspia` conta quantas
// vezes `obterMinhaIdentidade` saiu, e a sessão só a chama no login. Se uma tela
// criasse, garantisse ou inicializasse identidade, esse número subiria ao abri-la
// — e sobe zero.
//
// ---------------------------------------------------------------------------
// POR QUE O RANKING AQUI É A `RankingPage`, E NÃO UMA RÉPLICA
// ---------------------------------------------------------------------------
//
// Este arquivo hospedava um `RankingHostDeTeste`: um widget de teste que repetia
// à mão o consumo que o `main.dart` fazia do Ranking — ler `EscopoSessao`,
// mapear `FaseIdentidade` para `RankingEstado`, e alimentar a tela com um
// `RankingVM.mock()`.
//
// As duas metades desse host morreram, e por motivos opostos:
//
//   1. `RankingVM.mock()` foi RETIRADA de propósito de `ranking_screen.dart`
//      (o comentário que registra a remoção continua lá): ela era a única
//      origem dos dados da tela e viajava dentro do APK. Ressuscitá-la para o
//      teste compilar seria desfazer a entrega — dado de exemplo não volta ao
//      `lib/`.
//
//   2. O mapeamento `FaseIdentidade → RankingEstado` deixou de existir em
//      produção. Quem hospeda o Ranking hoje é a `RankingPage`, e o estado da
//      tela vem da `RankingFase` do paginador — da fonte de ranking, não da
//      identidade. Reescrever a réplica com esse mapeamento seria fiscalizar um
//      consumo que nenhum arquivo do `lib/` faz.
//
// A reconstrução, então, é NÃO ter réplica: os casos montam a `RankingPage` de
// produção. O host de teste existia para não tornar público um detalhe privado
// do `main.dart` (`_RankingPreviewHostState`); o detalhe virou uma página
// pública, e o motivo caiu junto. Com isso a contagem passa a ser medida contra
// o código que roda de verdade, e a divergência réplica-original que o
// `auditoria_identidade_test.dart` vigiava fica impossível por construção.
//
// O que a `RankingPage` aceita é a FONTE (`RankingPage(service: ...)`) — a mesma
// costura que a documentação dela aponta para ligar o ranking oficial quando ele
// existir. Injetar aqui uma fonte que nunca responde não é maquete: não devolve
// jogador nenhum, não entra no APK e não é alcançável pelo produto.
//
// SUPERFÍCIE DE TELEFONE: o padrão do `flutter_test` é 800x600, que é paisagem
// de desktop e faz telas desenhadas para celular estourarem em overflow. As
// telas aqui são de celular.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:buraco_master_vip/pages/perfil_page.dart';
import 'package:buraco_master_vip/pages/ranking_page.dart';
import 'package:buraco_master_vip/ranking/ranking_contract.dart';
import 'package:buraco_master_vip/screens/amigos_screen.dart';
import 'package:buraco_master_vip/screens/perfil_screen.dart';
import 'package:buraco_master_vip/screens/ranking_screen.dart';
import 'package:buraco_master_vip/services/ranking_service.dart';
import 'package:buraco_master_vip/sessao/escopo_sessao.dart';
import 'package:buraco_master_vip/sessao/fonte_identidade.dart';
import 'package:buraco_master_vip/sessao/identidade_publica_sessao.dart';
import 'package:buraco_master_vip/sessao/sessao_do_jogador.dart';

const String kPublicIdDeTeste = 'P0A1B2C3D4E5';

/// Conta as chamadas e responde na hora. É a testemunha de §18-O.
class FonteEspia implements FonteDeIdentidade {
  FonteEspia({this.publicId = kPublicIdDeTeste, this.apelido = 'Sônia'});

  final String publicId;
  final String apelido;
  int chamadas = 0;

  @override
  Future<IdentidadePublica> obterMinhaIdentidade() async {
    chamadas++;
    return IdentidadePublica(
      publicId: publicId,
      apelido: apelido,
      avatarRef: null,
      criada: false,
      estado: EstadoPerfil.ativo,
      limites: LimitesSociais.desconhecidos,
      edicao: MetadadosDeEdicao.desconhecidos,
    );
  }
}

/// Réplica fiel do consumo que `main.dart` faz na tela de Amigos/Descoberta.
///
/// Aqui a réplica CONTINUA valendo: o Amigos ainda é hospedado por um `State`
/// privado do `main.dart`, e o que ele faz com a identidade — `publicId ?? '—'`
/// — é exatamente o que este host repete. A auditoria estrutural
/// (`auditoria_identidade_test.dart`) é quem garante que o original não divirja.
class SocialHostDeTeste extends StatelessWidget {
  const SocialHostDeTeste({super.key});

  @override
  Widget build(BuildContext context) {
    final meuCodigo = EscopoSessao.identidadeDe(context).publicId ?? '—';
    return AmigosScreen(
      vm: AmigosVM.mock(ehVip: true).copyWith(meuCodigo: meuCodigo),
      onVoltar: () {},
      onCopiarCodigo: () {},
      onConvidarLink: () {},
      onBuscar: (_) {},
      onEnviarPedido: (_) {},
      onResponderPedido: (_, __) {},
      onTrocarAba: (_) {},
      onConvidar: (_) {},
      onAssistir: (_) {},
      onAbrirAmigo: (_) {},
      onRecarregar: () {},
      onAssinar: (_) {},
    );
  }
}

void main() {
  late FonteEspia fonte;
  late StreamController<String?> auth;
  late SessaoDoJogador sessao;

  setUp(() {
    fonte = FonteEspia();
    auth = StreamController<String?>.broadcast();
  });

  tearDown(() => auth.close());

  /// Abre a sessão DENTRO do corpo do teste, e não no `setUp`.
  ///
  /// Não é preciosismo: `testWidgets` roda o corpo do teste num zone de tempo
  /// falso, e `setUp` roda fora dele. Uma assinatura de stream registrada no
  /// `setUp` entrega seus eventos no zone de fora, que o relógio do `pump`
  /// jamais adianta — a sessão simplesmente nunca receberia o login. Assinar
  /// aqui põe o stream e o relógio do teste no mesmo mundo.
  void abrirSessao({String? uidInicial}) {
    sessao = SessaoDoJogador(
      fonte: fonte,
      uids: auth.stream,
      uidInicial: uidInicial,
    );
    addTearDown(sessao.dispose);
  }

  /// Monta a árvore com o escopo da sessão, numa superfície de telefone.
  Future<void> montar(WidgetTester tester, Widget tela) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      EscopoSessao(
        sessao: sessao,
        child: MaterialApp(home: tela),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// "login" — a sessão resolve a identidade ANTES de qualquer tela abrir.
  ///
  /// O `pumpWidget` vazio dá à ligação um relógio para girar sem construir tela
  /// nenhuma; é o que torna a afirmação forte, porque a identidade fica pronta
  /// com a árvore literalmente vazia. Os dois `pump` drenam a entrega do evento
  /// de autenticação e a resposta da fonte.
  Future<void> login(WidgetTester tester, [String uid = 'uid-A']) async {
    abrirSessao();
    await tester.pumpWidget(const SizedBox.shrink());
    auth.add(uid);
    await tester.pump();
    await tester.pump();
  }

  // =========================================================================
  // CASO B — Ranking direto
  // =========================================================================
  group('CASO B — login → Ranking', () {
    testWidgets('o Ranking abre sem tocar na identidade canônica', (
      tester,
    ) async {
      await login(tester);
      expect(sessao.publicId, kPublicIdDeTeste);
      final antes = fonte.chamadas;

      await montar(tester, const RankingPage());

      expect(find.byType(RankingScreen), findsOneWidget);
      // Abrir o Ranking NÃO produziu chamada nenhuma.
      expect(fonte.chamadas, antes);
      // E a identidade que já estava resolvida continua a mesma: o Ranking não
      // a substitui, não a recarrega e não a invalida.
      expect(sessao.publicId, kPublicIdDeTeste);
      expect(sessao.estado.fase, FaseIdentidade.disponivel);
    });

    testWidgets('o Ranking obedece à fase da PRÓPRIA fonte, não à da sessão', (
      tester,
    ) async {
      // Com a identidade RESOLVIDA e o ranking em voo, a tela mostra
      // carregando — ou seja, o estado dela vem do paginador. É este teste que
      // impede a volta do acoplamento antigo, em que a fase da IDENTIDADE
      // decidia o que o Ranking desenhava.
      await login(tester);
      expect(sessao.estado.fase, FaseIdentidade.disponivel);

      await montar(
        tester,
        const RankingPage(service: _RankingQueNuncaResponde()),
      );

      final tela = tester.widget<RankingScreen>(find.byType(RankingScreen));
      expect(tela.estado, RankingEstado.carregando);
      expect(fonte.chamadas, 1, reason: 'só o login chamou');
    });

    testWidgets('sem identidade resolvida o Ranking ainda abre, e não a cunha', (
      tester,
    ) async {
      // O contrapeso: identidade em voo (fonte que nunca responde) e ranking
      // idem. A tela obedece à fase do ranking, e a sessão não ganha um
      // publicId inventado pelo caminho.
      final lenta = _FonteQueNuncaResponde();
      final sessaoLenta = SessaoDoJogador(
        fonte: lenta,
        uids: auth.stream,
        uidInicial: 'uid-A',
      );
      addTearDown(sessaoLenta.dispose);

      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        EscopoSessao(
          sessao: sessaoLenta,
          child: const MaterialApp(
            home: RankingPage(service: _RankingQueNuncaResponde()),
          ),
        ),
      );
      await tester.pump();

      expect(sessaoLenta.estado.fase, FaseIdentidade.carregando);
      final tela = tester.widget<RankingScreen>(find.byType(RankingScreen));
      expect(tela.estado, RankingEstado.carregando);
      expect(sessaoLenta.publicId, isNull);
    });
  });

  // =========================================================================
  // REGRESSÃO — a maquete não volta ao caminho de produção
  // =========================================================================
  group('o Ranking de produção não desenha jogador inventado', () {
    testWidgets('a fonte embarcada por padrão não entrega jogador nenhum', (
      tester,
    ) async {
      // A prova de que `RankingVM.mock()` não voltou por outro nome: montada
      // como o `main.dart` a monta — `const RankingPage()`, sem argumento —, a
      // página cai na [RankingSemFonte] e o view-model que chega à tela está
      // literalmente vazio. Nenhum pódio de exemplo, nenhuma divisão fictícia,
      // nenhuma temporada com prazo inventado dentro do APK.
      //
      // A afirmação é COMPORTAMENTAL de propósito: um teste que procurasse a
      // string `RankingVM.mock` no `lib/` casaria com o comentário que registra
      // a remoção dela, e passaria a vigiar prosa em vez de código.
      await login(tester);
      await montar(tester, const RankingPage());

      final tela = tester.widget<RankingScreen>(find.byType(RankingScreen));
      expect(tela.estado, RankingEstado.erro);
      expect(tela.mensagemErro, RankingSemFonte.motivo);
      expect(tela.vm.podio, isEmpty);
      expect(tela.vm.lista, isEmpty);
      expect(tela.vm.escadaLigas, isEmpty);
      expect(tela.vm.divisao, isNull);
      expect(tela.vm.faixaTempo, isEmpty);
    });
  });

  // =========================================================================
  // CASO C — Social direto, SEM passar pelo Ranking
  // =========================================================================
  group('CASO C — login → Social', () {
    testWidgets('a descoberta tem o publicId canônico sem abrir Ranking', (
      tester,
    ) async {
      await login(tester);
      final antes = fonte.chamadas;

      await montar(tester, const SocialHostDeTeste());

      expect(find.byType(AmigosScreen), findsOneWidget);
      final tela = tester.widget<AmigosScreen>(find.byType(AmigosScreen));
      // O "meu código" da tela É o publicId do servidor.
      expect(tela.vm.meuCodigo, kPublicIdDeTeste);
      expect(
        fonte.chamadas,
        antes,
        reason: 'nenhuma tela do Ranking foi construída, e nada foi pedido',
      );
    });

    testWidgets('sem identidade resolvida, o código não vira uid nem some', (
      tester,
    ) async {
      // Sessão nunca autenticada.
      abrirSessao();
      await montar(tester, const SocialHostDeTeste());
      final tela = tester.widget<AmigosScreen>(find.byType(AmigosScreen));
      expect(tela.vm.meuCodigo, '—');
      expect(tela.vm.meuCodigo, isNot('uid-A'));
    });
  });

  // =========================================================================
  // CASO D — Perfil direto, SEM passar pelo Ranking
  // =========================================================================
  group('CASO D — login → Perfil', () {
    testWidgets('Perfil consome o apelido da identidade canônica', (
      tester,
    ) async {
      await login(tester);
      final antes = fonte.chamadas;

      await montar(tester, const PerfilPage());
      await tester.pumpAndSettle(const Duration(milliseconds: 500));

      expect(find.byType(PerfilScreen), findsOneWidget);
      final tela = tester.widget<PerfilScreen>(find.byType(PerfilScreen));
      // O nome vem de `publicProfiles`, a autoridade — não do displayName.
      expect(tela.vm.nome, 'Sônia');
      expect(fonte.chamadas, antes, reason: 'Perfil não pede identidade');
    });

    testWidgets('abrir e fechar o Perfil várias vezes não consulta nada', (
      tester,
    ) async {
      await login(tester);
      final antes = fonte.chamadas;

      for (var i = 0; i < 3; i++) {
        await montar(tester, const PerfilPage());
        await tester.pumpAndSettle(const Duration(milliseconds: 500));
        await tester.pumpWidget(const SizedBox.shrink());
      }

      expect(fonte.chamadas, antes);
    });
  });

  // =========================================================================
  // CASO E — ordem independente, agora pelas telas
  // =========================================================================
  group('CASO E — a ordem das telas não muda a identidade', () {
    testWidgets('Ranking→Social e Social→Ranking dão o mesmo publicId', (
      tester,
    ) async {
      await login(tester);

      // Ordem 1: Ranking, depois Social.
      await montar(tester, const RankingPage());
      await montar(tester, const SocialHostDeTeste());
      final ordem1 = tester
          .widget<AmigosScreen>(find.byType(AmigosScreen))
          .vm
          .meuCodigo;

      // Ordem 2: Social, depois Ranking, depois Social de novo.
      await montar(tester, const SocialHostDeTeste());
      await montar(tester, const RankingPage());
      await montar(tester, const SocialHostDeTeste());
      final ordem2 = tester
          .widget<AmigosScreen>(find.byType(AmigosScreen))
          .vm
          .meuCodigo;

      expect(ordem1, ordem2);
      expect(ordem1, kPublicIdDeTeste);
      expect(fonte.chamadas, 1, reason: 'uma chamada, a do login');
    });
  });

  // =========================================================================
  // CASO O — Ranking NÃO cria identidade
  // =========================================================================
  group('CASO O — abrir Ranking não cria nem garante identidade', () {
    testWidgets('abrir o Ranking dez vezes não emite nenhuma chamada', (
      tester,
    ) async {
      await login(tester);
      expect(fonte.chamadas, 1, reason: 'só o login chamou');

      for (var i = 0; i < 10; i++) {
        await montar(tester, const RankingPage());
      }

      expect(fonte.chamadas, 1);
      expect(sessao.chamadasEmitidas, 1);
    });

    testWidgets('o Ranking reconstruído em rajada não vira tempestade', (
      tester,
    ) async {
      await login(tester);
      await montar(tester, const RankingPage());

      // 60 frames — um segundo de reconstrução contínua.
      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }

      expect(fonte.chamadas, 1, reason: 'build não consulta a Function');
    });

    testWidgets('o Ranking aberto SEM sessão autenticada não cria identidade', (
      tester,
    ) async {
      // O cenário que a arquitetura antiga usava para cunhar id: entrar no
      // Ranking. Aqui não nasce nada.
      abrirSessao();
      await montar(tester, const RankingPage());
      await tester.pumpAndSettle();

      expect(fonte.chamadas, 0);
      expect(sessao.publicId, isNull);
      expect(sessao.estado.fase, FaseIdentidade.naoAutenticado);
    });
  });
}

class _FonteQueNuncaResponde implements FonteDeIdentidade {
  @override
  Future<IdentidadePublica> obterMinhaIdentidade() =>
      Completer<IdentidadePublica>().future;
}

/// Fonte de ranking que fica em voo para sempre — deixa a tela em `carregando`.
///
/// Não é maquete: não publica jogador, divisão, liga nem posição. Entra pela
/// mesma porta por onde a fonte oficial entrará (`RankingPage(service: ...)`),
/// e o padrão de produção continua sendo a [RankingSemFonte].
class _RankingQueNuncaResponde extends RankingService {
  const _RankingQueNuncaResponde();

  @override
  Future<RankingAbertura> abrir(RankingEscopo escopo) =>
      Completer<RankingAbertura>().future;

  @override
  Future<RankingPagina> proximaPagina(RankingEscopo escopo, String cursor) =>
      Completer<RankingPagina>().future;
}
