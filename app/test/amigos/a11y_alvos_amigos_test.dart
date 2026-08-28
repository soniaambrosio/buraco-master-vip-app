// a11y_alvos_amigos_test.dart — o PISO DE TOQUE da superfície Amigos, medido
// na árvore de acessibilidade e confirmado no hit test real.
//
// ---------------------------------------------------------------------------
// O QUE ESTE ARQUIVO MEDE, E POR QUE ELE NÃO PROCURA `48` NO CÓDIGO
// ---------------------------------------------------------------------------
//
// Nenhum caso aqui lê o fonte da tela. O que eles fazem é montar Amigos, ligar
// a árvore de acessibilidade com `ensureSemantics()` e LER os nós que o Flutter
// realmente produziu — rótulo, papel, estado, ação e retângulo. É a diferença
// entre provar que alguém escreveu um número e provar que o número chegou ao
// alvo: um `ConstrainedBox` que o layout de cima esmaga, um `visualDensity`
// que subtrai 8 do alvo depois de o piso já ter sido escrito, ou um piso
// declarado num `Semantics` que o dedo não encontra — nada disso aparece numa
// varredura de texto, e tudo isso aparece aqui.
//
// E MEDIR NÃO BASTA. O retângulo do nó semântico é o que o leitor de tela
// anuncia; ele NÃO prova que o dedo, encostando na borda nova, aciona o
// controle certo. Por isso metade dos casos abaixo toca em COORDENADA — nos
// quatro meios de borda do alvo medido — e confere qual callback respondeu.
// Um alvo que crescesse só na anotação passaria no grupo 1 e reprovaria no 3.
//
// A MEDIDA É EM PONTOS LÓGICOS. A bancada roda com `devicePixelRatio` 3, então
// o retângulo cru vem em PIXELS FÍSICOS; [_nos] divide pela razão antes de
// comparar. Sem isso, 48 pontos "medem" 144 e todo caso passa por engano.
//
// SUPERFÍCIE ALTA (1080x6000, dpr 3 = 360x2000 lógicos): telefone na largura,
// para o layout ser o real, e alta o bastante para a tela inteira ser
// construída. Nó fora da viewport não existe, e medir num 360x800 daria verde
// sobre metade da lista. E é a VIEW que se redimensiona, nunca a superfície:
// `setSurfaceSize` não chega a rotas de overlay, e produz falso positivo de
// "controle fora da tela".
//
// ---------------------------------------------------------------------------
// O QUE ESTE ARQUIVO NÃO JULGA
// ---------------------------------------------------------------------------
//
// Não julga regra social. Quem prova que a lista veio da autoridade, que o
// botão desenhado é o que o servidor ofereceu e que a ação chega com o
// `publicId` certo é `descoberta_social_tela_test.dart`. Aqui esses fatos
// aparecem só como PRESERVAÇÃO: o mesmo callback, depois de o alvo crescer.

import 'dart:async';
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:buraco_master_vip/amigos/escopo_social.dart';
import 'package:buraco_master_vip/amigos/estado_social.dart';
import 'package:buraco_master_vip/amigos/leitor_social.dart';
import 'package:buraco_master_vip/casca/amigos_de_producao.dart';
import 'package:buraco_master_vip/pages/perfil_page.dart';
import 'package:buraco_master_vip/sessao/escopo_sessao.dart';
import 'package:buraco_master_vip/sessao/fonte_identidade.dart';
import 'package:buraco_master_vip/sessao/identidade_publica_sessao.dart';
import 'package:buraco_master_vip/sessao/sessao_do_jogador.dart';

import 'bancada_social.dart';

// ===========================================================================
// A régua
// ===========================================================================

/// Um nó da árvore de acessibilidade, traduzido para o que esta OS julga.
class _Alvo {
  _Alvo({
    required this.id,
    required this.label,
    required this.tooltip,
    required this.valor,
    required this.dica,
    required this.area,
    required this.ehBotao,
    required this.ehCampo,
    required this.habilitado,
    required this.selecionado,
    required this.aciona,
    required this.ordem,
  });

  final int id;
  final String label;
  final String tooltip;
  final String valor;
  final String dica;

  /// Em PONTOS LÓGICOS, já dividido pelo `devicePixelRatio`.
  final Rect area;

  final bool ehBotao;
  final bool ehCampo;
  final Tristate habilitado;
  final Tristate selecionado;

  /// O nó aceita a ação de toque? É o que um leitor de tela dispara, e é
  /// diferente de ter um detector de gesto por baixo.
  final bool aciona;

  /// A posição na travessia — a ordem em que o leitor de tela anda.
  final int ordem;

  /// O nome acessível: `label` e, se ele for vazio, o `tooltip`.
  ///
  /// `IconButton(tooltip:)` põe o nome em `tooltip`, e não em `label`. Um
  /// portão que olhasse só `label` acusaria de anônimo o "Limpar busca", que
  /// já estava certo antes desta OS.
  String get nome => label.trim().isNotEmpty ? label.trim() : tooltip.trim();

  /// Tudo o que este nó FALA — para a varredura de UID.
  String get fala => '$label $tooltip $valor $dica';

  @override
  String toString() =>
      '#$id "$nome" botao=$ehBotao campo=$ehCampo sel=$selecionado '
      'toque=$aciona ${area.width.toStringAsFixed(1)}x'
      '${area.height.toStringAsFixed(1)} @${area.left.toStringAsFixed(1)},'
      '${area.top.toStringAsFixed(1)}';
}

/// A raiz da árvore de acessibilidade.
///
/// Sobe a partir do `MaterialApp`, e NÃO da tela: com uma rota empilhada o
/// Flutter tira a de baixo da árvore, e ancorar na tela devolveria um nó de
/// subárvore descartada — que ainda responde, e ainda tem os filhos antigos.
SemanticsNode _raiz(WidgetTester tester) {
  var no = tester.getSemantics(find.byType(MaterialApp));
  while (no.parent != null) {
    no = no.parent!;
  }
  return no;
}

/// Todos os nós, na ordem em que o leitor de tela os encontra.
List<_Alvo> _nos(WidgetTester tester) {
  final dpr = tester.view.devicePixelRatio;
  final saida = <_Alvo>[];

  void anda(SemanticsNode no, Matrix4 acumulado) {
    final m = acumulado.clone();
    if (no.transform != null) m.multiply(no.transform!);
    final fisico = MatrixUtils.transformRect(m, no.rect);
    final d = no.getSemanticsData();
    saida.add(
      _Alvo(
        id: no.id,
        label: d.label,
        tooltip: d.tooltip,
        valor: d.value,
        dica: d.hint,
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
        ordem: saida.length,
      ),
    );
    no.visitChildren((filho) {
      anda(filho, m);
      return true;
    });
  }

  anda(_raiz(tester), Matrix4.identity());
  return saida;
}

/// Só os nós que respondem a toque — os que esta OS julga por tamanho.
///
/// O CAMPO DE BUSCA ENTRA. Ele não é botão, mas é alvo: quem toca nele abre o
/// teclado, e a diretriz de tamanho não distingue papel.
List<_Alvo> _alvos(WidgetTester tester) =>
    _nos(tester).where((a) => a.aciona).toList();

_Alvo _porNome(List<_Alvo> alvos, String nome) => alvos.firstWhere(
  (a) => a.nome == nome,
  orElse: () => throw StateError(
    'nenhum alvo chamado "$nome"; havia ${alvos.map((a) => a.nome).toList()}',
  ),
);

/// A linha de um jogador. Ela é o único alvo SEM nome próprio da tela: quem
/// fala por ela é o nó de anúncio que mora dentro (ver [_anuncios]).
List<_Alvo> _linhas(List<_Alvo> alvos) =>
    alvos.where((a) => a.nome.isEmpty && !a.ehCampo && !a.ehBotao).toList();

/// Os nós que ANUNCIAM uma linha por extenso — não acionáveis, e por isso fora
/// de [_alvos]. Eles carregam a frase que o leitor de tela lê.
List<_Alvo> _anuncios(WidgetTester tester) => _nos(tester)
    .where((a) => !a.aciona && a.nome.contains('Toque para ver o perfil'))
    .toList();

/// `a` contém `b` por inteiro?
bool _contem(Rect a, Rect b) =>
    b.left >= a.left - 0.01 &&
    b.top >= a.top - 0.01 &&
    b.right <= a.right + 0.01 &&
    b.bottom <= a.bottom + 0.01;

/// O piso desta OS. Escrito aqui, e não importado da tela, DE PROPÓSITO: um
/// portão que cite a constante do produto passa a acompanhar o produto, e
/// baixar o piso na tela ficaria verde.
const double _piso = 48.0;

/// Os quatro MEIOS DE BORDA do alvo, um ponto para dentro.
///
/// Um ponto, e não meio ponto: o toque cai em ponto lógico, e a borda exata
/// é o limite do `Rect` — encostar nela é ambíguo por construção. Um ponto
/// para dentro já está na FAIXA NOVA de todo alvo que esta OS ampliou (o
/// menor crescimento foi de 4 pontos, no Voltar), e os quatro pontos cobrem
/// os dois eixos: topo e base provam o crescimento em altura, esquerda e
/// direita o crescimento em largura.
///
/// E POR QUE NÃO OS CANTOS. Porque o canto de um controle arredondado não é
/// tocável, e isso não é defeito: `Material` com `borderRadius` desenha um
/// `PhysicalShape`, e `RenderPhysicalShape.hitTest` RECUSA o toque fora do
/// recorte. As três abas (raio 10) e as linhas (raio 12) se comportam assim,
/// e uma prova por canto acusaria de inoperante um controle que funciona —
/// foi exatamente o que a primeira versão desta suíte fez, e o falso positivo
/// era convincente. O TAMANHO continua medido pelo retângulo, que é o que o
/// leitor de tela anuncia; o TOQUE é conferido onde o desenho responde.
List<Offset> _bordas(Rect r) => <Offset>[
  Offset(r.center.dx, r.top + 1),
  Offset(r.center.dx, r.bottom - 1),
  Offset(r.left + 1, r.center.dy),
  Offset(r.right - 1, r.center.dy),
];

// ===========================================================================
// A bancada
// ===========================================================================

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

/// Liga a árvore de acessibilidade e a desliga DENTRO do corpo do caso.
///
/// `addTearDown(handle.dispose)` não serve: o `flutter_test` confere se sobrou
/// `SemanticsHandle` ANTES de rodar os tear-downs, e todo caso reprovaria por
/// arnês, com uma mensagem que não diz isso.
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

void main() {
  late TransporteSocialFalso t;
  late LeitorSocial social;
  late SessaoDoJogador sessao;
  late StreamController<String?> uids;

  setUp(() {
    t = TransporteSocialFalso();
    social = LeitorSocial(transporte: t);
    uids = StreamController<String?>.broadcast();
    sessao = SessaoDoJogador(
      fonte: _FonteFalsa(),
      uids: uids.stream,
      uidInicial: 'uid-A',
    );
  });

  tearDown(() {
    social.dispose();
    sessao.dispose();
    uids.close();
  });

  /// Deixa a tela assentar de verdade — o Perfil tem atraso artificial de
  /// 350 ms, e `pumpAndSettle` volta antes dele.
  Future<void> assentar(WidgetTester tester) async {
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
  }

  void telefoneAlto(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 6000);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  /// Monta Amigos.
  ///
  /// [comRotaAbaixo] empilha a tela sobre uma rota inicial, que é o único jeito
  /// de `maybePop` ter o que fazer — sem ela, o Voltar seria testado num
  /// navegador de uma rota só, onde não voltar é o comportamento CERTO e o caso
  /// passaria sem provar nada.
  ///
  /// [comEscopo] falso encena "fora do aplicativo", em que a tela desenha só o
  /// topo e a busca.
  Future<void> montar(
    WidgetTester tester, {
    bool comRotaAbaixo = false,
    bool comEscopo = true,
    bool deixarAssentar = true,
  }) async {
    telefoneAlto(tester);
    // ÁRVORE NOVA A CADA MONTAGEM, e isto não é zelo: `pumpWidget` casa a
    // árvore nova com a anterior e REAPROVEITA o `State` quando o tipo do
    // widget bate. Nos laços que percorrem as quatro bordas de um controle,
    // a segunda volta nasceria com a aba já trocada pela primeira — e a
    // pré-condição do caso seria falsa por herança, não por defeito.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    const tela = AmigosDeProducao();
    Widget corpo = MaterialApp(
      home: comRotaAbaixo
          ? Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () => Navigator.of(
                      context,
                    ).push(MaterialPageRoute<void>(builder: (_) => tela)),
                    child: const Text('ABRIR AMIGOS'),
                  ),
                ),
              ),
            )
          : tela,
    );
    if (comEscopo) corpo = EscopoSocial(social: social, child: corpo);
    await tester.pumpWidget(EscopoSessao(sessao: sessao, child: corpo));
    // Sem assentar para o caso que precisa OLHAR o carregamento: enquanto o
    // indicador roda, a árvore nunca para de se mexer e `pumpAndSettle`
    // estoura por tempo. Não é limitação do teste — é a animação existindo,
    // que é justamente o que aquela cena quer ver.
    if (!deixarAssentar) {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      return;
    }
    await assentar(tester);
    if (comRotaAbaixo) {
      await tester.tap(find.text('ABRIR AMIGOS'));
      await assentar(tester);
    }
  }

  // -------------------------------------------------------------------------
  // As cenas
  // -------------------------------------------------------------------------

  Future<void> comAmigos(WidgetTester tester) async {
    t.respostaAmigos = paginaFalsa([
      jogadorFalso('P1', apelido: 'Bia'),
      jogadorFalso('P2', apelido: 'Caio'),
    ], proximoCursor: 'c1');
    await montar(tester);
    await tester.tap(find.text('Todos'));
    await assentar(tester);
  }

  Future<void> emRecebidas(WidgetTester tester) async {
    t.respostaRecebidas = paginaFalsa([jogadorFalso('P3', apelido: 'Duda')]);
    await montar(tester);
    await tester.tap(find.text('Pedidos'));
    await assentar(tester);
  }

  Future<void> emEnviadas(WidgetTester tester) async {
    t.respostaEnviadas = paginaFalsa([jogadorFalso('P4', apelido: 'Elis')]);
    await montar(tester);
    await tester.tap(find.text('Pedidos'));
    await assentar(tester);
  }

  Future<void> buscar(WidgetTester tester, String termo) async {
    await tester.enterText(find.byType(TextField), termo);
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await assentar(tester);
  }

  Future<void> emBusca(WidgetTester tester) async {
    t.respostaDaBusca = ResultadosDeBusca(
      termo: 'bia',
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
    await montar(tester);
    await buscar(tester, 'bia');
  }

  Future<void> emBuscaTruncada(WidgetTester tester) async {
    t.respostaDaBusca = ResultadosDeBusca(
      termo: 'bi',
      itens: [resultadoFalso('P9', apelido: 'Bia')],
      truncado: true,
      modo: ModoDeBusca.prefixo,
    );
    await montar(tester);
    await buscar(tester, 'bia');
  }

  Future<void> emFalhaDeLista(WidgetTester tester) async {
    t.falhaFixa = const FalhaSocial(MotivoFalhaSocial.indisponivel);
    await montar(tester);
  }

  Future<void> emFalhaDeBusca(WidgetTester tester) async {
    await montar(tester);
    t.proximaFalha = const FalhaSocial(MotivoFalhaSocial.indisponivel);
    await buscar(tester, 'bia');
  }

  Future<void> emVazio(WidgetTester tester) => montar(tester);

  Future<void> emCarregamento(WidgetTester tester) async {
    t.manual = true;
    await montar(tester, deixarAssentar: false);
  }

  Future<void> foraDoEscopo(WidgetTester tester) =>
      montar(tester, comEscopo: false);

  final cenas = <String, Future<void> Function(WidgetTester)>{
    'todos + carregar mais': comAmigos,
    'pedidos recebidos': emRecebidas,
    'pedidos enviados': emEnviadas,
    'busca com resultado': emBusca,
    'busca truncada': emBuscaTruncada,
    'falha de lista': emFalhaDeLista,
    'falha de busca': emFalhaDeBusca,
    'vazio': emVazio,
    'carregando': emCarregamento,
    'fora do escopo': foraDoEscopo,
  };

  // =========================================================================
  // 1 — O piso
  // =========================================================================
  group('1 — o piso de 48 pontos', () {
    testWidgets(
      '1a — o Voltar mede ao menos 48x48 (media 44x44 na base)',
      (tester) => _comSemantica(tester, () async {
        await comAmigos(tester);
        final voltar = _porNome(_alvos(tester), 'Voltar');
        expect(
          voltar.area.width,
          greaterThanOrEqualTo(_piso),
          reason: '$voltar',
        );
        expect(
          voltar.area.height,
          greaterThanOrEqualTo(_piso),
          reason: '$voltar',
        );
      }),
    );

    for (final cena in cenas.entries) {
      testWidgets(
        '1b — nenhum alvo mede menos de 48x48 — ${cena.key}',
        (tester) => _comSemantica(tester, () async {
          await cena.value(tester);
          final alvos = _alvos(tester);
          expect(
            alvos,
            isNotEmpty,
            reason: '${cena.key}: cena sem alvo nenhum',
          );
          for (final a in alvos) {
            expect(
              a.area.height,
              greaterThanOrEqualTo(_piso),
              reason: '${cena.key}: baixo demais $a',
            );
            expect(
              a.area.width,
              greaterThanOrEqualTo(_piso),
              reason: '${cena.key}: estreito demais $a',
            );
          }
        }),
      );
    }

    testWidgets(
      '1c — o inventário nominal preserva os controles essenciais',
      (tester) => _comSemantica(tester, () async {
        // IGUALDADE EXATA E ORDENADA, e não `contains`.
        //
        // `contains` responde "o controle X ainda existe?", que é metade da
        // pergunta. Ele fica verde com um alvo A MAIS — um botão novo que
        // ninguém reviu —, com um alvo DUPLICADO e com a ordem de leitura
        // trocada, que é justamente a travessia que o leitor de tela anuncia.
        // A lista abaixo é a cena inteira, na ordem em que o foco a percorre:
        // zero extra, zero ausente, zero duplicata fora das que o desenho
        // explica (uma linha e um "Chamar pra jogar" por jogador).
        //
        // SOBRE O "Remover" QUE ESTAVA AQUI ANTES DA COMPOSIÇÃO. Ele não
        // sumiu: saiu da LISTA e passou a ser oferecido pelo Perfil, onde
        // quem declara as ações é o servidor (`verPerfilPublico`), e não uma
        // dedução do cliente a partir da aba. A tela diz isso no próprio
        // cabeçalho — "NÃO DEDUZ BOTÃO" — e a lista era a única exceção. O
        // caminho novo é provado ponta a ponta em `matriz_amigos_test.dart`,
        // grupo 3; sem aquela prova, esta ausência seria um desaparecimento
        // silencioso de capacidade, e não uma mudança de autoridade.
        await comAmigos(tester);
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
          '', // a linha de Caio
          'Chamar pra jogar',
          'Carregar mais',
        ]);
        expect(_linhas(_alvos(tester)), hasLength(2));
      }),
    );

    testWidgets(
      '1d — recebidas oferece Aceitar e Recusar, ambos no piso',
      (tester) => _comSemantica(tester, () async {
        await emRecebidas(tester);
        final alvos = _alvos(tester);
        for (final nome in ['Aceitar', 'Recusar']) {
          final b = _porNome(alvos, nome);
          expect(b.area.height, greaterThanOrEqualTo(_piso), reason: '$b');
          expect(b.area.width, greaterThanOrEqualTo(_piso), reason: '$b');
        }
      }),
    );
  });

  // =========================================================================
  // 2 — Sobreposição
  // =========================================================================
  group('2 — a área nova não invade a do vizinho', () {
    for (final cena in cenas.entries) {
      testWidgets(
        '2a — nenhuma interseção parcial — ${cena.key}',
        (tester) => _comSemantica(tester, () async {
          await cena.value(tester);
          final alvos = _alvos(tester);
          for (var i = 0; i < alvos.length; i++) {
            for (var j = i + 1; j < alvos.length; j++) {
              final a = alvos[i].area;
              final b = alvos[j].area;
              // CONTER é legítimo, e é o desenho desta tela: o botão de ação
              // mora DENTRO da linha, e o "Limpar busca" dentro do campo. O
              // Flutter entrega o toque ao mais interno, e os casos do grupo 3
              // provam que ele entrega. O que não pode existir é interseção
              // PARCIAL: ali o dedo cai num dos dois sem que o desenho diga
              // em qual.
              if (_contem(a, b) || _contem(b, a)) continue;
              expect(
                a.overlaps(b),
                isFalse,
                reason: '${cena.key}: ${alvos[i]} e ${alvos[j]} se cruzam',
              );
            }
          }
        }),
      );
    }

    testWidgets(
      '2b — o botão ampliado continua CABENDO na linha dele',
      (tester) => _comSemantica(tester, () async {
        await emRecebidas(tester);
        final alvos = _alvos(tester);
        final linhas = _linhas(alvos);
        expect(linhas, hasLength(1));
        for (final nome in ['Aceitar', 'Recusar']) {
          expect(
            _contem(linhas.single.area, _porNome(alvos, nome).area),
            isTrue,
            reason:
                '$nome vazou para fora da linha: ${_porNome(alvos, nome)} '
                'em ${linhas.single}',
          );
        }
      }),
    );

    testWidgets(
      '2c — Aceitar e Recusar continuam separados',
      (tester) => _comSemantica(tester, () async {
        await emRecebidas(tester);
        final alvos = _alvos(tester);
        final a = _porNome(alvos, 'Aceitar').area;
        final r = _porNome(alvos, 'Recusar').area;
        expect(a.overlaps(r), isFalse, reason: 'Aceitar $a x Recusar $r');
      }),
    );
  });

  // =========================================================================
  // 3 — Hit test real, nas bordas
  // =========================================================================
  group('3 — tocar na borda nova aciona o controle certo', () {
    testWidgets(
      '3a — os quatro cantos do Voltar voltam',
      (tester) => _comSemantica(tester, () async {
        for (var borda = 0; borda < 4; borda++) {
          await montar(tester, comRotaAbaixo: true);
          expect(find.byType(AmigosDeProducao), findsOneWidget);
          final area = _porNome(_alvos(tester), 'Voltar').area;
          expect(area.width, greaterThanOrEqualTo(_piso));
          await tester.tapAt(_bordas(area)[borda]);
          await assentar(tester);
          expect(
            find.byType(AmigosDeProducao),
            findsNothing,
            reason: 'a borda $borda de $area não voltou',
          );
          expect(find.text('ABRIR AMIGOS'), findsOneWidget);
        }
      }),
    );

    testWidgets(
      '3b — as bordas de cada aba trocam para a aba daquele rótulo',
      (tester) => _comSemantica(tester, () async {
        // O DESFECHO é a aba trocada e a lista daquela aba à vista, e NÃO a
        // contagem de consultas. Contar não serviria aqui: o leitor social
        // vive fora da árvore e sobrevive às remontagens deste laço, então a
        // partir da segunda volta `garantir` acha a página já carregada e não
        // consulta — o que é o comportamento certo dele, e reprovaria um
        // toque que funcionou. Quem prova a contagem é `leitor_social_test`.
        const esperado = {'Todos': 'Caio', 'Pedidos': 'Duda'};
        for (final entrada in esperado.entries) {
          for (var borda = 0; borda < 4; borda++) {
            t.respostaAmigos = paginaFalsa([
              jogadorFalso('P2', apelido: 'Caio'),
            ]);
            t.respostaRecebidas = paginaFalsa([
              jogadorFalso('P3', apelido: 'Duda'),
            ]);
            t.respostaEnviadas = paginaFalsa([
              jogadorFalso('P4', apelido: 'Elis'),
            ]);
            await montar(tester);
            final area = _porNome(_alvos(tester), entrada.key).area;
            expect(area.height, greaterThanOrEqualTo(_piso));
            expect(
              _porNome(_alvos(tester), entrada.key).selecionado,
              Tristate.isFalse,
            );
            await tester.tapAt(_bordas(area)[borda]);
            await assentar(tester);
            final agora = _porNome(_alvos(tester), entrada.key);
            expect(
              agora.selecionado,
              Tristate.isTrue,
              reason: 'a borda $borda de ${entrada.key} ($area) não trocou',
            );
            expect(
              find.text(entrada.value),
              findsOneWidget,
              reason:
                  'a borda $borda de ${entrada.key} trocou o rótulo mas '
                  'não a lista',
            );
          }
        }
      }),
    );

    testWidgets(
      '3c — os cantos de Aceitar aceitam, e com o publicId da linha',
      (tester) => _comSemantica(tester, () async {
        for (var borda = 0; borda < 4; borda++) {
          await emRecebidas(tester);
          final area = _porNome(_alvos(tester), 'Aceitar').area;
          expect(area.height, greaterThanOrEqualTo(_piso));
          await tester.tapAt(_bordas(area)[borda]);
          await assentar(tester);
          final acao = t.chamadas.lastWhere((c) => c.metodo == 'agir');
          expect(
            acao.acao,
            AcaoSocial.aceitarSolicitacao,
            reason: 'borda $borda',
          );
          expect(acao.publicId, 'P3', reason: 'borda $borda');
        }
      }),
    );

    testWidgets(
      '3d — os cantos de Recusar recusam, e nunca aceitam',
      (tester) => _comSemantica(tester, () async {
        for (var borda = 0; borda < 4; borda++) {
          await emRecebidas(tester);
          final area = _porNome(_alvos(tester), 'Recusar').area;
          await tester.tapAt(_bordas(area)[borda]);
          await assentar(tester);
          final acao = t.chamadas.lastWhere((c) => c.metodo == 'agir');
          expect(
            acao.acao,
            AcaoSocial.recusarSolicitacao,
            reason: 'borda $borda',
          );
          expect(acao.publicId, 'P3', reason: 'borda $borda');
        }
      }),
    );

    testWidgets(
      '3e — a borda ampliada do botão NÃO abre o Perfil da linha',
      (tester) => _comSemantica(tester, () async {
        // O botão está dentro da linha, e a linha navega. Crescer o alvo do
        // botão para dentro da linha só é seguro se o toque continuar parando
        // no botão — este caso é o que separa "alvo maior" de "alvo que
        // engoliu o vizinho".
        for (var borda = 0; borda < 4; borda++) {
          await emRecebidas(tester);
          final area = _porNome(_alvos(tester), 'Aceitar').area;
          await tester.tapAt(_bordas(area)[borda]);
          await assentar(tester);
          expect(
            find.byType(PerfilPage),
            findsNothing,
            reason: 'a borda $borda de Aceitar caiu na linha',
          );
        }
      }),
    );

    testWidgets(
      '3f — os cantos de Limpar busca limpam a busca',
      (tester) => _comSemantica(tester, () async {
        for (var borda = 0; borda < 4; borda++) {
          await emBusca(tester);
          expect(find.text('Bia'), findsOneWidget);
          final area = _porNome(_alvos(tester), 'Limpar busca').area;
          expect(area.height, greaterThanOrEqualTo(_piso));
          expect(area.width, greaterThanOrEqualTo(_piso));
          await tester.tapAt(_bordas(area)[borda]);
          await assentar(tester);
          expect(
            tester.widget<TextField>(find.byType(TextField)).controller!.text,
            isEmpty,
            reason: 'borda $borda: o campo não esvaziou',
          );
          expect(
            find.text('Bia'),
            findsNothing,
            reason: 'borda $borda: os resultados sobreviveram ao limpar',
          );
        }
      }),
    );

    testWidgets(
      '3g — a borda da linha abre o Perfil daquele publicId',
      (tester) => _comSemantica(tester, () async {
        await comAmigos(tester);
        final linhas = _linhas(_alvos(tester));
        expect(linhas, hasLength(2));
        // A SEGUNDA linha, de propósito: se a navegação usasse índice fixo ou
        // o primeiro item, este caso passaria com o perfil errado.
        final area = linhas[1].area;
        // A borda ESQUERDA, longe do botão de ação, que mora à direita.
        await tester.tapAt(Offset(area.left + 1, area.center.dy));
        await assentar(tester);
        final pagina = tester.widget<PerfilPage>(find.byType(PerfilPage));
        expect(pagina.publicIdVisitado, 'P2');
        expect(pagina.ehMeuPerfil, isFalse);
      }),
    );

    testWidgets(
      '3h — a borda de Adicionar solicita amizade, com o publicId da busca',
      (tester) => _comSemantica(tester, () async {
        for (var borda = 0; borda < 4; borda++) {
          await emBusca(tester);
          final area = _porNome(_alvos(tester), 'Adicionar').area;
          expect(area.height, greaterThanOrEqualTo(_piso));
          await tester.tapAt(_bordas(area)[borda]);
          await assentar(tester);
          final acao = t.chamadas.lastWhere((c) => c.metodo == 'agir');
          expect(acao.acao, AcaoSocial.adicionarAmigo, reason: 'borda $borda');
          expect(acao.publicId, 'P9', reason: 'borda $borda');
        }
      }),
    );

    testWidgets(
      '3i — a borda de Cancelar cancela o pedido enviado',
      (tester) => _comSemantica(tester, () async {
        await emEnviadas(tester);
        final area = _porNome(_alvos(tester), 'Cancelar').area;
        expect(area.height, greaterThanOrEqualTo(_piso));
        await tester.tapAt(_bordas(area).first);
        await assentar(tester);
        final acao = t.chamadas.lastWhere((c) => c.metodo == 'agir');
        expect(acao.acao, AcaoSocial.cancelarSolicitacao);
        expect(acao.publicId, 'P4');
      }),
    );

    testWidgets(
      '3j — a borda de Tentar de novo relê a lista',
      (tester) => _comSemantica(tester, () async {
        await emFalhaDeLista(tester);
        final area = _porNome(_alvos(tester), 'Tentar de novo').area;
        expect(area.height, greaterThanOrEqualTo(_piso));
        t.falhaFixa = null;
        final antes = t.chamadasDe('listarOnline');
        await tester.tapAt(_bordas(area).last);
        await assentar(tester);
        expect(t.chamadasDe('listarOnline'), antes + 1);
      }),
    );

    testWidgets(
      '3k — a borda de Carregar mais pagina com o cursor',
      (tester) => _comSemantica(tester, () async {
        await comAmigos(tester);
        final area = _porNome(_alvos(tester), 'Carregar mais').area;
        expect(area.height, greaterThanOrEqualTo(_piso));
        await tester.tapAt(_bordas(area).first);
        await assentar(tester);
        final ultima = t.chamadas.lastWhere((c) => c.metodo == 'listarAmigos');
        expect(ultima.cursor, 'c1');
      }),
    );
  });

  // =========================================================================
  // 4 — Semântica preservada
  // =========================================================================
  group('4 — a semântica exemplar continua de pé', () {
    testWidgets(
      '4a — as abas continuam declarando papel e seleção',
      (tester) => _comSemantica(tester, () async {
        const rotulos = ['Online', 'Todos', 'Pedidos'];
        await comAmigos(tester);
        var alvos = _alvos(tester);
        expect(
          {for (final n in rotulos) n: _porNome(alvos, n).selecionado},
          {
            'Online': Tristate.isFalse,
            'Todos': Tristate.isTrue,
            'Pedidos': Tristate.isFalse,
          },
        );
        for (final n in rotulos) {
          expect(_porNome(alvos, n).ehBotao, isTrue);
        }

        await tester.tap(find.text('Pedidos'));
        await assentar(tester);
        alvos = _alvos(tester);
        expect(
          {for (final n in rotulos) n: _porNome(alvos, n).selecionado},
          {
            'Online': Tristate.isFalse,
            'Todos': Tristate.isFalse,
            'Pedidos': Tristate.isTrue,
          },
        );
      }),
    );

    testWidgets(
      '4b — as linhas continuam anunciadas por extenso, e o avatar continua fora',
      (tester) => _comSemantica(tester, () async {
        await emRecebidas(tester);
        final falas = _anuncios(tester).map((a) => a.nome).toList();
        expect(falas, ['Duda. Quer ser seu amigo. Toque para ver o perfil.']);
        // O avatar é decoração: nenhum nó fala o emoji dele.
        for (final no in _nos(tester)) {
          expect(no.fala, isNot(contains('🙂')));
        }
      }),
    );

    testWidgets(
      '4c — os botões continuam com papel de botão e habilitados',
      (tester) => _comSemantica(tester, () async {
        await emRecebidas(tester);
        for (final nome in ['Aceitar', 'Recusar', 'Voltar']) {
          final b = _porNome(_alvos(tester), nome);
          expect(b.ehBotao, isTrue, reason: '$b');
          expect(b.habilitado, isNot(Tristate.isFalse), reason: '$b');
        }
      }),
    );

    testWidgets(
      '4d — o campo de busca continua campo, com o tooltip de limpar',
      (tester) => _comSemantica(tester, () async {
        await emBusca(tester);
        final alvos = _alvos(tester);
        expect(alvos.where((a) => a.ehCampo), hasLength(1));
        expect(_porNome(alvos, 'Limpar busca').ehBotao, isTrue);
      }),
    );

    for (final cena in cenas.entries) {
      testWidgets(
        '4e — nenhum anúncio duplicado — ${cena.key}',
        (tester) => _comSemantica(tester, () async {
          await cena.value(tester);
          final alvos = _alvos(tester);
          // (a) Um controle, um nó: dois nós acionáveis no mesmo retângulo
          // são o mesmo botão anunciado duas vezes — o jeito mais fácil de
          // ampliar um alvo errado é embrulhá-lo num segundo `Semantics`.
          for (var i = 0; i < alvos.length; i++) {
            for (var j = i + 1; j < alvos.length; j++) {
              expect(
                alvos[i].area == alvos[j].area,
                isFalse,
                reason:
                    '${cena.key}: ${alvos[i]} e ${alvos[j]} são o mesmo alvo',
              );
            }
          }
          // (b) Nenhum nome repetido dentro da cena, tirando o botão de ação,
          // que se repete uma vez por linha.
          final vistos = <String>{};
          for (final n in alvos.map((a) => a.nome).where((n) => n.isNotEmpty)) {
            if (!vistos.add(n)) {
              expect(
                const ['Chamar pra jogar', 'Cancelar', 'Adicionar'],
                contains(n),
                reason: '${cena.key}: "$n" anunciado duas vezes',
              );
            }
          }
        }),
      );

      testWidgets(
        '4f — a ordem de foco desce a tela — ${cena.key}',
        (tester) => _comSemantica(tester, () async {
          await cena.value(tester);
          final alvos = _alvos(tester);
          for (var i = 1; i < alvos.length; i++) {
            final antes = alvos[i - 1].area;
            final agora = alvos[i].area;
            // Ou desce, ou é filho do anterior — o botão de ação, dentro da
            // linha, é a única exceção legítima desta tela.
            expect(
              agora.top >= antes.top - 0.5 || _contem(antes, agora),
              isTrue,
              reason: '${cena.key}: ${alvos[i]} vem depois de ${alvos[i - 1]}',
            );
          }
        }),
      );

      testWidgets(
        '4g — nenhum UID na árvore — ${cena.key}',
        (tester) => _comSemantica(tester, () async {
          await cena.value(tester);
          // O uid desta bancada é `uid-A`, e o formato do Firebase é um token
          // de 28 caracteres. Os dois são procurados: o literal pega a fuga
          // direta, e o formato pega a fuga de um uid real.
          final firebase = RegExp(r'\b[A-Za-z0-9]{28}\b');
          for (final no in _nos(tester)) {
            final fala = no.fala;
            expect(
              fala.toLowerCase(),
              isNot(contains('uid')),
              reason: '${cena.key}: $no',
            );
            expect(
              firebase.hasMatch(fala),
              isFalse,
              reason: '${cena.key}: $no',
            );
          }
        }),
      );
    }
  });

  // =========================================================================
  // 5 — Os estados continuam funcionais
  // =========================================================================
  group('5 — vazio, carregando, erro e conteúdo', () {
    testWidgets(
      '5a — vazio diz a frase da aba, e não desenha alvo de lista',
      (tester) => _comSemantica(tester, () async {
        await emVazio(tester);
        expect(find.text('Nenhum amigo online agora.'), findsOneWidget);
        expect(_linhas(_alvos(tester)), isEmpty);
      }),
    );

    testWidgets(
      '5b — carregando mostra o progresso',
      (tester) => _comSemantica(tester, () async {
        await emCarregamento(tester);
        expect(find.text('Carregando…'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsWidgets);
        // Sem isto o caso reprova por voo pendente, e a mensagem não diz isso.
        for (var i = 0; i < t.pendentes.length; i++) {
          if (!t.pendentes[i].isCompleted) t.responder(i, null);
        }
        await assentar(tester);
      }),
    );

    testWidgets(
      '5c — erro oferece Tentar de novo, no piso',
      (tester) => _comSemantica(tester, () async {
        await emFalhaDeLista(tester);
        expect(find.text('Não consegui carregar agora.'), findsOneWidget);
        final b = _porNome(_alvos(tester), 'Tentar de novo');
        expect(b.area.height, greaterThanOrEqualTo(_piso));
      }),
    );

    testWidgets(
      '5d — conteúdo continua desenhando quem o servidor mandou',
      (tester) => _comSemantica(tester, () async {
        await comAmigos(tester);
        expect(find.text('Bia'), findsOneWidget);
        expect(find.text('Caio'), findsOneWidget);
        expect(find.text('Carregar mais'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }),
    );

    testWidgets(
      '5e — fora do escopo diz o motivo, e o Voltar continua no piso',
      (tester) => _comSemantica(tester, () async {
        await foraDoEscopo(tester);
        expect(
          find.text('Amigos indisponível fora do aplicativo.'),
          findsOneWidget,
        );
        final voltar = _porNome(_alvos(tester), 'Voltar');
        expect(voltar.area.height, greaterThanOrEqualTo(_piso));
      }),
    );
  });
}
