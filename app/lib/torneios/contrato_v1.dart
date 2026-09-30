// contrato_v1.dart — O CONTRATO NORMATIVO DOS MODELOS DE TORNEIO DA V1.
//
// UM contrato, e um so. Antes desta base havia dois vocabularios vivos para a
// mesma coisa: o seed aprovado falava `vagas:{max,min}`, `entrada:{...}` e
// `acesso`; a Cloud Function lia `limiteParticipantes`, `custoEntrada` e
// `usaCheckin` — campos que o seed nunca teve e que `TorneioTemplate.toJson`
// nunca emitiu. Os dois lados estavam certos sozinhos e errados juntos.
//
// ESTE ARQUIVO NAO CRIA PRODUTOR DE EDICAO. Nao le Firestore, nao chama
// Function, nao escreve nada. Ele responde UMA pergunta, de forma pura:
//
//     este mapa de template pode existir como modelo da V1?
//
// Quem for construir o produtor de edicoes consome ESTE arquivo. Se escrever a
// propria validacao, tera criado o segundo vocabulario outra vez.
//
// TUDO AQUI FALHA FECHADO. Campo ausente, tipo errado, valor desconhecido e
// mapa vazio produzem violacao — nunca um "provavelmente esta certo". Mesma
// disciplina de elegibilidade/composicao.dart: dado ausente nao vira permissao.

import 'tournament_lifecycle.dart';

/// Versao do esquema de template da V1.
///
/// Sobe quando um campo obrigatorio nasce, morre ou muda de significado. Nao
/// sobe por acrescimo opcional — senao toda edicao de comentario viraria
/// migracao.
const int kEsquemaTemplateV1 = 1;

/// Acessos que um template da V1 pode declarar.
///
/// `publico` e `misto` ficaram de fora porque a regra comercial congelada da V1
/// exige VIP integral vigente, e os dois admitiam jogador sem assinatura. Eles
/// nao foram CONVERTIDOS: os modelos que os usavam sairam da relacao ativa e
/// vivem em `app/data/torneios/legado/`, preservados como estavam.
///
/// `somente_convidados` continua valendo, e o convite e criterio CUMULATIVO ao
/// VIP — nunca alternativo. Um convite nao substitui a assinatura; ele restringe
/// ainda mais quem, entre os assinantes, pode entrar.
const Set<String> kAcessosAdmitidosV1 = {'vip', 'somente_convidados'};

/// Participacao admitida na V1.
///
/// `dupla` NAO existe aqui, e a ausencia e deliberada: nao ha convite, aceite
/// nem consentimento de parceiro nesta base. Um campo dormente que ainda assim
/// influenciasse capacidade, chaveamento ou cobranca seria pior do que a
/// ausencia — pareceria funcionalidade e se comportaria como defeito.
const String kParticipacaoV1 = 'individual';

/// Por que um template foi recusado pelo contrato da V1.
///
/// Enum, e nao string livre, pelo mesmo motivo de [RecusaTransicao]: recusa
/// redigida na hora nao se audita depois.
enum ViolacaoContratoV1 {
  /// Sem `templateId`, ou vazio. A identidade e estavel e e a chave de tudo:
  /// premiacao, historico e qualificacao anual sao indexados por ela.
  identidadeAusente('identidade_ausente'),

  /// `versao` ausente ou menor que 1.
  versaoInvalida('versao_invalida'),

  /// `esquema` ausente ou diferente de [kEsquemaTemplateV1]. Documento de outra
  /// safra nao e promovido em silencio — ver [precisaMigracao].
  esquemaIncompativel('esquema_incompativel'),

  /// `acesso` fora de [kAcessosAdmitidosV1].
  acessoNaoVip('acesso_nao_vip'),

  /// `participacao` diferente de individual.
  participacaoNaoIndividual('participacao_nao_individual'),

  /// O template trouxe campo de dupla numa versao que nao tem dupla.
  campoDeDuplaPresente('campo_de_dupla_presente'),

  /// `vagas.max` / `vagas.min` ausentes, nao inteiros ou incoerentes.
  capacidadeInvalida('capacidade_invalida'),

  /// Nem `recorrencia` nem `dataFixa`: um modelo sem agenda nunca vira edicao.
  agendaAusente('agenda_ausente'),

  /// `modalidade` ausente ou sem `tipo`.
  modalidadeAusente('modalidade_ausente'),

  /// `criadoPor` ausente. Sem criador registrado, a separacao de funcoes da
  /// aprovacao nao tem como ser afirmada.
  criadorAusente('criador_ausente'),

  /// `aprovadoPor` igual a `criadoPor`.
  aprovadorIgualAoCriador('aprovador_igual_ao_criador'),

  /// `publicado: true` sem `aprovadoPor`. Publicar e consequencia de aprovar.
  publicadoSemAprovacao('publicado_sem_aprovacao'),

  /// A premiacao declarou movimentacao economica em vez de referencia. Ver
  /// [premiacaoMovimentaCarteira].
  premiacaoComMovimentacao('premiacao_com_movimentacao');

  final String wire;
  const ViolacaoContratoV1(this.wire);
}

/// Campos cuja simples PRESENCA denuncia dupla num esquema que nao tem dupla.
const Set<String> kCamposDeDuplaProibidosV1 = {
  'parceiroId',
  'parceiro',
  'dupla',
  'duplas',
  'conviteParceiro',
  'participacaoDupla',
};

/// Chaves que transformariam a premiacao de referencia em ordem de pagamento.
const Set<String> kCamposDeCarteiraProibidosV1 = {
  'carteira',
  'wallet',
  'wallets',
  'creditarEm',
  'contaDestino',
};

/// Este mapa veio de uma safra anterior e exige migracao explicita?
///
/// Devolve `true` quando `esquema` esta ausente, nao e inteiro, ou e menor que o
/// corrente. A funcao NAO migra: migracao silenciosa e como cada campo
/// desaparecido vira default e cada default vira regra. Quem migrar escreve a
/// migracao e a declara.
bool precisaMigracao(Map<String, Object?> json) {
  final esquema = json['esquema'];
  if (esquema is! int) return true;
  return esquema < kEsquemaTemplateV1;
}

/// A premiacao desta base e REFERENCIA CONTRATUAL, e nao ordem de pagamento.
///
/// Um template pode declarar quantas fichas cada colocacao dara — e isso e o
/// contrato que o futuro concessor devera honrar. O que ele NAO pode declarar e
/// PARA ONDE o credito vai: enquanto a divergencia entre `wallets` e
/// `usuarios.fichas` nao for arbitrada, um campo de destino aqui seria a escolha
/// silenciosa que esta fundacao existe para impedir.
bool premiacaoMovimentaCarteira(Object? premiacao) {
  bool mapaMovimenta(Map<Object?, Object?> m) =>
      m.keys.any((k) => kCamposDeCarteiraProibidosV1.contains(k));

  if (premiacao is Map<Object?, Object?>) {
    if (mapaMovimenta(premiacao)) return true;
    return premiacao.values
        .any((f) => f is Map<Object?, Object?> && mapaMovimenta(f));
  }
  if (premiacao is List) {
    return premiacao.any((f) => f is Map<Object?, Object?> && mapaMovimenta(f));
  }
  return false;
}

/// Valida um template contra o contrato da V1.
///
/// Funcao pura e TOTAL: devolve TODAS as violacoes e nao para na primeira. Quem
/// mostrar isso a um operador precisa listar de uma vez tudo o que falta, senao
/// ele descobre um requisito por tentativa — mesma razao de
/// `avaliarElegibilidade` em eligibility.dart.
///
/// Template INATIVO (`ativo: false`) tambem e validado: um modelo cadastrado e
/// desligado ainda e um modelo, e o dia em que alguem o ligar nao pode ser o dia
/// em que se descobre que ele nunca coube no contrato.
List<ViolacaoContratoV1> validarTemplateV1(Map<String, Object?> json) {
  final v = <ViolacaoContratoV1>[];

  final id = json['templateId'];
  if (id is! String || id.isEmpty) v.add(ViolacaoContratoV1.identidadeAusente);

  final versao = json['versao'];
  if (versao is! int || versao < 1) v.add(ViolacaoContratoV1.versaoInvalida);

  if (precisaMigracao(json)) v.add(ViolacaoContratoV1.esquemaIncompativel);

  // O acesso pode vir como string (`"vip"`) ou como mapa (`{"tipo": "misto"}`).
  // As duas formas existiam no seed aprovado, e o contrato reconhece as duas
  // para poder RECUSAR a segunda por valor, em vez de estourar na leitura.
  final acesso = json['acesso'];
  final acessoWire = acesso is String
      ? acesso
      : (acesso is Map && acesso['tipo'] is String
          ? acesso['tipo'] as String
          : null);
  if (acessoWire == null || !kAcessosAdmitidosV1.contains(acessoWire)) {
    v.add(ViolacaoContratoV1.acessoNaoVip);
  }

  if (json['participacao'] != kParticipacaoV1) {
    v.add(ViolacaoContratoV1.participacaoNaoIndividual);
  }
  if (kCamposDeDuplaProibidosV1.any(json.containsKey)) {
    v.add(ViolacaoContratoV1.campoDeDuplaPresente);
  }

  // Capacidade INDIVIDUAL: `max` conta jogadores, e nao pares. Enquanto a dupla
  // nao existir, o numero e o mesmo — o dia em que ela existir e o dia em que
  // esta linha precisa de uma decisao, e nao de uma multiplicacao esperta.
  final vagas = json['vagas'];
  if (vagas is! Map) {
    v.add(ViolacaoContratoV1.capacidadeInvalida);
  } else {
    final max = vagas['max'];
    final min = vagas['min'];
    if (max is! int || min is! int || min < 1 || max < min) {
      v.add(ViolacaoContratoV1.capacidadeInvalida);
    }
  }

  final temRecorrencia = json['recorrencia'] is Map;
  final temDataFixa = json['dataFixa'] is String;
  if (!temRecorrencia && !temDataFixa) v.add(ViolacaoContratoV1.agendaAusente);

  final modalidade = json['modalidade'];
  if (modalidade is! Map || modalidade['tipo'] is! String) {
    v.add(ViolacaoContratoV1.modalidadeAusente);
  }

  final criadoPor = json['criadoPor'];
  final aprovadoPor = json['aprovadoPor'];
  if (criadoPor is! String || criadoPor.isEmpty) {
    v.add(ViolacaoContratoV1.criadorAusente);
  }
  if (criadoPor is String &&
      criadoPor.isNotEmpty &&
      aprovadoPor is String &&
      criadoPor == aprovadoPor) {
    v.add(ViolacaoContratoV1.aprovadorIgualAoCriador);
  }
  if (json['publicado'] == true &&
      (aprovadoPor is! String || aprovadoPor.isEmpty)) {
    v.add(ViolacaoContratoV1.publicadoSemAprovacao);
  }

  if (premiacaoMovimentaCarteira(json['premiacao'])) {
    v.add(ViolacaoContratoV1.premiacaoComMovimentacao);
  }

  return v;
}

/// O ciclo editorial da V1, afirmado sobre o grafo REAL.
///
/// Nao e uma copia do grafo: e uma leitura dele. Uma copia divergiria de
/// `tournament_lifecycle.dart` na primeira mudanca, e as duas ficariam verdes
/// discordando uma da outra.
///
/// Lista vazia significa: `em_revisao` existe, `rascunho` so alcanca `agendado`
/// atravessando a revisao, a automacao nao submete nem aprova, e a edicao em
/// revisao nao aparece para o jogador.
List<String> quebrasDoCicloEditorialV1() {
  final quebras = <String>[];

  final deRascunho = transicoesEdicao[EdicaoStatus.rascunho] ?? const {};
  if (!deRascunho.contains(EdicaoStatus.emRevisao)) {
    quebras.add('rascunho nao alcanca em_revisao');
  }
  if (deRascunho.contains(EdicaoStatus.agendado)) {
    quebras.add('rascunho alcanca agendado DIRETO — o salto voltou');
  }

  final deRevisao = transicoesEdicao[EdicaoStatus.emRevisao] ?? const {};
  if (!deRevisao.contains(EdicaoStatus.agendado)) {
    quebras.add('em_revisao nao alcanca agendado');
  }
  if (!deRevisao.contains(EdicaoStatus.rascunho)) {
    quebras.add('em_revisao nao rejeita de volta para rascunho');
  }

  if ((transicoesAutomaticas[EdicaoStatus.rascunho] ?? const {}).isNotEmpty) {
    quebras.add('a automacao submete a revisao');
  }
  if ((transicoesAutomaticas[EdicaoStatus.emRevisao] ?? const {}).isNotEmpty) {
    quebras.add('a automacao aprova a revisao');
  }

  if (EdicaoStatus.emRevisao.publico) {
    quebras.add('em_revisao aparece nas listagens publicas');
  }

  return quebras;
}
