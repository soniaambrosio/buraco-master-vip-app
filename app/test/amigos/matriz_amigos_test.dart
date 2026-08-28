// matriz_amigos_test.dart — as provas que a COMPOSIÇÃO de Amigos trouxe, e que
// a suíte de alvos não podia absorver sem deixar de ser o que o contrato
// externo descreve.
//
// ---------------------------------------------------------------------------
// POR QUE UM ARQUIVO NOVO
// ---------------------------------------------------------------------------
//
// `a11y_alvos_amigos_test.dart` é a suíte congelada: 75 identidades, nomes,
// ordem e corpos travados por `test/contrato_alvos_amigos.txt`. Acrescentar
// casos lá seria mexer no que a autoridade externa existe para não deixar mexer
// — e a diferença entre "a suíte cresceu" e "a suíte foi trocada" deixaria de
// ser visível. As provas novas são ADITIVAS, num gate próprio (`matrizamigos`),
// registrado na mesma fonte canônica.
//
// ---------------------------------------------------------------------------
// O QUE ESTE ARQUIVO JULGA
// ---------------------------------------------------------------------------
//
// 1. A MATRIZ. Os quatro controles que a composição trouxe — `Usar um código`,
//    `Copiar`, `Aparecer offline` e `Chamar pra jogar` — em 320, 360 e 412
//    pontos de largura, a 100%, 150% e 200% de escala de texto. Nove pontos.
//
//    A medida é feita em SUPERFÍCIE ALTA e o alcance em ALTURA REAL, e são duas
//    perguntas diferentes. Num telefone de 640 o nó semântico é RECORTADO pelo
//    viewport, e um controle perfeitamente correto que esteja abaixo da dobra
//    mediria 9 pontos de altura — falso positivo garantido. Então: geometria e
//    semântica na superfície alta, onde tudo existe inteiro; e rolagem e toque
//    na altura real, onde a pergunta é "dá para chegar nele e acionar?".
//
// 2. A ABA INICIAL. A composição trocou a entrada de `Amigos` para `Online`, e
//    isso não pode ser uma expectativa trocada num teste: as duas listas são
//    exercidas, cada uma com consulta própria e nome próprio.
//
// 3. A REMOÇÃO. `Remover` saiu da lista e passou a ser oferecido pelo Perfil,
//    onde quem declara as ações é o servidor. Sem a prova ponta a ponta, isso
//    seria o desaparecimento silencioso de uma capacidade.
//
// 4. O INVENTÁRIO POR CENA, exato e ordenado — o que existe e em que ordem o
//    leitor de tela encontra.
//
// 5. OS RESIDUAIS HERDADOS, declarados nominalmente. Eles não foram corrigidos
//    por esta OS; ficam escritos para que ninguém os conte como corrigidos e
//    para que piorar seja vermelho.
//
// 6. A TERCEIRA PERNA da instrumentação. O passo 0 do workflow guarda a guarda
//    Dart, e a guarda Dart guarda o passo 0; derrubar os dois juntos deixaria o
//    portão sem ninguém. Este gate é o terceiro apoio, e ele mora aqui porque
//    tem de morar fora dos dois que ele observa.
@Timeout(Duration(minutes: 10))
library;

import 'dart:async';
import 'dart:io';
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:buraco_master_vip/amigos/escopo_social.dart';
import 'package:buraco_master_vip/amigos/estado_social.dart';
import 'package:buraco_master_vip/amigos/leitor_social.dart';
import 'package:buraco_master_vip/casca/amigos_de_producao.dart';
import 'package:buraco_master_vip/casca/lobby_online.dart';
import 'package:buraco_master_vip/pages/perfil_page.dart';
import 'package:buraco_master_vip/sessao/escopo_sessao.dart';
import 'package:buraco_master_vip/sessao/fonte_identidade.dart';
import 'package:buraco_master_vip/sessao/identidade_publica_sessao.dart';
import 'package:buraco_master_vip/sessao/sessao_do_jogador.dart';

import 'bancada_social.dart';

// ===========================================================================
// A régua
// ===========================================================================

/// Os quatro controles que a composição trouxe, e que esta matriz cobre.
const _controlesNovos = <String>[
  'Usar um código',
  'Copiar',
  'Aparecer offline',
  'Chamar pra jogar',
];

const _larguras = <double>[320, 360, 412];
const _escalas = <double>[1.0, 1.5, 2.0];

/// A altura de um telefone de verdade, para as provas de alcance.
const _alturaReal = 640.0;

/// A altura da superfície de MEDIDA — alta o bastante para nada ser recortado.
const _alturaDeMedida = 2000.0;

/// O piso de toque. Escrito aqui, e conferido contra o contrato externo em
/// `test/contrato_alvos_amigos.txt` pelo gate `suitesobrig`.
const double _piso = 48.0;

class _Alvo {
  _Alvo({
    required this.nome,
    required this.area,
    required this.ehBotao,
    required this.ehCampo,
    required this.habilitado,
    required this.selecionado,
    required this.aciona,
  });

  final String nome;
  final Rect area;
  final bool ehBotao;
  final bool ehCampo;
  final Tristate habilitado;
  final Tristate selecionado;
  final bool aciona;

  @override
  String toString() =>
      '"$nome" ${area.width.toStringAsFixed(1)}x'
      '${area.height.toStringAsFixed(1)} @${area.left.toStringAsFixed(1)},'
      '${area.top.toStringAsFixed(1)} botao=$ehBotao toque=$aciona';
}

List<_Alvo> _nos(WidgetTester tester) {
  final dpr = tester.view.devicePixelRatio;
  var raiz = tester.getSemantics(find.byType(MaterialApp));
  while (raiz.parent != null) {
    raiz = raiz.parent!;
  }
  final saida = <_Alvo>[];
  void anda(SemanticsNode no, Matrix4 acumulado) {
    final m = acumulado.clone();
    if (no.transform != null) m.multiply(no.transform!);
    final fisico = MatrixUtils.transformRect(m, no.rect);
    final d = no.getSemanticsData();
    final rotulo = d.label.trim();
    saida.add(
      _Alvo(
        nome: rotulo.isNotEmpty ? rotulo : d.tooltip.trim(),
        area: Rect.fromLTWH(
          fisico.left / dpr,
          fisico.top / dpr,
          fisico.width / dpr,
          fisico.height / dpr,
        ),
        ehBotao: d.flagsCollection.isButton,
        ehCampo: d.flagsCollection.isTextField,
        habilitado: d.flagsCollection.isEnabled,
        selecionado: d.flagsCollection.isSelected,
        aciona: d.hasAction(SemanticsAction.tap),
      ),
    );
    no.visitChildren((filho) {
      anda(filho, m);
      return true;
    });
  }

  anda(raiz, Matrix4.identity());
  return saida;
}

List<_Alvo> _alvos(WidgetTester tester) =>
    _nos(tester).where((a) => a.aciona).toList();

_Alvo _porNome(List<_Alvo> alvos, String nome) => alvos.firstWhere(
  (a) => a.nome == nome,
  orElse: () => throw StateError(
    'nenhum alvo chamado "$nome"; havia ${alvos.map((a) => a.nome).toList()}',
  ),
);

bool _contem(Rect a, Rect b) =>
    b.left >= a.left - 0.01 &&
    b.top >= a.top - 0.01 &&
    b.right <= a.right + 0.01 &&
    b.bottom <= a.bottom + 0.01;

/// Liga a árvore de acessibilidade e a desliga DENTRO do corpo do caso.
///
/// `addTearDown(handle.dispose)` não serve: o `flutter_test` confere se sobrou
/// `SemanticsHandle` ANTES de rodar os tear-downs, e todo caso reprova por
/// arnês, com uma mensagem que fala de `expect()` e não diz isso.
Future<void> _comSemantica(
  WidgetTester tester,
  Future<void> Function() corpo,
) async {
  final handle = tester.ensureSemantics();
  try {
    await corpo();
  } finally {
    handle.dispose();
  }
}

class _FonteFalsa implements FonteDeIdentidade {
  @override
  Future<IdentidadePublica> obterMinhaIdentidade() async => IdentidadePublica(
    publicId: 'P0EUMESMO0001',
    apelido: 'Ana',
    avatarRef: null,
    criada: false,
    estado: EstadoPerfil.ativo,
    limites: LimitesSociais.desconhecidos,
    edicao: const MetadadosDeEdicao(
      apelidoMinimo: 3,
      apelidoMaximo: 24,
      catalogoDeAvatarDisponivel: false,
    ),
  );
}

void main() {
  late TransporteSocialFalso t;
  late LeitorSocial social;
  late SessaoDoJogador sessao;
  late StreamController<String?> uids;

  /// Os erros de LAYOUT que a montagem produziu.
  ///
  /// `takeException` não serve aqui: ele devolve o primeiro e embrulha o resto
  /// numa mensagem de "múltiplas exceções", e o que interessa é a lista inteira,
  /// cada uma com o seu tamanho e a sua linha.
  late List<String> estouros;

  setUp(() {
    t = TransporteSocialFalso();
    social = LeitorSocial(transporte: t);
    uids = StreamController<String?>.broadcast();
    sessao = SessaoDoJogador(
      fonte: _FonteFalsa(),
      uids: uids.stream,
      uidInicial: 'uid-A',
    );
    t.respostaOnline = paginaFalsa([jogadorFalso('P1', apelido: 'Bia')]);
    t.respostaAmigos = paginaFalsa([
      jogadorFalso('P1', apelido: 'Bia'),
      jogadorFalso('P2', apelido: 'Caio'),
    ], proximoCursor: 'c1');
    t.respostaRecebidas = paginaFalsa([jogadorFalso('P3', apelido: 'Duda')]);
    t.respostaEnviadas = paginaFalsa([jogadorFalso('P4', apelido: 'Elis')]);
    estouros = <String>[];
  });

  tearDown(() {
    social.dispose();
    sessao.dispose();
    uids.close();
  });

  Future<void> montar(
    WidgetTester tester, {
    double largura = 360,
    double altura = _alturaDeMedida,
    double escala = 1.0,
  }) async {
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = Size(largura * 3, altura * 3);
    addTearDown(tester.view.reset);

    estouros = <String>[];
    final anterior = FlutterError.onError;
    FlutterError.onError = (detalhe) =>
        estouros.add(detalhe.exceptionAsString().split('\n').first);

    await tester.pumpWidget(
      EscopoSessao(
        sessao: sessao,
        child: EscopoSocial(
          social: social,
          child: MaterialApp(
            home: const AmigosDeProducao(),
            builder: (context, filho) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(escala)),
              child: filho!,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    // AQUI, e não num `addTearDown`. O `flutter_test` confere, ANTES de rodar
    // os tear-downs, se alguém deixou `FlutterError.onError` trocado — e
    // reprova o caso com uma mensagem sobre `expect()` que não diz isso. Quem
    // desvia o canal de erro devolve o canal antes da primeira afirmação.
    //
    // O efeito colateral é bom: o desvio cobre a MONTAGEM, que é quando o
    // layout acontece, e os toques que vêm depois erram pelo caminho normal —
    // uma exceção num toque não vira uma linha silenciosa numa lista.
    FlutterError.onError = anterior;
  }

  Future<void> trocarPara(WidgetTester tester, String aba) async {
    await tester.tap(find.text(aba));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
  }

  Future<void> buscar(WidgetTester tester, String termo) async {
    t.respostaDaBusca = ResultadosDeBusca(
      termo: termo,
      itens: [
        resultadoFalso(
          'P9',
          apelido: 'Bia',
          acoes: const [AcaoSocial.adicionarAmigo],
        ),
      ],
      truncado: false,
      modo: ModoDeBusca.prefixo,
    );
    await tester.enterText(find.byType(TextField), termo);
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
  }

  // =========================================================================
  // 1 — A matriz: o que a régua MEDE
  // =========================================================================
  group('1 — 320/360/412 dp por 100/150/200% — medida', () {
    for (final largura in _larguras) {
      for (final escala in _escalas) {
        final ponto = '${largura.toInt()} dp @ ${(escala * 100).toInt()}%';

        testWidgets(
          'M1 — os quatro controles no piso e dentro da tela — $ponto',
          (tester) => _comSemantica(tester, () async {
            await montar(tester, largura: largura, escala: escala);
            final alvos = _alvos(tester);
            for (final nome in _controlesNovos) {
              final a = _porNome(alvos, nome);

              // (a) ÁREA REAL. Não o desenho, e não a anotação: o retângulo do
              // nó que o leitor de tela anuncia e onde o dedo cai.
              expect(
                a.area.height,
                greaterThanOrEqualTo(_piso),
                reason: '$ponto: baixo demais $a',
              );
              expect(
                a.area.width,
                greaterThanOrEqualTo(_piso),
                reason: '$ponto: estreito demais $a',
              );

              // (b) ZERO CORTE PELA VIEWPORT no eixo em que não há rolagem. Um
              // controle que começa antes de 0 ou termina depois da largura
              // está fora da tela em aparelho nenhum — e esta página não rola
              // de lado, o que é o caso M4.
              expect(
                a.area.left,
                greaterThanOrEqualTo(-0.01),
                reason: '$ponto: $a começa fora da tela pela esquerda',
              );
              expect(
                a.area.right,
                lessThanOrEqualTo(largura + 0.01),
                reason: '$ponto: $a ultrapassa a largura da viewport',
              );

              // (c) PAPEL, NOME E ESTADO — o que o leitor de tela fala.
              expect(a.ehBotao, isTrue, reason: '$ponto: $a não é botão');
              expect(a.nome.trim(), isNotEmpty, reason: '$ponto: $a sem nome');
              expect(
                a.habilitado,
                isNot(Tristate.isFalse),
                reason: '$ponto: $a anunciado como desabilitado',
              );
              expect(a.aciona, isTrue, reason: '$ponto: $a não aceita toque');
            }
          }),
        );

        testWidgets('M2 — nenhum estouro na superfície de medida — $ponto', (
          tester,
        ) async {
          await montar(tester, largura: largura, escala: escala);
          expect(
            estouros,
            isEmpty,
            reason:
                '$ponto: o layout transbordou. Mascarar isto com `ClipRect` ou '
                'com fonte menor seria esconder conteúdo que a pessoa precisa '
                'ler — a saída é quebra, expansão ou disposição vertical.',
          );
        });

        testWidgets('M3 — nenhum estouro num telefone de verdade — $ponto', (
          tester,
        ) async {
          // A pilha do cabeçalho cresce com a escala, e é aqui que ela empurra
          // as abas para fora. Na superfície alta este defeito não aparece.
          await montar(
            tester,
            largura: largura,
            escala: escala,
            altura: _alturaReal,
          );
          expect(
            estouros,
            isEmpty,
            reason:
                '$ponto: transbordou num telefone de ${_alturaReal.toInt()} de '
                'altura',
          );
        });

        testWidgets(
          'M4 — sem rolagem horizontal, com rolagem vertical — $ponto',
          (tester) async {
            await montar(
              tester,
              largura: largura,
              escala: escala,
              altura: _alturaReal,
            );
            expect(
              find.byWidgetPredicate(
                (w) => w is ScrollView && w.scrollDirection == Axis.horizontal,
              ),
              findsNothing,
              reason: '$ponto: a página passou a rolar de lado',
            );
            expect(
              find.byWidgetPredicate(
                (w) => w is ScrollView && w.scrollDirection == Axis.vertical,
              ),
              findsWidgets,
              reason:
                  '$ponto: não há rolagem vertical nenhuma — o que não couber '
                  'na altura fica inalcançável',
            );
          },
        );

        testWidgets(
          'M5 — nenhuma sobreposição material — $ponto',
          (tester) => _comSemantica(tester, () async {
            await montar(tester, largura: largura, escala: escala);
            final alvos = _alvos(tester);
            for (var i = 0; i < alvos.length; i++) {
              for (var j = i + 1; j < alvos.length; j++) {
                final a = alvos[i].area;
                final b = alvos[j].area;
                // CONTER é o desenho desta tela — o botão mora dentro da linha,
                // e o Flutter entrega o toque ao mais interno. O que não pode
                // existir é interseção PARCIAL: ali o dedo cai num dos dois sem
                // que o desenho diga em qual.
                if (_contem(a, b) || _contem(b, a)) continue;
                expect(
                  a.overlaps(b),
                  isFalse,
                  reason: '$ponto: ${alvos[i]} e ${alvos[j]} se cruzam',
                );
              }
            }
          }),
        );
      }
    }
  });

  // =========================================================================
  // 2 — A matriz: o que o DEDO alcança, num telefone de verdade
  // =========================================================================
  group('2 — 320/360/412 dp por 100/150/200% — alcance e toque', () {
    for (final largura in _larguras) {
      for (final escala in _escalas) {
        final ponto = '${largura.toInt()} dp @ ${(escala * 100).toInt()}%';

        testWidgets('T1 — Aparecer offline alcança e alterna — $ponto', (
          tester,
        ) async {
          await montar(
            tester,
            largura: largura,
            escala: escala,
            altura: _alturaReal,
          );
          final antes = t.chamadasDe('definirAparecerOffline');
          await tester.ensureVisible(find.byTooltip('Aparecer offline'));
          await tester.pumpAndSettle();
          await tester.tap(find.byTooltip('Aparecer offline'));
          await tester.pumpAndSettle(const Duration(seconds: 3));
          expect(
            t.chamadasDe('definirAparecerOffline'),
            antes + 1,
            reason: '$ponto: o toque não chegou à autoridade',
          );
        });

        testWidgets('T2 — Copiar alcança e copia o código — $ponto', (
          tester,
        ) async {
          // A ÁREA DE TRANSFERÊNCIA É PLATAFORMA. Sem um atendente para
          // `SystemChannels.platform`, `Clipboard.setData` estoura com
          // `MissingPluginException` dentro do `async` do botão, o recado nunca
          // sai, e o caso reprovaria por bancada — dizendo que copiar não
          // responde quando o que falta é o aparelho.
          final copiado = <String>[];
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            (chamada) async {
              if (chamada.method == 'Clipboard.setData') {
                copiado.add(
                  (chamada.arguments as Map)['text'] as String? ?? '',
                );
              }
              return null;
            },
          );
          addTearDown(
            () => tester.binding.defaultBinaryMessenger
                .setMockMethodCallHandler(SystemChannels.platform, null),
          );

          await montar(
            tester,
            largura: largura,
            escala: escala,
            altura: _alturaReal,
          );
          await tester.ensureVisible(find.text('Copiar'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Copiar'));
          await tester.pumpAndSettle();
          expect(
            copiado,
            ['P0EUMESMO0001'],
            reason: '$ponto: o que foi para a área de transferência não é o '
                'código de convite desta sessão',
          );
          expect(
            find.text('Código copiado.'),
            findsOneWidget,
            reason: '$ponto: copiar não respondeu nada',
          );
          await tester.pumpAndSettle(const Duration(seconds: 3));
        });

        testWidgets('T3 — Usar um código alcança e abre o diálogo — $ponto', (
          tester,
        ) async {
          await montar(
            tester,
            largura: largura,
            escala: escala,
            altura: _alturaReal,
          );
          await tester.ensureVisible(find.text('Usar um código'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Usar um código'));
          await tester.pumpAndSettle();
          expect(
            find.text('Código de quem convidou você'),
            findsOneWidget,
            reason: '$ponto: o diálogo de indicação não abriu',
          );
          await tester.tap(find.text('Cancelar'));
          await tester.pumpAndSettle();
        });

        testWidgets('T4 — Chamar pra jogar alcança e leva ao lobby — $ponto', (
          tester,
        ) async {
          await montar(
            tester,
            largura: largura,
            escala: escala,
            altura: _alturaReal,
          );
          await tester.ensureVisible(find.text('Chamar pra jogar'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Chamar pra jogar'));
          await tester.pumpAndSettle();
          expect(
            find.byType(LobbyOnline),
            findsOneWidget,
            reason: '$ponto: chamar pra jogar não levou a lugar nenhum',
          );
          await tester.pumpAndSettle(const Duration(seconds: 3));
        });
      }
    }
  });

  // =========================================================================
  // 3 — A aba inicial, e a lista de amigos a uma escolha de distância
  // =========================================================================
  group('3 — a entrada é Online, e Amigos é escolha explícita', () {
    testWidgets(
      'A1 — Online nasce selecionada, e é ela quem consulta',
      (tester) => _comSemantica(tester, () async {
        // A DECISÃO ESTÁ REGISTRADA AQUI. A composição escolheu a presença como
        // entrada — é o que o cabeçalho de `amigos_de_producao.dart` documenta
        // —, e este caso é a autoridade que diz isso em voz alta. Se um dia a
        // entrada voltar a ser `Todos`, é este caso que fica vermelho, e não um
        // detalhe de outra suíte descobrindo por acidente.
        await montar(tester);
        final alvos = _alvos(tester);
        expect(_porNome(alvos, 'Online').selecionado, Tristate.isTrue);
        expect(_porNome(alvos, 'Todos').selecionado, Tristate.isFalse);
        expect(_porNome(alvos, 'Pedidos').selecionado, Tristate.isFalse);

        expect(t.chamadasDe('listarOnline'), 1);
        expect(
          t.chamadasDe('listarAmigos'),
          0,
          reason:
              'a entrada consultou a lista de amigos sem ninguém ter pedido — '
              'a aba inicial e a lista consultada têm de ser a mesma',
        );
        expect(find.text('Bia'), findsOneWidget);
      }),
    );

    testWidgets('A2 — escolher Todos consulta listarAmigos e mostra o nome', (
      tester,
    ) async {
      await montar(tester);
      await trocarPara(tester, 'Todos');
      expect(t.chamadasDe('listarAmigos'), 1);
      expect(find.text('Caio'), findsOneWidget);
    });

    testWidgets('A3 — a linha de Todos navega pelo publicId daquela linha', (
      tester,
    ) async {
      await montar(tester);
      await trocarPara(tester, 'Todos');
      // A SEGUNDA linha, de propósito: navegação por índice fixo ou pelo
      // primeiro item passaria com o perfil errado.
      await tester.tap(find.text('Caio'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      final pagina = tester.widget<PerfilPage>(find.byType(PerfilPage));
      expect(pagina.publicIdVisitado, 'P2');
      expect(pagina.ehMeuPerfil, isFalse);
    });
  });

  // =========================================================================
  // 4 — A remoção mudou de autoridade, e não desapareceu
  // =========================================================================
  group('4 — desfazer amizade continua alcançável, pelo Perfil', () {
    testWidgets('R1 — a LISTA não oferece Remover, e isso é a regra da tela', (
      tester,
    ) async {
      await montar(tester);
      await trocarPara(tester, 'Todos');
      // `listarAmigos` devolve entradas SEM `acoes`, e o cabeçalho da tela diz
      // que ela não deduz botão. Antes da composição havia uma exceção — a
      // lista desenhava `Remover` por dedução —, e ela caiu.
      expect(find.text('Remover'), findsNothing);
    });

    testWidgets('R2 — pelo Perfil, o SERVIDOR oferece Remover', (tester) async {
      t.perfis['P2'] = resultadoFalso(
        'P2',
        apelido: 'Caio',
        relacao: RelacaoSocial.amigos,
        acoes: const [AcaoSocial.removerAmigo],
      );
      await montar(tester);
      await trocarPara(tester, 'Todos');
      await tester.tap(find.text('Caio'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(find.byType(PerfilPage), findsOneWidget);
      expect(
        find.text('Remover'),
        findsOneWidget,
        reason:
            'a lista deixou de oferecer Remover e o Perfil também não oferece '
            '— a capacidade de desfazer amizade desapareceu da superfície',
      );
    });

    testWidgets('R3 — e o toque desfaz a amizade daquele publicId', (
      tester,
    ) async {
      t.perfis['P2'] = resultadoFalso(
        'P2',
        apelido: 'Caio',
        relacao: RelacaoSocial.amigos,
        acoes: const [AcaoSocial.removerAmigo],
      );
      await montar(tester);
      await trocarPara(tester, 'Todos');
      await tester.tap(find.text('Caio'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      t.perfis['P2'] = resultadoFalso(
        'P2',
        apelido: 'Caio',
        acoes: const [AcaoSocial.adicionarAmigo],
      );
      await tester.tap(find.text('Remover'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      final acao = t.chamadas.lastWhere((c) => c.metodo == 'agir');
      expect(acao.acao, AcaoSocial.removerAmigo);
      expect(acao.publicId, 'P2');
      // E a tela passa a mostrar o que a autoridade diz AGORA.
      expect(find.text('Adicionar'), findsOneWidget);
      expect(find.text('Remover'), findsNothing);
    });
  });

  // =========================================================================
  // 5 — O inventário exato e ordenado, cena a cena
  // =========================================================================
  group('5 — o que existe, e em que ordem, em cada cena', () {
    testWidgets(
      'V1 — Online',
      (tester) => _comSemantica(tester, () async {
        await montar(tester);
        expect(_alvos(tester).map((a) => a.nome).toList(), <String>[
          'Voltar',
          'Aparecer offline',
          'Copiar',
          'Usar um código',
          'Buscar por apelido ou código…',
          'Online',
          'Todos',
          'Pedidos',
          '', // a linha de Bia
          'Chamar pra jogar',
        ]);
      }),
    );

    testWidgets(
      'V2 — Pedidos',
      (tester) => _comSemantica(tester, () async {
        await montar(tester);
        await trocarPara(tester, 'Pedidos');
        expect(_alvos(tester).map((a) => a.nome).toList(), <String>[
          'Voltar',
          'Aparecer offline',
          'Copiar',
          'Usar um código',
          'Buscar por apelido ou código…',
          'Online',
          'Todos',
          'Pedidos',
          '', // a linha de Duda, em SOLICITAÇÕES
          'Aceitar',
          'Recusar',
          '', // a linha de Elis, em ENVIADOS
          'Cancelar',
        ]);
      }),
    );

    testWidgets(
      'V3 — busca',
      (tester) => _comSemantica(tester, () async {
        await montar(tester);
        await buscar(tester, 'bia');
        // O CAMPO PERDE O NOME quando tem texto: o rótulo do nó vem do
        // `hintText`, que só existe enquanto ele está vazio, e o que a pessoa
        // digitou vai para o VALOR do nó, não para o rótulo. Anotar aqui evita
        // que a próxima leitura conclua que o campo ficou anônimo por defeito.
        expect(_alvos(tester).map((a) => a.nome).toList(), <String>[
          'Voltar',
          'Aparecer offline',
          'Copiar',
          'Usar um código',
          '', // o campo de busca, agora com texto
          'Limpar busca',
          '', // a linha de Bia
          'Adicionar',
        ]);
      }),
    );
  });

  // =========================================================================
  // 6 — Os residuais herdados, declarados
  // =========================================================================
  group('6 — o que esta OS NÃO corrigiu, escrito', () {
    testWidgets(
      'D1 — os nós anunciados sem toque próprio continuam os mesmos',
      (tester) => _comSemantica(tester, () async {
        // ------------------------------------------------------------------
        // ISTO NÃO É UMA CORREÇÃO. É UM REGISTRO.
        // ------------------------------------------------------------------
        //
        // Três formas do mesmo residual herdado:
        //
        //   * `Semantics(button: true, label: 'Aparecer offline para amigos')`
        //     por fora do `IconButton` — o rótulo longo é anunciado num nó que
        //     não recebe toque, e quem recebe o toque anuncia o `tooltip`;
        //   * o anúncio por extenso de cada linha, que é botão e não aciona: a
        //     linha inteira é que aciona, um nível acima;
        //   * `_BotaoDeAcao`, que embrulha o botão num `Semantics` com papel de
        //     botão e sem ação própria, deixando um nó anônimo na travessia.
        //
        // Nada disso veio desta OS, e corrigir qualquer um mexeria na anotação
        // que os 75 casos congelados medem. O caso existe para que o número não
        // cresça em silêncio e para que ninguém leia esta OS como tendo
        // consertado o que ela não consertou.
        await montar(tester);
        await trocarPara(tester, 'Pedidos');
        expect(
          _nos(tester).where((a) => a.ehBotao && !a.aciona).map((a) => a.nome),
          <String>[
            'Aparecer offline para amigos',
            'Duda. Quer ser seu amigo. Toque para ver o perfil.',
            '', // o embrulho de Aceitar
            '', // o embrulho de Recusar
            'Elis. Pedido enviado. Toque para ver o perfil.',
            '', // o embrulho de Cancelar
          ],
          reason:
              'o conjunto de nós com papel de botão e sem toque próprio mudou; '
              'se foi para menos, este registro tem de ser atualizado junto '
              'com a correção',
        );
      }),
    );

    testWidgets(
      'D2 — os botões de ação do PERFIL continuam abaixo do piso',
      (tester) => _comSemantica(tester, () async {
        // ------------------------------------------------------------------
        // OUTRO REGISTRO, E ELE É DESCONFORTÁVEL
        // ------------------------------------------------------------------
        //
        // A OS 17 corrigiu o alvo dos botões de ação da tela de AMIGOS; os do
        // `perfil_page.dart` ficaram com `BoxConstraints(minHeight: 40)` e área
        // efetiva de 40. O `Remover` que esta OS provou alcançável é um deles.
        //
        // Corrigi-lo é mexer numa rota fora de Amigos, que esta C2 não está
        // autorizada a alterar. Fica MEDIDO e escrito: o dia em que alguém
        // levar o Perfil ao piso, este caso reprova e aponta para si mesmo.
        t.perfis['P2'] = resultadoFalso(
          'P2',
          apelido: 'Caio',
          relacao: RelacaoSocial.amigos,
          acoes: const [AcaoSocial.removerAmigo],
        );
        await montar(tester);
        await trocarPara(tester, 'Todos');
        await tester.tap(find.text('Caio'));
        await tester.pumpAndSettle();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpAndSettle();

        final b = _porNome(_alvos(tester), 'Remover');
        expect(
          b.area.height,
          40.0,
          reason:
              'o alvo do Perfil mudou de altura. Se subiu para 48, o residual '
              'foi corrigido e este registro sai — mas por decisão escrita, e '
              'não de carona.',
        );
        expect(b.area.width, greaterThanOrEqualTo(_piso));
      }),
    );
  });

  // =========================================================================
  // 7 — A terceira perna da instrumentação
  // =========================================================================
  group('7 — o passo 0 e a guarda Dart continuam existindo', () {
    // ------------------------------------------------------------------
    // POR QUE ESTES CASOS MORAM AQUI, E NÃO NA GUARDA
    // ------------------------------------------------------------------
    //
    // O passo 0 do workflow protege a guarda Dart; a guarda Dart protege o
    // passo 0. Derrubar os DOIS juntos deixaria o portão sem ninguém: a suíte
    // apagada vira NÃO EXECUTADO, que não reprova, e o passo apagado não deixa
    // rastro nenhum no portão.
    //
    // Uma terceira perna precisa morar fora das duas. Ela mora aqui porque este
    // é o outro gate desta OS, e não porque este arquivo tenha vocação de
    // instrumentação — é a única posição que fecha o triângulo sem inventar uma
    // segunda arquitetura de portão.
    //
    // Ela confere EXISTÊNCIA E VIDA, e não impressão digital: as impressões são
    // trabalho dos dois que se medem, e repeti-las aqui exigiria recarimbar
    // três arquivos a cada edição legítima sem fechar nenhum ataque a mais.
    String ler(String caminho) {
      final f = File(caminho);
      expect(
        f.existsSync(),
        isTrue,
        reason:
            'sumiu "$caminho" (corrente: ${Directory.current.path}) — se ele '
            'caiu junto com o outro guardião, esta é a única prova que sobrou',
      );
      return f.readAsStringSync().replaceAll('\r', '');
    }

    test('P1 — o verificador shell existe e ainda decide', () {
      expect(
        ler('../scripts/ci/verificar_suites_obrigatorias.sh'),
        contains('exit "\$falhas"'),
      );
    });

    test('P2 — a guarda Dart existe e ainda analisa', () {
      final s = ler('test/ci/suites_obrigatorias_test.dart');
      expect(s, contains('_analisar('));
      expect(s, contains('_digestCarimbado'));
    });

    test('P3 — o contrato externo existe, com as 75 identidades', () {
      final linhas = ler('test/contrato_alvos_amigos.txt').split('\n');
      expect(linhas.where((l) => l.startsWith('caso ')), hasLength(75));
      expect(linhas, contains('piso         48.0'));
    });

    test('P4 — o passo 0 continua no workflow, com o comando vivo', () {
      final linhas = ler('../.github/workflows/ci-os-integracao.yml')
          .split('\n')
          .map((l) => l.trim())
          .toList();
      expect(
        linhas.where((l) => l.contains('verificar_suites_obrigatorias.sh')),
        hasLength(1),
        reason: 'a invocação do verificador saiu do workflow',
      );
      expect(linhas, contains('exit "\$st"'));
    });
  });
}
