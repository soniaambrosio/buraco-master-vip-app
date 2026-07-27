import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../screens/perfil_screen.dart';
import '../services/perfil_service.dart';

/// Controlador da tela de Perfil (camada de lógica — Claude).
///
/// Responsabilidade: carregar o [PerfilVM] pelo [PerfilService], administrar os
/// estados (carregando/normal/erro) e ligar os 14 callbacks da UI a ações reais.
/// NÃO altera o visual — a interface é 100% do [PerfilScreen] (Codex).
///
/// FASE 1: identidade real (nome do Firebase) + arquitetura pronta; números ainda
/// de demonstração (ver [PerfilService.statsDemo]). As ações que dependem de telas
/// futuras (config, editar, loja, ranking) mostram um aviso "chega já já".
class PerfilPage extends StatefulWidget {
  const PerfilPage({super.key, this.ehMeuPerfil = true});

  /// true = perfil do próprio dono (mostra editar/câmera/trocar vitrine).
  /// false = visitando outro jogador (a UI oculta os controles de dono).
  final bool ehMeuPerfil;

  @override
  State<PerfilPage> createState() => _PerfilPageState();
}

class _PerfilPageState extends State<PerfilPage> {
  static const _service = PerfilService();

  PerfilEstado _estado = PerfilEstado.carregando;
  PerfilVM? _vm;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() {
      _estado = PerfilEstado.carregando;
      _erro = null;
    });
    try {
      final vm = await _service.carregar(ehMeuPerfil: widget.ehMeuPerfil);
      if (!mounted) return;
      setState(() {
        _vm = vm;
        _estado = PerfilEstado.normal;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _estado = PerfilEstado.erro;
        _erro = 'Não consegui carregar seu perfil agora. Tenta de novo?';
      });
    }
  }

  /// Aviso curto para ações cuja tela ainda não existe (próximas fatias).
  void _breve(String o) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('$o — chega nas próximas fatias 👍'),
          duration: const Duration(milliseconds: 1300),
          backgroundColor: const Color(0xFF2A1B0E),
        ),
      );
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(msg),
          duration: const Duration(milliseconds: 1600),
          backgroundColor: const Color(0xFF2A1B0E),
        ),
      );
  }

  Future<void> _compartilhar() async {
    final vm = _vm;
    final nome = vm?.nome ?? 'Jogador(a)';
    final texto =
        'Vem jogar Buraco comigo no Buraco Master VIP! Sou $nome 👑 '
        'Nível ${vm?.nivel ?? 1} · Liga ${vm?.liga ?? 'Bronze'}.';
    await Clipboard.setData(ClipboardData(text: texto));
    if (!mounted) return;
    _toast('Convite copiado! É só colar e mandar pra galera 🎉');
  }

  @override
  Widget build(BuildContext context) {
    // Na carga usa o placeholder do serviço (a própria tela mostra skeleton).
    final vm = _vm ?? _service.vmPlaceholder();

    return PerfilScreen(
      vm: vm,
      estado: _estado,
      mensagemErro: _erro,
      onVoltar: () => Navigator.of(context).maybePop(),
      onAbrirConfig: () => _breve('Configurações do perfil'),
      onTrocarAvatar: () => _breve('Trocar avatar'),
      onEditarNick: () => _breve('Editar apelido'),
      onEditarPerfil: () => _breve('Editar perfil'),
      // O bottom-sheet de presentes é interno à tela — nada a fazer aqui.
      onAbrirPresentes: () {},
      onFecharPresentes: () {},
      onVerTodasConquistas: () => _breve('Todas as conquistas'),
      onVerConquista: (id) => _breve('Conquista: $id'),
      onVerUltimaConquista: () => _breve('Última conquista'),
      onTrocarVitrine: () => _breve('Trocar itens da vitrine'),
      onCompartilhar: _compartilhar,
      onRecarregar: _carregar,
      onNavTap: (destino) {
        switch (destino) {
          case NavDestino.inicio:
            Navigator.of(context).maybePop();
            break;
          case NavDestino.ranking:
            _breve('Ranking');
            break;
          case NavDestino.loja:
            _breve('Loja VIP');
            break;
          case NavDestino.perfil:
            // já estamos no perfil
            break;
        }
      },
    );
  }
}
