// livro_de_efeitos_terminais.dart — o ciclo de vida do aviso de fim de partida.
//
// ===========================================================================
// RECEBER NÃO É CONSUMIR
// ===========================================================================
//
// A entrega anterior registrou um risco residual, e este arquivo é a resposta a
// ele. O livro dos efeitos terminais era um `Set<String>` de `eventoId`
// despachados, e "despachado" era anotado NO RECEBIMENTO — no mesmo gesto em
// que se descobria que o encerramento era novo. Enquanto houvesse consumidor
// montado, o resultado era o certo. Sem consumidor, não:
//
//   1. o servidor declara o fim enquanto a pessoa está fora da rota da mesa
//      (ou entre o `dispose` de um vínculo e o `didChangeDependencies` do
//      seguinte, que é uma janela real na troca de transporte);
//   2. o efeito é anotado como despachado e ninguém o apresenta;
//   3. a pessoa volta para a mesa. O retrato terminal está lá — a mesa diz
//      "Partida encerrada" —, mas o AVISO nunca acontece, e não acontece mais:
//      o reenvio pós-reconexão bate no livro e é engolido.
//
// O defeito não deixa rastro. Não há erro, não há log, não há teste vermelho:
// há um aviso que simplesmente não aparece, para uma fatia de gente que a
// bancada não reproduz.
//
// A correção é separar as duas perguntas que o `Set` respondia juntas:
//
//   "este fim já é conhecido?"     → impede efeito em duplicata
//   "este fim já foi APRESENTADO?" → impede repetição do diálogo
//
// ===========================================================================
// TRÊS SITUAÇÕES, E POR QUE SÃO TRÊS
// ===========================================================================
//
//   pendente      Chegou do servidor e ninguém o apresentou. É o estado em que
//                 um encerramento espera por consumidor — indefinidamente, se
//                 for preciso. Sobrevive à reconexão e à troca de transporte.
//
//   reivindicado  Um proprietário identificável assumiu a apresentação. Existe
//                 porque apresentar não é instantâneo: entre "vou apresentar" e
//                 "apresentei" cabe um quadro inteiro, e nesse intervalo chegam
//                 reconstruções, reenvios do servidor e trocas de transporte.
//                 Sem este estado, cada um deles abriria seu próprio diálogo.
//
//   apresentado   Fim de linha. Daqui não se volta: duplicata, rebuild,
//                 reconexão e ressubscrição não repetem o aviso.
//
// A transição que interessa é a que NÃO é de mão única: `reivindicado` volta a
// `pendente`. Reivindicar é uma promessa de apresentar, e uma promessa que não
// se cumpre — a rota morreu, o transporte virou, o apresentador não conseguiu
// inserir o diálogo — tem de devolver o efeito ao livro. É a diferença entre
// perder o aviso e adiá-lo.
//
// ===========================================================================
// POR QUE A POSSE É UM OBJETO, E NÃO UM `bool`
// ===========================================================================
//
// `confirmar` e `liberar` exigem a MESMA posse que reivindicou. Sem isso, um
// callback atrasado do vínculo anterior — que existe, e é o cenário que a suíte
// irmã já perseguia — confirmaria a apresentação que o vínculo ATUAL ainda está
// para fazer. O efeito iria para `apresentado` sem ninguém ter visto nada, que
// é o defeito original de volta por outra porta.
//
// A posse é opaca de propósito: nada se lê de dentro dela, e a única coisa que
// importa é ser diferente da anterior.
//
// ===========================================================================
// NADA AQUI É PERSISTIDO
// ===========================================================================
//
// O livro vive em memória, com a mesa. Não há Firestore, Firebase nem servidor
// nesta camada: o ciclo de vida de um aviso de interface é do cliente, e uma
// marca de "já apresentei" gravada fora dele descreveria uma sala que talvez
// nem exista mais. Quem apaga o livro é a saída da mesa (ou a virada de
// sessão), pelo mesmo motivo de sempre: a próxima mesa é outra partida.

/// O encerramento autoritativo, tal como o servidor o declarou.
///
/// Isto não é o desfecho calculado: o cliente não conta ponto, não concede
/// conquista e não pontua ranking. É só o aviso de que o servidor declarou a
/// partida encerrada, com o carimbo que permite a quem consome saber que já
/// tratou deste.
class EncerramentoAutoritativo {
  const EncerramentoAutoritativo({
    required this.versaoEstado,
    required this.eventoId,
    required this.visao,
  });

  /// O carimbo da emissão terminal. Nulos no modo legado — o servidor antigo
  /// não carimba, e inventar um número aqui seria fingir autoridade.
  final int? versaoEstado;
  final String? eventoId;

  /// A visão terminal, crua, como veio no envelope. Quem desenha continua
  /// passando pelo adaptador; isto é só o conteúdo do aviso.
  final Map<String, dynamic> visao;
}

/// Em que ponto do ciclo de vida um efeito terminal está. Ver o cabeçalho.
enum EstadoDoEfeito { pendente, reivindicado, apresentado }

/// A identidade de quem reivindica um efeito.
///
/// Objeto opaco e sem conteúdo. Não é `const` e não define `==`: a identidade
/// POR INSTÂNCIA é a característica inteira — uma posse nova tem de ser
/// diferente da anterior, e duas posses "iguais em conteúdo" seriam o mesmo
/// dono, que é justamente o que se quer distinguir.
final class PosseDoEfeito {
  PosseDoEfeito();
}

class _Efeito {
  _Efeito(this.aviso);

  final EncerramentoAutoritativo aviso;
  EstadoDoEfeito estado = EstadoDoEfeito.pendente;
  PosseDoEfeito? dono;
}

/// O livro dos efeitos terminais de UMA mesa.
///
/// Não é `ChangeNotifier` e não avisa ninguém. Ele responde perguntas e guarda
/// o que lhe contam; quem observa o transporte já notifica por outros motivos,
/// e um segundo canal de aviso aqui seria um segundo caminho pelo qual o efeito
/// poderia disparar.
class LivroDeEfeitosTerminais {
  /// A chave do modo legado.
  ///
  /// O servidor antigo não carimba, e é PROIBIDO fabricar um `eventoId` no
  /// cliente — um identificador inventado aqui teria a mesma cara de um do
  /// servidor e ninguém saberia distinguir. Sobra a única coisa verdadeira que
  /// se sabe: houve UM encerramento sem carimbo nesta mesa. Esta chave é o
  /// nome interno dele — privada, nunca exposta como `eventoId` e nunca posta
  /// no fio.
  ///
  /// A CADEIA VAZIA, e não um nome bonito: `OrdemDaVisao.lerCarimbo` recusa
  /// `eventoId` vazio como carimbo ilegível, então nenhum evento carimbado
  /// chega aqui com esta chave. A ausência de colisão é uma garantia herdada de
  /// um invariante que já existe, e não uma aposta sobre o formato dos UUIDs do
  /// servidor.
  static const String _chaveLegada = '';

  /// Inserção preservada de propósito: `Map` do Dart itera na ordem em que as
  /// chaves entraram, e [reivindicar] entrega o mais antigo primeiro. Duas
  /// emissões terminais distintas na mesma mesa são apresentadas na ordem em
  /// que o servidor as declarou.
  final Map<String, _Efeito> _efeitos = <String, _Efeito>{};

  static String _chaveDe(EncerramentoAutoritativo aviso) =>
      aviso.eventoId ?? _chaveLegada;

  /// Há efeito esperando por consumidor?
  bool get temPendente =>
      _efeitos.values.any((e) => e.estado == EstadoDoEfeito.pendente);

  /// O estado de um efeito, por `eventoId` (nulo = o legado). Diagnóstico e
  /// teste — nenhum caminho de produção decide nada a partir disto.
  EstadoDoEfeito? estadoDe(String? eventoId) =>
      _efeitos[eventoId ?? _chaveLegada]?.estado;

  /// Quantos efeitos o livro conhece, em qualquer estado. Diagnóstico e teste.
  int get conhecidos => _efeitos.length;

  /// O servidor declarou este fim. Anota como PENDENTE, se for a primeira vez.
  ///
  /// NÃO MARCA NADA COMO APRESENTADO, e é esse o ponto do arquivo: chegar é
  /// chegar. Quem apresenta confirma depois, e só depois.
  ///
  /// Devolve [aviso] quando ele passou a existir agora — é o gancho para
  /// cutucar um consumidor que já esteja montado — e nulo quando o fim já era
  /// conhecido, em qualquer estado. Um reenvio não é um fim novo nem quando o
  /// anterior ainda está pendente: ele é o MESMO fim, já anotado, e cutucar de
  /// novo abriria caminho para dois avisos do mesmo encerramento.
  EncerramentoAutoritativo? registrar(EncerramentoAutoritativo aviso) {
    final chave = _chaveDe(aviso);
    if (_efeitos.containsKey(chave)) return null;
    _efeitos[chave] = _Efeito(aviso);
    return aviso;
  }

  /// [dono] assume a apresentação do efeito pendente mais antigo.
  ///
  /// Devolve nulo quando não há pendente — inclusive quando há um efeito
  /// reivindicado por OUTRO dono. Reivindicação é exclusiva: é ela que impede
  /// que uma reconstrução, uma reentrada concorrente ou uma troca de transporte
  /// abram dois diálogos para o mesmo fim.
  EncerramentoAutoritativo? reivindicar(PosseDoEfeito dono) {
    for (final efeito in _efeitos.values) {
      if (efeito.estado != EstadoDoEfeito.pendente) continue;
      efeito.estado = EstadoDoEfeito.reivindicado;
      efeito.dono = dono;
      return efeito.aviso;
    }
    return null;
  }

  /// [dono] apresentou [aviso] de verdade. Fim de linha para este efeito.
  ///
  /// Devolve falso — e não muda nada — quando quem confirma não é quem
  /// reivindicou. É a proteção contra o callback atrasado do vínculo anterior:
  /// ele não pode encerrar o efeito que o vínculo atual ainda vai apresentar.
  bool confirmar(PosseDoEfeito dono, EncerramentoAutoritativo aviso) {
    final efeito = _efeitos[_chaveDe(aviso)];
    if (efeito == null) return false;
    if (efeito.estado != EstadoDoEfeito.reivindicado) return false;
    if (!identical(efeito.dono, dono)) return false;
    efeito.estado = EstadoDoEfeito.apresentado;
    efeito.dono = null;
    return true;
  }

  /// [dono] não vai apresentar [aviso]: o efeito volta a esperar.
  ///
  /// Mesma conferência de posse de [confirmar], e pela razão espelhada — um
  /// dono antigo não pode devolver ao livro o efeito que o dono atual acabou de
  /// reivindicar, porque isso abriria a porta para dois diálogos.
  bool liberar(PosseDoEfeito dono, EncerramentoAutoritativo aviso) {
    final efeito = _efeitos[_chaveDe(aviso)];
    if (efeito == null) return false;
    if (efeito.estado != EstadoDoEfeito.reivindicado) return false;
    if (!identical(efeito.dono, dono)) return false;
    efeito.estado = EstadoDoEfeito.pendente;
    efeito.dono = null;
    return true;
  }

  /// [dono] saiu de cena: tudo o que ele tinha reivindicado volta a pendente.
  ///
  /// É o que o `dispose` e a troca de transporte chamam. Sem isto, um efeito
  /// reivindicado por um vínculo morto ficaria preso em `reivindicado` para
  /// sempre — invisível como o defeito original, e pelo mesmo motivo.
  ///
  /// Devolve quantos foram liberados. Diagnóstico e teste.
  int liberarTudoDe(PosseDoEfeito dono) {
    var soltos = 0;
    for (final efeito in _efeitos.values) {
      if (efeito.estado != EstadoDoEfeito.reivindicado) continue;
      if (!identical(efeito.dono, dono)) continue;
      efeito.estado = EstadoDoEfeito.pendente;
      efeito.dono = null;
      soltos++;
    }
    return soltos;
  }

  /// A mesa acabou para esta pessoa: ela saiu, ou a sessão virou.
  ///
  /// A próxima mesa é outra partida, com contador próprio — e um encerramento
  /// dela não pode ser confundido com este. Some tudo, inclusive o que estava
  /// pendente: um aviso de uma mesa que a pessoa já deixou não tem mais onde
  /// aparecer.
  void limpar() => _efeitos.clear();
}
