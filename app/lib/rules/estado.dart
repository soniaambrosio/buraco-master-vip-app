// C1 — andaime do RulesEngine canônico. SEM comportamento de produção.
//
// Ajuste obrigatório 4 — clone profundo e normalização de estado para o modo
// sombra. O EstadoJogo é um SNAPSHOT imutável, desacoplado da UI/mesa.dart.
import 'modalidade.dart';

/// FASE do turno (fase também é regra). Sequência canônica:
///  compra  -> início do turno: só compra (monte OU lixo), não descarta;
///  jogo    -> após comprar: baixar/estender, descartar, morto direto, batida;
///  mortoPendente -> um descarte esvaziou a mão e há morto a pegar: a ÚNICA
///                   ação legal é PegarMorto(viaDescarte:true) (morto indireto).
enum FaseTurno { compra, jogo, mortoPendente }

/// Carta imutável para snapshots do motor canônico (desacoplada da UI).
class CartaSnapshot {
  final String id;
  final String? naipe; // null para JOKER
  final String valor;
  final bool curinga;
  const CartaSnapshot(this.id, this.naipe, this.valor, this.curinga);

  CartaSnapshot copia() => CartaSnapshot(id, naipe, valor, curinga);

  /// Chave canônica para ordenação/normalização determinística.
  String get chave => '${naipe ?? "jk"}|$valor|$id';

  @override
  bool operator ==(Object o) =>
      o is CartaSnapshot &&
      o.id == id &&
      o.naipe == naipe &&
      o.valor == valor &&
      o.curinga == curinga;

  @override
  int get hashCode => Object.hash(id, naipe, valor, curinga);
}

/// Snapshot IMUTÁVEL do estado do jogo — base de comparação do modo sombra.
class EstadoJogo {
  final Modalidade modalidade;
  final int metaPontos;
  final List<CartaSnapshot> monte;
  final List<CartaSnapshot> lixo; // ordem semântica: topo = último
  final List<List<CartaSnapshot>> mortos;
  final List<List<CartaSnapshot>> maos; // por assento (0..3)
  final Map<String, List<List<CartaSnapshot>>> jogosDupla; // 'nos'/'eles'
  final Map<String, int> rodadasVulneravel;
  final Map<String, bool> primeiraBaixadaFeita;
  final int vez;
  final Map<String, bool> mortoPego; // por dupla: 'nos'/'eles'
  final bool rodadaEncerrada; // batida encerrou a rodada
  final String? duplaQueBateu;
  final FaseTurno fase; // fase do turno (compra/jogo/mortoPendente)

  const EstadoJogo({
    required this.modalidade,
    required this.metaPontos,
    required this.monte,
    required this.lixo,
    required this.mortos,
    required this.maos,
    required this.jogosDupla,
    required this.rodadasVulneravel,
    required this.primeiraBaixadaFeita,
    required this.vez,
    this.mortoPego = const {'nos': false, 'eles': false},
    this.rodadaEncerrada = false,
    this.duplaQueBateu,
    this.fase = FaseTurno.compra,
  });

  static List<CartaSnapshot> _copiaLista(List<CartaSnapshot> l) =>
      [for (final c in l) c.copia()];

  static List<List<CartaSnapshot>> _copiaMatriz(
          List<List<CartaSnapshot>> m) =>
      [for (final l in m) _copiaLista(l)];

  /// CLONE PROFUNDO: nenhuma referência de coleção é compartilhada com a
  /// origem. Mutação do clone não afeta o estado original (garantia do sombra).
  EstadoJogo cloneProfundo() => EstadoJogo(
        modalidade: modalidade,
        metaPontos: metaPontos,
        monte: _copiaLista(monte),
        lixo: _copiaLista(lixo),
        mortos: _copiaMatriz(mortos),
        maos: _copiaMatriz(maos),
        jogosDupla: {
          for (final e in jogosDupla.entries) e.key: _copiaMatriz(e.value),
        },
        rodadasVulneravel: {...rodadasVulneravel},
        primeiraBaixadaFeita: {...primeiraBaixadaFeita},
        vez: vez,
        mortoPego: {...mortoPego},
        rodadaEncerrada: rodadaEncerrada,
        duplaQueBateu: duplaQueBateu,
        fase: fase,
      );

  /// NORMALIZAÇÃO para comparação determinística no modo sombra.
  /// Ordena apenas coleções SEM ordem semântica (mãos), preservando a ordem
  /// interna de cada jogo baixado e a ordem do lixo/monte (semânticas).
  EstadoJogo normalizar() {
    List<CartaSnapshot> ordenar(List<CartaSnapshot> l) {
      final copia = _copiaLista(l);
      copia.sort((a, b) => a.chave.compareTo(b.chave));
      return copia;
    }

    // Jogos da dupla: ordena a LISTA de jogos por uma chave estável, sem
    // reordenar as cartas DENTRO de cada jogo (ordem semântica da sequência).
    Map<String, List<List<CartaSnapshot>>> jogosOrdenados() {
      final out = <String, List<List<CartaSnapshot>>>{};
      for (final e in jogosDupla.entries) {
        final jogos = _copiaMatriz(e.value);
        jogos.sort((ja, jb) {
          final ka = ja.map((c) => c.chave).join(',');
          final kb = jb.map((c) => c.chave).join(',');
          return ka.compareTo(kb);
        });
        out[e.key] = jogos;
      }
      return out;
    }

    return EstadoJogo(
      modalidade: modalidade,
      metaPontos: metaPontos,
      monte: _copiaLista(monte),
      lixo: _copiaLista(lixo),
      mortos: _copiaMatriz(mortos),
      maos: [for (final m in maos) ordenar(m)],
      jogosDupla: jogosOrdenados(),
      rodadasVulneravel: {...rodadasVulneravel},
      primeiraBaixadaFeita: {...primeiraBaixadaFeita},
      vez: vez,
      mortoPego: {...mortoPego},
      rodadaEncerrada: rodadaEncerrada,
      duplaQueBateu: duplaQueBateu,
      fase: fase,
    );
  }

  /// Assinatura estável do estado JÁ NORMALIZADO (diff textual no sombra).
  String assinatura() {
    final n = normalizar();
    String zona(List<CartaSnapshot> l) => l.map((c) => c.chave).join(',');
    String matriz(List<List<CartaSnapshot>> m) =>
        m.map(zona).join(' | ');
    final sb = StringBuffer()
      ..writeln('mod=${n.modalidade.texto} meta=${n.metaPontos} vez=${n.vez}')
      ..writeln('monte=${zona(n.monte)}')
      ..writeln('lixo=${zona(n.lixo)}')
      ..writeln('mortos=${matriz(n.mortos)}')
      ..writeln('maos=${matriz(n.maos)}')
      ..writeln('nos=${matriz(n.jogosDupla['nos'] ?? const [])}')
      ..writeln('eles=${matriz(n.jogosDupla['eles'] ?? const [])}')
      ..writeln('rv=${n.rodadasVulneravel}')
      ..writeln('pb=${n.primeiraBaixadaFeita}')
      ..writeln('mp=${n.mortoPego}')
      ..writeln('fim=${n.rodadaEncerrada} bateu=${n.duplaQueBateu}')
      ..writeln('fase=${n.fase.name}');
    return sb.toString();
  }

  /// Cópia rasa alterando poucos campos (compartilha as coleções deste estado).
  EstadoJogo copyWith(
          {int? vez,
          bool? rodadaEncerrada,
          String? duplaQueBateu,
          FaseTurno? fase}) =>
      EstadoJogo(
        modalidade: modalidade,
        metaPontos: metaPontos,
        monte: monte,
        lixo: lixo,
        mortos: mortos,
        maos: maos,
        jogosDupla: jogosDupla,
        rodadasVulneravel: rodadasVulneravel,
        primeiraBaixadaFeita: primeiraBaixadaFeita,
        vez: vez ?? this.vez,
        mortoPego: mortoPego,
        rodadaEncerrada: rodadaEncerrada ?? this.rodadaEncerrada,
        duplaQueBateu: duplaQueBateu ?? this.duplaQueBateu,
        fase: fase ?? this.fase,
      );
}
