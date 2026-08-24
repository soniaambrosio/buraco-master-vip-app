// contrato_e_estado_test.dart — o VOCABULÁRIO do ingresso e a MÁQUINA da
// intenção (OS 38.3 §15.3, §16 e §17).
//
// TRÊS TRABALHOS, e os três existem porque revisão de código não os garante:
//
// 1. O CONTRATO NÃO DERIVOU. `contrato/ingresso-assento-v1.json` foi lido do
//    servidor congelado `8a0ee4b`, e o digest dele é afirmado aqui. Diferente
//    do contrato da descoberta, este NÃO tem gêmeo no servidor — a OS proíbe
//    tocar nele —, então a amarra que existe é a proveniência mais o digest, e
//    o caso CT-04 cobra que o SHA declarado seja exatamente o exigido.
//
// 2. A MÁQUINA DA INTENÇÃO É FAIL-CLOSED. Cada forma de um ingresso acontecer
//    sem ACK tem caso próprio, e o esperado é sempre o mesmo: NADA é
//    confirmado. A prova de que o cliente não senta ninguém não é ler o
//    código — é mandar um ACK divergente e ver a confirmação não existir.
//
// 3. AS SUÍTES ESTÃO INSCRITAS. Os quatro gates desta OS são conferidos por
//    UMA suíte só — esta. É de propósito: se cada suíte guardasse a própria
//    inscrição, apagar a suíte apagaria o guarda dela junto, que é exatamente
//    o buraco.
//
// O digest é sobre o conteúdo NORMALIZADO em LF. Sem normalizar, a mesma
// árvore reprovaria no Windows (CRLF pelo autocrlf) e passaria no CI.

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:buraco_master_vip/ingresso/contrato_ingresso.dart';
import 'package:buraco_master_vip/ingresso/estado_ingresso.dart';
import 'package:buraco_master_vip/ingresso/modelo_ingresso.dart';

import 'cena_de_ingresso.dart';

/// O digest do contrato do ingresso.
///
/// Mudou? Então o contrato mudou. Se a mudança é intencional, releia o
/// servidor congelado ANTES de atualizar este valor — o ponto inteiro deste
/// caso existir é obrigar essa leitura.
const String kDigestDoContratoDeIngresso =
    '5ef5cd8e1fdd863ba33e9481a81df2c0c17fe462c2210f6a35dc8541ef589229';

/// O SHA do servidor que a OS 38.3 é obrigada a consumir.
const String kShaDoServidorDaOS44 = '8a0ee4b76ac915705e2e1a37237666a4aab41c39';

/// Onde o contrato mora, visto de onde o `flutter test` roda.
///
/// Funciona nos DOIS lugares: local, o CWD é `app/`; no CI, é `app_build/`,
/// que é irmão de `app/` na raiz do repositório.
File get arquivoDoContrato => File('../contrato/ingresso-assento-v1.json');

Map<String, dynamic> _contrato() =>
    jsonDecode(arquivoDoContrato.readAsStringSync()) as Map<String, dynamic>;

/// Uma máquina já com um pedido explícito em voo, na geração 7.
EstadoDoIngresso comPedidoEmVoo({
  String codigo = 'MESA-AAA',
  int? assento = 2,
  int geracao = 7,
}) {
  final e = EstadoDoIngresso()..definirGeracaoDeTransporte(geracao);
  final ok = e.iniciar(
    codigo: codigo,
    assento: assento,
    geracaoDeTransporte: geracao,
  );
  expect(ok, isTrue, reason: 'o arnês precisa de um pedido aceito');
  return e;
}

void main() {
  // =========================================================================
  group('CONTRATO — proveniência e não-divergência', () {
    // =======================================================================

    test('CT-01 o contrato existe onde o teste o procura', () {
      expect(
        arquivoDoContrato.existsSync(),
        isTrue,
        reason:
            'contrato/ingresso-assento-v1.json não foi encontrado a partir de '
            '${Directory.current.path}. Ele viaja junto com o repositório.',
      );
    });

    test('CT-02 o digest do contrato é o congelado', () {
      final cru = arquivoDoContrato.readAsStringSync().replaceAll('\r\n', '\n');
      final digest = sha256.convert(utf8.encode(cru)).toString();
      expect(
        digest,
        kDigestDoContratoDeIngresso,
        reason:
            'contrato/ingresso-assento-v1.json mudou. Ele foi lido do servidor '
            'em $kShaDoServidorDaOS44. Se a mudança é intencional, releia o '
            'servidor antes de atualizar o digest.',
      );
    });

    test('CT-03 o vocabulário do fio é o do contrato', () {
      final j = _contrato();
      final proto = j['protocoloWebSocket']! as Map<String, dynamic>;
      expect(proto['pedidoDoCliente'], ContratoDoIngresso.pedidoDeIngresso);
      expect(proto['respostaDeAceite'], ContratoDoIngresso.respostaDeAceite);
      expect(proto['respostaDeRecusa'], ContratoDoIngresso.respostaDeRecusa);
      expect(j['esquema'], ContratoDoIngresso.esquema);
      expect(j['versao'], ContratoDoIngresso.versao);
      expect(
        (proto['camposDoPedido']! as List).cast<String>(),
        [
          ContratoDoIngresso.campoCodigo,
          ContratoDoIngresso.campoApelido,
          ContratoDoIngresso.campoAssento,
        ],
      );
      expect(
        (proto['camposDaResposta']! as List).cast<String>(),
        [
          ContratoDoIngresso.campoCodigo,
          ContratoDoIngresso.campoAssentoConfirmado,
          ContratoDoIngresso.campoReconexao,
        ],
      );
    });

    test('CT-04 a proveniência aponta para o servidor EXIGIDO pela OS', () {
      final j = _contrato();
      final prov = j['proveniencia']! as Map<String, dynamic>;
      expect(
        prov['sha'],
        kShaDoServidorDaOS44,
        reason:
            'o contrato do cliente foi lido de outro servidor. A OS 38.3 nomeia '
            'um SHA só, e consumir outro é consumir um protocolo que ninguém '
            'homologou.',
      );
      expect(
        ContratoDoIngresso.shaDoServidor,
        kShaDoServidorDaOS44,
        reason:
            'a constante Dart e o JSON têm de apontar para o MESMO servidor; '
            'divergirem faz a proveniência deixar de significar alguma coisa.',
      );
      expect(prov['branch'], 'integracao/servidor-assento-descoberta-presenca-v1');
      expect(prov['repositorio'], 'soniaambrosio/buraco-servidor');
    });

    test('CT-05 as recusas tipadas são as do servidor', () {
      final j = _contrato();
      final r = j['recusasTipadas']! as Map<String, dynamic>;
      expect(r['assentoOcupado'], ContratoDoIngresso.recusaAssentoOcupado);
      expect(r['assentoInvalido'], ContratoDoIngresso.recusaAssentoInvalido);
      expect(
        r['admissaoIndisponivel'],
        ContratoDoIngresso.recusaAdmissaoIndisponivel,
      );
      // A enumeração é FECHADA: um código a mais no contrato sem entrar na
      // lista do cliente viraria recusa "desconhecida" em produção.
      expect(
        ContratoDoIngresso.codigosTipados,
        r.entries
            .where((e) => !e.key.startsWith('//'))
            .map((e) => e.value)
            .toSet(),
      );
    });

    test('CT-06 as recusas SEM código são as do servidor, normalizadas', () {
      final j = _contrato();
      final r = j['recusasSemCodigo']! as Map<String, dynamic>;
      expect(r['mesaNaoEncontrada'], ContratoDoIngresso.motivoMesaNaoEncontrada);
      expect(r['mesaCheia'], ContratoDoIngresso.motivoMesaCheia);
      expect(r['partidaJaComecou'], ContratoDoIngresso.motivoPartidaJaComecou);
    });

    test('CT-07 os limites do assento são os do servidor', () {
      final j = _contrato();
      final a = j['assento']! as Map<String, dynamic>;
      expect(a['minimo'], ContratoDoIngresso.assentoMinimo);
      expect(a['maximo'], ContratoDoIngresso.assentoMaximo);
      expect(a['capacidade'], ContratoDoIngresso.capacidadeDaMesa);
      expect(
        (a['ordemAutomatica']! as List).cast<int>(),
        ContratoDoIngresso.ordemAutomaticaDoServidor,
      );
    });

    test('CT-08 `ehAssentoPedido` recusa o que o servidor recusa', () {
      // O servidor usa `Number.isInteger(v) && v >= 0 && v < 4`. Coagir `"2"`
      // seria adivinhar a intenção de um cliente que já errou o contrato.
      expect(ContratoDoIngresso.ehAssentoPedido(0), isTrue);
      expect(ContratoDoIngresso.ehAssentoPedido(3), isTrue);
      expect(ContratoDoIngresso.ehAssentoPedido(-1), isFalse);
      expect(ContratoDoIngresso.ehAssentoPedido(4), isFalse);
      expect(ContratoDoIngresso.ehAssentoPedido('2'), isFalse);
      expect(ContratoDoIngresso.ehAssentoPedido(2.5), isFalse);
      expect(ContratoDoIngresso.ehAssentoPedido(null), isFalse);
      expect(ContratoDoIngresso.ehAssentoPedido(true), isFalse);
    });

    test('CT-09 o cliente NÃO reproduz a ordem automática do servidor', () {
      // A ordem existe como DOCUMENTO. Se algum caminho do cliente a usasse
      // para escolher, ele estaria adivinhando o que o ACK vai dizer — e as
      // duas implementações divergiriam no primeiro ajuste do servidor.
      final fontes = [
        File('lib/ingresso/estado_ingresso.dart'),
        File('lib/casca/escolha_assento_de_producao.dart'),
        File('lib/screens/escolha_assento_screen.dart'),
        File('lib/services/online_service.dart'),
      ];
      for (final f in fontes) {
        expect(f.existsSync(), isTrue, reason: '${f.path} sumiu');
        expect(
          f.readAsStringSync().contains('ordemAutomaticaDoServidor'),
          isFalse,
          reason:
              '${f.path} usa a ordem automática do servidor. Ela é documento, '
              'não algoritmo do cliente: reproduzi-la é fabricar a escolha que '
              'o ACK existe para informar.',
        );
      }
    });

    test('CT-10 a reentrada automática NÃO manda preferência de assento', () {
      // §10: depois de reconectar, o servidor é a autoridade absoluta sobre a
      // propriedade do assento. Reenviar preferência ali seria pedir para
      // trocar de cadeira — operação que este servidor não tem.
      final src = File('lib/services/online_service.dart').readAsStringSync();
      final m = RegExp(
        r"_bruto\(\{'tipo': 'entrarMesa'[^\}]*\}\)",
      ).firstMatch(src);
      expect(
        m,
        isNotNull,
        reason: 'ÂNCORA PERDIDA: a reentrada automática mudou de forma',
      );
      expect(
        m!.group(0)!.contains('assento'),
        isFalse,
        reason:
            'a reentrada automática passou a mandar assento. Ela não escolhe '
            'lugar: o titular volta para o dele, e quem não é titular não senta.',
      );
    });
  });

  // =========================================================================
  group('MODELO — como uma recusa é classificada', () {
    // =======================================================================

    test('MI-01 o CÓDIGO manda', () {
      expect(
        MotivoDeRecusaDeIngresso.classificar(
          codigo: ContratoDoIngresso.recusaAssentoOcupado,
          motivo: 'qualquer coisa',
        ),
        MotivoDeRecusaDeIngresso.assentoOcupado,
      );
      expect(
        MotivoDeRecusaDeIngresso.classificar(
          codigo: ContratoDoIngresso.recusaAssentoInvalido,
        ),
        MotivoDeRecusaDeIngresso.assentoInvalido,
      );
      expect(
        MotivoDeRecusaDeIngresso.classificar(
          codigo: ContratoDoIngresso.recusaAdmissaoIndisponivel,
        ),
        MotivoDeRecusaDeIngresso.admissaoIndisponivel,
      );
    });

    test('MI-02 sem código, o TEXTO é lido — e o acento não decide nada', () {
      // O servidor emite com acento. Um dia pode emitir sem, e a recusa não
      // pode virar "desconhecida" por causa de um caractere.
      expect(
        MotivoDeRecusaDeIngresso.classificar(motivo: 'mesa não encontrada'),
        MotivoDeRecusaDeIngresso.mesaNaoEncontrada,
      );
      expect(
        MotivoDeRecusaDeIngresso.classificar(motivo: 'mesa nao encontrada'),
        MotivoDeRecusaDeIngresso.mesaNaoEncontrada,
      );
      expect(
        MotivoDeRecusaDeIngresso.classificar(motivo: 'a partida já começou'),
        MotivoDeRecusaDeIngresso.partidaJaComecou,
      );
      expect(
        MotivoDeRecusaDeIngresso.classificar(motivo: 'MESA CHEIA'),
        MotivoDeRecusaDeIngresso.mesaCheia,
      );
    });

    test('MI-03 recusa que o cliente não conhece NÃO vira fallback', () {
      final m = MotivoDeRecusaDeIngresso.classificar(
        codigo: 'CODIGO_DO_FUTURO',
        motivo: 'algo novo',
      );
      expect(m, MotivoDeRecusaDeIngresso.desconhecida);
      final r = RecusaDeIngresso(motivo: m, assentoPedido: 1);
      expect(r.mensagem, isNotEmpty);
      expect(
        r.permiteEscolherOutroAssento,
        isTrue,
        reason: 'oferecer outra cadeira é da PESSOA; não é tentativa automática',
      );
    });

    test('MI-04 a recusa nomeia a POSIÇÃO pedida, contando de 1', () {
      final r = const RecusaDeIngresso(
        motivo: MotivoDeRecusaDeIngresso.assentoOcupado,
        assentoPedido: 2,
      );
      expect(r.mensagem, contains('posição 3'));
      final auto = const RecusaDeIngresso(
        motivo: MotivoDeRecusaDeIngresso.assentoOcupado,
        assentoPedido: null,
      );
      expect(auto.mensagem, isNot(contains('posição')));
    });

    test('MI-05 mesa fora de jogo NÃO oferece outra cadeira DESTA mesa', () {
      for (final m in [
        MotivoDeRecusaDeIngresso.mesaNaoEncontrada,
        MotivoDeRecusaDeIngresso.mesaCheia,
        MotivoDeRecusaDeIngresso.partidaJaComecou,
      ]) {
        expect(
          RecusaDeIngresso(motivo: m, assentoPedido: 0)
              .permiteEscolherOutroAssento,
          isFalse,
        );
      }
    });
  });

  // =========================================================================
  group('ESTADO — uma intenção, e nenhum assento concedido pelo cliente', () {
    // =======================================================================

    test('EI-01 sem pedido, um ACK não confirma nada', () {
      final e = EstadoDoIngresso();
      final mudou = e.aplicarAceite(
        ackDeIngresso(codigo: 'MESA-AAA', assento: 2),
        geracaoDeTransporte: 0,
      );
      expect(mudou, isFalse);
      expect(e.fase, FaseDoIngresso.ocioso);
      expect(e.temConfirmacaoPendente, isFalse);
    });

    test('EI-02 o pedido explícito confirma quando o ACK bate', () {
      final e = comPedidoEmVoo(assento: 2);
      expect(e.fase, FaseDoIngresso.solicitando);
      expect(e.assentoSolicitado, 2);
      final ok = e.aplicarAceite(
        ackDeIngresso(codigo: 'MESA-AAA', assento: 2),
        geracaoDeTransporte: 7,
      );
      expect(ok, isTrue);
      expect(e.fase, FaseDoIngresso.confirmado);
      final c = e.consumirConfirmacao();
      expect(c, isNotNull);
      expect(c!.assento, 2);
      expect(c.codigo, 'MESA-AAA');
      expect(c.reconexao, isFalse);
    });

    test('EI-03 CONFIRMADO != SOLICITADO não concede assento nenhum', () {
      // É o caso que separa "o servidor decide" de "o servidor decide, e o
      // cliente aceita qualquer coisa". Sem reconexão, divergir é violação.
      final e = comPedidoEmVoo(assento: 2);
      final ok = e.aplicarAceite(
        ackDeIngresso(codigo: 'MESA-AAA', assento: 1),
        geracaoDeTransporte: 7,
      );
      expect(ok, isTrue, reason: 'virou VEREDITO — de recusa');
      expect(e.fase, FaseDoIngresso.recusado);
      expect(e.temConfirmacaoPendente, isFalse);
      expect(e.consumirConfirmacao(), isNull);
      expect(e.recusa!.motivo, MotivoDeRecusaDeIngresso.ackForaDoContrato);
    });

    test('EI-04 na RECONEXÃO o assento do titular manda, e é aceito', () {
      final e = comPedidoEmVoo(assento: 2);
      final ok = e.aplicarAceite(
        ackDeIngresso(codigo: 'MESA-AAA', assento: 0, reconexao: true),
        geracaoDeTransporte: 7,
      );
      expect(ok, isTrue);
      expect(e.fase, FaseDoIngresso.confirmado);
      final c = e.consumirConfirmacao()!;
      expect(c.assento, 0, reason: 'o lugar que já era dele');
      expect(c.reconexao, isTrue);
      expect(c.anuncio, contains('posição 1'));
    });

    test('EI-05 ACK sem assento válido é recusa, não adivinhação', () {
      for (final bruto in <Map<String, dynamic>>[
        {'tipo': 'entrou', 'codigo': 'MESA-AAA', 'reconexao': false},
        {'tipo': 'entrou', 'codigo': 'MESA-AAA', 'assento': null},
        {'tipo': 'entrou', 'codigo': 'MESA-AAA', 'assento': '2'},
        {'tipo': 'entrou', 'codigo': 'MESA-AAA', 'assento': 9},
      ]) {
        final e = comPedidoEmVoo(assento: 2);
        e.aplicarAceite(bruto, geracaoDeTransporte: 7);
        expect(e.fase, FaseDoIngresso.recusado, reason: '$bruto');
        expect(e.temConfirmacaoPendente, isFalse, reason: '$bruto');
      }
    });

    test('EI-06 ACK de OUTRA mesa é descartado — e o pedido continua em voo', () {
      final e = comPedidoEmVoo(codigo: 'MESA-AAA', assento: 2);
      final mudou = e.aplicarAceite(
        ackDeIngresso(codigo: 'MESA-BBB', assento: 2),
        geracaoDeTransporte: 7,
      );
      expect(mudou, isFalse);
      expect(
        e.fase,
        FaseDoIngresso.solicitando,
        reason:
            'a mesa por código fala o MESMO `entrarMesa`; matar o pedido por '
            'causa do ACK dela seria perder uma tentativa válida',
      );
    });

    test('EI-07 TOQUE DUPLO: o segundo pedido não é autorizado', () {
      final e = comPedidoEmVoo(assento: 2);
      final segundo = e.iniciar(
        codigo: 'MESA-AAA',
        assento: 3,
        geracaoDeTransporte: 7,
      );
      expect(segundo, isFalse);
      expect(e.pedidosAutorizados, 1);
      expect(e.assentoSolicitado, 2, reason: 'a intenção não foi trocada');
    });

    test('EI-08 RESPOSTA DUPLICADA confirma uma vez só', () {
      final e = comPedidoEmVoo(assento: 2);
      expect(
        e.aplicarAceite(
          ackDeIngresso(codigo: 'MESA-AAA', assento: 2),
          geracaoDeTransporte: 7,
        ),
        isTrue,
      );
      expect(
        e.aplicarAceite(
          ackDeIngresso(codigo: 'MESA-AAA', assento: 2),
          geracaoDeTransporte: 7,
        ),
        isFalse,
        reason: 'a fase já não é `solicitando`',
      );
      expect(e.consumirConfirmacao(), isNotNull);
      expect(
        e.consumirConfirmacao(),
        isNull,
        reason: 'consumir entrega UMA vez — é o que faz navegar uma vez',
      );
    });

    test('EI-09 RESPOSTA FORA DE ORDEM: a recusa depois do ACK não desfaz', () {
      final e = comPedidoEmVoo(assento: 2);
      e.aplicarAceite(
        ackDeIngresso(codigo: 'MESA-AAA', assento: 2),
        geracaoDeTransporte: 7,
      );
      final tarde = e.aplicarRecusa(recusaAssentoOcupado(), geracaoDeTransporte: 7);
      expect(tarde, isFalse);
      expect(e.fase, FaseDoIngresso.confirmado);
      expect(e.recusa, isNull);
    });

    test('EI-10 RESPOSTA ATRASADA de outra geração é descartada', () {
      final e = comPedidoEmVoo(assento: 2, geracao: 7);
      // A conexão caiu e voltou: a geração vigente é outra.
      e.definirGeracaoDeTransporte(8);
      expect(
        e.fase,
        FaseDoIngresso.ocioso,
        reason: 'a intenção não atravessa conexões',
      );
      final tardio = e.aplicarAceite(
        ackDeIngresso(codigo: 'MESA-AAA', assento: 2),
        geracaoDeTransporte: 7,
      );
      expect(tardio, isFalse);
      expect(e.temConfirmacaoPendente, isFalse);
    });

    test('EI-11 SAIR DA TELA invalida o pedido', () {
      final e = comPedidoEmVoo(assento: 2);
      e.cancelar();
      expect(e.fase, FaseDoIngresso.ocioso);
      final tardio = e.aplicarAceite(
        ackDeIngresso(codigo: 'MESA-AAA', assento: 2),
        geracaoDeTransporte: 7,
      );
      expect(tardio, isFalse);
      expect(e.temConfirmacaoPendente, isFalse);
    });

    test('EI-12 TROCA DE CONTA apaga até confirmação não consumida', () {
      final e = comPedidoEmVoo(assento: 2);
      e.aplicarAceite(
        ackDeIngresso(codigo: 'MESA-AAA', assento: 2),
        geracaoDeTransporte: 7,
      );
      expect(e.temConfirmacaoPendente, isTrue);
      e.encerrarSessao();
      expect(
        e.temConfirmacaoPendente,
        isFalse,
        reason: 'a conta B não herda o assento que a conta A conquistou',
      );
      expect(e.consumirConfirmacao(), isNull);
      expect(e.fase, FaseDoIngresso.ocioso);
    });

    test('EI-13 recusa TIPADA de ocupado não produz segunda tentativa', () {
      final e = comPedidoEmVoo(assento: 2);
      final ok = e.aplicarRecusa(recusaAssentoOcupado(), geracaoDeTransporte: 7);
      expect(ok, isTrue);
      expect(e.fase, FaseDoIngresso.recusado);
      expect(e.recusa!.motivo, MotivoDeRecusaDeIngresso.assentoOcupado);
      expect(e.recusa!.assentoPedido, 2);
      expect(e.temConfirmacaoPendente, isFalse);
      expect(
        e.pedidosAutorizados,
        1,
        reason: 'nenhum pedido novo nasceu da recusa',
      );
      expect(
        e.assentoSolicitado,
        isNull,
        reason: 'a intenção morre com a recusa; não há cadeira reservada',
      );
    });

    test('EI-14 recusa de assento INVÁLIDO não altera estado local', () {
      final e = comPedidoEmVoo(assento: 2);
      e.aplicarRecusa(recusaAssentoInvalido(), geracaoDeTransporte: 7);
      expect(e.recusa!.motivo, MotivoDeRecusaDeIngresso.assentoInvalido);
      expect(e.temConfirmacaoPendente, isFalse);
      expect(e.fase, FaseDoIngresso.recusado);
    });

    test('EI-15 recusas de ciclo de vida chegam SEM código e são lidas', () {
      final casos = {
        'mesa não encontrada': MotivoDeRecusaDeIngresso.mesaNaoEncontrada,
        'mesa cheia': MotivoDeRecusaDeIngresso.mesaCheia,
        'a partida já começou': MotivoDeRecusaDeIngresso.partidaJaComecou,
      };
      casos.forEach((motivo, esperado) {
        final e = comPedidoEmVoo(assento: null);
        e.aplicarRecusa(recusaSemCodigo(motivo), geracaoDeTransporte: 7);
        expect(e.recusa!.motivo, esperado, reason: motivo);
      });
    });

    test('EI-16 pedido de assento INVÁLIDO nem chega a sair', () {
      final e = EstadoDoIngresso()..definirGeracaoDeTransporte(1);
      expect(
        e.iniciar(codigo: 'MESA-AAA', assento: 9, geracaoDeTransporte: 1),
        isFalse,
      );
      expect(e.pedidosAutorizados, 0);
      expect(e.fase, FaseDoIngresso.ocioso);
    });

    test('EI-18 ACK de geração ALHEIA é recusado na FRONTEIRA da classe', () {
      // O transporte nunca faz esta chamada: ele passa sempre a geração
      // vigente, e mata a intenção a cada troca de conexão — o que torna as
      // duas guardas redundantes NO CAMINHO DE PRODUÇÃO. Foi por isso que a
      // mutação I09 escapou: nenhum caso as alcançava.
      //
      // Elas continuam tendo de existir, e o lugar de cobrá-las é aqui. O
      // contrato desta classe é recusar QUALQUER resposta que não seja da
      // geração dela, sem depender de quem a chama estar correto.
      final e = comPedidoEmVoo(assento: 2, geracao: 7);
      final aceitou = e.aplicarAceite(
        ackDeIngresso(codigo: 'MESA-AAA', assento: 2),
        geracaoDeTransporte: 99,
      );
      expect(aceitou, isFalse);
      expect(e.temConfirmacaoPendente, isFalse);
      expect(
        e.fase,
        FaseDoIngresso.solicitando,
        reason: 'a resposta é de outra conexão: ela não é resposta nenhuma',
      );
      // E o mesmo vale para a recusa.
      expect(
        e.aplicarRecusa(recusaAssentoOcupado(), geracaoDeTransporte: 99),
        isFalse,
      );
      expect(e.recusa, isNull);
    });

    test('EI-17 pedido AUTOMÁTICO não tem assento, e não vira assento 0', () {
      final e = comPedidoEmVoo(assento: null);
      expect(e.intencao!.explicita, isFalse);
      expect(e.assentoSolicitado, isNull);
      // Qualquer assento serve, porque não houve pedido a contradizer.
      final ok = e.aplicarAceite(
        ackDeIngresso(codigo: 'MESA-AAA', assento: 1),
        geracaoDeTransporte: 7,
      );
      expect(ok, isTrue);
      expect(e.consumirConfirmacao()!.assento, 1);
    });
  });

  // =========================================================================
  group('§17 — REGISTRO: as suítes desta OS estão no portão', () {
    // =======================================================================
    //
    // Uma suíte que ninguém roda é uma suíte que não existe. As quatro
    // inscrições são conferidas AQUI, por uma suíte só — se cada uma guardasse
    // a própria, apagar a suíte apagaria o guarda dela junto.

    const gates = ['ingrcontrato', 'ingrassento', 'ingrtransp', 'ingrnav'];

    /// Os cinco gates da OS 38.2 continuam de pé. Esta OS não pode entregar
    /// ingresso derrubando a descoberta que ele consome.
    const gatesDaDescoberta = [
      'descadapt',
      'descestado',
      'deschome',
      'descstbl',
      'desclobby',
    ];

    test('RG-01 os quatro gates estão na FONTE ÚNICA', () {
      final fonte = File('../scripts/ci/gates_os_integracao.txt');
      expect(fonte.existsSync(), isTrue);
      final inscritos = fonte
          .readAsLinesSync()
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty && !l.startsWith('#'))
          .toSet();
      for (final g in [...gates, ...gatesDaDescoberta]) {
        expect(
          inscritos,
          contains(g),
          reason:
              'o gate "$g" saiu de scripts/ci/gates_os_integracao.txt. A suíte '
              'continuaria verde e o CI não a rodaria.',
        );
      }
    });

    test('RG-02 cada gate tem um passo que o EXECUTA no workflow', () {
      // A ÂNCORA É O COMEÇO DA LINHA, e isto não é preciosismo: a versão
      // anterior desta guarda procurava `roda <gate> test/` em QUALQUER
      // posição do arquivo, e por isso casava com `# roda ingrnav test/…`.
      // Comentar o passo tirava a suíte do CI e a guarda continuava verde —
      // foi exatamente o que a mutação I27 fez, e ela escapou.
      final linhas = File(
        '../.github/workflows/ci-os-integracao.yml',
      ).readAsLinesSync().map((l) => l.trim()).toList();
      for (final g in [...gates, ...gatesDaDescoberta]) {
        // STRING CRUA, e concatenada: numa string comum do Dart o \s
        // vira um `s` solto — a expressão passaria a procurar
        // `rodas+<gate>s+test/`, e a guarda reprovaria o repositório
        // íntegro por causa de uma barra.
        final executa = RegExp(r'^roda\s+' + g + r'\s+test/');
        expect(
          linhas.where(executa.hasMatch),
          hasLength(1),
          reason:
              'o workflow não EXECUTA `$g`. Comentar o passo, apagá-lo ou '
              'duplicá-lo dão no mesmo aqui: a suíte deixa de valer como '
              'portão, e o CI não diz uma palavra.',
        );
      }
    });

    test('RG-03 os arquivos apontados pelo workflow EXISTEM', () {
      final wf = File(
        '../.github/workflows/ci-os-integracao.yml',
      ).readAsStringSync();
      for (final g in [...gates, ...gatesDaDescoberta]) {
        final m = RegExp('roda\\s+$g\\s+(test/[^\\s]+)').firstMatch(wf);
        expect(m, isNotNull, reason: 'gate $g sem caminho');
        final caminho = m!.group(1)!;
        expect(
          File(caminho).existsSync(),
          isTrue,
          reason:
              'o workflow manda rodar "$caminho" e o arquivo não existe. '
              'Renomear a suíte sem atualizar o workflow deixaria o gate '
              'ausente, e ausência é reprovação — mas só no CI, tarde demais.',
        );
      }
    });

    test('RG-04 a campanha de sabotagem desta OS existe e carrega mutações', () {
      final f = File('tools/mutacoes_ingresso.js');
      expect(
        f.existsSync(),
        isTrue,
        reason:
            'as provas negativas da §16 vivem nesta campanha. Sem ela, a suíte '
            'afirma o que existe e não afirma que a defesa é NECESSÁRIA.',
      );
      final src = f.readAsStringSync();
      final quantas = RegExp("id: '[A-Z0-9]+'").allMatches(src).length;
      expect(
        quantas,
        greaterThanOrEqualTo(20),
        reason:
            'a campanha encolheu para $quantas mutações. Uma campanha que lê '
            'pouco e diz "tudo certo" parece rigor e é vácuo.',
      );
    });
  });
}
