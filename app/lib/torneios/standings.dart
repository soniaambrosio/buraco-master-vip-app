// standings.dart — motor deterministico de classificacao (OS 02 secoes 10 e 11).
//
// Camada pura: sem Firestore, sem UI e sem relogio. Recebe resultados, devolve
// uma classificacao. Chamar duas vezes com a mesma entrada da a mesma saida, na
// mesma ordem — e o que a OS 02 secao 10 quer dizer com "deterministico".
//
// CENTRALIZACAO: OS 02 secao 10 e explicita — "nao espalhar logica de ranking em
// widgets". Toda ordenacao de torneio passa por [calcularClassificacao]. A tela
// recebe uma lista ja ordenada e posicionada; ela nao reordena, nao desempata e
// nao decide quem avanca.
//
// CRITERIOS: a ordem padrao e a que o projeto ja documenta em
// app/lib/screens/torneios_models.dart — "Vitorias, saldo de pontos, pontos
// feitos e canastras limpas". Nenhum criterio esportivo foi inventado aqui, e o
// template pode reordena-los sem tocar neste arquivo (OS 02 secao 11: "arquitetura
// que permita alterar o criterio sem reconstrucao geral").

import 'match_contract.dart';
import 'tournament_model.dart';

/// Numeros de um participante na edicao, agregados a partir dos resultados.
class DesempenhoParticipante {
  final String participanteId;

  final int vitorias;
  final int derrotas;
  final int pontosFeitos;
  final int pontosSofridos;
  final int canastrasLimpas;
  final int partidasConcluidas;

  const DesempenhoParticipante({
    required this.participanteId,
    this.vitorias = 0,
    this.derrotas = 0,
    this.pontosFeitos = 0,
    this.pontosSofridos = 0,
    this.canastrasLimpas = 0,
    this.partidasConcluidas = 0,
  });

  int get saldo => pontosFeitos - pontosSofridos;

  DesempenhoParticipante _somar({
    required bool venceu,
    required int feitos,
    required int sofridos,
    required int canastras,
  }) =>
      DesempenhoParticipante(
        participanteId: participanteId,
        vitorias: vitorias + (venceu ? 1 : 0),
        derrotas: derrotas + (venceu ? 0 : 1),
        pontosFeitos: pontosFeitos + feitos,
        pontosSofridos: pontosSofridos + sofridos,
        canastrasLimpas: canastrasLimpas + canastras,
        partidasConcluidas: partidasConcluidas + 1,
      );

  Map<String, dynamic> toJson() => {
        'participanteId': participanteId,
        'vitorias': vitorias,
        'derrotas': derrotas,
        'pontosFeitos': pontosFeitos,
        'pontosSofridos': pontosSofridos,
        'saldo': saldo,
        'canastrasLimpas': canastrasLimpas,
        'partidasConcluidas': partidasConcluidas,
      };

  @override
  String toString() =>
      'Desempenho($participanteId ${vitorias}V-${derrotas}D saldo $saldo)';
}

/// Situacao do participante na classificacao (OS 02 secao 8).
enum SituacaoClassificacao {
  /// Segue na disputa.
  ativo('ativo'),

  /// Passou para a proxima fase.
  avancou('avancou'),

  /// Saiu da disputa.
  eliminado('eliminado');

  final String wire;
  const SituacaoClassificacao(this.wire);
}

/// Uma linha da classificacao.
class LinhaClassificacao {
  /// Posicao final, 1 e a melhor. Sempre unica dentro da classificacao.
  final int posicao;

  final DesempenhoParticipante desempenho;

  final SituacaoClassificacao situacao;

  /// O participante empatou com o anterior em TODOS os criterios esportivos e so
  /// foi separado pelo desempate administrativo.
  ///
  /// Existe para tornar visivel o que a OS 02 secao 11 chama de pendencia: a
  /// ordem entre os dois e deterministica, mas nao e esportiva. A tela pode
  /// sinalizar, e a administracao sabe onde falta criterio.
  final bool empateNaoResolvido;

  const LinhaClassificacao({
    required this.posicao,
    required this.desempenho,
    this.situacao = SituacaoClassificacao.ativo,
    this.empateNaoResolvido = false,
  });

  String get participanteId => desempenho.participanteId;

  LinhaClassificacao comSituacao(SituacaoClassificacao nova) => LinhaClassificacao(
        posicao: posicao,
        desempenho: desempenho,
        situacao: nova,
        empateNaoResolvido: empateNaoResolvido,
      );

  Map<String, dynamic> toJson() => {
        'posicao': posicao,
        'situacao': situacao.wire,
        'empateNaoResolvido': empateNaoResolvido,
        ...desempenho.toJson(),
      };

  @override
  String toString() => '$posicao. ${desempenho.participanteId}';
}

/// Agrega os resultados em desempenho por participante.
///
/// Partidas anuladas ([DesfechoPartida.anulada]) nao entram: elas nao pontuam
/// para ninguem, e conta-las como derrota puniria os dois lados por um problema
/// que nao foi deles.
///
/// [participantes] garante que quem nao jogou nenhuma partida ainda apareca na
/// classificacao com tudo zerado — sumir da lista faria o inscrito achar que
/// perdeu a vaga.
Map<String, DesempenhoParticipante> agregarDesempenho({
  required Iterable<ResultadoPartida> resultados,
  Iterable<String> participantes = const <String>[],
}) {
  final mapa = <String, DesempenhoParticipante>{
    for (final id in participantes)
      id: DesempenhoParticipante(participanteId: id),
  };

  for (final resultado in resultados) {
    if (!resultado.desfecho.pontua) continue;

    // Pontos sofridos = soma dos pontos dos OUTROS lados. Em mesa de dois lados
    // isso e o placar do adversario; a formula ja vale para mesas de tres ou
    // quatro lados sem virar um caso especial.
    final total = resultado.lados.fold<int>(0, (soma, l) => soma + l.pontos);

    for (final lado in resultado.lados) {
      final atual = mapa[lado.participanteId] ??
          DesempenhoParticipante(participanteId: lado.participanteId);
      mapa[lado.participanteId] = atual._somar(
        venceu: resultado.vencedorId == lado.participanteId,
        feitos: lado.pontos,
        sofridos: total - lado.pontos,
        canastras: lado.canastrasLimpas,
      );
    }
  }

  return mapa;
}

/// Compara dois desempenhos por um unico criterio.
///
/// Devolve negativo quando [a] fica na frente. Zero significa empate NESTE
/// criterio, e a decisao passa para o proximo da lista.
int compararPorCriterio(
  DesempenhoParticipante a,
  DesempenhoParticipante b,
  CriterioDesempate criterio,
) {
  switch (criterio) {
    // Todos os criterios esportivos sao "maior e melhor", entao a comparacao e
    // invertida em relacao a ordem natural.
    case CriterioDesempate.vitorias:
      return b.vitorias.compareTo(a.vitorias);
    case CriterioDesempate.saldoPontos:
      return b.saldo.compareTo(a.saldo);
    case CriterioDesempate.pontosFeitos:
      return b.pontosFeitos.compareTo(a.pontosFeitos);
    case CriterioDesempate.canastrasLimpas:
      return b.canastrasLimpas.compareTo(a.canastrasLimpas);
    case CriterioDesempate.desempateAdministrativo:
      // Nao e criterio esportivo: existe so para a ordem ser total. Ver a
      // documentacao do enum em tournament_model.dart.
      return a.participanteId.compareTo(b.participanteId);
  }
}

/// Aplica a cadeia de desempate inteira.
int compararDesempenho(
  DesempenhoParticipante a,
  DesempenhoParticipante b,
  List<CriterioDesempate> criterios,
) {
  for (final criterio in criterios) {
    final r = compararPorCriterio(a, b, criterio);
    if (r != 0) return r;
  }
  // Cadeia esgotada sem decidir. So acontece se o template omitir o desempate
  // administrativo; cai no id para nao devolver ordem imprevisivel.
  return a.participanteId.compareTo(b.participanteId);
}

/// Calcula a classificacao ordenada da edicao.
///
/// Funcao pura e deterministica: mesma entrada, mesma saida, sempre.
List<LinhaClassificacao> calcularClassificacao({
  required Iterable<ResultadoPartida> resultados,
  required List<CriterioDesempate> criterios,
  Iterable<String> participantes = const <String>[],
}) {
  final desempenhos = agregarDesempenho(
    resultados: resultados,
    participantes: participantes,
  ).values.toList(growable: false);

  desempenhos.sort((a, b) => compararDesempenho(a, b, criterios));

  // Criterios esportivos = tudo menos o desempate administrativo. Empate em
  // todos eles e o que a OS 02 secao 11 manda registrar como pendencia.
  final esportivos = criterios
      .where((c) => c != CriterioDesempate.desempateAdministrativo)
      .toList(growable: false);

  final linhas = <LinhaClassificacao>[];
  for (var i = 0; i < desempenhos.length; i++) {
    final empatado = i > 0 &&
        esportivos.every((c) =>
            compararPorCriterio(desempenhos[i - 1], desempenhos[i], c) == 0);
    linhas.add(LinhaClassificacao(
      posicao: i + 1,
      desempenho: desempenhos[i],
      empateNaoResolvido: empatado,
    ));
  }
  return linhas;
}

/// Marca quem avanca e quem e eliminado (OS 02 secoes 8 e 10).
///
/// [vagas] e quantos seguem para a proxima fase. Nao ha default: quantos avancam
/// e decisao de formato, e chutar um numero decidiria a competicao no lugar da
/// administracao.
///
/// Recusa avancar um corte que cai no meio de um empate nao resolvido: nesse
/// caso a decisao de quem passa seria puramente alfabetica, e eliminar alguem por
/// causa do proprio nome nao e resultado esportivo. Lanca [StateError] para que a
/// automacao pare e a pendencia apareca, em vez de seguir silenciosamente.
List<LinhaClassificacao> aplicarCorte(
  List<LinhaClassificacao> classificacao, {
  required int vagas,
}) {
  if (vagas < 1) {
    throw ArgumentError.value(vagas, 'vagas', 'deve ser >= 1');
  }
  if (vagas >= classificacao.length) {
    return classificacao
        .map((l) => l.comSituacao(SituacaoClassificacao.avancou))
        .toList(growable: false);
  }
  if (classificacao[vagas].empateNaoResolvido) {
    throw StateError(
        'corte em $vagas vaga(s) cai sobre empate nao resolvido entre '
        '${classificacao[vagas - 1].participanteId} e ${classificacao[vagas].participanteId}: '
        'falta criterio de desempate definido (OS 02 secao 11).');
  }
  return [
    for (var i = 0; i < classificacao.length; i++)
      classificacao[i].comSituacao(i < vagas
          ? SituacaoClassificacao.avancou
          : SituacaoClassificacao.eliminado),
  ];
}
