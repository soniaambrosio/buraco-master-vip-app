// busca_apelido.dart — BUSCA E DESCOBERTA por apelido público (OS de Busca §5 a
// §10).
//
// ---------------------------------------------------------------------------
// A DECISÃO CENTRAL DESTE ARQUIVO: NÃO EXISTE SEGUNDA NORMALIZAÇÃO
// ---------------------------------------------------------------------------
//
// A OS §5 exige que "a normalização usada na gravação/indexação e na busca seja
// exatamente a mesma". A forma mais forte de garantir isso não é escrever duas
// funções e testá-las uma contra a outra — é ter UMA função. [chaveDeBusca] é
// literalmente `chaveDeOrdenacao(normalizarApelido(x))`, e `apelidoOrdenacao`,
// o campo já gravado em `publicProfiles` desde a OS anterior, é
// `chaveDeOrdenacao(apelido)` sobre um apelido que a gravação já normalizou.
//
// Logo: `chaveDeBusca(apelidoBruto) == apelidoOrdenacao` do perfil que aquele
// apelido produziria. O teste `NRM-EQ` prova a igualdade, mas ela não depende do
// teste — depende de as duas expressões serem a mesma composição.
//
// ---------------------------------------------------------------------------
// POR QUE NÃO HÁ COLEÇÃO AUXILIAR DE ÍNDICE (OS §4)
// ---------------------------------------------------------------------------
//
// A §4 permite uma estrutura derivada de busca, desde que mínima, sem UID e
// reconstruível. A estrutura mínima possível é NENHUMA: `apelidoOrdenacao` já
// existe, já é derivado do apelido a cada escrita, já é recalculado pelo
// servidor e nunca aceito do cliente, e mora no ÚNICO documento que a OS
// anterior declarou público. Criar `nicknameIndex/{chave}` seria duplicar um
// campo que já está no lugar certo — e cada duplicata é uma chance de as duas
// discordarem no dia em que alguém mexer só em uma.
//
// O QUE ISSO NÃO MUDA: `apelidoOrdenacao` continua sendo campo DERIVADO e NÃO
// AUTORITATIVO. Ele não é identidade (isso é `publicId`), não é apresentação
// (isso é `apelido`) e não é amizade (isso é `friendships/{pairKey}`). Perdê-lo
// inteiro custaria a ordenação e a busca, e nada mais; ele se reconstrói
// reescrevendo o perfil.
//
// ---------------------------------------------------------------------------
// O QUE ESTE ARQUIVO **NÃO** FAZ, e por decisão registrada (OS §6)
// ---------------------------------------------------------------------------
//
// Sem busca fuzzy, sem Levenshtein, sem infixo ("quem contém 'ana'"), sem
// ranking de relevância, sem histórico de pesquisa, sem sugestão. Duas
// modalidades, as duas ancoradas no começo da chave: exata e prefixo. É o que
// uma faixa ordenada do Firestore serve sem estrutura nova — e é exatamente por
// caber na estrutura existente que essa é a modalidade "segura comprovada" que
// a §6 pede.

import 'amizade.dart';
import 'apresentacao.dart';
import 'erros_sociais.dart';
import '../moderacao/relacao_social.dart' as moderacao;

// ===========================================================================
// LIMITES (OS §9)
// ===========================================================================

/// Mínimo de caracteres visíveis de uma consulta.
///
/// AMARRADO A [kApelidoMinimo], e não escolhido em separado. Um termo mais curto
/// que o menor apelido possível não poderia casar com nada por correspondência
/// exata — e, no prefixo, seria a primeira letra de um diretório. Se um dia o
/// mínimo do apelido mudar, este acompanha sozinho.
const int kConsultaMinima = kApelidoMinimo;

/// Máximo de caracteres visíveis de uma consulta.
///
/// Também amarrado: consulta maior que o maior apelido possível não casa com
/// nada, e aceitar texto ilimitado só serviria para engordar log e chave de
/// consulta.
const int kConsultaMaxima = kApelidoMaximo;

/// Quantos resultados a busca devolve quando o cliente não pede um número.
const int kResultadosPadrao = 10;

/// TETO DURO de resultados por consulta.
///
/// Menor que o `kPaginaMaxima` das listas sociais de propósito: aquelas listas são
/// do próprio jogador (os amigos DELE), esta é uma janela para a base inteira.
/// O teto pequeno, somado à ausência de cursor, é o que impede que a busca vire
/// paginação sobre o diretório de jogadores — ver [kSemCursor].
const int kResultadosMaximo = 20;

/// A busca NÃO PAGINA, e a ausência é a decisão antienumeração central (§9).
///
/// Uma busca paginada é um diretório com passos: `limite=20` mais um cursor
/// percorre, em 500 chamadas, os 10.000 jogadores cujo apelido começa com "a".
/// Sem cursor, cada consulta enxerga no máximo [kResultadosMaximo] jogadores e
/// a única forma de ver outros é escrever um termo mais específico — que exige
/// saber o que se procura, que é a definição de "buscar" em oposição a "listar".
///
/// A constante existe para ser citada em teste e em documentação: a ausência de
/// um recurso não aparece num diff, e sem um nome ninguém a reconhece como
/// escolha.
const bool kSemCursor = true;

/// Sentinela que fecha a faixa do prefixo.
///
/// NÃO é U+F8FF, o valor do idiom mais citado para prefixo no Firestore. U+F8FF
/// fica na Área de Uso Privado e é MENOR que qualquer emoji (que vivem acima de
/// U+1F000): um apelido "Ana" seguido de emoji produz chave maior que
/// `"ana" + U+F8FF` e sumiria da busca por "ana" — e apelido com emoji é
/// legítimo, porque [recusaDeApelido] conta runas e não proíbe a faixa.
/// U+10FFFF é o maior ponto de código que existe, então não há string começada
/// pelo prefixo que fique fora da faixa.
const String kFimDaFaixa = '\u{10FFFF}';

// ===========================================================================
// MODALIDADE (OS §6)
// ===========================================================================

/// Como o termo é comparado com a chave de busca.
enum ModoBusca {
  /// A chave do apelido é IGUAL à chave do termo. É a modalidade que a §6 manda
  /// priorizar, e a única que não enxerga nada além do que foi digitado.
  exato,

  /// A chave do apelido COMEÇA com a chave do termo. Faixa ordenada sobre o
  /// mesmo campo; nenhuma estrutura a mais.
  prefixo;

  /// Modo pedido pelo cliente. Ausente vira [prefixo]; desconhecido vira `null`,
  /// e quem chama recusa.
  ///
  /// VALOR DESCONHECIDO NÃO CAI NO PADRÃO, de propósito: §9 pede "validação
  /// estrita dos parâmetros", e um `modo: 'contem'` silenciosamente tratado como
  /// prefixo faria o cliente acreditar que recebeu uma busca que não existe.
  static ModoBusca? porNome(Object? nome) {
    if (nome == null) return ModoBusca.prefixo;
    for (final m in ModoBusca.values) {
      if (m.name == nome) return m;
    }
    return null;
  }
}

// ===========================================================================
// NORMALIZAÇÃO (OS §5)
// ===========================================================================

/// A chave de comparação de um texto qualquer — termo de busca ou apelido.
///
/// É a MESMA composição que produz `apelidoOrdenacao` no documento público:
/// apara bordas, colapsa espaços internos, baixa a caixa e dobra o acento. Não
/// recusa nada e não decide nada; quem valida é [avaliarConsultaDeBusca].
///
/// NÃO ALTERA O QUE O JOGADOR VÊ (§5, última linha). A apresentação continua
/// sendo `PerfilPublico.apelido`, com acento e caixa originais; esta chave só
/// existe para comparar.
String chaveDeBusca(String bruto) => chaveDeOrdenacao(normalizarApelido(bruto));

// ===========================================================================
// A CONSULTA
// ===========================================================================

/// Uma consulta já validada — ou a recusa que a impediu de existir.
///
/// Devolve a FAIXA pronta ([chaveInicio], [chaveFim]) em vez de devolver só a
/// chave: montar a faixa é decisão de domínio (é ela que define o que "prefixo"
/// significa), e deixá-la para o TypeScript seria deixar a semântica da busca em
/// dois lugares.
class ConsultaDeBusca {
  final ErroSocial? recusa;
  final ModoBusca modo;

  /// Extremo inferior da faixa, inclusivo. No modo exato, é o valor da
  /// igualdade.
  final String chaveInicio;

  /// Extremo superior da faixa, inclusivo. Igual a [chaveInicio] no modo exato.
  final String chaveFim;

  final int limite;

  const ConsultaDeBusca.recusada(this.recusa)
      : modo = ModoBusca.prefixo,
        chaveInicio = '',
        chaveFim = '',
        limite = 0;

  const ConsultaDeBusca.aceita({
    required this.modo,
    required this.chaveInicio,
    required this.chaveFim,
    required this.limite,
  }) : recusa = null;

  bool get aceita => recusa == null;

  Map<String, Object?> toJson() => {
        'aceita': aceita,
        'recusa': recusa?.name,
        'modo': modo.name,
        'chaveInicio': chaveInicio,
        'chaveFim': chaveFim,
        'limite': limite,
      };
}

/// Quantos resultados devolver, dado o que o cliente pediu.
///
/// Mesma disciplina de `tamanhoDePagina` nas listas: o cliente pode pedir menos,
/// nunca mais.
int tamanhoDaBusca(Object? pedido) {
  if (pedido is! num) return kResultadosPadrao;
  final n = pedido.toInt();
  if (n <= 0) return kResultadosPadrao;
  return n > kResultadosMaximo ? kResultadosMaximo : n;
}

/// Valida um pedido de busca e monta a faixa (§5, §6, §9).
///
/// A ORDEM DAS RECUSAS É PROPOSITAL: forma antes de tamanho. Um termo com
/// caractere de controle é recusado como inválido mesmo que tenha o comprimento
/// certo, porque o problema dele não é o tamanho — e um `consultaMuitoCurta`
/// para `"a" + U+202E + "b"` mandaria o jogador digitar mais em vez de apagar o
/// lixo.
///
/// O COMPRIMENTO É MEDIDO DEPOIS DA NORMALIZAÇÃO. `"  ab  "` tem seis caracteres
/// e é curto demais; medir antes o aprovaria, e a busca sairia procurando por
/// `"ab"` — que é a consulta de duas letras que o mínimo existe para impedir.
ConsultaDeBusca avaliarConsultaDeBusca({
  required Object? termo,
  Object? modo,
  Object? limite,
}) {
  if (termo is! String) {
    return const ConsultaDeBusca.recusada(ErroSocial.consultaInvalida);
  }

  final modoEscolhido = ModoBusca.porNome(modo);
  if (modoEscolhido == null) {
    return const ConsultaDeBusca.recusada(ErroSocial.consultaInvalida);
  }

  final normalizado = normalizarApelido(termo);
  if (normalizado.isEmpty) {
    return const ConsultaDeBusca.recusada(ErroSocial.consultaInvalida);
  }
  if (temCaractereProibido(normalizado)) {
    return const ConsultaDeBusca.recusada(ErroSocial.consultaInvalida);
  }

  final visiveis = comprimentoVisivel(normalizado);
  if (visiveis < kConsultaMinima) {
    return const ConsultaDeBusca.recusada(ErroSocial.consultaMuitoCurta);
  }
  if (visiveis > kConsultaMaxima) {
    return const ConsultaDeBusca.recusada(ErroSocial.consultaMuitoLonga);
  }

  final chave = chaveDeOrdenacao(normalizado);
  // A chave pode encurtar em relação ao termo (a dobra de acento é 1:1, mas a
  // caixa e o colapso de espaço não aumentam nada), e nunca fica vazia se o
  // normalizado não estava — mas a checagem custa uma linha e fecha a hipótese.
  if (chave.isEmpty) {
    return const ConsultaDeBusca.recusada(ErroSocial.consultaInvalida);
  }

  return ConsultaDeBusca.aceita(
    modo: modoEscolhido,
    chaveInicio: chave,
    chaveFim: modoEscolhido == ModoBusca.exato ? chave : '$chave$kFimDaFaixa',
    limite: tamanhoDaBusca(limite),
  );
}

// ===========================================================================
// O RESULTADO (OS §7 e §10)
// ===========================================================================

/// O que a busca sabe sobre um candidato ANTES de decidir se ele aparece.
///
/// Carrega UID porque é o que o servidor tem em mãos; ele morre aqui dentro.
/// [ResultadoDeBusca], que é o que sai, não tem onde guardá-lo.
class CandidatoDeBusca {
  final String publicId;
  final String uidAlvo;
  final EstadoAmizade estado;
  final String? solicitanteUid;

  /// O observador bloqueou este candidato.
  final bool euBloqueeiOAlvo;

  /// Este candidato bloqueou o observador.
  final bool alvoMeBloqueou;

  const CandidatoDeBusca({
    required this.publicId,
    required this.uidAlvo,
    required this.estado,
    required this.solicitanteUid,
    required this.euBloqueeiOAlvo,
    required this.alvoMeBloqueou,
  });
}

/// O estado social sanitizado de um resultado (§10).
///
/// NÃO CARREGA UID, não carrega quem bloqueou quem e não é fonte de amizade: a
/// fonte continua sendo `friendships/{pairKey}`, e este objeto é uma leitura
/// composta na hora, exatamente como a de `verPerfilPublico`.
class ResultadoDeBusca {
  final String publicId;
  final RelacaoVista relacao;
  final Set<AcaoSocial> acoes;

  const ResultadoDeBusca({
    required this.publicId,
    required this.relacao,
    required this.acoes,
  });

  Map<String, Object?> toJson() => {
        'publicId': publicId,
        'relacao': relacao.name,
        'acoes': acoes.map((a) => a.name).toList(growable: false),
      };
}

/// Um candidato bloqueado — em QUALQUER sentido — aparece na busca? Não (§8).
///
/// É A REGRA INTEIRA DA §8 NUMA LINHA, e ela é simétrica de propósito:
///
///   o alvo me bloqueou ..... eu não o encontro. É a proteção pedida: sem isso,
///                            a busca seria a rota que devolve ao bloqueado o
///                            acesso que o bloqueio tirou — ele acharia a
///                            pessoa, veria o perfil e tentaria a amizade.
///   eu bloqueei o alvo ..... ele também não aparece. Não é exigência da OS; é a
///                            mesma decisão que a moderação já tomou em
///                            `avaliarContato` ao recusar as duas direções. Uma
///                            lista de descoberta que devolve quem eu escolhi
///                            não ver é um defeito de produto, e manter as duas
///                            direções iguais evita que a AUSÊNCIA de alguém
///                            informe qual dos dois lados bloqueou.
///
/// SANÇÃO NÃO OCULTA. Um jogador com restrição social vê os resultados e não
/// recebe ação nenhuma sobre eles ([RelacaoVista.indisponivel] com conjunto de
/// ações vazio). Ocultar tudo faria a busca parecer quebrada em vez de
/// restrita — e a restrição é sobre AGIR, não sobre enxergar. Quem impede a ação
/// de verdade é `enviarSolicitacaoAmizade`, que relê o contato dentro da própria
/// transação.
bool visivelNaBusca(CandidatoDeBusca c) =>
    !c.euBloqueeiOAlvo && !c.alvoMeBloqueou;

/// Projeta os candidatos em resultados públicos, na ordem recebida (§7, §8, §10).
///
/// UMA TRAVESSIA SÓ para filtro + relação + ações, pelo mesmo motivo que
/// `vistaDaRelacaoJson` junta vista e ações: separá-las deixaria o TypeScript
/// livre para filtrar de um jeito e rotular de outro, que é exatamente como as
/// duas divergem.
///
/// A ORDEM DE ENTRADA É PRESERVADA. Ela vem do `orderBy` do Firestore sobre a
/// chave de busca, e reordenar aqui tornaria o resultado dependente de quantos
/// itens o filtro removeu.
List<ResultadoDeBusca> projetarResultadosDeBusca({
  required String uidObservador,
  required List<CandidatoDeBusca> candidatos,
  bool observadorComChatSilenciado = false,
  bool observadorComRestricaoSocial = false,
}) {
  final saida = <ResultadoDeBusca>[];
  for (final c in candidatos) {
    if (!visivelNaBusca(c)) continue;

    // O veredito de contato vem da MODERAÇÃO, e não de um `if` daqui — §18 da OS
    // anterior continua valendo: consumir, nunca duplicar.
    final contato = moderacao.avaliarContato(
      origemBloqueouDestino: c.euBloqueeiOAlvo,
      destinoBloqueouOrigem: c.alvoMeBloqueou,
      origemComChatSilenciado: observadorComChatSilenciado,
      origemComRestricaoSocial: observadorComRestricaoSocial,
    );

    final vista = vistaDaRelacao(
      uidObservador: uidObservador,
      uidAlvo: c.uidAlvo,
      estado: c.estado,
      solicitanteUid: c.solicitanteUid,
      euBloqueeiOAlvo: c.euBloqueeiOAlvo,
      contatoPermitido: contato.permitido,
    );

    saida.add(ResultadoDeBusca(
      publicId: c.publicId,
      relacao: vista,
      acoes: acoesDisponiveis(vista),
    ));
  }
  return saida;
}
