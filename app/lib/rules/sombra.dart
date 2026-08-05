// C1 — andaime do RulesEngine canônico. SEM comportamento de produção.
//
// Ajuste obrigatório 5 — cada divergência INTENCIONAL entre o motor antigo e o
// RulesEngine é versionada: ID, caso específico, teste que a cobre e a etapa
// (commit) em que deixa de ser exceção.
//
// Fora desta lista, QUALQUER divergência antigo × novo é falha do modo sombra.

class ExcecaoSombra {
  final String id; // EXC-01, EXC-02, ...
  final String descricao; // o que diverge e por quê (mudança canônica)
  final String casoEspecifico; // entrada mínima que dispara a divergência
  final String testeCobertura; // nome do teste que trava a divergência
  final String etapaRemocao; // commit em que a exceção sai da lista

  const ExcecaoSombra({
    required this.id,
    required this.descricao,
    required this.casoEspecifico,
    required this.testeCobertura,
    required this.etapaRemocao,
  });
}

/// Divergências intencionais declaradas (as três correções canônicas).
/// Enquanto o motor antigo for o padrão, o sombra ACEITA só estas diferenças.
const List<ExcecaoSombra> excecoesSombra = [
  ExcecaoSombra(
    id: 'EXC-01',
    descricao:
        'Trinca com curinga: o antigo aceitava 1 curinga; o canônico rejeita '
        '(trinca somente natural; Joker e 2 fora).',
    casoEspecifico:
        'FECHADO: [Q espadas, Q copas, JOKER] -> antigo VÁLIDO, canônico INVÁLIDO.',
    testeCobertura: 'TRIN-02 (Joker) / TRIN-03 (2 como curinga)',
    etapaRemocao: 'C10 (aposentadoria do motor antigo)',
  ),
  ExcecaoSombra(
    id: 'EXC-02',
    descricao:
        'Abertura múltipla: o antigo valida 1 jogo por ação; o canônico soma '
        'vários jogos numa abertura atômica.',
    casoEspecifico:
        'Duas corridas legais que só JUNTAS atingem o mínimo -> antigo RECUSA, '
        'canônico ACEITA.',
    testeCobertura: 'ABE-ATOMICA-01',
    etapaRemocao: 'C10',
  ),
  ExcecaoSombra(
    id: 'EXC-03',
    descricao:
        'Lixo fechado: o antigo exige o jogo do topo atingir o mínimo sozinho; '
        'o canônico desacopla (topo só precisa ter uso legal).',
    casoEspecifico:
        'Topo num jogo abaixo do mínimo + outros jogos completam -> antigo '
        'RECUSA, canônico ACEITA.',
    testeCobertura: 'LIXO-DESACOPLA-01',
    etapaRemocao: 'C10',
  ),
];

/// Verdade do modo sombra sobre um par de assinaturas de estado.
class ResultadoSombra {
  final bool iguais;
  final String? idExcecaoAplicada; // preenchido quando a diferença é declarada
  final String? diff; // diferença textual quando NÃO justificada
  const ResultadoSombra({
    required this.iguais,
    this.idExcecaoAplicada,
    this.diff,
  });
}
