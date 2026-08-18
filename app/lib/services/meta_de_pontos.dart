// meta_de_pontos.dart — a meta da partida, do lado do cliente.
//
// ---------------------------------------------------------------------------
// POR QUE É UM TIPO, E NÃO UM `int`
// ---------------------------------------------------------------------------
//
// A meta é a primeira configuração de mesa que o jogador escolhe, e o comando
// de criação a carrega. Enquanto ela for um `int` no caminho todo, "mandar
// 1.732" é uma linha de código válida em qualquer ponto — a tela, um atalho de
// teste, um `copyWith` distraído. Sendo uma enumeração fechada, o valor
// arbitrário deixa de compilar: não existe `MetaDePontos` fora das três.
//
// ---------------------------------------------------------------------------
// ISTO NÃO É AUTORIDADE — É ESPELHO
// ---------------------------------------------------------------------------
//
// Quem decide quais metas existem é o servidor (`METAS_CANONICAS` em
// `salas`, repo `buraco-servidor`). Esta lista é a MESMA, e está aqui para que
// a tela saiba o que oferecer — não para validar nada em nome dele. Um cliente
// adulterado que mande 1.999 é recusado lá, com sala nenhuma criada; se um dia
// as duas listas divergirem, o sintoma é o servidor recusando um botão que a
// tela desenhou, e não uma mesa fora do catálogo.
//
// O PADRÃO É DECLARADO, e não "o primeiro da lista". Derivar o padrão da ordem
// da vitrine faz reordenar botão trocar regra sem ninguém notar — e é a mesma
// razão pela qual `META_PADRAO` existe separado no servidor.

/// As metas de pontos que uma mesa pode ter.
enum MetaDePontos {
  mil500(1500, '1.500'),
  doisMil(2000, '2.000'),
  tresMil(3000, '3.000');

  const MetaDePontos(this.pontos, this.rotulo);

  /// O número que vai no comando de criação da mesa.
  final int pontos;

  /// Como o número se escreve na tela, com o separador de milhar da casa.
  final String rotulo;

  /// A meta de uma mesa nova quando ninguém escolheu outra.
  ///
  /// 2.000 é o centro das três, e é a mesma decisão que o servidor toma quando
  /// o campo não vem na mensagem.
  static const MetaDePontos padrao = MetaDePontos.doisMil;

  /// A meta correspondente a um número vindo do servidor, ou `null`.
  ///
  /// `null` é a resposta honesta para o que não está no catálogo: a tela mostra
  /// o que a mesa tem, e uma mesa com meta desconhecida não vira "2.000" na
  /// interface só para caber. Aceita `Object?` porque a visão do servidor chega
  /// como mapa dinâmico, e um campo ausente ou de outro tipo tem de responder a
  /// mesma coisa que um número fora da lista.
  static MetaDePontos? deValor(Object? valor) {
    if (valor is! int) return null;
    for (final m in MetaDePontos.values) {
      if (m.pontos == valor) return m;
    }
    return null;
  }
}
