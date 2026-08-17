// OS 3 — HARNESS DETERMINÍSTICO DE PARTIDAS COMPLETAS (V1 × V2).
//
// FORA DO PORTÃO. O CI roda `flutter test test/teste_motor.dart`; este arquivo
// só é alcançado quando alguém o nomeia. Existe porque a comparação exigida
// pela §13 custa minutos, e o portão precisa continuar custando segundos.
//
// O QUE ELE FAZ
// Joga partidas completas (até a meta) com o robô CANÔNICO nas duas duplas,
// atribuindo uma configuração a cada dupla. O espelhamento troca os lados na
// mesma semente, para que a vantagem de posição/distribuição se cancele.
//
// COMO A CONFIGURAÇÃO POR DUPLA É FEITA SEM TOCAR NO MOTOR
// `Jogo.configuracaoBot` é um campo mutável lido a cada `botJoga`. O harness o
// troca ANTES de cada jogada, conforme a dupla do assento. Nenhuma linha de
// `mesa.dart` precisou mudar para isso — e, como a troca é externa, ela não
// existe em produção.
//
// PARÂMETROS (ambiente, para não recompilar):
//   HARNESS_SEEDS      quantas sementes por modalidade   (padrão 4)
//   HARNESS_SEED0      primeira semente                  (padrão 1)
//   HARNESS_MODS       lista separada por vírgula        (padrão ABERTO,FECHADO,SBTL)
//   HARNESS_META       meta de pontos                    (padrão 1500)
//   HARNESS_MODO       'v1v1' | 'v1v2'                   (padrão v1v2)
//   HARNESS_OUT        arquivo de saída (obrigatório)
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:buraco_master_vip/mesa.dart';
import 'package:buraco_master_vip/motor/motor_config.dart';
import 'package:buraco_master_vip/bot/pesos.dart';
import 'package:buraco_master_vip/bot/executor_bot.dart';
import 'package:buraco_master_vip/motor/projecao_estado.dart' show paraCanonico;
import 'package:buraco_master_vip/rules/rule_spec.dart';

/// Teto de segurança por rodada e por partida (o mesmo espírito do `AUD-01`).
const int _maxSegmentosPorRodada = 3000;
const int _maxRodadas = 60;

/// Métricas de UMA partida, do ponto de vista de cada dupla.
class ResultadoPartida {
  final String modalidade;
  final int seed;

  /// Configuração que jogou por 'nos' e por 'eles' (carimbo de versão).
  final String versaoNos;
  final String versaoEles;

  final int pontosNos;
  final int pontosEles;
  final int rodadas;
  final int turnos;
  final int comprasLixo;
  final int canastrasNos;
  final int canastrasEles;
  final int mortosPegos;
  final int batidas;
  final int impasses;
  final int truncadas;
  final int falhasTecnicas;
  final bool terminou;
  final bool integra;

  /// Decisões em que a feature da memória pública apareceu (≠ 0).
  final int sinalAplicado;

  /// Decisões em que a razão nova foi emitida — o sinal MUDOU o vencedor.
  final int sinalDecisivo;

  /// Microssegundos de cada chamada de decisão (para média e p95).
  final List<int> temposMicros;

  const ResultadoPartida({
    required this.modalidade,
    required this.seed,
    required this.versaoNos,
    required this.versaoEles,
    required this.pontosNos,
    required this.pontosEles,
    required this.rodadas,
    required this.turnos,
    required this.comprasLixo,
    required this.canastrasNos,
    required this.canastrasEles,
    required this.mortosPegos,
    required this.batidas,
    required this.impasses,
    required this.truncadas,
    required this.falhasTecnicas,
    required this.terminou,
    required this.integra,
    required this.sinalAplicado,
    required this.sinalDecisivo,
    required this.temposMicros,
  });

  Map<String, Object?> toJson() => {
        'modalidade': modalidade,
        'seed': seed,
        'versaoNos': versaoNos,
        'versaoEles': versaoEles,
        'pontosNos': pontosNos,
        'pontosEles': pontosEles,
        'rodadas': rodadas,
        'turnos': turnos,
        'comprasLixo': comprasLixo,
        'canastrasNos': canastrasNos,
        'canastrasEles': canastrasEles,
        'mortosPegos': mortosPegos,
        'batidas': batidas,
        'impasses': impasses,
        'truncadas': truncadas,
        'falhasTecnicas': falhasTecnicas,
        'terminou': terminou,
        'integra': integra,
        'sinalAplicado': sinalAplicado,
        'sinalDecisivo': sinalDecisivo,
        'decisoes': temposMicros.length,
        'microsTotal': temposMicros.fold<int>(0, (a, b) => a + b),
      };
}

/// Nome da feature e da razão que esta OS acrescenta. Declarados aqui como
/// STRING para o harness não depender da compilação da V2 — assim ele roda
/// igual antes e depois da entrega, e serve de baseline.
const String kFeatureMemoria = 'memoriaDescarteParceiro';
const String kRazaoMemoria = 'DESCARTE_MEMORIA_PARCEIRO';

/// Configuração CANDIDATA da comparação: a V2 desta OS.
///
/// `HARNESS_PESO` sobrescreve o peso da memória — é o que permite calibrar por
/// medição (rodar 3, 4, 5) em vez de escolher um número por conveniência de um
/// teste. Sem a variável, vale o peso aprovado da `ConfiguracaoBot.v2`.
ConfiguracaoBot configuracaoCandidata() {
  final peso = Platform.environment['HARNESS_PESO'];
  if (peso == null) return ConfiguracaoBot.v2;
  return ConfiguracaoBot.v2.comPesos(ConfiguracaoBot.v2.pesos.copyWith(
    memoriaDescarteParceiro: double.parse(peso),
    versao: 'bmv-bot-heuristico-v2-descartes-publicos@peso=$peso',
  ));
}

/// Joga UMA partida completa. `cfgNos`/`cfgEles` são aplicadas por dupla.
ResultadoPartida jogarPartida({
  required String modalidade,
  required int seed,
  required ConfiguracaoBot cfgNos,
  required ConfiguracaoBot cfgEles,
  int metaPontos = 1500,
}) {
  final j = Jogo(const ['n0', 'e1', 'n2', 'e3'], const ['', '', '', ''],
      const ['', '', '', ''],
      seed: seed, motorConfig: MotorConfig.producao());
  j.modalidade = modalidade;
  j.metaPontos = metaPontos;

  var turnos = 0,
      comprasLixo = 0,
      mortosPegos = 0,
      batidas = 0,
      truncadas = 0,
      sinalAplicado = 0,
      sinalDecisivo = 0,
      rodadas = 0;
  final tempos = <int>[];
  final sw = Stopwatch();

  for (var rod = 0; rod < _maxRodadas && !j.encerrada; rod++) {
    rodadas++;
    var seg = 0;
    while (!j.rodadaEncerrada && seg < _maxSegmentosPorRodada) {
      seg++;
      turnos++;
      final assento = j.vez;
      // A configuração é da DUPLA do assento. Trocada por fora, a cada jogada.
      j.configuracaoBot = assento % 2 == 0 ? cfgNos : cfgEles;

      // COMPRA DO LIXO detectada pela IDENTIDADE das cartas, não pelo tamanho:
      // depois de comprar o lixo o robô descarta, e a pilha volta a ter carta.
      // A única forma de as cartas ANTERIORES saírem da pilha é a compra.
      final idsLixoAntes = {for (final c in j.lixo) c.id};
      final mortoAntes =
          (j.mortoPego['nos'] ?? false) || (j.mortoPego['eles'] ?? false)
              ? (j.mortoPego['nos'] == true ? 1 : 0) +
                  (j.mortoPego['eles'] == true ? 1 : 0)
              : 0;

      sw
        ..reset()
        ..start();
      j.botJoga(assento);
      sw.stop();
      tempos.add(sw.elapsedMicroseconds);

      if (idsLixoAntes.isNotEmpty &&
          j.lixo.every((c) => !idsLixoAntes.contains(c.id))) {
        comprasLixo++;
      }
      final mortoDepois = (j.mortoPego['nos'] == true ? 1 : 0) +
          (j.mortoPego['eles'] == true ? 1 : 0);
      if (mortoDepois > mortoAntes) mortosPegos += mortoDepois - mortoAntes;

      // RASTRO: a última decisão do turno é a que produziu o descarte.
      final d = j.ultimaDecisaoBot;
      if (d != null) {
        if (d['truncado'] == true) truncadas++;
        final f = d['features'];
        if (f is Map && (f[kFeatureMemoria] as num? ?? 0) != 0) {
          sinalAplicado++;
        }
        final rz = d['razoes'];
        if (rz is List && rz.contains(kRazaoMemoria)) sinalDecisivo++;
      }
      if (j.integridadeErro != null) break;
    }
    if (j.rodadaEncerrada && j.duplaQueBateu != null) batidas++;
    if (seg >= _maxSegmentosPorRodada) break;
    j.contarPontos();
    if (!j.encerrada) j.novaRodada();
  }

  int canastras(String dupla) => j.jogosDupla[dupla]!
      .where((m) => m.length >= 7)
      .length;

  return ResultadoPartida(
    modalidade: modalidade,
    seed: seed,
    versaoNos: cfgNos.pesos.versao,
    versaoEles: cfgEles.pesos.versao,
    pontosNos: j.placar['nos'] ?? 0,
    pontosEles: j.placar['eles'] ?? 0,
    rodadas: rodadas,
    turnos: turnos,
    comprasLixo: comprasLixo,
    canastrasNos: canastras('nos'),
    canastrasEles: canastras('eles'),
    mortosPegos: mortosPegos,
    batidas: batidas,
    impasses: j.impassesEstrategicos.length,
    truncadas: truncadas,
    falhasTecnicas: j.falhasTecnicas,
    terminou: j.encerrada,
    integra: j.integridadeErro == null,
    sinalAplicado: sinalAplicado,
    sinalDecisivo: sinalDecisivo,
    temposMicros: tempos,
  );
}

int _envInt(String chave, int padrao) {
  final v = Platform.environment[chave];
  return v == null ? padrao : (int.tryParse(v) ?? padrao);
}

void main() {
  test('harness de partidas completas', () {
    final saida = Platform.environment['HARNESS_OUT'];
    if (saida == null) {
      fail('defina HARNESS_OUT com o arquivo de saída');
    }
    final nSeeds = _envInt('HARNESS_SEEDS', 4);
    final seed0 = _envInt('HARNESS_SEED0', 1);
    final meta = _envInt('HARNESS_META', 1500);
    final mods = (Platform.environment['HARNESS_MODS'] ?? 'ABERTO,FECHADO,SBTL')
        .split(',');
    final modo = Platform.environment['HARNESS_MODO'] ?? 'v1v2';

    // A configuração "candidata" é resolvida por nome, para o harness compilar
    // igual na base (onde a V2 ainda não existe) e na entrega.
    final candidata = modo == 'v1v1' ? ConfiguracaoBot.v1 : configuracaoCandidata();

    final linhas = <Map<String, Object?>>[];
    final relogio = Stopwatch()..start();
    for (final mod in mods) {
      for (var i = 0; i < nSeeds; i++) {
        final seed = seed0 + i;
        // ESPELHO: a mesma semente jogada com os lados trocados. A distribuição
        // é a mesma; o que muda é qual dupla usa a candidata.
        linhas.add(jogarPartida(
          modalidade: mod,
          seed: seed,
          cfgNos: candidata,
          cfgEles: ConfiguracaoBot.v1,
          metaPontos: meta,
        ).toJson()
          ..['lado'] = 'candidata=nos');
        linhas.add(jogarPartida(
          modalidade: mod,
          seed: seed,
          cfgNos: ConfiguracaoBot.v1,
          cfgEles: candidata,
          metaPontos: meta,
        ).toJson()
          ..['lado'] = 'candidata=eles');
      }
    }
    relogio.stop();

    File(saida).writeAsStringSync(jsonEncode({
      'modo': modo,
      'mods': mods,
      'seeds': nSeeds,
      'seed0': seed0,
      'meta': meta,
      'duracaoMs': relogio.elapsedMilliseconds,
      'partidas': linhas,
    }));
    // ignore: avoid_print
    print('[HARNESS] ${linhas.length} partidas em '
        '${relogio.elapsedMilliseconds}ms -> $saida');
  });

  // =====================================================================
  // CUSTO DA DECISÃO — V1 × V2 SOBRE O MESMO ESTADO
  //
  // Por que não medir isso pelas partidas: a V2 joga partidas DIFERENTES, com
  // mãos e mesas diferentes, e o custo de uma decisão depende do tamanho da
  // mão e da quantidade de jogos expostos. Comparar o tempo médio por turno
  // entre duas trajetórias mede as trajetórias, não o custo do sinal.
  //
  // Aqui as duas configurações decidem sobre o MESMO estado, com as MESMAS
  // alternativas. A diferença é só o trabalho que a V2 acrescenta: montar o
  // índice uma vez por decisão, consultar um conjunto por plano, e a passada
  // linear do argmax contrafactual.
  // =====================================================================
  test('custo da decisão V1 x V2 no mesmo estado', () {
    final repeticoes = _envInt('BENCH_REPS', 60);
    final linhas = <String>[];

    for (final mod in const ['ABERTO', 'FECHADO', 'SBTL']) {
      // Estado de MEIO DE PARTIDA, construído por jogo real e determinístico:
      // mãos cheias, jogos na mesa e livro de proveniência povoado — que é
      // onde o índice tem mais trabalho a fazer.
      final j = Jogo(const ['n0', 'e1', 'n2', 'e3'], const ['', '', '', ''],
          const ['', '', '', ''],
          seed: 4242, motorConfig: MotorConfig.producao());
      j.modalidade = mod;
      j.configuracaoBot = ConfiguracaoBot.v1;
      for (var t = 0; t < 24 && !j.rodadaEncerrada; t++) {
        j.botJoga(j.vez);
      }
      if (j.rodadaEncerrada) continue;
      // O turno anterior TERMINOU, então o estado está na fase de COMPRA — e
      // `decidirJogo` numa fase de compra não gera plano nenhum e nem chega ao
      // avaliador. A primeira versão deste bench media exatamente isso (o
      // rastro denunciou: `planos=0`) e concluía "sem custo" sem ter
      // exercitado uma linha da V2. Comprar do monte põe o estado na fase de
      // JOGO, que é onde o descarte — e o sinal — existem.
      final assento = j.vez;
      if (!j.comprarMonte(assento)) continue;
      final estado = paraCanonico(j).canonico;
      final spec = RuleSpec.canonica(estado.modalidade,
          metaPontos: estado.metaPontos);

      final ex1 = ExecutorBot(spec, cfg: ConfiguracaoBot.v1);
      final ex2 = ExecutorBot(spec, cfg: ConfiguracaoBot.v2);
      ex1.decidirJogo(estado, assento); // aquece o JIT
      ex2.decidirJogo(estado, assento);

      // INTERCALADO, e comparado por MEDIANA. Medir em blocos (60 chamadas da
      // V1, depois 60 da V2) mede também a deriva da máquina no intervalo — a
      // primeira versão deste bench chegou a acusar a V2 22% MAIS RÁPIDA no
      // STBL, o que é impossível. Alternando chamada a chamada, a deriva incide
      // igualmente sobre as duas, e a mediana descarta as caudas de GC.
      final t1 = <int>[], t2 = <int>[];
      final sw = Stopwatch();
      for (var i = 0; i < repeticoes; i++) {
        sw
          ..reset()
          ..start();
        ex1.decidirJogo(estado, assento);
        sw.stop();
        t1.add(sw.elapsedMicroseconds);
        sw
          ..reset()
          ..start();
        ex2.decidirJogo(estado, assento);
        sw.stop();
        t2.add(sw.elapsedMicroseconds);
      }
      t1.sort();
      t2.sort();
      final v1 = t1[t1.length ~/ 2];
      final v2 = t2[t2.length ~/ 2];
      final p95_1 = t1[(0.95 * (t1.length - 1)).floor()];
      final p95_2 = t2[(0.95 * (t2.length - 1)).floor()];
      final sinal = ExecutorBot(spec, cfg: ConfiguracaoBot.v2)
          .decidirJogo(estado, assento)
          .features[kFeatureMemoria];
      linhas.add('$mod: mediana V1=${v1}us V2=${v2}us '
          'delta=${(100 * (v2 - v1) / v1).toStringAsFixed(1)}% | '
          'p95 V1=${p95_1}us V2=${p95_2}us | '
          'mao=${estado.maos[assento].length} '
          'livro=${estado.descartes.length} '
          'planos=${ex2.decidirJogo(estado, assento).candidatosConsiderados} '
          'featureNoVencedor=${sinal ?? "-"}');
    }
    for (final l in linhas) {
      // ignore: avoid_print
      print('[BENCH] $l');
    }
    expect(linhas, isNotEmpty);
  });
}
