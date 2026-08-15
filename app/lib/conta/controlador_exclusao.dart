// controlador_exclusao.dart — o DONO do fluxo de exclusão da própria conta.
//
// O fluxo mínimo que a OS pede é:
//
//     Configurações → Excluir minha conta → aviso → confirmação →
//     reautenticação quando necessária → execução backend → encerramento
//     da sessão
//
// Este arquivo é esse fluxo, inteiro, e é o único lugar onde ele existe. A tela
// não sabe a ordem; ela desenha [fase] e chama três métodos.
//
// ---------------------------------------------------------------------------
// POR QUE A REAUTENTICAÇÃO ENTRA COMO CALLBACK, E NÃO COMO IMPORT
// ---------------------------------------------------------------------------
//
// "Reautenticar" quer dizer coisas diferentes conforme o provedor: senha para
// e-mail, o fluxo da conta Google para Google Sign-In. A decisão de QUAL fluxo
// abrir é do host (main.dart), que já conhece `GoogleSignIn` e `FirebaseAuth`.
//
// Se este controlador importasse `firebase_auth`, ele deixaria de ser testável
// sem Firebase — e os casos que mais importam aqui (reautenticação vencida,
// falha parcial, chamada duplicada, o jogador desistindo no meio) são
// exatamente os que precisam ser encenados. Por isso as duas dependências
// externas entram como funções: [reautenticar] e [encerrarSessao].
//
// É a mesma razão pela qual `SessaoDoJogador` recebe um `Stream<String?>` em vez
// de chamar `FirebaseAuth.authStateChanges()` sozinho.
//
// ---------------------------------------------------------------------------
// A TRAVA QUE NÃO É ÓBVIA: UMA EXECUÇÃO DE CADA VEZ
// ---------------------------------------------------------------------------
//
// O backend aguenta chamada duplicada — o diário converge e nada é refeito. Mas
// aguentar não é motivo para provocar: dois toques no botão abririam duas
// chamadas de rede, e a segunda responderia `repeticao: true` no meio da
// primeira, fazendo a tela encerrar a sessão enquanto a outra ainda corre.
// [_emVoo] existe para que o segundo toque simplesmente não faça nada.

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'exclusao_de_conta.dart';
import 'fonte_exclusao.dart';

/// Onde o fluxo está. A tela desenha a partir disto e de mais nada.
enum FaseDaExclusao {
  /// Ainda não pedimos o resumo.
  inicial,

  /// Buscando o aviso no servidor.
  carregandoAviso,

  /// Aviso na tela, esperando o jogador digitar a confirmação.
  aguardandoConfirmacao,

  /// O servidor recusou ANTES de qualquer escrita (torneio em andamento, por
  /// exemplo). Estado próprio porque a tela mostra outra coisa: não é erro de
  /// rede, é uma pendência que o jogador resolve e volta.
  bloqueada,

  /// Pedindo a credencial de novo.
  reautenticando,

  /// Executando. IRREVERSÍVEL a partir da primeira etapa do backend.
  excluindo,

  /// Acabou. A sessão já foi encerrada.
  concluida,

  /// Falhou. [falha] diz por quê e se vale tentar de novo.
  falhou,
}

/// Pede a credencial de novo. `true` se a pessoa reautenticou.
///
/// `false` cobre os dois casos que dão no mesmo para o fluxo: ela cancelou, ou
/// o provedor recusou. Nenhum dos dois é erro a reportar — os dois significam
/// "não prossiga".
typedef ReautenticarJogador = Future<bool> Function();

/// Encerra a sessão local. Chamado UMA vez, depois de o backend confirmar.
typedef EncerrarSessao = Future<void> Function();

class ControladorDeExclusao extends ChangeNotifier {
  ControladorDeExclusao({
    required FonteDeExclusaoDeConta fonte,
    required ReautenticarJogador reautenticar,
    required EncerrarSessao encerrarSessao,
  }) : _fonte = fonte,
       _reautenticar = reautenticar,
       _encerrarSessao = encerrarSessao;

  final FonteDeExclusaoDeConta _fonte;
  final ReautenticarJogador _reautenticar;
  final EncerrarSessao _encerrarSessao;

  FaseDaExclusao _fase = FaseDaExclusao.inicial;
  ResumoDaExclusao? _resumo;
  FalhaExclusao? _falha;
  bool _descartado = false;
  Future<void>? _emVoo;

  FaseDaExclusao get fase => _fase;
  ResumoDaExclusao? get resumo => _resumo;
  FalhaExclusao? get falha => _falha;

  /// Quantas execuções saíram daqui. Existe para o teste do duplo toque poder
  /// afirmar um NÚMERO — "não houve duas chamadas" sem contar não prova nada.
  int get execucoesEmitidas => _execucoes;
  int _execucoes = 0;

  /// A palavra digitada confere com a que o servidor mandou?
  ///
  /// CONFERÊNCIA LOCAL DE CONVENIÊNCIA, e não de segurança. Serve para o botão
  /// só acender quando faz sentido; quem decide de verdade é o servidor, que
  /// confere de novo. Uma tela que confiasse só nisto seria contornada por um
  /// aplicativo modificado em dez minutos.
  bool confirmacaoConfere(String digitado) {
    final esperada = _resumo?.palavraDeConfirmacao ?? '';
    if (esperada.isEmpty) return false;
    return digitado.trim().toUpperCase() == esperada.toUpperCase();
  }

  // -------------------------------------------------------------------------
  // AVISO
  // -------------------------------------------------------------------------

  /// Busca o resumo. Idempotente: chamar duas vezes não abre duas requisições.
  Future<void> carregarAviso() {
    if (_descartado) return Future<void>.value();
    final emVoo = _emVoo;
    if (emVoo != null) return emVoo;
    if (_fase == FaseDaExclusao.excluindo || _fase == FaseDaExclusao.concluida) {
      return Future<void>.value();
    }

    _fase = FaseDaExclusao.carregandoAviso;
    _falha = null;
    notifyListeners();

    final voo = _carregar();
    _emVoo = voo;
    return voo;
  }

  Future<void> _carregar() async {
    try {
      final resumo = await _fonte.resumir();
      if (_descartado) return;
      _resumo = resumo;
      // A RECUSA DO SERVIDOR VENCE. Uma tela que mostrasse o botão mesmo com
      // `podeExcluir: false` levaria a pessoa a digitar a palavra para receber
      // um erro que já era conhecido antes de ela começar.
      _fase = resumo.podeExcluir
          ? FaseDaExclusao.aguardandoConfirmacao
          : FaseDaExclusao.bloqueada;
    } on FalhaExclusao catch (e) {
      if (_descartado) return;
      _falha = e;
      _fase = FaseDaExclusao.falhou;
    } catch (e) {
      if (_descartado) return;
      // Uma fonte que escapa do contrato não pode derrubar a tela.
      _falha = FalhaExclusao(MotivoFalhaExclusao.desconhecida, '$e');
      _fase = FaseDaExclusao.falhou;
    } finally {
      _emVoo = null;
      if (!_descartado) notifyListeners();
    }
  }

  // -------------------------------------------------------------------------
  // EXECUÇÃO
  // -------------------------------------------------------------------------

  /// Confirma e executa.
  ///
  /// A REAUTENTICAÇÃO É REATIVA, e não preventiva: só pedimos a credencial
  /// depois de o servidor dizer que precisa. Pedir antes, sempre, faria a pessoa
  /// digitar a senha duas vezes numa sessão recém-aberta — e a decisão sobre a
  /// janela é do servidor, não da tela.
  Future<void> confirmar(String digitado) {
    if (_descartado) return Future<void>.value();

    final emVoo = _emVoo;
    if (emVoo != null) return emVoo;

    if (_fase == FaseDaExclusao.concluida) return Future<void>.value();
    if (!confirmacaoConfere(digitado)) {
      _falha = const FalhaExclusao(
        MotivoFalhaExclusao.confirmacaoInvalida,
        'a palavra digitada não confere',
      );
      _fase = FaseDaExclusao.falhou;
      notifyListeners();
      return Future<void>.value();
    }

    _fase = FaseDaExclusao.excluindo;
    _falha = null;
    notifyListeners();

    final voo = _executar(digitado, jaReautenticou: false);
    _emVoo = voo;
    return voo;
  }

  Future<void> _executar(String confirmacao, {required bool jaReautenticou}) async {
    try {
      _execucoes++;
      final resultado = await _fonte.excluir(confirmacao: confirmacao);
      if (_descartado) return;

      // `repeticao: true` É SUCESSO. Acontece quando a rede caiu entre a
      // execução e a resposta: o backend já tinha terminado, e a segunda chamada
      // converge. Tratar como erro deixaria o jogador olhando uma falha de uma
      // conta que já não existe.
      if (resultado.concluida || resultado.repeticao) {
        await _encerrar();
        return;
      }

      _falha = const FalhaExclusao(
        MotivoFalhaExclusao.desconhecida,
        'o servidor respondeu sem concluir',
      );
      _fase = FaseDaExclusao.falhou;
    } on FalhaExclusao catch (e) {
      if (_descartado) return;

      if (e.motivo == MotivoFalhaExclusao.reautenticacaoNecessaria &&
          !jaReautenticou) {
        await _reautenticarERepetir(confirmacao);
        return;
      }

      _falha = e;
      _fase = FaseDaExclusao.falhou;
    } catch (e) {
      if (_descartado) return;
      _falha = FalhaExclusao(MotivoFalhaExclusao.desconhecida, '$e');
      _fase = FaseDaExclusao.falhou;
    } finally {
      _emVoo = null;
      if (!_descartado) notifyListeners();
    }
  }

  /// Pede a credencial e tenta UMA vez mais.
  ///
  /// UMA, e não em laço. Se a segunda tentativa também voltar
  /// `reautenticacaoNecessaria`, alguma coisa está errada de um jeito que o
  /// jogador não resolve apertando de novo — pode ser relógio do aparelho fora
  /// de hora, provedor devolvendo credencial velha, ou a janela do servidor
  /// curta demais. Um laço aqui viraria um pedido de senha infinito.
  Future<void> _reautenticarERepetir(String confirmacao) async {
    _fase = FaseDaExclusao.reautenticando;
    notifyListeners();

    bool reautenticou;
    try {
      reautenticou = await _reautenticar();
    } catch (e) {
      reautenticou = false;
    }
    if (_descartado) return;

    if (!reautenticou) {
      // Cancelar não é falha a reportar: é a pessoa desistindo. Ela volta para o
      // aviso, com a conta intacta.
      _falha = null;
      _fase = FaseDaExclusao.aguardandoConfirmacao;
      return;
    }

    _fase = FaseDaExclusao.excluindo;
    notifyListeners();
    await _executar(confirmacao, jaReautenticou: true);
  }

  /// Encerra a sessão e fecha o fluxo.
  ///
  /// A ORDEM É: backend confirma → sessão morre → fase vira concluída. Encerrar
  /// antes da confirmação deixaria o jogador deslogado de uma conta que continua
  /// existindo, sem saber o que aconteceu.
  ///
  /// A falha do `signOut` NÃO derruba o desfecho: a conta já foi apagada no
  /// servidor, e o token local que sobrou está morto de qualquer forma — a
  /// primeira chamada que ele tentar será recusada. Marcar como falha aqui faria
  /// a tela mentir sobre uma exclusão que aconteceu.
  Future<void> _encerrar() async {
    try {
      await _encerrarSessao();
    } catch (_) {
      // Deliberadamente engolido. Ver acima.
    }
    if (_descartado) return;
    _falha = null;
    _fase = FaseDaExclusao.concluida;
  }

  /// Volta do estado de falha para o aviso, para tentar de novo.
  void tentarDeNovo() {
    if (_descartado || _fase != FaseDaExclusao.falhou) return;
    _falha = null;
    _fase = _resumo == null
        ? FaseDaExclusao.inicial
        : FaseDaExclusao.aguardandoConfirmacao;
    notifyListeners();
  }

  @override
  void dispose() {
    _descartado = true;
    super.dispose();
  }
}
