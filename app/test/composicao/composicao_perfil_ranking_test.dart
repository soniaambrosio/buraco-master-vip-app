// composicao_perfil_ranking_test.dart — o que só existe DEPOIS da união.
//
// ---------------------------------------------------------------------------
// POR QUE UMA SUÍTE SÓ PARA A COMPOSIÇÃO
// ---------------------------------------------------------------------------
//
// As duas entradas já vinham homologadas cada uma por conta própria. O que
// nenhuma delas podia provar é a interseção: três arquivos que as duas mexeram,
// e que o git auto-mesclou sem conflito.
//
// AUTO-MERGE LIMPO NÃO É PROVA. Nesta linhagem um merge sem conflito já
// reintroduziu um segundo dono de autenticação, por um hunk que o git juntou
// sozinho e ninguém leu. Esta suíte existe para que a união seja afirmada por
// teste e não por confiança no algoritmo de três vias.
//
// O que cada lado precisa continuar valendo:
//
//   PERFIL PUBLICÁVEL  nada de nível 1, zero, 'Novato(a)', 'Bronze' ou '#0'.
//                      O que não tem fonte não é desenhado nem compartilhado.
//   LEITOR DE RANKING  o próprio jogador vem do escopo, o visitado vem de
//                      `publicIdVisitado`, e resposta vencida não aparece.
//   MESA ONLINE        as portas únicas continuam únicas.
//
// NENHUM ATRASO REAL de rede: o transporte falso responde quando o teste manda.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:buraco_master_vip/pages/perfil_page.dart';
import 'package:buraco_master_vip/ranking/escopo_ranking.dart';
import 'package:buraco_master_vip/ranking/leitor_ranking.dart';
import 'package:buraco_master_vip/ranking/ranking_da_sessao.dart';
import 'package:buraco_master_vip/ranking/ranking_transporte.dart';
import 'package:buraco_master_vip/screens/perfil_screen.dart';
import 'package:buraco_master_vip/sessao/escopo_sessao.dart';
import 'package:buraco_master_vip/sessao/fonte_identidade.dart';
import 'package:buraco_master_vip/sessao/identidade_publica_sessao.dart';
import 'package:buraco_master_vip/sessao/sessao_do_jogador.dart';

// ===========================================================================
// Ferramentas
// ===========================================================================

const contaA = 'P0A1B2C3D4E5';
const contaB = 'P9Z8Y7X6W5V4';
const alvoX = 'PXX1XX2XX3XX';

/// A resposta de `abrirRanking` para quem ESTÁ na tabela.
Map<String, Object?> aberturaCom({
  String liga = 'Ouro',
  String? ligaId = 'ouro',
  int posicao = 128,
  String? temporadaId = 'T-2026-01',
}) => {
  'resumo': {
    'escopo': 'temporada',
    'temporadaId': temporadaId,
    'temporadaNome': 'Temporada 1',
    'divisao': null,
    'podio': const [],
    'escadaLigas': const [],
    'eu': {
      'id': contaA,
      'apelido': '',
      'avatar': '',
      'liga': liga,
      'ligaId': ligaId,
      'pontos': 1200,
      'posicao': posicao,
      'direcao': 'manteve',
      'delta': 0,
      'selo': null,
      'souEu': true,
      'estado': 'classificado',
      'qualificacaoRestante': 0,
      'partidas': 10,
      'vitorias': 6,
      'derrotas': 4,
      'aproveitamento': 60.0,
    },
  },
  'primeiraPagina': const {'itens': [], 'cursorProxima': null, 'fim': true},
};

/// A resposta de `consultarJogadorPorIdPublico`.
Map<String, Object?> publicoCom({
  required String id,
  String liga = 'Prata',
  String? ligaId = 'prata',
  int posicao = 50,
  String? temporadaId = 'T-2026-01',
}) => {
  'id': id,
  'temporadaId': temporadaId,
  'classificado': true,
  'jogador': {
    'id': id,
    'apelido': '',
    'avatar': '',
    'liga': liga,
    'ligaId': ligaId,
    'pontos': 900,
    'posicao': posicao,
    'direcao': 'manteve',
    'delta': 0,
    'selo': null,
    'souEu': false,
    'estado': 'classificado',
    'qualificacaoRestante': 0,
    'partidas': 5,
    'vitorias': 2,
    'derrotas': 3,
    'aproveitamento': 40.0,
  },
};

/// Transporte que registra TUDO o que foi pedido, e responde quando mandarem.
class TransporteEspiao extends TransporteRanking {
  final List<String> chamadas = <String>[];
  final List<String> idsConsultados = <String>[];
  final List<Completer<FotografiaRanking>> proprios = [];
  final List<Completer<FotografiaRanking>> publicos = [];

  /// Quando falso, cada chamada fica pendurada até o teste completá-la.
  bool automatico = true;
  Object? respostaPropria = aberturaCom();
  Object? respostaPublica = publicoCom(id: alvoX);

  @override
  Future<FotografiaRanking> meuRanking() {
    chamadas.add('proprio');
    if (!automatico) {
      final c = Completer<FotografiaRanking>();
      proprios.add(c);
      return c.future;
    }
    return Future.value(FotografiaRanking.daAbertura(respostaPropria));
  }

  @override
  Future<FotografiaRanking> rankingPorIdPublico(String publicId) {
    chamadas.add('publico');
    idsConsultados.add(publicId);
    if (!automatico) {
      final c = Completer<FotografiaRanking>();
      publicos.add(c);
      return c.future;
    }
    return Future.value(FotografiaRanking.doPerfilPublico(respostaPublica));
  }

  int get chamadasProprio => chamadas.where((c) => c == 'proprio').length;
  int get chamadasPublico => chamadas.where((c) => c == 'publico').length;
}

/// Fonte de identidade regulável, para encenar troca de conta.
class FonteRegulavel implements FonteDeIdentidade {
  String publicId = contaA;
  String apelido = 'Sônia';

  @override
  Future<IdentidadePublica> obterMinhaIdentidade() async => IdentidadePublica(
    publicId: publicId,
    apelido: apelido,
    avatarRef: null,
    criada: false,
    estado: EstadoPerfil.ativo,
    limites: LimitesSociais.desconhecidos,
    edicao: MetadadosDeEdicao.desconhecidos,
  );
}

/// Duas esperas encadeadas: a identidade responde por `Future`, e só DEPOIS o
/// Perfil descobre que o `publicId` mudou e começa os 350ms do serviço.
Future<void> assentar(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 400));
  }
  await tester.pumpAndSettle();
}

PerfilVM vmNaTela(WidgetTester tester) =>
    tester.widget<PerfilScreen>(find.byType(PerfilScreen)).vm;

String textoDaTela(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '')
    .join(' | ');

/// O arquivo SEM comentários, respeitando aspas. Mesma técnica das auditorias
/// vizinhas: uma auditoria que lê comentário se auto-sabota.
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
        if (i + 1 < fonte.length) saida.write(fonte[i + 1]);
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

final RegExp _import = RegExp(r'''import\s+['"]([^'"]+)['"]''');

/// Quem CONSTRÓI uma classe, entre os arquivos alcançáveis pela raiz.
///
/// O arquivo que DECLARA a classe é excluído de propósito: `class X` traz o
/// próprio construtor (`const X({...})`), e contá-lo como ponto de construção
/// faria toda autoridade parecer duplicada por definição. Já perdi uma medição
/// para esse falso-positivo.
List<String> _quemConstroi(Set<String> alcancaveis, String classe) {
  final saida = <String>[];
  for (final caminho in alcancaveis) {
    final f = File(caminho);
    if (!f.existsSync()) continue;
    final fonte = semComentarios(f);
    if (RegExp('class\\s+$classe\\b').hasMatch(fonte)) continue;
    if (fonte.contains('$classe(')) saida.add(caminho);
  }
  return saida..sort();
}

String _barras(String p) => p.replaceAll(r'\', '/');

String _resolver(String de, String alvo) {
  if (alvo.startsWith('package:buraco_master_vip/')) {
    return 'lib/${alvo.substring('package:buraco_master_vip/'.length)}';
  }
  final base = _barras(de).split('/')..removeLast();
  for (final parte in alvo.split('/')) {
    if (parte == '..') {
      base.removeLast();
    } else if (parte != '.') {
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
  // =========================================================================
  // A UNIÃO EM FUNCIONAMENTO — Perfil próprio
  // =========================================================================
  group('C1 — o Perfil próprio bebe do escopo de ranking', () {
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
      ranking = RankingDaSessao(
        leitor: LeitorDeRanking(transporte: transporte),
      );
      addTearDown(ranking.dispose);
      sessao = SessaoDoJogador(fonte: fonte, uids: auth.stream);
      addTearDown(sessao.dispose);
    }

    Future<void> montar(
      WidgetTester tester, {
      bool ehMeuPerfil = true,
      String? visitado,
    }) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        EscopoSessao(
          sessao: sessao,
          child: EscopoRanking(
            ranking: ranking,
            child: MaterialApp(
              home: PerfilPage(
                ehMeuPerfil: ehMeuPerfil,
                publicIdVisitado: visitado,
              ),
            ),
          ),
        ),
      );
      await assentar(tester);
    }

    testWidgets('C1 — o Perfil próprio recebe o ranking REAL do escopo', (
      tester,
    ) async {
      abrir();
      auth.add('uid-a');
      ranking.aoMudarSessao(geracao: 1, publicId: contaA);
      await montar(tester);

      final vm = vmNaTela(tester);
      expect(vm.ranking.liga, 'Ouro');
      expect(vm.ranking.posicaoMundial, 128);
      expect(vm.ranking.temporadaId, 'T-2026-01');
      // Uma consulta, e uma só: o Perfil não abre a sua.
      expect(transporte.chamadasProprio, 1);
      expect(transporte.chamadasPublico, 0);
    });

    testWidgets(
      'C2 — o ranking chega DEPOIS e a tela acompanha, sem recarregar o perfil',
      (tester) async {
        transporte.automatico = false;
        abrir();
        auth.add('uid-a');
        ranking.aoMudarSessao(geracao: 1, publicId: contaA);
        await montar(tester);

        // O perfil já montou; o ranking ainda está em voo.
        expect(vmNaTela(tester).ranking.fase, FaseRanking.carregando);
        final nomeAntes = vmNaTela(tester).nome;

        transporte.proprios.single.complete(
          FotografiaRanking.daAbertura(aberturaCom(liga: 'Diamante')),
        );
        await tester.pumpAndSettle();

        expect(vmNaTela(tester).ranking.liga, 'Diamante');
        // O resto do VM não foi recarregado: mesmo nome, e nenhuma consulta a
        // mais de identidade nem de ranking.
        expect(vmNaTela(tester).nome, nomeAntes);
        expect(transporte.chamadasProprio, 1);
      },
    );

    testWidgets('C12 — uma reconstrução não abre callable nova', (
      tester,
    ) async {
      abrir();
      auth.add('uid-a');
      ranking.aoMudarSessao(geracao: 1, publicId: contaA);
      await montar(tester);
      expect(transporte.chamadasProprio, 1);

      // Rebuilds em rajada: o `build` lê o estado, não pergunta.
      for (var i = 0; i < 5; i++) {
        await tester.pump();
        tester.element(find.byType(PerfilScreen)).markNeedsBuild();
      }
      await tester.pumpAndSettle();
      expect(
        transporte.chamadasProprio,
        1,
        reason: 'o build virou consulta — §20 do Perfil publicável',
      );
    });

    testWidgets('C13 — três retries concorrentes produzem UMA chamada', (
      tester,
    ) async {
      transporte.automatico = false;
      abrir();
      auth.add('uid-a');
      ranking.aoMudarSessao(geracao: 1, publicId: contaA);
      await montar(tester);
      expect(transporte.chamadasProprio, 1);

      transporte.proprios.single.complete(
        FotografiaRanking.daAbertura(aberturaCom()),
      );
      await tester.pumpAndSettle();

      // Três toques seguidos no retry.
      ranking.recarregar();
      ranking.recarregar();
      ranking.recarregar();
      await tester.pumpAndSettle();
      expect(
        transporte.chamadasProprio,
        2,
        reason: 'o dedupe por chave não segurou os três toques',
      );
    });

    testWidgets(
      'C6 — resposta antiga, depois da troca de sessão, não aparece',
      (tester) async {
        transporte.automatico = false;
        abrir();
        auth.add('uid-a');
        ranking.aoMudarSessao(geracao: 1, publicId: contaA);
        await montar(tester);

        final voo = transporte.proprios.single;
        // A sessão troca ANTES de a resposta chegar.
        fonte.publicId = contaB;
        ranking.aoMudarSessao(geracao: 2, publicId: contaB);
        await tester.pumpAndSettle();

        voo.complete(
          FotografiaRanking.daAbertura(aberturaCom(liga: 'Diamante')),
        );
        await tester.pumpAndSettle();

        final vm = vmNaTela(tester);
        expect(
          vm.ranking.liga,
          isNot('Diamante'),
          reason: 'a liga da sessão anterior apareceu para a conta nova',
        );
        expect(textoDaTela(tester), isNot(contains('Diamante')));
      },
    );

    testWidgets('C7 — resposta de temporada vencida não aparece', (
      tester,
    ) async {
      transporte.automatico = false;
      abrir();
      auth.add('uid-a');
      ranking.aoMudarSessao(geracao: 1, publicId: contaA);
      await montar(tester);

      // O pedido do próprio (#1) fica em voo; um pedido público (#2) nasce
      // depois e é atendido primeiro, trazendo a temporada NOVA.
      final vooProprio = transporte.proprios.single;
      final leitor = ranking.leitor;
      final vooPublico = leitor.rankingPublico(
        contaPublicId: contaA,
        alvoPublicId: alvoX,
      );
      transporte.publicos.single.complete(
        FotografiaRanking.doPerfilPublico(
          publicoCom(id: alvoX, temporadaId: 'T-2026-02'),
        ),
      );
      await vooPublico;

      // Agora a resposta VENCIDA do próprio chega.
      vooProprio.complete(
        FotografiaRanking.daAbertura(
          aberturaCom(liga: 'Diamante', temporadaId: 'T-2026-01'),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        vmNaTela(tester).ranking.liga,
        isNot('Diamante'),
        reason: 'a fotografia da temporada vencida foi publicada na tela',
      );
      expect(textoDaTela(tester), isNot(contains('Diamante')));
    });

    // =====================================================================
    // Perfil VISITADO
    // =====================================================================

    testWidgets('C3 — o visitado é escolhido SÓ pelo publicIdVisitado', (
      tester,
    ) async {
      abrir();
      auth.add('uid-a');
      ranking.aoMudarSessao(geracao: 1, publicId: contaA);
      await montar(tester, ehMeuPerfil: false, visitado: alvoX);

      expect(transporte.chamadasPublico, 1);
      expect(
        transporte.idsConsultados,
        [alvoX],
        reason: 'o alvo saiu de outro lugar que não o publicIdVisitado',
      );
      final vm = vmNaTela(tester);
      expect(vm.ranking.liga, 'Prata');
      expect(vm.ranking.posicaoMundial, 50);
    });

    testWidgets('C4 — visitado SEM alvo não chama o transporte', (
      tester,
    ) async {
      abrir();
      auth.add('uid-a');
      ranking.aoMudarSessao(geracao: 1, publicId: contaA);
      await montar(tester, ehMeuPerfil: false);

      expect(transporte.chamadasPublico, 0);
      final vm = vmNaTela(tester);
      expect(vm.ranking.temAlgumDado, isFalse);
      expect(vm.ranking.liga, isNull);
    });

    testWidgets('C5 — visitado SEM sessão não chama o transporte', (
      tester,
    ) async {
      abrir();
      // Nenhum `auth.add`: não há conta consultante.
      await montar(tester, ehMeuPerfil: false, visitado: alvoX);

      expect(
        transporte.chamadasPublico,
        0,
        reason: 'consultou terceiro sem conta consultante',
      );
      expect(vmNaTela(tester).ranking.temAlgumDado, isFalse);
    });

    // =====================================================================
    // O QUE O PERFIL PUBLICÁVEL NÃO DEIXA VOLTAR
    // =====================================================================

    testWidgets('C8 — sem nível, nada de "Nível null" na tela nem no convite', (
      tester,
    ) async {
      abrir();
      auth.add('uid-a');
      ranking.aoMudarSessao(geracao: 1, publicId: contaA);
      await montar(tester);

      final vm = vmNaTela(tester);
      expect(vm.nivel, isNull);
      final texto = textoDaTela(tester);
      expect(texto, isNot(contains('Nível null')));
      expect(texto, isNot(contains('Nível 1')));
      final convite = PerfilPage.textoDeCompartilhamento(vm);
      expect(convite, isNot(contains('Nível')));
      expect(convite, isNot(contains('null')));
    });

    testWidgets('C9 — sem liga, nada de Bronze na tela nem no convite', (
      tester,
    ) async {
      transporte.respostaPropria = aberturaCom(liga: '', ligaId: null);
      abrir();
      auth.add('uid-a');
      ranking.aoMudarSessao(geracao: 1, publicId: contaA);
      await montar(tester);

      final vm = vmNaTela(tester);
      expect(vm.ranking.liga, isNull);
      expect(textoDaTela(tester), isNot(contains('Bronze')));
      expect(PerfilPage.textoDeCompartilhamento(vm), isNot(contains('Bronze')));
    });

    testWidgets('C10 — sem colocação, nada de #0 nem de #1', (tester) async {
      transporte.respostaPropria = aberturaCom(posicao: 0);
      abrir();
      auth.add('uid-a');
      ranking.aoMudarSessao(geracao: 1, publicId: contaA);
      await montar(tester);

      final vm = vmNaTela(tester);
      expect(vm.ranking.posicaoMundial, isNull);
      final texto = textoDaTela(tester);
      expect(texto, isNot(contains('#0')));
      expect(texto, isNot(contains('#1')));
      expect(texto, isNot(contains('no mundo')));
      expect(
        PerfilPage.textoDeCompartilhamento(vm),
        isNot(contains('no mundo')),
      );
    });
  });

  // =========================================================================
  // AUDITORIA ESTRUTURAL DA UNIÃO
  // =========================================================================
  group('C11–C16 — as autoridades continuam únicas', () {
    late Set<String> alcancaveis;

    setUpAll(() {
      alcancaveis = alcancaveisDaRaiz();
      expect(alcancaveis, contains('lib/main.dart'));
      expect(alcancaveis.length, greaterThan(20));
    });

    test('C11 — o PerfilService não consulta ranking', () {
      final fonte = semComentarios(File('lib/services/perfil_service.dart'));
      for (final proibido in const [
        'leitor_ranking',
        'ranking_transporte',
        'LeitorDeRanking',
        'TransporteRanking',
        'EscopoRanking',
        'RankingDaSessao',
        'cloud_functions',
        'FirebaseAuth',
      ]) {
        expect(
          fonte,
          isNot(contains(proibido)),
          reason: 'o serviço passou a ser um segundo lugar que busca $proibido',
        );
      }
      // Ele recebe o estado pronto, e é só isso que sabe de ranking.
      expect(fonte, contains('EstadoRanking? ranking'));
    });

    test('C11b — só o adaptador de Firebase conhece cloud_functions', () {
      final donos = <String>[];
      for (final caminho in alcancaveis) {
        final f = File(caminho);
        if (!f.existsSync()) continue;
        if (semComentarios(f).contains('cloud_functions')) donos.add(caminho);
      }
      expect(
        donos..sort(),
        containsAll(<String>['lib/ranking/ranking_transporte_firebase.dart']),
      );
      for (final d in donos) {
        expect(
          d,
          anyOf(endsWith('_firebase.dart'), contains('colecao_firebase')),
          reason: '$d abriu uma segunda porta para as callables',
        );
      }
    });

    test('C11c — só a cadeia de sessão observa o Firebase Auth', () {
      final donos = <String>[];
      for (final caminho in alcancaveis) {
        final f = File(caminho);
        if (!f.existsSync()) continue;
        if (semComentarios(f).contains('firebase_auth')) donos.add(caminho);
      }
      for (final d in donos) {
        expect(
          _barras(d),
          contains('/sessao/'),
          reason: '$d é um segundo dono de autenticação',
        );
      }
      expect(donos, isNotEmpty, reason: 'a varredura precisa achar alguém');
    });

    test('C14 — a Mesa Online mantém as portas únicas', () {
      final tela = semComentarios(
        File('lib/casca/mesa_online/mesa_online_screen.dart'),
      );
      // O caminho online não constrói o motor da partida local.
      for (final proibido in const [
        'MesaScreen',
        'MotorDePartida',
        'motor/',
        'lib/mesa.dart',
      ]) {
        expect(
          tela,
          isNot(contains(proibido)),
          reason: 'a Mesa Online alcançou $proibido',
        );
      }
      // E as duas portas continuam existindo, alcançáveis pela raiz.
      expect(
        alcancaveis,
        contains('lib/casca/mesa_online/porta_de_comandos_online.dart'),
      );
      expect(
        alcancaveis,
        contains('lib/casca/mesa_online/estado_mesa_online.dart'),
      );
    });

    test('C15 — a cadeia Home → PerfilPage → PerfilScreen é única', () {
      final home = semComentarios(File('lib/casca/home_de_producao.dart'));
      expect(home, contains('PerfilPage('));

      // Ninguém alcançável pela raiz constrói PerfilScreen a não ser a página.
      final construtores = _quemConstroi(alcancaveis, 'PerfilScreen');
      expect(construtores, [
        'lib/pages/perfil_page.dart',
      ], reason: 'há um segundo caminho para a tela de Perfil');

      // E a página é alcançável a partir da raiz.
      expect(alcancaveis, contains('lib/pages/perfil_page.dart'));
      expect(alcancaveis, contains('lib/casca/home_de_producao.dart'));
    });

    test('C16 — main.dart permanece byte a byte o das duas entradas', () {
      // O merge-base `bc74e30` e as duas entradas têm o MESMO blob para este
      // arquivo. Se a composição o tivesse tocado, seria sinal de que a união
      // extravasou para a raiz — que nenhuma das duas entradas mexeu.
      final bytes = File('lib/main.dart').readAsBytesSync();
      final normalizado = utf8.decode(bytes).replaceAll('\r\n', '\n');
      final digest = sha256.convert(utf8.encode(normalizado)).toString();
      expect(
        digest,
        '8526fc0a1cb487b7ec37a27a6449b09f667c5d412968f69bb547c9f246d5a0ab',
        reason: 'main.dart mudou na composição',
      );
    });

    test('C17 — o ranking é alcançável pela raiz, e por um caminho só', () {
      for (final arquivo in const [
        'lib/ranking/escopo_ranking.dart',
        'lib/ranking/ranking_da_sessao.dart',
        'lib/ranking/leitor_ranking.dart',
        'lib/ranking/ranking_transporte.dart',
        'lib/ranking/ranking_transporte_firebase.dart',
        'lib/ranking/estado_ranking.dart',
      ]) {
        expect(alcancaveis, contains(arquivo), reason: '$arquivo ficou órfão');
      }

      // Quem constrói o leitor é a raiz do aplicativo, e mais ninguém.
      final construtores = _quemConstroi(alcancaveis, 'LeitorDeRanking');
      expect(construtores, [
        'lib/casca/raiz_do_aplicativo.dart',
      ], reason: 'há um segundo lugar que instancia o leitor');
    });
  });
}
