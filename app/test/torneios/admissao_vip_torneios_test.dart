// admissao_vip_torneios_test.dart — o PORTAO DA ADMISSAO em Torneios V1.
//
// A fundacao (fundacao_base_p_test.dart) prova que os MODELOS da V1 exigem VIP.
// Esta suite prova a outra metade, que a fundacao nao tinha como provar: DE ONDE
// vem o "sim" que a admissao consome, e o que acontece com todo "sim" que nao
// veio de la.
//
// O DEFEITO QUE ELA FECHA
//
// `PerfilElegibilidade.assinaturaAtiva` e a unica resposta que a porta de
// admissao consulta, e ela nascia de `EntitlementVip.vigenteEm` — tres
// condicoes, todas temporais ou de estado: `vipAtivo`, `estado.concedeAcesso` e
// `agora < expiraEm`. Nenhuma delas pergunta QUEM ESCREVEU o documento.
//
// A consequencia era concreta e nao hipotetica: `playerEntitlements/{uid}` tem
// campo `origem`, e `entitlement.dart` documenta `administrativa` como uma
// origem possivel SEM PRODUTOR — e e exatamente sob ela que uma assinatura
// PRESENTEADA seria escrita. Um documento assim, com `estado: 'ativo'` e prazo
// no futuro, entrava em torneio pago e ranqueado como assinante.
//
// A prova da base era falso-fechada por acidente de eixo: ela demonstrava a
// recusa do presente com um ESTADO inventado (`estado: 'presenteado'`), que cai
// em `desconhecido`. Um presente escrito com estado LEGITIMO passava. Ver
// ORIG-05.
//
// O QUE ESTA SUITE AFIRMA
//
//   ADM   a admissao ponta a ponta: quem entra, quem nao entra, e por que.
//   ORIG  a matriz de origens de beneficio, uma linha por origem.
//   CLI   o cliente nao consegue fabricar elegibilidade por nenhum caminho.
//   CONV  o convite continua obrigatorio, e cumulativo ao VIP.
//   AUT   falha, ausencia e resposta malformada da autoridade recusam.
//   RULES a porta de escrita direta continua fechada.
//   GRD   as guardas vencedoras da fundacao sobreviveram a esta correcao.
//
// Dart puro sobre flutter_test: sem widget, sem Firebase, sem rede. Os blocos
// CLI, RULES e GRD sao ESTRUTURAIS — varrem arquivo — porque afirmam a AUSENCIA
// de um caminho, e ausencia nao tem comportamento para exercitar.

import 'dart:io';

import 'package:buraco_master_vip/elegibilidade/composicao.dart';
import 'package:buraco_master_vip/elegibilidade/entitlement.dart';
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

TorneioCatalogo _catalogo() => TorneioCatalogo.fromMap(_seedAtivo());

/// Um template `somente_convidados`, montado a partir de um modelo REAL do seed
/// com o acesso trocado.
///
/// Ele nao sai do catalogo porque nenhum template ativo declara esse acesso
/// hoje — o unico `somente_convidados` da V1 e o Encerramento, e ele nao e um
/// `TorneioTemplate` (ver CONV-08). Montar o modelo aqui e o que permite provar
/// a derivacao de criterios que governa esse acesso ANTES de o primeiro modelo
/// real existir; sem isso, o defeito so apareceria no dia da estreia.
TorneioTemplate _templateDeConvidados() {
  final base = Map<String, dynamic>.from(
      (_seedAtivo()['templates'] as List).first as Map<String, dynamic>);
  base['acesso'] = 'somente_convidados';
  return TorneioTemplate.fromJson(base);
}

/// Um documento `playerEntitlements/{uid}` COMO O BILLING O ESCREVE.
///
/// Os defaults sao o caso feliz de proposito: cada teste altera UM eixo, e a
/// recusa que ele observa e atribuivel a esse eixo, e nao a um campo esquecido.
Map<String, Object?> _doc({
  String estado = 'ativo',
  bool vipAtivo = true,
  String origem = 'play',
  Duration validade = const Duration(days: 30),
  bool comPrazo = true,
}) =>
    {
      'vipAtivo': vipAtivo,
      'estado': estado,
      'origem': origem,
      if (comPrazo) 'expiraEm': _agora.add(validade).toIso8601String(),
      'produtoId': 'vip_mensal',
      'esquema': kEsquemaEntitlement,
    };

/// O perfil montado pela COMPOSICAO DE PRODUCAO.
///
/// Construir `PerfilElegibilidade` a mao provaria o que o teste escreveu. Todo
/// caso desta suite que fala de VIP passa por aqui.
PerfilElegibilidade _perfil({
  Map<String, Object?>? entitlement,
  Map<String, Object?>? moderacao,
  Set<String> convites = const {},
  String userId = 'ana',
}) =>
    comporPerfil(
      userId: userId,
      agora: _agora,
      entitlement: entitlement,
      moderacao: moderacao,
      convitesAtivos: convites,
      temporadasAtivas: const {'2026'},
    );

EdicaoTorneio _edicao(
  String tournamentId, {
  EdicaoStatus status = EdicaoStatus.inscricoesAbertas,
  String editionId = 'ed-2026-08',
}) =>
    EdicaoTorneio(
      tournamentId: tournamentId,
      editionId: editionId,
      numeroEdicao: 3,
      temporada: '2026',
      status: status,
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

/// A admissao completa, contra o template VIP regular da V1.
ResultadoInscricao _admitir(
  PerfilElegibilidade perfil, {
  EdicaoStatus status = EdicaoStatus.inscricoesAbertas,
  Iterable<Inscricao> inscricoes = const <Inscricao>[],
  String? templateId,
}) {
  final template = _catalogo()[templateId ?? TorneioIds.sextaMasterVip];
  return inscrever(
    edicao: _edicao(template.tournamentId, status: status),
    template: template,
    perfil: perfil,
    vagas: ConfiguracaoVagas(limite: template.vagasMax ?? 64),
    agora: _agora,
    saldoFichas: 1000000,
    inscricoes: inscricoes,
  );
}

Inscricao _inscricaoDe(String userId, String tournamentId) => Inscricao(
      tournamentId: tournamentId,
      editionId: 'ed-2026-08',
      userId: userId,
      status: StatusInscricao.inscrito,
      inscritoEm: _agora.subtract(const Duration(minutes: 5)),
      atualizadoEm: _agora.subtract(const Duration(minutes: 5)),
    );

String _texto(String caminho) => File(caminho).readAsStringSync();

/// Codigo sem comentario de linha, para que uma varredura de simbolo nao case
/// com a propria frase que explica por que o simbolo nao esta la.
String _semComentario(String fonte) => fonte
    .split('\n')
    .where((l) {
      final t = l.trimLeft();
      return !t.startsWith('//') && !t.startsWith('*');
    })
    .join('\n');

void main() {
  // ===========================================================================
  // ADM — a admissao ponta a ponta
  // ===========================================================================
  group('ADM', () {
    test('ADM-01 VIP integral vigente e ADMITIDO', () {
      final p = _perfil(entitlement: _doc());
      expect(p.assinaturaAtiva, isTrue);
      expect(_admitir(p).aceita, isTrue);
    });

    test('ADM-02 um SEGUNDO jogador VIP integral entra por direito PROPRIO', () {
      // A vaga do primeiro nao habilita nem atrapalha a do segundo: cada
      // admissao le o entitlement DA SUA identidade.
      final ana = _perfil(entitlement: _doc(), userId: 'ana');
      final bruno = _perfil(entitlement: _doc(), userId: 'bruno');
      final template = _catalogo()[TorneioIds.sextaMasterVip];

      expect(_admitir(ana).aceita, isTrue);
      final comAna = [_inscricaoDe('ana', template.tournamentId)];
      final r = _admitir(bruno, inscricoes: comAna);
      expect(r.aceita, isTrue);
      expect(r.inscricao!.userId, 'bruno');
    });

    test('ADM-03 o SEM-VIP nao entra, e o motivo e o de assinatura', () {
      final r = _admitir(_perfil());
      expect(r.aceita, isFalse);
      expect(r.recusa, MotivoRecusaInscricao.requisitoVipNaoAtendido);
    });

    test('ADM-04 repetir a MESMA admissao valida nao inscreve duas vezes', () {
      final ana = _perfil(entitlement: _doc());
      final template = _catalogo()[TorneioIds.sextaMasterVip];
      final primeira = _admitir(ana);
      expect(primeira.aceita, isTrue);

      final segunda = _admitir(ana,
          inscricoes: [_inscricaoDe('ana', template.tournamentId)]);
      expect(segunda.aceita, isFalse);
      expect(segunda.recusa, MotivoRecusaInscricao.jaInscrito);
      // A duplicidade e recusada ANTES de qualquer avaliacao cara: reinscrever
      // nao pode custar uma leitura de elegibilidade nem um segundo debito.
      expect(segunda.avaliacao, isNull);
    });

    test('ADM-05 duplicidade INCOMPATIVEL: inscricao cancelada NAO bloqueia',
        () {
      // `jaInscrito` olha o status ATIVO. Uma inscricao cancelada e um registro
      // historico, e tratar historico como bloqueio impediria o jogador de
      // voltar a um torneio que ele mesmo desistiu.
      final ana = _perfil(entitlement: _doc());
      final template = _catalogo()[TorneioIds.sextaMasterVip];
      final cancelada = Inscricao(
        tournamentId: template.tournamentId,
        editionId: 'ed-2026-08',
        userId: 'ana',
        status: StatusInscricao.cancelado,
        inscritoEm: _agora.subtract(const Duration(days: 1)),
        atualizadoEm: _agora.subtract(const Duration(hours: 2)),
      );
      expect(_admitir(ana, inscricoes: [cancelada]).aceita, isTrue);
    });

    test('ADM-06 edicao FORA da fase permitida recusa antes do VIP', () {
      // O VIP e valido; a edicao e que nao admite. A recusa tem de dizer isso,
      // e nao "falta assinatura" — mentir sobre o motivo manda o jogador
      // comprar o que ele ja tem.
      final ana = _perfil(entitlement: _doc());
      for (final fase in [
        EdicaoStatus.rascunho,
        EdicaoStatus.emRevisao,
        EdicaoStatus.agendado,
        EdicaoStatus.emAndamento,
        EdicaoStatus.encerrado,
      ]) {
        final r = _admitir(ana, status: fase);
        expect(r.aceita, isFalse, reason: fase.wire);
        expect(r.recusa, MotivoRecusaInscricao.inscricoesEncerradas,
            reason: fase.wire);
      }
    });

    test('ADM-07 perfil SUSPENSO nao entra nem com VIP integral vigente', () {
      final p = _perfil(
        entitlement: _doc(),
        moderacao: {
          'userId': 'ana',
          'suspensoAte': _agora.add(const Duration(days: 3)).toIso8601String(),
        },
      );
      expect(p.assinaturaAtiva, isTrue);
      expect(p.suspenso, isTrue);
      expect(_admitir(p).recusa, MotivoRecusaInscricao.perfilSuspenso);
    });
  });

  // ===========================================================================
  // ORIG — a matriz de origens de beneficio
  // ===========================================================================
  group('ORIG', () {
    test('ORIG-01 a relacao de origens integrais e FECHADA e tem produtor', () {
      // Os dois nomes, e a razao de cada um estar aqui, e que ha codigo que os
      // escreve. Nao ha terceiro nome porque nao ha terceiro produtor.
      expect(kOrigensVipIntegral, {'play', 'legado_usuarios'});
    });

    test('ORIG-02 assinatura INTEGRAL vigente concede', () {
      for (final origem in kOrigensVipIntegral) {
        expect(_perfil(entitlement: _doc(origem: origem)).assinaturaAtiva,
            isTrue,
            reason: origem);
      }
    });

    test('ORIG-03 assinatura VENCIDA nao concede, mesmo com vipAtivo gravado',
        () {
      // O documento ainda diz `vipAtivo: true` e `estado: ativo` — o job de
      // expiracao pode atrasar. Quem decide e o relogio da leitura.
      final p =
          _perfil(entitlement: _doc(validade: const Duration(minutes: -1)));
      expect(p.assinaturaAtiva, isFalse);
      expect(_admitir(p).recusa, MotivoRecusaInscricao.requisitoVipNaoAtendido);
    });

    test('ORIG-04 passe de CORTESIA nao concede', () {
      // O passe vive em `playerCourtesyPass` / `passesVip`, escrito por
      // functions-mesas. As duas metades da prova: um documento com forma de
      // passe, entregue no lugar do entitlement, nao concede; e a origem
      // `cortesia`, ainda que num documento de entitlement bem formado,
      // tambem nao.
      final comoPasse = _perfil(entitlement: const {
        'passeAtivo': true,
        'ciclo': '2026-Q3',
        'origem': 'cortesia',
      });
      expect(comoPasse.assinaturaAtiva, isFalse);

      final bemFormado = _perfil(entitlement: _doc(origem: 'cortesia'));
      expect(bemFormado.assinaturaAtiva, isFalse);
      expect(_admitir(bemFormado).recusa,
          MotivoRecusaInscricao.requisitoVipNaoAtendido);
    });

    test('ORIG-05 VIP PRESENTEADO nao concede — e o eixo e a ORIGEM', () {
      // ESTE E O CASO QUE A BASE NAO TINHA.
      //
      // A prova anterior demonstrava a recusa do presente com um ESTADO
      // inventado (`estado: 'presenteado'`), que cai em `desconhecido` e nao
      // concede. Isso e verdade e continua valendo — mas prova o eixo errado:
      // um presente NAO seria escrito com um estado inventado. Seria escrito
      // com estado LEGITIMO, prazo no futuro e `origem: 'administrativa'`, que
      // e a origem sem produtor documentada em `entitlement.dart`.
      //
      // Este documento e exatamente esse, e ele NAO concede.
      final presente = _doc(origem: 'administrativa');
      expect(presente['estado'], 'ativo');
      expect(presente['vipAtivo'], isTrue);

      final p = _perfil(entitlement: presente);
      expect(p.assinaturaAtiva, isFalse);
      expect(_admitir(p).recusa, MotivoRecusaInscricao.requisitoVipNaoAtendido);

      // E o mesmo vale para qualquer rotulo de presente que alguem escolha
      // amanha: a lista e fechada, entao o nome novo cai de fora por
      // construcao, e nao por um `else` que alguem tem de lembrar de escrever.
      for (final rotulo in [
        'presente',
        'presenteado',
        'gift',
        'promocional',
        'cortesia_vip',
        'admin',
      ]) {
        expect(_perfil(entitlement: _doc(origem: rotulo)).assinaturaAtiva,
            isFalse,
            reason: rotulo);
      }
    });

    test('ORIG-06 o eixo do ESTADO continua fechado, e independente da origem',
        () {
      // A guarda antiga nao foi substituida pela nova: as duas valem juntas.
      for (final estado in [
        'presenteado',
        'em_espera',
        'pausado',
        'pendente',
        'expirado',
        'revogado',
        'reembolsado',
        'nunca_teve',
        'rotulo_que_ninguem_previu',
      ]) {
        expect(_perfil(entitlement: _doc(estado: estado)).assinaturaAtiva,
            isFalse,
            reason: estado);
      }
    });

    test('ORIG-07 estado AUSENTE e estado DESCONHECIDO recusam', () {
      final semEstado = _perfil(entitlement: {
        'vipAtivo': true,
        'origem': 'play',
        'expiraEm': _agora.add(const Duration(days: 30)).toIso8601String(),
      });
      expect(semEstado.assinaturaAtiva, isFalse);
      expect(EstadoEntitlement.porWire(null), EstadoEntitlement.desconhecido);
      expect(EstadoEntitlement.porWire('seja_la_o_que_for'),
          EstadoEntitlement.desconhecido);
    });

    test('ORIG-08 entitlement AUSENTE recusa', () {
      expect(_perfil(entitlement: null).assinaturaAtiva, isFalse);
      expect(_perfil(entitlement: const {}).assinaturaAtiva, isFalse);
      expect(temVipEm('ana', null, _agora), isFalse);
      expect(_admitir(_perfil(entitlement: null)).recusa,
          MotivoRecusaInscricao.requisitoVipNaoAtendido);
    });

    test('ORIG-09 origem AUSENTE recusa: ausencia nao vira VIP', () {
      final semOrigem = _perfil(entitlement: {
        'vipAtivo': true,
        'estado': 'ativo',
        'expiraEm': _agora.add(const Duration(days: 30)).toIso8601String(),
      });
      expect(semOrigem.assinaturaAtiva, isFalse);
      expect(_perfil(entitlement: _doc(origem: '')).assinaturaAtiva, isFalse);
    });

    test('ORIG-10 documento SEM PRAZO nao concede, mesmo com origem integral',
        () {
      final semPrazo = _perfil(entitlement: _doc(comPrazo: false));
      expect(semPrazo.assinaturaAtiva, isFalse);
    });

    test(
        'ORIG-11 a origem NAO substitui a vigencia, e a vigencia NAO substitui '
        'a origem', () {
      // As duas metades sao independentes, e o teste afirma isso pelos quatro
      // quadrantes: so quem tem AS DUAS passa.
      const integral = 'play';
      const naoIntegral = 'administrativa';
      const vigente = Duration(days: 30);
      const vencida = Duration(days: -1);

      expect(
          _perfil(entitlement: _doc(origem: integral, validade: vigente))
              .assinaturaAtiva,
          isTrue);
      expect(
          _perfil(entitlement: _doc(origem: integral, validade: vencida))
              .assinaturaAtiva,
          isFalse);
      expect(
          _perfil(entitlement: _doc(origem: naoIntegral, validade: vigente))
              .assinaturaAtiva,
          isFalse);
      expect(
          _perfil(entitlement: _doc(origem: naoIntegral, validade: vencida))
              .assinaturaAtiva,
          isFalse);
    });

    test('ORIG-12 `integralVigenteEm` recusa instante SEM FUSO, como vigenteEm',
        () {
      // A ordem dos operandos importa: curto-circuitar a origem antes da
      // vigencia faria um documento de origem estranha silenciar a exigencia de
      // UTC, que e exigencia de TODOS os chamadores.
      final e = EntitlementVip.fromMap('ana', _doc(origem: 'administrativa'));
      expect(() => e.integralVigenteEm(DateTime(2026, 8, 22, 20)),
          throwsArgumentError);
      expect(() => comporPerfil(userId: 'ana', agora: DateTime(2026, 8, 22)),
          throwsArgumentError);
    });

    test('ORIG-13 a autoridade de VIP integral e UMA, e mora na elegibilidade',
        () {
      // Uma segunda lista de origens em qualquer lugar do dominio seria uma
      // segunda autoridade a divergir da primeira. A varredura afirma que nao
      // ha: `kOrigensVipIntegral` e declarada em `entitlement.dart` e CONSUMIDA
      // pelo predicado do mesmo arquivo — e por mais ninguem.
      final declaracoes = <String>[];
      for (final f in Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))) {
        final caminho = f.path.replaceAll(r'\', '/');
        final codigo = _semComentario(f.readAsStringSync());
        if (codigo.contains('kOrigensVipIntegral')) {
          declaracoes.add(caminho);
        }
        // Nenhum outro arquivo pode montar a propria relacao de origens.
        if (!caminho.endsWith('lib/elegibilidade/entitlement.dart')) {
          expect(codigo.contains("'legado_usuarios'"), isFalse,
              reason: '$caminho escreveu a propria relacao de origens');
        }
      }
      expect(declaracoes, ['lib/elegibilidade/entitlement.dart']);
    });
  });

  // ===========================================================================
  // CLI — o cliente nao fabrica elegibilidade
  // ===========================================================================
  group('CLI', () {
    test('CLI-01 `assinaturaAtiva: true` no documento NAO e lido', () {
      // O campo nem existe no formato do entitlement. Se um cliente conseguisse
      // escrever o documento (as Rules dizem que nao, ver RULES-03), o campo
      // seria simplesmente ignorado: a composicao le `vipAtivo`, `estado`,
      // `origem` e `expiraEm`, e nada mais.
      final forjado = _perfil(entitlement: const {
        'assinaturaAtiva': true,
        'vip': true,
        'elegivel': true,
        'origem': 'play',
        'estado': 'ativo',
      });
      expect(forjado.assinaturaAtiva, isFalse);
    });

    test('CLI-02 `vip: true` no documento NAO e lido', () {
      final forjado = _perfil(entitlement: {
        'vip': true,
        'vipAtivo': false,
        'estado': 'ativo',
        'origem': 'play',
        'expiraEm': _agora.add(const Duration(days: 30)).toIso8601String(),
      });
      expect(forjado.assinaturaAtiva, isFalse);
      expect(_admitir(forjado).recusa,
          MotivoRecusaInscricao.requisitoVipNaoAtendido);
    });

    test('CLI-03 a porta de admissao NAO recebe perfil do cliente', () {
      // A callable `inscreverEmTorneio` aceita `tournamentId`, `editionId` e
      // `parceiroId`. NAO ha caminho por onde `req.data` alcance o perfil: ele
      // e montado por `montarPerfil(uid)` a partir das colecoes, com o `uid` do
      // `request.auth`, e nao do corpo.
      final corpo = _semComentario(_texto('../functions/src/index.ts'));

      expect(corpo.contains('montarPerfil(uid)'), isTrue);
      expect(RegExp(r'req\.data[^;\n]*perfil').hasMatch(corpo), isFalse,
          reason: 'perfil vindo do corpo da requisicao');
      expect(
          RegExp(r'req\.data[^;\n]*assinaturaAtiva').hasMatch(corpo), isFalse);
      expect(RegExp(r'req\.data[^;\n]*\bvip\b').hasMatch(corpo), isFalse);
      // O uid vem da autenticacao, sempre.
      expect(corpo.contains('exigirAutenticacao(req)'), isTrue);
      expect(RegExp(r'const\s+uid\s*=\s*req\.data').hasMatch(corpo), isFalse);
    });

    test('CLI-04 `montarPerfil` le as FONTES, e nenhuma delas e o cliente', () {
      final corpo = _semComentario(_texto('../functions/src/index.ts'));
      final inicio = corpo.indexOf('async function montarPerfil');
      expect(inicio, greaterThan(-1));
      final fim = corpo.indexOf('export const inscreverEmTorneio', inicio);
      expect(fim, greaterThan(inicio));
      final funcao = corpo.substring(inicio, fim);

      expect(funcao.contains('"playerEntitlements"'), isTrue);
      expect(funcao.contains('"playerModeration"'), isTrue);
      expect(funcao.contains('dominio.comporElegibilidade'), isTrue);
      // Nenhum literal de elegibilidade e MONTADO aqui: foi projetar campo por
      // conta propria que produziu o defeito P0-1.
      expect(funcao.contains('assinaturaAtiva'), isFalse);
      expect(RegExp(r'\bvipAtivo\b').hasMatch(funcao), isFalse);
    });

    test(
        'CLI-05 nenhuma tela decide elegibilidade de torneio por conta propria',
        () {
      for (final f in Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) {
        final p = f.path.replaceAll(r'\', '/');
        return p.endsWith('.dart') &&
            (p.contains('/screens/') || p.contains('/casca/'));
      })) {
        final codigo = _semComentario(f.readAsStringSync());
        expect(codigo.contains('kOrigensVipIntegral'), isFalse,
            reason: f.path);
        expect(codigo.contains('integralVigenteEm'), isFalse, reason: f.path);
        expect(codigo.contains('comporPerfil'), isFalse, reason: f.path);
      }
    });
  });

  // ===========================================================================
  // CONV — o convite
  // ===========================================================================
  group('CONV', () {
    test('CONV-01 `somente_convidados` deriva OS DOIS criterios', () {
      // O convite e CUMULATIVO ao VIP, e agora quem afirma isso e o codigo que
      // decide, e nao so a prosa do contrato normativo em `contrato_v1.dart`.
      final t = _templateDeConvidados();
      expect(t.acesso, AcessoTorneio.somenteConvidados);
      expect(t.criteriosElegibilidade, containsAll(['assinatura', 'convite']));
    });

    test('CONV-02 os criterios de `somente_convidados` PARSEIAM', () {
      // Eles NAO parseavam: a derivacao produzia `convite:<tournamentId>`, e
      // `TipoCriterio.convite` nao aceita argumento — entao
      // `CriterioElegibilidade.parse` lancava `FormatException` e a avaliacao
      // inteira morria antes de recusar coisa alguma.
      final t = _templateDeConvidados();
      expect(t.criteriosInterpretados.map((c) => c.tipo),
          containsAll([TipoCriterio.assinatura, TipoCriterio.convite]));
      // E a forma que explodia continua sendo recusada, para que ninguem a
      // reintroduza achando que ela era valida.
      expect(() => CriterioElegibilidade.parse('convite:qualquer_coisa'),
          throwsFormatException);
    });

    test('CONV-03 convite SEM VIP nao entra', () {
      final t = _templateDeConvidados();
      final a = t.avaliar(_perfil(convites: {t.tournamentId}));
      expect(a.elegivel, isFalse);
      expect(a.falhas.map((f) => f.recusa),
          contains(RecusaElegibilidade.semAssinatura));
    });

    test('CONV-04 VIP SEM convite nao entra no torneio de convidados', () {
      final t = _templateDeConvidados();
      final a = t.avaliar(_perfil(entitlement: _doc()));
      expect(a.elegivel, isFalse);
      expect(a.falhas.map((f) => f.recusa),
          contains(RecusaElegibilidade.semConvite));
    });

    test('CONV-05 VIP integral COM convite proprio entra', () {
      final t = _templateDeConvidados();
      final ok = _perfil(entitlement: _doc(), convites: {t.tournamentId});
      expect(t.avaliar(ok).elegivel, isTrue);
    });

    test('CONV-06 convite de OUTRO torneio nao habilita este', () {
      final t = _templateDeConvidados();
      final outro = _perfil(
        entitlement: _doc(),
        convites: const {'encerramento_anual', 'temporada_2025'},
      );
      final a = t.avaliar(outro);
      expect(a.elegivel, isFalse);
      expect(a.falhas.map((f) => f.recusa),
          contains(RecusaElegibilidade.semConvite));
    });

    test(
        'CONV-07 convite INEXISTENTE e convite EXPIRADO chegam iguais: ausentes',
        () {
      // A traducao mora em `montarPerfil`, que so aceita `convite_aceito` e
      // `confirmado`. Todo outro status — inclusive expirado, recusado e
      // revogado — nao vira convite ativo, e o dominio recusa por `semConvite`.
      final corpo = _semComentario(_texto('../functions/src/index.ts'));
      expect(corpo.contains('"status", "in", ["convite_aceito", "confirmado"]'),
          isTrue);

      final t = _templateDeConvidados();
      expect(
          t
              .avaliar(_perfil(entitlement: _doc()))
              .falhas
              .map((f) => f.recusa)
              .contains(RecusaElegibilidade.semConvite),
          isTrue);
    });

    test('CONV-08 o Encerramento e EventoEncerramento, e NAO um template', () {
      // Este caso existe para que a cobertura de CONV-01..07 nao seja lida como
      // maior do que e. O unico `somente_convidados` da V1 nao passa por
      // `avaliarElegibilidade`: ele e outro tipo, sem criterios derivados e sem
      // porta de inscricao. Foi por isso que o defeito da derivacao pode viver
      // tanto tempo sem ninguem esbarrar nele.
      //
      // Quando a etapa de convites ligar o Encerramento, ou ele vira
      // `TorneioTemplate` — e CONV-01..07 passam a valer sobre o modelo real —
      // ou ele ganha porta propria, e ai esta linha fica vermelha e a decisao
      // aparece no diff.
      final evento = _catalogo().encerramento!;
      expect(evento, isA<EventoEncerramento>());
      expect(evento.acesso, AcessoTorneio.somenteConvidados);
      expect(evento.convitesAtivosEmProducao, isFalse);
      expect(
          _catalogo().todos.map((t) => t.acesso),
          everyElement(AcessoTorneio.vip),
          reason: 'um template do catalogo passou a declarar outro acesso');
    });
  });

  // ===========================================================================
  // AUT — a autoridade falhando
  // ===========================================================================
  group('AUT', () {
    test('AUT-01 documento MALFORMADO nao concede — e nao passa batido', () {
      // Campo com tipo errado: quem le espera String ISO em `expiraEm`.
      expect(
          _perfil(entitlement: {
            'vipAtivo': true,
            'estado': 'ativo',
            'origem': 'play',
            'expiraEm': 1755892800,
          }).assinaturaAtiva,
          isFalse);
      // Prazo ilegivel derruba a operacao, e nao vira "sem prazo" em silencio:
      // um texto que nao e data e dado corrompido, e dado corrompido tem de
      // aparecer.
      expect(
          () => _perfil(entitlement: {
                'vipAtivo': true,
                'estado': 'ativo',
                'origem': 'play',
                'expiraEm': 'ontem a tarde',
              }),
          throwsFormatException);
    });

    test('AUT-02 a ponte devolve ERRO TIPADO, e nunca um perfil de consolo',
        () {
      // `js_bridge.dart` embrulha cada entrada num try/catch que serializa
      // `{"erro": ...}`. Nenhum `catch` produz perfil, elegibilidade ou
      // `assinaturaAtiva`.
      final ponte = _semComentario(_texto('lib/torneios/js_bridge.dart'));
      expect(ponte.contains('return _erro(e);'), isTrue);
      expect(
          RegExp(r'catch\s*\([^)]*\)\s*\{\s*return\s+(?!_erro)').hasMatch(ponte),
          isFalse,
          reason: 'um catch devolvendo algo que nao seja erro tipado');
      expect(RegExp(r"assinaturaAtiva'?\s*:\s*true").hasMatch(ponte), isFalse);
    });

    test('AUT-03 a porta NAO tem fallback: falha de leitura derruba a chamada',
        () {
      // `montarPerfil` usa `Promise.all` sem `.catch`, e `inscreverEmTorneio`
      // nao embrulha a composicao em try/catch. Um timeout ou erro do Firestore
      // rejeita a callable — que e a recusa correta —, em vez de seguir com um
      // perfil vazio, que concederia por omissao em qualquer torneio sem
      // criterio.
      final corpo = _semComentario(_texto('../functions/src/index.ts'));
      final inicio = corpo.indexOf('async function montarPerfil');
      final fim = corpo.indexOf('export const cancelarInscricaoTorneio');
      final trecho = corpo.substring(inicio, fim);
      expect(trecho.contains('Promise.all'), isTrue);
      expect(trecho.contains('catch'), isFalse,
          reason: 'a admissao ganhou um caminho de recuperacao silenciosa');
      expect(RegExp(r'\|\|\s*\{\s*\}').hasMatch(trecho), isFalse,
          reason: 'perfil default por omissao');
    });

    test('AUT-04 a decisao da admissao e UMA, e ela e do dominio', () {
      // Nenhum `if` de elegibilidade em TypeScript: a Function pergunta e
      // obedece. Se um deles aparecer aqui, existem duas respostas para a mesma
      // pergunta, e elas divergem no primeiro dia.
      final corpo = _semComentario(_texto('../functions/src/index.ts'));
      final inicio = corpo.indexOf('export const inscreverEmTorneio');
      final fim = corpo.indexOf('export const cancelarInscricaoTorneio');
      final porta = corpo.substring(inicio, fim);

      expect(porta.contains('dominio.inscrever'), isTrue);
      expect(porta.contains('veredito.aceita'), isTrue);
      for (final proibido in [
        'assinaturaAtiva',
        'vipAtivo',
        'expiraEm',
        'kOrigensVipIntegral',
        'playerCourtesyPass',
        'passesVip',
      ]) {
        expect(porta.contains(proibido), isFalse, reason: proibido);
      }
    });
  });

  // ===========================================================================
  // RULES — a porta de escrita direta
  // ===========================================================================
  group('RULES', () {
    test('RULES-01 `registrations` continua FECHADA para o cliente', () {
      final rules = _texto('../firebase/firestore.rules');
      final i = rules.indexOf('match /registrations/{userId}');
      expect(i, greaterThan(-1));
      final bloco =
          rules.substring(i, rules.indexOf('}', rules.indexOf('allow write', i)));
      expect(bloco.contains('allow write: if false;'), isTrue);
      expect(RegExp(r'allow\s+(create|update|delete)\s*:').hasMatch(bloco),
          isFalse,
          reason: 'a porta de inscricao direta reabriu');
    });

    test('RULES-02 `editions` continua fechada para escrita do cliente', () {
      final rules = _texto('../firebase/firestore.rules');
      final i = rules.indexOf('match /editions/{editionId}');
      expect(i, greaterThan(-1));
      final bloco = rules.substring(i, i + 400);
      expect(bloco.contains('allow write: if false;'), isTrue);
    });

    test('RULES-03 o cliente nao escreve o proprio entitlement', () {
      // O cliente le o proprio direito e nao escreve nenhum. Sem isto, a lista
      // fechada de origens seria decorativa: bastaria gravar `origem: 'play'`
      // no proprio documento.
      final rules = _texto('../firebase/firestore.rules');
      final i = rules.indexOf('match /playerEntitlements/{uid}');
      expect(i, greaterThan(-1));
      final bloco = rules.substring(i, i + 200);
      expect(bloco.contains('allow write: if false;'), isTrue,
          reason: 'sem isto, o cliente escolhe a propria origem');
      expect(RegExp(r'allow\s+(create|update)\s*:').hasMatch(bloco), isFalse);
      // E o documento interno do Billing continua fechado para todo mundo.
      final interno = rules.indexOf('match /interno/{documento}', i);
      expect(interno, greaterThan(i));
      expect(rules.substring(interno, interno + 120)
          .contains('allow read, write: if false;'), isTrue);
    });
  });

  // ===========================================================================
  // GRD — as guardas da fundacao sobreviveram
  // ===========================================================================
  group('GRD', () {
    test('GRD-01 os acessos admitidos da V1 continuam dois', () {
      expect(kAcessosAdmitidosV1, {'vip', 'somente_convidados'});
      expect(kParticipacaoV1, 'individual');
    });

    test('GRD-02 os superseded continuam FORA do catalogo ativo', () {
      final ativos = _catalogo().todos.map((t) => t.tournamentId).toSet();
      for (final id in TorneioIds.superseded) {
        expect(ativos, isNot(contains(id)), reason: id);
      }
      expect(() => _catalogo()[TorneioIds.quartaVulnerabilidade],
          throwsA(anything));
    });

    test('GRD-03 `em_revisao` continua no caminho, e o salto continua RECUSADO',
        () {
      expect(quebrasDoCicloEditorialV1(), isEmpty);
      final salto = avaliarTransicao(
        de: EdicaoStatus.rascunho,
        para: EdicaoStatus.agendado,
        ator: AtorTransicao.administracao,
      );
      expect(salto.permitida, isFalse);
      expect(salto.recusa, RecusaTransicao.transicaoInexistente);
    });

    test('GRD-04 `criadoPor` continua obrigatorio, e o criador nao se aprova',
        () {
      // A cobranca mora na APROVACAO, que e onde a separacao de funcoes precisa
      // valer: sem saber quem criou, nao ha como afirmar que o aprovador e
      // outra pessoa.
      expect(
        avaliarTransicao(
          de: EdicaoStatus.emRevisao,
          para: EdicaoStatus.agendado,
          ator: AtorTransicao.administracao,
          operadorId: 'op-2',
        ).recusa,
        RecusaTransicao.criadorAusente,
      );
      expect(
        avaliarTransicao(
          de: EdicaoStatus.emRevisao,
          para: EdicaoStatus.agendado,
          ator: AtorTransicao.administracao,
          criadaPor: 'op-1',
        ).recusa,
        RecusaTransicao.aprovadorAusente,
      );
      expect(
        avaliarTransicao(
          de: EdicaoStatus.emRevisao,
          para: EdicaoStatus.agendado,
          ator: AtorTransicao.administracao,
          criadaPor: 'op-1',
          operadorId: 'op-1',
        ).recusa,
        RecusaTransicao.aprovadorIgualAoCriador,
      );
      expect(
        validarTemplateV1({
          'templateId': 'x',
          'versao': 1,
          'esquema': kEsquemaTemplateV1,
          'acesso': 'vip',
          'participacao': 'individual',
        }),
        contains(ViolacaoContratoV1.criadorAusente),
      );
    });

    test('GRD-05 o jogador continua sem mover status', () {
      for (final para in EdicaoStatus.values) {
        final r = avaliarTransicao(
          de: EdicaoStatus.inscricoesAbertas,
          para: para,
          ator: AtorTransicao.jogador,
        );
        expect(r.permitida, isFalse, reason: para.wire);
        expect(r.recusa, RecusaTransicao.atorNaoAutorizado, reason: para.wire);
      }
    });

    test('GRD-06 esta correcao nao ligou nenhum cliente de Torneios', () {
      // A fundacao venceu a arbitragem afirmando que NAO LIGOU NADA. A C1 mexeu
      // em elegibilidade e no modelo; ela nao pode ter aberto uma porta de
      // inscricao na tela por tabela.
      for (final f in Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) {
        final p = f.path.replaceAll(r'\', '/');
        return p.endsWith('.dart') &&
            (p.contains('/screens/') || p.contains('/casca/'));
      })) {
        final codigo = _semComentario(f.readAsStringSync());
        for (final proibido in [
          'inscreverEmTorneio',
          'inscrever(',
          'avaliarElegibilidade',
        ]) {
          expect(codigo.contains(proibido), isFalse,
              reason: '${f.path} chama $proibido');
        }
      }
    });

    test('GRD-07 Billing e Comunicacao NAO mudaram de resposta', () {
      // A correcao e de elegibilidade, e o alcance dela e o alcance da politica
      // que a pediu. Quem le `vigenteEm` continua lendo `vigenteEm`.
      for (final caminho in [
        'lib/billing/gerenciar_assinatura.dart',
        'lib/billing/estado_ui.dart',
        'lib/billing/acesso_vip.dart',
        'lib/comunicacao/porta.dart',
      ]) {
        final codigo = _semComentario(_texto(caminho));
        expect(codigo.contains('integralVigenteEm'), isFalse, reason: caminho);
        expect(codigo.contains('kOrigensVipIntegral'), isFalse,
            reason: caminho);
      }
      // E `vigenteEm` continua respondendo o que sempre respondeu: um direito
      // administrativo vigente E VIP para a loja e para o chat.
      final adm = EntitlementVip.fromMap('ana', _doc(origem: 'administrativa'));
      expect(adm.vigenteEm(_agora), isTrue);
      expect(adm.integralVigenteEm(_agora), isFalse);
    });

    test('GRD-08 a fundacao nao ganhou carteira nem fila nova', () {
      for (final f in Directory('lib/torneios')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))) {
        final p = f.path.replaceAll(r'\', '/');
        if (p.endsWith('lib/torneios/contrato_v1.dart')) continue;
        final codigo = _semComentario(f.readAsStringSync());
        for (final proibido in ['wallets', 'tournamentJobs']) {
          expect(codigo.contains(proibido), isFalse,
              reason: '$p menciona $proibido');
        }
      }
    });
  });
}
