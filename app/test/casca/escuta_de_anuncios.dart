// escuta_de_anuncios.dart — o gravador dos anúncios de leitor de tela.
//
// NÃO é um arquivo `_test.dart`: não declara caso nenhum e o coletor do
// `flutter test` não o recolhe. É instrumento.
//
// ---------------------------------------------------------------------------
// POR QUE INTERCEPTAR O CANAL, E NÃO LER O CÓDIGO
// ---------------------------------------------------------------------------
//
// Um anúncio de leitor de tela não deixa rastro na árvore de widgets: ele sai
// do framework como UMA mensagem no canal `flutter/accessibility`, é entregue
// à plataforma e acaba. Procurar `SemanticsService.announce` no fonte provaria
// que a chamada foi ESCRITA — não que ela ACONTECEU, nem quantas vezes, nem em
// que ordem, nem com que texto. E é exatamente "quantas vezes" que a OS cobra:
// uma por transição, nenhuma por reconstrução.
//
// Interceptando o canal, o teste mede o que a pessoa cega efetivamente ouviria.
// Um anúncio a mais aparece aqui como um elemento a mais na lista.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tudo que foi anunciado desde que a escuta começou, em ordem.
class EscutaDeAnuncios {
  final List<Map<Object?, Object?>> eventos = <Map<Object?, Object?>>[];

  /// Só os anúncios (`type: announce`), na ordem em que saíram.
  List<String> get mensagens => eventos
      .where((e) => e['type'] == 'announce')
      .map((e) => ((e['data']! as Map)['message'] ?? '').toString())
      .toList();

  /// Quantos anúncios contêm [trecho]. É o número que responde "repetiu?".
  int quantasVezesDisse(String trecho) =>
      mensagens.where((m) => m.contains(trecho)).length;

  /// Zera o registro. Serve para medir uma janela específica — por exemplo,
  /// "depois de chegar à mesa, quantos anúncios saem numa reconstrução?".
  void limpar() => eventos.clear();

  @override
  String toString() => mensagens.toString();
}

/// Passa a gravar os anúncios deste caso. Desfaz-se sozinha no fim.
EscutaDeAnuncios escutarAnuncios(WidgetTester tester) {
  final escuta = EscutaDeAnuncios();
  final mensageiro = tester.binding.defaultBinaryMessenger;
  mensageiro.setMockDecodedMessageHandler<Object?>(
    SystemChannels.accessibility,
    (Object? mensagem) async {
      if (mensagem is Map) {
        escuta.eventos.add(mensagem.cast<Object?, Object?>());
      }
      return null;
    },
  );
  addTearDown(
    () => mensageiro.setMockDecodedMessageHandler<Object?>(
      SystemChannels.accessibility,
      null,
    ),
  );
  return escuta;
}
