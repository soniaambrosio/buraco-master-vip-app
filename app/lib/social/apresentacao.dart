// apresentacao.dart — apelido, avatar e O DOCUMENTO PÚBLICO (OS §5 a §8, §31-F).
//
// A REGRA QUE GOVERNA ESTE ARQUIVO INTEIRO, e que vem de §5: o Firestore não
// projeta campo por regra de segurança. Uma regra libera ou nega o DOCUMENTO
// INTEIRO. Logo, "campo público" e "documento público" são a mesma coisa: se um
// e-mail encostar no documento de perfil, ele está publicado — não importa que
// nenhuma tela o desenhe.
//
// Por isso [PerfilPublico] não é um DTO de conveniência. Ele é a definição
// executável de "o que pode ser lido por qualquer jogador", e
// [conferirDocumentoPublico] é a trava que o servidor aciona ANTES de gravar.
// Um campo novo só chega ao documento público passando por [camposPublicos] — e
// quem acrescentar um campo lá tem que olhar para a lista de proibidos que está
// logo abaixo.
//
// A MESMA disciplina que a moderação já aplicou ao separar `reports/` (registro
// administrativo) de `users/{uid}/reportReceipts` (comprovante do denunciante):
// dois documentos, porque não há como esconder metade de um.

import 'erros_sociais.dart';
import 'identidade_publica.dart';

// ===========================================================================
// APELIDO (§7)
// ===========================================================================

/// Mínimo de caracteres VISÍVEIS do apelido.
const int kApelidoMinimo = 3;

/// Máximo de caracteres VISÍVEIS do apelido.
///
/// "Visíveis" conta runas, não unidades UTF-16: um apelido com emoji ou com
/// acento composto ocuparia o dobro de `String.length` e seria recusado por um
/// limite que o jogador não consegue enxergar.
const int kApelidoMaximo = 24;

/// Caracteres que são recusados mesmo estando "dentro do limite".
///
/// Não é purismo tipográfico. Cada faixa aqui tem um abuso concreto:
///
///   C0/C1 ................. controles. `\n` num apelido quebra o layout de
///                           qualquer lista e polui log de servidor.
///   U+200B..U+200F ........ espaços de largura zero e marcas direcionais. É o
///                           truque clássico de impersonação: dois apelidos que
///                           se desenham idênticos e são strings diferentes.
///   U+202A..U+202E ........ overrides de bidirecionalidade. Invertem a ordem
///                           visual do texto seguinte — dá para desenhar um
///                           apelido que PARECE ser o de outra pessoa.
///   U+2060..U+2064, U+FEFF  juntadores invisíveis, mesma família do anterior.
///   U+2066..U+2069 ........ isolamentos direcionais, idem.
///
/// Espaço comum (U+0020) NÃO está aqui de propósito: apelido com espaço é
/// legítimo ("Dona Maria"). O que se faz com ele é colapsar, não proibir.
bool _caractereProibido(int rune) {
  if (rune < 0x20) return true; // C0
  if (rune == 0x7F) return true; // DEL
  if (rune >= 0x80 && rune <= 0x9F) return true; // C1
  if (rune >= 0x200B && rune <= 0x200F) return true;
  if (rune >= 0x202A && rune <= 0x202E) return true;
  if (rune >= 0x2060 && rune <= 0x2064) return true;
  if (rune >= 0x2066 && rune <= 0x2069) return true;
  if (rune == 0xFEFF) return true;
  return false;
}

/// Há caractere proibido neste texto?
///
/// Extraída de [recusaDeApelido] para que a BUSCA por apelido aplique o mesmo
/// crivo à consulta que a gravação aplica ao apelido — ver `busca_apelido.dart`.
/// Um termo de busca com override de bidirecionalidade ou espaço de largura zero
/// nunca casaria com apelido nenhum (a gravação já os recusa), mas recusá-lo na
/// entrada é o que impede que ele chegue ao banco disfarçado de consulta.
bool temCaractereProibido(String texto) => texto.runes.any(_caractereProibido);

/// Normaliza um apelido: apara as bordas e colapsa espaços consecutivos (§7).
///
/// NÃO recusa nada — normalizar e validar são passos separados de propósito. O
/// servidor normaliza primeiro e valida DEPOIS, porque `"  Ana  "` é um apelido
/// perfeitamente válido que só precisava de um trim, e recusá-lo por causa dos
/// espaços seria hostilidade gratuita com quem usa teclado de celular.
///
/// O que colapsa é qualquer sequência de espaço/tabulação, para um único espaço.
String normalizarApelido(String bruto) =>
    bruto.trim().replaceAll(RegExp(r'[ \t]+'), ' ');

/// Quantos caracteres visíveis tem o apelido já normalizado.
int comprimentoVisivel(String apelido) => apelido.runes.length;

/// O apelido normalizado é aceitável? Devolve `null` quando sim.
///
/// Recebe o texto JÁ NORMALIZADO. Chamar com o texto bruto faria `"  ab  "`
/// passar pelo mínimo por causa dos espaços.
ErroSocial? recusaDeApelido(String apelidoNormalizado) {
  if (apelidoNormalizado.isEmpty) return ErroSocial.apelidoInvalido;
  if (temCaractereProibido(apelidoNormalizado)) return ErroSocial.apelidoInvalido;
  final n = comprimentoVisivel(apelidoNormalizado);
  if (n < kApelidoMinimo || n > kApelidoMaximo) {
    return ErroSocial.apelidoInvalido;
  }
  return null;
}

/// Dobras de acento usadas na chave de ordenação.
///
/// Escrita à mão, e não com `unorm`/ICU, porque o único consumidor é a ORDENAÇÃO
/// da lista de amigos e o alfabeto real dos jogadores é o português. Puxar uma
/// dependência de normalização Unicode inteira para ordenar 200 nomes seria
/// pagar caro por um problema que não se tem.
const Map<String, String> _dobraDeAcento = {
  'á': 'a', 'à': 'a', 'ã': 'a', 'â': 'a', 'ä': 'a', 'å': 'a',
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
  'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
  'ó': 'o', 'ò': 'o', 'õ': 'o', 'ô': 'o', 'ö': 'o',
  'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
  'ç': 'c', 'ñ': 'n', 'ý': 'y',
};

/// Chave de ordenação do apelido (§22: "por apelido normalizado").
///
/// Minúsculas + acento dobrado, para que "Ávila" caia ao lado de "Avila" e não
/// depois de "Zeca" — que é onde a ordenação por ponto de código o colocaria.
///
/// NÃO é identidade e NÃO é exibida: o que aparece na tela é o [PerfilPublico.apelido]
/// original, com acento e caixa. Esta chave só existe para comparar.
String chaveDeOrdenacao(String apelido) {
  final buffer = StringBuffer();
  for (final c in apelido.toLowerCase().split('')) {
    buffer.write(_dobraDeAcento[c] ?? c);
  }
  return buffer.toString();
}

// ===========================================================================
// AVATAR (§8)
// ===========================================================================

/// Formato aceito para uma referência de avatar.
///
/// Minúsculas, dígitos, `-` e `_`, de 3 a 64 caracteres. O alfabeto exclui
/// exatamente os caracteres que apareceriam nas quatro coisas que §8 proíbe:
///
///   `:` e `/` .... URL externa arbitrária e caminho de arquivo
///   `<` e `>` .... HTML
///   `.` .......... caminho relativo (`../`) e extensão de arquivo
///   espaço ....... payload livre
///
/// Ou seja: a recusa não depende de uma lista de coisas ruins que alguém precisa
/// lembrar de manter. Depende de uma lista de coisas boas, que é curta.
final RegExp kFormatoAvatarRef = RegExp(r'^[a-z0-9][a-z0-9_-]{2,63}$');

/// O catálogo canônico de avatares AINDA NÃO EXISTE nesta árvore, e isto está
/// registrado em vez de contornado (§8: "Se ainda não houver fonte canônica
/// apropriada: usar campo nullable/ausente e documentar").
///
/// O que existe é o catálogo de COLEÇÕES (`app/data/colecoes/catalogo.seed.json`),
/// e os slots dele são `mascote`, `efeito`, `coroa`, `emblema` e `vitrine` — não
/// há slot de avatar. `app/lib/services/perfil_service.dart` desenha o avatar
/// como um emoji fixo (`'👑'`), que é placeholder de tela, não fonte canônica.
///
/// Enquanto esta constante estiver vazia, [recusaDeAvatar] valida só o FORMATO.
/// No dia em que houver catálogo, basta preencher: a validação passa a exigir
/// pertencimento sem que nenhuma chamada mude.
const Set<String> kCatalogoAvatares = <String>{};

/// A referência de avatar é aceitável? Devolve `null` quando sim.
///
/// `null` de entrada é ACEITO: §8 manda tratar a ausência, e um jogador sem
/// avatar escolhido é o estado normal de quem acabou de criar a conta.
ErroSocial? recusaDeAvatar(
  Object? avatarRef, {
  Set<String> catalogo = kCatalogoAvatares,
}) {
  if (avatarRef == null) return null;
  if (avatarRef is! String) return ErroSocial.avatarInvalido;
  if (!kFormatoAvatarRef.hasMatch(avatarRef)) return ErroSocial.avatarInvalido;
  if (catalogo.isNotEmpty && !catalogo.contains(avatarRef)) {
    return ErroSocial.avatarInvalido;
  }
  return null;
}

// ===========================================================================
// O DOCUMENTO PÚBLICO (§5, §6, §31-E, §31-F)
// ===========================================================================

/// Os ÚNICOS campos que podem existir no documento público.
///
/// Lista fechada, e usada de verdade: [conferirDocumentoPublico] recusa
/// qualquer chave fora dela. Acrescentar um campo aqui é uma decisão de produto
/// sobre exposição, não um detalhe de implementação.
const Set<String> camposPublicos = {
  'publicId',
  'apelido',
  'apelidoOrdenacao',
  'avatarRef',
  'estado',
  'criadoEm',
  'atualizadoEm',
  'esquema',
};

/// Campos cuja presença no documento público é DEFEITO GRAVE, e não descuido.
///
/// A lista existe para que o erro tenha nome quando aparecer. Ela é uma rede
/// sobre [camposPublicos], não a regra principal: a regra é a lista fechada de
/// permitidos, que já recusaria qualquer um destes. Manter as duas custa nada e
/// faz a mensagem de erro dizer "isto é dado privado" em vez de "campo
/// desconhecido" — a diferença entre alguém corrigir e alguém acrescentar à
/// lista de permitidos sem pensar.
///
/// Vem de §5 e §31-F, item por item.
const Set<String> camposProibidosNoPublico = {
  'uid', 'userId', 'ownerUid', 'donoUid',
  'email', 'emailVerified', 'telefone', 'phoneNumber',
  'token', 'idToken', 'refreshToken', 'providerId', 'providerData', 'claims',
  'vip', 'vipExpiraEm', 'billing', 'entitlement', 'entitlements', 'assinatura',
  'fichas', 'compras',
  'reports', 'denuncias', 'reportReceipts', 'sancoes', 'sanctions',
  'playerModeration', 'moderacao', 'suspensoAte', 'suspensaoPermanente',
  'endereco', 'cpf', 'documento', 'dataNascimento',
  'blocks', 'bloqueados', 'mutes',
};

/// Confere que um mapa pode ser gravado como documento público.
///
/// Devolve a lista de chaves ofensivas — vazia quando está tudo certo. Devolve
/// LISTA, e não booleano, porque o servidor precisa dizer no log QUAL campo
/// vazaria; um `false` mandaria alguém caçar.
///
/// Esta função é chamada pelo servidor antes de CADA escrita em `publicProfiles`.
/// Não é um teste: é uma trava em produção. O teste apenas prova que ela pega.
List<String> conferirDocumentoPublico(Map<String, Object?> documento) {
  final ofensivas = <String>[];
  for (final chave in documento.keys) {
    if (!camposPublicos.contains(chave)) ofensivas.add(chave);
  }
  ofensivas.sort();
  return ofensivas;
}

/// O perfil público de um jogador — a fonte ÚNICA de apelido e avatar (§31).
///
/// Perfil, Ranking, Hall e Amigos leem daqui. §31 pede exatamente isso: "não
/// criem quatro maneiras diferentes de descobrir apelido/avatar".
///
/// NÃO CARREGA UID. Não é omissão a ser corrigida: é a razão de a classe existir.
class PerfilPublico {
  /// A identidade pública. Imutável, e a chave do documento.
  final String publicId;

  /// Como o jogador quer aparecer. Já normalizado.
  final String apelido;

  /// Referência de avatar, ou `null` quando o jogador não escolheu (§8).
  final String? avatarRef;

  final EstadoPerfilPublico estado;

  /// Instantes em ISO-8601 UTC, gravados pelo servidor. Ficam no documento
  /// público porque "jogador desde" é informação de perfil, e não há nada de
  /// sensível em saber quando uma conta de jogo foi criada.
  final String criadoEm;
  final String atualizadoEm;

  const PerfilPublico({
    required this.publicId,
    required this.apelido,
    required this.avatarRef,
    required this.estado,
    required this.criadoEm,
    required this.atualizadoEm,
  });

  /// Chave de ordenação derivada. Gravada no documento por conveniência de
  /// leitura, e recalculada a cada escrita — nunca aceita do cliente.
  String get apelidoOrdenacao => chaveDeOrdenacao(apelido);

  /// A ÚNICA serialização de um perfil público.
  ///
  /// Se existir uma segunda em algum lugar, ela é o bug: a garantia de §31-F
  /// ("Ver Perfil nunca deve retornar UID/e-mail/Billing/...") vale porque há um
  /// caminho só, e ele não tem esses campos para dar.
  Map<String, Object?> toJson() => {
        'publicId': publicId,
        'apelido': apelido,
        'apelidoOrdenacao': apelidoOrdenacao,
        'avatarRef': avatarRef,
        'estado': estado.name,
        'criadoEm': criadoEm,
        'atualizadoEm': atualizadoEm,
        'esquema': kEsquemaSocial,
      };

  /// Relê um perfil gravado.
  ///
  /// Tolerante com o que falta e RIGOROSA com o que não presta: um documento sem
  /// `apelido` vira apelido vazio (a tela mostra o publicId), mas um `publicId`
  /// malformado é erro — ele é a identidade, e uma identidade corrompida não tem
  /// leitura degradada possível.
  static PerfilPublico deJson(Map<String, Object?> raw) {
    final publicId = raw['publicId'];
    if (!idPublicoValido(publicId)) {
      throw FormatException('perfil público com publicId inválido: $publicId');
    }
    return PerfilPublico(
      publicId: publicId! as String,
      apelido: raw['apelido'] is String ? raw['apelido']! as String : '',
      avatarRef: raw['avatarRef'] is String ? raw['avatarRef']! as String : null,
      estado: EstadoPerfilPublico.porNome(raw['estado']),
      criadoEm: raw['criadoEm'] is String ? raw['criadoEm']! as String : '',
      atualizadoEm:
          raw['atualizadoEm'] is String ? raw['atualizadoEm']! as String : '',
    );
  }
}

/// O que o servidor deve gravar quando o jogador pede para mudar apelido/avatar
/// (§11).
///
/// Devolve ou a recusa, ou o mapa exato a gravar. Nunca os dois. E o mapa NÃO
/// contém `publicId`, `criadoEm` nem `esquema`: §11 lista o que o cliente não
/// pode alterar, e a forma de garantir isso não é conferir depois — é não deixar
/// o caminho de alteração produzir esses campos.
class AtualizacaoDeApresentacao {
  final ErroSocial? recusa;
  final Map<String, Object?>? campos;

  const AtualizacaoDeApresentacao.recusada(this.recusa) : campos = null;
  const AtualizacaoDeApresentacao.aceita(this.campos) : recusa = null;

  bool get aceita => recusa == null;

  Map<String, Object?> toJson() => {
        'aceita': aceita,
        'recusa': recusa?.name,
        'campos': campos,
      };
}

/// Avalia um pedido de alteração de apresentação.
///
/// [apelidoBruto] e [avatarRef] são opcionais e independentes: mandar só o
/// apelido não apaga o avatar. Para REMOVER o avatar, quem chama passa
/// [removerAvatar] — não `avatarRef: null`, que é indistinguível de "não mexi
/// nisso" e apagaria o avatar de quem só quis trocar de nome.
AtualizacaoDeApresentacao avaliarAtualizacaoDeApresentacao({
  String? apelidoBruto,
  Object? avatarRef,
  bool removerAvatar = false,
  required String agoraIso,
  Set<String> catalogoAvatares = kCatalogoAvatares,
}) {
  final campos = <String, Object?>{};

  if (apelidoBruto != null) {
    final apelido = normalizarApelido(apelidoBruto);
    final recusa = recusaDeApelido(apelido);
    if (recusa != null) return AtualizacaoDeApresentacao.recusada(recusa);
    campos['apelido'] = apelido;
    // Recalculada aqui, a cada escrita. O cliente não manda esta chave e o
    // servidor não a copia de lugar nenhum: ela é função do apelido, e função
    // com duas origens vira duas verdades.
    campos['apelidoOrdenacao'] = chaveDeOrdenacao(apelido);
  }

  if (removerAvatar) {
    campos['avatarRef'] = null;
  } else if (avatarRef != null) {
    final recusa = recusaDeAvatar(avatarRef, catalogo: catalogoAvatares);
    if (recusa != null) return AtualizacaoDeApresentacao.recusada(recusa);
    campos['avatarRef'] = avatarRef;
  }

  if (campos.isEmpty) {
    // Pedido vazio. Recusado em vez de tratado como sucesso silencioso: quem
    // chamou acha que mudou alguma coisa, e não mudou.
    return const AtualizacaoDeApresentacao.recusada(ErroSocial.apelidoInvalido);
  }

  campos['atualizadoEm'] = agoraIso;
  return AtualizacaoDeApresentacao.aceita(campos);
}
