// fundacao_v1.dart — A FUNDACAO CONTRATUAL DE TORNEIOS V1 (OS 42).
//
// O QUE ESTE ARQUIVO E: a forma declarada das decisoes congeladas da V1, numa
// camada pura — sem Firestore, sem Cloud Function, sem UI e sem relogio
// implicito. Todo insumo entra por parametro e nenhuma funcao daqui escreve
// coisa alguma.
//
// O QUE ESTE ARQUIVO NAO E, e a lista nao e modestia: nao ha claim `admin`, nao
// ha produtor de edicoes, nao ha consumidor de `tournamentJobs`, nao ha
// inscricao produtiva, nao ha carteira nem ledger, nao ha check-in, nao ha rota
// de cliente e nao ha ligacao com a Central de Torneios. A relacao esta escrita
// em [kForaDaFundacaoV1] e e conferida por teste, para que "ainda nao existe"
// seja um fato auditavel e nao uma promessa em comentario.
//
// POR QUE UMA FUNDACAO ANTES DAS SUCESSORAS
//
// O dominio de torneios desta arvore e grande (dezenove arquivos) e foi escrito
// contra um projeto que admitia torneio publico, misto e por assinatura. A V1
// nao admite. Sem um lugar onde a decisao esteja ESCRITA, cada sucessora
// reinterpretaria o recorte, e a primeira divergencia so apareceria em
// producao — que e exatamente como `players/{uid}` chegou a ser lido por um
// consumidor sem que nada o escrevesse (ver elegibilidade/composicao.dart).
//
// A REGRA DE OURO DESTE ARQUIVO: ele NAO reimplanta nenhuma pergunta que ja
// tenha dono. Vigencia de VIP e de [EntitlementVip.vigenteEm]; suspensao e de
// `moderacao/sancao.dart`; criterio de elegibilidade e de `eligibility.dart`;
// status da edicao e de `tournament_lifecycle.dart`. Aqui se declara QUAL
// recorte da V1 vale, e se COMPOE o que ja existe. Uma segunda conta de VIP
// nesta camada seria a segunda autoridade que a arvore inteira evita.

import '../elegibilidade/entitlement.dart';
import 'annual_closing.dart';
import 'eligibility.dart';
import 'tournament_lifecycle.dart';
import 'tournament_model.dart';

/// Versao do recorte declarado aqui.
///
/// Sobe quando uma decisao CONGELADA mudar — nunca quando a implementacao das
/// sucessoras avancar. As duas coisas se movem em ritmos diferentes e misturar
/// as duas faria a versao deixar de significar alguma coisa.
const int kVersaoFundacaoTorneiosV1 = 1;

// ---------------------------------------------------------------------------
// 1. ACESSO
// ---------------------------------------------------------------------------

/// O UNICO acesso admitido na V1.
///
/// A decisao e de produto e esta congelada: torneio da V1 e por convite. Nao ha
/// caminho de entrada aberto, nem entrada por assinatura sozinha.
const AcessoTorneio kAcessoTorneiosV1 = AcessoTorneio.somenteConvidados;

/// Os acessos declarados SUPERSEDED pela V1.
///
/// `publico` e `misto` sao irreconciliaveis com o requisito da V1 — convite
/// valido MAIS VIP integral vigente. Um torneio publico e, por definicao, um
/// torneio sem convite; um misto admite trilha de entrada que nao passa por
/// convite nenhum. Nao e um numero a ajustar: e a forma da entrada.
const Set<AcessoTorneio> kAcessosSupersededV1 = {
  AcessoTorneio.publico,
  AcessoTorneio.misto,
};

/// Em que situacao um seed do catalogo fica sob o recorte da V1.
enum SituacaoSeedV1 {
  /// O seed ja declara o acesso da V1. Serve como esta.
  admitido('admitido'),

  /// O seed NAO foi superseded, mas tambem nao declara o acesso da V1. Para ter
  /// edicao na V1 ele precisa ser reemitido com `somente_convidados`.
  ///
  /// Este e o caso de `acesso: "vip"`. A OS que congelou o recorte declarou
  /// superseded apenas `publico` e `misto`; classificar `vip` junto com eles
  /// seria decidir mais do que foi decidido. Mas o acesso da V1 tambem nao e
  /// `vip`, entao servir o seed como esta seria decidir por omissao. A terceira
  /// situacao existe justamente para nao fazer nem uma coisa nem outra.
  reemissaoExigida('reemissao_exigida'),

  /// Declarado superseded pela V1. Nao volta por reemissao.
  superseded('superseded');

  final String wire;
  const SituacaoSeedV1(this.wire);
}

/// Classifica um seed do catalogo pelo acesso que ele declara.
SituacaoSeedV1 situacaoDoSeedV1(AcessoTorneio acesso) {
  if (kAcessosSupersededV1.contains(acesso)) return SituacaoSeedV1.superseded;
  if (acesso == kAcessoTorneiosV1) return SituacaoSeedV1.admitido;
  return SituacaoSeedV1.reemissaoExigida;
}

// ---------------------------------------------------------------------------
// 2. PARTICIPACAO
// ---------------------------------------------------------------------------

/// Como o jogador entra na disputa.
enum ParticipacaoV1 {
  /// Vigente na V1.
  individual('individual'),

  /// DORMENTE: declarada para que a sucessora que a acordar encontre o nome ja
  /// fixado, e nao invente um segundo. Nenhum caminho da V1 a aceita.
  ///
  /// Declarar sem ligar e deliberado. O oposto — nao declarar — faria a primeira
  /// sucessora escolher entre `dupla`, `parceria` e `duplas`, e o dominio ja
  /// carrega `parceiroId` em registrations.dart esperando por essa decisao.
  dupla('dupla');

  final String wire;
  const ParticipacaoV1(this.wire);

  /// A V1 aceita esta participacao.
  bool get vigenteNaV1 => this == individual;

  static ParticipacaoV1? porWire(String wire) {
    for (final p in ParticipacaoV1.values) {
      if (p.wire == wire) return p;
    }
    return null;
  }
}

/// A unica participacao vigente na V1.
const ParticipacaoV1 kParticipacaoTorneiosV1 = ParticipacaoV1.individual;

// ---------------------------------------------------------------------------
// 3. O CICLO EDITORIAL DA EDICAO
// ---------------------------------------------------------------------------

/// O ciclo de AUTORIA da edicao, anterior a publicacao.
///
/// NAO SUBSTITUI [EdicaoStatus]. Aquele enum governa a vida PUBLICA da edicao —
/// anunciado, inscricoes abertas, em andamento, encerrado. Este governa os tres
/// estados que existem ANTES de a edicao virar publica, e que ate a V1 nao
/// tinham nome: uma edicao em `rascunho` que fosse direto a `agendado` nunca
/// passava por revisao, e a revisao e o lugar onde a separacao entre criador e
/// aprovador acontece.
///
/// A ponte entre os dois e um so ponto: [EstadoEditorialV1.agendado] corresponde
/// a [EdicaoStatus.agendado], e e onde este ciclo entrega a edicao para aquele.
enum EstadoEditorialV1 {
  /// Escrita em andamento. Invisivel para jogadores, como `EdicaoStatus.rascunho`.
  rascunho('rascunho'),

  /// Submetida. Aguarda um aprovador que nao seja quem a criou.
  emRevisao('em_revisao'),

  /// Aprovada. Daqui em diante quem manda e [EdicaoStatus].
  agendado('agendado');

  final String wire;
  const EstadoEditorialV1(this.wire);

  /// Corresponde a este estado da vida publica da edicao, quando corresponde.
  EdicaoStatus? get equivalentePublico => switch (this) {
        EstadoEditorialV1.rascunho => EdicaoStatus.rascunho,
        EstadoEditorialV1.agendado => EdicaoStatus.agendado,
        EstadoEditorialV1.emRevisao => null,
      };
}

/// As transicoes que existem. Sao estas, e so estas.
///
/// O ciclo congelado e `rascunho -> em_revisao -> agendado`, e SO PARA FRENTE.
/// Devolver a revisao para rascunho, reprovar, ou desagendar sao operacoes
/// plausiveis que a OS NAO congelou — e uma fundacao que as inventasse estaria
/// decidindo produto no lugar de quem decide. Elas ficam para a sucessora que
/// as receber por escrito; ate la, cada uma recusa por
/// [RecusaEditorialV1.transicaoInexistente], que e uma recusa nomeada e nao um
/// silencio.
const Map<EstadoEditorialV1, Set<EstadoEditorialV1>> kTransicoesEditoriaisV1 = {
  EstadoEditorialV1.rascunho: {EstadoEditorialV1.emRevisao},
  EstadoEditorialV1.emRevisao: {EstadoEditorialV1.agendado},
  EstadoEditorialV1.agendado: {},
};

/// Por que uma transicao editorial foi recusada.
enum RecusaEditorialV1 {
  /// A transicao nao esta em [kTransicoesEditoriaisV1].
  transicaoInexistente('transicao_inexistente'),

  /// Quem pediu nao e a administracao. Automacao e cliente nao movem edicao.
  atorNaoAdministrativo('ator_nao_administrativo'),

  /// A aprovacao chegou sem aprovador declarado.
  aprovadorAusente('aprovador_ausente'),

  /// Criador e aprovador sao a mesma pessoa.
  aprovadorIgualAoCriador('aprovador_igual_ao_criador'),

  /// Identificador vazio. Nao ha como auditar quem fez o que.
  identificadorVazio('identificador_vazio');

  final String wire;
  const RecusaEditorialV1(this.wire);
}

/// Avalia uma transicao do ciclo editorial. `null` significa PERMITIDA.
///
/// [ator] entra na assinatura pelo mesmo motivo que em
/// `tournament_lifecycle.dart`: a recusa vira um valor auditavel, e nao um `if`
/// esquecido numa rota. E ele e um DADO do chamador — esta camada nao verifica
/// claim, token nem papel, porque verificar credencial e trabalho de quem tem
/// acesso a credencial. Congelar aqui que o ciclo e administrativo e uma coisa;
/// fingir que esta funcao autentica alguem seria outra.
///
/// [criadoPor] e [aprovadoPor] sao identificadores opacos de administrador. A
/// fundacao nao sabe — e nao precisa saber — de que colecao eles saem.
RecusaEditorialV1? avaliarTransicaoEditorialV1({
  required EstadoEditorialV1 de,
  required EstadoEditorialV1 para,
  required AtorTransicao ator,
  required String criadoPor,
  String? aprovadoPor,
}) {
  if (ator != AtorTransicao.administracao) {
    return RecusaEditorialV1.atorNaoAdministrativo;
  }
  if (!(kTransicoesEditoriaisV1[de] ?? const <EstadoEditorialV1>{})
      .contains(para)) {
    return RecusaEditorialV1.transicaoInexistente;
  }
  if (criadoPor.trim().isEmpty) return RecusaEditorialV1.identificadorVazio;

  // A separacao so e exigivel onde ha aprovacao: submeter a revisao e ato de um
  // autor so. Exigir dois nomes na submissao inventaria um segundo papel que a
  // OS nao criou.
  if (para == EstadoEditorialV1.agendado) {
    final aprovador = aprovadoPor?.trim() ?? '';
    if (aprovador.isEmpty) return RecusaEditorialV1.aprovadorAusente;
    if (aprovador == criadoPor.trim()) {
      return RecusaEditorialV1.aprovadorIgualAoCriador;
    }
  }
  return null;
}

// ---------------------------------------------------------------------------
// 4. VIP INTEGRAL
// ---------------------------------------------------------------------------

/// As origens de `playerEntitlements/{uid}` que representam VIP INTEGRAL.
///
/// Sao as duas que tem produtor nesta arvore: `play` (compra validada, e a
/// reconciliacao que a confirma) e `legado_usuarios` (a migracao da base
/// anterior, que e a MESMA assinatura vista de outro lado).
///
/// `administrativa` esta documentada em `entitlement.dart` e NAO TEM PRODUTOR.
/// E exatamente sob ela que um VIP presenteado seria escrito no dia em que
/// alguem o escrevesse — e a V1 congelou que VIP presenteado nao concede acesso
/// a torneio. Fica de fora, e fica de fora por lista fechada: origem
/// desconhecida recusa, em vez de cair num `else` que concede.
const Set<String> kOrigensVipIntegralV1 = {'play', 'legado_usuarios'};

/// As colecoes que a admissao da V1 NAO consulta, e nao por esquecimento.
///
/// O passe de cortesia vive fora de `playerEntitlements` de proposito — o
/// cabecalho de `functions-ranking/src/passe.ts` explica por que: sao
/// autoridades diferentes, com donos e ciclos de vida diferentes. A V1 herda
/// essa separacao e a torna explicita: o passe governa a entrada na mesa
/// VIP/ranqueada, e nao a entrada em torneio.
const Set<String> kColecoesForaDaAdmissaoV1 = {
  'playerCourtesyPass',
  'passesVip',
};

/// O jogador tem VIP INTEGRAL vigente em [agora]?
///
/// Duas perguntas, e as duas delegadas: a vigencia e de
/// [EntitlementVip.vigenteEm] — nao ha uma segunda conta de prazo aqui — e a
/// integralidade e a pertinencia da origem a [kOrigensVipIntegralV1].
bool vipIntegralVigenteV1(EntitlementVip entitlement, DateTime agora) =>
    entitlement.vigenteEm(agora) &&
    kOrigensVipIntegralV1.contains(entitlement.origem);

// ---------------------------------------------------------------------------
// 5. ADMISSAO
// ---------------------------------------------------------------------------

/// Por que a admissao a um torneio da V1 foi recusada.
enum RecusaAdmissaoV1 {
  /// O torneio nao declara o acesso da V1.
  acessoNaoSuportado('acesso_nao_suportado'),

  /// A participacao pedida esta dormente na V1.
  participacaoDormente('participacao_dormente'),

  /// Herdada, e nao nova: a suspensao vem de `playerModeration/{uid}` pela
  /// composicao de `elegibilidade/composicao.dart`. Aparece aqui para que a
  /// fundacao nao admita quem o resto do sistema ja recusa.
  suspenso('suspenso'),

  /// Sem convite valido PARA ESTE torneio.
  semConvite('sem_convite'),

  /// Sem VIP integral vigente. Inclui o VIP presenteado, por
  /// [kOrigensVipIntegralV1].
  semVipIntegral('sem_vip_integral');

  final String wire;
  const RecusaAdmissaoV1(this.wire);
}

/// Avalia a admissao de um jogador a um torneio da V1. `null` = ADMITIDO.
///
/// ISTO NAO E INSCRICAO. Nada e escrito, nenhuma vaga e reservada, nenhuma
/// ficha e movida e nenhum documento e lido: [perfil] e [entitlement] chegam
/// prontos de quem os leu. A inscricao produtiva e de uma sucessora, e quando
/// ela existir esta e a pergunta que ela faz antes de escrever.
///
/// A ORDEM DAS RECUSAS E DELIBERADA, do mais estrutural ao mais pessoal:
/// primeiro o que reprova o torneio inteiro (acesso, participacao), depois o
/// que reprova a pessoa (suspensao, convite, VIP). Assim um torneio mal
/// declarado nao se apresenta ao jogador como "voce nao tem convite".
RecusaAdmissaoV1? avaliarAdmissaoV1({
  required String tournamentId,
  required AcessoTorneio acesso,
  required ParticipacaoV1 participacao,
  required PerfilElegibilidade perfil,
  required EntitlementVip entitlement,
  required DateTime agora,
}) {
  if (!agora.isUtc) {
    throw ArgumentError.value(agora, 'agora', 'instante precisa estar em UTC');
  }
  if (acesso != kAcessoTorneiosV1) return RecusaAdmissaoV1.acessoNaoSuportado;
  if (!participacao.vigenteNaV1) return RecusaAdmissaoV1.participacaoDormente;
  if (perfil.suspenso) return RecusaAdmissaoV1.suspenso;
  if (!perfil.convitesAtivos.contains(tournamentId)) {
    return RecusaAdmissaoV1.semConvite;
  }
  if (!vipIntegralVigenteV1(entitlement, agora)) {
    return RecusaAdmissaoV1.semVipIntegral;
  }
  return null;
}

// ---------------------------------------------------------------------------
// 6. HALL — NENHUMA CANDIDATURA ORFA
// ---------------------------------------------------------------------------

/// Por que uma candidatura ao Hall foi recusada.
enum RecusaCandidaturaHallV1 {
  /// A edicao que a originaria nao concluiu. Esta e a candidatura ORFA: um
  /// direito que aponta para um fato que nao aconteceu.
  ///
  /// Nao e hipotese. Nesta arvore `aoConcluirEdicao` reage a criacao de
  /// `conclusion`, e nada escreve `conclusion` — entao toda candidatura que
  /// existisse hoje seria orfa por construcao. A V1 congela que ela nao existe.
  edicaoSemConclusao('edicao_sem_conclusao'),

  /// A origem da classificacao nao foi declarada. Uma vaga sem motivo nao e
  /// auditavel, e [RegistroClassificacaoAnual] guarda o motivo justamente para
  /// que ela seja.
  origemDesconhecida('origem_desconhecida'),

  /// Edicao ou jogador sem identificador.
  identificadorVazio('identificador_vazio');

  final String wire;
  const RecusaCandidaturaHallV1(this.wire);
}

/// Uma candidatura ao Hall so existe amarrada a uma conclusao que aconteceu.
/// `null` = a candidatura e legitima.
///
/// [edicaoConcluida] e um FATO que o chamador leu, nao uma pergunta que esta
/// camada responde: quem sabe se a edicao concluiu e quem leu a edicao.
RecusaCandidaturaHallV1? avaliarCandidaturaHallV1({
  required String editionId,
  required String userId,
  required bool edicaoConcluida,
  required OrigemClassificacaoAnual? origem,
}) {
  if (editionId.trim().isEmpty || userId.trim().isEmpty) {
    return RecusaCandidaturaHallV1.identificadorVazio;
  }
  if (!edicaoConcluida) return RecusaCandidaturaHallV1.edicaoSemConclusao;
  if (origem == null) return RecusaCandidaturaHallV1.origemDesconhecida;
  return null;
}

// ---------------------------------------------------------------------------
// 7. OS LIMITES, POR ESCRITO
// ---------------------------------------------------------------------------

/// O que a V1 NAO entrega, nomeado um a um.
///
/// Existe para ser conferido por teste. Um limite escrito so em comentario
/// envelhece em silencio: alguem liga a peca, o comentario continua dizendo que
/// ela nao existe, e a proxima leitura da arvore acredita no comentario. Aqui a
/// lista e dado, e a suite `torneiobase` a percorre contra a arvore.
const List<String> kForaDaFundacaoV1 = [
  'claim admin',
  'produtor de edicoes',
  'consumidor de tournamentJobs',
  'inscricao produtiva',
  'carteira ou ledger',
  'check-in',
  'cliente ou rota produtiva',
  'ligacao da Central de Torneios',
  'OS 12 visual/A11Y',
  'backend completo',
];
