import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/screens/resultado_partida_screen.dart';
import '../lib/screens/resultado_vitoria_adapter.dart';
import '../lib/screens/vitoria_celebracao.dart';
import 'superficie_de_teste.dart';

/// Comportamento da celebracao ja montada na arvore.
///
/// O contrato (quem venceu, se toca som) esta em
/// `vitoria_celebracao_contract_test.dart`. Aqui o que se protege e o que so
/// aparece com a camada rodando: a comemoracao acontecer uma vez por evento,
/// nao repetir em rebuild, nao roubar toque e nao depender do audio.
const _jogadores = [
  JogadorResultadoVM(assento: 0, nome: 'Sônia', avatar: '👑', souEu: true),
  JogadorResultadoVM(assento: 1, nome: 'Carlos', avatar: '🧔🏻'),
  JogadorResultadoVM(assento: 2, nome: 'Cláudia', avatar: '🐰'),
  JogadorResultadoVM(assento: 3, nome: 'Rafael', avatar: '🧔🏽'),
];

CelebracaoVitoriaVM _vmDe(String eventoId, {bool fimPartida = true}) {
  return celebracaoVitoriaDoResultado(
    eventoId: eventoId,
    fimPartida: fimPartida,
    assentosVencedores: const {0, 2},
    jogadores: _jogadores,
    // Som ligado de proposito: no runner nao existe plugin de audio, e a
    // comemoracao visual precisa acontecer mesmo assim.
    somHabilitado: true,
  );
}

Widget _appCom(CelebracaoVitoriaVM vm, {VoidCallback? onToque}) {
  return MaterialApp(
    home: Scaffold(
      body: CelebracaoVitoriaLayer(
        vm: vm,
        child: Center(
          child: ElevatedButton(
            onPressed: onToque ?? () {},
            child: const Text('Jogar de novo'),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('a comemoracao acontece mesmo sem audio disponivel',
      (tester) async {
    usarTelefoneRetrato(tester);

    await tester.pumpWidget(_appCom(_vmDe('fim-partida-1')));
    // O primeiro quadro so agenda; a execucao vem no post-frame.
    await tester.pump();

    final quadros = await tester.pumpAndSettle();
    // Se o confete ficasse preso esperando o som, nada teria animado.
    expect(quadros, greaterThan(1));
  });

  testWidgets('rebuild com o mesmo evento nao recomeca a comemoracao',
      (tester) async {
    usarTelefoneRetrato(tester);

    final vm = _vmDe('fim-partida-7');
    await tester.pumpWidget(_appCom(vm));
    await tester.pump();
    await tester.pumpAndSettle();

    // Mesma partida, novo build: voltar para a tela, reconectar ou qualquer
    // setState nao pode disparar confete e som outra vez.
    await tester.pumpWidget(_appCom(_vmDe('fim-partida-7')));
    final quadros = await tester.pumpAndSettle();
    expect(quadros, 1);
  });

  testWidgets('uma partida nova comemora de novo', (tester) async {
    usarTelefoneRetrato(tester);

    await tester.pumpWidget(_appCom(_vmDe('fim-partida-7')));
    await tester.pump();
    await tester.pumpAndSettle();

    await tester.pumpWidget(_appCom(_vmDe('fim-partida-8')));
    await tester.pump();
    final quadros = await tester.pumpAndSettle();
    expect(quadros, greaterThan(1));
  });

  testWidgets('fim de rodada nao comemora', (tester) async {
    usarTelefoneRetrato(tester);

    await tester.pumpWidget(
      _appCom(_vmDe('rodada-3', fimPartida: false)),
    );
    await tester.pump();

    final quadros = await tester.pumpAndSettle();
    expect(quadros, 1);
  });

  testWidgets('a camada nao rouba o toque da tela de resultado',
      (tester) async {
    usarTelefoneRetrato(tester);

    var toques = 0;
    await tester.pumpWidget(
      _appCom(_vmDe('fim-partida-9'), onToque: () => toques++),
    );
    await tester.pump();

    await tester.tap(find.text('Jogar de novo'));
    await tester.pump();
    expect(toques, 1);

    await tester.pumpAndSettle();
  });
}
