// porta_de_comandos_online_test.dart — o gesto vira comando, uma vez só.
//
// O `OnlineService` é o de produção; falso é só o canal WebSocket. Assim as
// mensagens que os casos inspecionam são as que sairiam pelo fio de verdade,
// com os nomes de campo do servidor.
//
// O que se prova, em ordem:
//
//   1. cada gesto sai no formato que o servidor entende;
//   2. duas tentativas iguais (ou diferentes) não viram duas mensagens;
//   3. a trava sai por AUTORIDADE — visão nova, recusa, ou queda —, nunca por
//      otimismo;
//   4. recusa de regra, de credencial e de transporte são coisas distintas;
//   5. nada é aplicado localmente, em caso nenhum.

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:buraco_master_vip/casca/mesa_online/porta_de_comandos_online.dart';
import 'package:buraco_master_vip/services/online_service.dart';

import 'bancada_online.dart';

/// Um `OnlineService` de produção, com canal falso, já autenticado e sentado.
class _Mesa {
  _Mesa(this.canal, this.online, this.porta);

  final CanalFalso canal;
  final OnlineService online;
  final PortaDeComandosOnline porta;

  void servidorMandaVisao([Map<String, dynamic>? v]) =>
      canal.servidorEnvia({'tipo': 'estado', 'visao': v ?? visaoDeJogo()});

  void servidorRecusa(String motivo, {String? codigo}) => canal.servidorEnvia({
    'tipo': 'erro',
    'motivo': motivo,
    if (codigo != null) 'codigo': codigo,
  });

  void fechar() {
    porta.dispose();
    online.dispose();
  }
}

/// Monta a mesa dentro de um [FakeAsync] e roda [corpo].
///
/// O `FakeAsync` é necessário porque o `OnlineService` arma relógios reais
/// (limite de autenticação, backoff) e a porta arma o teto de espera. Com
/// tempo de mentira, os casos são determinísticos e a suíte não dorme.
void comMesa(void Function(_Mesa m, FakeAsync a) corpo) {
  fakeAsync((a) {
    final canal = CanalFalso();
    final online = OnlineService(
      obterIdToken: () async => 'token-de-teste',
      abrirCanal: (_) => canal,
      endpoint: Uri.parse(kEndpointDeTeste),
    );
    final porta = PortaDeComandosOnline(online);
    final m = _Mesa(canal, online, porta);

    online.conectar();
    a.flushMicrotasks();
    canal.servidorEnvia({'tipo': 'autenticado'});
    a.flushMicrotasks();
    canal.servidorEnvia({
      'tipo': 'entrou',
      'codigo': 'BURACO-0001',
      'assento': 0,
    });
    a.flushMicrotasks();
    expect(online.status, OnlineStatus.conectado);

    try {
      corpo(m, a);
    } finally {
      m.fechar();
      a.flushTimers();
    }
  });
}

void main() {
  // =========================================================================
  // 1 — o formato do fio
  // =========================================================================
  group('o gesto vira o comando do protocolo', () {
    test('comprar do monte', () {
      comMesa((m, a) {
        expect(m.porta.comprarDoMonte(), isTrue);
        a.flushMicrotasks();
        expect(m.canal.jogadas, [
          {'tipo': 'comprarMonte'},
        ]);
      });
    });

    test('comprar o lixo', () {
      comMesa((m, a) {
        m.porta.comprarDoLixo();
        a.flushMicrotasks();
        expect(m.canal.jogadas.single['tipo'], 'comprarLixo');
      });
    });

    test('descartar leva o id da carta', () {
      comMesa((m, a) {
        m.porta.descartar('c3');
        a.flushMicrotasks();
        expect(m.canal.jogadas.single, {'tipo': 'descartar', 'id': 'c3'});
      });
    });

    test('baixar leva a lista de ids', () {
      comMesa((m, a) {
        m.porta.baixar(['c1', 'c2', 'c9']);
        a.flushMicrotasks();
        expect(m.canal.jogadas.single, {
          'tipo': 'baixar',
          'ids': ['c1', 'c2', 'c9'],
        });
      });
    });

    test('estender leva o índice do jogo e os ids', () {
      comMesa((m, a) {
        m.porta.estender(1, ['c4']);
        a.flushMicrotasks();
        expect(m.canal.jogadas.single, {
          'tipo': 'estender',
          'indiceJogo': 1,
          'ids': ['c4'],
        });
      });
    });

    test('baixar e estender vazios nem saem', () {
      comMesa((m, a) {
        expect(m.porta.baixar(const []), isFalse);
        expect(m.porta.estender(0, const []), isFalse);
        a.flushMicrotasks();
        expect(m.canal.jogadas, isEmpty);
      });
    });

    test('sair da mesa não é logout', () {
      comMesa((m, a) {
        m.porta.sairDaMesa();
        a.flushMicrotasks();
        expect(m.canal.doTipo('sair'), hasLength(1));
        expect(
          m.online.status,
          OnlineStatus.conectado,
          reason: 'a conexão e a conta continuam de pé',
        );
      });
    });
  });

  // =========================================================================
  // 2 — o duplo toque
  // =========================================================================
  group('duplo toque', () {
    test('dois toques iguais viram UMA mensagem', () {
      comMesa((m, a) {
        expect(m.porta.comprarDoMonte(), isTrue);
        expect(m.porta.comprarDoMonte(), isFalse);
        expect(m.porta.comprarDoMonte(), isFalse);
        a.flushMicrotasks();
        expect(m.canal.jogadas, hasLength(1));
        expect(m.porta.ultimaRecusa, MotivoDaRecusa.jaTemIntencaoPendente);
      });
    });

    test('a trava vale para intenções DIFERENTES também', () {
      comMesa((m, a) {
        // "comprar" e depois "descartar" antes de o servidor responder à compra
        // é uma dupla que também não pode acontecer.
        expect(m.porta.comprarDoMonte(), isTrue);
        expect(m.porta.descartar('c1'), isFalse);
        a.flushMicrotasks();
        expect(m.canal.jogadas, hasLength(1));
        expect(m.canal.jogadas.single['tipo'], 'comprarMonte');
      });
    });

    test('a intenção pendente é identificável pela tela', () {
      comMesa((m, a) {
        m.porta.descartar('c3');
        expect(m.porta.temIntencaoPendente, isTrue);
        expect(m.porta.pendente!.chave, 'descartar:c3');
        expect(m.porta.pendente!.rotulo, isNotEmpty);
        expect(m.porta.aceitaComando, isFalse);
        a.flushMicrotasks();
      });
    });

    test('sair passa por cima da trava — é a saída de emergência', () {
      comMesa((m, a) {
        m.porta.comprarDoMonte();
        expect(m.porta.temIntencaoPendente, isTrue);
        m.porta.sairDaMesa();
        a.flushMicrotasks();
        expect(m.canal.doTipo('sair'), hasLength(1));
        expect(m.porta.temIntencaoPendente, isFalse);
      });
    });
  });

  // =========================================================================
  // 3 — a trava sai por autoridade
  // =========================================================================
  group('a trava só sai por autoridade', () {
    test('visão nova libera a próxima intenção', () {
      comMesa((m, a) {
        m.porta.comprarDoMonte();
        a.flushMicrotasks();
        expect(m.porta.temIntencaoPendente, isTrue);

        m.servidorMandaVisao(visaoDeJogo(jaComprou: true));
        a.flushMicrotasks();

        expect(m.porta.temIntencaoPendente, isFalse);
        expect(m.porta.aceitaComando, isTrue);
        expect(m.porta.ultimaRecusa, isNull);

        expect(m.porta.descartar('c1'), isTrue);
        a.flushMicrotasks();
        expect(m.canal.jogadas, hasLength(2));
      });
    });

    test('recusa do servidor libera, e o motivo fica na tela', () {
      comMesa((m, a) {
        m.porta.descartar('c1');
        a.flushMicrotasks();

        m.servidorRecusa('não é a sua vez');
        a.flushMicrotasks();

        expect(m.porta.temIntencaoPendente, isFalse);
        expect(m.porta.ultimaRecusa, MotivoDaRecusa.regra);
        expect(m.porta.mensagemDaRecusa, 'não é a sua vez');
      });
    });

    test('o teto de espera destrava sem aplicar nada', () {
      comMesa((m, a) {
        m.porta.comprarDoMonte();
        a.flushMicrotasks();
        expect(m.porta.temIntencaoPendente, isTrue);

        // Meio caminho: continua esperando.
        a.elapse(const Duration(seconds: 6));
        expect(m.porta.temIntencaoPendente, isTrue);

        a.elapse(const Duration(seconds: 7));
        expect(m.porta.temIntencaoPendente, isFalse);
        expect(m.porta.ultimaRecusa, MotivoDaRecusa.semResposta);
        // E nenhuma mensagem a mais saiu: destravar não é reenviar.
        expect(m.canal.jogadas, hasLength(1));
      });
    });

    test('a queda da conexão destrava e não reenvia', () {
      comMesa((m, a) {
        m.porta.comprarDoMonte();
        a.flushMicrotasks();

        m.canal.servidorDerruba();
        a.flushMicrotasks();

        expect(m.porta.temIntencaoPendente, isFalse);
        expect(m.porta.ultimaRecusa, MotivoDaRecusa.transporte);
        expect(
          m.canal.jogadas,
          hasLength(1),
          reason: 'o que aconteceu com a jogada em voo, só o servidor sabe',
        );
      });
    });

    test('sem conexão autenticada o comando nem sai', () {
      fakeAsync((a) {
        final canal = CanalFalso();
        final online = OnlineService(
          obterIdToken: () async => 'token-de-teste',
          abrirCanal: (_) => canal,
          endpoint: Uri.parse(kEndpointDeTeste),
        );
        final porta = PortaDeComandosOnline(online);
        addTearDown(porta.dispose);
        addTearDown(online.dispose);

        // Nunca conectou.
        expect(porta.aceitaComando, isFalse);
        expect(porta.comprarDoMonte(), isFalse);
        expect(porta.ultimaRecusa, MotivoDaRecusa.transporte);
        expect(canal.jogadas, isEmpty);

        online.desligar();
        a.flushTimers();
      });
    });
  });

  // =========================================================================
  // 4 — a natureza da recusa
  // =========================================================================
  group('classificação da recusa', () {
    test('recusa sem código é regra do Buraco', () {
      comMesa((m, a) {
        m.porta.descartar('c1');
        a.flushMicrotasks();
        m.servidorRecusa('essa carta não tem mola');
        a.flushMicrotasks();
        expect(m.porta.ultimaRecusa, MotivoDaRecusa.regra);
      });
    });

    test('credencial expirada não é recusa de regra', () {
      comMesa((m, a) {
        m.porta.descartar('c1');
        a.flushMicrotasks();
        m.servidorRecusa(
          'credencial expirada',
          codigo: 'CREDENCIAL_EXPIRADA',
        );
        a.flushMicrotasks();
        expect(m.porta.ultimaRecusa, MotivoDaRecusa.autenticacao);
      });
    });

    test('identidade divergente também é autenticação', () {
      comMesa((m, a) {
        m.porta.descartar('c1');
        a.flushMicrotasks();
        m.servidorRecusa(
          'identidade divergente',
          codigo: 'IDENTIDADE_DIVERGENTE',
        );
        a.flushMicrotasks();
        expect(m.porta.ultimaRecusa, MotivoDaRecusa.autenticacao);
      });
    });

    test('o código de uma recusa não contamina a seguinte', () {
      comMesa((m, a) {
        m.porta.descartar('c1');
        a.flushMicrotasks();
        m.servidorRecusa('credencial expirada', codigo: 'CREDENCIAL_EXPIRADA');
        a.flushMicrotasks();
        expect(m.porta.ultimaRecusa, MotivoDaRecusa.autenticacao);

        // A conexão se recupera e uma recusa de REGRA chega — sem código,
        // porque o motor não manda um.
        m.canal.servidorEnvia({'tipo': 'autenticado'});
        a.flushMicrotasks();
        m.porta.descartar('c2');
        a.flushMicrotasks();
        m.servidorRecusa('não é a sua vez');
        a.flushMicrotasks();

        expect(
          m.porta.ultimaRecusa,
          MotivoDaRecusa.regra,
          reason:
              'herdar o código anterior faria "sua jogada não vale" virar '
              '"sua credencial venceu", e travaria a pessoa numa mesa boa',
        );
      });
    });

    test('dispensar a recusa limpa o aviso e não reenvia nada', () {
      comMesa((m, a) {
        m.porta.descartar('c1');
        a.flushMicrotasks();
        m.servidorRecusa('não é a sua vez');
        a.flushMicrotasks();
        expect(m.porta.ultimaRecusa, isNotNull);

        m.porta.dispensarRecusa();
        expect(m.porta.ultimaRecusa, isNull);
        expect(m.porta.mensagemDaRecusa, isNull);
        expect(m.canal.jogadas, hasLength(1));
      });
    });
  });

  // =========================================================================
  // 5 — a porta não guarda partida
  // =========================================================================
  group('nenhuma mutação local', () {
    test('a visão do transporte é a mesma antes e depois de um comando', () {
      comMesa((m, a) {
        m.servidorMandaVisao();
        a.flushMicrotasks();
        final antes = m.online.visao;

        m.porta.descartar('c1');
        a.flushMicrotasks();

        expect(
          identical(m.online.visao, antes),
          isTrue,
          reason:
              'a mesa só muda quando chega visão nova; a porta não tira carta '
              'da mão nem "corrige" depois',
        );
      });
    });

    test('a recusa preserva o estado autoritativo', () {
      comMesa((m, a) {
        m.servidorMandaVisao(visaoDeJogo(jaComprou: true));
        a.flushMicrotasks();
        final autoritativo = m.online.visao;

        m.porta.descartar('c1');
        a.flushMicrotasks();
        m.servidorRecusa('essa carta não tem mola');
        a.flushMicrotasks();

        expect(identical(m.online.visao, autoritativo), isTrue);
        expect(m.online.visao!['jaComprou'], isTrue);
      });
    });

    test('a mesma visão entregue duas vezes não acumula nada', () {
      comMesa((m, a) {
        final v = visaoDeJogo();
        m.servidorMandaVisao(v);
        a.flushMicrotasks();
        m.servidorMandaVisao(v);
        a.flushMicrotasks();

        // Sem `eventoId` no protocolo, a garantia possível é esta: reprocessar
        // o mesmo retrato produz o mesmo estado, e não uma mão com seis cartas.
        expect((m.online.visao!['suaMao'] as List), hasLength(3));
        expect(m.porta.temIntencaoPendente, isFalse);
      });
    });
  });
}
