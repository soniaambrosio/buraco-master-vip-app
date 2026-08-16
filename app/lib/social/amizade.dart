// amizade.dart — o grafo social (OS §12 a §18, §25 a §27, §31-A e §31-B).
//
// AMIZADE É BILATERAL, E ISSO É UMA DECISÃO DE MODELO, NÃO DE VOCABULÁRIO (§12).
// Existe UM documento por par, e não um "A segue B" mais um "B segue A". A razão
// é que dois documentos podem discordar: basta uma escrita falhar e o sistema
// passa a ter A que lista B e B que não lista A — a "relação unilateral fantasma"
// que §17 proíbe. Com um documento só, esse estado não é raro: é impossível.
//
// ---------------------------------------------------------------------------
// O QUE ESTE ARQUIVO NÃO FAZ, E POR QUÊ
// ---------------------------------------------------------------------------
//
// NÃO EXISTE ESTADO `bloqueada` EM [EstadoAmizade]. §12 lista "relação bloqueada
// pelo domínio de bloqueio existente" entre os estados necessários, e a forma
// CERTA de atender isso é justamente não guardá-lo aqui: o bloqueio canônico
// mora em `users/{uid}/blocks/{alvo}`, escrito por `bloquearJogador` no codebase
// de moderação. Gravar um espelho dele em `friendships` criaria a segunda
// infraestrutura de bloqueio que §18 e §40 proíbem — e a cópia divergiria da
// original no primeiro desbloqueio que não propagasse.
//
// O bloqueio entra aqui como PARÂMETRO (`contatoPermitido`), vindo de
// `avaliarContato` em `moderacao/relacao_social.dart`, que é a "porta única das
// rotas sociais" que aquela OS deixou pronta esperando por esta. E aparece na
// leitura como [RelacaoVista.bloqueadoPorMim] / [RelacaoVista.indisponivel], que
// são VISTAS compostas na hora, não estado persistido.
//
// MUTE NÃO APARECE NESTE ARQUIVO, EM LUGAR NENHUM (§19). Silêncio pessoal é
// preferência de exibição; ele não remove amizade, não impede amizade e não
// altera o grafo. A ausência é a implementação.
//
// ---------------------------------------------------------------------------
// IDEMPOTÊNCIA POR CONSTRUÇÃO, NÃO POR BARREIRA (§26)
// ---------------------------------------------------------------------------
//
// A moderação precisou de `moderationTasks` porque duas denúncias do mesmo
// jogador contra o mesmo alvo são fatos DIFERENTES — só o `reportIntentId`
// distingue "denunciei de novo" de "o botão repetiu". Aqui não: o estado da
// relação entre dois jogadores é único e a chave do documento é função do par.
// Enviar duas vezes encontra a mesma pendência; aceitar duas vezes encontra a
// amizade já feita; remover duas vezes encontra o vazio. Não há nada para uma
// tabela de intenções distinguir, e criar uma seria custo sem garantia nova.
//
// Por isso todo veredito carrega [VereditoAmizade.repeticao]: é o sinal de que a
// operação não mudou nada MAS o desfecho pedido já vale — quem chama responde
// sucesso, no mesmo padrão de `jaRegistrada: true` da denúncia. Responder erro
// aqui faria o cliente tentar de novo, e a próxima também "falharia".

import '../moderacao/validacao.dart';
import 'erros_sociais.dart';

// ===========================================================================
// LIMITES (§25)
// ===========================================================================

/// Teto de amizades ativas por jogador.
const int kLimiteAmigos = 200;

/// Teto de solicitações pendentes ENVIADAS por jogador.
const int kLimiteSolicitacoesEnviadas = 50;

/// NÃO EXISTE teto de solicitações RECEBIDAS, e a ausência é a implementação de
/// §25: "Solicitações recebidas não devem poder ser usadas pelo atacante para
/// impedir permanentemente o usuário de utilizar o sistema."
///
/// Um teto de recebidas seria uma arma: contas descartáveis enchem a caixa da
/// vítima até o limite e ninguém mais consegue adicioná-la — para sempre, porque
/// as pendências não expiram. O custo de não ter teto é uma lista longa, que a
/// paginação de §23 resolve.
const int? kLimiteSolicitacoesRecebidas = null;

// ===========================================================================
// A CHAVE DO PAR (§20)
// ===========================================================================

/// A chave canônica da relação entre dois jogadores.
///
/// Os dois UIDs ORDENADOS e juntados por `|`. Determinística e calculada pelo
/// servidor, como §20 pede — e é ela que torna impossível existirem `A-B` e
/// `B-A` como documentos distintos: as duas chamadas produzem o mesmo texto,
/// então a segunda encontra o documento da primeira em vez de criar outro.
///
/// POR QUE OS UIDS CRUS, e não um hash: a chave nunca sai do backend
/// (`friendships` é negada ao cliente em qualquer leitura, ver firestore.rules),
/// e um hash tornaria impossível investigar uma relação a partir de um UID
/// conhecido sem varrer a coleção. O separador é o mesmo `|` que as chaves de
/// torneio e de moderação já usam, e [identificadorValido] proíbe `|` dentro dos
/// componentes — por isso a chave não pode ser ambígua.
String chaveDoPar(String uidA, String uidB) {
  if (!identificadorValido(uidA) || !identificadorValido(uidB)) {
    throw ArgumentError('chaveDoPar exige identificadores válidos');
  }
  if (uidA == uidB) {
    throw ArgumentError('chaveDoPar: não existe par de um jogador consigo');
  }
  final ordenados = [uidA, uidB]..sort();
  return '${ordenados[0]}$kSeparadorChave${ordenados[1]}';
}

/// Os dois membros em ordem estável. Gravado no documento para sustentar a
/// consulta `array-contains` da lista de amigos.
List<String> membrosOrdenados(String uidA, String uidB) =>
    [uidA, uidB]..sort();

// ===========================================================================
// ESTADO CANÔNICO
// ===========================================================================

/// O estado da relação, do ponto de vista do BANCO (não do jogador).
///
/// Só três, e "nenhuma" é a AUSÊNCIA do documento — recusar, cancelar e remover
/// apagam. Guardar um `estado: 'recusada'` criaria uma lápide que ninguém
/// consulta e que precisaria de política de expiração própria; e, pior, faria
/// "não somos nada" ter duas representações (documento ausente e documento
/// recusado), que é o tipo de ambiguidade que produz bug de idempotência.
enum EstadoAmizade {
  nenhuma,
  pendente,
  amigos;

  static EstadoAmizade porNome(Object? nome) {
    for (final e in EstadoAmizade.values) {
      if (e.name == nome) return e;
    }
    return EstadoAmizade.nenhuma;
  }
}

/// A relação canônica entre dois jogadores — o documento `friendships/{pairKey}`.
class RelacaoAmizade {
  final String pairKey;

  /// Os dois UIDs, ordenados. INTERNO: nunca sai numa resposta ao cliente (§21).
  final List<String> membros;

  final EstadoAmizade estado;

  /// Quem pediu e quem recebeu. Só fazem sentido em [EstadoAmizade.pendente], e
  /// continuam gravados depois do aceite porque a pergunta "quem convidou quem?"
  /// é legítima e barata de responder.
  final String? solicitanteUid;
  final String? destinatarioUid;

  final String? solicitadaEm;
  final String? amigosDesde;

  /// `uid -> publicId` dos dois membros.
  ///
  /// DENORMALIZAÇÃO DELIBERADA, e a única deste arquivo. O `publicId` é imutável
  /// (§9), então esta cópia não pode ficar velha — não existe evento que a
  /// invalide. É o que permite montar a lista de amigos sem uma segunda ida ao
  /// mapa de identidades por amigo.
  ///
  /// Apelido e avatar NÃO estão aqui, e a ausência é o ponto: eles MUDAM. Copiá-los
  /// exigiria reescrever até 200 documentos a cada troca de apelido, e §31-I
  /// pede que a troca apareça imediatamente. Resolver a apresentação na leitura
  /// faz isso valer por construção, sem trabalho de reconciliação nenhum.
  final Map<String, String> publicIds;

  const RelacaoAmizade({
    required this.pairKey,
    required this.membros,
    required this.estado,
    this.solicitanteUid,
    this.destinatarioUid,
    this.solicitadaEm,
    this.amigosDesde,
    this.publicIds = const {},
  });

  /// A relação inexistente. Devolvida quando o documento não está lá — para que
  /// quem lê nunca precise tratar `null` e esquecer um caso.
  factory RelacaoAmizade.nenhuma(String uidA, String uidB) => RelacaoAmizade(
        pairKey: chaveDoPar(uidA, uidB),
        membros: membrosOrdenados(uidA, uidB),
        estado: EstadoAmizade.nenhuma,
      );

  /// O outro membro do par, visto por [uid].
  String? outroMembro(String uid) {
    for (final m in membros) {
      if (m != uid) return m;
    }
    return null;
  }

  bool contem(String uid) => membros.contains(uid);

  Map<String, Object?> toJson() => {
        'pairKey': pairKey,
        'membros': membros,
        'estado': estado.name,
        'solicitanteUid': solicitanteUid,
        'destinatarioUid': destinatarioUid,
        'solicitadaEm': solicitadaEm,
        'amigosDesde': amigosDesde,
        'publicIds': publicIds,
        'esquema': kEsquemaSocial,
      };

  static RelacaoAmizade deJson(Map<String, Object?> raw) {
    final membros = ((raw['membros'] as List?) ?? const [])
        .whereType<String>()
        .toList(growable: false);
    final ids = <String, String>{};
    (raw['publicIds'] as Map?)?.forEach((k, v) {
      if (k is String && v is String) ids[k] = v;
    });
    return RelacaoAmizade(
      pairKey: '${raw['pairKey']}',
      membros: membros,
      estado: EstadoAmizade.porNome(raw['estado']),
      solicitanteUid: raw['solicitanteUid'] as String?,
      destinatarioUid: raw['destinatarioUid'] as String?,
      solicitadaEm: raw['solicitadaEm'] as String?,
      amigosDesde: raw['amigosDesde'] as String?,
      publicIds: ids,
    );
  }
}

// ===========================================================================
// VEREDITOS
// ===========================================================================

/// O que o servidor deve FAZER depois de um veredito aceito.
enum AcaoAmizade {
  /// Criar a pendência A -> B.
  criarSolicitacao,

  /// §27, primeiro cenário: já existia pendência no sentido INVERSO, então este
  /// pedido é um aceite disfarçado.
  ///
  /// A alternativa que §27 permite (recusar a duplicidade e exigir aceite
  /// normal) foi descartada porque produz uma tela sem saída: os dois jogadores
  /// se convidaram, os dois veem "solicitação enviada", e nenhum dos dois vê o
  /// botão de aceitar. Interpretar como aceite é o desfecho que o jogador espera
  /// e é determinístico — quem chega por último aceita.
  aceitarInversa,

  /// Fechar a amizade a partir da pendência existente.
  aceitar,

  /// Apagar o documento da relação.
  apagar,

  /// Não fazer nada (repetição ou recusa).
  nenhuma,
}

class VereditoAmizade {
  final bool aceita;
  final ErroSocial? recusa;
  final AcaoAmizade acao;

  /// O desfecho pedido JÁ VALE, e nada mudou.
  ///
  /// Quem chama responde SUCESSO, com uma marca de repetição — nunca erro. Ver o
  /// cabeçalho deste arquivo.
  final bool repeticao;

  const VereditoAmizade.aceita(this.acao)
      : aceita = true,
        recusa = null,
        repeticao = false;

  const VereditoAmizade.repetida(this.recusa)
      : aceita = false,
        acao = AcaoAmizade.nenhuma,
        repeticao = true;

  const VereditoAmizade.recusada(this.recusa)
      : aceita = false,
        acao = AcaoAmizade.nenhuma,
        repeticao = false;

  Map<String, Object?> toJson() => {
        'aceita': aceita,
        'recusa': recusa?.name,
        'acao': acao.name,
        'repeticao': repeticao,
      };
}

// ===========================================================================
// OPERAÇÕES
// ===========================================================================

/// Avalia um pedido de amizade (§13 e §27).
///
/// [contatoPermitido] vem de `avaliarContato` (moderação). É a soberania do
/// bloqueio entrando no grafo por um parâmetro só — e é por isso que não há como
/// esquecer de checar: sem ele a função não compila.
///
/// [amigosDoDestinatario] só é consultado no caminho de [AcaoAmizade.aceitarInversa],
/// porque ali quem chama está de fato ACEITANDO. No pedido comum ele é ignorado
/// de propósito: recusar por lotação alheia contaria ao solicitante quantos
/// amigos o alvo tem, e essa contagem não é dele.
VereditoAmizade avaliarSolicitacao({
  required String solicitanteUid,
  required String destinatarioUid,
  required EstadoAmizade estadoAtual,
  String? solicitantePendenteUid,
  required bool contatoPermitido,
  required int amigosDoSolicitante,
  required int amigosDoDestinatario,
  required int pendentesEnviadasDoSolicitante,
}) {
  if (!identificadorValido(solicitanteUid) ||
      !identificadorValido(destinatarioUid)) {
    return const VereditoAmizade.recusada(ErroSocial.identificadorInvalido);
  }
  if (solicitanteUid == destinatarioUid) {
    return const VereditoAmizade.recusada(ErroSocial.autoAmizadeInvalida);
  }
  // O BLOQUEIO VEM ANTES DE TUDO (§18, §31-H). Antes até de `jaSaoAmigos`: se há
  // bloqueio, a resposta não deve nem confirmar que existe relação.
  if (!contatoPermitido) {
    return const VereditoAmizade.recusada(ErroSocial.relacaoBloqueada);
  }

  switch (estadoAtual) {
    case EstadoAmizade.amigos:
      return const VereditoAmizade.recusada(ErroSocial.jaSaoAmigos);

    case EstadoAmizade.pendente:
      if (solicitantePendenteUid == solicitanteUid) {
        // Toque duplo, retry após timeout, reconexão no meio do envio.
        return const VereditoAmizade.repetida(ErroSocial.solicitacaoJaExiste);
      }
      // Pendência no sentido inverso: este pedido é o aceite dela.
      if (amigosDoSolicitante >= kLimiteAmigos ||
          amigosDoDestinatario >= kLimiteAmigos) {
        return const VereditoAmizade.recusada(ErroSocial.limiteAmigos);
      }
      return const VereditoAmizade.aceita(AcaoAmizade.aceitarInversa);

    case EstadoAmizade.nenhuma:
      if (amigosDoSolicitante >= kLimiteAmigos) {
        return const VereditoAmizade.recusada(ErroSocial.limiteAmigos);
      }
      if (pendentesEnviadasDoSolicitante >= kLimiteSolicitacoesEnviadas) {
        return const VereditoAmizade.recusada(ErroSocial.limiteSolicitacoes);
      }
      return const VereditoAmizade.aceita(AcaoAmizade.criarSolicitacao);
  }
}

/// Avalia um aceite (§14).
///
/// SOMENTE O DESTINATÁRIO ACEITA. Sem esta checagem, o próprio remetente
/// fecharia a amizade que ele mesmo pediu — que é a definição de adicionar
/// alguém sem permissão.
VereditoAmizade avaliarAceite({
  required String uidQueAceita,
  required EstadoAmizade estadoAtual,
  String? destinatarioPendenteUid,
  required bool contatoPermitido,
  required int amigosDeQuemAceita,
  required int amigosDoOutro,
}) {
  if (!identificadorValido(uidQueAceita)) {
    return const VereditoAmizade.recusada(ErroSocial.identificadorInvalido);
  }
  // §27, segundo cenário: "A aceita enquanto B bloqueia A — bloqueio deve
  // prevalecer. Não pode terminar em amizade ativa contra um bloqueio
  // confirmado." Esta linha é essa exigência.
  if (!contatoPermitido) {
    return const VereditoAmizade.recusada(ErroSocial.relacaoBloqueada);
  }
  if (estadoAtual == EstadoAmizade.amigos) {
    // Aceitar duas vezes. O desfecho pedido já vale.
    return const VereditoAmizade.repetida(ErroSocial.jaSaoAmigos);
  }
  if (estadoAtual == EstadoAmizade.nenhuma) {
    return const VereditoAmizade.recusada(ErroSocial.solicitacaoNaoEncontrada);
  }
  if (destinatarioPendenteUid != uidQueAceita) {
    return const VereditoAmizade.recusada(ErroSocial.naoEDestinatario);
  }
  if (amigosDeQuemAceita >= kLimiteAmigos || amigosDoOutro >= kLimiteAmigos) {
    return const VereditoAmizade.recusada(ErroSocial.limiteAmigos);
  }
  return const VereditoAmizade.aceita(AcaoAmizade.aceitar);
}

/// Avalia uma recusa (§15).
///
/// Recusar não cria amizade, não pune e NÃO bloqueia o remetente. Só encerra a
/// pendência — o documento é apagado.
VereditoAmizade avaliarRecusa({
  required String uidQueRecusa,
  required EstadoAmizade estadoAtual,
  String? destinatarioPendenteUid,
}) {
  if (estadoAtual == EstadoAmizade.nenhuma) {
    // Recusar duas vezes: a segunda não encontra nada, e isso é sucesso.
    return const VereditoAmizade.repetida(ErroSocial.solicitacaoNaoEncontrada);
  }
  if (estadoAtual == EstadoAmizade.amigos) {
    // Não há pendência para recusar. E recusar NÃO pode virar um atalho para
    // desfazer amizade: são operações diferentes, com telas diferentes.
    return const VereditoAmizade.recusada(ErroSocial.solicitacaoNaoEncontrada);
  }
  if (destinatarioPendenteUid != uidQueRecusa) {
    return const VereditoAmizade.recusada(ErroSocial.naoEDestinatario);
  }
  return const VereditoAmizade.aceita(AcaoAmizade.apagar);
}

/// Avalia um cancelamento (§16).
///
/// SOMENTE O REMETENTE CANCELA. §16 é explícita: "Destinatário não pode
/// cancelá-la em nome do remetente; pode recusá-la." A diferença importa porque
/// as duas ações contam histórias diferentes para quem as recebe.
VereditoAmizade avaliarCancelamento({
  required String uidQueCancela,
  required EstadoAmizade estadoAtual,
  String? solicitantePendenteUid,
}) {
  if (estadoAtual == EstadoAmizade.nenhuma) {
    return const VereditoAmizade.repetida(ErroSocial.solicitacaoNaoEncontrada);
  }
  if (estadoAtual == EstadoAmizade.amigos) {
    return const VereditoAmizade.recusada(ErroSocial.solicitacaoNaoEncontrada);
  }
  if (solicitantePendenteUid != uidQueCancela) {
    return const VereditoAmizade.recusada(ErroSocial.naoERemetente);
  }
  return const VereditoAmizade.aceita(AcaoAmizade.apagar);
}

/// Avalia a remoção de uma amizade (§17).
///
/// QUALQUER UM DOS DOIS remove, e a remoção é bilateral porque o documento é um
/// só. Não vira bloqueio: §17 é explícita.
///
/// Quando não há amizade, o resultado é REPETIÇÃO e não erro — a pós-condição
/// pedida ("A e B não são amigos") já vale. E o caminho de repetição NÃO apaga
/// nada, o que é o detalhe que impede "remover amigo" de virar um cancelamento
/// silencioso de solicitação pendente.
VereditoAmizade avaliarRemocao({
  required String uidQueRemove,
  required EstadoAmizade estadoAtual,
  required bool ehMembro,
}) {
  if (!ehMembro) {
    // Tentativa de desfazer amizade alheia. Não é repetição: é operação sobre
    // relação de terceiros.
    return const VereditoAmizade.recusada(ErroSocial.naoEDestinatario);
  }
  if (estadoAtual != EstadoAmizade.amigos) {
    return const VereditoAmizade.repetida(ErroSocial.jaSaoAmigos);
  }
  return const VereditoAmizade.aceita(AcaoAmizade.apagar);
}

// ===========================================================================
// A VISTA DO JOGADOR (§31-A e §31-B)
// ===========================================================================

/// A relação entre o jogador autenticado e o perfil que ele está olhando.
///
/// COMPOSIÇÃO, NÃO PERSISTÊNCIA: nasce de [EstadoAmizade] mais o veredito de
/// contato da moderação, calculada na hora da leitura. É o que garante que o
/// bloqueio continue soberano sem existir um segundo lugar onde ele more.
enum RelacaoVista {
  nenhuma,
  solicitacaoEnviada,
  solicitacaoRecebida,
  amigos,

  /// O próprio jogador bloqueou o alvo. Ele sabe disso — foi ele quem fez —,
  /// então a tela pode dizer e oferecer desbloquear.
  bloqueadoPorMim,

  /// Interação impossível por decisão do OUTRO lado, ou por sanção social.
  ///
  /// UM ESTADO SÓ PARA DOIS FATOS DIFERENTES, de propósito (§31-B: "Não expor
  /// texto do tipo `Fulano bloqueou você`"). O cliente sabe que não pode
  /// interagir; não sabe por quê, e não precisa saber.
  indisponivel,

  /// É o próprio perfil.
  euMesmo;

  static RelacaoVista porNome(Object? nome) {
    for (final r in RelacaoVista.values) {
      if (r.name == nome) return r;
    }
    return RelacaoVista.nenhuma;
  }
}

/// As ações que a interface pode oferecer (§31-B).
enum AcaoSocial {
  adicionarAmigo,
  cancelarSolicitacao,
  aceitarSolicitacao,
  recusarSolicitacao,
  removerAmigo,
  bloquear,
  desbloquear,
  editarPerfil,
}

/// Compõe a vista a partir do estado canônico e do bloqueio.
///
/// A ORDEM DAS PERGUNTAS É A POLÍTICA. Bloqueio antes de amizade: se há bloqueio,
/// a resposta não menciona a amizade que ainda não foi desfeita pelo gatilho —
/// e é isso que fecha a janela entre "bloqueei agora" e "o gatilho já rodou".
RelacaoVista vistaDaRelacao({
  required String uidObservador,
  required String uidAlvo,
  required EstadoAmizade estado,
  String? solicitanteUid,
  required bool euBloqueeiOAlvo,
  required bool contatoPermitido,
}) {
  if (uidObservador == uidAlvo) return RelacaoVista.euMesmo;
  if (euBloqueeiOAlvo) return RelacaoVista.bloqueadoPorMim;
  if (!contatoPermitido) return RelacaoVista.indisponivel;

  switch (estado) {
    case EstadoAmizade.amigos:
      return RelacaoVista.amigos;
    case EstadoAmizade.pendente:
      return solicitanteUid == uidObservador
          ? RelacaoVista.solicitacaoEnviada
          : RelacaoVista.solicitacaoRecebida;
    case EstadoAmizade.nenhuma:
      return RelacaoVista.nenhuma;
  }
}

/// As ações válidas naquele momento, derivadas da vista (§31-B).
///
/// "A interface não deve inventar permissões" — então ela também não deve
/// deduzi-las. Esta função é a dedução, feita uma vez, no lado que tem
/// autoridade. O backend revalida cada ação de qualquer modo: esta lista serve
/// para desenhar botão, não para autorizar.
Set<AcaoSocial> acoesDisponiveis(RelacaoVista vista) {
  switch (vista) {
    case RelacaoVista.euMesmo:
      return const {AcaoSocial.editarPerfil};
    case RelacaoVista.bloqueadoPorMim:
      // Nenhuma ação social: oferecer "adicionar amigo" a quem eu bloqueei seria
      // convidar o jogador a uma recusa garantida.
      return const {AcaoSocial.desbloquear};
    case RelacaoVista.indisponivel:
      // Nada. Nem bloquear — o botão de bloquear numa tela sem interação possível
      // é, por si, a informação de que há algo do outro lado.
      return const {};
    case RelacaoVista.nenhuma:
      return const {AcaoSocial.adicionarAmigo, AcaoSocial.bloquear};
    case RelacaoVista.solicitacaoEnviada:
      return const {AcaoSocial.cancelarSolicitacao, AcaoSocial.bloquear};
    case RelacaoVista.solicitacaoRecebida:
      return const {
        AcaoSocial.aceitarSolicitacao,
        AcaoSocial.recusarSolicitacao,
        AcaoSocial.bloquear,
      };
    case RelacaoVista.amigos:
      return const {AcaoSocial.removerAmigo, AcaoSocial.bloquear};
  }
}
