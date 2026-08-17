// C1 — andaime do RulesEngine canônico.
// C10 (parte 2): PARTICIPA DO RUNTIME LOCAL. Sob `MotorConfig.producao()` a
// partida real passa por aqui; o cabeçalho antigo dizia o contrário.
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

/// OS PROVENIÊNCIA DE DESCARTES V1 — REGISTRO CANÔNICO de um descarte público.
///
/// A autoridade grava este registro NO INSTANTE em que aceita o descarte, que é
/// o único ponto onde a autoria é inequívoca. Nada aqui é reconstruído depois:
/// a posição da carta na pilha do lixo NÃO diz quem a pôs lá, e deduzi-la pela
/// ordem dos turnos seria fabricar informação.
///
/// AUTOR = `assento`. É a identidade canônica da mesa (0..3), a mesma que a
/// projeção e o bot já usam. UID, conta e perfil não entram: são identidade
/// privada, e o contrato público desta camada trabalha por assento.
///
/// `ordem` é o carimbo temporal do descarte DENTRO DA MÃO (0, 1, 2, ...),
/// monotônico e nunca reusado. Existe para que a associação carta↔autor
/// sobreviva a serialização, filtragem e à compra do lixo — a lista pode ser
/// recortada por um consumidor sem que a sequência real se perca.
class DescarteRegistrado {
  /// A carta que foi ao lixo (cópia imutável — o registro não referencia mão).
  final CartaSnapshot carta;

  /// Assento que descartou. Autoria registrada, nunca inferida.
  final int assento;

  /// Ordem temporal do descarte dentro da MÃO corrente.
  final int ordem;

  const DescarteRegistrado({
    required this.carta,
    required this.assento,
    required this.ordem,
  });

  DescarteRegistrado copia() =>
      DescarteRegistrado(carta: carta.copia(), assento: assento, ordem: ordem);

  /// Chave canônica para assinatura/normalização determinística.
  String get chave => '$ordem@$assento:${carta.chave}';

  // Parâmetro `other` (e não `o`, como no `CartaSnapshot` acima) porque é o
  // nome do método sobrescrito — o analyzer cobra, e a OS não aceita issue nova.
  @override
  bool operator ==(Object other) =>
      other is DescarteRegistrado &&
      other.carta == carta &&
      other.assento == assento &&
      other.ordem == ordem;

  @override
  int get hashCode => Object.hash(carta, assento, ordem);

  @override
  String toString() => 'DescarteRegistrado($chave)';
}

/// Próxima `ordem` do livro de proveniência: monotônica a partir do último
/// registro, nunca reusada. Derivar de `length` seria frágil se um consumidor
/// recortasse a lista.
int proximaOrdemDescarte(List<DescarteRegistrado> livro) =>
    livro.isEmpty ? 0 : livro.last.ordem + 1;

/// REGISTRA um descarte no livro (append-only).
///
/// AUTORIDADE ÚNICA da forma do registro: o caminho canônico e o caminho legado
/// chamam esta mesma função, então não têm como divergir na autoria nem na
/// ordem. Nenhum outro lugar do código constrói um `DescarteRegistrado` de
/// produção.
void registrarDescarte(
        List<DescarteRegistrado> livro, CartaSnapshot carta, int assento) =>
    livro.add(DescarteRegistrado(
      carta: carta.copia(),
      assento: assento,
      ordem: proximaOrdemDescarte(livro),
    ));

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

  /// PROVENIÊNCIA PÚBLICA dos descartes da MÃO corrente, em ordem temporal.
  ///
  /// Append-only. Vive AQUI, e não no envelope de runtime, porque é estado
  /// canônico da mão: quem não está no `EstadoJogo` não atravessa `aplicarLegal`
  /// e some no primeiro round-trip da autoridade.
  ///
  /// SEMÂNTICA (§8 da OS): histórico ACUMULADO da mão. Comprar o lixo esvazia a
  /// pilha, mas NÃO apaga o registro — a carta deixou de estar no lixo, não
  /// deixou de ter sido descartada à vista de todos. A memória é limitada à MÃO
  /// (§9): a distribuição da mão seguinte zera o livro junto com o lixo, então
  /// descarte de mão anterior nunca é atribuído à mão corrente.
  ///
  /// Pode conter MENOS entradas que o lixo tem cartas — um lixo montado por
  /// fixture ou herdado de um snapshot antigo não tem proveniência. Isso é
  /// intencional: sem registro, o autor é DESCONHECIDO, e desconhecido é sempre
  /// preferível a um autor inventado.
  final List<DescarteRegistrado> descartes;

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
    this.descartes = const <DescarteRegistrado>[],
  });

  static List<DescarteRegistrado> _copiaLivro(List<DescarteRegistrado> l) =>
      [for (final d in l) d.copia()];

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
        descartes: _copiaLivro(descartes),
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
      // O livro de proveniência tem ORDEM SEMÂNTICA (é temporal): normalizar
      // NÃO o reordena, do mesmo modo que não reordena lixo nem monte.
      descartes: _copiaLivro(descartes),
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
      ..writeln('fase=${n.fase.name}')
      ..writeln('descartes=${n.descartes.map((d) => d.chave).join(',')}');
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
        // Compartilhada como as demais coleções: o gerador registra o descarte
        // na lista do clone e só depois ajusta vez/fase por aqui.
        descartes: descartes,
      );
}
