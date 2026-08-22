// navegacao_perfil_publico.dart — o ÚNICO lugar do aplicativo que decide de
// quem é o perfil que vai abrir.
//
// ---------------------------------------------------------------------------
// POR QUE UM ARQUIVO INTEIRO PARA UM `if`
// ---------------------------------------------------------------------------
//
// Porque este `if` é a fronteira entre duas autoridades diferentes, e errá-lo
// não produz uma tela feia: produz o perfil da pessoa errada, ou uma consulta
// remota sobre o próprio jogador feita pela porta reservada a terceiros.
//
//   souEu == true  -> `const PerfilPage()`, a cadeia do PROPRIETÁRIO. Lê o
//                     `EscopoRanking` que a casca já mantém, não emite chamada
//                     nenhuma de perfil público e mostra os controles de dono.
//   souEu == false -> `PerfilPage(publicIdVisitado: ...)`, a cadeia do VISITANTE.
//                     Consulta `consultarJogadorPorIdPublico` com o id que a
//                     autoridade emitiu, e só com ele.
//
// Espalhado por cada lista que um dia mostre jogadores, este `if` viraria N
// cópias, e a primeira que alguém escrevesse com `jogador.publicPlayerId ==
// minhaSessao.publicId` no lugar de `jogador.souEu` reabriria o defeito sem que
// nenhuma das outras percebesse. Um ponto só é o que torna a regra AUDITÁVEL:
// há um arquivo para ler, e um teste que afirma que ninguém mais constrói
// `PerfilPage`.
//
// ---------------------------------------------------------------------------
// O QUE ESTA FUNÇÃO SE PROÍBE DE FAZER
// ---------------------------------------------------------------------------
//
// Não compara apelido — dois jogadores podem ter o mesmo, e o backend publica
// `''` para quem não escolheu nenhum.
// Não compara posição — ela muda entre o desenho e o toque.
// Não compara `publicPlayerId` com o da sessão — parece a comparação certa e
// não é: `souEu` é calculado pelo servidor sobre o UID, que é o que de fato
// identifica a conta, e num intervalo de troca de sessão o `publicId` local já
// é o da conta nova enquanto a lista ainda é da antiga.
// Não vê UID, porque UID não chega até aqui.
//
// A ÚNICA coisa que ela confere por conta própria é se HÁ id, e só para o caso
// do terceiro: um id vazio não vira navegação, porque do outro lado ele viraria
// `invalid-argument` e a pessoa teria aberto uma tela para ver um erro. Não
// confere a FORMA — ver [JogadorPublicoRanking.temIdPublicoUtilizavel] para o
// motivo, que é o mesmo pelo qual este cliente não sabe cunhar identidade.

// ---------------------------------------------------------------------------
// POR QUE UM TIPO DE ALVO, E NÃO UMA SOBRECARGA POR ORIGEM
// ---------------------------------------------------------------------------
//
// O Perfil de terceiro passou a ser alcançável por três caminhos — a tabela do
// Ranking, um resultado da busca por apelido e uma linha das listas sociais. Um
// `abrir...` para cada um seria três cópias deste mesmo `if`, e a decisão
// deixaria de ter um lugar.
//
// [AlvoDePerfil] é o que impede isso: cada origem sabe traduzir a SUA projeção
// para os dois únicos fatos que a decisão precisa — é o próprio jogador, e qual
// é o identificador público —, e a tradução mora num construtor nomeado, onde a
// razão de cada uma pode ser lida e conferida. Quem navega não escolhe os dois
// campos soltos: escolhe a origem, e a origem responde.

import 'package:flutter/material.dart';

import '../amigos/estado_social.dart';
import '../pages/perfil_page.dart';
import '../ranking/ranking_transporte.dart' show JogadorPublicoRanking;

/// De quem é o Perfil que se quer abrir, reduzido ao que a decisão precisa.
///
/// DOIS CAMPOS, e nem um a mais. Nome, avatar, colocação e estado da relação
/// existem nas projeções de origem e não entram aqui de propósito: nenhum deles
/// participa da decisão, e ter um deles à mão é o começo de alguém decidir por
/// ele.
class AlvoDePerfil {
  /// A partir da projeção do RANKING.
  ///
  /// `souEu` vem calculado pelo servidor sobre o UID — ver o parágrafo acima
  /// sobre por que a comparação local de identificadores não serve.
  AlvoDePerfil.doRanking(JogadorPublicoRanking jogador)
    : souEu = jogador.souEu,
      publicPlayerId = jogador.publicPlayerId;

  /// A partir de um RESULTADO DE BUSCA.
  ///
  /// Aqui `souEu` também é do servidor: `projetarResultadosDeBusca` devolve a
  /// relação `euMesmo` quando o candidato é o próprio observador, e é o mesmo
  /// `uidObservador == uidAlvo` que decide isso do lado de lá.
  AlvoDePerfil.daBusca(ResultadoSocial resultado)
    : souEu = resultado.relacao == RelacaoSocial.euMesmo,
      publicPlayerId = resultado.jogador.publicId;

  /// A partir de uma linha das LISTAS SOCIAIS (amigos ou solicitações).
  ///
  /// `souEu: false` não é uma suposição de conveniência — é um invariante do
  /// banco. Uma relação de alguém consigo não pode existir: `avaliarSolicitacao`
  /// recusa `solicitanteUid == destinatarioUid` antes de qualquer coisa, e
  /// `chaveDoPar` LANÇA para um par de um jogador com ele mesmo, então nem por
  /// escrita direta há como criar o documento. Se a lista de amigos trouxesse o
  /// próprio jogador, o defeito estaria no servidor, e desenhá-lo aqui como
  /// terceiro seria o menor dos problemas.
  AlvoDePerfil.daListaSocial(JogadorPublico entrada)
    : souEu = false,
      publicPlayerId = entrada.publicId;

  /// É o próprio jogador autenticado? Decidido pela AUTORIDADE, sempre.
  final bool souEu;

  /// O identificador público do alvo. OPACO.
  final String publicPlayerId;

  /// Há id com que abrir o perfil de um terceiro?
  ///
  /// Só "trim não vazio", pelo mesmo motivo de
  /// [JogadorPublicoRanking.temIdPublicoUtilizavel]: conferir a FORMA seria uma
  /// cópia local da fórmula do servidor.
  bool get temIdPublicoUtilizavel => publicPlayerId.trim().isNotEmpty;
}

/// Abre o Perfil do [jogador], pela cadeia que a autoridade determinou.
///
/// Devolve `true` quando navegou. `false` é o caso do terceiro sem id
/// utilizável — e é silêncio de propósito: um aviso ali seria o aplicativo
/// culpando a pessoa por um dado que ela não escolheu e não pode corrigir.
Future<bool> abrirPerfilDoJogador(
  BuildContext context,
  AlvoDePerfil jogador,
) async {
  final navegador = Navigator.of(context);

  // O PRÓPRIO JOGADOR NUNCA PASSA PELA CALLABLE DE TERCEIRO.
  //
  // Este ramo vem primeiro e não olha o `publicPlayerId` de propósito: mesmo
  // que ele viesse vazio ou estranho, o perfil do dono não depende dele — a
  // identidade sai do escopo de sessão, e o ranking do escopo de ranking.
  // Testar a forma do id aqui criaria um caminho em que o dono fica sem perfil
  // por causa de um campo que a tela dele nem lê.
  if (jogador.souEu) {
    await navegador.push(
      MaterialPageRoute<void>(builder: (_) => const PerfilPage()),
    );
    return true;
  }

  if (!jogador.temIdPublicoUtilizavel) return false;

  await navegador.push(
    MaterialPageRoute<void>(
      // `publicIdVisitado` sozinho já significa "visitando": ver o construtor
      // de [PerfilPage]. Não há aqui um `ehMeuPerfil: false` a esquecer.
      builder: (_) => PerfilPage(publicIdVisitado: jogador.publicPlayerId),
    ),
  );
  return true;
}
