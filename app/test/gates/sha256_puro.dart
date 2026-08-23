// OS 43.1 — SHA-256 em Dart puro, para o portão de batida natural do bot.
//
// POR QUE NÃO `package:crypto`
// O scaffold do CI (`flutter create` + `flutter pub add`) não declara `crypto`:
// ele só aparece como dependência TRANSITIVA do Firebase. Importar um pacote
// transitivo acende `depend_on_referenced_packages` no analyzer e, pior, faz o
// portão depender de uma árvore de dependências que ninguém fixou. Sessenta
// linhas de código fechado valem mais aqui do que um import emprestado.
//
// NORMALIZAÇÃO DE FIM DE LINHA — E POR QUE ELA NÃO ESCONDE NADA
// O repositório é editado no Windows com `core.autocrlf = true`: a árvore de
// trabalho tem CRLF e o blob do git tem LF. O CI roda em Linux, onde o mesmo
// arquivo chega com LF. Hashear os bytes crus daria digests diferentes para o
// MESMO conteúdo, e o portão reprovaria por causa do sistema operacional.
//
// Por isso o digest declarado é o dos bytes com todo `\r` que precede `\n`
// removido. Isso não apaga alteração nenhuma de conteúdo: qualquer caractere
// que não seja o CR de fim de linha continua entrando no hash, e um CR solto
// (sem `\n` depois) também entra.
library;

/// Remove o CR de sequências CRLF. CR solto é PRESERVADO — ele é conteúdo.
List<int> normalizarFimDeLinha(List<int> bytes) {
  final out = <int>[];
  for (var i = 0; i < bytes.length; i++) {
    if (bytes[i] == 0x0D && i + 1 < bytes.length && bytes[i + 1] == 0x0A) {
      continue;
    }
    out.add(bytes[i]);
  }
  return out;
}

const List<int> _k = <int>[
  0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, //
  0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
  0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
  0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
  0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc,
  0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
  0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7,
  0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
  0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
  0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
  0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3,
  0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
  0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5,
  0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
  0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
  0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
];

int _rotr(int x, int n) => ((x >> n) | (x << (32 - n))) & 0xFFFFFFFF;

/// SHA-256 dos bytes dados, em hexadecimal minúsculo (64 caracteres).
String sha256Hex(List<int> entrada) {
  final h = <int>[
    0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, //
    0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19,
  ];
  final msg = <int>[...entrada, 0x80];
  while (msg.length % 64 != 56) {
    msg.add(0);
  }
  final bits = entrada.length * 8;
  for (var i = 7; i >= 0; i--) {
    msg.add((bits >> (8 * i)) & 0xFF);
  }

  final w = List<int>.filled(64, 0);
  for (var bloco = 0; bloco < msg.length; bloco += 64) {
    for (var i = 0; i < 16; i++) {
      final j = bloco + i * 4;
      w[i] = (msg[j] << 24) | (msg[j + 1] << 16) | (msg[j + 2] << 8) | msg[j + 3];
    }
    for (var i = 16; i < 64; i++) {
      final s0 = _rotr(w[i - 15], 7) ^ _rotr(w[i - 15], 18) ^ (w[i - 15] >> 3);
      final s1 = _rotr(w[i - 2], 17) ^ _rotr(w[i - 2], 19) ^ (w[i - 2] >> 10);
      w[i] = (w[i - 16] + s0 + w[i - 7] + s1) & 0xFFFFFFFF;
    }
    var a = h[0], b = h[1], c = h[2], d = h[3];
    var e = h[4], f = h[5], g = h[6], hh = h[7];
    for (var i = 0; i < 64; i++) {
      final s1 = _rotr(e, 6) ^ _rotr(e, 11) ^ _rotr(e, 25);
      final ch = (e & f) ^ ((~e & 0xFFFFFFFF) & g);
      final t1 = (hh + s1 + ch + _k[i] + w[i]) & 0xFFFFFFFF;
      final s0 = _rotr(a, 2) ^ _rotr(a, 13) ^ _rotr(a, 22);
      final maj = (a & b) ^ (a & c) ^ (b & c);
      final t2 = (s0 + maj) & 0xFFFFFFFF;
      hh = g;
      g = f;
      f = e;
      e = (d + t1) & 0xFFFFFFFF;
      d = c;
      c = b;
      b = a;
      a = (t1 + t2) & 0xFFFFFFFF;
    }
    h[0] = (h[0] + a) & 0xFFFFFFFF;
    h[1] = (h[1] + b) & 0xFFFFFFFF;
    h[2] = (h[2] + c) & 0xFFFFFFFF;
    h[3] = (h[3] + d) & 0xFFFFFFFF;
    h[4] = (h[4] + e) & 0xFFFFFFFF;
    h[5] = (h[5] + f) & 0xFFFFFFFF;
    h[6] = (h[6] + g) & 0xFFFFFFFF;
    h[7] = (h[7] + hh) & 0xFFFFFFFF;
  }
  final sb = StringBuffer();
  for (final v in h) {
    sb.write(v.toRadixString(16).padLeft(8, '0'));
  }
  return sb.toString();
}

/// Digest CANÔNICO de um arquivo de texto do repositório: bytes normalizados.
String sha256DeTextoNormalizado(List<int> bytesDoArquivo) =>
    sha256Hex(normalizarFimDeLinha(bytesDoArquivo));
