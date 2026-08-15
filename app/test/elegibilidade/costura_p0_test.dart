// costura_p0_test.dart — a PROVA DE FRONTEIRA que faltava.
//
// O QUE ESTE ARQUIVO EXISTE PARA IMPEDIR
//
// A homologacao P0 integrada fechou com 604 testes verdes e ainda assim
// encontrou dois bloqueadores. O motivo esta em uma linha do teste do motor:
//
//     motor_torneios_test.dart:706
//     perfil: _perfil('ana', suspenso: true)
//
// A flag era CONSTRUIDA A MAO e injetada direto no dominio. O dominio estava
// certo, o teste passava — e a costura onde o nome do campo divergia nao era
// exercitada por ninguem. Na producao, `suspenso` vinha de `players/{uid}`, uma
// colecao que nenhum produtor alimentava, e portanto era sempre `false`.
//
// Aqui NENHUM estado e construido a mao. Cada caso comeca no PRODUTOR real e
// atravessa a fronteira inteira:
//
//     avaliarSancao + consolidar()      <- o mesmo codigo que a Cloud Function
//              |                           de moderacao executa
//              v
//     documento playerModeration/{uid}  <- exatamente o que ela grava
//              |
//              +-- documento playerEntitlements/{uid}  <- o que o Billing grava
//              v
//        comporPerfil()                 <- a fronteira de elegibilidade
//              v
//        inscrever()                    <- o consumidor
//              v
//        recusa / aceite
//
// SOBRE O LADO DO BILLING, DITO SEM MAQUIAGEM
//
// O produtor do entitlement e JavaScript (`functions-billing/entitlement.js`) e
// nao roda dentro de um teste Dart. Os documentos abaixo sao, portanto, LITERAIS
// — mas nao literais inventados: cada um deles e verificado, campo a campo,
// contra a saida real de `documentosDeEntitlement` no grupo "CONTRATO COM O
// CONSUMIDOR" de `functions-billing/test/entitlement.test.js`. Mexer no formato
// de um lado quebra o outro. E um contrato espelhado com estopim nos dois lados,
// e nao uma unica prova automatica; a distincao esta declarada no relatorio.

import 'package:buraco_master_vip/elegibilidade/composicao.dart';
import 'package:buraco_master_vip/elegibilidade/entitlement.dart';
import 'package:buraco_master_vip/moderacao/sancao.dart';
import 'package:buraco_master_vip/torneios/assets_registry.dart';
import 'package:buraco_master_vip/torneios/eligibility.dart';
import 'package:buraco_master_vip/torneios/registrations.dart';
import 'package:buraco_master_vip/torneios/tournament_lifecycle.dart';
import 'package:buraco_master_vip/torneios/tournament_model.dart';
import 'package:flutter_test/flutter_test.dart';

const uid = 'jogadora-ana';
const kProduto = 'master_vip_mensal';

final agora = DateTime.utc(2026, 8, 11, 20);
final futuro = agora.add(const Duration(days: 20));
final passado = agora.subtract(const Duration(days: 5));

// ===========================================================================
// PRODUTORES REAIS
// ===========================================================================

/// Aplica uma sancao pelo MESMO caminho da Cloud Function de moderacao e devolve
/// o documento que ela grava em `playerModeration/{uid}`.
///
/// A ordem reproduz `aplicarSancao` (`functions-moderacao/src/index.ts`):
/// primeiro `avaliarSancao` julga o pedido, depois `consolidar` dobra o
/// historico no efeito vigente, e o `toJson` do efeito e o corpo do documento.
Map<String, Object?> documentoDeModeracao(
  List<Sancao> sancoes, {
  DateTime? em,
}) {
  for (final s in sancoes) {
    final veredito = avaliarSancao(
      userId: s.userId,
      responsavel: s.responsavel,
      tipo: s.tipo,
      motivo: s.motivo,
      inicio: s.inicio,
      fim: s.fim,
    );
    // Uma sancao que a propria moderacao recusaria nao serve de premissa: o
    // teste estaria provando um estado que o sistema nunca produziria.
    expect(veredito.aceita, isTrue,
        reason: 'sancao de premissa recusada: ${veredito.recusa}');
  }
  return consolidar(uid, sancoes, em ?? agora).toJson();
}

Sancao sancao({
  required TipoSancao tipo,
  DateTime? inicio,
  DateTime? fim,
  StatusSancao status = StatusSancao.ativa,
  String id = 'sancao-1',
}) =>
    Sancao(
      sancaoId: id,
      userId: uid,
      tipo: tipo,
      motivo: 'conduta antidesportiva reiterada',
      inicio: inicio ?? agora.subtract(const Duration(hours: 1)),
      fim: fim,
      responsavel: 'admin-moderacao',
      status: status,
    );

/// O documento `playerEntitlements/{uid}` tal como o Billing o grava.
///
/// ESPELHO de `documentosDeEntitlement().publico`. Ver o grupo "CONTRATO COM O
/// CONSUMIDOR" em `functions-billing/test/entitlement.test.js`.
Map<String, Object?> documentoDeEntitlement({
  required bool vipAtivo,
  required EstadoEntitlement estado,
  DateTime? expiraEm,
  String origem = 'play',
  bool renovacaoAutomatica = true,
  bool comInicio = true,
}) =>
    {
      'uid': uid,
      'vipAtivo': vipAtivo,
      'estado': estado.wire,
      'produtoId': kProduto,
      'origem': origem,
      // Desfecho terminal nao carrega inicio: ele descreve o fim, nao o
      // periodo. Ver `consolidarTerminal` no lado do Billing.
      'inicioEm': comInicio ? passado.toIso8601String() : null,
      'expiraEm': expiraEm?.toIso8601String(),
      'renovacaoAutomatica': renovacaoAutomatica,
      'atualizadoEm': agora.toIso8601String(),
      'esquema': kEsquemaEntitlement,
    };

// ===========================================================================
// CONSUMIDOR REAL
// ===========================================================================

TorneioTemplate torneio({AcessoTorneio acesso = AcessoTorneio.vip}) =>
    TorneioTemplate(
      tournamentId: 'sexta_master_vip',
      nome: 'Sexta Master VIP',
      versao: 1,
      acesso: acesso,
      participacao: TipoParticipacao.individual,
      modalidade: const PoliticaModalidade(
        tipo: TipoPoliticaModalidade.fixa,
        valor: ModalidadeMesa.aberto,
      ),
      recorrencia: const PoliticaRecorrencia(
        tipo: TipoRecorrencia.semanal,
        diaSemana: 'sexta',
        horario: '20:00',
      ),
      vagasMax: 16,
      vagasMin: 4,
      checkin: const JanelaCheckin(abre: '19:30', fecha: '19:55'),
      entrada: const PoliticaEntrada(tipo: 'gratuito'),
      premiacao: const [
        FaixaPremiacao(
          colocacao: 1,
          crownAssetId: TorneioAssetIds.crownChampion,
          fichas: 1000,
        ),
      ],
      capaAssetId: TorneioAssetIds.capaCopaBuracoMaster,
    );

EdicaoTorneio edicao() {
  final base = agora.add(const Duration(hours: 4));
  return EdicaoTorneio(
    tournamentId: 'sexta_master_vip',
    editionId: 'ed-2026-08-14',
    numeroEdicao: 7,
    temporada: '2026',
    status: EdicaoStatus.inscricoesAbertas,
    inicioPrevisto: base,
    inscricoesAbremEm: base.subtract(const Duration(days: 5)),
    inscricoesFechamEm: base.subtract(const Duration(minutes: 30)),
    modalidade: ModalidadeMesa.aberto,
    numeroFases: 2,
    formato: FormatoTorneio.misto,
    metaPontos: 1500,
    regraVersao: 1,
    criadoEm: agora.subtract(const Duration(days: 30)),
    atualizadoEm: agora,
  );
}

/// A travessia completa: documentos -> composicao -> inscricao.
///
/// E de proposito que nao existe um atalho para "montar um perfil": todo caso
/// deste arquivo tem que passar por `comporPerfil`, senao ele volta a ser o
/// teste que a homologacao reprovou.
ResultadoInscricao inscrever2({
  Map<String, Object?>? moderacao,
  Map<String, Object?>? entitlement,
  AcessoTorneio acesso = AcessoTorneio.vip,
}) {
  final perfil = comporPerfil(
    userId: uid,
    agora: agora,
    moderacao: moderacao,
    entitlement: entitlement,
  );
  return inscrever(
    edicao: edicao(),
    template: torneio(acesso: acesso),
    perfil: perfil,
    vagas: const ConfiguracaoVagas(limite: 16),
    agora: agora,
    saldoFichas: 0,
  );
}

void main() {
  // =====================================================================
  // CASO A — jogador suspenso nao se inscreve
  // =====================================================================
  group('P0-A moderacao chega ao portao de torneios', () {
    test('A-01 suspensao temporaria vigente recusa a inscricao', () {
      final doc = documentoDeModeracao([
        sancao(
          tipo: TipoSancao.suspensaoTemporaria,
          fim: agora.add(const Duration(days: 3)),
        ),
      ]);

      // O documento produzido carrega o prazo, e nao um booleano: e o que
      // permite a suspensao acabar sozinha.
      expect(doc['suspensoAte'], isNotNull);
      expect(doc['suspensaoPermanente'], isFalse);

      final r = inscrever2(
        moderacao: doc,
        entitlement: documentoDeEntitlement(
          vipAtivo: true,
          estado: EstadoEntitlement.ativo,
          expiraEm: futuro,
        ),
      );

      // VIP em dia e mesmo assim recusado: sancao vem antes de qualquer
      // criterio do torneio.
      expect(r.aceita, isFalse);
      expect(r.recusa, MotivoRecusaInscricao.perfilSuspenso);
    });

    test('A-02 suspensao permanente recusa mesmo sem prazo', () {
      final doc = documentoDeModeracao([
        sancao(tipo: TipoSancao.suspensaoPermanente),
      ]);
      expect(doc['suspensaoPermanente'], isTrue);
      expect(doc['suspensoAte'], isNull);

      final r = inscrever2(moderacao: doc, acesso: AcessoTorneio.publico);
      expect(r.recusa, MotivoRecusaInscricao.perfilSuspenso);
    });

    test('A-03 suspensao JA VENCIDA nao impede: o prazo e reavaliado na leitura',
        () {
      // A sancao foi consolidada quando ainda valia...
      final doc = documentoDeModeracao(
        [
          sancao(
            tipo: TipoSancao.suspensaoTemporaria,
            inicio: agora.subtract(const Duration(hours: 6)),
            fim: agora.subtract(const Duration(hours: 2)),
          ),
        ],
        em: agora.subtract(const Duration(hours: 5)),
      );
      expect(doc['suspensoAte'], isNotNull);

      // ...e o consumidor le depois de ela ter vencido. Ninguem precisou rodar
      // um job para desligar a flag.
      final r = inscrever2(moderacao: doc, acesso: AcessoTorneio.publico);
      expect(r.aceita, isTrue);
    });

    test('A-04 sancao revogada perde efeito no proximo consolidar', () {
      final doc = documentoDeModeracao([
        sancao(
          tipo: TipoSancao.suspensaoTemporaria,
          fim: agora.add(const Duration(days: 3)),
          status: StatusSancao.revogada,
        ),
      ]);
      final r = inscrever2(moderacao: doc, acesso: AcessoTorneio.publico);
      expect(r.aceita, isTrue);
    });

    test('A-05 silencio de chat NAO impede competir', () {
      // Sancao existe, mas nao e das que barram o jogo. Uma composicao que
      // tratasse "tem documento de moderacao" como "esta suspenso" reprovaria
      // aqui — e seria punicao inventada.
      final doc = documentoDeModeracao([
        sancao(
          tipo: TipoSancao.muteTemporario,
          fim: agora.add(const Duration(days: 3)),
        ),
      ]);
      expect(doc['chatSilenciadoAte'], isNotNull);

      final r = inscrever2(moderacao: doc, acesso: AcessoTorneio.publico);
      expect(r.aceita, isTrue);
    });

    test('A-06 sem documento de moderacao, ninguem esta suspenso', () {
      expect(estaSuspensoEm(uid, null, agora), isFalse);
      expect(estaSuspensoEm(uid, const {}, agora), isFalse);
    });
  });

  // =====================================================================
  // CASOS B a G — o ciclo de vida do VIP chega ao portao
  // =====================================================================
  group('P0-B..G entitlement chega ao portao de torneios', () {
    test('B VIP vigente ENTRA no torneio VIP', () {
      final r = inscrever2(
        entitlement: documentoDeEntitlement(
          vipAtivo: true,
          estado: EstadoEntitlement.ativo,
          expiraEm: futuro,
        ),
      );
      expect(r.aceita, isTrue, reason: 'assinante pagante foi recusado');
      expect(r.inscricao!.status, StatusInscricao.inscrito);
    });

    test('C sem entitlement nenhum, torneio VIP recusa', () {
      final r = inscrever2(entitlement: null);
      expect(r.aceita, isFalse);
      expect(r.recusa, MotivoRecusaInscricao.requisitoVipNaoAtendido);
      expect(
        r.avaliacao!.principal!.recusa,
        RecusaElegibilidade.semAssinatura,
      );
    });

    test('D VIP EXPIRADO recusa — inclusive com vipAtivo ainda gravado', () {
      // O caso que separa esta correcao de um `vip: true` renomeado. O
      // documento ainda diz `vipAtivo`, porque a varredura de vencimento pode
      // nao ter rodado; quem recusa e o prazo, avaliado na leitura.
      final r = inscrever2(
        entitlement: documentoDeEntitlement(
          vipAtivo: true,
          estado: EstadoEntitlement.ativo,
          expiraEm: passado,
        ),
      );
      expect(r.recusa, MotivoRecusaInscricao.requisitoVipNaoAtendido);
    });

    test('D-2 apos a varredura, o documento tambem conta a verdade', () {
      final r = inscrever2(
        entitlement: documentoDeEntitlement(
          vipAtivo: false,
          estado: EstadoEntitlement.expirado,
          expiraEm: passado,
          renovacaoAutomatica: false,
        ),
      );
      expect(r.recusa, MotivoRecusaInscricao.requisitoVipNaoAtendido);
    });

    test('E VIP REVOGADO recusa — documento como o Billing o grava', () {
      final r = inscrever2(
        entitlement: documentoDeEntitlement(
          vipAtivo: false,
          estado: EstadoEntitlement.revogado,
          // `consolidarTerminal` encerra o direito no instante do evento.
          expiraEm: agora,
          renovacaoAutomatica: false,
          comInicio: false,
        ),
      );
      expect(r.recusa, MotivoRecusaInscricao.requisitoVipNaoAtendido);
    });

    test('E-2 revogado recusa AINDA QUE o prazo estivesse no futuro', () {
      // Mais duro que a realidade de proposito: mesmo que uma escrita parcial
      // deixasse o prazo antigo no documento, o estado terminal sozinho recusa.
      final r = inscrever2(
        entitlement: documentoDeEntitlement(
          vipAtivo: false,
          estado: EstadoEntitlement.revogado,
          expiraEm: futuro,
        ),
      );
      expect(r.recusa, MotivoRecusaInscricao.requisitoVipNaoAtendido);
    });

    test('F VIP REEMBOLSADO recusa — documento como o Billing o grava', () {
      final r = inscrever2(
        entitlement: documentoDeEntitlement(
          vipAtivo: false,
          estado: EstadoEntitlement.reembolsado,
          expiraEm: agora,
          renovacaoAutomatica: false,
          comInicio: false,
        ),
      );
      expect(r.recusa, MotivoRecusaInscricao.requisitoVipNaoAtendido);
    });

    test('F-2 reembolsado recusa AINDA QUE o prazo estivesse no futuro', () {
      final r = inscrever2(
        entitlement: documentoDeEntitlement(
          vipAtivo: false,
          estado: EstadoEntitlement.reembolsado,
          expiraEm: futuro,
        ),
      );
      expect(r.recusa, MotivoRecusaInscricao.requisitoVipNaoAtendido);
    });

    test('G CANCELADO com periodo ainda pago CONTINUA entrando', () {
      // Desligar a renovacao nao e perder o que ja foi cobrado. Encerrar aqui
      // seria vender um mes e entregar meio.
      final r = inscrever2(
        entitlement: documentoDeEntitlement(
          vipAtivo: true,
          estado: EstadoEntitlement.canceladoVigente,
          expiraEm: futuro,
          renovacaoAutomatica: false,
        ),
      );
      expect(r.aceita, isTrue);
    });

    test('G-2 o mesmo cancelamento, depois do prazo, recusa', () {
      final r = inscrever2(
        entitlement: documentoDeEntitlement(
          vipAtivo: true,
          estado: EstadoEntitlement.canceladoVigente,
          expiraEm: passado,
          renovacaoAutomatica: false,
        ),
      );
      expect(r.recusa, MotivoRecusaInscricao.requisitoVipNaoAtendido);
    });

    test('H carencia e conta em atraso: uma concede, a outra nao', () {
      final carencia = inscrever2(
        entitlement: documentoDeEntitlement(
          vipAtivo: true,
          estado: EstadoEntitlement.emCarencia,
          expiraEm: futuro,
        ),
      );
      expect(carencia.aceita, isTrue);

      final espera = inscrever2(
        entitlement: documentoDeEntitlement(
          vipAtivo: false,
          estado: EstadoEntitlement.emEspera,
          expiraEm: futuro,
        ),
      );
      expect(espera.recusa, MotivoRecusaInscricao.requisitoVipNaoAtendido);
    });

    test('I torneio publico nao exige VIP nenhum', () {
      final r = inscrever2(entitlement: null, acesso: AcessoTorneio.publico);
      expect(r.aceita, isTrue);
    });
  });

  // =====================================================================
  // O QUE NAO PODE CONCEDER
  // =====================================================================
  group('P0 fail-closed: duvida nunca vira acesso', () {
    test('FC-01 documento incoerente (revogado + vipAtivo) nao concede', () {
      // Escrita parcial, migracao malfeita ou campo adulterado: as tres
      // condicoes juntas e que concedem, e este documento so tem uma.
      final e = EntitlementVip.fromMap(uid, {
        'vipAtivo': true,
        'estado': 'revogado',
        'expiraEm': futuro.toIso8601String(),
      });
      expect(e.vigenteEm(agora), isFalse);
    });

    test('FC-02 estado que este codigo nao conhece nao concede', () {
      final e = EntitlementVip.fromMap(uid, {
        'vipAtivo': true,
        'estado': 'estado_que_a_google_inventar',
        'expiraEm': futuro.toIso8601String(),
      });
      expect(e.estado, EstadoEntitlement.desconhecido);
      expect(e.vigenteEm(agora), isFalse);
    });

    test('FC-03 direito sem prazo nao concede', () {
      final e = EntitlementVip.fromMap(uid, {
        'vipAtivo': true,
        'estado': 'ativo',
        'expiraEm': null,
      });
      expect(e.vigenteEm(agora), isFalse);
    });

    test('FC-04 documento vazio ou ausente e "sem VIP", nao "talvez"', () {
      expect(EntitlementVip.fromMap(uid, null).vigenteEm(agora), isFalse);
      expect(EntitlementVip.fromMap(uid, const {}).vigenteEm(agora), isFalse);
      expect(temVipEm(uid, null, agora), isFalse);
    });

    test('FC-05 o uid do caminho vence o uid do corpo', () {
      // Documento copiado de outra pessoa nao passa a valer por causa do campo
      // que ele carrega dentro.
      final e = EntitlementVip.fromMap(uid, {
        'uid': 'outra-pessoa',
        'vipAtivo': true,
        'estado': 'ativo',
        'expiraEm': futuro.toIso8601String(),
      });
      expect(e.uid, uid);
    });

    test('FC-06 a vigencia exige relogio em UTC', () {
      final e = EntitlementVip.fromMap(uid, {
        'vipAtivo': true,
        'estado': 'ativo',
        'expiraEm': futuro.toIso8601String(),
      });
      expect(
        () => e.vigenteEm(DateTime(2026, 8, 11, 20)),
        throwsArgumentError,
      );
      expect(
        () => comporPerfil(userId: uid, agora: DateTime(2026, 8, 11, 20)),
        throwsArgumentError,
      );
    });

    test('FC-07 o exato instante do vencimento ja nao concede', () {
      final e = EntitlementVip.fromMap(uid, {
        'vipAtivo': true,
        'estado': 'ativo',
        'expiraEm': agora.toIso8601String(),
      });
      expect(e.vigenteEm(agora), isFalse);
      expect(
        e.vigenteEm(agora.subtract(const Duration(milliseconds: 1))),
        isTrue,
      );
    });
  });

  // =====================================================================
  // A COMPOSICAO EM SI
  // =====================================================================
  group('composicao', () {
    test('CP-01 as duas fontes entram no mesmo retrato', () {
      final perfil = comporPerfil(
        userId: uid,
        agora: agora,
        moderacao: documentoDeModeracao([
          sancao(
            tipo: TipoSancao.suspensaoTemporaria,
            fim: agora.add(const Duration(days: 1)),
          ),
        ]),
        entitlement: documentoDeEntitlement(
          vipAtivo: true,
          estado: EstadoEntitlement.ativo,
          expiraEm: futuro,
        ),
        convitesAtivos: const {'encerramento_anual'},
        titulos: const {'copa_buraco_master'},
      );

      expect(perfil.userId, uid);
      expect(perfil.suspenso, isTrue);
      expect(perfil.assinaturaAtiva, isTrue);
      expect(perfil.convitesAtivos, contains('encerramento_anual'));
      expect(perfil.titulos, contains('copa_buraco_master'));
    });

    test('CP-02 nivel, ranking e conquistas vem AUSENTES: nao ha produtor', () {
      // Declarado, e nao acidental. Enquanto ranking e nivel nao tiverem
      // autoridade que os publique, o criterio correspondente recusa por dado
      // indisponivel — que e o que o sistema ja fazia, agora explicito.
      final perfil = comporPerfil(userId: uid, agora: agora);
      expect(perfil.nivel, isNull);
      expect(perfil.posicaoRanking, isNull);
      expect(perfil.conquistas, isEmpty);

      final a = avaliarElegibilidade(
        criterios: [const CriterioElegibilidade(TipoCriterio.nivelMinimo, '5')],
        perfil: perfil,
        tournamentId: 'sexta_master_vip',
      );
      expect(a.principal!.recusa, RecusaElegibilidade.dadoIndisponivel);
    });

    test('CP-03 jogador limpo: sem sancao e sem compra', () {
      final perfil = comporPerfil(userId: uid, agora: agora);
      expect(perfil.suspenso, isFalse);
      expect(perfil.assinaturaAtiva, isFalse);
    });

    test('CP-04 documento de moderacao ilegivel derruba a operacao', () {
      // Nao ha "ignorar o que nao entendi": um estado de moderacao corrompido
      // que virasse `suspenso: false` liberaria justamente quem esta punido.
      expect(
        () => comporPerfil(
          userId: uid,
          agora: agora,
          moderacao: const {'suspensoAte': 'nao-e-uma-data'},
        ),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
