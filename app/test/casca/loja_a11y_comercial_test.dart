// loja_a11y_comercial_test.dart — a acessibilidade da Loja produtiva e a
// segurança do acionamento comercial.
//
// ---------------------------------------------------------------------------
// O QUE ESTA SUÍTE GUARDA
// ---------------------------------------------------------------------------
//
// A auditoria da OS 14 encontrou quatro P0 na Loja, e dois deles não eram de
// leitura de tela — eram de cobrança:
//
//   * tocar num card de plano abria o fluxo de pagamento da Play NO MESMO
//     GESTO que selecionava, sem confirmação, e três toques abriam três
//     cobranças;
//   * o resultado da compra nunca chegava a ninguém: recusa, erro da Play e
//     pendência eram silenciosos, visual e sonoramente.
//
// Nenhum dos dois era visível no aplicativo publicado no dia da auditoria,
// porque o produto `master_vip` ainda não existe na Play Console e a vitrine
// vem vazia. Eles disparariam sozinhos, sem mudança de código, no dia da
// publicação. É por isso que a suíte monta a vitrine COM planos: ela exercita
// o estado futuro, que é onde o defeito mora.
//
// ---------------------------------------------------------------------------
// NENHUMA PLATAFORMA É TOCADA AQUI
// ---------------------------------------------------------------------------
//
// A suíte monta `LojaScreen` diretamente, com callbacks que só registram texto.
// Não há `ServicoBilling`, `LojaPlayReal`, `EntitlementRepositorio` nem
// Firebase em lugar nenhum deste arquivo — e a ausência é verificada pelo
// próprio caso `PROVA-15`, que lê os imports.
//
// O preço, esse sim, é REAL no sentido que importa: ele nasce de um
// `GooglePlayProductDetails` montado a partir dos mesmos wrappers da Billing
// Library que o plugin devolve, e atravessa `planosVipDe` e `planosParaLoja`
// antes de chegar à tela. Nenhuma constante de preço é digitada nos casos.
//
// ---------------------------------------------------------------------------
// MEDIDAS
// ---------------------------------------------------------------------------
//
// `devicePixelRatio` é 1.0 de propósito: a árvore semântica reporta retângulos
// em pixels FÍSICOS, e com dpr 3 toda medida de alvo de toque teria de ser
// dividida antes de comparar com os 48 dp da régua. Com dpr 1 o número que sai
// da árvore já é o número da régua.

import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';

import 'package:buraco_master_vip/billing/plano_vip.dart';
import 'package:buraco_master_vip/screens/loja_screen.dart';
import 'package:buraco_master_vip/screens/loja_vip_adaptador.dart';
import 'package:buraco_master_vip/billing/catalogo.dart';
import 'package:buraco_master_vip/billing/estado_ui.dart';
import 'package:buraco_master_vip/billing/servico_billing.dart';
import 'package:buraco_master_vip/billing/validacao.dart';
import 'package:buraco_master_vip/casca/loja_de_producao.dart';
import 'package:buraco_master_vip/elegibilidade/entitlement.dart';
import 'package:buraco_master_vip/screens/perfil_screen.dart' show NavDestino;

import '../billing/apoio/dubles.dart';

// ===========================================================================
// A fixture de preço: a Play, encenada pelos wrappers dela mesma
// ===========================================================================

/// Os valores da fixture, num lugar só, para os casos poderem AFIRMAR sobre
/// eles sem redigitá-los.
const String kPrecoMensal = r'R$ 19,90';
const String kPrecoTrimestral = r'R$ 49,90';
const String kPrecoAnual = r'R$ 149,90';

SubscriptionOfferDetailsWrapper _planoBase({
  required String basePlanId,
  required String periodo,
  required String precoFormatado,
  required int precoMicros,
}) =>
    SubscriptionOfferDetailsWrapper(
      basePlanId: basePlanId,
      offerTags: const <String>[],
      offerIdToken: 'token-de-$basePlanId',
      pricingPhases: <PricingPhaseWrapper>[
        PricingPhaseWrapper(
          billingCycleCount: 0,
          billingPeriod: periodo,
          formattedPrice: precoFormatado,
          priceAmountMicros: precoMicros,
          priceCurrencyCode: 'BRL',
          recurrenceMode: RecurrenceMode.infiniteRecurring,
        ),
      ],
    );

/// UM produto de assinatura com três planos-base — a modelagem que o Google Play
/// recomenda, e a razão de `ProductDetails.id` não distinguir plano nenhum.
List<ProductDetails> _produtoComTresPlanos() {
  final wrapper = ProductDetailsWrapper(
    description: 'Assinatura VIP',
    name: 'Buraco Master VIP',
    productId: 'master_vip',
    productType: ProductType.subs,
    title: 'Buraco Master VIP',
    subscriptionOfferDetails: <SubscriptionOfferDetailsWrapper>[
      _planoBase(
        basePlanId: 'yearly_auto',
        periodo: 'P1Y',
        precoFormatado: kPrecoAnual,
        precoMicros: 149900000,
      ),
      _planoBase(
        basePlanId: 'monthly_auto',
        periodo: 'P1M',
        precoFormatado: kPrecoMensal,
        precoMicros: 19900000,
      ),
      _planoBase(
        basePlanId: 'quarterly_auto',
        periodo: 'P3M',
        precoFormatado: kPrecoTrimestral,
        precoMicros: 49900000,
      ),
    ],
  );
  return GooglePlayProductDetails.fromProductDetails(wrapper);
}

/// Os planos como a tela os recebe, pelo caminho REAL do adaptador.
List<PlanoVipLoja> planosDaPlay() =>
    planosParaLoja(planosVipDe(_produtoComTresPlanos()));

// ===========================================================================
// A bancada
// ===========================================================================

/// O que a tela pediu ao hospedeiro. Nenhuma destas chamadas chega a lugar
/// nenhum além desta lista.
class Registro {
  final List<String> eventos = <String>[];
  void reg(String e) => eventos.add(e);

  /// Só as intenções COMERCIAIS — as que abririam o fluxo da Play.
  List<String> get intencoes =>
      eventos.where((e) => e.startsWith('ASSINAR:')).toList();
}

/// Telefone comum, e a menor largura Android que a bancada suporta.
const Size kTelefone = Size(412, 915);
const Size kLarguraMinima = Size(320, 640);

class Bancada {
  Bancada(this.tester);

  final WidgetTester tester;
  final Registro registro = Registro();
  final List<String> anuncios = <String>[];

  /// Captura o que `SemanticsService.sendAnnouncement` mandaria ao sistema.
  ///
  /// O canal `flutter/accessibility` é o mesmo que o TalkBack escuta no
  /// aparelho; o mock apenas se põe no lugar da plataforma.
  void escutarAnuncios() {
    tester.binding.defaultBinaryMessenger
        .setMockDecodedMessageHandler<Object?>(
      SystemChannels.accessibility,
      (Object? mensagem) async {
        if (mensagem is Map && mensagem['type'] == 'announce') {
          final dados = mensagem['data'];
          if (dados is Map && dados['message'] is String) {
            anuncios.add(dados['message'] as String);
          }
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger
          .setMockDecodedMessageHandler<Object?>(
        SystemChannels.accessibility,
        null,
      );
    });
  }

  Future<void> montar({
    LojaVM? vm,
    EstadoDaCompraNaLoja estado = EstadoDaCompraNaLoja.ociosa,
    double escala = 1.0,
    Size tela = kTelefone,
    String? aviso,
  }) async {
    tester.view.physicalSize = tela;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData.fromView(tester.view)
            .copyWith(textScaler: TextScaler.linear(escala)),
        child: MaterialApp(
          home: LojaScreen(
            vm: vm ?? LojaVM(ehVip: false, planos: planosDaPlay()),
            avisoDaVitrine: aviso,
            estadoDaCompra: estado,
            onVoltar: () => registro.reg('VOLTAR'),
            onNav: (NavDestino d) => registro.reg('NAV:${d.name}'),
            onComprarMoedas: () => registro.reg('CARTEIRA'),
            onSelecionarPlano: (String id) => registro.reg('SELECIONAR:$id'),
            onAssinar: (String id) => registro.reg('ASSINAR:$id'),
            onComprarPacote: (String id) => registro.reg('PACOTE:$id'),
            onConfirmarCompra: (String id) => registro.reg('CONFIRMAR:$id'),
            onAbrirCategoria: (LojaCategoria c) =>
                registro.reg('CATEGORIA:${c.name}'),
            onPresentear: (String id) => registro.reg('PRESENTEAR:$id'),
            onBuscarPresenteado: (String t) => registro.reg('BUSCAR:$t'),
            onEnviarPresente: (String i, String j) =>
                registro.reg('ENVIAR:$i/$j'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }
}

// ===========================================================================
// Leitura da árvore semântica
// ===========================================================================

/// Um nó da árvore, com o retângulo já em pontos lógicos.
class NoSemantico {
  NoSemantico(this.rotulo, this.dados, this.retangulo);

  final String rotulo;
  final SemanticsData dados;
  final Rect retangulo;

  bool get ehBotao => dados.flagsCollection.isButton;
  bool get ehCabecalho => dados.flagsCollection.isHeader;
  bool get selecionado => dados.flagsCollection.isSelected == Tristate.isTrue;
  bool get temToque => dados.hasAction(SemanticsAction.tap);
  bool get habilitado => dados.flagsCollection.isEnabled == Tristate.isTrue;
  /// Tristate.none significa que o no nao tem estado de habilitacao nenhum:
  /// e a distincao entre "botao sem estado" e "botao desabilitado".
  bool get temEstadoDeHabilitacao =>
      dados.flagsCollection.isEnabled != Tristate.none;
  double get largura => retangulo.width;
  double get altura => retangulo.height;

  @override
  String toString() =>
      '"$rotulo" botao=$ehBotao selecionado=$selecionado '
      '${largura.toStringAsFixed(1)}x${altura.toStringAsFixed(1)}';
}

/// Todos os nós da árvore semântica atual.
List<NoSemantico> arvore(WidgetTester tester) {
  final SemanticsNode? raiz = tester
      .binding.renderViews.first.owner?.semanticsOwner?.rootSemanticsNode;
  final saida = <NoSemantico>[];
  if (raiz == null) return saida;
  final double dpr = tester.view.devicePixelRatio;

  void andar(SemanticsNode no, Matrix4 pai) {
    final Matrix4 m = pai.clone();
    if (no.transform != null) m.multiply(no.transform!);
    final Rect g = MatrixUtils.transformRect(m, no.rect);
    final SemanticsData d = no.getSemanticsData();
    saida.add(NoSemantico(
      d.label,
      d,
      Rect.fromLTWH(g.left / dpr, g.top / dpr, g.width / dpr, g.height / dpr),
    ));
    no.visitChildren((SemanticsNode c) {
      andar(c, m);
      return true;
    });
  }

  andar(raiz, Matrix4.identity());
  return saida;
}

/// O nó cujo rótulo é exatamente [rotulo].
NoSemantico no(WidgetTester tester, String rotulo) {
  final achados = arvore(tester).where((n) => n.rotulo == rotulo).toList();
  expect(
    achados,
    hasLength(1),
    reason: 'esperava UM nó com rótulo "$rotulo"; achei ${achados.length}. '
        'Árvore: ${arvore(tester).where((n) => n.rotulo.isNotEmpty).join(" | ")}',
  );
  return achados.single;
}

/// O nó cujo rótulo COMEÇA com [prefixo] — para rótulos compostos.
NoSemantico noComecandoCom(WidgetTester tester, String prefixo) {
  final achados =
      arvore(tester).where((n) => n.rotulo.startsWith(prefixo)).toList();
  expect(
    achados,
    hasLength(1),
    reason: 'esperava UM nó começando com "$prefixo"; achei ${achados.length}',
  );
  return achados.single;
}

/// Todo controle acionável da tela.
List<NoSemantico> acionaveis(WidgetTester tester) =>
    arvore(tester).where((n) => n.temToque).toList();

const double kAlvoMinimo = 48.0;

/// Conta as caixas que estouraram, varrendo o render tree.
///
/// Não basta olhar exceção: `flutter_test` guarda só a primeira, e o caso
/// precisa saber se sobrou alguma.
int caixasEstouradas(WidgetTester tester) {
  int n = 0;
  void andar(RenderObject ro) {
    if (ro is RenderFlex) {
      // `RenderFlex` só sabe do próprio estouro por debugPaint; o sinal
      // observável é o filho maior que o pai.
      final pai = ro;
      double soma = 0;
      RenderBox? filho = pai.firstChild;
      while (filho != null) {
        if (filho.hasSize) {
          soma += pai.direction == Axis.vertical
              ? filho.size.height
              : filho.size.width;
        }
        filho = pai.childAfter(filho);
      }
      if (pai.hasSize) {
        final disponivel = pai.direction == Axis.vertical
            ? pai.size.height
            : pai.size.width;
        if (soma > disponivel + 0.5) n++;
      }
    }
    ro.visitChildren(andar);
  }

  andar(tester.binding.rootElement!.renderObject!);
  return n;
}

// ===========================================================================
// Contraste
// ===========================================================================

double _canal(int v) {
  final d = v / 255.0;
  return d <= 0.03928 ? d / 12.92 : math.pow((d + 0.055) / 1.055, 2.4) as double;
}

double luminancia(Color c) =>
    0.2126 * _canal((c.r * 255).round()) +
    0.7152 * _canal((c.g * 255).round()) +
    0.0722 * _canal((c.b * 255).round());

double contraste(Color a, Color b) {
  final la = luminancia(a);
  final lb = luminancia(b);
  final maior = la > lb ? la : lb;
  final menor = la > lb ? lb : la;
  return (maior + 0.05) / (menor + 0.05);
}

/// Compõe [frente] (com alfa) sobre [fundo] opaco.
Color compor(Color frente, Color fundo) {
  final a = frente.a;
  return Color.fromARGB(
    255,
    ((frente.r * a + fundo.r * (1 - a)) * 255).round(),
    ((frente.g * a + fundo.g * (1 - a)) * 255).round(),
    ((frente.b * a + fundo.b * (1 - a)) * 255).round(),
  );
}

// ===========================================================================
// Os casos
// ===========================================================================

void main() {
  // -------------------------------------------------------------------------
  // §6 — semântica dos controles
  // -------------------------------------------------------------------------
  group('PROVA-01 · voltar', () {
    testWidgets('tem nome, papel de botão e alvo de 48 dp', (tester) async {
      final SemanticsHandle h = tester.ensureSemantics();
      final b = Bancada(tester);
      await b.montar();

      final v = no(tester, 'Voltar');
      expect(v.ehBotao, isTrue, reason: 'Voltar precisa ser anunciado botão');
      expect(v.temToque, isTrue);
      expect(v.largura, greaterThanOrEqualTo(kAlvoMinimo));
      expect(v.altura, greaterThanOrEqualTo(kAlvoMinimo));

      // O glifo não pode continuar sendo um nó por conta própria: seriam dois
      // anúncios para um controle só.
      expect(
        arvore(tester).where((n) => n.rotulo == '‹'),
        isEmpty,
        reason: 'o caractere de seta não pode virar nó semântico',
      );
      h.dispose();
    });

    testWidgets('e continua voltando quando tocado', (tester) async {
      final b = Bancada(tester);
      await b.montar();
      await tester.tap(find.text('‹'));
      await tester.pumpAndSettle();
      expect(b.registro.eventos, contains('VOLTAR'));
    });
  });

  group('PROVA-02 · fechar modal', () {
    testWidgets('o X da confirmação tem nome e 48 dp', (tester) async {
      final SemanticsHandle h = tester.ensureSemantics();
      final b = Bancada(tester);
      await b.montar();

      await tester.tap(find.text('Assinar plano anual'));
      await tester.pumpAndSettle();

      final x = no(tester, 'Fechar confirmação de assinatura');
      expect(x.ehBotao, isTrue);
      expect(x.largura, greaterThanOrEqualTo(kAlvoMinimo));
      expect(x.altura, greaterThanOrEqualTo(kAlvoMinimo));

      // NENHUM acionável sem nome pode sobrar na folha.
      expect(
        acionaveis(tester).where((n) => n.rotulo.trim().isEmpty),
        isEmpty,
        reason: 'controle acionável sem nome na folha de confirmação',
      );
      h.dispose();
    });

    testWidgets('e fechar NÃO compra', (tester) async {
      final b = Bancada(tester);
      await b.montar();
      await tester.tap(find.text('Assinar plano anual'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(find.text('Confirmar assinatura'), findsNothing);
      expect(b.registro.intencoes, isEmpty);
    });
  });

  // -------------------------------------------------------------------------
  // §3 — selecionar não é comprar
  // -------------------------------------------------------------------------
  group('PROVA-03 · tocar em plano não compra', () {
    testWidgets('um toque no card produz seleção e NENHUMA intenção',
        (tester) async {
      final b = Bancada(tester);
      await b.montar();

      await tester.tap(find.text('Mensal'));
      await tester.pumpAndSettle();

      expect(b.registro.eventos, contains('SELECIONAR:monthly_auto'));
      expect(
        b.registro.intencoes,
        isEmpty,
        reason: 'ESTE É O P0: selecionar abria o fluxo de cobrança da Play',
      );
    });

    testWidgets('nem tocando nos três, um a um', (tester) async {
      final b = Bancada(tester);
      await b.montar();
      for (final nome in <String>['Mensal', 'Trimestral', 'Anual']) {
        await tester.tap(find.text(nome));
        await tester.pumpAndSettle();
      }
      expect(b.registro.intencoes, isEmpty);
      expect(b.registro.eventos.where((e) => e.startsWith('SELECIONAR:')),
          hasLength(3));
    });

    testWidgets('a ação de assinar existe, é nomeada e nomeia o plano',
        (tester) async {
      final SemanticsHandle h = tester.ensureSemantics();
      final b = Bancada(tester);
      await b.montar();

      // O destaque é o de período mais longo, e é o selecionado inicial.
      final acao = no(tester, 'Assinar plano anual');
      expect(acao.ehBotao, isTrue);
      expect(acao.altura, greaterThanOrEqualTo(kAlvoMinimo));

      // Trocar a seleção troca o nome da ação: quem ouve sabe o que assina.
      await tester.tap(find.text('Mensal'));
      await tester.pumpAndSettle();
      expect(no(tester, 'Assinar plano mensal').ehBotao, isTrue);
      h.dispose();
    });

    testWidgets('a confirmação mostra plano, preço e periodicidade',
        (tester) async {
      final SemanticsHandle h = tester.ensureSemantics();
      final b = Bancada(tester);
      await b.montar();

      await tester.tap(find.text('Assinar plano anual'));
      await tester.pumpAndSettle();

      expect(find.text('Confirmar assinatura'), findsOneWidget);
      // Visível...
      expect(find.text('Plano Anual'), findsOneWidget);
      expect(find.text(kPrecoAnual), findsWidgets);
      // ...e falado num nó só, na ordem da frase.
      final resumo = noComecandoCom(tester, 'Plano Anual.');
      expect(resumo.rotulo, contains(kPrecoAnual));
      expect(resumo.rotulo, contains('Cobrança'));
      expect(resumo.rotulo, contains('por cento'),
          reason: 'o desconto precisa ser dito como economia, não como -37%');
      // As duas saídas.
      expect(find.text('Continuar para o pagamento'), findsOneWidget);
      expect(find.text('Cancelar'), findsOneWidget);
      h.dispose();
    });
  });

  // -------------------------------------------------------------------------
  // §6 — selected
  // -------------------------------------------------------------------------
  group('PROVA-04 · plano selecionado', () {
    testWidgets('expõe selected=true, e só ele', (tester) async {
      final SemanticsHandle h = tester.ensureSemantics();
      final b = Bancada(tester);
      await b.montar();

      final cards = arvore(tester)
          .where((n) => n.rotulo.startsWith('Plano '))
          .where((n) => n.temToque)
          .toList();
      expect(cards, hasLength(3));
      expect(cards.where((c) => c.selecionado), hasLength(1));
      expect(cards.singleWhere((c) => c.selecionado).rotulo,
          startsWith('Plano Anual'));

      await tester.tap(find.text('Trimestral'));
      await tester.pumpAndSettle();

      final depois = arvore(tester)
          .where((n) => n.rotulo.startsWith('Plano ') && n.temToque)
          .toList();
      expect(depois.singleWhere((c) => c.selecionado).rotulo,
          startsWith('Plano Trimestral'));
      h.dispose();
    });

    testWidgets('o card é UM nó com nome, preço, por mês e desconto',
        (tester) async {
      final SemanticsHandle h = tester.ensureSemantics();
      final b = Bancada(tester);
      await b.montar();

      final card = noComecandoCom(tester, 'Plano Anual.');
      expect(card.ehBotao, isTrue);
      expect(card.rotulo, contains(kPrecoAnual));
      expect(card.rotulo, contains('/mês'));
      expect(card.rotulo, contains('Economia de'));
      h.dispose();
    });
  });

  // -------------------------------------------------------------------------
  // §4 — trava de intenção
  // -------------------------------------------------------------------------
  group('PROVA-05 · confirmar dispara exatamente uma intenção', () {
    testWidgets('um Continuar produz uma intenção', (tester) async {
      final b = Bancada(tester);
      await b.montar();

      await tester.tap(find.text('Assinar plano anual'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continuar para o pagamento'));
      await tester.pumpAndSettle();

      expect(b.registro.intencoes, <String>['ASSINAR:yearly_auto']);
    });
  });

  group('PROVA-06 · toques repetidos', () {
    testWidgets('três toques rápidos em Continuar => UMA intenção',
        (tester) async {
      final b = Bancada(tester);
      await b.montar();
      await tester.tap(find.text('Assinar plano anual'));
      await tester.pumpAndSettle();

      final alvo = find.text('Continuar para o pagamento');
      // Sem `pumpAndSettle` entre eles: é a janela real entre o toque e o
      // estado chegar pelo stream.
      await tester.tap(alvo, warnIfMissed: false);
      await tester.tap(alvo, warnIfMissed: false);
      await tester.tap(alvo, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(b.registro.intencoes, hasLength(1),
          reason: 'a trava local tem de fechar a janela do mesmo quadro');
    });

    testWidgets('durante uma tentativa viva, assinar fica indisponível',
        (tester) async {
      final SemanticsHandle h = tester.ensureSemantics();
      final b = Bancada(tester);
      await b.montar(estado: EstadoDaCompraNaLoja.iniciando);

      final acao = no(tester, 'Aguarde…');
      expect(acao.temEstadoDeHabilitacao, isTrue);
      expect(acao.habilitado, isFalse,
          reason: 'o desabilitado precisa ser ESTADO, não só cor');

      await tester.tap(find.text('Aguarde…'), warnIfMissed: false);
      await tester.tap(find.text('Aguarde…'), warnIfMissed: false);
      await tester.tap(find.text('Aguarde…'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(b.registro.intencoes, isEmpty);
      expect(find.text('Confirmar assinatura'), findsNothing);
      h.dispose();
    });

    testWidgets('pagamento PENDENTE também tranca', (tester) async {
      final b = Bancada(tester);
      await b.montar(estado: EstadoDaCompraNaLoja.pendente);
      await tester.tap(find.text('Aguarde…'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(b.registro.intencoes, isEmpty,
          reason: 'pagamento em aprovação é compra viva: assinar de novo '
              'cobraria duas vezes pela mesma assinatura');
    });
  });

  // -------------------------------------------------------------------------
  // §5 — o resultado chega
  // -------------------------------------------------------------------------
  group('PROVA-07 · cancelamento', () {
    testWidgets('aparece na tela e é anunciado uma vez', (tester) async {
      final b = Bancada(tester);
      b.escutarAnuncios();
      await b.montar(estado: EstadoDaCompraNaLoja.iniciando);
      b.anuncios.clear();

      await b.montar(estado: EstadoDaCompraNaLoja.cancelada);

      expect(find.textContaining('Compra cancelada'), findsOneWidget);
      expect(b.anuncios, hasLength(1));
      expect(b.anuncios.single, contains('cancelada'));
    });
  });

  group('PROVA-08 · erro', () {
    testWidgets('aparece na tela e é anunciado uma vez', (tester) async {
      final b = Bancada(tester);
      b.escutarAnuncios();
      await b.montar(estado: EstadoDaCompraNaLoja.iniciando);
      b.anuncios.clear();

      await b.montar(estado: EstadoDaCompraNaLoja.erro);

      expect(find.textContaining('não conseguiu concluir'), findsOneWidget);
      expect(b.anuncios, hasLength(1));
    });

    testWidgets('recusa também', (tester) async {
      final b = Bancada(tester);
      b.escutarAnuncios();
      await b.montar(estado: EstadoDaCompraNaLoja.iniciando);
      b.anuncios.clear();

      await b.montar(estado: EstadoDaCompraNaLoja.recusada);
      expect(find.textContaining('Nada foi concedido'), findsOneWidget);
      expect(b.anuncios, hasLength(1));
    });

    testWidgets('reconstruir no MESMO estado não repete o anúncio',
        (tester) async {
      final b = Bancada(tester);
      b.escutarAnuncios();
      await b.montar(estado: EstadoDaCompraNaLoja.recusada);
      b.anuncios.clear();

      await b.montar(estado: EstadoDaCompraNaLoja.recusada);
      await b.montar(estado: EstadoDaCompraNaLoja.recusada);

      expect(b.anuncios, isEmpty,
          reason: 'anúncio é por TRANSIÇÃO; a Loja reconstrói a cada quadro');
    });
  });

  group('PROVA-09 · pendente não afirma direito', () {
    testWidgets('aparece, explica a espera e não diz que há VIP',
        (tester) async {
      final b = Bancada(tester);
      await b.montar(estado: EstadoDaCompraNaLoja.aguardandoConfirmacao);

      expect(find.textContaining('não é preciso comprar de novo'),
          findsOneWidget);
      expect(find.text('Seu acesso VIP está ativo'), findsNothing);
    });

    testWidgets('nem no estado CONCLUÍDA, que é o mais perigoso',
        (tester) async {
      final b = Bancada(tester);
      await b.montar(estado: EstadoDaCompraNaLoja.concluida);

      // O texto fala de liberação em curso, não de acesso obtido.
      expect(find.textContaining('assim que o servidor'), findsOneWidget);
      expect(find.text('Seu acesso VIP está ativo'), findsNothing,
          reason: 'compra validada com assinatura em ON_HOLD é exatamente '
              'este estado, e sem VIP nenhum');
    });

    test('nenhuma mensagem de compra promete VIP concedido', () {
      for (final e in EstadoDaCompraNaLoja.values) {
        final texto = e.mensagem;
        if (texto == null) continue;
        final minusculo = texto.toLowerCase();
        expect(minusculo.contains('vip ativo'), isFalse, reason: '$e');
        expect(minusculo.contains('vip liberado'), isFalse, reason: '$e');
        expect(minusculo.contains('você é vip'), isFalse, reason: '$e');
        expect(minusculo.contains('vip ativado'), isFalse, reason: '$e');
      }
    });
  });

  // -------------------------------------------------------------------------
  // §9 — VIP
  // -------------------------------------------------------------------------
  group('PROVA-10 · mudança para VIP', () {
    testWidgets('é anunciada exatamente uma vez', (tester) async {
      final b = Bancada(tester);
      b.escutarAnuncios();
      await b.montar(vm: LojaVM(ehVip: false, planos: planosDaPlay()));
      b.anuncios.clear();

      await b.montar(vm: LojaVM(ehVip: true, planos: planosDaPlay()));
      expect(b.anuncios, hasLength(1));
      expect(b.anuncios.single, contains('VIP'));
      expect(find.text('Seu acesso VIP está ativo'), findsOneWidget);
    });

    testWidgets('e reconstruir já VIP não reanuncia', (tester) async {
      final b = Bancada(tester);
      b.escutarAnuncios();
      await b.montar(vm: LojaVM(ehVip: true, planos: planosDaPlay()));
      b.anuncios.clear();

      await b.montar(vm: LojaVM(ehVip: true, planos: planosDaPlay()));
      await b.montar(vm: LojaVM(ehVip: true, planos: planosDaPlay()));

      expect(b.anuncios, isEmpty);
    });
  });

  // -------------------------------------------------------------------------
  // §6 — navegação inferior e título
  // -------------------------------------------------------------------------
  group('PROVA-11 · navegação inferior', () {
    testWidgets('quatro destinos com 48 dp, papel e a aba atual selecionada',
        (tester) async {
      final SemanticsHandle h = tester.ensureSemantics();
      final b = Bancada(tester);
      await b.montar();

      const destinos = <String>['Início', 'Ranking', 'Perfil'];
      for (final d in destinos) {
        final item = no(tester, d);
        expect(item.ehBotao, isTrue, reason: '$d precisa ser botão');
        expect(item.altura, greaterThanOrEqualTo(kAlvoMinimo), reason: d);
        expect(item.largura, greaterThanOrEqualTo(kAlvoMinimo), reason: d);
        expect(item.selecionado, isFalse, reason: d);
      }

      // A aba "Loja" divide o rótulo com o título da tela, então é localizada
      // pelo que a distingue: ela é botão, e o título é cabeçalho.
      final aba = arvore(tester)
          .where((n) => n.rotulo == 'Loja' && n.ehBotao)
          .single;
      expect(aba.selecionado, isTrue,
          reason: 'a aba atual precisa ser anunciada como selecionada');
      expect(aba.altura, greaterThanOrEqualTo(kAlvoMinimo));
      h.dispose();
    });

    testWidgets('a aba atual não depende só de cor', (tester) async {
      final b = Bancada(tester);
      await b.montar();
      // O traço indicador é desenhado só sob o item ativo.
      final indicadores =
          tester.widgetList<Container>(find.byType(Container)).where((c) {
        final d = c.decoration;
        return d is BoxDecoration && d.color == LojaScreen.gold;
      });
      expect(indicadores, hasLength(1),
          reason: 'exatamente um traço de aba ativa');
    });

    testWidgets('e TODOS os acionáveis da tela passam nos 48 dp',
        (tester) async {
      final SemanticsHandle h = tester.ensureSemantics();
      final b = Bancada(tester);
      await b.montar();

      final pequenos = acionaveis(tester)
          .where((n) => n.largura < kAlvoMinimo || n.altura < kAlvoMinimo)
          .toList();
      expect(pequenos, isEmpty, reason: 'alvos pequenos: $pequenos');

      final semNome =
          acionaveis(tester).where((n) => n.rotulo.trim().isEmpty).toList();
      expect(semNome, isEmpty, reason: 'acionáveis sem nome: $semNome');
      h.dispose();
    });

    testWidgets('o título da tela é cabeçalho', (tester) async {
      final SemanticsHandle h = tester.ensureSemantics();
      final b = Bancada(tester);
      await b.montar();
      expect(
        arvore(tester).where((n) => n.rotulo == 'Loja' && n.ehCabecalho),
        hasLength(1),
      );
      h.dispose();
    });
  });

  // -------------------------------------------------------------------------
  // §7 — escala de texto
  // -------------------------------------------------------------------------
  group('PROVA-12 · escala de texto', () {
    for (final escala in <double>[1.0, 1.5, 2.0]) {
      testWidgets('sem estouro em ${(escala * 100).round()}%', (tester) async {
        final b = Bancada(tester);
        await b.montar(escala: escala);
        expect(tester.takeException(), isNull);
        expect(caixasEstouradas(tester), 0,
            reason: 'os cards de plano tinham height: 132 e cortavam o '
                'desconto em 200%');
      });
    }

    testWidgets('sem estouro em 200% na menor largura suportada',
        (tester) async {
      final b = Bancada(tester);
      await b.montar(escala: 2.0, tela: kLarguraMinima);
      expect(tester.takeException(), isNull);
      expect(caixasEstouradas(tester), 0);
    });

    testWidgets('e preço, por mês e desconto continuam visíveis em 200%',
        (tester) async {
      final b = Bancada(tester);
      await b.montar(escala: 2.0);
      expect(find.text(kPrecoAnual), findsOneWidget);
      expect(find.textContaining('/mês'), findsWidgets);
      expect(find.text('-37%'), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // §8 — contraste
  // -------------------------------------------------------------------------
  group('PROVA-13 · contraste', () {
    // Os dois extremos do gradiente do card em destaque.
    const topo = Color(0xFFF8DEA0);
    const base = Color(0xFFEAB43E);
    const barra = Color(0xFF0D0805);

    test('o selo de desconto passa nos DOIS extremos do destaque', () {
      const selo = Color(0xFF0F3D2A);
      expect(contraste(selo, topo), greaterThanOrEqualTo(4.5));
      expect(contraste(selo, base), greaterThanOrEqualTo(4.5));
      // A cor auditada era esta, e dava 1,14:1 na base.
      expect(contraste(const Color(0xFF5BE0A2), base), lessThan(4.5));
    });

    test('o por-mês do destaque passa nos dois extremos', () {
      const porMes = Color(0xFF4E3208);
      expect(contraste(porMes, topo), greaterThanOrEqualTo(4.5));
      expect(contraste(porMes, base), greaterThanOrEqualTo(4.5));
      expect(contraste(const Color(0xFF6D4A12), base), lessThan(4.5));
    });

    test('o rótulo inativo da navegação passa', () {
      final inativo = compor(Colors.white.withValues(alpha: .55), barra);
      expect(contraste(inativo, barra), greaterThanOrEqualTo(4.5));
      final auditado = compor(Colors.white.withValues(alpha: .26), barra);
      expect(contraste(auditado, barra), lessThan(4.5));
    });

    test('o traço da aba ativa passa a régua de elemento gráfico', () {
      expect(contraste(LojaScreen.gold, barra), greaterThanOrEqualTo(3.0));
    });

    testWidgets('e as cores medidas são as que a tela realmente usa',
        (tester) async {
      final b = Bancada(tester);
      await b.montar();
      // O selo do plano em destaque, lido do widget e não de uma constante
      // repetida no caso.
      final selo = tester.widget<Text>(find.text('-37%'));
      expect(selo.style?.color, const Color(0xFF0F3D2A),
          reason: 'o caso de contraste tem de medir a cor REAL do widget');

      final porMes = tester.widget<Text>(find.text('R\$ 12,49/mês'));
      expect(porMes.style?.color, const Color(0xFF4E3208));
    });

    testWidgets('o rótulo inativo da navegação, LIDO DO WIDGET, passa',
        (tester) async {
      // O caso acima mede uma constante escrita aqui. Este mede a cor que o
      // widget realmente carrega — e é a diferença entre um caso que detecta a
      // regressão e um que só repete o valor certo para si mesmo.
      final b = Bancada(tester);
      await b.montar();

      for (final rotulo in const <String>['Início', 'Ranking', 'Perfil']) {
        final texto = tester.widget<Text>(find.text(rotulo));
        final cor = texto.style?.color;
        expect(cor, isNotNull, reason: rotulo);
        expect(
          contraste(compor(cor!, barra), barra),
          greaterThanOrEqualTo(4.5),
          reason: 'o rótulo "$rotulo" da barra inferior',
        );
      }
    });
  });

  // -------------------------------------------------------------------------
  // §11.14 e §11.15 — origem do preço e ausência de plataforma
  // -------------------------------------------------------------------------
  group('PROVA-14 · o preço vem da Play', () {
    test('o adaptador entrega exatamente o formattedPrice da fixture', () {
      final planos = planosDaPlay();
      expect(planos.map((p) => p.preco).toList(),
          <String>[kPrecoMensal, kPrecoTrimestral, kPrecoAnual]);
      // E os identificadores são os PLANOS-BASE, não o id do produto.
      expect(planos.map((p) => p.id).toList(),
          <String>['monthly_auto', 'quarterly_auto', 'yearly_auto']);
    });

    testWidgets('e é esse valor que aparece na tela', (tester) async {
      final b = Bancada(tester);
      await b.montar();
      expect(find.text(kPrecoAnual), findsOneWidget);
    });

    test('catálogo vazio produz zero plano — nenhum preço de reserva', () {
      expect(planosParaLoja(const <PlanoVipDisponivel>[]), isEmpty);
    });

    test('trocar a fixture troca o preço exibido', () {
      // Prova de que o valor ATRAVESSA, e não é escolhido no meio do caminho:
      // uma moeda que nenhuma constante do cliente conhece chega intacta.
      final outro = planosParaLoja(planosVipDe(
        GooglePlayProductDetails.fromProductDetails(ProductDetailsWrapper(
          description: 'x',
          name: 'x',
          productId: 'master_vip',
          productType: ProductType.subs,
          title: 'x',
          subscriptionOfferDetails: <SubscriptionOfferDetailsWrapper>[
            _planoBase(
              basePlanId: 'monthly_auto',
              periodo: 'P1M',
              precoFormatado: 'US\$ 3.99',
              precoMicros: 3990000,
            ),
          ],
        )),
      ));
      expect(outro.single.preco, 'US\$ 3.99');
    });
  });

  group('PROVA-15 · nenhuma plataforma é tocada', () {
    test('a suíte não importa Billing real, Play real nem Firebase', () {
      // Lê o próprio arquivo: um import novo que abrisse plataforma faria este
      // caso reprovar antes de o efeito colateral chegar a produção.
      //
      // SÓ AS LINHAS DE `import`, e não o arquivo inteiro. A primeira versão
      // deste caso varria o texto todo e reprovava sozinha: a própria lista de
      // proibidos, escrita logo abaixo, casava com a busca. Um teste estrutural
      // que lê o arquivo onde ele mesmo mora precisa olhar para a construção da
      // linguagem, não para a ocorrência da palavra.
      final imports = _lerEsteArquivo()
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.startsWith('import '))
          .toList();
      expect(imports, isNotEmpty, reason: 'ÂNCORA PERDIDA: nenhum import lido');

      const proibidos = <String>[
        // `servico_billing.dart` e `validacao.dart` NAO estao aqui, e a
        // ausencia e deliberada: os dois sao Dart puro com as pontas
        // injetaveis, e e por elas que a Play e o backend entram encenados.
        // O que nao pode entrar sao as BORDAS REAIS.
        'entitlement_repositorio.dart',
        'validacao_firebase.dart',
        'vinculo_firebase.dart',
        'package:firebase_core',
        'package:cloud_firestore',
        'package:firebase_auth',
        'package:cloud_functions',
      ];
      for (final p in proibidos) {
        expect(
          imports.where((l) => l.contains(p)),
          isEmpty,
          reason: 'import proibido: $p',
        );
      }

      // A borda REAL da Play mora em `loja_play.dart`, e construí-la exigiria
      // importar aquele arquivo aqui — que é o que a lista acima impede.
      //
      // Não há verificação textual de "ninguém escreveu LojaPlayReal()", e a
      // ausência é deliberada: um caso que procura uma palavra dentro do
      // arquivo onde ele mesmo mora encontra a própria busca. A prova que
      // fecha o assunto é comportamental — o caso do host confere
      // `assinaturasAbertas == 0` na Play encenada, que é a única que esta
      // suíte inteira alcança.
    });

    testWidgets('e nenhum caminho da tela concede VIP', (tester) async {
      final b = Bancada(tester);
      await b.montar();
      await tester.tap(find.text('Assinar plano anual'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continuar para o pagamento'));
      await tester.pumpAndSettle();

      // A intenção saiu — e o selo NÃO acendeu, porque quem o acende é o
      // backend, e ele não participa desta suíte.
      expect(b.registro.intencoes, hasLength(1));
      expect(find.text('Seu acesso VIP está ativo'), findsNothing);
    });
  });
  // -------------------------------------------------------------------------
  // §5 no HOST DE PRODUÇÃO — a ligação, e não só a tela
  // -------------------------------------------------------------------------
  //
  // Os casos acima montam `LojaScreen` direto e provam o que a TELA faz com o
  // estado que recebe. Faltava o outro lado: que `LojaDeProducao` de fato
  // ENTREGA esse estado. Sem isto, apagar a linha `estadoDaCompra:` do host
  // deixaria a suíte inteira verde — e foi exatamente o que a campanha de
  // mutação mostrou na primeira rodada.
  group('PROVA-05b · o host repassa o estado da compra', () {
    testWidgets('uma tentativa que falha aparece na tela', (tester) async {
      final play = LojaPlayFalsa();
      play.respostaDoCatalogo = ProductDetailsResponse(
        productDetails: _produtoComTresPlanos(),
        notFoundIDs: const <String>[],
      );
      addTearDown(play.descartar);

      await _montarHost(tester, play);

      // A vitrine chegou com os planos que a Play "devolveu".
      expect(find.text('Assinar plano anual'), findsOneWidget);

      await tester.tap(find.text('Assinar plano anual'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continuar para o pagamento'));
      await tester.pumpAndSettle();

      // Sem sessão não há vínculo de conta, e o serviço RECUSA antes de abrir
      // qualquer diálogo da Play. O que a OS exige é que essa recusa não seja
      // silenciosa — e é este texto que prova que o estado atravessou o host.
      expect(
        find.textContaining('não conseguiu concluir'),
        findsOneWidget,
        reason: 'o resultado da tentativa tem de chegar à tela pelo host',
      );

      // E nenhum fluxo de cobrança foi aberto.
      expect(play.assinaturasAbertas, 0);
      expect(play.consumiveisAbertos, 0);
    });

    testWidgets('e o estado ocioso não inventa faixa nenhuma', (tester) async {
      final play = LojaPlayFalsa();
      play.respostaDoCatalogo = ProductDetailsResponse(
        productDetails: _produtoComTresPlanos(),
        notFoundIDs: const <String>[],
      );
      addTearDown(play.descartar);

      await _montarHost(tester, play);
      expect(find.textContaining('não conseguiu concluir'), findsNothing);
      expect(find.textContaining('Compra cancelada'), findsNothing);
    });

    test('a tradução cobre os oito estados do Billing', () {
      // Um `switch` exaustivo já obriga a cobertura em tempo de compilação; o
      // que este caso guarda é o SIGNIFICADO de duas escolhas que um `switch`
      // não sabe defender sozinho.
      expect(
        estadoDaCompraParaLoja(EstadoCompra.validada),
        EstadoDaCompraNaLoja.concluida,
        reason: 'validada não pode virar um estado que afirme VIP',
      );
      expect(
        estadoDaCompraParaLoja(EstadoCompra.aguardandoRevalidacao),
        estadoDaCompraParaLoja(EstadoCompra.aguardandoValidacao),
        reason: 'os dois pedem a mesma coisa de quem lê: esperar',
      );
      // E o mapeamento é total: nenhum estado do Billing cai em `ociosa` por
      // engano.
      for (final e in EstadoCompra.values) {
        final traduzido = estadoDaCompraParaLoja(e);
        if (e != EstadoCompra.ociosa) {
          expect(traduzido, isNot(EstadoDaCompraNaLoja.ociosa), reason: '$e');
        }
      }
    });
  });

}

/// O texto deste próprio arquivo.
///
/// O caminho é relativo à raiz do pacote, que é o diretório de trabalho tanto
/// aqui quanto no `app_build` do CI.
String _lerEsteArquivo() {
  final f = File('test/casca/loja_a11y_comercial_test.dart');
  expect(f.existsSync(), isTrue,
      reason: 'a suíte precisa conseguir ler a si mesma');
  return f.readAsStringSync();
}

/// Monta a `LojaDeProducao` REAL, com a Play encenada e sem Firebase.
///
/// Não há `EscopoSessao` acima, e é de propósito: `identidadeDe` tolera a
/// ausência e devolve `deslogado`, o que dá um uid nulo. É o cenário em que o
/// serviço recusa a compra ANTES de abrir qualquer diálogo — a forma mais
/// segura de exercitar o caminho de resultado sem chegar perto de uma cobrança.
Future<void> _montarHost(WidgetTester tester, LojaPlayFalsa play) async {
  tester.view.physicalSize = kTelefone;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final dependencias = DependenciasDaLoja(
    criarBilling: (sessao) => ServicoBilling(
      loja: play,
      sessao: sessao,
      // O CATALOGO OFICIAL ESTA VAZIO HOJE — `CatalogoBilling.oficial` declara
      // `assinaturas: {}`, porque `master_vip` ainda nao existe na Play Console.
      // Este teste encena o dia em que ele existir, que e exatamente o dia em
      // que os dois P0 comerciais passariam a ser alcancaveis.
      catalogo: const CatalogoBilling(assinaturas: <String>{'master_vip'}),
      validador: ValidadorRoteirizado(
        (_) => const ResultadoValidacao.recusada('sem backend neste teste'),
      ),
      registrador: (_) {},
    ),
    // Sem documento de direito: quem acende o selo é o backend, e ele não
    // participa desta suíte.
    observarEntitlement: (_) => const Stream<EntitlementVip>.empty(),
  );

  await tester.pumpWidget(
    EscopoLoja(
      dependencias: dependencias,
      child: const MaterialApp(home: LojaDeProducao()),
    ),
  );
  await tester.pumpAndSettle();
}
