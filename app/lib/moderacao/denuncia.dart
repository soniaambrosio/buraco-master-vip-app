// denuncia.dart — o que é uma denúncia válida (OS de Moderação §3 a §7).
//
// Este arquivo DECIDE; ele não grava. A separação é a mesma que o motor de
// torneios já adota: o domínio responde "esta denúncia pode ser aceita, e por
// quê não", e a Cloud Function apenas executa a resposta. Se um `if` de política
// de moderação aparecer no TypeScript, ele está no lugar errado.
//
// DUAS COISAS QUE O CLIENTE NÃO ESCOLHE, e que por isso não existem como entrada
// aqui: o UID do denunciante (vem do contexto autenticado) e o `createdAt` (vem
// do servidor). Aceitá-los como campo seria deixar qualquer pessoa denunciar em
// nome de outra e datar o registro para trás.

import 'validacao.dart';

/// A que a denúncia se refere.
enum TipoDenuncia { perfil, mensagem, partida }

/// Motivo alegado. Enumerado, e não texto livre, porque categoria livre não se
/// agrega, não se prioriza e não se compara entre denúncias — e a triagem
/// depende exatamente disso.
///
/// Algumas categorias valem para mais de um tipo (assédio cabe no perfil e no
/// chat). Em vez de duplicar a constante com nomes quase iguais, a permissão é
/// dada pelo mapa [categoriasPermitidas].
enum CategoriaDenuncia {
  // comuns a perfil e mensagem
  assedio,
  ameaca,
  discriminacao,
  // perfil
  nomeOfensivo,
  avatarInadequado,
  fraude,
  // mensagem
  insulto,
  spam,
  conteudoSexual,
  dadosPessoais,
  golpe,
  // partida
  combinacao,
  abandonoDeliberado,
  manipulacaoResultado,
  multiplasContas,
  exploracaoFalha,
  // comum a perfil e partida
  antidesportivo,
  // escape consciente, em TODOS os tipos
  outro,
}

/// Quais categorias cada tipo aceita.
///
/// "Insulto" numa denúncia de partida seria aceito por um validador que só
/// olhasse o enum — e a fila de moderação de partidas encheria de caso de chat.
const Map<TipoDenuncia, Set<CategoriaDenuncia>> categoriasPermitidas = {
  TipoDenuncia.perfil: {
    CategoriaDenuncia.nomeOfensivo,
    CategoriaDenuncia.avatarInadequado,
    CategoriaDenuncia.assedio,
    CategoriaDenuncia.ameaca,
    CategoriaDenuncia.discriminacao,
    CategoriaDenuncia.antidesportivo,
    CategoriaDenuncia.fraude,
    CategoriaDenuncia.outro,
  },
  TipoDenuncia.mensagem: {
    CategoriaDenuncia.insulto,
    CategoriaDenuncia.assedio,
    CategoriaDenuncia.ameaca,
    CategoriaDenuncia.spam,
    CategoriaDenuncia.conteudoSexual,
    CategoriaDenuncia.discriminacao,
    CategoriaDenuncia.dadosPessoais,
    CategoriaDenuncia.golpe,
    CategoriaDenuncia.outro,
  },
  TipoDenuncia.partida: {
    CategoriaDenuncia.combinacao,
    CategoriaDenuncia.abandonoDeliberado,
    CategoriaDenuncia.manipulacaoResultado,
    CategoriaDenuncia.multiplasContas,
    CategoriaDenuncia.exploracaoFalha,
    CategoriaDenuncia.antidesportivo,
    CategoriaDenuncia.outro,
  },
};

/// Situação administrativa. O cliente nunca escreve este campo.
enum StatusDenuncia { recebida, emAnalise, procedente, improcedente, arquivada }

/// O que o DENUNCIANTE pode saber sobre o andamento.
///
/// Deliberadamente mais pobre que [StatusDenuncia]: dizer "improcedente" a quem
/// denunciou expõe o resultado da investigação e convida a testar de novo com
/// outra redação. Ver §6 da OS.
enum StatusPublicoDenuncia { emAnalise, concluida }

extension StatusDenunciaPublico on StatusDenuncia {
  StatusPublicoDenuncia get publico => switch (this) {
        StatusDenuncia.recebida => StatusPublicoDenuncia.emAnalise,
        StatusDenuncia.emAnalise => StatusPublicoDenuncia.emAnalise,
        StatusDenuncia.procedente => StatusPublicoDenuncia.concluida,
        StatusDenuncia.improcedente => StatusPublicoDenuncia.concluida,
        StatusDenuncia.arquivada => StatusPublicoDenuncia.concluida,
      };
}

/// Por que uma denúncia foi recusada.
///
/// Enumerado pelo mesmo motivo que `RecusaConcessao` no domínio de recompensas:
/// recusa silenciosa impede auditoria depois. Quem chama devolve ao cliente uma
/// mensagem genérica — mas o log e a métrica precisam do motivo exato.
enum RecusaDenuncia {
  autoDenuncia,
  categoriaInvalidaParaTipo,
  comentarioLongo,
  identificadorInvalido,
  referenciaAusente,
  referenciaIncoerente,
  intencaoInvalida,
  limiteAtingido,
}

/// Resultado da avaliação. Espelha o formato `{aceita, recusa, falhas}` que a
/// Function de torneios já devolve, para que o tratamento no TypeScript seja o
/// mesmo dos dois lados.
class VereditoDenuncia {
  final bool aceita;
  final RecusaDenuncia? recusa;
  final List<String> falhas;

  const VereditoDenuncia.aceita()
      : aceita = true,
        recusa = null,
        falhas = const [];

  const VereditoDenuncia.recusada(this.recusa, this.falhas) : aceita = false;

  Map<String, Object?> toJson() => {
        'aceita': aceita,
        'recusa': recusa?.name,
        'falhas': falhas,
      };
}

/// Referências que a denúncia carrega, conforme o tipo.
class ReferenciasDenuncia {
  final String? matchId;
  final String? roomId;
  final String? messageId;

  const ReferenciasDenuncia({this.matchId, this.roomId, this.messageId});

  Map<String, Object?> toJson() => {
        if (matchId != null) 'matchId': matchId,
        if (roomId != null) 'roomId': roomId,
        if (messageId != null) 'messageId': messageId,
      };
}

/// Limite de denúncias por janela, por denunciante.
///
/// Não é antifraude sofisticada: é o freio que impede uma conta automatizada de
/// despejar mil registros na fila de moderação. O número é folgado para não
/// atrapalhar quem denuncia várias mensagens de uma discussão real.
const int kLimiteDenunciasPorJanela = 20;

/// Tamanho da janela do freio acima.
const Duration kJanelaDenuncias = Duration(hours: 1);

/// Avalia uma denúncia.
///
/// [denuncianteUid] vem do contexto autenticado, NUNCA do payload — quem chama é
/// responsável por isso, e o teste `DEN-UID` prova que o payload é ignorado.
/// [jaNaJanela] é quantas denúncias o mesmo denunciante já registrou dentro de
/// [kJanelaDenuncias]; contá-las é do servidor, decidir é daqui.
VereditoDenuncia avaliarDenuncia({
  required String denuncianteUid,
  required String denunciadoUid,
  required TipoDenuncia tipo,
  required CategoriaDenuncia categoria,
  required String reportIntentId,
  String? comentario,
  ReferenciasDenuncia referencias = const ReferenciasDenuncia(),
  int jaNaJanela = 0,
}) {
  final falhas = <String>[];

  // Identificadores primeiro: sem eles, nada mais faz sentido conferir.
  if (!identificadorValido(denuncianteUid)) falhas.add('denuncianteUid');
  if (!identificadorValido(denunciadoUid)) falhas.add('denunciadoUid');
  if (falhas.isNotEmpty) {
    return VereditoDenuncia.recusada(
        RecusaDenuncia.identificadorInvalido, falhas);
  }

  if (!identificadorValido(reportIntentId)) {
    return VereditoDenuncia.recusada(
        RecusaDenuncia.intencaoInvalida, const ['reportIntentId']);
  }

  // Auto-denúncia. Recusada antes do resto: é sempre inválida, e responder o
  // mesmo erro para qualquer outro defeito atrasaria o diagnóstico de graça.
  if (denuncianteUid == denunciadoUid) {
    return VereditoDenuncia.recusada(
        RecusaDenuncia.autoDenuncia, const ['denunciadoUid']);
  }

  if (!(categoriasPermitidas[tipo] ?? const <CategoriaDenuncia>{})
      .contains(categoria)) {
    return VereditoDenuncia.recusada(
        RecusaDenuncia.categoriaInvalidaParaTipo, const ['categoria']);
  }

  if (!textoCabe(comentario)) {
    return VereditoDenuncia.recusada(
        RecusaDenuncia.comentarioLongo, const ['comentario']);
  }

  // Referências exigidas por tipo. Uma denúncia de mensagem sem `messageId` não
  // é investigável: sobra a palavra de quem denunciou contra a de quem foi
  // denunciado, que é exatamente o que a §5 da OS quer evitar.
  final ausentes = <String>[];
  final incoerentes = <String>[];

  switch (tipo) {
    case TipoDenuncia.perfil:
      // Perfil não exige referência. Mas se vier alguma, ela precisa ser válida:
      // aceitar lixo aqui deixaria o registro com campo impossível de investigar.
      break;
    case TipoDenuncia.mensagem:
      if (referencias.messageId == null) ausentes.add('messageId');
      if (referencias.roomId == null) ausentes.add('roomId');
      break;
    case TipoDenuncia.partida:
      if (referencias.matchId == null) ausentes.add('matchId');
      break;
  }

  for (final par in <(String, String?)>[
    ('matchId', referencias.matchId),
    ('roomId', referencias.roomId),
    ('messageId', referencias.messageId),
  ]) {
    if (par.$2 != null && !identificadorValido(par.$2)) incoerentes.add(par.$1);
  }

  if (ausentes.isNotEmpty) {
    return VereditoDenuncia.recusada(
        RecusaDenuncia.referenciaAusente, ausentes);
  }
  if (incoerentes.isNotEmpty) {
    return VereditoDenuncia.recusada(
        RecusaDenuncia.referenciaIncoerente, incoerentes);
  }

  // O freio fica por último: um pedido malformado não deve consumir cota, senão
  // dá para queimar a cota de outra pessoa só mandando lixo em nome dela.
  if (jaNaJanela >= kLimiteDenunciasPorJanela) {
    return VereditoDenuncia.recusada(
        RecusaDenuncia.limiteAtingido, const ['jaNaJanela']);
  }

  return const VereditoDenuncia.aceita();
}

/// Chave determinista da denúncia — vira o ID DO DOCUMENTO.
///
/// Mesmo padrão de `rewardGrants`: uma segunda gravação do mesmo pedido é a
/// MESMA escrita, e a duplicidade fica impossível por construção em vez de por
/// checagem. Toque duplo no botão, retry após timeout e reconexão convergem no
/// mesmo documento.
///
/// O denunciante entra na chave para que o `reportIntentId` de uma pessoa não
/// colida com o de outra — ele é gerado no aparelho e não há autoridade central
/// distribuindo esses valores.
String chaveDeDenuncia({
  required String denuncianteUid,
  required String reportIntentId,
}) =>
    chaveComposta([denuncianteUid, reportIntentId]);

/// Versão do formato do registro gravado. Sobe quando o shape muda de maneira
/// que um leitor antigo interpretaria errado.
const int kEsquemaDenuncia = 1;
