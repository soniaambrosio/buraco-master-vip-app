// A MATRIZ DA OS DE HOMOLOGAÇÃO, CONFERIDA POR FORA.
//
// Escrito do zero durante a homologação independente de
// `integracao/perfil-publicavel-canonico-v1` @ `e87dd18`, sem reusar helper
// nenhum das suítes da candidata. O motivo é o de sempre numa homologação: um
// caso que passa porque o teste vizinho o preparou não prova nada. Aqui o VM, a
// montagem da tela e a leitura do texto são todos locais.
//
// A sobreposição com `estado_canonico_ranking_test.dart` é deliberada — as duas
// suítes devem concordar, e é justamente a concordância que se está provando.
// O que NÃO existe lá, e é a razão de este arquivo ficar:
//
//   - a barra de XP conferida em TODOS os seis subconjuntos parciais de
//     (nivel, xpAtual, xpProximo): meia barra é tão inventada quanto a inteira;
//   - título presente com emoji ausente, que é o caminho por onde um
//     `'null Campeã'` entraria na faixa;
//   - `posicaoMundial: 0` vindo de uma fonte DISPONÍVEL e chegando ao convite
//     copiado — a higienização provada na superfície que sai do aparelho;
//   - `identical()` entre o ranking da Home e o do Perfil, e não só igualdade:
//     a OS pede a MESMA instância canônica, e `==` não distingue as duas coisas.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:buraco_master_vip/pages/perfil_page.dart';
import 'package:buraco_master_vip/ranking/estado_ranking.dart';
import 'package:buraco_master_vip/screens/perfil_screen.dart';
import 'package:buraco_master_vip/services/perfil_service.dart';

PerfilVM _vm({
  String nome = 'Sônia',
  EstadoRanking ranking = const EstadoRanking.indisponivel(),
  int? nivel,
  int? xpAtual,
  int? xpProximo,
  String? titulo,
  String? tituloEmoji,
  PerfilStats? stats,
  int? presentesCount,
  List<Conquista>? conquistas,
  List<ItemVitrine> vitrine = const [],
}) {
  return PerfilVM(
    ehMeuPerfil: true,
    nome: nome,
    avatar: '👑',
    mascote: '🦊',
    moldura: 'assets/perfil/vitrine_moldura.webp',
    dorso: 'assets/perfil/vitrine_dorso.webp',
    efeito: 'assets/perfil/vitrine_efeito.webp',
    nivel: nivel,
    xpAtual: xpAtual,
    xpProximo: xpProximo,
    titulo: titulo,
    tituloEmoji: tituloEmoji,
    ranking: ranking,
    stats: stats,
    ultimaConquista: null,
    presentesCount: presentesCount,
    conquistas: conquistas,
    vitrine: vitrine,
    presentes: const [],
  );
}

Future<void> _montar(
  WidgetTester tester,
  PerfilVM vm, {
  PerfilEstado estado = PerfilEstado.normal,
  String? mensagemErro,
}) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: PerfilScreen(
        vm: vm,
        estado: estado,
        mensagemErro: mensagemErro,
        onVoltar: () {},
        onAbrirConfig: () {},
        onTrocarAvatar: () {},
        onEditarNick: () {},
        onEditarPerfil: () {},
        onAbrirPresentes: () {},
        onFecharPresentes: () {},
        onVerTodasConquistas: () {},
        onVerConquista: (_) {},
        onVerUltimaConquista: () {},
        onTrocarVitrine: () {},
        onCompartilhar: () {},
        onRecarregar: () {},
        onNavTap: (_) {},
      ),
    ),
  );
  await tester.pumpAndSettle();
}

List<String> _pedacos(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((t) => (t.data ?? t.textSpan?.toPlainText() ?? '').trim())
    .toList();

String _texto(WidgetTester tester) => _pedacos(tester).join(' | ');

void main() {
  group('PROBE — higienização do estado canônico', () {
    test('posicaoMundial 0, negativa e liga em branco viram ausência', () {
      for (final p in [0, -1, -128]) {
        final e = EstadoRanking.disponivel(liga: 'Ouro', posicaoMundial: p);
        expect(e.posicaoMundial, isNull, reason: 'posicao $p não é colocação');
        expect(e.temPosicao, isFalse);
      }
      for (final l in ['', '   ', '\t', '\n']) {
        final e = EstadoRanking.disponivel(liga: l, posicaoMundial: 5);
        expect(e.liga, isNull, reason: 'liga "$l" não é liga');
        expect(e.ligaParaExibicao, '—');
      }
    });

    test('fora de disponivel, nem liga nem colocação atravessam', () {
      const fases = [
        EstadoRanking.indisponivel(),
        EstadoRanking.carregando(),
        EstadoRanking.falha(),
      ];
      for (final e in fases) {
        expect(e.liga, isNull);
        expect(e.posicaoMundial, isNull);
        expect(e.temAlgumDado, isFalse);
        expect(e.ligaParaExibicao, '—');
      }
    });

    test('ranking REAL atravessa sem substituição', () {
      const e = EstadoRanking.disponivel(liga: 'Diamante', posicaoMundial: 128);
      expect(e.liga, 'Diamante');
      expect(e.posicaoMundial, 128);
      expect(e.ligaParaExibicao, 'Diamante');
      // e a colocação 1 (limite inferior legítimo) não é confundida com ausência
      expect(
        const EstadoRanking.disponivel(posicaoMundial: 1).posicaoMundial,
        1,
      );
    });
  });

  group('PROBE — a tela não desenha o que não tem fonte', () {
    testWidgets('sem classificação: identidade e vitrine ficam, "💎 Liga —"', (
      tester,
    ) async {
      await _montar(
        tester,
        _vm(
          vitrine: const [
            ItemVitrine(
              slot: 'Moldura',
              nome: 'Aurora',
              icone: 'assets/perfil/vitrine_moldura.webp',
            ),
          ],
        ),
      );

      // Identidade e vitrine permanecem.
      expect(find.text('Sônia'), findsOneWidget);
      expect(find.text('VITRINE EQUIPADA'), findsOneWidget);
      // Ausência admitida no rótulo fixo.
      expect(find.text('💎 Liga'), findsOneWidget);
      expect(find.text('—'), findsWidgets);
      // E nenhuma classificação fictícia.
      final t = _texto(tester);
      for (final proibido in [
        'Bronze',
        'Prata',
        'Ouro',
        'Diamante',
        '#0',
        'no mundo',
        'Novato',
      ]) {
        expect(t, isNot(contains(proibido)), reason: 'inventou "$proibido"');
      }
    });

    testWidgets('nível/XP/título/placar/presentes/conquistas somem', (
      tester,
    ) async {
      await _montar(tester, _vm());
      final t = _texto(tester);
      for (final proibido in [
        'XP',
        'Nível',
        'Vitórias',
        'Partidas',
        'Canastras',
        'Aproveit',
        'presentes que você recebeu',
        'CONQUISTAS',
        'Ainda sem conquistas',
      ]) {
        expect(t, isNot(contains(proibido)), reason: 'desenhou "$proibido"');
      }
      // Nenhum zero nem "1" isolado (o selo de nível do avatar).
      final p = _pedacos(tester);
      expect(p, isNot(contains('0')));
      expect(p, isNot(contains('1')));
      expect(p, isNot(contains('0%')));
    });

    testWidgets('conquistas null = não consultado; [] = consultado e vazio', (
      tester,
    ) async {
      await _montar(tester, _vm(conquistas: null));
      expect(_texto(tester), isNot(contains('CONQUISTAS')));
      expect(_texto(tester), isNot(contains('Ainda sem conquistas')));

      await _montar(tester, _vm(conquistas: const []));
      expect(_texto(tester), contains('CONQUISTAS'));
      expect(_texto(tester), contains('Ainda sem conquistas'));
    });

    testWidgets('XP exige os TRÊS campos: nenhum subconjunto desenha barra', (
      tester,
    ) async {
      // Meia barra é tão inventada quanto a barra inteira.
      final parciais = <PerfilVM>[
        _vm(nivel: 5),
        _vm(xpAtual: 100),
        _vm(xpProximo: 1000),
        _vm(nivel: 5, xpAtual: 100),
        _vm(nivel: 5, xpProximo: 1000),
        _vm(xpAtual: 100, xpProximo: 1000),
      ];
      for (final vm in parciais) {
        await _montar(tester, vm);
        expect(
          _texto(tester),
          isNot(contains('XP')),
          reason: 'barra de XP desenhada com campo faltando',
        );
      }
      // Com os três, ela volta.
      await _montar(tester, _vm(nivel: 5, xpAtual: 100, xpProximo: 1000));
      expect(_texto(tester), contains('XP'));
    });

    testWidgets('título sem emoji não vira "null Campeã"', (tester) async {
      await _montar(tester, _vm(titulo: 'Campeã', tituloEmoji: null));
      final t = _texto(tester);
      expect(t, contains('Campeã'));
      expect(t, isNot(contains('null')));
    });
  });

  group('PROBE — carregando e erro', () {
    testWidgets('carregando: esqueleto, sem nome nem número inventado', (
      tester,
    ) async {
      await _montar(
        tester,
        const PerfilService().vmPlaceholder(),
        estado: PerfilEstado.carregando,
      );
      final t = _texto(tester);
      for (final proibido in [
        'Sônia',
        'Bronze',
        'no mundo',
        'XP',
        'Vitórias',
        'CONQUISTAS',
        'Novato',
      ]) {
        expect(t, isNot(contains(proibido)));
      }
      final p = _pedacos(tester);
      expect(p, isNot(contains('0')));
      expect(p, isNot(contains('1')));
    });

    testWidgets('erro: pede recarga e NÃO reaproveita o VM anterior', (
      tester,
    ) async {
      // O VM entregue é o mais "cheio" possível — a maquete. Se a tela
      // desenhasse o corpo no estado de erro, tudo isto vazaria.
      await _montar(
        tester,
        PerfilVM.mock(),
        estado: PerfilEstado.erro,
        mensagemErro: 'Não consegui carregar seu perfil agora. Tenta de novo?',
      );
      final t = _texto(tester);
      expect(t, contains('Tenta de novo'));
      for (final vazado in [
        'Diamante',
        '#128',
        'Rainha da Canastra',
        'Vitórias',
        'XP',
        'CONQUISTAS',
      ]) {
        expect(t, isNot(contains(vazado)), reason: 'VM antigo vazou: $vazado');
      }
    });
  });

  group('PROBE — o convite que sai do aparelho', () {
    test('sem nada competitivo, fecha em "Sou {nome} 👑" sem órfão', () {
      final texto = PerfilPage.textoDeCompartilhamento(_vm(nome: 'Sônia'));
      expect(texto, endsWith('Sou Sônia 👑'));
      expect(texto, isNot(contains('Nível')));
      expect(texto, isNot(contains('Liga')));
      expect(texto, isNot(contains('#')));
      expect(texto, isNot(contains('—')));
      expect(texto, isNot(contains('null')));
      // Nenhuma pontuação órfã em nenhuma forma.
      expect(texto.trimRight(), isNot(endsWith('.')));
      expect(texto, isNot(contains('👑 .')));
      expect(texto, isNot(contains('👑 ·')));
      expect(texto, isNot(contains('· .')));
      expect(texto, isNot(contains('  ')));
    });

    test('com dado real, o convite volta a afirmar — e pontua certo', () {
      final texto = PerfilPage.textoDeCompartilhamento(
        _vm(
          nome: 'Sônia',
          nivel: 24,
          ranking: const EstadoRanking.disponivel(
            liga: 'Diamante',
            posicaoMundial: 128,
          ),
        ),
      );
      expect(texto, contains('Sou Sônia 👑'));
      expect(texto, contains('Nível 24'));
      expect(texto, contains('Liga Diamante'));
      expect(texto, contains('#128 no mundo'));
      expect(texto, endsWith('.'));
      expect(texto, isNot(contains('  ')));
    });

    test('colocação 0 vinda da fonte não vira "#0" no convite', () {
      final texto = PerfilPage.textoDeCompartilhamento(
        _vm(
          nome: 'Sônia',
          ranking: const EstadoRanking.disponivel(posicaoMundial: 0),
        ),
      );
      expect(texto, isNot(contains('#')));
      expect(texto, endsWith('Sou Sônia 👑'));
    });

    test('sem VM não afirma nem nome', () {
      final texto = PerfilPage.textoDeCompartilhamento(null);
      expect(texto, isNot(contains('Sou')));
      expect(texto, isNot(contains('Nível')));
      expect(texto, isNot(contains('Liga')));
    });
  });

  group('PROBE — a mesma fonte canônica em toda superfície', () {
    test('Home, Perfil e convite leem a MESMA instância', () async {
      // A constante é uma só e é `const`: identidade referencial, não igualdade.
      const daHome = rankingDaCascaPublicavel;
      final doPerfil = (await const PerfilService().carregar()).ranking;
      expect(identical(doPerfil, daHome), isTrue, reason: 'mesma instância');
      expect(daHome.liga, isNull);
      expect(daHome.posicaoMundial, isNull);

      // E o convite, montado do mesmo VM, não afirma nada competitivo.
      final vm = await const PerfilService().carregar();
      final texto = PerfilPage.textoDeCompartilhamento(vm);
      expect(texto, isNot(contains('Liga')));
      expect(texto, isNot(contains('#')));
    });

    test('o serviço publicável não entrega nenhum dos oito absorvidos', () async {
      final vm = await const PerfilService().carregar();
      expect(vm.nivel, isNull);
      expect(vm.xpAtual, isNull);
      expect(vm.xpProximo, isNull);
      expect(vm.titulo, isNull);
      expect(vm.tituloEmoji, isNull);
      expect(vm.stats, isNull);
      expect(vm.presentesCount, isNull);
      expect(vm.conquistas, isNull);
      expect(vm.ultimaConquista, isNull);
      // A chave de demonstração está DESLIGADA no código publicável.
      expect(PerfilService.statsDemo, isFalse);
    });
  });
}
