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
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart' show sha256;

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

// ---------------------------------------------------------------------------
// A arte: onde ela mora, o que ela é, e como se olha dentro dela
// ---------------------------------------------------------------------------

const String _dirDaArte = 'assets/ajustes/real';

/// Os digestos APROVADOS, conferidos contra `SHA256SUMS.txt` do pacote
/// `tema-real-vip-assets-v1.zip`
/// (`8ef236fd64f9a3bf0c4dcddcd9bf5da3f86a29f788ac0d860658a74bcc99c3b6`).
///
/// Estão aqui, e não num arquivo ao lado, de propósito: uma tabela de hashes que
/// mora junto do que ela guarda pode ser reescrita no mesmo commit sem aparecer
/// como decisão. Trocar a arte passa a exigir trocar ESTA lista, no diff.
const Map<String, String> _digestosAprovados = {
  'editar_perfil.webp':
      '8a2d81da512bf44c41822df2dd9a79332b3849aa569573e507b358034df086b5',
  'assinatura_vip.webp':
      'b93a1445e893c55ce7eb458a405d8d0ce8e0cd7ca9685b3bf3da0142ff5f9c45',
  'fichas_e_compras.webp':
      'a4ed40a0645cab6baf6a17a57c80663c443e165c1f6d097e47685c2aace0f60f',
  'musica.webp':
      'aab5866f36beb99f84420fe8398dff4c0c85a39e1b1de7c43c0086774d973350',
  'efeitos_sonoros.webp':
      'db9a0928db0fb72bd7ef4dcf11082cd5dd0ea7e901305b6448b312b2085fc9f1',
  'vibracao.webp':
      'b40b95fb0523be3656b6f5654481dc4f6059828f144e57781ef0015fa7f1cd30',
  'notificacoes.webp':
      'cf4f8c3908fa35b9b6404dcb32fc2735de8dea0a3120493da4fa7fd515064dbc',
  'animacoes.webp':
      'a820c2aeec9315cbd5e0f4d365817917e850fcc1274a9a114d7b5e4aeae63666',
  'ordenar_cartas.webp':
      'ebb6d41c90ba636454f0a6a1d48c4dabfe369250c9e91615e83a4e23214d9266',
  'mao.webp':
      '9d4ba7346c4818b34324ca9931643f870677573684754cc599d5caffb134924e',
  'presenca_online.webp':
      'c4c1eb811e2f045e52eea73335eb2f6516162fff973724f260469bc6a3280aaf',
  'convites.webp':
      'ca7a1d3fe919216ffe2f036e97863e350ec978a6e395991f2e1740f4e98b836c',
  'jogadores_bloqueados.webp':
      '2698f28b93e311c96040e4ca37cc500de00d4f8a53110b661de36b6f4a047d98',
  'como_jogar.webp':
      'b5fa759df9a5cad73cf8a93e2e5a107a203b24ba3c03193e5f97e7cf556e8de1',
  'suporte.webp':
      'efd1ea80bbd991aeef0543d6dfc660f481a8ac36e8d4d1d70236328aabe15411',
  'avaliar_aplicativo.webp':
      '6cee0fc959dab25140fc7104d4eebd7e76e501d57998936a31dc10638e492810',
  'secao_conta.webp':
      'a01fe79375c8ea505fc97a17ff82b14c76037dad973ac2f7b1cd298f65a24856',
  'secao_som_e_notificacoes.webp':
      '5f88111d7fbefaf0f1b4b592e5ea6fd994b113ccc37b3e800a5f9e130fb7f299',
  'secao_jogo.webp':
      'd06bebfb7ad918e90d0bc5d2021f4fdfba5601144d6addfd52dd8af4a114253b',
  'secao_privacidade.webp':
      '89e0c913d90c36ec92933bedbd3d94d177bda1f5b9abe834cb7a5c06f2435b34',
  'secao_geral.webp':
      'edca9681f7986d85b537646c55a707d0ce93a9298578ea07d524596cb2d063fa',
  'titulo_ajustes.webp':
      'b5a804424d2aba06fe9afc6929bfb7c7b8cdda41fcf3e3abe86cee049a9afd2b',
  'confirmar_descarte.webp':
      '5253ef584a68396f16b0860f9657170372e7f744f6a2fec8cc1ed304d73a4b8e',
  'chat_publico.webp':
      'f3b1c526595707442a350620d9bb717f7ff80e64bdda83f8149314ae2dcaabcd',
  'idioma.webp':
      'b013eb3c67e503b03b55fefa8b042c280c9b0189900ff38521e6015d9bf82e88',
  'termos_e_privacidade.webp':
      '2ebdf9861f700419838582da938ed834272ea472a36a6747c1571df292b23e31',
  'orientacao_mesa.webp':
      '5d9d7232a27bef442a7cc21651ca4eb8a93430a876b64324d2380f81403498d1',
  'saldo_de_fichas.webp':
      'b1e4dba34be2187b12d2d61ed0ef2015e3f0c3a6d2c430191e8f08e21318caaa',
};

/// Bundle servido pelos ARQUIVOS REAIS do repositório.
///
/// Existe porque `rootBundle` numa suíte de teste não carrega o manifesto de
/// assets do aplicativo. Ler do disco prova o que interessa — que estes bytes
/// abrem —, e [vazio] encena corrupção sem tocar em nenhum arquivo.
class _BundleDoDisco extends CachingAssetBundle {
  _BundleDoDisco({this.vazio = const {}});

  /// Chaves que devem responder como arquivo corrompido (zero byte).
  final Set<String> vazio;

  final List<String> lidos = <String>[];

  @override
  Future<ByteData> load(String key) async {
    lidos.add(key);
    if (vazio.contains(key)) return ByteData(0);
    final nome = key.split('/').last;
    final arquivo = File('$_dirDaArte/$nome');
    if (!arquivo.existsSync()) {
      throw FlutterError('asset ausente no disco: $key');
    }
    return ByteData.view(arquivo.readAsBytesSync().buffer);
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) async =>
      throw FlutterError('esta bancada só serve bytes');
}

/// Roda [corpo] com o relogio REAL.
///
/// `testWidgets` roda sob `FakeAsync`, e decodificar imagem depende de
/// trabalho do engine que acontece FORA desse relogio: o `await` nunca
/// devolve e o teste morre por timeout de dez minutos, sem uma linha de
/// diagnostico. `runAsync` e a unica saida — e por isso nenhuma prova deste
/// grupo pode bombear quadro: dentro dele, `pump` e proibido.
Future<void> _comRelogioReal(
  WidgetTester t,
  Future<void> Function() corpo,
) async {
  await t.runAsync(corpo);
}

Future<ui.Image> _decodificar(String nome) async {
  final bytes = File('$_dirDaArte/$nome').readAsBytesSync();
  final codec = await ui.instantiateImageCodec(bytes);
  final quadro = await codec.getNextFrame();
  return quadro.image;
}

/// O que se aprende olhando os pixels de um ícone.
class _Pixels {
  const _Pixels({
    required this.transparentes,
    required this.opacos,
    required this.cobertura,
    required this.cantosTransparentes,
    required this.brancoOpaco,
    required this.bordaNaoTransparente,
  });

  /// Pixels com alfa exatamente zero.
  final int transparentes;

  /// Pixels com alfa 255.
  final int opacos;

  /// Fração de pixels com alguma tinta (alfa > 32).
  final double cobertura;

  /// Quantos dos quatro cantos estão transparentes.
  final int cantosTransparentes;

  /// Fração de pixels brancos E opacos — o rastro de um fundo esquecido.
  final double brancoOpaco;

  /// Fração do ANEL DE BORDA (1 px) que não é transparente.
  ///
  /// É a medida decisiva contra fundo assado: um fundo chapado — branco, preto
  /// ou xadrez de editor — dá 100% aqui. Um desenho que só encosta na borda dá
  /// frações de por cento. Os quatro cantos sozinhos são frágeis; o anel são
  /// 1.020 pixels.
  final double bordaNaoTransparente;
}

Future<_Pixels> _pixels(String nome) async {
  final img = await _decodificar(nome);
  final dados = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
  img.dispose();
  final b = dados!.buffer.asUint8List();
  final total = b.length ~/ 4;
  var transparentes = 0, opacos = 0, comTinta = 0, branco = 0;
  for (var i = 0; i < b.length; i += 4) {
    final a = b[i + 3];
    if (a == 0) transparentes++;
    if (a == 255) opacos++;
    if (a > 32) comTinta++;
    if (a > 200 && b[i] > 240 && b[i + 1] > 240 && b[i + 2] > 240) branco++;
  }
  int alfaEm(int x, int y) => b[((y * img.width) + x) * 4 + 3];
  final cantos = [
    alfaEm(0, 0),
    alfaEm(img.width - 1, 0),
    alfaEm(0, img.height - 1),
    alfaEm(img.width - 1, img.height - 1),
  ].where((a) => a == 0).length;

  var pixelsDaBorda = 0, naoTransparenteNaBorda = 0;
  for (var x = 0; x < img.width; x++) {
    for (final y in [0, img.height - 1]) {
      pixelsDaBorda++;
      if (alfaEm(x, y) != 0) naoTransparenteNaBorda++;
    }
  }
  for (var y = 1; y < img.height - 1; y++) {
    for (final x in [0, img.width - 1]) {
      pixelsDaBorda++;
      if (alfaEm(x, y) != 0) naoTransparenteNaBorda++;
    }
  }

  return _Pixels(
    transparentes: transparentes,
    opacos: opacos,
    cobertura: comTinta / total,
    cantosTransparentes: cantos,
    brancoOpaco: branco / total,
    bordaNaoTransparente: naoTransparenteNaBorda / pixelsDaBorda,
  );
}

/// Fração da caixa de 18x18 que ainda recebe tinta depois da redução.
Future<double> _coberturaEm18px(String nome) async {
  const lado = 18;
  final img = await _decodificar(nome);
  final gravador = ui.PictureRecorder();
  final tela = Canvas(gravador);
  tela.drawImageRect(
    img,
    Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
    const Rect.fromLTWH(0, 0, 18, 18),
    Paint()..filterQuality = FilterQuality.high,
  );
  final pequena = await gravador.endRecording().toImage(lado, lado);
  img.dispose();
  final dados = await pequena.toByteData(format: ui.ImageByteFormat.rawRgba);
  pequena.dispose();
  final b = dados!.buffer.asUint8List();
  var comTinta = 0;
  for (var i = 3; i < b.length; i += 4) {
    if (b[i] > 32) comTinta++;
  }
  return comTinta / (lado * lado);
}

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

  // -------------------------------------------------------------------------
  // ART — a arte aprovada, byte a byte e pixel a pixel
  //
  // Este grupo entrou com a incorporação dos 28 desenhos. Ele não fala de
  // elegibilidade nem de tema: fala dos ARQUIVOS. É o único lugar do
  // repositório que abre os WebP e olha dentro deles, e é por isso que ele
  // existe — um asset pode estar presente, registrado e citado no manifesto e
  // ainda assim ser um retângulo branco opaco.
  // -------------------------------------------------------------------------
  group('ART — a arte aprovada', () {
    test('ART-01 o diretório tem os 28 exigidos, e nada além', () {
      final dir = Directory(_dirDaArte);
      expect(dir.existsSync(), isTrue, reason: 'diretório da arte ausente');
      final noDisco = dir
          .listSync()
          .whereType<File>()
          .map((f) => f.path.replaceAll(r'\', '/').split('/').last)
          .toSet();
      final exigidos = arquivosDoTemaReal.values.toSet();

      expect(exigidos.length, 28);
      expect(noDisco.difference(exigidos), isEmpty,
          reason: 'arquivo NÃO registrado no contrato: '
              '${noDisco.difference(exigidos)}');
      expect(exigidos.difference(noDisco), isEmpty,
          reason: 'arquivo exigido e ausente: '
              '${exigidos.difference(noDisco)}');
    });

    test('ART-02 cada arquivo confere com o SHA-256 aprovado', () {
      expect(_digestosAprovados.length, 28);
      expect(_digestosAprovados.keys.toSet(),
          arquivosDoTemaReal.values.toSet(),
          reason: 'a tabela de digestos e o contrato divergiram');
      for (final entrada in _digestosAprovados.entries) {
        final bytes = File('$_dirDaArte/${entrada.key}').readAsBytesSync();
        final real = sha256.convert(bytes).toString();
        expect(real, entrada.value,
            reason: '${entrada.key} não é o arquivo aprovado');
      }
    });

    test('ART-03 todos são WebP LOSSLESS 256x256 com alfa declarado', () {
      for (final nome in arquivosDoTemaReal.values) {
        final b = File('$_dirDaArte/$nome').readAsBytesSync();
        expect(String.fromCharCodes(b.sublist(0, 4)), 'RIFF', reason: nome);
        expect(String.fromCharCodes(b.sublist(8, 12)), 'WEBP', reason: nome);
        // `VP8L` é o contêiner SEM PERDA. `VP8 ` seria com perda, e num ícone
        // de 18 px o artefato de compressão come justamente o contorno fino.
        expect(String.fromCharCodes(b.sublist(12, 16)), 'VP8L', reason: nome);
        expect(b[20], 0x2F, reason: '$nome: assinatura VP8L errada');
        final bits = b.buffer.asByteData().getUint32(21, Endian.little);
        expect((bits & 0x3FFF) + 1, 256, reason: '$nome: largura');
        expect(((bits >> 14) & 0x3FFF) + 1, 256, reason: '$nome: altura');
        expect((bits >> 28) & 1, 1, reason: '$nome: alfa não declarado');
      }
    });

    testWidgets('ART-04 os 28 decodificam de verdade, em 256x256', (t) async {
      await _comRelogioReal(t, () async {
      for (final nome in arquivosDoTemaReal.values) {
        final img = await _decodificar(nome);
        expect(img.width, 256, reason: nome);
        expect(img.height, 256, reason: nome);
        img.dispose();
      }
      });
    });

    testWidgets('ART-05 o alfa é REAL: há pixel transparente e pixel opaco',
        (t) async {
      await _comRelogioReal(t, () async {
      // A prova de que o fundo foi RECORTADO, e não pintado de preto. Um PNG
      // com fundo chapado também "tem canal alfa": o que ele não tem é pixel
      // com alfa zero.
      for (final nome in arquivosDoTemaReal.values) {
        final p = await _pixels(nome);
        expect(p.transparentes, greaterThan(0),
            reason: '$nome não tem um único pixel transparente');
        expect(p.opacos, greaterThan(0),
            reason: '$nome não tem um único pixel opaco');
      }
      });
    });

    testWidgets('ART-06 nenhum é uma folha em branco', (t) async {
      await _comRelogioReal(t, () async {
      for (final nome in arquivosDoTemaReal.values) {
        final p = await _pixels(nome);
        expect(p.cobertura, greaterThan(0.05),
            reason: '$nome está praticamente vazio '
                '(${(p.cobertura * 100).toStringAsFixed(1)}% de tinta)');
      }
      });
    });

    testWidgets('ART-07 nenhum traz fundo branco ou xadrez embutido',
        (t) async {
      await _comRelogioReal(t, () async {
      for (final nome in arquivosDoTemaReal.values) {
        final p = await _pixels(nome);
        // Os quatro cantos são o lugar onde um fundo esquecido aparece
        // primeiro — e onde o xadrez do editor de imagem costuma sobrar.
        expect(p.cantosTransparentes, 4,
            reason: '$nome tem canto opaco: fundo não foi recortado');
        // Os limiares vêm da MEDIDA do conjunto aprovado, e a distância é de
        // ordens de grandeza — não são números ajustados para passar:
        //   anel de borda ... máximo medido 0,69%; fundo assado daria 100%;
        //   branco opaco ... máximo medido 2,00% (o vidro do espelho em
        //                    `editar_perfil`); fundo branco daria mais de 50%.
        expect(p.bordaNaoTransparente, lessThan(0.02),
            reason: '$nome pinta '
                '${(p.bordaNaoTransparente * 100).toStringAsFixed(1)}% do anel '
                'de borda: fundo assado');
        expect(p.brancoOpaco, lessThan(0.10),
            reason: '$nome tem ${(p.brancoOpaco * 100).toStringAsFixed(1)}% '
                'de branco opaco: fundo branco ou xadrez de editor');
      }
      });
    });

    testWidgets('ART-08 continuam legíveis reduzidos a 18 px', (t) async {
      await _comRelogioReal(t, () async {
      // 18 px é o tamanho de desenho na tela (`_iconeTile`). Um ícone que
      // desaparece nessa redução é bonito no painel e inútil no aparelho; um
      // que vira um bloco cheio perdeu o desenho e virou mancha.
      for (final nome in arquivosDoTemaReal.values) {
        final cobertura = await _coberturaEm18px(nome);
        expect(cobertura, greaterThan(0.15),
            reason: '$nome some a 18 px '
                '(${(cobertura * 100).toStringAsFixed(1)}%)');
        expect(cobertura, lessThan(0.98),
            reason: '$nome vira mancha a 18 px '
                '(${(cobertura * 100).toStringAsFixed(1)}%)');
      }
      });
    });

    test('ART-09 a declaração da arte é única, e a lista de arquivos não se '
        'repete', () {
      final pubspec = _fonte('pubspec.yaml');
      final linhas = pubspec
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l == '- assets/ajustes/real/')
          .length;
      expect(linhas, 1,
          reason: 'a declaração do diretório da arte não está exatamente uma '
              'vez em app/pubspec.yaml');

      // FONTE ÚNICA da LISTA DE ARQUIVOS: os 28 nomes moram no contrato
      // (`conjunto_real_vip.dart`) e no registro de origem, e em lugar nenhum
      // mais. Um workflow ou script que os repetisse viraria uma segunda
      // autoridade, e as duas divergiriam no primeiro dia em que alguém
      // corrigisse só uma. O DIRETÓRIO, esse, precisa aparecer nos montadores —
      // é o que a ART-15 confere.
      const alguns = [
        'secao_jogo.webp',
        'titulo_ajustes.webp',
        'saldo_de_fichas.webp',
      ];
      for (final caminho in const [
        '../.github/workflows/ci-os-integracao.yml',
        '../.github/workflows/build.yml',
        '../.github/workflows/release-aab.yml',
        '../scripts/ci/gates_os_integracao.txt',
        '../tools/ci/montar_app.sh',
      ]) {
        final texto = _fonte(caminho);
        for (final nome in alguns) {
          expect(texto.contains(nome), isFalse,
              reason: '$caminho repete a lista de arquivos da arte');
        }
      }
    });
    testWidgets('ART-10 a chave está ligada e o conjunto inteiro abre',
        (t) async {
      await _comRelogioReal(t, () async {
      expect(kConjuntoRealVipRegistrado, isTrue,
          reason: 'o Tema Real está desligado');
      final doDisco = _BundleDoDisco();
      expect(await conjuntoRealDisponivel(bundle: doDisco), isTrue,
          reason: 'o conjunto real não abriu inteiro a partir dos arquivos');
      expect(doDisco.lidos.toSet(), chavesDeAssetDoTemaReal.toSet(),
          reason: 'a pré-checagem não percorreu os 28');
      });
    });

    testWidgets('ART-11 corromper UM arquivo derruba o conjunto inteiro',
        (t) async {
      await _comRelogioReal(t, () async {
      for (final alvo in chavesDeAssetDoTemaReal) {
        final bundle = _BundleDoDisco(vazio: {alvo});
        expect(await conjuntoRealDisponivel(bundle: bundle), isFalse,
            reason: '$alvo corrompido e o conjunto se disse completo');
      }
      });
    });

    testWidgets('ART-12 ATIVAÇÃO: o VIP vigente recebe o Tema Real pelo '
        'caminho de produção', (t) async {
      await _comRelogioReal(t, () async {
      // Sem `registrado:` e sem `verificarConjunto:` — exatamente a chamada que
      // o host faz. É esta prova que distingue "a arquitetura funciona" de "o
      // tema está ligado".
      final acesso = await _comPortao(
        documento: _direito(EstadoEntitlement.ativo),
      );
      final r = await resolverTemaDeAjustes(
        acesso: acesso,
        verificarConjunto: () => conjuntoRealDisponivel(
          bundle: _BundleDoDisco(),
        ),
      );
      expect(r.tema, TemaIconografia.realVip);
      expect(r.motivo, MotivoDoTema.concedido);
      expect(r.icones.assetsUsados, chavesDeAssetDoTemaReal.toSet());
      });
    });

    testWidgets('ART-13 e o público continua no Padrão pelo mesmo caminho',
        (t) async {
      await _comRelogioReal(t, () async {
      for (final caso in <String, EntitlementVip?>{
        'sem documento': null,
        'expirado': _direito(
          EstadoEntitlement.expirado,
          ativo: false,
          expira: DateTime.utc(2026, 1, 1),
        ),
      }.entries) {
        final acesso = await _comPortao(documento: caso.value);
        final r = await resolverTemaDeAjustes(
          acesso: acesso,
          verificarConjunto: () => conjuntoRealDisponivel(
            bundle: _BundleDoDisco(),
          ),
        );
        expect(r.tema, TemaIconografia.padrao, reason: caso.key);
        expect(r.icones.assetsUsados, isEmpty, reason: caso.key);
      }
      });
    });

    testWidgets('ART-14 o Tema Real não acrescenta UM pixel de estouro em '
        '320/360/412 dp a 100/150/200% de fonte', (t) async {
      // Nove geometrias, e a razão de serem estas: 320 dp é o telefone pequeno
      // que ainda existe, 412 dp o grande, 360 dp a mediana; 200% é o teto de
      // ampliação que o Android oferece nas Configurações do sistema.
      //
      // A prova é COMPARATIVA, e é de propósito. Esta tela já estoura 22 px em
      // 320 dp a 200% — no cabeçalho, entre o apelido flexível e a pastilha
      // 'VIP' — e isso é dívida ANTERIOR a esta OS, medida idêntica nos dois
      // temas. Um limiar absoluto aqui obrigaria esta missão a consertar layout
      // que ela não veio consertar, ou a afrouxar o número até passar. A
      // pergunta certa é outra: o ícone luxuoso, que tem a MESMA caixa de 18 px
      // do glifo, acrescenta alguma coisa? A resposta tem de ser 'nada', e o
      // teste falha se um único estouro ou corte aparecer só no Tema Real.
      final bundle = _BundleDoDisco();
      addTearDown(t.view.reset);

      Future<(Set<String>, Set<String>)> medir(
        ConjuntoDeIcones icones,
        double largura,
        double escala,
      ) async {
        t.view.physicalSize = Size(largura * 3, 12000);
        t.view.devicePixelRatio = 3;
        final estouros = <String>{};
        final anterior = FlutterError.onError;
        FlutterError.onError = (d) => estouros.add(d.exceptionAsString());
        try {
          await t.pumpWidget(
            MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(escala)),
              child: _telaCom(
                icones: icones,
                bundle: bundle,
                perfil: const PerfilResumo(
                  apelido: 'Jogadora',
                  email: 'jogadora@exemplo.com',
                  avatar: '👑',
                  vip: true,
                  fichas: 1200,
                ),
              ),
            ),
          );
          await _assentar(t);
        } finally {
          FlutterError.onError = anterior;
        }
        return (
          estouros.where((e) => e.contains('overflowed')).toSet(),
          _cortesSilenciosos(t).toSet(),
        );
      }

      for (final largura in const [320.0, 360.0, 412.0]) {
        for (final escala in const [1.0, 1.5, 2.0]) {
          final caso = '${largura.toInt()}dp @ ${(escala * 100).toInt()}%';
          final (estouroPadrao, cortePadrao) =
              await medir(conjuntoPadraoDeAjustes, largura, escala);
          final (estouroReal, corteReal) =
              await medir(conjuntoRealVipDeAjustes, largura, escala);

          expect(estouroReal.difference(estouroPadrao), isEmpty,
              reason: '$caso: estouro que só o Tema Real produz');
          expect(corteReal.difference(cortePadrao), isEmpty,
              reason: '$caso: corte que só o Tema Real produz');

          // E a tela continua INTEIRA no Tema Real: os 28 arquivos, e nenhum
          // glifo de chave variável sobrando.
          final v = _varrer(t);
          expect(v.assets.difference(chavesDeAssetDoTemaReal.toSet()), isEmpty,
              reason: caso);
          expect(v.glifos.intersection(_glifosVariaveis()), isEmpty,
              reason: '$caso: sobrou glifo padrão na tela real');
        }
      }
    });

    test('ART-15 toda pasta declarada é REALMENTE empacotada pelos montadores',
        () {
      // O BURACO MAIS SILENCIOSO QUE ESTA OS ENCONTROU, e ele quase levou a
      // entrega inteira: os dois montadores de APK têm listas PRÓPRIAS de
      // pastas a copiar, escritas à mão, e nenhuma delas conhecia
      // `assets/ajustes/real`. O `montar_app.sh` ainda criava a pasta vazia para
      // o Flutter não reclamar — então o build passava, o APK saía sem os 28
      // ícones, a pré-checagem do conjunto respondia `false` no aparelho, e todo
      // assinante VIP via a tela pública. Sem erro. Em lugar nenhum.
      //
      // `release-aab.yml` escapa porque copia `app/assets/` inteiro por `find`.
      // Os outros dois precisam desta prova.
      final declaradas = _fonte('pubspec.yaml')
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.startsWith('- assets/') && l.endsWith('/'))
          .map((l) => l.substring('- assets/'.length, l.length - 1))
          .toList();
      expect(declaradas, contains('ajustes/real'));
      expect(declaradas.length, greaterThanOrEqualTo(16));

      final montador = _fonte('../tools/ci/montar_app.sh');
      final apk = _fonte('../.github/workflows/build.yml');
      // A cobertura pode vir de um passo do ANCESTRAL que copia recursivamente
      // — `assets/loja/` arrasta `loja/dorsos` nos dois montadores. Por isso a
      // busca é por PREFIXO de caminho, e não pelo nome inteiro.
      //
      // É um limite declarado: um passo de ancestral que copiasse SEM `-r`
      // satisfaria esta prova e não empacotaria a subpasta. O que fecha esse
      // resto é a guarda de pasta vazia do `montar_app.sh`, conferida logo
      // abaixo — ela mede o resultado, não a intenção.
      bool cobre(String texto, String pasta) {
        final segmentos = pasta.split('/');
        for (var i = segmentos.length; i > 0; i--) {
          if (texto.contains(segmentos.take(i).join('/'))) return true;
        }
        return false;
      }

      for (final pasta in declaradas) {
        expect(cobre(montador, pasta), isTrue,
            reason: 'montar_app.sh não copia assets/$pasta');
        expect(cobre(apk, 'assets/$pasta'), isTrue,
            reason: 'build.yml não copia assets/$pasta');
      }
      // As duas pastas que esta OS tocou têm passo PRÓPRIO, com contagem exata.
      expect(apk.contains('EXATAMENTE 28 icones'), isTrue);
      expect(apk.contains('assets/mesa_vip'), isTrue);

      // E o montador reprova, em vez de seguir, quando uma pasta declarada
      // chega vazia — é o que impede a próxima pasta de repetir a história.
      final semComentario = _semComentarios(montador);
      expect(semComentario.contains('pasta declarada no pubspec e VAZIA'),
          isTrue,
          reason: 'montar_app.sh voltou a aceitar pasta declarada e vazia');
      expect(semComentario.contains('exit 1'), isTrue);
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
