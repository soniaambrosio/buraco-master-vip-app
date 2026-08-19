// acessibilidade_configuracoes_test.dart — o portão dos controles de Ajustes.
//
// ---------------------------------------------------------------------------
// O QUE ESTE ARQUIVO FIXA, E POR QUE ELE OLHA A ÁRVORE E NÃO OS WIDGETS
// ---------------------------------------------------------------------------
//
// Um teste que procurasse `find.byType(Switch)` diria que esta tela sempre
// esteve certa: os nove interruptores estavam lá, no lugar, com o valor certo.
// O defeito não era a falta de um widget, era a FORMA da árvore de
// acessibilidade que eles produziam — e essa forma só se vê olhando os
// `SemanticsNode`.
//
// Antes desta entrega, cada preferência chegava ao leitor de tela partida em
// dois controles concorrentes: o texto, tocável, sem estado; e o `Switch`, com
// estado, sem nome. Dezoito paradas para nove preferências, metade delas
// anônimas — inclusive as de PRIVACIDADE, onde a pessoa alternava quem pode
// falar com ela sem ouvir o que estava alternando.
//
// Por isso as asserções aqui são sobre nós: quantos existem, que nome têm, que
// estado carregam e que ação aceitam. É o mesmo tipo de prova que a auditoria
// de acessibilidade usou para acusar o defeito — agora do lado de cá,
// impedindo que ele volte.
//
// Boa parte da varredura corre a árvore inteira a partir da raiz, sem saber
// quantos controles a tela tem nem onde eles estão: quem responde é a árvore.
// Um controle novo que nasça sem nome é acusado sem ninguém precisar lembrar
// de acrescentá-lo a uma lista aqui.

import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:buraco_master_vip/screens/configuracoes_screen.dart';

// ---------------------------------------------------------------------------
// AS NOVE PREFERÊNCIAS DE LIGA/DESLIGA
// ---------------------------------------------------------------------------
//
// São nove, e não dez: `Configuracoes` tem exatamente nove campos `bool`. A
// décima linha que a auditoria contou como interruptor é "Quem pode me
// convidar", que é uma escolha entre três valores — coberta mais abaixo, no
// grupo da folha de escolha.

@immutable
class _Preferencia {
  const _Preferencia(this.titulo, this.subtitulo, this.ler);

  final String titulo;
  final String subtitulo;
  final bool Function(Configuracoes) ler;

  /// O nome que o leitor de tela deve anunciar para este controle.
  String get rotulo => '$titulo. $subtitulo';

  @override
  String toString() => titulo;
}

bool _lerMusica(Configuracoes c) => c.musica;
bool _lerEfeitos(Configuracoes c) => c.efeitosSonoros;
bool _lerVibracao(Configuracoes c) => c.vibracao;
bool _lerNotificacoes(Configuracoes c) => c.notificacoes;
bool _lerAnimacoes(Configuracoes c) => c.animacoes;
bool _lerOrdenar(Configuracoes c) => c.ordenarCartasAuto;
bool _lerConfirmar(Configuracoes c) => c.confirmarDescarte;
bool _lerChatMaiores(Configuracoes c) => c.chatPublicoSoMaiores;
bool _lerMostrarOnline(Configuracoes c) => c.mostrarOnline;

const _preferencias = <_Preferencia>[
  _Preferencia('Música', 'Trilha musical do aplicativo', _lerMusica),
  _Preferencia(
    'Efeitos sonoros',
    'Cartas, canastras e avisos da mesa',
    _lerEfeitos,
  ),
  _Preferencia('Vibração', 'Avisar quando chegar a sua vez', _lerVibracao),
  _Preferencia(
    'Notificações',
    'Convites, recompensas e novidades',
    _lerNotificacoes,
  ),
  _Preferencia('Animações', 'Movimentos e celebrações visuais', _lerAnimacoes),
  _Preferencia(
    'Ordenar cartas automaticamente',
    'Organiza a mão por naipe e valor',
    _lerOrdenar,
  ),
  _Preferencia(
    'Confirmar antes de descartar',
    'Evita descarte por toque acidental',
    _lerConfirmar,
  ),
  _Preferencia(
    'Chat público só para maiores',
    'Restringe o acesso conforme a conta',
    _lerChatMaiores,
  ),
  _Preferencia(
    'Mostrar quando estou online',
    'Amigos poderão ver sua presença',
    _lerMostrarOnline,
  ),
];

/// Os títulos das seções. Eles são texto de organização, não controles: se um
/// deles aparecer dentro do nome de algo acionável, é porque a fronteira
/// semântica daquele controle vazou para o nó de cima.
const _titulosDeSecao = <String>[
  'CONTA',
  'SOM E NOTIFICAÇÕES',
  'JOGO',
  'PRIVACIDADE',
  'GERAL',
];

const _padrao = Configuracoes(versaoApp: '1.0.0');

const _tudoLigado = Configuracoes(
  musica: true,
  efeitosSonoros: true,
  vibracao: true,
  notificacoes: true,
  animacoes: true,
  ordenarCartasAuto: true,
  confirmarDescarte: true,
  chatPublicoSoMaiores: true,
  mostrarOnline: true,
  versaoApp: '1.0.0',
);

const _tudoDesligado = Configuracoes(
  musica: false,
  efeitosSonoros: false,
  vibracao: false,
  notificacoes: false,
  animacoes: false,
  ordenarCartasAuto: false,
  confirmarDescarte: false,
  chatPublicoSoMaiores: false,
  mostrarOnline: false,
  versaoApp: '1.0.0',
);

Tristate _comoMarca(bool ligado) => ligado ? Tristate.isTrue : Tristate.isFalse;

// ---------------------------------------------------------------------------
// BANCADA
// ---------------------------------------------------------------------------

class _Bancada {
  final List<Configuracoes> alteracoes = <Configuracoes>[];
  final List<String> visitas = <String>[];
  int voltas = 0;
}

/// Monta a tela numa superfície ALTA de propósito.
///
/// O telefone de verdade tem 800 de altura e a lista rola; aqui ela cabe
/// inteira, e é isso que se quer: fora da viewport o Flutter nem constrói os
/// nós, e uma varredura que só enxerga metade da tela dá um verde que não
/// significa nada. A largura continua a de um telefone, que é o que decide o
/// layout das linhas.
Future<_Bancada> _montar(
  WidgetTester tester, {
  Configuracoes config = _padrao,
}) async {
  tester.view.physicalSize = const Size(1080, 6000);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final bancada = _Bancada();

  await tester.pumpWidget(
    MaterialApp(
      home: ConfiguracoesScreen(
        perfil: const PerfilResumo(
          apelido: 'Ana',
          email: '',
          vip: false,
          moedas: null,
        ),
        config: config,
        onVoltar: () => bancada.voltas++,
        callbacks: ConfiguracoesCallbacks(
          onAlterar: bancada.alteracoes.add,
          onEditarPerfil: () => bancada.visitas.add('editar-perfil'),
          onAssinaturaVip: () => bancada.visitas.add('vip'),
          onMoedasCompras: () => bancada.visitas.add('moedas'),
          onBloqueados: () => bancada.visitas.add('bloqueados'),
          onRegras: () => bancada.visitas.add('regras'),
          onSuporte: () => bancada.visitas.add('suporte'),
          onTermos: () => bancada.visitas.add('termos'),
          onAvaliar: () => bancada.visitas.add('avaliar'),
          onSair: () => bancada.visitas.add('sair'),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return bancada;
}

// ---------------------------------------------------------------------------
// VARREDURA DA ÁRVORE
// ---------------------------------------------------------------------------

/// A raiz da árvore semântica viva, alcançada subindo a partir do aplicativo.
///
/// O ponto de partida tem de ser o `MaterialApp`, e não a tela: com a folha de
/// escolha aberta, o Flutter tira a rota de baixo da árvore de acessibilidade
/// inteira — é o que impede o leitor de tela de passear pelo que está atrás de
/// um modal. Subindo a partir de `ConfiguracoesScreen` chega-se à raiz da
/// subárvore JÁ DESCARTADA, que ainda existe em memória e ainda responde: a
/// varredura devolveria a tela de trás intacta e nenhuma opção da folha, e o
/// teste acusaria "a folha não abriu" quando ela abriu.
SemanticsNode _raiz(WidgetTester tester) {
  var no = tester.getSemantics(find.byType(MaterialApp));
  while (no.parent != null) {
    no = no.parent!;
  }
  return no;
}

List<SemanticsNode> _todosOsNos(WidgetTester tester) {
  final encontrados = <SemanticsNode>[];
  void visitar(SemanticsNode no) {
    encontrados.add(no);
    no.visitChildren((filho) {
      visitar(filho);
      return true;
    });
  }

  visitar(_raiz(tester));
  return encontrados;
}

/// O nome que o leitor de tela realmente anuncia.
///
/// Não é só `label`: um `IconButton` com `tooltip` — o botão de voltar desta
/// tela — carrega o nome em `tooltip`, e as plataformas anunciam esse campo.
/// Acusar esse botão de anônimo seria um falso positivo, e um que empurraria
/// alguém a "consertar" o que já está certo.
String _nomeAcessivel(SemanticsNode no) {
  final d = no.getSemanticsData();
  return d.label.trim().isNotEmpty ? d.label.trim() : d.tooltip.trim();
}

bool _acionavel(SemanticsNode no) =>
    no.getSemanticsData().hasAction(SemanticsAction.tap);

/// `Tristate.none` quer dizer "isto não é um controle de liga/desliga" — o que
/// é diferente de estar desligado, e é justamente a diferença que o leitor de
/// tela precisa ouvir.
Tristate _alternancia(SemanticsNode no) =>
    no.getSemanticsData().flagsCollection.isToggled;

/// `Tristate.none` aqui quer dizer "isto não é uma opção que se escolhe" — que
/// era como as três opções da folha chegavam antes, todas iguais entre si.
Tristate _selecao(SemanticsNode no) =>
    no.getSemanticsData().flagsCollection.isSelected;

bool _ehBotao(SemanticsNode no) =>
    no.getSemanticsData().flagsCollection.isButton;

List<SemanticsNode> _nosComRotulo(WidgetTester tester, String rotulo) =>
    _todosOsNos(
      tester,
    ).where((no) => no.getSemanticsData().label == rotulo).toList();

SemanticsNode _noUnico(WidgetTester tester, String rotulo) {
  final achados = _nosComRotulo(tester, rotulo);
  expect(
    achados,
    hasLength(1),
    reason: 'esperava UM nó chamado "$rotulo", achei ${achados.length}',
  );
  return achados.single;
}

List<String> _rotulosSelecionados(WidgetTester tester) => _todosOsNos(tester)
    .where((no) => _selecao(no) == Tristate.isTrue)
    .map((no) => no.getSemanticsData().label)
    .toList();

/// Aciona pelo canal de acessibilidade — não pelo dedo.
///
/// É a diferença que importa aqui: `tester.tap` prova que a área é tocável, e
/// isso nunca esteve em questão. O que estava quebrado era o caminho que o
/// leitor de tela usa, e é esse que precisa ser exercido.
Future<void> _acionar(
  WidgetTester tester,
  SemanticsNode no, [
  SemanticsAction acao = SemanticsAction.tap,
]) async {
  no.owner!.performAction(no.id, acao);
  await tester.pumpAndSettle();
}

void main() {
  // -------------------------------------------------------------------------
  group('cada preferência é UM controle com nome, estado e ação', () {
    testWidgets('as nove têm nome, e o nome é único na árvore', (tester) async {
      final handle = tester.ensureSemantics();
      await _montar(tester);

      for (final p in _preferencias) {
        expect(
          _nomeAcessivel(_noUnico(tester, p.rotulo)),
          isNotEmpty,
          reason: '${p.titulo}: controle sem nome',
        );
      }

      handle.dispose();
    });

    testWidgets('as nove aceitam a ação de alternar', (tester) async {
      final handle = tester.ensureSemantics();
      await _montar(tester);

      for (final p in _preferencias) {
        expect(
          _acionavel(_noUnico(tester, p.rotulo)),
          isTrue,
          reason: '${p.titulo}: o nó não aceita a ação de alternar',
        );
      }

      handle.dispose();
    });

    testWidgets('as nove anunciam que ligam e desligam', (tester) async {
      final handle = tester.ensureSemantics();
      await _montar(tester);

      for (final p in _preferencias) {
        expect(
          _alternancia(_noUnico(tester, p.rotulo)),
          isNot(Tristate.none),
          reason: '${p.titulo}: o nó não se apresenta como liga/desliga',
        );
      }

      handle.dispose();
    });

    testWidgets('com tudo ligado, as nove saem ligadas', (tester) async {
      final handle = tester.ensureSemantics();
      await _montar(tester, config: _tudoLigado);

      for (final p in _preferencias) {
        expect(
          _alternancia(_noUnico(tester, p.rotulo)),
          equals(_comoMarca(p.ler(_tudoLigado))),
          reason: '${p.titulo}: o estado anunciado não é o da tela',
        );
      }

      handle.dispose();
    });

    testWidgets('com tudo desligado, as nove saem desligadas', (tester) async {
      final handle = tester.ensureSemantics();
      await _montar(tester, config: _tudoDesligado);

      for (final p in _preferencias) {
        expect(
          _alternancia(_noUnico(tester, p.rotulo)),
          equals(_comoMarca(p.ler(_tudoDesligado))),
          reason: '${p.titulo}: o estado anunciado não é o da tela',
        );
      }

      handle.dispose();
    });

    // Um estado que fosse constante `true` passaria em "tudo ligado" e seria
    // pego em "tudo desligado". Um estado que copiasse o campo do VIZINHO passa
    // nos dois. Aqui cada nó é conferido contra o seu próprio campo num pump em
    // que ligados e desligados convivem — que é como a tela abre de fábrica.
    testWidgets('no estado padrão, cada nó espelha o seu próprio campo', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _montar(tester, config: _padrao);

      for (final p in _preferencias) {
        expect(
          _alternancia(_noUnico(tester, p.rotulo)),
          equals(_comoMarca(p.ler(_padrao))),
          reason: '${p.titulo}: o estado anunciado não é o da tela',
        );
      }

      // E a mistura existe de verdade: sem isto, o laço acima seria satisfeito
      // por qualquer constante.
      expect(
        _preferencias.map((p) => p.ler(_padrao)).toSet(),
        containsAll(<bool>[true, false]),
        reason: 'o padrão deixou de misturar ligados e desligados',
      );

      handle.dispose();
    });
  });

  // -------------------------------------------------------------------------
  group('alternar pelo canal do leitor de tela', () {
    testWidgets('cada uma das nove alterna só a si mesma', (tester) async {
      for (final p in _preferencias) {
        final handle = tester.ensureSemantics();
        final bancada = await _montar(tester, config: _padrao);

        await _acionar(tester, _noUnico(tester, p.rotulo));

        expect(
          bancada.alteracoes,
          hasLength(1),
          reason: '${p.titulo}: esperava UMA alteração',
        );
        final depois = bancada.alteracoes.single;
        expect(
          p.ler(depois),
          equals(!p.ler(_padrao)),
          reason: '${p.titulo}: a preferência não inverteu',
        );
        for (final outra in _preferencias) {
          if (identical(outra, p)) continue;
          expect(
            outra.ler(depois),
            equals(outra.ler(_padrao)),
            reason: '${p.titulo} alternou também ${outra.titulo}',
          );
        }

        handle.dispose();
      }
    });

    // As de PRIVACIDADE, nomeadas. Elas são o motivo de a auditoria ter
    // classificado isto como P0: alternar sem saber o que se alterna é ruim em
    // qualquer lugar, e aqui o que se alterna é com quem a pessoa fala e quem
    // sabe que ela está online.
    testWidgets('"Mostrar quando estou online" alterna só a presença', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final bancada = await _montar(tester, config: _tudoLigado);

      await _acionar(
        tester,
        _noUnico(
          tester,
          'Mostrar quando estou online. Amigos poderão ver sua presença',
        ),
      );

      expect(bancada.alteracoes, hasLength(1));
      expect(bancada.alteracoes.single.mostrarOnline, isFalse);
      expect(bancada.alteracoes.single.chatPublicoSoMaiores, isTrue);
      expect(
        bancada.alteracoes.single.quemMeConvida,
        equals(_tudoLigado.quemMeConvida),
      );

      handle.dispose();
    });

    testWidgets('"Chat público só para maiores" alterna só o chat', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final bancada = await _montar(tester, config: _tudoLigado);

      await _acionar(
        tester,
        _noUnico(
          tester,
          'Chat público só para maiores. Restringe o acesso conforme a conta',
        ),
      );

      expect(bancada.alteracoes, hasLength(1));
      expect(bancada.alteracoes.single.chatPublicoSoMaiores, isFalse);
      expect(bancada.alteracoes.single.mostrarOnline, isTrue);

      handle.dispose();
    });

    testWidgets('"Quem pode me convidar" se anuncia com o valor que vale', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _montar(
        tester,
        config: const Configuracoes(
          quemMeConvida: QuemMeConvida.ninguem,
          versaoApp: '1.0.0',
        ),
      );

      final no = _noUnico(tester, 'Quem pode me convidar. Ninguém');
      expect(_acionavel(no), isTrue);
      expect(_ehBotao(no), isTrue);

      handle.dispose();
    });
  });

  // -------------------------------------------------------------------------
  group('a árvore inteira, sem lista de controles conhecidos', () {
    testWidgets('nenhum nó acionável fica sem nome', (tester) async {
      final handle = tester.ensureSemantics();
      await _montar(tester);

      final anonimos = _todosOsNos(tester)
          .where(_acionavel)
          .where((no) => _nomeAcessivel(no).isEmpty)
          .toList();

      expect(
        anonimos,
        isEmpty,
        reason:
            'controles acionáveis sem nome, em '
            '${anonimos.map((no) => no.rect).join(", ")}',
      );

      handle.dispose();
    });

    testWidgets('há exatamente nove nós de liga/desliga', (tester) async {
      final handle = tester.ensureSemantics();
      await _montar(tester);

      final alternaveis = _todosOsNos(
        tester,
      ).where((no) => _alternancia(no) != Tristate.none).toList();

      // Dezoito seria o `Switch` de volta como nó irmão do texto; oito, uma
      // preferência que sumiu da árvore.
      expect(
        alternaveis,
        hasLength(_preferencias.length),
        reason:
            'nós de liga/desliga encontrados: '
            '${alternaveis.map((no) => '"${no.getSemanticsData().label}"').join(", ")}',
      );

      handle.dispose();
    });

    testWidgets('nenhum título de seção gruda num controle', (tester) async {
      final handle = tester.ensureSemantics();
      await _montar(tester);

      for (final no in _todosOsNos(tester).where(_acionavel)) {
        final nome = _nomeAcessivel(no);
        for (final secao in _titulosDeSecao) {
          expect(
            nome.contains(secao),
            isFalse,
            reason:
                'o controle "$nome" absorveu o título da seção "$secao": a '
                'fronteira semântica dele vazou para o nó de cima',
          );
        }
      }

      handle.dispose();
    });

    testWidgets('o botão de voltar continua nomeado e funcionando', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final bancada = await _montar(tester);

      final voltar = _todosOsNos(tester)
          .where(_acionavel)
          .where((no) => _nomeAcessivel(no) == 'Voltar')
          .toList();
      expect(voltar, hasLength(1));

      await _acionar(tester, voltar.single);
      expect(bancada.voltas, equals(1));

      handle.dispose();
    });

    testWidgets('sair da conta continua sendo um controle nomeado', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _montar(tester);

      expect(_acionavel(_noUnico(tester, 'Sair da conta')), isTrue);

      handle.dispose();
    });
  });

  // -------------------------------------------------------------------------
  group('a folha de escolha marca a opção corrente', () {
    /// Abre a folha de "Quem pode me convidar" pelo canal de acessibilidade.
    Future<_Bancada> abrirConvites(
      WidgetTester tester, {
      required QuemMeConvida atual,
      required String rotuloDoBotao,
    }) async {
      final bancada = await _montar(
        tester,
        config: Configuracoes(quemMeConvida: atual, versaoApp: '1.0.0'),
      );
      await _acionar(tester, _noUnico(tester, rotuloDoBotao));
      return bancada;
    }

    testWidgets('a opção atual sai como selecionada, e só ela', (tester) async {
      final handle = tester.ensureSemantics();
      await abrirConvites(
        tester,
        atual: QuemMeConvida.somenteAmigos,
        rotuloDoBotao: 'Quem pode me convidar. Só amigos',
      );

      expect(_rotulosSelecionados(tester), equals(<String>['Só amigos']));

      handle.dispose();
    });

    testWidgets('as outras dizem que NÃO estão selecionadas', (tester) async {
      final handle = tester.ensureSemantics();
      await abrirConvites(
        tester,
        atual: QuemMeConvida.somenteAmigos,
        rotuloDoBotao: 'Quem pode me convidar. Só amigos',
      );

      // A distinção importa: `Tristate.none` — "não é coisa que se seleciona" —
      // e `Tristate.isFalse` — "é, e não está" — chegam diferentes ao leitor de
      // tela. Só a primeira devolve a lista a três botões indistinguíveis.
      for (final rotulo in <String>['Todos', 'Só amigos', 'Ninguém']) {
        expect(
          _selecao(_noUnico(tester, rotulo)),
          equals(_comoMarca(rotulo == 'Só amigos')),
          reason: '"$rotulo": marca de selecionada errada',
        );
      }

      handle.dispose();
    });

    testWidgets('a marca acompanha o valor, e não a posição na lista', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await abrirConvites(
        tester,
        atual: QuemMeConvida.ninguem,
        rotuloDoBotao: 'Quem pode me convidar. Ninguém',
      );

      expect(_rotulosSelecionados(tester), equals(<String>['Ninguém']));

      handle.dispose();
    });

    testWidgets('a mão dominante também marca a opção corrente', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _montar(
        tester,
        config: const Configuracoes(
          maoDominante: MaoDominante.canhoto,
          versaoApp: '1.0.0',
        ),
      );
      await _acionar(tester, _noUnico(tester, 'Mão dominante. Canhoto'));

      expect(_rotulosSelecionados(tester), equals(<String>['Canhoto']));

      handle.dispose();
    });

    testWidgets('escolher pelo canal semântico troca o valor e fecha', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final bancada = await abrirConvites(
        tester,
        atual: QuemMeConvida.todos,
        rotuloDoBotao: 'Quem pode me convidar. Todos',
      );

      await _acionar(tester, _noUnico(tester, 'Ninguém'));

      expect(bancada.alteracoes, hasLength(1));
      expect(bancada.alteracoes.single.quemMeConvida, QuemMeConvida.ninguem);
      expect(
        _nosComRotulo(tester, 'Ninguém'),
        isEmpty,
        reason: 'a folha ficou aberta depois da escolha',
      );

      handle.dispose();
    });

    testWidgets('fechar a folha sem escolher não altera nada', (tester) async {
      final handle = tester.ensureSemantics();
      final bancada = await abrirConvites(
        tester,
        atual: QuemMeConvida.todos,
        rotuloDoBotao: 'Quem pode me convidar. Todos',
      );

      final barreira = _todosOsNos(tester)
          .where(
            (no) => no.getSemanticsData().hasAction(SemanticsAction.dismiss),
          )
          .toList();
      expect(
        barreira,
        hasLength(1),
        reason: 'a folha não oferece como ser fechada',
      );

      await _acionar(tester, barreira.single, SemanticsAction.dismiss);

      expect(bancada.alteracoes, isEmpty);
      expect(_nosComRotulo(tester, 'Ninguém'), isEmpty);
      // E a tela de trás continua inteira.
      expect(
        _nosComRotulo(tester, 'Quem pode me convidar. Todos'),
        hasLength(1),
      );

      handle.dispose();
    });

    testWidgets('escolher a opção que já vale não dispara alteração', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final bancada = await abrirConvites(
        tester,
        atual: QuemMeConvida.todos,
        rotuloDoBotao: 'Quem pode me convidar. Todos',
      );

      await _acionar(tester, _noUnico(tester, 'Todos'));

      expect(bancada.alteracoes, isEmpty);

      handle.dispose();
    });
  });

  // -------------------------------------------------------------------------
  // O DEDO CONTINUA FAZENDO O QUE FAZIA
  // -------------------------------------------------------------------------
  //
  // Declarar semântica não mexe em hit test, e é isso que este grupo fixa. Ele
  // existe porque a correção poderia ter sido feita de um jeito que quebra o
  // toque — encolhendo a área tocável para o quadrado do `Switch`, por exemplo
  // — e nada nos grupos de cima acusaria: eles só olham a árvore semântica.
  group('o toque com o dedo continua igual', () {
    testWidgets('tocar no texto da preferência alterna', (tester) async {
      final bancada = await _montar(tester, config: _tudoLigado);

      await tester.tap(find.text('Música'));
      await tester.pump();

      expect(bancada.alteracoes, hasLength(1));
      expect(bancada.alteracoes.single.musica, isFalse);
    });

    testWidgets('tocar no próprio interruptor alterna', (tester) async {
      final bancada = await _montar(tester, config: _tudoLigado);

      // O primeiro `Switch` da tela é o da Música — e a asserção abaixo é quem
      // confirma isso: se fosse outro, a preferência trocada seria outra.
      await tester.tap(find.byType(Switch).first);
      await tester.pump();

      expect(bancada.alteracoes, hasLength(1));
      expect(bancada.alteracoes.single.musica, isFalse);
    });

    testWidgets('tocar numa linha de navegação chama o destino dela', (
      tester,
    ) async {
      final bancada = await _montar(tester);

      await tester.tap(find.text('Jogadores bloqueados'));
      await tester.pump();

      expect(bancada.visitas, equals(<String>['bloqueados']));
      expect(bancada.alteracoes, isEmpty);
    });

    testWidgets('tocar numa escolha abre a folha, e a opção troca o valor', (
      tester,
    ) async {
      final bancada = await _montar(tester);

      await tester.tap(find.text('Quem pode me convidar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ninguém'));
      await tester.pumpAndSettle();

      expect(bancada.alteracoes, hasLength(1));
      expect(bancada.alteracoes.single.quemMeConvida, QuemMeConvida.ninguem);
    });

    testWidgets('tocar em sair chama o único caminho de saída', (tester) async {
      final bancada = await _montar(tester);

      await tester.tap(find.text('Sair da conta'));
      await tester.pump();

      expect(bancada.visitas, equals(<String>['sair']));
    });
  });
}
