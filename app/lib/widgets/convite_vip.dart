import 'package:flutter/material.dart';

// ============================================================================
// CONVITE VIP — componente reutilizável do convite de assinatura recorrente.
// Usado por toda tela com recurso VIP (Amigos, Salão VIP do Lobby, etc.).
//
// Os PLANOS ficam num lugar só (kVipPlanos) — mudou preço? edita AQUI e muda
// em todas as telas de uma vez. Preços: TABELA-PRECOS.md. Fase B: o botão liga
// no Google Play Billing + infra conta.vip/ehVip(). Ver ASSINATURA-VIP-INFRA.md.
//
// Dois modos:
//   • ConviteVip(...)            → conteúdo rolável (pra tela cheia: cai dentro
//                                   de um Expanded/Scaffold, como no Amigos).
//   • mostrarConviteVip(context) → abre o mesmo convite como folha (bottom
//                                   sheet) — pra gate contextual (ex.: não-VIP
//                                   toca em "Criar mesa privada" ou na porta VIP).
// ============================================================================

class VipPlano {
  final String id; // 'semanal' | 'mensal' | 'anual'
  final String nome;
  final String preco;
  final String periodo;
  final String? selo;
  const VipPlano(this.id, this.nome, this.preco, this.periodo, [this.selo]);
}

/// Fonte única dos planos (TABELA-PRECOS.md). Mudou preço? é só aqui.
const List<VipPlano> kVipPlanos = [
  VipPlano('semanal', 'Semanal', 'R\$ 7,90', 'por semana'),
  VipPlano('mensal', 'Mensal', 'R\$ 19,90', 'por mês', '⭐ mais vendido'),
  VipPlano('anual', 'Anual', 'R\$ 132,90', '≈ R\$ 11/mês', '💎 44% OFF'),
];

const String kVipPlanoPadrao = 'mensal';

/// Abre o convite VIP como folha (bottom sheet) — gate contextual.
/// O [onAssinar] recebe o id do plano escolhido (a folha se fecha antes).
Future<void> mostrarConviteVip(
  BuildContext context, {
  required String titulo,
  required String subtitulo,
  required List<String> beneficios,
  required ValueChanged<String> onAssinar,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF160F08),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.9,
        ),
        child: ConviteVip(
          titulo: titulo,
          subtitulo: subtitulo,
          beneficios: beneficios,
          onAssinar: (plano) {
            Navigator.of(ctx).pop();
            onAssinar(plano);
          },
        ),
      ),
    ),
  );
}

class ConviteVip extends StatefulWidget {
  final String titulo;
  final String subtitulo;
  final List<String> beneficios;
  final ValueChanged<String> onAssinar; // recebe o id do plano
  final EdgeInsets padding;

  const ConviteVip({
    super.key,
    required this.titulo,
    required this.subtitulo,
    required this.beneficios,
    required this.onAssinar,
    this.padding = const EdgeInsets.fromLTRB(16, 4, 16, 24),
  });

  @override
  State<ConviteVip> createState() => _ConviteVipState();
}

class _ConviteVipState extends State<ConviteVip> {
  static const _gold = Color(0xFFEFB94A);
  static const _goldHi = Color(0xFFF6E2A6);
  static const _card = Color(0xFF1C130C);
  static const _texto = Color(0xFFEFE3CC);
  static const _mut = Color(0xFF9A8C6C);

  String _sel = kVipPlanoPadrao;

  @override
  Widget build(BuildContext context) {
    return ListView(
      shrinkWrap: true,
      padding: widget.padding,
      children: [
        // herói
        Container(
          margin: const EdgeInsets.only(top: 6),
          padding: const EdgeInsets.fromLTRB(18, 22, 18, 20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF2A1E0C), Color(0xFF191007)],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0x66EFB94A), width: 1.5),
          ),
          child: Column(
            children: [
              const Text('👑', style: TextStyle(fontSize: 44)),
              const SizedBox(height: 8),
              Text(widget.titulo,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: _goldHi, fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text(widget.subtitulo,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFFD9C79A), fontSize: 12.5, height: 1.35)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // benefícios
        ...widget.beneficios.map((b) => Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('✓', style: TextStyle(color: _gold, fontSize: 15, fontWeight: FontWeight.w900)),
                  const SizedBox(width: 10),
                  Expanded(child: Text(b, style: const TextStyle(color: _texto, fontSize: 13, height: 1.3))),
                ],
              ),
            )),
        const SizedBox(height: 10),
        const Text('ESCOLHA SEU PLANO',
            style: TextStyle(color: _gold, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.4)),
        const SizedBox(height: 10),
        ...kVipPlanos.map(_planoCard),
        const SizedBox(height: 6),
        // CTA
        GestureDetector(
          onTap: () => widget.onAssinar(_sel),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 15),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFF6E2A6), Color(0xFFE0A83A)]),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: const Text('Virar VIP 👑',
                style: TextStyle(color: Color(0xFF3A2606), fontSize: 15.5, fontWeight: FontWeight.w900)),
          ),
        ),
        const SizedBox(height: 10),
        const Text('Assinatura recorrente — renova sozinha, cancele quando quiser na Google Play.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _mut, fontSize: 10.5, height: 1.3)),
      ],
    );
  }

  Widget _planoCard(VipPlano p) {
    final on = _sel == p.id;
    return GestureDetector(
      onTap: () => setState(() => _sel = p.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 9),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: on ? const Color(0xFF2A1E0C) : _card,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: on ? _gold : const Color(0x22FFFFFF), width: on ? 1.8 : 1),
        ),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: on ? _gold : _mut, width: 2),
                color: on ? _gold : Colors.transparent,
              ),
              alignment: Alignment.center,
              child: on ? const Icon(Icons.check, size: 13, color: Color(0xFF3A2606)) : const SizedBox.shrink(),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(p.nome,
                          style: const TextStyle(color: _texto, fontSize: 14.5, fontWeight: FontWeight.w800)),
                      if (p.selo != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0x33EFB94A),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Text(p.selo!,
                              style: const TextStyle(color: _goldHi, fontSize: 9.5, fontWeight: FontWeight.w800)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(p.periodo, style: const TextStyle(color: _mut, fontSize: 11)),
                ],
              ),
            ),
            Text(p.preco, style: const TextStyle(color: _goldHi, fontSize: 15, fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }
}
