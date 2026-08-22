// lobby_publico_de_producao.dart — o host publicável do Lobby Público.
//
// ---------------------------------------------------------------------------
// ESTE HOST NÃO É DONO DE NADA
// ---------------------------------------------------------------------------
//
// Ele não cria transporte, não conecta, não guarda retrato e não tem timer. O
// transporte é UM, mora na raiz (`escopo_transporte.dart`), e já está
// conectado e pulsando desde a Home — ver `ponte_sessao_online.dart`.
//
// Isso não é elegância: é o que faz a presença existir para quem nunca abre
// esta tela. Se o Lobby fosse dono da conexão, o número da Home só estaria
// certo depois de a pessoa visitar o Lobby — e antes disso ela seria contada
// como ausente, estando com o aplicativo aberto na mão.
//
// O que este arquivo faz é: ler o estado, traduzir a fase e pedir uma
// atualização quando a tela abre.
//
// ---------------------------------------------------------------------------
// SEM INGRESSO NESTA ETAPA
// ---------------------------------------------------------------------------
//
// `onEscolherMesa` fica NULO de propósito. Escolher assento e entrar numa mesa
// pública é a OS 38.3, e ela tem decisões próprias (qual assento, o que fazer
// quando a mesa encheu entre o toque e a chegada do pedido, o que a mesa VIP
// muda). Um card clicável agora prometeria uma porta que não existe, e a porta
// que existe — `entrarMesa` por código — não serve: ela não sabe escolher
// assento e entraria em qualquer lugar.

import 'package:flutter/material.dart';

import '../descoberta/estado_descoberta.dart';
import '../screens/lobby_publico_screen.dart';
import 'escopo_transporte.dart';

class LobbyPublicoDeProducao extends StatefulWidget {
  const LobbyPublicoDeProducao({super.key});

  @override
  State<LobbyPublicoDeProducao> createState() => _LobbyPublicoDeProducaoState();
}

class _LobbyPublicoDeProducaoState extends State<LobbyPublicoDeProducao> {
  @override
  void initState() {
    super.initState();
    // ATUALIZAÇÃO AO ABRIR — e depois do primeiro quadro.
    //
    // Depois do quadro porque pedir aqui dentro pode notificar ouvintes
    // durante a construção da árvore, e o Flutter reprova isso. Em `initState`
    // e não em `build` porque `build` roda a cada notificação do transporte: um
    // pedido ali viraria um pedido por resposta, que é o laço.
    //
    // O limite de frequência do agente protege o resto: se a lista acabou de
    // chegar, este pedido não sai.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      EscopoTransporte.talvezDe(context)?.solicitarMesas();
    });
  }

  @override
  Widget build(BuildContext context) {
    final online = EscopoTransporte.talvezDe(context);

    // Fora do escopo do transporte — prévia isolada de tela. Não é pretexto
    // para construir um transporte próprio: é uma tela que não tem o que
    // mostrar, e ela diz isso.
    if (online == null) {
      return LobbyPublicoScreen(
        retrato: null,
        fase: FaseDaDescoberta.sessaoEncerrada,
        atualizando: false,
        onVoltar: () => Navigator.of(context).maybePop(),
        onAtualizar: () {},
      );
    }

    final estado = online.descoberta;
    return LobbyPublicoScreen(
      retrato: estado.retrato,
      fase: estado.fase,
      atualizando: estado.atualizando,
      ultimaAtualizacaoRecusada: estado.ultimaRecusa != null,
      onVoltar: () => Navigator.of(context).maybePop(),
      // O botão Atualizar. `solicitarMesas` já é protegida por frequência:
      // apertar dez vezes seguidas manda um pedido só.
      onAtualizar: () => online.solicitarMesas(),
      // OS 38.3. Ver o cabeçalho.
      onEscolherMesa: null,
    );
  }
}
