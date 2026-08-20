// comunicacao_test.dart — a AUTORIDADE de Comunicação Controlada V1.
//
// Cobre as seções 14.1 a 14.6 e as provas negativas da §15 da OS, no que é
// DECISÃO PURA. A divisão de trabalho entre as três suítes desta frente é a
// mesma que a fundação do chat já estabeleceu, e ela não é arbitrária:
//
//   AQUI (Dart puro) ......... o que é decidido: ambiente, catálogo, direito,
//                              ritmo, bloqueio, silêncio, evento de sistema.
//   firebase/testes/ ......... quem PODE LER e ESCREVER cada coleção. Quem
//                              prova isso é a regra do Firestore, não o Dart.
//   functions-moderacao/ ..... autenticação, transação, idempotência real e a
//     integracao.*.emulador     resolução do ambiente contra `salasPrivadas`.
//
// O NOME TERMINA EM `_test.dart` de propósito: os arquivos com prefixo `teste_`
// deste repositório ficam FORA do glob padrão do `flutter test` e só rodam
// porque o CI os nomeia um a um. Uma suíte nova nascer invisível seria começar
// com um defeito.

import 'package:buraco_master_vip/chat/porta.dart';
import 'package:buraco_master_vip/chat/superficie.dart';
import 'package:buraco_master_vip/comunicacao/ambiente.dart';
import 'package:buraco_master_vip/comunicacao/catalogo.dart';
import 'package:buraco_master_vip/comunicacao/evento.dart';
import 'package:buraco_master_vip/comunicacao/limites.dart';
import 'package:buraco_master_vip/comunicacao/porta.dart';
import 'package:buraco_master_vip/moderacao/relacao_social.dart';
import 'package:flutter_test/flutter_test.dart';

const autor = 'uidAutor';
const outro = 'uidOutro';
const terceiro = 'uidTerceiro';
const plateia = 'uidPlateia';
const publicIdDoAutor = 'BMV7K2MP4RC';

/// Um instante fixo. Nenhum teste desta suíte lê relógio: o domínio recebe
/// `agora`, e é essa disciplina que permite provar cooldown sem esperar.
final agora = DateTime.utc(2026, 8, 20, 12, 0, 0);

/// Direito VIP vigente, no formato de `playerEntitlements/{uid}`.
Map<String, Object?> vipVigente({DateTime? ate}) => {
      'vipAtivo': true,
      'estado': 'ativo',
      'expiraEm': (ate ?? agora.add(const Duration(days: 30))).toIso8601String(),
    };

/// Direito VENCIDO. Note `vipAtivo: true` com `expiraEm` no passado: é
/// exatamente o documento de quem cancelou e cujo período já acabou, e é o caso
/// que um `if (doc.vipAtivo)` erraria.
Map<String, Object?> vipVencido() => {
      'vipAtivo': true,
      'estado': 'cancelado_vigente',
      'expiraEm': agora.subtract(const Duration(days: 1)).toIso8601String(),
    };

CanalDeComunicacao canalDe({
  required AmbienteDeComunicacao ambiente,
  required ModoDeComunicacao modo,
  String canalId = 'sala7',
  List<String> outros = const [outro],
  List<String> espectadores = const [],
  bool aberto = true,
  bool autorPresente = true,
  bool autorEspectador = false,
}) {
  final papelDoAutor = ambiente.ehSaguao
      ? PapelNoCanal.presenteNoAmbiente
      : PapelNoCanal.jogadorSentado;
  final papelDosOutros = papelDoAutor;

  return CanalDeComunicacao(
    ambiente: ambiente,
    modo: modo,
    canal: CanalDeChat(
      canalId: canalId,
      superficie: superficieDe(ambiente),
      aberto: aberto,
      participantes: [
        if (autorPresente && !autorEspectador)
          ParticipanteDoCanal(uid: autor, papel: papelDoAutor),
        if (autorEspectador)
          const ParticipanteDoCanal(
              uid: autor, papel: PapelNoCanal.espectador),
        for (final u in outros) ParticipanteDoCanal(uid: u, papel: papelDosOutros),
        for (final u in espectadores)
          ParticipanteDoCanal(uid: u, papel: PapelNoCanal.espectador),
      ],
    ),
  );
}

VereditoComunicacao pedir({
  String autorUid = autor,
  String intentId = 'intent-1',
  Object? tipo = 'fala_catalogada',
  Object? itemId = 'elogiar_boa_jogada_01',
  Object? conteudo,
  CanalDeComunicacao? canal,
  SancaoDoAutor sancao = const SancaoDoAutor(),
  List<ParDeContato> contatos = const [],
  List<String> silenciaram = const [],
  List<String> campos = const [],
  String? publicId = publicIdDoAutor,
  Map<String, Object?>? entitlement,
  EstadoDeRitmo ritmo = const EstadoDeRitmo(),
  DateTime? quando,
  int versaoDoCliente = kVersaoDoCatalogo,
}) =>
    avaliarComunicacao(
      autorUid: autorUid,
      intentId: intentId,
      tipoPedido: tipo,
      itemIdPedido: itemId,
      conteudoBruto: conteudo,
      canal: canal ??
          canalDe(
            ambiente: AmbienteDeComunicacao.mesaPublica,
            modo: ModoDeComunicacao.apenasEmotes,
          ),
      sancao: sancao,
      agora: quando ?? agora,
      contatos: contatos,
      silenciaramOAutor: silenciaram,
      camposDoPayload: campos,
      autorPublicId: publicId,
      entitlementBruto: entitlement,
      ritmo: ritmo,
      versaoDeCatalogoDoCliente: versaoDoCliente,
    );

void main() {
  // =========================================================================
  // §2 — A MATRIZ CANÔNICA
  // =========================================================================
  //
  // A tabela inteira, num teste só. Ela é a decisão de produto congelada, e um
  // caso por ambiente espalhado pelo arquivo deixaria a matriz sem um lugar
  // onde ela apareça inteira — que é justamente onde se enxerga um buraco.
  group('MAT — a matriz do §2', () {
    test('MAT-01 texto livre existe em UM ambiente e um modo, e só', () {
      final comTexto = <String>[];
      for (final a in AmbienteDeComunicacao.values) {
        for (final m in ModoDeComunicacao.values) {
          if (permissaoDe(a, m).textoLivre) comTexto.add('${a.wire}/${m.wire}');
        }
      }
      expect(comTexto, ['mesa_privada/completo']);
    });

    test('MAT-02 os quatro ambientes controlados aceitam catálogo', () {
      for (final a in [
        AmbienteDeComunicacao.saguaoPublico,
        AmbienteDeComunicacao.salaoVip,
        AmbienteDeComunicacao.mesaPublica,
        AmbienteDeComunicacao.mesaVip,
      ]) {
        expect(permissaoDe(a, ModoDeComunicacao.apenasEmotes).catalogado, isTrue,
            reason: a.wire);
        expect(permissaoDe(a, ModoDeComunicacao.apenasEmotes).textoLivre, isFalse,
            reason: a.wire);
      }
    });

    test('MAT-03 Treino não tem comunicação nenhuma, em modo nenhum', () {
      for (final m in ModoDeComunicacao.values) {
        expect(permissaoDe(AmbienteDeComunicacao.treino, m).algumaCoisa, isFalse);
        expect(modoPermitidoNoAmbiente(AmbienteDeComunicacao.treino, m), isFalse);
      }
    });

    test('MAT-04 `completo` só pode ser CONFIGURADO na Mesa Privada', () {
      for (final a in AmbienteDeComunicacao.values) {
        expect(
          modoPermitidoNoAmbiente(a, ModoDeComunicacao.completo),
          a == AmbienteDeComunicacao.mesaPrivada,
          reason: a.wire,
        );
      }
    });

    test('MAT-05 `completo` gravado num ambiente errado NÃO vira texto livre',
        () {
      // A segunda tranca. A primeira (configuração) recusa; esta continua
      // fechada mesmo diante de um documento que já traga o valor errado.
      for (final a in [
        AmbienteDeComunicacao.mesaPublica,
        AmbienteDeComunicacao.mesaVip,
        AmbienteDeComunicacao.saguaoPublico,
        AmbienteDeComunicacao.salaoVip,
      ]) {
        expect(permissaoDe(a, ModoDeComunicacao.completo).textoLivre, isFalse,
            reason: a.wire);
      }
    });

    test('MAT-06 modo ausente ou desconhecido é lido como DESLIGADO', () {
      expect(modoPorWire(null), ModoDeComunicacao.desligado);
      expect(modoPorWire('completo_mesmo'), ModoDeComunicacao.desligado);
      expect(modoPorWire(42), ModoDeComunicacao.desligado);
    });

    test('MAT-07 a tradução dos tipos de mesa cobre os quatro, e só', () {
      expect(ambienteDeTipoDeMesa('publica'), AmbienteDeComunicacao.mesaPublica);
      expect(ambienteDeTipoDeMesa('vipRanqueada'), AmbienteDeComunicacao.mesaVip);
      expect(ambienteDeTipoDeMesa('privada'), AmbienteDeComunicacao.mesaPrivada);
      expect(ambienteDeTipoDeMesa('treino'), AmbienteDeComunicacao.treino);
      expect(ambienteDeTipoDeMesa('vip'), isNull);
      expect(ambienteDeTipoDeMesa(null), isNull);
    });

    test('MAT-08 `privada` x `vip_ranqueada` não resolve para ambiente nenhum',
        () {
      // Seria sala fechada alimentando o Ranking — a combinação que a taxonomia
      // dos tipos recusa desde a OS anterior.
      expect(
        ambienteDoServidor(
            tipoPartida: 'privada', categoriaCompetitiva: 'vip_ranqueada'),
        isNull,
      );
      expect(
        ambienteDoServidor(
            tipoPartida: 'privada', categoriaCompetitiva: 'casual'),
        AmbienteDeComunicacao.mesaPrivada,
      );
      expect(
        ambienteDoServidor(
            tipoPartida: 'publica', categoriaCompetitiva: 'vip_ranqueada'),
        AmbienteDeComunicacao.mesaVip,
      );
      expect(
        ambienteDoServidor(
            tipoPartida: 'simulada', categoriaCompetitiva: 'casual'),
        AmbienteDeComunicacao.treino,
      );
    });
  });

  // =========================================================================
  // §14.1 — AMBIENTES CONTROLADOS
  // =========================================================================
  group('CTR — ambientes controlados (§14.1)', () {
    test('CTR-01 Saguão Público aceita falaId válido', () {
      final v = pedir(
        itemId: 'convite_dupla_01',
        canal: canalDe(
          ambiente: AmbienteDeComunicacao.saguaoPublico,
          modo: ModoDeComunicacao.apenasEmotes,
        ),
      );
      expect(v.aceita, isTrue, reason: v.recusa);
      expect(v.itemId, 'convite_dupla_01');
      expect(v.chaveDeLocalizacao, 'comunicacao.fala.convite_dupla_01');
      expect(v.conteudo, isNull);
    });

    test('CTR-02 Saguão Público recusa texto livre', () {
      final v = pedir(
        tipo: 'texto_privado',
        itemId: null,
        conteudo: 'oi gente',
        canal: canalDe(
          ambiente: AmbienteDeComunicacao.saguaoPublico,
          modo: ModoDeComunicacao.apenasEmotes,
        ),
      );
      expect(v.aceita, isFalse);
      expect(v.recusa, 'textoLivreNaoPermitidoNoAmbiente');
    });

    test('CTR-03 Salão VIP aceita fala premium autorizada', () {
      final v = pedir(
        itemId: 'provocar_realeza_manda_01',
        canal: canalDe(
          ambiente: AmbienteDeComunicacao.salaoVip,
          modo: ModoDeComunicacao.apenasEmotes,
        ),
        entitlement: vipVigente(),
      );
      expect(v.aceita, isTrue, reason: v.recusa);
      expect(v.fallbackOficial, 'A realeza manda lembranças.');
    });

    test('CTR-04 Salão VIP recusa texto livre', () {
      final v = pedir(
        tipo: 'texto_privado',
        itemId: null,
        conteudo: 'boa noite, realeza',
        canal: canalDe(
          ambiente: AmbienteDeComunicacao.salaoVip,
          modo: ModoDeComunicacao.apenasEmotes,
        ),
        entitlement: vipVigente(),
      );
      expect(v.aceita, isFalse);
      expect(v.recusa, 'textoLivreNaoPermitidoNoAmbiente');
    });

    test('CTR-05 Mesa Pública aceita balão autorizado', () {
      final v = pedir(tipo: 'reacao_catalogada', itemId: 'reacao_aplauso_01');
      expect(v.aceita, isTrue, reason: v.recusa);
      expect(v.tipo, TipoDeComunicacao.reacaoCatalogada);
    });

    test('CTR-06 Mesa Pública recusa texto livre mesmo com modo `completo`', () {
      final v = pedir(
        tipo: 'texto_privado',
        itemId: null,
        conteudo: 'texto na mesa publica',
        canal: canalDe(
          ambiente: AmbienteDeComunicacao.mesaPublica,
          // O modo errado GRAVADO. Se a autoridade obedecesse ao documento em
          // vez da matriz, este caso passaria — e a §2 seria decorativa.
          modo: ModoDeComunicacao.completo,
        ),
      );
      expect(v.aceita, isFalse);
      expect(v.recusa, 'textoLivreNaoPermitidoNoAmbiente');
    });

    test('CTR-07 Mesa VIP aceita balão autorizado', () {
      final v = pedir(
        tipo: 'emoji_catalogado',
        itemId: 'emoji_joia_01',
        canal: canalDe(
          ambiente: AmbienteDeComunicacao.mesaVip,
          modo: ModoDeComunicacao.apenasEmotes,
        ),
      );
      expect(v.aceita, isTrue, reason: v.recusa);
    });

    test('CTR-08 Mesa VIP recusa texto livre mesmo com modo `completo`', () {
      final v = pedir(
        tipo: 'texto_privado',
        itemId: null,
        conteudo: 'sou vip, logo digito',
        canal: canalDe(
          ambiente: AmbienteDeComunicacao.mesaVip,
          modo: ModoDeComunicacao.completo,
        ),
        entitlement: vipVigente(),
      );
      expect(v.aceita, isFalse);
      expect(v.recusa, 'textoLivreNaoPermitidoNoAmbiente');
    });

    test('CTR-09 payload adulterado não altera o tipo do ambiente', () {
      // A prova negativa central da §15: mandar `ambiente`, `modo`, `tipoMesa`,
      // `isVip` ou `chatCompleto` no pedido RECUSA o pedido inteiro. Não é
      // "aceita e ignora": ignorar em silêncio deixaria o cliente adulterado
      // acreditando que a tentativa é inofensiva, e o log sem registro dela.
      for (final campo in [
        'ambiente',
        'modo',
        'tipoMesa',
        'chatCompleto',
        'isVip',
        'publicId',
        'autorUid',
        'papel',
        'espectador',
        'entitlement',
        'eventoId',
        'enviadaEm',
        'messageId',
        'roomId',
        'chaveDeLocalizacao',
        'fallbackOficial',
      ]) {
        final v = pedir(campos: [campo]);
        expect(v.aceita, isFalse, reason: campo);
        expect(v.recusa, 'payloadComCampoProibido', reason: campo);
        expect(v.camposProibidos, [campo]);
      }
    });

    test('CTR-10 fala inexistente é recusada', () {
      final v = pedir(itemId: 'fala_que_nunca_existiu_99');
      expect(v.aceita, isFalse);
      expect(v.recusa, 'itemDesconhecido');
    });

    test('CTR-11 fala desativada é recusada, e com motivo PRÓPRIO', () {
      final v = pedir(
        itemId: 'provocar_so_na_conversa_01',
        canal: canalDe(
          ambiente: AmbienteDeComunicacao.saguaoPublico,
          modo: ModoDeComunicacao.apenasEmotes,
        ),
      );
      expect(v.aceita, isFalse);
      // Distinto de `itemDesconhecido` de propósito: um diz "cliente
      // desatualizado", o outro diz "id inventado".
      expect(v.recusa, 'itemDesativado');
    });

    test('CTR-12 fala de outro ambiente é recusada', () {
      // `convite_dupla_01` vale nos saguões e não na mesa.
      final v = pedir(itemId: 'convite_dupla_01');
      expect(v.aceita, isFalse);
      expect(v.recusa, 'itemForaDoAmbiente');
    });

    test('CTR-13 item premium sem entitlement é recusado', () {
      final canal = canalDe(
        ambiente: AmbienteDeComunicacao.salaoVip,
        modo: ModoDeComunicacao.apenasEmotes,
      );
      for (final direito in <Map<String, Object?>?>[
        null,
        {},
        vipVencido(),
        {'vipAtivo': false, 'estado': 'ativo', 'expiraEm': '2099-01-01T00:00:00Z'},
        {'vipAtivo': true, 'estado': 'revogado', 'expiraEm': '2099-01-01T00:00:00Z'},
        {'vipAtivo': true, 'estado': 'ativo'},
      ]) {
        final v = pedir(
          itemId: 'provocar_realeza_manda_01',
          canal: canal,
          entitlement: direito,
        );
        expect(v.aceita, isFalse, reason: '$direito');
        expect(v.recusa, 'entitlementAusente', reason: '$direito');
      }
    });

    test('CTR-14 item premium autorizado funciona', () {
      final v = pedir(
        tipo: 'emoji_catalogado',
        itemId: 'emoji_coroa_01',
        canal: canalDe(
          ambiente: AmbienteDeComunicacao.mesaVip,
          modo: ModoDeComunicacao.apenasEmotes,
        ),
        entitlement: vipVigente(),
      );
      expect(v.aceita, isTrue, reason: v.recusa);
    });

    test('CTR-15 texto exibível no lugar do ID é recusado', () {
      // §6.2. Um campo de texto aceito "só para o fallback" seria texto livre
      // com outro nome — e aberto nos quatro ambientes que esta OS fecha.
      final comConteudo = pedir(conteudo: 'Boa jogada!');
      expect(comConteudo.aceita, isFalse);
      expect(comConteudo.recusa, 'textoNoLugarDoItem');

      for (final campo in ['texto', 'mensagem', 'frase', 'label', 'legenda']) {
        final v = pedir(campos: [campo]);
        expect(v.aceita, isFalse, reason: campo);
        expect(v.recusa, 'textoNoLugarDoItem', reason: campo);
      }
    });

    test('CTR-16 repetição abusiva sofre cooldown', () {
      // Três usos do mesmo item cabem na janela; o quarto não.
      var ritmo = const EstadoDeRitmo();
      var t = agora;
      for (var i = 0; i < 3; i++) {
        final v = pedir(
          intentId: 'intent-$i',
          tipo: 'emoji_catalogado',
          itemId: 'emoji_joia_01',
          ritmo: ritmo,
          quando: t,
        );
        expect(v.aceita, isTrue, reason: 'envio $i: ${v.recusa}');
        ritmo = v.proximoRitmo!;
        t = t.add(const Duration(seconds: 10));
      }
      final quarto = pedir(
        intentId: 'intent-3',
        tipo: 'emoji_catalogado',
        itemId: 'emoji_joia_01',
        ritmo: ritmo,
        quando: t,
      );
      expect(quarto.aceita, isFalse);
      expect(quarto.recusa, 'ritmoExcedido');
      expect(quarto.motivoDeRitmo, MotivoDeRitmo.repeticaoDoMesmoItem);
      expect(quarto.liberaEmMs, isNotNull);
    });

    test('CTR-17 retry idempotente não duplica: mesmo autor+intenção, mesmo id',
        () {
      final a = pedir(intentId: 'mesma-intencao');
      final b = pedir(intentId: 'mesma-intencao');
      expect(a.messageId, b.messageId);

      // E a IMPRESSÃO muda quando o pedido muda, para que a mesma intenção com
      // outro item não seja tratada como repetição.
      final c = pedir(intentId: 'mesma-intencao', itemId: 'elogiar_parceria_01');
      expect(c.messageId, a.messageId);
      expect(c.impressao, isNot(a.impressao));
    });

    test('CTR-18 rajada é limitada, e a limitação não depende do item', () {
      var ritmo = const EstadoDeRitmo();
      final itens = [
        'emoji_joia_01',
        'emoji_carta_01',
        'reacao_aplauso_01',
        'reacao_risada_01',
      ];
      var aceitos = 0;
      for (var i = 0; i < itens.length + 2; i++) {
        final item = itens[i % itens.length];
        final v = pedir(
          intentId: 'raj-$i',
          tipo: item.startsWith('emoji')
              ? 'emoji_catalogado'
              : 'reacao_catalogada',
          itemId: item,
          ritmo: ritmo,
          // Todos no MESMO instante: é isso que é rajada.
          quando: agora,
        );
        ritmo = v.proximoRitmo!;
        if (v.aceita) aceitos++;
      }
      // O teto de rajada é 5; a contagem não pode ser "todos".
      expect(aceitos, lessThan(itens.length + 2));
      expect(aceitos, lessThanOrEqualTo(ConfiguracaoDeRitmo.padrao.rajadaMaxima));
    });

    test('CTR-19 versão de catálogo do cliente antiga recusa item novo', () {
      final v = pedir(versaoDoCliente: 0);
      expect(v.aceita, isFalse);
      expect(v.recusa, 'versaoDeCatalogoInsuficiente');
    });
  });

  // =========================================================================
  // §14.2 — MESA PRIVADA
  // =========================================================================
  group('PRI — Mesa Privada (§14.2)', () {
    CanalDeComunicacao privada({
      ModoDeComunicacao modo = ModoDeComunicacao.completo,
      List<String> outros = const [outro],
      bool aberto = true,
      bool autorEspectador = false,
    }) =>
        canalDe(
          ambiente: AmbienteDeComunicacao.mesaPrivada,
          modo: modo,
          outros: outros,
          aberto: aberto,
          autorEspectador: autorEspectador,
        );

    VereditoComunicacao texto({
      CanalDeComunicacao? canal,
      Object? conteudo = 'boa jogada, parceiro',
      String autorUid = autor,
      SancaoDoAutor sancao = const SancaoDoAutor(),
      List<ParDeContato> contatos = const [],
      List<String> silenciaram = const [],
      String? publicId = publicIdDoAutor,
      EstadoDeRitmo ritmo = const EstadoDeRitmo(),
      DateTime? quando,
    }) =>
        pedir(
          autorUid: autorUid,
          tipo: 'texto_privado',
          itemId: null,
          conteudo: conteudo,
          canal: canal ?? privada(),
          sancao: sancao,
          contatos: contatos,
          silenciaram: silenciaram,
          publicId: publicId,
          ritmo: ritmo,
          quando: quando,
        );

    test('PRI-19 jogador sentado na Mesa Privada com chat completo envia texto',
        () {
      final v = texto();
      expect(v.aceita, isTrue, reason: v.recusa);
      expect(v.tipo, TipoDeComunicacao.textoPrivado);
      expect(v.conteudo, 'boa jogada, parceiro');
      expect(v.destinatarios, [outro]);
    });

    test('PRI-23 quem não está na sala é recusado', () {
      final v = texto(autorUid: 'uidDeFora');
      expect(v.aceita, isFalse);
      expect(v.recusa, 'papelSemDireitoDeFala');
    });

    test('PRI-24 espectador não envia texto', () {
      final v = texto(canal: privada(autorEspectador: true));
      expect(v.aceita, isFalse);
      expect(v.recusa, 'papelSemDireitoDeFala');
    });

    test('PRI-26 `chatCompleto` funciona quando autorizado', () {
      expect(texto(canal: privada(modo: ModoDeComunicacao.completo)).aceita,
          isTrue);
    });

    test('PRI-27 `somenteBaloes` recusa texto e aceita item', () {
      final semTexto = texto(canal: privada(modo: ModoDeComunicacao.apenasEmotes));
      expect(semTexto.aceita, isFalse);
      expect(semTexto.recusa, 'textoLivreNaoPermitidoNoAmbiente');

      final comItem = pedir(
        canal: privada(modo: ModoDeComunicacao.apenasEmotes),
        itemId: 'elogiar_parceria_01',
      );
      expect(comItem.aceita, isTrue, reason: comItem.recusa);
    });

    test('PRI-28 `desligado` recusa TODA comunicação de usuário', () {
      final canal = privada(modo: ModoDeComunicacao.desligado);
      final semTexto = texto(canal: canal);
      expect(semTexto.aceita, isFalse);
      expect(semTexto.recusa, 'ambienteSemComunicacao');

      final semItem = pedir(canal: canal, itemId: 'elogiar_parceria_01');
      expect(semItem.aceita, isFalse);
      expect(semItem.recusa, 'ambienteSemComunicacao');
    });

    test('PRI-29 texto vazio é recusado', () {
      for (final vazio in ['', '   ', ' '.trim()]) {
        final v = texto(conteudo: vazio);
        expect(v.aceita, isFalse, reason: '"$vazio"');
        expect(v.recusa, 'conteudoVazio', reason: '"$vazio"');
      }
    });

    test('PRI-30 texto excessivo é recusado', () {
      final v = texto(conteudo: 'a' * 301);
      expect(v.aceita, isFalse);
      expect(v.recusa, 'conteudoAcimaDoLimite');
    });

    test('PRI-31 caracteres de controle são recusados', () {
      for (final s in ['linha1\nlinha2', 'a b', 'a b', 'tab\there']) {
        final v = texto(conteudo: s);
        expect(v.aceita, isFalse, reason: s);
        expect(v.recusa, 'conteudoComCaractereDeControle', reason: s);
      }
    });

    test('PRI-32 remetente falso não muda o dono da mensagem', () {
      // O `messageId` deriva do UID AUTENTICADO. Dois autores com a mesma
      // intenção produzem ids diferentes, e nenhum deles é escolhido pelo
      // payload — `autorUid` no pedido cai na trava de campos proibidos.
      final meu = texto();
      final doOutro = pedir(
        autorUid: outro,
        tipo: 'texto_privado',
        itemId: null,
        conteudo: 'boa jogada, parceiro',
        canal: privada(outros: const [autor]),
      );
      expect(meu.messageId, isNot(doOutro.messageId));

      final comCampo = pedir(
        tipo: 'texto_privado',
        itemId: null,
        conteudo: 'oi',
        canal: privada(),
        campos: const ['autorUid'],
      );
      expect(comCampo.aceita, isFalse);
      expect(comCampo.recusa, 'payloadComCampoProibido');
    });

    test('PRI-33 sem identidade pública não há envio', () {
      for (final id in [null, '']) {
        final v = texto(publicId: id);
        expect(v.aceita, isFalse);
        expect(v.recusa, 'identidadePublicaAusente');
      }
    });

    test('PRI-36 sala encerrada (canal fechado) recusa mensagem nova', () {
      final v = texto(canal: privada(aberto: false));
      expect(v.aceita, isFalse);
      expect(v.recusa, 'canalFechado');
    });

    test('PRI-37 mesa sem mais ninguém sentado recusa: não se fala com parede',
        () {
      final v = texto(canal: privada(outros: const []));
      expect(v.aceita, isFalse);
      expect(v.recusa, 'semDestinatarios');
    });
  });

  // =========================================================================
  // §14.3 — BLOQUEIO E SILENCIAMENTO
  // =========================================================================
  group('BLQ — bloqueio e silêncio (§14.3)', () {
    test('BLQ-37 silenciar oculta para quem silenciou, e SÓ para ele', () {
      final v = pedir(
        canal: canalDe(
          ambiente: AmbienteDeComunicacao.mesaPublica,
          modo: ModoDeComunicacao.apenasEmotes,
          outros: const [outro, terceiro],
        ),
        silenciaram: const [outro],
      );
      expect(v.aceita, isTrue, reason: v.recusa);
      expect(v.destinatarios, [terceiro]);
      expect(v.silenciados, [outro]);
    });

    test('BLQ-38 silenciar NÃO pune o autor: a mensagem existe mesmo assim', () {
      // Todos silenciaram. A mensagem continua sendo aceita e gravada — recusar
      // aqui contaria ao autor que ele foi silenciado, que é o que a §9.1
      // proíbe. Compare com BLQ-40: bloqueio zerando a lista RECUSA.
      final v = pedir(
        canal: canalDe(
          ambiente: AmbienteDeComunicacao.mesaPublica,
          modo: ModoDeComunicacao.apenasEmotes,
          outros: const [outro, terceiro],
        ),
        silenciaram: const [outro, terceiro],
      );
      expect(v.aceita, isTrue, reason: v.recusa);
      expect(v.destinatarios, isEmpty);
      expect(v.silenciados, [outro, terceiro]);
    });

    test('BLQ-39 bloqueio filtra por PAR, não cala a mesa', () {
      final v = pedir(
        canal: canalDe(
          ambiente: AmbienteDeComunicacao.mesaPublica,
          modo: ModoDeComunicacao.apenasEmotes,
          outros: const [outro, terceiro],
        ),
        contatos: const [ParDeContato(uid: outro, bloqueouOAutor: true)],
      );
      expect(v.aceita, isTrue, reason: v.recusa);
      expect(v.destinatarios, [terceiro]);
    });

    test('BLQ-40 bloqueio nas DUAS direções suprime a comunicação', () {
      for (final par in const [
        ParDeContato(uid: outro, bloqueouOAutor: true),
        ParDeContato(uid: outro, autorBloqueou: true),
      ]) {
        final v = pedir(contatos: [par]);
        expect(v.aceita, isFalse);
        expect(v.recusa, 'contatoRecusado');
      }
    });

    test('BLQ-41 a recusa por bloqueio não diz QUEM bloqueou', () {
      final v = pedir(
        contatos: const [ParDeContato(uid: outro, bloqueouOAutor: true)],
      );
      final json = v.toJson().toString();
      expect(json.contains(outro), isFalse,
          reason: 'a recusa não pode nomear o outro jogador');
    });

    test('BLQ-42 sanção cala para o ambiente inteiro, não por par', () {
      final suspenso = pedir(sancao: const SancaoDoAutor(suspenso: true));
      expect(suspenso.recusa, 'suspensaoImpedeChat');

      final silenciado = pedir(sancao: const SancaoDoAutor(chatSilenciado: true));
      expect(silenciado.recusa, 'contatoRecusado');
      expect(silenciado.motivoContato,
          MotivoContatoRecusado.chatSilenciadoPorSancao);

      final restrito = pedir(sancao: const SancaoDoAutor(restricaoSocial: true));
      expect(restrito.motivoContato, MotivoContatoRecusado.restricaoSocial);
    });

    test('BLQ-47 evento de sistema atravessa bloqueio e silêncio', () {
      // §9.2: "preserva comandos necessários do sistema e do jogo". Quem
      // bloqueou alguém continua precisando saber que a sala foi encerrada.
      final v = avaliarEventoDeSistema(
        eventoIdPedido: 'sistema_sala_encerrada',
        canal: canalDe(
          ambiente: AmbienteDeComunicacao.mesaPrivada,
          modo: ModoDeComunicacao.completo,
          outros: const [outro, terceiro],
        ),
        intentId: 'evt-1',
        autoridadeConfirmada: true,
      );
      expect(v.aceita, isTrue, reason: v.recusa);
      expect(v.destinatarios, containsAll(<String>[autor, outro, terceiro]));
      expect(v.silenciados, isEmpty);
    });
  });

  // =========================================================================
  // §14.5 — EVENTOS DE SISTEMA
  // =========================================================================
  group('SIS — eventos de sistema (§14.5)', () {
    final canal = canalDe(
      ambiente: AmbienteDeComunicacao.mesaPublica,
      modo: ModoDeComunicacao.apenasEmotes,
    );

    test('SIS-61 evento real de presente é aceito, e não tem autor', () {
      final v = avaliarEventoDeSistema(
        eventoIdPedido: 'sistema_presente_disponivel',
        canal: canal,
        intentId: 'evt-presente',
        autoridadeConfirmada: true,
      );
      expect(v.aceita, isTrue, reason: v.recusa);
      expect(v.fallbackOficial, 'Pegue seu presente!');
      expect(v.toJson()['autorPublicId'], isNull);
    });

    test('SIS-62 usuário comum não fabrica evento de presente', () {
      // Dois caminhos, os dois fechados. (a) pedir o TIPO pela porta do
      // jogador; (b) chamar a porta do evento sem autoridade.
      final peloTipo = pedir(tipo: 'evento_de_sistema', itemId: null);
      expect(peloTipo.aceita, isFalse);
      expect(peloTipo.recusa, 'eventoDeSistemaSemAutoridade');

      final semAutoridade = avaliarEventoDeSistema(
        eventoIdPedido: 'sistema_presente_disponivel',
        canal: canal,
        intentId: 'evt-x',
      );
      expect(semAutoridade.aceita, isFalse);
      expect(semAutoridade.recusa, 'eventoDeSistemaSemAutoridade');
    });

    test('SIS-63 o jogador não fabrica selo, título nem texto de sistema', () {
      // O item do catálogo de EVENTOS não é alcançável pela porta do jogador,
      // nem mesmo com o tipo "certo": o catálogo consultado é outro.
      for (final tipo in [
        'fala_catalogada',
        'reacao_catalogada',
        'emoji_catalogado',
      ]) {
        final v = pedir(tipo: tipo, itemId: 'sistema_presente_disponivel');
        expect(v.aceita, isFalse, reason: tipo);
        expect(v.recusa, 'itemDesconhecido', reason: tipo);
      }
    });

    test('SIS-64 evento de sistema adulterado é recusado', () {
      final v = avaliarEventoDeSistema(
        eventoIdPedido: 'sistema_voce_ganhou_tudo',
        canal: canal,
        intentId: 'evt-y',
        autoridadeConfirmada: true,
      );
      expect(v.aceita, isFalse);
      expect(v.recusa, 'eventoDeSistemaDesconhecido');
    });

    test('SIS-65 o evento carrega SIGNIFICADO, não frase do remetente', () {
      final v = avaliarEventoDeSistema(
        eventoIdPedido: 'sistema_jogador_entrou',
        canal: canal,
        intentId: 'evt-z',
        autoridadeConfirmada: true,
      );
      expect(v.chaveDeLocalizacao, 'comunicacao.sistema.jogador_entrou');
      expect(v.toJson()['conteudo'], isNull);
    });

    test('SIS-66 todo item tem chave E fallback oficial', () {
      // §6.3: ausência de tradução usa fallback OFICIAL, nunca texto inventado
      // pelo remetente. Isso só é possível se todo item trouxer os dois.
      for (final i in catalogoV1) {
        expect(i.chaveDeLocalizacao.isNotEmpty, isTrue, reason: i.id);
        expect(i.fallbackOficial.isNotEmpty, isTrue, reason: i.id);
        expect(i.chaveDeLocalizacao.startsWith('comunicacao.'), isTrue,
            reason: i.id);
      }
      for (final e in catalogoDeEventosDeSistema) {
        expect(e.chaveDeLocalizacao.isNotEmpty, isTrue, reason: e.id);
        expect(e.fallbackOficial.isNotEmpty, isTrue, reason: e.id);
      }
    });

    test('SIS-67 evento fora do ambiente dele é recusado', () {
      final v = avaliarEventoDeSistema(
        // `sistema_jogador_entrou` é de mesa.
        eventoIdPedido: 'sistema_jogador_entrou',
        canal: canalDe(
          ambiente: AmbienteDeComunicacao.saguaoPublico,
          modo: ModoDeComunicacao.apenasEmotes,
        ),
        intentId: 'evt-w',
        autoridadeConfirmada: true,
      );
      expect(v.aceita, isFalse);
      expect(v.recusa, 'itemForaDoAmbiente');
    });

    test('SIS-68 Treino não recebe nem evento de sistema', () {
      final v = avaliarEventoDeSistema(
        eventoIdPedido: 'sistema_jogador_entrou',
        canal: canalDe(
          ambiente: AmbienteDeComunicacao.treino,
          modo: ModoDeComunicacao.desligado,
        ),
        intentId: 'evt-t',
        autoridadeConfirmada: true,
      );
      expect(v.aceita, isFalse);
    });
  });

  // =========================================================================
  // O CATÁLOGO E O RITMO, como objetos
  // =========================================================================
  group('CAT — o catálogo autoritativo (§6.2)', () {
    test('CAT-01 ids são únicos e estáveis no formato', () {
      final ids = <String>{};
      for (final i in catalogoV1) {
        expect(ids.add(i.id), isTrue, reason: 'id repetido: ${i.id}');
        expect(RegExp(r'^[a-z0-9_]+$').hasMatch(i.id), isTrue, reason: i.id);
      }
      for (final e in catalogoDeEventosDeSistema) {
        expect(ids.add(e.id), isTrue, reason: 'id repetido: ${e.id}');
      }
    });

    test('CAT-02 item premium não aparece no Saguão Público', () {
      for (final i in catalogoV1.where((i) => i.premium)) {
        expect(i.liberadoEm(AmbienteDeComunicacao.saguaoPublico), isFalse,
            reason: i.id);
      }
    });

    test('CAT-03 nenhum item é liberado no Treino', () {
      for (final i in catalogoV1) {
        expect(i.liberadoEm(AmbienteDeComunicacao.treino), isFalse, reason: i.id);
      }
    });

    test('CAT-04 as categorias aprovadas nos protótipos estão todas presentes',
        () {
      final categorias = catalogoV1.map((i) => i.categoria).toSet();
      expect(categorias, containsAll(CategoriaDeComunicacao.values));
    });

    test('CAT-05 item desativado carrega a data de desativação', () {
      for (final i in catalogoV1.where((i) => !i.ativo)) {
        expect(i.desativadoEm, isNotNull, reason: i.id);
      }
    });
  });

  group('RIT — o ritmo (§6.5)', () {
    test('RIT-01 o teto por janela recusa o excedente', () {
      var estado = const EstadoDeRitmo();
      final config = ConfiguracaoDeRitmo.padrao;
      var t = agora;
      var aceitos = 0;
      for (var i = 0; i < config.limitePorJanela + 5; i++) {
        final v = avaliarRitmo(
          config: config,
          estado: estado,
          agora: t,
          tipo: TipoDeComunicacao.textoPrivado,
        );
        estado = v.proximoEstado;
        if (v.permitido) aceitos++;
        // Espaçado o bastante para não cair na rajada nem no cooldown.
        t = t.add(const Duration(seconds: 2));
      }
      expect(aceitos, lessThanOrEqualTo(config.limitePorJanela));
    });

    test('RIT-02 recusas seguidas acionam o bloqueio temporário por abuso', () {
      var estado = const EstadoDeRitmo();
      final config = ConfiguracaoDeRitmo.padrao;
      var motivo;
      for (var i = 0; i < config.recusasParaBloquear + 1; i++) {
        final v = avaliarRitmo(
          config: config,
          estado: estado,
          agora: agora,
          tipo: TipoDeComunicacao.emojiCatalogado,
          categoria: CategoriaDeComunicacao.emoji,
          itemId: 'emoji_joia_01',
          cooldownDoItem: const Duration(seconds: 10),
        );
        estado = v.proximoEstado;
        motivo = v.motivo;
      }
      expect(motivo, MotivoDeRitmo.bloqueadoPorAbuso);
      expect(estado.bloqueadoAteMs, isNotNull);
    });

    test('RIT-03 o bloqueio em vigor recusa sem se renovar sozinho', () {
      final ate = agora.add(const Duration(minutes: 2)).millisecondsSinceEpoch;
      final estado = EstadoDeRitmo(bloqueadoAteMs: ate, recusasSeguidas: 4);
      final v = avaliarRitmo(
        config: ConfiguracaoDeRitmo.padrao,
        estado: estado,
        agora: agora,
        tipo: TipoDeComunicacao.textoPrivado,
      );
      expect(v.permitido, isFalse);
      expect(v.motivo, MotivoDeRitmo.bloqueadoPorAbuso);
      expect(v.proximoEstado.bloqueadoAteMs, ate,
          reason: 'insistir não pode empurrar o fim do bloqueio');
    });

    test('RIT-04 estado ilegível vira estado VAZIO, nunca restrição', () {
      for (final bruto in <Object?>[null, 'lixo', 42, {'recentes': 'x'}]) {
        final e = EstadoDeRitmo.fromJson(bruto);
        expect(e.recentes, isEmpty);
        expect(e.bloqueadoAteMs, isNull);
      }
    });

    test('RIT-05 o estado devolvido não guarda conteúdo de mensagem', () {
      final v = avaliarRitmo(
        config: ConfiguracaoDeRitmo.padrao,
        estado: const EstadoDeRitmo(),
        agora: agora,
        tipo: TipoDeComunicacao.textoPrivado,
      );
      final json = v.proximoEstado.toJson().toString();
      expect(json.contains('conteudo'), isFalse);
      expect(json.contains('texto'), isFalse);
    });
  });

  // =========================================================================
  // §11 — PRIVACIDADE DA RESPOSTA
  // =========================================================================
  group('PRV — o que a resposta NÃO carrega (§11)', () {
    test('PRV-01 o veredito aceito não expõe UID de terceiro fora da entrega',
        () {
      // `destinatarios` e `silenciados` existem no veredito porque o TRANSPORTE
      // precisa deles. O que esta suíte fixa é que nada ALÉM deles carrega UID:
      // a projeção pública é montada noutro lugar (functions-moderacao/src/
      // comunicacao.ts) e é lista de permissão.
      final v = pedir(
        canal: canalDe(
          ambiente: AmbienteDeComunicacao.mesaPublica,
          modo: ModoDeComunicacao.apenasEmotes,
          outros: const [outro, terceiro],
        ),
        silenciaram: const [terceiro],
      );
      final json = v.toJson();
      expect(json['destinatarios'], [outro]);
      expect(json['silenciados'], [terceiro]);
      json.remove('destinatarios');
      json.remove('silenciados');
      final resto = json.toString();
      for (final uid in [autor, outro, terceiro, plateia]) {
        expect(resto.contains(uid), isFalse, reason: uid);
      }
    });

    test('PRV-02 o messageId não deriva do UID de forma legível', () {
      final v = pedir();
      expect(v.messageId!.contains(autor), isFalse);
      expect(v.messageId!.length, 32);
    });
  });
}
