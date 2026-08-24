@Timeout(Duration(minutes: 20))
library;

// transporte_ingresso_test.dart — O PEDIDO NO FIO (OS 38.3 §8, §9, §10 e §14).
//
// UMA AFIRMAÇÃO, e ela é o motivo desta OS existir:
//
//   O CLIENTE PEDE UM ASSENTO E ESPERA. Quem senta é o servidor, e o único
//   assento que existe para o aplicativo é o que vem dentro do ACK.
//
// Tudo o que está aqui é código de produção: a `RaizDoAplicativo` de verdade,
// a `SessaoDoJogador` de verdade, a `PonteSessaoOnline` de verdade e o
// `OnlineService` de verdade. Falsas são as quatro pontas do mundo — fluxo de
// autenticação, fonte de identidade, provedor de credencial e canal
// WebSocket. NENHUM CASO ABRE REDE.
//
// POR QUE ISTO PRECISA DE SUÍTE PRÓPRIA, separada da tela: o que se guarda
// aqui é o FIO — o que sai, o que entra, e o que é descartado. Um caso que
// montasse a tela provaria o desenho e deixaria de fora a única pergunta que
// importa quando uma resposta chega atrasada: de quem ela é.

import 'package:flutter_test/flutter_test.dart';

import 'package:buraco_master_vip/ingresso/contrato_ingresso.dart';
import 'package:buraco_master_vip/ingresso/estado_ingresso.dart';
import 'package:buraco_master_vip/ingresso/modelo_ingresso.dart';

import '../casca/bancada_online.dart';
import 'cena_de_ingresso.dart';

void main() {
  // =========================================================================
  group('§8.1 — O QUE SAI NO FIO', () {
    // =======================================================================

    testWidgets('TR-01 o pedido EXPLÍCITO leva o assento escolhido', (
      tester,
    ) async {
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);
      await abrirAplicativo(tester, b);
      await servidorAceita(tester, b);

      final saiu = b.online.solicitarIngresso(
        codigo: 'MESA-AAA',
        apelido: 'Ana',
        assento: 2,
      );
      await tester.pumpAndSettle();

      expect(saiu, isTrue);
      final pedidos = pedidosDeIngresso(b);
      expect(pedidos, hasLength(1));
      expect(pedidos.single['codigo'], 'MESA-AAA');
      expect(pedidos.single['apelido'], 'Ana');
      expect(pedidos.single[ContratoDoIngresso.campoAssento], 2);
      aquietar(b);
    });

    testWidgets('TR-02 o ingresso AUTOMÁTICO OMITE a chave `assento`', (
      tester,
    ) async {
      // `null` explícito NÃO é ausência: o servidor o lê como pedido
      // malformado e responde ASSENTO_INVALIDO. E mandar uma preferência
      // inventada para imitar a ordem dele seria adivinhar a resposta.
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);
      await abrirAplicativo(tester, b);
      await servidorAceita(tester, b);

      b.online.solicitarIngresso(codigo: 'MESA-AAA', apelido: 'Ana');
      await tester.pumpAndSettle();

      final p = pedidosDeIngresso(b).single;
      expect(
        p.containsKey(ContratoDoIngresso.campoAssento),
        isFalse,
        reason: 'a chave não pode existir — nem com valor nulo',
      );
      aquietar(b);
    });

    testWidgets('TR-03 nenhuma mensagem carrega identidade interna', (
      tester,
    ) async {
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);
      await abrirAplicativo(tester, b);
      await servidorAceita(tester, b);

      b.online.solicitarIngresso(
        codigo: 'MESA-AAA',
        apelido: 'Ana',
        assento: 1,
      );
      await tester.pumpAndSettle();

      final p = pedidosDeIngresso(b).single;
      for (final proibido in const [
        'uid',
        'uidAutenticado',
        'jogadorId',
        'admissaoId',
        'tentativaEntradaId',
        'token',
        'credencial',
      ]) {
        expect(
          p.containsKey(proibido),
          isFalse,
          reason:
              'o cliente não diz quem é: a identidade sai do token verificado, '
              'e um `$proibido` no fio seria recusado como divergente',
        );
      }
      expect(p.keys.toSet(), {'tipo', 'codigo', 'apelido', 'assento'});
      aquietar(b);
    });

    testWidgets('TR-04 sem conexão autenticada, NADA sai', (tester) async {
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);
      await abrirAplicativo(tester, b);
      // O servidor ainda NÃO aceitou a credencial.

      final saiu = b.online.solicitarIngresso(
        codigo: 'MESA-AAA',
        apelido: 'Ana',
        assento: 2,
      );
      await tester.pumpAndSettle();

      expect(saiu, isFalse);
      expect(pedidosDeIngresso(b), isEmpty);
      expect(
        b.online.ingresso.fase,
        FaseDoIngresso.ocioso,
        reason: 'sem pedido no fio não há intenção a guardar',
      );
      aquietar(b);
    });

    testWidgets('TR-05 o pedido NÃO fica na fila para quando a conexão voltar', (
      tester,
    ) async {
      // Entre a queda e a volta a mesa pode ter enchido, e a pessoa já não
      // está olhando para aquela tela. Um pedido guardado sentaria alguém
      // numa cadeira que ninguém está pedindo mais.
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);
      await abrirAplicativo(tester, b);

      b.online.solicitarIngresso(
        codigo: 'MESA-AAA',
        apelido: 'Ana',
        assento: 2,
      );
      await servidorAceita(tester, b);
      await tester.pumpAndSettle();

      expect(pedidosDeIngresso(b), isEmpty);
      aquietar(b);
    });

    testWidgets('TR-06 assento fora de 0..3 nem chega a sair', (tester) async {
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);
      await abrirAplicativo(tester, b);
      await servidorAceita(tester, b);

      for (final invalido in const [-1, 4, 99]) {
        expect(
          b.online.solicitarIngresso(
            codigo: 'MESA-AAA',
            apelido: 'Ana',
            assento: invalido,
          ),
          isFalse,
          reason: 'assento $invalido',
        );
      }
      await tester.pumpAndSettle();
      expect(pedidosDeIngresso(b), isEmpty);
      aquietar(b);
    });
  });

  // =========================================================================
  group('§8.2 — O ACK, E SÓ ELE, CONFIRMA', () {
    // =======================================================================

    testWidgets('TR-07 ACK positivo confirma o assento SOLICITADO', (
      tester,
    ) async {
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);
      await abrirAplicativo(tester, b);
      await servidorAceita(tester, b);

      b.online.solicitarIngresso(
        codigo: 'MESA-AAA',
        apelido: 'Ana',
        assento: 2,
      );
      await tester.pumpAndSettle();
      expect(b.online.ingresso.fase, FaseDoIngresso.solicitando);
      expect(
        b.online.ingresso.temConfirmacaoPendente,
        isFalse,
        reason: 'antes do ACK não há ingresso — nem um pouquinho',
      );

      b.canal.servidorEnvia(ackDeIngresso(codigo: 'MESA-AAA', assento: 2));
      await tester.pumpAndSettle();

      final c = b.online.ingresso.consumirConfirmacao();
      expect(c, isNotNull);
      expect(c!.assento, 2);
      expect(c.codigo, 'MESA-AAA');
      // E o transporte adotou a verdade do servidor sobre ESTA conexão.
      expect(b.online.meuAssento, 2);
      expect(b.online.codigo, 'MESA-AAA');
      aquietar(b);
    });

    testWidgets('TR-08 ACK com assento DIFERENTE do pedido não confirma', (
      tester,
    ) async {
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);
      await abrirAplicativo(tester, b);
      await servidorAceita(tester, b);

      b.online.solicitarIngresso(
        codigo: 'MESA-AAA',
        apelido: 'Ana',
        assento: 2,
      );
      await tester.pumpAndSettle();
      b.canal.servidorEnvia(ackDeIngresso(codigo: 'MESA-AAA', assento: 1));
      await tester.pumpAndSettle();

      expect(b.online.ingresso.fase, FaseDoIngresso.recusado);
      expect(b.online.ingresso.temConfirmacaoPendente, isFalse);
      expect(
        b.online.ingresso.recusa!.motivo,
        MotivoDeRecusaDeIngresso.ackForaDoContrato,
      );
      aquietar(b);
    });
  });

  // =========================================================================
  group('§8.3 · §8.4 — RECUSA TIPADA, SEM FALLBACK', () {
    // =======================================================================

    testWidgets('TR-09 ASSENTO_OCUPADO: recusa, e NENHUM segundo pedido', (
      tester,
    ) async {
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);
      await abrirAplicativo(tester, b);
      await servidorAceita(tester, b);

      b.online.solicitarIngresso(
        codigo: 'MESA-AAA',
        apelido: 'Ana',
        assento: 2,
      );
      await tester.pumpAndSettle();
      b.canal.servidorEnvia(recusaAssentoOcupado());
      await tester.pumpAndSettle();

      expect(
        b.online.ingresso.recusa!.motivo,
        MotivoDeRecusaDeIngresso.assentoOcupado,
      );
      expect(b.online.ingresso.temConfirmacaoPendente, isFalse);
      expect(
        pedidosDeIngresso(b),
        hasLength(1),
        reason:
            'não existe "tenta a próxima cadeira": quem pediu um lugar recebe '
            'aquele lugar ou uma recusa, nunca um lugar diferente',
      );
      expect(
        b.online.meuAssento,
        isNull,
        reason: 'a recusa não senta ninguém em lugar nenhum',
      );
      aquietar(b);
    });

    testWidgets('TR-10 ASSENTO_INVALIDO: recusa tipada, sem estado local', (
      tester,
    ) async {
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);
      await abrirAplicativo(tester, b);
      await servidorAceita(tester, b);

      b.online.solicitarIngresso(
        codigo: 'MESA-AAA',
        apelido: 'Ana',
        assento: 0,
      );
      await tester.pumpAndSettle();
      b.canal.servidorEnvia(recusaAssentoInvalido());
      await tester.pumpAndSettle();

      expect(
        b.online.ingresso.recusa!.motivo,
        MotivoDeRecusaDeIngresso.assentoInvalido,
      );
      expect(b.online.meuAssento, isNull);
      expect(b.online.codigo, isNull);
      expect(pedidosDeIngresso(b), hasLength(1));
      aquietar(b);
    });

    testWidgets('TR-11 recusa SEM código também é classificada', (
      tester,
    ) async {
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);
      await abrirAplicativo(tester, b);
      await servidorAceita(tester, b);

      b.online.solicitarIngresso(codigo: 'MESA-AAA', apelido: 'Ana');
      await tester.pumpAndSettle();
      b.canal.servidorEnvia(recusaSemCodigo('mesa cheia'));
      await tester.pumpAndSettle();

      expect(
        b.online.ingresso.recusa!.motivo,
        MotivoDeRecusaDeIngresso.mesaCheia,
      );
      aquietar(b);
    });

    testWidgets('TR-12 um `erro` SEM pedido em voo não vira recusa de ingresso', (
      tester,
    ) async {
      // O `erro` é compartilhado com o resto do protocolo. Roubá-lo faria a
      // recusa de uma jogada aparecer como recusa de assento.
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);
      await abrirAplicativo(tester, b);
      await servidorAceita(tester, b);

      b.canal.servidorEnvia(recusaAssentoOcupado());
      await tester.pumpAndSettle();

      expect(b.online.ingresso.fase, FaseDoIngresso.ocioso);
      expect(b.online.ingresso.recusa, isNull);
      aquietar(b);
    });
  });

  // =========================================================================
  group('§8.5 — CONCORRÊNCIA: um vencedor, e o outro NÃO é realocado', () {
    // =======================================================================

    testWidgets('TR-13 dois clientes pedem a MESMA cadeira', (tester) async {
      final a = Bancada(uidInicial: 'uid-A');
      final c = Bancada(uidInicial: 'uid-C');
      addTearDown(a.fechar);
      addTearDown(c.fechar);

      // DOIS CLIENTES, UM APLICATIVO MONTADO.
      //
      // Montar os dois com `pumpWidget` NÃO funciona, e falha em silêncio: o
      // segundo `pumpWidget` recebe um widget do MESMO tipo, então o Flutter
      // ATUALIZA o elemento que já existe em vez de montar outro — o
      // `initState` do segundo nunca roda, a ponte dele nunca liga, e o caso
      // morre em `canais.last` com "Bad state: No element", parecendo defeito
      // do transporte.
      //
      // O adversário sobe pela porta do transporte, que é a mesma que a ponte
      // usa. O que se mede aqui é o veredito do servidor chegando a dois
      // clientes independentes — e para isso o segundo não precisa de tela.
      await abrirAplicativo(tester, a);
      await servidorAceita(tester, a);
      a.online.solicitarIngresso(
        codigo: 'MESA-AAA',
        apelido: 'Ana',
        assento: 2,
      );
      await tester.pumpAndSettle();

      c.online.conectar();
      await tester.pumpAndSettle();
      await servidorAceita(tester, c);
      // Os dois enxergam a mesma cadeira livre — que é o cenário real: a
      // fotografia da descoberta não conhece reserva.
      expect(
        c.online.solicitarIngresso(
          codigo: 'MESA-AAA',
          apelido: 'Cida',
          assento: 2,
        ),
        isTrue,
        reason: 'o segundo pedido SAI: nada no cliente sabe da disputa',
      );
      await tester.pumpAndSettle();

      // O servidor decide: A sentou, C levou a recusa TIPADA.
      a.canal.servidorEnvia(ackDeIngresso(codigo: 'MESA-AAA', assento: 2));
      c.canal.servidorEnvia(recusaAssentoOcupado());
      await tester.pumpAndSettle();

      expect(a.online.ingresso.temConfirmacaoPendente, isTrue);
      expect(a.online.ingresso.consumirConfirmacao()!.assento, 2);

      expect(c.online.ingresso.temConfirmacaoPendente, isFalse);
      expect(
        c.online.ingresso.recusa!.motivo,
        MotivoDeRecusaDeIngresso.assentoOcupado,
      );
      expect(
        c.online.meuAssento,
        isNull,
        reason: 'o perdedor NÃO é colocado em outra cadeira',
      );
      expect(
        pedidosDeIngresso(c),
        hasLength(1),
        reason: 'e não sai e reentra',
      );
      aquietar(a);
      aquietar(c);
    });
  });

  // =========================================================================
  group('§8.1 · §14 — TOQUE DUPLO, DUPLICATA E FORA DE ORDEM', () {
    // =======================================================================

    testWidgets('TR-14 TOQUE DUPLO manda UM pedido', (tester) async {
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);
      await abrirAplicativo(tester, b);
      await servidorAceita(tester, b);

      expect(
        b.online.solicitarIngresso(
          codigo: 'MESA-AAA',
          apelido: 'Ana',
          assento: 2,
        ),
        isTrue,
      );
      expect(
        b.online.solicitarIngresso(
          codigo: 'MESA-AAA',
          apelido: 'Ana',
          assento: 2,
        ),
        isFalse,
      );
      expect(
        b.online.solicitarIngresso(
          codigo: 'MESA-AAA',
          apelido: 'Ana',
          assento: 3,
        ),
        isFalse,
        reason: 'nem para outra cadeira: uma intenção ativa por vez',
      );
      await tester.pumpAndSettle();

      expect(pedidosDeIngresso(b), hasLength(1));
      expect(b.online.ingresso.pedidosAutorizados, 1);
      aquietar(b);
    });

    testWidgets('TR-15 ACK DUPLICADO confirma uma vez só', (tester) async {
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);
      await abrirAplicativo(tester, b);
      await servidorAceita(tester, b);

      b.online.solicitarIngresso(
        codigo: 'MESA-AAA',
        apelido: 'Ana',
        assento: 2,
      );
      await tester.pumpAndSettle();
      b.canal.servidorEnvia(ackDeIngresso(codigo: 'MESA-AAA', assento: 2));
      b.canal.servidorEnvia(ackDeIngresso(codigo: 'MESA-AAA', assento: 2));
      await tester.pumpAndSettle();

      expect(b.online.ingresso.consumirConfirmacao(), isNotNull);
      expect(
        b.online.ingresso.consumirConfirmacao(),
        isNull,
        reason: 'consumir entrega UMA vez — é o que faz navegar uma vez',
      );
      aquietar(b);
    });

    testWidgets('TR-16 recusa FORA DE ORDEM depois do ACK não desfaz', (
      tester,
    ) async {
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);
      await abrirAplicativo(tester, b);
      await servidorAceita(tester, b);

      b.online.solicitarIngresso(
        codigo: 'MESA-AAA',
        apelido: 'Ana',
        assento: 2,
      );
      await tester.pumpAndSettle();
      b.canal.servidorEnvia(ackDeIngresso(codigo: 'MESA-AAA', assento: 2));
      b.canal.servidorEnvia(recusaAssentoOcupado());
      await tester.pumpAndSettle();

      expect(b.online.ingresso.fase, FaseDoIngresso.confirmado);
      expect(b.online.ingresso.recusa, isNull);
      aquietar(b);
    });

    testWidgets('TR-17 ACK de OUTRA mesa não responde a este pedido', (
      tester,
    ) async {
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);
      await abrirAplicativo(tester, b);
      await servidorAceita(tester, b);

      b.online.solicitarIngresso(
        codigo: 'MESA-AAA',
        apelido: 'Ana',
        assento: 2,
      );
      await tester.pumpAndSettle();
      b.canal.servidorEnvia(ackDeIngresso(codigo: 'MESA-BBB', assento: 2));
      await tester.pumpAndSettle();

      expect(b.online.ingresso.temConfirmacaoPendente, isFalse);
      expect(b.online.ingresso.fase, FaseDoIngresso.solicitando);
      aquietar(b);
    });
  });

  // =========================================================================
  group('§10 — RECONEXÃO E PROPRIEDADE DO ASSENTO', () {
    // =======================================================================

    testWidgets('TR-18 a reentrada automática NÃO manda preferência', (
      tester,
    ) async {
      // Depois de entrar, o servidor é a autoridade absoluta sobre a
      // propriedade do assento. Reenviar preferência aqui seria pedir para
      // trocar de cadeira — operação que este servidor não tem.
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);
      await abrirAplicativo(tester, b);
      await servidorAceita(tester, b);

      b.online.solicitarIngresso(
        codigo: 'MESA-AAA',
        apelido: 'Ana',
        assento: 2,
      );
      await tester.pumpAndSettle();
      b.canal.servidorEnvia(ackDeIngresso(codigo: 'MESA-AAA', assento: 2));
      await tester.pumpAndSettle();
      b.online.ingresso.consumirConfirmacao();

      // A conexão cai e volta. O backoff da primeira tentativa é de até
      // 500 ms (metade fixa, metade sorteada), então alguns quadros de um
      // segundo cobrem a espera com folga — e sem depender do sorteio.
      final canalVelho = b.canal;
      canalVelho.servidorDerruba();
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      await tester.pumpAndSettle();
      expect(b.canais.length, greaterThan(1));
      await servidorAceita(tester, b);

      final reentradas = pedidosDeIngresso(b);
      expect(reentradas, isNotEmpty, reason: 'a reentrada tem de acontecer');
      final ultima = reentradas.last;
      expect(ultima['codigo'], 'MESA-AAA');
      expect(
        ultima.containsKey(ContratoDoIngresso.campoAssento),
        isFalse,
        reason: 'o titular volta para o assento DELE; ele não escolhe outro',
      );
      aquietar(b);
    });

    testWidgets('TR-19 a RECONEXÃO pode confirmar um assento diferente', (
      tester,
    ) async {
      // É o ÚNICO caso em que confirmado != solicitado é legítimo — e o
      // servidor o ANUNCIA com `reconexao: true`. Recusá-lo impediria alguém
      // de voltar para a própria cadeira.
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);
      await abrirAplicativo(tester, b);
      await servidorAceita(tester, b);

      b.online.solicitarIngresso(
        codigo: 'MESA-AAA',
        apelido: 'Ana',
        assento: 3,
      );
      await tester.pumpAndSettle();
      b.canal.servidorEnvia(
        ackDeIngresso(codigo: 'MESA-AAA', assento: 0, reconexao: true),
      );
      await tester.pumpAndSettle();

      final c = b.online.ingresso.consumirConfirmacao();
      expect(c, isNotNull);
      expect(c!.assento, 0);
      expect(c.reconexao, isTrue);
      aquietar(b);
    });

    testWidgets('TR-20a a QUEDA do socket mata o pedido em voo', (
      tester,
    ) async {
      // A queda NÃO sobe a geração do transporte — a reconexão reaproveita
      // a mesma —, então o crachá sozinho não cobriria este caso. Sem a
      // defesa, o seletor ficaria em "pedindo" para sempre.
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);
      await abrirAplicativo(tester, b);
      await servidorAceita(tester, b);

      b.online.solicitarIngresso(
        codigo: 'MESA-AAA',
        apelido: 'Ana',
        assento: 2,
      );
      await tester.pumpAndSettle();
      expect(b.online.ingresso.fase, FaseDoIngresso.solicitando);

      b.canal.servidorDerruba();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 10));

      expect(
        b.online.ingresso.fase,
        FaseDoIngresso.ocioso,
        reason: 'a resposta não vem mais pelo socket que levou o pedido',
      );
      expect(b.online.ingresso.temConfirmacaoPendente, isFalse);
      aquietar(b);
    });

    testWidgets('TR-20 a queda da conexão MATA o pedido em voo', (
      tester,
    ) async {
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);
      await abrirAplicativo(tester, b);
      await servidorAceita(tester, b);

      b.online.solicitarIngresso(
        codigo: 'MESA-AAA',
        apelido: 'Ana',
        assento: 2,
      );
      await tester.pumpAndSettle();
      expect(b.online.ingresso.fase, FaseDoIngresso.solicitando);

      b.online.desligar();
      await tester.pumpAndSettle();

      expect(
        b.online.ingresso.fase,
        FaseDoIngresso.ocioso,
        reason:
            'a resposta não vem mais por este canal, e a tela travada em '
            '"entrando" para sempre seria pior que a recusa',
      );
      expect(b.online.ingresso.temConfirmacaoPendente, isFalse);
    });
  });

  // =========================================================================
  group('§14 — TROCA DE CONTA: A NÃO ATRAVESSA PARA B', () {
    // =======================================================================

    testWidgets('TR-21 a resposta ATRASADA de A não senta B', (tester) async {
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);
      await abrirAplicativo(tester, b);
      await servidorAceita(tester, b);

      b.online.solicitarIngresso(
        codigo: 'MESA-DE-A',
        apelido: 'Ana',
        assento: 2,
      );
      await tester.pumpAndSettle();
      final canalDeA = b.canal;

      // A pessoa troca de conta.
      b.fluxo.add('uid-B');
      await tester.pumpAndSettle();
      expect(canalDeA.fechado, isTrue);
      expect(b.online.ingresso.fase, FaseDoIngresso.ocioso);

      // E o ACK de A chega pelo canal velho.
      canalDeA.servidorEnvia(ackDeIngresso(codigo: 'MESA-DE-A', assento: 2));
      await tester.pumpAndSettle();

      expect(
        b.online.ingresso.temConfirmacaoPendente,
        isFalse,
        reason: 'a conta B não herda o assento que a conta A conquistou',
      );
      expect(b.online.ingresso.consumirConfirmacao(), isNull);
      expect(b.online.meuAssento, isNull);
      aquietar(b);
    });

    testWidgets('TR-22 a CONFIRMAÇÃO de A não sobrevive à troca', (
      tester,
    ) async {
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);
      await abrirAplicativo(tester, b);
      await servidorAceita(tester, b);

      b.online.solicitarIngresso(
        codigo: 'MESA-DE-A',
        apelido: 'Ana',
        assento: 2,
      );
      await tester.pumpAndSettle();
      b.canal.servidorEnvia(ackDeIngresso(codigo: 'MESA-DE-A', assento: 2));
      await tester.pumpAndSettle();
      expect(
        b.online.ingresso.temConfirmacaoPendente,
        isTrue,
        reason: 'A conquistou o lugar, e ainda não consumiu a confirmação',
      );

      b.fluxo.add('uid-B');
      await tester.pumpAndSettle();

      expect(b.online.ingresso.temConfirmacaoPendente, isFalse);
      expect(b.online.ingresso.consumirConfirmacao(), isNull);
      aquietar(b);
    });
  });
}
