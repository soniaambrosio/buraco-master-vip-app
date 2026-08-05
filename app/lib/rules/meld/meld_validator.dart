// C2 — validador de MELD canônico (a partir da spec, não cópia do motor antigo).
// SEM comportamento de produção: nada no app importa este arquivo; o motor
// antigo (class Jogo) continua padrão. Só a suíte de testes usa isto.
//
// Regras canônicas cobertas:
//  - Sequência: cartas naturais de UM único naipe, ranks contíguos, no máximo
//    1 curinga (Joker ou "2" contextual). Ás baixo (A-2-3) ou alto (Q-K-A),
//    sem dar a volta.
//  - Trinca: SOMENTE natural, mesmo valor, sem curinga (Joker e "2" fora);
//    três "2" naturais é trinca de 2. Permitida apenas no Fechado. Nunca vira
//    canastra (sem bônus) e não libera batida.
//  - "2" é interpretado de forma contextual, escolhendo a leitura legal mais
//    limpa (menos curingas). Uma carta nunca é natural e curinga ao mesmo tempo.
import '../estado.dart' show CartaSnapshot;
import '../modalidade.dart';
import '../rule_spec.dart';

/// Papel de cada carta dentro do meld interpretado (posição canônica).
class UsoCarta {
  final String id;
  final String papel; // 'natural' | 'curinga'
  final int posicao; // índice canônico dentro do meld (0-based)
  const UsoCarta(this.id, this.papel, this.posicao);
}

class ResultadoMeld {
  final bool valido;
  final String? motivo;
  final String? tipo; // 'sequencia' | 'trinca'
  final String? classificacao; // 'limpa' | 'suja' (sequência) | 'trinca'
  final int qtdCuringas;
  final String? naipeCanonico; // naipe da sequência; null na trinca
  final bool canastra; // C2: trinca sempre false; sequência não classificada aqui
  final bool liberaBatida; // C2: trinca sempre false (regra canônica)
  final List<UsoCarta> usos; // papel/posição de cada carta (ordem canônica)
  final List<CartaSnapshot> ordenado; // meld em ordem canônica (IDs preservados)
  final String assinatura; // assinatura canônica, independente da ordem de entrada

  const ResultadoMeld({
    required this.valido,
    this.motivo,
    this.tipo,
    this.classificacao,
    this.qtdCuringas = 0,
    this.naipeCanonico,
    this.canastra = false,
    this.liberaBatida = false,
    this.usos = const [],
    this.ordenado = const [],
    this.assinatura = '',
  });

  factory ResultadoMeld.invalido(String motivo) =>
      ResultadoMeld(valido: false, motivo: motivo);

  /// Posições (0-based) ocupadas por curinga, em ordem canônica.
  List<int> get posicoesCuringa =>
      [for (final u in usos) if (u.papel == 'curinga') u.posicao];
}

/// Ordem base dos valores; rank natural = índice + 1 (A=1 .. K=13). O ás também
/// pode valer 14 (alto). "2" natural = rank 2.
const List<String> _ordemValores = [
  'A', '2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K'
];

int _rankBase(String valor) => _ordemValores.indexOf(valor) + 1; // 1..13

class _Run {
  final int start; // rank da primeira posição da janela
  final int n; // tamanho da janela (== total de cartas)
  final Map<int, CartaSnapshot> naturaisPorRank; // rank -> carta natural
  const _Run(this.start, this.n, this.naturaisPorRank);
}

/// Tenta encaixar as cartas naturais numa janela contígua com `qtdCuringas`
/// curingas preenchendo lacunas/pontas. Retorna a janela canônica ou null.
_Run? _encaixaRun(List<CartaSnapshot> naturais, int qtdCuringas) {
  final n = naturais.length + qtdCuringas;
  if (n < 3 || n > 13) return null; // sem volta completa (as-a-ás fica p/ C3)
  final ases = naturais.where((c) => c.valor == 'A').toList();
  final outros = naturais.where((c) => c.valor != 'A').toList();
  if (ases.length > 1) return null; // 2 ases na mesma sequência = volta (proibido em C2)

  final ranksOutros = <int, CartaSnapshot>{};
  for (final c in outros) {
    final r = _rankBase(c.valor);
    if (r < 1) return null; // valor inesperado
    if (ranksOutros.containsKey(r)) return null; // rank duplicado
    ranksOutros[r] = c;
  }

  final opcoesAs = ases.isEmpty ? <int?>[null] : <int?>[1, 14];
  for (final asRank in opcoesAs) {
    final ranks = Map<int, CartaSnapshot>.from(ranksOutros);
    if (asRank != null) {
      if (ranks.containsKey(asRank)) continue;
      ranks[asRank] = ases.first;
    }
    final chaves = ranks.keys.toList()..sort();
    final minR = chaves.first, maxR = chaves.last;
    final sLow = (maxR - n + 1) < 1 ? 1 : (maxR - n + 1);
    final sHighA = minR;
    final sHighB = 15 - n; // start + n - 1 <= 14
    final sHigh = sHighA < sHighB ? sHighA : sHighB;
    if (sLow > sHigh) continue; // não cabe
    final start = sLow; // canônico: menor start possível
    return _Run(start, n, ranks);
  }
  return null;
}

/// Especial: as_a_as (A-2-...-K-A) — 14 cartas do MESMO naipe, 2 ases naturais
/// nas pontas, 12 cartas 2..K (uma de cada), sem curinga. Legalidade e
/// classificação estrutural pertencem ao C2; a pontuação de 1000 fica no C3.
ResultadoMeld? _tentarAsAAs(List<CartaSnapshot> cartas) {
  if (cartas.length != 14) return null;
  if (cartas.any((c) => c.valor == 'JOKER')) return null;
  final naipes = cartas.map((c) => c.naipe).toSet();
  if (naipes.length != 1) return null;
  final naipe = cartas.first.naipe;
  final ases = cartas.where((c) => c.valor == 'A').toList();
  if (ases.length != 2) return null;
  final naoAses = cartas.where((c) => c.valor != 'A').toList();
  const esperado = ['2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K'];
  if (naoAses.length != 12) return null;
  final setVal = naoAses.map((c) => c.valor).toSet();
  if (setVal.length != 12) return null;
  for (final v in esperado) {
    if (!setVal.contains(v)) return null;
  }
  final porRank = <int, CartaSnapshot>{};
  for (final c in naoAses) {
    porRank[_rankBase(c.valor)] = c; // 2..13
  }
  final asesOrd = [...ases]..sort((a, b) => a.chave.compareTo(b.chave));
  final ordenado = <CartaSnapshot>[];
  final usos = <UsoCarta>[];
  final assin = StringBuffer('SEQ|$naipe|start1|');
  ordenado.add(asesOrd[0]); // ponta baixa (A rank 1)
  usos.add(UsoCarta(asesOrd[0].id, 'natural', 0));
  assin.write('N1,');
  for (int rank = 2; rank <= 13; rank++) {
    final c = porRank[rank]!;
    ordenado.add(c);
    usos.add(UsoCarta(c.id, 'natural', rank - 1));
    assin.write('N$rank,');
  }
  ordenado.add(asesOrd[1]); // ponta alta (A rank 14)
  usos.add(UsoCarta(asesOrd[1].id, 'natural', 13));
  assin.write('N14,');
  return ResultadoMeld(
    valido: true,
    tipo: 'sequencia',
    classificacao: 'as_a_as',
    qtdCuringas: 0,
    naipeCanonico: naipe,
    canastra: false,
    liberaBatida: false,
    usos: usos,
    ordenado: ordenado,
    assinatura: assin.toString(),
  );
}

/// Valida (ou não) as cartas como SEQUÊNCIA canônica.
ResultadoMeld validarSequencia(List<CartaSnapshot> cartas, RuleSpec spec) {
  if (cartas.length < 3) {
    return ResultadoMeld.invalido('mínimo de 3 cartas para formar um jogo');
  }
  // Especial "volta completa" A-2-...-K-A (14 cartas, mesmo naipe).
  final asAAs = _tentarAsAAs(cartas);
  if (asAAs != null) return asAAs;
  final jokers = cartas.where((c) => c.valor == 'JOKER').toList();
  if (jokers.length > spec.maxCuringasPorSequencia) {
    return ResultadoMeld.invalido(
        'máximo de ${spec.maxCuringasPorSequencia} curinga por sequência');
  }
  final dois = cartas.where((c) => c.valor == '2').toList();
  final comuns =
      cartas.where((c) => c.valor != '2' && c.valor != 'JOKER').toList();

  if (comuns.isEmpty && dois.isEmpty) {
    return ResultadoMeld.invalido('sequência precisa de cartas naturais');
  }
  final naipesComuns = comuns.map((c) => c.naipe).toSet();
  if (naipesComuns.length > 1) {
    return ResultadoMeld.invalido(
        'todas as cartas naturais devem ser do mesmo naipe');
  }
  final naipeSeq = comuns.isNotEmpty
      ? comuns.first.naipe
      : (dois.isNotEmpty ? dois.first.naipe : null);

  // Interpretações dos "2" (natural x curinga), MENOS curingas primeiro (mais limpo).
  final interps = <List<CartaSnapshot>>[]; // cada item = subconjunto de 2 usados como curinga
  for (int mask = 0; mask < (1 << dois.length); mask++) {
    final comoCuringa = <CartaSnapshot>[];
    var ok = true;
    for (int i = 0; i < dois.length; i++) {
      if ((mask & (1 << i)) != 0) {
        comoCuringa.add(dois[i]);
      } else {
        // "2" natural precisa ser do naipe da sequência
        if (naipeSeq != null && dois[i].naipe != naipeSeq) {
          ok = false;
          break;
        }
      }
    }
    if (ok) interps.add(comoCuringa);
  }
  interps.sort((a, b) => a.length - b.length);

  String motivoFalha = 'lacuna maior que o número de curingas disponíveis';
  for (final comoCuringa in interps) {
    final qtd = jokers.length + comoCuringa.length;
    if (qtd > spec.maxCuringasPorSequencia) {
      motivoFalha = 'máximo de ${spec.maxCuringasPorSequencia} curinga por sequência';
      continue;
    }
    final curingaIds = comoCuringa.map((c) => c.id).toSet();
    final naturais = [
      ...comuns,
      ...dois.where((c) => !curingaIds.contains(c.id)),
    ];
    if (naturais.isEmpty) continue;
    final run = _encaixaRun(naturais, qtd);
    if (run == null) continue;

    final wildCards = [...jokers, ...comoCuringa]; // no máximo 1
    final ordenado = <CartaSnapshot>[];
    final usos = <UsoCarta>[];
    final assin = StringBuffer('SEQ|$naipeSeq|start${run.start}|');
    int wi = 0;
    for (int i = 0; i < run.n; i++) {
      final rank = run.start + i;
      final nat = run.naturaisPorRank[rank];
      if (nat != null) {
        ordenado.add(nat);
        usos.add(UsoCarta(nat.id, 'natural', i));
        assin.write('N$rank,');
      } else {
        final w = wildCards[wi++];
        ordenado.add(w);
        usos.add(UsoCarta(w.id, 'curinga', i));
        assin.write('W$rank,');
      }
    }
    // Classificação estrutural: A-K limpa (13 cartas, ás baixo, sem curinga) = de_500.
    final classific = (qtd == 0 && run.n == 13 && run.start == 1)
        ? 'de_500'
        : (qtd == 0 ? 'limpa' : 'suja');
    return ResultadoMeld(
      valido: true,
      tipo: 'sequencia',
      classificacao: classific,
      qtdCuringas: qtd,
      naipeCanonico: naipeSeq,
      canastra: false, // bônus/tarja de canastra (7+) fica para C3
      liberaBatida: false, // idem
      usos: usos,
      ordenado: ordenado,
      assinatura: assin.toString(),
    );
  }
  return ResultadoMeld.invalido(motivoFalha);
}

/// Valida (ou não) as cartas como TRINCA canônica (só natural, mesmo valor).
ResultadoMeld validarTrinca(List<CartaSnapshot> cartas, RuleSpec spec) {
  if (!spec.trincaPermitida) {
    return ResultadoMeld.invalido(
        'trinca não é permitida na modalidade ${spec.modalidade.texto}');
  }
  if (cartas.length < 3) {
    return ResultadoMeld.invalido('uma trinca tem no mínimo 3 cartas');
  }
  if (cartas.any((c) => c.valor == 'JOKER')) {
    return ResultadoMeld.invalido(
        'Joker não entra em trinca — só cartas naturais do mesmo valor');
  }
  final valor = cartas.first.valor;
  if (cartas.any((c) => c.valor != valor)) {
    return ResultadoMeld.invalido(
        'trinca: todas as cartas devem ter o mesmo valor natural; 2 e Joker não entram como curinga');
  }
  final ord = [...cartas]..sort((a, b) => a.chave.compareTo(b.chave));
  final usos = [
    for (int i = 0; i < ord.length; i++) UsoCarta(ord[i].id, 'natural', i)
  ];
  return ResultadoMeld(
    valido: true,
    tipo: 'trinca',
    classificacao: 'trinca', // NUNCA canastra, mesmo com 7+
    qtdCuringas: 0,
    naipeCanonico: null,
    canastra: false,
    liberaBatida: false, // trinca não libera batida (regra canônica)
    usos: usos,
    ordenado: ord,
    assinatura: 'TRIN|$valor|n${ord.length}',
  );
}

/// Despacho por modalidade: tenta sequência; se falhar, tenta trinca (se a
/// modalidade permitir). Trinca NUNCA é classificada como sequência.
ResultadoMeld validarJogoMesa(List<CartaSnapshot> cartas, RuleSpec spec) {
  final seq = validarSequencia(cartas, spec);
  if (seq.valido) return seq;
  if (spec.trincaPermitida) {
    final tr = validarTrinca(cartas, spec);
    if (tr.valido) return tr;
    // motivo mais relevante: se as cartas têm todas o mesmo valor, era tentativa de trinca
    final mesmoValor = cartas.map((c) => c.valor).toSet().length == 1;
    if (mesmoValor) return tr;
  }
  return seq;
}
