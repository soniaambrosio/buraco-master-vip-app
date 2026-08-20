// superficie.dart — ONDE o chat de TEXTO LIVRE existe, e onde ele NÃO existe.
//
// Este arquivo é uma CLASSIFICAÇÃO, não uma lista de desejos: cada superfície tem
// um veredito, e o veredito de quem não tem decisão de produto é NÃO LIBERADO —
// nunca "liberado até alguém reclamar".
//
// A CORREÇÃO CANÔNICA QUE MOLDOU ESTE ARQUIVO. A primeira versão tratava
// "mesa de partida" como UMA superfície e liberava texto livre nas três variantes
// de `TipoMesa`, apoiada em `ChatMesa.completo` aparecer nas três. Isso estava
// errado, e a razão é de produto, não de código:
//
//   TEXTO LIVRE EXIGE CÍRCULO RESTRITO. Só a Mesa Privada é composta por pessoas
//   CONVIDADAS e INDIVIDUALMENTE ELEGÍVEIS — quem entra tem código e tem direito
//   próprio. Numa Mesa Pública qualquer pessoa senta ao lado de qualquer outra, e
//   texto livre entre desconhecidos é uma superfície de assédio que a denúncia
//   remedia depois em vez de prevenir antes.
//
// As demais superfícies NÃO ficam sem chat: elas usam mensagens previamente
// cadastradas, reações e emojis autorizados. Isso é outra funcionalidade, com
// outro vocabulário, e NÃO é construída aqui — este arquivo só afirma que texto
// DIGITADO LIVREMENTE não nasce nelas.
//
// A CLASSIFICAÇÃO, com a evidência de cada linha:
//
//   mesaPrivada ........... LIBERADO. Círculo restrito: `TipoMesa.privada` nasce
//                           com `codigo` de convite em
//                           app/lib/screens/configurar_mesa_screen.dart, e o
//                           servidor a trata como benefício exclusivo em que
//                           "cada ocupante precisa de direito PRÓPRIO"
//                           (`avaliarAdmissaoAoAssento`).
//
//   mesaPublica ........... NÃO LIBERADO. Falas prontas. Mesa aberta a
//                           desconhecidos.
//
//   mesaVip ............... NÃO LIBERADO. Falas prontas. A modalidade
//                           competitiva oficial (`vip_ranqueada`) é aberta a
//                           qualquer VIP, e ser VIP não é ser convidado.
//
//   saguaoPublico ......... NÃO LIBERADO. Falas prontas — e é o que
//                           app/lib/screens/saguao_screen.dart já anunciava:
//                           "Converse por falas prontas · sem digitação".
//
//   salaoVip .............. NÃO LIBERADO. Falas prontas. É o saguão em modo VIP
//                           ("👑 Salão VIP" na mesma tela), e não uma mesa.
//
//   espectadorDeMesa ...... NÃO LIBERADO, nas DUAS direções: não fala e não
//                           recebe. Receber é metade de conversar, e liberar só a
//                           escuta entregaria a mesa a uma plateia que os
//                           jogadores não escolheram.
//
// O QUE MUDA QUANDO O PRODUTO DECIDIR outra coisa: acrescenta-se o valor e a
// política. O que NÃO se faz é reaproveitar `mesaPrivada` para um canal que não é
// Mesa Privada — ver `politicaDe`, que é a fonte única.

/// Onde a mensagem foi escrita.
///
/// `wire` é o valor que atravessa a fronteira. Nome de enum do Dart NÃO vai para
/// o Firestore: renomear o enum em Dart não pode reescrever documento gravado.
///
/// QUEBRA DELIBERADA: o valor `mesa_de_partida` da primeira versão NÃO existe
/// mais. Ele colapsava três superfícies com políticas diferentes, e mantê-lo como
/// sinônimo de alguma delas seria manter o defeito com outro nome. Canal gravado
/// com o valor antigo passa a ser superfície desconhecida — e superfície
/// desconhecida é recusa, não permissão.
enum SuperficieChat {
  /// Mesa criada por convite, com código, entre pessoas individualmente
  /// elegíveis. A ÚNICA superfície de texto livre.
  mesaPrivada('mesa_privada'),

  /// Mesa aberta: qualquer jogador senta.
  mesaPublica('mesa_publica'),

  /// A modalidade competitiva oficial (VIP/Ranqueada).
  mesaVip('mesa_vip'),

  /// O saguão, fora de qualquer partida.
  saguaoPublico('saguao_publico'),

  /// O saguão em modo VIP.
  salaoVip('salao_vip'),

  /// Quem assiste uma partida sem ocupar assento.
  espectadorDeMesa('espectador_de_mesa');

  final String wire;
  const SuperficieChat(this.wire);

  static SuperficieChat? porWire(Object? wire) {
    if (wire is! String) return null;
    for (final s in SuperficieChat.values) {
      if (s.wire == wire) return s;
    }
    return null;
  }
}

/// O estado de uma superfície diante do chat de TEXTO LIVRE.
enum PoliticaSuperficie {
  /// Há decisão de produto, e ela permite texto livre.
  liberado('liberado'),

  /// Há decisão de produto, e ela NÃO permite texto livre. Não é lacuna: é
  /// recusa. Estas superfícies têm chat de falas prontas, que é outra coisa.
  naoLiberado('nao_liberado'),

  /// Não há decisão de produto. Trata-se como recusa até que exista.
  ///
  /// NENHUMA superfície está neste estado hoje — a correção canônica decidiu
  /// todas. O valor permanece porque a distinção continua valendo para a
  /// superfície que aparecer amanhã, e porque um laudo precisa distinguir "o
  /// produto disse não" de "ninguém decidiu": só o segundo é pendência.
  decisaoAusente('decisao_ausente');

  final String wire;
  const PoliticaSuperficie(this.wire);
}

/// A classificação. Fonte ÚNICA: quem quiser saber se há texto livre numa
/// superfície pergunta aqui, e não olha um `if` espalhado.
PoliticaSuperficie politicaDe(SuperficieChat s) => switch (s) {
      SuperficieChat.mesaPrivada => PoliticaSuperficie.liberado,
      SuperficieChat.mesaPublica => PoliticaSuperficie.naoLiberado,
      SuperficieChat.mesaVip => PoliticaSuperficie.naoLiberado,
      SuperficieChat.saguaoPublico => PoliticaSuperficie.naoLiberado,
      SuperficieChat.salaoVip => PoliticaSuperficie.naoLiberado,
      SuperficieChat.espectadorDeMesa => PoliticaSuperficie.naoLiberado,
    };

/// Texto livre pode nascer nesta superfície?
///
/// FALHA FECHADA por construção: só `liberado` responde `true`. Um valor novo no
/// enum [PoliticaSuperficie] não vira permissão por descuido, e uma superfície
/// nova não vira permissão por esquecimento — o `switch` é exaustivo.
bool superficieAceitaTextoLivre(SuperficieChat s) =>
    politicaDe(s) == PoliticaSuperficie.liberado;

/// O papel de quem está no canal.
///
/// Vem do CANAL (documento autoritativo), nunca do payload. É a diferença entre
/// "o servidor sabe que você está sentado" e "você disse que está sentado".
enum PapelNoCanal {
  /// Ocupa assento na partida.
  jogadorSentado('jogador_sentado'),

  /// Assiste, sem assento.
  espectador('espectador'),

  /// Não está no canal. Inclui quem já saiu.
  foraDoCanal('fora_do_canal');

  final String wire;
  const PapelNoCanal(this.wire);
}

/// Versão do formato dos documentos de chat.
///
/// SOBE PARA 2 nesta correção. O `esquema: 1` acompanhava canais gravados com
/// `mesa_de_partida`, valor que deixou de existir; um leitor que encontre 1 está
/// olhando um documento cuja superfície não é mais interpretável.
const int kEsquemaChat = 2;
