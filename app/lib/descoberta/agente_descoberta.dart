// agente_descoberta.dart — o RITMO: quando pedir, quando pulsar, quando parar.
//
// ---------------------------------------------------------------------------
// POR QUE O RITMO NÃO MORA NA TELA
// ---------------------------------------------------------------------------
//
// Um `Timer.periodic` dentro de um `State` é a receita conhecida de dois
// defeitos que já custaram caro em aplicativos assim:
//
//   * TEMPESTADE DE RECONSTRUÇÃO. `initState` cria o timer, mas uma rota
//     empilhada e desempilhada cria outro, e o primeiro continua vivo. Dois
//     timers viram dois pedidos por período, e ninguém cancela o que não
//     conhece.
//   * TIMER ÓRFÃO. A tela sai, o `dispose` esquece um dos timers, e o
//     aplicativo continua falando com o servidor por uma tela que não existe.
//
// Aqui o ritmo pertence a quem tem ciclo de vida de verdade: o transporte, que
// é UM pela vida do aplicativo. A tela não cria timer nenhum — ela lê o estado
// e, no máximo, PEDE uma atualização imediata.
//
// ---------------------------------------------------------------------------
// O LIMITE DO SERVIDOR É RESPEITADO ANTES DE ENVIAR
// ---------------------------------------------------------------------------
//
// O servidor recusa consulta mais frequente que 1 s e pulso mais frequente que
// 5 s, por conexão. Enviar assim mesmo custa o socket e devolve recusa — e a
// recusa é indistinguível, para quem lê a tela, de um servidor com problema.
//
// Então o limite é conferido aqui, com o relógio injetado. É também o que
// protege o botão Atualizar: apertar dez vezes seguidas manda UM pedido.

import 'dart:async';

import 'contrato_descoberta.dart';

/// Intervalo padrão da atualização automática da lista.
///
/// Cinco vezes o piso do servidor (1 s). O piso existe para impedir abuso, não
/// para ser a cadência normal: uma lista de saguão que se repinta a cada
/// segundo gasta bateria e rede de todo mundo para mostrar a mesma coisa. Cinco
/// segundos é rápido o bastante para a mesa que encheu aparecer cheia antes de
/// alguém tentar entrar nela.
const Duration intervaloPadraoDeDescoberta = Duration(seconds: 5);

/// Dispara os dois pedidos periódicos e guarda os limites de frequência.
///
/// Não conhece socket, JSON nem tela: recebe duas funções e um relógio.
class AgenteDeDescoberta {
  AgenteDeDescoberta({
    required this.pedirMesas,
    required this.pulsar,
    DateTime Function()? relogio,
    this.intervaloDeDescoberta = intervaloPadraoDeDescoberta,
  }) : _relogio = relogio ?? DateTime.now;

  /// Manda `descobrirMesas` pelo transporte.
  final void Function() pedirMesas;

  /// Manda `presenca_ping` pelo transporte.
  final void Function() pulsar;

  final Duration intervaloDeDescoberta;

  final DateTime Function() _relogio;

  Timer? _timerDeMesas;
  Timer? _timerDePulso;
  DateTime? _ultimoPedidoDeMesas;
  DateTime? _ultimoPulso;
  bool _ligado = false;
  bool _descartado = false;

  /// Intervalo de pulso vigente. Nasce no piso do contrato e passa a ser o que
  /// o servidor sugerir — é ele quem sabe o próprio TTL, e escrever o número
  /// aqui faria o cliente adivinhar um valor que já vem pronto no recibo.
  Duration _intervaloDePulso = ContratoDaDescoberta.ritmoMinimoDePulso;
  Duration get intervaloDePulso => _intervaloDePulso;

  /// Está pulsando e pedindo?
  bool get ligado => _ligado;

  /// Quantos pedidos de mesa o agente já mandou. Existe para o teste afirmar um
  /// NÚMERO — "não fez tempestade" só é verificável contando.
  int get pedidosDeMesasEnviados => _pedidosDeMesas;
  int _pedidosDeMesas = 0;

  int get pulsosEnviados => _pulsos;
  int _pulsos = 0;

  /// SÓ DEPOIS DE AUTENTICADO. Quem chama é o transporte, ao receber
  /// `autenticado` — antes disso o servidor recusaria as duas mensagens, e o
  /// cliente estaria gastando socket para levar `NAO_AUTENTICADO`.
  ///
  /// Idempotente: chamar de novo com o agente ligado não cria um segundo par de
  /// timers. É esta linha que impede a tempestade quando a tela reconstrói.
  void iniciar() {
    if (_descartado || _ligado) return;
    _ligado = true;

    // A PRIMEIRA CONSULTA É IMEDIATA. Esperar o primeiro período deixaria a
    // Home cinco segundos sem número nenhum logo depois de conectar — e é
    // exatamente o instante em que a pessoa está olhando.
    solicitarMesas(forcado: true);
    _pulsarAgora(forcado: true);
  }

  /// Para tudo. Idempotente, e seguro de chamar de dentro do `dispose`.
  void parar() {
    _ligado = false;
    _timerDeMesas?.cancel();
    _timerDeMesas = null;
    _timerDePulso?.cancel();
    _timerDePulso = null;
  }

  /// Encerra de vez. Depois disto [iniciar] não liga mais nada — é o que
  /// impede um `dispose` seguido de uma resposta tardia religar os timers.
  void descartar() {
    _descartado = true;
    parar();
  }

  /// Pede a lista agora, se o limite de frequência permitir.
  ///
  /// Devolve `true` quando o pedido saiu. O botão Atualizar usa o retorno para
  /// não fingir que fez algo: apertar duas vezes em meio segundo manda um só.
  ///
  /// [forcado] pula a espera — usado na primeira consulta depois de autenticar,
  /// que por definição não tem pedido anterior para respeitar.
  bool solicitarMesas({bool forcado = false}) {
    if (_descartado) return false;
    final agora = _relogio();
    final ultimo = _ultimoPedidoDeMesas;
    if (!forcado &&
        ultimo != null &&
        agora.difference(ultimo) < ContratoDaDescoberta.ritmoMinimoDeMesas) {
      return false;
    }
    _ultimoPedidoDeMesas = agora;
    _pedidosDeMesas++;
    pedirMesas();
    // O RELÓGIO DO PRÓXIMO PEDIDO CONTA A PARTIR DESTE.
    //
    // É o que garante o piso do contrato sem consultar relógio nenhum no
    // caminho periódico: um pedido manual reagenda o automático, então dois
    // pedidos nunca saem a menos de um intervalo um do outro.
    if (_ligado) _agendarMesas();
    return true;
  }

  /// O tique automático da lista. NÃO consulta o limite de frequência — o
  /// próprio intervalo É o limite, e ele é cinco vezes o piso do contrato.
  ///
  /// Consultar o relógio aqui foi um defeito real desta OS: `DateTime.now()`
  /// não anda junto com os temporizadores num teste de widget, então o tique
  /// disparava e a checagem o recusava — e a presença de quem estava parado na
  /// Home simplesmente parava. Em produção os dois relógios concordam e o
  /// defeito seria invisível até alguém medir.
  void _tiqueDeMesas() {
    if (_descartado || !_ligado) return;
    _ultimoPedidoDeMesas = _relogio();
    _pedidosDeMesas++;
    pedirMesas();
    _agendarMesas();
  }

  void _agendarMesas() {
    _timerDeMesas?.cancel();
    _timerDeMesas = Timer(intervaloDeDescoberta, _tiqueDeMesas);
  }

  bool _pulsarAgora({bool forcado = false}) {
    if (_descartado) return false;
    final agora = _relogio();
    final ultimo = _ultimoPulso;
    if (!forcado &&
        ultimo != null &&
        agora.difference(ultimo) < ContratoDaDescoberta.ritmoMinimoDePulso) {
      return false;
    }
    _ultimoPulso = agora;
    _pulsos++;
    pulsar();
    if (_ligado) _rearmarPulso();
    return true;
  }

  /// O tique automático do pulso. Mesma razão do de mesas.
  void _tiqueDePulso() {
    if (_descartado || !_ligado) return;
    _ultimoPulso = _relogio();
    _pulsos++;
    pulsar();
    _rearmarPulso();
  }

  /// O servidor respondeu `presenca_ok` e disse de quanto em quanto tempo
  /// pulsar. O valor é ADOTADO, com o piso do contrato como chão: um servidor
  /// que sugerisse 10 ms levaria recusa por ritmo a cada pulso.
  void aoReceberRecibo({required Duration intervaloSugerido}) {
    if (_descartado) return;
    final novo = intervaloSugerido < ContratoDaDescoberta.ritmoMinimoDePulso
        ? ContratoDaDescoberta.ritmoMinimoDePulso
        : intervaloSugerido;
    if (novo == _intervaloDePulso) return;
    _intervaloDePulso = novo;
    if (_ligado) _rearmarPulso();
  }

  void _rearmarPulso() {
    _timerDePulso?.cancel();
    _timerDePulso = Timer(_intervaloDePulso, _tiqueDePulso);
  }
}
