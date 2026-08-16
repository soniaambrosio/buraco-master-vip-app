// Gera o launcher icon oficial do Buraco Master VIP a partir da arte aprovada.
//
// FONTE (nao e redesenhada por este programa, apenas reamostrada):
//   app/assets/splash/logo_splash_oficial.webp — 1024x1024, RGBA, 100% opaca.
//
// SAIDA (arvore de recursos Android, versionada em android/launcher-icon/res):
//   mipmap-{m,h,xh,xxh,xxxh}dpi/ic_launcher.png ...... icone legado (API < 26)
//   mipmap-{...}/ic_launcher_foreground.png .......... camada de frente (API 26+)
//   mipmap-anydpi-v26/ic_launcher.xml ................ declaracao do adaptive icon
//   values/ic_launcher_background.xml ................ cor da camada de fundo
//   ../play-store-icon-512.png ....................... icone 512x512 da ficha da Play
//
// POR QUE O ADAPTIVE ICON E MONTADO ASSIM
//
// A arte oficial e um emblema circular sobre fundo quase preto, ocupando o
// quadrado inteiro. Um adaptive icon tem 108 unidades de lado, das quais o
// sistema exibe apenas as 72 centrais — o resto e reserva para o parallax e
// para o recorte da mascara (circulo, squircle, quadrado arredondado, gota).
//
// Jogar a arte inteira na camada de frente em bleed total faria a mascara comer
// o anel dourado externo do emblema. Entao a frente recebe a arte reduzida para
// exatamente 72/108 do quadro, centralizada, com o resto transparente: o
// emblema passa a coincidir com a area visivel, e nenhuma mascara o corta.
//
// O fundo e cor chapada amostrada dos proprios cantos da arte. Isso importa:
// como a arte tem fundo escuro proprio, uma cor de fundo diferente deixaria
// aparecer a borda quadrada da camada de frente contra o fundo. Amostrando a
// cor da arte, a emenda desaparece.
//
// O icone legado (API < 26) NAO leva esse tratamento: ali nao existe mascara
// nem camada, entao a arte entra quadrada e cheia, que e o enquadramento
// aprovado.
import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

/// Densidades do Android e o lado, em pixels, do icone legado em cada uma.
/// A base e 48dp (mdpi); as demais sao os multiplicadores canonicos.
const Map<String, int> _densidadesLegado = {
  'mdpi': 48,
  'hdpi': 72,
  'xhdpi': 96,
  'xxhdpi': 144,
  'xxxhdpi': 192,
};

/// O adaptive icon mede 108dp de lado — 2,25x o icone legado em cada densidade.
const Map<String, int> _densidadesAdaptive = {
  'mdpi': 108,
  'hdpi': 162,
  'xhdpi': 216,
  'xxhdpi': 324,
  'xxxhdpi': 432,
};

/// Fracao do quadro de 108 que a arte ocupa na camada de frente. 72/108 e a
/// area que o sistema realmente exibe.
const double _fracaoVisivel = 72 / 108;

void main(List<String> argumentos) {
  final raiz = _raizDoRepositorio();
  final fonte = File('${raiz.path}/app/assets/splash/logo_splash_oficial.webp');
  if (!fonte.existsSync()) {
    stderr.writeln('ERRO: arte oficial nao encontrada em ${fonte.path}');
    exit(1);
  }

  final arte = img.decodeImage(fonte.readAsBytesSync());
  if (arte == null) {
    stderr.writeln('ERRO: nao consegui decodificar ${fonte.path}');
    exit(1);
  }
  if (arte.width != arte.height) {
    stderr.writeln(
      'ERRO: a arte-fonte precisa ser quadrada (recebi ${arte.width}x${arte.height}). '
      'Recortar a arte NAO e trabalho deste programa — o enquadramento e decisao '
      'de design, e sai errado se for automatico.',
    );
    exit(1);
  }

  final fundo = _corDeFundo(arte);
  stdout.writeln('arte-fonte : ${fonte.path} (${arte.width}x${arte.height})');
  stdout.writeln('cor de fundo amostrada dos cantos: ${_hex(fundo)}');

  final res = Directory('${raiz.path}/android/launcher-icon/res');
  if (res.existsSync()) res.deleteSync(recursive: true);

  var gerados = 0;

  for (final entrada in _densidadesLegado.entries) {
    final destino = _arquivo(res, 'mipmap-${entrada.key}/ic_launcher.png');
    // `copyResize` cubico: a arte so diminui, e o cubico preserva melhor os
    // fios finos do filigrana dourado do que o padrao (linear).
    final icone = img.copyResize(
      arte,
      width: entrada.value,
      height: entrada.value,
      interpolation: img.Interpolation.cubic,
    );
    destino.writeAsBytesSync(img.encodePng(icone));
    gerados++;
  }

  for (final entrada in _densidadesAdaptive.entries) {
    final lado = entrada.value;
    final destino =
        _arquivo(res, 'mipmap-${entrada.key}/ic_launcher_foreground.png');
    destino.writeAsBytesSync(img.encodePng(_camadaDeFrente(arte, lado)));
    gerados++;
  }

  _arquivo(res, 'mipmap-anydpi-v26/ic_launcher.xml').writeAsStringSync(
    '<?xml version="1.0" encoding="utf-8"?>\n'
    '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
    '    <background android:drawable="@color/ic_launcher_background" />\n'
    '    <foreground android:drawable="@mipmap/ic_launcher_foreground" />\n'
    '</adaptive-icon>\n',
  );
  gerados++;

  _arquivo(res, 'values/ic_launcher_background.xml').writeAsStringSync(
    '<?xml version="1.0" encoding="utf-8"?>\n'
    '<resources>\n'
    '    <color name="ic_launcher_background">${_hex(fundo)}</color>\n'
    '</resources>\n',
  );
  gerados++;

  // Icone da ficha da Play: 512x512, PNG 32 bits, sem transparencia. A arte ja
  // e opaca, mas o achatamento contra a cor de fundo garante o requisito mesmo
  // se a arte-fonte ganhar alpha um dia.
  final ficha = img.copyResize(
    arte,
    width: 512,
    height: 512,
    interpolation: img.Interpolation.cubic,
  );
  final fichaOpaca = img.Image(width: 512, height: 512, numChannels: 4);
  img.fill(fichaOpaca, color: fundo);
  img.compositeImage(fichaOpaca, ficha);
  _arquivo(Directory('${raiz.path}/android/launcher-icon'),
          'play-store-icon-512.png')
      .writeAsBytesSync(img.encodePng(fichaOpaca));
  gerados++;

  stdout.writeln('arquivos gerados: $gerados');
  stdout.writeln('destino          : ${res.parent.path}');
}

/// Monta a camada de frente do adaptive icon: quadro [lado]x[lado] transparente
/// com a arte reduzida a 72/108 do quadro, centralizada.
img.Image _camadaDeFrente(img.Image arte, int lado) {
  final quadro = img.Image(width: lado, height: lado, numChannels: 4);
  // Sem `fill`: o quadro nasce com alpha 0, e e isso que o adaptive icon espera
  // da camada de frente — o que sobra do quadro precisa deixar o fundo passar.
  final visivel = math.max(1, (lado * _fracaoVisivel).round());
  final reduzida = img.copyResize(
    arte,
    width: visivel,
    height: visivel,
    interpolation: img.Interpolation.cubic,
  );
  final deslocamento = ((lado - visivel) / 2).round();
  img.compositeImage(quadro, reduzida, dstX: deslocamento, dstY: deslocamento);
  return quadro;
}

/// Media dos quatro cantos da arte. Serve como cor da camada de fundo.
img.Color _corDeFundo(img.Image arte) {
  final ultimo = arte.width - 1;
  final cantos = [
    arte.getPixel(0, 0),
    arte.getPixel(ultimo, 0),
    arte.getPixel(0, ultimo),
    arte.getPixel(ultimo, ultimo),
  ];
  int media(num Function(img.Pixel) canal) =>
      (cantos.map(canal).reduce((a, b) => a + b) / cantos.length).round();
  return img.ColorRgba8(media((p) => p.r), media((p) => p.g), media((p) => p.b), 255);
}

String _hex(img.Color c) =>
    '#${c.r.toInt().toRadixString(16).padLeft(2, '0')}'
            '${c.g.toInt().toRadixString(16).padLeft(2, '0')}'
            '${c.b.toInt().toRadixString(16).padLeft(2, '0')}'
        .toUpperCase()
        .replaceFirst('#', '#');

File _arquivo(Directory base, String caminhoRelativo) {
  final f = File('${base.path}/$caminhoRelativo');
  f.parent.createSync(recursive: true);
  return f;
}

/// Sobe a partir do diretorio atual ate achar a raiz do repositorio. Deixa o
/// programa funcionar tanto de `tools/icone` quanto da raiz.
Directory _raizDoRepositorio() {
  var dir = Directory.current;
  for (var i = 0; i < 6; i++) {
    if (Directory('${dir.path}/app/assets').existsSync() &&
        Directory('${dir.path}/.github').existsSync()) {
      return dir;
    }
    final pai = dir.parent;
    if (pai.path == dir.path) break;
    dir = pai;
  }
  stderr.writeln(
    'ERRO: nao localizei a raiz do repositorio a partir de ${Directory.current.path}',
  );
  exit(1);
}
