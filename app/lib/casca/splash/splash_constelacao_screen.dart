// splash_constelacao_screen.dart — a PRIMEIRA TELA FLUTTER do aplicativo.
//
// ---------------------------------------------------------------------------
// ELA NÃO É O SPLASH DO ANDROID
// ---------------------------------------------------------------------------
//
// O Android já mostrou a tela nativa antes de existir engine de Flutter. Esta
// tela entra DEPOIS, no primeiro quadro do Flutter, e a única coisa que garante
// que a troca não pisque é as duas serem da mesma cor: `kFundoDaAbertura` aqui,
// e a mesma cor configurada no `launch_background` do Android. Por isso o fundo
// é pintado no primeiro quadro, antes de a arte existir — nunca há um instante
// em que esta tela seja branca.
//
// ---------------------------------------------------------------------------
// ESTA TELA NÃO DECIDE DESTINO
// ---------------------------------------------------------------------------
//
// Ela avisa UMA vez que a abertura visual terminou, por [onConcluida], e para
// por aí. Quem decide entre Login e Home é `casca_de_producao.dart`, lendo a
// sessão — e é essa separação que faz o portão duplo existir:
//
//     animação encerrada  E  bootstrap pronto  E  ainda montado
//
// Se o bootstrap terminar primeiro, a casca continua desenhando esta tela até a
// animação acabar. Se a animação acabar primeiro, esta tela fica no ar com o
// último quadro (ou o fundo) enquanto a sessão não responde.
//
// ---------------------------------------------------------------------------
// O RELÓGIO DE SEGURANÇA, E O QUE ELE NÃO PODE FAZER
// ---------------------------------------------------------------------------
//
// Um runtime nativo pode não subir; uma callback de término pode não chegar.
// Sem rede de segurança isso vira um aplicativo aberto e parado — o pior
// defeito possível numa abertura, porque não há nada para apertar.
//
// O relógio é armado ANTES do carregamento e marca apenas "animação encerrada".
// Ele NÃO afirma bootstrap pronto: uma sessão que não respondeu continua não
// tendo respondido, e quem trata isso é o teto da casca, que mostra o estado
// explícito com saída.

import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart' show Scaffold;
import 'package:flutter/widgets.dart';

import 'abertura_rive.dart';
import 'contrato_da_abertura.dart';

class SplashConstelacaoScreen extends StatefulWidget {
  const SplashConstelacaoScreen({
    super.key,
    required this.onConcluida,
    this.fonte,
    this.duracao = kDuracaoDaAbertura,
    this.habilitarSom = true,
  });

  /// Avisa que a abertura VISUAL terminou. Chamada no máximo uma vez.
  final VoidCallback onConcluida;

  /// De onde a arte vem. Nula usa a fonte real da Rive.
  ///
  /// Nula em produção, e este é o ponto: quem monta esta tela no aplicativo
  /// publicado não escolhe nada, não injeta nada e não tem como trocar a arte
  /// sem querer — [AberturaRive] é construída AQUI, e este é o único lugar do
  /// repositório que a constrói. A porta existe porque o runtime da Rive é
  /// nativo e não sobe dentro de `flutter test`: sem ela, corrida, dupla
  /// notificação e desmontagem no meio não teriam como ser provadas.
  final FonteDaAbertura? fonte;

  /// Duração de autoria da timeline.
  ///
  /// NÃO é a autoridade do fim: quem termina a animação é a própria timeline.
  /// Este valor define só o horizonte do relógio de segurança, e é encurtado
  /// pelos testes de widget para a suíte não esperar segundos de verdade.
  final Duration duracao;

  final bool habilitarSom;

  @override
  State<SplashConstelacaoScreen> createState() =>
      _SplashConstelacaoScreenState();
}

class _SplashConstelacaoScreenState extends State<SplashConstelacaoScreen> {
  AberturaCarregada? _arte;
  FalhaDaAbertura? _falha;

  /// A plataforma pediu movimento reduzido nesta execução.
  bool _movimentoReduzido = false;

  AudioPlayer? _audio;
  Timer? _relogioDeSeguranca;

  bool _comecou = false;
  bool _concluiu = false;

  /// O horizonte do relógio de segurança.
  ///
  /// Proporcional à duração de autoria: 3 s × 7/6 = 3,5 s. Ver
  /// `kProporcaoDoFallback`.
  Duration get _horizonteDeSeguranca => widget.duracao * kProporcaoDoFallback;

  Duration get _janelaDeMovimentoReduzido =>
      widget.duracao * kProporcaoDeMovimentoReduzido;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Uma vez por montagem. `didChangeDependencies` roda de novo a cada mudança
    // de MediaQuery — uma rotação de tela no meio da abertura recarregaria a
    // arte e rearmaria o relógio se não houvesse esta trava.
    if (_comecou) return;
    _comecou = true;

    _movimentoReduzido = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    if (_movimentoReduzido) {
      // Sem laço e sem animação: o fundo estável fica no ar por uma janela
      // curta e a abertura se dá por encerrada. O bootstrap continua mandando.
      _relogioDeSeguranca = Timer(
        _janelaDeMovimentoReduzido,
        _encerrarAnimacao,
      );
      return;
    }

    // ARMADO ANTES DE CARREGAR, de propósito: se o carregamento travar, o
    // relógio já está correndo.
    _relogioDeSeguranca = Timer(_horizonteDeSeguranca, _encerrarAnimacao);

    unawaited(_tocarSom());
    unawaited(_carregarArte());
  }

  Future<void> _carregarArte() async {
    try {
      final arte = await (widget.fonte ?? const AberturaRive()).carregar();
      if (!mounted) {
        // Chegou tarde: a tela já saiu. Devolver aqui é o que impede o arquivo
        // e o artboard de vazarem numa abertura interrompida.
        arte.descartar();
        return;
      }
      setState(() => _arte = arte);
      unawaited(
        arte.concluida.then((_) {
          if (mounted) _encerrarAnimacao();
        }),
      );
    } on FalhaDaAbertura catch (falha) {
      if (!mounted) return;
      // O fundo estático já está na tela desde o primeiro quadro; guardar o
      // motivo serve à prova, não à apresentação. Não vai para registro nenhum:
      // esta base não tem observabilidade alcançável pela raiz, e a OS proíbe
      // criar uma coletora concorrente só para isto.
      setState(() => _falha = falha);
    }
  }

  Future<void> _tocarSom() async {
    if (!widget.habilitarSom) return;
    try {
      final audio = _audio = AudioPlayer();
      await audio.play(AssetSource('splash/splash_intro.mp3'), volume: 0.52);
    } catch (_) {
      // A abertura nunca pode ser impedida por falha de áudio.
    }
  }

  /// O único caminho para "a animação acabou". Idempotente por construção.
  void _encerrarAnimacao() {
    if (_concluiu || !mounted) return;
    _concluiu = true;
    _relogioDeSeguranca?.cancel();
    _relogioDeSeguranca = null;
    unawaited(_pararSom());
    widget.onConcluida();
  }

  Future<void> _pararSom() async {
    try {
      await _audio?.stop();
    } catch (_) {
      // Mesma razão do `play`.
    }
  }

  @override
  void dispose() {
    _relogioDeSeguranca?.cancel();
    _relogioDeSeguranca = null;
    _arte?.descartar();
    _arte = null;
    _audio?.dispose();
    _audio = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final arte = _arte;
    return Scaffold(
      // Sem AppBar, sem indicador de carregamento e sem texto: durante a
      // abertura não existe nada além da arte.
      backgroundColor: kFundoDaAbertura,
      body: ColoredBox(
        color: kFundoDaAbertura,
        child: SizedBox.expand(child: arte?.desenhar()),
      ),
    );
  }

  /// Por que a arte não entrou. Existe para a suíte poder afirmar QUAL falha
  /// aconteceu, e não só que "algo deu errado".
  @visibleForTesting
  FalhaDaAbertura? get falha => _falha;

  @visibleForTesting
  bool get movimentoReduzido => _movimentoReduzido;
}
