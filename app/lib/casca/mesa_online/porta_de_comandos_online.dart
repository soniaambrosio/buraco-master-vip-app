// porta_de_comandos_online.dart — por onde o gesto da pessoa vira comando.
//
// ===========================================================================
// UMA PORTA, E NÃO UM MOTOR
// ===========================================================================
//
// Esta classe não guarda partida. Não tem baralho, não tem mão, não tem
// placar, não sabe se uma jogada é válida e não altera nada do que a tela
// mostra. Ela guarda UMA coisa: se existe uma intenção esperando resposta do
// servidor.
//
// Isso é deliberado, e é a diferença entre uma mesa online honesta e um
// híbrido. A tentação, num jogo de cartas em rede, é aplicar a jogada na hora
// para a tela responder rápido e "corrigir" quando o servidor discordar. Numa
// mesa de Buraco isso significa tirar a carta da mão antes de saber se o
// descarte valeu — e, quando o servidor recusa, devolvê-la. Enquanto o
// servidor não responde, a pessoa está olhando para uma mesa que não existe em
// lugar nenhum, e a correção parece um bug ("a carta voltou sozinha").
//
// Aqui nada é aplicado localmente. O estado da mesa muda quando — e só
// quando — chega uma visão nova do servidor.
//
// ===========================================================================
// O DUPLO TOQUE, SEM eventoId
// ===========================================================================
//
// O protocolo do servidor (`buraco-servidor`, SHA
// 16a692bbe95597536b3f9975ecf32e1bde58ebcb) NÃO tem identificador de evento
// nem versão de estado: `{tipo:'jogada', jogada:{...}}` sai sem carimbo, e o
// servidor não sabe dizer que duas mensagens iguais eram a mesma intenção.
// Dois toques em "comprar" chegam como duas compras — e a segunda ou é
// recusada ("você já comprou nesta jogada") ou, num instante infeliz, compra
// de novo no turno seguinte.
//
// Sem carimbo no fio, a idempotência tem de ser do lado de cá, e ela é uma
// TRAVA, não um filtro de repetidos: enquanto uma intenção espera resposta,
// nenhuma outra sai. Numa mesa em que só se faz uma coisa por vez, isso é
// exatamente o certo — e é mais forte do que bloquear só a intenção
// equivalente, porque "comprar" seguido de "descartar" antes de o servidor
// responder à compra também é uma dupla que não pode acontecer.
//
// A trava é solta pela AUTORIDADE: uma visão nova, uma recusa do servidor, ou
// a queda da conexão. Nunca por um relógio de otimismo. Existe um teto de
// espera ([limiteDeResposta]) — e ele não aplica nada nem finge que a jogada
// valeu: só devolve o controle à pessoa depois de o servidor ficar mudo tempo
// demais, porque uma mesa travada para sempre é pior do que uma mesa que
// admite não ter ouvido resposta.
//
// ===========================================================================
// O QUE NÃO SE REGISTRA
// ===========================================================================
//
// Nada. Esta classe não chama `print`, `debugPrint` nem logger nenhum, e o
// motivo é o conteúdo que passa por ela: ids de carta são a mão da pessoa, e
// as mensagens de recusa do servidor citam carta ("o topo é o X"). Um log de
// diagnóstico aqui seria a mão inteira num arquivo. Há teste estrutural que
// falha se alguém acrescentar um.

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../services/online_service.dart';

/// Por que uma intenção não pôde ser enviada, ou por que foi recusada.
enum MotivoDaRecusa {
  /// O servidor recusou a jogada pelas regras do Buraco. A pessoa tenta outra.
  regra,

  /// A credencial venceu ou foi recusada. Não há jogada que resolva.
  autenticacao,

  /// O transporte não está autenticado agora: caiu, está reconectando, ou o
  /// servidor ainda não aceitou a credencial.
  transporte,

  /// Já existe uma intenção esperando resposta.
  jaTemIntencaoPendente,

  /// O servidor ficou mudo além do teto de espera.
  semResposta,
}

/// A intenção que está no fio agora.
class IntencaoPendente {
  const IntencaoPendente(this.rotulo, this.chave);

  /// Como a tela chama isto para a pessoa ("comprando do monte…").
  final String rotulo;

  /// Identidade da intenção. NÃO vai no fio — o protocolo não tem campo para
  /// ela. Serve para a tela saber qual botão está aguardando.
  final String chave;
}

/// A única porta por onde as ações da mesa online saem.
///
/// Fica sobre o [OnlineService] da raiz — não cria transporte, não abre
/// socket, não observa autenticação e não conhece Firebase.
class PortaDeComandosOnline extends ChangeNotifier {
  PortaDeComandosOnline(
    this._online, {
    this.limiteDeResposta = const Duration(seconds: 12),
  }) {
    _online.addListener(_aoMudarOTransporte);
    _ultimaVisao = _online.visao;
    _ultimoErro = _online.erro;
  }

  final OnlineService _online;

  /// Quanto se espera o servidor responder a uma intenção antes de devolver o
  /// controle à pessoa. Não aplica jogada nenhuma — só destrava a interface.
  final Duration limiteDeResposta;

  IntencaoPendente? _pendente;
  Timer? _relogioDaEspera;

  /// A última visão que já foi contada como resposta. Comparada por
  /// IDENTIDADE: o `OnlineService` troca o mapa inteiro a cada `estado`, então
  /// mapa diferente quer dizer retrato novo.
  Map<String, dynamic>? _ultimaVisao;
  String? _ultimoErro;

  MotivoDaRecusa? _ultimaRecusa;
  String? _mensagemDaRecusa;

  /// Quantas recusas COM TEXTO já saíram desta porta.
  ///
  /// Existe por causa de uma armadilha do anúncio por leitor de tela: quem
  /// observa só [mensagemDaRecusa] não distingue "a mesma recusa continua na
  /// tela" de "a mesma recusa aconteceu de novo". As duas são a mesma string —
  /// e a segunda é notícia. Tentar duas vezes a mesma jogada inválida tem de
  /// falar duas vezes; ficar olhando para o recado que já foi lido, nenhuma.
  ///
  /// O selo NÃO vai no fio e não é estado de jogo: é o carimbo de ocorrência
  /// que o protocolo do servidor não tem. Ele sobe uma vez por recusa que
  /// PRODUZ TEXTO — o duplo toque, que morre em silêncio de propósito, não
  /// mexe nele.
  int _selosDeRecusa = 0;

  /// A intenção esperando resposta, ou nulo.
  IntencaoPendente? get pendente => _pendente;

  bool get temIntencaoPendente => _pendente != null;

  /// Por que a última tentativa não passou. Nulo quando a última coisa que
  /// aconteceu foi uma resposta boa.
  MotivoDaRecusa? get ultimaRecusa => _ultimaRecusa;

  /// O texto da recusa, para a pessoa ler. Vem do servidor já redigido pelo
  /// [OnlineService], ou é nosso quando a recusa é local.
  String? get mensagemDaRecusa => _mensagemDaRecusa;

  /// Quantas recusas com texto já aconteceram. Ver [_selosDeRecusa].
  int get selosDeRecusa => _selosDeRecusa;

  /// Dá para mandar comando agora? Só com a conexão autenticada e sem intenção
  /// pendurada.
  bool get aceitaComando =>
      _online.status == OnlineStatus.conectado && _pendente == null;

  // -------------------------------------------------------------------------
  // As intenções
  // -------------------------------------------------------------------------

  bool comprarDoMonte() =>
      _tentar('comprarMonte', 'Comprando do monte…', _online.comprarMonte);

  bool comprarDoLixo() =>
      _tentar('comprarLixo', 'Comprando o lixo…', _online.comprarLixo);

  bool descartar(String idDaCarta) => _tentar(
    // A chave inclui o id para a tela conseguir dizer QUAL carta está saindo.
    // Ela não vai para o fio, e não é registrada em lugar nenhum.
    'descartar:$idDaCarta',
    'Descartando…',
    () => _online.descartar(idDaCarta),
  );

  bool baixar(List<String> ids) {
    if (ids.isEmpty) return false;
    return _tentar(
      'baixar:${ids.join(",")}',
      'Baixando o jogo…',
      () => _online.baixar(List<String>.unmodifiable(ids)),
    );
  }

  bool estender(int indiceDoJogo, List<String> ids) {
    if (ids.isEmpty || indiceDoJogo < 0) return false;
    return _tentar(
      'estender:$indiceDoJogo:${ids.join(",")}',
      'Estendendo o jogo…',
      () => _online.estender(indiceDoJogo, List<String>.unmodifiable(ids)),
    );
  }

  /// Sair da mesa.
  ///
  /// NÃO passa pela trava: sair é a saída de emergência, e uma pessoa presa
  /// numa mesa que não responde precisa poder sair justamente quando há uma
  /// intenção pendurada. Também não é logout — quem sai da mesa continua na
  /// conta.
  void sairDaMesa() {
    _limparPendencia();
    _ultimaRecusa = null;
    _mensagemDaRecusa = null;
    _online.sair();
    notifyListeners();
  }

  /// Recomeça depois de uma falha terminal do transporte.
  void tentarReconectar() {
    _limparPendencia();
    _online.tentarNovamente();
    notifyListeners();
  }

  /// Apaga a recusa que está na tela. Só isso — não reenvia nada.
  void dispensarRecusa() {
    if (_ultimaRecusa == null) return;
    _ultimaRecusa = null;
    _mensagemDaRecusa = null;
    notifyListeners();
  }

  // -------------------------------------------------------------------------
  // O miolo
  // -------------------------------------------------------------------------

  bool _tentar(String chave, String rotulo, void Function() enviar) {
    if (_pendente != null) {
      // O duplo toque morre aqui, e em silêncio: a pessoa já vê a primeira
      // intenção marcada como pendente na tela, e um balão de erro por tocar
      // duas vezes seria ruído sobre uma ação que está indo bem.
      _ultimaRecusa = MotivoDaRecusa.jaTemIntencaoPendente;
      _mensagemDaRecusa = null;
      return false;
    }
    if (_online.status != OnlineStatus.conectado) {
      _ultimaRecusa = MotivoDaRecusa.transporte;
      _mensagemDaRecusa = _online.status == OnlineStatus.naoAutenticado
          ? 'entre na sua conta para continuar jogando'
          : 'sem conexão com o servidor — sua jogada não foi enviada';
      _selosDeRecusa++;
      notifyListeners();
      return false;
    }

    _ultimaRecusa = null;
    _mensagemDaRecusa = null;
    _pendente = IntencaoPendente(rotulo, chave);
    _armarEspera();
    enviar();
    notifyListeners();
    return true;
  }

  void _armarEspera() {
    _relogioDaEspera?.cancel();
    _relogioDaEspera = Timer(limiteDeResposta, () {
      if (_pendente == null) return;
      _limparPendencia();
      _ultimaRecusa = MotivoDaRecusa.semResposta;
      _mensagemDaRecusa =
          'o servidor não respondeu à sua jogada — confira a mesa antes de '
          'tentar de novo';
      _selosDeRecusa++;
      notifyListeners();
    });
  }

  void _limparPendencia() {
    _relogioDaEspera?.cancel();
    _relogioDaEspera = null;
    _pendente = null;
  }

  /// O transporte se mexeu. É AQUI que a autoridade solta a trava.
  void _aoMudarOTransporte() {
    var mudou = false;

    // 1) VISÃO NOVA. O servidor transmite o estado depois de aplicar a jogada —
    //    e também depois de RECUSAR uma que mexeu no estado (o foul de abertura
    //    vulnerável devolve cartas para a mão). Nos dois casos a resposta
    //    chegou, e a trava sai.
    final visao = _online.visao;
    if (!identical(visao, _ultimaVisao)) {
      _ultimaVisao = visao;
      if (_pendente != null) {
        _limparPendencia();
        mudou = true;
      }
    }

    // 2) RECUSA. Vem DEPOIS da visão quando as duas vêm juntas, o que é a
    //    ordem certa: a mesa já está no estado autoritativo quando a explicação
    //    aparece.
    final erro = _online.erro;
    if (erro != null && erro != _ultimoErro) {
      _limparPendencia();
      _ultimaRecusa = _classificar();
      _mensagemDaRecusa = erro;
      _selosDeRecusa++;
      mudou = true;
    }
    _ultimoErro = erro;

    // 3) A CONEXÃO SAIU DO AR. Uma intenção pendurada num socket que caiu nunca
    //    vai ser respondida por ele. A trava sai para a pessoa não ficar presa,
    //    e nada é reenviado: o que aconteceu com a jogada em voo, só o servidor
    //    sabe, e a visão da retomada é que vai dizer.
    if (_online.status != OnlineStatus.conectado && _pendente != null) {
      _limparPendencia();
      _ultimaRecusa = MotivoDaRecusa.transporte;
      _mensagemDaRecusa =
          'a conexão caiu antes da resposta — a mesa vai se acertar quando ela '
          'voltar';
      _selosDeRecusa++;
      mudou = true;
    }

    if (mudou) notifyListeners();
  }

  /// De quem é a culpa da última recusa.
  ///
  /// O `codigo` é o do servidor quando ele mandou um; recusa de regra do motor
  /// chega só com `motivo`, e é por isso que a ausência de código significa
  /// "regra" e não "desconhecido".
  MotivoDaRecusa _classificar() {
    final codigo = _online.erroCodigo;
    if (codigo == 'NAO_AUTENTICADO' ||
        codigo == 'CREDENCIAL_EXPIRADA' ||
        codigo == 'IDENTIDADE_DIVERGENTE') {
      return MotivoDaRecusa.autenticacao;
    }
    if (_online.status == OnlineStatus.naoAutenticado) {
      return MotivoDaRecusa.autenticacao;
    }
    if (_online.status != OnlineStatus.conectado) {
      return MotivoDaRecusa.transporte;
    }
    return MotivoDaRecusa.regra;
  }

  @override
  void dispose() {
    _relogioDaEspera?.cancel();
    _online.removeListener(_aoMudarOTransporte);
    super.dispose();
  }
}
