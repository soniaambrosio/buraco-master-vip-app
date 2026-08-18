// OS 4 — ORÇAMENTO DETERMINÍSTICO DE BUSCA DO BOT.
//
// O PROBLEMA QUE ESTE ARQUIVO RESOLVE
// A camada estratégica tinha um contador (`_nos`) que cobria só a ENUMERAÇÃO de
// planos da fase de jogo. A fase de COMPRA do Fechado/STBL — onde a autoridade
// deriva todos os usos atômicos do topo do lixo — não tinha teto nenhum. Numa
// mão de 19 cartas do STBL isso mediu 101.404 transações validadas em 17
// segundos, contra 227 ms de toda a fase de jogo. O turno passava de 20 s, e
// uma partida chegou a 2 horas.
//
// A AUTORIDADE É O TRABALHO, NÃO O RELÓGIO
// O limite que decide é DETERMINÍSTICO: nós expandidos, combinações examinadas
// e planos completos avaliados. Aparelho mais rápido não muda a decisão — o que
// seria o caso se o corte fosse por tempo. O fusível temporal existe, mas só
// como proteção contra defeito não previsto no contador; ele não desempata,
// não reordena e não governa decisão normal.
//
// CONTADOR ÚNICO
// Um `OrcamentoBuscaBot` nasce por DECISÃO e é passado explicitamente para toda
// camada que expande. Não existe contador paralelo: o gerador não guarda mais o
// seu próprio `_nos`, e a derivação de compra do lixo recebe o teto que este
// objeto publica. Nada atravessa turnos, e dois bots decidindo ao mesmo tempo
// têm orçamentos distintos porque cada `decidir*` cria o seu.
library;

/// Por que a busca terminou. Entra na telemetria e nos testes.
enum MotivoEncerramentoBusca {
  /// A busca varreu tudo o que havia, dentro do orçamento.
  buscaCompleta,

  /// O limite DETERMINÍSTICO de trabalho foi atingido.
  orcamentoDeterministico,

  /// O fusível TEMPORAL disparou (proteção secundária).
  fusivelTemporal,
}

/// Em que fase da busca o limite foi atingido.
enum FaseBusca {
  /// Derivação dos usos atômicos do topo do lixo (Fechado/STBL).
  derivacaoCompraLixo,

  /// Enumeração de melds/extensões candidatos da mão.
  enumeracaoUnidades,

  /// Combinação disjunta de unidades em baixadas.
  combinacaoBaixadas,

  /// Expansão de baixada + descarte em planos completos.
  expansaoPlanos,

  /// Pontuação dos planos completos pelo avaliador.
  avaliacaoPlanos,
}

/// Limites de trabalho de UMA decisão. Todos determinísticos.
///
/// Os números vivem em `ConfiguracaoBot` (é lá que mora toda calibração); esta
/// classe só os transporta, para que o orçamento seja construível em teste sem
/// arrastar a configuração inteira.
class LimitesBusca {
  /// Nós de enumeração (DFS de melds + combinação de unidades) na fase de jogo.
  final int nos;

  /// Transações de compra do lixo VALIDADAS na derivação da fase de compra.
  /// É a unidade de trabalho que explodia: cada uma roda `avaliarComprarLixo`
  /// mais `acaoEhLegal`, isto é, dois clones profundos do estado inteiro.
  final int transacoesCompraLixo;

  /// Planos completos efetivamente pontuados pelo avaliador.
  final int planosAvaliados;

  /// Fusível temporal em milissegundos. Zero desliga o fusível.
  final int fusivelMs;

  const LimitesBusca({
    required this.nos,
    required this.transacoesCompraLixo,
    required this.planosAvaliados,
    required this.fusivelMs,
  });
}

/// Contador ÚNICO de uma decisão do bot.
///
/// Regras que este objeto garante por construção:
///  - nasce por decisão (quem cria é `ExecutorBot`, em cada `decidir*`);
///  - nunca é reiniciado no meio: não existe `reset`, de propósito;
///  - o esgotamento é POR DIMENSÃO e absorvente dentro dela: gastar todos os
///    nós não impede a expansão nem a avaliação do que já foi enumerado;
///  - não sorteia, não lê relógio para decidir e não conhece carta nenhuma.
class OrcamentoBuscaBot {
  final LimitesBusca limites;

  int _nos = 0;
  int _transacoesCompraLixo = 0;
  int _planosAvaliados = 0;

  // ESGOTAMENTO POR DIMENSAO, e nao um unico interruptor.
  //
  // A primeira versao usava um so `_esgotado` absorvente, e isso quebrou a
  // busca: numa mao grande a ENUMERACAO gasta todos os nos, o interruptor
  // fechava, e a EXPANSAO e a AVALIACAO nem comecavam — o gerador devolvia
  // ZERO planos onde a base devolvia 110. Cortar a enumeracao precisa deixar
  // intacto o direito de transformar em plano completo o que ja foi enumerado;
  // senao o corte nao limita a busca, ele apaga a busca.
  bool _nosEsgotados = false;
  bool _planosEsgotados = false;
  bool _fusivelQueimou = false;

  MotivoEncerramentoBusca _motivo = MotivoEncerramentoBusca.buscaCompleta;
  FaseBusca? _faseDoLimite;
  bool _houveFallback = false;

  /// Relógio do FUSÍVEL. Só é consultado em pontos seguros da expansão, e só
  /// para abortar — nunca para escolher, ordenar ou desempatar.
  final Stopwatch _relogio = Stopwatch();

  OrcamentoBuscaBot(this.limites) {
    if (limites.fusivelMs > 0) _relogio.start();
  }

  /// Orçamento SEM limite prático — para os testes que precisam da busca
  /// completa e para provar que a decisão não muda quando nada aperta.
  factory OrcamentoBuscaBot.ilimitado() => OrcamentoBuscaBot(
        const LimitesBusca(
          nos: 1 << 30,
          transacoesCompraLixo: 1 << 30,
          planosAvaliados: 1 << 30,
          fusivelMs: 0,
        ),
      );

  int get nos => _nos;
  int get transacoesCompraLixo => _transacoesCompraLixo;
  int get planosAvaliados => _planosAvaliados;

  /// Alguma dimensao do orcamento acabou (ou o fusivel queimou). E o que vira
  /// `truncado` no rastro: a cobertura foi parcial, ainda que a decisao seja
  /// completa e legal.
  bool get esgotado =>
      _nosEsgotados || _planosEsgotados || _fusivelQueimou || _lixoEstourou;

  /// A EXPANSAO em planos completos pode continuar?
  ///
  /// Nao consulta o orcamento de NOS de proposito: expandir o que ja foi
  /// enumerado e o que produz uma decisao utilizavel, e a largura da expansao
  /// ja tem teto proprio. Aqui so o fusivel e o teto de planos mandam parar.
  bool podeExpandir() => !_fusivelQueimou && !_planosEsgotados;
  MotivoEncerramentoBusca get motivo => _motivo;
  FaseBusca? get faseDoLimite => _faseDoLimite;
  bool get houveFallback => _houveFallback;

  /// A derivação de compra do lixo bateu o teto dela.
  bool get lixoEstourou => _lixoEstourou;
  bool _lixoEstourou = false;

  /// Quanto do orçamento de NÓS sobra. Só instrumentação.
  int get nosRestantes {
    final r = limites.nos - _nos;
    return r < 0 ? 0 : r;
  }

  /// Quanto do orçamento de TRANSAÇÕES de lixo sobra.
  int get transacoesRestantes {
    final r = limites.transacoesCompraLixo - _transacoesCompraLixo;
    return r < 0 ? 0 : r;
  }

  /// Teto ABSOLUTO de transações da derivação de compra do lixo, para que a
  /// autoridade possa parar sozinha sem conhecer este objeto. É assim que o
  /// motor recebe um teto de trabalho sem passar a conhecer o bot.
  int get tetoTransacoesCompraLixo => limites.transacoesCompraLixo;

  /// Marca que a decisão precisou do fallback legal.
  void marcarFallback() => _houveFallback = true;

  /// Registra trabalho já feito por uma camada que conta sozinha (a derivação
  /// de compra do lixo devolve os seus contadores no fim).
  void registrarTransacoesCompraLixo(int quantas, {required bool estourou}) {
    _transacoesCompraLixo += quantas;
    if (estourou) {
      // A derivação do lixo tem teto PRÓPRIO e não consome nós nem planos:
      // estourá-la registra o motivo, mas não fecha a busca do turno.
      _registrar(MotivoEncerramentoBusca.orcamentoDeterministico,
          FaseBusca.derivacaoCompraLixo);
      _lixoEstourou = true;
    }
  }

  /// Gasta UM nó de enumeração. Devolve `false` quando não há mais orçamento —
  /// e, a partir daí, sempre `false`.
  bool gastarNo(FaseBusca fase) {
    if (_nosEsgotados || _fusivelQueimou) return false;
    _nos++;
    if (_nos > limites.nos) {
      _nosEsgotados = true;
      _registrar(MotivoEncerramentoBusca.orcamentoDeterministico, fase);
      return false;
    }
    return !_verificarFusivel(fase);
  }

  /// Gasta UM plano completo pontuado.
  bool gastarPlanoAvaliado() {
    if (_planosEsgotados || _fusivelQueimou) return false;
    _planosAvaliados++;
    if (_planosAvaliados > limites.planosAvaliados) {
      _planosEsgotados = true;
      _registrar(MotivoEncerramentoBusca.orcamentoDeterministico,
          FaseBusca.avaliacaoPlanos);
      return false;
    }
    return !_verificarFusivel(FaseBusca.avaliacaoPlanos);
  }

  /// PONTO SEGURO de verificação do fusível: só entre unidades de trabalho
  /// completas, nunca no meio de uma mutação.
  bool _verificarFusivel(FaseBusca fase) {
    if (limites.fusivelMs <= 0 || _fusivelQueimou) return _fusivelQueimou;
    // Consultar o relógio a cada nó custaria caro e não mudaria nada: o fusível
    // é grosseiro por natureza. A cada 256 unidades de trabalho é frequente o
    // bastante para cortar um travamento e raro o bastante para não pesar.
    if ((_nos + _planosAvaliados) % 256 != 0) return false;
    if (_relogio.elapsedMilliseconds >= limites.fusivelMs) {
      _fusivelQueimou = true;
      _registrar(MotivoEncerramentoBusca.fusivelTemporal, fase);
      return true;
    }
    return false;
  }

  /// Registra o PRIMEIRO motivo e a PRIMEIRA fase em que um limite bateu. O
  /// que veio depois e consequencia, nao causa.
  void _registrar(MotivoEncerramentoBusca m, FaseBusca fase) {
    if (_motivo != MotivoEncerramentoBusca.buscaCompleta) return;
    _motivo = m;
    _faseDoLimite = fase;
  }

  /// Telemetria da decisão. Só números e enums — nenhuma carta, nenhum
  /// identificador de jogador, nenhum estado privado.
  Map<String, Object?> toJson() => {
        'motivo': _motivo.name,
        if (_faseDoLimite != null) 'fase': _faseDoLimite!.name,
        'nos': _nos,
        'transacoesLixo': _transacoesCompraLixo,
        'planosAvaliados': _planosAvaliados,
        'esgotado': esgotado,
        'nosEsgotados': _nosEsgotados,
        'planosEsgotados': _planosEsgotados,
        'fusivel': _fusivelQueimou,
        'fallback': _houveFallback,
      };
}
