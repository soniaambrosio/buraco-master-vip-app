import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/screens/configurar_mesa_screen.dart';
import '../lib/screens/onde_jogar_screen.dart';

void main() {
  group('Configuração de Mesa — contrato visual aprovado', () {
    test('Mesa Pública mostra somente opções públicas', () {
      final vm = ConfigMesaVM.mock(tipo: TipoMesa.publica);

      expect(vm.tipo, TipoMesa.publica);
      expect(vm.aposta, isNull);
      expect(vm.espectadores, isNull);
      expect(vm.codigo, isNull);
      expect(vm.cadeiras, isNull);
      expect(vm.custoCriar, 0);
      expect(vm.pontosOpcoes, [1500, 3000]);
      expect(vm.tempoOpcoes, [15, 30, 45]);
    });

    test('Mesa VIP tem aposta em moedas e não herda controles da Privada', () {
      final vm = ConfigMesaVM.mock(tipo: TipoMesa.vip);

      expect(vm.tipo, TipoMesa.vip);
      expect(vm.aposta, isNotNull);
      expect(vm.aposta!.opcoes, [0, 500, 1000, 5000]);
      expect(vm.espectadores, isNull);
      expect(vm.codigo, isNull);
      expect(vm.cadeiras, isNull);
    });

    test('Mesa Privada preserva configuração completa e custo próprio', () {
      final vm = ConfigMesaVM.mock(tipo: TipoMesa.privada);

      expect(vm.tipo, TipoMesa.privada);
      expect(vm.aposta, isNotNull);
      expect(vm.aposta!.opcoes, [0, 500, 1000, 5000]);
      expect(vm.espectadores, isTrue);
      expect(vm.codigo, 'BURACO-7K2M');
      expect(vm.cadeiras, isNotNull);
      expect(vm.cadeiras, hasLength(4));
      expect(vm.custoCriar, 500);
    });

    test('dono e convidado ficam protegidos; só vagas livres podem alternar', () {
      final vm = ConfigMesaVM.mock(tipo: TipoMesa.privada);
      final cadeiras = vm.cadeiras!;

      expect(cadeiras[0].id, 'dono');
      expect(cadeiras[0].estado, EstadoCadeira.travada);
      expect(cadeiras[0].podeAlternar, isFalse);

      expect(cadeiras[1].id, 'convidado');
      expect(cadeiras[1].estado, EstadoCadeira.travada);
      expect(cadeiras[1].podeAlternar, isFalse);

      expect(cadeiras[2].id, 'reservada');
      expect(cadeiras[2].podeAlternar, isTrue);

      expect(cadeiras[3].id, 'aberta');
      expect(cadeiras[3].estado, EstadoCadeira.liberada);
      expect(cadeiras[3].podeAlternar, isTrue);
    });

    test('pote acompanha aposta x quantidade de jogadores', () {
      const aposta = ApostaVM(
        valor: 1000,
        opcoes: [0, 500, 1000, 5000],
        pote: 4000,
      );

      expect(aposta.valor * 4, aposta.pote);
      expect(aposta.copyWith(valor: 500, pote: 1000).pote, 1000);
    });
  });

  group('Onde jogar — rota aprovada', () {
    test('cada ambiente possui uma única saída e a privada não cai no lobby legado', () {
      final vm = OndeJogarVM.mock(ehVip: true);
      final ids = vm.opcoes.map((opcao) => opcao.id).toList();

      expect(ids, ['publica', 'vip', 'privada_config', 'treino']);
      expect(ids.toSet(), hasLength(ids.length));

      final privada = vm.opcoes.singleWhere((opcao) => opcao.titulo == 'Mesa Privada');
      expect(privada.id, 'privada_config');
      expect(privada.id, isNot('privada'));
      expect(privada.bloqueado, isTrue);
    });
  });

  testWidgets('não VIP não atravessa gate da Mesa VIP nem da criação Privada',
      (tester) async {
    final escolhidos = <String>[];
    final bloqueados = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        home: OndeJogarScreen(
          vm: OndeJogarVM.mock(ehVip: false),
          onVoltar: () {},
          onEscolher: escolhidos.add,
          onBloqueado: bloqueados.add,
        ),
      ),
    );

    await tester.tap(find.text('Mesa VIP'));
    await tester.pump();
    await tester.tap(find.text('Mesa Privada'));
    await tester.pump();

    expect(escolhidos, isEmpty);
    expect(bloqueados, ['vip', 'privada_config']);
  });

  testWidgets('VIP pode abrir Mesa VIP e criação da Privada', (tester) async {
    final escolhidos = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        home: OndeJogarScreen(
          vm: OndeJogarVM.mock(ehVip: true),
          onVoltar: () {},
          onEscolher: escolhidos.add,
        ),
      ),
    );

    await tester.tap(find.text('Mesa VIP'));
    await tester.pump();
    await tester.tap(find.text('Mesa Privada'));
    await tester.pump();

    expect(escolhidos, ['vip', 'privada_config']);
  });

  testWidgets('Mesa Privada organiza código, espectadores e cadeiras sem seletor de tipo',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ConfigurarMesaScreen(
          vm: ConfigMesaVM.mock(tipo: TipoMesa.privada),
          onVoltar: () {},
          onTipo: (_) {},
          onTipoBloqueado: (_) {},
          onModalidade: (_) {},
          onVerRegras: () {},
          onModo: (_) {},
          onPontos: (_) {},
          onAposta: (_) {},
          onTempo: (_) {},
          onChat: (_) {},
          onEspectadores: (_) {},
          onCopiar: () {},
          onAlternarCadeira: (_) {},
          onCriarMesa: () {},
        ),
      ),
    );

    expect(find.text('Configurar Mesa Privada'), findsOneWidget);
    expect(find.text('Seu espaço, suas regras'), findsOneWidget);
    expect(find.text('ACESSO À SALA'), findsOneWidget);
    expect(find.text('BURACO-7K2M'), findsOneWidget);
    expect(find.text('ESPECTADORES'), findsOneWidget);
    expect(find.text('CADEIRAS'), findsOneWidget);
    expect(find.text('Resumo da mesa'), findsOneWidget);
    expect(find.text('CRIAR MESA PRIVADA'), findsOneWidget);
    expect(find.text('STBL'), findsOneWidget);

    expect(find.text('Pública'), findsNothing);
    expect(find.text('VIP'), findsNothing);
    expect(find.text('Privada'), findsNothing);
  });

  testWidgets('Mesa Privada com 2 jogadores não exibe quatro cadeiras', (tester) async {
    final vm = ConfigMesaVM.mock(tipo: TipoMesa.privada).copyWith(
      modo: ModoJogo.dois,
      aposta: const ApostaVM(
        valor: 500,
        opcoes: [0, 500, 1000, 5000],
        pote: 1000,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ConfigurarMesaScreen(
          vm: vm,
          onVoltar: () {},
          onTipo: (_) {},
          onTipoBloqueado: (_) {},
          onModalidade: (_) {},
          onVerRegras: () {},
          onModo: (_) {},
          onPontos: (_) {},
          onAposta: (_) {},
          onTempo: (_) {},
          onChat: (_) {},
          onEspectadores: (_) {},
          onCopiar: () {},
          onAlternarCadeira: (_) {},
          onCriarMesa: () {},
        ),
      ),
    );

    expect(find.text('Você (dono)'), findsOneWidget);
    expect(find.text('Cláudia'), findsOneWidget);
    expect(find.text('Reservada'), findsNothing);
    expect(find.text('Aberta'), findsNothing);
    expect(find.textContaining('2 jogadores'), findsOneWidget);
  });
}
