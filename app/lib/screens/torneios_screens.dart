import 'dart:async';

import 'package:flutter/material.dart';

import 'torneios_models.dart';

class TorneiosPalette {
  static const gold = Color(0xFFEFB94A);
  static const goldHi = Color(0xFFF6E2A6);
  static const purple = Color(0xFF8F5EE8);
  static const amethyst = Color(0xFFB98BFF);
  static const bgTop = Color(0xFF241812);
  static const bgMid = Color(0xFF120A06);
  static const bgBottom = Color(0xFF000000);
  static const card = Color(0xFF1C130C);
  static const card2 = Color(0xFF24152C);
  static const border = Color(0x44EFB94A);
  static const text = Color(0xFFF0E5D1);
  static const textMuted = Color(0xFFB7A88D);
  static const success = Color(0xFF4DC989);
  static const danger = Color(0xFFE66A78);
  static const warning = Color(0xFFF4C35B);
}

String torneioData(DateTime dt) {
  const meses = ['jan', 'fev', 'mar', 'abr', 'mai', 'jun', 'jul', 'ago', 'set', 'out', 'nov', 'dez'];
  final dia = dt.day.toString().padLeft(2, '0');
  final hora = dt.hour.toString().padLeft(2, '0');
  final min = dt.minute.toString().padLeft(2, '0');
  return '$dia ${meses[dt.month - 1]} · $hora:$min';
}

String torneioDuracao(Duration d) {
  if (d.inSeconds <= 0) return 'encerrado';
  if (d.inDays > 0) return '${d.inDays}d ${d.inHours.remainder(24)}h';
  if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes.remainder(60)}min';
  final m = d.inMinutes.toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$m:$s';
}

String _acessoLabel(TipoAcesso acesso) => switch (acesso) {
      TipoAcesso.publico => 'PÚBLICO',
      TipoAcesso.vip => 'VIP',
      TipoAcesso.misto => 'MISTO',
    };

String _participacaoLabel(TipoParticipacao tipo) =>
    tipo == TipoParticipacao.dupla ? 'DUPLAS' : 'INDIVIDUAL';

String _entradaLabel(TorneioCardVM item) => item.entrada == TipoEntrada.gratuito
    ? 'GRÁTIS'
    : '${item.valorEntrada} FICHAS';

IconData _statusIcon(TorneioStatus status) => switch (status) {
      TorneioStatus.inscricoesAbertas => Icons.how_to_reg_rounded,
      TorneioStatus.checkinAberto => Icons.task_alt_rounded,
      TorneioStatus.preparandoMesas => Icons.grid_view_rounded,
      TorneioStatus.emAndamento => Icons.sports_esports_rounded,
      TorneioStatus.aguardandoValidacao => Icons.fact_check_rounded,
      TorneioStatus.encerrado => Icons.emoji_events_rounded,
      TorneioStatus.cancelado => Icons.cancel_rounded,
      TorneioStatus.suspenso => Icons.pause_circle_filled_rounded,
      _ => Icons.event_rounded,
    };

Color _statusColor(TorneioStatus status) => switch (status) {
      TorneioStatus.inscricoesAbertas => TorneiosPalette.success,
      TorneioStatus.checkinAberto => TorneiosPalette.warning,
      TorneioStatus.preparandoMesas => TorneiosPalette.amethyst,
      TorneioStatus.emAndamento => TorneiosPalette.purple,
      TorneioStatus.aguardandoValidacao => TorneiosPalette.warning,
      TorneioStatus.encerrado => TorneiosPalette.gold,
      TorneioStatus.cancelado => TorneiosPalette.danger,
      TorneioStatus.suspenso => TorneiosPalette.danger,
      _ => TorneiosPalette.textMuted,
    };

class TorneiosShell extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final List<Widget> actions;
  final Widget child;
  final Widget? bottom;
  final bool scroll;

  const TorneiosShell({
    super.key,
    required this.title,
    this.subtitle,
    this.onBack,
    this.actions = const [],
    required this.child,
    this.bottom,
    this.scroll = false,
  });

  @override
  Widget build(BuildContext context) {
    final content = scroll
        ? SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            child: child,
          )
        : child;
    return Scaffold(
      backgroundColor: Colors.black,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              TorneiosPalette.bgTop,
              TorneiosPalette.bgMid,
              TorneiosPalette.bgBottom,
            ],
            stops: [0, .52, 1],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                children: [
                  _TorneiosHeader(
                    title: title,
                    subtitle: subtitle,
                    onBack: onBack,
                    actions: actions,
                  ),
                  Expanded(child: content),
                  if (bottom != null) bottom!,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TorneiosHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final List<Widget> actions;

  const _TorneiosHeader({
    required this.title,
    this.subtitle,
    this.onBack,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: const BoxDecoration(
        color: Color(0xCC120A06),
        border: Border(bottom: BorderSide(color: TorneiosPalette.border)),
      ),
      child: Row(
        children: [
          if (onBack != null)
            IconButton(
              tooltip: 'Voltar',
              onPressed: onBack,
              icon: const Icon(Icons.chevron_left_rounded, color: TorneiosPalette.gold, size: 30),
            )
          else
            const SizedBox(width: 48),
          Expanded(
            child: Column(
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: TorneiosPalette.goldHi,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .3,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: TorneiosPalette.textMuted,
                      fontSize: 10.5,
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(
            width: 48.0 * (actions.isEmpty ? 1 : actions.length),
            child: Row(mainAxisAlignment: MainAxisAlignment.end, children: actions),
          ),
        ],
      ),
    );
  }
}

class TorneioPill extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const TorneioPill(this.label, {super.key, this.color = TorneiosPalette.gold, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withValues(alpha: .45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: color, size: 12),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(color: color, fontSize: 9.5, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class TorneioSectionTitle extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;

  const TorneioSectionTitle(this.title, {super.key, this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 18, 2, 9),
      child: Row(
        children: [
          Container(width: 3, height: 16, decoration: BoxDecoration(color: TorneiosPalette.purple, borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title.toUpperCase(),
              style: const TextStyle(
                color: TorneiosPalette.gold,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.3,
              ),
            ),
          ),
          if (action != null)
            TextButton(onPressed: onAction, child: Text(action!, style: const TextStyle(color: TorneiosPalette.amethyst, fontSize: 11))),
        ],
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Color? color;
  final VoidCallback? onTap;

  const _GlassCard({required this.child, this.padding = const EdgeInsets.all(14), this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    final box = Ink(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? TorneiosPalette.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: TorneiosPalette.border),
      ),
      child: child,
    );
    if (onTap == null) return box;
    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(16), child: box),
    );
  }
}

// -----------------------------------------------------------------------------
// TELA 1 — CENTRAL DE TORNEIOS
// -----------------------------------------------------------------------------
class CentralTorneiosScreen extends StatefulWidget {
  final List<TorneioCardVM> torneios;
  final TorneiosCallbacks callbacks;
  final VoidCallback onVoltar;
  final VoidCallback? onAbrirAdmin;
  final VoidCallback? onAbrirCenariosMock;
  final bool mostrarAdmin;

  const CentralTorneiosScreen({
    super.key,
    required this.torneios,
    required this.callbacks,
    required this.onVoltar,
    this.onAbrirAdmin,
    this.onAbrirCenariosMock,
    this.mostrarAdmin = false,
  });

  @override
  State<CentralTorneiosScreen> createState() => _CentralTorneiosScreenState();
}

class _CentralTorneiosScreenState extends State<CentralTorneiosScreen> {
  SecaoCentral _secao = SecaoCentral.destaque;
  final Set<String> _filtros = {};

  List<TorneioCardVM> get _visiveis {
    var lista = widget.torneios.where((item) => _secao == SecaoCentral.destaque ? item.secao == SecaoCentral.destaque : item.secao == _secao).toList();
    if (_filtros.isEmpty) return lista;
    return lista.where((item) {
      if (_filtros.contains('gratuitos') && item.entrada != TipoEntrada.gratuito) return false;
      if (_filtros.contains('fichas') && item.entrada != TipoEntrada.fichas) return false;
      if (_filtros.contains('vip') && item.acesso != TipoAcesso.vip) return false;
      if (_filtros.contains('publico') && item.acesso != TipoAcesso.publico) return false;
      if (_filtros.contains('duplas') && item.participacao != TipoParticipacao.dupla) return false;
      if (_filtros.contains('individual') && item.participacao != TipoParticipacao.individual) return false;
      if (_filtros.contains('aberto') && item.modalidade != ModalidadeTorneio.aberto) return false;
      if (_filtros.contains('fechado') && item.modalidade != ModalidadeTorneio.fechado) return false;
      if (_filtros.contains('stbl') && item.modalidade != ModalidadeTorneio.stbl) return false;
      return true;
    }).toList();
  }

  void _alternarFiltro(String filtro) {
    setState(() {
      _filtros.contains(filtro) ? _filtros.remove(filtro) : _filtros.add(filtro);
    });
    widget.callbacks.onFiltrarCentral(Set.unmodifiable(_filtros));
  }

  @override
  Widget build(BuildContext context) {
    final visiveis = _visiveis;
    return TorneiosShell(
      title: 'Torneios',
      subtitle: 'competição oficial · regras auditadas',
      onBack: widget.onVoltar,
      actions: [
        IconButton(
          tooltip: 'Filtros',
          onPressed: () => _abrirFiltros(context),
          icon: Badge(
            isLabelVisible: _filtros.isNotEmpty,
            label: Text('${_filtros.length}'),
            child: const Icon(Icons.tune_rounded, color: TorneiosPalette.goldHi),
          ),
        ),
        if (widget.onAbrirCenariosMock != null)
          IconButton(
            tooltip: 'Cenários mock',
            onPressed: widget.onAbrirCenariosMock,
            icon: const Icon(Icons.science_rounded, color: TorneiosPalette.warning),
          ),
        if (widget.mostrarAdmin)
          IconButton(
            tooltip: 'Administração',
            onPressed: widget.onAbrirAdmin,
            icon: const Icon(Icons.admin_panel_settings_rounded, color: TorneiosPalette.amethyst),
          ),
      ],
      child: Column(
        children: [
          _CentralHero(total: widget.torneios.length, meus: widget.torneios.where((e) => e.inscrito).length),
          _SecoesCentral(ativa: _secao, onChanged: (value) => setState(() => _secao = value)),
          if (_filtros.isNotEmpty)
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  for (final f in _filtros)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: InputChip(
                        label: Text(f.toUpperCase()),
                        onDeleted: () => _alternarFiltro(f),
                        backgroundColor: TorneiosPalette.purple.withValues(alpha: .16),
                        side: BorderSide(color: TorneiosPalette.purple.withValues(alpha: .45)),
                        labelStyle: const TextStyle(color: TorneiosPalette.amethyst, fontSize: 9),
                        deleteIconColor: TorneiosPalette.amethyst,
                      ),
                    ),
                ],
              ),
            ),
          Expanded(
            child: visiveis.isEmpty
                ? const _TorneiosEmpty()
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                    itemCount: visiveis.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 11),
                    itemBuilder: (context, index) => TorneioCard(
                      vm: visiveis[index],
                      destaque: _secao == SecaoCentral.destaque,
                      onTap: () => widget.callbacks.onAbrirDetalhes(visiveis[index].tournamentId),
                      onAction: () => visiveis[index].status == TorneioStatus.inscricoesAbertas
                          ? widget.callbacks.onInscrever(visiveis[index].tournamentId)
                          : widget.callbacks.onAbrirDetalhes(visiveis[index].tournamentId),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  void _abrirFiltros(BuildContext context) {
    const filtros = [
      ('gratuitos', 'Gratuitos'),
      ('fichas', 'Com fichas'),
      ('publico', 'Público'),
      ('vip', 'VIP'),
      ('individual', 'Individual'),
      ('duplas', 'Duplas'),
      ('aberto', 'Aberto'),
      ('fechado', 'Fechado'),
      ('stbl', 'STBL'),
    ];
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF130B08),
      showDragHandle: true,
      builder: (_) => StatefulBuilder(
        builder: (context, modalSetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Filtrar torneios', style: TextStyle(color: TorneiosPalette.goldHi, fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final f in filtros)
                      FilterChip(
                        label: Text(f.$2),
                        selected: _filtros.contains(f.$1),
                        onSelected: (_) {
                          _alternarFiltro(f.$1);
                          modalSetState(() {});
                        },
                        selectedColor: TorneiosPalette.purple.withValues(alpha: .30),
                        checkmarkColor: TorneiosPalette.goldHi,
                        side: BorderSide(color: _filtros.contains(f.$1) ? TorneiosPalette.purple : TorneiosPalette.border),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: FilledButton.styleFrom(backgroundColor: TorneiosPalette.gold, foregroundColor: const Color(0xFF2F1D05)),
                    child: const Text('Aplicar filtros'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CentralHero extends StatelessWidget {
  final int total;
  final int meus;

  const _CentralHero({required this.total, required this.meus});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(colors: [Color(0xFF4C2475), Color(0xFF25152F), Color(0xFF1B100A)]),
        border: Border.all(color: TorneiosPalette.amethyst.withValues(alpha: .55)),
      ),
      child: Row(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(colors: [TorneiosPalette.goldHi, TorneiosPalette.gold, Color(0xFF7C5215)]),
              border: Border.all(color: Colors.white.withValues(alpha: .45), width: 1.5),
            ),
            child: const Icon(Icons.emoji_events_rounded, color: Color(0xFF3A2206), size: 34),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('A mesa fica séria agora.', style: TextStyle(color: TorneiosPalette.goldHi, fontSize: 17, fontWeight: FontWeight.w900)),
                const SizedBox(height: 3),
                const Text('Inscreva-se, faça o check-in e acompanhe cada rodada.', style: TextStyle(color: Color(0xFFD8C7EA), fontSize: 11.5, height: 1.3)),
                const SizedBox(height: 9),
                Row(
                  children: [
                    TorneioPill('$total torneios', color: TorneiosPalette.gold),
                    const SizedBox(width: 6),
                    TorneioPill('$meus inscritos', color: TorneiosPalette.success),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SecoesCentral extends StatelessWidget {
  final SecaoCentral ativa;
  final ValueChanged<SecaoCentral> onChanged;

  const _SecoesCentral({required this.ativa, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const labels = {
      SecaoCentral.destaque: 'Destaque',
      SecaoCentral.inscricoesAbertas: 'Abertas',
      SecaoCentral.proximos: 'Próximos',
      SecaoCentral.emAndamento: 'Ao vivo',
      SecaoCentral.meus: 'Meus',
      SecaoCentral.encerrados: 'Encerrados',
    };
    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          for (final item in SecaoCentral.values)
            Padding(
              padding: const EdgeInsets.only(right: 7),
              child: ChoiceChip(
                label: Text(labels[item]!),
                selected: item == ativa,
                onSelected: (_) => onChanged(item),
                selectedColor: TorneiosPalette.purple.withValues(alpha: .34),
                backgroundColor: TorneiosPalette.card,
                side: BorderSide(color: item == ativa ? TorneiosPalette.amethyst : TorneiosPalette.border),
                labelStyle: TextStyle(
                  color: item == ativa ? TorneiosPalette.goldHi : TorneiosPalette.textMuted,
                  fontSize: 10.5,
                  fontWeight: item == ativa ? FontWeight.w800 : FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class TorneioCard extends StatelessWidget {
  final TorneioCardVM vm;
  final bool destaque;
  final VoidCallback onTap;
  final VoidCallback onAction;

  const TorneioCard({super.key, required this.vm, required this.destaque, required this.onTap, required this.onAction});

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(vm.status);
    final progress = vm.vagasTotais == 0 ? 0.0 : (vm.inscritos / vm.vagasTotais).clamp(0.0, 1.0);
    return _GlassCard(
      onTap: onTap,
      color: destaque ? const Color(0xFF25152C) : TorneiosPalette.card,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Container(
            height: destaque ? 92 : 70,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
              gradient: LinearGradient(
                colors: destaque
                    ? const [Color(0xFF5D2C8A), Color(0xFF2A1539), Color(0xFF25150B)]
                    : const [Color(0xFF2D1B12), Color(0xFF1C130C)],
              ),
            ),
            child: Stack(
              children: [
                Positioned(right: 16, top: 11, child: Icon(Icons.emoji_events_rounded, color: TorneiosPalette.gold.withValues(alpha: .18), size: destaque ? 76 : 54)),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 9),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          TorneioPill(vm.modalidade.label, color: TorneiosPalette.gold),
                          const SizedBox(width: 5),
                          TorneioPill(_acessoLabel(vm.acesso), color: vm.acesso == TipoAcesso.vip ? TorneiosPalette.amethyst : TorneiosPalette.textMuted),
                          const Spacer(),
                          TorneioPill(vm.status.label, color: statusColor, icon: _statusIcon(vm.status)),
                        ],
                      ),
                      const Spacer(),
                      Text(vm.nome, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: TorneiosPalette.goldHi, fontSize: 16, fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 13),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _IconText(Icons.calendar_month_rounded, torneioData(vm.dataHora))),
                    Expanded(child: _IconText(Icons.groups_2_rounded, _participacaoLabel(vm.participacao))),
                    Expanded(child: _IconText(Icons.local_activity_rounded, _entradaLabel(vm))),
                  ],
                ),
                const SizedBox(height: 11),
                Row(
                  children: [
                    const Icon(Icons.workspace_premium_rounded, color: TorneiosPalette.gold, size: 18),
                    const SizedBox(width: 7),
                    Expanded(child: Text(vm.premiacaoPrincipal, style: const TextStyle(color: TorneiosPalette.text, fontSize: 11.5, fontWeight: FontWeight.w700))),
                  ],
                ),
                const SizedBox(height: 11),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          minHeight: 6,
                          value: progress,
                          backgroundColor: Colors.white.withValues(alpha: .07),
                          valueColor: AlwaysStoppedAnimation(progress > .9 ? TorneiosPalette.warning : TorneiosPalette.purple),
                        ),
                      ),
                    ),
                    const SizedBox(width: 9),
                    Text('${vm.inscritos}/${vm.vagasTotais}', style: const TextStyle(color: TorneiosPalette.textMuted, fontSize: 10.5)),
                  ],
                ),
                const SizedBox(height: 11),
                Row(
                  children: [
                    if (vm.tempoRestanteInscricao != null && vm.tempoRestanteInscricao!.inSeconds > 0)
                      Expanded(child: Text('Inscrições por ${torneioDuracao(vm.tempoRestanteInscricao!)}', style: const TextStyle(color: TorneiosPalette.warning, fontSize: 10.5, fontWeight: FontWeight.w700)))
                    else
                      const Spacer(),
                    FilledButton.tonal(
                      onPressed: onAction,
                      style: FilledButton.styleFrom(backgroundColor: TorneiosPalette.purple.withValues(alpha: .24), foregroundColor: TorneiosPalette.goldHi, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9)),
                      child: Text(vm.status == TorneioStatus.inscricoesAbertas ? 'Inscrever' : 'Ver detalhes'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IconText extends StatelessWidget {
  final IconData icon;
  final String text;

  const _IconText(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: TorneiosPalette.amethyst, size: 17),
        const SizedBox(height: 3),
        Text(text, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: TorneiosPalette.textMuted, fontSize: 9.5, height: 1.15)),
      ],
    );
  }
}

class _TorneiosEmpty extends StatelessWidget {
  const _TorneiosEmpty();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.emoji_events_outlined, color: TorneiosPalette.textMuted, size: 48),
            SizedBox(height: 12),
            Text('Nenhum torneio neste filtro.', style: TextStyle(color: TorneiosPalette.textMuted)),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// TELA 2 — DETALHES
// -----------------------------------------------------------------------------
class TorneioDetalhesScreen extends StatelessWidget {
  final TorneioDetalhesVM vm;
  final TorneiosCallbacks callbacks;
  final VoidCallback onVoltar;

  const TorneioDetalhesScreen({super.key, required this.vm, required this.callbacks, required this.onVoltar});

  @override
  Widget build(BuildContext context) {
    return TorneiosShell(
      title: 'Detalhes do torneio',
      subtitle: vm.card.nome,
      onBack: onVoltar,
      scroll: true,
      bottom: _DetalhesActions(vm: vm, callbacks: callbacks),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DetalhesHero(card: vm.card),
          if (vm.minhaInscricao != null) ...[
            const SizedBox(height: 10),
            _StatusMinhaInscricao(status: vm.minhaInscricao!),
          ],
          const TorneioSectionTitle('Sobre'),
          _GlassCard(child: Text(vm.descricao, style: const TextStyle(color: TorneiosPalette.text, fontSize: 12.5, height: 1.45))),
          const TorneioSectionTitle('Agenda e formato'),
          _GlassCard(
            child: Column(
              children: [
                _DetailLine(Icons.calendar_today_rounded, 'Início', torneioData(vm.card.dataHora)),
                _DetailLine(Icons.fact_check_rounded, 'Check-in', '${torneioData(vm.checkinAbre)} até ${torneioData(vm.checkinFecha)}'),
                _DetailLine(Icons.repeat_rounded, 'Rodadas previstas', '${vm.rodadasPrevistas}'),
                _DetailLine(Icons.flag_rounded, 'Classificação', vm.criteriosClassificacao),
              ],
            ),
          ),
          const TorneioSectionTitle('Premiação'),
          _PremiacoesList(premios: vm.premiacoes),
          const TorneioSectionTitle('Regulamento'),
          _InfoExpansivel(title: 'Regras da modalidade', text: vm.regras),
          _InfoExpansivel(title: 'Critérios de desempate', text: vm.criteriosDesempate),
          _InfoExpansivel(title: 'Abandono', text: vm.regrasAbandono),
          _InfoExpansivel(title: 'Desconexão e reconexão', text: vm.regrasDesconexao),
          _InfoExpansivel(title: 'Cancelamento', text: vm.politicaCancelamento),
          const SizedBox(height: 96),
        ],
      ),
    );
  }
}

class _DetalhesHero extends StatelessWidget {
  final TorneioCardVM card;

  const _DetalhesHero({required this.card});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF5B2A82), Color(0xFF2C1736), Color(0xFF1A100B)]),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: TorneiosPalette.amethyst.withValues(alpha: .55)),
      ),
      child: Column(
        children: [
          const Icon(Icons.emoji_events_rounded, color: TorneiosPalette.gold, size: 54),
          const SizedBox(height: 8),
          Text(card.nome, textAlign: TextAlign.center, style: const TextStyle(color: TorneiosPalette.goldHi, fontSize: 21, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 6,
            runSpacing: 6,
            children: [
              TorneioPill(card.modalidade.label, color: TorneiosPalette.gold),
              TorneioPill(_acessoLabel(card.acesso), color: TorneiosPalette.amethyst),
              TorneioPill(_participacaoLabel(card.participacao), color: TorneiosPalette.text),
              TorneioPill(_entradaLabel(card), color: TorneiosPalette.success),
            ],
          ),
          const SizedBox(height: 13),
          Text('${torneioData(card.dataHora)} · ${card.inscritos}/${card.vagasTotais} inscritos', style: const TextStyle(color: Color(0xFFDCCFE8), fontSize: 11.5)),
          const SizedBox(height: 8),
          Text(card.premiacaoPrincipal, textAlign: TextAlign.center, style: const TextStyle(color: TorneiosPalette.gold, fontSize: 13, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _StatusMinhaInscricao extends StatelessWidget {
  final StatusParticipante status;

  const _StatusMinhaInscricao({required this.status});

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      color: TorneiosPalette.purple.withValues(alpha: .14),
      child: Row(
        children: [
          const Icon(Icons.verified_rounded, color: TorneiosPalette.success),
          const SizedBox(width: 10),
          Expanded(child: Text('Sua participação: ${status.label}', style: const TextStyle(color: TorneiosPalette.text, fontWeight: FontWeight.w800))),
        ],
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailLine(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: TorneiosPalette.amethyst, size: 19),
          const SizedBox(width: 10),
          SizedBox(width: 104, child: Text(label, style: const TextStyle(color: TorneiosPalette.textMuted, fontSize: 11))),
          Expanded(child: Text(value, style: const TextStyle(color: TorneiosPalette.text, fontSize: 11.5, fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }
}

class _PremiacoesList extends StatelessWidget {
  final List<PremiacaoVM> premios;

  const _PremiacoesList({required this.premios});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final p in premios)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _GlassCard(
              child: Row(
                children: [
                  _PodioCircle(posicao: p.posicao),
                  const SizedBox(width: 12),
                  Expanded(child: Text(p.valorLabel, style: const TextStyle(color: TorneiosPalette.text, fontSize: 12, fontWeight: FontWeight.w800))),
                  TorneioPill(p.statusEntrega.toUpperCase(), color: p.statusEntrega == 'entregue' ? TorneiosPalette.success : TorneiosPalette.gold),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _PodioCircle extends StatelessWidget {
  final int posicao;

  const _PodioCircle({required this.posicao});

  @override
  Widget build(BuildContext context) {
    final color = posicao == 1 ? TorneiosPalette.gold : posicao == 2 ? const Color(0xFFCBD1D8) : const Color(0xFFC78355);
    return Container(
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: .16), border: Border.all(color: color)),
      child: Text('$posicaoº', style: TextStyle(color: color, fontWeight: FontWeight.w900)),
    );
  }
}

class _InfoExpansivel extends StatelessWidget {
  final String title;
  final String text;

  const _InfoExpansivel({required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          collapsedBackgroundColor: TorneiosPalette.card,
          backgroundColor: TorneiosPalette.card,
          collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: TorneiosPalette.border)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: TorneiosPalette.border)),
          iconColor: TorneiosPalette.amethyst,
          collapsedIconColor: TorneiosPalette.amethyst,
          title: Text(title, style: const TextStyle(color: TorneiosPalette.goldHi, fontSize: 12, fontWeight: FontWeight.w800)),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          children: [Text(text, style: const TextStyle(color: TorneiosPalette.textMuted, fontSize: 11.5, height: 1.45))],
        ),
      ),
    );
  }
}

class _DetalhesActions extends StatelessWidget {
  final TorneioDetalhesVM vm;
  final TorneiosCallbacks callbacks;

  const _DetalhesActions({required this.vm, required this.callbacks});

  @override
  Widget build(BuildContext context) {
    if (vm.botoes.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 10),
      decoration: const BoxDecoration(color: Color(0xF20D0805), border: Border(top: BorderSide(color: TorneiosPalette.border))),
      child: SafeArea(
        top: false,
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: 7,
          runSpacing: 7,
          children: [
            for (final b in vm.botoes)
              FilledButton.icon(
                onPressed: () => _acionar(b),
                style: FilledButton.styleFrom(
                  backgroundColor: b == BotaoTorneio.inscrever || b == BotaoTorneio.fazerCheckin ? TorneiosPalette.gold : TorneiosPalette.purple.withValues(alpha: .38),
                  foregroundColor: b == BotaoTorneio.inscrever || b == BotaoTorneio.fazerCheckin ? const Color(0xFF341E04) : TorneiosPalette.goldHi,
                ),
                icon: Icon(_botaoIcon(b), size: 17),
                label: Text(_botaoLabel(b), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
              ),
          ],
        ),
      ),
    );
  }

  void _acionar(BotaoTorneio b) {
    final id = vm.card.tournamentId;
    switch (b) {
      case BotaoTorneio.inscrever:
        callbacks.onInscrever(id);
        break;
      case BotaoTorneio.convidarDupla:
        callbacks.onInscrever(id);
        break;
      case BotaoTorneio.confirmarDupla:
        callbacks.onAceitarConvite(id);
        break;
      case BotaoTorneio.cancelarInscricao:
        callbacks.onCancelarInscricao(id);
        break;
      case BotaoTorneio.fazerCheckin:
        callbacks.onFazerCheckin(id);
        break;
      case BotaoTorneio.entrarSalaEspera:
        callbacks.onEntrarSalaEspera(id);
        break;
      case BotaoTorneio.verClassificacao:
        callbacks.onVerClassificacao(id);
        break;
      case BotaoTorneio.verResultado:
        callbacks.onVerResultado(id);
        break;
    }
  }

  static String _botaoLabel(BotaoTorneio b) => switch (b) {
        BotaoTorneio.inscrever => 'Inscrever-se',
        BotaoTorneio.convidarDupla => 'Escolher dupla',
        BotaoTorneio.confirmarDupla => 'Confirmar dupla',
        BotaoTorneio.cancelarInscricao => 'Cancelar inscrição',
        BotaoTorneio.fazerCheckin => 'Fazer check-in',
        BotaoTorneio.entrarSalaEspera => 'Sala de espera',
        BotaoTorneio.verClassificacao => 'Classificação',
        BotaoTorneio.verResultado => 'Resultado',
      };

  static IconData _botaoIcon(BotaoTorneio b) => switch (b) {
        BotaoTorneio.inscrever => Icons.how_to_reg_rounded,
        BotaoTorneio.convidarDupla => Icons.group_add_rounded,
        BotaoTorneio.confirmarDupla => Icons.handshake_rounded,
        BotaoTorneio.cancelarInscricao => Icons.cancel_outlined,
        BotaoTorneio.fazerCheckin => Icons.task_alt_rounded,
        BotaoTorneio.entrarSalaEspera => Icons.hourglass_bottom_rounded,
        BotaoTorneio.verClassificacao => Icons.leaderboard_rounded,
        BotaoTorneio.verResultado => Icons.emoji_events_rounded,
      };
}

// -----------------------------------------------------------------------------
// MODAL — INSCRIÇÃO INDIVIDUAL OU DUPLA
// -----------------------------------------------------------------------------
Future<void> showInscricaoTorneioModal({
  required BuildContext context,
  required InscricaoModalVM vm,
  required TorneiosCallbacks callbacks,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: const Color(0xFF120A06),
    showDragHandle: true,
    builder: (_) => InscricaoTorneioModal(vm: vm, callbacks: callbacks),
  );
}

class InscricaoTorneioModal extends StatefulWidget {
  final InscricaoModalVM vm;
  final TorneiosCallbacks callbacks;

  const InscricaoTorneioModal({super.key, required this.vm, required this.callbacks});

  @override
  State<InscricaoTorneioModal> createState() => _InscricaoTorneioModalState();
}

class _InscricaoTorneioModalState extends State<InscricaoTorneioModal> {
  String? _parceiroId;
  bool _regrasLidas = false;

  bool get _saldoSuficiente => widget.vm.entrada == TipoEntrada.gratuito || widget.vm.meuSaldoFichas >= widget.vm.valorEntrada;
  bool get _duplaOk => widget.vm.participacao == TipoParticipacao.individual || _parceiroId != null;
  bool get _podeConfirmar => widget.vm.recusa == null && _saldoSuficiente && _duplaOk && (!widget.vm.exigeConfirmacaoRegras || _regrasLidas);

  @override
  Widget build(BuildContext context) {
    final vm = widget.vm;
    return Padding(
      padding: EdgeInsets.fromLTRB(18, 0, 18, MediaQuery.viewInsetsOf(context).bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.emoji_events_rounded, color: TorneiosPalette.gold, size: 44),
            const SizedBox(height: 6),
            Text('Inscrição · ${vm.nome}', textAlign: TextAlign.center, style: const TextStyle(color: TorneiosPalette.goldHi, fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text('${vm.modalidade.label} · ${torneioData(vm.dataHora)}', textAlign: TextAlign.center, style: const TextStyle(color: TorneiosPalette.textMuted, fontSize: 11.5)),
            const SizedBox(height: 16),
            _GlassCard(
              child: Column(
                children: [
                  _DetailLine(Icons.local_activity_rounded, 'Entrada', vm.entrada == TipoEntrada.gratuito ? 'Gratuita' : '${vm.valorEntrada} fichas'),
                  _DetailLine(Icons.account_balance_wallet_rounded, 'Seu saldo', '${vm.meuSaldoFichas} fichas'),
                  _DetailLine(Icons.workspace_premium_rounded, 'Premiação', vm.premiacaoResumo),
                ],
              ),
            ),
            if (!_saldoSuficiente) ...[
              const SizedBox(height: 9),
              const _ModalAlert(icon: Icons.error_outline_rounded, text: 'Saldo insuficiente para esta inscrição.', color: TorneiosPalette.danger),
            ],
            if (vm.recusa != null) ...[
              const SizedBox(height: 9),
              _ModalAlert(icon: Icons.block_rounded, text: vm.mensagemRecusa ?? _recusaLabel(vm.recusa!), color: TorneiosPalette.danger),
            ],
            if (vm.participacao == TipoParticipacao.dupla) ...[
              const TorneioSectionTitle('Escolha o parceiro'),
              for (final amigo in vm.amigos)
                Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: RadioListTile<String>(
                    value: amigo.playerId,
                    groupValue: _parceiroId,
                    onChanged: (value) => setState(() => _parceiroId = value),
                    activeColor: TorneiosPalette.gold,
                    tileColor: TorneiosPalette.card,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: TorneiosPalette.border)),
                    title: Text(amigo.nome, style: const TextStyle(color: TorneiosPalette.text, fontSize: 12, fontWeight: FontWeight.w700)),
                    subtitle: Text(amigo.online ? 'online agora' : 'offline', style: TextStyle(color: amigo.online ? TorneiosPalette.success : TorneiosPalette.textMuted, fontSize: 10)),
                    secondary: CircleAvatar(backgroundColor: TorneiosPalette.purple.withValues(alpha: .24), child: Text(amigo.nome.isEmpty ? '?' : amigo.nome.substring(0, 1), style: const TextStyle(color: TorneiosPalette.goldHi))),
                  ),
                ),
            ],
            const SizedBox(height: 10),
            CheckboxListTile(
              value: _regrasLidas,
              onChanged: (value) => setState(() => _regrasLidas = value ?? false),
              activeColor: TorneiosPalette.gold,
              checkColor: const Color(0xFF311D04),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              title: const Text('Li e aceito o regulamento, o check-in e as regras de abandono.', style: TextStyle(color: TorneiosPalette.text, fontSize: 11.5, height: 1.3)),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: _podeConfirmar
                  ? () {
                      widget.callbacks.onConfirmarInscricao(vm.tournamentId, parceiroId: _parceiroId, regrasLidas: _regrasLidas);
                      Navigator.of(context).pop();
                    }
                  : null,
              style: FilledButton.styleFrom(backgroundColor: TorneiosPalette.gold, foregroundColor: const Color(0xFF321E04), padding: const EdgeInsets.symmetric(vertical: 14)),
              icon: const Icon(Icons.verified_rounded),
              label: Text(vm.participacao == TipoParticipacao.dupla ? 'Confirmar inscrição da dupla' : 'Confirmar inscrição', style: const TextStyle(fontWeight: FontWeight.w900)),
            ),
            const SizedBox(height: 6),
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Agora não', style: TextStyle(color: TorneiosPalette.textMuted))),
          ],
        ),
      ),
    );
  }

  static String _recusaLabel(MotivoInscricaoRecusada motivo) => switch (motivo) {
        MotivoInscricaoRecusada.semFichas => 'Você não tem fichas suficientes.',
        MotivoInscricaoRecusada.lotado => 'As vagas deste torneio foram preenchidas.',
        MotivoInscricaoRecusada.inscricoesEncerradas => 'As inscrições foram encerradas.',
        MotivoInscricaoRecusada.jaInscrito => 'Você já está inscrito neste torneio.',
        MotivoInscricaoRecusada.parceiroJaInscrito => 'O parceiro escolhido já está inscrito.',
        MotivoInscricaoRecusada.requisitoVipNaoAtendido => 'Este torneio exige acesso VIP.',
        MotivoInscricaoRecusada.perfilSuspenso => 'O perfil está impedido de participar neste momento.',
        MotivoInscricaoRecusada.conflitoComOutraPartida => 'Existe conflito com outra partida agendada.',
      };
}

class _ModalAlert extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _ModalAlert({required this.icon, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(color: color.withValues(alpha: .10), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withValues(alpha: .5))),
      child: Row(children: [Icon(icon, color: color, size: 18), const SizedBox(width: 8), Expanded(child: Text(text, style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w700)))]),
    );
  }
}

// -----------------------------------------------------------------------------
// TELA 3 — SALA DE ESPERA
// -----------------------------------------------------------------------------
class SalaEsperaTorneioScreen extends StatefulWidget {
  final SalaEsperaVM vm;
  final TorneiosCallbacks callbacks;
  final VoidCallback onVoltar;
  final VoidCallback onVerClassificacao;

  const SalaEsperaTorneioScreen({super.key, required this.vm, required this.callbacks, required this.onVoltar, required this.onVerClassificacao});

  @override
  State<SalaEsperaTorneioScreen> createState() => _SalaEsperaTorneioScreenState();
}

class _SalaEsperaTorneioScreenState extends State<SalaEsperaTorneioScreen> {
  late Duration _restante;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _restante = widget.vm.contagemRegressiva;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _restante.inSeconds <= 0) return;
      setState(() => _restante -= const Duration(seconds: 1));
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.vm;
    return TorneiosShell(
      title: 'Sala de espera',
      subtitle: vm.nome,
      onBack: widget.onVoltar,
      actions: [IconButton(onPressed: widget.onVerClassificacao, icon: const Icon(Icons.leaderboard_rounded, color: TorneiosPalette.goldHi))],
      scroll: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CountdownCard(restante: _restante, status: vm.status),
          const SizedBox(height: 10),
          _GlassCard(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _MiniKpi(value: '${vm.checkins}', label: 'check-ins')),
                    Expanded(child: _MiniKpi(value: '${vm.participantes}', label: 'participantes')),
                    Expanded(child: _MiniKpi(value: '${vm.participantes - vm.checkins}', label: 'pendentes')),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: vm.participantes == 0 ? 0 : vm.checkins / vm.participantes,
                    minHeight: 8,
                    backgroundColor: Colors.white.withValues(alpha: .07),
                    valueColor: const AlwaysStoppedAnimation(TorneiosPalette.success),
                  ),
                ),
              ],
            ),
          ),
          const TorneioSectionTitle('Sua situação'),
          _GlassCard(
            color: TorneiosPalette.purple.withValues(alpha: .13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [const Icon(Icons.verified_user_rounded, color: TorneiosPalette.success), const SizedBox(width: 8), Expanded(child: Text(vm.meuStatus.label, style: const TextStyle(color: TorneiosPalette.goldHi, fontWeight: FontWeight.w900)))]),
                if (vm.statusDupla != null) ...[
                  const SizedBox(height: 7),
                  Text(vm.statusDupla!, style: const TextStyle(color: TorneiosPalette.textMuted, fontSize: 11.5)),
                ],
              ],
            ),
          ),
          if (vm.meuConfronto != null) ...[
            const TorneioSectionTitle('Sua convocação'),
            _ConfrontoCard(
              vm: vm.meuConfronto!,
              actionLabel: 'Entrar na mesa',
              onAction: () => widget.callbacks.onEntrarNaMesa(vm.tournamentId, vm.meuConfronto!.confrontoId),
            ),
            const SizedBox(height: 8),
            FaixaTorneioMesa(
              vm: FaixaTorneioMesaVM(
                nomeTorneio: vm.nome,
                rodada: vm.meuConfronto!.rodada,
                mesaLabel: vm.meuConfronto!.mesaLabel,
                faseOuPosicao: 'Classificatória',
                pontuacaoAcumulada: 4680,
              ),
            ),
          ],
          const TorneioSectionTitle('Avisos oficiais'),
          _GlassCard(
            child: Column(
              children: [
                for (final msg in vm.mensagensOficiais)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.campaign_rounded, color: TorneiosPalette.amethyst, size: 18), const SizedBox(width: 8), Expanded(child: Text(msg, style: const TextStyle(color: TorneiosPalette.text, fontSize: 11.5, height: 1.35)))]),
                  ),
              ],
            ),
          ),
          const TorneioSectionTitle('Resumo das regras'),
          _GlassCard(child: Text(vm.regrasResumo, style: const TextStyle(color: TorneiosPalette.textMuted, fontSize: 11.5))),
        ],
      ),
    );
  }
}

class _CountdownCard extends StatelessWidget {
  final Duration restante;
  final TorneioStatus status;

  const _CountdownCard({required this.restante, required this.status});

  @override
  Widget build(BuildContext context) {
    final h = restante.inHours.toString().padLeft(2, '0');
    final m = restante.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = restante.inSeconds.remainder(60).toString().padLeft(2, '0');
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF5B2A82), Color(0xFF2C1736)]),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: TorneiosPalette.amethyst.withValues(alpha: .6)),
      ),
      child: Column(
        children: [
          TorneioPill(status.label, color: _statusColor(status), icon: _statusIcon(status)),
          const SizedBox(height: 11),
          Text('$h:$m:$s', style: const TextStyle(color: TorneiosPalette.goldHi, fontSize: 42, fontWeight: FontWeight.w900, letterSpacing: 2)),
          const Text('até o início previsto', style: TextStyle(color: Color(0xFFD5C5E6), fontSize: 11)),
        ],
      ),
    );
  }
}

class _MiniKpi extends StatelessWidget {
  final String value;
  final String label;

  const _MiniKpi({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(children: [Text(value, style: const TextStyle(color: TorneiosPalette.goldHi, fontSize: 20, fontWeight: FontWeight.w900)), Text(label, style: const TextStyle(color: TorneiosPalette.textMuted, fontSize: 9.5))]);
  }
}

class FaixaTorneioMesa extends StatelessWidget {
  final FaixaTorneioMesaVM vm;

  const FaixaTorneioMesa({super.key, required this.vm});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xE6120A06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: TorneiosPalette.gold.withValues(alpha: .42)),
      ),
      child: Row(
        children: [
          const Icon(Icons.emoji_events_rounded, color: TorneiosPalette.gold, size: 15),
          const SizedBox(width: 6),
          Expanded(child: Text(vm.nomeTorneio, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: TorneiosPalette.goldHi, fontSize: 10.5, fontWeight: FontWeight.w800))),
          Text('R${vm.rodada} · ${vm.mesaLabel} · ${vm.faseOuPosicao} · ${vm.pontuacaoAcumulada} pts', style: const TextStyle(color: TorneiosPalette.textMuted, fontSize: 8.8)),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// TELA 4 — CLASSIFICAÇÃO / CONFRONTOS / MINHA PARTICIPAÇÃO
// -----------------------------------------------------------------------------
class ClassificacaoTorneioScreen extends StatelessWidget {
  final ClassificacaoTorneioVM vm;
  final TorneiosCallbacks callbacks;
  final VoidCallback onVoltar;

  const ClassificacaoTorneioScreen({super.key, required this.vm, required this.callbacks, required this.onVoltar});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: TorneiosShell(
        title: 'Classificação',
        subtitle: '${vm.nome} · rodada ${vm.rodadaAtual}',
        onBack: onVoltar,
        child: Column(
          children: [
            const TabBar(
              indicatorColor: TorneiosPalette.gold,
              labelColor: TorneiosPalette.goldHi,
              unselectedLabelColor: TorneiosPalette.textMuted,
              labelStyle: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800),
              tabs: [Tab(text: 'RANKING'), Tab(text: 'CONFRONTOS'), Tab(text: 'MINHA JORNADA')],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _RankingTorneio(lista: vm.classificacao),
                  _ConfrontosTorneio(lista: vm.confrontos, onEntrar: (c) => callbacks.onEntrarNaMesa(vm.tournamentId, c.confrontoId)),
                  _MinhaJornada(vm: vm.minhaParticipacao, onEntrar: vm.minhaParticipacao.proximoConfronto == null ? null : () => callbacks.onEntrarNaMesa(vm.tournamentId, vm.minhaParticipacao.proximoConfronto!.confrontoId)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RankingTorneio extends StatelessWidget {
  final List<ClassificacaoLinhaVM> lista;

  const _RankingTorneio({required this.lista});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
      itemCount: lista.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = lista[index];
        return _GlassCard(
          color: item.souEu ? TorneiosPalette.purple.withValues(alpha: .18) : TorneiosPalette.card,
          child: Row(
            children: [
              _PodioCircle(posicao: item.posicao),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [Expanded(child: Text(item.nome, style: TextStyle(color: item.souEu ? TorneiosPalette.goldHi : TorneiosPalette.text, fontSize: 12, fontWeight: FontWeight.w900))), if (item.souEu) const TorneioPill('VOCÊ', color: TorneiosPalette.amethyst)]),
                    const SizedBox(height: 5),
                    Text('${item.vitorias}V · ${item.derrotas}D · ${item.pontosFeitos} feitos · ${item.canastrasLimpas} limpas', style: const TextStyle(color: TorneiosPalette.textMuted, fontSize: 9.6)),
                  ],
                ),
              ),
              const SizedBox(width: 7),
              Column(children: [Text(item.saldo >= 0 ? '+${item.saldo}' : '${item.saldo}', style: TextStyle(color: item.saldo >= 0 ? TorneiosPalette.success : TorneiosPalette.danger, fontWeight: FontWeight.w900)), const Text('saldo', style: TextStyle(color: TorneiosPalette.textMuted, fontSize: 8.5))]),
            ],
          ),
        );
      },
    );
  }
}

class _ConfrontosTorneio extends StatelessWidget {
  final List<ConfrontoVM> lista;
  final ValueChanged<ConfrontoVM> onEntrar;

  const _ConfrontosTorneio({required this.lista, required this.onEntrar});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
      itemCount: lista.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) => _ConfrontoCard(vm: lista[index], actionLabel: lista[index].ehMeu && lista[index].statusPartida != 'encerrada' ? 'Entrar' : null, onAction: lista[index].ehMeu ? () => onEntrar(lista[index]) : null),
    );
  }
}

class _ConfrontoCard extends StatelessWidget {
  final ConfrontoVM vm;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _ConfrontoCard({required this.vm, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    final cor = vm.statusPartida == 'encerrada' ? TorneiosPalette.success : vm.statusPartida == 'em jogo' ? TorneiosPalette.purple : TorneiosPalette.warning;
    return _GlassCard(
      color: vm.ehMeu ? TorneiosPalette.purple.withValues(alpha: .15) : TorneiosPalette.card,
      child: Column(
        children: [
          Row(children: [TorneioPill('RODADA ${vm.rodada}', color: TorneiosPalette.gold), const SizedBox(width: 5), TorneioPill(vm.mesaLabel, color: TorneiosPalette.amethyst), const Spacer(), TorneioPill(vm.statusPartida.toUpperCase(), color: cor)]),
          const SizedBox(height: 12),
          Row(children: [Expanded(child: Text(vm.duplaA, textAlign: TextAlign.center, style: const TextStyle(color: TorneiosPalette.text, fontSize: 12, fontWeight: FontWeight.w800))), Text(vm.resultado ?? '×', style: const TextStyle(color: TorneiosPalette.goldHi, fontSize: 17, fontWeight: FontWeight.w900)), Expanded(child: Text(vm.duplaB, textAlign: TextAlign.center, style: const TextStyle(color: TorneiosPalette.text, fontSize: 12, fontWeight: FontWeight.w800)))]),
          if (vm.horario != null) ...[
            const SizedBox(height: 8),
            Text(torneioData(vm.horario!), style: const TextStyle(color: TorneiosPalette.textMuted, fontSize: 10)),
          ],
          if (actionLabel != null) ...[
            const SizedBox(height: 11),
            SizedBox(width: double.infinity, child: FilledButton(onPressed: onAction, style: FilledButton.styleFrom(backgroundColor: TorneiosPalette.gold, foregroundColor: const Color(0xFF321E04)), child: Text(actionLabel!))),
          ],
        ],
      ),
    );
  }
}

class _MinhaJornada extends StatelessWidget {
  final MinhaParticipacaoVM vm;
  final VoidCallback? onEntrar;

  const _MinhaJornada({required this.vm, this.onEntrar});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF5B2A82), Color(0xFF2C1736)]), borderRadius: BorderRadius.circular(18), border: Border.all(color: TorneiosPalette.amethyst.withValues(alpha: .55))),
          child: Column(children: [const Text('POSIÇÃO ATUAL', style: TextStyle(color: Color(0xFFD8C7E8), fontSize: 10, letterSpacing: 1.4)), Text('${vm.posicaoAtual}º', style: const TextStyle(color: TorneiosPalette.goldHi, fontSize: 42, fontWeight: FontWeight.w900)), Text(vm.desempenhoResumo, textAlign: TextAlign.center, style: const TextStyle(color: TorneiosPalette.text, fontSize: 11.5))]),
        ),
        const TorneioSectionTitle('Por que estou aqui'),
        _GlassCard(child: Text(vm.criterios, style: const TextStyle(color: TorneiosPalette.text, fontSize: 12, height: 1.4))),
        if (vm.proximoConfronto != null) ...[
          const TorneioSectionTitle('Próximo confronto'),
          _ConfrontoCard(vm: vm.proximoConfronto!, actionLabel: onEntrar == null ? null : 'Entrar quando liberar', onAction: onEntrar),
        ],
        const TorneioSectionTitle('Resultados anteriores'),
        _GlassCard(child: Column(children: [for (final r in vm.resultadosAnteriores) Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(children: [const Icon(Icons.check_circle_rounded, color: TorneiosPalette.success, size: 17), const SizedBox(width: 8), Expanded(child: Text(r, style: const TextStyle(color: TorneiosPalette.text, fontSize: 11.5)))]))])),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// TELA 5 — RESULTADO
// -----------------------------------------------------------------------------
class ResultadoTorneioScreen extends StatelessWidget {
  final ResultadoTorneioVM vm;
  final TorneiosCallbacks callbacks;
  final VoidCallback onVoltar;

  const ResultadoTorneioScreen({super.key, required this.vm, required this.callbacks, required this.onVoltar});

  @override
  Widget build(BuildContext context) {
    return TorneiosShell(
      title: 'Resultado oficial',
      subtitle: vm.nome,
      onBack: onVoltar,
      actions: [IconButton(onPressed: () => callbacks.onCompartilharConquista(vm.tournamentId), icon: const Icon(Icons.share_rounded, color: TorneiosPalette.goldHi))],
      scroll: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PodioFinal(vm: vm),
          if (vm.registraHallDosImortais) ...[
            const SizedBox(height: 10),
            const _ModalAlert(icon: Icons.auto_awesome_rounded, text: 'Esta conquista será registrada no Hall dos Imortais.', color: TorneiosPalette.amethyst),
          ],
          const TorneioSectionTitle('Estatísticas do torneio'),
          _GlassCard(child: Text(vm.estatisticas, textAlign: TextAlign.center, style: const TextStyle(color: TorneiosPalette.text, fontSize: 12, height: 1.4))),
          const TorneioSectionTitle('Suas premiações'),
          for (final p in vm.minhasPremiacoes)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _GlassCard(
                child: Row(children: [_PodioCircle(posicao: p.posicao), const SizedBox(width: 10), Expanded(child: Text(p.valorLabel, style: const TextStyle(color: TorneiosPalette.text, fontSize: 11.5, fontWeight: FontWeight.w800))), if (p.statusEntrega == 'resgatar') FilledButton(onPressed: () => callbacks.onResgatarPremio(p.rewardId), style: FilledButton.styleFrom(backgroundColor: TorneiosPalette.gold, foregroundColor: const Color(0xFF321E04), padding: const EdgeInsets.symmetric(horizontal: 12)), child: const Text('Resgatar', style: TextStyle(fontSize: 10))) else TorneioPill(p.statusEntrega.toUpperCase(), color: p.statusEntrega == 'entregue' ? TorneiosPalette.success : TorneiosPalette.warning)]),
              ),
            ),
          const TorneioSectionTitle('Classificação final'),
          for (final item in vm.classificacaoFinal)
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: _GlassCard(
                color: item.souEu ? TorneiosPalette.purple.withValues(alpha: .16) : TorneiosPalette.card,
                child: Row(children: [_PodioCircle(posicao: item.posicao), const SizedBox(width: 9), Expanded(child: Text(item.nome, style: const TextStyle(color: TorneiosPalette.text, fontWeight: FontWeight.w800))), Text('${item.vitorias}V · ${item.saldo >= 0 ? '+' : ''}${item.saldo}', style: const TextStyle(color: TorneiosPalette.textMuted, fontSize: 10.5))]),
              ),
            ),
        ],
      ),
    );
  }
}

class _PodioFinal extends StatelessWidget {
  final ResultadoTorneioVM vm;

  const _PodioFinal({required this.vm});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 20, 14, 16),
      decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF5D2B85), Color(0xFF2C1736), Color(0xFF1A100B)]), borderRadius: BorderRadius.circular(22), border: Border.all(color: TorneiosPalette.amethyst.withValues(alpha: .55))),
      child: Column(
        children: [
          const Icon(Icons.emoji_events_rounded, color: TorneiosPalette.gold, size: 62),
          const SizedBox(height: 6),
          const Text('CAMPEÕES', style: TextStyle(color: Color(0xFFD9C8E9), fontSize: 10, letterSpacing: 2)),
          Text(vm.campeao, textAlign: TextAlign.center, style: const TextStyle(color: TorneiosPalette.goldHi, fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(child: _PodioNome(posicao: 2, nome: vm.vice ?? '—')),
              const SizedBox(width: 8),
              Expanded(child: _PodioNome(posicao: 3, nome: vm.terceiro ?? '—')),
            ],
          ),
          if (vm.minhaPosicaoRanking != null) ...[
            const SizedBox(height: 14),
            TorneioPill('SUA POSIÇÃO: ${vm.minhaPosicaoRanking}º', color: TorneiosPalette.success),
          ],
        ],
      ),
    );
  }
}

class _PodioNome extends StatelessWidget {
  final int posicao;
  final String nome;

  const _PodioNome({required this.posicao, required this.nome});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: .22), borderRadius: BorderRadius.circular(13), border: Border.all(color: TorneiosPalette.border)),
      child: Column(children: [_PodioCircle(posicao: posicao), const SizedBox(height: 5), Text(nome, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: TorneiosPalette.text, fontSize: 10.5, fontWeight: FontWeight.w700))]),
    );
  }
}

// -----------------------------------------------------------------------------
// TELA 6 — ADMINISTRAÇÃO
// -----------------------------------------------------------------------------
class AdminTorneiosScreen extends StatefulWidget {
  final List<AdminTorneioResumoVM> torneios;
  final TorneiosCallbacks callbacks;
  final VoidCallback onVoltar;

  const AdminTorneiosScreen({super.key, required this.torneios, required this.callbacks, required this.onVoltar});

  @override
  State<AdminTorneiosScreen> createState() => _AdminTorneiosScreenState();
}

class _AdminTorneiosScreenState extends State<AdminTorneiosScreen> {
  bool _somenteAlertas = false;

  @override
  Widget build(BuildContext context) {
    final lista = _somenteAlertas ? widget.torneios.where((t) => t.alertas.isNotEmpty).toList() : widget.torneios;
    return TorneiosShell(
      title: 'Gestão de torneios',
      subtitle: 'área exclusiva da proprietária',
      onBack: widget.onVoltar,
      actions: [IconButton(tooltip: 'Criar modelo', onPressed: widget.callbacks.onCriarModelo, icon: const Icon(Icons.add_circle_rounded, color: TorneiosPalette.gold))],
      child: Column(
        children: [
          _AdminResumo(torneios: widget.torneios),
          SwitchListTile(
            value: _somenteAlertas,
            onChanged: (value) => setState(() => _somenteAlertas = value),
            title: const Text('Mostrar somente torneios com alertas', style: TextStyle(color: TorneiosPalette.text, fontSize: 11.5)),
            activeColor: TorneiosPalette.gold,
            dense: true,
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 28),
              itemCount: lista.length,
              separatorBuilder: (_, __) => const SizedBox(height: 9),
              itemBuilder: (context, index) => _AdminCard(
                vm: lista[index],
                onEditar: () => widget.callbacks.onEditarModelo(lista[index].id),
                onAcoes: () => _abrirAcoes(context, lista[index]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _abrirAcoes(BuildContext context, AdminTorneioResumoVM item) {
    final acoes = _acoesPorStatus(item.status);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF130B08),
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(item.nome, style: const TextStyle(color: TorneiosPalette.goldHi, fontSize: 17, fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              for (final acao in acoes)
                ListTile(
                  leading: Icon(_acaoIcon(acao), color: TorneiosPalette.amethyst),
                  title: Text(_acaoLabel(acao), style: const TextStyle(color: TorneiosPalette.text, fontSize: 12)),
                  onTap: () {
                    Navigator.of(context).pop();
                    widget.callbacks.onAcaoAdmin(item.id, acao);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  static List<AcaoAdmin> _acoesPorStatus(TorneioStatus status) => switch (status) {
        TorneioStatus.rascunho => const [AcaoAdmin.ativar, AcaoAdmin.ampliarVagas, AcaoAdmin.alterarPremiacao, AcaoAdmin.verHistorico],
        TorneioStatus.agendado => const [AcaoAdmin.ativar, AcaoAdmin.ampliarVagas, AcaoAdmin.alterarPremiacao, AcaoAdmin.verHistorico],
        TorneioStatus.anunciado => const [AcaoAdmin.ativar, AcaoAdmin.ampliarVagas, AcaoAdmin.alterarPremiacao, AcaoAdmin.verHistorico],
        TorneioStatus.inscricoesAbertas => const [AcaoAdmin.pausar, AcaoAdmin.ampliarVagas, AcaoAdmin.reduzirVagas, AcaoAdmin.alterarPremiacao, AcaoAdmin.cancelarEdicao],
        TorneioStatus.checkinAberto => const [AcaoAdmin.iniciar, AcaoAdmin.ampliarVagas, AcaoAdmin.cancelarEdicao, AcaoAdmin.verHistorico],
        TorneioStatus.preparandoMesas => const [AcaoAdmin.iniciar, AcaoAdmin.ampliarVagas, AcaoAdmin.cancelarEdicao, AcaoAdmin.verHistorico],
        TorneioStatus.emAndamento => const [AcaoAdmin.pausar, AcaoAdmin.encerrar, AcaoAdmin.verHistorico],
        TorneioStatus.aguardandoValidacao => const [AcaoAdmin.validarResultado, AcaoAdmin.liberarPremiacao, AcaoAdmin.verHistorico],
        _ => const [AcaoAdmin.verHistorico],
      };

  static String _acaoLabel(AcaoAdmin acao) => switch (acao) {
        AcaoAdmin.ativar => 'Ativar edição',
        AcaoAdmin.pausar => 'Pausar edição',
        AcaoAdmin.cancelarEdicao => 'Cancelar edição',
        AcaoAdmin.reabrirInscricoes => 'Reabrir inscrições',
        AcaoAdmin.ampliarVagas => 'Ampliar vagas',
        AcaoAdmin.reduzirVagas => 'Reduzir vagas',
        AcaoAdmin.alterarPremiacao => 'Alterar premiação',
        AcaoAdmin.iniciar => 'Iniciar torneio',
        AcaoAdmin.encerrar => 'Encerrar torneio',
        AcaoAdmin.validarResultado => 'Validar resultado',
        AcaoAdmin.liberarPremiacao => 'Liberar premiação',
        AcaoAdmin.verHistorico => 'Ver histórico de auditoria',
      };

  static IconData _acaoIcon(AcaoAdmin acao) => switch (acao) {
        AcaoAdmin.ativar => Icons.play_circle_rounded,
        AcaoAdmin.pausar => Icons.pause_circle_rounded,
        AcaoAdmin.cancelarEdicao => Icons.cancel_rounded,
        AcaoAdmin.reabrirInscricoes => Icons.lock_open_rounded,
        AcaoAdmin.ampliarVagas => Icons.group_add_rounded,
        AcaoAdmin.reduzirVagas => Icons.group_remove_rounded,
        AcaoAdmin.alterarPremiacao => Icons.workspace_premium_rounded,
        AcaoAdmin.iniciar => Icons.flag_rounded,
        AcaoAdmin.encerrar => Icons.stop_circle_rounded,
        AcaoAdmin.validarResultado => Icons.fact_check_rounded,
        AcaoAdmin.liberarPremiacao => Icons.card_giftcard_rounded,
        AcaoAdmin.verHistorico => Icons.history_rounded,
      };
}

class _AdminResumo extends StatelessWidget {
  final List<AdminTorneioResumoVM> torneios;

  const _AdminResumo({required this.torneios});

  @override
  Widget build(BuildContext context) {
    final ativos = torneios.where((e) => e.status == TorneioStatus.emAndamento).length;
    final alertas = torneios.fold<int>(0, (s, e) => s + e.alertas.length);
    final arrecadado = torneios.fold<int>(0, (s, e) => s + e.arrecadacaoFichas);
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 13, 14, 5),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF3D2057), Color(0xFF21132A)]), borderRadius: BorderRadius.circular(18), border: Border.all(color: TorneiosPalette.amethyst.withValues(alpha: .45))),
      child: Row(children: [Expanded(child: _MiniKpi(value: '$ativos', label: 'ao vivo')), Expanded(child: _MiniKpi(value: '$alertas', label: 'alertas')), Expanded(child: _MiniKpi(value: '$arrecadado', label: 'fichas'))]),
    );
  }
}

class _AdminCard extends StatelessWidget {
  final AdminTorneioResumoVM vm;
  final VoidCallback onEditar;
  final VoidCallback onAcoes;

  const _AdminCard({required this.vm, required this.onEditar, required this.onAcoes});

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Expanded(child: Text('${vm.nome} · edição ${vm.edicao}', style: const TextStyle(color: TorneiosPalette.goldHi, fontSize: 13, fontWeight: FontWeight.w900))), TorneioPill(vm.status.label, color: _statusColor(vm.status))]),
          const SizedBox(height: 8),
          Text('${vm.modalidade.label} · ${torneioData(vm.data)}', style: const TextStyle(color: TorneiosPalette.textMuted, fontSize: 10.5)),
          const SizedBox(height: 10),
          Row(children: [Expanded(child: _MiniKpi(value: '${vm.inscritos}/${vm.vagas}', label: 'inscritos')), Expanded(child: _MiniKpi(value: '${vm.checkins}', label: 'check-ins')), Expanded(child: _MiniKpi(value: '${vm.mesasAtivas}', label: 'mesas')), Expanded(child: _MiniKpi(value: '${vm.arrecadacaoFichas}', label: 'fichas'))]),
          const SizedBox(height: 8),
          Text(vm.premiacaoPrevista, style: const TextStyle(color: TorneiosPalette.text, fontSize: 10.5, fontWeight: FontWeight.w700)),
          if (vm.alertas.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final a in vm.alertas)
              Padding(padding: const EdgeInsets.only(bottom: 4), child: Row(children: [const Icon(Icons.warning_amber_rounded, color: TorneiosPalette.warning, size: 17), const SizedBox(width: 6), Expanded(child: Text(a, style: const TextStyle(color: TorneiosPalette.warning, fontSize: 10.5)))])),
          ],
          const SizedBox(height: 9),
          Row(children: [Expanded(child: OutlinedButton.icon(onPressed: onEditar, icon: const Icon(Icons.edit_rounded, size: 16), label: const Text('Editar modelo'), style: OutlinedButton.styleFrom(foregroundColor: TorneiosPalette.amethyst, side: BorderSide(color: TorneiosPalette.amethyst.withValues(alpha: .45))))), const SizedBox(width: 8), Expanded(child: FilledButton.icon(onPressed: onAcoes, icon: const Icon(Icons.bolt_rounded, size: 16), label: const Text('Ações'), style: FilledButton.styleFrom(backgroundColor: TorneiosPalette.gold, foregroundColor: const Color(0xFF321E04))))]),
        ],
      ),
    );
  }
}
