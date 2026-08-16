// sha256.dart — SHA-256 em Dart puro.
//
// Por que reimplementar em vez de usar `package:crypto`: o gate de identidade
// de build roda via `dart run`, FORA de qualquer pubspec (este repositório não
// versiona um — o projeto Flutter é montado pelo CI). Uma dependência de
// pacote aqui tornaria o gate dependente da mesma resolução de dependências
// que ele existe para auditar.
//
// Implementação de livro (FIPS 180-4), validada contra os vetores oficiais na
// suíte. Não é caminho quente: hasheia alguns artefatos por release.

import 'dart:convert';
import 'dart:typed_data';

const List<int> _k = <int>[
  0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1,
  0x923f82a4, 0xab1c5ed5, 0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
  0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174, 0xe49b69c1, 0xefbe4786,
  0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
  0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147,
  0x06ca6351, 0x14292967, 0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
  0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85, 0xa2bfe8a1, 0xa81a664b,
  0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
  0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a,
  0x5b9cca4f, 0x682e6ff3, 0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
  0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
];

const int _mascara = 0xffffffff;

int _rotr(int x, int n) => ((x >> n) | (x << (32 - n))) & _mascara;

/// SHA-256 de [dados], em hex minúsculo de 64 caracteres.
String sha256Hex(List<int> dados) {
  final h = <int>[
    0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
    0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19,
  ];

  // Preenchimento: 0x80, zeros, e o comprimento em bits como 64-bit big-endian.
  final bits = dados.length * 8;
  final preenchido = BytesBuilder()
    ..add(dados)
    ..addByte(0x80);
  while (preenchido.length % 64 != 56) {
    preenchido.addByte(0);
  }
  final cauda = ByteData(8)..setUint64(0, bits, Endian.big);
  preenchido.add(cauda.buffer.asUint8List());

  final msg = preenchido.toBytes();
  final w = Uint32List(64);

  for (var bloco = 0; bloco < msg.length; bloco += 64) {
    for (var i = 0; i < 16; i++) {
      final o = bloco + i * 4;
      w[i] = (msg[o] << 24) | (msg[o + 1] << 16) | (msg[o + 2] << 8) | msg[o + 3];
    }
    for (var i = 16; i < 64; i++) {
      final s0 = _rotr(w[i - 15], 7) ^ _rotr(w[i - 15], 18) ^ (w[i - 15] >> 3);
      final s1 = _rotr(w[i - 2], 17) ^ _rotr(w[i - 2], 19) ^ (w[i - 2] >> 10);
      w[i] = (w[i - 16] + s0 + w[i - 7] + s1) & _mascara;
    }

    var a = h[0], b = h[1], c = h[2], d = h[3];
    var e = h[4], f = h[5], g = h[6], hh = h[7];

    for (var i = 0; i < 64; i++) {
      final bigSigma1 = _rotr(e, 6) ^ _rotr(e, 11) ^ _rotr(e, 25);
      final ch = (e & f) ^ ((~e & _mascara) & g);
      final temp1 = (hh + bigSigma1 + ch + _k[i] + w[i]) & _mascara;
      final bigSigma0 = _rotr(a, 2) ^ _rotr(a, 13) ^ _rotr(a, 22);
      final maj = (a & b) ^ (a & c) ^ (b & c);
      final temp2 = (bigSigma0 + maj) & _mascara;

      hh = g;
      g = f;
      f = e;
      e = (d + temp1) & _mascara;
      d = c;
      c = b;
      b = a;
      a = (temp1 + temp2) & _mascara;
    }

    h[0] = (h[0] + a) & _mascara;
    h[1] = (h[1] + b) & _mascara;
    h[2] = (h[2] + c) & _mascara;
    h[3] = (h[3] + d) & _mascara;
    h[4] = (h[4] + e) & _mascara;
    h[5] = (h[5] + f) & _mascara;
    h[6] = (h[6] + g) & _mascara;
    h[7] = (h[7] + hh) & _mascara;
  }

  final sb = StringBuffer();
  for (final v in h) {
    sb.write(v.toRadixString(16).padLeft(8, '0'));
  }
  return sb.toString();
}

/// SHA-256 de um texto UTF-8.
String sha256DoTexto(String texto) => sha256Hex(utf8.encode(texto));
