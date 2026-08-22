// composicao_navegacao_publica_test.dart — as QUATRO entregas na mesma árvore.
//
// ---------------------------------------------------------------------------
// O QUE ESTA SUÍTE PROVA QUE NENHUMA DAS ENTRADAS PODIA
// ---------------------------------------------------------------------------
//
// A composição juntou quatro coisas que nunca tinham convivido:
//
//   avatar público canônico ......... `92344ed`, via a base
//   Ranking Real V2 ................. `e1923f19`, via a base
//   contrato das estatísticas ....... `79063e07` (o `torneio` inelegível)
//   navegação ao Perfil público ..... `53105ab`
//
// A folha da navegação (`53105ab`) e a base são IRMÃS: as duas saem de
// `6e428e8`, e por isso a árvore-base do merge não conhecia nem o avatar
// canônico nem o contrato novo. O git mesclou `perfil_page.dart` e
// `perfil_screen.dart` SEM CONFLITO — os hunks caíram em regiões diferentes —,
// e auto-merge limpo não é prova: nesta linhagem um merge sem conflito já
// reintroduziu um segundo dono de autenticação por um hunk que ninguém leu.
//
// Então o que se afirma aqui é a CONVIVÊNCIA, e não cada parte de novo:
// cada entrada já tem a sua matriz, e elas continuam rodando.
//
// A parte do CONTRATO (casos 2, 3 e 4 da OS) não mora aqui, e não por
// esquecimento: o overlay do CI copia só `app/`, então nenhum teste Dart
// alcança `functions-ranking/`. Ela vive em
// `functions-ranking/test/composicao.test.js`, do lado de quem a produz.
//
// SUPERFÍCIE DE TELEFONE: o padrão do `flutter_test` é 800x600, paisagem de
// desktop, e faz telas de celular estourarem em overflow.

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:buraco_master_vip/casca/home_de_producao.dart';
import 'package:buraco_master_vip/casca/ranking_de_producao.dart';
import 'package:buraco_master_vip/pages/perfil_page.dart';
import 'package:buraco_master_vip/ranking/escopo_ranking.dart';
import 'package:buraco_master_vip/ranking/leitor_ranking.dart';
import 'package:buraco_master_vip/ranking/ranking_da_sessao.dart';
import 'package:buraco_master_vip/ranking/ranking_transporte.dart';
import 'package:buraco_master_vip/screens/inicio_screen.dart';
import 'package:buraco_master_vip/screens/perfil_screen.dart';
import 'package:buraco_master_vip/sessao/avatar_publico.dart';
import 'package:buraco_master_vip/sessao/escopo_sessao.dart';
import 'package:buraco_master_vip/sessao/fonte_identidade.dart';
import 'package:buraco_master_vip/sessao/identidade_publica_sessao.dart';
import 'package:buraco_master_vip/sessao/sessao_do_jogador.dart';

// ===========================================================================
// Fixtures
// ===========================================================================

const String contaA = 'P0A1B2C3D4E5';
const String contaB = 'PZZ9Y8X7W6V5';
const String alvoX = 'PXX1XX2XX3XX';

const String avatarDeA = 'coruja_dourada';

Map<String, Object?> jogadorBruto({
  required String id,
  String apelido = '',
  String avatar = '',
  String liga = 'Ouro',
  String? ligaId = 'ouro',
  int pontos = 1200,
  int posicao = 1,
  bool souEu = false,
}) => {
  'id': id,
  'apelido': apelido,
  'avatar': avatar,
  'liga': liga,
  'ligaId': ligaId,
  'pontos': pontos,
  'posicao': posicao,
  'direcao': 'manteve',
  'delta': 0,
  'selo': null,
  'souEu': souEu,
  'estado': 'classificado',
  'qualificacaoRestante': 0,
  'partidas': 10,
  'vitorias': 6,
  'derrotas': 4,
  'aproveitamento': 60.0,
};

Map<String, Object?> abertura({
  String? temporadaId = 'T-2026-01',
  Object? eu,
  List<Map<String, Object?>> podio = const [],
  List<Map<String, Object?>> primeiraPagina = const [],
}) => {
  'resumo': {
    'escopo': 'temporada',
    'temporadaId': temporadaId,
    'temporadaNome': 'Temporada 1',
    'faixaTempo': 'em andamento',
    'fimEm': null,
    'divisao': null,
    'podio': podio,
    'escadaLigas': const [],
    'eu': eu,
  },
  'primeiraPagina': {
    'itens': primeiraPagina,
    'cursorProxima': null,
    'fim': true,
  },
};

Map<String, Object?> publicoCom({required String id, String liga = 'Prata'}) => {
  'id': id,
  'temporadaId': 'T-2026-01',
  'classificado': true,
  'jogador': jogadorBruto(id: id, liga: liga, ligaId: 'prata', posicao: 50),
};

/// A abertura com o dono e dois terceiros — o cenário da tabela tocável.
Map<String, Object?> aberturaPovoada() => abertura(
  eu: jogadorBruto(id: contaA, apelido: 'você', souEu: true, posicao: 7),
  podio: [
    jogadorBruto(id: alvoX, apelido: 'Terceiro', posicao: 1),
    jogadorBruto(id: contaA, apelido: 'você', souEu: true, posicao: 7),
  ],
  primeiraPagina: [
    jogadorBruto(id: alvoX, apelido: 'Terceiro', posicao: 1),
    jogadorBruto(id: '', apelido: 'Sem id', posicao: 2),
    jogadorBruto(id: contaB, apelido: 'Homônima', posicao: 3),
  ],
);

class TransporteEspiao extends TransporteRanking {
  final List<String> chamadas = <String>[];
  final List<String> idsConsultados = <String>[];

  Object? resposta = aberturaPovoada();
  Object? Function(String id) respostaPublica = (id) => publicoCom(id: id);

  /// Quando falso, cada abertura fica pendurada até o teste completá-la — é o
  /// que permite encenar três toques com a MESMA consulta ainda em voo.
  bool automatico = true;
  final List<Completer<Object?>> pendentes = <Completer<Object?>>[];

  @override
  Future<AberturaRanking> abrirRanking() async {
    chamadas.add('abrir');
    if (!automatico) {
      final c = Completer<Object?>();
      pendentes.add(c);
      return AberturaRanking.daResposta(await c.future);
    }
    return AberturaRanking.daResposta(resposta);
  }

  /// Idem para a consulta de terceiro, e com fila PRÓPRIA.
  ///
  /// Duas filas, e não uma: o caso da barreira temporal precisa dos dois voos
  /// vivos ao mesmo tempo, e eles só coexistem porque as chaves são
  /// diferentes — na mesma chave o leitor dedupa, que é o comportamento que o
  /// caso vizinho afirma.
  final List<Completer<Object?>> pendentesPublicos = <Completer<Object?>>[];

  @override
  Future<FotografiaRanking> rankingPorIdPublico(String publicId) async {
    chamadas.add('publico');
    idsConsultados.add(publicId);
    if (!automatico) {
      final c = Completer<Object?>();
      pendentesPublicos.add(c);
      return FotografiaRanking.doPerfilPublico(await c.future);
    }
    return FotografiaRanking.doPerfilPublico(respostaPublica(publicId));
  }

  int get chamadasAbrir => chamadas.where((c) => c == 'abrir').length;
  int get chamadasPublico => chamadas.where((c) => c == 'publico').length;
}

class FonteRegulavel implements FonteDeIdentidade {
  String publicId = contaA;
  String apelido = 'Ana';
  String? avatarRef = avatarDeA;

  @override
  Future<IdentidadePublica> obterMinhaIdentidade() async => IdentidadePublica(
    publicId: publicId,
    apelido: apelido,
    avatarRef: avatarRef,
    criada: false,
    estado: EstadoPerfil.ativo,
    limites: LimitesSociais.desconhecidos,
    edicao: MetadadosDeEdicao.desconhecidos,
  );
}

/// O arquivo SEM comentários, respeitando aspas.
///
/// Mesma técnica das auditorias vizinhas: este arquivo escreve em prosa os
/// literais que proíbe, e uma varredura ingênua acusaria a explicação.
String semComentarios(File f) {
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

final RegExp _import = RegExp('''import\\s+['"]([^'"]+)['"]''');

String _barras(String p) => p.replaceAll(r'\', '/');

String _resolver(String de, String alvo) {
  if (alvo.startsWith('package:buraco_master_vip/')) {
    return 'lib/${alvo.substring('package:buraco_master_vip/'.length)}';
  }
  final base = _barras(de).split('/')..removeLast();
  for (final parte in alvo.split('/')) {
    if (parte == '..') {
      if (base.isNotEmpty) base.removeLast();
    } else if (parte != '.' && parte.isNotEmpty) {
      base.add(parte);
    }
  }
  return base.join('/');
}

/// O fecho transitivo dos imports a partir de `lib/main.dart`.
Set<String> alcancaveisDaRaiz() {
  final vistos = <String>{};
  final fila = <String>['lib/main.dart'];
  while (fila.isNotEmpty) {
    final atual = fila.removeLast();
    if (!vistos.add(atual)) continue;
    final f = File(atual);
    if (!f.existsSync()) continue;
    for (final m in _import.allMatches(semComentarios(f))) {
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

void main() {
  late TransporteEspiao transporte;
  late RankingDaSessao ranking;
  late FonteRegulavel fonte;
  late StreamController<String?> auth;
  late SessaoDoJogador sessao;

  setUp(() {
    transporte = TransporteEspiao();
    fonte = FonteRegulavel();
    auth = StreamController<String?>.broadcast();
  });

  tearDown(() => auth.close());

  // Abertos DENTRO do teste: `testWidgets` roda num zone de tempo falso, e um
  // stream assinado no `setUp` nunca entregaria o login para o `pump`.
  void abrir() {
    ranking = RankingDaSessao(leitor: LeitorDeRanking(transporte: transporte));
    addTearDown(ranking.dispose);
    sessao = SessaoDoJogador(fonte: fonte, uids: auth.stream);
    addTearDown(sessao.dispose);
  }

  Future<void> assentar(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 400));
    }
    await tester.pumpAndSettle();
  }

  Future<void> montar(WidgetTester tester, Widget tela) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      EscopoSessao(
        sessao: sessao,
        child: EscopoRanking(
          ranking: ranking,
          child: MaterialApp(home: tela),
        ),
      ),
    );
    await assentar(tester);
  }

  Future<void> login(WidgetTester tester, {String uid = 'uid-A'}) async {
    abrir();
    await tester.pumpWidget(const SizedBox.shrink());
    auth.add(uid);
    await tester.pump();
    await tester.pump();
    ranking.aoMudarSessao(geracao: 1, publicId: fonte.publicId);
  }

  // =========================================================================
  // CASO 1 — avatar e Ranking coexistem no fecho produtivo
  // =========================================================================
  group('C1 — as quatro entregas no mesmo fecho', () {
    late Set<String> alcancaveis;

    setUpAll(() => alcancaveis = alcancaveisDaRaiz());

    test('C1 avatar e Ranking Real coexistem, e a navegação com eles', () {
      // POR CONJUNTO E POR NOME, e nunca por contagem: um total confere que
      // nada entrou de surpresa, mas não confere que o que devia estar está.
      // Os dois lados importam, e este caso é o segundo.
      expect(alcancaveis, contains('lib/sessao/avatar_publico.dart'));
      for (final caminho in const [
        'lib/ranking/escopo_ranking.dart',
        'lib/ranking/leitor_ranking.dart',
        'lib/ranking/ranking_da_sessao.dart',
        'lib/ranking/ranking_transporte.dart',
        'lib/ranking/ranking_transporte_firebase.dart',
      ]) {
        expect(alcancaveis, contains(caminho), reason: '$caminho saiu do fecho');
      }
      for (final caminho in const [
        'lib/ranking/estado_tabela_ranking.dart',
        'lib/casca/ranking_de_producao.dart',
        'lib/casca/navegacao_perfil_publico.dart',
      ]) {
        expect(alcancaveis, contains(caminho), reason: '$caminho saiu do fecho');
      }
    });

    test('C17 os cinco arquivos nominais do Ranking continuam no fecho', () {
      // O mesmo conjunto que a auditoria do avatar já exige, afirmado TAMBÉM
      // daqui: aquela suíte pode um dia ser reescrita, e o Ranking não pode
      // depender de a linhagem do avatar continuar vigiando-o.
      const doRanking = [
        'lib/ranking/escopo_ranking.dart',
        'lib/ranking/leitor_ranking.dart',
        'lib/ranking/ranking_da_sessao.dart',
        'lib/ranking/ranking_transporte.dart',
        'lib/ranking/ranking_transporte_firebase.dart',
      ];
      expect(
        alcancaveis.where((c) => c.startsWith('lib/ranking/')).toSet(),
        containsAll(doRanking),
      );
    });

    test('C18 o avatar acrescenta só a sua dependência legítima', () {
      // O resolvedor não arrasta nada: importa só o estado canônico de
      // identidade, que já estava no fecho antes dele.
      final resolvedor = semComentarios(File('lib/sessao/avatar_publico.dart'));
      final importados = _import
          .allMatches(resolvedor)
          .map((m) => m.group(1)!)
          .toList();
      expect(importados, ['identidade_publica_sessao.dart']);
    });

    test('C16 nenhuma superfície de maquete assume autoridade', () {
      // Amigos, Loja e Hall são catálogo visual: podem existir na árvore, mas
      // não podem ser ALCANÇÁVEIS a partir de `main.dart`, porque alcançável é
      // o que a casca de produção monta.
      // REANCORADO PARA A RAIZ P, e a regra ficou mais estrita.
      //
      // Na linhagem funcional estas cinco telas eram inalcançáveis, e proibir o
      // CAMINHO bastava. A raiz P ligou a Loja (`LojaDeProducao`) e o
      // Ranking/Hall reais, e com isso `loja_screen`, `loja_categoria_screen`,
      // `hall_screen` e `ranking_screen` passaram a ser ALCANÇÁVEIS — como
      // apresentação, recebendo o VM de fora. Medido: a raiz P sozinha, SEM nada
      // desta composição, já alcança as quatro.
      //
      // O que não pode é a maquete assumir autoridade, e maquete aqui é o
      // factory `.mock()` — que continua existindo, DECLARADO, e que ninguém no
      // caminho de produção constrói. Então a proibição passa de "o arquivo não
      // está no fecho" para "o factory não é chamado no fecho", que é o que a
      // regra sempre quis dizer e que continua valendo com o arquivo dentro.
      //
      // `amigos_screen` segue proibida pelo CAMINHO: ela não tem host de
      // produção nenhum, e se aparecer no fecho é porque virou rota.
      expect(
        alcancaveis,
        isNot(contains('lib/screens/amigos_screen.dart')),
        reason: 'a maquete de Amigos virou produção',
      );
      for (final maquete in const [
        'AmigosScreen',
        'HallVM.mock',
        'RankingVM.mock',
        'LojaVM.mock',
      ]) {
        final constroem = alcancaveis.where((c) {
          final f = File(c);
          if (!f.existsSync()) return false;
          final fonte = semComentarios(f);
          if (!fonte.contains('$maquete(')) return false;
          return !fonte.contains('factory $maquete(');
        }).toList();
        expect(
          constroem,
          isEmpty,
          reason: '$maquete passou a ser construída no caminho de produção',
        );
      }
    });

    test('C12 o avatar não volta ao emoji fixo na trilha produtiva', () {
      final home = semComentarios(File('lib/casca/home_de_producao.dart'));
      expect(home, isNot(contains('avatarRef ??')));
      expect(home, contains('avatarPublicoDaIdentidade('));
    });

    test('C19 nenhuma suíte das entradas foi removida', () {
      // As três entradas trouxeram matrizes, e composição não é lugar de perder
      // prova. Se um arquivo destes sumir, foi alguém "limpando" o que
      // atrapalhava — que é o modo mais comum de uma composição ficar verde.
      for (final suite in const [
        'test/casca/avatar_publico_canonico_test.dart',
        'test/casca/homologacao_avatar_publico_test.dart',
        'test/composicao/composicao_perfil_ranking_test.dart',
        'test/composicao/composicao_avatar_ranking_test.dart',
        'test/ranking/navegacao_perfil_publico_test.dart',
        'test/ranking/leitor_ranking_real_test.dart',
        'test/ranking/regressao_leitor_ranking_test.dart',
        'test/ranking/barreira_temporal_ranking_test.dart',
        'test/ranking/estado_canonico_ranking_test.dart',
        'test/ranking/homologacao_perfil_publicavel_test.dart',
      ]) {
        expect(
          File(suite).existsSync(),
          isTrue,
          reason: '$suite sumiu da árvore',
        );
      }
    });

    test('C20 nenhuma contagem rígida envelhecida sobrou nas auditorias', () {
      // As duas auditorias que a composição moveu passaram a escrever o total
      // como SOMA NOMEADA, e não como número solto. Este caso trava a forma:
      // um `hasLength(48)` cru voltaria a envelhecer em silêncio na próxima
      // composição, e o próximo a mexer ajustaria o número sem nomear nada.
      final auditoria = semComentarios(
        File('test/casca/avatar_publico_canonico_test.dart'),
      );
      expect(auditoria, contains('doRankingReal.length'));
      expect(auditoria, contains('daNavegacaoPublica.length'));

      // A proibição é do total do FECHO, e só dele. `hasLength` com número
      // literal é legítimo em toda parte — `assinantes` de `authStateChanges`
      // tem de ser exatamente 1, e escrever `1` ali é o certo. O que não pode
      // é o total do fecho voltar a ser um número solto, porque é ele que
      // envelhece a cada composição.
      final totalDoFecho = RegExp(
        r'expect\(\s*alcancaveis\s*,\s*hasLength\(([^)]*)\)',
      ).firstMatch(auditoria);
      expect(
        totalDoFecho,
        isNotNull,
        reason: 'sumiu a asserção de tamanho do fecho',
      );
      expect(
        RegExp(r'^\s*\d+\s*$').hasMatch(totalDoFecho!.group(1)!),
        isFalse,
        reason: 'o total do fecho voltou a ser literal — nomeie o que entrou, '
            'como manda a lição das duas composições anteriores',
      );
    });
  });

  // =========================================================================
  // CASOS 5–11 — a projeção pública e a decisão de qual Perfil abrir
  // =========================================================================
  group('C5–C11 — jogadores públicos, sem uid e sem palpite', () {
    test('C5 a tabela usa jogadores públicos SEM uid', () {
      final lida = AberturaRanking.daResposta(aberturaPovoada());
      expect(lida.tabela!.podio, isNotEmpty);
      expect(lida.tabela!.primeiraPagina, isNotEmpty);

      // A garantia é ESTRUTURAL: o objeto não tem campo onde um uid caberia.
      // Uma expressão regular sobre a resposta seria afrouxável; a ausência do
      // campo, não.
      final fonte = semComentarios(File('lib/ranking/ranking_transporte.dart'));
      expect(
        RegExp(r'final\s+String\??\s+uid\b').hasMatch(fonte),
        isFalse,
        reason: 'nasceu um campo uid na projeção pública',
      );
      expect(
        RegExp(r'''\buid\s*:''').hasMatch(fonte),
        isFalse,
        reason: 'algum construtor da projeção passou a receber uid',
      );
    });

    testWidgets('C6 o terceiro navega pelo publicId, e por ele só', (
      tester,
    ) async {
      await login(tester);
      await montar(tester, const RankingDeProducao());

      await tester.tap(find.text('Terceiro').first);
      await assentar(tester);

      expect(find.byType(PerfilScreen), findsOneWidget);
      final pagina = tester.widget<PerfilPage>(find.byType(PerfilPage));
      expect(pagina.publicIdVisitado, alvoX);
      expect(pagina.ehMeuPerfil, isFalse);
      // E a consulta saiu para aquele id, e não para outro.
      expect(transporte.idsConsultados, [alvoX]);
    });

    testWidgets('C7 o proprietário abre o próprio Perfil sem callable de terceiro', (
      tester,
    ) async {
      await login(tester);
      await montar(tester, const RankingDeProducao());

      await tester.tap(find.text('você').first);
      await assentar(tester);

      final pagina = tester.widget<PerfilPage>(find.byType(PerfilPage));
      expect(pagina.ehMeuPerfil, isTrue);
      expect(pagina.publicIdVisitado, isNull);
      // A prova que importa: NENHUMA consulta de terceiro foi emitida sobre o
      // próprio jogador. O dono lê o escopo que a casca já mantém.
      expect(transporte.chamadasPublico, 0);
      expect(transporte.idsConsultados, isEmpty);
    });

    testWidgets('C8 publicId vazio não navega', (tester) async {
      await login(tester);
      await montar(tester, const RankingDeProducao());

      await tester.tap(find.text('Sem id'));
      await assentar(tester);

      // Continua no Ranking, e em silêncio: um aviso ali seria o aplicativo
      // culpando a pessoa por um dado que ela não escolheu.
      expect(find.byType(RankingDeProducao), findsOneWidget);
      expect(find.byType(PerfilScreen), findsNothing);
      expect(transporte.chamadasPublico, 0);
    });

    test('C9 apelido não vira identificador', () {
      final fonte = semComentarios(
        File('lib/casca/navegacao_perfil_publico.dart'),
      );
      expect(fonte, contains('jogador.souEu'));
      expect(
        fonte,
        isNot(contains('apelido')),
        reason: 'a decisão de qual Perfil abrir passou a olhar o apelido',
      );
    });

    test('C10 posição não vira identificador', () {
      final fonte = semComentarios(
        File('lib/casca/navegacao_perfil_publico.dart'),
      );
      expect(
        fonte,
        isNot(contains('posicao')),
        reason: 'a decisão passou a olhar a posição, que muda entre o desenho '
            'e o toque',
      );
    });

    test('C11 índice de lista não vira identificador', () {
      final fonte = semComentarios(
        File('lib/casca/navegacao_perfil_publico.dart'),
      );
      for (final proibido in const ['indexOf', 'elementAt', 'index]', '[i]']) {
        expect(
          fonte,
          isNot(contains(proibido)),
          reason: 'a decisão passou a identificar jogador por posição na lista',
        );
      }
      // E nem pela comparação que PARECE certa: `souEu` vem do servidor, sobre
      // o uid, e no intervalo de troca de sessão o publicId local já é o da
      // conta nova enquanto a lista ainda é da antiga.
      expect(fonte, isNot(contains('EscopoSessao')));
      expect(fonte, isNot(contains('publicId ==')));
    });

    testWidgets('C6b duas visitas seguidas consultam os DOIS ids', (
      tester,
    ) async {
      await login(tester);
      await montar(tester, const RankingDeProducao());

      await tester.tap(find.text('Terceiro').first);
      await assentar(tester);

      // Volta pelo Navigator, e não por `pageBack()`: a tela do Perfil desenha
      // o próprio controle de voltar, e `pageBack` procura os botões padrão do
      // Material/Cupertino, que não estão lá. Encenar a volta com o gesto
      // errado falharia por motivo nenhum.
      tester.state<NavigatorState>(find.byType(Navigator).first).pop();
      await assentar(tester);

      await tester.tap(find.text('Homônima'));
      await assentar(tester);

      // Dois ids distintos, na ordem em que foram tocados — nada de reaproveitar
      // a resposta do primeiro para o segundo.
      expect(transporte.idsConsultados, [alvoX, contaB]);
    });
  });

  // =========================================================================
  // CASOS 12–15 — o que a composição não pode ter afrouxado
  // =========================================================================
  group('C12–C15 — as invariantes da base sob a tabela nova', () {
    testWidgets('C12 o avatar canônico segue no cabeçalho da Home', (
      tester,
    ) async {
      fonte.avatarRef = avatarDeA;
      await login(tester);
      await montar(tester, const HomeDeProducao());

      final jogador = tester
          .widget<InicioScreen>(find.byType(InicioScreen))
          .vm
          .jogador;
      expect(jogador.avatar, avatarDeA);
      expect(jogador.avatar, avatarPublicoDe(avatarDeA));
    });

    testWidgets('C12b avatar ausente cai no fallback DA AUTORIDADE', (
      tester,
    ) async {
      fonte.avatarRef = null;
      await login(tester);
      await montar(tester, const HomeDeProducao());

      final jogador = tester
          .widget<InicioScreen>(find.byType(InicioScreen))
          .vm
          .jogador;
      expect(jogador.avatar, kAvatarPublicoFallback);
    });

    testWidgets('C13 ranking ausente não vira Bronze nem colocação zero', (
      tester,
    ) async {
      // `eu: null` na abertura é "o servidor não te classificou", e é o caso
      // exato em que este aplicativo já desenhou Bronze e #0.
      transporte.resposta = abertura(eu: null);
      await login(tester);
      await montar(tester, const PerfilPage());

      final vm = tester.widget<PerfilScreen>(find.byType(PerfilScreen)).vm;
      expect(vm.ranking.liga, isNull);
      expect(vm.ranking.posicaoMundial, isNull);
      expect(vm.ranking.ehLigaDeVerdade, isFalse);

      final textos = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? '')
          .join(' | ');
      expect(textos, isNot(contains('Bronze')));
      expect(textos, isNot(contains('#0')));
    });

    test('C14 a barreira temporal continua de pé sob o abrirRanking novo', () async {
      // ---------------------------------------------------------------------
      // O QUE ESTE CASO ENCENA, E O QUE ELE NÃO ENCENA
      // ---------------------------------------------------------------------
      //
      // NÃO é "resposta antiga chegou por último". Uma segunda pergunta,
      // emitida DEPOIS de a primeira responder, tem o direito de trocar a
      // temporada — é a virada legítima, e a suíte da barreira a exige.
      //
      // O que a barreira fecha é a ordem INVERSA: dois pedidos CONTEMPORÂNEOS,
      // nascidos antes de qualquer resposta, em que o de número maior traz a
      // notícia mais velha. O cliente sabe quando emitiu cada um, mas não em
      // que ordem o servidor os atendeu.
      //
      // O que faz esta cópia valer a pena aqui, em vez de confiar na suíte
      // original: o voo #1 agora é `abrirRanking` — o método que a folha da
      // navegação criou, que devolve cabeçalho MAIS tabela. A barreira foi
      // escrita quando esse caminho não existia, e é ele que a composição
      // acabou de colocar na frente dela.
      //
      // Duas chaves diferentes de propósito: na mesma chave o leitor dedupa, e
      // os dois voos não coexistiriam.
      final t = TransporteEspiao()..automatico = false;
      final leitor = LeitorDeRanking(transporte: t);

      final vooAbertura = leitor.abrirRanking(contaPublicId: contaA); // #1
      final vooPublico = leitor.rankingPublico(
        contaPublicId: contaA,
        alvoPublicId: alvoX,
      ); // #2

      // O servidor atendeu #1 DEPOIS da virada de temporada.
      t.pendentes.single.complete(
        abertura(
          temporadaId: 'T2',
          eu: jogadorBruto(id: contaA, liga: 'Ouro', ligaId: 'ouro'),
          primeiraPagina: [jogadorBruto(id: alvoX, apelido: 'Terceiro')],
        ),
      );
      final aberta = await vooAbertura;
      expect(aberta, isNotNull);
      expect(aberta!.eu.temporadaId, 'T2');
      // A tabela veio junto — é o que `abrirRanking` acrescentou.
      expect(aberta.tabela.primeiraPagina, hasLength(1));

      // E atendeu #2 ANTES dela: número maior, notícia mais velha.
      t.pendentesPublicos.single.complete(publicoCom(id: alvoX));

      expect(
        await vooPublico,
        isNull,
        reason: 'uma temporada anterior de um pedido contemporâneo foi aceita '
            'como atual — a barreira caiu na composição',
      );
      // E o que já se sabia continua de pé.
      expect(leitor.emCache(contaPublicId: contaA)!.temporadaId, 'T2');
    });

    testWidgets('C15 três toques simultâneos abrem UMA consulta', (
      tester,
    ) async {
      transporte.automatico = false;
      await login(tester);
      await montar(tester, const PerfilPage());

      // A consulta da montagem está pendurada. Dois retries a mais, com ela
      // ainda em voo, não podem virar três chamadas: o leitor dedupa por chave.
      final antes = transporte.chamadasAbrir;
      unawaited(ranking.recarregar());
      unawaited(ranking.recarregar());
      await tester.pump();

      expect(
        transporte.chamadasAbrir,
        antes,
        reason: 'o retry deixou de ser idempotente — três toques viraram três '
            'chamadas da mesma callable',
      );

      // E quando a única consulta responde, a tela produz o resultado.
      for (final c in transporte.pendentes) {
        if (!c.isCompleted) c.complete(aberturaPovoada());
      }
      await assentar(tester);
      expect(
        tester.widget<PerfilScreen>(find.byType(PerfilScreen)).vm.ranking.liga,
        'Ouro',
      );
    });
  });

  // =========================================================================
  // O LIMITE FUNCIONAL DECLARADO PELA OS
  // =========================================================================
  group('a identidade do terceiro — pendência RESOLVIDA', () {
    testWidgets('o perfil visitado é do visitado, nos quatro campos', (
      tester,
    ) async {
      // ---------------------------------------------------------------------
      // ESTE CASO MUDOU DE SENTIDO, E A HISTÓRIA IMPORTA.
      // ---------------------------------------------------------------------
      //
      // Ele nasceu registrando uma PENDÊNCIA: naquela composição, o perfil
      // visitado tinha a liga certa e o nome e o avatar de quem estava olhando,
      // porque o `PerfilService` só recebia a identidade da sessão. O caso
      // deliberadamente não afirmava nada sobre nome e avatar — afirmar o valor
      // errado o carimbaria como esperado, e ficaria vermelho no dia da
      // correção.
      //
      // Esse dia chegou. A projeção pública que a tela já consultava para a liga
      // sempre trouxe apelido e avatar junto; o cliente é que os descartava.
      // Agora os quatro campos vêm do mesmo `publicId`, e é isso que se afirma.
      //
      // A matriz completa — com fixtures grotescamente diferentes entre
      // visitante e visitado — está em `test/perfil/identidade_visitada_test.dart`.
      transporte.respostaPublica = (id) =>
          publicoCom(id: id, liga: 'Prata');
      await login(tester);
      await montar(
        tester,
        const PerfilPage(publicIdVisitado: alvoX),
      );

      final vm = tester.widget<PerfilScreen>(find.byType(PerfilScreen)).vm;

      // 1. o publicId certo chegou, e a consulta foi feita para ele;
      expect(transporte.idsConsultados, [alvoX]);
      // 2. o ranking exibido é o DO VISITADO, e não o de quem olha;
      expect(vm.ranking.liga, 'Prata');
      expect(vm.ranking.posicaoMundial, 50);
      // 3. e agora o nome também: a fixture publica apelido vazio, então vale a
      //    regra de apresentação — o id público, que É de quem está sendo
      //    visitado. O que não pode, em hipótese alguma, é ser o de quem olha.
      expect(vm.nome, alvoX);
      expect(vm.nome, isNot('Ana'));
      expect(vm.ranking.liga, isNot('Ouro'));
    });

    testWidgets('a liga da sessão NÃO mascara a do visitado', (tester) async {
      // A parte do defeito que a OS proíbe expressamente: seja qual for o
      // estado do nome e do avatar, a LIGA do visitado nunca pode ser a de quem
      // está olhando. É o campo que a composição já consegue acertar, e por
      // isso é o campo que se trava.
      transporte.resposta = abertura(
        eu: jogadorBruto(id: contaA, liga: 'Diamante', ligaId: 'diamante'),
      );
      transporte.respostaPublica = (id) => publicoCom(id: id, liga: 'Prata');
      await login(tester);
      await montar(tester, const PerfilPage(publicIdVisitado: alvoX));

      final vm = tester.widget<PerfilScreen>(find.byType(PerfilScreen)).vm;
      expect(vm.ranking.liga, 'Prata');
      expect(vm.ranking.liga, isNot('Diamante'));
    });
  });
}
