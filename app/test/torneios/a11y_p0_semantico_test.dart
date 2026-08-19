// a11y_p0_semantico_test.dart — o portão da OS 12.1 "Torneios — correção do P0
// semântico V1".
//
// ---------------------------------------------------------------------------
// O QUE ESTE ARQUIVO PROVA, E POR QUE MEDINDO A ÁRVORE
// ---------------------------------------------------------------------------
//
// A auditoria de acessibilidade da OS 12, sobre esta mesma folha em `c65a61b7`,
// registrou TRÊS achados P0. Dois são semânticos e são o escopo desta OS; o
// terceiro é de layout e pertence à OS 12.2, que continua bloqueada:
//
//   P0-1  Dois controles só-ícone SEM NOME ALGUM — nem `label`, nem `tooltip`.
//         "Ver classificação", na Sala de espera (torneios_screens.dart:1383),
//         e "Compartilhar conquista", no Resultado (:1709). Apareciam na árvore
//         como nós de 48x48 dp com `isButton` e ação de toque, e rótulo vazio:
//         o leitor de tela anunciava "botão" e nada mais. Na Sala de espera,
//         aquele botão é a ÚNICA saída para a classificação.
//
//   P0-2  Um `Switch` cru no cabeçalho do formulário de modelo
//         (torneio_modelo_screen.dart:307). O texto "Modelo recorrente" era nó
//         IRMÃO na árvore — mesma profundidade, sem associação —, então o
//         controle que liga e desliga o modelo inteiro chegava como
//         `"" {hasToggledState, isToggled}` em 60x48 dp.
//
//   P0-3  Estouro de `RenderFlex` na escala de fábrica. NÃO É DESTA OS. Ver a
//         §5 deste arquivo: os estouros continuam lá, medidos e nomeados, e
//         este portão FALHA se eles mudarem — para os DOIS lados, inclusive se
//         alguém "aproveitar a viagem" e corrigir layout aqui.
//
// A prova é COMPORTAMENTAL e lida da árvore semântica real, colhida do
// `SemanticsOwner` com a view em 360x800 dp e escala de fábrica. Não há aqui
// nenhuma busca textual pelo reparo: um `grep` por `semanticLabel` continuaria
// verde se alguém escrevesse o rótulo no widget errado, e continuaria verde se
// o rótulo existisse mas o nó fosse duplicado — que é o defeito vizinho.
//
// NOTA DE MEDIÇÃO, herdada da OS 12. `setSurfaceSize` mais um `MediaQuery`
// injetado NÃO se propagam para rotas de overlay, e produzem falso positivo de
// "controle fora da tela". Tudo aqui usa `view.physicalSize` +
// `view.devicePixelRatio`, que valem para a árvore inteira.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:buraco_master_vip/screens/torneio_modelo_screen.dart';
import 'package:buraco_master_vip/screens/torneios_models.dart';
import 'package:buraco_master_vip/screens/torneios_screens.dart';

// ===========================================================================
// Bancada
// ===========================================================================

/// Um nó da árvore semântica, achatado para poder ser afirmado de uma vez.
class No {
  final int id;
  final int profundidade;
  final String rotulo;
  final String valor;
  final String dica;
  final Set<SemanticsFlag> bandeiras;
  final Set<SemanticsAction> acoes;
  final Size tamanho;
  final No? pai;

  No({
    required this.id,
    required this.profundidade,
    required this.rotulo,
    required this.valor,
    required this.dica,
    required this.bandeiras,
    required this.acoes,
    required this.tamanho,
    required this.pai,
  });

  bool get tocavel => acoes.contains(SemanticsAction.tap);

  /// "Tem nome" no sentido em que a auditoria da OS 12 usou o termo: o nome
  /// pode estar no rótulo, que é o campo primário, ou na dica — `tooltip` cai
  /// em `tooltipText`, e o TalkBack o lê quando não há descrição de conteúdo.
  /// Os seis controles nomeados SÓ por `tooltip` são achado P2 da OS 12, e P2
  /// está fora do escopo desta OS: por isso a régua global aceita a dica, e a
  /// §1 e a §2 — que são o P0 — exigem o rótulo.
  bool get temNome => rotulo.isNotEmpty || dica.isNotEmpty;

  /// Um controle aninhado dentro de um nó já nomeado: o caso do `Switch`
  /// interno de um `SwitchListTile`. A auditoria registrou que esses não
  /// constituem alvo próprio — herdam nome e ação do tile que os contém.
  bool get herdaNomeDeAncestral {
    for (var p = pai; p != null; p = p.pai) {
      if (p.rotulo.isNotEmpty) return true;
    }
    return false;
  }

  @override
  String toString() =>
      'd=$profundidade "$rotulo"'
      '${valor.isEmpty ? '' : ' [val=$valor]'}'
      '${dica.isEmpty ? '' : ' [tip=$dica]'}'
      ' {${bandeiras.map((f) => f.name).join(',')}}'
      ' <${acoes.map((a) => a.name).join(',')}>'
      ' ${tamanho.width.toStringAsFixed(1)}x${tamanho.height.toStringAsFixed(1)}';
}

/// O dono da árvore semântica.
///
/// `pipelineOwner` está marcado como obsoleto, mas o substituto sugerido não
/// expõe a ÁRVORE — dá o nó de um `Finder`, e é a árvore inteira que este
/// arquivo precisa medir. O acesso fica aqui, num lugar só, para que a dívida
/// de depreciação seja uma linha e não cinco.
SemanticsOwner _dono(WidgetTester tester) =>
    tester.binding.pipelineOwner.semanticsOwner!;

/// Dispara o toque pelo caminho da tecnologia assistiva.
///
/// Não é hit-test de pixel: é a ação semântica, que é o caminho que estava
/// fechado enquanto o nó não tinha nome.
void toque(WidgetTester tester, No no) =>
    _dono(tester).performAction(no.id, SemanticsAction.tap);

/// Achata a árvore inteira, em ordem de percurso.
List<No> arvore(WidgetTester tester) {
  final raiz = _dono(tester).rootSemanticsNode!;
  final saida = <No>[];
  void andar(SemanticsNode n, int profundidade, No? pai) {
    final dados = n.getSemanticsData();
    final no = No(
      id: n.id,
      profundidade: profundidade,
      rotulo: dados.label,
      valor: dados.value,
      dica: dados.tooltip,
      bandeiras: {
        for (final f in SemanticsFlag.values)
          if (dados.hasFlag(f)) f,
      },
      acoes: {
        for (final a in SemanticsAction.values)
          if ((dados.actions & a.index) != 0) a,
      },
      tamanho: n.rect.size,
      pai: pai,
    );
    saida.add(no);
    n.visitChildren((filho) {
      andar(filho, profundidade + 1, no);
      return true;
    });
  }

  andar(raiz, 0, null);
  return saida;
}

/// Exige que exista UM, e só um, nó com este rótulo.
No unico(List<No> nos, String rotulo) {
  final achados = nos.where((n) => n.rotulo == rotulo).toList();
  expect(
    achados,
    hasLength(1),
    reason:
        'esperava EXATAMENTE um nó rotulado "$rotulo"; dois nós para a mesma '
        'ação é o defeito vizinho ao que se corrige aqui. '
        'Achados: ${achados.join(' | ')}',
  );
  return achados.single;
}

TorneiosCallbacks callbacks({
  void Function(String)? verClassificacao,
  void Function(String)? compartilhar,
  void Function(String)? entrarNaMesa,
  void Function(String)? resgatar,
}) => TorneiosCallbacks(
  onAbrirDetalhes: (_) {},
  onInscrever: (_) {},
  onConfirmarInscricao: (_, {parceiroId, required regrasLidas}) {},
  onConvidarParceiro: (_, _) {},
  onAceitarConvite: (_) {},
  onCancelarConvite: (_) {},
  onCancelarInscricao: (_) {},
  onFazerCheckin: (_) {},
  onEntrarSalaEspera: (_) {},
  onEntrarNaMesa: (id, _) => (entrarNaMesa ?? (_) {})(id),
  onVerClassificacao: verClassificacao ?? (_) {},
  onVerResultado: (_) {},
  onResgatarPremio: resgatar ?? (_) {},
  onCompartilharConquista: compartilhar ?? (_) {},
  onFiltrarCentral: (_) {},
  onCriarModelo: () {},
  onEditarModelo: (_) {},
  onSalvarModelo: (_) {},
  onAcaoAdmin: (_, _) {},
);

/// Estouros de layout colhidos durante a montagem da tela.
///
/// A Sala de espera ESTOURA — é o P0-3 da OS 12, que pertence à OS 12.2. Se
/// esta bancada não os interceptasse, todo teste que monta a Sala reprovaria
/// por um defeito que esta OS está PROIBIDA de corrigir. Interceptar não é
/// esconder: a §5 afirma exatamente quais estouros existem e quanto medem, e
/// reprova se a lista mudar.
List<String> estouros = <String>[];

Future<void> montar(WidgetTester tester, Widget tela) async {
  tester.view.physicalSize = const Size(1080, 2400); // 360x800 dp @ dpr 3
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  estouros = <String>[];
  final anterior = FlutterError.onError;
  FlutterError.onError = (detalhes) {
    final texto = detalhes.exceptionAsString();
    if (texto.contains('overflowed by')) {
      final primeira = texto.split('\n').first.trim();
      if (!estouros.contains(primeira)) estouros.add(primeira);
      return;
    }
    anterior?.call(detalhes);
  };
  addTearDown(() => FlutterError.onError = anterior);

  // Rede de segurança, e ela é o que separa um portão de um travamento.
  //
  // A Sala de espera mantém um `Timer.periodic` de um segundo, cancelado só
  // no `dispose`. Quando uma prova REPROVA, o `expect` interrompe o corpo do
  // teste e a desmontagem explícita lá embaixo nunca chega a rodar: o timer
  // fica vivo e a suíte PENDURA no teste seguinte, em vez de dar vermelho.
  // Um portão que trava ao reprovar não informa nada — e foi exatamente assim
  // que este arquivo se comportou na primeira mutação de layout injetada
  // contra ele, antes desta linha existir.
  //
  // O `addTearDown` desmonta em qualquer saída, e roda antes dos demais
  // porque é atendido na ordem inversa do registro.
  addTearDown(() async => tester.pumpWidget(const SizedBox()));

  await tester.pumpWidget(MaterialApp(home: tela));
  await tester.pump();
}

/// Desmonta a tela no meio de um teste que monta mais de uma superfície.
///
/// A saída normal já está coberta pela rede de segurança de [montar]; esta
/// função existe para o caso em que a desmontagem precisa acontecer ANTES do
/// fim do teste — trocar de tela sem levar junto o cronômetro da anterior.
/// `pumpAndSettle` não serve para nada disso: o `Timer.periodic` da Sala de
/// espera nunca deixa a árvore assentar.
Future<void> desmontar(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
}

// --- varredura estrutural, para a §6 ---------------------------------------

String _barras(String caminho) => caminho.replaceAll(r'\', '/');

/// O arquivo SEM comentários, respeitando aspas para que uma `//` dentro de
/// string literal não seja confundida com início de comentário.
///
/// A técnica é a mesma de `saneamento_mock_admin_test.dart` e de
/// `casca/auditoria_casca_test.dart`, e pelo mesmo motivo: o código de produção
/// EXPLICA em prosa o que foi removido, e uma varredura ingênua acusaria a
/// explicação como violação. Pior: o jeito de "consertar" seria apagar a
/// documentação que registra a decisão.
String _codigo(File f) {
  final fonte = f.readAsStringSync();
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

String _resolver(String deQuem, String importado) {
  if (importado.startsWith('package:buraco_master_vip/')) {
    return 'lib/${importado.substring('package:buraco_master_vip/'.length)}';
  }
  final base = _barras(deQuem).split('/')..removeLast();
  for (final parte in importado.split('/')) {
    if (parte == '.' || parte.isEmpty) continue;
    if (parte == '..') {
      if (base.isNotEmpty) base.removeLast();
      continue;
    }
    base.add(parte);
  }
  return base.join('/');
}

final RegExp _import = RegExp(r'''import\s+['"]([^'"]+)['"]''');

/// O fecho transitivo dos imports a partir de `lib/main.dart`.
Set<String> _alcancaveisDaRaiz() {
  final vistos = <String>{};
  final fila = <String>['lib/main.dart'];
  while (fila.isNotEmpty) {
    final atual = fila.removeLast();
    if (!vistos.add(atual)) continue;
    final f = File(atual);
    if (!f.existsSync()) continue;
    for (final m in _import.allMatches(_codigo(f))) {
      final alvo = m.group(1)!;
      if (alvo.startsWith('dart:')) continue;
      if (alvo.startsWith('package:') &&
          !alvo.startsWith('package:buraco_master_vip/')) {
        continue;
      }
      fila.add(_resolver(atual, alvo));
    }
  }
  return vistos;
}

List<File> _fontesDoCliente() =>
    Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

// ===========================================================================

void main() {
  // =========================================================================
  // §1 — P0-1 (a): a saída da Sala de espera para a classificação
  //
  // ANTES (OS 12, árvore medida em 360x800 dp @100%):
  //   d=4 "" {isButton,hasEnabledState,isEnabled,isFocusable} <tap,focus> 48x48
  //   — sem rótulo, sem tooltip. E este botão é a ÚNICA saída da Sala de
  //   espera para a classificação: quem usa leitor de tela ficava sem ela.
  // =========================================================================
  group('P0-1 (a) · Sala de espera · "Ver classificação"', () {
    testWidgets('tem nome, papel, estado e ação — e num nó só', (tester) async {
      await montar(
        tester,
        SalaEsperaTorneioScreen(
          vm: TorneiosMockData.sala('t1'),
          callbacks: callbacks(),
          onVoltar: () {},
          onVerClassificacao: () {},
        ),
      );

      final nos = arvore(tester);
      final botao = unico(nos, 'Ver classificação');

      // NOME — e o nome diz a AÇÃO, não o desenho do ícone. "leaderboard" seria
      // o nome do ícone; "Ver classificação" é o que o toque faz.
      expect(botao.rotulo, 'Ver classificação');

      // PAPEL
      expect(botao.bandeiras, contains(SemanticsFlag.isButton));

      // ESTADO — declarado e habilitado. Um botão com ação e sem estado deixa o
      // leitor de tela sem como dizer que ele está disponível.
      expect(botao.bandeiras, contains(SemanticsFlag.hasEnabledState));
      expect(botao.bandeiras, contains(SemanticsFlag.isEnabled));

      // AÇÃO ÚNICA — um só nó, com toque, e sem filho que repita a ação.
      expect(botao.acoes, contains(SemanticsAction.tap));
      expect(
        nos.where((n) => n.pai == botao),
        isEmpty,
        reason: 'o botão não pode ter filho semântico repetindo a ação',
      );

      // FOCO
      expect(botao.bandeiras, contains(SemanticsFlag.isFocusable));

      // GEOMETRIA INTACTA — o reparo é semântico. 48x48 é exatamente o que a
      // OS 12 mediu ANTES da correção.
      expect(botao.tamanho, const Size(48, 48));

      await desmontar(tester);
    });

    testWidgets('o toque pela árvore de acessibilidade chama o callback', (
      tester,
    ) async {
      // O toque é disparado pelo `SemanticsOwner`, não por hit-test de pixel.
      // É o caminho que a tecnologia assistiva usa de verdade — e é o caminho
      // que estava fechado quando o nó não tinha nome.
      var chamadas = 0;
      await montar(
        tester,
        SalaEsperaTorneioScreen(
          vm: TorneiosMockData.sala('t1'),
          callbacks: callbacks(),
          onVoltar: () {},
          onVerClassificacao: () => chamadas++,
        ),
      );

      final botao = unico(arvore(tester), 'Ver classificação');
      toque(tester, botao);
      await tester.pump();

      expect(chamadas, 1, reason: 'uma ação, uma chamada — nem zero, nem duas');

      await desmontar(tester);
    });

    testWidgets('a ordem de foco segue a ordem visual da barra', (tester) async {
      await montar(
        tester,
        SalaEsperaTorneioScreen(
          vm: TorneiosMockData.sala('t1'),
          callbacks: callbacks(),
          onVoltar: () {},
          onVerClassificacao: () {},
        ),
      );

      final nos = arvore(tester);
      final ordem = nos.indexOf(unico(nos, 'Ver classificação'));
      final voltar = nos.indexWhere((n) => n.dica == 'Voltar');
      final titulo = nos.indexWhere((n) => n.rotulo == 'Sala de espera');

      expect(voltar, greaterThanOrEqualTo(0));
      // Voltar → título → subtítulo → ação da direita: a leitura visual.
      expect(voltar, lessThan(titulo));
      expect(titulo, lessThan(ordem));

      await desmontar(tester);
    });
  });

  // =========================================================================
  // §2 — P0-1 (b): a partilha da conquista, no Resultado
  //
  // ANTES: mesmo quadro do §1 — 48x48 dp, `isButton`, toque, rótulo vazio.
  // =========================================================================
  group('P0-1 (b) · Resultado · "Compartilhar conquista"', () {
    testWidgets('tem nome, papel, estado e ação — e num nó só', (tester) async {
      await montar(
        tester,
        ResultadoTorneioScreen(
          vm: TorneiosMockData.resultado('t1'),
          callbacks: callbacks(),
          onVoltar: () {},
        ),
      );

      final nos = arvore(tester);
      final botao = unico(nos, 'Compartilhar conquista');

      expect(botao.rotulo, 'Compartilhar conquista');
      expect(botao.bandeiras, contains(SemanticsFlag.isButton));
      expect(botao.bandeiras, contains(SemanticsFlag.hasEnabledState));
      expect(botao.bandeiras, contains(SemanticsFlag.isEnabled));
      expect(botao.acoes, contains(SemanticsAction.tap));
      expect(botao.bandeiras, contains(SemanticsFlag.isFocusable));
      expect(nos.where((n) => n.pai == botao), isEmpty);
      expect(botao.tamanho, const Size(48, 48));
    });

    testWidgets('o toque chama onCompartilharConquista com o torneio certo', (
      tester,
    ) async {
      final recebidos = <String>[];
      await montar(
        tester,
        ResultadoTorneioScreen(
          vm: TorneiosMockData.resultado('t1'),
          callbacks: callbacks(compartilhar: recebidos.add),
          onVoltar: () {},
        ),
      );

      final botao = unico(arvore(tester), 'Compartilhar conquista');
      toque(tester, botao);
      await tester.pump();

      // O identificador importa: um reparo que trocasse o callback por outro
      // deixaria o nome certo e a ação errada.
      expect(recebidos, ['t1']);
    });
  });

  // =========================================================================
  // §3 — P0-2: o interruptor do modelo de torneio
  //
  // ANTES (OS 12), três nós IRMÃOS na mesma profundidade d=6:
  //   d=6 "Modelo recorrente"                                     192x40
  //   d=6 "Todas as decisões finais serão validadas pelo Claude."  192x60
  //   d=6 ""  {hasToggledState,isToggled} <tap,focus>               60x48
  // O controle que liga e desliga o modelo inteiro chegava sem nome.
  // =========================================================================
  group('P0-2 · Formulário de modelo · o interruptor "Modelo recorrente"', () {
    Widget formulario() => ModeloTorneioScreen(
      initial: TorneiosMockData.modelo(),
      onVoltar: () {},
      onSalvar: (_) {},
    );

    No interruptor(List<No> nos) {
      final achados = nos
          .where((n) => n.rotulo.startsWith('Modelo recorrente'))
          .toList();
      expect(
        achados,
        hasLength(1),
        reason:
            'o rótulo e o controle têm de ser UM nó; achados: '
            '${achados.join(' | ')}',
      );
      return achados.single;
    }

    testWidgets('tem nome, papel de interruptor, estado e ação num nó só', (
      tester,
    ) async {
      await montar(tester, formulario());
      final nos = arvore(tester);
      final controle = interruptor(nos);

      // NOME — o rótulo e a explicação passaram a viajar COM o controle.
      expect(controle.rotulo, startsWith('Modelo recorrente'));
      expect(
        controle.rotulo,
        contains('Todas as decisões finais serão validadas pelo Claude.'),
      );

      // PAPEL — interruptor, e não botão. O papel errado faria o leitor de tela
      // prometer "ativar" onde o gesto na verdade alterna.
      expect(controle.bandeiras, contains(SemanticsFlag.hasToggledState));
      expect(controle.bandeiras, isNot(contains(SemanticsFlag.isButton)));

      // ESTADO — ligado, habilitado, e o estado é o mesmo que a UI já usa.
      expect(controle.bandeiras, contains(SemanticsFlag.isToggled));
      expect(controle.bandeiras, contains(SemanticsFlag.hasEnabledState));
      expect(controle.bandeiras, contains(SemanticsFlag.isEnabled));

      // AÇÃO e FOCO
      expect(controle.acoes, contains(SemanticsAction.tap));
      expect(controle.bandeiras, contains(SemanticsFlag.isFocusable));
    });

    testWidgets('o rótulo não sobrou como nó solto ao lado do controle', (
      tester,
    ) async {
      await montar(tester, formulario());
      final nos = arvore(tester);

      // Este é o teste que reprova a "correção" preguiçosa: dar nome ao
      // interruptor e DEIXAR o texto como nó irmão faria o leitor anunciar a
      // mesma informação duas vezes.
      expect(
        nos.where((n) => n.rotulo == 'Modelo recorrente'),
        isEmpty,
        reason: 'o texto do rótulo não pode existir como nó separado',
      );
      expect(
        nos.where(
          (n) =>
              n.rotulo == 'Todas as decisões finais serão validadas pelo Claude.',
        ),
        isEmpty,
        reason: 'a explicação também foi absorvida pelo nó do controle',
      );

      // E não sobrou nenhum nó anônimo com estado de alternância soltos ao lado.
      final controle = interruptor(nos);
      final irmaosAnonimos = nos.where(
        (n) =>
            n.pai == controle.pai &&
            n.rotulo.isEmpty &&
            n.bandeiras.contains(SemanticsFlag.hasToggledState),
      );
      expect(irmaosAnonimos, isEmpty);
    });

    testWidgets('o toque alterna o estado, e o estado anunciado acompanha', (
      tester,
    ) async {
      await montar(tester, formulario());

      var controle = interruptor(arvore(tester));
      expect(controle.bandeiras, contains(SemanticsFlag.isToggled));

      toque(tester, controle);
      await tester.pump();

      controle = interruptor(arvore(tester));
      expect(
        controle.bandeiras,
        isNot(contains(SemanticsFlag.isToggled)),
        reason: 'a semântica tem de consumir o MESMO estado que a UI usa',
      );

      toque(tester, controle);
      await tester.pump();

      controle = interruptor(arvore(tester));
      expect(controle.bandeiras, contains(SemanticsFlag.isToggled));
    });

    testWidgets('nenhum dos treze interruptores da folha chega sem nome', (
      tester,
    ) async {
      // O `Switch` cru era um caso isolado entre treze; esta afirmação impede
      // que o próximo controle nasça com o mesmo defeito.
      await montar(tester, formulario());
      final nos = arvore(tester);
      final alternaveis = nos
          .where((n) => n.bandeiras.contains(SemanticsFlag.hasToggledState))
          .toList();

      expect(
        alternaveis.length,
        greaterThanOrEqualTo(13),
        reason: 'a varredura precisa ter o que ler',
      );
      final mudos = alternaveis
          .where((n) => n.rotulo.isEmpty && !n.herdaNomeDeAncestral)
          .toList();
      expect(mudos, isEmpty, reason: 'interruptores sem nome: ${mudos.join(' | ')}');
    });
  });

  // =========================================================================
  // §4 — as provas GLOBAIS, sobre as superfícies tocadas por esta OS
  // =========================================================================
  group('provas globais de nome, papel e ação', () {
    Future<List<No>> superficie(WidgetTester tester, Widget tela) async {
      await montar(tester, tela);
      return arvore(tester);
    }

    testWidgets('nenhum nó tocável relevante fica sem nome', (tester) async {
      final telas = <String, Widget>{
        'Sala de espera': SalaEsperaTorneioScreen(
          vm: TorneiosMockData.sala('t1'),
          callbacks: callbacks(),
          onVoltar: () {},
          onVerClassificacao: () {},
        ),
        'Resultado': ResultadoTorneioScreen(
          vm: TorneiosMockData.resultado('t1'),
          callbacks: callbacks(),
          onVoltar: () {},
        ),
        'Formulário de modelo': ModeloTorneioScreen(
          initial: TorneiosMockData.modelo(),
          onVoltar: () {},
          onSalvar: (_) {},
        ),
      };

      final mudos = <String>[];
      for (final entrada in telas.entries) {
        final nos = await superficie(tester, entrada.value);
        for (final n in nos) {
          if (!n.tocavel) continue;
          if (n.temNome) continue;
          // Controle aninhado dentro de um nó já nomeado não é alvo próprio:
          // herda nome e ação de quem o contém (o caso do `Switch` interno do
          // `SwitchListTile`).
          if (n.herdaNomeDeAncestral) continue;
          mudos.add('${entrada.key}: $n');
        }
        await desmontar(tester);
      }

      expect(
        mudos,
        isEmpty,
        reason: 'nó com ação de toque e sem nome:\n${mudos.join('\n')}',
      );
    });

    testWidgets('nenhuma ação crítica existe apenas visualmente', (
      tester,
    ) async {
      // Um nó com papel de botão e SEM ação de toque é um controle que a
      // tecnologia assistiva vê e não consegue acionar.
      final nos = await superficie(
        tester,
        ResultadoTorneioScreen(
          vm: TorneiosMockData.resultado('t1'),
          callbacks: callbacks(),
          onVoltar: () {},
        ),
      );
      final inertes = nos
          .where(
            (n) =>
                n.bandeiras.contains(SemanticsFlag.isButton) &&
                !n.acoes.contains(SemanticsAction.tap),
          )
          .toList();
      expect(inertes, isEmpty, reason: 'botões sem ação: ${inertes.join(' | ')}');
    });

    testWidgets('os dois reparos do P0-1 não trocaram de papel', (tester) async {
      // Papel incorreto é achado próprio: um interruptor anunciado como botão,
      // ou um botão anunciado como interruptor, mente sobre o gesto.
      final sala = await superficie(
        tester,
        SalaEsperaTorneioScreen(
          vm: TorneiosMockData.sala('t1'),
          callbacks: callbacks(),
          onVoltar: () {},
          onVerClassificacao: () {},
        ),
      );
      final verClassificacao = unico(sala, 'Ver classificação');
      expect(
        verClassificacao.bandeiras,
        isNot(contains(SemanticsFlag.hasToggledState)),
      );
      await desmontar(tester);

      final resultado = await superficie(
        tester,
        ResultadoTorneioScreen(
          vm: TorneiosMockData.resultado('t1'),
          callbacks: callbacks(),
          onVoltar: () {},
        ),
      );
      expect(
        unico(resultado, 'Compartilhar conquista').bandeiras,
        isNot(contains(SemanticsFlag.hasToggledState)),
      );
    });
  });

  // =========================================================================
  // §5 — a fronteira com a OS 12.2: o layout NÃO foi tocado
  // =========================================================================
  group('o P0-3 de layout continua onde a OS 12 o mediu', () {
    testWidgets('a Sala de espera estoura exatamente os mesmos dois flexes', (
      tester,
    ) async {
      // Esta OS está proibida de corrigir layout. A afirmação vale para os DOIS
      // lados: se alguém corrigir um estouro por aqui, o portão fica vermelho e
      // a correção volta para a OS 12.2, onde ela é medida junto com as nove
      // superfícies em três escalas.
      await montar(
        tester,
        SalaEsperaTorneioScreen(
          vm: TorneiosMockData.sala('t1'),
          callbacks: callbacks(),
          onVoltar: () {},
          onVerClassificacao: () {},
        ),
      );

      expect(
        estouros.length,
        2,
        reason: 'estouros colhidos:\n${estouros.join('\n')}',
      );
      expect(
        estouros.any((e) => e.contains('overflowed by 102 pixels')),
        isTrue,
        reason: '_ConfrontoCard (torneios_screens.dart:1647) — P0-3, OS 12.2',
      );
      expect(
        estouros.any((e) => e.contains('overflowed by 177 pixels')),
        isTrue,
        reason: 'FaixaTorneioMesa (torneios_screens.dart:1522) — P0-3, OS 12.2',
      );

      await desmontar(tester);
    });

    testWidgets('o Resultado e o formulário seguem sem estouro em 360 dp', (
      tester,
    ) async {
      await montar(
        tester,
        ResultadoTorneioScreen(
          vm: TorneiosMockData.resultado('t1'),
          callbacks: callbacks(),
          onVoltar: () {},
        ),
      );
      expect(estouros, isEmpty);

      await montar(
        tester,
        ModeloTorneioScreen(
          initial: TorneiosMockData.modelo(),
          onVoltar: () {},
          onSalvar: (_) {},
        ),
      );
      expect(
        estouros,
        isEmpty,
        reason:
            'o `MergeSemantics` do §3 não é widget de layout — se aparecer '
            'estouro aqui, alguém trocou o desenho junto com a semântica',
      );
    });
  });

  // =========================================================================
  // §6 — o que esta OS NÃO podia fazer, e não fez
  // =========================================================================
  group('nada de mock, admin ou rota produtiva entrou junto', () {
    test('a varredura tem o que ler', () {
      expect(_fontesDoCliente().length, greaterThan(20));
      expect(_alcancaveisDaRaiz(), contains('lib/main.dart'));
      expect(_alcancaveisDaRaiz().length, greaterThan(5));
    });

    test('nenhum arquivo do cliente fala em seletor de cenários mock', () {
      const proibidos = [
        'onAbrirCenariosMock',
        'CenariosMock',
        'Cenários mock',
        'Cenários de validação visual',
      ];
      final infratores = <String>[];
      for (final f in _fontesDoCliente()) {
        final conteudo = _codigo(f);
        for (final termo in proibidos) {
          if (conteudo.contains(termo)) {
            infratores.add('${_barras(f.path)}: $termo');
          }
        }
      }
      expect(infratores, isEmpty);
    });

    test('`mostrarAdmin` continua sem existir como parâmetro', () {
      final infratores = <String>[];
      for (final f in _fontesDoCliente()) {
        if (_codigo(f).contains('mostrarAdmin')) {
          infratores.add(_barras(f.path));
        }
      }
      expect(infratores, isEmpty);
    });

    test('nenhuma rota produtiva para Torneios foi acrescentada', () {
      // A OS 12 mediu 51 arquivos no fecho de `lib/main.dart`, e NENHUM de
      // Torneios. Corrigir acessibilidade não é ligar a folha à Casca: se um
      // arquivo de torneio aparecer aqui, alguém antecipou uma decisão de
      // produto por dentro de uma OS de reparo semântico.
      final alcancaveis = _alcancaveisDaRaiz();
      final torneiosNoFecho = alcancaveis
          .where((c) => _barras(c).toLowerCase().contains('torneio'))
          .toList();
      expect(
        torneiosNoFecho,
        isEmpty,
        reason:
            'Torneios entrou no fecho de main(): ${torneiosNoFecho.join(', ')}',
      );
    });

    test('a preview page continua sem nenhum importador', () {
      // A única raiz que constrói a folha é a bancada de prévias. Se ela
      // ganhar um importador, a folha virou rota.
      final importadores = <String>[];
      for (final f in _fontesDoCliente()) {
        if (_barras(f.path).endsWith('lib/pages/torneios_preview_page.dart')) {
          continue;
        }
        if (_codigo(f).contains('torneios_preview_page.dart')) {
          importadores.add(_barras(f.path));
        }
      }
      expect(importadores, isEmpty);
    });
  });
}
