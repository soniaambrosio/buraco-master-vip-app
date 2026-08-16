// boas_vindas_test.dart — o lado do CLIENTE do bônus de boas-vindas.
//
// O que esta suíte prova é estreito de propósito, porque o lado do cliente é
// estreito de propósito: que ele PEDE, que não guarda "já recebi" em lugar
// nenhum, e que uma falha de rede não é confundida com "já recebeu".
//
// A garantia que importa — +100 uma vez por conta, sob retry e sob concorrência
// — é do servidor, e está provada em `functions-economia/test/carteira.test.js`
// contra um Firestore com contenção otimista. Nada aqui pode substituir aquilo,
// e um teste de cliente que fingisse provar isso seria pior que nenhum.

import 'package:flutter_test/flutter_test.dart';

import 'package:buraco_master_vip/economia/bonus_boas_vindas.dart';

/// Porta de mentira que conta quantas vezes foi chamada.
class PortaEspia implements PortaBoasVindas {
  PortaEspia(this._respostas);

  final List<ResultadoBoasVindas> _respostas;
  int chamadas = 0;

  @override
  Future<ResultadoBoasVindas> garantir() async {
    final i = chamadas < _respostas.length ? chamadas : _respostas.length - 1;
    chamadas += 1;
    return _respostas[i];
  }
}

/// Porta que estoura em vez de devolver resultado.
class PortaQueEstoura implements PortaBoasVindas {
  int chamadas = 0;

  @override
  Future<ResultadoBoasVindas> garantir() async {
    chamadas += 1;
    throw StateError('plugin fora do ar');
  }
}

void main() {
  const concedido = ResultadoBoasVindas(concedido: true, valor: 100);
  const jaTinha = ResultadoBoasVindas(concedido: false, valor: 100);

  group('ResultadoBoasVindas', () {
    test('BV-01 concessão bem-sucedida não é falha', () {
      expect(concedido.falhou, isFalse);
      expect(concedido.valor, 100);
    });

    test('BV-02 "já recebeu" é resposta, e não falha', () {
      // A distinção existe porque só uma das duas merece nova tentativa: o
      // servidor dizendo "já foi" é definitivo; a rede fora, não.
      expect(jaTinha.falhou, isFalse);
      expect(jaTinha.concedido, isFalse);
    });

    test('BV-03 indisponível é falha, e não concede nada', () {
      const r = ResultadoBoasVindas.indisponivel('rede fora');
      expect(r.falhou, isTrue);
      expect(r.concedido, isFalse);
      expect(r.erro, 'rede fora');
    });
  });

  group('GarantiaDeBoasVindas', () {
    test('BV-10 pede ao servidor na primeira chamada', () async {
      final porta = PortaEspia([concedido]);
      final garantia = GarantiaDeBoasVindas(porta);

      final r = await garantia.garantir();

      expect(r.concedido, isTrue);
      expect(porta.chamadas, 1);
    });

    test('BV-11 não repete a chamada dentro da mesma sessão', () async {
      // Dedução de CHAMADA, não de crédito: existe só para a tela não disparar
      // cinco requisições iguais ao reconstruir.
      final porta = PortaEspia([concedido]);
      final garantia = GarantiaDeBoasVindas(porta);

      await garantia.garantir();
      await garantia.garantir();
      await garantia.garantir();

      expect(porta.chamadas, 1);
    });

    test('BV-12 chamadas simultâneas compartilham a mesma requisição', () async {
      final porta = PortaEspia([concedido]);
      final garantia = GarantiaDeBoasVindas(porta);

      final r = await Future.wait([
        garantia.garantir(),
        garantia.garantir(),
        garantia.garantir(),
      ]);

      expect(porta.chamadas, 1);
      expect(r.every((x) => x.concedido), isTrue);
    });

    test('BV-13 FALHA não é memorizada: a próxima chamada tenta de novo', () async {
      // Se a falha fosse tratada como resposta, uma queda de rede na abertura
      // deixaria o jogador sem as 100 fichas dele por toda a sessão.
      final porta = PortaEspia([
        const ResultadoBoasVindas.indisponivel('rede fora'),
        concedido,
      ]);
      final garantia = GarantiaDeBoasVindas(porta);

      final primeira = await garantia.garantir();
      final segunda = await garantia.garantir();

      expect(primeira.falhou, isTrue);
      expect(segunda.concedido, isTrue);
      expect(porta.chamadas, 2);
    });

    test('BV-14 "já recebeu" É memorizado — é resposta definitiva', () async {
      final porta = PortaEspia([jaTinha]);
      final garantia = GarantiaDeBoasVindas(porta);

      await garantia.garantir();
      await garantia.garantir();

      expect(porta.chamadas, 1);
      expect(garantia.ultimo, isNotNull);
      expect(garantia.ultimo!.concedido, isFalse);
    });

    test('BV-15 porta que estoura não trava as tentativas seguintes', () async {
      final porta = PortaQueEstoura();
      final garantia = GarantiaDeBoasVindas(porta);

      final primeira = await garantia.garantir();
      final segunda = await garantia.garantir();

      expect(primeira.falhou, isTrue);
      expect(segunda.falhou, isTrue);
      // O `_emVoo` precisa ter sido liberado: sem isso, a segunda chamada
      // ficaria presa na Future morta da primeira.
      expect(porta.chamadas, 2);
    });

    test('BV-16 nada é lembrado entre sessões — o objeto novo pergunta de novo', () async {
      // Nenhum estado vai para disco. Reinstalação, backup restaurado e troca de
      // aparelho caem todos aqui: o app pergunta, e o servidor é quem sabe.
      final porta = PortaEspia([concedido, jaTinha]);

      await GarantiaDeBoasVindas(porta).garantir();
      final outraSessao = await GarantiaDeBoasVindas(porta).garantir();

      expect(porta.chamadas, 2);
      // E a segunda sessão não recebe outro bônus: quem decide é o servidor.
      expect(outraSessao.concedido, isFalse);
    });

    test('BV-17 o cliente não tem por onde escolher o valor', () async {
      // A porta não recebe parâmetro nenhum: `garantir()` não tem assinatura por
      // onde passar valor, saldo ou um booleano dizendo "ainda não recebi". O
      // valor exibido é o que o servidor respondeu.
      final porta = PortaEspia([const ResultadoBoasVindas(concedido: true, valor: 100)]);
      final r = await GarantiaDeBoasVindas(porta).garantir();

      expect(r.valor, 100);
    });
  });
}
