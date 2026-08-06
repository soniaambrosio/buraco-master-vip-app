// billing_catalogo_test.dart — portao do catalogo de produtos do Google Play.
//
// Dart puro: nao sobe widget, nao toca Firebase, nao abre a Play Store. So le a
// declaracao estatica de IDs.
//
// Este portao NAO exige que o catalogo esteja vazio — ele vai ser preenchido
// assim que a Play Console liberar a area de produtos. O que ele impede e que
// alguem adiante um ID chutado ou mal formado. IDs de produto do Google Play
// sao IMUTAVEIS: uma vez criados nao podem ser apagados, so desativados. Um
// `master_vip_mensal_teste` publicado por engano fica de enfeite para sempre.

import 'package:buraco_master_vip/services/billing_catalogo.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fragmentos que denunciam um ID provisorio.
const _marcasDeProvisorio = <String>[
  'test',
  'teste',
  'placeholder',
  'exemplo',
  'example',
  'dummy',
  'fake',
  'sample',
  'todo',
  'tmp',
  'temp',
  'xxx',
  'foo',
  'bar',
];

void main() {
  group('BillingCatalogo', () {
    test('nao contem IDs provisorios', () {
      for (final id in BillingCatalogo.todos) {
        for (final marca in _marcasDeProvisorio) {
          expect(
            id.toLowerCase().contains(marca),
            isFalse,
            reason: 'o ID "$id" parece provisorio (contem "$marca"). '
                'Só entram aqui os IDs oficiais devolvidos pela Play Console.',
          );
        }
      }
    });

    test('todo ID respeita o formato aceito pelo Google Play', () {
      for (final id in BillingCatalogo.todos) {
        expect(
          BillingCatalogo.formatoValido.hasMatch(id),
          isTrue,
          reason: 'o ID "$id" nao bate com ^[a-z0-9][a-z0-9._]*\$ — '
              'a Play Console vai recusar o cadastro.',
        );
      }
    });

    test('nenhum ID e assinatura e consumivel ao mesmo tempo', () {
      final ambiguos =
          BillingCatalogo.assinaturas.intersection(BillingCatalogo.consumiveis);
      expect(
        ambiguos,
        isEmpty,
        reason: 'IDs em $ambiguos estao nos dois conjuntos. O tipo decide se a '
            'compra e consumida ou nao — nao pode ser os dois.',
      );
    });

    test('nao ha ID repetido entre os conjuntos declarados', () {
      // Set ja deduplica dentro de cada conjunto; aqui a conta confirma que a
      // uniao nao perdeu nada, ou seja, que nao houve colisao silenciosa.
      expect(
        BillingCatalogo.todos.length,
        BillingCatalogo.assinaturas.length + BillingCatalogo.consumiveis.length,
      );
    });

    test('"configurado" reflete a existencia de IDs', () {
      expect(BillingCatalogo.configurado, BillingCatalogo.todos.isNotEmpty);
    });

    test('classificacao so responde por ID declarado', () {
      expect(BillingCatalogo.ehAssinatura('nao_declarado'), isFalse);
      expect(BillingCatalogo.ehConsumivel('nao_declarado'), isFalse);
      for (final id in BillingCatalogo.assinaturas) {
        expect(BillingCatalogo.ehAssinatura(id), isTrue);
        expect(BillingCatalogo.ehConsumivel(id), isFalse);
      }
      for (final id in BillingCatalogo.consumiveis) {
        expect(BillingCatalogo.ehConsumivel(id), isTrue);
        expect(BillingCatalogo.ehAssinatura(id), isFalse);
      }
    });
  });
}
