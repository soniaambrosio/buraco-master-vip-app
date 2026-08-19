// inspecao_ampliada_test.dart — ampliar não pode ser um jeito torto de comprar.
//
// ---------------------------------------------------------------------------
// O DEFEITO QUE ESTA SUÍTE PERSEGUE
// ---------------------------------------------------------------------------
//
// Um card de cosmético tem 130 pixels de largura e três alvos de toque muito
// perto uns dos outros: a arte, o botão Comprar/Equipar e o botão de
// presentear. Acrescentar "toque na arte para ver de perto" é acrescentar um
// quarto gesto num espaço que já era apertado — e o modo de falhar não é a
// ampliação não abrir. É a ampliação abrir E a compra acontecer, ou a compra
// acontecer no lugar da ampliação. Quem toca para OLHAR não pode acabar
// pagando.
//
// Por isso a maior parte dos casos aqui não pergunta "a inspeção funciona?".
// Pergunta "o que MAIS aconteceu?" — e a resposta exigida é: nada.
//
// ---------------------------------------------------------------------------
// AS CINCO MUTAÇÕES QUE A OS MANDA MATAR, E ONDE CADA UMA MORRE
// ---------------------------------------------------------------------------
//
//   inspeção vira compra ........ S1, S2, S3, M2, M5
//   inspeção vira equipar ....... S1, S2, S3, M2, M5
//   overlay captura o botão ..... S3, S4, M4
//   fechamento impedido ......... F1, F2, F3
//   estado vaza entre itens ..... V1, V2
//
// S2/M2/M4/M5 são estruturais de propósito. Um teste de comportamento prova
// que HOJE o toque na arte não compra; ele não prova que amanhã alguém não vai
// envolver o card inteiro no alvo e devolver a ambiguidade. S2 olha a ÁRVORE de
// widgets e exige que o botão não seja descendente do alvo; M2 olha o CÓDIGO do
// módulo e exige que não exista campo de callback por onde uma compra pudesse
// entrar.
//
// SUPERFÍCIE DE TELEFONE: o padrão do `flutter_test` é 800x600, que é paisagem
// de desktop e faz telas de celular estourarem em overflow.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:buraco_master_vip/cosmeticos/inspecao_ampliada.dart';
import 'package:buraco_master_vip/screens/loja_categoria_screen.dart';
import 'package:buraco_master_vip/screens/loja_screen.dart' show LojaCategoria;
import 'package:buraco_master_vip/screens/perfil_screen.dart';

// ===========================================================================
// Superfície e utilidades
// ===========================================================================

const Size _telefone = Size(390, 844);

Future<void> _emTelefone(WidgetTester tester) async {
  tester.view.physicalSize = _telefone;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Widget _casca(Widget filho) => MaterialApp(home: filho);

/// Um item de teste, com tudo explícito e nada implícito.
ItemInspecionavel _item({
  String id = 'item_x',
  String nome = 'Pérola Negra',
  CategoriaInspecao categoria = CategoriaInspecao.moldura,
  EstadoInspecao estado = EstadoInspecao.disponivel,
  String previa = 'assets/loja/molduras/perola_negra.webp',
  String? detalhe,
}) {
  return ItemInspecionavel(
    id: id,
    nome: nome,
    categoria: categoria,
    estado: estado,
    previa: previa,
    detalhe: detalhe,
  );
}

/// Uma tela mínima com UM alvo de inspeção e UM botão perigoso ao lado.
///
/// O botão existe para ser vigiado: [comprasDisparadas] só sobe se ele for
/// acionado, e nenhum caso desta suíte tem o direito de fazê-lo subir.
class _Bancada extends StatelessWidget {
  final ItemInspecionavel item;
  final VoidCallback onComprar;

  const _Bancada({required this.item, required this.onComprar});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 120,
              height: 120,
              child: AlvoDeInspecao(
                item: item,
                child: const ColoredBox(color: Color(0xFF332211)),
              ),
            ),
            FilledButton(onPressed: onComprar, child: const Text('Comprar')),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// O catálogo da Loja, encenado
// ===========================================================================

/// UM ITEM DA LOJA, COM ARTE QUE EXISTE NESTA LINHAGEM.
///
/// A prévia aponta para `assets/perfil/` e não para `assets/loja/`, e o motivo
/// é factual: `assets/loja/` NÃO EXISTE nesta base — as 46 artes da Loja vivem
/// noutra branch. A folha de confirmação de compra desenha a prévia com um
/// `Image.asset` sem `errorBuilder`, e um asset ausente ali vira exceção de
/// verdade no meio do caso.
///
/// Apontar para uma arte declarada no `pubspec` tira do caminho um defeito de
/// EMPACOTAMENTO que não é o que esta suíte investiga. Se a arte da Loja
/// entrar um dia, nada aqui muda: a inspeção nunca leu o caminho, só o repassou.
ItemCosmetico _cosmetico({
  String id = 'moldura_rubi',
  String nome = 'Rubi',
  Raridade raridade = Raridade.lendario,
  ItemEstado estado = ItemEstado.disponivel,
  bool presenteavel = true,
}) {
  return ItemCosmetico(
    id: id,
    nome: nome,
    raridade: raridade,
    preco: 1800,
    moeda: MoedaTipo.moedas,
    previa: 'assets/perfil/vitrine_moldura.webp',
    estado: estado,
    soVip: false,
    presenteavel: presenteavel,
  );
}

/// O que a Loja poderia mexer sem ninguém ver, contado.
///
/// É um livro-caixa: a suíte compara o ANTES e o DEPOIS de cada inspeção. Se um
/// número mudar, a ampliação deixou de ser só olhar.
class _LivroDaLoja {
  int compras = 0;
  int confirmacoes = 0;
  int equipar = 0;
  int bloqueados = 0;
  int presentear = 0;
  int enviosDePresente = 0;
  int moedas = 0;

  List<int> get fotografia => [
        compras,
        confirmacoes,
        equipar,
        bloqueados,
        presentear,
        enviosDePresente,
        moedas,
      ];
}

Widget _lojaCategoria(_LivroDaLoja livro, {required List<ItemCosmetico> itens}) {
  return _casca(
    LojaCategoriaScreen(
      vm: LojaCategoriaVM(
        categoria: LojaCategoria.molduras,
        titulo: 'Molduras',
        moedas: 1000,
        gemas: 28,
        ehVip: false,
        itens: itens,
        amigos: const [
          AmigoPresente(id: 'ana', nome: 'Ana Bella', avatar: '🐰'),
        ],
      ),
      onVoltar: () {},
      onComprarMoedas: () => livro.moedas++,
      onComprar: (_) => livro.compras++,
      onConfirmarCompra: (_) => livro.confirmacoes++,
      onEquipar: (_) => livro.equipar++,
      onItemBloqueado: (_) => livro.bloqueados++,
      onPresentear: (_) => livro.presentear++,
      onBuscarPresenteado: (_) {},
      onEnviarPresente: (_, _) => livro.enviosDePresente++,
      onNav: (_) {},
    ),
  );
}

// ===========================================================================
// O Perfil, encenado
// ===========================================================================

class _LivroDoPerfil {
  int abriuPresentes = 0;
  int fechouPresentes = 0;
  int trocouVitrine = 0;
  int trocouAvatar = 0;
  int editouPerfil = 0;
  int viuConquista = 0;

  List<int> get fotografia => [
        abriuPresentes,
        fechouPresentes,
        trocouVitrine,
        trocouAvatar,
        editouPerfil,
        viuConquista,
      ];
}

PerfilVM _perfilVM() {
  return PerfilVM(
    ehMeuPerfil: true,
    nome: 'Ana Bella',
    avatar: '👑',
    mascote: '🦊',
    moldura: 'assets/perfil/vitrine_moldura.webp',
    dorso: 'assets/perfil/vitrine_dorso.webp',
    efeito: 'assets/perfil/vitrine_efeito.webp',
    nivel: null,
    xpAtual: null,
    xpProximo: null,
    titulo: null,
    tituloEmoji: null,
    ranking: const EstadoRanking.indisponivel(),
    stats: null,
    ultimaConquista: null,
    presentesCount: 2,
    conquistas: null,
    vitrine: const [
      ItemVitrine(
        slot: 'moldura',
        nome: 'Moldura',
        icone: 'assets/perfil/vitrine_moldura.webp',
      ),
      ItemVitrine(
        slot: 'mascote',
        nome: 'Mascote',
        icone: 'assets/perfil/vitrine_mascote.webp',
      ),
      ItemVitrine(
        slot: 'dorso',
        nome: 'Dorso',
        icone: 'assets/perfil/vitrine_dorso.webp',
      ),
      // Um slot que a lista NÃO conhece: prova que o desconhecido continua
      // inspecionável, e que ele não recebe rótulo chutado.
      ItemVitrine(slot: 'feltro_da_mesa', nome: 'Feltro', icone: '🟩'),
    ],
    presentes: const [
      Presente(
        id: 'rosa',
        nome: 'Rosa',
        icone: 'assets/perfil/presente_rosa.webp',
        quantidade: 3,
      ),
      Presente(
        id: 'bombom',
        nome: 'Bombom',
        icone: 'assets/perfil/presente_bombom.webp',
        quantidade: 7,
      ),
    ],
  );
}

Widget _perfil(_LivroDoPerfil livro, {PerfilVM? vm}) {
  return _casca(
    PerfilScreen(
      vm: vm ?? _perfilVM(),
      onVoltar: () {},
      onAbrirConfig: () {},
      onTrocarAvatar: () => livro.trocouAvatar++,
      onEditarNick: () {},
      onEditarPerfil: () => livro.editouPerfil++,
      onAbrirPresentes: () => livro.abriuPresentes++,
      onFecharPresentes: () => livro.fechouPresentes++,
      onVerTodasConquistas: () {},
      onVerConquista: (_) => livro.viuConquista++,
      onVerUltimaConquista: () {},
      onTrocarVitrine: () => livro.trocouVitrine++,
      onCompartilhar: () {},
      onRecarregar: () {},
      onNavTap: (_) {},
    ),
  );
}

// ===========================================================================
// Leitura do código-fonte, para os casos estruturais
// ===========================================================================

File _fonteDoModulo() {
  final f = File('lib/cosmeticos/inspecao_ampliada.dart');
  if (!f.existsSync()) {
    fail('lib/cosmeticos/inspecao_ampliada.dart sumiu — a inspeção ampliada '
        'deixou de ter um módulo próprio');
  }
  return f;
}

/// O arquivo SEM comentários.
///
/// Sem isso a varredura casa com a própria prosa: este módulo EXPLICA que não
/// compra e não equipa, e as palavras "comprar" e "equipar" aparecem nessas
/// frases. Um teste que lesse comentário reprovaria o arquivo por dizer a
/// verdade sobre si mesmo.
String _codigo(File f) {
  final saida = StringBuffer();
  for (final linha in f.readAsLinesSync()) {
    final semLinha = linha.replaceAll(RegExp(r'//.*$'), '');
    saida.writeln(semLinha);
  }
  return saida.toString();
}

// ===========================================================================
// Superfícies e formas de arte, para a responsividade
//
// A OS manda medir quatro telas e três formas de item. As duas listas abaixo
// são o enunciado dela transcrito, e o cruzamento delas vira doze casos.
// ===========================================================================

class _Superficie {
  final String nome;
  final Size tamanho;
  const _Superficie(this.nome, this.tamanho);
}

const List<_Superficie> _superficies = [
  _Superficie('360x800', Size(360, 800)),
  _Superficie('390x844', Size(390, 844)),
  _Superficie('412x915', Size(412, 915)),
  // O tablet não é "um celular grande": é a única superfície em que sobra
  // largura, e onde um cartão sem teto viraria uma arte de 700 pixels no meio
  // do nada. O `maxWidth: 380` do módulo é o que impede isso, e é aqui que ele
  // é medido.
  _Superficie('tablet 800x1280', Size(800, 1280)),
];

/// Uma arte REAL do projeto, com a proporção que ela tem de verdade.
///
/// Nenhuma das três é sintética, e isso é de propósito: uma imagem inventada
/// no teste provaria que o `contain` funciona sobre uma imagem inventada. O
/// dorso do baralho é o cosmético mais vertical que existe no repositório, o
/// presente é o mais horizontal, e o selo de premiação é exatamente quadrado.
class _Forma {
  final String nome;
  final String caminho;
  final double razao;
  const _Forma(this.nome, this.caminho, this.razao);
}

const List<_Forma> _formas = [
  _Forma('item vertical', 'assets/baralho/dorso.webp', 907 / 1210),
  _Forma('item horizontal', 'assets/perfil/presente_diamante.webp', 170 / 115),
  _Forma(
    'item quadrado',
    'assets/torneios/premiacao/selos/seal_runner_up.png',
    1,
  ),
];

Future<void> _emTela(WidgetTester tester, Size tamanho) async {
  tester.view.physicalSize = tamanho;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// O pacote de assets lido do DISCO, e não do bundle empacotado.
///
/// Sem isto os casos de proporção seriam decorativos. No workflow do APK o
/// passo que DECLARA os assets no `pubspec` roda depois dos portões de teste —
/// as artes já estão copiadas em `app_build/assets/`, mas o `rootBundle` ainda
/// não as conhece. Um `Image.asset` ali cai no `errorBuilder`, e um caso que
/// medisse a forma da arte estaria medindo o ícone de falha, verde e vazio.
///
/// Lendo do disco, o caso mede o mesmo arquivo `.webp` que vai para o APK, no
/// CI e na máquina, e falha alto se o arquivo sumir.
class _BundleDeDisco extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    // O `AssetImage` NÃO pede a arte primeiro: pede o MANIFESTO, para escolher
    // a variante de densidade. Um manifesto vazio responde "esta arte não tem
    // variante", e aí o caminho pedido é o caminho lido. Sem isto o manifesto
    // ausente derruba a resolução inteira antes de chegar na arte, o item cai
    // no `errorBuilder`, e o caso mediria o ícone de falha achando que mede a
    // moldura.
    if (key.startsWith('AssetManifest')) {
      return const StandardMessageCodec().encodeMessage(<String, Object?>{})!;
    }
    final arquivo = File(key);
    if (!arquivo.existsSync()) {
      throw FlutterError('asset ausente no disco: $key');
    }
    return ByteData.sublistView(arquivo.readAsBytesSync());
  }
}

Widget _cascaComDisco(Widget filho) =>
    DefaultAssetBundle(bundle: _BundleDeDisco(), child: _casca(filho));

/// Uma tela com um alvo de inspeção e nada mais.
Widget _bancadaDeArte(ItemInspecionavel item) => _cascaComDisco(
      Scaffold(
        body: Center(
          child: AlvoDeInspecao(
            item: item,
            child: const SizedBox(width: 90, height: 90),
          ),
        ),
      ),
    );

/// Deixa a decodificação REAL acontecer.
///
/// Ler o arquivo e passá-lo pelo codec é trabalho de verdade da engine, e o
/// relógio falso do `flutter_test` não o faz andar: sem `runAsync` a imagem
/// nunca chega ao `RenderImage` e `render.image` fica nulo para sempre.
Future<void> _decodifica(WidgetTester tester) async {
  await tester.runAsync(() async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
  });
  await tester.pump();
}

/// O tamanho lógico da tela montada agora.
Size _tamanhoLogico(WidgetTester tester) =>
    tester.view.physicalSize / tester.view.devicePixelRatio;

/// O perfil de OUTRA pessoa, com cosméticos que não são os meus.
///
/// Cada peça tem nome próprio e inconfundível. Se a inspeção de um perfil
/// visitado desenhar o item do visitante, é por esses nomes que se descobre —
/// e nenhum deles coincide com os de [_perfilVM].
PerfilVM _perfilVMVisitado() {
  return PerfilVM(
    ehMeuPerfil: false,
    nome: 'Rita do Buraco',
    avatar: '🎩',
    mascote: '🦁',
    moldura: 'assets/perfil/vitrine_moldura.webp',
    dorso: 'assets/perfil/vitrine_dorso.webp',
    efeito: 'assets/perfil/vitrine_efeito.webp',
    nivel: null,
    xpAtual: null,
    xpProximo: null,
    titulo: null,
    tituloEmoji: null,
    ranking: const EstadoRanking.indisponivel(),
    stats: null,
    ultimaConquista: null,
    presentesCount: null,
    conquistas: null,
    vitrine: const [
      ItemVitrine(
        slot: 'moldura',
        nome: 'Coroa da Rita',
        icone: 'assets/perfil/vitrine_moldura.webp',
      ),
      ItemVitrine(
        slot: 'dorso',
        nome: 'Dorso da Rita',
        icone: 'assets/perfil/vitrine_dorso.webp',
      ),
    ],
    presentes: const [],
  );
}
void main() {
  // =========================================================================
  // §1 — AS OITO CATEGORIAS DA OS
  //
  // Uma por caso, e todas pelo MESMO widget: é essa igualdade que torna a
  // cobertura honesta. Se cada categoria tivesse tela própria, oito casos
  // verdes provariam oito coisas diferentes.
  // =========================================================================
  group('C — as categorias que a OS enumera abrem a inspeção', () {
    Future<void> abreEAnuncia(
      WidgetTester tester,
      CategoriaInspecao categoria,
      String rotuloEsperado,
    ) async {
      await _emTelefone(tester);
      final livro = <String>[];
      await tester.pumpWidget(
        _casca(
          Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: AlvoDeInspecao(
                  item: _item(
                    nome: 'Peça de teste',
                    categoria: categoria,
                    previa: '🟨',
                  ),
                  child: const SizedBox(width: 90, height: 90),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(InspecaoAmpliada), findsNothing);
      await tester.tap(find.byType(AlvoDeInspecao));
      await tester.pumpAndSettle();

      expect(
        find.byType(InspecaoAmpliada),
        findsOneWidget,
        reason: '$categoria não abriu a inspeção',
      );
      expect(find.text(rotuloEsperado), findsOneWidget);
      expect(find.text('Peça de teste'), findsOneWidget);
      expect(livro, isEmpty);
    }

    testWidgets('C1 moldura', (t) async {
      await abreEAnuncia(t, CategoriaInspecao.moldura, 'Moldura');
    });

    testWidgets('C2 verso de carta', (t) async {
      await abreEAnuncia(t, CategoriaInspecao.verso, 'Verso de carta');
    });

    testWidgets('C3 mesa e feltro', (t) async {
      await abreEAnuncia(t, CategoriaInspecao.mesa, 'Mesa e feltro');
    });

    testWidgets('C4 mascote', (t) async {
      await abreEAnuncia(t, CategoriaInspecao.mascote, 'Mascote');
    });

    testWidgets('C5 emoji', (t) async {
      await abreEAnuncia(t, CategoriaInspecao.emoji, 'Emoji');
    });

    testWidgets('C6 balão', (t) async {
      await abreEAnuncia(t, CategoriaInspecao.balao, 'Balão');
    });

    testWidgets('C7 presente', (t) async {
      await abreEAnuncia(t, CategoriaInspecao.presente, 'Presente');
    });

    testWidgets('C8 efeito de entrada', (t) async {
      await abreEAnuncia(t, CategoriaInspecao.efeitoDeEntrada, 'Efeito de entrada');
    });

    test('C9 toda categoria tem rótulo, e nenhum rótulo é vazio', () {
      // O `switch` exaustivo do Dart garante que a extensão compile com todas
      // as categorias; este caso garante que nenhuma delas escapou com `''`,
      // que compilaria igual e apagaria a legenda da tela.
      for (final c in CategoriaInspecao.values) {
        expect(c.rotulo.trim(), isNotEmpty, reason: '$c ficou sem rótulo');
      }
      expect(
        CategoriaInspecao.values.map((c) => c.rotulo).toSet(),
        hasLength(CategoriaInspecao.values.length),
        reason: 'duas categorias com o mesmo rótulo são uma categoria a menos '
            'para quem lê a tela',
      );
    });
  });

  // =========================================================================
  // §2 — AS TRÊS SAÍDAS
  //
  // A OS pede toque fora, X e voltar. Nenhuma delas é a mesma coisa: o toque
  // fora depende de `barrierDismissible`, o X depende de existir um botão, e o
  // voltar depende de NINGUÉM ter interceptado a rota com um `PopScope`.
  // =========================================================================
  group('F — a inspeção fecha pelos três caminhos', () {
    Future<void> abrir(WidgetTester tester) async {
      await _emTelefone(tester);
      await tester.pumpWidget(
        _casca(
          Scaffold(
            body: Center(
              child: AlvoDeInspecao(
                item: _item(nome: 'Fênix'),
                child: const SizedBox(width: 90, height: 90),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(AlvoDeInspecao));
      await tester.pumpAndSettle();
      expect(find.byType(InspecaoAmpliada), findsOneWidget);
    }

    testWidgets('F1 toque fora fecha', (t) async {
      await abrir(t);
      // O canto superior esquerdo da tela está fora do cartão, que é
      // centralizado e tem margem de 22 pixels.
      await t.tapAt(const Offset(6, 6));
      await t.pumpAndSettle();
      expect(find.byType(InspecaoAmpliada), findsNothing);
    });

    testWidgets('F2 o X fecha', (t) async {
      await abrir(t);
      await t.tap(find.byTooltip('Fechar'));
      await t.pumpAndSettle();
      expect(find.byType(InspecaoAmpliada), findsNothing);
    });

    testWidgets('F3 o voltar do sistema fecha', (t) async {
      await abrir(t);
      // Não é `Navigator.pop` disfarçado: `handlePopRoute` entra pelo mesmo
      // canal de plataforma que o botão físico de voltar do Android, e é o
      // único jeito de flagrar um `PopScope` que tenha prendido a rota.
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      expect(find.byType(InspecaoAmpliada), findsNothing);
    });

    testWidgets('F4 fechada a inspeção, a tela de baixo volta a responder', (t) async {
      await _emTelefone(t);
      var compras = 0;
      await t.pumpWidget(
        _casca(_Bancada(item: _item(), onComprar: () => compras++)),
      );
      await t.tap(find.byType(AlvoDeInspecao));
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Fechar'));
      await t.pumpAndSettle();

      expect(compras, 0, reason: 'a ida e a volta não podem ter comprado nada');
      await t.tap(find.text('Comprar'));
      await t.pump();
      expect(
        compras,
        1,
        reason: 'a inspeção fechada deixou resíduo capturando o toque do botão',
      );
    });
  });

  // =========================================================================
  // §3 — SEGURANÇA CONTRA O TOQUE AMBÍGUO
  // =========================================================================
  group('S — ampliar não atravessa para Comprar/Equipar', () {
    testWidgets('S1 Loja: abrir e fechar não move saldo, inventário nem equipado',
        (t) async {
      await _emTelefone(t);
      final livro = _LivroDaLoja();
      await t.pumpWidget(
        _lojaCategoria(livro, itens: [
          _cosmetico(id: 'moldura_rubi', nome: 'Rubi'),
          _cosmetico(
            id: 'moldura_ametista',
            nome: 'Ametista',
            estado: ItemEstado.equipado,
          ),
        ]),
      );
      final antes = livro.fotografia;
      expect(antes, everyElement(0));

      await t.tap(find.byType(AlvoDeInspecao).first);
      await t.pumpAndSettle();
      expect(find.byType(InspecaoAmpliada), findsOneWidget);
      await t.tap(find.byTooltip('Fechar'));
      await t.pumpAndSettle();

      expect(
        livro.fotografia,
        antes,
        reason: 'a inspeção mexeu em compra, equipamento, presente ou carteira',
      );
    });

    testWidgets('S2 Loja: o botão de ação NÃO é descendente do alvo de ampliação',
        (t) async {
      await _emTelefone(t);
      final livro = _LivroDaLoja();
      await t.pumpWidget(
        _lojaCategoria(livro, itens: [_cosmetico()]),
      );

      expect(find.byType(AlvoDeInspecao), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Comprar'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AlvoDeInspecao),
          matching: find.byType(FilledButton),
        ),
        findsNothing,
        reason: 'o alvo de ampliação passou a conter o botão de compra — o '
            'toque ambíguo voltou a depender da arena de gestos',
      );
      expect(
        find.descendant(
          of: find.byType(AlvoDeInspecao),
          matching: find.byType(OutlinedButton),
        ),
        findsNothing,
        reason: 'o alvo de ampliação passou a conter o botão de presentear',
      );
    });

    testWidgets('S3 Loja: tocar Comprar continua comprando, e só isso', (t) async {
      await _emTelefone(t);
      final livro = _LivroDaLoja();
      await t.pumpWidget(
        _lojaCategoria(livro, itens: [_cosmetico()]),
      );

      // POR QUE ESTE CASO FILTRA UM ERRO, E POR QUE FILTRA SÓ ESSE.
      //
      // A folha de confirmação de compra desenha a prévia com um `Image.asset`
      // SEM `errorBuilder` — é o único ponto da Loja que não tem. E o portão do
      // `build.yml` roda as suítes ANTES do passo que declara os diretórios de
      // arte no `pubspec`, então ali o asset não está empacotado e o
      // carregamento estoura.
      //
      // Isso é um defeito de EMPACOTAMENTO, anterior a esta OS e alheio ao que
      // este caso investiga — que é se tocar Comprar ainda compra e não abre
      // ampliação. Ignorar o erro TODO esconderia uma exceção de verdade, então
      // o filtro é nominal: qualquer outra falha continua reprovando o caso.
      final erros = <FlutterErrorDetails>[];
      final anterior = FlutterError.onError;
      FlutterError.onError = erros.add;
      addTearDown(() => FlutterError.onError = anterior);

      await t.tap(find.widgetWithText(FilledButton, 'Comprar'));
      await t.pumpAndSettle();

      FlutterError.onError = anterior;
      expect(
        erros
            .map((e) => '${e.exception}')
            .where((e) => !e.contains('Unable to load asset'))
            .toList(),
        isEmpty,
        reason: 'o caminho de compra levantou um erro que não é o do asset '
            'ausente do artefato de build',
      );

      expect(livro.compras, 1);
      expect(
        find.byType(InspecaoAmpliada),
        findsNothing,
        reason: 'o caminho de compra abriu a inspeção pelo meio',
      );
      expect(find.text('Confirmar compra'), findsOneWidget);
    });

    testWidgets('S4 Loja: item equipado amplia sem desequipar', (t) async {
      await _emTelefone(t);
      final livro = _LivroDaLoja();
      await t.pumpWidget(
        _lojaCategoria(livro, itens: [
          _cosmetico(estado: ItemEstado.equipado, nome: 'Ametista'),
        ]),
      );

      await t.tap(find.byType(AlvoDeInspecao));
      await t.pumpAndSettle();

      expect(find.text('✓ Em uso'), findsOneWidget);
      expect(livro.equipar, 0, reason: 'ampliar um equipado chamou onEquipar');
      expect(livro.fotografia, everyElement(0));
    });

    testWidgets('S5 Loja: item bloqueado amplia sem disparar o aviso de bloqueio',
        (t) async {
      await _emTelefone(t);
      final livro = _LivroDaLoja();
      await t.pumpWidget(
        _lojaCategoria(livro, itens: [
          _cosmetico(estado: ItemEstado.bloqueado, nome: 'Pérola Negra'),
        ]),
      );

      await t.tap(find.byType(AlvoDeInspecao));
      await t.pumpAndSettle();

      expect(find.byType(InspecaoAmpliada), findsOneWidget);
      // Escopado ao cartão: o card da vitrine JÁ escreve "🔒 Bloqueado" no
      // próprio botão, e uma busca solta acharia os dois e passaria por acaso.
      expect(
        find.descendant(
          of: find.byType(InspecaoAmpliada),
          matching: find.text('🔒 Bloqueado'),
        ),
        findsOneWidget,
      );
      expect(
        livro.bloqueados,
        0,
        reason: 'ver um item bloqueado de perto não é tentar usá-lo',
      );
    });

    testWidgets('S6 Perfil: ampliar do baú não fecha o baú nem avisa fechamento',
        (t) async {
      await _emTelefone(t);
      final livro = _LivroDoPerfil();
      await t.pumpWidget(_perfil(livro));
      await t.pumpAndSettle();

      await t.tap(find.text('🎁 Meus Presentes'));
      await t.pumpAndSettle();
      expect(livro.abriuPresentes, 1);
      expect(find.text('Rosa'), findsOneWidget);

      await t.tap(find.byType(AlvoDeInspecao).last);
      await t.pumpAndSettle();
      expect(find.byType(InspecaoAmpliada), findsOneWidget);

      await t.tap(find.byTooltip('Fechar'));
      await t.pumpAndSettle();

      expect(
        find.text('Rosa'),
        findsWidgets,
        reason: 'fechar a inspeção derrubou o baú junto',
      );
      expect(
        livro.fechouPresentes,
        0,
        reason: 'a inspeção anunciou um fechamento de baú que não aconteceu',
      );
    });

    testWidgets('S7 Perfil: a vitrine amplia sem tocar em trocar vitrine', (t) async {
      await _emTelefone(t);
      final livro = _LivroDoPerfil();
      await t.pumpWidget(_perfil(livro));
      await t.pumpAndSettle();

      final antes = livro.fotografia;
      await t.tap(find.text('Moldura'));
      await t.pumpAndSettle();

      expect(find.byType(InspecaoAmpliada), findsOneWidget);
      await t.tap(find.byTooltip('Fechar'));
      await t.pumpAndSettle();

      expect(
        livro.fotografia,
        antes,
        reason: 'ampliar uma peça da vitrine disparou comando de perfil',
      );
    });

    testWidgets('S8 Perfil: o mascote amplia sem acionar trocar avatar', (t) async {
      await _emTelefone(t);
      final livro = _LivroDoPerfil();
      await t.pumpWidget(_perfil(livro));
      await t.pumpAndSettle();

      // O selo do mascote é o alvo cujo item se chama exatamente 'Mascote' e
      // cuja prévia é o glifo do VM — o da vitrine usa asset.
      final alvos = t.widgetList<AlvoDeInspecao>(find.byType(AlvoDeInspecao));
      final doHeroi = alvos.where((a) => a.item.previa == '🦊');
      expect(doHeroi, hasLength(1), reason: 'o selo do mascote não é ampliável');

      expect(
        find.descendant(
          of: find.byType(AlvoDeInspecao),
          matching: find.byIcon(Icons.photo_camera_rounded),
        ),
        findsNothing,
        reason: 'o botão de trocar avatar caiu dentro de um alvo de ampliação',
      );
      expect(livro.trocouAvatar, 0);
    });
  });

  // =========================================================================
  // §4 — ESTADOS E PROPORÇÃO
  // =========================================================================
  group('E — bloqueado, adquirido e equipado, e a forma preservada', () {
    Future<void> montaComEstado(WidgetTester t, EstadoInspecao estado) async {
      await _emTelefone(t);
      await t.pumpWidget(
        _casca(InspecaoAmpliada(item: _item(estado: estado))),
      );
      await t.pumpAndSettle();
    }

    testWidgets('E1 bloqueado se anuncia', (t) async {
      await montaComEstado(t, EstadoInspecao.bloqueado);
      expect(find.text('🔒 Bloqueado'), findsOneWidget);
    });

    testWidgets('E2 adquirido se anuncia', (t) async {
      await montaComEstado(t, EstadoInspecao.adquirido);
      expect(find.text('Você tem este item'), findsOneWidget);
    });

    testWidgets('E3 equipado se anuncia', (t) async {
      await montaComEstado(t, EstadoInspecao.equipado);
      expect(find.text('✓ Em uso'), findsOneWidget);
    });

    testWidgets('E4 a arte ampliada preserva a proporção', (t) async {
      await _emTelefone(t);
      await t.pumpWidget(_casca(InspecaoAmpliada(item: _item())));
      await t.pumpAndSettle();

      final imagens = t.widgetList<Image>(
        find.descendant(
          of: find.byType(InspecaoAmpliada),
          matching: find.byType(Image),
        ),
      );
      expect(imagens, isNotEmpty, reason: 'a inspeção não desenhou arte nenhuma');
      for (final img in imagens) {
        expect(
          img.fit,
          BoxFit.contain,
          reason: 'a arte ampliada foi recortada ou esticada — uma ampliação '
              'que deforma é pior do que a miniatura',
        );
      }
    });

    testWidgets('E5 a prévia por glifo também cabe sem deformar', (t) async {
      await _emTelefone(t);
      await t.pumpWidget(_casca(InspecaoAmpliada(item: _item(previa: '🦊'))));
      await t.pumpAndSettle();

      final ajustes = t.widgetList<FittedBox>(
        find.descendant(
          of: find.byType(InspecaoAmpliada),
          matching: find.byType(FittedBox),
        ),
      );
      expect(ajustes, isNotEmpty);
      expect(ajustes.every((f) => f.fit == BoxFit.contain), isTrue);
      expect(find.text('🦊'), findsOneWidget);
    });

    testWidgets('E6 a inspeção não mostra preço nem convite a agir', (t) async {
      await _emTelefone(t);
      await t.pumpWidget(
        _casca(InspecaoAmpliada(item: _item(detalhe: 'LENDÁRIO'))),
      );
      await t.pumpAndSettle();

      for (final proibido in ['Comprar', 'Equipar', 'Comprar agora', '🪙', '💎']) {
        expect(
          find.textContaining(proibido),
          findsNothing,
          reason: 'a inspeção começou a oferecer "$proibido"',
        );
      }
      expect(find.text('LENDÁRIO'), findsOneWidget);
    });
  });

  // =========================================================================
  // §5 — VAZAMENTO ENTRE ITENS
  // =========================================================================
  group('V — uma inspeção não sabe nada da anterior', () {
    testWidgets('V1 abrir A, fechar e abrir B mostra só B', (t) async {
      await _emTelefone(t);
      final livro = _LivroDaLoja();
      await t.pumpWidget(
        _lojaCategoria(livro, itens: [
          _cosmetico(id: 'a', nome: 'Rubi'),
          _cosmetico(
            id: 'b',
            nome: 'Esmeralda',
            estado: ItemEstado.equipado,
            raridade: Raridade.vip,
          ),
        ]),
      );

      await t.tap(find.byType(AlvoDeInspecao).first);
      await t.pumpAndSettle();
      // O selo de raridade também aparece no card, por baixo: o escopo é o que
      // faz este caso falar sobre a INSPEÇÃO e não sobre a vitrine.
      expect(
        find.descendant(
          of: find.byType(InspecaoAmpliada),
          matching: find.text('LENDÁRIO'),
        ),
        findsOneWidget,
      );
      expect(find.text('Ainda não é seu'), findsOneWidget);
      await t.tap(find.byTooltip('Fechar'));
      await t.pumpAndSettle();

      await t.tap(find.byType(AlvoDeInspecao).last);
      await t.pumpAndSettle();

      final cartao = find.byType(InspecaoAmpliada);
      expect(
        find.descendant(of: cartao, matching: find.text('Esmeralda')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: cartao, matching: find.text('Rubi')),
        findsNothing,
        reason: 'o item anterior sobreviveu à inspeção seguinte',
      );
      expect(
        find.descendant(of: cartao, matching: find.text('Ainda não é seu')),
        findsNothing,
        reason: 'o ESTADO do item anterior vazou para o seguinte',
      );
      expect(
        find.descendant(of: cartao, matching: find.text('✓ Em uso')),
        findsOneWidget,
      );
    });

    testWidgets('V2 duas inspeções seguidas não empilham cartões', (t) async {
      await _emTelefone(t);
      final livro = _LivroDaLoja();
      await t.pumpWidget(
        _lojaCategoria(livro, itens: [_cosmetico()]),
      );

      for (var i = 0; i < 3; i++) {
        await t.tap(find.byType(AlvoDeInspecao));
        await t.pumpAndSettle();
        expect(
          find.byType(InspecaoAmpliada),
          findsOneWidget,
          reason: 'a rodada $i empilhou uma segunda inspeção',
        );
        await t.tap(find.byTooltip('Fechar'));
        await t.pumpAndSettle();
        expect(find.byType(InspecaoAmpliada), findsNothing);
      }
      expect(livro.fotografia, everyElement(0));
    });

    testWidgets('V3 o slot desconhecido não herda rótulo do vizinho', (t) async {
      await _emTelefone(t);
      final livro = _LivroDoPerfil();
      await t.pumpWidget(_perfil(livro));
      await t.pumpAndSettle();

      await t.tap(find.text('Moldura'));
      await t.pumpAndSettle();
      expect(find.text('Moldura'), findsWidgets);
      await t.tap(find.byTooltip('Fechar'));
      await t.pumpAndSettle();

      await t.tap(find.text('Feltro'));
      await t.pumpAndSettle();
      final cartao = find.byType(InspecaoAmpliada);
      expect(
        find.descendant(of: cartao, matching: find.text('Colecionável')),
        findsOneWidget,
        reason: 'um slot que a lista não conhece recebeu rótulo chutado',
      );
    });
  });

  // =========================================================================
  // §6 — ACESSIBILIDADE
  // =========================================================================
  group('A — a inspeção se anuncia e se fecha sem enxergar', () {
    testWidgets('A1 a imagem ampliada tem nome e categoria na semântica', (t) async {
      await _emTelefone(t);
      final handle = t.ensureSemantics();
      await t.pumpWidget(
        _casca(InspecaoAmpliada(item: _item(nome: 'Pérola Negra'))),
      );
      await t.pumpAndSettle();

      expect(
        find.bySemanticsLabel('Pérola Negra, Moldura, ampliado'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('A2 o fechamento é alcançável por rótulo', (t) async {
      await _emTelefone(t);
      final handle = t.ensureSemantics();
      await t.pumpWidget(_casca(InspecaoAmpliada(item: _item())));
      await t.pumpAndSettle();

      expect(find.bySemanticsLabel('Fechar'), findsWidgets);
      handle.dispose();
    });

    testWidgets('A3 o alvo se anuncia como botão de ampliar', (t) async {
      await _emTelefone(t);
      final handle = t.ensureSemantics();
      await t.pumpWidget(
        _casca(
          Scaffold(
            body: Center(
              child: AlvoDeInspecao(
                item: _item(nome: 'Coruja Jogadora'),
                child: const SizedBox(width: 80, height: 80),
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();

      expect(find.bySemanticsLabel('Ampliar Coruja Jogadora'), findsOneWidget);
      expect(
        t.getSemantics(find.bySemanticsLabel('Ampliar Coruja Jogadora')),
        isSemantics(label: 'Ampliar Coruja Jogadora', isButton: true),
        reason: 'quem não vê a arte precisa saber que ali se aperta',
      );
      handle.dispose();
    });
  });

  // =========================================================================
  // §7 — AUDITORIA ESTRUTURAL
  //
  // Os casos acima provam o comportamento de HOJE. Estes impedem que a próxima
  // pessoa reabra o buraco sem perceber.
  // =========================================================================
  group('M — o módulo não tem por onde comprar, equipar nem chamar backend', () {
    test('M1 o módulo importa só o Material', () {
      final imports = RegExp(r'''^import\s+['"]([^'"]+)['"]''', multiLine: true)
          .allMatches(_codigo(_fonteDoModulo()))
          .map((m) => m.group(1)!)
          .toList();
      expect(
        imports,
        ['package:flutter/material.dart'],
        reason: 'um arquivo que não conhece serviço nenhum não chama backend; '
            'esta lista é a prova, e cresceu',
      );
    });

    test('M2 o módulo não declara callback externo nenhum', () {
      final codigo = _codigo(_fonteDoModulo());
      for (final tipo in ['VoidCallback', 'ValueChanged', 'ValueSetter']) {
        expect(
          codigo,
          isNot(contains(tipo)),
          reason: 'apareceu um $tipo: a inspeção ganhou uma saída, e uma saída '
              'é por onde compra e equipar entram',
        );
      }
      // `Function` como TIPO DE CAMPO, e não a palavra solta: `final void
      // Function(...) onX;`.
      expect(
        RegExp(r'\bfinal\s+[\w<>,\s?]*\bFunction\b').hasMatch(codigo),
        isFalse,
        reason: 'um campo de função é um callback com outro nome',
      );
    });

    test('M3 nada de compra, equipamento, saldo ou inventário no módulo', () {
      final codigo = _codigo(_fonteDoModulo());
      for (final termo in [
        'Comprar',
        'Equipar',
        'onComprar',
        'onEquipar',
        'preco',
        'saldo',
        'moedas',
        'gemas',
        'inventario',
        'Firebase',
        'Firestore',
        'http',
      ]) {
        expect(
          codigo,
          isNot(contains(termo)),
          reason: '"$termo" entrou no módulo da inspeção',
        );
      }
    });

    test('M4 nenhum ajuste de imagem que deforme', () {
      final codigo = _codigo(_fonteDoModulo());
      for (final deformante in [
        'BoxFit.cover',
        'BoxFit.fill',
        'BoxFit.fitWidth',
        'BoxFit.fitHeight',
      ]) {
        expect(
          codigo,
          isNot(contains(deformante)),
          reason: '$deformante recorta ou estica a arte',
        );
      }
      expect(codigo, contains('BoxFit.contain'));
    });

    test('M5 o fechamento não é interceptado', () {
      final codigo = _codigo(_fonteDoModulo());
      expect(
        codigo,
        isNot(contains('PopScope')),
        reason: 'um PopScope aqui é exatamente a mutação "impeça o fechamento"',
      );
      expect(
        codigo,
        contains('barrierDismissible: true'),
        reason: 'sem barreira dispensável não há fechamento por toque fora',
      );
    });

    test('M6 as duas telas usam o MESMO alvo, e nenhuma tem o seu próprio', () {
      // Uma segunda implementação de ampliação é uma segunda chance de o toque
      // ambíguo voltar — e ela não seria coberta por nenhum caso acima.
      final telas = {
        'lib/screens/loja_categoria_screen.dart': true,
        'lib/screens/perfil_screen.dart': true,
      };
      for (final caminho in telas.keys) {
        final f = File(caminho);
        expect(f.existsSync(), isTrue, reason: '$caminho sumiu');
        final codigo = _codigo(f);
        expect(
          codigo,
          contains('AlvoDeInspecao('),
          reason: '$caminho deixou de oferecer inspeção ampliada',
        );
        expect(
          codigo,
          contains("import '../cosmeticos/inspecao_ampliada.dart'"),
          reason: '$caminho passou a ter ampliação por conta própria',
        );
      }
    });
  });

  // =========================================================================
  // §8 — RESPONSIVIDADE
  //
  // Quatro telas × três formas de arte. O cruzamento não é zelo: a ampliação
  // falha de dois jeitos DIFERENTES, e cada um deles só aparece num canto da
  // matriz. O texto estoura na tela mais BAIXA (360x800, onde o cartão tem
  // menos altura sobrando), e a arte se deforma na tela mais LARGA (o tablet,
  // onde sobra folga e a tentação de esticar). Medir só o telefone do meio não
  // pega nem um nem outro.
  //
  // O nome e o detalhe são longos de propósito nos doze: um overflow de
  // `Column` nasce do texto que não coube, não da imagem — a imagem mora numa
  // caixa de altura fixa e nunca empurra ninguém.
  // =========================================================================
  group('R — a inspeção cabe em toda tela, com arte de qualquer forma', () {
    var n = 0;
    for (final tela in _superficies) {
      for (final forma in _formas) {
        n++;
        testWidgets('R$n ${tela.nome} · ${forma.nome}', (t) async {
          await _emTela(t, tela.tamanho);
          await t.pumpWidget(
            _bancadaDeArte(
              _item(
                nome: 'Moldura Pérola Negra Edição de Aniversário',
                detalhe: 'Lendário · recebido no torneio de aniversário',
                previa: forma.caminho,
              ),
            ),
          );
          await t.tap(find.byType(AlvoDeInspecao));
          await t.pumpAndSettle();
          await _decodifica(t);

          // 1. NADA ESTOUROU. Um `RenderFlex overflowed` é reportado na
          // pintura, e em teste vira exceção — é este expect que a pega.
          expect(
            t.takeException(),
            isNull,
            reason: 'a inspeção estourou em ${tela.nome} com ${forma.nome}',
          );

          // 2. O CARTÃO CABE NA TELA. Overflow não é o único jeito de não
          // caber: um cartão alto demais sai pela borda sem reclamar, porque o
          // Dialog o centraliza e deixa transbordar.
          final conteudo = t.getRect(
            find
                .descendant(
                  of: find.byType(InspecaoAmpliada),
                  matching: find.byType(Column),
                )
                .first,
          );
          final tamanho = _tamanhoLogico(t);
          expect(conteudo.top, greaterThanOrEqualTo(-.5),
              reason: 'o topo do cartão saiu da tela em ${tela.nome}');
          expect(conteudo.bottom, lessThanOrEqualTo(tamanho.height + .5),
              reason: 'o pé do cartão saiu da tela em ${tela.nome}');
          expect(conteudo.left, greaterThanOrEqualTo(-.5));
          expect(conteudo.right, lessThanOrEqualTo(tamanho.width + .5));

          // 3. A ARTE NÃO FOI DEFORMADA NEM CORTADA. Aqui não se olha o NOME
          // do BoxFit: pega-se o fit que o módulo realmente usou, aplica-se à
          // imagem real na caixa real, e mede-se o retângulo que sairia
          // pintado. `fill` e `fitWidth` mudam a proporção do destino; `cover`
          // faz o destino ultrapassar a caixa, que é o corte. Os dois modos de
          // falhar morrem em números, e não em vocabulário.
          final render = t.renderObject<RenderImage>(
            find.descendant(
              of: find.byType(InspecaoAmpliada),
              matching: find.byType(RawImage),
            ),
          );
          final imagem = render.image;
          expect(
            imagem,
            isNotNull,
            reason: 'a arte de ${forma.caminho} não decodificou — este caso '
                'mediria o ícone de falha, e diria que está tudo bem',
          );
          final origem =
              Size(imagem!.width.toDouble(), imagem.height.toDouble());
          expect(
            origem.width / origem.height,
            closeTo(forma.razao, .01),
            reason: '${forma.caminho} deixou de ser ${forma.nome}: este caso '
                'passou a medir outra forma e ninguém avisou',
          );

          final fit = render.fit;
          expect(fit, isNotNull, reason: 'a arte ampliada ficou sem fit');
          final destino = applyBoxFit(fit!, origem, render.size).destination;
          expect(
            destino.width / destino.height,
            closeTo(forma.razao, .01),
            reason: 'a arte saiu esticada em ${tela.nome} ($fit)',
          );
          expect(
            destino.width,
            lessThanOrEqualTo(render.size.width + .5),
            reason: 'a arte foi cortada na largura em ${tela.nome} ($fit)',
          );
          expect(
            destino.height,
            lessThanOrEqualTo(render.size.height + .5),
            reason: 'a arte foi cortada na altura em ${tela.nome} ($fit)',
          );
        });
      }
    }
  });

  // =========================================================================
  // §9 — AS ARMADILHAS RESTANTES
  //
  // Cada caso deste grupo existe porque a OS nomeia uma mutação que nenhum dos
  // grupos acima mataria.
  // =========================================================================
  group('X — arte ausente, toque dobrado, perfil alheio e o botão voltar', () {
    testWidgets('X1 arte ausente falha de forma segura, e não derruba a tela',
        (t) async {
      await _emTela(t, const Size(390, 844));
      await t.pumpWidget(
        _bancadaDeArte(
          _item(
            nome: 'Arte Que Sumiu',
            previa: 'assets/loja/molduras/inexistente.webp',
          ),
        ),
      );
      await t.tap(find.byType(AlvoDeInspecao));
      await t.pumpAndSettle();
      await _decodifica(t);

      expect(
        t.takeException(),
        isNull,
        reason: 'a arte ausente virou exceção: o errorBuilder sumiu, e a '
            'inspeção de um item sem arte passou a derrubar a tela',
      );
      expect(
        find.byIcon(Icons.auto_awesome_rounded),
        findsOneWidget,
        reason: 'sem o desenho de reserva a pessoa vê um buraco e não sabe se '
            'o app travou',
      );
      // O resto do cartão continua de pé: nome, categoria e a saída.
      expect(find.text('Arte Que Sumiu'), findsOneWidget);
      await t.tap(find.byTooltip('Fechar'));
      await t.pumpAndSettle();
      expect(find.byType(InspecaoAmpliada), findsNothing);
    });

    test('X2 nenhuma arte é buscada por URL, em nenhuma das três superfícies',
        () {
      // A OS proíbe asset externo como reserva, e a razão é dupla: uma arte
      // baixada na hora conta ao servidor que aquela pessoa abriu aquele item,
      // e some quando o servidor sai do ar. O desenho de reserva do módulo é
      // um ícone local, e é assim que tem de continuar.
      final superficies = {
        'lib/cosmeticos/inspecao_ampliada.dart': _fonteDoModulo(),
        'lib/screens/loja_categoria_screen.dart':
            File('lib/screens/loja_categoria_screen.dart'),
        'lib/screens/perfil_screen.dart':
            File('lib/screens/perfil_screen.dart'),
      };
      for (final entrada in superficies.entries) {
        expect(entrada.value.existsSync(), isTrue,
            reason: '${entrada.key} sumiu');
        final codigo = _codigo(entrada.value);
        for (final marca in [
          'Image.network',
          'NetworkImage',
          'http://',
          'https://',
        ]) {
          expect(
            codigo,
            isNot(contains(marca)),
            reason: '"$marca" entrou em ${entrada.key}: a arte passou a vir '
                'da rede',
          );
        }
      }
    });

    testWidgets('X3 dois toques seguidos não empilham dois overlays',
        (t) async {
      await _emTela(t, const Size(390, 844));
      var compras = 0;
      await t.pumpWidget(
        _casca(_Bancada(item: _item(), onComprar: () => compras++)),
      );

      await t.tap(find.byType(AlvoDeInspecao));
      // UM quadro só: a inspeção está ENTRANDO, e é exatamente aqui que um
      // segundo toque escaparia. Quem espera o pumpAndSettle mede o estado
      // calmo e nunca vê a janela.
      await t.pump();
      await t.tap(find.byType(AlvoDeInspecao), warnIfMissed: false);
      await t.pumpAndSettle();

      expect(
        find.byType(InspecaoAmpliada),
        findsOneWidget,
        reason: 'o segundo toque atravessou a barreira e abriu uma segunda '
            'inspeção: fechar uma deixaria a outra na tela',
      );
      expect(compras, 0);

      // E uma saída basta para voltar à tela: se tivessem entrado duas rotas,
      // o primeiro fechamento deixaria a de baixo aparecendo.
      await t.tap(find.byTooltip('Fechar'));
      await t.pumpAndSettle();
      expect(find.byType(InspecaoAmpliada), findsNothing);
      expect(compras, 0);
    });

    testWidgets(
        'X4 o Perfil visitado amplia o item DELE, e o zoom não publica nada a '
        'mais', (t) async {
      await _emTela(t, const Size(390, 844));
      final livro = _LivroDoPerfil();
      await t.pumpWidget(_perfil(livro, vm: _perfilVMVisitado()));
      await t.pumpAndSettle();

      // A vitrine visitada mostra as peças DA RITA. Nenhum nome do meu próprio
      // perfil pode aparecer aqui.
      expect(find.text('Coroa da Rita'), findsOneWidget);
      expect(
        find.text('Moldura'),
        findsNothing,
        reason: 'a vitrine do perfil visitado desenhou o item do visitante',
      );

      // O SEGUNDO item, e não o primeiro. Uma inspeção que sempre abrisse o
      // item de índice zero passaria despercebida no primeiro card, que é
      // justamente o que a pessoa toca primeiro quando confere à mão.
      await t.tap(find.text('Dorso da Rita'));
      await t.pumpAndSettle();

      final cartao = find.byType(InspecaoAmpliada);
      expect(cartao, findsOneWidget);
      expect(
        find.descendant(of: cartao, matching: find.text('Dorso da Rita')),
        findsOneWidget,
        reason: 'a inspeção ampliou um item que não é o que foi tocado',
      );
      expect(
        find.descendant(of: cartao, matching: find.text('Coroa da Rita')),
        findsNothing,
        reason: 'a inspeção abriu o item do vizinho na vitrine',
      );

      // O zoom não inventou publicação nova: o comando de trocar a vitrine
      // continua fora do perfil alheio, e nada foi acionado nele.
      await t.tap(find.byTooltip('Fechar'));
      await t.pumpAndSettle();
      expect(
        find.text('trocar ›'),
        findsNothing,
        reason: 'a inspeção trouxe junto um comando que o perfil visitado não '
            'tinha',
      );
      expect(livro.fotografia, everyElement(0));
    });

    testWidgets('X5 o voltar do sistema fecha a inspeção e NÃO sai da tela',
        (t) async {
      await _emTela(t, const Size(390, 844));
      var compras = 0;
      await t.pumpWidget(
        _casca(_Bancada(item: _item(), onComprar: () => compras++)),
      );
      await t.tap(find.byType(AlvoDeInspecao));
      await t.pumpAndSettle();
      expect(find.byType(InspecaoAmpliada), findsOneWidget);

      await t.binding.handlePopRoute();
      await t.pumpAndSettle();

      expect(find.byType(InspecaoAmpliada), findsNothing);
      // A diferença entre "fechou a inspeção" e "saiu da vitrine" é esta: a
      // tela de baixo continua montada e continua respondendo. Um voltar que
      // desmontasse a vitrine junto passaria no F3 e reprovaria aqui.
      expect(
        find.byType(AlvoDeInspecao),
        findsOneWidget,
        reason: 'o voltar levou a pessoa para fora da vitrine em vez de só '
            'fechar a inspeção',
      );
      await t.tap(find.text('Comprar'));
      await t.pump();
      expect(compras, 1);
    });
  });
}
