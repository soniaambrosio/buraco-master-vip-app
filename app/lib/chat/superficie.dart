// superficie.dart — ONDE o chat livre existe, e onde ele NÃO existe.
//
// Este arquivo é uma CLASSIFICAÇÃO, não uma lista de desejos. A OS do Chat Livre
// Seguro §11 proíbe inventar superfície de produto e proíbe liberar por
// conveniência: cada superfície aqui tem um veredito, e o veredito de quem não
// tem decisão de produto é NÃO LIBERADO — nunca "liberado até alguém reclamar".
//
// POR QUE UM ENUM FECHADO, e não uma string de canal livre: a superfície decide
// se a mensagem existe. Se ela fosse texto vindo do cliente, inventar
// `superficie: "qualquer_coisa"` seria inventar um canal onde ninguém aplicou
// política nenhuma — e o padrão de quem inventa canal é justamente escapar do
// gate. Valor fora desta lista é entrada inválida, e entrada inválida é recusa.
//
// A CLASSIFICAÇÃO, com a evidência que a sustenta (§11):
//
//   mesaDePartida ......... LIBERADO. A decisão existe e é anterior a esta OS:
//                           `ChatMesa.completo` está nas TRÊS variantes de
//                           `TipoMesa` (publica, vip, privada) em
//                           app/lib/screens/configurar_mesa_screen.dart, e a
//                           mesa tem coluna de chat em app/lib/mesa.dart.
//                           Cobre as superfícies que a §11 lista como "mesa",
//                           "sala privada" e "VIP/Ranqueada": as três são a
//                           MESMA superfície técnica — uma partida com gente
//                           sentada — e diferem só no `TipoDePartida`, que é
//                           dado do canal e não outro lugar de conversa.
//
//   espectadorDeMesa ...... NÃO LIBERADO. Nenhuma decisão de produto diz que
//                           quem assiste conversa com quem joga, e a §11 é
//                           explícita ao proibir concluir isso automaticamente.
//                           Não liberado nas DUAS direções: espectador não fala
//                           e não recebe. Receber é metade de conversar, e
//                           liberar só a escuta entregaria a mesa a uma plateia
//                           que os jogadores não escolheram.
//
//   saguaoPublico ......... DECISÃO DE PRODUTO AUSENTE. Dois artefatos do
//                           próprio repositório apontam para longe do texto
//                           livre aqui: app/lib/screens/saguao_screen.dart
//                           anuncia "Converse por falas prontas · sem
//                           digitação", e o único controle de idade que existe
//                           (`chatPublicoSoMaiores`, em
//                           app/lib/screens/configuracoes_screen.dart) é uma
//                           preferência gravada em SharedPreferences pelo
//                           próprio aparelho — não há autoridade de idade
//                           NENHUMA no backend para sustentá-lo. Abrir texto
//                           livre num saguão público apoiado num interruptor que
//                           o usuário controla é o oposto de restringir.
//
// O que muda quando o produto decidir: acrescenta-se o valor e a política. O que
// NÃO se faz é reaproveitar `mesaDePartida` para um canal que não é mesa.

/// Onde a mensagem foi escrita.
///
/// `wire` é o valor que atravessa a fronteira. Nome de enum do Dart NÃO vai para
/// o Firestore: renomear o enum em Dart não pode reescrever documento gravado.
enum SuperficieChat {
  /// Uma partida com jogadores sentados. O canal é a partida.
  mesaDePartida('mesa_de_partida'),

  /// Quem assiste uma partida sem ocupar assento.
  espectadorDeMesa('espectador_de_mesa'),

  /// O saguão, fora de qualquer partida.
  saguaoPublico('saguao_publico');

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

/// O estado de uma superfície diante do chat livre.
enum PoliticaSuperficie {
  /// Há decisão de produto, e ela permite texto livre.
  liberado('liberado'),

  /// Há decisão de produto, e ela NÃO permite. Não é lacuna: é recusa.
  naoLiberado('nao_liberado'),

  /// Não há decisão de produto. Trata-se como recusa até que exista, e o nome é
  /// diferente de [naoLiberado] de propósito: um laudo precisa distinguir "o
  /// produto disse não" de "ninguém decidiu", porque só o segundo é pendência.
  decisaoAusente('decisao_ausente');

  final String wire;
  const PoliticaSuperficie(this.wire);
}

/// A classificação da §11. Fonte ÚNICA: quem quiser saber se há chat numa
/// superfície pergunta aqui, e não olha um `if` espalhado.
PoliticaSuperficie politicaDe(SuperficieChat s) => switch (s) {
      SuperficieChat.mesaDePartida => PoliticaSuperficie.liberado,
      SuperficieChat.espectadorDeMesa => PoliticaSuperficie.naoLiberado,
      SuperficieChat.saguaoPublico => PoliticaSuperficie.decisaoAusente,
    };

/// Texto livre pode nascer nesta superfície?
///
/// FALHA FECHADA por construção: só `liberado` responde `true`. Um valor novo no
/// enum [PoliticaSuperficie] não vira permissão por descuido.
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
const int kEsquemaChat = 1;
