// tournament_model.dart — modelo versionado de torneio e edicao (OS 02 secao 3).
//
// Camada pura: sem Firestore, sem Cloud Functions, sem UI e sem relogio.
//
// FONTE DE VERDADE: app/data/torneios/tournamentTemplates.seed.json, aprovado
// fora do repositorio. Este arquivo MODELA aquele seed; ele nao define numero
// nenhum. Nenhuma vaga, nenhum valor de entrada, nenhum premio e nenhuma
// duracao aparece como constante aqui — se um numero de regra vier parar neste
// arquivo, ele deixou de ser editavel no painel e virou codigo, que e
// exatamente o que a primeira regra do seed proibe.
//
// DOIS NIVEIS, DE PROPOSITO:
// - [TorneioTemplate] e o MOLDE recorrente ("Sexta Master VIP"). Vive uma vez.
// - [EdicaoTorneio] e a OCORRENCIA datada ("Sexta Master VIP #8, 07/08/2026").
//   E ela que tem status, inscritos, mesas, classificacao e campeao.
//
// O QUE E DO TEMPLATE E O QUE E DA EDICAO: o seed aprovado deixa a modalidade
// como POLITICA — "alterna", "rodizio", "definidaMensalmente",
// "definidaPelaAdmin" — e nao como valor fixo. Numero de fases e meta de pontos
// tambem nao aparecem nele. Isso nao e lacuna: sao decisoes de EDICAO, tomadas
// quando a edicao e criada. Por isso [TorneioTemplate] guarda a politica e
// [EdicaoTorneio] guarda o valor resolvido.
//
// VERSAO DE REGRA: [EdicaoTorneio.regraVersao] congela qual versao do template
// regeu aquela edicao. Alterar o template amanha nao pode reinterpretar a edicao
// de ontem — a mesma decisao ja tomada em reward_grants.dart para o snapshot de
// `acumulaContador`.

import 'tournament_lifecycle.dart';

/// Fuso de referencia de todo horario de calendario do seed.
///
/// String, e nao offset numerico: o Brasil ja mudou de regra de horario de verao
/// e pode mudar de novo. Guardar "-03:00" congelaria a decisao errada.
const fusoTorneios = 'America/Sao_Paulo';

/// Unica moeda do sistema (regra do seed: "Carteira unica: 'fichas'").
const moedaTorneios = 'fichas';

/// Quem pode entrar.
enum AcessoTorneio {
  publico('publico'),
  vip('vip'),
  misto('misto'),
  somenteConvidados('somente_convidados');

  final String wire;
  const AcessoTorneio(this.wire);

  static AcessoTorneio? porWire(String wire) {
    for (final a in AcessoTorneio.values) {
      if (a.wire == wire) return a;
    }
    return null;
  }
}

/// Regra de mesa. Espelha `ModalidadeTorneio` de screens/torneios_models.dart e
/// os valores que mesa.dart ja aceita em `Jogo.modalidade`.
enum ModalidadeMesa {
  aberto('aberto'),
  fechado('fechado'),
  stbl('stbl');

  final String wire;
  const ModalidadeMesa(this.wire);

  /// Vocabulario que `Jogo.modalidade` espera em mesa.dart.
  String get wireMotor => wire.toUpperCase();

  static ModalidadeMesa? porWire(String wire) {
    final alvo = wire.toLowerCase();
    for (final m in ModalidadeMesa.values) {
      if (m.wire == alvo) return m;
    }
    return null;
  }
}

/// Como a modalidade de cada edicao e escolhida.
enum TipoPoliticaModalidade {
  /// Sempre a mesma.
  fixa('fixa'),

  /// Alterna entre as opcoes a cada edicao.
  alterna('alterna'),

  /// Percorre as opcoes em rodizio.
  rodizio('rodizio'),

  /// A administracao define a cada mes.
  definidaMensalmente('definidaMensalmente'),

  /// A administracao define caso a caso.
  definidaPelaAdmin('definidaPelaAdmin');

  final String wire;
  const TipoPoliticaModalidade(this.wire);

  /// A modalidade sai do template sem intervencao humana.
  bool get resolveSozinha => this == fixa || this == alterna || this == rodizio;

  static TipoPoliticaModalidade? porWire(String wire) {
    for (final t in TipoPoliticaModalidade.values) {
      if (t.wire == wire) return t;
    }
    return null;
  }
}

/// Politica de modalidade do template.
class PoliticaModalidade {
  final TipoPoliticaModalidade tipo;

  /// Valor unico em [TipoPoliticaModalidade.fixa]; null nos demais.
  final ModalidadeMesa? valor;

  /// Opcoes de alternancia ou rodizio. Vazia em `fixa`.
  final List<ModalidadeMesa> opcoes;

  /// Modalidades reservadas a edicoes especiais.
  final List<ModalidadeMesa> alternaEspecial;

  const PoliticaModalidade({
    required this.tipo,
    this.valor,
    this.opcoes = const [],
    this.alternaEspecial = const [],
  });

  /// Modalidade da edicao de numero [numeroEdicao].
  ///
  /// null quando a politica exige decisao humana — nao ha default. Escolher uma
  /// modalidade no lugar da administracao mudaria a regra da mesa, e a trava do
  /// lixo e a obrigatoriedade da canastra limpa dependem dela.
  ModalidadeMesa? resolverPara(int numeroEdicao) {
    switch (tipo) {
      case TipoPoliticaModalidade.fixa:
        return valor;
      case TipoPoliticaModalidade.alterna:
      case TipoPoliticaModalidade.rodizio:
        if (opcoes.isEmpty) return null;
        // Edicao 1 pega a primeira opcao. O ciclo e deterministico: reprocessar
        // a criacao da edicao 7 devolve sempre a mesma modalidade.
        return opcoes[(numeroEdicao - 1) % opcoes.length];
      case TipoPoliticaModalidade.definidaMensalmente:
      case TipoPoliticaModalidade.definidaPelaAdmin:
        return null;
    }
  }

  factory PoliticaModalidade.fromJson(Map<String, dynamic> json, String id) {
    final tipo = TipoPoliticaModalidade.porWire(json['tipo'] as String);
    if (tipo == null) {
      throw FormatException('$id: modalidade.tipo desconhecida "${json['tipo']}".');
    }

    ModalidadeMesa exigir(String bruto) {
      final m = ModalidadeMesa.porWire(bruto);
      if (m == null) {
        throw FormatException('$id: modalidade desconhecida "$bruto".');
      }
      return m;
    }

    final valorBruto = json['valor'] as String?;
    final opcoes = ((json['opcoes'] as List?) ?? const [])
        .map((e) => exigir(e as String))
        .toList(growable: false);

    if (tipo == TipoPoliticaModalidade.fixa && valorBruto == null) {
      throw FormatException('$id: modalidade fixa exige "valor".');
    }
    if (tipo.resolveSozinha && tipo != TipoPoliticaModalidade.fixa && opcoes.isEmpty) {
      throw FormatException('$id: modalidade ${tipo.wire} exige "opcoes".');
    }

    return PoliticaModalidade(
      tipo: tipo,
      valor: valorBruto == null ? null : exigir(valorBruto),
      opcoes: opcoes,
      alternaEspecial: ((json['alternaEspecial'] as List?) ?? const [])
          .map((e) => exigir(e as String))
          .toList(growable: false),
    );
  }

  Map<String, dynamic> toJson() => {
        'tipo': tipo.wire,
        if (valor != null) 'valor': valor!.wire,
        if (opcoes.isNotEmpty) 'opcoes': opcoes.map((m) => m.wire).toList(),
        if (alternaEspecial.isNotEmpty)
          'alternaEspecial': alternaEspecial.map((m) => m.wire).toList(),
      };
}

/// Ritmo de geracao de edicoes.
enum TipoRecorrencia {
  semanal('semanal'),
  quinzenal('quinzenal'),
  mensal('mensal'),

  /// Sem recorrencia automatica: a administracao cria cada edicao.
  nenhuma('none');

  final String wire;
  const TipoRecorrencia(this.wire);

  static TipoRecorrencia? porWire(String wire) {
    for (final r in TipoRecorrencia.values) {
      if (r.wire == wire) return r;
    }
    return null;
  }
}

/// Quando a proxima edicao acontece. Todo horario e lido em [fusoTorneios].
class PoliticaRecorrencia {
  final TipoRecorrencia tipo;

  /// Dia da semana em recorrencia semanal (ex.: "quarta"). null nas demais.
  final String? diaSemana;

  /// Regra de recorrencia mensal (ex.: "ultimo_domingo"). null nas demais.
  final String? regra;

  /// Horario local de inicio, "HH:MM". null em [TipoRecorrencia.nenhuma].
  final String? horario;

  const PoliticaRecorrencia({
    required this.tipo,
    this.diaSemana,
    this.regra,
    this.horario,
  });

  factory PoliticaRecorrencia.fromJson(Map<String, dynamic> json, String id) {
    final tipo = TipoRecorrencia.porWire(json['tipo'] as String);
    if (tipo == null) {
      throw FormatException('$id: recorrencia.tipo desconhecida "${json['tipo']}".');
    }
    final horario = json['horario'] as String?;
    if (horario != null && !_horaValida(horario)) {
      throw FormatException('$id: recorrencia.horario "$horario" fora do formato HH:MM.');
    }
    if (tipo != TipoRecorrencia.nenhuma && horario == null) {
      throw FormatException('$id: recorrencia ${tipo.wire} exige horario.');
    }
    return PoliticaRecorrencia(
      tipo: tipo,
      diaSemana: json['diaSemana'] as String?,
      regra: json['regra'] as String?,
      horario: horario,
    );
  }

  Map<String, dynamic> toJson() => {
        'tipo': tipo.wire,
        if (diaSemana != null) 'diaSemana': diaSemana,
        if (regra != null) 'regra': regra,
        if (horario != null) 'horario': horario,
      };
}

bool _horaValida(String valor) =>
    RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(valor);

/// Janela de check-in, em horario local de [fusoTorneios].
class JanelaCheckin {
  final String abre;
  final String fecha;

  const JanelaCheckin({required this.abre, required this.fecha});

  factory JanelaCheckin.fromJson(Map<String, dynamic> json, String id) {
    final abre = json['abre'] as String?;
    final fecha = json['fecha'] as String?;
    if (abre == null || !_horaValida(abre)) {
      throw FormatException('$id: checkin.abre "$abre" fora do formato HH:MM.');
    }
    if (fecha == null || !_horaValida(fecha)) {
      throw FormatException('$id: checkin.fecha "$fecha" fora do formato HH:MM.');
    }
    if (fecha.compareTo(abre) <= 0) {
      throw FormatException('$id: checkin.fecha deve ser depois de checkin.abre.');
    }
    return JanelaCheckin(abre: abre, fecha: fecha);
  }

  Map<String, dynamic> toJson() => {'abre': abre, 'fecha': fecha};
}

/// Como se paga para entrar.
///
/// Guarda a estrutura do seed sem interpreta-la: a decisao de quanto cobrar de
/// quem, e quando, sai daqui como DADO. O motor le, nunca calcula um valor que
/// nao esteja no seed.
class PoliticaEntrada {
  /// `gratuito` | `paga` | `introducaoGratisDepoisPaga` | `porTrilha` | `ingresso`.
  final String tipo;

  /// Valor cobrado, em [moedaTorneios]. null quando gratuito ou por trilha.
  final int? valor;

  /// Sempre [moedaTorneios]: carteira unica.
  final String moeda;

  /// A administracao pode editar no painel.
  final bool configuravel;

  /// Quantas edicoes saem de graca antes de a cobranca comecar.
  final int? gratisPrimeirasEdicoes;

  /// Valor cobrado depois das edicoes gratuitas.
  final int? valorApos;

  /// O que conta como edicao para o contador de gratuidade.
  final String? contador;

  /// Edicoes canceladas nao consomem gratuidade.
  final bool ignoraCanceladas;

  /// Assinante entra de graca automaticamente.
  final bool gratuidadeVipAutomatica;

  /// A cobranca esta ligada. Falso em trilha configurada mas desativada.
  final bool ativar;

  /// Trilhas de entrada, quando o torneio cobra diferente por perfil de
  /// participante (ex.: classificado entra de graca, vaga remanescente paga).
  final Map<String, PoliticaEntrada> trilhas;

  const PoliticaEntrada({
    required this.tipo,
    this.valor,
    this.moeda = moedaTorneios,
    this.configuravel = false,
    this.gratisPrimeirasEdicoes,
    this.valorApos,
    this.contador,
    this.ignoraCanceladas = false,
    this.gratuidadeVipAutomatica = false,
    this.ativar = true,
    this.trilhas = const {},
  });

  /// Custo cobrado na edicao [numeroEdicao] para a trilha informada.
  ///
  /// Devolve null quando a decisao nao esta no seed — o chamador precisa saber
  /// que nao ha valor, em vez de receber zero e cobrar de graca por engano.
  int? custoPara({int numeroEdicao = 1, String? trilha}) {
    if (trilhas.isNotEmpty) {
      final escolhida = trilha == null ? null : trilhas[trilha];
      if (escolhida == null) return null;
      return escolhida.custoPara(numeroEdicao: numeroEdicao);
    }
    switch (tipo) {
      case 'gratuito':
        return 0;
      case 'paga':
      case 'ingresso':
        return ativar ? valor : 0;
      case 'introducaoGratisDepoisPaga':
        final gratis = gratisPrimeirasEdicoes;
        if (gratis == null) return null;
        return numeroEdicao <= gratis ? 0 : valorApos;
      default:
        return null;
    }
  }

  factory PoliticaEntrada.fromJson(Map<String, dynamic> json, String id) {
    // Trilhas: qualquer chave cujo valor seja um objeto com "tipo" proprio.
    final trilhas = <String, PoliticaEntrada>{};
    for (final entrada in json.entries) {
      final valor = entrada.value;
      if (valor is Map<String, dynamic> && valor.containsKey('tipo')) {
        trilhas[entrada.key] = PoliticaEntrada.fromJson(valor, '$id.${entrada.key}');
      }
    }
    if (trilhas.isNotEmpty) {
      return PoliticaEntrada(tipo: 'porTrilha', trilhas: trilhas);
    }

    final moeda = (json['moeda'] as String?) ?? moedaTorneios;
    if (moeda != moedaTorneios) {
      // Carteira unica e regra do seed. Uma moeda diferente aqui significaria
      // debitar de um saldo que nao existe.
      throw FormatException('$id: moeda "$moeda" invalida — a carteira e unica ($moedaTorneios).');
    }

    return PoliticaEntrada(
      tipo: json['tipo'] as String,
      valor: json['valor'] as int?,
      moeda: moeda,
      configuravel: (json['configuravel'] as bool?) ?? false,
      gratisPrimeirasEdicoes: json['gratisPrimeirasEdicoes'] as int?,
      valorApos: json['valorApos'] as int?,
      contador: json['contador'] as String?,
      ignoraCanceladas: (json['ignoraCanceladas'] as bool?) ?? false,
      gratuidadeVipAutomatica: (json['gratuidadeVipAutomatica'] as bool?) ?? false,
      ativar: (json['ativar'] as bool?) ?? true,
    );
  }

  Map<String, dynamic> toJson() => trilhas.isNotEmpty
      ? {for (final t in trilhas.entries) t.key: t.value.toJson()}
      : {
          'tipo': tipo,
          if (valor != null) 'valor': valor,
          'moeda': moeda,
          'configuravel': configuravel,
          if (gratisPrimeirasEdicoes != null)
            'gratisPrimeirasEdicoes': gratisPrimeirasEdicoes,
          if (valorApos != null) 'valorApos': valorApos,
          if (contador != null) 'contador': contador,
          'ativar': ativar,
        };
}

/// Premio de UMA colocacao.
///
/// Colocacao exata, e nao faixa: o seed aprovado premia 1o, 2o e 3o
/// individualmente. Faixa do tipo "3o ao 8o" nao existe na entrega, e modelar
/// uma abriria espaco para um 4o colocado entrar sem ninguem decidir — o seed
/// e explicito em nao ter Top 4.
class FaixaPremiacao {
  final int colocacao;

  /// Fichas concedidas. null quando o valor ficou como `configuravel` no seed.
  final int? fichas;

  /// O valor em fichas depende de decisao administrativa.
  final bool fichasConfiguravel;

  /// Coroa concedida, por `assetId` do assets_registry.
  final String? crownAssetId;

  /// Selo concedido, por `assetId` do assets_registry.
  final String? sealAssetId;

  /// Beneficios fora do catalogo de coroas e selos (hall, titulo, moldura).
  /// Ficam registrados para a etapa que os implementar; o motor nao os concede.
  final List<String> extras;

  /// Pontos de ranking dependem de decisao administrativa.
  final bool rankingPointsConfiguravel;

  const FaixaPremiacao({
    required this.colocacao,
    this.fichas,
    this.fichasConfiguravel = false,
    this.crownAssetId,
    this.sealAssetId,
    this.extras = const [],
    this.rankingPointsConfiguravel = false,
  });

  bool cobre(int posicao) => posicao == colocacao;

  /// Ativos de catalogo desta faixa, em ordem estavel.
  ///
  /// Uma colocacao pode conceder coroa E selo — a Quarta da Vulnerabilidade
  /// premia o campeao com as duas. Cada uma vira uma concessao propria, com
  /// chave de idempotencia propria.
  List<String> get assetIds => [
        ?crownAssetId,
        ?sealAssetId,
      ];

  factory FaixaPremiacao.fromJson(Map<String, dynamic> json, String id) {
    final colocacao = json['colocacao'];
    if (colocacao is! int || colocacao < 1) {
      throw FormatException('$id: premiacao.colocacao deve ser int >= 1 (recebido: $colocacao).');
    }

    final fichasBruto = json['fichas'];
    int? fichas;
    var fichasConfiguravel = false;
    if (fichasBruto is int) {
      if (fichasBruto < 0) {
        throw FormatException('$id: premiacao.fichas nao pode ser negativa.');
      }
      fichas = fichasBruto;
    } else if (fichasBruto == 'configuravel') {
      fichasConfiguravel = true;
    } else if (fichasBruto != null) {
      throw FormatException('$id: premiacao.fichas deve ser int ou "configuravel".');
    }

    final ranking = json['rankingPoints'];
    final rankingConfiguravel =
        ranking is Map && ranking['valor'] == 'configuravel';

    final faixa = FaixaPremiacao(
      colocacao: colocacao,
      fichas: fichas,
      fichasConfiguravel: fichasConfiguravel,
      crownAssetId: json['crownAssetId'] as String?,
      sealAssetId: json['sealAssetId'] as String?,
      extras: ((json['extras'] as List?) ?? const [])
          .map((e) => e as String)
          .toList(growable: false),
      rankingPointsConfiguravel: rankingConfiguravel,
    );

    if (faixa.assetIds.isEmpty &&
        fichas == null &&
        !fichasConfiguravel &&
        faixa.extras.isEmpty) {
      throw FormatException('$id: premiacao da colocacao $colocacao nao concede nada.');
    }
    return faixa;
  }

  Map<String, dynamic> toJson() => {
        'colocacao': colocacao,
        if (fichas != null) 'fichas': fichas,
        if (fichasConfiguravel) 'fichas': 'configuravel',
        if (crownAssetId != null) 'crownAssetId': crownAssetId,
        if (sealAssetId != null) 'sealAssetId': sealAssetId,
        if (extras.isNotEmpty) 'extras': extras,
      };
}

/// Criterio de desempate, aplicado em ordem (OS 02 secao 11).
///
/// Os quatro primeiros sao os que o projeto ja documenta, em
/// app/lib/screens/torneios_models.dart: "1. Vitorias · 2. Saldo · 3. Pontos
/// feitos · 4. Canastras limpas". Nenhum criterio alem desses foi inventado.
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

/// Individual ou dupla. Governa a formacao de mesas (seating.dart) e a unidade
/// de classificacao (standings.dart).
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
/// Decisao de EDICAO, nao de template: o seed aprovado nao fixa formato, e a
/// modalidade de varios torneios muda a cada edicao. Fica aqui porque phases.dart
/// e history.dart precisam do tipo.
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

/// Politica de pontuacao no ranking.
class PoliticaRanking {
  /// Todo participante elegivel pontua.
  final bool todosElegiveisPontuam;

  /// Participante do acesso publico pontua no ranking.
  final bool publicoPontuaRanking;

  /// Assinante pontua no ranking.
  final bool vipPontuaRanking;

  /// Participante do acesso publico recebe premios que nao sejam ranking.
  final bool publicoRecebeOutrosPremios;

  const PoliticaRanking({
    this.todosElegiveisPontuam = false,
    this.publicoPontuaRanking = false,
    this.vipPontuaRanking = false,
    this.publicoRecebeOutrosPremios = false,
  });

  factory PoliticaRanking.fromJson(Map<String, dynamic> json) => PoliticaRanking(
        todosElegiveisPontuam: (json['todosElegiveisPontuam'] as bool?) ?? false,
        publicoPontuaRanking: (json['publicoPontuaRanking'] as bool?) ?? false,
        vipPontuaRanking: (json['vipPontuaRanking'] as bool?) ?? false,
        publicoRecebeOutrosPremios:
            (json['publicoRecebeOutrosPremios'] as bool?) ?? false,
      );

  Map<String, dynamic> toJson() => {
        'todosElegiveisPontuam': todosElegiveisPontuam,
        'publicoPontuaRanking': publicoPontuaRanking,
        'vipPontuaRanking': vipPontuaRanking,
        'publicoRecebeOutrosPremios': publicoRecebeOutrosPremios,
      };
}

/// Molde recorrente de um torneio. Imutavel: alterar configuracao produz uma
/// [versao] nova, nao uma mutacao no lugar.
class TorneioTemplate {
  /// Identificador canonico e imutavel. Le a chave `templateId` do seed.
  ///
  /// O campo se chama `tournamentId` porque e assim que ele aparece em toda
  /// chave de idempotencia do dominio (concessao, inscricao, resultado, tarefa).
  /// Renomear o campo obrigaria a reescrever as chaves, e chave de idempotencia
  /// gravada nao se reescreve sem migracao.
  final String tournamentId;

  final String nome;

  /// Versao da regra. Toda edicao guarda a versao sob a qual nasceu.
  final int versao;

  final AcessoTorneio acesso;
  final TipoParticipacao participacao;
  final PoliticaModalidade modalidade;
  final PoliticaRecorrencia recorrencia;

  /// Vagas maximas. null apenas em template ainda sem dimensionamento.
  final int? vagasMax;

  /// Minimo para a edicao acontecer.
  final int? vagasMin;

  final JanelaCheckin? checkin;
  final PoliticaEntrada? entrada;
  final PoliticaRanking rankingPolicy;

  /// Premios por colocacao.
  final List<FaixaPremiacao> premiacao;

  /// Selos concedidos por desempenho ou conduta, fora da colocacao.
  final List<String> selosCondicionais;

  /// Ordem de desempate aplicada pela classificacao.
  final List<CriterioDesempate> criteriosDesempate;

  /// Arte de capa, por referencia ao assets_registry.dart.
  final String? capaAssetId;

  /// O torneio gera edicoes.
  final bool ativo;

  /// O torneio aparece para os jogadores.
  ///
  /// Separado de [ativo] de proposito: integrar a configuracao NAO e abrir o
  /// torneio ao publico. O seed aprovado traz todos com `publicado: false`, e
  /// publicar e ato administrativo posterior.
  final bool publicado;

  /// Campos que o projeto ainda NAO definiu, em texto legivel.
  final List<String> pendencias;

  /// Observacao de origem, preservada do seed para a auditoria.
  final String? nota;

  const TorneioTemplate({
    required this.tournamentId,
    required this.nome,
    required this.versao,
    required this.acesso,
    required this.participacao,
    required this.modalidade,
    required this.recorrencia,
    this.vagasMax,
    this.vagasMin,
    this.checkin,
    this.entrada,
    this.rankingPolicy = const PoliticaRanking(),
    this.premiacao = const [],
    this.selosCondicionais = const [],
    this.criteriosDesempate = desempatePadrao,
    this.capaAssetId,
    this.ativo = true,
    this.publicado = false,
    this.pendencias = const [],
    this.nota,
  });

  /// O template tem tudo que o motor precisa para rodar uma edicao.
  ///
  /// Exige exatamente o que o seed aprovado define — dimensionamento, janela de
  /// check-in, politica de entrada e tabela de premiacao. NAO exige numero de
  /// fases nem meta de pontos: o seed nao os traz porque sao decisao de edicao,
  /// e cobra-los aqui reprovaria uma configuracao que ja foi aprovada.
  bool get configuracaoCompleta =>
      pendencias.isEmpty &&
      vagasMax != null &&
      vagasMin != null &&
      checkin != null &&
      entrada != null &&
      premiacao.isNotEmpty;

  /// Criterios de elegibilidade derivados do acesso.
  ///
  /// Derivado, e nao campo proprio: dois lugares dizendo quem pode entrar
  /// divergem, e o seed ja diz isso em `acesso`.
  List<String> get criteriosElegibilidade => switch (acesso) {
        AcessoTorneio.vip => const ['assinatura'],
        AcessoTorneio.somenteConvidados => ['convite:$tournamentId'],
        AcessoTorneio.publico || AcessoTorneio.misto => const [],
      };

  /// Faixa que cobre a colocacao, ou null quando a colocacao nao premia.
  FaixaPremiacao? faixaPara(int colocacao) {
    for (final faixa in premiacao) {
      if (faixa.cobre(colocacao)) return faixa;
    }
    return null;
  }

  /// Maior colocacao premiada. Zero quando nao ha premiacao.
  int get ultimaColocacaoPremiada => premiacao.fold(
      0, (maior, f) => f.colocacao > maior ? f.colocacao : maior);

  factory TorneioTemplate.fromJson(Map<String, dynamic> json) {
    final id = (json['templateId'] ?? json['tournamentId']) as String?;
    if (id == null || id.isEmpty) {
      throw FormatException('template: templateId deve ser string nao vazia.');
    }

    final nome = json['nome'];
    if (nome is! String || nome.isEmpty) {
      throw FormatException('$id: nome deve ser string nao vazia.');
    }

    // `acesso` vem como string simples ou como objeto {tipo, elegiveis}.
    final acessoBruto = json['acesso'];
    final acessoWire = acessoBruto is Map
        ? acessoBruto['tipo'] as String?
        : acessoBruto as String?;
    final acesso = acessoWire == null ? null : AcessoTorneio.porWire(acessoWire);
    if (acesso == null) {
      throw FormatException('$id: acesso desconhecido "$acessoWire".');
    }

    final participacao =
        TipoParticipacao.porWire((json['participacao'] as String?) ?? '');
    if (participacao == null) {
      throw FormatException('$id: participacao desconhecida "${json['participacao']}".');
    }

    final modalidadeBruta = json['modalidade'];
    if (modalidadeBruta is! Map<String, dynamic>) {
      throw FormatException('$id: modalidade deve ser objeto com "tipo".');
    }

    final recorrenciaBruta = json['recorrencia'];
    if (recorrenciaBruta is! Map<String, dynamic>) {
      throw FormatException('$id: recorrencia deve ser objeto com "tipo".');
    }

    int? vaga(String campo) {
      final vagas = json['vagas'];
      if (vagas is! Map) return null;
      final v = vagas[campo];
      if (v == null) return null;
      if (v is! int || v < 2) {
        throw FormatException('$id: vagas.$campo deve ser int >= 2 (recebido: $v).');
      }
      return v;
    }

    final max = vaga('max');
    final min = vaga('min');
    if (max != null && min != null && min > max) {
      throw FormatException('$id: vagas.min ($min) maior que vagas.max ($max).');
    }

    final premiacao = ((json['premiacao'] as List?) ?? const [])
        .map((e) => FaixaPremiacao.fromJson(e as Map<String, dynamic>, id))
        .toList(growable: false);
    final colocacoes = <int>{};
    for (final faixa in premiacao) {
      if (!colocacoes.add(faixa.colocacao)) {
        throw FormatException('$id: colocacao ${faixa.colocacao} premiada duas vezes.');
      }
    }

    // Trava de "sem Top 4": o seed aprovado premia campeao, vice e terceiro.
    // Uma quarta colocacao entrando por edicao de seed seria justamente o Top 4
    // que a decisao #3 exclui desta entrega — melhor recusar a carga do que
    // descobrir na noite da final.
    final top4 = json['top4'];
    if (top4 is Map && top4['implementar'] == true) {
      throw FormatException('$id: top4.implementar e true, mas Top 4 nao faz parte desta entrega.');
    }
    for (final faixa in premiacao) {
      if (faixa.colocacao > 3) {
        throw FormatException(
            '$id: premiacao inclui a colocacao ${faixa.colocacao}; esta entrega vai ate o 3o lugar.');
      }
    }

    final checkinBruto = json['checkin'];
    final entradaBruta = json['entrada'];
    final rankingBruto = json['rankingPolicy'];

    return TorneioTemplate(
      tournamentId: id,
      nome: nome,
      // O seed nao versiona template: ele proprio e a versao 1 da configuracao
      // aprovada. Nao e numero de regra, e sim identidade de schema.
      versao: (json['versao'] as int?) ?? 1,
      acesso: acesso,
      participacao: participacao,
      modalidade: PoliticaModalidade.fromJson(modalidadeBruta, id),
      recorrencia: PoliticaRecorrencia.fromJson(recorrenciaBruta, id),
      vagasMax: max,
      vagasMin: min,
      checkin: checkinBruto is Map<String, dynamic>
          ? JanelaCheckin.fromJson(checkinBruto, id)
          : null,
      entrada: entradaBruta is Map<String, dynamic>
          ? PoliticaEntrada.fromJson(entradaBruta, id)
          : null,
      rankingPolicy: rankingBruto is Map<String, dynamic>
          ? PoliticaRanking.fromJson(rankingBruto)
          : const PoliticaRanking(),
      premiacao: premiacao,
      selosCondicionais: ((json['selosCondicionais'] as List?) ?? const [])
          .map((e) => e as String)
          .toList(growable: false),
      capaAssetId: (json['coverAssetId'] ?? json['capaAssetId']) as String?,
      ativo: (json['ativo'] as bool?) ?? true,
      // Default FALSE: um template que esqueca o campo nao pode aparecer para o
      // jogador por omissao. Publicar e ato explicito.
      publicado: (json['publicado'] as bool?) ?? false,
      pendencias: ((json['pendencias'] as List?) ?? const [])
          .map((e) => e as String)
          .toList(growable: false),
      nota: json['note'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'templateId': tournamentId,
        'nome': nome,
        'versao': versao,
        'acesso': acesso.wire,
        'participacao': participacao.wire,
        'modalidade': modalidade.toJson(),
        'recorrencia': recorrencia.toJson(),
        if (vagasMax != null || vagasMin != null)
          'vagas': {
            if (vagasMax != null) 'max': vagasMax,
            if (vagasMin != null) 'min': vagasMin,
          },
        if (checkin != null) 'checkin': checkin!.toJson(),
        if (entrada != null) 'entrada': entrada!.toJson(),
        'rankingPolicy': rankingPolicy.toJson(),
        'premiacao': premiacao.map((f) => f.toJson()).toList(),
        if (selosCondicionais.isNotEmpty) 'selosCondicionais': selosCondicionais,
        'criteriosDesempate': criteriosDesempate.map((c) => c.wire).toList(),
        if (capaAssetId != null) 'coverAssetId': capaAssetId,
        'ativo': ativo,
        'publicado': publicado,
        if (pendencias.isNotEmpty) 'pendencias': pendencias,
        if (nota != null) 'note': nota,
      };

  @override
  String toString() => 'TorneioTemplate($tournamentId v$versao)';
}

/// Configuracao estrutural do Torneio de Encerramento dos Campeoes do Ano.
///
/// Classe propria, e nao mais um [TorneioTemplate]: o seed aprovado o declara
/// numa chave separada porque ele nao tem recorrencia, tem data fixa, premia por
/// papel (campeao / vice / convidado) em vez de por colocacao, e tem um motor de
/// convites que os outros nao tem. Forca-lo no molde comum exigiria inventar
/// campos que o seed nao traz.
class EventoEncerramento {
  final String tournamentId;
  final String nome;

  /// `planejado` enquanto a etapa de convites nao for implementada.
  final String status;

  /// Data e hora oficiais, sempre em UTC apos a normalizacao.
  final DateTime dataFixa;

  final JanelaCheckin checkin;
  final AcessoTorneio acesso;

  final int? vagasMax;
  final int? vagasMin;

  /// Dimensionamentos alternativos ja aprovados.
  final List<int> escalavelPara;

  final String? capaAssetId;

  /// O motor de convites esta ligado em producao.
  ///
  /// Falso ate a tabela oficial de pesos existir. Enquanto for falso, nenhum
  /// convite e gerado automaticamente — a estrutura de annual_closing.dart fica
  /// pronta e parada, que e o que a decisao #8 pede.
  final bool convitesAtivosEmProducao;

  /// Como os pesos de convite sao definidos ("configuraveis").
  final String? pesosConvite;

  /// Premiacao por papel: `campeao`, `vice`, `convidados`.
  final Map<String, PremioEncerramento> premiacao;

  final String? nota;

  EventoEncerramento({
    required this.tournamentId,
    required this.nome,
    required this.status,
    required DateTime dataFixa,
    required this.checkin,
    required this.acesso,
    this.vagasMax,
    this.vagasMin,
    this.escalavelPara = const [],
    this.capaAssetId,
    this.convitesAtivosEmProducao = false,
    this.pesosConvite,
    this.premiacao = const {},
    this.nota,
  }) : dataFixa = dataFixa.toUtc();

  /// O evento tem dimensionamento, janela e premiacao definidos.
  bool get configuracaoCompleta =>
      vagasMax != null && vagasMin != null && premiacao.isNotEmpty;

  factory EventoEncerramento.fromJson(Map<String, dynamic> json) {
    final id = json['templateId'] as String?;
    if (id == null || id.isEmpty) {
      throw const FormatException('encerramento: templateId e obrigatorio.');
    }

    final dataBruta = json['dataFixa'] as String?;
    final data = dataBruta == null ? null : DateTime.tryParse(dataBruta);
    if (data == null) {
      throw FormatException('$id: dataFixa "$dataBruta" nao e ISO-8601 valido.');
    }

    final acesso = AcessoTorneio.porWire((json['acesso'] as String?) ?? '');
    if (acesso == null) {
      throw FormatException('$id: acesso desconhecido "${json['acesso']}".');
    }

    int? vaga(String campo) {
      final vagas = json['vagas'];
      if (vagas is! Map) return null;
      final v = vagas[campo];
      if (v == null) return null;
      if (v is! int || v < 2) {
        throw FormatException('$id: vagas.$campo deve ser int >= 2 (recebido: $v).');
      }
      return v;
    }

    final motor = json['motorConvites'];
    final premiacaoBruta = json['premiacao'];

    return EventoEncerramento(
      tournamentId: id,
      nome: json['nome'] as String,
      status: (json['status'] as String?) ?? 'planejado',
      dataFixa: data,
      checkin: JanelaCheckin.fromJson(json['checkin'] as Map<String, dynamic>, id),
      acesso: acesso,
      vagasMax: vaga('max'),
      vagasMin: vaga('min'),
      escalavelPara: (((json['vagas'] as Map?)?['escalavelPara'] as List?) ?? const [])
          .map((e) => e as int)
          .toList(growable: false),
      capaAssetId: json['coverAssetId'] as String?,
      convitesAtivosEmProducao:
          motor is Map ? (motor['ativarEmProducao'] as bool?) ?? false : false,
      pesosConvite: motor is Map ? motor['pesos'] as String? : null,
      premiacao: premiacaoBruta is Map<String, dynamic>
          ? {
              for (final papel in premiacaoBruta.entries)
                papel.key: PremioEncerramento.fromJson(
                    papel.value as Map<String, dynamic>, '$id.${papel.key}'),
            }
          : const {},
      nota: json['note'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'templateId': tournamentId,
        'nome': nome,
        'status': status,
        'dataFixa': dataFixa.toIso8601String(),
        'checkin': checkin.toJson(),
        'acesso': acesso.wire,
        'vagas': {
          if (vagasMax != null) 'max': vagasMax,
          if (vagasMin != null) 'min': vagasMin,
          if (escalavelPara.isNotEmpty) 'escalavelPara': escalavelPara,
        },
        if (capaAssetId != null) 'coverAssetId': capaAssetId,
        'motorConvites': {
          if (pesosConvite != null) 'pesos': pesosConvite,
          'ativarEmProducao': convitesAtivosEmProducao,
        },
        'premiacao': {
          for (final p in premiacao.entries) p.key: p.value.toJson(),
        },
        if (nota != null) 'note': nota,
      };

  @override
  String toString() => 'EventoEncerramento($tournamentId $status)';
}

/// Premio de um papel no encerramento anual.
class PremioEncerramento {
  final String? crownAssetId;
  final String? sealAssetId;
  final List<String> extras;

  const PremioEncerramento({
    this.crownAssetId,
    this.sealAssetId,
    this.extras = const [],
  });

  List<String> get assetIds => [
        ?crownAssetId,
        ?sealAssetId,
      ];

  factory PremioEncerramento.fromJson(Map<String, dynamic> json, String id) {
    final premio = PremioEncerramento(
      crownAssetId: json['crownAssetId'] as String?,
      sealAssetId: json['sealAssetId'] as String?,
      extras: ((json['extras'] as List?) ?? const [])
          .map((e) => e as String)
          .toList(growable: false),
    );
    if (premio.assetIds.isEmpty && premio.extras.isEmpty) {
      throw FormatException('$id: premio do encerramento nao concede nada.');
    }
    return premio;
  }

  Map<String, dynamic> toJson() => {
        if (crownAssetId != null) 'crownAssetId': crownAssetId,
        if (sealAssetId != null) 'sealAssetId': sealAssetId,
        if (extras.isNotEmpty) 'extras': extras,
      };
}

/// Ocorrencia datada de um [TorneioTemplate].
///
/// Imutavel: o motor devolve uma edicao nova a cada mudanca de estado, e a
/// camada de persistencia grava. Assim nenhuma funcao muda o estado de outra por
/// referencia compartilhada.
class EdicaoTorneio {
  final String tournamentId;

  /// Unico DENTRO do torneio, nao globalmente — mesma premissa da chave de
  /// idempotencia em reward_grants.dart.
  final String editionId;

  /// Numero sequencial exibido ("edicao 12"), >= 1.
  final int numeroEdicao;

  /// Temporada a que a edicao pertence (ex.: "2026").
  final String temporada;

  final EdicaoStatus status;

  /// Status guardado no momento da suspensao, para a retomada saber o destino.
  /// null fora de [EdicaoStatus.suspenso].
  final EdicaoStatus? statusAnterior;

  /// Inicio previsto da disputa, sempre em UTC.
  final DateTime inicioPrevisto;

  /// Abertura das inscricoes, em UTC. null enquanto nao definida.
  final DateTime? inscricoesAbremEm;

  /// Encerramento das inscricoes, em UTC. null enquanto nao definido.
  final DateTime? inscricoesFechamEm;

  /// Modalidade resolvida para esta edicao.
  ///
  /// Fica na EDICAO porque a politica do template pode ser "alterna", "rodizio"
  /// ou "definida mensalmente" — nesses casos nao existe modalidade de template,
  /// so de edicao. null enquanto a administracao nao decidir.
  final ModalidadeMesa? modalidade;

  /// Numero de fases desta edicao. null enquanto nao definido.
  final int? numeroFases;

  /// Como as fases desta edicao se encadeiam.
  ///
  /// Fica na EDICAO, e nao no template, pelo mesmo motivo de [modalidade]: o
  /// seed aprovado nao fixa formato, e varios torneios decidem a cada edicao.
  ///
  /// Ter UM lugar so para o formato e o que impede o historico de discordar da
  /// disputa. Enquanto ele era parametro solto de `montarHistorico`, era
  /// possivel apurar a edicao como `misto` e grava-la no historico como
  /// `pontos_corridos` sem nada reclamar.
  ///
  /// null enquanto a administracao nao definir.
  final FormatoTorneio? formato;

  /// Meta de pontos da partida, repassada ao Motor de Partidas.
  final int? metaPontos;

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
    this.modalidade,
    this.numeroFases,
    this.formato,
    this.metaPontos,
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
      _copiar(
        status: novo,
        statusAnterior:
            novo == EdicaoStatus.suspenso ? (statusAnterior ?? status) : null,
        em: em,
      );

  /// Define a janela de inscricao da edicao.
  ///
  /// Recebe os instantes prontos em vez de deriva-los do template: o seed
  /// aprovado nao traz duracao de inscricao, e calcular uma a partir do
  /// check-in inventaria regra de calendario que ninguem decidiu.
  EdicaoTorneio comJanela({
    required DateTime abreEm,
    required DateTime fechaEm,
    required DateTime em,
  }) =>
      _copiar(abreEm: abreEm, fechaEm: fechaEm, em: em);

  /// Resolve a modalidade a partir da politica do template.
  ///
  /// Devolve a edicao inalterada quando a politica exige decisao humana — nao
  /// escolhe modalidade no lugar da administracao.
  EdicaoTorneio comModalidadeDe(TorneioTemplate template, {required DateTime em}) {
    final resolvida = template.modalidade.resolverPara(numeroEdicao);
    if (resolvida == null) return this;
    return _copiar(modalidade: resolvida, em: em);
  }

  EdicaoTorneio _copiar({
    EdicaoStatus? status,
    EdicaoStatus? statusAnterior,
    DateTime? abreEm,
    DateTime? fechaEm,
    ModalidadeMesa? modalidade,
    required DateTime em,
  }) =>
      EdicaoTorneio(
        tournamentId: tournamentId,
        editionId: editionId,
        numeroEdicao: numeroEdicao,
        temporada: temporada,
        status: status ?? this.status,
        statusAnterior: status == null ? this.statusAnterior : statusAnterior,
        inicioPrevisto: inicioPrevisto,
        inscricoesAbremEm: abreEm ?? inscricoesAbremEm,
        inscricoesFechamEm: fechaEm ?? inscricoesFechamEm,
        modalidade: modalidade ?? this.modalidade,
        numeroFases: numeroFases,
        formato: formato,
        metaPontos: metaPontos,
        regraVersao: regraVersao,
        criadoEm: criadoEm,
        atualizadoEm: em,
      );

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

    final modalidadeWire = json['modalidade'] as String?;
    ModalidadeMesa? modalidade;
    if (modalidadeWire != null) {
      modalidade = ModalidadeMesa.porWire(modalidadeWire);
      if (modalidade == null) {
        throw FormatException('edicao: modalidade desconhecida "$modalidadeWire".');
      }
    }

    // Valor gravado que o dominio nao reconhece e registro corrompido, nao
    // ausencia: aceitar como null faria a edicao parecer "sem formato definido"
    // e o historico seria recusado por um motivo enganoso.
    final formatoWire = json['formato'] as String?;
    FormatoTorneio? formato;
    if (formatoWire != null) {
      formato = FormatoTorneio.porWire(formatoWire);
      if (formato == null) {
        throw FormatException('edicao: formato desconhecido "$formatoWire".');
      }
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
        modalidade: modalidade,
        numeroFases: json['numeroFases'] as int?,
        formato: formato,
        metaPontos: json['metaPontos'] as int?,
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
        'modalidade': modalidade?.wire,
        'numeroFases': numeroFases,
        'formato': formato?.wire,
        'metaPontos': metaPontos,
        'regraVersao': regraVersao,
        'criadoEm': criadoEm.toIso8601String(),
        'atualizadoEm': atualizadoEm.toIso8601String(),
      };

  @override
  String toString() => 'EdicaoTorneio($chave #$numeroEdicao ${status.wire})';
}
