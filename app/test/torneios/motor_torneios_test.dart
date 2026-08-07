// motor_torneios_test.dart — cobertura obrigatoria do Motor de Torneios
// (OS 02 secao 22).
//
// Dart puro sobre flutter_test: nao sobe widget, nao toca Firebase e nao le rede.
// Os seeds reais entram por arquivo (copiados para test/torneios/data/ pelo
// workflow), como ja acontece em reward_grants_test.dart.
//
// Os grupos seguem, na ordem, a lista da OS 02 secao 22, e os casos extras
// identificados na auditoria vem no fim.

import 'dart:convert';
import 'dart:io';

import 'package:buraco_master_vip/screens/torneios_models.dart' as ui;
import 'package:buraco_master_vip/torneios/annual_closing.dart';
import 'package:buraco_master_vip/torneios/assets_registry.dart';
import 'package:buraco_master_vip/torneios/automation.dart';
import 'package:buraco_master_vip/torneios/champion.dart';
import 'package:buraco_master_vip/torneios/eligibility.dart';
import 'package:buraco_master_vip/torneios/history.dart';
import 'package:buraco_master_vip/torneios/match_contract.dart';
import 'package:buraco_master_vip/torneios/participants.dart';
import 'package:buraco_master_vip/torneios/phases.dart';
import 'package:buraco_master_vip/torneios/registrations.dart';
import 'package:buraco_master_vip/torneios/reward_grants.dart';
import 'package:buraco_master_vip/torneios/reward_policies.dart';
import 'package:buraco_master_vip/torneios/seating.dart';
import 'package:buraco_master_vip/torneios/standings.dart';
import 'package:buraco_master_vip/torneios/tournament_catalog.dart';
import 'package:buraco_master_vip/torneios/tournament_lifecycle.dart';
import 'package:buraco_master_vip/torneios/tournament_model.dart';
import 'package:buraco_master_vip/torneios/ui_contracts.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _seed(String nome) {
  final arquivo = File('test/torneios/data/$nome');
  return jsonDecode(arquivo.readAsStringSync()) as Map<String, dynamic>;
}

final _agora = DateTime.utc(2026, 8, 7, 20);

/// Template SINTETICO, usado nos caminhos felizes de mecanica.
///
/// Construido em codigo, e nao lido do seed, de proposito: os testes de mecanica
/// (lotacao, empate, avanco) precisam de numeros pequenos e controlados, e
/// amarra-los aos valores reais faria a suite quebrar toda vez que a Sonia
/// ajustasse uma vaga no painel. Os testes que verificam a CONFIGURACAO APROVADA
/// leem o seed de verdade — ver o grupo "seed aprovado".
TorneioTemplate _template({
  TipoParticipacao participacao = TipoParticipacao.individual,
  int limite = 8,
  AcessoTorneio acesso = AcessoTorneio.publico,
  List<FaixaPremiacao> premiacao = const [
    FaixaPremiacao(
      colocacao: 1,
      crownAssetId: TorneioAssetIds.crownChampion,
      fichas: 1000,
    ),
    FaixaPremiacao(
      colocacao: 2,
      crownAssetId: TorneioAssetIds.crownRunnerUp,
      fichas: 500,
    ),
    FaixaPremiacao(colocacao: 3, crownAssetId: TorneioAssetIds.crownTop3),
  ],
}) =>
    TorneioTemplate(
      tournamentId: 'copa_buraco_master',
      nome: 'Copa Buraco Master',
      versao: 3,
      acesso: acesso,
      participacao: participacao,
      modalidade: const PoliticaModalidade(
        tipo: TipoPoliticaModalidade.fixa,
        valor: ModalidadeMesa.aberto,
      ),
      recorrencia: const PoliticaRecorrencia(
        tipo: TipoRecorrencia.semanal,
        diaSemana: 'sabado',
        horario: '19:30',
      ),
      vagasMax: limite,
      vagasMin: 2,
      checkin: const JanelaCheckin(abre: '19:00', fecha: '19:20'),
      entrada: const PoliticaEntrada(tipo: 'gratuito'),
      premiacao: premiacao,
      capaAssetId: TorneioAssetIds.capaCopaBuracoMaster,
    );

EdicaoTorneio _edicao({
  EdicaoStatus status = EdicaoStatus.inscricoesAbertas,
  DateTime? inicio,
}) {
  final base = inicio ?? _agora.add(const Duration(hours: 4));
  return EdicaoTorneio(
    tournamentId: 'copa_buraco_master',
    editionId: 'ed-2026-08',
    numeroEdicao: 3,
    temporada: '2026',
    status: status,
    inicioPrevisto: base,
    inscricoesAbremEm: base.subtract(const Duration(days: 7)),
    inscricoesFechamEm: base.subtract(const Duration(minutes: 30)),
    modalidade: ModalidadeMesa.aberto,
    numeroFases: 2,
    formato: FormatoTorneio.misto,
    metaPontos: 1500,
    regraVersao: 3,
    criadoEm: _agora.subtract(const Duration(days: 30)),
    atualizadoEm: _agora,
  );
}

/// Catalogo real, lido do seed aprovado.
TorneioCatalogo _catalogo() =>
    TorneioCatalogo.fromMap(_seed('tournamentTemplates.seed.json'));

/// Todos os numeros de REGRA declarados no seed: vagas, valores de entrada e
/// premios em fichas.
///
/// Sao lidos do proprio seed, e nao listados a mao, para que o teste continue
/// valendo quando a Sonia mudar um valor no painel — a lista se atualiza junto.
///
/// Numeros de um so digito ficam de fora de proposito: 1, 2 e 3 sao indices,
/// colocacoes e limites estruturais, e um deles bateria com qualquer `length`
/// ou `>= 2` legitimo do motor, transformando o teste em ruido.
Set<int> _numerosDoSeed(Map<String, dynamic> raiz) {
  final numeros = <int>{};
  void varrer(Object? no) {
    if (no is int) {
      if (no >= 10) numeros.add(no);
    } else if (no is List) {
      for (final item in no) {
        varrer(item);
      }
    } else if (no is Map) {
      for (final entrada in no.entries) {
        // `_meta` e so documentacao; nao carrega numero de regra.
        if (entrada.key == '_meta') continue;
        varrer(entrada.value);
      }
    }
  }

  varrer(raiz);
  return numeros;
}

/// Remove comentarios de linha e de bloco, e o conteudo de strings.
///
/// Sem isso o teste acusaria "64" dentro de um comentario que explica um LCG de
/// 64 bits, ou dentro de uma mensagem de erro — nenhum dos dois e regra fixa no
/// motor.
String _semComentarios(String fonte) => fonte
    .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
    .replaceAll(RegExp(r'//[^\n]*'), '')
    .replaceAll(RegExp(r"'(?:[^'\\\n]|\\.)*'"), "''")
    .replaceAll(RegExp(r'"(?:[^"\\\n]|\\.)*"'), '""');

PerfilElegibilidade _perfil(
  String id, {
  int nivel = 10,
  bool vip = true,
  bool suspenso = false,
  Set<String> convites = const {},
  Set<String> titulos = const {},
}) =>
    PerfilElegibilidade(
      userId: id,
      nivel: nivel,
      posicaoRanking: 5,
      assinaturaAtiva: vip,
      suspenso: suspenso,
      convitesAtivos: convites,
      titulos: titulos,
      temporadasAtivas: const {'2026'},
    );

Inscricao _inscricao(String userId, {String? parceiro, int minuto = 0}) => Inscricao(
      tournamentId: 'copa_buraco_master',
      editionId: 'ed-2026-08',
      userId: userId,
      parceiroId: parceiro,
      status: parceiro == null ? StatusInscricao.inscrito : StatusInscricao.duplaConfirmada,
      inscritoEm: _agora.add(Duration(minutes: minuto)),
      atualizadoEm: _agora.add(Duration(minutes: minuto)),
    );

ResultadoPartida _resultado({
  required String matchId,
  required String faseId,
  required String mesaId,
  required String vencedor,
  required String perdedor,
  int pontosVencedor = 1500,
  int pontosPerdedor = 900,
  int canastrasVencedor = 3,
  int canastrasPerdedor = 1,
  DesfechoPartida desfecho = DesfechoPartida.normal,
}) =>
    ResultadoPartida(
      matchId: matchId,
      tournamentId: 'copa_buraco_master',
      editionId: 'ed-2026-08',
      faseId: faseId,
      mesaId: mesaId,
      lados: [
        LadoResultado(participanteId: vencedor, pontos: pontosVencedor, canastrasLimpas: canastrasVencedor),
        LadoResultado(participanteId: perdedor, pontos: pontosPerdedor, canastrasLimpas: canastrasPerdedor),
      ],
      vencedorId: desfecho == DesfechoPartida.anulada ? null : vencedor,
      desfecho: desfecho,
      encerradaEm: _agora.add(const Duration(hours: 5)),
    );

SolicitacaoPartida _solicitacao({
  required String matchId,
  required String faseId,
  required String mesaId,
  required List<String> ids,
}) =>
    SolicitacaoPartida(
      matchId: matchId,
      tournamentId: 'copa_buraco_master',
      editionId: 'ed-2026-08',
      faseId: faseId,
      mesaId: mesaId,
      assentos: ids.map(Participante.deId).toList(),
      modalidade: 'ABERTO',
      metaPontos: 1500,
      solicitadaEm: _agora,
    );

void main() {
  // ===========================================================================
  // 1. CRIACAO DE TORNEIO
  // ===========================================================================
  group('1. criacao de torneio', () {
    test('o catalogo carrega os seis templates mais o evento de encerramento', () {
      final catalogo = _catalogo();
      expect(catalogo.todos.length, TorneioIds.todos.length);
      expect(catalogo.regulares.map((t) => t.tournamentId), TorneioIds.regulares);
      expect(catalogo.buscar(TorneioIds.campeonatoAnual), isNotNull);
      expect(catalogo.encerramento, isNotNull);
    });

    test('as capas e premios do catalogo existem no registro de assets', () {
      final assets = TorneioAssetsRegistry.fromMap(_seed('assets_registry.seed.json'));
      expect(() => _catalogo().validarCobertura(assets), returnsNormally);
    });

    test('a edicao congela a versao da regra sob a qual nasceu', () {
      expect(_edicao().regraVersao, 3);
      expect(_template().versao, 3);
    });

    test('templateId duplicado no seed e recusado', () {
      final raiz = _seed('tournamentTemplates.seed.json');
      final lista = raiz['templates'] as List;
      lista.add(Map<String, dynamic>.from(lista.first as Map));
      expect(() => TorneioCatalogo.fromMap(raiz), throwsFormatException);
    });

    test('colocacao premiada duas vezes e recusada na carga', () {
      final raiz = _seed('tournamentTemplates.seed.json');
      final primeiro = (raiz['templates'] as List).first as Map<String, dynamic>;
      final premiacao = primeiro['premiacao'] as List;
      premiacao.add({'colocacao': 1, 'fichas': 1});
      expect(() => TorneioCatalogo.fromMap(raiz), throwsFormatException);
    });

    test('moeda diferente de fichas e recusada — a carteira e unica', () {
      final raiz = _seed('tournamentTemplates.seed.json');
      final sexta = (raiz['templates'] as List)
          .cast<Map<String, dynamic>>()
          .firstWhere((t) => t['templateId'] == TorneioIds.sextaMasterVip);
      (sexta['entrada'] as Map)['moeda'] = 'moedas';
      expect(() => TorneioCatalogo.fromMap(raiz), throwsFormatException);
    });
  });

  // ===========================================================================
  // SEED APROVADO — a configuracao decidida fora do repositorio
  // ===========================================================================
  group('seed aprovado', () {
    test('1. os cinco torneios regulares carregam SEM configuracaoPendente', () {
      for (final template in _catalogo().regulares) {
        expect(template.configuracaoCompleta, isTrue,
            reason: '${template.tournamentId} deveria estar configurado');
        expect(template.pendencias, isEmpty, reason: template.tournamentId);
        expect(template.vagasMax, isNotNull, reason: template.tournamentId);
        expect(template.vagasMin, isNotNull, reason: template.tournamentId);
        expect(template.checkin, isNotNull, reason: template.tournamentId);
        expect(template.entrada, isNotNull, reason: template.tournamentId);
        expect(template.premiacao, isNotEmpty, reason: template.tournamentId);
      }
    });

    test('1b. inscricao num torneio regular nao e recusada por configuracao', () {
      // Prova do efeito, e nao so da flag: antes do seed aprovado esta chamada
      // devolvia `configuracaoPendente` e nem chegava a avaliar o jogador.
      final template = _catalogo()[TorneioIds.domingoPintando7];
      final r = inscrever(
        edicao: _edicao(),
        template: template,
        perfil: _perfil('ana'),
        vagas: ConfiguracaoVagas(limite: template.vagasMax!),
        agora: _agora,
        saldoFichas: 100000,
      );
      expect(r.recusa, isNot(MotivoRecusaInscricao.configuracaoPendente));
      expect(r.aceita, isTrue);
    });

    test('2. o Encerramento carrega sua configuracao estrutural', () {
      final evento = _catalogo().encerramento!;
      expect(evento.tournamentId, TorneioIds.encerramentoCampeoesAno);
      expect(evento.configuracaoCompleta, isTrue);
      expect(evento.vagasMax, isNotNull);
      expect(evento.vagasMin, isNotNull);
      expect(evento.escalavelPara, isNotEmpty);
      expect(evento.acesso, AcessoTorneio.somenteConvidados);
      expect(evento.dataFixa.isUtc, isTrue);
      // Premiacao por papel, e nao por colocacao.
      expect(evento.premiacao.keys, containsAll(['campeao', 'vice', 'convidados']));
    });

    test('2b. o motor de convites do Encerramento continua DESATIVADO', () {
      // Decisao #8: mock ate a tabela oficial de pesos existir.
      expect(_catalogo().encerramento!.convitesAtivosEmProducao, isFalse);
    });

    test('3. o Campeonato Anual continua cadastrado, inativo e nao publicado', () {
      final anual = _catalogo()[TorneioIds.campeonatoAnual];
      expect(anual.ativo, isFalse);
      expect(anual.publicado, isFalse);
      expect(anual.recorrencia.tipo, TipoRecorrencia.nenhuma);
      // Cadastrado significa presente no catalogo, o que a busca acima ja prova.
      expect(_catalogo().ativos.map((t) => t.tournamentId),
          isNot(contains(TorneioIds.campeonatoAnual)));
    });

    test('4. NENHUM template esta publicado automaticamente', () {
      final catalogo = _catalogo();
      for (final template in catalogo.todos) {
        expect(template.publicado, isFalse,
            reason: '${template.tournamentId} nao pode nascer publicado');
      }
      expect(catalogo.publicados, isEmpty);
    });

    test('4b. template que omite "publicado" nao nasce publicado', () {
      final raiz = _seed('tournamentTemplates.seed.json');
      for (final t in (raiz['templates'] as List).cast<Map<String, dynamic>>()) {
        t.remove('publicado');
      }
      final catalogo = TorneioCatalogo.fromMap(raiz);
      expect(catalogo.publicados, isEmpty,
          reason: 'o default de publicado precisa ser false');
    });

    test('5. nenhuma regra numerica do seed virou constante no codigo', () {
      // Primeira regra do seed: "TODOS os numeros sao SEEDS editaveis no painel
      // admin. Nada fica fixo no codigo." Este teste le os numeros do proprio
      // seed e varre o dominio atras deles.
      final numeros = _numerosDoSeed(_seed('tournamentTemplates.seed.json'));
      expect(numeros, isNotEmpty, reason: 'o seed precisa ter numeros a proteger');

      final infracoes = <String>[];
      for (final arquivo in Directory('lib/torneios')
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))) {
        final codigo = _semComentarios(arquivo.readAsStringSync());
        for (final numero in numeros) {
          if (RegExp(r'(?<![\w.])' + numero.toString() + r'(?![\w.])')
              .hasMatch(codigo)) {
            infracoes.add('${arquivo.uri.pathSegments.last}: $numero');
          }
        }
      }
      expect(infracoes, isEmpty,
          reason: 'numero de regra fixo no motor deixa de ser editavel no painel');
    });

    test('6. nao existe Top 4 em lugar nenhum', () {
      final catalogo = _catalogo();
      for (final template in catalogo.todos) {
        expect(template.ultimaColocacaoPremiada, lessThanOrEqualTo(3),
            reason: template.tournamentId);
        expect(template.faixaPara(4), isNull, reason: template.tournamentId);
        for (final faixa in template.premiacao) {
          expect(faixa.colocacao, lessThanOrEqualTo(3), reason: template.tournamentId);
        }
      }
      // O encerramento premia por papel; nenhum papel e "quarto".
      expect(catalogo.encerramento!.premiacao.keys, isNot(contains('quarto')));
    });

    test('6b. um seed que tente premiar o 4o lugar e RECUSADO', () {
      final raiz = _seed('tournamentTemplates.seed.json');
      final copa = (raiz['templates'] as List)
          .cast<Map<String, dynamic>>()
          .firstWhere((t) => t['templateId'] == TorneioIds.copaBuracoMaster);
      (copa['premiacao'] as List).add({'colocacao': 4, 'fichas': 1});
      expect(() => TorneioCatalogo.fromMap(raiz), throwsFormatException);
    });

    test('6c. top4.implementar = true e RECUSADO', () {
      final raiz = _seed('tournamentTemplates.seed.json');
      final copa = (raiz['templates'] as List)
          .cast<Map<String, dynamic>>()
          .firstWhere((t) => t['templateId'] == TorneioIds.copaBuracoMaster);
      copa['top4'] = {'implementar': true};
      expect(() => TorneioCatalogo.fromMap(raiz), throwsFormatException);
    });

    test('a modalidade em politica resolve por edicao, sem inventar valor', () {
      final catalogo = _catalogo();

      // Fixa: sempre a mesma.
      final sexta = catalogo[TorneioIds.sextaMasterVip].modalidade;
      expect(sexta.tipo, TipoPoliticaModalidade.fixa);
      expect(sexta.resolverPara(1), sexta.resolverPara(9));

      // Rodizio: percorre as opcoes e volta ao inicio.
      final copa = catalogo[TorneioIds.copaBuracoMaster].modalidade;
      expect(copa.tipo, TipoPoliticaModalidade.rodizio);
      expect(copa.resolverPara(1), copa.opcoes.first);
      expect(copa.resolverPara(1 + copa.opcoes.length), copa.opcoes.first);

      // Definida pela administracao: NAO resolve sozinha.
      expect(catalogo[TorneioIds.campeonatoMensal].modalidade.resolverPara(1), isNull);
      expect(catalogo[TorneioIds.campeonatoAnual].modalidade.resolverPara(1), isNull);
    });

    test('o acesso do seed vira criterio de elegibilidade, sem campo duplicado', () {
      final catalogo = _catalogo();
      expect(catalogo[TorneioIds.quartaVulnerabilidade].criteriosElegibilidade, isEmpty);
      expect(catalogo[TorneioIds.sextaMasterVip].criteriosElegibilidade,
          contains('assinatura'));
      // Sem assinatura, a Sexta recusa com o motivo que a tela ja conhece.
      final r = inscrever(
        edicao: _edicao(),
        template: catalogo[TorneioIds.sextaMasterVip],
        perfil: _perfil('ana', vip: false),
        vagas: const ConfiguracaoVagas(limite: 64),
        agora: _agora,
        saldoFichas: 100000,
      );
      expect(r.recusa, MotivoRecusaInscricao.requisitoVipNaoAtendido);
    });

    test('a entrada em duas etapas cobra a partir da edicao certa', () {
      // Quarta da Vulnerabilidade: gratis nas primeiras edicoes, paga depois.
      // Os numeros vem do seed; o teste so confere o COMPORTAMENTO.
      final entrada = _catalogo()[TorneioIds.quartaVulnerabilidade].entrada!;
      final gratis = entrada.gratisPrimeirasEdicoes!;
      expect(entrada.custoPara(numeroEdicao: gratis), 0);
      expect(entrada.custoPara(numeroEdicao: gratis + 1), entrada.valorApos);
      expect(entrada.valorApos, greaterThan(0));
    });

    test('a trilha de classificado do mensal e gratuita e a paga esta desligada', () {
      final entrada = _catalogo()[TorneioIds.campeonatoMensal].entrada!;
      expect(entrada.trilhas.keys, containsAll(['classificados', 'vagasRemanescentes']));
      expect(entrada.custoPara(trilha: 'classificados'), 0);
      // `ativar: false` no seed: a cobranca existe configurada, mas desligada.
      expect(entrada.trilhas['vagasRemanescentes']!.ativar, isFalse);
      expect(entrada.custoPara(trilha: 'vagasRemanescentes'), 0);
    });

    test('todo horario do seed esta no formato HH:MM do fuso do projeto', () {
      expect(fusoTorneios, 'America/Sao_Paulo');
      for (final t in _catalogo().regulares) {
        expect(RegExp(r'^\d{2}:\d{2}$').hasMatch(t.checkin!.abre), isTrue);
        expect(RegExp(r'^\d{2}:\d{2}$').hasMatch(t.checkin!.fecha), isTrue);
        expect(t.checkin!.fecha.compareTo(t.checkin!.abre) > 0, isTrue,
            reason: t.tournamentId);
      }
    });
  });

  // ===========================================================================
  // 2. ABERTURA E 7. FECHAMENTO DE INSCRICOES
  // ===========================================================================
  group('2. abertura de inscricoes', () {
    test('a automacao abre inscricoes quando o calendario alcanca a janela', () {
      final edicao = _edicao(status: EdicaoStatus.agendado);
      final tarefas = planejarTarefas(
        edicao: edicao,
        template: _template(),
        agora: _agora,
      );
      expect(tarefas.map((t) => t.tarefa), contains(TarefaAutomatica.abrirInscricoes));
      expect(tarefas.first.transicaoPara, EdicaoStatus.inscricoesAbertas);
    });

    test('nao abre antes da janela', () {
      final edicao = _edicao(status: EdicaoStatus.agendado);
      final tarefas = planejarTarefas(
        edicao: edicao,
        template: _template(),
        agora: edicao.inscricoesAbremEm!.subtract(const Duration(minutes: 1)),
      );
      expect(tarefas, isEmpty);
    });

    test('template sem configuracao completa nao gera tarefa nenhuma', () {
      // O Campeonato Anual esta cadastrado mas sem dimensionamento, janela nem
      // entrada (decisao #6). A automacao nao pode agendar edicao dele.
      final tarefas = planejarTarefas(
        edicao: _edicao(status: EdicaoStatus.agendado),
        template: _catalogo()[TorneioIds.campeonatoAnual],
        agora: _agora,
      );
      expect(tarefas, isEmpty);
    });

    test('a transicao de abertura e permitida ao sistema', () {
      expect(
        avaliarTransicao(
          de: EdicaoStatus.agendado,
          para: EdicaoStatus.inscricoesAbertas,
          ator: AtorTransicao.sistema,
        ).permitida,
        isTrue,
      );
    });
  });

  group('7. fechamento das inscricoes', () {
    test('fecha por prazo', () {
      final edicao = _edicao();
      final tarefas = planejarTarefas(
        edicao: edicao,
        template: _template(),
        agora: edicao.inscricoesFechamEm!,
      );
      expect(tarefas.single.tarefa, TarefaAutomatica.fecharInscricoes);
    });

    test('fecha por lotacao antes do prazo', () {
      final tarefas = planejarTarefas(
        edicao: _edicao(),
        template: _template(),
        agora: _agora,
        contexto: const ContextoAutomacao(lotado: true),
      );
      expect(tarefas.single.tarefa, TarefaAutomatica.fecharInscricoes);
    });

    test('inscricao fora da janela e recusada mesmo com status aberto', () {
      final edicao = _edicao();
      final r = inscrever(
        edicao: edicao,
        template: _template(),
        perfil: _perfil('ana'),
        vagas: const ConfiguracaoVagas(limite: 8),
        agora: edicao.inscricoesFechamEm!.add(const Duration(minutes: 1)),
        saldoFichas: 0,
      );
      expect(r.recusa, MotivoRecusaInscricao.inscricoesEncerradas);
    });
  });

  // ===========================================================================
  // 3. INSCRICAO VALIDA · 4. DUPLICADA · 5. INELEGIVEL · 6. LIMITE
  // ===========================================================================
  group('3. inscricao valida', () {
    test('jogador elegivel entra', () {
      final r = inscrever(
        edicao: _edicao(),
        template: _template(),
        perfil: _perfil('ana'),
        vagas: const ConfiguracaoVagas(limite: 8),
        agora: _agora,
        saldoFichas: 0,
      );
      expect(r.aceita, isTrue);
      expect(r.inscricao!.status, StatusInscricao.inscrito);
      expect(r.inscricao!.chaveIdempotencia, 'copa_buraco_master|ed-2026-08|ana');
    });

    test('dupla com parceiro entra como dupla confirmada', () {
      final r = inscrever(
        edicao: _edicao(),
        template: _template(participacao: TipoParticipacao.dupla),
        perfil: _perfil('ana'),
        vagas: const ConfiguracaoVagas(limite: 8),
        agora: _agora,
        saldoFichas: 0,
        parceiroId: 'bia',
      );
      expect(r.inscricao!.status, StatusInscricao.duplaConfirmada);
    });

    test('saldo insuficiente recusa por sem_fichas', () {
      final r = inscrever(
        edicao: _edicao(),
        template: _template(),
        perfil: _perfil('ana'),
        vagas: const ConfiguracaoVagas(limite: 8, custoEntrada: 500),
        agora: _agora,
        saldoFichas: 100,
      );
      expect(r.recusa, MotivoRecusaInscricao.semFichas);
    });

    test('template sem configuracao completa recusa a inscricao', () {
      final r = inscrever(
        edicao: _edicao(),
        template: _catalogo()[TorneioIds.campeonatoAnual],
        perfil: _perfil('ana'),
        vagas: const ConfiguracaoVagas(limite: 8),
        agora: _agora,
        saldoFichas: 0,
      );
      expect(r.recusa, MotivoRecusaInscricao.configuracaoPendente);
    });
  });

  group('4. inscricao duplicada', () {
    test('mesmo jogador duas vezes e recusado', () {
      final r = inscrever(
        edicao: _edicao(),
        template: _template(),
        perfil: _perfil('ana'),
        vagas: const ConfiguracaoVagas(limite: 8),
        agora: _agora,
        saldoFichas: 0,
        inscricoes: [_inscricao('ana')],
      );
      expect(r.recusa, MotivoRecusaInscricao.jaInscrito);
    });

    test('inscricao cancelada nao bloqueia nova inscricao', () {
      final cancelada = _inscricao('ana').comStatus(StatusInscricao.cancelado, em: _agora);
      final r = inscrever(
        edicao: _edicao(),
        template: _template(),
        perfil: _perfil('ana'),
        vagas: const ConfiguracaoVagas(limite: 8),
        agora: _agora,
        saldoFichas: 0,
        inscricoes: [cancelada],
      );
      expect(r.aceita, isTrue);
    });

    test('parceiro ja inscrito em outra dupla e recusado', () {
      final r = inscrever(
        edicao: _edicao(),
        template: _template(participacao: TipoParticipacao.dupla),
        perfil: _perfil('ana'),
        vagas: const ConfiguracaoVagas(limite: 8),
        agora: _agora,
        saldoFichas: 0,
        parceiroId: 'bia',
        inscricoes: [_inscricao('caio', parceiro: 'bia')],
      );
      expect(r.recusa, MotivoRecusaInscricao.parceiroJaInscrito);
    });

    test('parceiro igual ao proprio jogador e recusado', () {
      final r = inscrever(
        edicao: _edicao(),
        template: _template(participacao: TipoParticipacao.dupla),
        perfil: _perfil('ana'),
        vagas: const ConfiguracaoVagas(limite: 8),
        agora: _agora,
        saldoFichas: 0,
        parceiroId: 'ana',
      );
      expect(r.recusa, MotivoRecusaInscricao.parceiroInvalido);
    });
  });

  group('5. jogador inelegivel', () {
    test('sem assinatura em torneio VIP', () {
      final r = inscrever(
        edicao: _edicao(),
        template: _template(acesso: AcessoTorneio.vip),
        perfil: _perfil('ana', vip: false),
        vagas: const ConfiguracaoVagas(limite: 8),
        agora: _agora,
        saldoFichas: 0,
      );
      expect(r.recusa, MotivoRecusaInscricao.requisitoVipNaoAtendido);
    });

    test('nivel insuficiente', () {
      // Avaliado direto na camada de elegibilidade: o seed aprovado so expressa
      // acesso (publico / vip / misto / somente convidados), entao nao ha
      // template real com criterio de nivel. A camada suporta o criterio para
      // quando o projeto o adotar — ver eligibility.dart.
      final a = avaliarElegibilidade(
        criterios: [const CriterioElegibilidade(TipoCriterio.nivelMinimo, '20')],
        perfil: _perfil('ana', nivel: 3),
        tournamentId: 'copa_buraco_master',
      );
      expect(a.elegivel, isFalse);
      expect(a.principal!.recusa, RecusaElegibilidade.nivelInsuficiente);
    });

    test('perfil suspenso e recusado', () {
      final r = inscrever(
        edicao: _edicao(),
        template: _template(),
        perfil: _perfil('ana', suspenso: true),
        vagas: const ConfiguracaoVagas(limite: 8),
        agora: _agora,
        saldoFichas: 0,
      );
      expect(r.recusa, MotivoRecusaInscricao.perfilSuspenso);
    });

    test('convite vale so para o torneio que o emitiu', () {
      final perfil = _perfil('ana', convites: const {'encerramento_anual'});
      expect(
        avaliarElegibilidade(
          criterios: [const CriterioElegibilidade(TipoCriterio.convite)],
          perfil: perfil,
          tournamentId: 'copa_buraco_master',
        ).elegivel,
        isFalse,
      );
      expect(
        avaliarElegibilidade(
          criterios: [const CriterioElegibilidade(TipoCriterio.convite)],
          perfil: perfil,
          tournamentId: 'encerramento_anual',
        ).elegivel,
        isTrue,
      );
    });

    test('dado ausente recusa em vez de passar por omissao', () {
      const perfil = PerfilElegibilidade(userId: 'ana');
      final a = avaliarElegibilidade(
        criterios: [const CriterioElegibilidade(TipoCriterio.nivelMinimo, '5')],
        perfil: perfil,
        tournamentId: 't',
      );
      expect(a.principal!.recusa, RecusaElegibilidade.dadoIndisponivel);
    });

    test('a avaliacao lista TODAS as falhas, nao so a primeira', () {
      final a = avaliarElegibilidade(
        criterios: [
          const CriterioElegibilidade(TipoCriterio.nivelMinimo, '99'),
          const CriterioElegibilidade(TipoCriterio.assinatura),
          const CriterioElegibilidade(TipoCriterio.campeao, 'copa_buraco_master'),
        ],
        perfil: _perfil('ana', nivel: 1, vip: false),
        tournamentId: 'copa_buraco_master',
      );
      expect(a.falhas.length, 3);
    });

    test('criterio malformado e recusado na interpretacao', () {
      expect(() => CriterioElegibilidade.parse('nivel_minimo'), throwsFormatException);
      expect(() => CriterioElegibilidade.parse('assinatura:5'), throwsFormatException);
      expect(() => CriterioElegibilidade.parse('inventado:1'), throwsFormatException);
      expect(() => CriterioElegibilidade.parse('nivel_minimo:zero'), throwsFormatException);
    });
  });

  group('6. limite de participantes', () {
    test('lotado sem lista de espera e recusado', () {
      final inscricoes = [for (var i = 0; i < 4; i++) _inscricao('j$i', minuto: i)];
      final r = inscrever(
        edicao: _edicao(),
        template: _template(limite: 4),
        perfil: _perfil('ana'),
        vagas: const ConfiguracaoVagas(limite: 4),
        agora: _agora,
        saldoFichas: 0,
        inscricoes: inscricoes,
      );
      expect(r.recusa, MotivoRecusaInscricao.lotado);
    });

    test('lotado com lista de espera entra na fila', () {
      final inscricoes = [for (var i = 0; i < 4; i++) _inscricao('j$i', minuto: i)];
      final r = inscrever(
        edicao: _edicao(),
        template: _template(limite: 4),
        perfil: _perfil('ana'),
        vagas: const ConfiguracaoVagas(limite: 4, listaEspera: true, custoEntrada: 250),
        agora: _agora,
        saldoFichas: 1000,
        inscricoes: inscricoes,
      );
      expect(r.emEspera, isTrue);
      expect(r.inscricao!.posicaoEspera, 1);
      // Lista de espera nao debita: a vaga ainda nao existe.
      expect(r.inscricao!.fichasDebitadas, 0);
    });

    test('dupla ocupa dois assentos na contagem de lotacao', () {
      final inscricoes = [
        _inscricao('a', parceiro: 'b', minuto: 0),
        _inscricao('c', parceiro: 'd', minuto: 1),
      ];
      final r = inscrever(
        edicao: _edicao(),
        template: _template(participacao: TipoParticipacao.dupla, limite: 4),
        perfil: _perfil('ana'),
        vagas: const ConfiguracaoVagas(limite: 4),
        agora: _agora,
        saldoFichas: 0,
        parceiroId: 'bia',
        inscricoes: inscricoes,
      );
      expect(r.recusa, MotivoRecusaInscricao.lotado);
    });

    test('cancelado libera a vaga', () {
      final inscricoes = [
        for (var i = 0; i < 3; i++) _inscricao('j$i', minuto: i),
        _inscricao('j3', minuto: 3).comStatus(StatusInscricao.cancelado, em: _agora),
      ];
      final r = inscrever(
        edicao: _edicao(),
        template: _template(limite: 4),
        perfil: _perfil('ana'),
        vagas: const ConfiguracaoVagas(limite: 4),
        agora: _agora,
        saldoFichas: 0,
        inscricoes: inscricoes,
      );
      expect(r.aceita, isTrue);
    });

    test('convocacao da lista de espera respeita a ordem', () {
      final espera = [
        Inscricao(
          tournamentId: 'copa_buraco_master',
          editionId: 'ed-2026-08',
          userId: 'segundo',
          status: StatusInscricao.listaEspera,
          inscritoEm: _agora,
          atualizadoEm: _agora,
          posicaoEspera: 2,
        ),
        Inscricao(
          tournamentId: 'copa_buraco_master',
          editionId: 'ed-2026-08',
          userId: 'primeiro',
          status: StatusInscricao.listaEspera,
          inscritoEm: _agora,
          atualizadoEm: _agora,
          posicaoEspera: 1,
        ),
      ];
      final convocado = convocarDaListaEspera(
        inscricoes: espera,
        agora: _agora,
        custoEntrada: 250,
      );
      expect(convocado!.userId, 'primeiro');
      expect(convocado.status, StatusInscricao.inscrito);
      expect(convocado.fichasDebitadas, 250);
    });
  });

  // ===========================================================================
  // 8. FORMACAO DE MESAS
  // ===========================================================================
  group('8. formacao de mesas', () {
    final participantes = [
      for (var i = 0; i < 8; i++) Participante.individual('j$i'),
    ];

    test('forma mesas completas', () {
      final r = formarMesas(
        tournamentId: 'copa_buraco_master',
        editionId: 'ed-2026-08',
        faseId: 'f1',
        participantes: participantes,
        ladosPorMesa: 2,
        semente: 42,
      );
      expect(r.formada, isTrue);
      expect(r.mesas.length, 4);
      expect(r.mesas.first.assentos.length, 2);
    });

    test('o sorteio e reproduzivel com a mesma semente', () {
      List<String> distribuicao(int semente) => formarMesas(
            tournamentId: 'copa_buraco_master',
            editionId: 'ed-2026-08',
            faseId: 'f1',
            participantes: participantes,
            ladosPorMesa: 2,
            semente: semente,
          ).mesas.expand((m) => m.assentos.map((a) => a.participanteId)).toList();

      expect(distribuicao(42), distribuicao(42));
      expect(distribuicao(42), isNot(distribuicao(7)));
    });

    test('a ordem de entrada nao altera o sorteio', () {
      // Sem a normalizacao interna, a mesma semente daria mesas diferentes
      // conforme a origem da lista (mapa, query, cache).
      final invertido = participantes.reversed.toList();
      final a = formarMesas(
        tournamentId: 't', editionId: 'e', faseId: 'f1',
        participantes: participantes, ladosPorMesa: 2, semente: 99,
      );
      final b = formarMesas(
        tournamentId: 't', editionId: 'e', faseId: 'f1',
        participantes: invertido, ladosPorMesa: 2, semente: 99,
      );
      expect(
        a.mesas.expand((m) => m.assentos.map((x) => x.participanteId)),
        b.mesas.expand((m) => m.assentos.map((x) => x.participanteId)),
      );
    });

    test('OURO: a distribuicao e identica na VM e em JavaScript', () {
      // Estes valores foram conferidos rodando o MESMO sorteio nas duas
      // plataformas: `dart run` (VM, como no app) e `node` sobre o bundle de
      // js_bridge.dart (como nas Cloud Functions). As duas produzem exatamente
      // esta distribuicao.
      //
      // O teste existe porque a primeira versao do gerador usava um LCG de 64
      // bits, que em JavaScript perde precisao (int vira double) e divergia do
      // app. Se alguem trocar o gerador por um que multiplique inteiros grandes,
      // este teste quebra ANTES de o servidor sortear uma mesa que o aparelho
      // nao consegue reproduzir.
      String distribuicao(int semente) => formarMesas(
            tournamentId: 't', editionId: 'e', faseId: 'f1',
            participantes: [for (var i = 0; i < 8; i++) Participante.individual('j$i')],
            ladosPorMesa: 2, semente: semente,
          ).mesas.map((m) => m.assentos.map((a) => a.participanteId).join('/')).join(' | ');

      expect(distribuicao(42), 'j4/j6 | j5/j7 | j1/j3 | j2/j0');
      expect(distribuicao(7), 'j5/j2 | j4/j3 | j6/j1 | j0/j7');
    });

    test('semente que zera em 32 bits nao trava o gerador', () {
      // Xorshift preso em zero devolveria sempre o mesmo indice e todas as mesas
      // sairiam na ordem de entrada.
      final r = formarMesas(
        tournamentId: 't', editionId: 'e', faseId: 'f1',
        participantes: participantes, ladosPorMesa: 2, semente: 0,
      );
      expect(r.formada, isTrue);
      expect(
        r.mesas.expand((m) => m.assentos.map((a) => a.participanteId)).toList(),
        isNot(participantes.map((p) => p.participanteId).toList()),
      );
    });

    test('ninguem senta em duas mesas', () {
      final r = formarMesas(
        tournamentId: 't', editionId: 'e', faseId: 'f1',
        participantes: participantes, ladosPorMesa: 2, semente: 5,
      );
      final todos = r.mesas.expand((m) => m.assentos.map((a) => a.participanteId)).toList();
      expect(todos.toSet().length, todos.length);
      expect(todos.length, participantes.length);
    });

    test('jogador repetido entre unidades e recusado', () {
      final r = formarMesas(
        tournamentId: 't', editionId: 'e', faseId: 'f1',
        participantes: [
          Participante.dupla('ana', 'bia'),
          Participante.dupla('ana', 'caio'),
        ],
        ladosPorMesa: 2,
        semente: 1,
      );
      expect(r.recusa, RecusaFormacao.jogadorDuplicado);
    });

    test('sobra e recusada por padrao e devolvida quando permitida', () {
      final impar = participantes.take(5).toList();
      expect(
        formarMesas(
          tournamentId: 't', editionId: 'e', faseId: 'f1',
          participantes: impar, ladosPorMesa: 2, semente: 1,
        ).recusa,
        RecusaFormacao.sobraDeParticipantes,
      );
      final comSobra = formarMesas(
        tournamentId: 't', editionId: 'e', faseId: 'f1',
        participantes: impar, ladosPorMesa: 2, semente: 1, permitirSobra: true,
      );
      expect(comSobra.mesas.length, 2);
      expect(comSobra.excedentes.length, 1);
    });

    test('participantes insuficientes sao recusados', () {
      expect(
        formarMesas(
          tournamentId: 't', editionId: 'e', faseId: 'f1',
          participantes: [Participante.individual('so-eu')],
          ladosPorMesa: 2, semente: 1,
        ).recusa,
        RecusaFormacao.participantesInsuficientes,
      );
    });

    test('reunir participantes forma duplas e absorve o parceiro', () {
      final unidades = reunirParticipantes(
        inscricoes: [
          _inscricao('ana', parceiro: 'bia', minuto: 0),
          _inscricao('bia', parceiro: 'ana', minuto: 1),
          _inscricao('caio', parceiro: 'duda', minuto: 2),
        ],
        participacao: TipoParticipacao.dupla,
      );
      expect(unidades.length, 2);
      expect(unidades.first.participanteId, 'ana+bia');
    });

    test('a dupla tem o mesmo id independente da ordem de quem convidou', () {
      expect(
        Participante.dupla('bia', 'ana').participanteId,
        Participante.dupla('ana', 'bia').participanteId,
      );
    });
  });

  // ===========================================================================
  // 9. PROCESSAMENTO DE RESULTADO · 10. RESULTADO DUPLICADO
  // ===========================================================================
  group('9. processamento de resultado', () {
    final solicitacao = _solicitacao(
      matchId: 'm1', faseId: 'f1', mesaId: 'f1-mesa-1', ids: ['ana', 'bia'],
    );
    final resultado = _resultado(
      matchId: 'm1', faseId: 'f1', mesaId: 'f1-mesa-1',
      vencedor: 'ana', perdedor: 'bia',
    );

    test('resultado coerente e aceito', () {
      final r = processarResultado(
        resultado: resultado, solicitacao: solicitacao, edicaoEmDisputa: true,
      );
      expect(r.processado, isTrue);
    });

    test('partida nao solicitada e recusada', () {
      final r = processarResultado(
        resultado: resultado, solicitacao: null, edicaoEmDisputa: true,
      );
      expect(r.recusa, RecusaResultado.partidaDesconhecida);
    });

    test('fase divergente e recusada', () {
      final r = processarResultado(
        resultado: _resultado(
          matchId: 'm1', faseId: 'f2', mesaId: 'f1-mesa-1',
          vencedor: 'ana', perdedor: 'bia',
        ),
        solicitacao: solicitacao,
        edicaoEmDisputa: true,
      );
      expect(r.recusa, RecusaResultado.faseIncorreta);
    });

    test('mesa divergente e recusada', () {
      final r = processarResultado(
        resultado: _resultado(
          matchId: 'm1', faseId: 'f1', mesaId: 'f1-mesa-9',
          vencedor: 'ana', perdedor: 'bia',
        ),
        solicitacao: solicitacao,
        edicaoEmDisputa: true,
      );
      expect(r.recusa, RecusaResultado.mesaIncorreta);
    });

    test('participante fora da mesa e recusado', () {
      final r = processarResultado(
        resultado: _resultado(
          matchId: 'm1', faseId: 'f1', mesaId: 'f1-mesa-1',
          vencedor: 'ana', perdedor: 'intruso',
        ),
        solicitacao: solicitacao,
        edicaoEmDisputa: true,
      );
      expect(r.recusa, RecusaResultado.participantesDivergentes);
    });

    test('edicao fora de disputa recusa o resultado', () {
      final r = processarResultado(
        resultado: resultado, solicitacao: solicitacao, edicaoEmDisputa: false,
      );
      expect(r.recusa, RecusaResultado.edicaoForaDeDisputa);
    });

    test('vencedor fora dos lados e recusado na construcao', () {
      expect(
        () => ResultadoPartida(
          matchId: 'm', tournamentId: 't', editionId: 'e', faseId: 'f', mesaId: 'me',
          lados: const [
            LadoResultado(participanteId: 'a', pontos: 1, canastrasLimpas: 0),
            LadoResultado(participanteId: 'b', pontos: 0, canastrasLimpas: 0),
          ],
          vencedorId: 'c',
          desfecho: DesfechoPartida.normal,
          encerradaEm: _agora,
        ),
        throwsArgumentError,
      );
    });

    test('round-trip toJson -> fromMap preserva o resultado', () {
      final volta = ResultadoPartida.fromMap(resultado.toJson());
      expect(volta.chaveIdempotencia, resultado.chaveIdempotencia);
      expect(volta.vencedorId, 'ana');
      expect(volta.lados.length, 2);
    });

    test('chave de idempotencia adulterada e recusada na hidratacao', () {
      final json = resultado.toJson();
      json['chaveIdempotencia'] = 'outra|coisa|qualquer';
      expect(() => ResultadoPartida.fromMap(json), throwsFormatException);
    });

    test('data sem sufixo Z e recusada', () {
      final json = resultado.toJson();
      json['encerradaEm'] = '2026-08-07T20:00:00';
      expect(() => ResultadoPartida.fromMap(json), throwsFormatException);
    });
  });

  group('10. resultado duplicado', () {
    test('reenvio do mesmo resultado e recusado como ja processado', () {
      final solicitacao = _solicitacao(
        matchId: 'm1', faseId: 'f1', mesaId: 'f1-mesa-1', ids: ['ana', 'bia'],
      );
      final resultado = _resultado(
        matchId: 'm1', faseId: 'f1', mesaId: 'f1-mesa-1',
        vencedor: 'ana', perdedor: 'bia',
      );
      final r = processarResultado(
        resultado: resultado,
        solicitacao: solicitacao,
        edicaoEmDisputa: true,
        processados: [resultado.chaveIdempotencia],
      );
      expect(r.recusa, RecusaResultado.jaProcessado);
      // Reenvio por timeout nao e falha: a camada de transporte responde 200.
      expect(r.idempotente, isTrue);
    });

    test('resultado duplicado nao dobra a pontuacao', () {
      final resultado = _resultado(
        matchId: 'm1', faseId: 'f1', mesaId: 'f1-mesa-1',
        vencedor: 'ana', perdedor: 'bia',
      );
      final uma = agregarDesempenho(resultados: [resultado]);
      // O motor de agregacao recebe a lista JA deduplicada por
      // processarResultado; este teste fixa que uma unica entrada produz uma
      // unica vitoria, que e a garantia da qual a deduplicacao depende.
      expect(uma['ana']!.vitorias, 1);
      expect(uma['ana']!.partidasConcluidas, 1);
    });

    test('duas edicoes diferentes com o mesmo matchId nao colidem', () {
      final a = _resultado(
        matchId: 'm1', faseId: 'f1', mesaId: 'me', vencedor: 'ana', perdedor: 'bia',
      );
      final b = ResultadoPartida(
        matchId: 'm1', tournamentId: 'copa_buraco_master', editionId: 'ed-2026-09',
        faseId: 'f1', mesaId: 'me',
        lados: const [
          LadoResultado(participanteId: 'ana', pontos: 1500, canastrasLimpas: 1),
          LadoResultado(participanteId: 'bia', pontos: 900, canastrasLimpas: 0),
        ],
        vencedorId: 'ana', desfecho: DesfechoPartida.normal, encerradaEm: _agora,
      );
      expect(a.chaveIdempotencia, isNot(b.chaveIdempotencia));
    });
  });

  // ===========================================================================
  // 11. AVANCO DE FASE · 12. ELIMINACAO
  // ===========================================================================
  group('11. avanco de fase e 12. eliminacao', () {
    Fase fase({StatusFase status = StatusFase.emAndamento, int? vagas = 2}) => Fase(
          faseId: 'f1',
          tournamentId: 'copa_buraco_master',
          editionId: 'ed-2026-08',
          ordem: 1,
          tipo: TipoFase.inicial,
          semente: 1,
          ladosPorMesa: 2,
          status: status,
          vagasAvanco: vagas,
        );

    List<Mesa> mesas({StatusMesa status = StatusMesa.encerrada}) => [
          Mesa(
            mesaId: 'f1-mesa-1', tournamentId: 'copa_buraco_master',
            editionId: 'ed-2026-08', faseId: 'f1',
            assentos: [Participante.individual('ana'), Participante.individual('bia')],
            status: status,
          ),
          Mesa(
            mesaId: 'f1-mesa-2', tournamentId: 'copa_buraco_master',
            editionId: 'ed-2026-08', faseId: 'f1',
            assentos: [Participante.individual('caio'), Participante.individual('duda')],
            status: status,
          ),
        ];

    final resultados = [
      _resultado(matchId: 'm1', faseId: 'f1', mesaId: 'f1-mesa-1', vencedor: 'ana', perdedor: 'bia'),
      _resultado(
        matchId: 'm2', faseId: 'f1', mesaId: 'f1-mesa-2', vencedor: 'caio', perdedor: 'duda',
        pontosVencedor: 1500, pontosPerdedor: 1200, canastrasVencedor: 2,
      ),
    ];

    test('fase com mesa aberta nao apura', () {
      final r = apurarFase(
        fase: fase(), mesas: mesas(status: StatusMesa.emJogo),
        resultados: resultados, criterios: desempatePadrao,
      );
      expect(r.recusa, RecusaAvanco.faseIncompleta);
    });

    test('fase completa apura e promove os classificados', () {
      final r = apurarFase(
        fase: fase(), mesas: mesas(), resultados: resultados, criterios: desempatePadrao,
      );
      expect(r.apurada, isTrue);
      expect(r.avancam.length, 2);
      // Ana e Caio venceram; Ana tem saldo maior (600 contra 300).
      expect(r.avancam, ['ana', 'caio']);
      expect(r.classificacao.last.situacao, SituacaoClassificacao.eliminado);
    });

    test('fase ja concluida recusa reprocessamento', () {
      final r = apurarFase(
        fase: fase(status: StatusFase.concluida), mesas: mesas(),
        resultados: resultados, criterios: desempatePadrao,
      );
      expect(r.recusa, RecusaAvanco.faseJaConcluida);
    });

    test('fase sem vagas declaradas recusa', () {
      final r = apurarFase(
        fase: fase(vagas: null), mesas: mesas(),
        resultados: resultados, criterios: desempatePadrao,
      );
      expect(r.recusa, RecusaAvanco.vagasNaoDefinidas);
    });

    test('a apuracao usa so os resultados da propria fase', () {
      final comOutraFase = [
        ...resultados,
        _resultado(matchId: 'm9', faseId: 'f2', mesaId: 'f2-mesa-1', vencedor: 'bia', perdedor: 'duda'),
      ];
      final r = apurarFase(
        fase: fase(), mesas: mesas(), resultados: comOutraFase, criterios: desempatePadrao,
      );
      // A vitoria de Bia na fase 2 nao pode salva-la da eliminacao na fase 1.
      expect(r.avancam, isNot(contains('bia')));
    });

    test('mesa cancelada nao impede a conclusao da fase', () {
      final comCancelada = [
        ...mesas(),
        Mesa(
          mesaId: 'f1-mesa-3', tournamentId: 'copa_buraco_master',
          editionId: 'ed-2026-08', faseId: 'f1',
          assentos: [Participante.individual('x'), Participante.individual('y')],
          status: StatusMesa.cancelada,
        ),
      ];
      expect(faseConcluida(comCancelada), isTrue);
    });

    test('fase sem mesa nenhuma nao conclui', () {
      expect(faseConcluida(const []), isFalse);
    });

    test('montarFases respeita o formato e a ultima fase e a decisiva', () {
      final fases = montarFases(
        tournamentId: 'copa_buraco_master',
        editionId: 'ed-2026-08',
        totalFases: 3,
        formato: FormatoTorneio.misto,
        semente: 10,
        ladosPorMesa: 2,
        vagasPorFase: const [4, 2],
      );
      expect(fases.length, 3);
      expect(fases.last.tipo, TipoFase.finalDecisiva);
      expect(fases[1].tipo, TipoFase.semifinal);
      expect(fases.last.vagasAvanco, isNull);
      // Sementes derivadas: reformar a fase 2 nao remonta a fase 1.
      expect(fases.map((f) => f.semente).toSet().length, 3);
    });

    test('montarFases recusa numeroFases indefinido', () {
      expect(
        () => montarFases(
          tournamentId: 't', editionId: 'e',
          totalFases: null,
          formato: FormatoTorneio.misto,
          semente: 1, ladosPorMesa: 2,
        ),
        throwsArgumentError,
      );
    });
  });

  // ===========================================================================
  // 13. CLASSIFICACAO · 14. EMPATE · 15. DESEMPATE
  // ===========================================================================
  group('13. classificacao', () {
    test('ordena por vitorias e depois por saldo', () {
      final classificacao = calcularClassificacao(
        resultados: [
          _resultado(matchId: 'm1', faseId: 'f1', mesaId: 'me1', vencedor: 'ana', perdedor: 'bia', pontosVencedor: 1500, pontosPerdedor: 500),
          _resultado(matchId: 'm2', faseId: 'f1', mesaId: 'me2', vencedor: 'caio', perdedor: 'duda', pontosVencedor: 1500, pontosPerdedor: 1400),
        ],
        criterios: desempatePadrao,
      );
      expect(classificacao.map((l) => l.participanteId), ['ana', 'caio', 'duda', 'bia']);
      expect(classificacao.first.posicao, 1);
    });

    test('quem nao jogou aparece zerado em vez de sumir', () {
      final classificacao = calcularClassificacao(
        resultados: const [],
        criterios: desempatePadrao,
        participantes: const ['ana', 'bia'],
      );
      expect(classificacao.length, 2);
      expect(classificacao.first.desempenho.partidasConcluidas, 0);
    });

    test('partida anulada nao pontua para ninguem', () {
      final agregado = agregarDesempenho(
        resultados: [
          _resultado(
            matchId: 'm1', faseId: 'f1', mesaId: 'me', vencedor: 'ana', perdedor: 'bia',
            desfecho: DesfechoPartida.anulada,
          ),
        ],
        participantes: const ['ana', 'bia'],
      );
      expect(agregado['ana']!.partidasConcluidas, 0);
      expect(agregado['bia']!.derrotas, 0);
    });

    test('abandono conta vitoria para quem ficou', () {
      final agregado = agregarDesempenho(
        resultados: [
          _resultado(
            matchId: 'm1', faseId: 'f1', mesaId: 'me', vencedor: 'ana', perdedor: 'bia',
            desfecho: DesfechoPartida.abandono,
          ),
        ],
      );
      expect(agregado['ana']!.vitorias, 1);
      expect(agregado['bia']!.derrotas, 1);
    });

    test('pontos sofridos sao os pontos do adversario', () {
      final agregado = agregarDesempenho(
        resultados: [
          _resultado(
            matchId: 'm1', faseId: 'f1', mesaId: 'me', vencedor: 'ana', perdedor: 'bia',
            pontosVencedor: 1500, pontosPerdedor: 900,
          ),
        ],
      );
      expect(agregado['ana']!.pontosSofridos, 900);
      expect(agregado['ana']!.saldo, 600);
      expect(agregado['bia']!.saldo, -600);
    });

    test('a classificacao e deterministica entre chamadas', () {
      List<String> ordem() => calcularClassificacao(
            resultados: [
              _resultado(matchId: 'm1', faseId: 'f1', mesaId: 'me1', vencedor: 'ana', perdedor: 'bia'),
              _resultado(matchId: 'm2', faseId: 'f1', mesaId: 'me2', vencedor: 'caio', perdedor: 'duda'),
            ],
            criterios: desempatePadrao,
          ).map((l) => l.participanteId).toList();
      expect(ordem(), ordem());
    });
  });

  group('14. empate e 15. desempate', () {
    // Ana e Caio: mesma vitoria, mesmo saldo, mesmos pontos feitos.
    // O que os separa e a canastra limpa.
    final empatados = [
      _resultado(
        matchId: 'm1', faseId: 'f1', mesaId: 'me1', vencedor: 'ana', perdedor: 'bia',
        pontosVencedor: 1500, pontosPerdedor: 900, canastrasVencedor: 5,
      ),
      _resultado(
        matchId: 'm2', faseId: 'f1', mesaId: 'me2', vencedor: 'caio', perdedor: 'duda',
        pontosVencedor: 1500, pontosPerdedor: 900, canastrasVencedor: 2,
      ),
    ];

    test('canastras limpas desempatam quando vitorias, saldo e pontos empatam', () {
      final classificacao = calcularClassificacao(
        resultados: empatados, criterios: desempatePadrao,
      );
      expect(classificacao.first.participanteId, 'ana');
      expect(classificacao[1].participanteId, 'caio');
      expect(classificacao[1].empateNaoResolvido, isFalse);
    });

    test('empate em TODOS os criterios esportivos e sinalizado', () {
      final identicos = [
        _resultado(
          matchId: 'm1', faseId: 'f1', mesaId: 'me1', vencedor: 'ana', perdedor: 'bia',
          pontosVencedor: 1500, pontosPerdedor: 900, canastrasVencedor: 3, canastrasPerdedor: 1,
        ),
        _resultado(
          matchId: 'm2', faseId: 'f1', mesaId: 'me2', vencedor: 'caio', perdedor: 'duda',
          pontosVencedor: 1500, pontosPerdedor: 900, canastrasVencedor: 3, canastrasPerdedor: 1,
        ),
      ];
      final classificacao = calcularClassificacao(
        resultados: identicos, criterios: desempatePadrao,
      );
      expect(classificacao[1].empateNaoResolvido, isTrue,
          reason: 'ana e caio empatam em tudo; so o desempate administrativo os separa');
    });

    test('a ordem dos criterios do template muda a classificacao', () {
      // Priorizando canastras, Caio (5) passaria na frente de Ana (2), mesmo com
      // saldo pior. Fixa que trocar o criterio nao exige tocar no motor
      // (OS 02 secao 11).
      final resultados = [
        _resultado(
          matchId: 'm1', faseId: 'f1', mesaId: 'me1', vencedor: 'ana', perdedor: 'bia',
          pontosVencedor: 1500, pontosPerdedor: 100, canastrasVencedor: 2,
        ),
        _resultado(
          matchId: 'm2', faseId: 'f1', mesaId: 'me2', vencedor: 'caio', perdedor: 'duda',
          pontosVencedor: 1500, pontosPerdedor: 1400, canastrasVencedor: 5,
        ),
      ];
      final porSaldo = calcularClassificacao(
        resultados: resultados, criterios: desempatePadrao,
      );
      final porCanastra = calcularClassificacao(
        resultados: resultados,
        criterios: const [
          CriterioDesempate.vitorias,
          CriterioDesempate.canastrasLimpas,
          CriterioDesempate.desempateAdministrativo,
        ],
      );
      expect(porSaldo.first.participanteId, 'ana');
      expect(porCanastra.first.participanteId, 'caio');
    });

    test('corte sobre empate nao resolvido e recusado em vez de arbitrado', () {
      final identicos = [
        _resultado(
          matchId: 'm1', faseId: 'f1', mesaId: 'me1', vencedor: 'ana', perdedor: 'bia',
          pontosVencedor: 1500, pontosPerdedor: 900, canastrasVencedor: 3, canastrasPerdedor: 1,
        ),
        _resultado(
          matchId: 'm2', faseId: 'f1', mesaId: 'me2', vencedor: 'caio', perdedor: 'duda',
          pontosVencedor: 1500, pontosPerdedor: 900, canastrasVencedor: 3, canastrasPerdedor: 1,
        ),
      ];
      final classificacao = calcularClassificacao(
        resultados: identicos, criterios: desempatePadrao,
      );
      // Corte em 1 vaga cairia entre ana e caio, que empatam em tudo.
      expect(() => aplicarCorte(classificacao, vagas: 1), throwsStateError);
      // Corte em 2 vagas nao cai sobre o empate e passa.
      expect(() => aplicarCorte(classificacao, vagas: 2), returnsNormally);
    });

    test('corte maior que a lista promove todos', () {
      final classificacao = calcularClassificacao(
        resultados: const [], criterios: desempatePadrao, participantes: const ['ana', 'bia'],
      );
      final cortada = aplicarCorte(classificacao, vagas: 5);
      expect(cortada.every((l) => l.situacao == SituacaoClassificacao.avancou), isTrue);
    });
  });

  // ===========================================================================
  // 16. FINALISTA · 17. CAMPEAO · 18. CONCLUSAO
  // ===========================================================================
  group('16. definicao de finalista', () {
    test('a semifinal apura e entrega dois finalistas', () {
      final semi = Fase(
        faseId: 'f2', tournamentId: 'copa_buraco_master', editionId: 'ed-2026-08',
        ordem: 2, tipo: TipoFase.semifinal, semente: 2, ladosPorMesa: 2,
        status: StatusFase.emAndamento, vagasAvanco: 2,
      );
      final mesas = [
        Mesa(
          mesaId: 'f2-mesa-1', tournamentId: 'copa_buraco_master', editionId: 'ed-2026-08',
          faseId: 'f2',
          assentos: [Participante.individual('ana'), Participante.individual('bia')],
          status: StatusMesa.encerrada,
        ),
        Mesa(
          mesaId: 'f2-mesa-2', tournamentId: 'copa_buraco_master', editionId: 'ed-2026-08',
          faseId: 'f2',
          assentos: [Participante.individual('caio'), Participante.individual('duda')],
          status: StatusMesa.encerrada,
        ),
      ];
      final r = apurarFase(
        fase: semi,
        mesas: mesas,
        resultados: [
          _resultado(matchId: 'm1', faseId: 'f2', mesaId: 'f2-mesa-1', vencedor: 'ana', perdedor: 'bia'),
          _resultado(matchId: 'm2', faseId: 'f2', mesaId: 'f2-mesa-2', vencedor: 'caio', perdedor: 'duda', pontosPerdedor: 1000),
        ],
        criterios: desempatePadrao,
      );
      expect(r.avancam.length, 2);
      expect(r.avancam.toSet(), {'ana', 'caio'});
    });

    test('a fase decisiva nao avanca: ela produz classificacao final', () {
      final finalFase = Fase(
        faseId: 'f3', tournamentId: 'copa_buraco_master', editionId: 'ed-2026-08',
        ordem: 3, tipo: TipoFase.finalDecisiva, semente: 3, ladosPorMesa: 2,
        status: StatusFase.emAndamento,
      );
      final mesas = [
        Mesa(
          mesaId: 'f3-mesa-1', tournamentId: 'copa_buraco_master', editionId: 'ed-2026-08',
          faseId: 'f3',
          assentos: [Participante.individual('ana'), Participante.individual('caio')],
          status: StatusMesa.encerrada,
        ),
      ];
      final resultados = [
        _resultado(matchId: 'm3', faseId: 'f3', mesaId: 'f3-mesa-1', vencedor: 'ana', perdedor: 'caio'),
      ];
      expect(
        apurarFase(fase: finalFase, mesas: mesas, resultados: resultados, criterios: desempatePadrao).recusa,
        RecusaAvanco.faseDecisiva,
      );
      final decisiva = apurarFaseDecisiva(
        fase: finalFase, mesas: mesas, resultados: resultados, criterios: desempatePadrao,
      );
      expect(decisiva.apurada, isTrue);
      expect(decisiva.classificacao.first.participanteId, 'ana');
    });
  });

  group('17. definicao de campeao e 18. conclusao', () {
    List<LinhaClassificacao> classificacaoFinal() => calcularClassificacao(
          resultados: [
            _resultado(matchId: 'm1', faseId: 'f3', mesaId: 'me', vencedor: 'ana', perdedor: 'caio'),
          ],
          criterios: desempatePadrao,
        );

    test('conclui e registra campeao, vice e classificacao', () {
      final r = concluirEdicao(
        tournamentId: 'copa_buraco_master',
        editionId: 'ed-2026-08',
        classificacaoFinal: classificacaoFinal(),
        agora: _agora,
        edicaoEncerravel: true,
      );
      expect(r.concluida, isTrue);
      expect(r.conclusao!.campeaoId, 'ana');
      expect(r.conclusao!.viceId, 'caio');
      expect(r.conclusao!.chaveIdempotencia, 'copa_buraco_master|ed-2026-08');
    });

    test('registra a dupla campea inteira', () {
      final classificacao = calcularClassificacao(
        resultados: [
          _resultado(matchId: 'm1', faseId: 'f3', mesaId: 'me', vencedor: 'ana+bia', perdedor: 'caio+duda'),
        ],
        criterios: desempatePadrao,
      );
      final r = concluirEdicao(
        tournamentId: 'copa_buraco_master', editionId: 'ed-2026-08',
        classificacaoFinal: classificacao, agora: _agora, edicaoEncerravel: true,
      );
      expect(r.conclusao!.campeoes, ['ana', 'bia']);
    });

    test('DOIS CAMPEOES NA MESMA EDICAO SAO IMPOSSIVEIS', () {
      final r = concluirEdicao(
        tournamentId: 'copa_buraco_master', editionId: 'ed-2026-08',
        classificacaoFinal: classificacaoFinal(), agora: _agora, edicaoEncerravel: true,
        conclusoes: const ['copa_buraco_master|ed-2026-08'],
      );
      expect(r.recusa, RecusaConclusao.jaConcluida);
      expect(r.idempotente, isTrue);
    });

    test('empate no topo recusa a conclusao em vez de arbitrar o titulo', () {
      final identicos = calcularClassificacao(
        resultados: [
          _resultado(
            matchId: 'm1', faseId: 'f3', mesaId: 'me1', vencedor: 'ana', perdedor: 'bia',
            pontosVencedor: 1500, pontosPerdedor: 900, canastrasVencedor: 3, canastrasPerdedor: 1,
          ),
          _resultado(
            matchId: 'm2', faseId: 'f3', mesaId: 'me2', vencedor: 'caio', perdedor: 'duda',
            pontosVencedor: 1500, pontosPerdedor: 900, canastrasVencedor: 3, canastrasPerdedor: 1,
          ),
        ],
        criterios: desempatePadrao,
      );
      final r = concluirEdicao(
        tournamentId: 'copa_buraco_master', editionId: 'ed-2026-08',
        classificacaoFinal: identicos, agora: _agora, edicaoEncerravel: true,
      );
      expect(r.recusa, RecusaConclusao.empateNoTopo);
    });

    test('classificacao vazia recusa a conclusao', () {
      final r = concluirEdicao(
        tournamentId: 't', editionId: 'e', classificacaoFinal: const [],
        agora: _agora, edicaoEncerravel: true,
      );
      expect(r.recusa, RecusaConclusao.semClassificacao);
    });

    test('edicao nao encerravel recusa a conclusao', () {
      final r = concluirEdicao(
        tournamentId: 't', editionId: 'e', classificacaoFinal: classificacaoFinal(),
        agora: _agora, edicaoEncerravel: false,
      );
      expect(r.recusa, RecusaConclusao.edicaoNaoEncerravel);
    });

    test('status encerrado e terminal: nao ha volta', () {
      expect(EdicaoStatus.encerrado.terminal, isTrue);
      expect(
        avaliarTransicao(
          de: EdicaoStatus.encerrado, para: EdicaoStatus.emAndamento,
          ator: AtorTransicao.administracao,
        ).recusa,
        RecusaTransicao.origemTerminal,
      );
    });
  });

  // ===========================================================================
  // 19. PREMIACAO · 20. PREMIACAO CHAMADA DUAS VEZES
  // ===========================================================================
  group('19. premiacao', () {
    final assets = TorneioAssetsRegistry.fromMap(_seed('assets_registry.seed.json'));
    final politicas = RewardPoliciesRegistry.fromMap(_seed('reward_policies.seed.json'));

    ConclusaoEdicao conclusao({List<String> ordem = const ['ana', 'bia', 'caio']}) =>
        ConclusaoEdicao(
          tournamentId: 'copa_buraco_master',
          editionId: 'ed-2026-08',
          campeaoId: ordem.first,
          campeoes: Participante.deId(ordem.first).membros,
          viceId: ordem.length > 1 ? ordem[1] : null,
          terceiroId: ordem.length > 2 ? ordem[2] : null,
          classificacaoFinal: ordem,
          totalParticipantes: ordem.length,
          concluidaEm: _agora,
        );

    test('a colocacao vira concessao pela faixa do template', () {
      final planejadas = planejarPremiacao(
        conclusao: conclusao(), template: _template(),
        assets: assets, politicas: politicas, agora: _agora,
      );
      final campea = planejadas.firstWhere((p) => p.userId == 'ana');
      expect(campea.resultado.concedida, isTrue);
      expect(campea.resultado.concessao!.assetId, TorneioAssetIds.crownChampion);
      expect(campea.resultado.concessao!.colocacao, 1);
      expect(campea.fichas, 1000);
    });

    test('cada membro da dupla recebe a propria concessao', () {
      final planejadas = planejarPremiacao(
        conclusao: conclusao(ordem: const ['ana+bia', 'caio+duda']),
        template: _template(participacao: TipoParticipacao.dupla),
        assets: assets, politicas: politicas, agora: _agora,
      );
      final campeas = planejadas.where((p) => p.colocacao == 1).toList();
      expect(campeas.map((p) => p.userId).toSet(), {'ana', 'bia'});
      // As duas chaves sao distintas porque o userId entra nelas.
      expect(
        campeas.map((p) => p.resultado.concessao!.chaveIdempotencia).toSet().length,
        2,
      );
    });

    test('colocacao sem faixa nao gera premio', () {
      final planejadas = planejarPremiacao(
        conclusao: conclusao(ordem: const ['a', 'b', 'c', 'd', 'e', 'f']),
        template: _template(),
        assets: assets, politicas: politicas, agora: _agora,
      );
      // As faixas cobrem 1, 2 e 3 — nao existe Top 4. Do 4o em diante ninguem
      // e premiado.
      expect(planejadas.map((p) => p.userId), isNot(contains('d')));
      expect(planejadas.map((p) => p.userId), isNot(contains('e')));
      expect(planejadas.length, 3);
    });

    test('arte pendente recusa a concessao com motivo explicito', () {
      final planejadas = planejarPremiacao(
        conclusao: conclusao(ordem: const ['ana']),
        template: _template(premiacao: const [
          FaixaPremiacao(colocacao: 1, crownAssetId: TorneioAssetIds.crownClosingChampion),
        ]),
        assets: assets, politicas: politicas, agora: _agora,
      );
      expect(planejadas.single.resultado.concedida, isFalse);
      expect(planejadas.single.resultado.recusa, RecusaConcessao.artePendente);
    });

    test('faixa so de fichas nao tenta conceder ativo de catalogo', () {
      final planejadas = planejarPremiacao(
        conclusao: conclusao(ordem: const ['ana']),
        template: _template(premiacao: const [
          FaixaPremiacao(colocacao: 1, fichas: 800),
        ]),
        assets: assets, politicas: politicas, agora: _agora,
      );
      expect(planejadas.single.fichas, 800);
      expect(planejadas.single.resultado.concedida, isFalse);
    });
  });

  group('20. premiacao chamada duas vezes', () {
    final assets = TorneioAssetsRegistry.fromMap(_seed('assets_registry.seed.json'));
    final politicas = RewardPoliciesRegistry.fromMap(_seed('reward_policies.seed.json'));

    final conclusao = ConclusaoEdicao(
      tournamentId: 'copa_buraco_master', editionId: 'ed-2026-08',
      campeaoId: 'ana', campeoes: const ['ana'], viceId: 'bia',
      classificacaoFinal: const ['ana', 'bia'], totalParticipantes: 2,
      concluidaEm: _agora,
    );

    test('reprocessar a premiacao NAO premia de novo', () {
      final primeira = planejarPremiacao(
        conclusao: conclusao, template: _template(),
        assets: assets, politicas: politicas, agora: _agora,
      );
      final concedidas = primeira
          .where((p) => p.resultado.concedida)
          .map((p) => p.resultado.concessao!)
          .toList();
      expect(concedidas, isNotEmpty);

      final segunda = planejarPremiacao(
        conclusao: conclusao, template: _template(),
        assets: assets, politicas: politicas,
        agora: _agora.add(const Duration(hours: 1)),
        historico: concedidas,
      );
      expect(segunda.every((p) => !p.resultado.concedida), isTrue);
      expect(
        segunda.map((p) => p.resultado.recusa),
        everyElement(RecusaConcessao.concessaoDuplicada),
      );
    });

    test('duas faixas do mesmo ativo para o mesmo jogador nao passam as duas', () {
      // Faixas nao sobrepostas, mas apontando para o MESMO assetId. Sem o
      // acumulador interno, as duas passariam e a duplicidade so apareceria na
      // gravacao.
      final planejadas = planejarPremiacao(
        conclusao: ConclusaoEdicao(
          tournamentId: 'copa_buraco_master', editionId: 'ed-2026-08',
          campeaoId: 'ana', campeoes: const ['ana'],
          classificacaoFinal: const ['ana'], totalParticipantes: 1,
          concluidaEm: _agora,
        ),
        template: _template(premiacao: const [
          FaixaPremiacao(colocacao: 1, crownAssetId: TorneioAssetIds.crownChampion),
        ]),
        assets: assets, politicas: politicas, agora: _agora,
        historico: [
          concederRecompensa(
            rewardId: 'r0', userId: 'ana',
            tournamentId: 'copa_buraco_master', editionId: 'ed-2026-08',
            assetId: TorneioAssetIds.crownChampion, grantedAt: _agora,
            motivo: MotivoConcessao.colocacao, colocacao: 1,
            assets: assets, politicas: politicas,
          ).concessao!,
        ],
      );
      expect(planejadas.single.resultado.recusa, RecusaConcessao.concessaoDuplicada);
    });
  });

  // ===========================================================================
  // 21. REPROCESSAMENTO
  // ===========================================================================
  group('21. reprocessamento', () {
    test('a chave da tarefa nao depende do instante de execucao', () {
      final edicao = _edicao(status: EdicaoStatus.agendado);
      String chave(DateTime quando) => planejarTarefas(
            edicao: edicao, template: _template(), agora: quando,
          ).single.chaveIdempotencia;

      expect(chave(_agora), chave(_agora.add(const Duration(hours: 3))));
    });

    test('tarefa ja executada some do plano', () {
      final pendentes = planejarTarefas(
        edicao: _edicao(status: EdicaoStatus.agendado),
        template: _template(), agora: _agora,
      );
      final restantes = tarefasNaoExecutadas(
        pendentes, {pendentes.single.chaveIdempotencia},
      );
      expect(restantes, isEmpty);
    });

    test('cada fase apuravel tem chave propria', () {
      final tarefas = planejarTarefas(
        edicao: _edicao(status: EdicaoStatus.emAndamento),
        template: _template(), agora: _agora,
        contexto: const ContextoAutomacao(fasesApuraveis: ['f1', 'f2']),
      );
      expect(tarefas.length, 2);
      expect(tarefas.map((t) => t.chaveIdempotencia).toSet().length, 2);
    });

    test('edicao suspensa nao gera tarefa', () {
      final edicao = EdicaoTorneio(
        tournamentId: 'copa_buraco_master', editionId: 'ed-2026-08',
        numeroEdicao: 1, temporada: '2026',
        status: EdicaoStatus.suspenso, statusAnterior: EdicaoStatus.inscricoesAbertas,
        inicioPrevisto: _agora.add(const Duration(hours: 4)),
        regraVersao: 3, criadoEm: _agora, atualizadoEm: _agora,
      );
      expect(planejarTarefas(edicao: edicao, template: _template(), agora: _agora), isEmpty);
    });

    test('edicao encerrada nao gera tarefa', () {
      expect(
        planejarTarefas(
          edicao: _edicao(status: EdicaoStatus.encerrado),
          template: _template(), agora: _agora,
        ),
        isEmpty,
      );
    });

    test('sem quorum a edicao nao anda sozinha', () {
      final tarefas = planejarTarefas(
        edicao: _edicao(status: EdicaoStatus.inscricoesEncerradas),
        template: _template(), agora: _agora,
        contexto: const ContextoAutomacao(quorumAtingido: false),
      );
      expect(tarefas, isEmpty);
    });

    test('a chave rejeita segmento com o separador', () {
      expect(
        () => ChaveTarefa.de(
          tarefa: TarefaAutomatica.abrirInscricoes,
          tournamentId: 'a|b', editionId: 'e',
        ),
        throwsArgumentError,
      );
    });
  });

  // ===========================================================================
  // 22. HISTORICO
  // ===========================================================================
  group('22. historico', () {
    final assets = TorneioAssetsRegistry.fromMap(_seed('assets_registry.seed.json'));
    final politicas = RewardPoliciesRegistry.fromMap(_seed('reward_policies.seed.json'));

    RegistroHistorico montar() {
      final classificacao = calcularClassificacao(
        resultados: [
          _resultado(matchId: 'm1', faseId: 'f1', mesaId: 'me', vencedor: 'ana', perdedor: 'bia'),
        ],
        criterios: desempatePadrao,
      );
      final conclusao = concluirEdicao(
        tournamentId: 'copa_buraco_master', editionId: 'ed-2026-08',
        classificacaoFinal: classificacao, agora: _agora, edicaoEncerravel: true,
      ).conclusao!;
      final premiacoes = planejarPremiacao(
        conclusao: conclusao, template: _template(),
        assets: assets, politicas: politicas, agora: _agora,
      );
      return montarHistorico(
        edicao: _edicao(status: EdicaoStatus.encerrado),
        template: _template(),
        conclusao: conclusao,
        classificacaoFinal: classificacao,
        fases: const ['f1'],
        totalPartidas: 1,
        premiacoes: premiacoes,
      );
    }

    test('o historico congela campeao, classificacao e premios', () {
      final h = montar();
      expect(h.campeaoId, 'ana');
      expect(h.classificacaoFinal.length, 2);
      expect(h.premiacoes, isNotEmpty);
      expect(h.totalPartidas, 1);
    });

    test('congela a versao da regra e os criterios vigentes', () {
      final h = montar();
      expect(h.regraVersao, 3);
      expect(h.criteriosDesempate, desempatePadrao);
    });

    test('so o que foi efetivamente concedido entra no historico', () {
      final conclusao = ConclusaoEdicao(
        tournamentId: 'copa_buraco_master', editionId: 'ed-2026-08',
        campeaoId: 'ana', campeoes: const ['ana'],
        classificacaoFinal: const ['ana'], totalParticipantes: 1, concluidaEm: _agora,
      );
      final premiacoes = planejarPremiacao(
        conclusao: conclusao,
        template: _template(premiacao: const [
          FaixaPremiacao(colocacao: 1, crownAssetId: TorneioAssetIds.crownClosingChampion),
        ]),
        assets: assets, politicas: politicas, agora: _agora,
      );
      final h = montarHistorico(
        edicao: _edicao(status: EdicaoStatus.encerrado), template: _template(),
        conclusao: conclusao,
        classificacaoFinal: calcularClassificacao(
          resultados: const [], criterios: desempatePadrao, participantes: const ['ana'],
        ),
        fases: const ['f1'], totalPartidas: 0, premiacoes: premiacoes,
      );
      // A arte esta pendente: a recusa nao pode virar premio no perfil.
      expect(h.premiacoes, isEmpty);
    });

    test('round-trip toJson -> fromMap preserva o registro', () {
      final h = montar();
      final volta = RegistroHistorico.fromMap(h.toJson());
      expect(volta.chaveIdempotencia, h.chaveIdempotencia);
      expect(volta.campeaoId, h.campeaoId);
      expect(volta.classificacaoFinal.length, h.classificacaoFinal.length);
      expect(volta.criteriosDesempate, h.criteriosDesempate);
    });

    test('o formato do historico e o da EDICAO, nao um parametro solto', () {
      final h = montar();
      expect(h.formato, _edicao().formato);
      expect(h.formato, FormatoTorneio.misto);
    });

    test('edicao sem formato resolvido FALHA ALTO em vez de inventar um', () {
      // Antes, `formato` era parametro de montarHistorico: dava para apurar a
      // edicao em `misto` e gravar o historico como `pontos_corridos` sem nada
      // reclamar. Agora ha uma fonte so, e a ausencia para o processo.
      final semFormato = EdicaoTorneio(
        tournamentId: 'copa_buraco_master', editionId: 'ed-2026-08',
        numeroEdicao: 3, temporada: '2026', status: EdicaoStatus.encerrado,
        inicioPrevisto: _agora, regraVersao: 3,
        criadoEm: _agora, atualizadoEm: _agora,
      );
      expect(semFormato.formato, isNull);
      expect(
        () => montarHistorico(
          edicao: semFormato,
          template: _template(),
          conclusao: ConclusaoEdicao(
            tournamentId: 'copa_buraco_master', editionId: 'ed-2026-08',
            campeaoId: 'ana', campeoes: const ['ana'],
            classificacaoFinal: const ['ana'], totalParticipantes: 1,
            concluidaEm: _agora,
          ),
          classificacaoFinal: const [],
          fases: const ['f1'],
          totalPartidas: 0,
          premiacoes: const [],
        ),
        throwsArgumentError,
      );
    });

    test('a edicao carrega o formato no round-trip', () {
      final volta = EdicaoTorneio.fromMap(_edicao().toJson());
      expect(volta.formato, FormatoTorneio.misto);
    });

    test('formato gravado desconhecido e recusado, nao lido como ausente', () {
      // Valor corrompido nao pode virar null: a edicao pareceria "sem formato
      // definido" e a falha apontaria para o motivo errado.
      final json = _edicao().toJson();
      json['formato'] = 'suico';
      expect(() => EdicaoTorneio.fromMap(json), throwsFormatException);
    });

    test('consultas de jogador funcionam sobre o historico', () {
      final h = montar();
      expect(h.participou('ana'), isTrue);
      expect(h.colocacaoDe('bia'), 2);
      expect(h.colocacaoDe('ninguem'), isNull);
      expect(titulosDoJogador([h], 'ana'), {'copa_buraco_master'});
      expect(historicoDoJogador([h], 'ana').length, 1);
      expect(historicoDoJogador([h], 'ninguem'), isEmpty);
    });
  });

  // ===========================================================================
  // 23. REGISTRO ANUAL · 24. DUAS CLASSIFICACOES DO MESMO JOGADOR
  // ===========================================================================
  group('23. registro anual de elegibilidade', () {
    test('registra a conquista de vaga', () {
      final r = registrarClassificacaoAnual(
        userId: 'ana', temporada: '2026',
        tournamentId: 'copa_buraco_master', editionId: 'ed-2026-08',
        origem: OrigemClassificacaoAnual.campeaoEdicao, colocacao: 1, agora: _agora,
      );
      expect(r.registrado, isTrue);
      expect(r.registro!.chaveIdempotencia, '2026|copa_buraco_master|ed-2026-08|ana');
    });

    test('reprocessar a mesma edicao NAO cria registro novo', () {
      final primeiro = registrarClassificacaoAnual(
        userId: 'ana', temporada: '2026',
        tournamentId: 'copa_buraco_master', editionId: 'ed-2026-08',
        origem: OrigemClassificacaoAnual.campeaoEdicao, colocacao: 1, agora: _agora,
      ).registro!;
      final segundo = registrarClassificacaoAnual(
        userId: 'ana', temporada: '2026',
        tournamentId: 'copa_buraco_master', editionId: 'ed-2026-08',
        origem: OrigemClassificacaoAnual.campeaoEdicao, colocacao: 1,
        agora: _agora.add(const Duration(days: 1)),
        registros: [primeiro],
      );
      expect(segundo.recusa, RecusaRegistroAnual.registroDuplicado);
    });

    test('indicacao administrativa sem motivo e recusada', () {
      expect(
        () => registrarClassificacaoAnual(
          userId: 'ana', temporada: '2026', tournamentId: 't', editionId: 'e',
          origem: OrigemClassificacaoAnual.indicacaoAdministrativa, agora: _agora,
        ),
        throwsArgumentError,
      );
    });

    test('round-trip do registro anual', () {
      final r = registrarClassificacaoAnual(
        userId: 'ana', temporada: '2026', tournamentId: 't', editionId: 'e',
        origem: OrigemClassificacaoAnual.viceEdicao, colocacao: 2, agora: _agora,
      ).registro!;
      final volta = RegistroClassificacaoAnual.fromMap(r.toJson());
      expect(volta.chaveIdempotencia, r.chaveIdempotencia);
      expect(volta.origem, OrigemClassificacaoAnual.viceEdicao);
    });
  });

  group('24. duas classificacoes do mesmo jogador', () {
    List<RegistroClassificacaoAnual> tresConquistas() => [
          RegistroClassificacaoAnual(
            userId: 'ana', temporada: '2026', tournamentId: 'copa_buraco_master',
            editionId: 'ed-03', origem: OrigemClassificacaoAnual.campeaoEdicao,
            colocacao: 1, registradoEm: _agora.subtract(const Duration(days: 90)),
          ),
          RegistroClassificacaoAnual(
            userId: 'ana', temporada: '2026', tournamentId: 'campeonato_mensal',
            editionId: 'ed-07', origem: OrigemClassificacaoAnual.campeaoMensal,
            colocacao: 1, registradoEm: _agora.subtract(const Duration(days: 30)),
          ),
          RegistroClassificacaoAnual(
            userId: 'bia', temporada: '2026', tournamentId: 'sexta_master_vip',
            editionId: 'ed-12', origem: OrigemClassificacaoAnual.viceEdicao,
            colocacao: 2, registradoEm: _agora.subtract(const Duration(days: 10)),
          ),
        ];

    test('a segunda classificacao do mesmo jogador e ACEITA e preservada', () {
      final registros = tresConquistas();
      final daAna = registros.where((r) => r.userId == 'ana').toList();
      expect(daAna.length, 2);
      // Chaves distintas: as duas conquistas coexistem no historico.
      expect(daAna.map((r) => r.chaveIdempotencia).toSet().length, 2);
    });

    test('duas classificacoes geram UM convite, nao dois', () {
      final convites = consolidarConvites(
        temporada: '2026', registros: tresConquistas(), agora: _agora,
      );
      expect(convites.length, 2, reason: 'ana e bia — um convite cada');
      final daAna = convites.firstWhere((c) => c.userId == 'ana');
      expect(daAna.classificacoes, 2);
      expect(daAna.chaveIdempotencia, '2026|ana');
    });

    test('o convite aponta para a PRIMEIRA classificacao', () {
      final convites = consolidarConvites(
        temporada: '2026', registros: tresConquistas(), agora: _agora,
      );
      final daAna = convites.firstWhere((c) => c.userId == 'ana');
      expect(daAna.registroOrigemChave, '2026|copa_buraco_master|ed-03|ana');
    });

    test('as vagas excedentes ficam consultaveis sem regra inventada', () {
      final excedentes = registrosExcedentes(
        temporada: '2026', registros: tresConquistas(),
      );
      // So a SEGUNDA conquista da Ana. A regra de redistribuicao nao existe e nao
      // foi inventada (OS 02 secao 17) — a lista apenas fica pronta para quando
      // a administracao definir.
      expect(excedentes.length, 1);
      expect(excedentes.single.userId, 'ana');
      expect(excedentes.single.editionId, 'ed-07');
    });

    test('reconsolidar NAO rebaixa um convite ja aceito', () {
      final primeira = consolidarConvites(
        temporada: '2026', registros: tresConquistas(), agora: _agora,
      );
      final aceito = primeira
          .firstWhere((c) => c.userId == 'ana')
          .comStatus(StatusConvite.conviteAceito, em: _agora);

      final segunda = consolidarConvites(
        temporada: '2026', registros: tresConquistas(),
        agora: _agora.add(const Duration(days: 1)), existentes: [aceito],
      );
      final daAna = segunda.firstWhere((c) => c.userId == 'ana');
      expect(daAna.status, StatusConvite.conviteAceito);
      expect(daAna.criadoEm, aceito.criadoEm);
    });

    test('a consolidacao e deterministica', () {
      List<String> ordem() => consolidarConvites(
            temporada: '2026', registros: tresConquistas(), agora: _agora,
          ).map((c) => c.userId).toList();
      expect(ordem(), ordem());
      expect(ordem(), ['ana', 'bia']);
    });

    test('registros de outra temporada nao entram', () {
      final outra = [
        ...tresConquistas(),
        RegistroClassificacaoAnual(
          userId: 'caio', temporada: '2025', tournamentId: 't', editionId: 'e',
          origem: OrigemClassificacaoAnual.campeaoEdicao, colocacao: 1,
          registradoEm: _agora,
        ),
      ];
      final convites = consolidarConvites(
        temporada: '2026', registros: outra, agora: _agora,
      );
      expect(convites.map((c) => c.userId), isNot(contains('caio')));
    });
  });

  // ===========================================================================
  // 25. GERACAO DE CONVITE · 26. BLOQUEIO DE CONVITE DUPLICADO
  // ===========================================================================
  group('25. geracao de convite', () {
    ConviteEncerramento convite(StatusConvite status) => ConviteEncerramento(
          userId: 'ana', temporada: '2026', status: status,
          registroOrigemChave: '2026|t|e|ana', classificacoes: 1,
          criadoEm: _agora, atualizadoEm: _agora,
        );

    test('o fluxo completo do convite avanca estado a estado', () {
      var atual = convite(StatusConvite.elegivel);
      for (final proximo in [
        StatusConvite.convitePendente,
        StatusConvite.conviteGerado,
        StatusConvite.conviteEnviado,
        StatusConvite.conviteAceito,
        StatusConvite.confirmado,
        StatusConvite.participou,
      ]) {
        final r = transicionarConvite(convite: atual, para: proximo, agora: _agora);
        expect(r.aceita, isTrue, reason: 'falhou em ${proximo.wire}');
        atual = r.convite!;
      }
      expect(atual.status, StatusConvite.participou);
    });

    test('pular etapa e recusado', () {
      final r = transicionarConvite(
        convite: convite(StatusConvite.elegivel),
        para: StatusConvite.conviteAceito, agora: _agora,
      );
      expect(r.recusa, RecusaConvite.transicaoInexistente);
    });

    test('estado terminal nao volta atras', () {
      final r = transicionarConvite(
        convite: convite(StatusConvite.conviteRecusado),
        para: StatusConvite.conviteEnviado, agora: _agora,
      );
      expect(r.recusa, RecusaConvite.statusTerminal);
    });

    test('convite inexistente e recusado', () {
      final r = transicionarConvite(
        convite: null, para: StatusConvite.conviteGerado, agora: _agora,
      );
      expect(r.recusa, RecusaConvite.conviteInexistente);
    });

    test('a VM do convite entrega os dados sem gerar arte', () {
      final vm = conviteParaUi(convite(StatusConvite.conviteEnviado));
      expect(vm.statusLabel, 'Convite enviado');
      expect(vm.aguardandoResposta, isTrue);
      expect(vm.classificacoes, 1);
    });
  });

  group('26. bloqueio de convite duplicado', () {
    test('reconsolidar nao cria um segundo convite para o mesmo jogador', () {
      final registros = [
        RegistroClassificacaoAnual(
          userId: 'ana', temporada: '2026', tournamentId: 't1', editionId: 'e1',
          origem: OrigemClassificacaoAnual.campeaoEdicao, colocacao: 1,
          registradoEm: _agora.subtract(const Duration(days: 5)),
        ),
        RegistroClassificacaoAnual(
          userId: 'ana', temporada: '2026', tournamentId: 't2', editionId: 'e2',
          origem: OrigemClassificacaoAnual.campeaoEdicao, colocacao: 1,
          registradoEm: _agora,
        ),
      ];
      final um = consolidarConvites(temporada: '2026', registros: registros, agora: _agora);
      final dois = consolidarConvites(
        temporada: '2026', registros: registros, agora: _agora, existentes: um,
      );
      expect(um.length, 1);
      expect(dois.length, 1);
      expect(dois.single.chaveIdempotencia, um.single.chaveIdempotencia);
    });

    test('transicao nula e recusada em vez de parecer progresso', () {
      final c = ConviteEncerramento(
        userId: 'ana', temporada: '2026', status: StatusConvite.conviteEnviado,
        registroOrigemChave: 'x', classificacoes: 1,
        criadoEm: _agora, atualizadoEm: _agora,
      );
      final r = transicionarConvite(
        convite: c, para: StatusConvite.conviteEnviado, agora: _agora,
      );
      expect(r.recusa, RecusaConvite.transicaoNula);
    });
  });

  // ===========================================================================
  // CASOS EXTRAS IDENTIFICADOS NA AUDITORIA
  // ===========================================================================
  group('extra: seguranca do ciclo de vida (OS 02 secao 21)', () {
    test('JOGADOR NAO MOVE STATUS DE TORNEIO, em nenhuma transicao', () {
      for (final de in EdicaoStatus.values) {
        for (final para in EdicaoStatus.values) {
          final r = avaliarTransicao(de: de, para: para, ator: AtorTransicao.jogador);
          expect(r.permitida, isFalse, reason: '${de.wire} -> ${para.wire}');
          expect(r.recusa, RecusaTransicao.atorNaoAutorizado);
        }
      }
    });

    test('a automacao nao cancela torneio', () {
      expect(
        avaliarTransicao(
          de: EdicaoStatus.inscricoesAbertas, para: EdicaoStatus.cancelado,
          ator: AtorTransicao.sistema,
        ).recusa,
        RecusaTransicao.atorNaoAutorizado,
      );
      expect(
        avaliarTransicao(
          de: EdicaoStatus.inscricoesAbertas, para: EdicaoStatus.cancelado,
          ator: AtorTransicao.administracao,
        ).permitida,
        isTrue,
      );
    });

    test('a automacao nao reabre inscricoes', () {
      expect(
        avaliarTransicao(
          de: EdicaoStatus.inscricoesEncerradas, para: EdicaoStatus.inscricoesAbertas,
          ator: AtorTransicao.sistema,
        ).recusa,
        RecusaTransicao.atorNaoAutorizado,
      );
    });

    test('transicao inexistente e recusada', () {
      expect(
        avaliarTransicao(
          de: EdicaoStatus.rascunho, para: EdicaoStatus.emAndamento,
          ator: AtorTransicao.administracao,
        ).recusa,
        RecusaTransicao.transicaoInexistente,
      );
    });

    test('suspender e retomar preservam o status de origem', () {
      const origem = EdicaoStatus.inscricoesAbertas;
      final suspensao = avaliarSuspensao(de: origem, ator: AtorTransicao.administracao);
      expect(suspensao.destino, EdicaoStatus.suspenso);

      final retomada = avaliarRetomada(
        de: EdicaoStatus.suspenso, statusAnterior: origem,
        ator: AtorTransicao.administracao,
      );
      expect(retomada.destino, origem);
    });

    test('retomada sem origem e recusada em vez de adivinhada', () {
      expect(
        avaliarRetomada(
          de: EdicaoStatus.suspenso, statusAnterior: null,
          ator: AtorTransicao.administracao,
        ).recusa,
        RecusaTransicao.retomadaSemOrigem,
      );
    });

    test('so a administracao suspende', () {
      for (final ator in [AtorTransicao.sistema, AtorTransicao.jogador]) {
        expect(
          avaliarSuspensao(de: EdicaoStatus.emAndamento, ator: ator).recusa,
          RecusaTransicao.atorNaoAutorizado,
        );
      }
    });

    test('a edicao exige statusAnterior quando suspensa', () {
      expect(
        () => EdicaoTorneio(
          tournamentId: 't', editionId: 'e', numeroEdicao: 1, temporada: '2026',
          status: EdicaoStatus.suspenso,
          inicioPrevisto: _agora, regraVersao: 1, criadoEm: _agora, atualizadoEm: _agora,
        ),
        throwsArgumentError,
      );
    });
  });

  group('extra: cancelamento de inscricao', () {
    test('cancela dentro da janela e devolve fichas quando o torneio devolve', () {
      final inscricao = Inscricao(
        tournamentId: 'copa_buraco_master', editionId: 'ed-2026-08', userId: 'ana',
        status: StatusInscricao.inscrito, inscritoEm: _agora, atualizadoEm: _agora,
        fichasDebitadas: 250,
      );
      final r = cancelarInscricao(
        edicao: _edicao(), userId: 'ana', agora: _agora,
        inscricoes: [inscricao], devolveFichas: true,
      );
      expect(r.aceito, isTrue);
      expect(r.fichasDevolvidas, 250);
      expect(r.inscricao!.status, StatusInscricao.cancelado);
    });

    test('nao devolve quando o torneio nao devolve', () {
      final inscricao = Inscricao(
        tournamentId: 'copa_buraco_master', editionId: 'ed-2026-08', userId: 'ana',
        status: StatusInscricao.inscrito, inscritoEm: _agora, atualizadoEm: _agora,
        fichasDebitadas: 250,
      );
      final r = cancelarInscricao(
        edicao: _edicao(), userId: 'ana', agora: _agora, inscricoes: [inscricao],
      );
      expect(r.fichasDevolvidas, 0);
    });

    test('cancelar duas vezes e recusado', () {
      final cancelada = _inscricao('ana').comStatus(StatusInscricao.cancelado, em: _agora);
      final r = cancelarInscricao(
        edicao: _edicao(), userId: 'ana', agora: _agora, inscricoes: [cancelada],
      );
      expect(r.recusa, RecusaCancelamento.jaCancelada);
    });

    test('cancelar com a edicao em quadra e recusado', () {
      final r = cancelarInscricao(
        edicao: _edicao(status: EdicaoStatus.emAndamento), userId: 'ana',
        agora: _agora, inscricoes: [_inscricao('ana')],
      );
      expect(r.recusa, RecusaCancelamento.foraDaJanela);
    });

    test('cancelar sem inscricao e recusado', () {
      final r = cancelarInscricao(
        edicao: _edicao(), userId: 'ninguem', agora: _agora, inscricoes: [_inscricao('ana')],
      );
      expect(r.recusa, RecusaCancelamento.inscricaoInexistente);
    });
  });

  group('extra: hidratacao e invariantes', () {
    test('round-trip da inscricao', () {
      final i = _inscricao('ana');
      final volta = Inscricao.fromMap(i.toJson());
      expect(volta.chaveIdempotencia, i.chaveIdempotencia);
      expect(volta.status, i.status);
    });

    test('inscricao com chave adulterada e recusada', () {
      final json = _inscricao('ana').toJson();
      json['chaveIdempotencia'] = 'x|y|z';
      expect(() => Inscricao.fromMap(json), throwsFormatException);
    });

    test('round-trip da edicao', () {
      final e = _edicao();
      final volta = EdicaoTorneio.fromMap(e.toJson());
      expect(volta.chave, e.chave);
      expect(volta.regraVersao, e.regraVersao);
      expect(volta.inscricoesAbremEm, e.inscricoesAbremEm);
    });

    test('edicao com data sem sufixo Z e recusada', () {
      final json = _edicao().toJson();
      json['inicioPrevisto'] = '2026-08-08T00:00:00';
      expect(() => EdicaoTorneio.fromMap(json), throwsFormatException);
    });

    test('a janela de inscricao e fechada no inicio e aberta no fim', () {
      final e = _edicao();
      expect(e.janelaInscricaoAbertaEm(e.inscricoesAbremEm!), isTrue);
      expect(e.janelaInscricaoAbertaEm(e.inscricoesFechamEm!), isFalse);
      expect(
        e.janelaInscricaoAbertaEm(
          e.inscricoesAbremEm!.subtract(const Duration(seconds: 1)),
        ),
        isFalse,
      );
    });

    test('a janela de inscricao e explicita, nunca derivada do check-in', () {
      final semJanela = EdicaoTorneio(
        tournamentId: 't', editionId: 'e', numeroEdicao: 1, temporada: '2026',
        status: EdicaoStatus.agendado, inicioPrevisto: _agora.add(const Duration(days: 10)),
        regraVersao: 1, criadoEm: _agora, atualizadoEm: _agora,
      );
      // O seed aprovado traz janela de CHECK-IN, nao de inscricao. Derivar uma
      // da outra inventaria regra de calendario que ninguem decidiu, entao a
      // edicao nasce sem janela e a administracao a define ao agendar.
      expect(semJanela.inscricoesAbremEm, isNull);
      expect(semJanela.janelaInscricaoAbertaEm(_agora), isFalse);

      final comJanela = semJanela.comJanela(
        abreEm: _agora,
        fechaEm: _agora.add(const Duration(days: 9)),
        em: _agora,
      );
      expect(comJanela.inscricoesAbremEm, _agora);
      expect(comJanela.janelaInscricaoAbertaEm(_agora), isTrue);
    });

    test('a modalidade da edicao vem da politica, sem inventar valor', () {
      final base = EdicaoTorneio(
        tournamentId: 't', editionId: 'e', numeroEdicao: 1, temporada: '2026',
        status: EdicaoStatus.agendado, inicioPrevisto: _agora,
        regraVersao: 1, criadoEm: _agora, atualizadoEm: _agora,
      );
      // Politica fixa: resolve.
      expect(
        base.comModalidadeDe(_template(), em: _agora).modalidade,
        ModalidadeMesa.aberto,
      );
      // Politica que exige decisao humana: a edicao segue sem modalidade.
      final mensal = _catalogo()[TorneioIds.campeonatoMensal];
      expect(base.comModalidadeDe(mensal, em: _agora).modalidade, isNull);
    });

    test('participanteId de dupla mal formado e recusado', () {
      expect(() => Participante.deId('b+a'), throwsFormatException);
      expect(() => Participante.deId('a+b+c'), throwsFormatException);
      expect(() => Participante.deId(''), throwsFormatException);
    });

    test('membro com o separador e recusado', () {
      expect(() => Participante.individual('a+b'), throwsArgumentError);
    });
  });

  // ===========================================================================
  // CONTRATOS PARA FLUTTER (OS 02 secao 24)
  // ===========================================================================
  group('contratos para Flutter', () {
    test('a correspondencia de status dominio <-> UI e 1:1', () {
      // Trava contra deriva: acrescentar um estado de um lado sem o outro quebra
      // AQUI, e nao na tela do jogador.
      expect(EdicaoStatus.values.length, ui.TorneioStatus.values.length);
      for (final s in EdicaoStatus.values) {
        expect(statusParaUi(s).name, s.name, reason: s.wire);
      }
    });

    test('a correspondencia de participante dominio <-> UI cobre a UI inteira', () {
      final mapeados = StatusInscricao.values
          .map(participanteParaUi)
          .whereType<ui.StatusParticipante>()
          .toSet();
      expect(mapeados.length, ui.StatusParticipante.values.length);
      // listaEspera e cancelado nao existem na UI aprovada: devolvem null em vez
      // de um valor aproximado.
      expect(participanteParaUi(StatusInscricao.listaEspera), isNull);
      expect(participanteParaUi(StatusInscricao.cancelado), isNull);
    });

    test('a correspondencia de recusa de inscricao cobre a UI inteira', () {
      final mapeados = MotivoRecusaInscricao.values
          .map(recusaParaUi)
          .whereType<ui.MotivoInscricaoRecusada>()
          .toSet();
      expect(mapeados.length, ui.MotivoInscricaoRecusada.values.length);
    });

    test('modalidade e participacao mapeiam para a UI', () {
      expect(modalidadeParaUi(ModalidadeMesa.stbl), ui.ModalidadeTorneio.stbl);
      expect(participacaoParaUi(TipoParticipacao.dupla), ui.TipoParticipacao.dupla);
      expect(ModalidadeMesa.values.length, ui.ModalidadeTorneio.values.length);
    });

    test('a secao da central deriva do estado', () {
      expect(
        secaoParaUi(status: EdicaoStatus.inscricoesAbertas, inscrito: false),
        ui.SecaoCentral.inscricoesAbertas,
      );
      expect(
        secaoParaUi(status: EdicaoStatus.inscricoesAbertas, inscrito: true),
        ui.SecaoCentral.meus,
      );
      expect(
        secaoParaUi(status: EdicaoStatus.emAndamento, inscrito: true),
        ui.SecaoCentral.emAndamento,
      );
      expect(
        secaoParaUi(status: EdicaoStatus.encerrado, inscrito: true),
        ui.SecaoCentral.encerrados,
      );
    });

    test('os botoes vem do dominio, nao do widget', () {
      expect(
        botoesParaUi(status: EdicaoStatus.inscricoesAbertas, minhaInscricao: null),
        contains(ui.BotaoTorneio.inscrever),
      );
      expect(
        botoesParaUi(
          status: EdicaoStatus.inscricoesAbertas,
          minhaInscricao: StatusInscricao.inscrito,
        ),
        contains(ui.BotaoTorneio.cancelarInscricao),
      );
      expect(
        botoesParaUi(status: EdicaoStatus.encerrado, minhaInscricao: null),
        contains(ui.BotaoTorneio.verResultado),
      );
    });

    test('o card monta a partir do dominio', () {
      final card = cardDaEdicao(
        edicao: _edicao(),
        template: _template(acesso: AcessoTorneio.vip),
        inscritos: 5,
        premiacaoPrincipal: '1.000 fichas + Coroa',
        capaUrl: 'assets/torneios/capas/copa_buraco_master.png',
        agora: _agora,
      );
      expect(card.status, ui.TorneioStatus.inscricoesAbertas);
      expect(card.acesso, ui.TipoAcesso.vip);
      expect(card.vagasTotais, 8);
      expect(card.tempoRestanteInscricao, isNotNull);
    });

    test('a linha de classificacao mapeia para a UI', () {
      final linhas = calcularClassificacao(
        resultados: [
          _resultado(matchId: 'm1', faseId: 'f1', mesaId: 'me', vencedor: 'ana', perdedor: 'bia'),
        ],
        criterios: desempatePadrao,
      );
      final vm = linhaParaUi(linhas.first, nome: 'Ana', souEu: true);
      expect(vm.posicao, 1);
      expect(vm.vitorias, 1);
      expect(vm.saldo, 600);
      expect(vm.souEu, isTrue);
    });

    test('o confronto mapeia para a UI', () {
      final mesa = Mesa(
        mesaId: 'f1-mesa-7', tournamentId: 't', editionId: 'e', faseId: 'f1',
        assentos: [Participante.individual('ana'), Participante.individual('bia')],
        status: StatusMesa.emJogo,
      );
      final vm = confrontoParaUi(mesa, rodada: 2, nomes: const ['Ana', 'Bia'], ehMeu: true);
      expect(vm.mesaLabel, 'Mesa 7');
      expect(vm.statusPartida, 'em jogo');
      expect(vm.confrontoId, 'f1-mesa-7');
    });
  });

  // ===========================================================================
  // CONTRATO COM O MOTOR DE PARTIDAS (OS 02 secao 23)
  // ===========================================================================
  group('contrato com o Motor de Partidas', () {
    test('a solicitacao carrega tudo que a mesa precisa e nada alem', () {
      final mesa = Mesa(
        mesaId: 'f1-mesa-1', tournamentId: 'copa_buraco_master',
        editionId: 'ed-2026-08', faseId: 'f1',
        assentos: [Participante.dupla('ana', 'bia'), Participante.dupla('caio', 'duda')],
      );
      final solicitacao = SolicitacaoPartida(
        matchId: matchIdDaMesa(mesa),
        tournamentId: mesa.tournamentId, editionId: mesa.editionId,
        faseId: mesa.faseId, mesaId: mesa.mesaId,
        assentos: mesa.assentos, modalidade: 'FECHADO', metaPontos: 1500,
        solicitadaEm: _agora,
      );
      expect(solicitacao.matchId, 'match-f1-mesa-1');
      expect(solicitacao.assentos.length, 2);
      expect(solicitacao.toJson()['assentos'], ['ana+bia', 'caio+duda']);
    });

    test('o matchId e derivado da mesa: reenviar nao abre duas mesas', () {
      final mesa = Mesa(
        mesaId: 'f1-mesa-1', tournamentId: 't', editionId: 'e', faseId: 'f1',
        assentos: [Participante.individual('a'), Participante.individual('b')],
      );
      expect(matchIdDaMesa(mesa), matchIdDaMesa(mesa));
    });

    test('mesa com participante repetido e recusada', () {
      expect(
        () => SolicitacaoPartida(
          matchId: 'm', tournamentId: 't', editionId: 'e', faseId: 'f', mesaId: 'me',
          assentos: [Participante.individual('ana'), Participante.individual('ana')],
          modalidade: 'ABERTO', metaPontos: 1500, solicitadaEm: _agora,
        ),
        throwsArgumentError,
      );
    });

    test('mesa com menos de dois lados e recusada', () {
      expect(
        () => SolicitacaoPartida(
          matchId: 'm', tournamentId: 't', editionId: 'e', faseId: 'f', mesaId: 'me',
          assentos: [Participante.individual('ana')],
          modalidade: 'ABERTO', metaPontos: 1500, solicitadaEm: _agora,
        ),
        throwsArgumentError,
      );
    });

    test('as interfaces do contrato existem e sao implementaveis', () {
      // Fixa a forma do contrato: o Motor de Partidas implementa [MotorDePartidas]
      // sem importar nada do dominio de torneios alem de match_contract.dart.
      final motor = _MotorFalso();
      final receptor = _ReceptorFalso();
      expect(motor, isA<MotorDePartidas>());
      expect(receptor, isA<ReceptorDeResultado>());
    });
  });
}

/// Implementacao minima so para fixar a forma da interface.
class _MotorFalso implements MotorDePartidas {
  final solicitadas = <SolicitacaoPartida>[];

  @override
  Future<void> solicitarPartida(SolicitacaoPartida solicitacao) async {
    // Idempotente por matchId, como o contrato exige.
    if (solicitadas.any((s) => s.matchId == solicitacao.matchId)) return;
    solicitadas.add(solicitacao);
  }

  @override
  Future<void> cancelarPartida(String matchId) async {
    solicitadas.removeWhere((s) => s.matchId == matchId);
  }
}

class _ReceptorFalso implements ReceptorDeResultado {
  final recebidos = <String>{};

  @override
  Future<void> receberResultado(ResultadoPartida resultado) async {
    recebidos.add(resultado.chaveIdempotencia);
  }
}
