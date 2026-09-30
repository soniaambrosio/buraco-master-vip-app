// cena_de_ingresso.dart — o cenário compartilhado das suítes do ingresso.
//
// NÃO é um arquivo `_test.dart`: não declara caso nenhum e o coletor do
// `flutter test` não o recolhe.
//
// ---------------------------------------------------------------------------
// PROVENIÊNCIA — ISTO É CÓPIA, NÃO INVENÇÃO
// ---------------------------------------------------------------------------
//
// As mensagens daqui reproduzem campo a campo o que o servidor congelado
// emite:
//
//   repositório `soniaambrosio/buraco-servidor`
//   branch      `integracao/servidor-assento-descoberta-presenca-v1`
//   SHA         8a0ee4b76ac915705e2e1a37237666a4aab41c39
//   funções     `entrarMesa`, `aplicarEntrada`, `erroDeAdmissao`
//
// O ACK sai de `aplicarEntrada`:
//   `{ tipo: "entrou", codigo, assento, reconexao }`
// A recusa tipada sai de `erroDeAdmissao`:
//   `{ tipo: "erro", motivo, codigo }`
// e a recusa de ciclo de vida sai sem `codigo`, só com `motivo`.
//
// AS ASPEREZAS SÃO DE PROPÓSITO. `motivo` vem ACENTUADO, como o servidor o
// escreve; escrevê-lo sem acento aqui deixaria o normalizador do cliente sem
// nada para normalizar, e o caso passaria sem medir a defesa que existe.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:buraco_master_vip/casca/lobby_publico_de_producao.dart';
import 'package:buraco_master_vip/ingresso/contrato_ingresso.dart';

import '../casca/bancada_online.dart';

// ===========================================================================
// As mensagens do servidor
// ===========================================================================

/// O ACK positivo, como `aplicarEntrada` o emite.
Map<String, dynamic> ackDeIngresso({
  required String codigo,
  required int assento,
  bool reconexao = false,
}) => {
  'tipo': ContratoDoIngresso.respostaDeAceite,
  'codigo': codigo,
  'assento': assento,
  'reconexao': reconexao,
};

/// A recusa TIPADA de assento ocupado — `recusaDeAssento(RECUSA_ASSENTO_OCUPADO,
/// ERRO_ASSENTO_OCUPADO)` passando por `erroDeAdmissao`.
Map<String, dynamic> recusaAssentoOcupado() => {
  'tipo': ContratoDoIngresso.respostaDeRecusa,
  'motivo': 'assento ocupado',
  'codigo': ContratoDoIngresso.recusaAssentoOcupado,
};

/// A recusa TIPADA de assento inválido.
Map<String, dynamic> recusaAssentoInvalido() => {
  'tipo': ContratoDoIngresso.respostaDeRecusa,
  'motivo': 'assento inválido',
  'codigo': ContratoDoIngresso.recusaAssentoInvalido,
};

/// Recusa de ciclo de vida da mesa: SEM código, só com o motivo — e com os
/// acentos do servidor.
Map<String, dynamic> recusaSemCodigo(String motivo) => {
  'tipo': ContratoDoIngresso.respostaDeRecusa,
  'motivo': motivo,
};

// ===========================================================================
// A cena do aplicativo inteiro
// ===========================================================================

/// Monta o aplicativo numa superfície de telefone e atravessa a abertura.
Future<void> abrirAplicativo(WidgetTester tester, Bancada b) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(b.aplicativo);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 40));
  await tester.pumpAndSettle();
}

/// O servidor aceita a credencial.
Future<void> servidorAceita(WidgetTester tester, Bancada b) async {
  b.canal.servidorEnvia({'tipo': 'autenticado'});
  await tester.pumpAndSettle();
}

/// Silencia o transporte DENTRO do corpo do teste.
///
/// O `flutter_test` confere temporizadores pendentes ao fim do corpo, antes
/// dos `addTearDown` — então `addTearDown(b.fechar)`, que continua existindo e
/// continua certo, não chega a tempo.
void aquietar(Bancada b) => b.online.desligar();

/// Home → Onde jogar → Lobby Público, pelos toques de verdade.
Future<void> irAoLobbyPublico(WidgetTester tester) async {
  await tester.tap(find.text('Jogar').first);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Mesa Pública'));
  await tester.pumpAndSettle();
  expect(find.byType(LobbyPublicoDeProducao), findsOneWidget);
}

/// Volta uma rota.
///
/// `tester.pageBack()` NÃO serve: ele procura um botão com o tooltip "Back",
/// em inglês, e as telas daqui nomeiam o Voltar em português.
Future<void> voltar(WidgetTester tester) async {
  final estado = tester.state<NavigatorState>(find.byType(Navigator).last);
  estado.pop();
  await tester.pumpAndSettle();
}

/// Todas as mensagens de um tipo que o aplicativo escreveu no socket.
List<Map<String, dynamic>> mensagensDoTipo(Bancada b, String tipo) =>
    b.canal.mensagens.where((m) => m['tipo'] == tipo).toList();

/// Os pedidos de ingresso que saíram.
List<Map<String, dynamic>> pedidosDeIngresso(Bancada b) =>
    mensagensDoTipo(b, ContratoDoIngresso.pedidoDeIngresso);
