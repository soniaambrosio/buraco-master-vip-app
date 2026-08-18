// billing_flutter_test.dart — os quinze casos exigidos pela OS de integracao do
// Google Play Billing (BILLING-FLUTTER-01 a 15).
//
// O que esta sendo protegido aqui e uma invariante que custa dinheiro nos dois
// sentidos: finalizar uma compra que nao foi validada faz a Play Store parar de
// reentrega-la, e o jogador que pagou fica sem receber; nao finalizar uma compra
// definitivamente recusada faz a Play reentregar para sempre.
//
// Roda sem plugin, sem Firebase, sem emulador e sem aparelho — as portas
// (`LojaPlay`, `ValidadorDeCompra`, `SessaoJogador`) existem exatamente para
// isso.

import 'dart:async';

import 'package:buraco_master_vip/billing/catalogo.dart';
import 'package:buraco_master_vip/billing/estado_ui.dart';
import 'package:buraco_master_vip/billing/servico_billing.dart';
import 'package:buraco_master_vip/billing/sessao.dart';
import 'package:buraco_master_vip/billing/validacao.dart';
import 'package:buraco_master_vip/elegibilidade/entitlement.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'apoio/dubles.dart';

/// Um catalogo de teste. NAO sao IDs reais e nao existem na Play Console: eles
/// so exercitam o caminho que os IDs oficiais vao percorrer quando existirem.
/// O catalogo de PRODUCAO (`CatalogoBilling.oficial`) continua vazio.
const _catalogoDeTeste = CatalogoBilling(
  assinaturas: <String>{'assinatura.de.teste'},
  consumiveis: <String>{'consumivel.de.teste'},
);

const _uid = 'jogador-1';
final _agora = DateTime.utc(2026, 8, 12, 12);

/// Monta o servico com todas as portas dubladas.
({
  ServicoBilling servico,
  LojaPlayFalsa loja,
  ValidadorRoteirizado validador,
  List<String> log,
}) montar({
  bool disponivel = true,
  CatalogoBilling catalogo = _catalogoDeTeste,
  String? uid = _uid,
  ResultadoValidacao Function(CompraParaValidar)? resposta,
}) {
  final loja = LojaPlayFalsa(estaDisponivel: disponivel);
  final validador = ValidadorRoteirizado(
    resposta ?? (_) => const ResultadoValidacao(aprovada: true),
  );
  final log = <String>[];
  final servico = ServicoBilling(
    loja: loja,
    validador: validador,
    sessao: SessaoFixa(uid),
    catalogo: catalogo,
    registrador: log.add,
  );
  return (servico: servico, loja: loja, validador: validador, log: log);
}

/// Uma resposta de catalogo com um produto encontrado.
ProductDetailsResponse _catalogoCom(List<String> ids) => ProductDetailsResponse(
      productDetails: ids.map(produtoFalso).toList(),
      notFoundIDs: const <String>[],
    );

void main() {
  // =========================================================================
  group('BILLING-FLUTTER-01 — Billing indisponivel', () {
    test('a Play Store indisponivel nao derruba o app e desliga a vitrine',
        () async {
      final m = montar(disponivel: false);
      addTearDown(m.servico.descartar);

      final estado = await m.servico.iniciar();

      expect(estado, EstadoCatalogo.indisponivel);
      expect(m.servico.estado.catalogo, EstadoCatalogo.indisponivel);
      expect(m.servico.estado.podeComprar, isFalse);
      // Sem Play nao ha o que escutar: nenhuma escuta e aberta.
      expect(m.loja.escutasAbertas, 0);
    });

    test('isAvailable lancando e tratado como indisponivel, nao como crash',
        () async {
      final loja = LojaPlayFalsa()..disponivelLanca = true;
      final servico = ServicoBilling(
        loja: loja,
        validador: ValidadorRoteirizado((_) => const ResultadoValidacao(aprovada: true)),
        sessao: const SessaoFixa(_uid),
        catalogo: _catalogoDeTeste,
        registrador: (_) {},
      );
      addTearDown(servico.descartar);

      expect(await servico.iniciar(), EstadoCatalogo.indisponivel);
    });
  });

  // =========================================================================
  group('BILLING-FLUTTER-02 — catalogo vazio', () {
    test('o catalogo OFICIAL esta vazio e o app tolera isso sem erro', () async {
      // Este e o estado real de hoje, e o que o primeiro AAB precisa exibir.
      expect(CatalogoBilling.oficial.configurado, isFalse,
          reason: 'nenhum ID provisorio pode entrar no catalogo de producao');

      final m = montar(catalogo: CatalogoBilling.oficial);
      addTearDown(m.servico.descartar);

      final estado = await m.servico.iniciar();

      expect(estado, EstadoCatalogo.semProdutos);
      expect(m.servico.estado.podeComprar, isFalse);
      expect(m.servico.assinaturas, isEmpty);
      expect(m.servico.consumiveis, isEmpty);
      // Nao se pergunta a Play Store por zero IDs.
      expect(m.loja.consultas, isEmpty);
    });

    test('catalogo declarado mas nenhum ID encontrado na Play vira semProdutos',
        () async {
      final m = montar();
      addTearDown(m.servico.descartar);
      m.loja.respostaDoCatalogo = ProductDetailsResponse(
        productDetails: const <ProductDetails>[],
        notFoundIDs: _catalogoDeTeste.todos.toList(),
      );

      expect(await m.servico.iniciar(), EstadoCatalogo.semProdutos);
    });
  });

  // =========================================================================
  group('BILLING-FLUTTER-03 — produto carregado corretamente', () {
    test('assinatura e consumivel chegam separados e a vitrine abre', () async {
      final m = montar();
      addTearDown(m.servico.descartar);
      m.loja.respostaDoCatalogo =
          _catalogoCom(['assinatura.de.teste', 'consumivel.de.teste']);

      final estado = await m.servico.iniciar();

      expect(estado, EstadoCatalogo.pronto);
      expect(m.servico.estado.podeComprar, isTrue);
      expect(m.servico.assinaturas.map((p) => p.id), ['assinatura.de.teste']);
      expect(m.servico.consumiveis.map((p) => p.id), ['consumivel.de.teste']);
      // Assinatura e produto unico vao na MESMA ida a Play Store.
      expect(m.loja.consultas.single, _catalogoDeTeste.todos);
    });

    test('todo ID declarado respeita o formato aceito pela Play Console', () {
      expect(_catalogoDeTeste.formatoIntegro, isTrue);
      expect(CatalogoBilling.oficial.formatoIntegro, isTrue);
    });
  });

  // =========================================================================
  group('BILLING-FLUTTER-04 — compra cancelada pelo usuario', () {
    test('cancelar nao valida, nao concede, e devolve o app a um estado estavel',
        () async {
      final m = montar();
      addTearDown(m.servico.descartar);
      await m.servico.iniciar();

      m.loja.entregar([
        compraFalsa('assinatura.de.teste',
            token: 'tok-cancelada', status: PurchaseStatus.canceled),
      ]);
      await cederAoLaco();

      expect(m.servico.estado.compra, EstadoCompra.cancelada);
      expect(m.validador.chamadas, 0, reason: 'nao se valida o que nao foi pago');
      // Finaliza para a Play parar de reentregar um cancelamento.
      expect(m.loja.finalizadas, hasLength(1));
      expect(m.servico.estado.mostrarComoVip(_agora), isFalse);
    });
  });

  // =========================================================================
  group('BILLING-FLUTTER-05 — compra pendente', () {
    test('pendente nao valida, nao finaliza e nao concede', () async {
      final m = montar();
      addTearDown(m.servico.descartar);
      await m.servico.iniciar();

      m.loja.entregar([
        compraFalsa('assinatura.de.teste',
            token: 'tok-pendente', status: PurchaseStatus.pending),
      ]);
      await cederAoLaco();

      expect(m.servico.estado.compra, EstadoCompra.pendente);
      expect(m.validador.chamadas, 0);
      // NAO finaliza: o pagamento ainda pode se concretizar, e finalizar
      // impediria a Play de entregar a conclusao.
      expect(m.loja.finalizadas, isEmpty);
      expect(m.servico.estado.mostrarComoVip(_agora), isFalse);
    });
  });

  // =========================================================================
  group('BILLING-FLUTTER-06 — compra concluida e enviada a validacao', () {
    test('o token vai para o backend com o tipo correto e o pedido', () async {
      final m = montar();
      addTearDown(m.servico.descartar);
      await m.servico.iniciar();

      m.loja.entregar([
        compraFalsa('assinatura.de.teste',
            token: 'tok-06', pedido: 'GPA.1111'),
      ]);
      await cederAoLaco();

      expect(m.validador.chamadas, 1);
      final enviada = m.validador.recebidas.single;
      expect(enviada.produtoId, 'assinatura.de.teste');
      expect(enviada.tokenCompra, 'tok-06');
      expect(enviada.assinatura, isTrue,
          reason: 'o servidor recusa com invalid-argument se o tipo divergir');
      expect(enviada.orderId, 'GPA.1111');

      // O payload e exatamente o contrato de validarCompraPlay.
      expect(enviada.paraPayload().keys.toSet(),
          {'produtoId', 'tokenCompra', 'assinatura', 'orderId'});
      expect(enviada.paraPayload().containsKey('uid'), isFalse,
          reason: 'uid mandado pelo cliente seria falsificavel');
    });

    test('consumivel viaja com assinatura: false', () async {
      final m = montar();
      addTearDown(m.servico.descartar);
      await m.servico.iniciar();

      m.loja.entregar([compraFalsa('consumivel.de.teste', token: 'tok-06b')]);
      await cederAoLaco();

      expect(m.validador.recebidas.single.assinatura, isFalse);
    });
  });

  // =========================================================================
  group('BILLING-FLUTTER-07 — backend valida com sucesso', () {
    test('aprovada finaliza a compra e marca validada — nao VIP', () async {
      final m = montar(resposta: (_) => const ResultadoValidacao(aprovada: true));
      addTearDown(m.servico.descartar);
      await m.servico.iniciar();

      m.loja.entregar([compraFalsa('assinatura.de.teste', token: 'tok-07')]);
      await cederAoLaco();

      expect(m.servico.estado.compra, EstadoCompra.validada);
      expect(m.loja.finalizadas.single.productID, 'assinatura.de.teste');
      // O selo VIP nao nasce daqui. Ver BILLING-FLUTTER-15.
      expect(m.servico.estado.mostrarComoVip(_agora), isFalse);
    });

    test('reentrega ja processada tambem e sucesso, e nao credita de novo',
        () async {
      final m = montar(
        resposta: (_) => const ResultadoValidacao(
          aprovada: false,
          jaProcessada: true,
          detalhes: <String, dynamic>{'fichasCreditadas': 1000},
        ),
      );
      addTearDown(m.servico.descartar);
      await m.servico.iniciar();

      m.loja.entregar([compraFalsa('consumivel.de.teste', token: 'tok-07b')]);
      await cederAoLaco();

      expect(m.servico.estado.compra, EstadoCompra.validada);
      expect(m.loja.finalizadas, hasLength(1));
    });
  });

  // =========================================================================
  group('BILLING-FLUTTER-08 — backend rejeita o produto', () {
    test('recusa definitiva finaliza a compra e nao concede nada', () async {
      final m = montar(
        resposta: (_) =>
            const ResultadoValidacao.recusada('produto em purchaseState 1'),
      );
      addTearDown(m.servico.descartar);
      await m.servico.iniciar();

      m.loja.entregar([compraFalsa('assinatura.de.teste', token: 'tok-08')]);
      await cederAoLaco();

      expect(m.servico.estado.compra, EstadoCompra.recusada);
      // Finaliza para a Play parar de reentregar lixo.
      expect(m.loja.finalizadas, hasLength(1));
      expect(m.servico.estado.mostrarComoVip(_agora), isFalse);
    });

    test('so permission-denied e invalid-argument sao vereditos definitivos',
        () {
      expect(codigoEDefinitivo('permission-denied'), isTrue);
      expect(codigoEDefinitivo('invalid-argument'), isTrue);

      // O RESTO E TRANSITORIO, e a lista abaixo e a que custa dinheiro:
      // descartar qualquer um destes queimaria uma compra ja paga.
      for (final codigo in <String>[
        'unauthenticated', // sessao caiu entre a compra e a validacao
        'failed-precondition', // `configuracao/billing` ainda vazio
        'unavailable',
        'deadline-exceeded',
        'internal',
        'not-found',
        'unimplemented',
        'resource-exhausted',
        'aborted',
      ]) {
        expect(codigoEDefinitivo(codigo), isFalse, reason: codigo);
      }
    });
  });

  // =========================================================================
  group('BILLING-FLUTTER-09 — erro transitorio na validacao', () {
    test('falha temporaria NAO finaliza a compra: ela volta a ser entregue',
        () async {
      final m = montar(
        resposta: (_) => const ResultadoValidacao.indisponivel('rede fora'),
      );
      addTearDown(m.servico.descartar);
      await m.servico.iniciar();

      m.loja.entregar([compraFalsa('assinatura.de.teste', token: 'tok-09')]);
      await cederAoLaco();

      expect(m.servico.estado.compra, EstadoCompra.aguardandoRevalidacao);
      expect(m.servico.estado.aguardandoServidor, isTrue);
      expect(m.loja.finalizadas, isEmpty,
          reason: 'finalizar aqui perderia a compra paga para sempre');
      expect(m.servico.estado.mostrarComoVip(_agora), isFalse);
    });

    test('a compra adiada e revalidada quando a Play a reentrega', () async {
      var falhar = true;
      final m = montar(
        resposta: (_) => falhar
            ? const ResultadoValidacao.indisponivel('rede fora')
            : const ResultadoValidacao(aprovada: true),
      );
      addTearDown(m.servico.descartar);
      await m.servico.iniciar();

      final compra = compraFalsa('assinatura.de.teste', token: 'tok-09b');
      m.loja.entregar([compra]);
      await cederAoLaco();
      expect(m.loja.finalizadas, isEmpty);

      falhar = false;
      m.loja.entregar([compra]);
      await cederAoLaco();

      expect(m.servico.estado.compra, EstadoCompra.validada);
      expect(m.loja.finalizadas, hasLength(1));
      expect(m.validador.chamadas, 2);
    });
  });

  // =========================================================================
  group('BILLING-FLUTTER-10 — callback duplicado', () {
    test('a mesma compra entregue duas vezes em voo vira UMA validacao',
        () async {
      final m = montar();
      addTearDown(m.servico.descartar);
      await m.servico.iniciar();
      m.validador.portao = Completer<void>();

      final compra = compraFalsa('assinatura.de.teste', token: 'tok-10');
      m.loja.entregar([compra]);
      await cederAoLaco();
      // Chegou de novo antes de a primeira validacao voltar.
      m.loja.entregar([compra]);
      await cederAoLaco();

      expect(m.validador.chamadas, 1,
          reason: 'a segunda entrega precisa ser absorvida em voo');

      m.validador.liberar();
      await cederAoLaco();

      expect(m.servico.estado.compra, EstadoCompra.validada);
      expect(m.loja.finalizadas, hasLength(1));
    });

    test('duas compras DIFERENTES no mesmo lote sao ambas validadas', () async {
      final m = montar();
      addTearDown(m.servico.descartar);
      await m.servico.iniciar();

      m.loja.entregar([
        compraFalsa('assinatura.de.teste', token: 'tok-10a'),
        compraFalsa('consumivel.de.teste', token: 'tok-10b'),
      ]);
      await cederAoLaco();

      expect(m.validador.chamadas, 2);
    });
  });

  // =========================================================================
  group('BILLING-FLUTTER-11 — restore reenviando compra conhecida', () {
    test('restore revalida e nao duplica beneficio', () async {
      final m = montar(
        // O backend reconhece o token que ja processou.
        resposta: (_) => const ResultadoValidacao(
          aprovada: true,
          jaProcessada: true,
        ),
      );
      addTearDown(m.servico.descartar);
      await m.servico.iniciar();

      m.loja.reentregasNoRestore = [
        compraFalsa('assinatura.de.teste',
            token: 'tok-11', status: PurchaseStatus.restored),
      ];

      await m.servico.restaurar();
      await cederAoLaco();

      expect(m.loja.restauracoes, 1);
      expect(m.servico.estado.restauracao, EstadoRestauracao.concluida);
      // Passou pela validacao — restore NAO concede por conta propria.
      expect(m.validador.chamadas, 1);
      expect(m.servico.estado.compra, EstadoCompra.validada);
      // E continua sem VIP local: quem concede e o entitlement.
      expect(m.servico.estado.mostrarComoVip(_agora), isFalse);
    });

    test('restore sem nada a restaurar tem estado proprio', () async {
      final m = montar();
      addTearDown(m.servico.descartar);
      await m.servico.iniciar();

      await m.servico.restaurar();

      expect(m.servico.estado.restauracao, EstadoRestauracao.nadaARestaurar);
      expect(m.validador.chamadas, 0);
    });

    test('restore antes de iniciar nao chama a Play', () async {
      final m = montar();
      addTearDown(m.servico.descartar);

      await m.servico.restaurar();

      expect(m.loja.restauracoes, 0);
      expect(m.servico.estado.restauracao, EstadoRestauracao.nadaARestaurar);
    });
  });

  // =========================================================================
  group('BILLING-FLUTTER-12 — usuario nao autenticado', () {
    test('sem sessao a compra e ADIADA, nunca finalizada', () async {
      final m = montar(uid: null);
      addTearDown(m.servico.descartar);
      await m.servico.iniciar();

      m.loja.entregar([compraFalsa('assinatura.de.teste', token: 'tok-12')]);
      await cederAoLaco();

      expect(m.validador.chamadas, 0,
          reason: 'nao se gasta a chamada sem sessao');
      expect(m.servico.estado.compra, EstadoCompra.aguardandoRevalidacao);
      expect(m.loja.finalizadas, isEmpty,
          reason: 'finalizar sem sessao perderia a compra do jogador que pagou');
      expect(m.servico.estado.mostrarComoVip(_agora), isFalse);
    });

    test('a mesma compra e validada assim que existe sessao', () async {
      final loja = LojaPlayFalsa();
      final validador =
          ValidadorRoteirizado((_) => const ResultadoValidacao(aprovada: true));
      String? uid;
      final servico = ServicoBilling(
        loja: loja,
        validador: validador,
        // Uma sessao que muda, como a real muda depois do login.
        sessao: _SessaoVariavel(() => uid),
        catalogo: _catalogoDeTeste,
        registrador: (_) {},
      );
      addTearDown(servico.descartar);
      await servico.iniciar();

      final compra = compraFalsa('assinatura.de.teste', token: 'tok-12b');
      loja.entregar([compra]);
      await cederAoLaco();
      expect(loja.finalizadas, isEmpty);

      uid = _uid; // o jogador entrou na conta
      loja.entregar([compra]); // a Play reentrega
      await cederAoLaco();

      expect(validador.chamadas, 1);
      expect(servico.estado.compra, EstadoCompra.validada);
      expect(loja.finalizadas, hasLength(1));
    });
  });

  // =========================================================================
  group('BILLING-FLUTTER-13 — listener nao duplica', () {
    test('iniciar duas vezes abre UMA escuta', () async {
      final m = montar();
      addTearDown(m.servico.descartar);

      await m.servico.iniciar();
      await m.servico.iniciar();
      await m.servico.iniciar();

      expect(m.loja.escutasAbertas, 1);
    });

    test('duas chamadas CONCORRENTES a iniciar tambem abrem UMA escuta',
        () async {
      final m = montar();
      addTearDown(m.servico.descartar);

      // Sem o guarda por Future, as duas passariam pelo teste `_escuta != null`
      // antes de qualquer uma atribuir, e cada compra seria entregue duas vezes.
      await Future.wait<EstadoCatalogo>(
          [m.servico.iniciar(), m.servico.iniciar()]);

      expect(m.loja.escutasAbertas, 1);
    });

    test('uma compra so produz UMA validacao depois de varios iniciar',
        () async {
      final m = montar();
      addTearDown(m.servico.descartar);
      await m.servico.iniciar();
      await m.servico.iniciar();

      m.loja.entregar([compraFalsa('assinatura.de.teste', token: 'tok-13')]);
      await cederAoLaco();

      expect(m.validador.chamadas, 1);
    });

    test('encerrar solta a escuta e permite religar', () async {
      final m = montar();
      addTearDown(m.servico.descartar);
      await m.servico.iniciar();
      await m.servico.encerrar();
      await m.servico.iniciar();

      expect(m.loja.escutasAbertas, 2, reason: 'uma por ciclo de vida');

      m.loja.entregar([compraFalsa('assinatura.de.teste', token: 'tok-13b')]);
      await cederAoLaco();

      expect(m.validador.chamadas, 1, reason: 'a escuta antiga foi cancelada');
    });
  });

  // =========================================================================
  group('BILLING-FLUTTER-14 — o token nunca aparece em log', () {
    const token = 'TOKEN-SECRETO-DA-COMPRA-jkl123XYZ';

    test('nem no caminho feliz, nem no adiado, nem no recusado', () async {
      for (final resposta in <ResultadoValidacao Function(CompraParaValidar)>[
        (_) => const ResultadoValidacao(aprovada: true),
        (_) => const ResultadoValidacao.indisponivel('rede fora'),
        (_) => const ResultadoValidacao.recusada('purchaseState 1'),
      ]) {
        final m = montar(resposta: resposta);
        await m.servico.iniciar();

        m.loja.entregar([compraFalsa('assinatura.de.teste', token: token)]);
        await cederAoLaco();

        expect(m.log, isNotEmpty, reason: 'o teste precisa ter o que examinar');
        for (final linha in m.log) {
          expect(linha, isNot(contains(token)));
        }
        // O diagnostico tambem vai parar em tela de suporte.
        expect(m.servico.estado.diagnostico ?? '', isNot(contains(token)));
        await m.servico.descartar();
      }
    });

    test('o log usa o MESMO rotulo curto que o backend', () async {
      final m = montar();
      addTearDown(m.servico.descartar);
      await m.servico.iniciar();

      m.loja.entregar([compraFalsa('assinatura.de.teste', token: token)]);
      await cederAoLaco();

      // `rotuloToken` no backend = 8 primeiros hex do SHA-256 do token.
      final rotulo = rotuloDoToken(token);
      expect(rotulo, hasLength(8));
      expect(rotulo, matches(RegExp(r'^[0-9a-f]{8}$')));
      expect(m.log.any((l) => l.contains(rotulo)), isTrue,
          reason: 'sem rotulo nao ha como correlacionar app e servidor');
    });

    test('toString de CompraParaValidar nao vaza o token', () {
      const c = CompraParaValidar(
        produtoId: 'assinatura.de.teste',
        tokenCompra: token,
        assinatura: true,
      );
      expect(c.toString(), isNot(contains(token)));
      expect(c.toString(), contains(rotuloDoToken(token)));
    });

    test('redigirToken apaga o token de um texto de terceiros', () {
      final sujo = 'erro ao serializar {"tokenCompra":"$token"}';
      final limpo = redigirToken(sujo, token);
      expect(limpo, isNot(contains(token)));
      expect(limpo, contains('<token:${rotuloDoToken(token)}>'));
    });

    test('erro do fluxo da Play nao ecoa o objeto de erro', () async {
      final m = montar();
      addTearDown(m.servico.descartar);
      await m.servico.iniciar();

      m.loja.falharNoFluxo(StateError('payload cru com $token dentro'));
      await cederAoLaco();

      for (final linha in m.log) {
        expect(linha, isNot(contains(token)));
      }
      expect(m.servico.estado.diagnostico ?? '', isNot(contains(token)));
    });
  });

  // =========================================================================
  group('BILLING-FLUTTER-15 — VIP so depois da confirmacao server-side', () {
    /// O documento `playerEntitlements/{uid}` como o Billing o grava.
    EntitlementVip entitlement({
      required bool vipAtivo,
      required EstadoEntitlement estado,
      DateTime? expiraEm,
    }) =>
        EntitlementVip(
          uid: _uid,
          vipAtivo: vipAtivo,
          estado: estado,
          origem: 'play',
          expiraEm: expiraEm,
        );

    test('compra validada, sem entitlement: NAO e VIP', () async {
      final m = montar();
      addTearDown(m.servico.descartar);
      await m.servico.iniciar();

      m.loja.entregar([compraFalsa('assinatura.de.teste', token: 'tok-15')]);
      await cederAoLaco();

      expect(m.servico.estado.compra, EstadoCompra.validada);
      expect(m.servico.estado.mostrarComoVip(_agora), isFalse,
          reason: 'a Play ter respondido purchased nao concede direito');
      // Mas a espera e visivel, para a interface nao ficar muda.
      expect(m.servico.estado.aguardandoServidor, isFalse);
    });

    test('o VIP acende quando o entitlement do backend chega', () async {
      final m = montar();
      addTearDown(m.servico.descartar);
      await m.servico.iniciar();

      m.loja.entregar([compraFalsa('assinatura.de.teste', token: 'tok-15b')]);
      await cederAoLaco();
      expect(m.servico.estado.mostrarComoVip(_agora), isFalse);

      m.servico.atualizarEntitlement(entitlement(
        vipAtivo: true,
        estado: EstadoEntitlement.ativo,
        expiraEm: _agora.add(const Duration(days: 30)),
      ));

      expect(m.servico.estado.mostrarComoVip(_agora), isTrue);
    });

    test('entitlement vencido nao concede, mesmo com vipAtivo gravado', () {
      final painel = PainelBilling(
        compra: EstadoCompra.validada,
        entitlement: entitlement(
          vipAtivo: true,
          estado: EstadoEntitlement.ativo,
          expiraEm: _agora.subtract(const Duration(minutes: 1)),
        ),
      );
      expect(painel.mostrarComoVip(_agora), isFalse);
    });

    test('estado que nao concede acesso nao vira VIP, mesmo vigente', () {
      for (final estado in <EstadoEntitlement>[
        EstadoEntitlement.emEspera,
        EstadoEntitlement.pausado,
        EstadoEntitlement.pendente,
        EstadoEntitlement.revogado,
        EstadoEntitlement.reembolsado,
        EstadoEntitlement.expirado,
        EstadoEntitlement.desconhecido,
      ]) {
        final painel = PainelBilling(
          compra: EstadoCompra.validada,
          entitlement: entitlement(
            vipAtivo: true,
            estado: estado,
            expiraEm: _agora.add(const Duration(days: 30)),
          ),
        );
        expect(painel.mostrarComoVip(_agora), isFalse, reason: estado.wire);
      }
    });

    test('cancelado vigente CONTINUA VIP ate o fim do periodo pago', () {
      // Cancelar nao e perder na hora: o periodo ja pago vale ate o fim.
      final painel = PainelBilling(
        entitlement: entitlement(
          vipAtivo: true,
          estado: EstadoEntitlement.canceladoVigente,
          expiraEm: _agora.add(const Duration(days: 5)),
        ),
      );
      expect(painel.mostrarComoVip(_agora), isTrue);
    });

    test('e VIP sem nenhuma compra nesta sessao — o caso normal de quem abre o app',
        () {
      final painel = PainelBilling(
        compra: EstadoCompra.ociosa,
        entitlement: entitlement(
          vipAtivo: true,
          estado: EstadoEntitlement.ativo,
          expiraEm: _agora.add(const Duration(days: 30)),
        ),
      );
      expect(painel.mostrarComoVip(_agora), isTrue);
    });
  });
}

/// Uma sessao que muda de valor entre chamadas, como a real muda no login.
class _SessaoVariavel implements SessaoJogador {
  _SessaoVariavel(this._leitura);
  final String? Function() _leitura;

  @override
  String? get uid => _leitura();
}
