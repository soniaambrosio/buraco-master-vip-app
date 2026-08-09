import 'package:flutter/material.dart';

enum AcaoSocialPrivada { silenciar, bloquear, denunciar }
enum PapelCadeiraPrivada { dono, parceiro, oponente }

class MesaPrivadaPolicy {
  const MesaPrivadaPolicy._();

  static const bool exigeVipParaCriar = true;
  static const bool exigeVipParaJogar = true;
  static const bool permitePasseConvidadoVip = true;
  static const bool espectadorPrecisaVip = false;

  static PapelCadeiraPrivada papelDaCadeira({
    required int quantidadeJogadores,
    required int indice,
  }) {
    if (indice == 0) return PapelCadeiraPrivada.dono;
    if (quantidadeJogadores == 2) return PapelCadeiraPrivada.oponente;
    if (indice == 1) return PapelCadeiraPrivada.parceiro;
    return PapelCadeiraPrivada.oponente;
  }

  static String papelLabel(PapelCadeiraPrivada papel) {
    switch (papel) {
      case PapelCadeiraPrivada.dono:
        return 'DONO';
      case PapelCadeiraPrivada.parceiro:
        return 'PARCEIRO';
      case PapelCadeiraPrivada.oponente:
        return 'OPONENTE';
    }
  }
}

class MesaPrivadaVipPolicyCard extends StatelessWidget {
  const MesaPrivadaVipPolicyCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(11, 10, 11, 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF27183A), Color(0xFF15100D)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF7654A5)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.workspace_premium_rounded,
              color: Color(0xFFEFB94A), size: 21),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Todos os jogadores são VIP',
                  style: TextStyle(
                    color: Color(0xFFF6E2A6),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'O código encontra a sala, mas não substitui a assinatura. Exceção: Passe Convidado VIP ocasional e válido.',
                  style: TextStyle(
                    color: Color(0xFFC9B9D7),
                    fontSize: 9.4,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MesaPrivadaChatSafetyCard extends StatelessWidget {
  const MesaPrivadaChatSafetyCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(11, 10, 11, 10),
      decoration: BoxDecoration(
        color: const Color(0xFF111710),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF315A3E)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.forum_rounded, color: Color(0xFF78E6A7), size: 19),
              SizedBox(width: 7),
              Expanded(
                child: Text(
                  'Chat livre, com proteção',
                  style: TextStyle(
                    color: Color(0xFFF6E2A6),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'A resenha faz parte da mesa. Se passar da zoeira para a ofensa, cada jogador pode agir sem interromper a partida.',
            style: TextStyle(
              color: Color(0xFFB8C7B9),
              fontSize: 9.4,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          const Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _SafetyChip(icon: Icons.volume_off_rounded, label: 'Silenciar'),
              _SafetyChip(icon: Icons.block_rounded, label: 'Bloquear'),
              _SafetyChip(icon: Icons.flag_outlined, label: 'Denunciar'),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Bloquear não expulsa automaticamente alguém de uma partida em andamento. Denúncias seguem para análise do sistema.',
            style: TextStyle(
              color: Color(0xFF88988A),
              fontSize: 8.5,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}

class MesaPrivadaPlayerSafetyMenuButton extends StatelessWidget {
  final String jogadorId;
  final void Function(String jogadorId, AcaoSocialPrivada acao)? onAcao;

  const MesaPrivadaPlayerSafetyMenuButton({
    super.key,
    required this.jogadorId,
    this.onAcao,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<AcaoSocialPrivada>(
      tooltip: 'Ações do jogador',
      color: const Color(0xFF1C130C),
      icon: const Icon(Icons.more_vert_rounded,
          color: Color(0xFFEFB94A), size: 20),
      onSelected: (acao) {
        if (onAcao != null) {
          onAcao!(jogadorId, acao);
          return;
        }
        final label = switch (acao) {
          AcaoSocialPrivada.silenciar => 'Silenciar',
          AcaoSocialPrivada.bloquear => 'Bloquear',
          AcaoSocialPrivada.denunciar => 'Denunciar',
        };
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text('$label — integração fica com o Claude'),
              duration: const Duration(milliseconds: 1300),
              backgroundColor: const Color(0xFF2A1B0E),
            ),
          );
      },
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: AcaoSocialPrivada.silenciar,
          child: _SafetyMenuRow(
            icon: Icons.volume_off_rounded,
            label: 'Silenciar para mim',
          ),
        ),
        PopupMenuItem(
          value: AcaoSocialPrivada.bloquear,
          child: _SafetyMenuRow(
            icon: Icons.block_rounded,
            label: 'Bloquear jogador',
          ),
        ),
        PopupMenuItem(
          value: AcaoSocialPrivada.denunciar,
          child: _SafetyMenuRow(
            icon: Icons.flag_outlined,
            label: 'Denunciar',
          ),
        ),
      ],
    );
  }
}

class MesaPrivadaChairRoleBadge extends StatelessWidget {
  final PapelCadeiraPrivada papel;

  const MesaPrivadaChairRoleBadge({super.key, required this.papel});

  @override
  Widget build(BuildContext context) {
    final parceiro = papel == PapelCadeiraPrivada.parceiro;
    final dono = papel == PapelCadeiraPrivada.dono;
    final color = dono
        ? const Color(0xFFEFB94A)
        : parceiro
            ? const Color(0xFF78E6A7)
            : const Color(0xFFE7B7A6);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: .55)),
      ),
      child: Text(
        MesaPrivadaPolicy.papelLabel(papel),
        style: TextStyle(
          color: color,
          fontSize: 8.2,
          fontWeight: FontWeight.w900,
          letterSpacing: .25,
        ),
      ),
    );
  }
}

class _SafetyChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SafetyChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF182319),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF2C4632)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: const Color(0xFF78E6A7)),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFD7E1D8),
              fontSize: 8.8,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SafetyMenuRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SafetyMenuRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFFEFB94A), size: 18),
        const SizedBox(width: 9),
        Text(label, style: const TextStyle(color: Color(0xFFF3E9D7))),
      ],
    );
  }
}
