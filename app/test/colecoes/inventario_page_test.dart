// inventario_page_test.dart — a tela real contra um repositorio falso.
//
// Sobe `InventarioPage` de verdade, com `InventarioService` de verdade, e troca
// APENAS a fronteira: o repositorio (que seria Firestore) e a leitura do asset
// (que seria o rootBundle). O catalogo continua sendo o de producao, lido do
// disco pelo mesmo `test/suporte/seeds.dart` das demais suites.
//
// POR QUE NAO UM VM DE MENTIRA: a projecao ja tem cobertura propria em
// inventario_vm_test.dart. O que esta suite prova e o outro lado — que a tela
// consome a AUTORIDADE e nao um mock, que a escrita de equipagem sai com os
// itens certos, e que nenhum estado inventa posse.
//
// SUPERFICIE DE TELEFONE: o padrao do flutter_test e 800x600, uma janela de
// desktop deitada; a tela e de celular. Ver test/superficie_de_teste.dart.

import 'dart:async';

import 'package:buraco_master_vip/colecoes/colecao_campanha.dart';
import 'package:buraco_master_vip/colecoes/colecao_catalogo.dart';
import 'package:buraco_master_vip/colecoes/colecao_inventario.dart';
import 'package:buraco_master_vip/colecoes/colecao_repositorio.dart';
import 'package:buraco_master_vip/colecoes/colecao_ui_contract.dart';
import 'package:buraco_master_vip/pages/inventario_page.dart';
import 'package:buraco_master_vip/services/inventario_service.dart';
import 'package:buraco_master_vip/sessao/escopo_sessao.dart';
import 'package:buraco_master_vip/sessao/fonte_identidade.dart';
import 'package:buraco_master_vip/sessao/identidade_publica_sessao.dart';
import 'package:buraco_master_vip/sessao/sessao_do_jogador.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../superficie_de_teste.dart';
import '../suporte/seeds.dart';

const _uid = 'uid_pioneiro_1';
final _agora = DateTime.utc(2026, 8, 6, 12);

/// Repositorio de mentira. So implementa o que o inventario usa; o resto lanca,
/// para que um uso nao previsto apareca como falha e nao como silencio.
class RepositorioFalso implements ColecaoRepositorio {
  RepositorioFalso(this._itens);

  List<ItemInventario> _itens;

  /// Erro a devolver na proxima leitura, quando houver.
  ErroColecao? erroDeLeitura;

  /// Registro das escritas de equipagem, para conferir o que foi ao servidor.
  final List<({String equipado, List<String> desequipados})> equipagens = [];

  int leituras = 0;

  @override
  Future<InventarioUsuario> carregarInventario({
    required String uid,
    String? collectionId,
  }) async {
    leituras++;
    final erro = erroDeLeitura;
    if (erro != null) throw erro;
    return InventarioUsuario(uid, _itens.where((i) => i.userId == uid));
  }

  @override
  Future<void> aplicarEquipagem({
    required String uid,
    required String itemIdEquipado,
    required List<String> itemIdsDesequipados,
  }) async {
    equipagens.add((equipado: itemIdEquipado, desequipados: itemIdsDesequipados));
    _itens = [
      for (final item in _itens)
        if (item.itemId == itemIdEquipado)
          item.copiarCom(equipped: true)
        else if (itemIdsDesequipados.contains(item.itemId))
          item.copiarCom(equipped: false)
        else
          item,
    ];
  }

  @override
  Future<CampanhaColecao> carregarCampanha(String campaignId) =>
      throw UnimplementedError('o inventario nao le campanha');

  @override
  Future<bool> featureFlagLigada(CampanhaColecao campanha) =>
      throw UnimplementedError('o inventario nao le feature flag');

  @override
  Future<EvidenciaElegibilidade> carregarEvidencia({
    required String campaignId,
    required String uid,
  }) =>
      throw UnimplementedError('o inventario nao le elegibilidade');

  @override
  Future<RespostaResgate> resgatar(String campaignId) =>
      throw UnimplementedError('o inventario NAO resgata');
}

/// Identidade pronta, sem rede.

/// Repositorio que permite PRENDER a leitura de um uid especifico.
///
/// E o que torna a corrida deterministica: sem um portao, "a resposta de A chega
/// depois da de B" dependeria de temporizacao e o teste passaria por sorte.
class RepositorioComPortao implements ColecaoRepositorio {
  RepositorioComPortao(this._itens);

  List<ItemInventario> _itens;

  final Map<String, Completer<void>> _portoes = {};

  /// Erro a lancar na leitura daquele uid, quando houver.
  final Map<String, ErroColecao> erroPorUid = {};

  final List<({String uid, String equipado, List<String> desequipados})>
      equipagens = [];

  void prender(String uid) => _portoes[uid] = Completer<void>();

  void soltar(String uid) => _portoes.remove(uid)?.complete();

  @override
  Future<InventarioUsuario> carregarInventario({
    required String uid,
    String? collectionId,
  }) async {
    final portao = _portoes[uid];
    if (portao != null) await portao.future;
    final erro = erroPorUid[uid];
    if (erro != null) throw erro;
    return InventarioUsuario(uid, _itens.where((i) => i.userId == uid));
  }

  @override
  Future<void> aplicarEquipagem({
    required String uid,
    required String itemIdEquipado,
    required List<String> itemIdsDesequipados,
  }) async {
    equipagens.add((
      uid: uid,
      equipado: itemIdEquipado,
      desequipados: itemIdsDesequipados,
    ));
    _itens = [
      for (final item in _itens)
        if (item.itemId == itemIdEquipado)
          item.copiarCom(equipped: true)
        else if (itemIdsDesequipados.contains(item.itemId))
          item.copiarCom(equipped: false)
        else
          item,
    ];
  }

  @override
  Future<CampanhaColecao> carregarCampanha(String campaignId) =>
      throw UnimplementedError('o inventario nao le campanha');

  @override
  Future<bool> featureFlagLigada(CampanhaColecao campanha) =>
      throw UnimplementedError('o inventario nao le feature flag');

  @override
  Future<EvidenciaElegibilidade> carregarEvidencia({
    required String campaignId,
    required String uid,
  }) =>
      throw UnimplementedError('o inventario nao le elegibilidade');

  @override
  Future<RespostaResgate> resgatar(String campaignId) =>
      throw UnimplementedError('o inventario NAO resgata');
}

class FonteFixa implements FonteDeIdentidade {
  FonteFixa(this.uid);

  final String uid;

  @override
  Future<IdentidadePublica> obterMinhaIdentidade() async => IdentidadePublica(
        publicId: 'P0A1B2C3D4E5',
        apelido: 'Sônia',
        avatarRef: null,
        criada: false,
        estado: EstadoPerfil.ativo,
        limites: LimitesSociais.desconhecidos,
        edicao: MetadadosDeEdicao.desconhecidos,
      );
}

ItemInventario _item(String itemId, {bool equipped = false, String userId = _uid}) =>
    ItemInventario(
      userId: userId,
      itemId: itemId,
      collectionId: ColecaoIds.pioneiros2026,
      origem: OrigemItem.campanha,
      campaignId: 'pioneiros_2026',
      campaignVersion: 1,
      unlockedAt: _agora,
      equipped: equipped,
    );

void main() {
  final catalogoBruto =
      arquivoDeSeed('colecoes', 'catalogo.seed.json').readAsStringSync();

  InventarioService servicoCom(RepositorioFalso repo) => InventarioService(
        repositorio: repo,
        lerAsset: (_) async => catalogoBruto,
      );

  /// Monta a tela com uma sessao ja autenticada (ou sem nenhuma).
  Future<void> montar(
    WidgetTester tester,
    InventarioService service, {
    String? uid = _uid,
  }) async {
    usarTelefoneRetrato(tester);
    ignorarOverflowDaFonteDeTeste();

    final sessao = SessaoDoJogador(
      fonte: FonteFixa(uid ?? ''),
      uids: const Stream<String?>.empty(),
      uidInicial: uid,
    );
    addTearDown(sessao.dispose);

    await tester.pumpWidget(EscopoSessao(
      sessao: sessao,
      child: MaterialApp(home: InventarioPage(serviceParaTeste: service)),
    ));
    // Sem duracao os eventos de identidade e a leitura do repositorio nao sao
    // entregues; `pumpAndSettle` sozinho devolveria com a carga pela metade.
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('mostra as pecas do jogador, e apenas elas', (tester) async {
    final repo = RepositorioFalso([
      _item(ColecaoItemIds.pioneerCrown),
      _item(ColecaoItemIds.pioneerEmblem),
    ]);
    await montar(tester, servicoCom(repo));

    expect(find.text('Coroa dos Pioneiros'), findsOneWidget);
    expect(find.text('Emblema Oficial dos Pioneiros'), findsOneWidget);
    expect(find.text('2 de 10'), findsOneWidget);

    // As oito pecas restantes existem no catalogo e NAO sao do jogador: nenhuma
    // delas pode aparecer, em nenhuma forma.
    expect(find.text('Trono Real dos Pioneiros'), findsNothing);
    expect(find.text('Bau dos Pioneiros'), findsNothing);
    expect(find.text('Dragao Imperial Pioneiro'), findsNothing);
  });

  testWidgets('acervo vazio nao vira convite nem oferta', (tester) async {
    final repo = RepositorioFalso(const []);
    await montar(tester, servicoCom(repo));

    expect(find.text('Nada por aqui ainda'), findsOneWidget);
    // Nenhuma peca do catalogo aparece como isca.
    expect(find.text('Coroa dos Pioneiros'), findsNothing);
    expect(find.textContaining('Comprar'), findsNothing);
    expect(find.textContaining('Resgatar'), findsNothing);
  });

  testWidgets('sem sessao diz que falta entrar, e nao que falta item',
      (tester) async {
    final repo = RepositorioFalso([_item(ColecaoItemIds.pioneerCrown)]);
    await montar(tester, servicoCom(repo), uid: null);

    expect(find.text('Entra na tua conta'), findsOneWidget);
    expect(find.text('Nada por aqui ainda'), findsNothing);
    // Nao ha de quem ler posse: o repositorio nem chega a ser consultado.
    expect(repo.leituras, 0);
  });

  testWidgets('item equipado aparece na vitrine, sem botao de equipar',
      (tester) async {
    final repo = RepositorioFalso([
      _item(ColecaoItemIds.pioneerCrown, equipped: true),
    ]);
    await montar(tester, servicoCom(repo));

    expect(find.text('Na vitrine'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Equipar'), findsNothing);
  });

  testWidgets('peca de exibicao nao ganha botao de equipar', (tester) async {
    // O Bau nao tem slot: possuido, porem nao vai para a vitrine.
    final repo = RepositorioFalso([_item(ColecaoItemIds.pioneerChest)]);
    await montar(tester, servicoCom(repo));

    expect(find.text('Bau dos Pioneiros'), findsOneWidget);
    expect(find.text('Peça de exibição'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Equipar'), findsNothing);
  });

  testWidgets('equipar grava no servidor e troca o ocupante do slot',
      (tester) async {
    // Os dois mascotes disputam o mesmo slot, com maxAtivos 1.
    final repo = RepositorioFalso([
      _item(ColecaoItemIds.pioneerMascotBulldog, equipped: true),
      _item(ColecaoItemIds.pioneerMascotOwl),
    ]);
    await montar(tester, servicoCom(repo));

    await tester.tap(find.widgetWithText(FilledButton, 'Equipar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // A escrita saiu UMA vez, com o entrante e o item que saiu do slot — quem
    // decide a troca e o dominio, e a tela nao pode ter escolhido sozinha.
    expect(repo.equipagens, hasLength(1));
    expect(repo.equipagens.single.equipado, ColecaoItemIds.pioneerMascotOwl);
    expect(
      repo.equipagens.single.desequipados,
      [ColecaoItemIds.pioneerMascotBulldog],
    );

    // E a tela reflete a troca: uma peca na vitrine, e a outra equipavel.
    expect(find.text('Na vitrine'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Equipar'), findsOneWidget);
  });

  testWidgets('falha de leitura mostra o erro e oferece tentar de novo',
      (tester) async {
    final repo = RepositorioFalso([_item(ColecaoItemIds.pioneerCrown)])
      ..erroDeLeitura =
          const ErroColecao(FalhaBackend.indisponivel, 'sem rede');
    await montar(tester, servicoCom(repo));

    expect(find.text('Não deu para carregar'), findsOneWidget);
    expect(find.textContaining('Sem conexão'), findsOneWidget);

    // Some com o erro e repete: a tela nao pode ficar presa no estado de falha.
    repo.erroDeLeitura = null;
    await tester.tap(find.widgetWithText(FilledButton, 'Tentar de novo'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Coroa dos Pioneiros'), findsOneWidget);
  });

  testWidgets('trocar de conta nao mostra o acervo do dono anterior',
      (tester) async {
    final repo = RepositorioFalso([
      _item(ColecaoItemIds.pioneerCrown),
      _item(ColecaoItemIds.pioneerEmblem, userId: 'outro_uid'),
    ]);
    final service = servicoCom(repo);

    expect((await service.carregar(_uid))!.totalItens, 1);

    final doOutro = (await service.carregar('outro_uid'))!;
    expect(doOutro.totalItens, 1);
    expect(
      doOutro.grupos.single.itens.single.id,
      ColecaoItemIds.pioneerEmblem,
      reason: 'o acervo do jogador anterior nao pode vazar para o novo',
    );
  });

  testWidgets('equipar antes de carregar nao inventa inventario',
      (tester) async {
    final repo = RepositorioFalso([_item(ColecaoItemIds.pioneerCrown)]);
    final service = servicoCom(repo);

    await expectLater(
      service.equipar(_uid, ColecaoItemIds.pioneerCrown),
      throwsA(isA<InventarioIndisponivel>()),
    );
    expect(repo.equipagens, isEmpty);
  });

  group('troca de conta A -> B com resposta atrasada', () {
    // `Future` nao se cancela em Dart: a leitura de A CONTINUA depois de o
    // jogador trocar de conta, e vai terminar. Estes casos prendem a leitura de
    // A num portao, deixam a de B passar inteira, e so entao soltam A — que e a
    // ordem que acontece de verdade quando a rede de A esta lenta.

    late RepositorioComPortao repo;
    late InventarioService service;

    setUp(() {
      repo = RepositorioComPortao([
        _item(ColecaoItemIds.pioneerCrown, userId: 'uid_a'),
        _item(ColecaoItemIds.pioneerEmblem, userId: 'uid_b'),
      ]);
      service = InventarioService(
        repositorio: repo,
        lerAsset: (_) async => catalogoBruto,
      );
    });

    test('o acervo de A nao APARECE depois de B ter carregado', () async {
      repo.prender('uid_a');

      final futuroA = service.carregar('uid_a');
      final vmB = await service.carregar('uid_b');

      expect(vmB!.grupos.single.itens.single.id, ColecaoItemIds.pioneerEmblem);

      // A resposta de A chega agora, atrasada.
      repo.soltar('uid_a');
      final vmA = await futuroA;

      expect(
        vmA,
        isNull,
        reason: 'leitura superada tem de ser descartada, nao entregue a tela',
      );
    });

    test('o acervo de A nao e ACEITO em B: equipar segue sendo de B', () async {
      repo.prender('uid_a');
      final futuroA = service.carregar('uid_a');
      await service.carregar('uid_b');
      repo.soltar('uid_a');
      await futuroA;

      // Se a resposta atrasada de A tivesse vencido, o estado em memoria seria
      // o de A e esta chamada seria recusada — ou, pior, gravaria item de A.
      final aplicada = await service.equipar('uid_b', ColecaoItemIds.pioneerEmblem);

      expect(aplicada.aceita, isTrue);
      expect(repo.equipagens.single.equipado, ColecaoItemIds.pioneerEmblem);
      expect(repo.equipagens.single.uid, 'uid_b');
    });

    test('item de A nunca e aceito em nome de B', () async {
      repo.prender('uid_a');
      final futuroA = service.carregar('uid_a');
      await service.carregar('uid_b');
      repo.soltar('uid_a');
      await futuroA;

      // A Coroa e de A. Pedi-la em nome de B tem de ser recusado pelo dominio,
      // e nada pode chegar ao servidor.
      final aplicada = await service.equipar('uid_b', ColecaoItemIds.pioneerCrown);

      expect(aplicada.aceita, isFalse);
      expect(aplicada.recusa, RecusaEquipagem.itemNaoPossuido);
      expect(repo.equipagens, isEmpty);
    });

    test('sair da conta durante a leitura descarta a resposta', () async {
      repo.prender('uid_a');
      final futuroA = service.carregar('uid_a');

      // Logout: a sessao canonica passa a nao ter uid.
      final vmSaida = await service.carregar(null);
      expect(vmSaida!.estado, EstadoInventario.semSessao);

      repo.soltar('uid_a');
      expect(await futuroA, isNull);

      // E nada ficou em memoria para equipar.
      await expectLater(
        service.equipar('uid_a', ColecaoItemIds.pioneerCrown),
        throwsA(isA<InventarioIndisponivel>()),
      );
    });

    test('erro de uma leitura superada nao vira erro na tela de B', () async {
      repo.prender('uid_a');
      repo.erroPorUid['uid_a'] =
          const ErroColecao(FalhaBackend.indisponivel, 'sem rede');

      final futuroA = service.carregar('uid_a');
      final vmB = await service.carregar('uid_b');
      expect(vmB, isNotNull);

      repo.soltar('uid_a');

      // Sem a trava, este `await` lancaria e a tela de B mostraria "sem conexao"
      // por causa de um pedido que nao e mais dela.
      expect(await futuroA, isNull);
    });
  });
}
