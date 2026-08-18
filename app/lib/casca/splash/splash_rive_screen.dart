// splash_rive_screen.dart — a abertura alternativa, animada na Rive.
//
// ===========================================================================
// A REGRA QUE GOVERNA ESTE ARQUIVO
// ===========================================================================
//
// A ANIMAÇÃO NÃO MANDA EM NADA. Ela não decide destino, não conhece sessão, não
// sabe se existe alguém logado e não empurra rota quando opera pela casca. Ela
// é apresentação, e o único fato que produz é "a abertura terminou".
//
// Quem decide o destino continua sendo `casca_de_producao.dart`, lendo a sessão
// canônica. Esta tela é intercambiável com `screens/splash_oficial_screen.dart`
// justamente porque as duas dizem a MESMA frase para a casca, pelo mesmo
// contrato — é isso que torna a comparação A/B uma comparação, e não duas
// arquiteturas diferentes disputando.
//
// ---------------------------------------------------------------------------
// O RELÓGIO É QUEM CONCLUI, E NUNCA A ANIMAÇÃO
// ---------------------------------------------------------------------------
//
// Este é o coração do arquivo, e é a diferença entre uma abertura e um
// travamento. A conclusão é disparada por um [Timer] de [duracao], armado no
// `initState`, ANTES de qualquer carregamento — e nada no caminho da Rive pode
// atrasá-lo, cancelá-lo ou substituí-lo.
//
// Amarrar a conclusão ao fim da animação seria o desenho natural, e é o errado:
// uma arte que não carrega nunca termina, uma arte em laço nunca termina, um
// runtime que trava nunca termina — e cada um desses vira um aplicativo que
// abre e fica parado, sem nada para apertar. Com o relógio, o pior caso da Rive
// é uma abertura FEIA, com o fallback no lugar da arte. Nunca uma abertura
// eterna.
//
// E o relógio conclui a APRESENTAÇÃO, não a autenticação: ele diz "pode passar
// para a próxima tela", e quem escolhe qual é ela lê a sessão. Um timer que
// decidisse destino seria um segundo dono de sessão com cara de animação.
//
// ---------------------------------------------------------------------------
// NUNCA HÁ TELA BRANCA
// ---------------------------------------------------------------------------
//
// O fallback estático não é o plano B: ele é o que está desenhado desde o
// primeiro quadro. A arte da Rive entra POR CIMA quando (e se) ficar pronta.
// Um construtor que devolvesse vazio enquanto carrega produziria um piscar
// branco no arranque frio — que é justamente quando o carregamento demora mais.

import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import 'fonte_da_animacao_rive.dart';

/// O que aconteceu numa execução da abertura.
///
/// Existe para MEDIR sem escrever em registro de saída — a casca é uma das
/// camadas em que isso é proibido, e com razão: é por ali que credencial e
/// identidade vazam. Quem quiser instrumentar passa
/// [SplashRiveScreen.onMedicao] e recebe isto uma vez, na conclusão.
@immutable
class MedicaoDaSplashRive {
  const MedicaoDaSplashRive({
    required this.ateAArte,
    required this.total,
    required this.usouFallback,
    required this.motivoDaFalha,
  });

  /// Quanto levou até a arte estar desenhável. Nulo quando ela nunca ficou.
  final Duration? ateAArte;

  /// Quanto durou a abertura inteira, do primeiro quadro à conclusão.
  final Duration total;

  /// A abertura terminou mostrando o fallback estático.
  final bool usouFallback;

  /// Por que a arte não entrou. Nulo quando ela entrou.
  final String? motivoDaFalha;
}

/// A abertura alternativa: arte da Rive por cima, fallback estático por baixo.
///
/// O contrato é o mesmo de `SplashOficialScreen`, e de propósito — ver o
/// cabeçalho. Exatamente um entre [proximaTela] e [onConcluida] é obrigatório.
class SplashRiveScreen extends StatefulWidget {
  const SplashRiveScreen({
    super.key,
    this.proximaTela,
    this.onConcluida,
    this.habilitarSom = true,
    this.duracao = const Duration(milliseconds: 3800),
    this.fonte = const FonteRiveIndisponivel(),
    this.onMedicao,
  }) : assert(
         (proximaTela == null) != (onConcluida == null),
         'informe proximaTela OU onConcluida, nunca os dois',
       );

  /// A splash empurra o destino sozinha. Modo antigo.
  final Widget? proximaTela;

  /// A splash AVISA que terminou e não navega. É o modo que a casca usa.
  final VoidCallback? onConcluida;

  final bool habilitarSom;

  /// Quanto dura a abertura. É ISTO que conclui — não a animação.
  ///
  /// O padrão é o mesmo da abertura oficial. Uma alternativa que durasse
  /// diferente não seria comparável com ela.
  final Duration duracao;

  /// De onde a arte vem.
  ///
  /// O padrão é [FonteRiveIndisponivel] — que falha na hora, sem tocar em
  /// pacote nenhum. Não é descuido: quem monta a tela é
  /// `casca_de_producao.dart`, e é ela que injeta a fonte de verdade quando a
  /// variante da Rive foi pedida no build. Com o padrão inerte, um uso
  /// distraído desta tela desenha o fallback em vez de arrastar o runtime
  /// nativo da Rive para dentro de um binário que não pediu por ele.
  final FonteDaAnimacaoRive fonte;

  /// Chamado uma vez, quando a abertura termina.
  final void Function(MedicaoDaSplashRive)? onMedicao;

  @override
  State<SplashRiveScreen> createState() => _SplashRiveScreenState();
}

class _SplashRiveScreenState extends State<SplashRiveScreen> {
  static const _fundo = Color(0xFF120A06);
  static const _ouro = Color(0xFFEFB94A);
  static const _ouroClaro = Color(0xFFF6E2A6);

  /// O relógio que conclui a abertura. Não é cancelável por falha nenhuma.
  Timer? _relogio;

  final Stopwatch _cronometro = Stopwatch();

  AnimacaoRivePronta? _arte;
  String? _motivoDaFalha;
  Duration? _ateAArte;

  AudioPlayer? _audio;
  bool _concluiu = false;

  @override
  void initState() {
    super.initState();
    _cronometro.start();

    // ARMADO PRIMEIRO, e de propósito: se o carregamento abaixo lançasse de
    // forma síncrona, o relógio já estaria de pé e a abertura ainda terminaria.
    _relogio = Timer(widget.duracao, _concluir);

    unawaited(_tocarSom());
    unawaited(_carregarArte());
  }

  Future<void> _tocarSom() async {
    if (!widget.habilitarSom) return;
    try {
      final audio = _audio = AudioPlayer();
      await audio.play(AssetSource('splash/splash_intro.mp3'), volume: 0.52);
    } catch (_) {
      // A abertura nunca deve ser impedida por falha de áudio.
    }
  }

  /// Carrega a arte UMA VEZ.
  ///
  /// Roda no `initState`, e o `State` sobrevive às reconstruções da casca por
  /// causa da chave que ela usa ao montar esta tela. Reconstruir a árvore não
  /// relê o arquivo.
  Future<void> _carregarArte() async {
    try {
      final pronta = await widget.fonte.carregar();
      if (!mounted) {
        // Ninguém mais vai desenhar isto, e o que foi alocado é meu.
        pronta.descartar();
        return;
      }
      setState(() {
        _arte = pronta;
        _ateAArte = _cronometro.elapsed;
      });
    } on FalhaAoCarregarRive catch (falha) {
      if (!mounted) return;
      setState(() => _motivoDaFalha = falha.motivo);
    } catch (erro) {
      // A porta promete só `FalhaAoCarregarRive`. Se aparecer outra coisa, a
      // abertura ainda assim não pode cair — o fallback cobre o desconhecido
      // pelo mesmo motivo que cobre o conhecido.
      if (!mounted) return;
      setState(() => _motivoDaFalha = 'falha inesperada: $erro');
    }
  }

  void _concluir() {
    if (_concluiu || !mounted) return;
    _concluiu = true;
    _cronometro.stop();

    widget.onMedicao?.call(
      MedicaoDaSplashRive(
        ateAArte: _ateAArte,
        total: _cronometro.elapsed,
        usouFallback: _arte == null,
        motivoDaFalha: _motivoDaFalha,
      ),
    );

    // Não esperado: um `await` aqui seguraria a abertura pelo tempo do plugin
    // de áudio, que em ambiente sem plugin nunca responde.
    unawaited(_pararSom());

    final proxima = widget.proximaTela;
    if (proxima == null) {
      // O MODO DA CASCA. A tela avisa e para por aqui — quem decide o destino
      // lê a sessão, e não esta animação.
      widget.onConcluida!.call();
      return;
    }
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, _, _) => proxima,
        transitionsBuilder: (_, animacao, _, filho) =>
            FadeTransition(opacity: animacao, child: filho),
        transitionDuration: const Duration(milliseconds: 420),
      ),
    );
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
    _relogio?.cancel();
    _arte?.descartar();
    _audio?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final arte = _arte;
    return Scaffold(
      backgroundColor: _fundo,
      body: SizedBox.expand(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // SEMPRE desenhado. É o que garante que não existe quadro branco,
            // nem no arranque frio nem quando a arte falha.
            const _FallbackEstatico(),
            if (arte != null)
              // A arte entra por cima quando fica pronta, num desvanecer para
              // que a troca não seja um salto.
              _EntradaSuave(child: Builder(builder: arte.construir)),
          ],
        ),
      ),
    );
  }
}

/// A abertura desenhada sem depender de pacote nenhum.
///
/// Usa o logo que a abertura oficial já usa e que já vai no pacote de assets:
/// um fallback que dependesse de um asset NOVO teria o mesmo modo de falha que
/// ele existe para cobrir.
class _FallbackEstatico extends StatelessWidget {
  const _FallbackEstatico();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.18),
          radius: 1.05,
          colors: [Color(0xFF2A1A0A), Color(0xFF120A06)],
        ),
      ),
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // `errorBuilder` porque um fallback que quebra por asset ausente
              // não é fallback. Aqui embaixo não há mais rede de segurança.
              Image(
                image: AssetImage('assets/splash/logo_splash_oficial.webp'),
                width: 208,
                fit: BoxFit.contain,
                errorBuilder: _semLogo,
              ),
              SizedBox(height: 22),
              Text(
                'BURACO MASTER VIP',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _SplashRiveScreenState._ouroClaro,
                  fontSize: 17,
                  letterSpacing: 3.4,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _semLogo(BuildContext _, Object _, StackTrace? _) =>
      const Icon(
        Icons.workspace_premium,
        size: 96,
        color: _SplashRiveScreenState._ouro,
      );
}

/// Aparecimento em desvanecer, para a arte não surgir de um quadro para o outro.
class _EntradaSuave extends StatefulWidget {
  const _EntradaSuave({required this.child});

  final Widget child;

  @override
  State<_EntradaSuave> createState() => _EntradaSuaveState();
}

class _EntradaSuaveState extends State<_EntradaSuave>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  )..forward();

  @override
  void dispose() {
    _controle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      FadeTransition(opacity: _controle, child: widget.child);
}

/// A fonte que não tem arte nenhuma para dar.
///
/// É o padrão de [SplashRiveScreen], e o que faz o padrão ser INERTE: montar a
/// tela sem escolher uma fonte desenha o fallback, sem tocar no runtime nativo.
class FonteRiveIndisponivel extends FonteDaAnimacaoRive {
  const FonteRiveIndisponivel();

  @override
  Future<AnimacaoRivePronta> carregar() async =>
      throw const FalhaAoCarregarRive('nenhuma fonte de arte foi configurada');
}
