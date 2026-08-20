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

// ---------------------------------------------------------------------------
// O PISO DA SUPERFÍCIE
// ---------------------------------------------------------------------------
//
// Uma varredura do tipo "nenhum controle viola X" é VERDADEIRA quando não há
// controle nenhum. Trocar o `build` por um `SizedBox.shrink()` deixava duas
// delas verdes — e é exatamente o tipo de verde que não significa nada.
//
// As listas abaixo são o piso: o que esta tela tem de ter ANTES de qualquer
// conclusão universal ser tirada sobre ela. Elas não substituem a varredura;
// elas são a pré-condição dela, e por isso são conferidas DENTRO de cada
// varredura, e não só num caso vizinho que poderia estar sozinho no vermelho.

/// As três escolhas que moram na própria tela, com o valor padrão anunciado.
const _escolhasDaTela = <String>[
  'Mão dominante. Destro',
  'Quem pode me convidar. Todos',
  'Idioma. Português (Brasil)',
];

/// As oito linhas que levam a outro lugar, no perfil padrão da bancada.
const _linhasDeNavegacao = <String>[
  'Editar perfil. Apelido, foto e informações públicas',
  'Assinatura VIP. Conheça os benefícios da assinatura',
  'Moedas e compras. Pacotes de moedas e histórico',
  'Jogadores bloqueados. Rever ou desbloquear jogadores',
  'Regras e como jogar. Aberto, Fechado e STBL',
  'Suporte. Fale com a equipe do aplicativo',
  'Termos e privacidade. Documentos e políticas do serviço',
  'Avaliar o aplicativo. Conte sua experiência na loja',
];

/// As âncoras que a suíte usa em outros casos e que, se sumirem, tirariam o
/// chão de tudo o mais sem que ninguém reclamasse.
const _ancoras = <String>['Voltar', 'Sair da conta'];

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

/// `Tristate.none` aqui quer dizer "este nó não diz se está habilitado" — que é
/// como as linhas de navegação e as opções da folha chegavam, e o que faz um
/// leitor de tela não ter o que anunciar sobre a disponibilidade do controle.
Tristate _habilitacao(SemanticsNode no) =>
    no.getSemanticsData().flagsCollection.isEnabled;

/// `Tristate.none` quer dizer "este nó não participa do foco de entrada".
///
/// Não existe `isFocusable` na coleção: quem responde é `isFocused`, e o
/// tri-estado carrega as duas informações de uma vez — `none` é "não é
/// focável", `isFalse` é "é focável e não está com o foco", `isTrue` é "está
/// com o foco agora".
Tristate _foco(SemanticsNode no) =>
    no.getSemanticsData().flagsCollection.isFocused;

bool _aceitaFoco(SemanticsNode no) =>
    no.getSemanticsData().hasAction(SemanticsAction.focus);

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

/// Todos os controles que esta tela promete, num lugar só.
List<String> get _superficieEsperada => <String>[
  ..._preferencias.map((p) => p.rotulo),
  ..._escolhasDaTela,
  ..._linhasDeNavegacao,
  ..._ancoras,
];

/// A pré-condição de toda conclusão universal desta suíte.
///
/// Reprova quando a superfície encolheu — inclusive quando ela encolheu até
/// zero, que é o caso que uma varredura do tipo "nenhum viola X" não pega
/// sozinha. Chamada DENTRO de cada varredura, e não ao lado dela: uma guarda
/// que mora num caso vizinho deixa o caso guardado passar verde.
void _exigirPiso(WidgetTester tester) {
  final nos = _todosOsNos(tester);

  expect(
    nos.where(_acionavel),
    isNotEmpty,
    reason:
        'a árvore não tem NENHUM controle acionável — qualquer conclusão do '
        'tipo "nenhum controle viola X" seria verdadeira por vacuidade',
  );

  for (final rotulo in _superficieEsperada) {
    final achados = nos
        .where((no) => _nomeAcessivel(no) == rotulo)
        .where(_acionavel)
        .toList();
    expect(
      achados,
      hasLength(1),
      reason:
          'o piso da superfície não fecha: esperava UM controle acionável '
          'chamado "$rotulo", achei ${achados.length}',
    );
  }

  expect(
    nos.where((no) => _alternancia(no) != Tristate.none),
    hasLength(_preferencias.length),
    reason: 'o piso da superfície não fecha: alternadores fora de nove',
  );
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
      _exigirPiso(tester);

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
      _exigirPiso(tester);

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

  // -------------------------------------------------------------------------
  // O PISO, SOZINHO
  // -------------------------------------------------------------------------
  //
  // O piso já é conferido dentro das varreduras — é lá que ele impede o verde
  // por vacuidade. Aqui ele ganha um caso próprio para que a mensagem de falha
  // aponte para a causa ("a tela encolheu") em vez de para o sintoma.
  group('a superfície existe antes de qualquer conclusão sobre ela', () {
    testWidgets('P1 — os vinte e dois controles esperados estão na árvore', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _montar(tester);

      _exigirPiso(tester);
      expect(_superficieEsperada, hasLength(22));

      handle.dispose();
    });

    testWidgets('P2 — uma tela vazia reprova o piso', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pumpAndSettle();

      // O piso é a única coisa entre uma varredura universal e um verde que não
      // significa nada. Se este caso passar a não lançar, as varreduras
      // voltaram a aprovar o vazio.
      expect(() => _exigirPiso(tester), throwsA(isA<TestFailure>()));

      handle.dispose();
    });
  });

  // -------------------------------------------------------------------------
  // O CONTRATO DE INTERAÇÃO
  // -------------------------------------------------------------------------
  //
  // Agrupar a linha num nó só resolveu o nome e o estado, e cobrou um preço que
  // não estava na conta: descartar a subárvore levava junto o [Focus] que mora
  // dentro do `InkWell` e do `Switch`. O controle continuava legível e sumia do
  // canal de foco de entrada — teclado, D-pad, varredura por acionador —, e
  // nenhum caso reclamava, porque nenhum caso olhava.
  //
  // Estes casos olham. E olham pelo mecanismo REAL: acionar `focus` e conferir
  // que o nó passou a se declarar focado só é possível se a ação tiver chegado
  // a um `FocusNode` de verdade. Um `onFocus` de fachada, escrito para encher
  // contagem, aceitaria a ação e deixaria o nó exatamente como estava.
  group('cada controle expõe o contrato de interação inteiro', () {
    testWidgets('I1 — todo controle acionável se declara habilitado', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _montar(tester);
      _exigirPiso(tester);

      final mudos = _todosOsNos(tester)
          .where(_acionavel)
          .where((no) => _habilitacao(no) != Tristate.isTrue)
          .map(_nomeAcessivel)
          .toList();

      expect(
        mudos,
        isEmpty,
        reason:
            'controles que não dizem se estão habilitados: $mudos — o leitor '
            'de tela não tem o que anunciar sobre a disponibilidade deles',
      );

      handle.dispose();
    });

    testWidgets('I2 — todo controle acionável participa do foco de entrada', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _montar(tester);
      _exigirPiso(tester);

      final fora = _todosOsNos(tester)
          .where(_acionavel)
          .where((no) => _foco(no) == Tristate.none || !_aceitaFoco(no))
          .map(_nomeAcessivel)
          .toList();

      expect(
        fora,
        isEmpty,
        reason:
            'controles fora do canal de foco de entrada: $fora — eles existem '
            'no widget e não são anunciados a teclado nem a acionador',
      );

      handle.dispose();
    });

    testWidgets('I3 — focar pelo canal semântico move o foco DE VERDADE', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _montar(tester);

      // Um de cada família: interruptor, escolha e navegação.
      for (final rotulo in <String>[
        'Música. Trilha musical do aplicativo',
        'Mão dominante. Destro',
        'Termos e privacidade. Documentos e políticas do serviço',
      ]) {
        final antes = _noUnico(tester, rotulo);
        expect(
          _foco(antes),
          Tristate.isFalse,
          reason: '$rotulo: já deveria ser focável e ainda não estar focado',
        );
        final focadoAntes = tester.binding.focusManager.primaryFocus;

        await _acionar(tester, antes, SemanticsAction.focus);

        expect(
          _foco(_noUnico(tester, rotulo)),
          Tristate.isTrue,
          reason:
              '$rotulo: a ação de foco foi aceita e o nó continua dizendo que '
              'não está focado — sinal de que ela não chegou a um FocusNode',
        );
        expect(
          tester.binding.focusManager.primaryFocus,
          isNot(same(focadoAntes)),
          reason: '$rotulo: o foco primário do aplicativo não se moveu',
        );
      }

      handle.dispose();
    });

    testWidgets('I4 — focar um controle não altera preferência nenhuma', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final bancada = await _montar(tester);

      await _acionar(
        tester,
        _noUnico(tester, 'Mostrar quando estou online. Amigos poderão ver sua presença'),
        SemanticsAction.focus,
      );

      expect(
        bancada.alteracoes,
        isEmpty,
        reason: 'focar não é acionar: nenhuma preferência pode ter mudado',
      );

      handle.dispose();
    });

    testWidgets('I5 — nenhum controle voltou a se partir em dois nós', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _montar(tester);
      _exigirPiso(tester);

      // O defeito original era o nome num nó e o estado noutro. O defeito
      // GÊMEO, que uma fusão mal feita produz, é o mesmo conteúdo em dois nós
      // aninhados — o leitor de tela para duas vezes na mesma linha.
      final porRotulo = <String, int>{};
      for (final no in _todosOsNos(tester).where(_acionavel)) {
        final nome = _nomeAcessivel(no);
        if (nome.isEmpty) continue;
        porRotulo[nome] = (porRotulo[nome] ?? 0) + 1;
      }

      final repetidos = porRotulo.entries
          .where((e) => e.value > 1)
          .map((e) => '"${e.key}" ×${e.value}')
          .toList();

      expect(
        repetidos,
        isEmpty,
        reason: 'o mesmo controle aparece mais de uma vez na árvore: $repetidos',
      );

      handle.dispose();
    });

    testWidgets('I6 — as opções da folha também têm habilitação e foco', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _montar(tester);
      await _acionar(tester, _noUnico(tester, 'Quem pode me convidar. Todos'));

      for (final rotulo in <String>['Todos', 'Só amigos', 'Ninguém']) {
        final no = _noUnico(tester, rotulo);
        expect(_habilitacao(no), Tristate.isTrue, reason: '$rotulo sem enabled');
        expect(_aceitaFoco(no), isTrue, reason: '$rotulo não aceita foco');
        expect(_foco(no), isNot(Tristate.none), reason: '$rotulo não é focável');
        expect(_ehBotao(no), isTrue, reason: '$rotulo sem papel de botão');
      }

      handle.dispose();
    });
  });
}
