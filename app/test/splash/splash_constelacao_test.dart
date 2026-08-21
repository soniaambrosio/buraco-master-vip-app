// splash_constelacao_test.dart — a abertura em Rive, do binário ao roteamento.
//
// ---------------------------------------------------------------------------
// O QUE ESTA SUÍTE PROVA, E O QUE ELA NÃO PODE PROVAR
// ---------------------------------------------------------------------------
//
// PROVA, e sem depender de rede ou de aparelho:
//
//   * que o binário aprovado está no repositório, chega ao bundle e é o mesmo
//     arquivo — tamanho, cabeçalho e SHA-256 conferidos byte a byte;
//   * que os nomes `SplashConstelacao` e `entrada_splash` existem DENTRO do
//     binário e são exatamente as constantes que o código usa;
//   * que a saída da abertura só acontece com animação encerrada E bootstrap
//     pronto, em qualquer ordem, e no máximo uma vez;
//   * que arte que não carrega, callback repetida, corrida com o relógio de
//     segurança, tela desmontada e movimento reduzido têm comportamento
//     definido — e nenhum deles aprisiona a jogadora nem inventa sessão.
//
// NÃO PROVA, e o laudo diz isso com todas as letras: que o runtime nativo
// DESENHA a arte. `rive_native` é uma biblioteca dinâmica baixada no build da
// plataforma alvo; dentro de `flutter test` ela não existe. É por isso que a
// tela recebe a arte por uma porta (`FonteDaAbertura`) e a suíte injeta um
// dublê. A prova de desenho é de aparelho, e está registrada no laudo.
//
// A porta não pode ser contornada, e os três últimos casos do primeiro grupo
// existem só para afirmar isso: `package:rive` entra num arquivo só, a fonte
// real é construída num lugar só, e o padrão continua sendo a fonte real.

import 'dart:io';
import 'dart:ui' show Tristate;

// A implementação do escopo global do `audioplayers` mora neste pacote, que
// chega como dependência transitiva. O `ignore` é deliberado: declarar o
// pacote em `dev_dependencies` mexeria nas dependências da árvore, e esta OS
// não pode mexer. Ver [_EscopoGlobalDoAudio].
// ignore: depend_on_referenced_packages
import 'package:audioplayers_platform_interface/audioplayers_platform_interface.dart';
import 'package:buraco_master_vip/casca/home_de_producao.dart';
import 'package:buraco_master_vip/casca/login_de_producao.dart';
import 'package:buraco_master_vip/casca/raiz_do_aplicativo.dart';
import 'package:buraco_master_vip/casca/splash/contrato_da_abertura.dart';
import 'package:buraco_master_vip/casca/splash/splash_constelacao_screen.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../casca/abertura_falsa.dart';
import '../casca/bancada_online.dart';

// ===========================================================================
// O binário autoritativo, como a OS o declara
// ===========================================================================

const int kTamanhoAutoritativo = 2298957;
const String kSha256Autoritativo =
    'a5a7ca1912de6f301b8a5c022151c7f14d6ae07228fa9c9dd49076fb2ea4d67d';

/// O segundo asset visual autoritativo.
const int kTamanhoDaConstelacao = 4663;
const String kSha256DaConstelacao =
    'a87fc5ad2d25fef715d9db7556575b96cd180d99eebaac113607f3abcffc0204';

/// Bundle que entrega tudo, menos a constelação.
///
/// É a costura padrão do Flutter — `DefaultAssetBundle` — e é ela que torna
/// "um SVG ausente não impede a abertura de terminar" uma coisa PROVADA em vez
/// de afirmada. Sem ela, exercitar essa falha exigiria apagar o arquivo do
/// repositório.
class _BundleSemConstelacao extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) {
    if (key == kAssetDaConstelacao) {
      throw FlutterError('constelação indisponível');
    }
    return rootBundle.load(key);
  }
}

/// Superfície de telefone. Sem isto o teste desenha numa janela de mesa e a
/// medida de layout não diz nada sobre o aparelho de ninguém.
void _telefone(WidgetTester tester, {Size tamanho = const Size(1080, 1920)}) {
  tester.view.physicalSize = tamanho;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

/// Monta a abertura sozinha, com a arte vindo do dublê.
Future<int Function()> _montarAbertura(
  WidgetTester tester, {
  required AberturaFalsa fonte,
  Duration duracao = const Duration(milliseconds: 300),
  bool movimentoReduzido = false,
  bool som = false,
  TextScaler escalaDeTexto = TextScaler.noScaling,
  Size tamanho = const Size(1080, 1920),
  String chave = 'abertura',
  AssetBundle? bundle,
}) async {
  _telefone(tester, tamanho: tamanho);
  var saidas = 0;
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: movimentoReduzido,
            textScaler: escalaDeTexto,
          ),
          child: _talvezComBundle(
            bundle,
            SplashConstelacaoScreen(
              // A chave é o que impede a remontagem de REAPROVEITAR o State da
              // montagem anterior: sem ela, um caso que monta a tela duas vezes
              // mede a primeira montagem duas vezes e passa por engano.
              key: ValueKey<String>(chave),
              duracao: duracao,
              // Falso por padrão: os casos que NÃO tratam de som não têm por
              // que abrir um player. Quem prova a matriz de §11.2 liga isto e
              // escuta os canais reais do plugin — ver `_EscutaDoAudio`.
              habilitarSom: som,
              fonte: fonte,
              onConcluida: () => saidas++,
            ),
          ),
        ),
      ),
    ),
  );
  return () => saidas;
}

Widget _talvezComBundle(AssetBundle? bundle, Widget filho) =>
    bundle == null ? filho : DefaultAssetBundle(bundle: bundle, child: filho);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // =========================================================================
  // §8.1 — contrato do asset
  // =========================================================================
  group('ASSET — o binário aprovado, e nenhum outro', () {
    test('A01 o arquivo está no repositório', () {
      final f = File(kAssetDaAbertura);
      expect(
        f.existsSync(),
        isTrue,
        reason: '$kAssetDaAbertura não existe na árvore do aplicativo',
      );
      expect(f.lengthSync(), greaterThan(0));
    });

    test('A02 o asset está declarado no pubspec.yaml', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      // O diretório, e não um curinga amplo: `assets/` inteiro empacotaria
      // arte de prévia que não vai para o aplicativo publicado.
      expect(
        pubspec,
        contains('- assets/rive/'),
        reason:
            'sem a linha no pubspec o arquivo não entra no bundle, e a '
            'abertura abre no fundo estático sem nenhum erro de compilação',
      );
    });

    test('A03 o bundle do Flutter entrega o arquivo', () async {
      final dados = await rootBundle.load(kAssetDaAbertura);
      expect(dados.lengthInBytes, greaterThan(0));
    });

    test('A04 o cabeçalho é RIVE', () async {
      final dados = await rootBundle.load(kAssetDaAbertura);
      final cabecalho = String.fromCharCodes(
        dados.buffer.asUint8List(dados.offsetInBytes, 4),
      );
      expect(cabecalho, 'RIVE');
    });

    test('A05 tamanho e SHA-256 são os do binário aprovado', () async {
      final dados = await rootBundle.load(kAssetDaAbertura);
      final bytes = dados.buffer.asUint8List(
        dados.offsetInBytes,
        dados.lengthInBytes,
      );

      expect(
        bytes.length,
        kTamanhoAutoritativo,
        reason: 'o arquivo mudou de tamanho — foi reexportado ou recomprimido',
      );
      // `crypto` é dependência de DESENVOLVIMENTO. Calcular o hash aqui não
      // acrescenta um byte ao aplicativo publicado.
      expect(
        sha256.convert(bytes).toString(),
        kSha256Autoritativo,
        reason: 'o binário não é o aprovado',
      );
    });

    test('A06 os nomes do contrato existem DENTRO do binário', () async {
      final dados = await rootBundle.load(kAssetDaAbertura);
      final bytes = dados.buffer.asUint8List(
        dados.offsetInBytes,
        dados.lengthInBytes,
      );
      // O formato guarda os nomes como texto. Procurá-los nos bytes é a única
      // maneira de conferir o contrato sem o runtime nativo — e é uma prova
      // real: se alguém trocar o nome do artboard na constante, este caso cai.
      for (final nome in [kArtboardDaAbertura, kTimelineDaAbertura]) {
        expect(
          _contem(bytes, nome),
          isTrue,
          reason: '"$nome" não aparece dentro do .riv',
        );
      }
    });

    test('A07 nenhuma string divergente dos nomes do contrato em lib/', () {
      final infratores = <String>[];
      for (final f in _fontesDoCliente()) {
        final caminho = f.path.replaceAll(r'\', '/');
        if (caminho.endsWith('lib/casca/splash/contrato_da_abertura.dart')) {
          continue;
        }
        final conteudo = _semComentarios(f.readAsStringSync());
        for (final nome in [
          kArtboardDaAbertura,
          kTimelineDaAbertura,
          kAssetDaAbertura,
        ]) {
          // O nome como LITERAL, entre aspas. Sem as aspas, a classe
          // `SplashConstelacaoScreen` acusaria a si mesma — e o jeito de
          // "consertar" seria renomear a tela, que não é o defeito.
          if (conteudo.contains("'$nome'") || conteudo.contains('"$nome"')) {
            infratores.add('$caminho: $nome');
          }
        }
      }
      expect(
        infratores,
        isEmpty,
        reason:
            'nome do contrato escrito solto: um erro de digitação nele não '
            'quebra a compilação, devolve null no runtime e abre a tela vazia',
      );
    });

    test('A08 package:rive é importado num arquivo só', () {
      final importadores = <String>[];
      for (final f in _fontesDoCliente()) {
        final conteudo = _semComentarios(f.readAsStringSync());
        if (conteudo.contains('package:rive/')) {
          importadores.add(f.path.replaceAll(r'\', '/'));
        }
      }
      expect(importadores, hasLength(1));
      expect(
        importadores.single,
        endsWith('lib/casca/splash/abertura_rive.dart'),
        reason:
            'o runtime da Rive é nativo: espalhá-lo torna cada tela que o '
            'toca impossível de rodar em flutter test',
      );
    });

    test('A09 a fonte real é construída num lugar só, e é o padrão', () {
      final construtores = <String>[];
      for (final f in _fontesDoCliente()) {
        final caminho = f.path.replaceAll(r'\', '/');
        if (caminho.endsWith('lib/casca/splash/abertura_rive.dart')) continue;
        if (_semComentarios(f.readAsStringSync()).contains('AberturaRive(')) {
          construtores.add(caminho);
        }
      }
      expect(construtores, hasLength(1));
      expect(
        construtores.single,
        endsWith('lib/casca/splash/splash_constelacao_screen.dart'),
        reason:
            'a porta existe para o teste, não para produção: quem publica não '
            'escolhe fonte de arte, e só há um lugar onde a real é montada',
      );
    });

    test('A10 o ajuste visual é contain, centralizado, sem esticar', () {
      // Estrutural, e o laudo declara isso como limite: medir o desenho exige
      // o runtime nativo, que não sobe aqui. O que este caso impede é a
      // regressão barata — alguém trocar `contain` por `fill` ou `cover` e a
      // arte sair esticada ou cortada no aparelho.
      final fonte = _semComentarios(
        File('lib/casca/splash/abertura_rive.dart').readAsStringSync(),
      );
      expect(fonte, contains('Fit.contain'));
      expect(fonte, contains('Alignment.center'));
      expect(fonte, isNot(contains('Fit.fill')));
      expect(fonte, isNot(contains('Fit.cover')));
    });

    test('A11 a timeline é escolhida pelo nome, nunca por posição', () {
      final fonte = _semComentarios(
        File('lib/casca/splash/abertura_rive.dart').readAsStringSync(),
      );
      expect(fonte, contains('animationNamed(kTimelineDaAbertura)'));
      expect(fonte, contains('artboard(kArtboardDaAbertura)'));
      expect(fonte, isNot(contains('animationAt(')));
      expect(fonte, isNot(contains('artboardAt(')));
      expect(fonte, isNot(contains('defaultArtboard(')));
      // A `State Machine 1` da arte está vazia e NÃO é a autoridade desta V1.
      expect(fonte, isNot(contains('stateMachine')));
      expect(fonte, isNot(contains('StateMachine')));
    });
  });

  // =========================================================================
  // Correção visual V1 — a constelação como camada complementar
  // =========================================================================
  group('CONSTELACAO — a camada que faltava, sem tocar no .riv', () {
    test('C01 o .riv continua com o MESMO tamanho e o MESMO SHA-256', () async {
      // O binario nao foi tocado por esta correcao, e este caso e o que
      // impede alguem "resolver" um problema visual mexendo nele.
      final dados = await rootBundle.load(kAssetDaAbertura);
      final bytes = dados.buffer.asUint8List(
        dados.offsetInBytes,
        dados.lengthInBytes,
      );
      expect(bytes.length, kTamanhoAutoritativo);
      expect(sha256.convert(bytes).toString(), kSha256Autoritativo);
    });

    test('C02 a constelação está no repositório e no bundle', () async {
      expect(File(kAssetDaConstelacao).existsSync(), isTrue);
      final dados = await rootBundle.load(kAssetDaConstelacao);
      final bytes = dados.buffer.asUint8List(
        dados.offsetInBytes,
        dados.lengthInBytes,
      );
      expect(bytes.length, kTamanhoDaConstelacao);
      expect(sha256.convert(bytes).toString(), kSha256DaConstelacao);
      expect(String.fromCharCodes(bytes.take(5)), '<?xml');
      // A mesma area de referencia da Rive. Sem isso as duas camadas
      // escorregariam uma em relacao a outra em qualquer tela que nao fosse
      // exatamente 9:16.
      final texto = String.fromCharCodes(bytes);
      expect(texto, contains('viewBox="0 0 1080 1920"'));
    });

    test('C03 o asset da constelação está declarado no pubspec', () {
      // Mesmo diretorio ja declarado do .riv — e o caso existe para que
      // ninguem mova o arquivo para uma pasta nao declarada sem perceber.
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec, contains('- assets/rive/'));
      expect(kAssetDaConstelacao, startsWith('assets/rive/'));
    });

    testWidgets('C04 a constelação aparece na abertura, POR CIMA da Rive', (
      tester,
    ) async {
      final fonte = AberturaFalsa();
      await _montarAbertura(tester, fonte: fonte, chave: 'c04');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(SvgPicture), findsOneWidget);
      expect(find.byKey(kChaveDaArteFalsa), findsOneWidget);

      // A ORDEM IMPORTA, e nao e preferencia: o artboard da Rive pinta fundo
      // opaco em toda a sua area. Uma constelacao POR BAIXO seria coberta, e o
      // defeito continuaria — so que com um asset a mais no APK fingindo que
      // foi resolvido.
      final pilha = tester.widget<Stack>(
        find
            .descendant(
              of: find.byType(SplashConstelacaoScreen),
              matching: find.byType(Stack),
            )
            .first,
      );
      // A camada da arte é procurada pela SUBÁRVORE, e não pela chave do
      // filho direto: a arte é decoração e viaja embrulhada em
      // `ExcludeSemantics`, então a chave do dublê não está mais no topo da
      // camada. O que se mede continua sendo o mesmo: em que posição da
      // pilha a arte entra, e se a constelação vem depois dela.
      final indiceDaArte = pilha.children.indexWhere(
        (w) =>
            w.key == kChaveDaArteFalsa ||
            find
                .descendant(
                  of: find.byWidget(w),
                  matching: find.byKey(kChaveDaArteFalsa),
                )
                .evaluate()
                .isNotEmpty,
      );
      expect(indiceDaArte, isNonNegative);
      expect(
        indiceDaArte,
        lessThan(pilha.children.length - 1),
        reason: 'a constelação não é a última camada — ela ficaria por baixo',
      );
    });

    testWidgets('C05 a constelação não recebe toque', (tester) async {
      await _montarAbertura(tester, fonte: AberturaFalsa(), chave: 'c05');
      await tester.pump(const Duration(milliseconds: 100));
      // `MaterialApp` e `Scaffold` já trazem `IgnorePointer` na árvore, e todos
      // eles com `ignoring: false`. O que este caso exige é que exista um
      // ATIVO acima da constelação.
      final barreiras = tester.widgetList<IgnorePointer>(
        find.ancestor(
          of: find.byType(SvgPicture),
          matching: find.byType(IgnorePointer),
        ),
      );
      expect(
        barreiras.where((b) => b.ignoring),
        hasLength(1),
        reason: 'a camada visual passou a poder engolir toque',
      );
    });

    testWidgets('C06 a constelação NÃO cria uma segunda conclusão', (
      tester,
    ) async {
      final fonte = AberturaFalsa(
        duracaoDaTimeline: const Duration(milliseconds: 100),
      );
      final saidas = await _montarAbertura(tester, fonte: fonte, chave: 'c06');

      await tester.pump(const Duration(milliseconds: 120));
      expect(saidas(), 1);
      // O fade da constelacao vai ate 60 ms, e a arte esta na tela: nem o fim
      // do fade nem o relogio produzem a segunda saida.
      await tester.pump(const Duration(milliseconds: 600));
      expect(
        saidas(),
        1,
        reason: 'a camada visual passou a mandar na duração da apresentação',
      );
    });

    testWidgets('C07 constelação ausente não impede a continuidade', (
      tester,
    ) async {
      final fonte = AberturaFalsa(
        duracaoDaTimeline: const Duration(milliseconds: 100),
      );
      final saidas = await _montarAbertura(
        tester,
        fonte: fonte,
        chave: 'c07',
        bundle: _BundleSemConstelacao(),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(SvgPicture), findsNothing);
      // A Rive continua, o fundo continua, e a abertura termina na hora certa.
      expect(find.byKey(kChaveDaArteFalsa), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 60));
      expect(saidas(), 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('C08 Rive quebrada: a constelação sozinha não trava nada', (
      tester,
    ) async {
      // O comportamento anterior tem de ficar igual: fundo estavel, sem texto,
      // e saida pelo relogio de seguranca.
      final saidas = await _montarAbertura(
        tester,
        fonte: AberturaFalsa(falha: FalhaDaAbertura.arteNaoCarregou),
        chave: 'c08',
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(kChaveDaArteFalsa), findsNothing);
      expect(find.byType(SvgPicture), findsOneWidget);
      // O ÚNICO texto da tela continua sendo o rótulo de pular. Não é
      // afrouxamento do que este caso exigia: o que ele proíbe — texto
      // técnico, nome de falha, mensagem de erro — continua proibido, e
      // agora está dito pelo conteúdo, e não só pela contagem.
      expect(_textosDaTela(tester), [kRotuloDePular]);

      await tester.pump(const Duration(milliseconds: 300));
      expect(saidas(), 1);
    });

    testWidgets('C09 movimento reduzido: a camada entra sem fade', (
      tester,
    ) async {
      final saidas = await _montarAbertura(
        tester,
        fonte: AberturaFalsa(),
        chave: 'c09',
        movimentoReduzido: true,
      );
      await tester.pump(const Duration(milliseconds: 10));

      // A constelacao e imagem parada: ela entra. O que o movimento reduzido
      // desliga e o fade, e nao a camada.
      expect(find.byType(SvgPicture), findsOneWidget);
      expect(find.byType(TweenAnimationBuilder<double>), findsNothing);

      await tester.pump(const Duration(milliseconds: 61));
      expect(saidas(), 1);
    });

    testWidgets('C11 a máscara é aplicada SÓ na camada da constelação', (
      tester,
    ) async {
      await _montarAbertura(tester, fonte: AberturaFalsa(), chave: 'c11');
      await tester.pump(const Duration(milliseconds: 100));

      final recortes = tester.widgetList<ClipPath>(
        find.ancestor(
          of: find.byType(SvgPicture),
          matching: find.byType(ClipPath),
        ),
      );
      expect(
        recortes.where((c) => c.clipper is MascaraDaConstelacao),
        hasLength(1),
      );

      // E NÃO na Rive: o recorte existe para tirar dois nós de cima das
      // letras, não para mexer na arte que já estava aprovada.
      expect(
        tester.widgetList<ClipPath>(
          find.ancestor(
            of: find.byKey(kChaveDaArteFalsa),
            matching: find.byType(ClipPath),
          ),
        ).where((c) => c.clipper is MascaraDaConstelacao),
        isEmpty,
      );
    });

    test('C12 a máscara exclui exatamente as duas caixas medidas', () {
      // AS CAIXAS SÃO AFIRMADAS UMA A UMA, e não só percorridas. A versão
      // anterior deste caso iterava `kExclusoesDaConstelacao` e nada mais — com
      // a lista vazia o laço não rodava, nenhuma expectativa era avaliada e o
      // teste passava com a máscara desligada. Quem denunciou foi a campanha de
      // mutação, não a leitura.
      expect(kExclusoesDaConstelacao, hasLength(2));
      expect(
        kExclusoesDaConstelacao,
        containsAll(const <Rect>[
          Rect.fromLTRB(448, 1514, 484, 1550),
          Rect.fromLTRB(599, 1514, 635, 1550),
        ]),
        reason:
            'as caixas saíram das coordenadas medidas: elas cobrem os nós em '
            '(466,1532) e (617,1532), que são os que encostavam nas letras',
      );

      // Em 1080 × 1920 a escala do `contain` é 1 e não há deslocamento: as
      // caixas do contrato caem sobre si mesmas.
      const mascara = MascaraDaConstelacao();
      final caminho = mascara.getClip(kCanvasDaAbertura);

      // Os dois pontos que a medição pixel a pixel acusou.
      for (final encostava in const [Offset(466, 1532), Offset(617, 1532)]) {
        expect(
          caminho.contains(encostava),
          isFalse,
          reason: '$encostava voltou a ser desenhado sobre a base do título',
        );
      }

      for (final area in kExclusoesDaConstelacao) {
        expect(
          caminho.contains(area.center),
          isFalse,
          reason: 'o centro de $area continua sendo desenhado',
        );
      }
      // E o resto do canvas continua inteiro — inclusive logo acima e logo
      // abaixo das caixas, que é onde as linhas da constelação seguem.
      for (final ponto in const [
        Offset(540, 100),
        Offset(112, 286),
        Offset(540, 960),
        Offset(540, 1687),
        Offset(466, 1600),
        Offset(617, 1450),
        Offset(1000, 1900),
      ]) {
        expect(
          caminho.contains(ponto),
          isTrue,
          reason: 'a máscara comeu $ponto, que não é área de título',
        );
      }
    });

    testWidgets('C14 o fade da constelação dura 600 ms na abertura real', (
      tester,
    ) async {
      // 3 s × 1/5. O valor não é escrito no código da tela: ele SAI da duração
      // de autoria, e este caso é o que impede alguém trocar a proporção sem
      // perceber que mudou o tempo da entrada.
      await _montarAbertura(
        tester,
        fonte: AberturaFalsa(),
        chave: 'c14',
        duracao: kDuracaoDaAbertura,
      );
      await tester.pump(const Duration(milliseconds: 50));

      final fade = tester.widget<TweenAnimationBuilder<double>>(
        find.byType(TweenAnimationBuilder<double>),
      );
      expect(fade.duration, const Duration(milliseconds: 600));
      expect(fade.tween.begin, 0);
      expect(fade.tween.end, 1);
    });

    test('C13 a máscara acompanha o contain em outras proporções', () {
      const mascara = MascaraDaConstelacao();

      // Telefone estreito, tela alta e recortada, e uma tela larga: em todas,
      // a arte é encaixada por `contain` e sobra faixa em UM dos eixos.
      for (final janela in const [
        Size(720, 1520),
        Size(1080, 2400),
        Size(1440, 2560),
        Size(1200, 1200),
      ]) {
        final caminho = mascara.getClip(janela);
        final escala = janela.width / kCanvasDaAbertura.width <
                janela.height / kCanvasDaAbertura.height
            ? janela.width / kCanvasDaAbertura.width
            : janela.height / kCanvasDaAbertura.height;
        final origem = Offset(
          (janela.width - kCanvasDaAbertura.width * escala) / 2,
          (janela.height - kCanvasDaAbertura.height * escala) / 2,
        );

        for (final area in kExclusoesDaConstelacao) {
          final centro =
              origem + Offset(area.center.dx * escala, area.center.dy * escala);
          expect(
            caminho.contains(centro),
            isFalse,
            reason:
                'em $janela a exclusão saiu de cima do título — foi calculada '
                'em pixels de tela em vez de coordenadas do canvas',
          );
          // Bem longe da caixa, a constelação continua desenhada.
          final longe = origem + Offset(540 * escala, 300 * escala);
          expect(caminho.contains(longe), isTrue);
        }
      }
    });

    testWidgets('C10 a constelação não altera a ordem do portão duplo', (
      tester,
    ) async {
      final b = Bancada();
      addTearDown(b.fechar);
      final fonte = AberturaFalsa(
        duracaoDaTimeline: const Duration(milliseconds: 20),
      );
      _telefone(tester);

      await tester.pumpWidget(
        RaizDoAplicativo(
          sessao: b.sessao,
          autenticacao: b.autenticacao,
          online: b.online,
          duracaoDaSplash: const Duration(milliseconds: 300),
          somNaSplash: false,
          fonteDaAbertura: fonte,
          limiteDeResolucao: const Duration(seconds: 8),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // A constelacao esta na tela, a animacao acabou, e mesmo assim ninguem
      // foi roteado: quem decide continua sendo a sessao.
      expect(find.byType(SvgPicture), findsOneWidget);
      expect(find.byType(LoginDeProducao), findsNothing);
      expect(find.byType(HomeDeProducao), findsNothing);

      b.fluxo.add(null);
      await tester.pump();
      await tester.pump();
      expect(find.byType(LoginDeProducao), findsOneWidget);
      expect(find.byType(SvgPicture), findsNothing);
    });
  });

  // =========================================================================
  // §8.2 — a tela e o portão duplo
  // =========================================================================
  group('ABERTURA — uma saída, e só quando as duas condições valem', () {
    testWidgets('W01 timeline termina: sai UMA vez', (tester) async {
      final fonte = AberturaFalsa(
        duracaoDaTimeline: const Duration(milliseconds: 100),
      );
      final saidas = await _montarAbertura(tester, fonte: fonte);

      expect(saidas(), 0, reason: 'saiu antes de a animação terminar');
      await tester.pump(const Duration(milliseconds: 120));
      expect(saidas(), 1);

      // E o relógio de segurança, que ainda estava armado, não produz a
      // segunda saída quando o horizonte dele chega.
      await tester.pump(const Duration(milliseconds: 400));
      expect(saidas(), 1);
    });

    testWidgets('W02 a timeline avisando DUAS vezes é uma saída só', (
      tester,
    ) async {
      final fonte = AberturaFalsa();
      final saidas = await _montarAbertura(tester, fonte: fonte);
      await tester.pump();

      fonte.ultima!.concluirAgora();
      fonte.ultima!.concluirAgora();
      await tester.pump(const Duration(milliseconds: 10));
      expect(saidas(), 1);

      fonte.ultima!.concluirAgora();
      await tester.pump(const Duration(milliseconds: 10));
      expect(saidas(), 1);
    });

    testWidgets('W03 relógio de segurança e timeline em corrida: uma saída', (
      tester,
    ) async {
      // A timeline avisa no MESMO instante do horizonte do relógio: 300 × 7/6
      // = 350 ms.
      final fonte = AberturaFalsa(
        duracaoDaTimeline: const Duration(milliseconds: 350),
      );
      final saidas = await _montarAbertura(tester, fonte: fonte);

      await tester.pump(const Duration(milliseconds: 350));
      expect(saidas(), 1);
      await tester.pump(const Duration(milliseconds: 500));
      expect(saidas(), 1);
    });

    testWidgets('W04 timeline que nunca termina: o relógio salva a abertura', (
      tester,
    ) async {
      final fonte = AberturaFalsa();
      final saidas = await _montarAbertura(tester, fonte: fonte);

      await tester.pump(const Duration(milliseconds: 300));
      expect(saidas(), 0, reason: 'o relógio disparou antes do horizonte');

      await tester.pump(const Duration(milliseconds: 60));
      expect(saidas(), 1, reason: '3 s × 7/6 = 3,5 s — aqui, 300 ms × 7/6');
    });

    for (final motivo in FalhaDaAbertura.values) {
      testWidgets(
        'W05 ${motivo.name}: fundo estável, sem texto, e saída no relógio',
        (tester) async {
          final saidas = await _montarAbertura(
            tester,
            fonte: AberturaFalsa(falha: motivo),
            chave: motivo.name,
          );

          await tester.pump(const Duration(milliseconds: 10));
          // Nada de arte, nada de texto técnico, nada de indicador: o fundo e
          // a única ação que a abertura oferece.
          expect(find.byKey(kChaveDaArteFalsa), findsNothing);
          expect(find.byType(CircularProgressIndicator), findsNothing);
          // O nome da falha NÃO chega à tela — e o único texto é o rótulo.
          expect(_textosDaTela(tester), [kRotuloDePular]);
          for (final texto in _textosDaTela(tester)) {
            expect(texto, isNot(contains(motivo.name)));
          }
          expect(
            tester
                .state<State<SplashConstelacaoScreen>>(
                  find.byType(SplashConstelacaoScreen),
                )
                .mounted,
            isTrue,
          );

          await tester.pump(const Duration(milliseconds: 400));
          expect(
            saidas(),
            1,
            reason: 'falha $motivo aprisionou a jogadora na abertura',
          );
        },
      );
    }

    testWidgets('W06 arte que carrega entra na tela', (tester) async {
      final fonte = AberturaFalsa();
      await _montarAbertura(tester, fonte: fonte);
      await tester.pump();
      expect(find.byKey(kChaveDaArteFalsa), findsOneWidget);
      expect(fonte.carregamentos, 1, reason: 'o arquivo é lido uma vez só');
    });

    testWidgets('W07 tela desmontada: sem saída tardia e sem exceção', (
      tester,
    ) async {
      final fonte = AberturaFalsa();
      final saidas = await _montarAbertura(tester, fonte: fonte);
      await tester.pump();
      final arte = fonte.ultima!;

      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));

      // A timeline avisa DEPOIS de a tela sair — o caso clássico de
      // `setState` após `dispose`.
      arte.concluirAgora();
      await tester.pump(const Duration(milliseconds: 500));

      expect(saidas(), 0);
      expect(arte.descartada, isTrue, reason: 'a arte vazou');
      expect(arte.descartes, 1, reason: 'a arte foi devolvida duas vezes');
      expect(tester.takeException(), isNull);
    });

    testWidgets('W08 arte que chega depois da desmontagem é devolvida', (
      tester,
    ) async {
      final fonte = AberturaFalsa(
        atrasoDoCarregamento: const Duration(milliseconds: 50),
      );
      await _montarAbertura(tester, fonte: fonte);
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pump(const Duration(milliseconds: 100));

      expect(fonte.ultima, isNotNull);
      expect(
        fonte.ultima!.descartada,
        isTrue,
        reason: 'arquivo e artboard ficaram abertos numa abertura interrompida',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('W09 movimento reduzido: sem arte, sem laço, janela curta', (
      tester,
    ) async {
      final fonte = AberturaFalsa();
      final saidas = await _montarAbertura(
        tester,
        fonte: fonte,
        movimentoReduzido: true,
      );
      await tester.pump();

      expect(
        fonte.carregamentos,
        0,
        reason: 'com movimento reduzido a animação não é nem carregada',
      );
      expect(find.byKey(kChaveDaArteFalsa), findsNothing);
      expect(saidas(), 0);

      // 300 ms × 1/5 = 60 ms, e não a duração inteira: a janela é curta e não
      // bloqueia ninguém.
      await tester.pump(const Duration(milliseconds: 61));
      expect(saidas(), 1);
      await tester.pump(const Duration(milliseconds: 500));
      expect(saidas(), 1, reason: 'virou laço');
    });

    testWidgets('W10 mudança de MediaQuery no meio não reinicia a abertura', (
      tester,
    ) async {
      final fonte = AberturaFalsa();
      final saidas = await _montarAbertura(tester, fonte: fonte);
      await tester.pump();

      // Uma rotação, uma mudança de escala de texto, um teclado abrindo.
      tester.view.physicalSize = const Size(1920, 1080);
      await tester.pump();
      tester.view.physicalSize = const Size(1080, 1920);
      await tester.pump();

      expect(fonte.carregamentos, 1, reason: 'a arte foi recarregada');
      await tester.pump(const Duration(milliseconds: 400));
      expect(saidas(), 1, reason: 'o relógio de segurança foi rearmado');
    });

    testWidgets('W11 ir para segundo plano e voltar não duplica a saída', (
      tester,
    ) async {
      final fonte = AberturaFalsa(
        duracaoDaTimeline: const Duration(milliseconds: 100),
      );
      final saidas = await _montarAbertura(tester, fonte: fonte);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(milliseconds: 150));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 400));

      expect(saidas(), 1);
      expect(tester.takeException(), isNull);
    });
  });

  // =========================================================================
  // §8.3 — layout
  // =========================================================================
  group('LAYOUT — a janela inteira, na cor certa, sem distorcer', () {
    testWidgets('L01 o primeiro quadro já é o fundo da arte', (tester) async {
      await _montarAbertura(tester, fonte: AberturaFalsa());
      // Sem `pump` extra: é o PRIMEIRO quadro que não pode ser branco.
      final tela = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(tela.backgroundColor, kFundoDaAbertura);
      expect(kFundoDaAbertura, const Color(0xFF050B1E));
      expect(
        tester
            .widgetList<ColoredBox>(find.byType(ColoredBox))
            .map((c) => c.color),
        contains(kFundoDaAbertura),
      );
    });

    // ELE JÁ EXIGIU O CONTRÁRIO, e é por isso que este comentário existe.
    //
    // Até a auditoria de acessibilidade, L02 afirmava "não há AppBar, texto
    // nem controle durante a abertura" — e a última linha dele,
    // `expect(find.byType(TextButton), findsNothing)`, era literalmente o
    // portão que impedia a abertura de ter o que apertar. A abertura saía
    // MUDA para o leitor de tela e sem saída para quem não quer esperar, e
    // a suíte protegia esse estado.
    //
    // O que sobreviveu do caso antigo é o que ele queria de fato dizer: a
    // abertura não tem cromo, não tem indicador de progresso e não tem texto
    // técnico. O que entrou é o que faltava — a ação, com nome, papel,
    // estado, alvo medido, acionamento real e uma transição só.
    testWidgets('L02 a abertura oferece "Pular abertura" como botão real', (
      tester,
    ) async {
      // Dispensado no fim do CORPO, e não por `addTearDown`: o framework
      // confere os manipuladores abertos antes de rodar os tearDowns.
      final manipulador = tester.ensureSemantics();

      final saidas = await _montarAbertura(tester, fonte: AberturaFalsa());
      await tester.pump();

      // O que a abertura continua NÃO tendo.
      expect(find.byType(AppBar), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(ElevatedButton), findsNothing);
      expect(
        _textosDaTela(tester),
        [kRotuloDePular],
        reason: 'a abertura ganhou texto que não é a ação de pular',
      );

      // 1. A AÇÃO EXISTE, e é uma só.
      final botao = find.byType(TextButton);
      expect(
        botao,
        findsOneWidget,
        reason: 'a abertura voltou a não ter o que apertar',
      );

      // 2. O NOME é exatamente o do contrato, e é o mesmo que está escrito.
      final dados = tester.getSemantics(botao).getSemanticsData();
      expect(
        dados.label,
        kRotuloDePular,
        reason: 'o nome acessível da ação deixou de ser "$kRotuloDePular"',
      );
      expect(_textosDaTela(tester).single, dados.label);
      expect(find.bySemanticsLabel(kRotuloDePular), findsOneWidget);

      // 3. O PAPEL é de botão, e 4. o estado é habilitado.
      //
      // `isEnabled` é tri-estado de propósito nesta versão: `none` significa
      // "nem se aplica" — um rótulo solto, sem papel — e é exatamente o que
      // uma área sensível com `Semantics` pendurado devolveria.
      final marcas = dados.flagsCollection;
      expect(
        marcas.isButton,
        isTrue,
        reason: 'a ação perdeu o papel de botão',
      );
      expect(
        marcas.isEnabled,
        Tristate.isTrue,
        reason: 'a ação existe mas não se declara habilitada',
      );
      expect(
        marcas.isFocused,
        isNot(Tristate.none),
        reason: 'a ação não é focável — teclado e leitor de tela não chegam',
      );
      expect(dados.hasAction(SemanticsAction.tap), isTrue);

      // 5. O ALVO É MEDIDO no que recebe o toque, nunca na pintura.
      final alvo = tester.getSize(botao);
      expect(
        alvo.width,
        greaterThanOrEqualTo(kAlvoMinimoDePular),
        reason: 'alvo de $alvo — abaixo do piso de $kAlvoMinimoDePular dp',
      );
      expect(
        alvo.height,
        greaterThanOrEqualTo(kAlvoMinimoDePular),
        reason: 'alvo de $alvo — abaixo do piso de $kAlvoMinimoDePular dp',
      );

      // 6. ACIONAMENTO REAL, e 7. UMA transição só.
      expect(saidas(), 0);
      await tester.tap(botao);
      await tester.pump();
      expect(
        saidas(),
        1,
        reason: 'tocar a ação não encerrou a abertura',
      );

      // E a ação sai da árvore: não sobra controle que não faz nada.
      expect(find.byType(TextButton), findsNothing);
      await tester.pump(const Duration(seconds: 1));
      expect(
        saidas(),
        1,
        reason: 'o relógio de segurança produziu uma segunda saída',
      );
      manipulador.dispose();
    });

    testWidgets('L03 a arte ocupa a janela inteira em quatro superfícies', (
      tester,
    ) async {
      const superficies = <String, Size>{
        'telefone estreito': Size(720, 1520),
        'proporção 9:16': Size(1080, 1920),
        'tela alta e recortada': Size(1080, 2400),
        'tela larga': Size(1440, 2560),
      };
      for (final entrada in superficies.entries) {
        await _montarAbertura(
          tester,
          fonte: AberturaFalsa(),
          tamanho: entrada.value,
          chave: entrada.key,
        );
        await tester.pump();

        final janela = tester.getSize(find.byType(SplashConstelacaoScreen));
        final arte = tester.getSize(find.byKey(kChaveDaArteFalsa));
        expect(
          arte,
          janela,
          reason:
              '${entrada.key}: a arte não ocupa a janela inteira, e a faixa '
              'que sobra não está na cor do fundo',
        );
      }
    });

    testWidgets('L04 escala de texto ampliada não mexe na arte', (
      tester,
    ) async {
      await _montarAbertura(
        tester,
        fonte: AberturaFalsa(),
        chave: 'sem-escala',
      );
      await tester.pump();
      final semEscala = tester.getSize(find.byKey(kChaveDaArteFalsa));

      await _montarAbertura(
        tester,
        fonte: AberturaFalsa(),
        escalaDeTexto: const TextScaler.linear(2.0),
        chave: 'com-escala',
      );
      await tester.pump();
      final comEscala = tester.getSize(find.byKey(kChaveDaArteFalsa));

      expect(
        comEscala,
        semEscala,
        reason:
            'a abertura não tem texto do Flutter: a escala do sistema não '
            'pode deformar a arte',
      );
    });
  });

  // =========================================================================
  // ACESSIBILIDADE — o que a auditoria reprovou, e o que passou a valer
  // =========================================================================
  //
  // A abertura auditada saía com QUATRO nós semânticos e NENHUM rótulo: só
  // o `scopesRoute` que a rota do Material cria sozinha. Um leitor de tela
  // abria o aplicativo, ficava em silêncio por segundos, e não havia nada
  // para tocar — tocar a arte não produzia saída nenhuma, em lugar nenhum
  // da tela, em momento nenhum.
  group('ACESSIBILIDADE — a abertura fala, e tem o que apertar', () {
    testWidgets('S01 a abertura tem estado semântico, e é UM', (
      tester,
    ) async {
      // Dispensado no fim do CORPO, e não por `addTearDown`: o framework
      // confere os manipuladores abertos antes de rodar os tearDowns.
      final manipulador = tester.ensureSemantics();
      await _montarAbertura(tester, fonte: AberturaFalsa());
      await tester.pump();

      expect(
        find.bySemanticsLabel(kRotuloDaAbertura),
        findsOneWidget,
        reason: 'a abertura voltou a ser muda para o leitor de tela',
      );
      expect(kRotuloDaAbertura, contains('Buraco Master VIP'));
      manipulador.dispose();
    });

    testWidgets('S02 partícula nenhuma entra na leitura', (tester) async {
      // Dispensado no fim do CORPO, e não por `addTearDown`: o framework
      // confere os manipuladores abertos antes de rodar os tearDowns.
      final manipulador = tester.ensureSemantics();
      await _montarAbertura(tester, fonte: AberturaFalsa());
      await tester.pump(const Duration(milliseconds: 100));

      // A árvore inteira tem DOIS rótulos, nesta ordem: o estado da
      // abertura e a ação. Arte, constelação, máscara e fade não aparecem.
      expect(
        find.semantics
            .byPredicate((no) => no.label.isNotEmpty)
            .evaluate()
            .map((no) => no.label)
            .toList(),
        [kRotuloDaAbertura, kRotuloDePular],
        reason: 'a decoração vazou para a árvore semântica',
      );

      // E nada é região viva: a árvore muda a cada quadro do fade, e uma
      // região viva faria a abertura se reanunciar por cima de si mesma.
      expect(
        find.semantics.byPredicate(
          (no) => no.getSemanticsData().flagsCollection.isLiveRegion,
        ),
        findsNothing,
        reason: 'o estado da abertura se reanuncia a cada quadro',
      );
      manipulador.dispose();
    });

    testWidgets('S03 a ação existe desde o primeiro quadro', (tester) async {
      // A arte demora a carregar DE PROPÓSITO: é exatamente a janela em que
      // a abertura auditada não tinha nada para apertar.
      final saidas = await _montarAbertura(
        tester,
        fonte: AberturaFalsa(
          atrasoDoCarregamento: const Duration(milliseconds: 120),
        ),
      );
      // SEM `pump` extra: o primeiro quadro.
      expect(find.byKey(kChaveDaArteFalsa), findsNothing);
      expect(
        find.byType(TextButton),
        findsOneWidget,
        reason: 'a ação só aparece depois de a arte carregar',
      );

      await tester.tap(find.byType(TextButton));
      await tester.pump();
      expect(saidas(), 1);
      await tester.pump(const Duration(milliseconds: 500));
      expect(saidas(), 1);
    });

    testWidgets('S04 a ação funciona pela árvore semântica', (tester) async {
      // Dispensado no fim do CORPO, e não por `addTearDown`: o framework
      // confere os manipuladores abertos antes de rodar os tearDowns.
      final manipulador = tester.ensureSemantics();
      final saidas = await _montarAbertura(tester, fonte: AberturaFalsa());
      await tester.pump();

      // É ESTE o caminho do TalkBack: a ação chega pela árvore, e não por um
      // toque em coordenada. Um controle que só responde ao dedo passa no
      // teste de toque e continua inacessível.
      tester.semantics.performAction(
        find.semantics.byLabel(kRotuloDePular),
        SemanticsAction.tap,
      );
      await tester.pump();
      expect(
        saidas(),
        1,
        reason: 'a ação semântica não encerra a abertura',
      );
      manipulador.dispose();
    });

    testWidgets('S05 a ação funciona por teclado', (tester) async {
      final saidas = await _montarAbertura(tester, fonte: AberturaFalsa());
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final foco = tester.binding.focusManager.primaryFocus;
      expect(
        find.ancestor(
          of: find.byWidget(foco!.context!.widget),
          matching: find.byType(TextButton),
        ),
        findsOneWidget,
        reason: 'o tabulador não alcança a ação de pular',
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(saidas(), 1);
    });

    testWidgets('S06 pular leva ao destino da sessão, e só a ele', (
      tester,
    ) async {
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);
      _telefone(tester);
      await tester.pumpWidget(
        RaizDoAplicativo(
          sessao: b.sessao,
          autenticacao: b.autenticacao,
          online: b.online,
          duracaoDaSplash: const Duration(seconds: 3),
          somNaSplash: false,
          fonteDaAbertura: AberturaFalsa(),
          limiteDeResolucao: const Duration(seconds: 8),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(SplashConstelacaoScreen), findsOneWidget);
      expect(find.byType(HomeDeProducao), findsNothing);

      // A timeline dura três segundos e NÃO terminou. Quem encerra é ela.
      await tester.tap(find.byType(TextButton));
      await tester.pump();
      await tester.pump();
      expect(
        find.byType(HomeDeProducao),
        findsOneWidget,
        reason: 'pular não levou ao destino que a sessão decidiu',
      );
      expect(find.byType(LoginDeProducao), findsNothing);
      expect(find.byType(SplashConstelacaoScreen), findsNothing);
    });

    testWidgets('S07 toque duplo não monta a Casca duas vezes', (
      tester,
    ) async {
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);
      _telefone(tester);
      await tester.pumpWidget(
        RaizDoAplicativo(
          sessao: b.sessao,
          autenticacao: b.autenticacao,
          online: b.online,
          duracaoDaSplash: const Duration(seconds: 3),
          somNaSplash: false,
          fonteDaAbertura: AberturaFalsa(),
          limiteDeResolucao: const Duration(seconds: 8),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // DOIS toques no MESMO quadro, antes de qualquer reconstrução.
      final botao = find.byType(TextButton);
      await tester.tap(botao, warnIfMissed: false);
      await tester.tap(botao, warnIfMissed: false);
      await tester.pump();
      await tester.pump();

      expect(find.byType(HomeDeProducao), findsOneWidget);
      expect(find.byType(SplashConstelacaoScreen), findsNothing);
      await tester.pump(const Duration(seconds: 5));
      expect(
        find.byType(HomeDeProducao),
        findsOneWidget,
        reason: 'a Casca foi montada mais de uma vez',
      );
    });

    testWidgets('S08 callback tardio depois de pular não navega de novo', (
      tester,
    ) async {
      final fonte = AberturaFalsa();
      final saidas = await _montarAbertura(
        tester,
        fonte: fonte,
        duracao: const Duration(milliseconds: 300),
      );
      await tester.pump();
      await tester.tap(find.byType(TextButton));
      await tester.pump();
      expect(saidas(), 1);

      // A timeline avisa DEPOIS, e o relógio de segurança venceria em
      // seguida. Nenhum dos dois pode virar uma segunda saída.
      fonte.ultima!.concluirAgora();
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(
        saidas(),
        1,
        reason: 'um aviso tardio produziu uma segunda saída',
      );
    });

    testWidgets('S09 o foco não fica preso na abertura removida', (
      tester,
    ) async {
      final saidas = await _montarAbertura(tester, fonte: AberturaFalsa());
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(tester.binding.focusManager.primaryFocus, isNotNull);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(saidas(), 1);

      // A ação saiu da árvore, e o foco saiu junto: um nó de foco que morre
      // montado deixa o leitor de tela apontando para o que não existe.
      expect(find.byType(TextButton), findsNothing);
      final foco = tester.binding.focusManager.primaryFocus;
      if (foco?.context != null) {
        expect(
          find.ancestor(
            of: find.byWidget(foco!.context!.widget),
            matching: find.byType(TextButton),
          ),
          findsNothing,
          reason: 'o foco continua no botão que saiu da tela',
        );
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('S10 não pular continua funcionando igual', (tester) async {
      final fonte = AberturaFalsa(
        duracaoDaTimeline: const Duration(milliseconds: 120),
      );
      final saidas = await _montarAbertura(tester, fonte: fonte);
      await tester.pump();
      expect(find.byType(TextButton), findsOneWidget);

      // Ninguém toca em nada. A timeline encerra sozinha, como sempre.
      await tester.pump(const Duration(milliseconds: 200));
      expect(saidas(), 1);
      expect(
        find.byType(TextButton),
        findsNothing,
        reason: 'sobrou um botão de pular numa abertura já encerrada',
      );
      await tester.pump(const Duration(seconds: 1));
      expect(saidas(), 1);
    });

    testWidgets('S11 arte que não carrega não prende ninguém', (
      tester,
    ) async {
      // Dispensado no fim do CORPO, e não por `addTearDown`: o framework
      // confere os manipuladores abertos antes de rodar os tearDowns.
      final manipulador = tester.ensureSemantics();
      final saidas = await _montarAbertura(
        tester,
        fonte: AberturaFalsa(falha: FalhaDaAbertura.arteNaoCarregou),
      );
      await tester.pump(const Duration(milliseconds: 10));

      // Sem arte, a abertura continua falando e continua tendo saída — e a
      // saída é imediata, não a espera do relógio.
      expect(find.bySemanticsLabel(kRotuloDaAbertura), findsOneWidget);
      expect(find.byType(TextButton), findsOneWidget);
      await tester.tap(find.byType(TextButton));
      await tester.pump();
      expect(saidas(), 1);
      await tester.pump(const Duration(seconds: 1));
      expect(saidas(), 1);
      manipulador.dispose();
    });
  });

  // =========================================================================
  // §8.2.9 e §8.2.10 — o destino continua sendo da casca
  // =========================================================================
  group('ROTEAMENTO — quem decide o destino é a sessão, nunca a abertura', () {
    testWidgets('R01 bootstrap pronto antes: a abertura toca até o fim', (
      tester,
    ) async {
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);
      final fonte = AberturaFalsa();
      _telefone(tester);

      await tester.pumpWidget(
        RaizDoAplicativo(
          sessao: b.sessao,
          autenticacao: b.autenticacao,
          online: b.online,
          duracaoDaSplash: const Duration(milliseconds: 300),
          somNaSplash: false,
          fonteDaAbertura: fonte,
          limiteDeResolucao: const Duration(seconds: 8),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // A sessão já respondeu — e a Home continua fora da tela.
      expect(b.sessao.resolvida, isTrue);
      expect(find.byType(SplashConstelacaoScreen), findsOneWidget);
      expect(find.byType(HomeDeProducao), findsNothing);

      fonte.ultima!.concluirAgora();
      await tester.pump(const Duration(milliseconds: 20));
      await tester.pump();
      expect(find.byType(HomeDeProducao), findsOneWidget);
      expect(find.byType(SplashConstelacaoScreen), findsNothing);
    });

    testWidgets('R02 animação pronta antes: a abertura espera o bootstrap', (
      tester,
    ) async {
      final b = Bancada();
      addTearDown(b.fechar);
      final fonte = AberturaFalsa(
        duracaoDaTimeline: const Duration(milliseconds: 20),
      );
      _telefone(tester);

      await tester.pumpWidget(
        RaizDoAplicativo(
          sessao: b.sessao,
          autenticacao: b.autenticacao,
          online: b.online,
          duracaoDaSplash: const Duration(milliseconds: 300),
          somNaSplash: false,
          fonteDaAbertura: fonte,
          limiteDeResolucao: const Duration(seconds: 8),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // A animação acabou HÁ MUITO, e a abertura continua no ar porque
      // ninguém se pronunciou sobre a sessão. É o portão duplo.
      expect(find.byType(SplashConstelacaoScreen), findsOneWidget);
      expect(find.byType(LoginDeProducao), findsNothing);
      expect(find.byType(HomeDeProducao), findsNothing);

      b.fluxo.add(null);
      await tester.pump();
      await tester.pump();
      expect(find.byType(LoginDeProducao), findsOneWidget);
    });

    testWidgets('R03 arte quebrada NÃO mascara sessão que não responde', (
      tester,
    ) async {
      final b = Bancada();
      addTearDown(b.fechar);
      _telefone(tester);

      await tester.pumpWidget(
        RaizDoAplicativo(
          sessao: b.sessao,
          autenticacao: b.autenticacao,
          online: b.online,
          duracaoDaSplash: const Duration(milliseconds: 300),
          somNaSplash: false,
          fonteDaAbertura: AberturaFalsa(
            falha: FalhaDaAbertura.arteNaoCarregou,
          ),
          limiteDeResolucao: const Duration(seconds: 2),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // O relógio de segurança encerrou a ANIMAÇÃO. Ele não afirmou bootstrap.
      expect(find.byType(SplashConstelacaoScreen), findsOneWidget);
      expect(find.byType(LoginDeProducao), findsNothing);

      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      // O teto da casca — que já existia — é quem se pronuncia, e ele não
      // inventa sessão nenhuma.
      expect(find.text('Não consegui iniciar sua sessão'), findsOneWidget);
      expect(find.byType(HomeDeProducao), findsNothing);
    });

    testWidgets('R04 a abertura não conhece rota, sessão nem destino', (
      _,
    ) async {
      for (final caminho in const [
        'lib/casca/splash/splash_constelacao_screen.dart',
        'lib/casca/splash/abertura_rive.dart',
        'lib/casca/splash/contrato_da_abertura.dart',
      ]) {
        final fonte = _semComentarios(File(caminho).readAsStringSync());
        for (final proibido in const [
          'Navigator',
          'pushReplacement',
          'EscopoSessao',
          'SessaoDoJogador',
          'HomeDeProducao',
          'LoginDeProducao',
          'FirebaseAuth',
          'Firebase.initializeApp',
        ]) {
          expect(
            fonte,
            isNot(contains(proibido)),
            reason: '$caminho decide destino ou reinicializa bootstrap',
          );
        }
      }
    });

    testWidgets('R05 a casca é o único ponto que monta a abertura', (
      _,
    ) async {
      final montadores = <String>[];
      for (final f in _fontesDoCliente()) {
        final caminho = f.path.replaceAll(r'\', '/');
        if (caminho.endsWith('lib/casca/splash/splash_constelacao_screen.dart')) {
          continue;
        }
        if (_semComentarios(
          f.readAsStringSync(),
        ).contains('SplashConstelacaoScreen(')) {
          montadores.add(caminho);
        }
      }
      expect(montadores, hasLength(1));
      expect(montadores.single, endsWith('lib/casca/casca_de_producao.dart'));
    });

    test('R06 a casca continua exigindo as DUAS condições', () {
      final casca = _semComentarios(
        File('lib/casca/casca_de_producao.dart').readAsStringSync(),
      );
      // A ordem dos dois portões, na ordem em que a casca decide.
      expect(casca, contains('if (!sessao.resolvida)'));
      expect(casca, contains('if (!widget.aberturaTerminou) return _splash()'));
      expect(
        casca,
        isNot(contains('Future.delayed')),
        reason: 'relógio como autoridade de navegação',
      );
    });
  });

  // =========================================================================
  // §11.2 — o som e o movimento reduzido, cada um com a sua autoridade
  // =========================================================================
  //
  // O DEFEITO QUE ESTE GRUPO EXISTE PARA IMPEDIR
  //
  // A abertura pedia o som DENTRO do ramo de movimento normal. Quem tinha
  // "reduzir animações" ligado no sistema — e som ligado no aplicativo —
  // recebia uma abertura muda, sem ter pedido silêncio nenhum. Era o pior tipo
  // de acoplamento: invisível, e justamente na configuração de quem mais
  // depende do canal que sobrou.
  //
  // COMO ISTO É MEDIDO, E POR QUE A MEDIDA VALE
  //
  // Não há dublê de áudio aqui. O que a suíte escuta são os DOIS canais reais
  // do `audioplayers` (`xyz.luan/audioplayers` e `.global`), interceptados pela
  // costura padrão do `flutter_test`. O que aparece em [_EscutaDoAudio] é
  // literalmente o que sairia para o lado nativo no aparelho de quem joga.
  //
  // O plugin não existe dentro de `flutter test`, então a reprodução em si
  // nunca completa — e não é ela que está em questão. O que está em questão é
  // se a abertura CHEGA A PEDIR: `create` é a assinatura de `AudioPlayer()` no
  // canal, e é exatamente a chamada que não acontecia no ramo reduzido.
  group('SOM × MOVIMENTO — duas autoridades, e elas não se consultam', () {
    late _EscutaDoAudio audio;

    setUp(() => audio = _EscutaDoAudio()..instalar());
    tearDown(() => audio.remover());

    // -----------------------------------------------------------------------
    // M01–M04: a matriz, uma combinação por caso
    // -----------------------------------------------------------------------
    //
    // Escritos um a um, e não gerados por laço: são as quatro afirmações que a
    // OS 11.2 pede, e um laço faria a remoção de uma delas sumir sem deixar
    // rastro no relatório da suíte.

    testWidgets('M01 movimento normal + áudio permitido: a abertura toca', (
      tester,
    ) async {
      await _montarAbertura(
        tester,
        fonte: AberturaFalsa(),
        chave: 'm01',
        som: true,
      );
      await tester.pump(const Duration(milliseconds: 50));

      expect(
        audio.playersAbertos,
        1,
        reason: 'a abertura não pediu som nem no ramo em que sempre pediu',
      );
    });

    testWidgets('M02 movimento normal + áudio mutado: nada soa', (
      tester,
    ) async {
      await _montarAbertura(
        tester,
        fonte: AberturaFalsa(),
        chave: 'm02',
        som: false,
      );
      await tester.pump(const Duration(milliseconds: 50));

      expect(
        audio.chamadasDoPlayer,
        isEmpty,
        reason: 'mudo, e ainda assim alguma coisa foi pedida ao plugin',
      );
    });

    testWidgets(
      'M03 movimento reduzido + áudio permitido: o som CONTINUA',
      (tester) async {
        await _montarAbertura(
          tester,
          fonte: AberturaFalsa(),
          chave: 'm03',
          movimentoReduzido: true,
          som: true,
        );
        await tester.pump(const Duration(milliseconds: 50));

        // ESTA É A LINHA QUE REPROVA A RECOUPLAGEM. Enquanto `_tocarSom()`
        // morou dentro do ramo de movimento normal, ela media zero.
        expect(
          audio.playersAbertos,
          1,
          reason:
              'reduzir movimento voltou a silenciar a abertura — o áudio '
              'obedece a `habilitarSom`, nunca a `disableAnimations`',
        );
      },
    );

    testWidgets(
      'M04 movimento reduzido + áudio mutado: mudo continua mudo',
      (tester) async {
        await _montarAbertura(
          tester,
          fonte: AberturaFalsa(),
          chave: 'm04',
          movimentoReduzido: true,
          som: false,
        );
        await tester.pump(const Duration(milliseconds: 50));

        // O OUTRO LADO DA MESMA LINHA: desacoplar não pode virar "toca
        // sempre". Movimento reduzido não liga áudio que a jogadora desligou.
        expect(
          audio.chamadasDoPlayer,
          isEmpty,
          reason: 'movimento reduzido passou a LIGAR som que estava desligado',
        );
      },
    );

    // -----------------------------------------------------------------------
    // M05: o volume pedido é o mesmo nos dois ramos de movimento
    // -----------------------------------------------------------------------

    testWidgets('M05 o volume não é abaixado pelo movimento reduzido', (
      tester,
    ) async {
      await _montarAbertura(
        tester,
        fonte: AberturaFalsa(),
        chave: 'm05a',
        som: true,
      );
      await tester.pump(const Duration(milliseconds: 50));
      final normal = audio.volumes;

      audio.limpar();
      await _montarAbertura(
        tester,
        fonte: AberturaFalsa(),
        chave: 'm05b',
        movimentoReduzido: true,
        som: true,
      );
      await tester.pump(const Duration(milliseconds: 50));
      final reduzido = audio.volumes;

      // ANCORADO NA CONTAGEM, e não só na igualdade: duas listas vazias também
      // são iguais, e passariam sem provar nada.
      expect(normal, hasLength(1), reason: 'o volume deixou de ser pedido');
      expect(reduzido, hasLength(1));
      expect(
        reduzido.single,
        normal.single,
        reason: 'o ramo reduzido passou a pedir outro volume',
      );
    });

    // -----------------------------------------------------------------------
    // M06–M10: as propriedades que a matriz não pode quebrar
    // -----------------------------------------------------------------------
    //
    // Estas são transversais: valem nos QUATRO estados, e o laço é ancorado
    // logo abaixo por uma contagem — sem ela, apagar entradas de `_kMatriz`
    // deixaria o grupo verde com menos casos do que a OS exige.

    test('M06 a matriz tem os quatro estados que a OS pede', () {
      expect(_kMatriz, hasLength(4));
      expect(
        _kMatriz.map((e) => '${e.movimentoReduzido}/${e.som}').toSet(),
        <String>{'false/true', 'false/false', 'true/true', 'true/false'},
        reason: 'a matriz deixou de cobrir as quatro combinações',
      );
    });

    for (final estado in _kMatriz) {
      testWidgets('M07 [${estado.nome}] pular imediatamente: UMA saída', (
        tester,
      ) async {
        final saidas = await _montarAbertura(
          tester,
          fonte: AberturaFalsa(),
          chave: 'm07-${estado.chave}',
          movimentoReduzido: estado.movimentoReduzido,
          som: estado.som,
        );
        await tester.pump();

        expect(saidas(), 0);
        await tester.tap(find.byType(TextButton));
        await tester.pump();
        expect(saidas(), 1, reason: 'pular não encerrou a abertura');

        // "Pular abertura" continua passando por `_encerrarAnimacao()`, e é
        // por isso que o botão sai da árvore e o relógio não produz uma
        // segunda saída.
        expect(find.byType(TextButton), findsNothing);
        await tester.pump(const Duration(seconds: 1));
        expect(saidas(), 1, reason: 'houve uma segunda conclusão');
      });

      testWidgets('M08 [${estado.nome}] conclusão natural: UMA saída', (
        tester,
      ) async {
        final saidas = await _montarAbertura(
          tester,
          fonte: AberturaFalsa(
            duracaoDaTimeline: const Duration(milliseconds: 100),
          ),
          chave: 'm08-${estado.chave}',
          movimentoReduzido: estado.movimentoReduzido,
          som: estado.som,
        );
        await tester.pump();
        expect(saidas(), 0);

        // No ramo reduzido quem encerra é a janela curta (300 ms × 1/5); no
        // outro, a timeline. Os dois horizontes cabem nesta espera, e o que se
        // afirma é o mesmo nos dois: encerrou, e uma vez só.
        await tester.pump(const Duration(milliseconds: 150));
        expect(saidas(), 1, reason: 'a abertura não terminou sozinha');

        await tester.pump(const Duration(seconds: 1));
        expect(
          saidas(),
          1,
          reason: 'o relógio de segurança produziu uma segunda saída',
        );
      });

      testWidgets(
        'M09 [${estado.nome}] depois de encerrar, o som para e nada recomeça',
        (tester) async {
          final saidas = await _montarAbertura(
            tester,
            fonte: AberturaFalsa(),
            chave: 'm09-${estado.chave}',
            movimentoReduzido: estado.movimentoReduzido,
            som: estado.som,
          );
          await tester.pump(const Duration(milliseconds: 50));

          final antes = audio.chamadasDoPlayer.length;
          await tester.tap(find.byType(TextButton));
          await tester.pump();
          await tester.pump(const Duration(seconds: 1));
          expect(saidas(), 1);

          final depois = audio.chamadasDoPlayer.skip(antes).toList();
          expect(
            depois.where(_reiniciaOSom),
            isEmpty,
            reason: 'a abertura mandou o som recomeçar depois de encerrar',
          );
          // ÂNCORA: com som permitido tem de haver a parada. Sem esta linha, o
          // caso passaria por lista vazia — inclusive num futuro em que o
          // `stop` deixasse de ser enviado.
          expect(
            depois.where((m) => m == 'stop'),
            estado.som ? hasLength(1) : isEmpty,
            reason: 'o encerramento deixou de silenciar o que estava tocando',
          );
        },
      );

      testWidgets('M10 [${estado.nome}] a abertura continua falando', (
        tester,
      ) async {
        final manipulador = tester.ensureSemantics();
        await _montarAbertura(
          tester,
          fonte: AberturaFalsa(),
          chave: 'm10-${estado.chave}',
          movimentoReduzido: estado.movimentoReduzido,
          som: estado.som,
        );
        await tester.pump();

        // O anúncio da OS 11.1, intacto: uma frase, e uma só.
        expect(find.bySemanticsLabel(kRotuloDaAbertura), findsOneWidget);

        // E o botão, com nome, papel, estado e alvo medido no que RECEBE o
        // toque — não na pintura.
        final botao = find.byType(TextButton);
        final dados = tester.getSemantics(botao).getSemanticsData();
        expect(dados.label, kRotuloDePular);
        expect(dados.flagsCollection.isButton, isTrue);
        expect(dados.flagsCollection.isEnabled, Tristate.isTrue);
        expect(dados.hasAction(SemanticsAction.tap), isTrue);

        final alvo = tester.getSize(botao);
        expect(alvo.width, greaterThanOrEqualTo(kAlvoMinimoDePular));
        expect(alvo.height, greaterThanOrEqualTo(kAlvoMinimoDePular));
        manipulador.dispose();
      });
    }

    // -----------------------------------------------------------------------
    // M11: o ramo reduzido continua sendo o ramo reduzido
    // -----------------------------------------------------------------------

    testWidgets('M11 som ligado não devolve animação ao ramo reduzido', (
      tester,
    ) async {
      final fonte = AberturaFalsa();
      await _montarAbertura(
        tester,
        fonte: fonte,
        chave: 'm11',
        movimentoReduzido: true,
        som: true,
      );
      await tester.pump(const Duration(milliseconds: 20));

      // Desacoplar é nos DOIS sentidos: o som passou a tocar aqui, e a
      // apresentação animada continua desligada. A arte não é nem carregada, e
      // a constelação — que é imagem parada — entra sem fade.
      expect(
        fonte.carregamentos,
        0,
        reason: 'a animação voltou ao ramo reduzido',
      );
      expect(find.byKey(kChaveDaArteFalsa), findsNothing);
      expect(find.byType(SvgPicture), findsOneWidget);
      expect(find.byType(TweenAnimationBuilder<double>), findsNothing);
    });

    // -----------------------------------------------------------------------
    // M12–M13: as duas guardas estruturais
    // -----------------------------------------------------------------------

    test('M12 o pedido de som está FORA do ramo de movimento reduzido', () {
      final tela = _semComentarios(
        File(
          'lib/casca/splash/splash_constelacao_screen.dart',
        ).readAsStringSync(),
      );

      final inicio = tela.indexOf('void didChangeDependencies()');
      expect(
        inicio,
        isNonNegative,
        reason: 'a entrada da abertura mudou de nome',
      );
      final corpo = tela.substring(inicio);

      final pedidoDeSom = corpo.indexOf('_tocarSom()');
      final ramoReduzido = corpo.indexOf('if (_movimentoReduzido)');
      expect(
        pedidoDeSom,
        isNonNegative,
        reason: 'a abertura parou de pedir som',
      );
      expect(ramoReduzido, isNonNegative);

      // A ORDEM É A AFIRMAÇÃO. Dentro do ramo, o pedido viria depois — foi
      // exatamente essa a posição que a OS 11.2 veio desfazer.
      expect(
        pedidoDeSom,
        lessThan(ramoReduzido),
        reason:
            '`_tocarSom()` voltou para dentro (ou para depois) do ramo de '
            'movimento reduzido: movimento voltou a decidir áudio',
      );

      // E a autoridade do som continua sendo uma só, com o nome que ela tem.
      expect(
        tela,
        contains('if (!widget.habilitarSom) return'),
        reason:
            'a autoridade de áudio da abertura deixou de ser `habilitarSom`',
      );
    });

    test('M13 a matriz de §11.2 não pode ser esvaziada em silêncio', () {
      // ESTA GUARDA MORA DENTRO DO GLOB QUE O PORTÃO RODA, e é de propósito: o
      // portão da abertura, no `build.yml`, exige que ESTE ARQUIVO exista e
      // roda a suíte inteira — mas ele não sabe o que tem dentro. Sem esta
      // contagem, apagar os casos de som deixaria o portão verde.
      final fonte = File(
        'test/splash/splash_constelacao_test.dart',
      ).readAsStringSync();

      // Casados pela FORMA DA CHAMADA, e não por comentário: um caso removido
      // e explicado em prosa continuaria contando, e o "conserto" seria apagar
      // a explicação.
      final casos = RegExp(
        "(?:testWidgets|test)\\(\\s*\\n?\\s*'M[0-9][0-9] ",
      ).allMatches(fonte).length;
      expect(
        casos,
        greaterThanOrEqualTo(13),
        reason:
            'a matriz de áudio × movimento encolheu: $casos casos M, e a OS '
            '11.2 exige 13',
      );

      // E as duas autoridades continuam nomeadas em lugares diferentes.
      expect(fonte, contains('audio.playersAbertos'));
      expect(fonte, contains('movimentoReduzido: true'));
    });
  });
}

// ===========================================================================
// Ferramentas
// ===========================================================================

/// Todos os `.dart` do cliente, menos os bundles que compilam para as Cloud
/// Functions. Mesmo recorte de `auditoria_casca_test.dart`.
List<File> _fontesDoCliente() =>
    Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) {
          final n = f.path.replaceAll(r'\', '/');
          return !n.contains('/social/') &&
              !n.contains('/moderacao/') &&
              !n.endsWith('js_bridge.dart');
        })
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

/// O código sem comentários.
///
/// Pela mesma razão de `auditoria_casca_test.dart`: esta suíte explica em prosa
/// o que ela proíbe, e uma varredura ingênua acusaria a própria explicação —
/// com o agravante de que o "conserto" seria apagar a documentação.
String _semComentarios(String fonte) {
  final saida = StringBuffer();
  var i = 0;
  String? aspa;
  while (i < fonte.length) {
    final c = fonte[i];
    final proximo = i + 1 < fonte.length ? fonte[i + 1] : '';
    if (aspa != null) {
      saida.write(c);
      if (c == r'\') {
        if (proximo.isNotEmpty) saida.write(proximo);
        i += 2;
        continue;
      }
      if (c == aspa) aspa = null;
      i++;
      continue;
    }
    if (c == '/' && proximo == '/') {
      while (i < fonte.length && fonte[i] != '\n') {
        i++;
      }
      continue;
    }
    if (c == '/' && proximo == '*') {
      i += 2;
      while (i < fonte.length &&
          !(fonte[i] == '*' && i + 1 < fonte.length && fonte[i + 1] == '/')) {
        i++;
      }
      i += 2;
      continue;
    }
    if (c == "'" || c == '"') aspa = c;
    saida.write(c);
    i++;
  }
  return saida.toString();
}

/// O texto aparece nos bytes.
bool _contem(Uint8List bytes, String texto) {
  final alvo = texto.codeUnits;
  for (var i = 0; i + alvo.length <= bytes.length; i++) {
    var bate = true;
    for (var j = 0; j < alvo.length; j++) {
      if (bytes[i + j] != alvo[j]) {
        bate = false;
        break;
      }
    }
    if (bate) return true;
  }
  return false;
}

/// Todo o texto desenhado na tela, na ordem da árvore.
///
/// Existe porque `find.byType(Text), findsNothing` deixou de servir: a
/// abertura passou a ter UM texto legítimo — o rótulo da ação de pular — e a
/// pergunta que importa virou QUAL texto está lá, não QUANTOS.
List<String> _textosDaTela(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '')
    .toList();

// ===========================================================================
// §11.2 — a matriz de áudio × movimento, e como ela é escutada
// ===========================================================================

/// Uma das quatro combinações de "movimento reduzido × áudio permitido".
class _Estado {
  const _Estado(
    this.nome, {
    required this.movimentoReduzido,
    required this.som,
  });

  final String nome;

  /// A plataforma pediu animações reduzidas.
  final bool movimentoReduzido;

  /// A jogadora permitiu som — a autoridade de áudio da abertura.
  final bool som;

  /// Sufixo de chave de widget. Sem ele, duas montagens do mesmo caso
  /// reaproveitariam o `State` da anterior e mediriam a primeira duas vezes.
  String get chave =>
      '${movimentoReduzido ? 'red' : 'nor'}-${som ? 'som' : 'mudo'}';
}

/// AS QUATRO COMBINAÇÕES, DECLARADAS UMA VEZ.
///
/// Elas são o eixo da OS 11.2: movimento reduzido e áudio permitido são
/// perguntas independentes, e a suíte só prova isso se percorrer o produto das
/// duas — não uma diagonal conveniente. `M06` ancora a lista pela contagem e
/// pelo conjunto, para que apagar uma linha daqui reprove em vez de encolher a
/// cobertura em silêncio.
const List<_Estado> _kMatriz = <_Estado>[
  _Estado('normal + som', movimentoReduzido: false, som: true),
  _Estado('normal + mudo', movimentoReduzido: false, som: false),
  _Estado('reduzido + som', movimentoReduzido: true, som: true),
  _Estado('reduzido + mudo', movimentoReduzido: true, som: false),
];

/// Os métodos do plugin que FAZEM som voltar a existir.
///
/// Depois de a abertura encerrar, nenhum deles pode ser pedido: uma abertura
/// que já saiu de cena tocando por cima da tela seguinte é o defeito que `M09`
/// existe para impedir.
bool _reiniciaOSom(String metodo) => const <String>{
  'resume',
  'play',
  'setSourceUrl',
  'setSourceBytes',
}.contains(metodo);

/// O escopo GLOBAL do `audioplayers`, refeito a cada caso.
///
/// ---------------------------------------------------------------------------
/// POR QUE ISTO PRECISA EXISTIR, E POR QUE NÃO É ELE QUE ESTÁ SENDO MEDIDO
/// ---------------------------------------------------------------------------
///
/// O pacote inicializa o lado nativo UMA vez por processo e guarda o resultado
/// num `Completer` estático. Dentro de `flutter test` cada caso roda na sua
/// própria zona de tempo falso, e um `Future` completado na zona do primeiro
/// caso NUNCA entrega nos seguintes — a zona que agendaria a continuação já
/// morreu. Na prática: sem esta troca, só o PRIMEIRO caso do processo consegue
/// abrir um player, e todos os outros medem zero por motivo de ambiente. Foi
/// exatamente isso que aconteceu na primeira medição desta matriz, e um "zero"
/// desses é indistinguível do defeito que a OS 11.2 veio corrigir.
///
/// Trocar a instância faz o pacote considerar a plataforma "nova" e refazer a
/// inicialização dentro da zona do caso corrente.
///
/// O que isto substitui é só o `init` global. O caminho que a suíte de fato
/// mede — `AudioPlayer()`, `play`, `stop` — continua indo pelo canal REAL do
/// plugin, e é ele que [_EscutaDoAudio] escuta.
class _EscopoGlobalDoAudio extends GlobalAudioplayersPlatformInterface {
  @override
  Future<void> init() async {}

  @override
  Future<void> setGlobalAudioContext(AudioContext ctx) async {}

  @override
  Future<void> emitGlobalLog(String message) async {}

  @override
  Future<void> emitGlobalError(String code, String message) async {}

  @override
  Stream<GlobalAudioEvent> getGlobalEventStream() =>
      const Stream<GlobalAudioEvent>.empty();
}

/// O que a abertura pediu ao plugin de áudio, na ordem.
///
/// ---------------------------------------------------------------------------
/// NÃO É UM DUBLÊ DE CONVENIÊNCIA
/// ---------------------------------------------------------------------------
///
/// É o canal REAL do `audioplayers` — `xyz.luan/audioplayers` —, interceptado
/// pela costura padrão do `flutter_test`. Nada no código de produção sabe que
/// esta escuta existe: a tela constrói o `AudioPlayer` de sempre, com o asset
/// de sempre, e o que cai nesta lista é literalmente o que sairia para o lado
/// nativo no aparelho de quem joga.
///
/// É por isso que ela consegue responder "houve som?" num ambiente onde o
/// plugin de áudio não está instalado. A reprodução em si nunca completa dentro
/// de `flutter test` — o `audioplayers` copia o asset para o disco pelo
/// `path_provider`, que também não existe aqui —, e não é ela que está em
/// questão. O que está em questão é se a abertura CHEGA A PEDIR.
///
/// Sem esta escuta, a alternativa seria pendurar um contador dentro da tela só
/// para o teste olhar. Isso provaria que a tela concorda consigo mesma, e não
/// que o som foi pedido.
class _EscutaDoAudio {
  static const MethodChannel _doPlayer = MethodChannel('xyz.luan/audioplayers');

  final List<MethodCall> chamadas = <MethodCall>[];

  List<String> get chamadasDoPlayer =>
      chamadas.map((c) => c.method).toList(growable: false);

  /// Quantos players a abertura abriu.
  ///
  /// `create` é a assinatura de `AudioPlayer()` no canal, e é exatamente a
  /// chamada que não acontecia no ramo de movimento reduzido.
  int get playersAbertos => chamadas.where((c) => c.method == 'create').length;

  /// Os volumes pedidos, na ordem. Vem de `play(volume: …)`.
  List<double> get volumes => chamadas
      .where((c) => c.method == 'setVolume')
      .map(
        (c) =>
            ((c.arguments as Map<Object?, Object?>)['volume'] as num).toDouble(),
      )
      .toList();

  void limpar() => chamadas.clear();

  void instalar() {
    // Antes do mock, e não depois: o escopo global tem de estar trocado quando
    // o primeiro `AudioPlayer` do caso for construído. Ver
    // [_EscopoGlobalDoAudio].
    GlobalAudioplayersPlatformInterface.instance = _EscopoGlobalDoAudio();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_doPlayer, (chamada) async {
          chamadas.add(chamada);
          return null;
        });
  }

  void remover() =>
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_doPlayer, null);
}
