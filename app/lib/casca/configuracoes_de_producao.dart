// configuracoes_de_producao.dart — Ajustes, e o único botão de sair do app.
//
// ---------------------------------------------------------------------------
// DUAS CORREÇÕES, E AS DUAS SÃO SOBRE QUEM MANDA
// ---------------------------------------------------------------------------
//
// O host anterior fazia duas coisas por conta própria:
//
//   1. montava o cabeçalho lendo `FirebaseAuth.instance.currentUser` direto —
//      nome e e-mail vindos de um lugar que não é a sessão canônica. Era uma
//      segunda fonte de verdade sobre a identidade, e uma que continuaria
//      mostrando os dados do jogador anterior até o Firebase se atualizar;
//
//   2. saía da conta chamando `FirebaseAuth.instance.signOut()` e
//      `GoogleSignIn().signOut()` na mão, e depois dava `popUntil` para voltar
//      à primeira rota. O `popUntil` é o detalhe que denuncia o modelo antigo:
//      ele existia porque a tela de baixo continuaria sendo a Home privada.
//
// Agora: a identidade vem do `EscopoSessao`, e o logout é um comando canônico.
// Não há `popUntil` — a raiz troca de tela sozinha ao ver a sessão cair, e a
// pilha de navegação inteira é descartada junto, porque o `MaterialApp` é
// chaveado pela geração da sessão (ver `raiz_do_aplicativo.dart`). É o que faz
// esta tela poder sumir sem se preocupar em navegar: ela não sobrevive à
// própria ação.

import 'dart:async';

import 'package:flutter/material.dart';

import '../screens/configuracoes_screen.dart';
import '../screens/como_jogar_screen.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/configuracoes_service.dart';
import '../screens/excluir_conta_screen.dart';
import '../conta/controlador_exclusao.dart';
import '../conta/fonte_exclusao_firebase.dart';
import '../billing/acesso_vip.dart';
import '../billing/entitlement_repositorio.dart';
import '../billing/gerenciar_assinatura.dart';
import '../sessao/escopo_sessao.dart';
import '../elegibilidade/entitlement.dart';
import '../sessao/identidade_publica_sessao.dart';
import '../tema/iconografia_ajustes.dart';
import '../tema/resolucao_tema_ajustes.dart';
import 'escopo_autenticacao.dart';
import 'loja_de_producao.dart';

/// Versão exibida nos Ajustes. Vem da configuração do build; o padrão acompanha
/// a `version` do `pubspec.yaml`.
const String kVersaoDoAplicativo = String.fromEnvironment(
  'BMV_VERSAO_APP',
  defaultValue: '1.0.0',
);

class ConfiguracoesDeProducao extends StatefulWidget {
  const ConfiguracoesDeProducao({
    super.key,
    this.observarEntitlement = _entitlementDeProducao,
    this.verificarConjuntoReal,
    this.aoDiagnosticar,
  });

  /// A escuta de `playerEntitlements/{uid}` — a MESMA porta que a Loja usa.
  ///
  /// Injetavel porque o teste precisa encenar assinante, carencia, expirado e
  /// falha de leitura sem Firebase; producao nao passa nada e recebe o
  /// repositorio real.
  final FonteEntitlement observarEntitlement;

  /// Pre-checagem do conjunto luxuoso INTEIRO. `null` = a de producao.
  final Future<bool> Function()? verificarConjuntoReal;

  /// Para onde vai o diagnostico sanitizado do fallback de iconografia.
  ///
  /// NAO E `debugPrint`, e a diferenca importa: a auditoria da casca proibe
  /// que esta camada escreva em log, porque e por log que credencial e
  /// identidade vazam sem ninguem ver. O diagnostico existe, e formado
  /// (`ResolucaoDeTema.diagnostico`, vocabulario fechado, sem uid e sem
  /// e-mail), e so vai a algum lugar se quem monta a tela disser para onde.
  /// Em producao ninguem diz, e nada e escrito.
  final void Function(String diagnostico)? aoDiagnosticar;

  @override
  State<ConfiguracoesDeProducao> createState() =>
      _ConfiguracoesDeProducaoState();
}

/// A escuta real de `playerEntitlements/{uid}`.
///
/// O `try` NAO e paranoia: `EntitlementRepositorio()` toca
/// `FirebaseFirestore.instance` no construtor, e num build sem Firebase isso
/// LANCA — derrubando a arvore inteira por causa de um tema cosmetico. O
/// desfecho certo desse caso e DUVIDA, nao 'nao e VIP': um fluxo de erro
/// vira `SituacaoVip.erro`, que o resolvedor le como estado desconhecido e
/// responde com Tema Padrao. Devolver `Stream.empty()` diria 'ainda
/// carregando' para sempre; devolver `ausente(uid)` afirmaria que a pessoa
/// nao assina, o que ninguem verificou.
Stream<EntitlementVip> _entitlementDeProducao(String uid) {
  try {
    return EntitlementRepositorio().observar(uid);
  } catch (erro, pilha) {
    return Stream<EntitlementVip>.error(erro, pilha);
  }
}

class _ConfiguracoesDeProducaoState extends State<ConfiguracoesDeProducao> {
  // Estado REAL: carrega do disco (SharedPreferences) e persiste cada mudança.
  Configuracoes _config = const Configuracoes(versaoApp: kVersaoDoAplicativo);

  /// Um logout em voo. Impede o segundo toque de disparar um segundo comando.
  bool _saindo = false;

  /// O PORTAO VIP desta tela. Ele guarda fatos (uid, documento, se falhou) e
  /// recomputa a vigencia contra o relogio a cada leitura — e por isso um
  /// direito que vence com a tela aberta deixa de valer na reconstrucao
  /// seguinte, sem escrita no Firestore e sem relogio proprio aqui.
  late final PortaoVip _portao = PortaoVip(fonte: widget.observarEntitlement);
  StreamSubscription<AcessoVip>? _escutaVip;

  /// O uid que o portao esta seguindo. Trocar de conta reancora o portao e
  /// zera a resolucao ANTES de qualquer leitura nova: nao existe instante em
  /// que o tema do jogador anterior sirva de cache para o proximo.
  String? _uid;

  /// A resolucao corrente. Comeca no Padrao, sempre — inclusive para quem vai
  /// se revelar assinante um quadro depois.
  ResolucaoDeTema _tema = const ResolucaoDeTema(
    tema: TemaIconografia.padrao,
    estado: EstadoTemaVip.desconhecido,
    motivo: MotivoDoTema.autoridadeIndefinida,
  );

  /// Serializa as resolucoes: a checagem do conjunto e assincrona, e sem isto
  /// uma resposta velha poderia chegar depois de uma nova e reacender o tema
  /// de um direito que ja caiu.
  int _geracaoDaResolucao = 0;

  @override
  void initState() {
    super.initState();
    ConfiguracoesService.instance
        .carregar(versaoApp: kVersaoDoAplicativo)
        .then((c) {
          if (mounted) setState(() => _config = c);
        })
        // Sem armazenamento local disponível a tela abre nos padrões, que é o
        // que ela já mostra. Sem este `catch`, a falha viraria exceção
        // assíncrona sem dono e derrubaria a tela inteira por causa de uma
        // preferência de som.
        .catchError((Object _) {});
    _escutaVip = _portao.mudancas.listen((_) => _resolverTema());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final uid = EscopoSessao.identidadeDe(context).uid;
    if (uid == _uid) return;
    _uid = uid;
    // A projecao visual da conta anterior sai da tela ANTES de a nova ser
    // consultada. Sem isto, o intervalo entre trocar de conta e o primeiro
    // evento do Firestore mostraria o VIP de quem saiu.
    _tema = const ResolucaoDeTema(
      tema: TemaIconografia.padrao,
      estado: EstadoTemaVip.desconhecido,
      motivo: MotivoDoTema.autoridadeIndefinida,
    );
    _portao.usarSessao(uid);
  }

  @override
  void dispose() {
    _escutaVip?.cancel();
    _portao.encerrar();
    super.dispose();
  }

  /// Reavalia o tema INTEIRO a partir do retrato corrente da autoridade.
  Future<void> _resolverTema() async {
    final geracao = ++_geracaoDaResolucao;
    final resolucao = await resolverTemaDeAjustes(
      acesso: _portao.atual,
      verificarConjunto: widget.verificarConjuntoReal,
    );
    if (!mounted || geracao != _geracaoDaResolucao) return;
    if (resolucao.tema == _tema.tema && resolucao.motivo == _tema.motivo) {
      // Nada mudou para a tela. Reconstruir aqui seria reconstrucao por
      // evento de rede, e a §12 proibe que a troca de tema mexa em estado.
      _tema = resolucao;
      return;
    }
    if (resolucao.tema == TemaIconografia.padrao &&
        resolucao.motivo != MotivoDoTema.concedido) {
      // Diagnostico tecnico SANITIZADO: nem uid, nem e-mail, nem caminho de
      // arquivo, nem mensagem de excecao. So o vocabulario fechado da §7.
      widget.aoDiagnosticar?.call(resolucao.diagnostico);
    }
    setState(() => _tema = resolucao);
  }

  void _aviso(String texto) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(texto),
          duration: const Duration(milliseconds: 1500),
          backgroundColor: const Color(0xFF2A1B0E),
        ),
      );
  }

  /// O cabeçalho, montado a partir da SESSÃO — nunca do provedor de
  /// autenticação.
  ///
  /// `vip` e `moedas` ficam nos valores neutros porque não há autoridade de
  /// assinatura nem de economia alcançável pelo cliente. Preencher VIP com um
  /// palpite aqui seria pior do que não mostrar: a tela ganharia um selo dourado
  /// que ninguém emitiu.
  PerfilResumo _cabecalho(EstadoIdentidadeSessao estado) {
    final identidade = estado.identidade;
    final apelido = identidade?.apelido.trim() ?? '';
    final acesso = _portao.atual;
    return PerfilResumo(
      apelido: apelido.isNotEmpty
          ? apelido
          : (identidade?.publicId ?? 'Jogador(a)'),
      // Tela PRIVADA da propria pessoa: aqui o e-mail da conta pode aparecer.
      // No Perfil publico, nao — e por isso ele vem do provedor de
      // AUTENTICACAO e nunca da `IdentidadePublica`, que e o que terceiros veem.
      email: EscopoAutenticacao.de(context).emailDaConta ?? '',
      // Avatar publico canonico. Nao ha coroa fixa por cima da identidade: a
      // coroa so aparece como fallback de quem nao tem apelido nem avatar, como
      // ja era antes desta OS.
      avatar: identidade?.avatarRef,
      // O SELO VEM DA AUTORIDADE. `liberado` significa 'vigente agora', medido
      // pelo portao contra o relogio; a tela nao o deriva do plano escrito ao
      // lado nem de coisa nenhuma que ela mesma desenhe.
      vip: acesso.liberado,
      assinatura: _assinaturaNaTela(acesso),
      // Nulo, e nao zero: sem autoridade de economia, "0 fichas disponiveis" e
      // uma afirmacao sobre a carteira de alguem que ninguem consultou.
      fichas: null,
    );
  }

  /// O identificador do plano, quando ele tem a forma de um id da Play.
  ///
  /// E o identificador TECNICO, e nao um nome bonito: o nome comercial
  /// ('Mensal', 'Anual') vem do periodo que a consulta da Play devolve, e essa
  /// consulta nao acontece nesta tela — `playerEntitlements` guarda o produto,
  /// nao o catalogo. Inventar 'Mensal' a partir do produto seria afirmar um
  /// periodo que ninguem consultou, que e o defeito que a §10 nomeia. Sem
  /// identificador valido a tela cai em 'Plano VIP', que nao afirma periodo.
  static String? _identificadorDoPlano(String? produtoId) {
    final id = produtoId?.trim();
    if (id == null || id.isEmpty) return null;
    return kFormatoIdentificadorPlay.hasMatch(id) ? id : null;
  }

  /// Traduz o retrato da autoridade para a linha 'Assinatura VIP' da §10.
  ///
  /// Cada estado da Play vira um estado da tela; nenhum vira texto aqui. Quem
  /// escreve a frase e a propria tela, a partir dos CAMPOS — plano, data e
  /// renovacao —, o que e o oposto de 'Renova em 24/08 · Mensal' fixo.
  AssinaturaVipNaTela _assinaturaNaTela(AcessoVip acesso) {
    if (acesso.situacao == SituacaoVip.carregando ||
        acesso.situacao == SituacaoVip.erro) {
      return const AssinaturaVipNaTela();
    }
    final direito = acesso.entitlement;
    if (direito == null) {
      return acesso.situacao == SituacaoVip.semSessao
          ? const AssinaturaVipNaTela()
          : const AssinaturaVipNaTela(
              situacao: SituacaoAssinaturaVip.semAssinatura,
            );
    }
    final situacao = switch (direito.estado) {
      EstadoEntitlement.nuncaTeve => SituacaoAssinaturaVip.semAssinatura,
      EstadoEntitlement.ativo => SituacaoAssinaturaVip.ativa,
      EstadoEntitlement.emCarencia => SituacaoAssinaturaVip.emCarencia,
      EstadoEntitlement.canceladoVigente =>
        SituacaoAssinaturaVip.renovacaoCancelada,
      EstadoEntitlement.emEspera => SituacaoAssinaturaVip.emEspera,
      EstadoEntitlement.pausado => SituacaoAssinaturaVip.pausada,
      EstadoEntitlement.pendente => SituacaoAssinaturaVip.pendente,
      EstadoEntitlement.expirado => SituacaoAssinaturaVip.expirada,
      EstadoEntitlement.revogado => SituacaoAssinaturaVip.expirada,
      EstadoEntitlement.reembolsado => SituacaoAssinaturaVip.expirada,
      EstadoEntitlement.desconhecido => SituacaoAssinaturaVip.indisponivel,
    };
    return AssinaturaVipNaTela(
      situacao: situacao,
      plano: _identificadorDoPlano(direito.produtoId),
      validoAte: direito.expiraEm,
      renovacaoAutomatica: direito.renovacaoAutomatica,
    );
  }

  Future<void> _salvar(Configuracoes novo) async {
    setState(() => _config = novo); // aplica na hora na UI
    await ConfiguracoesService.instance.salvar(novo); // persiste no disco
  }

  Future<void> _confirmarSaida() async {
    if (_saindo) return;
    final sair = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1C130C),
        title: const Text(
          'Sair da conta?',
          style: TextStyle(color: Color(0xFFF6E2A6)),
        ),
        content: const Text(
          'Você precisará entrar novamente para continuar jogando.',
          style: TextStyle(color: Color(0xFFD5C4A3)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF8E2F2B),
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Sair'),
          ),
        ],
      ),
    );
    if (sair != true || !mounted) return;

    setState(() => _saindo = true);
    // O ÚNICO caminho de saída do aplicativo. Ele encerra a sessão no provedor;
    // o resto acontece em cascata e sem esta tela participar: a sessão vê o uid
    // cair, sobe a geração, a ponte derruba socket e reconexão, e a raiz
    // substitui a árvore pela tela pública. NÃO há `pop` aqui — navegar seria
    // disputar com a raiz quem decide a tela.
    await EscopoAutenticacao.de(context).sair();
    if (mounted) setState(() => _saindo = false);
  }

  @override
  Widget build(BuildContext context) {
    return ConfiguracoesScreen(
      icones: _tema.icones,
      perfil: _cabecalho(EscopoSessao.identidadeDe(context)),
      config: _config,
      onVoltar: () => Navigator.of(context).maybePop(),
      callbacks: ConfiguracoesCallbacks(
        onAlterar: _salvar,
        onEditarPerfil: () =>
            _aviso('Editar perfil ainda não está disponível.'),
        // A SEGUNDA porta para a Loja, e ela existe porque é aqui que a pessoa
        // vem procurar a própria assinatura. Não é um atalho decorativo: quem
        // abre Ajustes para ver o VIP não deveria ter de voltar à Home e achar
        // o item da grade.
        onAssinaturaVip: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const LojaDeProducao()),
        ),
        onFichasECompras: () =>
            _aviso('A compra de fichas ainda não está disponível.'),
        onBloqueados: () =>
            _aviso('A lista de bloqueados ainda não está disponível.'),
        onRegras: _abrirRegras,
        onSuporte: () => _aviso('O suporte ainda não está disponível.'),
        onTermos: () =>
            _aviso('Os termos e a privacidade ainda não estão disponíveis.'),
        onAvaliar: () =>
            _aviso('A avaliação na loja ainda não está disponível.'),
        onSair: _confirmarSaida,
        onExcluirConta: _abrirExclusaoDeConta,
      ),
    );
  }

  /// Exclusão de conta — a costura que a composição canônica exigiu.
  ///
  /// A tela e o controlador vieram da linhagem de conta; o que NÃO veio junto
  /// foi o roteamento: o `main.dart` antigo abria isto de dentro de um `State`
  /// que falava direto com `FirebaseAuth.instance` e com o `GoogleSignIn`. Aqui
  /// as duas dependências saem da autoridade única — `EscopoAutenticacao` para
  /// reautenticar e encerrar, `EscopoSessao` para saber de quem é a conta.
  ///
  /// É obrigatória por duas razões, e qualquer uma bastaria: `ConfiguracoesScreen`
  /// declara `onExcluirConta` como `required` (sem ela a árvore não compila), e
  /// o caminho de exclusão dentro do aplicativo é exigência da Play.
  Future<void> _abrirExclusaoDeConta() async {
    final autenticacao = EscopoAutenticacao.de(context);
    final uid = EscopoSessao.identidadeDe(context).uid;

    final controlador = ControladorDeExclusao(
      fonte: FonteDeExclusaoFirebase(),
      reautenticar: autenticacao.reautenticar,
      lerAssinatura: () => _assinaturaDe(uid),
      abrirLinkExterno: (destino) =>
          launchUrl(destino, mode: LaunchMode.externalApplication),
      encerrarSessao: autenticacao.sair,
    );

    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (rota) => ExcluirContaScreen(
          controlador: controlador,
          onVoltar: () => Navigator.of(rota).maybePop(),
          // Conta excluída: volta para a raiz. A sessão já se invalidou sozinha
          // quando o `sair()` fez o fluxo de autenticação emitir `null` — não há
          // estado a limpar à mão aqui.
          onConcluida: () => Navigator.of(rota).popUntil((r) => r.isFirst),
        ),
      ),
    );

    controlador.dispose();
  }

  /// A situação da assinatura, para a tela de exclusão.
  ///
  /// LEITURA ÚNICA, e todo caminho de dúvida cai em `nenhuma`: sem sessão, sem
  /// documento ou com erro de leitura. Não oferecer um botão custa menos do que
  /// prometer uma assinatura que não existe.
  Future<AssinaturaParaGerenciar> _assinaturaDe(String? uid) async {
    if (uid == null || uid.isEmpty) return AssinaturaParaGerenciar.nenhuma;
    try {
      final entitlement = await EntitlementRepositorio().ler(uid);
      return AssinaturaParaGerenciar.doEntitlement(
        entitlement,
        DateTime.now().toUtc(),
      );
    } catch (_) {
      return AssinaturaParaGerenciar.nenhuma;
    }
  }

  void _abrirRegras() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (rota) => ComoJogarScreen(
          onVoltar: () => Navigator.of(rota).maybePop(),
          // Nas regras abertas pelos Ajustes não há atalho para a mesa: a pessoa
          // veio ler, e empurrá-la para uma partida a tiraria de onde estava.
          onJogarTreino: () => Navigator.of(rota).maybePop(),
        ),
      ),
    );
  }
}
