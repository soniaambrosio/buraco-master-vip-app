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

import 'package:buraco_master_vip/casca/home_de_producao.dart';
import 'package:buraco_master_vip/casca/login_de_producao.dart';
import 'package:buraco_master_vip/casca/raiz_do_aplicativo.dart';
import 'package:buraco_master_vip/casca/splash/contrato_da_abertura.dart';
import 'package:buraco_master_vip/casca/splash/splash_constelacao_screen.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
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
              habilitarSom: false,
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
      final indiceDaArte = pilha.children.indexWhere(
        (w) => w.key == kChaveDaArteFalsa,
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
      expect(find.byType(Text), findsNothing);

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
          // Nada de arte, nada de texto técnico, nada de indicador: só o fundo.
          expect(find.byKey(kChaveDaArteFalsa), findsNothing);
          expect(find.byType(Text), findsNothing);
          expect(find.byType(CircularProgressIndicator), findsNothing);
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

    testWidgets('L02 não há AppBar, texto nem controle durante a abertura', (
      tester,
    ) async {
      await _montarAbertura(tester, fonte: AberturaFalsa());
      await tester.pump();
      expect(find.byType(AppBar), findsNothing);
      expect(find.byType(Text), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(ElevatedButton), findsNothing);
      expect(find.byType(TextButton), findsNothing);
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
