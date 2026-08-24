// estado_ingresso.dart — a MÁQUINA DA INTENÇÃO: um pedido por vez, e nenhum
// assento concedido pelo cliente.
//
// ---------------------------------------------------------------------------
// O PROBLEMA QUE ESTE ARQUIVO RESOLVE
// ---------------------------------------------------------------------------
//
// Entre o toque na cadeira e a resposta do servidor existe uma janela. Dentro
// dela cabe tudo o que estraga um saguão:
//
//   * o dedo bate duas vezes e saem dois pedidos;
//   * a resposta do primeiro chega depois da do segundo;
//   * a pessoa sai da tela e a resposta chega para uma tela que não existe;
//   * a conexão cai, volta com outro crachá, e a resposta velha chega junto;
//   * a pessoa TROCA DE CONTA, e a resposta da conta anterior chega para a nova.
//
// Nenhum desses é resolvido por "esperar direitinho". Todos são resolvidos por
// haver UMA intenção com dono, com crachá de conexão, e por toda resposta ser
// conferida contra ela antes de virar qualquer coisa.
//
// ---------------------------------------------------------------------------
// O CLIENTE NÃO SENTA NINGUÉM
// ---------------------------------------------------------------------------
//
// Não existe caminho aqui que produza um [IngressoConfirmado] sem um ACK. Não
// há valor padrão, não há "assume o que pediu", não há segunda tentativa em
// outra cadeira. Uma recusa é um fim: a fase vira [FaseDoIngresso.recusado] e
// só um novo gesto da pessoa começa outro pedido.
//
// A ÚNICA divergência tolerada entre pedido e confirmação é a RECONEXÃO. Nela
// o servidor ignora a preferência e devolve o assento que já era do titular —
// e recusar isso impediria alguém de voltar para a própria cadeira.
//
// ---------------------------------------------------------------------------
// POR QUE ISTO MORA NO TRANSPORTE, E NÃO NA TELA
// ---------------------------------------------------------------------------
//
// Pela mesma razão do retrato da descoberta (OS 38.2): a tela pode ser
// descartada, e a resposta chega assim mesmo. Estado que vive na tela morre
// antes da resposta e não tem como descartá-la; estado que vive no transporte
// tem o crachá da conexão na mão e sabe dizer "isto não é meu".

import 'contrato_ingresso.dart';
import 'modelo_ingresso.dart';

/// Em que ponto o ingresso está. Enumeração fechada — a tela decide o que
/// desenhar por `switch` exaustivo.
enum FaseDoIngresso {
  /// Nenhum pedido em voo e nenhum veredito pendente.
  ocioso,

  /// Um pedido saiu e a resposta não chegou. É a fase que TRAVA o toque duplo.
  solicitando,

  /// O servidor confirmou. Há assento, e ele veio do ACK.
  confirmado,

  /// O servidor recusou, ou o ACK não pôde ser aceito. Não há assento.
  recusado,
}

/// Guarda a intenção vigente e julga toda resposta contra ela.
///
/// Sem `ChangeNotifier` de propósito: quem notifica é o transporte, que é o
/// dono de ciclo de vida. Dois notificadores para o mesmo evento fariam a tela
/// reconstruir duas vezes por resposta — a mesma decisão de
/// `estado_descoberta.dart`.
class EstadoDoIngresso {
  IntencaoDeIngresso? _intencao;
  FaseDoIngresso _fase = FaseDoIngresso.ocioso;
  IngressoConfirmado? _confirmado;
  RecusaDeIngresso? _recusa;
  int _geracaoDeTransporte = 0;

  /// Quantos pedidos de ingresso ESTA máquina autorizou.
  ///
  /// Existe para o teste afirmar um NÚMERO: "toque duplo não manda dois
  /// pedidos" só é verificável contando. É o mesmo motivo de
  /// `AgenteDeDescoberta.pedidosDeMesasEnviados` existir.
  int get pedidosAutorizados => _pedidos;
  int _pedidos = 0;

  FaseDoIngresso get fase => _fase;

  /// Há um pedido em voo. É isto que trava o segundo toque e desabilita as
  /// cadeiras na tela.
  bool get solicitando => _fase == FaseDoIngresso.solicitando;

  /// A intenção vigente, ou `null`.
  IntencaoDeIngresso? get intencao => _intencao;

  /// O assento PEDIDO na intenção vigente. `null` no automático e quando não
  /// há intenção — a tela distingue os dois pela [fase].
  int? get assentoSolicitado => _intencao?.assento;

  /// A recusa do último veredito, ou `null`.
  RecusaDeIngresso? get recusa => _recusa;

  /// Há uma confirmação AINDA NÃO CONSUMIDA.
  ///
  /// A navegação lê isto e chama [consumirConfirmacao]. É o que faz um ACK
  /// navegar UMA vez: uma resposta duplicada do servidor encontra a fase já
  /// fora de `solicitando` e não produz segunda confirmação, e um `build`
  /// repetido encontra a confirmação já consumida.
  bool get temConfirmacaoPendente => _confirmado != null;

  /// A geração de transporte que este estado considera vigente.
  int get geracaoDeTransporte => _geracaoDeTransporte;

  /// Chamado pelo transporte quando uma conexão nova é autenticada.
  ///
  /// UMA INTENÇÃO NÃO ATRAVESSA CONEXÕES. O pedido saiu por um socket que
  /// morreu; a resposta dele nunca vai chegar, e a resposta que chegar pelo
  /// socket novo é de outra tentativa. Mantê-la viva deixaria a tela travada
  /// em "entrando…" para sempre — e, pior, faria um ACK do socket novo ser
  /// creditado a um pedido do antigo.
  void definirGeracaoDeTransporte(int geracao) {
    if (geracao == _geracaoDeTransporte) return;
    _geracaoDeTransporte = geracao;
    if (_fase == FaseDoIngresso.solicitando) {
      _intencao = null;
      _recusa = null;
      _fase = FaseDoIngresso.ocioso;
    }
  }

  /// Registra a intenção. Devolve `false` quando o pedido NÃO deve sair.
  ///
  /// Duas recusas locais, e as duas economizam socket sem decidir nada sobre
  /// ocupação:
  ///
  ///   * já há pedido em voo — é a trava do toque duplo;
  ///   * o assento pedido não é um assento — a MESMA regra do servidor.
  ///
  /// Nenhuma delas olha para a mesa. Se a cadeira está livre ou não é pergunta
  /// do servidor, e perguntá-la aqui criaria a autoridade local que a OS
  /// proíbe.
  bool iniciar({
    required String codigo,
    required int? assento,
    required int geracaoDeTransporte,
  }) {
    if (_fase == FaseDoIngresso.solicitando) return false;
    if (codigo.isEmpty) return false;
    if (assento != null && !ContratoDoIngresso.ehAssentoPedido(assento)) {
      return false;
    }
    _intencao = IntencaoDeIngresso(
      codigo: codigo,
      assento: assento,
      geracaoDeTransporte: geracaoDeTransporte,
    );
    _fase = FaseDoIngresso.solicitando;
    _recusa = null;
    _confirmado = null;
    _pedidos++;
    return true;
  }

  /// Julga um ACK `entrou`. Devolve `true` só quando ele virou confirmação.
  ///
  /// [bruto] é a mensagem inteira, como chegou.
  bool aplicarAceite(Object? bruto, {required int geracaoDeTransporte}) {
    final intencao = _intencao;
    if (intencao == null || _fase != FaseDoIngresso.solicitando) return false;

    // 1. TRANSPORTE. Resposta de uma conexão que já não é a vigente não vale —
    //    ela foi pedida por outra sessão. É a trava do A → B.
    if (geracaoDeTransporte != _geracaoDeTransporte) return false;
    if (intencao.geracaoDeTransporte != geracaoDeTransporte) return false;

    if (bruto is! Map) return false;

    // 2. IDENTIDADE DA MESA. Um ACK de outro código não responde a esta
    //    intenção — e existe um caminho real que o produz: a mesa por código,
    //    que fala o MESMO `entrarMesa` por outra tela. Descartar (e continuar
    //    esperando) é o certo; tratar como recusa mataria um pedido válido.
    final codigo = bruto[ContratoDoIngresso.campoCodigo];
    if (codigo is! String || codigo != intencao.codigo) return false;

    // 3. O ASSENTO CONFIRMADO. Ausente, não inteiro ou fora de 0..3 é violação
    //    de contrato do servidor — e não há nada a adivinhar: sem assento
    //    válido não existe ingresso.
    final assento = bruto[ContratoDoIngresso.campoAssentoConfirmado];
    if (!ContratoDoIngresso.ehAssentoPedido(assento)) {
      return _recusar(MotivoDeRecusaDeIngresso.ackForaDoContrato);
    }
    final confirmado = assento! as int;
    final reconexao = bruto[ContratoDoIngresso.campoReconexao] == true;

    // 4. CONFIRMADO == SOLICITADO. Só a reconexão escapa, e o servidor a
    //    ANUNCIA: ali ele ignora a preferência de propósito e devolve o lugar
    //    do titular.
    if (intencao.explicita && !reconexao && confirmado != intencao.assento) {
      return _recusar(MotivoDeRecusaDeIngresso.ackForaDoContrato);
    }

    _confirmado = IngressoConfirmado(
      codigo: codigo,
      assento: confirmado,
      reconexao: reconexao,
    );
    _fase = FaseDoIngresso.confirmado;
    _recusa = null;
    return true;
  }

  /// Julga uma recusa `erro`. Devolve `true` quando ela virou o veredito.
  ///
  /// Consome APENAS com pedido em voo. Fora disso o `erro` é de outro caminho
  /// (uma jogada recusada, uma credencial vencida) e não tem nada a ver com
  /// ingresso — roubá-lo faria a tela do seletor mostrar a recusa da mesa.
  bool aplicarRecusa(Object? bruto, {required int geracaoDeTransporte}) {
    final intencao = _intencao;
    if (intencao == null || _fase != FaseDoIngresso.solicitando) return false;
    if (geracaoDeTransporte != _geracaoDeTransporte) return false;
    if (intencao.geracaoDeTransporte != geracaoDeTransporte) return false;
    if (bruto is! Map) return false;

    final codigo = bruto[ContratoDoIngresso.campoCodigoDeRecusa];
    final motivo = bruto[ContratoDoIngresso.campoMotivo];
    return _recusar(
      MotivoDeRecusaDeIngresso.classificar(
        codigo: codigo is String ? codigo : null,
        motivo: motivo is String ? motivo : null,
      ),
    );
  }

  /// Entrega a confirmação UMA vez e a apaga.
  ///
  /// Quem navega chama isto. Depois disso a fase continua
  /// [FaseDoIngresso.confirmado] — a tela ainda pode dizer que deu certo —, e
  /// [temConfirmacaoPendente] volta a ser falso, então nenhum `build` posterior
  /// empurra o destino de novo.
  IngressoConfirmado? consumirConfirmacao() {
    final c = _confirmado;
    _confirmado = null;
    return c;
  }

  /// A TELA SAIU, OU A PESSOA DESISTIU. A intenção morre.
  ///
  /// Uma resposta que chegue depois disto encontra a fase fora de
  /// `solicitando` e não navega, não confirma e não recusa.
  ///
  /// O que isto NÃO faz é desfazer uma entrada que o servidor já concedeu: se
  /// o ACK estava a caminho, a pessoa está sentada de verdade, e sair da mesa
  /// por conta própria seria a compensação "entrei errado, saio e tento de
  /// novo" que a OS proíbe. A verdade continua sendo a do servidor, e a
  /// próxima lista a mostra.
  void cancelar() {
    _intencao = null;
    _confirmado = null;
    _recusa = null;
    _fase = FaseDoIngresso.ocioso;
  }

  /// LOGOUT OU TROCA DE CONTA. Apaga tudo, inclusive confirmação não
  /// consumida.
  ///
  /// É o caminho que impede a conta B de herdar o assento que a conta A
  /// conquistou: a confirmação de A não sobrevive à troca, então não há o que
  /// consumir e não há para onde navegar.
  void encerrarSessao() {
    _intencao = null;
    _confirmado = null;
    _recusa = null;
    _fase = FaseDoIngresso.ocioso;
  }

  bool _recusar(MotivoDeRecusaDeIngresso motivo) {
    _recusa = RecusaDeIngresso(
      motivo: motivo,
      assentoPedido: _intencao?.assento,
    );
    _fase = FaseDoIngresso.recusado;
    _confirmado = null;
    // A INTENÇÃO MORRE COM A RECUSA. Mantê-la deixaria um `assentoSolicitado`
    // vivo apontando para uma cadeira que não é de ninguém — e a tela
    // desenharia a seleção como se o pedido continuasse valendo.
    _intencao = null;
    return true;
  }
}
