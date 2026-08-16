// C1 — andaime do RulesEngine canônico. NÃO participa do runtime: o modo sombra
// é exclusivamente DIAGNÓSTICO e `MotorConfig.producao()` nasce com sombra OFF.
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
        '(trinca somente natural; Joker e 2 fora). RECONCILIADA (C9-C2c): o '
        'legado ATUAL já recusa Joker em trinca — os dois motores CONVERGEM '
        '(ambos recusam). Não é divergência dirigível por transação de sombra.',
    casoEspecifico:
        'FECHADO: [Q espadas, Q copas, JOKER] -> hoje antigo e canônico ambos '
        'INVÁLIDO (teste C9-EXC01-RECONC).',
    testeCobertura: 'TRIN-02 (Joker) / TRIN-03 (2 como curinga) / C9-EXC01-RECONC',
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
    testeCobertura: 'LIXO-04 (jogo do topo < 75, conjunto acima) / LIXO-01',
    etapaRemocao: 'C10',
  ),
  ExcecaoSombra(
    id: 'EXC-04',
    descricao:
        'Grupo só de ases: o antigo classificava como "de_as" (família '
        'sequência); o canônico classifica como TRINCA no Fechado, NUNCA '
        'sequência; no Aberto e no STBL é inválido. Trinca de ases não forma '
        'canastra, não recebe bônus e não libera batida. RECONCILIADA (C9-C2c): '
        'em NÍVEL DE ESTADO os dois motores CONVERGEM — no Fechado ambos ACEITAM '
        '(mesmo meld baixado) e no Aberto ambos RECUSAM (o legado atual barra o '
        'grupo de ases fora do Fechado). A diferença remanescente é só de '
        'CLASSIFICAÇÃO/pontuação (de_as × trinca), fora do alcance da assinatura '
        'de estado.',
    casoEspecifico:
        'A copas, A ouros, A espadas -> Fechado: ambos ACEITAM; Aberto: ambos '
        'RECUSAM (testes C9-EXC04-RECONC-FECHADO / C9-EXC04-RECONC-ABERTO).',
    testeCobertura: 'MELD-AS-01 / C9-EXC04-RECONC-FECHADO / C9-EXC04-RECONC-ABERTO',
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
