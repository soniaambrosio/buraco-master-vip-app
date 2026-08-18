// porta.dart — A PORTA ÚNICA do chat livre.
//
// Uma mensagem de chat só existe se [avaliarEnvio] disser que existe. Não há
// segundo caminho, não há atalho para superfície nova, e não há `if` de política
// espalhado no TypeScript: functions-moderacao/src/index.ts autentica, lê e
// grava, mas quem DECIDE é este arquivo. É a mesma repartição que o cabeçalho de
// functions-moderacao/src/index.ts já declara para denúncia e sanção.
//
// AS DUAS PERGUNTAS SÃO DIFERENTES, e confundi-las é o erro que este arquivo
// evita:
//
//   1. A MENSAGEM EXISTE?  Vale para o autor, uma vez. Conteúdo, superfície,
//      assento, intenção, sanção. Uma sanção de chat não é "sobre um par": ela
//      cala o autor para a mesa inteira.
//
//   2. QUEM RECEBE?  Vale por PAR. Bloqueio é escolha pessoal entre duas
//      pessoas: numa mesa de quatro, quem me bloqueou não me lê, e os outros
//      dois leem. Recusar a mensagem inteira porque UM jogador me bloqueou
//      entregaria a qualquer um o poder de me calar na mesa; entregar a mensagem
//      a quem me bloqueou tornaria o bloqueio decorativo. Filtrar por par é a
//      única resposta que não é nenhuma das duas.
//
// O BLOQUEIO É CONSUMIDO, NUNCA REDECIDIDO. A pergunta "este par pode se falar?"
// tem UMA resposta no projeto, e ela está em `avaliarContato`
// (app/lib/moderacao/relacao_social.dart), inclusive a decisão de que o efeito é
// simétrico mesmo com registro unilateral. Este arquivo chama aquela função por
// par e obedece. Reescrever a regra aqui criaria a segunda autoridade que a OS
// proíbe em §7.

import '../moderacao/relacao_social.dart';
import '../moderacao/validacao.dart';
import 'mensagem.dart';
import 'superficie.dart';

/// Quem está no canal, e em que papel.
///
/// `uid` é interno e nunca sai numa projeção — ver [MensagemPublica]. Ele existe
/// aqui porque bloqueio é relação entre UIDs, e a filtragem acontece antes de
/// qualquer coisa virar `publicId`.
class ParticipanteDoCanal {
  final String uid;
  final PapelNoCanal papel;

  const ParticipanteDoCanal({required this.uid, required this.papel});
}

/// O CANAL, como a autoridade o conhece.
///
/// CONTEXTO ESTÁVEL (§10). O que identifica onde a mensagem pertence: o id do
/// canal, a superfície, quem está sentado. Nada aqui é conexão, socket, geração
/// de transporte ou instante de retry — uma reconexão legítima não muda nenhum
/// campo desta classe, e é por isso que ela pode sustentar idempotência.
///
/// NÃO VEM DO PAYLOAD. Vem do documento autoritativo `chatChannels/{canalId}`,
/// escrito pelo motor de partidas. A diferença é a fronteira inteira: se a lista
/// de participantes viesse do cliente, qualquer jogador se declararia sentado
/// numa mesa que nunca viu, ou se declararia sozinho para escapar do filtro de
/// bloqueio (§4).
class CanalDeChat {
  final String canalId;
  final SuperficieChat superficie;

  /// Canal fechado não aceita mensagem nova. Partida encerrada não recebe fala.
  final bool aberto;

  final List<ParticipanteDoCanal> participantes;

  const CanalDeChat({
    required this.canalId,
    required this.superficie,
    required this.participantes,
    this.aberto = true,
  });

  /// O papel de [uid] neste canal. Quem não consta está [PapelNoCanal.foraDoCanal].
  PapelNoCanal papelDe(String uid) {
    for (final p in participantes) {
      if (p.uid == uid) return p.papel;
    }
    return PapelNoCanal.foraDoCanal;
  }

  /// Os candidatos a receber: quem está SENTADO, menos o próprio autor.
  ///
  /// Espectador não entra, e a ausência é a decisão da §11 aplicada na direção
  /// que se esquece: não basta impedir o espectador de falar, é preciso não
  /// entregar a ele a conversa dos jogadores. Receber é metade de conversar.
  List<String> assentosExceto(String autorUid) => [
        for (final p in participantes)
          if (p.papel == PapelNoCanal.jogadorSentado && p.uid != autorUid) p.uid,
      ];
}

/// O estado disciplinar de quem escreve, já consolidado e já comparado ao
/// relógio pelo servidor.
///
/// Booleanos, e não datas, de propósito: o relógio pertence a quem executa, e
/// congelá-lo UMA vez por operação é o que impede a primeira checagem dizer
/// "silenciado" e a segunda, milissegundos depois, dizer "livre". É a mesma
/// postura do cabeçalho de app/lib/moderacao/sancao.dart.
class SancaoDoAutor {
  /// `chatSilenciadoAte` em vigor. Vem de `TipoSancao.muteTemporario`.
  final bool chatSilenciado;

  /// `socialRestritoAte` em vigor. Vem de `TipoSancao.restricaoSocial`.
  final bool restricaoSocial;

  /// Suspensão em vigor: `suspensoAte` OU `suspensaoPermanente`.
  ///
  /// POR QUE A SUSPENSÃO ENTRA AQUI, e por que isso NÃO é política inventada
  /// (§8): `TipoSancao.suspensaoTemporaria` está documentada em
  /// app/lib/moderacao/sancao.dart como "impede entrar na aplicação por um
  /// prazo". Quem não entra na aplicação não fala na mesa — negar o chat é
  /// leitura literal do efeito já escrito, não uma regra nova.
  ///
  /// A LACUNA QUE ISTO NÃO FECHA, e que fica declarada: `consultarContato`
  /// (functions-moderacao/src/index.ts) e functions-social/src/repositorio.ts
  /// consultam `suspensaoPermanente` mas NÃO consultam `suspensoAte`. Ou seja:
  /// nas rotas sociais, uma suspensão TEMPORÁRIA hoje não impede convite nem
  /// pedido de amizade. Esta OS não mexe naquelas rotas — mudar o veredito de
  /// `avaliarContato` alteraria o comportamento de amizade e convite, que estão
  /// fora do seu escopo. O chat nasce fechado; a correção das rotas sociais é
  /// pendência registrada no laudo.
  final bool suspenso;

  const SancaoDoAutor({
    this.chatSilenciado = false,
    this.restricaoSocial = false,
    this.suspenso = false,
  });
}

/// O bloqueio entre o autor e UM candidato, nas duas direções.
///
/// Duas leituras por par, e não uma: a §7 é explícita em recusar as duas
/// direções, e `avaliarContato` recebe as duas justamente para que quem chama não
/// possa "esquecer" a volta.
class ParDeContato {
  final String uid;
  final bool autorBloqueou;
  final bool bloqueouOAutor;

  const ParDeContato({
    required this.uid,
    this.autorBloqueou = false,
    this.bloqueouOAutor = false,
  });
}

/// O resultado da porta.
class VereditoEnvio {
  final bool aceita;
  final RecusaMensagem? recusa;

  /// Só vem quando [recusa] é [RecusaMensagem.contatoRecusado]: o motivo no
  /// vocabulário canônico da moderação.
  final MotivoContatoRecusado? motivoContato;

  /// Campos que o cliente mandou e não podia mandar. Preenchido apenas na recusa
  /// [RecusaMensagem.payloadComCampoProibido], para que o laudo e o log digam
  /// QUAL campo — sem isso, a recusa é indistinguível de um bug de serialização.
  final List<String> camposProibidos;

  /// Só quando aceita: o id derivado, o digest do pedido e o texto já aparado.
  final String? messageId;
  final String? impressao;
  final String? conteudo;

  /// Só quando aceita: os UIDs que devem receber. Já filtrado por bloqueio nas
  /// duas direções. NUNCA vai para o cliente — é lista de UID, e
  /// `kChavesProibidasNaEntrega` recusa `destinatarios` numa entrega.
  final List<String> destinatarios;

  const VereditoEnvio.aceita({
    required String this.messageId,
    required String this.impressao,
    required String this.conteudo,
    required this.destinatarios,
  })  : aceita = true,
        recusa = null,
        motivoContato = null,
        camposProibidos = const [];

  const VereditoEnvio.recusada(
    this.recusa, {
    this.motivoContato,
    this.camposProibidos = const [],
  })  : aceita = false,
        messageId = null,
        impressao = null,
        conteudo = null,
        destinatarios = const [];

  Map<String, Object?> toJson() => {
        'aceita': aceita,
        'recusa': recusa?.name,
        'motivoContato': motivoContato?.name,
        'camposProibidos': camposProibidos,
        if (aceita) 'messageId': messageId,
        if (aceita) 'impressao': impressao,
        if (aceita) 'conteudo': conteudo,
        if (aceita) 'destinatarios': destinatarios,
      };
}

/// A porta. Decide se a mensagem existe e para quem ela vai.
///
/// [autorUid] é o UID AUTENTICADO, e a assinatura desta função é parte da prova:
/// não existe parâmetro por onde entre um autor alegado. Se o payload trouxer
/// `autorUid`, ele cai em [kCamposProibidosNoEnvio] e o pedido inteiro é
/// recusado — a mensagem não muda de dono, e a chamada não segue em silêncio.
///
/// A ORDEM DAS PERGUNTAS não é estética. Do mais barato e mais estrutural ao mais
/// caro: primeiro o que está errado no formato do pedido, depois a superfície,
/// depois quem é o autor no canal, depois o disciplinar, e só então a filtragem
/// por par. Nenhuma resposta muda com a ordem — qualquer recusa recusa — mas a
/// recusa devolvida é a mais informativa, e nenhuma leitura de bloqueio é feita
/// para um pedido que já estava malformado.
VereditoEnvio avaliarEnvio({
  required String autorUid,
  required String intentId,
  required Object? conteudoBruto,
  required Object? superficiePedida,
  required CanalDeChat? canal,
  required SancaoDoAutor sancao,
  required List<ParDeContato> contatos,
  Map<String, Object?> payloadCru = const {},
  String? autorPublicId,
}) {
  // 1. O pedido trouxe o que não devia? (§4, §10, §13)
  final proibidos = [
    for (final k in payloadCru.keys)
      if (kCamposProibidosNoEnvio.contains(k)) k,
  ]..sort();
  if (proibidos.isNotEmpty) {
    return VereditoEnvio.recusada(
      RecusaMensagem.payloadComCampoProibido,
      camposProibidos: proibidos,
    );
  }

  // 2. Identificadores. `identificadorValido` recusa vazio, longo, com `|` e
  //    fora de [A-Za-z0-9_-] — o mesmo crivo que a moderação já usa.
  if (!identificadorValido(intentId)) {
    return const VereditoEnvio.recusada(RecusaMensagem.intencaoInvalida);
  }

  // 3. A superfície existe e aceita texto livre? (§11)
  final superficie = SuperficieChat.porWire(superficiePedida);
  if (superficie == null || !superficieAceitaTextoLivre(superficie)) {
    return const VereditoEnvio.recusada(
        RecusaMensagem.superficieNaoAceitaChat);
  }

  // 4. O canal é autoritativo, e é DELE que sai a superfície efetiva.
  //
  //    Conferir que a superfície pedida bate com a do canal fecha uma porta
  //    concreta: sem isso, alguém mandaria `superficie: mesa_de_partida` sobre um
  //    canal de saguão e escaparia da classificação da §11 pelo nome do campo.
  if (canal == null) {
    return const VereditoEnvio.recusada(RecusaMensagem.canalDesconhecido);
  }
  if (!identificadorValido(canal.canalId) || canal.superficie != superficie) {
    return const VereditoEnvio.recusada(RecusaMensagem.canalInvalido);
  }
  if (!canal.aberto) {
    return const VereditoEnvio.recusada(RecusaMensagem.canalFechado);
  }

  // 5. Quem escreve ocupa assento? Espectador e quem já saiu não falam (§11).
  if (canal.papelDe(autorUid) != PapelNoCanal.jogadorSentado) {
    return const VereditoEnvio.recusada(RecusaMensagem.papelSemDireitoDeFala);
  }

  // 6. O conteúdo (§6). Texto livre, com limites operacionais.
  //
  //    O tipo vem ANTES do resto: Map, List e número não são "texto vazio", são
  //    payload estrutural no lugar de conteúdo, e merecem recusa própria para que
  //    o caso apareça no log como o que é.
  if (conteudoBruto is! String) {
    return const VereditoEnvio.recusada(RecusaMensagem.conteudoNaoTexto);
  }
  final conteudo = normalizarConteudo(conteudoBruto);
  if (conteudo == null) {
    return const VereditoEnvio.recusada(RecusaMensagem.conteudoVazio);
  }
  if (temCaractereDeControle(conteudo)) {
    return const VereditoEnvio.recusada(
        RecusaMensagem.conteudoComCaractereDeControle);
  }
  if (tamanhoDeMensagem(conteudo) > kLimiteMensagem) {
    return const VereditoEnvio.recusada(
        RecusaMensagem.conteudoAcimaDoLimite);
  }

  // 7. Identidade pública. Sem `publicId` não há como nomear o autor sem expor o
  //    UID, então a recusa é a alternativa correta — e NÃO cunhar um publicId
  //    aqui é deliberado: a autoridade de identidade pública é functions-social,
  //    e uma segunda cunhagem criaria duas identidades para a mesma pessoa (§5).
  if (autorPublicId == null || autorPublicId.isEmpty) {
    return const VereditoEnvio.recusada(
        RecusaMensagem.identidadePublicaAusente);
  }

  // 8. Sanção sobre QUEM ESCREVE (§8). Vale para a mesa inteira, não por par.
  if (sancao.suspenso) {
    return const VereditoEnvio.recusada(RecusaMensagem.suspensaoImpedeChat);
  }
  if (sancao.restricaoSocial) {
    return const VereditoEnvio.recusada(
      RecusaMensagem.contatoRecusado,
      motivoContato: MotivoContatoRecusado.restricaoSocial,
    );
  }
  if (sancao.chatSilenciado) {
    return const VereditoEnvio.recusada(
      RecusaMensagem.contatoRecusado,
      motivoContato: MotivoContatoRecusado.chatSilenciadoPorSancao,
    );
  }

  // 9. Quem recebe. Por PAR, consumindo `avaliarContato`.
  final assentos = canal.assentosExceto(autorUid);
  if (assentos.isEmpty) {
    return const VereditoEnvio.recusada(RecusaMensagem.semDestinatarios);
  }

  final porUid = {for (final c in contatos) c.uid: c};
  final permitidos = <String>[];
  MotivoContatoRecusado? ultimoMotivo;

  for (final uid in assentos) {
    // Par sem leitura de bloqueio é tratado como SEM bloqueio, e não como
    // permitido por omissão: quem executa é obrigado a entregar um `ParDeContato`
    // por assento. A ausência aqui significa "nada gravado", que é o estado
    // normal de duas pessoas que nunca se bloquearam.
    final par = porUid[uid] ?? ParDeContato(uid: uid);

    // A sanção já foi decidida no passo 8, para a mesa inteira. Passá-la de novo
    // aqui faria `avaliarContato` devolver "silenciado" em vez do motivo do par,
    // e o motivo do par é o que interessa nesta etapa.
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

  // Ninguém sobrou: havia gente sentada, e o bloqueio zerou a lista. Responder
  // sucesso aqui deixaria o jogador falando com uma parede acreditando que foi
  // lido — que é justamente o que a §7 quer impedir na mesa de duas pessoas.
  if (permitidos.isEmpty) {
    return VereditoEnvio.recusada(
      RecusaMensagem.contatoRecusado,
      motivoContato: ultimoMotivo,
    );
  }

  return VereditoEnvio.aceita(
    messageId: mensagemIdDe(autorUid: autorUid, intentId: intentId),
    impressao: impressaoDoEnvio(
      superficie: superficie,
      canalId: canal.canalId,
      conteudo: conteudo,
    ),
    conteudo: conteudo,
    destinatarios: permitidos,
  );
}
