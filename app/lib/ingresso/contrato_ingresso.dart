// contrato_ingresso.dart — o vocabulário do fio do INGRESSO, num lugar só.
//
// ---------------------------------------------------------------------------
// POR QUE ESTE ARQUIVO EXISTE SEPARADO DO DA DESCOBERTA
// ---------------------------------------------------------------------------
//
// A descoberta é uma PROJEÇÃO SOMENTE LEITURA: ela não senta ninguém. O
// ingresso é o oposto — é a única mensagem desta família que muda o estado do
// servidor. Misturar os dois vocabulários num arquivo só faria a fronteira que
// lê uma lista compartilhar constantes com a que ocupa uma cadeira, e a
// primeira regressão a atravessar essa fronteira seria invisível.
//
// ---------------------------------------------------------------------------
// A DIFERENÇA DE PROVENIÊNCIA, DITA EM VOZ ALTA
// ---------------------------------------------------------------------------
//
// `contrato/descoberta-mesas-v1.json` existe IDÊNTICO nos dois repositórios, e
// é isso que faz uma edição de um lado reprovar no outro.
//
// `contrato/ingresso-assento-v1.json` NÃO tem gêmeo. A OS 38.3 é do cliente e
// proíbe tocar no servidor — não há como publicar a cópia lá sem violar isso.
// O que sobra é mais fraco e precisa ser dito: a amarra é a PROVENIÊNCIA (o
// SHA congelado, declarado dentro do JSON) mais o digest, que impede a cópia
// do cliente de derivar sozinha. Publicar o gêmeo no servidor é residual
// registrado.
//
// ---------------------------------------------------------------------------
// O CLIENTE PEDE. O SERVIDOR DECIDE.
// ---------------------------------------------------------------------------
//
// Nenhuma constante daqui autoriza o aplicativo a concluir coisa nenhuma sobre
// ocupação. [assentoMinimo]/[assentoMaximo] existem para o cliente não gastar
// socket mandando um pedido que já sabe inválido — e não para ele julgar se a
// cadeira está livre. Quem sabe isso é o servidor, no instante da escrita.

/// Vocabulário e limites do fio do ingresso (OS 38.3).
///
/// Tudo `static const`: é contrato, não configuração.
class ContratoDoIngresso {
  const ContratoDoIngresso._();

  /// Nome do arquivo de contrato, relativo à raiz do repositório.
  static const arquivo = 'contrato/ingresso-assento-v1.json';

  static const esquema = 'ingresso-assento-v1';
  static const versao = 1;

  /// O SHA do servidor congelado de onde cada valor deste arquivo foi lido.
  ///
  /// Não é decoração: a suíte compara esta string com a que está dentro do
  /// JSON, então trocar de servidor sem reler o protocolo reprova.
  static const shaDoServidor = '8a0ee4b76ac915705e2e1a37237666a4aab41c39';

  // --- mensagens ------------------------------------------------------------

  /// Cliente → servidor. Campos: `codigo`, `apelido` e — só quando há escolha
  /// explícita — `assento`.
  static const pedidoDeIngresso = 'entrarMesa';

  /// Servidor → cliente: o ACK. Traz o assento EFETIVAMENTE confirmado.
  static const respostaDeAceite = 'entrou';

  /// Servidor → cliente: a recusa. Traz `motivo` e, quando tipada, `codigo`.
  static const respostaDeRecusa = 'erro';

  // --- campos ---------------------------------------------------------------

  static const campoCodigo = 'codigo';
  static const campoApelido = 'apelido';

  /// O campo do assento PEDIDO. Quando o ingresso é automático, esta chave não
  /// existe no objeto — ver `EstadoDoIngresso`.
  static const campoAssento = 'assento';

  /// O campo do assento CONFIRMADO, dentro do ACK. Mesmo nome, outro sentido:
  /// aqui ele é veredito, não pedido.
  static const campoAssentoConfirmado = 'assento';

  static const campoReconexao = 'reconexao';
  static const campoMotivo = 'motivo';
  static const campoCodigoDeRecusa = 'codigo';

  // --- recusas tipadas ------------------------------------------------------

  /// A cadeira pedida já tem dono. É a recusa da CONCORRÊNCIA: dois jogadores
  /// viram o mesmo lugar livre e só um sentou.
  static const recusaAssentoOcupado = 'ASSENTO_OCUPADO';

  /// O pedido não é um assento: fora de 0..3, não inteiro, ou `null` explícito.
  static const recusaAssentoInvalido = 'ASSENTO_INVALIDO';

  /// O backend de direitos da mesa VIP não respondeu. Não acontece em mesa
  /// pública casual — que é a única descobrível —, e está aqui porque o
  /// servidor pode emiti-la e um código não previsto viraria recusa genérica
  /// sem que ninguém soubesse por quê.
  static const recusaAdmissaoIndisponivel = 'ADMISSAO_VIP_INDISPONIVEL';

  /// Enumeração FECHADA dos códigos tipados deste caminho.
  static const codigosTipados = <String>{
    recusaAssentoOcupado,
    recusaAssentoInvalido,
    recusaAdmissaoIndisponivel,
  };

  // --- recusas sem código ---------------------------------------------------
  //
  // Chegam só com `motivo`. São lidas por TEXTO porque é o que existe no fio.
  // Classificar errado não concede assento nenhum: no pior caso a recusa vira
  // genérica, e a pessoa continua fora da mesa — que é o lado seguro.

  static const motivoMesaNaoEncontrada = 'mesa nao encontrada';
  static const motivoMesaCheia = 'mesa cheia';
  static const motivoPartidaJaComecou = 'a partida ja comecou';

  // --- assento --------------------------------------------------------------

  static const assentoMinimo = 0;
  static const assentoMaximo = 3;

  /// Quatro cadeiras, sempre. Mesmo número da descoberta, e não é coincidência:
  /// é a mesma mesa.
  static const capacidadeDaMesa = 4;

  /// A ordem que o SERVIDOR aplica quando o campo `assento` está ausente.
  ///
  /// Está aqui para ser DOCUMENTADA e para a suíte poder afirmar que o cliente
  /// não a reproduz. O aplicativo não escolhe por esta lista e não a manda
  /// disfarçada de preferência: ele omite o campo e lê o assento do ACK.
  static const ordemAutomaticaDoServidor = <int>[2, 1, 3];

  /// A MESMA regra do servidor (`Number.isInteger(v) && v >= 0 && v < 4`).
  ///
  /// Sem coerção: `"2"` não vira 2 aqui, do mesmo jeito que não vira lá.
  /// Adivinhar a intenção de um cliente que já errou o contrato é como se
  /// volta ao fallback por outro caminho.
  static bool ehAssentoPedido(Object? v) =>
      v is int && v >= assentoMinimo && v <= assentoMaximo;

  /// Normaliza um `motivo` do fio para comparação: minúsculas, sem acento e
  /// sem espaço sobrando.
  ///
  /// O servidor escreve "mesa não encontrada" com til; um dia pode escrever sem.
  /// Fazer a comparação depender do acento transformaria uma recusa conhecida
  /// em desconhecida por causa de um caractere — e a diferença apareceria como
  /// mensagem genérica na tela de alguém, não como teste vermelho.
  static String normalizarMotivo(String bruto) {
    const de = 'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ';
    const para = 'aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC';
    final buffer = StringBuffer();
    for (final unidade in bruto.runes) {
      final c = String.fromCharCode(unidade);
      final i = de.indexOf(c);
      buffer.write(i == -1 ? c : para[i]);
    }
    return buffer.toString().toLowerCase().trim();
  }
}
