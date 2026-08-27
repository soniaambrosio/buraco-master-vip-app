// a11y_estados_terminais_test.dart — os estados terminais da casca lidos por
// quem não vê a tela.
//
// ---------------------------------------------------------------------------
// O QUE ESTÁ SENDO EXERCITADO
// ---------------------------------------------------------------------------
//
// `CascaDeProducao` de verdade, com a `SessaoDoJogador` de verdade. Falsa é só
// a ponta do mundo — a fonte de identidade —, e o fluxo de autenticação é um
// `StreamController` que NUNCA emite: é assim que o teto de espera estoura sem
// gastar oito segundos de relógio de parede.
//
// Os dois estados terminais desta casca:
//
//   _AvisoTerminal    — não há sessão montada acima. Sem ação: não se sai dele
//                       tentando de novo, porque o defeito é do build.
//   _EsperaEstourada  — a sessão não respondeu dentro do teto. Tem ação.
//
// ---------------------------------------------------------------------------
// POR QUE A ÁRVORE SEMÂNTICA, E NÃO `find.text`
// ---------------------------------------------------------------------------
//
// `find.text('⏳')` continua achando a ampulheta depois da correção: o widget
// segue lá, desenhado, e é isso mesmo que se quer — ela sai da LEITURA, não da
// tela. A única prova que distingue as duas coisas é a árvore de semântica, e é
// contra ela que este arquivo afirma.
//
// ---------------------------------------------------------------------------
// OS 20-C1 — O QUE ESTA VOLTA ACRESCENTOU, E POR QUÊ
// ---------------------------------------------------------------------------
//
// A entrega original provava COMPORTAMENTO em uma largura só. Faltavam três
// coisas, e todas as três admitiam defeito sem produzir uma linha vermelha:
//
//   §4 A MOLDURA COMO UNIDADE. Trocar `container: true` por `false`, ou tirar
//      o `Semantics` inteiro, não mudava rótulo nenhum — os três textos
//      continuavam lá, na mesma ordem, só que soltos no meio da rota. O grupo
//      `moldura semântica` afirma contra o NÓ, e não contra os rótulos.
//
//   §5 O CANCELAMENTO DO RELÓGIO. Tirar o `cancel` do `dispose` derrubava oito
//      casos por `pending timer` — um sintoma coletivo, que não nomeia a
//      causa. O grupo `relógio da espera` vigia criação e cancelamento do
//      timer pela zona, e reprova PELO NOME.
//
//   §6 A MATRIZ RESPONSIVA. A escala de texto era medida em 360 dp. Um
//      aparelho de 320 dp com o texto em 200% é a combinação em que a ação sai
//      da dobra, e ela nunca era montada aqui dentro. O grupo `matriz
//      responsiva` monta as dezoito.
//
// Os vinte e um casos originais continuam com os MESMOS nomes, palavra por
// palavra: eles são a relação nominal que `auditoria_casca_test.dart` cobra do
// lado de fora. O grupo `escala de texto` deixou de ser um laço e passou a ser
// seis casos escritos por extenso — mesmos nomes, mesmo corpo, agora legíveis
// por quem lê o arquivo em vez de executá-lo.
//
// ---------------------------------------------------------------------------
// ESTA SUÍTE NÃO SE PROTEGE SOZINHA
// ---------------------------------------------------------------------------
//
// Um contrato escrito aqui dentro morre junto com o arquivo. Quem cobra a
// existência, a contagem e os nomes desta suíte é `auditoria_casca_test.dart`,
// que roda no gate `cascaaud`. O grupo `o portão desta suíte`, no fim deste
// arquivo, fecha o outro lado do laço: ele cobra que aquele verificador
// continua existindo e continua falando desta suíte. Apagar um denuncia o
// outro.

@Timeout(Duration(minutes: 3))
library;

import 'dart:async';
import 'dart:io';
// `Tristate` é o tipo em que papel e estado passaram a ser respondidos: um
// controle sem estado de habilitação devolve `none`, e não `false`.
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:buraco_master_vip/casca/casca_de_producao.dart';
import 'package:buraco_master_vip/screens/splash_oficial_screen.dart';
import 'package:buraco_master_vip/sessao/escopo_sessao.dart';
import 'package:buraco_master_vip/sessao/fonte_identidade.dart';
import 'package:buraco_master_vip/sessao/identidade_publica_sessao.dart';
import 'package:buraco_master_vip/sessao/sessao_do_jogador.dart';

// ===========================================================================
// Bancada
// ===========================================================================

/// Nunca responde. A identidade não é o que está sob teste aqui, e uma fonte
/// que respondesse resolveria a sessão e apagaria o estado sob teste.
class _FonteMuda implements FonteDeIdentidade {
  @override
  Future<IdentidadePublica> obterMinhaIdentidade() =>
      Completer<IdentidadePublica>().future;
}

const Duration _kTeto = Duration(seconds: 8);

/// Passa do teto com folga, sem depender do valor exato.
const Duration _kAlemDoTeto = Duration(seconds: 9);

const String _kMensagemDaEspera =
    'A verificação da sua conta está demorando mais que o normal. '
    'Confira sua conexão e tente de novo.';

const String _kTituloDoAviso = 'Aplicativo mal configurado';
const String _kDetalheDoAviso = 'A sessão do jogador não foi montada na abertura.';

/// O rótulo da única ação oferecida por qualquer um dos dois estados.
const String _kAcao = 'Tentar de novo';

Widget _casca({SessaoDoJogador? sessao}) {
  final Widget app = MaterialApp(
    home: CascaDeProducao(
      aberturaTerminou: true,
      onAberturaConcluida: () {},
      somNaSplash: false,
      duracaoDaSplash: const Duration(milliseconds: 10),
      limiteDeResolucao: _kTeto,
    ),
  );
  // Sem escopo acima, a casca cai no aviso terminal — que é justamente um dos
  // dois casos sob teste.
  if (sessao == null) return app;
  return EscopoSessao(sessao: sessao, child: app);
}

/// Altura lógica da superfície, igual em toda a matriz.
///
/// A largura é a variável; a altura fica fixa para que uma diferença medida
/// entre 320 e 412 dp seja da LARGURA, e não de duas coisas mudando juntas.
const double _kAlturaDp = 780;

/// Superfície de telefone em retrato.
///
/// O padrão do `flutter_test` é 800x600 — paisagem de desktop —, e nele estas
/// telas não se parecem com o que o aparelho mostra.
///
/// `larguraDp` é o que a matriz da OS 20-C1 varia: 320 dp é o piso real de
/// aparelho pequeno em uso, 360 é o mais comum e 412 é o de tela grande. O
/// padrão continua 360 para que os vinte e um casos originais meçam
/// exatamente o que mediam antes.
void _telefone(WidgetTester t, {double escala = 1.0, double larguraDp = 360}) {
  const double dpr = 3;
  t.view.physicalSize = Size(larguraDp * dpr, _kAlturaDp * dpr);
  t.view.devicePixelRatio = dpr;
  t.platformDispatcher.textScaleFactorTestValue = escala;
  addTearDown(t.view.reset);
  addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
}

/// Roda o corpo com a árvore de semântica ligada.
///
/// O `dispose` fica no `finally`, e não em `addTearDown`, porque o
/// `flutter_test` confere se sobrou `SemanticsHandle` ANTES de rodar os
/// tearDowns — registrado lá, o descarte chega tarde e todo teste do arquivo
/// falha por vazamento, escondendo o que realmente estava sendo provado.
Future<void> _lendoATela(
  WidgetTester t,
  Future<void> Function() corpo,
) async {
  final SemanticsHandle h = t.ensureSemantics();
  try {
    await corpo();
  } finally {
    h.dispose();
  }
}

/// Uma sessão que nunca se pronuncia: o fluxo não emite e ninguém o fecha.
SessaoDoJogador _sessaoMuda() {
  final fluxo = StreamController<String?>.broadcast();
  final s = SessaoDoJogador(fonte: _FonteMuda(), uids: fluxo.stream);
  addTearDown(() {
    s.dispose();
    fluxo.close();
  });
  return s;
}

/// Monta a casca e atravessa o teto, deixando a espera estourada em pé.
Future<void> _atravessarOTeto(WidgetTester t, SessaoDoJogador s) async {
  await t.pumpWidget(_casca(sessao: s));
  await t.pump();
  await t.pump(_kAlemDoTeto);
  await t.pump();
}

// ===========================================================================
// Vigia do relógio
// ===========================================================================
//
// A `Zone` é o único ponto por onde passa TODO `Timer` criado pelo código sob
// teste — inclusive o que nasce dentro do `initState` de um widget, longe do
// alcance do teste. Interceptando `createTimer` e devolvendo um invólucro que
// registra o `cancel`, a suíte consegue afirmar a coisa exata que a OS pede:
// que o relógio da espera foi CANCELADO, e não que "nada estourou depois".
//
// Sem isto, tirar o `cancel` do `dispose` reprovaria por `pending timer` em
// oito casos que falam de outra coisa — um sintoma coletivo que não nomeia a
// causa e que some no instante em que alguém escreve `t.pump` a menos.

/// O que o relógio fez, na ordem em que fez.
class _LivroDoRelogio {
  final List<Duration> criados = <Duration>[];
  final List<Duration> cancelados = <Duration>[];
}

/// Um `Timer` que anota o próprio cancelamento antes de repassá-lo.
class _TimerVigiado implements Timer {
  _TimerVigiado(this._real, this._livro, this._duracao);

  final Timer _real;
  final _LivroDoRelogio _livro;
  final Duration _duracao;

  @override
  void cancel() {
    _livro.cancelados.add(_duracao);
    _real.cancel();
  }

  @override
  bool get isActive => _real.isActive;

  @override
  int get tick => _real.tick;
}

/// Roda o corpo numa zona que vigia os timers criados dentro dele.
///
/// A criação continua sendo do relógio de mentira do `flutter_test` — quem
/// cria é `parent.createTimer`, e o tempo continua andando por `pump`. A zona
/// só observa.
Future<void> _sobVigiaDoRelogio(
  _LivroDoRelogio livro,
  Future<void> Function() corpo,
) {
  return runZoned(
    corpo,
    zoneSpecification: ZoneSpecification(
      createTimer: (self, parent, zone, duracao, f) {
        livro.criados.add(duracao);
        return _TimerVigiado(
          parent.createTimer(zone, duracao, f),
          livro,
          duracao,
        );
      },
    ),
  );
}

// ===========================================================================
// Leitura da árvore semântica
// ===========================================================================

/// Todos os rótulos do estado, na ordem em que um leitor de tela os percorre.
///
/// É esta ordem — e não a ordem do `Column` — que responde "o título vem antes
/// da mensagem?".
///
/// A varredura começa no nó da moldura rolável, e não na raiz da árvore, para
/// que o que se afirma seja o CONTEÚDO DO ESTADO — e não o que o `MaterialApp`
/// por acaso pendura acima dele.
List<String> _rotulosEmOrdem(WidgetTester t) {
  final saida = <String>[];
  void andar(SemanticsNode n) {
    final rotulo = n.label.trim();
    if (rotulo.isNotEmpty) saida.add(rotulo);
    n.visitChildren((filho) {
      andar(filho);
      return true;
    });
  }

  andar(t.getSemantics(find.byType(SingleChildScrollView)));
  return saida;
}

/// Este nó é cabeçalho?
bool _ehCabecalho(SemanticsNode n) => n.flagsCollection.isHeader;

/// O nó que agrupa o estado inteiro.
///
/// É o `Semantics(container: true, explicitChildNodes: true)` da moldura.
/// `getSemantics` sobe do `Column` até o nó semântico mais próximo — que é
/// esse, quando ele existe.
SemanticsNode _containerDoEstado(WidgetTester t) =>
    t.getSemantics(find.byType(Column));

/// O nó semântico da MOLDURA ROLÁVEL — a janela por onde o estado é visto.
///
/// Tomado pelo recheio do `SingleChildScrollView`, que fica logo ACIMA do
/// `Semantics` da moldura. `getSemantics` sobe dali até o primeiro nó
/// semântico, e esse nó é a janela: ele existe com ou sem o container do
/// estado, e é o candidato natural a adotar os filhos quando o container some.
SemanticsNode _noDaMolduraRolavel(WidgetTester t) => t.getSemantics(
  find.ancestor(of: find.byType(Column), matching: find.byType(Padding)).first,
);

/// O nó que agrupa o estado é DO ESTADO, e não uma peça de layout no caminho.
///
/// ESTA PROVA CUSTOU DUAS TENTATIVAS, e as duas erradas ensinam o que ela tem
/// de afirmar.
///
/// PRIMEIRO ERRO — contar filhos. Tirando o `container: true` da moldura, ou o
/// `Semantics` inteiro, os três textos NÃO ficam órfãos: são adotados pelo nó
/// da moldura rolável, logo acima. Esse nó tem rótulo vazio, não é a rota e
/// passa a ter exatamente três filhos, na ordem certa. Contar filhos fica
/// verde com o `Semantics` removido.
///
/// SEGUNDO ERRO — medir. O nó do estado mede o conteúdo e o nó da janela mede a
/// área visível, o que parece distinguir os dois — até o conteúdo passar da
/// dobra. A partir daí a árvore semântica RECORTA o nó do estado pelo viewport,
/// e ele passa a medir a janela também. A régua só funcionava enquanto tudo
/// coubesse, que é justamente o caso desinteressante.
///
/// O QUE DE FATO SEPARA OS DOIS é serem DOIS. Com o container, a coluna do
/// estado e a moldura rolável caem em nós semânticos diferentes: existe um nó
/// que é só do estado, com começo e fim próprios. Sem ele, os dois pontos caem
/// no MESMO nó — e o estado deixa de ter fronteira, em qualquer tamanho de
/// tela, com ou sem rolagem.
void _containerEnvolveOEstado(WidgetTester t) {
  final SemanticsNode no = _containerDoEstado(t);
  expect(
    no.flagsCollection.scopesRoute,
    isFalse,
    reason:
        'o nó que agrupa o estado é o nó da ROTA — não há container de estado '
        'nenhum',
  );
  expect(
    no.id,
    isNot(_noDaMolduraRolavel(t).id),
    reason:
        'a coluna do estado e a moldura rolável caem no MESMO nó semântico '
        '(#${no.id}): não existe container próprio do estado. O `Semantics` da '
        'moldura foi removido, ou está com `container: false` — e o estado '
        'perdeu começo e fim.',
  );
  expect(
    no.label,
    isEmpty,
    reason:
        'o container absorveu o texto dos filhos — sem `explicitChildNodes` o '
        'estado inteiro vira um rótulo só, e o botão perde papel, estado e ação',
  );
}

/// Os filhos diretos de um nó, na ordem de leitura.
List<SemanticsNode> _filhosDiretos(SemanticsNode n) {
  final filhos = <SemanticsNode>[];
  n.visitChildren((f) {
    filhos.add(f);
    return true;
  });
  return filhos;
}

/// Captura o que a casca manda dizer em voz alta.
///
/// `SemanticsService.announce` vira uma mensagem no canal de acessibilidade da
/// plataforma; interceptá-lo é a única forma de CONTAR anúncios sem um leitor
/// de tela de verdade do outro lado — e contar é o ponto, porque o defeito que
/// se quer impedir é falar duas vezes.
List<String> _capturarAnuncios(WidgetTester t) {
  final ditos = <String>[];
  t.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<dynamic>(
    SystemChannels.accessibility,
    (dynamic mensagem) async {
      final m = mensagem as Map<dynamic, dynamic>;
      if (m['type'] == 'announce') {
        final dados = m['data'] as Map<dynamic, dynamic>;
        ditos.add(dados['message'] as String);
      }
      return null;
    },
  );
  addTearDown(
    () => t.binding.defaultBinaryMessenger
        .setMockDecodedMessageHandler<dynamic>(
          SystemChannels.accessibility,
          null,
        ),
  );
  return ditos;
}

// ===========================================================================
// Geometria
// ===========================================================================
//
// NADA AQUI MEDE GLIFO. A fonte dos testes de widget é um quadrado — cada
// caractere ocupa exatamente `fontSize` de lado —, então qualquer número
// absoluto medido nela descreve a fonte de teste, e não o aparelho. O que
// estas ferramentas medem são RELAÇÕES: um retângulo está dentro do outro, um
// vem antes do outro, dois não se cruzam. Essas relações continuam valendo com
// a fonte de verdade.

/// A superfície visível, em coordenadas lógicas.
Rect _telaVisivel(WidgetTester t) =>
    Offset.zero & t.view.physicalSize / t.view.devicePixelRatio;

/// O retângulo do widget, em coordenadas da tela.
Rect _caixa(WidgetTester t, Finder f) => t.getRect(f);

/// Nenhum dos retângulos invade o seguinte.
///
/// Numa coluna, "não sobrepor" é o fundo de um terminar antes do topo do
/// próximo. Meio pixel de folga negativa é arredondamento de layout, e não
/// texto por cima de texto.
void _semSobreposicaoVertical(WidgetTester t, List<Finder> emOrdem) {
  for (var i = 0; i + 1 < emOrdem.length; i++) {
    final acima = _caixa(t, emOrdem[i]);
    final abaixo = _caixa(t, emOrdem[i + 1]);
    expect(
      acima.bottom,
      lessThanOrEqualTo(abaixo.top + 0.5),
      reason:
          'o elemento ${i + 1} termina em ${acima.bottom} e o ${i + 2} começa '
          'em ${abaixo.top} — eles se sobrepõem',
    );
  }
}

/// O widget está de fato visível na superfície, e não só montado.
///
/// `findsOneWidget` responde "existe na árvore", que é outra pergunta: um
/// texto empurrado 400 dp abaixo da dobra existe e não está alcançável. Aqui a
/// afirmação é sobre a INTERSEÇÃO com a tela ser não vazia depois de a moldura
/// ter rolado até ele.
Future<void> _alcancavel(WidgetTester t, Finder f, {required String oQue}) async {
  await t.ensureVisible(f);
  await t.pump();
  final Rect r = _caixa(t, f);
  final Rect tela = _telaVisivel(t);
  final Rect dentro = r.intersect(tela);
  expect(
    dentro.width > 0 && dentro.height > 0,
    isTrue,
    reason: '$oQue ficou fora da tela mesmo depois de rolar: $r em $tela',
  );
}

/// A moldura rola exatamente quando precisa rolar.
///
/// Não basta "existe um `Scrollable`": o que a pessoa precisa é que, quando o
/// conteúdo não couber, exista percurso para chegar ao fim dele — e que, quando
/// couber, a tela não fique deslizando à toa.
void _rolaSePrecisa(WidgetTester t) {
  final ScrollableState s = t.state<ScrollableState>(find.byType(Scrollable));
  final double conteudo = t.getSize(find.byType(Column)).height;
  final double janela = s.position.viewportDimension;
  if (conteudo > janela + 0.5) {
    expect(
      s.position.maxScrollExtent,
      greaterThan(0),
      reason:
          'o conteúdo mede $conteudo numa janela de $janela e a moldura não '
          'oferece rolagem — o que passar da dobra fica inalcançável',
    );
  } else {
    expect(
      s.position.maxScrollExtent,
      0,
      reason: 'o conteúdo cabe na janela e mesmo assim a moldura desliza',
    );
  }
}

// ===========================================================================
// O corpo dos seis casos de escala
// ===========================================================================
//
// Estes dois métodos são o CORPO dos seis casos do grupo `escala de texto`,
// que até a OS 20-C1 nasciam de um laço `for`. Os nomes não mudaram — mudou
// que agora eles estão escritos um por um, porque é por NOME que a fonte única
// de gates cobra a existência de cada um. Um laço esconde os nomes de quem lê
// o arquivo, e a relação nominal só podia então ser conferida executando.
//
// A afirmação é a mesma de antes, palavra por palavra.

Future<void> _escalaEsperaEstourada(WidgetTester t, double escala) async {
  final String rotulo = '${(escala * 100).toInt()}%';
  await _lendoATela(t, () async {
    _telefone(t, escala: escala);
    await _atravessarOTeto(t, _sessaoMuda());

    // Um overflow de layout vira exceção do framework durante o quadro.
    expect(t.takeException(), isNull, reason: 'layout estourou em $rotulo');

    // A correção semântica não pode ter tirado nada da tela.
    expect(find.text(kTituloDaEsperaEstourada), findsOneWidget);
    expect(find.text(_kAcao), findsOneWidget);
    expect(
      _ehCabecalho(t.getSemantics(find.text(kTituloDaEsperaEstourada))),
      isTrue,
      reason: 'o cabeçalho não pode depender da escala',
    );

    // E a ação continua alcançável e apertável. Em 200% ela desce para fora
    // da dobra — o que é esperado e já era assim: a moldura ROLA. O que não
    // pode é ela ficar inalcançável, e é isso que o `ensureVisible` afirma.
    await t.ensureVisible(find.text(_kAcao));
    await t.pump();
    await t.tap(find.text(_kAcao));
    await t.pump();
    expect(find.byType(SplashOficialScreen), findsOneWidget);
  });
}

Future<void> _escalaAvisoTerminal(WidgetTester t, double escala) async {
  final String rotulo = '${(escala * 100).toInt()}%';
  await _lendoATela(t, () async {
    _telefone(t, escala: escala);
    await t.pumpWidget(_casca());
    await t.pump();

    expect(t.takeException(), isNull, reason: 'layout estourou em $rotulo');
    expect(find.text(_kTituloDoAviso), findsOneWidget);
    expect(
      _ehCabecalho(t.getSemantics(find.text(_kTituloDoAviso))),
      isTrue,
      reason: 'o cabeçalho não pode depender da escala',
    );
  });
}

void main() {
  // =========================================================================
  // 1 — espera estourada: o estado que TEM ação
  // =========================================================================
  group('espera estourada', () {
    testWidgets('o título é anunciado, e como cabeçalho', (t) async {
      await _lendoATela(t, () async {
        _telefone(t);
        await _atravessarOTeto(t, _sessaoMuda());

        final no = t.getSemantics(find.text(kTituloDaEsperaEstourada));
        expect(no.label, kTituloDaEsperaEstourada);
        // PROVA NEGATIVA: tirar `header: true` da casca derruba exatamente
        // esta linha, e nenhuma outra.
        expect(
          _ehCabecalho(no),
          isTrue,
          reason: 'o título do estado precisa ser cabeçalho',
        );
      });
    });

    testWidgets('o cabeçalho é ÚNICO — a mensagem não é cabeçalho', (t) async {
      await _lendoATela(t, () async {
        _telefone(t);
        await _atravessarOTeto(t, _sessaoMuda());

        expect(
          _ehCabecalho(t.getSemantics(find.text(_kMensagemDaEspera))),
          isFalse,
          reason: 'dois cabeçalhos no mesmo estado é o mesmo que nenhum',
        );
      });
    });

    testWidgets('a mensagem chega inteira e sem jargão', (t) async {
      await _lendoATela(t, () async {
        _telefone(t);
        await _atravessarOTeto(t, _sessaoMuda());

        expect(_rotulosEmOrdem(t), contains(_kMensagemDaEspera));
      });
    });

    testWidgets('a ampulheta NÃO entra na árvore', (t) async {
      await _lendoATela(t, () async {
        _telefone(t);
        await _atravessarOTeto(t, _sessaoMuda());

        // Ela continua desenhada — o que mudou é a leitura, não a tela.
        expect(find.text('⏳'), findsOneWidget);
        // PROVA NEGATIVA: devolver o `ExcludeSemantics` para `Text` puro põe
        // um rótulo "⏳" na árvore e derruba esta linha.
        expect(
          _rotulosEmOrdem(t).where((r) => r.contains('⏳')),
          isEmpty,
          reason: 'emoji decorativo não pode ser anunciado',
        );
      });
    });

    testWidgets('nada de gráfico sobra sem descrição', (t) async {
      await _lendoATela(t, () async {
        _telefone(t);
        await _atravessarOTeto(t, _sessaoMuda());

        // Não há ícone informativo neste estado: TODA a informação é texto. A
        // prova é que os rótulos da árvore são exatamente os três textos — nem
        // um a mais, que seria decoração falando; nem um a menos, que seria
        // informação perdida.
        expect(_rotulosEmOrdem(t), const <String>[
          kTituloDaEsperaEstourada,
          _kMensagemDaEspera,
          _kAcao,
        ]);
      });
    });

    testWidgets('a ordem de foco é título, mensagem, ação', (t) async {
      await _lendoATela(t, () async {
        _telefone(t);
        await _atravessarOTeto(t, _sessaoMuda());

        final r = _rotulosEmOrdem(t);
        expect(
          r.indexOf(kTituloDaEsperaEstourada),
          lessThan(r.indexOf(_kMensagemDaEspera)),
        );
        expect(
          r.indexOf(_kMensagemDaEspera),
          lessThan(r.indexOf(_kAcao)),
        );
      });
    });

    testWidgets('a ação tem nome, papel e estado', (t) async {
      await _lendoATela(t, () async {
        _telefone(t);
        await _atravessarOTeto(t, _sessaoMuda());

        final no = t.getSemantics(find.text(_kAcao));
        expect(no.label, _kAcao);
        expect(no.flagsCollection.isButton, isTrue, reason: 'papel');
        // Um controle SEM estado de habilitação responde `none` — e um botão
        // que não diz se está ligado não é operável por quem não o vê.
        expect(
          no.flagsCollection.isEnabled,
          Tristate.isTrue,
          reason: 'papel sem estado de habilitação não é ação',
        );
        expect(
          no.flagsCollection.isFocused,
          isNot(Tristate.none),
          reason: 'focável',
        );
        // Sem a AÇÃO, o botão é um rótulo bonito que ninguém consegue apertar
        // pelo leitor de tela.
        expect(no.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      });
    });

    testWidgets('o callback continua sendo o de antes: volta a esperar', (
      t,
    ) async {
      await _lendoATela(t, () async {
        _telefone(t);
        final s = _sessaoMuda();
        await _atravessarOTeto(t, s);
        expect(find.text(kTituloDaEsperaEstourada), findsOneWidget);

        await t.tap(find.text(_kAcao));
        await t.pump();

        // O DESTINO NÃO MUDOU: "tentar de novo" volta a esperar a sessão — não
        // navega para lugar nenhum, não inventa login e não resolve sessão.
        expect(find.byType(SplashOficialScreen), findsOneWidget);
        expect(find.text(kTituloDaEsperaEstourada), findsNothing);
        expect(s.resolvida, isFalse);
        expect(s.estado.autenticado, isFalse);

        // E o teto volta a valer: passado de novo, o estado retorna.
        await t.pump(_kAlemDoTeto);
        await t.pump();
        expect(find.text(kTituloDaEsperaEstourada), findsOneWidget);
      });
    });

    testWidgets('nada de sensível na árvore', (t) async {
      await _lendoATela(t, () async {
        _telefone(t);
        await _atravessarOTeto(t, _sessaoMuda());

        final tudo = _rotulosEmOrdem(t).join(' | ').toLowerCase();
        for (final proibido in const <String>[
          'uid',
          'token',
          'credencial',
          'publicid',
          'firebase',
          'exception',
          'stack',
          'null',
        ]) {
          expect(
            tudo.contains(proibido),
            isFalse,
            reason: 'a leitura do estado expôs "$proibido"',
          );
        }
      });
    });
  });

  // =========================================================================
  // 2 — a transição, dita uma vez só
  // =========================================================================
  group('mudança dinâmica', () {
    testWidgets('a transição é anunciada — e UMA vez', (t) async {
      await _lendoATela(t, () async {
        _telefone(t);
        final ditos = _capturarAnuncios(t);
        final s = _sessaoMuda();

        await t.pumpWidget(_casca(sessao: s));
        await t.pump();
        // Antes do teto não há o que anunciar: a abertura está fazendo o seu
        // trabalho, e dizer isso seria ruído.
        expect(ditos, isEmpty);

        await t.pump(_kAlemDoTeto);
        await t.pump();
        expect(ditos, <String>[kTituloDaEsperaEstourada]);

        // PROVA NEGATIVA DA REPETIÇÃO. Não basta bombear: `pump` sem nada a
        // mudar não reconstrói a casca, e um teste assim passa mesmo com o
        // anúncio solto no `build`. O que reconstrói de verdade é o pai
        // entregar um widget novo — que é exatamente o que a raiz de produção
        // faz a cada notificação da sessão, via `ListenableBuilder`.
        for (var i = 0; i < 3; i++) {
          await t.pumpWidget(_casca(sessao: s));
          await t.pump();
        }
        await t.pump(const Duration(seconds: 30));
        await t.pump();
        expect(
          ditos,
          <String>[kTituloDaEsperaEstourada],
          reason: 'o anúncio repetiu a cada reconstrução',
        );
      });
    });

    testWidgets('o estado de abertura da rota NÃO é anunciado por cima', (
      t,
    ) async {
      await _lendoATela(t, () async {
        _telefone(t);
        final ditos = _capturarAnuncios(t);

        // Aviso terminal: primeiro quadro da rota. O leitor de tela já anuncia
        // a rota que abre — um `announce` aqui seria a mesma coisa duas vezes.
        await t.pumpWidget(_casca());
        await t.pump();
        await t.pump(_kAlemDoTeto);
        await t.pump();

        expect(find.text(_kTituloDoAviso), findsOneWidget);
        expect(ditos, isEmpty);
      });
    });

    testWidgets('descartada antes do teto, a casca não fala depois', (t) async {
      await _lendoATela(t, () async {
        _telefone(t);
        final ditos = _capturarAnuncios(t);

        await t.pumpWidget(_casca(sessao: _sessaoMuda()));
        await t.pump();

        // Sai da árvore ANTES de o teto estourar.
        await t.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
        await t.pump();

        // O relógio segue correndo no mundo, mas não há mais tela a descrever.
        await t.pump(_kAlemDoTeto);
        await t.pump();
        await t.pump(const Duration(seconds: 30));

        expect(
          ditos,
          isEmpty,
          reason: 'anúncio atrasado descreve uma tela que foi embora',
        );
      });
    });

    testWidgets('descartada depois de falar, não repete', (t) async {
      await _lendoATela(t, () async {
        _telefone(t);
        final ditos = _capturarAnuncios(t);

        await _atravessarOTeto(t, _sessaoMuda());
        expect(ditos, hasLength(1));

        await t.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
        await t.pump(const Duration(seconds: 30));

        expect(ditos, hasLength(1));
      });
    });
  });

  // =========================================================================
  // 3 — aviso terminal: o estado que NÃO tem ação
  // =========================================================================
  group('aviso terminal', () {
    testWidgets('título é cabeçalho, detalhe não, e nenhuma ação é oferecida', (
      t,
    ) async {
      await _lendoATela(t, () async {
        _telefone(t);
        await t.pumpWidget(_casca());
        await t.pump();

        expect(
          _ehCabecalho(t.getSemantics(find.text(_kTituloDoAviso))),
          isTrue,
        );
        expect(
          _ehCabecalho(t.getSemantics(find.text(_kDetalheDoAviso))),
          isFalse,
        );

        // NÃO SE INVENTA SAÍDA: deste estado não se sai tentando de novo, e a
        // leitura não pode sugerir que se sai.
        expect(_rotulosEmOrdem(t), const <String>[
          _kTituloDoAviso,
          _kDetalheDoAviso,
        ]);
        expect(find.byType(FilledButton), findsNothing);
      });
    });

    testWidgets('o triângulo NÃO entra na árvore', (t) async {
      await _lendoATela(t, () async {
        _telefone(t);
        await t.pumpWidget(_casca());
        await t.pump();

        expect(find.text('⚠️'), findsOneWidget);
        expect(_rotulosEmOrdem(t).where((r) => r.contains('⚠')), isEmpty);
      });
    });
  });

  // =========================================================================
  // 4 — escala de texto: o PASS que já existia continua valendo
  // =========================================================================
  //
  // Seis casos, escritos um a um. Os nomes são os mesmos que o laço produzia:
  // é por eles que `auditoria_casca_test.dart` cobra a relação nominal.
  group('escala de texto', () {
    testWidgets('espera estourada em 100%: sem estouro, e operável', (t) async {
      await _escalaEsperaEstourada(t, 1.0);
    });

    testWidgets('aviso terminal em 100%: sem estouro', (t) async {
      await _escalaAvisoTerminal(t, 1.0);
    });

    testWidgets('espera estourada em 150%: sem estouro, e operável', (t) async {
      await _escalaEsperaEstourada(t, 1.5);
    });

    testWidgets('aviso terminal em 150%: sem estouro', (t) async {
      await _escalaAvisoTerminal(t, 1.5);
    });

    testWidgets('espera estourada em 200%: sem estouro, e operável', (t) async {
      await _escalaEsperaEstourada(t, 2.0);
    });

    testWidgets('aviso terminal em 200%: sem estouro', (t) async {
      await _escalaAvisoTerminal(t, 2.0);
    });
  });

  // =========================================================================
  // 5 — OS 20-C1 §4: a moldura é UMA unidade, e os filhos são explícitos
  // =========================================================================
  //
  // O que estes casos perseguem não deixa rastro em rótulo nenhum. Com
  // `container: false`, ou sem o `Semantics` da moldura, os três textos
  // continuam lá, na mesma ordem, com os mesmos flags — e todo o grupo 1
  // continua verde. O que muda é que eles deixam de ter começo e fim: viram
  // três coisas soltas no meio da rota, e quem lê a tela perde a noção de onde
  // o estado começou.
  //
  // Por isso a afirmação é contra o NÓ que agrupa, e não contra o que ele diz.
  group('moldura semântica', () {
    testWidgets('espera estourada: a moldura é um container semântico PRÓPRIO', (
      t,
    ) async {
      await _lendoATela(t, () async {
        _telefone(t);
        await _atravessarOTeto(t, _sessaoMuda());

        _containerEnvolveOEstado(t);
      });
    });

    testWidgets('espera estourada: TRÊS filhos explícitos, na ordem de leitura', (
      t,
    ) async {
      await _lendoATela(t, () async {
        _telefone(t);
        await _atravessarOTeto(t, _sessaoMuda());

        _containerEnvolveOEstado(t);
        final List<SemanticsNode> filhos =
            _filhosDiretos(_containerDoEstado(t));
        expect(
          filhos.map((f) => f.label).toList(),
          const <String>[kTituloDaEsperaEstourada, _kMensagemDaEspera, _kAcao],
          reason: 'os três filhos do estado, na ordem, e sem nada entre eles',
        );
        // Cada papel no seu filho, e em nenhum outro.
        expect(_ehCabecalho(filhos[0]), isTrue, reason: 'o título é cabeçalho');
        expect(
          _ehCabecalho(filhos[1]),
          isFalse,
          reason: 'a mensagem não é cabeçalho',
        );
        expect(
          filhos[2].flagsCollection.isButton,
          isTrue,
          reason: 'a ação é a única com papel de botão',
        );
        expect(filhos[0].flagsCollection.isButton, isFalse);
        expect(filhos[1].flagsCollection.isButton, isFalse);
      });
    });

    testWidgets('aviso terminal: a moldura é um container semântico PRÓPRIO', (
      t,
    ) async {
      await _lendoATela(t, () async {
        _telefone(t);
        await t.pumpWidget(_casca());
        await t.pump();

        _containerEnvolveOEstado(t);
      });
    });

    testWidgets('aviso terminal: DOIS filhos explícitos, e nenhuma ação', (
      t,
    ) async {
      await _lendoATela(t, () async {
        _telefone(t);
        await t.pumpWidget(_casca());
        await t.pump();

        _containerEnvolveOEstado(t);
        final List<SemanticsNode> filhos =
            _filhosDiretos(_containerDoEstado(t));
        expect(
          filhos.map((f) => f.label).toList(),
          const <String>[_kTituloDoAviso, _kDetalheDoAviso],
          reason: 'o aviso terminal tem título e detalhe — e mais nada',
        );
        expect(_ehCabecalho(filhos[0]), isTrue);
        expect(_ehCabecalho(filhos[1]), isFalse);
        // AÇÃO INDEVIDA: deste estado não se sai tentando de novo. Um filho
        // com papel de botão aqui é uma saída que não existe.
        for (final f in filhos) {
          expect(
            f.flagsCollection.isButton,
            isFalse,
            reason: 'o aviso terminal ganhou uma ação que não leva a lugar '
                'nenhum: "${f.label}"',
          );
          expect(
            f.getSemanticsData().hasAction(SemanticsAction.tap),
            isFalse,
            reason: 'nada aqui é apertável',
          );
        }
      });
    });

    testWidgets('os filhos não são fundidos: cada texto é um nó', (t) async {
      await _lendoATela(t, () async {
        _telefone(t);
        await _atravessarOTeto(t, _sessaoMuda());

        final List<SemanticsNode> filhos =
            _filhosDiretos(_containerDoEstado(t));
        // Fundir título e mensagem produz UM nó cujo rótulo contém os dois. A
        // contagem sozinha já denunciaria, mas a prova diz por que importa:
        // fundidos, o cabeçalho passa a carregar a mensagem inteira, e o salto
        // entre cabeçalhos deixa de ser um salto.
        expect(filhos, hasLength(3));
        expect(filhos.map((f) => f.id).toSet(), hasLength(3));
        expect(
          filhos[0].label.contains(_kMensagemDaEspera),
          isFalse,
          reason: 'o título absorveu a mensagem',
        );
        expect(
          filhos[1].label.contains(kTituloDaEsperaEstourada),
          isFalse,
          reason: 'a mensagem absorveu o título',
        );
        expect(
          filhos[2].label,
          _kAcao,
          reason: 'a ação carrega o próprio rótulo, e só ele',
        );
      });
    });

    testWidgets('o emoji não é filho do container em nenhum dos dois estados', (
      t,
    ) async {
      await _lendoATela(t, () async {
        _telefone(t);
        await _atravessarOTeto(t, _sessaoMuda());
        for (final f in _filhosDiretos(_containerDoEstado(t))) {
          expect(f.label.contains('⏳'), isFalse);
        }
        // O `ExcludeSemantics` tira o nó, e não o desenho: a ampulheta segue
        // na tela. Um filho a mais no container é o emoji tendo voltado.
        expect(find.text('⏳'), findsOneWidget);
        expect(_filhosDiretos(_containerDoEstado(t)), hasLength(3));

        await t.pumpWidget(_casca());
        await t.pump();
        for (final f in _filhosDiretos(_containerDoEstado(t))) {
          expect(f.label.contains('⚠'), isFalse);
        }
        expect(find.text('⚠️'), findsOneWidget);
        expect(_filhosDiretos(_containerDoEstado(t)), hasLength(2));
      });
    });
  });

  // =========================================================================
  // 6 — OS 20-C1 §5: o relógio da espera é cancelado, e isso tem nome
  // =========================================================================
  group('relógio da espera', () {
    testWidgets('o relógio nasce armado com o teto configurado', (t) async {
      final livro = _LivroDoRelogio();
      await _sobVigiaDoRelogio(livro, () async {
        await _lendoATela(t, () async {
          _telefone(t);
          await t.pumpWidget(_casca(sessao: _sessaoMuda()));
          await t.pump();

          expect(
            livro.criados,
            contains(_kTeto),
            reason:
                'a casca não armou relógio nenhum — sem teto, uma sessão que '
                'não responde deixa a abertura eterna',
          );
          expect(livro.cancelados, isEmpty, reason: 'ninguém cancelou ainda');

          // Some da árvore antes do teto para não deixar relógio correndo
          // atrás de uma tela que não existe mais.
          await t.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
          await t.pump();
        });
      });
    });

    testWidgets('descartada a casca, o relógio da espera é CANCELADO', (
      t,
    ) async {
      final livro = _LivroDoRelogio();
      final ditos = _capturarAnuncios(t);
      var abriuDeNovo = 0;

      await _sobVigiaDoRelogio(livro, () async {
        await _lendoATela(t, () async {
          _telefone(t);
          final s = _sessaoMuda();
          await t.pumpWidget(
            EscopoSessao(
              sessao: s,
              child: MaterialApp(
                home: CascaDeProducao(
                  aberturaTerminou: true,
                  onAberturaConcluida: () => abriuDeNovo++,
                  somNaSplash: false,
                  duracaoDaSplash: const Duration(milliseconds: 10),
                  limiteDeResolucao: _kTeto,
                ),
              ),
            ),
          );
          await t.pump();
          expect(livro.criados, contains(_kTeto));

          // O descarte acontece ANTES do teto: é a janela em que o relógio
          // ainda tem para onde acordar.
          await t.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
          await t.pump();

          // ESTA É A AFIRMAÇÃO QUE DÁ NOME AO CASO. Tirar o
          // `_relogioDaEspera?.cancel()` do `dispose` deixa esta lista vazia,
          // e é aqui que a remoção passa a ter endereço. Sem esta linha, a
          // mesma remoção só apareceria como `pending timer` em oito casos
          // que falam de outro assunto.
          expect(
            livro.cancelados,
            contains(_kTeto),
            reason:
                'o relógio da espera não foi cancelado no descarte — ele '
                'segue correndo atrás de uma casca que saiu da árvore',
          );

          // E o cancelamento vale: passado o teto, nada acontece.
          await t.pump(_kAlemDoTeto);
          await t.pump();
          await t.pump(const Duration(seconds: 30));

          expect(ditos, isEmpty, reason: 'falou depois de descartada');
          expect(abriuDeNovo, 0, reason: 'chamou de volta depois de descartada');
          expect(
            find.text(kTituloDaEsperaEstourada),
            findsNothing,
            reason: 'desenhou depois de descartada',
          );
        });
      });
    });
  });

  // =========================================================================
  // 7 — OS 20-C1 §6: a matriz responsiva, medida AQUI DENTRO
  // =========================================================================
  //
  // Três larguras por três escalas por dois estados. A largura entrou porque
  // 360 dp esconde o caso interessante: é em 320 dp com o texto em 200% que a
  // ação sai da dobra, e é aí que "existe na árvore" para de significar
  // "alcançável".
  //
  // O que se mede são RELAÇÕES — dentro, antes, não cruza —, nunca a largura
  // absoluta de um glifo: a fonte dos testes é um quadrado, e números tirados
  // dela descrevem a bancada, não o aparelho.
  group('matriz responsiva', () {
    for (final double larguraDp in const <double>[320, 360, 412]) {
      for (final double escala in const <double>[1.0, 1.5, 2.0]) {
        final String onde =
            '${larguraDp.toInt()} dp × ${(escala * 100).toInt()}%';

        testWidgets('espera estourada em $onde: geometria, alcance e ordem', (
          t,
        ) async {
          await _lendoATela(t, () async {
            _telefone(t, escala: escala, larguraDp: larguraDp);
            final ditos = _capturarAnuncios(t);
            await _atravessarOTeto(t, _sessaoMuda());

            // 1. Zero overflow: um estouro de layout vira exceção no quadro.
            expect(
              t.takeException(),
              isNull,
              reason: 'o layout estourou em $onde',
            );

            // 2. Nada de essencial se perdeu.
            final Finder titulo = find.text(kTituloDaEsperaEstourada);
            final Finder mensagem = find.text(_kMensagemDaEspera);
            final Finder acao = find.text(_kAcao);
            expect(titulo, findsOneWidget);
            expect(mensagem, findsOneWidget);
            expect(acao, findsOneWidget);
            // O emoji continua DESENHADO em toda a matriz.
            expect(find.text('⏳'), findsOneWidget);

            // 3. Zero sobreposição: na coluna, um termina antes do próximo
            //    começar.
            _semSobreposicaoVertical(t, <Finder>[titulo, mensagem, acao]);

            // 4. A moldura rola exatamente quando o conteúdo não cabe — e o
            //    estado continua sendo UMA unidade, e não o buraco por onde
            //    ele é visto. Com rolagem os dois deixam de ter o mesmo
            //    tamanho, e é aqui que a diferença fica gritante.
            _rolaSePrecisa(t);
            _containerEnvolveOEstado(t);

            // 5. Os três são alcançáveis — rolando, se for o caso.
            await _alcancavel(t, titulo, oQue: 'o título em $onde');
            await _alcancavel(t, mensagem, oQue: 'a mensagem em $onde');
            await _alcancavel(t, acao, oQue: 'a ação em $onde');

            // 6. A ordem semântica não depende do tamanho da tela.
            expect(_rotulosEmOrdem(t), const <String>[
              kTituloDaEsperaEstourada,
              _kMensagemDaEspera,
              _kAcao,
            ]);
            // 7. E o emoji continua FORA da árvore em toda a matriz.
            expect(
              _rotulosEmOrdem(t).where((r) => r.contains('⏳')),
              isEmpty,
              reason: 'o emoji decorativo entrou na leitura em $onde',
            );

            // 8. A ação está habilitada e é tocável de verdade.
            final SemanticsNode no = t.getSemantics(acao);
            expect(no.flagsCollection.isButton, isTrue);
            expect(no.flagsCollection.isEnabled, Tristate.isTrue);
            expect(no.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
            await t.tap(acao);
            await t.pump();
            expect(
              find.byType(SplashOficialScreen),
              findsOneWidget,
              reason: 'apertar a ação em $onde não voltou a esperar',
            );

            // 9. O anúncio da transição continua único em toda a matriz.
            expect(ditos, <String>[kTituloDaEsperaEstourada]);
          });
        });

        testWidgets('aviso terminal em $onde: geometria, alcance e ordem', (
          t,
        ) async {
          await _lendoATela(t, () async {
            _telefone(t, escala: escala, larguraDp: larguraDp);
            final ditos = _capturarAnuncios(t);
            await t.pumpWidget(_casca());
            await t.pump();

            expect(
              t.takeException(),
              isNull,
              reason: 'o layout estourou em $onde',
            );

            final Finder titulo = find.text(_kTituloDoAviso);
            final Finder detalhe = find.text(_kDetalheDoAviso);
            expect(titulo, findsOneWidget);
            expect(detalhe, findsOneWidget);
            expect(find.text('⚠️'), findsOneWidget);

            _semSobreposicaoVertical(t, <Finder>[titulo, detalhe]);
            _rolaSePrecisa(t);
            _containerEnvolveOEstado(t);
            await _alcancavel(t, titulo, oQue: 'o título em $onde');
            await _alcancavel(t, detalhe, oQue: 'o detalhe em $onde');

            expect(_rotulosEmOrdem(t), const <String>[
              _kTituloDoAviso,
              _kDetalheDoAviso,
            ]);
            expect(
              _rotulosEmOrdem(t).where((r) => r.contains('⚠')),
              isEmpty,
              reason: 'o emoji decorativo entrou na leitura em $onde',
            );

            // Deste estado não se sai: nenhuma ação, em nenhum tamanho.
            expect(find.byType(FilledButton), findsNothing);
            // E ele é o primeiro quadro da rota: quem anuncia é o leitor de
            // tela, não a casca.
            expect(
              ditos,
              isEmpty,
              reason: 'o aviso terminal anunciou a própria entrada em $onde',
            );
          });
        });
      }
    }
  });

  // =========================================================================
  // 8 — o outro lado do laço: esta suíte é cobrada de fora
  // =========================================================================
  //
  // `auditoria_casca_test.dart` cobra a existência, a contagem e os nomes
  // desta suíte. Estes dois casos cobram o contrário: que aquele verificador
  // continua lá e continua falando DESTA suíte.
  //
  // Sozinho, cada um dos dois arquivos é removível em silêncio. Um cobrando o
  // outro, remover qualquer um deixa o que sobrou vermelho — e remover os dois
  // esbarra no `-f` do `build.yml` e no `roda_obrigatorio` do
  // `ci-os-integracao.yml`, que são duas autoridades a mais, em outro
  // repositório de decisão.
  group('o portão desta suíte', () {
    // Rodando de `app/` — ou de `app_build/`, no CI —, o verificador é irmão
    // deste arquivo.
    final File verificador = File('test/casca/auditoria_casca_test.dart');

    testWidgets('o verificador externo existe', (t) async {
      expect(
        verificador.existsSync(),
        isTrue,
        reason:
            'auditoria_casca_test.dart sumiu — é ele que impede esta suíte de '
            'ser apagada em silêncio',
      );
    });

    testWidgets('o verificador externo cobra ESTA suíte pelo nome', (t) async {
      if (!verificador.existsSync()) return;
      final String texto = verificador.readAsStringSync();
      expect(
        texto,
        contains('a11y_estados_terminais_test.dart'),
        reason: 'o verificador parou de falar do caminho desta suíte',
      );
      expect(
        texto,
        contains('a11yterm'),
        reason: 'o verificador parou de falar do gate desta suíte',
      );
      // A relação nominal vive lá, e não aqui: uma lista guardada dentro do
      // que ela guarda some junto com ele.
      expect(
        texto,
        contains('kCasosOriginaisA11yTerm'),
        reason:
            'a relação nominal dos casos saiu do verificador — sem ela, um '
            'arquivo com o mesmo caminho e outro conteúdo passa',
      );
      // E ela é a lista de verdade, não um nome de variável vazio: um dos
      // vinte e um casos, escrito por extenso, tem de estar lá.
      expect(
        texto,
        contains('espera estourada a ação tem nome, papel e estado'),
        reason: 'a relação nominal do verificador foi esvaziada',
      );
      // E O CONTRATO É EXECUTADO, e não só declarado.
      //
      // Esta linha nasceu de um escape: apagar o GRUPO de casos do verificador
      // deixa as constantes todas de pé — caminho, relação nominal, piso — e
      // nenhuma delas é lida por ninguém. O arquivo continua parecendo um
      // contrato, e não cobra mais nada. Declaração sem execução é decoração.
      expect(
        texto,
        contains("group('o portão dos estados terminais semânticos'"),
        reason:
            'o verificador ainda declara o contrato, mas não o executa mais: o '
            'grupo de casos que lê estas constantes foi removido',
      );
    });
  });
}
