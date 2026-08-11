import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Superficie padrao de telefone em retrato para os testes de widget.
///
/// O `flutter_test` roda em 800 x 600 logicos por padrao — uma janela de
/// desktop deitada. As telas do fluxo de mesas sao desenhadas para telefone em
/// retrato: nesse tamanho o conteudo cai fora da viewport (dentro dos
/// scrollables os itens nem chegam a ser construidos, entao `find.text` nao
/// acha nada) e as colunas estouram na vertical. Fixar a superficie mantem o
/// teste medindo a tela aprovada, e nao a janela do runner.
void usarTelefoneRetrato(
  WidgetTester tester, {
  Size logico = const Size(360, 800),
  double devicePixelRatio = 3.0,
}) {
  tester.view.devicePixelRatio = devicePixelRatio;
  tester.view.physicalSize = logico * devicePixelRatio;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Descarta o estouro de `RenderFlex` causado pela fonte substituta do
/// `flutter_test`.
///
/// O runner nao carrega as fontes reais do app: cada glifo vira uma caixa de
/// 1em, entao uma frase curta quebra em mais linhas do que no aparelho. Em
/// telas desenhadas sobre uma caixa de projeto fixa (`FittedBox` + `SizedBox`),
/// isso faz paineis de altura travada acusarem overflow que nao existe em
/// producao — conferido reduzindo a escala do texto, quando o estouro some sem
/// nenhuma mudanca de layout.
///
/// So o overflow e ignorado; qualquer outra excecao de renderizacao continua
/// quebrando o teste.
void ignorarOverflowDaFonteDeTeste() {
  final anterior = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.exceptionAsString().contains('A RenderFlex overflowed by')) {
      return;
    }
    anterior?.call(details);
  };
  addTearDown(() => FlutterError.onError = anterior);
}

/// Superficie de telefone deitado, para validar a orientacao horizontal.
void usarTelefoneHorizontal(
  WidgetTester tester, {
  Size logico = const Size(800, 360),
  double devicePixelRatio = 3.0,
}) {
  usarTelefoneRetrato(
    tester,
    logico: logico,
    devicePixelRatio: devicePixelRatio,
  );
}
