// lobby_publico_screen.dart — a camada VISUAL do Lobby Público.
//
// ---------------------------------------------------------------------------
// ESTA TELA NÃO SABE FALAR COM O SERVIDOR
// ---------------------------------------------------------------------------
//
// Ela recebe um retrato já tipado e já ordenado, e desenha. Não pede, não
// reordena, não soma e não completa nada. É a mesma disciplina das outras telas
// desta pasta: `screens/` desenha, `casca/` decide.
//
// Duas consequências que valem dizer em voz alta:
//
//   * A ORDEM É A DO SERVIDOR. `retrato.mesas` chega ordenado (ingressável
//     primeiro, depois mais cheia, depois esperando há mais tempo) e é
//     percorrido na ordem em que veio. Não há `sort` neste arquivo, e não pode
//     haver: reordenar aqui faria a lista discordar do critério que o servidor
//     usa para dizer qual mesa está mais perto de completar.
//   * AS CONTAGENS DOS FILTROS SÃO AS DO SERVIDOR. O chip "Aberto" mostra
//     `presenca.porModalidade[aberto].mesas`, não `mesas.where(...).length`.
//     Os dois números costumam bater — e quando não baterem, o certo é o do
//     servidor, porque ele viu o registro inteiro e a lista pode ter sido
//     truncada, filtrada ou estar velha.
//
// O FILTRO OCULTA, NÃO RECALCULA. Escolher "Com vagas" esconde cards do retrato
// vigente. Nenhum número muda por causa disso.
//
// ---------------------------------------------------------------------------
// "PÚBLICA" NÃO APARECE EM CARD NENHUM
// ---------------------------------------------------------------------------
//
// A tela inteira só tem mesa pública. Repetir a palavra em cada card gastaria a
// largura mais disputada da linha para dizer o que o título já disse.

import 'package:flutter/material.dart';

import '../descoberta/estado_descoberta.dart';
import '../descoberta/modelo_descoberta.dart';

/// Os cinco filtros de apresentação. Enumeração fechada.
enum FiltroDoLobby {
  todas('Todas'),
  comVagas('Com vagas'),
  aberto('Aberto'),
  fechado('Fechado'),

  /// O rótulo vem de `ModalidadeDeMesa.sbtl.rotulo` — ver o construtor abaixo.
  /// Escrever `'STBL'` aqui criaria uma SEGUNDA fonte para o mesmo texto.
  stbl('');

  const FiltroDoLobby(this._rotuloLiteral);
  final String _rotuloLiteral;

  /// Modalidade que este filtro seleciona, ou `null` quando ele não filtra por
  /// modalidade.
  ModalidadeDeMesa? get modalidade => switch (this) {
    FiltroDoLobby.aberto => ModalidadeDeMesa.aberto,
    FiltroDoLobby.fechado => ModalidadeDeMesa.fechado,
    FiltroDoLobby.stbl => ModalidadeDeMesa.sbtl,
    _ => null,
  };

  /// O texto do chip. Para os filtros de modalidade ele vem do MODELO, que é o
  /// único lugar do aplicativo que sabe que `sbtl` se escreve STBL.
  String get rotulo => modalidade?.rotulo ?? _rotuloLiteral;

  bool aceita(MesaPublica m) => switch (this) {
    FiltroDoLobby.todas => true,
    FiltroDoLobby.comVagas => m.ingressavel,
    _ => m.modalidade == modalidade,
  };
}

/// Quanto tempo uma mesa espera, em texto de gente.
///
/// Segundos exatos não interessam a ninguém e mudariam o texto a cada quadro;
/// o que a pessoa quer saber é se a mesa acabou de abrir ou está lá há um bom
/// tempo.
String textoDeEspera(Duration d) {
  if (d.inSeconds < 60) return 'agora mesmo';
  if (d.inMinutes < 60) {
    final m = d.inMinutes;
    return 'há $m ${m == 1 ? 'minuto' : 'minutos'}';
  }
  final h = d.inHours;
  return 'há $h ${h == 1 ? 'hora' : 'horas'}';
}

class LobbyPublicoScreen extends StatefulWidget {
  const LobbyPublicoScreen({
    super.key,
    required this.retrato,
    required this.fase,
    required this.atualizando,
    required this.onVoltar,
    required this.onAtualizar,
    this.ultimaAtualizacaoRecusada = false,
    this.onEscolherMesa,
  });

  /// O retrato vigente, ou `null` quando ainda não há nenhum válido.
  final RetratoDaDescoberta? retrato;

  final FaseDaDescoberta fase;

  /// Há um pedido em voo.
  final bool atualizando;

  /// A última resposta foi descartada (inválida ou atrasada) e o retrato que
  /// está na tela é o anterior. A tela DIZ isso em vez de esvaziar a lista.
  final bool ultimaAtualizacaoRecusada;

  final VoidCallback onVoltar;
  final VoidCallback onAtualizar;

  /// A PORTA DO INGRESSO, e nada além disso.
  ///
  /// Recebe o código OPACO da mesa. Ela NÃO ingressa: quem a liga (a OS 38.3)
  /// abre o seletor de assento, e é lá que o pedido é feito. Esta tela
  /// continua sem saber falar com o servidor.
  ///
  /// `null` em prévia isolada — e aí o card não é botão, porque um nó tocável
  /// que não faz nada é pior que nenhum.
  final void Function(String codigo)? onEscolherMesa;

  @override
  State<LobbyPublicoScreen> createState() => _LobbyPublicoScreenState();
}

class _LobbyPublicoScreenState extends State<LobbyPublicoScreen> {
  static const _gold = Color(0xFFEFB94A);
  static const _goldHi = Color(0xFFF6E2A6);
  static const _card = Color(0xFF1C130C);
  static const _borda = Color(0x33EFB94A);
  static const _texto = Color(0xFFEFE3CC);
  static const _mut = Color(0xFF9A8C6C);
  static const _feltro = Color(0xFF123020);
  static const _feltroBorda = Color(0x882F7D4D);
  static const _verdeClaro = Color(0xFFA9D6BB);

  /// Piso de toque. A régua desta base: nada abaixo disto recebe gesto.
  static const double _alvoMinimo = 48;

  FiltroDoLobby _filtro = FiltroDoLobby.todas;

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
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _cabecalho(),
                  _resumo(),
                  _filtros(),
                  Expanded(child: _corpo()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // CABEÇALHO
  // -------------------------------------------------------------------------

  Widget _cabecalho() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 8, 10, 0),
      child: Row(
        children: [
          // `tooltip` vira o nome acessível do IconButton — e é ele que a régua
          // cobra. Ícone sem nome é nó tocável anônimo.
          IconButton(
            onPressed: widget.onVoltar,
            tooltip: 'Voltar',
            icon: const Icon(
              Icons.chevron_left,
              color: _gold,
              size: 30,
              semanticLabel: 'Voltar',
            ),
            constraints: const BoxConstraints(
              minWidth: _alvoMinimo,
              minHeight: _alvoMinimo,
            ),
          ),
          const Expanded(
            child: Text(
              'Lobby Público',
              style: TextStyle(
                color: _goldHi,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          _botaoAtualizar(),
        ],
      ),
    );
  }

  Widget _botaoAtualizar() {
    // ANUNCIADO UMA VEZ, e não a cada quadro. O rótulo muda de "Atualizar" para
    // "Atualizando" enquanto o pedido está em voo; um `liveRegion` aqui faria o
    // leitor de tela repetir a palavra a cada reconstrução, que numa lista que
    // se atualiza sozinha é a cada poucos segundos, para sempre.
    final emVoo = widget.atualizando;
    return IconButton(
      onPressed: emVoo ? null : widget.onAtualizar,
      tooltip: emVoo ? 'Atualizando a lista' : 'Atualizar a lista',
      icon: Icon(
        Icons.refresh_rounded,
        color: emVoo ? _mut : _gold,
        size: 26,
        semanticLabel: emVoo ? 'Atualizando a lista' : 'Atualizar a lista',
      ),
      constraints: const BoxConstraints(
        minWidth: _alvoMinimo,
        minHeight: _alvoMinimo,
      ),
    );
  }

  // -------------------------------------------------------------------------
  // RESUMO — os números OFICIAIS, do servidor
  // -------------------------------------------------------------------------

  Widget _resumo() {
    final p = widget.retrato?.presenca;
    if (p == null) return const SizedBox.shrink();
    final linha =
        '${p.jogadoresEmMesasPublicas} '
        '${p.jogadoresEmMesasPublicas == 1 ? 'jogador' : 'jogadores'} '
        'em ${p.mesasPublicas} ${p.mesasPublicas == 1 ? 'mesa' : 'mesas'} · '
        '${p.mesasPublicasComVagas} com ${p.mesasPublicasComVagas == 1 ? 'vaga' : 'vagas'}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 8),
      child: Text(linha, style: const TextStyle(color: _mut, fontSize: 13)),
    );
  }

  // -------------------------------------------------------------------------
  // FILTROS
  // -------------------------------------------------------------------------

  Widget _filtros() {
    final p = widget.retrato?.presenca;
    // `Wrap`, E NÃO UMA FAIXA QUE ROLA NA HORIZONTAL.
    //
    // A primeira versão era um `ListView` horizontal, e ela escondia dois dos
    // cinco filtros já em 390 dp — "Fechado" e "STBL" ficavam fora da
    // viewport, e um `ListView` nem constrói o que está fora. Rolar para o lado
    // é um gesto que quase ninguém descobre, e a §14.5 cobra "filtros e ações
    // alcançáveis" em 320 dp com fonte a 200%.
    //
    // Com `Wrap` os cinco existem sempre; o que muda com a fonte grande é o
    // número de linhas, e a lista abaixo continua rolando normalmente.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Wrap(
        children: [for (final f in FiltroDoLobby.values) _chip(f, p)],
      ),
    );
  }

  Widget _chip(FiltroDoLobby f, PresencaAgregada? p) {
    final selecionado = _filtro == f;
    final contagem = _contagemDo(f, p);
    final rotulo = contagem == null ? f.rotulo : '${f.rotulo} ($contagem)';

    // `excludeSemantics` AQUI LEVARIA O TOQUE JUNTO.
    //
    // A primeira versão era `Semantics(button:true, selected:..., label:...,
    // excludeSemantics:true, child: InkWell(...))`. O nó saía com `isButton` e
    // com o rótulo certo — e SEM a ação de toque, porque quem a fornece é o
    // `InkWell`, cuja semântica o `excludeSemantics` descartava. O resultado é
    // um controle que responde ao dedo e é inerte para o TalkBack: passa em
    // teste de `tester.tap` e é inacessível de verdade.
    //
    // A forma certa é o inverso: a semântica ENVOLVE o `InkWell` (herdando a
    // ação dele) e quem tem a semântica descartada é só o `Text` de dentro,
    // que produziria um segundo nó com o mesmo texto.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Semantics(
        button: true,
        selected: selecionado,
        label: rotulo,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => setState(() => _filtro = f),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              constraints: const BoxConstraints(minHeight: _alvoMinimo),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: selecionado ? const Color(0xFF3A2A15) : _card,
                border: Border.all(
                  color: selecionado ? _gold : _borda,
                  width: selecionado ? 1.6 : 1,
                ),
              ),
              child: ExcludeSemantics(
                child: Text(
                  rotulo,
                  style: TextStyle(
                    color: selecionado ? _goldHi : _texto,
                    fontSize: 13,
                    fontWeight: selecionado ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// A contagem do chip. SEMPRE do servidor — ver o cabeçalho do arquivo.
  int? _contagemDo(FiltroDoLobby f, PresencaAgregada? p) {
    if (p == null) return null;
    return switch (f) {
      FiltroDoLobby.todas => p.mesasPublicas,
      FiltroDoLobby.comVagas => p.mesasPublicasComVagas,
      _ => p.de(f.modalidade!).mesas,
    };
  }

  // -------------------------------------------------------------------------
  // CORPO
  // -------------------------------------------------------------------------

  Widget _corpo() {
    final retrato = widget.retrato;

    // A FASE MANDA QUANDO NÃO HÁ RETRATO. Havendo retrato, ele continua na
    // tela mesmo em `reconectando` — a lista de dez segundos atrás é mais útil
    // e mais honesta do que uma tela vazia.
    if (retrato == null) {
      return switch (widget.fase) {
        FaseDaDescoberta.ociosa || FaseDaDescoberta.carregando => _aviso(
          icone: Icons.hourglass_top_rounded,
          titulo: 'Procurando mesas…',
          detalhe: 'Estamos pedindo a lista ao servidor.',
        ),
        FaseDaDescoberta.reconectando => _aviso(
          icone: Icons.wifi_tethering_rounded,
          titulo: 'Reconectando…',
          detalhe: 'A conexão caiu e estamos voltando.',
        ),
        FaseDaDescoberta.servidorIndisponivel => _aviso(
          icone: Icons.cloud_off_rounded,
          titulo: 'Servidor indisponível',
          detalhe: 'Não consegui falar com o servidor agora.',
          acao: 'Tentar de novo',
        ),
        FaseDaDescoberta.retratoInvalido => _aviso(
          icone: Icons.report_problem_rounded,
          titulo: 'Resposta fora do contrato',
          detalhe:
              'O servidor respondeu algo que este aplicativo não sabe ler. '
              'Nada foi exibido de propósito.',
          acao: 'Tentar de novo',
        ),
        FaseDaDescoberta.sessaoEncerrada => _aviso(
          icone: Icons.lock_outline_rounded,
          titulo: 'Sessão encerrada',
          detalhe: 'Entre na sua conta para ver as mesas.',
        ),
        FaseDaDescoberta.disponivel => _aviso(
          icone: Icons.hourglass_top_rounded,
          titulo: 'Procurando mesas…',
          detalhe: 'Estamos pedindo a lista ao servidor.',
        ),
      };
    }

    if (retrato.mesas.isEmpty) {
      return _aviso(
        icone: Icons.table_restaurant_rounded,
        titulo: 'Nenhuma mesa aberta agora',
        detalhe: 'Assim que alguém abrir uma, ela aparece aqui.',
      );
    }

    final visiveis = retrato.mesas.where(_filtro.aceita).toList();
    if (visiveis.isEmpty) {
      return _aviso(
        icone: Icons.filter_alt_off_rounded,
        titulo: _filtro == FiltroDoLobby.comVagas
            ? 'Nenhuma mesa com vaga agora'
            : 'Nenhuma mesa nesse filtro',
        detalhe:
            'Há ${retrato.mesas.length} '
            '${retrato.mesas.length == 1 ? 'mesa' : 'mesas'} em outros filtros.',
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 2, 14, 24),
      children: [
        if (widget.ultimaAtualizacaoRecusada) _faixaDeAvisoDeAtraso(),
        for (final m in visiveis) _cardDaMesa(m),
      ],
    );
  }

  Widget _faixaDeAvisoDeAtraso() {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: const Color(0xFF2A1B0E),
        border: Border.all(color: _borda),
      ),
      child: const Text(
        'A última atualização não pôde ser aplicada. Esta lista pode estar '
        'desatualizada.',
        style: TextStyle(color: _mut, fontSize: 12.5, height: 1.25),
      ),
    );
  }

  Widget _aviso({
    required IconData icone,
    required String titulo,
    required String detalhe,
    String? acao,
  }) {
    // `ListView` e não `Column`: em 320 dp com fonte a 200% o bloco inteiro
    // passa da altura da tela, e sem rolagem o texto sairia pela borda.
    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
      children: [
        Semantics(
          container: true,
          label: '$titulo. $detalhe',
          excludeSemantics: true,
          child: Column(
            children: [
              Icon(icone, color: _mut, size: 44),
              const SizedBox(height: 12),
              Text(
                titulo,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _texto,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                detalhe,
                textAlign: TextAlign.center,
                style: const TextStyle(color: _mut, fontSize: 13, height: 1.3),
              ),
            ],
          ),
        ),
        if (acao != null) ...[
          const SizedBox(height: 16),
          Center(
            child: Semantics(
              button: true,
              label: acao,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: widget.onAtualizar,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    constraints: const BoxConstraints(
                      minHeight: _alvoMinimo,
                      minWidth: 160,
                    ),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: const Color(0xFF3A2A15),
                      border: Border.all(color: _gold, width: 1.4),
                    ),
                    child: Text(
                      acao,
                      style: const TextStyle(
                        color: _goldHi,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  // -------------------------------------------------------------------------
  // CARD
  // -------------------------------------------------------------------------

  /// A FRASE do card, para quem usa leitor de tela.
  ///
  /// Uma frase só, com tudo o que a pessoa vidente lê de relance — e nesta
  /// ordem, porque é a ordem em que a decisão é tomada: que mesa é, quanto
  /// falta, de que tipo, até quantos pontos, e desde quando espera.
  /// [tocavel] acrescenta a dica de ação. Ela só existe quando o card É
  /// botão: dizer "toque para escolher" num card inerte mandaria a pessoa
  /// tentar um gesto que não acontece.
  String frasePara(MesaPublica m, {bool tocavel = false}) {
    final partes = <String>[
      m.nome,
      '${m.jogadores} de ${m.capacidade} ${m.jogadores == 1 ? 'jogador' : 'jogadores'}',
      m.vagas == 0
          ? 'sem vagas'
          : '${m.vagas} ${m.vagas == 1 ? 'vaga' : 'vagas'}',
      'modalidade ${m.modalidade.rotulo}',
      'meta ${m.metaPontos} pontos',
      m.estadoIngresso.rotulo,
      'esperando ${textoDeEspera(m.aguardandoHa)}',
      for (final a in m.assentos) a.descricaoAcessivel,
      if (tocavel) 'toque para escolher seu lugar',
    ];
    return partes.join('. ');
  }

  Widget _cardDaMesa(MesaPublica m) {
    final escolher = widget.onEscolherMesa;
    // TOCÁVEL SÓ QUANDO A MESA ACEITA INGRESSO, e `ingressavel` vem do
    // SERVIDOR — não é `vagas > 0`. Mesa em andamento pode ter cadeira vazia
    // e mesmo assim não aceitar ninguém, e um card clicável ali mandaria a
    // pessoa buscar uma recusa que o retrato já sabia dar.
    final tocavel = escolher != null && m.ingressavel;
    final conteudo = _conteudoDoCard(m, tocavel: tocavel);

    if (!tocavel) {
      // Um nó tocável que não faz nada é pior que nenhum.
      return Semantics(
        container: true,
        label: frasePara(m),
        excludeSemantics: true,
        child: conteudo,
      );
    }
    // `excludeSemantics` AQUI LEVARIA O TOQUE JUNTO: a semântica ENVOLVE o
    // `InkWell` (herdando a ação dele) e quem tem a semântica descartada é o
    // conteúdo de dentro.
    return Semantics(
      button: true,
      label: frasePara(m, tocavel: true),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => escolher(m.codigo),
          borderRadius: BorderRadius.circular(14),
          child: ExcludeSemantics(child: conteudo),
        ),
      ),
    );
  }

  Widget _conteudoDoCard(MesaPublica m, {bool tocavel = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: _card,
        border: Border.all(color: _borda),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Nome + ocupação. `Wrap` em vez de `Row`: a 200% de fonte o nome
          // sozinho já ocupa a linha inteira em 320 dp, e um `Row` estouraria.
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Text(
                m.nome,
                style: const TextStyle(
                  color: _goldHi,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(9),
                  color: _feltro,
                  border: Border.all(color: _feltroBorda),
                ),
                child: Text(
                  m.ocupacaoCurta,
                  style: const TextStyle(
                    color: _verdeClaro,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Modalidade · Meta · espera. `Wrap` pela mesma razão.
          Wrap(
            spacing: 10,
            runSpacing: 2,
            children: [
              _etiqueta(m.modalidade.rotulo),
              _etiqueta('Meta ${m.metaPontos}'),
              _etiqueta(textoDeEspera(m.aguardandoHa)),
            ],
          ),
          const SizedBox(height: 10),
          _assentos(m),
          const SizedBox(height: 8),
          _estado(m, tocavel: tocavel),
        ],
      ),
    );
  }

  Widget _etiqueta(String texto) =>
      Text(texto, style: const TextStyle(color: _mut, fontSize: 12.5));

  Widget _assentos(MesaPublica m) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [for (final a in m.assentos) _chipDeAssento(a)],
    );
  }

  Widget _chipDeAssento(AssentoPublico a) {
    final livre = !a.ocupado;
    final rotulo = livre
        ? 'Livre'
        : (a.ehBot ? 'Robô' : (a.apelido ?? 'Jogador'));
    return Container(
      constraints: const BoxConstraints(minWidth: 66),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: livre ? const Color(0xFF150E08) : _feltro,
        border: Border.all(color: livre ? _borda : _feltroBorda),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            livre
                ? Icons.event_seat_outlined
                : (a.ehBot ? Icons.smart_toy_outlined : Icons.person_rounded),
            size: 14,
            color: livre ? _mut : _verdeClaro,
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              rotulo,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: livre ? _mut : _texto,
                fontSize: 12,
                fontWeight: livre ? FontWeight.w500 : FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// [tocavel] acrescenta a etiqueta ENTRAR. Ela é o rótulo da ação que o
  /// card inteiro executa — o card é o botão, e não ela: um segundo alvo
  /// dentro de um alvo produziria dois nós tocáveis para o mesmo gesto, e o
  /// de dentro teria menos de 48 dp.
  Widget _estado(MesaPublica m, {bool tocavel = false}) {
    final cor = m.ingressavel ? _verdeClaro : _mut;
    return Row(
      children: [
        Icon(
          m.ingressavel
              ? Icons.check_circle_outline_rounded
              : Icons.hourglass_bottom_rounded,
          size: 15,
          color: cor,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            m.estadoIngresso.rotulo,
            style: TextStyle(
              color: cor,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (tocavel)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(9),
              color: const Color(0xFF3A2A15),
              border: Border.all(color: _gold, width: 1.2),
            ),
            child: const Text(
              'Entrar',
              style: TextStyle(
                color: _goldHi,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
      ],
    );
  }
}
