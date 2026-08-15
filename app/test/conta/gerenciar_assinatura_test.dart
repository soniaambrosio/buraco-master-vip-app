// gerenciar_assinatura_test.dart — o caminho até a tela de assinaturas da Play.
//
// OS de Conformidade de Exclusão de Conta, §7.
//
// Duas coisas são provadas aqui, e elas têm naturezas diferentes.
//
// A PRIMEIRA É LÓGICA: a tradução de `EntitlementVip` para
// `SituacaoDaAssinatura`, estado por estado — inclusive os três que NÃO dão
// acesso VIP e mesmo assim precisam do caminho para a loja, que é o caso que um
// booleano `ehVip` esconderia.
//
// A SEGUNDA É DE COERÊNCIA ENTRE ARQUIVOS: `kPacotePlayOficial` precisa ser o
// mesmo pacote que o workflow de release grava no AAB. Um pacote errado ali não
// quebra compilação nenhuma — produz um deep link morto que ninguém descobre
// até um assinante reclamar. É exatamente o tipo de divergência que só um teste
// que LÊ os dois arquivos pega.

import 'package:flutter_test/flutter_test.dart';

import 'package:buraco_master_vip/billing/gerenciar_assinatura.dart';
import 'package:buraco_master_vip/elegibilidade/entitlement.dart';

import 'raiz_do_repositorio.dart';

/// Um entitlement montado para o estado que se quer exercitar.
///
/// `expiraEm` no futuro por padrão porque a vigência é temporal: sem prazo, ou
/// com prazo vencido, `vigenteEm` recusa antes de olhar o estado — e o teste
/// mediria outra coisa que não o que se propôs a medir.
EntitlementVip entitlement(
  EstadoEntitlement estado, {
  bool vipAtivo = true,
  String? produtoId = 'master_vip_mensal',
  bool renovacaoAutomatica = true,
  Duration daquiA = const Duration(days: 10),
}) {
  return EntitlementVip(
    uid: 'u1',
    vipAtivo: vipAtivo,
    estado: estado,
    produtoId: produtoId,
    renovacaoAutomatica: renovacaoAutomatica,
    expiraEm: DateTime.utc(2026, 8, 15).add(daquiA),
  );
}

final DateTime agora = DateTime.utc(2026, 8, 15);

void main() {
  // =========================================================================
  // A SITUAÇÃO, ESTADO POR ESTADO
  // =========================================================================
  group('a situação derivada do entitlement', () {
    test('os três estados que concedem acesso são "vigente"', () {
      for (final estado in [
        EstadoEntitlement.ativo,
        EstadoEntitlement.emCarencia,
        EstadoEntitlement.canceladoVigente,
      ]) {
        final a = AssinaturaParaGerenciar.doEntitlement(
          entitlement(estado),
          agora,
        );
        expect(a.situacao, SituacaoDaAssinatura.vigente, reason: estado.wire);
        expect(a.ofereceGerenciamento, isTrue);
      }
    });

    test('sem acesso e ainda cobrável: em espera, pausado e pendente', () {
      // O CASO QUE ESTE ARQUIVO EXISTE PARA COBRIR. Quem está em
      // `SUBSCRIPTION_STATE_ON_HOLD` perdeu o VIP e a Google continua tentando
      // cobrar. Se a tela só oferecesse a loja a quem tem acesso, essa pessoa —
      // que é quem mais precisa dela — não veria botão nenhum, excluiria a
      // conta e continuaria pagando.
      for (final estado in [
        EstadoEntitlement.emEspera,
        EstadoEntitlement.pausado,
        EstadoEntitlement.pendente,
      ]) {
        final a = AssinaturaParaGerenciar.doEntitlement(
          entitlement(estado),
          agora,
        );
        expect(a.situacao, SituacaoDaAssinatura.gerenciavel, reason: estado.wire);
        expect(a.ofereceGerenciamento, isTrue);
      }
    });

    test('o que terminou não oferece gerenciamento', () {
      for (final estado in [
        EstadoEntitlement.nuncaTeve,
        EstadoEntitlement.expirado,
        EstadoEntitlement.revogado,
        EstadoEntitlement.reembolsado,
      ]) {
        final a = AssinaturaParaGerenciar.doEntitlement(
          entitlement(estado),
          agora,
        );
        expect(a.situacao, SituacaoDaAssinatura.nenhuma, reason: estado.wire);
        expect(a.ofereceGerenciamento, isFalse);
        // E o produto NÃO vaza para um estado que não oferece nada.
        expect(a.produtoId, isNull, reason: estado.wire);
      }
    });

    test('documento ausente não oferece nada', () {
      final a = AssinaturaParaGerenciar.doEntitlement(
        const EntitlementVip.ausente('u1'),
        agora,
      );
      expect(a.situacao, SituacaoDaAssinatura.nenhuma);
    });

    test('estado desconhecido cai no lado seguro: oferece a loja', () {
      // Mandar conferir na Play não concede direito nenhum e não cobra nada.
      // Silenciar poderia esconder uma cobrança — e um estado novo da
      // plataforma vai aparecer aqui um dia.
      final a = AssinaturaParaGerenciar.doEntitlement(
        entitlement(EstadoEntitlement.desconhecido),
        agora,
      );
      expect(a.situacao, SituacaoDaAssinatura.gerenciavel);
    });

    test('documento incoerente não concede VIP, mas ainda leva à loja', () {
      // `ativo` com `vipAtivo: false` é dado meio escrito. `vigenteEm` já
      // recusou o acesso; recusar TAMBÉM o caminho para a Play puniria duas
      // vezes por um defeito que não é do jogador.
      final a = AssinaturaParaGerenciar.doEntitlement(
        entitlement(EstadoEntitlement.ativo, vipAtivo: false),
        agora,
      );
      expect(a.situacao, SituacaoDaAssinatura.gerenciavel);
    });

    test('assinatura vencida pelo relógio não é vigente', () {
      final a = AssinaturaParaGerenciar.doEntitlement(
        entitlement(EstadoEntitlement.ativo, daquiA: const Duration(days: -1)),
        agora,
      );
      expect(a.situacao, isNot(SituacaoDaAssinatura.vigente));
    });

    test('produto fora do formato da Play não vira produto', () {
      // Um id inválido geraria um `sku` que a loja não reconhece — deep link
      // morto. Cortar aqui faz cair na central geral, que sempre funciona.
      final a = AssinaturaParaGerenciar.doEntitlement(
        entitlement(EstadoEntitlement.ativo, produtoId: 'Master VIP Mensal!'),
        agora,
      );
      expect(a.situacao, SituacaoDaAssinatura.vigente);
      expect(a.produtoId, isNull);
    });

    test('a renovação automática atravessa intacta', () {
      final ligada = AssinaturaParaGerenciar.doEntitlement(
        entitlement(EstadoEntitlement.ativo),
        agora,
      );
      final desligada = AssinaturaParaGerenciar.doEntitlement(
        entitlement(
          EstadoEntitlement.canceladoVigente,
          renovacaoAutomatica: false,
        ),
        agora,
      );
      expect(ligada.renovacaoAutomatica, isTrue);
      expect(desligada.renovacaoAutomatica, isFalse);
    });
  });

  // =========================================================================
  // O LINK
  // =========================================================================
  group('o link de gerenciamento', () {
    test('com produto e pacote, é o deep link do produto', () {
      final uri = linkDeGerenciamentoDeAssinatura(
        produtoId: 'master_vip_mensal',
      );
      expect(uri.scheme, 'https');
      expect(uri.host, 'play.google.com');
      expect(uri.path, '/store/account/subscriptions');
      expect(uri.queryParameters['sku'], 'master_vip_mensal');
      expect(uri.queryParameters['package'], kPacotePlayOficial);
    });

    test('sem produto, é a central geral', () {
      expect(
        linkDeGerenciamentoDeAssinatura().toString(),
        kCentralDeAssinaturasPlay,
      );
      expect(
        linkDeGerenciamentoDeAssinatura(produtoId: '   ').toString(),
        kCentralDeAssinaturasPlay,
      );
    });

    test('produto ou pacote fora do formato caem na central geral', () {
      // A regra da OS, literal: "se não for possível resolver com segurança a
      // assinatura específica, abrir a central geral".
      expect(
        linkDeGerenciamentoDeAssinatura(produtoId: 'VIP Mensal').toString(),
        kCentralDeAssinaturasPlay,
      );
      expect(
        linkDeGerenciamentoDeAssinatura(
          produtoId: 'master_vip_mensal',
          pacote: '',
        ).toString(),
        kCentralDeAssinaturasPlay,
      );
      expect(
        linkDeGerenciamentoDeAssinatura(
          produtoId: 'master_vip_mensal',
          pacote: 'Pacote Inválido',
        ).toString(),
        kCentralDeAssinaturasPlay,
      );
    });

    test('nunca devolve nulo, e sempre é a Play', () {
      // Não existe estado em que a resposta certa seja "não há para onde ir".
      for (final produto in <String?>[null, '', 'x', 'master_vip_mensal', '!!']) {
        final uri = linkDeGerenciamentoDeAssinatura(produtoId: produto);
        expect(uri.host, 'play.google.com');
        expect(uri.scheme, 'https');
      }
    });
  });

  // =========================================================================
  // COERÊNCIA COM O RESTO DO REPOSITÓRIO
  // =========================================================================
  group('o pacote oficial não foi inventado', () {
    test('kPacotePlayOficial é o BMV_APPLICATION_ID do workflow de release', () {
      final workflow = lerDaRaiz('.github/workflows/release-aab.yml');
      final achado =
          RegExp(r'BMV_APPLICATION_ID:\s*(\S+)').firstMatch(workflow);

      expect(
        achado,
        isNotNull,
        reason: 'release-aab.yml deixou de declarar BMV_APPLICATION_ID — o '
            'pacote do deep link perdeu a fonte contra a qual era conferido.',
      );
      expect(
        achado!.group(1),
        kPacotePlayOficial,
        reason: 'o pacote do deep link de assinatura divergiu do applicationId '
            'que vai no AAB. Um deep link com pacote errado abre uma tela de '
            'erro na Play, e nada neste repositório quebraria por causa disso.',
      );
    });

    test('o pacote respeita o formato de applicationId da Play', () {
      expect(kFormatoIdentificadorPlay.hasMatch(kPacotePlayOficial), isTrue);
    });
  });
}
