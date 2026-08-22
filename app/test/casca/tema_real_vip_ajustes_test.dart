// tema_real_vip_ajustes_test.dart — a suíte do Tema Real VIP da tela de Ajustes.
//
// SEIS GRUPOS, e cada um responde a uma pergunta diferente:
//
//   ELG  quem tem direito ao tema, e quem não tem;
//   AST  os dois conjuntos estão inteiros, e não há mistura nem carga externa;
//   EST  trocar de tema não mexe em preferência, em comando nem em sessão;
//   DAD  o que a tela mostra vem da autoridade, e não de maquete;
//   A11Y o tema não muda nome acessível, alvo de toque nem ordem de leitura;
//   NRG  as autoridades vizinhas continuaram fora do alcance desta OS.
//
// A ARMADILHA CENTRAL DESTA SUÍTE, e ela custou uma rodada: um teste que
// afirmasse "o assinante recebe ícones luxuosos" sem varrer a tela INTEIRA
// passaria com metade da tela dourada. Por isso as varreduras devolvem os dois
// conjuntos rendidos (assets e glifos) e as provas comparam CONJUNTOS, nunca
// ocorrências. `_exigirPiso` confere, na primeira linha de cada varredura, que a
// tela realmente montou — varredura de árvore vazia passa em tudo.
library;

import 'dart:io';

import 'package:buraco_master_vip/billing/acesso_vip.dart';
import 'package:buraco_master_vip/elegibilidade/entitlement.dart';
import 'package:buraco_master_vip/screens/configuracoes_screen.dart';
import 'package:buraco_master_vip/tema/conjunto_real_vip.dart';
import 'package:buraco_master_vip/tema/iconografia_ajustes.dart';
import 'package:buraco_master_vip/tema/resolucao_tema_ajustes.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Apoio
// ---------------------------------------------------------------------------

/// Superfície de telefone alta o bastante para a tela inteira existir.
///
/// Nó fora da viewport NÃO EXISTE para a árvore semântica nem para o `finder`.
/// Medir em 360x800 constrói metade da tela e dá verde sem significado.
void _superficieDeVarredura(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 12000);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

/// PNG 1x1 transparente. Serve para o Tema Real ter arquivo de verdade para
/// abrir e decodificar sem que nenhum desenho precise existir no repositório.
final Uint8List _pngTransparente = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
  0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
  0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
  0x42, 0x60, 0x82,
]);

/// Bundle que serve exatamente as chaves que lhe forem dadas, e nada mais.
class _BundleFalso extends CachingAssetBundle {
  _BundleFalso(this.chaves);

  final Set<String> chaves;

  @override
  Future<ByteData> load(String key) async {
    if (!chaves.contains(key)) {
      throw FlutterError('asset ausente na bancada: $key');
    }
    return ByteData.view(_pngTransparente.buffer);
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) async =>
      throw FlutterError('esta bancada só serve bytes');
}

/// Monta um retrato REAL, pelo portão, a partir de um documento e de um relógio.
Future<AcessoVip> _comPortao({
  EntitlementVip? documento,
  Object? falha,
  String? uid = 'uid-1',
  DateTime? agora,
}) async {
  final portao = PortaoVip(
    fonte: (_) {
      if (falha != null) return Stream<EntitlementVip>.error(falha);
      if (documento == null) return const Stream<EntitlementVip>.empty();
      return Stream<EntitlementVip>.value(documento);
    },
    relogio: () => agora ?? DateTime.utc(2026, 8, 22, 12),
  );
  addTearDown(portao.encerrar);
  portao.usarSessao(uid);
  await Future<void>.delayed(Duration.zero);
  return portao.atual;
}

EntitlementVip _direito(
  EstadoEntitlement estado, {
  bool ativo = true,
  DateTime? expira,
  String? produto = 'master_vip_mensal',
  bool renova = true,
}) =>
    EntitlementVip(
      uid: 'uid-1',
      vipAtivo: ativo,
      estado: estado,
      produtoId: produto,
      expiraEm: expira ?? DateTime.utc(2026, 9, 22),
      renovacaoAutomatica: renova,
    );

/// O que a tela REALMENTE desenhou, por família.
class _Varredura {
  _Varredura(this.assets, this.glifos);

  final Set<String> assets;
  final Set<IconData> glifos;
}

_Varredura _varrer(WidgetTester tester) {
  final assets = <String>{};
  for (final img in tester.widgetList<Image>(find.byType(Image))) {
    final provedor = img.image;
    if (provedor is AssetImage) assets.add(provedor.assetName);
    if (provedor is ExactAssetImage) assets.add(provedor.assetName);
  }
  final glifos = <IconData>{};
  for (final icone in tester.widgetList<Icon>(find.byType(Icon))) {
    final dados = icone.icon;
    if (dados != null) glifos.add(dados);
  }
  // PISO: a tela montou mesmo? Uma árvore vazia satisfaz qualquer asserção de
  // "não contém", e é assim que uma varredura universal passa provando nada.
  final total = assets.length + glifos.length;
  expect(
    total,
    greaterThanOrEqualTo(20),
    reason: 'a tela não montou: só $total ícones na árvore',
  );
  return _Varredura(assets, glifos);
}

Set<IconData> _glifosVariaveis() => {
      for (final chave in IconeAjustes.variaveis)
        (conjuntoPadraoDeAjustes[chave] as IconeMaterial).dados,
    };

Set<IconData> _glifosInvariantes() => {
      for (final chave in IconeAjustes.invariantes)
        (conjuntoPadraoDeAjustes[chave] as IconeMaterial).dados,
    };

const PerfilResumo _perfilPublico = PerfilResumo(
  apelido: 'Jogadora',
  email: '',
  vip: false,
  fichas: null,
);

Widget _telaCom({
  required ConjuntoDeIcones icones,
  PerfilResumo perfil = _perfilPublico,
  Configuracoes config = const Configuracoes(versaoApp: '9.9.9'),
  void Function(Configuracoes)? onAlterar,
  List<String>? toques,
  AssetBundle? bundle,
}) {
  void registra(String nome) => toques?.add(nome);
  final tela = ConfiguracoesScreen(
    icones: icones,
    perfil: perfil,
    config: config,
    onVoltar: () => registra('voltar'),
    callbacks: ConfiguracoesCallbacks(
      onAlterar: onAlterar ?? (_) => registra('alterar'),
      onEditarPerfil: () => registra('editarPerfil'),
      onAssinaturaVip: () => registra('assinaturaVip'),
      onFichasECompras: () => registra('fichasECompras'),
      onBloqueados: () => registra('bloqueados'),
      onRegras: () => registra('regras'),
      onSuporte: () => registra('suporte'),
      onTermos: () => registra('termos'),
      onAvaliar: () => registra('avaliar'),
      onSair: () => registra('sair'),
      onExcluirConta: () => registra('excluirConta'),
    ),
  );
  final corpo = MaterialApp(home: tela);
  return bundle == null
      ? corpo
      : DefaultAssetBundle(bundle: bundle, child: corpo);
}

/// Assenta a arvore sem `pumpAndSettle`.
///
/// `pumpAndSettle` espera a AUSENCIA de frame agendado, e nesta tela ele nao
/// chega: basta uma animacao que se reagende para ele girar ate o timeout de
/// dez minutos e reprovar por tempo, nao por defeito. Dois quadros com duracao
/// bastam para tudo que estas provas medem.
Future<void> _assentar(WidgetTester t) async {
  await t.pump();
  await t.pump(const Duration(milliseconds: 400));
}

String _fonte(String caminho) => File(caminho).readAsStringSync();

/// Lê um arquivo da raiz do repositório a partir da pasta `app/`.
String _daRaiz(String relativo) => _fonte('../$relativo');

void main() {
  // -------------------------------------------------------------------------
  group('ELG — quem tem direito ao Tema Real', () {
    test('ELG-01 jogador público fica no Tema Padrão', () async {
      final acesso = await _comPortao(documento: null, uid: null);
      final r = await resolverTemaDeAjustes(
        acesso: acesso,
        registrado: true,
        verificarConjunto: () async => true,
      );
      expect(r.estado, EstadoTemaVip.publico);
      expect(r.tema, TemaIconografia.padrao);
      expect(r.motivo, MotivoDoTema.semDireitoVigente);
      expect(r.icones, same(conjuntoPadraoDeAjustes));
    });

    test('ELG-02 assinante VIP ativo recebe o Tema Real', () async {
      final acesso = await _comPortao(
        documento: _direito(EstadoEntitlement.ativo),
      );
      final r = await resolverTemaDeAjustes(
        acesso: acesso,
        registrado: true,
        verificarConjunto: () async => true,
      );
      expect(r.estado, EstadoTemaVip.vipCompletoAtivo);
      expect(r.tema, TemaIconografia.realVip);
      expect(r.motivo, MotivoDoTema.concedido);
    });

    test('ELG-03 carência com benefício preservado segue a autoridade',
        () async {
      for (final estado in [
        EstadoEntitlement.emCarencia,
        EstadoEntitlement.canceladoVigente,
      ]) {
        final acesso = await _comPortao(documento: _direito(estado));
        final r = await resolverTemaDeAjustes(
          acesso: acesso,
          registrado: true,
          verificarConjunto: () async => true,
        );
        expect(r.estado, EstadoTemaVip.vipCompletoEmCarenciaComBeneficio,
            reason: estado.wire);
        expect(r.tema, TemaIconografia.realVip, reason: estado.wire);
      }
    });

    test('ELG-04 VIP expirado volta INTEGRALMENTE ao padrão', () async {
      // Documento ainda diz `vipAtivo`, e o prazo já passou. É o caso que o
      // booleano gravado erraria: quem confia no campo continua VIP para sempre.
      final acesso = await _comPortao(
        documento: _direito(
          EstadoEntitlement.ativo,
          expira: DateTime.utc(2026, 8, 1),
        ),
      );
      final r = await resolverTemaDeAjustes(
        acesso: acesso,
        registrado: true,
        verificarConjunto: () async => true,
      );
      expect(r.estado, EstadoTemaVip.vipCompletoExpirado);
      expect(r.tema, TemaIconografia.padrao);
      expect(r.icones, same(conjuntoPadraoDeAjustes));
    });

    test('ELG-05 o passe quinzenal de cortesia NÃO libera o Tema Real', () {
      // Prova ESTRUTURAL, e é a única honesta: o passe mora em
      // `playerCourtesyPass/{uid}`, e nenhuma peça do caminho do tema sabe ler
      // essa coleção. Um teste de comportamento não conseguiria falhar aqui,
      // porque não há entrada por onde o passe chegue.
      final caminhos = [
        'lib/tema/resolucao_tema_ajustes.dart',
        'lib/tema/conjunto_real_vip.dart',
        'lib/tema/iconografia_ajustes.dart',
        'lib/billing/acesso_vip.dart',
        'lib/billing/entitlement_repositorio.dart',
        'lib/casca/configuracoes_de_producao.dart',
      ];
      for (final caminho in caminhos) {
        final texto = _semComentarios(_fonte(caminho));
        expect(texto.contains('playerCourtesyPass'), isFalse,
            reason: '$caminho lê a coleção do passe de cortesia');
        expect(texto.contains('courtesyPass'), isFalse, reason: caminho);
        expect(RegExp(r'\bpasse\b').hasMatch(texto.toLowerCase()) &&
            texto.contains('materializar'), isFalse,
            reason: '$caminho materializa passe');
      }
      // E o backend do passe continua sem tocar a autoridade da assinatura.
      final passe =
          _semComentarios(_daRaiz('functions-ranking/src/passe.ts'));
      expect(passe.contains('playerEntitlements'), isFalse,
          reason: 'o passe passou a escrever na coleção da assinatura');
    });

    test('ELG-06 código de sala não entra na decisão de tema', () {
      final resolucao = _fonte('lib/tema/resolucao_tema_ajustes.dart');
      for (final proibido in [
        'codigo',
        'sala',
        'mesa',
        'amigo',
        'inventario',
        'equipad',
      ]) {
        expect(
          RegExp('$proibido', caseSensitive: false)
              .hasMatch(_semComentarios(resolucao)),
          isFalse,
          reason: 'a decisão de tema passou a olhar "$proibido"',
        );
      }
    });

    test('ELG-07 estado desconhecido usa o Tema Padrão', () async {
      final falha = await _comPortao(falha: StateError('sem rede'));
      final rFalha = await resolverTemaDeAjustes(
        acesso: falha,
        registrado: true,
        verificarConjunto: () async => true,
      );
      expect(rFalha.estado, EstadoTemaVip.desconhecido);
      expect(rFalha.tema, TemaIconografia.padrao);
      expect(rFalha.motivo, MotivoDoTema.autoridadeIndefinida);

      // Estado que a plataforma passou a devolver e este cliente não conhece:
      // é DÚVIDA, e não "não assina".
      final novo = await _comPortao(
        documento: _direito(EstadoEntitlement.desconhecido, ativo: false),
      );
      final rNovo = await resolverTemaDeAjustes(
        acesso: novo,
        registrado: true,
        verificarConjunto: () async => true,
      );
      expect(rNovo.estado, EstadoTemaVip.desconhecido);
      expect(rNovo.tema, TemaIconografia.padrao);
    });

    test('ELG-08 só o benefício completo AUTORITATIVO libera', () async {
      // Presente, cortesia ou qualquer origem futura só valem quando viram
      // documento vigente. `origem` não participa da decisão — o que decide é
      // `vigenteEm`, e por isso um direito administrativo em dia libera e um
      // vencido não.
      final presente = _direito(
        EstadoEntitlement.ativo,
        produto: null,
      );
      final acesso = await _comPortao(documento: presente);
      final r = await resolverTemaDeAjustes(
        acesso: acesso,
        registrado: true,
        verificarConjunto: () async => true,
      );
      expect(r.tema, TemaIconografia.realVip);

      final semPrazo = EntitlementVip(
        uid: 'uid-1',
        vipAtivo: true,
        estado: EstadoEntitlement.ativo,
      );
      final semPrazoAcesso = await _comPortao(documento: semPrazo);
      final r2 = await resolverTemaDeAjustes(
        acesso: semPrazoAcesso,
        registrado: true,
        verificarConjunto: () async => true,
      );
      expect(r2.tema, TemaIconografia.padrao,
          reason: 'direito sem prazo não concede');
    });
  });

  // -------------------------------------------------------------------------
  group('AST — os conjuntos, e a proibição de mistura', () {
    test('AST-09 o conjunto padrão está completo e é todo de glifo', () {
      for (final chave in IconeAjustes.values) {
        expect(conjuntoPadraoDeAjustes[chave], isA<IconeMaterial>(),
            reason: chave.name);
      }
      expect(conjuntoPadraoDeAjustes.assetsUsados, isEmpty);
    });

    test('AST-10 o conjunto real está completo e cobre todas as variáveis', () {
      for (final chave in IconeAjustes.values) {
        final fonte = conjuntoRealVipDeAjustes[chave];
        if (chave.ehVariavel) {
          expect(fonte, isA<IconeDeAsset>(), reason: chave.name);
        } else {
          expect(fonte, conjuntoPadraoDeAjustes[chave], reason: chave.name);
        }
      }
      expect(
        arquivosDoTemaReal.keys.toSet(),
        IconeAjustes.variaveis,
        reason: 'o manifesto e as chaves variáveis divergiram',
      );
      expect(chavesDeAssetDoTemaReal.toSet().length,
          IconeAjustes.variaveis.length,
          reason: 'dois ícones apontam para o mesmo arquivo');
    });

    test('AST-11 um único asset ausente derruba o conjunto INTEIRO', () async {
      final completo = _BundleFalso(chavesDeAssetDoTemaReal.toSet());
      expect(
        await conjuntoRealDisponivel(bundle: completo, registrado: true),
        isTrue,
      );

      for (final faltando in chavesDeAssetDoTemaReal) {
        final parcial = _BundleFalso(
          chavesDeAssetDoTemaReal.where((c) => c != faltando).toSet(),
        );
        expect(
          await conjuntoRealDisponivel(bundle: parcial, registrado: true),
          isFalse,
          reason: 'faltando $faltando e o conjunto ainda se disse completo',
        );
      }
    });

    test('AST-12 nenhum ícone é carregado de fora do aplicativo', () {
      for (final chave in chavesDeAssetDoTemaReal) {
        expect(chave.startsWith(kPrefixoAssetsReais), isTrue);
        expect(chave.contains('://'), isFalse);
      }
      // A proibição é ESTRUTURAL: não existe variante de [FonteDeIcone] que
      // carregue por rede. Acrescentar uma reprova aqui.
      final contrato = _semComentarios(_fonte('lib/tema/iconografia_ajustes.dart'));
      for (final proibido in [
        'http',
        'NetworkImage',
        'Uri.parse',
        'HttpClient',
      ]) {
        expect(contrato.contains(proibido), isFalse, reason: proibido);
      }
      expect(RegExp(r'final class \w+ extends FonteDeIcone')
          .allMatches(contrato).length, 2,
          reason: 'apareceu uma terceira forma de servir ícone');
    });

    test('AST-13 todo arquivo exigido tem chave, nome estável e origem', () {
      expect(arquivosExigidos.length, IconeAjustes.variaveis.length);
      for (final caminho in arquivosExigidos) {
        expect(caminho.startsWith('app/assets/ajustes/real/'), isTrue);
        expect(RegExp(r'^[a-z0-9_/.]+\.webp$')
            .hasMatch(caminho.split('assets/').last), isTrue,
            reason: 'nome instável: $caminho');
      }
      // O documento de origem existe e lista TODOS os arquivos exigidos.
      final origem = _daRaiz('docs/ORIGEM-ICONES-TEMA-REAL.md');
      for (final caminho in arquivosExigidos) {
        expect(origem.contains(caminho.split('/').last), isTrue,
            reason: 'sem linha de origem: $caminho');
      }
    });

    testWidgets('AST-14 a tela nunca mistura os dois conjuntos', (t) async {
      _superficieDeVarredura(t);

      await t.pumpWidget(_telaCom(icones: conjuntoPadraoDeAjustes));
      await _assentar(t);
      final padrao = _varrer(t);
      expect(padrao.assets, isEmpty,
          reason: 'o Tema Padrão desenhou arquivo de tema luxuoso');
      expect(padrao.glifos.difference(_glifosVariaveis()
          .union(_glifosInvariantes())), isEmpty,
          reason: 'glifo fora do contrato: ${padrao.glifos}');

      final bundle = _BundleFalso(chavesDeAssetDoTemaReal.toSet());
      await t.pumpWidget(
        _telaCom(icones: conjuntoRealVipDeAjustes, bundle: bundle),
      );
      await _assentar(t);
      final real = _varrer(t);
      expect(real.assets, isNotEmpty);
      expect(real.assets.difference(chavesDeAssetDoTemaReal.toSet()), isEmpty);
      // O ponto da prova: NENHUM glifo de chave variável sobrou na tela real.
      expect(real.glifos.intersection(_glifosVariaveis()), isEmpty,
          reason: 'metade da tela ficou padrão: ${real.glifos}');
      expect(real.glifos.difference(_glifosInvariantes()), isEmpty);
    });
  });

  // -------------------------------------------------------------------------
  group('EST — o tema não mexe em estado', () {
    testWidgets('EST-15 trocar de tema não altera nenhuma preferência',
        (t) async {
      _superficieDeVarredura(t);
      const config = Configuracoes(
        musica: false,
        vibracao: true,
        maoDominante: MaoDominante.canhoto,
        quemMeConvida: QuemMeConvida.somenteAmigos,
        mostrarOnline: false,
        versaoApp: '9.9.9',
      );
      final alteracoes = <Configuracoes>[];
      final bundle = _BundleFalso(chavesDeAssetDoTemaReal.toSet());

      await t.pumpWidget(_telaCom(
        icones: conjuntoPadraoDeAjustes,
        config: config,
        onAlterar: alteracoes.add,
      ));
      await _assentar(t);
      final antes = _textosDe(t);

      await t.pumpWidget(_telaCom(
        icones: conjuntoRealVipDeAjustes,
        config: config,
        onAlterar: alteracoes.add,
        bundle: bundle,
      ));
      await _assentar(t);

      expect(alteracoes, isEmpty, reason: 'a troca de tema persistiu valor');
      expect(_textosDe(t), antes, reason: 'a troca de tema mudou texto');
      expect(_estadosDosSwitches(t).length, 9);
    });

    testWidgets('EST-16 a expiração não mexe nos interruptores', (t) async {
      _superficieDeVarredura(t);
      const config = Configuracoes(
        musica: false,
        efeitosSonoros: false,
        vibracao: true,
        versaoApp: '9.9.9',
      );
      final alteracoes = <Configuracoes>[];
      final bundle = _BundleFalso(chavesDeAssetDoTemaReal.toSet());

      await t.pumpWidget(_telaCom(
        icones: conjuntoRealVipDeAjustes,
        config: config,
        onAlterar: alteracoes.add,
        perfil: const PerfilResumo(
          apelido: 'Jogadora',
          email: '',
          vip: true,
          fichas: null,
        ),
        bundle: bundle,
      ));
      await _assentar(t);
      final antes = _estadosDosSwitches(t);

      // Direito venceu: volta ao padrão, e o resto da tela não muda.
      await t.pumpWidget(_telaCom(
        icones: conjuntoPadraoDeAjustes,
        config: config,
        onAlterar: alteracoes.add,
      ));
      await _assentar(t);

      expect(_estadosDosSwitches(t), antes);
      expect(alteracoes, isEmpty);
    });

    testWidgets('EST-17 reconstruir não dispara comando nenhum', (t) async {
      _superficieDeVarredura(t);
      final toques = <String>[];
      for (var i = 0; i < 3; i++) {
        await t.pumpWidget(_telaCom(
          icones: conjuntoPadraoDeAjustes,
          toques: toques,
        ));
        await _assentar(t);
      }
      expect(toques, isEmpty);
    });

    test('EST-18 o logout não deixa tema aceso para o próximo', () {
      final host = _fonte('lib/casca/configuracoes_de_producao.dart');
      final semComentario = _semComentarios(host);
      expect(semComentario.contains('_portao.encerrar()'), isTrue,
          reason: 'o portão VIP não é encerrado no dispose');
      expect(semComentario.contains('_escutaVip?.cancel()'), isTrue,
          reason: 'a escuta do direito não é cancelada');
      expect(semComentario.contains('_portao.usarSessao(uid)'), isTrue,
          reason: 'o portão não é reancorado na troca de sessão');
    });

    test('EST-19 trocar de conta zera a resolução ANTES de consultar', () {
      final host = _semComentarios(
        _fonte('lib/casca/configuracoes_de_producao.dart'),
      );
      final i = host.indexOf('_uid = uid;');
      final zera = host.indexOf('TemaIconografia.padrao', i);
      final consulta = host.indexOf('_portao.usarSessao(uid)', i);
      expect(i, greaterThan(0));
      expect(zera, greaterThan(i));
      expect(consulta, greaterThan(zera),
          reason: 'a conta nova é consultada antes de o tema da anterior sair');
    });

    testWidgets('EST-20 arquivo que falha não bloqueia a tela', (t) async {
      _superficieDeVarredura(t);
      // Bundle vazio: TODO arquivo do tema real falha ao abrir. A tela ainda
      // monta, ainda responde ao toque e não sobe exceção.
      final toques = <String>[];
      await t.pumpWidget(_telaCom(
        icones: conjuntoRealVipDeAjustes,
        bundle: _BundleFalso(const {}),
        toques: toques,
      ));
      await _assentar(t);

      expect(t.takeException(), isNull);
      expect(find.text('Sair da conta'), findsOneWidget);
      await t.tap(find.text('Editar perfil'));
      await _assentar(t);
      expect(toques, ['editarPerfil']);
    });
  });

  // -------------------------------------------------------------------------
  group('DAD — o que a tela mostra vem da autoridade', () {
    testWidgets('DAD-21 apelido e avatar vêm da sessão canônica', (t) async {
      _superficieDeVarredura(t);
      await t.pumpWidget(_telaCom(
        icones: conjuntoPadraoDeAjustes,
        perfil: const PerfilResumo(
          apelido: 'Aurora',
          email: 'aurora@exemplo.com',
          avatar: '🦉',
          vip: false,
          fichas: null,
        ),
      ));
      await _assentar(t);
      expect(find.text('Aurora'), findsOneWidget);
      expect(find.text('🦉'), findsOneWidget);
      expect(find.text('aurora@exemplo.com'), findsOneWidget);
      // Nada da maquete chegou.
      expect(find.text('Sônia Rainha'), findsNothing);

      // E o host lê a sessão, não o provedor de autenticação, para a identidade.
      final host = _semComentarios(
        _fonte('lib/casca/configuracoes_de_producao.dart'),
      );
      expect(host.contains('identidade?.avatarRef'), isTrue);
      expect(host.contains('FirebaseAuth.instance'), isFalse,
          reason: 'voltou a existir uma segunda fonte de identidade');
    });

    test('DAD-22 o e-mail não vaza para superfície pública', () {
      // A tela de Ajustes e privada e pode mostra-lo; a superficie publica, nao.
      // A prova mais forte nao e 'a palavra nao aparece': e que `email` esta na
      // lista de campos PROIBIDOS da apresentacao publica, e continua la.
      final apresentacao = _semComentarios(_fonte('lib/social/apresentacao.dart'));
      expect(apresentacao.contains("'email'"), isTrue,
          reason: 'e-mail saiu da lista de campos proibidos do perfil publico');
      expect(apresentacao.contains("'emailVerified'"), isTrue);

      for (final caminho in [
        'lib/pages/perfil_page.dart',
        'lib/sessao/identidade_publica_sessao.dart',
      ]) {
        final texto = _semComentarios(_fonte(caminho));
        expect(RegExp(r'email', caseSensitive: false).hasMatch(texto),
            isFalse,
            reason: '$caminho passou a falar de e-mail');
      }
      // E a origem do e-mail e a autoridade de CONTA, nao a identidade publica.
      final host = _semComentarios(
        _fonte('lib/casca/configuracoes_de_producao.dart'),
      );
      expect(host.contains('EscopoAutenticacao.de(context).emailDaConta'),
          isTrue);
    });

    testWidgets('DAD-23 plano e renovação não são literais', (t) async {
      _superficieDeVarredura(t);
      await t.pumpWidget(_telaCom(
        icones: conjuntoPadraoDeAjustes,
        perfil: PerfilResumo(
          apelido: 'Aurora',
          email: '',
          vip: true,
          fichas: null,
          assinatura: AssinaturaVipNaTela(
            situacao: SituacaoAssinaturaVip.ativa,
            plano: 'master_vip_mensal',
            validoAte: DateTime.utc(2026, 9, 24, 12),
            renovacaoAutomatica: true,
          ),
        ),
      ));
      await _assentar(t);
      expect(find.text('master_vip_mensal · Renova em 24/09/2026'),
          findsOneWidget);
      expect(find.text('Renova em 24/08 · Mensal'), findsNothing);

      // Sem autoridade, a tela diz que não sabe — nunca "não assina".
      await t.pumpWidget(_telaCom(
        icones: conjuntoPadraoDeAjustes,
        perfil: const PerfilResumo(
          apelido: 'Aurora',
          email: '',
          vip: false,
          fichas: null,
        ),
      ));
      await _assentar(t);
      expect(find.textContaining('indisponivel'), findsOneWidget);

      // E o literal proibido não existe em lugar nenhum do código da tela.
      final tela =
          _semComentarios(_fonte('lib/screens/configuracoes_screen.dart'));
      expect(tela.contains('Renova em 24/08'), isFalse);
      expect(RegExp(r"'Mensal'").hasMatch(tela), isFalse);
    });

    testWidgets('DAD-24 a linha comercial chama-se Fichas e compras',
        (t) async {
      _superficieDeVarredura(t);
      final toques = <String>[];
      await t.pumpWidget(_telaCom(
        icones: conjuntoPadraoDeAjustes,
        toques: toques,
      ));
      await _assentar(t);
      expect(find.text('Fichas e compras'), findsOneWidget);
      expect(find.text('Moedas e compras'), findsNothing);
      expect(find.text('Pacotes de fichas e histórico'), findsOneWidget);
      await t.tap(find.text('Fichas e compras'));
      await _assentar(t);
      expect(toques, ['fichasECompras']);

      final tela = _fonte('lib/screens/configuracoes_screen.dart');
      expect(tela.contains('Moedas e compras'), isFalse);
      expect(tela.contains('moedas disponíveis'), isFalse);
    });

    testWidgets('DAD-25 a versão vem da build', (t) async {
      _superficieDeVarredura(t);
      await t.pumpWidget(_telaCom(
        icones: conjuntoPadraoDeAjustes,
        config: const Configuracoes(versaoApp: '7.7.7'),
      ));
      await _assentar(t);
      expect(find.text('Versão 7.7.7'), findsOneWidget);

      final host = _fonte('lib/casca/configuracoes_de_producao.dart');
      expect(host.contains("String.fromEnvironment("), isTrue);
      expect(host.contains("'BMV_VERSAO_APP'"), isTrue);
      expect(_semComentarios(host).contains('2.0.0'), isFalse);
      expect(_semComentarios(_fonte('lib/screens/configuracoes_screen.dart'))
          .contains('2.0.0'), isFalse);
    });

    test('DAD-26 Como jogar continua na rota canônica', () {
      final host = _semComentarios(
        _fonte('lib/casca/configuracoes_de_producao.dart'),
      );
      expect(host.contains('ComoJogarScreen('), isTrue,
          reason: 'a rota produtiva de Regras foi trocada');
      expect(host.contains('onRegras: _abrirRegras'), isTrue);
    });
  });

  // -------------------------------------------------------------------------
  group('A11Y — o tema não muda leitura, nome nem alvo', () {
    testWidgets('A11Y-27 os alvos críticos têm 48dp', (t) async {
      _superficieDeVarredura(t);
      for (final icones in [
        conjuntoPadraoDeAjustes,
        conjuntoRealVipDeAjustes,
      ]) {
        await t.pumpWidget(_telaCom(
          icones: icones,
          bundle: _BundleFalso(chavesDeAssetDoTemaReal.toSet()),
        ));
        await _assentar(t);
        for (final rotulo in const [
          'Editar perfil',
          'Assinatura VIP',
          'Fichas e compras',
          'Jogadores bloqueados',
          'Regras e como jogar',
          'Suporte',
          'Sair da conta',
        ]) {
          final alvo = _alturaTocavelDe(t, rotulo);
          expect(alvo, greaterThanOrEqualTo(48.0),
              reason: '"$rotulo" tem alvo de ${alvo}dp');
        }
      }
    });

    testWidgets('A11Y-28 ícone nenhum é lido pelo leitor de tela', (t) async {
      _superficieDeVarredura(t);
      final semantica = t.ensureSemantics();

      for (final icones in [
        conjuntoPadraoDeAjustes,
        conjuntoRealVipDeAjustes,
      ]) {
        await t.pumpWidget(_telaCom(
          icones: icones,
          bundle: _BundleFalso(chavesDeAssetDoTemaReal.toSet()),
        ));
        await _assentar(t);
        // Nenhum `Image` do tema entra na árvore semântica.
        for (final img in t.widgetList<Image>(find.byType(Image))) {
          expect(img.excludeFromSemantics, isTrue,
              reason: 'um arquivo do tema virou nó de leitura');
        }
        for (final rotulos in _rotulosSemanticos(t)) {
          expect(rotulos.contains('.webp'), isFalse,
              reason: 'nome de arquivo anunciado: $rotulos');
          expect(rotulos.contains('assets/'), isFalse, reason: rotulos);
        }
      }
      // O binding confere os `SemanticsHandle` ANTES de rodar os `tearDown`:
      // soltar por `addTearDown` reprova o teste por handle vivo.
      semantica.dispose();
    });

    testWidgets('A11Y-29 os nomes acessíveis são IGUAIS nos dois temas',
        (t) async {
      _superficieDeVarredura(t);
      final semantica = t.ensureSemantics();

      await t.pumpWidget(_telaCom(icones: conjuntoPadraoDeAjustes));
      await _assentar(t);
      final nomesPadrao = _rotulosSemanticos(t);

      await t.pumpWidget(_telaCom(
        icones: conjuntoRealVipDeAjustes,
        bundle: _BundleFalso(chavesDeAssetDoTemaReal.toSet()),
      ));
      await _assentar(t);
      final nomesReais = _rotulosSemanticos(t);

      expect(nomesPadrao, isNotEmpty);
      expect(nomesReais, nomesPadrao,
          reason: 'o tema mudou o que o leitor de tela anuncia');
      semantica.dispose();
    });

    testWidgets('A11Y-30 texto ampliado não estoura', (t) async {
      _superficieDeVarredura(t);
      // DOIS detectores, e só estes dois são honestos: o erro do framework
      // (`RenderFlex overflowed`) e o corte SILENCIOSO por `maxLines`. As
      // métricas de largura de parágrafo acusam a tela intocada já em 100%.
      final estouros = <String>[];
      final anterior = FlutterError.onError;
      FlutterError.onError = (d) => estouros.add(d.exceptionAsString());
      try {
        await t.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
            child: _telaCom(
              icones: conjuntoRealVipDeAjustes,
              bundle: _BundleFalso(chavesDeAssetDoTemaReal.toSet()),
            ),
          ),
        );
        await _assentar(t);
      } finally {
        // ANTES de qualquer `expect`: o binding reprova o teste inteiro se um
        // `expect` rodar com o handler ainda trocado.
        FlutterError.onError = anterior;
      }
      final transbordou =
          estouros.where((e) => e.contains('overflowed')).toList();
      expect(transbordou, isEmpty, reason: transbordou.join('\n'));
      expect(_cortesSilenciosos(t), isEmpty,
          reason: 'texto cortado por maxLines em 160% de escala');
    });

    testWidgets('A11Y-31 o tema não é o único portador de significado',
        (t) async {
      _superficieDeVarredura(t);
      // Toda ação nomeada por ícone TEM texto ao lado, nos dois temas: nenhuma
      // função é comunicada só pelo dourado.
      for (final icones in [
        conjuntoPadraoDeAjustes,
        conjuntoRealVipDeAjustes,
      ]) {
        await t.pumpWidget(_telaCom(
          icones: icones,
          bundle: _BundleFalso(chavesDeAssetDoTemaReal.toSet()),
        ));
        await _assentar(t);
        for (final rotulo in const [
          'Editar perfil',
          'Assinatura VIP',
          'Fichas e compras',
          'Música',
          'Vibração',
          'Jogadores bloqueados',
          'Sair da conta',
          'Excluir minha conta',
        ]) {
          expect(find.text(rotulo), findsOneWidget, reason: rotulo);
        }
      }
    });

    testWidgets('A11Y-32 Sair da conta conserva o tratamento destrutivo',
        (t) async {
      _superficieDeVarredura(t);
      final bundle = _BundleFalso(chavesDeAssetDoTemaReal.toSet());
      for (final icones in [
        conjuntoPadraoDeAjustes,
        conjuntoRealVipDeAjustes,
      ]) {
        await t.pumpWidget(_telaCom(icones: icones, bundle: bundle));
        await _assentar(t);
        // O ícone de sair é o MESMO glifo nos dois temas — nada de dourado.
        expect(
          find.byWidgetPredicate((w) =>
              w is Icon && w.icon == Icons.logout_rounded),
          findsOneWidget,
        );
        expect(
          find.byWidgetPredicate((w) =>
              w is Icon && w.icon == Icons.person_remove_outlined),
          findsOneWidget,
        );
      }
      // E o contrato declara essa invariância, para que ninguém a desfaça sem
      // ver.
      expect(IconeAjustes.invariantes.contains(IconeAjustes.sair), isTrue);
      expect(IconeAjustes.invariantes.contains(IconeAjustes.excluirConta),
          isTrue);
      expect(arquivosDoTemaReal.containsKey(IconeAjustes.sair), isFalse);
      expect(arquivosDoTemaReal.containsKey(IconeAjustes.excluirConta),
          isFalse);
    });
  });

  // -------------------------------------------------------------------------
  group('NRG — as autoridades vizinhas ficaram fora do alcance', () {
    test('NRG-33 o Perfil público não conhece o tema', () {
      for (final caminho in [
        'lib/pages/perfil_page.dart',
        'lib/social/apresentacao.dart',
      ]) {
        final texto = _fonte(caminho);
        expect(texto.contains('tema/'), isFalse, reason: caminho);
        expect(texto.contains('IconeAjustes'), isFalse, reason: caminho);
      }
    });

    test('NRG-34 catálogo e inventário não ganharam o tema', () {
      for (final caminho in [
        'lib/colecoes/colecao_catalogo.dart',
        'lib/colecoes/colecao_inventario.dart',
        'lib/colecoes/colecao_repositorio.dart',
      ]) {
        final texto = _fonte(caminho);
        expect(texto.contains('IconeAjustes'), isFalse, reason: caminho);
        expect(texto.contains('TemaIconografia'), isFalse, reason: caminho);
        expect(texto.contains('ajustes/real'), isFalse, reason: caminho);
      }
    });

    test('NRG-35 o Billing não passou a decidir tema', () {
      // A direção da dependência é a de sempre: o tema conhece o Billing, o
      // Billing não conhece o tema.
      final dir = Directory('lib/billing');
      for (final arquivo in dir.listSync().whereType<File>()) {
        final texto = arquivo.readAsStringSync();
        expect(texto.contains("tema/"), isFalse, reason: arquivo.path);
        expect(texto.contains('TemaIconografia'), isFalse,
            reason: arquivo.path);
      }
    });

    test('NRG-36 o passe de cortesia não foi ampliado', () {
      final passe = _semComentarios(_daRaiz('functions-ranking/src/passe.ts'));
      expect(passe.contains('vipCompleto'), isFalse);
      expect(passe.contains('beneficiosVipCompletos'), isFalse);
      expect(passe.contains('playerEntitlements'), isFalse);
    });

    test('NRG-37 as regras de mesa não foram tocadas pelo tema', () {
      for (final caminho in [
        'lib/rules/rule_spec.dart',
        'lib/comunicacao/ambiente.dart',
      ]) {
        final texto = _fonte(caminho);
        expect(texto.contains('IconeAjustes'), isFalse, reason: caminho);
        expect(texto.contains('TemaIconografia'), isFalse, reason: caminho);
      }
    });

    test('NRG-38 a superfície do tema é só a tela de Ajustes', () {
      // Quem importa `lib/tema/` — e ninguém mais deveria.
      final permitidos = {
        'lib/casca/configuracoes_de_producao.dart',
        'lib/screens/configuracoes_screen.dart',
        'lib/tema/conjunto_real_vip.dart',
        'lib/tema/resolucao_tema_ajustes.dart',
        'lib/tema/iconografia_ajustes.dart',
      };
      final encontrados = <String>{};
      for (final arquivo in Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))) {
        final texto = arquivo.readAsStringSync();
        final caminho = arquivo.path.replaceAll(r'\', '/');
        // O próprio pacote do tema pertence a si por definição; o que importa é
        // quem MAIS o alcança.
        if (caminho.startsWith('lib/tema/') ||
            texto.contains("tema/iconografia_ajustes.dart") ||
            texto.contains("tema/resolucao_tema_ajustes.dart") ||
            texto.contains("tema/conjunto_real_vip.dart")) {
          encontrados.add(caminho);
        }
      }
      expect(encontrados, permitidos,
          reason: 'o tema escapou da tela de Ajustes');
    });
  });
}

// ---------------------------------------------------------------------------
// Ferramentas de medição
// ---------------------------------------------------------------------------

/// Remove comentários de linha. Sem isto, uma prova de ausência casa com o
/// comentário que EXPLICA a ausência — e passa provando o contrário.
String _semComentarios(String fonte) => fonte
    .split('\n')
    .where((l) => !l.trimLeft().startsWith('//'))
    .join('\n');

/// Textos que o `maxLines` cortou sem levantar erro nenhum.
List<String> _cortesSilenciosos(WidgetTester t) {
  final cortados = <String>[];
  void desce(RenderObject no) {
    if (no is RenderParagraph && no.didExceedMaxLines) {
      cortados.add(no.text.toPlainText());
    }
    no.visitChildren(desce);
  }

  desce(t.binding.rootElement!.renderObject!);
  return cortados;
}

List<String> _textosDe(WidgetTester t) => t
    .widgetList<Text>(find.byType(Text))
    .map((w) => w.data ?? '')
    .where((s) => s.isNotEmpty)
    .toList();

List<bool> _estadosDosSwitches(WidgetTester t) =>
    t.widgetList<Switch>(find.byType(Switch)).map((s) => s.value).toList();

Set<String> _rotulosSemanticos(WidgetTester t) {
  final rotulos = <String>{};
  void desce(SemanticsNode no) {
    final dados = no.getSemanticsData();
    final nome = dados.label.trim().isNotEmpty
        ? dados.label.trim()
        : dados.tooltip.trim();
    if (nome.isNotEmpty) rotulos.add(nome);
    no.visitChildren((filho) {
      desce(filho);
      return true;
    });
  }

  // Ancorar no MaterialApp e SUBIR ate a raiz: `pipelineOwner` e depreciado, e
  // com um modal aberto a subarvore da tela ja foi descartada — subir de la
  // varre uma arvore morta que ainda responde.
  var no = t.getSemantics(find.byType(MaterialApp));
  while (no.parent != null) {
    no = no.parent!;
  }
  desce(no);
  return rotulos;
}

/// Altura do alvo de toque que responde por [rotulo].
double _alturaTocavelDe(WidgetTester t, String rotulo) {
  final texto = find.text(rotulo);
  expect(texto, findsOneWidget, reason: 'rótulo ausente: $rotulo');
  final alvo = find.ancestor(
    of: texto,
    matching: find.byWidgetPredicate((w) => w is InkWell || w is InkResponse),
  );
  if (alvo.evaluate().isEmpty) return t.getSize(texto).height;
  return t.getSize(alvo.first).height;
}
