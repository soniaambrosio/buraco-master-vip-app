import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../screens/perfil_screen.dart';
import '../services/perfil_service.dart';
import '../sessao/escopo_sessao.dart';
import '../sessao/identidade_publica_sessao.dart';

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

  /// O `publicId` com que o VM atual foi montado. É o que permite distinguir
  /// "a identidade mudou" de "o widget reconstruiu".
  String? _publicIdCarregado;
  bool _jaCarregou = false;

  /// O Perfil não pede identidade — ele REAGE à identidade da sessão.
  ///
  /// A recarga acontece quando o `publicId` canônico MUDA (chegou, ou trocou
  /// junto com o usuário), nunca a cada reconstrução. §20: um `build` não pode
  /// virar consulta. No pior caso são duas cargas — uma antes de a identidade
  /// chegar, outra quando ela chega — e nunca uma por frame.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final sessao = EscopoSessao.identidadeDe(context);
    if (_jaCarregou && sessao.publicId == _publicIdCarregado) return;
    _jaCarregou = true;
    _publicIdCarregado = sessao.publicId;
    _carregar();
  }

  Future<void> _carregar() async {
    // Lido do escopo a cada carga: o Perfil consome o MESMO estado canônico que
    // Ranking e Social — não existe `identidadeDoPerfil`.
    final IdentidadePublica? identidade = EscopoSessao.identidadeDe(
      context,
    ).identidade;
    setState(() {
      _estado = PerfilEstado.carregando;
      _erro = null;
    });
    try {
      final vm = await _service.carregar(
        ehMeuPerfil: widget.ehMeuPerfil,
        identidade: identidade,
      );
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

  /// O convite leva só o que a tela pode afirmar.
  ///
  /// Antes ele montava 'Nível ${vm?.nivel ?? 1} · Liga ${vm?.liga ?? 'Bronze'}'
  /// — com os `??`, o texto copiado dizia "Nível 1 · Liga Bronze" mesmo quando
  /// não havia nível nem liga em lugar nenhum. Era a afirmação inventada da tela
  /// saindo do aplicativo pela área de transferência, que é o pior destino
  /// possível para ela: vai para o WhatsApp de outra pessoa.
  Future<void> _compartilhar() async {
    final vm = _vm;
    final nome = vm?.nome ?? 'Jogador(a)';
    final nivel = vm?.nivel;
    final liga = vm?.liga;
    final selo = [
      if (nivel != null) 'Nível $nivel',
      if (liga != null) 'Liga $liga',
    ].join(' · ');
    final texto =
        'Vem jogar Buraco comigo no Buraco Master VIP! Sou $nome 👑'
        '${selo.isEmpty ? '' : ' $selo.'}';
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
