// endpoint_de_release.dart — a politica do endereco do servidor que entra no AAB.
//
// ---------------------------------------------------------------------------
// POR QUE ISTO EXISTE (OS PRE-HOM-BMV-RC1, bloqueador AMB-03)
//
// `EndpointServidor.urlConfigurada` (app/lib/services/endpoint_servidor.dart) e
// `String.fromEnvironment('BMV_SERVIDOR_URL')`, sem valor padrao, e o perfil
// release recusa endereco vazio. O `release-aab.yml` rodava
// `flutter build appbundle --release` SEM `--dart-define`: todo AAB saia sem
// servidor, abria, jogava Treino e caia em "endereco do servidor nao
// configurado" ao tentar o online. O `build.yml` (APK de teste) injeta o valor,
// entao nenhum teste de APK reproduzia o defeito.
//
// A correcao tem tres pecas, e esta e a do meio:
//
//   1. a FONTE do valor e um arquivo VERSIONADO
//      (`tools/android/release/servidor_url.txt`). Nao e variavel de repositorio
//      nem input do disparo: trocar o backend tem de trocar o commit, senao dois
//      AAB do mesmo SHA apontariam para servidores diferentes e a identidade da
//      candidata deixaria de fechar;
//   2. ANTES do build, [validarEndpointDeRelease] recusa o que nao pode ir para
//      um artefato de release — vazio, placeholder, local, sem TLS, com
//      credencial ou parametro, porta de desenvolvimento;
//   3. DEPOIS do build, [conferirEndpointNoAab] abre o `.aab` e prova que o
//      valor esta DENTRO do snapshot AOT (`libapp.so`) de cada ABI, e que
//      nenhum endereco local de WebSocket sobreviveu la dentro.
//
// A politica aqui e MAIS estreita que a do app (que aceita `https` e o
// normaliza para `wss`): o pipeline exige a forma canonica, porque e ela que se
// procura byte a byte no artefato.
// ---------------------------------------------------------------------------
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// Endereco recusado pela politica de release. A mensagem nao carrega segredo:
/// o endereco do servidor e publico.
class EndpointDeReleaseInvalido implements Exception {
  const EndpointDeReleaseInvalido(this.motivo);
  final String motivo;
  @override
  String toString() => 'EndpointDeReleaseInvalido: $motivo';
}

/// Hosts que so existem na maquina de quem desenvolve (mesmo conjunto do app).
const Set<String> hostsLocais = {
  'localhost',
  '127.0.0.1',
  '0.0.0.0',
  '::1',
  '::',
  '10.0.2.2',
  '10.0.3.2',
};

/// Sufixos reservados para rede local, documentacao ou teste (RFC 2606/6761/6762).
const List<String> sufixosReservados = [
  '.localhost',
  '.local',
  '.internal',
  '.lan',
  '.home',
  '.test',
  '.example',
  '.invalid',
];

/// Fragmentos que denunciam placeholder esquecido no lugar do valor real.
const List<String> marcasDePlaceholder = [
  'exemplo',
  'example',
  'placeholder',
  'changeme',
  'change-me',
  'seu-servidor',
  'your-server',
  'todo',
  'xxx',
  'dummy',
  'mock',
  'fake',
];

/// Le o conteudo do arquivo versionado: ignora linhas vazias e comentarios
/// (`#`), e exige EXATAMENTE uma linha de valor. Duas linhas de valor sao
/// ambiguidade — qual delas o build usaria? — e reprovam.
String lerArquivoDeEndpoint(String conteudo) {
  final valores = const LineSplitter()
      .convert(conteudo)
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty && !l.startsWith('#'))
      .toList();
  if (valores.isEmpty) {
    throw const EndpointDeReleaseInvalido(
      'o arquivo de endpoint nao tem valor — nenhum backend foi autorizado',
    );
  }
  if (valores.length > 1) {
    throw EndpointDeReleaseInvalido(
      'o arquivo de endpoint tem ${valores.length} valores; tem de ter exatamente um',
    );
  }
  return valores.single;
}

/// Valida o endereco para um artefato de release e devolve a forma canonica
/// (`wss://host` ou `wss://host/caminho`), que e a string que o build recebe e
/// que [conferirEndpointNoAab] procura depois.
String validarEndpointDeRelease(String bruto) {
  final texto = bruto.trim();
  if (texto.isEmpty) {
    throw const EndpointDeReleaseInvalido('endereco vazio');
  }
  if (texto != bruto || RegExp(r'\s').hasMatch(texto)) {
    throw const EndpointDeReleaseInvalido('endereco com espaco em branco');
  }
  if (RegExp(r'[<>{}$`"\\]').hasMatch(texto)) {
    throw const EndpointDeReleaseInvalido(
      'endereco com caractere de modelo/placeholder',
    );
  }
  final minusculo = texto.toLowerCase();
  for (final marca in marcasDePlaceholder) {
    if (minusculo.contains(marca)) {
      throw EndpointDeReleaseInvalido('endereco parece placeholder ("$marca")');
    }
  }

  final Uri url;
  try {
    url = Uri.parse(texto);
  } on FormatException {
    throw const EndpointDeReleaseInvalido('endereco invalido');
  }
  if (url.scheme != 'wss') {
    throw const EndpointDeReleaseInvalido(
      'o release exige wss:// (minusculo, com TLS)',
    );
  }
  if (!url.hasAuthority || url.host.isEmpty) {
    throw const EndpointDeReleaseInvalido('endereco sem host');
  }
  if (url.userInfo.isNotEmpty) {
    throw const EndpointDeReleaseInvalido('endereco com usuario/senha');
  }
  if (url.hasQuery || url.hasFragment) {
    throw const EndpointDeReleaseInvalido(
      'endereco com parametro ou fragmento',
    );
  }
  if (url.hasPort && url.port != 443) {
    throw EndpointDeReleaseInvalido(
      'porta ${url.port} num release (so a 443 padrao do wss e aceita)',
    );
  }

  final host = url.host.toLowerCase();
  if (hostsLocais.contains(host)) {
    throw EndpointDeReleaseInvalido('host local ($host)');
  }
  if (_ehIpLiteral(host)) {
    throw EndpointDeReleaseInvalido(
      'IP literal ($host) — o release aponta para um nome, nao para um IP',
    );
  }
  if (!host.contains('.')) {
    throw EndpointDeReleaseInvalido('host sem dominio ($host)');
  }
  for (final sufixo in sufixosReservados) {
    if (host.endsWith(sufixo)) {
      throw EndpointDeReleaseInvalido('dominio reservado ($host)');
    }
  }

  final caminho = url.path == '/' ? '' : url.path;
  return 'wss://$host$caminho';
}

bool _ehIpLiteral(String host) =>
    RegExp(r'^\d{1,3}(\.\d{1,3}){3}$').hasMatch(host) || host.contains(':');

/// Resultado da conferencia do endereco dentro do AAB.
class ConferenciaDoAab {
  ConferenciaDoAab(this.ocorrenciasPorAbi, this.enderecosWebSocket);

  /// `base/lib/<abi>/libapp.so` -> quantas vezes o endereco autorizado aparece.
  final Map<String, int> ocorrenciasPorAbi;

  /// Todos os literais `ws://`/`wss://` achados nos snapshots, para auditoria.
  final Set<String> enderecosWebSocket;
}

/// Abre o `.aab` e prova que [endpoint] (forma canonica) esta compilado no
/// snapshot AOT de CADA ABI empacotada, e que nenhum endereco de WebSocket com
/// host local sobreviveu no artefato.
ConferenciaDoAab conferirEndpointNoAab(Uint8List bytesDoAab, String endpoint) {
  final arquivo = ZipDecoder().decodeBytes(bytesDoAab);
  final snapshots = arquivo.files
      .where(
        (f) =>
            f.isFile && RegExp(r'^base/lib/[^/]+/libapp\.so$').hasMatch(f.name),
      )
      .toList();
  if (snapshots.isEmpty) {
    throw const EndpointDeReleaseInvalido(
      'o AAB nao tem base/lib/<abi>/libapp.so — nao e um build AOT de release',
    );
  }

  final agulha = ascii.encode(endpoint);
  final ocorrencias = <String, int>{};
  final enderecos = <String>{};
  for (final so in snapshots) {
    final bytes = so.readBytes();
    if (bytes == null) {
      throw EndpointDeReleaseInvalido('nao consegui ler ${so.name}');
    }
    ocorrencias[so.name] = _contar(bytes, agulha);
    enderecos.addAll(_literaisWebSocket(bytes));
  }

  final sem = ocorrencias.entries.where((e) => e.value == 0).map((e) => e.key);
  if (sem.isNotEmpty) {
    throw EndpointDeReleaseInvalido(
      'o endereco autorizado NAO esta compilado em: ${sem.join(', ')}',
    );
  }
  for (final e in enderecos) {
    final host = Uri.tryParse(e)?.host.toLowerCase() ?? '';
    if (hostsLocais.contains(host) ||
        sufixosReservados.any((s) => host.endsWith(s))) {
      throw EndpointDeReleaseInvalido(
        'endereco local de WebSocket dentro do artefato: $e',
      );
    }
  }
  return ConferenciaDoAab(ocorrencias, enderecos);
}

int _contar(Uint8List palheiro, List<int> agulha) {
  var n = 0;
  outer:
  for (var i = 0; i <= palheiro.length - agulha.length; i++) {
    for (var j = 0; j < agulha.length; j++) {
      if (palheiro[i + j] != agulha[j]) continue outer;
    }
    n++;
  }
  return n;
}

Set<String> _literaisWebSocket(Uint8List bytes) {
  // Le como latin1 (1 byte = 1 caractere) para que os offsets nao se desloquem.
  final texto = latin1.decode(bytes, allowInvalid: true);
  return RegExp(
    r'wss?://[A-Za-z0-9._~:/?#\[\]@!&()*+,;=%-]+',
  ).allMatches(texto).map((m) => m.group(0)!).toSet();
}
