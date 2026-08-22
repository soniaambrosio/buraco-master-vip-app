// saneamento_recompensa_treino_test.dart — a Mesa de Treino nao promete fichas.
//
// ---------------------------------------------------------------------------
// O QUE ESTA SUITE GUARDA
// ---------------------------------------------------------------------------
//
// A tela de Resultado da Mesa de Treino oferecia um cartao de midia recompensada
// que anunciava credito na carteira pela continuidade da partida. Nenhum credito
// existia: a carteira canonica (`usuarios/{uid}`) so aceita escrita do servidor,
// e o Treino, por decisao registrada, nao movimenta economia. Era maquete
// apresentada como produto.
//
// A promessa saiu inteira — rotulo, estado, botao e callback. Esta suite existe
// para que ela nao volte por descuido nem por composicao de outra linhagem.
//
// TRES BLOCOS, E POR QUE SAO TRES
//
//   SAN — comportamento: a tela e montada de verdade e a ARVORE SEMANTICA e
//         percorrida. Afirmar contra `find.text` nao basta: um rotulo escondido
//         do desenho e presente na leitura de tela continua sendo a promessa, e
//         so a arvore semantica separa as duas coisas.
//   CON — comportamento: o que a OS manda preservar continua funcionando, e
//         aciona o callback certo UMA vez. Sem este bloco, apagar a tela inteira
//         passaria no bloco SAN.
//   EST — estrutura: o vocabulario do falso fluxo nao volta ao codigo das
//         superficies do Treino, e nenhuma dependencia publicitaria entra no
//         projeto. Busca textual sozinha nao prova nada — ela esta aqui como
//         SEGUNDA metade, para alcancar o que o comportamento nao alcanca:
//         codigo morto que compila e dependencia declarada e ainda nao usada.
//
// A varredura de EST le o codigo SEM as linhas de comentario. Um comentario que
// explica uma remocao contem, por necessidade, as palavras removidas; varrer o
// arquivo cru faria a nota desta suite reprovar a propria suite.

import 'dart:io';

import 'package:buraco_master_vip/screens/resultado_partida_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import '../superficie_de_teste.dart';

// --- fixture -----------------------------------------------------------------

const _det = DetalhePontuacaoVM(
  total: 120,
  canastras: 1,
  cartasBaixadas: 40,
  bonusBatida: 100,
  descontoMao: 0,
  penalidadeMorto: 0,
  limpas: 1,
  sujas: 0,
  de500: 0,
  de1000: 0,
);

const _jogadores = <JogadorResultadoVM>[
  JogadorResultadoVM(assento: 0, nome: 'Voce', avatar: '@', souEu: true),
  JogadorResultadoVM(assento: 1, nome: 'Rita', avatar: 'R'),
  JogadorResultadoVM(assento: 2, nome: 'Ana', avatar: 'A'),
  JogadorResultadoVM(assento: 3, nome: 'Leo', avatar: 'L'),
];

/// Registro do que cada callback recebeu. Serve tambem para provar o NEGATIVO:
/// montar a tela nao pode acionar nada sozinho.
class _Efeitos {
  int continuar = 0;
  int revanche = 0;
  int jogarNovamente = 0;
  int voltarLobby = 0;
  final List<int> amigos = <int>[];

  int get total =>
      continuar + revanche + jogarNovamente + voltarLobby + amigos.length;
}

Widget _resultado(
  _Efeitos e, {
  bool fimPartida = true,
  bool conviteEnviado = false,
}) =>
    MaterialApp(
      home: ResultadoPartidaScreen(
        fimPartida: fimPartida,
        mesaVip: false,
        rodada: 3,
        titulo: 'NOS VENCEMOS!',
        pontosNos: 3010,
        pontosEles: 1240,
        detalheNos: _det,
        detalheEles: _det,
        jogadores: _jogadores,
        amizades: const <int, EstadoAmizade>{},
        conviteRevancheEnviado: conviteEnviado,
        onContinuar: () => e.continuar++,
        onConvidarRevanche: () => e.revanche++,
        onJogarNovamente: () => e.jogarNovamente++,
        onVoltarLobby: () => e.voltarLobby++,
        onAdicionarAmigo: e.amigos.add,
      ),
    );

/// Monta a tela com a arvore semantica ligada e entrega os nos ao corpo.
///
/// O `handle` e descartado no `finally` do CORPO, e nao por `addTearDown`: o
/// `flutter_test` confere os handles ANTES dos tearDowns, e registrado la o
/// descarte chega tarde e reprova todos os casos do arquivo.
Future<void> _lendoOResultado(
  WidgetTester t,
  _Efeitos e,
  Future<void> Function(List<SemanticsNode> nos) corpo, {
  bool fimPartida = true,
  bool conviteEnviado = false,
}) async {
  usarTelefoneRetrato(t);
  ignorarOverflowDaFonteDeTeste();
  final h = t.ensureSemantics();
  try {
    await t.pumpWidget(_resultado(
      e,
      fimPartida: fimPartida,
      conviteEnviado: conviteEnviado,
    ));
    await t.pump();
    final nos = <SemanticsNode>[];
    void andar(SemanticsNode n) {
      nos.add(n);
      n.visitChildren((f) {
        andar(f);
        return true;
      });
    }

    // A partir do no da PROPRIA tela, e nao da raiz do binding: `pipelineOwner`
    // esta depreciado, e ancorar no widget sob teste tambem deixa de arrastar
    // decoracao do `MaterialApp` para dentro da medicao.
    andar(t.getSemantics(find.byType(ResultadoPartidaScreen)));
    await corpo(nos);
  } finally {
    h.dispose();
  }
}

List<String> _rotulos(List<SemanticsNode> nos) => nos
    .map((n) => n.getSemanticsData().label)
    .where((s) => s.isNotEmpty)
    .toList();

/// Toda a fala da tela num texto so — rotulo, valor e dica.
String _fala(List<SemanticsNode> nos) => nos.map((n) {
      final d = n.getSemanticsData();
      return '${d.label} ${d.value} ${d.hint}';
    }).join(' ');

// --- vocabulario proibido -----------------------------------------------------

/// O que nenhuma superficie do Treino pode dizer nem conter.
///
/// Nao inclui "sem anuncios" de outras telas: a Loja vende ausencia de
/// publicidade como beneficio real da assinatura, e isso e texto legitimo. O
/// que esta proibido aqui e PROMETER CREDITO e oferecer o gesto que
/// supostamente o concede.
const _promessasProibidas = <String>[
  'fichas de continuidade',
  '+50',
  '50 fichas',
  'Recompensa recebida',
  'recompensa registrada',
  'Ver anuncio',
  'Ver anúncio',
  'ASSISTIR',
  'RECEBIDO',
];

/// Simbolos do falso fluxo. Se qualquer um reaparecer no CODIGO das superficies
/// do Treino, o gesto voltou junto.
const _simbolosProibidos = <String>[
  'anuncioDisponivel',
  'anuncioAssistido',
  'assinanteSemAnuncios',
  'recompensaAnuncio',
  'onVerAnuncio',
  '_verAnuncioRecompensado',
  '_anuncioRecompensado',
];

/// Pacotes de publicidade e de consentimento publicitario.
const _dependenciasProibidas = <String>[
  'google_mobile_ads',
  'admob',
  'applovin',
  'unity_ads',
  'ironsource',
  'facebook_audience',
  'user_messaging_platform',
];

const _telaResultado = 'lib/screens/resultado_partida_screen.dart';
const _mesaTreino = 'lib/mesa.dart';
const _celebracao = 'lib/screens/resultado_partida_celebrado.dart';

File _arquivo(String caminho) {
  final f = File(caminho);
  if (!f.existsSync()) {
    fail('arquivo obrigatorio ausente: $caminho — esta suite nao pode passar '
        'quando o alvo dela some');
  }
  return f;
}

/// O conteudo do arquivo sem as linhas de comentario.
///
/// Uma nota que explica uma remocao cita o que foi removido; varrer o arquivo
/// cru transformaria documentacao honesta em reprovacao. Quem reintroduzir a
/// promessa vai faze-lo em CODIGO, e e o codigo que esta varredura le.
String _codigoSemComentarios(String caminho) => _arquivo(caminho)
    .readAsLinesSync()
    .where((l) => !l.trimLeft().startsWith('//'))
    .join('\n');

void main() {
  // =========================================================================
  group('SAN — a promessa economica saiu da tela de Resultado', () {
    testWidgets('SAN-01 nenhum rotulo semantico fala em fichas', (t) async {
      final e = _Efeitos();
      await _lendoOResultado(t, e, (nos) async {
        expect(_fala(nos).toLowerCase(), isNot(contains('fichas')));
      });
    });

    testWidgets('SAN-02 nenhum rotulo semantico fala em anuncio', (t) async {
      final e = _Efeitos();
      await _lendoOResultado(t, e, (nos) async {
        final fala = _fala(nos).toLowerCase();
        expect(fala, isNot(contains('anuncio')));
        expect(fala, isNot(contains('anúncio')));
      });
    });

    testWidgets('SAN-03 nenhum rotulo semantico declara recompensa', (t) async {
      final e = _Efeitos();
      await _lendoOResultado(t, e, (nos) async {
        expect(_fala(nos).toLowerCase(), isNot(contains('recompensa')));
      });
    });

    testWidgets('SAN-04 nenhuma promessa proibida na fala da tela', (t) async {
      final e = _Efeitos();
      await _lendoOResultado(t, e, (nos) async {
        final fala = _fala(nos);
        for (final p in _promessasProibidas) {
          expect(fala, isNot(contains(p)), reason: 'a tela voltou a dizer "$p"');
        }
      });
    });

    testWidgets('SAN-05 nenhum botao oferece o gesto do anuncio', (t) async {
      final e = _Efeitos();
      await _lendoOResultado(t, e, (nos) async {
        final botoes = nos
            .where((n) => n.getSemanticsData().flagsCollection.isButton)
            .map((n) => n.getSemanticsData().label)
            .toList();
        expect(botoes, isNotEmpty, reason: 'a tela perdeu todos os botoes');
        for (final b in botoes) {
          expect(
            b,
            isNot(anyOf(
              equals('ASSISTIR'),
              equals('RECEBIDO'),
              equals('INDISPONIVEL'),
              equals('INDISPONÍVEL'),
            )),
          );
        }
      });
    });

    testWidgets('SAN-06 a LISTA EXATA de rotulos e a esperada', (t) async {
      // Lista exata, e nao `contains`: um `contains` deixa passar rotulo que
      // VOLTOU, e um "nao contem" deixa passar informacao que se PERDEU. So a
      // igualdade fecha as duas portas de uma vez.
      final e = _Efeitos();
      await _lendoOResultado(t, e, (nos) async {
        expect(_rotulos(nos), <String>[
          'FIM DE PARTIDA',
          'NOS VENCEMOS!',
          'NÓS',
          '3010',
          'ELES',
          '1240',
          'NÓS',
          '+120',
          'Canastras',
          '+1',
          'Cartas baixadas',
          '+40',
          'Batida',
          '+100',
          'LIMPA 1',
          'ELES',
          '+120',
          'Canastras',
          '+1',
          'Cartas baixadas',
          '+40',
          'Batida',
          '+100',
          'LIMPA 1',
          'Vamos jogar?',
          'Convide a mesa inteira para uma revanche.',
          'CONVIDAR',
          'JOGADORES DA MESA',
          'R\nRita',
          '+ AMIGO',
          'A\nAna',
          '+ AMIGO',
          'L\nLeo',
          '+ AMIGO',
          'VAMOS JOGAR?',
          'VOLTAR AO LOBBY',
        ]);
      });
    });

    testWidgets('SAN-07 o texto DESENHADO tambem nao promete', (t) async {
      // Leitura de tela e pintura sao superficies diferentes: uma promessa pode
      // sair de uma e ficar na outra.
      final e = _Efeitos();
      await _lendoOResultado(t, e, (nos) async {
        final desenhado = t
            .widgetList<Text>(find.byType(Text))
            .map((w) => w.data ?? '')
            .join(' ');
        for (final p in _promessasProibidas) {
          expect(desenhado, isNot(contains(p)),
              reason: 'a tela voltou a DESENHAR "$p"');
        }
      });
    });
  });

  // =========================================================================
  group('CON — a continuidade normal do Treino permanece', () {
    testWidgets('CON-01 montar a tela nao aciona callback nenhum', (t) async {
      final e = _Efeitos();
      await _lendoOResultado(t, e, (nos) async {
        expect(e.total, 0, reason: 'a tela agiu sozinha, sem toque');
      });
    });

    // O botao principal tem DOIS papeis, e confundi-los faz o teste medir a
    // acao errada: antes de o convite sair ele diz "VAMOS JOGAR?" e convida a
    // mesa; depois ele vira "JOGAR NOVAMENTE" e reinicia a partida. Os dois
    // estados sao continuidade, e os dois precisam de prova.
    testWidgets('CON-02 antes do convite, o botao principal CONVIDA', (t) async {
      final e = _Efeitos();
      await _lendoOResultado(t, e, (nos) async {
        expect(find.text('JOGAR NOVAMENTE'), findsNothing);
        await t.tap(find.text('VAMOS JOGAR?'));
        await t.pump();
        expect(e.revanche, 1);
        expect(e.total, 1, reason: 'o toque acionou mais de uma coisa');
      });
    });

    testWidgets('CON-02b depois do convite, ele JOGA NOVAMENTE UMA vez',
        (t) async {
      final e = _Efeitos();
      await _lendoOResultado(t, e, (nos) async {
        await t.tap(find.text('JOGAR NOVAMENTE'));
        await t.pump();
        expect(e.jogarNovamente, 1);
        expect(e.total, 1, reason: 'o toque acionou mais de uma coisa');
      }, conviteEnviado: true);
    });

    testWidgets('CON-03 "VOLTAR AO LOBBY" aciona a saida UMA vez', (t) async {
      final e = _Efeitos();
      await _lendoOResultado(t, e, (nos) async {
        await t.tap(find.text('VOLTAR AO LOBBY'));
        await t.pump();
        expect(e.voltarLobby, 1);
        expect(e.total, 1);
      });
    });

    testWidgets('CON-04 "CONVIDAR" aciona a revanche UMA vez', (t) async {
      final e = _Efeitos();
      await _lendoOResultado(t, e, (nos) async {
        await t.tap(find.text('CONVIDAR'));
        await t.pump();
        expect(e.revanche, 1);
        expect(e.total, 1);
      });
    });

    testWidgets('CON-05 "+ AMIGO" leva o assento certo', (t) async {
      final e = _Efeitos();
      await _lendoOResultado(t, e, (nos) async {
        await t.tap(find.text('+ AMIGO').first);
        await t.pump();
        expect(e.amigos, <int>[1]);
        expect(e.total, 1);
      });
    });

    testWidgets('CON-06 fim de rodada mantem "PROXIMA RODADA"', (t) async {
      final e = _Efeitos();
      await _lendoOResultado(t, e, (nos) async {
        expect(find.text('PRÓXIMA RODADA'), findsOneWidget);
        await t.tap(find.text('PRÓXIMA RODADA'));
        await t.pump();
        expect(e.continuar, 1);
        expect(e.total, 1);
      }, fimPartida: false);
    });

    testWidgets('CON-07 o placar e o detalhamento continuam na tela', (t) async {
      final e = _Efeitos();
      await _lendoOResultado(t, e, (nos) async {
        final fala = _fala(nos);
        for (final v in <String>['3010', '1240', 'Canastras', 'Batida']) {
          expect(fala, contains(v), reason: 'o resultado perdeu "$v"');
        }
      });
    });
  });

  // =========================================================================
  group('EST — o falso fluxo nao volta pelo codigo nem por dependencia', () {
    test('EST-01 a tela de Resultado nao contem simbolo do falso fluxo', () {
      final src = _codigoSemComentarios(_telaResultado);
      for (final s in _simbolosProibidos) {
        expect(src, isNot(contains(s)), reason: '"$s" voltou ao codigo da tela');
      }
    });

    test('EST-02 a Mesa de Treino nao contem simbolo do falso fluxo', () {
      final src = _codigoSemComentarios(_mesaTreino);
      for (final s in _simbolosProibidos) {
        expect(src, isNot(contains(s)), reason: '"$s" voltou ao codigo da mesa');
      }
    });

    test('EST-03 nenhuma promessa literal no codigo das superficies', () {
      for (final caminho in <String>[_telaResultado, _mesaTreino, _celebracao]) {
        final src = _codigoSemComentarios(caminho);
        for (final p in _promessasProibidas) {
          expect(src, isNot(contains(p)),
              reason: '"$p" voltou ao codigo de $caminho');
        }
      }
    });

    test('EST-04 o Treino nao alcanca carteira nem economia', () {
      final src = _codigoSemComentarios(_mesaTreino);
      for (final s in <String>[
        'httpsCallable',
        'FirebaseFirestore',
        'creditar',
        'carteira',
      ]) {
        expect(src, isNot(contains(s)),
            reason: 'o Treino passou a falar com "$s" — economia no Treino '
                'exige OS propria');
      }
    });

    test('EST-05 nenhuma dependencia publicitaria no pubspec', () {
      final src = _arquivo('pubspec.yaml').readAsStringSync().toLowerCase();
      for (final d in _dependenciasProibidas) {
        expect(src, isNot(contains(d)), reason: 'dependencia "$d" declarada');
      }
    });

    test('EST-06 nenhum metadata publicitario no manifesto Android', () {
      final dir = Directory('android');
      if (!dir.existsSync()) return;
      for (final f in dir.listSync(recursive: true).whereType<File>()) {
        if (!f.path.endsWith('AndroidManifest.xml')) continue;
        final src = f.readAsStringSync().toLowerCase();
        for (final d in <String>['com.google.android.gms.ads', 'admob']) {
          expect(src, isNot(contains(d)),
              reason: 'configuracao de anuncio em ${f.path}');
        }
      }
    });

    test('EST-07 a suite ainda aponta para os arquivos que ela guarda', () {
      // Se alguem renomear a tela ou a mesa, esta suite passaria a guardar nada
      // e continuaria verde. Ela reprova em vez de emudecer.
      for (final caminho in <String>[_telaResultado, _mesaTreino, _celebracao]) {
        expect(File(caminho).existsSync(), isTrue,
            reason: 'alvo desta suite sumiu: $caminho');
      }
      expect(_codigoSemComentarios(_telaResultado), contains('_acoesFinais'),
          reason: 'a tela de Resultado perdeu as acoes finais');
      expect(_codigoSemComentarios(_mesaTreino), contains('_jogarNovamente'),
          reason: 'a Mesa de Treino perdeu o jogar novamente');
    });
  });
}
