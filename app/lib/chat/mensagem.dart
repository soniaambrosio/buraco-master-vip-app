// mensagem.dart — o que é uma mensagem de chat, e o que ela JAMAIS carrega.
//
// TEXTO LIVRE É TEXTO LIVRE (§6). Não há lista de frases prontas aqui, e não há
// filtro moral de palavras: a OS proíbe as duas coisas. O que há são limites
// OPERACIONAIS — tipo, tamanho, caracteres que não renderizam — e a separação
// entre o que o jogador escreve e o que a autoridade decide.
//
// O CLIENTE PEDE; ELE NÃO DECIDE (§4). Deste arquivo saem os campos que o
// payload nunca escolhe:
//
//   messageId .... derivado, não sorteado pelo cliente (ver [mensagemIdDe]);
//   autor ........ o UID autenticado, e o `publicId` que a autoridade de
//                  identidade pública já mantém;
//   enviadaEm .... o instante que o servidor congelou;
//   superficie ... valor de um enum fechado, não string livre.
//
// NADA AQUI LÊ RELÓGIO, Firestore ou rede. É a mesma disciplina de
// app/lib/moderacao/ — decisão pura, testável sem emulador, e o mesmo código
// serve ao cliente (para não deixar digitar 3 mil caracteres à toa) e ao
// servidor (que é quem decide de verdade).

import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../moderacao/validacao.dart';
import 'superficie.dart';

/// Tamanho máximo de uma linha de chat, em PONTOS DE CÓDIGO.
///
/// 300 e não 500 (o teto do comentário de denúncia) porque as duas coisas não
/// são o mesmo objeto: um comentário de denúncia é um relato que alguém lerá uma
/// vez, e uma linha de chat é despejada numa mesa quatro vezes por minuto. O
/// teto menor é o que mantém a mesa legível e o volume de escrita previsível.
const int kLimiteMensagem = 300;

/// A medida é em RUNES (pontos de código), e a escolha é deliberada (§6:
/// "tamanho medido de forma consistente").
///
/// `String.length` em Dart conta unidades UTF-16: um emoji fora do BMP conta 2, e
/// um jogador que escrevesse 151 emojis levaria "acima do limite" com 151
/// caracteres na tela. Contar pontos de código dá o MESMO número em Dart
/// (`runes.length`) e em JavaScript (`[...s].length`) — e essa igualdade é o que
/// permite ao cliente e ao servidor recusarem exatamente as mesmas mensagens.
///
/// NÃO é contagem de grafemas: uma família com quatro pessoas ainda conta vários.
/// Grafema exigiria pacote de segmentação nas duas linguagens, e o teto aqui é
/// proteção de volume, não tipografia.
int tamanhoDeMensagem(String conteudo) => conteudo.runes.length;

/// Por que uma mensagem foi recusada.
enum RecusaMensagem {
  /// Veio Map, List, número ou nada onde tinha que vir texto. É o caso do
  /// payload estrutural tentando passar por conteúdo (§6).
  conteudoNaoTexto,

  /// Nada sobrou depois de aparar as pontas.
  conteudoVazio,

  /// Acima de [kLimiteMensagem] pontos de código.
  conteudoAcimaDoLimite,

  /// Contém caractere de controle ou separador de linha invisível.
  conteudoComCaractereDeControle,

  /// `intentId` ausente ou fora do formato de identificador.
  intencaoInvalida,

  /// `canalId` ausente ou fora do formato de identificador.
  canalInvalido,

  /// Superfície desconhecida, ou superfície sem decisão de produto (§11).
  superficieNaoAceitaChat,

  /// Quem escreve não ocupa assento no canal: espectador ou quem já saiu (§11).
  papelSemDireitoDeFala,

  /// O payload trouxe campo de transporte ou de identidade interna (§10, §13).
  payloadComCampoProibido,

  /// Quem escreve não tem identidade pública, e sem ela a única forma de
  /// identificar o autor seria expor o UID (§5).
  identidadePublicaAusente,

  /// Não existe canal autoritativo com esse id. Recusa e não criação: quem abre
  /// canal é o motor de partidas, nunca quem fala (§10).
  canalDesconhecido,

  /// O canal existe mas não aceita mais mensagem (partida encerrada).
  canalFechado,

  /// Não há ninguém sentado além do autor para receber. Mensagem para ninguém
  /// não é mensagem, e responder sucesso faria o jogador crer que foi lida.
  semDestinatarios,

  /// Bloqueio ou sanção social impedem o contato. O motivo exato vem em
  /// `motivoContato`, no vocabulário canônico de
  /// app/lib/moderacao/relacao_social.dart — esta camada NÃO reinventa aquele
  /// enum, ela o carrega (§7).
  contatoRecusado,

  /// Suspensão em vigor sobre quem escreve (§8). Valor próprio porque
  /// `MotivoContatoRecusado` não tem um: aquele enum foi escrito para rotas
  /// sociais, onde suspensão nunca foi consultada. Ver [avaliarEnvio].
  suspensaoImpedeChat,
}

/// Campos que o payload de envio JAMAIS pode trazer.
///
/// DUAS FAMÍLIAS, e as duas por motivos diferentes:
///
///  1. CONTEXTO TRANSITÓRIO (§10). `socketId`, `connectionId`, `geracao`,
///     `tentativa`: são identidade de CONEXÃO, não de mensagem. Aceitá-los faria
///     uma reconexão legítima virar outra mensagem — que é exatamente o defeito
///     que a idempotência existe para impedir. Recusar em vez de ignorar porque
///     um cliente que os manda está construído sobre a suposição errada, e
///     ignorar em silêncio deixaria o erro crescer.
///
///  2. IDENTIDADE E AUTORIDADE (§4, §5). `uid`, `autorUid`, `senderUid`,
///     `publicId`, `messageId`, `enviadaEm`, `token`: são o que a autoridade
///     decide. Aceitá-los é a diferença entre "quero enviar este texto" e "esta
///     mensagem é de outra pessoa, gravada na hora que eu quiser".
///
/// Recusar o pedido inteiro (e não apenas descartar o campo) é o que torna a
/// prova negativa POSSÍVEL: um teste que manda `autorUid` de terceiro precisa
/// ver algo acontecer. Ver [avaliarEnvio] em porta.dart.
const Set<String> kCamposProibidosNoEnvio = {
  // transporte / contexto transitório
  'socketId', 'socket', 'connectionId', 'conexaoId',
  'geracao', 'generation', 'tentativa', 'retry', 'ip', 'remoteAddress',
  'sessionId', 'sessaoId', 'wsId',
  // identidade e autoridade
  'uid', 'userId', 'autorUid', 'authorUid', 'senderUid', 'remetenteUid',
  'publicId', 'autorPublicId', 'messageId', 'mensagemId',
  'enviadaEm', 'timestamp', 'criadoEm', 'serverTime',
  'token', 'idToken', 'refreshToken', 'claims', 'admin',
  // estado que só a moderação escreve
  'moderacao', 'playerModeration', 'chatSilenciadoAte', 'socialRestritoAte',
  'suspensoAte', 'suspensaoPermanente', 'visibilidade', 'oculta',
  // MODO DO CHAT — quem decide é a SUPERFÍCIE, não o pedido.
  //
  // A correção canônica é explícita: payload que tente habilitar chat completo
  // fora da Mesa Privada tem de ser RECUSADO pela autoridade, mesmo vindo de
  // cliente adulterado. Estes nomes existem aqui para que a tentativa seja
  // recusada por NOME, e não apenas ignorada — uma recusa nomeada aparece no log
  // e no laudo; um campo ignorado em silêncio deixa o cliente adulterado tentar
  // de novo, para sempre, sem ninguém saber.
  //
  // Note que a proteção NÃO depende desta lista: mesmo sem ela, a superfície vem
  // do documento do canal (escrito pelo motor) e é conferida contra a
  // classificação. A lista é a segunda tranca, e é a que dá o diagnóstico.
  'chatCompleto', 'chatLivre', 'textoLivre', 'modoChat', 'chat',
  'permitirTextoLivre', 'liberarChat',
};

/// Caracteres que não renderizam e por isso não entram numa linha de chat.
///
/// C0 (0x00–0x1F), DEL (0x7F), C1 (0x80–0x9F) e os separadores U+2028/U+2029.
///
/// O motivo não é estética: são o jeito clássico de forjar uma linha. Um `\n` no
/// meio do texto imita duas mensagens numa; um `\r` reposiciona o cursor num log
/// de operador; U+2028 quebra linha em JavaScript sem parecer que quebrou. A
/// mensagem é UMA linha, e recusar é mais honesto que remover em silêncio — quem
/// removesse entregaria ao jogador um texto diferente do que ele escreveu, e
/// deixaria a evidência de uma denúncia divergir do que foi digitado.
///
/// TAB inclusive: 0x09 está no intervalo C0 e não tem função numa linha só.
bool temCaractereDeControle(String s) {
  for (final r in s.runes) {
    if (r <= 0x1F) return true;
    if (r == 0x7F) return true;
    if (r >= 0x80 && r <= 0x9F) return true;
    if (r == 0x2028 || r == 0x2029) return true;
  }
  return false;
}

/// Normaliza o conteúdo: apara as pontas, e NADA MAIS.
///
/// Não colapsa espaço interno, não corta, não corrige, não transforma. Texto
/// livre significa que o que o jogador escreveu é o que fica gravado — e é
/// também o que a evidência de uma denúncia vai mostrar. Uma autoridade que
/// reescrevesse o conteúdo tornaria a própria evidência discutível.
String? normalizarConteudo(Object? bruto) {
  if (bruto is! String) return null;
  final t = bruto.trim();
  return t.isEmpty ? null : t;
}

// ---------------------------------------------------------------- identidade

/// O `messageId` autoritativo, derivado de autor + intenção.
///
/// DUAS PROPRIEDADES, e as duas são exigência da OS:
///
///  1. DETERMINISTA (§9). Mesmo autor + mesma intenção = mesmo id. É o que faz
///     retry, toque duplo e reconexão convergirem no MESMO documento em vez de
///     publicarem duas mensagens. O cliente escolhe o `intentId`; ele NÃO
///     escolhe o `messageId`, e não consegue prever o de outra pessoa.
///
///  2. OPACO (§13). É um digest, e não `${uid}|${intentId}` — que é o formato
///     que `chaveDeDenuncia` usa em app/lib/moderacao/denuncia.dart. A diferença
///     tem razão concreta: o id de uma denúncia só aparece em coleção de leitura
///     restrita a admin, enquanto o `messageId` viaja para os outros jogadores da
///     mesa e é referenciado numa denúncia. Um id que carregasse o UID
///     transformaria cada linha de chat num vazamento de identidade interna.
///
/// 32 hex = 128 bits do SHA-256. O truncamento é seguro para o que se pede aqui:
/// o valor não é segredo e não autentica ninguém — ele só precisa não colidir
/// entre autores diferentes, e 128 bits cobrem isso com folga.
///
/// `chaveComposta` (e não interpolação crua) porque ela RECUSA componente com
/// `|` ou fora de `[A-Za-z0-9_-]`: sem isso, um `intentId` com separador dentro
/// deixaria dois pedidos diferentes caírem na mesma chave.
String mensagemIdDe({required String autorUid, required String intentId}) {
  final base = chaveComposta([autorUid, intentId]);
  final digest = sha256.convert(utf8.encode(base));
  return digest.toString().substring(0, 32);
}

/// A "impressão" do pedido: o que a chave de idempotência NÃO carrega.
///
/// POR QUE ISTO EXISTE: a barreira de functions-moderacao/src/idempotency.ts
/// compara `impressao` para distinguir REPETIÇÃO de INTENÇÃO REAPROVEITADA. A
/// chave é autor+intenção; ela não diz nada sobre o canal nem sobre o texto. Sem
/// esta impressão, reaproveitar o mesmo `intentId` com OUTRO texto encontraria a
/// chave reservada, e a autoridade responderia sucesso sem ter gravado a
/// mensagem nova — a mensagem pedida desapareceria com uma confirmação na mão de
/// quem pediu. É o mesmo defeito que `conferirConformidade` já corrigiu para
/// denúncia e sanção.
///
/// É digest, e não o texto cru, porque este valor é gravado em `moderationTasks`
/// e não faz sentido guardar uma segunda cópia do conteúdo fora da mensagem.
String impressaoDoEnvio({
  required SuperficieChat superficie,
  required String canalId,
  required String conteudo,
}) {
  final base = jsonEncode([superficie.wire, canalId, conteudo]);
  return sha256.convert(utf8.encode(base)).toString().substring(0, 32);
}

// ------------------------------------------------------------------ projeção

/// A mensagem como os OUTROS a recebem (§13).
///
/// O que esta classe NÃO tem é o ponto dela: não há `autorUid`, não há UID de
/// destinatário, não há socket, não há IP, não há token, não há estado
/// administrativo, não há lista de bloqueios. O autor aparece pelo `publicId` —
/// a identidade que app/lib/social/ e functions-social já mantêm como pública.
///
/// `conteudo` é TEXTO OPACO. Nenhum campo aqui diz "html", "markdown" ou
/// "richText", e essa ausência é contrato: quem renderizar isto renderiza como
/// texto. Um campo que sugerisse marcação convidaria o primeiro renderizador a
/// interpretar conteúdo escrito por outro jogador (§6).
class MensagemPublica {
  final String messageId;
  final String autorPublicId;
  final String superficie;
  final String canalId;
  final String conteudo;

  /// Instante do SERVIDOR, em ISO-8601 com fuso.
  final String enviadaEm;

  final int esquema;

  const MensagemPublica({
    required this.messageId,
    required this.autorPublicId,
    required this.superficie,
    required this.canalId,
    required this.conteudo,
    required this.enviadaEm,
    this.esquema = kEsquemaChat,
  });

  Map<String, Object?> toJson() => {
        'messageId': messageId,
        'autorPublicId': autorPublicId,
        'superficie': superficie,
        'canalId': canalId,
        'conteudo': conteudo,
        'enviadaEm': enviadaEm,
        'esquema': esquema,
      };
}

/// Chaves que jamais podem aparecer numa mensagem entregue a outro jogador.
///
/// Espelha `CHAVES_PROIBIDAS` de functions-social/src/chaves.ts, e a duplicação
/// é deliberada pelo mesmo motivo declarado lá: aquela lista guarda a RESPOSTA
/// social, esta guarda a MENSAGEM. São dois momentos, e um documento limpo ainda
/// vira uma entrega suja se alguém espalhar o documento gravado dentro dela.
///
/// [MensagemPublica] é classe fechada, então o vazamento não entra por ela — ele
/// entra no dia em que alguém devolver o documento do Firestore direto, ou
/// acrescentar um `...doc.data()` "só para depurar".
/// [caminhosProibidosNaEntrega] é o que transforma esse dia num erro em vez de
/// num incidente.
const Set<String> kChavesProibidasNaEntrega = {
  'uid', 'userId', 'autorUid', 'authorUid', 'senderUid', 'remetenteUid',
  'destinatarioUid', 'destinatarios', 'participantes', 'espectadores',
  'membros', 'email', 'telefone', 'phoneNumber',
  'token', 'idToken', 'refreshToken', 'claims', 'providerId', 'providerData',
  'ip', 'remoteAddress', 'socketId', 'socket', 'connectionId', 'sessionId',
  'reports', 'denuncias', 'sanctions', 'sancoes', 'playerModeration',
  'chatSilenciadoAte', 'socialRestritoAte', 'suspensoAte',
  'suspensaoPermanente', 'blocks', 'bloqueios', 'mutes',
  'vip', 'billing', 'entitlement', 'entitlements', 'assinatura', 'compras',
  'cpf', 'endereco',
};

/// Procura chave proibida EM PROFUNDIDADE e devolve os caminhos encontrados.
///
/// Recursiva porque o vazamento real quase nunca está no topo: ele está em
/// `{mensagem: {...}, canal: {participantes: [...]}}`, um nível abaixo de onde
/// alguém olharia numa revisão.
List<String> caminhosProibidosNaEntrega(Object? valor, [String prefixo = '']) {
  if (valor is List) {
    final achados = <String>[];
    for (var i = 0; i < valor.length; i++) {
      achados.addAll(caminhosProibidosNaEntrega(valor[i], '$prefixo[$i]'));
    }
    return achados;
  }
  if (valor is! Map) return const [];

  final achados = <String>[];
  valor.forEach((chave, v) {
    final nome = chave is String ? chave : '$chave';
    final caminho = prefixo.isEmpty ? nome : '$prefixo.$nome';
    if (kChavesProibidasNaEntrega.contains(nome)) achados.add(caminho);
    achados.addAll(caminhosProibidosNaEntrega(v, caminho));
  });
  return achados;
}
