// casca_de_producao.dart — quem decide qual tela o aplicativo mostra.
//
// ---------------------------------------------------------------------------
// UMA DECISÃO, TOMADA NUM LUGAR SÓ
// ---------------------------------------------------------------------------
//
//   inicialização → Splash oficial → a sessão responde → Login ou Home
//
// A decisão é DECLARATIVA: esta tela não empurra rota nenhuma para trocar entre
// Login e Home. Ela lê a sessão e desenha o que aquele estado significa. É o que
// torna impossível o defeito clássico do roteamento imperativo — a tela privada
// que continua na pilha depois do logout porque ninguém se lembrou de removê-la.
//
// ---------------------------------------------------------------------------
// POR QUE ESPERAR A SESSÃO, E NÃO SÓ A ANIMAÇÃO
// ---------------------------------------------------------------------------
//
// `estado.autenticado == false` responde duas perguntas diferentes com a mesma
// palavra: "não há ninguém logado" e "ainda não sabemos". Quem restaura sessão
// salva demora alguns quadros para se pronunciar, e uma casca que olhasse só o
// `autenticado` mostraria a tela pública nesse intervalo — um piscar de Login
// para quem já estava logado.
//
// Por isso a espera é por `sessao.resolvida`, e a Splash cobre o intervalo
// inteiro: a animação termina e a tela continua ali até a resposta chegar.
//
// ---------------------------------------------------------------------------
// E SE A RESPOSTA NUNCA CHEGAR
// ---------------------------------------------------------------------------
//
// Existe teto. Uma splash eterna é, para quem olha, um aplicativo travado — e
// travado sem nada para apertar. Passado [limiteDeResolucao] sem resposta, a
// casca mostra um estado explícito, com o que houve e um botão. Isso NÃO é
// inventar sessão: continua não havendo identidade, e a tela diz exatamente
// isso.

import 'dart:async';

import 'package:flutter/material.dart';

import '../sessao/escopo_sessao.dart';
import '../sessao/sessao_do_jogador.dart';
import 'home_de_producao.dart';
import 'login_de_producao.dart';
import 'splash/contrato_da_abertura.dart';
import 'splash/splash_constelacao_screen.dart';

/// Quanto a casca espera o fluxo de autenticação se pronunciar antes de
/// desistir e oferecer uma saída.
const Duration kLimitePadraoDeResolucao = Duration(seconds: 8);

class CascaDeProducao extends StatefulWidget {
  const CascaDeProducao({
    super.key,
    required this.aberturaTerminou,
    required this.onAberturaConcluida,
    this.duracaoDaSplash,
    this.somNaSplash = true,
    this.limiteDeResolucao,
    this.fonteDaAbertura,
  });

  /// A abertura já tocou nesta execução.
  ///
  /// Vem de fora porque esta tela é reconstruída do zero a cada troca de
  /// sessão. Guardado aqui dentro, o valor se perderia e a animação de abertura
  /// tocaria de novo a cada login e a cada logout.
  final bool aberturaTerminou;
  final VoidCallback onAberturaConcluida;

  /// Duração da abertura. Nula usa o padrão da própria splash.
  final Duration? duracaoDaSplash;

  /// Desligável para os testes de widget, que não têm plugin de áudio.
  final bool somNaSplash;

  final Duration? limiteDeResolucao;

  /// De onde a arte da abertura vem. Nula em produção — a splash usa a fonte
  /// real da Rive.
  ///
  /// Existe pelo mesmo motivo das outras costuras desta casca: o runtime da
  /// Rive é nativo e não sobe dentro de `flutter test`, então sem esta injeção
  /// o portão duplo (animação × bootstrap) só poderia ser provado no ramo em
  /// que a arte FALHA — e o caso que mais importa é justamente o outro.
  final FonteDaAbertura? fonteDaAbertura;

  @override
  State<CascaDeProducao> createState() => _CascaDeProducaoState();
}

class _CascaDeProducaoState extends State<CascaDeProducao> {
  /// O teto de espera estourou sem a sessão se pronunciar.
  bool _esperaEstourou = false;

  Timer? _relogioDaEspera;

  Duration get _limite => widget.limiteDeResolucao ?? kLimitePadraoDeResolucao;

  @override
  void initState() {
    super.initState();
    _armarEspera();
  }

  void _armarEspera() {
    _relogioDaEspera?.cancel();
    _relogioDaEspera = Timer(_limite, () {
      if (!mounted) return;
      // Marca e pronto: não é preciso conferir a sessão aqui, porque o `build`
      // só consulta esta bandeira DEPOIS de constatar que ela não respondeu. Se
      // respondeu no meio do caminho, o ramo nunca é avaliado — e ler o escopo
      // de dentro de um timer criaria dependência fora da fase de build por
      // nada.
      setState(() => _esperaEstourou = true);
    });
  }

  void _tentarDeNovo() {
    setState(() => _esperaEstourou = false);
    _armarEspera();
  }

  @override
  void dispose() {
    _relogioDaEspera?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final SessaoDoJogador? sessao = EscopoSessao.talvezDe(context);

    // Sem sessão acima não existe casca de produção — só pré-visualização de
    // tela. Dizer isso é mais honesto do que desenhar uma Home sem dono.
    if (sessao == null) {
      return const _AvisoTerminal(
        titulo: 'Aplicativo mal configurado',
        detalhe: 'A sessão do jogador não foi montada na abertura.',
      );
    }

    if (!sessao.resolvida) {
      if (_esperaEstourou) {
        return _EsperaEstourada(onTentarDeNovo: _tentarDeNovo);
      }
      return _splash();
    }

    // A sessão respondeu. A abertura ainda pode estar tocando — e ela toca até
    // o fim: cortar a animação porque a resposta chegou cedo faria a abertura
    // durar um tempo diferente a cada vez que o aplicativo abrisse.
    if (!widget.aberturaTerminou) return _splash();

    if (!sessao.estado.autenticado) return const LoginDeProducao();
    return const HomeDeProducao();
  }

  Widget _splash() => SplashConstelacaoScreen(
    // A chave amarra o estado da splash a ESTA instância: sem ela, sair do ramo
    // de espera e voltar recriaria a animação do zero.
    key: const ValueKey('splash-da-casca'),
    habilitarSom: widget.somNaSplash,
    // A duração de autoria da timeline é o padrão. Ela não é a autoridade do
    // fim — quem termina a animação é a própria arte —, e sim o horizonte do
    // relógio de segurança da abertura.
    duracao: widget.duracaoDaSplash ?? kDuracaoDaAbertura,
    fonte: widget.fonteDaAbertura,
    onConcluida: widget.onAberturaConcluida,
  );
}

/// A sessão não se pronunciou dentro do teto.
class _EsperaEstourada extends StatelessWidget {
  const _EsperaEstourada({required this.onTentarDeNovo});

  final VoidCallback onTentarDeNovo;

  @override
  Widget build(BuildContext context) {
    return _Moldura(
      children: [
        const Text('⏳', style: TextStyle(fontSize: 40)),
        const SizedBox(height: 14),
        const Text(
          'Não consegui iniciar sua sessão',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFFF6E2A6),
            fontSize: 19,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'A verificação da sua conta está demorando mais que o normal. '
          'Confira sua conexão e tente de novo.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFFB9A886),
            fontSize: 13,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 20),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFEFB94A),
            foregroundColor: const Color(0xFF3A2606),
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 13),
          ),
          onPressed: onTentarDeNovo,
          child: const Text(
            'Tentar de novo',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

/// Estado do qual não se sai tentando de novo: o build está errado.
class _AvisoTerminal extends StatelessWidget {
  const _AvisoTerminal({required this.titulo, required this.detalhe});

  final String titulo;
  final String detalhe;

  @override
  Widget build(BuildContext context) {
    return _Moldura(
      children: [
        const Text('⚠️', style: TextStyle(fontSize: 40)),
        const SizedBox(height: 14),
        Text(
          titulo,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFFF6E2A6),
            fontSize: 19,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          detalhe,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFFB9A886),
            fontSize: 13,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

/// O fundo da casa, para os estados que não são tela de conteúdo.
class _Moldura extends StatelessWidget {
  const _Moldura({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF120A06),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: children,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
