// colecao_arte.dart — de onde vem a arte de um item de colecao.
//
// Camada pura: sem Flutter, sem rede, sem disco. Este arquivo descreve a FONTE
// da arte e o contrato de quem a resolve; quem baixa, cacheia ou desenha vem
// depois.
//
// POR QUE ISTO EXISTE
// O Kit Pioneiros 2026 mora inteiro no bundle, e vai continuar assim. Mas uma
// colecao futura pode ser grande demais para embarcar — 26 MiB por colecao nao
// escala — e vai precisar vir de armazenamento remoto, com cache local e
// verificacao de integridade.
//
// Trocar isso depois seria caro se o catalogo guardasse apenas um caminho de
// arquivo: cada tela, cada teste e cada documento de inventario passaria a ter
// duas formas de achar a mesma imagem. Modelar a fonte desde agora custa pouco e
// mantem uma promessa importante: **o `itemId` nao muda quando a origem muda**.
// Uma peca que hoje vem do bundle e amanha vem da rede continua sendo o mesmo
// item no inventario de quem ja a possui.

import 'dart:convert';

/// De onde a arte vem.
enum TipoFonteArte {
  /// Empacotada no aplicativo (`assets/...`). Disponivel offline, sem download.
  bundle('bundle'),

  /// Baixada sob demanda e mantida em cache local.
  remota('remota');

  final String wire;
  const TipoFonteArte(this.wire);
}

/// Descreve onde encontrar a arte de um item e como confirmar que ela chegou
/// inteira.
class FonteArte {
  final TipoFonteArte tipo;

  /// Caminho no bundle Flutter. Preenchido apenas em [TipoFonteArte.bundle].
  final String? assetPath;

  /// Endereco remoto. Preenchido apenas em [TipoFonteArte.remota].
  final String? url;

  /// SHA-256 do arquivo. Obrigatorio em fonte remota — sem ele nao ha como
  /// distinguir download truncado de arquivo integro, e um PNG pela metade vira
  /// card quebrado em producao.
  ///
  /// Opcional em fonte de bundle, onde o portao de integridade do CI ja compara
  /// cada arte com o manifesto antes de empacotar.
  final String? sha256;

  /// Tamanho esperado em bytes, quando conhecido. Permite barra de progresso e
  /// recusa antecipada por falta de espaco.
  final int? bytes;

  const FonteArte._({
    required this.tipo,
    this.assetPath,
    this.url,
    this.sha256,
    this.bytes,
  });

  /// Arte empacotada no aplicativo.
  factory FonteArte.bundle(String assetPath, {String? sha256, int? bytes}) {
    if (assetPath.isEmpty) {
      throw ArgumentError.value(assetPath, 'assetPath', 'nao pode ser vazio');
    }
    return FonteArte._(
      tipo: TipoFonteArte.bundle,
      assetPath: assetPath,
      sha256: sha256,
      bytes: bytes,
    );
  }

  /// Arte remota. Exige checksum: ver [sha256].
  factory FonteArte.remota({
    required String url,
    required String sha256,
    int? bytes,
  }) {
    if (url.isEmpty) {
      throw ArgumentError.value(url, 'url', 'nao pode ser vazio');
    }
    if (sha256.isEmpty) {
      throw ArgumentError.value(sha256, 'sha256', 'obrigatorio em fonte remota');
    }
    return FonteArte._(
      tipo: TipoFonteArte.remota,
      url: url,
      sha256: sha256,
      bytes: bytes,
    );
  }

  bool get ehBundle => tipo == TipoFonteArte.bundle;
  bool get ehRemota => tipo == TipoFonteArte.remota;

  /// Chave estavel de cache. Deriva da ORIGEM, nunca do `itemId`: dois itens
  /// podem, no futuro, apontar para o mesmo arquivo, e o cache deve guardar uma
  /// copia so.
  String get chaveCache => ehBundle ? 'bundle:$assetPath' : 'remota:$url';

  /// Le a forma nova (`arte: {...}`) ou a antiga (`assetPath: "..."`).
  ///
  /// A forma antiga continua valendo de proposito: o seed do Kit Pioneiros foi
  /// escrito assim e nao ha razao para reescreve-lo so por causa do formato.
  /// Quando so ha `assetPath`, a origem e bundle.
  factory FonteArte.fromJson(Map<String, dynamic> json, String contexto) {
    final arte = json['arte'];
    if (arte == null) {
      final assetPath = json['assetPath'];
      if (assetPath is! String || assetPath.isEmpty) {
        throw FormatException('$contexto: informe `arte` ou `assetPath`.');
      }
      return FonteArte.bundle(assetPath);
    }
    if (arte is! Map<String, dynamic>) {
      throw FormatException('$contexto: `arte` deve ser objeto.');
    }
    if (json['assetPath'] != null) {
      throw FormatException('$contexto: use `arte` OU `assetPath`, nunca os dois.');
    }

    final wire = arte['tipo'];
    if (wire is! String) {
      throw FormatException('$contexto: `arte.tipo` deve ser string.');
    }

    switch (wire) {
      case 'bundle':
        final assetPath = arte['assetPath'];
        if (assetPath is! String || assetPath.isEmpty) {
          throw FormatException('$contexto: arte bundle exige assetPath.');
        }
        return FonteArte.bundle(
          assetPath,
          sha256: arte['sha256'] as String?,
          bytes: arte['bytes'] as int?,
        );
      case 'remota':
        final url = arte['url'];
        final sha = arte['sha256'];
        if (url is! String || url.isEmpty) {
          throw FormatException('$contexto: arte remota exige url.');
        }
        if (sha is! String || sha.isEmpty) {
          throw FormatException('$contexto: arte remota exige sha256.');
        }
        return FonteArte.remota(url: url, sha256: sha, bytes: arte['bytes'] as int?);
      default:
        throw FormatException('$contexto: `arte.tipo` desconhecido "$wire".');
    }
  }

  Map<String, dynamic> toJson() => {
        'tipo': tipo.wire,
        'assetPath': ?assetPath,
        'url': ?url,
        'sha256': ?sha256,
        'bytes': ?bytes,
      };

  @override
  String toString() => 'FonteArte($chaveCache)';
}

/// Arte pronta para ser exibida.
class ArteResolvida {
  /// Identificador que a camada de imagem usa. Em bundle e o proprio
  /// `assetPath`; numa implementacao remota sera o caminho do arquivo em cache.
  final String referencia;

  /// true quando veio do bundle (ou do cache) sem tocar a rede.
  final bool local;

  const ArteResolvida({required this.referencia, required this.local});
}

/// Por que a arte nao pode ser exibida.
class FalhaArte implements Exception {
  final String itemId;
  final String motivo;

  const FalhaArte(this.itemId, this.motivo);

  @override
  String toString() => 'FalhaArte($itemId): $motivo';
}

/// Quem transforma uma [FonteArte] em algo exibivel.
///
/// A camada visual depende DESTA interface, e nao de `assetPath` direto. E o que
/// permite trocar bundle por remoto sem tocar em tela, catalogo ou inventario.
abstract interface class ResolvedorDeArte {
  Future<ArteResolvida> resolver(String itemId, FonteArte fonte);

  /// Antecipa a arte sem exibi-la — o carrossel usa isto para preparar o
  /// proximo item. Implementacoes locais podem nao fazer nada.
  Future<void> preparar(String itemId, FonteArte fonte);
}

/// Resolvedor para arte empacotada. Nao toca em rede nem em disco: o bundle ja
/// esta no aplicativo.
///
/// Recusa fonte remota de proposito, em vez de devolver algo pela metade: se uma
/// colecao remota chegar antes do resolvedor remoto existir, o erro aparece na
/// hora e nao como imagem vazia.
class ResolvedorBundle implements ResolvedorDeArte {
  const ResolvedorBundle();

  @override
  Future<ArteResolvida> resolver(String itemId, FonteArte fonte) async {
    if (!fonte.ehBundle) {
      throw FalhaArte(itemId, 'fonte remota exige um resolvedor com cache; ver ResolvedorDeArte');
    }
    return ArteResolvida(referencia: fonte.assetPath!, local: true);
  }

  @override
  Future<void> preparar(String itemId, FonteArte fonte) async {
    if (!fonte.ehBundle) {
      throw FalhaArte(itemId, 'fonte remota exige um resolvedor com cache; ver ResolvedorDeArte');
    }
  }
}

/// Contrato do cache que um resolvedor remoto vai precisar.
///
/// Declarado agora, sem implementacao, para que a forma da solucao ja esteja
/// acordada: guarda por [FonteArte.chaveCache], confere o SHA-256 ANTES de dar o
/// arquivo por bom, e descarta o que nao bater.
abstract interface class CacheDeArte {
  Future<String?> buscar(String chaveCache);

  /// Grava e devolve a referencia local. Deve recusar bytes cujo SHA-256 nao
  /// bata com [sha256Esperado].
  Future<String> guardar(String chaveCache, List<int> bytes, String sha256Esperado);

  Future<void> remover(String chaveCache);
}

/// Utilitario de leitura de manifesto para quem for construir o resolvedor
/// remoto: converte a lista de itens do catalogo em fontes.
Map<String, FonteArte> fontesDoJson(String source, String contexto) {
  final raiz = jsonDecode(source);
  if (raiz is! Map<String, dynamic>) {
    throw FormatException('$contexto: raiz deve ser objeto.');
  }
  final fontes = <String, FonteArte>{};
  for (final bruto in (raiz['itens'] as List? ?? const [])) {
    final item = bruto as Map<String, dynamic>;
    final itemId = item['itemId'] as String;
    fontes[itemId] = FonteArte.fromJson(item, '$contexto/$itemId');
  }
  return fontes;
}
