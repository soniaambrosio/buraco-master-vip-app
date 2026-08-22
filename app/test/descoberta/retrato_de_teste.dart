// retrato_de_teste.dart — retratos no FORMATO DO SERVIDOR, para as suítes.
//
// NÃO é um arquivo `_test.dart`: não declara caso nenhum e o coletor do
// `flutter test` não o recolhe. É só o cenário.
//
// ---------------------------------------------------------------------------
// PROVENIÊNCIA — ISTO É CÓPIA, NÃO INVENÇÃO
// ---------------------------------------------------------------------------
//
// Os mapas daqui reproduzem campo a campo o que a projeção da OS 38.1 emite:
//
//   repositório `soniaambrosio/buraco-servidor`
//   branch      `integracao/descoberta-mesas-publicas-presenca-v1`
//   SHA         d1de8a7b2b91dfeb5b409fec61473f10fc21afe4
//   contrato    `contrato/descoberta-mesas-v1.json`
//   digest      a528c9e465a815f4aebb284b30744a17a02badbc0d48bc7d9b0ba368c0c5c63b
//
// A cópia é conferida por `contrato_de_descoberta_test`, que compara ESTES
// campos com o JSON congelado do contrato. Sem essa conferência, um dublê que
// divergisse do servidor faria a suíte inteira medir um contrato imaginário —
// e passar.
//
// ---------------------------------------------------------------------------
// AS ASPEREZAS SÃO DE PROPÓSITO
// ---------------------------------------------------------------------------
//
// A chave da modalidade-mãe é `sbtl`, minúscula e sem T no lugar que a
// jogadora espera. Escrever `STBL` aqui deixaria o P0 de apresentação verde
// sem que o aplicativo traduzisse coisa nenhuma — o dublê estaria fazendo o
// trabalho que o código deveria fazer.

import 'package:buraco_master_vip/descoberta/contrato_descoberta.dart';

/// Um assento OCUPADO, no formato do servidor.
Map<String, Object?> assentoOcupado(
  int indice, {
  String apelido = 'Ana',
  bool bot = false,
  int? avatarGaleria,
}) => {
  'assento': indice,
  'ocupado': true,
  'tipo': bot ? 'bot' : 'humano',
  'apelido': apelido,
  'avatarGaleria': bot ? null : avatarGaleria,
};

/// Um assento LIVRE. Livre não carrega nada — nem tipo, nem apelido, nem
/// avatar. É assim que o servidor o emite, e o adaptador recusa o contrário.
Map<String, Object?> assentoLivre(int indice) => {
  'assento': indice,
  'ocupado': false,
  'tipo': null,
  'apelido': null,
  'avatarGaleria': null,
};

/// Uma mesa pública. Os totais são DERIVADOS dos assentos, como no servidor —
/// escrevê-los à mão deixaria o dublê produzir mesas incoerentes sem querer, e
/// a incoerência é justamente o que o adaptador precisa recusar.
Map<String, Object?> mesa({
  required String codigo,
  String? nome,
  String modalidade = 'sbtl',
  int metaPontos = 2000,
  int humanos = 1,
  int bots = 0,
  bool iniciada = false,
  int aguardandoHaMs = 0,
  int revisao = 1,
  List<String>? apelidos,
  List<int?>? avatares,
}) {
  final assentos = <Map<String, Object?>>[];
  for (var i = 0; i < ContratoDaDescoberta.capacidadeDaMesa; i++) {
    if (i < humanos) {
      assentos.add(
        assentoOcupado(
          i,
          apelido: (apelidos != null && i < apelidos.length)
              ? apelidos[i]
              : 'Jogador ${i + 1}',
          avatarGaleria: (avatares != null && i < avatares.length)
              ? avatares[i]
              : null,
        ),
      );
    } else if (i < humanos + bots) {
      assentos.add(assentoOcupado(i, apelido: 'Robô', bot: true));
    } else {
      assentos.add(assentoLivre(i));
    }
  }
  final ocupados = humanos + bots;
  final vagas = ContratoDaDescoberta.capacidadeDaMesa - ocupados;
  final estado = iniciada
      ? 'em_andamento'
      : (vagas > 0 ? 'aguardando' : 'cheia');
  return {
    'codigo': codigo,
    'nome': nome ?? 'Mesa de ${assentos.first['apelido'] ?? codigo}',
    'modalidade': modalidade,
    'metaPontos': metaPontos,
    'capacidade': ContratoDaDescoberta.capacidadeDaMesa,
    'jogadores': humanos,
    'bots': bots,
    'ocupados': ocupados,
    'vagas': vagas,
    'assentos': assentos,
    'estadoIngresso': estado,
    'ingressavel': estado == 'aguardando',
    'aguardandoHaMs': aguardandoHaMs,
    'revisao': revisao,
  };
}

/// O bloco de presença. Como no servidor, `porModalidade` traz SEMPRE as três.
Map<String, Object?> presenca({
  required List<Map<String, Object?>> mesas,
  int? jogadoresOnlineTotal,
  int espectadoresOnline = 0,
}) {
  var emMesas = 0;
  var aguardando = 0;
  var emAndamento = 0;
  var comVagas = 0;
  final porModalidade = <String, Map<String, Object?>>{
    for (final m in const ['aberto', 'fechado', 'sbtl'])
      m: {
        'mesas': 0,
        'mesasComVagas': 0,
        'jogadores': 0,
        'jogadoresAguardando': 0,
        'jogadoresEmAndamento': 0,
      },
  };

  for (final m in mesas) {
    final humanos = m['jogadores']! as int;
    final ingressavel = m['ingressavel']! as bool;
    final andando = m['estadoIngresso'] == 'em_andamento';
    final chave = m['modalidade']! as String;
    emMesas += humanos;
    if (andando) {
      emAndamento += humanos;
    } else {
      aguardando += humanos;
    }
    if (ingressavel) comVagas++;
    final alvo = porModalidade[chave];
    if (alvo != null) {
      alvo['mesas'] = (alvo['mesas']! as int) + 1;
      if (ingressavel) {
        alvo['mesasComVagas'] = (alvo['mesasComVagas']! as int) + 1;
      }
      alvo['jogadores'] = (alvo['jogadores']! as int) + humanos;
      if (andando) {
        alvo['jogadoresEmAndamento'] =
            (alvo['jogadoresEmAndamento']! as int) + humanos;
      } else {
        alvo['jogadoresAguardando'] =
            (alvo['jogadoresAguardando']! as int) + humanos;
      }
    }
  }

  return {
    'jogadoresOnlineTotal':
        jogadoresOnlineTotal ?? (emMesas + espectadoresOnline),
    'espectadoresOnline': espectadoresOnline,
    'jogadoresEmMesasPublicas': emMesas,
    'jogadoresEmMesasPublicasAguardando': aguardando,
    'jogadoresEmMesasPublicasEmAndamento': emAndamento,
    'mesasPublicas': mesas.length,
    'mesasPublicasComVagas': comVagas,
    'porModalidade': porModalidade,
  };
}

/// A mensagem `mesas` inteira, pronta para entrar pelo canal falso.
Map<String, Object?> retratoDeMesas({
  List<Map<String, Object?>> mesas = const [],
  String geracao = 'ger-1',
  int revisao = 1,
  String geradoEm = '2026-08-21T12:00:00.000Z',
  int? jogadoresOnlineTotal,
  int espectadoresOnline = 0,
}) => {
  'tipo': ContratoDaDescoberta.respostaDeMesas,
  'esquema': ContratoDaDescoberta.esquema,
  'geracao': geracao,
  'revisao': revisao,
  'geradoEm': geradoEm,
  'mesas': mesas,
  'presenca': presenca(
    mesas: mesas,
    jogadoresOnlineTotal: jogadoresOnlineTotal,
    espectadoresOnline: espectadoresOnline,
  ),
};

/// O recibo do pulso.
Map<String, Object?> reciboDePulso({
  int ttlMs = 45000,
  int intervaloSugeridoMs = 15000,
}) => {
  'tipo': ContratoDaDescoberta.reciboDePulso,
  'ttlMs': ttlMs,
  'intervaloSugeridoMs': intervaloSugeridoMs,
};
