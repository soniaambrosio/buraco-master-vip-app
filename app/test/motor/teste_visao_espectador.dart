// teste_visao_espectador.dart — PROVA DE QUE O ESPECTADOR NÃO RECEBE SEGREDO.
//
// Cobre a seção 13 da OS de Moderação, um caso por afirmação. O item é marcado
// como crítico na OS, e a razão é a assimetria do erro: esconder na interface
// parece funcionar em todo teste visual, e mesmo assim o dado já chegou ao
// aparelho de quem não podia vê-lo.
//
// A verificação forte é ESP-04 e suas variantes: em vez de conferir campo a
// campo (uma lista de permissão que envelhece calada), a varredura parte dos IDS
// SECRETOS e percorre todo valor de texto da estrutura, sob qualquer chave e em
// qualquer profundidade. Um campo novo com carta dentro reprova sozinho.
//
// Os três últimos casos da seção 13 da OS — payload privado por endpoint direto,
// por UID de terceiro e por parâmetro adulterado — não são provados aqui: eles
// são de autorização, não de recorte, e ficam em firebase/testes/. Este arquivo
// prova a única coisa que o Dart pode provar: que a visão do espectador NÃO
// CONTÉM o segredo, qualquer que seja o caminho que a produziu.

import 'package:flutter_test/flutter_test.dart';
import 'package:buraco_master_vip/mesa.dart';
import 'package:buraco_master_vip/motor/motor_partida.dart';
import 'package:buraco_master_vip/motor/presenca.dart';
import 'package:buraco_master_vip/motor/relogio_turno.dart';
import 'package:buraco_master_vip/motor/visao_assento.dart';
import 'package:buraco_master_vip/motor/visao_espectador.dart';

Jogo novo([String modalidade = 'ABERTO']) {
  final j = Jogo(const ['você', 'B1', 'B2', 'B3'], const ['A', 'B', 'C', 'D'],
      const ['🐶', '🐰', '🦊', '🐱']);
  j.modalidade = modalidade;
  return j;
}

MotorPartida motorDe(Jogo j) {
  var t = 0;
  return MotorPartida(
    partidaId: 'p-espectador',
    jogo: j,
    agora: () => t += 1000,
    janelaIdempotencia: 256,
  );
}

/// Campos do assento que existem SÓ porque o assento tem mão própria.
/// Nenhum deles pode aparecer na visão de espectador.
const camposDeSegredoDoAssento = <String>[
  'mao', // as cartas em si
  'impressaoDaMao', // impressão digital DERIVADA das cartas
  'idTopoObrigatorio', // id de carta que está numa mão
  'idDescarteProibido', // id de carta que está numa mão
];

void main() {
  group('ESP — o espectador vê a mesa, nunca o segredo', () {
    // ---------------------------------------------------------------- público

    test('ESP-01 recebe o estado público da partida', () {
      final v = VisaoEspectador.de(novo(), partidaId: 'p1', versaoEstado: 3);

      expect(v['espectador'], isTrue);
      expect(v['partidaId'], 'p1');
      expect(v['versaoEstado'], 3);
      expect(v['modalidade'], 'ABERTO');
      expect(v['metaPontos'], 1500);
      expect(v['vez'], isA<int>());
      expect(v['placarNos'], 0);
      expect(v['placarEles'], 0);
      expect(v['rodadaEncerrada'], isFalse);
      expect(v['partidaEncerrada'], isFalse);

      final jogadores = v['jogadores'] as List;
      expect(jogadores, hasLength(4));
      expect((jogadores[0] as Map)['apelido'], 'você');
      expect((jogadores[1] as Map)['mascote'], '🐰');
      expect((jogadores[0] as Map)['dupla'], 'nos');
      expect((jogadores[1] as Map)['dupla'], 'eles');
    });

    test('ESP-02 vê as cartas já publicadas: lixo e jogos baixados', () {
      final j = novo();
      // O lixo é pilha aberta; quem está em volta da mesa já leu tudo que passou.
      final descartada = j.maos[0].removeLast();
      j.lixo.add(descartada);

      final v = VisaoEspectador.de(j);
      final visiveis = VisaoAssento.idsVisiveis(v);

      expect(visiveis, contains(descartada.id),
          reason: 'carta no lixo é pública e DEVE aparecer');
      expect((v['lixo'] as List), hasLength(1));
      expect(v['jogosNos'], isEmpty);
      expect(v['jogosEles'], isEmpty);
    });

    test('ESP-03 vê a CONTAGEM do que está oculto, e só ela', () {
      final j = novo();
      final v = VisaoEspectador.de(j);

      expect(v['cartasNaMao'], [11, 11, 11, 11]);
      expect(v['monteRestante'], j.monte.length);
      expect(v['mortosRestantes'], j.mortos.length);
      expect(v['mortosTamanhos'], [for (final m in j.mortos) m.length]);
      expect(v['mortoPegoNos'], isFalse);
      expect(v['mortoPegoEles'], isFalse);
    });

    // ---------------------------------------------------- ausência de segredo

    test('ESP-04 nenhum id secreto aparece em NENHUM texto da visão', () {
      final j = novo();
      final v = VisaoEspectador.de(j);
      expect(VisaoEspectador.vazamentos(v, j), isEmpty);
    });

    test('ESP-05 não recebe a mão de NENHUM dos quatro assentos', () {
      final j = novo();
      final v = VisaoEspectador.de(j);

      for (var a = 0; a < 4; a++) {
        final mao = {for (final c in j.maos[a]) c.id};
        expect(VisaoAssento.vazamentos(v, mao), isEmpty,
            reason: 'vazou a mão do assento $a');
      }
    });

    test('ESP-06 não recebe o conteúdo do morto', () {
      final j = novo();
      final morto = {
        for (final m in j.mortos)
          for (final c in m) c.id,
      };
      expect(morto, isNotEmpty, reason: 'o cenário precisa ter morto');
      expect(VisaoAssento.vazamentos(VisaoEspectador.de(j), morto), isEmpty);
    });

    test('ESP-07 não recebe o monte nem a ordem em que ele vai sair', () {
      final j = novo();
      final monte = {for (final c in j.monte) c.id};
      expect(VisaoAssento.vazamentos(VisaoEspectador.de(j), monte), isEmpty);
    });

    test('ESP-08 os campos de segredo do assento não existem aqui', () {
      final j = novo();
      final v = VisaoEspectador.de(j);
      for (final campo in camposDeSegredoDoAssento) {
        expect(v.containsKey(campo), isFalse,
            reason: '`$campo` é campo de assento e não pode existir no recorte '
                'de espectador');
      }
    });

    test('ESP-09 a obrigação do topo é FATO público, sem o id da carta', () {
      final j = novo();
      // Simula quem pegou o lixo e está devendo o topo: a carta foi para a mão.
      final topo = j.maos[0].first;
      j.lixoTopoObrigatorio = topo.id;

      final v = VisaoEspectador.de(j);
      expect(v['obrigacaoTopoPendente'], isTrue,
          reason: 'que existe pendência é público');
      expect(v.containsKey('idTopoObrigatorio'), isFalse);
      expect(VisaoAssento.vazamentos(v, {topo.id}), isEmpty);
    });

    // ------------------------------------------------------- casos dinâmicos

    test('ESP-10 durante uma partida de robôs a visão nunca vaza', () {
      final j = novo();
      final m = motorDe(j);

      for (var t = 0; t < 25 && !m.jogo.rodadaEncerrada; t++) {
        m.conduzirRobo(m.jogo.vez, eventoId: 'esp$t');
        final v = VisaoEspectador.de(m.jogo);
        expect(VisaoEspectador.vazamentos(v, m.jogo), isEmpty,
            reason: 'vazou no turno $t');
      }
    });

    test('ESP-11 rodada apurada: pontosRodada não carrega id de carta', () {
      final j = novo();
      final m = motorDe(j);

      // Conduz até a rodada fechar; se não fechar, o caso ainda vale como
      // varredura do estado corrente.
      for (var t = 0; t < 400 && !m.jogo.rodadaEncerrada; t++) {
        m.conduzirRobo(m.jogo.vez, eventoId: 'fim$t');
      }
      m.jogo.contarPontos();

      final v = VisaoEspectador.de(m.jogo);
      expect(VisaoEspectador.vazamentos(v, m.jogo), isEmpty,
          reason: 'o detalhamento da pontuação vazou carta');
    });

    test('ESP-12 mesa bloqueada não vaza a carta citada no código de erro', () {
      final j = novo();
      final duplicada = j.monte.first;
      j.mortos.first.add(duplicada); // mesma carta em duas zonas
      j.auditarIntegridade();
      expect(j.integridadeErro, isNotNull);

      final v = VisaoEspectador.de(j);
      expect(v['mesaBloqueada'], isTrue);
      expect(VisaoAssento.vazamentos(v, {duplicada.id}), isEmpty);
    });

    test('ESP-13 reconexão: remontar a visão não afrouxa o recorte', () {
      // O §13 da OS pede explicitamente "não recebe dados privados por
      // reconexão". Reconectar é pedir a visão de novo, com outra versão de
      // estado e outro relógio — nada disso muda o que é segredo.
      final j = novo();
      final relogio =
          RelogioTurno(assento: 2, inicioMs: 1000, duracaoMs: 45000, versaoEstado: 9);

      for (final versao in [0, 1, 9, 999]) {
        final v = VisaoEspectador.de(
          j,
          versaoEstado: versao,
          partidaId: 'p-reconexao',
          relogio: relogio,
          presenca: MapaPresenca(),
        );
        expect(VisaoEspectador.vazamentos(v, j), isEmpty,
            reason: 'vazou ao remontar na versão $versao');
        expect(v.containsKey('mao'), isFalse);
      }
    });

    test('ESP-14 não existe parâmetro de assento para adulterar', () {
      // "não obtém informação secreta alterando parâmetros": a assinatura não
      // aceita assento, então não há valor a forjar. O que sobra de ajustável
      // (versão, partidaId, relógio, presença) é estado de sessão e não abre mão.
      final j = novo();
      final v = VisaoEspectador.de(j, partidaId: '../assento/2', versaoEstado: -1);
      expect(VisaoEspectador.vazamentos(v, j), isEmpty);
      expect(v.containsKey('assento'), isFalse,
          reason: 'espectador não ocupa assento');
    });

    // ------------------------------------------------------------ divergência

    test('ESP-DRIFT o recorte de espectador é mais estreito que o de assento',
        () {
      final j = novo();
      final espectador = VisaoEspectador.de(j);
      final assento = VisaoAssento.de(j, 0);

      // Todo campo público que os dois compartilham tem que existir nos dois.
      const compartilhados = [
        'partidaId', 'versaoEstado', 'formatoSnapshot', 'jogadores',
        'modalidade', 'metaPontos', 'rodada', 'vez', 'jaComprou',
        'rodadaEncerrada', 'partidaEncerrada', 'lixo', 'jogosNos', 'jogosEles',
        'cartasNaMao', 'monteRestante', 'mortosRestantes', 'mortosTamanhos',
        'mortoPegoNos', 'mortoPegoEles', 'obrigacaoTopoPendente', 'placarNos',
        'placarEles', 'minimoParaDescerNos', 'minimoParaDescerEles',
        'duplaQueBateu', 'assentoQueBateu', 'pontosRodada', 'mesaBloqueada',
        'relogio', 'presenca',
      ];
      for (final campo in compartilhados) {
        expect(assento.containsKey(campo), isTrue,
            reason: 'o assento perdeu `$campo` — atualize os dois recortes');
        expect(espectador.containsKey(campo), isTrue,
            reason: 'o espectador ficou para trás em `$campo`');
      }

      // E o espectador não pode ter ganhado nada que o assento não tenha,
      // fora os campos que só fazem sentido sem assento.
      const soDoEspectador = [
        'espectador', 'vulneravelNos', 'vulneravelEles',
        'podeBaterNos', 'podeBaterEles',
      ];
      final excedente = espectador.keys
          .where((k) => !assento.containsKey(k) && !soDoEspectador.contains(k))
          .toList();
      expect(excedente, isEmpty,
          reason: 'campo novo no espectador sem par no assento: $excedente');
    });
  });
}
