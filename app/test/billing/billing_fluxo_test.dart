// billing_fluxo_test.dart — decisao do cliente sobre o veredito do backend.
//
// Dart puro: `billing_validacao.dart` nao importa Firebase de proposito
// (a implementacao concreta vive em `billing_validacao_firebase.dart`), entao
// esta suite roda sem plugin, sem rede e sem emulador.
//
// O que esta sendo protegido aqui e uma invariante que custa dinheiro dos dois
// lados: finalizar uma compra que nao foi validada faz a Play Store parar de
// reentrega-la, e o jogador que pagou fica sem receber; nao finalizar uma
// compra recusada faz a Play reentregar para sempre.

import 'package:buraco_master_vip/services/billing_validacao.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('decidirDestinoDaCompra', () {
    test('compra aprovada é concedida', () {
      const r = ResultadoValidacao(aprovada: true);
      expect(decidirDestinoDaCompra(r), DestinoDaCompra.conceder);
    });

    test('reentrega de compra já processada também é concedida', () {
      // Caminho normal de reentrega da Play Store: o backend reconhece o token,
      // NAO credita de novo, e devolve `jaProcessada`. Para o app isso e
      // sucesso — so limpa a pendencia.
      const r = ResultadoValidacao(
        aprovada: false,
        jaProcessada: true,
        detalhes: <String, dynamic>{'fichasCreditadas': 1000},
      );
      expect(decidirDestinoDaCompra(r), DestinoDaCompra.conceder);
    });

    test('falha temporária é adiada, nunca recusada', () {
      const r = ResultadoValidacao.indisponivel('rede fora');
      expect(decidirDestinoDaCompra(r), DestinoDaCompra.adiar);
    });

    test('recusa definitiva do backend é recusa', () {
      const r = ResultadoValidacao.recusada('purchaseState 1');
      expect(decidirDestinoDaCompra(r), DestinoDaCompra.recusar);
    });

    test('recusa tem precedência sobre repetível quando ambos são falsos', () {
      const r = ResultadoValidacao(aprovada: false);
      expect(decidirDestinoDaCompra(r), DestinoDaCompra.recusar);
    });
  });

  group('deveFinalizarCompra', () {
    test('só "adiar" mantém a compra pendente para reentrega', () {
      expect(deveFinalizarCompra(DestinoDaCompra.adiar), isFalse);
      expect(deveFinalizarCompra(DestinoDaCompra.conceder), isTrue);
      expect(deveFinalizarCompra(DestinoDaCompra.recusar), isTrue);
    });

    test('nenhuma falha temporária é finalizada — varre todos os destinos', () {
      // Trava contra um destino novo entrar no enum sem alguem decidir se ele
      // finaliza ou nao.
      for (final destino in DestinoDaCompra.values) {
        final finaliza = deveFinalizarCompra(destino);
        expect(
          finaliza,
          destino != DestinoDaCompra.adiar,
          reason: 'destino $destino sem regra de finalizacao definida',
        );
      }
    });
  });

  group('reentrega do mesmo token não gera crédito duplo no cliente', () {
    test('validar duas vezes produz duas decisões de conceder, sem creditar', () {
      // O cliente NAO credita: o valor concedido vem sempre do backend, dentro
      // de `detalhes`. Duas entregas do mesmo token produzem duas decisoes de
      // `conceder`, mas o total creditado e o que o backend informou UMA vez —
      // na segunda ele responde `jaProcessada` repetindo a mesma concessao.
      const primeira = ResultadoValidacao(
        aprovada: true,
        detalhes: <String, dynamic>{'fichasCreditadas': 1000},
      );
      const reentrega = ResultadoValidacao(
        aprovada: false,
        jaProcessada: true,
        detalhes: <String, dynamic>{'fichasCreditadas': 1000},
      );

      expect(decidirDestinoDaCompra(primeira), DestinoDaCompra.conceder);
      expect(decidirDestinoDaCompra(reentrega), DestinoDaCompra.conceder);

      // A reentrega e explicitamente marcada como ja processada — e isso que
      // permite a UI avisar "voce ja tem isso" em vez de "creditamos de novo".
      expect(primeira.jaProcessada, isFalse);
      expect(reentrega.jaProcessada, isTrue);
      expect(reentrega.detalhes['fichasCreditadas'], primeira.detalhes['fichasCreditadas']);
    });

    test('compra adiada e depois aprovada finaliza só na aprovação', () {
      const tentativa1 = ResultadoValidacao.indisponivel('timeout');
      const tentativa2 = ResultadoValidacao(aprovada: true);

      expect(deveFinalizarCompra(decidirDestinoDaCompra(tentativa1)), isFalse);
      expect(deveFinalizarCompra(decidirDestinoDaCompra(tentativa2)), isTrue);
    });
  });

  group('CompraParaValidar', () {
    test('payload não inventa orderId quando a Play não informou', () {
      const c = CompraParaValidar(
        produtoId: 'master_vip',
        tokenCompra: 'token-abc',
        assinatura: true,
      );
      final payload = c.paraPayload();
      expect(payload.containsKey('orderId'), isFalse);
      expect(payload['produtoId'], 'master_vip');
      expect(payload['tokenCompra'], 'token-abc');
      expect(payload['assinatura'], isTrue);
    });

    test('payload não carrega uid — o backend obtém a identidade do Auth', () {
      // uid mandado pelo cliente seria falsificavel. O callable ja leva o token
      // do Firebase Auth verificado.
      const c = CompraParaValidar(
        produtoId: 'pacote_fichas',
        tokenCompra: 'token-xyz',
        assinatura: false,
        orderId: 'GPA.1234',
      );
      final payload = c.paraPayload();
      expect(payload.containsKey('uid'), isFalse);
      expect(payload['orderId'], 'GPA.1234');
    });
  });
}
