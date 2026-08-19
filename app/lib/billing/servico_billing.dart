// servico_billing.dart — a camada isolada do cliente Billing.
//
// TODA conversa do aplicativo com a Google Play Billing passa por aqui. Nenhuma
// tela chama o plugin direto: se chamasse, cada tela teria a sua propria nocao
// de quando finalizar uma compra, e "quando finalizar" e justamente a decisao
// que faz o jogador receber ou perder o que pagou.
//
// O QUE ESTE SERVICO FAZ
//   consulta a vitrine, abre o fluxo de compra, escuta as entregas da Play
//   Store, confere se ha sessao, manda o token para o backend validar, e —
//   somente depois de um veredito — encerra a compra na Play Store.
//
// O QUE ELE NUNCA FAZ
//   conceder VIP, conceder fichas, escrever `playerEntitlements`, escrever
//   `compras/{hash}`, consumir assinatura, ou decidir que o jogador e VIP
//   porque a Play respondeu `purchased`.
//
// A ORDEM ENTRE VALIDAR, RECONHECER E FINALIZAR — e por que ela e esta
//
//   1. a Play Store entrega a compra pelo `purchaseStream`;
//   2. o app manda o `purchaseToken` para `validarCompraPlay`;
//   3. o BACKEND credita e so entao chama `acknowledge` (assinatura) ou
//      `consume` (consumivel), em `fecharComAGoogle`;
//   4. o app chama `completePurchase`, que e local e apenas encerra a pendencia
//      no plugin.
//
// O reconhecimento junto a Google e do servidor, nao do cliente, porque e o
// servidor que sabe se creditou. Se o cliente reconhecesse antes, uma falha
// entre reconhecer e creditar deixaria a Play satisfeita e o jogador sem nada —
// e a Play nao reentregaria mais. Na ordem acima, qualquer morte do app antes do
// passo 4 termina numa reentrega, que a idempotencia do backend absorve.
//
// O prazo de 3 dias da Play (assinatura nao reconhecida e estornada) e atendido
// no passo 3, e nao depende de o app continuar aberto.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../elegibilidade/entitlement.dart';
import 'catalogo.dart';
import 'estado_ui.dart';
import 'loja_play.dart';
import 'sessao.dart';
import 'vinculo.dart';
import 'validacao.dart';
import 'validacao_firebase.dart';

class ServicoBilling {
  ServicoBilling({
    LojaPlay? loja,
    ValidadorDeCompra? validador,
    required SessaoJogador sessao,
    PreparadorDeCompra? preparador,
    CatalogoBilling catalogo = CatalogoBilling.oficial,
    void Function(String)? registrador,
  })  : _loja = loja ?? const LojaPlayReal(),
        _validador = validador ?? ValidadorFirebase(),
        _sessao = sessao,
        _preparador = preparador ?? PreparadorFirebase(),
        _catalogo = catalogo,
        _registrar = registrador ?? _registroPadrao;

  static void _registroPadrao(String linha) => debugPrint('[billing] $linha');

  final LojaPlay _loja;
  final ValidadorDeCompra _validador;
  final SessaoJogador _sessao;
  final PreparadorDeCompra _preparador;

  /// O vinculo desta sessao, e o uid a que ele pertence.
  ///
  /// EM MEMORIA E ESCOPADO AO UID, as duas coisas de proposito. Persistir em
  /// disco criaria a unica falha que este desenho nao pode ter — o identificador
  /// de A sobrevivendo ao logout e sendo usado numa compra de B. Guardar sem o
  /// uid ao lado criaria a mesma falha dentro do mesmo processo, numa troca de
  /// conta sem reinicio.
  String? _vinculo;
  String? _vinculoDoUid;
  final CatalogoBilling _catalogo;
  final void Function(String) _registrar;

  /// O catalogo que este servico consulta. Em producao, [CatalogoBilling.oficial].
  CatalogoBilling get catalogo => _catalogo;

  final StreamController<PainelBilling> _painel =
      StreamController<PainelBilling>.broadcast();

  StreamSubscription<List<PurchaseDetails>>? _escuta;

  /// O guarda contra listener duplicado.
  ///
  /// Nao basta testar `_escuta != null`: duas chamadas concorrentes a [iniciar]
  /// passariam as duas pelo teste antes de qualquer uma atribuir, e a Play Store
  /// passaria a entregar cada compra DUAS vezes — dobrando as chamadas ao
  /// backend. Guardar o Future faz a segunda chamada esperar a primeira em vez
  /// de comecar outra. Ver BILLING-FLUTTER-13.
  Future<EstadoCatalogo>? _iniciando;

  PainelBilling _estado = const PainelBilling();
  List<ProductDetails> _produtos = const <ProductDetails>[];

  /// Tokens cuja validacao esta EM VOO agora.
  ///
  /// Existe para o caso de a Play Store entregar a mesma compra duas vezes antes
  /// de a primeira validacao voltar — reentrega e rotina, nao anomalia. Sem
  /// isto, o app faria duas chamadas para o mesmo token; o backend absorveria (a
  /// transacao de `compras/{hash}` e idempotente), mas o app estaria gastando
  /// rede e produzindo dois eventos de interface para um fato so.
  ///
  /// E memoria de processo, nao armazenamento: nao e persistido, nao e logado, e
  /// morre com o app. Ver BILLING-FLUTTER-10.
  final Set<String> _emValidacao = <String>{};

  /// Quantas compras a Play entregou desde que a restauracao comecou.
  int? _entregasNaRestauracao;

  /// O retrato atual. Sincrono, para quem monta a tela pela primeira vez.
  PainelBilling get estado => _estado;

  /// As transicoes, para quem quer reagir.
  Stream<PainelBilling> get painel => _painel.stream;

  /// Assinaturas consultaveis na Play Store agora.
  List<ProductDetails> get assinaturas => _produtos
      .where((p) => _catalogo.ehAssinatura(p.id))
      .toList(growable: false);

  /// Produtos unicos consumiveis consultaveis agora.
  List<ProductDetails> get consumiveis => _produtos
      .where((p) => _catalogo.ehConsumivel(p.id))
      .toList(growable: false);

  // ==========================================================================
  // CICLO DE VIDA
  // ==========================================================================

  /// Liga o servico. Idempotente e seguro sob concorrencia.
  Future<EstadoCatalogo> iniciar() {
    final emCurso = _iniciando;
    if (emCurso != null) return emCurso;
    return _iniciando = _iniciar();
  }

  Future<EstadoCatalogo> _iniciar() async {
    _publicar(_estado.copiarCom(catalogo: EstadoCatalogo.carregando));

    final disponivel = await _disponivelComSeguranca();
    if (!disponivel) {
      _registrar('Play Billing indisponivel nesta plataforma/aparelho');
      return _publicarCatalogo(EstadoCatalogo.indisponivel);
    }

    // A ESCUTA COMECA ANTES DE QUALQUER COMPRA, de proposito. E por este canal
    // que a Play Store reentrega as compras que ficaram penduradas de sessoes
    // anteriores — o app fechado no meio da validacao, a troca de aparelho, a
    // reinstalacao. Ligar a escuta depois perderia exatamente essas.
    _escuta = _loja.fluxoDeCompras.listen(
      _aoReceberCompras,
      onError: (Object e) {
        // So o tipo. O objeto de erro do plugin pode carregar os dados da
        // compra, e dados da compra incluem o `purchaseToken`.
        _registrar('falha no fluxo de compras: ${e.runtimeType}');
        _publicar(_estado.copiarCom(
          compra: EstadoCompra.erroDaPlay,
          diagnostico: 'fluxo de compras: ${e.runtimeType}',
        ));
      },
    );

    await recarregarCatalogo();
    return _estado.catalogo;
  }

  /// `isAvailable()` pode lancar em plataforma sem implementacao registrada.
  /// Uma excecao aqui nao pode derrubar a abertura do app: sem Billing, o app
  /// segue funcionando com a vitrine desligada.
  Future<bool> _disponivelComSeguranca() async {
    try {
      return await _loja.disponivel();
    } catch (e) {
      _registrar('isAvailable lancou: ${e.runtimeType}');
      return false;
    }
  }

  /// Consulta a Play Store pelos IDs declarados em [CatalogoBilling].
  ///
  /// TOLERA CATALOGO VAZIO SEM ERRO. Enquanto a Play Console nao liberar a area
  /// de produtos, `_catalogo.todos` e vazio: a consulta e PULADA (pedir
  /// zero IDs a Play Store nao tem sentido) e o estado vira `semProdutos`. E
  /// isso que o primeiro AAB precisa exibir.
  Future<void> recarregarCatalogo() async {
    if (!_catalogo.configurado) {
      _produtos = const <ProductDetails>[];
      _publicarCatalogo(EstadoCatalogo.semProdutos);
      return;
    }

    _publicar(_estado.copiarCom(catalogo: EstadoCatalogo.carregando));

    final ProductDetailsResponse resposta;
    try {
      resposta = await _loja.consultarProdutos(_catalogo.todos);
    } catch (e) {
      _registrar('consulta de catalogo lancou: ${e.runtimeType}');
      _produtos = const <ProductDetails>[];
      _publicarCatalogo(EstadoCatalogo.indisponivel);
      return;
    }

    if (resposta.error != null) {
      _registrar('consulta de catalogo falhou: ${resposta.error!.code}');
      _produtos = const <ProductDetails>[];
      _publicarCatalogo(EstadoCatalogo.indisponivel);
      return;
    }

    if (resposta.notFoundIDs.isNotEmpty) {
      // Declarado no app e ausente na Play Console: ID errado, produto inativo,
      // ou build ainda nao publicado numa trilha de teste. IDs de produto nao
      // sao segredo — podem ser registrados.
      _registrar('IDs nao encontrados na Play Console: ${resposta.notFoundIDs}');
    }

    _produtos = resposta.productDetails;
    _publicarCatalogo(
      _produtos.isEmpty ? EstadoCatalogo.semProdutos : EstadoCatalogo.pronto,
    );
  }

  /// Desliga a escuta. Chamar no `dispose` de quem ligou, e no LOGOUT.
  ///
  /// NAO fecha o canal de estado: o servico pode ser religado com [iniciar], e
  /// fechar o `StreamController` de um singleton o deixaria inutilizavel pelo
  /// resto da vida do processo.
  ///
  /// O PAINEL VOLTA AO ZERO, E ISSO E A PARTE QUE IMPORTA.
  ///
  /// `PainelBilling.entitlement` e o direito de UM jogador, e a interface le VIP
  /// dali. Se ele sobrevivesse ao desligamento, o proximo jogador a entrar no
  /// mesmo processo apareceria como VIP sem ter comprado nada — o direito dele so
  /// seria corrigido quando o primeiro `snapshot` de `playerEntitlements/{uid}`
  /// chegasse, o que depende de rede e NAO e sincrono. Essa janela e o vazamento
  /// entre contas que a homologacao proibe.
  ///
  /// Zerar tambem PUBLICA o novo retrato: uma tela ja montada escuta [painel], e
  /// sem evento ela continuaria exibindo o selo do jogador anterior mesmo com o
  /// estado interno correto.
  ///
  /// O custo do zero e um piscar de "nao-VIP" quando quem religa e o MESMO
  /// jogador (o app voltando do segundo plano, por exemplo), ate o documento ser
  /// relido. E a direcao segura: errar para menos nao entrega acesso pago a
  /// quem nao pagou. Ver HOMOLOG-H e HOMOLOG-I em
  /// `test/billing/troca_de_conta_test.dart`.
  Future<void> encerrar() async {
    await _escuta?.cancel();
    _escuta = null;
    _iniciando = null;
    _emValidacao.clear();
    _entregasNaRestauracao = null;
    _produtos = const <ProductDetails>[];
    // O vinculo sai junto com o resto. Ele pertence a uma CONTA, nao ao
    // processo: sobreviver ao logout o deixaria disponivel para a proxima
    // sessao, e uma compra de B com o identificador de A seria creditada a A.
    _vinculo = null;
    _vinculoDoUid = null;
    _publicar(const PainelBilling());
  }

  /// Libera tudo, inclusive o canal. So para quem realmente vai descartar o
  /// servico (teste, ou fim de processo).
  Future<void> descartar() async {
    await encerrar();
    await _painel.close();
  }

  // ==========================================================================
  // ENTITLEMENT — o que a interface pode chamar de VIP
  // ==========================================================================

  /// Recebe o direito lido de `playerEntitlements/{uid}`.
  ///
  /// Quem le e `EntitlementRepositorio`; o servico so guarda e republica, para
  /// que a interface tenha uma fonte unica. O servico NAO deduz entitlement da
  /// resposta da compra — ver o cabecalho de `estado_ui.dart`.
  void atualizarEntitlement(EntitlementVip entitlement) {
    _publicar(_estado.copiarCom(entitlement: entitlement));
  }

  // ==========================================================================
  // COMPRA
  // ==========================================================================

  /// Abre o fluxo de compra do [produto].
  ///
  /// [ofertaPlanoBase] escolhe o plano-base de uma assinatura (mensal,
  /// trimestral, anual). Ver [LojaPlay.comprarAssinatura].
  /// O vinculo desta sessao, preparando-o se ainda nao houver.
  ///
  /// Devolve `null` em tres situacoes, e nas tres a compra NAO deve abrir:
  ///
  ///   sem sessao        o backend responderia `unauthenticated` na preparacao,
  ///                     e sem vinculo a compra nasceria orfa;
  ///   preparacao falhou rede fora, funcao indisponivel — sem amarra;
  ///   forma invalida    o backend recusaria; abrir aqui seria cobrar por uma
  ///                     compra que ja se sabe que sera negada.
  ///
  /// O cache e por UID. Se a sessao trocou, o vinculo guardado e de OUTRA conta e
  /// e descartado sem hesitacao — reaproveita-lo faria a compra de B ser
  /// atribuida a A, que e exatamente o defeito que esta correcao fechou.
  Future<String?> _vinculoDaSessao() async {
    final uid = _sessao.uid;
    if (uid == null) {
      _registrar('compra nao aberta: sem sessao para vincular');
      _publicar(_estado.copiarCom(
        compra: EstadoCompra.erroDaPlay,
        diagnostico: 'compra: sem sessao',
      ));
      return null;
    }

    if (_vinculoDoUid != uid) {
      _vinculo = null;
      _vinculoDoUid = null;
    }
    if (_vinculo != null) return _vinculo;

    final concedido = await _preparador.preparar();
    if (!vinculoBemFormado(concedido)) {
      // O valor NAO entra no log nem no diagnostico. Ele nao e segredo de
      // autenticacao, mas a relacao com o uid e privada, e um diagnostico que
      // o carregue acaba em captura de tela de suporte.
      _registrar('compra nao aberta: vinculo ausente ou mal formado');
      _publicar(_estado.copiarCom(
        compra: EstadoCompra.erroDaPlay,
        diagnostico: 'compra: vinculo indisponivel',
      ));
      return null;
    }

    _vinculo = concedido;
    _vinculoDoUid = uid;
    return _vinculo;
  }

  Future<bool> comprar(ProductDetails produto, {String? ofertaPlanoBase}) async {
    _publicar(_estado.copiarCom(
      compra: EstadoCompra.emAndamento,
      produtoEmFoco: produto.id,
      limparDiagnostico: true,
    ));

    // ========================================================================
    // O PORTAO DA PROPRIEDADE — antes de qualquer dialogo da Play
    // ========================================================================
    //
    // Nao existe "compra primeiro, vincula depois". Uma compra que chega a Play
    // sem a amarra da conta e uma compra que o backend vai recusar: a Google
    // devolveria a resposta sem identificador externo, e sem ele nao ha dono
    // comprovavel. O jogador teria pago para receber `permission-denied`.
    //
    // Por isso a recusa acontece ANTES de abrir o fluxo, e ela nao cobra nada
    // de ninguem.
    final vinculo = await _vinculoDaSessao();
    if (vinculo == null) return false;

    try {
      return _catalogo.ehAssinatura(produto.id)
          ? await _loja.comprarAssinatura(produto,
              ofertaPlanoBase: ofertaPlanoBase, vinculoDaConta: vinculo)
          : await _loja.comprarConsumivel(produto, vinculoDaConta: vinculo);
    } catch (e) {
      _registrar('abertura do fluxo de compra falhou: ${e.runtimeType}');
      _publicar(_estado.copiarCom(
        compra: EstadoCompra.erroDaPlay,
        diagnostico: 'compra: ${e.runtimeType}',
      ));
      return false;
    }
  }

  /// Pede a Play Store para reentregar as compras ativas desta conta.
  ///
  /// O restore NAO concede nada por si: cada compra reentregue volta pelo
  /// `purchaseStream` e percorre o MESMO caminho de validacao de uma compra
  /// nova. E por isso que restaurar nao duplica beneficio — quem decide e o
  /// backend, que ja viu aquele token.
  Future<void> restaurar() async {
    if (_estado.catalogo == EstadoCatalogo.naoIniciado ||
        _estado.catalogo == EstadoCatalogo.indisponivel) {
      _publicar(_estado.copiarCom(restauracao: EstadoRestauracao.nadaARestaurar));
      return;
    }

    _entregasNaRestauracao = 0;
    _publicar(_estado.copiarCom(restauracao: EstadoRestauracao.emAndamento));

    try {
      await _loja.restaurar();
    } catch (e) {
      _registrar('restauracao falhou: ${e.runtimeType}');
      _entregasNaRestauracao = null;
      _publicar(_estado.copiarCom(
        restauracao: EstadoRestauracao.nadaARestaurar,
        diagnostico: 'restauracao: ${e.runtimeType}',
      ));
      return;
    }

    // A Play entrega as compras restauradas pelo `purchaseStream` ANTES de
    // `restorePurchases()` completar — o plugin aguarda a consulta terminar.
    // Por isso da para concluir aqui se veio algo ou nao.
    final entregues = _entregasNaRestauracao ?? 0;
    _entregasNaRestauracao = null;
    _publicar(_estado.copiarCom(
      restauracao: entregues > 0
          ? EstadoRestauracao.concluida
          : EstadoRestauracao.nadaARestaurar,
    ));
  }

  // ==========================================================================
  // ENTREGAS DA PLAY STORE
  // ==========================================================================

  Future<void> _aoReceberCompras(List<PurchaseDetails> compras) async {
    for (final compra in compras) {
      await _tratar(compra);
    }
  }

  Future<void> _tratar(PurchaseDetails compra) async {
    if (_entregasNaRestauracao != null) {
      _entregasNaRestauracao = _entregasNaRestauracao! + 1;
    }

    switch (compra.status) {
      case PurchaseStatus.pending:
        // Pagamento ainda nao concretizado. Nao ha token util para validar e nao
        // ha nada a finalizar: so avisar a interface e esperar a Play voltar.
        _publicar(_estado.copiarCom(
          compra: EstadoCompra.pendente,
          produtoEmFoco: compra.productID,
        ));

      case PurchaseStatus.purchased:
      case PurchaseStatus.restored:
        await _validar(compra);

      case PurchaseStatus.canceled:
        await _finalizar(compra);
        _publicar(_estado.copiarCom(
          compra: EstadoCompra.cancelada,
          produtoEmFoco: compra.productID,
        ));

      case PurchaseStatus.error:
        // Erro da propria Play Store: nao houve compra. Finalizar limpa a
        // pendencia; nao ha nada para o backend olhar.
        await _finalizar(compra);
        _registrar('a Play devolveu erro para ${compra.productID}: '
            '${compra.error?.code ?? "sem codigo"}');
        _publicar(_estado.copiarCom(
          compra: EstadoCompra.erroDaPlay,
          produtoEmFoco: compra.productID,
          diagnostico: 'play: ${compra.error?.code ?? "sem codigo"}',
        ));
    }
  }

  Future<void> _validar(PurchaseDetails compra) async {
    // No Android este campo carrega o `purchaseToken`.
    final token = compra.verificationData.serverVerificationData;
    final rotulo = rotuloDoToken(token);

    // Reentrega concorrente: a mesma compra chegou de novo antes de a primeira
    // validacao voltar. Ver `_emValidacao`.
    if (!_emValidacao.add(token)) {
      _registrar('entrega repetida de $rotulo ignorada: validacao em voo');
      return;
    }

    try {
      // PORTAO DE SESSAO — antes de gastar a chamada.
      //
      // Sem sessao o backend responderia `unauthenticated`. O que esta em jogo
      // nao e seguranca (a titularidade continua sendo decidida por
      // `request.auth.uid` la), e sim NAO PERDER A COMPRA: sem este portao o
      // caminho de erro poderia terminar em `completePurchase`, e uma compra
      // finalizada nao e reentregue. Aqui ela fica pendente e volta no proximo
      // login.
      if (_sessao.uid == null) {
        _registrar('compra $rotulo adiada: sem sessao do Firebase Auth');
        _publicar(_estado.copiarCom(
          compra: EstadoCompra.aguardandoRevalidacao,
          produtoEmFoco: compra.productID,
          diagnostico: 'sem sessao: a compra segue pendente para revalidar',
        ));
        return;
      }

      _publicar(_estado.copiarCom(
        compra: EstadoCompra.aguardandoValidacao,
        produtoEmFoco: compra.productID,
        limparDiagnostico: true,
      ));

      final resultado = await _validador.validar(
        CompraParaValidar(
          produtoId: compra.productID,
          tokenCompra: token,
          // O tipo vem do catalogo do app e e conferido pelo servidor contra
          // `configuracao/billing`. Divergencia vira `invalid-argument`.
          assinatura: _catalogo.declaradoComoAssinatura(compra.productID),
          orderId: compra.purchaseID,
        ),
      );

      final destino = decidirDestinoDaCompra(resultado);

      // A FINALIZACAO SEGUE A DECISAO, nunca o contrario. `adiar` e o unico
      // destino que NAO finaliza, para a Play Store reentregar.
      if (deveFinalizarCompra(destino)) {
        await _finalizar(compra);
      }

      switch (destino) {
        case DestinoDaCompra.conceder:
          // NADA e creditado aqui, e o jogador NAO vira VIP por causa desta
          // linha. O backend ja gravou o que a compra concede; o direito chega a
          // interface pelo `EntitlementRepositorio`.
          _registrar('compra $rotulo validada pelo servidor '
              '(${resultado.jaProcessada ? "reentrega ja processada" : "nova"})');
          _publicar(_estado.copiarCom(
            compra: EstadoCompra.validada,
            produtoEmFoco: compra.productID,
            limparDiagnostico: true,
          ));

        case DestinoDaCompra.adiar:
          _registrar('compra $rotulo adiada: ${resultado.motivo}');
          _publicar(_estado.copiarCom(
            compra: EstadoCompra.aguardandoRevalidacao,
            produtoEmFoco: compra.productID,
            diagnostico: resultado.motivo,
          ));

        case DestinoDaCompra.recusar:
          _registrar('compra $rotulo recusada: ${resultado.motivo}');
          _publicar(_estado.copiarCom(
            compra: EstadoCompra.recusada,
            produtoEmFoco: compra.productID,
            diagnostico: resultado.motivo,
          ));
      }
    } finally {
      _emValidacao.remove(token);
    }
  }

  Future<void> _finalizar(PurchaseDetails compra) async {
    if (!compra.pendingCompletePurchase) return;
    try {
      await _loja.finalizar(compra);
    } catch (e) {
      // Falhar aqui nao perde nada: a compra continua pendente e sera
      // reentregue, e o backend ja registrou o que precisava.
      _registrar('completePurchase falhou: ${e.runtimeType}');
    }
  }

  // ==========================================================================

  EstadoCatalogo _publicarCatalogo(EstadoCatalogo c) {
    _publicar(_estado.copiarCom(catalogo: c));
    return c;
  }

  void _publicar(PainelBilling novo) {
    _estado = novo;
    if (!_painel.isClosed) _painel.add(novo);
  }
}
