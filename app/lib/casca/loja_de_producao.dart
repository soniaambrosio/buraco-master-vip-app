// loja_de_producao.dart — a Loja alcançável a partir do aplicativo publicável.
//
// ---------------------------------------------------------------------------
// O QUE ESTA TELA SUBSTITUI
// ---------------------------------------------------------------------------
//
// O caminho para a Loja existia num lugar só: `_LojaPreviewHost`, dentro das
// 2.172 linhas do `main.dart` antigo. Aquele host já era o host CERTO — foi ele
// que trocou o `setState(() => _ehVip = true)` por `playerEntitlements/{uid}` e
// os preços escritos à mão pelo `formattedPrice` da Play. O problema é que ele
// morava na bancada de prévias, e a Casca V2 apagou a bancada inteira. Desde
// então o Billing do cliente estava completo e INALCANÇÁVEL: nenhuma rota que
// nasce em `main()` chegava a uma tela capaz de abrir o fluxo de compra.
//
// Este arquivo é aquele host, movido para dentro da casca e com as três
// diferenças que a casca exige:
//
//   1. O uid vem do `EscopoSessao` — a sessão canônica —, e não de
//      `FirebaseAuth.instance`. Só a camada de sessão fala com o provedor.
//   2. A navegação é a de produção: volta com `maybePop`, o Início é a Home
//      real e o Perfil é a `PerfilPage` real.
//   3. NADA de `LojaVM.mock()`. É a diferença que muda o que aparece na tela, e
//      está explicada logo abaixo.
//
// ---------------------------------------------------------------------------
// POR QUE A LOJA DE PRODUÇÃO É MENOR QUE A MAQUETE
// ---------------------------------------------------------------------------
//
// O host de prévia desenhava `LojaVM.mock().copiarCom(ehVip:…, planos:…)`: o VIP
// e os planos vinham do backend e da Play, e todo o resto — 1.000 moedas, 12
// gemas, cinco pacotes com preço, seis categorias de cosmético com contagem
// ("28 skins"), oito amigos para presentear — vinha da maquete.
//
// Numa bancada de prévias isso é honesto: quem abre sabe que está olhando um
// desenho. Num aplicativo publicado, não. "🪙 1.000" no alto da tela é uma
// afirmação sobre a carteira de quem instalou, e um pacote de moedas com
// "R$ 4,90" é uma OFERTA — de um produto que não existe na Play Console, que
// nenhum backend credita e que ninguém aprovou. É a mesma regra que esvaziou a
// Home: dado sem fonte não é desenhado, e promessa comercial sem produto não é
// exibida.
//
// Sobra o que tem autoridade de verdade, que é exatamente o que a linhagem do
// Billing entregou: o selo VIP (`playerEntitlements/{uid}`, escrito só pelo
// backend depois de conferir a compra com a Google) e os planos que a Play
// devolveu, com o preço que ELA formatou. Enquanto o produto `master_vip` não
// existir na Play Console, a lista de planos vem vazia — e a tela diz isso, em
// vez de fingir uma vitrine.
//
// O caminho de volta desses elementos não passa por aqui: no dia em que houver
// autoridade de economia e catálogo de cosméticos, quem os liga preenche os
// campos correspondentes de `LojaVM` e as seções reaparecem sozinhas.
//
// ---------------------------------------------------------------------------
// A COSTURA DE TESTE
// ---------------------------------------------------------------------------
//
// [DependenciasDaLoja] existe pelo mesmo motivo que as quatro costuras de
// `raiz_do_aplicativo.dart`: sem ela, provar "a Home abre a Loja" ou "tocar em
// assinar NÃO acende o VIP" exigiria Firebase e o plugin da Play dentro do
// `flutter test`, e os casos simplesmente não seriam testados.
//
// Fora de um [EscopoLoja] a montagem é a de PRODUÇÃO. A direção da falha é essa
// de propósito: um esquecimento não entrega uma Loja falsa: entrega a real.

import 'dart:async';

import 'package:flutter/material.dart';

import '../billing/acesso_vip.dart' show FonteEntitlement;
import '../billing/entitlement_repositorio.dart';
import '../billing/estado_ui.dart';
import '../billing/plano_vip.dart';
import '../billing/servico_billing.dart';
import '../billing/sessao.dart';
import '../elegibilidade/entitlement.dart';
import '../pages/perfil_page.dart';
import '../screens/loja_screen.dart';
import '../screens/loja_vip_adaptador.dart';
import '../screens/perfil_screen.dart' show NavDestino;
import '../sessao/escopo_sessao.dart';

// ===========================================================================
// As dependências, e como o teste as troca
// ===========================================================================

/// De onde a Loja tira o serviço de compras e a leitura do direito VIP.
class DependenciasDaLoja {
  const DependenciasDaLoja({
    required this.criarBilling,
    required this.observarEntitlement,
  });

  /// Monta o serviço para a sessão informada. Quem chama é dono do que recebe.
  final ServicoBilling Function(SessaoJogador sessao) criarBilling;

  /// A escuta de `playerEntitlements/{uid}`.
  final FonteEntitlement observarEntitlement;

  /// A montagem real: Play Billing de verdade e Firestore de verdade.
  static const DependenciasDaLoja producao = DependenciasDaLoja(
    criarBilling: _billingDeProducao,
    observarEntitlement: _entitlementDeProducao,
  );
}

ServicoBilling _billingDeProducao(SessaoJogador sessao) =>
    ServicoBilling(sessao: sessao);

Stream<EntitlementVip> _entitlementDeProducao(String uid) =>
    EntitlementRepositorio().observar(uid);

/// Pendura uma montagem alternativa da Loja na árvore. Só o teste monta isto.
class EscopoLoja extends InheritedWidget {
  const EscopoLoja({
    super.key,
    required this.dependencias,
    required super.child,
  });

  final DependenciasDaLoja dependencias;

  /// A montagem visível deste ponto da árvore. Fora do escopo, a de produção.
  static DependenciasDaLoja de(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<EscopoLoja>()
          ?.dependencias ??
      DependenciasDaLoja.producao;

  @override
  bool updateShouldNotify(EscopoLoja anterior) =>
      dependencias != anterior.dependencias;
}

// ===========================================================================
// A tela
// ===========================================================================

class LojaDeProducao extends StatefulWidget {
  const LojaDeProducao({super.key});

  @override
  State<LojaDeProducao> createState() => _LojaDeProducaoState();
}

class _LojaDeProducaoState extends State<LojaDeProducao> {
  ServicoBilling? _billing;
  StreamSubscription<PainelBilling>? _escutaPainel;
  StreamSubscription<EntitlementVip>? _escutaEntitlement;

  PainelBilling _painel = const PainelBilling();
  List<PlanoVipDisponivel> _planos = const <PlanoVipDisponivel>[];

  /// O jogador desta tela. Fixado na primeira montagem, e é o certo: a troca de
  /// sessão descarta a pilha de navegação inteira (ver a chave do `MaterialApp`
  /// em `raiz_do_aplicativo.dart`), então esta tela não sobrevive à troca —
  /// ela é reconstruída do zero, com o uid novo.
  String? _uid;
  bool _montado = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_montado) return;
    _montado = true;

    final dependencias = EscopoLoja.de(context);
    _uid = EscopoSessao.identidadeDe(context).uid;

    final billing = dependencias.criarBilling(SessaoFixa(_uid));
    _billing = billing;

    _escutaPainel = billing.painel.listen((p) {
      if (!mounted) return;
      setState(() {
        _painel = p;
        _planos = planosVipDe(billing.assinaturas);
      });
    });

    // A escuta do direito é POR JOGADOR e só faz sentido com sessão. Sem uid o
    // documento nem existe, e o padrão — entitlement ausente — já é "sem VIP".
    final uid = _uid;
    if (uid != null && uid.isNotEmpty) {
      _escutaEntitlement = dependencias.observarEntitlement(uid).listen(
        billing.atualizarEntitlement,
        // Falha de leitura NÃO acende nem apaga VIP por conta própria: o estado
        // anterior continua valendo até o backend responder.
        onError: (Object _) {},
      );
    }

    billing.iniciar();
  }

  @override
  void dispose() {
    _escutaPainel?.cancel();
    _escutaEntitlement?.cancel();
    // Esta tela criou o serviço, então esta tela o descarta.
    _billing?.descartar();
    super.dispose();
  }

  /// O jogador deve ser APRESENTADO como VIP agora?
  ///
  /// Recalculado a cada quadro contra o relógio, e não guardado: um direito que
  /// vence com a tela aberta deixa de valer no quadro seguinte, sem depender de
  /// o Firestore emitir evento no segundo exato do vencimento.
  bool get _ehVip => _painel.mostrarComoVip(DateTime.now().toUtc());

  // -------------------------------------------------------------------------
  // Compra
  // -------------------------------------------------------------------------

  /// Abre o fluxo de compra do plano-base escolhido.
  ///
  /// O `offerToken` é o que faz a Play cobrar o plano CERTO: sem ele ela usaria
  /// a oferta padrão do produto, e quem escolheu "Anual" poderia acabar
  /// assinando o mensal.
  Future<void> _assinar(String basePlanId) async {
    final billing = _billing;
    if (billing == null) return;

    PlanoVipDisponivel? escolhido;
    for (final p in _planos) {
      if (p.basePlanId == basePlanId) escolhido = p;
    }
    if (escolhido == null) {
      _aviso('Este plano não está disponível agora.');
      return;
    }
    await billing.comprar(
      escolhido.produto,
      ofertaPlanoBase: escolhido.ofertaToken,
    );
  }

  /// Texto honesto para cada situação do fluxo.
  ///
  /// `aguardandoRevalidacao` é o que merece mais cuidado: é o caso em que a
  /// pessoa PAGOU e o servidor ainda não confirmou. Dizer "erro" faria parecer
  /// que o dinheiro sumiu; dizer "pronto" seria mentira.
  String? get _avisoDoEstado {
    switch (_painel.compra) {
      case EstadoCompra.aguardandoValidacao:
        return 'Confirmando sua assinatura com o servidor…';
      case EstadoCompra.aguardandoRevalidacao:
        return 'Sua compra foi registrada e será confirmada em instantes. '
            'Não é preciso comprar de novo.';
      case EstadoCompra.validada:
        return 'Assinatura confirmada. Liberando seu VIP…';
      case EstadoCompra.recusada:
        return 'Não foi possível validar esta compra.';
      case EstadoCompra.pendente:
        return 'Pagamento pendente de aprovação.';
      case EstadoCompra.cancelada:
        return 'Compra cancelada.';
      case EstadoCompra.erroDaPlay:
        return 'A Play Store não conseguiu concluir a compra.';
      case EstadoCompra.emAndamento:
      case EstadoCompra.ociosa:
        return null;
    }
  }

  /// O que a vitrine diz quando não há plano nenhum para oferecer.
  ///
  /// Cada situação tem texto próprio porque elas pedem coisas diferentes de
  /// quem lê: esperar, desistir, ou entrar na conta.
  String get _avisoDaVitrine {
    if (_uid == null || _uid!.isEmpty) {
      return 'Entre na sua conta para assinar o Buraco Master VIP.';
    }
    switch (_painel.catalogo) {
      case EstadoCatalogo.naoIniciado:
      case EstadoCatalogo.carregando:
        return 'Consultando os planos na Google Play…';
      case EstadoCatalogo.indisponivel:
        return 'A Google Play não está disponível neste aparelho, então não dá '
            'para assinar por aqui agora.';
      case EstadoCatalogo.semProdutos:
      case EstadoCatalogo.pronto:
        return 'A assinatura VIP ainda não está à venda. Assim que os planos '
            'entrarem no ar, eles aparecem aqui.';
    }
  }

  void _aviso(String texto) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(texto),
          duration: const Duration(milliseconds: 1600),
          backgroundColor: const Color(0xFF2A1B0E),
        ),
      );
  }

  // -------------------------------------------------------------------------
  // Navegação
  // -------------------------------------------------------------------------

  void _navegar(NavDestino destino) {
    switch (destino) {
      case NavDestino.inicio:
        // A Home é a primeira rota da casca — voltar até ela é despir a pilha,
        // e não empurrar uma segunda Home por cima.
        Navigator.of(context).popUntil((rota) => rota.isFirst);
      case NavDestino.perfil:
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const PerfilPage()),
        );
      case NavDestino.ranking:
        _aviso('Ranking ainda não está disponível nesta versão.');
      case NavDestino.loja:
        break; // já estamos aqui
    }
  }

  @override
  Widget build(BuildContext context) {
    return LojaScreen(
      // O construtor por extenso, e nenhuma fábrica de maquete: os campos que
      // não estão aqui são exatamente os que não têm autoridade, e o padrão
      // deles — nulo e lista vazia — é o que apaga as seções.
      vm: LojaVM(ehVip: _ehVip, planos: planosParaLoja(_planos)),
      avisoDaVitrine: _avisoDaVitrine,
      onVoltar: () => Navigator.of(context).maybePop(),
      onNav: _navegar,
      // NENHUM `_ehVip = true` aqui, e essa ausência é o ponto: este callback só
      // ABRE o fluxo da Play. O selo acende quando o backend gravar o
      // entitlement e o `snapshots()` trouxer a mudança.
      onAssinar: (basePlanId) {
        _assinar(basePlanId);
        final texto = _avisoDoEstado;
        if (texto != null) _aviso(texto);
      },
      // As quatro superfícies abaixo não são alcançáveis com as listas vazias:
      // sem pacote não há carteira nem grade de moedas, sem categoria não há
      // cosmético e sem amigo não há presente. Continuam preenchidas porque
      // `LojaScreen` as exige, e um callback vazio viraria, no dia em que a
      // fonte existir, um botão silencioso.
      onComprarMoedas: () {},
      onComprarPacote: (_) {},
      onConfirmarCompra: (_) {},
      onAbrirCategoria: (_) {},
      onPresentear: (_) {},
      onBuscarPresenteado: (_) {},
      onEnviarPresente: (_, _) {},
    );
  }
}
