import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../mesa.dart';
import 'configurar_mesa_screen.dart';
import 'mesa_flow_plan.dart';
import 'mesa_privada_social.dart';
import 'preparando_partida_screen.dart';

/// Host de prévia limpo para substituir o `_ConfigMesaPreviewHost` legado.
///
/// Continua 100% mock/visual: servidor, saldo, VIP/Passe, criação de sala e
/// autoridade serão injetados na integração. A diferença é que este host usa a
/// cadeia de contratos aprovada em vez de reconstruir escolhas manualmente.
class MesaFlowPreviewHost extends StatefulWidget {
  final TipoMesa tipoInicial;
  final bool ehVip;

  const MesaFlowPreviewHost({
    super.key,
    required this.tipoInicial,
    this.ehVip = true,
  });

  @override
  State<MesaFlowPreviewHost> createState() => _MesaFlowPreviewHostState();
}

class _MesaFlowPreviewHostState extends State<MesaFlowPreviewHost> {
  late ConfigMesaVM _vm = ConfigMesaVM.mock(
    tipo: widget.tipoInicial,
    ehVip: widget.ehVip,
  );

  int get _jogadores => _vm.modo == ModoJogo.dois ? 2 : 4;

  void _aviso(String texto) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(texto),
          duration: const Duration(milliseconds: 1500),
          backgroundColor: const Color(0xFF2A1B0E),
        ),
      );
  }

  ApostaVM? _apostaComPote(ApostaVM? aposta, {int? valor, int? jogadores}) {
    if (aposta == null) return null;
    final novoValor = valor ?? aposta.valor;
    final qtd = jogadores ?? _jogadores;
    return aposta.copyWith(valor: novoValor, pote: novoValor * qtd);
  }

  void _trocarModo(ModoJogo modo) {
    final qtd = modo == ModoJogo.dois ? 2 : 4;
    setState(() {
      _vm = _vm.copyWith(
        modo: modo,
        aposta: _apostaComPote(_vm.aposta, jogadores: qtd),
      );
    });
  }

  void _alternarCadeira(String id) {
    final cadeiras = _vm.cadeiras;
    if (cadeiras == null) return;
    setState(() {
      _vm = _vm.copyWith(
        cadeiras: cadeiras.map((cadeira) {
          if (cadeira.id != id || !cadeira.podeAlternar) return cadeira;
          return cadeira.copyWith(
            estado: cadeira.estado == EstadoCadeira.travada
                ? EstadoCadeira.liberada
                : EstadoCadeira.travada,
          );
        }).toList(growable: false),
      );
    });
  }

  Future<void> _copiarCodigo() async {
    final codigo = _vm.codigo;
    if (codigo == null) return;
    await Clipboard.setData(ClipboardData(text: codigo));
    if (mounted) _aviso('Código $codigo copiado');
  }

  void _verRegras() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1C130C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(22, 18, 22, 26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Modalidades',
                style: TextStyle(
                  color: Color(0xFFEFB94A),
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 13),
              Text('Aberto — lixo à vista e compra livre.'),
              SizedBox(height: 8),
              Text('Fechado — compra justificada e aceita trinca.'),
              SizedBox(height: 8),
              Text('STBL — sem trinca e bate somente com canastra limpa.'),
            ],
          ),
        ),
      ),
    );
  }

  void _criarMesa() {
    final plan = MesaFlowPlan.fromVm(_vm);
    if (!plan.valido) {
      _aviso('Revise a mesa: ${plan.validation.erros.join(', ')}');
      return;
    }

    // Não abre o motor histórico de 4 assentos fingindo ser uma partida 1 × 1.
    if (plan.precisaMotorDoisJogadores) {
      _aviso(
        'Prévia 1 × 1 pronta até a preparação. O motor de 2 jogadores será ligado de forma autoritativa.',
      );
      return;
    }

    final variant = plan.legacyRendererSkinCode == 'publica'
        ? MesaVariant.publica
        : MesaVariant.vip;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PreparandoPartidaScreen(
          vm: plan.preparacao,
          onConcluido: () {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => MesaScreen(
                  variant: variant,
                  modalidade: plan.launch.modalidade,
                  metaPontos: plan.launch.metaPontos,
                  tempoSegundos: plan.launch.tempoSegundos,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ConfigurarMesaScreen(
      vm: _vm,
      onVoltar: () => Navigator.of(context).maybePop(),
      // O tipo é escolhido exclusivamente em Onde jogar.
      onTipo: (_) {},
      onTipoBloqueado: (_) => _aviso('Ambiente exclusivo para jogador VIP'),
      onModalidade: (value) =>
          setState(() => _vm = _vm.copyWith(modalidade: value)),
      onVerRegras: _verRegras,
      onModo: _trocarModo,
      onPontos: (value) => setState(() => _vm = _vm.copyWith(pontos: value)),
      onAposta: (value) => setState(() {
        _vm = _vm.copyWith(
          aposta: _apostaComPote(_vm.aposta, valor: value),
        );
      }),
      onTempo: (value) => setState(() => _vm = _vm.copyWith(tempo: value)),
      onChat: (value) => setState(() => _vm = _vm.copyWith(chat: value)),
      onEspectadores: (value) =>
          setState(() => _vm = _vm.copyWith(espectadores: value)),
      onCopiar: _copiarCodigo,
      onAlternarCadeira: _alternarCadeira,
      onConvidarCadeira: (id) =>
          _aviso('Convite para $id — ligação real fica com o Claude'),
      onAcaoSocialPrivada: (id, acao) => _aviso(
        '${acao.name} em $id — persistência/moderação fica com o Claude',
      ),
      onCriarMesa: _criarMesa,
    );
  }
}
