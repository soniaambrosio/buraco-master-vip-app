// inventario_vm_test.dart — cobertura da projecao de posse para a tela.
//
// Dart puro sobre flutter_test: nao sobe widget, nao toca Firebase, nao le
// relogio. O catalogo entra por arquivo, pelo mesmo `test/suporte/seeds.dart`
// que as outras suites do modulo usam, de modo que estes casos exercitam a
// CONFIGURACAO DE PRODUCAO e nao um catalogo de mentira.
//
// A INVARIANTE QUE ESTA SUITE PROTEGE: a tela de inventario mostra o que o
// jogador possui, e nada alem disso. O caso `nao possuido nao aparece` e o
// coracao do arquivo — e a diferenca entre um inventario e uma vitrine de loja,
// e e o tipo de regra que uma refatoracao bem-intencionada desfaz sem perceber.

import 'package:buraco_master_vip/colecoes/colecao_catalogo.dart';
import 'package:buraco_master_vip/colecoes/colecao_inventario.dart';
import 'package:buraco_master_vip/colecoes/colecao_ui_contract.dart';
import 'package:flutter_test/flutter_test.dart';

import '../suporte/seeds.dart';

const _uid = 'uid_pioneiro_1';

/// Instante de referencia. Fixo de proposito: nenhum teste le o relogio.
final _agora = DateTime.utc(2026, 8, 6, 12);

ItemInventario _item(
  String itemId, {
  String collectionId = ColecaoIds.pioneiros2026,
  bool equipped = false,
}) =>
    ItemInventario(
      userId: _uid,
      itemId: itemId,
      collectionId: collectionId,
      origem: OrigemItem.campanha,
      campaignId: 'pioneiros_2026',
      campaignVersion: 1,
      unlockedAt: _agora,
      equipped: equipped,
    );

InventarioUsuario _inventario(List<ItemInventario> itens) =>
    InventarioUsuario(_uid, itens);

void main() {
  final catalogo = CatalogoColecoes.fromMap(lerSeed('colecoes', 'catalogo.seed.json'));

  InventarioVM montar(InventarioUsuario inventario) =>
      montarInventarioVM(catalogo: catalogo, inventario: inventario);

  group('so aparece o que e do jogador', () {
    test('inventario vazio nao vira lista vazia de itens, e sim estado vazio', () {
      final vm = montar(InventarioUsuario.vazio(_uid));

      expect(vm.estado, EstadoInventario.vazio);
      expect(vm.grupos, isEmpty);
      expect(vm.totalItens, 0);
      expect(vm.temItens, isFalse);
    });

    test('item NAO possuido nao aparece — nem como silhueta', () {
      final vm = montar(_inventario([_item(ColecaoItemIds.pioneerCrown)]));

      final ids = vm.grupos.single.itens.map((i) => i.id).toList();
      expect(ids, [ColecaoItemIds.pioneerCrown]);

      // O catalogo tem dez itens; o jogador tem um. Se a projecao varresse o
      // catalogo em vez do inventario, os outros nove estariam aqui marcados
      // como nao possuidos — que e a estrutura de uma loja.
      expect(catalogo.itensDe(ColecaoIds.pioneiros2026).length, 10);
      expect(vm.grupos.single.itens.length, 1);
      expect(vm.grupos.single.itens.every((i) => i.owned), isTrue);
    });

    test('todo item projetado esta marcado como possuido', () {
      final vm = montar(_inventario([
        _item(ColecaoItemIds.pioneerCrown),
        _item(ColecaoItemIds.pioneerEmblem),
        _item(ColecaoItemIds.pioneerThrone),
      ]));

      expect(vm.totalItens, 3);
      expect(
        vm.grupos.expand((g) => g.itens).every((i) => i.owned),
        isTrue,
      );
    });
  });

  group('contagem e agrupamento', () {
    test('o grupo conta o acervo contra o tamanho da colecao', () {
      final vm = montar(_inventario([
        _item(ColecaoItemIds.pioneerCrown),
        _item(ColecaoItemIds.pioneerChest),
        _item(ColecaoItemIds.pioneerEmblem),
      ]));

      final grupo = vm.grupos.single;
      expect(grupo.collectionId, ColecaoIds.pioneiros2026);
      expect(grupo.displayName, 'Kit Pioneiros 2026');
      expect(grupo.possuidos, 3);
      expect(grupo.totalNaColecao, 10);
      expect(grupo.completa, isFalse);
    });

    test('acervo completo marca a colecao como completa', () {
      final todos = catalogo
          .itensDe(ColecaoIds.pioneiros2026)
          .map((i) => _item(i.itemId))
          .toList();
      final vm = montar(_inventario(todos));

      expect(vm.estado, EstadoInventario.pronto);
      expect(vm.grupos.single.completa, isTrue);
      expect(vm.totalItens, 10);
    });

    test('a ordem dos itens vem do catalogo, nao da ordem de leitura', () {
      // Entra fora de ordem de proposito: o Firestore nao promete ordem.
      final vm = montar(_inventario([
        _item(ColecaoItemIds.pioneerStatue), // sortOrder 10
        _item(ColecaoItemIds.pioneerCrown), // sortOrder 1
        _item(ColecaoItemIds.pioneerEmblem), // sortOrder 5
      ]));

      final ordens = vm.grupos.single.itens.map((i) => i.sortOrder).toList();
      expect(ordens, [...ordens]..sort());
      expect(vm.grupos.single.itens.first.id, ColecaoItemIds.pioneerCrown);
      expect(vm.grupos.single.itens.last.id, ColecaoItemIds.pioneerStatue);
    });
  });

  group('estado de equipagem', () {
    test('item equipado aparece equipado e nao se oferece para equipar', () {
      final vm = montar(_inventario([
        _item(ColecaoItemIds.pioneerCrown, equipped: true),
      ]));

      final item = vm.grupos.single.itens.single;
      expect(item.equipped, isTrue);
      expect(item.canEquip, isFalse, reason: 'ja esta equipado');
      expect(vm.totalEquipados, 1);
    });

    test('item equipavel e nao equipado pode ser equipado', () {
      final vm = montar(_inventario([_item(ColecaoItemIds.pioneerCrown)]));

      final item = vm.grupos.single.itens.single;
      expect(item.equipped, isFalse);
      expect(item.canEquip, isTrue);
      expect(item.slot, 'coroa');
    });

    test('peca de apresentacao nao e equipavel mesmo sendo do jogador', () {
      // O Bau e arte de abertura da campanha: possuido, sem slot, sem vitrine.
      final vm = montar(_inventario([_item(ColecaoItemIds.pioneerChest)]));

      final item = vm.grupos.single.itens.single;
      expect(item.owned, isTrue);
      expect(item.slot, isNull);
      expect(item.canEquip, isFalse);
    });
  });

  group('itens que esta versao nao conhece', () {
    test('sao contados e nao desenhados', () {
      final vm = montar(_inventario([
        _item(ColecaoItemIds.pioneerCrown),
        // Colecao futura, concedida por um servidor mais novo que o aplicativo.
        _item('colecao_2027_item_desconhecido', collectionId: 'colecao_2027'),
      ]));

      expect(vm.itensSemDefinicao, 1);
      expect(vm.temItensSemDefinicao, isTrue);
      // Contado, mas nunca desenhado: sem definicao nao ha nome nem arte, e um
      // card com id cru seria pior do que dizer que falta atualizar.
      expect(vm.totalItens, 1);
      expect(vm.grupos.single.itens.single.id, ColecaoItemIds.pioneerCrown);
    });

    test('so itens desconhecidos ainda e estado vazio, com o aviso de pe', () {
      final vm = montar(_inventario([
        _item('colecao_2027_item_desconhecido', collectionId: 'colecao_2027'),
      ]));

      expect(vm.estado, EstadoInventario.vazio);
      expect(vm.itensSemDefinicao, 1);
    });
  });

  group('estados sem leitura', () {
    test('sem sessao nao e o mesmo que sem itens', () {
      const vm = InventarioVM.semSessao();

      expect(vm.estado, EstadoInventario.semSessao);
      expect(vm.estado, isNot(EstadoInventario.vazio));
      expect(vm.grupos, isEmpty);
    });

    test('erro carrega a mensagem e nao finge acervo vazio', () {
      const vm = InventarioVM.erro('Sem conexão para carregar teus itens agora.');

      expect(vm.estado, EstadoInventario.erro);
      expect(vm.mensagemErro, isNotEmpty);
      expect(vm.temItens, isFalse);
    });
  });
}
