// evento.dart — O QUE ATRAVESSA a fronteira quando alguém se comunica.
//
// A §5 da OS pede uma coisa só, e ela é fácil de enunciar e fácil de errar:
//
//     CADA EVENTO DEVERÁ POSSUIR TIPO EXPLÍCITO.
//     NÃO TRANSPORTAR TUDO COMO UMA STRING GENÉRICA.
//
// O erro que isso proíbe tem nome: é o campo `texto` que serve para tudo. Com
// ele, uma fala catalogada viaja como a frase já renderizada, um emoji viaja
// como o caractere, e um evento de sistema viaja como "Você recebeu um
// presente" — e nesse instante o sistema perdeu a capacidade de saber o que
// cada mensagem É. Perde a localização (a frase chega no idioma de quem
// escreveu), perde a moderação (não dá para contar repetição de uma fala se
// falas não têm id) e perde a autenticidade (qualquer um digita a frase do
// sistema).
//
// Por isso o tipo é enumerado e fechado, e por isso o conteúdo de cada tipo é
// diferente: fala catalogada tem `itemId`, texto privado tem `conteudo`, evento
// de sistema tem `eventoId` e NÃO tem autor jogador.

/// O que este evento é. Lista fechada (§5).
///
/// `wire` fica gravado e viaja. Nome de enum do Dart não vai para o Firestore.
enum TipoDeComunicacao {
  /// Uma fala do catálogo: "Boa jogada!", "Vamos jogar?". Carrega `itemId`.
  falaCatalogada('fala_catalogada'),

  /// Uma reação rápida sobre a mesa. Carrega `itemId`.
  reacaoCatalogada('reacao_catalogada'),

  /// Um emoji autorizado. Carrega `itemId`.
  emojiCatalogado('emoji_catalogado'),

  /// Texto digitado. SÓ existe na Mesa Privada. Carrega `conteudo`.
  textoPrivado('texto_privado'),

  /// Produzido pela autoridade: presente, resgate, convite oficial, entrada,
  /// saída, ação de moderação, encerramento. NUNCA tem autor jogador.
  eventoDeSistema('evento_de_sistema');

  final String wire;
  const TipoDeComunicacao(this.wire);

  static TipoDeComunicacao? porWire(Object? wire) {
    if (wire is! String) return null;
    for (final t in TipoDeComunicacao.values) {
      if (t.wire == wire) return t;
    }
    return null;
  }

  /// Este tipo se resolve por um item do catálogo?
  bool get ehCatalogado =>
      this == TipoDeComunicacao.falaCatalogada ||
      this == TipoDeComunicacao.reacaoCatalogada ||
      this == TipoDeComunicacao.emojiCatalogado;

  /// Um jogador pode PEDIR este tipo?
  ///
  /// `eventoDeSistema` responde `false`, e é a §8 inteira em uma linha: usuário
  /// comum não fabrica "Você recebeu um presente" nem "Jogador foi banido". A
  /// porta que produz evento de sistema é outra, e exige autoridade.
  bool get pedidoPeloJogador => this != TipoDeComunicacao.eventoDeSistema;
}

/// Versão do formato dos documentos de comunicação gravados.
const int kEsquemaComunicacao = 1;

/// Por que uma comunicação CATALOGADA foi recusada.
///
/// Vocabulário PRÓPRIO, e não um acréscimo a `RecusaMensagem` (app/lib/chat/
/// mensagem.dart): aquele enum descreve o que dá errado com TEXTO — vazio,
/// longo, com caractere de controle. Nada disso existe aqui, porque aqui não há
/// texto do jogador. Misturar os dois faria cada leitor de log ter de saber
/// quais valores se aplicam ao seu caso.
///
/// Os dois vocabulários convivem no MESMO campo do veredito, serializados pelo
/// `.name`. É o que permite ao cliente distinguir `conteudoVazio` de
/// `itemDesconhecido` sem que a autoridade precise de dois campos de recusa.
enum RecusaComunicacao {
  /// `tipo` ausente, desconhecido, ou de um tipo que o jogador não pede.
  tipoInvalido,

  /// O ambiente não admite comunicação nenhuma (Treino), ou o modo é
  /// `desligado`.
  ambienteSemComunicacao,

  /// O ambiente não admite TEXTO LIVRE. É a recusa da §2 — a que separa a Mesa
  /// Privada de todo o resto.
  textoLivreNaoPermitidoNoAmbiente,

  /// O ambiente não admite item catalogado (Treino, ou chat desligado).
  catalogadoNaoPermitidoNoAmbiente,

  /// `itemId` ausente ou fora do formato de identificador.
  itemInvalido,

  /// Não existe item com esse id no catálogo.
  itemDesconhecido,

  /// O item existe e está DESATIVADO. Recusa própria, e não `itemDesconhecido`,
  /// porque as duas dizem coisas diferentes a quem lê o log: uma é cliente
  /// desatualizado, a outra é tentativa de usar id inventado.
  itemDesativado,

  /// O item existe, está ativo, e NÃO é liberado neste ambiente.
  itemForaDoAmbiente,

  /// O item é de um tipo diferente do que o pedido declarou (emoji pedido como
  /// fala, por exemplo).
  itemDeOutroTipo,

  /// O item é premium e quem pediu não tem o direito exigido.
  entitlementAusente,

  /// O cliente mandou o TEXTO da fala em vez do id — ou mandou texto junto com
  /// o id. §6.2: "Não aceitar texto exibível enviado como substituto do ID".
  textoNoLugarDoItem,

  /// A versão mínima do catálogo exigida pelo item é maior que a versão que o
  /// pedido declara conhecer.
  versaoDeCatalogoInsuficiente,

  /// Ritmo: limite por janela, cooldown, repetição ou rajada. O detalhe vem em
  /// `motivoDeRitmo`.
  ritmoExcedido,

  /// Comunicação temporariamente bloqueada por abuso (§6.5).
  comunicacaoBloqueadaPorAbuso,

  /// Evento de sistema pedido por quem não é autoridade (§8).
  eventoDeSistemaSemAutoridade,

  /// `eventoId` que não existe no catálogo de eventos de sistema.
  eventoDeSistemaDesconhecido,
}

/// A FAMÍLIA de uma recusa — o motivo CATEGÓRICO da §7.4.
///
/// ===========================================================================
/// POR QUE UMA FAMÍLIA, E NÃO SÓ O NOME DA RECUSA
/// ===========================================================================
///
/// Quem traduz a recusa para o fio é o servidor de partidas, e ele não pode —
/// nem deve — conhecer o vocabulário inteiro desta autoridade. Duas razões
/// concretas, e as duas apareceram na prática:
///
///  1. UM NOME NOVO AQUI viraria `tente_de_novo` lá, em silêncio. O jogador
///     receberia "tente de novo" para uma recusa que nunca vai mudar de
///     resposta, e ficaria tentando.
///
///  2. O SERVIDOR TEM INVARIANTES DE VOCABULÁRIO. A suíte dele afirma que a
///     palavra `entitlement` não aparece no arquivo — é assim que ela prova que
///     aquele processo não decide assinatura. Um `case "entitlementAusente"` no
///     tradutor derrubaria essa prova por causa de um rótulo, e a saída errada
///     seria afrouxar a prova.
///
/// A família resolve as duas: é curta, é estável, e diz o que o jogador precisa
/// saber (que espécie de porta se fechou) sem nomear a regra que a fechou.
enum FamiliaDeRecusa {
  /// O pedido está malformado: campo proibido, intenção inválida, tipo
  /// desconhecido.
  forma('forma'),

  /// O canal não existe, está fechado ou é incoerente.
  canal('canal'),

  /// O AMBIENTE não admite o que se pediu. É a família da §2.
  ambiente('ambiente'),

  /// O item não existe, está inativo, é de outro tipo ou não vale aqui.
  catalogo('catalogo'),

  /// Falta o direito exigido pelo item.
  direito('direito'),

  /// Cedo demais: cooldown, janela, repetição, rajada, freio por abuso.
  ritmo('ritmo'),

  /// Bloqueio entre duas pessoas.
  contato('contato'),

  /// Sanção sobre quem escreve.
  sancao('sancao'),

  /// Falta identidade pública.
  identidade('identidade'),

  /// O conteúdo do texto é inválido.
  conteudo('conteudo');

  final String wire;
  const FamiliaDeRecusa(this.wire);
}

/// A família de uma recusa, pelo NOME dela.
///
/// Recebe o nome porque as recusas vêm de DOIS enums — [RecusaComunicacao] e
/// `RecusaMensagem` — que convivem no mesmo campo do veredito por decisão
/// (ver o cabeçalho de [RecusaComunicacao]). Uma função por nome é o que
/// permite classificar os dois sem juntá-los num terceiro enum.
///
/// DESCONHECIDO VIRA [FamiliaDeRecusa.forma], e não uma família nova: uma
/// recusa que ninguém classificou é, no mínimo, um pedido que não deu certo, e
/// `forma` é a família que não promete nada ao cliente.
FamiliaDeRecusa familiaDaRecusa(String? recusa) {
  switch (recusa) {
    case 'canalDesconhecido':
    case 'canalInvalido':
    case 'canalFechado':
    case 'papelSemDireitoDeFala':
    case 'semDestinatarios':
      return FamiliaDeRecusa.canal;

    case 'ambienteSemComunicacao':
    case 'textoLivreNaoPermitidoNoAmbiente':
    case 'catalogadoNaoPermitidoNoAmbiente':
    case 'superficieNaoAceitaChat':
      return FamiliaDeRecusa.ambiente;

    case 'itemInvalido':
    case 'itemDesconhecido':
    case 'itemDesativado':
    case 'itemForaDoAmbiente':
    case 'itemDeOutroTipo':
    case 'textoNoLugarDoItem':
    case 'versaoDeCatalogoInsuficiente':
    case 'eventoDeSistemaDesconhecido':
      return FamiliaDeRecusa.catalogo;

    case 'entitlementAusente':
    case 'eventoDeSistemaSemAutoridade':
      return FamiliaDeRecusa.direito;

    case 'ritmoExcedido':
    case 'comunicacaoBloqueadaPorAbuso':
      return FamiliaDeRecusa.ritmo;

    case 'contatoRecusado':
      return FamiliaDeRecusa.contato;

    case 'suspensaoImpedeChat':
      return FamiliaDeRecusa.sancao;

    case 'identidadePublicaAusente':
      return FamiliaDeRecusa.identidade;

    case 'conteudoNaoTexto':
    case 'conteudoVazio':
    case 'conteudoAcimaDoLimite':
    case 'conteudoComCaractereDeControle':
      return FamiliaDeRecusa.conteudo;

    default:
      return FamiliaDeRecusa.forma;
  }
}

/// A comunicação como os OUTROS a recebem.
///
/// O QUE ESTA CLASSE NÃO TEM continua sendo o ponto dela, exatamente como em
/// `MensagemPublica` (app/lib/chat/mensagem.dart): não há `autorUid`, não há
/// destinatário, não há socket, não há estado administrativo, não há lista de
/// bloqueios nem de silenciados.
///
/// O QUE ELA GANHOU nesta OS:
///
///   `tipo` .................. para o cliente saber o que renderizar;
///   `itemId` ................ o que foi dito, quando é catálogo;
///   `chaveDeLocalizacao` .... para o cliente renderizar NO IDIOMA DELE;
///   `fallbackOficial` ....... o texto oficial de quem não tem tradução;
///   `ambiente` .............. onde isto foi dito;
///   `versaoDoCatalogo` ...... com que catálogo o item foi resolvido.
///
/// `conteudo` continua existindo e continua sendo TEXTO OPACO — mas só vem
/// preenchido em `textoPrivado`. Numa fala catalogada ele é `null`, e essa
/// ausência é deliberada: se a autoridade mandasse a frase pronta, o jogador
/// estrangeiro receberia português, e a §6.3 inteira seria decorativa.
class ComunicacaoPublica {
  final String messageId;

  /// A identidade PÚBLICA de quem falou. `null` só em evento de sistema.
  final String? autorPublicId;

  final String ambiente;
  final String canalId;
  final String tipo;

  final String? itemId;
  final String? chaveDeLocalizacao;
  final String? fallbackOficial;
  final String? conteudo;

  /// Instante do SERVIDOR, em ISO-8601 com fuso.
  final String enviadaEm;

  final int versaoDoCatalogo;
  final int versaoDoContrato;
  final int esquema;

  const ComunicacaoPublica({
    required this.messageId,
    required this.autorPublicId,
    required this.ambiente,
    required this.canalId,
    required this.tipo,
    required this.enviadaEm,
    required this.versaoDoCatalogo,
    required this.versaoDoContrato,
    this.itemId,
    this.chaveDeLocalizacao,
    this.fallbackOficial,
    this.conteudo,
    this.esquema = kEsquemaComunicacao,
  });

  /// LISTA DE PERMISSÃO explícita, e campos nulos OMITIDOS.
  ///
  /// Omitir em vez de mandar `null` não é economia de bytes: é para que
  /// `conteudo` só apareça quando existe conteúdo. Um `conteudo: null` numa
  /// fala catalogada convidaria o primeiro renderizador a tratar ausência como
  /// string vazia e a desenhar um balão em branco.
  Map<String, Object?> toJson() => {
        'messageId': messageId,
        if (autorPublicId != null) 'autorPublicId': autorPublicId,
        'ambiente': ambiente,
        'canalId': canalId,
        'tipo': tipo,
        if (itemId != null) 'itemId': itemId,
        if (chaveDeLocalizacao != null) 'chaveDeLocalizacao': chaveDeLocalizacao,
        if (fallbackOficial != null) 'fallbackOficial': fallbackOficial,
        if (conteudo != null) 'conteudo': conteudo,
        'enviadaEm': enviadaEm,
        'versaoDoCatalogo': versaoDoCatalogo,
        'versaoDoContrato': versaoDoContrato,
        'esquema': esquema,
      };
}
