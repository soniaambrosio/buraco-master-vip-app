// modelo_ingresso.dart — a intenção, a confirmação e a recusa, TIPADAS.
//
// ---------------------------------------------------------------------------
// TRÊS COISAS QUE NÃO PODEM SER O MESMO OBJETO
// ---------------------------------------------------------------------------
//
//   INTENÇÃO     o que o jogador PEDIU. Existe do toque até a resposta, e some
//                quando a tela é descartada ou a sessão troca.
//   CONFIRMAÇÃO  o que o servidor DEU. Só nasce de um ACK, e o assento dentro
//                dela é o único assento que existe para o cliente.
//   RECUSA       por que não deu. Não carrega assento nenhum, de propósito:
//                não existe "recusado, mas sente ali".
//
// Um mapa com `assentoPedido`, `assentoConfirmado` e `erro` faria as três
// caberem no mesmo lugar, e a primeira pergunta difícil — "estou dentro?" —
// passaria a ter três respostas possíveis lidas de campos diferentes.

import 'contrato_ingresso.dart';

/// O que o jogador pediu, e sob qual conexão.
///
/// [assento] nulo significa INGRESSO AUTOMÁTICO — o campo não vai no fio e o
/// servidor aplica a ordem dele. Não é "assento 0": é a ausência de pedido, e
/// as duas coisas produzem mensagens diferentes.
class IntencaoDeIngresso {
  const IntencaoDeIngresso({
    required this.codigo,
    required this.assento,
    required this.geracaoDeTransporte,
  });

  /// O código OPACO da mesa, como a descoberta o publicou.
  final String codigo;

  /// O assento PEDIDO, ou `null` para automático.
  final int? assento;

  /// O crachá da conexão que levou o pedido. Uma resposta que chegue por outra
  /// geração não é desta intenção — ver `estado_ingresso.dart`.
  final int geracaoDeTransporte;

  /// Houve escolha explícita de cadeira?
  bool get explicita => assento != null;
}

/// O que o servidor confirmou. Só o ACK constrói isto.
class IngressoConfirmado {
  const IngressoConfirmado({
    required this.codigo,
    required this.assento,
    required this.reconexao,
  });

  final String codigo;

  /// O assento EFETIVAMENTE ocupado, decidido pelo servidor.
  final int assento;

  /// A tentativa foi classificada como volta do titular ao próprio assento.
  ///
  /// É o ÚNICO caso em que o assento confirmado pode divergir do pedido: numa
  /// reconexão o servidor ignora a preferência e devolve o lugar que já era
  /// dele. Tratar isso como violação impediria alguém de voltar para a própria
  /// cadeira — que é o oposto do que a autoridade do servidor existe para
  /// proteger.
  final bool reconexao;

  /// Frase para leitor de tela. A posição é dita por extenso porque
  /// "assento 2" não quer dizer nada para quem não vê a mesa desenhada.
  String get anuncio => reconexao
      ? 'Você voltou para a posição ${assento + 1}.'
      : 'Lugar confirmado na posição ${assento + 1}.';
}

/// Por que o ingresso não aconteceu. Enumeração FECHADA.
///
/// Um código desconhecido vira [desconhecida] — nunca um fallback, nunca uma
/// segunda tentativa. A pessoa continua fora da mesa, que é o lado seguro.
enum MotivoDeRecusaDeIngresso {
  /// A cadeira pedida tem dono. É a recusa da CONCORRÊNCIA.
  assentoOcupado,

  /// O pedido não era um assento.
  assentoInvalido,

  /// O backend de direitos não respondeu (mesa VIP).
  admissaoIndisponivel,

  /// A mesa não existe mais no servidor.
  mesaNaoEncontrada,

  /// Não há vaga nenhuma (caminho do ingresso automático).
  mesaCheia,

  /// A partida começou e quem pediu não é titular de assento.
  partidaJaComecou,

  /// O ACK veio, e não descreve um ingresso que possa ser aceito: assento
  /// ausente, fora de 0..3, ou diferente do que foi pedido sem ser reconexão.
  ///
  /// É violação de contrato do servidor, e o cliente a trata como recusa em
  /// vez de adivinhar — adivinhar aqui seria sentar alguém numa cadeira que
  /// ninguém pediu.
  ackForaDoContrato,

  /// Recusa que o cliente não sabe classificar.
  desconhecida;

  /// Como classificar uma recusa do fio.
  ///
  /// O CÓDIGO MANDA, e o texto é a segunda tentativa. É a ordem certa porque o
  /// código é vocabulário estável e o texto é mensagem para gente — mensagem
  /// muda, e um dia vai mudar.
  static MotivoDeRecusaDeIngresso classificar({
    String? codigo,
    String? motivo,
  }) {
    switch (codigo) {
      case ContratoDoIngresso.recusaAssentoOcupado:
        return MotivoDeRecusaDeIngresso.assentoOcupado;
      case ContratoDoIngresso.recusaAssentoInvalido:
        return MotivoDeRecusaDeIngresso.assentoInvalido;
      case ContratoDoIngresso.recusaAdmissaoIndisponivel:
        return MotivoDeRecusaDeIngresso.admissaoIndisponivel;
    }
    if (motivo == null) return MotivoDeRecusaDeIngresso.desconhecida;
    final texto = ContratoDoIngresso.normalizarMotivo(motivo);
    if (texto == ContratoDoIngresso.motivoMesaNaoEncontrada) {
      return MotivoDeRecusaDeIngresso.mesaNaoEncontrada;
    }
    if (texto == ContratoDoIngresso.motivoMesaCheia) {
      return MotivoDeRecusaDeIngresso.mesaCheia;
    }
    if (texto == ContratoDoIngresso.motivoPartidaJaComecou) {
      return MotivoDeRecusaDeIngresso.partidaJaComecou;
    }
    return MotivoDeRecusaDeIngresso.desconhecida;
  }
}

/// Uma recusa, pronta para a tela.
///
/// NÃO CARREGA ASSENTO CONCEDIDO. Não existe "recusado, mas sente ali" — se
/// existisse um campo assim, alguém acabaria lendo dele.
class RecusaDeIngresso {
  const RecusaDeIngresso({required this.motivo, required this.assentoPedido});

  final MotivoDeRecusaDeIngresso motivo;

  /// Qual cadeira foi PEDIDA, para a frase dizer de qual se trata. `null` no
  /// ingresso automático. É o pedido, nunca uma concessão.
  final int? assentoPedido;

  /// O texto que a jogadora lê — e que o leitor de tela anuncia.
  ///
  /// Cada frase diz O QUE FAZER, porque uma recusa sem saída é um beco. E
  /// nenhuma delas promete que o aplicativo vai tentar de novo sozinho: ele
  /// não vai, e prometer seria a compensação que a OS proíbe.
  String get mensagem => switch (motivo) {
    MotivoDeRecusaDeIngresso.assentoOcupado =>
      assentoPedido == null
          ? 'Esse lugar acabou de ser ocupado. Escolha outro.'
          : 'A posição ${assentoPedido! + 1} acabou de ser ocupada. '
                'Escolha outro lugar.',
    MotivoDeRecusaDeIngresso.assentoInvalido =>
      'Esse lugar não existe nesta mesa. Escolha um dos quatro.',
    MotivoDeRecusaDeIngresso.admissaoIndisponivel =>
      'Não foi possível liberar sua entrada nesta mesa agora. Tente outra.',
    MotivoDeRecusaDeIngresso.mesaNaoEncontrada =>
      'Esta mesa não existe mais. Volte e escolha outra.',
    MotivoDeRecusaDeIngresso.mesaCheia =>
      'A mesa encheu. Volte e escolha outra.',
    MotivoDeRecusaDeIngresso.partidaJaComecou =>
      'A partida desta mesa já começou. Volte e escolha outra.',
    MotivoDeRecusaDeIngresso.ackForaDoContrato =>
      'O servidor respondeu algo que este aplicativo não sabe ler. '
          'Nada foi feito de propósito.',
    MotivoDeRecusaDeIngresso.desconhecida =>
      'Não foi possível entrar nesta mesa agora.',
  };

  /// A recusa deixa a pessoa no SELETOR (dá para tentar outra cadeira) ou manda
  /// voltar para a lista (a mesa inteira saiu de jogo)?
  ///
  /// Nenhum dos dois é tentativa automática: os dois são o que a tela OFERECE,
  /// e quem aperta é a pessoa.
  bool get permiteEscolherOutroAssento => switch (motivo) {
    MotivoDeRecusaDeIngresso.assentoOcupado ||
    MotivoDeRecusaDeIngresso.assentoInvalido ||
    MotivoDeRecusaDeIngresso.ackForaDoContrato ||
    MotivoDeRecusaDeIngresso.desconhecida => true,
    MotivoDeRecusaDeIngresso.mesaNaoEncontrada ||
    MotivoDeRecusaDeIngresso.mesaCheia ||
    MotivoDeRecusaDeIngresso.partidaJaComecou ||
    MotivoDeRecusaDeIngresso.admissaoIndisponivel => false,
  };
}
