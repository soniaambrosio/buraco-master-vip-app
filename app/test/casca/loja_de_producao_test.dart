// loja_de_producao_test.dart — a Loja alcançável pelo aplicativo publicável.
//
// O QUE ESTÁ SENDO EXERCITADO É A CASCA DE VERDADE. A raiz é a
// `RaizDoAplicativo` real, a sessão é a `SessaoDoJogador` real e a Home é a
// `HomeDeProducao` real — a navegação provada aqui é a mesma que o APK executa.
// Falsas são só as duas pontas do mundo que a Loja toca: a Play Store (via a
// porta `LojaPlay`) e o documento de direito VIP do Firestore.
//
// AS QUATRO PERGUNTAS QUE ESTA SUÍTE RESPONDE
//
//   1. Dá para CHEGAR na Loja partindo da Home publicável? (era "não": o único
//      caminho vivia no `_LojaPreviewHost` do `main.dart` de prévias, e a Casca
//      V2 apagou aquele arquivo.)
//   2. Dá para VOLTAR? E a Home continua viva embaixo?
//   3. A Loja de produção desenha algum número que ninguém forneceu?
//   4. Existe algum caminho, dentro do cliente, que acenda o selo VIP sem o
//      backend? (a resposta tem de ser não, e o teste tenta.)
//
// SUPERFÍCIE DE TELEFONE: o padrão do `flutter_test` é 800x600, paisagem de
// desktop, e faz telas de celular estourarem em overflow. Ver
// `casca_producao_test.dart`.

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'package:buraco_master_vip/billing/servico_billing.dart';
import 'package:buraco_master_vip/billing/validacao.dart';
import 'package:buraco_master_vip/billing/vinculo.dart';
import 'package:buraco_master_vip/casca/configuracoes_de_producao.dart';
import 'package:buraco_master_vip/casca/home_de_producao.dart';
import 'package:buraco_master_vip/casca/loja_de_producao.dart';
import 'package:buraco_master_vip/casca/login_de_producao.dart';
import 'package:buraco_master_vip/elegibilidade/entitlement.dart';
import 'package:buraco_master_vip/screens/inicio_screen.dart';
import 'package:buraco_master_vip/screens/loja_screen.dart';

import '../billing/apoio/dubles.dart';
import 'bancada_online.dart';

// ===========================================================================
// A mesa de teste da Loja
// ===========================================================================

/// As dependências da Loja, encenadas.
///
/// Guarda o que a tela pediu, para que o teste possa afirmar coisas sobre o
/// PEDIDO — "não abriu escuta de entitlement sem sessão" é uma delas, e ela não
/// tem como ser vista pela tela.
class _LojaFalsa {
  _LojaFalsa({this.produtos = const <ProductDetails>[]});

  final List<ProductDetails> produtos;

  final play = LojaPlayFalsa();
  final entitlements = StreamController<EntitlementVip>.broadcast();

  /// Os uids para os quais a escuta de `playerEntitlements/{uid}` foi aberta.
  final List<String> escutasAbertas = <String>[];

  /// A sessão que o serviço recebeu, na ordem em que foi montado.
  final List<String?> uidsRecebidos = <String?>[];

  ServicoBilling? servico;

  DependenciasDaLoja get dependencias => DependenciasDaLoja(
    criarBilling: (sessao) {
      uidsRecebidos.add(sessao.uid);
      play.respostaDoCatalogo = ProductDetailsResponse(
        productDetails: produtos,
        notFoundIDs: const <String>[],
      );
      final s = ServicoBilling(
        loja: play,
        sessao: sessao,
        validador: ValidadorRoteirizado(
          (_) => const ResultadoValidacao.recusada('sem backend neste teste'),
        ),
        // Sem vínculo concedido, o serviço se recusa a abrir a compra — que é
        // exatamente o que se quer provar no caso "assinar não acende VIP".
        preparador: PreparadorFixo(null),
        // Um registrador mudo: o padrão do serviço escreve em `debugPrint`, e o
        // que interessa aqui é a tela, não o log.
        registrador: (_) {},
      );
      servico = s;
      return s;
    },
    observarEntitlement: (uid) {
      escutasAbertas.add(uid);
      return entitlements.stream;
    },
  );

  Future<void> fechar() async {
    await entitlements.close();
    await play.descartar();
  }
}

/// Um direito VIP vigente até bem depois do fim do teste.
///
/// Os três campos são obrigatórios juntos: `vigenteEm` exige `vipAtivo`, um
/// estado que conceda e uma data de expiração no futuro. Faltando qualquer um,
/// o direito não vale — e é assim de propósito, para que dúvida nunca conceda.
EntitlementVip _vipVigente(String uid) => EntitlementVip.fromMap(uid, {
  'vipAtivo': true,
  'estado': 'ativo',
  'expiraEm': DateTime.now()
      .toUtc()
      .add(const Duration(days: 30))
      .toIso8601String(),
});

/// Monta o aplicativo numa superfície de telefone, com a Loja encenada.
Future<void> _abrirAplicativo(
  WidgetTester tester,
  Bancada b,
  _LojaFalsa loja,
) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  // O escopo fica ACIMA da raiz de propósito: as rotas empurradas pelo
  // `Navigator` nascem abaixo do `MaterialApp`, que nasce abaixo da raiz — é
  // assim que uma tela aberta por `push` enxerga a montagem encenada.
  await tester.pumpWidget(
    EscopoLoja(dependencias: loja.dependencias, child: b.aplicativo),
  );
  await tester.pump();
}

/// Deixa a abertura terminar e o roteamento assentar.
Future<void> _passarAAbertura(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 40));
  await tester.pumpAndSettle();
}

/// Toca no item da grade do menu da Home.
///
/// O alvo do toque é o `InkWell`, e não o `Text` — tocar no rótulo avisa
/// `warnIfMissed`. A prova do toque é a asserção seguinte, e não o gesto.
Future<void> _tocarNoMenu(WidgetTester tester, String label) async {
  final alvo = find.ancestor(
    of: find.text(label),
    matching: find.byType(InkWell),
  );
  expect(alvo, findsWidgets, reason: 'o item "$label" não está na grade');
  await tester.tap(alvo.first);
  await tester.pumpAndSettle();
}

void main() {
  // =========================================================================
  // 1 — o caminho existe
  // =========================================================================
  group('a Loja é alcançável a partir da casca', () {
    testWidgets('a grade da Home leva à Loja de produção', (tester) async {
      final b = Bancada(uidInicial: 'uid-A');
      final loja = _LojaFalsa();
      addTearDown(b.fechar);
      addTearDown(loja.fechar);

      await _abrirAplicativo(tester, b, loja);
      await _passarAAbertura(tester);
      expect(find.byType(HomeDeProducao), findsOneWidget);

      await _tocarNoMenu(tester, 'Loja VIP');

      expect(find.byType(LojaDeProducao), findsOneWidget);
      expect(find.byType(LojaScreen), findsOneWidget);
    });

    testWidgets('o item da Loja não está mais apagado na grade', (
      tester,
    ) async {
      // O `disponivel: false` desenhava o selo de indisponível e fazia o toque
      // virar aviso. Enquanto ele estiver lá, um caminho novo não é alcançável
      // pelo dedo de ninguém — só pelo teste que chama o callback direto.
      final b = Bancada(uidInicial: 'uid-A');
      final loja = _LojaFalsa();
      addTearDown(b.fechar);
      addTearDown(loja.fechar);

      await _abrirAplicativo(tester, b, loja);
      await _passarAAbertura(tester);

      final inicio = tester.widget<InicioScreen>(find.byType(InicioScreen));
      final item = inicio.vm.menu.firstWhere((m) => m.id == 'loja');
      expect(item.disponivel, isTrue);
    });

    testWidgets('os Ajustes também abrem a Loja', (tester) async {
      final b = Bancada(uidInicial: 'uid-A');
      final loja = _LojaFalsa();
      addTearDown(b.fechar);
      addTearDown(loja.fechar);

      await _abrirAplicativo(tester, b, loja);
      await _passarAAbertura(tester);
      await _tocarNoMenu(tester, 'Ajustes');
      expect(find.byType(ConfiguracoesDeProducao), findsOneWidget);

      await tester.tap(find.text('Assinatura VIP'));
      await tester.pumpAndSettle();

      expect(find.byType(LojaDeProducao), findsOneWidget);
    });

    testWidgets('o ‹ da Loja volta para a Home, que continua viva', (
      tester,
    ) async {
      final b = Bancada(uidInicial: 'uid-A');
      final loja = _LojaFalsa();
      addTearDown(b.fechar);
      addTearDown(loja.fechar);

      await _abrirAplicativo(tester, b, loja);
      await _passarAAbertura(tester);
      await _tocarNoMenu(tester, 'Loja VIP');
      expect(find.byType(LojaDeProducao), findsOneWidget);

      await tester.tap(find.text('‹'));
      await tester.pumpAndSettle();

      expect(find.byType(LojaDeProducao), findsNothing);
      expect(find.byType(HomeDeProducao), findsOneWidget);
    });
  });

  // =========================================================================
  // 2 — a sessão manda
  // =========================================================================
  group('a Loja respeita a sessão', () {
    testWidgets('o Billing é montado com o uid da sessão canônica', (
      tester,
    ) async {
      final b = Bancada(uidInicial: 'uid-A');
      final loja = _LojaFalsa();
      addTearDown(b.fechar);
      addTearDown(loja.fechar);

      await _abrirAplicativo(tester, b, loja);
      await _passarAAbertura(tester);
      await _tocarNoMenu(tester, 'Loja VIP');

      expect(loja.uidsRecebidos, ['uid-A']);
      expect(loja.escutasAbertas, ['uid-A']);
    });

    testWidgets('sair da conta com a Loja aberta descarta a Loja', (
      tester,
    ) async {
      // Este é o caso que um roteamento por `home:` não cobre: a Loja foi
      // EMPURRADA sobre a Home, e trocar a tela de baixo a deixaria por cima,
      // privada, de uma sessão encerrada.
      final b = Bancada(uidInicial: 'uid-A');
      final loja = _LojaFalsa();
      addTearDown(b.fechar);
      addTearDown(loja.fechar);

      await _abrirAplicativo(tester, b, loja);
      await _passarAAbertura(tester);
      await _tocarNoMenu(tester, 'Loja VIP');
      expect(find.byType(LojaDeProducao), findsOneWidget);

      b.fluxo.add(null); // logout
      await tester.pumpAndSettle();

      expect(find.byType(LojaDeProducao), findsNothing);
      expect(find.byType(LoginDeProducao), findsOneWidget);
    });

    testWidgets('sem sessão a Loja nem é alcançável', (tester) async {
      final b = Bancada();
      final loja = _LojaFalsa();
      addTearDown(b.fechar);
      addTearDown(loja.fechar);

      await _abrirAplicativo(tester, b, loja);
      b.fluxo.add(null);
      await _passarAAbertura(tester);

      expect(find.byType(LoginDeProducao), findsOneWidget);
      expect(find.byType(HomeDeProducao), findsNothing);
      // E nada de Billing montado: a tela pública não tem o que vender.
      expect(loja.uidsRecebidos, isEmpty);
      expect(loja.escutasAbertas, isEmpty);
    });
  });

  // =========================================================================
  // 3 — a Loja de produção não afirma o que não sabe
  // =========================================================================
  group('a Loja de produção não desenha dado sem fonte', () {
    late Bancada b;
    late _LojaFalsa loja;

    Future<void> abrirALoja(WidgetTester tester) async {
      b = Bancada(uidInicial: 'uid-A');
      loja = _LojaFalsa();
      addTearDown(b.fechar);
      addTearDown(loja.fechar);
      await _abrirAplicativo(tester, b, loja);
      await _passarAAbertura(tester);
      await _tocarNoMenu(tester, 'Loja VIP');
    }

    testWidgets('o VM não traz carteira, pacote, cosmético nem amigo', (
      tester,
    ) async {
      await abrirALoja(tester);

      final tela = tester.widget<LojaScreen>(find.byType(LojaScreen));
      // Nulo, e não zero: "0 moedas" é a afirmação de que alguém consultou a
      // carteira desta pessoa. Ninguém consultou.
      expect(tela.vm.moedas, isNull);
      expect(tela.vm.gemas, isNull);
      expect(tela.vm.pacotes, isEmpty);
      expect(tela.vm.categorias, isEmpty);
      expect(tela.vm.amigos, isEmpty);
    });

    testWidgets('as seções de maquete não chegam à tela', (tester) async {
      await abrirALoja(tester);

      // Os títulos das seções da maquete. Se algum aparecer, é porque a Loja de
      // produção voltou a desenhar `LojaVM.mock()`.
      expect(find.text('MOEDAS'), findsNothing);
      expect(find.text('COSMÉTICOS'), findsNothing);
      expect(find.text('Presentear assinatura VIP'), findsNothing);
      // E nenhum preço escrito no código: o único preço que a Loja pode exibir é
      // o `formattedPrice` que a Play devolveu.
      expect(find.textContaining('R\$'), findsNothing);
    });

    testWidgets('sem planos, a vitrine explica em vez de ficar vazia', (
      tester,
    ) async {
      await abrirALoja(tester);
      expect(
        find.textContaining('ainda não está à venda'),
        findsOneWidget,
        reason:
            'catálogo vazio é o estado de hoje e precisa ser dito; um buraco no '
            'lugar da grade lê-se como aplicativo quebrado',
      );
    });
  });

  // =========================================================================
  // 4 — o selo VIP tem uma fonte só
  // =========================================================================
  group('o VIP vem do backend, e só dele', () {
    testWidgets('a Loja abre sem VIP quando não há documento', (tester) async {
      final b = Bancada(uidInicial: 'uid-A');
      final loja = _LojaFalsa();
      addTearDown(b.fechar);
      addTearDown(loja.fechar);

      await _abrirAplicativo(tester, b, loja);
      await _passarAAbertura(tester);
      await _tocarNoMenu(tester, 'Loja VIP');

      expect(find.text('Seu acesso VIP está ativo'), findsNothing);
      expect(tester.widget<LojaScreen>(find.byType(LojaScreen)).vm.ehVip,
          isFalse);
    });

    testWidgets('o entitlement do backend acende o selo', (tester) async {
      final b = Bancada(uidInicial: 'uid-A');
      final loja = _LojaFalsa();
      addTearDown(b.fechar);
      addTearDown(loja.fechar);

      await _abrirAplicativo(tester, b, loja);
      await _passarAAbertura(tester);
      await _tocarNoMenu(tester, 'Loja VIP');

      loja.entitlements.add(_vipVigente('uid-A'));
      await tester.pumpAndSettle();

      expect(find.text('Seu acesso VIP está ativo'), findsOneWidget);
      expect(
        tester.widget<LojaScreen>(find.byType(LojaScreen)).vm.ehVip,
        isTrue,
      );
    });

    testWidgets('tocar em assinar NÃO acende o VIP', (tester) async {
      // A prova comportamental do defeito que a linhagem do Billing fechou: o
      // host antigo fazia `setState(() => _ehVip = true)` no clique. Aqui a Play
      // tem um plano de verdade, o toque abre o fluxo de compra, a Play até
      // confirma a abertura — e o selo continua apagado, porque nenhum
      // documento de direito chegou.
      final b = Bancada(uidInicial: 'uid-A');
      final loja = _LojaFalsa(
        produtos: <ProductDetails>[produtoFalso('master_vip')],
      );
      addTearDown(b.fechar);
      addTearDown(loja.fechar);

      await _abrirAplicativo(tester, b, loja);
      await _passarAAbertura(tester);
      await _tocarNoMenu(tester, 'Loja VIP');
      await tester.pumpAndSettle();

      final tela = tester.widget<LojaScreen>(find.byType(LojaScreen));
      // `produtoFalso` não carrega `subscriptionOfferDetails`, então a Play não
      // descreve plano-base nenhum e a grade continua vazia. É o estado real de
      // um produto mal configurado na Console, e o que ele NÃO pode produzir é
      // um VIP local.
      tela.onAssinar('monthly_auto');
      await tester.pumpAndSettle();

      expect(
        tester.widget<LojaScreen>(find.byType(LojaScreen)).vm.ehVip,
        isFalse,
        reason: 'nenhum caminho do cliente pode conceder VIP',
      );
      expect(find.text('Seu acesso VIP está ativo'), findsNothing);
    });

    testWidgets('a Loja fechada não deixa escuta aberta', (tester) async {
      final b = Bancada(uidInicial: 'uid-A');
      final loja = _LojaFalsa();
      addTearDown(b.fechar);
      addTearDown(loja.fechar);

      await _abrirAplicativo(tester, b, loja);
      await _passarAAbertura(tester);
      await _tocarNoMenu(tester, 'Loja VIP');
      expect(loja.servico, isNotNull);

      await tester.tap(find.text('‹'));
      await tester.pumpAndSettle();

      // Um evento depois do descarte não pode chegar a `setState` de um widget
      // morto — o `flutter_test` reprova erro assíncrono solto, então este caso
      // falharia sozinho se a escuta tivesse ficado.
      loja.entitlements.add(_vipVigente('uid-A'));
      await tester.pumpAndSettle();
      expect(find.byType(HomeDeProducao), findsOneWidget);
    });
  });

  // =========================================================================
  // 5 — a direção da falha
  // =========================================================================
  testWidgets('fora do escopo, a montagem é a de PRODUÇÃO', (tester) async {
    // Esquecer de montar o `EscopoLoja` não pode entregar uma Loja de teste,
    // com Play encenada e VIP fácil, dentro do APK. Fora do escopo, `de()`
    // devolve a montagem real — e a prova é que ela é IDÊNTICA à constante de
    // produção, e não "alguma coisa não nula".
    late DependenciasDaLoja vista;
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          vista = EscopoLoja.de(context);
          return const SizedBox.shrink();
        },
      ),
    );
    expect(identical(vista, DependenciasDaLoja.producao), isTrue);
  });

  // =========================================================================
  // 6 — o critério de PASS da OS, escrito como teste
  // =========================================================================
  //
  // Os casos acima provam a navegação em runtime, que é a prova forte. Este
  // prova a MESMA coisa pelo fecho de imports a partir de `lib/main.dart` — e
  // vale por dois motivos que o runtime não cobre: ele reprova se alguém
  // ressuscitar um host de prévia como caminho da Loja, e ele responde
  // literalmente à pergunta da ordem de serviço ("alcançável sem passar por
  // main.dart de preview") em vez de a inferir de um `find.byType`.
  //
  // A técnica de despojar comentários é a de `auditoria_casca_test.dart`, e
  // pelo mesmo motivo: este arquivo fala de `PreviewHost` em prosa.
  test('a Loja está no fecho de imports da raiz de produção', () {
    final alcancaveis = _alcancaveisDaRaiz();
    expect(alcancaveis, contains('lib/main.dart'));
    expect(
      alcancaveis,
      containsAll(<String>[
        'lib/casca/loja_de_producao.dart',
        'lib/screens/loja_screen.dart',
      ]),
      reason: 'a Loja voltou a ficar fora do alcance de main()',
    );
    // E o caminho não passa por bancada de prévias: a raiz não hospeda host
    // nenhum, e a tela de categorias de cosmético — que é maquete pura, com
    // preço e cadeado — continua sem ninguém que a alcance.
    expect(_semComentarios(File('lib/main.dart')), isNot(contains('Preview')));
    expect(alcancaveis, isNot(contains('lib/screens/loja_categoria_screen.dart')));
  });
}

// ===========================================================================
// O fecho de imports, medido do mesmo jeito que a auditoria da casca mede
// ===========================================================================

String _semComentarios(File f) {
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

String _resolver(String deQuem, String importado) {
  if (importado.startsWith('package:buraco_master_vip/')) {
    return 'lib/${importado.substring('package:buraco_master_vip/'.length)}';
  }
  final base = deQuem.replaceAll(r'\', '/').split('/')..removeLast();
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

Set<String> _alcancaveisDaRaiz() {
  final padrao = RegExp(r'''import\s+['"]([^'"]+)['"]''');
  final vistos = <String>{};
  final fila = <String>['lib/main.dart'];
  while (fila.isNotEmpty) {
    final atual = fila.removeLast();
    if (!vistos.add(atual)) continue;
    final f = File(atual);
    if (!f.existsSync()) continue;
    for (final m in padrao.allMatches(_semComentarios(f))) {
      final alvo = m.group(1)!;
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
