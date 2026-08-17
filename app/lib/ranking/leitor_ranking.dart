// leitor_ranking.dart — quem pergunta o ranking, e quem decide se a resposta
// ainda vale quando ela chega.
//
// ---------------------------------------------------------------------------
// O PROBLEMA QUE ESTE ARQUIVO RESOLVE NÃO É "CHAMAR A CALLABLE"
// ---------------------------------------------------------------------------
//
// Chamar é uma linha. O que custa é o intervalo entre a pergunta e a resposta,
// porque nele o mundo muda:
//
//   - a pessoa sai da conta;
//   - a pessoa troca de conta;
//   - ela abre o perfil de outro jogador, e depois de um terceiro;
//   - ela aperta "tentar de novo" três vezes;
//   - a temporada vira.
//
// Uma resposta que chega depois de qualquer um desses eventos está CORRETA para
// uma pergunta que ninguém está mais fazendo. Aplicá-la é como o defeito do
// Bronze, só que pior: em vez de um valor inventado, um valor verdadeiro sobre
// a pessoa errada.
//
// Por isso este leitor devolve `EstadoRanking?`, e o `null` NÃO é "sem
// ranking" — sem ranking é `EstadoRanking.indisponivel`, que é um valor. O
// `null` quer dizer DESCARTE: esta resposta perdeu a validade, não a aplique,
// e não mexa no que está na tela. Quem chama trata `null` não fazendo nada, que
// é a única reação correta.
//
// ---------------------------------------------------------------------------
// DUAS PROTEÇÕES POR CHAVE, E UMA GLOBAL
// ---------------------------------------------------------------------------
//
// Geração e número de pedido protegem CADA CHAVE do próprio passado. Elas não
// bastam, e a homologação independente mostrou por quê: com duas chaves em voo
// e uma virada de temporada no meio, cada resposta é, na sua própria chave, a
// mais recente — e mesmo assim uma delas fala de um mundo que acabou. A
// resposta vencida era devolvida como atual e ainda despejava do cache a
// fotografia boa da temporada nova.
//
// A terceira guarda é GLOBAL e mora em [_aceitarTemporada]. Ela não ordena
// `temporadaId` — o cliente não tem como saber qual identificador é mais novo,
// e fingir que sabe seria a mesma classe de erro que inventar liga. O que ele
// sabe é a ordem em que perguntou.
//
// ---------------------------------------------------------------------------
// O QUE ELE NÃO FAZ
// ---------------------------------------------------------------------------
//
// Não interpreta. A tradução de fotografia e de falha para `EstadoRanking` mora
// em `estado_ranking.dart`, e é de lá que sai toda decisão sobre o que se pode
// afirmar. Este arquivo cuida de identidade, ordem e validade — nada mais.
//
// Não registra nada. Nem uid, nem publicId, nem payload, nem token: um leitor
// de ranking não é lugar de diagnóstico, e um `print` com identificador de
// jogador é vazamento com outro nome.

import 'estado_ranking.dart';
import 'ranking_transporte.dart';

/// De quem é a fotografia pedida.
///
/// A distinção é de AUTORIDADE, e não de conveniência: o próprio jogador vem de
/// `abrirRanking`, que tira a identidade do contexto autenticado, e um terceiro
/// vem de `consultarJogadorPorIdPublico`, que recebe um id. Guardar os dois sob
/// a mesma chave deixaria a fotografia de um visitado sobrescrever a do dono.
enum _Alvo { proprio, publico }

/// A chave de uma fotografia em cache.
///
/// É a conta autenticada MAIS o alvo. As duas partes são obrigatórias: só o
/// alvo deixaria a fotografia do jogador A visível para B (mesma chave,
/// jogadores diferentes), e só a conta juntaria o perfil próprio com o de um
/// visitado.
class _Chave {
  const _Chave(this.contaPublicId, this.alvo, this.alvoPublicId);

  /// O `publicId` de quem está logado. É o que impede vazamento entre contas.
  final String contaPublicId;
  final _Alvo alvo;

  /// O `publicId` consultado. Igual ao da conta quando o alvo é o próprio.
  final String alvoPublicId;

  @override
  bool operator ==(Object outro) =>
      outro is _Chave &&
      outro.contaPublicId == contaPublicId &&
      outro.alvo == alvo &&
      outro.alvoPublicId == alvoPublicId;

  @override
  int get hashCode => Object.hash(contaPublicId, alvo, alvoPublicId);
}

/// Lê o ranking real e protege o resultado contra o tempo.
class LeitorDeRanking {
  LeitorDeRanking({required TransporteRanking transporte})
    : _transporte = transporte;

  final TransporteRanking _transporte;

  /// A geração de sessão que este leitor considera atual.
  ///
  /// Espelha `SessaoDoJogador.geracao`, e é ela que torna logout e troca de
  /// conta observáveis aqui sem que o leitor precise assinar a sessão — quem
  /// assina é a casca, que já assinava.
  int _geracao = 0;

  /// O último pedido emitido por chave. Só o mais recente tem direito de
  /// responder; os anteriores viram descarte quando chegam.
  ///
  /// POR CHAVE, e não global: duas consultas simultâneas a `publicId`
  /// diferentes são pedidos legítimos e concorrentes, e um contador único faria
  /// a segunda cancelar a primeira sem motivo.
  final Map<_Chave, int> _ultimoPedido = <_Chave, int>{};

  /// Pedidos em voo, para que apertar "tentar de novo" três vezes não abra três
  /// chamadas. O retry é idempotente por isto, e não por sorte de timing.
  final Map<_Chave, Future<EstadoRanking?>> _emVoo =
      <_Chave, Future<EstadoRanking?>>{};

  /// O número do pedido dono do voo corrente de cada chave.
  ///
  /// Existe para que um voo que termina só retire do mapa o SEU voo. Depois de
  /// [aoMudarSessao] — que esvazia `_emVoo` — pode haver dois voos vivos na
  /// mesma chave: o velho, órfão, e o novo. Sem esta marca, o velho ao terminar
  /// removia a entrada do NOVO, e o próximo toque abria uma chamada a mais.
  final Map<_Chave, int> _donoDoVoo = <_Chave, int>{};

  /// A última fotografia boa de cada chave.
  final Map<_Chave, EstadoRanking> _cache = <_Chave, EstadoRanking>{};

  int _sequencia = 0;

  /// A temporada que este leitor aceita como vigente, e a BARREIRA que protege
  /// essa decisão.
  ///
  /// ---------------------------------------------------------------------
  /// POR QUE UM NÚMERO DE PEDIDO, E NÃO O `temporadaId` SOZINHO
  /// ---------------------------------------------------------------------
  ///
  /// A pergunta "T1 ou T2 é mais nova?" não tem resposta no cliente.
  /// `temporadaId` é opaco: comparar `'T-2026-01'` com `'T-2026-02'` por ordem
  /// de string funcionaria hoje e mentiria no dia em que a autoridade emitisse
  /// `'verao'` e `'inverno'`, ou um ULID, ou qualquer coisa que não ordene. E
  /// aceitar como mais nova a última resposta que CHEGOU é justamente o defeito:
  /// resposta atrasada chega por último e não é a mais nova.
  ///
  /// O que o cliente sabe com certeza é a ordem em que ELE PERGUNTOU.
  ///
  /// ---------------------------------------------------------------------
  /// E POR QUE A BARREIRA NÃO É O PEDIDO QUE ESTABELECEU
  /// ---------------------------------------------------------------------
  ///
  /// Foi, e vazava. Guardando o número do pedido que estabeleceu a temporada, a
  /// barreira ficava presa lá atrás e QUALQUER pedido de número maior podia
  /// derrubá-la — inclusive um que já estava em voo junto com ele. A ordem
  /// inversa mostra o buraco: pedidos #1 e #2 nascem juntos, o servidor atende
  /// #1 depois da virada (T2, barreira em 1) e #2 antes (T1); como `2 < 1` é
  /// falso, a notícia velha passava.
  ///
  /// Pedidos contemporâneos não se ordenam entre si. O cliente sabe quando
  /// EMITIU cada um, mas não em que ordem o servidor os atendeu — e supor que o
  /// de número maior viu o mundo mais novo é a mesma classe de erro que supor
  /// que o último a chegar é o mais recente.
  ///
  /// Então a barreira é `_sequencia` NO INSTANTE EM QUE A TEMPORADA FOI
  /// APRENDIDA: todo pedido já emitido até ali é contemporâneo, e só um emitido
  /// depois — cujo número é necessariamente maior que essa marca — tem o
  /// direito de trocar a temporada aceita. Entre contemporâneos divergentes, o
  /// leitor mantém o que sabe e espera a próxima pergunta, que é sequencialmente
  /// posterior e resolve sozinha.
  ///
  /// "Aprendida" inclui CONFIRMADA. Uma resposta que repete a temporada vigente
  /// é notícia tão fresca quanto uma que a troca, e não reancorar nela era o
  /// segundo meio de a barreira ficar para trás.
  String? _temporadaAceita;
  int _barreiraTemporal = 0;

  /// Quantas chamadas de transporte foram realmente emitidas. Só diagnóstico de
  /// teste — nunca um número de produto.
  int get chamadasEmitidas => _chamadas;
  int _chamadas = 0;

  /// A sessão avançou: logout, troca de conta ou recarga que mudou a geração.
  ///
  /// Tudo o que estava em voo perde o direito de ser aplicado, e o cache vai
  /// junto. Descartar o cache aqui é o que garante que a fotografia de A não
  /// apareça em B nem por um frame — mesmo que B tenha, por acaso, o mesmo
  /// `publicId` num teste mal montado.
  /// A TEMPORADA ACEITA VAI JUNTO, e essa linha não é higiene: ela é o que
  /// impede a conta que entra de herdar a autoridade temporal da que saiu. Sem
  /// isso, um jogador cuja sessão anterior já vira T2 receberia a resposta
  /// legítima de T1 da conta nova e a descartaria como "vencida" — ficaria sem
  /// ranking nenhum, por um fato que não é sobre ele.
  void aoMudarSessao(int geracao) {
    if (geracao == _geracao) return;
    _geracao = geracao;
    _ultimoPedido.clear();
    _emVoo.clear();
    // Junto com `_emVoo`, e não depois: os voos órfãos deixam de ser donos de
    // coisa nenhuma, então o primeiro pedido da sessão nova é dono da chave
    // desde o instante em que nasce.
    _donoDoVoo.clear();
    _cache.clear();
    _temporadaAceita = null;
    _barreiraTemporal = 0;
  }

  /// A fotografia guardada para esta conta e alvo, se houver.
  ///
  /// Devolvida como DADO ANTERIOR: quem chama pode mostrá-la enquanto uma nova
  /// consulta corre, mas nunca como se a consulta tivesse dado certo.
  EstadoRanking? emCache({
    required String contaPublicId,
    String? alvoPublicId,
  }) => _cache[_chaveDe(contaPublicId, alvoPublicId)];

  /// O ranking do jogador autenticado.
  Future<EstadoRanking?> meuRanking({required String contaPublicId}) =>
      _ler(_chaveDe(contaPublicId, null), () => _transporte.meuRanking());

  /// O ranking de um jogador pelo id público.
  Future<EstadoRanking?> rankingPublico({
    required String contaPublicId,
    required String alvoPublicId,
  }) => _ler(
    _chaveDe(contaPublicId, alvoPublicId),
    () => _transporte.rankingPorIdPublico(alvoPublicId),
  );

  _Chave _chaveDe(String contaPublicId, String? alvoPublicId) =>
      alvoPublicId == null || alvoPublicId == contaPublicId
      ? _Chave(contaPublicId, _Alvo.proprio, contaPublicId)
      : _Chave(contaPublicId, _Alvo.publico, alvoPublicId);

  Future<EstadoRanking?> _ler(
    _Chave chave,
    Future<FotografiaRanking> Function() chamar,
  ) {
    // Dedupe: um pedido igual já está em voo, e a resposta dele serve para os
    // dois chamadores. É isto que torna o retry idempotente.
    final jaVoando = _emVoo[chave];
    if (jaVoando != null) return jaVoando;

    final geracaoDoPedido = _geracao;
    final numero = ++_sequencia;
    _ultimoPedido[chave] = numero;

    final voo = _executar(chave, numero, geracaoDoPedido, chamar);
    _emVoo[chave] = voo;
    _donoDoVoo[chave] = numero;
    return voo;
  }

  Future<EstadoRanking?> _executar(
    _Chave chave,
    int numero,
    int geracaoDoPedido,
    Future<FotografiaRanking> Function() chamar,
  ) async {
    _chamadas++;
    EstadoRanking estado;
    String? temporadaDaResposta;
    try {
      final foto = await chamar();
      estado = EstadoRanking.daFotografia(foto);
      temporadaDaResposta = foto.temporadaId;
    } on FalhaRanking catch (e) {
      // A PROVA DE SESSÃO VEM DA PRÓPRIA CHAVE. Este leitor só é consultado em
      // nome de uma conta, e a conta é o `publicId` que o chamador passou —
      // então "há sessão local" não é suposição, é o argumento recebido. Vazio
      // é o único caso em que não há conta a que pertencer, e é lá que
      // `sessaoInvalida` volta a ser uma afirmação verificável.
      estado = EstadoRanking.daFalha(
        e.motivo,
        haSessaoLocal: chave.contaPublicId.trim().isNotEmpty,
      );
    } catch (_) {
      // Exceção fora do vocabulário: é defeito, e defeito não vira ausência.
      // Sem `rethrow` de propósito — uma falha de ranking não pode derrubar a
      // tela que a pediu, e muito menos a casca em volta dela.
      estado = const EstadoRanking.falha();
    } finally {
      // Sai do voo mesmo quando a resposta será descartada: o próximo "tentar
      // de novo" precisa poder emitir uma chamada nova.
      //
      // SÓ O PRÓPRIO VOO. Era incondicional, e a suposição por trás disso —
      // "só existe um voo por chave" — é falsa depois de [aoMudarSessao]: ela
      // esvazia `_emVoo` sem cancelar o que está no ar, então o voo velho
      // continua vivo e, ao terminar, despejava do mapa o voo NOVO da mesma
      // chave. O dedupe furava e o toque seguinte abria uma chamada a mais.
      if (_donoDoVoo[chave] == numero) {
        _emVoo.remove(chave);
        _donoDoVoo.remove(chave);
      }
    }

    // AS TRÊS GUARDAS, nesta ordem, e ANTES de qualquer escrita.
    //
    // A geração primeiro: se a sessão trocou, esta resposta é sobre outra
    // pessoa, e nem o cache pode recebê-la.
    if (geracaoDoPedido != _geracao) return null;
    // Depois a sequência POR CHAVE: mesma sessão, mesma chave, mas já houve
    // pedido mais novo. A resposta é velha e não pode sobrescrever a mais
    // recente — nem quando a velha chega DEPOIS.
    if (_ultimoPedido[chave] != numero) return null;
    // E por último a temporada, que é GLOBAL. As duas de cima são por chave e
    // por sessão; nenhuma delas enxerga duas chaves em voo separadas por uma
    // virada de temporada, que era exatamente o buraco.
    if (!_aceitarTemporada(temporadaDaResposta, numero)) return null;

    // Só fotografia boa entra no cache. Guardar falha faria o retry seguinte
    // mostrar o erro anterior como se fosse dado.
    if (estado.fase == FaseRanking.disponivel) {
      _cache[chave] = estado;
    }
    return estado;
  }

  /// Decide se esta resposta ainda pertence ao presente.
  ///
  /// Devolve `false` para a resposta VENCIDA — a que fala de uma temporada
  /// diferente da aceita e nasceu de um pedido ANTERIOR ao que estabeleceu a
  /// aceita. Nesse caso ela não é devolvida, não entra no cache, não invalida
  /// nada e não muda a temporada aceita: uma notícia velha não tem o direito de
  /// apagar a nova, que era o segundo efeito do defeito.
  ///
  /// Devolve `true` nos três casos legítimos:
  ///
  ///   - `temporadaId` nulo — o contrato publica nulo em
  ///     `consultarJogadorPorIdPublico` quando não há temporada vigente. Isso é
  ///     ausência de notícia, e não notícia de virada: não estabelece, não
  ///     derruba e não invalida nada. Uma fotografia sem temporada também não
  ///     envenena o cache, porque não afirma temporada nenhuma;
  ///   - mesma temporada da aceita — vale mesmo vindo de outra chave e mesmo
  ///     chegando fora de ordem: não há nada de vencido nela;
  ///   - temporada diferente vinda de pedido POSTERIOR — é a virada de verdade.
  ///     Ela passa a ser a aceita, e só então as fotografias incompatíveis saem
  ///     do cache.
  bool _aceitarTemporada(String? temporadaId, int numero) {
    if (temporadaId == null) return true;

    // CONFIRMAÇÃO. Nada muda no que se sabe, mas a barreira avança: esta
    // resposta é notícia de agora, e tudo que estava em voo junto com ela passa
    // a ser contemporâneo dela, não posterior. Sem esta linha a barreira ficava
    // parada no primeiro estabelecimento, e era por onde a ordem inversa
    // entrava.
    if (temporadaId == _temporadaAceita) {
      _ancorar();
      return true;
    }

    // TROCA. Só quem foi emitido depois do último aprendizado pode fazê-la.
    // Estritamente maior: empatar com a barreira é ser contemporâneo, e
    // contemporâneo não é posterior.
    if (_temporadaAceita != null && numero <= _barreiraTemporal) return false;

    _temporadaAceita = temporadaId;
    _ancorar();
    // Fotografia SEM temporada fica: ela não afirma pertencer a nenhuma, então
    // não pode estar errada sobre esta.
    _cache.removeWhere(
      (_, estado) =>
          estado.temporadaId != null && estado.temporadaId != temporadaId,
    );
    return true;
  }

  /// Marca o instante em que a temporada foi aprendida.
  ///
  /// `_sequencia` é o número do ÚLTIMO pedido emitido até agora. Tudo com
  /// número menor ou igual já estava em voo neste instante — contemporâneo — e
  /// perde o direito de trocar a temporada. Quem vier depois terá número maior.
  ///
  /// `max` e não atribuição direta: uma resposta atrasada que apenas confirma a
  /// temporada é notícia válida, mas não pode PUXAR A BARREIRA PARA TRÁS e
  /// reabrir a janela que uma resposta mais nova já havia fechado.
  void _ancorar() {
    if (_sequencia > _barreiraTemporal) _barreiraTemporal = _sequencia;
  }
}
