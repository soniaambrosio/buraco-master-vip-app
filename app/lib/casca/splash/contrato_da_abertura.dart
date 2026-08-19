// contrato_da_abertura.dart — o que a abertura é, em nomes, e nada mais.
//
// ---------------------------------------------------------------------------
// POR QUE UM ARQUIVO SÓ DE CONTRATO
// ---------------------------------------------------------------------------
//
// A arte da abertura é um binário autoritativo: o artboard chama
// `SplashConstelacao`, a timeline chama `entrada_splash`, e os dois nomes
// existem DENTRO do arquivo. Um erro de digitação em qualquer um deles não
// quebra a compilação — ele devolve `null` no runtime da Rive, e o aplicativo
// abre no fundo estático sem ninguém saber por quê.
//
// Por isso os nomes moram aqui, uma vez, e a suíte varre `lib/` exigindo que
// nenhuma outra string igual apareça solta. É a diferença entre um contrato e
// uma convenção.
//
// ---------------------------------------------------------------------------
// A PORTA ESTREITA
// ---------------------------------------------------------------------------
//
// [FonteDaAbertura] existe porque o runtime da Rive é NATIVO: dentro de
// `flutter test` a biblioteca dinâmica não está presente e qualquer chamada a
// ela lança. Sem esta porta, os casos que importam — a corrida entre a callback
// e o fallback, a dupla notificação, o widget desmontado no meio — simplesmente
// não seriam testáveis, e a abertura chegaria ao aparelho da jogadora provada
// só por leitura.
//
// A porta é pequena de propósito: carregar, desenhar, avisar que terminou,
// devolver. Ela não conhece sessão, não conhece rota e não decide destino.

import 'package:flutter/widgets.dart';

/// Caminho do binário dentro do bundle. Declarado em `pubspec.yaml`.
const String kAssetDaAbertura =
    'assets/rive/splash_constelacao_master_vip_v2.riv';

/// A constelação, o SEGUNDO asset visual autoritativo.
///
/// Ela existe fora do `.riv` por uma razão medida, não por gosto: no projeto de
/// autoria a constelação está lá, mas ela NÃO entra na exportação da timeline
/// `entrada_splash`. O binário não pode ser tocado, então a camada que faltava
/// entra por cima, em vetor, com a MESMA área de referência 1080 × 1920 e o
/// mesmo ajuste `contain` — é isso que faz as duas coincidirem em qualquer
/// tela, em vez de "quase".
const String kAssetDaConstelacao =
    'assets/rive/constelacao_dourada_master_vip.svg';

/// Quanto dura o fade de entrada da constelação, em fração da abertura.
///
/// 3 s × 1/5 = 600 ms, no começo. É um fade e nada mais: ele não move
/// geometria, não conclui a abertura e não disputa autoridade com a timeline.
/// Proporcional pelo mesmo motivo do relógio de segurança — os testes encurtam
/// a abertura, e um valor fixo faria cada caso esperar por nada.
const double kProporcaoDoFadeDaConstelacao = 1 / 5;

/// O artboard, escolhido pelo NOME.
///
/// Nunca por posição: um reexport da arte pode reordenar os artboards, e a
/// abertura passaria a tocar outra coisa sem nenhum erro aparecer.
const String kArtboardDaAbertura = 'SplashConstelacao';

/// A timeline, escolhida pelo NOME.
///
/// A arte também traz um `State Machine 1` vazio. Ele NÃO é a autoridade desta
/// V1 — quem define a abertura é esta timeline, e é ela que tem duração.
const String kTimelineDaAbertura = 'entrada_splash';

/// Duração de autoria da timeline. Reprodução única, sem laço.
const Duration kDuracaoDaAbertura = Duration(seconds: 3);

/// O fundo da abertura, igual ao da arte.
///
/// Ele é pintado ANTES de a arte carregar e continua por baixo dela depois:
/// como o ajuste é `contain`, as faixas que sobram nas proporções que não são
/// 9:16 caem exatamente nesta cor e somem visualmente. É também esta cor que a
/// tela nativa do Android pinta, e é por isso que não existe piscar entre as
/// duas.
const Color kFundoDaAbertura = Color(0xFF050B1E);

/// Quanto o fallback espera ALÉM da duração de autoria antes de dar a animação
/// por encerrada sozinho.
///
/// É proporcional, e não um valor fixo, por uma razão prática: a casca encurta
/// a abertura nos testes de widget, e uma margem fixa de meio segundo faria
/// cada caso da suíte esperar meio segundo de relógio falso por nada. Na
/// duração real, 3 s × 7/6 = 3,5 s — exatamente o que a OS pede.
const double kProporcaoDoFallback = 7 / 6;

/// Janela curta de exibição quando a plataforma pede movimento reduzido.
///
/// Não é animação e não é laço: é o fundo estável no ar por um instante, para
/// a troca de tela não ser um corte seco. Continua não bloqueando nada — quem
/// libera a tela seguinte é o bootstrap, como sempre.
const double kProporcaoDeMovimentoReduzido = 1 / 5;

/// Por que a arte não entrou no ar.
///
/// Existe para o teste poder afirmar QUAL falha aconteceu. Não vai para log
/// nenhum: esta base não tem camada de observabilidade alcançável pela raiz, e
/// a OS proíbe criar uma concorrente só para isto.
enum FalhaDaAbertura {
  /// O runtime nativo não subiu, ou o arquivo não decodificou.
  arteNaoCarregou,

  /// Decodificou, mas não existe artboard com o nome do contrato.
  artboardAusente,

  /// Existe o artboard, mas não existe a timeline com o nome do contrato.
  timelineAusente,
}

/// A arte já carregada e pronta para desenhar.
abstract class AberturaCarregada {
  /// Desenha a arte. Chamado de dentro do `build`.
  Widget desenhar();

  /// Completa UMA vez, quando a timeline chega ao fim.
  ///
  /// Pode nunca completar — e é justamente por isso que existe o fallback.
  Future<void> get concluida;

  /// Devolve o que a arte reservou. Chamado no `dispose` da tela.
  void descartar();
}

/// De onde a abertura vem.
abstract class FonteDaAbertura {
  /// Carrega a arte.
  ///
  /// Lança [FalhaDaAbertura] quando não dá. Não devolve `null`: uma abertura
  /// que "carregou nada" e uma que falhou são estados diferentes, e confundir
  /// os dois foi o que fez a tela branca existir em tantos aplicativos.
  Future<AberturaCarregada> carregar();
}
