// vinculo_firebase.dart — o adaptador de Firebase da porta de vinculo.
//
// POR QUE ELE SAIU DE `vinculo.dart`
//
// A invariante e do projeto inteiro, e nao deste modulo: so um arquivo
// `*_firebase.dart` conhece `cloud_functions`. Ela e cobrada por
// `test/composicao/composicao_perfil_ranking_test.dart` (C11b) sobre o codigo
// ALCANCAVEL a partir de `main.dart` — e foi ao ligar a Loja a casca que
// `vinculo.dart` passou a ser alcancavel, com a callable dentro dele.
//
// A separacao ja era a forma do resto do modulo: `validacao.dart` declara a
// porta e `validacao_firebase.dart` a implementa. Aqui ficou igual. A porta, o
// validador de formato e o duble continuam em `vinculo.dart`, que voltou a ser
// Dart puro e exercitavel sem Firebase — que e a razao de a porta existir.
library;

import 'package:cloud_functions/cloud_functions.dart';

import 'vinculo.dart';

/// A implementacao real, sobre a callable `prepararCompraPlay`.
class PreparadorFirebase implements PreparadorDeCompra {
  PreparadorFirebase({
    String regiao = 'us-central1',
    String nomeDaFuncao = 'prepararCompraPlay',
    FirebaseFunctions? funcoes,
  })  : _regiao = regiao,
        _nomeDaFuncao = nomeDaFuncao,
        _funcoes = funcoes;

  final String _regiao;
  final String _nomeDaFuncao;
  final FirebaseFunctions? _funcoes;

  FirebaseFunctions get _instancia =>
      _funcoes ?? FirebaseFunctions.instanceFor(region: _regiao);

  @override
  Future<String?> preparar() async {
    try {
      // SEM PAYLOAD, e isso e a regra e nao economia. A callable ignora o corpo
      // da requisicao de proposito: aceitar um identificador vindo daqui
      // devolveria ao cliente exatamente o poder que a correcao P0 tirou dele.
      final resposta = await _instancia
          .httpsCallable(_nomeDaFuncao)
          .call<Map<String, dynamic>>();

      final valor = resposta.data['contaOfuscada'];
      return valor is String ? valor : null;
    } catch (_) {
      // Nem o tipo do erro sobe: quem chama so precisa saber que nao ha vinculo,
      // e a decisao — nao abrir a compra — e a mesma para toda causa.
      return null;
    }
  }
}
