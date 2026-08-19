import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../ranking/escopo_ranking.dart';
import '../ranking/estado_ranking.dart';
import '../screens/perfil_screen.dart';
import '../services/perfil_service.dart';
import '../sessao/escopo_sessao.dart';
import '../sessao/identidade_publica_sessao.dart';
import 'ranking_page.dart';

/// Controlador da tela de Perfil (camada de lógica — Claude).
///
/// Responsabilidade: carregar o [PerfilVM] pelo [PerfilService], administrar os
/// estados (carregando/normal/erro) e ligar os 14 callbacks da UI a ações reais.
/// NÃO altera o visual — a interface é 100% do [PerfilScreen] (Codex).
///
/// FASE 1: identidade real (sessão canônica) + arquitetura pronta; os números
/// chegam AUSENTES enquanto não há autoridade que os informe (ver
/// [PerfilService.statsDemo]). As ações que dependem de telas futuras (config,
/// editar, loja, ranking) mostram um aviso "chega já já".
class PerfilPage extends StatefulWidget {
  const PerfilPage({super.key, this.ehMeuPerfil = true, this.publicIdVisitado});

  /// true = perfil do próprio dono (mostra editar/câmera/trocar vitrine).
  /// false = visitando outro jogador (a UI oculta os controles de dono).
  final bool ehMeuPerfil;

  /// O `publicId` de quem está sendo visitado, quando não é o próprio perfil.
  ///
  /// SÓ ELE decide de quem é o ranking consultado. Não há inferência por nome,
  /// por índice de lista nem por nada que a tela tenha à mão: o id público é a
  /// única identidade que este app usa para falar de terceiro, e recebê-lo
  /// explicitamente é o que impede o Perfil de "adivinhar" quem visitar.
  ///
  /// Nulo com [ehMeuPerfil] falso é um perfil visitado de quem não se sabe o
  /// id — a tela mostra o resto e não afirma ranking, porque não há a quem
  /// perguntar.
  final String? publicIdVisitado;

  /// O texto do convite, montado a partir do que o VM REALMENTE tem.
  ///
  /// ERA uma interpolação única com dois fallbacks embutidos —
  /// `Nível ${vm?.nivel ?? 1} · Liga ${vm?.liga ?? 'Bronze'}` — e o segundo era
  /// o pior dos três lugares onde a liga inventada aparecia: os outros dois
  /// ficavam na tela do dono, este SAÍA DO APARELHO. A pessoa colava no grupo
  /// da família um texto afirmando uma liga que ninguém lhe atribuiu.
  ///
  /// Agora cada trecho competitivo só entra se houver o que afirmar, e quando
  /// não há, o convite continua sendo um convite — perde a linha, não a função.
  /// Público, e por isso o mais rigoroso de todos: aqui nem o travessão entra,
  /// porque num texto solto ele não se lê como ausência, se lê como ruído. E o
  /// nível segue a mesma regra da liga: sem sistema de progressão ligado, não há
  /// `Nível` nenhum para mandar para a conversa de outra pessoa.
  ///
  /// ESTÁTICO E PÚBLICO de propósito: o texto é a superfície que sai do
  /// aparelho, e um teste precisa poder conferi-lo sem encenar um toque e sem
  /// mexer na área de transferência.
  static String textoDeCompartilhamento(PerfilVM? vm) {
    const convite = 'Vem jogar Buraco comigo no Buraco Master VIP!';
    // Sem VM não há nada carregado: não existe nem nome para afirmar.
    if (vm == null) return '$convite 👑';

    final partes = <String>[];
    final nivel = vm.nivel;
    if (nivel != null) partes.add('Nível $nivel');
    final liga = vm.ranking.liga;
    if (liga != null) partes.add('Liga $liga');
    final posicao = vm.ranking.posicaoMundial;
    if (posicao != null) partes.add('#$posicao no mundo');

    // Sem nenhum trecho competitivo, o convite fecha no nome: nada de um ponto
    // solto depois da coroa, e nada de uma lista vazia virando espaço em branco.
    if (partes.isEmpty) return '$convite Sou ${vm.nome} 👑';
    return '$convite Sou ${vm.nome} 👑 ${partes.join(' · ')}.';
  }

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

  /// O ranking de um perfil VISITADO.
  ///
  /// Só existe para o outro: o do próprio jogador é lido no `build`, do estado
  /// que a casca já mantém, para que Perfil e Home nunca discordem e para que a
  /// tela acompanhe a consulta em vez de congelar o valor do instante da carga.
  ///
  /// Devolve `null` quando a resposta perdeu a validade no caminho — a sessão
  /// mudou, ou já houve pedido mais novo. Quem chama não publica nada.
  Future<EstadoRanking?> _rankingVisitado(String? contaPublicId) async {
    final alvo = widget.publicIdVisitado;
    final leitor = EscopoRanking.talvezDe(context)?.leitor;
    // Sem alvo, sem conta ou sem escopo não há a quem perguntar. A tela mostra
    // o resto e não afirma ranking — que é diferente de afirmar ausência dele.
    if (alvo == null || contaPublicId == null || leitor == null) {
      return rankingDaCascaPublicavel;
    }
    return leitor.rankingPublico(
      contaPublicId: contaPublicId,
      alvoPublicId: alvo,
    );
  }

  Future<void> _carregar() async {
    // Lido do escopo a cada carga: o Perfil consome o MESMO estado canônico que
    // Ranking e Social — não existe `identidadeDoPerfil`.
    final estadoSessao = EscopoSessao.identidadeDe(context);
    final IdentidadePublica? identidade = estadoSessao.identidade;
    final String? contaPublicId = estadoSessao.publicId;
    setState(() {
      _estado = PerfilEstado.carregando;
      _erro = null;
    });
    try {
      // `null` é descarte: a resposta é de uma sessão que acabou, ou já foi
      // superada por outra. Vira "não sei" — o Perfil monta o resto da tela sem
      // afirmar ranking, em vez de exibir a fotografia de quem saiu.
      final ranking = widget.ehMeuPerfil
          ? null
          : (await _rankingVisitado(contaPublicId) ?? rankingDaCascaPublicavel);
      final vm = await _service.carregar(
        ehMeuPerfil: widget.ehMeuPerfil,
        identidade: identidade,
        ranking: ranking,
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

  Future<void> _compartilhar() async {
    final texto = PerfilPage.textoDeCompartilhamento(_vm);
    await Clipboard.setData(ClipboardData(text: texto));
    if (!mounted) return;
    _toast('Convite copiado! É só colar e mandar pra galera 🎉');
  }

  @override
  Widget build(BuildContext context) {
    // Na carga usa o placeholder do serviço (a própria tela mostra skeleton).
    final base = _vm ?? _service.vmPlaceholder();

    // O RANKING PRÓPRIO É LIDO AQUI, e não guardado no VM da carga.
    //
    // Ler no `build` faz duas coisas de uma vez. Primeiro, amarra esta tela ao
    // MESMO objeto que a Home lê — não há como as duas divergirem, porque não
    // há duas leituras. Segundo, a consulta em voo aparece: o Perfil entra em
    // "carregando" e passa para o resultado sozinho, sem recarregar a tela
    // inteira. Congelar o valor no instante da carga deixaria o Perfil eterno
    // em "carregando" para quem o abrisse rápido demais.
    final vm = widget.ehMeuPerfil
        ? base.comRanking(EscopoRanking.meuEstadoDe(context))
        : base;

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
      // O retry recarrega as DUAS coisas que podem ter falhado, e não só o
      // perfil: quem apertou o botão viu uma tela sem ranking, e recarregar só
      // a metade que já estava boa seria o botão não fazer o que promete. As
      // duas são idempotentes por baixo.
      onRecarregar: () {
        EscopoRanking.talvezDe(context)?.recarregar();
        _carregar();
      },
      onNavTap: (destino) {
        switch (destino) {
          case NavDestino.inicio:
            Navigator.of(context).maybePop();
            break;
          case NavDestino.ranking:
            Navigator.of(context).pushReplacement(
              MaterialPageRoute<void>(builder: (_) => const RankingPage()),
            );
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
