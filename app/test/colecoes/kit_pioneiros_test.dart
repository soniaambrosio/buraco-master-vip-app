// kit_pioneiros_test.dart — cobertura do dominio do Kit Pioneiros 2026.
//
// Dart puro sobre flutter_test: nao sobe widget, nao toca Firebase e nao le
// rede. Os seeds reais entram por arquivo (copiados para test/colecoes/data/
// pelo workflow), de modo que o teste valida a CONFIGURACAO DE PRODUCAO e nao
// apenas o codigo.
//
// A suite esta organizada pelos criterios de aceite da ordem de servico: cada
// grupo abaixo corresponde a uma linha da secao 9.

import 'dart:convert';
import 'dart:io';

import 'package:buraco_master_vip/colecoes/colecao_campanha.dart';
import 'package:buraco_master_vip/colecoes/colecao_catalogo.dart';
import 'package:buraco_master_vip/colecoes/colecao_inventario.dart';
import 'package:buraco_master_vip/colecoes/colecao_resgate.dart';
import 'package:buraco_master_vip/colecoes/colecao_ui_contract.dart';
import 'package:flutter_test/flutter_test.dart';

const _uid = 'uid_pioneiro_1';
const _outroUid = 'uid_pioneiro_2';

/// Instante de referencia. Fixo de proposito: nenhum teste le o relogio.
final _agora = DateTime.utc(2026, 8, 6, 12);

String _lerArquivo(String nome) {
  final arquivo = File('test/colecoes/data/$nome');
  if (!arquivo.existsSync()) {
    throw StateError('arquivo de teste nao encontrado: ${arquivo.path}');
  }
  return arquivo.readAsStringSync();
}

Map<String, dynamic> _lerJson(String nome) =>
    jsonDecode(_lerArquivo(nome)) as Map<String, dynamic>;

/// Copia o mapa da campanha aplicando sobrescritas, para exercitar
/// configuracoes que nao sao a de producao.
Map<String, dynamic> _campanhaCom(
  Map<String, dynamic> raiz,
  Map<String, dynamic> sobrescrever,
) {
  final copia = jsonDecode(jsonEncode(raiz['campanha'])) as Map<String, dynamic>;
  copia.addAll(sobrescrever);
  return copia;
}

/// Inventario com os itens da campanha ja concedidos.
InventarioUsuario _inventarioCompleto(CampanhaColecao campanha, {String userId = _uid}) =>
    InventarioUsuario(
      userId,
      campanha.rewardIds.map((id) => ItemInventario(
            userId: userId,
            itemId: id,
            collectionId: campanha.collectionId,
            origem: OrigemItem.campanha,
            campaignId: campanha.campaignId,
            campaignVersion: campanha.version,
            unlockedAt: _agora,
          )),
    );

void main() {
  final catalogoRaiz = _lerJson('catalogo.seed.json');
  final campanhaRaiz = _lerJson('campanha_pioneiros_2026.seed.json');
  final manifesto = _lerJson('pioneiros_2026.manifest.json');

  final catalogo = CatalogoColecoes.fromMap(catalogoRaiz);
  final campanha = CampanhaColecao.fromMap(campanhaRaiz['campanha'] as Map<String, dynamic>);

  /// Campanha ativa, sem janela — a configuracao mais comum nos testes de fluxo.
  final campanhaAtiva = CampanhaColecao.fromMap(
    _campanhaCom(campanhaRaiz, {'status': 'active'}),
  );

  // ==========================================================================
  group('catalogo', () {
    test('o seed de producao carrega', () {
      expect(catalogo.schemaVersion, 1);
      expect(catalogo.colecoes, hasLength(1));
    });

    test('a colecao declara exatamente os dez itens do contrato', () {
      expect(
        () => catalogo.validarComposicao(
            ColecaoIds.pioneiros2026, ColecaoItemIds.pioneiros2026),
        returnsNormally,
      );
      expect(catalogo.itensDe(ColecaoIds.pioneiros2026), hasLength(10));
    });

    test('nenhum item aparece a venda e nenhum preco existe', () {
      final colecao = catalogo.colecao(ColecaoIds.pioneiros2026);
      expect(colecao.purchasable, isFalse);
      expect(colecao.transferable, isFalse);
      expect(colecao.tradable, isFalse);
      expect(colecao.revocable, isFalse);
      expect(colecao.visivelNaLoja, isFalse);
      // Nenhum campo de preco foi sequer modelado: o DTO nao tem onde guardar um.
      for (final bruto in (catalogoRaiz['colecoes'] as List)) {
        for (final item in ((bruto as Map)['itens'] as List).cast<Map<String, dynamic>>()) {
          expect(item.keys, isNot(contains('price')));
          expect(item.keys, isNot(contains('preco')));
        }
      }
    });

    test('carregar um seed com purchasable true e recusado', () {
      final adulterado = jsonDecode(jsonEncode(catalogoRaiz)) as Map<String, dynamic>;
      (adulterado['colecoes'] as List).first['purchasable'] = true;
      expect(() => CatalogoColecoes.fromMap(adulterado), throwsFormatException);
    });

    test('os tres mascotes sao itens distintos no mesmo slot', () {
      final mascotes = catalogo
          .itensDe(ColecaoIds.pioneiros2026)
          .where((i) => i.categoria == 'mascot')
          .toList();
      expect(mascotes, hasLength(3));
      expect(mascotes.map((m) => m.itemId).toSet(), hasLength(3));
      expect(mascotes.map((m) => m.slot).toSet(), {'mascote'});
    });

    test('cada peca cai numa categoria e num slot declarados', () {
      for (final item in catalogo.itensDe(ColecaoIds.pioneiros2026)) {
        expect(item.categoria, isNotEmpty);
        if (item.equipavel) {
          expect(catalogo.buscarSlot(item.slot!), isNotNull,
              reason: '${item.itemId} aponta para slot nao declarado');
        } else {
          expect(item.slot, isNull);
        }
      }
    });

    test('o Bau consta no catalogo e nao e equipavel', () {
      final bau = catalogo[ColecaoItemIds.pioneerChest];
      expect(bau.equipavel, isFalse);
      expect(bau.slot, isNull);
      expect(bau.assetPath, isNotEmpty);
    });

    test('assetPath e unico: nenhuma arte duplicada no bundle', () {
      final caminhos = catalogo.itens.map((i) => i.arte.chaveCache).toList();
      expect(caminhos.toSet(), hasLength(caminhos.length));
    });

    test('item equipavel sem slot e recusado', () {
      final adulterado = jsonDecode(jsonEncode(catalogoRaiz)) as Map<String, dynamic>;
      final itens = (adulterado['colecoes'] as List).first['itens'] as List;
      (itens.first as Map<String, dynamic>)['slot'] = null;
      expect(() => CatalogoColecoes.fromMap(adulterado), throwsFormatException);
    });
  });

  // ==========================================================================
  group('manifesto e preservacao da arte', () {
    test('o catalogo aponta para os dez arquivos do manifesto', () {
      final noManifesto = (manifesto['items'] as List)
          .cast<Map<String, dynamic>>()
          .map((i) => i['file'] as String)
          .toSet();
      expect(noManifesto, hasLength(10));

      final noCatalogo = catalogo
          .itensDe(ColecaoIds.pioneiros2026)
          .map((i) => i.assetPath!.split('/').last)
          .toSet();
      expect(noCatalogo, noManifesto,
          reason: 'renomear arquivo sem atualizar o catalogo quebra a colecao');
    });

    test('itemId do catalogo e id do manifesto sao os mesmos', () {
      final noManifesto = (manifesto['items'] as List)
          .cast<Map<String, dynamic>>()
          .map((i) => i['id'] as String)
          .toSet();
      expect(noManifesto, ColecaoItemIds.pioneiros2026.toSet());
    });

    test('o manifesto registra alpha real em 1254x1254 nas dez pecas', () {
      for (final item in (manifesto['items'] as List).cast<Map<String, dynamic>>()) {
        expect(item['width'], 1254, reason: '${item['id']}');
        expect(item['height'], 1254, reason: '${item['id']}');
        expect(item['mode'], 'RGBA', reason: '${item['id']}');
        expect(item['alpha_min'], 0, reason: '${item['id']}');
        expect(item['alpha_max'], 255, reason: '${item['id']}');
      }
    });

    test('todos os assets moram numa unica pasta', () {
      final pastas = catalogo
          .itensDe(ColecaoIds.pioneiros2026)
          .map((i) => i.assetPath!.substring(0, i.assetPath!.lastIndexOf('/')))
          .toSet();
      expect(pastas, {'assets/colecoes/pioneiros_2026'});
    });

    test('as regras de exibicao proibem corte e precache total', () {
      expect(RegrasDeExibicao.usarBoxFitContain, isTrue);
      expect(RegrasDeExibicao.preservarTransparencia, isTrue);
      expect(RegrasDeExibicao.paddingVisualMinimo, greaterThanOrEqualTo(0.08));
      expect(RegrasDeExibicao.precachearTudoNaAbertura, isFalse);
    });
  });

  // ==========================================================================
  group('campanha', () {
    test('o seed de producao carrega e promete a composicao exata', () {
      expect(campanha.campaignId, 'pioneiros_2026');
      expect(campanha.collectionId, ColecaoIds.pioneiros2026);
      expect(campanha.featureFlag, 'kitPioneiros2026Enabled');
      expect(() => campanha.validarComposicao(ColecaoItemIds.pioneiros2026),
          returnsNormally);
      expect(campanha.rewardIds, hasLength(10));
    });

    test('e entregue inativa, para a Sonia decidir o momento da ativacao', () {
      expect(campanha.status, StatusCampanha.draft);
      expect(campanha.status.concede, isFalse);
      expect(campanha.catalogVisibility, VisibilidadeCatalogo.hidden);
    });

    test('a fonte de elegibilidade e uma subcolecao, nao um array de UIDs', () {
      expect(campanha.eligibilitySource, contains('/eligible/'));
      expect(campanha.eligibilitySource, contains('{uid}'));
    });

    test('data sem sufixo Z e recusada', () {
      expect(
        () => CampanhaColecao.fromMap(
            _campanhaCom(campanhaRaiz, {'startAt': '2026-08-06T12:00:00'})),
        throwsFormatException,
      );
    });

    test('janela invertida e recusada', () {
      expect(
        () => CampanhaColecao.fromMap(_campanhaCom(campanhaRaiz, {
          'startAt': '2026-09-01T00:00:00Z',
          'endAt': '2026-08-01T00:00:00Z',
        })),
        throwsFormatException,
      );
    });

    test('rewardIds com item repetido e recusado', () {
      expect(
        () => CampanhaColecao.fromMap(_campanhaCom(campanhaRaiz, {
          'rewardIds': [ColecaoItemIds.pioneerCrown, ColecaoItemIds.pioneerCrown],
        })),
        throwsFormatException,
      );
    });
  });

  // ==========================================================================
  group('elegibilidade', () {
    VeredictoElegibilidade avaliar({
      CampanhaColecao? c,
      EvidenciaElegibilidade evidencia = const EvidenciaElegibilidade(naAllowlist: true),
      bool flag = true,
      DateTime? agora,
    }) =>
        avaliarElegibilidade(
          campanha: c ?? campanhaAtiva,
          evidencia: evidencia,
          featureFlagLigada: flag,
          agora: agora ?? _agora,
        );

    test('flag desligada recusa antes de qualquer outra checagem', () {
      final v = avaliar(flag: false);
      expect(v.elegivel, isFalse);
      expect(v.recusa, RecusaElegibilidade.featureFlagDesligada);
    });

    test('campanha em draft nao concede nem para quem esta na allowlist', () {
      final v = avaliar(c: campanha);
      expect(v.recusa, RecusaElegibilidade.campanhaInativa);
    });

    test('campanha encerrada nao concede', () {
      final encerrada =
          CampanhaColecao.fromMap(_campanhaCom(campanhaRaiz, {'status': 'closed'}));
      expect(avaliar(c: encerrada).recusa, RecusaElegibilidade.campanhaInativa);
    });

    test('antes de startAt e depois de endAt recusa', () {
      final comJanela = CampanhaColecao.fromMap(_campanhaCom(campanhaRaiz, {
        'status': 'active',
        'startAt': '2026-08-10T00:00:00Z',
        'endAt': '2026-08-20T00:00:00Z',
      }));
      expect(avaliar(c: comJanela, agora: DateTime.utc(2026, 8, 9)).recusa,
          RecusaElegibilidade.foraDaJanelaAntes);
      expect(avaliar(c: comJanela, agora: DateTime.utc(2026, 8, 15)).elegivel, isTrue);
      expect(avaliar(c: comJanela, agora: DateTime.utc(2026, 8, 20)).recusa,
          RecusaElegibilidade.foraDaJanelaDepois,
          reason: 'a janela e fechada no inicio e aberta no fim');
    });

    test('claimDeadline vencido recusa mesmo dentro da janela', () {
      final comPrazo = CampanhaColecao.fromMap(_campanhaCom(campanhaRaiz, {
        'status': 'active',
        'startAt': '2026-08-01T00:00:00Z',
        'endAt': '2026-12-01T00:00:00Z',
        'claimDeadline': '2026-08-05T00:00:00Z',
      }));
      expect(avaliar(c: comPrazo).recusa, RecusaElegibilidade.prazoDeResgateEncerrado);
    });

    test('sem evidencia nenhuma, recusa', () {
      expect(avaliar(evidencia: EvidenciaElegibilidade.nenhuma).recusa,
          RecusaElegibilidade.semEvidencia);
    });

    test('cada modo aceita apenas a sua evidencia', () {
      final casos = <String, EvidenciaElegibilidade>{
        'allowlist': const EvidenciaElegibilidade(naAllowlist: true),
        'closedTest': const EvidenciaElegibilidade(participouTesteFechado: true),
        'matchInWindow': const EvidenciaElegibilidade(concluiuPartidaNaJanela: true),
      };
      for (final modo in casos.keys) {
        final c = CampanhaColecao.fromMap(
            _campanhaCom(campanhaRaiz, {'status': 'active', 'eligibilityMode': modo}));
        for (final entry in casos.entries) {
          final esperado = entry.key == modo;
          expect(avaliar(c: c, evidencia: entry.value).elegivel, esperado,
              reason: 'modo $modo com evidencia ${entry.key}');
        }
      }
    });

    test('hybrid aceita qualquer uma das tres evidencias', () {
      final c = CampanhaColecao.fromMap(
          _campanhaCom(campanhaRaiz, {'status': 'active', 'eligibilityMode': 'hybrid'}));
      expect(avaliar(c: c, evidencia: const EvidenciaElegibilidade(naAllowlist: true)).elegivel, isTrue);
      expect(avaliar(c: c, evidencia: const EvidenciaElegibilidade(participouTesteFechado: true)).elegivel, isTrue);
      expect(avaliar(c: c, evidencia: const EvidenciaElegibilidade(concluiuPartidaNaJanela: true)).elegivel, isTrue);
      expect(avaliar(c: c, evidencia: EvidenciaElegibilidade.nenhuma).elegivel, isFalse);
    });

    test('adminGrant so aceita concessao administrativa', () {
      final c = CampanhaColecao.fromMap(_campanhaCom(
          campanhaRaiz, {'status': 'active', 'eligibilityMode': 'adminGrant'}));
      expect(avaliar(c: c, evidencia: const EvidenciaElegibilidade(naAllowlist: true)).elegivel, isFalse);
      expect(
          avaliar(c: c, evidencia: const EvidenciaElegibilidade(concessaoAdministrativa: true))
              .elegivel,
          isTrue);
    });

    test('concessao administrativa atende um UID em qualquer modo, sem novo build', () {
      for (final modo in ModoElegibilidade.values) {
        final c = CampanhaColecao.fromMap(_campanhaCom(
            campanhaRaiz, {'status': 'active', 'eligibilityMode': modo.wire}));
        expect(
          avaliar(c: c, evidencia: const EvidenciaElegibilidade(concessaoAdministrativa: true))
              .elegivel,
          isTrue,
          reason: 'modo ${modo.wire}',
        );
      }
    });
  });

  // ==========================================================================
  group('resgate', () {
    ResultadoResgate resgatar({
      CampanhaColecao? c,
      EvidenciaElegibilidade evidencia = const EvidenciaElegibilidade(naAllowlist: true),
      bool flag = true,
      DateTime? agora,
      InventarioUsuario? inventario,
      ComprovanteResgate? comprovante,
      String userId = _uid,
    }) =>
        prepararResgate(
          campanha: c ?? campanhaAtiva,
          catalogo: catalogo,
          userId: userId,
          evidencia: evidencia,
          featureFlagLigada: flag,
          agora: agora ?? _agora,
          inventario: inventario ?? InventarioUsuario.vazio(userId),
          comprovanteExistente: comprovante,
        );

    test('elegivel recebe exatamente os dez itens numa unica operacao', () {
      final r = resgatar();
      expect(r.situacao, SituacaoResgate.concedido);
      expect(r.plano!.quantidade, 10);
      expect(r.plano!.itensAGravar.map((i) => i.itemId).toSet(),
          ColecaoItemIds.pioneiros2026.toSet());
      expect(r.plano!.comprovante.itemIds, hasLength(10));
    });

    test('todo item concedido carrega origem, campanha e versao', () {
      final r = resgatar();
      for (final item in r.plano!.itensAGravar) {
        expect(item.origem, OrigemItem.campanha);
        expect(item.campaignId, campanhaAtiva.campaignId);
        expect(item.campaignVersion, campanhaAtiva.version);
        expect(item.collectionId, ColecaoIds.pioneiros2026);
        expect(item.unlockedAt.isUtc, isTrue);
        expect(item.equipped, isFalse);
      }
    });

    test('nao elegivel nao resgata nem por chamada direta', () {
      final r = resgatar(evidencia: EvidenciaElegibilidade.nenhuma);
      expect(r.situacao, SituacaoResgate.recusado);
      expect(r.recusa, RecusaResgate.naoElegivel);
      expect(r.plano, isNull);
    });

    test('com a flag desligada nenhuma concessao ocorre', () {
      final r = resgatar(flag: false);
      expect(r.recusa, RecusaResgate.featureFlagDesligada);
      expect(r.exigeGravacao, isFalse);
    });

    test('campanha em draft nao concede', () {
      expect(resgatar(c: campanha).recusa, RecusaResgate.campanhaInativa);
    });

    test('segunda chamada devolve jaResgatado, sem erro e sem duplicidade', () {
      final primeiro = resgatar();
      final inventario = InventarioUsuario(_uid, primeiro.plano!.itensAGravar);

      final segundo = resgatar(
        inventario: inventario,
        comprovante: primeiro.plano!.comprovante,
      );
      expect(segundo.situacao, SituacaoResgate.jaResgatado);
      expect(segundo.exigeGravacao, isFalse);
      expect(segundo.comprovanteExistente!.itemIds, hasLength(10));
    });

    test('repetir dez vezes nao passa de dez itens', () {
      final primeiro = resgatar();
      var inventario = InventarioUsuario(_uid, primeiro.plano!.itensAGravar);
      for (var i = 0; i < 10; i++) {
        final r = resgatar(inventario: inventario, comprovante: primeiro.plano!.comprovante);
        if (r.exigeGravacao) {
          inventario = inventario.comItens(r.plano!.itensAGravar);
        }
      }
      expect(inventario.total, 10);
    });

    test('falha parcial e reconciliada de forma idempotente', () {
      final primeiro = resgatar();
      // Simula transacao interrompida: comprovante gravado, tres itens gravados.
      final parcial = InventarioUsuario(_uid, primeiro.plano!.itensAGravar.take(3));

      final r = resgatar(inventario: parcial, comprovante: primeiro.plano!.comprovante);
      expect(r.situacao, SituacaoResgate.reconciliado);
      expect(r.plano!.quantidade, 7);

      final completo = parcial.comItens(r.plano!.itensAGravar);
      expect(completo.total, 10);

      // Reconciliar de novo nao acha nada para fazer.
      final terceiro = resgatar(inventario: completo, comprovante: primeiro.plano!.comprovante);
      expect(terceiro.situacao, SituacaoResgate.jaResgatado);
    });

    test('a reconciliacao preserva o unlockedAt original do resgate', () {
      final primeiro = resgatar(agora: DateTime.utc(2026, 8, 6));
      final parcial = InventarioUsuario(_uid, primeiro.plano!.itensAGravar.take(1));

      final r = resgatar(
        inventario: parcial,
        comprovante: primeiro.plano!.comprovante,
        agora: DateTime.utc(2026, 11, 30),
      );
      for (final item in r.plano!.itensAGravar) {
        expect(item.unlockedAt, DateTime.utc(2026, 8, 6));
      }
    });

    test('quem ja resgatou nao perde o kit quando a campanha encerra', () {
      final primeiro = resgatar();
      final inventario = InventarioUsuario(_uid, primeiro.plano!.itensAGravar.take(4));
      final encerrada =
          CampanhaColecao.fromMap(_campanhaCom(campanhaRaiz, {'status': 'closed'}));

      final r = resgatar(
        c: encerrada,
        inventario: inventario,
        comprovante: primeiro.plano!.comprovante,
        evidencia: EvidenciaElegibilidade.nenhuma,
      );
      expect(r.situacao, SituacaoResgate.reconciliado,
          reason: 'o inventario e permanente; a campanha e que tem prazo');
      expect(r.plano!.quantidade, 6);
    });

    test('comprovante de outra versao nao e arbitrado automaticamente', () {
      final antigo = ComprovanteResgate(
        userId: _uid,
        campaignId: campanhaAtiva.campaignId,
        campaignVersion: 99,
        claimedAt: _agora,
        itemIds: ColecaoItemIds.pioneiros2026,
      );
      expect(resgatar(comprovante: antigo).recusa,
          RecusaResgate.comprovanteDeOutraVersao);
    });

    test('campanha que promete composicao diferente do catalogo e recusada', () {
      final divergente = CampanhaColecao.fromMap(_campanhaCom(campanhaRaiz, {
        'status': 'active',
        'rewardIds': ColecaoItemIds.pioneiros2026.take(9).toList(),
      }));
      expect(resgatar(c: divergente).recusa, RecusaResgate.composicaoInvalida);
    });

    test('o comprovante de um jogador nao vale para outro', () {
      final doOutro = ComprovanteResgate(
        userId: _outroUid,
        campaignId: campanhaAtiva.campaignId,
        campaignVersion: campanhaAtiva.version,
        claimedAt: _agora,
        itemIds: ColecaoItemIds.pioneiros2026,
      );
      expect(doOutro.chaveIdempotencia, isNot(ChaveResgate.de(
        campaignId: campanhaAtiva.campaignId,
        version: campanhaAtiva.version,
        userId: _uid,
      )));
    });
  });

  // ==========================================================================
  group('idempotencia', () {
    test('a chave e determinista e reproduzivel offline', () {
      String chave() => ChaveResgate.de(
            campaignId: 'pioneiros_2026',
            version: 1,
            userId: _uid,
          );
      expect(chave(), chave());
      expect(chave(), 'pioneiros_2026|1|$_uid');
    });

    test('a versao entra na chave: reedicao futura nao e lida como duplicidade', () {
      final v1 = ChaveResgate.de(campaignId: 'pioneiros_2026', version: 1, userId: _uid);
      final v2 = ChaveResgate.de(campaignId: 'pioneiros_2026', version: 2, userId: _uid);
      expect(v1, isNot(v2));
    });

    test('segmento com o separador e recusado, para nao colidir chaves', () {
      expect(
        () => ChaveResgate.de(campaignId: 'a|b', version: 1, userId: _uid),
        throwsArgumentError,
      );
    });

    test('comprovante com chave adulterada e recusado', () {
      final valido = ComprovanteResgate(
        userId: _uid,
        campaignId: 'pioneiros_2026',
        campaignVersion: 1,
        claimedAt: _agora,
        itemIds: ColecaoItemIds.pioneiros2026,
      ).toJson();
      valido['chaveIdempotencia'] = 'pioneiros_2026|1|outro_uid';
      expect(() => ComprovanteResgate.fromMap(valido), throwsFormatException);
    });

    test('comprovante com data sem sufixo Z e recusado', () {
      final bruto = ComprovanteResgate(
        userId: _uid,
        campaignId: 'pioneiros_2026',
        campaignVersion: 1,
        claimedAt: _agora,
        itemIds: ColecaoItemIds.pioneiros2026,
      ).toJson();
      bruto['claimedAt'] = '2026-08-06T12:00:00';
      expect(() => ComprovanteResgate.fromMap(bruto), throwsFormatException);
    });

    test('comprovante valido sobrevive a ida e volta por JSON', () {
      final original = ComprovanteResgate(
        userId: _uid,
        campaignId: 'pioneiros_2026',
        campaignVersion: 1,
        claimedAt: _agora,
        itemIds: ColecaoItemIds.pioneiros2026,
      );
      final volta = ComprovanteResgate.fromMap(
          jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>);
      expect(volta.chaveIdempotencia, original.chaveIdempotencia);
      expect(volta.itemIds, original.itemIds);
      expect(volta.claimedAt, original.claimedAt);
    });
  });

  // ==========================================================================
  group('inventario e equipagem', () {
    late InventarioUsuario cheio;

    setUp(() => cheio = _inventarioCompleto(campanhaAtiva));

    test('o inventario sobrevive a ida e volta por documento', () {
      final original = cheio.buscar(ColecaoItemIds.pioneerCrown)!;
      final volta = ItemInventario.fromMap(
          jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>);
      expect(volta.itemId, original.itemId);
      expect(volta.campaignVersion, original.campaignVersion);
      expect(volta.unlockedAt, original.unlockedAt);
    });

    test('documento de campanha sem campaignId e recusado', () {
      final bruto = cheio.buscar(ColecaoItemIds.pioneerCrown)!.toJson();
      bruto['campaignId'] = null;
      expect(() => ItemInventario.fromMap(bruto), throwsFormatException);
    });

    test('anexar os mesmos itens de novo nao duplica nada', () {
      final denovo = cheio.comItens(cheio.itens);
      expect(denovo.total, 10);
    });

    test('equipar um mascote desequipa o anterior: tres possuidos, um ativo', () {
      final r1 = cheio.equipar(ColecaoItemIds.pioneerMascotBulldog, catalogo);
      expect(r1.aceita, isTrue);
      expect(r1.desequipados, isEmpty);

      final r2 = r1.inventario!.equipar(ColecaoItemIds.pioneerMascotDragon, catalogo);
      expect(r2.aceita, isTrue);
      expect(r2.desequipados, [ColecaoItemIds.pioneerMascotBulldog]);

      final inv = r2.inventario!;
      expect(inv.equipadosNoSlot('mascote', catalogo), hasLength(1));
      expect(inv.estaEquipado(ColecaoItemIds.pioneerMascotDragon), isTrue);
      expect(inv.estaEquipado(ColecaoItemIds.pioneerMascotBulldog), isFalse);
      // Possuir os tres continua valendo.
      expect(inv.possui(ColecaoItemIds.pioneerMascotOwl), isTrue);
    });

    test('emblema e medalhao dividem o slot: so um representa o jogador', () {
      final r1 = cheio.equipar(ColecaoItemIds.pioneerEmblem, catalogo);
      final r2 = r1.inventario!.equipar(ColecaoItemIds.pioneerMedallion, catalogo);
      expect(r2.desequipados, [ColecaoItemIds.pioneerEmblem]);
      expect(r2.inventario!.equipadosNoSlot('emblema', catalogo), hasLength(1));
    });

    test('trono e estatua dividem o slot de vitrine', () {
      final r1 = cheio.equipar(ColecaoItemIds.pioneerThrone, catalogo);
      final r2 = r1.inventario!.equipar(ColecaoItemIds.pioneerStatue, catalogo);
      expect(r2.desequipados, [ColecaoItemIds.pioneerThrone]);
    });

    test('slots diferentes convivem equipados ao mesmo tempo', () {
      var inv = cheio;
      for (final id in [
        ColecaoItemIds.pioneerCrown,
        ColecaoItemIds.pioneerEmblem,
        ColecaoItemIds.pioneerMascotOwl,
        ColecaoItemIds.pioneerVortex,
        ColecaoItemIds.pioneerThrone,
      ]) {
        final r = inv.equipar(id, catalogo);
        expect(r.aceita, isTrue, reason: id);
        inv = r.inventario!;
      }
      expect(inv.itens.where((i) => i.equipped), hasLength(5));
    });

    test('o Bau nao pode ser equipado', () {
      final r = cheio.equipar(ColecaoItemIds.pioneerChest, catalogo);
      expect(r.aceita, isFalse);
      expect(r.recusa, RecusaEquipagem.itemNaoEquipavel);
    });

    test('item nao possuido nao pode ser equipado', () {
      final vazio = InventarioUsuario.vazio(_uid);
      expect(vazio.equipar(ColecaoItemIds.pioneerCrown, catalogo).recusa,
          RecusaEquipagem.itemNaoPossuido);
    });

    test('itemId desconhecido e recusado', () {
      expect(cheio.equipar('nao_existe', catalogo).recusa,
          RecusaEquipagem.itemInexistente);
    });

    test('equipar duas vezes o mesmo item e recusa explicita', () {
      final r = cheio.equipar(ColecaoItemIds.pioneerCrown, catalogo);
      expect(r.inventario!.equipar(ColecaoItemIds.pioneerCrown, catalogo).recusa,
          RecusaEquipagem.jaEquipado);
    });

    test('desequipar libera o slot', () {
      final r1 = cheio.equipar(ColecaoItemIds.pioneerCrown, catalogo);
      final r2 = r1.inventario!.desequipar(ColecaoItemIds.pioneerCrown, catalogo);
      expect(r2.aceita, isTrue);
      expect(r2.inventario!.equipadosNoSlot('coroa', catalogo), isEmpty);
      expect(r2.inventario!.possui(ColecaoItemIds.pioneerCrown), isTrue);
    });

    test('desequipar o que nao estava equipado e recusa explicita', () {
      expect(cheio.desequipar(ColecaoItemIds.pioneerCrown, catalogo).recusa,
          RecusaEquipagem.naoEstavaEquipado);
    });

    test('a equipagem permanece apos ida e volta pelo documento', () {
      final r = cheio.equipar(ColecaoItemIds.pioneerMascotOwl, catalogo);
      final reidratado = InventarioUsuario(
        _uid,
        r.inventario!.itens.map((i) => ItemInventario.fromMap(
            jsonDecode(jsonEncode(i.toJson())) as Map<String, dynamic>)),
      );
      expect(reidratado.estaEquipado(ColecaoItemIds.pioneerMascotOwl), isTrue);
      expect(reidratado.total, 10);
    });

    test('inventario nao aceita item de outro jogador', () {
      expect(
        () => InventarioUsuario(_uid, [
          ItemInventario(
            userId: _outroUid,
            itemId: ColecaoItemIds.pioneerCrown,
            collectionId: ColecaoIds.pioneiros2026,
            origem: OrigemItem.campanha,
            campaignId: 'pioneiros_2026',
            campaignVersion: 1,
            unlockedAt: _agora,
          )
        ]),
        throwsArgumentError,
      );
    });
  });

  // ==========================================================================
  group('contrato de UI', () {
    ColecaoVM montar({
      CampanhaColecao? c,
      InventarioUsuario? inventario,
      bool elegivel = true,
      bool flag = true,
      SituacaoResgate? situacao,
      bool emAndamento = false,
      String? erro,
    }) =>
        montarColecaoVM(
          campanha: c ?? campanhaAtiva,
          catalogo: catalogo,
          inventario: inventario ?? InventarioUsuario.vazio(_uid),
          veredicto: elegivel
              ? const VeredictoElegibilidade.elegivel()
              : const VeredictoElegibilidade.recusado(RecusaElegibilidade.semEvidencia),
          featureFlagLigada: flag,
          situacao: situacao,
          emAndamento: emAndamento,
          mensagemErro: erro,
        );

    test('com a flag desligada a campanha nao aparece', () {
      final vm = montar(flag: false);
      expect(vm.estado, EstadoColecao.inactive);
      expect(vm.deveAparecer, isFalse);
      expect(vm.podeResgatar, isFalse);
    });

    test('nao elegivel em modo hidden nao ve a campanha', () {
      final vm = montar(elegivel: false);
      expect(vm.estado, EstadoColecao.notEligible);
      expect(vm.visibilidade, VisibilidadeCatalogo.hidden);
      expect(vm.deveAparecer, isFalse);
    });

    test('nao elegivel em modo teaser ve a colecao bloqueada', () {
      final teaser = CampanhaColecao.fromMap(_campanhaCom(
          campanhaRaiz, {'status': 'active', 'catalogVisibility': 'teaser'}));
      final vm = montar(c: teaser, elegivel: false);
      expect(vm.deveAparecer, isTrue);
      expect(vm.podeResgatar, isFalse);
      expect(vm.recompensas.every((r) => !r.owned), isTrue);
    });

    test('elegivel sem resgate ve o convite com as dez pecas', () {
      final vm = montar();
      expect(vm.estado, EstadoColecao.eligibleUnclaimed);
      expect(vm.podeResgatar, isTrue);
      expect(vm.recompensas, hasLength(10));
      expect(vm.possuidos, 0);
      expect(vm.completa, isFalse);
      expect(vm.heroAssetPath, contains('bau'));
      expect(vm.fechamentoAssetPath, contains('emblema'));
    });

    test('as recompensas saem na ordem de apresentacao', () {
      final ordens = montar().recompensas.map((r) => r.sortOrder).toList();
      expect(ordens, List.generate(10, (i) => i + 1));
    });

    test('durante a chamada o botao fica bloqueado', () {
      final vm = montar(emAndamento: true);
      expect(vm.estado, EstadoColecao.claiming);
      expect(vm.podeResgatar, isFalse);
    });

    test('erro recuperavel traz a mensagem que promete nao duplicar', () {
      final vm = montar(erro: TextosColecao.retryMessage);
      expect(vm.estado, EstadoColecao.recoverableError);
      expect(vm.mensagemErro, contains('não será duplicado'));
    });

    test('resgate concluido agora dispara a revelacao', () {
      final vm = montar(
        inventario: _inventarioCompleto(campanhaAtiva),
        situacao: SituacaoResgate.concedido,
      );
      expect(vm.estado, EstadoColecao.claimed);
      expect(vm.resgatado, isTrue);
      expect(vm.completa, isTrue);
      expect(vm.possuidos, 10);
    });

    test('quem ja tinha resgatado cai em alreadyClaimed, sem revelacao', () {
      final vm = montar(inventario: _inventarioCompleto(campanhaAtiva));
      expect(vm.estado, EstadoColecao.alreadyClaimed);
      expect(vm.resgatado, isTrue);
      expect(vm.podeResgatar, isFalse);
    });

    test('o inventario continua visivel depois da campanha encerrada', () {
      final encerrada =
          CampanhaColecao.fromMap(_campanhaCom(campanhaRaiz, {'status': 'closed'}));
      final vm = montar(c: encerrada, inventario: _inventarioCompleto(campanhaAtiva));
      expect(vm.estado, EstadoColecao.alreadyClaimed);
      expect(vm.deveAparecer, isTrue);
    });

    test('canEquip separa possuido de equipavel', () {
      final inv = _inventarioCompleto(campanhaAtiva);
      final vm = montar(inventario: inv, situacao: SituacaoResgate.jaResgatado);

      final bau = vm.recompensas.firstWhere((r) => r.id == ColecaoItemIds.pioneerChest);
      expect(bau.owned, isTrue);
      expect(bau.canEquip, isFalse, reason: 'o Bau e arte de apresentacao');

      final coroa = vm.recompensas.firstWhere((r) => r.id == ColecaoItemIds.pioneerCrown);
      expect(coroa.canEquip, isTrue);
    });

    test('item equipado deixa de oferecer equipar', () {
      final equipado = _inventarioCompleto(campanhaAtiva)
          .equipar(ColecaoItemIds.pioneerCrown, catalogo)
          .inventario!;
      final vm = montar(inventario: equipado, situacao: SituacaoResgate.jaResgatado);
      final coroa = vm.recompensas.firstWhere((r) => r.id == ColecaoItemIds.pioneerCrown);
      expect(coroa.equipped, isTrue);
      expect(coroa.canEquip, isFalse);
    });

    test('toda recompensa tem rotulo de acessibilidade', () {
      for (final r in montar().recompensas) {
        expect(r.accessibilityLabel, isNotEmpty);
        expect(r.assetPath, startsWith('assets/colecoes/pioneiros_2026/'));
      }
    });

    test('os textos provisorios estao no contrato, nao soltos em widget', () {
      expect(TextosColecao.title, 'KIT PIONEIROS 2026');
      expect(TextosColecao.claimButton, 'Abrir meu Kit Pioneiro');
      expect(TextosColecao.successTitle, 'Coleção desbloqueada');
    });
  });

  // ==========================================================================
  group('telemetria', () {
    test('os sete eventos previstos existem com o nome acordado', () {
      expect(EventoColecao.values.map((e) => e.wire).toSet(), {
        'pioneer_offer_seen',
        'pioneer_claim_started',
        'pioneer_claim_success',
        'pioneer_claim_already_completed',
        'pioneer_claim_error',
        'pioneer_item_equipped',
        'pioneer_inventory_opened',
      });
    });

    test('o payload carrega so identificadores tecnicos', () {
      final p = EventoColecao.itemEquipped.payload(
        campaignId: 'pioneiros_2026',
        appVersion: '1.0.0',
        rewardId: ColecaoItemIds.pioneerCrown,
      );
      expect(p.keys.toSet(), {'campaignId', 'appVersion', 'rewardId'});
      expect(p.containsKey('userId'), isFalse);
      expect(p.containsKey('email'), isFalse);
    });

    test('campos ausentes sao omitidos em vez de irem nulos', () {
      final p = EventoColecao.offerSeen.payload(
        campaignId: 'pioneiros_2026',
        appVersion: '1.0.0',
      );
      expect(p.keys.toSet(), {'campaignId', 'appVersion'});
    });
  });
}
