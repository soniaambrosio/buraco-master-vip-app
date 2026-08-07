// automation.dart — tarefas automaticas do torneio (OS 02 secao 19).
//
// Camada pura: sem Firestore, sem Cloud Scheduler, sem timer. Este arquivo decide
// QUAIS tarefas estao vencidas num dado instante e QUAL a chave de cada uma.
// Quem dispara e o agendador; quem grava e a persistencia.
//
// A EXIGENCIA CENTRAL DA SECAO 19: "reprocessar uma tarefa automatica nao pode
// provocar duplicidade". Aqui isso e resolvido por construcao — toda tarefa tem
// uma [ChaveTarefa] determinista, derivada do alvo e nao do momento da execucao.
// Rodar o agendador dez vezes no mesmo minuto produz dez vezes a MESMA chave, e a
// camada de execucao descarta as nove repetidas com uma unica leitura.
//
// A chave NAO inclui o instante de execucao de proposito. Se incluisse, cada
// tentativa geraria uma chave nova e a idempotencia desapareceria justamente no
// cenario que ela existe para cobrir: o retry.

import 'tournament_lifecycle.dart';
import 'tournament_model.dart';

/// O que a automacao sabe fazer.
enum TarefaAutomatica {
  /// Abre as inscricoes quando o calendario alcanca a janela.
  abrirInscricoes('abrir_inscricoes'),

  /// Fecha as inscricoes no fim da janela, ou por lotacao.
  fecharInscricoes('fechar_inscricoes'),

  abrirCheckin('abrir_checkin'),

  /// Forma as mesas da fase.
  formarMesas('formar_mesas'),

  /// Inicia a disputa.
  iniciarEdicao('iniciar_edicao'),

  /// Apura a fase encerrada e promove quem avanca.
  avancarFase('avancar_fase'),

  /// Conclui a edicao e registra o campeao.
  concluirEdicao('concluir_edicao'),

  /// Concede os premios da classificacao final.
  concederPremios('conceder_premios'),

  /// Registra os classificados ao encerramento anual.
  registrarClassificadosAnuais('registrar_classificados_anuais');

  final String wire;
  const TarefaAutomatica(this.wire);

  static TarefaAutomatica? porWire(String wire) {
    for (final t in TarefaAutomatica.values) {
      if (t.wire == wire) return t;
    }
    return null;
  }
}

/// Chave determinista de uma tarefa.
///
/// Contrato: `tarefa + tournamentId + editionId [+ alvo]`. O [alvo] distingue
/// ocorrencias legitimamente diferentes da mesma tarefa na mesma edicao — sem
/// ele, avancar a fase 2 seria confundido com avancar a fase 1 e a segunda
/// jamais rodaria.
abstract final class ChaveTarefa {
  static const separador = '|';

  static String de({
    required TarefaAutomatica tarefa,
    required String tournamentId,
    required String editionId,
    String? alvo,
  }) {
    for (final par in [
      [tournamentId, 'tournamentId'],
      [editionId, 'editionId'],
      if (alvo != null) [alvo, 'alvo'],
    ]) {
      if (par[0].isEmpty) {
        throw ArgumentError.value(par[0], par[1], 'nao pode ser vazio');
      }
      if (par[0].contains(separador)) {
        throw ArgumentError.value(par[0], par[1], 'nao pode conter "$separador"');
      }
    }
    final base = '${tarefa.wire}$separador$tournamentId$separador$editionId';
    return alvo == null ? base : '$base$separador$alvo';
  }
}

/// Uma tarefa vencida, pronta para execucao.
class TarefaPendente {
  final TarefaAutomatica tarefa;
  final String tournamentId;
  final String editionId;

  /// Fase, mesa ou outro recorte, quando a tarefa se repete dentro da edicao.
  final String? alvo;

  /// Instante em que a tarefa passou a estar vencida, em UTC. Informativo: nao
  /// entra na chave.
  final DateTime venceuEm;

  /// Transicao de status que a tarefa vai pedir, quando houver. Serve para a
  /// camada de execucao passar por [avaliarTransicao] antes de aplicar.
  final EdicaoStatus? transicaoPara;

  TarefaPendente({
    required this.tarefa,
    required this.tournamentId,
    required this.editionId,
    this.alvo,
    required DateTime venceuEm,
    this.transicaoPara,
  }) : venceuEm = venceuEm.toUtc();

  String get chaveIdempotencia => ChaveTarefa.de(
        tarefa: tarefa,
        tournamentId: tournamentId,
        editionId: editionId,
        alvo: alvo,
      );

  Map<String, dynamic> toJson() => {
        'tarefa': tarefa.wire,
        'tournamentId': tournamentId,
        'editionId': editionId,
        'alvo': alvo,
        'venceuEm': venceuEm.toIso8601String(),
        'transicaoPara': transicaoPara?.wire,
        'chaveIdempotencia': chaveIdempotencia,
      };

  @override
  String toString() => 'TarefaPendente($chaveIdempotencia)';
}

/// Estado da edicao que o planejador precisa saber e que nao esta na propria
/// edicao.
///
/// Passado por parametro em vez de consultado: mantem [planejarTarefas] pura e
/// testavel sem banco.
class ContextoAutomacao {
  /// A lotacao foi atingida. Fecha inscricoes antes do prazo.
  final bool lotado;

  /// Ha inscritos suficientes para a edicao acontecer.
  final bool quorumAtingido;

  /// O template usa janela de check-in.
  final bool usaCheckin;

  /// Fases cujas mesas ja encerraram e que ainda nao foram apuradas.
  final List<String> fasesApuraveis;

  /// Todas as fases terminaram.
  final bool todasFasesConcluidas;

  const ContextoAutomacao({
    this.lotado = false,
    this.quorumAtingido = false,
    this.usaCheckin = false,
    this.fasesApuraveis = const [],
    this.todasFasesConcluidas = false,
  });
}

/// Lista as tarefas vencidas para uma edicao no instante informado.
///
/// Funcao pura e deterministica: mesma edicao, mesmo contexto e mesmo instante
/// produzem exatamente a mesma lista, na mesma ordem.
///
/// Devolver a tarefa NAO significa que ela pode rodar: a camada de execucao ainda
/// passa por [avaliarTransicao] com [AtorTransicao.sistema], e o grafo de
/// transicoes automaticas e quem tem a ultima palavra. Duas guardas em vez de uma
/// porque o planejador enxerga calendario e o grafo enxerga legalidade.
List<TarefaPendente> planejarTarefas({
  required EdicaoTorneio edicao,
  required TorneioTemplate template,
  required DateTime agora,
  ContextoAutomacao contexto = const ContextoAutomacao(),
}) {
  final momento = agora.toUtc();
  final pendentes = <TarefaPendente>[];

  void adicionar(
    TarefaAutomatica tarefa, {
    required DateTime venceuEm,
    String? alvo,
    EdicaoStatus? transicaoPara,
  }) {
    pendentes.add(TarefaPendente(
      tarefa: tarefa,
      tournamentId: edicao.tournamentId,
      editionId: edicao.editionId,
      alvo: alvo,
      venceuEm: venceuEm,
      transicaoPara: transicaoPara,
    ));
  }

  // Edicao suspensa ou terminal nao gera tarefa: o agendador nao pode retomar o
  // que a administracao pausou de proposito.
  if (edicao.status.terminal || edicao.status == EdicaoStatus.suspenso) {
    return const [];
  }
  // Template incompleto tambem nao: abrir inscricao sem lotacao definida
  // produziria uma edicao que ninguem configurou (OS 02 secao 3).
  if (!template.configuracaoCompleta) return const [];

  final abre = edicao.inscricoesAbremEm;
  final fecha = edicao.inscricoesFechamEm;

  switch (edicao.status) {
    case EdicaoStatus.agendado:
    case EdicaoStatus.anunciado:
      if (abre != null && !momento.isBefore(abre)) {
        adicionar(TarefaAutomatica.abrirInscricoes,
            venceuEm: abre, transicaoPara: EdicaoStatus.inscricoesAbertas);
      }

    case EdicaoStatus.inscricoesAbertas:
      final venceuPorPrazo = fecha != null && !momento.isBefore(fecha);
      if (venceuPorPrazo || contexto.lotado) {
        adicionar(TarefaAutomatica.fecharInscricoes,
            venceuEm: venceuPorPrazo ? fecha : momento,
            transicaoPara: EdicaoStatus.inscricoesEncerradas);
      }

    case EdicaoStatus.inscricoesEncerradas:
      // Sem quorum a edicao nao anda sozinha. Cancelar e decisao administrativa
      // (o grafo nao autoriza o sistema a cancelar), entao aqui simplesmente nao
      // ha tarefa — e o painel de admin mostra a edicao parada.
      if (!contexto.quorumAtingido) break;
      if (contexto.usaCheckin) {
        adicionar(TarefaAutomatica.abrirCheckin,
            venceuEm: momento, transicaoPara: EdicaoStatus.checkinAberto);
      } else {
        adicionar(TarefaAutomatica.formarMesas,
            venceuEm: momento,
            alvo: 'fase-1',
            transicaoPara: EdicaoStatus.preparandoMesas);
      }

    case EdicaoStatus.checkinAberto:
      if (!momento.isBefore(edicao.inicioPrevisto)) {
        adicionar(TarefaAutomatica.formarMesas,
            venceuEm: edicao.inicioPrevisto,
            alvo: 'fase-1',
            transicaoPara: EdicaoStatus.preparandoMesas);
      }

    case EdicaoStatus.preparandoMesas:
      adicionar(TarefaAutomatica.iniciarEdicao,
          venceuEm: momento, transicaoPara: EdicaoStatus.emAndamento);

    case EdicaoStatus.emAndamento:
      // Uma tarefa por fase apuravel: o `alvo` e o que impede a apuracao da fase
      // 2 de ser descartada como repeticao da fase 1.
      for (final faseId in contexto.fasesApuraveis) {
        adicionar(TarefaAutomatica.avancarFase, venceuEm: momento, alvo: faseId);
      }
      if (contexto.todasFasesConcluidas) {
        adicionar(TarefaAutomatica.concluirEdicao,
            venceuEm: momento, transicaoPara: EdicaoStatus.aguardandoValidacao);
      }

    case EdicaoStatus.aguardandoValidacao:
      adicionar(TarefaAutomatica.concluirEdicao,
          venceuEm: momento, transicaoPara: EdicaoStatus.encerrado);
      adicionar(TarefaAutomatica.concederPremios, venceuEm: momento);
      adicionar(TarefaAutomatica.registrarClassificadosAnuais, venceuEm: momento);

    case EdicaoStatus.rascunho:
    case EdicaoStatus.encerrado:
    case EdicaoStatus.cancelado:
    case EdicaoStatus.suspenso:
      break;
  }

  return pendentes;
}

/// Filtra as tarefas que ainda nao rodaram.
///
/// [executadas] e o conjunto de chaves ja gravadas. Esta e a barreira que a
/// OS 02 secao 19 pede: reprocessar o planejamento devolve as mesmas chaves, e
/// as ja executadas somem aqui.
List<TarefaPendente> tarefasNaoExecutadas(
  Iterable<TarefaPendente> pendentes,
  Set<String> executadas,
) =>
    pendentes
        .where((t) => !executadas.contains(t.chaveIdempotencia))
        .toList(growable: false);
