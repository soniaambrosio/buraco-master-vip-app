// mesa_online_screen.dart — a mesa que a pessoa vê quando joga no servidor.
//
// ===========================================================================
// ESTA TELA NÃO SABE JOGAR BURACO
// ===========================================================================
//
// Ela recebe um [EstadoMesaOnline] pronto — já lido e validado pelo adaptador —
// e desenha. Não tem `Jogo`, não distribui carta, não valida sequência, não
// conta ponto e não decide de quem é a vez. Tudo o que aparece aqui veio da
// visão que o servidor calculou para ESTE assento.
//
// A consequência prática, e o motivo de a OS insistir nela: quando o servidor
// não manda um dado, o componente correspondente SOME ou a ação fica
// desabilitada com explicação. Nada é completado com valor plausível. Uma mesa
// com meia informação é honesta; uma mesa com informação inventada é uma mesa
// que mente com cara de certeza.
//
// ===========================================================================
// O QUE É LOCAL AQUI
// ===========================================================================
//
// Uma coisa só: a SELEÇÃO. Quais cartas o dedo da pessoa está segurando antes
// de ela decidir o que fazer com elas. A seleção não existe para o servidor,
// não vai no fio, não muda a mão e é jogada fora a cada visão nova — porque um
// retrato novo pode ter tirado da mão exatamente a carta que estava marcada.
//
// ===========================================================================
// O QUE NÃO TEM, E POR QUÊ
// ===========================================================================
//
//   * PRAZO DO TURNO. O servidor de `16a692b` não manda relógio nenhum na
//     visão de assento. Um cronômetro desenhado aqui seria contagem inventada,
//     e a pessoa acreditaria nela.
//   * AVATAR. A visão traz `avatarTipo`/`avatarId`, mas o adaptador não os
//     transporta e esta fatia não desenha foto. O lugar mostra apelido.
//   * MÃO ALHEIA. Não existe caminho: `AssentoOnline` só tem contagem.
//   * CONQUISTA E PONTUAÇÃO DE RANKING. Não se concede nada por inferência do
//     cliente. O resultado que aparece é o que o servidor declarou.

import 'package:flutter/material.dart';

import 'arte_das_cartas.dart';
import 'estado_mesa_online.dart';
import 'porta_de_comandos_online.dart';

const _fundo = Color(0xFF0E2A1B);
const _feltro = Color(0xFF143D28);
const _ouro = Color(0xFFEFB94A);
const _ouroClaro = Color(0xFFF6E2A6);
const _texto = Color(0xFFEFE3CC);
const _mut = Color(0xFF9A8C6C);

class MesaOnlineScreen extends StatefulWidget {
  const MesaOnlineScreen({
    super.key,
    required this.estado,
    required this.porta,
    required this.conectado,
    required this.onSair,
    this.avisoDeConexao,
  });

  final EstadoMesaOnline estado;
  final PortaDeComandosOnline porta;

  /// O transporte está autenticado agora. Falso durante uma reconexão — e
  /// enquanto for falso, nenhum comando é oferecido.
  final bool conectado;

  /// O que dizer sobre a conexão, quando há o que dizer ("reconectando…").
  final String? avisoDeConexao;

  final VoidCallback onSair;

  @override
  State<MesaOnlineScreen> createState() => _MesaOnlineScreenState();
}

class _MesaOnlineScreenState extends State<MesaOnlineScreen> {
  /// Ids das cartas marcadas pelo dedo. Local, visual, e só.
  final Set<String> _selecionadas = {};

  @override
  void didUpdateWidget(MesaOnlineScreen antiga) {
    super.didUpdateWidget(antiga);
    // VISÃO NOVA APAGA A SELEÇÃO. Não é zelo: o retrato novo pode ter tirado da
    // mão a carta marcada (ela foi baixada, ou a rodada virou), e uma seleção
    // sobrevivente apontaria para carta que não está mais lá. O comando seguinte
    // sairia com um id que o servidor recusaria, e para a pessoa pareceria que
    // a mesa "não aceita" a carta que ela está vendo.
    if (!identical(antiga.estado, widget.estado)) {
      _selecionadas.removeWhere(
        (id) => !widget.estado.minhaMao.any((c) => c.id == id),
      );
    }
  }

  void _alternar(String id) {
    setState(() {
      if (!_selecionadas.remove(id)) _selecionadas.add(id);
    });
  }

  void _limparSelecao() => setState(_selecionadas.clear);

  @override
  Widget build(BuildContext context) {
    final e = widget.estado;
    final cap = e.capacidades(conectado: widget.conectado);

    return Scaffold(
      backgroundColor: _fundo,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A1F14),
        foregroundColor: _ouroClaro,
        title: Text('Mesa · ${e.modalidade.toUpperCase()}'),
        actions: [
          TextButton(
            onPressed: widget.onSair,
            child: const Text(
              'Sair',
              style: TextStyle(color: _mut, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (widget.avisoDeConexao != null)
              _FaixaDeAviso(texto: widget.avisoDeConexao!),
            _Placar(estado: e),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Assentos(estado: e),
                    const SizedBox(height: 10),
                    _Centro(
                      estado: e,
                      capacidades: cap,
                      onComprarMonte: widget.porta.comprarDoMonte,
                      onComprarLixo: widget.porta.comprarDoLixo,
                    ),
                    const SizedBox(height: 10),
                    _JogosBaixados(estado: e),
                    if (e.encerrada || e.rodadaEncerrada) ...[
                      const SizedBox(height: 10),
                      _Desfecho(estado: e),
                    ],
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
            _MinhaMao(
              estado: e,
              capacidades: cap,
              selecionadas: _selecionadas,
              onTocarCarta: _alternar,
            ),
            _BarraDeAcoes(
              estado: e,
              capacidades: cap,
              porta: widget.porta,
              selecionadas: _selecionadas,
              onLimparSelecao: _limparSelecao,
            ),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// Faixa de aviso — estado do transporte
// ===========================================================================

class _FaixaDeAviso extends StatelessWidget {
  const _FaixaDeAviso({required this.texto});
  final String texto;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    color: const Color(0xFF5A3A0E),
    padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 12),
    child: Text(
      texto,
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: Color(0xFFF6E2A6),
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

// ===========================================================================
// Placar — RELATIVO a quem está sentado
// ===========================================================================

class _Placar extends StatelessWidget {
  const _Placar({required this.estado});
  final EstadoMesaOnline estado;

  @override
  Widget build(BuildContext context) {
    final e = estado;
    final daVez = e.assentoDaVez;
    final String vez;
    if (e.encerrada) {
      vez = 'Partida encerrada';
    } else if (e.rodadaEncerrada) {
      vez = 'Rodada encerrada';
    } else if (e.suaVez) {
      vez = 'É a sua vez';
    } else if (daVez != null) {
      vez = 'Vez de ${daVez.apelido}';
    } else {
      // O servidor mandou uma vez que não corresponde a assento nenhum. Dizer
      // isso é melhor do que escolher um nome.
      vez = 'Aguardando a mesa';
    }

    return Container(
      color: const Color(0xFF0A1F14),
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LadoDoPlacar(
                rotulo: 'Sua dupla',
                pontos: e.meusPontos,
                destaque: true,
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 14),
                child: Text('×', style: TextStyle(color: _mut, fontSize: 18)),
              ),
              _LadoDoPlacar(
                rotulo: 'Adversários',
                pontos: e.pontosAdversarios,
                destaque: false,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            // A meta só aparece quando o servidor a declarou. Sem ela, a frase
            // termina na rodada — e não numa meta plausível.
            e.metaPontos == null
                ? 'Rodada ${e.rodada}'
                : 'Rodada ${e.rodada}  ·  meta ${e.metaPontos}',
            style: const TextStyle(color: _mut, fontSize: 11.5),
          ),
          const SizedBox(height: 6),
          Text(
            vez,
            style: TextStyle(
              color: e.suaVez ? _ouroClaro : _mut,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _LadoDoPlacar extends StatelessWidget {
  const _LadoDoPlacar({
    required this.rotulo,
    required this.pontos,
    required this.destaque,
  });

  final String rotulo;
  final int pontos;
  final bool destaque;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        rotulo,
        style: const TextStyle(color: _mut, fontSize: 10.5),
      ),
      Text(
        '$pontos',
        style: TextStyle(
          color: destaque ? _ouroClaro : _texto,
          fontSize: 22,
          fontWeight: FontWeight.w900,
        ),
      ),
    ],
  );
}

// ===========================================================================
// Os lugares
// ===========================================================================

class _Assentos extends StatelessWidget {
  const _Assentos({required this.estado});
  final EstadoMesaOnline estado;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    alignment: WrapAlignment.center,
    children: [
      for (final a in estado.assentos)
        _Lugar(
          assento: a,
          daVez: a.indice == estado.vez,
          minhaDupla: a.dupla == estado.minhaDupla,
        ),
    ],
  );
}

class _Lugar extends StatelessWidget {
  const _Lugar({
    required this.assento,
    required this.daVez,
    required this.minhaDupla,
  });

  final AssentoOnline assento;
  final bool daVez;
  final bool minhaDupla;

  @override
  Widget build(BuildContext context) {
    return Container(
      // Teto, e não largura fixa: num aparelho estreito dois lugares lado a
      // lado não cabem, e o `Wrap` acima já sabe quebrar a linha. Fixar a
      // largura faria o lugar estourar em vez de quebrar.
      constraints: const BoxConstraints(maxWidth: 154),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _feltro,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: daVez ? _ouro : const Color(0x22EFB94A),
          width: daVez ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  assento.ehVoce ? '${assento.apelido} (você)' : assento.apelido,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: minhaDupla ? _ouroClaro : _texto,
                    fontWeight: FontWeight.w800,
                    fontSize: 12.5,
                  ),
                ),
                Text(
                  // O tipo do assento é dado do servidor, e vale dizer: uma
                  // pessoa que caiu vira robô na mesa (é como o servidor
                  // segura a partida), e quem está jogando merece saber que o
                  // adversário agora é a máquina.
                  assento.ehBot ? 'robô' : (minhaDupla ? 'sua dupla' : 'adversário'),
                  style: const TextStyle(color: _mut, fontSize: 10.5),
                ),
              ],
            ),
          ),
          Column(
            children: [
              const Icon(Icons.style, size: 15, color: _mut),
              Text(
                '${assento.qtdCartas}',
                style: const TextStyle(
                  color: _texto,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// O centro da mesa: monte, lixo, mortos
// ===========================================================================

class _Centro extends StatelessWidget {
  const _Centro({
    required this.estado,
    required this.capacidades,
    required this.onComprarMonte,
    required this.onComprarLixo,
  });

  final EstadoMesaOnline estado;
  final CapacidadesDaMesa capacidades;
  final VoidCallback onComprarMonte;
  final VoidCallback onComprarLixo;

  @override
  Widget build(BuildContext context) {
    final e = estado;
    final podeLixo = capacidades.podeComprar && e.lixoQtd > 0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _feltro,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x22EFB94A)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PilhaFechada(
            rotulo: 'Monte',
            quantidade: e.monteQtd,
            habilitada: capacidades.podeComprar && e.monteQtd > 0,
            onTap: onComprarMonte,
          ),
          const SizedBox(width: 12),
          Expanded(child: _Lixo(estado: e, habilitado: podeLixo, onTap: onComprarLixo)),
          const SizedBox(width: 12),
          PilhaFechada(rotulo: 'Mortos', quantidade: e.mortosQtd),
        ],
      ),
    );
  }
}

class _Lixo extends StatelessWidget {
  const _Lixo({
    required this.estado,
    required this.habilitado,
    required this.onTap,
  });

  final EstadoMesaOnline estado;
  final bool habilitado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final e = estado;
    final aberto = e.lixoAberto;

    final Widget corpo;
    if (aberto != null) {
      // MODALIDADE ABERTA: o lixo inteiro é público, e o servidor o manda.
      corpo = SizedBox(
        height: 67,
        child: aberto.isEmpty
            ? const Center(
                child: Text(
                  'lixo vazio',
                  style: TextStyle(color: _mut, fontSize: 11),
                ),
              )
            : ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: aberto.length,
                separatorBuilder: (_, _) => const SizedBox(width: 3),
                itemBuilder: (_, i) => GestureDetector(
                  onTap: habilitado ? onTap : null,
                  child: CartaOnlineWidget(carta: aberto[i], largura: 40),
                ),
              ),
      );
    } else if (e.lixoTopo != null) {
      // NAS OUTRAS MODALIDADES só o topo é visível. O resto existe (a contagem
      // diz), mas não é nosso para mostrar.
      //
      // A contagem vai para o rótulo de baixo, e não ao lado da carta: numa
      // faixa estreita — que é o normal, porque esta coluna divide a largura
      // com o monte e os mortos — o texto ao lado não cabe e some cortado.
      corpo = SizedBox(
        height: 67,
        child: Align(
          alignment: Alignment.centerLeft,
          child: GestureDetector(
            onTap: habilitado ? onTap : null,
            child: CartaOnlineWidget(carta: e.lixoTopo!, largura: 40),
          ),
        ),
      );
    } else {
      corpo = const SizedBox(
        height: 67,
        child: Center(
          child: Text('lixo vazio', style: TextStyle(color: _mut, fontSize: 11)),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        corpo,
        const SizedBox(height: 4),
        Text(
          'Lixo · ${e.lixoQtd}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: _mut, fontSize: 10.5),
        ),
      ],
    );
  }
}

// ===========================================================================
// Jogos baixados — públicos das duas duplas
// ===========================================================================

class _JogosBaixados extends StatelessWidget {
  const _JogosBaixados({required this.estado});
  final EstadoMesaOnline estado;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _LadoDeJogos(
        titulo: 'Jogos da sua dupla',
        jogos: estado.meusJogos,
        minha: true,
      ),
      const SizedBox(height: 8),
      _LadoDeJogos(
        titulo: 'Jogos dos adversários',
        jogos: estado.jogosAdversarios,
        minha: false,
      ),
    ],
  );
}

class _LadoDeJogos extends StatelessWidget {
  const _LadoDeJogos({
    required this.titulo,
    required this.jogos,
    required this.minha,
  });

  final String titulo;
  final List<List<CartaOnline>> jogos;
  final bool minha;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: _feltro,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(
        color: minha ? const Color(0x44EFB94A) : const Color(0x18EFB94A),
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          style: TextStyle(
            color: minha ? _ouroClaro : _mut,
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        if (jogos.isEmpty)
          const Text(
            'nenhum jogo baixado',
            style: TextStyle(color: _mut, fontSize: 11),
          )
        else
          for (var i = 0; i < jogos.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                children: [
                  SizedBox(
                    width: 20,
                    child: Text(
                      '${i + 1}',
                      style: const TextStyle(color: _mut, fontSize: 10),
                    ),
                  ),
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: jogos[i].length,
                        separatorBuilder: (_, _) => const SizedBox(width: 2),
                        itemBuilder: (_, k) => CartaOnlineWidget(
                          carta: jogos[i][k],
                          largura: 28,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
      ],
    ),
  );
}

// ===========================================================================
// Desfecho — o resultado é o que o servidor declarou
// ===========================================================================

class _Desfecho extends StatelessWidget {
  const _Desfecho({required this.estado});
  final EstadoMesaOnline estado;

  @override
  Widget build(BuildContext context) {
    final e = estado;
    final String titulo;
    if (e.encerrada) {
      titulo = e.duplaQueBateu == null
          // Partida encerrada sem o servidor dizer quem bateu: mostrar o
          // placar é honesto, anunciar um vencedor não seria.
          ? 'A partida terminou'
          : (e.euBati ? '🏆 Sua dupla venceu' : 'A dupla adversária venceu');
    } else {
      titulo = e.duplaQueBateu == null
          ? 'A rodada terminou'
          : (e.euBati ? 'Sua dupla bateu' : 'A dupla adversária bateu');
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1C3D2A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x55EFB94A)),
      ),
      child: Column(
        children: [
          Text(
            titulo,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _ouroClaro,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Sua dupla ${e.meusPontos}  ×  ${e.pontosAdversarios} adversários',
            style: const TextStyle(color: _texto, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// A minha mão
// ===========================================================================

class _MinhaMao extends StatelessWidget {
  const _MinhaMao({
    required this.estado,
    required this.capacidades,
    required this.selecionadas,
    required this.onTocarCarta,
  });

  final EstadoMesaOnline estado;
  final CapacidadesDaMesa capacidades;
  final Set<String> selecionadas;
  final void Function(String id) onTocarCarta;

  @override
  Widget build(BuildContext context) {
    final e = estado;
    // Selecionar sem poder agir seria um gesto que não leva a lugar nenhum.
    final podeSelecionar = capacidades.podeBaixar || capacidades.podeDescartar;

    return Container(
      color: const Color(0xFF0A1F14),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Sua mão · ${e.minhaMao.length}',
                style: const TextStyle(color: _mut, fontSize: 11),
              ),
              if (e.precisaUsarTopo != null) ...[
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'use a carta destacada antes de descartar',
                    style: TextStyle(color: Color(0xFF63C6F5), fontSize: 10.5),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 82,
            child: e.minhaMao.isEmpty
                ? const Center(
                    child: Text(
                      'sem cartas na mão',
                      style: TextStyle(color: _mut, fontSize: 12),
                    ),
                  )
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: e.minhaMao.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 3),
                    itemBuilder: (_, i) {
                      final c = e.minhaMao[i];
                      return CartaOnlineWidget(
                        carta: c,
                        selecionada: selecionadas.contains(c.id),
                        destacada: e.precisaUsarTopo == c.id,
                        onTap: podeSelecionar ? () => onTocarCarta(c.id) : null,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// As ações
// ===========================================================================

class _BarraDeAcoes extends StatelessWidget {
  const _BarraDeAcoes({
    required this.estado,
    required this.capacidades,
    required this.porta,
    required this.selecionadas,
    required this.onLimparSelecao,
  });

  final EstadoMesaOnline estado;
  final CapacidadesDaMesa capacidades;
  final PortaDeComandosOnline porta;
  final Set<String> selecionadas;
  final VoidCallback onLimparSelecao;

  @override
  Widget build(BuildContext context) {
    final pendente = porta.pendente;
    final recusa = porta.mensagemDaRecusa;
    final selecao = selecionadas.toList();

    return Container(
      color: const Color(0xFF0A1F14),
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (pendente != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(_ouro),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    pendente.rotulo,
                    style: const TextStyle(color: _ouroClaro, fontSize: 12),
                  ),
                ],
              ),
            )
          else if (recusa != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: GestureDetector(
                onTap: porta.dispensarRecusa,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0x33E05B5B),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0x55E05B5B)),
                  ),
                  child: Text(
                    recusa,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFF6C9C9),
                      fontSize: 11.5,
                    ),
                  ),
                ),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: _Botao(
                  rotulo: selecao.isEmpty
                      ? 'Baixar'
                      : 'Baixar ${selecao.length}',
                  primario: false,
                  // Baixar com a mão vazia de seleção não é uma ação: o
                  // protocolo manda `ids`, e uma lista vazia seria um comando
                  // sem conteúdo.
                  onPressed: capacidades.podeBaixar && selecao.isNotEmpty
                      ? () {
                          porta.baixar(selecao);
                          onLimparSelecao();
                        }
                      : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Botao(
                  rotulo: 'Descartar',
                  primario: true,
                  // Um descarte é UMA carta: o comando leva `id`, no singular.
                  onPressed:
                      capacidades.podeDescartar && selecao.length == 1
                      ? () {
                          porta.descartar(selecao.first);
                          onLimparSelecao();
                        }
                      : null,
                ),
              ),
            ],
          ),
          if (!capacidades.conectado)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'sem conexão com o servidor — as ações voltam quando ela voltar',
                textAlign: TextAlign.center,
                style: TextStyle(color: _mut, fontSize: 10.5),
              ),
            ),
        ],
      ),
    );
  }
}

class _Botao extends StatelessWidget {
  const _Botao({
    required this.rotulo,
    required this.primario,
    required this.onPressed,
  });

  final String rotulo;
  final bool primario;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => primario
      ? ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: _ouro,
            foregroundColor: const Color(0xFF1C130C),
            disabledBackgroundColor: const Color(0xFF23372B),
            disabledForegroundColor: _mut,
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          onPressed: onPressed,
          child: Text(
            rotulo,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        )
      : OutlinedButton(
          style: OutlinedButton.styleFrom(
            foregroundColor: _ouroClaro,
            disabledForegroundColor: _mut,
            side: const BorderSide(color: Color(0x55EFB94A)),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          onPressed: onPressed,
          child: Text(
            rotulo,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        );
}
