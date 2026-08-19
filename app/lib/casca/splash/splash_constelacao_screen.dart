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
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart'
    show MaterialTapTargetSize, Scaffold, TextButton;
import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

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

  /// Os bytes do SVG da constelação. Nulo = não entrou, e a abertura segue.
  Uint8List? _constelacao;

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

  Duration get _fadeDaConstelacao =>
      widget.duracao * kProporcaoDoFadeDaConstelacao;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Uma vez por montagem. `didChangeDependencies` roda de novo a cada mudança
    // de MediaQuery — uma rotação de tela no meio da abertura recarregaria a
    // arte e rearmaria o relógio se não houvesse esta trava.
    if (_comecou) return;
    _comecou = true;

    _movimentoReduzido = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    // A constelação é carregada nos DOIS ramos, inclusive com movimento
    // reduzido: ela é imagem parada, não animação. O que o movimento reduzido
    // desliga é o fade, não a camada.
    unawaited(_carregarConstelacao());

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

  /// Lê o SVG da constelação pelo bundle da árvore.
  ///
  /// Por `DefaultAssetBundle`, e não pelo `rootBundle`: é a costura padrão do
  /// Flutter para trocar o bundle num teste, e é ela que torna provável — em
  /// vez de afirmável — que um SVG ausente ou corrompido NÃO impede a abertura
  /// de terminar. Sem isso, o único jeito de exercitar essa falha seria apagar
  /// o arquivo do repositório.
  Future<void> _carregarConstelacao() async {
    try {
      final dados = await DefaultAssetBundle.of(
        context,
      ).load(kAssetDaConstelacao);
      if (!mounted) return;
      setState(() {
        _constelacao = dados.buffer.asUint8List(
          dados.offsetInBytes,
          dados.lengthInBytes,
        );
      });
    } catch (_) {
      // A constelação é camada COMPLEMENTAR. Sem ela a abertura perde brilho,
      // não perde função: o relógio, a timeline e o portão duplo seguem iguais.
      // Nada é escrito em registro — ver a nota sobre observabilidade no
      // carregamento da arte.
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
  ///
  /// Três coisas chegam aqui — a timeline, o relógio de segurança e a jogadora
  /// pelo botão de pular — e a PRIMEIRA delas é a que vale. A trava não é
  /// detalhe de implementação: sem ela, pular no mesmo quadro em que a timeline
  /// termina avisaria a casca duas vezes, e a casca montaria a tela seguinte
  /// duas vezes.
  void _encerrarAnimacao() {
    if (_concluiu || !mounted) return;
    // Dentro do `setState` porque o botão sai da árvore quando não há mais o
    // que pular: um controle que continua na tela sem fazer nada é pior do
    // que nenhum.
    setState(() => _concluiu = true);
    _relogioDeSeguranca?.cancel();
    _relogioDeSeguranca = null;
    unawaited(_pararSom());
    widget.onConcluida();
  }

  /// A jogadora pediu para pular. Mesma saída, e nenhuma saída própria.
  ///
  /// Ela NÃO decide destino e não encurta o portão duplo: pular marca "animação
  /// encerrada" e nada mais. Se o bootstrap ainda não respondeu, esta tela
  /// continua no ar — pular a abertura nunca pode inventar uma sessão.
  ///
  /// O foco sai ANTES da saída. O botão vai deixar a árvore no quadro seguinte,
  /// e um nó de foco que morre montado deixa o leitor de tela apontando para um
  /// controle que não existe mais. Devolver o foco ao escopo é o que esta tela
  /// pode fazer sem conhecer a rota seguinte — quem monta a rota é a casca.
  void _pular() {
    if (_concluiu) return;
    FocusManager.instance.primaryFocus?.unfocus();
    _encerrarAnimacao();
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
    final constelacao = _constelacao;

    return Scaffold(
      // Sem AppBar e sem indicador de carregamento: durante a abertura não
      // existe nada além da arte e da única ação que a abertura oferece.
      backgroundColor: kFundoDaAbertura,
      // O QUE A ABERTURA DIZ, e uma vez só.
      //
      // `explicitChildNodes` é o que impede este rótulo de ENGOLIR o botão:
      // sem ele o nó do contêiner absorveria o filho, e o leitor de tela
      // anunciaria uma frase só, sem ação nenhuma para acionar. Com ele saem
      // dois nós — o estado da abertura, e o botão com o nome e o papel dele.
      //
      // E não é `liveRegion`: região viva reanuncia a cada mudança da árvore, e
      // esta árvore muda a cada quadro do fade da constelação. Seria a abertura
      // falando por cima de si mesma até o fim.
      body: Semantics(
        container: true,
        explicitChildNodes: true,
        label: kRotuloDaAbertura,
        child: ColoredBox(
          color: kFundoDaAbertura,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // A ARTE É DECORAÇÃO, e decoração não se lê. O que ela mostra já
              // está dito em [kRotuloDaAbertura]; deixá-la na árvore só criaria
              // nós sem nome para o leitor atravessar antes de chegar ao botão.
              if (arte != null) ExcludeSemantics(child: arte.desenhar()),

            // A CONSTELAÇÃO VAI POR CIMA, e não por baixo. Não é preferência:
            // o artboard da Rive pinta fundo opaco em toda a sua área, então
            // uma camada por baixo seria coberta e o defeito continuaria — só
            // que agora com um asset a mais no APK fingindo que foi resolvido.
            //
            // `IgnorePointer` porque a abertura não é interativa: a camada não
            // pode passar a engolir toque nenhum.
            //
            // Mesma caixa da Rive: viewBox 1080 × 1920, `contain`, centralizado.
            // É o que faz as duas coincidirem em qualquer proporção de tela em
            // vez de escorregarem uma em relação à outra.
              if (constelacao != null)
                IgnorePointer(
                  child: ExcludeSemantics(
                    child: _ComFadeSutil(
                      duracao: _movimentoReduzido
                          ? Duration.zero
                          : _fadeDaConstelacao,
                      // A MÁSCARA É SÓ DESTA CAMADA. Ela não toca a Rive, não
                      // desloca nem redimensiona nada, e o `.svg` continua byte
                      // a byte o aprovado — é recorte de composição, e só.
                      child: ClipPath(
                        clipper: const MascaraDaConstelacao(),
                        child: SvgPicture.memory(
                          constelacao,
                          fit: BoxFit.contain,
                          alignment: Alignment.center,
                        ),
                      ),
                    ),
                  ),
                ),

              // A ÚNICA AÇÃO DA ABERTURA, e ela existe desde o primeiro quadro.
              //
              // Não espera a arte carregar, não espera fração nenhuma da
              // animação e não se esconde atrás de gesto adivinhado: enquanto
              // houver abertura para pular, o botão está lá, com nome, papel e
              // alvo medido. Sai da árvore quando não há mais o que pular.
              //
              // `Positioned.fill` não engole toque: as caixas de alinhamento e
              // de espaçamento só respondem onde o filho está, e é por isso que
              // a área vazia continua sendo área vazia.
              if (!_concluiu)
                Positioned.fill(
                  child: SafeArea(
                    child: Align(
                      alignment: Alignment.bottomRight,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: _BotaoDePular(onPular: _pular),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
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

/// Onde a constelação não é desenhada.
///
/// Reproduz, na conta, exatamente o que `BoxFit.contain` faz com a arte: a
/// mesma escala e o mesmo deslocamento centralizado. É isso que faz a exclusão
/// continuar em cima das letras num telefone estreito, numa tela alta e numa
/// tela larga — e não só nos 1080 × 1920 em que ela foi medida.
///
/// Ver [kExclusoesDaConstelacao] para a medição que definiu as caixas.
class MascaraDaConstelacao extends CustomClipper<Path> {
  const MascaraDaConstelacao();

  @override
  Path getClip(Size tamanho) {
    // A MESMA conta do `contain` da arte: encaixa o canvas inteiro dentro da
    // janela, preservando a proporção, e centraliza o que sobra.
    final escala = math.min(
      tamanho.width / kCanvasDaAbertura.width,
      tamanho.height / kCanvasDaAbertura.height,
    );
    final desenhada = Size(
      kCanvasDaAbertura.width * escala,
      kCanvasDaAbertura.height * escala,
    );
    final origem = Offset(
      (tamanho.width - desenhada.width) / 2,
      (tamanho.height - desenhada.height) / 2,
    );

    var caminho = Path()..addRect(Offset.zero & tamanho);
    for (final area in kExclusoesDaConstelacao) {
      caminho = Path.combine(
        PathOperation.difference,
        caminho,
        Path()
          ..addRect(
            Rect.fromLTRB(
              origem.dx + area.left * escala,
              origem.dy + area.top * escala,
              origem.dx + area.right * escala,
              origem.dy + area.bottom * escala,
            ),
          ),
      );
    }
    return caminho;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// Um fade de entrada, e nada além disso.
///
/// Não é uma segunda animação controladora: ele não tem `AnimationController`
/// nosso, não guarda estado de apresentação, não avisa ninguém quando termina e
/// não move um pixel de geometria. A autoridade da duração da abertura continua
/// sendo a timeline da Rive — este widget só evita que a constelação apareça
/// num corte seco.
///
/// Com `Duration.zero` (movimento reduzido) ele entrega opacidade cheia no
/// primeiro quadro, sem animar nada.
class _ComFadeSutil extends StatelessWidget {
  const _ComFadeSutil({required this.duracao, required this.child});

  final Duration duracao;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (duracao == Duration.zero) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: duracao,
      curve: Curves.easeOut,
      builder: (_, opacidade, filho) =>
          Opacity(opacity: opacidade, child: filho),
      child: child,
    );
  }
}

/// "Pular abertura" — um botão de verdade, e não uma área sensível.
///
/// ---------------------------------------------------------------------------
/// POR QUE TEXTO VISÍVEL, E NÃO UM ÍCONE
/// ---------------------------------------------------------------------------
///
/// Um "»|" sozinho depende de a pessoa já conhecer a convenção, e é a primeira
/// coisa que a auditoria seguinte reprovaria. Com o rótulo escrito, o nome
/// falado e o nome lido são a MESMA string ([kRotuloDePular]) — o que também
/// faz o comando de voz funcionar dizendo exatamente o que está na tela.
///
/// ---------------------------------------------------------------------------
/// O ALVO É MEDIDO, NÃO ESTIMADO
/// ---------------------------------------------------------------------------
///
/// [MaterialTapTargetSize.padded] garante o piso de 48 dp mesmo quando o texto
/// desenhado é menor, e `minimumSize` o garante nas duas direções. Quem recebe
/// o toque é este botão inteiro, e é ele que a suíte mede — a diferença entre
/// medir o alvo e medir a pintura já custou um P0 neste repositório.
///
/// Teclado sai de graça, e não por acaso: um botão do Material é focável e
/// aciona no Enter e no espaço. É por isso que a ação é um botão, e não um
/// `GestureDetector` com `Semantics` pendurado em volta.
class _BotaoDePular extends StatelessWidget {
  const _BotaoDePular({required this.onPular});

  final VoidCallback onPular;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPular,
      style: TextButton.styleFrom(
        // Ouro claro sobre o azul da abertura: a mesma família da marca, e bem
        // acima do mínimo de contraste exigido para texto.
        foregroundColor: const Color(0xFFF6E2A6),
        backgroundColor: const Color(0xCC0A1430),
        minimumSize: const Size(kAlvoMinimoDePular * 2, kAlvoMinimoDePular),
        tapTargetSize: MaterialTapTargetSize.padded,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        shape: const StadiumBorder(side: BorderSide(color: Color(0x8CEFB94A))),
      ),
      child: const Text(
        kRotuloDePular,
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    );
  }
}
