// fundacao_base_p_test.dart — o portao da FUNDACAO da base P de Torneios V1.
//
// Esta suite nao prova o Motor de Torneios: disso cuida motor_torneios_test.dart,
// que continua inteiro. Ela prova as DECISOES DE FUNDACAO da V1, e prova cada
// uma pelos dois lados — o estado correto existe, e o estado errado derruba.
//
//   SEED  o acesso de todo modelo ativo exige VIP integral; publico e misto
//         sairam e nao voltam em silencio.
//   CTR   existe UM contrato normativo de template, e ele falha fechado.
//   PART  a participacao da V1 e individual, e dupla nao influencia nada.
//   CICL  rascunho -> em_revisao -> agendado, com aprovador distinto do criador.
//   ECON  a divergencia de carteira segue BLOQUEADA, sem escolha silenciosa.
//   JOBS  a fila sem consumidor continua sem consumidor, e isso nao e sucesso.
//   HALL  nenhuma candidatura orfa.
//   CLI   nenhum cliente produtivo nasceu.
//
// Dart puro sobre flutter_test: sem widget, sem Firebase, sem rede. Os blocos
// ECON, JOBS, HALL e CLI sao ESTRUTURAIS — varrem a arvore — porque o que eles
// afirmam e a AUSENCIA de uma coisa, e ausencia nao tem comportamento para
// exercitar. Um teste de comportamento que "nao credita" passaria igual num
// codigo que credita por outro caminho.

import 'dart:io';

import 'package:buraco_master_vip/elegibilidade/composicao.dart';
import 'package:buraco_master_vip/torneios/contrato_v1.dart';
import 'package:buraco_master_vip/torneios/eligibility.dart';
import 'package:buraco_master_vip/torneios/registrations.dart';
import 'package:buraco_master_vip/torneios/tournament_catalog.dart';
import 'package:buraco_master_vip/torneios/tournament_lifecycle.dart';
import 'package:buraco_master_vip/torneios/tournament_model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../suporte/seeds.dart';

final _agora = DateTime.utc(2026, 8, 22, 20);

Map<String, dynamic> _seedAtivo() =>
    lerSeed('torneios', 'tournamentTemplates.seed.json');

Map<String, dynamic> _seedLegado() =>
    lerSeedLegado('torneios', 'tournamentTemplates.superseded.json');

List<Map<String, dynamic>> _templatesAtivos() =>
    (_seedAtivo()['templates'] as List).cast<Map<String, dynamic>>();

TorneioCatalogo _catalogo() => TorneioCatalogo.fromMap(_seedAtivo());

/// Um entitlement como o Billing o escreve em `playerEntitlements/{uid}`.
Map<String, Object?> _entitlement({
  required String estado,
  required bool ativo,
  required DateTime expiraEm,
}) =>
    {
      'vipAtivo': ativo,
      'estado': estado,
      'expiraEm': expiraEm.toIso8601String(),
      'origem': 'play',
    };

/// Perfil montado pela composicao REAL, e nao a mao.
///
/// Construir `PerfilElegibilidade` direto no teste provaria o que o teste
/// escreveu. Passando pelo `comporPerfil` de producao, quem decide se ha VIP e
/// o mesmo codigo que decide em producao.
PerfilElegibilidade _perfilDe({
  Map<String, Object?>? entitlement,
  Map<String, Object?>? moderacao,
  Set<String> convites = const {},
}) =>
    comporPerfil(
      userId: 'ana',
      agora: _agora,
      entitlement: entitlement,
      moderacao: moderacao,
      convitesAtivos: convites,
      temporadasAtivas: const {'2026'},
    );

EdicaoTorneio _edicaoAberta(String tournamentId) => EdicaoTorneio(
      tournamentId: tournamentId,
      editionId: 'ed-2026-08',
      numeroEdicao: 3,
      temporada: '2026',
      status: EdicaoStatus.inscricoesAbertas,
      inicioPrevisto: _agora.add(const Duration(hours: 4)),
      inscricoesAbremEm: _agora.subtract(const Duration(days: 7)),
      inscricoesFechamEm: _agora.add(const Duration(hours: 3)),
      modalidade: ModalidadeMesa.aberto,
      numeroFases: 2,
      formato: FormatoTorneio.misto,
      metaPontos: 1500,
      regraVersao: 3,
      criadoEm: _agora.subtract(const Duration(days: 30)),
      atualizadoEm: _agora,
    );

/// Todo o codigo do dominio de torneios, como texto, para as varreduras.
List<File> _fontesDoDominio() => Directory('lib/torneios')
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'))
    .toList(growable: false);

String _barras(String p) => p.replaceAll(r'\', '/');

/// Remove comentarios de linha, para que uma varredura de simbolo nao case com
/// a propria frase que explica por que o simbolo nao esta la.
String _codigoSemComentario(File f) => f
    .readAsLinesSync()
    .where((l) => !l.trimLeft().startsWith('//'))
    .join('\n');

void main() {
  // ===========================================================================
  // SEED — acesso e elegibilidade
  // ===========================================================================
  group('SEED', () {
    test('SEED-01 nenhum template ativo declara acesso publico', () {
      for (final t in _templatesAtivos()) {
        expect(t['acesso'], isNot('publico'), reason: t['templateId'] as String);
      }
    });

    test('SEED-02 nenhum template ativo declara acesso misto', () {
      for (final t in _templatesAtivos()) {
        final a = t['acesso'];
        final wire = a is String ? a : (a is Map ? a['tipo'] : null);
        expect(wire, isNot('misto'), reason: t['templateId'] as String);
      }
    });

    test('SEED-03 todo acesso ativo esta na relacao admitida da V1', () {
      for (final t in _templatesAtivos()) {
        final a = t['acesso'];
        final wire = a is String ? a : (a is Map ? a['tipo'] : null);
        expect(kAcessosAdmitidosV1, contains(wire),
            reason: t['templateId'] as String);
      }
      final evento = _seedAtivo()['eventoEncerramento'] as Map<String, dynamic>;
      expect(kAcessosAdmitidosV1, contains(evento['acesso']));
    });

    test('SEED-04 todo template ativo exige assinatura como criterio', () {
      for (final t in _catalogo().todos) {
        expect(t.criteriosElegibilidade, contains('assinatura'),
            reason: t.tournamentId);
      }
    });

    test('SEED-05 somente_convidados e CUMULATIVO ao VIP, nunca alternativo',
        () {
      // O evento de encerramento e o unico `somente_convidados` da V1. Um
      // convite NAO substitui a assinatura: quem foi convidado e perdeu o VIP
      // continua de fora, e o convite sozinho nao abre a porta.
      final evento = _seedAtivo()['eventoEncerramento'] as Map<String, dynamic>;
      expect(evento['acesso'], 'somente_convidados');

      final soConvite = _perfilDe(convites: const {'encerramento_anual'});
      expect(soConvite.assinaturaAtiva, isFalse);

      final recusa = avaliarCriterio(
        criterio: const CriterioElegibilidade(TipoCriterio.assinatura),
        perfil: soConvite,
        tournamentId: 'encerramento_campeoes_ano',
      );
      expect(recusa, RecusaElegibilidade.semAssinatura);
    });

    test('SEED-06 jogador sem VIP e recusado em todo template ATIVO', () {
      final semVip = _perfilDe();
      // `ativos` exclui o Campeonato Anual, que esta cadastrado e desligado
      // (decisao #6) — ele tem recusa PROPRIA, em SEED-06b.
      final ativos = _catalogo().ativos.toList();
      expect(ativos, isNotEmpty);
      for (final template in ativos) {
        final r = inscrever(
          edicao: _edicaoAberta(template.tournamentId),
          template: template,
          perfil: semVip,
          vagas: ConfiguracaoVagas(limite: template.vagasMax ?? 64),
          agora: _agora,
          saldoFichas: 1000000,
        );
        expect(r.aceita, isFalse, reason: template.tournamentId);
        expect(r.recusa, MotivoRecusaInscricao.requisitoVipNaoAtendido,
            reason: template.tournamentId);
      }
    });

    test('SEED-06b o Campeonato Anual recusa ANTES de avaliar o jogador', () {
      // Ele esta cadastrado, inativo e sem configuracao completa — nao tem
      // vagas nem janela. A recusa correta e `configuracaoPendente`, e nao
      // `requisitoVipNaoAtendido`: dizer "falta VIP" a um jogador que jamais
      // poderia se inscrever seria mentir sobre o motivo.
      //
      // O caso existe para que a diferenca fique AFIRMADA. Sem ele, o dia em
      // que alguem completar a configuracao do Anual sem por o criterio de
      // assinatura passaria despercebido.
      final anual = _catalogo()[TorneioIds.campeonatoAnual];
      expect(anual.ativo, isFalse);
      final r = inscrever(
        edicao: _edicaoAberta(anual.tournamentId),
        template: anual,
        perfil: _perfilDe(),
        vagas: const ConfiguracaoVagas(limite: 64),
        agora: _agora,
        saldoFichas: 1000000,
      );
      expect(r.aceita, isFalse);
      expect(r.recusa, MotivoRecusaInscricao.configuracaoPendente);
      // E o criterio de assinatura ESTA la, esperando a configuracao chegar.
      expect(anual.criteriosElegibilidade, contains('assinatura'));
    });

    test('SEED-07 VIP integral vigente e aceito', () {
      final vip = _perfilDe(
        entitlement: _entitlement(
          estado: 'ativo',
          ativo: true,
          expiraEm: _agora.add(const Duration(days: 30)),
        ),
      );
      expect(vip.assinaturaAtiva, isTrue);
      final template = _catalogo()[TorneioIds.sextaMasterVip];
      final r = inscrever(
        edicao: _edicaoAberta(template.tournamentId),
        template: template,
        perfil: vip,
        vagas: ConfiguracaoVagas(limite: template.vagasMax!),
        agora: _agora,
        saldoFichas: 1000000,
      );
      expect(r.aceita, isTrue);
    });

    test('SEED-08 VIP EXPIRADO nao concede acesso', () {
      final expirado = _perfilDe(
        entitlement: _entitlement(
          estado: 'ativo',
          ativo: true,
          // O documento ainda diz `vipAtivo: true` — o job de expiracao pode
          // atrasar. Quem decide e o relogio da leitura.
          expiraEm: _agora.subtract(const Duration(minutes: 1)),
        ),
      );
      expect(expirado.assinaturaAtiva, isFalse);
    });

    test('SEED-09 passe quinzenal de cortesia nao concede acesso', () {
      // O passe vive em `playerCourtesyPass` / `passesVip`, escrito por
      // functions-mesas. Nao e uma checagem que alguem possa esquecer: e uma
      // colecao que o torneio NAO CONSULTA. As duas metades da prova:
      //
      //   1. um documento com forma de passe, entregue no lugar do entitlement,
      //      nao concede — porque nao tem o que o entitlement precisa ter;
      //   2. o dominio inteiro nao menciona as colecoes do passe.
      final comPasse = _perfilDe(entitlement: {
        'passeAtivo': true,
        'ciclo': '2026-Q3',
        'origem': 'cortesia',
      });
      expect(comPasse.assinaturaAtiva, isFalse);

      for (final f in _fontesDoDominio()) {
        final codigo = _codigoSemComentario(f);
        for (final termo in [
          'playerCourtesyPass',
          'passesVip',
          'passeDeCortesia',
        ]) {
          expect(codigo.contains(termo), isFalse,
              reason: '${_barras(f.path)} menciona $termo');
        }
      }
    });

    test('SEED-10 VIP presenteado nao concede acesso enquanto nao houver '
        'autoridade', () {
      // Nao existe autoridade de assinatura presenteada nesta arvore: nenhuma
      // colecao, nenhum campo, nenhuma Function. A prova possivel — e a
      // honesta — e que a AUSENCIA falha fechada: um estado que o codigo nao
      // conhece cai em `desconhecido`, e `desconhecido` nao concede.
      final presenteado = _perfilDe(
        entitlement: _entitlement(
          estado: 'presenteado',
          ativo: true,
          expiraEm: _agora.add(const Duration(days: 365)),
        ),
      );
      expect(presenteado.assinaturaAtiva, isFalse);

      // E o mesmo vale para qualquer rotulo novo que alguem invente amanha.
      for (final inventado in ['presente', 'cortesia_vip', 'promocional']) {
        final p = _perfilDe(
          entitlement: _entitlement(
            estado: inventado,
            ativo: true,
            expiraEm: _agora.add(const Duration(days: 365)),
          ),
        );
        expect(p.assinaturaAtiva, isFalse, reason: inventado);
      }
    });

    test('SEED-11 os superseded sairam do catalogo ativo', () {
      final ativos = _templatesAtivos().map((t) => t['templateId']).toSet();
      for (final id in TorneioIds.superseded) {
        expect(ativos, isNot(contains(id)), reason: id);
      }
      expect(TorneioIds.todos, isNot(contains(TorneioIds.quartaVulnerabilidade)));
      expect(TorneioIds.todos, isNot(contains(TorneioIds.campeonatoMensal)));
    });

    test('SEED-12 os superseested foram PRESERVADOS no legado, como estavam',
        () {
      final legado = (_seedLegado()['templatesSuperseded'] as List)
          .cast<Map<String, dynamic>>();
      expect(legado.map((t) => t['templateId']),
          containsAll(TorneioIds.superseded));
      // Preservados, e nao convertidos: o acesso original continua la. Se um dia
      // alguem os promover, promovera a decisao junto — nao um dado ja
      // reescrito por conveniencia de esquema.
      final quarta = legado
          .firstWhere((t) => t['templateId'] == TorneioIds.quartaVulnerabilidade);
      expect(quarta['acesso'], 'publico');
      final mensal =
          legado.firstWhere((t) => t['templateId'] == TorneioIds.campeonatoMensal);
      expect((mensal['acesso'] as Map)['tipo'], 'misto');
    });

    test('SEED-13 o legado esta fora do carregamento produtivo', () {
      // O glob que o CI e qualquer carregador usam e `app/data/torneios/*.json`.
      // Um arquivo em `legado/` nao casa — e essa e a garantia, e nao um
      // comentario pedindo cuidado.
      final dir = Directory('data/torneios');
      if (!dir.existsSync()) return; // layout do scaffold: nada a conferir
      final naRaiz = dir
          .listSync()
          .whereType<File>()
          .map((f) => _barras(f.path).split('/').last)
          .toList();
      expect(naRaiz, isNot(contains('tournamentTemplates.superseded.json')));
    });

    test('SEED-14 um superseded de volta ao seed ativo DERRUBA a carga', () {
      final raiz = _seedAtivo();
      final legado = (_seedLegado()['templatesSuperseded'] as List)
          .cast<Map<String, dynamic>>();
      (raiz['templates'] as List).add(legado.first);
      expect(
        () => TorneioCatalogo.fromMap(raiz),
        throwsA(isA<FormatException>().having(
          (e) => e.message,
          'mensagem',
          allOf(contains('SUPERSEDED'), contains('VIP integral')),
        )),
      );
    });
  });

  // ===========================================================================
  // CTR — o contrato normativo de template
  // ===========================================================================
  group('CTR', () {
    Map<String, Object?> valido() => {
          'templateId': 'exemplo',
          'esquema': kEsquemaTemplateV1,
          'versao': 1,
          'acesso': 'vip',
          'participacao': 'individual',
          'vagas': {'max': 64, 'min': 16},
          'recorrencia': {'tipo': 'semanal'},
          'modalidade': {'tipo': 'fixa'},
          'criadoPor': 'admin-a',
          'aprovadoPor': 'admin-b',
          'publicado': false,
          'premiacao': [
            {'colocacao': 1, 'fichas': 500}
          ],
        };

    test('CTR-01 o exemplar valido nao produz violacao nenhuma', () {
      expect(validarTemplateV1(valido()), isEmpty);
    });

    test('CTR-02 o seed ATIVO satisfaz o contrato, com UMA lacuna declarada',
        () {
      // A lacuna e `criadoPor`: nao ha produtor seguro do claim `admin` nesta
      // arvore, entao nao existe identidade administrativa para registrar. Ela
      // aparece AQUI, por valor, em vez de ficar implicita — e o dia em que o
      // produtor existir e o dia em que este teste muda de propósito.
      // `campeonato_anual` tem DUAS: alem do criador, ele nao declara vagas —
      // esta cadastrado e desligado (decisao #6), e a configuracao que falta e
      // a mesma que faz o dominio recusar inscricao por `configuracaoPendente`.
      // As duas lacunas sao a MESMA lacuna, vista de dois lugares.
      const lacunasDeclaradas = <String, List<ViolacaoContratoV1>>{
        'sexta_master_vip': [ViolacaoContratoV1.criadorAusente],
        'copa_buraco_master': [ViolacaoContratoV1.criadorAusente],
        'domingo_pintando_7': [ViolacaoContratoV1.criadorAusente],
        'campeonato_anual': [
          ViolacaoContratoV1.capacidadeInvalida,
          ViolacaoContratoV1.criadorAusente,
        ],
      };
      final ativos = _templatesAtivos();
      expect(ativos.map((t) => t['templateId']).toSet(),
          lacunasDeclaradas.keys.toSet());
      for (final t in ativos) {
        final id = t['templateId'] as String;
        expect(validarTemplateV1(t), lacunasDeclaradas[id], reason: id);
      }
    });

    test('CTR-03 acesso publico e misto sao recusados por valor', () {
      final pub = valido()..['acesso'] = 'publico';
      expect(validarTemplateV1(pub), contains(ViolacaoContratoV1.acessoNaoVip));
      final misto = valido()..['acesso'] = {'tipo': 'misto'};
      expect(validarTemplateV1(misto), contains(ViolacaoContratoV1.acessoNaoVip));
    });

    test('CTR-04 os dois templates do legado sao recusados pelo contrato', () {
      final legado = (_seedLegado()['templatesSuperseded'] as List)
          .cast<Map<String, dynamic>>();
      for (final t in legado) {
        expect(validarTemplateV1(t), contains(ViolacaoContratoV1.acessoNaoVip),
            reason: t['templateId'] as String);
      }
    });

    test('CTR-05 participacao diferente de individual e recusada', () {
      final d = valido()..['participacao'] = 'dupla';
      expect(validarTemplateV1(d),
          contains(ViolacaoContratoV1.participacaoNaoIndividual));
    });

    test('CTR-06 qualquer campo de dupla e recusado pela PRESENCA', () {
      for (final campo in kCamposDeDuplaProibidosV1) {
        final t = valido()..[campo] = 'seja o que for';
        expect(validarTemplateV1(t),
            contains(ViolacaoContratoV1.campoDeDuplaPresente),
            reason: campo);
      }
    });

    test('CTR-07 capacidade ausente, negativa ou invertida e recusada', () {
      expect(validarTemplateV1(valido()..remove('vagas')),
          contains(ViolacaoContratoV1.capacidadeInvalida));
      expect(validarTemplateV1(valido()..['vagas'] = {'max': 4, 'min': 8}),
          contains(ViolacaoContratoV1.capacidadeInvalida));
      expect(validarTemplateV1(valido()..['vagas'] = {'max': 8, 'min': 0}),
          contains(ViolacaoContratoV1.capacidadeInvalida));
    });

    test('CTR-08 modelo sem agenda e recusado; dataFixa serve', () {
      final semAgenda = valido()..remove('recorrencia');
      expect(validarTemplateV1(semAgenda),
          contains(ViolacaoContratoV1.agendaAusente));
      final comData = semAgenda..['dataFixa'] = '2026-12-18T20:30:00-03:00';
      expect(validarTemplateV1(comData),
          isNot(contains(ViolacaoContratoV1.agendaAusente)));
    });

    test('CTR-09 esquema ausente ou antigo exige migracao explicita', () {
      expect(precisaMigracao(valido()..remove('esquema')), isTrue);
      expect(precisaMigracao(valido()..['esquema'] = 0), isTrue);
      expect(precisaMigracao(valido()..['esquema'] = '1'), isTrue);
      expect(precisaMigracao(valido()), isFalse);
      expect(validarTemplateV1(valido()..remove('esquema')),
          contains(ViolacaoContratoV1.esquemaIncompativel));
    });

    test('CTR-10 criador e aprovador: ausencia, igualdade e publicacao', () {
      expect(validarTemplateV1(valido()..remove('criadoPor')),
          contains(ViolacaoContratoV1.criadorAusente));
      expect(validarTemplateV1(valido()..['aprovadoPor'] = 'admin-a'),
          contains(ViolacaoContratoV1.aprovadorIgualAoCriador));
      final publicadoSemAprovador = valido()
        ..remove('aprovadoPor')
        ..['publicado'] = true;
      expect(validarTemplateV1(publicadoSemAprovador),
          contains(ViolacaoContratoV1.publicadoSemAprovacao));
    });

    test('CTR-11 premiacao com destino de carteira e recusada', () {
      for (final campo in kCamposDeCarteiraProibidosV1) {
        final t = valido()
          ..['premiacao'] = [
            {'colocacao': 1, 'fichas': 500, campo: 'wallets'}
          ];
        expect(validarTemplateV1(t),
            contains(ViolacaoContratoV1.premiacaoComMovimentacao),
            reason: campo);
      }
      // Premiacao por PAPEL (o evento de encerramento) tambem e varrida.
      final porPapel = valido()
        ..['premiacao'] = {
          'campeao': {'fichas': 1000, 'carteira': 'usuarios'}
        };
      expect(validarTemplateV1(porPapel),
          contains(ViolacaoContratoV1.premiacaoComMovimentacao));
    });

    test('CTR-12 o contrato e TOTAL: nao para na primeira violacao', () {
      final ruim = <String, Object?>{'premiacao': <Object?>[]};
      final v = validarTemplateV1(ruim);
      expect(v, containsAll([
        ViolacaoContratoV1.identidadeAusente,
        ViolacaoContratoV1.versaoInvalida,
        ViolacaoContratoV1.esquemaIncompativel,
        ViolacaoContratoV1.acessoNaoVip,
        ViolacaoContratoV1.participacaoNaoIndividual,
        ViolacaoContratoV1.capacidadeInvalida,
        ViolacaoContratoV1.agendaAusente,
        ViolacaoContratoV1.modalidadeAusente,
        ViolacaoContratoV1.criadorAusente,
      ]));
      expect(v.length, greaterThanOrEqualTo(9));
    });

    test('CTR-13 mapa vazio falha fechado, e nao passa por omissao', () {
      expect(validarTemplateV1(const {}), isNotEmpty);
    });
  });

  // ===========================================================================
  // PART — participacao individual
  // ===========================================================================
  group('PART', () {
    test('PART-01 todo template ativo e individual', () {
      for (final t in _templatesAtivos()) {
        expect(t['participacao'], kParticipacaoV1,
            reason: t['templateId'] as String);
      }
      for (final t in _catalogo().todos) {
        expect(t.participacao, TipoParticipacao.individual,
            reason: t.tournamentId);
      }
    });

    test('PART-02 uma inscricao corresponde a UM jogador', () {
      final template = _catalogo()[TorneioIds.copaBuracoMaster];
      final vip = _perfilDe(
        entitlement: _entitlement(
          estado: 'ativo',
          ativo: true,
          expiraEm: _agora.add(const Duration(days: 30)),
        ),
      );
      final r = inscrever(
        edicao: _edicaoAberta(template.tournamentId),
        template: template,
        perfil: vip,
        vagas: ConfiguracaoVagas(limite: template.vagasMax!),
        agora: _agora,
        saldoFichas: 1000000,
      );
      expect(r.aceita, isTrue);
      expect(r.inscricao!.parceiroId, isNull);
      expect(r.inscricao!.status, StatusInscricao.inscrito);
    });

    test('PART-03 parceiro informado num torneio individual e recusado', () {
      final template = _catalogo()[TorneioIds.copaBuracoMaster];
      final vip = _perfilDe(
        entitlement: _entitlement(
          estado: 'ativo',
          ativo: true,
          expiraEm: _agora.add(const Duration(days: 30)),
        ),
      );
      final r = inscrever(
        edicao: _edicaoAberta(template.tournamentId),
        template: template,
        perfil: vip,
        vagas: ConfiguracaoVagas(limite: template.vagasMax!),
        agora: _agora,
        saldoFichas: 1000000,
        parceiroId: 'bruno',
      );
      expect(r.aceita, isFalse);
    });

    test('PART-04 dupla nao altera capacidade: a vaga conta JOGADOR', () {
      // O contrato le `vagas.max` como numero de jogadores. Nao ha, em lugar
      // nenhum da V1, uma multiplicacao por dois escondida — e e isso que esta
      // asserido: o mesmo `max` do seed atravessa ate o limite de inscricao.
      for (final t in _catalogo().todos) {
        if (t.vagasMax == null) continue;
        final bruto = _templatesAtivos()
            .firstWhere((m) => m['templateId'] == t.tournamentId);
        expect(t.vagasMax, (bruto['vagas'] as Map)['max'],
            reason: t.tournamentId);
      }
    });

    test('PART-05 nenhum template ativo carrega campo de dupla', () {
      for (final t in _templatesAtivos()) {
        for (final campo in kCamposDeDuplaProibidosV1) {
          expect(t.containsKey(campo), isFalse,
              reason: '${t['templateId']} tem $campo');
        }
      }
    });
  });

  // ===========================================================================
  // CICL — o ciclo editorial
  // ===========================================================================
  group('CICL', () {
    test('CICL-01 o grafo real satisfaz o ciclo da V1', () {
      expect(quebrasDoCicloEditorialV1(), isEmpty);
    });

    test('CICL-02 rascunho -> em_revisao e permitido a administracao', () {
      final r = avaliarTransicao(
        de: EdicaoStatus.rascunho,
        para: EdicaoStatus.emRevisao,
        ator: AtorTransicao.administracao,
      );
      expect(r.permitida, isTrue);
      expect(r.destino, EdicaoStatus.emRevisao);
    });

    test('CICL-03 rascunho -> agendado e RECUSADO', () {
      final r = avaliarTransicao(
        de: EdicaoStatus.rascunho,
        para: EdicaoStatus.agendado,
        ator: AtorTransicao.administracao,
        criadaPor: 'admin-a',
        operadorId: 'admin-b',
      );
      expect(r.permitida, isFalse);
      expect(r.recusa, RecusaTransicao.transicaoInexistente);
    });

    test('CICL-04 em_revisao -> agendado passa com aprovador DISTINTO', () {
      final r = avaliarTransicao(
        de: EdicaoStatus.emRevisao,
        para: EdicaoStatus.agendado,
        ator: AtorTransicao.administracao,
        criadaPor: 'admin-a',
        operadorId: 'admin-b',
      );
      expect(r.permitida, isTrue);
      expect(r.destino, EdicaoStatus.agendado);
    });

    test('CICL-05 criador aprovando a propria edicao e RECUSADO', () {
      final r = avaliarTransicao(
        de: EdicaoStatus.emRevisao,
        para: EdicaoStatus.agendado,
        ator: AtorTransicao.administracao,
        criadaPor: 'admin-a',
        operadorId: 'admin-a',
      );
      expect(r.permitida, isFalse);
      expect(r.recusa, RecusaTransicao.aprovadorIgualAoCriador);
    });

    test('CICL-06 aprovador ausente e RECUSADO', () {
      for (final operador in [null, '']) {
        final r = avaliarTransicao(
          de: EdicaoStatus.emRevisao,
          para: EdicaoStatus.agendado,
          ator: AtorTransicao.administracao,
          criadaPor: 'admin-a',
          operadorId: operador,
        );
        expect(r.recusa, RecusaTransicao.aprovadorAusente,
            reason: 'operador=$operador');
      }
    });

    test('CICL-07 criador ausente e RECUSADO', () {
      for (final criador in [null, '']) {
        final r = avaliarTransicao(
          de: EdicaoStatus.emRevisao,
          para: EdicaoStatus.agendado,
          ator: AtorTransicao.administracao,
          criadaPor: criador,
          operadorId: 'admin-b',
        );
        expect(r.recusa, RecusaTransicao.criadorAusente,
            reason: 'criador=$criador');
      }
    });

    test('CICL-08 o cliente nao aprova, nem com os dois nomes certos', () {
      final r = avaliarTransicao(
        de: EdicaoStatus.emRevisao,
        para: EdicaoStatus.agendado,
        ator: AtorTransicao.jogador,
        criadaPor: 'admin-a',
        operadorId: 'admin-b',
      );
      expect(r.permitida, isFalse);
      expect(r.recusa, RecusaTransicao.atorNaoAutorizado);
    });

    test('CICL-09 a automacao nao submete a revisao nem aprova', () {
      final submete = avaliarTransicao(
        de: EdicaoStatus.rascunho,
        para: EdicaoStatus.emRevisao,
        ator: AtorTransicao.sistema,
      );
      expect(submete.recusa, RecusaTransicao.atorNaoAutorizado);

      final aprova = avaliarTransicao(
        de: EdicaoStatus.emRevisao,
        para: EdicaoStatus.agendado,
        ator: AtorTransicao.sistema,
        criadaPor: 'admin-a',
        operadorId: 'admin-b',
      );
      expect(aprova.recusa, RecusaTransicao.atorNaoAutorizado);
    });

    test('CICL-10 rejeitar devolve ao rascunho, e nao cancela', () {
      final r = avaliarTransicao(
        de: EdicaoStatus.emRevisao,
        para: EdicaoStatus.rascunho,
        ator: AtorTransicao.administracao,
      );
      expect(r.permitida, isTrue);
      expect(r.destino, EdicaoStatus.rascunho);
    });

    test('CICL-11 transicao regressiva indevida e recusada', () {
      for (final par in [
        [EdicaoStatus.agendado, EdicaoStatus.rascunho],
        [EdicaoStatus.agendado, EdicaoStatus.emRevisao],
        [EdicaoStatus.emAndamento, EdicaoStatus.inscricoesAbertas],
        [EdicaoStatus.encerrado, EdicaoStatus.emRevisao],
      ]) {
        final r = avaliarTransicao(
          de: par[0],
          para: par[1],
          ator: AtorTransicao.administracao,
          criadaPor: 'admin-a',
          operadorId: 'admin-b',
        );
        expect(r.permitida, isFalse, reason: '${par[0].wire} -> ${par[1].wire}');
      }
    });

    test('CICL-12 estado desconhecido nao vira estado', () {
      expect(EdicaoStatus.porWire('em_revisao'), EdicaoStatus.emRevisao);
      expect(EdicaoStatus.porWire('aprovado'), isNull);
      expect(EdicaoStatus.porWire(''), isNull);
    });

    test('CICL-13 em_revisao nao e publico e nao aceita inscricao', () {
      expect(EdicaoStatus.emRevisao.publico, isFalse);
      expect(EdicaoStatus.emRevisao.aceitaInscricao, isFalse);
      expect(EdicaoStatus.emRevisao.terminal, isFalse);
    });
  });

  // ===========================================================================
  // ECON — a divergencia de carteira segue bloqueada
  // ===========================================================================
  group('ECON', () {
    test('ECON-01 a fundacao nao escolheu carteira nenhuma', () {
      // Os dois nomes aparecem no repositorio — em `functions/src/index.ts` e em
      // `functions-billing`. O que esta afirmado aqui e mais estreito e e o que
      // esta OS podia quebrar: o DOMINIO Dart de torneios continua sem citar
      // qualquer uma das duas.
      const termos = [
        'wallets',
        'usuarios/',
        'FieldValue.increment',
      ];
      for (final f in _fontesDoDominio()) {
        // `contrato_v1.dart` e a SENTINELA: ele nomeia os campos proibidos para
        // poder recusa-los. Varre-lo pelo nome faria a guarda acusar a si mesma
        // — e o reparo obvio (tirar a varredura) tiraria junto a guarda de todo
        // o resto. Ele e conferido logo abaixo, por um criterio mais estreito.
        if (_barras(f.path).endsWith('lib/torneios/contrato_v1.dart')) continue;
        final codigo = _codigoSemComentario(f);
        for (final termo in termos) {
          expect(codigo.contains(termo), isFalse,
              reason: '${_barras(f.path)} cita $termo');
        }
      }

      // Na sentinela, os nomes so podem aparecer DENTRO da relacao de proibidos.
      final sentinela = File('lib/torneios/contrato_v1.dart');
      final linhas = sentinela
          .readAsLinesSync()
          .where((l) => !l.trimLeft().startsWith('//'))
          .where((l) => termos.any(l.contains))
          .map((l) => l.trim())
          .toList();
      expect(linhas, ["'wallets',"],
          reason: 'a sentinela passou a USAR o nome, e nao apenas a proibi-lo');
    });

    test('ECON-02 o contrato recusa premiacao que aponte destino', () {
      expect(
        premiacaoMovimentaCarteira([
          {'colocacao': 1, 'creditarEm': 'wallets'}
        ]),
        isTrue,
      );
      expect(
        premiacaoMovimentaCarteira([
          {'colocacao': 1, 'fichas': 500}
        ]),
        isFalse,
      );
    });

    test('ECON-03 o seed ativo declara premiacao SEM destino', () {
      for (final t in _templatesAtivos()) {
        expect(premiacaoMovimentaCarteira(t['premiacao']), isFalse,
            reason: t['templateId'] as String);
      }
      final evento = _seedAtivo()['eventoEncerramento'] as Map<String, dynamic>;
      expect(premiacaoMovimentaCarteira(evento['premiacao']), isFalse);
    });
  });

  // ===========================================================================
  // JOBS e HALL — ausencia nao e sucesso
  // ===========================================================================
  group('JOBS', () {
    test('JOBS-01 o dominio nao consome nem marca a fila de tarefas', () {
      for (final f in _fontesDoDominio()) {
        final codigo = _codigoSemComentario(f);
        for (final termo in [
          'tournamentJobs',
          'jobConsumido',
          'marcarJobExecutado',
        ]) {
          expect(codigo.contains(termo), isFalse,
              reason: '${_barras(f.path)} cita $termo');
        }
      }
    });

    test('JOBS-02 esta fundacao nao criou consumidor de jobs', () {
      // O consumidor e OS propria. Se um arquivo com este nome aparecer, ele
      // nasceu fora do recorte — e o portao tem de dizer isso em vez de deixar
      // passar por ser "so um arquivo novo".
      for (final nome in [
        'lib/torneios/jobs.dart',
        'lib/torneios/consumidor_jobs.dart',
      ]) {
        expect(File(nome).existsSync(), isFalse, reason: nome);
      }
    });
  });

  group('HALL', () {
    test('HALL-01 o dominio nao produz candidatura ao Hall', () {
      for (final f in _fontesDoDominio()) {
        final codigo = _codigoSemComentario(f);
        for (final termo in [
          'hallEntries',
          'candidaturaHall',
          'indicarAoHall',
        ]) {
          expect(codigo.contains(termo), isFalse,
              reason: '${_barras(f.path)} cita $termo');
        }
      }
    });

    test('HALL-02 o seed cita o Hall como PREMIO, e nunca como evento', () {
      // `hall_dos_imortais` aparece na lista de `extras` de premiacao do seed
      // legado. Isso e referencia contratual — o que a premiacao devera dar —,
      // e nao um produtor. A distincao esta afirmada: nenhum campo do seed ativo
      // instrui alguem a CRIAR candidatura.
      final texto = arquivoDeSeed('torneios', 'tournamentTemplates.seed.json')
          .readAsStringSync();
      for (final termo in ['candidatura', 'indicar', 'hallEntries']) {
        expect(texto.contains(termo), isFalse, reason: termo);
      }
    });
  });

  // ===========================================================================
  // CLI — nenhum cliente produtivo
  // ===========================================================================
  group('CLI', () {
    test('CLI-01 nenhum arquivo de Torneios esta no fecho de main()', () {
      final alcancaveis = _fechoDeMain();
      final infratores = alcancaveis
          .where((c) =>
              c.contains('/torneios/') ||
              c.endsWith('torneios_screens.dart') ||
              c.endsWith('torneios_models.dart') ||
              c.endsWith('torneio_modelo_screen.dart') ||
              c.endsWith('torneios_preview_page.dart'))
          .toList();
      expect(infratores, isEmpty);
    });

    test('CLI-02 a bancada de previa continua sem importador', () {
      final alvo = 'pages/torneios_preview_page.dart';
      final importadores = <String>[];
      for (final f in Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))) {
        if (_barras(f.path).endsWith(alvo)) continue;
        if (_codigoSemComentario(f).contains('torneios_preview_page.dart')) {
          importadores.add(_barras(f.path));
        }
      }
      expect(importadores, isEmpty);
    });

    test('CLI-03 nenhuma tela de torneio ganhou porta de inscricao', () {
      for (final nome in [
        'lib/screens/torneios_screens.dart',
        'lib/screens/torneio_modelo_screen.dart',
        'lib/pages/torneios_preview_page.dart',
      ]) {
        final f = File(nome);
        if (!f.existsSync()) continue;
        final codigo = _codigoSemComentario(f);
        for (final termo in [
          'inscreverEmTorneio',
          'cancelarInscricaoTorneio',
          'FirebaseFirestore',
          'httpsCallable',
        ]) {
          expect(codigo.contains(termo), isFalse, reason: '$nome cita $termo');
        }
      }
    });
  });
}

/// Fecho de `lib/main.dart`, por importacao, com caminhos normalizados.
Set<String> _fechoDeMain() {
  final importe = RegExp(r'''import\s+'([^']+)';''');
  final vistos = <String>{};
  final fila = <String>['lib/main.dart'];

  String resolver(String origem, String alvo) {
    if (alvo.startsWith('package:buraco_master_vip/')) {
      return 'lib/${alvo.substring('package:buraco_master_vip/'.length)}';
    }
    final partes = _barras(origem).split('/')..removeLast();
    for (final passo in alvo.split('/')) {
      if (passo == '..') {
        partes.removeLast();
      } else if (passo != '.') {
        partes.add(passo);
      }
    }
    return partes.join('/');
  }

  while (fila.isNotEmpty) {
    final atual = fila.removeLast();
    if (!vistos.add(atual)) continue;
    final f = File(atual);
    if (!f.existsSync()) continue;
    for (final m in importe.allMatches(_codigoSemComentario(f))) {
      final alvo = m.group(1)!;
      if (alvo.startsWith('dart:')) continue;
      if (alvo.startsWith('package:') &&
          !alvo.startsWith('package:buraco_master_vip/')) {
        continue;
      }
      fila.add(resolver(atual, alvo));
    }
  }
  return vistos;
}
