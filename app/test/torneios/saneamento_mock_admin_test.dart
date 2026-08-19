// saneamento_mock_admin_test.dart — o portão da OS "Saneamento produtivo da
// Central de Torneios: mock e admin V1".
//
// ---------------------------------------------------------------------------
// O QUE ESTE ARQUIVO PROVA, E POR QUE EM QUATRO CAMADAS
// ---------------------------------------------------------------------------
//
// O censo de telas registrou dois defeitos na Central de Torneios: um seletor
// de "Cenários mock" na barra de uma tela de produto, e uma área de gestão
// aberta por `mostrarAdmin: true` escrito no host. Os dois nasceram do mesmo
// lugar — o host de pré-visualização era o único chamador, e o que fosse
// conveniente para ele virava, por tabela, o comportamento da tela.
//
// Provar só o comportamento não basta, e provar só a estrutura também não:
//
//   §1 COMPORTAMENTO DA CENTRAL — o atalho de gestão aparece quando, e só
//      quando, a autoridade disser que sim. Um teste de "o literal sumiu" não
//      pegaria alguém reintroduzindo o mesmo defeito com outro nome.
//
//   §2 COMPORTAMENTO DA TELA DE GESTÃO — a guarda mora NA TELA, não no botão.
//      Este é o caso que o censo não tinha como enxergar: esconder o atalho
//      protege contra o toque, e uma rota é alcançável de outros jeitos.
//
//   §3 A SESSÃO — o papel vem do custom claim assinado, falha fechado em todo
//      caminho de dúvida, e não sobrevive a uma troca de conta no meio do
//      caminho.
//
//   §4 AUDITORIA ESTRUTURAL — a prova de AUSÊNCIA. O comportamento acima
//      continuaria verde se alguém reintroduzisse o seletor mock numa OUTRA
//      tela, ou o `mostrarAdmin` num outro widget. Esta seção varre `lib/`
//      inteiro, e não só o que é alcançável hoje.
//
// A VARREDURA DESPOJA COMENTÁRIOS ANTES DE LER, e a técnica é a mesma de
// `casca/auditoria_casca_test.dart` pelo mesmo motivo: o código de produção
// EXPLICA, em prosa, o que foi removido — e uma varredura ingênua acusaria a
// explicação como violação. Pior: o jeito de "consertar" seria apagar a
// documentação que registra a decisão.

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:buraco_master_vip/casca/autoridade_administrativa_de_producao.dart';
import 'package:buraco_master_vip/screens/torneios_models.dart';
import 'package:buraco_master_vip/screens/torneios_screens.dart';
import 'package:buraco_master_vip/sessao/fonte_identidade.dart';
import 'package:buraco_master_vip/sessao/identidade_publica_sessao.dart';
import 'package:buraco_master_vip/sessao/papel_de_sessao.dart';
import 'package:buraco_master_vip/sessao/sessao_do_jogador.dart';

// ===========================================================================
// Bancada
// ===========================================================================

/// Autoridade com a resposta na mão do teste.
///
/// O construtor `pendente` é o que permite encenar "a resposta chegou DEPOIS da
/// troca de conta" sem `Future.delayed` e sem flakiness.
class PapelFalso implements FonteDePapel {
  PapelFalso(this._resposta);
  PapelFalso.pendente() : _resposta = null;

  final bool? _resposta;
  final Completer<bool> _completer = Completer<bool>();
  int chamadas = 0;

  @override
  Future<bool> ehAdministrador() {
    chamadas++;
    final pronta = _resposta;
    if (pronta != null) return Future<bool>.value(pronta);
    return _completer.future;
  }

  void responder(bool valor) => _completer.complete(valor);
}

/// Autoridade que escapa do contrato. Não é hipótese: um provedor sem rede, um
/// SDK ausente ou um claim malformado chegam aqui como exceção.
class PapelQueLanca implements FonteDePapel {
  const PapelQueLanca();

  @override
  Future<bool> ehAdministrador() async => throw StateError('encenado');
}

class FonteDeIdentidadeFalsa implements FonteDeIdentidade {
  @override
  Future<IdentidadePublica> obterMinhaIdentidade() async => IdentidadePublica(
    publicId: 'BMV-TESTE',
    apelido: '',
    avatarRef: null,
    criada: false,
    estado: EstadoPerfil.ativo,
    limites: LimitesSociais.desconhecidos,
    edicao: MetadadosDeEdicao.desconhecidos,
  );
}

/// Cartões SEM imagem, de propósito: `imagemUrl` vira `AssetImage`, e o portão
/// de qualidade do CI roda antes de os assets serem declarados no pubspec. Um
/// cartão com capa faria esta suíte falhar por ambiente, não por produto.
List<TorneioCardVM> _cartoes() => [
  TorneioCardVM(
    tournamentId: 'quarta-vulnerabilidade',
    nome: 'Quarta da Vulnerabilidade',
    modalidade: ModalidadeTorneio.fechado,
    acesso: TipoAcesso.publico,
    participacao: TipoParticipacao.individual,
    dataHora: DateTime.utc(2026, 9, 2, 20),
    vagasTotais: 64,
    inscritos: 48,
    entrada: TipoEntrada.gratuito,
    valorEntrada: 0,
    premiacaoPrincipal: '1.000 fichas',
    status: TorneioStatus.inscricoesAbertas,
    secao: SecaoCentral.destaque,
  ),
];

List<AdminTorneioResumoVM> _resumosAdmin() => [
  AdminTorneioResumoVM(
    id: 'quarta-vulnerabilidade',
    nome: 'Quarta da Vulnerabilidade',
    edicao: 12,
    data: DateTime.utc(2026, 9, 2, 20),
    modalidade: ModalidadeTorneio.fechado,
    inscritos: 48,
    vagas: 64,
    status: TorneioStatus.inscricoesAbertas,
    arrecadacaoFichas: 0,
    premiacaoPrevista: '1.000 fichas + Coroa',
    checkins: 0,
    mesasAtivas: 0,
    alertas: const ['16 vagas restantes'],
  ),
];

TorneiosCallbacks _callbacksInertes({VoidCallback? onCriarModelo}) =>
    TorneiosCallbacks(
      onAbrirDetalhes: (_) {},
      onInscrever: (_) {},
      onConfirmarInscricao: (_, {parceiroId, required regrasLidas}) {},
      onConvidarParceiro: (_, __) {},
      onAceitarConvite: (_) {},
      onCancelarConvite: (_) {},
      onCancelarInscricao: (_) {},
      onFazerCheckin: (_) {},
      onEntrarSalaEspera: (_) {},
      onEntrarNaMesa: (_, __) {},
      onVerClassificacao: (_) {},
      onVerResultado: (_) {},
      onResgatarPremio: (_) {},
      onCompartilharConquista: (_) {},
      onFiltrarCentral: (_) {},
      onCriarModelo: onCriarModelo ?? () {},
      onEditarModelo: (_) {},
      onSalvarModelo: (_) {},
      onAcaoAdmin: (_, __) {},
    );

/// Silencia SÓ o transbordo horizontal de layout, e só ele.
///
/// O runner não carrega as fontes do aplicativo: cada glifo vira uma caixa de
/// 1em, então as linhas ficam mais largas do que no aparelho e `Row` de altura
/// travada acusa transbordo que não existe em produção. O ponto que acusa aqui
/// é o cartão da Central (`torneios_screens.dart`), código de produto que esta
/// OS não tocou — reprovar por causa dele esconderia o que a suíte veio provar.
///
/// O filtro é ESTREITO de propósito: qualquer outra exceção continua reprovando.
void _ignorarTransbordoDaFonteDeTeste() {
  final anterior = FlutterError.onError;
  FlutterError.onError = (detalhes) {
    if (detalhes.exceptionAsString().contains('A RenderFlex overflowed by')) {
      return;
    }
    anterior?.call(detalhes);
  };
  addTearDown(() => FlutterError.onError = anterior);
}

/// Superfície de telefone. Sem isto o conteúdo cai fora da viewport de 800x600
/// do runner e `find` não acha o que existe.
Future<void> _montar(WidgetTester tester, Widget tela) async {
  _ignorarTransbordoDaFonteDeTeste();
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: tela));
  // Dois quadros: o primeiro monta, o segundo entrega a resposta da consulta
  // de autoridade, que sai de `initState` e resolve num microtask.
  await tester.pump();
  await tester.pump();
}

final Finder _atalhoDeGestao = find.byTooltip('Administração');

/// O cartão de gestão desenha `nome · edição N` numa string só — `find.text`
/// exato não acha o nome sozinho, e um teste que "passa" por não achar nada é
/// um teste que não prova nada.
final Finder _nomeDaEdicao = find.textContaining('Quarta da Vulnerabilidade');

// ===========================================================================
// Ferramentas da auditoria estrutural
// ===========================================================================

String _barras(String caminho) => caminho.replaceAll(r'\', '/');

/// O arquivo SEM comentários, respeitando aspas.
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

List<File> _fontesDoCliente() =>
    Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

void main() {
  // =========================================================================
  // §1 — a Central: o atalho de gestão e o seletor mock
  // =========================================================================
  group('Central de Torneios', () {
    testWidgets('sem autoridade declarada, não há atalho de gestão', (
      tester,
    ) async {
      // O padrão do construtor. É o caso do host de pré-visualização, e é o
      // caso de qualquer chamador futuro que esqueça de passar autoridade.
      await _montar(
        tester,
        CentralTorneiosScreen(
          torneios: _cartoes(),
          callbacks: _callbacksInertes(),
          onVoltar: () {},
        ),
      );

      expect(_atalhoDeGestao, findsNothing);
    });

    testWidgets('autoridade que nega não abre o atalho', (tester) async {
      await _montar(
        tester,
        CentralTorneiosScreen(
          torneios: _cartoes(),
          callbacks: _callbacksInertes(),
          onVoltar: () {},
          autoridade: PapelFalso(false),
        ),
      );

      expect(_atalhoDeGestao, findsNothing);
    });

    testWidgets('autoridade que lança não abre o atalho', (tester) async {
      await _montar(
        tester,
        CentralTorneiosScreen(
          torneios: _cartoes(),
          callbacks: _callbacksInertes(),
          onVoltar: () {},
          autoridade: const PapelQueLanca(),
        ),
      );

      expect(_atalhoDeGestao, findsNothing);
    });

    testWidgets('só com autoridade afirmativa o atalho aparece e aciona', (
      tester,
    ) async {
      var acionou = 0;
      await _montar(
        tester,
        CentralTorneiosScreen(
          torneios: _cartoes(),
          callbacks: _callbacksInertes(),
          onVoltar: () {},
          onAbrirAdmin: () => acionou++,
          autoridade: PapelFalso(true),
        ),
      );

      expect(_atalhoDeGestao, findsOneWidget);
      await tester.tap(_atalhoDeGestao);
      await tester.pump();
      expect(acionou, 1);
    });

    testWidgets('enquanto a resposta não chega, o atalho não existe', (
      tester,
    ) async {
      // Desenhar primeiro e esconder depois faria a área de gestão PISCAR na
      // tela de quem não a tem — e um toque rápido cabe nesse piscar.
      final papel = PapelFalso.pendente();
      await _montar(
        tester,
        CentralTorneiosScreen(
          torneios: _cartoes(),
          callbacks: _callbacksInertes(),
          onVoltar: () {},
          autoridade: papel,
        ),
      );

      expect(_atalhoDeGestao, findsNothing);

      papel.responder(true);
      // Dois quadros: o primeiro deixa o `await` retomar e chamar `setState`,
      // o segundo desenha o resultado.
      await tester.pump();
      await tester.pump();
      expect(_atalhoDeGestao, findsOneWidget);
    });

    testWidgets('resposta atrasada da conta anterior não abre o atalho', (
      tester,
    ) async {
      // O caso que só existe por causa do await: a pessoa administradora sai,
      // outra entra, e o "sim" da primeira chega depois. Sem a comparação de
      // fonte, a conta nova herdaria a gestão.
      final daAdministradora = PapelFalso.pendente();

      Widget central(FonteDePapel autoridade) => CentralTorneiosScreen(
        torneios: _cartoes(),
        callbacks: _callbacksInertes(),
        onVoltar: () {},
        autoridade: autoridade,
      );

      await _montar(tester, central(daAdministradora));
      expect(_atalhoDeGestao, findsNothing);

      // Troca de conta: mesma tela, autoridade nova.
      await tester.pumpWidget(MaterialApp(home: central(PapelFalso(false))));
      await tester.pump();

      // A resposta da conta que saiu chega agora, e é um "sim".
      daAdministradora.responder(true);
      await tester.pump();
      await tester.pump();

      expect(_atalhoDeGestao, findsNothing);
    });

    testWidgets('a Central não oferece seletor de cenários mock', (
      tester,
    ) async {
      await _montar(
        tester,
        CentralTorneiosScreen(
          torneios: _cartoes(),
          callbacks: _callbacksInertes(),
          onVoltar: () {},
          // Mesmo no caso mais permissivo que existe: quem administra também
          // não recebe ferramenta de laboratório.
          autoridade: PapelFalso(true),
        ),
      );

      expect(find.byTooltip('Cenários mock'), findsNothing);
      expect(find.byIcon(Icons.science_rounded), findsNothing);
      expect(find.textContaining('Cenários'), findsNothing);
    });
  });

  // =========================================================================
  // §2 — a tela de gestão: a guarda mora na tela, não no botão
  // =========================================================================
  group('tela de gestão de torneios', () {
    Widget admin(FonteDePapel autoridade, {VoidCallback? onCriarModelo}) =>
        AdminTorneiosScreen(
          torneios: _resumosAdmin(),
          callbacks: _callbacksInertes(onCriarModelo: onCriarModelo),
          onVoltar: () {},
          autoridade: autoridade,
        );

    testWidgets('construída direto por rota, sem autoridade, recusa', (
      tester,
    ) async {
      // ESTE É O CASO DA "ROTA INTERNA": ninguém tocou em botão nenhum. A tela
      // foi construída à mão, que é o que um `Navigator.push` escrito noutro
      // arquivo faz.
      await _montar(tester, admin(PapelFalso(false)));

      expect(find.text('Área restrita'), findsOneWidget);
      expect(find.text('Esta conta não administra torneios.'), findsOneWidget);
    });

    testWidgets('recusada, não desenha NADA do conteúdo administrativo', (
      tester,
    ) async {
      await _montar(tester, admin(PapelFalso(false)));

      // O nome da edição, o resumo e o atalho de criar modelo carregam
      // inscritos, alertas e premiação. Desenhar isso atrás de um aviso seria
      // vazar exatamente o que a guarda existe para negar.
      expect(_nomeDaEdicao, findsNothing);
      expect(find.byTooltip('Criar modelo'), findsNothing);
      expect(find.textContaining('16 vagas restantes'), findsNothing);
      expect(find.text('Mostrar somente torneios com alertas'), findsNothing);
    });

    testWidgets('enquanto verifica, também não desenha o conteúdo', (
      tester,
    ) async {
      final papel = PapelFalso.pendente();
      await _montar(tester, admin(papel));

      expect(find.text('Área restrita'), findsOneWidget);
      expect(find.text('Conferindo as permissões desta conta.'), findsOneWidget);
      expect(_nomeDaEdicao, findsNothing);

      papel.responder(true);
      await tester.pump();
      await tester.pump();
      expect(_nomeDaEdicao, findsOneWidget);
    });

    testWidgets('autoridade que lança recusa', (tester) async {
      await _montar(tester, admin(const PapelQueLanca()));

      expect(find.text('Esta conta não administra torneios.'), findsOneWidget);
      expect(_nomeDaEdicao, findsNothing);
    });

    testWidgets('com autoridade, a gestão aparece inteira', (tester) async {
      var criou = 0;
      await _montar(
        tester,
        admin(PapelFalso(true), onCriarModelo: () => criou++),
      );

      expect(find.text('Área restrita'), findsNothing);
      expect(_nomeDaEdicao, findsOneWidget);
      expect(find.byTooltip('Criar modelo'), findsOneWidget);

      await tester.tap(find.byTooltip('Criar modelo'));
      await tester.pump();
      expect(criou, 1);
    });

    testWidgets('perder a autoridade fecha a tela já aberta', (tester) async {
      await _montar(tester, admin(PapelFalso(true)));
      expect(_nomeDaEdicao, findsOneWidget);

      await tester.pumpWidget(MaterialApp(home: admin(PapelFalso(false))));
      await tester.pump();
      await tester.pump();

      expect(_nomeDaEdicao, findsNothing);
      expect(find.text('Área restrita'), findsOneWidget);
    });
  });

  // =========================================================================
  // §3 — a sessão é quem responde, e falha fechado
  // =========================================================================
  group('autoridade administrativa da sessão', () {
    late StreamController<String?> auth;
    late SessaoDoJogador sessao;

    SessaoDoJogador montar(FonteDePapel papeis) {
      auth = StreamController<String?>.broadcast();
      return sessao = SessaoDoJogador(
        fonte: FonteDeIdentidadeFalsa(),
        uids: auth.stream,
        papeis: papeis,
      );
    }

    Future<void> logar(String? uid) async {
      auth.add(uid);
      await Future<void>.delayed(Duration.zero);
    }

    tearDown(() {
      sessao.dispose();
      auth.close();
    });

    test('sem ninguém logado, não administra — e nem pergunta', () async {
      final papel = PapelFalso(true);
      final s = montar(papel);

      expect(await s.temAutoridadeAdministrativa(), isFalse);
      // Não basta responder "não": perguntar a um provedor sem sessão é pedir
      // o papel de "quem?", e a resposta que voltasse não teria dono.
      expect(papel.chamadas, 0);
    });

    test('logada, devolve o que a autoridade assinada disser', () async {
      final s = montar(PapelFalso(true));
      await logar('uid-1');

      expect(await s.temAutoridadeAdministrativa(), isTrue);
    });

    test('logada sem o claim, não administra', () async {
      final s = montar(PapelFalso(false));
      await logar('uid-1');

      expect(await s.temAutoridadeAdministrativa(), isFalse);
    });

    test('provedor que lança não vira autoridade', () async {
      final s = montar(const PapelQueLanca());
      await logar('uid-1');

      expect(await s.temAutoridadeAdministrativa(), isFalse);
    });

    test('troca de conta durante a consulta anula a resposta', () async {
      // A trava de geração, do lado do papel. Sem ela, o "sim" de quem saiu
      // seria entregue a quem entrou.
      final papel = PapelFalso.pendente();
      final s = montar(papel);
      await logar('uid-administradora');

      final resposta = s.temAutoridadeAdministrativa();
      await logar('uid-outra-pessoa');
      papel.responder(true);

      expect(await resposta, isFalse);
    });

    test('logout durante a consulta anula a resposta', () async {
      final papel = PapelFalso.pendente();
      final s = montar(papel);
      await logar('uid-administradora');

      final resposta = s.temAutoridadeAdministrativa();
      await logar(null);
      papel.responder(true);

      expect(await resposta, isFalse);
    });

    test('o adaptador de produção delega à sessão, sem regra própria', () async {
      final s = montar(PapelFalso(true));
      await logar('uid-1');

      final autoridade = autoridadeAdministrativaDe(s);
      expect(await autoridade.ehAdministrador(), isTrue);

      // A igualdade é por sessão: é ela que faz a tela distinguir "mesma conta,
      // reconstruiu" de "conta diferente".
      expect(autoridade, equals(autoridadeAdministrativaDe(s)));

      final outra = SessaoDoJogador(
        fonte: FonteDeIdentidadeFalsa(),
        uids: const Stream<String?>.empty(),
      );
      addTearDown(outra.dispose);
      expect(autoridade, isNot(equals(autoridadeAdministrativaDe(outra))));
    });
  });

  // =========================================================================
  // §4 — a prova de AUSÊNCIA, sobre `lib/` inteiro
  // =========================================================================
  group('nenhuma ferramenta de desenvolvimento sobrou em lib/', () {
    test('a varredura tem o que ler', () {
      // Sem isto, um `lib/` que não fosse encontrado deixaria a seção inteira
      // verde por vazio.
      expect(_fontesDoCliente().length, greaterThan(20));
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
      expect(
        infratores,
        isEmpty,
        reason:
            'ferramenta de laboratório na barra de uma tela de produto volta a '
            'ser produto no dia em que alguém religa o host',
      );
    });

    test('`mostrarAdmin` não existe mais como parâmetro de tela', () {
      // O nome inteiro sai, e não só o literal `true`. Enquanto o parâmetro
      // existir, `mostrarAdmin: algumaCoisa` continua sendo o cliente decidindo
      // o próprio papel — e a revisão seguinte só olharia o valor.
      final infratores = <String>[];
      for (final f in _fontesDoCliente()) {
        if (_codigo(f).contains('mostrarAdmin')) {
          infratores.add(_barras(f.path));
        }
      }
      expect(infratores, isEmpty);
    });

    test('a tela de gestão não compila sem autoridade', () {
      // Prova de FORMA, e é o que sustenta o §2: um `= const SemPapel()` no
      // construtor seria conveniente e transformaria "esqueci de passar" numa
      // tela em branco silenciosa, em vez de erro de compilação.
      final fonte = _codigo(
        File('lib/screens/torneios_screens.dart'),
      ).replaceAll(RegExp(r'\s+'), ' ');
      // Recorta a DECLARAÇÃO da tela de gestão. Varrer o arquivo inteiro
      // acusaria o padrão legítimo da Central (`this.autoridade = const
      // SemPapel()`), que é justamente o que se quer lá: quem esquece de passar
      // autoridade não recebe atalho.
      final inicio = fonte.indexOf('class AdminTorneiosScreen');
      final fim = fonte.indexOf('class _AdminTorneiosScreenState');
      expect(inicio, greaterThanOrEqualTo(0));
      expect(fim, greaterThan(inicio));
      final declaracao = fonte.substring(inicio, fim);

      expect(declaracao, contains('required this.autoridade,'));
      expect(declaracao, isNot(contains('this.autoridade = ')));
    });

    test('só a camada de sessão sabe ler o claim administrativo', () {
      // O claim é a autoridade. Uma segunda tela que soubesse lê-lo passaria a
      // ser um segundo juiz de papel — e o segundo nunca conhece a geração da
      // sessão, que é a trava provada no §3.
      final leitores = <String>[];
      for (final f in _fontesDoCliente()) {
        final conteudo = _codigo(f);
        if (conteudo.contains('getIdTokenResult') ||
            conteudo.contains("['admin']")) {
          leitores.add(_barras(f.path));
        }
      }
      expect(leitores, hasLength(1));
      expect(leitores.single, endsWith('lib/sessao/sessao_firebase.dart'));
    });

    test('a porta de papel não sabe conceder papel', () {
      // Um cliente com vocabulário para atribuir papel a si mesmo acabaria
      // atribuindo, e a linha que fizesse isso pareceria um atalho de teste.
      final porta = _codigo(File('lib/sessao/papel_de_sessao.dart'));
      for (final verbo in ['conceder', 'definir', 'assumir']) {
        expect(porta, isNot(contains(verbo)), reason: 'verbo proibido: $verbo');
      }
    });
  });
}
