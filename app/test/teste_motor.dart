// PORTÃO DE QUALIDADE — testes do MOTOR REAL (mesa.dart), executados no CI.
// Nenhum APK é gerado se um teste falhar. Mesma suíte nominal validada em
// simulação (INT/JOGO/FLUX/PONT/BOT/TRX = 121 testes) + 12 partidas completas.
// Todos os testes exercitam o COMPORTAMENTO via API pública do motor.
import 'package:flutter_test/flutter_test.dart';
import 'package:buraco_master_vip/mesa.dart';
// C1 — andaime do RulesEngine canônico (aditivo; motor antigo continua padrão).
import 'package:buraco_master_vip/rules/modalidade.dart';
import 'package:buraco_master_vip/rules/rule_spec.dart';
import 'package:buraco_master_vip/rules/acoes.dart';
import 'package:buraco_master_vip/rules/pontuacao.dart';
import 'package:buraco_master_vip/rules/estado.dart';
import 'package:buraco_master_vip/rules/sombra.dart';
import 'package:buraco_master_vip/rules/replay.dart';
import 'package:buraco_master_vip/rules/rules_engine.dart';
// C2 — validador de meld canônico (aditivo; motor antigo continua padrão).
import 'package:buraco_master_vip/rules/meld/meld_validator.dart';
// C3 — pontuação canônica (aditivo; motor antigo continua padrão).
import 'package:buraco_master_vip/rules/pontuacao_canonica.dart';
// C4 — jogada atômica / abertura múltipla (aditivo; motor antigo continua padrão).
import 'package:buraco_master_vip/rules/abertura/abertura.dart';
// C6 — morto e batida (aditivo; motor antigo continua padrão).
import 'package:buraco_master_vip/rules/morto/morto.dart';
// C7 — gerador único de ações legais (aditivo; motor antigo continua padrão).
import 'package:buraco_master_vip/rules/gerador/gerador.dart';
// C8 — conformidade Dart × Node (fixture do lado Node; comparação cross-engine).
import 'dart:convert';
import 'conformidade_fixture.dart';
// C9-A — costura: flags + contrato da porta + fábrica/seletor (aditivo; NÃO é
// regra, NÃO é runtime; sem projeção Jogo<->EstadoJogo, sem adaptador concreto).
import 'package:buraco_master_vip/motor/motor_config.dart';
import 'package:buraco_master_vip/motor/porta_motor.dart';
import 'package:buraco_master_vip/motor/fabrica_motor.dart';
// C9-B — projeção/envelope + adaptadores concretos + composição (costura OFF).
import 'package:buraco_master_vip/motor/envelope_runtime.dart';
import 'package:buraco_master_vip/motor/projecao_estado.dart';
import 'package:buraco_master_vip/motor/adaptador_canonico.dart';
import 'package:buraco_master_vip/motor/adaptador_legado.dart';
import 'package:buraco_master_vip/motor/composicao.dart';
// C9-C — modo sombra + comparador.
import 'package:buraco_master_vip/motor/modo_sombra.dart';
import 'package:buraco_master_vip/motor/autoridade_canonica.dart';

int _seq = 0;
Carta c(String valor, String? naipe) =>
    Carta('t${_seq++}_${naipe ?? 'jk'}_$valor', naipe, valor,
        valor == '2' || valor == 'JOKER');
Carta cj() => c('JOKER', null);

Jogo novo([String modalidade = 'ABERTO', int? seed]) {
  final j = Jogo(const ['você', 'B1', 'B2', 'B3'], const ['', '', '', ''],
      const ['', '', '', ''], seed: seed);
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
  j.mortos = [pool.sublist(0, 11), pool.sublist(11, 22)];
  j.monte = pool.sublist(22);
  j.vez = vez;
  j.jaComprou = jaComprou;
  j.rodadaEncerrada = false;
  j.lixoTopoObrigatorio = null;
  j.mortoPego = {'nos': false, 'eles': false};
  j.primeiraBaixadaFeita = {'nos': false, 'eles': false};
  j.rodadasVulneravel = {'nos': 0, 'eles': 0};
  j.integridadeErro = null;
  j.auditarIntegridade();
  if (j.integridadeErro != null) {
    throw StateError('montar() quebrou a integridade: ${j.integridadeErro}');
  }
  return j;
}

List<String> idsMao(Jogo j, int a) => [for (final x in j.maos[a]) x.id];

// Oráculo de pontos DO TESTE (tabela oficial §4.1) — independente do motor.
int pts(Carta x) {
  if (x.valor == 'A') return 15;
  if (x.valor == 'JOKER') return 50;
  if (x.valor == '2') return 10;
  if (['8', '9', '10', 'J', 'Q', 'K'].contains(x.valor)) return 10;
  return 5;
}

Jogo corrompido() {
  final j = novo();
  j.vez = 0;
  j.maos[0].add(Carta('artificial_7s', 'espadas', '7', false));
  j.auditarIntegridade();
  return j;
}

// Valida um conjunto de cartas COMO A MESA valida: baixando num jogo montado.
Map<String, dynamic> baixaEm(String modalidade, List<Spec> cartas,
    {List<Spec> extra = const [('K', 'paus')]}) {
  final j = novo(modalidade);
  montar(j, mao0: [...cartas, ...extra], vez: 0, jaComprou: true);
  final ids = [for (var i = 0; i < cartas.length; i++) j.maos[0][i].id];
  return j.baixar(0, ids);
}

void main() {
  // ================= INT — integridade (25) =================
  test('INT-01 baralho da partida tem 108 cartas', () {
    expect(totalCartas(novo()), 108);
  });
  test('INT-02 cardId físico único em todas as 108 cartas', () {
    final t = zonasTodas(novo());
    expect(t.map((x) => x.id).toSet().length, 108);
  });
  test('INT-03 exatamente 2 cópias de cada valor+naipe (52 combinações)', () {
    final cnt = <String, int>{};
    for (final x in zonasTodas(novo())) {
      if (x.valor == 'JOKER') continue;
      cnt['${x.naipe}:${x.valor}'] = (cnt['${x.naipe}:${x.valor}'] ?? 0) + 1;
    }
    expect(cnt.length, 52);
    expect(cnt.values.every((v) => v == 2), isTrue);
  });
  test('INT-04 exatamente 4 JOKERs', () {
    expect(zonasTodas(novo()).where((x) => x.valor == 'JOKER').length, 4);
  });
  test('INT-05 distribuição: 4×11 mãos + 2×11 mortos + 42 monte + 0 lixo', () {
    final j = novo();
    expect(j.maos.every((m) => m.length == 11), isTrue);
    expect(j.mortos.every((m) => m.length == 11), isTrue);
    expect(j.monte.length, 42);
    expect(j.lixo, isEmpty);
  });
  test('INT-06 auditor aprova estado recém-distribuído', () {
    final j = novo();
    expect(j.auditarIntegridade(), isTrue);
    expect(j.integridadeErro, isNull);
  });
  test('INT-07 zonas somam 108 após compra do monte', () {
    final j = novo()..vez = 0;
    j.comprarMonte(0);
    expect(totalCartas(j), 108);
    expect(j.integridadeErro, isNull);
  });
  test('INT-08 zonas somam 108 após compra do lixo', () {
    final j = novo();
    montar(j, mao0: const [('5', 'copas'), ('6', 'copas'), ('9', 'paus')],
        lixo: const [('4', 'ouros'), ('7', 'copas')], vez: 0);
    j.comprarLixo(0, modalidade: 'ABERTO');
    expect(totalCartas(j), 108);
    expect(j.integridadeErro, isNull);
  });
  test('INT-09 zonas somam 108 após baixada', () {
    final j = novo();
    montar(j,
        mao0: const [('5', 'copas'), ('6', 'copas'), ('7', 'copas'), ('K', 'paus')],
        vez: 0, jaComprou: true);
    j.baixar(0, idsMao(j, 0).sublist(0, 3));
    expect(totalCartas(j), 108);
    expect(j.integridadeErro, isNull);
  });
  test('INT-10 zonas somam 108 após extensão', () {
    final j = novo();
    montar(j, mao0: const [('8', 'copas'), ('K', 'paus')],
        mesaNos: const [[('5', 'copas'), ('6', 'copas'), ('7', 'copas')]],
        vez: 0, jaComprou: true);
    j.estender(0, 0, [j.maos[0][0].id]);
    expect(totalCartas(j), 108);
    expect(j.integridadeErro, isNull);
  });
  test('INT-11 zonas somam 108 após descarte', () {
    final j = novo();
    montar(j, mao0: const [('5', 'copas'), ('K', 'paus')], vez: 0, jaComprou: true);
    j.descartar(0, j.maos[0][0].id);
    expect(totalCartas(j), 108);
    expect(j.integridadeErro, isNull);
  });
  test('INT-12 zonas somam 108 após pegar o morto', () {
    final j = novo();
    montar(j, mao0: const [('5', 'copas')],
        mesaNos: const [[('9', 'ouros'), ('10', 'ouros'), ('J', 'ouros')]],
        vez: 0, jaComprou: true);
    j.descartar(0, j.maos[0][0].id);
    expect(totalCartas(j), 108);
    expect(j.maos[0].length, 11);
    expect(j.integridadeErro, isNull);
  });
  test('INT-13 DECK-001: 3ª cópia de 7♠ é REJEITADA (DUPLICATE_RANK_SUIT_OVERFLOW)', () {
    final j = corrompido();
    expect(j.integridadeErro, contains('DUPLICATE_RANK_SUIT_OVERFLOW'));
    expect(j.integridadeErro, contains('espadas:7 x3'));
  });
  test('INT-14 DECK-002: mesmo cardId em 2 zonas rejeitado', () {
    final j = novo();
    j.lixo.add(j.maos[0][0]);
    j.auditarIntegridade();
    expect(j.integridadeErro, contains('CARD_PRESENT_IN_MULTIPLE_ZONES'));
  });
  test('INT-15 DECK-003: 107 cartas rejeitado (DECK_TOTAL_MISMATCH)', () {
    final j = novo();
    j.monte.removeLast();
    j.auditarIntegridade();
    expect(j.integridadeErro, contains('DECK_TOTAL_MISMATCH: 107'));
  });
  test('INT-16 DECK-003b: 109 cartas rejeitado', () {
    final j = novo();
    j.monte.add(Carta('extra', 'copas', '5', false));
    j.auditarIntegridade();
    expect(j.integridadeErro, isNotNull);
  });
  test('INT-17 carta virt_ (desenho do coringa) no estado é rejeitada', () {
    final j = novo();
    j.monte.removeLast();
    j.monte.add(Carta('virt_falsa', 'copas', '5', false));
    j.auditarIntegridade();
    expect(j.integridadeErro, isNotNull);
  });
  test('INT-18 corrompido: comprarMonte recusado e estado inalterado', () {
    final j = corrompido();
    final antes = totalCartas(j);
    expect(j.comprarMonte(0), isFalse);
    expect(totalCartas(j), antes);
  });
  test('INT-19 corrompido: comprarLixo recusado', () {
    final j = corrompido();
    j.lixo = [j.monte.removeLast()];
    j.auditarIntegridade();
    expect(j.comprarLixo(0)['ok'], isFalse);
  });
  test('INT-20 corrompido: baixar recusado', () {
    final j = corrompido()..jaComprou = true;
    expect(j.baixar(0, idsMao(j, 0).sublist(0, 3))['ok'], isFalse);
  });
  test('INT-21 corrompido: descartar recusado com código auditável', () {
    final j = corrompido()..jaComprou = true;
    expect(j.descartar(0, idsMao(j, 0)[0]), contains('DUPLICATE'));
  });
  test('INT-22 corrompido: botJoga não faz NADA (estado preservado)', () {
    final j = corrompido();
    final antes = idsMao(j, 0);
    j.botJoga(0);
    expect(idsMao(j, 0), antes);
  });
  test('INT-23 RESTAURAÇÃO corrompida é recusada (não abre silenciosamente)', () {
    final j = corrompido();
    expect(j.auditarIntegridade(), isFalse);
    expect(j.integridadeErro, isNotNull);
  });
  test('INT-24 auditor é idempotente (2ª execução, mesmo veredito)', () {
    final j = corrompido();
    final e1 = j.integridadeErro;
    j.auditarIntegridade();
    expect(j.integridadeErro, e1);
  });
  test('INT-25 RECONEXÃO com estado válido destrava o jogo', () {
    final j = corrompido();
    j.maos[0].removeWhere((x) => x.id == 'artificial_7s');
    expect(j.auditarIntegridade(), isTrue);
    expect(j.integridadeErro, isNull);
    j.vez = 0;
    expect(j.comprarMonte(0), isTrue);
  });

  // ================= JOGO — jogos e canastras (36) =================
  final jv = novo(); // validarSequencia é pública e sem estado
  Map<String, dynamic> vs(List<Carta> cs) => jv.validarSequencia(cs);
  test('JOGO-01 sequência de 3 mesmo naipe é válida', () {
    expect(vs([c('5', 'copas'), c('6', 'copas'), c('7', 'copas')])['valido'], true);
  });
  test('JOGO-02 jogo com menos de 3 cartas é inválido', () {
    expect(vs([c('5', 'copas'), c('6', 'copas')])['valido'], isNot(true));
  });
  test('JOGO-03 naipes misturados é inválido', () {
    expect(vs([c('5', 'copas'), c('6', 'ouros'), c('7', 'copas')])['valido'], isNot(true));
  });
  test('JOGO-04 MELD-001: 5-6-7-7-8 mesmo naipe é inválido', () {
    expect(vs([c('5', 'espadas'), c('6', 'espadas'), c('7', 'espadas'), c('7', 'espadas'), c('8', 'espadas')])['valido'], isNot(true));
  });
  test('JOGO-05 lacuna sem curinga é inválida (5-6-8)', () {
    expect(vs([c('5', 'copas'), c('6', 'copas'), c('8', 'copas')])['valido'], isNot(true));
  });
  test('JOGO-06 lacuna tapada por JOKER é válida (1 curinga)', () {
    final r = vs([c('5', 'copas'), c('6', 'copas'), cj(), c('8', 'copas')]);
    expect(r['valido'], true);
    expect(r['qtd_curingas'], 1);
  });
  test('JOGO-07 JOKER + 2-curinga no mesmo jogo é inválido', () {
    expect(vs([c('5', 'copas'), cj(), c('7', 'copas'), c('2', 'ouros'), c('9', 'copas')])['valido'], isNot(true));
  });
  test('JOGO-08 dois JOKERs é inválido', () {
    expect(vs([c('5', 'copas'), cj(), c('7', 'copas'), cj(), c('9', 'copas')])['valido'], isNot(true));
  });
  test('JOGO-09 jogo só de curingas é inválido', () {
    expect(vs([cj(), cj(), cj()])['valido'], isNot(true));
  });
  test('JOGO-10 A-2..7 com 2 NATURAL é canastra LIMPA', () {
    final r = vs([for (final v in ['A', '2', '3', '4', '5', '6', '7']) c(v, 'copas')]);
    expect(r['tipo'], 'limpa');
  });
  test('JOGO-11 2 de OUTRO naipe como curinga → SUJA', () {
    final r = vs([c('4', 'copas'), c('2', 'ouros'), c('6', 'copas'), c('7', 'copas'), c('8', 'copas'), c('9', 'copas'), c('10', 'copas')]);
    expect(r['tipo'], 'suja');
  });
  test('JOGO-12 2 do MESMO naipe tapando lacuna distante → SUJA', () {
    final r = vs([c('4', 'copas'), c('2', 'copas'), c('6', 'copas'), c('7', 'copas'), c('8', 'copas'), c('9', 'copas'), c('10', 'copas')]);
    expect(r['tipo'], 'suja');
  });
  test('JOGO-13 dois 2 (um natural + um curinga) é válido', () {
    final r = vs([c('A', 'copas'), c('2', 'copas'), c('2', 'ouros'), c('3', 'copas'), c('4', 'copas'), c('5', 'copas'), c('6', 'copas')]);
    expect(r['valido'], true);
  });
  test('JOGO-14 Ás BAIXO válido (A-2-3)', () {
    expect(vs([c('A', 'paus'), c('2', 'paus'), c('3', 'paus')])['valido'], true);
  });
  test('JOGO-15 Ás ALTO válido (Q-K-A)', () {
    expect(vs([c('Q', 'paus'), c('K', 'paus'), c('A', 'paus')])['valido'], true);
  });
  test('JOGO-16 Ás não dá a volta (K-A-2-3 é inválido)', () {
    expect(vs([c('K', 'paus'), c('A', 'paus'), c('2', 'paus'), c('3', 'paus')])['valido'], isNot(true));
  });
  test('JOGO-16b J-Q-K-A-2 não vira limpa contígua (sem volta)', () {
    final r = vs([c('J', 'paus'), c('Q', 'paus'), c('K', 'paus'), c('A', 'paus'), c('2', 'paus')]);
    final limpaContigua = r['valido'] == true && r['tipo'] == 'limpa' && r['qtd_curingas'] == 0;
    expect(limpaContigua, isFalse);
  });
  test('JOGO-17 500: 13 naturais A..K → de_500', () {
    final r = vs([for (final v in ['A', '2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K']) c(v, 'ouros')]);
    expect(r['tipo'], 'de_500');
  });
  test('JOGO-18 1000: 14 naturais A..K-A → as_a_as', () {
    final r = vs([for (final v in ['A', '2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K']) c(v, 'ouros'), c('A', 'ouros')]);
    expect(r['tipo'], 'as_a_as');
  });
  test('JOGO-19 13 cartas COM curinga não é 500 (vira suja)', () {
    final r = vs([for (final v in ['A', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K']) c(v, 'ouros'), cj()]);
    expect(r['tipo'], 'suja');
  });
  test('JOGO-20 três Ases NÃO valem no Aberto', () {
    final r = baixaEm('ABERTO', const [('A', 'copas'), ('A', 'ouros'), ('A', 'paus')]);
    expect(r['ok'], isNot(true));
  });
  test('JOGO-21 trinca 8-8-8 é VÁLIDA no Fechado', () {
    final r = baixaEm('FECHADO', const [('8', 'copas'), ('8', 'ouros'), ('8', 'paus')]);
    expect(r['ok'], true);
  });
  test('JOGO-22 trinca com JOKER é INVÁLIDA (spec: só natural)', () {
    final r = baixaEm('FECHADO', const [('8', 'copas'), ('8', 'ouros'), ('JOKER', null)]);
    expect(r['ok'], isNot(true));
  });
  test('JOGO-23 trinca com 2 de OUTRO valor (curinga) é INVÁLIDA (spec: só natural)', () {
    final r = baixaEm('FECHADO', const [('8', 'copas'), ('8', 'ouros'), ('2', 'paus')]);
    expect(r['ok'], isNot(true));
  });
  test('JOGO-24 trinca com DOIS curingas é inválida', () {
    final r = baixaEm('FECHADO', const [('8', 'copas'), ('JOKER', null), ('2', 'paus')]);
    expect(r['ok'], isNot(true));
  });
  test('JOGO-25 trinca é INVÁLIDA no Aberto', () {
    final r = baixaEm('ABERTO', const [('8', 'copas'), ('8', 'ouros'), ('8', 'paus')]);
    expect(r['ok'], isNot(true));
  });
  test('JOGO-26 trinca é INVÁLIDA no STBL', () {
    final r = baixaEm('SBTL', const [('8', 'copas'), ('8', 'ouros'), ('8', 'paus')]);
    expect(r['ok'], isNot(true));
  });
  test('JOGO-27 trinca de ASES é válida no Fechado', () {
    final r = baixaEm('FECHADO', const [('A', 'copas'), ('A', 'ouros'), ('A', 'paus')]);
    expect(r['ok'], true);
  });
  test('JOGO-28 trinca de 2s é válida no Fechado', () {
    final r = baixaEm('FECHADO', const [('2', 'copas'), ('2', 'ouros'), ('2', 'paus')]);
    expect(r['ok'], true);
  });
  test('JOGO-29 trinca 7+ natural é válida mas NÃO é canastra (tipo trinca, sem limpa)', () {
    final r = baixaEm('FECHADO', const [
      ('9', 'copas'), ('9', 'ouros'), ('9', 'paus'), ('9', 'espadas'),
      ('9', 'copas'), ('9', 'ouros'), ('9', 'paus')
    ]);
    expect(r['ok'], true);
    expect(r['tipo'], 'trinca'); // nunca 'limpa' — trinca não forma canastra
  });
  test('JOGO-30 trinca 7+ COM curinga (JOKER) é INVÁLIDA (spec: só natural)', () {
    final r = baixaEm('FECHADO', const [
      ('9', 'copas'), ('9', 'ouros'), ('9', 'paus'), ('9', 'espadas'),
      ('9', 'copas'), ('9', 'ouros'), ('JOKER', null)
    ]);
    expect(r['ok'], isNot(true));
  });
  test('JOGO-31 mistura trinca+sequência (8-8-9) é inválida', () {
    final r = baixaEm('FECHADO', const [('8', 'copas'), ('8', 'ouros'), ('9', 'copas')]);
    expect(r['ok'], isNot(true));
  });
  // ===== TRINCA CANÔNICA (P1 — spec Sônia: só cartas naturais do mesmo valor) =====
  test('TRIN-01 três "2" NATURAIS formam trinca válida (Fechado)', () {
    final r = baixaEm('FECHADO', const [('2', 'copas'), ('2', 'ouros'), ('2', 'paus')]);
    expect(r['ok'], true);
    expect(r['tipo'], 'trinca');
  });
  test('TRIN-02 Joker em trinca é INVÁLIDA', () {
    final r = baixaEm('FECHADO', const [('K', 'copas'), ('K', 'ouros'), ('JOKER', null)]);
    expect(r['ok'], isNot(true));
  });
  test('TRIN-03 "2" como substituto em trinca de OUTRO valor é INVÁLIDA', () {
    final r = baixaEm('FECHADO', const [('K', 'copas'), ('K', 'ouros'), ('2', 'paus')]);
    expect(r['ok'], isNot(true));
  });
  test('TRIN-04 trinca 7+ NÃO forma canastra e NÃO libera batida', () {
    final j = novo('FECHADO');
    final trinca = <Carta>[
      c('9', 'copas'), c('9', 'ouros'), c('9', 'paus'), c('9', 'espadas'),
      c('9', 'copas'), c('9', 'ouros'), c('9', 'paus')
    ];
    j.jogosDupla['nos'] = [trinca];
    expect(j.duplaPodeBater('nos'), false,
        reason: 'trinca 7+ é só trinca (não canastra) — não pode liberar a batida');
  });
  test('JOGO-32 SUJA vira LIMPA quando a carta real entra', () {
    final j = novo('ABERTO');
    montar(j, mao0: const [
      ('2', 'copas'), ('4', 'copas'), ('5', 'copas'), ('6', 'copas'),
      ('7', 'copas'), ('8', 'copas'), ('9', 'copas'), ('3', 'copas'), ('K', 'paus')
    ], vez: 0, jaComprou: true);
    final ids7 = idsMao(j, 0).sublist(0, 7);
    final r1 = j.baixar(0, ids7);
    expect(r1['tipo'], 'suja');
    final tres = j.maos[0].firstWhere((x) => x.valor == '3').id;
    final r2 = j.estender(0, 0, [tres]);
    expect(r2['tipo'], 'limpa');
  });
  test('JOGO-33 ordenarMeld: JOKER fica no buraco (4-★-6)', () {
    final m = jv.ordenarMeld([c('4', 'ouros'), cj(), c('6', 'ouros')]);
    expect([for (final x in m) x.valor], ['4', 'JOKER', '6']);
  });
  test('JOGO-34 MELD-003: 2-curinga no buraco e Ás alto no fim', () {
    final m = jv.ordenarMeld([c('10', 'paus'), c('J', 'paus'), c('K', 'paus'), c('A', 'paus'), c('2', 'paus')]);
    expect([for (final x in m) x.valor], ['10', 'J', '2', 'K', 'A']);
  });
  test('JOGO-35 substituto do ★ é o 3 da lacuna, com id virt_ (fora do estado)', () {
    final m = jv.ordenarMeld([c('A', 'copas'), c('2', 'copas'), c('4', 'copas'), c('5', 'copas'), c('6', 'copas'), cj()]);
    final subs = jv.substitutosMeld(m);
    final pos = m.indexWhere((x) => x.valor == 'JOKER');
    expect(pos, isNonNegative);
    expect(subs[pos]?.valor, '3');
    expect(subs[pos]!.id.startsWith('virt_'), isTrue);
  });
  test('CUR-01 curinga baixado mantém identidade JOKER (substituto só p/ exibição)', () {
    // A carta RENDERIZADA continua sendo o joker (_meldCardFace usa `original`);
    // o valor substituído existe só p/ exibição/validação, nunca troca a carta.
    final m = jv.ordenarMeld([c('4', 'ouros'), cj(), c('6', 'ouros')]);
    final subs = jv.substitutosMeld(m);
    final pos = m.indexWhere((x) => x.valor == 'JOKER');
    expect(pos, isNonNegative);
    expect(m[pos].valor, 'JOKER'); // identidade preservada
    expect(m[pos].ehCoringa, isTrue);
    expect(subs[pos]?.valor, '5'); // valor representado só p/ exibição (=5)
    expect(subs[pos]!.valor == 'JOKER', isFalse);
  });

  // ================= FLUX — monte, lixo, morto, turno (20) =================
  test('FLUX-01 comprarMonte transfere exatamente 1 carta', () {
    final j = novo();
    montar(j, mao0: const [('5', 'copas'), ('K', 'paus')], vez: 0);
    j.comprarMonte(0);
    expect(j.maos[0].length, 3);
    expect(j.jaComprou, isTrue);
  });
  test('FLUX-02 segunda compra no mesmo turno é recusada', () {
    final j = novo();
    montar(j, mao0: const [('5', 'copas'), ('K', 'paus')], vez: 0);
    j.comprarMonte(0);
    expect(j.comprarMonte(0), isFalse);
  });
  test('FLUX-03 comprarLixo leva TODAS as cartas do lixo', () {
    final j = novo();
    montar(j, mao0: const [('K', 'paus')],
        lixo: const [('4', 'ouros'), ('9', 'paus'), ('7', 'copas')], vez: 0);
    j.comprarLixo(0, modalidade: 'ABERTO');
    expect(j.lixo, isEmpty);
    expect(j.maos[0].length, 4);
  });
  test('FLUX-04 lixo vazio → compra recusada', () {
    final j = novo();
    montar(j, mao0: const [('K', 'paus')], vez: 0);
    expect(j.comprarLixo(0)['ok'], isFalse);
  });
  test('FLUX-05 Fechado: topo SEM uso → recusa e lixo intacto', () {
    final j = novo('FECHADO');
    montar(j, mao0: const [('K', 'paus'), ('3', 'ouros')],
        lixo: const [('9', 'copas'), ('7', 'espadas')], vez: 0);
    final r = j.comprarLixo(0, modalidade: 'FECHADO');
    expect(r['ok'], isFalse);
    expect(j.lixo.length, 2);
  });
  test('FLUX-06 Fechado: topo estende jogo da dupla → permitida com obrigação', () {
    final j = novo('FECHADO');
    montar(j, mao0: const [('K', 'paus')],
        mesaNos: const [[('5', 'copas'), ('6', 'copas'), ('7', 'copas')]],
        lixo: const [('9', 'ouros'), ('8', 'copas')], vez: 0);
    final r = j.comprarLixo(0, modalidade: 'FECHADO');
    expect(r['ok'], true);
    expect(j.lixoTopoObrigatorio, isNotNull);
  });
  test('FLUX-07 Fechado: topo forma TRINCA com par da mão → permitida', () {
    final j = novo('FECHADO');
    montar(j, mao0: const [('9', 'copas'), ('9', 'ouros'), ('K', 'paus')],
        lixo: const [('4', 'espadas'), ('9', 'paus')], vez: 0);
    expect(j.comprarLixo(0, modalidade: 'FECHADO')['ok'], true);
  });
  test('FLUX-08/09 obrigação bloqueia o descarte e é liberada BAIXANDO o topo', () {
    final j = novo('FECHADO');
    montar(j, mao0: const [('9', 'copas'), ('9', 'ouros'), ('K', 'paus')],
        lixo: const [('4', 'espadas'), ('9', 'paus')], vez: 0);
    j.comprarLixo(0, modalidade: 'FECHADO');
    final k = j.maos[0].firstWhere((x) => x.valor == 'K').id;
    expect(j.descartar(0, k), contains('use a carta do topo'));
    final topo = j.lixoTopoObrigatorio!;
    final par = [for (final x in j.maos[0]) if (x.valor == '9' && x.id != topo) x.id];
    expect(j.baixar(0, [topo, par[0], par[1]])['ok'], true);
    expect(j.descartar(0, k), isNull);
  });
  test('FLUX-10 obrigação cumprida ESTENDENDO → descarte liberado', () {
    final j = novo('FECHADO');
    montar(j, mao0: const [('K', 'paus'), ('3', 'ouros')],
        mesaNos: const [[('5', 'copas'), ('6', 'copas'), ('7', 'copas')]],
        lixo: const [('9', 'ouros'), ('8', 'copas')], vez: 0);
    j.comprarLixo(0, modalidade: 'FECHADO');
    j.estender(0, 0, [j.lixoTopoObrigatorio!]);
    final k = j.maos[0].firstWhere((x) => x.valor == 'K').id;
    expect(j.descartar(0, k), isNull);
  });
  test('FLUX-11 Aberto: compra LIVRE e sem obrigação', () {
    final j = novo();
    montar(j, mao0: const [('K', 'paus'), ('3', 'ouros')],
        lixo: const [('9', 'copas'), ('7', 'espadas')], vez: 0);
    expect(j.comprarLixo(0, modalidade: 'ABERTO')['ok'], true);
    expect(j.lixoTopoObrigatorio, isNull);
  });
  test('FLUX-12/13 Aberto anti-turno-nulo: mesma carta recusada; outra permitida', () {
    final j = novo();
    montar(j, mao0: const [('K', 'paus'), ('3', 'ouros')],
        lixo: const [('9', 'copas')], vez: 0);
    j.comprarLixo(0, modalidade: 'ABERTO');
    final nove = j.maos[0].firstWhere((x) => x.valor == '9').id;
    expect(j.descartar(0, nove), contains('não pode devolvê-la'));
    final outra = j.maos[0].firstWhere((x) => x.id != nove).id;
    expect(j.descartar(0, outra), isNull);
  });
  test('FLUX-14 descarte passa a vez (0→1) e zera jaComprou', () {
    final j = novo();
    montar(j, mao0: const [('5', 'copas'), ('K', 'paus')], vez: 0, jaComprou: true);
    j.descartar(0, j.maos[0][0].id);
    expect(j.vez, 1);
    expect(j.jaComprou, isFalse);
  });
  test('FLUX-15 descartar sem ter comprado é recusado', () {
    final j = novo();
    montar(j, mao0: const [('5', 'copas'), ('K', 'paus')], vez: 0);
    expect(j.descartar(0, j.maos[0][0].id), isNotNull);
  });
  test('FLUX-16 morto INDIRETO: recebe 11 e a vez PASSA', () {
    final j = novo();
    montar(j, mao0: const [('5', 'copas')],
        mesaNos: const [[('9', 'ouros'), ('10', 'ouros'), ('J', 'ouros')]],
        vez: 0, jaComprou: true);
    j.descartar(0, j.maos[0][0].id);
    expect(j.maos[0].length, 11);
    expect(j.mortoPego['nos'], isTrue);
    expect(j.vez, 1);
  });
  test('FLUX-17 morto DIRETO: zera baixando, MESMA vez, e ainda deve descartar', () {
    final j = novo();
    montar(j, mao0: const [('5', 'copas'), ('6', 'copas'), ('7', 'copas')],
        vez: 0, jaComprou: true);
    final r = j.baixar(0, idsMao(j, 0));
    expect(r['pegouMorto'], true);
    expect(j.maos[0].length, 11);
    expect(j.vez, 0);
    expect(j.jaComprou, isTrue);
  });
  test('FLUX-18 cada dupla pega no MÁXIMO 1 morto', () {
    final j = novo();
    montar(j, mao0: const [('5', 'copas')], mao2: const [('8', 'ouros')],
        mesaNos: const [[('9', 'ouros'), ('10', 'ouros'), ('J', 'ouros')]],
        vez: 0, jaComprou: true);
    j.descartar(0, j.maos[0][0].id); // nós pegamos o morto 1
    final mortosAntes = j.mortos.length;
    j.vez = 2;
    j.jaComprou = true;
    final r = j.descartar(2, j.maos[2][0].id);
    expect(j.mortos.length == mortosAntes || r != null, isTrue);
  });
  test('FLUX-19 monte vazio: MORTO vira monte na compra', () {
    final j = novo();
    montar(j, mao0: const [('5', 'copas'), ('K', 'paus')], vez: 0);
    j.mortos[0].addAll(j.monte);
    j.monte = [];
    j.auditarIntegridade();
    expect(j.comprarMonte(0), isTrue);
    expect(j.mortos.length, 1);
  });
  test('FLUX-20 monte E mortos vazios → rodada encerra por falta de compra', () {
    final j = novo();
    montar(j, mao0: const [('5', 'copas'), ('K', 'paus')], vez: 0);
    j.lixo.addAll(j.monte);
    j.lixo.addAll(j.mortos[0]);
    j.lixo.addAll(j.mortos[1]);
    j.monte = [];
    j.mortos = [];
    j.auditarIntegridade();
    expect(j.comprarMonte(0), isFalse);
    expect(j.rodadaEncerrada, isTrue);
  });

  // ================= PONT — pontuação e vulnerabilidade (15) =================
  Map<String, dynamic> fechaEconta(Jogo j, {String? bateu}) {
    j.rodadaEncerrada = true;
    j.duplaQueBateu = bateu;
    j.contarPontos();
    return (j.pontosRodada!['nos'] as Map).cast<String, dynamic>();
  }

  test('PONT-01 tabela: A=15, 2=10, 5=5, K=10, JOKER=50 (via desconto da mão)', () {
    final j = novo();
    montar(j, mao0: const [('A', 'copas'), ('2', 'copas'), ('5', 'copas'), ('K', 'paus'), ('JOKER', null)]);
    j.mortoPego = {'nos': true, 'eles': true};
    final r = fechaEconta(j);
    expect(r['descontoMao'], -(15 + 10 + 5 + 10 + 50));
  });
  test('PONT-02 canastra SUJA soma bônus 100', () {
    final j = novo();
    montar(j, mesaNos: const [[('4', 'copas'), ('2', 'ouros'), ('6', 'copas'), ('7', 'copas'), ('8', 'copas'), ('9', 'copas'), ('10', 'copas')]]);
    j.mortoPego = {'nos': true, 'eles': true};
    expect(fechaEconta(j)['canastras'], 100);
  });
  test('PONT-03 canastra LIMPA soma bônus 200', () {
    final j = novo();
    montar(j, mesaNos: const [[('4', 'copas'), ('5', 'copas'), ('6', 'copas'), ('7', 'copas'), ('8', 'copas'), ('9', 'copas'), ('10', 'copas')]]);
    j.mortoPego = {'nos': true, 'eles': true};
    expect(fechaEconta(j)['canastras'], 200);
  });
  test('PONT-04 canastra de 500 soma 500', () {
    final j = novo();
    montar(j, mesaNos: const [[
      ('A', 'ouros'), ('2', 'ouros'), ('3', 'ouros'), ('4', 'ouros'), ('5', 'ouros'), ('6', 'ouros'),
      ('7', 'ouros'), ('8', 'ouros'), ('9', 'ouros'), ('10', 'ouros'), ('J', 'ouros'), ('Q', 'ouros'), ('K', 'ouros')
    ]]);
    j.mortoPego = {'nos': true, 'eles': true};
    expect(fechaEconta(j)['canastras'], 500);
  });
  test('PONT-05 canastra de 1000 soma 1000 (só o maior bônus)', () {
    final j = novo();
    montar(j, mesaNos: const [[
      ('A', 'ouros'), ('2', 'ouros'), ('3', 'ouros'), ('4', 'ouros'), ('5', 'ouros'), ('6', 'ouros'),
      ('7', 'ouros'), ('8', 'ouros'), ('9', 'ouros'), ('10', 'ouros'), ('J', 'ouros'), ('Q', 'ouros'),
      ('K', 'ouros'), ('A', 'ouros')
    ]]);
    j.mortoPego = {'nos': true, 'eles': true};
    expect(fechaEconta(j)['canastras'], 1000);
  });
  test('PONT-06 batida soma +100', () {
    final j = novo();
    montar(j);
    j.mortoPego = {'nos': true, 'eles': true};
    expect(fechaEconta(j, bateu: 'nos')['bonusBatida'], 100);
  });
  test('PONT-07 cartas na mão descontam (A+K = -25)', () {
    final j = novo();
    montar(j, mao0: const [('A', 'copas'), ('K', 'paus')]);
    j.mortoPego = {'nos': true, 'eles': true};
    expect(fechaEconta(j)['descontoMao'], -25);
  });
  test('PONT-08 dupla sem morto (outra pegou, sem conversão) leva -100', () {
    final j = novo();
    montar(j);
    j.mortoPego = {'nos': false, 'eles': true};
    expect(fechaEconta(j)['penalidadeMorto'], -100);
  });
  test('PONT-09 morto CONVERTIDO em monte isenta o -100', () {
    final j = novo();
    montar(j, mao0: const [('5', 'copas'), ('K', 'paus')], vez: 0, jaComprou: true);
    j.mortos[0].addAll(j.monte);
    j.monte = [];
    j.auditarIntegridade();
    j.descartar(0, j.maos[0][0].id); // _passarVez converte o morto em monte
    j.mortoPego = {'nos': false, 'eles': true};
    expect(fechaEconta(j)['penalidadeMorto'], 0);
  });
  test('PONT-10 morto pego (mesmo sem usar) não leva -100', () {
    final j = novo();
    montar(j);
    j.mortoPego = {'nos': true, 'eles': true};
    expect(fechaEconta(j)['penalidadeMorto'], 0);
  });
  test('PONT-11 meta 1500 com vencedor → partida encerra', () {
    final j = novo();
    montar(j);
    j.mortoPego = {'nos': true, 'eles': true};
    j.placar = {'nos': 1550, 'eles': 300};
    j.rodadaEncerrada = true;
    j.contarPontos();
    expect(j.encerrada, isTrue);
  });
  test('PONT-12 EMPATE exato na meta → NÃO encerra (rodada extra)', () {
    final j = novo();
    montar(j);
    j.mortoPego = {'nos': true, 'eles': true};
    j.placar = {'nos': 1600, 'eles': 1600};
    j.rodadaEncerrada = true;
    j.contarPontos();
    expect(j.encerrada, isFalse);
  });
  test('PONT-13 ambas acima da meta → MAIOR total vence (encerra)', () {
    final j = novo();
    montar(j);
    j.mortoPego = {'nos': true, 'eles': true};
    j.placar = {'nos': 1520, 'eles': 1580};
    j.rodadaEncerrada = true;
    j.contarPontos();
    expect(j.encerrada, isTrue);
  });
  test('PONT-14 vulnerável a partir de meta/2: mínimos 75 → 90', () {
    final j = novo();
    j.metaPontos = 1500;
    j.placar = {'nos': 750, 'eles': 0};
    j.novaRodada();
    expect(j.minimoParaDescer('nos'), 75);
    j.placar = {'nos': 800, 'eles': 0};
    j.novaRodada();
    expect(j.minimoParaDescer('nos'), 90);
  });
  test('PONT-15 abertura vulnerável: baixada de 15 pts é rejeitada', () {
    final j = novo();
    montar(j, mao0: const [
      ('3', 'copas'), ('4', 'copas'), ('5', 'copas'), ('K', 'paus'), ('K', 'ouros'), ('A', 'espadas')
    ], vez: 0, jaComprou: true);
    j.rodadasVulneravel = {'nos': 1, 'eles': 0};
    final ids = idsMao(j, 0).sublist(0, 3);
    final r = j.baixar(0, ids);
    expect(r['ok'], isFalse);
    expect('${r['erro']}', contains('Vulnerável'));
  });

  // ================= BOT — mesmo validador (15) =================
  test('BOT-01 turno do bot preserva as 108 cartas e a integridade', () {
    final j = novo()..vez = 1;
    j.jaComprou = false;
    j.botJoga(1);
    expect(totalCartas(j), 108);
    expect(j.integridadeErro, isNull);
  });
  test('BOT-02 Fechado: bot NÃO pega lixo sem justificativa', () {
    final j = novo('FECHADO');
    montar(j,
        mao1: const [('K', 'paus'), ('3', 'ouros'), ('8', 'copas'), ('J', 'espadas'), ('5', 'ouros')],
        lixo: const [('9', 'copas'), ('7', 'espadas')], vez: 1);
    final lixoAntes = j.lixo.length;
    j.botJoga(1);
    expect(j.lixo.length >= lixoAntes, isTrue);
    expect(j.integridadeErro, isNull);
  });
  test('BOT-03/04 bot nunca termina o turno com obrigação pendente', () {
    final j = novo('FECHADO');
    montar(j,
        mao1: const [('9', 'copas'), ('9', 'ouros'), ('K', 'paus'), ('3', 'espadas'), ('J', 'ouros')],
        lixo: const [('4', 'espadas'), ('9', 'paus')], vez: 1);
    j.botJoga(1);
    expect(j.lixoTopoObrigatorio, isNull);
    expect(j.integridadeErro, isNull);
  });
  test('BOT-05 após 60 turnos de bot, TODOS os jogos na mesa são válidos', () {
    final j = novo('FECHADO');
    for (var i = 0; i < 60 && !j.rodadaEncerrada; i++) {
      j.botJoga(j.vez);
    }
    bool trincaValida(List<Carta> m) {
      // espelho da regra §4.3: mesmo valor, máx. 1 curinga substituto
      final naoJk = [for (final x in m) if (x.valor != 'JOKER') x];
      if (naoJk.isEmpty || m.length < 3) return false;
      final cont = <String, int>{};
      for (final x in naoJk) {
        cont[x.valor] = (cont[x.valor] ?? 0) + 1;
      }
      final valor = (cont.entries.toList()..sort((a, b) => b.value - a.value)).first.key;
      final subs = [for (final x in naoJk) if (x.valor != valor) x];
      if (subs.any((x) => x.valor != '2')) return false;
      return (m.length - naoJk.length) + subs.length <= 1;
    }

    for (final d in ['nos', 'eles']) {
      for (final m in j.jogosDupla[d]!) {
        final okSeq = j.validarSequencia(m)['valido'] == true;
        expect(okSeq || trincaValida(m), isTrue, reason: 'jogo inválido na mesa: $m');
      }
    }
    expect(j.integridadeErro, isNull);
  });
  test('BOT-06 bot respeita a abertura vulnerável (1ª baixada ≥ 75)', () {
    final j = novo();
    j.placar = {'nos': 800, 'eles': 800};
    j.novaRodada();
    final aberturas = <int>[];
    for (var i = 0; i < 80 && !j.rodadaEncerrada; i++) {
      final d = j.vez % 2 == 0 ? 'nos' : 'eles';
      final abertaAntes = j.primeiraBaixadaFeita[d]!;
      final nAntes = j.jogosDupla[d]!.length;
      j.botJoga(j.vez);
      if (!abertaAntes && j.jogosDupla[d]!.length > nAntes) {
        var soma = 0;
        for (final x in j.jogosDupla[d]![nAntes]) {
          soma += pts(x);
        }
        aberturas.add(soma);
      }
    }
    expect(aberturas.every((s) => s >= 75), isTrue, reason: '$aberturas');
  });
  test('BOT-07 bot bloqueado por integridade não altera nenhuma mão', () {
    final j = corrompido()..vez = 1;
    final estado = [for (var a = 0; a < 4; a++) idsMao(j, a)];
    j.botJoga(1);
    expect([for (var a = 0; a < 4; a++) idsMao(j, a)], estado);
  });
  test('BOT-08 botJoga FORA da vez não faz nada', () {
    final j = novo()..vez = 0;
    final mao = idsMao(j, 1);
    j.botJoga(1);
    expect(idsMao(j, 1), mao);
  });
  test('BOT-09 bot em rodada encerrada não faz nada', () {
    final j = novo()..rodadaEncerrada = true;
    j.vez = 1;
    final mao = idsMao(j, 1);
    j.botJoga(1);
    expect(idsMao(j, 1), mao);
  });
  test('BOT-10 ao fim do turno o bot descartou 1 carta (lixo cresceu) ou fechou', () {
    final j = novo()..vez = 1;
    final lixoAntes = j.lixo.length;
    j.botJoga(1);
    expect(j.lixo.length > lixoAntes || j.rodadaEncerrada || j.maos[1].length == 11,
        isTrue);
  });
  test('BOT-11 40 turnos seguidos preservam 108 cartas (SBTL)', () {
    final j = novo('SBTL');
    for (var i = 0; i < 40 && !j.rodadaEncerrada; i++) {
      j.botJoga(j.vez);
      expect(totalCartas(j), 108);
      expect(j.integridadeErro, isNull);
    }
  });
  test('BOT-12 se a rodada terminou por batida, a dupla PODIA bater', () {
    final j = novo();
    for (var i = 0; i < 400 && !j.rodadaEncerrada; i++) {
      j.botJoga(j.vez);
    }
    if (j.duplaQueBateu != null) {
      expect(j.duplaPodeBater(j.duplaQueBateu!), isTrue);
    }
  });
  test('BOT-13 bots pegam morto ao zerar a mão (ou a rodada termina)', () {
    final j = novo();
    var pegou = false;
    for (var i = 0; i < 400 && !j.rodadaEncerrada; i++) {
      j.botJoga(j.vez);
      if (j.mortoPego['nos']! || j.mortoPego['eles']!) {
        pegou = true;
        break;
      }
    }
    expect(pegou || j.rodadaEncerrada, isTrue);
  });
  test('BOT-14 MESMO validador: 5-6-8 recusado IGUAL pra humano e pra bot', () {
    final jh = novo();
    montar(jh, mao0: const [('5', 'copas'), ('6', 'copas'), ('8', 'copas'), ('K', 'paus')], vez: 0, jaComprou: true);
    final rh = jh.baixar(0, idsMao(jh, 0).sublist(0, 3));
    final jb = novo();
    montar(jb, mao1: const [('5', 'copas'), ('6', 'copas'), ('8', 'copas'), ('K', 'paus')], vez: 1, jaComprou: true);
    final rb = jb.baixar(1, idsMao(jb, 1).sublist(0, 3));
    expect(rh['ok'], isFalse);
    expect(rb['ok'], isFalse);
    expect(rh['erro'], rb['erro']);
  });
  test('BOT-15 o descarte do bot NUNCA sai da mão de outro jogador nem da mesa', () {
    final j = novo()..vez = 1;
    final proibidos = <String>{
      for (var a = 0; a < 4; a++)
        if (a != 1) ...idsMao(j, a),
      for (final d in ['nos', 'eles'])
        for (final g in j.jogosDupla[d]!)
          for (final x in g) x.id,
    };
    final lixoAntes = j.lixo.length;
    j.botJoga(1);
    if (j.lixo.length > lixoAntes) {
      expect(proibidos.contains(j.lixo.last.id), isFalse);
    }
  });

  // ================= TRX — transação e idempotência (10) =================
  test('TRX-01 baixada inválida: NADA muda', () {
    final j = novo();
    montar(j, mao0: const [('5', 'copas'), ('6', 'copas'), ('8', 'copas'), ('K', 'paus')], vez: 0, jaComprou: true);
    final mao = idsMao(j, 0);
    j.baixar(0, mao.sublist(0, 3));
    expect(idsMao(j, 0), mao);
    expect(j.jogosDupla['nos'], isEmpty);
  });
  test('TRX-02 MELD-002: extensão inválida → jogo original PRESERVADO', () {
    final j = novo();
    montar(j, mao0: const [('K', 'paus'), ('3', 'ouros')],
        mesaNos: const [[('5', 'copas'), ('6', 'copas'), ('7', 'copas')]],
        vez: 0, jaComprou: true);
    final jogoAntes = [for (final x in j.jogosDupla['nos']![0]) x.id];
    j.estender(0, 0, [j.maos[0].firstWhere((x) => x.valor == 'K').id]);
    expect([for (final x in j.jogosDupla['nos']![0]) x.id], jogoAntes);
  });
  test('TRX-03 descarte inválido preserva mão e lixo', () {
    final j = novo();
    montar(j, mao0: const [('5', 'copas'), ('K', 'paus')], vez: 0);
    final mao = idsMao(j, 0);
    j.descartar(0, mao[0]);
    expect(idsMao(j, 0), mao);
    expect(j.lixo, isEmpty);
  });
  test('TRX-04 compra do lixo recusada preserva lixo e mão', () {
    final j = novo('FECHADO');
    montar(j, mao0: const [('K', 'paus'), ('3', 'ouros')],
        lixo: const [('9', 'copas'), ('7', 'espadas')], vez: 0);
    final mao = idsMao(j, 0);
    final lixo = [for (final x in j.lixo) x.id];
    j.comprarLixo(0, modalidade: 'FECHADO');
    expect(idsMao(j, 0), mao);
    expect([for (final x in j.lixo) x.id], lixo);
  });
  test('TRX-05 comando repetido: 2º descarte da mesma carta falha e não duplica', () {
    final j = novo();
    montar(j, mao0: const [('5', 'copas'), ('K', 'paus')], vez: 0, jaComprou: true);
    final cid = j.maos[0][0].id;
    j.descartar(0, cid);
    final lixoDepois = j.lixo.length;
    expect(j.descartar(0, cid), isNotNull);
    expect(j.lixo.length, lixoDepois);
  });
  test('TRX-06 comando repetido: 2ª compra falha e não tira 2ª carta', () {
    final j = novo();
    montar(j, mao0: const [('5', 'copas'), ('K', 'paus')], vez: 0);
    j.comprarMonte(0);
    final n = j.maos[0].length;
    j.comprarMonte(0);
    expect(j.maos[0].length, n);
  });
  test('TRX-07 baixar com id repetido é recusado sem efeito', () {
    final j = novo();
    montar(j, mao0: const [('5', 'copas'), ('6', 'copas'), ('7', 'copas'), ('K', 'paus')], vez: 0, jaComprou: true);
    final cid = j.maos[0][0].id;
    final r = j.baixar(0, [cid, cid, j.maos[0][1].id]);
    expect(r['ok'], isFalse);
    expect(j.maos[0].length, 4);
  });
  test('TRX-08 baixar com carta fora da mão é recusado sem efeito', () {
    final j = novo();
    montar(j, mao0: const [('5', 'copas'), ('6', 'copas'), ('7', 'copas')], vez: 0, jaComprou: true);
    final r = j.baixar(0, ['id_inexistente', j.maos[0][0].id, j.maos[0][1].id]);
    expect(r['ok'], isFalse);
    expect(j.maos[0].length, 3);
  });
  test('TRX-09 corrupção entre jogadas é detectada no fim do turno', () {
    final j = novo()..vez = 0;
    j.comprarMonte(0);
    j.maos[2].add(Carta('intruso', 'copas', '5', false));
    j.descartar(0, j.maos[0][0].id);
    expect(j.integridadeErro, isNotNull);
  });
  test('TRX-10 rodada completa de bots termina ÍNTEGRA', () {
    final j = novo('FECHADO');
    for (var i = 0; i < 600 && !j.rodadaEncerrada; i++) {
      j.botJoga(j.vez);
    }
    expect(totalCartas(j), 108);
    expect(j.integridadeErro, isNull);
  });

  // ============ ADENDOS exigidos antes do APK candidato (31/07) ============
  test('FLUX-21 conversão do morto da dupla correspondente isenta o -100 (fluxo real)', () {
    final j = novo();
    montar(j,
        mao0: const [('K', 'paus'), ('Q', 'ouros')],
        mao1: const [('5', 'copas')],
        mesaEles: const [[('9', 'ouros'), ('10', 'ouros'), ('J', 'ouros')]],
        vez: 1, jaComprou: true);
    j.descartar(1, j.maos[1][0].id); // ELES zeram → pegam o morto 1 (indireto)
    expect(j.mortoPego['eles'], isTrue);
    expect(j.mortoPego['nos'], isFalse);
    expect(j.mortos.length, 1);
    j.lixo.addAll(j.monte); // esgota o monte (108 cartas preservadas)
    j.monte = [];
    j.auditarIntegridade();
    expect(j.integridadeErro, isNull);
    j.vez = 0;
    j.jaComprou = true;
    j.descartar(0, j.maos[0][0].id); // passar a vez CONVERTE o morto 2 em monte
    expect(j.mortos, isEmpty);
    j.rodadaEncerrada = true;
    j.contarPontos();
    expect((j.pontosRodada!['nos'] as Map)['penalidadeMorto'], 0,
        reason: 'NÓS sem morto por CONVERSÃO → sem -100');
    expect((j.pontosRodada!['eles'] as Map)['penalidadeMorto'], 0,
        reason: 'ELES pegou o seu morto → sem -100');
  });
  test('NOME-01 STBL e SBTL: as duas grafias aplicam regras IDÊNTICAS', () {
    for (final grafia in ['STBL', 'SBTL', 'stbl', 'sbtl']) {
      final rTrinca = baixaEm(grafia, const [('8', 'copas'), ('8', 'ouros'), ('8', 'paus')]);
      expect(rTrinca['ok'], isNot(true), reason: 'trinca deveria ser proibida em $grafia');
      final rSeq = baixaEm(grafia, const [('5', 'copas'), ('6', 'copas'), ('7', 'copas')]);
      expect(rSeq['ok'], true, reason: 'sequência deveria valer em $grafia');
    }
  });

  // ================= 12 PARTIDAS COMPLETAS (4 por modalidade) =================
  for (final mod in ['ABERTO', 'FECHADO', 'SBTL']) {
    for (var n = 1; n <= 4; n++) {
      test('PARTIDA-$mod-$n completa: íntegra, 108 cartas e com vencedor', () {
        final j = novo(mod);
        j.metaPontos = 1500;
        for (var rod = 0; rod < 60 && !j.encerrada; rod++) {
          var seg = 0;
          while (!j.rodadaEncerrada && seg < 3000) {
            seg++;
            j.botJoga(j.vez);
            if (j.integridadeErro != null) break;
          }
          expect(j.integridadeErro, isNull);
          j.contarPontos();
          if (!j.encerrada) j.novaRodada();
        }
        expect(j.encerrada, isTrue, reason: 'placar ${j.placar}');
        expect(totalCartas(j), 108);
        expect(j.integridadeErro, isNull);
        expect(j.placar['nos'] != j.placar['eles'], isTrue);
      });
    }
  }

  // ============== AUDITORIA (fase diagnóstica) — invariante P0 + estado x render ==============
  // DETERMINISTICO: seeds fixas, nº de partidas e limite de turnos declarados. Se falhar,
  // o relatorio traz seed+modalidade+rodada+turno+assento+meld+IDs para reproducao exata.
  // NAO depende de debugPrint: a falha e do proprio expect, com relatorio completo.
  // AUD-01: em bot x bot, NENHUM meld ARMAZENADO pode ser ilegal (revalidado pelo motor).
  const kAudSeeds = [1, 2, 3, 7, 11, 13, 17, 23, 42, 99, 123, 777]; // 12 seeds fixas
  const kAudLimiteTurnos = 4000; // limite de turnos por partida (trava de seguranca)
  const kCicloMax = 12; // mesma assinatura de estado repetida >12x numa rodada = ciclo
  for (final mod in ['ABERTO', 'FECHADO', 'SBTL']) {
    test('AUD-01-$mod bot x bot deterministico (${kAudSeeds.length} seeds): sem meld ilegal, sem ciclo', () {
      final sw = Stopwatch()..start();
      var totalTurnos = 0, partidasCompletas = 0;
      final naoConcluidas = <String>[]; // estourou seg/turno sem terminar a rodada
      final ciclos = <String>[]; // estado repetido (assinatura) > kCicloMax numa rodada
      for (final seed in kAudSeeds) {
        final j = novo(mod, seed);
        j.metaPontos = 1500;
        var turno = 0;
        var abortou = false;
        for (var rod = 0; rod < 60 && !j.encerrada && !abortou; rod++) {
          var seg = 0;
          final vistos = <String, int>{}; // assinaturas de estado desta rodada
          while (!j.rodadaEncerrada && seg < 3000 && turno < kAudLimiteTurnos) {
            seg++;
            turno++;
            totalTurnos++;
            final assento = j.vez;
            final sig = '${j.vez}|${j.monte.length}|${j.lixo.length}|'
                '${j.maos.map((m) => m.length).join(',')}|'
                '${j.jogosDupla['nos']!.map((g) => g.length).join('.')}|'
                '${j.jogosDupla['eles']!.map((g) => g.length).join('.')}';
            final n = (vistos[sig] ?? 0) + 1;
            vistos[sig] = n;
            if (n > kCicloMax) {
              ciclos.add('seed=$seed mod=$mod rodada=$rod turno=$turno repetiu=${n}x sig=[$sig]');
              abortou = true;
              break;
            }
            j.botJoga(j.vez);
            final falhas = j.auditarMeldsArmazenados();
            expect(falhas, isEmpty,
                reason: 'ESTADO ILEGAL: seed=$seed mod=$mod rodada=$rod turno=$turno '
                    'assento=$assento :: ${falhas.join(' || ')}');
            if (j.integridadeErro != null) {
              abortou = true;
              break;
            }
          }
          if (!abortou && (seg >= 3000 || turno >= kAudLimiteTurnos)) {
            naoConcluidas.add('seed=$seed mod=$mod rodada=$rod seg=$seg turno=$turno');
            abortou = true;
          }
          if (!abortou) {
            j.contarPontos();
            if (!j.encerrada) j.novaRodada();
          }
        }
        if (!abortou && j.encerrada) partidasCompletas++;
      }
      sw.stop();
      // RELATORIO INTEGRAL (visivel no log do CI com --reporter expanded):
      // ignore: avoid_print
      print('[AUD-01 $mod] duracao=${sw.elapsedMilliseconds}ms seeds=${kAudSeeds.length} '
          'partidas_completas=$partidasCompletas total_turnos=$totalTurnos '
          'nao_concluidas=${naoConcluidas.length} ciclos=${ciclos.length}');
      expect(ciclos, isEmpty, reason: 'CICLO/ESTADO REPETIDO: ${ciclos.join(' ; ')}');
      expect(naoConcluidas, isEmpty, reason: 'NAO CONCLUIDA (possivel loop): ${naoConcluidas.join(' ; ')}');
    });
  }

  // AUD-02: usa o EMPACOTAMENTO REAL do _packedMelds (funcao pura Jogo.empacotarLinhasFFD).
  // Dois jogos LEGAIS de naipes diferentes, cada um terminando em As, caem na MESMA linha
  // (gap 6px < step 20px) -> colam e parecem 1 jogo so com dois aces de naipes diferentes,
  // que na verdade estao em MELDS DIFERENTES (render, nao estado).
  test('AUD-02 render (FFD real): dois jogos legais de naipes diferentes vao pra MESMA linha', () {
    final j = novo('ABERTO');
    final runCopas = [c('J', 'copas'), c('Q', 'copas'), c('K', 'copas'), c('A', 'copas')];
    final runOuros = [c('J', 'ouros'), c('Q', 'ouros'), c('K', 'ouros'), c('A', 'ouros')];
    expect(j.validarSequencia(runCopas)['valido'], true);
    expect(j.validarSequencia(runOuros)['valido'], true);
    final aCopas = runCopas.last, aOuros = runOuros.last;
    expect(aCopas.valor == 'A' && aCopas.naipe == 'copas', true);
    expect(aOuros.valor == 'A' && aOuros.naipe == 'ouros', true);
    expect(identical(runCopas, runOuros), false); // melds DISTINTOS
    const cardWidth = 66.0, step = 20.0, spacing = 6.0; // iguais ao _packedMelds
    double larg(List<Carta> m) => cardWidth + (m.length - 1) * step;
    const larguraUtil = 380.0; // largura tipica da area de jogos
    final jogos = [runCopas, runOuros]; // indices 0 e 1
    final linhas =
        Jogo.empacotarLinhasFFD([for (final g in jogos) larg(g)], larguraUtil, spacing);
    final mesmaLinha = linhas.any((l) => l.contains(0) && l.contains(1));
    expect(mesmaLinha, true,
        reason: 'FFD real: jogo0(A/copas#${aCopas.id}) e jogo1(A/ouros#${aOuros.id}) na MESMA '
            'linha (gap=${spacing}px < step=${step}px) -> colam e parecem 1 jogo so com 2 aces '
            'de naipes diferentes. Linhas=$linhas');
  });

  // ===================================================================
  // C1 — ANDAIME do RulesEngine canônico. Testes ADITIVOS: exercitam só os
  // novos módulos (rules/), sem tocar no comportamento do motor antigo.
  // ===================================================================
  group('C1 — andaime RulesEngine (aditivo, sem comportamento novo)', () {
    test('C1 Modalidade: deTexto/texto e alias SBTL', () {
      expect(Modalidade.deTexto('ABERTO'), Modalidade.aberto);
      expect(Modalidade.deTexto('fechado'), Modalidade.fechado);
      expect(Modalidade.deTexto('STBL'), Modalidade.stbl);
      expect(Modalidade.deTexto('sbtl'), Modalidade.stbl); // typo historico
      expect(Modalidade.aberto.texto, 'ABERTO');
      expect(Modalidade.fechado.texto, 'FECHADO');
      expect(Modalidade.stbl.texto, 'STBL');
      expect(() => Modalidade.deTexto('x'), throwsArgumentError);
    });

    test('C1 RuleSpec: decisoes congeladas por modalidade', () {
      final f = RuleSpec.canonica(Modalidade.fechado);
      expect(f.trincaPermitida, true);
      expect(f.trincaAceitaCuringa, false);
      expect(f.maxCuringasPorSequencia, 1);
      expect(f.exigeUsoDoTopoNoLixo, true);
      expect(f.aberturaMultiplaAtomica, true);
      expect(f.versao, RuleSpec.versaoCanonica);
      final a = RuleSpec.canonica(Modalidade.aberto);
      expect(a.trincaPermitida, false);
      expect(a.exigeUsoDoTopoNoLixo, false);
    });

    test('C1 Vulnerabilidade: faixas EXATAS 0/75/90 e limiar meta/2', () {
      final v = RuleSpec.canonica(Modalidade.fechado, metaPontos: 1500)
          .vulnerabilidade;
      expect(v.limiarAcumulado, 750);
      expect(v.minimoParaDescer(rodadasVulneravel: 0, jaAbriuNaRodada: false), 0);
      expect(v.minimoParaDescer(rodadasVulneravel: 1, jaAbriuNaRodada: false), 75);
      expect(v.minimoParaDescer(rodadasVulneravel: 2, jaAbriuNaRodada: false), 90);
      expect(v.minimoParaDescer(rodadasVulneravel: 5, jaAbriuNaRodada: false), 90);
      expect(v.minimoParaDescer(rodadasVulneravel: 1, jaAbriuNaRodada: true), 0);
      expect(
          RuleSpec.canonica(Modalidade.fechado, metaPontos: 3000)
              .vulnerabilidade
              .limiarAcumulado,
          1500);
    });

    test('C1 Vulnerabilidade: PARIDADE com o motor antigo (minimoParaDescer)',
        () {
      final v = RuleSpec.canonica(Modalidade.fechado).vulnerabilidade;
      for (final rv in [0, 1, 2, 3]) {
        for (final ja in [false, true]) {
          final j = novo('FECHADO');
          j.rodadasVulneravel['nos'] = rv;
          j.primeiraBaixadaFeita['nos'] = ja;
          expect(
              v.minimoParaDescer(rodadasVulneravel: rv, jaAbriuNaRodada: ja),
              j.minimoParaDescer('nos'),
              reason: 'spec deve espelhar o antigo (rv=$rv, jaAbriu=$ja)');
        }
      }
      expect(v.limiarAcumulado, novo('FECHADO').metaPontos ~/ 2);
    });

    test('C1 Pontuacao: parcial da rodada distinta da acumulada da partida', () {
      const r = PontuacaoRodada(melds: 100, canastras: 200, mao: 30, bonus: 100);
      expect(r.total, 370); // 100 + 200 + 100 - 30
      const p = PontuacaoPartida(nos: 500, eles: 400);
      final p2 = p.somarRodada('nos', r);
      expect(p2.nos, 870);
      expect(p2.eles, 400);
    });

    test('C1 Sombra: excecoes versionadas e completas', () {
      expect(excecoesSombra.length, 4);
      expect(excecoesSombra.map((e) => e.id).toList(),
          ['EXC-01', 'EXC-02', 'EXC-03', 'EXC-04']);
      for (final e in excecoesSombra) {
        expect(e.descricao.isNotEmpty, true);
        expect(e.casoEspecifico.isNotEmpty, true);
        expect(e.testeCobertura.isNotEmpty, true);
        expect(e.etapaRemocao.isNotEmpty, true);
      }
    });

    test('C1 Acoes + Replay: contrato cobre monte/lixo/baixar/descarte + round-trip',
        () {
      final acoes = <Acao>[
        const ComprarLixo(),
        const Baixar(
          jogosNovos: [
            ['c1', 'c2', 'c3'],
            ['c4', 'c5', 'c6', 'c7'],
          ],
          extensoes: [Extensao(0, ['c8'])],
          topoLixoConsumido: 'c9',
        ),
        const Descartar('c10'),
        const ComprarMonte(),
      ];
      final r = Replay(
        seed: 42,
        versaoSpec: RuleSpec.versaoCanonica,
        modalidade: Modalidade.fechado,
        acoes: acoes,
      );
      final volta = Replay.fromJson(r.toJson());
      expect(volta.seed, 42);
      expect(volta.versaoSpec, RuleSpec.versaoCanonica);
      expect(volta.modalidade, Modalidade.fechado);
      expect(volta.acoes.length, 4);
      expect(volta.acoes[1], isA<Baixar>());
      final b = volta.acoes[1] as Baixar;
      expect(b.jogosNovos.length, 2);
      expect(b.jogosNovos[1].length, 4);
      expect(b.extensoes.single.indiceJogo, 0);
      expect(b.topoLixoConsumido, 'c9');
      expect(volta.acoes[2], isA<Descartar>());
      expect((volta.acoes[2] as Descartar).carta, 'c10');
    });

    test('C1 Estado: clone profundo isola referencias; normalizar ordena maos',
        () {
      CartaSnapshot cs(String id, String? n, String v) =>
          CartaSnapshot(id, n, v, v == '2' || v == 'JOKER');
      final est = EstadoJogo(
        modalidade: Modalidade.aberto,
        metaPontos: 1500,
        monte: [cs('m1', 'copas', 'K')],
        lixo: [cs('l1', 'ouros', '7')],
        mortos: [
          [cs('x1', 'paus', '3')]
        ],
        maos: [
          [cs('h2', 'copas', 'Q'), cs('h1', 'copas', 'J')]
        ],
        jogosDupla: {
          'nos': [
            [cs('j1', 'copas', '4'), cs('j2', 'copas', '5')]
          ],
          'eles': [],
        },
        rodadasVulneravel: {'nos': 1, 'eles': 0},
        primeiraBaixadaFeita: {'nos': false, 'eles': false},
        vez: 0,
      );
      final clone = est.cloneProfundo();
      clone.maos[0].clear(); // muta o clone
      expect(est.maos[0].length, 2); // original intacto
      expect(clone.monte.first == est.monte.first, true); // igualdade por valor
      final norm = est.normalizar();
      expect(norm.maos[0].first.id, 'h1'); // J antes de Q
      expect(norm.maos[0].last.id, 'h2');
      expect(norm.assinatura().contains('mod=ABERTO'), true);
    });

    test('C1 RulesEngine: fachada existe e ainda nao implementa (andaime)', () {
      final eng = RulesEngine(RuleSpec.canonica(Modalidade.aberto));
      final estVazio = EstadoJogo(
        modalidade: Modalidade.aberto,
        metaPontos: 1500,
        monte: const [],
        lixo: const [],
        mortos: const [],
        maos: const [],
        jogosDupla: const {'nos': [], 'eles': []},
        rodadasVulneravel: const {'nos': 0, 'eles': 0},
        primeiraBaixadaFeita: const {'nos': false, 'eles': false},
        vez: 0,
      );
      expect(() => eng.avaliar(estVazio, const ComprarMonte()),
          throwsUnimplementedError);
    });
  });

  // ===================================================================
  // C2 — MELDS canônicos (validador novo em rules/meld/). Testes de
  // PROPRIEDADE obrigatórios. Aditivos: só exercitam o validador novo,
  // sem tocar no comportamento do motor antigo.
  // ===================================================================
  group('C2 — melds canônicos (propriedades)', () {
    CartaSnapshot csm(String id, String? naipe, String valor) =>
        CartaSnapshot(id, naipe, valor, valor == '2' || valor == 'JOKER');

    List<List<T>> perms<T>(List<T> xs) {
      if (xs.length <= 1) return [List<T>.from(xs)];
      final out = <List<T>>[];
      for (int i = 0; i < xs.length; i++) {
        final rest = [...xs.sublist(0, i), ...xs.sublist(i + 1)];
        for (final p in perms(rest)) {
          out.add([xs[i], ...p]);
        }
      }
      return out;
    }

    final aberto = RuleSpec.canonica(Modalidade.aberto);
    final fechado = RuleSpec.canonica(Modalidade.fechado);
    final stbl = RuleSpec.canonica(Modalidade.stbl);

    test('MELD-PROP-01 mesmo naipe (curinga não altera o naipe canônico)', () {
      // sequência natural do mesmo naipe -> aceita
      expect(
          validarSequencia([
            csm('a', 'copas', '4'),
            csm('b', 'copas', '5'),
            csm('c', 'copas', '6'),
          ], aberto).valido,
          true);
      // uma carta natural de outro naipe -> rejeitada
      expect(
          validarSequencia([
            csm('a', 'copas', '4'),
            csm('b', 'copas', '5'),
            csm('c', 'espadas', '6'),
          ], aberto).valido,
          false);
      // A copas + A ouros na mesma sequência -> rejeitada
      expect(
          validarSequencia([
            csm('a', 'copas', 'A'),
            csm('b', 'ouros', 'A'),
            csm('c', 'copas', '2'),
          ], aberto).valido,
          false);
      // válida com um Joker -> aceita, naipe canônico preservado
      final comJoker = validarSequencia([
        csm('a', 'copas', '5'),
        csm('j', '', 'JOKER'),
        csm('c', 'copas', '7'),
      ], aberto);
      expect(comJoker.valido, true);
      expect(comJoker.naipeCanonico, 'copas');
      expect(comJoker.qtdCuringas, 1);
      // válida com "2" contextual -> aceita conforme a melhor interpretação legal
      final com2 = validarSequencia([
        csm('a', 'copas', 'A'),
        csm('b', 'copas', '2'),
        csm('c', 'copas', '3'),
      ], aberto);
      expect(com2.valido, true);
      expect(com2.qtdCuringas, 0); // "2" do mesmo naipe é a leitura mais limpa
    });

    test('MELD-PROP-02 invariância da ordem de entrada', () {
      // 5-6-[7]-8 (copas) com Joker no lugar do 7
      final base = [
        csm('a', 'copas', '5'),
        csm('b', 'copas', '6'),
        csm('j', '', 'JOKER'),
        csm('d', 'copas', '8'),
      ];
      final ref = validarSequencia(base, aberto);
      expect(ref.valido, true);
      expect(ref.qtdCuringas, 1);
      for (final p in perms(base)) {
        final r = validarSequencia(p, aberto);
        expect(r.valido, ref.valido);
        expect(r.tipo, ref.tipo);
        expect(r.qtdCuringas, ref.qtdCuringas);
        expect(r.posicoesCuringa, ref.posicoesCuringa);
        expect(r.assinatura, ref.assinatura);
        // pontuação é função pura das cartas + estrutura canônica: mesma
        // sequência canônica => mesma pontuação. Comparamos a forma canônica.
        expect(r.ordenado.map((c) => '${c.valor}/${c.naipe}').toList(),
            ref.ordenado.map((c) => '${c.valor}/${c.naipe}').toList());
      }
    });

    test('MELD-AS-01 ases de naipes diferentes', () {
      // A♥,2♥,3♥ -> sequência válida
      final s1 = validarSequencia([
        csm('a', 'copas', 'A'),
        csm('b', 'copas', '2'),
        csm('c', 'copas', '3'),
      ], aberto);
      expect(s1.valido, true);
      expect(s1.tipo, 'sequencia');
      // A♥,2♥,3♥,A♦ -> inválida como sequência (ás de outro naipe)
      expect(
          validarSequencia([
            csm('a', 'copas', 'A'),
            csm('b', 'copas', '2'),
            csm('c', 'copas', '3'),
            csm('d', 'ouros', 'A'),
          ], aberto).valido,
          false);
      // A♥,A♦,A♠ no Fechado -> trinca natural válida
      final tr = validarJogoMesa([
        csm('a', 'copas', 'A'),
        csm('b', 'ouros', 'A'),
        csm('c', 'espadas', 'A'),
      ], fechado);
      expect(tr.valido, true);
      expect(tr.tipo, 'trinca');
      // a MESMA trinca nunca pode ser classificada como sequência
      expect(
          validarSequencia([
            csm('a', 'copas', 'A'),
            csm('b', 'ouros', 'A'),
            csm('c', 'espadas', 'A'),
          ], fechado).valido,
          false);
      // trinca de ases não forma canastra e não libera batida
      expect(tr.canastra, false);
      expect(tr.liberaBatida, false);
    });

    test('MELD-TRIN-01 trinca somente natural', () {
      // três naturais do mesmo valor -> válida no Fechado
      expect(
          validarTrinca([
            csm('a', 'copas', 'K'),
            csm('b', 'ouros', 'K'),
            csm('c', 'espadas', 'K'),
          ], fechado).valido,
          true);
      // três "2" naturais -> trinca de 2 válida
      final t2 = validarTrinca([
        csm('a', 'copas', '2'),
        csm('b', 'ouros', '2'),
        csm('c', 'espadas', '2'),
      ], fechado);
      expect(t2.valido, true);
      expect(t2.tipo, 'trinca');
      expect(t2.qtdCuringas, 0);
      // duas naturais + Joker -> inválida
      expect(
          validarTrinca([
            csm('a', 'copas', 'K'),
            csm('b', 'ouros', 'K'),
            csm('j', '', 'JOKER'),
          ], fechado).valido,
          false);
      // duas naturais + "2" como substituto -> inválida
      expect(
          validarTrinca([
            csm('a', 'copas', 'K'),
            csm('b', 'ouros', 'K'),
            csm('d', 'copas', '2'),
          ], fechado).valido,
          false);
      // trinca proibida no Aberto e no STBL
      final trioK = [
        csm('a', 'copas', 'K'),
        csm('b', 'ouros', 'K'),
        csm('c', 'espadas', 'K'),
      ];
      expect(validarTrinca(trioK, aberto).valido, false);
      expect(validarTrinca(trioK, stbl).valido, false);
      // 7+ cartas continua trinca, sem tarja de canastra e sem bônus
      final t7 = validarTrinca([
        csm('a', 'copas', '9'),
        csm('b', 'ouros', '9'),
        csm('c', 'espadas', '9'),
        csm('d', 'paus', '9'),
        csm('e', 'copas', '9'),
        csm('f', 'ouros', '9'),
        csm('g', 'espadas', '9'),
      ], fechado);
      expect(t7.valido, true);
      expect(t7.tipo, 'trinca');
      expect(t7.canastra, false);
      expect(t7.liberaBatida, false);
    });

    test('MELD-WILD-01 interpretação contextual do curinga', () {
      // "2" do mesmo naipe atua NATURAL (leitura mais limpa)
      final natural2 = validarSequencia([
        csm('a', 'copas', 'A'),
        csm('b', 'copas', '2'),
        csm('c', 'copas', '3'),
      ], aberto);
      expect(natural2.valido, true);
      expect(natural2.qtdCuringas, 0);
      expect(natural2.usos.firstWhere((u) => u.id == 'b').papel, 'natural');
      // "2" de OUTRO naipe só cabe como curinga
      final wild2 = validarSequencia([
        csm('a', 'copas', 'A'),
        csm('b', 'espadas', '2'),
        csm('c', 'copas', '3'),
      ], aberto);
      expect(wild2.valido, true);
      expect(wild2.qtdCuringas, 1);
      expect(wild2.classificacao, 'suja');
      expect(wild2.usos.firstWhere((u) => u.id == 'b').papel, 'curinga');
      // nenhuma carta é natural e curinga ao mesmo tempo
      for (final u in wild2.usos) {
        expect(wild2.usos.where((x) => x.id == u.id).length, 1);
      }
      // Joker sempre curinga, com posição e contagem registradas
      final comJoker = validarSequencia([
        csm('a', 'copas', '5'),
        csm('j', '', 'JOKER'),
        csm('c', 'copas', '7'),
      ], aberto);
      expect(comJoker.usos.firstWhere((u) => u.id == 'j').papel, 'curinga');
      expect(comJoker.qtdCuringas, 1);
    });

    test('MELD-ID-01 conservação dos IDs após ordenar/normalizar', () {
      final entrada = [
        csm('x1', 'copas', '8'),
        csm('x2', 'copas', '6'),
        csm('j', '', 'JOKER'),
        csm('x3', 'copas', '5'),
      ];
      final r = validarSequencia(entrada, aberto);
      expect(r.valido, true);
      final idsIn = entrada.map((c) => c.id).toSet();
      final idsOut = r.ordenado.map((c) => c.id).toList();
      expect(idsOut.toSet(), idsIn); // nenhum some
      expect(idsOut.length, entrada.length); // nenhum duplica
      for (final c in r.ordenado) {
        final orig = entrada.firstWhere((e) => e.id == c.id);
        expect(c.naipe, orig.naipe); // não muda de naipe
        expect(c.valor, orig.valor); // não muda de valor
      }
      // lista exibida (usos) corresponde exatamente à lista validada (ordenado)
      expect(r.usos.map((u) => u.id).toList(),
          r.ordenado.map((c) => c.id).toList());
    });

    test('MELD-500-01 de_500 (A-K) e as_a_as (A-K-A): legalidade e classificação',
        () {
      List<CartaSnapshot> runCopas(List<String> valores) => [
            for (int i = 0; i < valores.length; i++)
              csm('c$i', 'copas', valores[i])
          ];
      const aK = [
        'A', '2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K'
      ];
      // A-K válido -> de_500
      final de500 = validarSequencia(runCopas(aK), aberto);
      expect(de500.valido, true);
      expect(de500.tipo, 'sequencia');
      expect(de500.classificacao, 'de_500');
      expect(de500.qtdCuringas, 0);
      // A-K-A válido -> as_a_as (dois ases MESMO naipe, nas pontas)
      final aKa = [...runCopas(aK), csm('cA2', 'copas', 'A')];
      final asAAs = validarSequencia(aKa, aberto);
      expect(asAAs.valido, true);
      expect(asAAs.tipo, 'sequencia');
      expect(asAAs.classificacao, 'as_a_as');
      expect(asAAs.qtdCuringas, 0);
      // segundo Ás de OUTRO naipe -> inválido
      final segundoAsOutro = [...runCopas(aK), csm('ad', 'ouros', 'A')];
      expect(validarSequencia(segundoAsOutro, aberto).valido, false);
      // dois Reis (rank duplicado) -> inválido
      expect(
          validarSequencia([
            csm('q', 'copas', 'Q'),
            csm('k1', 'copas', 'K'),
            csm('k2', 'copas', 'K'),
          ], aberto).valido,
          false);
      // Ás duplicado que não fecha as pontas -> inválido
      expect(
          validarSequencia([
            csm('a1', 'copas', 'A'),
            csm('a2', 'copas', 'A'),
            csm('c2', 'copas', '2'),
            csm('c3', 'copas', '3'),
          ], aberto).valido,
          false);
      // grupo de ases -> trinca (Fechado), nunca sequência
      final trioAs = [
        csm('a', 'copas', 'A'),
        csm('b', 'ouros', 'A'),
        csm('c', 'espadas', 'A'),
      ];
      expect(validarJogoMesa(trioAs, fechado).tipo, 'trinca');
      expect(validarSequencia(trioAs, fechado).valido, false);
    });
  });

  // ===================================================================
  // C3 — PONTUAÇÃO canônica (rules/pontuacao_canonica.dart). Aditivos: só
  // exercitam o módulo novo; motor antigo continua ativo em runtime.
  // Inclui vetores anti-dupla-contagem entre cartas e bônus de canastra.
  // ===================================================================
  group('C3 — pontuação canônica', () {
    CartaSnapshot csm(String id, String? naipe, String valor) =>
        CartaSnapshot(id, naipe, valor, valor == '2' || valor == 'JOKER');
    final aberto = RuleSpec.canonica(Modalidade.aberto);
    final fechado = RuleSpec.canonica(Modalidade.fechado);
    const aK = [
      'A', '2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K'
    ];
    List<CartaSnapshot> runCopas(List<String> vs) =>
        [for (int i = 0; i < vs.length; i++) csm('c$i', 'copas', vs[i])];

    test('PONT-CANON-01 valor das cartas', () {
      expect(valorCarta(csm('a', 'copas', 'A')), 15);
      expect(valorCarta(csm('j', '', 'JOKER')), 50);
      expect(valorCarta(csm('d', 'copas', '2')), 10);
      for (final v in ['8', '9', '10', 'J', 'Q', 'K']) {
        expect(valorCarta(csm('x', 'copas', v)), 10, reason: v);
      }
      for (final v in ['3', '4', '5', '6', '7']) {
        expect(valorCarta(csm('x', 'copas', v)), 5, reason: v);
      }
    });

    test('PONT-CANON-02 meld curto: só pontos das cartas, sem bônus', () {
      final m = validarSequencia(
          [csm('a', 'copas', '4'), csm('b', 'copas', '5'), csm('c', 'copas', '6')],
          aberto);
      final p = pontosMeld(m);
      expect(p.cartas, 15); // 5+5+5
      expect(p.bonus, 0); // <7 não é canastra
      expect(p.total, 15);
    });

    test('PONT-CANON-03 canastra limpa (7+, sem curinga) = cartas + 200', () {
      final m = validarSequencia(runCopas(['3', '4', '5', '6', '7', '8', '9']),
          aberto);
      expect(m.classificacao, 'limpa');
      final p = pontosMeld(m);
      expect(p.cartas, 45); // 5*5 + 10*2
      expect(p.bonus, 200);
      expect(p.total, 245);
    });

    test('PONT-CANON-04 canastra suja (7+, com curinga) = cartas + 100', () {
      final m = validarSequencia([
        csm('c3', 'copas', '3'),
        csm('c4', 'copas', '4'),
        csm('c5', 'copas', '5'),
        csm('c6', 'copas', '6'),
        csm('c7', 'copas', '7'),
        csm('c8', 'copas', '8'),
        csm('j', '', 'JOKER'),
      ], aberto);
      expect(m.classificacao, 'suja');
      expect(m.qtdCuringas, 1);
      final p = pontosMeld(m);
      expect(p.cartas, 85); // 3-7=25, 8=10, joker=50
      expect(p.bonus, 100);
      expect(p.total, 185);
    });

    test('PONT-CANON-05 de_500 (A-K) = cartas + 500 (só o maior bônus)', () {
      final m = validarSequencia(runCopas(aK), aberto);
      expect(m.classificacao, 'de_500');
      final p = pontosMeld(m);
      expect(p.cartas, 110); // A15 + 2:10 + (3-7)25 + (8-K)60
      expect(p.bonus, 500); // não 200 (limpa) nem 700
      expect(p.total, 610);
    });

    test('PONT-CANON-06 as_a_as (A-K-A) = cartas + 1000 (só o maior bônus)', () {
      final cards = [...runCopas(aK), csm('cA2', 'copas', 'A')];
      final m = validarSequencia(cards, aberto);
      expect(m.classificacao, 'as_a_as');
      final p = pontosMeld(m);
      expect(p.cartas, 125); // 110 + A(15)
      expect(p.bonus, 1000);
      expect(p.total, 1125);
    });

    test('PONT-CANON-07 trinca (mesmo 7+) = só cartas, sem bônus de canastra',
        () {
      const naipes = [
        'copas', 'ouros', 'espadas', 'paus', 'copas', 'ouros', 'espadas'
      ];
      final nines = [for (int i = 0; i < 7; i++) csm('n$i', naipes[i], '9')];
      final m = validarTrinca(nines, fechado);
      expect(m.valido, true);
      expect(m.tipo, 'trinca');
      final p = pontosMeld(m);
      expect(p.cartas, 70); // 7 * 10
      expect(p.bonus, 0); // trinca nunca forma canastra
      expect(p.total, 70);
    });

    test('PONT-CANON-08 penalidade da mão desconta o valor das cartas', () {
      final r = pontuarRodada(
          EntradaRodada(mao: [csm('a', 'copas', 'A'), csm('k', 'copas', 'K')]),
          aberto);
      expect(r.mao, 25); // 15 + 10
      expect(r.total, -25);
    });

    test('PONT-CANON-09 batida soma +100', () {
      final sem = pontuarRodada(const EntradaRodada(bateu: false), aberto);
      final com = pontuarRodada(const EntradaRodada(bateu: true), aberto);
      expect(com.batida, 100);
      expect(com.total - sem.total, 100);
    });

    test('PONT-CANON-10 morto não pego (alguém pegou, sem conversão) = -100',
        () {
      final penal = pontuarRodada(
          const EntradaRodada(mortoPego: false, algumPegouMorto: true), aberto);
      expect(penal.penalidadeMorto, 100);
      expect(penal.total, -100);
      final pego = pontuarRodada(
          const EntradaRodada(mortoPego: true, algumPegouMorto: true), aberto);
      expect(pego.penalidadeMorto, 0);
      final conv = pontuarRodada(
          const EntradaRodada(
              mortoPego: false, algumPegouMorto: true, mortoConvertido: true),
          aberto);
      expect(conv.penalidadeMorto, 0);
      final ninguem = pontuarRodada(
          const EntradaRodada(mortoPego: false, algumPegouMorto: false),
          aberto);
      expect(ninguem.penalidadeMorto, 0);
    });

    test('PONT-CANON-11 parcial da rodada x acumulada da partida', () {
      // canastra limpa 7 (245) + batida (100), mão 0
      final canastra = runCopas(['3', '4', '5', '6', '7', '8', '9']);
      final r = pontuarRodada(
          EntradaRodada(melds: [canastra], bateu: true), aberto);
      expect(r.total, 345); // 45 + 200 + 100
      expect(r.parcial.total, 345);
      var partida = const PontuacaoPartida(nos: 500, eles: 400);
      partida = partida.somarRodada('nos', r.parcial);
      expect(partida.nos, 845);
      expect(partida.eles, 400);
    });

    test('PONT-CANON-12 mínimo de abertura via RuleSpec (+75/+90)', () {
      final v = fechado.vulnerabilidade;
      expect(v.minimoParaDescer(rodadasVulneravel: 0, jaAbriuNaRodada: false), 0);
      expect(
          v.minimoParaDescer(rodadasVulneravel: 1, jaAbriuNaRodada: false), 75);
      expect(
          v.minimoParaDescer(rodadasVulneravel: 2, jaAbriuNaRodada: false), 90);
    });

    test('PONT-CANON-13 fim de partida: meta cruzada e sem empate', () {
      expect(partidaEncerrada(const PontuacaoPartida(nos: 1500, eles: 1400), 1500),
          true);
      // empate exato na meta força rodada extra
      expect(partidaEncerrada(const PontuacaoPartida(nos: 1500, eles: 1500), 1500),
          false);
      expect(partidaEncerrada(const PontuacaoPartida(nos: 1490, eles: 1400), 1500),
          false);
    });

    test('PONT-DOUBLE-01 sem dupla contagem entre cartas e bônus de canastra',
        () {
      final cards = runCopas(['3', '4', '5', '6', '7', '8', '9']);
      final m = validarSequencia(cards, aberto);
      final p = pontosMeld(m);
      final somaManual = cards.fold<int>(0, (s, c) => s + valorCarta(c));
      expect(p.cartas, somaManual); // cada carta contada UMA vez
      expect(p.bonus, 200); // bônus fixo, NÃO inclui valor de carta
      expect(p.total, somaManual + 200); // exatamente cartas + bônus
      // e NÃO é cartas contadas duas vezes nem bônus dobrado
      expect(p.total == 2 * somaManual + 200, false);
      expect(p.total == somaManual + 400, false);
    });
  });

  // ===================================================================
  // C4 — JOGADA ATÔMICA / abertura múltipla (rules/abertura/abertura.dart).
  // Aditivos: só exercitam o módulo novo sobre EstadoJogo imutável; motor
  // antigo continua ativo em runtime.
  // ===================================================================
  group('C4 — jogada atômica / abertura múltipla', () {
    CartaSnapshot csm(String id, String? naipe, String valor) =>
        CartaSnapshot(id, naipe, valor, valor == '2' || valor == 'JOKER');
    final aberto = RuleSpec.canonica(Modalidade.aberto);

    EstadoJogo estadoCom({
      required List<CartaSnapshot> mao0,
      List<List<CartaSnapshot>> melsNos = const [],
      int rvNos = 0,
      bool abriuNos = false,
      List<CartaSnapshot> monte = const [],
      List<CartaSnapshot> lixo = const [],
    }) =>
        EstadoJogo(
          modalidade: Modalidade.aberto,
          metaPontos: 1500,
          monte: [...monte],
          lixo: [...lixo],
          mortos: const [],
          maos: [
            [...mao0],
            <CartaSnapshot>[],
            <CartaSnapshot>[],
            <CartaSnapshot>[],
          ],
          jogosDupla: {
            'nos': [for (final m in melsNos) [...m]],
            'eles': <List<CartaSnapshot>>[],
          },
          rodadasVulneravel: {'nos': rvNos, 'eles': 0},
          primeiraBaixadaFeita: {'nos': abriuNos, 'eles': false},
          vez: 0,
        );

    Set<String> idsDoEstado(EstadoJogo e) => {
          for (final m in e.maos) ...m.map((c) => c.id),
          ...e.monte.map((c) => c.id),
          ...e.lixo.map((c) => c.id),
          for (final mm in e.mortos) ...mm.map((c) => c.id),
          for (final g in e.jogosDupla['nos']!) ...g.map((c) => c.id),
          for (final g in e.jogosDupla['eles']!) ...g.map((c) => c.id),
        };

    test('ATOM-01 dois jogos de naipes diferentes somando 80 → aceita', () {
      final mao = [
        csm('a', 'copas', '10'), csm('b', 'copas', 'J'),
        csm('c', 'copas', 'Q'), csm('d', 'copas', 'K'), // 40
        csm('e', 'ouros', '10'), csm('f', 'ouros', 'J'),
        csm('g', 'ouros', 'Q'), csm('h', 'ouros', 'K'), // 40
      ];
      final est = estadoCom(mao0: mao, rvNos: 1); // vulnerável, min 75
      final r = avaliarBaixar(
          est,
          0,
          const Baixar(jogosNovos: [
            ['a', 'b', 'c', 'd'],
            ['e', 'f', 'g', 'h'],
          ]),
          aberto);
      expect(r.valido, true);
      expect(r.pontosAbertura, 80);
      expect(r.minimoExigido, 75);
      expect(r.sujeitoAoMinimo, true);
      expect(r.atingiuMinimo, true);
      expect(r.proximoEstado!.jogosDupla['nos']!.length, 2);
    });

    test('ATOM-02 um jogo válido + um inválido → rejeita tudo', () {
      final mao = [
        csm('a', 'copas', '10'), csm('b', 'copas', 'J'), csm('c', 'copas', 'Q'),
        csm('e', 'ouros', '4'), csm('f', 'ouros', '7'), csm('g', 'ouros', '9'),
      ];
      final est = estadoCom(mao0: mao, rvNos: 0);
      final r = avaliarBaixar(
          est,
          0,
          const Baixar(jogosNovos: [
            ['a', 'b', 'c'],
            ['e', 'f', 'g'],
          ]),
          aberto);
      expect(r.valido, false);
      expect(r.proximoEstado, null);
      expect(est.jogosDupla['nos']!.isEmpty, true); // mesa intacta
      expect(est.maos[0].length, 6); // mão intacta
    });

    test('ATOM-03 total abaixo do mínimo → rejeita tudo', () {
      final mao = [
        csm('a', 'copas', '4'), csm('b', 'copas', '5'), csm('c', 'copas', '6'),
        csm('e', 'ouros', '4'), csm('f', 'ouros', '5'), csm('g', 'ouros', '6'),
      ];
      final est = estadoCom(mao0: mao, rvNos: 1); // min 75
      final r = avaliarBaixar(
          est,
          0,
          const Baixar(jogosNovos: [
            ['a', 'b', 'c'],
            ['e', 'f', 'g'],
          ]),
          aberto);
      expect(r.valido, false);
      expect(r.pontosAbertura, 30); // 15 + 15
      expect(r.minimoExigido, 75);
      expect(r.proximoEstado, null);
    });

    test('ATOM-04 abertura com Joker contado corretamente (50)', () {
      final mao = [
        csm('a', 'copas', '10'), csm('b', 'copas', 'J'),
        csm('c', 'copas', 'Q'), csm('d', 'copas', 'K'), // 40
        csm('e', 'ouros', '5'), csm('f', 'ouros', '6'),
        csm('j', '', 'JOKER'), csm('h', 'ouros', '8'), // 5+5+50+10 = 70
      ];
      final est = estadoCom(mao0: mao, rvNos: 1);
      final r = avaliarBaixar(
          est,
          0,
          const Baixar(jogosNovos: [
            ['a', 'b', 'c', 'd'],
            ['e', 'f', 'j', 'h'],
          ]),
          aberto);
      expect(r.valido, true);
      expect(r.pontosAbertura, 110); // Joker conta 50
    });

    test('ATOM-05 jogo único continua funcionando', () {
      final mao = [
        csm('a', 'copas', '10'), csm('b', 'copas', 'J'),
        csm('c', 'copas', 'Q'), csm('d', 'copas', 'K'),
      ];
      final est = estadoCom(mao0: mao, rvNos: 0);
      final r = avaliarBaixar(
          est, 0, const Baixar(jogosNovos: [['a', 'b', 'c', 'd']]), aberto);
      expect(r.valido, true);
      expect(r.proximoEstado!.jogosDupla['nos']!.length, 1);
      expect(r.proximoEstado!.maos[0].isEmpty, true);
    });

    test('ATOM-06 mesma carta usada em dois jogos → rejeita', () {
      final mao = [
        csm('a', 'copas', '10'), csm('b', 'copas', 'J'), csm('c', 'copas', 'Q'),
        csm('d', 'copas', 'K'), csm('e', 'ouros', '9'),
      ];
      final r = avaliarBaixar(
          estadoCom(mao0: mao),
          0,
          const Baixar(jogosNovos: [
            ['a', 'b', 'c'],
            ['a', 'd', 'e'], // 'a' repetido
          ]),
          aberto);
      expect(r.valido, false);
      expect(r.proximoEstado, null);
    });

    test('ATOM-07 carta inexistente ou já baixada → rejeita', () {
      final mao = [
        csm('a', 'copas', '10'), csm('b', 'copas', 'J'), csm('c', 'copas', 'Q'),
      ];
      final r = avaliarBaixar(estadoCom(mao0: mao), 0,
          const Baixar(jogosNovos: [['a', 'b', 'zzz']]), aberto);
      expect(r.valido, false);
      expect(r.proximoEstado, null);
    });

    test('ATOM-08 várias extensões válidas → aceita', () {
      final mesa1 = [
        csm('m1', 'copas', '4'), csm('m2', 'copas', '5'), csm('m3', 'copas', '6')
      ];
      final mesa2 = [
        csm('n1', 'ouros', '9'), csm('n2', 'ouros', '10'), csm('n3', 'ouros', 'J')
      ];
      final mao = [csm('a', 'copas', '7'), csm('b', 'ouros', 'Q')];
      final est =
          estadoCom(mao0: mao, melsNos: [mesa1, mesa2], abriuNos: true);
      final r = avaliarBaixar(
          est,
          0,
          const Baixar(extensoes: [
            Extensao(0, ['a']),
            Extensao(1, ['b']),
          ]),
          aberto);
      expect(r.valido, true);
      expect(r.proximoEstado!.jogosDupla['nos']![0].length, 4); // 4-5-6-7
      expect(r.proximoEstado!.jogosDupla['nos']![1].length, 4); // 9-10-J-Q
      expect(r.proximoEstado!.maos[0].isEmpty, true);
    });

    test('ATOM-09 uma extensão inválida → rejeita tudo', () {
      final mesa1 = [
        csm('m1', 'copas', '4'), csm('m2', 'copas', '5'), csm('m3', 'copas', '6')
      ];
      final mesa2 = [
        csm('n1', 'ouros', '9'), csm('n2', 'ouros', '10'), csm('n3', 'ouros', 'J')
      ];
      final mao = [csm('a', 'copas', '7'), csm('b', 'ouros', 'K')]; // K quebra 9-10-J
      final est =
          estadoCom(mao0: mao, melsNos: [mesa1, mesa2], abriuNos: true);
      final r = avaliarBaixar(
          est,
          0,
          const Baixar(extensoes: [
            Extensao(0, ['a']),
            Extensao(1, ['b']),
          ]),
          aberto);
      expect(r.valido, false);
      expect(r.proximoEstado, null);
      expect(est.jogosDupla['nos']![0].length, 3); // mesa intacta
      expect(est.jogosDupla['nos']![1].length, 3);
      expect(est.maos[0].length, 2); // mão intacta
    });

    test('ATOM-10 falha não altera mão, mesa, lixo, pontuação ou turno', () {
      final mao = [
        csm('a', 'copas', '4'), csm('b', 'copas', '5'), csm('c', 'copas', '6'),
      ];
      final est = estadoCom(
          mao0: mao, rvNos: 1, lixo: [csm('l', 'ouros', '7')]);
      final antes = est.assinatura();
      final vezAntes = est.vez;
      final r = avaliarBaixar(
          est, 0, const Baixar(jogosNovos: [['a', 'b', 'c']]), aberto); // 15 < 75
      expect(r.valido, false);
      expect(r.proximoEstado, null);
      expect(est.assinatura(), antes); // estado idêntico
      expect(est.vez, vezAntes); // turno intacto
      expect(est.maos[0].length, 3); // mão intacta
      expect(est.lixo.length, 1); // lixo intacto
      expect(est.jogosDupla['nos']!.isEmpty, true); // mesa intacta
    });

    test('ATOM-11 sucesso conserva integralmente todos os IDs', () {
      final mao = [
        csm('a', 'copas', '10'), csm('b', 'copas', 'J'),
        csm('c', 'copas', 'Q'), csm('d', 'copas', 'K'),
        csm('e', 'ouros', '10'), csm('f', 'ouros', 'J'),
        csm('g', 'ouros', 'Q'), csm('h', 'ouros', 'K'),
        csm('x', 'paus', '2'), // carta extra que não entra
      ];
      final est = estadoCom(
          mao0: mao,
          rvNos: 1,
          monte: [csm('mo', 'espadas', '3')],
          lixo: [csm('li', 'espadas', '4')]);
      final idsAntes = idsDoEstado(est);
      final r = avaliarBaixar(
          est,
          0,
          const Baixar(jogosNovos: [
            ['a', 'b', 'c', 'd'],
            ['e', 'f', 'g', 'h'],
          ]),
          aberto);
      expect(r.valido, true);
      final prox = r.proximoEstado!;
      final idsDepois = idsDoEstado(prox);
      expect(idsDepois, idsAntes); // nenhum some, nenhum surge
      expect(idsDepois.length, idsAntes.length); // sem duplicação
      expect(prox.maos[0].map((c) => c.id).toSet(), {'x'}); // só a extra sobra
      // e o estado original continua intacto
      expect(idsDoEstado(est), idsAntes);
      expect(est.maos[0].length, 9);
    });

    test('ATOM-12 duas extensões no MESMO jogo, válidas isoladas mas ilegais juntas → rejeita',
        () {
      final mesa1 = [
        csm('m1', 'copas', '5'), csm('m2', 'copas', '6'), csm('m3', 'copas', '7')
      ];
      // dois 8 de copas (2 cópias existem): cada um estende 5-6-7 → 5-6-7-8
      // (válido isolado), mas juntos formam 5-6-7-8-8 (rank duplicado) → ilegal.
      final mao = [csm('o1', 'copas', '8'), csm('o2', 'copas', '8')];
      final est = estadoCom(mao0: mao, melsNos: [mesa1], abriuNos: true);
      final r = avaliarBaixar(
          est,
          0,
          const Baixar(extensoes: [
            Extensao(0, ['o1']),
            Extensao(0, ['o2']),
          ]),
          aberto);
      expect(r.valido, false); // agrupado: [5,6,7,8,8] é inválido
      expect(r.proximoEstado, null);
      expect(est.jogosDupla['nos']![0].length, 3); // mesa intacta
    });

    test('ATOM-13 duas extensões no MESMO jogo, válidas só em conjunto → aceita (agrupadas)',
        () {
      final mesa1 = [
        csm('m1', 'copas', '5'), csm('m2', 'copas', '6'), csm('m3', 'copas', '7')
      ];
      // 9 sozinho deixaria lacuna (5-6-7-_-9, inválido isolado); com o 8 juntos
      // formam 5-6-7-8-9. A validação agrupada precisa aceitar.
      final mao = [csm('c9', 'copas', '9'), csm('c8', 'copas', '8')];
      final est = estadoCom(mao0: mao, melsNos: [mesa1], abriuNos: true);
      final r = avaliarBaixar(
          est,
          0,
          const Baixar(extensoes: [
            Extensao(0, ['c9']),
            Extensao(0, ['c8']),
          ]),
          aberto);
      expect(r.valido, true);
      expect(r.proximoEstado!.jogosDupla['nos']![0].length, 5); // 5-6-7-8-9
    });

    test('ATOM-14 consumo do topo do lixo (topoLixoConsumido) → rejeitado nesta etapa',
        () {
      final mao = [
        csm('a', 'copas', '10'), csm('b', 'copas', 'J'),
        csm('c', 'copas', 'Q'), csm('d', 'copas', 'K'),
      ];
      final est = estadoCom(mao0: mao);
      final r = avaliarBaixar(
          est,
          0,
          const Baixar(
            jogosNovos: [['a', 'b', 'c', 'd']],
            topoLixoConsumido: 'x',
          ),
          aberto);
      expect(r.valido, false);
      expect(r.proximoEstado, null);
      expect(est.jogosDupla['nos']!.isEmpty, true); // nada aplicado
    });

    test('ATOM-15 extensão isolada NÃO marca primeiraBaixadaFeita', () {
      final mesa1 = [
        csm('m1', 'copas', '5'), csm('m2', 'copas', '6'), csm('m3', 'copas', '7')
      ];
      final mao = [csm('c8', 'copas', '8')];
      // jogo na mesa com a flag ainda false: a extensão não pode marcá-la.
      final est = estadoCom(mao0: mao, melsNos: [mesa1], abriuNos: false);
      final r = avaliarBaixar(
          est, 0, const Baixar(extensoes: [Extensao(0, ['c8'])]), aberto);
      expect(r.valido, true);
      expect(r.proximoEstado!.primeiraBaixadaFeita['nos'], false);
      expect(r.sujeitoAoMinimo, false); // sem abertura sujeita a mínimo
      expect(r.atingiuMinimo, true); // vacuamente satisfeito
    });

    test('ATOM-16 abertura (jogo novo) marca primeiraBaixadaFeita', () {
      final mao = [
        csm('a', 'copas', '10'), csm('b', 'copas', 'J'),
        csm('c', 'copas', 'Q'), csm('d', 'copas', 'K'),
      ];
      final est = estadoCom(mao0: mao, rvNos: 0, abriuNos: false);
      final r = avaliarBaixar(
          est, 0, const Baixar(jogosNovos: [['a', 'b', 'c', 'd']]), aberto);
      expect(r.valido, true);
      expect(r.proximoEstado!.primeiraBaixadaFeita['nos'], true);
      expect(r.sujeitoAoMinimo, false); // não vulnerável (rv=0) → sem mínimo
      expect(r.atingiuMinimo, true);
    });
  });

  // ===================================================================
  // C5 — COMPRA DO LIXO (Fechado/STBL) desacoplada do mínimo, via a ação
  // canônica avaliarComprarLixo. A autorização vê SÓ mão + topo visível;
  // cartas enterradas do lixo só entram na mão DEPOIS de aprovada a compra.
  // Aditivos: motor antigo continua ativo em runtime.
  // ===================================================================
  group('C5 — compra do lixo (Fechado/STBL) desacoplada do mínimo', () {
    CartaSnapshot csm(String id, String? naipe, String valor) =>
        CartaSnapshot(id, naipe, valor, valor == '2' || valor == 'JOKER');
    final fechado = RuleSpec.canonica(Modalidade.fechado);
    final stbl = RuleSpec.canonica(Modalidade.stbl);
    final aberto = RuleSpec.canonica(Modalidade.aberto);

    EstadoJogo estadoLixo({
      required List<CartaSnapshot> mao0,
      required List<CartaSnapshot> lixo,
      List<List<CartaSnapshot>> melsNos = const [],
      int rvNos = 0,
      bool abriuNos = false,
      Modalidade modalidade = Modalidade.fechado,
    }) =>
        EstadoJogo(
          modalidade: modalidade,
          metaPontos: 1500,
          monte: const [],
          lixo: [...lixo],
          mortos: const [],
          maos: [
            [...mao0],
            <CartaSnapshot>[],
            <CartaSnapshot>[],
            <CartaSnapshot>[],
          ],
          jogosDupla: {
            'nos': [for (final m in melsNos) [...m]],
            'eles': <List<CartaSnapshot>>[],
          },
          rodadasVulneravel: {'nos': rvNos, 'eles': 0},
          primeiraBaixadaFeita: {'nos': abriuNos, 'eles': false},
          vez: 0,
        );

    Set<String> idsDoEstado(EstadoJogo e) => {
          for (final m in e.maos) ...m.map((c) => c.id),
          ...e.monte.map((c) => c.id),
          ...e.lixo.map((c) => c.id),
          for (final mm in e.mortos) ...mm.map((c) => c.id),
          for (final g in e.jogosDupla['nos']!) ...g.map((c) => c.id),
          for (final g in e.jogosDupla['eles']!) ...g.map((c) => c.id),
        };

    List<CartaSnapshot> doisReisComuns() => [
          csm('c10', 'paus', '10'), csm('cj', 'paus', 'J'),
          csm('cq', 'paus', 'Q'), csm('ck', 'paus', 'K'),
          csm('d10', 'ouros', '10'), csm('dj', 'ouros', 'J'),
          csm('dq', 'ouros', 'Q'), csm('dk', 'ouros', 'K'),
        ];

    test('LIXO-01 topo forma jogo válido + outros completam +75 → aceita', () {
      final mao = [
        csm('h5', 'copas', '5'), csm('h7', 'copas', '7'), ...doisReisComuns()
      ];
      final est =
          estadoLixo(mao0: mao, lixo: [csm('t6', 'copas', '6')], rvNos: 1);
      final r = avaliarComprarLixo(est, 0, fechado,
          topoDeclarado: 't6',
          jogosNovos: const [
            ['h5', 't6', 'h7'],
            ['c10', 'cj', 'cq', 'ck'],
            ['d10', 'dj', 'dq', 'dk'],
          ]);
      expect(r.valido, true);
      expect(r.pontosAbertura, 95);
      expect(r.atingiuMinimo, true);
      expect(r.proximoEstado!.lixo.isEmpty, true);
    });

    test('LIXO-02 topo sem uso em nenhum jogo → rejeita tudo', () {
      final est =
          estadoLixo(mao0: doisReisComuns(), lixo: [csm('t6', 'copas', '6')]);
      final r = avaliarComprarLixo(est, 0, fechado,
          topoDeclarado: 't6', jogosNovos: const [['c10', 'cj', 'cq', 'ck']]);
      expect(r.valido, false);
      expect(r.proximoEstado, null);
      expect(est.lixo.length, 1);
    });

    test('LIXO-03 topo usado com Joker em jogo válido → aceita (STBL)', () {
      final mao = [
        csm('h5', 'copas', '5'), csm('jk', '', 'JOKER'), csm('h8', 'copas', '8')
      ];
      final est = estadoLixo(
          mao0: mao,
          lixo: [csm('t6', 'copas', '6')],
          modalidade: Modalidade.stbl);
      final r = avaliarComprarLixo(est, 0, stbl,
          topoDeclarado: 't6', jogosNovos: const [['h5', 't6', 'jk', 'h8']]);
      expect(r.valido, true);
      expect(r.proximoEstado!.lixo.isEmpty, true);
    });

    test('LIXO-04 jogo do topo < 75 sozinho, conjunto ≥ 75 → aceita (desacoplado)',
        () {
      final mao = [
        csm('h3', 'copas', '3'), csm('h5', 'copas', '5'), ...doisReisComuns()
      ];
      final est =
          estadoLixo(mao0: mao, lixo: [csm('t4', 'copas', '4')], rvNos: 1);
      final r = avaliarComprarLixo(est, 0, fechado,
          topoDeclarado: 't4',
          jogosNovos: const [
            ['h3', 't4', 'h5'],
            ['c10', 'cj', 'cq', 'ck'],
            ['d10', 'dj', 'dq', 'dk'],
          ]);
      expect(r.valido, true);
      expect(r.pontosAbertura, 95);
      expect(r.minimoExigido, 75);
    });

    test('LIXO-05 total da abertura abaixo do mínimo → rejeita', () {
      final mao = [
        csm('h5', 'copas', '5'), csm('h7', 'copas', '7'),
        csm('c3', 'paus', '3'), csm('c4', 'paus', '4'), csm('c5', 'paus', '5'),
      ];
      final est =
          estadoLixo(mao0: mao, lixo: [csm('t6', 'copas', '6')], rvNos: 1);
      final r = avaliarComprarLixo(est, 0, fechado,
          topoDeclarado: 't6',
          jogosNovos: const [
            ['h5', 't6', 'h7'],
            ['c3', 'c4', 'c5'],
          ]);
      expect(r.valido, false);
      expect(r.pontosAbertura, 30);
      expect(r.proximoEstado, null);
      expect(est.lixo.length, 1);
    });

    test('LIXO-06 topo estende jogo existente → aceita', () {
      final mesa = [
        csm('m5', 'copas', '5'), csm('m6', 'copas', '6'), csm('m7', 'copas', '7')
      ];
      final est = estadoLixo(
          mao0: const [],
          lixo: [csm('t8', 'copas', '8')],
          melsNos: [mesa],
          abriuNos: true);
      final r = avaliarComprarLixo(est, 0, fechado,
          topoDeclarado: 't8', extensoes: const [Extensao(0, ['t8'])]);
      expect(r.valido, true);
      expect(r.proximoEstado!.jogosDupla['nos']![0].length, 4);
      expect(r.proximoEstado!.lixo.isEmpty, true);
    });

    test('LIXO-07 topo declarado não é o topo real → rejeita', () {
      final mao = [csm('h5', 'copas', '5'), csm('h7', 'copas', '7')];
      final est = estadoLixo(
          mao0: mao,
          lixo: [csm('b3', 'copas', '3'), csm('t6', 'copas', '6')]);
      final r = avaliarComprarLixo(est, 0, fechado,
          topoDeclarado: 'b3', jogosNovos: const [['h5', 't6', 'h7']]);
      expect(r.valido, false);
      expect(r.proximoEstado, null);
    });

    test('LIXO-08 topo declarado ausente de todos os melds/extensões → rejeita',
        () {
      final mesa = [
        csm('m5', 'copas', '5'), csm('m6', 'copas', '6'), csm('m7', 'copas', '7')
      ];
      final est = estadoLixo(
          mao0: [csm('h8', 'copas', '8')],
          lixo: [csm('t9', 'ouros', '9')],
          melsNos: [mesa],
          abriuNos: true);
      final r = avaliarComprarLixo(est, 0, fechado,
          topoDeclarado: 't9', extensoes: const [Extensao(0, ['h8'])]);
      expect(r.valido, false);
      expect(r.proximoEstado, null);
    });

    test('LIXO-09 topo usado em dois jogos → rejeita', () {
      final mao = [
        csm('h5', 'copas', '5'), csm('h7', 'copas', '7'),
        csm('x4', 'ouros', '4'), csm('x8', 'ouros', '8'),
      ];
      final est = estadoLixo(mao0: mao, lixo: [csm('t6', 'copas', '6')]);
      final r = avaliarComprarLixo(est, 0, fechado,
          topoDeclarado: 't6',
          jogosNovos: const [
            ['h5', 't6', 'h7'],
            ['x4', 't6', 'x8'],
          ]);
      expect(r.valido, false);
      expect(r.proximoEstado, null);
    });

    test('LIXO-10 falha preserva integralmente o estado', () {
      final mao = [
        csm('h5', 'copas', '5'), csm('h7', 'copas', '7'),
        csm('c3', 'paus', '3'), csm('c4', 'paus', '4'), csm('c5', 'paus', '5'),
      ];
      final est =
          estadoLixo(mao0: mao, lixo: [csm('t6', 'copas', '6')], rvNos: 1);
      final antes = est.assinatura();
      final vezAntes = est.vez;
      final r = avaliarComprarLixo(est, 0, fechado,
          topoDeclarado: 't6',
          jogosNovos: const [
            ['h5', 't6', 'h7'],
            ['c3', 'c4', 'c5'],
          ]);
      expect(r.valido, false);
      expect(r.proximoEstado, null);
      expect(est.assinatura(), antes);
      expect(est.vez, vezAntes);
      expect(est.lixo.length, 1);
      expect(est.maos[0].length, 5);
      expect(est.jogosDupla['nos']!.isEmpty, true);
    });

    test('LIXO-11 sucesso conserva todos os IDs (lixo → mão/mesa)', () {
      final mao = [
        csm('h5', 'copas', '5'), csm('h7', 'copas', '7'), ...doisReisComuns()
      ];
      final est = estadoLixo(
          mao0: mao,
          lixo: [csm('bx', 'espadas', '2'), csm('t6', 'copas', '6')],
          rvNos: 1);
      final idsAntes = idsDoEstado(est);
      final r = avaliarComprarLixo(est, 0, fechado,
          topoDeclarado: 't6',
          jogosNovos: const [
            ['h5', 't6', 'h7'],
            ['c10', 'cj', 'cq', 'ck'],
            ['d10', 'dj', 'dq', 'dk'],
          ]);
      expect(r.valido, true);
      final prox = r.proximoEstado!;
      expect(idsDoEstado(prox), idsAntes);
      expect(prox.lixo.isEmpty, true);
      expect(prox.maos[0].map((c) => c.id).toSet(), {'bx'});
      expect(idsDoEstado(est), idsAntes);
    });

    test('LIXO-12 Aberto não herda a exigência do topo do Fechado/STBL', () {
      final estA = estadoLixo(
          mao0: doisReisComuns(),
          lixo: [csm('t6', 'copas', '6')],
          modalidade: Modalidade.aberto);
      expect(
          avaliarComprarLixo(estA, 0, aberto,
              topoDeclarado: 't6',
              jogosNovos: const [['c10', 'cj', 'cq', 'ck']]).valido,
          true);
      final estF = estadoLixo(
          mao0: doisReisComuns(),
          lixo: [csm('t6', 'copas', '6')],
          modalidade: Modalidade.fechado);
      expect(
          avaliarComprarLixo(estF, 0, fechado,
              topoDeclarado: 't6',
              jogosNovos: const [['c10', 'cj', 'cq', 'ck']]).valido,
          false);
    });

    // --- correção do vazamento de informação oculta ---

    test('LIXO-13 carta escondida abaixo do topo não justifica a compra (Fechado)',
        () {
      // topo t8; a mão tem 6; tenta usar um 7 ENTERRADO para formar 6-7-8.
      final est = estadoLixo(
          mao0: [csm('h6', 'copas', '6')],
          lixo: [csm('bh7', 'copas', '7'), csm('t8', 'copas', '8')]);
      final r = avaliarComprarLixo(est, 0, fechado,
          topoDeclarado: 't8', jogosNovos: const [['h6', 'bh7', 't8']]);
      expect(r.valido, false); // bh7 está oculto → indisponível
      expect(r.proximoEstado, null);
      expect(est.lixo.length, 2); // lixo intacto
    });

    test('LIXO-14 cartas escondidas não completam +75/+90 antes da autorização',
        () {
      // topo t6 forma 5-6-7 (15); tenta completar 75 com 4 cartas ENTERRADAS.
      final est = estadoLixo(
          mao0: [csm('h5', 'copas', '5'), csm('h7', 'copas', '7')],
          lixo: [
            csm('b10', 'paus', '10'), csm('bj', 'paus', 'J'),
            csm('bq', 'paus', 'Q'), csm('bk', 'paus', 'K'),
            csm('t6', 'copas', '6'),
          ],
          rvNos: 1);
      final r = avaliarComprarLixo(est, 0, fechado,
          topoDeclarado: 't6',
          jogosNovos: const [
            ['h5', 't6', 'h7'],
            ['b10', 'bj', 'bq', 'bk'], // enterradas → indisponíveis
          ]);
      expect(r.valido, false);
      expect(r.proximoEstado, null);
    });

    test('LIXO-15 compra válida: topo vai ao jogo e demais cartas do lixo à mão',
        () {
      final est = estadoLixo(
          mao0: [csm('h5', 'copas', '5'), csm('h7', 'copas', '7')],
          lixo: [csm('b2', 'espadas', '2'), csm('t6', 'copas', '6')]);
      final r = avaliarComprarLixo(est, 0, fechado,
          topoDeclarado: 't6', jogosNovos: const [['h5', 't6', 'h7']]);
      expect(r.valido, true);
      final prox = r.proximoEstado!;
      expect(prox.jogosDupla['nos']![0].map((c) => c.id).contains('t6'), true);
      expect(prox.maos[0].map((c) => c.id).contains('b2'), true);
      expect(prox.lixo.isEmpty, true);
    });

    test('LIXO-16 ação maliciosa usando ID enterrado num meld → rejeita', () {
      // topo declarado correto (t6), mas um meld referencia um ID ENTERRADO (b3).
      final est = estadoLixo(
          mao0: [csm('h5', 'copas', '5'), csm('h7', 'copas', '7')],
          lixo: [csm('b3', 'ouros', '3'), csm('t6', 'copas', '6')]);
      final r = avaliarComprarLixo(est, 0, fechado,
          topoDeclarado: 't6', jogosNovos: const [['h5', 'b3', 'h7']]);
      expect(r.valido, false);
      expect(r.proximoEstado, null);
      expect(est.lixo.length, 2); // nada revelado/movido
    });

    test('LIXO-17 topo + mão completam o mínimo → aceita, ignorando o oculto', () {
      final mao = [
        csm('h5', 'copas', '5'), csm('h7', 'copas', '7'), ...doisReisComuns()
      ];
      final est = estadoLixo(
          mao0: mao,
          lixo: [csm('b2', 'espadas', '2'), csm('t6', 'copas', '6')],
          rvNos: 1);
      final r = avaliarComprarLixo(est, 0, fechado,
          topoDeclarado: 't6',
          jogosNovos: const [
            ['h5', 't6', 'h7'],
            ['c10', 'cj', 'cq', 'ck'],
            ['d10', 'dj', 'dq', 'dk'],
          ]);
      expect(r.valido, true);
      expect(r.pontosAbertura, 95);
      expect(r.proximoEstado!.maos[0].map((c) => c.id).contains('b2'), true);
    });

    test('LIXO-18 Aberto: compra do lixo sem baixar → aceita e mantém o turno',
        () {
      final est = estadoLixo(
          mao0: [csm('hx', 'ouros', '3')],
          lixo: [csm('b2', 'espadas', '2'), csm('t6', 'copas', '6')],
          modalidade: Modalidade.aberto);
      final vezAntes = est.vez;
      final r = avaliarComprarLixo(est, 0, aberto); // sem baixar
      expect(r.valido, true);
      final prox = r.proximoEstado!;
      expect(prox.lixo.isEmpty, true);
      expect(prox.maos[0].map((c) => c.id).toSet(), {'hx', 'b2', 't6'});
      expect(prox.vez, vezAntes); // turno mantido (a compra não descarta)
    });

    test('LIXO-19 falha na autorização não revela, move nem usa cartas ocultas',
        () {
      final est = estadoLixo(
          mao0: doisReisComuns(),
          lixo: [csm('b2', 'espadas', '2'), csm('t6', 'copas', '6')]);
      final antes = est.assinatura();
      final r = avaliarComprarLixo(est, 0, fechado,
          topoDeclarado: 't6', jogosNovos: const [['c10', 'cj', 'cq', 'ck']]);
      expect(r.valido, false);
      expect(r.proximoEstado, null);
      expect(est.assinatura(), antes);
      expect(est.lixo.map((c) => c.id).toList(), ['b2', 't6']);
      expect(est.maos[0].length, 8);
    });
  });

  // ===================================================================
  // C6 — MORTO e BATIDA (rules/morto/morto.dart). Aditivos: só exercitam o
  // módulo novo sobre EstadoJogo imutável; motor antigo continua ativo.
  // ===================================================================
  group('C6 — morto e batida', () {
    CartaSnapshot csm(String id, String? naipe, String valor) =>
        CartaSnapshot(id, naipe, valor, valor == '2' || valor == 'JOKER');
    final fechado = RuleSpec.canonica(Modalidade.fechado);
    final aberto = RuleSpec.canonica(Modalidade.aberto);

    List<CartaSnapshot> seqCartas(String naipe, List<String> vs, String pre) =>
        [for (int i = 0; i < vs.length; i++) csm('$pre$i', naipe, vs[i])];
    List<CartaSnapshot> limpa7() =>
        seqCartas('copas', ['3', '4', '5', '6', '7', '8', '9'], 'L');
    List<CartaSnapshot> suja7() => [
          csm('S0', 'copas', '3'), csm('S1', 'copas', '4'),
          csm('S2', 'copas', '5'), csm('S3', 'copas', '6'),
          csm('S4', 'copas', '7'), csm('S5', 'copas', '8'),
          csm('SJ', '', 'JOKER'),
        ];
    List<CartaSnapshot> trinca7() => [
          csm('T0', 'copas', '9'), csm('T1', 'ouros', '9'),
          csm('T2', 'espadas', '9'), csm('T3', 'paus', '9'),
          csm('T4', 'copas', '9'), csm('T5', 'ouros', '9'),
          csm('T6', 'espadas', '9'),
        ];
    List<CartaSnapshot> morto11(String pre) =>
        [for (int i = 0; i < 11; i++) csm('$pre$i', 'copas', '5')];

    EstadoJogo estadoMorto({
      List<CartaSnapshot> mao0 = const [],
      List<List<CartaSnapshot>> mortos = const [],
      List<List<CartaSnapshot>> melsNos = const [],
      Map<String, bool> mortoPego = const {'nos': false, 'eles': false},
      Modalidade modalidade = Modalidade.fechado,
      int vez = 0,
    }) =>
        EstadoJogo(
          modalidade: modalidade,
          metaPontos: 1500,
          monte: const [],
          lixo: const [],
          mortos: [for (final m in mortos) [...m]],
          maos: [
            [...mao0],
            <CartaSnapshot>[],
            <CartaSnapshot>[],
            <CartaSnapshot>[],
          ],
          jogosDupla: {
            'nos': [for (final m in melsNos) [...m]],
            'eles': <List<CartaSnapshot>>[],
          },
          rodadasVulneravel: const {'nos': 0, 'eles': 0},
          primeiraBaixadaFeita: const {'nos': true, 'eles': true},
          vez: vez,
          mortoPego: {...mortoPego},
        );

    Set<String> idsDoEstado(EstadoJogo e) => {
          for (final m in e.maos) ...m.map((c) => c.id),
          ...e.monte.map((c) => c.id),
          ...e.lixo.map((c) => c.id),
          for (final mm in e.mortos) ...mm.map((c) => c.id),
          for (final g in e.jogosDupla['nos']!) ...g.map((c) => c.id),
          for (final g in e.jogosDupla['eles']!) ...g.map((c) => c.id),
        };

    test('MORTO-01 esvazia sem descarte → morto DIRETO (mesma vez)', () {
      final est = estadoMorto(mortos: [morto11('a'), morto11('b')]);
      final r = pegarMorto(est, 0, viaDescarte: false);
      expect(r.valido, true);
      expect(r.tipo, FimMao.mortoDireto);
      final prox = r.proximoEstado!;
      expect(prox.maos[0].length, 11);
      expect(prox.mortoPego['nos'], true);
      expect(prox.mortos.length, 1);
      expect(prox.vez, est.vez); // direto mantém a vez
    });

    test('MORTO-02 esvazia ao descartar → morto INDIRETO (a vez passa)', () {
      final est = estadoMorto(mortos: [morto11('a'), morto11('b')], vez: 0);
      final r = pegarMorto(est, 0, viaDescarte: true);
      expect(r.valido, true);
      expect(r.tipo, FimMao.mortoIndireto);
      expect(r.proximoEstado!.maos[0].length, 11);
      expect(r.proximoEstado!.vez, 1); // indireto passa a vez (0→1)
    });

    test('MORTO-03 morto já utilizado não pode ser pego novamente', () {
      final est = estadoMorto(
          mortos: [morto11('a')],
          mortoPego: const {'nos': true, 'eles': false});
      final r = pegarMorto(est, 0);
      expect(r.valido, false);
      expect(r.proximoEstado, null);
    });

    test('MORTO-04 morto correto vai para a dupla correta', () {
      final mortoA = morto11('a');
      final mortoB = morto11('b');
      final est = estadoMorto(mortos: [mortoA, mortoB]);
      final r = pegarMorto(est, 0);
      expect(r.valido, true);
      final prox = r.proximoEstado!;
      expect(prox.maos[0].map((c) => c.id).toSet(),
          mortoA.map((c) => c.id).toSet());
      expect(prox.mortoPego['nos'], true);
      expect(prox.mortoPego['eles'], false);
      expect(prox.mortos.length, 1);
      expect(prox.mortos[0].map((c) => c.id).toSet(),
          mortoB.map((c) => c.id).toSet());
    });

    test('MORTO-05 retirada conserva as 11 cartas e todos os IDs', () {
      final est = estadoMorto(mortos: [morto11('a'), morto11('b')]);
      final idsAntes = idsDoEstado(est);
      final r = pegarMorto(est, 0);
      expect(r.valido, true);
      final prox = r.proximoEstado!;
      expect(prox.maos[0].length, 11);
      expect(idsDoEstado(prox), idsAntes); // nada some/surge
      expect(idsDoEstado(prox).length, 22); // sem duplicação
    });

    test('MORTO-06 falha preserva estado', () {
      final est = estadoMorto(
          mortos: [morto11('a')],
          mortoPego: const {'nos': true, 'eles': false});
      final antes = est.assinatura();
      final r = pegarMorto(est, 0);
      expect(r.valido, false);
      expect(r.proximoEstado, null);
      expect(est.assinatura(), antes);
      expect(est.mortos.length, 1);
    });

    test('MORTO-07 rodada encerrada → morto não pode ser pego, estado intacto',
        () {
      final est = estadoMorto(mortos: [morto11('a'), morto11('b')])
          .copyWith(rodadaEncerrada: true);
      final antes = est.assinatura();
      final r = pegarMorto(est, 0);
      expect(r.valido, false);
      expect(r.proximoEstado, null);
      expect(est.assinatura(), antes);
      expect(est.mortos.length, 2); // nada removido
      expect(podeEsvaziarMao(est, 0, fechado), false); // encerrada trava tudo
    });

    test('MORTO-08 morto com tamanho ≠ 11 → rejeita sem alterar estado', () {
      final curto = [for (int i = 0; i < 10; i++) csm('k$i', 'copas', '5')];
      final est = estadoMorto(mortos: [curto]);
      final antes = est.assinatura();
      final r = pegarMorto(est, 0);
      expect(r.valido, false);
      expect(r.proximoEstado, null);
      expect(est.assinatura(), antes);
      expect(est.mortos.first.length, 10); // pile intacto, não consumido
    });

    test('BATIDA-01 canastra válida + morto cumprido + mão vazia → permite', () {
      final est = estadoMorto(
          melsNos: [limpa7()],
          mortoPego: const {'nos': true, 'eles': false});
      final r = avaliarBatida(est, 0, fechado);
      expect(r.valido, true);
      expect(r.tipo, FimMao.batida);
      expect(r.proximoEstado!.rodadaEncerrada, true);
      expect(r.proximoEstado!.duplaQueBateu, 'nos');
    });

    test('BATIDA-02 trinca de 7+ não libera batida', () {
      final est = estadoMorto(
          melsNos: [trinca7()],
          mortoPego: const {'nos': true, 'eles': false});
      final r = avaliarBatida(est, 0, fechado);
      expect(r.valido, false);
      expect(r.proximoEstado, null);
    });

    test('BATIDA-03 sem canastra exigida → rejeita', () {
      final est = estadoMorto(
          melsNos: [seqCartas('copas', ['3', '4', '5'], 'x')],
          mortoPego: const {'nos': true, 'eles': false});
      final r = avaliarBatida(est, 0, fechado);
      expect(r.valido, false);
    });

    test('BATIDA-04 sem pegar o morto exigido → rejeita', () {
      final est = estadoMorto(
          mortos: [morto11('a')],
          melsNos: [limpa7()],
          mortoPego: const {'nos': false, 'eles': false});
      final r = avaliarBatida(est, 0, fechado);
      expect(r.valido, false); // morto disponível e não pego
    });

    test('BATIDA-05 canastra suja: libera no Fechado, não no Aberto', () {
      final estF = estadoMorto(
          melsNos: [suja7()],
          mortoPego: const {'nos': true, 'eles': false},
          modalidade: Modalidade.fechado);
      expect(avaliarBatida(estF, 0, fechado).valido, true);
      final estA = estadoMorto(
          melsNos: [suja7()],
          mortoPego: const {'nos': true, 'eles': false},
          modalidade: Modalidade.aberto);
      expect(avaliarBatida(estA, 0, aberto).valido, false);
    });

    test('BATIDA-06 batida aplica +100 uma única vez', () {
      final sem = pontuarRodada(const EntradaRodada(bateu: false), fechado);
      final com = pontuarRodada(const EntradaRodada(bateu: true), fechado);
      expect(com.batida, 100);
      expect(com.total - sem.total, 100);
    });

    test('BATIDA-07 morto não pego aplica −100 no fechamento', () {
      final r = pontuarRodada(
          const EntradaRodada(mortoPego: false, algumPegouMorto: true), fechado);
      expect(r.penalidadeMorto, 100);
      expect(r.total, -100);
    });

    test('BATIDA-08 tentativa inválida não altera mão, mesa, mortos, turno nem pontos',
        () {
      final est = estadoMorto(
          mortos: [morto11('a')],
          melsNos: [limpa7()],
          mortoPego: const {'nos': false, 'eles': false});
      final antes = est.assinatura();
      final r = avaliarBatida(est, 0, fechado); // morto não pego → recusa
      expect(r.valido, false);
      expect(r.proximoEstado, null);
      expect(est.assinatura(), antes);
      expect(est.rodadaEncerrada, false);
      expect(est.mortos.length, 1);
    });

    test('BATIDA-09 batida válida não faz carta sumir nem duplicar', () {
      final est = estadoMorto(
          melsNos: [limpa7()],
          mortoPego: const {'nos': true, 'eles': false});
      final idsAntes = idsDoEstado(est);
      final r = avaliarBatida(est, 0, fechado);
      expect(r.valido, true);
      expect(idsDoEstado(r.proximoEstado!), idsAntes);
    });
  });

  // ===================================================================
  // C7 — GERADOR ÚNICO de ações legais (rules/gerador/gerador.dart).
  // Duas travas globais (fora da vez / rodada encerrada) + paridade
  // jogador↔bot (mesma legalidade). Aditivo: motor antigo segue ativo.
  // ===================================================================
  group('C7 — gerador único (turno e legalidade)', () {
    CartaSnapshot csm(String id, String? naipe, String valor) =>
        CartaSnapshot(id, naipe, valor, valor == '2' || valor == 'JOKER');
    final fechado = RuleSpec.canonica(Modalidade.fechado);

    EstadoJogo estadoTurno({
      int vez = 0,
      bool rodadaEncerrada = false,
      List<CartaSnapshot> mao0 = const [],
      List<CartaSnapshot> mao1 = const [],
      List<CartaSnapshot> monte = const [],
      List<CartaSnapshot> lixo = const [],
      List<List<CartaSnapshot>> melsNos = const [],
      List<List<CartaSnapshot>> mortos = const [],
      Map<String, bool> mortoPego = const {'nos': false, 'eles': false},
      Modalidade modalidade = Modalidade.fechado,
      FaseTurno fase = FaseTurno.compra,
    }) =>
        EstadoJogo(
          modalidade: modalidade,
          metaPontos: 1500,
          monte: [...monte],
          lixo: [...lixo],
          mortos: [for (final m in mortos) [...m]],
          maos: [
            [...mao0],
            [...mao1],
            <CartaSnapshot>[],
            <CartaSnapshot>[],
          ],
          jogosDupla: {
            'nos': [for (final m in melsNos) [...m]],
            'eles': <List<CartaSnapshot>>[],
          },
          rodadasVulneravel: const {'nos': 0, 'eles': 0},
          primeiraBaixadaFeita: const {'nos': true, 'eles': true},
          vez: vez,
          mortoPego: {...mortoPego},
          rodadaEncerrada: rodadaEncerrada,
          fase: fase,
        );

    // Estado base: é a vez do assento 0; monte e lixo com carta; assento 1 com
    // uma mão qualquer (para provar que o bloqueio é o TURNO, não o conteúdo).
    EstadoJogo base() => estadoTurno(
          vez: 0,
          monte: [csm('m0', 'copas', '7')],
          lixo: [csm('x0', 'ouros', '9')],
          mao0: [csm('a0', 'copas', '3'), csm('a1', 'copas', '4')],
          mao1: [csm('b0', 'espadas', '5'), csm('b1', 'espadas', '6')],
        );

    test('TURNO-01 compra do monte fora da vez → não gera / rejeita', () {
      final est = base(); // vez = 0
      final r = aplicarLegal(est, 1, const ComprarMonte(), fechado);
      expect(r.legal, false);
      expect(r.motivo, contains('vez'));
      expect(r.proximoEstado, null);
      expect(gerarAcoesLegais(est, 1, fechado), isEmpty);
    });

    test('TURNO-02 compra do lixo fora da vez → não gera / rejeita', () {
      final est = base();
      final r = aplicarLegal(est, 1, const ComprarLixo(), fechado);
      expect(r.legal, false);
      expect(r.motivo, contains('vez'));
      expect(gerarAcoesLegais(est, 1, fechado), isEmpty);
    });

    test('TURNO-03 baixar fora da vez → não gera / rejeita', () {
      final est = base();
      final r = aplicarLegal(
          est, 1, const Baixar(jogosNovos: [['b0', 'b1']]), fechado);
      expect(r.legal, false);
      expect(r.motivo, contains('vez'));
    });

    test('TURNO-04 estender fora da vez → não gera / rejeita', () {
      final est = base();
      final r = aplicarLegal(
          est, 1, const Baixar(extensoes: [Extensao(0, ['b0'])]), fechado);
      expect(r.legal, false);
      expect(r.motivo, contains('vez'));
    });

    test('TURNO-05 descartar fora da vez → não gera / rejeita', () {
      final est = base();
      final r = aplicarLegal(est, 1, const Descartar('b0'), fechado);
      expect(r.legal, false);
      expect(r.motivo, contains('vez'));
    });

    test('TURNO-06 pegar morto fora da vez → não gera / rejeita', () {
      final est = base();
      final r = aplicarLegal(est, 1, const PegarMorto(), fechado);
      expect(r.legal, false);
      expect(r.motivo, contains('vez'));
    });

    test('TURNO-07 bater fora da vez → não gera / rejeita', () {
      final est = base();
      final r = aplicarLegal(est, 1, const Bater(), fechado);
      expect(r.legal, false);
      expect(r.motivo, contains('vez'));
    });

    test('TURNO-08 rodada encerrada → nenhuma ação legal', () {
      final est = estadoTurno(
        vez: 0,
        rodadaEncerrada: true,
        monte: [csm('m0', 'copas', '7')],
        mao0: [csm('a0', 'copas', '3')],
      );
      // Mesmo sendo a vez do assento 0, a rodada fechada trava tudo.
      expect(gerarAcoesLegais(est, 0, fechado), isEmpty);
      final r = aplicarLegal(est, 0, const ComprarMonte(), fechado);
      expect(r.legal, false);
      expect(r.motivo, contains('encerrada'));
      expect(r.proximoEstado, null);
    });

    test('TURNO-09 assento da vez → só ações realmente legais aparecem', () {
      final est = base(); // vez 0, FASE COMPRA (início do turno), monte não vazio
      final ger = gerarAcoesLegais(est, 0, fechado);
      // Na fase de COMPRA a única ação legal aqui é comprar do monte.
      expect(ger.any((a) => a is ComprarMonte), true);
      expect(ger.any((a) => a is Descartar), false); // não descarta antes de comprar
      expect(ger.any((a) => a is ComprarLixo), false); // Fechado sem uso do topo
      expect(ger.any((a) => a is Bater), false);
      expect(ger.any((a) => a is PegarMorto), false);
    });

    test('TURNO-10 mesma situação para jogador e bot → mesma legalidade', () {
      // Fase de JOGO (já comprou). Mão0 = 3,4,5 de copas (sequência válida);
      // já abriu antes, então sem mínimo. Um candidato válido e um inválido.
      final est = estadoTurno(
        vez: 0,
        fase: FaseTurno.jogo,
        monte: [csm('m0', 'copas', '7')],
        mao0: [
          csm('h0', 'copas', '3'),
          csm('h1', 'copas', '4'),
          csm('h2', 'copas', '5'),
          csm('h3', 'ouros', 'K'), // sobra: a baixada NÃO zera a mão
        ],
      );
      const candValido = Baixar(jogosNovos: [['h0', 'h1', 'h2']]);
      const candInvalido = Baixar(jogosNovos: [['h0', 'h1']]); // < 3 cartas
      final props = <Acao>[candValido, candInvalido];
      // "Bot": enumera candidatos e filtra pela MESMA legalidade do gerador.
      final ger = gerarAcoesLegais(est, 0, fechado, candidatos: props);
      final decisaoBot = [for (final a in props) ger.contains(a)];
      // "Jogador": pergunta a legalidade de cada ação, uma a uma.
      final decisaoJogador = [
        for (final a in props) acaoEhLegal(est, 0, a, fechado)
      ];
      expect(decisaoJogador, decisaoBot); // paridade estrutural
      expect(decisaoJogador, [true, false]);
    });
  });

  // ===================================================================
  // C7-fix — FASE DO TURNO (sequência temporal é regra). O gerador único
  // só oferece/aplica ações compatíveis com estado.fase. Aditivo.
  // ===================================================================
  group('C7-fix — fase do turno', () {
    CartaSnapshot csm(String id, String? naipe, String valor) =>
        CartaSnapshot(id, naipe, valor, valor == '2' || valor == 'JOKER');
    final fechado = RuleSpec.canonica(Modalidade.fechado);
    final aberto = RuleSpec.canonica(Modalidade.aberto);

    List<CartaSnapshot> morto11(String pre) =>
        [for (int i = 0; i < 11; i++) csm('$pre$i', 'copas', '5')];

    EstadoJogo estF({
      FaseTurno fase = FaseTurno.compra,
      int vez = 0,
      List<CartaSnapshot> mao0 = const [],
      List<CartaSnapshot> monte = const [],
      List<CartaSnapshot> lixo = const [],
      List<List<CartaSnapshot>> mortos = const [],
      List<List<CartaSnapshot>> melsNos = const [],
      Map<String, bool> mortoPego = const {'nos': false, 'eles': false},
      Modalidade modalidade = Modalidade.fechado,
    }) =>
        EstadoJogo(
          modalidade: modalidade,
          metaPontos: 1500,
          monte: [...monte],
          lixo: [...lixo],
          mortos: [for (final m in mortos) [...m]],
          maos: [
            [...mao0],
            <CartaSnapshot>[],
            <CartaSnapshot>[],
            <CartaSnapshot>[],
          ],
          jogosDupla: {
            'nos': [for (final m in melsNos) [...m]],
            'eles': <List<CartaSnapshot>>[],
          },
          rodadasVulneravel: const {'nos': 0, 'eles': 0},
          primeiraBaixadaFeita: const {'nos': true, 'eles': true},
          vez: vez,
          mortoPego: {...mortoPego},
          fase: fase,
        );

    List<CartaSnapshot> limpa7() => [
          for (int i = 0; i < 7; i++)
            csm('c$i', 'copas', const ['3', '4', '5', '6', '7', '8', '9'][i])
        ];

    test('FASE-01 início (compra): pode comprar, não pode descartar', () {
      final est = estF(
          fase: FaseTurno.compra,
          monte: [csm('m0', 'copas', '7')],
          mao0: [csm('a0', 'copas', '3')]);
      expect(acaoEhLegal(est, 0, const ComprarMonte(), fechado), true);
      expect(acaoEhLegal(est, 0, const Descartar('a0'), fechado), false);
      final ger = gerarAcoesLegais(est, 0, fechado);
      expect(ger.any((a) => a is ComprarMonte), true);
      expect(ger.any((a) => a is Descartar), false);
    });

    test('FASE-02 após comprar do monte: não pode comprar de novo', () {
      final est = estF(
          fase: FaseTurno.compra,
          monte: [csm('m0', 'copas', '7'), csm('m1', 'ouros', '8')],
          mao0: [csm('a0', 'copas', '3')]);
      final r = aplicarLegal(est, 0, const ComprarMonte(), fechado);
      expect(r.legal, true);
      final prox = r.proximoEstado!;
      expect(prox.fase, FaseTurno.jogo);
      expect(acaoEhLegal(prox, 0, const ComprarMonte(), fechado), false);
      expect(acaoEhLegal(prox, 0, const ComprarLixo(), fechado), false);
    });

    test('FASE-03 após comprar do lixo: não pode comprar monte/lixo de novo', () {
      // Aberto: a compra do lixo pode ocorrer sem baixar.
      final est = estF(
          fase: FaseTurno.compra,
          modalidade: Modalidade.aberto,
          monte: [csm('m0', 'copas', '7')],
          lixo: [csm('x0', 'ouros', '9')],
          mao0: [csm('a0', 'copas', '3')]);
      final r = aplicarLegal(est, 0, const ComprarLixo(), aberto);
      expect(r.legal, true);
      final prox = r.proximoEstado!;
      expect(prox.fase, FaseTurno.jogo);
      expect(acaoEhLegal(prox, 0, const ComprarMonte(), aberto), false);
      expect(acaoEhLegal(prox, 0, const ComprarLixo(), aberto), false);
    });

    test('FASE-04 após compra (fase jogo): pode baixar/estender', () {
      final maoSeq = [
        csm('h0', 'copas', '3'),
        csm('h1', 'copas', '4'),
        csm('h2', 'copas', '5'),
        csm('h3', 'ouros', 'K'), // sobra: a baixada NÃO zera a mão
      ];
      final estJogo = estF(fase: FaseTurno.jogo, mao0: maoSeq);
      final estCompra = estF(fase: FaseTurno.compra, mao0: maoSeq);
      const baixada = Baixar(jogosNovos: [['h0', 'h1', 'h2']]);
      expect(acaoEhLegal(estJogo, 0, baixada, fechado), true);
      expect(acaoEhLegal(estCompra, 0, baixada, fechado), false);
    });

    test('FASE-05 descarte só após a fase de compra', () {
      final est0 = estF(fase: FaseTurno.compra, mao0: [csm('a0', 'copas', '3')]);
      final est1 = estF(
          fase: FaseTurno.jogo,
          mao0: [csm('a0', 'copas', '3'), csm('a1', 'copas', '4')]);
      expect(acaoEhLegal(est0, 0, const Descartar('a0'), fechado), false);
      expect(acaoEhLegal(est1, 0, const Descartar('a0'), fechado), true);
    });

    test('FASE-06 descarte encerra o turno; próximo começa em compra', () {
      final est = estF(
          fase: FaseTurno.jogo,
          vez: 0,
          mao0: [csm('a0', 'copas', '3'), csm('a1', 'copas', '4')]);
      final r = aplicarLegal(est, 0, const Descartar('a0'), fechado);
      expect(r.legal, true);
      final prox = r.proximoEstado!;
      expect(prox.vez, 1); // a vez passa
      expect(prox.fase, FaseTurno.compra); // próximo começa comprando
    });

    test('FASE-07 morto direto: mantém em fase de jogo e exige descarte', () {
      // Mão vazia (esvaziada baixando), fase de jogo, morto disponível.
      final est = estF(
          fase: FaseTurno.jogo, vez: 0, mao0: const [], mortos: [morto11('a')]);
      final r = aplicarLegal(est, 0, const PegarMorto(), fechado); // direto
      expect(r.legal, true);
      final prox = r.proximoEstado!;
      expect(prox.fase, FaseTurno.jogo); // continua em jogo
      expect(prox.vez, 0); // mesma vez
      expect(prox.maos[0].length, 11); // pegou o morto
      // exige descarte posterior: um descarte é legal agora
      expect(
          acaoEhLegal(prox, 0, Descartar(prox.maos[0].first.id), fechado), true);
    });

    test('FASE-08 morto indireto: descarte esvazia → pendente → passa a vez', () {
      final est = estF(
          fase: FaseTurno.jogo,
          vez: 0,
          mao0: [csm('a0', 'copas', '3')],
          mortos: [morto11('a')]);
      // Descarta a última carta → fase mortoPendente, MESMA vez.
      final r1 = aplicarLegal(est, 0, const Descartar('a0'), fechado);
      expect(r1.legal, true);
      final p1 = r1.proximoEstado!;
      expect(p1.fase, FaseTurno.mortoPendente);
      expect(p1.vez, 0);
      // A ÚNICA ação legal agora é pegar o morto indireto.
      final ger = gerarAcoesLegais(p1, 0, fechado);
      expect(ger.length, 1);
      expect(ger.single, isA<PegarMorto>());
      final r2 =
          aplicarLegal(p1, 0, const PegarMorto(viaDescarte: true), fechado);
      expect(r2.legal, true);
      final p2 = r2.proximoEstado!;
      expect(p2.vez, 1); // agora a vez passa
      expect(p2.fase, FaseTurno.compra); // próximo começa comprando
      expect(p2.maos[0].length, 11); // pegou o morto
    });

    test('FASE-09 morto indireto sem descarte real anterior → rejeita', () {
      // Fase de jogo (não pendente), mão vazia e morto disponível.
      final estJogo = estF(
          fase: FaseTurno.jogo, vez: 0, mao0: const [], mortos: [morto11('a')]);
      final r =
          aplicarLegal(estJogo, 0, const PegarMorto(viaDescarte: true), fechado);
      expect(r.legal, false);
      expect(r.proximoEstado, null);
      // Também ilegal a partir da fase de compra.
      final estCompra =
          estF(fase: FaseTurno.compra, vez: 0, mortos: [morto11('a')]);
      expect(
          acaoEhLegal(estCompra, 0, const PegarMorto(viaDescarte: true), fechado),
          false);
    });

    test('FASE-10 nenhuma ação se repete fora da sequência permitida', () {
      final est = estF(
          fase: FaseTurno.compra,
          vez: 0,
          monte: [csm('m0', 'copas', '7'), csm('m1', 'ouros', '8')],
          mao0: [csm('a0', 'copas', '3')]);
      // 1) comprar do monte → jogo; comprar de novo é ilegal.
      final p1 = aplicarLegal(est, 0, const ComprarMonte(), fechado).proximoEstado!;
      expect(acaoEhLegal(p1, 0, const ComprarMonte(), fechado), false);
      expect(gerarAcoesLegais(p1, 0, fechado).any((a) => a is ComprarMonte),
          false);
      // 2) descartar encerra → compra, vez 1; descartar de novo é ilegal.
      final p2 =
          aplicarLegal(p1, 0, Descartar(p1.maos[0].first.id), fechado)
              .proximoEstado!;
      expect(p2.fase, FaseTurno.compra);
      expect(p2.vez, 1);
      expect(acaoEhLegal(p2, 1, const Descartar('qualquer'), fechado), false);
    });

    test('FASE-11 fase entra em clone, normalizar, assinatura, replay e sombra',
        () {
      final st = estF(fase: FaseTurno.jogo, mao0: [csm('a0', 'copas', '3')]);
      expect(st.cloneProfundo().fase, FaseTurno.jogo); // clone
      expect(st.normalizar().fase, FaseTurno.jogo); // normalizar
      expect(st.assinatura(), contains('fase=jogo')); // sombra (assinatura)
      final outra = estF(fase: FaseTurno.compra, mao0: [csm('a0', 'copas', '3')]);
      expect(st.assinatura() == outra.assinatura(), false); // fase muda assinatura
      final rep = Replay(
          seed: 1,
          versaoSpec: 'x',
          modalidade: Modalidade.fechado,
          faseInicial: FaseTurno.jogo);
      expect(Replay.fromJson(rep.toJson()).faseInicial, FaseTurno.jogo); // replay
    });

    test('FASE-12 já pegou morto + canastra + descarta última → BATIDA', () {
      final est = estF(
          fase: FaseTurno.jogo,
          vez: 0,
          mao0: [csm('u0', 'ouros', 'K')], // última carta
          melsNos: [limpa7()], // canastra na mesa
          mortoPego: const {'nos': true, 'eles': false}); // morto cumprido
      final r = aplicarLegal(est, 0, const Descartar('u0'), fechado);
      expect(r.legal, true);
      final prox = r.proximoEstado!;
      expect(prox.rodadaEncerrada, true); // encerra como BATIDA
      expect(prox.duplaQueBateu, 'nos');
      expect(prox.vez, 0); // não "passa a vez" simplesmente
    });

    test('FASE-13 já pegou morto, SEM canastra, descarta última → rejeita', () {
      final est = estF(
          fase: FaseTurno.jogo,
          vez: 0,
          mao0: [csm('u0', 'ouros', 'K')],
          melsNos: const [], // nenhuma canastra que libere
          mortoPego: const {'nos': true, 'eles': false});
      final antes = est.assinatura();
      final r = aplicarLegal(est, 0, const Descartar('u0'), fechado);
      expect(r.legal, false);
      expect(r.proximoEstado, null);
      expect(est.assinatura(), antes); // estado intacto
    });

    test('FASE-14 baixa todas + morto disponível → morto direto, mantém a vez', () {
      final est = estF(
          fase: FaseTurno.jogo,
          vez: 0,
          mao0: [
            csm('h0', 'copas', '3'),
            csm('h1', 'copas', '4'),
            csm('h2', 'copas', '5'),
          ],
          mortos: [morto11('a')]);
      final r = aplicarLegal(
          est, 0, const Baixar(jogosNovos: [['h0', 'h1', 'h2']]), fechado);
      expect(r.legal, true);
      final prox = r.proximoEstado!;
      expect(prox.maos[0].isEmpty, true);
      expect(prox.fase, FaseTurno.jogo);
      expect(prox.vez, 0); // mantém a vez
      expect(acaoEhLegal(prox, 0, const PegarMorto(), fechado), true);
    });

    test('FASE-15 baixa todas + morto cumprido + canastra → pode bater', () {
      final est = estF(
          fase: FaseTurno.jogo,
          vez: 0,
          mao0: limpa7(), // 7 cartas formam canastra ao baixar
          mortoPego: const {'nos': true, 'eles': false}); // morto cumprido
      final r = aplicarLegal(
          est,
          0,
          Baixar(jogosNovos: [
            [for (final c in limpa7()) c.id]
          ]),
          fechado);
      expect(r.legal, true);
      final prox = r.proximoEstado!;
      expect(prox.maos[0].isEmpty, true);
      expect(acaoEhLegal(prox, 0, const Bater(), fechado), true);
    });

    test('FASE-16 baixa todas sem morto nem canastra → rejeita a baixada', () {
      final est = estF(
          fase: FaseTurno.jogo,
          vez: 0,
          mao0: [
            csm('h0', 'copas', '3'),
            csm('h1', 'copas', '4'),
            csm('h2', 'copas', '5'),
          ],
          mortos: const [], // sem morto
          mortoPego: const {'nos': true, 'eles': false});
      final antes = est.assinatura();
      final r = aplicarLegal(
          est, 0, const Baixar(jogosNovos: [['h0', 'h1', 'h2']]), fechado);
      expect(r.legal, false); // 3 cartas não é canastra; nada libera esvaziar
      expect(r.proximoEstado, null);
      expect(est.assinatura(), antes); // estado intacto
    });

    test('FASE-17 descarte da última com morto disponível → morto indireto', () {
      final est = estF(
          fase: FaseTurno.jogo,
          vez: 0,
          mao0: [csm('u0', 'ouros', 'K')],
          mortos: [morto11('a')]);
      final r = aplicarLegal(est, 0, const Descartar('u0'), fechado);
      expect(r.legal, true);
      final prox = r.proximoEstado!;
      expect(prox.fase, FaseTurno.mortoPendente);
      final ger = gerarAcoesLegais(prox, 0, fechado);
      expect(ger.length, 1);
      expect(ger.single, isA<PegarMorto>());
    });

    test('FASE-18 nenhuma transição deixa mão vazia + rodada aberta + 0 ações', () {
      // (a) baixar que esvazia COM morto: aceito e há ação legal (saída existe).
      final estA = estF(
          fase: FaseTurno.jogo,
          vez: 0,
          mao0: [
            csm('h0', 'copas', '3'),
            csm('h1', 'copas', '4'),
            csm('h2', 'copas', '5'),
          ],
          mortos: [morto11('a')]);
      final pA = aplicarLegal(
              estA, 0, const Baixar(jogosNovos: [['h0', 'h1', 'h2']]), fechado)
          .proximoEstado!;
      expect(pA.maos[0].isEmpty && !pA.rodadaEncerrada, true);
      expect(gerarAcoesLegais(pA, 0, fechado), isNotEmpty); // invariante
      // (b) baixar que esvaziaria SEM saída: rejeitado (não cria estado impossível).
      final estB = estF(
          fase: FaseTurno.jogo,
          vez: 0,
          mao0: [
            csm('h0', 'copas', '3'),
            csm('h1', 'copas', '4'),
            csm('h2', 'copas', '5'),
          ],
          mortos: const [],
          mortoPego: const {'nos': true, 'eles': false});
      expect(
          aplicarLegal(estB, 0, const Baixar(jogosNovos: [['h0', 'h1', 'h2']]),
                  fechado)
              .legal,
          false);
      // (c) descarte-batida: encerra a rodada (não fica aberta e vazia).
      final estC = estF(
          fase: FaseTurno.jogo,
          vez: 0,
          mao0: [csm('u0', 'ouros', 'K')],
          melsNos: [limpa7()],
          mortoPego: const {'nos': true, 'eles': false});
      final pC =
          aplicarLegal(estC, 0, const Descartar('u0'), fechado).proximoEstado!;
      expect(pC.rodadaEncerrada, true);
    });
  });

  // ===================================================================
  // C8 — CONFORMIDADE Dart × Node (modo sombra). Roda os MESMOS vetores no
  // motor canônico e compara com o fixture do servidor deployado (só leitura).
  // PÓS-DEPLOY (server @09835bd, sha256 81ec3255…): o servidor foi corrigido
  // para a regra canônica (CRIT-01 de_500, CRIT-02 as_a_as, CRIT-03 bot).
  // Todos os vetores CONVERGEM → ZERO divergências críticas. O portão agora
  // EXIGE conjunto crítico vazio; qualquer divergência volta a bloquear online.
  // ===================================================================
  group('C8 — conformidade Dart × Node', () {
    final fx = jsonDecode(c8FixtureJson) as Map<String, dynamic>;
    final fechado = RuleSpec.canonica(Modalidade.fechado);
    final aberto = RuleSpec.canonica(Modalidade.aberto);
    RuleSpec specDe(String m) =>
        m == 'aberto' ? aberto : (m == 'fechado' ? fechado : RuleSpec.canonica(Modalidade.stbl));
    CartaSnapshot cfx(Map<String, dynamic> c) => CartaSnapshot(
        c['id'] as String,
        c['naipe'] as String?,
        c['valor'] as String,
        c['valor'] == '2' || c['valor'] == 'JOKER');

    test('C8-HASH fixture casa com o extrato de regras do servidor + versão da spec',
        () {
      expect(fx['hashRegrasNode'],
          '81ec3255b8b67c25f6ca47a3d33486f0f81112f9da4573bb34cf3a1f1eb34281');
      expect(fx['versaoSpec'], 'bmv-regras-2026.08');
    });

    test('C8-CONFORMIDADE cross-engine: ZERO divergências críticas (pós-deploy)', () {
      final criticas = <String>{};

      // MELD: compara legalidade e bônus de canastra (efeito), não rótulos.
      for (final v in (fx['meld'] as List).cast<Map<String, dynamic>>()) {
        final cartas = (v['cartas'] as List)
            .cast<Map<String, dynamic>>()
            .map(cfx)
            .toList();
        final r = validarJogoMesa(cartas, specDe(v['modalidade'] as String));
        final dartValido = r.valido;
        final dartBonus = bonusCanastra(r);
        final node = v['node'] as Map<String, dynamic>;
        final igual =
            dartValido == (node['valido'] as bool) && dartBonus == (node['bonus'] as int);
        final crit = v['critEsperado'] as String?;
        if (igual) {
          expect(crit, isNull,
              reason:
                  '${v['id']}: esperava divergência ($crit) mas coincidiu (valido=$dartValido bonus=$dartBonus)');
        } else {
          expect(crit, isNotNull,
              reason:
                  '${v['id']}: divergência NÃO prevista — Dart(valido=$dartValido,bonus=$dartBonus) × Node(valido=${node['valido']},bonus=${node['bonus']})');
          criticas.add(crit!);
        }
      }

      // PONTUAÇÃO: compara o total da rodada da dupla.
      for (final v in (fx['score'] as List).cast<Map<String, dynamic>>()) {
        final melds = (v['melds'] as List)
            .map((m) =>
                (m as List).cast<Map<String, dynamic>>().map(cfx).toList())
            .toList();
        final mao =
            (v['mao'] as List).cast<Map<String, dynamic>>().map(cfx).toList();
        final f = v['flags'] as Map<String, dynamic>;
        final r = pontuarRodada(
            EntradaRodada(
              melds: melds,
              mao: mao,
              bateu: f['bateu'] as bool,
              mortoPego: f['mortoPego'] as bool,
              algumPegouMorto: f['algumPegouMorto'] as bool,
            ),
            fechado);
        final dartTotal = r.total;
        final nodeTotal = (v['node'] as Map<String, dynamic>)['total'] as int;
        final igual = dartTotal == nodeTotal;
        final crit = v['critEsperado'] as String?;
        if (igual) {
          expect(crit, isNull,
              reason:
                  '${v['id']}: esperava divergência ($crit) mas os totais coincidiram ($dartTotal)');
        } else {
          expect(crit, isNotNull,
              reason:
                  '${v['id']}: divergência de pontuação NÃO prevista — Dart=$dartTotal × Node=$nodeTotal');
          criticas.add(crit!);
        }
      }

      // PÓS-DEPLOY: com o servidor na regra canônica, o conjunto crítico é
      // VAZIO. Se qualquer divergência ressurgir (regressão no servidor ou
      // fixture desatualizado), este teste falha e bloqueia a promoção online.
      expect(criticas, <String>{});
    });
  });

  // ===================================================================
  // C9-A — costura do motor canônico atrás de flag: FLAGS + CONTRATO da
  // porta + FÁBRICA/SELETOR. NENHUM runtime, NENHUMA projeção Jogo<->
  // EstadoJogo, NENHUM adaptador concreto (isso é o C9-B). Os testes só
  // exercitam flags (independência/OFF por padrão), seleção e a fábrica com
  // construtores INJETADOS (dublês reais — não lançam UnimplementedError).
  // ===================================================================
  group('C9-A — flags + porta + fábrica', () {
    // FLAGS -----------------------------------------------------------------
    test('C9-FLAG-01 defaults OFF (construtor padrão)', () {
      const c = MotorConfig();
      expect(c.canonicoAtivo, isFalse);
      expect(c.sombraAtiva, isFalse);
    });

    test('C9-FLAG-02 doAmbiente() sem --dart-define: ambas OFF', () {
      final c = MotorConfig.doAmbiente();
      expect(c.canonicoAtivo, isFalse);
      expect(c.sombraAtiva, isFalse);
    });

    test('C9-FLAG-03 flags INDEPENDENTES (sombra não liga autoridade)', () {
      const soSombra = MotorConfig(sombraAtiva: true);
      expect(soSombra.sombraAtiva, isTrue);
      expect(soSombra.canonicoAtivo, isFalse);
      const soAutoridade = MotorConfig(canonicoAtivo: true);
      expect(soAutoridade.canonicoAtivo, isTrue);
      expect(soAutoridade.sombraAtiva, isFalse);
    });

    // SELEÇÃO ---------------------------------------------------------------
    test('C9-SEL-01 autoridade OFF -> legado', () {
      expect(selecionarMotor(const MotorConfig()), TipoMotor.legado);
    });

    test('C9-SEL-02 autoridade ON -> canônico', () {
      expect(selecionarMotor(const MotorConfig(canonicoAtivo: true)),
          TipoMotor.canonico);
    });

    test('C9-SEL-03 sombra NÃO afeta a seleção', () {
      // Sombra ligada, autoridade desligada => ainda legado.
      expect(selecionarMotor(const MotorConfig(sombraAtiva: true)),
          TipoMotor.legado);
      // Sombra ligada, autoridade ligada => canônico (seleção só olha autoridade).
      expect(
          selecionarMotor(
              const MotorConfig(canonicoAtivo: true, sombraAtiva: true)),
          TipoMotor.canonico);
    });

    // FÁBRICA (construtores injetados; dublês reais) -------------------------
    final construtores = <TipoMotor, ConstrutorPorta>{
      TipoMotor.legado: () => const _PortaDupla('legado'),
      TipoMotor.canonico: () => const _PortaDupla('canonico'),
    };

    test('C9-FAB-01 autoridade OFF -> fábrica devolve a porta LEGADA', () {
      final fab = FabricaMotor(construtores);
      final porta = fab.criar(const MotorConfig());
      expect(porta, isA<PortaMotor>());
      expect((porta as _PortaDupla).marca, 'legado');
    });

    test('C9-FAB-02 autoridade ON -> fábrica devolve a porta CANÔNICA', () {
      final fab = FabricaMotor(construtores);
      final porta = fab.criar(const MotorConfig(canonicoAtivo: true));
      expect((porta as _PortaDupla).marca, 'canonico');
    });

    test('C9-FAB-03 sem construtor registrado -> StateError (não devolve fake)',
        () {
      // Só o legado registrado; pede autoridade ON (canônico) -> deve falhar.
      final fab = FabricaMotor(<TipoMotor, ConstrutorPorta>{
        TipoMotor.legado: () => const _PortaDupla('legado'),
      });
      expect(() => fab.criar(const MotorConfig(canonicoAtivo: true)),
          throwsStateError);
    });

    // CONTRATO --------------------------------------------------------------
    test('C9-CONTRATO-01 a porta é tipada em termos canônicos (implementável)',
        () {
      final PortaMotor porta = const _PortaDupla('legado');
      final estado = _estadoMinimoC9();
      final spec = RuleSpec.canonica(Modalidade.aberto);
      // As quatro operações respondem com os TIPOS canônicos do contrato.
      expect(porta.ehVez(estado, 0), isA<bool>());
      expect(porta.acoesLegais(estado, 0, spec), isA<List<Acao>>());
      expect(porta.ehLegal(estado, 0, const ComprarMonte(), spec), isA<bool>());
      final r = porta.aplicar(estado, 0, const ComprarMonte(), spec);
      expect(r, isA<ResultadoJogada>());
      expect(r.legal, isFalse); // dublê recusa; contrato preserva a forma
    });
  });

  // ===================================================================
  // C9-B — projeção/envelope + adaptadores concretos + composição (costura
  // runtime AUTORIDADE OFF). Matriz completa de estado: CANÔNICO round-trip
  // exato; DERIVADO por função pura; cada RUNTIME ENVELOPE preservado;
  // UI/SIDECAR pass-through; nada some em silêncio.
  // ===================================================================
  group('C9-B — projeção + adaptadores', () {
    test('C9-MAP-01 CANÔNICO round-trip exato (estado rico)', () {
      final o = _origemRicaC9();
      final a = _roundTripC9(o);
      expect(a.modalidade, o.modalidade);
      expect(a.metaPontos, o.metaPontos);
      expect(a.vez, o.vez);
      expect(a.rodadaEncerrada, o.rodadaEncerrada);
      expect(a.duplaQueBateu, o.duplaQueBateu);
      expect(a.jaComprou, o.jaComprou);
      expect(a.mortoPego, o.mortoPego);
      expect(a.rodadasVulneravel, o.rodadasVulneravel);
      expect(a.primeiraBaixadaFeita, o.primeiraBaixadaFeita);
      expect(_sigM(a.maos), _sigM(o.maos));
      expect(_sig(a.monte), _sig(o.monte));
      expect(_sig(a.lixo), _sig(o.lixo));
      expect(_sigM(a.mortos), _sigM(o.mortos));
      expect(_sigM(a.jogosDupla['nos']!), _sigM(o.jogosDupla['nos']!));
      expect(_sigM(a.jogosDupla['eles']!), _sigM(o.jogosDupla['eles']!));
    });

    test('C9-MAP-02 DERIVADO fase <-> jaComprou (função pura)', () {
      final comprou = _origemRicaC9()..jaComprou = true;
      expect(paraCanonico(comprou).canonico.fase, FaseTurno.jogo);
      final naoComprou = _origemRicaC9()..jaComprou = false;
      expect(paraCanonico(naoComprou).canonico.fase, FaseTurno.compra);
      final alvo = Jogo.paraCostura();
      aplicarEmJogo(
          alvo, paraCanonico(comprou).canonico, EnvelopeRuntime.vazio());
      expect(alvo.jaComprou, isTrue);
      aplicarEmJogo(
          alvo, paraCanonico(naoComprou).canonico, EnvelopeRuntime.vazio());
      expect(alvo.jaComprou, isFalse);
    });

    test('C9-MAP-03 RUNTIME ENVELOPE — cada campo preservado', () {
      final o = _origemRicaC9();
      final a = _roundTripC9(o);
      // privados (via seam)
      expect(a.costuraCont, 42);
      expect(a.costuraLixoUnicoCompradoId, 'c200');
      expect(a.costuraMortosConvertidos, 1);
      expect(a.costuraIniciadorRodada, 2);
      expect(a.costuraRodadaContada, isTrue);
      // públicos
      expect(a.lixoTopoObrigatorio, 'c200');
      expect(a.integridadeErro, isNull);
      expect(a.assentoQueBateu, isNull);
      expect(a.rodada, 5);
      expect(a.placar, {'nos': 120, 'eles': 80});
      expect(a.encerrada, isFalse);
      expect(a.pontosRodada?['x'], 1);
    });

    test('C9-MAP-04 UI/SIDECAR pass-through', () {
      final o = _origemRicaC9();
      final a = _roundTripC9(o);
      expect(a.apelidos, o.apelidos);
      expect(a.avatares, o.avatares);
      expect(a.mascotes, o.mascotes);
    });

    test('C9-MAP-05 estados representativos round-trip sem perda', () {
      final inicio = Jogo.paraCostura();
      final aInicio = _roundTripC9(inicio);
      expect(aInicio.vez, 0);
      expect(aInicio.jaComprou, isFalse);
      expect(_sigM(aInicio.maos), _sigM(inicio.maos));

      final fim = _origemRicaC9()
        ..rodadaEncerrada = true
        ..duplaQueBateu = 'nos'
        ..assentoQueBateu = 1;
      final aFim = _roundTripC9(fim);
      expect(aFim.rodadaEncerrada, isTrue);
      expect(aFim.duplaQueBateu, 'nos');
      expect(aFim.assentoQueBateu, 1);

      final batida = _origemRicaC9()
        ..maos = [
          [Carta('u1', 'copas', 'Q', false)],
          <Carta>[],
          <Carta>[],
          <Carta>[],
        ]
        ..vez = 0;
      final aBatida = _roundTripC9(batida);
      expect(_sig(aBatida.maos[0]), _sig(batida.maos[0]));
      expect(aBatida.maos[0].length, 1);
    });

    test('C9-MAP-06 mortoPendente é canônico-only (=> jaComprou no legado)', () {
      final base = paraCanonico(_origemRicaC9()).canonico;
      final estadoPendente = EstadoJogo(
        modalidade: base.modalidade,
        metaPontos: base.metaPontos,
        monte: base.monte,
        lixo: base.lixo,
        mortos: base.mortos,
        maos: base.maos,
        jogosDupla: base.jogosDupla,
        rodadasVulneravel: base.rodadasVulneravel,
        primeiraBaixadaFeita: base.primeiraBaixadaFeita,
        vez: base.vez,
        mortoPego: base.mortoPego,
        rodadaEncerrada: base.rodadaEncerrada,
        duplaQueBateu: base.duplaQueBateu,
        fase: FaseTurno.mortoPendente,
      );
      final alvo = Jogo.paraCostura();
      aplicarEmJogo(alvo, estadoPendente, EnvelopeRuntime.vazio());
      expect(alvo.jaComprou, isTrue);
    });

    test('C9-MAP-07 round-trip completo mortoPendente -> Jogo -> mortoPendente',
        () {
      final mp = _estadoMortoPendenteC9();
      expect(mp.fase, FaseTurno.mortoPendente); // sanidade do estado de entrada
      final alvo = Jogo.paraCostura();
      aplicarEmJogo(alvo, mp, EnvelopeRuntime.vazio());
      // transporte carrega a fase EXATA (não é perdida como no bug do C9-B);
      expect(alvo.costuraFaseCanonica, 'mortoPendente');
      expect(alvo.jaComprou, isTrue); // coerência legada (comprou)
      final volta = paraCanonico(alvo).canonico;
      expect(volta.fase, FaseTurno.mortoPendente); // preservado EXATO
    });

    test('C9-MAP-08 após round-trip, PegarMorto(viaDescarte:true) segue legal',
        () {
      final mp = _estadoMortoPendenteC9();
      final spec = RuleSpec.canonica(Modalidade.aberto);
      // legal ANTES do round-trip (estado de entrada é válido)
      expect(acaoEhLegal(mp, 0, const PegarMorto(viaDescarte: true), spec),
          isTrue);
      final alvo = Jogo.paraCostura();
      aplicarEmJogo(alvo, mp, EnvelopeRuntime.vazio());
      final volta = paraCanonico(alvo).canonico;
      expect(volta.fase, FaseTurno.mortoPendente);
      // e CONTINUA legal DEPOIS do round-trip pela costura
      expect(acaoEhLegal(volta, 0, const PegarMorto(viaDescarte: true), spec),
          isTrue);
    });

    test('C9-MAP-09 pontosRodada é clone profundo (sem referência compartilhada)',
        () {
      final o = Jogo.paraCostura();
      o.pontosRodada = {
        'detalhe': {'de500': 1}
      };
      final proj = paraCanonico(o);
      // mutar a ORIGEM não afeta o envelope
      (o.pontosRodada!['detalhe'] as Map)['de500'] = 999;
      expect((proj.envelope.pontosRodada!['detalhe'] as Map)['de500'], 1);
      // aplicar em alvo; mutar o ENVELOPE não afeta o alvo
      final alvo = Jogo.paraCostura();
      aplicarEmJogo(alvo, proj.canonico, proj.envelope);
      (proj.envelope.pontosRodada!['detalhe'] as Map)['de500'] = 777;
      expect((alvo.pontosRodada!['detalhe'] as Map)['de500'], 1);
    });

    test('C9-ADAP-CAN-01 AdaptadorCanonico delega às funções canônicas', () {
      const porta = AdaptadorCanonico();
      final e = _estadoCompraC9();
      final spec = RuleSpec.canonica(Modalidade.aberto);
      expect(porta.ehVez(e, 0), ehVezDe(e, 0));
      expect(porta.ehLegal(e, 0, const ComprarMonte(), spec),
          acaoEhLegal(e, 0, const ComprarMonte(), spec));
      expect(porta.acoesLegais(e, 0, spec).length,
          gerarAcoesLegais(e, 0, spec).length);
      final r = porta.aplicar(e, 0, const ComprarMonte(), spec);
      expect(r.legal, aplicarLegal(e, 0, const ComprarMonte(), spec).legal);
      expect(r.legal, isTrue);
    });

    test('C9-ADAP-LEG-01 AdaptadorLegado delega a mesa.dart (ComprarMonte)', () {
      const porta = AdaptadorLegado();
      final e = _estadoCompraC9();
      final spec = RuleSpec.canonica(Modalidade.aberto);
      final r = porta.aplicar(e, 0, const ComprarMonte(), spec);
      expect(r.legal, isTrue);
      expect(r.proximoEstado, isNotNull);
      expect(r.proximoEstado!.maos[0].length, e.maos[0].length + 1);
      expect(r.proximoEstado!.monte.length, e.monte.length - 1);
      expect(porta.ehVez(e, 0), isTrue);
    });

    test('C9-ADAP-LEG-02 AdaptadorLegado — fronteira honesta rotulada (C9-C)',
        () {
      const porta = AdaptadorLegado();
      final e = _estadoCompraC9();
      final spec = RuleSpec.canonica(Modalidade.aberto);
      final acoes = <Acao>[
        const Baixar(jogosNovos: [
          ['h1']
        ]),
        const PegarMorto(),
        const Bater(),
      ];
      for (final acao in acoes) {
        final r = porta.aplicar(e, 0, acao, spec);
        expect(r.legal, isFalse);
        expect(r.motivo, contains('C9-C'));
      }
    });

    test('C9-COMPOSICAO-01 fábrica padrão: OFF=>legado, ON=>canônico', () {
      final fab = fabricaPadrao();
      expect(fab.criar(const MotorConfig()), isA<AdaptadorLegado>());
      expect(fab.criar(const MotorConfig(canonicoAtivo: true)),
          isA<AdaptadorCanonico>());
      expect(portaDoAmbiente(), isA<AdaptadorLegado>());
    });
  });

  // ===================================================================
  // C9-C — modo sombra + comparador. Autoridade OFF; sombra separada da
  // autoridade; execução dupla sem efeito (opera sobre clones). Pipeline:
  // execução dupla -> normalização -> comparação -> classificação
  // (CONVERGE | EXC-01..04 | INESPERADA) -> diff -> Replay (por snapshot).
  // ===================================================================
  group('C9-C — modo sombra + comparador', () {
    const sombra = ModoSombra();

    test('C9-SOMBRA-01 comprarMonte CONVERGE (normaliza + compara)', () {
      final spec = _specAbertoC9C();
      final rel = sombra.comparar(
          _preComprarMonteC9C(), TransacaoSombra.comprarMonte(0, spec));
      expect(rel.classificacao, ClassificacaoSombra.converge);
      expect(rel.diff, isEmpty);
      expect(rel.assinaturaLegado, rel.assinaturaCanonico);
      expect(rel.replayJson, isNull);
    });

    test('C9-SOMBRA-02 descarte normal CONVERGE', () {
      final spec = _specAbertoC9C();
      final rel = sombra.comparar(
          _preDescarteC9C(), TransacaoSombra.descartar(0, 'h2', spec));
      expect(rel.classificacao, ClassificacaoSombra.converge);
      expect(rel.diff, isEmpty);
    });

    test('C9-SOMBRA-03 injeção de divergência -> INESPERADA + diff + Replay',
        () {
      final spec = _specAbertoC9C();
      final rel = sombra.comparar(_preDescarteC9C(), _txInjecaoC9C(spec));
      expect(rel.classificacao, ClassificacaoSombra.inesperada);
      expect(rel.diff, isNotEmpty);
      expect(rel.replayJson, isNotNull);
    });

    test('C9-SOMBRA-04 monte vazio+morto RECONCILIADO -> CONVERGE (C9-C2a)', () {
      // Antes do C9-C2a divergia (legado converte morto->monte; canônico
      // recusava). Com a §8.1 no canônico, ambos convertem e compram -> converge.
      final spec = _specAbertoC9C();
      final rel = sombra.comparar(
          _preMonteVazioMortoC9C(), TransacaoSombra.comprarMonte(0, spec));
      expect(rel.classificacao, ClassificacaoSombra.converge);
      expect(rel.diff, isEmpty);
      expect(rel.replayJson, isNull);
      // C9-C2a-fix: converge SÓ com o envelope relevante também coincidindo.
      expect(rel.envRelevanteLegado['mortosConvertidos'], '1');
      expect(rel.envRelevanteCanonico['mortosConvertidos'], '1');
    });

    test('C9-C2a-MONTE-CONV canônico: monte vazio + morto -> morto vira monte',
        () {
      final spec = _specAbertoC9C();
      final morto = [for (var i = 0; i < 11; i++) _csC9('k$i', 'copas', '3')];
      final est = EstadoJogo(
        modalidade: Modalidade.aberto,
        metaPontos: 1500,
        monte: const <CartaSnapshot>[],
        lixo: const <CartaSnapshot>[],
        mortos: [morto],
        maos: [<CartaSnapshot>[], <CartaSnapshot>[], <CartaSnapshot>[], <CartaSnapshot>[]],
        jogosDupla: {
          'nos': <List<CartaSnapshot>>[],
          'eles': <List<CartaSnapshot>>[]
        },
        rodadasVulneravel: const {'nos': 0, 'eles': 0},
        primeiraBaixadaFeita: const {'nos': false, 'eles': false},
        vez: 0,
        fase: FaseTurno.compra,
      );
      final r = aplicarLegal(est, 0, const ComprarMonte(), spec);
      expect(r.legal, isTrue);
      expect(r.proximoEstado!.mortos.length, 0); // morto consumido
      expect(r.proximoEstado!.monte.length, 10); // 11 - 1 comprada
      expect(r.proximoEstado!.maos[0].length, 1); // comprou 1
      expect(r.proximoEstado!.fase, FaseTurno.jogo);
    });

    test('C9-C2a-fix-ENV mortosConvertidos igual nos dois lados após conversão',
        () {
      final spec = _specAbertoC9C();
      final rel = sombra.comparar(
          _preMonteVazioMortoC9C(), TransacaoSombra.comprarMonte(0, spec));
      expect(rel.envRelevanteLegado['mortosConvertidos'], '1'); // legado +1
      expect(rel.envRelevanteCanonico['mortosConvertidos'], '1'); // transportado
      expect(rel.envRelevanteLegado['mortosConvertidos'],
          rel.envRelevanteCanonico['mortosConvertidos']);
    });

    test('C9-C2a-fix-SCORE consequência: morto convertido mantém a isenção do -100',
        () {
      final spec = RuleSpec.canonica(Modalidade.aberto);
      // dupla NÃO pegou o morto e alguém pegou -> -100, EXCETO se houve conversão.
      final semConv = pontuarRodada(
          const EntradaRodada(
              melds: [],
              mao: [],
              bateu: false,
              mortoPego: false,
              algumPegouMorto: true,
              mortoConvertido: false),
          spec);
      final comConv = pontuarRodada(
          const EntradaRodada(
              melds: [],
              mao: [],
              bateu: false,
              mortoPego: false,
              algumPegouMorto: true,
              mortoConvertido: true),
          spec);
      expect(semConv.total, -100); // penalidade aplicada
      expect(comConv.total, 0); // conversão isenta o -100
    });

    test('C9-C2a-fix-NEG ComprarMonte ilegal (fase jogo): ambos recusam -> CONVERGE, 0 conversões',
        () {
      // Monte vazio + morto disponível, MAS ComprarMonte é ilegal (fase jogo)
      // nos DOIS motores -> estado inalterado dos dois lados -> convergência;
      // e NENHUMA conversão é contada/transportada (a recusa vem antes).
      final spec = _specAbertoC9C();
      final rel = sombra.comparar(_preMonteVazioMortoFaseJogoC9C(),
          TransacaoSombra.comprarMonte(0, spec));
      expect(rel.classificacao, ClassificacaoSombra.converge);
      expect(rel.envRelevanteCanonico['mortosConvertidos'], '0'); // 0 transportadas
      expect(rel.envRelevanteLegado['mortosConvertidos'], '0'); // legado tb recusa
    });

    // ---- C9-C2b: baixar/bater como transações semânticas ----
    test('C9-BAIXAR-01 baixar normal (não esvazia) CONVERGE', () {
      final spec = _specAbertoC9C();
      final rel = sombra.comparar(_preBaixarNormalC9C(),
          TransacaoSombra.baixar(0, const ['3c', '4c', '5c'], spec));
      expect(rel.classificacao, ClassificacaoSombra.converge);
      expect(rel.diff, isEmpty);
    });

    test('C9-BAIXAR-02 baixar inválido: ambos recusam -> CONVERGE (estado intacto)',
        () {
      final spec = _specAbertoC9C();
      // [3,5,7] copas: não é sequência nem trinca -> os dois motores recusam.
      final rel = sombra.comparar(_preBaixarNormalC9C(),
          TransacaoSombra.baixar(0, const ['3c', '5c', '7c'], spec));
      // legalidade EXPLÍCITA: os dois recusaram.
      expect(rel.legadoRecusou, isTrue);
      expect(rel.canonicoRecusou, isTrue);
      expect(rel.classificacao, ClassificacaoSombra.converge);
      expect(rel.diff, isEmpty);
    });

    test('C9-C2b-fix-ASSIM assimetria de legalidade com ESTADO IGUAL -> INESPERADA',
        () {
      // Detector: legado "aplica" sem mudar o estado (dublê) e o canônico RECUSA.
      // Estados finais coincidem, mas a LEGALIDADE diverge -> NÃO pode convergir.
      final spec = _specAbertoC9C();
      final txAssim = TransacaoSombra(
        rotulo: 'assimetria-estado-igual',
        assento: 0,
        spec: spec,
        excEsperada: null,
        aplicarLegado: (j) => true, // dublê: legado "aplicou" sem mutar estado
        acoesCanonicas: (e) => const [Descartar('inexistente')], // canônico recusa
      );
      final rel = sombra.comparar(_preDescarteC9C(), txAssim);
      expect(rel.legadoAplicou, isTrue);
      expect(rel.canonicoAplicou, isFalse);
      // apesar do estado final igual, a assimetria de legalidade é divergência:
      expect(rel.classificacao, ClassificacaoSombra.inesperada);
      expect(rel.replayJson, isNotNull); // Replay completo na assimetria
    });

    // ==================== C9-C2c: EXC reais + classificador verificador ====
    test('C9-C2c-EXHAUSTO monte E mortos vazios RECONCILIADO -> CONVERGE', () {
      // Reconciliação do finding: legado encerra a rodada e retorna false; o
      // canônico agora também ENCERRA a rodada (transição legal de exaustão).
      final spec = _specAbertoC9C();
      final rel = sombra.comparar(
          _preExaustoC9C(), TransacaoSombra.comprarMonte(0, spec));
      expect(rel.classificacao, ClassificacaoSombra.converge);
      expect(rel.diff, isEmpty);
    });

    test('C9-EXC02-REAL abertura múltipla vulnerável: EXC-02 VERIFICADA', () {
      final spec = _specAbertoC9C();
      final rel = sombra.comparar(
          _preEXC02C9C(),
          TransacaoSombra.aberturaMultipla(0, const ['3c', '4c', '5c'],
              const ['6d', '7d', '8d', '9d', '10d', 'Jd', 'Qd'], spec,
              excEsperada: 'EXC-02'));
      expect(rel.legadoAplicou, isFalse); // legado recusa (1º jogo < mínimo)
      expect(rel.canonicoAplicou, isTrue); // canônico aceita (soma ≥ mínimo)
      expect(rel.classificacao, ClassificacaoSombra.excecao);
      expect(rel.idExcecao, 'EXC-02');
    });

    test('C9-EXC02-NAO-DECLARADA condição real de EXC-02 SEM tag -> INESPERADA',
        () {
      // Condição real presente, mas excEsperada=null: NÃO pode ser mascarada.
      final spec = _specAbertoC9C();
      final rel = sombra.comparar(
          _preEXC02C9C(),
          TransacaoSombra.aberturaMultipla(0, const ['3c', '4c', '5c'],
              const ['6d', '7d', '8d', '9d', '10d', 'Jd', 'Qd'], spec));
      expect(rel.classificacao, ClassificacaoSombra.inesperada);
      expect(rel.replayJson, isNotNull);
    });

    test('C9-EXC02-SEM-COND EXC-02 declarada SEM a condição real -> INESPERADA',
        () {
      // Divergência que NÃO é abertura múltipla (descarte h2×h1), tagueada
      // EXC-02: o verificador recusa -> INESPERADA (não vira EXC pela tag).
      final spec = _specAbertoC9C();
      final rel = sombra.comparar(
          _preDescarteC9C(), _txInjecaoC9C(spec, exc: 'EXC-02'));
      expect(rel.classificacao, ClassificacaoSombra.inesperada);
      expect(rel.replayJson, isNotNull);
    });

    test('C9-EXC02-FORMATO-SEM-ECONOMIA formato de abertura múltipla vulnerável '
        '+ assimetria injetada, mas 1º jogo já atinge o mínimo -> INESPERADA',
        () {
      // Detector NEGATIVO do verificador econômico: satisfaz TUDO que o
      // predicado antigo exigia (≥2 jogos, dupla vulnerável abrindo,
      // legado-recusa/canônico-aplica), MAS o 1º jogo SOZINHO já bate o mínimo
      // (75 ≥ 75) — não é a SOMA que salva. Logo NÃO é EXC-02: o verificador
      // recusa e cai em INESPERADA, nunca `excecao`. (Recusa do legado injetada
      // para forçar a assimetria sem depender da economia.)
      final spec = _specAbertoC9C();
      final rel = sombra.comparar(
          _preAberturaJogo1SozinhoC9C(),
          _txAberturaInjetadaC9C(
              const ['8c', '9c', '10c', 'Jc', 'Qc', 'Kc', 'Ac'], // sozinho = 75
              const ['3d', '4d', '5d'], // +15 -> conjunto 90
              spec,
              exc: 'EXC-02'));
      expect(rel.legadoAplicou, isFalse); // recusa injetada
      expect(rel.canonicoAplicou, isTrue); // canônico aplica a abertura atômica
      expect(rel.classificacao, ClassificacaoSombra.inesperada);
      expect(rel.idExcecao, isNull); // não é mascarada como EXC-02
      expect(rel.replayJson, isNotNull); // INESPERADA gera Replay completo
    });

    test('C9-EXC01-RECONC trinca com curinga (Fechado): RECONCILIADA -> CONVERGE',
        () {
      // O legado atual JÁ rejeita trinca com JOKER (igual ao canônico).
      final specF = RuleSpec.canonica(Modalidade.fechado);
      final rel = sombra.comparar(_preEXC01C9C(),
          TransacaoSombra.baixar(0, const ['Qs', 'Qc', 'JK'], specF,
              excEsperada: 'EXC-01'));
      expect(rel.legadoRecusou, isTrue); // ambos recusam
      expect(rel.canonicoRecusou, isTrue);
      expect(rel.classificacao, ClassificacaoSombra.converge);
    });

    test('C9-EXC04-RECONC-FECHADO grupo de ases (Fechado): ambos TRINCA -> CONVERGE',
        () {
      final specF = RuleSpec.canonica(Modalidade.fechado);
      final rel = sombra.comparar(_preEXC04C9C('FECHADO'),
          TransacaoSombra.baixar(0, const ['Ac', 'Ao', 'As'], specF,
              excEsperada: 'EXC-04'));
      expect(rel.legadoAplicou, isTrue); // ambos aceitam como trinca
      expect(rel.canonicoAplicou, isTrue);
      expect(rel.classificacao, ClassificacaoSombra.converge);
    });

    test('C9-EXC04-RECONC-ABERTO grupo de ases (Aberto): ambos RECUSAM -> CONVERGE',
        () {
      final spec = _specAbertoC9C();
      final rel = sombra.comparar(_preEXC04C9C('ABERTO'),
          TransacaoSombra.baixar(0, const ['Ac', 'Ao', 'As'], spec,
              excEsperada: 'EXC-04'));
      expect(rel.legadoRecusou, isTrue); // ambos recusam (ás só em sequência)
      expect(rel.canonicoRecusou, isTrue);
      expect(rel.classificacao, ClassificacaoSombra.converge);
    });

    test('C9-EXC03-FUNC lixo fechado desacoplado: legado RECUSA × canônico ACEITA (nível-função)',
        () {
      // EXC-03 real, mas NÃO dirigível por transação de sombra (o Acao
      // ComprarLixo não carrega jogosNovos). Verificada em nível de FUNÇÃO.
      final specF = RuleSpec.canonica(Modalidade.fechado);
      final j = Jogo.paraCostura();
      j.vez = 0;
      j.jaComprou = false;
      j.modalidade = 'FECHADO';
      j.rodadasVulneravel = {'nos': 1, 'eles': 0};
      j.primeiraBaixadaFeita = {'nos': false, 'eles': false};
      j.monte = [Carta('mo', 'copas', '2', false)];
      j.lixo = [Carta('4c', 'copas', '4', false)]; // topo = 4c
      j.maos = [
        [
          Carta('3c', 'copas', '3', false),
          Carta('5c', 'copas', '5', false),
          Carta('10c', 'copas', '10', false),
          Carta('Jc', 'copas', 'J', false),
          Carta('Qc', 'copas', 'Q', false),
          Carta('Kc', 'copas', 'K', false),
          Carta('10d', 'ouros', '10', false),
          Carta('Jd', 'ouros', 'J', false),
          Carta('Qd', 'ouros', 'Q', false),
          Carta('Kd', 'ouros', 'K', false),
        ],
        <Carta>[],
        <Carta>[],
        <Carta>[],
      ];
      // LEGADO: comprarLixo Fechado exige o meld do TOPO bater o mínimo sozinho.
      final rLeg = j.comprarLixo(0, modalidade: 'FECHADO');
      expect(rLeg['ok'], isFalse); // recusa (topo meld [3,4,5]=15 < 75)
      // CANÔNICO: avaliarComprarLixo desacopla — topo só precisa ter uso; o
      // mínimo é a SOMA de todos os jogos novos (95 ≥ 75).
      final estado = paraCanonico(j).canonico;
      final rCan = avaliarComprarLixo(estado, 0, specF, topoDeclarado: '4c',
          jogosNovos: const [
            ['4c', '3c', '5c'],
            ['10c', 'Jc', 'Qc', 'Kc'],
            ['10d', 'Jd', 'Qd', 'Kd'],
          ]);
      expect(rCan.valido, isTrue); // aceita (desacoplado)
    });

    test('C9-BAIXAR-03 baixar que ESVAZIA -> morto DIRETO (estabilizado) CONVERGE',
        () {
      final spec = _specAbertoC9C();
      final rel = sombra.comparar(_preBaixarEsvaziaMortoC9C(),
          TransacaoSombra.baixar(0, const ['3c', '4c', '5c'], spec));
      expect(rel.classificacao, ClassificacaoSombra.converge);
      expect(rel.diff, isEmpty);
    });

    test('C9-BATER-01 baixar que ESVAZIA com morto pego + canastra -> BATIDA CONVERGE',
        () {
      final spec = _specAbertoC9C();
      final rel = sombra.comparar(_preBaterViaBaixarC9C(),
          TransacaoSombra.baixar(0, const ['Xc', 'Yc', 'Zc'], spec));
      expect(rel.classificacao, ClassificacaoSombra.converge);
      expect(rel.diff, isEmpty);
    });

    test('C9-SOMBRA-05 EXC classificada por condição REAL verificada -> excecao',
        () {
      // Atualizado ao contrato do C9-C2c: a tag conhecida NÃO basta — exige a
      // condição concreta verificada. Usa a abertura múltipla vulnerável real
      // (economia comprovada pelo verificador), que É a única EXC viva
      // dirigível por sombra. Prova a CLASSE `excecao` sem afrouxar o
      // verificador. (C9-EXC02-REAL segue como prova principal da exceção.)
      final spec = _specAbertoC9C();
      final rel = sombra.comparar(
          _preEXC02C9C(),
          TransacaoSombra.aberturaMultipla(0, const ['3c', '4c', '5c'],
              const ['6d', '7d', '8d', '9d', '10d', 'Jd', 'Qd'], spec,
              excEsperada: 'EXC-02'));
      expect(rel.classificacao, ClassificacaoSombra.excecao);
      expect(rel.idExcecao, 'EXC-02');
      expect(rel.replayJson, isNull); // excecao não carrega Replay (só INESPERADA)
    });

    test('C9-SOMBRA-06 EXC id DESCONHECIDO não esconde: continua INESPERADA',
        () {
      final spec = _specAbertoC9C();
      final rel =
          sombra.comparar(_preDescarteC9C(), _txInjecaoC9C(spec, exc: 'EXC-99'));
      expect(rel.classificacao, ClassificacaoSombra.inesperada);
      expect(rel.replayJson, isNotNull);
    });

    test('C9-SOMBRA-07 Replay reproduzível por snapshot', () {
      final spec = _specAbertoC9C();
      final pre = _preDescarteC9C();
      final rel = sombra.comparar(pre, _txInjecaoC9C(spec));
      final rep = Replay.fromJson(rel.replayJson!);
      expect(rep.reproduzivel, isTrue);
      expect(rep.seed, isNull);
      final proj0 = desserializarProjecao(rep.estadoInicialSerializado!);
      expect(proj0.canonico.assinatura(), pre.canonico.assinatura()); // fiel
      EstadoJogo reaplica(EstadoJogo e0) {
        var cur = e0;
        for (final a in rep.acoes) {
          final r = aplicarLegal(cur, cur.vez, a, spec);
          if (r.legal) cur = r.proximoEstado!;
        }
        return cur;
      }
      expect(reaplica(proj0.canonico).assinatura(),
          reaplica(pre.canonico).assinatura());
    });

    test('C9-SOMBRA-08 invariante Replay: seed OU snapshot COMPLETO validável',
        () {
      final snap = serializarProjecao(_preDescarteC9C()); // {canonico, envelope}
      // POSITIVO: snapshot completo -> reproduzível.
      expect(
          Replay(
                  versaoSpec: 'x',
                  modalidade: Modalidade.aberto,
                  estadoInicialSerializado: snap)
              .reproduzivel,
          isTrue);
      // NEGATIVO: snapshot INCOMPLETO (só canônico, sem envelope).
      expect(
          Replay(
                  versaoSpec: 'x',
                  modalidade: Modalidade.aberto,
                  estadoInicialSerializado: {'canonico': snap['canonico']})
              .reproduzivel,
          isFalse);
      // NEGATIVO: mapa arbitrário não conta como snapshot.
      expect(
          Replay(
                  versaoSpec: 'x',
                  modalidade: Modalidade.aberto,
                  estadoInicialSerializado: {'a': 1}).reproduzivel,
          isFalse);
      // seed válida -> reproduzível mesmo sem snapshot.
      expect(
          const Replay(seed: 7, versaoSpec: 'x', modalidade: Modalidade.aberto)
              .reproduzivel,
          isTrue);
    });

    test(
        'C9-SOMBRA-10 Replay de divergência DEPENDENTE do envelope reconstrói e reproduz',
        () {
      final spec = _specAbertoC9C();
      final pre = _preObrigacaoLixoC9C(); // lixoTopoObrigatorio no envelope
      final tx = _txDescartaOutraC9C(spec);
      final rel = sombra.comparar(pre, tx);
      // legado RECUSA (obrigação do topo do lixo); canônico descarta -> divergem.
      expect(rel.classificacao, ClassificacaoSombra.inesperada);
      final rep = Replay.fromJson(rel.replayJson!);
      expect(rep.reproduzivel, isTrue);
      // o ENVELOPE foi persistido no snapshot:
      final proj = desserializarProjecao(rep.estadoInicialSerializado!);
      expect(proj.envelope.lixoTopoObrigatorio, 'topo1');
      // e reproduz a MESMA classificação a partir do snapshot reconstruído
      // (se o envelope tivesse se perdido, o legado não recusaria e mudaria):
      final rel2 = sombra.comparar(proj, tx);
      expect(rel2.classificacao, rel.classificacao);
    });

    test('C9-SOMBRA-09 sombra SEPARADA da autoridade (flag)', () {
      expect(
          sombra.habilitado(
              const MotorConfig(sombraAtiva: true, canonicoAtivo: false)),
          isTrue);
      expect(
          sombra.habilitado(
              const MotorConfig(sombraAtiva: false, canonicoAtivo: true)),
          isFalse);
    });
  });

  // ==================================================================
  // C9-D — AUTORIDADE canônica atrás da flag (troca real de autoridade)
  // ==================================================================
  group('C9-D — autoridade canônica atrás da flag', () {
    String _assin(Jogo j) => paraCanonico(j).canonico.assinatura();
    // Snapshot DETERMINÍSTICO e COMPLETO: estado canônico + EnvelopeRuntime
    // inteiro (cont, lixoUnicoCompradoId, mortosConvertidos, iniciadorRodada,
    // rodadaContada, lixoTopoObrigatorio, integridadeErro, assentoQueBateu,
    // rodada, placar, encerrada, pontosRodada + sidecars). Prova ausência de
    // QUALQUER mutação parcial (estado E envelope) numa só comparação.
    String _snapshotProjecao(Jogo j) =>
        jsonEncode(serializarProjecao(paraCanonico(j)));

    test('C9D-OFF-LEGADO flag OFF: fluxo permanece LEGADO (regressão zero)', () {
      final j = _jgComprarMonteC9D(cfg: const MotorConfig()); // ambas OFF
      final maoAntes = j.maos[0].length;
      final monteAntes = j.monte.length;
      final ok = j.comprarMonte(0);
      expect(ok, isTrue); // legado aplicou
      expect(j.jaComprou, isTrue);
      expect(j.maos[0].length, maoAntes + 1);
      expect(j.monte.length, monteAntes - 1);
      expect(j.ultimoFallbackTecnico, isNull); // autoridade nunca tocada
    });

    test('C9D-ON-CANONICO flag ON: o canônico assume e aplica', () {
      final j = _jgComprarMonteC9D(cfg: const MotorConfig(canonicoAtivo: true));
      final maoAntes = j.maos[0].length;
      final ok = j.comprarMonte(0);
      expect(ok, isTrue); // canônico aplicou (transação atômica)
      expect(j.jaComprou, isTrue); // pós-estado COMMITADO
      expect(j.maos[0].length, maoAntes + 1);
      expect(j.ultimoFallbackTecnico, isNull); // aplicou -> sem fallback
    });

    test('C9D-COMMIT-INTEGRAL o pós-estado commitado É o pós-estado canônico',
        () {
      final j = _jgComprarMonteC9D(cfg: const MotorConfig(canonicoAtivo: true));
      final pre = paraCanonico(j);
      final esperado = aplicarLegal(pre.canonico, 0, const ComprarMonte(),
              RuleSpec.canonica(pre.canonico.modalidade))
          .proximoEstado!;
      j.comprarMonte(0);
      // A assinatura do Jogo após o commit é IDÊNTICA à do estado canônico.
      expect(_assin(j), esperado.assinatura());
    });

    test('C9D-SOMBRA-INDEP sombra ON não liga autoridade por consequência', () {
      // Sombra ON, autoridade OFF + projetor que LANÇARIA se a autoridade fosse
      // (erradamente) acionada. Como a autoridade NÃO é acionada pela sombra, o
      // projetor nunca é chamado e o legado roda normalmente.
      final j = _jgComprarMonteC9D(cfg: const MotorConfig(sombraAtiva: true));
      j.projetorAutoridadeTest = (_) => throw StateError('não deveria rodar');
      final ok = j.comprarMonte(0);
      expect(ok, isTrue); // legado rodou
      expect(j.jaComprou, isTrue);
      expect(j.ultimoFallbackTecnico, isNull); // autoridade jamais tocada
    });

    test('C9D-RECUSA-INTACTO recusa canônica deixa o estado INTACTO', () {
      final j = _jgComprarMonteC9D(cfg: const MotorConfig(canonicoAtivo: true));
      final antes = _assin(j);
      // assento 1 fora da vez -> recusa de REGRA.
      final r = aplicarComAutoridade(j, 1, const [ComprarMonte()]);
      expect(r.recusaCanonica, isTrue);
      expect(r.falhaTecnica, isFalse);
      expect(_assin(j), antes); // nada mudou
    });

    test('C9D-SEM-FALLBACK-SEMANTICO recusa de REGRA NÃO aciona fallback', () {
      final j = _jgComprarMonteC9D(cfg: const MotorConfig(canonicoAtivo: true));
      j.jaComprou = true; // fase jogo -> ComprarMonte é ilegal (recusa de regra)
      final antes = _assin(j);
      final ok = j.comprarMonte(0);
      expect(ok, isFalse); // recusa canônica
      expect(j.ultimoFallbackTecnico, isNull); // legado NÃO foi chamado
      expect(_assin(j), antes); // estado intacto
    });

    test('C9D-FALHA-TECNICA-EVIDENCIA falha de projeção -> técnica + evidência',
        () {
      final j = _jgComprarMonteC9D(cfg: const MotorConfig(canonicoAtivo: true));
      final r = aplicarComAutoridade(j, 0, const [ComprarMonte()],
          projetar: (_) => throw StateError('projeção quebrou'));
      expect(r.falhaTecnica, isTrue);
      expect(r.recusaCanonica, isFalse);
      expect(r.evidencia, isNotNull); // telemetria/diagnóstico presente
      expect(r.evidencia!['falhaTecnica'], 'projecao');
    });

    test('C9D-FALLBACK-TECNICO-ROTEADO falha técnica permite o fallback legado',
        () {
      final j = _jgComprarMonteC9D(cfg: const MotorConfig(canonicoAtivo: true));
      j.projetorAutoridadeTest = (_) => throw StateError('projeção quebrou');
      final maoAntes = j.maos[0].length;
      final ok = j.comprarMonte(0);
      expect(ok, isTrue); // legado rodou (fallback TÉCNICO)
      expect(j.maos[0].length, maoAntes + 1);
      expect(j.ultimoFallbackTecnico, isNotNull); // evidência do fallback
      expect(j.ultimoFallbackTecnico!['metodo'], 'comprarMonte');
      expect(j.ultimoFallbackTecnico!['evidencia'], isNotNull);
    });

    test('C9D-ATOMICIDADE operação composta que recusa não deixa estado parcial',
        () {
      final j = _jgAtomicidadeC9D(cfg: const MotorConfig(canonicoAtivo: true));
      // Prova COMPLETA: snapshot determinístico do estado canônico + do
      // EnvelopeRuntime INTEIRO antes da operação.
      final snapAntes = _snapshotProjecao(j);
      final assinAntes = _assin(j);
      // 1º Baixar VÁLIDO (aplica no snapshot); 2º Baixar INVÁLIDO (recusa) -> a
      // transação inteira é recusada e NADA é commitado.
      final r = aplicarComAutoridade(j, 0, [
        Baixar(jogosNovos: const [
          ['3c', '4c', '5c']
        ]),
        Baixar(jogosNovos: const [
          ['9c', '2s', '7d'] // não forma jogo -> recusa
        ]),
      ]);
      expect(r.recusaCanonica, isTrue);
      // Nenhuma mutação parcial: mão, jogos, lixo, mortos, turno, fase E TODOS
      // os campos do envelope (cont, lixoUnicoCompradoId, mortosConvertidos,
      // iniciadorRodada, rodadaContada, lixoTopoObrigatorio, integridadeErro,
      // assentoQueBateu, rodada, placar, encerrada, pontosRodada) intactos.
      expect(_snapshotProjecao(j), snapAntes);
      // Comparação da assinatura canônica preservada (prova redundante e legível).
      expect(_assin(j), assinAntes);
      expect(j.jogosDupla['nos'], isEmpty); // o 1º jogo NÃO vazou
    });

    test('C9D-ABERTURA-MULTIPLA autoridade exerce a vantagem canônica real', () {
      // Canônico: abertura atômica de 2 jogos que só JUNTOS batem o mínimo 75.
      final jOn = _jgAberturaMultiplaC9D(cfg: const MotorConfig(canonicoAtivo: true));
      final r = aplicarComAutoridade(jOn, 0, [
        Baixar(jogosNovos: const [
          ['3c', '4c', '5c'],
          ['6d', '7d', '8d', '9d', '10d', 'Jd', 'Qd']
        ])
      ]);
      expect(r.aplicou, isTrue); // abertura atômica ACEITA
      expect(jOn.jogosDupla['nos']!.length, 2); // os dois jogos na mesa
      expect(jOn.primeiraBaixadaFeita['nos'], isTrue);
      // Contraste: o legado single-meld NÃO abre com o 1º jogo sozinho (15<75).
      final jLeg = _jgAberturaMultiplaC9D(cfg: const MotorConfig());
      final rLeg = jLeg.baixar(0, ['3c', '4c', '5c']);
      expect(rLeg['ok'], isFalse);
    });

    test('C9D-EXHAUSTO autoridade ON: exaustão encerra a rodada (commitado)', () {
      final j = _jgExaustoC9D(cfg: const MotorConfig(canonicoAtivo: true));
      final ok = j.comprarMonte(0);
      expect(ok, isTrue); // transição legal de exaustão (aplicou)
      expect(j.rodadaEncerrada, isTrue); // encerramento COMMITADO
    });

    test('C9D-CONVERSAO-MORTO autoridade ON: §8.1 converte e conta no envelope',
        () {
      final j = _jgMonteVazioMortoC9D(cfg: const MotorConfig(canonicoAtivo: true));
      final convAntes = j.costuraMortosConvertidos;
      final ok = j.comprarMonte(0);
      expect(ok, isTrue);
      expect(j.costuraMortosConvertidos, convAntes + 1); // paridade de envelope
      expect(j.jaComprou, isTrue);
    });

    test('C9D-MORTO-DIRETO autoridade ON: baixar que esvazia pega o morto DIRETO',
        () {
      final j = _jgBaixarEsvaziaMortoC9D(cfg: const MotorConfig(canonicoAtivo: true));
      final r = j.baixar(0, ['3c', '4c', '5c']); // esvazia -> morto direto
      expect(r['ok'], isTrue);
      expect(j.mortoPego['nos'], isTrue); // morto pego (commitado)
      expect(j.maos[0].isNotEmpty, isTrue); // mão reabastecida pelo morto
    });

    test('C9D-MORTO-INDIRETO autoridade ON: descarte que esvazia pega o INDIRETO',
        () {
      final j = _jgDescarteEsvaziaMortoC9D(cfg: const MotorConfig(canonicoAtivo: true));
      final err = j.descartar(0, 'h1'); // última carta -> morto indireto
      expect(err, isNull);
      expect(j.mortoPego['nos'], isTrue);
      expect(j.maos[0].isNotEmpty, isTrue);
    });

    test('C9D-BATIDA autoridade ON: baixar que esvazia com canastra BATE', () {
      final j = _jgBaterViaBaixarC9D(cfg: const MotorConfig(canonicoAtivo: true));
      final r = j.baixar(0, ['Xc', 'Yc', 'Zc']); // esvazia com morto pego -> batida
      expect(r['ok'], isTrue);
      expect(j.rodadaEncerrada, isTrue);
      expect(j.duplaQueBateu, 'nos');
    });

    test('C9D-ANTI-MASCARAMENTO canônico recusa onde o legado aceitaria', () {
      // OFF: o legado ACEITA comprar o lixo no Fechado (obrigação do topo DIFERIDA).
      final jOff = _jgComprarLixoFechadoC9D(cfg: const MotorConfig());
      final rOff = jOff.comprarLixo(0, modalidade: 'FECHADO');
      expect(rOff['ok'], isTrue); // legado compra o lixo
      expect(jOff.lixo, isEmpty); // lixo recolhido pelo legado
      // ON: o canônico RECUSA (ComprarLixo atômico sem jogos) -> SEM fallback; o
      // legado NÃO é chamado, o estado permanece intacto (nada mascarado).
      final jOn = _jgComprarLixoFechadoC9D(cfg: const MotorConfig(canonicoAtivo: true));
      final lixoAntes = jOn.lixo.length;
      final maoAntes = jOn.maos[0].length;
      final rOn = jOn.comprarLixo(0, modalidade: 'FECHADO');
      expect(rOn['ok'], isFalse); // recusa canônica
      expect(jOn.lixo.length, lixoAntes); // lixo NÃO recolhido (legado não rodou)
      expect(jOn.maos[0].length, maoAntes);
      expect(jOn.ultimoFallbackTecnico, isNull); // recusa de REGRA, não técnica
    });
  });

  // ==================================================================
  // C10 — corte canônico. PARTE 1: contrato ATÔMICO da compra do lixo
  // Fechado/STBL (EXC-03) + auto-derivação + MotorConfig.producao.
  // (Exercita o motor pela AUTORIDADE; o flip do ROOT/pontuação/estender
  // é a PARTE 2.)
  // ==================================================================
  group('C10 — corte canônico (parte 1: contrato do lixo Fechado/STBL)', () {
    String _snap(Jogo j) => jsonEncode(serializarProjecao(paraCanonico(j)));
    final specF = RuleSpec.canonica(Modalidade.fechado);

    test('C10-PROD-01 MotorConfig.producao nasce CANÔNICO e sombra OFF', () {
      final cfg = MotorConfig.producao();
      expect(cfg.canonicoAtivo, isTrue);
      expect(cfg.sombraAtiva, isFalse);
      // rollback explícito continua sendo legado (pré-transação).
      expect(MotorConfig.legadoRollback().canonicoAtivo, isFalse);
    });

    test('C10-LIXO-01 Fechado: topo usado em JOGO NOVO -> compra ATÔMICA aceita',
        () {
      final j = _jgLixoFechadoNovoMeldC10();
      final acao =
          derivarCompraLixoFechado(paraCanonico(j).canonico, 0, specF);
      expect(acao, isNotNull); // auto-derivou [5c,3c,4c]
      final r = aplicarComAutoridade(j, 0, [acao!]);
      expect(r.aplicou, isTrue);
      expect(j.jogosDupla['nos']!.length, 1); // meld baixado atomicamente
      expect(j.lixo, isEmpty); // lixo recolhido
      expect(j.maos[0].any((c) => c.id == '5c'), isFalse); // topo foi à mesa
      expect(j.maos[0].any((c) => c.id == 'ent'), isTrue); // enterrada revelada DEPOIS
      expect(j.jaComprou, isTrue); // fase compra -> jogo
    });

    test('C10-LIXO-02 Fechado: topo usado em EXTENSÃO -> aceita', () {
      final j = _jgLixoFechadoExtensaoC10();
      final acao =
          derivarCompraLixoFechado(paraCanonico(j).canonico, 0, specF);
      expect(acao, isNotNull);
      final r = aplicarComAutoridade(j, 0, [acao!]);
      expect(r.aplicou, isTrue);
      expect(j.jogosDupla['nos']![0].length, 4); // 3-4-5 + 6 (topo)
      expect(j.lixo, isEmpty);
    });

    test('C10-LIXO-03 Fechado: topo SEM uso -> recusa, estado intacto', () {
      final j = _jgLixoFechadoSemUsoC10();
      expect(derivarCompraLixoFechado(paraCanonico(j).canonico, 0, specF),
          isNull);
      final antes = _snap(j);
      final r = aplicarComAutoridade(j, 0, const [ComprarLixo()]);
      expect(r.recusaCanonica, isTrue);
      expect(_snap(j), antes); // lixo/mão/mesa intactos
    });

    test('C10-LIXO-04 carta ENTERRADA não justifica a compra', () {
      final j = _jgLixoFechadoEnterradaC10();
      final antes = _snap(j);
      // declara um jogo usando a carta enterrada 'ent' (4c) -> oculta -> recusa.
      final r = aplicarComAutoridade(j, 0, [
        ComprarLixo(topoDeclarado: 'topo5', jogosNovos: const [
          ['topo5', 'ent', '3c']
        ])
      ]);
      expect(r.recusaCanonica, isTrue);
      expect(_snap(j), antes);
    });

    test('C10-LIXO-05 enterrada não completa o mínimo antes da autorização', () {
      final j = _jgLixoFechadoVulneravelC10();
      // Vulnerável (mínimo 75): topo+2 da mão somam 30 (<75); auto-derive NÃO abre.
      expect(derivarCompraLixoFechado(paraCanonico(j).canonico, 0, specF),
          isNull);
      final antes = _snap(j);
      // tentar completar o mínimo com cartas ENTERRADAS -> ocultas -> recusa.
      final r = aplicarComAutoridade(j, 0, [
        ComprarLixo(topoDeclarado: 'topo10', jogosNovos: const [
          ['topo10', 'Jc', 'Qc', 'entK', 'entA']
        ])
      ]);
      expect(r.recusaCanonica, isTrue);
      expect(_snap(j), antes);
    });

    test('C10-LIXO-06 sucesso move topo/jogo e só DEPOIS revela as enterradas',
        () {
      final j = _jgLixoFechadoNovoMeldC10();
      final idsAntes = j.lixo.map((c) => c.id).toList(); // [ent, 5c]
      final acao =
          derivarCompraLixoFechado(paraCanonico(j).canonico, 0, specF)!;
      aplicarComAutoridade(j, 0, [acao]);
      // topo 5c (id preservado) foi para a MESA no meld; enterrada 'ent' foi para
      // a mão (revelada só após a autorização); IDs físicos conservados.
      final meld = j.jogosDupla['nos']![0].map((c) => c.id).toSet();
      expect(meld.contains('5c'), isTrue);
      expect(meld.contains('ent'), isFalse); // enterrada NÃO entrou no meld
      expect(j.maos[0].any((c) => c.id == 'ent'), isTrue);
      expect(idsAntes.contains('5c') && idsAntes.contains('ent'), isTrue);
    });
  });
}

// C9-A — DUBLÊ REAL da porta (só para os testes de C9-A). Implementação
// concreta mínima e HONESTA: responde com os tipos canônicos do contrato e
// NUNCA lança UnimplementedError. Não reimplementa regra (delega `ehVez` ao
// `ehVezDe` canônico) e não conhece `mesa.dart` nem projeção. `marca` permite
// identificar qual construtor a fábrica devolveu.
class _PortaDupla implements PortaMotor {
  final String marca;
  const _PortaDupla(this.marca);

  @override
  bool ehVez(EstadoJogo estado, int assento) => ehVezDe(estado, assento);

  @override
  List<Acao> acoesLegais(EstadoJogo estado, int assento, RuleSpec spec,
          {List<Acao> candidatos = const []}) =>
      const <Acao>[];

  @override
  bool ehLegal(EstadoJogo estado, int assento, Acao acao, RuleSpec spec) =>
      false;

  @override
  ResultadoJogada aplicar(
          EstadoJogo estado, int assento, Acao acao, RuleSpec spec) =>
      ResultadoJogada.recusa('dublê:$marca');
}

// Estado mínimo e válido só para exercitar a FORMA do contrato no C9-CONTRATO-01
// (não é cenário de regra; o dublê nem consulta o conteúdo).
EstadoJogo _estadoMinimoC9() => const EstadoJogo(
      modalidade: Modalidade.aberto,
      metaPontos: 1500,
      monte: <CartaSnapshot>[],
      lixo: <CartaSnapshot>[],
      mortos: <List<CartaSnapshot>>[],
      maos: <List<CartaSnapshot>>[[], [], [], []],
      jogosDupla: <String, List<List<CartaSnapshot>>>{'nos': [], 'eles': []},
      rodadasVulneravel: <String, int>{'nos': 0, 'eles': 0},
      primeiraBaixadaFeita: <String, bool>{'nos': false, 'eles': false},
      vez: 0,
    );

// ===== C9-B — helpers de teste (projeção/adaptadores) =====

CartaSnapshot _csC9(String id, String? naipe, String valor, [bool cur = false]) =>
    CartaSnapshot(id, naipe, valor, cur);

String _sigCarta(Carta c) => '${c.id}|${c.naipe}|${c.valor}|${c.ehCoringa}';
List<String> _sig(List<Carta> l) => [for (final c in l) _sigCarta(c)];
List<List<String>> _sigM(List<List<Carta>> m) => [for (final l in m) _sig(l)];

// Estado canônico na fase de COMPRA com monte não-vazio (ComprarMonte legal).
EstadoJogo _estadoCompraC9() => EstadoJogo(
      modalidade: Modalidade.aberto,
      metaPontos: 1500,
      monte: [_csC9('m1', 'copas', '7'), _csC9('m2', 'ouros', '8')],
      lixo: [_csC9('l1', 'paus', '3')],
      mortos: [
        [_csC9('d1', 'espadas', 'A')]
      ],
      maos: [
        [_csC9('h1', 'copas', '4')],
        [_csC9('h2', 'ouros', '5')],
        [_csC9('h3', 'paus', '6')],
        [_csC9('h4', 'espadas', '7')],
      ],
      jogosDupla: {
        'nos': <List<CartaSnapshot>>[],
        'eles': <List<CartaSnapshot>>[],
      },
      rodadasVulneravel: {'nos': 0, 'eles': 0},
      primeiraBaixadaFeita: {'nos': false, 'eles': false},
      vez: 0,
      mortoPego: {'nos': false, 'eles': false},
      rodadaEncerrada: false,
      fase: FaseTurno.compra,
    );

// Jogo legado com valor distintivo em CADA campo da matriz (para round-trip).
Jogo _origemRicaC9() {
  final j = Jogo.paraCostura(
    apelidos: ['P0', 'P1', 'P2', 'P3'],
    avatares: ['av0', 'av1', 'av2', 'av3'],
    mascotes: ['ms0', 'ms1', 'ms2', 'ms3'],
  );
  // CANÔNICO
  j.modalidade = 'FECHADO';
  j.metaPontos = 3000;
  j.monte = [Carta('c100', 'copas', '7', false), Carta('c101', null, 'JOKER', true)];
  j.lixo = [Carta('c200', 'ouros', '3', false)];
  j.mortos = [
    [Carta('c300', 'paus', 'A', false)]
  ];
  j.maos = [
    [Carta('c1', 'copas', '4', false)],
    [Carta('c2', 'espadas', 'K', false)],
    <Carta>[],
    [Carta('c3', 'ouros', '2', true)],
  ];
  j.jogosDupla = {
    'nos': [
      [Carta('c400', 'copas', '5', false), Carta('c401', 'copas', '6', false)]
    ],
    'eles': <List<Carta>>[],
  };
  j.rodadasVulneravel = {'nos': 1, 'eles': 0};
  j.primeiraBaixadaFeita = {'nos': true, 'eles': false};
  j.vez = 2;
  j.mortoPego = {'nos': true, 'eles': false};
  j.rodadaEncerrada = false;
  j.duplaQueBateu = null;
  j.jaComprou = true; // DERIVADO -> fase jogo
  // RUNTIME ENVELOPE — públicos
  j.lixoTopoObrigatorio = 'c200';
  j.integridadeErro = null;
  j.assentoQueBateu = null;
  j.rodada = 5;
  j.placar = {'nos': 120, 'eles': 80};
  j.encerrada = false;
  j.pontosRodada = {'x': 1};
  // RUNTIME ENVELOPE — privados (seam)
  j.costuraCont = 42;
  j.costuraLixoUnicoCompradoId = 'c200';
  j.costuraMortosConvertidos = 1;
  j.costuraIniciadorRodada = 2;
  j.costuraRodadaContada = true;
  return j;
}

// Morto com EXATAMENTE 11 cartas (invariante exigido por pegarMorto).
List<CartaSnapshot> _morto11C9() =>
    [for (var i = 0; i < 11; i++) _csC9('mk$i', 'copas', '3')];

// Estado canônico em mortoPendente onde PegarMorto(viaDescarte:true) é legal:
// vez=0 (dupla 'nos'), mão do assento 0 vazia, morto disponível (11), dupla
// ainda não pegou o morto, rodada aberta.
EstadoJogo _estadoMortoPendenteC9() => EstadoJogo(
      modalidade: Modalidade.aberto,
      metaPontos: 1500,
      monte: [_csC9('mo1', 'copas', '7')],
      lixo: [_csC9('lx1', 'ouros', '4')],
      mortos: [_morto11C9()],
      maos: [
        <CartaSnapshot>[],
        [_csC9('b1', 'ouros', '5')],
        [_csC9('c1', 'paus', '6')],
        [_csC9('d1', 'espadas', '7')],
      ],
      jogosDupla: {
        'nos': <List<CartaSnapshot>>[],
        'eles': <List<CartaSnapshot>>[],
      },
      rodadasVulneravel: {'nos': 0, 'eles': 0},
      primeiraBaixadaFeita: {'nos': false, 'eles': false},
      vez: 0,
      mortoPego: {'nos': false, 'eles': false},
      rodadaEncerrada: false,
      fase: FaseTurno.mortoPendente,
    );

// Round-trip: Jogo -> (canônico, envelope) -> Jogo alvo (sidecar via construção).
Jogo _roundTripC9(Jogo origem) {
  final proj = paraCanonico(origem);
  final alvo = Jogo.paraCostura(
    apelidos: proj.envelope.apelidos,
    avatares: proj.envelope.avatares,
    mascotes: proj.envelope.mascotes,
  );
  aplicarEmJogo(alvo, proj.canonico, proj.envelope);
  return alvo;
}

// ===== C9-C — helpers de teste (modo sombra) =====

RuleSpec _specAbertoC9C() => RuleSpec.canonica(Modalidade.aberto);

// Pré-estado: fase compra, monte não-vazio (ComprarMonte legal e convergente).
ProjecaoBMV _preComprarMonteC9C() {
  final j = Jogo.paraCostura();
  j.vez = 0;
  j.jaComprou = false;
  j.modalidade = 'ABERTO';
  j.monte = [Carta('mo1', 'copas', '7', false), Carta('mo2', 'ouros', '8', false)];
  j.maos = [
    [Carta('h1', 'copas', '4', false), Carta('h2', 'paus', '9', false)],
    <Carta>[],
    <Carta>[],
    <Carta>[],
  ];
  j.lixo = [Carta('lx', 'espadas', '3', false)];
  return paraCanonico(j);
}

// Pré-estado: fase jogo, mão com 2 cartas (descarte normal, converge).
ProjecaoBMV _preDescarteC9C() {
  final j = Jogo.paraCostura();
  j.vez = 0;
  j.jaComprou = true;
  j.modalidade = 'ABERTO';
  j.monte = [Carta('mo1', 'copas', '7', false)];
  j.maos = [
    [Carta('h1', 'copas', '4', false), Carta('h2', 'paus', '9', false)],
    <Carta>[],
    <Carta>[],
    <Carta>[],
  ];
  j.lixo = [Carta('lx', 'espadas', '3', false)];
  return paraCanonico(j);
}

// Pré-estado: fase compra, monte VAZIO + morto disponível. Divergência real:
// legado converte morto->monte e compra; canônico RECUSA (monte vazio).
ProjecaoBMV _preMonteVazioMortoC9C() {
  final j = Jogo.paraCostura();
  j.vez = 0;
  j.jaComprou = false;
  j.modalidade = 'ABERTO';
  j.monte = <Carta>[];
  j.mortos = [
    [for (var i = 0; i < 11; i++) Carta('mk$i', 'copas', '3', false)]
  ];
  j.maos = [
    [Carta('h1', 'copas', '4', false), Carta('h2', 'paus', '9', false)],
    <Carta>[],
    <Carta>[],
    <Carta>[],
  ];
  j.lixo = [Carta('lx', 'espadas', '3', false)];
  return paraCanonico(j);
}

// Como _preMonteVazioMortoC9C, mas em fase JOGO (jaComprou=true): ComprarMonte
// é ilegal (fase != compra) tanto no canônico quanto no legado -> 0 conversões.
ProjecaoBMV _preMonteVazioMortoFaseJogoC9C() {
  final j = Jogo.paraCostura();
  j.vez = 0;
  j.jaComprou = true; // fase jogo -> ComprarMonte ilegal
  j.modalidade = 'ABERTO';
  j.monte = <Carta>[];
  j.mortos = [
    [for (var i = 0; i < 11; i++) Carta('mk$i', 'copas', '3', false)]
  ];
  j.maos = [
    [Carta('h1', 'copas', '4', false), Carta('h2', 'paus', '9', false)],
    <Carta>[],
    <Carta>[],
    <Carta>[],
  ];
  j.lixo = [Carta('lx', 'espadas', '3', false)];
  return paraCanonico(j);
}

// Transação injetada: legado descarta 'h2', canônico descarta 'h1' -> divergem.
TransacaoSombra _txInjecaoC9C(RuleSpec spec, {String? exc}) => TransacaoSombra(
      rotulo: 'injecao(descarta h2 legado x h1 canonico)',
      assento: 0,
      spec: spec,
      excEsperada: exc,
      aplicarLegado: (j) => j.descartar(0, 'h2') == null,
      acoesCanonicas: (e) => const [Descartar('h1')],
    );

// Pré-estado cuja DIVERGÊNCIA depende de campo do EnvelopeRuntime:
// lixoTopoObrigatorio='topo1' (em envelope) + 'topo1' na mão. No legado, o
// descarte de 'other' é RECUSADO (tem de usar o topo antes); no canônico (que
// não modela a obrigação) é aceito -> divergem. Só reproduz se o envelope for
// persistido no snapshot do Replay.
ProjecaoBMV _preObrigacaoLixoC9C() {
  final j = Jogo.paraCostura();
  j.vez = 0;
  j.jaComprou = true;
  j.modalidade = 'ABERTO';
  j.monte = [Carta('mo1', 'copas', '7', false)];
  j.maos = [
    [Carta('topo1', 'copas', '5', false), Carta('other', 'paus', '9', false)],
    <Carta>[],
    <Carta>[],
    <Carta>[],
  ];
  j.lixo = [Carta('lx', 'espadas', '3', false)];
  j.lixoTopoObrigatorio = 'topo1';
  return paraCanonico(j);
}

TransacaoSombra _txDescartaOutraC9C(RuleSpec spec) => TransacaoSombra(
      rotulo: 'descartaOutra(obrigacao do topo)',
      assento: 0,
      spec: spec,
      excEsperada: null,
      aplicarLegado: (j) => j.descartar(0, 'other') == null,
      acoesCanonicas: (e) => const [Descartar('other')],
    );

// ===== C9-C2b — helpers de teste (baixar / bater na sombra) =====

// Fase jogo; mão com 3c,4c,5c (sequência) + 7c + Ac. baixar [3,4,5] NÃO esvazia;
// baixar [3,5,7] é inválido (os dois motores recusam). Dupla não vulnerável.
ProjecaoBMV _preBaixarNormalC9C() {
  final j = Jogo.paraCostura();
  j.vez = 0;
  j.jaComprou = true; // fase jogo
  j.modalidade = 'ABERTO';
  j.monte = [Carta('mo1', 'copas', '2', false)];
  j.maos = [
    [
      Carta('3c', 'copas', '3', false),
      Carta('4c', 'copas', '4', false),
      Carta('5c', 'copas', '5', false),
      Carta('7c', 'copas', '7', false),
      Carta('Ac', 'copas', 'A', false),
    ],
    <Carta>[],
    <Carta>[],
    <Carta>[],
  ];
  j.lixo = [Carta('lx', 'espadas', '3', false)];
  return paraCanonico(j);
}

// Fase jogo; mão = EXATAMENTE [3c,4c,5c]. baixar esvazia -> morto DIRETO
// (morto disponível, dupla nos não pegou). Não vulnerável.
ProjecaoBMV _preBaixarEsvaziaMortoC9C() {
  final j = Jogo.paraCostura();
  j.vez = 0;
  j.jaComprou = true;
  j.modalidade = 'ABERTO';
  j.monte = [Carta('mo1', 'copas', '2', false)];
  j.maos = [
    [
      Carta('3c', 'copas', '3', false),
      Carta('4c', 'copas', '4', false),
      Carta('5c', 'copas', '5', false),
    ],
    <Carta>[],
    <Carta>[],
    <Carta>[],
  ];
  j.mortos = [
    [for (var i = 0; i < 11; i++) Carta('mk$i', 'ouros', '3', false)]
  ];
  j.mortoPego = {'nos': false, 'eles': false};
  j.lixo = [Carta('lx', 'espadas', '3', false)];
  return paraCanonico(j);
}

// Fase jogo; dupla nos JÁ pegou o morto e tem uma canastra limpa (7) baixada;
// mão = [Xc,Yc,Zc] (10,J,Q). baixar esvazia -> BATIDA (canastra libera).
ProjecaoBMV _preBaterViaBaixarC9C() {
  final j = Jogo.paraCostura();
  j.vez = 0;
  j.jaComprou = true;
  j.modalidade = 'ABERTO';
  j.monte = [Carta('mo1', 'copas', '2', false)];
  j.maos = [
    [
      Carta('Xc', 'copas', '10', false),
      Carta('Yc', 'copas', 'J', false),
      Carta('Zc', 'copas', 'Q', false),
    ],
    <Carta>[],
    <Carta>[],
    <Carta>[],
  ];
  j.jogosDupla = {
    'nos': [
      [
        Carta('3c', 'copas', '3', false),
        Carta('4c', 'copas', '4', false),
        Carta('5c', 'copas', '5', false),
        Carta('6c', 'copas', '6', false),
        Carta('7c', 'copas', '7', false),
        Carta('8c', 'copas', '8', false),
        Carta('9c', 'copas', '9', false),
      ]
    ],
    'eles': <List<Carta>>[],
  };
  j.mortoPego = {'nos': true, 'eles': false};
  j.primeiraBaixadaFeita = {'nos': true, 'eles': false};
  j.mortos = <List<Carta>>[];
  j.lixo = [Carta('lx', 'espadas', '3', false)];
  return paraCanonico(j);
}

// ===== C9-C2c — helpers de teste (EXC reais + exaustão do baralho) =====

// Baralho EXAURIDO: monte E mortos vazios, fase compra. O legado encerra a
// rodada (comprarMonte -> rodadaEncerrada=true e retorna false, sem comprar); o
// canônico agora TAMBÉM encerra (transição legal de exaustão em ComprarMonte).
// Ambos só escrevem rodadaEncerrada=true -> assinaturas iguais -> CONVERGE.
// (Reconcilia o finding "monte e mortos ambos vazios: legado encerra × canônico
// recusava" do C9-C2.)
ProjecaoBMV _preExaustoC9C() {
  final j = Jogo.paraCostura();
  j.vez = 0;
  j.jaComprou = false; // fase compra
  j.modalidade = 'ABERTO';
  j.monte = <Carta>[];
  j.mortos = <List<Carta>>[];
  j.maos = [
    [Carta('h1', 'copas', '4', false), Carta('h2', 'paus', '9', false)],
    <Carta>[],
    <Carta>[],
    <Carta>[],
  ];
  j.lixo = [Carta('lx', 'espadas', '3', false)];
  return paraCanonico(j);
}

// EXC-02 — ABERTURA MÚLTIPLA. Dupla NOS vulnerável (rodadasVulneravel=1 ->
// mínimo 75) e abrindo (primeiraBaixadaFeita=false). A mão traz DUAS corridas
// legais que só JUNTAS batem o mínimo: [3c,4c,5c] copas = 15 e a corrida de
// ouros 6..Q (7 cartas) = 60 -> soma 75. O legado baixa UM jogo por chamada (o
// 1º sozinho = 15 < 75 -> RECUSA); o canônico soma os dois numa abertura atômica
// -> ACEITA. Assimetria de legalidade real (EXC-02). Duas reservas (Kc, 9p) só
// para a baixada não esvaziar a mão.
ProjecaoBMV _preEXC02C9C() {
  final j = Jogo.paraCostura();
  j.vez = 0;
  j.jaComprou = true; // fase jogo
  j.modalidade = 'ABERTO';
  j.rodadasVulneravel = {'nos': 1, 'eles': 0};
  j.primeiraBaixadaFeita = {'nos': false, 'eles': false};
  j.monte = [Carta('mo1', 'copas', '2', false)];
  j.maos = [
    [
      Carta('3c', 'copas', '3', false),
      Carta('4c', 'copas', '4', false),
      Carta('5c', 'copas', '5', false),
      Carta('6d', 'ouros', '6', false),
      Carta('7d', 'ouros', '7', false),
      Carta('8d', 'ouros', '8', false),
      Carta('9d', 'ouros', '9', false),
      Carta('10d', 'ouros', '10', false),
      Carta('Jd', 'ouros', 'J', false),
      Carta('Qd', 'ouros', 'Q', false),
      Carta('Kc', 'copas', 'K', false), // reserva (não usada nos jogos)
      Carta('9p', 'paus', '9', false), // reserva
    ],
    <Carta>[],
    <Carta>[],
    <Carta>[],
  ];
  j.lixo = [Carta('lx', 'espadas', '3', false)];
  return paraCanonico(j);
}

// EXC-01 — TRINCA COM CURINGA (Fechado). Mão = [Q espadas, Q copas, JOKER] +
// reserva. baixar [Qs,Qc,JK]: o legado ATUAL recusa (Joker fora da trinca; e o
// par de naipes distintos não forma sequência) e o canônico também recusa
// (trinca só natural). Ambos RECUSAM -> estado inalterado -> CONVERGE
// (EXC-01 RECONCILIADA: o legado já não aceita curinga em trinca).
ProjecaoBMV _preEXC01C9C() {
  final j = Jogo.paraCostura();
  j.vez = 0;
  j.jaComprou = true; // fase jogo
  j.modalidade = 'FECHADO';
  j.monte = [Carta('mo1', 'copas', '7', false)];
  j.maos = [
    [
      Carta('Qs', 'espadas', 'Q', false),
      Carta('Qc', 'copas', 'Q', false),
      Carta('JK', null, 'JOKER', true),
      Carta('rp', 'paus', '5', false), // reserva
    ],
    <Carta>[],
    <Carta>[],
    <Carta>[],
  ];
  j.lixo = [Carta('lx', 'espadas', '3', false)];
  return paraCanonico(j);
}

// EXC-04 — GRUPO SÓ DE ASES [Ac,Ao,As]. Dupla NÃO vulnerável (mínimo 0, sem
// interferência de abertura). FECHADO: legado e canônico ACEITAM como TRINCA
// (mesmo meld, mesma ordem de entrada) -> ambos APLICAM -> CONVERGE. ABERTO:
// ambos RECUSAM ("trinca só vale no Fechado; ás só em sequência") -> CONVERGE.
// EXC-04 RECONCILIADA nas duas modalidades. Reservas (Kc, 9p) para a mão não
// esvaziar quando ambos aplicam (Fechado).
ProjecaoBMV _preEXC04C9C(String modalidade) {
  final j = Jogo.paraCostura();
  j.vez = 0;
  j.jaComprou = true; // fase jogo
  j.modalidade = modalidade;
  j.rodadasVulneravel = {'nos': 0, 'eles': 0}; // não vulnerável
  j.primeiraBaixadaFeita = {'nos': false, 'eles': false};
  j.monte = [Carta('mo1', 'copas', '7', false)];
  j.maos = [
    [
      Carta('Ac', 'copas', 'A', false),
      Carta('Ao', 'ouros', 'A', false),
      Carta('As', 'espadas', 'A', false),
      Carta('Kc', 'copas', 'K', false), // reserva
      Carta('9p', 'paus', '9', false), // reserva
    ],
    <Carta>[],
    <Carta>[],
    <Carta>[],
  ];
  j.lixo = [Carta('lx', 'espadas', '3', false)];
  return paraCanonico(j);
}

// Detector NEGATIVO do verificador econômico da EXC-02. Dupla NOS vulnerável
// (mínimo 75) e abrindo, mas a mão traz um 1º jogo que SOZINHO já bate o mínimo:
// a sequência 8..A de copas (7 cartas) = 75, mais [3d,4d,5d] = 15 (conjunto 90).
// Como NÃO é a soma que salva o mínimo, o par recusa/aplica não é EXC-02.
// Reservas (rp, rq) para a baixada canônica não esvaziar a mão.
ProjecaoBMV _preAberturaJogo1SozinhoC9C() {
  final j = Jogo.paraCostura();
  j.vez = 0;
  j.jaComprou = true; // fase jogo
  j.modalidade = 'ABERTO';
  j.rodadasVulneravel = {'nos': 1, 'eles': 0};
  j.primeiraBaixadaFeita = {'nos': false, 'eles': false};
  j.monte = [Carta('mo1', 'copas', '2', false)];
  j.maos = [
    [
      Carta('8c', 'copas', '8', false),
      Carta('9c', 'copas', '9', false),
      Carta('10c', 'copas', '10', false),
      Carta('Jc', 'copas', 'J', false),
      Carta('Qc', 'copas', 'Q', false),
      Carta('Kc', 'copas', 'K', false),
      Carta('Ac', 'copas', 'A', false), // 8..A copas = 75 (sozinho ≥ mínimo)
      Carta('3d', 'ouros', '3', false),
      Carta('4d', 'ouros', '4', false),
      Carta('5d', 'ouros', '5', false),
      Carta('rp', 'paus', '9', false), // reserva
      Carta('rq', 'espadas', '8', false), // reserva
    ],
    <Carta>[],
    <Carta>[],
    <Carta>[],
  ];
  j.lixo = [Carta('lx', 'espadas', '3', false)];
  return paraCanonico(j);
}

// Abertura múltipla com a RECUSA do legado INJETADA — força a assimetria
// (legado recusa / canônico aplica) SEM depender da economia, para o detector
// negativo do verificador. O canônico aplica os dois jogos atômicos.
TransacaoSombra _txAberturaInjetadaC9C(
        List<String> jogo1, List<String> jogo2, RuleSpec spec,
        {String? exc}) =>
    TransacaoSombra(
      rotulo: 'aberturaInjetada(recusaLegadoForcada)@0',
      assento: 0,
      spec: spec,
      excEsperada: exc,
      aplicarLegado: (j) => false, // recusa injetada (assimetria)
      acoesCanonicas: (e) => [
        Baixar(jogosNovos: [jogo1, jogo2])
      ],
    );

// ===== C9-D — helpers: Jogo VIVO com flag de autoridade (motorConfig) =====

// Fase compra, monte não-vazio: ComprarMonte legal e convergente.
Jogo _jgComprarMonteC9D({required MotorConfig cfg}) {
  final j = Jogo.paraCostura(motorConfig: cfg);
  j.vez = 0;
  j.jaComprou = false;
  j.modalidade = 'ABERTO';
  j.monte = [Carta('mo1', 'copas', '7', false), Carta('mo2', 'ouros', '8', false)];
  j.maos = [
    [Carta('h1', 'copas', '4', false), Carta('h2', 'paus', '9', false)],
    <Carta>[],
    <Carta>[],
    <Carta>[],
  ];
  j.lixo = [Carta('lx', 'espadas', '3', false)];
  return j;
}

// Fase jogo; dupla NÃO vulnerável. Mão tem [3c,4c,5c] (jogo válido) + [9c,2s,7d]
// (não forma jogo) + reserva. Para o detector de atomicidade (1º válido, 2º
// inválido -> transação recusada, nada commitado).
Jogo _jgAtomicidadeC9D({required MotorConfig cfg}) {
  final j = Jogo.paraCostura(motorConfig: cfg);
  j.vez = 0;
  j.jaComprou = true;
  j.modalidade = 'ABERTO';
  j.monte = [Carta('mo1', 'copas', '2', false)];
  j.maos = [
    [
      Carta('3c', 'copas', '3', false),
      Carta('4c', 'copas', '4', false),
      Carta('5c', 'copas', '5', false),
      Carta('9c', 'copas', '9', false),
      Carta('2s', 'espadas', '2', true),
      Carta('7d', 'ouros', '7', false),
      Carta('rp', 'paus', 'K', false), // reserva (mão não esvazia)
    ],
    <Carta>[],
    <Carta>[],
    <Carta>[],
  ];
  j.lixo = [Carta('lx', 'espadas', '3', false)];
  return j;
}

// Fase jogo; dupla NOS vulnerável (mínimo 75) abrindo. Duas corridas que só
// JUNTAS batem o mínimo: [3c,4c,5c]=15 + ouros 6..Q=60. Reservas p/ não esvaziar.
Jogo _jgAberturaMultiplaC9D({required MotorConfig cfg}) {
  final j = Jogo.paraCostura(motorConfig: cfg);
  j.vez = 0;
  j.jaComprou = true;
  j.modalidade = 'ABERTO';
  j.rodadasVulneravel = {'nos': 1, 'eles': 0};
  j.primeiraBaixadaFeita = {'nos': false, 'eles': false};
  j.monte = [Carta('mo1', 'copas', '2', false)];
  j.maos = [
    [
      Carta('3c', 'copas', '3', false),
      Carta('4c', 'copas', '4', false),
      Carta('5c', 'copas', '5', false),
      Carta('6d', 'ouros', '6', false),
      Carta('7d', 'ouros', '7', false),
      Carta('8d', 'ouros', '8', false),
      Carta('9d', 'ouros', '9', false),
      Carta('10d', 'ouros', '10', false),
      Carta('Jd', 'ouros', 'J', false),
      Carta('Qd', 'ouros', 'Q', false),
      Carta('Kc', 'copas', 'K', false), // reserva
      Carta('9p', 'paus', '9', false), // reserva
    ],
    <Carta>[],
    <Carta>[],
    <Carta>[],
  ];
  j.lixo = [Carta('lx', 'espadas', '3', false)];
  return j;
}

// Baralho EXAURIDO: monte E mortos vazios, fase compra.
Jogo _jgExaustoC9D({required MotorConfig cfg}) {
  final j = Jogo.paraCostura(motorConfig: cfg);
  j.vez = 0;
  j.jaComprou = false;
  j.modalidade = 'ABERTO';
  j.monte = <Carta>[];
  j.mortos = <List<Carta>>[];
  j.maos = [
    [Carta('h1', 'copas', '4', false), Carta('h2', 'paus', '9', false)],
    <Carta>[],
    <Carta>[],
    <Carta>[],
  ];
  j.lixo = [Carta('lx', 'espadas', '3', false)];
  return j;
}

// Fase compra, monte VAZIO + morto disponível (11): §8.1 converte morto->monte.
Jogo _jgMonteVazioMortoC9D({required MotorConfig cfg}) {
  final j = Jogo.paraCostura(motorConfig: cfg);
  j.vez = 0;
  j.jaComprou = false;
  j.modalidade = 'ABERTO';
  j.monte = <Carta>[];
  j.mortos = [
    [for (var i = 0; i < 11; i++) Carta('mk$i', 'copas', '3', false)]
  ];
  j.maos = [
    [Carta('h1', 'copas', '4', false), Carta('h2', 'paus', '9', false)],
    <Carta>[],
    <Carta>[],
    <Carta>[],
  ];
  j.lixo = [Carta('lx', 'espadas', '3', false)];
  return j;
}

// Fase jogo; mão = EXATAMENTE [3c,4c,5c]. Baixar esvazia -> morto DIRETO
// (morto disponível 11; dupla nos não pegou). Não vulnerável.
Jogo _jgBaixarEsvaziaMortoC9D({required MotorConfig cfg}) {
  final j = Jogo.paraCostura(motorConfig: cfg);
  j.vez = 0;
  j.jaComprou = true;
  j.modalidade = 'ABERTO';
  j.monte = [Carta('mo1', 'copas', '2', false)];
  j.maos = [
    [
      Carta('3c', 'copas', '3', false),
      Carta('4c', 'copas', '4', false),
      Carta('5c', 'copas', '5', false),
    ],
    <Carta>[],
    <Carta>[],
    <Carta>[],
  ];
  j.mortos = [
    [for (var i = 0; i < 11; i++) Carta('mk$i', 'ouros', '3', false)]
  ];
  j.mortoPego = {'nos': false, 'eles': false};
  j.lixo = [Carta('lx', 'espadas', '3', false)];
  return j;
}

// Fase jogo; mão = EXATAMENTE [h1]. Descarte esvazia -> morto INDIRETO
// (morto disponível 11; dupla nos não pegou).
Jogo _jgDescarteEsvaziaMortoC9D({required MotorConfig cfg}) {
  final j = Jogo.paraCostura(motorConfig: cfg);
  j.vez = 0;
  j.jaComprou = true;
  j.modalidade = 'ABERTO';
  j.monte = [Carta('mo1', 'copas', '2', false)];
  j.maos = [
    [Carta('h1', 'copas', '4', false)],
    <Carta>[],
    <Carta>[],
    <Carta>[],
  ];
  j.mortos = [
    [for (var i = 0; i < 11; i++) Carta('mk$i', 'ouros', '3', false)]
  ];
  j.mortoPego = {'nos': false, 'eles': false};
  j.lixo = [Carta('lx', 'espadas', '3', false)];
  return j;
}

// Fase jogo; dupla nos JÁ pegou o morto e tem uma canastra limpa (7) baixada;
// mão = [Xc,Yc,Zc] (10,J,Q). Baixar esvazia -> BATIDA (canastra libera).
Jogo _jgBaterViaBaixarC9D({required MotorConfig cfg}) {
  final j = Jogo.paraCostura(motorConfig: cfg);
  j.vez = 0;
  j.jaComprou = true;
  j.modalidade = 'ABERTO';
  j.monte = [Carta('mo1', 'copas', '2', false)];
  j.maos = [
    [
      Carta('Xc', 'copas', '10', false),
      Carta('Yc', 'copas', 'J', false),
      Carta('Zc', 'copas', 'Q', false),
    ],
    <Carta>[],
    <Carta>[],
    <Carta>[],
  ];
  j.jogosDupla = {
    'nos': [
      [
        Carta('3c', 'copas', '3', false),
        Carta('4c', 'copas', '4', false),
        Carta('5c', 'copas', '5', false),
        Carta('6c', 'copas', '6', false),
        Carta('7c', 'copas', '7', false),
        Carta('8c', 'copas', '8', false),
        Carta('9c', 'copas', '9', false),
      ]
    ],
    'eles': <List<Carta>>[],
  };
  j.mortoPego = {'nos': true, 'eles': false};
  j.primeiraBaixadaFeita = {'nos': true, 'eles': false};
  j.mortos = <List<Carta>>[];
  j.lixo = [Carta('lx', 'espadas', '3', false)];
  return j;
}

// Fase compra, FECHADO. Topo do lixo = 5c; mão tem 3c,4c -> o topo forma
// [5c,3c,4c] (uso imediato) => o LEGADO aceita comprar o lixo (obrigação do topo
// diferida). O canônico ComprarLixo (sem jogos) RECUSA no Fechado.
Jogo _jgComprarLixoFechadoC9D({required MotorConfig cfg}) {
  final j = Jogo.paraCostura(motorConfig: cfg);
  j.vez = 0;
  j.jaComprou = false;
  j.modalidade = 'FECHADO';
  j.monte = [Carta('mo1', 'copas', '7', false)];
  j.maos = [
    [
      Carta('3c', 'copas', '3', false),
      Carta('4c', 'copas', '4', false),
      Carta('k1', 'paus', 'K', false),
    ],
    <Carta>[],
    <Carta>[],
    <Carta>[],
  ];
  j.lixo = [
    Carta('bur', 'ouros', '9', false),
    Carta('5c', 'copas', '5', false), // topo = last
  ];
  return j;
}

// ===== C10 — helpers (parte 1: compra atômica do lixo Fechado/STBL) =====

// Fechado, fase compra. Topo do lixo = 5c; mão tem 3c,4c -> auto-derive [5c,3c,4c].
// Enterrada 'ent' (abaixo do topo) só entra na mão APÓS a autorização.
Jogo _jgLixoFechadoNovoMeldC10() {
  final j = Jogo.paraCostura();
  j.vez = 0;
  j.jaComprou = false;
  j.modalidade = 'FECHADO';
  j.monte = [Carta('mo1', 'copas', '7', false)];
  j.maos = [
    [
      Carta('3c', 'copas', '3', false),
      Carta('4c', 'copas', '4', false),
      Carta('rp', 'paus', 'K', false), // reserva (mão não esvazia)
    ],
    <Carta>[],
    <Carta>[],
    <Carta>[],
  ];
  // topo = last; 'ent' fica ENTERRada (abaixo do topo).
  j.lixo = [Carta('ent', 'ouros', '9', false), Carta('5c', 'copas', '5', false)];
  return j;
}

// Fechado, fase compra. Dupla nos já abriu ([3c,4c,5c]); topo = 6c estende.
Jogo _jgLixoFechadoExtensaoC10() {
  final j = Jogo.paraCostura();
  j.vez = 0;
  j.jaComprou = false;
  j.modalidade = 'FECHADO';
  j.primeiraBaixadaFeita = {'nos': true, 'eles': false};
  j.monte = [Carta('mo1', 'copas', '7', false)];
  j.jogosDupla = {
    'nos': [
      [
        Carta('3c', 'copas', '3', false),
        Carta('4c', 'copas', '4', false),
        Carta('5c', 'copas', '5', false),
      ]
    ],
    'eles': <List<Carta>>[],
  };
  j.maos = [
    [Carta('r1', 'paus', 'K', false), Carta('r2', 'espadas', '8', false)],
    <Carta>[],
    <Carta>[],
    <Carta>[],
  ];
  j.lixo = [Carta('ent', 'ouros', '9', false), Carta('6c', 'copas', '6', false)];
  return j;
}

// Fechado, fase compra. Topo = K paus SEM uso (mão não forma jogo com ele).
Jogo _jgLixoFechadoSemUsoC10() {
  final j = Jogo.paraCostura();
  j.vez = 0;
  j.jaComprou = false;
  j.modalidade = 'FECHADO';
  j.monte = [Carta('mo1', 'copas', '7', false)];
  j.maos = [
    [Carta('3o', 'ouros', '3', false), Carta('8s', 'espadas', '8', false)],
    <Carta>[],
    <Carta>[],
    <Carta>[],
  ];
  j.lixo = [Carta('ent', 'copas', '9', false), Carta('topoK', 'paus', 'K', false)];
  return j;
}

// Fechado, fase compra. O único jogo que usa o topo (5c) precisaria da carta
// ENTERRADA 'ent' (4c) — a mão não tem 4c. Declarar 'ent' -> oculta -> recusa.
Jogo _jgLixoFechadoEnterradaC10() {
  final j = Jogo.paraCostura();
  j.vez = 0;
  j.jaComprou = false;
  j.modalidade = 'FECHADO';
  j.monte = [Carta('mo1', 'copas', '7', false)];
  j.maos = [
    [Carta('3c', 'copas', '3', false), Carta('9s', 'espadas', '9', false)],
    <Carta>[],
    <Carta>[],
    <Carta>[],
  ];
  j.lixo = [Carta('ent', 'copas', '4', false), Carta('topo5', 'copas', '5', false)];
  return j;
}

// Fechado, fase compra, dupla VULNERÁVEL (mínimo 75) abrindo. topo10+Jc+Qc=30<75
// (não abre); cartas ENTERRADAS entK/entA não podem completar o mínimo.
Jogo _jgLixoFechadoVulneravelC10() {
  final j = Jogo.paraCostura();
  j.vez = 0;
  j.jaComprou = false;
  j.modalidade = 'FECHADO';
  j.rodadasVulneravel = {'nos': 1, 'eles': 0};
  j.primeiraBaixadaFeita = {'nos': false, 'eles': false};
  j.monte = [Carta('mo1', 'copas', '7', false)];
  j.maos = [
    [Carta('Jc', 'copas', 'J', false), Carta('Qc', 'copas', 'Q', false)],
    <Carta>[],
    <Carta>[],
    <Carta>[],
  ];
  // topo = topo10 (last); entA/entK ENTERRadas.
  j.lixo = [
    Carta('entA', 'copas', 'A', false),
    Carta('entK', 'copas', 'K', false),
    Carta('topo10', 'copas', '10', false),
  ];
  return j;
}
