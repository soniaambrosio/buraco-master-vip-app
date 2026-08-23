// composicao.dart — a FRONTEIRA UNICA do estado de elegibilidade do jogador.
//
// O DEFEITO QUE ESTE ARQUIVO EXISTE PARA FECHAR
//
// Ate a homologacao P0 integrada, tres modulos mantinham tres nocoes de estado
// do jogador em tres documentos, e o consumidor lia um QUARTO que ninguem
// escrevia:
//
//     Billing    -> usuarios/{uid}          (vip, vipExpiraEm)
//     Moderacao  -> playerModeration/{uid}  (suspensoAte, suspensaoPermanente)
//     Torneios   -> LIA players/{uid}       (assinaturaAtiva, suspenso)  <- vazio
//
// `players/{uid}` nao tinha produtor, nao tinha regra e nunca existiu. As duas
// flags eram sempre `false`, entao: jogador suspenso continuava se inscrevendo, e
// assinante VIP era recusado em torneio VIP.
//
// A CORRECAO NAO E CRIAR UM QUARTO DOCUMENTO E COPIAR CAMPOS PARA ELE.
//
// Elegibilidade e COMPOSICAO, nao duplicacao. Cada dominio continua dono do seu
// estado, e o retrato que o consumidor usa e MONTADO no momento da leitura:
//
//     playerModeration/{uid}      (dono: moderacao)
//              +
//     playerEntitlements/{uid}    (dono: billing)
//              v
//        comporPerfil()           <- este arquivo
//              v
//     PerfilElegibilidade         -> torneios e demais consumidores
//
// Nao ha copia materializada, entao nao ha o que divergir da fonte, e nao ha
// documento intermediario que alguem precise lembrar de atualizar. O preco e uma
// leitura a mais por inscricao — barato perto de uma sancao que nao pega.
//
// POR QUE ISTO E DART, E NAO TYPESCRIPT
//
// Quem consome o retrato e o dominio de torneios, que e Dart. Quem produz o
// estado de moderacao e `consolidar()`, que e Dart. Escrever a composicao em
// TypeScript criaria uma terceira leitura das mesmas regras, na unica linguagem
// onde nenhum teste do projeto a exercitaria. Aqui, a costura inteira
// — sancao aplicada -> estado consolidado -> perfil -> recusa de inscricao —
// roda num teste puro, sem emulador e sem mock. E o que
// `app/test/elegibilidade/costura_p0_test.dart` faz.
//
// A Cloud Function de torneios chama esta funcao pela mesma ponte que ja usa
// para inscrever (`js_bridge.dart` -> `functions/src/domain.ts`): ela LE os dois
// documentos e obedece. Nenhuma decisao sobre quem e elegivel mora em
// TypeScript.
//
// TUDO AQUI FALHA FECHADO. Documento ausente, campo faltando ou estado que este
// codigo nao conhece produzem "sem VIP" e — no caso da moderacao — mantem a
// suspensao se ela estiver la. Nenhum caminho de duvida concede acesso.

import '../moderacao/sancao.dart';
import '../torneios/eligibility.dart';
import 'entitlement.dart';

/// O retrato de elegibilidade, montado a partir das fontes reais.
///
/// [moderacao] e o documento `playerModeration/{uid}` como ele esta no
/// Firestore; [entitlement] e o `playerEntitlements/{uid}`. Ambos podem ser
/// `null` — jogador sem sancao nenhuma e jogador que nunca comprou sao os casos
/// comuns, e ambos sao estados validos, nao erros.
///
/// [agora] governa as duas perguntas temporais desta composicao (a sancao ainda
/// vale? o VIP ainda vale?) e por isso e capturado UMA vez pelo chamador, como
/// manda a mesma disciplina de `moderacao/sancao.dart`.
///
/// `assinaturaAtiva` do retorno significa VIP INTEGRAL VIGENTE — assinatura
/// de origem com produtor, dentro do prazo. Passe de cortesia, direito
/// administrativo e qualquer origem nova sem decisao escrita NAO satisfazem.
/// Ver [temVipEm] e `kOrigensVipIntegral`.
///
/// Os fatos de competicao ([convitesAtivos], [participacoes], [titulos],
/// [temporadasAtivas]) entram por parametro porque quem os produz sao consultas
/// a colecoes de torneio, e essa leitura e responsabilidade de quem chama.
///
/// [nivel], [posicaoRanking] e [conquistas] NAO TEM PRODUTOR NESTE SISTEMA e por
/// isso sao opcionais com ausencia como padrao. A decisao e deliberada e vale a
/// pena registrar: nao existe autoridade que publique ranking, nivel ou
/// conquista nesta arvore. Deixar os parametros abertos permite ligar a fonte no
/// dia em que ela existir; preenche-los com um chute hoje transformaria criterio
/// de torneio em ficcao. Enquanto estiverem ausentes, os criterios
/// correspondentes recusam por `dadoIndisponivel` / `classificacaoInsuficiente`
/// — que e exatamente o comportamento que o sistema ja tinha, agora explicito.
PerfilElegibilidade comporPerfil({
  required String userId,
  required DateTime agora,
  Map<String, Object?>? moderacao,
  Map<String, Object?>? entitlement,
  Set<String> convitesAtivos = const {},
  Set<String> participacoes = const {},
  Set<String> titulos = const {},
  Set<String> temporadasAtivas = const {},
  int? nivel,
  int? posicaoRanking,
  Set<String> conquistas = const {},
}) {
  if (!agora.isUtc) {
    throw ArgumentError.value(agora, 'agora', 'instante precisa estar em UTC');
  }

  return PerfilElegibilidade(
    userId: userId,
    nivel: nivel,
    posicaoRanking: posicaoRanking,
    assinaturaAtiva: temVipEm(userId, entitlement, agora),
    convitesAtivos: convitesAtivos,
    conquistas: conquistas,
    participacoes: participacoes,
    titulos: titulos,
    temporadasAtivas: temporadasAtivas,
    suspenso: estaSuspensoEm(userId, moderacao, agora),
  );
}

/// O jogador esta impedido de jogar em [agora], segundo a moderacao?
///
/// Le o documento que `consolidarSancoes` grava — o EFEITO consolidado, nao o
/// historico — e reaplica o relogio. A reaplicacao e o que faz uma suspensao
/// temporaria acabar sozinha: o documento guarda `suspensoAte`, e nao um
/// booleano que precisaria de alguem para desligar.
///
/// Suspensao permanente ignora o relogio, por construcao de [EstadoModeracao].
bool estaSuspensoEm(
  String userId,
  Map<String, Object?>? documento,
  DateTime agora,
) {
  if (documento == null || documento.isEmpty) return false;

  // O uid do CAMINHO manda. O documento tambem carrega `userId`, mas um
  // consumidor que confiasse no corpo aceitaria um registro copiado de outra
  // pessoa como se fosse do dono do caminho.
  final estado = EstadoModeracao.fromMap({...documento, 'userId': userId});
  return estado.suspensoEm(agora);
}

/// O jogador tem assinatura VIP INTEGRAL vigente em [agora]?
///
/// ESTA e a resposta que vira `PerfilElegibilidade.assinaturaAtiva`, e por
/// isso ela e a origem unica da admissao em Torneios. A conta de vigencia
/// continua morando inteira em [EntitlementVip.vigenteEm]; o que se acrescenta
/// aqui e a exigencia de ORIGEM, via [EntitlementVip.integralVigenteEm].
///
/// POR QUE A ORIGEM ENTRA, E POR QUE ELA ENTRA AQUI
///
/// A pergunta "tem VIP agora?" tinha uma resposta so, e ela era boa para a
/// loja, para o selo e para a comunicacao. Para TORNEIO ela era larga demais:
/// bastava um documento com `vipAtivo`, estado que concede e prazo no futuro
/// para conceder acesso — nao importava QUEM o tivesse escrito. Um direito
/// gravado sob `origem: "administrativa"` (a origem sem produtor sob a qual um
/// presente seria escrito) entrava em torneio pago e ranqueado como se fosse
/// assinante. A politica congelada da V1 diz que nao.
///
/// A exigencia entra NESTA fronteira, e nao dentro de `vigenteEm`, porque so
/// os consumidores de elegibilidade a querem. `temVipEm` tem exatamente um
/// chamador — [comporPerfil] — e [comporPerfil] tem exatamente um consumidor
/// de producao: a ponte de torneios. O alcance da regra e, por construcao, o
/// alcance da politica que a pediu; Billing e Comunicacao continuam lendo
/// `vigenteEm` e nao mudaram de resposta.
///
/// FALHA FECHADO nas tres formas de duvida: documento ausente, origem ausente
/// e origem que este codigo nao conhece recusam, todas.
bool temVipEm(
  String userId,
  Map<String, Object?>? documento,
  DateTime agora,
) =>
    EntitlementVip.fromMap(userId, documento).integralVigenteEm(agora);
