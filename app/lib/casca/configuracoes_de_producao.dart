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

import 'package:flutter/material.dart';

import '../screens/configuracoes_screen.dart';
import '../screens/como_jogar_screen.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/configuracoes_service.dart';
import '../screens/excluir_conta_screen.dart';
import '../conta/controlador_exclusao.dart';
import '../conta/fonte_exclusao_firebase.dart';
import '../billing/entitlement_repositorio.dart';
import '../billing/gerenciar_assinatura.dart';
import '../sessao/escopo_sessao.dart';
import '../sessao/escopo_sessao.dart';
import '../sessao/identidade_publica_sessao.dart';
import 'escopo_autenticacao.dart';

/// Versão exibida nos Ajustes. Vem da configuração do build; o padrão acompanha
/// a `version` do `pubspec.yaml`.
const String kVersaoDoAplicativo = String.fromEnvironment(
  'BMV_VERSAO_APP',
  defaultValue: '1.0.0',
);

class ConfiguracoesDeProducao extends StatefulWidget {
  const ConfiguracoesDeProducao({super.key});

  @override
  State<ConfiguracoesDeProducao> createState() =>
      _ConfiguracoesDeProducaoState();
}

class _ConfiguracoesDeProducaoState extends State<ConfiguracoesDeProducao> {
  // Estado REAL: carrega do disco (SharedPreferences) e persiste cada mudança.
  Configuracoes _config = const Configuracoes(versaoApp: kVersaoDoAplicativo);

  /// Um logout em voo. Impede o segundo toque de disparar um segundo comando.
  bool _saindo = false;

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
    return PerfilResumo(
      apelido: apelido.isNotEmpty
          ? apelido
          : (identidade?.publicId ?? 'Jogador(a)'),
      // O e-mail não é exibido: ele não ajuda quem já está logado e é dado
      // pessoal à mostra numa tela que se abre no meio de uma mesa.
      email: '',
      vip: false,
      // Nulo, e não zero: sem autoridade de economia, "0 moedas disponíveis" é
      // uma afirmação sobre a carteira de alguém que ninguém consultou.
      moedas: null,
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
      perfil: _cabecalho(EscopoSessao.identidadeDe(context)),
      config: _config,
      onVoltar: () => Navigator.of(context).maybePop(),
      callbacks: ConfiguracoesCallbacks(
        onAlterar: _salvar,
        onEditarPerfil: () =>
            _aviso('Editar perfil ainda não está disponível.'),
        onAssinaturaVip: () =>
            _aviso('A assinatura VIP ainda não está disponível.'),
        onMoedasCompras: () =>
            _aviso('A compra de moedas ainda não está disponível.'),
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
