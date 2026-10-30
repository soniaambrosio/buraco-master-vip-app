import 'package:flutter/foundation.dart';

enum TorneioStatus {
  rascunho,
  agendado,
  anunciado,
  inscricoesAbertas,
  inscricoesEncerradas,
  checkinAberto,
  preparandoMesas,
  emAndamento,
  aguardandoValidacao,
  encerrado,
  cancelado,
  suspenso,
}

enum StatusParticipante {
  inscrito,
  aguardandoDupla,
  duplaConfirmada,
  checkinPendente,
  checkinRealizado,
  ausente,
  desclassificado,
  convocadoParaMesa,
  emPartida,
}

enum ModalidadeTorneio { aberto, fechado, stbl }
enum TipoParticipacao { individual, dupla }
enum TipoAcesso { publico, vip, misto }
enum TipoEntrada { gratuito, fichas }
enum Recorrencia { unico, semanal, quinzenal, mensal, ultimoDiaDoMes, dataEspecial }
enum TipoPremio {
  fichas,
  pontosRanking,
  selo,
  titulo,
  moldura,
  coroa,
  mascote,
  presente,
  itemColecionavel,
  entradaTorneio,
  destaqueHallImortais,
}

enum MotivoInscricaoRecusada {
  semFichas,
  lotado,
  inscricoesEncerradas,
  jaInscrito,
  parceiroJaInscrito,
  requisitoVipNaoAtendido,
  perfilSuspenso,
  conflitoComOutraPartida,
}

enum SecaoCentral { destaque, inscricoesAbertas, proximos, emAndamento, meus, encerrados }
enum BotaoTorneio {
  inscrever,
  convidarDupla,
  confirmarDupla,
  cancelarInscricao,
  fazerCheckin,
  entrarSalaEspera,
  verClassificacao,
  verResultado,
}

enum AcaoAdmin {
  ativar,
  pausar,
  cancelarEdicao,
  reabrirInscricoes,
  ampliarVagas,
  reduzirVagas,
  alterarPremiacao,
  iniciar,
  encerrar,
  validarResultado,
  liberarPremiacao,
  verHistorico,
}

@immutable
class TorneioCardVM {
  final String tournamentId;
  final String nome;
  final String? imagemUrl;
  final ModalidadeTorneio modalidade;
  final TipoAcesso acesso;
  final TipoParticipacao participacao;
  final DateTime dataHora;
  final int vagasTotais;
  final int inscritos;
  final TipoEntrada entrada;
  final int valorEntrada;
  final String premiacaoPrincipal;
  final TorneioStatus status;
  final Duration? tempoRestanteInscricao;
  final SecaoCentral secao;
  final bool inscrito;

  const TorneioCardVM({
    required this.tournamentId,
    required this.nome,
    this.imagemUrl,
    required this.modalidade,
    required this.acesso,
    required this.participacao,
    required this.dataHora,
    required this.vagasTotais,
    required this.inscritos,
    required this.entrada,
    required this.valorEntrada,
    required this.premiacaoPrincipal,
    required this.status,
    this.tempoRestanteInscricao,
    required this.secao,
    this.inscrito = false,
  });
}

@immutable
class PremiacaoVM {
  final String rewardId;
  final int posicao;
  final TipoPremio tipo;
  final String valorLabel;
  final String statusEntrega;

  const PremiacaoVM({
    required this.rewardId,
    required this.posicao,
    required this.tipo,
    required this.valorLabel,
    required this.statusEntrega,
  });
}

@immutable
class TorneioDetalhesVM {
  final TorneioCardVM card;
  final String descricao;
  final String regras;
  final DateTime checkinAbre;
  final DateTime checkinFecha;
  final int rodadasPrevistas;
  final String criteriosClassificacao;
  final String criteriosDesempate;
  final String regrasAbandono;
  final String regrasDesconexao;
  final String politicaCancelamento;
  final List<PremiacaoVM> premiacoes;
  final StatusParticipante? minhaInscricao;
  final List<BotaoTorneio> botoes;

  const TorneioDetalhesVM({
    required this.card,
    required this.descricao,
    required this.regras,
    required this.checkinAbre,
    required this.checkinFecha,
    required this.rodadasPrevistas,
    required this.criteriosClassificacao,
    required this.criteriosDesempate,
    required this.regrasAbandono,
    required this.regrasDesconexao,
    required this.politicaCancelamento,
    required this.premiacoes,
    this.minhaInscricao,
    required this.botoes,
  });
}

@immutable
class AmigoConvidavelVM {
  final String playerId;
  final String nome;
  final String? avatarUrl;
  final bool online;

  const AmigoConvidavelVM({
    required this.playerId,
    required this.nome,
    this.avatarUrl,
    this.online = false,
  });
}

@immutable
class InscricaoModalVM {
  final String tournamentId;
  final String nome;
  final ModalidadeTorneio modalidade;
  final DateTime dataHora;
  final TipoEntrada entrada;
  final int valorEntrada;
  final int meuSaldoFichas;
  final String premiacaoResumo;
  final bool exigeConfirmacaoRegras;
  final TipoParticipacao participacao;
  final List<AmigoConvidavelVM> amigos;
  final String? convitePendenteDe;
  final String? statusDupla;
  final MotivoInscricaoRecusada? recusa;
  final String? mensagemRecusa;

  const InscricaoModalVM({
    required this.tournamentId,
    required this.nome,
    required this.modalidade,
    required this.dataHora,
    required this.entrada,
    required this.valorEntrada,
    required this.meuSaldoFichas,
    required this.premiacaoResumo,
    this.exigeConfirmacaoRegras = true,
    required this.participacao,
    this.amigos = const [],
    this.convitePendenteDe,
    this.statusDupla,
    this.recusa,
    this.mensagemRecusa,
  });
}

@immutable
class ConfrontoVM {
  final String confrontoId;
  final int rodada;
  final String mesaLabel;
  final DateTime? horario;
  final String duplaA;
  final String duplaB;
  final String? resultado;
  final String statusPartida;
  final bool ehMeu;

  const ConfrontoVM({
    required this.confrontoId,
    required this.rodada,
    required this.mesaLabel,
    this.horario,
    required this.duplaA,
    required this.duplaB,
    this.resultado,
    required this.statusPartida,
    this.ehMeu = false,
  });
}

@immutable
class SalaEsperaVM {
  final String tournamentId;
  final String nome;
  final Duration contagemRegressiva;
  final TorneioStatus status;
  final DateTime inicio;
  final int participantes;
  final int checkins;
  final StatusParticipante meuStatus;
  final String? statusDupla;
  final List<String> mensagensOficiais;
  final String regrasResumo;
  final ConfrontoVM? meuConfronto;

  const SalaEsperaVM({
    required this.tournamentId,
    required this.nome,
    required this.contagemRegressiva,
    required this.status,
    required this.inicio,
    required this.participantes,
    required this.checkins,
    required this.meuStatus,
    this.statusDupla,
    required this.mensagensOficiais,
    required this.regrasResumo,
    this.meuConfronto,
  });
}

@immutable
class ClassificacaoLinhaVM {
  final int posicao;
  final String nome;
  final String? avatarUrl;
  final bool souEu;
  final int vitorias;
  final int derrotas;
  final int pontosFeitos;
  final int pontosSofridos;
  final int saldo;
  final int canastrasLimpas;
  final int partidasConcluidas;
  final StatusParticipante status;

  const ClassificacaoLinhaVM({
    required this.posicao,
    required this.nome,
    this.avatarUrl,
    this.souEu = false,
    required this.vitorias,
    required this.derrotas,
    required this.pontosFeitos,
    required this.pontosSofridos,
    required this.saldo,
    required this.canastrasLimpas,
    required this.partidasConcluidas,
    required this.status,
  });
}

@immutable
class MinhaParticipacaoVM {
  final int posicaoAtual;
  final ConfrontoVM? proximoConfronto;
  final String desempenhoResumo;
  final String criterios;
  final List<String> resultadosAnteriores;

  const MinhaParticipacaoVM({
    required this.posicaoAtual,
    this.proximoConfronto,
    required this.desempenhoResumo,
    required this.criterios,
    required this.resultadosAnteriores,
  });
}

@immutable
class ClassificacaoTorneioVM {
  final String tournamentId;
  final String nome;
  final int rodadaAtual;
  final List<ClassificacaoLinhaVM> classificacao;
  final List<ConfrontoVM> confrontos;
  final MinhaParticipacaoVM minhaParticipacao;

  const ClassificacaoTorneioVM({
    required this.tournamentId,
    required this.nome,
    required this.rodadaAtual,
    required this.classificacao,
    required this.confrontos,
    required this.minhaParticipacao,
  });
}

@immutable
class ResultadoTorneioVM {
  final String tournamentId;
  final String nome;
  final String campeao;
  final String? vice;
  final String? terceiro;
  final List<ClassificacaoLinhaVM> classificacaoFinal;
  final int totalParticipantes;
  final String estatisticas;
  final List<PremiacaoVM> minhasPremiacoes;
  final bool registraHallDosImortais;
  final int? minhaPosicaoRanking;

  const ResultadoTorneioVM({
    required this.tournamentId,
    required this.nome,
    required this.campeao,
    this.vice,
    this.terceiro,
    required this.classificacaoFinal,
    required this.totalParticipantes,
    required this.estatisticas,
    required this.minhasPremiacoes,
    this.registraHallDosImortais = false,
    this.minhaPosicaoRanking,
  });
}

@immutable
class FaixaTorneioMesaVM {
  final String nomeTorneio;
  final int rodada;
  final String mesaLabel;
  final String faseOuPosicao;
  final int pontuacaoAcumulada;

  const FaixaTorneioMesaVM({
    required this.nomeTorneio,
    required this.rodada,
    required this.mesaLabel,
    required this.faseOuPosicao,
    required this.pontuacaoAcumulada,
  });
}

@immutable
class AdminTorneioResumoVM {
  final String id;
  final String nome;
  final int edicao;
  final DateTime data;
  final ModalidadeTorneio modalidade;
  final int inscritos;
  final int vagas;
  final TorneioStatus status;
  final int arrecadacaoFichas;
  final String premiacaoPrevista;
  final int checkins;
  final int mesasAtivas;
  final List<String> alertas;

  const AdminTorneioResumoVM({
    required this.id,
    required this.nome,
    required this.edicao,
    required this.data,
    required this.modalidade,
    required this.inscritos,
    required this.vagas,
    required this.status,
    required this.arrecadacaoFichas,
    required this.premiacaoPrevista,
    required this.checkins,
    required this.mesasAtivas,
    this.alertas = const [],
  });
}

@immutable
class ModeloTorneioForm {
  final String? templateId;
  final String nome;
  final String descricao;
  final String? imagemUrl;
  final ModalidadeTorneio modalidade;
  final TipoParticipacao participacao;
  final TipoAcesso acesso;
  final TipoEntrada entrada;
  final int valorEntrada;
  final int minJogadores;
  final int maxJogadores;
  final int rodadas;
  final Duration duracaoEstimada;
  final int metaPontos;
  final bool espectadoresPermitidos;
  final Recorrencia recorrencia;
  final String horario;
  final String fusoHorario;
  final DateTime? inicioRecorrencia;
  final DateTime? fimRecorrencia;
  final int? maxEdicoes;
  final List<DateTime> excecoes;
  final bool pausado;
  final Duration antecedenciaInscricao;
  final Duration encerramentoInscricao;
  final bool listaEspera;
  final bool entradaAutomaticaListaEspera;
  final bool permiteDesistencia;
  final bool devolveFichas;
  final Duration prazoCancelamentoSemPenalidade;
  final Duration checkinAbertura;
  final Duration checkinEncerramento;
  final Duration tolerancia;
  final bool eliminaPorAusencia;
  final bool convocaListaEspera;
  final List<PremiacaoVM> premiacoes;
  final List<String> criteriosDesempate;
  final String regrasAbandono;
  final String regrasDesconexao;
  final String regrasConduta;
  final Map<String, bool> notificacoes;
  final bool ativo;

  const ModeloTorneioForm({
    this.templateId,
    required this.nome,
    required this.descricao,
    this.imagemUrl,
    required this.modalidade,
    required this.participacao,
    required this.acesso,
    required this.entrada,
    required this.valorEntrada,
    required this.minJogadores,
    required this.maxJogadores,
    required this.rodadas,
    required this.duracaoEstimada,
    required this.metaPontos,
    required this.espectadoresPermitidos,
    required this.recorrencia,
    required this.horario,
    required this.fusoHorario,
    this.inicioRecorrencia,
    this.fimRecorrencia,
    this.maxEdicoes,
    this.excecoes = const [],
    this.pausado = false,
    required this.antecedenciaInscricao,
    required this.encerramentoInscricao,
    required this.listaEspera,
    required this.entradaAutomaticaListaEspera,
    required this.permiteDesistencia,
    required this.devolveFichas,
    required this.prazoCancelamentoSemPenalidade,
    required this.checkinAbertura,
    required this.checkinEncerramento,
    required this.tolerancia,
    required this.eliminaPorAusencia,
    required this.convocaListaEspera,
    required this.premiacoes,
    required this.criteriosDesempate,
    required this.regrasAbandono,
    required this.regrasDesconexao,
    required this.regrasConduta,
    required this.notificacoes,
    this.ativo = true,
  });

  ModeloTorneioForm copyWith({
    String? templateId,
    String? nome,
    String? descricao,
    String? imagemUrl,
    ModalidadeTorneio? modalidade,
    TipoParticipacao? participacao,
    TipoAcesso? acesso,
    TipoEntrada? entrada,
    int? valorEntrada,
    int? minJogadores,
    int? maxJogadores,
    int? rodadas,
    Duration? duracaoEstimada,
    int? metaPontos,
    bool? espectadoresPermitidos,
    Recorrencia? recorrencia,
    String? horario,
    String? fusoHorario,
    DateTime? inicioRecorrencia,
    DateTime? fimRecorrencia,
    int? maxEdicoes,
    List<DateTime>? excecoes,
    bool? pausado,
    Duration? antecedenciaInscricao,
    Duration? encerramentoInscricao,
    bool? listaEspera,
    bool? entradaAutomaticaListaEspera,
    bool? permiteDesistencia,
    bool? devolveFichas,
    Duration? prazoCancelamentoSemPenalidade,
    Duration? checkinAbertura,
    Duration? checkinEncerramento,
    Duration? tolerancia,
    bool? eliminaPorAusencia,
    bool? convocaListaEspera,
    List<PremiacaoVM>? premiacoes,
    List<String>? criteriosDesempate,
    String? regrasAbandono,
    String? regrasDesconexao,
    String? regrasConduta,
    Map<String, bool>? notificacoes,
    bool? ativo,
  }) {
    return ModeloTorneioForm(
      templateId: templateId ?? this.templateId,
      nome: nome ?? this.nome,
      descricao: descricao ?? this.descricao,
      imagemUrl: imagemUrl ?? this.imagemUrl,
      modalidade: modalidade ?? this.modalidade,
      participacao: participacao ?? this.participacao,
      acesso: acesso ?? this.acesso,
      entrada: entrada ?? this.entrada,
      valorEntrada: valorEntrada ?? this.valorEntrada,
      minJogadores: minJogadores ?? this.minJogadores,
      maxJogadores: maxJogadores ?? this.maxJogadores,
      rodadas: rodadas ?? this.rodadas,
      duracaoEstimada: duracaoEstimada ?? this.duracaoEstimada,
      metaPontos: metaPontos ?? this.metaPontos,
      espectadoresPermitidos: espectadoresPermitidos ?? this.espectadoresPermitidos,
      recorrencia: recorrencia ?? this.recorrencia,
      horario: horario ?? this.horario,
      fusoHorario: fusoHorario ?? this.fusoHorario,
      inicioRecorrencia: inicioRecorrencia ?? this.inicioRecorrencia,
      fimRecorrencia: fimRecorrencia ?? this.fimRecorrencia,
      maxEdicoes: maxEdicoes ?? this.maxEdicoes,
      excecoes: excecoes ?? this.excecoes,
      pausado: pausado ?? this.pausado,
      antecedenciaInscricao: antecedenciaInscricao ?? this.antecedenciaInscricao,
      encerramentoInscricao: encerramentoInscricao ?? this.encerramentoInscricao,
      listaEspera: listaEspera ?? this.listaEspera,
      entradaAutomaticaListaEspera:
          entradaAutomaticaListaEspera ?? this.entradaAutomaticaListaEspera,
      permiteDesistencia: permiteDesistencia ?? this.permiteDesistencia,
      devolveFichas: devolveFichas ?? this.devolveFichas,
      prazoCancelamentoSemPenalidade:
          prazoCancelamentoSemPenalidade ?? this.prazoCancelamentoSemPenalidade,
      checkinAbertura: checkinAbertura ?? this.checkinAbertura,
      checkinEncerramento: checkinEncerramento ?? this.checkinEncerramento,
      tolerancia: tolerancia ?? this.tolerancia,
      eliminaPorAusencia: eliminaPorAusencia ?? this.eliminaPorAusencia,
      convocaListaEspera: convocaListaEspera ?? this.convocaListaEspera,
      premiacoes: premiacoes ?? this.premiacoes,
      criteriosDesempate: criteriosDesempate ?? this.criteriosDesempate,
      regrasAbandono: regrasAbandono ?? this.regrasAbandono,
      regrasDesconexao: regrasDesconexao ?? this.regrasDesconexao,
      regrasConduta: regrasConduta ?? this.regrasConduta,
      notificacoes: notificacoes ?? this.notificacoes,
      ativo: ativo ?? this.ativo,
    );
  }
}

typedef ConfirmarInscricaoCallback = void Function(
  String id, {
  String? parceiroId,
  required bool regrasLidas,
});

@immutable
class TorneiosCallbacks {
  final void Function(String id) onAbrirDetalhes;
  final void Function(String id) onInscrever;
  final ConfirmarInscricaoCallback onConfirmarInscricao;
  final void Function(String id, String playerId) onConvidarParceiro;
  final void Function(String id) onAceitarConvite;
  final void Function(String id) onCancelarConvite;
  final void Function(String id) onCancelarInscricao;
  final void Function(String id) onFazerCheckin;
  final void Function(String id) onEntrarSalaEspera;
  final void Function(String id, String confrontoId) onEntrarNaMesa;
  final void Function(String id) onVerClassificacao;
  final void Function(String id) onVerResultado;
  final void Function(String rewardId) onResgatarPremio;
  final void Function(String id) onCompartilharConquista;
  final void Function(Set<String> filtros) onFiltrarCentral;
  final VoidCallback onCriarModelo;
  final void Function(String templateId) onEditarModelo;
  final void Function(ModeloTorneioForm form) onSalvarModelo;
  final void Function(String tournamentId, AcaoAdmin acao) onAcaoAdmin;

  const TorneiosCallbacks({
    required this.onAbrirDetalhes,
    required this.onInscrever,
    required this.onConfirmarInscricao,
    required this.onConvidarParceiro,
    required this.onAceitarConvite,
    required this.onCancelarConvite,
    required this.onCancelarInscricao,
    required this.onFazerCheckin,
    required this.onEntrarSalaEspera,
    required this.onEntrarNaMesa,
    required this.onVerClassificacao,
    required this.onVerResultado,
    required this.onResgatarPremio,
    required this.onCompartilharConquista,
    required this.onFiltrarCentral,
    required this.onCriarModelo,
    required this.onEditarModelo,
    required this.onSalvarModelo,
    required this.onAcaoAdmin,
  });
}

extension ModalidadeTorneioLabel on ModalidadeTorneio {
  String get label => switch (this) {
        ModalidadeTorneio.aberto => 'ABERTO',
        ModalidadeTorneio.fechado => 'FECHADO',
        ModalidadeTorneio.stbl => 'STBL',
      };
}

extension TorneioStatusLabel on TorneioStatus {
  String get label => switch (this) {
        TorneioStatus.rascunho => 'Rascunho',
        TorneioStatus.agendado => 'Agendado',
        TorneioStatus.anunciado => 'Anunciado',
        TorneioStatus.inscricoesAbertas => 'Inscrições abertas',
        TorneioStatus.inscricoesEncerradas => 'Inscrições encerradas',
        TorneioStatus.checkinAberto => 'Check-in aberto',
        TorneioStatus.preparandoMesas => 'Preparando mesas',
        TorneioStatus.emAndamento => 'Em andamento',
        TorneioStatus.aguardandoValidacao => 'Aguardando validação',
        TorneioStatus.encerrado => 'Encerrado',
        TorneioStatus.cancelado => 'Cancelado',
        TorneioStatus.suspenso => 'Suspenso',
      };
}

extension StatusParticipanteLabel on StatusParticipante {
  String get label => switch (this) {
        StatusParticipante.inscrito => 'Inscrito',
        StatusParticipante.aguardandoDupla => 'Aguardando dupla',
        StatusParticipante.duplaConfirmada => 'Dupla confirmada',
        StatusParticipante.checkinPendente => 'Check-in pendente',
        StatusParticipante.checkinRealizado => 'Check-in realizado',
        StatusParticipante.ausente => 'Ausente',
        StatusParticipante.desclassificado => 'Desclassificado',
        StatusParticipante.convocadoParaMesa => 'Convocado para a mesa',
        StatusParticipante.emPartida => 'Em partida',
      };
}

class TorneiosMockData {
  static DateTime get _base => DateTime(2026, 8, 5, 20);

  static List<TorneioCardVM> cards() => [
        TorneioCardVM(
          tournamentId: 'quarta-vulnerabilidade',
          nome: 'Quarta da Vulnerabilidade',
          modalidade: ModalidadeTorneio.fechado,
          acesso: TipoAcesso.misto,
          participacao: TipoParticipacao.dupla,
          dataHora: _base,
          vagasTotais: 64,
          inscritos: 48,
          entrada: TipoEntrada.gratuito,
          valorEntrada: 0,
          premiacaoPrincipal: '1.000 fichas + Coroa Ametista',
          status: TorneioStatus.inscricoesAbertas,
          tempoRestanteInscricao: const Duration(hours: 7, minutes: 42),
          secao: SecaoCentral.destaque,
        ),
        TorneioCardVM(
          tournamentId: 'sexta-master-vip',
          nome: 'Sexta Master VIP',
          modalidade: ModalidadeTorneio.stbl,
          acesso: TipoAcesso.vip,
          participacao: TipoParticipacao.dupla,
          dataHora: _base.add(const Duration(days: 2, hours: 1)),
          vagasTotais: 48,
          inscritos: 44,
          entrada: TipoEntrada.fichas,
          valorEntrada: 500,
          premiacaoPrincipal: '4.000 fichas + Título exclusivo',
          status: TorneioStatus.checkinAberto,
          tempoRestanteInscricao: Duration.zero,
          secao: SecaoCentral.meus,
          inscrito: true,
        ),
        TorneioCardVM(
          tournamentId: 'copa-buraco-master',
          nome: 'Copa Buraco Master',
          modalidade: ModalidadeTorneio.aberto,
          acesso: TipoAcesso.publico,
          participacao: TipoParticipacao.individual,
          dataHora: _base.add(const Duration(days: 5)),
          vagasTotais: 128,
          inscritos: 91,
          entrada: TipoEntrada.gratuito,
          valorEntrada: 0,
          premiacaoPrincipal: 'Selo Campeão + 2.500 pts',
          status: TorneioStatus.anunciado,
          tempoRestanteInscricao: const Duration(days: 3),
          secao: SecaoCentral.proximos,
        ),
        TorneioCardVM(
          tournamentId: 'domingo-pintando-7',
          nome: 'Domingo Pintando o 7',
          modalidade: ModalidadeTorneio.fechado,
          acesso: TipoAcesso.publico,
          participacao: TipoParticipacao.dupla,
          dataHora: _base.subtract(const Duration(hours: 1)),
          vagasTotais: 32,
          inscritos: 32,
          entrada: TipoEntrada.fichas,
          valorEntrada: 250,
          premiacaoPrincipal: '2.000 fichas + Moldura 7 Real',
          status: TorneioStatus.emAndamento,
          secao: SecaoCentral.emAndamento,
          inscrito: true,
        ),
        TorneioCardVM(
          tournamentId: 'campeonato-mensal',
          nome: 'Campeonato Mensal',
          modalidade: ModalidadeTorneio.stbl,
          acesso: TipoAcesso.misto,
          participacao: TipoParticipacao.individual,
          dataHora: _base.subtract(const Duration(days: 10)),
          vagasTotais: 96,
          inscritos: 89,
          entrada: TipoEntrada.fichas,
          valorEntrada: 750,
          premiacaoPrincipal: 'Destaque no Hall dos Imortais',
          status: TorneioStatus.encerrado,
          secao: SecaoCentral.encerrados,
          inscrito: true,
        ),
        TorneioCardVM(
          tournamentId: 'copa-rapida',
          nome: 'Copa Relâmpago VIP',
          modalidade: ModalidadeTorneio.aberto,
          acesso: TipoAcesso.vip,
          participacao: TipoParticipacao.individual,
          dataHora: _base.add(const Duration(hours: 20)),
          vagasTotais: 24,
          inscritos: 17,
          entrada: TipoEntrada.fichas,
          valorEntrada: 150,
          premiacaoPrincipal: '800 fichas + Presente Real',
          status: TorneioStatus.inscricoesAbertas,
          tempoRestanteInscricao: const Duration(hours: 18),
          secao: SecaoCentral.inscricoesAbertas,
        ),
      ];

  static TorneioCardVM card(String id) => cards().firstWhere(
        (item) => item.tournamentId == id,
        orElse: () => cards().first,
      );

  static List<PremiacaoVM> premios() => const [
        PremiacaoVM(
          rewardId: 'premio-1',
          posicao: 1,
          tipo: TipoPremio.coroa,
          valorLabel: '1.000 fichas + Coroa Ametista',
          statusEntrega: 'resgatar',
        ),
        PremiacaoVM(
          rewardId: 'premio-2',
          posicao: 2,
          tipo: TipoPremio.fichas,
          valorLabel: '600 fichas + 800 pts',
          statusEntrega: 'entregue',
        ),
        PremiacaoVM(
          rewardId: 'premio-3',
          posicao: 3,
          tipo: TipoPremio.selo,
          valorLabel: 'Selo Pódio Real + 400 fichas',
          statusEntrega: 'pendente',
        ),
      ];

  static TorneioDetalhesVM detalhes(String id) {
    final c = card(id);
    final botoes = switch (c.status) {
      TorneioStatus.inscricoesAbertas => const [BotaoTorneio.inscrever, BotaoTorneio.convidarDupla],
      TorneioStatus.checkinAberto => const [BotaoTorneio.fazerCheckin, BotaoTorneio.entrarSalaEspera],
      TorneioStatus.preparandoMesas =>
        const [BotaoTorneio.entrarSalaEspera, BotaoTorneio.verClassificacao],
      TorneioStatus.emAndamento =>
        const [BotaoTorneio.entrarSalaEspera, BotaoTorneio.verClassificacao],
      TorneioStatus.aguardandoValidacao => const [BotaoTorneio.verClassificacao],
      TorneioStatus.encerrado => const [BotaoTorneio.verResultado, BotaoTorneio.verClassificacao],
      _ => const [BotaoTorneio.verClassificacao],
    };
    return TorneioDetalhesVM(
      card: c,
      descricao:
          'Uma competição oficial do Buraco Master VIP, com partidas auditadas, mesas organizadas automaticamente e premiações exclusivas para os melhores colocados.',
      regras:
          'Modalidade ${c.modalidade.label}; meta de 1.500 pontos; ${c.participacao == TipoParticipacao.dupla ? 'duplas fixas' : 'participação individual'}; decisões oficiais validadas pelo servidor.',
      checkinAbre: c.dataHora.subtract(const Duration(minutes: 30)),
      checkinFecha: c.dataHora.subtract(const Duration(minutes: 5)),
      rodadasPrevistas: 4,
      criteriosClassificacao: 'Vitórias, saldo de pontos, pontos feitos e canastras limpas.',
      criteriosDesempate: '1. Vitórias · 2. Saldo · 3. Pontos feitos · 4. Canastras limpas.',
      regrasAbandono: 'Abandono confirmado encerra a participação e aplica a regra oficial do torneio.',
      regrasDesconexao: 'Prazo de reconexão conforme o contrato oficial; o robô substitui temporariamente.',
      politicaCancelamento: 'Cancelamento sem penalidade até 2 horas antes do início, quando permitido.',
      premiacoes: premios(),
      minhaInscricao: c.inscrito ? StatusParticipante.checkinPendente : null,
      botoes: botoes,
    );
  }

  static InscricaoModalVM inscricao(String id, {MotivoInscricaoRecusada? recusa}) {
    final c = card(id);
    return InscricaoModalVM(
      tournamentId: id,
      nome: c.nome,
      modalidade: c.modalidade,
      dataHora: c.dataHora,
      entrada: c.entrada,
      valorEntrada: c.valorEntrada,
      meuSaldoFichas: 1250,
      premiacaoResumo: c.premiacaoPrincipal,
      participacao: c.participacao,
      amigos: const [
        AmigoConvidavelVM(playerId: 'bia', nome: 'Bia Cartas', online: true),
        AmigoConvidavelVM(playerId: 'marlene', nome: 'Dona Marlene', online: true),
        AmigoConvidavelVM(playerId: 'ze', nome: 'Zé do Buraco', online: false),
        AmigoConvidavelVM(playerId: 'mateus', nome: 'Mateus Canastra', online: true),
      ],
      recusa: recusa,
      mensagemRecusa: recusa == null ? null : 'Não foi possível concluir agora. Confira o motivo e tente novamente.',
    );
  }

  static SalaEsperaVM sala(String id) {
    final c = card(id);
    return SalaEsperaVM(
      tournamentId: id,
      nome: c.nome,
      contagemRegressiva: const Duration(minutes: 8, seconds: 23),
      status: TorneioStatus.preparandoMesas,
      inicio: c.dataHora,
      participantes: c.inscritos,
      checkins: c.inscritos - 4,
      meuStatus: StatusParticipante.convocadoParaMesa,
      statusDupla: c.participacao == TipoParticipacao.dupla ? 'Dupla confirmada com Bia Cartas' : null,
      mensagensOficiais: const [
        'Check-in confirmado. Permaneça nesta sala.',
        'As mesas serão sorteadas automaticamente.',
        'A convocação aparece aqui e não exige atualização manual.',
      ],
      regrasResumo: '${c.modalidade.label} · 1.500 pontos · 4 rodadas previstas',
      meuConfronto: ConfrontoVM(
        confrontoId: 'conf-3',
        rodada: 2,
        mesaLabel: 'Mesa 7 — Ametista',
        horario: c.dataHora,
        duplaA: 'Sônia & Bia',
        duplaB: 'Marlene & Mateus',
        statusPartida: 'aguardando',
        ehMeu: true,
      ),
    );
  }


  static SalaEsperaVM salaComStatus(String id, StatusParticipante status) {
    final base = sala(id);
    final temMesa = status == StatusParticipante.convocadoParaMesa || status == StatusParticipante.emPartida;
    return SalaEsperaVM(
      tournamentId: base.tournamentId,
      nome: base.nome,
      contagemRegressiva: base.contagemRegressiva,
      status: base.status,
      inicio: base.inicio,
      participantes: base.participantes,
      checkins: base.checkins,
      meuStatus: status,
      statusDupla: base.statusDupla,
      mensagensOficiais: base.mensagensOficiais,
      regrasResumo: base.regrasResumo,
      meuConfronto: temMesa ? base.meuConfronto : null,
    );
  }

  static List<ClassificacaoLinhaVM> classificacao() => const [
        ClassificacaoLinhaVM(
          posicao: 1,
          nome: 'Sônia & Bia',
          souEu: true,
          vitorias: 3,
          derrotas: 0,
          pontosFeitos: 4680,
          pontosSofridos: 2860,
          saldo: 1820,
          canastrasLimpas: 7,
          partidasConcluidas: 3,
          status: StatusParticipante.convocadoParaMesa,
        ),
        ClassificacaoLinhaVM(
          posicao: 2,
          nome: 'Marlene & Mateus',
          vitorias: 2,
          derrotas: 1,
          pontosFeitos: 4320,
          pontosSofridos: 3510,
          saldo: 810,
          canastrasLimpas: 5,
          partidasConcluidas: 3,
          status: StatusParticipante.checkinRealizado,
        ),
        ClassificacaoLinhaVM(
          posicao: 3,
          nome: 'Arthur & Clara',
          vitorias: 2,
          derrotas: 1,
          pontosFeitos: 3970,
          pontosSofridos: 3480,
          saldo: 490,
          canastrasLimpas: 4,
          partidasConcluidas: 3,
          status: StatusParticipante.emPartida,
        ),
        ClassificacaoLinhaVM(
          posicao: 4,
          nome: 'Zé & Nanda',
          vitorias: 1,
          derrotas: 2,
          pontosFeitos: 3210,
          pontosSofridos: 3840,
          saldo: -630,
          canastrasLimpas: 3,
          partidasConcluidas: 3,
          status: StatusParticipante.checkinRealizado,
        ),
        ClassificacaoLinhaVM(
          posicao: 5,
          nome: 'Júlio & Tereza',
          vitorias: 1,
          derrotas: 2,
          pontosFeitos: 2890,
          pontosSofridos: 4010,
          saldo: -1120,
          canastrasLimpas: 2,
          partidasConcluidas: 3,
          status: StatusParticipante.desclassificado,
        ),
      ];

  static ClassificacaoTorneioVM classificacaoVM(String id) => ClassificacaoTorneioVM(
        tournamentId: id,
        nome: card(id).nome,
        rodadaAtual: 3,
        classificacao: classificacao(),
        confrontos: [
          const ConfrontoVM(
            confrontoId: 'c1',
            rodada: 1,
            mesaLabel: 'Mesa 1',
            duplaA: 'Sônia & Bia',
            duplaB: 'Zé & Nanda',
            resultado: '1580 × 920',
            statusPartida: 'encerrada',
            ehMeu: true,
          ),
          const ConfrontoVM(
            confrontoId: 'c2',
            rodada: 2,
            mesaLabel: 'Mesa 3',
            duplaA: 'Marlene & Mateus',
            duplaB: 'Arthur & Clara',
            resultado: '1280 × 1520',
            statusPartida: 'encerrada',
          ),
          ConfrontoVM(
            confrontoId: 'c3',
            rodada: 3,
            mesaLabel: 'Mesa 7 — Ametista',
            horario: _base.add(const Duration(minutes: 20)),
            duplaA: 'Sônia & Bia',
            duplaB: 'Marlene & Mateus',
            statusPartida: 'aguardando',
            ehMeu: true,
          ),
          const ConfrontoVM(
            confrontoId: 'c4',
            rodada: 3,
            mesaLabel: 'Mesa 8',
            duplaA: 'Arthur & Clara',
            duplaB: 'Zé & Nanda',
            statusPartida: 'em jogo',
          ),
        ],
        minhaParticipacao: const MinhaParticipacaoVM(
          posicaoAtual: 1,
          proximoConfronto: ConfrontoVM(
            confrontoId: 'c3',
            rodada: 3,
            mesaLabel: 'Mesa 7 — Ametista',
            duplaA: 'Sônia & Bia',
            duplaB: 'Marlene & Mateus',
            statusPartida: 'aguardando',
            ehMeu: true,
          ),
          desempenhoResumo: '3 vitórias · 0 derrotas · saldo +1.820',
          criterios: 'Você lidera em vitórias e saldo de pontos.',
          resultadosAnteriores: ['R1 · 1580 × 920 · vitória', 'R2 · 1540 × 970 · vitória', 'R3 · 1560 × 970 · vitória'],
        ),
      );

  static ResultadoTorneioVM resultado(String id) => ResultadoTorneioVM(
        tournamentId: id,
        nome: card(id).nome,
        campeao: 'Sônia & Bia',
        vice: 'Marlene & Mateus',
        terceiro: 'Arthur & Clara',
        classificacaoFinal: classificacao(),
        totalParticipantes: 64,
        estatisticas: '4 rodadas · 32 mesas · 118 canastras · maior batida: 2.140 pontos',
        minhasPremiacoes: premios(),
        registraHallDosImortais: true,
        minhaPosicaoRanking: 1,
      );

  static List<AdminTorneioResumoVM> admin() => [
        AdminTorneioResumoVM(
          id: 'quarta-vulnerabilidade',
          nome: 'Quarta da Vulnerabilidade',
          edicao: 12,
          data: _base,
          modalidade: ModalidadeTorneio.fechado,
          inscritos: 48,
          vagas: 64,
          status: TorneioStatus.inscricoesAbertas,
          arrecadacaoFichas: 0,
          premiacaoPrevista: '1.000 fichas + Coroa',
          checkins: 0,
          mesasAtivas: 0,
          alertas: const ['16 vagas restantes'],
        ),
        AdminTorneioResumoVM(
          id: 'sexta-master-vip',
          nome: 'Sexta Master VIP',
          edicao: 8,
          data: _base.add(const Duration(days: 2)),
          modalidade: ModalidadeTorneio.stbl,
          inscritos: 44,
          vagas: 48,
          status: TorneioStatus.checkinAberto,
          arrecadacaoFichas: 22000,
          premiacaoPrevista: '4.000 fichas + Título',
          checkins: 39,
          mesasAtivas: 0,
          alertas: const ['5 check-ins pendentes'],
        ),
        AdminTorneioResumoVM(
          id: 'copa-buraco-master',
          nome: 'Copa Buraco Master',
          edicao: 3,
          data: _base.add(const Duration(days: 5)),
          modalidade: ModalidadeTorneio.aberto,
          inscritos: 91,
          vagas: 128,
          status: TorneioStatus.anunciado,
          arrecadacaoFichas: 0,
          premiacaoPrevista: 'Selo Campeão + Ranking',
          checkins: 0,
          mesasAtivas: 0,
        ),
        AdminTorneioResumoVM(
          id: 'domingo-pintando-7',
          nome: 'Domingo Pintando o 7',
          edicao: 20,
          data: _base.subtract(const Duration(hours: 1)),
          modalidade: ModalidadeTorneio.fechado,
          inscritos: 32,
          vagas: 32,
          status: TorneioStatus.emAndamento,
          arrecadacaoFichas: 8000,
          premiacaoPrevista: '2.000 fichas + Moldura',
          checkins: 32,
          mesasAtivas: 8,
          alertas: const ['1 mesa em reconexão'],
        ),
        AdminTorneioResumoVM(
          id: 'campeonato-mensal',
          nome: 'Campeonato Mensal',
          edicao: 6,
          data: _base.subtract(const Duration(days: 10)),
          modalidade: ModalidadeTorneio.stbl,
          inscritos: 89,
          vagas: 96,
          status: TorneioStatus.aguardandoValidacao,
          arrecadacaoFichas: 66750,
          premiacaoPrevista: 'Hall + Coroa + 10.000 fichas',
          checkins: 86,
          mesasAtivas: 0,
          alertas: const ['Resultado aguardando validação'],
        ),
      ];

  static ModeloTorneioForm modelo({String? id}) => ModeloTorneioForm(
        templateId: id ?? 'modelo-quarta',
        nome: 'Quarta da Vulnerabilidade',
        descricao: 'Torneio semanal para quem joga fechado de verdade.',
        modalidade: ModalidadeTorneio.fechado,
        participacao: TipoParticipacao.dupla,
        acesso: TipoAcesso.misto,
        entrada: TipoEntrada.gratuito,
        valorEntrada: 0,
        minJogadores: 16,
        maxJogadores: 64,
        rodadas: 4,
        duracaoEstimada: const Duration(hours: 2, minutes: 30),
        metaPontos: 1500,
        espectadoresPermitidos: true,
        recorrencia: Recorrencia.semanal,
        horario: '20:00',
        fusoHorario: 'America/Sao_Paulo',
        inicioRecorrencia: DateTime(2026, 8, 5),
        fimRecorrencia: DateTime(2026, 12, 31),
        maxEdicoes: 20,
        antecedenciaInscricao: const Duration(days: 7),
        encerramentoInscricao: const Duration(minutes: 30),
        listaEspera: true,
        entradaAutomaticaListaEspera: true,
        permiteDesistencia: true,
        devolveFichas: true,
        prazoCancelamentoSemPenalidade: const Duration(hours: 2),
        checkinAbertura: const Duration(minutes: 30),
        checkinEncerramento: const Duration(minutes: 5),
        tolerancia: const Duration(minutes: 5),
        eliminaPorAusencia: true,
        convocaListaEspera: true,
        premiacoes: premios(),
        criteriosDesempate: const ['Vitórias', 'Saldo de pontos', 'Pontos feitos', 'Canastras limpas'],
        regrasAbandono: 'Abandono confirmado elimina a dupla da edição.',
        regrasDesconexao: 'Reconexão oficial com robô temporário.',
        regrasConduta: 'Respeito obrigatório; denúncias seguem a moderação do app.',
        notificacoes: const {
          'anuncio': true,
          'inscricoes_abertas': true,
          'lembrete_24h': true,
          'checkin': true,
          'mesa_pronta': true,
          'resultado': true,
        },
        ativo: true,
      );
}
