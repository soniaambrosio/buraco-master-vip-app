// validacao.dart — o que conta como identificador, texto e instante aceitáveis.
//
// Fica num arquivo só porque as três frentes da moderação (denúncia, bloqueio,
// silêncio) validam as MESMAS coisas. Uma segunda definição de "uid válido"
// divergiria da primeira no dia em que alguém apertasse o limite num lugar só —
// e a que ficasse frouxa seria justamente a porta.
//
// Nada aqui lê relógio, Firestore ou rede: é decisão pura. É por isso que o
// teste do domínio roda sem emulador, e é por isso que o mesmo código pode valer
// no cliente (para não deixar o jogador escrever 3 mil caracteres à toa) e no
// servidor (que é quem decide de verdade).

/// Tamanho máximo do comentário livre de uma denúncia.
///
/// O limite existe menos por armazenamento e mais por superfície: campo de texto
/// sem teto é onde se cola um payload inteiro para tentar sair pelo outro lado.
const int kLimiteComentario = 500;

/// Tamanho máximo de qualquer identificador vindo do cliente.
///
/// UIDs do Firebase têm 28 caracteres; o folga cobre ids de mensagem e de mesa
/// sem virar campo livre.
const int kLimiteIdentificador = 128;

/// Separador das chaves de idempotência compostas.
///
/// Mesmo caractere que `functions/src/index.ts` já usa nas chaves de torneio. Um
/// identificador que o contivesse quebraria a chave em dois campos e deixaria
/// dois pedidos diferentes colidirem na mesma chave — por isso ele é proibido
/// DENTRO dos componentes, e não apenas escapado na hora de juntar.
const String kSeparadorChave = '|';

/// Um identificador é aceitável?
///
/// A regra é restritiva de propósito: letras, dígitos, `-` e `_`. Barra ficaria
/// de fora mesmo sem esta lista, porque o Firestore a lê como separador de
/// caminho, e um id com `../` viraria escrita fora da coleção pretendida.
bool identificadorValido(Object? v) {
  if (v is! String) return false;
  if (v.isEmpty || v.length > kLimiteIdentificador) return false;
  if (v.contains(kSeparadorChave)) return false;
  return RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(v);
}

/// Texto opcional já aparado. Devolve `null` quando não sobra conteúdo.
///
/// Espaço em branco puro vira `null` em vez de string vazia para que o registro
/// não guarde um campo que só parece preenchido.
String? textoOpcional(Object? v) {
  if (v is! String) return null;
  final t = v.trim();
  return t.isEmpty ? null : t;
}

/// O texto cabe no limite?
bool textoCabe(String? t, [int limite = kLimiteComentario]) =>
    t == null || t.length <= limite;

/// Exige instante com fuso e devolve em UTC.
///
/// Mesma postura do domínio de torneios: data sem fuso é recusada em vez de
/// interpretada como local. Duas máquinas em fusos diferentes gravariam
/// instantes distintos para o mesmo fato, e a janela de expiração de uma sanção
/// passaria a depender de onde o processo rodou.
DateTime exigirUtc(DateTime t, String campo) {
  if (!t.isUtc) {
    throw ArgumentError.value(t, campo, 'instante precisa estar em UTC');
  }
  return t;
}

/// Junta componentes numa chave de idempotência determinista.
///
/// Recusa componente inválido em vez de escapá-lo: escapar esconderia o defeito
/// e deixaria a chave depender de uma regra de escape que ninguém revisaria.
String chaveComposta(List<String> partes) {
  for (final p in partes) {
    if (!identificadorValido(p)) {
      throw ArgumentError.value(p, 'parte', 'componente de chave inválido');
    }
  }
  return partes.join(kSeparadorChave);
}
