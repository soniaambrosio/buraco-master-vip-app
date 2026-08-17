// ordem_da_visao.dart — quem decide se uma visão do servidor ainda vale.
//
// ===========================================================================
// O PROBLEMA QUE ISTO RESOLVE
// ===========================================================================
//
// Até aqui, toda mensagem `{tipo:'estado'}` que chegava pelo fio substituía o
// estado da mesa. Num socket que entrega em ordem isso quase sempre acerta — e
// "quase sempre" é o tamanho do problema: reenvio, reconexão e corrida entre
// conexões produzem visões que chegam DEPOIS de outras mais novas. Aplicadas,
// elas desfazem na tela o que já tinha acontecido: a carta volta para a mão, o
// placar regride, a vez muda de dono. Para quem olha, é o aplicativo errando —
// não a rede.
//
// O servidor (`buraco-servidor`, ref `claude/versionamento-visao-autoritativa-v1`,
// SHA 7e7572b3471bcec2a6968e6084f56dd407cef601) passou a carimbar cada emissão
// com um par que permite ordenar e deduplicar. Este arquivo é o consumidor
// desse par, e é a ÚNICA autoridade de ordem do cliente.
//
// ===========================================================================
// O CONTRATO — E ONDE OS CAMPOS MORAM
// ===========================================================================
//
//   {tipo:'estado', visao:{…}, versaoEstado: 7, eventoId: "…"}
//
// `versaoEstado` e `eventoId` são IRMÃOS de `visao`, não filhos. A razão é do
// servidor e está registrada lá: `visao` é o recorte que o papel autoriza, e a
// versão é da mesa inteira, igual para todos os papéis. Dentro da visão, o par
// passaria pela lista de permissão do espectador e sumiria justamente para quem
// mais precisa dele.
//
// A consequência aqui é direta: um `versaoEstado` encontrado DENTRO de `visao`
// não é o carimbo do servidor e não tem autoridade de ordem nenhuma.
//
//   versaoEstado  inteiro monotônico da sala. Só cresce, nunca reinicia — nem
//                 na revanche. É da SALA: outra sala tem contador próprio, e o
//                 dela pode ser numericamente menor.
//   eventoId      UUID sorteado. Opaco: não é derivado da versão, da partida
//                 nem do estado, e não se lê nada de dentro dele. É re-sorteado
//                 quando a versão avança, e REAPROVEITADO no reenvio.
//   (0, null)     "não há estado autoritativo" — mesa que o servidor não
//                 encontrou. Mesa viva nunca emite zero: o primeiro carimbo já
//                 entrega 1.
//
// ===========================================================================
// COLISÃO NOMINAL — versaoEstado NÃO É versaoEstadoFinal
// ===========================================================================
//
// `versaoEstadoFinal`, no envelope de encerramento, é OUTRO número: ele já
// existia antes deste contrato, vale `jogo.rodada` e conta rodadas. O nome
// colide, o significado não.
//
// Nada neste arquivo lê, compara ou mapeia `versaoEstadoFinal`, e é proibido
// passar a fazê-lo: ordenar snapshots por número de rodada faria a mesa
// descartar toda emissão que não virasse a rodada — isto é, quase todas. Há
// teste fixando a distinção.
//
// ===========================================================================
// DOIS LIVROS, DUAS VIDAS
// ===========================================================================
//
// Esta classe guarda DOIS registros, e a diferença de escopo entre eles é o
// miolo do arquivo:
//
//   MARCADOR DE ORDEM (versão + eventoId aceitos)
//     Vive junto com a PROJEÇÃO. Ele descreve o retrato que está na mão agora;
//     descartado o retrato, ele não descreve mais nada e tem de morrer junto.
//     É por isso que [reiniciarProjecao] existe e é chamado de
//     `_limparProjecao`: numa reconexão o servidor reenvia a versão VIGENTE (a
//     reconexão não muta a sala, então não gera versão nova), e um marcador
//     sobrevivente trataria esse reenvio como duplicata — deixando a mesa em
//     branco até a jogada seguinte.
//
//   LIVRO DOS EFEITOS TERMINAIS ([LivroDeEfeitosTerminais])
//     Vive junto com a MESA. Ele NÃO pode morrer na reconexão, e pelo motivo
//     exatamente inverso: o reenvio pós-reconexão traz o mesmo encerramento de
//     novo, e um livro zerado dispararia o diálogo, a navegação e o som pela
//     segunda vez. Só [reiniciarMesa] o apaga — sair da mesa, ou a sessão virar.
//
// Escopo trocado entre os dois é o defeito que a matriz de testes persegue: com
// o marcador vivo demais, a mesa congela na reconexão; com o livro curto
// demais, o encerramento acontece duas vezes.
//
// O QUE O LIVRO ANOTA MUDOU, E É A ENTREGA DESTA OS. Ele já foi um conjunto de
// `eventoId` DESPACHADOS, anotados no recebimento — e recebimento não é
// apresentação: um fim que chegasse sem consumidor de interface montado era
// anotado como resolvido sem que ninguém o visse. Hoje o livro guarda o ciclo
// de vida inteiro (pendente → reivindicado → apresentado), e quem o descreve é
// `livro_de_efeitos_terminais.dart`. Este arquivo continua sendo quem decide o
// que É um encerramento; não é mais quem decide que ele acabou.
//
// NADA AQUI É PERSISTIDO. O par vive em memória, com a conexão — igual ao
// servidor, que perde a sala inteira se o processo reiniciar. Uma versão
// guardada em disco descreveria uma sala que já não existe.

import 'livro_de_efeitos_terminais.dart';

export 'livro_de_efeitos_terminais.dart'
    show
        EncerramentoAutoritativo,
        EstadoDoEfeito,
        LivroDeEfeitosTerminais,
        PosseDoEfeito;

/// O que uma emissão pode carregar de metadados, depois de lida.
sealed class MetadadosDaVisao {
  const MetadadosDaVisao();
}

/// O par veio completo e bem-formado.
final class VisaoVersionada extends MetadadosDaVisao {
  const VisaoVersionada(this.versaoEstado, this.eventoId);

  /// Inteiro monotônico da SALA. Sempre >= 1 aqui: zero é
  /// [VisaoSemEstadoAutoritativo].
  final int versaoEstado;

  /// Identificador opaco da emissão. Não se lê nada de dentro dele.
  final String eventoId;
}

/// Nenhum dos dois campos veio — envelope de servidor anterior ao carimbo.
final class VisaoSemCarimbo extends MetadadosDaVisao {
  const VisaoSemCarimbo();
}

/// O par `(0, null)` que o servidor emite para "esta mesa não tem estado
/// autoritativo". Não é a primeira versão e não é estado.
final class VisaoSemEstadoAutoritativo extends MetadadosDaVisao {
  const VisaoSemEstadoAutoritativo();
}

/// Os campos vieram, mas não descrevem um carimbo: tipo errado, versão
/// negativa, ou um dos dois sozinho.
///
/// [campo] é para o teste e o diagnóstico. Não carrega o valor recebido.
final class VisaoComCarimboIlegivel extends MetadadosDaVisao {
  const VisaoComCarimboIlegivel(this.campo);
  final String campo;
}

/// O que fazer com a emissão que acabou de chegar.
enum CondutaDaVisao {
  /// Retrato novo (ou o primeiro desta projeção): aplicar.
  aceitar,

  /// Mesma versão, mesmo `eventoId`. É o reenvio do retrato que já está na
  /// mão — reaplicar não mudaria nada e só custaria uma reconstrução da tela.
  duplicada,

  /// Versão menor que a última aceita. Retomada atrasada: descartar inteira.
  atrasada,

  /// Mesma versão, `eventoId` diferente. Duas emissões distintas dizendo ser o
  /// mesmo estado — o contrato do servidor não permite isso, e adivinhar qual
  /// das duas vale seria inventar autoridade. Não substitui o estado.
  inconsistente,

  /// Metadados presentes e ilegíveis. Descartada sem tocar no marcador.
  ilegivel,

  /// `(0, null)`: o servidor disse que não há estado autoritativo.
  semEstadoAutoritativo,

  /// Envelope sem carimbo DEPOIS de esta projeção já ter aceitado um
  /// versionado. Aceitá-lo seria abrir mão da ordem que já se tinha.
  legadaTardia,
}

/// A decisão sobre uma emissão, com o carimbo que a produziu.
class DecisaoDaVisao {
  const DecisaoDaVisao._(this.conduta, {this.versaoEstado, this.eventoId});

  final CondutaDaVisao conduta;

  /// Nulos no modo legado e em toda conduta de descarte — o carimbo ou não
  /// existia, ou não era legível. Nunca fabricados.
  final int? versaoEstado;
  final String? eventoId;

  /// O snapshot deve ser aplicado ao estado canônico?
  bool get aplicaSnapshot => conduta == CondutaDaVisao.aceitar;

  /// Esta emissão fala pelo servidor sobre o estado ATUAL?
  ///
  /// Verdadeiro também na duplicata, e é aí que está o ponto: uma duplicata não
  /// muda o estado, mas continua sendo o servidor afirmando o mesmo desfecho.
  /// Descartá-la inteira — em vez de só não reaplicar o snapshot — engoliria um
  /// evento terminal que talvez ainda não tenha sido despachado.
  bool get temAutoridade =>
      conduta == CondutaDaVisao.aceitar || conduta == CondutaDaVisao.duplicada;
}

/// O marcador de ordem de uma conexão. Ver o cabeçalho do arquivo.
///
/// Não é `ChangeNotifier` e não avisa ninguém: ele responde perguntas, e quem
/// muda estado é o dono dele.
class OrdemDaVisao {
  // ---- Marcador de ordem: vive com a PROJEÇÃO -----------------------------

  int? _versaoAceita;
  String? _eventoAceito;

  /// Esta projeção já aceitou uma visão carimbada? Depois disso, envelope sem
  /// carimbo não entra mais (ver §5 da OS e [CondutaDaVisao.legadaTardia]).
  bool _jaAceitouVersionada = false;

  // ---- Livro dos efeitos terminais: vive com a MESA ----------------------

  /// O ciclo de vida dos avisos de fim desta mesa.
  ///
  /// PÚBLICO de propósito: quem apresenta o efeito precisa reivindicá-lo e
  /// confirmá-lo, e essas duas coisas acontecem fora daqui — a apresentação é
  /// da interface, e esta classe não sabe o que é diálogo. O que ela não
  /// delega é a pergunta de ordem: só ela decide o que é um encerramento, e o
  /// livro só é escrito por [talvezEncerramento].
  final LivroDeEfeitosTerminais efeitos = LivroDeEfeitosTerminais();

  /// A última versão aceita, ou nulo. Diagnóstico e teste.
  int? get versaoAceita => _versaoAceita;

  /// O `eventoId` da última visão aceita, ou nulo. Diagnóstico e teste.
  String? get eventoAceito => _eventoAceito;

  /// O retrato foi descartado: a mesa vai receber um novo do servidor.
  ///
  /// Apaga SÓ o marcador de ordem. O livro dos efeitos terminais sobrevive —
  /// ver o cabeçalho.
  void reiniciarProjecao() {
    _versaoAceita = null;
    _eventoAceito = null;
    _jaAceitouVersionada = false;
  }

  /// A mesa acabou para esta pessoa: ela saiu, ou a sessão virou.
  ///
  /// Aqui o livro dos efeitos também zera — a próxima mesa é outra partida, com
  /// contador próprio, e um encerramento dela não pode ser confundido com este.
  void reiniciarMesa() {
    reiniciarProjecao();
    efeitos.limpar();
  }

  /// Lê o carimbo de [envelope] — a mensagem INTEIRA, não a `visao`.
  ///
  /// Os campos são irmãos de `visao`; procurá-los dentro dela não acharia nada,
  /// e achar alguma coisa lá seria pior do que não achar.
  static MetadadosDaVisao lerCarimbo(Map<String, dynamic> envelope) {
    final versao = envelope['versaoEstado'];
    final evento = envelope['eventoId'];

    if (versao == null && evento == null) return const VisaoSemCarimbo();

    if (versao is! int || versao < 0) {
      return const VisaoComCarimboIlegivel('versaoEstado');
    }
    // `(0, null)` é o contrato do servidor para "não há estado autoritativo".
    // Zero com um `eventoId` junto não é previsto por contrato nenhum.
    if (versao == 0) {
      return evento == null
          ? const VisaoSemEstadoAutoritativo()
          : const VisaoComCarimboIlegivel('versaoEstado');
    }
    if (evento is! String || evento.isEmpty) {
      return const VisaoComCarimboIlegivel('eventoId');
    }
    return VisaoVersionada(versao, evento);
  }

  /// Decide o que fazer com [envelope], e COMPROMETE o marcador quando aceita.
  ///
  /// Comprometer aqui, e não no chamador, é de propósito: o marcador avança
  /// exatamente quando o estado avança, e não existe caminho em que um dos dois
  /// ande sem o outro.
  ///
  /// Nenhuma conduta de descarte toca o marcador. Uma visão atrasada não pode
  /// mover o relógio para trás, e uma mensagem ilegível não pode movê-lo para
  /// lugar nenhum.
  DecisaoDaVisao avaliar(Map<String, dynamic> envelope) {
    final carimbo = lerCarimbo(envelope);

    switch (carimbo) {
      case VisaoComCarimboIlegivel():
        return const DecisaoDaVisao._(CondutaDaVisao.ilegivel);

      case VisaoSemEstadoAutoritativo():
        return const DecisaoDaVisao._(CondutaDaVisao.semEstadoAutoritativo);

      case VisaoSemCarimbo():
        // MODO LEGADO. Aceito só enquanto esta projeção nunca viu carimbo: um
        // servidor que carimba não deixa de carimbar no meio da partida, então
        // uma visão sem carimbo depois de uma carimbada é anomalia, não
        // compatibilidade. Sem número, o marcador não avança — não há o que
        // avançar, e fabricar um seria dar cara de autoridade a um palpite.
        if (_jaAceitouVersionada) {
          return const DecisaoDaVisao._(CondutaDaVisao.legadaTardia);
        }
        return const DecisaoDaVisao._(CondutaDaVisao.aceitar);

      case VisaoVersionada(:final versaoEstado, :final eventoId):
        final ultima = _versaoAceita;

        // PRIMEIRA CARIMBADA DESTA PROJEÇÃO. Entra qualquer que seja o número —
        // e tem de entrar: outra sala tem contador próprio, e o dela pode ser
        // menor que o da anterior.
        if (ultima == null) {
          return _aceitarCarimbada(versaoEstado, eventoId);
        }
        if (versaoEstado < ultima) {
          return const DecisaoDaVisao._(CondutaDaVisao.atrasada);
        }
        if (versaoEstado == ultima) {
          return eventoId == _eventoAceito
              ? DecisaoDaVisao._(
                  CondutaDaVisao.duplicada,
                  versaoEstado: versaoEstado,
                  eventoId: eventoId,
                )
              : const DecisaoDaVisao._(CondutaDaVisao.inconsistente);
        }
        return _aceitarCarimbada(versaoEstado, eventoId);
    }
  }

  DecisaoDaVisao _aceitarCarimbada(int versao, String evento) {
    _versaoAceita = versao;
    _eventoAceito = evento;
    _jaAceitouVersionada = true;
    return DecisaoDaVisao._(
      CondutaDaVisao.aceitar,
      versaoEstado: versao,
      eventoId: evento,
    );
  }

  /// A emissão descrita por [decisao] declara um encerramento que o livro ainda
  /// não conhece? Anota-o como PENDENTE e devolve o aviso; ou devolve nulo.
  ///
  /// "PENDENTE", e não "despachado": este método não sabe se alguém vai
  /// apresentar o aviso, e fingir que sabe é o defeito que a OS desta entrega
  /// corrige. O retorno serve para CUTUCAR um consumidor que já esteja montado;
  /// quem confirma o consumo é quem apresenta, pelo livro, depois de apresentar.
  ///
  /// ESTE MÉTODO NÃO CONSULTA O MARCADOR DE ORDEM, e a independência é o
  /// requisito. Perguntar ao marcador "já vi esta versão?" responderia SIM
  /// sempre que [avaliar] tivesse acabado de aceitá-la — e o efeito terminal
  /// seria engolido pela própria aplicação do snapshot que o trouxe.
  ///
  /// Chamar com uma [decisao] de descarte devolve nulo: emissão sem autoridade
  /// não declara encerramento. Chamar com uma duplicata NÃO devolve nulo por
  /// ser duplicata — o livro dos efeitos é quem decide, e ele pode estar limpo
  /// para aquele `eventoId`.
  EncerramentoAutoritativo? talvezEncerramento(
    DecisaoDaVisao decisao,
    Map<String, dynamic> visao,
  ) {
    if (!decisao.temAutoridade) return null;
    // `encerrada` é o campo do contrato, não uma regra do Buraco reimplementada:
    // quem declara o fim é o servidor, e isto só lê a declaração.
    if (visao['encerrada'] != true) return null;

    final evento = decisao.eventoId;
    // O registro e a pergunta são o mesmo gesto: não há janela entre "conferi"
    // e "anotei", e é o livro que devolve nulo quando o fim já era conhecido.
    return efeitos.registrar(
      EncerramentoAutoritativo(
        // Nulos JUNTOS no modo legado: sem carimbo não há número, e pôr um
        // aqui seria dar cara de autoridade a um palpite.
        versaoEstado: evento == null ? null : decisao.versaoEstado,
        eventoId: evento,
        visao: visao,
      ),
    );
  }
}
