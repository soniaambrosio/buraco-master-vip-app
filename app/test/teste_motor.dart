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
import 'dart:math'; // OS ENCERRAMENTO: passeio determinístico da varredura
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
// C10 (rev.1) — derivação fora do isolate de UI.
import 'package:buraco_master_vip/motor/derivacao_fora_do_frame.dart';
// C10 — classificação canônica de meld (usada para auditar a mesa do robô).
import 'package:buraco_master_vip/motor/pontuacao_costura.dart'
    show tipoCanonicoDeMeld;
// OS BOT-IA V1 — camada estratégica do robô (observa -> gera -> pontua ->
// escolhe -> devolve para a autoridade validar/aplicar).
import 'package:buraco_master_vip/bot/executor_bot.dart';
import 'package:buraco_master_vip/bot/gerador_candidatos.dart';
import 'package:buraco_master_vip/bot/pesos.dart';
import 'package:buraco_master_vip/bot/razoes.dart';
import 'package:buraco_master_vip/bot/visao_informacao.dart';
// OS PROVENIÊNCIA DE DESCARTES V1 — o consumidor da autoria pública.
import 'package:buraco_master_vip/bot/modelo_parceiro.dart';

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
  // C10 (rev.1): antes este teste afirmava que a conversão ISENTAVA o -100.
  // A revisão da direção rejeitou a regra: conversão é evento de baralho, não
  // perdão de pontuação. Mesmo cenário, expectativa corrigida.
  test('PONT-09 morto CONVERTIDO em monte NÃO isenta o -100', () {
    final j = novo();
    montar(j, mao0: const [('5', 'copas'), ('K', 'paus')], vez: 0, jaComprou: true);
    j.mortos[0].addAll(j.monte);
    j.monte = [];
    j.auditarIntegridade();
    j.descartar(0, j.maos[0][0].id); // _passarVez converte o morto em monte
    expect(j.costuraMortosConvertidos, greaterThan(0)); // conversão registrada
    j.mortoPego = {'nos': false, 'eles': true};
    expect(fechaEconta(j)['penalidadeMorto'], -100);
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
  // C10 (rev.1): este teste afirmava que a conversão ISENTAVA o -100. A revisão
  // da direção rejeitou essa regra, no canônico e no legado. O cenário é o
  // mesmo; o que mudou é a expectativa.
  test('FLUX-21 conversão do morto NÃO isenta o -100 (fluxo real)', () {
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
    expect((j.pontosRodada!['nos'] as Map)['penalidadeMorto'], -100,
        reason: 'NÓS ficou sem morto — a conversão NÃO perdoa a penalidade');
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
      // C10 (parte 2, revisão de regra): a conversão §8.1 NÃO isenta o -100.
      // Antes daqui `mortoConvertido: true` zerava a penalidade — errado. O
      // campo deixou de existir; a mesma entrada continua pagando.
      final conv = pontuarRodada(
          const EntradaRodada(mortoPego: false, algumPegouMorto: true), aberto);
      expect(conv.penalidadeMorto, 100);
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
        // OS ENCERRAMENTO: sobrar 1 carta só é legal se ela tiver descarte
        // legal. Sem morto e sem canastra, [h3] seria beco e a baixada seria
        // (corretamente) recusada — o teste passaria a medir outra coisa.
        mortos: [
          [for (var i = 0; i < 11; i++) csm('mtT$i', 'ouros', '3')]
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
      // OS ENCERRAMENTO: morto disponível para que sobrar [h3] tenha descarte
      // legal — senão a recusa viria do beco, não da FASE, que é o que se mede.
      final mortoOk = [
        [for (var i = 0; i < 11; i++) csm('mtF$i', 'ouros', '3')]
      ];
      final estJogo =
          estF(fase: FaseTurno.jogo, mao0: maoSeq, mortos: mortoOk);
      final estCompra =
          estF(fase: FaseTurno.compra, mao0: maoSeq, mortos: mortoOk);
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
      // C10 (parte 2, revisão de regra): dupla que NÃO pegou o morto paga -100
      // sempre que alguém pegou. A conversão §8.1 NÃO isenta — ela é evento de
      // baralho (contado no envelope), não perdão de pontuação.
      final semMorto = pontuarRodada(
          const EntradaRodada(
              melds: [],
              mao: [],
              bateu: false,
              mortoPego: false,
              algumPegouMorto: true),
          spec);
      final comMorto = pontuarRodada(
          const EntradaRodada(
              melds: [],
              mao: [],
              bateu: false,
              mortoPego: true,
              algumPegouMorto: true),
          spec);
      expect(semMorto.total, -100); // penalidade aplicada
      expect(comMorto.total, 0); // quem pegou o seu morto não paga
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
      expect(j.ultimaFalhaTecnica, isNull); // autoridade nunca tocada
    });

    test('C9D-ON-CANONICO flag ON: o canônico assume e aplica', () {
      final j = _jgComprarMonteC9D(cfg: const MotorConfig(canonicoAtivo: true));
      final maoAntes = j.maos[0].length;
      final ok = j.comprarMonte(0);
      expect(ok, isTrue); // canônico aplicou (transação atômica)
      expect(j.jaComprou, isTrue); // pós-estado COMMITADO
      expect(j.maos[0].length, maoAntes + 1);
      expect(j.ultimaFalhaTecnica, isNull); // aplicou -> sem fallback
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
      expect(j.ultimaFalhaTecnica, isNull); // autoridade jamais tocada
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
      expect(j.ultimaFalhaTecnica, isNull); // legado NÃO foi chamado
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

    // C10 — contrato REVISTO: sob autoridade única não existe fallback nenhum.
    // A falha TÉCNICA é FAIL-CLOSED: recusa a jogada, deixa o `Jogo` intacto e
    // registra a evidência. O legado NÃO roda (antes do C10 este teste provava
    // exatamente o contrário; a OS C10 mandou ajustá-lo ao contrato novo).
    test('C9D-FALLBACK-TECNICO-ROTEADO falha técnica é FAIL-CLOSED (sem legado)',
        () {
      final j = _jgComprarMonteC9D(cfg: const MotorConfig(canonicoAtivo: true));
      j.projetorAutoridadeTest = (_) => throw StateError('projeção quebrou');
      final maoAntes = j.maos[0].length;
      final monteAntes = j.monte.length;
      final ok = j.comprarMonte(0);
      expect(ok, isFalse); // recusada — o legado NÃO rodou
      expect(j.maos[0].length, maoAntes); // nada entrou na mão
      expect(j.monte.length, monteAntes); // nada saiu do monte
      expect(j.jaComprou, isFalse); // turno não avançou
      expect(j.ultimaFalhaTecnica, isNotNull); // evidência preservada
      expect(j.ultimaFalhaTecnica!['metodo'], 'comprarMonte');
      expect(j.ultimaFalhaTecnica!['evidencia'], isNotNull);
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

    // C10 — contrato REVISTO. No C9-D a `Acao ComprarLixo` não carregava jogos,
    // então no Fechado o canônico só sabia RECUSAR e a prova de anti-mascaramento
    // era a recusa. Com o contrato ATÔMICO da Parte 1 os dois motores ACEITAM a
    // mesma compra — e a divergência REAL passa a ser OUTRA, mais funda: o
    // legado compra PARA A MÃO e DEFERE a obrigação do topo; o canônico só
    // compra com o topo JÁ na mesa, no mesmo commit. É esse diferimento que o
    // §5 proíbe, e é ele que este teste passa a provar.
    test('C9D-ANTI-MASCARAMENTO canônico não DEFERE a obrigação do topo', () {
      // OFF: o legado recolhe o lixo para a mão e deixa a obrigação PENDENTE.
      final jOff = _jgComprarLixoFechadoC9D(cfg: const MotorConfig());
      final rOff = jOff.comprarLixo(0, modalidade: 'FECHADO');
      expect(rOff['ok'], isTrue);
      expect(jOff.lixo, isEmpty); // lixo recolhido
      expect(jOff.jogosDupla['nos'], isEmpty); // NADA foi para a mesa
      expect(jOff.lixoTopoObrigatorio, '5c'); // obrigação DIFERIDA
      expect(jOff.maos[0].any((c) => c.id == '5c'), isTrue); // topo na mão

      // ON: mesma mesa, mesma compra — mas ATÔMICA. O topo vai para a mesa no
      // MESMO commit e não sobra obrigação nenhuma para cobrar depois.
      final jOn =
          _jgComprarLixoFechadoC9D(cfg: const MotorConfig(canonicoAtivo: true));
      final rOn = jOn.comprarLixo(0, modalidade: 'FECHADO');
      expect(rOn['ok'], isTrue);
      expect(jOn.lixo, isEmpty);
      expect(jOn.jogosDupla['nos']!.length, 1); // 3c-4c-5c baixado junto
      expect(jOn.jogosDupla['nos']![0].map((c) => c.id).toSet(),
          {'3c', '4c', '5c'});
      expect(jOn.lixoTopoObrigatorio, isNull); // nada diferido
      expect(jOn.maos[0].any((c) => c.id == '5c'), isFalse); // topo foi à mesa
      expect(jOn.maos[0].any((c) => c.id == 'bur'), isTrue); // enterrada revelada
      expect(jOn.ultimaFalhaTecnica, isNull); // caminho de REGRA, não técnico
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

    // Ids referenciados por TODOS os candidatos (para provar exclusão de enterradas).
    Set<String> _idsDosCandidatos(List<ComprarLixo> cs) {
      final s = <String>{};
      for (final c in cs) {
        for (final j in c.jogosNovos) {
          s.addAll(j);
        }
        for (final e in c.extensoes) {
          s.addAll(e.cartas);
        }
      }
      return s;
    }

    test('C10-LIXO-01 Fechado: topo usado em JOGO NOVO -> compra ATÔMICA aceita',
        () {
      final j = _jgLixoFechadoNovoMeldC10();
      final cands = derivarCandidatosCompraLixoFechado(
          paraCanonico(j).canonico, 0, specF);
      expect(cands.length, 1); // 1 candidato -> executável direto ([5c,3c,4c])
      final r = aplicarComAutoridade(j, 0, [cands.single]);
      expect(r.aplicou, isTrue);
      expect(j.jogosDupla['nos']!.length, 1); // meld baixado atomicamente
      expect(j.lixo, isEmpty); // lixo recolhido
      expect(j.maos[0].any((c) => c.id == '5c'), isFalse); // topo foi à mesa
      expect(j.maos[0].any((c) => c.id == 'ent'), isTrue); // enterrada revelada DEPOIS
      expect(j.jaComprou, isTrue); // fase compra -> jogo
    });

    test('C10-LIXO-02 Fechado: topo usado em EXTENSÃO -> aceita', () {
      final j = _jgLixoFechadoExtensaoC10();
      final cands = derivarCandidatosCompraLixoFechado(
          paraCanonico(j).canonico, 0, specF);
      // topo estende 3-4-5 -> 3-4-5-6 (só há esse uso do topo).
      final ext = cands.firstWhere((c) => c.extensoes.isNotEmpty);
      final r = aplicarComAutoridade(j, 0, [ext]);
      expect(r.aplicou, isTrue);
      expect(j.jogosDupla['nos']![0].length, 4); // 3-4-5 + 6 (topo)
      expect(j.lixo, isEmpty);
    });

    test('C10-LIXO-03 Fechado: topo SEM uso -> 0 candidatos -> recusa, intacto',
        () {
      final j = _jgLixoFechadoSemUsoC10();
      expect(
          derivarCandidatosCompraLixoFechado(paraCanonico(j).canonico, 0, specF),
          isEmpty);
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
      // Vulnerável (mínimo 75): topo+mão somam 30 (<75) e não há meld extra na
      // mão -> 0 candidatos (a abertura não fecha só com o que é visível).
      expect(
          derivarCandidatosCompraLixoFechado(paraCanonico(j).canonico, 0, specF),
          isEmpty);
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
      final cands = derivarCandidatosCompraLixoFechado(
          paraCanonico(j).canonico, 0, specF);
      aplicarComAutoridade(j, 0, [cands.single]);
      final meld = j.jogosDupla['nos']![0].map((c) => c.id).toSet();
      expect(meld.contains('5c'), isTrue); // topo (id preservado) foi à mesa
      expect(meld.contains('ent'), isFalse); // enterrada NÃO entrou no meld
      expect(j.maos[0].any((c) => c.id == 'ent'), isTrue); // revelada só após
      expect(idsAntes.contains('5c') && idsAntes.contains('ent'), isTrue);
    });

    test('C10-LIXO-07 duas alternativas válidas -> 2+ candidatos, sem escolher',
        () {
      final j = _jgLixoDuasAlternativasC10();
      final cands = derivarCandidatosCompraLixoFechado(
          paraCanonico(j).canonico, 0, specF);
      expect(cands.length, greaterThanOrEqualTo(2)); // não colapsa numa só
      // enumera AMBOS os tipos de uso do topo (jogo novo E extensão).
      expect(cands.any((c) => c.jogosNovos.isNotEmpty), isTrue);
      expect(cands.any((c) => c.extensoes.isNotEmpty), isTrue);
      // determinístico e sem duplicatas semânticas: 2ª chamada = mesma lista.
      final cands2 = derivarCandidatosCompraLixoFechado(
          paraCanonico(j).canonico, 0, specF);
      expect(cands2.length, cands.length);
    });

    test('C10-LIXO-08 topo + mão formam meld com >3 cartas -> candidato', () {
      final j = _jgLixoMeldGrandeC10();
      final cands = derivarCandidatosCompraLixoFechado(
          paraCanonico(j).canonico, 0, specF);
      expect(cands.any((c) => c.jogosNovos.any((jn) => jn.length > 3)), isTrue);
    });

    test('C10-LIXO-09 extensão exige topo + outra carta da mão -> candidato', () {
      final j = _jgLixoExtTopoMaisMaoC10();
      final cands = derivarCandidatosCompraLixoFechado(
          paraCanonico(j).canonico, 0, specF);
      // o topo (t7) sozinho não estende (falta o 6c); precisa de topo + 6c.
      expect(
          cands.any((c) => c.extensoes
              .any((e) => e.cartas.length > 1 && e.cartas.contains('t7'))),
          isTrue);
      // e o topo sozinho NÃO forma extensão válida.
      expect(
          cands.any((c) =>
              c.extensoes.any((e) => e.cartas.length == 1 && e.cartas.first == 't7')),
          isFalse);
    });

    test('C10-LIXO-10 abertura vulnerável: 1º meld < mínimo, conjunto >= mínimo',
        () {
      final j = _jgLixoAberturaMultiplaC10();
      final cands = derivarCandidatosCompraLixoFechado(
          paraCanonico(j).canonico, 0, specF);
      // existe candidato ATÔMICO com >=2 jogos (o 1º isolado é <75; a soma >=75).
      final multi = cands.firstWhere((c) => c.jogosNovos.length >= 2);
      final r = aplicarComAutoridade(j, 0, [multi]);
      expect(r.aplicou, isTrue); // compra atômica aceita
      expect(j.jogosDupla['nos']!.length, greaterThanOrEqualTo(2));
      expect(j.lixo, isEmpty);
    });

    test('C10-LIXO-11 nenhuma carta ENTERRADA participa dos candidatos', () {
      final j = _jgLixoAberturaMultiplaC10();
      final cands = derivarCandidatosCompraLixoFechado(
          paraCanonico(j).canonico, 0, specF);
      final ids = _idsDosCandidatos(cands);
      // as enterradas do estado (tudo do lixo menos o topo) não aparecem.
      final topoId = j.lixo.last.id;
      final enterradas =
          j.lixo.where((c) => c.id != topoId).map((c) => c.id).toSet();
      expect(ids.intersection(enterradas), isEmpty);
    });

    test('C10-LIXO-12 round-trip do contrato rico (toJson -> acaoDeJson)', () {
      final rica = ComprarLixo(
        topoDeclarado: 'T',
        jogosNovos: const [
          ['T', 'a', 'b'],
          ['x', 'y', 'z']
        ],
        extensoes: const [
          Extensao(0, ['m', 'n']),
          Extensao(2, ['p'])
        ],
      );
      final volta = acaoDeJson(rica.toJson()) as ComprarLixo;
      expect(volta.topoDeclarado, 'T');
      expect(volta.jogosNovos, rica.jogosNovos);
      expect(volta.extensoes.length, 2);
      expect(volta.extensoes[0].indiceJogo, 0);
      expect(volta.extensoes[0].cartas, ['m', 'n']);
      expect(volta.extensoes[1].indiceJogo, 2);
      expect(volta.extensoes[1].cartas, ['p']);
    });

    test('C10-LIXO-13 jogo novo com 8+ cartas contendo o topo -> derivado/aceito',
        () {
      final j = _jgLixoRunLongoC10();
      final cands = derivarCandidatosCompraLixoFechado(
          paraCanonico(j).canonico, 0, specF);
      // SEM cap de tamanho: existe candidato com um jogo de 8+ cartas (com o topo).
      final grande =
          cands.firstWhere((c) => c.jogosNovos.any((jn) => jn.length >= 8));
      expect(grande.jogosNovos.expand((x) => x), contains('5c')); // topo dentro
      final r = aplicarComAutoridade(j, 0, [grande]);
      expect(r.aplicou, isTrue); // e é aceito pela autoridade
    });

    test('C10-LIXO-14 transação com >3 melds na abertura aparece nos candidatos',
        () {
      final j = _jgLixoQuatroMeldsC10();
      final cands = derivarCandidatosCompraLixoFechado(
          paraCanonico(j).canonico, 0, specF);
      // SEM cap de contagem: há candidato com 4+ jogos numa única compra atômica.
      final multi = cands.firstWhere((c) => c.jogosNovos.length > 3);
      final r = aplicarComAutoridade(j, 0, [multi]);
      expect(r.aplicou, isTrue);
      expect(j.jogosDupla['nos']!.length, greaterThanOrEqualTo(4));
    });

    test('C10-LIXO-15 mais recursos visíveis não elimina candidato legal anterior',
        () {
      // A: mão mínima -> candidato standalone [5c,3c,4c].
      final a = derivarCandidatosCompraLixoFechado(
          paraCanonico(_jgLixoMonoAC10()).canonico, 0, specF);
      final alvo = a.firstWhere((c) =>
          c.extensoes.isEmpty &&
          c.jogosNovos.length == 1 &&
          (List<String>.from(c.jogosNovos.first)..sort()).join('-') ==
              '3c-4c-5c');
      final sigAlvo = (List<String>.from(alvo.jogosNovos.first)..sort()).join('-');
      // B: mesma mão + cartas extras (mais melds possíveis). O candidato de A
      // continua presente (nenhum cap interno o elimina).
      final b = derivarCandidatosCompraLixoFechado(
          paraCanonico(_jgLixoMonoBC10()).canonico, 0, specF);
      final aindaTem = b.any((c) =>
          c.extensoes.isEmpty &&
          c.jogosNovos.length == 1 &&
          (List<String>.from(c.jogosNovos.first)..sort()).join('-') == sigAlvo);
      expect(aindaTem, isTrue);
      expect(b.length, greaterThan(a.length)); // só ACRESCENTA candidatos
    });

    test('C10-LIXO-16 mão grande e ruidosa acha candidato SEM enumerar 2^n', () {
      final estado = paraCanonico(_jgLixoGrandeRuidosoC10()).canonico;
      final n = estado.maos[0].length;
      expect(n, greaterThan(14)); // mão significativamente > 14
      final diag = DiagnosticoLixo();
      final cands =
          derivarCandidatosCompraLixoFechado(estado, 0, specF, diag: diag);
      // candidato legal CONHECIDO ([5c,3c,4c]) continua sendo encontrado.
      expect(
          cands.any((c) =>
              c.extensoes.isEmpty &&
              c.jogosNovos.length == 1 &&
              (List<String>.from(c.jogosNovos.first)..sort()).join('-') ==
                  '3c-4c-5c'),
          isTrue);
      // EVIDÊNCIA estrutural: nós de DFS visitados MUITO abaixo de 2^n — a poda
      // por estrutura de meld (não um cap) evita a explosão. Escala com a mão.
      expect(diag.nosMeld * 16 < (1 << n), isTrue);
      expect(diag.nosMeld, greaterThan(0)); // realmente percorreu
    });

    test('C10-LIXO-17 espaço combinatório grande: determinístico e deduplicado',
        () {
      final estado = paraCanonico(_jgLixoQuatroMeldsC10()).canonico;
      final d1 = DiagnosticoLixo();
      final c1 =
          derivarCandidatosCompraLixoFechado(estado, 0, specF, diag: d1);
      final c2 = derivarCandidatosCompraLixoFechado(estado, 0, specF);
      final s1 = [for (final c in c1) jsonEncode(c.toJson())];
      final s2 = [for (final c in c2) jsonEncode(c.toJson())];
      expect(s2, s1); // MESMA lista, MESMA ordem -> determinístico
      expect(s1.toSet().length, s1.length); // sem duplicatas semânticas
      expect(c1.length, greaterThan(1)); // espaço combinatório real (>1)
      // travessia streaming: nº de nós é finito e sub-exponencial na mão.
      final n = estado.maos[0].length;
      expect(d1.nosMeld * 8 < (1 << n), isTrue);
    });
  });

  // ==================================================================
  // C10 — corte canônico. PARTE 2: PROMOÇÃO DO CONSUMIDOR REAL.
  // A Parte 1 provou o CONTRATO; esta parte prova o FLUXO: a partida
  // local nasce canônica, não existe fallback, `estender` e a pontuação
  // passam pela autoridade, o consumidor consome os candidatos do lixo,
  // e o robô joga sob a mesma autoridade do humano.
  // ==================================================================
  group('C10 — corte canônico (parte 2: promoção do consumidor real)', () {
    String snap(Jogo j) => jsonEncode(serializarProjecao(paraCanonico(j)));

    // ---------- ROOT e rollback ----------

    test('C10-PROD-02 o ROOT da mesa local NASCE em produção (canônico ON)', () {
      // Mesma expressão que `_novoJogo` usa. Sem `motorConfig`, produção.
      const mesa = MesaScreen();
      expect(mesa.motorConfig, isNull); // nenhuma config explícita
      expect(mesa.configEfetivaDoMotor.canonicoAtivo, isTrue);
      expect(mesa.configEfetivaDoMotor.sombraAtiva, isFalse); // sombra OFF
    });

    test('C10-ROLLBACK-01 rollback é CONFIGURAÇÃO explícita e pré-transação',
        () {
      final mesa = MesaScreen(motorConfig: MotorConfig.legadoRollback());
      expect(mesa.configEfetivaDoMotor.canonicoAtivo, isFalse);
      expect(mesa.configEfetivaDoMotor.sombraAtiva, isFalse);
      // E a config é imutável para a partida: o `Jogo` a recebe na CONSTRUÇÃO
      // (campo final), então nenhuma jogada pode trocá-la no meio do caminho.
      final j = Jogo.paraCostura(motorConfig: MotorConfig.producao());
      expect(j.motorConfig.canonicoAtivo, isTrue);
      expect(j.motorConfig, isA<MotorConfig>());
    });

    // ---------- autoridade única: sem fallback de espécie alguma ----------

    test('C10-NO-FALLBACK-01 recusa de REGRA não roda o legado', () {
      // Fechado, topo SEM uso: o legado também recusaria, mas o ponto aqui é
      // que a recusa é canônica e NADA é tocado nem registrado como técnico.
      final j = _jgSemUsoC10();
      final antes = snap(j);
      final r = j.comprarLixo(0, modalidade: 'FECHADO');
      expect(r['ok'], isFalse);
      expect(r['escolhaNecessaria'], isNull);
      expect(snap(j), antes); // estado intacto
      expect(j.ultimaFalhaTecnica, isNull); // regra, não técnica
    });

    test('C10-NO-FALLBACK-03 falha TÉCNICA na compra do MONTE é fail-closed',
        () {
      final j = _jgMonteVazioMortoC10();
      final antes = snap(j);
      final falhasAntes = j.falhasTecnicas;
      j.projetorAutoridadeTest = (_) => throw StateError('projeção quebrou');
      final ok = j.comprarMonte(0);
      j.projetorAutoridadeTest = null;
      expect(ok, isFalse);
      expect(snap(j), antes); // nada convertido, nada comprado
      expect(j.jaComprou, isFalse);
      expect(j.falhasTecnicas, falhasAntes + 1);
      expect(j.ultimaFalhaTecnica!['metodo'], 'comprarMonte');
    });

    test('C10-NO-FALLBACK-04 falha TÉCNICA na compra ATÔMICA do lixo é fail-closed',
        () {
      final j = _jgAtomicoUmC10();
      final cands = j.candidatosCompraLixo(0); // deriva ANTES de injetar a falha
      expect(cands.length, 1);
      final antes = snap(j);
      j.projetorAutoridadeTest = (_) => throw StateError('projeção quebrou');
      final r = j.comprarLixoAtomico(0, cands.single);
      j.projetorAutoridadeTest = null;
      expect(r['ok'], isFalse);
      expect(snap(j), antes); // lixo NÃO recolhido, nada baixado
      expect(j.lixo.length, 2);
      expect(j.jogosDupla['nos'], isEmpty);
      expect(j.ultimaFalhaTecnica!['metodo'], 'comprarLixo');
    });

    test('C10-NO-FALLBACK-02 falha TÉCNICA é fail-closed em TODOS os métodos',
        () {
      for (final caso in <String>['baixar', 'estender', 'descartar']) {
        final j = _jgBaixarEsvaziaMortoC10();
        j.jogosDupla['nos']!.add([
          Carta('e1', 'ouros', '3', false),
          Carta('e2', 'ouros', '4', false),
          Carta('e3', 'ouros', '5', false),
        ]);
        final antes = snap(j);
        j.projetorAutoridadeTest = (_) => throw StateError('projeção quebrou');
        final Object? saida = switch (caso) {
          'baixar' => j.baixar(0, ['3c', '4c', '5c']),
          'estender' => j.estender(0, 0, ['3c']),
          _ => j.descartar(0, '3c'),
        };
        // recusado, com mensagem — e sem NENHUM efeito no estado.
        if (saida is Map) {
          expect(saida['ok'], isFalse, reason: caso);
        } else {
          expect(saida, isNotNull, reason: caso); // descartar devolve o erro
        }
        j.projetorAutoridadeTest = null;
        expect(snap(j), antes, reason: caso);
        expect(j.ultimaFalhaTecnica, isNotNull, reason: caso);
        expect(j.ultimaFalhaTecnica!['metodo'], caso);
        expect(j.ultimaFalhaTecnica!['evidencia'], isNotNull, reason: caso);
      }
    });

    // ---------- compra do lixo: 0 / 1 / 2+ no consumidor real ----------

    test('C10-ATOMIC-01 consumidor real compra o lixo de forma ATÔMICA', () {
      final j = _jgAtomicoUmC10();
      final r = j.comprarLixo(0, modalidade: 'FECHADO'); // 1 candidato -> executa
      expect(r['ok'], isTrue);
      expect(j.lixo, isEmpty); // lixo recolhido
      expect(j.jogosDupla['nos']!.length, 1); // e o topo JÁ está na mesa
      expect(j.jogosDupla['nos']![0].any((c) => c.id == '5c'), isTrue);
      expect(j.lixoTopoObrigatorio, isNull); // nenhuma obrigação diferida
      expect(j.maos[0].any((c) => c.id == 'ent'), isTrue); // enterrada só depois
      expect(j.jaComprou, isTrue);
    });

    test('C10-ATOMIC-02 2+ usos legais: NÃO escolhe pelo jogador', () {
      final j = _jgAtomicoDoisC10();
      final antes = snap(j);
      final r = j.comprarLixo(0, modalidade: 'FECHADO');
      expect(r['ok'], isFalse); // não executou nada
      expect(r['escolhaNecessaria'], isTrue);
      final cands = r['candidatos'] as List<ComprarLixo>;
      expect(cands.length, greaterThanOrEqualTo(2));
      expect(snap(j), antes); // mesa intacta esperando a escolha
      // escolhida UMA, a transação acontece — e é a escolhida.
      final escolha = cands.first;
      expect(j.comprarLixoAtomico(0, escolha)['ok'], isTrue);
      expect(j.lixo, isEmpty);
    });

    test('C10-ATOMIC-03 Aberto continua compra LIVRE (sem uso do topo)', () {
      final j = _jgLixoAbertoC10();
      expect(j.candidatosCompraLixo(0), isEmpty); // Aberto não deriva candidato
      final r = j.comprarLixo(0, modalidade: 'ABERTO');
      expect(r['ok'], isTrue);
      expect(j.lixo, isEmpty);
      expect(j.jogosDupla['nos'], isEmpty); // foi para a MÃO, sem baixar
      expect(j.maos[0].any((c) => c.id == 'topoA'), isTrue);
    });

    // C10 (rev.1) — a derivação combinatória sai do isolate de UI. A entrega
    // anterior alegava isso com `Future(() => ...)`, que só adia a execução no
    // MESMO isolate e não livra frame nenhum. Este teste prova o que a alegação
    // exige: os payloads ATRAVESSAM a fronteira de isolate (`compute`) e voltam
    // com o MESMO resultado da chamada síncrona — sem teto, sem amostragem.
    test('C10-ISOLATE-01 derivações cruzam a fronteira de isolate intactas',
        () async {
      final j = _jgAtomicoUmC10();
      final estado = paraCanonico(j).canonico;
      final sinc = j.candidatosCompraLixo(0);
      final foraDoFrame = await candidatosLixoForaDoFrame(
          ArgsCandidatosLixo(estado, 0, j.specCanonica));
      expect([for (final c in foraDoFrame) jsonEncode(c.toJson())],
          [for (final c in sinc) jsonEncode(c.toJson())]);

      final j2 = _jgSelecaoAmbiguaC10();
      const sel = ['a3', 'a4', 'a5', 'a6', 'a7', 'a8'];
      final pSinc = j2.particoesDaSelecao(0, sel);
      final pFora = await particoesForaDoFrame(
          ArgsParticoes(paraCanonico(j2).canonico, 0, j2.specCanonica, sel));
      expect([for (final p in pFora) jsonEncode(p.toJson())],
          [for (final p in pSinc) jsonEncode(p.toJson())]);
      expect(pFora.length, greaterThanOrEqualTo(2)); // não é um caso trivial
    });

    // ---------- estender e abertura múltipla ----------

    test('C10-ESTENDER-01 estender passa pela autoridade canônica', () {
      final j = _jgEstenderC10();
      final r = j.estender(0, 0, ['6c']);
      expect(r['ok'], isTrue);
      expect(j.jogosDupla['nos']![0].length, 4); // 3-4-5 + 6
      expect(j.maos[0].any((c) => c.id == '6c'), isFalse);
      // extensão ILEGAL é recusada pela MESMA autoridade, sem mutar nada.
      final antes = snap(j);
      expect(j.estender(0, 0, ['kx'])['ok'], isFalse);
      expect(snap(j), antes);
    });

    // C10 (rev.1) — o CONSUMIDOR HUMANO da abertura múltipla. A chamada direta
    // a `baixarAtomico` (ABERTURA-01) provava o motor, não o gesto. Estes
    // provam o caminho que o jogador percorre: seleciona cartas -> a autoridade
    // deriva as partições -> 0 recusa / 1 executa / 2+ escolhe.
    test('C10-ABERTURA-02 seleção de UM meld dá exatamente UMA partição', () {
      // Garante que o gesto de sempre não mudou de comportamento.
      final j = _jgEstenderC10();
      final ps = j.particoesDaSelecao(0, ['9o', '10o', 'Jo']);
      expect(ps.length, 1);
      expect(ps.single.jogosNovos.length, 1);
      final r = j.baixarAtomico(0, jogosNovos: ps.single.jogosNovos);
      expect(r['ok'], isTrue);
      expect(j.jogosDupla['nos']!.length, 2);
    });

    test('C10-ABERTURA-03 consumidor HUMANO abre com vários jogos numa seleção',
        () {
      // Vulnerável (mínimo 75): o jogador seleciona as cartas dos TRÊS jogos e
      // toca no feltro. A autoridade reparte; a abertura sai numa transação só.
      final j = _jgAberturaMultiplaC10();
      final sel = ['3c', '4c', '5c', 'Jo', 'Qo', 'Ko', 'Qe', 'Ke', 'Ae'];
      final ps = j.particoesDaSelecao(0, sel);
      expect(ps, isNotEmpty); // há partição legal
      expect(ps.first.jogosNovos.length, 3); // repartida em três jogos
      final r = j.baixarAtomico(0, jogosNovos: ps.first.jogosNovos);
      expect(r['ok'], isTrue, reason: r['erro']?.toString());
      expect(j.jogosDupla['nos']!.length, 3);
      expect(j.primeiraBaixadaFeita['nos'], isTrue);
      // toda carta selecionada foi usada, e nenhuma outra.
      final naMesa =
          j.jogosDupla['nos']!.expand((m) => m.map((c) => c.id)).toSet();
      expect(naMesa, sel.toSet());
    });

    test('C10-ABERTURA-04 seleção sem partição legal -> 0 -> recusa intacta',
        () {
      final j = _jgAberturaMultiplaC10();
      final antes = snap(j);
      // 3c,4c,Jo não se reparte em jogo nenhum.
      expect(j.particoesDaSelecao(0, ['3c', '4c', 'Jo']), isEmpty);
      expect(j.baixar(0, ['3c', '4c', 'Jo'])['ok'], isFalse);
      expect(snap(j), antes);
    });

    test('C10-ABERTURA-05 seleção ambígua -> 2+ partições, sem autoescolha', () {
      final j = _jgSelecaoAmbiguaC10();
      final ps = j.particoesDaSelecao(0, ['a3', 'a4', 'a5', 'a6', 'a7', 'a8']);
      // 6 cartas em sequência: pode virar UM jogo de 6 ou DOIS de 3.
      expect(ps.length, greaterThanOrEqualTo(2));
      expect(ps.any((p) => p.jogosNovos.length == 1), isTrue);
      expect(ps.any((p) => p.jogosNovos.length == 2), isTrue);
      // determinístico: a mesma seleção devolve a mesma lista, na mesma ordem.
      final s1 = [for (final p in ps) jsonEncode(p.toJson())];
      final s2 = [
        for (final p in j.particoesDaSelecao(0, ['a3', 'a4', 'a5', 'a6', 'a7', 'a8']))
          jsonEncode(p.toJson())
      ];
      expect(s2, s1);
      expect(s1.toSet().length, s1.length); // sem duplicatas (âncora evita permutação)
      // nada foi aplicado só por derivar.
      expect(j.jogosDupla['nos'], isEmpty);
    });

    test('C10-ABERTURA-01 abertura MÚLTIPLA atômica no consumidor real', () {
      // Dupla vulnerável (mínimo 75). Nenhum jogo isolado atinge o mínimo;
      // juntos, sim. O legado baixava um por chamada e recusaria o primeiro.
      final j = _jgAberturaMultiplaC10();
      final isolado = j.baixarAtomico(0, jogosNovos: [
        ['3c', '4c', '5c']
      ]);
      expect(isolado['ok'], isFalse); // 15 pts < 75
      final junto = j.baixarAtomico(0, jogosNovos: [
        ['3c', '4c', '5c'],
        ['Ko', 'Qo', 'Jo'],
        ['Ae', 'Ke', 'Qe'],
      ]);
      expect(junto['ok'], isTrue, reason: junto['erro']?.toString());
      expect(j.jogosDupla['nos']!.length, 3); // os três num commit só
      expect(j.primeiraBaixadaFeita['nos'], isTrue);
    });

    // ---------- pontuação canônica (EXC-04) ----------

    test('C10-SCORE-01 fim de rodada conta pela autoridade canônica', () {
      final j = _jgPontuacaoC10(cfg: MotorConfig.producao());
      j.rodadaEncerrada = true;
      j.duplaQueBateu = 'nos';
      j.contarPontos();
      final nos = (j.pontosRodada!['nos'] as Map).cast<String, dynamic>();
      // canastra limpa 3..9 copas = 200 de bônus + 45 de cartas.
      expect(nos['canastras'], 200);
      expect((nos['detalhe'] as Map)['limpas'], 1);
      expect((nos['detalhe'] as Map)['baixadas'], 45);
      expect(nos['bonusBatida'], 100);
      expect(nos['total'], 200 + 45 + 100);
      expect(j.placar['nos'], 345);
    });

    test('C10-SCORE-02 EXC-04: grupo de ases classificado SÓ pelo canônico',
        () {
      // Fechado: 7 ases é TRINCA para o canônico — nunca canastra, sem bônus,
      // mas as cartas pontuam. Era exatamente aqui que o rótulo divergia
      // (`de_as` do classificador legado × `trinca` do canônico).
      final j = _jgAsesC10(cfg: MotorConfig.producao());
      j.rodadaEncerrada = true;
      j.contarPontos();
      final nos = (j.pontosRodada!['nos'] as Map).cast<String, dynamic>();
      expect(nos['canastras'], 0); // trinca NUNCA é canastra
      final det = nos['detalhe'] as Map;
      expect(det['limpas'], 0);
      expect(det['sujas'], 0);
      expect(det['asAas'], 0);
      expect(det['baixadas'], 7 * 15); // as cartas pontuam normalmente
      // e o placar ao vivo concorda com o fim de rodada (mesma autoridade).
      expect(j.pontosMesaAoVivo('nos'), 7 * 15);
    });

    test('C10-SCORE-03 conversão §8.1 NÃO isenta o -100 de quem ficou sem morto',
        () {
      // Regressão da correção de regra da revisão. ELES pegou o seu morto; o
      // morto de NÓS virou monte pela conversão §8.1. NÓS paga -100 assim mesmo.
      final j = _jgPenalidadeAposConversaoC10(cfg: MotorConfig.producao());
      expect(j.costuraMortosConvertidos, greaterThan(0)); // houve conversão
      j.rodadaEncerrada = true;
      j.duplaQueBateu = 'eles';
      j.contarPontos();
      final nos = (j.pontosRodada!['nos'] as Map).cast<String, dynamic>();
      final eles = (j.pontosRodada!['eles'] as Map).cast<String, dynamic>();
      expect(nos['penalidadeMorto'], -100); // NÃO isento pela conversão
      expect(eles['penalidadeMorto'], 0); // pegou o seu morto
      // e a conversão continua REGISTRADA (só não vale como perdão).
      expect(j.costuraMortosConvertidos, 1);
    });

    // ---------- morto, batida, conversão §8.1, exaustão ----------

    test('C10-MORTO-01 morto DIRETO pelo caminho de produção', () {
      final j = _jgBaixarEsvaziaMortoC10();
      final r = j.baixar(0, ['3c', '4c', '5c']); // zera a mão baixando
      expect(r['ok'], isTrue);
      expect(r['pegouMorto'], isTrue); // o consumidor recebe o feedback
      expect(j.mortoPego['nos'], isTrue);
      expect(j.maos[0].length, 11); // morto na mão
      expect(j.rodadaEncerrada, isFalse);
    });

    test('C10-MORTO-02 morto INDIRETO pelo caminho de produção', () {
      final j = _jgDescarteEsvaziaMortoC10();
      expect(j.descartar(0, 'h1'), isNull); // descarte que zera
      expect(j.mortoPego['nos'], isTrue);
      expect(j.maos[0].length, 11);
      expect(j.rodadaEncerrada, isFalse);
      expect(j.vez, 1); // morto indireto encerra o turno
    });

    test('C10-BATIDA-01 batida pelo caminho de produção', () {
      final j = _jgBaterViaBaixarC10();
      final r = j.baixar(0, ['Xc', 'Yc', 'Zc']);
      expect(r['ok'], isTrue);
      expect(r['bateu'], isTrue); // feedback que a mesa usa para 'Você bateu!'
      expect(j.rodadaEncerrada, isTrue);
      expect(j.duplaQueBateu, 'nos');
    });

    test('C10-CONVERSAO-01 §8.1 converte morto em monte pela produção', () {
      final j = _jgMonteVazioMortoC10();
      final antes = j.costuraMortosConvertidos;
      expect(j.comprarMonte(0), isTrue);
      expect(j.costuraMortosConvertidos, antes + 1); // envelope contou
      expect(j.mortos, isEmpty); // morto virou monte
      expect(j.maos[0].length, 3); // comprou 1
      expect(j.rodadaEncerrada, isFalse);
    });

    test('C10-EXAUSTAO-01 monte E mortos vazios encerram a rodada', () {
      final j = _jgExaustoC10();
      j.comprarMonte(0);
      expect(j.rodadaEncerrada, isTrue);
      expect(j.maos[0].length, 2); // nenhuma carta comprada
      // e a contagem fecha pelo caminho canônico, sem exceção.
      j.contarPontos();
      expect(j.pontosRodada, isNotNull);
    });

    // ---------- robô ----------

    test('C10-BOT-01 robô compra o lixo ATOMICAMENTE, sem obrigação diferida',
        () {
      final j = _jgBotLixoFechadoC10();
      j.botJoga(0);
      expect(j.lixo.isEmpty || j.lixo.length == 1, isTrue); // recolheu e descartou
      expect(j.jogosDupla['nos']!.isNotEmpty, isTrue); // topo foi à mesa
      expect(j.lixoTopoObrigatorio, isNull); // NUNCA nasce sob o canônico
      expect(j.vez, 1); // o turno terminou por descarte, não por atalho
      expect(j.ultimaFalhaTecnica, isNull); // nenhuma rede ilegal acionada
    });

    // C10 (rev.1) — FAIL-CLOSED do robô. Em cada etapa, a falha técnica tem de
    // ENCERRAR o turno: nada de "tenta o monte", "tenta outro grupo", "tenta
    // outra extensão", "varre os outros descartes". A prova é que NENHUMA
    // transação acontece depois da falha — estado idêntico ao de antes.
    test('C10-BOT-FC-01 falha técnica na COMPRA não vira compra do monte', () {
      final j = _jgBotLixoFechadoC10();
      final antes = snap(j);
      final monteAntes = j.monte.length;
      j.projetorAutoridadeTest = (_) => throw StateError('projeção quebrou');
      j.botJoga(0);
      j.projetorAutoridadeTest = null;
      expect(j.ultimaFalhaTecnica, isNotNull);
      expect(j.falhasTecnicas, 1); // UMA falha, não uma cascata
      expect(j.monte.length, monteAntes); // NÃO comprou o monte
      expect(j.jaComprou, isFalse);
      expect(snap(j), antes); // nenhuma transação aconteceu
    });

    test('C10-BOT-FC-02 falha técnica ao BAIXAR não tenta outro grupo', () {
      final j = _jgBotBaixarMuitosGruposC10();
      final antes = snap(j);
      j.projetorAutoridadeTest = (_) => throw StateError('projeção quebrou');
      j.botJoga(0);
      j.projetorAutoridadeTest = null;
      expect(j.ultimaFalhaTecnica, isNotNull);
      expect(j.falhasTecnicas, 1); // parou na PRIMEIRA
      expect(j.jogosDupla['nos'], isEmpty);
      expect(snap(j), antes);
    });

    test('C10-BOT-FC-03 falha técnica ao ESTENDER não tenta outra extensão', () {
      final j = _jgBotEstenderC10();
      final antes = snap(j);
      j.projetorAutoridadeTest = (_) => throw StateError('projeção quebrou');
      j.botJoga(0);
      j.projetorAutoridadeTest = null;
      expect(j.ultimaFalhaTecnica, isNotNull);
      expect(j.falhasTecnicas, 1);
      expect(snap(j), antes);
    });

    test('C10-BOT-FC-04 falha técnica ao DESCARTAR não varre as outras cartas',
        () {
      // A falha é injetada SÓ na hora do descarte: a compra e as baixadas já
      // aconteceram normalmente, então o turno tem estado real antes da falha.
      final j = _jgBotDescarteC10();
      j.botJoga(0); // turno inteiro, sem falha -> descartou e passou a vez
      expect(j.vez, 1);

      final j2 = _jgBotDescarteC10();
      j2.jaComprou = true; // já na fase de jogo: a próxima ação é o descarte
      final maoAntes = j2.maos[0].length;
      j2.projetorAutoridadeTest = (_) => throw StateError('projeção quebrou');
      j2.botJoga(0);
      j2.projetorAutoridadeTest = null;
      expect(j2.ultimaFalhaTecnica, isNotNull);
      expect(j2.falhasTecnicas, 1); // uma tentativa só, não uma por carta
      expect(j2.maos[0].length, maoAntes); // nenhuma carta saiu da mão
      expect(j2.vez, 0); // a vez NÃO passou
    });

    // C10 (rev.2) — FAIL-CLOSED da jogada AUTOMÁTICA por tempo esgotado. A
    // rev.1 corrigiu o robô e esqueceu este caminho: ele varria a mão inteira
    // depois de uma falha técnica e ainda passava a vez como se nada fosse.
    test('C10-AUTO-FC-01 falha técnica no 1º descarte não faz um 2º descarte',
        () {
      final j = _jgBotDescarteC10();
      j.jaComprou = true; // fase de jogo: a próxima ação é o descarte
      final antes = snap(j);
      final maoAntes = j.maos[0].length;
      expect(maoAntes, greaterThan(1)); // há cartas para um 2º descarte existir
      j.projetorAutoridadeTest = (_) => throw StateError('projeção quebrou');
      final concluiu = j.jogadaAutomatica(0);
      j.projetorAutoridadeTest = null;
      expect(concluiu, isFalse); // NÃO fingiu turno concluído
      expect(j.falhasTecnicas, 1); // UMA tentativa, não uma por carta
      expect(j.maos[0].length, maoAntes); // nenhuma carta saiu
      expect(j.vez, 0); // a vez NÃO passou -> os robôs não são acionados
      expect(j.ultimaFalhaTecnica, isNotNull); // evidência preservada
      expect(j.ultimaFalhaTecnica!['metodo'], 'descartar');
      expect(snap(j), antes);
    });

    test('C10-AUTO-FC-02 falha técnica na COMPRA automática não vai ao descarte',
        () {
      final j = _jgBotDescarteC10(); // fase de compra
      final antes = snap(j);
      j.projetorAutoridadeTest = (_) => throw StateError('projeção quebrou');
      final concluiu = j.jogadaAutomatica(0);
      j.projetorAutoridadeTest = null;
      expect(concluiu, isFalse);
      expect(j.falhasTecnicas, 1); // parou na compra
      expect(j.ultimaFalhaTecnica!['metodo'], 'comprarMonte');
      expect(j.jaComprou, isFalse);
      expect(snap(j), antes);
    });

    test('C10-AUTO-01 sem falha, a jogada automática conclui o turno', () {
      final j = _jgBotDescarteC10();
      expect(j.jogadaAutomatica(0), isTrue);
      expect(j.falhasTecnicas, 0);
      expect(j.vez, 1); // comprou e descartou: turno encerrado
    });

    test('C10-AUTO-02 mesa OCUPADA não deixa a jogada automática rodar', () {
      final j = _jgBotDescarteC10();
      j.mesaOcupadaPorDerivacao = true;
      final antes = snap(j);
      expect(j.jogadaAutomatica(0), isFalse);
      expect(j.falhasTecnicas, 0); // não é falha técnica: é a trava
      expect(snap(j), antes);
    });

    // C10 (rev.3) — a PAUSA precisava ser de ESTADO, não de mensagem. Na rev.2
    // `PARTIDA PAUSADA` era só texto: o Timer.periodic seguia vivo com o relógio
    // zerado e o tick seguinte tentava tudo outra vez.
    test('C10-AUTO-PAUSA-01 após a 1ª falha técnica, nenhuma nova tentativa',
        () {
      final j = _jgBotDescarteC10();
      j.jaComprou = true;
      final antes = snap(j);
      j.projetorAutoridadeTest = (_) => throw StateError('projeção quebrou');
      expect(j.jogadaAutomatica(0), isFalse); // 1ª oportunidade: falha
      expect(j.falhasTecnicas, 1);
      expect(j.pausadaPorFalhaTecnica, isTrue);

      // Ticks seguintes do relógio: mais oportunidades, e o projetor CONTINUA
      // quebrado. Se a pausa não fosse real, cada uma somaria outra falha.
      for (var tick = 0; tick < 4; tick++) {
        expect(j.jogadaAutomatica(0), isFalse);
      }
      j.projetorAutoridadeTest = null;
      expect(j.falhasTecnicas, 1); // UMA tentativa, e só
      expect(j.maos[0].length, 3); // nada comprado, nada descartado
      expect(j.vez, 0); // turno não avançou artificialmente
      expect(j.ultimaFalhaTecnica, isNotNull); // evidência preservada
      expect(snap(j), antes);
    });

    test('C10-AUTO-PAUSA-02 a pausa técnica não tranca o jogador', () {
      // Escopo deliberado: a falha foi do piloto automático. O humano segue
      // livre — tentar de novo na mão é decisão dele, não recuperação inventada.
      final j = _jgBotDescarteC10();
      j.jaComprou = true;
      j.pausadaPorFalhaTecnica = true;
      expect(j.jogadaAutomatica(0), isFalse); // automático travado
      expect(j.descartar(0, 'd1'), isNull); // humano passa
      expect(j.vez, 1);
    });

    // C10 (rev.3) — o retorno de `jogadaAutomatica` passou a ser medido pelo
    // ESTADO. Antes bastava chegar ao fim do laço para devolver `true`.
    test('C10-AUTO-CONTRATO-01 todas as cartas recusadas por REGRA -> false',
        () {
      final j = _jgAutoSemDescarteLegalC10();
      final vezAntes = j.vez;
      final antes = snap(j);
      final r = j.jogadaAutomatica(0);
      expect(r, isFalse); // não fingiu turno concluído
      expect(j.falhasTecnicas, 0); // foi recusa de REGRA, não falha técnica
      expect(j.pausadaPorFalhaTecnica, isFalse); // e não pausa a partida
      expect(j.vez, vezAntes); // a vez continua onde estava
      expect(j.rodadaEncerrada, isFalse);
      expect(snap(j), antes); // nenhum descarte inventado
    });

    test('C10-AUTO-CONTRATO-02 turno realmente concluído -> true', () {
      final j = _jgBotDescarteC10();
      final vezAntes = j.vez;
      expect(j.jogadaAutomatica(0), isTrue);
      expect(j.vez, isNot(vezAntes)); // a vez passou de verdade
    });

    test('C10-BOT-03 robô abre com ABERTURA COMPOSTA quando o mínimo exige', () {
      // Vulnerável (mínimo 75): nenhum jogo isolado atinge; a soma sim.
      final j = _jgBotAberturaCompostaC10();
      expect(j.minimoParaDescer('nos'), 75);
      j.botJoga(0);
      expect(j.primeiraBaixadaFeita['nos'], isTrue); // ABRIU
      expect(j.jogosDupla['nos']!.length, greaterThanOrEqualTo(2));
      final pontos = j.jogosDupla['nos']!.fold<int>(
          0, (s, m) => s + m.fold<int>(0, (t, c) => t + pts(c)));
      expect(pontos, greaterThanOrEqualTo(75)); // o mínimo foi atingido na soma
      expect(j.ultimaFalhaTecnica, isNull);
    });

    test('C10-BOT-03-BECO a MESMA abertura, sem morto, não deixa o robô preso',
        () {
      // Este é o caso NOMEADO na OS de encerramento. Fixture idêntico ao do
      // C10-BOT-03, porém sem morto a pegar e sem canastra: a abertura composta
      // de 9 cartas atinge o mínimo, mas deixaria [guard] sem descarte legal.
      //
      // ANTES desta OS: a autoridade ACEITAVA a abertura, o robô ficava com 1
      // carta indescartável, o turno não concluía e a vez não passava.
      // DEPOIS: a abertura é recusada (a dupla simplesmente não abre neste
      // turno) e o robô conclui o turno pelo descarte.
      final j = _jgBotAberturaCompostaBecoC10();
      expect(j.minimoParaDescer('nos'), 75);

      // A abertura que atinge o mínimo é REPROVADA pela autoridade, por deixar
      // o turno sem conclusão legal — e não por causa do mínimo.
      final r = j.baixarAtomico(0, jogosNovos: [
        ['3c', '4c', '5c'],
        ['Jo', 'Qo', 'Ko'],
        ['Qe', 'Ke', 'Ae'],
      ]);
      expect(r['ok'], isFalse);
      expect(j.primeiraBaixadaFeita['nos'], isFalse);

      // E o robô, na mesma mesa, encerra o turno de forma canônica.
      final robo = _jgBotAberturaCompostaBecoC10();
      final marca = robo.falhasTecnicas;
      robo.botJoga(0);
      expect(robo.falhasTecnicas, marca); // sem falha técnica
      expect(robo.pausadaPorFalhaTecnica, isFalse); // sem pausa da partida
      expect(robo.vez != 0 || robo.rodadaEncerrada, isTrue); // a vez andou
      expect(robo.maos[0].length, greaterThan(0)); // não ficou preso com 1 carta
    });

    test('C10-BOT-02 robô só escolhe DENTRO dos candidatos da autoridade', () {
      final j = _jgBotLixoFechadoC10();
      final cands = j.candidatosCompraLixo(0);
      expect(cands, isNotEmpty);
      final assinaturas = {
        for (final c in cands) jsonEncode(c.toJson()),
      };
      j.botJoga(0);
      // o meld que foi à mesa tem que sair de algum candidato legal.
      final naMesa = j.jogosDupla['nos']!
          .expand((m) => m.map((c) => c.id))
          .toSet();
      final algumCandidatoExplica = assinaturas.any((s) {
        final ids = <String>{};
        final m = jsonDecode(s) as Map<String, dynamic>;
        for (final g in (m['jogosNovos'] as List? ?? const [])) {
          ids.addAll((g as List).cast<String>());
        }
        for (final e in (m['extensoes'] as List? ?? const [])) {
          ids.addAll(((e as Map)['cartas'] as List).cast<String>());
        }
        return ids.every(naMesa.contains) && ids.isNotEmpty;
      });
      expect(algumCandidatoExplica, isTrue);
    });

    // C10 (rev.2) — CONCORRÊNCIA: enquanto a mesa está ocupada por uma
    // derivação ou por uma escolha humana pendente, NENHUMA jogada é aceita. A
    // trava mora no MODELO justamente porque a guarda de UI da rev.1 esquecia
    // pontos de entrada — foi assim que `estender` ficou de fora.
    test('C10-OCUPADA-01 extensão NÃO altera mão nem mesa com a mesa ocupada',
        () {
      final j = _jgEstenderC10();
      j.mesaOcupadaPorDerivacao = true; // derivação/seletor em curso
      final antes = snap(j);
      final maoAntes = j.maos[0].length;
      final r = j.estender(0, 0, ['6c']); // seria LEGAL se a mesa estivesse livre
      expect(r['ok'], isFalse);
      expect(r['ocupada'], isTrue);
      expect(j.maos[0].length, maoAntes); // mão intacta
      expect(j.jogosDupla['nos']![0].length, 3); // mesa intacta
      expect(snap(j), antes);
      // liberada, a MESMA extensão passa — a recusa era da trava, não da regra.
      j.mesaOcupadaPorDerivacao = false;
      expect(j.estender(0, 0, ['6c'])['ok'], isTrue);
      expect(j.jogosDupla['nos']![0].length, 4);
    });

    test('C10-OCUPADA-02 TODA entrada mutante respeita a trava', () {
      // Uma por uma, cada porta de entrada da mesa: com a trava ligada, nenhuma
      // muda nada. Se um caminho novo aparecer sem a guarda, este teste cai.
      final j = _jgEstenderC10();
      j.mesaOcupadaPorDerivacao = true;
      final antes = snap(j);
      expect(j.comprarMonte(0), isFalse);
      expect(j.baixar(0, ['9o', '10o', 'Jo'])['ok'], isFalse);
      expect(
          j.baixarAtomico(0, jogosNovos: [
            ['9o', '10o', 'Jo']
          ])['ok'],
          isFalse);
      expect(j.estender(0, 0, ['6c'])['ok'], isFalse);
      expect(j.descartar(0, 'kx'), isNotNull);
      expect(snap(j), antes); // nada mudou em nenhuma das tentativas

      final jl = _jgAtomicoUmC10();
      final cands = jl.candidatosCompraLixo(0);
      jl.mesaOcupadaPorDerivacao = true;
      final antesL = snap(jl);
      expect(jl.comprarLixo(0, modalidade: 'FECHADO')['ok'], isFalse);
      expect(jl.comprarLixoAtomico(0, cands.single)['ok'], isFalse);
      expect(snap(jl), antesL);
    });

    // C10 (rev.3) — a trava de concorrência no ROLLBACK LEGADO.
    //
    // `C10-OCUPADA-01` roda pelo caminho canônico, onde `estender` desce para
    // `baixarAtomico` — que também barra. Ou seja: aquele teste sobrevive à
    // remoção da guarda direta de `Jogo.estender()`, e por isso não a prova.
    // A guarda direta existe pelo LEGADO, onde essa segunda camada não existe.
    // Este teste é o que cai se ela for removida.
    test('C10-OCUPADA-04 rollback LEGADO: extensão barrada pela trava direta',
        () {
      final j = _jgEstenderC10(cfg: MotorConfig.legadoRollback());
      expect(j.motorConfig.canonicoAtivo, isFalse); // é mesmo o legado
      final antes = snap(j);
      final maoAntes = j.maos[0].length;

      j.mesaOcupadaPorDerivacao = true;
      final bloqueada = j.estender(0, 0, ['6c']);
      expect(bloqueada['ok'], isFalse);
      expect(bloqueada['ocupada'], isTrue);
      expect(j.maos[0].length, maoAntes); // mão intacta
      expect(j.jogosDupla['nos']![0].length, 3); // mesa intacta
      expect(snap(j), antes); // snapshot integralmente intacto

      // Liberada, a MESMA extensão passa — pelo caminho legado, provando que a
      // recusa veio da trava e não da regra nem da ausência do canônico.
      j.mesaOcupadaPorDerivacao = false;
      final livre = j.estender(0, 0, ['6c']);
      expect(livre['ok'], isTrue);
      expect(j.jogosDupla['nos']![0].length, 4);
      expect(j.maos[0].length, maoAntes - 1);
    });

    test('C10-OCUPADA-03 derivar NÃO tranca a mesa por si só', () {
      // A trava é de quem CONSOME (o fluxo da tela), não da derivação. Derivar
      // é leitura pura e não pode deixar a mesa presa.
      final j = _jgAtomicoUmC10();
      expect(j.mesaOcupadaPorDerivacao, isFalse);
      j.candidatosCompraLixo(0);
      j.particoesDaSelecao(0, ['3c', '4c', 'rp']);
      expect(j.mesaOcupadaPorDerivacao, isFalse);
      expect(j.comprarLixo(0, modalidade: 'FECHADO')['ok'], isTrue);
    });

    // ---------- contrato que a UI aprovada consome ----------

    test('C10-UI-01 baixada devolve tipo/pegouMorto/bateu à mesa', () {
      // meld curto: 'aberta' -> a mesa NÃO celebra canastra.
      final j = _jgEstenderC10();
      final curto = j.baixarAtomico(0, jogosNovos: [
        ['9o', '10o', 'Jo']
      ]);
      expect(curto['ok'], isTrue, reason: curto['erro']?.toString());
      expect(curto['tipo'], 'aberta');
      expect(curto['bateu'], isNull);
      expect(curto['pegouMorto'], isNull);
      // canastra limpa (7) -> classificação que aciona tarja e som.
      final j2 = _jgCanastraC10();
      final r = j2.baixar(0, ['c1', 'c2', 'c3', 'c4', 'c5', 'c6', 'c7']);
      expect(r['ok'], isTrue, reason: r['erro']?.toString());
      expect(r['tipo'], 'limpa');
    });

    // ---------- rollback legado permanece intacto ----------

    test('C10-LEGACY-01 sob rollback, o legado continua exatamente o legado',
        () {
      final j = _jgComprarLixoFechadoC9D(cfg: MotorConfig.legadoRollback());
      final r = j.comprarLixo(0, modalidade: 'FECHADO');
      expect(r['ok'], isTrue);
      expect(j.jogosDupla['nos'], isEmpty); // legado NÃO baixa junto
      expect(j.lixoTopoObrigatorio, '5c'); // e DEFERE a obrigação
      // baixada atômica não existe fora da autoridade canônica.
      expect(
          j.baixarAtomico(0, jogosNovos: [
            ['3c', '4c', '5c']
          ])['ok'],
          isFalse);
      // e a pontuação legada continua sendo a legada.
      final p = _jgPontuacaoC10(cfg: MotorConfig.legadoRollback());
      p.rodadaEncerrada = true;
      p.duplaQueBateu = 'nos';
      p.contarPontos();
      expect((p.pontosRodada!['nos'] as Map)['canastras'], 200);
    });
  });

  // ===================================================================
  // OS BOT-IA V1 — INTELIGÊNCIA ESTRATÉGICA DO ROBÔ
  //
  // Todos os cenários são DETERMINÍSTICOS (mesa montada à mão, sem sorteio) e
  // rodam sob a autoridade canônica, que é onde o robô estratégico vive. O
  // rollback legado continua com o robô guloso de sempre, de propósito.
  // ===================================================================
  group('OS BOT-IA V1 — inteligência estratégica', () {
    // ---------- §2 política aprovada: curinga não vai ao lixo ----------

    test('BOTIA-01 o bot NÃO descarta 2', () {
      final j = _botBase();
      j.maos[0] = [
        _bc('c2d', '2', 'ouros'),
        _bc('cKc', 'K', 'paus'),
        _bc('c9s', '9', 'espadas'),
        _bc('c4h', '4', 'copas'),
      ];
      final d = _decisaoJogo(j);
      expect(_descarteDe(d), isNot('c2d'));

      j.botJoga(0);
      expect(j.lixo.last.valor, isNot('2'));
      expect(j.maos[0].any((c) => c.id == 'c2d'), isTrue); // o 2 ficou na mão
    });

    test('BOTIA-02 o bot NÃO descarta Joker', () {
      final j = _botBase();
      j.maos[0] = [
        _bc('cjk', 'JOKER', null),
        _bc('cKc', 'K', 'paus'),
        _bc('c9s', '9', 'espadas'),
        _bc('c4h', '4', 'copas'),
      ];
      final d = _decisaoJogo(j);
      expect(_descarteDe(d), isNot('cjk'));

      j.botJoga(0);
      expect(j.lixo.last.valor, isNot('JOKER'));
      expect(j.maos[0].any((c) => c.id == 'cjk'), isTrue);
    });

    // ---------- §2 descarte por dano estrutural ----------

    test('BOTIA-03 entre cartas legais, descarta a de MENOR dano estrutural',
        () {
      // 5h-6h encostam (e o 8h fica a duas casas do 6h); o Kc é peça solta.
      final j = _botBase();
      j.maos[0] = [
        _bc('c5h', '5', 'copas'),
        _bc('c6h', '6', 'copas'),
        _bc('c8h', '8', 'copas'),
        _bc('cKc', 'K', 'paus'),
      ];
      final d = _decisaoJogo(j);
      expect(_descarteDe(d), 'cKc');
      expect(d.features['danoDescarte'], 0.0); // dano ZERO: nada foi quebrado
    });

    // ---------- §1 parceiro ----------

    test('BOTIA-04 preserva carta útil à sequência PÚBLICA do parceiro', () {
      // A dupla tem 4-5-6 de copas na mesa. O 8h ainda não estende (falta o 7),
      // mas é a extensão natural seguinte — e as quatro cartas da mão são, em
      // tudo o mais, indistinguíveis (todas soltas, todas de 10 pontos).
      final d = _decisaoJogo(_fixParceiroAdjacente());
      expect(_descarteDe(d), isNot('c8h'));
      expect(d.features['descarteAdjacenteAoParceiro'], isNull);
    });

    // ---------- §2 adversário ----------

    test('BOTIA-05 evita o descarte que alimenta sequência pública adversária',
        () {
      // Eles têm 10-J-Q de copas. O Kh completa; as outras três são inertes.
      final d = _decisaoJogo(_fixAlimentaAdversario());
      expect(_descarteDe(d), isNot('cKh'));
      expect(d.razoesSecundarias, contains(Razao.descarteSeguro));
    });

    // ---------- §3 curinga ----------

    test('BOTIA-06 NÃO suja canastra limpa por conveniência', () {
      final j = _fixCanastraLimpa();
      final antes = j.jogosDupla['nos']![0].length;
      final d = _decisaoJogo(j);
      expect(d.plano!.baixada, isNull); // nem tenta estender com o curinga

      // A alternativa nem chega a existir: o filtro do §3 a remove da geração.
      final planos = _planosDe(j);
      expect(planos.any((p) => p.sujaJogoLimpo), isFalse);

      j.botJoga(0);
      expect(j.jogosDupla['nos']![0].length, antes); // a limpa ficou intacta
      expect(j.maos[0].any((c) => c.id == 'c2s'), isTrue); // o curinga ficou
    });

    test('BOTIA-07 NÃO gasta curinga quando há caminho natural equivalente',
        () {
      // Vulnerável (mínimo 75). Dois caminhos legais para abrir: um natural de
      // 7 cartas (80 pts) e um de 3 cartas que queima o Joker (75 pts).
      final j = _fixDoisCaminhosDeAbertura();
      expect(j.minimoParaDescer('nos'), 75);
      final d = _decisaoJogo(j);
      expect(d.plano!.baixada, isNotNull);
      expect(_idsDaBaixada(d.plano!.baixada!), isNot(contains('cjk')));
      expect(d.plano!.curingasComprometidos, 0);
      expect(d.razao, Razao.baixaAberturaMinima);
    });

    test('BOTIA-08 USA o curinga quando ele é decisivo para o morto', () {
      final j = _fixCuringaDecisivoMorto();
      final d = _decisaoJogo(j);
      expect(d.plano!.baixada, isNotNull);
      expect(_idsDaBaixada(d.plano!.baixada!), contains('cjk'));
      expect(d.plano!.pegouMorto, isTrue);
      expect(d.razao, Razao.baixaMorto);

      j.botJoga(0);
      expect(j.mortoPego['nos'], isTrue);
    });

    // ---------- §4 não baixar tudo que é legal ----------

    test('BOTIA-09 NÃO baixa automaticamente todo meld legal', () {
      final j = _fixCorridaPromissora();
      // A baixada existe e é legal — o bot é que prefere não fazê-la.
      expect(_planosDe(j).any((p) => p.baixada != null), isTrue);
      final d = _decisaoJogo(j);
      expect(d.plano!.baixada, isNull);
      expect(d.razao, Razao.preservaEstrutura);

      j.botJoga(0);
      expect(j.jogosDupla['nos']!.length, 1); // só o jogo que já estava lá
    });

    test('BOTIA-10 prefere manter estrutura quando baixar gera descarte ruim',
        () {
      // Estender com o 6 de paus consumiria a única carta que dava para largar
      // em segurança; sobrariam só cartas que completam o jogo deles.
      final j = _fixBaixarForcaDescartePerigoso();
      expect(_planosDe(j).any((p) => p.baixada != null), isTrue);
      final d = _decisaoJogo(j);
      expect(d.plano!.baixada, isNull);
    });

    // ---------- §6 parceiro e morto ----------

    test('BOTIA-11 REAVALIA o turno depois de pegar o morto', () {
      final j = _fixMortoDireto();
      j.botJoga(0);
      expect(j.mortoPego['nos'], isTrue); // pegou o morto baixando
      expect(j.maos[0].length, 10); // 11 do morto - 1 descartada
      expect(j.vez, 1); // o turno FECHOU: houve uma segunda decisão
      expect(j.lixo.length, 2);
    });

    test('BOTIA-12 NÃO bate prematuramente prejudicando o parceiro', () {
      final j = _fixBatidaPrematura();
      expect(j.duplaPodeBater('nos'), isTrue); // bater É legal aqui
      j.botJoga(0);
      expect(j.rodadaEncerrada, isFalse); // e mesmo assim não bateu
      expect(j.vez, 1); // encerrou o turno descartando
    });

    // ---------- §4/§13 abertura vulnerável ----------

    test('BOTIA-13 abertura vulnerável escolhe a opção de MENOR dano', () {
      // Duas aberturas legais de 80 pts: espadas+ouros (peças soltas) ou
      // espadas+copas (que quebraria a corrida de seis).
      final j = _fixAberturaComEscolha();
      expect(j.minimoParaDescer('nos'), 75);
      j.botJoga(0);
      expect(j.primeiraBaixadaFeita['nos'], isTrue);
      final naMesa = {
        for (final m in j.jogosDupla['nos']!)
          for (final c in m) c.id
      };
      expect(naMesa.contains('cAd'), isTrue); // abriu com os ouros soltos
      for (final id in const ['c3h', 'c4h', 'c5h', 'c6h', 'c7h', 'c8h']) {
        expect(naMesa.contains(id), isFalse, reason: '$id foi para a mesa');
        expect(j.maos[0].any((c) => c.id == id), isTrue);
      }
    });

    // ---------- princípio arquitetural: subordinação à autoridade ----------

    test('BOTIA-14 nenhuma ação escolhida pelo bot passa fora do RulesEngine',
        () {
      // (a) toda ação que o bot escolhe já é legal para a MESMA autoridade.
      for (final j in <Jogo>[
        _fixParceiroAdjacente(),
        _fixAlimentaAdversario(),
        _fixCanastraLimpa(),
        _fixDoisCaminhosDeAbertura(),
        _fixCuringaDecisivoMorto(),
        _fixCorridaPromissora(),
        _fixBaixarForcaDescartePerigoso(),
        _fixBatidaPrematura(),
      ]) {
        final estado = paraCanonico(j).canonico;
        final d = _decisaoJogo(j);
        var cur = estado;
        for (final a in d.acoes) {
          final r = aplicarLegal(cur, 0, a, j.specCanonica);
          expect(r.legal, isTrue,
              reason: 'ação recusada pela autoridade: ${a.toJson()}');
          cur = r.proximoEstado!;
        }
      }

      // (b) uma INTENÇÃO forjada (meld ilegal) submetida pela mesma porta do
      // bot é recusada, e o estado fica intacto. Querer não basta.
      final j = _fixCorridaPromissora();
      final antes = _snapJogo(j);
      final forjada = j.baixarAtomico(0, jogosNovos: [
        ['c5h', 'c6h', 'c8h'] // buraco no 7: não é sequência
      ]);
      expect(forjada['ok'], isFalse);
      expect(j.falhasTecnicas, 0); // recusa de REGRA, não falha técnica
      expect(_snapJogo(j), antes);
    });

    // ---------- §7 informação justa ----------

    test('BOTIA-15 informação OCULTA não entra na visão nem muda a decisão',
        () {
      final a = _fixInformacaoJusta(variante: 0);
      final b = _fixInformacaoJusta(variante: 1);

      // (a) estrutural: a visão não carrega NADA das zonas ocultas.
      final visao = VisaoInformacao.doEstado(paraCanonico(a).canonico, 0);
      final proibidos = <String>{
        for (var s = 1; s < 4; s++) ...[for (final c in a.maos[s]) c.id],
        for (final c in a.monte) c.id,
        for (final m in a.mortos) ...[for (final c in m) c.id],
        // cartas ENTERRADAS do lixo (tudo menos o topo visível)
        ...[for (final c in a.lixo.sublist(0, a.lixo.length - 1)) c.id],
      };
      final naVisao = <String>{
        for (final c in visao.mao) c.id,
        for (final m in visao.meldsProprios) ...[for (final c in m) c.id],
        for (final m in visao.meldsAdversarios) ...[for (final c in m) c.id],
        if (visao.lixoTopo != null) visao.lixoTopo!.id,
      };
      expect(naVisao.intersection(proibidos), isEmpty);

      // (b) comportamental: mudar TODO o oculto não move a decisão.
      final da = _decisaoJogo(a);
      final db = _decisaoJogo(b);
      expect(jsonEncode([for (final x in db.acoes) x.toJson()]),
          jsonEncode([for (final x in da.acoes) x.toJson()]));
      expect(db.razao, da.razao);
      expect(db.score, da.score);
    });

    // ---------- §8 determinismo e auditabilidade ----------

    test('BOTIA-16 mesmo estado público + config + seed = mesma decisão', () {
      final d1 = _decisaoJogo(_fixInformacaoJusta(variante: 0));
      final d2 = _decisaoJogo(_fixInformacaoJusta(variante: 0));
      expect(d2.assinaturaDecisao, d1.assinaturaDecisao);
      expect(jsonEncode(d2.toJson()), jsonEncode(d1.toJson()));

      // Decidir DUAS vezes sobre a mesma mesa também não pode variar.
      final j = _fixCorridaPromissora();
      expect(jsonEncode(_decisaoJogo(j).toJson()),
          jsonEncode(_decisaoJogo(j).toJson()));
    });

    test('BOTIA-17 a decisão carrega o rastro que a explica', () {
      final j = _fixCorridaPromissora();
      j.botJoga(0);
      final rastro = j.ultimaDecisaoBot!;
      expect(rastro['razao'], isNotNull);
      expect(rastro['candidatos'], greaterThan(1));
      expect((rastro['features'] as Map), isNotEmpty);
      expect(rastro['truncado'], isFalse);
      expect((rastro['acoes'] as List), isNotEmpty);
    });

    // ---------- §2 impasse DOCUMENTADO (nunca silencioso) ----------

    test('BOTIA-18 mão só de curinga vira IMPASSE registrado, não exceção muda',
        () {
      final j = _botBase();
      j.maos[0] = [
        _bc('c2d', '2', 'ouros'),
        _bc('c2s', '2', 'espadas'),
        _bc('cjk', 'JOKER', null),
      ];
      j.botJoga(0);
      expect(j.impassesEstrategicos, isNotEmpty);
      expect(j.impassesEstrategicos.first['razao'],
          Razao.impasseDescarteSoCuringa);
      expect(j.lixo.last.valor, '2'); // menor perda: o 2 antes do Joker
      expect(j.vez, 1); // e o turno não ficou pendurado
    });

    // ---------- §9 fail-safe: nada disso afrouxa o C10 ----------

    test('BOTIA-20 partida canônica de 60 turnos: 108 cartas, integridade e '
        'progresso', () {
      final j = Jogo(const ['você', 'B1', 'B2', 'B3'], const ['', '', '', ''],
          const ['', '', '', ''],
          seed: 4242, motorConfig: MotorConfig.producao());
      for (var i = 0; i < 60 && !j.rodadaEncerrada; i++) {
        final vezAntes = j.vez;
        j.botJoga(j.vez);
        expect(j.ultimaFalhaTecnica, isNull, reason: 'turno $i');
        expect(totalCartas(j), 108, reason: 'turno $i');
        j.auditarIntegridade();
        expect(j.integridadeErro, isNull, reason: 'turno $i');
        // PROGRESSO: sob a autoridade única o robô não pode "destravar" o turno
        // por fora. Ou a vez anda, ou a rodada encerra — nunca gira parado.
        expect(j.rodadaEncerrada || j.vez != vezAntes, isTrue,
            reason: 'turno $i não concluiu');
        // E todo jogo que foi para a mesa continua legal para a autoridade.
        for (final d in const ['nos', 'eles']) {
          for (final m in j.jogosDupla[d]!) {
            expect(tipoCanonicoDeMeld(m, j.specCanonica), isNotNull,
                reason: 'meld ilegal na mesa no turno $i');
          }
        }
      }
    });

    test('BOTIA-19 falha técnica encerra o turno estratégico sem 2ª transação',
        () {
      final j = _fixCorridaPromissora();
      final antes = _snapJogo(j);
      j.projetorAutoridadeTest = (_) => throw StateError('projeção quebrou');
      j.botJoga(0);
      j.projetorAutoridadeTest = null;
      expect(j.falhasTecnicas, 1); // UMA tentativa, não uma varredura
      expect(_snapJogo(j), antes);
      expect(j.vez, 0);
    });
  });

  // ===================================================================
  // OS BOT-IA V1 — NÃO-VACUIDADE
  //
  // Cada regra estratégica crítica é desligada uma por vez, e o cenário
  // correspondente muda de resultado. Uma regra que não pode ser desligada é
  // uma regra que não pode ser provada — e um teste que passa com a regra
  // desligada não estava testando a regra.
  // ===================================================================
  group('OS BOT-IA V1 — não-vacuidade', () {
    test('NV-01/02 sem `proibeDescartarCuringa`, descartar curinga volta a ser '
        'alternativa', () {
      List<Carta> mao() => [
            _bc('cjk', 'JOKER', null),
            _bc('c2d', '2', 'ouros'),
            _bc('cKc', 'K', 'paus'),
            _bc('c9s', '9', 'espadas'),
          ];
      // A política é um FILTRO sobre as alternativas: com ela ligada, nenhum
      // plano sequer contempla mandar 2 ou Joker ao lixo.
      final com = _botBase()..maos[0] = mao();
      expect(
          _planosDe(com).any((p) =>
              p.cartaDescartada != null &&
              (p.cartaDescartada!.valor == '2' ||
                  p.cartaDescartada!.valor == 'JOKER')),
          isFalse);

      final sem = _botBase(
          regras: const RegrasEstrategicas(proibeDescartarCuringa: false))
        ..maos[0] = mao();
      expect(
          _planosDe(sem).any((p) =>
              p.cartaDescartada != null &&
              (p.cartaDescartada!.valor == '2' ||
                  p.cartaDescartada!.valor == 'JOKER')),
          isTrue);
    });

    test('NV-03 sem `avaliaDanoEstrutural`, o descarte deixa de escolher', () {
      final base = _botBase();
      base.maos[0] = _maoDanoEstrutural();
      final sem = _botBase(
          cfg: ConfiguracaoBot.v1.comRegras(
              const RegrasEstrategicas(avaliaDanoEstrutural: false)));
      sem.maos[0] = _maoDanoEstrutural();
      expect(_decisaoJogo(base).features.containsKey('danoDescarte'), isTrue);
      expect(_decisaoJogo(sem).features.containsKey('danoDescarte'), isFalse);
    });

    test('NV-04 sem `preservaCartaDoParceiro`, o bot larga a carta do parceiro',
        () {
      // Com a regra, NENHUMA semente escolhe o 8h; sem ela, alguma escolhe —
      // porque as quatro cartas passam a ser rigorosamente equivalentes.
      var comRegraLargou = false, semRegraLargou = false;
      for (var seed = 0; seed <= 20; seed++) {
        comRegraLargou = comRegraLargou ||
            _descarteDe(_decisaoJogo(_fixParceiroAdjacente(seed: seed))) ==
                'c8h';
        semRegraLargou = semRegraLargou ||
            _descarteDe(_decisaoJogo(_fixParceiroAdjacente(
                    seed: seed,
                    regras: const RegrasEstrategicas(
                        preservaCartaDoParceiro: false)))) ==
                'c8h';
      }
      expect(comRegraLargou, isFalse);
      expect(semRegraLargou, isTrue);
    });

    test('NV-05 sem `evitaAlimentarAdversario`, o bot entrega a extensão', () {
      var comRegra = false, semRegra = false;
      for (var seed = 0; seed <= 20; seed++) {
        comRegra = comRegra ||
            _descarteDe(_decisaoJogo(_fixAlimentaAdversario(seed: seed))) ==
                'cKh';
        semRegra = semRegra ||
            _descarteDe(_decisaoJogo(_fixAlimentaAdversario(
                    seed: seed,
                    regras: const RegrasEstrategicas(
                        evitaAlimentarAdversario: false)))) ==
                'cKh';
      }
      expect(comRegra, isFalse);
      expect(semRegra, isTrue);
    });

    test('NV-06 sem `protegeCanastraLimpa`, sujar a limpa volta a ser opção',
        () {
      final com = _fixCanastraLimpa();
      final sem = _fixCanastraLimpa(
          regras: const RegrasEstrategicas(protegeCanastraLimpa: false));
      expect(_planosDe(com).any((p) => p.sujaJogoLimpo), isFalse);
      expect(_planosDe(sem).any((p) => p.sujaJogoLimpo), isTrue);
    });

    test('NV-07 sem `preservaCuringa`, o bot queima o Joker para abrir', () {
      final sem = _fixDoisCaminhosDeAbertura(
          regras: const RegrasEstrategicas(preservaCuringa: false));
      final d = _decisaoJogo(sem);
      expect(_idsDaBaixada(d.plano!.baixada!), contains('cjk'));
    });

    test('NV-08 sem o valor da mão no peso, o bot baixa tudo que é legal', () {
      // Zerar `potencialMao`/`ligacoesMao` apaga o único termo que faz segurar
      // valer a pena. Sem ele o bot volta a ser o guloso que baixa por baixar.
      final sem = _fixCorridaPromissora(
          pesos: const PesosHeuristicos(
              potencialMao: 0, ligacoesMao: 0, exposicaoSemGanho: 0));
      expect(_decisaoJogo(sem).plano!.baixada, isNotNull);
    });

    test('NV-09 sem `planoIncluiDescarte`, o bot baixa e entrega o descarte',
        () {
      final sem = _fixBaixarForcaDescartePerigoso(
          regras: const RegrasEstrategicas(planoIncluiDescarte: false));
      expect(_decisaoJogo(sem).plano!.baixada, isNotNull);
    });

    test('NV-10 sem `prudenciaBatida`, o bot bate e deixa o parceiro na mão',
        () {
      final sem = _fixBatidaPrematura(
          regras: const RegrasEstrategicas(prudenciaBatida: false));
      sem.botJoga(0);
      expect(sem.rodadaEncerrada, isTrue);
      expect(sem.duplaQueBateu, 'nos');
    });
  });

  // ===================================================================
  // OS — GARANTIA DE ENCERRAMENTO LEGAL DE TURNO V1
  //
  // INVARIANTE: se a autoridade ACEITA uma ação durante o turno, o estado
  // resultante precisa admitir ao menos UMA transição legal até um desfecho
  // canônico (descarte, batida, tomada do morto, encerramento da mão/partida
  // ou passagem da vez). O motor não pode produzir estado operacionalmente
  // morto — nem para o humano, nem para o robô.
  //
  // A definição OPERACIONAL de "morto" usada aqui não é opinião do teste: é o
  // PRÓPRIO gerador canônico (`gerarAcoesLegais`) devolvendo lista VAZIA com a
  // rodada ainda aberta e a vez ainda no mesmo assento.
  // ===================================================================
  group('OS ENCERRAMENTO DE TURNO V1 — conclusão legal garantida', () {
    // O estado está MORTO? (rodada aberta, vez parada no assento e ZERO ações
    // legais). É a negação exata do invariante.
    bool morto(Jogo j, int assento) {
      if (j.rodadaEncerrada) return false; // desfecho canônico: mão encerrada
      if (j.vez != assento) return false; // desfecho canônico: a vez passou
      final proj = paraCanonico(j);
      final spec = RuleSpec.canonica(proj.canonico.modalidade,
          metaPontos: proj.canonico.metaPontos);
      return gerarAcoesLegais(proj.canonico, assento, spec).isEmpty;
    }

    String snapEnc(Jogo j) => jsonEncode(serializarProjecao(paraCanonico(j)));

    // ---------- CENÁRIO 1 — reprodução exata do C10-BOT-03 ----------
    test(
        'ENC-01 baixada que deixaria 1 carta SEM descarte legal é RECUSADA '
        '(reprodução do C10-BOT-03)', () {
      final j = _jgEncBecoSemSaida();
      final antes = snapEnc(j);
      final maoAntes = idsMao(j, 0);
      final mesaAntes = j.jogosDupla['nos']!.map((m) => m.length).toList();

      // A baixada é estruturalmente LEGAL (7-8-9 de copas é sequência válida) e
      // era ACEITA pela base: deixava a mão em [orfa], sem morto a pegar e sem
      // canastra para bater — logo, sem NENHUM descarte legal.
      final r = j.baixar(0, ['7c', '8c', '9c']);

      expect(r['ok'], isFalse); // agora a AUTORIDADE recusa
      expect(r['erro'], isNotNull);

      // Atomicidade: nada mudou.
      expect(idsMao(j, 0), maoAntes);
      expect(j.jogosDupla['nos']!.map((m) => m.length).toList(), mesaAntes);
      expect(j.vez, 0);
      expect(j.rodadaEncerrada, isFalse);
      expect(snapEnc(j), antes);

      // E o turno continua tendo saída legal: o descarte normal passa a vez.
      expect(morto(j, 0), isFalse);
      expect(j.descartar(0, 'orfa'), isNull);
      expect(j.vez, 1);
    });

    test('ENC-01b a base produzia estado MORTO — o invariante é o que mudou',
        () {
      // Prova dirigida do invariante sobre o MESMO cenário: qualquer que seja o
      // caminho aceito, o pós-estado nunca é morto.
      final j = _jgEncBecoSemSaida();
      final proj = paraCanonico(j);
      final spec = RuleSpec.canonica(proj.canonico.modalidade,
          metaPontos: proj.canonico.metaPontos);

      // A baixada em questão é REPROVADA pelo gerador único (mesma autoridade
      // que o humano e o robô consultam).
      final baixada = Baixar(jogosNovos: [
        ['7c', '8c', '9c']
      ]);
      final res = aplicarLegal(proj.canonico, 0, baixada, spec);
      expect(res.legal, isFalse);
      expect(res.proximoEstado, isNull); // sem mutação parcial
      expect(res.codigo, reasonCodeSemConclusaoLegal);

      // O estado ORIGINAL segue vivo (o descarte é a saída).
      expect(gerarAcoesLegais(proj.canonico, 0, spec), isNotEmpty);
    });

    // ---------- CENÁRIO 2 — uma carta restante, descarte legal existente ----
    test('ENC-02 1 carta restante COM descarte legal (morto a pegar) continua '
        'PERMITIDA', () {
      final j = _jgEncUmaCartaComMorto();
      final r = j.baixar(0, ['7c', '8c', '9c']);
      expect(r['ok'], isTrue); // nada de bloqueio falso
      expect(idsMao(j, 0), ['orfa']);
      expect(morto(j, 0), isFalse);
    });

    // ---------- CENÁRIO 3 — uma carta restante e batida válida -------------
    test('ENC-03 1 carta restante com CANASTRA na mesa: baixada permitida e a '
        'batida acontece', () {
      final j = _jgEncUmaCartaComCanastra();
      expect(j.baixar(0, ['7c', '8c', '9c'])['ok'], isTrue);
      expect(idsMao(j, 0), ['orfa']);
      expect(morto(j, 0), isFalse);
      // O descarte da última carta é BATIDA legal (canastra limpa na mesa).
      expect(j.descartar(0, 'orfa'), isNull);
      expect(j.rodadaEncerrada, isTrue);
      expect(j.duplaQueBateu, 'nos');
    });

    // ---------- CENÁRIO 4 — uma carta restante e morto aplicável -----------
    test('ENC-04 fluxo do MORTO indireto permanece intacto ponta a ponta', () {
      final j = _jgEncUmaCartaComMorto();
      expect(j.baixar(0, ['7c', '8c', '9c'])['ok'], isTrue);
      expect(j.descartar(0, 'orfa'), isNull);
      // Zerou a mão com morto disponível -> a autoridade estabiliza o morto
      // INDIRETO e a vez passa.
      expect(j.mortoPego['nos'], isTrue);
      expect(j.maos[0].length, 11);
      expect(j.vez, 1);
      expect(j.rodadaEncerrada, isFalse);
    });

    // ---------- CENÁRIO 5 — duas ou mais cartas restantes ------------------
    test('ENC-05 baixada que deixa 2+ cartas NÃO é bloqueada', () {
      final j = _jgEncDuasSobrando();
      expect(j.baixar(0, ['7c', '8c', '9c'])['ok'], isTrue);
      expect(idsMao(j, 0).length, 2);
      expect(morto(j, 0), isFalse);
      expect(j.descartar(0, 'orfa1'), isNull); // descarte normal
      expect(j.vez, 1);
    });

    // ---------- CENÁRIO 6 — curinga ---------------------------------------
    test('ENC-06 a regra vale para baixada COM curinga (JOKER e "2")', () {
      for (final curinga in ['jk', 'd2']) {
        final j = _jgEncBecoComCuringa(curinga);
        final antes = snapEnc(j);
        final r = j.baixar(0, ['7c', '8c', curinga]);
        expect(r['ok'], isFalse, reason: 'curinga $curinga');
        expect(snapEnc(j), antes, reason: 'curinga $curinga');
        expect(morto(j, 0), isFalse);
      }
    });

    // ---------- CENÁRIO 7 — vulnerável / não vulnerável --------------------
    test('ENC-07 abertura que atinge o mínimo mas deixaria beco é recusada '
        '(vulnerável E não vulnerável)', () {
      for (final vuln in [0, 1]) {
        final j = _jgEncAberturaBeco(rodadasVulneravel: vuln);
        expect(j.minimoParaDescer('nos'), vuln == 1 ? 75 : 0);
        final antes = snapEnc(j);
        // 10-J-Q-K de copas (40) + 10-J-Q-K de ouros (40) = 80 >= 75: o mínimo
        // NÃO é o que barra. O que barra é a carta órfã sem descarte legal.
        final r = j.baixarAtomico(0, jogosNovos: [
          ['10c', 'Jc', 'Qc', 'Kc'],
          ['10o', 'Jo', 'Qo', 'Ko'],
        ]);
        expect(r['ok'], isFalse, reason: 'vulneravel=$vuln');
        expect(j.primeiraBaixadaFeita['nos'], isFalse); // não abriu
        expect(snapEnc(j), antes, reason: 'vulneravel=$vuln');
        expect(morto(j, 0), isFalse);
      }
    });

    // ---------- CENÁRIO 8 — aberto / fechado / STBL ------------------------
    test('ENC-08 mesma garantia nas três modalidades', () {
      for (final m in ['ABERTO', 'FECHADO', 'STBL']) {
        final j = _jgEncBecoSemSaida(modalidade: m);
        final antes = snapEnc(j);
        expect(j.baixar(0, ['7c', '8c', '9c'])['ok'], isFalse, reason: m);
        expect(snapEnc(j), antes, reason: m);
        expect(morto(j, 0), isFalse, reason: m);
        // e o descarte normal segue disponível em todas elas
        expect(j.descartar(0, 'orfa'), isNull, reason: m);
        expect(j.vez, 1, reason: m);
      }
    });

    // ---------- CENÁRIO 9 — rollback transacional --------------------------
    test('ENC-09 a recusa é ATÔMICA: nenhuma mutação parcial em lugar nenhum',
        () {
      final j = _jgEncBecoSemSaida();
      final antes = snapEnc(j);
      final lixoAntes = [for (final c in j.lixo) c.id];
      final monteAntes = j.monte.length;
      final mortosAntes = j.mortos.length;
      final mortoPegoAntes = Map<String, bool>.from(j.mortoPego);
      final abriuAntes = Map<String, bool>.from(j.primeiraBaixadaFeita);
      final falhasAntes = j.falhasTecnicas;

      expect(j.baixar(0, ['7c', '8c', '9c'])['ok'], isFalse);

      expect(idsMao(j, 0), ['7c', '8c', '9c', 'orfa']); // mão intacta
      expect(j.jogosDupla['nos']!.length, 1); // mesa intacta
      expect(j.jogosDupla['nos']![0].length, 3);
      expect([for (final c in j.lixo) c.id], lixoAntes);
      expect(j.monte.length, monteAntes);
      expect(j.mortos.length, mortosAntes);
      expect(j.mortoPego, mortoPegoAntes);
      expect(j.primeiraBaixadaFeita, abriuAntes);
      expect(j.vez, 0);
      expect(j.rodadaEncerrada, isFalse);
      // Recusa de REGRA não é falha técnica e não pausa a partida.
      expect(j.falhasTecnicas, falhasAntes);
      expect(j.pausadaPorFalhaTecnica, isFalse);
      expect(snapEnc(j), antes); // projeção idêntica, campo a campo
    });

    // ---------- CENÁRIO 10 — avanço de turno -------------------------------
    test('ENC-10 turno concluído de forma válida SEMPRE transfere a vez', () {
      // (a) descarte normal -> próximo assento
      final a = _jgEncDuasSobrando();
      expect(a.baixar(0, ['7c', '8c', '9c'])['ok'], isTrue);
      expect(a.descartar(0, 'orfa1'), isNull);
      expect(a.vez, 1);
      expect(a.rodadaEncerrada, isFalse);

      // (b) morto indireto -> próximo assento
      final b = _jgEncUmaCartaComMorto();
      expect(b.baixar(0, ['7c', '8c', '9c'])['ok'], isTrue);
      expect(b.descartar(0, 'orfa'), isNull);
      expect(b.vez, 1);

      // (c) batida -> rodada encerrada (desfecho canônico, não há "próxima vez")
      final c = _jgEncUmaCartaComCanastra();
      expect(c.baixar(0, ['7c', '8c', '9c'])['ok'], isTrue);
      expect(c.descartar(0, 'orfa'), isNull);
      expect(c.rodadaEncerrada, isTrue);

      // (d) recusa -> a vez NÃO se move (não se inventa avanço)
      final d = _jgEncBecoSemSaida();
      expect(d.baixar(0, ['7c', '8c', '9c'])['ok'], isFalse);
      expect(d.vez, 0);
    });

    // ---------- §12 — outros estados mortos --------------------------------
    test('ENC-11 COMPRAR O LIXO com uso do topo também respeita o invariante',
        () {
      // Mesma família de beco por outro portão: a compra atômica do lixo
      // (Fechado/STBL) consome a mão no uso do topo e pode deixar 1 carta órfã.
      final j = _jgEncLixoBeco();
      final antes = snapEnc(j);

      // A compra que deixaria a mão em [orfa] sem saída é RECUSADA pela
      // autoridade, mesmo sendo uma compra estruturalmente válida do Fechado
      // (o topo é usado num 7-8-9 legal).
      final becoDireto = j.comprarLixoAtomico(
          0,
          const ComprarLixo(topoDeclarado: 'lxTopo', jogosNovos: [
            ['lxTopo', '8c', '9c']
          ]));
      expect(becoDireto['ok'], isFalse);
      expect(snapEnc(j), antes); // atomicidade da recusa

      // E o que é OFERECIDO ao jogador é exatamente o que a autoridade ACEITA:
      // a derivação não pode listar um candidato que depois seria recusado.
      final cands = j.candidatosCompraLixo(0);
      for (final c in cands) {
        final k = _jgEncLixoBeco();
        expect(k.comprarLixoAtomico(0, c)['ok'], isTrue,
            reason: 'candidato oferecido tem de ser aplicável');
        expect(morto(k, 0), isFalse);
      }
      // Neste cenário o único uso possível do topo é justamente o que dá beco,
      // então a mesa corretamente não oferece compra nenhuma — e o turno segue
      // com saída pelo monte.
      expect(cands, isEmpty);
      expect(morto(j, 0), isFalse);
      expect(j.comprarMonte(0), isTrue);
    });

    test('ENC-12 INVARIANTE varrido: nenhuma ação aceita deixa estado morto',
        () {
      // Varredura dirigida (property-like) sobre as mesas desta OS: para cada
      // cenário, TODA baixada candidata + todas as ações de base são aplicadas
      // sobre o estado canônico; se a autoridade ACEITA, o pós-estado tem de
      // admitir continuação legal.
      final fabricas = <String, Jogo Function()>{
        'beco': () => _jgEncBecoSemSaida(),
        'beco-fechado': () => _jgEncBecoSemSaida(modalidade: 'FECHADO'),
        'beco-stbl': () => _jgEncBecoSemSaida(modalidade: 'STBL'),
        'com-morto': () => _jgEncUmaCartaComMorto(),
        'com-canastra': () => _jgEncUmaCartaComCanastra(),
        'duas-sobrando': () => _jgEncDuasSobrando(),
        'curinga-joker': () => _jgEncBecoComCuringa('jk'),
        'curinga-dois': () => _jgEncBecoComCuringa('d2'),
        'abertura': () => _jgEncAberturaBeco(rodadasVulneravel: 1),
      };

      var aceitas = 0;
      for (final entry in fabricas.entries) {
        final proj = paraCanonico(entry.value());
        final estado = proj.canonico;
        final spec = RuleSpec.canonica(estado.modalidade,
            metaPontos: estado.metaPontos);
        final mao = estado.maos[0];

        // Candidatos: todo subconjunto da mão com 3..mão cartas como jogo novo,
        // mais toda extensão de 1 carta em cada jogo exposto, mais as ações de
        // base do gerador.
        final candidatos = <Acao>[];
        final n = mao.length;
        for (var mask = 1; mask < (1 << n); mask++) {
          final ids = <String>[
            for (var i = 0; i < n; i++)
              if (mask & (1 << i) != 0) mao[i].id
          ];
          if (ids.length >= 3) candidatos.add(Baixar(jogosNovos: [ids]));
          if (ids.length == 1) {
            final melds = estado.jogosDupla['nos'] ?? const [];
            for (var k = 0; k < melds.length; k++) {
              candidatos.add(Baixar(extensoes: [Extensao(k, ids)]));
            }
          }
        }

        for (final acao in [
          ...candidatos,
          const ComprarMonte(),
          const PegarMorto(),
          const PegarMorto(viaDescarte: true),
          const Bater(),
          for (final c in mao) Descartar(c.id),
        ]) {
          final r = aplicarLegal(estado, 0, acao, spec);
          if (!r.legal) {
            expect(r.proximoEstado, isNull,
                reason: '${entry.key}: recusa não pode devolver estado');
            continue;
          }
          aceitas++;
          final pos = r.proximoEstado!;
          if (pos.rodadaEncerrada) continue; // desfecho canônico
          if (pos.vez != 0) continue; // a vez passou: desfecho canônico
          // Mesmo assento, rodada aberta: TEM de haver continuação legal.
          expect(gerarAcoesLegais(pos, 0, spec), isNotEmpty,
              reason: '${entry.key}: ${acao.toJson()} deixou estado MORTO');
        }
      }
      expect(aceitas, greaterThan(0)); // não-vacuidade da varredura
    });

    // ---------- §10 — humano e robô sob a MESMA autoridade -----------------
    test('ENC-13 humano e robô recebem a MESMA regra (sem exceção para bot)',
        () {
      // Humano: recusa explícita.
      final humano = _jgEncBecoSemSaida();
      expect(humano.baixar(0, ['7c', '8c', '9c'])['ok'], isFalse);

      // Robô: a mesma mesa, jogada pelo robô canônico. O plano que deixaria
      // beco não é mais aplicável — o robô conclui o turno de outra forma.
      final robo = _jgEncBecoSemSaida();
      final marcaFalhas = robo.falhasTecnicas;
      robo.botJoga(0);
      expect(robo.falhasTecnicas, marcaFalhas); // nenhuma falha técnica
      expect(morto(robo, 0), isFalse); // e nunca em estado morto
      // O turno do robô terminou de forma canônica: a vez passou ou a mão
      // encerrou.
      expect(robo.vez != 0 || robo.rodadaEncerrada, isTrue);
    });

    test('ENC-15 varredura de BARALHOS REAIS no regime em que o beco nasce',
        () {
      // §12 — caça a estados mortos ADICIONAIS, fora dos fixtures desta OS.
      //
      // Parte de baralhos REAIS e caminha por ações legais sorteadas. O regime
      // importa: com morto ainda por pegar, esvaziar é sempre legal e o beco
      // não nasce — uma varredura "do início" passa longe da região de
      // interesse e não prova nada. Aqui os DOIS mortos já foram consumidos,
      // que é exatamente quando a última carta pode ficar sem descarte legal.
      //
      // Não-vacuidade medida: com a guarda desligada, esta mesma varredura
      // (em escala maior) acusa estados mortos — inclusive por EXTENSÃO, não
      // só por jogo novo. Com a guarda ligada, zero.
      final achados = <String>[];
      var aceitas = 0;
      for (final modalidade in ['ABERTO', 'FECHADO', 'STBL']) {
        for (var seed = 1; seed <= 3; seed++) {
          final jogo = Jogo(const ['A', 'B', 'C', 'D'], const ['', '', '', ''],
              const ['', '', '', ''],
              seed: seed, motorConfig: MotorConfig.producao());
          jogo.modalidade = modalidade;
          var e = paraCanonico(jogo).canonico.cloneProfundo();
          e.mortos.clear(); // os dois mortos já foram pegos
          e.mortoPego['nos'] = true;
          e.mortoPego['eles'] = true;
          final spec =
              RuleSpec.canonica(e.modalidade, metaPontos: e.metaPontos);
          final rnd = Random(seed * 7919);

          for (var passo = 0; passo < 18 && !e.rodadaEncerrada; passo++) {
            final assento = e.vez;
            final mao = e.maos[assento];
            // candidatos: subconjuntos da mão (jogo novo) + extensões de até 3
            // cartas em qualquer jogo exposto das duas duplas.
            final cands = <Acao>[];
            final n = mao.length;
            for (var mask = 1; mask < (1 << n); mask++) {
              final ids = <String>[
                for (var i = 0; i < n; i++)
                  if (mask & (1 << i) != 0) mao[i].id
              ];
              if (ids.length >= 3) cands.add(Baixar(jogosNovos: [ids]));
              if (ids.length <= 3) {
                for (final d in const ['nos', 'eles']) {
                  final melds =
                      e.jogosDupla[d] ?? const <List<CartaSnapshot>>[];
                  for (var k = 0; k < melds.length; k++) {
                    cands.add(Baixar(extensoes: [Extensao(k, ids)]));
                  }
                }
              }
            }
            final legais = <Acao>[];
            for (final a in [
              ...cands,
              const ComprarMonte(),
              const ComprarLixo(),
              const PegarMorto(),
              const PegarMorto(viaDescarte: true),
              const Bater(),
              for (final c in mao) Descartar(c.id),
            ]) {
              final r = aplicarLegal(e, assento, a, spec);
              if (!r.legal) {
                expect(r.proximoEstado, isNull); // recusa não devolve estado
                continue;
              }
              aceitas++;
              legais.add(a);
              final pos = r.proximoEstado!;
              if (!pos.rodadaEncerrada &&
                  pos.vez == assento &&
                  gerarAcoesLegais(pos, assento, spec).isEmpty) {
                achados.add('$modalidade/$seed/$passo -> ${a.toJson()}');
              }
            }
            if (legais.isEmpty) {
              achados.add('$modalidade/$seed/$passo estado SEM ação legal');
              break;
            }
            e = aplicarLegal(e, assento, legais[rnd.nextInt(legais.length)],
                    spec)
                .proximoEstado!;
          }
        }
      }
      expect(achados, isEmpty, reason: achados.take(5).join(' | '));
      expect(aceitas, greaterThan(500)); // não-vacuidade da varredura
    });

    test('ENC-16 reasonCode é para máquina; ao jogador vai só a mensagem', () {
      // §16/§17 — a distinção existe, mas os dois canais não se misturam: o
      // texto que chega ao cliente não carrega o código nem internals do motor,
      // e o código é estável o bastante para telemetria comparar por igualdade.
      final j = _jgEncBecoSemSaida();
      final erro = j.baixar(0, ['7c', '8c', '9c'])['erro'] as String;
      expect(erro, motivoSemConclusaoLegal);
      expect(erro.contains(reasonCodeSemConclusaoLegal), isFalse);
      expect(erro.toLowerCase(), isNot(contains('canônic')));
      expect(erro.toLowerCase(), isNot(contains('estado')));
      // nenhuma carta da mão é revelada na mensagem
      for (final c in ['7c', '8c', '9c', 'orfa']) {
        expect(erro.contains(c), isFalse);
      }

      // O código, por sua vez, chega inteiro pela autoridade.
      final proj = paraCanonico(_jgEncBecoSemSaida());
      final r = aplicarComAutoridade(_jgEncBecoSemSaida(), 0, [
        Baixar(jogosNovos: [
          ['7c', '8c', '9c']
        ])
      ]);
      expect(r.recusaCanonica, isTrue);
      expect(r.codigo, reasonCodeSemConclusaoLegal);
      // e é recusa de REGRA, não falha técnica (não vira telemetria de erro)
      expect(r.falhaTecnica, isFalse);
      expect(r.evidencia, isNull);
      expect(proj.canonico.vez, 0);
    });

    test('ENC-14 o gerador único NUNCA oferece uma ação que leve a beco', () {
      // Paridade estrutural: o que o gerador oferece é exatamente o que a
      // autoridade aceita — e nada do que ele oferece leva a estado morto.
      final proj = paraCanonico(_jgEncBecoSemSaida());
      final estado = proj.canonico;
      final spec =
          RuleSpec.canonica(estado.modalidade, metaPontos: estado.metaPontos);
      final baixada = Baixar(jogosNovos: [
        ['7c', '8c', '9c']
      ]);
      final oferecidas =
          gerarAcoesLegais(estado, 0, spec, candidatos: [baixada]);
      // a baixada de beco não aparece entre as ações legais
      expect(oferecidas.whereType<Baixar>(), isEmpty);
      // e o que sobra é saída de verdade
      expect(oferecidas, isNotEmpty);
      for (final a in oferecidas) {
        expect(acaoEhLegal(estado, 0, a, spec), isTrue);
      }
    });
  });

  // =====================================================================
  // OS 2 — PROVENIÊNCIA PÚBLICA CANÔNICA DE DESCARTES V1
  //
  // ANTES/DEPOIS. `PROV-00` nasceu no commit anterior provando o buraco: a
  // autoridade empilhava a carta no lixo e não registrava quem a descartou, e
  // por isso `ModeloParceiro.parceiroDescartou` respondia `false` a um fato
  // verdadeiro. Aqui os dois testes viram o par:
  //   • PROV-00 — descarte REAL agora carrega autoria até o consumidor;
  //   • PROV-01 — a forma HISTÓRICA preservada: lixo SEM registro (montado por
  //     fixture) continua sem autoria. Ausência de prova, nunca dedução.
  // =====================================================================
  group('OS PROVENIÊNCIA DE DESCARTES V1 — autoria pública de descarte', () {
    // Mesa de trabalho: quatro mãos com material suficiente para cada assento
    // descartar sem esbarrar no invariante de conclusão de turno da OS 1.
    Jogo mesaProv([String modalidade = 'ABERTO']) {
      final j = novo(modalidade);
      return montar(j,
          mao0: [('7', 'copas'), ('8', 'copas'), ('9', 'copas')],
          mao1: [('K', 'espadas'), ('Q', 'espadas'), ('J', 'espadas')],
          mao2: [('4', 'ouros'), ('5', 'ouros'), ('6', 'ouros')],
          mao3: [('J', 'paus'), ('10', 'paus'), ('9', 'paus')],
          vez: 0,
          jaComprou: true);
    }

    CartaSnapshot snap(Carta x) =>
        CartaSnapshot(x.id, x.naipe, x.valor, x.ehCoringa);

    // ---------- §19.1 — descarte simples com autoria ----------
    test('PROV-00 o descarte REAL chega ao consumidor com autor e ordem', () {
      final j = mesaProv();
      final alvo = j.maos[0].firstWhere((x) => x.valor == '9');
      expect(j.descartar(0, alvo.id), isNull);

      // O fato público continua sendo o mesmo: a carta está no topo do lixo.
      expect(j.lixo.last.id, alvo.id);

      // E agora a AUTORIA acompanha a carta até a visão de qualquer assento.
      final estado = paraCanonico(j).canonico;
      expect(estado.descartes, hasLength(1));
      expect(estado.descartes.single.assento, 0);
      expect(estado.descartes.single.carta.id, alvo.id);
      expect(estado.descartes.single.ordem, 0);

      final visao = VisaoInformacao.doEstado(estado, 2); // parceiro do assento 0
      expect(visao.lixoTopo!.id, alvo.id);
      expect(visao.descartesPublicos, hasLength(1));
      expect(visao.descartesPublicos.single.assento, 0);
      expect(visao.descartesPublicos.single.carta.id, alvo.id);
      expect(visao.descartesPublicos.single.ordem, 0);
    });

    // ---------- §17 Caso 1 — o bot afirma o fato ----------
    test('PROV-00b o modelo do parceiro afirma "meu parceiro descartou esta '
        'carta" porque a autoridade registrou', () {
      final j = mesaProv();
      final alvo = j.maos[0].firstWhere((x) => x.valor == '9');
      expect(j.descartar(0, alvo.id), isNull);

      final estado = paraCanonico(j).canonico;
      final spec =
          RuleSpec.canonica(estado.modalidade, metaPontos: estado.metaPontos);
      final modelo =
          ModeloParceiro.observar(VisaoInformacao.doEstado(estado, 2), spec);
      expect(modelo.parceiroDescartou(snap(alvo)), isTrue);
    });

    // ---------- §17 Caso 3 / §18 — sem registro, sem autor ----------
    test('PROV-01 carta no lixo SEM registro não ganha autor inventado', () {
      final j = novo('ABERTO');
      // Lixo montado por fixture: a carta está lá, ninguém a descartou dentro
      // da autoridade. É a forma histórica do teste original desta OS.
      montar(j,
          mao0: [('7', 'copas'), ('8', 'copas'), ('9', 'copas')],
          mao1: [('K', 'espadas'), ('Q', 'espadas')],
          mao2: [('4', 'ouros'), ('5', 'ouros')],
          mao3: [('J', 'paus'), ('10', 'paus')],
          lixo: [('3', 'espadas')],
          vez: 0,
          jaComprou: true);
      final noLixo = j.lixo.single;

      final estado = paraCanonico(j).canonico;
      expect(estado.lixo, hasLength(1));
      expect(estado.descartes, isEmpty,
          reason: 'o lixo tem carta, a autoridade não tem prova de autoria');

      final spec =
          RuleSpec.canonica(estado.modalidade, metaPontos: estado.metaPontos);
      for (final observador in const [0, 1, 2, 3]) {
        final visao = VisaoInformacao.doEstado(estado, observador);
        expect(visao.lixoTopo!.id, noLixo.id); // o topo continua público
        expect(visao.descartesPublicos, isEmpty);
        expect(
            ModeloParceiro.observar(visao, spec).parceiroDescartou(snap(noLixo)),
            isFalse,
            reason: 'ausência de prova nunca vira autoria deduzida');
      }
    });

    // ---------- §19.2 — quatro jogadores descartando em ordem ----------
    test('PROV-02 quatro assentos descartam: cada carta fica com o SEU autor',
        () {
      final j = mesaProv();
      final descartados = <int, String>{};
      for (var a = 0; a < 4; a++) {
        if (a > 0) expect(j.comprarMonte(a), isTrue); // turno começa comprando
        final carta = j.maos[a].first;
        descartados[a] = carta.id;
        expect(j.descartar(a, carta.id), isNull, reason: 'assento $a');
      }

      final estado = paraCanonico(j).canonico;
      expect(estado.descartes, hasLength(4));
      for (var a = 0; a < 4; a++) {
        final reg = estado.descartes[a];
        expect(reg.assento, a);
        expect(reg.carta.id, descartados[a]);
        expect(reg.ordem, a, reason: 'ordem temporal é 0,1,2,3');
      }
      // A ordem do livro acompanha a ordem da pilha do lixo (mesma sequência).
      expect([for (final d in estado.descartes) d.carta.id],
          [for (final c in estado.lixo) c.id]);
    });

    // ---------- §19.3 / §17 Caso 2 — cartas iguais, autores diferentes ------
    test('PROV-03 duas cartas IGUAIS descartadas por autores diferentes não se '
        'confundem', () {
      final j = novo('ABERTO');
      // Assento 0 (parceiro de 2) e assento 1 (adversário) têm cada um um 9♥.
      montar(j,
          mao0: [('9', 'copas'), ('7', 'copas'), ('8', 'copas')],
          mao1: [('9', 'copas'), ('K', 'espadas'), ('Q', 'espadas')],
          mao2: [('4', 'ouros'), ('5', 'ouros'), ('6', 'ouros')],
          mao3: [('J', 'paus'), ('10', 'paus'), ('9', 'paus')],
          vez: 0,
          jaComprou: true);
      final noveDoZero = j.maos[0].firstWhere((x) => x.valor == '9');
      final noveDoUm = j.maos[1].firstWhere((x) => x.valor == '9');
      expect(noveDoZero.id == noveDoUm.id, isFalse);

      expect(j.descartar(0, noveDoZero.id), isNull);
      expect(j.comprarMonte(1), isTrue);
      expect(j.descartar(1, noveDoUm.id), isNull);

      final estado = paraCanonico(j).canonico;
      expect(estado.descartes, hasLength(2));
      // Cada REGISTRO guarda o seu autor — as duas cópias não se misturam.
      final porId = {for (final d in estado.descartes) d.carta.id: d.assento};
      expect(porId[noveDoZero.id], 0);
      expect(porId[noveDoUm.id], 1);

      // §17 Caso 2 — só o adversário descartou o 9♠: não vira "do parceiro".
      final noveDoTres = j.maos[3].firstWhere((x) => x.valor == '9');
      final estadoDepois = paraCanonico(j).canonico;
      final spec = RuleSpec.canonica(estadoDepois.modalidade,
          metaPontos: estadoDepois.metaPontos);
      final visao2 = VisaoInformacao.doEstado(estadoDepois, 2);
      final modelo2 = ModeloParceiro.observar(visao2, spec);
      expect(modelo2.parceiroDescartou(snap(noveDoZero)), isTrue,
          reason: 'assento 0 É o parceiro do assento 2');
      expect(modelo2.parceiroDescartou(snap(noveDoTres)), isFalse,
          reason: 'ninguém descartou o 9♠');

      // O adversário (assento 1) recebe o MESMO fato público, com o mesmo autor.
      final visao1 = VisaoInformacao.doEstado(estadoDepois, 1);
      expect([for (final d in visao1.descartesPublicos) d.assento],
          [for (final d in visao2.descartesPublicos) d.assento]);
    });

    // ---------- §19.4 e §19.5 — compra do lixo e descarte depois dela -------
    test('PROV-04 comprar o lixo esvazia a pilha e PRESERVA o histórico; o '
        'descarte seguinte continua a mesma sequência', () {
      final j = mesaProv();
      final primeira = j.maos[0].firstWhere((x) => x.valor == '9');
      expect(j.descartar(0, primeira.id), isNull);

      // Assento 1 compra o lixo inteiro (ABERTO: sem exigência de uso do topo).
      expect(j.comprarLixo(1, modalidade: 'ABERTO')['ok'], isTrue);
      expect(j.lixo, isEmpty, reason: 'a pilha foi capturada');

      final aposCompra = paraCanonico(j).canonico;
      expect(aposCompra.lixo, isEmpty);
      expect(aposCompra.descartes, hasLength(1),
          reason: 'a carta saiu do lixo; o fato de ter sido descartada não sai');
      expect(aposCompra.descartes.single.assento, 0);
      expect(aposCompra.descartes.single.carta.id, primeira.id);

      // §19.5 — novo descarte DEPOIS da compra: ordem continua de onde parou.
      final segunda = j.maos[1].firstWhere((x) => x.id != primeira.id);
      expect(j.descartar(1, segunda.id), isNull);
      final aposDescarte = paraCanonico(j).canonico;
      expect(aposDescarte.descartes, hasLength(2));
      expect(aposDescarte.descartes[1].assento, 1);
      expect(aposDescarte.descartes[1].ordem, 1);
      // O lixo tem 1 carta, o livro tem 2: pilha e histórico são coisas
      // diferentes, e é exatamente isso que a semântica acumulada quer dizer.
      expect(aposDescarte.lixo, hasLength(1));

      // O parceiro do assento 0 continua sabendo o que ele dispensou.
      final spec = RuleSpec.canonica(aposDescarte.modalidade,
          metaPontos: aposDescarte.metaPontos);
      final modelo = ModeloParceiro.observar(
          VisaoInformacao.doEstado(aposDescarte, 2), spec);
      expect(modelo.parceiroDescartou(snap(primeira)), isTrue,
          reason: 'lixo comprado não apaga a memória pública da mão');
    });

    // ---------- §19.6 / §9 — nova mão ----------
    test('PROV-05 NOVA MÃO zera o livro: descarte de mão anterior não é '
        'atribuído à mão corrente', () {
      final j = mesaProv();
      final carta = j.maos[0].firstWhere((x) => x.valor == '9');
      expect(j.descartar(0, carta.id), isNull);
      expect(paraCanonico(j).canonico.descartes, hasLength(1));

      // Distribuir a mão seguinte é o mesmo caminho que o fim de rodada usa.
      j.novaRodada();

      expect(j.descartes, isEmpty);
      expect(j.lixo, isEmpty);
      final estado = paraCanonico(j).canonico;
      expect(estado.descartes, isEmpty);

      final spec =
          RuleSpec.canonica(estado.modalidade, metaPontos: estado.metaPontos);
      final modelo =
          ModeloParceiro.observar(VisaoInformacao.doEstado(estado, 2), spec);
      expect(modelo.parceiroDescartou(snap(carta)), isFalse,
          reason: 'a memória da mão anterior não atravessa a distribuição');
    });

    // ---------- §19.11, §19.12, §19.7 / §17 Caso 4 — serialização e volta ----
    test('PROV-06 RECONEXÃO: o estado reconstruído do snapshot tem a MESMA '
        'autoria', () {
      final j = mesaProv();
      final carta = j.maos[0].firstWhere((x) => x.valor == '9');
      expect(j.descartar(0, carta.id), isNull);
      expect(j.comprarMonte(1), isTrue);
      final outra = j.maos[1].first;
      expect(j.descartar(1, outra.id), isNull);

      final original = paraCanonico(j);
      // Serialização -> texto -> desserialização: o caminho que um jogador que
      // reconecta percorre para receber o estado da mão em curso.
      final texto = jsonEncode(serializarProjecao(original));
      final reconstruida = desserializarProjecao(
          jsonDecode(texto) as Map<String, dynamic>);

      expect(reconstruida.canonico.descartes, hasLength(2));
      expect(reconstruida.canonico.assinatura(), original.canonico.assinatura());
      for (var i = 0; i < 2; i++) {
        expect(reconstruida.canonico.descartes[i],
            original.canonico.descartes[i]);
      }

      // E a visão do reconectado é IGUAL à de quem nunca caiu.
      for (final observador in const [0, 1, 2, 3]) {
        expect(
            VisaoInformacao.doEstado(reconstruida.canonico, observador)
                .assinaturaPublica(),
            VisaoInformacao.doEstado(original.canonico, observador)
                .assinaturaPublica());
      }

      // O snapshot continua servindo de Replay reproduzível (versão da spec).
      final replay = Replay(
        versaoSpec: RuleSpec.versaoCanonica,
        modalidade: original.canonico.modalidade,
        metaPontos: original.canonico.metaPontos,
        acoes: const [ComprarMonte()],
        estadoInicialSerializado: serializarProjecao(original),
        faseInicial: original.canonico.fase,
      );
      expect(replay.reproduzivel, isTrue);
      expect(replay.snapshotCompleto, isTrue);
      final ida = Replay.fromJson(
          jsonDecode(jsonEncode(replay.toJson())) as Map<String, dynamic>);
      expect(
          desserializarProjecao(ida.estadoInicialSerializado!)
              .canonico
              .descartes,
          original.canonico.descartes);
    });

    test('PROV-07 snapshot ANTERIOR à OS (sem a chave) desserializa como '
        'DESCONHECIDO, não como autoria reconstruída', () {
      final j = mesaProv();
      final carta = j.maos[0].firstWhere((x) => x.valor == '9');
      expect(j.descartar(0, carta.id), isNull);

      // Simula um snapshot gravado antes desta OS: mesma estrutura, sem a
      // chave `descartes`. É a prova de compatibilidade ADITIVA do §16.
      final mapa = jsonDecode(jsonEncode(serializarProjecao(paraCanonico(j))))
          as Map<String, dynamic>;
      (mapa['canonico'] as Map).remove('descartes');

      final antigo = desserializarProjecao(mapa);
      expect(antigo.canonico.lixo, hasLength(1), reason: 'o lixo veio inteiro');
      expect(antigo.canonico.descartes, isEmpty,
          reason: 'sem registro no snapshot, autor = desconhecido');
    });

    // ---------- §19.8, §19.9, §19.10 — as visões ----------
    test('PROV-08 todas as visões recebem a MESMA verdade pública', () {
      final j = mesaProv();
      final doZero = j.maos[0].firstWhere((x) => x.valor == '9');
      expect(j.descartar(0, doZero.id), isNull);
      expect(j.comprarMonte(1), isTrue);
      final doUm = j.maos[1].first;
      expect(j.descartar(1, doUm.id), isNull);

      final estado = paraCanonico(j).canonico;
      final esperado = [
        (0, doZero.id, 0),
        (1, doUm.id, 1),
      ];

      // Próprio jogador, parceiro e adversários: um único conjunto de fatos.
      for (final observador in const [0, 1, 2, 3]) {
        final v = VisaoInformacao.doEstado(estado, observador);
        expect([
          for (final d in v.descartesPublicos) (d.assento, d.carta.id, d.ordem)
        ], esperado, reason: 'visão do assento $observador');
      }

      // Recorte tipo ESPECTADOR — quem não tem mão nenhuma nesta visão: a
      // autoria pública continua idêntica, sem ganhar nenhuma permissão nova.
      final semMao = VisaoInformacao.doEstado(estado, 0, maoOculta: true);
      expect(semMao.mao, isEmpty);
      expect([
        for (final d in semMao.descartesPublicos)
          (d.assento, d.carta.id, d.ordem)
      ], esperado);
    });

    test('PROV-09 o consumidor distingue parceiro de ADVERSÁRIO com o mesmo '
        'fato canônico', () {
      final j = mesaProv();
      final doZero = j.maos[0].firstWhere((x) => x.valor == '9');
      expect(j.descartar(0, doZero.id), isNull);
      expect(j.comprarMonte(1), isTrue);
      final doUm = j.maos[1].first;
      expect(j.descartar(1, doUm.id), isNull);

      final estado = paraCanonico(j).canonico;
      final v2 = VisaoInformacao.doEstado(estado, 2);
      // A visão NÃO pré-calcula "foi do parceiro": entrega o autor, e quem
      // observa decide (§10). Aqui o consumidor faz a conta com o assento.
      final doParceiro = [
        for (final d in v2.descartesPublicos)
          if (d.assento == v2.parceiro) d.carta.id
      ];
      final dosAdversarios = [
        for (final d in v2.descartesPublicos)
          if (v2.adversarios.contains(d.assento)) d.carta.id
      ];
      expect(doParceiro, [doZero.id]);
      expect(dosAdversarios, [doUm.id]);
    });

    // ---------- §19.15 / §20 — nada privado atravessa ----------
    test('PROV-10 o registro carrega SÓ carta, assento e ordem — nenhum dado '
        'privado', () {
      final j = mesaProv();
      final carta = j.maos[0].firstWhere((x) => x.valor == '9');
      expect(j.descartar(0, carta.id), isNull);

      final serializado = serializarEstado(paraCanonico(j).canonico);
      final registros = (serializado['descartes'] as List).cast<Map>();
      expect(registros, hasLength(1));
      expect(registros.single.keys.toSet(), {'carta', 'assento', 'ordem'});
      // A carta é a MESMA forma pública que o lixo já usa — nada a mais.
      expect((registros.single['carta'] as Map).keys.toSet(),
          ((serializado['lixo'] as List).first as Map).keys.toSet());

      // Nenhum resquício de mão, monte, morto, uid ou tempo no texto do livro.
      final texto = jsonEncode(registros).toLowerCase();
      for (final proibido in const [
        'uid',
        'mao',
        'monte',
        'morto',
        'timestamp',
        'razao',
        'plano'
      ]) {
        expect(texto.contains(proibido), isFalse, reason: 'vazou "$proibido"');
      }
    });

    test('PROV-11 a proveniência é PÚBLICA: estados que só diferem no OCULTO '
        'seguem com a mesma assinatura pública', () {
      Jogo comMaoAlheia(List<Spec> mao1) {
        final j = novo('ABERTO');
        montar(j,
            mao0: [('7', 'copas'), ('8', 'copas'), ('9', 'copas')],
            mao1: mao1,
            mao2: [('4', 'ouros'), ('5', 'ouros'), ('6', 'ouros')],
            mao3: [('J', 'paus'), ('10', 'paus'), ('9', 'paus')],
            vez: 0,
            jaComprou: true);
        final alvo = j.maos[0].firstWhere((x) => x.valor == '9');
        expect(j.descartar(0, alvo.id), isNull);
        return j;
      }

      final a = comMaoAlheia([('K', 'espadas'), ('Q', 'espadas'), ('J', 'espadas')]);
      final b = comMaoAlheia([('3', 'espadas'), ('4', 'espadas'), ('5', 'espadas')]);
      final va = VisaoInformacao.doEstado(paraCanonico(a).canonico, 2);
      final vb = VisaoInformacao.doEstado(paraCanonico(b).canonico, 2);
      // Mesmo público (inclusive a autoria do descarte), oculto diferente.
      expect(va.descartesPublicos.single.assento,
          vb.descartesPublicos.single.assento);
      expect(va.assinaturaPublica().contains('desc=0@0:'), isTrue);

      // E autorias DIFERENTES produzem assinaturas públicas diferentes — o
      // campo participa de verdade, não é decoração.
      final c1 = comMaoAlheia([('K', 'espadas'), ('Q', 'espadas'), ('J', 'espadas')]);
      expect(c1.comprarMonte(1), isTrue);
      expect(c1.descartar(1, c1.maos[1].first.id), isNull);
      final vc = VisaoInformacao.doEstado(paraCanonico(c1).canonico, 2);
      expect(vc.assinaturaPublica() == va.assinaturaPublica(), isFalse);
    });

    // ---------- §19.14 / §17 — os quatro casos, ponta a ponta ----------
    test('PROV-12 os quatro casos do §17 numa partida com o ROBÔ canônico', () {
      final j = mesaProv();
      // Caso 1 — o parceiro descartou uma carta pública.
      final doParceiro = j.maos[0].firstWhere((x) => x.valor == '9');
      expect(j.descartar(0, doParceiro.id), isNull);
      // Caso 2 — um adversário descartou outra.
      expect(j.comprarMonte(1), isTrue);
      final doAdversario = j.maos[1].first;
      expect(j.descartar(1, doAdversario.id), isNull);

      final estado = paraCanonico(j).canonico;
      final spec =
          RuleSpec.canonica(estado.modalidade, metaPontos: estado.metaPontos);
      final modelo =
          ModeloParceiro.observar(VisaoInformacao.doEstado(estado, 2), spec);

      expect(modelo.parceiroDescartou(snap(doParceiro)), isTrue); // 1
      expect(modelo.parceiroDescartou(snap(doAdversario)), isFalse); // 2

      // Caso 3 — carta que está no lixo mas não tem autoria provada.
      final semProva = paraCanonico(j).canonico;
      final forjado = EstadoJogo(
        modalidade: semProva.modalidade,
        metaPontos: semProva.metaPontos,
        monte: semProva.monte,
        lixo: semProva.lixo, // o lixo inteiro...
        mortos: semProva.mortos,
        maos: semProva.maos,
        jogosDupla: semProva.jogosDupla,
        rodadasVulneravel: semProva.rodadasVulneravel,
        primeiraBaixadaFeita: semProva.primeiraBaixadaFeita,
        vez: semProva.vez,
        mortoPego: semProva.mortoPego,
        fase: semProva.fase,
        // ...e NENHUM registro de autoria.
      );
      final semAutor =
          ModeloParceiro.observar(VisaoInformacao.doEstado(forjado, 2), spec);
      expect(semAutor.parceiroDescartou(snap(doParceiro)), isFalse,
          reason: 'sem registro o bot não inventa autor');

      // Caso 4 — reconexão: o mesmo bot, a partir do snapshot, afirma o mesmo.
      final reconectado = desserializarProjecao(jsonDecode(
              jsonEncode(serializarProjecao(paraCanonico(j))))
          as Map<String, dynamic>);
      final aposQueda = ModeloParceiro.observar(
          VisaoInformacao.doEstado(reconectado.canonico, 2), spec);
      expect(aposQueda.parceiroDescartou(snap(doParceiro)), isTrue);
      expect(aposQueda.parceiroDescartou(snap(doAdversario)), isFalse);
    });

    // ---------- §21/§22 — o motor e o robô continuam como estavam ----------
    test('PROV-13 partida completa do ROBÔ canônico: o livro nunca mente e '
        'nunca some', () {
      for (final modalidade in const ['ABERTO', 'FECHADO']) {
        final j = Jogo(const ['você', 'B1', 'B2', 'B3'], const ['', '', '', ''],
            const ['', '', '', ''],
            seed: 20260817, motorConfig: MotorConfig.producao());
        j.modalidade = modalidade;
        for (var turno = 0; turno < 40 && !j.rodadaEncerrada; turno++) {
          final assento = j.vez;
          j.botJoga(assento);
          final estado = paraCanonico(j).canonico;
          // INVARIANTE: todo registro aponta para um assento real, a ordem é
          // estritamente crescente, e o livro nunca encolhe sem nova mão.
          for (var i = 0; i < estado.descartes.length; i++) {
            final d = estado.descartes[i];
            expect(d.assento >= 0 && d.assento < 4, isTrue);
            expect(d.ordem, i);
          }
          // O lixo NUNCA tem mais cartas do que o livro tem registros: toda
          // carta na pilha chegou lá por um descarte registrado.
          expect(estado.lixo.length <= estado.descartes.length, isTrue,
              reason: '$modalidade turno $turno: lixo sem proveniência');
        }
        // NÃO-VACUIDADE: a partida precisa ter descartado de verdade, senão o
        // invariante acima passaria por vazio.
        final fim = paraCanonico(j).canonico;
        expect(fim.descartes.length >= 10, isTrue,
            reason: '$modalidade: só ${fim.descartes.length} descartes '
                'registrados — o cenário não exercitou nada');
        expect(fim.descartes.map((d) => d.assento).toSet().length >= 2, isTrue,
            reason: '$modalidade: um único assento descartou na partida toda');
      }
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

// ===== C10 — helpers (parte 1-fix: geração de TODOS os candidatos) =====

// Fechado, dupla nos já abriu ([3c,4c,5c]); topo 6c pode virar JOGO NOVO
// [6c,7c,8c] OU ESTENDER 3-4-5 -> duas (ou mais) alternativas.
Jogo _jgLixoDuasAlternativasC10() {
  final j = Jogo.paraCostura();
  j.vez = 0;
  j.jaComprou = false;
  j.modalidade = 'FECHADO';
  j.primeiraBaixadaFeita = {'nos': true, 'eles': false};
  j.monte = [Carta('mo1', 'copas', '2', false)];
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
    [
      Carta('7c', 'copas', '7', false),
      Carta('8c', 'copas', '8', false),
      Carta('9s', 'espadas', '9', false),
    ],
    <Carta>[],
    <Carta>[],
    <Carta>[],
  ];
  j.lixo = [Carta('ent', 'ouros', '2', false), Carta('6c', 'copas', '6', false)];
  return j;
}

// Fechado, abrindo (não vulnerável). topo 5c + mão 3c,4c,6c,7c formam meld
// GRANDE (>3 cartas): [3c,4c,5c,6c] / [3c,4c,5c,6c,7c].
Jogo _jgLixoMeldGrandeC10() {
  final j = Jogo.paraCostura();
  j.vez = 0;
  j.jaComprou = false;
  j.modalidade = 'FECHADO';
  j.monte = [Carta('mo1', 'copas', '2', false)];
  j.maos = [
    [
      Carta('3c', 'copas', '3', false),
      Carta('4c', 'copas', '4', false),
      Carta('6c', 'copas', '6', false),
      Carta('7c', 'copas', '7', false),
      Carta('9s', 'espadas', '9', false),
    ],
    <Carta>[],
    <Carta>[],
    <Carta>[],
  ];
  j.lixo = [Carta('ent', 'ouros', '2', false), Carta('5c', 'copas', '5', false)];
  return j;
}

// Fechado, dupla nos já abriu ([3c,4c,5c]); topo t7 (7c) NÃO estende sozinho
// (falta o 6c); precisa de topo + 6c (carta da mão) -> [3,4,5,6,7].
Jogo _jgLixoExtTopoMaisMaoC10() {
  final j = Jogo.paraCostura();
  j.vez = 0;
  j.jaComprou = false;
  j.modalidade = 'FECHADO';
  j.primeiraBaixadaFeita = {'nos': true, 'eles': false};
  j.monte = [Carta('mo1', 'copas', '2', false)];
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
    [Carta('6c', 'copas', '6', false), Carta('9s', 'espadas', '9', false)],
    <Carta>[],
    <Carta>[],
    <Carta>[],
  ];
  j.lixo = [Carta('ent', 'ouros', '2', false), Carta('t7', 'copas', '7', false)];
  return j;
}

// Fechado, dupla nos VULNERÁVEL (mínimo 75) ABRINDO. topo 5c forma [5c,3c,4c]=15
// (<75 isolado); a corrida de ouros 6..Q=60 completa o mínimo NO CONJUNTO (75).
// Enterradas (entA/entK) NUNCA entram na geração.
Jogo _jgLixoAberturaMultiplaC10() {
  final j = Jogo.paraCostura();
  j.vez = 0;
  j.jaComprou = false;
  j.modalidade = 'FECHADO';
  j.rodadasVulneravel = {'nos': 1, 'eles': 0};
  j.primeiraBaixadaFeita = {'nos': false, 'eles': false};
  j.monte = [Carta('mo1', 'copas', '2', false)];
  j.maos = [
    [
      Carta('3c', 'copas', '3', false),
      Carta('4c', 'copas', '4', false),
      Carta('6d', 'ouros', '6', false),
      Carta('7d', 'ouros', '7', false),
      Carta('8d', 'ouros', '8', false),
      Carta('9d', 'ouros', '9', false),
      Carta('10d', 'ouros', '10', false),
      Carta('Jd', 'ouros', 'J', false),
      Carta('Qd', 'ouros', 'Q', false),
    ],
    <Carta>[],
    <Carta>[],
    <Carta>[],
  ];
  j.lixo = [
    Carta('entA', 'ouros', 'A', false),
    Carta('entK', 'ouros', 'K', false),
    Carta('5c', 'copas', '5', false), // topo
  ];
  return j;
}

// ===== C10 — helpers (parte 1-fix2: sem caps de tamanho/contagem) =====

// Fechado, não vulnerável. topo 5c + corrida copas 3,4,6,7,8,9,10,J na mão ->
// jogo novo de 8/9 cartas contendo o topo (sp9 evita esvaziar a mão).
Jogo _jgLixoRunLongoC10() {
  final j = Jogo.paraCostura();
  j.vez = 0;
  j.jaComprou = false;
  j.modalidade = 'FECHADO';
  j.monte = [Carta('mo1', 'copas', '2', false)];
  j.maos = [
    [
      Carta('3c', 'copas', '3', false),
      Carta('4c', 'copas', '4', false),
      Carta('6c', 'copas', '6', false),
      Carta('7c', 'copas', '7', false),
      Carta('8c', 'copas', '8', false),
      Carta('9c', 'copas', '9', false),
      Carta('10c', 'copas', '10', false),
      Carta('Jc', 'copas', 'J', false),
      Carta('sp9', 'espadas', '9', false), // reserva (mão não esvazia)
    ],
    <Carta>[],
    <Carta>[],
    <Carta>[],
  ];
  j.lixo = [Carta('ent', 'ouros', '2', false), Carta('5c', 'copas', '5', false)];
  return j;
}

// Fechado, não vulnerável. topo 5c (meld [5c,3c,4c]) + três corridas disjuntas
// (ouros/espadas/paus) -> compra atômica com 4 jogos. sp evita esvaziar a mão.
Jogo _jgLixoQuatroMeldsC10() {
  final j = Jogo.paraCostura();
  j.vez = 0;
  j.jaComprou = false;
  j.modalidade = 'FECHADO';
  j.monte = [Carta('mo1', 'copas', '2', false)];
  j.maos = [
    [
      Carta('3c', 'copas', '3', false),
      Carta('4c', 'copas', '4', false),
      Carta('5o', 'ouros', '5', false),
      Carta('6o', 'ouros', '6', false),
      Carta('7o', 'ouros', '7', false),
      Carta('5e', 'espadas', '5', false),
      Carta('6e', 'espadas', '6', false),
      Carta('7e', 'espadas', '7', false),
      Carta('5p', 'paus', '5', false),
      Carta('6p', 'paus', '6', false),
      Carta('7p', 'paus', '7', false),
      Carta('spA', 'espadas', 'A', false), // reserva
    ],
    <Carta>[],
    <Carta>[],
    <Carta>[],
  ];
  j.lixo = [Carta('ent', 'ouros', '2', false), Carta('5c', 'copas', '5', false)];
  return j;
}

// Monotonicidade (15) — estado A: mão mínima (topo 5c + 3c,4c).
Jogo _jgLixoMonoAC10() {
  final j = Jogo.paraCostura();
  j.vez = 0;
  j.jaComprou = false;
  j.modalidade = 'FECHADO';
  j.monte = [Carta('mo1', 'copas', '2', false)];
  j.maos = [
    [Carta('3c', 'copas', '3', false), Carta('4c', 'copas', '4', false)],
    <Carta>[],
    <Carta>[],
    <Carta>[],
  ];
  j.lixo = [Carta('ent', 'ouros', '2', false), Carta('5c', 'copas', '5', false)];
  // OS ENCERRAMENTO: morto ainda por pegar — é o que torna LEGAL sobrar 1 carta
  // na mão depois da compra (ver _mortoDisponivelEnc).
  j.mortos = _mortoDisponivelEnc('monoA');
  return j;
}

// Monotonicidade (15) — estado B: mesma mão de A + uma corrida ouros extra.
Jogo _jgLixoMonoBC10() {
  final j = Jogo.paraCostura();
  j.vez = 0;
  j.jaComprou = false;
  j.modalidade = 'FECHADO';
  j.monte = [Carta('mo1', 'copas', '2', false)];
  j.maos = [
    [
      Carta('3c', 'copas', '3', false),
      Carta('4c', 'copas', '4', false),
      Carta('5o', 'ouros', '5', false),
      Carta('6o', 'ouros', '6', false),
      Carta('7o', 'ouros', '7', false),
    ],
    <Carta>[],
    <Carta>[],
    <Carta>[],
  ];
  j.lixo = [Carta('ent', 'ouros', '2', false), Carta('5c', 'copas', '5', false)];
  // OS ENCERRAMENTO: idem estado A — morto disponível.
  j.mortos = _mortoDisponivelEnc('monoB');
  return j;
}

// ===== C10 — helper (parte 1-fix3: prova de estresse sem explosão) =====

// Fechado, não vulnerável. Mão GRANDE (18) e RUIDOSA: o meld conhecido
// [5c,3c,4c] (topo 5c + 3c,4c) mais 16 cartas de RUÍDO — em cada naipe, ranks
// NÃO consecutivos; nenhum rank aparece 3x — de modo que NENHUM outro meld se
// forma. A poda estrutural (naipe/valor) descarta o ruído cedo, então o DFS não
// enumera 2^18.
Jogo _jgLixoGrandeRuidosoC10() {
  final j = Jogo.paraCostura();
  j.vez = 0;
  j.jaComprou = false;
  j.modalidade = 'FECHADO';
  j.monte = [Carta('mo1', 'copas', '2', false)];
  j.maos = [
    [
      // meld conhecido (com o topo 5c): 3c,4c
      Carta('3c', 'copas', '3', false),
      Carta('4c', 'copas', '4', false),
      // ruído copas (não consecutivo com 3,4 nem entre si)
      Carta('7c', 'copas', '7', false),
      Carta('9c', 'copas', '9', false),
      Carta('Jc', 'copas', 'J', false),
      Carta('Kc', 'copas', 'K', false),
      // ruído ouros
      Carta('7o', 'ouros', '7', false),
      Carta('9o', 'ouros', '9', false),
      Carta('Jo', 'ouros', 'J', false),
      Carta('Ko', 'ouros', 'K', false),
      // ruído espadas
      Carta('8e', 'espadas', '8', false),
      Carta('10e', 'espadas', '10', false),
      Carta('Qe', 'espadas', 'Q', false),
      Carta('Ae', 'espadas', 'A', false),
      // ruído paus
      Carta('8p', 'paus', '8', false),
      Carta('10p', 'paus', '10', false),
      Carta('Qp', 'paus', 'Q', false),
      Carta('Ap', 'paus', 'A', false),
    ],
    <Carta>[],
    <Carta>[],
    <Carta>[],
  ];
  j.lixo = [Carta('ent', 'ouros', '2', false), Carta('5c', 'copas', '5', false)];
  return j;
}

// ===== C10 — helpers (parte 2: promoção do consumidor real) =====
// Todos nascem em `MotorConfig.producao()` por padrão: é o estado do ROOT
// depois do flip. Onde o teste precisa comparar com o legado, a config vem
// por parâmetro.

Jogo _c10Base({MotorConfig? cfg, String modalidade = 'ABERTO'}) {
  final j = Jogo.paraCostura(motorConfig: cfg ?? MotorConfig.producao());
  j.vez = 0;
  j.modalidade = modalidade;
  j.mortoPego = {'nos': false, 'eles': false};
  j.primeiraBaixadaFeita = {'nos': false, 'eles': false};
  j.rodadasVulneravel = {'nos': 0, 'eles': 0};
  j.maos = [<Carta>[], <Carta>[], <Carta>[], <Carta>[]];
  j.jogosDupla = {'nos': <List<Carta>>[], 'eles': <List<Carta>>[]};
  j.monte = <Carta>[];
  j.mortos = <List<Carta>>[];
  j.lixo = <Carta>[];
  return j;
}

// Aberto, fase compra: lixo com 2 cartas; compra LIVRE, vai toda para a mão.
Jogo _jgLixoAbertoC10() {
  final j = _c10Base();
  j.jaComprou = false;
  j.monte = [Carta('mo1', 'copas', '7', false)];
  j.maos[0] = [Carta('k1', 'paus', 'K', false)];
  j.lixo = [
    Carta('entA', 'ouros', '9', false),
    Carta('topoA', 'espadas', '4', false), // topo
  ];
  return j;
}

// Fase jogo; mesa da dupla tem 3-4-5 copas; mão tem 6c (estende) e kx (não).
Jogo _jgEstenderC10({MotorConfig? cfg}) {
  final j = _c10Base(cfg: cfg);
  j.jaComprou = true;
  j.monte = [Carta('mo1', 'copas', '2', false)];
  j.maos[0] = [
    Carta('6c', 'copas', '6', false),
    Carta('kx', 'paus', 'K', false),
    Carta('9o', 'ouros', '9', false),
    Carta('10o', 'ouros', '10', false),
    Carta('Jo', 'ouros', 'J', false),
  ];
  j.jogosDupla['nos'] = [
    [
      Carta('3c', 'copas', '3', false),
      Carta('4c', 'copas', '4', false),
      Carta('5c', 'copas', '5', false),
    ]
  ];
  j.primeiraBaixadaFeita = {'nos': true, 'eles': false};
  j.lixo = [Carta('lx', 'espadas', '3', false)];
  return j;
}

// Fase jogo, dupla VULNERÁVEL (mínimo 75). Três jogos de 3 cartas: nenhum
// atinge 75 sozinho (15 / 30 / 35), os três juntos somam 80.
Jogo _jgAberturaMultiplaC10() {
  final j = _c10Base();
  j.jaComprou = true;
  j.rodadasVulneravel = {'nos': 1, 'eles': 0};
  j.monte = [Carta('mo1', 'copas', '2', false)];
  j.maos[0] = [
    Carta('3c', 'copas', '3', false),
    Carta('4c', 'copas', '4', false),
    Carta('5c', 'copas', '5', false),
    Carta('Jo', 'ouros', 'J', false),
    Carta('Qo', 'ouros', 'Q', false),
    Carta('Ko', 'ouros', 'K', false),
    Carta('Qe', 'espadas', 'Q', false),
    Carta('Ke', 'espadas', 'K', false),
    Carta('Ae', 'espadas', 'A', false),
    Carta('guard', 'paus', '8', false), // sobra: não zera a mão
  ];
  j.lixo = [Carta('lx', 'espadas', '3', false)];
  // OS ENCERRAMENTO: morto disponível — sem ele, a abertura de 9 cartas deixaria
  // a mão em [guard] sem descarte legal (o beco desta OS).
  j.mortos = _mortoDisponivelEnc('abertMult');
  return j;
}

// Mesa: canastra LIMPA 3..9 copas (45 pts de cartas + 200 de bônus).
Jogo _jgPontuacaoC10({required MotorConfig cfg}) {
  final j = _c10Base(cfg: cfg);
  j.jaComprou = true;
  j.mortoPego = {'nos': true, 'eles': true};
  j.jogosDupla['nos'] = [
    [
      Carta('c1', 'copas', '3', false),
      Carta('c2', 'copas', '4', false),
      Carta('c3', 'copas', '5', false),
      Carta('c4', 'copas', '6', false),
      Carta('c5', 'copas', '7', false),
      Carta('c6', 'copas', '8', false),
      Carta('c7', 'copas', '9', false),
    ]
  ];
  return j;
}

// FECHADO: sete ases baixados (trinca de 7 cartas). EXC-04.
Jogo _jgAsesC10({required MotorConfig cfg}) {
  final j = _c10Base(cfg: cfg, modalidade: 'FECHADO');
  j.jaComprou = true;
  j.mortoPego = {'nos': true, 'eles': true};
  j.jogosDupla['nos'] = [
    [
      Carta('a1', 'copas', 'A', false),
      Carta('a2', 'ouros', 'A', false),
      Carta('a3', 'paus', 'A', false),
      Carta('a4', 'espadas', 'A', false),
      Carta('a5', 'copas', 'A', false),
      Carta('a6', 'ouros', 'A', false),
      Carta('a7', 'paus', 'A', false),
    ]
  ];
  return j;
}

// Fase jogo; mão = EXATAMENTE [3c,4c,5c]; morto disponível -> morto DIRETO.
Jogo _jgBaixarEsvaziaMortoC10() {
  final j = _c10Base();
  j.jaComprou = true;
  j.monte = [Carta('mo1', 'copas', '2', false)];
  j.maos[0] = [
    Carta('3c', 'copas', '3', false),
    Carta('4c', 'copas', '4', false),
    Carta('5c', 'copas', '5', false),
  ];
  j.mortos = [
    [for (var i = 0; i < 11; i++) Carta('mk$i', 'ouros', '3', false)]
  ];
  j.lixo = [Carta('lx', 'espadas', '3', false)];
  return j;
}

// Fase jogo; mão = EXATAMENTE [h1]; morto disponível -> morto INDIRETO.
Jogo _jgDescarteEsvaziaMortoC10() {
  final j = _c10Base();
  j.jaComprou = true;
  j.monte = [Carta('mo1', 'copas', '2', false)];
  j.maos[0] = [Carta('h1', 'copas', '4', false)];
  j.mortos = [
    [for (var i = 0; i < 11; i++) Carta('mk$i', 'ouros', '3', false)]
  ];
  j.lixo = [Carta('lx', 'espadas', '3', false)];
  return j;
}

// Fase jogo; morto já pego + canastra limpa na mesa; mão = [Xc,Yc,Zc] -> BATIDA.
Jogo _jgBaterViaBaixarC10() {
  final j = _c10Base();
  j.jaComprou = true;
  j.monte = [Carta('mo1', 'copas', '2', false)];
  j.maos[0] = [
    Carta('Xc', 'copas', '10', false),
    Carta('Yc', 'copas', 'J', false),
    Carta('Zc', 'copas', 'Q', false),
  ];
  j.jogosDupla['nos'] = [
    [
      Carta('b1', 'ouros', '3', false),
      Carta('b2', 'ouros', '4', false),
      Carta('b3', 'ouros', '5', false),
      Carta('b4', 'ouros', '6', false),
      Carta('b5', 'ouros', '7', false),
      Carta('b6', 'ouros', '8', false),
      Carta('b7', 'ouros', '9', false),
    ]
  ];
  j.primeiraBaixadaFeita = {'nos': true, 'eles': false};
  j.mortoPego = {'nos': true, 'eles': false};
  j.lixo = [Carta('lx', 'espadas', '3', false)];
  return j;
}

// Fase compra, monte VAZIO + 1 morto disponível: §8.1 converte morto -> monte.
Jogo _jgMonteVazioMortoC10() {
  final j = _c10Base();
  j.jaComprou = false;
  j.mortos = [
    [for (var i = 0; i < 11; i++) Carta('mk$i', 'copas', '3', false)]
  ];
  j.maos[0] = [
    Carta('h1', 'copas', '4', false),
    Carta('h2', 'paus', '9', false),
  ];
  j.lixo = [Carta('lx', 'espadas', '3', false)];
  return j;
}

// Fase compra, monte E mortos VAZIOS: exaustão encerra a rodada.
Jogo _jgExaustoC10() {
  final j = _c10Base();
  j.jaComprou = false;
  j.maos[0] = [
    Carta('h1', 'copas', '4', false),
    Carta('h2', 'paus', '9', false),
  ];
  j.lixo = [Carta('lx', 'espadas', '3', false)];
  return j;
}

// FECHADO, fase compra. Topo 5c + mão (3c,4c) forma jogo; sobram cartas para o
// robô descartar depois, para o turno terminar pelo caminho normal.
Jogo _jgBotLixoFechadoC10() {
  final j = _c10Base(modalidade: 'FECHADO');
  j.jaComprou = false;
  j.monte = [
    Carta('mo1', 'paus', '8', false),
    Carta('mo2', 'paus', '9', false),
  ];
  j.mortos = [
    [for (var i = 0; i < 11; i++) Carta('mk$i', 'ouros', '3', false)]
  ];
  j.maos[0] = [
    Carta('3c', 'copas', '3', false),
    Carta('4c', 'copas', '4', false),
    Carta('kx', 'paus', 'K', false),
    Carta('qx', 'espadas', 'Q', false),
  ];
  j.lixo = [
    Carta('bur', 'ouros', '9', false),
    Carta('5c', 'copas', '5', false), // topo
  ];
  return j;
}

// Fase jogo; mão contém exatamente uma canastra LIMPA de 7 (3..9 copas) + sobra.
Jogo _jgCanastraC10() {
  final j = _c10Base();
  j.jaComprou = true;
  j.monte = [Carta('mo1', 'paus', '2', false)];
  j.maos[0] = [
    Carta('c1', 'copas', '3', false),
    Carta('c2', 'copas', '4', false),
    Carta('c3', 'copas', '5', false),
    Carta('c4', 'copas', '6', false),
    Carta('c5', 'copas', '7', false),
    Carta('c6', 'copas', '8', false),
    Carta('c7', 'copas', '9', false),
    Carta('sobra', 'paus', 'K', false),
  ];
  j.lixo = [Carta('lx', 'espadas', '3', false)];
  return j;
}

// Os três cenários de compra do lixo Fechado — agora em CONFIG DE PRODUÇÃO.
// Os homônimos da Parte 1 nascem em config legada de propósito: lá o alvo era o
// DERIVADOR (chamado direto). Aqui o alvo é o CONSUMIDOR, que só existe com a
// autoridade ligada.

// 1 candidato: topo 5c + mão (3c,4c) formam 3-4-5 copas. 'ent' fica enterrada.
Jogo _jgAtomicoUmC10() {
  final j = _c10Base(modalidade: 'FECHADO');
  j.jaComprou = false;
  j.monte = [Carta('mo1', 'copas', '7', false)];
  j.maos[0] = [
    Carta('3c', 'copas', '3', false),
    Carta('4c', 'copas', '4', false),
    Carta('rp', 'paus', 'K', false), // reserva: a mão não esvazia
  ];
  j.lixo = [
    Carta('ent', 'ouros', '9', false),
    Carta('5c', 'copas', '5', false), // topo
  ];
  return j;
}

// 2+ candidatos: topo 6c estende 3-4-5 na mesa E fecha 6-7-8 com a mão.
Jogo _jgAtomicoDoisC10() {
  final j = _c10Base(modalidade: 'FECHADO');
  j.jaComprou = false;
  j.primeiraBaixadaFeita = {'nos': true, 'eles': false};
  j.monte = [Carta('mo1', 'copas', '2', false)];
  j.jogosDupla['nos'] = [
    [
      Carta('3c', 'copas', '3', false),
      Carta('4c', 'copas', '4', false),
      Carta('5c', 'copas', '5', false),
    ]
  ];
  j.maos[0] = [
    Carta('7c', 'copas', '7', false),
    Carta('8c', 'copas', '8', false),
    Carta('9s', 'espadas', '9', false),
  ];
  j.lixo = [
    Carta('ent', 'ouros', '2', false),
    Carta('6c', 'copas', '6', false), // topo
  ];
  return j;
}

// 0 candidatos: topo K paus não forma jogo nem estende nada.
Jogo _jgSemUsoC10() {
  final j = _c10Base(modalidade: 'FECHADO');
  j.jaComprou = false;
  j.monte = [Carta('mo1', 'copas', '7', false)];
  j.maos[0] = [
    Carta('3o', 'ouros', '3', false),
    Carta('8s', 'espadas', '8', false),
  ];
  j.lixo = [
    Carta('ent', 'copas', '9', false),
    Carta('topoK', 'paus', 'K', false), // topo
  ];
  return j;
}

// ELES pegou o seu morto; o morto de NÓS foi CONVERTIDO em monte (§8.1).
// NÓS não pegou morto nenhum — e paga o -100 mesmo assim.
Jogo _jgPenalidadeAposConversaoC10({required MotorConfig cfg}) {
  final j = _c10Base(cfg: cfg);
  j.jaComprou = true;
  j.mortos = <List<Carta>>[]; // um foi pego, o outro virou monte
  j.mortoPego = {'nos': false, 'eles': true};
  j.costuraMortosConvertidos = 1; // a conversão aconteceu e está registrada
  j.jogosDupla['eles'] = [
    [
      Carta('e1', 'ouros', '3', false),
      Carta('e2', 'ouros', '4', false),
      Carta('e3', 'ouros', '5', false),
    ]
  ];
  j.primeiraBaixadaFeita = {'nos': false, 'eles': true};
  return j;
}

// Fase JOGO com VÁRIOS grupos baixáveis: se o robô não parasse na primeira
// falha técnica, tentaria o segundo e o terceiro grupo.
Jogo _jgBotBaixarMuitosGruposC10() {
  final j = _c10Base();
  j.jaComprou = true;
  j.monte = [Carta('mo1', 'paus', '2', false)];
  j.maos[0] = [
    Carta('3c', 'copas', '3', false),
    Carta('4c', 'copas', '4', false),
    Carta('5c', 'copas', '5', false),
    Carta('9o', 'ouros', '9', false),
    Carta('10o', 'ouros', '10', false),
    Carta('Jo', 'ouros', 'J', false),
    Carta('5e', 'espadas', '5', false),
    Carta('6e', 'espadas', '6', false),
    Carta('7e', 'espadas', '7', false),
    Carta('sobra', 'paus', 'K', false),
  ];
  j.lixo = [Carta('lx', 'espadas', '3', false)];
  return j;
}

// Fase JOGO com DOIS jogos na mesa e cartas que estendem os dois: se o robô não
// parasse na primeira falha técnica, tentaria a segunda extensão.
Jogo _jgBotEstenderC10() {
  final j = _c10Base();
  j.jaComprou = true;
  j.monte = [Carta('mo1', 'paus', '2', false)];
  j.primeiraBaixadaFeita = {'nos': true, 'eles': false};
  j.jogosDupla['nos'] = [
    [
      Carta('a1', 'copas', '3', false),
      Carta('a2', 'copas', '4', false),
      Carta('a3', 'copas', '5', false),
    ],
    [
      Carta('b1', 'ouros', '9', false),
      Carta('b2', 'ouros', '10', false),
      Carta('b3', 'ouros', 'J', false),
    ],
  ];
  j.maos[0] = [
    Carta('6c', 'copas', '6', false), // estende o 1º
    Carta('Qo', 'ouros', 'Q', false), // estende o 2º
    Carta('sobra', 'paus', 'K', false),
  ];
  j.lixo = [Carta('lx', 'espadas', '3', false)];
  return j;
}

// Turno simples que termina em DESCARTE: nada para baixar nem estender.
Jogo _jgBotDescarteC10() {
  final j = _c10Base();
  j.jaComprou = false;
  j.monte = [
    Carta('mo1', 'paus', '8', false),
    Carta('mo2', 'ouros', '2', false),
  ];
  j.maos[0] = [
    Carta('d1', 'copas', '4', false),
    Carta('d2', 'espadas', '9', false),
    Carta('d3', 'paus', 'Q', false),
  ];
  j.lixo = [Carta('lx', 'espadas', '3', false)];
  return j;
}

// Dupla VULNERÁVEL (mínimo 75) e ainda sem abrir. Três sequências de 3 cartas:
// 15 + 30 + 35 = 80. Nenhuma isolada atinge 75 — só a abertura COMPOSTA abre.
Jogo _jgBotAberturaCompostaC10() {
  final j = _c10Base();
  j.jaComprou = true;
  j.rodadasVulneravel = {'nos': 1, 'eles': 0};
  j.monte = [Carta('mo1', 'paus', '2', false)];
  j.maos[0] = [
    Carta('3c', 'copas', '3', false),
    Carta('4c', 'copas', '4', false),
    Carta('5c', 'copas', '5', false),
    Carta('Jo', 'ouros', 'J', false),
    Carta('Qo', 'ouros', 'Q', false),
    Carta('Ko', 'ouros', 'K', false),
    Carta('Qe', 'espadas', 'Q', false),
    Carta('Ke', 'espadas', 'K', false),
    Carta('Ae', 'espadas', 'A', false),
    Carta('guard', 'paus', '8', false), // sobra: a abertura não zera a mão
  ];
  j.lixo = [Carta('lx', 'espadas', '3', false)];
  // OS ENCERRAMENTO: morto disponível. É esta linha que separa o cenário
  // LEGÍTIMO de abertura composta (aqui) do BECO do C10-BOT-03 — veja
  // `_jgBotAberturaCompostaBecoC10`, que é este mesmo fixture SEM morto.
  j.mortos = _mortoDisponivelEnc('botComposta');
  return j;
}

/// C10-BOT-03 na forma ORIGINAL (histórica): a mesma abertura composta, porém
/// SEM morto a pegar e SEM canastra na mesa. Abrir consome 9 das 10 cartas e
/// deixa [guard] sem descarte legal — o beco que esta OS corrige. Preservado
/// literalmente para provar o antes/depois do caso nomeado na OS.
Jogo _jgBotAberturaCompostaBecoC10() {
  final j = _jgBotAberturaCompostaC10();
  j.mortos = <List<Carta>>[];
  j.mortoPego = {'nos': true, 'eles': true};
  return j;
}

// Fase jogo, dupla já abriu (sem mínimo). Seleção 3..8 de copas: pode virar UM
// jogo de 6 cartas OU dois jogos de 3 — partição ambígua de verdade.
Jogo _jgSelecaoAmbiguaC10() {
  final j = _c10Base();
  j.jaComprou = true;
  j.primeiraBaixadaFeita = {'nos': true, 'eles': false};
  j.monte = [Carta('mo1', 'paus', '2', false)];
  j.maos[0] = [
    Carta('a3', 'copas', '3', false),
    Carta('a4', 'copas', '4', false),
    Carta('a5', 'copas', '5', false),
    Carta('a6', 'copas', '6', false),
    Carta('a7', 'copas', '7', false),
    Carta('a8', 'copas', '8', false),
    Carta('guard', 'paus', 'K', false), // sobra: a baixada não zera a mão
  ];
  j.lixo = [Carta('lx', 'espadas', '3', false)];
  // OS ENCERRAMENTO: a "carta guarda" sozinha NÃO bastava — sobrar 1 carta sem
  // morto e sem canastra é o beco. O morto é o que dá saída legal ao turno.
  j.mortos = _mortoDisponivelEnc('ambigua');
  return j;
}

// C10 (rev.3) — fase de JOGO com uma única carta na mão, sem morto disponível
// (os dois já foram pegos) e sem canastra que libere a batida. Descartar a
// última carta é RECUSADO POR REGRA ("esvaziar a mão é regra"), e não há outra
// carta para tentar: é o cenário em que todas as opções de descarte falham por
// regra, sem nenhuma falha técnica.
Jogo _jgAutoSemDescarteLegalC10() {
  final j = _c10Base();
  j.jaComprou = true;
  j.monte = [Carta('mo1', 'paus', '8', false)];
  j.mortos = <List<Carta>>[];
  j.mortoPego = {'nos': true, 'eles': true};
  j.primeiraBaixadaFeita = {'nos': true, 'eles': false};
  j.maos[0] = [Carta('u1', 'copas', '4', false)];
  // Jogo de 3 cartas na mesa: existe baixada, mas NÃO é canastra — não libera
  // a batida, então o descarte que zera a mão continua ilegal.
  j.jogosDupla['nos'] = [
    [
      Carta('n1', 'ouros', '3', false),
      Carta('n2', 'ouros', '4', false),
      Carta('n3', 'ouros', '5', false),
    ]
  ];
  j.lixo = [Carta('lx', 'espadas', '3', false)];
  return j;
}

// ===================================================================
// OS BOT-IA V1 — helpers e mesas determinísticas
//
// Nenhum cenário sorteia carta: todas as mesas são montadas à mão, sob a
// autoridade canônica (é lá que o robô estratégico vive). As mãos dos outros
// assentos existem só para dar CONTAGEM pública realista — o conteúdo delas é
// irrelevante por construção, e o BOTIA-15 prova isso.
// ===================================================================

/// Carta de teste com a flag de curinga coerente com o valor.
Carta _bc(String id, String valor, String? naipe) =>
    Carta(id, naipe, valor, valor == '2' || valor == 'JOKER');

/// Enchimento das mãos alheias: só o TAMANHO importa (informação pública).
List<Carta> _enchimento(int assento, int n) =>
    [for (var i = 0; i < n; i++) _bc('f${assento}_$i', '7', 'paus')];

/// Mesa canônica base: fase de JOGO, dupla NOS já aberta (sem mínimo em jogo),
/// sem morto disponível e sem ameaça adversária. Cada cenário muda só o que
/// quer testar.
Jogo _botBase({
  String modalidade = 'ABERTO',
  ConfiguracaoBot? cfg,
  RegrasEstrategicas? regras,
  PesosHeuristicos? pesos,
  int seed = 0,
}) {
  final j = Jogo.paraCostura(motorConfig: MotorConfig.producao());
  j.vez = 0;
  j.jaComprou = true; // fase de jogo
  j.modalidade = modalidade;
  j.mortoPego = {'nos': false, 'eles': false};
  j.primeiraBaixadaFeita = {'nos': true, 'eles': false};
  j.rodadasVulneravel = {'nos': 0, 'eles': 0};
  j.maos = [
    <Carta>[],
    _enchimento(1, 8),
    _enchimento(2, 8),
    _enchimento(3, 8),
  ];
  j.jogosDupla = {'nos': <List<Carta>>[], 'eles': <List<Carta>>[]};
  j.monte = [_bc('bm1', '7', 'paus')];
  j.mortos = <List<Carta>>[];
  j.lixo = [_bc('blx', '3', 'espadas')];
  j.configuracaoBot = cfg ??
      ConfiguracaoBot(
        pesos: pesos ?? const PesosHeuristicos(),
        regras: regras ?? const RegrasEstrategicas(),
        seed: seed,
      );
  return j;
}

/// Decisão da camada estratégica para a fase de jogo do assento.
DecisaoBot _decisaoJogo(Jogo j, {int assento = 0}) =>
    ExecutorBot(j.specCanonica, cfg: j.configuracaoBot)
        .decidirJogo(paraCanonico(j).canonico, assento);

/// Todos os planos gerados (antes da escolha) — usado para provar que uma
/// alternativa existe ou que o filtro a removeu.
List<PlanoTurno> _planosDe(Jogo j, {int assento = 0}) =>
    GeradorPlanos(j.specCanonica, j.configuracaoBot)
        .planosDeJogo(paraCanonico(j).canonico, assento)
        .planos;

/// Id da carta descartada pela decisão (null se o plano não descarta).
String? _descarteDe(DecisaoBot d) {
  for (final a in d.acoes) {
    if (a is Descartar) return a.carta;
  }
  return null;
}

/// Ids consumidos por uma baixada (jogos novos + extensões).
Set<String> _idsDaBaixada(Baixar b) => {
      for (final g in b.jogosNovos) ...g,
      for (final e in b.extensoes) ...e.cartas,
    };

/// Mão do cenário de dano estrutural (5h-6h encostados, 8h a duas casas do 6h,
/// Kc totalmente solto).
List<Carta> _maoDanoEstrutural() => [
      _bc('c5h', '5', 'copas'),
      _bc('c6h', '6', 'copas'),
      _bc('c8h', '8', 'copas'),
      _bc('cKc', 'K', 'paus'),
    ];

/// §1 — a dupla abriu 4-5-6 de copas. Na mão, o 8h ainda NÃO estende (falta o
/// 7), mas é a extensão natural seguinte. As outras três cartas são soltas e
/// valem os mesmos 10 pontos: sem a regra do parceiro, as quatro empatam.
Jogo _fixParceiroAdjacente({int seed = 0, RegrasEstrategicas? regras}) {
  final j = _botBase(seed: seed, regras: regras);
  j.jogosDupla['nos'] = [
    [
      _bc('m4h', '4', 'copas'),
      _bc('m5h', '5', 'copas'),
      _bc('m6h', '6', 'copas'),
    ]
  ];
  j.maos[0] = [
    _bc('c8h', '8', 'copas'),
    _bc('cKc', 'K', 'paus'),
    _bc('cKs', 'K', 'espadas'),
    _bc('cQd', 'Q', 'ouros'),
  ];
  return j;
}

/// §2 — ELES têm 10-J-Q de copas na mesa; o Kh completa. As outras três cartas
/// da mão são inertes e valem os mesmos 10 pontos.
Jogo _fixAlimentaAdversario({int seed = 0, RegrasEstrategicas? regras}) {
  final j = _botBase(seed: seed, regras: regras);
  j.primeiraBaixadaFeita = {'nos': true, 'eles': true};
  j.jogosDupla['eles'] = [
    [
      _bc('e10h', '10', 'copas'),
      _bc('eJh', 'J', 'copas'),
      _bc('eQh', 'Q', 'copas'),
    ]
  ];
  j.maos[0] = [
    _bc('cKh', 'K', 'copas'),
    _bc('cKc', 'K', 'paus'),
    _bc('cKs', 'K', 'espadas'),
    _bc('cQd', 'Q', 'ouros'),
  ];
  return j;
}

/// §3 — canastra LIMPA de 7 (3..9 de copas) na mesa da dupla. O 2 de espadas
/// estende como curinga e SUJARIA a limpa; é a "conveniência" que a OS proíbe.
Jogo _fixCanastraLimpa({RegrasEstrategicas? regras}) {
  final j = _botBase(regras: regras);
  j.jogosDupla['nos'] = [
    [
      _bc('l3h', '3', 'copas'),
      _bc('l4h', '4', 'copas'),
      _bc('l5h', '5', 'copas'),
      _bc('l6h', '6', 'copas'),
      _bc('l7h', '7', 'copas'),
      _bc('l8h', '8', 'copas'),
      _bc('l9h', '9', 'copas'),
    ]
  ];
  j.maos[0] = [
    _bc('c2s', '2', 'espadas'), // curinga: entra como o 10 e suja a limpa
    _bc('cKc', 'K', 'paus'),
    _bc('cKs', 'K', 'espadas'),
    _bc('cQd', 'Q', 'ouros'),
  ];
  return j;
}

/// §3 — dupla VULNERÁVEL (mínimo 75) e ainda sem abrir, com dois caminhos:
///   natural: J-Q-K-A de ouros (45) + Q-K-A de espadas (35) = 80;
///   curinga: Joker + K-A de copas = 75 num jogo só.
/// Os dois abrem legalmente; só um preserva o Joker.
Jogo _fixDoisCaminhosDeAbertura({RegrasEstrategicas? regras}) {
  final j = _botBase(regras: regras);
  j.primeiraBaixadaFeita = {'nos': false, 'eles': false};
  j.rodadasVulneravel = {'nos': 1, 'eles': 0};
  j.maos[0] = [
    _bc('cJd', 'J', 'ouros'),
    _bc('cQd', 'Q', 'ouros'),
    _bc('cKd', 'K', 'ouros'),
    _bc('cAd', 'A', 'ouros'),
    _bc('cQs', 'Q', 'espadas'),
    _bc('cKs', 'K', 'espadas'),
    _bc('cAs', 'A', 'espadas'),
    _bc('cKh', 'K', 'copas'),
    _bc('cAh', 'A', 'copas'),
    _bc('cjk', 'JOKER', null),
    _bc('cSobra', '9', 'paus'),
  ];
  return j;
}

/// §3 — aqui o curinga É decisivo: com ele a mão zera e a dupla PEGA O MORTO.
Jogo _fixCuringaDecisivoMorto({RegrasEstrategicas? regras}) {
  final j = _botBase(regras: regras);
  j.mortos = [
    [
      for (var i = 0; i < 11; i++)
        _bc('mk$i', i.isEven ? '3' : '4', i.isEven ? 'ouros' : 'paus')
    ]
  ];
  j.maos[0] = [
    _bc('cKs', 'K', 'espadas'),
    _bc('cAs', 'A', 'espadas'),
    _bc('cjk', 'JOKER', null), // entra como a dama de espadas
  ];
  return j;
}

/// §4 — corrida promissora de cinco cartas na mão. Baixá-la é LEGAL e o bot
/// pode; a questão é se ele deve.
Jogo _fixCorridaPromissora(
    {RegrasEstrategicas? regras, PesosHeuristicos? pesos}) {
  final j = _botBase(regras: regras, pesos: pesos);
  j.jogosDupla['nos'] = [
    [_bc('m3c', '3', 'paus'), _bc('m4c', '4', 'paus'), _bc('m5c', '5', 'paus')]
  ];
  j.maos[0] = [
    _bc('c5h', '5', 'copas'),
    _bc('c6h', '6', 'copas'),
    _bc('c7h', '7', 'copas'),
    _bc('c8h', '8', 'copas'),
    _bc('c9h', '9', 'copas'),
    _bc('cKc', 'K', 'paus'),
    _bc('cQd', 'Q', 'ouros'),
  ];
  return j;
}

/// §4 — a extensão é legal e rende progresso, mas consome a ÚNICA carta que o
/// bot poderia largar em segurança: o turno terminaria entregando ao adversário
/// exatamente o que ele precisa. Só quem simula o DESCARTE junto com a baixada
/// enxerga isso — olhando só para a baixada, estender parece bom negócio.
Jogo _fixBaixarForcaDescartePerigoso({RegrasEstrategicas? regras}) {
  final j = _botBase(regras: regras);
  j.primeiraBaixadaFeita = {'nos': true, 'eles': true};
  j.jogosDupla['nos'] = [
    [_bc('m3c', '3', 'paus'), _bc('m4c', '4', 'paus'), _bc('m5c', '5', 'paus')]
  ];
  j.jogosDupla['eles'] = [
    [
      _bc('e10h', '10', 'copas'),
      _bc('eJh', 'J', 'copas'),
      _bc('eQh', 'Q', 'copas'),
    ]
  ];
  j.maos[0] = [
    _bc('c6c', '6', 'paus'), // estende o jogo da dupla — e é o descarte seguro
    _bc('cKh', 'K', 'copas'), // completa o jogo deles por cima
    _bc('c9h', '9', 'copas'), // e este completa por baixo
  ];
  return j;
}

/// §6/§11 — a baixada zera a mão e a dupla PEGA O MORTO no meio do turno: o
/// plano antigo deixa de valer e o robô precisa decidir de novo.
Jogo _fixMortoDireto() {
  final j = _botBase();
  j.mortos = [
    [
      _bc('mk0', '3', 'ouros'),
      _bc('mk1', '5', 'ouros'),
      _bc('mk2', '7', 'ouros'),
      _bc('mk3', '9', 'ouros'),
      _bc('mk4', 'J', 'ouros'),
      _bc('mk5', 'K', 'ouros'),
      _bc('mk6', '3', 'paus'),
      _bc('mk7', '5', 'paus'),
      _bc('mk8', '7', 'paus'),
      _bc('mk9', '9', 'paus'),
      _bc('mk10', 'J', 'paus'),
    ]
  ];
  j.maos[0] = [
    _bc('cQs', 'Q', 'espadas'),
    _bc('cKs', 'K', 'espadas'),
    _bc('cAs', 'A', 'espadas'),
  ];
  return j;
}

/// §6 — bater É legal (canastra limpa na mesa, morto já cumprido), mas o
/// parceiro está com a mão cheia e NENHUM adversário ameaça fechar.
Jogo _fixBatidaPrematura({RegrasEstrategicas? regras}) {
  final j = _botBase(regras: regras);
  j.mortoPego = {'nos': true, 'eles': false};
  j.mortos = <List<Carta>>[];
  j.jogosDupla['nos'] = [
    [
      _bc('l3h', '3', 'copas'),
      _bc('l4h', '4', 'copas'),
      _bc('l5h', '5', 'copas'),
      _bc('l6h', '6', 'copas'),
      _bc('l7h', '7', 'copas'),
      _bc('l8h', '8', 'copas'),
      _bc('l9h', '9', 'copas'),
    ]
  ];
  j.maos = [
    [
      _bc('cQs', 'Q', 'espadas'),
      _bc('cKs', 'K', 'espadas'),
      _bc('cAs', 'A', 'espadas'),
    ],
    _enchimento(1, 9), // sem ameaça: mão longa
    _enchimento(2, 11), // parceiro CARREGADO
    _enchimento(3, 9),
  ];
  return j;
}

/// §13 — vulnerável (mínimo 75) com DUAS aberturas de 80 pontos: espadas (45)
/// + ouros (35), que consome peças soltas, ou espadas + copas, que quebraria a
/// corrida de seis. Mesmos pontos, danos estruturais muito diferentes.
Jogo _fixAberturaComEscolha() {
  final j = _botBase();
  j.primeiraBaixadaFeita = {'nos': false, 'eles': false};
  j.rodadasVulneravel = {'nos': 1, 'eles': 0};
  j.maos[0] = [
    _bc('cJs', 'J', 'espadas'),
    _bc('cQs', 'Q', 'espadas'),
    _bc('cKs', 'K', 'espadas'),
    _bc('cAs', 'A', 'espadas'),
    _bc('cQd', 'Q', 'ouros'),
    _bc('cKd', 'K', 'ouros'),
    _bc('cAd', 'A', 'ouros'),
    _bc('c3h', '3', 'copas'),
    _bc('c4h', '4', 'copas'),
    _bc('c5h', '5', 'copas'),
    _bc('c6h', '6', 'copas'),
    _bc('c7h', '7', 'copas'),
    _bc('c8h', '8', 'copas'),
    _bc('cSobra', '9', 'paus'),
  ];
  return j;
}

/// §7 — duas mesas com o MESMO estado público (mesma mão própria, mesmos jogos
/// expostos, mesmo topo do lixo, mesmas contagens) e TODO o oculto diferente:
/// mãos alheias, monte, morto e a carta ENTERRADA do lixo.
Jogo _fixInformacaoJusta({required int variante}) {
  final j = _botBase();
  final v = variante;
  j.jogosDupla['nos'] = [
    [_bc('m3c', '3', 'paus'), _bc('m4c', '4', 'paus'), _bc('m5c', '5', 'paus')]
  ];
  j.maos[0] = [
    _bc('c5h', '5', 'copas'),
    _bc('c6h', '6', 'copas'),
    _bc('c8h', '8', 'copas'),
    _bc('cKc', 'K', 'paus'),
  ];
  // ---- oculto: muda tudo entre as variantes, mantendo as CONTAGENS ----
  j.maos[1] = [
    for (var i = 0; i < 8; i++)
      _bc('h1_${v}_$i', v == 0 ? '7' : 'A', v == 0 ? 'paus' : 'copas')
  ];
  j.maos[2] = [
    for (var i = 0; i < 8; i++)
      _bc('h2_${v}_$i', v == 0 ? '9' : 'K', v == 0 ? 'ouros' : 'espadas')
  ];
  j.maos[3] = [
    for (var i = 0; i < 8; i++)
      _bc('h3_${v}_$i', v == 0 ? '4' : 'JOKER', v == 0 ? 'espadas' : null)
  ];
  j.monte = [
    for (var i = 0; i < 5; i++)
      _bc('mo_${v}_$i', v == 0 ? '3' : '2', v == 0 ? 'copas' : 'ouros')
  ];
  j.mortos = [
    [
      for (var i = 0; i < 11; i++)
        _bc('mk_${v}_$i', v == 0 ? '6' : 'Q', v == 0 ? 'paus' : 'copas')
    ]
  ];
  // O TOPO do lixo é idêntico; a carta ENTERRADA é que muda.
  j.lixo = [
    _bc('ent_$v', v == 0 ? '10' : '2', v == 0 ? 'paus' : 'copas'),
    _bc('blx', '3', 'espadas'), // topo visível, igual nas duas
  ];
  return j;
}

/// Snapshot serializado do `Jogo` (mesmo instrumento dos testes do C10, aqui em
/// nível de arquivo porque os cenários do bot vivem noutro grupo).
String _snapJogo(Jogo j) => jsonEncode(serializarProjecao(paraCanonico(j)));

// ===================================================================
// OS ENCERRAMENTO DE TURNO V1 — mesas determinísticas
//
// Todas partem do mesmo terreno: fase de JOGO (já comprou), dupla NOS já
// aberta, e o que varia é só a EXISTÊNCIA de saída legal depois da baixada
// (morto disponível, canastra na mesa, ou nenhuma das duas = beco).
// ===================================================================

/// Terreno base: assento 0 na fase de jogo, dupla NOS aberta, sem canastra.
/// `mortosRestantes = 0` + `mortoPego` nos dois lados = não há morto a pegar.
Jogo _encBase({
  String modalidade = 'ABERTO',
  int mortosRestantes = 0,
  bool mortoPegoNos = true,
  bool abertaNos = true,
  int rodadasVulneravel = 0,
}) {
  final j = Jogo.paraCostura(motorConfig: MotorConfig.producao());
  j.vez = 0;
  j.modalidade = modalidade;
  j.jaComprou = true;
  j.mortoPego = {'nos': mortoPegoNos, 'eles': true};
  j.primeiraBaixadaFeita = {'nos': abertaNos, 'eles': false};
  j.rodadasVulneravel = {'nos': rodadasVulneravel, 'eles': 0};
  j.maos = [<Carta>[], <Carta>[], <Carta>[], <Carta>[]];
  j.jogosDupla = {'nos': <List<Carta>>[], 'eles': <List<Carta>>[]};
  j.monte = [Carta('mo1', 'paus', '8', false)];
  j.mortos = [
    for (var k = 0; k < mortosRestantes; k++)
      [for (var i = 0; i < 11; i++) Carta('mk${k}_$i', 'ouros', '3', false)]
  ];
  j.lixo = [Carta('lx', 'espadas', '3', false)];
  return j;
}

/// Meld de 3 cartas na mesa da dupla: existe jogo exposto, mas NÃO é canastra —
/// portanto não libera a batida.
List<Carta> _encMeldCurto() => [
      Carta('n1', 'ouros', '3', false),
      Carta('n2', 'ouros', '4', false),
      Carta('n3', 'ouros', '5', false),
    ];

/// Canastra LIMPA de 7 cartas (libera batida no ABERTO e no FECHADO).
List<Carta> _encCanastra() => [
      for (final v in ['3', '4', '5', '6', '7', '8', '9'])
        Carta('cn$v', 'paus', v, false),
    ];

/// C10-BOT-03 — BECO: baixar 7-8-9 de copas deixa [orfa] na mão, sem morto a
/// pegar e sem canastra para bater. Nenhum descarte é legal depois disso.
Jogo _jgEncBecoSemSaida({String modalidade = 'ABERTO'}) {
  final j = _encBase(modalidade: modalidade);
  j.maos[0] = [
    Carta('7c', 'copas', '7', false),
    Carta('8c', 'copas', '8', false),
    Carta('9c', 'copas', '9', false),
    Carta('orfa', 'paus', 'K', false),
  ];
  j.jogosDupla['nos'] = [_encMeldCurto()];
  return j;
}

/// Mesma baixada, mas COM morto disponível: sobra 1 carta e o descarte dela é
/// legal (zera a mão -> morto indireto). Tem de continuar permitida.
Jogo _jgEncUmaCartaComMorto() {
  final j = _encBase(mortosRestantes: 1, mortoPegoNos: false);
  j.maos[0] = [
    Carta('7c', 'copas', '7', false),
    Carta('8c', 'copas', '8', false),
    Carta('9c', 'copas', '9', false),
    Carta('orfa', 'paus', 'K', false),
  ];
  j.jogosDupla['nos'] = [_encMeldCurto()];
  return j;
}

/// Mesma baixada, mas COM canastra limpa na mesa: sobra 1 carta e descartá-la é
/// BATIDA legal. Tem de continuar permitida.
Jogo _jgEncUmaCartaComCanastra() {
  final j = _encBase();
  j.maos[0] = [
    Carta('7c', 'copas', '7', false),
    Carta('8c', 'copas', '8', false),
    Carta('9c', 'copas', '9', false),
    Carta('orfa', 'paus', 'K', false),
  ];
  j.jogosDupla['nos'] = [_encCanastra()];
  return j;
}

/// A baixada deixa DUAS cartas: o descarte normal existe, nada a bloquear.
Jogo _jgEncDuasSobrando() {
  final j = _encBase();
  j.maos[0] = [
    Carta('7c', 'copas', '7', false),
    Carta('8c', 'copas', '8', false),
    Carta('9c', 'copas', '9', false),
    Carta('orfa1', 'paus', 'K', false),
    Carta('orfa2', 'espadas', 'Q', false),
  ];
  j.jogosDupla['nos'] = [_encMeldCurto()];
  return j;
}

/// Beco cujo meld usa CURINGA: `jk` (JOKER) ou `d2` (o "2" curinga).
Jogo _jgEncBecoComCuringa(String curinga) {
  final j = _encBase();
  j.maos[0] = [
    Carta('7c', 'copas', '7', false),
    Carta('8c', 'copas', '8', false),
    curinga == 'jk'
        ? Carta('jk', null, 'JOKER', true)
        : Carta('d2', 'ouros', '2', true),
    Carta('orfa', 'paus', 'K', false),
  ];
  j.jogosDupla['nos'] = [_encMeldCurto()];
  return j;
}

/// ABERTURA que ATINGE o mínimo de vulnerabilidade (40+40 = 80 >= 75) e ainda
/// assim deixaria a mão em [orfa] sem saída. Prova que a recusa é do beco, não
/// do mínimo.
Jogo _jgEncAberturaBeco({required int rodadasVulneravel}) {
  final j = _encBase(
    abertaNos: false,
    rodadasVulneravel: rodadasVulneravel,
  );
  j.maos[0] = [
    for (final v in ['10', 'J', 'Q', 'K']) Carta('${v}c', 'copas', v, false),
    for (final v in ['10', 'J', 'Q', 'K']) Carta('${v}o', 'ouros', v, false),
    Carta('orfa', 'paus', '4', false),
  ];
  j.jogosDupla['nos'] = <List<Carta>>[];
  return j;
}

/// FECHADO — compra do lixo com uso ATÔMICO do topo que consumiria a mão e
/// deixaria uma carta órfã sem descarte legal.
Jogo _jgEncLixoBeco() {
  final j = _encBase(modalidade: 'FECHADO');
  j.jaComprou = false; // fase de COMPRA
  j.maos[0] = [
    Carta('8c', 'copas', '8', false),
    Carta('9c', 'copas', '9', false),
    Carta('orfa', 'paus', 'K', false),
  ];
  j.jogosDupla['nos'] = [_encMeldCurto()];
  // Lixo de UMA carta (o topo): comprá-lo traz só ela para a mão. O uso atômico
  // do topo fecha 7-8-9 com a mão e deixa exatamente [orfa] — o mesmo beco, por
  // outro portão. Com o lixo mais fundo a mão sobraria com 2+ cartas e haveria
  // descarte legal (foi o que a 1ª versão deste fixture provou por acidente).
  j.lixo = [Carta('lxTopo', 'copas', '7', false)];
  return j;
}

/// OS ENCERRAMENTO DE TURNO V1 — MORTO disponível (11 cartas) para fixtures que
/// deixam UMA carta na mão depois da jogada.
///
/// Por que existe: vários fixtures do C10/C7 usavam o idioma "carta guarda"
/// (`// sobra: a baixada NÃO zera a mão`) acreditando que sobrar 1 carta era
/// seguro. Sem morto a pegar e sem canastra na mesa, sobrar 1 carta é
/// exatamente o BECO desta OS — descartá-la esvazia a mão, e esvaziar é ilegal.
/// Os fixtures codificavam o defeito sem querer.
///
/// A correção preserva o que cada teste mede: dar morto à dupla NÃO muda mão,
/// mesa nem a combinatória de candidatos/partições — só devolve ao jogador a
/// saída legal que o cenário real teria. Nenhuma asserção foi afrouxada.
List<List<Carta>> _mortoDisponivelEnc(String tag) => [
      [for (var i = 0; i < 11; i++) Carta('mt${tag}_$i', 'ouros', '3', false)]
    ];
