// OS 4 — BENCHMARK POR DECISÃO e CORPUS DE ESTADOS.
//
// FORA DO PORTÃO (o CI roda `teste_motor.dart`). Existe porque a exigência da
// OS é sobre a DECISÃO — "nenhuma decisão do corpus pode passar de 2 s" — e o
// tempo de um TURNO não responde isso: um turno pode conter várias decisões
// (o laço de jogo reavalia do zero sempre que a mão troca pelo morto).
//
// COMO O CORPUS É CONSTRUÍDO
// Jogando de verdade, com o robô canônico e sementes fixas, e guardando o
// estado ANTES de cada jogada. Assim o corpus é reprodutível a partir de
// (modalidade, semente) e não de um arquivo que alguém precisa versionar.
//
// O QUE É MEDIDO
// `decidirCompra` e `decidirJogo` sobre cada estado do corpus, com a
// configuração da base e com a candidata — as duas sobre O MESMO estado, que é
// a única forma de comparar custo sem comparar trajetórias diferentes.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:buraco_master_vip/mesa.dart';
import 'package:buraco_master_vip/motor/motor_config.dart';
import 'package:buraco_master_vip/motor/projecao_estado.dart' show paraCanonico;
import 'package:buraco_master_vip/motor/autoridade_canonica.dart';
import 'package:buraco_master_vip/rules/acoes.dart';
import 'package:buraco_master_vip/rules/estado.dart';
import 'package:buraco_master_vip/rules/rule_spec.dart';
import 'package:buraco_master_vip/bot/pesos.dart';
import 'package:buraco_master_vip/bot/executor_bot.dart';
import 'package:buraco_master_vip/bot/orcamento_busca.dart';

int _env(String k, int p) => int.tryParse(Platform.environment[k] ?? '') ?? p;

/// Um estado do corpus, com o rótulo que permite reproduzi-lo.
class ItemCorpus {
  final String mod;
  final int seed;
  final int turno;
  final EstadoJogo estado;
  final int assento;
  const ItemCorpus(this.mod, this.seed, this.turno, this.estado, this.assento);
}

/// Monta o corpus jogando com a configuração indicada.
List<ItemCorpus> montarCorpus({
  required List<String> mods,
  required List<int> seeds,
  required int turnosPorPartida,
  required ConfiguracaoBot cfg,
}) {
  final out = <ItemCorpus>[];
  for (final mod in mods) {
    for (final seed in seeds) {
      final j = Jogo(const ['n0', 'e1', 'n2', 'e3'], const ['', '', '', ''],
          const ['', '', '', ''],
          seed: seed, motorConfig: MotorConfig.producao());
      j.modalidade = mod;
      j.configuracaoBot = cfg;
      var t = 0;
      while (!j.rodadaEncerrada && t < turnosPorPartida) {
        t++;
        final assento = j.vez;
        out.add(ItemCorpus(mod, seed, t, paraCanonico(j).canonico, assento));
        j.botJoga(assento);
        if (j.integridadeErro != null) break;
      }
    }
  }
  return out;
}

/// Mede UMA decisão completa (derivação de candidatos + escolha) no estado.
({int micros, DecisaoBot decisao}) medirDecisao(
    ItemCorpus it, ConfiguracaoBot cfg) {
  final spec = RuleSpec.canonica(it.estado.modalidade,
      metaPontos: it.estado.metaPontos);
  final ex = ExecutorBot(spec, cfg: cfg);
  final sw = Stopwatch()..start();
  final DecisaoBot d;
  if (it.estado.fase == FaseTurno.compra) {
    final orc = OrcamentoBuscaBot(cfg.limitesBusca);
    var cands = const <ComprarLixo>[];
    if (spec.exigeUsoDoTopoNoLixo) {
      final diag =
          DiagnosticoLixo(tetoTransacoes: orc.tetoTransacoesCompraLixo);
      cands = derivarCandidatosCompraLixoFechado(it.estado, it.assento, spec,
          diag: diag);
      orc.registrarTransacoesCompraLixo(diag.transacoesValidadas,
          estourou: diag.estourou);
    }
    d = ex.decidirCompra(it.estado, it.assento,
        candidatosLixo: cands, orcamento: orc);
  } else {
    d = ex.decidirJogo(it.estado, it.assento,
        orcamento: OrcamentoBuscaBot(cfg.limitesBusca));
  }
  sw.stop();
  return (micros: sw.elapsedMicroseconds, decisao: d);
}

/// Assinatura da ESCOLHA (não do rastro): é o que precisa ser idêntico entre a
/// base e a candidata quando a busca coube no orçamento.
String escolhaDe(DecisaoBot d) =>
    jsonEncode([for (final a in d.acoes) a.toJson()]);

void main() {
  final mods =
      (Platform.environment['BENCH_MODS'] ?? 'ABERTO,FECHADO,SBTL').split(',');
  final seeds = (Platform.environment['BENCH_SEEDS'] ?? '1,2,3,5,7')
      .split(',')
      .map(int.parse)
      .toList();
  final turnos = _env('BENCH_TURNOS', 45);

  test('custo por decisao e preservacao da escolha', () {
    // O corpus é montado com a configuração da BASE: os estados visitados têm
    // de ser os mesmos que a base visitaria, senão a comparação de custo mede
    // trajetórias diferentes.
    final corpus = montarCorpus(
      mods: mods,
      seeds: seeds,
      turnosPorPartida: turnos,
      cfg: ConfiguracaoBot.base,
    );

    final microsBase = <int>[];
    final microsNovo = <int>[];
    var iguais = 0, diferentes = 0, cortadas = 0, fallbacks = 0;
    final divergencias = <String>[];

    for (final it in corpus) {
      final b = medirDecisao(it, ConfiguracaoBot.base);
      final n = medirDecisao(it, ConfiguracaoBot.v2);
      microsBase.add(b.micros);
      microsNovo.add(n.micros);

      final orc = n.decisao.orcamento;
      final cortou = orc != null && orc['esgotado'] == true;
      if (cortou) cortadas++;
      if (orc != null && orc['fallback'] == true) fallbacks++;

      if (escolhaDe(b.decisao) == escolhaDe(n.decisao)) {
        iguais++;
      } else {
        diferentes++;
        if (divergencias.length < 12) {
          divergencias.add('${it.mod}/${it.seed}/t${it.turno} '
              'fase=${it.estado.fase.name} cortou=$cortou '
              'motivo=${orc?['motivo']}');
        }
      }
    }

    int q(List<int> v, double p) {
      final s = [...v]..sort();
      return s.isEmpty ? 0 : s[(p * (s.length - 1)).floor()];
    }

    // ignore: avoid_print
    print('[DEC] decisoes=${corpus.length} '
        'BASE p50=${q(microsBase, .5)}us p95=${q(microsBase, .95)}us '
        'p99=${q(microsBase, .99)}us max=${q(microsBase, 1)}us');
    // ignore: avoid_print
    print('[DEC] decisoes=${corpus.length} '
        'NOVO p50=${q(microsNovo, .5)}us p95=${q(microsNovo, .95)}us '
        'p99=${q(microsNovo, .99)}us max=${q(microsNovo, 1)}us');
    // ignore: avoid_print
    print('[DEC] escolhas iguais=$iguais diferentes=$diferentes '
        'cortadas=$cortadas fallbacks=$fallbacks');
    for (final d in divergencias) {
      // ignore: avoid_print
      print('[DIVERGE] $d');
    }

    final saida = Platform.environment['BENCH_OUT'];
    if (saida != null) {
      File(saida).writeAsStringSync(jsonEncode({
        'decisoes': corpus.length,
        'base': {
          'p50': q(microsBase, .5),
          'p95': q(microsBase, .95),
          'p99': q(microsBase, .99),
          'max': q(microsBase, 1),
        },
        'novo': {
          'p50': q(microsNovo, .5),
          'p95': q(microsNovo, .95),
          'p99': q(microsNovo, .99),
          'max': q(microsNovo, 1),
        },
        'iguais': iguais,
        'diferentes': diferentes,
        'cortadas': cortadas,
        'fallbacks': fallbacks,
      }));
    }
    expect(corpus, isNotEmpty);
  });
  // ===================================================================
  // BENCHMARK DE PARTIDA — a CONFIGURAÇÃO ENTREGUE nos dois lados.
  //
  // A matriz de 384 partidas põe o bot novo contra o bot da BASE, que é o que
  // mede qualidade. Ela NÃO responde "quanto tempo leva uma partida do jogo
  // entregue", porque metade dos assentos ali roda de propósito a versão sem
  // orçamento — a explosão que esta OS corrige. Este benchmark põe a
  // configuração entregue nas quatro cadeiras, que é o que o jogador terá.
  //
  // Parâmetros: BENCH_MODS, BENCH_SEEDS, BENCH_RODADAS, BENCH_PARTIDA_OUT.
  // ===================================================================
  test('custo por partida com a configuracao entregue', () {
    final seeds = (Platform.environment['BENCH_SEEDS'] ?? '29')
        .split(',')
        .map(int.parse)
        .toList();
    final maxRodadas = _env('BENCH_RODADAS', 60);
    final registros = <Map<String, Object?>>[];

    for (final mod in mods) {
      for (final seed in seeds) {
        final j = Jogo(const ['n0', 'e1', 'n2', 'e3'], const ['', '', '', ''],
            const ['', '', '', ''],
            seed: seed, motorConfig: MotorConfig.producao());
        j.modalidade = mod;
        j.metaPontos = 1500;
        j.configuracaoBot = ConfiguracaoBot.v2;

        final tempos = <int>[];
        var cortes = 0, fallbacks = 0, turnos = 0;
        final relogio = Stopwatch()..start();
        final sw = Stopwatch();
        for (var rod = 0; rod < maxRodadas && !j.encerrada; rod++) {
          var seg = 0;
          while (!j.rodadaEncerrada && seg < 3000) {
            seg++;
            turnos++;
            sw
              ..reset()
              ..start();
            j.botJoga(j.vez);
            sw.stop();
            tempos.add(sw.elapsedMilliseconds);
            final o = j.ultimaDecisaoBot?['orcamento'];
            if (o is Map) {
              if (o['esgotado'] == true) cortes++;
              if (o['fallback'] == true) fallbacks++;
            }
            if (j.integridadeErro != null) break;
          }
          if (seg >= 3000) break;
          j.contarPontos();
          if (!j.encerrada) j.novaRodada();
        }
        relogio.stop();
        tempos.sort();
        int q(double x) =>
            tempos.isEmpty ? 0 : tempos[(x * (tempos.length - 1)).floor()];
        registros.add({
          'mod': mod,
          'seed': seed,
          'turnos': turnos,
          'terminou': j.encerrada,
          'integra': j.integridadeErro == null,
          'partidaMs': relogio.elapsedMilliseconds,
          'p50': q(0.5),
          'p95': q(0.95),
          'p99': q(0.99),
          'max': tempos.isEmpty ? 0 : tempos.last,
          'cortes': cortes,
          'fallbacks': fallbacks,
        });
        // ignore: avoid_print
        print('[PARTIDA] $mod/$seed turnos=$turnos '
            'terminou=${j.encerrada} partida=${relogio.elapsedMilliseconds}ms '
            'p50=${q(0.5)}ms p95=${q(0.95)}ms p99=${q(0.99)}ms '
            'max=${tempos.isEmpty ? 0 : tempos.last}ms '
            'cortes=$cortes fallbacks=$fallbacks');
      }
    }
    final saida = Platform.environment['BENCH_PARTIDA_OUT'];
    if (saida != null) File(saida).writeAsStringSync(jsonEncode(registros));
    // TODA partida tem de terminar: e o criterio da OS, nao um detalhe.
    for (final r in registros) {
      expect(r['terminou'], isTrue, reason: '${r['mod']}/${r['seed']}');
      expect(r['integra'], isTrue, reason: '${r['mod']}/${r['seed']}');
    }
  });
}
