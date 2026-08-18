// variante_de_splash.dart — QUAL abertura o aplicativo mostra.
//
// ---------------------------------------------------------------------------
// POR QUE ISTO EXISTE
// ---------------------------------------------------------------------------
//
// Há duas aberturas no repositório, e as duas são para valer:
//
//   * [VarianteDeSplash.oficial] — `screens/splash_oficial_screen.dart`, a que
//     está publicada hoje: animação desenhada em Flutter, sem asset externo
//     além do logo e do som.
//   * [VarianteDeSplash.rive] — `casca/splash/splash_rive_screen.dart`, a
//     alternativa em avaliação: a arte animada no editor da Rive.
//
// A ESCOLHA NÃO É AUTOMÁTICA, e o padrão é a oficial. Trocar a abertura de
// produção é decisão de quem toca o produto, tomada depois de olhar as duas —
// não efeito colateral de esta OS ter entrado. Enquanto a decisão não for
// tomada, quem quiser ver a alternativa pede por configuração de build.
//
// ---------------------------------------------------------------------------
// COMO PEDIR A ALTERNATIVA
// ---------------------------------------------------------------------------
//
//   flutter run   --dart-define=BMV_SPLASH=rive
//   flutter build apk --dart-define=BMV_SPLASH=rive
//
// `String.fromEnvironment` é resolvido em tempo de COMPILAÇÃO, então a variante
// de um binário é um fato dele, e não um estado que possa virar no meio de uma
// execução.
//
// O QUE ISSO NÃO GARANTE, para ninguém supor demais: a dependência da Rive
// entra no artefato dos dois lados, e o efeito disso no TAMANHO do APK não foi
// medido nesta OS. O que o padrão evita é o custo de EXECUÇÃO — no build
// oficial, `FonteRiveReal` nunca é instanciada e o runtime nativo nunca sobe.
//
// Valor desconhecido cai na oficial de propósito: um erro de digitação no
// comando de build não pode trocar a abertura do aplicativo publicado.

/// Qual abertura mostrar.
enum VarianteDeSplash {
  /// A abertura publicada hoje. É o padrão, e continua sendo.
  oficial,

  /// A alternativa em avaliação, animada na Rive.
  rive,
}

/// O nome da variante pedido no build. Vazio quando ninguém pediu nada.
///
/// Público para que o portão possa afirmar o padrão sem reescrever a string —
/// uma segunda cópia literal é exatamente como um padrão trocado passa sem
/// ninguém ver.
const String kChaveDeBuildDaSplash = 'BMV_SPLASH';

const String _pedidoNoBuild = String.fromEnvironment(kChaveDeBuildDaSplash);

/// A variante que ESTE binário vai usar.
const VarianteDeSplash varianteDeSplashDoBuild = _pedidoNoBuild == 'rive'
    ? VarianteDeSplash.rive
    : VarianteDeSplash.oficial;

/// Traduz o texto vindo do build numa variante.
///
/// Existe separada da constante acima porque a constante é resolvida na
/// compilação e não pode ser exercitada por teste nenhum: um teste que quisesse
/// provar "escrita errada cai na oficial" precisaria de um binário por caso.
/// Esta função tem a mesma regra e é chamável.
VarianteDeSplash varianteDeSplashDoTexto(String? texto) =>
    texto == 'rive' ? VarianteDeSplash.rive : VarianteDeSplash.oficial;
