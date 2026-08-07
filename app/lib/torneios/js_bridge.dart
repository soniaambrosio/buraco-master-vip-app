// js_bridge.dart — expoe o dominio de torneios para as Cloud Functions.
//
// POR QUE ESTE ARQUIVO EXISTE: as Functions rodam em Node/TypeScript e o motor e
// escrito em Dart. Reescrever as regras em TypeScript criaria uma SEGUNDA
// IMPLEMENTACAO do mesmo motor — exatamente o que a OS 02 secao 1 proibe — e as
// duas divergiriam no primeiro dia em que alguem mudasse um criterio de
// desempate so de um lado. O jogador veria uma classificacao na tela e outra no
// servidor.
//
// A saida: `dart compile js` transforma ESTE arquivo (e todo o dominio que ele
// importa) num bundle que o Node carrega. A regra continua existindo uma unica
// vez, em Dart, testada pela mesma suite que o app usa.
//
// FRONTEIRA: aqui so entra conversao de tipo. Nenhuma decisao de negocio mora
// neste arquivo — se algum `if` de regra aparecer aqui, ele esta no lugar errado.
//
// Compilar com:
//   dart compile js -O2 -o functions/lib/domain_bundle.js \
//       lib/torneios/js_bridge.dart
//
// ui_contracts.dart NAO e importado de proposito: ele depende de Flutter e nao
// compila para JS de servidor. A fronteira com a tela nao tem o que fazer aqui.

import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'annual_closing.dart';
import 'assets_registry.dart';
import 'automation.dart';
import 'champion.dart';
import 'eligibility.dart';
import 'history.dart';
import 'match_contract.dart';
import 'participants.dart';
import 'phases.dart';
import 'registrations.dart';
import 'reward_grants.dart';
import 'reward_policies.dart';
import 'seating.dart';
import 'standings.dart';
import 'tournament_lifecycle.dart';
import 'tournament_model.dart';

/// Objeto global que o Node enxerga como `globalThis.bmvTorneios`.
@JS('bmvTorneios')
external set _bmvTorneios(JSObject valor);

/// Toda funcao exportada recebe JSON e devolve JSON.
///
/// Poderia ser objeto JS estruturado, mas string JSON e deliberado: mantem a
/// fronteira com UMA forma de serializacao — a mesma dos `toJson`/`fromMap` ja
/// testados — em vez de um segundo caminho de conversao que ninguem cobre.
typedef _Ponte = String Function(String);

String _erro(Object e) => jsonEncode({'erro': e.toString()});

/// `{criterios: [...], perfil: {...}, tournamentId: "..."}`
String avaliarElegibilidadeJson(String entrada) {
  try {
    final json = jsonDecode(entrada) as Map<String, dynamic>;
    final perfilJson = json['perfil'] as Map<String, dynamic>;
    Set<String> conjunto(String campo) =>
        ((perfilJson[campo] as List?) ?? const []).map((e) => e as String).toSet();

    final avaliacao = avaliarElegibilidade(
      criterios: ((json['criterios'] as List?) ?? const [])
          .map((e) => CriterioElegibilidade.parse(e as String))
          .toList(growable: false),
      perfil: PerfilElegibilidade(
        userId: perfilJson['userId'] as String,
        nivel: perfilJson['nivel'] as int?,
        posicaoRanking: perfilJson['posicaoRanking'] as int?,
        assinaturaAtiva: (perfilJson['assinaturaAtiva'] as bool?) ?? false,
        convitesAtivos: conjunto('convitesAtivos'),
        conquistas: conjunto('conquistas'),
        participacoes: conjunto('participacoes'),
        titulos: conjunto('titulos'),
        temporadasAtivas: conjunto('temporadasAtivas'),
        suspenso: (perfilJson['suspenso'] as bool?) ?? false,
      ),
      tournamentId: json['tournamentId'] as String,
    );
    return jsonEncode({
      'elegivel': avaliacao.elegivel,
      'falhas': [
        for (final f in avaliacao.falhas)
          {'criterio': f.criterio.wire, 'recusa': f.recusa.wire},
      ],
    });
  } catch (e) {
    return _erro(e);
  }
}

/// `{edicao, template, perfil, vagas, agora, saldoFichas, parceiroId?,
///   inscricoes: [...], emOutraPartida?}`
String inscreverJson(String entrada) {
  try {
    final json = jsonDecode(entrada) as Map<String, dynamic>;
    final perfilJson = json['perfil'] as Map<String, dynamic>;
    final vagasJson = json['vagas'] as Map<String, dynamic>;
    Set<String> conjunto(String campo) =>
        ((perfilJson[campo] as List?) ?? const []).map((e) => e as String).toSet();

    final resultado = inscrever(
      edicao: EdicaoTorneio.fromMap(json['edicao'] as Map<String, dynamic>),
      template: TorneioTemplate.fromJson(json['template'] as Map<String, dynamic>),
      perfil: PerfilElegibilidade(
        userId: perfilJson['userId'] as String,
        nivel: perfilJson['nivel'] as int?,
        posicaoRanking: perfilJson['posicaoRanking'] as int?,
        assinaturaAtiva: (perfilJson['assinaturaAtiva'] as bool?) ?? false,
        convitesAtivos: conjunto('convitesAtivos'),
        conquistas: conjunto('conquistas'),
        participacoes: conjunto('participacoes'),
        titulos: conjunto('titulos'),
        temporadasAtivas: conjunto('temporadasAtivas'),
        suspenso: (perfilJson['suspenso'] as bool?) ?? false,
      ),
      vagas: ConfiguracaoVagas(
        limite: vagasJson['limite'] as int,
        listaEspera: (vagasJson['listaEspera'] as bool?) ?? false,
        custoEntrada: (vagasJson['custoEntrada'] as int?) ?? 0,
      ),
      agora: _instante(json['agora']),
      saldoFichas: json['saldoFichas'] as int,
      parceiroId: json['parceiroId'] as String?,
      inscricoes: _lista(json['inscricoes']).map(Inscricao.fromMap),
      emOutraPartida: (json['emOutraPartida'] as bool?) ?? false,
    );
    return jsonEncode({
      'aceita': resultado.aceita,
      'recusa': resultado.recusa?.wire,
      'inscricao': resultado.inscricao?.toJson(),
      'falhas': [
        for (final f in resultado.avaliacao?.falhas ?? const [])
          {'criterio': f.criterio.wire, 'recusa': f.recusa.wire},
      ],
    });
  } catch (e) {
    return _erro(e);
  }
}

/// `{de, para, ator}`
String avaliarTransicaoJson(String entrada) {
  try {
    final json = jsonDecode(entrada) as Map<String, dynamic>;
    final de = EdicaoStatus.porWire(json['de'] as String);
    final para = EdicaoStatus.porWire(json['para'] as String);
    if (de == null || para == null) {
      return jsonEncode({'permitida': false, 'recusa': 'transicao_inexistente'});
    }
    final ator = AtorTransicao.values.firstWhere(
      (a) => a.wire == json['ator'],
      orElse: () => AtorTransicao.jogador,
    );
    final r = avaliarTransicao(de: de, para: para, ator: ator);
    return jsonEncode({
      'permitida': r.permitida,
      'destino': r.destino?.wire,
      'recusa': r.recusa?.wire,
    });
  } catch (e) {
    return _erro(e);
  }
}

/// `{resultado, solicitacao?, edicaoEmDisputa, processados: [...]}`
String processarResultadoJson(String entrada) {
  try {
    final json = jsonDecode(entrada) as Map<String, dynamic>;
    final solicitacaoJson = json['solicitacao'] as Map<String, dynamic>?;
    final resultado = ResultadoPartida.fromMap(json['resultado'] as Map<String, dynamic>);

    final r = processarResultado(
      resultado: resultado,
      solicitacao: solicitacaoJson == null
          ? null
          : SolicitacaoPartida(
              matchId: solicitacaoJson['matchId'] as String,
              tournamentId: solicitacaoJson['tournamentId'] as String,
              editionId: solicitacaoJson['editionId'] as String,
              faseId: solicitacaoJson['faseId'] as String,
              mesaId: solicitacaoJson['mesaId'] as String,
              assentos: ((solicitacaoJson['assentos'] as List?) ?? const [])
                  .map((e) => Participante.deId(e as String))
                  .toList(growable: false),
              modalidade: solicitacaoJson['modalidade'] as String,
              metaPontos: solicitacaoJson['metaPontos'] as int,
              solicitadaEm: _instante(solicitacaoJson['solicitadaEm']),
            ),
      edicaoEmDisputa: json['edicaoEmDisputa'] as bool,
      processados: _textos(json['processados']),
    );
    return jsonEncode({
      'processado': r.processado,
      'idempotente': r.idempotente,
      'recusa': r.recusa?.wire,
      'chaveIdempotencia': resultado.chaveIdempotencia,
    });
  } catch (e) {
    return _erro(e);
  }
}

/// `{resultados: [...], criterios: [...], participantes: [...]}`
String calcularClassificacaoJson(String entrada) {
  try {
    final json = jsonDecode(entrada) as Map<String, dynamic>;
    final linhas = calcularClassificacao(
      resultados: _lista(json['resultados']).map(ResultadoPartida.fromMap),
      criterios: _criterios(json['criterios']),
      participantes: _textos(json['participantes']),
    );
    return jsonEncode({'classificacao': [for (final l in linhas) l.toJson()]});
  } catch (e) {
    return _erro(e);
  }
}

/// `{fase, mesas: [...], resultados: [...], criterios: [...]}`
String apurarFaseJson(String entrada) {
  try {
    final json = jsonDecode(entrada) as Map<String, dynamic>;
    final fase = Fase.fromMap(json['fase'] as Map<String, dynamic>);
    final mesas = _lista(json['mesas']).map(Mesa.fromMap).toList(growable: false);
    final resultados =
        _lista(json['resultados']).map(ResultadoPartida.fromMap).toList(growable: false);
    final criterios = _criterios(json['criterios']);

    final r = fase.decisiva
        ? apurarFaseDecisiva(
            fase: fase, mesas: mesas, resultados: resultados, criterios: criterios)
        : apurarFase(
            fase: fase, mesas: mesas, resultados: resultados, criterios: criterios);

    return jsonEncode({
      'apurada': r.apurada,
      'recusa': r.recusa?.wire,
      'avancam': r.avancam,
      'classificacao': [for (final l in r.classificacao) l.toJson()],
    });
  } catch (e) {
    return _erro(e);
  }
}

/// `{tournamentId, editionId, faseId, participantes: [...], ladosPorMesa,
///   semente, permitirSobra?}`
String formarMesasJson(String entrada) {
  try {
    final json = jsonDecode(entrada) as Map<String, dynamic>;
    final r = formarMesas(
      tournamentId: json['tournamentId'] as String,
      editionId: json['editionId'] as String,
      faseId: json['faseId'] as String,
      participantes:
          _textos(json['participantes']).map(Participante.deId).toList(growable: false),
      ladosPorMesa: json['ladosPorMesa'] as int,
      semente: json['semente'] as int,
      permitirSobra: (json['permitirSobra'] as bool?) ?? false,
    );
    return jsonEncode({
      'formada': r.formada,
      'recusa': r.recusa?.wire,
      'mesas': [for (final m in r.mesas) m.toJson()],
      'excedentes': [for (final p in r.excedentes) p.participanteId],
    });
  } catch (e) {
    return _erro(e);
  }
}

/// `{tournamentId, editionId, classificacaoFinal: [...], agora,
///   edicaoEncerravel, conclusoes: [...]}`
String concluirEdicaoJson(String entrada) {
  try {
    final json = jsonDecode(entrada) as Map<String, dynamic>;
    final r = concluirEdicao(
      tournamentId: json['tournamentId'] as String,
      editionId: json['editionId'] as String,
      classificacaoFinal: _linhas(json['classificacaoFinal']),
      agora: _instante(json['agora']),
      edicaoEncerravel: json['edicaoEncerravel'] as bool,
      conclusoes: _textos(json['conclusoes']),
    );
    return jsonEncode({
      'concluida': r.concluida,
      'idempotente': r.idempotente,
      'recusa': r.recusa?.wire,
      'conclusao': r.conclusao?.toJson(),
    });
  } catch (e) {
    return _erro(e);
  }
}

/// `{conclusao, template, assetsSeed, politicasSeed, agora, proximaEdicaoEm?,
///   historico: [...]}`
String planejarPremiacaoJson(String entrada) {
  try {
    final json = jsonDecode(entrada) as Map<String, dynamic>;
    final conclusaoJson = json['conclusao'] as Map<String, dynamic>;

    final planejadas = planejarPremiacao(
      conclusao: ConclusaoEdicao(
        tournamentId: conclusaoJson['tournamentId'] as String,
        editionId: conclusaoJson['editionId'] as String,
        campeaoId: conclusaoJson['campeaoId'] as String,
        campeoes: _textos(conclusaoJson['campeoes']).toList(growable: false),
        viceId: conclusaoJson['viceId'] as String?,
        terceiroId: conclusaoJson['terceiroId'] as String?,
        classificacaoFinal:
            _textos(conclusaoJson['classificacaoFinal']).toList(growable: false),
        totalParticipantes: conclusaoJson['totalParticipantes'] as int,
        concluidaEm: _instante(conclusaoJson['concluidaEm']),
      ),
      template: TorneioTemplate.fromJson(json['template'] as Map<String, dynamic>),
      assets: TorneioAssetsRegistry.fromMap(json['assetsSeed'] as Map<String, dynamic>),
      politicas:
          RewardPoliciesRegistry.fromMap(json['politicasSeed'] as Map<String, dynamic>),
      agora: _instante(json['agora']),
      proximaEdicaoEm:
          json['proximaEdicaoEm'] == null ? null : _instante(json['proximaEdicaoEm']),
      historico: _lista(json['historico']).map(RecompensaConcessao.fromMap),
    );

    return jsonEncode({
      'premiacoes': [
        for (final p in planejadas)
          {
            'userId': p.userId,
            'colocacao': p.colocacao,
            'fichas': p.fichas,
            'concedida': p.resultado.concedida,
            'recusa': p.resultado.recusa?.wire,
            'concessao': p.resultado.concessao?.toJson(),
          },
      ],
    });
  } catch (e) {
    return _erro(e);
  }
}

/// `{edicao, template, agora, contexto?, executadas: [...]}`
String planejarTarefasJson(String entrada) {
  try {
    final json = jsonDecode(entrada) as Map<String, dynamic>;
    final contextoJson = (json['contexto'] as Map<String, dynamic>?) ?? const {};

    final pendentes = planejarTarefas(
      edicao: EdicaoTorneio.fromMap(json['edicao'] as Map<String, dynamic>),
      template: TorneioTemplate.fromJson(json['template'] as Map<String, dynamic>),
      agora: _instante(json['agora']),
      contexto: ContextoAutomacao(
        lotado: (contextoJson['lotado'] as bool?) ?? false,
        quorumAtingido: (contextoJson['quorumAtingido'] as bool?) ?? false,
        usaCheckin: (contextoJson['usaCheckin'] as bool?) ?? false,
        fasesApuraveis:
            _textos(contextoJson['fasesApuraveis']).toList(growable: false),
        todasFasesConcluidas:
            (contextoJson['todasFasesConcluidas'] as bool?) ?? false,
      ),
    );

    final restantes =
        tarefasNaoExecutadas(pendentes, _textos(json['executadas']).toSet());
    return jsonEncode({'tarefas': [for (final t in restantes) t.toJson()]});
  } catch (e) {
    return _erro(e);
  }
}

/// `{temporada, registros: [...], agora, existentes: [...]}`
String consolidarConvitesJson(String entrada) {
  try {
    final json = jsonDecode(entrada) as Map<String, dynamic>;
    final temporada = json['temporada'] as String;
    final registros = _lista(json['registros'])
        .map(RegistroClassificacaoAnual.fromMap)
        .toList(growable: false);

    final existentes = [
      for (final c in _lista(json['existentes']))
        ConviteEncerramento(
          userId: c['userId'] as String,
          temporada: c['temporada'] as String,
          status: StatusConvite.porWire(c['status'] as String) ?? StatusConvite.elegivel,
          registroOrigemChave: c['registroOrigemChave'] as String,
          classificacoes: c['classificacoes'] as int,
          criadoEm: _instante(c['criadoEm']),
          atualizadoEm: _instante(c['atualizadoEm']),
        ),
    ];

    final convites = consolidarConvites(
      temporada: temporada,
      registros: registros,
      agora: _instante(json['agora']),
      existentes: existentes,
    );
    final excedentes =
        registrosExcedentes(temporada: temporada, registros: registros);

    return jsonEncode({
      'convites': [for (final c in convites) c.toJson()],
      'excedentes': [for (final r in excedentes) r.toJson()],
    });
  } catch (e) {
    return _erro(e);
  }
}

/// `{edicao, template, conclusao, classificacaoFinal, fases, totalPartidas,
///   premiacoes}`
String montarHistoricoJson(String entrada) {
  try {
    final json = jsonDecode(entrada) as Map<String, dynamic>;
    final conclusaoJson = json['conclusao'] as Map<String, dynamic>;

    final premiacoes = [
      for (final p in _lista(json['premiacoes']))
        PremiacaoPlanejada(
          resultado: p['concessao'] == null
              ? const ResultadoConcessao.recusada(RecusaConcessao.assetInexistente)
              : ResultadoConcessao.concedida(
                  RecompensaConcessao.fromMap(p['concessao'] as Map<String, dynamic>)),
          userId: p['userId'] as String,
          colocacao: p['colocacao'] as int,
          fichas: p['fichas'] as int?,
        ),
    ];

    // O formato entra DENTRO de `edicao`, e nao como campo proprio da chamada:
    // um campo proprio permitiria o chamador mandar um formato diferente do que
    // a edicao registra, e a ponte nao teria como saber qual dos dois vale.
    final historico = montarHistorico(
      edicao: EdicaoTorneio.fromMap(json['edicao'] as Map<String, dynamic>),
      template: TorneioTemplate.fromJson(json['template'] as Map<String, dynamic>),
      conclusao: ConclusaoEdicao(
        tournamentId: conclusaoJson['tournamentId'] as String,
        editionId: conclusaoJson['editionId'] as String,
        campeaoId: conclusaoJson['campeaoId'] as String,
        campeoes: _textos(conclusaoJson['campeoes']).toList(growable: false),
        viceId: conclusaoJson['viceId'] as String?,
        terceiroId: conclusaoJson['terceiroId'] as String?,
        classificacaoFinal:
            _textos(conclusaoJson['classificacaoFinal']).toList(growable: false),
        totalParticipantes: conclusaoJson['totalParticipantes'] as int,
        concluidaEm: _instante(conclusaoJson['concluidaEm']),
      ),
      classificacaoFinal: _linhas(json['classificacaoFinal']),
      fases: _textos(json['fases']).toList(growable: false),
      totalPartidas: json['totalPartidas'] as int,
      premiacoes: premiacoes,
    );

    final saida = historico.toJson();
    // Campo derivado, so para o indice de historico por jogador: o Firestore nao
    // consulta dentro de objetos aninhados de um array.
    saida['participantesUserIds'] = [
      for (final l in historico.classificacaoFinal) ...l.membros,
    ];
    return jsonEncode(saida);
  } catch (e) {
    return _erro(e);
  }
}

// ---------------------------------------------------------------------------
// Conversores
// ---------------------------------------------------------------------------

DateTime _instante(Object? valor) {
  final parsed = DateTime.tryParse(valor as String);
  if (parsed == null) {
    throw FormatException('instante invalido: $valor');
  }
  if (!parsed.isUtc) {
    // Mesma exigencia do resto do dominio: sem sufixo Z, o mesmo registro
    // expiraria em horas diferentes conforme o relogio de quem le.
    throw FormatException('instante deve estar em UTC (sufixo Z): $valor');
  }
  return parsed;
}

Iterable<Map<String, dynamic>> _lista(Object? valor) =>
    ((valor as List?) ?? const []).map((e) => e as Map<String, dynamic>);

Iterable<String> _textos(Object? valor) =>
    ((valor as List?) ?? const []).map((e) => e as String);

List<CriterioDesempate> _criterios(Object? valor) {
  final lista = (valor as List?) ?? const [];
  if (lista.isEmpty) return desempatePadrao;
  return [
    for (final e in lista)
      CriterioDesempate.porWire(e as String) ??
          (throw FormatException('criterio de desempate desconhecido: $e')),
  ];
}

List<LinhaClassificacao> _linhas(Object? valor) => [
      for (final l in _lista(valor))
        LinhaClassificacao(
          posicao: l['posicao'] as int,
          desempenho: DesempenhoParticipante(
            participanteId: l['participanteId'] as String,
            vitorias: (l['vitorias'] as int?) ?? 0,
            derrotas: (l['derrotas'] as int?) ?? 0,
            pontosFeitos: (l['pontosFeitos'] as int?) ?? 0,
            pontosSofridos: (l['pontosSofridos'] as int?) ?? 0,
            canastrasLimpas: (l['canastrasLimpas'] as int?) ?? 0,
            partidasConcluidas: (l['partidasConcluidas'] as int?) ?? 0,
          ),
          situacao: switch (l['situacao']) {
            'avancou' => SituacaoClassificacao.avancou,
            'eliminado' => SituacaoClassificacao.eliminado,
            _ => SituacaoClassificacao.ativo,
          },
          empateNaoResolvido: (l['empateNaoResolvido'] as bool?) ?? false,
        ),
    ];

void main() {
  final api = <String, _Ponte>{
    'avaliarElegibilidade': avaliarElegibilidadeJson,
    'inscrever': inscreverJson,
    'avaliarTransicao': avaliarTransicaoJson,
    'processarResultado': processarResultadoJson,
    'calcularClassificacao': calcularClassificacaoJson,
    'apurarFase': apurarFaseJson,
    'formarMesas': formarMesasJson,
    'concluirEdicao': concluirEdicaoJson,
    'planejarPremiacao': planejarPremiacaoJson,
    'planejarTarefas': planejarTarefasJson,
    'consolidarConvites': consolidarConvitesJson,
    'montarHistorico': montarHistoricoJson,
  };

  final exportado = JSObject();
  api.forEach((nome, fn) {
    exportado.setProperty(nome.toJS, ((JSString entrada) => fn(entrada.toDart).toJS).toJS);
  });
  _bmvTorneios = exportado;
}
