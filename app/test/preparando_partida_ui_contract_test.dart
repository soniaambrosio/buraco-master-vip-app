import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/screens/preparando_partida_screen.dart';

void main() {
  Widget appCom(PreparandoPartidaVM vm) {
    return MaterialApp(
      home: PreparandoPartidaScreen(
        vm: vm,
        onConcluido: () {},
        habilitarSom: false,
        duracaoMinima: const Duration(days: 1),
      ),
    );
  }

  testWidgets('modo 2 distribui cartas somente para os dois participantes',
      (tester) async {
    const jogadores = [
      JogadorPreparacaoVM(
        id: 'voce',
        nome: 'Você',
        avatar: '👑',
        ehVip: true,
        pronto: true,
        posicao: PosicaoJogador.baixo,
      ),
      JogadorPreparacaoVM(
        id: 'oponente',
        nome: 'Oponente',
        avatar: '🧔🏻',
        ehVip: true,
        pronto: true,
        posicao: PosicaoJogador.topo,
      ),
    ];

    await tester.pumpWidget(
      appCom(
        const PreparandoPartidaVM(
          titulo: 'MESA DE 2',
          subtitulo: '2 jogadores',
          ehVip: true,
          jogadores: jogadores,
        ),
      ),
    );

    expect(find.byKey(const ValueKey('carta-distribuida-voce')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('carta-distribuida-oponente')),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) => widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>)
                .value
                .startsWith('carta-distribuida-'),
      ),
      findsNWidgets(2),
    );
  });

  testWidgets('modo 4 distribui uma carta visual para cada participante',
      (tester) async {
    const jogadores = [
      JogadorPreparacaoVM(
        id: 'topo',
        nome: 'Parceiro',
        avatar: '👩🏼',
        ehVip: true,
        pronto: true,
        posicao: PosicaoJogador.topo,
      ),
      JogadorPreparacaoVM(
        id: 'direita',
        nome: 'Oponente 1',
        avatar: '🧔🏽',
        ehVip: true,
        pronto: true,
        posicao: PosicaoJogador.direita,
      ),
      JogadorPreparacaoVM(
        id: 'baixo',
        nome: 'Você',
        avatar: '👑',
        ehVip: true,
        pronto: true,
        posicao: PosicaoJogador.baixo,
      ),
      JogadorPreparacaoVM(
        id: 'esquerda',
        nome: 'Oponente 2',
        avatar: '👩🏽',
        ehVip: true,
        pronto: true,
        posicao: PosicaoJogador.esquerda,
      ),
    ];

    await tester.pumpWidget(
      appCom(
        const PreparandoPartidaVM(
          titulo: 'MESA DE 4',
          subtitulo: '4 jogadores',
          ehVip: true,
          jogadores: jogadores,
        ),
      ),
    );

    for (final id in ['topo', 'direita', 'baixo', 'esquerda']) {
      expect(find.byKey(ValueKey('carta-distribuida-$id')), findsOneWidget);
    }
    expect(
      find.byWidgetPredicate(
        (widget) => widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>)
                .value
                .startsWith('carta-distribuida-'),
      ),
      findsNWidgets(4),
    );
  });
}
