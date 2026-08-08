// diagnostico.dart — LOG TÉCNICO DA PARTIDA (OS-01 §13).
//
// O objetivo é responder, depois do fato, a reclamações do tipo:
//   "Eu descartei e a carta voltou."
//   "Caí e quando voltei minha mão estava diferente."
//
// Para isso o diário guarda a LINHA DO TEMPO das decisões do motor — comando,
// turno, versão do estado antes e depois, resultado, erro — e, no lugar do
// conteúdo das mãos, uma IMPRESSÃO DIGITAL. Duas entradas com a mesma impressão
// provam que a mão não mudou; impressões diferentes apontam exatamente entre
// quais dois eventos ela mudou. Nada disso expõe a carta de ninguém.
//
// Regra dura: este arquivo NUNCA registra conteúdo de carta, mão, monte ou
// morto. `EventoDiagnostico.dados` é filtrado na construção — ver [_sanitizar].

import 'dart:convert';

import '../mesa.dart';
import 'snapshot_partida.dart';

/// Natureza do evento registrado.
enum TipoEvento {
  comando,
  rejeicao,
  duplicado,
  integridade,
  snapshot,
  reconexao,
  presenca,
  relogio,
  rodada,
  partida,
}

/// Uma linha do diário. Imutável.
class EventoDiagnostico {
  /// Epoch em milissegundos — fornecido por quem registra (o motor não lê o
  /// relógio do dispositivo por conta própria; ver `RelogioTurno`).
  final int ts;
  final String partidaId;
  final TipoEvento tipo;

  /// Ação em caixa alta e estável (ex.: `COMPRAR_MONTE`, `RECONEXAO_ACEITA`).
  final String acao;

  final int? assento;
  final int? rodada;
  final int? vez;
  final String? eventoId;
  final int? versaoAntes;
  final int? versaoDepois;
  final String? resultado;
  final String? erro;
  final Map<String, Object?> dados;

  EventoDiagnostico({
    required this.ts,
    required this.partidaId,
    required this.tipo,
    required this.acao,
    this.assento,
    this.rodada,
    this.vez,
    this.eventoId,
    this.versaoAntes,
    this.versaoDepois,
    this.resultado,
    this.erro,
    Map<String, Object?> dados = const {},
  }) : dados = _sanitizar(dados);

  /// Chaves cujo conteúdo é informação privada de partida. Se alguém tentar
  /// registrá-las, o valor é substituído por um marcador — o log continua útil
  /// e a informação não vaza para o suporte.
  static const Set<String> _proibidas = {
    'mao',
    'maos',
    'cartas',
    'monte',
    'lixo',
    'morto',
    'mortos',
    'jogos',
    'jogosNos',
    'jogosEles',
    'baralho',
    'apelido',
    'apelidos',
    'email',
    'uid',
    'token',
  };

  static Map<String, Object?> _sanitizar(Map<String, Object?> entrada) {
    final saida = <String, Object?>{};
    for (final e in entrada.entries) {
      if (_proibidas.contains(e.key.toLowerCase())) {
        saida[e.key] = '<omitido>';
        continue;
      }
      final v = e.value;
      // Só escalares entram. Estruturas aninhadas são o caminho mais fácil para
      // uma carta escapar sem ninguém perceber.
      if (v == null || v is num || v is bool || v is String) {
        saida[e.key] = v;
      } else {
        saida[e.key] = '<omitido>';
      }
    }
    return Map.unmodifiable(saida);
  }

  Map<String, Object?> toJson() => {
        'ts': ts,
        'partida': partidaId,
        'tipo': tipo.name,
        'acao': acao,
        if (assento != null) 'assento': assento,
        if (rodada != null) 'rodada': rodada,
        if (vez != null) 'vez': vez,
        if (eventoId != null) 'eventoId': eventoId,
        if (versaoAntes != null) 'versaoAntes': versaoAntes,
        if (versaoDepois != null) 'versaoDepois': versaoDepois,
        if (resultado != null) 'resultado': resultado,
        if (erro != null) 'erro': erro,
        if (dados.isNotEmpty) 'dados': dados,
      };

  @override
  String toString() => toJson().toString();
}

/// Diário circular de uma partida.
///
/// Circular de propósito: uma partida longa não pode crescer sem limite na
/// memória do celular nem do servidor. A janela padrão cobre folgadamente uma
/// rodada inteira, que é o horizonte de qualquer reclamação.
class DiarioPartida {
  final String partidaId;
  final int capacidade;
  final List<EventoDiagnostico> _eventos = [];

  /// Quantos eventos já foram descartados pela janela circular. Aparece no
  /// despejo para o suporte saber que o começo foi truncado.
  int descartados = 0;

  DiarioPartida(this.partidaId, {this.capacidade = 400})
      : assert(capacidade > 0);

  List<EventoDiagnostico> get eventos => List.unmodifiable(_eventos);
  int get tamanho => _eventos.length;

  void registrar(EventoDiagnostico e) {
    _eventos.add(e);
    while (_eventos.length > capacidade) {
      _eventos.removeAt(0);
      descartados++;
    }
  }

  /// Atalho para registrar sem montar o objeto na chamada.
  void anotar({
    required int ts,
    required TipoEvento tipo,
    required String acao,
    int? assento,
    int? rodada,
    int? vez,
    String? eventoId,
    int? versaoAntes,
    int? versaoDepois,
    String? resultado,
    String? erro,
    Map<String, Object?> dados = const {},
  }) =>
      registrar(EventoDiagnostico(
        ts: ts,
        partidaId: partidaId,
        tipo: tipo,
        acao: acao,
        assento: assento,
        rodada: rodada,
        vez: vez,
        eventoId: eventoId,
        versaoAntes: versaoAntes,
        versaoDepois: versaoDepois,
        resultado: resultado,
        erro: erro,
        dados: dados,
      ));

  void limpar() {
    _eventos.clear();
    descartados = 0;
  }

  /// Despejo em JSON Lines — um evento por linha, cada linha um JSON válido e
  /// independente, pronto para anexar a um chamado de suporte ou subir para o
  /// servidor.
  ///
  /// `Map.toString()` NÃO é JSON: produz `{a: 1}` em vez de `{"a":1}`, não
  /// escapa aspas nem acentos, e um erro do motor com aspas no texto quebraria
  /// o arquivo inteiro. Quem for ler o despejo precisa conseguir dar
  /// `jsonDecode` linha a linha — é para isso que o formato existe.
  String paraJsonl() => _eventos.map((e) => jsonEncode(e.toJson())).join('\n');

  /// Impressão digital da mão de um assento, para anexar a um evento sem expor
  /// as cartas. Mesma mão ⇒ mesma impressão, independente da ordem.
  static String impressaoDaMao(Jogo j, int assento) =>
      SnapshotPartida.impressaoDeCartas(j.maos[assento]);
}
