// relacao_social.dart — bloqueio e silêncio PESSOAL (OS de Moderação §8 a §10).
//
// As duas coisas deste arquivo pertencem ao JOGADOR: ele escolhe quem bloquear e
// de quem não quer ver mensagem. Nenhuma delas é punição, e por isso nenhuma
// delas mora em `sancao.dart` — a §10 da OS pede a separação explicitamente, e a
// razão é prática: sanção é revogável por quem administra, escolha pessoal não;
// sanção expira, escolha pessoal não; sanção entra no histórico disciplinar,
// escolha pessoal jamais deveria.
//
// O BLOQUEIO É UNILATERAL. "A bloqueia B" não cria "B bloqueia A": são dois
// documentos independentes, e desfazer um não desfaz o outro. O que NÃO é
// unilateral é o efeito sobre o contato — ver [avaliarContato].

import 'validacao.dart';

/// Teto de bloqueios por jogador.
///
/// Existe para que a lista continue consultável por leitura direta de documento.
/// Quem chegar perto disso não está usando a ferramenta para o que ela serve.
const int kLimiteBloqueios = 500;

/// Por que um bloqueio (ou desbloqueio) foi recusado.
enum RecusaBloqueio {
  autoBloqueio,
  identificadorInvalido,
  limiteAtingido,
}

/// Por que um mute pessoal foi recusado.
enum RecusaMute {
  autoMute,
  identificadorInvalido,
}

class VereditoRelacao {
  final bool aceita;
  final Object? recusa; // RecusaBloqueio | RecusaMute
  final List<String> falhas;

  const VereditoRelacao.aceita()
      : aceita = true,
        recusa = null,
        falhas = const [];

  const VereditoRelacao.recusada(this.recusa, this.falhas) : aceita = false;

  Map<String, Object?> toJson() => {
        'aceita': aceita,
        'recusa': switch (recusa) {
          RecusaBloqueio r => r.name,
          RecusaMute r => r.name,
          _ => null,
        },
        'falhas': falhas,
      };
}

/// Avalia um pedido de bloqueio.
///
/// [jaBloqueados] é quantos o jogador já tem; contar é do servidor.
VereditoRelacao avaliarBloqueio({
  required String bloqueadorUid,
  required String bloqueadoUid,
  int jaBloqueados = 0,
}) {
  final falhas = <String>[];
  if (!identificadorValido(bloqueadorUid)) falhas.add('bloqueadorUid');
  if (!identificadorValido(bloqueadoUid)) falhas.add('bloqueadoUid');
  if (falhas.isNotEmpty) {
    return VereditoRelacao.recusada(
        RecusaBloqueio.identificadorInvalido, falhas);
  }

  // Auto-bloqueio: sem sentido, e um documento `blocks/{eu}/{eu}` faria toda
  // consulta de contato responder "bloqueado" para o próprio jogador.
  if (bloqueadorUid == bloqueadoUid) {
    return VereditoRelacao.recusada(
        RecusaBloqueio.autoBloqueio, const ['bloqueadoUid']);
  }

  if (jaBloqueados >= kLimiteBloqueios) {
    return VereditoRelacao.recusada(
        RecusaBloqueio.limiteAtingido, const ['jaBloqueados']);
  }

  return const VereditoRelacao.aceita();
}

/// Avalia um pedido de silêncio pessoal.
VereditoRelacao avaliarMute({
  required String donoUid,
  required String alvoUid,
}) {
  final falhas = <String>[];
  if (!identificadorValido(donoUid)) falhas.add('donoUid');
  if (!identificadorValido(alvoUid)) falhas.add('alvoUid');
  if (falhas.isNotEmpty) {
    return VereditoRelacao.recusada(RecusaMute.identificadorInvalido, falhas);
  }
  if (donoUid == alvoUid) {
    return VereditoRelacao.recusada(RecusaMute.autoMute, const ['alvoUid']);
  }
  return const VereditoRelacao.aceita();
}

/// Por que um contato social foi recusado.
enum MotivoContatoRecusado {
  /// O destinatário bloqueou quem está tentando falar. É o caso que a §8 da OS
  /// exige cobrir: o bloqueado não alcança o bloqueador por rota social nenhuma.
  bloqueadoPeloDestino,

  /// Quem tenta falar foi quem bloqueou. Recusar também esta direção é decisão
  /// deste projeto, não exigência da OS: sem ela, bloquear alguém viraria uma
  /// forma de falar sem poder ouvir a resposta — que é assédio com passo extra.
  bloqueouODestino,

  /// Sanção administrativa de chat em vigor sobre quem tenta falar.
  chatSilenciadoPorSancao,

  /// Sanção administrativa de restrição social em vigor sobre quem tenta falar.
  restricaoSocial,
}

/// Resultado da consulta de contato.
class VereditoContato {
  final bool permitido;
  final MotivoContatoRecusado? motivo;

  const VereditoContato.permitido()
      : permitido = true,
        motivo = null;
  const VereditoContato.recusado(this.motivo) : permitido = false;

  Map<String, Object?> toJson() =>
      {'permitido': permitido, 'motivo': motivo?.name};
}

/// Pode [origemUid] iniciar contato social com [destinoUid]?
///
/// É a porta única que toda rota social futura (mensagem privada, convite
/// direto, pedido de amizade) deve consultar. Existe agora, antes das rotas,
/// justamente para que elas nasçam perguntando em vez de serem corrigidas
/// depois — a §8 da OS pede o contrato mesmo onde o recurso ainda não existe.
///
/// As duas primeiras perguntas são sobre BLOQUEIO (escolha pessoal) e as duas
/// últimas sobre SANÇÃO (decisão administrativa). A ordem importa para o motivo
/// devolvido, não para a resposta: qualquer uma verdadeira recusa.
VereditoContato avaliarContato({
  required bool origemBloqueouDestino,
  required bool destinoBloqueouOrigem,
  bool origemComChatSilenciado = false,
  bool origemComRestricaoSocial = false,
}) {
  if (destinoBloqueouOrigem) {
    return const VereditoContato.recusado(
        MotivoContatoRecusado.bloqueadoPeloDestino);
  }
  if (origemBloqueouDestino) {
    return const VereditoContato.recusado(
        MotivoContatoRecusado.bloqueouODestino);
  }
  if (origemComRestricaoSocial) {
    return const VereditoContato.recusado(MotivoContatoRecusado.restricaoSocial);
  }
  if (origemComChatSilenciado) {
    return const VereditoContato.recusado(
        MotivoContatoRecusado.chatSilenciadoPorSancao);
  }
  return const VereditoContato.permitido();
}

/// Versão do formato dos documentos de relação social.
const int kEsquemaRelacaoSocial = 1;
