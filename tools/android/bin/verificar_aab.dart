// Confere o .aab JA CONSTRUIDO. Nao confia em nenhuma etapa anterior: tudo que
// e afirmado aqui sai de dentro do artefato.
//
// Uso:
//   dart run tools/android/bin/verificar_aab.dart \
//     --aab=app_build/build/app/outputs/bundle/release/app-release.aab \
//     --manifesto=manifesto-final.xml \
//     --application-id=io.github.soniaambrosio.buracomastervip \
//     --version-code=3 --version-name=1.0.1
//
// `--manifesto` e a saida de `bundletool dump manifest`, que e o manifesto REAL
// depois do merge das dependencias — o unico lugar onde a lista de permissoes
// existe de fato. O manifesto de origem do app nao declara quase nenhuma delas.
//
// A conferencia anterior era uma sequencia de `grep` sobre esse XML. `grep` em
// XML aprova por acidente: casa dentro de comentario, casa atributo parecido,
// casa o manifesto de outra coisa. Aqui o XML e parseado.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:image/image.dart' as img;
import 'package:xml/xml.dart';

/// Permissoes que esta build declara, com a origem de cada uma.
///
/// A comparacao e por conjunto EXATO — sobrar reprova, e faltar tambem. Nao e
/// rigor decorativo: nenhuma dessas permissoes esta no manifesto de origem do
/// app (ele nao declara quase nada), todas chegam pelo merge dos manifestos das
/// dependencias. Ou seja, o conjunto muda sozinho quando uma dependencia sobe
/// de versao, sem uma linha de codigo nossa mudar.
///
/// Uma permissao aparecendo sozinha muda o que precisa ser declarado no Data
/// Safety e pode custar uma reprovacao na Play. Uma sumindo sozinha quebra o
/// app em producao. Nos dois casos, o portao obriga alguem a decidir.
///
/// A chave `{applicationId}` e substituida antes da comparacao.
const Map<String, String> permissoesEsperadas = {
  'android.permission.INTERNET':
      'Firebase Auth/Firestore/Functions e o WebSocket de partidas. Sem ela o app nao conecta.',
  'android.permission.ACCESS_NETWORK_STATE':
      'Play Services / Firebase — consulta de conectividade antes de tentar rede.',
  'android.permission.WAKE_LOCK':
      'Play Services (Firebase). Mantem a CPU ativa durante troca de token.',
  'com.android.vending.BILLING':
      'Google Play Billing. Declarada no manifesto de origem E trazida pelo in_app_purchase_android.',
  'com.google.android.c2dm.permission.RECEIVE':
      'Play Services (firebase-common). Recepcao de mensagem do Google Cloud Messaging.',
  'com.google.android.providers.gsf.permission.READ_GSERVICES':
      'Play Services. Leitura das configuracoes do Google Services Framework do aparelho.',
  '{applicationId}.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION':
      'Gerada pelo androidx.core para o proprio app. Nivel `signature`: so o proprio '
          'app a detem, e serve para registrar BroadcastReceiver dinamico nao exportado. '
          'Nao aparece para o usuario e nao entra no Data Safety.',
};

/// Classes que PRECISAM estar compiladas no dex do bundle.
///
/// A conferencia anterior procurava o caminho `com/android/billingclient` na
/// LISTAGEM do zip. Isso nunca poderia dar certo: num AAB (como num APK) as
/// classes nao existem como arquivos — estao dentro de `base/dex/classes*.dex`.
/// A busca retornava zero sempre, e o passo tinha `exit 1` no zero, entao o
/// portao reprovaria todo build. Aqui a busca e pelos bytes do descritor
/// dentro do proprio dex, que e onde a tabela de strings guarda o nome.
const Map<String, String> classesExigidas = {
  'Lcom/android/billingclient/api/BillingClient;':
      'Google Play Billing Library — e a presenca dela que faz a Play Console reconhecer o AAB como capaz de faturar.',
  'Lcom/android/billingclient/api/Purchase;':
      'Modelo de compra da Billing Library.',
  'Lio/flutter/plugins/inapppurchase/InAppPurchasePlugin;':
      'Ponte do plugin in_app_purchase_android para o Dart.',
  'Lcom/google/firebase/auth/FirebaseAuth;': 'Firebase Auth — login do jogador.',
};

void main(List<String> argumentos) {
  final args = _Argumentos(argumentos);
  final aab = File(args.obrigatorio('aab'));
  final manifesto = File(args.obrigatorio('manifesto'));
  final appId = args.obrigatorio('application-id');
  final versionCode = args.obrigatorio('version-code');
  final versionName = args.obrigatorio('version-name');

  if (!aab.existsSync()) _abortar('AAB nao encontrado: ${aab.path}');
  if (!manifesto.existsSync()) {
    _abortar(
      'despejo do manifesto nao encontrado: ${manifesto.path}. '
      'Gere com: java -jar bundletool.jar dump manifest --bundle=<aab>',
    );
  }

  final falhas = <String>[];
  final doc = XmlDocument.parse(manifesto.readAsStringSync());
  final raiz = doc.rootElement;

  _secao('identidade e versao');
  falhas.addAll(_igual('package', raiz.getAttribute('package'), appId));
  falhas.addAll(_igual(
      'android:versionCode', raiz.getAttribute('versionCode', namespace: '*'), versionCode));
  falhas.addAll(_igual(
      'android:versionName', raiz.getAttribute('versionName', namespace: '*'), versionName));

  _secao('SDK');
  final usesSdk = raiz.findElements('uses-sdk').firstOrNull;
  if (usesSdk == null) {
    falhas.add('nao ha <uses-sdk> no manifesto final');
  } else {
    falhas.addAll(_igual('minSdkVersion',
        usesSdk.getAttribute('minSdkVersion', namespace: '*'), '24'));
    falhas.addAll(_igual('targetSdkVersion',
        usesSdk.getAttribute('targetSdkVersion', namespace: '*'), '36'));
  }

  _secao('a identidade do PoC nao pode sobrar em lugar nenhum do manifesto');
  final textoManifesto = manifesto.readAsStringSync();
  if (textoManifesto.contains('buracomastervip.poc') ||
      textoManifesto.contains('com.buracomastervip')) {
    for (final linha in const LineSplitter().convert(textoManifesto)) {
      if (linha.contains('com.buracomastervip')) {
        stdout.writeln('  FALHA sobrou: ${linha.trim()}');
      }
    }
    falhas.add('o pacote do PoC aparece no manifesto final');
  } else {
    stdout.writeln('  OK    nenhuma ocorrencia de com.buracomastervip');
  }

  _secao('Activity de entrada');
  final atividades = raiz
      .findAllElements('activity')
      .map((e) => e.getAttribute('name', namespace: '*'))
      .whereType<String>()
      .toList();
  final principal = '$appId.MainActivity';
  if (atividades.contains(principal)) {
    stdout.writeln('  OK    $principal');
  } else {
    stdout.writeln('  FALHA nao achei $principal. Activities: $atividades');
    falhas.add('a MainActivity nao esta no pacote oficial');
  }

  _secao('depuracao desligada');
  final application = raiz.findElements('application').firstOrNull;
  final debuggable = application?.getAttribute('debuggable', namespace: '*');
  if (debuggable == null || debuggable == 'false') {
    stdout.writeln('  OK    android:debuggable = ${debuggable ?? '(ausente)'}');
  } else {
    falhas.add('android:debuggable = $debuggable — o release nao pode ser depuravel');
  }

  _secao('icone declarado');
  final icone = application?.getAttribute('icon', namespace: '*');
  stdout.writeln('  android:icon = $icone');
  if (icone == null) falhas.add('a <application> nao declara android:icon');

  _secao('permissoes efetivas do artefato');
  final esperadas = permissoesEsperadas.map(
    (nome, origem) => MapEntry(nome.replaceAll('{applicationId}', appId), origem),
  );
  final permissoes = raiz
      .findElements('uses-permission')
      .map((e) => e.getAttribute('name', namespace: '*'))
      .whereType<String>()
      .toSet();
  for (final p in permissoes.toList()..sort()) {
    final origem = esperadas[p];
    if (origem == null) {
      stdout.writeln('  FALHA $p  <-- NAO PREVISTA');
      falhas.add('permissao nao prevista no artefato: $p');
    } else {
      stdout.writeln('  OK    $p');
      stdout.writeln('        origem: $origem');
    }
  }
  for (final p in esperadas.keys.toList()..sort()) {
    if (!permissoes.contains(p)) {
      stdout.writeln('  FALHA $p  <-- ESPERADA E AUSENTE');
      falhas.add('permissao esperada sumiu do artefato: $p');
    }
  }
  stdout.writeln('  total: ${permissoes.length} permissoes');

  // -------------------------------------------------------------------------
  // conteudo do bundle
  // -------------------------------------------------------------------------
  _secao('conteudo do bundle');
  final zip = ZipDecoder().decodeBytes(aab.readAsBytesSync());
  final nomes = zip.files.where((f) => f.isFile).map((f) => f.name).toList();
  stdout.writeln('  entradas no bundle: ${nomes.length}');

  int contem(String agulha) => nomes.where((n) => n.contains(agulha)).length;

  void exigir(String rotulo, String agulha, {int minimo = 1}) {
    final n = contem(agulha);
    final ok = n >= minimo;
    stdout.writeln('  ${ok ? 'OK   ' : 'FALHA'} $rotulo: $n entrada(s) ($agulha)');
    if (!ok) falhas.add('$rotulo ausente do bundle');
  }

  exigir('launcher icon (mipmap)', 'res/mipmap', minimo: 5);
  exigir('assets do app', 'assets/flutter_assets/assets/');
  exigir('baralho', 'assets/flutter_assets/assets/baralho/', minimo: 55);
  exigir('arte oficial do splash', 'assets/flutter_assets/assets/splash/');
  exigir('dex', 'dex/classes', minimo: 1);

  _secao('o launcher icon do artefato e a arte oficial');
  final icones = Directory(args.opcional('icone') ?? 'android/launcher-icon/res');
  if (!icones.existsSync()) {
    falhas.add('nao achei a arte de referencia em ${icones.path}');
  } else {
    for (final densidade in ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi']) {
      // O aapt2 renomeia a pasta para `mipmap-<densidade>-v4` no artefato.
      final noBundle = zip.files.firstWhereOrNull(
        (f) => f.name == 'base/res/mipmap-$densidade-v4/ic_launcher.png',
      );
      final noRepo = File('${icones.path}/mipmap-$densidade/ic_launcher.png');
      if (noBundle == null || !noRepo.existsSync()) {
        stdout.writeln('  FALHA $densidade: faltou o arquivo dos dois lados');
        falhas.add('icone $densidade ausente do artefato ou da referencia');
        continue;
      }
      final a = img.decodePng(Uint8List.fromList(noBundle.content as List<int>));
      final b = img.decodePng(noRepo.readAsBytesSync());
      final diferenca = _pixelsDiferentes(a, b);
      final ok = diferenca == 0;
      stdout.writeln('  ${ok ? 'OK   ' : 'FALHA'} $densidade '
          '${a?.width}x${a?.height} — $diferenca pixel(s) de diferenca');
      if (!ok) {
        falhas.add('o icone $densidade do artefato nao e a arte oficial');
      }
    }
    final adaptativo = zip.files.firstWhereOrNull(
      (f) => f.name == 'base/res/mipmap-anydpi-v26/ic_launcher.xml',
    );
    stdout.writeln(
      '  ${adaptativo != null ? 'OK   ' : 'FALHA'} adaptive icon (mipmap-anydpi-v26)',
    );
    if (adaptativo == null) falhas.add('adaptive icon ausente do artefato');
  }

  _secao('classes compiladas no dex');
  final dex = zip.files
      .where((f) => f.isFile && RegExp(r'dex/classes\d*\.dex$').hasMatch(f.name))
      .toList();
  if (dex.isEmpty) {
    falhas.add('nenhum arquivo .dex no bundle');
  } else {
    stdout.writeln('  ${dex.length} arquivo(s) de dex: '
        '${dex.map((f) => f.name.split('/').last).join(', ')}');
    final conteudoDex = dex.map((f) => f.content as List<int>).toList();
    classesExigidas.forEach((descritor, porque) {
      final onde = <String>[];
      for (var i = 0; i < dex.length; i++) {
        if (_contemBytes(conteudoDex[i], descritor)) {
          onde.add(dex[i].name.split('/').last);
        }
      }
      final ok = onde.isNotEmpty;
      stdout.writeln('  ${ok ? 'OK   ' : 'FALHA'} $descritor'
          '${ok ? ' -> ${onde.join(', ')}' : ''}');
      if (!ok) {
        stdout.writeln('        $porque');
        falhas.add('classe ausente do dex: $descritor');
      }
    });
  }

  _secao('nada de material de assinatura dentro do bundle');
  for (final proibido in ['key.properties', 'upload.jks', '.keystore', '.jks']) {
    final achados = nomes.where((n) => n.endsWith(proibido)).toList();
    if (achados.isEmpty) {
      stdout.writeln('  OK    nenhum $proibido empacotado');
    } else {
      stdout.writeln('  FALHA $achados');
      falhas.add('material de assinatura empacotado: $achados');
    }
  }

  _secao('o bundle esta assinado');
  final assinatura = nomes
      .where((n) =>
          n.startsWith('META-INF/') &&
          (n.endsWith('.RSA') || n.endsWith('.EC') || n.endsWith('.DSA')))
      .toList();
  if (assinatura.isEmpty) {
    falhas.add('nao ha bloco de assinatura em META-INF/');
    stdout.writeln('  FALHA sem bloco de assinatura');
  } else {
    stdout.writeln('  OK    ${assinatura.join(', ')}');
  }

  _secao('as dez maiores entradas do bundle');
  final porTamanho = zip.files.where((f) => f.isFile).toList()
    ..sort((a, b) => b.size.compareTo(a.size));
  for (final f in porTamanho.take(10)) {
    stdout.writeln('  ${_mb(f.size).padLeft(9)}  ${f.name}');
  }

  // -------------------------------------------------------------------------
  stdout.writeln('\n${'=' * 70}');
  if (falhas.isEmpty) {
    stdout.writeln('CONFERENCIA APROVADA — ${permissoes.length} permissoes, '
        '${nomes.length} entradas, ${_mb(aab.lengthSync())}');
    exit(0);
  }
  stdout.writeln('CONFERENCIA REPROVADA — ${falhas.length} problema(s):');
  for (final f in falhas) {
    stdout.writeln('  - $f');
  }
  exit(1);
}

List<String> _igual(String rotulo, String? obtido, String esperado) {
  final ok = obtido == esperado;
  stdout.writeln('  ${ok ? 'OK   ' : 'FALHA'} $rotulo = ${obtido ?? '(ausente)'}'
      '${ok ? '' : '  (esperado: $esperado)'}');
  return ok ? const [] : ['$rotulo = $obtido, esperado $esperado'];
}

String _mb(int bytes) => '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';

/// Procura o descritor da classe nos bytes crus do dex.
///
/// O dex guarda os nomes na tabela de strings em MUTF-8; para um descritor
/// ASCII como `Lcom/android/billingclient/api/BillingClient;` isso e byte a
/// byte igual ao UTF-8, entao a busca direta basta e evita trazer um parser de
/// dex (ou depender de `dexdump`, que nem sempre esta no PATH do runner).
bool _contemBytes(List<int> conteudo, String texto) {
  final agulha = utf8.encode(texto);
  final limite = conteudo.length - agulha.length;
  for (var i = 0; i <= limite; i++) {
    var bate = true;
    for (var j = 0; j < agulha.length; j++) {
      if (conteudo[i + j] != agulha[j]) {
        bate = false;
        break;
      }
    }
    if (bate) return true;
  }
  return false;
}

void _secao(String t) => stdout.writeln('\n--- $t ---');

Never _abortar(String mensagem) {
  stderr.writeln('ERRO: $mensagem');
  exit(1);
}

/// Numero de pixels em que as duas imagens diferem. -1 quando nem da para
/// comparar (falha de decodificacao ou dimensao diferente).
int _pixelsDiferentes(img.Image? a, img.Image? b) {
  if (a == null || b == null) return -1;
  if (a.width != b.width || a.height != b.height) return -1;
  var diferentes = 0;
  for (var y = 0; y < a.height; y++) {
    for (var x = 0; x < a.width; x++) {
      final p = a.getPixel(x, y);
      final q = b.getPixel(x, y);
      if (p.r != q.r || p.g != q.g || p.b != q.b || p.a != q.a) diferentes++;
    }
  }
  return diferentes;
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;

  T? firstWhereOrNull(bool Function(T) teste) {
    for (final e in this) {
      if (teste(e)) return e;
    }
    return null;
  }
}

class _Argumentos {
  _Argumentos(List<String> brutos) {
    for (final a in brutos) {
      final i = a.indexOf('=');
      if (a.startsWith('--') && i > 2) {
        _mapa[a.substring(2, i)] = a.substring(i + 1);
      }
    }
  }

  final Map<String, String> _mapa = {};

  String obrigatorio(String nome) {
    final v = _mapa[nome];
    if (v == null || v.isEmpty) _abortar('faltou o argumento --$nome=...');
    return v!;
  }

  String? opcional(String nome) => _mapa[nome];
}
