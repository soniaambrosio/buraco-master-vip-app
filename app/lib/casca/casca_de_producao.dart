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
import 'package:flutter/semantics.dart';

import '../screens/splash_oficial_screen.dart';
import '../sessao/escopo_sessao.dart';
import '../sessao/sessao_do_jogador.dart';
import 'home_de_producao.dart';
import 'login_de_producao.dart';

/// Quanto a casca espera o fluxo de autenticação se pronunciar antes de
/// desistir e oferecer uma saída.
const Duration kLimitePadraoDeResolucao = Duration(seconds: 8);

/// O título do estado de espera estourada.
///
/// Constante porque ele é dito DUAS vezes: desenhado na tela e anunciado a
/// quem usa leitor de tela, no quadro em que o estado entra em vigor. Duas
/// cópias da mesma frase divergem com o tempo, e um anúncio divergente passa
/// a descrever uma tela que não está mais ali.
const String kTituloDaEsperaEstourada = 'Não consegui iniciar sua sessão';

class CascaDeProducao extends StatefulWidget {
  const CascaDeProducao({
    super.key,
    required this.aberturaTerminou,
    required this.onAberturaConcluida,
    this.duracaoDaSplash,
    this.somNaSplash = true,
    this.limiteDeResolucao,
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

  @override
  State<CascaDeProducao> createState() => _CascaDeProducaoState();
}

class _CascaDeProducaoState extends State<CascaDeProducao> {
  /// O teto de espera estourou sem a sessão se pronunciar.
  bool _esperaEstourou = false;

  /// A entrada NESTE estado já foi dita em voz alta.
  ///
  /// Zerada por [_tentarDeNovo]: voltar a esperar e estourar de novo é uma
  /// transição nova, e merece ser anunciada de novo.
  bool _jaAnunciouOEstouro = false;

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

  /// Diz, uma vez só, que a tela mudou debaixo de quem não está olhando.
  ///
  /// A troca acontece DENTRO desta casca: a rota não muda, e quem usa leitor
  /// de tela estava na abertura. Sem anúncio, a pessoa segue esperando uma
  /// animação que já foi substituída por um botão. É o que a visão entrega de
  /// graça e a leitura não.
  ///
  /// QUEM CHAMA É O `build`, E NÃO O RELÓGIO. A bandeira `_esperaEstourou`
  /// não é a autoridade sobre o que está na tela — ela é só um dos termos da
  /// decisão. Sem sessão montada acima, por exemplo, o teto estoura do mesmo
  /// jeito e o que aparece é o AVISO TERMINAL; anunciado dali, o estouro
  /// falaria de uma tela que ninguém está vendo. Chamado do ramo que de fato
  /// desenha o estado, o anúncio só existe quando o estado existe.
  ///
  /// UMA VEZ, E NÃO A CADA QUADRO: a bandeira sobe na primeira chamada e só
  /// desce em [_tentarDeNovo]. Reconstrução por qualquer outro motivo —
  /// teclado, rotação, escala de texto — passa por aqui e não fala nada.
  void _anunciarAEsperaEstourada() {
    if (_jaAnunciouOEstouro) return;
    _jaAnunciouOEstouro = true;
    // O quadro que está sendo construído agora é o que põe o estado na tela,
    // e anunciar antes dele é descrever o que ainda não está lá. Este
    // callback não agenda quadro nenhum: ele pega carona no que já está em
    // construção.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Rede, e não a trave. Quem impede de fato o anúncio atrasado é o
      // `cancel` do [dispose]: sem ele, o relógio acorda uma casca que já
      // saiu da árvore. Este `mounted` cobre a janela entre o quadro e o
      // callback, que o desenho atual não consegue abrir — fica pelo que
      // custa, que é nada.
      if (!mounted) return;
      SemanticsService.sendAnnouncement(
        View.of(context),
        kTituloDaEsperaEstourada,
        Directionality.maybeOf(context) ?? TextDirection.ltr,
      );
    });
  }

  void _tentarDeNovo() {
    setState(() {
      _esperaEstourou = false;
      _jaAnunciouOEstouro = false;
    });
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
        _anunciarAEsperaEstourada();
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

  Widget _splash() => SplashOficialScreen(
    // A chave amarra o estado da splash a ESTA instância: sem ela, sair do ramo
    // de espera e voltar recriaria a animação do zero.
    key: const ValueKey('splash-da-casca'),
    habilitarSom: widget.somNaSplash,
    duracao: widget.duracaoDaSplash ?? const Duration(milliseconds: 3800),
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
        // DECORAÇÃO, E SÓ. A ampulheta repete em desenho o que o título e a
        // mensagem já dizem por escrito. Dentro da árvore ela vira a palavra
        // "ampulheta" na frente de uma frase que não pediu por ela — e quem
        // ouve não tem como saber que aquilo era enfeite.
        const ExcludeSemantics(
          child: Text('⏳', style: TextStyle(fontSize: 40)),
        ),
        const SizedBox(height: 14),
        // O TÍTULO É CABEÇALHO, E É O ÚNICO. Marcar a mensagem também faria o
        // salto entre cabeçalhos parar duas vezes dentro do mesmo estado, que
        // para quem navega assim é o mesmo que não haver cabeçalho nenhum.
        Semantics(
          header: true,
          child: const Text(
            kTituloDaEsperaEstourada,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFFF6E2A6),
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
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
        // Mesma decoração, mesma razão do estado acima.
        const ExcludeSemantics(
          child: Text('⚠️', style: TextStyle(fontSize: 40)),
        ),
        const SizedBox(height: 14),
        // Aqui NÃO há anúncio: este estado é o primeiro quadro da rota, e não
        // uma troca sob os pés de quem já estava lendo. O leitor de tela já
        // anuncia a rota que abre; um `announce` por cima seria a mesma
        // informação dita duas vezes.
        Semantics(
          header: true,
          child: Text(
            titulo,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFFF6E2A6),
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
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
              // UMA UNIDADE, E NÃO TRÊS TEXTOS SOLTOS NO MEIO DA ROTA. O
              // container dá começo e fim ao estado; `explicitChildNodes` é o
              // que impede esse container de achatar os filhos num rótulo só —
              // achatado, o botão perderia o papel, o estado e a ação junto.
              child: Semantics(
                container: true,
                explicitChildNodes: true,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: children,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
