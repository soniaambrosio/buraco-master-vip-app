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

  /// A última fotografia boa de cada chave.
  final Map<_Chave, EstadoRanking> _cache = <_Chave, EstadoRanking>{};

  int _sequencia = 0;

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
  void aoMudarSessao(int geracao) {
    if (geracao == _geracao) return;
    _geracao = geracao;
    _ultimoPedido.clear();
    _emVoo.clear();
    _cache.clear();
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
      estado = EstadoRanking.daFalha(e.motivo);
    } catch (_) {
      // Exceção fora do vocabulário: é defeito, e defeito não vira ausência.
      // Sem `rethrow` de propósito — uma falha de ranking não pode derrubar a
      // tela que a pediu, e muito menos a casca em volta dela.
      estado = const EstadoRanking.falha();
    } finally {
      // Sai do voo mesmo quando a resposta será descartada: o próximo "tentar
      // de novo" precisa poder emitir uma chamada nova.
      //
      // Incondicional porque, por construção, só existe UM voo por chave: o
      // dedupe acima devolve o voo corrente em vez de abrir outro, e
      // [aoMudarSessao] esvazia o mapa inteiro. Não há voo alheio a preservar.
      _emVoo.remove(chave);
    }

    // AS DUAS GUARDAS, nesta ordem, e ANTES de qualquer escrita.
    //
    // A geração primeiro: se a sessão trocou, esta resposta é sobre outra
    // pessoa, e nem o cache pode recebê-la.
    if (geracaoDoPedido != _geracao) return null;
    // Depois a sequência: mesma sessão, mesma chave, mas já houve pedido mais
    // novo. A resposta é velha e não pode sobrescrever a mais recente — nem
    // quando a velha chega DEPOIS, que é o caso que ninguém encena e todo mundo
    // sofre.
    if (_ultimoPedido[chave] != numero) return null;

    // A invalidação por temporada vem DEPOIS das guardas de propósito: uma
    // resposta descartada não pode esvaziar o cache de quem está na tela. Já
    // aconteceu de uma resposta velha "limpar" dado bom a caminho do lixo.
    _invalidarPorTemporada(temporadaDaResposta);

    // Só fotografia boa entra no cache. Guardar falha faria o retry seguinte
    // mostrar o erro anterior como se fosse dado.
    if (estado.fase == FaseRanking.disponivel) {
      _cache[chave] = estado;
    }
    return estado;
  }

  /// A temporada virou: fotografias de outra temporada não valem mais.
  ///
  /// A virada só é perceptível quando uma resposta nova revela um
  /// `temporadaId` diferente — o cliente não tem calendário, e inventar um
  /// seria a mesma classe de erro que inventar liga. Quando ela aparece, tudo
  /// que era de outra temporada sai do cache de uma vez, para que nenhuma tela
  /// combine a liga de uma temporada com a colocação de outra.
  void _invalidarPorTemporada(String? temporadaId) {
    if (temporadaId == null) return;
    _cache.removeWhere(
      (_, estado) =>
          estado.temporadaId != null && estado.temporadaId != temporadaId,
    );
  }
}
