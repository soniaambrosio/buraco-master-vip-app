// fonte_da_animacao_rive.dart — a PORTA ESTREITA por onde a Rive entra.
//
// ---------------------------------------------------------------------------
// POR QUE UMA PORTA, E NÃO O PACOTE DIRETO NA TELA
// ---------------------------------------------------------------------------
//
// A OS exige provar quatro coisas que só acontecem quando o mundo está errado:
// a animação FALHA, ela DEMORA, o arquivo está AUSENTE, o runtime LANÇA. Nada
// disso se produz de dentro de um `flutter test` com o pacote de verdade — o
// runtime da Rive ou carrega ou não carrega, e não aceita instruções sobre como
// falhar.
//
// Então a tela não conhece a Rive. Ela conhece esta porta, que tem UM método, e
// recebe a implementação de verdade por padrão. Os testes passam uma fonte que
// falha na hora, uma que nunca responde, uma que responde tarde demais — e a
// tela é exercitada de verdade, não simulada.
//
// A SEGUNDA RAZÃO é de contenção: `package:rive` é importado num arquivo só do
// repositório inteiro (`fonte_rive_real.dart`), e o portão afirma isso. Uma
// dependência em avaliação não deve se espalhar pela casca antes de alguém
// decidir se ela fica.

import 'package:flutter/widgets.dart';

/// Onde a arte animada mora dentro do pacote de assets.
///
/// Constante pública porque o portão a afirma e o `pubspec` a declara: uma
/// segunda cópia literal do caminho é como um asset renomeado passa despercebido
/// até alguém abrir o aplicativo publicado.
const String kAssetDaSplashRive = 'assets/splash/splash.riv';

/// A animação carregada e pronta para desenhar.
///
/// Guarda um CONSTRUTOR, e não um widget pronto, porque quem desenha é o
/// `build` da tela — e ele roda muitas vezes.
@immutable
class AnimacaoRivePronta {
  const AnimacaoRivePronta({required this.construir, required this.descartar});

  /// Desenha a animação.
  final WidgetBuilder construir;

  /// Devolve ao sistema o que o carregamento tomou.
  ///
  /// Chamado uma vez, no descarte da tela. A porta não é dona do ciclo de vida
  /// da tela; a tela é dona do que a porta entregou.
  final VoidCallback descartar;
}

/// A animação não pôde ser carregada.
///
/// É a ÚNICA falha que esta porta promete: quem implementa converte para cá
/// tudo o que o mundo real fizer de errado — arquivo ausente, bytes corrompidos,
/// runtime que não sobe, artboard que não existe. A tela trata um caso só, e é
/// por isso que ela não tem como esquecer de tratar um deles.
class FalhaAoCarregarRive implements Exception {
  const FalhaAoCarregarRive(this.motivo);

  final String motivo;

  @override
  String toString() => 'FalhaAoCarregarRive: $motivo';
}

/// De onde a abertura em Rive vem.
abstract class FonteDaAnimacaoRive {
  const FonteDaAnimacaoRive();

  /// Prepara o runtime e carrega a arte.
  ///
  /// Lança [FalhaAoCarregarRive] quando não dá. NÃO devolve nulo: um retorno
  /// nulo obrigaria a tela a distinguir "não carregou" de "carregou vazio", e
  /// essa é exatamente a distinção que ninguém lembra de fazer.
  Future<AnimacaoRivePronta> carregar();
}
