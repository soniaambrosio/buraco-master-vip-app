// ui_contracts.dart — ponte entre o dominio de torneios e as telas Flutter
// (OS 02 secao 24).
//
// ESTE E O UNICO ARQUIVO DE app/lib/torneios/ QUE IMPORTA FLUTTER. Todos os
// outros sao Dart puro de proposito, para poderem rodar em teste, no servidor e
// em linha de comando sem subir widget. A fronteira e aqui, e so aqui.
//
// A DIRECAO DA DEPENDENCIA: este arquivo importa screens/torneios_models.dart, e
// nunca o contrario. As telas continuam exatamente como foram aprovadas — a
// OS 02 secao 25 proibe refaze-las, e nada em screens/ foi tocado. Quem se adapta
// e o dominio.
//
// POR QUE OS ENUMS SAO DOIS: `TorneioStatus`, `StatusParticipante` e
// `MotivoInscricaoRecusada` ja existem em screens/torneios_models.dart, mas
// aquele arquivo importa package:flutter/foundation.dart. Reusa-los no dominio
// arrastaria Flutter para dentro do motor e impediria o servidor de avaliar uma
// inscricao. A correspondencia e 1:1 e esta FIXADA POR TESTE: renomear um valor
// de um lado sem o outro quebra o portao antes de chegar na tela.
//
// O QUE ESTE ARQUIVO NAO FAZ: nao cria tela, nao desenha card, nao gera arte e
// nao decide layout (OS 02 secao 25). Ele so traduz.

import '../screens/torneios_models.dart' as ui;
import 'annual_closing.dart';
import 'champion.dart';
import 'history.dart';
import 'registrations.dart';
import 'seating.dart';
import 'standings.dart';
import 'tournament_lifecycle.dart';
import 'tournament_model.dart';

/// Traducao total de [EdicaoStatus] para o enum de tela.
///
/// Total de proposito: um `switch` sem `default` faz o compilador recusar o
/// codigo no dia em que alguem acrescentar um estado ao dominio sem decidir como
/// a tela o mostra. Um `default` silencioso deixaria o estado novo aparecer como
/// "Rascunho" para o jogador.
ui.TorneioStatus statusParaUi(EdicaoStatus status) => switch (status) {
      EdicaoStatus.rascunho => ui.TorneioStatus.rascunho,
      EdicaoStatus.agendado => ui.TorneioStatus.agendado,
      EdicaoStatus.anunciado => ui.TorneioStatus.anunciado,
      EdicaoStatus.inscricoesAbertas => ui.TorneioStatus.inscricoesAbertas,
      EdicaoStatus.inscricoesEncerradas => ui.TorneioStatus.inscricoesEncerradas,
      EdicaoStatus.checkinAberto => ui.TorneioStatus.checkinAberto,
      EdicaoStatus.preparandoMesas => ui.TorneioStatus.preparandoMesas,
      EdicaoStatus.emAndamento => ui.TorneioStatus.emAndamento,
      EdicaoStatus.aguardandoValidacao => ui.TorneioStatus.aguardandoValidacao,
      EdicaoStatus.encerrado => ui.TorneioStatus.encerrado,
      EdicaoStatus.cancelado => ui.TorneioStatus.cancelado,
      EdicaoStatus.suspenso => ui.TorneioStatus.suspenso,
    };

/// Traducao de [StatusInscricao] para o enum de tela.
///
/// [StatusInscricao.listaEspera] e [StatusInscricao.cancelado] nao existem em
/// `StatusParticipante` — sao estados de INSCRICAO, e a tela aprovada nao os
/// representa. Devolvem null em vez de um valor aproximado: mostrar quem esta na
/// lista de espera como "Inscrito" faria o jogador achar que tem vaga.
ui.StatusParticipante? participanteParaUi(StatusInscricao status) =>
    switch (status) {
      StatusInscricao.inscrito => ui.StatusParticipante.inscrito,
      StatusInscricao.aguardandoDupla => ui.StatusParticipante.aguardandoDupla,
      StatusInscricao.duplaConfirmada => ui.StatusParticipante.duplaConfirmada,
      StatusInscricao.checkinPendente => ui.StatusParticipante.checkinPendente,
      StatusInscricao.checkinRealizado => ui.StatusParticipante.checkinRealizado,
      StatusInscricao.ausente => ui.StatusParticipante.ausente,
      StatusInscricao.desclassificado => ui.StatusParticipante.desclassificado,
      StatusInscricao.convocadoParaMesa => ui.StatusParticipante.convocadoParaMesa,
      StatusInscricao.emPartida => ui.StatusParticipante.emPartida,
      StatusInscricao.listaEspera => null,
      StatusInscricao.cancelado => null,
    };

/// Traducao de [MotivoRecusaInscricao] para o enum de tela.
///
/// Os motivos que a tela aprovada nao conhece devolvem null; a camada de
/// apresentacao cai na mensagem generica que a tela ja tem.
ui.MotivoInscricaoRecusada? recusaParaUi(MotivoRecusaInscricao motivo) =>
    switch (motivo) {
      MotivoRecusaInscricao.semFichas => ui.MotivoInscricaoRecusada.semFichas,
      MotivoRecusaInscricao.lotado => ui.MotivoInscricaoRecusada.lotado,
      MotivoRecusaInscricao.inscricoesEncerradas =>
        ui.MotivoInscricaoRecusada.inscricoesEncerradas,
      MotivoRecusaInscricao.jaInscrito => ui.MotivoInscricaoRecusada.jaInscrito,
      MotivoRecusaInscricao.parceiroJaInscrito =>
        ui.MotivoInscricaoRecusada.parceiroJaInscrito,
      MotivoRecusaInscricao.requisitoVipNaoAtendido =>
        ui.MotivoInscricaoRecusada.requisitoVipNaoAtendido,
      MotivoRecusaInscricao.perfilSuspenso =>
        ui.MotivoInscricaoRecusada.perfilSuspenso,
      MotivoRecusaInscricao.conflitoComOutraPartida =>
        ui.MotivoInscricaoRecusada.conflitoComOutraPartida,
      MotivoRecusaInscricao.inelegivel => null,
      MotivoRecusaInscricao.parceiroInvalido => null,
      MotivoRecusaInscricao.configuracaoPendente => null,
    };

/// Traducao de [ModalidadeMesa] para o enum de tela.
ui.ModalidadeTorneio modalidadeParaUi(ModalidadeMesa modalidade) =>
    switch (modalidade) {
      ModalidadeMesa.aberto => ui.ModalidadeTorneio.aberto,
      ModalidadeMesa.fechado => ui.ModalidadeTorneio.fechado,
      ModalidadeMesa.stbl => ui.ModalidadeTorneio.stbl,
    };

/// Traducao de [TipoParticipacao] para o enum de tela.
ui.TipoParticipacao participacaoParaUi(TipoParticipacao tipo) => switch (tipo) {
      TipoParticipacao.individual => ui.TipoParticipacao.individual,
      TipoParticipacao.dupla => ui.TipoParticipacao.dupla,
    };

/// Em que secao da central o card aparece.
///
/// Deriva do estado do dominio em vez de ser um campo gravado: um campo gravado
/// ficaria desatualizado no minuto em que o status mudasse, e a central mostraria
/// um torneio encerrado na aba "inscricoes abertas".
ui.SecaoCentral secaoParaUi({
  required EdicaoStatus status,
  required bool inscrito,
}) {
  if (inscrito && status.emDisputa) return ui.SecaoCentral.emAndamento;
  if (inscrito && !status.terminal) return ui.SecaoCentral.meus;
  return switch (status) {
    EdicaoStatus.inscricoesAbertas => ui.SecaoCentral.inscricoesAbertas,
    EdicaoStatus.agendado ||
    EdicaoStatus.anunciado ||
    EdicaoStatus.inscricoesEncerradas ||
    EdicaoStatus.checkinAberto =>
      ui.SecaoCentral.proximos,
    EdicaoStatus.preparandoMesas ||
    EdicaoStatus.emAndamento ||
    EdicaoStatus.aguardandoValidacao =>
      ui.SecaoCentral.emAndamento,
    EdicaoStatus.encerrado || EdicaoStatus.cancelado => ui.SecaoCentral.encerrados,
    EdicaoStatus.rascunho || EdicaoStatus.suspenso => ui.SecaoCentral.proximos,
  };
}

/// Quais botoes a tela oferece no estado atual (OS 02 secao 24).
///
/// A decisao mora AQUI, nao no widget: OS 02 diretriz final — "nao acoplar regras
/// criticas a interface". A tela desenha o que esta na lista; ela nao decide se o
/// jogador pode se inscrever.
List<ui.BotaoTorneio> botoesParaUi({
  required EdicaoStatus status,
  required StatusInscricao? minhaInscricao,
}) {
  final inscrito = minhaInscricao != null && minhaInscricao.ativo;

  return switch (status) {
    EdicaoStatus.inscricoesAbertas => inscrito
        ? const [ui.BotaoTorneio.cancelarInscricao, ui.BotaoTorneio.convidarDupla]
        : const [ui.BotaoTorneio.inscrever, ui.BotaoTorneio.convidarDupla],
    EdicaoStatus.checkinAberto => inscrito
        ? const [ui.BotaoTorneio.fazerCheckin, ui.BotaoTorneio.entrarSalaEspera]
        : const [ui.BotaoTorneio.verClassificacao],
    EdicaoStatus.preparandoMesas || EdicaoStatus.emAndamento => inscrito
        ? const [ui.BotaoTorneio.entrarSalaEspera, ui.BotaoTorneio.verClassificacao]
        : const [ui.BotaoTorneio.verClassificacao],
    EdicaoStatus.aguardandoValidacao => const [ui.BotaoTorneio.verClassificacao],
    EdicaoStatus.encerrado => const [
        ui.BotaoTorneio.verResultado,
        ui.BotaoTorneio.verClassificacao,
      ],
    // Rascunho, agendado, anunciado, inscricoes encerradas, cancelado e suspenso
    // nao oferecem acao ao jogador; a tela mostra so o estado.
    _ => const [ui.BotaoTorneio.verClassificacao],
  };
}

/// Monta o card da central a partir do dominio (OS 02 secao 24).
ui.TorneioCardVM cardDaEdicao({
  required EdicaoTorneio edicao,
  required TorneioTemplate template,
  required int inscritos,
  required String premiacaoPrincipal,
  required String? capaUrl,
  required DateTime agora,
  bool inscrito = false,
  int valorEntrada = 0,
}) {
  final fecha = edicao.inscricoesFechamEm;
  final restante = fecha == null || !fecha.isAfter(agora.toUtc())
      ? null
      : fecha.difference(agora.toUtc());

  return ui.TorneioCardVM(
    tournamentId: edicao.tournamentId,
    nome: template.nome,
    imagemUrl: capaUrl,
    // A modalidade vem da EDICAO: a politica do template pode ser "alterna" ou
    // "rodizio", e nesse caso nao existe modalidade de torneio, so de edicao.
    // O fallback so vale para politica fixa, onde os dois coincidem.
    modalidade: modalidadeParaUi(
      edicao.modalidade ??
          template.modalidade.valor ??
          ModalidadeMesa.aberto,
    ),
    acesso: switch (template.acesso) {
      AcessoTorneio.vip || AcessoTorneio.somenteConvidados => ui.TipoAcesso.vip,
      AcessoTorneio.misto => ui.TipoAcesso.misto,
      AcessoTorneio.publico => ui.TipoAcesso.publico,
    },
    participacao: participacaoParaUi(template.participacao),
    dataHora: edicao.inicioPrevisto,
    vagasTotais: template.vagasMax ?? 0,
    inscritos: inscritos,
    entrada: valorEntrada > 0 ? ui.TipoEntrada.fichas : ui.TipoEntrada.gratuito,
    valorEntrada: valorEntrada,
    premiacaoPrincipal: premiacaoPrincipal,
    status: statusParaUi(edicao.status),
    tempoRestanteInscricao: restante,
    secao: secaoParaUi(status: edicao.status, inscrito: inscrito),
    inscrito: inscrito,
  );
}

/// Monta uma linha da tabela de classificacao (OS 02 secao 24).
///
/// [nome] vem da camada de perfil: o dominio guarda identificadores, nao apelidos
/// — um apelido gravado na classificacao ficaria desatualizado no dia em que o
/// jogador o trocasse.
ui.ClassificacaoLinhaVM linhaParaUi(
  LinhaClassificacao linha, {
  required String nome,
  String? avatarUrl,
  bool souEu = false,
}) =>
    ui.ClassificacaoLinhaVM(
      posicao: linha.posicao,
      nome: nome,
      avatarUrl: avatarUrl,
      souEu: souEu,
      vitorias: linha.desempenho.vitorias,
      derrotas: linha.desempenho.derrotas,
      pontosFeitos: linha.desempenho.pontosFeitos,
      pontosSofridos: linha.desempenho.pontosSofridos,
      saldo: linha.desempenho.saldo,
      canastrasLimpas: linha.desempenho.canastrasLimpas,
      partidasConcluidas: linha.desempenho.partidasConcluidas,
      status: switch (linha.situacao) {
        SituacaoClassificacao.eliminado => ui.StatusParticipante.desclassificado,
        SituacaoClassificacao.avancou => ui.StatusParticipante.checkinRealizado,
        SituacaoClassificacao.ativo => ui.StatusParticipante.inscrito,
      },
    );

/// Monta um confronto da sala de espera / classificacao (OS 02 secao 24).
ui.ConfrontoVM confrontoParaUi(
  Mesa mesa, {
  required int rodada,
  required List<String> nomes,
  DateTime? horario,
  String? resultado,
  bool ehMeu = false,
}) =>
    ui.ConfrontoVM(
      confrontoId: mesa.mesaId,
      rodada: rodada,
      mesaLabel: 'Mesa ${mesa.numero}',
      horario: horario,
      duplaA: nomes.isNotEmpty ? nomes[0] : '',
      duplaB: nomes.length > 1 ? nomes[1] : '',
      resultado: resultado,
      statusPartida: switch (mesa.status) {
        StatusMesa.formada => 'aguardando',
        StatusMesa.emJogo => 'em jogo',
        StatusMesa.encerrada => 'encerrada',
        StatusMesa.cancelada => 'cancelada',
      },
      ehMeu: ehMeu,
    );

/// Dados do convite ao encerramento anual que a tela e a arte automatica
/// consomem (OS 02 secao 18).
///
/// A OS e explicita: "A geracao de imagem/cartao nao faz parte desta ordem de
/// servico. O sistema devera apenas fornecer os dados necessarios". E o que esta
/// classe faz — nenhum pixel e produzido aqui.
class ConviteVM {
  final String userId;
  final String temporada;
  final String statusWire;
  final String statusLabel;

  /// Quantas vezes o jogador se classificou na temporada.
  final int classificacoes;

  /// O jogador pode aceitar ou recusar agora.
  final bool aguardandoResposta;

  final DateTime atualizadoEm;

  const ConviteVM({
    required this.userId,
    required this.temporada,
    required this.statusWire,
    required this.statusLabel,
    required this.classificacoes,
    required this.aguardandoResposta,
    required this.atualizadoEm,
  });
}

/// Rotulo em portugues para cada estado de convite.
String rotuloConvite(StatusConvite status) => switch (status) {
      StatusConvite.elegivel => 'Classificado',
      StatusConvite.convitePendente => 'Convite pendente',
      StatusConvite.conviteGerado => 'Convite gerado',
      StatusConvite.conviteEnviado => 'Convite enviado',
      StatusConvite.conviteAceito => 'Convite aceito',
      StatusConvite.conviteRecusado => 'Convite recusado',
      StatusConvite.confirmado => 'Presenca confirmada',
      StatusConvite.participou => 'Participou',
      StatusConvite.ausencia => 'Ausente',
    };

ConviteVM conviteParaUi(ConviteEncerramento convite) => ConviteVM(
      userId: convite.userId,
      temporada: convite.temporada,
      statusWire: convite.status.wire,
      statusLabel: rotuloConvite(convite.status),
      classificacoes: convite.classificacoes,
      aguardandoResposta: convite.status == StatusConvite.conviteEnviado,
      atualizadoEm: convite.atualizadoEm,
    );

/// Resumo de uma edicao encerrada para a aba de historico (OS 02 secao 24).
class HistoricoResumoVM {
  final String tournamentId;
  final String editionId;
  final String nomeTorneio;
  final int numeroEdicao;
  final String temporada;
  final DateTime encerramento;
  final String campeaoId;
  final int totalParticipantes;

  /// Colocacao do jogador consultado. null quando ele nao participou.
  final int? minhaColocacao;

  const HistoricoResumoVM({
    required this.tournamentId,
    required this.editionId,
    required this.nomeTorneio,
    required this.numeroEdicao,
    required this.temporada,
    required this.encerramento,
    required this.campeaoId,
    required this.totalParticipantes,
    this.minhaColocacao,
  });
}

HistoricoResumoVM historicoParaUi(RegistroHistorico registro, {String? userId}) =>
    HistoricoResumoVM(
      tournamentId: registro.tournamentId,
      editionId: registro.editionId,
      nomeTorneio: registro.nomeTorneio,
      numeroEdicao: registro.numeroEdicao,
      temporada: registro.temporada,
      encerramento: registro.encerramento,
      campeaoId: registro.campeaoId,
      totalParticipantes: registro.totalParticipantes,
      minhaColocacao: userId == null ? null : registro.colocacaoDe(userId),
    );

/// Premiacao de uma edicao, no formato que a tela ja espera (OS 02 secao 24).
///
/// [statusEntrega] usa os mesmos textos que o mock aprovado ja emprega
/// ("entregue", "pendente"), para a tela nao precisar de um mapa novo.
List<ui.PremiacaoVM> premiacoesParaUi(List<PremiacaoPlanejada> planejadas) => [
      for (final p in planejadas)
        if (p.resultado.concedida)
          ui.PremiacaoVM(
            rewardId: p.resultado.concessao!.rewardId,
            posicao: p.colocacao,
            tipo: ui.TipoPremio.selo,
            valorLabel: p.resultado.concessao!.assetId,
            statusEntrega: 'entregue',
          )
        else
          ui.PremiacaoVM(
            rewardId: 'pendente-${p.userId}-${p.colocacao}',
            posicao: p.colocacao,
            tipo: ui.TipoPremio.fichas,
            valorLabel: p.fichas == null ? '—' : '${p.fichas} fichas',
            statusEntrega: 'pendente',
          ),
    ];
