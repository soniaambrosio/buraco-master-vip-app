// limites.dart — O RITMO. Quanto se pode falar, e com que frequência.
//
// A §6.5 pede seis coisas, e todas do lado do SERVIDOR: limite por intervalo,
// cooldown por categoria, limite de repetição da mesma fala, contenção de
// rajada, bloqueio temporário em abuso e idempotência em retries. A sexta já
// existia (`executarUmaVez`, em functions-moderacao/src/idempotency.ts); as
// cinco primeiras nascem aqui.
//
// ===========================================================================
// POR QUE ISTO NÃO PODE MORAR NO CLIENTE
// ===========================================================================
//
// Um temporizador na tela é uma cortesia com o jogador distraído: ele evita que
// alguém mande a mesma fala três vezes por engano. Ele não evita NADA de quem
// quer inundar a mesa, porque essa pessoa não usa a tela — ela chama o endpoint.
// A §6.5 é explícita: "Não depender de temporizador visual no cliente".
//
// A consequência de projeto é esta: o cliente PODE (e deve) desenhar o mesmo
// cooldown, mas a resposta que vale é a daqui.
//
// ===========================================================================
// NADA AQUI LÊ RELÓGIO
// ===========================================================================
//
// [avaliarRitmo] recebe `agora`. É a mesma disciplina de
// app/lib/moderacao/sancao.dart e de app/lib/chat/porta.dart, e o motivo é o
// mesmo: uma operação inteira precisa enxergar UM instante. Duas leituras de
// relógio na mesma decisão fariam a checagem de rajada e a de cooldown
// discordarem sobre quanto tempo passou.

import 'catalogo.dart';
import 'evento.dart';

/// Um envio que já aconteceu, como o estado o guarda.
///
/// O QUE ELE NÃO GUARDA: o conteúdo. Nem o texto privado, nem a frase da fala.
/// Para medir ritmo basta saber QUANDO e O QUÊ (por id), e guardar conteúdo
/// aqui seria uma segunda cópia da mensagem fora do documento dela — com
/// retenção própria e sem finalidade, o oposto do que a §11 manda.
class RegistroDeRitmo {
  /// Instante do envio, em milissegundos desde a época (UTC).
  final int emMs;

  /// `itemId` do catálogo, ou `null` para texto privado.
  final String? itemId;

  /// Categoria do item, ou `null` para texto privado.
  final CategoriaDeComunicacao? categoria;

  const RegistroDeRitmo({
    required this.emMs,
    this.itemId,
    this.categoria,
  });

  Map<String, Object?> toJson() => {
        'emMs': emMs,
        if (itemId != null) 'itemId': itemId,
        if (categoria != null) 'categoria': categoria!.wire,
      };

  static RegistroDeRitmo? fromJson(Object? bruto) {
    if (bruto is! Map) return null;
    final ms = bruto['emMs'];
    if (ms is! num) return null;
    final cat = bruto['categoria'];
    CategoriaDeComunicacao? categoria;
    if (cat is String) {
      for (final c in CategoriaDeComunicacao.values) {
        if (c.wire == cat) categoria = c;
      }
    }
    final item = bruto['itemId'];
    return RegistroDeRitmo(
      emMs: ms.toInt(),
      itemId: item is String ? item : null,
      categoria: categoria,
    );
  }
}

/// O estado de ritmo de UM jogador. Documento pequeno e de vida curta.
class EstadoDeRitmo {
  /// Envios recentes, mais antigo primeiro. Aparado a cada avaliação: o que
  /// saiu de todas as janelas não interessa a ninguém e não se guarda.
  final List<RegistroDeRitmo> recentes;

  /// Comunicação bloqueada por abuso até este instante (ms), ou `null`.
  ///
  /// ISTO NÃO É SANÇÃO. Sanção é decisão de moderação, tem responsável, motivo
  /// e trilha (app/lib/moderacao/sancao.dart). Isto é um freio automático de
  /// minutos, sem julgamento e sem registro disciplinar — e o vocabulário
  /// precisa distinguir os dois, senão um freio de rajada vira "punido" no
  /// relatório de alguém.
  final int? bloqueadoAteMs;

  /// Recusas de ritmo seguidas. Zera a cada envio aceito.
  final int recusasSeguidas;

  const EstadoDeRitmo({
    this.recentes = const [],
    this.bloqueadoAteMs,
    this.recusasSeguidas = 0,
  });

  Map<String, Object?> toJson() => {
        'recentes': [for (final r in recentes) r.toJson()],
        if (bloqueadoAteMs != null) 'bloqueadoAteMs': bloqueadoAteMs,
        'recusasSeguidas': recusasSeguidas,
      };

  /// Lê o documento gravado. Tudo que não der para ler vira estado VAZIO — que
  /// é o estado de quem nunca falou, e é seguro: um estado ilegível não pode
  /// virar "já falou demais" nem "está bloqueado", porque nenhuma das duas
  /// leituras seria justificável.
  static EstadoDeRitmo fromJson(Object? bruto) {
    if (bruto is! Map) return const EstadoDeRitmo();
    final lista = bruto['recentes'];
    final recentes = <RegistroDeRitmo>[];
    if (lista is List) {
      for (final item in lista) {
        final r = RegistroDeRitmo.fromJson(item);
        if (r != null) recentes.add(r);
      }
    }
    final bloqueado = bruto['bloqueadoAteMs'];
    final recusas = bruto['recusasSeguidas'];
    return EstadoDeRitmo(
      recentes: recentes,
      bloqueadoAteMs: bloqueado is num ? bloqueado.toInt() : null,
      recusasSeguidas: recusas is num ? recusas.toInt() : 0,
    );
  }
}

/// Os limites. UM lugar, e configuráveis (§6.5: "centralizado e configurável").
///
/// Os números são o ponto de partida, e cada um tem uma razão de tamanho — não
/// de precisão. Nenhum deles foi medido em produção, porque não há produção; o
/// que existe é a ordem de grandeza que mantém uma mesa legível.
class ConfiguracaoDeRitmo {
  /// Teto de envios na [janela]. Vale para TUDO — fala, reação, emoji, texto.
  final int limitePorJanela;
  final Duration janela;

  /// Teto de envios na [janelaDeRajada]. É o freio do dedo rápido: o limite por
  /// minuto sozinho deixaria mandar vinte coisas no mesmo segundo e ficar
  /// quieto os cinquenta e nove restantes.
  final int rajadaMaxima;
  final Duration janelaDeRajada;

  /// Quantas vezes o MESMO item pode aparecer em [janelaDeRepeticao].
  final int repeticoesDoMesmoItem;
  final Duration janelaDeRepeticao;

  /// Intervalo mínimo entre dois itens da mesma categoria.
  ///
  /// Por categoria, e não só por item, porque o abuso não precisa repetir: dez
  /// provocações DIFERENTES em dez segundos são a mesma inundação.
  final Map<CategoriaDeComunicacao, Duration> cooldownPorCategoria;
  final Duration cooldownPadraoDeCategoria;

  /// Intervalo mínimo entre duas linhas de texto privado.
  ///
  /// MENOR que o das falas, e de propósito: texto é conversa, e conversa tem
  /// ritmo de conversa. O que segura o texto é o limite por janela.
  final Duration cooldownDeTextoPrivado;

  /// Recusas de ritmo seguidas que acionam o bloqueio temporário.
  final int recusasParaBloquear;
  final Duration bloqueioPorAbuso;

  const ConfiguracaoDeRitmo({
    this.limitePorJanela = 20,
    this.janela = const Duration(minutes: 1),
    this.rajadaMaxima = 5,
    this.janelaDeRajada = const Duration(seconds: 5),
    this.repeticoesDoMesmoItem = 3,
    this.janelaDeRepeticao = const Duration(minutes: 2),
    this.cooldownPorCategoria = const {},
    this.cooldownPadraoDeCategoria = const Duration(seconds: 3),
    this.cooldownDeTextoPrivado = const Duration(milliseconds: 700),
    this.recusasParaBloquear = 5,
    this.bloqueioPorAbuso = const Duration(minutes: 2),
  });

  /// A configuração vigente. Um valor, nomeado, para que mudar limite seja
  /// mudar UMA linha e não caçar constantes.
  static const padrao = ConfiguracaoDeRitmo(
    cooldownPorCategoria: {
      // Convidar para jogo é o que mais incomoda quando repete: ele pede
      // resposta de quem não pediu nada.
      CategoriaDeComunicacao.chamarParaJogo: Duration(seconds: 45),
      CategoriaDeComunicacao.provocar: Duration(seconds: 15),
      CategoriaDeComunicacao.elogiar: Duration(seconds: 5),
      CategoriaDeComunicacao.reacao: Duration(seconds: 3),
      CategoriaDeComunicacao.emoji: Duration(seconds: 2),
    },
  );

  /// O cooldown de uma CATEGORIA. Categoria ausente cai no padrão dela, e NÃO
  /// no cooldown do texto privado: o texto tem caminho próprio em
  /// [avaliarRitmo], escolhido pelo tipo. Se a ausência caísse no texto, um
  /// item catalogado que chegasse sem categoria herdaria o intervalo mais curto
  /// do sistema — dado incompleto concedendo mais, que é o avesso da regra.
  Duration cooldownDe(CategoriaDeComunicacao? categoria) {
    if (categoria == null) return cooldownPadraoDeCategoria;
    return cooldownPorCategoria[categoria] ?? cooldownPadraoDeCategoria;
  }

  /// A maior janela que o estado precisa lembrar. O que for mais velho que isto
  /// não influencia decisão nenhuma e é descartado.
  Duration get horizonte {
    var maior = janela;
    if (janelaDeRepeticao > maior) maior = janelaDeRepeticao;
    if (janelaDeRajada > maior) maior = janelaDeRajada;
    for (final d in cooldownPorCategoria.values) {
      if (d > maior) maior = d;
    }
    if (cooldownPadraoDeCategoria > maior) maior = cooldownPadraoDeCategoria;
    return maior;
  }

  Map<String, Object?> toJson() => {
        'limitePorJanela': limitePorJanela,
        'janelaMs': janela.inMilliseconds,
        'rajadaMaxima': rajadaMaxima,
        'janelaDeRajadaMs': janelaDeRajada.inMilliseconds,
        'repeticoesDoMesmoItem': repeticoesDoMesmoItem,
        'janelaDeRepeticaoMs': janelaDeRepeticao.inMilliseconds,
        'cooldownPorCategoriaMs': {
          for (final e in cooldownPorCategoria.entries)
            e.key.wire: e.value.inMilliseconds,
        },
        'cooldownPadraoDeCategoriaMs': cooldownPadraoDeCategoria.inMilliseconds,
        'cooldownDeTextoPrivadoMs': cooldownDeTextoPrivado.inMilliseconds,
        'recusasParaBloquear': recusasParaBloquear,
        'bloqueioPorAbusoMs': bloqueioPorAbuso.inMilliseconds,
      };
}

/// Por que o ritmo recusou.
enum MotivoDeRitmo {
  /// Bloqueio temporário por abuso ainda em vigor.
  bloqueadoPorAbuso,

  /// Passou do teto na janela longa.
  limiteDaJanela,

  /// Muitos envios no mesmo punhado de segundos.
  rajada,

  /// A mesma fala outra vez, cedo demais.
  repeticaoDoMesmoItem,

  /// Dois itens da mesma categoria em sequência, cedo demais.
  cooldownDeCategoria,

  /// O item tem cooldown PRÓPRIO, maior que o da categoria.
  cooldownDoItem,
}

/// O veredito do ritmo.
class VereditoDeRitmo {
  final bool permitido;
  final MotivoDeRitmo? motivo;

  /// Quando a mesma tentativa passaria a ser aceita (ms). Serve ao cliente para
  /// desenhar o contador — e é informação sobre QUEM PEDIU, nunca sobre
  /// terceiro, então pode voltar na resposta.
  final int? liberaEmMs;

  /// O estado a gravar. Vem preenchido nos DOIS desfechos: a recusa também
  /// muda o estado (conta recusa seguida, e pode acionar o bloqueio).
  final EstadoDeRitmo proximoEstado;

  const VereditoDeRitmo({
    required this.permitido,
    required this.proximoEstado,
    this.motivo,
    this.liberaEmMs,
  });

  Map<String, Object?> toJson() => {
        'permitido': permitido,
        if (motivo != null) 'motivo': motivo!.name,
        if (liberaEmMs != null) 'liberaEmMs': liberaEmMs,
        'estado': proximoEstado.toJson(),
      };
}

/// Decide se este envio cabe no ritmo, e devolve o estado seguinte.
///
/// A ORDEM das perguntas é do mais grave ao mais brando: bloqueio em vigor,
/// teto da janela, rajada, repetição, cooldown. Todas recusam igual; a ordem
/// decide QUAL motivo o jogador recebe, e o mais grave é o mais informativo.
///
/// O ESTADO SEGUINTE É SEMPRE DEVOLVIDO, inclusive na recusa. Sem isso, uma
/// rajada de pedidos recusados não contaria como abuso — e o freio automático
/// da §6.5 nunca dispararia, porque nenhuma tentativa recusada teria deixado
/// rastro.
VereditoDeRitmo avaliarRitmo({
  required ConfiguracaoDeRitmo config,
  required EstadoDeRitmo estado,
  required DateTime agora,
  required TipoDeComunicacao tipo,
  CategoriaDeComunicacao? categoria,
  String? itemId,
  Duration cooldownDoItem = Duration.zero,
}) {
  final agoraMs = agora.toUtc().millisecondsSinceEpoch;

  // Apara o histórico ANTES de qualquer conta. O que saiu do horizonte não
  // participa de decisão nenhuma, e carregá-lo faria o documento crescer sem
  // limite para um dado que ninguém consulta.
  final horizonteMs = config.horizonte.inMilliseconds;
  final recentes = [
    for (final r in estado.recentes)
      if (agoraMs - r.emMs <= horizonteMs) r,
  ];

  VereditoDeRitmo recusar(MotivoDeRitmo motivo, int? liberaEm) {
    final recusas = estado.recusasSeguidas + 1;
    final bloqueia = recusas >= config.recusasParaBloquear;
    return VereditoDeRitmo(
      permitido: false,
      motivo: bloqueia ? MotivoDeRitmo.bloqueadoPorAbuso : motivo,
      liberaEmMs: bloqueia
          ? agoraMs + config.bloqueioPorAbuso.inMilliseconds
          : liberaEm,
      proximoEstado: EstadoDeRitmo(
        recentes: recentes,
        recusasSeguidas: bloqueia ? 0 : recusas,
        bloqueadoAteMs: bloqueia
            ? agoraMs + config.bloqueioPorAbuso.inMilliseconds
            : estado.bloqueadoAteMs,
      ),
    );
  }

  // 1. BLOQUEIO EM VIGOR. Recusa sem contar recusa nova: quem já está freado
  //    não fica mais freado por insistir, e contar aqui faria o bloqueio se
  //    renovar sozinho enquanto o cliente tentasse reconectar.
  final bloqueadoAte = estado.bloqueadoAteMs;
  if (bloqueadoAte != null && agoraMs < bloqueadoAte) {
    return VereditoDeRitmo(
      permitido: false,
      motivo: MotivoDeRitmo.bloqueadoPorAbuso,
      liberaEmMs: bloqueadoAte,
      proximoEstado: EstadoDeRitmo(
        recentes: recentes,
        bloqueadoAteMs: bloqueadoAte,
        recusasSeguidas: estado.recusasSeguidas,
      ),
    );
  }

  // 2. TETO DA JANELA.
  final naJanela = [
    for (final r in recentes)
      if (agoraMs - r.emMs <= config.janela.inMilliseconds) r,
  ];
  if (naJanela.length >= config.limitePorJanela) {
    final maisAntigo = naJanela.first.emMs;
    return recusar(
      MotivoDeRitmo.limiteDaJanela,
      maisAntigo + config.janela.inMilliseconds,
    );
  }

  // 3. RAJADA.
  final naRajada = [
    for (final r in recentes)
      if (agoraMs - r.emMs <= config.janelaDeRajada.inMilliseconds) r,
  ];
  if (naRajada.length >= config.rajadaMaxima) {
    final maisAntigo = naRajada.first.emMs;
    return recusar(
      MotivoDeRitmo.rajada,
      maisAntigo + config.janelaDeRajada.inMilliseconds,
    );
  }

  // 4. REPETIÇÃO DO MESMO ITEM. Só se aplica a item catalogado: texto privado
  //    não tem id, e comparar textos iguais seria olhar o conteúdo — que este
  //    módulo deliberadamente não guarda.
  if (itemId != null) {
    final repeticoes = [
      for (final r in recentes)
        if (r.itemId == itemId &&
            agoraMs - r.emMs <= config.janelaDeRepeticao.inMilliseconds)
          r,
    ];
    if (repeticoes.length >= config.repeticoesDoMesmoItem) {
      final maisAntigo = repeticoes.first.emMs;
      return recusar(
        MotivoDeRitmo.repeticaoDoMesmoItem,
        maisAntigo + config.janelaDeRepeticao.inMilliseconds,
      );
    }

    // 5. COOLDOWN PRÓPRIO DO ITEM.
    if (cooldownDoItem > Duration.zero) {
      final ultimoDoItem = _ultimo(recentes, (r) => r.itemId == itemId);
      if (ultimoDoItem != null &&
          agoraMs - ultimoDoItem.emMs < cooldownDoItem.inMilliseconds) {
        return recusar(
          MotivoDeRitmo.cooldownDoItem,
          ultimoDoItem.emMs + cooldownDoItem.inMilliseconds,
        );
      }
    }
  }

  // 6. COOLDOWN DA CATEGORIA — ou o do texto privado, e a escolha olha o TIPO,
  //    não a ausência de categoria. A diferença aparece no dia em que um item
  //    catalogado chegar sem categoria por defeito de dados: pela ausência, ele
  //    herdaria o cooldown do texto (o mais curto do sistema); pelo tipo, ele
  //    herda o padrão de categoria, que é o conservador.
  final cooldown = tipo == TipoDeComunicacao.textoPrivado
      ? config.cooldownDeTextoPrivado
      : config.cooldownDe(categoria);
  if (cooldown > Duration.zero) {
    final ultimo = _ultimo(recentes, (r) => r.categoria == categoria);
    if (ultimo != null && agoraMs - ultimo.emMs < cooldown.inMilliseconds) {
      // UM motivo para os dois casos. O texto privado não ganha motivo próprio
      // porque, do ponto de vista de quem recebe a recusa, a resposta é a
      // mesma: "cedo demais para outra". A distinção que importaria — qual
      // cooldown foi aplicado — está em `liberaEmMs`, que é acionável.
      return recusar(
        MotivoDeRitmo.cooldownDeCategoria,
        ultimo.emMs + cooldown.inMilliseconds,
      );
    }
  }

  // ACEITO. O registro entra no histórico e as recusas seguidas zeram: quem
  // conseguiu falar não está mais em rajada.
  return VereditoDeRitmo(
    permitido: true,
    proximoEstado: EstadoDeRitmo(
      recentes: [
        ...recentes,
        RegistroDeRitmo(emMs: agoraMs, itemId: itemId, categoria: categoria),
      ],
      recusasSeguidas: 0,
      bloqueadoAteMs: null,
    ),
  );
}

RegistroDeRitmo? _ultimo(
  List<RegistroDeRitmo> registros,
  bool Function(RegistroDeRitmo) filtro,
) {
  RegistroDeRitmo? achado;
  for (final r in registros) {
    if (filtro(r) && (achado == null || r.emMs > achado.emMs)) achado = r;
  }
  return achado;
}
