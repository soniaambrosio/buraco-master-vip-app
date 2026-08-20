// catalogo.dart — O QUE PODE SER DITO nos ambientes controlados.
//
// Nos quatro ambientes controlados (Saguão Público, Salão VIP, Mesa Pública e
// Mesa VIP) o jogador não escreve: ele ESCOLHE. E o que ele escolhe viaja como
// um IDENTIFICADOR, nunca como a frase.
//
// ===========================================================================
// POR QUE O ID, E NÃO A FRASE — as três razões, e todas são concretas
// ===========================================================================
//
//  1. LOCALIZAÇÃO (§6.3). `convite_dupla_01` chega ao aparelho de cada um e
//     cada um lê no SEU idioma. Se viajasse "Vamos fazer dupla?", o jogador
//     português mandaria português para o mexicano, e a única saída seria
//     traduzir texto de jogador em tempo real — que é caro, é errado com gíria
//     e é impossível de moderar.
//
//  2. MODERAÇÃO (§9.5). Denunciar uma fala catalogada preserva `itemId` e a
//     VERSÃO do catálogo. Com isso, quem tria sabe exatamente o que foi dito e
//     quantas vezes, mesmo que o catálogo tenha mudado depois. Com a frase, a
//     evidência seria uma string que ninguém sabe se foi editada.
//
//  3. CONTROLE (§6.2). "Não aceitar texto exibível enviado como substituto do
//     ID". Um campo de texto aceito "só para o fallback" é um campo de texto
//     livre com outro nome — e ele estaria aberto nos quatro ambientes que esta
//     OS existe para fechar.
//
// ===========================================================================
// O CATÁLOGO É CÓDIGO, E ISSO É DECISÃO
// ===========================================================================
//
// Ele poderia morar numa coleção do Firestore. Não mora, por três motivos:
//
//   * o catálogo é REGRA (o que pode ser dito onde), e regra deste projeto mora
//     no domínio Dart, compilado para o Node — a mesma disciplina de
//     app/lib/moderacao/ e app/lib/chat/;
//   * um catálogo em banco precisaria de regras de escrita, de auditoria de
//     quem editou e de cache — três superfícies novas para um dado que muda
//     em release, não em tempo de jogo;
//   * versionar em código dá `git blame`: por que este item foi desativado, e
//     quando, fica escrito ao lado do item.
//
// O QUE MUDA QUANDO O PRODUTO QUISER MEXER: sobe [kVersaoDoCatalogo], e os
// clientes antigos continuam funcionando porque cada item declara a versão
// mínima que sabe renderizá-lo.

import 'ambiente.dart';
import 'evento.dart';

/// Versão do catálogo. Viaja com cada evento gravado e com cada denúncia.
///
/// SOBE quando itens entram, saem ou mudam de política. NÃO sobe quando só o
/// texto de fallback é corrigido — o significado é a chave de localização, e
/// ela não mudou.
const int kVersaoDoCatalogo = 1;

/// As categorias aprovadas nos protótipos (§6.4), preservadas ao pé da letra.
///
/// Elas são ATALHOS de intenção, e a §6.4 é explícita: "Essas categorias são
/// atalhos. Não liberam digitação."
enum CategoriaDeComunicacao {
  provocar('provocar'),
  elogiar('elogiar'),
  chamarParaJogo('chamar_para_jogo'),
  reacao('reacao'),
  emoji('emoji');

  final String wire;
  const CategoriaDeComunicacao(this.wire);
}

/// O direito que um item premium exige.
///
/// UM valor além de [nenhum], e não uma lista aberta: `vip` é o único direito
/// que existe neste projeto. Inventar `vip_ouro` aqui criaria produto que
/// ninguém decidiu e que o Billing não sabe conceder.
///
/// A VIGÊNCIA NÃO É DECIDIDA AQUI. Quem responde "este jogador tem VIP agora?"
/// é `EntitlementVip.vigenteEm` (app/lib/elegibilidade/entitlement.dart), que é
/// a definição ÚNICA de vigência no projeto e já é consumida pelo Billing, pela
/// Loja e pela elegibilidade. Este arquivo só diz QUAL direito o item exige.
enum DireitoDeComunicacao {
  nenhum('nenhum'),
  vip('vip');

  final String wire;
  const DireitoDeComunicacao(this.wire);
}

/// Um item do catálogo autoritativo (§6.2).
class ItemCatalogado {
  /// ID ESTÁVEL. Fica gravado em mensagem e em denúncia; renomear é mudança de
  /// contrato, e o item antigo teria de continuar existindo.
  final String id;

  /// Que espécie de comunicação este item produz.
  final TipoDeComunicacao tipo;

  final CategoriaDeComunicacao categoria;

  /// Item inativo é RECUSADO, e não escondido. Some da tela e para de ser
  /// aceito — as duas coisas, senão um cliente antigo continuaria mandando.
  final bool ativo;

  /// Onde este item pode ser usado. Conjunto FECHADO: ambiente fora da lista é
  /// recusa (`itemForaDoAmbiente`), nunca permissão por omissão.
  final Set<AmbienteDeComunicacao> ambientes;

  /// A menor versão de catálogo que sabe renderizar este item.
  ///
  /// Serve ao cliente ANTIGO: ele declara a versão que conhece, e um item novo
  /// demais é recusado antes de virar um balão em branco na tela dele.
  final int versaoMinima;

  /// O direito exigido. [DireitoDeComunicacao.nenhum] é a maioria.
  final DireitoDeComunicacao direitoExigido;

  /// A chave que o cliente usa para achar a tradução. É o SIGNIFICADO.
  final String chaveDeLocalizacao;

  /// O texto OFICIAL, em pt-BR, de quem não tem tradução para o idioma do
  /// aparelho (§6.3: "fallback oficial, nunca texto inventado pelo remetente").
  ///
  /// Ele viaja na projeção junto com a chave. Isso é deliberado: o cliente que
  /// não conhece a chave (porque é mais antigo que o item) ainda mostra algo
  /// correto, e o que ele mostra veio da AUTORIDADE, não de quem falou.
  final String fallbackOficial;

  /// Nome do recurso visual (ícone, sprite, animação). `null` quando a fala é
  /// só texto. Esta OS não cria arte nenhuma: o campo existe para que a OS
  /// visual tenha onde declarar o que já existir.
  final String? recursoVisual;

  /// Intervalo mínimo entre dois usos DESTE item pelo mesmo jogador (§6.2,
  /// "limite de frequência"). Zero significa "só o limite geral se aplica".
  final Duration cooldown;

  /// Quando o item saiu do ar. Documental: fica junto do `ativo: false` para
  /// que a arqueologia de uma denúncia antiga saiba se o item existia à época.
  final String? desativadoEm;

  const ItemCatalogado({
    required this.id,
    required this.tipo,
    required this.categoria,
    required this.ambientes,
    required this.chaveDeLocalizacao,
    required this.fallbackOficial,
    this.ativo = true,
    this.versaoMinima = 1,
    this.direitoExigido = DireitoDeComunicacao.nenhum,
    this.recursoVisual,
    this.cooldown = Duration.zero,
    this.desativadoEm,
  });

  bool get premium => direitoExigido != DireitoDeComunicacao.nenhum;

  bool liberadoEm(AmbienteDeComunicacao ambiente) => ambientes.contains(ambiente);

  Map<String, Object?> toJson() => {
        'id': id,
        'tipo': tipo.wire,
        'categoria': categoria.wire,
        'ativo': ativo,
        'ambientes': [for (final a in ambientes) a.wire]..sort(),
        'versaoMinima': versaoMinima,
        'direitoExigido': direitoExigido.wire,
        'chaveDeLocalizacao': chaveDeLocalizacao,
        'fallbackOficial': fallbackOficial,
        if (recursoVisual != null) 'recursoVisual': recursoVisual,
        'cooldownMs': cooldown.inMilliseconds,
        if (desativadoEm != null) 'desativadoEm': desativadoEm,
      };
}

/// Conjuntos de ambientes usados mais de uma vez. Nomeados para que a intenção
/// apareça na declaração do item em vez de um literal repetido.
const Set<AmbienteDeComunicacao> _todosOnline = {
  AmbienteDeComunicacao.saguaoPublico,
  AmbienteDeComunicacao.salaoVip,
  AmbienteDeComunicacao.mesaPublica,
  AmbienteDeComunicacao.mesaVip,
  AmbienteDeComunicacao.mesaPrivada,
};

const Set<AmbienteDeComunicacao> _mesas = {
  AmbienteDeComunicacao.mesaPublica,
  AmbienteDeComunicacao.mesaVip,
  AmbienteDeComunicacao.mesaPrivada,
};

const Set<AmbienteDeComunicacao> _saguoes = {
  AmbienteDeComunicacao.saguaoPublico,
  AmbienteDeComunicacao.salaoVip,
};

/// Onde os itens premium valem: os ambientes cuja porta de entrada já é VIP.
///
/// O Saguão Público está FORA de propósito. Não por regra de negócio nova, e
/// sim porque um item premium ali seria vitrine: quem não tem direito veria a
/// recusa toda vez, e quem tem exibiria o selo para uma plateia que não pediu.
const Set<AmbienteDeComunicacao> _premium = {
  AmbienteDeComunicacao.salaoVip,
  AmbienteDeComunicacao.mesaVip,
  AmbienteDeComunicacao.mesaPrivada,
};

/// O CATÁLOGO V1.
///
/// Pequeno de propósito. A §16 põe "novos emojis" fora do escopo desta OS: o
/// que se entrega aqui é a AUTORIDADE que valida itens, com um acervo inicial
/// coerente com as categorias já aprovadas. Ampliar o acervo é trabalho de
/// produto, e agora tem onde acontecer.
const List<ItemCatalogado> catalogoV1 = [
  // ------------------------------------------------------------- provocar
  ItemCatalogado(
    id: 'provocar_agora_complicou_01',
    tipo: TipoDeComunicacao.falaCatalogada,
    categoria: CategoriaDeComunicacao.provocar,
    ambientes: _mesas,
    chaveDeLocalizacao: 'comunicacao.fala.provocar_agora_complicou_01',
    fallbackOficial: 'Agora complicou!',
    cooldown: Duration(seconds: 20),
  ),
  ItemCatalogado(
    id: 'provocar_essa_doeu_01',
    tipo: TipoDeComunicacao.falaCatalogada,
    categoria: CategoriaDeComunicacao.provocar,
    ambientes: _mesas,
    chaveDeLocalizacao: 'comunicacao.fala.provocar_essa_doeu_01',
    fallbackOficial: 'Essa doeu!',
    cooldown: Duration(seconds: 20),
  ),
  // DESATIVADO. Estava no protótipo do saguão e não sobreviveu à revisão: sem
  // alvo declarado, "só na conversa" lida como provocação a quem não escolheu
  // participar. Fica no catálogo, inativo, porque denúncia antiga pode
  // referenciá-lo — apagar o item apagaria a evidência.
  ItemCatalogado(
    id: 'provocar_so_na_conversa_01',
    tipo: TipoDeComunicacao.falaCatalogada,
    categoria: CategoriaDeComunicacao.provocar,
    ambientes: _saguoes,
    ativo: false,
    desativadoEm: '2026-08-20T00:00:00.000Z',
    chaveDeLocalizacao: 'comunicacao.fala.provocar_so_na_conversa_01',
    fallbackOficial: 'Só na conversa, hein?',
  ),
  // PREMIUM. Fora do Saguão Público (ver `_premium`).
  ItemCatalogado(
    id: 'provocar_realeza_manda_01',
    tipo: TipoDeComunicacao.falaCatalogada,
    categoria: CategoriaDeComunicacao.provocar,
    ambientes: _premium,
    direitoExigido: DireitoDeComunicacao.vip,
    chaveDeLocalizacao: 'comunicacao.fala.provocar_realeza_manda_01',
    fallbackOficial: 'A realeza manda lembranças.',
    recursoVisual: 'balao_realeza',
    cooldown: Duration(seconds: 30),
  ),

  // -------------------------------------------------------------- elogiar
  ItemCatalogado(
    id: 'elogiar_boa_jogada_01',
    tipo: TipoDeComunicacao.falaCatalogada,
    categoria: CategoriaDeComunicacao.elogiar,
    ambientes: _todosOnline,
    chaveDeLocalizacao: 'comunicacao.fala.elogiar_boa_jogada_01',
    fallbackOficial: 'Boa jogada!',
    cooldown: Duration(seconds: 10),
  ),
  ItemCatalogado(
    id: 'elogiar_parceria_01',
    tipo: TipoDeComunicacao.falaCatalogada,
    categoria: CategoriaDeComunicacao.elogiar,
    ambientes: _mesas,
    chaveDeLocalizacao: 'comunicacao.fala.elogiar_parceria_01',
    fallbackOficial: 'Bem jogado, parceiro!',
    cooldown: Duration(seconds: 10),
  ),

  // ------------------------------------------------------ chamar para jogo
  //
  // SÓ NOS SAGUÕES, e é o exemplo que a própria §6.3 usa (`convite_dupla_01`).
  // Convidar para uma mesa de dentro da mesa em que já se joga não é um
  // convite: é ruído. O recorte de ambiente serve, aqui, ao produto — e serve
  // também de prova de que a lista de ambientes é aplicada.
  ItemCatalogado(
    id: 'convite_dupla_01',
    tipo: TipoDeComunicacao.falaCatalogada,
    categoria: CategoriaDeComunicacao.chamarParaJogo,
    ambientes: _saguoes,
    chaveDeLocalizacao: 'comunicacao.fala.convite_dupla_01',
    fallbackOficial: 'Vamos fazer dupla?',
    cooldown: Duration(seconds: 60),
  ),
  ItemCatalogado(
    id: 'convite_mesa_agora_01',
    tipo: TipoDeComunicacao.falaCatalogada,
    categoria: CategoriaDeComunicacao.chamarParaJogo,
    ambientes: _saguoes,
    chaveDeLocalizacao: 'comunicacao.fala.convite_mesa_agora_01',
    fallbackOficial: 'Abrindo mesa agora!',
    cooldown: Duration(seconds: 60),
  ),

  // --------------------------------------------------------------- reação
  ItemCatalogado(
    id: 'reacao_aplauso_01',
    tipo: TipoDeComunicacao.reacaoCatalogada,
    categoria: CategoriaDeComunicacao.reacao,
    ambientes: _todosOnline,
    chaveDeLocalizacao: 'comunicacao.reacao.aplauso',
    fallbackOficial: 'Aplaudiu',
    recursoVisual: 'reacao_aplauso',
    cooldown: Duration(seconds: 5),
  ),
  ItemCatalogado(
    id: 'reacao_risada_01',
    tipo: TipoDeComunicacao.reacaoCatalogada,
    categoria: CategoriaDeComunicacao.reacao,
    ambientes: _todosOnline,
    chaveDeLocalizacao: 'comunicacao.reacao.risada',
    fallbackOficial: 'Riu',
    recursoVisual: 'reacao_risada',
    cooldown: Duration(seconds: 5),
  ),
  ItemCatalogado(
    id: 'reacao_coroa_dourada_01',
    tipo: TipoDeComunicacao.reacaoCatalogada,
    categoria: CategoriaDeComunicacao.reacao,
    ambientes: _premium,
    direitoExigido: DireitoDeComunicacao.vip,
    chaveDeLocalizacao: 'comunicacao.reacao.coroa_dourada',
    fallbackOficial: 'Coroou a jogada',
    recursoVisual: 'reacao_coroa_dourada',
    cooldown: Duration(seconds: 15),
  ),

  // ---------------------------------------------------------------- emoji
  ItemCatalogado(
    id: 'emoji_joia_01',
    tipo: TipoDeComunicacao.emojiCatalogado,
    categoria: CategoriaDeComunicacao.emoji,
    ambientes: _todosOnline,
    chaveDeLocalizacao: 'comunicacao.emoji.joia',
    fallbackOficial: 'Joia',
    recursoVisual: 'emoji_joia',
    cooldown: Duration(seconds: 3),
  ),
  ItemCatalogado(
    id: 'emoji_carta_01',
    tipo: TipoDeComunicacao.emojiCatalogado,
    categoria: CategoriaDeComunicacao.emoji,
    ambientes: _todosOnline,
    chaveDeLocalizacao: 'comunicacao.emoji.carta',
    fallbackOficial: 'Carta',
    recursoVisual: 'emoji_carta',
    cooldown: Duration(seconds: 3),
  ),
  ItemCatalogado(
    id: 'emoji_coroa_01',
    tipo: TipoDeComunicacao.emojiCatalogado,
    categoria: CategoriaDeComunicacao.emoji,
    ambientes: _premium,
    direitoExigido: DireitoDeComunicacao.vip,
    chaveDeLocalizacao: 'comunicacao.emoji.coroa',
    fallbackOficial: 'Coroa',
    recursoVisual: 'emoji_coroa',
    cooldown: Duration(seconds: 10),
  ),
];

/// Índice por id. Construído uma vez.
final Map<String, ItemCatalogado> _porId = {
  for (final i in catalogoV1) i.id: i,
};

/// O item, ou `null` quando o id não existe.
///
/// NÃO devolve um item "padrão" e não inventa nada: id desconhecido é recusa,
/// e a recusa distingue `itemDesconhecido` de `itemDesativado` justamente
/// porque as duas contam histórias diferentes sobre quem pediu.
ItemCatalogado? itemPorId(Object? id) {
  if (id is! String) return null;
  return _porId[id];
}

// ===========================================================================
// EVENTOS DE SISTEMA (§8)
// ===========================================================================
//
// Catálogo SEPARADO, e a separação é a §8 inteira: nenhum destes é pedido por
// jogador. Se morassem na mesma lista dos itens, o primeiro caminho que
// aceitasse `itemId` de jogador aceitaria também `sistema_presente_disponivel`
// — e "Pegue seu presente" passaria a ser digitável por qualquer um, que é
// exatamente a fraude que a §8 nomeia.
//
// ESTA OS NÃO CRIA PRESENTE, não move carteira e não concede assinatura. Ela
// reconhece o TIPO de evento, valida a ORIGEM e projeta a intenção localizada.
// Quem produz o fato continua sendo a autoridade de Presentes, de Moderação ou
// de Salas.

/// Um evento que só a autoridade emite.
class EventoDeSistemaCatalogado {
  final String id;
  final String chaveDeLocalizacao;
  final String fallbackOficial;

  /// Onde este evento pode aparecer.
  final Set<AmbienteDeComunicacao> ambientes;

  const EventoDeSistemaCatalogado({
    required this.id,
    required this.chaveDeLocalizacao,
    required this.fallbackOficial,
    required this.ambientes,
  });

  Map<String, Object?> toJson() => {
        'id': id,
        'chaveDeLocalizacao': chaveDeLocalizacao,
        'fallbackOficial': fallbackOficial,
        'ambientes': [for (final a in ambientes) a.wire]..sort(),
      };
}

/// Os eventos de sistema da §8, um a um.
const List<EventoDeSistemaCatalogado> catalogoDeEventosDeSistema = [
  EventoDeSistemaCatalogado(
    id: 'sistema_presente_disponivel',
    chaveDeLocalizacao: 'comunicacao.sistema.presente_disponivel',
    // O texto que a §8 cita nominalmente. Ele NASCE aqui, do catálogo da
    // autoridade, e é localizado pelo cliente — nunca digitado por um jogador.
    fallbackOficial: 'Pegue seu presente!',
    ambientes: _todosOnline,
  ),
  EventoDeSistemaCatalogado(
    id: 'sistema_presente_recebido',
    chaveDeLocalizacao: 'comunicacao.sistema.presente_recebido',
    fallbackOficial: 'Você recebeu um presente.',
    ambientes: _todosOnline,
  ),
  EventoDeSistemaCatalogado(
    id: 'sistema_resgate_concluido',
    chaveDeLocalizacao: 'comunicacao.sistema.resgate_concluido',
    fallbackOficial: 'Resgate concluído.',
    ambientes: _todosOnline,
  ),
  EventoDeSistemaCatalogado(
    id: 'sistema_convite_oficial',
    chaveDeLocalizacao: 'comunicacao.sistema.convite_oficial',
    fallbackOficial: 'Convite oficial disponível.',
    ambientes: _saguoes,
  ),
  EventoDeSistemaCatalogado(
    id: 'sistema_jogador_entrou',
    chaveDeLocalizacao: 'comunicacao.sistema.jogador_entrou',
    fallbackOficial: 'Um jogador entrou.',
    ambientes: _mesas,
  ),
  EventoDeSistemaCatalogado(
    id: 'sistema_jogador_saiu',
    chaveDeLocalizacao: 'comunicacao.sistema.jogador_saiu',
    fallbackOficial: 'Um jogador saiu.',
    ambientes: _mesas,
  ),
  EventoDeSistemaCatalogado(
    id: 'sistema_acao_de_moderacao',
    chaveDeLocalizacao: 'comunicacao.sistema.acao_de_moderacao',
    // NÃO diz de quem, e não diz o quê. Sanção de terceiro é dado
    // administrativo, e a §11 proíbe publicá-lo.
    fallbackOficial: 'Uma ação de moderação foi aplicada.',
    ambientes: _todosOnline,
  ),
  EventoDeSistemaCatalogado(
    id: 'sistema_sala_encerrada',
    chaveDeLocalizacao: 'comunicacao.sistema.sala_encerrada',
    fallbackOficial: 'A sala foi encerrada.',
    ambientes: _mesas,
  ),
];

final Map<String, EventoDeSistemaCatalogado> _eventosPorId = {
  for (final e in catalogoDeEventosDeSistema) e.id: e,
};

EventoDeSistemaCatalogado? eventoDeSistemaPorId(Object? id) {
  if (id is! String) return null;
  return _eventosPorId[id];
}
