// fonte_rive_real.dart — O ÚNICO arquivo do repositório que importa `rive`.
//
// Toda a superfície do pacote passa por aqui, e o portão
// (`test/casca/splash_rive_test.dart`) afirma que continua assim. A razão é
// contenção: a Rive está EM AVALIAÇÃO. Se a decisão for não ficar com ela, o
// que sai é este arquivo e a linha do `pubspec` — não uma caçada por imports
// espalhados pela casca.
//
// ---------------------------------------------------------------------------
// AS QUATRO MANEIRAS DE ISTO DAR ERRADO
// ---------------------------------------------------------------------------
//
// E todas as quatro terminam do mesmo jeito, em [FalhaAoCarregarRive], porque
// para a abertura do aplicativo elas SIGNIFICAM a mesma coisa — não há arte
// para desenhar, então desenhe o fallback e siga:
//
//   1. o runtime nativo não sobe (`init` devolve `false`, sem lançar);
//   2. o asset não está no pacote — é o caso de HOJE, e é esperado;
//   3. os bytes existem mas não decodificam;
//   4. o arquivo decodifica mas não tem artboard ou máquina de estados.
//
// O caso 2 merece nota: `assets/splash/splash.riv` AINDA NÃO EXISTE no
// repositório. A arte está sendo produzida. Esta implementação é a que vai
// recebê-la sem alteração nenhuma — e, até lá, ela falha limpo e o aplicativo
// abre pelo fallback, que é exatamente o comportamento que a OS exige provar.

import 'package:rive/rive.dart' as rive;

import 'fonte_da_animacao_rive.dart';

/// Carrega a abertura do pacote de assets, com o runtime de verdade.
class FonteRiveReal extends FonteDaAnimacaoRive {
  const FonteRiveReal({this.asset = kAssetDaSplashRive});

  /// Qual arte carregar. Parametrizado para que uma segunda arte possa ser
  /// comparada sem recompilar a tela.
  final String asset;

  @override
  Future<AnimacaoRivePronta> carregar() async {
    // `init` devolve `false` em vez de lançar quando não consegue subir — e um
    // `false` ignorado vira uma tela preta silenciosa lá na frente.
    final bool runtimeSubiu;
    try {
      runtimeSubiu = await rive.RiveNative.init();
    } catch (erro) {
      throw FalhaAoCarregarRive('o runtime da Rive não inicializou: $erro');
    }
    if (!runtimeSubiu) {
      throw const FalhaAoCarregarRive(
        'o runtime da Rive não inicializou neste dispositivo',
      );
    }

    final rive.File? arquivo;
    try {
      arquivo = await rive.File.asset(asset, riveFactory: rive.Factory.rive);
    } catch (erro) {
      // Asset ausente cai aqui: o `rootBundle` lança ao não achar a chave.
      throw FalhaAoCarregarRive('não consegui ler "$asset": $erro');
    }
    if (arquivo == null) {
      throw FalhaAoCarregarRive('"$asset" não decodificou como arte da Rive');
    }
    final arquivoCarregado = arquivo;

    // O controlador é quem escolhe artboard e máquina de estados, e é ele que
    // lança quando a arte não tem o que ele procura.
    final rive.RiveWidgetController controlador;
    try {
      controlador = rive.RiveWidgetController(arquivoCarregado);
    } catch (erro) {
      arquivoCarregado.dispose();
      throw FalhaAoCarregarRive('"$asset" não tem o que animar: $erro');
    }

    return AnimacaoRivePronta(
      construir: (_) => rive.RiveWidget(
        controller: controlador,
        // A abertura ocupa a tela inteira preservando a proporção da arte. Não
        // é `cover`: cortar a arte da abertura é decisão de quem a desenhou.
        fit: rive.Fit.contain,
      ),
      // A ORDEM IMPORTA: o controlador aponta para dentro do arquivo, e
      // descartar o arquivo primeiro deixaria o controlador com referência
      // pendurada.
      descartar: () {
        controlador.dispose();
        arquivoCarregado.dispose();
      },
    );
  }
}
