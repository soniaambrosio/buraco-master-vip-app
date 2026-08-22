// fundacao_torneios_v1_test.dart — a suite do gate `torneiobase`.
//
// O QUE ELA GUARDA: as decisoes CONGELADAS de Torneios V1, e o fato de que a
// fundacao que as declara nao ligou nada. As duas coisas juntas, porque cada
// uma sozinha e falsificavel: uma fundacao correta que alguem ligou a uma rota
// deixa de ser fundacao, e uma fundacao desligada que declara a decisao errada
// nao serve para sucessora nenhuma.
//
// SEM MOCK, SEM EMULADOR, SEM REDE. Os seeds reais entram por arquivo, pelo
// mesmo `test/suporte/seeds.dart` que as outras duas suites de torneios usam, e
// a auditoria estrutural le a arvore do disco.
//
// A AUDITORIA ESTRUTURAL DESCARTA LINHA DE COMENTARIO antes de procurar
// qualquer coisa. Um arquivo que documenta o que NAO faz cita, nos comentarios,
// exatamente os nomes que a auditoria caca — `tournamentJobs`, `check-in`,
// `carteira`. Buscar no texto cru faria a prova reprovar o arquivo por ele
// explicar a propria abstinencia.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:buraco_master_vip/elegibilidade/entitlement.dart';
import 'package:buraco_master_vip/torneios/annual_closing.dart';
import 'package:buraco_master_vip/torneios/eligibility.dart';
import 'package:buraco_master_vip/torneios/fundacao_v1.dart';
import 'package:buraco_master_vip/torneios/tournament_lifecycle.dart';
import 'package:buraco_master_vip/torneios/tournament_model.dart';

import '../suporte/seeds.dart';

// ---------------------------------------------------------------------------
// Localizacao de arquivos fora do pacote, FECHADA.
//
// `flutter test` roda com o diretorio corrente na raiz do pacote (`app/`
// localmente, `app_build/` no CI), e nos dois casos a raiz do repositorio e
// `..`. O terceiro candidato cobre uma invocacao a partir da raiz.
//
// Nao ha `if (!existe) return;` em lugar nenhum desta suite: um teste que
// desiste quando nao acha o arquivo fica VERDE justamente no caso em que
// alguem apagou o arquivo, que e o caso que ele existe para pegar.
// ---------------------------------------------------------------------------

File _naRaizDoRepo(String relativo) {
  const bases = ['..', '.'];
  final tentados = <String>[];
  for (final base in bases) {
    final caminho = '$base/$relativo';
    tentados.add(caminho);
    final arquivo = File(caminho);
    if (arquivo.existsSync()) return arquivo;
  }
  throw StateError(
    'arquivo do repositorio nao encontrado: $relativo\n'
    'diretorio corrente: ${Directory.current.path}\n'
    'caminhos tentados:\n  ${tentados.join('\n  ')}',
  );
}

/// O arquivo da fundacao, como ele esta no disco.
String get _fonteDaFundacao =>
    File('lib/torneios/fundacao_v1.dart').readAsStringSync();

/// O mesmo arquivo SEM as linhas de comentario.
String _semComentarios(String texto) => texto
    .split('\n')
    .where((l) => !l.trimLeft().startsWith('//'))
    .join('\n');

/// O codigo da fundacao sem os comentarios E sem a DECLARACAO DE LIMITES.
///
/// `kForaDaFundacaoV1` nomeia, em texto, exatamente as pecas que a V1 nao
/// entrega — `tournamentJobs`, check-in, carteira. Varrer o arquivo atras
/// desses nomes sem descontar a lista faria a prova reprovar o arquivo por ele
/// DECLARAR a propria abstinencia, que e o oposto do que ela quer medir.
///
/// O recorte falha alto se a lista sumir do arquivo: uma varredura que nao acha
/// o que veio descontar nao pode seguir como se tivesse descontado.
String _codigoForaDosLimitesDeclarados() {
  final codigo = _semComentarios(_fonteDaFundacao);
  const marca = 'const List<String> kForaDaFundacaoV1';
  final inicio = codigo.indexOf(marca);
  if (inicio < 0) {
    throw StateError('a declaracao de limites sumiu de fundacao_v1.dart');
  }
  final fim = codigo.indexOf('];', inicio);
  if (fim < 0) {
    throw StateError('a declaracao de limites nao fecha em fundacao_v1.dart');
  }
  return codigo.substring(0, inicio) + codigo.substring(fim + 2);
}

/// Todos os `.dart` de `lib/`, para as varreduras de consumidor.
List<File> _dartsDaBiblioteca() => Directory('lib')
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'))
    .toList();

// ---------------------------------------------------------------------------
// Leitura do catalogo real
// ---------------------------------------------------------------------------

Map<String, dynamic> get _seedCatalogo =>
    lerSeed('torneios', 'tournamentTemplates.seed.json');

/// `acesso` chega como string simples ou como objeto `{tipo, elegiveis}` — os
/// dois formatos existem no seed aprovado.
AcessoTorneio _acessoDe(Map<String, dynamic> bloco) {
  final bruto = bloco['acesso'];
  final wire = bruto is Map ? bruto['tipo'] as String? : bruto as String?;
  final acesso = AcessoTorneio.porWire(wire ?? '');
  if (acesso == null) {
    throw StateError('acesso desconhecido no seed: "$wire"');
  }
  return acesso;
}

List<Map<String, dynamic>> _templatesDoSeed() =>
    (_seedCatalogo['templates'] as List).cast<Map<String, dynamic>>();

// ---------------------------------------------------------------------------
// Fixtures de admissao
// ---------------------------------------------------------------------------

final DateTime _agora = DateTime.utc(2026, 8, 22, 12);

EntitlementVip _vip({
  String origem = 'play',
  bool ativo = true,
  EstadoEntitlement estado = EstadoEntitlement.ativo,
  DateTime? expiraEm,
}) =>
    EntitlementVip(
      uid: 'u1',
      vipAtivo: ativo,
      estado: estado,
      origem: origem,
      expiraEm: expiraEm ?? _agora.add(const Duration(days: 30)),
    );

PerfilElegibilidade _perfil({
  Set<String> convites = const {'copa_x'},
  bool suspenso = false,
}) =>
    PerfilElegibilidade(
      userId: 'u1',
      convitesAtivos: convites,
      suspenso: suspenso,
    );

RecusaAdmissaoV1? _admissao({
  AcessoTorneio acesso = AcessoTorneio.somenteConvidados,
  ParticipacaoV1 participacao = ParticipacaoV1.individual,
  PerfilElegibilidade? perfil,
  EntitlementVip? entitlement,
}) =>
    avaliarAdmissaoV1(
      tournamentId: 'copa_x',
      acesso: acesso,
      participacao: participacao,
      perfil: perfil ?? _perfil(),
      entitlement: entitlement ?? _vip(),
      agora: _agora,
    );

void main() {
  group('FV1-A — acesso: somente convidados, e os seeds superseded', () {
    test('FV1-A01 o acesso da V1 e `somente_convidados`, e so ele', () {
      expect(kAcessoTorneiosV1, AcessoTorneio.somenteConvidados);
      expect(kAcessoTorneiosV1.wire, 'somente_convidados');
    });

    test('FV1-A02 acesso publico e SUPERSEDED', () {
      expect(situacaoDoSeedV1(AcessoTorneio.publico), SituacaoSeedV1.superseded);
    });

    test('FV1-A03 acesso misto e SUPERSEDED', () {
      expect(situacaoDoSeedV1(AcessoTorneio.misto), SituacaoSeedV1.superseded);
    });

    test('FV1-A04 acesso somente_convidados e admitido', () {
      expect(
        situacaoDoSeedV1(AcessoTorneio.somenteConvidados),
        SituacaoSeedV1.admitido,
      );
    });

    test('FV1-A05 acesso vip nao e superseded, mas exige reemissao', () {
      expect(
        situacaoDoSeedV1(AcessoTorneio.vip),
        SituacaoSeedV1.reemissaoExigida,
      );
      expect(kAcessosSupersededV1.contains(AcessoTorneio.vip), isFalse);
    });

    test('FV1-A06 os superseded sao exatamente dois, e sao publico e misto', () {
      expect(kAcessosSupersededV1, {AcessoTorneio.publico, AcessoTorneio.misto});
    });

    test('FV1-A07 toda situacao de seed tem um wire proprio', () {
      final wires = SituacaoSeedV1.values.map((s) => s.wire).toSet();
      expect(wires.length, SituacaoSeedV1.values.length);
    });

    test('FV1-A08 no seed real, `quarta_vulnerabilidade` e SUPERSEDED', () {
      final t = _templatesDoSeed()
          .firstWhere((t) => t['templateId'] == 'quarta_vulnerabilidade');
      expect(_acessoDe(t), AcessoTorneio.publico);
      expect(situacaoDoSeedV1(_acessoDe(t)), SituacaoSeedV1.superseded);
    });

    test('FV1-A09 no seed real, `campeonato_mensal` e SUPERSEDED', () {
      final t = _templatesDoSeed()
          .firstWhere((t) => t['templateId'] == 'campeonato_mensal');
      expect(_acessoDe(t), AcessoTorneio.misto);
      expect(situacaoDoSeedV1(_acessoDe(t)), SituacaoSeedV1.superseded);
    });

    test('FV1-A10 no seed real, o evento de encerramento ja e admitido', () {
      final evento = _seedCatalogo['eventoEncerramento'] as Map<String, dynamic>;
      expect(_acessoDe(evento), AcessoTorneio.somenteConvidados);
      expect(situacaoDoSeedV1(_acessoDe(evento)), SituacaoSeedV1.admitido);
    });

    test('FV1-A11 nenhum template do catalogo serve a V1 sem reemissao', () {
      // A medida que importa para as sucessoras: os seis templates do catalogo
      // sao `publico`, `misto` ou `vip`, e NENHUM declara o acesso da V1. Quem
      // for criar edicao precisa reemitir ou receber um seed novo — nao existe
      // caminho em que um template de hoje entre na V1 como esta.
      final templates = _templatesDoSeed();
      expect(templates, isNotEmpty);
      final admitidos = templates
          .where((t) => situacaoDoSeedV1(_acessoDe(t)) == SituacaoSeedV1.admitido)
          .toList();
      expect(admitidos, isEmpty);
    });

    test('FV1-A12 todo template do seed cai em exatamente uma situacao', () {
      final templates = _templatesDoSeed();
      expect(templates.length, greaterThanOrEqualTo(6));
      for (final t in templates) {
        expect(SituacaoSeedV1.values, contains(situacaoDoSeedV1(_acessoDe(t))));
      }
    });
  });

  group('FV1-B — VIP integral: o presenteado nao concede acesso', () {
    test('FV1-B01 assinatura da Play vigente e VIP integral', () {
      expect(vipIntegralVigenteV1(_vip(origem: 'play'), _agora), isTrue);
    });

    test('FV1-B02 assinatura migrada do legado e VIP integral', () {
      expect(
        vipIntegralVigenteV1(_vip(origem: 'legado_usuarios'), _agora),
        isTrue,
      );
    });

    test('FV1-B03 origem `administrativa` NAO e VIP integral', () {
      // E sob esta origem que um VIP presenteado seria escrito. Ela esta
      // documentada em entitlement.dart e nao tem produtor nesta arvore.
      expect(vipIntegralVigenteV1(_vip(origem: 'administrativa'), _agora),
          isFalse);
    });

    test('FV1-B04 origem desconhecida recusa, em vez de conceder', () {
      expect(vipIntegralVigenteV1(_vip(origem: 'cortesia'), _agora), isFalse);
      expect(vipIntegralVigenteV1(_vip(origem: 'desconhecida'), _agora), isFalse);
    });

    test('FV1-B05 as origens integrais sao exatamente duas', () {
      expect(kOrigensVipIntegralV1, {'play', 'legado_usuarios'});
    });

    test('FV1-B06 documento ausente nao concede', () {
      expect(
        vipIntegralVigenteV1(const EntitlementVip.ausente('u1'), _agora),
        isFalse,
      );
    });

    test('FV1-B07 origem certa e prazo vencido nao concede', () {
      final vencido = _vip(expiraEm: _agora.subtract(const Duration(days: 1)));
      expect(vipIntegralVigenteV1(vencido, _agora), isFalse);
    });

    test('FV1-B08 origem certa e estado revogado nao concede', () {
      final revogado = _vip(estado: EstadoEntitlement.revogado);
      expect(vipIntegralVigenteV1(revogado, _agora), isFalse);
    });

    test('FV1-B09 a vigencia continua sendo de EntitlementVip, nao daqui', () {
      // Se esta camada tivesse a propria conta de prazo, um documento com
      // `vipAtivo: false` e prazo no futuro passaria. Ele nao passa porque quem
      // decide e `vigenteEm`.
      final inativo = _vip(ativo: false);
      expect(inativo.vigenteEm(_agora), isFalse);
      expect(vipIntegralVigenteV1(inativo, _agora), isFalse);
    });

    test('FV1-B10 as colecoes do passe de cortesia estao fora da admissao', () {
      expect(kColecoesForaDaAdmissaoV1, {'playerCourtesyPass', 'passesVip'});
    });

    test('FV1-B11 a admissao recusa o presenteado por `sem_vip_integral`', () {
      expect(
        _admissao(entitlement: _vip(origem: 'administrativa')),
        RecusaAdmissaoV1.semVipIntegral,
      );
    });

    test('FV1-B12 convite e VIP integral juntos admitem', () {
      expect(_admissao(), isNull);
    });

    test('FV1-B13 convite sem VIP integral nao admite', () {
      expect(
        _admissao(entitlement: const EntitlementVip.ausente('u1')),
        RecusaAdmissaoV1.semVipIntegral,
      );
    });

    test('FV1-B14 VIP integral sem convite nao admite', () {
      expect(
        _admissao(perfil: _perfil(convites: const {})),
        RecusaAdmissaoV1.semConvite,
      );
    });

    test('FV1-B15 convite de OUTRO torneio nao vale para este', () {
      expect(
        _admissao(perfil: _perfil(convites: const {'copa_y'})),
        RecusaAdmissaoV1.semConvite,
      );
    });

    test('FV1-B16 acesso fora do recorte reprova antes de olhar a pessoa', () {
      expect(
        _admissao(acesso: AcessoTorneio.publico),
        RecusaAdmissaoV1.acessoNaoSuportado,
      );
      expect(
        _admissao(acesso: AcessoTorneio.vip),
        RecusaAdmissaoV1.acessoNaoSuportado,
      );
    });

    test('FV1-B17 suspenso nao entra, mesmo com convite e VIP integral', () {
      expect(_admissao(perfil: _perfil(suspenso: true)),
          RecusaAdmissaoV1.suspenso);
    });

    test('FV1-B18 a admissao exige instante em UTC', () {
      expect(
        () => avaliarAdmissaoV1(
          tournamentId: 'copa_x',
          acesso: AcessoTorneio.somenteConvidados,
          participacao: ParticipacaoV1.individual,
          perfil: _perfil(),
          entitlement: _vip(),
          agora: DateTime(2026, 8, 22),
        ),
        throwsArgumentError,
      );
    });
  });

  group('FV1-C — participacao individual, dupla dormente', () {
    test('FV1-C01 a participacao vigente na V1 e individual', () {
      expect(kParticipacaoTorneiosV1, ParticipacaoV1.individual);
      expect(kParticipacaoTorneiosV1.vigenteNaV1, isTrue);
    });

    test('FV1-C02 dupla esta declarada e NAO vigente', () {
      expect(ParticipacaoV1.values, contains(ParticipacaoV1.dupla));
      expect(ParticipacaoV1.dupla.vigenteNaV1, isFalse);
    });

    test('FV1-C03 a admissao em dupla recusa por dormencia', () {
      expect(
        _admissao(participacao: ParticipacaoV1.dupla),
        RecusaAdmissaoV1.participacaoDormente,
      );
    });

    test('FV1-C04 a dormencia reprova antes do convite e do VIP', () {
      // Se a ordem fosse outra, um pedido em dupla de quem nao tem convite
      // voltaria como "sem convite" — e a sucessora que ligar duplas
      // procuraria o defeito no lugar errado.
      expect(
        _admissao(
          participacao: ParticipacaoV1.dupla,
          perfil: _perfil(convites: const {}),
          entitlement: const EntitlementVip.ausente('u1'),
        ),
        RecusaAdmissaoV1.participacaoDormente,
      );
    });

    test('FV1-C05 os wires de participacao sao estaveis', () {
      expect(ParticipacaoV1.individual.wire, 'individual');
      expect(ParticipacaoV1.dupla.wire, 'dupla');
      expect(ParticipacaoV1.porWire('dupla'), ParticipacaoV1.dupla);
      expect(ParticipacaoV1.porWire('parceria'), isNull);
    });

    test('FV1-C06 todo template do seed ja declara participacao individual', () {
      final templates = _templatesDoSeed();
      expect(templates, isNotEmpty);
      for (final t in templates) {
        expect(t['participacao'], 'individual', reason: '${t['templateId']}');
      }
    });
  });

  group('FV1-D — ciclo editorial rascunho -> em_revisao -> agendado', () {
    RecusaEditorialV1? mover(
      EstadoEditorialV1 de,
      EstadoEditorialV1 para, {
      AtorTransicao ator = AtorTransicao.administracao,
      String criadoPor = 'admin_a',
      String? aprovadoPor = 'admin_b',
    }) =>
        avaliarTransicaoEditorialV1(
          de: de,
          para: para,
          ator: ator,
          criadoPor: criadoPor,
          aprovadoPor: aprovadoPor,
        );

    test('FV1-D01 rascunho avanca para em_revisao', () {
      expect(
        mover(EstadoEditorialV1.rascunho, EstadoEditorialV1.emRevisao),
        isNull,
      );
    });

    test('FV1-D02 em_revisao avanca para agendado', () {
      expect(
        mover(EstadoEditorialV1.emRevisao, EstadoEditorialV1.agendado),
        isNull,
      );
    });

    test('FV1-D03 rascunho NAO pula a revisao', () {
      expect(
        mover(EstadoEditorialV1.rascunho, EstadoEditorialV1.agendado),
        RecusaEditorialV1.transicaoInexistente,
      );
    });

    test('FV1-D04 agendado nao tem saida neste ciclo', () {
      for (final destino in EstadoEditorialV1.values) {
        expect(
          mover(EstadoEditorialV1.agendado, destino),
          RecusaEditorialV1.transicaoInexistente,
          reason: 'agendado -> ${destino.wire}',
        );
      }
    });

    test('FV1-D05 a devolucao para rascunho nao foi congelada, e recusa', () {
      expect(
        mover(EstadoEditorialV1.emRevisao, EstadoEditorialV1.rascunho),
        RecusaEditorialV1.transicaoInexistente,
      );
    });

    test('FV1-D06 nenhum estado transita para si mesmo', () {
      for (final estado in EstadoEditorialV1.values) {
        expect(
          mover(estado, estado),
          RecusaEditorialV1.transicaoInexistente,
          reason: estado.wire,
        );
      }
    });

    test('FV1-D07 a automacao nao move edicao', () {
      expect(
        mover(EstadoEditorialV1.rascunho, EstadoEditorialV1.emRevisao,
            ator: AtorTransicao.sistema),
        RecusaEditorialV1.atorNaoAdministrativo,
      );
    });

    test('FV1-D08 o jogador nao move edicao', () {
      expect(
        mover(EstadoEditorialV1.emRevisao, EstadoEditorialV1.agendado,
            ator: AtorTransicao.jogador),
        RecusaEditorialV1.atorNaoAdministrativo,
      );
    });

    test('FV1-D09 criador vazio nao passa nem na submissao', () {
      expect(
        mover(EstadoEditorialV1.rascunho, EstadoEditorialV1.emRevisao,
            criadoPor: '   '),
        RecusaEditorialV1.identificadorVazio,
      );
    });

    test('FV1-D10 o mapa de transicoes cobre os tres estados', () {
      expect(kTransicoesEditoriaisV1.keys.toSet(),
          EstadoEditorialV1.values.toSet());
    });

    test('FV1-D11 os wires do ciclo sao os da decisao congelada', () {
      expect(
        EstadoEditorialV1.values.map((e) => e.wire).toList(),
        ['rascunho', 'em_revisao', 'agendado'],
      );
    });

    test('FV1-D12 o ciclo entrega a edicao para EdicaoStatus, sem duplicar', () {
      expect(EstadoEditorialV1.rascunho.equivalentePublico,
          EdicaoStatus.rascunho);
      expect(EstadoEditorialV1.agendado.equivalentePublico,
          EdicaoStatus.agendado);
      // `em_revisao` e o estado que a vida publica NAO tem: e por isso que ele
      // precisou existir aqui.
      expect(EstadoEditorialV1.emRevisao.equivalentePublico, isNull);
    });
  });

  group('FV1-E — criador e aprovador sao administradores distintos', () {
    RecusaEditorialV1? aprovar(String criador, String? aprovador) =>
        avaliarTransicaoEditorialV1(
          de: EstadoEditorialV1.emRevisao,
          para: EstadoEditorialV1.agendado,
          ator: AtorTransicao.administracao,
          criadoPor: criador,
          aprovadoPor: aprovador,
        );

    test('FV1-E01 dois administradores distintos aprovam', () {
      expect(aprovar('admin_a', 'admin_b'), isNull);
    });

    test('FV1-E02 o criador nao aprova a propria edicao', () {
      expect(aprovar('admin_a', 'admin_a'),
          RecusaEditorialV1.aprovadorIgualAoCriador);
    });

    test('FV1-E03 aprovacao sem aprovador declarado recusa', () {
      expect(aprovar('admin_a', null), RecusaEditorialV1.aprovadorAusente);
    });

    test('FV1-E04 aprovador vazio recusa', () {
      expect(aprovar('admin_a', '   '), RecusaEditorialV1.aprovadorAusente);
    });

    test('FV1-E05 espaco nas bordas nao cria um segundo administrador', () {
      expect(aprovar('admin_a', '  admin_a  '),
          RecusaEditorialV1.aprovadorIgualAoCriador);
    });

    test('FV1-E06 a submissao NAO exige aprovador', () {
      // A separacao vale onde ha aprovacao. Exigi-la na submissao inventaria um
      // segundo papel que a decisao congelada nao criou.
      expect(
        avaliarTransicaoEditorialV1(
          de: EstadoEditorialV1.rascunho,
          para: EstadoEditorialV1.emRevisao,
          ator: AtorTransicao.administracao,
          criadoPor: 'admin_a',
        ),
        isNull,
      );
    });

    test('FV1-E07 a recusa por transicao vem antes da recusa por aprovador', () {
      expect(
        avaliarTransicaoEditorialV1(
          de: EstadoEditorialV1.rascunho,
          para: EstadoEditorialV1.agendado,
          ator: AtorTransicao.administracao,
          criadoPor: 'admin_a',
          aprovadoPor: 'admin_a',
        ),
        RecusaEditorialV1.transicaoInexistente,
      );
    });
  });

  group('FV1-F — Hall: nenhuma candidatura orfa', () {
    test('FV1-F01 edicao sem conclusao nao gera candidatura', () {
      expect(
        avaliarCandidaturaHallV1(
          editionId: 'ed_1',
          userId: 'u1',
          edicaoConcluida: false,
          origem: OrigemClassificacaoAnual.campeaoEdicao,
        ),
        RecusaCandidaturaHallV1.edicaoSemConclusao,
      );
    });

    test('FV1-F02 edicao concluida com origem declarada gera candidatura', () {
      expect(
        avaliarCandidaturaHallV1(
          editionId: 'ed_1',
          userId: 'u1',
          edicaoConcluida: true,
          origem: OrigemClassificacaoAnual.campeaoEdicao,
        ),
        isNull,
      );
    });

    test('FV1-F03 candidatura sem origem declarada recusa', () {
      expect(
        avaliarCandidaturaHallV1(
          editionId: 'ed_1',
          userId: 'u1',
          edicaoConcluida: true,
          origem: null,
        ),
        RecusaCandidaturaHallV1.origemDesconhecida,
      );
    });

    test('FV1-F04 edicao sem identificador recusa', () {
      expect(
        avaliarCandidaturaHallV1(
          editionId: '  ',
          userId: 'u1',
          edicaoConcluida: true,
          origem: OrigemClassificacaoAnual.campeaoEdicao,
        ),
        RecusaCandidaturaHallV1.identificadorVazio,
      );
    });

    test('FV1-F05 jogador sem identificador recusa', () {
      expect(
        avaliarCandidaturaHallV1(
          editionId: 'ed_1',
          userId: '',
          edicaoConcluida: true,
          origem: OrigemClassificacaoAnual.campeaoEdicao,
        ),
        RecusaCandidaturaHallV1.identificadorVazio,
      );
    });

    test('FV1-F06 a orfandade e recusada antes da origem ausente', () {
      expect(
        avaliarCandidaturaHallV1(
          editionId: 'ed_1',
          userId: 'u1',
          edicaoConcluida: false,
          origem: null,
        ),
        RecusaCandidaturaHallV1.edicaoSemConclusao,
      );
    });

    test('FV1-F07 toda origem conhecida serve de motivo', () {
      expect(OrigemClassificacaoAnual.values, isNotEmpty);
      for (final origem in OrigemClassificacaoAnual.values) {
        expect(
          avaliarCandidaturaHallV1(
            editionId: 'ed_1',
            userId: 'u1',
            edicaoConcluida: true,
            origem: origem,
          ),
          isNull,
          reason: origem.toString(),
        );
      }
    });
  });

  group('FV1-G — auditoria estrutural: zero autoridade produtiva', () {
    test('FV1-G01 a fundacao e camada pura: sem Flutter, sem Firestore, sem IO',
        () {
      final codigo = _semComentarios(_fonteDaFundacao);
      expect(codigo, isNotEmpty);
      for (final proibido in const [
        'package:flutter',
        'cloud_firestore',
        'FirebaseFirestore',
        'dart:io',
        'firebase_',
      ]) {
        expect(codigo.contains(proibido), isFalse, reason: proibido);
      }
    });

    test('FV1-G02 a fundacao nao toca nenhuma peca fora do recorte', () {
      // Os nomes aparecem nos COMENTARIOS e na DECLARACAO DE LIMITES, que
      // existem para dizer que cada peca esta de fora. A prova e sobre o resto.
      final codigo = _codigoForaDosLimitesDeclarados();
      expect(codigo, isNotEmpty);
      for (final proibido in const [
        'tournamentJobs',
        'wallets',
        'registrations',
        'checkin',
        'onCall',
        'onSchedule',
      ]) {
        expect(codigo.contains(proibido), isFalse, reason: proibido);
      }
    });

    test('FV1-G02b o desconto da lista de limites e estreito', () {
      // Controle da prova acima: o recorte tira A LISTA, e nao o arquivo. Se
      // ele passasse a devolver quase nada, `FV1-G02` ficaria verde por vazio.
      final inteiro = _semComentarios(_fonteDaFundacao);
      final recortado = _codigoForaDosLimitesDeclarados();
      expect(recortado.length, greaterThan((inteiro.length * 0.9).round()));
      expect(recortado.contains('avaliarAdmissaoV1'), isTrue);
      expect(inteiro.contains('tournamentJobs'), isTrue);
    });

    test('FV1-G03 nenhum arquivo de producao consome a fundacao ainda', () {
      // A fundacao NAO tem consumidor, e e isso que a mantem fundacao. Quando
      // uma sucessora a ligar, este caso vira vermelho e a ligacao passa a ser
      // uma decisao escrita no diff, em vez de um efeito colateral.
      final darts = _dartsDaBiblioteca();
      expect(darts.length, greaterThan(100),
          reason: 'a varredura nao enxergou a arvore — verde por vazio');
      final consumidores = darts
          .where((f) => !f.path.replaceAll(r'\', '/').endsWith(
              'lib/torneios/fundacao_v1.dart'))
          .where((f) => _semComentarios(f.readAsStringSync())
              .contains('torneios/fundacao_v1.dart'))
          .map((f) => f.path)
          .toList();
      expect(consumidores, isEmpty);
    });

    test('FV1-G04 a superficie de deploy do codebase de torneios nao mudou', () {
      // Sete `export const` em functions/src/index.ts. A fundacao nao acrescenta
      // Cloud Function nenhuma, e este numero e o mesmo que `rankingfn PF-01`
      // guarda do outro lado.
      final index = _naRaizDoRepo('functions/src/index.ts').readAsStringSync();
      final exports =
          RegExp(r'^export const ', multiLine: true).allMatches(index).length;
      expect(exports, 7);
    });

    test('FV1-G05 os limites da V1 estao declarados, e sao dez', () {
      expect(kForaDaFundacaoV1.length, 10);
      for (final limite in const [
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
      ]) {
        expect(kForaDaFundacaoV1, contains(limite));
      }
    });

    test('FV1-G06 `torneiobase` esta na fonte unica, com contrato e produtor',
        () {
      final fonte =
          _naRaizDoRepo('scripts/ci/gates_os_integracao.txt').readAsStringSync();
      expect(
        RegExp(r'^torneiobase$', multiLine: true).hasMatch(fonte),
        isTrue,
        reason: 'torneiobase saiu da fonte unica — o agregador para de percorre-lo',
      );
      for (final atributo in const [
        'suite      app/test/torneios/fundacao_torneios_v1_test.dart',
        'executor   roda torneiobase test/torneios/fundacao_torneios_v1_test.dart',
      ]) {
        expect(fonte, contains(atributo), reason: atributo);
      }

      final workflow =
          _naRaizDoRepo('.github/workflows/ci-os-integracao.yml').readAsStringSync();
      expect(
        workflow.contains(
            'roda torneiobase  test/torneios/fundacao_torneios_v1_test.dart'),
        isTrue,
        reason: 'o workflow deixou de executar a suite deste gate',
      );
    });

    test('FV1-G07 a versao do recorte esta declarada', () {
      expect(kVersaoFundacaoTorneiosV1, 1);
    });
  });
}
