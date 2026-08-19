import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/screens/configurar_mesa_screen.dart';
import '../lib/screens/mesa_config_contract.dart';
import '../lib/screens/mesa_config_validator.dart';
import '../lib/screens/mesa_privada_social.dart';
import '../lib/screens/onde_jogar_screen.dart';
import 'superficie_de_teste.dart';

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

    test('Mesa VIP tem aposta e não herda controles da Privada', () {
      final vm = ConfigMesaVM.mock(tipo: TipoMesa.vip);

      expect(vm.aposta, isNotNull);
      expect(vm.aposta!.opcoes, [0, 500, 1000, 5000]);
      expect(vm.espectadores, isNull);
      expect(vm.codigo, isNull);
      expect(vm.cadeiras, isNull);
      expect(vm.custoCriar, 250);
    });

    test('Mesa Privada preserva aposta, código, cadeiras e custo próprio', () {
      final vm = ConfigMesaVM.mock(tipo: TipoMesa.privada);

      expect(vm.aposta, isNotNull);
      expect(vm.espectadores, isTrue);
      expect(vm.codigo, 'BURACO-7K2M');
      expect(vm.cadeiras, hasLength(4));
      expect(vm.custoCriar, 500);
      expect(vm.cadeiras![0].ocupada, isTrue);
      expect(vm.cadeiras![0].ehVip, isTrue);
      expect(vm.cadeiras![1].ocupada, isTrue);
      expect(vm.cadeiras![1].ehVip, isTrue);
    });

    test('dono e convidado ficam protegidos; só vagas livres alternam', () {
      final cadeiras = ConfigMesaVM.mock(tipo: TipoMesa.privada).cadeiras!;

      expect(cadeiras[0].id, 'dono');
      expect(cadeiras[0].estado, EstadoCadeira.travada);
      expect(cadeiras[0].podeAlternar, isFalse);

      expect(cadeiras[1].id, 'convidado');
      expect(cadeiras[1].estado, EstadoCadeira.travada);
      expect(cadeiras[1].podeAlternar, isFalse);

      expect(cadeiras[2].podeAlternar, isTrue);
      expect(cadeiras[3].estado, EstadoCadeira.liberada);
      expect(cadeiras[3].podeAlternar, isTrue);
    });
  });

  group('Mesa Privada — regra VIP e montagem da turma', () {
    test('papéis das cadeiras respeitam 4 jogadores e 2 jogadores', () {
      expect(
        MesaPrivadaPolicy.papelDaCadeira(
          quantidadeJogadores: 4,
          indice: 0,
        ),
        PapelCadeiraPrivada.dono,
      );
      expect(
        MesaPrivadaPolicy.papelDaCadeira(
          quantidadeJogadores: 4,
          indice: 1,
        ),
        PapelCadeiraPrivada.parceiro,
      );
      expect(
        MesaPrivadaPolicy.papelDaCadeira(
          quantidadeJogadores: 4,
          indice: 2,
        ),
        PapelCadeiraPrivada.oponente,
      );
      expect(
        MesaPrivadaPolicy.papelDaCadeira(
          quantidadeJogadores: 2,
          indice: 1,
        ),
        PapelCadeiraPrivada.oponente,
      );
    });

    test('contrato exige VIP nas cadeiras e admite Passe Convidado ocasional', () {
      // `ehVip: true` DECLARADO: criar mesa privada exige VIP, e o mock não
      // concede mais por omissão. Ver MOCK-04 em enforcement_vip_ui_test.dart.
      final contract = MesaConfigContract.fromVm(
        ConfigMesaVM.mock(tipo: TipoMesa.privada, ehVip: true),
      );

      expect(contract.exigeVipDosParticipantes, isTrue);
      expect(contract.permitePasseConvidadoVip, isTrue);
      expect(contract.espectadorPodeSerNaoVip, isTrue);
      expect(validarMesaConfig(contract).ok, isTrue);
    });

    test('participante ocupado sem VIP nem passe é recusado pelo contrato visual', () {
      final vm = ConfigMesaVM.mock(tipo: TipoMesa.privada);
      final cadeiras = List<CadeiraVM>.of(vm.cadeiras!);
      cadeiras[1] = cadeiras[1].copyWith(
        ehVip: false,
        passeConvidadoVip: false,
      );

      final result = validarMesaConfig(
        MesaConfigContract.fromVm(vm.copyWith(cadeiras: cadeiras)),
      );

      expect(result.ok, isFalse);
      expect(
        result.erros,
        contains('PRIVADA_PARTICIPANTE_SEM_VIP_OU_PASSE:convidado'),
      );
    });

    test('Passe Convidado VIP válido permite a cadeira promocional', () {
      // Quem CRIA a mesa é VIP (declarado); o que este caso mede é a cadeira
      // do CONVIDADO, que entra sem VIP mas com passe promocional válido.
      final vm = ConfigMesaVM.mock(tipo: TipoMesa.privada, ehVip: true);
      final cadeiras = List<CadeiraVM>.of(vm.cadeiras!);
      cadeiras[1] = cadeiras[1].copyWith(
        ehVip: false,
        passeConvidadoVip: true,
      );

      final result = validarMesaConfig(
        MesaConfigContract.fromVm(vm.copyWith(cadeiras: cadeiras)),
      );

      expect(result.ok, isTrue);
    });
  });

  group('Onde jogar — acesso privado', () {
    test('cada ambiente tem saída única e a Privada evita lobby legado', () {
      final vm = OndeJogarVM.mock(ehVip: true);
      final ids = vm.opcoes.map((opcao) => opcao.id).toList();

      expect(ids, ['publica', 'vip', 'privada_config', 'treino']);
      expect(ids.toSet(), hasLength(ids.length));
      final privada = vm.opcoes.singleWhere(
        (opcao) => opcao.titulo == 'Mesa Privada',
      );
      expect(privada.bloqueado, isTrue);
      expect(privada.nota, contains('Passe Convidado VIP'));
    });

    testWidgets('não VIP não cria VIP nem Privada', (tester) async {
      usarTelefoneRetrato(tester);
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

    testWidgets('código pode ser informado antes da validação VIP/Passe no servidor',
        (tester) async {
      usarTelefoneRetrato(tester);
      var entradasPorCodigo = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: OndeJogarScreen(
            vm: OndeJogarVM.mock(ehVip: false),
            onVoltar: () {},
            onEscolher: (_) {},
            onEntrarCodigo: () => entradasPorCodigo++,
          ),
        ),
      );

      // O atalho fica no cartao da Privada, o terceiro da lista: em telefone
      // ele nasce logo abaixo da dobra e precisa entrar em cena antes do toque.
      await tester.ensureVisible(find.byKey(const ValueKey('entrar-com-codigo')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('entrar-com-codigo')));
      await tester.pump();

      expect(entradasPorCodigo, 1);
      expect(
        find.text('VIP ativo ou Passe Convidado VIP válido'),
        findsOneWidget,
      );
    });
  });

  testWidgets('Privada mostra slogan, chat livre, segurança e montagem da turma',
      (tester) async {
    usarTelefoneRetrato(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: ConfigurarMesaScreen(
          vm: ConfigMesaVM.mock(tipo: TipoMesa.privada),
          onVoltar: () {},
          onTipo: (_) {},          onModalidade: (_) {},
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
    expect(
      find.text('Monte sua mesa. E resolvam no baralho.'),
      findsOneWidget,
    );
    expect(find.text('Todos os jogadores são VIP'), findsOneWidget);
    expect(find.text('STBL'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Chat livre, com proteção'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Chat livre, com proteção'), findsOneWidget);
    // 'Livre' e o rotulo do chat completo quando a mesa e privada; ele vive no
    // mesmo bloco do chat, entao so existe depois desta rolagem.
    expect(find.text('Livre'), findsOneWidget);
    expect(find.text('Silenciar'), findsOneWidget);
    expect(find.text('Bloquear'), findsOneWidget);
    expect(find.text('Denunciar'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('MONTE SUA PARTIDA'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('MONTE SUA PARTIDA'), findsOneWidget);
    expect(find.text('DONO'), findsOneWidget);
    expect(find.text('PARCEIRO'), findsOneWidget);
    expect(find.text('OPONENTE'), findsWidgets);
  });

  testWidgets('menu do convidado expõe silenciar, bloquear e denunciar',
      (tester) async {
    usarTelefoneRetrato(tester);
    // O menu suspenso poe icone e rotulo na mesma linha: com a fonte do runner
    // o rotulo fica largo demais e a linha estoura na horizontal.
    ignorarOverflowDaFonteDeTeste();
    final acoes = <AcaoSocialPrivada>[];

    await tester.pumpWidget(
      MaterialApp(
        home: ConfigurarMesaScreen(
          vm: ConfigMesaVM.mock(tipo: TipoMesa.privada),
          onVoltar: () {},
          onTipo: (_) {},          onModalidade: (_) {},
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
          onAcaoSocialPrivada: (_, acao) => acoes.add(acao),
        ),
      ),
    );

    await tester.scrollUntilVisible(
      find.text('Cláudia'),
      350,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.byTooltip('Ações do jogador'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Ações do jogador'));
    await tester.pumpAndSettle();
    expect(find.text('Silenciar para mim'), findsOneWidget);
    expect(find.text('Bloquear jogador'), findsOneWidget);
    expect(find.text('Denunciar'), findsWidgets);

    await tester.tap(find.text('Denunciar').last);
    await tester.pumpAndSettle();
    expect(acoes, [AcaoSocialPrivada.denunciar]);
  });

  testWidgets('Privada de 2 jogadores mostra dono e oponente, sem parceiro',
      (tester) async {
    usarTelefoneRetrato(tester);
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
          onTipo: (_) {},          onModalidade: (_) {},
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

    await tester.scrollUntilVisible(
      find.text('Cláudia'),
      350,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Você'), findsOneWidget);
    expect(find.text('Cláudia'), findsOneWidget);
    expect(find.text('PARCEIRO'), findsNothing);
    expect(find.text('OPONENTE'), findsOneWidget);
    expect(find.text('Reservada'), findsNothing);
    expect(find.text('Aberta'), findsNothing);
  });
}
