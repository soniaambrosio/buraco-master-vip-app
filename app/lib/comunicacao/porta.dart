// porta.dart — A PORTA ÚNICA DE TODA COMUNICAÇÃO SOCIAL.
//
// Uma fala, uma reação, um emoji ou uma linha de texto só existem se
// [avaliarComunicacao] disser que existem. Não há segundo caminho, e não há
// `if` de política no TypeScript: functions-moderacao/src/index.ts autentica,
// lê, grava e entrega — quem DECIDE é este arquivo.
//
// ===========================================================================
// ESTA PORTA NÃO SUBSTITUI A DO CHAT LIVRE: ELA A ENVOLVE
// ===========================================================================
//
// `avaliarEnvio` (app/lib/chat/porta.dart) continua sendo a autoridade sobre
// TEXTO: conteúdo, tamanho, caractere de controle, assento, bloqueio por par.
// Ela foi escrita, provada e ligada na OS do Chat Livre Seguro, e reescrevê-la
// aqui criaria a segunda implementação que aquela OS proíbe.
//
// O que esta porta acrescenta é a pergunta que faltava, e que é a razão desta
// OS existir:
//
//     ANTES de perguntar "este texto é válido?", perguntar
//     "TEXTO PODE EXISTIR AQUI?"
//
// A resposta vem da matriz da §2 (ambiente.dart), e ela é NÃO em cinco dos seis
// ambientes. Onde ela é não, o pedido de texto é recusado sem sequer olhar o
// conteúdo — e o jogador só tem o catálogo.
//
// ===========================================================================
// A ORDEM DAS PERGUNTAS
// ===========================================================================
//
//   1. o pedido trouxe campo que não podia trazer?     (forma)
//   2. a intenção é um identificador?                  (forma)
//   3. o canal existe, está aberto e é coerente?       (contexto)
//   4. quem pede está no canal, e em que papel?        (contexto)
//   5. que TIPO de comunicação é esta?                 (contrato)
//   6. o AMBIENTE admite esse tipo?                    (§2 — a decisão)
//   7. o item existe, está ativo e vale aqui?          (catálogo)
//   8. quem pede tem o direito exigido?                (entitlement)
//   9. há sanção sobre quem pede?                      (disciplinar)
//  10. o ritmo permite?                                (anti-spam)
//  11. quem recebe?                                    (bloqueio, silêncio)
//
// Nenhuma resposta muda com a ordem — qualquer recusa recusa. O que a ordem
// decide é QUAL recusa volta, e o barato vem antes do caro: nenhuma leitura de
// bloqueio é feita para um pedido malformado.

import '../chat/mensagem.dart';
import '../chat/porta.dart';
import '../chat/superficie.dart';
import '../elegibilidade/entitlement.dart';
import '../moderacao/relacao_social.dart';
import '../moderacao/validacao.dart';
import 'ambiente.dart';
import 'catalogo.dart';
import 'evento.dart';
import 'limites.dart';

/// O canal, com o AMBIENTE que a autoridade resolveu.
///
/// [canal] é o mesmo `CanalDeChat` do domínio do chat — participantes, papéis,
/// aberto/fechado. [ambiente] e [modo] são o que esta OS acrescenta, e eles
/// NÃO VÊM DO PAYLOAD: são resolvidos quando o canal é declarado, a partir da
/// autoridade dos tipos de mesa e (na Mesa Privada) do documento da sala.
class CanalDeComunicacao {
  final CanalDeChat canal;
  final AmbienteDeComunicacao ambiente;
  final ModoDeComunicacao modo;

  const CanalDeComunicacao({
    required this.canal,
    required this.ambiente,
    required this.modo,
  });

  String get canalId => canal.canalId;
  bool get aberto => canal.aberto;

  /// Quem pode RECEBER, além do autor.
  ///
  /// Numa mesa, são os assentos (a lista que o chat já usava). Num saguão, são
  /// os presentes. Espectador não aparece em nenhuma das duas: a decisão de que
  /// plateia não recebe conversa de jogador é anterior a esta OS
  /// (app/lib/chat/superficie.dart) e continua valendo.
  List<String> candidatosExceto(String autorUid) {
    if (ambiente.ehSaguao) {
      return [
        for (final p in canal.participantes)
          if (p.papel == PapelNoCanal.presenteNoAmbiente && p.uid != autorUid)
            p.uid,
      ];
    }
    return canal.assentosExceto(autorUid);
  }

  /// O papel que dá direito de FALAR neste ambiente.
  PapelNoCanal get papelQueFala => ambiente.ehSaguao
      ? PapelNoCanal.presenteNoAmbiente
      : PapelNoCanal.jogadorSentado;
}

/// Campos que o payload de comunicação JAMAIS pode trazer, ALÉM dos que o chat
/// já recusava (`kCamposProibidosNoEnvio`).
///
/// Cada um destes é uma das PROVAS NEGATIVAS da §15 — a lista do que "não basta
/// alterar no cliente". Recusar o pedido inteiro (em vez de ignorar o campo) é
/// o que torna a prova possível: um teste que manda `ambiente: mesa_privada`
/// precisa ver algo acontecer.
const Set<String> kCamposProibidosNaComunicacao = {
  // Onde se está, e o que o lugar permite. Vem do canal, resolvido pela
  // autoridade dos tipos de mesa.
  'ambiente', 'modo', 'modoDeChat', 'chat', 'chatCompleto',
  'tipoMesa', 'tipoDeMesa', 'tipoPartida', 'categoriaCompetitiva',
  'codigoDaSala', 'codigoConvite', 'salaId', 'roomId',
  // Direito. Vem de `playerEntitlements`, e a vigência é recalculada.
  'isVip', 'premium', 'direito', 'direitoExigido', 'entitlement', 'entitlements',
  // Papel. Vem do canal.
  'papel', 'proprietario', 'ehProprietario', 'espectador', 'assento',
  // O que a autoridade resolve do catálogo. Aceitar qualquer um destes seria
  // deixar o remetente escolher o texto que os outros veem (§6.2).
  'versaoDoCatalogo', 'chaveDeLocalizacao', 'fallbackOficial', 'recursoVisual',
  'categoria',
  // Evento de sistema. §8: usuário comum não fabrica.
  'eventoId', 'sistema', 'origem', 'autoridade',
};

/// Campos que, num pedido CATALOGADO, denunciam texto no lugar do id (§6.2).
const Set<String> kCamposDeTextoExibivel = {
  'conteudo', 'texto', 'mensagem', 'frase', 'label', 'titulo', 'legenda',
};

/// O resultado da porta.
class VereditoComunicacao {
  final bool aceita;

  /// Nome da recusa. Carrega o `.name` de [RecusaComunicacao] OU de
  /// `RecusaMensagem` (app/lib/chat/mensagem.dart), conforme o caminho — os
  /// dois vocabulários convivem no mesmo campo de propósito, para que o cliente
  /// só precise olhar um lugar. Ver o cabeçalho de [RecusaComunicacao].
  final String? recusa;

  final MotivoContatoRecusado? motivoContato;
  final MotivoDeRitmo? motivoDeRitmo;
  final List<String> camposProibidos;

  /// Quando a mesma tentativa passaria a ser aceita (ms desde a época). Só em
  /// recusa de ritmo, e é informação sobre QUEM PEDIU — nunca sobre terceiro.
  final int? liberaEmMs;

  // -------------------------------------------------------- quando aceita
  final String? messageId;
  final String? impressao;
  final TipoDeComunicacao? tipo;
  final String? itemId;
  final String? chaveDeLocalizacao;
  final String? fallbackOficial;
  final String? conteudo;
  final AmbienteDeComunicacao? ambiente;

  /// Quem deve RECEBER, já filtrado por bloqueio nas duas direções.
  final List<String> destinatarios;

  /// Quem silenciou o autor e por isso não recebe a entrega.
  ///
  /// SEPARADO de [destinatarios] de propósito, e essa separação é a §9.1 em
  /// forma de dado: silêncio é preferência de quem ouve, não veto de quem fala.
  /// Se os silenciadores apenas sumissem da lista de destinatários, a mensagem
  /// que ninguém quer ouvir seria indistinguível — para a autoridade e para o
  /// log — de mensagem barrada por bloqueio.
  final List<String> silenciados;

  /// O estado de ritmo a gravar. Vem nos DOIS desfechos (ver [avaliarRitmo]).
  final EstadoDeRitmo? proximoRitmo;

  const VereditoComunicacao._({
    required this.aceita,
    this.recusa,
    this.motivoContato,
    this.motivoDeRitmo,
    this.camposProibidos = const [],
    this.liberaEmMs,
    this.messageId,
    this.impressao,
    this.tipo,
    this.itemId,
    this.chaveDeLocalizacao,
    this.fallbackOficial,
    this.conteudo,
    this.ambiente,
    this.destinatarios = const [],
    this.silenciados = const [],
    this.proximoRitmo,
  });

  factory VereditoComunicacao.aceita({
    required String messageId,
    required String impressao,
    required TipoDeComunicacao tipo,
    required AmbienteDeComunicacao ambiente,
    required List<String> destinatarios,
    required List<String> silenciados,
    required EstadoDeRitmo proximoRitmo,
    String? itemId,
    String? chaveDeLocalizacao,
    String? fallbackOficial,
    String? conteudo,
  }) =>
      VereditoComunicacao._(
        aceita: true,
        messageId: messageId,
        impressao: impressao,
        tipo: tipo,
        ambiente: ambiente,
        itemId: itemId,
        chaveDeLocalizacao: chaveDeLocalizacao,
        fallbackOficial: fallbackOficial,
        conteudo: conteudo,
        destinatarios: destinatarios,
        silenciados: silenciados,
        proximoRitmo: proximoRitmo,
      );

  factory VereditoComunicacao.recusada(
    Object recusa, {
    MotivoContatoRecusado? motivoContato,
    MotivoDeRitmo? motivoDeRitmo,
    List<String> camposProibidos = const [],
    int? liberaEmMs,
    EstadoDeRitmo? proximoRitmo,
  }) =>
      VereditoComunicacao._(
        aceita: false,
        recusa: recusa is Enum ? recusa.name : recusa.toString(),
        motivoContato: motivoContato,
        motivoDeRitmo: motivoDeRitmo,
        camposProibidos: camposProibidos,
        liberaEmMs: liberaEmMs,
        proximoRitmo: proximoRitmo,
      );

  Map<String, Object?> toJson() => {
        'aceita': aceita,
        'recusa': recusa,
        // O motivo CATEGORICO. Ver [FamiliaDeRecusa]: e o que o servidor de
        // partidas traduz para o fio, em vez de conhecer cada nome de recusa.
        if (!aceita) 'familia': familiaDaRecusa(recusa).wire,
        'motivoContato': motivoContato?.name,
        'motivoDeRitmo': motivoDeRitmo?.name,
        'camposProibidos': camposProibidos,
        if (liberaEmMs != null) 'liberaEmMs': liberaEmMs,
        if (aceita) 'messageId': messageId,
        if (aceita) 'impressao': impressao,
        if (aceita) 'tipo': tipo!.wire,
        if (aceita) 'ambiente': ambiente!.wire,
        if (aceita && itemId != null) 'itemId': itemId,
        if (aceita && chaveDeLocalizacao != null)
          'chaveDeLocalizacao': chaveDeLocalizacao,
        if (aceita && fallbackOficial != null) 'fallbackOficial': fallbackOficial,
        if (aceita && conteudo != null) 'conteudo': conteudo,
        if (aceita) 'destinatarios': destinatarios,
        if (aceita) 'silenciados': silenciados,
        if (proximoRitmo != null) 'proximoRitmo': proximoRitmo!.toJson(),
        'versaoDoCatalogo': kVersaoDoCatalogo,
        'versaoDoContrato': kVersaoContratoComunicacao,
        'esquema': kEsquemaComunicacao,
      };
}

/// A impressão do pedido de comunicação (o que a chave de idempotência NÃO
/// carrega).
///
/// MESMA razão de `impressaoDoEnvio` no domínio do chat: a chave é
/// autor+intenção, e ela não diz nada sobre o que foi pedido. Sem esta
/// impressão, reaproveitar o mesmo `intentId` com OUTRO item encontraria a
/// chave reservada e a autoridade responderia sucesso sem ter gravado nada — o
/// pedido sumiria com uma confirmação na mão de quem pediu.
String impressaoDaComunicacao({
  required AmbienteDeComunicacao ambiente,
  required String canalId,
  required TipoDeComunicacao tipo,
  String? itemId,
  String? conteudo,
}) {
  // Reaproveita o digest do chat: mesma função, mesma propriedade, e uma só
  // implementação de "impressão" no projeto.
  return impressaoDoEnvio(
    superficie: superficieDe(ambiente),
    canalId: canalId,
    conteudo: [
      ambiente.wire,
      tipo.wire,
      itemId ?? '',
      conteudo ?? '',
    ].join('|'),
  );
}

/// A PORTA.
///
/// [autorUid] é o UID AUTENTICADO — ou, no ingresso do motor, o UID que o motor
/// afirma E que a autoridade confere contra o canal. Não existe parâmetro por
/// onde entre um autor meramente alegado.
///
/// [entitlementBruto] é o documento `playerEntitlements/{uid}` COMO ESTÁ, sem
/// interpretação prévia. A vigência é decidida aqui, por
/// `EntitlementVip.vigenteEm` — a definição ÚNICA de "tem VIP agora?" do
/// projeto. O TypeScript lê o documento e não opina sobre ele; se opinasse,
/// haveria dois lugares respondendo à mesma pergunta.
VereditoComunicacao avaliarComunicacao({
  required String autorUid,
  required String intentId,
  required Object? tipoPedido,
  required CanalDeComunicacao? canal,
  required SancaoDoAutor sancao,
  required DateTime agora,
  Object? itemIdPedido,
  Object? conteudoBruto,
  List<ParDeContato> contatos = const [],
  List<String> silenciaramOAutor = const [],
  List<String> camposDoPayload = const [],
  String? autorPublicId,
  Map<String, Object?>? entitlementBruto,
  EstadoDeRitmo ritmo = const EstadoDeRitmo(),
  ConfiguracaoDeRitmo configRitmo = ConfiguracaoDeRitmo.padrao,
  int versaoDeCatalogoDoCliente = kVersaoDoCatalogo,
}) {
  // 1. O pedido trouxe o que não devia? (§15)
  final proibidos = <String>{
    for (final k in camposDoPayload)
      if (kCamposProibidosNoEnvio.contains(k) ||
          kCamposProibidosNaComunicacao.contains(k))
        k,
  }.toList()
    ..sort();
  if (proibidos.isNotEmpty) {
    return VereditoComunicacao.recusada(
      RecusaMensagem.payloadComCampoProibido,
      camposProibidos: proibidos,
    );
  }

  // 2. Identificador da intenção.
  if (!identificadorValido(intentId)) {
    return VereditoComunicacao.recusada(RecusaMensagem.intencaoInvalida);
  }

  // 3. O canal. Ele é o CONTEXTO ESTÁVEL: sem canal declarado pela autoridade
  //    não há ambiente, e sem ambiente não há permissão. Falha fechada.
  if (canal == null) {
    return VereditoComunicacao.recusada(RecusaMensagem.canalDesconhecido);
  }
  if (!identificadorValido(canal.canalId)) {
    return VereditoComunicacao.recusada(RecusaMensagem.canalInvalido);
  }
  if (!superficieCoerente(canal.ambiente, canal.canal.superficie)) {
    return VereditoComunicacao.recusada(RecusaMensagem.canalInvalido);
  }
  if (!canal.aberto) {
    return VereditoComunicacao.recusada(RecusaMensagem.canalFechado);
  }

  // 4. Quem pede está no canal, no papel que fala?
  if (canal.canal.papelDe(autorUid) != canal.papelQueFala) {
    return VereditoComunicacao.recusada(RecusaMensagem.papelSemDireitoDeFala);
  }

  // 5. O tipo. Fechado, explícito, e evento de sistema NÃO se pede (§8).
  final tipo = TipoDeComunicacao.porWire(tipoPedido);
  if (tipo == null) {
    return VereditoComunicacao.recusada(RecusaComunicacao.tipoInvalido);
  }
  if (!tipo.pedidoPeloJogador) {
    return VereditoComunicacao.recusada(
        RecusaComunicacao.eventoDeSistemaSemAutoridade);
  }

  // 6. A MATRIZ (§2). É aqui que a OS acontece.
  final permissao = permissaoDe(canal.ambiente, canal.modo);
  if (!permissao.algumaCoisa) {
    return VereditoComunicacao.recusada(
        RecusaComunicacao.ambienteSemComunicacao);
  }
  if (tipo == TipoDeComunicacao.textoPrivado && !permissao.textoLivre) {
    return VereditoComunicacao.recusada(
        RecusaComunicacao.textoLivreNaoPermitidoNoAmbiente);
  }
  if (tipo.ehCatalogado && !permissao.catalogado) {
    return VereditoComunicacao.recusada(
        RecusaComunicacao.catalogadoNaoPermitidoNoAmbiente);
  }

  // 7. Identidade pública. Sem ela não há como nomear o autor sem expor o UID —
  //    e cunhar um publicId aqui criaria a segunda identidade que a §4.4 proíbe.
  if (autorPublicId == null || autorPublicId.isEmpty) {
    return VereditoComunicacao.recusada(
        RecusaMensagem.identidadePublicaAusente);
  }

  // ------------------------------------------------------------------------
  // O CAMINHO DO TEXTO LIVRE: delega ao domínio do chat, que é a autoridade
  // sobre texto desde a OS do Chat Livre Seguro. O que se acrescentou está
  // ACIMA desta linha, e é a única coisa que faltava: o ambiente.
  // ------------------------------------------------------------------------
  if (tipo == TipoDeComunicacao.textoPrivado) {
    final vereditoDeTexto = avaliarEnvio(
      autorUid: autorUid,
      intentId: intentId,
      conteudoBruto: conteudoBruto,
      superficiePedida: superficieDe(canal.ambiente).wire,
      canal: canal.canal,
      sancao: sancao,
      contatos: contatos,
      autorPublicId: autorPublicId,
    );

    if (!vereditoDeTexto.aceita) {
      return VereditoComunicacao.recusada(
        vereditoDeTexto.recusa ?? RecusaMensagem.conteudoNaoTexto,
        motivoContato: vereditoDeTexto.motivoContato,
        camposProibidos: vereditoDeTexto.camposProibidos,
      );
    }

    // O RITMO vem DEPOIS da decisão de conteúdo, e antes de qualquer escrita.
    // Ordem deliberada: um texto malformado não deve consumir cota de ritmo, e
    // quem digita lixo não deve ser freado por isso — deve ser corrigido.
    final ritmoDoTexto = avaliarRitmo(
      config: configRitmo,
      estado: ritmo,
      agora: agora,
      tipo: tipo,
    );
    if (!ritmoDoTexto.permitido) {
      return _recusaDeRitmo(ritmoDoTexto);
    }

    final entregaveis =
        _separarSilenciados(vereditoDeTexto.destinatarios, silenciaramOAutor);

    return VereditoComunicacao.aceita(
      messageId: vereditoDeTexto.messageId!,
      impressao: impressaoDaComunicacao(
        ambiente: canal.ambiente,
        canalId: canal.canalId,
        tipo: tipo,
        conteudo: vereditoDeTexto.conteudo,
      ),
      tipo: tipo,
      ambiente: canal.ambiente,
      conteudo: vereditoDeTexto.conteudo,
      destinatarios: entregaveis.entregar,
      silenciados: entregaveis.silenciados,
      proximoRitmo: ritmoDoTexto.proximoEstado,
    );
  }

  // ------------------------------------------------------------------------
  // O CAMINHO CATALOGADO.
  // ------------------------------------------------------------------------

  // 8. Texto no lugar do id (§6.2). Antes de olhar o item: quem manda a frase
  //    pronta está tentando escrever, e a resposta é a mesma em qualquer
  //    ambiente controlado.
  final comTexto = [
    for (final k in camposDoPayload)
      if (kCamposDeTextoExibivel.contains(k)) k,
  ]..sort();
  if (comTexto.isNotEmpty || conteudoBruto != null) {
    return VereditoComunicacao.recusada(
      RecusaComunicacao.textoNoLugarDoItem,
      camposProibidos: comTexto,
    );
  }

  // 9. O item.
  if (itemIdPedido is! String || !identificadorValido(itemIdPedido)) {
    return VereditoComunicacao.recusada(RecusaComunicacao.itemInvalido);
  }
  final item = itemPorId(itemIdPedido);
  if (item == null) {
    return VereditoComunicacao.recusada(RecusaComunicacao.itemDesconhecido);
  }
  if (!item.ativo) {
    return VereditoComunicacao.recusada(RecusaComunicacao.itemDesativado);
  }
  if (item.tipo != tipo) {
    return VereditoComunicacao.recusada(RecusaComunicacao.itemDeOutroTipo);
  }
  if (!item.liberadoEm(canal.ambiente)) {
    return VereditoComunicacao.recusada(RecusaComunicacao.itemForaDoAmbiente);
  }
  if (item.versaoMinima > versaoDeCatalogoDoCliente) {
    return VereditoComunicacao.recusada(
        RecusaComunicacao.versaoDeCatalogoInsuficiente);
  }

  // 10. O direito exigido. A vigência é RECALCULADA contra o relógio da
  //     operação — um `vipAtivo: true` gravado descreve um instante que já
  //     passou (ver o cabeçalho de app/lib/elegibilidade/entitlement.dart).
  if (item.premium && !_temDireitoVip(autorUid, entitlementBruto, agora)) {
    return VereditoComunicacao.recusada(RecusaComunicacao.entitlementAusente);
  }

  // 11. Sanção sobre QUEM FALA (§10). Vale para o ambiente inteiro, não por par
  //     — a mesma decisão que o chat livre já tomou.
  if (sancao.suspenso) {
    return VereditoComunicacao.recusada(RecusaMensagem.suspensaoImpedeChat);
  }
  if (sancao.restricaoSocial) {
    return VereditoComunicacao.recusada(
      RecusaMensagem.contatoRecusado,
      motivoContato: MotivoContatoRecusado.restricaoSocial,
    );
  }
  if (sancao.chatSilenciado) {
    return VereditoComunicacao.recusada(
      RecusaMensagem.contatoRecusado,
      motivoContato: MotivoContatoRecusado.chatSilenciadoPorSancao,
    );
  }

  // 12. O ritmo (§6.5).
  final vereditoDeRitmo = avaliarRitmo(
    config: configRitmo,
    estado: ritmo,
    agora: agora,
    tipo: tipo,
    categoria: item.categoria,
    itemId: item.id,
    cooldownDoItem: item.cooldown,
  );
  if (!vereditoDeRitmo.permitido) {
    return _recusaDeRitmo(vereditoDeRitmo);
  }

  // 13. Quem recebe. Bloqueio por PAR, consumindo `avaliarContato` — a mesma
  //     função que o chat livre consome, e a única resposta do projeto para
  //     "estes dois podem se falar?".
  final candidatos = canal.candidatosExceto(autorUid);
  if (candidatos.isEmpty) {
    return VereditoComunicacao.recusada(RecusaMensagem.semDestinatarios);
  }

  final porUid = {for (final c in contatos) c.uid: c};
  final permitidos = <String>[];
  MotivoContatoRecusado? ultimoMotivo;

  for (final uid in candidatos) {
    final par = porUid[uid] ?? ParDeContato(uid: uid);
    final veredito = avaliarContato(
      origemBloqueouDestino: par.autorBloqueou,
      destinoBloqueouOrigem: par.bloqueouOAutor,
    );
    if (veredito.permitido) {
      permitidos.add(uid);
    } else {
      ultimoMotivo = veredito.motivo;
    }
  }

  if (permitidos.isEmpty) {
    return VereditoComunicacao.recusada(
      RecusaMensagem.contatoRecusado,
      motivoContato: ultimoMotivo,
    );
  }

  final entregaveis = _separarSilenciados(permitidos, silenciaramOAutor);

  return VereditoComunicacao.aceita(
    messageId: mensagemIdDe(autorUid: autorUid, intentId: intentId),
    impressao: impressaoDaComunicacao(
      ambiente: canal.ambiente,
      canalId: canal.canalId,
      tipo: tipo,
      itemId: item.id,
    ),
    tipo: tipo,
    ambiente: canal.ambiente,
    itemId: item.id,
    chaveDeLocalizacao: item.chaveDeLocalizacao,
    fallbackOficial: item.fallbackOficial,
    destinatarios: entregaveis.entregar,
    silenciados: entregaveis.silenciados,
    proximoRitmo: vereditoDeRitmo.proximoEstado,
  );
}

/// "Este jogador tem VIP AGORA?", perguntado ao único lugar que responde.
///
/// DUAS PROTEÇÕES que a chamada crua não teria:
///
///   * `agora.toUtc()` — `vigenteEm` RECUSA instante sem fuso, com exceção. Uma
///     porta de comunicação não pode estourar por causa de um `DateTime` local;
///   * `try/catch` — `fromMap` faz `DateTime.parse` nos campos de data, e um
///     documento com data corrompida estouraria. Documento ilegível vira SEM
///     DIREITO, que é a leitura conservadora: um direito que não dá para provar
///     não é um direito (o mesmo princípio do cabeçalho de
///     app/lib/elegibilidade/entitlement.dart).
bool _temDireitoVip(
  String uid,
  Map<String, Object?>? bruto,
  DateTime agora,
) {
  try {
    return EntitlementVip.fromMap(uid, bruto).vigenteEm(agora.toUtc());
  } catch (_) {
    return false;
  }
}

VereditoComunicacao _recusaDeRitmo(VereditoDeRitmo v) {
  final bloqueado = v.motivo == MotivoDeRitmo.bloqueadoPorAbuso;
  return VereditoComunicacao.recusada(
    bloqueado
        ? RecusaComunicacao.comunicacaoBloqueadaPorAbuso
        : RecusaComunicacao.ritmoExcedido,
    motivoDeRitmo: v.motivo,
    liberaEmMs: v.liberaEmMs,
    proximoRitmo: v.proximoEstado,
  );
}

class _Entregaveis {
  final List<String> entregar;
  final List<String> silenciados;
  const _Entregaveis(this.entregar, this.silenciados);
}

/// Separa quem silenciou o autor de quem recebe.
///
/// SILÊNCIO NÃO RECUSA A MENSAGEM, e é a diferença exata para o bloqueio: se a
/// lista de entrega ficar vazia porque todo mundo silenciou, a mensagem AINDA
/// existe, é gravada e é confirmada ao autor. O contrário — recusar — contaria
/// ao autor que ele foi silenciado, que é precisamente o que a §9.1 proíbe
/// ("não notificar o alvo", e o alvo do silêncio é ele).
_Entregaveis _separarSilenciados(
  List<String> destinatarios,
  List<String> silenciaramOAutor,
) {
  if (silenciaramOAutor.isEmpty) {
    return _Entregaveis(destinatarios, const []);
  }
  final calados = silenciaramOAutor.toSet();
  final entregar = <String>[];
  final silenciados = <String>[];
  for (final uid in destinatarios) {
    if (calados.contains(uid)) {
      silenciados.add(uid);
    } else {
      entregar.add(uid);
    }
  }
  return _Entregaveis(entregar, silenciados);
}

// ===========================================================================
// EVENTO DE SISTEMA (§8)
// ===========================================================================

/// Avalia a emissão de um evento de sistema.
///
/// FUNÇÃO SEPARADA, e não um `tipo` a mais em [avaliarComunicacao]. A razão é a
/// §8 inteira: quem chama esta função é a AUTORIDADE, e o parâmetro que prova
/// isso ([autoridadeConfirmada]) não existe na outra porta. Um jogador não
/// alcança este caminho porque não há campo no pedido dele que leve até aqui —
/// e é isso que impede "Você recebeu um presente" de ser digitável.
///
/// [autoridadeConfirmada] é decidido pelo executor (claim `motorDePartidas` ou
/// `admin`), e é `false` por padrão: quem esquecer de passar não emite nada.
VereditoComunicacao avaliarEventoDeSistema({
  required Object? eventoIdPedido,
  required CanalDeComunicacao? canal,
  required String intentId,
  bool autoridadeConfirmada = false,
}) {
  if (!autoridadeConfirmada) {
    return VereditoComunicacao.recusada(
        RecusaComunicacao.eventoDeSistemaSemAutoridade);
  }
  if (!identificadorValido(intentId)) {
    return VereditoComunicacao.recusada(RecusaMensagem.intencaoInvalida);
  }
  if (canal == null) {
    return VereditoComunicacao.recusada(RecusaMensagem.canalDesconhecido);
  }
  if (!identificadorValido(canal.canalId) ||
      !superficieCoerente(canal.ambiente, canal.canal.superficie)) {
    return VereditoComunicacao.recusada(RecusaMensagem.canalInvalido);
  }
  if (!canal.aberto) {
    return VereditoComunicacao.recusada(RecusaMensagem.canalFechado);
  }

  final evento = eventoDeSistemaPorId(eventoIdPedido);
  if (evento == null) {
    return VereditoComunicacao.recusada(
        RecusaComunicacao.eventoDeSistemaDesconhecido);
  }
  if (!evento.ambientes.contains(canal.ambiente)) {
    return VereditoComunicacao.recusada(RecusaComunicacao.itemForaDoAmbiente);
  }

  // TREINO continua sem comunicação nenhuma, inclusive de sistema: não há
  // ninguém para ler. `permissaoDe` responde `nenhuma`, e a resposta vale
  // também aqui — a autoridade não fala sozinha para uma mesa de robôs.
  if (!permissaoDe(canal.ambiente, canal.modo).algumaCoisa &&
      canal.ambiente == AmbienteDeComunicacao.treino) {
    return VereditoComunicacao.recusada(
        RecusaComunicacao.ambienteSemComunicacao);
  }

  // A ENTREGA DO EVENTO DE SISTEMA NÃO É FILTRADA POR BLOQUEIO NEM POR SILÊNCIO.
  //
  // §9.2, última linha: "preserva comandos necessários do sistema e do jogo".
  // Um jogador que bloqueou outro continua precisando saber que a sala foi
  // encerrada. O silêncio e o bloqueio são sobre PESSOAS, e um evento de
  // sistema não tem pessoa: ele não tem `autorPublicId`.
  final todos = [
    for (final p in canal.canal.participantes)
      if (p.papel == PapelNoCanal.jogadorSentado ||
          p.papel == PapelNoCanal.presenteNoAmbiente)
        p.uid,
  ];

  return VereditoComunicacao.aceita(
    messageId: mensagemIdDe(autorUid: 'sistema', intentId: intentId),
    impressao: impressaoDaComunicacao(
      ambiente: canal.ambiente,
      canalId: canal.canalId,
      tipo: TipoDeComunicacao.eventoDeSistema,
      itemId: evento.id,
    ),
    tipo: TipoDeComunicacao.eventoDeSistema,
    ambiente: canal.ambiente,
    itemId: evento.id,
    chaveDeLocalizacao: evento.chaveDeLocalizacao,
    fallbackOficial: evento.fallbackOficial,
    destinatarios: todos,
    silenciados: const [],
    proximoRitmo: const EstadoDeRitmo(),
  );
}
