// tournament_model.dart — modelo versionado de torneio e edicao (OS 02 secao 3).
//
// Camada pura: sem Firestore, sem Cloud Functions, sem UI e sem relogio.
//
// DOIS NIVEIS, DE PROPOSITO:
// - [TorneioTemplate] e o MOLDE recorrente ("Sexta Master VIP"). Vive uma vez.
// - [EdicaoTorneio] e a OCORRENCIA datada ("Sexta Master VIP #8, 07/08/2026").
//   E ela que tem status, inscritos, mesas, classificacao e campeao.
//
// Sem essa separacao, configurar um torneio novo obrigaria a duplicar o motor
// inteiro — exatamente o que a OS 02 secao 2 proibe. O que muda entre os cinco
// torneios previstos e DADO no template, nao codigo.
//
// VERSAO DE REGRA: [EdicaoTorneio.regraVersao] congela qual versao do template
// regeu aquela edicao. Alterar o template amanha nao pode reinterpretar a edicao
// de ontem — e a mesma decisao ja tomada em reward_grants.dart para o snapshot
// de `acumulaContador`.
//
// PENDENCIAS: campos que o projeto ainda nao definiu ficam null e sao listados em
// [TorneioTemplate.pendencias]. OS 02 secao 11 e secao 6 sao explicitas: nao
// inventar criterio nao aprovado. Um null declarado e auditavel; um default
// chutado vira regra oficial sem ninguem ter decidido.

import 'tournament_lifecycle.dart';

/// Os cinco torneios previstos na OS 02 secao 2.
///
/// O enum existe para que o codigo referencie o torneio por identificador
/// canonico, nunca por nome exibido — renomear "Copa Buraco Master" na tela nao
/// pode quebrar consulta de historico.
enum TipoTorneio {
  quartaVulnerabilidade('quarta_vulnerabilidade'),
  sextaMasterVip('sexta_master_vip'),
  copaBuracoMaster('copa_buraco_master'),
  domingoPintando7('domingo_pintando_7'),
  campeonatoMensal('campeonato_mensal'),

  /// Torneio festivo de encerramento do ano (OS 02 secao 16). Separado dos cinco
  /// recorrentes porque o acesso e por convite, nao por inscricao aberta.
  encerramentoAnual('encerramento_anual');

  final String wire;
  const TipoTorneio(this.wire);

  static TipoTorneio? porWire(String wire) {
    for (final t in TipoTorneio.values) {
      if (t.wire == wire) return t;
    }
    return null;
  }
}

/// Regra de mesa. Espelha `ModalidadeTorneio` de screens/torneios_models.dart e
/// os valores que mesa.dart ja aceita em `Jogo.modalidade`.
enum ModalidadeMesa {
  aberto('ABERTO'),
  fechado('FECHADO'),
  sbtl('SBTL');

  final String wire;
  const ModalidadeMesa(this.wire);

  static ModalidadeMesa? porWire(String wire) {
    for (final m in ModalidadeMesa.values) {
      if (m.wire == wire) return m;
    }
    return null;
  }
}

/// Individual ou dupla. Governa a formacao de mesas (seating.dart) e a unidade de
/// classificacao (standings.dart).
enum TipoParticipacao {
  individual('individual'),
  dupla('dupla');

  final String wire;
  const TipoParticipacao(this.wire);

  static TipoParticipacao? porWire(String wire) {
    for (final p in TipoParticipacao.values) {
      if (p.wire == wire) return p;
    }
    return null;
  }
}

/// Como as fases se encadeiam (OS 02 secao 8).
///
/// Tres formas apenas, cobrindo o que a OS enumera. Nao ha entrada para formatos
/// que o projeto nao descreveu: acrescentar depois e barato, remover um formato
/// que ja gerou historico nao e.
enum FormatoTorneio {
  /// Todos disputam o mesmo numero de rodadas; classifica por pontuacao.
  pontosCorridos('pontos_corridos'),

  /// Mata-mata puro: quem perde sai.
  eliminatorio('eliminatorio'),

  /// Fase de rodadas classificatoria seguida de eliminatorias.
  misto('misto');

  final String wire;
  const FormatoTorneio(this.wire);

  /// O formato encerra com confronto unico entre dois finalistas.
  bool get temFinal => this != pontosCorridos;

  static FormatoTorneio? porWire(String wire) {
    for (final f in FormatoTorneio.values) {
      if (f.wire == wire) return f;
    }
    return null;
  }
}

/// Ritmo de geracao de edicoes. Espelha `Recorrencia` de torneios_models.dart.
enum Recorrencia {
  unico('unico'),
  semanal('semanal'),
  quinzenal('quinzenal'),
  mensal('mensal'),
  ultimoDiaDoMes('ultimo_dia_do_mes'),
  dataEspecial('data_especial');

  final String wire;
  const Recorrencia(this.wire);

  static Recorrencia? porWire(String wire) {
    for (final r in Recorrencia.values) {
      if (r.wire == wire) return r;
    }
    return null;
  }
}

/// Criterio de desempate, aplicado em ordem (OS 02 secao 11).
///
/// Os quatro primeiros sao os que o projeto ja documenta, em
/// app/lib/screens/torneios_models.dart: "1. Vitorias · 2. Saldo · 3. Pontos
/// feitos · 4. Canastras limpas". Nenhum criterio alem desses foi inventado aqui.
enum CriterioDesempate {
  vitorias('vitorias'),
  saldoPontos('saldo_pontos'),
  pontosFeitos('pontos_feitos'),
  canastrasLimpas('canastras_limpas'),

  /// Ultimo recurso deterministico: menor identificador de participante.
  ///
  /// NAO e criterio esportivo e nao substitui um criterio de projeto — existe
  /// porque uma classificacao precisa ser uma ordem total. Sem ele, dois
  /// participantes empatados em tudo sairiam em ordem imprevisivel a cada
  /// leitura, e "quem avancou" mudaria entre duas aberturas da mesma tela.
  /// Enquanto a administracao nao definir o criterio real, este permanece como
  /// pendencia declarada em [TorneioTemplate.pendencias].
  desempateAdministrativo('desempate_administrativo');

  final String wire;
  const CriterioDesempate(this.wire);

  static CriterioDesempate? porWire(String wire) {
    for (final c in CriterioDesempate.values) {
      if (c.wire == wire) return c;
    }
    return null;
  }
}

/// Ordem de desempate que o projeto ja documenta.
const List<CriterioDesempate> desempatePadrao = [
  CriterioDesempate.vitorias,
  CriterioDesempate.saldoPontos,
  CriterioDesempate.pontosFeitos,
  CriterioDesempate.canastrasLimpas,
  CriterioDesempate.desempateAdministrativo,
];

/// Uma faixa de premiacao do template: "colocacao X recebe o ativo Y".
///
/// Referencia o ativo por `assetId` (chave para assets_registry.dart), nunca pelo
/// nome do PNG — mesma disciplina ja adotada em reward_policies.dart.
class FaixaPremiacao {
  /// Colocacao inicial coberta pela faixa, >= 1.
  final int posicaoInicial;

  /// Colocacao final coberta, >= [posicaoInicial]. Igual a ela em premio de
  /// posicao unica; maior em faixas do tipo "3o ao 8o".
  final int posicaoFinal;

  /// Chave estrangeira para assets_registry.dart. null quando a faixa concede
  /// apenas moeda.
  final String? assetId;

  /// Fichas concedidas na faixa. null quando a faixa nao paga fichas.
  final int? fichas;

  const FaixaPremiacao({
    required this.posicaoInicial,
    required this.posicaoFinal,
    this.assetId,
    this.fichas,
  });

  bool cobre(int colocacao) =>
      colocacao >= posicaoInicial && colocacao <= posicaoFinal;

  factory FaixaPremiacao.fromJson(Map<String, dynamic> json) {
    final inicial = json['posicaoInicial'];
    final fim = json['posicaoFinal'];
    if (inicial is! int || inicial < 1) {
      throw FormatException('faixa de premiacao: posicaoInicial deve ser int >= 1 (recebido: $inicial).');
    }
    if (fim is! int || fim < inicial) {
      throw FormatException('faixa de premiacao: posicaoFinal deve ser int >= posicaoInicial (recebido: $fim).');
    }
    final assetId = json['assetId'];
    if (assetId != null && (assetId is! String || assetId.isEmpty)) {
      throw FormatException('faixa de premiacao: assetId deve ser string nao vazia ou null.');
    }
    final fichas = json['fichas'];
    if (fichas != null && (fichas is! int || fichas < 0)) {
      throw FormatException('faixa de premiacao: fichas deve ser int >= 0 ou null.');
    }
    if (assetId == null && fichas == null) {
      throw FormatException('faixa de premiacao $inicial-$fim: precisa conceder assetId ou fichas.');
    }
    return FaixaPremiacao(
      posicaoInicial: inicial,
      posicaoFinal: fim,
      assetId: assetId as String?,
      fichas: fichas as int?,
    );
  }

  Map<String, dynamic> toJson() => {
        'posicaoInicial': posicaoInicial,
        'posicaoFinal': posicaoFinal,
        'assetId': assetId,
        'fichas': fichas,
      };
}

/// Molde recorrente de um torneio. Imutavel: alterar configuracao produz uma
/// [versao] nova, nao uma mutacao no lugar.
class TorneioTemplate {
  /// Identificador canonico e imutavel do torneio.
  final String tournamentId;

  final TipoTorneio tipo;
  final String nome;

  /// Versao da regra. Toda edicao guarda a versao sob a qual nasceu.
  final int versao;

  final ModalidadeMesa modalidade;
  final TipoParticipacao participacao;
  final FormatoTorneio formato;
  final Recorrencia recorrencia;

  /// Numero de fases previstas. null enquanto o projeto nao definir.
  final int? numeroFases;

  /// Limite de participantes. null enquanto o projeto nao definir.
  final int? limiteParticipantes;

  /// Minimo para a edicao acontecer. null enquanto o projeto nao definir.
  final int? minimoParticipantes;

  /// Meta de pontos da partida, repassada ao Motor de Partidas.
  /// null enquanto o projeto nao definir.
  final int? metaPontos;

  /// Quanto antes do inicio as inscricoes abrem. null enquanto nao definido.
  final Duration? antecedenciaInscricao;

  /// Quanto antes do inicio as inscricoes fecham. null enquanto nao definido.
  final Duration? encerramentoInscricao;

  /// Criterios de elegibilidade exigidos. Ver eligibility.dart. Lista vazia
  /// significa torneio aberto a todos, e e diferente de "ainda nao definido" —
  /// este ultimo aparece em [pendencias].
  final List<String> criteriosElegibilidade;

  /// Ordem de desempate aplicada pela classificacao.
  final List<CriterioDesempate> criteriosDesempate;

  /// Faixas de premiacao. Vazia enquanto o projeto nao definir.
  final List<FaixaPremiacao> premiacao;

  /// Arte de capa, por referencia ao assets_registry.dart.
  final String? capaAssetId;

  /// Campos que o projeto ainda NAO definiu, em texto legivel. OS 02 secao 11 e
  /// secao 27 exigem pendencia declarada, nao default silencioso.
  final List<String> pendencias;

  final bool ativo;

  const TorneioTemplate({
    required this.tournamentId,
    required this.tipo,
    required this.nome,
    required this.versao,
    required this.modalidade,
    required this.participacao,
    required this.formato,
    required this.recorrencia,
    this.numeroFases,
    this.limiteParticipantes,
    this.minimoParticipantes,
    this.metaPontos,
    this.antecedenciaInscricao,
    this.encerramentoInscricao,
    this.criteriosElegibilidade = const [],
    this.criteriosDesempate = desempatePadrao,
    this.premiacao = const [],
    this.capaAssetId,
    this.pendencias = const [],
    this.ativo = true,
  });

  /// O template tem tudo que o motor precisa para rodar uma edicao de verdade.
  ///
  /// Consultado antes de abrir inscricoes: deixar uma edicao andar com limite de
  /// vagas indefinido produziria uma lotacao que ninguem decidiu.
  bool get configuracaoCompleta =>
      pendencias.isEmpty &&
      numeroFases != null &&
      limiteParticipantes != null &&
      minimoParticipantes != null &&
      metaPontos != null &&
      antecedenciaInscricao != null &&
      encerramentoInscricao != null &&
      premiacao.isNotEmpty;

  /// Faixa que cobre a colocacao, ou null quando a colocacao nao premia.
  FaixaPremiacao? faixaPara(int colocacao) {
    for (final faixa in premiacao) {
      if (faixa.cobre(colocacao)) return faixa;
    }
    return null;
  }

  factory TorneioTemplate.fromJson(Map<String, dynamic> json) {
    String texto(String campo) {
      final v = json[campo];
      if (v is! String || v.isEmpty) {
        throw FormatException('template: $campo deve ser string nao vazia (recebido: $v).');
      }
      return v;
    }

    int? inteiroOpcional(String campo, {int minimo = 1}) {
      final v = json[campo];
      if (v == null) return null;
      if (v is! int || v < minimo) {
        throw FormatException('template: $campo deve ser int >= $minimo ou null (recebido: $v).');
      }
      return v;
    }

    /// Duracao em ISO-8601 restrito, aceitando dias, horas e minutos.
    Duration? duracaoOpcional(String campo) {
      final v = json[campo];
      if (v == null) return null;
      if (v is! String) {
        throw FormatException('template: $campo deve ser string ISO-8601 ou null (recebido: $v).');
      }
      final m = RegExp(r'^P(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?)?$').firstMatch(v);
      if (m == null || v == 'P' || v == 'PT') {
        throw FormatException('template: $campo "$v" fora do formato PnDTnHnM.');
      }
      final d = Duration(
        days: int.parse(m.group(1) ?? '0'),
        hours: int.parse(m.group(2) ?? '0'),
        minutes: int.parse(m.group(3) ?? '0'),
      );
      if (d <= Duration.zero) {
        throw FormatException('template: $campo deve ser positiva (recebido: $v).');
      }
      return d;
    }

    final tournamentId = texto('tournamentId');
    final tipo = TipoTorneio.porWire(texto('tipo'));
    if (tipo == null) {
      throw FormatException('$tournamentId: tipo desconhecido "${json['tipo']}".');
    }
    final modalidade = ModalidadeMesa.porWire(texto('modalidade'));
    if (modalidade == null) {
      throw FormatException('$tournamentId: modalidade desconhecida "${json['modalidade']}".');
    }
    final participacao = TipoParticipacao.porWire(texto('participacao'));
    if (participacao == null) {
      throw FormatException('$tournamentId: participacao desconhecida "${json['participacao']}".');
    }
    final formato = FormatoTorneio.porWire(texto('formato'));
    if (formato == null) {
      throw FormatException('$tournamentId: formato desconhecido "${json['formato']}".');
    }
    final recorrencia = Recorrencia.porWire(texto('recorrencia'));
    if (recorrencia == null) {
      throw FormatException('$tournamentId: recorrencia desconhecida "${json['recorrencia']}".');
    }

    final versao = json['versao'];
    if (versao is! int || versao < 1) {
      throw FormatException('$tournamentId: versao deve ser int >= 1 (recebido: $versao).');
    }

    final limite = inteiroOpcional('limiteParticipantes', minimo: 2);
    final minimo = inteiroOpcional('minimoParticipantes', minimo: 2);
    if (limite != null && minimo != null && minimo > limite) {
      throw FormatException('$tournamentId: minimoParticipantes ($minimo) maior que limiteParticipantes ($limite).');
    }

    final desempateBruto = json['criteriosDesempate'];
    final List<CriterioDesempate> desempate;
    if (desempateBruto == null) {
      desempate = desempatePadrao;
    } else {
      if (desempateBruto is! List) {
        throw FormatException('$tournamentId: criteriosDesempate deve ser lista ou null.');
      }
      desempate = desempateBruto.map((e) {
        final c = CriterioDesempate.porWire(e as String);
        if (c == null) {
          throw FormatException('$tournamentId: criterio de desempate desconhecido "$e".');
        }
        return c;
      }).toList(growable: false);
      final vistos = <CriterioDesempate>{};
      for (final c in desempate) {
        if (!vistos.add(c)) {
          throw FormatException('$tournamentId: criterio de desempate repetido "${c.wire}".');
        }
      }
    }

    final premiacaoBruta = (json['premiacao'] as List?) ?? const [];
    final premiacao = premiacaoBruta
        .map((e) => FaixaPremiacao.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
    // Faixas sobrepostas dariam dois premios para a mesma colocacao e a segunda
    // concessao cairia como duplicidade em tempo de execucao — melhor recusar o
    // seed do que descobrir na noite do torneio.
    for (var i = 0; i < premiacao.length; i++) {
      for (var j = i + 1; j < premiacao.length; j++) {
        final a = premiacao[i];
        final b = premiacao[j];
        if (a.posicaoInicial <= b.posicaoFinal && b.posicaoInicial <= a.posicaoFinal) {
          throw FormatException(
              '$tournamentId: faixas de premiacao sobrepostas (${a.posicaoInicial}-${a.posicaoFinal} e ${b.posicaoInicial}-${b.posicaoFinal}).');
        }
      }
    }

    return TorneioTemplate(
      tournamentId: tournamentId,
      tipo: tipo,
      nome: texto('nome'),
      versao: versao,
      modalidade: modalidade,
      participacao: participacao,
      formato: formato,
      recorrencia: recorrencia,
      numeroFases: inteiroOpcional('numeroFases'),
      limiteParticipantes: limite,
      minimoParticipantes: minimo,
      metaPontos: inteiroOpcional('metaPontos', minimo: 1),
      antecedenciaInscricao: duracaoOpcional('antecedenciaInscricao'),
      encerramentoInscricao: duracaoOpcional('encerramentoInscricao'),
      criteriosElegibilidade: ((json['criteriosElegibilidade'] as List?) ?? const [])
          .map((e) => e as String)
          .toList(growable: false),
      criteriosDesempate: desempate,
      premiacao: premiacao,
      capaAssetId: json['capaAssetId'] as String?,
      pendencias: ((json['pendencias'] as List?) ?? const [])
          .map((e) => e as String)
          .toList(growable: false),
      ativo: (json['ativo'] as bool?) ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'tournamentId': tournamentId,
        'tipo': tipo.wire,
        'nome': nome,
        'versao': versao,
        'modalidade': modalidade.wire,
        'participacao': participacao.wire,
        'formato': formato.wire,
        'recorrencia': recorrencia.wire,
        'numeroFases': numeroFases,
        'limiteParticipantes': limiteParticipantes,
        'minimoParticipantes': minimoParticipantes,
        'metaPontos': metaPontos,
        'antecedenciaInscricao': _duracaoWire(antecedenciaInscricao),
        'encerramentoInscricao': _duracaoWire(encerramentoInscricao),
        'criteriosElegibilidade': criteriosElegibilidade,
        'criteriosDesempate': criteriosDesempate.map((c) => c.wire).toList(),
        'premiacao': premiacao.map((f) => f.toJson()).toList(),
        'capaAssetId': capaAssetId,
        'pendencias': pendencias,
        'ativo': ativo,
      };

  static String? _duracaoWire(Duration? d) {
    if (d == null) return null;
    final dias = d.inDays;
    final horas = d.inHours % 24;
    final minutos = d.inMinutes % 60;
    final buffer = StringBuffer('P');
    if (dias > 0) buffer.write('${dias}D');
    if (horas > 0 || minutos > 0) {
      buffer.write('T');
      if (horas > 0) buffer.write('${horas}H');
      if (minutos > 0) buffer.write('${minutos}M');
    }
    return buffer.toString();
  }

  @override
  String toString() => 'TorneioTemplate($tournamentId v$versao)';
}

/// Ocorrencia datada de um [TorneioTemplate].
///
/// Imutavel: o motor devolve uma edicao nova a cada mudanca de estado, e a camada
/// de persistencia grava. Assim nenhuma funcao muda o estado de outra por
/// referencia compartilhada.
class EdicaoTorneio {
  final String tournamentId;

  /// Unico DENTRO do torneio, nao globalmente — mesma premissa da chave de
  /// idempotencia em reward_grants.dart.
  final String editionId;

  /// Numero sequencial exibido ("edicao 12"), >= 1.
  final int numeroEdicao;

  /// Temporada a que a edicao pertence, no formato do calendario do projeto
  /// (ex.: "2026"). Usada pelo registro anual (annual_closing.dart).
  final String temporada;

  final EdicaoStatus status;

  /// Status guardado no momento da suspensao, para a retomada saber o destino.
  /// null fora de [EdicaoStatus.suspenso].
  final EdicaoStatus? statusAnterior;

  /// Inicio previsto da disputa, sempre em UTC.
  final DateTime inicioPrevisto;

  /// Abertura das inscricoes, em UTC. null enquanto nao calculada.
  final DateTime? inscricoesAbremEm;

  /// Encerramento das inscricoes, em UTC. null enquanto nao calculado.
  final DateTime? inscricoesFechamEm;

  /// Versao do template sob a qual esta edicao nasceu. Congelada.
  final int regraVersao;

  final DateTime criadoEm;
  final DateTime atualizadoEm;

  EdicaoTorneio({
    required this.tournamentId,
    required this.editionId,
    required this.numeroEdicao,
    required this.temporada,
    required this.status,
    this.statusAnterior,
    required DateTime inicioPrevisto,
    DateTime? inscricoesAbremEm,
    DateTime? inscricoesFechamEm,
    required this.regraVersao,
    required DateTime criadoEm,
    required DateTime atualizadoEm,
  })  : inicioPrevisto = inicioPrevisto.toUtc(),
        inscricoesAbremEm = inscricoesAbremEm?.toUtc(),
        inscricoesFechamEm = inscricoesFechamEm?.toUtc(),
        criadoEm = criadoEm.toUtc(),
        atualizadoEm = atualizadoEm.toUtc() {
    if (numeroEdicao < 1) {
      throw ArgumentError.value(numeroEdicao, 'numeroEdicao', 'deve ser >= 1');
    }
    if (editionId.isEmpty) {
      throw ArgumentError.value(editionId, 'editionId', 'nao pode ser vazio');
    }
    if (temporada.isEmpty) {
      throw ArgumentError.value(temporada, 'temporada', 'nao pode ser vazia');
    }
    if (regraVersao < 1) {
      throw ArgumentError.value(regraVersao, 'regraVersao', 'deve ser >= 1');
    }
    if (status == EdicaoStatus.suspenso && statusAnterior == null) {
      throw ArgumentError.value(statusAnterior, 'statusAnterior',
          'e obrigatorio quando status e suspenso');
    }
    if (status != EdicaoStatus.suspenso && statusAnterior != null) {
      throw ArgumentError.value(statusAnterior, 'statusAnterior',
          'so vale quando status e suspenso');
    }
    final abre = this.inscricoesAbremEm;
    final fecha = this.inscricoesFechamEm;
    if (abre != null && fecha != null && !fecha.isAfter(abre)) {
      throw ArgumentError.value(inscricoesFechamEm, 'inscricoesFechamEm',
          'deve ser posterior a inscricoesAbremEm');
    }
  }

  /// Chave global da edicao. Todo registro derivado (inscricao, mesa, resultado,
  /// premiacao) carrega este par.
  String get chave => '$tournamentId|$editionId';

  /// Aplica uma transicao ja aprovada por tournament_lifecycle.dart.
  ///
  /// Nao reavalia a permissao: quem chama e responsavel por passar por
  /// [avaliarTransicao] antes. Separar decisao de aplicacao mantem a decisao
  /// testavel sem construir uma edicao inteira.
  EdicaoTorneio comStatus(
    EdicaoStatus novo, {
    required DateTime em,
    EdicaoStatus? statusAnterior,
  }) =>
      EdicaoTorneio(
        tournamentId: tournamentId,
        editionId: editionId,
        numeroEdicao: numeroEdicao,
        temporada: temporada,
        status: novo,
        statusAnterior: novo == EdicaoStatus.suspenso ? (statusAnterior ?? status) : null,
        inicioPrevisto: inicioPrevisto,
        inscricoesAbremEm: inscricoesAbremEm,
        inscricoesFechamEm: inscricoesFechamEm,
        regraVersao: regraVersao,
        criadoEm: criadoEm,
        atualizadoEm: em,
      );

  /// Calcula a janela de inscricao a partir do template.
  ///
  /// Devolve a propria edicao inalterada quando o template ainda nao definiu as
  /// duracoes — nao inventa janela (OS 02 secao 3).
  EdicaoTorneio comJanelaDe(TorneioTemplate template, {required DateTime em}) {
    final antes = template.antecedenciaInscricao;
    final fecha = template.encerramentoInscricao;
    if (antes == null || fecha == null) return this;
    return EdicaoTorneio(
      tournamentId: tournamentId,
      editionId: editionId,
      numeroEdicao: numeroEdicao,
      temporada: temporada,
      status: status,
      statusAnterior: statusAnterior,
      inicioPrevisto: inicioPrevisto,
      inscricoesAbremEm: inicioPrevisto.subtract(antes),
      inscricoesFechamEm: inicioPrevisto.subtract(fecha),
      regraVersao: regraVersao,
      criadoEm: criadoEm,
      atualizadoEm: em,
    );
  }

  /// A janela de inscricao contem o instante informado.
  ///
  /// Fechada no inicio e aberta no fim, `[abre, fecha)` — mesma convencao de
  /// `RecompensaConcessao.ativaEm`, para que as duas janelas do sistema nao
  /// tenham bordas diferentes.
  bool janelaInscricaoAbertaEm(DateTime instante) {
    final abre = inscricoesAbremEm;
    final fecha = inscricoesFechamEm;
    if (abre == null || fecha == null) return false;
    final momento = instante.toUtc();
    return !momento.isBefore(abre) && momento.isBefore(fecha);
  }

  factory EdicaoTorneio.fromMap(Map<String, dynamic> json) {
    String texto(String campo) {
      final v = json[campo];
      if (v is! String || v.isEmpty) {
        throw FormatException('edicao: $campo deve ser string nao vazia (recebido: $v).');
      }
      return v;
    }

    DateTime? instante(String campo, {required bool obrigatorio}) {
      final v = json[campo];
      if (v == null) {
        if (obrigatorio) {
          throw FormatException('edicao: $campo e obrigatorio.');
        }
        return null;
      }
      if (v is! String || v.isEmpty) {
        throw FormatException('edicao: $campo deve ser string ISO-8601 em UTC (recebido: $v).');
      }
      final parsed = DateTime.tryParse(v);
      if (parsed == null) {
        throw FormatException('edicao: $campo nao e ISO-8601 valido (recebido: $v).');
      }
      // Mesmo criterio de reward_grants.dart: data sem fuso seria lida com o
      // relogio de quem abriu a tela, e a mesma edicao abriria inscricao em
      // horas diferentes em cada aparelho.
      if (!parsed.isUtc) {
        throw FormatException('edicao: $campo deve estar em UTC (sufixo Z) (recebido: $v).');
      }
      return parsed;
    }

    final status = EdicaoStatus.porWire(texto('status'));
    if (status == null) {
      throw FormatException('edicao: status desconhecido "${json['status']}".');
    }
    final anteriorWire = json['statusAnterior'] as String?;
    EdicaoStatus? anterior;
    if (anteriorWire != null) {
      anterior = EdicaoStatus.porWire(anteriorWire);
      if (anterior == null) {
        throw FormatException('edicao: statusAnterior desconhecido "$anteriorWire".');
      }
    }

    final numero = json['numeroEdicao'];
    if (numero is! int) {
      throw FormatException('edicao: numeroEdicao deve ser int (recebido: $numero).');
    }
    final regraVersao = json['regraVersao'];
    if (regraVersao is! int) {
      throw FormatException('edicao: regraVersao deve ser int (recebido: $regraVersao).');
    }

    try {
      return EdicaoTorneio(
        tournamentId: texto('tournamentId'),
        editionId: texto('editionId'),
        numeroEdicao: numero,
        temporada: texto('temporada'),
        status: status,
        statusAnterior: anterior,
        inicioPrevisto: instante('inicioPrevisto', obrigatorio: true)!,
        inscricoesAbremEm: instante('inscricoesAbremEm', obrigatorio: false),
        inscricoesFechamEm: instante('inscricoesFechamEm', obrigatorio: false),
        regraVersao: regraVersao,
        criadoEm: instante('criadoEm', obrigatorio: true)!,
        atualizadoEm: instante('atualizadoEm', obrigatorio: true)!,
      );
    } on ArgumentError catch (e) {
      // Invariante de construtor violada por dado gravado: vira erro de formato,
      // nao estouro de argumento, porque a origem e o registro e nao o chamador.
      throw FormatException('edicao: registro invalido ($e).');
    }
  }

  Map<String, dynamic> toJson() => {
        'tournamentId': tournamentId,
        'editionId': editionId,
        'numeroEdicao': numeroEdicao,
        'temporada': temporada,
        'status': status.wire,
        'statusAnterior': statusAnterior?.wire,
        'inicioPrevisto': inicioPrevisto.toIso8601String(),
        'inscricoesAbremEm': inscricoesAbremEm?.toIso8601String(),
        'inscricoesFechamEm': inscricoesFechamEm?.toIso8601String(),
        'regraVersao': regraVersao,
        'criadoEm': criadoEm.toIso8601String(),
        'atualizadoEm': atualizadoEm.toIso8601String(),
      };

  @override
  String toString() => 'EdicaoTorneio($chave #$numeroEdicao ${status.wire})';
}
