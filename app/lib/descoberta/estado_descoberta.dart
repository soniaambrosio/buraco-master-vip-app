// estado_descoberta.dart — o guardião do retrato: geração, revisão e fase.
//
// ---------------------------------------------------------------------------
// O PROBLEMA QUE ESTE ARQUIVO RESOLVE
// ---------------------------------------------------------------------------
//
// Um retrato pedido pela rede volta quando volta. Numa conexão ruim, a resposta
// de dois pedidos atrás chega DEPOIS da resposta do último — e ela descreve um
// servidor que não existe mais. Aplicá-la faz a lista andar para trás: mesas
// que encheram voltam a ter vaga, mesas que sumiram reaparecem.
//
// A defesa não é "guardar a hora da resposta" (o relógio do aparelho não é
// autoridade sobre nada) nem "contar pedidos" (o cliente não sabe quantos o
// servidor respondeu). A defesa é a REVISÃO, que o servidor emite de uma
// sequência que só sobe.
//
// ---------------------------------------------------------------------------
// GERAÇÃO NÃO É REVISÃO, E COMPARAR AS DUAS É O ERRO CLÁSSICO
// ---------------------------------------------------------------------------
//
// A revisão vale dentro de UM processo do servidor. Se o servidor reinicia, ela
// volta a zero — e um cliente que só comparasse números descartaria para sempre
// tudo o que viesse do processo novo, porque `1 <= 4812`.
//
// Por isso o retrato carrega `geracao`, sorteada por processo. Geração
// diferente NÃO é comparação: é ordem de jogar fora o que se tinha e adotar o
// novo por inteiro.
//
// ---------------------------------------------------------------------------
// RECUSAR UMA ATUALIZAÇÃO NÃO É ESVAZIAR A LISTA
// ---------------------------------------------------------------------------
//
// Retrato inválido, atrasado ou de outro transporte é DESCARTADO — e o último
// retrato válido continua na tela. Substituí-lo por lista vazia diria à
// jogadora que não há mesas, quando o que houve foi uma resposta ruim. O que
// muda é o AVISO (`ultimaRecusa`), não o conteúdo.
//
// A única coisa que apaga o retrato é a sessão acabar: logout e troca de conta.
// Aí ele não é "velho", é DE OUTRA PESSOA.

import 'adaptador_descoberta.dart';
import 'modelo_descoberta.dart';

/// Em que estado a superfície está. Enumeração fechada — a tela decide o que
/// desenhar por `switch` exaustivo, e um estado novo quebra a compilação em vez
/// de cair num `else` silencioso.
enum FaseDaDescoberta {
  /// Ninguém pediu nada ainda (transporte não autenticado).
  ociosa,

  /// Primeiro pedido em voo, sem retrato nenhum para mostrar.
  carregando,

  /// Há retrato válido.
  disponivel,

  /// O transporte caiu e está voltando. O retrato anterior segue na tela,
  /// marcado como possivelmente velho.
  reconectando,

  /// O ciclo automático desistiu, ou o servidor recusou de forma terminal.
  servidorIndisponivel,

  /// Nunca chegou um retrato que passasse na fronteira.
  retratoInvalido,

  /// Logout ou troca de conta. Não há o que mostrar, e não pode haver.
  sessaoEncerrada,
}

/// Por que uma atualização foi descartada. `null` quando a última foi aceita.
enum MotivoDeDescarte {
  /// O adaptador recusou (esquema, tipo, campo proibido, incoerência...).
  retratoInvalido,

  /// Revisão igual ou menor, na mesma geração: chegou atrasada.
  revisaoAtrasada,

  /// Veio de um transporte que já não é o vigente.
  transporteAnterior,
}

/// Guarda o retrato vigente e decide o que entra.
///
/// Sem `ChangeNotifier` de propósito: quem notifica é o transporte, que é o
/// único dono de ciclo de vida aqui. Dois notificadores para o mesmo evento
/// fariam a tela reconstruir duas vezes por resposta.
class EstadoDaDescoberta {
  RetratoDaDescoberta? _retrato;
  FaseDaDescoberta _fase = FaseDaDescoberta.ociosa;
  bool _atualizando = false;
  MotivoDeDescarte? _ultimaRecusa;
  RecusaDeRetrato? _detalheDaRecusa;
  int _geracaoDeTransporte = 0;

  /// O retrato vigente, ou `null` quando não há nenhum válido.
  RetratoDaDescoberta? get retrato => _retrato;

  FaseDaDescoberta get fase => _fase;

  /// Há um pedido em voo. É isto que a tela usa para o "atualizando".
  bool get atualizando => _atualizando;

  /// Por que a ÚLTIMA atualização foi descartada. Não apaga o retrato.
  MotivoDeDescarte? get ultimaRecusa => _ultimaRecusa;

  /// Detalhe da recusa do adaptador, para log e teste.
  RecusaDeRetrato? get detalheDaRecusa => _detalheDaRecusa;

  /// A lista está vazia DE VERDADE: há retrato, e ele não tem mesa nenhuma.
  /// Diferente de "ainda não sei", que é `retrato == null`.
  bool get vazioReal => _retrato != null && _retrato!.mesas.isEmpty;

  /// Há mesas, e nenhuma aceita ingresso agora.
  bool get semIngressaveis =>
      _retrato != null && _retrato!.mesas.isNotEmpty && !_retrato!.temIngressavel;

  /// Total de pessoas no aplicativo, ou `null` quando ainda não se sabe.
  ///
  /// `null` NÃO É ZERO, e essa distinção é a razão de o tipo ser anulável: zero
  /// é uma afirmação ("não tem ninguém"), e desconhecido não é afirmação
  /// nenhuma. A Home omite a linha em vez de dizer que o aplicativo está vazio.
  int? get jogadoresOnlineTotal => _retrato?.presenca.jogadoresOnlineTotal;

  /// A geração de transporte que este estado considera vigente.
  int get geracaoDeTransporte => _geracaoDeTransporte;

  /// Chamado pelo transporte quando uma conexão nova é autenticada.
  ///
  /// Sobe a geração vigente, e com isso toda resposta ainda em voo da conexão
  /// anterior passa a ser descartável por [aplicar].
  void definirGeracaoDeTransporte(int geracao) {
    _geracaoDeTransporte = geracao;
  }

  /// Um pedido saiu.
  void marcarPedidoEmVoo() {
    _atualizando = true;
    if (_retrato == null && _fase != FaseDaDescoberta.sessaoEncerrada) {
      _fase = FaseDaDescoberta.carregando;
    }
  }

  /// Aplica (ou descarta) uma resposta `mesas` crua.
  ///
  /// [geracaoDeTransporte] é o crachá da conexão que recebeu a mensagem.
  /// Devolve `true` só quando o retrato entrou.
  bool aplicar(Object? bruto, {required int geracaoDeTransporte}) {
    _atualizando = false;

    // 1. TRANSPORTE. Resposta de uma conexão que já morreu não vale, mesmo que
    //    o conteúdo dela pareça novo — ela foi pedida por outra sessão.
    if (geracaoDeTransporte != _geracaoDeTransporte) {
      _ultimaRecusa = MotivoDeDescarte.transporteAnterior;
      _detalheDaRecusa = null;
      return false;
    }

    // 2. FRONTEIRA. Ou o retrato inteiro é construído, ou nada entra.
    final leitura = AdaptadorDaDescoberta.ler(bruto);
    final novo = leitura.retrato;
    if (novo == null) {
      _ultimaRecusa = MotivoDeDescarte.retratoInvalido;
      _detalheDaRecusa = leitura.recusa;
      if (_retrato == null) _fase = FaseDaDescoberta.retratoInvalido;
      return false;
    }

    // 3. ORDEM. Geração diferente substitui tudo; mesma geração só avança.
    final atual = _retrato;
    if (atual != null && atual.geracao == novo.geracao) {
      if (novo.revisao <= atual.revisao) {
        _ultimaRecusa = MotivoDeDescarte.revisaoAtrasada;
        _detalheDaRecusa = null;
        return false;
      }
    }

    _retrato = novo;
    _fase = FaseDaDescoberta.disponivel;
    _ultimaRecusa = null;
    _detalheDaRecusa = null;
    return true;
  }

  /// O transporte caiu e o ciclo automático está tentando voltar.
  void marcarReconectando() {
    _atualizando = false;
    _fase = FaseDaDescoberta.reconectando;
  }

  /// O ciclo automático desistiu, ou a falha é terminal.
  void marcarServidorIndisponivel() {
    _atualizando = false;
    _fase = FaseDaDescoberta.servidorIndisponivel;
  }

  /// Voltou a haver conexão autenticada, e ainda não chegou retrato novo.
  void marcarAguardandoRetrato() {
    if (_fase == FaseDaDescoberta.sessaoEncerrada) return;
    if (_retrato == null) {
      _fase = FaseDaDescoberta.carregando;
    } else {
      _fase = FaseDaDescoberta.disponivel;
    }
  }

  /// LOGOUT OU TROCA DE CONTA. Apaga tudo — é o único caminho que apaga.
  void encerrarSessao() {
    _retrato = null;
    _atualizando = false;
    _ultimaRecusa = null;
    _detalheDaRecusa = null;
    _fase = FaseDaDescoberta.sessaoEncerrada;
  }

  /// Volta ao estado de quem nunca pediu nada. Usado quando o transporte é
  /// desligado sem que a sessão tenha acabado.
  void limpar() {
    _retrato = null;
    _atualizando = false;
    _ultimaRecusa = null;
    _detalheDaRecusa = null;
    _fase = FaseDaDescoberta.ociosa;
  }
}
