// avatar_publico_canonico_test.dart — Home e Perfil desenham o MESMO avatar.
//
// ---------------------------------------------------------------------------
// O DEFEITO QUE ESTA SUÍTE PERSEGUE
// ---------------------------------------------------------------------------
//
// A Home lia `identidade?.avatarRef ?? '👑'`; o Perfil escrevia `avatar: '👑'`
// dentro do `PerfilService`, sem olhar para a identidade. Duas autoridades
// visuais sobre o mesmo campo — e a segunda ganhava sempre, porque não era um
// fallback: era uma constante.
//
// A prova central de quase todos os casos é a MESMA COMPARAÇÃO: monta-se a Home
// e o Perfil sobre a mesma sessão e exige-se que os dois `avatar` sejam iguais.
// Um teste que só afirmasse "o Perfil mostra o avatarRef" passaria com uma
// segunda regra escrita à parte, e a segunda regra é justamente o que produziu
// a divergência.
//
// ---------------------------------------------------------------------------
// POR QUE A COROA CONTINUA AQUI
// ---------------------------------------------------------------------------
//
// `👑` É o fallback oficial — era o da Home antes desta correção, e virou
// constante em `sessao/avatar_publico.dart`. Ela não foi removida: foi
// rebaixada de "o avatar" para "o que aparece quando não há avatar". Os casos
// M11 e M24 existem para que ninguém a promova de volta nem a apague das telas
// onde ela é ornamento (marca do aplicativo, selo de VIP, convite).
//
// SUPERFÍCIE DE TELEFONE: o padrão do `flutter_test` é 800x600, que é paisagem
// de desktop e faz telas de celular estourarem em overflow.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:buraco_master_vip/casca/home_de_producao.dart';
import 'package:buraco_master_vip/pages/perfil_page.dart';
import 'package:buraco_master_vip/screens/inicio_screen.dart';
import 'package:buraco_master_vip/screens/perfil_screen.dart';
import 'package:buraco_master_vip/services/perfil_service.dart';
import 'package:buraco_master_vip/sessao/avatar_publico.dart';
import 'package:buraco_master_vip/sessao/escopo_sessao.dart';
import 'package:buraco_master_vip/sessao/fonte_identidade.dart';
import 'package:buraco_master_vip/sessao/identidade_publica_sessao.dart';
import 'package:buraco_master_vip/sessao/sessao_do_jogador.dart';

// ===========================================================================
// Fixtures
// ===========================================================================

const String kPublicIdA = 'P0A1B2C3D4E5';
const String kPublicIdB = 'PZZ9Y8X7W6V5';

/// Uma referência de avatar BEM FORMADA, e curta o bastante para caber no
/// círculo de 56px da Home sem estourar a linha do cabeçalho.
const String kAvatarValido = 'coruja_dourada';

/// A fonte de identidade, encenada — e contada.
///
/// A contagem é a testemunha de que nem a Home nem o Perfil pedem identidade:
/// só o login e o `recarregar()` explícito movem este número.
class FonteEspia implements FonteDeIdentidade {
  FonteEspia({
    this.publicId = kPublicIdA,
    this.avatarRef,
    this.apelido = 'Ana',
  });

  String publicId;
  String? avatarRef;
  String apelido;
  int chamadas = 0;

  /// Quando `false`, a resposta fica pendurada até [responder].
  ///
  /// É o que permite observar a JANELA entre "a sessão virou" e "a identidade
  /// nova chegou" — o instante exato em que um cache não invalidado mostraria
  /// o avatar do jogador anterior. Com resposta imediata essa janela existe,
  /// mas dura menos de um quadro, e o teste passaria sem tê-la visitado.
  bool automatica = true;
  final List<Completer<IdentidadePublica>> pendentes = [];

  IdentidadePublica get _atual => IdentidadePublica(
    publicId: publicId,
    apelido: apelido,
    avatarRef: avatarRef,
    criada: false,
    estado: EstadoPerfil.ativo,
    limites: LimitesSociais.desconhecidos,
    edicao: MetadadosDeEdicao.desconhecidos,
  );

  void responder() => pendentes.removeAt(0).complete(_atual);

  @override
  Future<IdentidadePublica> obterMinhaIdentidade() {
    chamadas++;
    if (automatica) return Future<IdentidadePublica>.value(_atual);
    final c = Completer<IdentidadePublica>();
    pendentes.add(c);
    return c.future;
  }
}

class _FonteQueNuncaResponde implements FonteDeIdentidade {
  int chamadas = 0;

  @override
  Future<IdentidadePublica> obterMinhaIdentidade() {
    chamadas++;
    return Completer<IdentidadePublica>().future;
  }
}

// ===========================================================================
// Ferramentas de auditoria estrutural
// ===========================================================================

String _barras(String caminho) => caminho.replaceAll(r'\', '/');

/// O arquivo SEM comentários, respeitando aspas.
///
/// Mesma técnica de `auditoria_casca_test.dart` e pelo mesmo motivo: este
/// próprio módulo explica em prosa o que é proibido, e uma varredura ingênua
/// acusaria a explicação como violação.
String _codigo(File f) {
  final fonte = f.readAsStringSync();
  final saida = StringBuffer();
  var i = 0;
  String? aspa;
  while (i < fonte.length) {
    final c = fonte[i];
    final proximo = i + 1 < fonte.length ? fonte[i + 1] : '';

    if (aspa != null) {
      saida.write(c);
      if (c == r'\') {
        if (proximo.isNotEmpty) saida.write(proximo);
        i += 2;
        continue;
      }
      if (c == aspa) aspa = null;
      i++;
      continue;
    }

    if (c == '/' && proximo == '/') {
      while (i < fonte.length && fonte[i] != '\n') {
        i++;
      }
      continue;
    }
    if (c == '/' && proximo == '*') {
      i += 2;
      while (i < fonte.length &&
          !(fonte[i] == '*' && i + 1 < fonte.length && fonte[i + 1] == '/')) {
        i++;
      }
      i += 2;
      continue;
    }
    if (c == "'" || c == '"') aspa = c;
    saida.write(c);
    i++;
  }
  return saida.toString();
}

String _resolverImport(String deQuem, String importado) {
  if (importado.startsWith('package:buraco_master_vip/')) {
    return 'lib/${importado.substring('package:buraco_master_vip/'.length)}';
  }
  final base = _barras(deQuem).split('/')..removeLast();
  for (final parte in importado.split('/')) {
    if (parte == '.' || parte.isEmpty) continue;
    if (parte == '..') {
      if (base.isNotEmpty) base.removeLast();
      continue;
    }
    base.add(parte);
  }
  return base.join('/');
}

final RegExp _reImport = RegExp(r'''import\s+['"]([^'"]+)['"]''');

/// O fecho transitivo dos imports a partir de `lib/main.dart`.
Set<String> _alcancaveisDaRaiz() {
  final vistos = <String>{};
  final fila = <String>['lib/main.dart'];
  while (fila.isNotEmpty) {
    final atual = fila.removeLast();
    if (!vistos.add(atual)) continue;
    final f = File(atual);
    if (!f.existsSync()) continue;
    for (final m in _reImport.allMatches(_codigo(f))) {
      final alvo = m.group(1)!;
      if (alvo.startsWith('dart:')) continue;
      if (alvo.startsWith('package:') &&
          !alvo.startsWith('package:buraco_master_vip/')) {
        continue;
      }
      fila.add(_resolverImport(atual, alvo));
    }
  }
  return vistos;
}

/// O código SEM os factories `.mock()`.
///
/// As maquetes são catálogo visual: `InicioVM.mock()` e `PerfilVM.mock()`
/// existem para o protótipo e para os testes, e `auditoria_casca_test.dart` já
/// prova que NENHUMA rota nascida em `main()` as CONSTRÓI. Elas continuam
/// escrevendo `avatar: '👑'`, e devem continuar — é fixture declarada, não a
/// segunda autoridade que esta OS foi fechar. Uma varredura que não as
/// descontasse obrigaria a mexer no protótipo para provar algo sobre produção.
String _semMaquetes(String codigo) {
  final saida = StringBuffer();
  final inicio = RegExp(r'factory\s+\w+\.mock\s*\(');
  var resto = codigo;
  while (true) {
    final m = inicio.firstMatch(resto);
    if (m == null) {
      saida.write(resto);
      return saida.toString();
    }
    saida.write(resto.substring(0, m.start));
    // Fecha primeiro a LISTA DE PARÂMETROS. Sem isto, a chave dos parâmetros
    // nomeados (`factory PerfilVM.mock({bool ehMeuPerfil = true})`) seria
    // confundida com a chave do corpo, e o corpo ficaria inteiro na varredura.
    var i = m.end;
    var parenteses = 1;
    while (i < resto.length && parenteses > 0) {
      if (resto[i] == '(') parenteses++;
      if (resto[i] == ')') parenteses--;
      i++;
    }
    // Agora sim: a chave que abre o corpo, e a contagem até ela fechar.
    i = resto.indexOf('{', i);
    if (i < 0) return saida.toString();
    var nivel = 0;
    for (; i < resto.length; i++) {
      if (resto[i] == '{') nivel++;
      if (resto[i] == '}') {
        nivel--;
        if (nivel == 0) {
          i++;
          break;
        }
      }
    }
    resto = resto.substring(i);
  }
}

/// O conteúdo do arquivo com as quebras de linha normalizadas para `\n`.
///
/// OBRIGATÓRIO para qualquer comparação de bytes neste repositório: o checkout
/// no Windows entrega `\r\n` e o do CI entrega `\n`. Sem normalizar, um digest
/// de arquivo prova o sistema operacional, e não o conteúdo.
String _normalizado(File f) => f.readAsStringSync().replaceAll('\r\n', '\n');

void main() {
  late FonteEspia fonte;
  late StreamController<String?> auth;
  late SessaoDoJogador sessao;

  setUp(() {
    fonte = FonteEspia();
    auth = StreamController<String?>.broadcast();
  });

  tearDown(() => auth.close());

  /// Abre a sessão DENTRO do corpo do teste, e não no `setUp`.
  ///
  /// `testWidgets` roda o corpo num zone de tempo falso e o `setUp` roda fora
  /// dele; uma assinatura registrada no `setUp` entrega seus eventos num mundo
  /// que o relógio do `pump` jamais adianta, e o login nunca chegaria.
  void abrirSessao() {
    sessao = SessaoDoJogador(fonte: fonte, uids: auth.stream);
    addTearDown(sessao.dispose);
  }

  Future<void> montar(WidgetTester tester, Widget tela) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      EscopoSessao(
        sessao: sessao,
        child: MaterialApp(home: tela),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Monta o Perfil e deixa a carga simulada do serviço (350ms) terminar.
  Future<void> montarPerfil(WidgetTester tester) async {
    await montar(tester, const PerfilPage());
    await tester.pumpAndSettle(const Duration(milliseconds: 500));
  }

  /// Drena as cargas em cascata do Perfil.
  ///
  /// `pumpAndSettle` SOZINHO NÃO SERVE aqui, e a razão é específica desta tela:
  /// `didChangeDependencies` chama `setState` DENTRO do quadro que está sendo
  /// construído, e marcar sujo no quadro corrente não agenda um quadro novo.
  /// O `pumpAndSettle` então devolve com o temporizador de 350ms do serviço
  /// ainda pendente, e o teste morre por "pending timers" — falha de encenação,
  /// não de comportamento. Uma troca de sessão pode encadear até três cargas
  /// (a da fase `carregando`, a da identidade nova e a do rebuild), então o
  /// laço avança tempo o bastante para todas terminarem.
  Future<void> drenarCargas(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 400));
    }
    await tester.pumpAndSettle();
  }

  /// "login" — a sessão resolve a identidade antes de qualquer tela abrir.
  Future<void> login(WidgetTester tester, [String uid = 'uid-A']) async {
    abrirSessao();
    await tester.pumpWidget(const SizedBox.shrink());
    auth.add(uid);
    await tester.pump();
    await tester.pump();
  }

  String avatarDaHome(WidgetTester tester) =>
      tester.widget<InicioScreen>(find.byType(InicioScreen)).vm.jogador.avatar;

  String avatarDoPerfil(WidgetTester tester) =>
      tester.widget<PerfilScreen>(find.byType(PerfilScreen)).vm.avatar;

  // =========================================================================
  // O RESOLVEDOR — a regra única, sem tela
  // =========================================================================
  group('resolvedor canônico', () {
    test('M05 referência vazia e só-espaços caem no fallback', () {
      for (final vazio in ['', ' ', '   ', '\t', '\n', ' \t \n ']) {
        expect(
          avatarPublicoDe(vazio),
          kAvatarPublicoFallback,
          reason: '"$vazio" é ausência escrita com espaços, não um avatar',
        );
      }
    });

    test('M06 espaços nas bordas não mudam a referência resolvida', () {
      // O ponto do caso não é o `trim` em si: é que Home e Perfil resolvem a
      // MESMA string. Antes, quem comparasse o valor cru teria dois resultados.
      for (final sujo in [
        ' $kAvatarValido',
        '$kAvatarValido ',
        '  $kAvatarValido  ',
        '\t$kAvatarValido\n',
      ]) {
        expect(avatarPublicoDe(sujo), kAvatarValido);
      }
    });

    test('M07 referência desconhecida vira fallback, nunca tentativa', () {
      const lixo = <String>[
        'https://exemplo.invalido/foto.png', // endereço de rede arbitrário
        'http://10.0.0.1/x', // idem, sem TLS
        'assets/perfil/vitrine_avatar.webp', // caminho de asset fabricado
        '../../etc/passwd', // caminho relativo
        '<img src=x>', // marcação
        'CORUJA_DOURADA', // maiúsculas: fora do alfabeto
        'ab', // curto demais
        'coruja dourada', // espaço no meio
        '-coruja', // não começa por letra/dígito
        'coruja.png', // extensão
        '👑', // o próprio fallback não é referência válida
      ];
      for (final ref in lixo) {
        expect(
          avatarPublicoDe(ref),
          kAvatarPublicoFallback,
          reason: '"$ref" não pode chegar ao renderizador',
        );
      }
      // E o comprimento máximo é respeitado nas duas pontas.
      expect(avatarPublicoDe('a' * 64), 'a' * 64);
      expect(avatarPublicoDe('a' * 65), kAvatarPublicoFallback);
    });

    test('M07b tipo não suportado no fio já morre na hidratação', () {
      // `avatarRef` não-string nunca chega ao resolvedor: `IdentidadePublica`
      // o converte em `null` ao hidratar a resposta da callable. Sem esta
      // trava, o cliente teria de decidir o que fazer com um número.
      for (final bruto in <Object?>[
        42,
        true,
        <String, Object?>{},
        <int>[1],
      ]) {
        final id = IdentidadePublica.doWire({
          'publicId': kPublicIdA,
          'perfil': {'apelido': 'Ana', 'avatarRef': bruto},
        });
        expect(id.avatarRef, isNull);
        expect(avatarPublicoDaIdentidade(id), kAvatarPublicoFallback);
      }
    });

    test(
      'M04 ausência de identidade e ausência de avatar dão o mesmo valor',
      () {
        expect(avatarPublicoDaIdentidade(null), kAvatarPublicoFallback);
        expect(avatarPublicoDe(null), kAvatarPublicoFallback);
        expect(avatarPublicoEhFallback(kAvatarPublicoFallback), isTrue);
        expect(avatarPublicoEhFallback(kAvatarValido), isFalse);
      },
    );

    test('o formato espelha, caractere a caractere, o do domínio social', () {
      // A cópia é deliberada — `auditoria_identidade_test.dart` proíbe o
      // cliente de importar `lib/social/`, porque aquele módulo carrega a
      // fórmula de geração de `publicId`. O preço da cópia é esta comparação:
      // se um lado mudar o alfabeto, cai um teste, e não o desenho da tela.
      final dominio = _codigo(File('lib/social/apresentacao.dart'));
      final noDominio = RegExp(
        r'kFormatoAvatarRef\s*=\s*RegExp\(\s*r(.+?)\s*\)\s*;',
      ).firstMatch(dominio);
      expect(noDominio, isNotNull, reason: 'o formato do servidor sumiu');

      final cliente = _codigo(File('lib/sessao/avatar_publico.dart'));
      final noCliente = RegExp(
        r'kFormatoAvatarPublico\s*=\s*RegExp\(\s*r(.+?)\s*\)\s*;',
      ).firstMatch(cliente);
      expect(noCliente, isNotNull, reason: 'o formato do cliente sumiu');

      expect(
        noCliente!.group(1),
        noDominio!.group(1),
        reason:
            'o cliente aceitaria uma referência que o servidor recusa (ou o '
            'contrário), e a divergência apareceria como avatar sumido',
      );
    });
  });

  // =========================================================================
  // A CONVERGÊNCIA — o coração da OS
  // =========================================================================
  group('Home e Perfil consomem a mesma autoridade', () {
    testWidgets('M01 avatarRef válido aparece na Home', (tester) async {
      fonte.avatarRef = kAvatarValido;
      await login(tester);

      await montar(tester, const HomeDeProducao());

      expect(avatarDaHome(tester), kAvatarValido);
      expect(find.text(kAvatarValido), findsOneWidget);
    });

    testWidgets('M02 o MESMO avatarRef aparece no Perfil', (tester) async {
      fonte.avatarRef = kAvatarValido;
      await login(tester);

      await montarPerfil(tester);

      expect(
        avatarDoPerfil(tester),
        kAvatarValido,
        reason: 'era aqui que a coroa fixa substituía o avatar escolhido',
      );
      expect(find.text(kAvatarValido), findsOneWidget);
    });

    testWidgets('M03 Home e Perfil produzem a mesma representação', (
      tester,
    ) async {
      // Varre o espectro inteiro numa sessão só: válido, ausente, vazio, com
      // espaços, desconhecido e com cara de caminho de asset. Se as duas telas
      // tivessem regras diferentes, bastaria UM destes para separá-las.
      const refs = <String?>[
        kAvatarValido,
        null,
        '',
        '   ',
        '  $kAvatarValido  ',
        'https://exemplo.invalido/foto.png',
        'assets/perfil/vitrine_avatar.webp',
        'CORUJA',
      ];

      for (final ref in refs) {
        fonte.avatarRef = ref;
        await login(tester);

        await montar(tester, const HomeDeProducao());
        final naHome = avatarDaHome(tester);

        await montarPerfil(tester);
        final noPerfil = avatarDoPerfil(tester);

        expect(
          noPerfil,
          naHome,
          reason: 'avatarRef ${ref == null ? 'null' : '"$ref"'} divergiu',
        );
        expect(naHome, avatarPublicoDe(ref));
      }
    });

    testWidgets(
      'M04b avatarRef ausente usa o mesmo fallback nos dois lugares',
      (tester) async {
        fonte.avatarRef = null;
        await login(tester);

        await montar(tester, const HomeDeProducao());
        expect(avatarDaHome(tester), kAvatarPublicoFallback);

        await montarPerfil(tester);
        expect(avatarDoPerfil(tester), kAvatarPublicoFallback);
      },
    );

    testWidgets('M07c referência desconhecida não derruba nenhuma das telas', (
      tester,
    ) async {
      fonte.avatarRef = 'https://exemplo.invalido/foto.png';
      await login(tester);

      await montar(tester, const HomeDeProducao());
      expect(tester.takeException(), isNull);
      expect(find.byType(InicioScreen), findsOneWidget);
      expect(avatarDaHome(tester), kAvatarPublicoFallback);
      // E, sobretudo: NÃO virou requisição de rede. As imagens que a Home
      // desenha são os ícones do menu, todas de asset — nenhuma `NetworkImage`.
      final imagens = tester
          .widgetList<Image>(find.byType(Image))
          .map((i) => i.image)
          .toList();
      expect(imagens, isNotEmpty, reason: 'a Home desenha os ícones do menu');
      expect(
        imagens.whereType<NetworkImage>(),
        isEmpty,
        reason: 'um avatarRef adulterado virou endereço de rede',
      );

      await montarPerfil(tester);
      expect(tester.takeException(), isNull);
      expect(avatarDoPerfil(tester), kAvatarPublicoFallback);
    });

    testWidgets('M08 asset ausente não derruba a tela', (tester) async {
      // Duas metades. A primeira: uma referência com cara de asset é recusada
      // pelo resolvedor, então o avatar nunca vira `Image.asset` de arquivo que
      // ninguém empacotou.
      expect(
        avatarPublicoDe('assets/perfil/nao_existe.webp'),
        kAvatarPublicoFallback,
      );

      // A segunda: mesmo que um caminho quebrado chegue por outra porta (a
      // moldura e os ícones da vitrine SÃO assets, e continuam sendo), os
      // renderizadores das duas telas seguram o erro.
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: PerfilScreen(
            vm: PerfilVM.mock().comAvatarPublico('assets/nao_existe.webp'),
            estado: PerfilEstado.normal,
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
      expect(tester.takeException(), isNull);
      expect(find.byType(PerfilScreen), findsOneWidget);
    });
  });

  // =========================================================================
  // REATIVIDADE E IDENTIDADE
  // =========================================================================
  group('reatividade', () {
    testWidgets('M09 atualização do avatar reflete na Home', (tester) async {
      fonte.avatarRef = null;
      await login(tester);
      await montar(tester, const HomeDeProducao());
      expect(avatarDaHome(tester), kAvatarPublicoFallback);

      // O perfil público mudou no servidor e a sessão o releu — o caminho real
      // de uma troca de avatar, e o ÚNICO: quem relê é a sessão, por gesto.
      fonte.avatarRef = kAvatarValido;
      await sessao.recarregar();
      await tester.pumpAndSettle();

      expect(avatarDaHome(tester), kAvatarValido);
    });

    testWidgets('M10 a MESMA atualização reflete no Perfil', (tester) async {
      fonte.avatarRef = null;
      await login(tester);
      await montarPerfil(tester);
      expect(avatarDoPerfil(tester), kAvatarPublicoFallback);
      final antes = fonte.chamadas;

      fonte.avatarRef = kAvatarValido;
      await sessao.recarregar();
      await tester.pumpAndSettle(const Duration(milliseconds: 500));

      expect(
        avatarDoPerfil(tester),
        kAvatarValido,
        reason:
            'o `publicId` não mudou, então a recarga do Perfil não dispara: '
            'o avatar tem de vir do estado vivo, e não da carga congelada',
      );
      expect(
        fonte.chamadas,
        antes + 1,
        reason: 'só o `recarregar()` explícito pediu — o Perfil não pediu nada',
      );
    });

    testWidgets('M11 rebuild não volta para a coroa fixa', (tester) async {
      fonte.avatarRef = kAvatarValido;
      await login(tester);
      await montar(tester, const HomeDeProducao());

      // 60 quadros — um segundo de reconstrução contínua.
      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        expect(avatarDaHome(tester), kAvatarValido);
      }

      await montarPerfil(tester);
      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        expect(avatarDoPerfil(tester), kAvatarValido);
      }
      expect(fonte.chamadas, 1, reason: 'build não consulta identidade');
    });

    testWidgets('M12 abrir e fechar o Perfil não cria assinatura nova', (
      tester,
    ) async {
      fonte.avatarRef = kAvatarValido;
      await login(tester);
      final antes = fonte.chamadas;

      for (var i = 0; i < 5; i++) {
        await montarPerfil(tester);
        expect(avatarDoPerfil(tester), kAvatarValido);
        await tester.pumpWidget(const SizedBox.shrink());
      }

      expect(fonte.chamadas, antes);
      expect(sessao.chamadasEmitidas, antes);
    });

    testWidgets('M13 logout remove o avatar anterior', (tester) async {
      fonte.avatarRef = kAvatarValido;
      await login(tester);
      await montar(tester, const HomeDeProducao());
      expect(avatarDaHome(tester), kAvatarValido);

      auth.add(null);
      await tester.pumpAndSettle();

      expect(avatarDaHome(tester), kAvatarPublicoFallback);
      expect(find.text(kAvatarValido), findsNothing);

      await montarPerfil(tester);
      expect(avatarDoPerfil(tester), kAvatarPublicoFallback);
      expect(find.text(kAvatarValido), findsNothing);
    });

    testWidgets('M13b logout COM O PERFIL ABERTO apaga o avatar na hora', (
      tester,
    ) async {
      // A variante de M13 que importa de verdade. Em M13 o Perfil é montado
      // DEPOIS do logout, e um estado novo nasce limpo por construção — um
      // cache de avatar guardado no `State` passaria por ali sem ser visto.
      // Aqui a tela atravessa a troca de sessão sem ser desmontada.
      fonte.avatarRef = kAvatarValido;
      await login(tester);
      await montarPerfil(tester);
      expect(avatarDoPerfil(tester), kAvatarValido);

      auth.add(null);
      await tester.pump();
      await tester.pump();

      expect(sessao.estado.fase, FaseIdentidade.naoAutenticado);
      expect(
        avatarDoPerfil(tester),
        kAvatarPublicoFallback,
        reason: 'o avatar sobreviveu ao logout dentro da tela montada',
      );

      await drenarCargas(tester);
      expect(avatarDoPerfil(tester), kAvatarPublicoFallback);
      expect(find.text(kAvatarValido), findsNothing);
    });

    testWidgets('M14b troca de jogador COM O PERFIL ABERTO não vaza o antigo', (
      tester,
    ) async {
      fonte.avatarRef = kAvatarValido;
      await login(tester, 'uid-A');
      await montarPerfil(tester);
      expect(avatarDoPerfil(tester), kAvatarValido);

      // B não escolheu avatar. A janela entre a troca e a chegada da identidade
      // de B é onde um cache mostraria a coruja de A no perfil de B.
      fonte.automatica = false;
      fonte.avatarRef = null;
      fonte.publicId = kPublicIdB;
      fonte.apelido = 'Bia';
      auth.add('uid-B');
      await tester.pump();
      await tester.pump();

      expect(sessao.estado.fase, FaseIdentidade.carregando);
      expect(
        avatarDoPerfil(tester),
        kAvatarPublicoFallback,
        reason: 'o perfil de B abriu com o avatar de A',
      );

      fonte.responder();
      await drenarCargas(tester);
      expect(avatarDoPerfil(tester), kAvatarPublicoFallback);
      expect(find.text(kAvatarValido), findsNothing);
    });

    testWidgets('M14 login de outro jogador não mostra o avatar do anterior', (
      tester,
    ) async {
      fonte.avatarRef = kAvatarValido;
      await login(tester, 'uid-A');
      await montar(tester, const HomeDeProducao());
      expect(avatarDaHome(tester), kAvatarValido);

      // O jogador B ainda não tem avatar escolhido. A JANELA PERIGOSA é o
      // instante ENTRE a troca de sessão e a chegada da nova identidade: é aí
      // que um cache não invalidado mostraria a coruja do jogador A. A fonte
      // fica manual justamente para que essa janela dure quadros, e não
      // microtasks.
      fonte.automatica = false;
      fonte.avatarRef = null;
      fonte.publicId = kPublicIdB;
      auth.add('uid-B');
      await tester.pump();
      await tester.pump();

      expect(sessao.estado.fase, FaseIdentidade.carregando);
      expect(
        avatarDaHome(tester),
        kAvatarPublicoFallback,
        reason: 'o avatar do jogador anterior sobreviveu à troca de sessão',
      );
      expect(find.text(kAvatarValido), findsNothing);

      // E depois que a identidade de B chega, continua sendo o fallback.
      fonte.responder();
      await tester.pumpAndSettle();
      expect(avatarDaHome(tester), kAvatarPublicoFallback);
      expect(find.text(kAvatarValido), findsNothing);
    });

    testWidgets('M15 mudança de publicId invalida o estado anterior', (
      tester,
    ) async {
      fonte.avatarRef = kAvatarValido;
      await login(tester, 'uid-A');
      await montarPerfil(tester);
      expect(avatarDoPerfil(tester), kAvatarValido);

      fonte.publicId = kPublicIdB;
      fonte.avatarRef = 'gato_prateado';
      fonte.apelido = 'Bia';
      auth.add('uid-B');
      // Um `pump` entrega o evento de autenticação, o outro a resposta da
      // fonte; só então a carga de 350ms do serviço tem por que começar.
      await tester.pump();
      await tester.pump();
      await drenarCargas(tester);

      final vm = tester.widget<PerfilScreen>(find.byType(PerfilScreen)).vm;
      expect(vm.avatar, 'gato_prateado');
      expect(vm.nome, 'Bia');
      expect(sessao.publicId, kPublicIdB);
    });

    testWidgets('M16 Perfil em carregamento não inventa avatar definitivo', (
      tester,
    ) async {
      final lenta = _FonteQueNuncaResponde();
      sessao = SessaoDoJogador(
        fonte: lenta,
        uids: auth.stream,
        uidInicial: 'uid-A',
      );
      addTearDown(sessao.dispose);

      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        EscopoSessao(
          sessao: sessao,
          child: const MaterialApp(home: PerfilPage()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      final tela = tester.widget<PerfilScreen>(find.byType(PerfilScreen));
      expect(sessao.estado.fase, FaseIdentidade.carregando);
      expect(tela.estado, PerfilEstado.carregando);
      // O esqueleto está no ar: nenhum avatar é DESENHADO, e o valor que o VM
      // carrega é o fallback — não um avatar inventado para preencher o campo.
      expect(tela.vm.avatar, kAvatarPublicoFallback);
      expect(find.text(kAvatarValido), findsNothing);

      // Drena a carga simulada do serviço (350ms) para que o teste não termine
      // com temporizador pendente. A identidade CONTINUA em voo — e o avatar
      // continua sendo o fallback, nunca um valor fabricado para preencher o
      // campo enquanto se espera.
      await tester.pump(const Duration(milliseconds: 400));
      expect(sessao.estado.fase, FaseIdentidade.carregando);
      expect(
        tester.widget<PerfilScreen>(find.byType(PerfilScreen)).vm.avatar,
        kAvatarPublicoFallback,
      );
    });

    testWidgets('referência válida que depois fica inválida cai no fallback', (
      tester,
    ) async {
      fonte.avatarRef = kAvatarValido;
      await login(tester);
      await montar(tester, const HomeDeProducao());
      expect(avatarDaHome(tester), kAvatarValido);

      fonte.avatarRef = 'https://exemplo.invalido/foto.png';
      await sessao.recarregar();
      await tester.pumpAndSettle();

      expect(avatarDaHome(tester), kAvatarPublicoFallback);
    });
  });

  // =========================================================================
  // PRESERVAÇÕES
  // =========================================================================
  group('o que não podia mudar', () {
    testWidgets('M17 nome, ranking e moldura seguem intactos', (tester) async {
      fonte.avatarRef = kAvatarValido;
      fonte.apelido = 'Ana';
      await login(tester);
      await montarPerfil(tester);

      final vm = tester.widget<PerfilScreen>(find.byType(PerfilScreen)).vm;
      expect(vm.nome, 'Ana', reason: 'o apelido continua vindo da identidade');
      expect(vm.moldura, 'assets/perfil/vitrine_moldura.webp');
      expect(vm.mascote, '🦊');
      expect(vm.vitrine, isNotEmpty);
      // Sem autoridade de ranking, liga e colocação continuam AUSENTES — o
      // Bronze inventado não pode voltar por esta porta.
      expect(vm.ranking.liga, isNull);
      expect(vm.ranking.posicaoMundial, isNull);
      expect(vm.nivel, isNull);
      expect(vm.stats, isNull);

      await montar(tester, const HomeDeProducao());
      final home = tester.widget<InicioScreen>(find.byType(InicioScreen));
      expect(home.vm.jogador.nome, 'Ana');
      expect(home.vm.jogador.email, '');
      expect(home.vm.jogador.moldura, isNull);
      expect(home.vm.jogador.moedas, isNull);
      expect(home.vm.jogador.liga, isNull);
    });

    test('M23 o convite compartilhado continua funcional e sem o avatar', () {
      // O texto é a superfície que SAI do aparelho. Ele nunca carregou o
      // avatar, e não é esta OS que vai colocá-lo lá.
      expect(
        PerfilPage.textoDeCompartilhamento(null),
        'Vem jogar Buraco comigo no Buraco Master VIP! 👑',
      );
      final vm = PerfilVM.mock().comAvatarPublico(kAvatarValido);
      final texto = PerfilPage.textoDeCompartilhamento(vm);
      expect(texto, contains('Vem jogar Buraco comigo'));
      expect(texto, contains('Sou ${vm.nome}'));
      expect(texto, isNot(contains(kAvatarValido)));
    });

    test('M19 main.dart continua byte a byte o da base', () {
      // Digest da base `d738f458f1f115ab8f47efea7a80bef26675e2ca`, calculado
      // sobre o conteúdo com quebras normalizadas (o checkout no Windows entrega
      // `\r\n` e o do CI entrega `\n`; sem normalizar, o digest provaria o
      // sistema operacional).
      const digestDaBase =
          '8526fc0a1cb487b7ec37a27a6449b09f667c5d412968f69bb547c9f246d5a0ab';
      final atual = sha256
          .convert(utf8.encode(_normalizado(File('lib/main.dart'))))
          .toString();
      expect(
        atual,
        digestDaBase,
        reason:
            'a porta de entrada do aplicativo mudou. Se a mudança for '
            'deliberada e de outra OS, é o digest daqui que se atualiza — de '
            'propósito, e não de passagem',
      );
    });

    test('M22 Mesa Online e Mesa de Treino ficam fora do assunto', () {
      // Nenhuma delas conhece o resolvedor: a correção não pode ter escorrido
      // para o caminho de jogo.
      final mesas = <String>[
        'lib/mesa.dart',
        'lib/screens/mesa_screen.dart',
        'lib/casca/lobby_online.dart',
        'lib/casca/onde_jogar_de_producao.dart',
        ...Directory('lib/casca/mesa_online')
            .listSync(recursive: true)
            .whereType<File>()
            .map((f) => _barras(f.path)),
      ];
      for (final caminho in mesas) {
        final f = File(caminho);
        if (!f.existsSync()) continue;
        final conteudo = _codigo(f);
        expect(
          conteudo,
          isNot(contains('avatar_publico')),
          reason: '$caminho passou a conhecer o resolvedor de avatar',
        );
        expect(
          conteudo,
          isNot(contains('avatarPublico')),
          reason: '$caminho passou a resolver avatar',
        );
      }
    });

    test('M24 as coroas ornamentais continuam onde estavam', () {
      // A busca textual por `👑` acusaria trinta e tantos lugares, e quase todos
      // são legítimos: a marca do aplicativo, o selo de VIP, o convite. Este
      // caso existe para que ninguém "resolva" a OS varrendo o emoji do
      // repositório.
      const ornamentos = <String, String>{
        'lib/screens/inicio_screen.dart': 'a marca, acima do nome do jogo',
        'lib/casca/login_de_producao.dart': 'a marca na tela de entrada',
        'lib/pages/perfil_page.dart': 'o convite copiado',
        'lib/screens/saguao_screen.dart': 'o selo de VIP',
        'lib/widgets/convite_vip.dart': 'a chamada para virar VIP',
        'lib/screens/hall_screen.dart': 'Rei/Rainha da semana',
      };
      ornamentos.forEach((caminho, papel) {
        expect(
          _codigo(File(caminho)),
          contains('👑'),
          reason: 'sumiu a coroa de $caminho ($papel)',
        );
      });
    });
  });

  // =========================================================================
  // AUDITORIA ESTRUTURAL
  // =========================================================================
  group('auditoria estrutural', () {
    late Set<String> alcancaveis;

    setUpAll(() {
      alcancaveis = _alcancaveisDaRaiz();
      expect(alcancaveis, contains('lib/main.dart'));
      expect(alcancaveis.length, greaterThan(5));
    });

    test('M20 o Perfil não abriu consulta nova a publicProfiles', () {
      const doPerfil = [
        'lib/pages/perfil_page.dart',
        'lib/screens/perfil_screen.dart',
        'lib/services/perfil_service.dart',
        'lib/sessao/avatar_publico.dart',
      ];
      const proibidos = [
        'publicProfiles',
        'cloud_firestore',
        'FirebaseFirestore',
        'httpsCallable',
        'cloud_functions',
        'StreamBuilder',
        '.listen(',
        'obterMinhaIdentidade',
        'recarregar()',
      ];
      // A ÚNICA EXCEÇÃO, e ela é nominal de propósito.
      //
      // `recarregar()` entrou na lista como procuração para "o Perfil foi
      // buscar identidade de novo". Depois que o Ranking Real passou a viver
      // nesta tela, existe um `recarregar()` que NÃO é isso: o botão de tentar
      // de novo pede à autoridade de RANKING que refaça a consulta dela. É
      // ação do jogador sobre outro dado, e recusá-la deixaria o retry pela
      // metade — o Perfil recarregaria e a liga continuaria falhada.
      //
      // A exceção é o texto exato da chamada, e não o termo solto: qualquer
      // outro `recarregar()` nestes quatro arquivos continua reprovando, e a
      // asserção seguinte prova que esta é a única que existe. O que a
      // auditoria protege — identidade pública tem um dono só — segue intacto,
      // porque `EscopoRanking` não é dono de identidade nenhuma.
      const excecaoRanking = 'EscopoRanking.talvezDe(context)?.recarregar()';
      final achados = <String>[];
      for (final caminho in doPerfil) {
        final conteudo = _codigo(File(caminho)).replaceAll(excecaoRanking, '');
        for (final termo in proibidos) {
          if (conteudo.contains(termo)) achados.add('$caminho: $termo');
        }
      }
      expect(
        achados,
        isEmpty,
        reason:
            'o Perfil consome o estado que a sessão já carregou; buscar de '
            'novo faria dele um segundo dono da identidade pública',
      );

      // E a exceção não é um buraco: ela vale UMA vez, num arquivo só.
      //
      // Sem esta contagem, a linha acima viraria autorização para espalhar
      // `recarregar()` pelo Perfil — bastaria escrevê-lo na forma isenta. Aqui
      // se prova que existe exatamente uma chamada, que ela está na página (e
      // não na tela, no serviço ou no resolvedor) e que os outros três arquivos
      // não têm nenhuma.
      final naPagina = _codigo(File('lib/pages/perfil_page.dart'));
      expect(
        excecaoRanking.allMatches(naPagina).length,
        1,
        reason:
            'o retry do Ranking é uma chamada só; mais de uma é o Perfil '
            'assumindo o comando de uma autoridade que não é dele',
      );
      for (final caminho in doPerfil.where(
        (c) => c != 'lib/pages/perfil_page.dart',
      )) {
        expect(
          _codigo(File(caminho)),
          isNot(contains('recarregar()')),
          reason: '$caminho não recarrega nada — quem o faz é a página',
        );
      }
    });

    test('a autoridade do avatar é UMA, e mora no resolvedor', () {
      // Nenhum consumidor pode decidir por conta própria o que fazer com um
      // `avatarRef`: quem lê o campo tem de chamar o resolvedor.
      //
      // ---------------------------------------------------------------------
      // POR QUE A REGRA DEIXOU DE SER "NINGUÉM MAIS PODE NOMEAR O CAMPO"
      // ---------------------------------------------------------------------
      //
      // Ela era `infratores, isEmpty` com uma exceção escrita à mão para o
      // portador. Funcionava enquanto havia UM portador e um consumidor que,
      // por acaso, não precisava nomear o campo — a Home chama
      // `avatarPublicoDaIdentidade(identidade)` e nunca escreve `avatarRef`.
      //
      // A descoberta social trouxe um segundo portador (`JogadorPublico`, que
      // declara `avatarRef` do mesmo jeito que a identidade da sessão) e um
      // consumidor que PRECISA nomear o campo, porque o valor lhe chega solto:
      // `avatarPublicoDe(jogador.avatarRef)`. Sob a regra antiga, esse
      // consumidor — que faz exatamente o certo — seria reprovado, e o jeito
      // de "consertar" seria esconder o nome do campo atrás de um atalho no
      // portador. Isso é o oposto do que a auditoria quer: seria uma segunda
      // regra de avatar, escrita onde ninguém procuraria.
      //
      // A regra agora diz o que sempre quis dizer: LEU, CHAMOU O RESOLVEDOR.
      // Ela continua reprovando o defeito de verdade (alguém escrever
      // `avatarRef ?? '👑'`), e o teste seguinte — o do literal único — fecha o
      // cerco pelo outro lado.
      const portadores = [
        // Declaram o campo e não desenham nada com ele.
        'lib/sessao/identidade_publica_sessao.dart',
        'lib/amigos/estado_social.dart',
      ];
      final infratores = <String>[];
      for (final caminho in alcancaveis) {
        if (caminho == 'lib/sessao/avatar_publico.dart') continue;
        if (portadores.contains(caminho)) continue;
        final f = File(caminho);
        if (!f.existsSync()) continue;
        final conteudo = _codigo(f);
        if (!conteudo.contains('avatarRef')) continue;
        if (conteudo.contains('avatarPublicoDe(')) continue;
        infratores.add(caminho);
      }
      expect(
        infratores,
        isEmpty,
        reason:
            'quem lê avatarRef fora do resolvedor está escrevendo a segunda '
            'regra: $infratores',
      );

      // E os portadores continuam sendo portadores: nenhum dos dois desenha.
      for (final caminho in portadores) {
        final conteudo = _codigo(File(caminho));
        expect(
          conteudo,
          isNot(contains(kAvatarPublicoFallback)),
          reason: '$caminho passou a decidir o que desenhar',
        );
      }
    });

    test('o fallback é literal em um lugar só do fecho alcançável', () {
      // A coroa continua espalhada pelo repositório como ornamento; o que não
      // pode existir é um SEGUNDO lugar que a use como avatar. A prova é por
      // vizinhança: `avatar` e `👑` na mesma linha de código.
      final suspeitos = <String>[];
      for (final caminho in alcancaveis) {
        if (caminho == 'lib/sessao/avatar_publico.dart') continue;
        final f = File(caminho);
        if (!f.existsSync()) continue;
        for (final linha in _semMaquetes(_codigo(f)).split('\n')) {
          final l = linha.toLowerCase();
          if (l.contains('avatar') && linha.contains('👑')) {
            suspeitos.add('$caminho: ${linha.trim()}');
          }
        }
      }
      expect(
        suspeitos,
        isEmpty,
        reason: 'voltou a existir uma coroa escrita como avatar: $suspeitos',
      );
    });

    test('M21 nenhum literal Bronze reaparece no fecho alcançável', () {
      final achados = <String>[];
      for (final caminho in alcancaveis) {
        final f = File(caminho);
        if (!f.existsSync()) continue;
        if (_codigo(f).contains('Bronze')) achados.add(caminho);
      }
      expect(achados, isEmpty);
    });

    test('M21b e nenhuma liga é AFIRMADA pelo caminho publicável', () {
      // A prova textual acima não basta, e a homologação anterior mostrou por
      // quê: `EstadoRanking.disponivel(liga: 'Bronze')` some de uma varredura
      // por `?? 'Bronze'`. O que fecha o buraco é o comportamento do produtor.
      expect(PerfilService.statsDemo, isFalse);
      expect(const PerfilService().vmPlaceholder().ranking.liga, isNull);
    });

    test('o fecho cresceu só pelo componente previsto', () {
      // O único arquivo novo alcançável é o resolvedor.
      expect(alcancaveis, contains('lib/sessao/avatar_publico.dart'));

      // 40 → 45 NA COMPOSIÇÃO COM O RANKING REAL V2, e os cinco têm nome.
      //
      // O 40 media uma árvore que não tinha Ranking: era o fecho de então mais
      // o resolvedor. Compondo as duas linhagens, entra junto o componente de
      // Ranking — e o número tinha de acompanhar, porque ele é um alarme de
      // crescimento INESPERADO, não uma constante do produto.
      //
      // Trocar o número sozinho seria trocar um alarme por outro sem prova. Por
      // isso os cinco arquivos estão listados abaixo: se amanhã o fecho crescer
      // de novo, não basta ajustar o total — o que entrou tem de ser nomeado
      // aqui, ou a lista denuncia. O alarme continua exato: qualquer arquivo
      // fora do previsto quebra o teste do mesmo jeito que quebrava antes.
      const doRankingReal = [
        'lib/ranking/escopo_ranking.dart',
        'lib/ranking/leitor_ranking.dart',
        'lib/ranking/ranking_da_sessao.dart',
        'lib/ranking/ranking_transporte.dart',
        'lib/ranking/ranking_transporte_firebase.dart',
      ];
      for (final caminho in doRankingReal) {
        expect(
          alcancaveis,
          contains(caminho),
          reason:
              '$caminho saiu do fecho — o Ranking Real deixou de ser '
              'alcançável a partir da raiz',
        );
      }

      // 45 → 48 AO ENTRAR A NAVEGAÇÃO AO PERFIL PÚBLICO, e os três também têm
      // nome. Mesma disciplina da rodada anterior, pelo mesmo motivo: o total é
      // alarme de crescimento inesperado, e crescimento PREVISTO se declara.
      //
      // Estes três são o que a tabela de Ranking passou a precisar para existir
      // como tela produtiva: o estado da tabela, a tela em si, e o único ponto
      // do aplicativo autorizado a decidir de quem é o Perfil que abre.
      const daNavegacaoPublica = [
        'lib/ranking/estado_tabela_ranking.dart',
        'lib/casca/ranking_de_producao.dart',
        'lib/casca/navegacao_perfil_publico.dart',
      ];
      for (final caminho in daNavegacaoPublica) {
        expect(
          alcancaveis,
          contains(caminho),
          reason:
              '$caminho saiu do fecho — a navegação ao Perfil público '
              'deixou de ser alcançável a partir da raiz',
        );
      }

      // 48 → 55 AO ENTRAR A DESCOBERTA SOCIAL, e os sete também têm nome.
      //
      // Cinco são o módulo do grafo social (o estado canônico, a porta, o
      // adaptador de Firebase, o leitor e o escopo — a mesma divisão que o
      // Ranking Real já tinha); o sexto é o dicionário de rótulos, que existe
      // para que a tela de Amigos e a faixa do Perfil visitado não chamem a
      // mesma relação por nomes diferentes; e o sétimo é a tela produtiva de
      // Amigos. A maquete `lib/screens/amigos_screen.dart` continua FORA do
      // fecho, e é isso que C16 e N12 provam.
      const daDescobertaSocial = [
        'lib/amigos/estado_social.dart',
        'lib/amigos/transporte_social.dart',
        'lib/amigos/transporte_social_firebase.dart',
        'lib/amigos/leitor_social.dart',
        'lib/amigos/escopo_social.dart',
        'lib/amigos/rotulos_sociais.dart',
        'lib/casca/amigos_de_producao.dart',
      ];
      for (final caminho in daDescobertaSocial) {
        expect(
          alcancaveis,
          contains(caminho),
          reason:
              '$caminho saiu do fecho — a descoberta social deixou de ser '
              'alcançável a partir da raiz',
        );
      }
      expect(
        alcancaveis,
        isNot(contains('lib/screens/amigos_screen.dart')),
        reason: 'a maquete de Amigos entrou no fecho de produção',
      );

      // 55 → 56 AO ENTRAR O PISO DE ÁREA TOCÁVEL, e o arquivo também tem nome.
      //
      // Mesma disciplina das três rodadas acima. Este é o único componente
      // novo da correção de acessibilidade dos botões: um número — 48 — e uma
      // caixa que o aplica. Ele é alcançável porque as três telas o usam, e
      // não arrasta nada: importa só o widgets.dart do Flutter, e é
      // incapaz de decidir navegação ou disponibilidade (não recebe callback).
      const doPisoDeToque = ['lib/widgets/alvo_minimo.dart'];
      for (final caminho in doPisoDeToque) {
        expect(
          alcancaveis,
          contains(caminho),
          reason:
              '$caminho saiu do fecho — o piso de área tocável deixou de ser '
              'alcançável a partir da raiz',
        );
      }

      expect(
        alcancaveis,
        hasLength(
          40 +
              doRankingReal.length +
              daNavegacaoPublica.length +
              daDescobertaSocial.length +
              doPisoDeToque.length,
        ),
      );
      // E ele não arrastou nada: importa só o estado canônico, que já estava lá.
      final resolvedor = _codigo(File('lib/sessao/avatar_publico.dart'));
      final importados = _reImport
          .allMatches(resolvedor)
          .map((m) => m.group(1)!)
          .toList();
      expect(importados, ['identidade_publica_sessao.dart']);
    });

    test('nada do que a OS proíbe entrou no fecho', () {
      expect(
        alcancaveis,
        isNot(contains('lib/screens/ranking_screen.dart')),
        reason: 'a prévia do Ranking continua inalcançável',
      );
      // O caminho online não pode ter adquirido o motor local.
      final online = alcancaveis.where(
        (c) => c.contains('/casca/mesa_online/') || c.contains('lobby_online'),
      );
      for (final caminho in online) {
        final f = File(caminho);
        if (!f.existsSync()) continue;
        expect(
          _codigo(f),
          isNot(contains("import '../../mesa.dart'")),
          reason: '$caminho passou a construir a mesa local',
        );
      }
    });

    test('M18 authStateChanges continua com um assinante só', () {
      final assinantes = <String>[];
      for (final f
          in Directory('lib')
              .listSync(recursive: true)
              .whereType<File>()
              .where((f) => f.path.endsWith('.dart'))) {
        final n = _barras(f.path);
        if (n.contains('/social/') || n.contains('/moderacao/')) continue;
        if (n.endsWith('js_bridge.dart')) continue;
        if (_codigo(f).contains('authStateChanges')) assinantes.add(n);
      }
      expect(assinantes, hasLength(1));
      expect(assinantes.single, endsWith('lib/sessao/sessao_firebase.dart'));
    });

    test('o resolvedor não conhece Flutter, Firebase nem armazenamento', () {
      final conteudo = _codigo(File('lib/sessao/avatar_publico.dart'));
      for (final termo in [
        'package:flutter',
        'BuildContext',
        'Widget',
        'firebase',
        'Firebase',
        'SharedPreferences',
        'File(',
        'http',
      ]) {
        expect(
          conteudo,
          isNot(contains(termo)),
          reason: 'o resolvedor virou outra coisa: encontrou "$termo"',
        );
      }
    });
  });
}
