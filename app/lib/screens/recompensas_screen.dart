import 'package:flutter/material.dart';

enum RecompensaEstado { carregando, normal, erro }

enum EstadoDia { resgatado, hoje, bloqueado }

class RecompensasVM {
  final CarteiraRec carteira;
  final NivelRec nivel;
  final LoginDiario loginDiario;
  final List<Missao> missoes;
  final String missoesRenovaEm;
  final List<FonteMoeda> comoGanhar;

  const RecompensasVM({
    required this.carteira,
    required this.nivel,
    required this.loginDiario,
    required this.missoes,
    required this.missoesRenovaEm,
    required this.comoGanhar,
  });

  factory RecompensasVM.mock() {
    return const RecompensasVM(
      carteira: CarteiraRec(moedas: 1000, gemas: 12),
      nivel: NivelRec(nivel: 24, xpAtual: 3240, xpProximo: 5000),
      loginDiario: LoginDiario(
        voltaEm: 'volta em 08:12',
        dias: [
          DiaLogin(dia: 1, recompensa: 100, estado: EstadoDia.resgatado),
          DiaLogin(dia: 2, recompensa: 150, estado: EstadoDia.resgatado),
          DiaLogin(dia: 3, recompensa: 250, estado: EstadoDia.resgatado),
          DiaLogin(dia: 4, recompensa: 400, estado: EstadoDia.hoje),
          DiaLogin(dia: 5, recompensa: 600, estado: EstadoDia.bloqueado),
          DiaLogin(dia: 6, recompensa: 800, estado: EstadoDia.bloqueado),
        ],
        bau: BauReal(
          titulo: 'Dia 7 · Baú Real',
          descricao: 'Mascote exclusivo + 2.000 🪙 + moldura',
          disponivel: false,
        ),
      ),
      missoes: [
        Missao(
          id: 'jogar3',
          icone: '🎮',
          titulo: 'Jogar 3 partidas',
          recompensa: 150,
          progresso: 3,
          meta: 3,
        ),
        Missao(
          id: 'canastra2',
          icone: '🃏',
          titulo: 'Fazer 2 canastras',
          recompensa: 200,
          progresso: 1,
          meta: 2,
        ),
        Missao(
          id: 'vencer1',
          icone: '🏆',
          titulo: 'Vencer 1 partida',
          recompensa: 250,
          progresso: 0,
          meta: 1,
        ),
      ],
      missoesRenovaEm: 'renova em 08:12',
      comoGanhar: [
        FonteMoeda(id: 'jogar', icone: '🎮', label: 'Jogar', valor: 50),
        FonteMoeda(id: 'vencer', icone: '🏆', label: 'Vencer', valor: 100),
        FonteMoeda(id: 'canastra', icone: '🃏', label: 'Canastra', valor: 30),
        FonteMoeda(id: 'anuncio', icone: '📺', label: 'Ver anúncio', valor: 50),
        FonteMoeda(id: 'convidar', icone: '👥', label: 'Convidar', valor: 500),
        FonteMoeda(id: 'login', icone: '📅', label: 'Login diário', valor: 100),
      ],
    );
  }
}

class CarteiraRec {
  final int moedas;
  final int gemas;

  const CarteiraRec({required this.moedas, required this.gemas});
}

class NivelRec {
  final int nivel;
  final int xpAtual;
  final int xpProximo;

  const NivelRec({
    required this.nivel,
    required this.xpAtual,
    required this.xpProximo,
  });
}

class LoginDiario {
  final String voltaEm;
  final List<DiaLogin> dias;
  final BauReal bau;

  const LoginDiario({
    required this.voltaEm,
    required this.dias,
    required this.bau,
  });
}

class DiaLogin {
  final int dia;
  final int recompensa;
  final EstadoDia estado;

  const DiaLogin({
    required this.dia,
    required this.recompensa,
    required this.estado,
  });
}

class BauReal {
  final String titulo;
  final String descricao;
  final bool disponivel;

  const BauReal({
    required this.titulo,
    required this.descricao,
    required this.disponivel,
  });
}

class Missao {
  final String id;
  final String icone;
  final String titulo;
  final int recompensa;
  final int progresso;
  final int meta;

  const Missao({
    required this.id,
    required this.icone,
    required this.titulo,
    required this.recompensa,
    required this.progresso,
    required this.meta,
  });
}

class FonteMoeda {
  final String id;
  final String icone;
  final String label;
  final int valor;

  const FonteMoeda({
    required this.id,
    required this.icone,
    required this.label,
    required this.valor,
  });
}

class RecompensasScreen extends StatelessWidget {
  static const _gold = Color(0xFFEFB94A);
  static const _goldHi = Color(0xFFF6E2A6);
  static const _card = Color(0xFF1C130C);
  static const _border = Color(0x33EFB94A);
  static const _muted = Color(0xFF8A7C5E);
  static const _text = Color(0xFFEFE3CC);

  final RecompensasVM vm;
  final RecompensaEstado estado;
  final String? mensagemErro;
  final VoidCallback onVoltar;
  final ValueChanged<String> onResgatarMissao;
  final VoidCallback onResgatarHoje;
  final VoidCallback onAbrirBau;
  final ValueChanged<String> onFonteTap;
  final VoidCallback onRecarregar;

  const RecompensasScreen({
    super.key,
    required this.vm,
    required this.estado,
    required this.onVoltar,
    required this.onResgatarMissao,
    required this.onResgatarHoje,
    required this.onAbrirBau,
    required this.onFonteTap,
    required this.onRecarregar,
    this.mensagemErro,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF241812), Color(0xFF120A06), Color(0xFF000000)],
            stops: [0, .55, 1],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(
                children: [
                  _TopBar(
                    carteira: vm.carteira,
                    carregando: estado == RecompensaEstado.carregando,
                    onVoltar: onVoltar,
                  ),
                  Expanded(child: _body()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _body() {
    if (estado == RecompensaEstado.erro) {
      return RefreshIndicator(
        color: _gold,
        backgroundColor: _card,
        onRefresh: () => Future<void>.sync(onRecarregar),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 24),
          children: [
            _ErrorCard(
              mensagem: mensagemErro ?? 'Não foi possível carregar suas recompensas.',
              onRecarregar: onRecarregar,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: _gold,
      backgroundColor: _card,
      onRefresh: () => Future<void>.sync(onRecarregar),
      child: estado == RecompensaEstado.carregando
          ? const _RecompensasSkeleton()
          : ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                _NivelCard(nivel: vm.nivel),
                _SectionHeader(
                  titulo: 'LOGIN DIÁRIO',
                  detalhe: vm.loginDiario.voltaEm,
                ),
                _DailyGrid(
                  login: vm.loginDiario,
                  onResgatarHoje: onResgatarHoje,
                  onAbrirBau: onAbrirBau,
                ),
                _SectionHeader(
                  titulo: 'MISSÕES DIÁRIAS',
                  detalhe: vm.missoesRenovaEm,
                ),
                _MissionsList(
                  missoes: vm.missoes,
                  onResgatar: onResgatarMissao,
                ),
                const _SectionHeader(titulo: 'COMO GANHAR MOEDAS'),
                _EarnGrid(fontes: vm.comoGanhar, onTap: onFonteTap),
              ],
            ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final CarteiraRec carteira;
  final bool carregando;
  final VoidCallback onVoltar;

  const _TopBar({
    required this.carteira,
    required this.carregando,
    required this.onVoltar,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 7, 14, 3),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: 'Voltar',
            child: InkWell(
              onTap: onVoltar,
              borderRadius: BorderRadius.circular(20),
              child: const SizedBox(
                width: 28,
                height: 34,
                child: Center(
                  child: Text(
                    '‹',
                    style: TextStyle(
                      color: RecompensasScreen._gold,
                      fontSize: 29,
                      height: .8,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 1),
          const Text(
            'Recompensas',
            style: TextStyle(
              color: RecompensasScreen._goldHi,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const Spacer(),
          if (carregando) ...[
            const _SkeletonBox(width: 82, height: 30, radius: 20),
            const SizedBox(width: 7),
            const _SkeletonBox(width: 72, height: 30, radius: 20),
          ] else ...[
            _WalletPill(emoji: '🪙', valor: _formatarInteiro(carteira.moedas)),
            const SizedBox(width: 7),
            _WalletPill(emoji: '💎', valor: _formatarInteiro(carteira.gemas)),
          ],
        ],
      ),
    );
  }
}

class _WalletPill extends StatelessWidget {
  final String emoji;
  final String valor;

  const _WalletPill({required this.emoji, required this.valor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .34),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: RecompensasScreen._border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 13, height: 1)),
          const SizedBox(width: 4),
          Text(
            valor,
            style: const TextStyle(
              color: RecompensasScreen._goldHi,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _NivelCard extends StatelessWidget {
  final NivelRec nivel;
  const _NivelCard({required this.nivel});

  @override
  Widget build(BuildContext context) {
    final progresso = nivel.xpProximo <= 0
        ? 0.0
        : (nivel.xpAtual / nivel.xpProximo).clamp(0.0, 1.0).toDouble();

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 10, 14, 0),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: RecompensasScreen._card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: RecompensasScreen._border),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(text: 'Nível '),
                    TextSpan(
                      text: '${nivel.nivel}',
                      style: const TextStyle(
                        color: RecompensasScreen._gold,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                style: const TextStyle(color: Color(0xFFC9BA99), fontSize: 12),
              ),
              Text(
                '${_formatarInteiro(nivel.xpAtual)} / ${_formatarInteiro(nivel.xpProximo)} XP',
                style: const TextStyle(color: Color(0xFFC9BA99), fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 7),
          _ProgressBar(valor: progresso, altura: 9),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String titulo;
  final String? detalhe;

  const _SectionHeader({required this.titulo, this.detalhe});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 17, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              titulo,
              style: const TextStyle(
                color: RecompensasScreen._gold,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.3,
              ),
            ),
          ),
          if (detalhe != null)
            Text(
              detalhe!,
              style: const TextStyle(
                color: RecompensasScreen._muted,
                fontSize: 10,
              ),
            ),
        ],
      ),
    );
  }
}

class _DailyGrid extends StatelessWidget {
  final LoginDiario login;
  final VoidCallback onResgatarHoje;
  final VoidCallback onAbrirBau;

  const _DailyGrid({
    required this.login,
    required this.onResgatarHoje,
    required this.onAbrirBau,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        children: [
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: login.dias.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1.43,
            ),
            itemBuilder: (_, index) {
              final dia = login.dias[index];
              return _DayCard(
                dia: dia,
                onTap: dia.estado == EstadoDia.hoje ? onResgatarHoje : null,
              );
            },
          ),
          const SizedBox(height: 8),
          _BauCard(bau: login.bau, onTap: onAbrirBau),
        ],
      ),
    );
  }
}

class _DayCard extends StatelessWidget {
  final DiaLogin dia;
  final VoidCallback? onTap;

  const _DayCard({required this.dia, this.onTap});

  @override
  Widget build(BuildContext context) {
    final resgatado = dia.estado == EstadoDia.resgatado;
    final hoje = dia.estado == EstadoDia.hoje;
    final bloqueado = dia.estado == EstadoDia.bloqueado;

    Widget content = Stack(
      children: [
        Positioned.fill(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                hoje ? 'HOJE' : 'Dia ${dia.dia}',
                style: TextStyle(
                  color: hoje ? RecompensasScreen._gold : RecompensasScreen._muted,
                  fontSize: 9.5,
                  fontWeight: hoje ? FontWeight.w900 : FontWeight.w400,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                hoje ? '🎁' : (bloqueado ? '🔒' : '🪙'),
                style: const TextStyle(fontSize: 21, height: 1.05),
              ),
              const SizedBox(height: 4),
              Text(
                _formatarInteiro(dia.recompensa),
                style: const TextStyle(
                  color: RecompensasScreen._goldHi,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        if (resgatado)
          const Positioned(
            top: 5,
            right: 7,
            child: Text(
              '✓',
              style: TextStyle(
                color: Color(0xFF5FD08A),
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
      ],
    );

    content = Opacity(opacity: resgatado || bloqueado ? .52 : 1, child: content);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            color: hoje ? null : RecompensasScreen._card,
            gradient: hoje
                ? const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF2A1E0C), Color(0xFF191007)],
                  )
                : null,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: hoje ? RecompensasScreen._gold : Colors.white.withValues(alpha: .07),
              width: hoje ? 1.6 : 1,
            ),
            boxShadow: hoje
                ? [
                    BoxShadow(
                      color: RecompensasScreen._gold.withValues(alpha: .34),
                      blurRadius: 12,
                    ),
                  ]
                : null,
          ),
          child: content,
        ),
      ),
    );
  }
}

class _BauCard extends StatelessWidget {
  final BauReal bau;
  final VoidCallback onTap;

  const _BauCard({required this.bau, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Color(0xFF3A2450), Color(0xFF22143A)],
            ),
            border: Border.all(color: const Color(0xAAB98BFF), width: 1.4),
            boxShadow: bau.disponivel
                ? [
                    BoxShadow(
                      color: const Color(0xFFB98BFF).withValues(alpha: .28),
                      blurRadius: 13,
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              const Text('👑', style: TextStyle(fontSize: 34, height: 1)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bau.titulo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFE6D0FF),
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      bau.descricao,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFC9B8E8),
                        fontSize: 10.5,
                        height: 1.12,
                      ),
                    ),
                  ],
                ),
              ),
              if (bau.disponivel)
                const Padding(
                  padding: EdgeInsets.only(left: 6),
                  child: Icon(Icons.lock_open_rounded, color: Color(0xFFE6D0FF), size: 19),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MissionsList extends StatelessWidget {
  final List<Missao> missoes;
  final ValueChanged<String> onResgatar;

  const _MissionsList({required this.missoes, required this.onResgatar});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        children: [
          for (var i = 0; i < missoes.length; i++) ...[
            _MissionCard(
              missao: missoes[i],
              onResgatar: () => onResgatar(missoes[i].id),
            ),
            if (i != missoes.length - 1) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _MissionCard extends StatelessWidget {
  final Missao missao;
  final VoidCallback onResgatar;

  const _MissionCard({required this.missao, required this.onResgatar});

  @override
  Widget build(BuildContext context) {
    final completa = missao.progresso >= missao.meta;
    final progresso = missao.meta <= 0
        ? 0.0
        : (missao.progresso / missao.meta).clamp(0.0, 1.0).toDouble();

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: RecompensasScreen._card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: RecompensasScreen._border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(missao.icone, style: const TextStyle(fontSize: 19, height: 1)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  missao.titulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: RecompensasScreen._text,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '+${_formatarInteiro(missao.recompensa)} 🪙',
                style: const TextStyle(
                  color: RecompensasScreen._gold,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _ProgressBar(valor: progresso, altura: 7),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  completa
                      ? '${missao.progresso}/${missao.meta} · completa'
                      : '${missao.progresso}/${missao.meta}',
                  style: const TextStyle(
                    color: RecompensasScreen._muted,
                    fontSize: 10,
                  ),
                ),
              ),
              if (completa)
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onResgatar,
                    borderRadius: BorderRadius.circular(9),
                    child: Ink(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(9),
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFFF6D77A), Color(0xFFE0A83A)],
                        ),
                      ),
                      child: const Text(
                        'Resgatar',
                        style: TextStyle(
                          color: Color(0xFF3A2606),
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2016),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Text(
                    'Em progresso',
                    style: TextStyle(
                      color: Color(0xFF6B5F47),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EarnGrid extends StatelessWidget {
  final List<FonteMoeda> fontes;
  final ValueChanged<String> onTap;

  const _EarnGrid({required this.fontes, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: fontes.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 9,
          mainAxisSpacing: 9,
          childAspectRatio: 1.36,
        ),
        itemBuilder: (_, index) {
          final fonte = fontes[index];
          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => onTap(fonte.id),
              borderRadius: BorderRadius.circular(12),
              child: Ink(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 9),
                decoration: BoxDecoration(
                  color: RecompensasScreen._card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: RecompensasScreen._border),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(fonte.icone, style: const TextStyle(fontSize: 23, height: 1)),
                    const SizedBox(height: 5),
                    Text(
                      fonte.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFFD9C79A),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '+${_formatarInteiro(fonte.valor)}',
                      style: const TextStyle(
                        color: Color(0xFF8FE0B0),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final double valor;
  final double altura;

  const _ProgressBar({required this.valor, required this.altura});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: altura,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .34),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: RecompensasScreen._gold.withValues(alpha: .15)),
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: valor.clamp(0.0, 1.0).toDouble(),
        child: const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFF6E2A6), Color(0xFFE0A83A)],
            ),
          ),
        ),
      ),
    );
  }
}

class _RecompensasSkeleton extends StatelessWidget {
  const _RecompensasSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(14, 10, 14, 0),
          child: _SkeletonBox(height: 66, radius: 14),
        ),
        const _SkeletonSectionHeader(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 1.43,
            children: const [
              _SkeletonBox(height: 72),
              _SkeletonBox(height: 72),
              _SkeletonBox(height: 72),
              _SkeletonBox(height: 72),
              _SkeletonBox(height: 72),
              _SkeletonBox(height: 72),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(14, 8, 14, 0),
          child: _SkeletonBox(height: 67, radius: 14),
        ),
        const _SkeletonSectionHeader(),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 14),
          child: Column(
            children: [
              _SkeletonBox(height: 85),
              SizedBox(height: 8),
              _SkeletonBox(height: 85),
              SizedBox(height: 8),
              _SkeletonBox(height: 85),
            ],
          ),
        ),
        const _SkeletonSectionHeader(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            crossAxisSpacing: 9,
            mainAxisSpacing: 9,
            childAspectRatio: 1.36,
            children: const [
              _SkeletonBox(height: 78),
              _SkeletonBox(height: 78),
              _SkeletonBox(height: 78),
              _SkeletonBox(height: 78),
              _SkeletonBox(height: 78),
              _SkeletonBox(height: 78),
            ],
          ),
        ),
      ],
    );
  }
}

class _SkeletonSectionHeader extends StatelessWidget {
  const _SkeletonSectionHeader();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 17, 16, 8),
      child: Row(
        children: [
          _SkeletonBox(width: 118, height: 12, radius: 4),
          Spacer(),
          _SkeletonBox(width: 74, height: 10, radius: 4),
        ],
      ),
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;

  const _SkeletonBox({this.width, required this.height, this.radius = 12});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFF2A211B),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Colors.white.withValues(alpha: .035)),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String mensagem;
  final VoidCallback onRecarregar;

  const _ErrorCard({required this.mensagem, required this.onRecarregar});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 26),
      decoration: BoxDecoration(
        color: RecompensasScreen._card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: RecompensasScreen._border),
      ),
      child: Column(
        children: [
          const Icon(Icons.card_giftcard_rounded, color: RecompensasScreen._gold, size: 39),
          const SizedBox(height: 12),
          const Text(
            'Algo deu errado',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: RecompensasScreen._text,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            mensagem,
            textAlign: TextAlign.center,
            style: const TextStyle(color: RecompensasScreen._muted, fontSize: 11.5),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: onRecarregar,
            style: FilledButton.styleFrom(
              backgroundColor: RecompensasScreen._gold,
              foregroundColor: const Color(0xFF3A2606),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
            ),
            child: const Text('Tentar de novo', style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }
}

String _formatarInteiro(int valor) {
  final negativo = valor < 0;
  final texto = valor.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < texto.length; i++) {
    if (i > 0 && (texto.length - i) % 3 == 0) buffer.write('.');
    buffer.write(texto[i]);
  }
  return negativo ? '-$buffer' : buffer.toString();
}
