// escolha_assento_de_producao.dart — o host publicável da escolha de assento.
//
// ---------------------------------------------------------------------------
// ESTE HOST NÃO É DONO DE NADA
// ---------------------------------------------------------------------------
//
// Não cria transporte, não conecta, não guarda retrato, não tem timer e não
// decide assento. O transporte é UM, mora na raiz e já está conectado e
// pulsando desde a Home (`ponte_sessao_online.dart`).
//
// O que este arquivo faz é: achar a mesa no retrato vigente, traduzir o toque
// numa cadeira em UM pedido pelo transporte, e — só depois do ACK — navegar.
//
// ---------------------------------------------------------------------------
// A NAVEGAÇÃO ACONTECE UMA VEZ, E DEPOIS DO ACK
// ---------------------------------------------------------------------------
//
// `OnlineService` notifica a cada mensagem do servidor, e o `build` roda a cada
// notificação. Navegar direto dali empilharia um destino por resposta
// recebida. A trava é dupla, e as duas metades são necessárias:
//
//   * `consumirConfirmacao()` entrega a confirmação UMA vez e a apaga, então
//     um segundo `build` não encontra nada para consumir;
//   * `_navegou` impede até a hipótese de dois quadros correrem antes de o
//     `pushReplacement` completar.
//
// E é `addPostFrameCallback` porque navegar durante a construção da árvore é
// erro de framework: o `Navigator` é um ancestral, e marcá-lo como sujo
// enquanto um descendente está sendo construído reprova no próprio Flutter.
//
// `pushReplacement` E NÃO `push`: voltar da mesa não pode devolver a pessoa a
// um seletor de assento de uma mesa em que ela já está sentada — uma tela que
// ofereceria cadeiras que já são dela ou de outros.
//
// ---------------------------------------------------------------------------
// SAIR DA TELA INVALIDA O PEDIDO
// ---------------------------------------------------------------------------
//
// O `dispose` cancela a intenção. Uma resposta que chegue depois encontra a
// máquina fora de `solicitando` e não confirma, não recusa e não navega.
//
// O que ele NÃO faz é desfazer uma entrada que o servidor já concedeu. Se o
// ACK estava a caminho, a pessoa está sentada de verdade; mandar `sair` aqui
// seria a compensação "entrei errado, saio e tento de novo" que a OS proíbe, e
// ela nem sequer resolveria — o servidor continuaria sendo a autoridade, e o
// cliente estaria discutindo com ele.

import 'package:flutter/material.dart';

import '../descoberta/modelo_descoberta.dart';
import '../ingresso/estado_ingresso.dart';
import '../ingresso/modelo_ingresso.dart';
import '../screens/escolha_assento_screen.dart';
import '../services/online_service.dart';
import '../sessao/escopo_sessao.dart';
import 'escopo_transporte.dart';
import 'lobby_online.dart';

/// O apelido com que o servidor nomeia um assento quando a identidade pública
/// ainda não chegou.
///
/// É o MESMO padrão do servidor (`apelido = "Jogador"`), e não um nome
/// inventado por esta tela. E não é identidade: quem o jogador é sai do token
/// verificado, e um `jogadorId` saindo daqui seria recusado como identidade
/// divergente.
const String kApelidoPadraoDoIngresso = 'Jogador';

class EscolhaAssentoDeProducao extends StatefulWidget {
  const EscolhaAssentoDeProducao({super.key, required this.codigo});

  /// O código OPACO da mesa, como a descoberta o publicou. Não é interpretado
  /// aqui e não é exibido.
  final String codigo;

  @override
  State<EscolhaAssentoDeProducao> createState() =>
      _EscolhaAssentoDeProducaoState();
}

class _EscolhaAssentoDeProducaoState extends State<EscolhaAssentoDeProducao> {
  /// O transporte que esta tela está usando. Guardado porque o `dispose`
  /// precisa dele e lá não se pode mais depender de um `InheritedWidget`.
  OnlineService? _srv;

  bool _navegou = false;

  /// A confirmação que acabou de ser consumida, guardada só para a tela poder
  /// ANUNCIÁ-LA no quadro em que a navegação sai.
  ///
  /// Sem isto o ACK positivo seria o único desfecho mudo da tela: o pedido é
  /// anunciado, a recusa é anunciada, e o sucesso — que é o que a pessoa está
  /// esperando — trocaria de tela sem uma palavra para quem não vê.
  IngressoConfirmado? _confirmacaoParaAnuncio;

  @override
  void initState() {
    super.initState();
    // ATUALIZAÇÃO AO ABRIR — e depois do primeiro quadro, pela mesma razão do
    // Lobby: pedir aqui dentro pode notificar ouvintes durante a construção da
    // árvore. O limite de frequência do agente protege o resto.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      EscopoTransporte.talvezDe(context)?.solicitarMesas();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _srv = EscopoTransporte.talvezDe(context);
  }

  @override
  void dispose() {
    // Ver o cabeçalho: a INTENÇÃO morre, a entrada concedida não é desfeita.
    _srv?.ingresso.cancelar();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final online = EscopoTransporte.talvezDe(context);

    // Fora do escopo do transporte — prévia isolada de tela. Não é pretexto
    // para construir um transporte próprio: é uma tela que não tem o que
    // mostrar, e ela diz isso.
    if (online == null) {
      return EscolhaAssentoScreen(
        mesa: null,
        fase: FaseDoIngresso.ocioso,
        assentoSolicitado: null,
        recusa: null,
        onVoltar: () => Navigator.of(context).maybePop(),
        onAtualizar: () {},
      );
    }

    final ingresso = online.ingresso;

    // O ACK CHEGOU. Consome a confirmação e navega — uma vez.
    if (ingresso.temConfirmacaoPendente && !_navegou) {
      final confirmado = ingresso.consumirConfirmacao();
      if (confirmado != null) {
        _navegou = true;
        _confirmacaoParaAnuncio = confirmado;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute<void>(
              builder: (_) => LobbyOnline(ingressoConfirmado: confirmado),
            ),
          );
        });
      }
    }

    final identidade = EscopoSessao.identidadeDe(context);
    final apelido = identidade.identidade?.apelido;
    final apelidoDoFio = (apelido == null || apelido.isEmpty)
        ? kApelidoPadraoDoIngresso
        : apelido;

    return EscolhaAssentoScreen(
      mesa: _mesaDoRetrato(online),
      faseDaDescoberta: online.descoberta.fase,
      fase: ingresso.fase,
      assentoSolicitado: ingresso.assentoSolicitado,
      recusa: ingresso.recusa,
      confirmacao: _confirmacaoParaAnuncio,
      onVoltar: () => Navigator.of(context).maybePop(),
      onAtualizar: () => online.solicitarMesas(),
      // O PEDIDO EXPLÍCITO. O retorno de `solicitarIngresso` é ignorado de
      // propósito: `false` significa "não saiu" — pedido em voo ou sem conexão
      // —, e a tela já desenha os dois estados. Inventar uma mensagem aqui
      // diria à pessoa que algo falhou quando o que houve foi o toque duplo
      // sendo travado, que é o comportamento certo.
      onEscolherAssento: (assento) => online.solicitarIngresso(
        codigo: widget.codigo,
        apelido: apelidoDoFio,
        assento: assento,
      ),
      // O INGRESSO AUTOMÁTICO. `assento` fica AUSENTE — nem `null` no fio, nem
      // uma preferência inventada para imitar a ordem do servidor.
      onEntrarEmQualquerLugar: () => online.solicitarIngresso(
        codigo: widget.codigo,
        apelido: apelidoDoFio,
      ),
    );
  }

  /// A mesa do retrato VIGENTE, ou `null` quando ela saiu da lista.
  ///
  /// Buscar por código a cada `build` é o que faz a ocupação desta tela andar
  /// junto com o servidor: a cadeira que alguém tomou aparece tomada aqui na
  /// atualização seguinte, sem que esta tela precise de estado próprio — e sem
  /// que ela possa DISCORDAR do que o Lobby mostra, porque a fonte é a mesma.
  ///
  /// E é o que faz a mesa SUMIR quando ela sai da lista, em vez de continuar
  /// desenhada a partir de uma fotografia velha.
  MesaPublica? _mesaDoRetrato(OnlineService online) {
    final retrato = online.descoberta.retrato;
    if (retrato == null) return null;
    for (final m in retrato.mesas) {
      if (m.codigo == widget.codigo) return m;
    }
    return null;
  }
}
