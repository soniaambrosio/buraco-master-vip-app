import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'perfil_screen.dart' show NavDestino;

enum RankingAba { temporada, global, amigos }

enum RankingEstado { carregando, normal, erro, vazio }

enum Direcao { subiu, desceu, estavel }

class DivisaoAtual {
  final String nome;
  final String icone;
  final int pontos;
  final int pontosProxima;
  final int faltamPontos;
  final String proximaDivisao;
  final int posicaoLiga;

  const DivisaoAtual({
    required this.nome,
    required this.icone,
    required this.pontos,
    required this.pontosProxima,
    required this.faltamPontos,
    required this.proximaDivisao,
    required this.posicaoLiga,
  });
}

class PodioEntry {
  final int posicao;
  final String nome;
  final String avatar;
  final String moldura;
  final int pontos;
  final bool ehVoce;

  const PodioEntry({
    required this.posicao,
    required this.nome,
    required this.avatar,
    required this.moldura,
    required this.pontos,
    required this.ehVoce,
  });
}

class RankingRow {
  final int posicao;
  final String nome;
  final String avatar;
  final String liga;
  final int pontos;
  final Direcao direcao;
  final int delta;
  final bool ehVoce;
  final String? selo;

  const RankingRow({
    required this.posicao,
    required this.nome,
    required this.avatar,
    required this.liga,
    required this.pontos,
    required this.direcao,
    required this.delta,
    required this.ehVoce,
    this.selo,
  });
}

class LigaEscada {
  final String nome;
  final String icone;
  final bool atual;

  const LigaEscada({
    required this.nome,
    required this.icone,
    required this.atual,
  });
}

/// View-model visual do contrato entregue pelo Claude.
///
/// Os tipos ficam temporariamente neste arquivo para a fatia visual compilar de
/// forma isolada. Na integração, o Claude pode movê-los para `lib/models/`
/// preservando exatamente esta API pública.
class RankingVM {
  final RankingAba aba;
  final String faixaTempo;
  final bool mostrarHall;
  final DivisaoAtual? divisao;
  final List<PodioEntry> podio;
  final List<RankingRow> lista;
  final List<LigaEscada> escadaLigas;

  const RankingVM({
    required this.aba,
    required this.faixaTempo,
    required this.mostrarHall,
    required this.divisao,
    required this.podio,
    required this.lista,
    required this.escadaLigas,
  });

  factory RankingVM.mock({RankingAba aba = RankingAba.temporada}) {
    final temporada = aba == RankingAba.temporada;

    return RankingVM(
      aba: aba,
      faixaTempo: temporada ? 'Temporada acaba em 12d 6h' : '',
      mostrarHall: true,
      divisao: temporada
          ? const DivisaoAtual(
              nome: 'Diamante III',
              icone: 'assets/ranking/divisao_diamante.webp',
              pontos: 1240,
              pontosProxima: 1500,
              faltamPontos: 260,
              proximaDivisao: 'Diamante II',
              posicaoLiga: 12,
            )
          : null,
      podio: const [
        PodioEntry(
          posicao: 1,
          nome: 'Sônia Rainha',
          avatar: '👑',
          moldura: 'assets/ranking/podio_ouro.webp',
          pontos: 5020,
          ehVoce: false,
        ),
        PodioEntry(
          posicao: 2,
          nome: 'Marina',
          avatar: '🐱',
          moldura: 'assets/ranking/podio_prata.webp',
          pontos: 4180,
          ehVoce: false,
        ),
        PodioEntry(
          posicao: 3,
          nome: 'Beto',
          avatar: '🦊',
          moldura: 'assets/ranking/podio_bronze.webp',
          pontos: 3910,
          ehVoce: false,
        ),
      ],
      lista: const [
        RankingRow(
          posicao: 4,
          nome: 'Cláudia',
          avatar: '🐰',
          liga: 'Diamante',
          pontos: 3640,
          direcao: Direcao.subiu,
          delta: 2,
          ehVoce: false,
        ),
        RankingRow(
          posicao: 5,
          nome: 'Ricardo',
          avatar: '🐻',
          liga: 'Diamante',
          pontos: 3500,
          direcao: Direcao.desceu,
          delta: 1,
          ehVoce: false,
        ),
        RankingRow(
          posicao: 12,
          nome: 'Você',
          avatar: '👑',
          liga: 'Diamante III',
          pontos: 1240,
          direcao: Direcao.subiu,
          delta: 3,
          ehVoce: true,
        ),
        RankingRow(
          posicao: 13,
          nome: 'Fernanda',
          avatar: '🐶',
          liga: 'Diamante',
          pontos: 1180,
          direcao: Direcao.subiu,
          delta: 1,
          ehVoce: false,
        ),
        RankingRow(
          posicao: 14,
          nome: 'Paulo',
          avatar: '🐵',
          liga: 'Ouro',
          pontos: 1090,
          direcao: Direcao.desceu,
          delta: 2,
          ehVoce: false,
        ),
      ],
      escadaLigas: const [
        LigaEscada(
          nome: 'Bronze',
          icone: 'assets/ranking/liga_bronze.webp',
          atual: false,
        ),
        LigaEscada(
          nome: 'Prata',
          icone: 'assets/ranking/liga_prata.webp',
          atual: false,
        ),
        LigaEscada(
          nome: 'Ouro',
          icone: 'assets/ranking/liga_ouro.webp',
          atual: false,
        ),
        LigaEscada(
          nome: 'Diamante',
          icone: 'assets/ranking/liga_diamante.webp',
          atual: true,
        ),
        LigaEscada(
          nome: 'Lenda',
          icone: 'assets/ranking/liga_lenda.webp',
          atual: false,
        ),
      ],
    );
  }
}

class RankingScreen extends StatelessWidget {
  final RankingVM vm;
  final RankingEstado estado;
  final String? mensagemErro;
  final VoidCallback onVoltar;
  final ValueChanged<RankingAba> onTrocarAba;
  final VoidCallback onAbrirHall;
  final ValueChanged<int> onVerJogador;
  final VoidCallback onRecarregar;
  final VoidCallback? onCarregarMais;
  final ValueChanged<NavDestino> onNavTap;

  const RankingScreen({
    super.key,
    required this.vm,
    this.estado = RankingEstado.normal,
    this.mensagemErro,
    required this.onVoltar,
    required this.onTrocarAba,
    required this.onAbrirHall,
    required this.onVerJogador,
    required this.onRecarregar,
    this.onCarregarMais,
    required this.onNavTap,
  });

  static const _ouro = Color(0xFFEFB94A);
  static const _ouroClaro = Color(0xFFF6E2A6);
  static const _card = Color(0xFF1C130C);
  static const _texto = Color(0xFFEFE3CC);
  static const _textoSec = Color(0xFFB6A884);
  static const _borda = Color(0x33EFB94A);
  static const _azulClaro = Color(0xFFBFE3FF);
  static const _azulSec = Color(0xFFA9C3E0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF241812), Color(0xFF120A06), Colors.black],
            stops: [0, .55, 1],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(
                children: [
                  Expanded(
                    child: RefreshIndicator(
                      color: _ouro,
                      backgroundColor: _card,
                      onRefresh: () => Future<void>.sync(onRecarregar),
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _topo(),
                            if (vm.mostrarHall) _hall(),
                            _abas(),
                            ..._conteudoPorEstado(),
                          ],
                        ),
                      ),
                    ),
                  ),
                  _navInferior(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _conteudoPorEstado() {
    switch (estado) {
      case RankingEstado.carregando:
        return [_carregando()];
      case RankingEstado.erro:
        return [_estadoCard(
          icone: Icons.wifi_off_rounded,
          titulo: mensagemErro ?? 'Não consegui carregar o ranking agora.',
          subtitulo: 'Tente novamente em alguns instantes.',
          acao: 'Tentar de novo',
          onTap: onRecarregar,
        )];
      case RankingEstado.vazio:
        return [_estadoCard(
          icone: Icons.groups_2_outlined,
          titulo: 'Ainda sem ninguém aqui',
          subtitulo: 'Quando houver jogadores nesta aba, o ranking aparece aqui.',
        )];
      case RankingEstado.normal:
        return [
          if (vm.divisao != null) _divisao(vm.divisao!),
          if (vm.podio.isNotEmpty) _podio(),
          if (vm.lista.isNotEmpty) _lista(),
          if (onCarregarMais != null && vm.lista.isNotEmpty) _carregarMais(),
          if (vm.escadaLigas.isNotEmpty) _escada(),
        ];
    }
  }

  Widget _topo() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 14, 4),
      child: Row(
        children: [
          Tooltip(
            message: 'Voltar',
            child: InkResponse(
              onTap: onVoltar,
              radius: 24,
              child: const SizedBox(
                width: 36,
                height: 36,
                child: Icon(Icons.chevron_left_rounded, color: _ouro, size: 30),
              ),
            ),
          ),
          const SizedBox(width: 2),
          const Text(
            'Ranking',
            style: TextStyle(
              color: _ouroClaro,
              fontSize: 17,
              fontWeight: FontWeight.w800,
              letterSpacing: .3,
            ),
          ),
          const Spacer(),
          if (vm.faixaTempo.trim().isNotEmpty)
            Flexible(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 190),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: .33),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _borda),
                ),
                child: Text.rich(
                  _tempoSpan(vm.faixaTempo),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFFC9BA99), fontSize: 11),
                ),
              ),
            ),
        ],
      ),
    );
  }

  TextSpan _tempoSpan(String texto) {
    final partes = texto.trim().split(' ');
    if (partes.length < 2) return TextSpan(text: texto);
    final destaque = partes.length >= 2 ? partes.sublist(partes.length - 2).join(' ') : '';
    final prefixo = texto.substring(0, math.max(0, texto.length - destaque.length));
    return TextSpan(
      children: [
        TextSpan(text: prefixo),
        TextSpan(
          text: destaque,
          style: const TextStyle(color: _ouro, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }

  Widget _hall() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onAbrirHall,
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [Color(0xFF2A1748), Color(0xFF1A1030)],
              ),
              border: Border.all(color: const Color(0xAAB98BFF), width: 1.4),
              boxShadow: const [
                BoxShadow(color: Colors.black38, blurRadius: 14, offset: Offset(0, 3)),
              ],
            ),
            child: const Row(
              children: [
                Text('🏛️', style: TextStyle(fontSize: 26)),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hall dos Imortais',
                        style: TextStyle(
                          color: Color(0xFFE6D0FF),
                          fontSize: 14.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 1),
                      Text(
                        'as maiores lendas do Buraco',
                        style: TextStyle(color: Color(0xFFC3B0E8), fontSize: 10.5),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: Color(0xFFD9C2FF), size: 23),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _abas() {
    const itens = [
      (RankingAba.temporada, 'Temporada'),
      (RankingAba.global, 'Global'),
      (RankingAba.amigos, 'Amigos'),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
      child: Row(
        children: [
          for (var i = 0; i < itens.length; i++) ...[
            Expanded(child: _aba(itens[i].$1, itens[i].$2)),
            if (i != itens.length - 1) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _aba(RankingAba aba, String label) {
    final ativa = vm.aba == aba;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: ativa ? null : () => onTrocarAba(aba),
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: ativa
                ? const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFF6E2A6), Color(0xFFE0A83A)],
                  )
                : null,
            color: ativa ? null : Colors.black.withValues(alpha: .25),
            border: ativa ? null : Border.all(color: Colors.white.withValues(alpha: .07)),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            style: TextStyle(
              color: ativa ? const Color(0xFF3A2606) : _textoSec,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _divisao(DivisaoAtual divisao) {
    final progresso = divisao.pontosProxima <= 0
        ? 0.0
        : (divisao.pontos / divisao.pontosProxima).clamp(0.0, 1.0).toDouble();

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFF20304A), Color(0xFF152033)],
        ),
        border: Border.all(color: const Color(0x405AA0FF)),
      ),
      child: Row(
        children: [
          _imagem(divisao.icone, 42),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  divisao.nome,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _azulClaro, fontSize: 16, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 2),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: '${_formatar(divisao.pontos)} pts · faltam '),
                      TextSpan(
                        text: _formatar(divisao.faltamPontos),
                        style: const TextStyle(color: _azulClaro, fontWeight: FontWeight.w800),
                      ),
                      TextSpan(text: ' pra ${divisao.proximaDivisao}'),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _azulSec, fontSize: 11),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: SizedBox(
                    height: 7,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ColoredBox(color: Colors.black.withValues(alpha: .33)),
                        FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: progresso,
                          child: const DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [Color(0xFF7FBAFF), _azulClaro]),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            children: [
              Text(
                '#${divisao.posicaoLiga}',
                style: const TextStyle(color: _ouroClaro, fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const Text('na liga', style: TextStyle(color: _azulSec, fontSize: 8.5)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _podio() {
    PodioEntry? achar(int posicao) {
      for (final item in vm.podio) {
        if (item.posicao == posicao) return item;
      }
      return null;
    }

    final itens = [achar(2), achar(1), achar(3)];
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < itens.length; i++) ...[
            Expanded(
              child: itens[i] == null
                  ? const SizedBox.shrink()
                  : _podioColuna(itens[i]!),
            ),
            if (i != itens.length - 1) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _podioColuna(PodioEntry entry) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onVerJogador(entry.posicao),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final spec = _podioSpec(entry.posicao);
                  final largura = math.min(spec.largura, constraints.maxWidth);
                  final escala = largura / spec.largura;
                  final altura = spec.altura * escala;
                  final avatar = spec.avatar * escala;
                  return SizedBox(
                    width: largura,
                    height: altura,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          left: largura * spec.x - avatar / 2,
                          top: altura * spec.y - avatar / 2,
                          child: ClipOval(
                            child: Container(
                              width: avatar,
                              height: avatar,
                              decoration: const BoxDecoration(
                                gradient: RadialGradient(
                                  center: Alignment(-.2, -.35),
                                  colors: [Color(0xFF3A2606), Color(0xFF1A1206)],
                                ),
                              ),
                              child: _avatar(entry.avatar, avatar * .52),
                            ),
                          ),
                        ),
                        Positioned.fill(
                          child: Image.asset(
                            entry.moldura,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Center(
                              child: Icon(Icons.workspace_premium_rounded, color: _ouro, size: 54),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              Text(
                entry.nome,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: entry.ehVoce ? _ouroClaro : _texto,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                _formatar(entry.pontos),
                style: const TextStyle(color: _ouro, fontSize: 10, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }

  _PodioSpec _podioSpec(int posicao) {
    switch (posicao) {
      case 1:
        return const _PodioSpec(
          largura: 104,
          altura: 123.4133,
          avatar: 59,
          x: .500,
          y: .492,
        );
      case 2:
        return const _PodioSpec(
          largura: 86,
          altura: 104.6333,
          avatar: 48,
          x: .501,
          y: .456,
        );
      default:
        return const _PodioSpec(
          largura: 100,
          altura: 103,
          avatar: 47,
          x: .419,
          y: .457,
        );
    }
  }

  Widget _lista() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
      child: Column(
        children: [
          for (var i = 0; i < vm.lista.length; i++) ...[
            _linha(vm.lista[i]),
            if (i != vm.lista.length - 1) const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }

  Widget _linha(RankingRow item) {
    final direcao = _direcao(item);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onVerJogador(item.posicao),
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: item.ehVoce ? const Color(0xFF2A1E0C) : _card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: item.ehVoce ? _ouro : Colors.white.withValues(alpha: .06),
              width: item.ehVoce ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 22,
                child: Text(
                  '${item.posicao}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: _textoSec, fontSize: 13, fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF2A1C10),
                  border: Border.all(color: _ouro.withValues(alpha: .33), width: 1.5),
                ),
                child: ClipOval(child: _avatar(item.avatar, 15)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            item.nome,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: _texto, fontSize: 13, fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (item.ehVoce) ...[
                          const SizedBox(width: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(color: _ouro, borderRadius: BorderRadius.circular(6)),
                            child: const Text(
                              'VOCÊ',
                              style: TextStyle(color: Color(0xFF3A2606), fontSize: 8, fontWeight: FontWeight.w900),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      item.liga,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Color(0xFF9FDCFF), fontSize: 10),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatar(item.pontos),
                    style: const TextStyle(color: _ouroClaro, fontSize: 13, fontWeight: FontWeight.w800),
                  ),
                  Text(
                    direcao.$1,
                    style: TextStyle(color: direcao.$2, fontSize: 10, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  (String, Color) _direcao(RankingRow item) {
    switch (item.direcao) {
      case Direcao.subiu:
        return ('▲ ${item.delta}', const Color(0xFF5FD08A));
      case Direcao.desceu:
        return ('▼ ${item.delta}', const Color(0xFFE07A6E));
      case Direcao.estavel:
        return ('—', _textoSec);
    }
  }

  Widget _carregarMais() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
      child: TextButton(
        onPressed: onCarregarMais,
        style: TextButton.styleFrom(foregroundColor: _ouro),
        child: const Text('Carregar mais', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _escada() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SUAS LIGAS',
            style: TextStyle(color: _ouro, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.5),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final liga in vm.escadaLigas)
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: liga.atual
                              ? [BoxShadow(color: _ouro.withValues(alpha: .55), blurRadius: 10)]
                              : null,
                        ),
                        child: Opacity(opacity: liga.atual ? 1 : .72, child: _imagem(liga.icone, 30)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        liga.nome,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: liga.atual ? _ouro : const Color(0xFF8A7C5E),
                          fontSize: 9,
                          fontWeight: liga.atual ? FontWeight.w800 : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _navInferior() {
    final itens = const [
      (NavDestino.inicio, 'Início', 'assets/ranking/nav_inicio.webp'),
      (NavDestino.ranking, 'Ranking', 'assets/ranking/nav_ranking.webp'),
      (NavDestino.loja, 'Loja', 'assets/ranking/nav_loja.webp'),
      (NavDestino.perfil, 'Perfil', 'assets/ranking/nav_perfil.webp'),
    ];

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0D0805),
        border: Border(top: BorderSide(color: _borda)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          for (final item in itens)
            Expanded(
              child: InkWell(
                onTap: () => onNavTap(item.$1),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 1),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Opacity(
                        opacity: item.$1 == NavDestino.ranking ? 1 : .42,
                        child: _imagem(item.$3, 24),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.$2,
                        style: TextStyle(
                          color: item.$1 == NavDestino.ranking ? _ouro : Colors.white.withValues(alpha: .25),
                          fontSize: 10.5,
                          fontWeight: item.$1 == NavDestino.ranking ? FontWeight.w700 : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _carregando() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      child: Column(
        children: [
          _skeleton(height: 78),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: _podioSkeleton(86)),
              const SizedBox(width: 8),
              Expanded(child: _podioSkeleton(104)),
              const SizedBox(width: 8),
              Expanded(child: _podioSkeleton(92)),
            ],
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < 5; i++) ...[
            _skeleton(height: 50),
            if (i != 4) const SizedBox(height: 6),
          ],
          const SizedBox(height: 16),
          Align(alignment: Alignment.centerLeft, child: _skeleton(width: 92, height: 11)),
          const SizedBox(height: 10),
          Row(
            children: [
              for (var i = 0; i < 5; i++) ...[
                Expanded(child: _skeleton(height: 42)),
                if (i != 4) const SizedBox(width: 4),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _podioSkeleton(double altura) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _skeleton(width: double.infinity, height: altura, radius: 999),
        const SizedBox(height: 8),
        _skeleton(width: 62, height: 10),
        const SizedBox(height: 4),
        _skeleton(width: 40, height: 9),
      ],
    );
  }

  Widget _estadoCard({
    required IconData icone,
    required String titulo,
    required String subtitulo,
    String? acao,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 18, 14, 0),
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 26),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borda),
      ),
      child: Column(
        children: [
          Icon(icone, color: _ouro, size: 38),
          const SizedBox(height: 12),
          Text(
            titulo,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _texto, fontSize: 15, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 5),
          Text(
            subtitulo,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _textoSec, fontSize: 11.5),
          ),
          if (acao != null && onTap != null) ...[
            const SizedBox(height: 18),
            FilledButton(
              onPressed: onTap,
              style: FilledButton.styleFrom(
                backgroundColor: _ouro,
                foregroundColor: const Color(0xFF3A2606),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
              ),
              child: Text(acao, style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _skeleton({
    double width = double.infinity,
    required double height,
    double radius = 12,
  }) {
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

  Widget _avatar(String valor, double tamanho) {
    final v = valor.trim();
    if (v.startsWith('assets/')) {
      return Image.asset(
        v,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => Icon(Icons.person_rounded, color: _ouroClaro, size: tamanho),
      );
    }
    if (v.startsWith('http://') || v.startsWith('https://')) {
      return Image.network(
        v,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => Icon(Icons.person_rounded, color: _ouroClaro, size: tamanho),
      );
    }
    return Center(child: Text(v.isEmpty ? '👤' : v, style: TextStyle(fontSize: tamanho, height: 1)));
  }

  Widget _imagem(String caminho, double tamanho) {
    return Image.asset(
      caminho,
      width: tamanho,
      height: tamanho,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Icon(Icons.auto_awesome_rounded, color: _ouro, size: tamanho * .8),
    );
  }

  String _formatar(int valor) {
    final negativo = valor < 0;
    final texto = valor.abs().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < texto.length; i++) {
      if (i > 0 && (texto.length - i) % 3 == 0) buffer.write('.');
      buffer.write(texto[i]);
    }
    return negativo ? '-$buffer' : buffer.toString();
  }
}

class _PodioSpec {
  final double largura;
  final double altura;
  final double avatar;
  final double x;
  final double y;

  const _PodioSpec({
    required this.largura,
    required this.altura,
    required this.avatar,
    required this.x,
    required this.y,
  });
}
