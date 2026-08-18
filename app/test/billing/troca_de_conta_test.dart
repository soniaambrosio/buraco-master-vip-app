// troca_de_conta_test.dart — os casos H e I da OS de homologacao comercial:
// LOGOUT e TROCA DE CONTA (A -> B).
//
// O QUE ESTA SENDO PROTEGIDO
//
// `ServicoBilling` guarda o ultimo `EntitlementVip` recebido dentro de
// `PainelBilling`, e a interface le VIP dali (`mostrarComoVip`). Esse retrato e
// de UM jogador. Se ele sobreviver a saida da conta, o proximo jogador a entrar
// no mesmo processo aparece como VIP sem ter direito nenhum — e o direito dele
// so seria corrigido quando o primeiro `snapshot` de `playerEntitlements/{uid}`
// chegasse, o que depende de rede.
//
// A janela nao e teorica: `EntitlementRepositorio.observar(uid)` e um
// `snapshots()`, e o primeiro evento de uma escuta nova NAO e sincrono. Entre o
// login de B e esse primeiro evento existe um intervalo em que a unica fonte da
// interface e o valor que ficou de A.
//
// A OS proibe isso em termos explicitos: "B nao pode herdar o estado VIP de A
// pelo cache Flutter" (secao 28). Este arquivo prova a invariante nos dois
// caminhos pelos quais uma sessao termina no cliente:
//
//   1. o desligamento do servico (`encerrar`), que e o que um logout dispara;
//   2. a substituicao explicita do direito por `EntitlementVip.ausente`, que e
//      o que a camada de ligacao deve fazer ao descobrir o novo uid.
//
// NAO ha producao alterada por este arquivo. Ele fixa por teste um contrato que
// ja existe no codigo e que, ate aqui, nenhuma suite cobria — a lacuna que a
// homologacao encontrou.

import 'package:buraco_master_vip/billing/catalogo.dart';
import 'package:buraco_master_vip/billing/estado_ui.dart';
import 'package:buraco_master_vip/billing/servico_billing.dart';
import 'package:buraco_master_vip/billing/sessao.dart';
import 'package:buraco_master_vip/billing/validacao.dart';
import 'package:buraco_master_vip/elegibilidade/entitlement.dart';
import 'package:flutter_test/flutter_test.dart';

import 'apoio/dubles.dart';

const _catalogoDeTeste = CatalogoBilling(
  assinaturas: <String>{'assinatura.de.teste'},
);

const _uidA = 'jogador-A';
const _uidB = 'jogador-B';
final _agora = DateTime.utc(2026, 8, 12, 12);

/// O direito VIP de A, como o backend o grava.
EntitlementVip _vipDe(String uid) => EntitlementVip(
      uid: uid,
      vipAtivo: true,
      estado: EstadoEntitlement.ativo,
      origem: 'play',
      expiraEm: _agora.add(const Duration(days: 30)),
    );

ServicoBilling _montar({String? uid = _uidA}) => ServicoBilling(
      loja: LojaPlayFalsa(estaDisponivel: true),
      validador: ValidadorRoteirizado((_) => const ResultadoValidacao(aprovada: true)),
      sessao: SessaoFixa(uid),
      catalogo: _catalogoDeTeste,
      registrador: (_) {},
    );

void main() {
  // =========================================================================
  group('HOMOLOG-H — logout nao deixa o VIP aceso', () {
    test('encerrar() apaga o direito que estava no painel', () async {
      final servico = _montar();
      addTearDown(servico.descartar);
      await servico.iniciar();

      servico.atualizarEntitlement(_vipDe(_uidA));
      expect(servico.estado.mostrarComoVip(_agora), isTrue,
          reason: 'pre-condicao: A e VIP enquanto a sessao dele esta aberta');

      // O logout desliga o servico.
      await servico.encerrar();

      expect(servico.estado.mostrarComoVip(_agora), isFalse,
          reason: 'o direito e de um jogador, e a sessao dele acabou');
      expect(servico.estado.entitlement, isNull,
          reason: 'nao basta parecer sem VIP: o documento de A nao pode ficar '
              'guardado num processo que vai atender outra conta');
    });

    test('o painel volta ao estado inicial, nao a um meio-termo', () async {
      final servico = _montar();
      addTearDown(servico.descartar);
      await servico.iniciar();
      servico.atualizarEntitlement(_vipDe(_uidA));

      await servico.encerrar();

      // Nada de compra de A pendurado na interface do proximo jogador.
      expect(servico.estado.compra, EstadoCompra.ociosa);
      expect(servico.estado.restauracao, EstadoRestauracao.ociosa);
      expect(servico.estado.produtoEmFoco, isNull);
      expect(servico.estado.diagnostico, isNull);
    });

    test('quem observa o painel VE a queda, e nao apenas a leitura sincrona',
        () async {
      final servico = _montar();
      addTearDown(servico.descartar);
      await servico.iniciar();
      servico.atualizarEntitlement(_vipDe(_uidA));

      final vistos = <bool>[];
      final assinatura =
          servico.painel.listen((p) => vistos.add(p.mostrarComoVip(_agora)));
      addTearDown(assinatura.cancel);

      await servico.encerrar();
      await Future<void>.delayed(Duration.zero);

      expect(vistos, isNotEmpty,
          reason: 'o desligamento precisa ser um evento, senao uma tela ja '
              'montada continua mostrando o selo de A');
      expect(vistos.last, isFalse);
    });
  });

  // =========================================================================
  group('HOMOLOG-I — troca de conta A -> B', () {
    test('B entrando no mesmo processo nao herda o VIP de A', () async {
      final servico = _montar();
      addTearDown(servico.descartar);
      await servico.iniciar();

      servico.atualizarEntitlement(_vipDe(_uidA));
      expect(servico.estado.mostrarComoVip(_agora), isTrue);

      // Logout de A, login de B — o mesmo processo, o mesmo servico.
      await servico.encerrar();
      await servico.iniciar();

      expect(servico.estado.mostrarComoVip(_agora), isFalse,
          reason: 'B nao comprou nada; o selo de A nao pode atravessar a troca');
    });

    test('o direito de B so aparece quando o backend responde POR B', () async {
      final servico = _montar();
      addTearDown(servico.descartar);
      await servico.iniciar();
      servico.atualizarEntitlement(_vipDe(_uidA));

      await servico.encerrar();
      await servico.iniciar();

      // A camada de ligacao anuncia o novo uid: documento ainda nao lido.
      servico.atualizarEntitlement(EntitlementVip.ausente(_uidB));
      expect(servico.estado.mostrarComoVip(_agora), isFalse);
      expect(servico.estado.entitlement!.uid, _uidB);

      // Agora sim, o documento de B chega.
      servico.atualizarEntitlement(_vipDe(_uidB));
      expect(servico.estado.mostrarComoVip(_agora), isTrue);
      expect(servico.estado.entitlement!.uid, _uidB);
    });

    test('ausente sobrescreve um direito vigente — o caso do logout sem encerrar',
        () async {
      // Se a camada de ligacao trocar o entitlement sem desligar o servico, o
      // `ausente` do novo uid precisa VENCER o valor anterior. Se `copiarCom`
      // tratasse `ausente` como "nao informado", o VIP de A sobreviveria.
      final servico = _montar();
      addTearDown(servico.descartar);
      await servico.iniciar();
      servico.atualizarEntitlement(_vipDe(_uidA));

      servico.atualizarEntitlement(EntitlementVip.ausente(_uidB));

      expect(servico.estado.mostrarComoVip(_agora), isFalse);
      expect(servico.estado.entitlement!.uid, _uidB);
    });
  });
}
