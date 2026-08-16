// identidade_publica.dart — o identificador PÚBLICO do jogador (OS §3, §4 e §9).
//
// AS TRÊS IDENTIDADES QUE ESTE ARQUIVO SEPARA (§3):
//
//   UID Firebase ....... identidade INTERNA. É a chave de `users/{uid}`, o
//                        `request.auth.uid` das Rules e o alvo de sanção em
//                        `playerModeration/{uid}`. Nunca sai numa API pública.
//   publicId ........... identidade PÚBLICA. É o que um jogador usa para
//                        referenciar outro: perfil, ranking, hall, amizade.
//   apelido/avatar ..... APRESENTAÇÃO. Mora em apresentacao.dart, muda quando o
//                        jogador quiser, e NÃO é identidade — trocar o apelido
//                        não troca o publicId.
//
// ---------------------------------------------------------------------------
// O QUE JÁ EXISTIA, E POR QUE ESTE ARQUIVO REPETE O FORMATO EM VEZ DE INVENTAR
// OUTRO (§4)
// ---------------------------------------------------------------------------
//
// A OS de Ranking declarou uma identidade pública aleatória e ela existe de
// verdade — em `functions-ranking/src/identidade.ts`, na branch
// `claude/ranking-ligas-backend-auth-ea5ceb`. Ela NÃO está nesta árvore: a base
// desta OS (`homologacao/p0-integrada-a90557`) é anterior àquele trabalho, e §41
// proíbe tocar em `functions-ranking`.
//
// Isso deixa duas escolhas ruins e uma boa. As ruins seriam (a) depender de uma
// branch paralela em execução, ou (b) inventar um segundo formato — que é
// exatamente o `publicId2` que §4 proíbe. A boa é a terceira: ADOTAR O MESMO
// FORMATO, byte a byte, para que o dia da consolidação seja uma reconciliação de
// DADOS, e não uma quebra de contrato.
//
//   alfabeto ..... base32 de Crockford sem I, L, O e U — idêntico.
//   comprimento .. 12 símbolos (60 bits) — idêntico.
//   prefixo ...... "P" — idêntico.
//
// Um id gerado aqui é válido lá, e vice-versa. O que muda é QUEM guarda o mapa,
// e isso está documentado em docs/CONTRATO-IDENTIDADE-PUBLICA-SOCIAL.md.
//
// POR QUE NÃO O `BMV-XXXXXXXXXX` do exemplo de §9: a própria §9 diz que "o
// formato exato deve aproveitar a implementação existente, se houver". Há. Um
// prefixo diferente criaria duas gerações de id no mesmo sistema antes mesmo de
// o sistema existir.
//
// ---------------------------------------------------------------------------
// POR QUE ALEATÓRIO PERSISTIDO, e não derivado
// ---------------------------------------------------------------------------
//
//   hash(uid) .............. reversível por força bruta: UIDs do Firebase têm
//                            formato conhecido e alfabeto pequeno.
//   HMAC(uid, segredo) ..... resolve o ataque acima e cria outro problema —
//                            rotacionar a chave trocaria o id público de TODO
//                            MUNDO, e ids públicos entram em link de perfil.
//   sequencial ............. vaza ordem de cadastro e tamanho da base, e convida
//                            à enumeração ("existe o 41, então existe o 40").
//
// Aleatório persistido não tem nenhum dos três. O custo é que o mapa é a fonte
// da verdade e precisa sobreviver — e ele vive no Firestore, junto com todo o
// resto que precisa sobreviver.
//
// NADA AQUI LÊ RELÓGIO, FIRESTORE OU `Random`. Os bytes entram por parâmetro. É
// o que torna a geração testável de verdade: o teste passa bytes conhecidos e
// afirma o id resultante, em vez de afirmar só o formato.

import 'erros_sociais.dart';

/// Alfabeto do id público.
///
/// Base32 de Crockford SEM I, L, O e U. As três primeiras se confundem com 1 e 0
/// quando alguém lê um id em voz alta ou digita de um print — o que acontece em
/// suporte —, e o U sai para reduzir a chance de palavra ofensiva acidental num
/// id que aparece na tela do jogador.
const String kAlfabetoIdPublico = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';

/// Quantos símbolos do alfabeto compõem o corpo do id.
///
/// 12 símbolos de base32 são 60 bits. Pelo paradoxo do aniversário, a chance de
/// colisão passa de 1 em 1 milhão só depois de ~1,5 milhão de jogadores — e a
/// colisão, quando acontecer, é DETECTADA e não ignorada (a reserva do id é um
/// `create`, que falha se o documento já existir). O comprimento é generoso de
/// propósito: alargar depois obrigaria a conviver com duas gerações de id.
const int kComprimentoIdPublico = 12;

/// Prefixo legível. Serve ao suporte ("isto é id de jogador, não matchId") e não
/// entra na conta de entropia.
const String kPrefixoIdPublico = 'P';

/// Comprimento total do id público, com prefixo.
const int kTamanhoTotalIdPublico =
    kComprimentoIdPublico + 1; // 1 = kPrefixoIdPublico.length

/// Gera um id público a partir de bytes aleatórios.
///
/// Os BYTES vêm de fora, e não de um `Random` chamado aqui dentro. É o que torna
/// esta função pura: o teste passa bytes conhecidos e afirma o id.
///
/// `% 32` sobre um byte NÃO enviesa: 256 = 8 × 32, então cada símbolo do alfabeto
/// recebe exatamente 8 dos 256 valores possíveis. O mesmo truque com um alfabeto
/// de tamanho não-potência-de-dois precisaria de rejeição para não favorecer as
/// primeiras letras.
String idPublicoDeBytes(List<int> bytes) {
  if (bytes.length < kComprimentoIdPublico) {
    throw ArgumentError.value(
      bytes.length,
      'bytes',
      'id público precisa de $kComprimentoIdPublico bytes',
    );
  }
  final buffer = StringBuffer(kPrefixoIdPublico);
  for (var i = 0; i < kComprimentoIdPublico; i++) {
    buffer.write(kAlfabetoIdPublico[(bytes[i] & 0xFF) % kAlfabetoIdPublico.length]);
  }
  return buffer.toString();
}

/// O valor tem a forma de um id público?
///
/// Usado na LEITURA, antes de gastar uma consulta: um id malformado vindo do
/// cliente é recusado sem tocar o banco, o que fecha a porta da enumeração por
/// tentativa barata.
bool idPublicoValido(Object? valor) {
  if (valor is! String) return false;
  if (valor.length != kTamanhoTotalIdPublico) return false;
  if (!valor.startsWith(kPrefixoIdPublico)) return false;
  for (final c in valor.substring(kPrefixoIdPublico.length).split('')) {
    if (!kAlfabetoIdPublico.contains(c)) return false;
  }
  return true;
}

/// Mapa de reparo de digitação, na tradição do Crockford.
///
/// I, L e O não pertencem ao alfabeto justamente porque se parecem com 1 e 0.
/// Quem digita um id lido de um print vai errar exatamente assim — e recusar a
/// entrada seria punir o jogador por um problema que o alfabeto criou para
/// proteger o próprio jogador.
///
/// O `U` NÃO tem reparo: ele foi excluído por outro motivo (palavra acidental) e
/// não se parece com nada do alfabeto. `U` digitado é entrada inválida mesmo.
const Map<String, String> _reparoDeDigitacao = {
  'I': '1',
  'L': '1',
  'O': '0',
};

/// Normaliza um id público vindo do cliente (§9, "normalização case-insensitive
/// para entrada").
///
/// Devolve `null` quando não sobra um id válido — e é `null`, e não exceção,
/// porque entrada malformada de cliente é caso comum, não defeito de programa.
///
/// O que faz, nesta ordem: apara espaços, remove hífens e espaços internos (quem
/// copia de um print agrupa em blocos), sobe para maiúsculas e repara I/L/O.
///
/// O QUE NÃO FAZ: aceitar um id que só fique válido depois de "chutar" um
/// símbolo faltante. Reparo é de forma, não de conteúdo.
String? normalizarIdPublico(Object? bruto) {
  if (bruto is! String) return null;
  final semRuido = bruto.replaceAll(RegExp(r'[\s\-]'), '').toUpperCase();
  if (semRuido.isEmpty) return null;

  final buffer = StringBuffer();
  for (final c in semRuido.split('')) {
    buffer.write(_reparoDeDigitacao[c] ?? c);
  }
  final candidato = buffer.toString();
  return idPublicoValido(candidato) ? candidato : null;
}

/// Um `publicId` poderia ter sido derivado deste `uid`?
///
/// Existe para o TESTE, e não para o caminho de produção: §36 exige provar que
/// "publicId não deriva do UID", e uma afirmação dessas precisa de um predicado
/// concreto para ser verificável. Responde true se o corpo do id aparece dentro
/// do uid (ou o contrário), ignorando caixa — que é a forma como um "derivado
/// preguiçoso" (prefixo, sufixo, fatia) se pareceria.
///
/// Não é prova criptográfica de independência, e não pretende ser: é a rede que
/// pega o erro real, que seria alguém trocar a geração aleatória por
/// `uid.substring(0, 12)` numa refatoração futura.
bool pareceDerivadoDoUid(String publicId, String uid) {
  final corpo = publicId.startsWith(kPrefixoIdPublico)
      ? publicId.substring(kPrefixoIdPublico.length)
      : publicId;
  final u = uid.toUpperCase();
  final c = corpo.toUpperCase();
  if (c.isEmpty || u.isEmpty) return false;
  return u.contains(c) || c.contains(u);
}

/// Estado de exposição de um perfil público (§31-G).
enum EstadoPerfilPublico {
  /// Perfil normal, exposto a quem consultar.
  ativo,

  /// Conta desativada ou removida. O documento continua existindo — apagá-lo
  /// deixaria a amizade apontando para um vazio, e §32 pede "consultas não
  /// quebradas" —, mas ele não é mais exposto.
  indisponivel;

  bool get exponivel => this == EstadoPerfilPublico.ativo;

  static EstadoPerfilPublico porNome(Object? nome) {
    for (final e in EstadoPerfilPublico.values) {
      if (e.name == nome) return e;
    }
    // Estado desconhecido num documento gravado é tratado como INDISPONÍVEL, e
    // não como ativo. A postura conservadora é a única segura aqui: um estado
    // que este código não entende pode ser exatamente "banido", e expor por
    // desconhecimento seria o pior desfecho possível.
    return EstadoPerfilPublico.indisponivel;
  }
}

/// Por que uma consulta de identidade foi recusada — ou `null` se foi aceita.
///
/// A DISTINÇÃO ENTRE "não existe" E "não é exponível" MORRE NA BORDA. §31-G pede
/// "erro/estado de domínio estável" e §31-F proíbe revelar dado interno; se o
/// cliente conseguisse distinguir os dois, teria um oráculo de "este publicId já
/// pertenceu a alguém", que é meia enumeração de graça. Por isso a função que
/// resolve identidade para o CLIENTE dobra os dois em
/// [ErroSocial.perfilPublicoNaoDisponivel]; o código granular fica no log.
ErroSocial? recusaDeConsultaPublica({
  required Object? idBruto,
  required bool existe,
  required EstadoPerfilPublico estado,
}) {
  if (normalizarIdPublico(idBruto) == null) {
    return ErroSocial.perfilPublicoInvalido;
  }
  if (!existe || !estado.exponivel) {
    return ErroSocial.perfilPublicoNaoDisponivel;
  }
  return null;
}
