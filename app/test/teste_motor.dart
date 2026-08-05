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

    test('C1 Sombra: 3 excecoes versionadas e completas', () {
      expect(excecoesSombra.length, 3);
      expect(excecoesSombra.map((e) => e.id).toList(),
          ['EXC-01', 'EXC-02', 'EXC-03']);
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
}
