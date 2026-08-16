// erros_sociais.dart — os códigos de domínio da identidade pública e do grafo
// social (OS §35).
//
// POR QUE UM ARQUIVO SÓ, e não um enum de recusa por operação como a moderação
// faz: aqui as operações se encadeiam. Enviar solicitação pode terminar em
// `relacaoBloqueada`, aceitar também, e abrir perfil também. Se cada operação
// tivesse o seu enum, o cliente precisaria de três tabelas de tradução para a
// MESMA situação — e a terceira ficaria desatualizada.
//
// O CONTRATO COM O CLIENTE É O `.name` DESTE ENUM, e nada mais. §35 é explícita:
// "Não depender de textos de erro para lógica do cliente." Por isso o texto
// legível não mora aqui: quem escreve a mensagem na tela é a camada de
// apresentação, a partir do código. Renomear um valor deste enum é quebra de
// contrato e exige nota de migração.

/// Código estável de recusa do domínio social.
///
/// A convenção é a do projeto (camelCase no `.name`, como `RecusaDenuncia` e
/// `RecusaBloqueio` já usam), e não o SCREAMING_SNAKE do exemplo da OS — §35
/// manda usar "a convenção real do projeto", e misturar as duas faria o cliente
/// tratar `autoDenuncia` e `AUTO_AMIZADE_INVALIDA` no mesmo `switch`.
enum ErroSocial {
  /// A identidade pública informada não existe, ou o UID consultado nunca
  /// recebeu identidade. Equivale a `IDENTIDADE_NAO_ENCONTRADA` da OS.
  identidadeNaoEncontrada,

  /// O perfil público existe mas não pode ser exposto: conta removida,
  /// desativada ou marcada como indisponível (§31-G).
  ///
  /// Separado de [identidadeNaoEncontrada] no DOMÍNIO, mas as duas devem chegar
  /// ao cliente com a mesma cara — ver o comentário de `perfilPublicoIndisponivel`
  /// em identidade_publica.dart. A distinção existe para o log do servidor.
  perfilPublicoNaoDisponivel,

  /// Formato de identidade pública inválido — recusado ANTES de tocar o banco,
  /// para que tentativa barata de enumeração não custe uma leitura.
  perfilPublicoInvalido,

  /// Pedido de amizade a si próprio (§13).
  autoAmizadeInvalida,

  /// Já existe amizade aceita entre os dois.
  jaSaoAmigos,

  /// Já existe solicitação pendente no MESMO sentido. Não é erro fatal: quem
  /// chama deve responder sucesso idempotente (§13, "chamada repetida deve ser
  /// idempotente"). O código existe para o servidor saber que não criou nada.
  solicitacaoJaExiste,

  /// Não há solicitação pendente para aceitar, recusar ou cancelar.
  solicitacaoNaoEncontrada,

  /// Quem chamou não é o destinatário da solicitação (§14).
  naoEDestinatario,

  /// Quem chamou não é o remetente da solicitação (§16). Cancelar é do
  /// remetente; o destinatário recusa, que é outra operação.
  naoERemetente,

  /// Há bloqueio em algum dos dois sentidos, ou sanção social vigente. O
  /// bloqueio é soberano sobre a amizade (§18 e §31-H).
  ///
  /// DELIBERADAMENTE OPACO: um único código para "eu bloqueei", "fui bloqueado"
  /// e "estou com restrição social". Devolver códigos distintos contaria ao
  /// chamador que a OUTRA pessoa o bloqueou, que é exatamente o que §31-B proíbe
  /// ("não expor texto do tipo `Fulano bloqueou você`").
  relacaoBloqueada,

  /// Teto de amizades ativas atingido (§25).
  limiteAmigos,

  /// Teto de solicitações pendentes ENVIADAS atingido (§25).
  ///
  /// Não existe teto de solicitações RECEBIDAS, e a ausência é deliberada: um
  /// atacante que pudesse encher a caixa de entrada alheia até o limite
  /// trancaria a vítima fora do sistema para sempre. §25 pede exatamente que
  /// isso não seja possível.
  limiteSolicitacoes,

  /// Apelido fora das regras de §7 (vazio, curto, longo, caractere de controle).
  apelidoInvalido,

  /// Referência de avatar fora do formato aceito, ou fora do catálogo quando
  /// existir catálogo (§8).
  avatarInvalido,

  /// Identificador interno malformado. Rede de segurança: nenhuma chamada
  /// legítima chega aqui, porque o UID vem do contexto autenticado.
  identificadorInvalido,

  // ------------------------------------------------------------------------
  // BUSCA POR APELIDO (OS de Busca e Descoberta §5, §6, §9)
  //
  // ACRESCENTADOS NO FIM, e não intercalados por afinidade: a §17 daquela OS
  // manda preservar o contrato anterior, e embora o contrato seja o `.name` (e
  // não a ordem), reordenar um enum é o tipo de mudança que passa despercebida
  // e reaparece num `index` gravado em algum lugar.
  // ------------------------------------------------------------------------

  /// Termo de busca inutilizável: não é texto, ficou vazio depois de
  /// normalizado, carrega caractere de controle, ou o modo pedido não existe.
  ///
  /// UM CÓDIGO PARA OS QUATRO, de propósito. São todos "o cliente montou o
  /// pedido errado", e a tela faz a mesma coisa com todos: pedir que a pessoa
  /// digite de novo. Códigos separados serviriam ao depurador, não ao jogador —
  /// e o depurador tem o log do servidor, que registra qual foi.
  consultaInvalida,

  /// Termo mais curto que o menor apelido possível, medido DEPOIS da
  /// normalização (§9, "tamanho mínimo da consulta").
  ///
  /// É o freio antienumeração mais simples que existe: com ele, não há consulta
  /// que devolva "os jogadores cujo apelido começa com a".
  consultaMuitoCurta,

  /// Termo mais longo que o maior apelido possível (§9, "tamanho máximo").
  consultaMuitoLonga,
}

/// Versão do formato dos documentos sociais gravados por esta OS.
///
/// Mesmo papel de `kEsquemaRelacaoSocial` na moderação: um leitor futuro precisa
/// saber o que esperar de um documento gravado hoje.
const int kEsquemaSocial = 1;
