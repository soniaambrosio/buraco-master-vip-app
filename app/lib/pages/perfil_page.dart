import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../amigos/escopo_social.dart';
import '../amigos/estado_social.dart';
import '../amigos/leitor_social.dart';
import '../amigos/rotulos_sociais.dart';
import '../amigos/transporte_social.dart' show kAcoesDeAmizade;
import '../casca/ranking_de_producao.dart';
import '../ranking/escopo_ranking.dart';
import '../ranking/estado_ranking.dart';
import '../ranking/leitor_ranking.dart' show LeituraDeAbertura;
import '../ranking/ranking_transporte.dart' show JogadorPublicoRanking;
import '../screens/perfil_screen.dart';
import 'ranking_page.dart';
import '../services/perfil_service.dart';
import '../sessao/avatar_publico.dart';
import '../sessao/escopo_sessao.dart';
import '../sessao/identidade_publica_sessao.dart';

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
  /// [ehMeuPerfil] é DERIVADO de [publicIdVisitado] quando não vem escrito.
  ///
  /// -------------------------------------------------------------------------
  /// O PADRÃO ERA `true`, E ERA UMA ARMADILHA
  /// -------------------------------------------------------------------------
  ///
  /// Com `ehMeuPerfil = true` fixo, `PerfilPage(publicIdVisitado: 'PXXX…')`
  /// compilava, abria e mostrava o perfil do DONO — com os controles de editar,
  /// trocar avatar e trocar vitrine — enquanto carregava um id de terceiro que
  /// ninguém consultava. Os dois campos precisavam concordar, e nada obrigava.
  ///
  /// Agora quem passa o id de um visitado já disse tudo o que precisava dizer.
  /// Passar os dois continua possível, e o escrito vence — é o que mantém de pé
  /// o caso legítimo de um perfil visitado de quem não se sabe o id
  /// (`ehMeuPerfil: false` sem `publicIdVisitado`), que a tela desenha sem
  /// afirmar ranking nenhum.
  ///
  /// `const PerfilPage()` continua constante: `??` e a comparação com `null`
  /// são expressões potencialmente constantes, então a Home não perde o
  /// construtor `const` que já usava.
  const PerfilPage({super.key, bool? ehMeuPerfil, this.publicIdVisitado})
    : ehMeuPerfil = ehMeuPerfil ?? (publicIdVisitado == null);

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

  /// A relação com o jogador VISITADO, como a autoridade social a descreve.
  ///
  /// -------------------------------------------------------------------------
  /// ISTO NÃO É UM GRAFO NO CLIENTE
  /// -------------------------------------------------------------------------
  ///
  /// É UMA relação, do jogador que está nesta rota, respondida por
  /// `social:verPerfilPublico`, e ela morre junto com a rota. Não há mapa, não
  /// há acumulação entre visitas e não há nada aqui que responda "somos amigos?"
  /// sobre alguém que não seja o desta tela.
  ///
  /// E ela é lida da autoridade SOCIAL, não da projeção do ranking — que é o
  /// que continua desenhando nome, avatar e números. Duas autoridades para duas
  /// perguntas diferentes: quem é essa pessoa (ranking, já canonizado) e o que
  /// eu sou dela (social). Misturá-las seria pedir ao ranking uma resposta que
  /// ele não tem.
  ResultadoSocial? _relacao;

  /// Uma ação social está em voo. Enquanto estiver, os botões somem — dois
  /// toques em "Adicionar" seriam duas chamadas, e a segunda voltaria com
  /// `repeticao`.
  bool _agindo = false;

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

  /// A leitura de um perfil VISITADO: identidade pública E estado competitivo.
  ///
  /// Só existe para o outro: o do próprio jogador é lido no `build`, do estado
  /// que a casca já mantém, para que Perfil e Home nunca discordem e para que a
  /// tela acompanhe a consulta em vez de congelar o valor do instante da carga.
  ///
  /// UMA LEITURA, e não duas. Nome, avatar e liga do visitado saem da mesma
  /// resposta e do mesmo `publicId`; pedi-los separadamente abriria a janela em
  /// que a tela mostra o nome de um e a liga de outro.
  ///
  /// Devolve `null` quando a resposta perdeu a validade no caminho — a sessão
  /// mudou, ou já houve pedido mais novo. Quem chama não publica nada.
  Future<LeituraDeAbertura?> _lerVisitado(String? contaPublicId) async {
    final alvo = widget.publicIdVisitado;
    final leitor = EscopoRanking.talvezDe(context)?.leitor;
    // Sem alvo, sem conta ou sem escopo não há a quem perguntar. A tela mostra
    // o resto e não afirma ranking — que é diferente de afirmar ausência dele.
    if (alvo == null || contaPublicId == null || leitor == null) return null;
    return leitor.perfilPublico(
      contaPublicId: contaPublicId,
      alvoPublicId: alvo,
    );
  }

  /// A projeção pública de um terceiro, traduzida para a tela.
  ///
  /// -------------------------------------------------------------------------
  /// O ÚNICO PONTO EM QUE A FRONTEIRA É ATRAVESSADA
  /// -------------------------------------------------------------------------
  ///
  /// Os três campos nascem AQUI, do MESMO objeto, e é isso que os torna
  /// incapazes de divergir. Espalhar esta tradução — o nome lido num lugar, o
  /// avatar noutro — é literalmente como o defeito existia: cada campo achava a
  /// sua própria fonte, e uma delas era a sessão de quem estava olhando.
  ///
  /// O nome segue a MESMA regra de apresentação do perfil próprio — apelido,
  /// senão o id público, senão o rótulo genérico — porque a pergunta é a mesma
  /// ("como esta pessoa se chama para os outros?"). O que muda é de quem se
  /// está falando, e é só isso que tinha de mudar.
  static RetratoVisitado _retratoDe(JogadorPublicoRanking j) {
    final apelido = j.apelido.trim();
    final id = j.publicPlayerId.trim();
    return RetratoVisitado(
      nome: apelido.isNotEmpty
          ? apelido
          : (id.isNotEmpty ? id : PerfilService.rotuloSemApelido),
      avatar: avatarPublicoDe(j.avatar),
      // `canastras` nulo porque a lista branca de `projetarJogador` não a
      // publica. Zero seria uma afirmação sobre o jogo de outra pessoa.
      stats: PerfilStats(
        vitorias: j.vitorias,
        partidas: j.partidas,
        canastras: null,
        aproveitamento: j.aproveitamento.round(),
      ),
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
      final leitura = widget.ehMeuPerfil
          ? null
          : await _lerVisitado(contaPublicId);
      final ranking = widget.ehMeuPerfil
          ? null
          : (leitura?.eu ?? rankingDaCascaPublicavel);
      final vm = await _service.carregar(
        ehMeuPerfil: widget.ehMeuPerfil,
        // A IDENTIDADE DA SESSÃO NÃO ATRAVESSA PARA UM PERFIL VISITADO.
        //
        // Passá-la e confiar que o serviço "vai preferir o visitado" seria
        // deixar de pé o caminho pelo qual o defeito existia: bastava a projeção
        // pública faltar — leitura vencida, falha de rede, jogador sem
        // classificação — para o serviço cair de volta na sessão e desenhar
        // quem estava olhando. Com `null` aqui, não há para onde cair.
        identidade: widget.ehMeuPerfil ? identidade : null,
        ranking: ranking,
        // Nulo quando a leitura falhou ou venceu. O serviço então monta um
        // perfil SEM nome e SEM avatar de ninguém — que é o certo: não se sabe
        // quem é, e inventar seria mostrar a pessoa errada.
        visitado: switch (leitura?.visitado) {
          final JogadorPublicoRanking j => _retratoDe(j),
          null => null,
        },
      );
      if (!mounted) return;
      setState(() {
        _vm = vm;
        _estado = PerfilEstado.normal;
      });
      // A RELAÇÃO VEM DEPOIS, e numa consulta própria — nunca embutida na
      // carga. Duas razões: ela é de outra autoridade (o codebase social, e não
      // o de ranking), e uma falha dela NÃO pode derrubar o perfil. Quem visita
      // alguém quer ver o perfil mesmo quando o social está fora do ar; o que
      // se perde nesse caso é o botão de adicionar, não a tela.
      await _lerRelacao();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _estado = PerfilEstado.erro;
        _erro = 'Não consegui carregar seu perfil agora. Tenta de novo?';
      });
    }
  }

  /// Lê a relação com o visitado, e engole a falha.
  ///
  /// ENGOLIR AQUI É A DECISÃO CERTA, e é o oposto do que `_agir` faz. Aqui a
  /// ausência de resposta tem uma representação honesta na tela: sem relação, a
  /// faixa social não aparece, e não aparecer é exatamente "não sei o que vocês
  /// são um do outro". Em `_agir` não há representação honesta do silêncio — a
  /// pessoa tocou num botão e precisa saber se funcionou —, e por isso lá a
  /// falha vira recado.
  Future<void> _lerRelacao() async {
    final alvo = widget.publicIdVisitado;
    if (widget.ehMeuPerfil || alvo == null) return;
    final social = EscopoSocial.talvezDe(context);
    if (social == null) return;
    try {
      final vista = await social.vistaDe(alvo);
      if (!mounted) return;
      setState(() => _relacao = vista);
    } on FalhaSocial {
      if (!mounted) return;
      // Volta a "não sei" em vez de manter a relação anterior: depois de um
      // retry que falhou, a faixa antiga seria uma afirmação sem respaldo.
      setState(() => _relacao = null);
    }
  }

  /// Executa uma ação social sobre o visitado e reflete a resposta na tela.
  ///
  /// O QUE VOLTA PARA A UI É A VISTA RELIDA DA AUTORIDADE
  /// ([RespostaDeAcao.vista]), e não uma dedução a partir do desfecho. O
  /// desfecho traz o estado do BANCO (`amigos`, `pendente`), que não conhece
  /// bloqueio nem sanção — desenhar botões a partir dele reabriria, num lugar
  /// novo, a política duplicada que o módulo inteiro existe para não ter.
  ///
  /// `vista` nula é "não sei": a faixa some. Não vira "vocês não são nada".
  Future<void> _acaoSocial(AcaoSocial acao) async {
    final alvo = widget.publicIdVisitado;
    final social = EscopoSocial.talvezDe(context);
    if (alvo == null || social == null || _agindo) return;
    setState(() => _agindo = true);
    try {
      final r = await social.agir(acao, alvo);
      if (!mounted) return;
      setState(() => _relacao = r.vista);
      _toast(textoDoDesfecho(acao, repeticao: r.repeticao));
    } on FalhaSocial catch (e) {
      if (!mounted) return;
      _toast(textoDaFalhaSocial(e));
    } finally {
      if (mounted) setState(() => _agindo = false);
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

  /// A PORTA PRODUTIVA PARA O RANKING REAL, e ela é uma só.
  ///
  /// A linha competitiva e o item "Ranking" da barra inferior chegam aqui — dois
  /// gestos, um destino. O item da barra dizia "chega nas próximas fatias", que
  /// deixou de ser verdade no instante em que a tabela passou a existir.
  ///
  /// Só empurra rota: não consulta nada. A tela aberta LÊ o `EscopoRanking` que
  /// esta mesma página já consome no cabeçalho, então abrir o ranking não
  /// acrescenta uma chamada — é a mesma resposta, vista inteira.
  void _abrirRanking() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const RankingDeProducao()));
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

    // UM VM SÓ, ENRIQUECIDO DUAS VEZES — e é isto que a composição precisava
    // preservar. Ranking e avatar chegaram por correções diferentes, cada uma
    // reescrevendo esta mesma linha na sua linhagem. Ficar com uma delas
    // apagaria a outra em silêncio, e mantê-las em dois VMs paralelos (um para
    // quem vem da Home, outro para quem vem do Ranking) recriaria a divergência
    // de telas que as DUAS vieram fechar. Então é um encadeamento, e o mesmo
    // Perfil passa pelos dois.
    //
    // A ordem não importa para o resultado: `comRanking` escreve só `ranking`,
    // `comAvatarPublico` escreve só `avatar`, e nenhum lê o campo do outro.
    //
    // O RANKING PRÓPRIO É LIDO AQUI, e não guardado no VM da carga.
    //
    // Ler no `build` faz duas coisas de uma vez. Primeiro, amarra esta tela ao
    // MESMO objeto que a Home lê — não há como as duas divergirem, porque não
    // há duas leituras. Segundo, a consulta em voo aparece: o Perfil entra em
    // "carregando" e passa para o resultado sozinho, sem recarregar a tela
    // inteira. Congelar o valor no instante da carga deixaria o Perfil eterno
    // em "carregando" para quem o abrisse rápido demais.
    //
    // O perfil VISITADO não passa por aqui: o ranking dele veio de `_carregar`,
    // consultado pelo `publicIdVisitado`, e sobrescrevê-lo com o estado da
    // sessão mostraria a liga de quem está olhando no perfil de quem é olhado.
    final comRanking = widget.ehMeuPerfil
        ? base.comRanking(EscopoRanking.meuEstadoDe(context))
        : base;

    // O AVATAR É REAPLICADO AQUI, e não herdado da carga. A leitura é a mesma
    // que a Home faz — `EscopoSessao` mais `avatarPublicoDaIdentidade` —, e é
    // por isso que as duas telas não conseguem divergir: não há uma segunda
    // regra, há a mesma função lida de dois lugares.
    //
    // Não é consulta nem assinatura nova: `identidadeDe` só lê o
    // `InheritedNotifier` que a raiz já pendurou, e é a MESMA dependência que
    // `didChangeDependencies` acima já estabelece. O efeito prático é que uma
    // troca de `avatarRef` chega ao Perfil pelo rebuild que a sessão notifica,
    // sem passar pela recarga (que só observa o `publicId`) e sem devolver a
    // tela ao esqueleto.
    //
    // COM GUARDA DE `ehMeuPerfil`, e a guarda é a correção.
    //
    // A composição anterior aplicava esta linha em TODO perfil, e registrou a
    // assimetria como deliberada com um argumento que era verdadeiro na época:
    // não havia de onde tirar o avatar de um terceiro, então reaplicar o da
    // sessão não mudava nada — o serviço já tinha escrito o mesmo valor.
    //
    // Agora há. O perfil visitado chega da carga com o avatar que a autoridade
    // pública publicou para aquele `publicId`, e reaplicar o da sessão por cima
    // apagaria justamente o que esta correção foi buscar. A reatividade que esta
    // reaplicação existe para dar — trocar de avatar e ver na hora, sem recarga
    // — é do DONO, e só faz sentido para ele.
    final identidade = EscopoSessao.identidadeDe(context).identidade;
    final vm = widget.ehMeuPerfil
        ? comRanking.comAvatarPublico(avatarPublicoDaIdentidade(identidade))
        : comRanking;

    return PerfilScreen(
      vm: vm,
      estado: _estado,
      mensagemErro: _erro,
      // Nula no perfil do dono, e nula enquanto não se souber a relação. Ver
      // [_FaixaSocial] para por que "não sei" é ausência de faixa, e não uma
      // faixa dizendo que não há relação.
      faixaSocial: widget.ehMeuPerfil || _relacao == null
          ? null
          : _FaixaSocial(
              relacao: _relacao!,
              ocupado: _agindo,
              onAgir: _acaoSocial,
            ),
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
      onAbrirRanking: _abrirRanking,
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
            // UNIÃO, e a primeira tentativa estava ERRADA. Mandar este destino
            // para `_abrirRanking` (o host novo, que lê a fonte real) tirou do
            // fecho alcançável DEZ arquivos de uma vez — `ranking_page.dart` era
            // o único ponto de produção que construía `RankingPage`, e
            // `RankingPage` é a única porta para `HallPage`. O Hall inteiro
            // saía da árvore em silêncio, sem nenhum teste vermelho.
            //
            // As DUAS portas ficam, de propósito, e não é indecisão: o cartão
            // (`onAbrirRanking`) abre a tabela de fonte real, e a barra inferior
            // continua abrindo a página que hospeda o Hall. Unificá-las exige
            // decidir onde o Hall passa a morar, e isso é OS própria — esta aqui
            // não pode remover superfície que não veio compor.
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

/// A faixa de relação social do Perfil visitado.
///
/// ---------------------------------------------------------------------------
/// O QUE ELA DESENHA, E DE ONDE VEM CADA COISA
/// ---------------------------------------------------------------------------
///
/// O rótulo vem de [rotuloDaRelacao] — as mesmas palavras que a tela de Amigos
/// usa, porque são a mesma relação. Os botões vêm de [ResultadoSocial.acoes],
/// que é o que a AUTORIDADE ofereceu para aquele jogador naquele momento; não há
/// aqui nenhum `if (relacao == amigos)` decidindo botão, e não pode haver.
///
/// ---------------------------------------------------------------------------
/// POR QUE UM ESTADO SEM RÓTULO E SEM AÇÃO NÃO DESENHA NADA
/// ---------------------------------------------------------------------------
///
/// [RelacaoSocial.nenhuma] com a lista de ações vazia é o caso de quem não pode
/// interagir por motivo que o contrato esconde — e o desenho certo é o silêncio.
/// Uma faixa vazia com moldura seria, ela mesma, a informação de que há algo do
/// outro lado: é a mesma razão pela qual o backend não oferece nem "bloquear"
/// num perfil indisponível.
class _FaixaSocial extends StatelessWidget {
  const _FaixaSocial({
    required this.relacao,
    required this.ocupado,
    required this.onAgir,
  });

  final ResultadoSocial relacao;
  final bool ocupado;
  final ValueChanged<AcaoSocial> onAgir;

  static const _ouro = Color(0xFFEFB94A);
  static const _ouroClaro = Color(0xFFF6E2A6);
  static const _textoSec = Color(0xFFB6A884);
  static const _borda = Color(0x33EFB94A);

  @override
  Widget build(BuildContext context) {
    final rotulo = rotuloDaRelacao(relacao.relacao);
    // Só as ações que este aplicativo sabe executar. `bloquear` e `desbloquear`
    // são do codebase de MODERAÇÃO — o social apenas reage a eles por gatilho —,
    // e desenhá-los como botão sem porta seria prometer o que não se cumpre.
    final acoes = relacao.acoes.where(kAcoesDeAmizade.contains).toList();
    if (rotulo == null && acoes.isEmpty) return const SizedBox.shrink();

    return Semantics(
      container: true,
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 6,
        children: [
          if (rotulo != null)
            Text(
              rotulo,
              style: const TextStyle(
                color: _textoSec,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          if (ocupado)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2.2, color: _ouro),
            )
          else
            for (final acao in acoes)
              ConstrainedBox(
                // O piso das diretrizes de toque, e não só o tamanho do texto.
                constraints: const BoxConstraints(minHeight: 40, minWidth: 88),
                child: OutlinedButton(
                  onPressed: () => onAgir(acao),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _ouroClaro,
                    side: const BorderSide(color: _borda),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    visualDensity: VisualDensity.compact,
                  ),
                  child: Text(
                    verboDaAcao(acao),
                    style: const TextStyle(fontSize: 12.5),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
