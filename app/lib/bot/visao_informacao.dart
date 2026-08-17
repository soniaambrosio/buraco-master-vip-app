// OS — INTELIGÊNCIA ESTRATÉGICA DO BOT V1 — §7 INFORMAÇÃO JUSTA.
//
// `VisaoInformacao` é a InformationView MASCARADA: a ÚNICA porta pela qual a
// camada estratégica enxerga a mesa. O mascaramento é ESTRUTURAL, não uma
// promessa: as mãos alheias, o conteúdo do monte e o conteúdo dos mortos
// simplesmente não têm campo aqui. Não existe getter para eles, então nenhum
// avaliador futuro consegue lê-los por descuido.
//
// O que o assento PODE conhecer, e portanto entra:
//   • a própria mão;
//   • os jogos JÁ BAIXADOS das duas duplas (públicos);
//   • o TOPO visível do lixo e o TAMANHO do lixo;
//   • o TAMANHO da mão de cada assento (contagem é informação pública);
//   • tamanho do monte, quantos mortos restam, quem já pegou morto;
//   • quem já abriu, rodadas de vulnerabilidade, vez, fase, modalidade, meta;
//   • os descartes PÚBLICOS da mão, com AUTORIA (OS 2 — ver abaixo).
//
// O que NÃO entra, em hipótese alguma:
//   • mão do parceiro e dos adversários (só a contagem);
//   • monte e mortos;
//   • qualquer estado oculto que o servidor tenha por conveniência técnica.
//
// LIXO ENTERRADO — mudança HONESTA de fronteira (OS PROVENIÊNCIA V1).
// Até `89fca38` esta visão mascarava as cartas enterradas do lixo, e a lista de
// descartes públicos era uma entrada opcional que ninguém preenchia. A OS 2
// mudou isso: `descartesPublicos` traz agora a MEMÓRIA da mão — cada carta que
// foi ao lixo e quem a pôs lá.
//
// Isso NÃO é informação privada: o lixo recebe carta por um único caminho, o
// descarte, e todo descarte fica visível no TOPO da pilha no instante em que
// acontece — em qualquer modalidade. Quem está na mesa viu. A visão passa a
// lembrar o que a mesa mostrou, e nada além disso:
//   • limitada à MÃO corrente (a distribuição zera o livro) — memória de mesa,
//     não memória perfeita e ilimitada;
//   • idêntica para todos os assentos e para quem assiste — ninguém recebe uma
//     verdade pública diferente da do vizinho;
//   • sem nenhuma carta que não tenha sido publicamente descartada: o monte, os
//     mortos e as mãos continuam sem campo.
//
// A consequência estratégica está registrada e é deliberada: depois de alguém
// comprar o lixo, o livro continua dizendo quais cartas passaram por ele. É a
// mesma dedução que um humano com boa memória faz na mesa real.
//
// MÃO OCULTA: quando um plano do bot resulta em PEGAR O MORTO, as 11 cartas
// novas são conhecidas só DEPOIS de a autoridade aplicar. Avaliar o plano lendo
// essas cartas seria ler o futuro do baralho. Por isso a projeção pós-morto vem
// com `maoOculta = true` e a lista `mao` VAZIA: o avaliador pontua "pegou o
// morto" pelo evento, jamais pelo conteúdo.
import '../rules/estado.dart';
import '../rules/modalidade.dart';

/// Chave da dupla do assento ('nos' para 0/2, 'eles' para 1/3).
String duplaDoAssento(int assento) => assento % 2 == 0 ? 'nos' : 'eles';

/// A outra dupla.
String duplaOposta(String dupla) => dupla == 'nos' ? 'eles' : 'nos';

/// Um descarte PÚBLICO já observado (quem descartou + a carta que foi ao lixo).
///
/// OS PROVENIÊNCIA DE DESCARTES V1: deixou de ser entrada opcional. A autoridade
/// registra a autoria no instante do descarte (`EstadoJogo.descartes`), e esta
/// é a PROJEÇÃO desse registro — o tipo da visão, distinto do tipo da
/// autoridade, porque projetar é filtrar, não apelidar.
///
/// A visão não tem construtor que aceite autoria vinda de fora: o único
/// caminho é `VisaoInformacao.doEstado`, que copia o que a autoridade gravou.
/// Sem registro na autoridade, não há entrada aqui — e a ausência significa
/// autor DESCONHECIDO, jamais um autor deduzido da posição na pilha.
class DescartePublico {
  final int assento;
  final CartaSnapshot carta;

  /// Ordem temporal dentro da MÃO (a mesma da autoridade).
  final int ordem;

  const DescartePublico(this.assento, this.carta, this.ordem);
}

/// Visão mascarada da mesa, do ponto de vista de UM assento.
class VisaoInformacao {
  final Modalidade modalidade;
  final int metaPontos;

  /// Assento observador (dono desta visão).
  final int assento;
  final int vez;
  final FaseTurno fase;
  final bool rodadaEncerrada;
  final String? duplaQueBateu;

  /// Mão PRÓPRIA. Vazia quando `maoOculta` — ver cabeçalho.
  final List<CartaSnapshot> mao;
  final bool maoOculta;

  /// Tamanho da mão própria (válido mesmo com `maoOculta`).
  final int tamanhoMao;

  /// Tamanho da mão de CADA assento (0..3). Contagem é informação pública.
  final List<int> tamanhosMao;

  /// Jogos já baixados da PRÓPRIA dupla (públicos).
  final List<List<CartaSnapshot>> meldsProprios;

  /// Jogos já baixados da dupla ADVERSÁRIA (públicos).
  final List<List<CartaSnapshot>> meldsAdversarios;

  /// TOPO visível do lixo (null se vazio). As cartas enterradas não existem aqui.
  final CartaSnapshot? lixoTopo;
  final int lixoTamanho;

  final int monteTamanho;
  final int mortosDisponiveis;

  final bool mortoPegoPropria;
  final bool mortoPegoAdversaria;
  final bool abriuPropria;
  final bool abriuAdversaria;
  final int rodadasVulneravelPropria;
  final int rodadasVulneravelAdversaria;

  /// Descartes PÚBLICOS da mão corrente, com autoria e ordem, como a autoridade
  /// os registrou. Vazio quando a autoridade não tem registro (mão recém
  /// distribuída, lixo montado por fixture, snapshot anterior à OS 2).
  final List<DescartePublico> descartesPublicos;

  const VisaoInformacao({
    required this.modalidade,
    required this.metaPontos,
    required this.assento,
    required this.vez,
    required this.fase,
    required this.rodadaEncerrada,
    required this.duplaQueBateu,
    required this.mao,
    required this.maoOculta,
    required this.tamanhoMao,
    required this.tamanhosMao,
    required this.meldsProprios,
    required this.meldsAdversarios,
    required this.lixoTopo,
    required this.lixoTamanho,
    required this.monteTamanho,
    required this.mortosDisponiveis,
    required this.mortoPegoPropria,
    required this.mortoPegoAdversaria,
    required this.abriuPropria,
    required this.abriuAdversaria,
    required this.rodadasVulneravelPropria,
    required this.rodadasVulneravelAdversaria,
    this.descartesPublicos = const <DescartePublico>[],
  });

  /// MASCARA um `EstadoJogo` canônico para o `assento`.
  ///
  /// Este é o único construtor de produção, e é aqui que a informação oculta
  /// morre: nada além da mão própria, dos jogos públicos, do topo do lixo e das
  /// CONTAGENS atravessa. `pegouMortoNesteLance` faz a mão nascer oculta.
  factory VisaoInformacao.doEstado(
    EstadoJogo estado,
    int assento, {
    bool maoOculta = false,
  }) {
    final propria = duplaDoAssento(assento);
    final adversaria = duplaOposta(propria);
    final mao = estado.maos[assento];
    return VisaoInformacao(
      modalidade: estado.modalidade,
      metaPontos: estado.metaPontos,
      assento: assento,
      vez: estado.vez,
      fase: estado.fase,
      rodadaEncerrada: estado.rodadaEncerrada,
      duplaQueBateu: estado.duplaQueBateu,
      mao: maoOculta
          ? const <CartaSnapshot>[]
          : [for (final c in mao) c.copia()],
      maoOculta: maoOculta,
      tamanhoMao: mao.length,
      // Só o TAMANHO das mãos alheias atravessa — nunca as cartas.
      tamanhosMao: [for (final m in estado.maos) m.length],
      meldsProprios: [
        for (final m in estado.jogosDupla[propria] ?? const [])
          [for (final c in m) c.copia()]
      ],
      meldsAdversarios: [
        for (final m in estado.jogosDupla[adversaria] ?? const [])
          [for (final c in m) c.copia()]
      ],
      // Só o TOPO. As cartas enterradas do lixo ficam de fora até a autorização
      // da compra — a mesma disciplina que `avaliarComprarLixo` já aplica.
      lixoTopo: estado.lixo.isEmpty ? null : estado.lixo.last.copia(),
      lixoTamanho: estado.lixo.length,
      // Só o TAMANHO do monte — o conteúdo é o futuro do baralho.
      monteTamanho: estado.monte.length,
      mortosDisponiveis: estado.mortos.length,
      mortoPegoPropria: estado.mortoPego[propria] ?? false,
      mortoPegoAdversaria: estado.mortoPego[adversaria] ?? false,
      abriuPropria: estado.primeiraBaixadaFeita[propria] ?? false,
      abriuAdversaria: estado.primeiraBaixadaFeita[adversaria] ?? false,
      rodadasVulneravelPropria: estado.rodadasVulneravel[propria] ?? 0,
      rodadasVulneravelAdversaria: estado.rodadasVulneravel[adversaria] ?? 0,
      // PROVENIÊNCIA: cópia fiel do livro da autoridade, IGUAL para todos os
      // assentos — o mesmo fato público que qualquer um na mesa observou no
      // instante do descarte. A visão não decide quem é parceiro nem quem é
      // adversário: entrega "quem descartou o quê" e deixa a relação com o
      // observador para o consumidor (§10/§11).
      descartesPublicos: [
        for (final d in estado.descartes)
          DescartePublico(d.assento, d.carta.copia(), d.ordem)
      ],
    );
  }

  String get dupla => duplaDoAssento(assento);
  String get duplaAdversaria => duplaOposta(dupla);

  /// Assento do PARCEIRO (informação pública: a mesa é fixa).
  int get parceiro => (assento + 2) % 4;

  /// Assentos adversários.
  List<int> get adversarios => [(assento + 1) % 4, (assento + 3) % 4];

  /// Cartas na mão do parceiro — CONTAGEM, que é pública.
  int get cartasDoParceiro => tamanhosMao[parceiro];

  /// Menor mão adversária (proxy público de "está perto de bater").
  int get menorMaoAdversaria =>
      adversarios.map((a) => tamanhosMao[a]).reduce((x, y) => x < y ? x : y);

  /// Ainda há morto para a PRÓPRIA dupla pegar?
  bool get mortoDisponivelParaDupla => !mortoPegoPropria && mortosDisponiveis > 0;

  /// Assinatura estável do que é PÚBLICO nesta visão (sem a mão própria).
  /// Serve ao teste de informação justa: dois estados com o mesmo público têm a
  /// mesma assinatura, por mais que difiram no oculto.
  String assinaturaPublica() {
    String zona(List<CartaSnapshot> l) => l.map((c) => c.chave).join(',');
    String matriz(List<List<CartaSnapshot>> m) => m.map(zona).join(' | ');
    return [
      'mod=${modalidade.texto} meta=$metaPontos assento=$assento vez=$vez',
      'fase=${fase.name} fim=$rodadaEncerrada bateu=$duplaQueBateu',
      'tam=$tamanhosMao lixoTopo=${lixoTopo?.chave} lixoN=$lixoTamanho',
      'monteN=$monteTamanho mortosN=$mortosDisponiveis',
      'mp=$mortoPegoPropria/$mortoPegoAdversaria',
      'ab=$abriuPropria/$abriuAdversaria',
      'rv=$rodadasVulneravelPropria/$rodadasVulneravelAdversaria',
      'nos=${matriz(meldsProprios)}',
      'eles=${matriz(meldsAdversarios)}',
      // A proveniência é PÚBLICA, logo entra na assinatura pública: dois
      // estados que diferem só em quem descartou o quê são estados públicos
      // diferentes, e o teste de informação justa precisa enxergar isso.
      'desc=${descartesPublicos.map((d) => '${d.ordem}@${d.assento}:'
          '${d.carta.chave}').join(',')}',
    ].join('\n');
  }
}
