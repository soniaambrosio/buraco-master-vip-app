// abertura_rive.dart — a ÚNICA porta do aplicativo para o runtime da Rive.
//
// ---------------------------------------------------------------------------
// POR QUE UM ARQUIVO SÓ
// ---------------------------------------------------------------------------
//
// `package:rive` é importado aqui e em lugar nenhum mais. Não é organização: é
// contenção. O runtime desta versão é NATIVO (FFI, biblioteca dinâmica baixada
// no build), e um `import 'package:rive/rive.dart'` espalhado por telas faria
// duas coisas ruins de uma vez — tornaria cada uma delas impossível de rodar em
// `flutter test`, e transformaria a decisão de trocar de runtime numa caçada.
//
// A suíte afirma esta contenção, então ela continua valendo depois desta OS.
//
// ---------------------------------------------------------------------------
// O QUE ESTA CAMADA DECIDE, E O QUE ELA NÃO DECIDE
// ---------------------------------------------------------------------------
//
// Ela decide: qual artboard, qual timeline, como a arte é ajustada à janela e
// quando a timeline terminou.
//
// Ela NÃO decide: quanto tempo a abertura fica na tela, o que vem depois, nem
// se a falha dela impede alguém de entrar. Isso é da tela, e da casca.

import 'dart:async';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart';
import 'package:rive/rive.dart' as rive;

import 'contrato_da_abertura.dart';

/// A fonte real: lê o `.riv` do bundle e o entrega desenhável.
class AberturaRive implements FonteDaAbertura {
  const AberturaRive();

  @override
  Future<AberturaCarregada> carregar() async {
    final rive.File arquivo;
    try {
      final dados = await rootBundle.load(kAssetDaAbertura);
      final decodificado = await rive.File.decode(
        dados.buffer.asUint8List(dados.offsetInBytes, dados.lengthInBytes),
        riveFactory: rive.Factory.flutter,
      );
      if (decodificado == null) throw FalhaDaAbertura.arteNaoCarregou;
      arquivo = decodificado;
    } on FalhaDaAbertura {
      rethrow;
    } catch (_) {
      // Asset ausente, bytes corrompidos, imagem embutida que não decodifica,
      // biblioteca nativa que não subiu — para quem chama é tudo a mesma coisa:
      // não há arte, e a abertura segue pelo fundo estático.
      throw FalhaDaAbertura.arteNaoCarregou;
    }

    // PELO NOME, e não pela posição. Ver `contrato_da_abertura.dart`.
    final artboard = arquivo.artboard(kArtboardDaAbertura);
    if (artboard == null) {
      arquivo.dispose();
      throw FalhaDaAbertura.artboardAusente;
    }

    // A timeline é resolvida AGORA, e não no primeiro quadro: descobrir que ela
    // não existe já com a tela no ar significaria um artboard parado no quadro
    // zero, que é pior do que o fundo estático — parece que travou.
    final animacao = artboard.animationNamed(kTimelineDaAbertura);
    if (animacao == null) {
      artboard.dispose();
      arquivo.dispose();
      throw FalhaDaAbertura.timelineAusente;
    }

    return _AberturaRiveCarregada(arquivo, artboard, animacao);
  }
}

class _AberturaRiveCarregada implements AberturaCarregada {
  _AberturaRiveCarregada(this._arquivo, this._artboard, rive.Animation animacao)
    : _pintor = _PintorDaTimeline(animacao) {
    _pintor.aoTerminar = _marcarConcluida;
  }

  final rive.File _arquivo;
  final rive.Artboard _artboard;
  final _PintorDaTimeline _pintor;
  final Completer<void> _fim = Completer<void>();

  bool _descartada = false;

  @override
  Future<void> get concluida => _fim.future;

  void _marcarConcluida() {
    if (!_fim.isCompleted) _fim.complete();
  }

  @override
  Widget desenhar() => rive.RiveArtboardWidget(
    artboard: _artboard,
    painter: _pintor,
  );

  @override
  void descartar() {
    if (_descartada) return;
    _descartada = true;
    // A ordem importa: o pintor segura a instância da animação, que é filha do
    // artboard, que é filho do arquivo.
    _pintor.dispose();
    _artboard.dispose();
    _arquivo.dispose();
    // Quem espera `concluida` não pode ficar pendurado para sempre num objeto
    // que já morreu.
    _marcarConcluida();
  }
}

/// Toca UMA timeline nomeada e avisa quando ela chega ao fim.
///
/// A alternativa pronta do pacote (`SingleAnimationPainter`) resolve a animação
/// por nome a cada troca de artboard e não expõe o término — e é exatamente o
/// término que esta abertura precisa saber.
final class _PintorDaTimeline extends rive.BasicArtboardPainter {
  _PintorDaTimeline(this._animacao)
    : super(fit: rive.Fit.contain, alignment: Alignment.center);

  final rive.Animation _animacao;

  VoidCallback? aoTerminar;
  bool _terminou = false;
  bool _descartado = false;

  @override
  bool advance(double elapsedSeconds) {
    if (_descartado) return false;

    final continua = _animacao.advanceAndApply(elapsedSeconds);

    // DUAS CONDIÇÕES, e não uma. `advanceAndApply` devolvendo `false` é o sinal
    // normal de fim numa reprodução única; a comparação com a duração cobre o
    // caso em que o quadro é longo o bastante para passar do fim e a
    // implementação ainda relatar movimento.
    if (!_terminou && (!continua || _animacao.time >= _animacao.duration)) {
      _terminou = true;
      // Fora da pilha do quadro: avisar durante o `advance` chamaria `setState`
      // de dentro da fase de layout da árvore.
      scheduleMicrotask(() => aoTerminar?.call());
    }

    return continua;
  }

  @override
  void dispose() {
    if (_descartado) return;
    _descartado = true;
    aoTerminar = null;
    _animacao.dispose();
    super.dispose();
  }
}
