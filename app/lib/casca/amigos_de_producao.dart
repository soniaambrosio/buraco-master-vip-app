// amigos_de_producao.dart — Amigos e descoberta social REAIS.
//
// ---------------------------------------------------------------------------
// POR QUE UMA TELA NOVA, E NÃO `screens/amigos_screen.dart`
// ---------------------------------------------------------------------------
//
// A mesma decisão que o Ranking já tomou, e pelo mesmo motivo. A tela do Codex
// existe, é bonita e continua no repositório como catálogo visual — mas ela
// nasce de `AmigosVM.mock()`, e o mock tem SEIS PESSOAS ESCRITAS DENTRO
// (`'claudia'`, `'beto'`, `'fernanda'`, `'mateus'`, `'sofia'`, mais 'Você'),
// com nível, status de presença e um código de convite `SONIA-RAINHA`.
//
// Nada disso é dado: é desenho. Os identificadores são apelidos em minúsculo, e
// se um deles chegasse a `publicIdVisitado` a callable responderia
// `invalid-argument` — depois de o aplicativo já ter afirmado que aquela pessoa
// existe e é sua amiga. Duas auditorias garantem que isso não aconteça
// (`navegacao_perfil_publico_test.dart` N12/N13 e
// `composicao_navegacao_publica_test.dart` C16): a maquete não pode ser
// alcançável a partir de `main()`.
//
// Esta tela é o contrário: ela não tem um único jogador escrito dentro. Tudo o
// que desenha veio de `listarAmigos`, `listarSolicitacoes*` e
// `buscarJogadoresPorApelido`.
//
// ---------------------------------------------------------------------------
// O QUE ESTA TELA NÃO FAZ
// ---------------------------------------------------------------------------
//
// NÃO DEDUZ BOTÃO. Cada ação desenhada é um item de `ResultadoSocial.acoes`,
// que veio do servidor. A tela não pergunta "somos amigos? então mostro
// remover" — essa dedução ignora bloqueio e sanção social, que a autoridade
// conhece e o cliente não. Ver o cabeçalho de `amigos/estado_social.dart`.
//
// NÃO GUARDA GRAFO. Não há mapa de amizades aqui nem no leitor; o que existe
// são páginas que o servidor devolveu. Ver `amigos/leitor_social.dart`.
//
// NÃO DECIDE DE QUEM É O PERFIL QUE ABRE. Isso é de
// `navegacao_perfil_publico.dart`, e a razão de ser um arquivo separado está
// lá.
//
// NÃO MOSTRA PRESENÇA ("online agora", "na mesa"). A maquete tem as três abas
// Online/Todos/Pedidos, e a primeira depende de um serviço de presença que não
// existe em lugar nenhum deste projeto. Desenhar uma aba "Online" alimentada
// pela lista completa faria a tela afirmar que todo mundo está jogando. As
// abas aqui são as que têm autoridade por trás: Amigos, Recebidos, Enviados.
//
// NÃO TEM PORTÃO DE VIP. A maquete anuncia Amigos como benefício de assinatura,
// e o backend social NÃO aplica esse gate em lugar nenhum — `enviarSolicitacao`
// e as listas atendem qualquer autenticado. Um portão só no cliente seria
// decoração sobre uma porta aberta, e esta OS é sobre ligar a tela ao grafo
// canônico, não sobre criar política de produto que a autoridade não tem.

import 'package:flutter/material.dart';

import '../amigos/escopo_social.dart';
import '../amigos/estado_social.dart';
import '../amigos/leitor_social.dart';
import '../amigos/transporte_social.dart' show kAcoesDeAmizade;
import '../sessao/avatar_publico.dart';
import '../sessao/escopo_sessao.dart';
import 'navegacao_perfil_publico.dart';

/// Altura mínima de uma linha tocável. Mesmo piso do Ranking, e pelo mesmo
/// motivo: 48 é o mínimo das diretrizes, e estas linhas carregam duas alturas
/// de texto mais um botão.
const double kAlturaMinimaDaLinhaSocial = 56;

class AmigosDeProducao extends StatefulWidget {
  const AmigosDeProducao({super.key});

  static const _ouro = Color(0xFFEFB94A);
  static const _ouroClaro = Color(0xFFF6E2A6);
  static const _texto = Color(0xFFEFE3CC);
  static const _textoSec = Color(0xFFB6A884);
  static const _card = Color(0xFF1C130C);
  static const _borda = Color(0x33EFB94A);

  @override
  State<AmigosDeProducao> createState() => _AmigosDeProducaoState();
}

class _AmigosDeProducaoState extends State<AmigosDeProducao> {
  final TextEditingController _campo = TextEditingController();

  QualLista _aba = QualLista.amigos;

  /// Uma ação está em voo para este `publicId`.
  ///
  /// UM POR VEZ, e por jogador: sem isto, dois toques no mesmo "Aceitar" viram
  /// duas chamadas, e a segunda volta com `repeticao: true` — o que não é erro,
  /// mas é uma ida ao servidor para descobrir o que já se sabia.
  String? _agindoSobre;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Idempotente: `garantir` só consulta quando a lista está por carregar. Sem
    // essa guarda, abrir o teclado viraria uma chamada.
    EscopoSocial.talvezDe(context)?.garantir(_aba);
  }

  @override
  void dispose() {
    _campo.dispose();
    super.dispose();
  }

  /// O menor termo que vale a pena mandar ao servidor.
  ///
  /// VEM DO SERVIDOR, e não de uma constante local: `obterMinhaIdentidade`
  /// publica `edicao.apelidoMinimo`, e é o mesmo número que
  /// `avaliarConsultaDeBusca` usa como piso da consulta. Sem identidade
  /// carregada devolve 0 — e aí não há freio nenhum: pedir e receber
  /// `consultaMuitoCurta` é honesto, inventar o número não.
  int get _minimoDeBusca =>
      EscopoSessao.identidadeDe(context).identidade?.edicao.apelidoMinimo ?? 0;

  void _trocarAba(QualLista qual) {
    setState(() => _aba = qual);
    EscopoSocial.talvezDe(context)?.garantir(qual);
  }

  void _buscar(String termo) {
    final social = EscopoSocial.talvezDe(context);
    if (social == null) return;
    final limpo = termo.trim();
    if (limpo.isEmpty) {
      social.limparBusca();
      return;
    }
    // O freio de tamanho evita a ida ao servidor; ele NÃO decide o que é um
    // termo válido. Quem decide é `avaliarConsultaDeBusca`, e um termo que
    // passa daqui e é recusado lá vira o recado do próprio servidor.
    if (limpo.runes.length < _minimoDeBusca) return;
    social.buscar(limpo);
  }

  /// Executa a ação que o servidor ofereceu e conta o desfecho.
  Future<void> _agir(AcaoSocial acao, String publicId) async {
    final social = EscopoSocial.talvezDe(context);
    if (social == null || _agindoSobre != null) return;
    setState(() => _agindoSobre = publicId);
    try {
      final r = await social.agir(acao, publicId);
      if (!mounted) return;
      // A aba visível foi VENCIDA pela ação (ver `_vencerListas`): quem a
      // recarrega é esta tela, porque é ela que sabe qual está à vista.
      social.garantir(_aba);
      _recado(_textoDoDesfecho(acao, r));
    } on FalhaSocial catch (e) {
      if (!mounted) return;
      _recado(_textoDaFalha(e));
    } finally {
      if (mounted) setState(() => _agindoSobre = null);
    }
  }

  /// O que dizer quando a ação deu certo.
  ///
  /// `repeticao` ganha frase PRÓPRIA em vez de silêncio: a pessoa tocou e algo
  /// tem de responder, e "vocês já são amigos" é verdade e é informação — muito
  /// melhor que repetir "pedido enviado" para um pedido que não foi enviado
  /// agora.
  static String _textoDoDesfecho(AcaoSocial acao, RespostaDeAcao r) {
    if (r.repeticao) return 'Isso já estava resolvido por aqui 👍';
    return switch (acao) {
      AcaoSocial.adicionarAmigo => 'Pedido enviado!',
      AcaoSocial.aceitarSolicitacao => 'Vocês agora são amigos 🎉',
      AcaoSocial.recusarSolicitacao => 'Pedido recusado.',
      AcaoSocial.cancelarSolicitacao => 'Pedido cancelado.',
      AcaoSocial.removerAmigo => 'Amizade desfeita.',
      _ => 'Pronto.',
    };
  }

  /// O que dizer quando o servidor recusou.
  ///
  /// NÃO EXPÕE O MOTIVO CRU. `alvoMeBloqueou` não existe no vocabulário do
  /// contrato justamente para que a tela não possa escrever "Fulano bloqueou
  /// você"; e mesmo os motivos que existem (`limiteDeAmigos`) só valem uma
  /// frase quando ela ajuda a pessoa a fazer algo diferente.
  static String _textoDaFalha(FalhaSocial e) => switch (e.motivo) {
    MotivoFalhaSocial.naoEncontrado => 'Não encontrei esse jogador.',
    MotivoFalhaSocial.naoAutenticado =>
      'Sua sessão expirou. Entre de novo para continuar.',
    MotivoFalhaSocial.regraDeNegocio => switch (e.recusa) {
      'limiteDeAmigos' => 'Você atingiu o limite de amigos.',
      'limiteDeSolicitacoesEnviadas' =>
        'Você tem pedidos demais esperando resposta.',
      // Uma recusa que esta versão do aplicativo não conhece. Frase neutra, e
      // NUNCA o código cru na cara do jogador.
      _ => 'Não deu para fazer isso agora.',
    },
    MotivoFalhaSocial.pedidoInvalido => 'Não deu para fazer isso agora.',
    _ => 'Falha de conexão. Tenta de novo?',
  };

  void _recado(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(msg),
          duration: const Duration(milliseconds: 1800),
          backgroundColor: const Color(0xFF2A1B0E),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final social = EscopoSocial.talvezDe(context);
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _topo(context),
              _busca(),
              // Fora do escopo não há a quem perguntar. A tela diz isso e não
              // desenha aba nenhuma: abas vazias pareceriam "você não tem
              // amigos", que é uma afirmação que ninguém pode fazer daqui.
              if (social == null)
                const Expanded(
                  child: _AvisoSocial(
                    mensagem: 'Amigos indisponível fora do aplicativo.',
                  ),
                )
              else ...[
                if (!_emModoBusca(social)) _abas(social),
                Expanded(child: _conteudo(social)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _topo(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
    child: Row(
      children: [
        Semantics(
          button: true,
          label: 'Voltar',
          child: InkResponse(
            onTap: () => Navigator.of(context).maybePop(),
            radius: 24,
            child: const SizedBox(
              width: 44,
              height: 44,
              child: Center(
                child: Icon(
                  Icons.chevron_left_rounded,
                  color: AmigosDeProducao._ouro,
                  size: 29,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 2),
        const Text(
          'Amigos',
          style: TextStyle(
            color: AmigosDeProducao._ouroClaro,
            fontSize: 17,
            fontWeight: FontWeight.w800,
            letterSpacing: .4,
          ),
        ),
      ],
    ),
  );

  Widget _busca() => Padding(
    padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
    child: TextField(
      controller: _campo,
      textInputAction: TextInputAction.search,
      // BUSCA NO ENVIO, e não a cada tecla. Sem cursor e com teto de
      // resultados, uma consulta por letra seria uma ida ao servidor por
      // caractere para jogar fora as N-1 primeiras respostas.
      onSubmitted: _buscar,
      style: const TextStyle(color: AmigosDeProducao._texto),
      decoration: InputDecoration(
        hintText: 'Procurar por apelido',
        hintStyle: const TextStyle(color: AmigosDeProducao._textoSec),
        prefixIcon: const Icon(
          Icons.search_rounded,
          color: AmigosDeProducao._textoSec,
        ),
        suffixIcon: _campo.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Limpar busca',
                icon: const Icon(
                  Icons.close_rounded,
                  color: AmigosDeProducao._textoSec,
                ),
                onPressed: () {
                  _campo.clear();
                  EscopoSocial.talvezDe(context)?.limparBusca();
                  setState(() {});
                },
              ),
        filled: true,
        fillColor: AmigosDeProducao._card,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AmigosDeProducao._borda),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AmigosDeProducao._ouro),
        ),
      ),
      onChanged: (_) => setState(() {}),
    ),
  );

  Widget _abas(LeitorSocial social) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
    child: Row(
      children: [
        _Aba(
          rotulo: 'Amigos',
          ativa: _aba == QualLista.amigos,
          onTap: () => _trocarAba(QualLista.amigos),
        ),
        const SizedBox(width: 8),
        _Aba(
          rotulo: 'Recebidos',
          ativa: _aba == QualLista.recebidas,
          onTap: () => _trocarAba(QualLista.recebidas),
        ),
        const SizedBox(width: 8),
        _Aba(
          rotulo: 'Enviados',
          ativa: _aba == QualLista.enviadas,
          onTap: () => _trocarAba(QualLista.enviadas),
        ),
      ],
    ),
  );

  Widget _conteudo(LeitorSocial social) {
    if (_emModoBusca(social)) return _resultados(social, social.busca);
    return _listaDaAba(social);
  }

  /// A tela está mostrando BUSCA, e não as abas?
  ///
  /// Olha o estado do leitor, e NÃO o texto da caixa. São coisas diferentes: a
  /// pessoa pode ter digitado sem enviar (e aí as abas continuam), e pode ter
  /// apagado o texto depois de uma busca enviada (e aí os resultados ficam até
  /// ela limpar). Amarrar a decisão ao `TextEditingController` faria a lista
  /// trocar sozinha embaixo do dedo enquanto ela digita.
  static bool _emModoBusca(LeitorSocial social) {
    final b = social.busca;
    return b.emVoo || b.resultados != null || b.fase == FaseSocial.falha;
  }

  // -------------------------------------------------------------------------
  // Busca
  // -------------------------------------------------------------------------

  Widget _resultados(LeitorSocial social, BuscaSocial busca) {
    if (busca.fase == FaseSocial.falha) {
      final falha = busca.falha;
      return _AvisoSocial(
        mensagem: falha == null
            ? 'Não consegui buscar agora.'
            : _textoDaBuscaRecusada(falha),
        // Só oferece insistir quando insistir pode dar outro resultado. Repetir
        // um termo curto demais devolveria a mesma recusa para sempre.
        onTentarDeNovo: falha != null && falha.transitoria
            ? () => social.buscar(busca.termo)
            : null,
      );
    }

    final r = busca.resultados;
    if (r == null) {
      return const _AvisoSocial(
        mensagem: 'Procurando…',
        mostrarProgresso: true,
      );
    }
    if (busca.semResultados) {
      // ESTA FRASE SÓ PODE SER DITA COM A FASE PRONTA. E ela é a mesma para
      // "não existe ninguém com esse apelido" e para "todos os candidatos me
      // bloquearam" — o contrato exige que os dois sejam indistinguíveis.
      return _AvisoSocial(mensagem: 'Ninguém encontrado para "${r.termo}".');
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 18),
      children: [
        if (busca.emVoo) const _FaixaDeProgresso(),
        for (final item in r.itens)
          _LinhaSocial(
            jogador: item.jogador,
            relacao: item.relacao,
            acoes: item.acoes,
            ocupado: _agindoSobre == item.publicId,
            onAgir: (a) => _agir(a, item.publicId),
            onAbrir: () =>
                abrirPerfilDoJogador(context, AlvoDePerfil.daBusca(item)),
          ),
        if (r.truncado)
          const Padding(
            padding: EdgeInsets.only(top: 10),
            child: Text(
              'Há mais jogadores com esse apelido. Digite o apelido completo '
              'para encontrar quem você procura.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AmigosDeProducao._textoSec,
                fontSize: 12.5,
                height: 1.35,
              ),
            ),
          ),
      ],
    );
  }

  /// A recusa da busca, dita para quem digitou.
  static String _textoDaBuscaRecusada(FalhaSocial e) => switch (e.recusa) {
    'consultaMuitoCurta' => 'Escreva um pouco mais para procurar.',
    'consultaMuitoLonga' => 'Esse texto é longo demais para um apelido.',
    'consultaInvalida' => 'Não consegui entender esse texto.',
    _ =>
      e.transitoria
          ? 'Falha de conexão. Tenta de novo?'
          : 'Não consegui buscar agora.',
  };

  // -------------------------------------------------------------------------
  // Listas
  // -------------------------------------------------------------------------

  Widget _listaDaAba(LeitorSocial social) {
    final lista = social.lista(_aba);
    switch (lista.fase) {
      case FaseSocial.naoCarregada:
      case FaseSocial.carregando:
        // A página anterior CONTINUA na tela durante uma releitura: trocar por
        // um esqueleto faria a lista sumir e voltar a cada ação.
        if (lista.itens.isEmpty) {
          return const _AvisoSocial(
            mensagem: 'Carregando…',
            mostrarProgresso: true,
          );
        }
      case FaseSocial.falha:
        return _AvisoSocial(
          mensagem: 'Não consegui carregar agora.',
          onTentarDeNovo: lista.podeTentarDeNovo
              ? () => social.recarregar(_aba)
              : null,
        );
      case FaseSocial.pronta:
        if (lista.itens.isEmpty) {
          // Afirmação só com resposta na mão — as outras fases desenhariam a
          // mesma lista vazia, e nelas a frase seria um palpite.
          return _AvisoSocial(mensagem: _vazioDaAba(_aba));
        }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 18),
      children: [
        if (lista.fase == FaseSocial.carregando) const _FaixaDeProgresso(),
        for (final entrada in lista.itens)
          _LinhaSocial(
            jogador: entrada,
            relacao: _relacaoDaAba(_aba),
            acoes: _acoesDaAba(_aba),
            ocupado: _agindoSobre == entrada.publicId,
            onAgir: (a) => _agir(a, entrada.publicId),
            onAbrir: () => abrirPerfilDoJogador(
              context,
              AlvoDePerfil.daListaSocial(entrada),
            ),
          ),
        if (lista.temMais)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: OutlinedButton(
                onPressed: lista.carregandoMais
                    ? null
                    : () => social.carregarMais(_aba),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AmigosDeProducao._ouroClaro,
                  side: const BorderSide(color: AmigosDeProducao._borda),
                ),
                child: Text(
                  lista.carregandoMais ? 'Carregando…' : 'Carregar mais',
                ),
              ),
            ),
          ),
      ],
    );
  }

  static String _vazioDaAba(QualLista qual) => switch (qual) {
    QualLista.amigos =>
      'Você ainda não tem amigos por aqui. Procure alguém pelo apelido.',
    QualLista.recebidas => 'Nenhum pedido esperando resposta.',
    QualLista.enviadas => 'Você não tem pedidos aguardando.',
  };

  /// A relação que uma linha de LISTA representa.
  ///
  /// -----------------------------------------------------------------------
  /// ISTO NÃO É DEDUZIR RELAÇÃO — É LER O NOME DA LISTA
  /// -----------------------------------------------------------------------
  ///
  /// A distinção importa e vale a pena escrevê-la. Deduzir seria olhar dados de
  /// um jogador e concluir algo sobre a relação com ele. Aqui não há dedução:
  /// `listarAmigos` devolve, por definição do contrato, os amigos; a lista de
  /// recebidas devolve, por definição, solicitações recebidas. A relação É o
  /// endereço de onde a linha veio.
  ///
  /// O que continua NÃO sendo deduzido é a AÇÃO — ver [_acoesDaAba].
  static RelacaoSocial _relacaoDaAba(QualLista qual) => switch (qual) {
    QualLista.amigos => RelacaoSocial.amigos,
    QualLista.recebidas => RelacaoSocial.solicitacaoRecebida,
    QualLista.enviadas => RelacaoSocial.solicitacaoEnviada,
  };

  /// As ações que uma linha de LISTA oferece.
  ///
  /// -----------------------------------------------------------------------
  /// A ÚNICA EXCEÇÃO À REGRA "A TELA NÃO INVENTA PERMISSÃO", E POR QUÊ
  /// -----------------------------------------------------------------------
  ///
  /// As três listas (`listarAmigos`, `listarSolicitacoes*`) devolvem
  /// `EntradaPublica` — apelido, avatar, `desde` — e NÃO devolvem `acoes`. O
  /// contrato foi escrito assim porque a lista já é o estado: quem está em
  /// "recebidas" tem um pedido pendente para responder, e ponto.
  ///
  /// Então aqui há duas saídas honestas, e nenhuma terceira:
  ///
  ///   (a) desenhar as ações que a lista implica — as MESMAS que
  ///       `acoesDisponiveis` deriva daquela relação no servidor;
  ///   (b) chamar `verPerfilPublico` uma vez por linha, para que o servidor
  ///       diga as ações de cada uma.
  ///
  /// (b) seria 25 chamadas para desenhar uma página de 25 amigos, e o ganho
  /// seria cobrir a janela em que alguém bloqueou você entre a listagem e o
  /// toque. Essa janela NÃO É EXPLORÁVEL: toda operação social lê o bloqueio
  /// dentro da própria transação, então o botão desenhado a mais é recusado
  /// pela autoridade e a tela conta o motivo. Um botão que às vezes é recusado
  /// é bem diferente de um botão que autoriza — a autorização continua inteira
  /// do lado de lá.
  ///
  /// Nos RESULTADOS DE BUSCA, onde o servidor manda `acoes`, a lista do
  /// servidor é usada e esta função não é chamada.
  static List<AcaoSocial> _acoesDaAba(QualLista qual) => switch (qual) {
    QualLista.amigos => const [AcaoSocial.removerAmigo],
    QualLista.recebidas => const [
      AcaoSocial.aceitarSolicitacao,
      AcaoSocial.recusarSolicitacao,
    ],
    QualLista.enviadas => const [AcaoSocial.cancelarSolicitacao],
  };
}

/// Uma aba. Botão, e não `TabBar`, porque a troca de aba dispara consulta.
class _Aba extends StatelessWidget {
  const _Aba({required this.rotulo, required this.ativa, required this.onTap});

  final String rotulo;
  final bool ativa;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Semantics(
      button: true,
      selected: ativa,
      child: Material(
        color: ativa
            ? AmigosDeProducao._ouro.withValues(alpha: .16)
            : AmigosDeProducao._card,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: ativa
                    ? AmigosDeProducao._ouro.withValues(alpha: .55)
                    : AmigosDeProducao._borda,
              ),
            ),
            child: Text(
              rotulo,
              style: TextStyle(
                color: ativa
                    ? AmigosDeProducao._ouroClaro
                    : AmigosDeProducao._textoSec,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Uma linha de jogador — e o gesto que leva ao Perfil público dele.
class _LinhaSocial extends StatelessWidget {
  const _LinhaSocial({
    required this.jogador,
    required this.relacao,
    required this.acoes,
    required this.ocupado,
    required this.onAgir,
    required this.onAbrir,
  });

  final JogadorPublico jogador;
  final RelacaoSocial relacao;
  final List<AcaoSocial> acoes;
  final bool ocupado;
  final ValueChanged<AcaoSocial> onAgir;
  final VoidCallback onAbrir;

  /// O rótulo do estado. DESCREVE, e não autoriza — quem autoriza é [acoes].
  ///
  /// `nenhuma` e `desconhecida` não ganham rótulo: a primeira porque "vocês não
  /// são nada" não é informação, a segunda porque este aplicativo não sabe o
  /// que o servidor quis dizer e um palpite ali seria pior que o silêncio.
  String? get _rotulo => switch (relacao) {
    RelacaoSocial.amigos => 'Amigos',
    RelacaoSocial.solicitacaoEnviada => 'Pedido enviado',
    RelacaoSocial.solicitacaoRecebida => 'Quer ser seu amigo',
    RelacaoSocial.bloqueadoPorMim => 'Bloqueado por você',
    // Um estado só para dois fatos (o outro me bloqueou; há sanção social), e a
    // frase não distingue os dois de propósito.
    RelacaoSocial.indisponivel => 'Indisponível',
    RelacaoSocial.euMesmo => 'Você',
    RelacaoSocial.nenhuma || RelacaoSocial.desconhecida => null,
  };

  String get _anuncio {
    final partes = <String>[
      jogador.nomeDeApresentacao,
      ?_rotulo,
    ];
    return '${partes.join('. ')}. Toque para ver o perfil.';
  }

  @override
  Widget build(BuildContext context) {
    final avatar = avatarPublicoDe(jogador.avatarRef);
    // Só as ações que ESTA tela sabe executar. `bloquear` e `desbloquear` são
    // do domínio de moderação e não têm porta aqui; desenhá-las como botão que
    // não faz nada seria pior que não desenhá-las.
    final desenhaveis = acoes.where(kAcoesDeAmizade.contains).toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: AmigosDeProducao._card,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: jogador.temIdUtilizavel ? onAbrir : null,
          child: Container(
            constraints: const BoxConstraints(
              minHeight: kAlturaMinimaDaLinhaSocial,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AmigosDeProducao._borda),
            ),
            child: Row(
              children: [
                Semantics(
                  excludeSemantics: true,
                  child: SizedBox(
                    width: 34,
                    child: Text(avatar, style: const TextStyle(fontSize: 22)),
                  ),
                ),
                Expanded(
                  child: Semantics(
                    button: true,
                    excludeSemantics: true,
                    label: _anuncio,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          jogador.nomeDeApresentacao,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AmigosDeProducao._texto,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (_rotulo != null)
                          Text(
                            _rotulo!,
                            style: const TextStyle(
                              color: AmigosDeProducao._textoSec,
                              fontSize: 11.5,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                if (ocupado)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: AmigosDeProducao._ouro,
                    ),
                  )
                else
                  for (final acao in desenhaveis)
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: _BotaoDeAcao(
                        acao: acao,
                        onTap: () => onAgir(acao),
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

/// O botão de uma ação social.
class _BotaoDeAcao extends StatelessWidget {
  const _BotaoDeAcao({required this.acao, required this.onTap});

  final AcaoSocial acao;
  final VoidCallback onTap;

  /// O rótulo é do VERBO, e não do estado. "Aceitar", não "Pedido recebido".
  static String rotuloDe(AcaoSocial acao) => switch (acao) {
    AcaoSocial.adicionarAmigo => 'Adicionar',
    AcaoSocial.aceitarSolicitacao => 'Aceitar',
    AcaoSocial.recusarSolicitacao => 'Recusar',
    AcaoSocial.cancelarSolicitacao => 'Cancelar',
    AcaoSocial.removerAmigo => 'Remover',
    AcaoSocial.bloquear => 'Bloquear',
    AcaoSocial.desbloquear => 'Desbloquear',
    AcaoSocial.editarPerfil => 'Editar',
  };

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: ConstrainedBox(
      // O piso das diretrizes vale para o botão também, e não só para a linha.
      constraints: const BoxConstraints(minHeight: 40, minWidth: 44),
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: AmigosDeProducao._ouroClaro,
          side: const BorderSide(color: AmigosDeProducao._borda),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          visualDensity: VisualDensity.compact,
        ),
        child: Text(rotuloDe(acao), style: const TextStyle(fontSize: 12.5)),
      ),
    ),
  );
}

/// Uma barra fina de progresso no topo da lista, para releitura em curso.
class _FaixaDeProgresso extends StatelessWidget {
  const _FaixaDeProgresso();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.only(bottom: 8),
    child: LinearProgressIndicator(
      minHeight: 2,
      color: AmigosDeProducao._ouro,
      backgroundColor: Colors.transparent,
    ),
  );
}

/// Um recado no meio da tela, com botão só quando insistir resolve.
class _AvisoSocial extends StatelessWidget {
  const _AvisoSocial({
    required this.mensagem,
    this.onTentarDeNovo,
    this.mostrarProgresso = false,
  });

  final String mensagem;
  final VoidCallback? onTentarDeNovo;
  final bool mostrarProgresso;

  @override
  Widget build(BuildContext context) {
    final acao = onTentarDeNovo;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (mostrarProgresso) ...[
              const SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: AmigosDeProducao._ouro,
                ),
              ),
              const SizedBox(height: 14),
            ],
            Text(
              mensagem,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AmigosDeProducao._textoSec,
                fontSize: 14,
                height: 1.35,
              ),
            ),
            if (acao != null) ...[
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48, minWidth: 160),
                child: OutlinedButton(
                  onPressed: acao,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AmigosDeProducao._ouroClaro,
                    side: const BorderSide(color: AmigosDeProducao._borda),
                  ),
                  child: const Text('Tentar de novo'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
