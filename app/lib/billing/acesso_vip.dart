// acesso_vip.dart — o PORTAO do cliente. A unica coisa que a interface pode
// perguntar antes de mostrar, abrir ou liberar qualquer coisa paga.
//
// O DEFEITO QUE ESTE ARQUIVO EXISTE PARA FECHAR
//
// `entitlement.dart` ja respondia corretamente "este jogador tem VIP agora?", e
// `entitlement_repositorio.dart` ja lia a unica fonte autoritativa. O que faltava
// era o caminho ENTRE os dois e a tela: cada host de `main.dart` carregava o
// proprio booleano local, nascido de uma `VM.mock()`, e um deles chegava a ligar
// esse booleano no clique de "Assinar". O dominio estava certo e a porta estava
// aberta.
//
// A correcao nao e espalhar `EntitlementRepositorio` por cada host. E ter UM
// portao, por sessao, que todos consultam — e que nao tem nenhum metodo capaz de
// conceder acesso. Procurar por um `set` aqui e a maneira mais rapida de
// verificar isso: nao existe. O unico jeito de [AcessoVip.liberado] responder
// `true` e um documento de `playerEntitlements/{uid}`, escrito pelo backend,
// chegar pela fonte e estar VIGENTE contra o relogio.
//
// POR QUE A SITUACAO E RECALCULADA A CADA LEITURA, E NAO GUARDADA
//
// [EntitlementVip.vigenteEm] e uma pergunta TEMPORAL. Se o portao guardasse
// `liberado: true` no instante em que o documento chegou, um direito que vence
// com o jogador dentro da tela continuaria liberado ate algum evento novo passar
// por aqui — e o evento pode nao vir: expiracao nao gera escrita no Firestore no
// segundo exato do vencimento. Por isso [atual] recomputa contra o relogio toda
// vez que e lido. O portao guarda FATOS (uid, documento, se a leitura falhou) e
// nunca guarda o VEREDITO.
//
// TUDO FALHA FECHADO. Sem sessao, documento ainda nao chegado, leitura com erro,
// documento de outro uid: todos respondem bloqueado. As situacoes sao
// DISTINGUIVEIS ([SituacaoVip]) porque a interface precisa dizer coisas
// diferentes — "carregando" nao e "assine agora" —, mas nenhuma delas concede.
library;

import 'dart:async';

import '../elegibilidade/entitlement.dart';

/// De onde o portao le o direito de um jogador.
///
/// E uma funcao, e nao o `EntitlementRepositorio` concreto, porque o portao e
/// Dart puro e precisa ser exercitavel sem Firebase — a mesma fronteira que
/// `loja_play.dart` traca para o plugin da Play. Em producao quem passa isto e
/// `EntitlementRepositorio.observar`.
typedef FonteEntitlement = Stream<EntitlementVip> Function(String uid);

/// O relogio da operacao, em UTC. Injetado pela mesma razao de
/// `moderacao/sancao.dart`: uma tela inteira precisa enxergar o mesmo instante.
typedef RelogioVip = DateTime Function();

/// Em que pe esta o direito VIP do jogador da sessao.
///
/// Cinco situacoes e nao um booleano porque a interface precisa distinguir
/// "ainda nao sei" de "sei que nao" — a diferenca entre um spinner e um convite
/// para assinar. Nenhuma delas, exceto [liberado], concede coisa alguma.
enum SituacaoVip {
  /// Ha sessao, mas o documento autoritativo ainda nao chegou.
  ///
  /// NAO liberar aqui e o que impede o flicker que a OS proibe: a tela VIP
  /// aparecendo por um quadro antes de a consulta responder.
  carregando,

  /// Nao ha jogador logado. Nem existe documento para consultar.
  semSessao,

  /// O documento chegou e o direito esta VIGENTE contra o relogio.
  /// A unica situacao que libera.
  liberado,

  /// O documento chegou e nao concede: nunca comprou, expirou, foi revogado,
  /// esta em espera, pausado ou pendente. [AcessoVip.entitlement] carrega o
  /// detalhe para a tela poder explicar qual dos casos e.
  semDireito,

  /// A consulta falhou (rede, permissao, Firestore fora do ar).
  ///
  /// Separado de [semDireito] de proposito: erro nao e ausencia de direito, e a
  /// tela deve oferecer "tentar de novo" em vez de "assine". Bloqueia do mesmo
  /// jeito — erro nunca vira acesso.
  erro,
}

/// O retrato do direito VIP no cliente, ja decidido.
///
/// Imutavel e sem construtor publico que aceite [SituacaoVip.liberado] a partir
/// de um booleano solto: quem produz isto e [PortaoVip], a partir de um
/// documento do backend.
class AcessoVip {
  const AcessoVip._({
    required this.situacao,
    this.uid,
    this.entitlement,
  });

  /// O estado inicial de qualquer sessao: nao se sabe ainda, e por isso nao
  /// libera.
  const AcessoVip.indefinido()
      : situacao = SituacaoVip.carregando,
        uid = null,
        entitlement = null;

  final SituacaoVip situacao;

  /// De QUEM e este retrato. `null` sem sessao.
  ///
  /// Existe para que um consumidor consiga afirmar que o acesso que ele esta
  /// usando pertence ao jogador que esta na tela — a invariante do caso "B nao
  /// herda o VIP de A".
  final String? uid;

  /// O documento como ele chegou. `null` enquanto nao chegou, ou quando a
  /// leitura falhou. Serve para a tela explicar o motivo; nao serve para
  /// decidir — quem decide e [liberado].
  final EntitlementVip? entitlement;

  /// PODE liberar recurso VIP?
  ///
  /// Esta e a unica pergunta que a interface faz. Um `== SituacaoVip.liberado`
  /// e nao uma combinacao de negacoes: se um estado novo for acrescentado a
  /// [SituacaoVip] amanha, ele nasce BLOQUEADO, que e o padrao seguro.
  bool get liberado => situacao == SituacaoVip.liberado;

  /// O par legivel de [liberado], para as telas que so precisam barrar.
  bool get bloqueado => !liberado;

  /// A consulta ainda esta em curso? A tela pode mostrar espera em vez de
  /// oferecer assinatura.
  bool get carregando => situacao == SituacaoVip.carregando;

  /// Faz sentido oferecer o fluxo de assinatura agora?
  ///
  /// So quando se SABE que nao ha direito. Durante carregamento, erro ou
  /// ausencia de sessao, empurrar a loja seria pedir para o jogador comprar de
  /// novo algo que ele talvez ja tenha.
  bool get podeOferecerAssinatura => situacao == SituacaoVip.semDireito;

  @override
  String toString() =>
      'AcessoVip(${situacao.name}, uid: $uid, '
      'entitlement: ${entitlement?.estado.wire})';
}

/// Observa `playerEntitlements/{uid}` da sessao corrente e responde, a qualquer
/// instante, se o jogador pode usar recurso VIP.
///
/// NAO TEM METODO QUE CONCEDA. [usarSessao] troca de quem e a pergunta;
/// [encerrar] desliga. Nenhum dos dois consegue produzir [SituacaoVip.liberado]
/// — isso so acontece quando um documento vigente chega pela [FonteEntitlement].
class PortaoVip {
  PortaoVip({
    required FonteEntitlement fonte,
    RelogioVip? relogio,
  })  : _fonte = fonte,
        _relogio = relogio ?? _agoraUtc;

  static DateTime _agoraUtc() => DateTime.now().toUtc();

  final FonteEntitlement _fonte;
  final RelogioVip _relogio;

  final StreamController<AcessoVip> _mudancas =
      StreamController<AcessoVip>.broadcast();

  StreamSubscription<EntitlementVip>? _escuta;

  String? _uid;
  EntitlementVip? _documento;
  bool _falhou = false;
  bool _encerrado = false;

  /// Cada mudanca do retrato. E `broadcast` porque varias telas observam o
  /// mesmo portao ao mesmo tempo.
  ///
  /// A emissao acontece quando um FATO muda (sessao, documento, falha). A
  /// passagem do tempo nao emite evento — quem precisa da vigencia recomputada
  /// le [atual], que sempre reconsulta o relogio.
  Stream<AcessoVip> get mudancas => _mudancas.stream;

  /// O retrato AGORA, recalculado contra o relogio a cada leitura.
  AcessoVip get atual {
    if (_uid == null) {
      return const AcessoVip._(situacao: SituacaoVip.semSessao);
    }
    if (_falhou) {
      return AcessoVip._(situacao: SituacaoVip.erro, uid: _uid);
    }
    final doc = _documento;
    if (doc == null) {
      return AcessoVip._(situacao: SituacaoVip.carregando, uid: _uid);
    }
    // O documento tem que ser DO jogador da sessao. Um retrato remanescente de
    // outro uid nunca decide nada aqui — e a trava final do caso "B nao herda o
    // VIP de A", independente de a troca de escuta ter corrido bem.
    if (doc.uid != _uid) {
      return AcessoVip._(situacao: SituacaoVip.carregando, uid: _uid);
    }
    return AcessoVip._(
      situacao: doc.vigenteEm(_relogio())
          ? SituacaoVip.liberado
          : SituacaoVip.semDireito,
      uid: _uid,
      entitlement: doc,
    );
  }

  /// Passa a responder pelo jogador [uid]. `null` significa logout.
  ///
  /// O DESCARTE E IMEDIATO E VEM ANTES DE QUALQUER LEITURA NOVA. Entre o login
  /// de B e o primeiro evento da escuta de B existe um intervalo — `snapshots()`
  /// nao entrega de forma sincrona. Se o documento de A sobrevivesse a esse
  /// intervalo, B apareceria como VIP sem ter direito nenhum, que e exatamente o
  /// criterio de reprovacao 6 da OS. Por isso o estado cai para "carregando"
  /// (ou "sem sessao") no MESMO instante da troca.
  ///
  /// Chamar com o mesmo uid duas vezes nao reinicia a escuta: seria derrubar um
  /// direito ja conhecido e reabrir a janela de espera sem motivo.
  void usarSessao(String? uid) {
    if (_encerrado) return;
    if (uid == _uid) return;

    _escuta?.cancel();
    _escuta = null;
    _uid = uid;
    _documento = null;
    _falhou = false;

    if (uid != null) {
      _escuta = _fonte(uid).listen(
        (documento) {
          // A escuta anterior pode entregar um evento atrasado depois de a
          // sessao ter trocado. O uid capturado no fechamento decide se o
          // evento ainda interessa.
          if (_encerrado || _uid != uid) return;
          _documento = documento;
          _falhou = false;
          _publicar();
        },
        onError: (Object _) {
          if (_encerrado || _uid != uid) return;
          // Falha de leitura DERRUBA o direito conhecido. O caminho oposto —
          // manter o ultimo valor bom — deixaria um jogador cujo documento
          // acabou de ficar ilegivel continuar VIP por tempo indeterminado.
          // Duvida recusa, que e a regra do codebase inteiro.
          _documento = null;
          _falhou = true;
          _publicar();
        },
      );
    }

    _publicar();
  }

  /// Desliga o portao. Depois disto ele nao volta a conceder nada.
  ///
  /// E o que o logout dispara junto de `ServicoBilling.encerrar()`.
  Future<void> encerrar() async {
    if (_encerrado) return;
    _encerrado = true;
    await _escuta?.cancel();
    _escuta = null;
    _uid = null;
    _documento = null;
    _falhou = false;
    if (!_mudancas.isClosed) {
      _mudancas.add(atual);
      await _mudancas.close();
    }
  }

  void _publicar() {
    if (!_mudancas.isClosed) _mudancas.add(atual);
  }
}
