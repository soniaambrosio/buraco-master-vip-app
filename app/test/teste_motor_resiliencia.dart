// PORTÃO DE QUALIDADE — RESILIÊNCIA DO MOTOR (OS-01 §6 a §10, §13, §16).
//
// A suíte de `teste_motor.dart` prova que as REGRAS estão certas. Esta prova que
// as regras continuam certas quando a rede está errada: comando repetido, dois
// jogadores ao mesmo tempo, queda no meio da jogada, volta com o estado velho,
// aplicativo em segundo plano.
//
// Convenções:
//   * nada aqui espera tempo real passar — o relógio é injetado;
//   * todo teste que fala em "queda" reenvia o MESMO eventoId, que é o que um
//     cliente real faz ao reconectar;
//   * os testes de vazamento varrem a estrutura inteira em vez de conferir
//     campo a campo: campo novo com carta dentro reprova sozinho.
import 'package:flutter_test/flutter_test.dart';
import 'package:buraco_master_vip/mesa.dart';
import 'package:buraco_master_vip/motor/comando_partida.dart';
import 'package:buraco_master_vip/motor/diagnostico.dart';
import 'package:buraco_master_vip/motor/motor_partida.dart';
import 'package:buraco_master_vip/motor/presenca.dart';
import 'package:buraco_master_vip/motor/relogio_turno.dart';
import 'package:buraco_master_vip/motor/sessao_reconexao.dart';
import 'package:buraco_master_vip/motor/snapshot_partida.dart';
import 'package:buraco_master_vip/motor/visao_assento.dart';

// ============================== ferramentas ==============================

Jogo novo([String modalidade = 'ABERTO']) {
  final j = Jogo(const ['você', 'B1', 'B2', 'B3'], const ['A', 'B', 'C', 'D'],
      const ['🐶', '🐰', '🦊', '🐱']);
  j.modalidade = modalidade;
  return j;
}

List<Carta> zonasTodas(Jogo j) => [
      ...j.monte,
      ...j.lixo,
      for (final m in j.mortos) ...m,
      for (final m in j.maos) ...m,
      for (final g in j.jogosDupla['nos']!) ...g,
      for (final g in j.jogosDupla['eles']!) ...g,
    ];

int totalCartas(Jogo j) => zonasTodas(j).length;

Carta pega(List<Carta> pool, String valor, String? naipe) {
  final i = pool.indexWhere((x) => x.valor == valor && x.naipe == naipe);
  if (i < 0) throw StateError('carta $valor/$naipe esgotada no pool');
  return pool.removeAt(i);
}

typedef Spec = (String, String?);

/// Monta um estado exato preservando as 108 cartas (o pool é o baralho real).
Jogo montar(
  Jogo j, {
  List<Spec> mao0 = const [],
  List<Spec> mao1 = const [],
  List<Spec> mao2 = const [],
  List<Spec> mao3 = const [],
  List<List<Spec>> mesaNos = const [],
  List<List<Spec>> mesaEles = const [],
  List<Spec> lixo = const [],
  int vez = 0,
  bool jaComprou = false,
  bool mortoPegoNos = false,
  bool mortoPegoEles = false,
  int mortos = 2,
}) {
  final pool = zonasTodas(j).toList();
  List<Carta> take(List<Spec> spec) =>
      [for (final s in spec) pega(pool, s.$1, s.$2)];
  j.maos = [take(mao0), take(mao1), take(mao2), take(mao3)];
  j.jogosDupla = {
    'nos': [for (final g in mesaNos) take(g)],
    'eles': [for (final g in mesaEles) take(g)],
  };
  j.lixo = take(lixo);
  j.mortos = [for (var i = 0; i < mortos; i++) pool.sublist(i * 11, (i + 1) * 11)];
  j.monte = pool.sublist(mortos * 11);
  j.vez = vez;
  j.jaComprou = jaComprou;
  j.rodadaEncerrada = false;
  j.encerrada = false;
  j.lixoTopoObrigatorio = null;
  j.mortoPego = {'nos': mortoPegoNos, 'eles': mortoPegoEles};
  j.primeiraBaixadaFeita = {'nos': false, 'eles': false};
  j.rodadasVulneravel = {'nos': 0, 'eles': 0};
  j.integridadeErro = null;
  j.auditarIntegridade();
  if (j.integridadeErro != null) {
    throw StateError('montar() quebrou a integridade: ${j.integridadeErro}');
  }
  return j;
}

/// Relógio de teste: avança só quando o teste manda.
class RelogioFake {
  int agoraMs;
  RelogioFake([this.agoraMs = 1700000000000]);
  int ler() => agoraMs;
  void avancar(int ms) => agoraMs += ms;
}

MotorPartida motorDe(Jogo j, {RelogioFake? relogio, int janela = 256}) =>
    MotorPartida(
      partidaId: 'p-teste',
      jogo: j,
      agora: (relogio ?? RelogioFake()).ler,
      janelaIdempotencia: janela,
    );

/// Uma canastra limpa de 7 cartas (copas 5..J) — libera batida em toda modalidade.
const List<Spec> canastraLimpa = [
  ('5', 'copas'),
  ('6', 'copas'),
  ('7', 'copas'),
  ('8', 'copas'),
  ('9', 'copas'),
  ('10', 'copas'),
  ('J', 'copas'),
];

void main() {
  // ==================== SNAP — snapshot e retomada (§9) ====================

  group('SNAP — snapshot e retomada', () {
    test('SNAP-01 ida e volta preserva o estado inteiro', () {
      final j = novo();
      j.comprarMonte(j.vez);
      final antes = SnapshotPartida.capturar(j);
      final volta = SnapshotPartida.restaurar(antes);
      expect(SnapshotPartida.capturar(volta), antes);
    });

    test('SNAP-02 captura é determinística (mesma impressão duas vezes)', () {
      final j = novo();
      final a = SnapshotPartida.impressao(SnapshotPartida.capturar(j));
      final b = SnapshotPartida.impressao(SnapshotPartida.capturar(j));
      expect(a, b);
    });

    test('SNAP-03 estado diferente produz impressão diferente', () {
      final j = novo();
      final antes = SnapshotPartida.impressao(SnapshotPartida.capturar(j));
      // §3.2: quem começa é sorteado — a compra tem que ser do assento da vez.
      j.comprarMonte(j.vez);
      expect(SnapshotPartida.impressao(SnapshotPartida.capturar(j)),
          isNot(antes));
    });

    test('SNAP-04 as 108 cartas atravessam a retomada', () {
      final j = novo();
      final volta = SnapshotPartida.restaurar(SnapshotPartida.capturar(j));
      expect(totalCartas(volta), 108);
      expect(volta.auditarIntegridade(), isTrue);
    });

    test('SNAP-05 a mão volta idêntica, carta por carta e na mesma ordem', () {
      final j = novo();
      final idsAntes = [for (final c in j.maos[0]) c.id];
      final volta = SnapshotPartida.restaurar(SnapshotPartida.capturar(j));
      expect([for (final c in volta.maos[0]) c.id], idsAntes);
    });

    test('SNAP-06 a ordem do monte é preservada (a próxima carta é a mesma)', () {
      final j = novo();
      final proxima = j.monte.first.id;
      final volta = SnapshotPartida.restaurar(SnapshotPartida.capturar(j));
      volta.comprarMonte(volta.vez);
      expect(volta.maos[volta.vez].last.id, proxima);
    });

    test('SNAP-07 obrigação do topo do lixo (Fechado) sobrevive à retomada', () {
      final j = novo('FECHADO');
      montar(j,
          mao0: [('8', 'copas'), ('8', 'ouros'), ('K', 'paus')],
          lixo: [('8', 'paus')],
          vez: 0);
      expect(j.comprarLixo(0, modalidade: 'FECHADO')['ok'], isTrue);
      expect(j.lixoTopoObrigatorio, isNotNull);
      final volta = SnapshotPartida.restaurar(SnapshotPartida.capturar(j));
      expect(volta.lixoTopoObrigatorio, j.lixoTopoObrigatorio);
      // e continua valendo: descartar antes de usar o topo é recusado
      expect(volta.descartar(0, volta.maos[0].first.id), isNotNull);
    });

    test('SNAP-08 trava do lixo único (Aberto) sobrevive à retomada', () {
      final j = novo();
      montar(j,
          mao0: [('K', 'paus'), ('Q', 'paus')], lixo: [('3', 'ouros')], vez: 0);
      expect(j.comprarLixo(0, modalidade: 'ABERTO')['ok'], isTrue);
      final proibido = j.descarteProibidoId;
      expect(proibido, isNotNull);
      final volta = SnapshotPartida.restaurar(SnapshotPartida.capturar(j));
      expect(volta.descarteProibidoId, proibido);
      expect(volta.descartar(0, proibido!), isNotNull); // recusado igual
    });

    test('SNAP-09 rodada já contada não conta de novo depois da retomada', () {
      final j = novo();
      montar(j, mao0: [('K', 'paus')], vez: 0, jaComprou: true, mortoPegoNos: true, mesaNos: [canastraLimpa]);
      j.descartar(0, j.maos[0].first.id);
      expect(j.rodadaEncerrada, isTrue);
      j.contarPontos();
      final placarNos = j.placar['nos'];
      final volta = SnapshotPartida.restaurar(SnapshotPartida.capturar(j));
      volta.contarPontos(); // proteção interna precisa ter viajado
      expect(volta.placar['nos'], placarNos);
    });

    test('SNAP-10 placar, rodada e vulnerabilidade atravessam a retomada', () {
      final j = novo();
      j.placar = {'nos': 900, 'eles': 320};
      j.rodadasVulneravel = {'nos': 2, 'eles': 0};
      j.primeiraBaixadaFeita = {'nos': false, 'eles': true};
      final volta = SnapshotPartida.restaurar(SnapshotPartida.capturar(j));
      expect(volta.placar, {'nos': 900, 'eles': 320});
      expect(volta.minimoParaDescer('nos'), 90);
      expect(volta.minimoParaDescer('eles'), 0);
    });

    test('SNAP-11 modalidade e meta atravessam a retomada', () {
      final j = novo('SBTL');
      j.metaPontos = 3000;
      final volta = SnapshotPartida.restaurar(SnapshotPartida.capturar(j));
      expect(volta.modalidade, 'SBTL');
      expect(volta.metaPontos, 3000);
    });

    test('SNAP-12 snapshot com carta em duas zonas é RECUSADO', () {
      final j = novo();
      final bruto = SnapshotPartida.capturar(j);
      final mao0 = (bruto['maos'] as List)[0] as List;
      (bruto['monte'] as List).add(mao0.first); // mesma carta em duas zonas
      expect(
        () => SnapshotPartida.restaurar(bruto),
        throwsA(isA<ErroSnapshot>()
            .having((e) => e.codigo, 'codigo', 'SNAPSHOT_CORROMPIDO')),
      );
    });

    test('SNAP-13 snapshot com carta faltando (107) é RECUSADO', () {
      final j = novo();
      final bruto = SnapshotPartida.capturar(j);
      (bruto['monte'] as List).removeLast();
      expect(() => SnapshotPartida.restaurar(bruto),
          throwsA(isA<ErroSnapshot>()));
    });

    test('SNAP-14 snapshot de formato desconhecido é RECUSADO', () {
      final bruto = SnapshotPartida.capturar(novo());
      bruto['versaoFormato'] = 999;
      expect(
        () => SnapshotPartida.restaurar(bruto),
        throwsA(isA<ErroSnapshot>().having(
            (e) => e.codigo, 'codigo', 'VERSAO_FORMATO_INCOMPATIVEL')),
      );
    });

    test('SNAP-15 snapshot sem o bloco interno é RECUSADO', () {
      final bruto = SnapshotPartida.capturar(novo());
      bruto.remove('interno');
      expect(() => SnapshotPartida.restaurar(bruto),
          throwsA(isA<ErroSnapshot>()));
    });

    test('SNAP-16 vez fora de 0..3 é RECUSADA', () {
      final bruto = SnapshotPartida.capturar(novo());
      bruto['vez'] = 7;
      expect(() => SnapshotPartida.restaurar(bruto),
          throwsA(isA<ErroSnapshot>()));
    });

    test('SNAP-17 mesa já bloqueada continua bloqueada depois da retomada', () {
      final j = novo();
      final bruto = SnapshotPartida.capturar(j);
      bruto['integridadeErro'] = 'DECK_TOTAL_MISMATCH: exemplo';
      final volta = SnapshotPartida.restaurar(bruto);
      expect(volta.integridadeErro, isNotNull);
      expect(volta.comprarMonte(volta.vez), isFalse); // segue recusando jogada
    });

    test('SNAP-18 impressão de mão ignora a ordem das cartas', () {
      final j = novo();
      final a = SnapshotPartida.impressaoDeCartas(j.maos[0]);
      final b = SnapshotPartida.impressaoDeCartas(j.maos[0].reversed.toList());
      expect(a, b);
    });

    test('SNAP-19 impressão de mão muda quando a mão muda', () {
      final j = novo();
      final antes = SnapshotPartida.impressaoDeCartas(j.maos[0]);
      j.comprarMonte(j.vez = 0);
      expect(SnapshotPartida.impressaoDeCartas(j.maos[0]), isNot(antes));
    });

    test('SNAP-20 impressão não depende da ordem das chaves do mapa', () {
      final a = SnapshotPartida.impressao({'x': 1, 'y': 2});
      final b = SnapshotPartida.impressao({'y': 2, 'x': 1});
      expect(a, b);
    });
  });

  // ================= VISAO — o que cada assento pode ver =================

  group('VISAO — recorte por assento', () {
    test('VISAO-01 o assento vê a própria mão inteira', () {
      final j = novo();
      final v = VisaoAssento.de(j, 0);
      final ids = VisaoAssento.idsVisiveis(v);
      for (final c in j.maos[0]) {
        expect(ids, contains(c.id));
      }
    });

    test('VISAO-02 NENHUMA carta de outra mão aparece', () {
      final j = novo();
      final ids = VisaoAssento.idsVisiveis(VisaoAssento.de(j, 0));
      for (var a = 1; a < 4; a++) {
        for (final c in j.maos[a]) {
          expect(ids, isNot(contains(c.id)), reason: 'vazou mão do assento $a');
        }
      }
    });

    test('VISAO-03 NENHUMA carta do monte aparece', () {
      final j = novo();
      final ids = VisaoAssento.idsVisiveis(VisaoAssento.de(j, 0));
      for (final c in j.monte) {
        expect(ids, isNot(contains(c.id)));
      }
    });

    test('VISAO-04 NENHUMA carta dos mortos aparece', () {
      final j = novo();
      final ids = VisaoAssento.idsVisiveis(VisaoAssento.de(j, 0));
      for (final m in j.mortos) {
        for (final c in m) {
          expect(ids, isNot(contains(c.id)));
        }
      }
    });

    test('VISAO-05 os quatro assentos juntos nunca revelam monte nem mortos', () {
      final j = novo();
      final ids = <String>{};
      for (var a = 0; a < 4; a++) {
        ids.addAll(VisaoAssento.idsVisiveis(VisaoAssento.de(j, a)));
      }
      for (final c in j.monte) {
        expect(ids, isNot(contains(c.id)));
      }
      for (final m in j.mortos) {
        for (final c in m) {
          expect(ids, isNot(contains(c.id)));
        }
      }
    });

    test('VISAO-06 o lixo e os jogos baixados são públicos', () {
      final j = novo();
      montar(j, mao0: [('K', 'paus')], mesaNos: [canastraLimpa], lixo: [('3', 'ouros')], vez: 1);
      final ids = VisaoAssento.idsVisiveis(VisaoAssento.de(j, 1));
      expect(ids, contains(j.lixo.first.id));
      for (final c in j.jogosDupla['nos']!.first) {
        expect(ids, contains(c.id));
      }
    });

    test('VISAO-07 contagem das mãos alheias é exposta (informação pública)', () {
      final j = novo();
      j.maos[2] = j.maos[2].sublist(0, 4);
      final v = VisaoAssento.de(j, 0);
      expect((v['cartasNaMao'] as List)[2], 4);
      expect(v['monteRestante'], j.monte.length);
      expect(v['mortosRestantes'], j.mortos.length);
    });

    test('VISAO-08 identidade da mesa: parceiro e adversários corretos', () {
      final v = VisaoAssento.de(novo(), 1);
      expect(v['dupla'], 'eles');
      expect(v['parceiro'], 3);
      expect(v['adversarios'], [2, 0]);
    });

    test('VISAO-09 o id do topo obrigatório só vai para quem tem a carta', () {
      final j = novo('FECHADO');
      montar(j,
          mao0: [('8', 'copas'), ('8', 'ouros'), ('K', 'paus')],
          lixo: [('8', 'paus')],
          vez: 0);
      j.comprarLixo(0, modalidade: 'FECHADO');
      expect(VisaoAssento.de(j, 0)['idTopoObrigatorio'], j.lixoTopoObrigatorio);
      expect(VisaoAssento.de(j, 1)['idTopoObrigatorio'], isNull);
      expect(VisaoAssento.de(j, 1)['obrigacaoTopoPendente'], isTrue);
    });

    test('VISAO-10 o código de integridade não vaza para o cliente', () {
      final j = novo();
      j.maos[0].add(Carta('artificial_7s', 'espadas', '7', false));
      j.auditarIntegridade();
      final v = VisaoAssento.de(j, 0);
      expect(v['mesaBloqueada'], isTrue);
      expect(v.containsKey('integridadeErro'), isFalse);
      expect(v.values.join(' '), isNot(contains('DUPLICATE_RANK')));
    });

    test('VISAO-11 a visão traz tudo que a retomada precisa (§9)', () {
      final v = VisaoAssento.de(novo(), 0);
      for (final campo in [
        'assento', 'parceiro', 'adversarios', 'mao', 'jogosNos', 'jogosEles',
        'lixo', 'monteRestante', 'mortosRestantes', 'placarNos', 'placarEles',
        'minimoParaDescerNos', 'rodada', 'vez', 'relogio', 'presenca',
      ]) {
        expect(v.containsKey(campo), isTrue, reason: 'faltou "$campo"');
      }
    });

    test('VISAO-12 assento fora de 0..3 é recusado', () {
      expect(() => VisaoAssento.de(novo(), 4), throwsArgumentError);
      expect(() => VisaoAssento.de(novo(), -1), throwsArgumentError);
    });

    test('VISAO-13 a impressão da mão acompanha a visão', () {
      final j = novo();
      final v = VisaoAssento.de(j, 0);
      expect(v['impressaoDaMao'], SnapshotPartida.impressaoDeCartas(j.maos[0]));
    });

    test('VISAO-14 o relógio do servidor entra na visão', () {
      final r = RelogioTurno(
          assento: 0, inicioMs: 1000, duracaoMs: 45000, versaoEstado: 7);
      final v = VisaoAssento.de(novo(), 0, relogio: r, versaoEstado: 7);
      expect((v['relogio'] as Map)['duracaoMs'], 45000);
      expect(v['versaoEstado'], 7);
    });
  });

  // ============ IDEM — o mesmo comando não vale duas vezes (§6) ============

  group('IDEM — idempotência por eventoId', () {
    test('IDEM-01 comprar duas vezes com o mesmo eventoId dá 1 carta só', () {
      final m = motorDe(novo());
      final antes = m.jogo.maos[m.jogo.vez].length;
      final cmd = ComandoPartida.comprarMonte(
          eventoId: 'e1', assento: m.jogo.vez);
      expect(m.aplicar(cmd).status, StatusComando.aplicado);
      expect(m.aplicar(cmd).status, StatusComando.duplicado);
      expect(m.jogo.maos[m.jogo.vez].length, antes + 1);
    });

    test('IDEM-02 o reenvio NÃO move a versão do estado', () {
      final m = motorDe(novo());
      final cmd = ComandoPartida.comprarMonte(
          eventoId: 'e1', assento: m.jogo.vez);
      m.aplicar(cmd);
      final v = m.versaoEstado;
      m.aplicar(cmd);
      m.aplicar(cmd);
      expect(m.versaoEstado, v);
    });

    test('IDEM-03 descartar duas vezes com o mesmo eventoId põe 1 carta no lixo', () {
      final j = novo();
      montar(j, mao0: [('K', 'paus'), ('Q', 'paus')], vez: 0, jaComprou: true);
      final m = motorDe(j);
      final cmd = ComandoPartida.descartar(
          eventoId: 'd1', assento: 0, idCarta: j.maos[0].first.id);
      expect(m.aplicar(cmd).status, StatusComando.aplicado);
      expect(m.aplicar(cmd).status, StatusComando.duplicado);
      expect(j.lixo.length, 1);
      expect(j.maos[0].length, 1);
    });

    test('IDEM-04 o duplicado devolve os MESMOS efeitos do original', () {
      final m = motorDe(novo());
      final cmd = ComandoPartida.comprarMonte(
          eventoId: 'e1', assento: m.jogo.vez);
      final a = m.aplicar(cmd);
      final b = m.aplicar(cmd);
      expect(b.efeitos, a.efeitos);
      expect(b.versaoEstado, m.versaoEstado);
    });

    test('IDEM-05 eventoIds diferentes NÃO são confundidos', () {
      final m = motorDe(novo());
      final assento = m.jogo.vez;
      final antes = m.jogo.maos[assento].length;
      m.aplicar(ComandoPartida.comprarMonte(eventoId: 'e1', assento: assento));
      final segundo = m.aplicar(
          ComandoPartida.comprarMonte(eventoId: 'e2', assento: assento));
      // a 2ª compra é recusada por REGRA (já comprou), não por duplicidade
      expect(segundo.codigoErro, ErroComando.regra);
      expect(m.jogo.maos[assento].length, antes + 1);
    });

    test('IDEM-06 comando RECUSADO não entra no cache (pode valer depois)', () {
      final j = novo();
      montar(j, mao0: [('K', 'paus')], mao1: [('Q', 'paus')], vez: 0);
      final m = motorDe(j);
      final cmd = ComandoPartida.comprarMonte(eventoId: 'x1', assento: 1);
      expect(m.aplicar(cmd).codigoErro, ErroComando.foraDeTurno);
      j.vez = 1; // a vez chegou
      expect(m.aplicar(cmd).status, StatusComando.aplicado);
    });

    test('IDEM-07 a janela guarda a quantidade contratada de eventos', () {
      final m = motorDe(novo(), janela: 3);
      for (var i = 0; i < 5; i++) {
        m.aplicar(ComandoPartida.ordenarMao(eventoId: 'o$i', assento: 0));
      }
      expect(m.eventosAplicados, ['o2', 'o3', 'o4']);
    });

    test('IDEM-08 a janela sobrevive ao snapshot (reenvio pós-restauração)', () {
      final m = motorDe(novo());
      final cmd = ComandoPartida.comprarMonte(
          eventoId: 'e1', assento: m.jogo.vez);
      m.aplicar(cmd);
      final volta = MotorPartida.restaurar(m.snapshot());
      final n = volta.jogo.maos[cmd.assento].length;
      expect(volta.aplicar(cmd).status, StatusComando.duplicado);
      expect(volta.jogo.maos[cmd.assento].length, n);
    });

    test('IDEM-09 nova rodada limpa a janela (baralho novo, ids novos)', () {
      final j = novo();
      montar(j, mao0: [('K', 'paus')], vez: 0, jaComprou: true, mortoPegoNos: true, mesaNos: [canastraLimpa]);
      final m = motorDe(j);
      m.aplicar(ComandoPartida.descartar(
          eventoId: 'd1', assento: 0, idCarta: j.maos[0].first.id));
      m.apurarRodada();
      m.iniciarNovaRodada();
      expect(m.eventosAplicados, isEmpty);
    });

    test('IDEM-10 conduzirRobo também é idempotente', () {
      final m = motorDe(novo());
      final assento = m.jogo.vez;
      final a = m.conduzirRobo(assento, eventoId: 'r1');
      final antes = m.impressao;
      final b = m.conduzirRobo(assento, eventoId: 'r1');
      expect(a.status, StatusComando.aplicado);
      expect(b.status, StatusComando.duplicado);
      expect(m.impressao, antes);
    });
  });

  // ============ CONC — dois comandos quase simultâneos (§6) ============

  group('CONC — concorrência e versão do estado', () {
    test('CONC-01 versão sobe exatamente 1 por comando aceito', () {
      final m = motorDe(novo());
      expect(m.versaoEstado, 0);
      m.aplicar(ComandoPartida.comprarMonte(
          eventoId: 'e1', assento: m.jogo.vez));
      expect(m.versaoEstado, 1);
    });

    test('CONC-02 comando com versão velha é RECUSADO e nada muda', () {
      final m = motorDe(novo());
      final assento = m.jogo.vez;
      m.aplicar(ComandoPartida.comprarMonte(eventoId: 'e1', assento: assento));
      final impressao = m.impressao;
      final r = m.aplicar(ComandoPartida.comprarMonte(
          eventoId: 'e2', assento: assento, versaoEsperada: 0));
      expect(r.codigoErro, ErroComando.versaoDesatualizada);
      expect(m.impressao, impressao);
      expect(m.versaoEstado, 1);
    });

    test('CONC-03 dois cliques quase simultâneos: o 2º perde a corrida', () {
      final j = novo();
      montar(j, mao0: [('K', 'paus'), ('Q', 'paus')], vez: 0, jaComprou: true);
      final m = motorDe(j);
      // as duas telas viram a versão 0 e mandaram descartes diferentes
      final a = ComandoPartida.descartar(
          eventoId: 'a', assento: 0, idCarta: j.maos[0][0].id, versaoEsperada: 0);
      final b = ComandoPartida.descartar(
          eventoId: 'b', assento: 0, idCarta: j.maos[0][1].id, versaoEsperada: 0);
      expect(m.aplicar(a).status, StatusComando.aplicado);
      expect(m.aplicar(b).codigoErro, ErroComando.versaoDesatualizada);
      expect(j.lixo.length, 1);
    });

    test('CONC-04 o reenvio é reconhecido ANTES da conferência de versão', () {
      // Regressão da ordem das checagens: um reenvio depois de queda carrega a
      // versão antiga. Se a versão fosse conferida primeiro, o cliente
      // concluiria que a jogada se perdeu.
      final m = motorDe(novo());
      final assento = m.jogo.vez;
      final cmd = ComandoPartida.comprarMonte(
          eventoId: 'e1', assento: assento, versaoEsperada: 0);
      expect(m.aplicar(cmd).status, StatusComando.aplicado);
      final r = m.aplicar(cmd); // versaoEsperada 0, versão atual 1
      expect(r.status, StatusComando.duplicado);
      expect(r.codigoErro, isNull);
    });

    test('CONC-05 sem versaoEsperada o comando aplica sobre qualquer versão', () {
      final m = motorDe(novo());
      m.aplicar(ComandoPartida.ordenarMao(eventoId: 'o1', assento: 0));
      final r = m.aplicar(ComandoPartida.comprarMonte(
          eventoId: 'e1', assento: m.jogo.vez));
      expect(r.status, StatusComando.aplicado);
    });

    test('CONC-06 apuração e nova rodada movem a versão', () {
      final j = novo();
      montar(j, mao0: [('K', 'paus')], vez: 0, jaComprou: true, mortoPegoNos: true, mesaNos: [canastraLimpa]);
      final m = motorDe(j);
      m.aplicar(ComandoPartida.descartar(
          eventoId: 'd1', assento: 0, idCarta: j.maos[0].first.id));
      final v = m.versaoEstado;
      expect(m.apurarRodada(), isTrue);
      expect(m.versaoEstado, v + 1);
      expect(m.apurarRodada(), isFalse); // não conta duas vezes
      expect(m.versaoEstado, v + 1);
    });

    test('CONC-07 a versão atravessa o snapshot', () {
      final m = motorDe(novo());
      m.aplicar(ComandoPartida.comprarMonte(
          eventoId: 'e1', assento: m.jogo.vez));
      final volta = MotorPartida.restaurar(m.snapshot());
      expect(volta.versaoEstado, m.versaoEstado);
    });
  });

  // ============ TURNO — nenhuma ação inválida altera o estado ============

  group('TURNO — autoridade de turno e envelope', () {
    test('TURNO-01 jogar fora da vez é recusado sem alterar nada', () {
      final j = novo();
      montar(j, mao0: [('K', 'paus')], mao1: [('Q', 'paus')], vez: 0);
      final m = motorDe(j);
      final impressao = m.impressao;
      final r = m.aplicar(
          ComandoPartida.comprarMonte(eventoId: 'x', assento: 1));
      expect(r.codigoErro, ErroComando.foraDeTurno);
      expect(m.impressao, impressao);
      expect(m.versaoEstado, 0);
    });

    test('TURNO-02 assento fora de 0..3 é recusado', () {
      final m = motorDe(novo());
      expect(m.aplicar(ComandoPartida.comprarMonte(eventoId: 'x', assento: 9))
          .codigoErro, ErroComando.assentoInvalido);
      expect(m.aplicar(ComandoPartida.comprarMonte(eventoId: 'y', assento: -1))
          .codigoErro, ErroComando.assentoInvalido);
    });

    test('TURNO-03 eventoId vazio é recusado', () {
      final m = motorDe(novo());
      expect(m.aplicar(ComandoPartida.comprarMonte(eventoId: '  ', assento: 0))
          .codigoErro, ErroComando.comandoInvalido);
    });

    test('TURNO-04 envelope incompleto é recusado antes de tocar no motor', () {
      final m = motorDe(novo());
      final semIds = ComandoPartida(
          eventoId: 'a', assento: 0, tipo: TipoComando.baixar);
      final semIndice = ComandoPartida(
          eventoId: 'b', assento: 0, tipo: TipoComando.estender, ids: ['c1']);
      expect(m.aplicar(semIds).codigoErro, ErroComando.comandoInvalido);
      expect(m.aplicar(semIndice).codigoErro, ErroComando.comandoInvalido);
      expect(m.versaoEstado, 0);
    });

    test('TURNO-05 mesa bloqueada recusa tudo com ESTADO_CORROMPIDO', () {
      final j = novo();
      j.maos[0].add(Carta('artificial_7s', 'espadas', '7', false));
      j.auditarIntegridade();
      final m = motorDe(j);
      final r = m.aplicar(
          ComandoPartida.comprarMonte(eventoId: 'x', assento: j.vez));
      expect(r.codigoErro, ErroComando.estadoCorrompido);
      expect(m.versaoEstado, 0);
    });

    test('TURNO-06 rodada encerrada recusa jogada', () {
      final j = novo();
      j.rodadaEncerrada = true;
      final m = motorDe(j);
      expect(
          m.aplicar(ComandoPartida.comprarMonte(eventoId: 'x', assento: j.vez))
              .codigoErro,
          ErroComando.rodadaEncerrada);
    });

    test('TURNO-07 partida encerrada recusa jogada', () {
      final j = novo();
      j.encerrada = true;
      final m = motorDe(j);
      expect(
          m.aplicar(ComandoPartida.comprarMonte(eventoId: 'x', assento: j.vez))
              .codigoErro,
          ErroComando.partidaEncerrada);
    });

    test('TURNO-08 jogada ilegal pela REGRA não altera o estado', () {
      final j = novo();
      montar(j, mao0: [('5', 'copas'), ('6', 'copas'), ('8', 'copas')],
          vez: 0, jaComprou: true);
      final m = motorDe(j);
      final impressao = m.impressao;
      final r = m.aplicar(ComandoPartida.baixar(
          eventoId: 'b1', assento: 0, ids: [for (final c in j.maos[0]) c.id]));
      expect(r.codigoErro, ErroComando.regra);
      expect(r.mensagem, isNotNull);
      expect(m.impressao, impressao);
      expect(m.versaoEstado, 0);
    });

    test('TURNO-09 ordenar a mão não depende de turno e não muda as cartas', () {
      final j = novo();
      final m = motorDe(j);
      final impressao = SnapshotPartida.impressaoDeCartas(j.maos[2]);
      final r = m.aplicar(ComandoPartida.ordenarMao(eventoId: 'o', assento: 2));
      expect(r.status, StatusComando.aplicado);
      expect(SnapshotPartida.impressaoDeCartas(j.maos[2]), impressao);
    });

    test('TURNO-10 o robô passa pelas mesmas travas de turno', () {
      final j = novo();
      montar(j, mao0: [('K', 'paus')], vez: 0);
      final m = motorDe(j);
      expect(m.conduzirRobo(1, eventoId: 'r1').codigoErro,
          ErroComando.foraDeTurno);
      expect(m.versaoEstado, 0);
    });
  });

  // ==================== RELOGIO — tempo de jogada (§7) ====================

  group('RELOGIO — prazo do turno', () {
    final r = RelogioTurno(
        assento: 0, inicioMs: 100000, duracaoMs: 45000, versaoEstado: 3);

    test('RELOGIO-01 o prazo é um instante, não um contador', () {
      expect(r.fimMs, 145000);
      expect(r.restanteMs(100000), 45000);
      expect(r.restanteMs(130000), 15000);
    });

    test('RELOGIO-02 nunca fica negativo', () {
      expect(r.restanteMs(999999), 0);
      expect(r.restanteSegundos(999999), 0);
    });

    test('RELOGIO-03 app em segundo plano: o prazo acerta sozinho na volta', () {
      // 60 s fora do ar num turno de 45 s. Um contador local mostraria 45;
      // o prazo mostra 0 e já sabe que estourou.
      expect(r.expirou(160000), isTrue);
      expect(r.restanteSegundos(160000), 0);
    });

    test('RELOGIO-04 segundos são arredondados para cima', () {
      expect(r.restanteSegundos(144999), 1); // 1 ms restante ainda é "1"
      expect(r.restanteSegundos(145000), 0);
    });

    test('RELOGIO-05 fração decorrida fica entre 0 e 1', () {
      expect(r.fracaoDecorrida(100000), 0);
      expect(r.fracaoDecorrida(122500), closeTo(0.5, 0.001));
      expect(r.fracaoDecorrida(999999), 1);
    });

    test('RELOGIO-06 relógio do servidor é autoridade; o local não é', () {
      expect(r.ehAutoridade, isTrue);
      final local = RelogioTurno.provisorio(
          assento: 0, inicioMs: 0, duracaoMs: 1000);
      expect(local.ehAutoridade, isFalse);
    });

    test('RELOGIO-07 relógio de versão antiga é reconhecido como vencido', () {
      expect(r.valeParaVersao(3), isTrue);
      expect(r.valeParaVersao(4), isFalse);
    });

    test('RELOGIO-08 ida e volta em JSON preserva o prazo', () {
      final volta = RelogioTurno.deJson(r.toJson());
      expect(volta!.fimMs, r.fimMs);
      expect(volta.ehAutoridade, isTrue);
    });

    test('RELOGIO-09 duração inválida não vira relógio', () {
      expect(
          RelogioTurno.deJson(
              {'assento': 0, 'inicioMs': 1, 'duracaoMs': 0}),
          isNull);
      expect(RelogioTurno.deJson('lixo'), isNull);
    });

    test('RELOGIO-10 relógio do aparelho errado é corrigido pelo offset', () {
      // O celular está 5 minutos adiantado. Sem correção, o prazo do servidor
      // pareceria vencido há muito tempo.
      final s = SincronizacaoRelogio();
      const erroDoAparelho = 300000;
      s.registrarAmostra(
        enviadoEm: 100000 + erroDoAparelho,
        recebidoEm: 100200 + erroDoAparelho,
        servidorEm: 100100,
      );
      expect(s.offsetMs, closeTo(-erroDoAparelho, 5));
      expect(r.restanteSegundos(s.agoraNoServidor(130000 + erroDoAparelho)), 15);
    });

    test('RELOGIO-11 amostra com ida-e-volta pior não estraga o offset', () {
      final s = SincronizacaoRelogio();
      s.registrarAmostra(enviadoEm: 1000, recebidoEm: 1020, servidorEm: 1010);
      final bom = s.offsetMs;
      s.registrarAmostra(enviadoEm: 2000, recebidoEm: 5000, servidorEm: 2100);
      expect(s.offsetMs, bom);
      expect(s.amostras, 2);
    });

    test('RELOGIO-12 sem amostra o offset é neutro', () {
      final s = SincronizacaoRelogio();
      expect(s.sincronizado, isFalse);
      expect(s.agoraNoServidor(123), 123);
    });

    test('RELOGIO-13 expiração é um registro do servidor, não do cliente', () {
      final e = ExpiracaoTurno.deJson({
        'assento': 2,
        'rodada': 3,
        'emMs': 500,
        'acao': 'jogadaAutomatica',
        'versaoEstado': 9,
      });
      expect(e!.acao, AcaoPorExpiracao.jogadaAutomatica);
      expect(e.versaoEstado, 9);
      expect(ExpiracaoTurno.deJson({'assento': 1, 'emMs': 1, 'acao': 'x'}), isNull);
    });
  });

  // ============== PRES — presença, abandono e substituição ==============

  group('PRES — presença e conexão', () {
    const p = PoliticaPresenca();

    test('PRES-01 heartbeat recente é online', () {
      expect(p.classificar(ultimoHeartbeatMs: 0, agoraMs: 5000),
          EstadoPresenca.online);
    });

    test('PRES-02 pequena oscilação NÃO tira ninguém da partida', () {
      // 11 s de silêncio: um túnel, um elevador. Ainda online.
      expect(p.classificar(ultimoHeartbeatMs: 0, agoraMs: 11000),
          EstadoPresenca.online);
    });

    test('PRES-03 silêncio médio vira instável (degrau intermediário)', () {
      expect(p.classificar(ultimoHeartbeatMs: 0, agoraMs: 20000),
          EstadoPresenca.instavel);
    });

    test('PRES-04 silêncio longo vira ausente', () {
      expect(p.classificar(ultimoHeartbeatMs: 0, agoraMs: 60000),
          EstadoPresenca.ausente);
    });

    test('PRES-05 a avaliação local NUNCA declara abandono nem robô', () {
      final mapa = MapaPresenca();
      mapa.registrarHeartbeat(1, 0);
      for (final agora in [0, 20000, 60000, 600000, 86400000]) {
        mapa.reavaliarLocalmente(agora);
        expect(mapa.estadoDe(1).ehTerminal, isFalse,
            reason: 'o cliente declarou estado terminal em t=$agora');
      }
      expect(mapa.estadoDe(1), EstadoPresenca.ausente);
    });

    test('PRES-06 só o servidor declara abandono', () {
      final mapa = MapaPresenca();
      mapa.registrarHeartbeat(2, 0);
      mapa.aplicarDoServidor([
        {'assento': 2, 'estado': 'abandonou', 'ultimoHeartbeatMs': 0, 'desdeMs': 90000}
      ]);
      expect(mapa.estadoDe(2), EstadoPresenca.abandonou);
      expect(mapa[2]!.doServidor, isTrue);
    });

    test('PRES-07 heartbeat não ressuscita quem o servidor declarou terminal', () {
      final mapa = MapaPresenca();
      mapa.aplicarDoServidor([
        {'assento': 3, 'estado': 'substituidoPorRobo', 'ultimoHeartbeatMs': 0, 'desdeMs': 0}
      ]);
      mapa.registrarHeartbeat(3, 999999);
      expect(mapa.estadoDe(3), EstadoPresenca.substituidoPorRobo);
    });

    test('PRES-08 a avaliação local não mexe em assento terminal', () {
      final mapa = MapaPresenca();
      mapa.aplicarDoServidor([
        {'assento': 0, 'estado': 'abandonou', 'ultimoHeartbeatMs': 0, 'desdeMs': 0}
      ]);
      mapa.reavaliarLocalmente(10000000);
      expect(mapa.estadoDe(0), EstadoPresenca.abandonou);
    });

    test('PRES-09 o retorno do jogador restabelece online', () {
      final mapa = MapaPresenca();
      mapa.registrarHeartbeat(1, 0);
      mapa.reavaliarLocalmente(60000);
      expect(mapa.estadoDe(1), EstadoPresenca.ausente);
      mapa.registrarHeartbeat(1, 61000);
      expect(mapa.estadoDe(1), EstadoPresenca.online);
    });

    test('PRES-10 contagem até o abandono ser possível é só informativa', () {
      final mapa = MapaPresenca();
      mapa.registrarHeartbeat(1, 0);
      expect(mapa.msAteAbandonoPossivel(1, 0), 45000 + 180000);
      expect(mapa.msAteAbandonoPossivel(1, 10000000), 0);
      // e continuar zerada não declarou nada
      mapa.reavaliarLocalmente(10000000);
      expect(mapa.estadoDe(1).ehTerminal, isFalse);
    });

    test('PRES-11 os parâmetros do servidor substituem os padrões', () {
      final vindos = ParametrosPresenca.deJson(
          {'toleranciaInstavelMs': 3000, 'toleranciaAusenteMs': 8000});
      final pol = PoliticaPresenca(vindos);
      expect(pol.classificar(ultimoHeartbeatMs: 0, agoraMs: 4000),
          EstadoPresenca.instavel);
      expect(pol.classificar(ultimoHeartbeatMs: 0, agoraMs: 9000),
          EstadoPresenca.ausente);
    });

    test('PRES-12 registro de abandono é lido, não calculado', () {
      final reg = RegistroAbandono.deJson({
        'partidaId': 'p1',
        'assento': 2,
        'motivo': 'ausenciaProlongada',
        'emMs': 500,
        'rodada': 3,
        'substituidoPorRobo': true,
        'retornoPermitido': true,
        'penalidadePontos': -100,
      });
      expect(reg!.motivo, MotivoSaida.ausenciaProlongada);
      expect(reg.substituidoPorRobo, isTrue);
      expect(reg.penalidadePontos, -100);
    });

    test('PRES-13 penalidade não informada é null, nunca zero inventado', () {
      final reg = RegistroAbandono.deJson({
        'assento': 0, 'motivo': 'voluntario', 'emMs': 1, 'rodada': 1,
      });
      expect(reg!.penalidadePontos, isNull);
    });

    test('PRES-14 motivo desconhecido não vira registro', () {
      expect(
          RegistroAbandono.deJson(
              {'assento': 0, 'motivo': 'inventado', 'emMs': 1}),
          isNull);
    });
  });

  // ============= RECON — queda e volta no lado do app (§9) =============

  group('RECON — sessão de reconexão', () {
    SessaoReconexao sessao([RelogioFake? r]) => SessaoReconexao(
          partidaId: 'p-teste',
          ids: GeradorEventoId('s1'),
          agora: (r ?? RelogioFake()).ler,
        );

    test('RECON-01 comando enviado fica pendente até a confirmação', () {
      final s = sessao();
      final cmd = s.novoComando(assento: 0, tipo: TipoComando.comprarMonte);
      s.registrarEnvio(cmd);
      expect(s.temPendencias, isTrue);
      s.confirmar(ResultadoComando(
          eventoId: cmd.eventoId,
          status: StatusComando.aplicado,
          versaoEstado: 1));
      expect(s.temPendencias, isFalse);
    });

    test('RECON-02 na volta o MESMO eventoId é reenviado', () {
      final s = sessao();
      final cmd = s.novoComando(assento: 0, tipo: TipoComando.comprarMonte);
      s.registrarEnvio(cmd);
      s.aoCair();
      final reenviar = s.aoReconectar();
      expect(reenviar.map((c) => c.eventoId), [cmd.eventoId]);
    });

    test('RECON-03 QUEDA DURANTE A COMPRA: o reenvio não compra duas vezes', () {
      final m = motorDe(novo());
      final assento = m.jogo.vez;
      final s = sessao();
      final cmd = s.novoComando(
          assento: assento, tipo: TipoComando.comprarMonte);
      s.registrarEnvio(cmd);
      final antes = m.jogo.maos[assento].length;
      m.aplicar(cmd); // o servidor recebeu…
      s.aoCair(); //    …mas a resposta se perdeu
      for (final r in s.aoReconectar()) {
        expect(m.aplicar(r).status, StatusComando.duplicado);
      }
      expect(m.jogo.maos[assento].length, antes + 1);
      expect(totalCartas(m.jogo), 108);
    });

    test('RECON-04 QUEDA DURANTE O DESCARTE: a carta não volta para a mão', () {
      final j = novo();
      montar(j, mao0: [('K', 'paus'), ('Q', 'paus')], vez: 0, jaComprou: true);
      final m = motorDe(j);
      final s = sessao();
      final cmd = s.novoComando(
          assento: 0,
          tipo: TipoComando.descartar,
          cartas: [j.maos[0].first.id]);
      s.registrarEnvio(cmd);
      m.aplicar(cmd);
      s.aoCair();
      for (final r in s.aoReconectar()) {
        m.aplicar(r);
      }
      expect(j.lixo.length, 1);
      expect(j.maos[0].length, 1);
      expect(totalCartas(j), 108);
    });

    test('RECON-05 QUEDA DURANTE O ENCERRAMENTO: a batida não se perde', () {
      final j = novo();
      montar(j, mao0: [('K', 'paus')], vez: 0, jaComprou: true,
          mortoPegoNos: true, mesaNos: [canastraLimpa]);
      final m = motorDe(j);
      final s = sessao();
      final cmd = s.novoComando(
          assento: 0,
          tipo: TipoComando.descartar,
          cartas: [j.maos[0].first.id]);
      s.registrarEnvio(cmd);
      m.aplicar(cmd);
      expect(j.rodadaEncerrada, isTrue);
      // o app cai antes de saber que bateu; o estado é persistido e restaurado
      final volta = MotorPartida.restaurar(m.snapshot());
      expect(volta.jogo.rodadaEncerrada, isTrue);
      expect(volta.jogo.duplaQueBateu, 'nos');
      for (final r in s.aoReconectar()) {
        expect(volta.aplicar(r).status, StatusComando.duplicado);
      }
      expect(volta.jogo.lixo.length, 1);
    });

    test('RECON-06 RETOMADA DO ASSENTO: a visão volta idêntica', () {
      final m = motorDe(novo());
      m.aplicar(ComandoPartida.comprarMonte(
          eventoId: 'e1', assento: m.jogo.vez));
      final antes = m.visaoDe(0);
      final volta = MotorPartida.restaurar(m.snapshot());
      expect(volta.visaoDe(0), antes);
    });

    test('RECON-07 visão com versão MENOR é descartada (a carta não volta)', () {
      final s = sessao();
      expect(s.aplicarVisaoDoServidor({'versaoEstado': 5, 'assento': 0}), isTrue);
      expect(s.aplicarVisaoDoServidor({'versaoEstado': 3, 'assento': 0}), isFalse);
      expect(s.versaoAplicada, 5);
    });

    test('RECON-08 visão repetida é ignorada', () {
      final s = sessao();
      expect(s.aplicarVisaoDoServidor({'versaoEstado': 5}), isTrue);
      expect(s.aplicarVisaoDoServidor({'versaoEstado': 5}), isFalse);
    });

    test('RECON-09 visão mais nova é adotada', () {
      final s = sessao();
      s.aplicarVisaoDoServidor({'versaoEstado': 5});
      expect(s.aplicarVisaoDoServidor({'versaoEstado': 6, 'assento': 2}), isTrue);
      expect(s.versaoAplicada, 6);
      expect(s.meuAssento, 2);
    });

    test('RECON-10 visão malformada não derruba a sessão', () {
      final s = sessao();
      expect(s.aplicarVisaoDoServidor(null), isFalse);
      expect(s.aplicarVisaoDoServidor('lixo'), isFalse);
      expect(s.aplicarVisaoDoServidor({'semVersao': 1}), isFalse);
      expect(s.versaoAplicada, -1);
    });

    test('RECON-11 o comando nasce travado na versão que o jogador viu', () {
      final s = sessao();
      s.aplicarVisaoDoServidor({'versaoEstado': 4});
      final cmd = s.novoComando(assento: 0, tipo: TipoComando.comprarMonte);
      expect(cmd.versaoEsperada, 4);
    });

    test('RECON-12 sem estado conhecido o comando não trava em versão', () {
      final cmd =
          sessao().novoComando(assento: 0, tipo: TipoComando.comprarMonte);
      expect(cmd.versaoEsperada, isNull);
    });

    test('RECON-13 depois de insistir demais o app pede o estado inteiro', () {
      final s = SessaoReconexao(
          partidaId: 'p', ids: GeradorEventoId('s'), maxTentativas: 3);
      s.aplicarVisaoDoServidor({'versaoEstado': 1}); // já conhece a partida
      final cmd = s.novoComando(assento: 0, tipo: TipoComando.comprarMonte);
      s.registrarEnvio(cmd);
      for (var i = 0; i < 5; i++) {
        s.aoReconectar();
      }
      expect(s.desistidos.map((c) => c.eventoId), [cmd.eventoId]);
      expect(s.precisaRetomadaCompleta, isTrue);
      s.retomadaConcluida();
      expect(s.precisaRetomadaCompleta, isFalse);
    });

    test('RECON-14 a presença vinda na visão é adotada', () {
      final s = sessao();
      s.aplicarVisaoDoServidor({
        'versaoEstado': 1,
        'presenca': {
          'assentos': [
            {'assento': 1, 'estado': 'instavel', 'ultimoHeartbeatMs': 0, 'desdeMs': 0}
          ]
        }
      });
      expect(s.presenca.estadoDe(1), EstadoPresenca.instavel);
    });

    test('RECON-15 o relógio da visão alimenta a barra de tempo', () {
      final s = sessao();
      s.aplicarVisaoDoServidor({
        'versaoEstado': 1,
        'relogio': {
          'assento': 0, 'inicioMs': 100000, 'duracaoMs': 45000,
          'versaoEstado': 1, 'fonte': 'servidor',
        }
      });
      s.calibrarRelogio(enviadoEm: 0, recebidoEm: 100, servidorEm: 50);
      expect(s.segundosRestantes(130000), 15);
    });

    test('RECON-16 sem relógio conhecido a barra não inventa tempo', () {
      expect(sessao().segundosRestantes(1000), isNull);
    });

    test('RECON-17 os eventoIds gerados são únicos na sessão', () {
      final g = GeradorEventoId('sessao-x');
      final ids = {for (var i = 0; i < 200; i++) g.proximo()};
      expect(ids.length, 200);
    });
  });

  // ==================== LOG — diagnóstico técnico (§13) ====================

  group('LOG — diário da partida', () {
    test('LOG-01 comando aceito registra versão antes e depois', () {
      final m = motorDe(novo());
      m.aplicar(ComandoPartida.comprarMonte(
          eventoId: 'e1', assento: m.jogo.vez));
      final e = m.diario.eventos.last;
      expect(e.acao, 'COMPRAR_MONTE');
      expect(e.versaoAntes, 0);
      expect(e.versaoDepois, 1);
      expect(e.eventoId, 'e1');
    });

    test('LOG-02 rejeição registra o código auditável', () {
      final j = novo();
      montar(j, mao0: [('K', 'paus')], vez: 0);
      final m = motorDe(j);
      m.aplicar(ComandoPartida.comprarMonte(eventoId: 'x', assento: 1));
      expect(m.diario.eventos.last.erro, ErroComando.foraDeTurno);
      expect(m.diario.eventos.last.tipo, TipoEvento.rejeicao);
    });

    test('LOG-03 o reenvio aparece marcado como duplicado', () {
      final m = motorDe(novo());
      final cmd = ComandoPartida.comprarMonte(
          eventoId: 'e1', assento: m.jogo.vez);
      m.aplicar(cmd);
      m.aplicar(cmd);
      expect(m.diario.eventos.last.tipo, TipoEvento.duplicado);
    });

    test('LOG-04 NENHUM id de carta aparece no despejo do diário', () {
      // É a garantia central do §13: o log serve para investigar, não para
      // reconstruir a mão de ninguém.
      final j = novo();
      montar(j, mao0: [('K', 'paus'), ('Q', 'paus')], vez: 0, jaComprou: true);
      final m = motorDe(j);
      m.aplicar(ComandoPartida.descartar(
          eventoId: 'd1', assento: 0, idCarta: j.maos[0].first.id));
      m.conduzirRobo(m.jogo.vez, eventoId: 'r1');
      final despejo = m.diario.paraJsonl();
      for (final c in zonasTodas(j)) {
        expect(despejo, isNot(contains(c.id)), reason: 'vazou a carta ${c.id}');
      }
    });

    test('LOG-05 chave sensível é censurada em vez de gravada', () {
      final e = EventoDiagnostico(
        ts: 1,
        partidaId: 'p',
        tipo: TipoEvento.comando,
        acao: 'X',
        dados: {'mao': 'A-K-Q', 'monte': 42, 'qtdCartas': 3},
      );
      expect(e.dados['mao'], '<omitido>');
      expect(e.dados['monte'], '<omitido>');
      expect(e.dados['qtdCartas'], 3);
    });

    test('LOG-06 estrutura aninhada não passa pelo filtro', () {
      final e = EventoDiagnostico(
        ts: 1, partidaId: 'p', tipo: TipoEvento.comando, acao: 'X',
        dados: {'qualquer': {'id': 'c7', 'valor': 'K'}},
      );
      expect(e.dados['qualquer'], '<omitido>');
    });

    test('LOG-07 a impressão da mão entra no log (e é hash, não carta)', () {
      final m = motorDe(novo());
      m.aplicar(ComandoPartida.comprarMonte(
          eventoId: 'e1', assento: m.jogo.vez));
      final impressao = m.diario.eventos.last.dados['impressaoDaMao'];
      expect(impressao, isA<String>());
      expect(impressao, DiarioPartida.impressaoDaMao(m.jogo, m.diario.eventos.last.assento!));
    });

    test('LOG-08 a impressão prova ONDE a mão mudou', () {
      final j = novo();
      montar(j, mao0: [('K', 'paus'), ('Q', 'paus')], vez: 0, jaComprou: true);
      final m = motorDe(j);
      final antes = DiarioPartida.impressaoDaMao(j, 0);
      m.aplicar(ComandoPartida.descartar(
          eventoId: 'd1', assento: 0, idCarta: j.maos[0].first.id));
      final depois = m.diario.eventos.last.dados['impressaoDaMao'];
      expect(depois, isNot(antes));
    });

    test('LOG-09 o diário é circular e informa quanto descartou', () {
      final d = DiarioPartida('p', capacidade: 3);
      for (var i = 0; i < 10; i++) {
        d.anotar(ts: i, tipo: TipoEvento.comando, acao: 'A$i');
      }
      expect(d.tamanho, 3);
      expect(d.descartados, 7);
      expect(d.eventos.first.acao, 'A7');
    });

    test('LOG-10 a mesa travar por integridade fica registrado', () {
      final j = novo();
      montar(j, mao0: [('K', 'paus'), ('Q', 'paus')], vez: 0, jaComprou: true);
      final m = motorDe(j);
      j.mortos.first.add(j.monte.first); // a mesma carta em duas zonas
      m.aplicar(ComandoPartida.descartar(
          eventoId: 'd1', assento: 0, idCarta: j.maos[0].first.id));
      expect(m.diario.eventos.any((e) => e.acao == 'MESA_BLOQUEADA'), isTrue);
    });

    test('LOG-11 a restauração é registrada', () {
      final m = motorDe(novo());
      final volta = MotorPartida.restaurar(m.snapshot());
      expect(volta.diario.eventos.last.acao, 'PARTIDA_RESTAURADA');
    });

    test('LOG-12 a sessão registra queda, volta e visão descartada', () {
      final s = SessaoReconexao(partidaId: 'p', ids: GeradorEventoId('s'));
      s.aplicarVisaoDoServidor({'versaoEstado': 5});
      s.aoCair();
      s.aoReconectar();
      s.aplicarVisaoDoServidor({'versaoEstado': 2});
      final acoes = [for (final e in s.diario.eventos) e.acao];
      expect(acoes, containsAll(
          ['VISAO_APLICADA', 'CONEXAO_PERDIDA', 'RECONECTADO', 'VISAO_DESCARTADA']));
    });

    test('LOG-13 "minha mão estava diferente" fica marcado na volta', () {
      final s = SessaoReconexao(partidaId: 'p', ids: GeradorEventoId('s'));
      s.aplicarVisaoDoServidor({'versaoEstado': 1, 'impressaoDaMao': 'aaa'});
      s.aplicarVisaoDoServidor({'versaoEstado': 2, 'impressaoDaMao': 'bbb'});
      expect(s.diario.eventos.last.dados['maoMudou'], isTrue);
    });
  });

  // ============ MODAL — as três modalidades pela mesma porta ============

  group('MODAL — Aberto, Fechado e STBL', () {
    test('MODAL-01 Aberto: pegar o lixo é livre pelo MotorPartida', () {
      final j = novo('ABERTO');
      montar(j, mao0: [('K', 'paus'), ('Q', 'paus')],
          lixo: [('3', 'ouros'), ('9', 'espadas')], vez: 0);
      final m = motorDe(j);
      expect(
          m.aplicar(ComandoPartida.comprarLixo(eventoId: 'l', assento: 0))
              .status,
          StatusComando.aplicado);
    });

    test('MODAL-02 Fechado: topo sem uso é recusado pelo MotorPartida', () {
      final j = novo('FECHADO');
      montar(j, mao0: [('K', 'paus'), ('Q', 'paus')],
          lixo: [('3', 'ouros')], vez: 0);
      final m = motorDe(j);
      final r = m.aplicar(ComandoPartida.comprarLixo(eventoId: 'l', assento: 0));
      expect(r.codigoErro, ErroComando.regra);
      expect(j.lixo.length, 1); // lixo intacto
      expect(m.versaoEstado, 0);
    });

    test('MODAL-03 Fechado: topo com uso é aceito e cria a obrigação', () {
      final j = novo('FECHADO');
      montar(j,
          mao0: [('8', 'copas'), ('8', 'ouros'), ('K', 'paus')],
          lixo: [('8', 'paus')], vez: 0);
      final m = motorDe(j);
      expect(
          m.aplicar(ComandoPartida.comprarLixo(eventoId: 'l', assento: 0))
              .status,
          StatusComando.aplicado);
      expect(m.visaoDe(0)['idTopoObrigatorio'], isNotNull);
    });

    test('MODAL-04 STBL usa a trava do Fechado para o lixo', () {
      final j = novo('STBL');
      montar(j, mao0: [('K', 'paus'), ('Q', 'paus')],
          lixo: [('3', 'ouros')], vez: 0);
      final m = motorDe(j);
      expect(
          m.aplicar(ComandoPartida.comprarLixo(eventoId: 'l', assento: 0))
              .codigoErro,
          ErroComando.regra);
    });

    for (final modalidade in ['ABERTO', 'FECHADO', 'SBTL']) {
      test('MODAL-05-$modalidade snapshot preserva a modalidade e as regras', () {
        final j = novo(modalidade);
        final volta = SnapshotPartida.restaurar(SnapshotPartida.capturar(j));
        expect(volta.modalidade, modalidade);
        expect(volta.auditarIntegridade(), isTrue);
      });
    }
  });

  // ============ E2E — partidas inteiras pela porta resiliente ============

  group('E2E — partida completa pelo MotorPartida', () {
    for (final modalidade in ['ABERTO', 'FECHADO', 'SBTL']) {
      test('E2E-$modalidade robôs jogam 200 turnos com estado sempre íntegro', () {
        final m = motorDe(novo(modalidade));
        var versaoAnterior = m.versaoEstado;
        for (var t = 0; t < 200; t++) {
          if (m.jogo.encerrada) break;
          if (m.jogo.rodadaEncerrada) {
            m.apurarRodada();
            if (m.jogo.encerrada) break;
            m.iniciarNovaRodada();
            versaoAnterior = m.versaoEstado;
            continue;
          }
          final r = m.conduzirRobo(m.jogo.vez, eventoId: 't$t');
          if (r.status == StatusComando.aplicado) {
            expect(m.versaoEstado, greaterThan(versaoAnterior));
            versaoAnterior = m.versaoEstado;
          }
          expect(totalCartas(m.jogo), 108, reason: 'turno $t');
          expect(m.jogo.integridadeErro, isNull, reason: 'turno $t');
        }
      });
    }

    test('E2E-SNAP retomada no meio de uma partida de robôs mantém tudo', () {
      final m = motorDe(novo());
      for (var t = 0; t < 12 && !m.jogo.rodadaEncerrada; t++) {
        m.conduzirRobo(m.jogo.vez, eventoId: 't$t');
      }
      final antes = m.snapshot();
      final volta = MotorPartida.restaurar(antes);
      expect(volta.snapshot()['jogo'], antes['jogo']);
      expect(volta.versaoEstado, m.versaoEstado);
      expect(volta.visaoDe(0), m.visaoDe(0));
      expect(totalCartas(volta.jogo), 108);
    });

    test('E2E-VISAO durante uma partida de robôs nada vaza para o assento 0', () {
      final m = motorDe(novo());
      for (var t = 0; t < 20 && !m.jogo.rodadaEncerrada; t++) {
        m.conduzirRobo(m.jogo.vez, eventoId: 't$t');
        final ids = VisaoAssento.idsVisiveis(m.visaoDe(0));
        for (var a = 1; a < 4; a++) {
          for (final c in m.jogo.maos[a]) {
            expect(ids, isNot(contains(c.id)), reason: 'turno $t, assento $a');
          }
        }
        for (final c in m.jogo.monte) {
          expect(ids, isNot(contains(c.id)), reason: 'monte no turno $t');
        }
      }
    });
  });
}
