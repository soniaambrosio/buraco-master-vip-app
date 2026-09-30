// Redação adversarial: o teste tenta VAZAR, não confirmar que funciona.
//
// Cada caso aqui é um caminho por onde um segredo chegaria ao painel do
// fornecedor se a redação tivesse um furo: dentro da mensagem, dentro de uma
// chave de contexto, dentro do valor, dentro de uma exceção aninhada três
// níveis abaixo, e solto no meio de texto sem chave nenhuma por perto.

import 'package:buraco_master_vip/observability/redacao.dart';
import 'package:flutter_test/flutter_test.dart';

/// Erro com causa aninhada — o formato clássico de vazamento: a mensagem de
/// fora é inócua e o segredo está lá embaixo.
class ErroComCausa implements Exception {
  ErroComCausa(this.mensagem, [this.causa]);
  final String mensagem;
  final Object? causa;
  @override
  String toString() => 'ErroComCausa: $mensagem';
}

void main() {
  const r = Redator();

  // Amostras SINTÉTICAS, com a forma dos segredos reais. Nenhuma delas é uma
  // credencial válida — inclusive por isso o teste pode ser lido em público.
  const jwtFalso =
      'eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.aBcDeFgHiJkLmNoPqRsTuVwXyZ0123456789';
  const chaveApiFalsa = 'AIzaSyC8ylNsHzt0nxmbosG1J9RTPLALpUOTBdQ';
  const uidFalso = 'kJ3mP9qRsT2vW5xY8zA1bC4dE7fG';
  const purchaseTokenFalso =
      'hlmnopqrstuvwxyzabcdefgh.AO-J1OxYzAbCdEfGhIjKlMnOpQrStUvWxYz0123456789AbCdEfGh';

  group('negação por forma — o segredo some mesmo sem chave por perto', () {
    test('ID token do Firebase (JWT)', () {
      final saida = r.texto('falhou ao renovar sessão: $jwtFalso');
      expect(saida, contains(marcaRedacao));
      expect(saida, isNot(contains('eyJhbGciOiJSUzI1NiI')));
      expect(saida, isNot(contains(jwtFalso)));
    });

    test('chave de API do Google', () {
      final saida = r.texto('FirebaseOptions(apiKey: $chaveApiFalsa)');
      expect(saida, isNot(contains(chaveApiFalsa)));
      expect(saida, isNot(contains('AIzaSy')));
    });

    test('e-mail', () {
      final saida = r.texto('conta jogadora.exemplo@gmail.com sem permissão');
      expect(saida, isNot(contains('@gmail.com')));
      expect(saida, contains(marcaRedacao));
    });

    test('UID cru do Firebase, solto no texto', () {
      final saida = r.texto('perfil $uidFalso não encontrado');
      expect(saida, isNot(contains(uidFalso)));
    });

    test('purchaseToken da Play', () {
      final saida = r.texto('compra recusada ($purchaseTokenFalso)');
      expect(saida, isNot(contains(purchaseTokenFalso)));
    });

    test('cabeçalho Authorization', () {
      final saida = r.texto('GET /perfil Authorization: Bearer abcdefgh12345678');
      expect(saida, isNot(contains('abcdefgh12345678')));
    });

    test('número longo (cartão/documento)', () {
      final saida = r.texto('pagamento 4111111111111111 recusado');
      expect(saida, isNot(contains('4111111111111111')));
    });

    test('mão privada de cartas', () {
      final saida = r.texto('estado inválido: mão [copas_A, ouros_K, JOKER]');
      expect(saida, isNot(contains('copas_A')));
      expect(saida, isNot(contains('ouros_K')));
      expect(saida, isNot(contains('JOKER')));
    });

    test('client id OAuth', () {
      final saida = r.texto(
          'serverClientId 203886484007-a5e1ob9b7uequoffj6u76h5vltici9a4.apps.googleusercontent.com inválido');
      expect(saida, isNot(contains('apps.googleusercontent.com')));
    });
  });

  group('negação por chave — o valor some porque o campo se chama assim', () {
    test('chaves proibidas viram marca, e a linha sobrevive', () {
      final saida = r.contexto(<String, Object?>{
        'uid': 'abc123',
        'email': 'a@b.com',
        'purchaseToken': 'qualquer-coisa',
        'firebaseIdToken': 'qualquer-coisa',
        'X-Access-Token': 'qualquer-coisa',
        'mensagemDoChat': 'oi tudo bem',
        'suaMao': '[copas_A]',
        'tela': 'ranking',
        'tentativas': 3,
      });
      for (final k in const [
        'uid',
        'email',
        'purchaseToken',
        'firebaseIdToken',
        'X-Access-Token',
        'mensagemDoChat',
        'suaMao',
      ]) {
        expect(saida[k], marcaRedacao, reason: 'chave $k deveria ser redigida');
      }
      // Saber que HAVIA um uid é diagnóstico legítimo.
      expect(saida.containsKey('uid'), isTrue);
      // O que é operacional passa intacto.
      expect(saida['tela'], 'ranking');
      expect(saida['tentativas'], '3');
    });

    test('chave proibida esconde o valor mesmo que o valor pareça inofensivo', () {
      final saida = r.contexto(<String, Object?>{'nomeDoJogador': 'Sônia'});
      expect(saida['nomeDoJogador'], marcaRedacao);
    });

    test('par nomeado dentro de texto livre', () {
      final saida = r.texto('POST {"idToken":"curto","tela":"loja"}');
      expect(saida, isNot(contains('curto')));
      expect(saida, contains('loja'));
    });
  });

  group('exceção aninhada', () {
    test('segredo três níveis abaixo não escapa', () {
      final raiz = ErroComCausa('token recusado: $jwtFalso');
      final meio = ErroComCausa('falha ao autenticar', raiz);
      final topo = ErroComCausa('não foi possível entrar na mesa', meio);

      final cadeia = r.cadeiaDeCausas(topo);
      expect(cadeia.length, 3);
      expect(cadeia.join('\n'), isNot(contains(jwtFalso)));
      expect(cadeia.first, contains('não foi possível entrar na mesa'));
      expect(cadeia.last, contains(marcaRedacao));
    });

    test('ciclo de causas não trava a redação', () {
      final a = ErroComCausa('a');
      final b = ErroComCausa('b', a);
      // `a` aponta de volta para `b` não é expressável com final; o teste do
      // limite cobre a outra metade: cadeia mais longa que o limite.
      final cadeia = r.cadeiaDeCausas(b, limite: 1);
      expect(cadeia.length, 1);
    });

    test('erro sem campo de causa não quebra nada', () {
      expect(r.cadeiaDeCausas(StateError('sem causa')), hasLength(1));
      expect(r.cadeiaDeCausas(null), isEmpty);
    });
  });

  group('o que NÃO pode ser destruído', () {
    test('SHA de commit sobrevive — é a resposta de "qual build quebrou?"', () {
      const sha = '0cea0d6d68f2c93613b985f4aa85800d77cf42d7';
      expect(r.texto('build $sha'), contains(sha));
    });

    test('stack trace preserva pacote, arquivo e linha', () {
      const stack = '''
#0      _MesaScreenState._descartar (package:buraco_master_vip/screens/mesa_screen.dart:412:7)
#1      _InicioPreviewHostState.build (package:buraco_master_vip/main.dart:365:12)
''';
      final saida = r.stack(stack);
      expect(saida, contains('mesa_screen.dart:412:7'));
      expect(saida, contains('_MesaScreenState._descartar'));
      expect(saida, contains('package:buraco_master_vip'));
    });

    test('stack trace ainda perde segredo embutido', () {
      final saida = r.stack('#0 login (main.dart:1:1) token=$jwtFalso');
      expect(saida, isNot(contains(jwtFalso)));
      expect(saida, contains('main.dart:1:1'));
    });
  });

  test('redigir duas vezes dá o mesmo resultado (idempotente)', () {
    final uma = r.texto('uid=$uidFalso chave=$chaveApiFalsa mail=a@b.com');
    final duas = r.texto(uma);
    expect(duas, uma);
  });

  test('entrada vazia ou nula não explode', () {
    expect(r.texto(null), '');
    expect(r.texto(''), '');
    expect(r.stack(null), '');
    expect(r.contexto(null), isEmpty);
  });
}
