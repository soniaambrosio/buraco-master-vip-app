// eligibility.dart — camada de criterios de elegibilidade (OS 02 secao 6).
//
// Camada pura: sem Firestore, sem UI e sem relogio implicito. Todo insumo entra
// por parametro.
//
// POR QUE UMA CAMADA: a OS 02 secao 6 pede que os criterios sejam validados
// "sem espalhar regras pela UI". Um `if (jogador.nivel >= 5)` dentro de um widget
// e invisivel para o backend, nao aparece em teste e diverge da regra do servidor
// no dia em que alguem editar so um dos dois lugares. Aqui o criterio e DADO:
// mora no template (`criteriosElegibilidade`), e a mesma string e avaliada no
// cliente e no servidor com este mesmo codigo.
//
// ESCOPO: os oito tipos implementados sao exatamente os que a OS 02 secao 6
// enumera — nivel, classificacao, convite, assinatura, conquista, participacao
// anterior, campeao e temporada. Nenhum criterio alem desses foi inventado.
// Acrescentar um novo tipo e uma entrada em [TipoCriterio] mais um `case`; nada
// no motor de inscricao muda.

import 'tournament_model.dart';

/// Os tipos de criterio previstos pelo projeto.
enum TipoCriterio {
  /// Nivel minimo do jogador. Argumento: inteiro.
  nivelMinimo('nivel_minimo'),

  /// Posicao maxima no ranking (1 e a melhor). Argumento: inteiro.
  classificacaoMaxima('classificacao_maxima'),

  /// Exige convite ativo para este torneio. Sem argumento.
  convite('convite'),

  /// Exige assinatura VIP ativa. Sem argumento.
  assinatura('assinatura'),

  /// Exige uma conquista especifica. Argumento: id da conquista.
  conquista('conquista'),

  /// Exige ter participado de um torneio. Argumento: tournamentId.
  participacaoAnterior('participacao_anterior'),

  /// Exige ter sido campeao de um torneio. Argumento: tournamentId.
  campeao('campeao'),

  /// Exige ter atividade registrada na temporada. Argumento: temporada.
  temporada('temporada');

  final String wire;
  const TipoCriterio(this.wire);

  /// O criterio precisa de argumento apos os dois-pontos.
  bool get exigeArgumento => this != convite && this != assinatura;

  /// O argumento e numerico.
  bool get argumentoNumerico =>
      this == nivelMinimo || this == classificacaoMaxima;

  static TipoCriterio? porWire(String wire) {
    for (final t in TipoCriterio.values) {
      if (t.wire == wire) return t;
    }
    return null;
  }
}

/// Um criterio ja interpretado.
///
/// Formato de origem: `tipo` ou `tipo:argumento` (ex.: `assinatura`,
/// `nivel_minimo:5`, `campeao_de` nao existe — e `campeao:quarta_vulnerabilidade`).
class CriterioElegibilidade {
  final TipoCriterio tipo;

  /// null nos criterios sem argumento.
  final String? argumento;

  const CriterioElegibilidade(this.tipo, [this.argumento]);

  /// Valor numerico do argumento. Só faz sentido em criterios numericos, e o
  /// parse ja foi validado em [CriterioElegibilidade.parse].
  int get valorNumerico => int.parse(argumento!);

  /// Interpreta a forma textual usada no template e no seed.
  ///
  /// Recusa entrada malformada com [FormatException] em vez de ignorar: um
  /// criterio que o sistema nao entendeu e silenciosamente descarta vira torneio
  /// aberto a todos sem ninguem ter decidido isso.
  factory CriterioElegibilidade.parse(String origem) {
    final texto = origem.trim();
    if (texto.isEmpty) {
      throw const FormatException('criterio de elegibilidade vazio.');
    }
    final corte = texto.indexOf(':');
    final nome = corte == -1 ? texto : texto.substring(0, corte);
    final arg = corte == -1 ? null : texto.substring(corte + 1).trim();

    final tipo = TipoCriterio.porWire(nome);
    if (tipo == null) {
      throw FormatException('criterio de elegibilidade desconhecido "$nome".');
    }
    if (tipo.exigeArgumento) {
      if (arg == null || arg.isEmpty) {
        throw FormatException('criterio "$nome" exige argumento (use "$nome:valor").');
      }
      if (tipo.argumentoNumerico) {
        final n = int.tryParse(arg);
        if (n == null || n < 1) {
          throw FormatException('criterio "$nome" exige argumento inteiro >= 1 (recebido: "$arg").');
        }
      }
    } else if (arg != null) {
      throw FormatException('criterio "$nome" nao aceita argumento (recebido: "$arg").');
    }
    return CriterioElegibilidade(tipo, arg);
  }

  String get wire => argumento == null ? tipo.wire : '${tipo.wire}:$argumento';

  @override
  bool operator ==(Object other) =>
      other is CriterioElegibilidade &&
      other.tipo == tipo &&
      other.argumento == argumento;

  @override
  int get hashCode => Object.hash(tipo, argumento);

  @override
  String toString() => 'CriterioElegibilidade($wire)';
}

/// Retrato dos fatos do jogador que os criterios consultam.
///
/// DTO puro montado pela camada de dados. O motor nunca sai buscando: se um fato
/// nao esta aqui, o criterio correspondente nao pode ser avaliado — e isso vira
/// recusa explicita, nao um "true" otimista.
class PerfilElegibilidade {
  final String userId;

  /// Nivel atual. null quando o dado ainda nao foi carregado.
  final int? nivel;

  /// Posicao no ranking (1 e a melhor). null quando o jogador nao esta ranqueado.
  final int? posicaoRanking;

  /// Assinatura VIP ativa no instante da avaliacao.
  final bool assinaturaAtiva;

  /// Torneios para os quais o jogador tem convite ativo.
  final Set<String> convitesAtivos;

  /// Conquistas ja obtidas, por id.
  final Set<String> conquistas;

  /// Torneios dos quais ja participou, por tournamentId.
  final Set<String> participacoes;

  /// Torneios dos quais ja foi campeao, por tournamentId.
  final Set<String> titulos;

  /// Temporadas em que o jogador tem atividade registrada.
  final Set<String> temporadasAtivas;

  /// O perfil esta suspenso por moderacao. Bloqueia inscricao independentemente
  /// dos criterios do torneio.
  final bool suspenso;

  const PerfilElegibilidade({
    required this.userId,
    this.nivel,
    this.posicaoRanking,
    this.assinaturaAtiva = false,
    this.convitesAtivos = const {},
    this.conquistas = const {},
    this.participacoes = const {},
    this.titulos = const {},
    this.temporadasAtivas = const {},
    this.suspenso = false,
  });
}

/// Por que o jogador nao atendeu a um criterio.
enum RecusaElegibilidade {
  nivelInsuficiente('nivel_insuficiente'),
  classificacaoInsuficiente('classificacao_insuficiente'),
  semConvite('sem_convite'),
  semAssinatura('sem_assinatura'),
  semConquista('sem_conquista'),
  semParticipacaoAnterior('sem_participacao_anterior'),
  naoFoiCampeao('nao_foi_campeao'),
  foraDaTemporada('fora_da_temporada'),

  /// O fato necessario nao veio no [PerfilElegibilidade]. Recusa deliberada: um
  /// dado ausente nao pode ser lido como criterio atendido.
  dadoIndisponivel('dado_indisponivel'),

  /// Perfil suspenso por moderacao.
  perfilSuspenso('perfil_suspenso');

  final String wire;
  const RecusaElegibilidade(this.wire);
}

/// Falha de um criterio especifico, para a UI conseguir dizer o que faltou.
class FalhaElegibilidade {
  final CriterioElegibilidade criterio;
  final RecusaElegibilidade recusa;

  const FalhaElegibilidade(this.criterio, this.recusa);

  @override
  bool operator ==(Object other) =>
      other is FalhaElegibilidade &&
      other.criterio == criterio &&
      other.recusa == recusa;

  @override
  int get hashCode => Object.hash(criterio, recusa);

  @override
  String toString() => 'FalhaElegibilidade(${criterio.wire} -> ${recusa.wire})';
}

/// Veredito de [avaliarElegibilidade].
class AvaliacaoElegibilidade {
  /// Todas as falhas encontradas, na ordem dos criterios do template.
  ///
  /// A avaliacao NAO para na primeira falha: a tela precisa poder listar tudo o
  /// que falta de uma vez, senao o jogador descobre um requisito por tentativa.
  final List<FalhaElegibilidade> falhas;

  const AvaliacaoElegibilidade(this.falhas);

  const AvaliacaoElegibilidade.elegivel() : falhas = const [];

  bool get elegivel => falhas.isEmpty;

  /// Primeira falha, para quem so precisa de um motivo (ex.: log do servidor).
  FalhaElegibilidade? get principal => falhas.isEmpty ? null : falhas.first;

  @override
  String toString() => elegivel
      ? 'AvaliacaoElegibilidade.elegivel'
      : 'AvaliacaoElegibilidade(${falhas.map((f) => f.criterio.wire).join(", ")})';
}

/// Avalia um unico criterio contra o perfil.
///
/// Devolve null quando o criterio foi atendido.
RecusaElegibilidade? avaliarCriterio({
  required CriterioElegibilidade criterio,
  required PerfilElegibilidade perfil,
  required String tournamentId,
}) {
  switch (criterio.tipo) {
    case TipoCriterio.nivelMinimo:
      final nivel = perfil.nivel;
      if (nivel == null) return RecusaElegibilidade.dadoIndisponivel;
      return nivel >= criterio.valorNumerico
          ? null
          : RecusaElegibilidade.nivelInsuficiente;

    case TipoCriterio.classificacaoMaxima:
      final posicao = perfil.posicaoRanking;
      // Jogador sem ranking nao "passa por omissao": ele simplesmente nao esta
      // entre os N primeiros exigidos.
      if (posicao == null) return RecusaElegibilidade.classificacaoInsuficiente;
      return posicao <= criterio.valorNumerico
          ? null
          : RecusaElegibilidade.classificacaoInsuficiente;

    case TipoCriterio.convite:
      // O convite e sempre PARA este torneio: um convite do encerramento anual
      // nao habilita a Sexta Master VIP.
      return perfil.convitesAtivos.contains(tournamentId)
          ? null
          : RecusaElegibilidade.semConvite;

    case TipoCriterio.assinatura:
      return perfil.assinaturaAtiva ? null : RecusaElegibilidade.semAssinatura;

    case TipoCriterio.conquista:
      return perfil.conquistas.contains(criterio.argumento)
          ? null
          : RecusaElegibilidade.semConquista;

    case TipoCriterio.participacaoAnterior:
      return perfil.participacoes.contains(criterio.argumento)
          ? null
          : RecusaElegibilidade.semParticipacaoAnterior;

    case TipoCriterio.campeao:
      return perfil.titulos.contains(criterio.argumento)
          ? null
          : RecusaElegibilidade.naoFoiCampeao;

    case TipoCriterio.temporada:
      return perfil.temporadasAtivas.contains(criterio.argumento)
          ? null
          : RecusaElegibilidade.foraDaTemporada;
  }
}

/// Avalia todos os criterios do torneio contra o perfil.
///
/// Funcao pura. Torneio sem criterio nenhum e aberto a todos — e isso e
/// diferente de "criterios ainda nao definidos", caso em que o template carrega a
/// pendencia e nao deveria ter chegado a abrir inscricoes.
AvaliacaoElegibilidade avaliarElegibilidade({
  required List<CriterioElegibilidade> criterios,
  required PerfilElegibilidade perfil,
  required String tournamentId,
}) {
  // Suspensao de moderacao vem antes de tudo: nao interessa quantos criterios do
  // torneio o jogador atende se o perfil esta bloqueado.
  if (perfil.suspenso) {
    return const AvaliacaoElegibilidade([
      FalhaElegibilidade(
        CriterioElegibilidade(TipoCriterio.assinatura),
        RecusaElegibilidade.perfilSuspenso,
      ),
    ]);
  }

  final falhas = <FalhaElegibilidade>[];
  for (final criterio in criterios) {
    final recusa = avaliarCriterio(
      criterio: criterio,
      perfil: perfil,
      tournamentId: tournamentId,
    );
    if (recusa != null) falhas.add(FalhaElegibilidade(criterio, recusa));
  }
  return falhas.isEmpty
      ? const AvaliacaoElegibilidade.elegivel()
      : AvaliacaoElegibilidade(falhas);
}

/// Interpreta os criterios declarados no template.
///
/// Extensao em vez de metodo no proprio [TorneioTemplate] para manter o modelo
/// sem dependencia deste arquivo: quem so precisa serializar um template nao
/// precisa arrastar o avaliador junto.
extension CriteriosDoTemplate on TorneioTemplate {
  List<CriterioElegibilidade> get criteriosInterpretados => criteriosElegibilidade
      .map(CriterioElegibilidade.parse)
      .toList(growable: false);

  /// Avalia este template contra um perfil.
  AvaliacaoElegibilidade avaliar(PerfilElegibilidade perfil) =>
      avaliarElegibilidade(
        criterios: criteriosInterpretados,
        perfil: perfil,
        tournamentId: tournamentId,
      );
}
