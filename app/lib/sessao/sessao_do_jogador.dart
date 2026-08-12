// sessao_do_jogador.dart — o DONO do estado canônico de identidade pública.
//
// ---------------------------------------------------------------------------
// QUEM DISPARA A CHAMADA, E POR QUE NÃO É UMA TELA
// ---------------------------------------------------------------------------
//
// A OS §16 proíbe que a existência da identidade seja efeito colateral do
// `initState` de alguma tela — e proíbe também a "solução" de mudar esse
// `initState` de lugar (splash, lobby, menu, widget raiz). O problema nunca foi
// QUAL tela chamava; era não haver ninguém explicitamente responsável.
//
// Aqui há. Este controller assina o fluxo de autenticação e trata a TRANSIÇÃO
// PARA SESSÃO AUTENTICADA como o gatilho. A responsabilidade está modelada, não
// espalhada: quem manda carregar é a camada de sessão, porque é ela quem sabe
// que uma sessão começou.
//
// Consequência direta, e é o objetivo da OS: abrir o Ranking não é pré-condição
// de nada. Ranking, Perfil, Social e Descoberta apenas LEEM [estado].
//
// ---------------------------------------------------------------------------
// AS QUATRO TRAVAS
// ---------------------------------------------------------------------------
//
// 1. DEDUPLICAÇÃO (§9). Uma requisição em voo é compartilhada. Três telas
//    pedindo identidade ao mesmo tempo produzem UMA chamada.
//
// 2. GERAÇÃO (§7.3, §9). Todo troca-de-sessão incrementa `_geracao`. Uma
//    resposta carrega a geração em que nasceu e é DESCARTADA se chegar depois
//    de a sessão ter virado. É o que impede a resposta atrasada do jogador A de
//    contaminar a sessão do jogador B.
//
// 3. CACHE DE SESSÃO, EM MEMÓRIA APENAS (§8). Uma vez carregada, a identidade
//    não é reconsultada por navegação. Não há SharedPreferences, SQLite, Hive
//    nem arquivo: uma segunda fonte de verdade precisaria de uma política de
//    invalidação que esta OS não especifica, e a memória do processo morre
//    junto com a sessão — que é exatamente a validade que se quer.
//
// 4. SEM RETRY POR REBUILD (§10, §20). [garantirCarregada] age SÓ a partir de
//    `naoCarregada`. Depois de uma falha ela é inerte: só [recarregar], que
//    nasce de um gesto explícito, tenta de novo. É por isso que um widget em
//    loop de reconstrução não vira tempestade de chamadas à Function.

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'fonte_identidade.dart';
import 'identidade_publica_sessao.dart';

/// Estado canônico da identidade pública do jogador autenticado.
///
/// UM POR APP. É o objeto que Ranking, Perfil, Social e Descoberta compartilham
/// — a convergência de §12 não é convenção, é o fato de só existir esta
/// instância pendurada na raiz (ver `escopo_sessao.dart`).
class SessaoDoJogador extends ChangeNotifier {
  /// [uids] é o fluxo de autenticação: o UID de quem está logado, ou `null`.
  /// Em produção vem de `FirebaseAuth.authStateChanges()`; nos testes vem de um
  /// `StreamController`, que é o que torna logout e troca A→B encenáveis.
  ///
  /// [uidInicial] cobre o caso de o app subir com sessão já restaurada, quando
  /// o stream ainda não emitiu.
  SessaoDoJogador({
    required FonteDeIdentidade fonte,
    required Stream<String?> uids,
    String? uidInicial,
  }) : _fonte = fonte {
    if (uidInicial != null) {
      // Estado montado à mão, sem passar por `_aplicarSessao`: o carregamento
      // fica para o microtask abaixo. Disparar dentro do construtor notificaria
      // uma plateia que ainda não teve como se inscrever.
      _geracao++;
      _estado = EstadoIdentidadeSessao.naoCarregada(uidInicial);
    }
    _assinatura = uids.listen(_aplicarSessao);
    if (uidInicial != null) scheduleMicrotask(garantirCarregada);
  }

  final FonteDeIdentidade _fonte;
  late final StreamSubscription<String?> _assinatura;

  EstadoIdentidadeSessao _estado = EstadoIdentidadeSessao.deslogado;

  /// Incrementado a cada troca de sessão. Uma resposta só é aceita se a geração
  /// em que ela nasceu ainda for a corrente.
  int _geracao = 0;

  /// A requisição em voo, compartilhada por todos os interessados.
  Future<void>? _emVoo;

  bool _descartado = false;

  /// A fotografia atual. Imutável — quem lê não consegue alterar.
  EstadoIdentidadeSessao get estado => _estado;

  /// Atalho de leitura. `null` quando não há identidade resolvida; NUNCA o uid.
  String? get publicId => _estado.publicId;

  /// Quantas chamadas a `obterMinhaIdentidade` já saíram deste controller.
  ///
  /// Existe para os testes de deduplicação (§18-F), de cache (§18-G) e de
  /// rebuild (§20) poderem afirmar um NÚMERO, e não só um comportamento. Um
  /// teste que diz "não houve tempestade" sem contar chamadas não prova nada.
  int get chamadasEmitidas => _chamadas;
  int _chamadas = 0;

  // -------------------------------------------------------------------------
  // Ciclo de vida da sessão
  // -------------------------------------------------------------------------

  /// Login, logout e troca de usuário entram todos por aqui.
  void _aplicarSessao(String? uid, {bool notificar = true}) {
    if (_descartado) return;
    // Reemissão do mesmo uid (o stream de auth repete em refresh de token) não
    // é troca de sessão: invalidar aqui jogaria fora um cache válido e faria
    // cada renovação de token virar uma chamada nova.
    if (uid == _estado.uid && _geracao > 0) return;

    // A INVALIDAÇÃO É INCONDICIONAL e vem ANTES de qualquer coisa: a geração
    // sobe, o voo é solto e o estado é substituído. Nenhum resquício do jogador
    // anterior sobrevive a esta linha — nem identidade, nem publicId, nem a
    // promessa em andamento.
    _geracao++;
    _emVoo = null;
    _estado = uid == null
        ? EstadoIdentidadeSessao.deslogado
        : EstadoIdentidadeSessao.naoCarregada(uid);

    if (notificar) notifyListeners();
    // O GATILHO: uma sessão autenticada começou, então a identidade é buscada.
    // Não é uma tela pedindo; é a sessão se completando.
    if (uid != null) garantirCarregada();
  }

  // -------------------------------------------------------------------------
  // Obtenção
  // -------------------------------------------------------------------------

  /// Garante que a identidade da sessão corrente esteja sendo (ou já tenha
  /// sido) obtida. Idempotente e segura para chamar de qualquer consumidor.
  ///
  /// É INERTE em quatro situações, e cada uma é uma exigência da OS:
  ///   * sessão não autenticada — não há o que buscar;
  ///   * identidade já disponível — §8, cache de sessão;
  ///   * requisição em voo — §9, deduplicação (devolve a MESMA future);
  ///   * falha anterior — §10 e §20, para que rebuild não vire retry.
  ///     Depois de falhar, só [recarregar] tenta de novo.
  Future<void> garantirCarregada() {
    if (_descartado) return Future<void>.value();
    final emVoo = _emVoo;
    if (emVoo != null) return emVoo;
    if (_estado.fase != FaseIdentidade.naoCarregada) {
      return Future<void>.value();
    }
    return _disparar();
  }

  /// Tentativa explícita, nascida de um gesto do jogador ("tentar de novo").
  ///
  /// Diferente de [garantirCarregada], age a partir de [FaseIdentidade.falha].
  /// Continua deduplicada: apertar o botão duas vezes não abre duas chamadas —
  /// §18-L pede exatamente que o retry não deixe duas requisições concorrentes.
  Future<void> recarregar() {
    if (_descartado || !_estado.autenticado) return Future<void>.value();
    final emVoo = _emVoo;
    if (emVoo != null) return emVoo;
    return _disparar();
  }

  Future<void> _disparar() {
    final uid = _estado.uid;
    if (uid == null) return Future<void>.value();

    // A geração é CAPTURADA AGORA, antes do await. É o crachá da resposta.
    final geracao = _geracao;
    _estado = EstadoIdentidadeSessao.carregando(uid);
    notifyListeners();

    _chamadas++;
    final voo = _executar(uid, geracao);
    _emVoo = voo;
    return voo;
  }

  Future<void> _executar(String uid, int geracao) async {
    EstadoIdentidadeSessao resultado;
    try {
      final identidade = await _fonte.obterMinhaIdentidade();
      resultado = EstadoIdentidadeSessao.disponivel(uid, identidade);
    } on FalhaIdentidade catch (e) {
      resultado = EstadoIdentidadeSessao.falhou(uid, e);
    } catch (e) {
      // Uma fonte que escapa do contrato não pode derrubar a sessão inteira
      // (§10). Vira falha de domínio, tratada como transitória.
      resultado = EstadoIdentidadeSessao.falhou(
        uid,
        FalhaIdentidade(MotivoFalhaIdentidade.desconhecida, '$e'),
      );
    }

    // A TRAVA DA RESPOSTA ATRASADA (§9, §18-J). Entre o disparo e este ponto
    // pode ter havido logout e login de outra pessoa. Se a geração virou, esta
    // resposta pertence a uma sessão que não existe mais: ela é DESCARTADA sem
    // tocar o estado e sem notificar ninguém.
    //
    // Note que nem o `_emVoo` é limpo neste caminho: ele já foi substituído (ou
    // anulado) por `_aplicarSessao`, e limpá-lo aqui apagaria o voo da sessão
    // NOVA — que é o mesmo vazamento por outra porta.
    if (_descartado || geracao != _geracao) return;

    _emVoo = null;
    _estado = resultado;
    notifyListeners();
  }

  @override
  void dispose() {
    _descartado = true;
    _assinatura.cancel();
    super.dispose();
  }
}
