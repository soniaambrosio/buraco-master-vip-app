// visao_assento.dart — O QUE CADA ASSENTO PODE VER (OS-01 §9, §11 e §16).
//
// O `Jogo` de mesa.dart é o estado COMPLETO: as quatro mãos, o monte na ordem
// em que vai sair, os mortos. Mandar isso para um cliente é entregar o jogo —
// qualquer pessoa com o inspetor aberto lê a mão do adversário. E o §11 da OS
// diz o mesmo para o robô: ele "não deve acessar informação que um jogador
// humano não poderia visualizar".
//
// Esta camada faz o recorte. A regra é uma só:
//
//   O assento vê a PRÓPRIA mão inteira. De todo o resto ele vê o que está na
//   mesa (lixo, jogos baixados, placar) e apenas a CONTAGEM do que está oculto
//   (mãos alheias, monte, mortos).
//
// A contagem não é vazamento: quantas cartas cada um tem é informação que
// qualquer jogador conta com os olhos na mesa real — e o robô já depende dela
// para decidir se bate agora ou espera o parceiro.
//
// A visão é também o formato de RETOMADA (§9): tudo o que o jogador precisa
// para voltar à partida exatamente onde estava — mesa, assento, parceiro,
// adversários, mão, jogos, lixo, monte, mortos, pontuação, vulnerabilidade,
// rodada, jogador da vez, timer e presença — sai daqui pronto, sem o cliente
// reconstruir nada por conta própria.

import '../mesa.dart';
import 'presenca.dart';
import 'relogio_turno.dart';
import 'snapshot_partida.dart';

/// Recorte do estado por assento.
class VisaoAssento {
  const VisaoAssento._();

  static Map<String, Object?> _carta(Carta c) => {
        'id': c.id,
        'naipe': c.naipe,
        'valor': c.valor,
        'coringa': c.ehCoringa,
      };

  static List<Object?> _cartas(List<Carta> cs) => [for (final c in cs) _carta(c)];

  /// Monta a visão de [assento].
  ///
  /// [relogio], [presenca] e [versaoEstado] vêm de fora porque não pertencem ao
  /// `Jogo`: são estado da SESSÃO, e quem manda neles é o servidor.
  static Map<String, Object?> de(
    Jogo j,
    int assento, {
    int versaoEstado = 0,
    String partidaId = '',
    RelogioTurno? relogio,
    MapaPresenca? presenca,
    ParametrosPresenca parametrosPresenca = ParametrosPresenca.padrao,
  }) {
    if (assento < 0 || assento > 3) {
      throw ArgumentError.value(assento, 'assento', 'fora de 0..3');
    }
    final dupla = assento % 2 == 0 ? 'nos' : 'eles';
    final duplaAdversaria = dupla == 'nos' ? 'eles' : 'nos';
    final minhaMao = j.maos[assento];

    // A obrigação do topo do lixo (Fechado/STBL) é pública no fato — todo mundo
    // viu quem pegou o monte de descarte —, mas só o dono precisa do id.
    final idObrigatorio = j.lixoTopoObrigatorio;
    final obrigacaoEhMinha =
        idObrigatorio != null && minhaMao.any((c) => c.id == idObrigatorio);

    return {
      'partidaId': partidaId,
      'versaoEstado': versaoEstado,
      'formatoSnapshot': kVersaoFormatoSnapshot,

      // ---- quem sou eu nesta mesa ----
      'assento': assento,
      'dupla': dupla,
      'parceiro': (assento + 2) % 4,
      'adversarios': [(assento + 1) % 4, (assento + 3) % 4],
      'jogadores': [
        for (var a = 0; a < 4; a++)
          {
            'assento': a,
            'apelido': a < j.apelidos.length ? j.apelidos[a] : '',
            'avatar': a < j.avatares.length ? j.avatares[a] : '',
            'mascote': a < j.mascotes.length ? j.mascotes[a] : '',
            'dupla': a % 2 == 0 ? 'nos' : 'eles',
            'cartasNaMao': j.maos[a].length,
          },
      ],

      // ---- mesa ----
      'modalidade': j.modalidade,
      'metaPontos': j.metaPontos,
      'rodada': j.rodada,

      // ---- turno ----
      'vez': j.vez,
      'minhaVez': j.vez == assento,
      'jaComprou': j.jaComprou,
      'rodadaEncerrada': j.rodadaEncerrada,
      'partidaEncerrada': j.encerrada,

      // ---- o que EU vejo por inteiro ----
      'mao': _cartas(minhaMao),
      'impressaoDaMao': SnapshotPartida.impressaoDeCartas(minhaMao),

      // ---- o que está na mesa (público) ----
      'lixo': _cartas(j.lixo),
      'jogosNos': [for (final g in j.jogosDupla['nos']!) _cartas(g)],
      'jogosEles': [for (final g in j.jogosDupla['eles']!) _cartas(g)],

      // ---- o que está oculto: só a contagem ----
      'cartasNaMao': [for (var a = 0; a < 4; a++) j.maos[a].length],
      'monteRestante': j.monte.length,
      'mortosRestantes': j.mortos.length,
      'mortosTamanhos': [for (final m in j.mortos) m.length],
      'mortoPegoNos': j.mortoPego['nos'] ?? false,
      'mortoPegoEles': j.mortoPego['eles'] ?? false,

      // ---- pendências do meu turno ----
      'obrigacaoTopoPendente': idObrigatorio != null,
      'idTopoObrigatorio': obrigacaoEhMinha ? idObrigatorio : null,
      'idDescarteProibido':
          j.vez == assento ? j.descarteProibidoId : null,

      // ---- placar e vulnerabilidade ----
      'placarNos': j.placar['nos'] ?? 0,
      'placarEles': j.placar['eles'] ?? 0,
      'minimoParaDescerNos': j.minimoParaDescer('nos'),
      'minimoParaDescerEles': j.minimoParaDescer('eles'),
      'vulneravel': j.minimoParaDescer(dupla) > 0,
      'podeBaterMinhaDupla': j.duplaPodeBater(dupla),
      'podeBaterAdversaria': j.duplaPodeBater(duplaAdversaria),

      // ---- desfecho ----
      'duplaQueBateu': j.duplaQueBateu,
      'assentoQueBateu': j.assentoQueBateu,
      'pontosRodada': j.pontosRodada,

      // ---- bloqueio crítico ----
      // O jogador só precisa saber QUE a mesa está travada. O código auditável
      // fica no log do servidor, não na tela de quem poderia explorá-lo.
      'mesaBloqueada': j.integridadeErro != null,

      // ---- sessão (não pertence ao Jogo) ----
      'relogio': relogio?.toJson(),
      'presenca': presenca?.toJson() ??
          {'parametros': parametrosPresenca.toJson(), 'assentos': const []},
    };
  }

  /// Todos os ids de carta que aparecem numa visão.
  ///
  /// Existe para o teste de vazamento: a visão do assento A não pode conter
  /// nenhum id que esteja na mão de B, no monte ou nos mortos.
  static Set<String> idsVisiveis(Map<String, Object?> visao) {
    final ids = <String>{};
    void varrer(Object? v) {
      if (v is Map) {
        final id = v['id'];
        if (id is String && v.containsKey('valor')) {
          ids.add(id);
          return;
        }
        for (final e in v.values) {
          varrer(e);
        }
      } else if (v is List) {
        for (final e in v) {
          varrer(e);
        }
      }
    }

    varrer(visao);
    return ids;
  }
}
