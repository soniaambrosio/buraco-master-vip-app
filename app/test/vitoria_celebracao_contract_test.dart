import 'package:flutter_test/flutter_test.dart';

import '../lib/screens/resultado_partida_screen.dart';
import '../lib/screens/resultado_vitoria_adapter.dart';

void main() {
  const jogadores = [
    JogadorResultadoVM(
      assento: 0,
      nome: 'Sônia',
      avatar: '👑',
      souEu: true,
    ),
    JogadorResultadoVM(
      assento: 1,
      nome: 'Carlos',
      avatar: '🧔🏻',
    ),
    JogadorResultadoVM(
      assento: 2,
      nome: 'Cláudia',
      avatar: '🐰',
    ),
    JogadorResultadoVM(
      assento: 3,
      nome: 'Rafael',
      avatar: '🧔🏽',
    ),
  ];

  test('dupla vencedora confirmada ativa confete e som para vencedora local', () {
    final vm = celebracaoVitoriaDoResultado(
      eventoId: 'resultado-partida-001',
      fimPartida: true,
      assentosVencedores: const {0, 2},
      jogadores: jogadores,
      somHabilitado: true,
    );

    expect(vm.ativa, isTrue);
    expect(vm.jogadorLocalVenceu, isTrue);
    expect(vm.tocarSomLocal, isTrue);
    expect(vm.usarConfetePadrao, isTrue);
    expect(vm.nomesVencedores, ['Sônia', 'Cláudia']);
    expect(vm.vencedoresLabel, 'Sônia & Cláudia');
  });

  test('perdedor vê celebração dos vencedores, mas não toca som de vitória local', () {
    final vm = celebracaoVitoriaDoResultado(
      eventoId: 'resultado-partida-002',
      fimPartida: true,
      assentosVencedores: const {1, 3},
      jogadores: jogadores,
      somHabilitado: true,
    );

    expect(vm.ativa, isTrue);
    expect(vm.jogadorLocalVenceu, isFalse);
    expect(vm.tocarSomLocal, isFalse);
    expect(vm.nomesVencedores, ['Carlos', 'Rafael']);
  });

  test('fechamento de rodada não dispara celebração final', () {
    final vm = celebracaoVitoriaDoResultado(
      eventoId: 'rodada-3',
      fimPartida: false,
      assentosVencedores: const {0, 2},
      jogadores: jogadores,
      somHabilitado: true,
    );

    expect(vm.ativa, isFalse);
    expect(vm.tocarSomLocal, isFalse);
  });

  test('sem vencedor autoritativo não existe comemoração', () {
    final vm = celebracaoVitoriaDoResultado(
      eventoId: 'resultado-partida-003',
      fimPartida: true,
      assentosVencedores: const {},
      jogadores: jogadores,
      somHabilitado: true,
    );

    expect(vm.ativa, isFalse);
  });
}
