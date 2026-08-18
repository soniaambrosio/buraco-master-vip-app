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

import 'package:flutter/material.dart';

import '../pages/perfil_page.dart';
import '../ranking/ranking_transporte.dart' show JogadorPublicoRanking;

/// Abre o Perfil do [jogador], pela cadeia que a autoridade determinou.
///
/// Devolve `true` quando navegou. `false` é o caso do terceiro sem id
/// utilizável — e é silêncio de propósito: um aviso ali seria o aplicativo
/// culpando a pessoa por um dado que ela não escolheu e não pode corrigir.
Future<bool> abrirPerfilDoJogador(
  BuildContext context,
  JogadorPublicoRanking jogador,
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
