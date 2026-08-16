// estado_mesa_online.dart — a fronteira entre a VISÃO do servidor e a tela.
//
// ===========================================================================
// QUEM MANDA
// ===========================================================================
//
// Em partida online o servidor é a autoridade do estado e do resultado. Este
// arquivo não é um motor: ele não distribui carta, não decide se uma jogada
// valeu, não conta ponto e não sabe as regras do Buraco. Ele faz UMA coisa —
// transformar o mapa cru que chegou pelo fio num estado de apresentação que a
// tela consegue desenhar, ou RECUSAR esse mapa quando ele não descreve uma
// mesa.
//
// A recusa é o ponto. Um adaptador escrito com `?? 0` e `?? []` em cada campo
// nunca falha e sempre mente: uma visão truncada vira uma mesa com placar
// zerado, mão vazia e a vez de ninguém — que a pessoa lê como "estou perdendo
// de 0 a 0 sem cartas" em vez de "o aplicativo não entendeu o servidor". Aqui,
// campo obrigatório ausente ou com tipo errado produz [VisaoRecusada], e quem
// desenha mostra erro honesto em vez de uma mesa inventada.
//
// A distinção entre OBRIGATÓRIO e NULO POR CONTRATO é do servidor, não nossa:
//
//   obrigatórios  voceAssento, modalidade, rodada, placar, vez, suaVez,
//                 jaComprou, suaMao, assentos, monteQtd, lixoQtd, mortosQtd,
//                 jogosDupla, encerrada, rodadaEncerrada
//   nulos válidos lixoTopo (lixo vazio), lixoAberto (só o ABERTO o publica),
//                 duplaQueBateu e pontosRodada (só com a rodada encerrada),
//                 precisaUsarTopo (só depois de comprar o lixo no
//                 FECHADO/SBTL), metaPontos (mesa sem meta declarada)
//
// ===========================================================================
// O QUE NÃO ATRAVESSA ESTA FRONTEIRA
// ===========================================================================
//
// A carta alheia. `visaoDoAssento` já é uma projeção por assento — dos outros
// jogadores vem só `qtdCartas` —, e este arquivo não tem por onde reconstruir
// o que não recebeu. [AssentoOnline] carrega uma CONTAGEM e nenhuma lista de
// cartas, e é uma classe diferente de quem tem mão justamente para que
// "desenhar a mão do assento 2" não seja uma coisa expressável.
//
// `jogadorId` e os campos de avatar também ficam de fora: eles chegam na visão
// (o servidor injeta para a mesa desenhar foto), mas esta fatia não desenha
// avatar, e transportar identificador que ninguém usa é superfície de
// vazamento sem contrapartida.
//
// ===========================================================================
// A DUPLA É ABSOLUTA NO FIO, E RELATIVA NA TELA
// ===========================================================================
//
// No servidor, `nos` são os assentos 0 e 2 e `eles` são o 1 e o 3 — sempre,
// independentemente de quem está lendo a visão. `placar.nos` NÃO quer dizer
// "o placar de quem está lendo".
//
// A tela anterior desenhava `'Nós ${placar['nos']} × ${placar['eles']} Eles'`,
// e para quem sentasse nos assentos 1 ou 3 isso mostrava o placar do
// adversário como se fosse o seu. [EstadoMesaOnline.minhaDupla] existe para
// fechar essa troca: a partir dela, [meusPontos] e [pontosAdversarios] são
// relativos a quem está sentado, e a tela nunca precisa saber a convenção do
// servidor.

/// As duas duplas, com os nomes que o servidor usa no fio.
enum Dupla {
  nos('nos'),
  eles('eles');

  const Dupla(this.noFio);

  /// A chave com que o servidor indexa `placar`, `jogosDupla` e `mortoPego`.
  final String noFio;

  static Dupla? talvezDe(Object? bruto) => switch (bruto) {
    'nos' => Dupla.nos,
    'eles' => Dupla.eles,
    _ => null,
  };

  /// A dupla de um assento. Espelha `duplaDoAssento` do servidor: pares são
  /// `nos`, ímpares são `eles`.
  static Dupla doAssento(int assento) =>
      assento.isEven ? Dupla.nos : Dupla.eles;

  Dupla get adversaria => this == Dupla.nos ? Dupla.eles : Dupla.nos;
}

/// Uma carta como o servidor a manda DENTRO da visão de assento.
class CartaOnline {
  const CartaOnline({
    required this.id,
    required this.naipe,
    required this.valor,
    required this.coringa,
  });

  /// Identificador do servidor. É ele que volta nos comandos `descartar`,
  /// `baixar` e `estender` — a tela nunca inventa id de carta.
  final String id;

  /// `copas` · `ouros` · `paus` · `espadas`, ou nulo no curinga impresso.
  final String? naipe;

  /// `A`..`K` ou `JOKER`.
  final String valor;

  final bool coringa;

  bool get ehVermelha => naipe == 'copas' || naipe == 'ouros';

  /// Lê uma carta crua, ou devolve nulo se ela não for uma carta.
  ///
  /// O campo do curinga é `eh_coringa`, com sublinhado: é o nome que
  /// `criarCarta` usa no servidor, e `visaoDoAssento` publica `suaMao`,
  /// `lixoTopo`, `lixoAberto` e `jogosDupla` CRUS. A forma `coringa`, sem
  /// sublinhado, é a de `cartaPublica` — usada na visão de quem assiste. As
  /// duas são do servidor, então as duas são aceitas aqui; inventar uma
  /// terceira não.
  static CartaOnline? talvezDe(Object? bruto) {
    if (bruto is! Map) return null;
    final id = bruto['id'];
    final valor = bruto['valor'];
    if (id is! String || id.isEmpty) return null;
    if (valor is! String || valor.isEmpty) return null;
    final naipe = bruto['naipe'];
    if (naipe != null && naipe is! String) return null;
    return CartaOnline(
      id: id,
      naipe: naipe as String?,
      valor: valor,
      coringa: bruto['eh_coringa'] == true || bruto['coringa'] == true,
    );
  }

  /// Uma lista de cartas, ou nulo se QUALQUER item não for carta.
  ///
  /// Tudo ou nada de propósito: descartar em silêncio a carta ilegível
  /// entregaria à tela uma mão com menos cartas do que a pessoa tem, e essa é
  /// uma mentira difícil de perceber olhando.
  static List<CartaOnline>? talvezLista(Object? bruto) {
    if (bruto is! List) return null;
    final saida = <CartaOnline>[];
    for (final item in bruto) {
      final c = talvezDe(item);
      if (c == null) return null;
      saida.add(c);
    }
    return saida;
  }

  @override
  bool operator ==(Object other) => other is CartaOnline && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'CartaOnline($id)';
}

/// Um assento visto de fora: o que é público sobre quem está sentado nele.
///
/// NÃO carrega cartas. Nem as do próprio leitor — a mão fica em
/// [EstadoMesaOnline.minhaMao], que existe uma vez só na mesa inteira.
class AssentoOnline {
  const AssentoOnline({
    required this.indice,
    required this.apelido,
    required this.ehBot,
    required this.dupla,
    required this.qtdCartas,
    required this.ehVoce,
  });

  final int indice;
  final String apelido;
  final bool ehBot;
  final Dupla dupla;

  /// Quantas cartas a pessoa tem na mão. É tudo o que se sabe da mão alheia.
  final int qtdCartas;

  final bool ehVoce;

  static AssentoOnline? talvezDe(Object? bruto, int indice) {
    if (bruto is! Map) return null;
    final apelido = bruto['apelido'];
    final qtd = bruto['qtdCartas'];
    if (apelido is! String) return null;
    if (qtd is! int || qtd < 0) return null;
    // A dupla vem do servidor quando declarada; na ausência, deriva do índice
    // pela MESMA regra (`duplaDoAssento`), que é aritmética do assento e não um
    // palpite sobre o estado da partida.
    final dupla = Dupla.talvezDe(bruto['dupla']) ?? Dupla.doAssento(indice);
    return AssentoOnline(
      indice: indice,
      apelido: apelido,
      ehBot: bruto['tipo'] == 'bot',
      dupla: dupla,
      qtdCartas: qtd,
      ehVoce: bruto['ehVoce'] == true,
    );
  }
}

/// O que a mesa permite FAZER neste instante.
///
/// Espelha `validarVez` do servidor, que é o mesmo portão para todas as
/// jogadas: partida ou rodada encerrada barram tudo; comprar exige a vez e não
/// ter comprado; baixar, estender e descartar exigem a vez e TER comprado.
///
/// Isto NÃO é a regra do Buraco reimplementada — é o que a tela precisa saber
/// para não oferecer um botão que o servidor recusaria. Quem julga a jogada
/// continua sendo o servidor, e uma capacidade aberta aqui não faz nenhuma
/// jogada valer.
class CapacidadesDaMesa {
  const CapacidadesDaMesa({
    required this.podeComprar,
    required this.podeBaixar,
    required this.podeDescartar,
    required this.conectado,
  });

  const CapacidadesDaMesa.nenhuma()
    : podeComprar = false,
      podeBaixar = false,
      podeDescartar = false,
      conectado = false;

  final bool podeComprar;

  /// Vale para `baixar` e para `estender` — o servidor cobra a mesma
  /// pré-condição dos dois.
  final bool podeBaixar;

  final bool podeDescartar;

  /// O transporte está autenticado. Sem isto tudo acima é falso: um comando
  /// enviado agora entraria numa fila e sairia num momento em que o estado já
  /// é outro.
  final bool conectado;
}

/// O estado de apresentação da mesa online. Somente leitura, e completo: se
/// existe uma instância disto, ela descreve uma mesa inteira.
class EstadoMesaOnline {
  const EstadoMesaOnline({
    required this.meuAssento,
    required this.modalidade,
    required this.metaPontos,
    required this.rodada,
    required this.placarPorDupla,
    required this.vez,
    required this.suaVez,
    required this.jaComprou,
    required this.minhaMao,
    required this.assentos,
    required this.monteQtd,
    required this.lixoQtd,
    required this.lixoTopo,
    required this.lixoAberto,
    required this.mortosQtd,
    required this.jogosPorDupla,
    required this.encerrada,
    required this.rodadaEncerrada,
    required this.duplaQueBateu,
    required this.pontosRodada,
    required this.precisaUsarTopo,
    required this.versaoEstado,
  });

  final int meuAssento;

  /// `aberto` · `fechado` · `sbtl`, como o servidor escreve.
  final String modalidade;

  /// Pontos que encerram a partida. Nulo quando a mesa não declarou meta.
  final int? metaPontos;

  final int rodada;

  /// O placar como o servidor o indexa — por dupla ABSOLUTA. A tela deve usar
  /// [meusPontos]/[pontosAdversarios], que já são relativos a quem lê.
  final Map<Dupla, int> placarPorDupla;

  final int vez;
  final bool suaVez;
  final bool jaComprou;

  /// A mão de quem está lendo. A única mão que existe nesta classe.
  final List<CartaOnline> minhaMao;

  /// Os quatro assentos, na ordem do servidor.
  final List<AssentoOnline> assentos;

  final int monteQtd;
  final int lixoQtd;

  /// Topo do lixo. Nulo com o lixo vazio.
  final CartaOnline? lixoTopo;

  /// O lixo inteiro. Só o ABERTO o publica; nas outras modalidades é nulo, e
  /// nulo aqui quer dizer "não é visível", nunca "está vazio".
  final List<CartaOnline>? lixoAberto;

  final int mortosQtd;

  /// Os jogos baixados de cada dupla. Públicos por contrato.
  final Map<Dupla, List<List<CartaOnline>>> jogosPorDupla;

  final bool encerrada;
  final bool rodadaEncerrada;

  /// Quem bateu. Preenchido só com a rodada encerrada.
  final Dupla? duplaQueBateu;

  /// O detalhamento da contagem da rodada, cru como o servidor manda.
  final Map<String, dynamic>? pontosRodada;

  /// Id da carta do topo que este assento é OBRIGADO a usar antes de descartar
  /// (FECHADO/SBTL, depois de comprar o lixo). Nulo sem pendência.
  ///
  /// A tela DESTACA essa carta; ela não bloqueia o descarte. A obrigação é
  /// regra do servidor, e é ele quem recusa — um bloqueio local aqui seria uma
  /// segunda opinião sobre a regra, e a errada travaria a pessoa sem recurso.
  final String? precisaUsarTopo;

  /// Ordem da visão, quando o servidor a declara.
  ///
  /// O servidor de `16a692b` NÃO manda este campo: a visão é um retrato
  /// completo, transmitido por um socket que já entrega em ordem. O campo é
  /// lido quando existe e vale nulo quando não existe — o que NÃO se faz aqui
  /// é preencher a ausência com um número de fabricação própria, que passaria
  /// a parecer autoridade do servidor.
  ///
  /// Quem usa isto é [EstadoMesaOnline.substitui].
  final int? versaoEstado;

  Dupla get minhaDupla => Dupla.doAssento(meuAssento);

  int get meusPontos => placarPorDupla[minhaDupla] ?? 0;
  int get pontosAdversarios => placarPorDupla[minhaDupla.adversaria] ?? 0;

  List<List<CartaOnline>> get meusJogos =>
      jogosPorDupla[minhaDupla] ?? const [];
  List<List<CartaOnline>> get jogosAdversarios =>
      jogosPorDupla[minhaDupla.adversaria] ?? const [];

  AssentoOnline get meuAssentoDados => assentos[meuAssento];

  /// Quem está com a vez, para a tela dizer o nome.
  AssentoOnline? get assentoDaVez =>
      vez >= 0 && vez < assentos.length ? assentos[vez] : null;

  bool get euBati => duplaQueBateu == minhaDupla;

  CapacidadesDaMesa capacidades({required bool conectado}) {
    final ativa = !encerrada && !rodadaEncerrada && suaVez && conectado;
    return CapacidadesDaMesa(
      podeComprar: ativa && !jaComprou,
      podeBaixar: ativa && jaComprou,
      podeDescartar: ativa && jaComprou,
      conectado: conectado,
    );
  }

  /// Este estado pode substituir [anterior]?
  ///
  /// Com versão declarada dos dois lados, só avança: versão menor é retomada
  /// atrasada e não pode desfazer o que já se mostrou. Versão IGUAL passa —
  /// é o reenvio do mesmo retrato, e recusá-lo faria a tela ignorar uma
  /// retransmissão legítima depois de reconectar.
  ///
  /// Sem versão declarada (o caso de hoje), a ordem é a do socket, e o retrato
  /// mais novo é simplesmente o último que chegou.
  bool substitui(EstadoMesaOnline? anterior) {
    if (anterior == null) return true;
    final minha = versaoEstado;
    final dela = anterior.versaoEstado;
    if (minha == null || dela == null) return true;
    return minha >= dela;
  }
}

// ===========================================================================
// A leitura
// ===========================================================================

/// O que uma visão crua pode ser depois de lida.
sealed class LeituraDaVisao {
  const LeituraDaVisao();
}

/// A mesa ainda está no lobby, aguardando jogadores.
class VisaoDeLobby extends LeituraDaVisao {
  const VisaoDeLobby();
}

/// A partida está em andamento e o estado é este.
class VisaoDeJogo extends LeituraDaVisao {
  const VisaoDeJogo(this.estado);
  final EstadoMesaOnline estado;
}

/// A visão não descreve uma mesa que se possa desenhar.
///
/// [motivo] é para a pessoa ler; [campo] é para o teste e para o diagnóstico
/// apontar onde a leitura parou. Nenhum dos dois carrega conteúdo da visão —
/// citar o valor recebido colocaria carta e identificador em texto de tela.
class VisaoRecusada extends LeituraDaVisao {
  const VisaoRecusada(this.motivo, {required this.campo});
  final String motivo;
  final String campo;
}

/// Lê a visão do servidor. É a ÚNICA porta de entrada de estado online na
/// apresentação — nenhuma tela lê o mapa cru por conta própria.
abstract final class AdaptadorVisaoOnline {
  /// [visao] é o mapa que veio em `{tipo:'estado', visao:{...}}`.
  ///
  /// [assentoDaConexao] é o assento que o servidor atribuiu a ESTA conexão, na
  /// mensagem `entrou`. Ele é conferido contra o `voceAssento` da visão: se os
  /// dois discordarem, a visão é de outra pessoa (ou de uma mesa anterior) e é
  /// recusada. É a checagem mais importante do arquivo — sem ela, uma visão
  /// fora de contexto seria desenhada como se fosse a mão de quem está olhando.
  static LeituraDaVisao ler(
    Map<String, dynamic>? visao, {
    required int? assentoDaConexao,
  }) {
    if (visao == null) {
      return const VisaoRecusada(
        'ainda não recebi o estado da mesa',
        campo: 'visao',
      );
    }
    if (visao['lobby'] == true) return const VisaoDeLobby();
    if (visao['erro'] != null) {
      return const VisaoRecusada(
        'o servidor não encontrou esta mesa',
        campo: 'erro',
      );
    }

    final meuAssento = visao['voceAssento'];
    if (meuAssento is! int || meuAssento < 0) {
      return const VisaoRecusada(
        'o servidor não disse em que lugar você está sentado',
        campo: 'voceAssento',
      );
    }
    if (assentoDaConexao != null && assentoDaConexao != meuAssento) {
      return const VisaoRecusada(
        'este estado é de outro lugar na mesa',
        campo: 'voceAssento',
      );
    }

    final assentosBrutos = visao['assentos'];
    if (assentosBrutos is! List || assentosBrutos.isEmpty) {
      return const VisaoRecusada(
        'o servidor não descreveu os lugares da mesa',
        campo: 'assentos',
      );
    }
    final assentos = <AssentoOnline>[];
    for (var i = 0; i < assentosBrutos.length; i++) {
      final a = AssentoOnline.talvezDe(assentosBrutos[i], i);
      if (a == null) {
        return const VisaoRecusada(
          'um dos lugares da mesa veio incompleto',
          campo: 'assentos',
        );
      }
      assentos.add(a);
    }
    if (meuAssento >= assentos.length) {
      return const VisaoRecusada(
        'seu lugar não existe nesta mesa',
        campo: 'voceAssento',
      );
    }

    final mao = CartaOnline.talvezLista(visao['suaMao']);
    if (mao == null) {
      return const VisaoRecusada(
        'não consegui ler a sua mão',
        campo: 'suaMao',
      );
    }

    final modalidade = visao['modalidade'];
    if (modalidade is! String || modalidade.isEmpty) {
      return const VisaoRecusada(
        'o servidor não disse a modalidade da mesa',
        campo: 'modalidade',
      );
    }

    final rodada = visao['rodada'];
    if (rodada is! int) {
      return const VisaoRecusada(
        'o servidor não disse em que rodada a mesa está',
        campo: 'rodada',
      );
    }

    final placar = _placar(visao['placar']);
    if (placar == null) {
      return const VisaoRecusada('não consegui ler o placar', campo: 'placar');
    }

    final vez = visao['vez'];
    if (vez is! int) {
      return const VisaoRecusada(
        'o servidor não disse de quem é a vez',
        campo: 'vez',
      );
    }

    final monteQtd = _contagem(visao['monteQtd']);
    final lixoQtd = _contagem(visao['lixoQtd']);
    final mortosQtd = _contagem(visao['mortosQtd']);
    if (monteQtd == null) {
      return const VisaoRecusada(
        'não consegui ler o monte',
        campo: 'monteQtd',
      );
    }
    if (lixoQtd == null) {
      return const VisaoRecusada('não consegui ler o lixo', campo: 'lixoQtd');
    }
    if (mortosQtd == null) {
      return const VisaoRecusada(
        'não consegui ler os mortos',
        campo: 'mortosQtd',
      );
    }

    final jogos = _jogos(visao['jogosDupla']);
    if (jogos == null) {
      return const VisaoRecusada(
        'não consegui ler os jogos baixados',
        campo: 'jogosDupla',
      );
    }

    // NULOS POR CONTRATO. Ausente e explicitamente nulo valem o mesmo — o que
    // não vale é um valor presente e ilegível, que seria informação perdida em
    // silêncio.
    final topoBruto = visao['lixoTopo'];
    final CartaOnline? lixoTopo;
    if (topoBruto == null) {
      lixoTopo = null;
    } else {
      lixoTopo = CartaOnline.talvezDe(topoBruto);
      if (lixoTopo == null) {
        return const VisaoRecusada(
          'não consegui ler o topo do lixo',
          campo: 'lixoTopo',
        );
      }
    }

    final abertoBruto = visao['lixoAberto'];
    final List<CartaOnline>? lixoAberto;
    if (abertoBruto == null) {
      lixoAberto = null;
    } else {
      lixoAberto = CartaOnline.talvezLista(abertoBruto);
      if (lixoAberto == null) {
        return const VisaoRecusada(
          'não consegui ler o lixo aberto',
          campo: 'lixoAberto',
        );
      }
    }

    final meta = visao['metaPontos'];
    final versao = visao['versaoEstado'];
    final topoObrigatorio = visao['precisaUsarTopo'];
    final pontos = visao['pontosRodada'];

    return VisaoDeJogo(
      EstadoMesaOnline(
        meuAssento: meuAssento,
        modalidade: modalidade,
        metaPontos: meta is int ? meta : null,
        rodada: rodada,
        placarPorDupla: placar,
        vez: vez,
        suaVez: visao['suaVez'] == true,
        jaComprou: visao['jaComprou'] == true,
        minhaMao: mao,
        assentos: assentos,
        monteQtd: monteQtd,
        lixoQtd: lixoQtd,
        lixoTopo: lixoTopo,
        lixoAberto: lixoAberto,
        mortosQtd: mortosQtd,
        jogosPorDupla: jogos,
        encerrada: visao['encerrada'] == true,
        rodadaEncerrada: visao['rodadaEncerrada'] == true,
        duplaQueBateu: Dupla.talvezDe(visao['duplaQueBateu']),
        pontosRodada: pontos is Map
            ? pontos.cast<String, dynamic>()
            : null,
        precisaUsarTopo: topoObrigatorio is String && topoObrigatorio.isNotEmpty
            ? topoObrigatorio
            : null,
        versaoEstado: versao is int ? versao : null,
      ),
    );
  }

  static int? _contagem(Object? bruto) =>
      bruto is int && bruto >= 0 ? bruto : null;

  static Map<Dupla, int>? _placar(Object? bruto) {
    if (bruto is! Map) return null;
    final saida = <Dupla, int>{};
    for (final d in Dupla.values) {
      final v = bruto[d.noFio];
      if (v is! int) return null;
      saida[d] = v;
    }
    return saida;
  }

  static Map<Dupla, List<List<CartaOnline>>>? _jogos(Object? bruto) {
    if (bruto is! Map) return null;
    final saida = <Dupla, List<List<CartaOnline>>>{};
    for (final d in Dupla.values) {
      final lista = bruto[d.noFio];
      if (lista is! List) return null;
      final jogos = <List<CartaOnline>>[];
      for (final jogo in lista) {
        final cartas = CartaOnline.talvezLista(jogo);
        if (cartas == null) return null;
        jogos.add(cartas);
      }
      saida[d] = jogos;
    }
    return saida;
  }
}
