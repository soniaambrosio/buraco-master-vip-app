// colecao_arte_test.dart — fonte da arte e resolvedor.
//
// O que estes casos protegem: que uma colecao futura possa vir de armazenamento
// remoto SEM que os itemIds mudem, e que a troca de origem nao passe silenciosa
// por falta de checksum.

import 'package:buraco_master_vip/colecoes/colecao_arte.dart';
import 'package:buraco_master_vip/colecoes/colecao_catalogo.dart';
import 'package:flutter_test/flutter_test.dart';

// SHA-256 ficticio: 64 hexadecimais. O conteudo nao importa aqui, so o formato.
const _shaFalso = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

void main() {
  group('fonte de arte', () {
    test('bundle guarda o caminho e dispensa checksum', () {
      final fonte = FonteArte.bundle('assets/colecoes/x/y.png');
      expect(fonte.ehBundle, isTrue);
      expect(fonte.ehRemota, isFalse);
      expect(fonte.assetPath, 'assets/colecoes/x/y.png');
      expect(fonte.url, isNull);
    });

    test('remota exige url e checksum', () {
      expect(() => FonteArte.remota(url: '', sha256: _shaFalso), throwsArgumentError);
      expect(() => FonteArte.remota(url: 'https://x/y.png', sha256: ''), throwsArgumentError);

      final fonte = FonteArte.remota(url: 'https://x/y.png', sha256: _shaFalso, bytes: 10);
      expect(fonte.ehRemota, isTrue);
      expect(fonte.sha256, _shaFalso);
      expect(fonte.bytes, 10);
    });

    test('a chave de cache vem da origem, nao do itemId', () {
      // Dois itens apontando para o mesmo arquivo devem compartilhar UMA copia.
      final a = FonteArte.bundle('assets/x.png');
      final b = FonteArte.bundle('assets/x.png');
      expect(a.chaveCache, b.chaveCache);

      final remota = FonteArte.remota(url: 'https://x/y.png', sha256: _shaFalso);
      expect(remota.chaveCache, isNot(a.chaveCache));
    });

    test('le a forma antiga (assetPath solto) como bundle', () {
      final fonte = FonteArte.fromJson({'assetPath': 'assets/x.png'}, 'item');
      expect(fonte.ehBundle, isTrue);
      expect(fonte.assetPath, 'assets/x.png');
    });

    test('le a forma nova (arte: {...})', () {
      final bundle = FonteArte.fromJson({
        'arte': {'tipo': 'bundle', 'assetPath': 'assets/x.png'},
      }, 'item');
      expect(bundle.ehBundle, isTrue);

      final remota = FonteArte.fromJson({
        'arte': {'tipo': 'remota', 'url': 'https://x/y.png', 'sha256': _shaFalso, 'bytes': 7},
      }, 'item');
      expect(remota.ehRemota, isTrue);
      expect(remota.bytes, 7);
    });

    test('declarar as duas formas ao mesmo tempo e recusado', () {
      expect(
        () => FonteArte.fromJson({
          'assetPath': 'assets/x.png',
          'arte': {'tipo': 'bundle', 'assetPath': 'assets/y.png'},
        }, 'item'),
        throwsFormatException,
      );
    });

    test('arte remota sem sha256 no seed e recusada', () {
      expect(
        () => FonteArte.fromJson({
          'arte': {'tipo': 'remota', 'url': 'https://x/y.png'},
        }, 'item'),
        throwsFormatException,
      );
    });

    test('tipo desconhecido e recusado em vez de virar bundle', () {
      expect(
        () => FonteArte.fromJson({
          'arte': {'tipo': 'cdn', 'url': 'https://x/y.png'},
        }, 'item'),
        throwsFormatException,
      );
    });

    test('sobrevive a ida e volta por JSON', () {
      final original = FonteArte.remota(url: 'https://x/y.png', sha256: _shaFalso, bytes: 3);
      final volta = FonteArte.fromJson({'arte': original.toJson()}, 'item');
      expect(volta.url, original.url);
      expect(volta.sha256, original.sha256);
      expect(volta.bytes, original.bytes);
    });
  });

  group('resolvedor', () {
    const resolvedor = ResolvedorBundle();

    test('resolve arte de bundle sem tocar rede nem disco', () async {
      final r = await resolvedor.resolver('id', FonteArte.bundle('assets/x.png'));
      expect(r.referencia, 'assets/x.png');
      expect(r.local, isTrue);
    });

    test('recusa arte remota em vez de devolver algo pela metade', () async {
      final remota = FonteArte.remota(url: 'https://x/y.png', sha256: _shaFalso);
      expect(() => resolvedor.resolver('id', remota), throwsA(isA<FalhaArte>()));
      expect(() => resolvedor.preparar('id', remota), throwsA(isA<FalhaArte>()));
    });
  });

  group('catalogo com origem remota', () {
    /// Catalogo minimo com um item de arte remota, para provar que a modelagem
    /// aceita origem remota HOJE — sem que nada do Kit Pioneiros mude.
    Map<String, dynamic> catalogoRemoto() => {
          'schemaVersion': 1,
          'slots': {
            'definicoes': [
              {'slot': 'mascote', 'maxAtivos': 1, 'origem': 'existente', 'nota': 'teste'},
            ],
          },
          'colecoes': [
            {
              'collectionId': 'futura_2027',
              'displayName': 'Colecao Futura',
              'rarity': 'pioneer',
              'permanente': true,
              'purchasable': false,
              'transferable': false,
              'tradable': false,
              'revocable': false,
              'manifesto': 'app/data/colecoes/futura.json',
              // Anotado de proposito: sem isto o Dart infere
              // `List<Map<String, Object>>` a partir do unico item, e os casos
              // abaixo — que acrescentam um item com `slot: null` — falhariam por
              // tipo, escondendo o que realmente esta sendo testado.
              'itens': <Map<String, dynamic>>[
                <String, dynamic>{
                  'itemId': 'futura_2027_mascote',
                  'displayName': 'Mascote Futuro',
                  'categoria': 'mascot',
                  'slot': 'mascote',
                  'equipavel': true,
                  'arte': {
                    'tipo': 'remota',
                    'url': 'https://cdn.exemplo/futura/mascote.png',
                    'sha256': _shaFalso,
                    'bytes': 1234,
                  },
                  'sortOrder': 1,
                  'enabled': true,
                  'accessibilityLabel': 'Mascote Futuro.',
                },
              ],
            },
          ],
        };

    test('o catalogo aceita item com arte remota', () {
      final catalogo = CatalogoColecoes.fromMap(catalogoRemoto());
      final item = catalogo['futura_2027_mascote'];
      expect(item.arte.ehRemota, isTrue);
      expect(item.assetPath, isNull,
          reason: 'arte remota nao tem caminho local ate ser resolvida');
      expect(item.arte.sha256, _shaFalso);
    });

    test('itens de origens diferentes convivem no mesmo catalogo', () {
      final bruto = catalogoRemoto();
      final lista = ((bruto['colecoes'] as List).first as Map<String, dynamic>)['itens'] as List;
      lista.add(<String, dynamic>{
        'itemId': 'futura_2027_selo',
        'displayName': 'Selo Futuro',
        'categoria': 'badge_emblem',
        'slot': null,
        'equipavel': false,
        'assetPath': 'assets/colecoes/futura_2027/selo.png',
        'sortOrder': 2,
        'enabled': true,
        'accessibilityLabel': 'Selo Futuro.',
      });

      final catalogo = CatalogoColecoes.fromMap(bruto);
      expect(catalogo['futura_2027_mascote'].arte.ehRemota, isTrue);
      expect(catalogo['futura_2027_selo'].arte.ehBundle, isTrue);
    });

    test('duas entradas para a mesma arte remota sao recusadas', () {
      final bruto = catalogoRemoto();
      final itens = (bruto['colecoes'] as List).first['itens'] as List;
      itens.add({
        ...(itens.first as Map<String, dynamic>),
        'itemId': 'futura_2027_clone',
        'sortOrder': 2,
      });
      expect(() => CatalogoColecoes.fromMap(bruto), throwsFormatException);
    });
  });
}
