// iconografia_ajustes.dart — o contrato central dos ícones da tela de Ajustes.
//
// ---------------------------------------------------------------------------
// POR QUE UM CONTRATO, E NÃO UM `if (vip)` POR LINHA
// ---------------------------------------------------------------------------
//
// A tela de Ajustes desenha trinta e quatro ícones. A forma ingênua de dar um
// tema alternativo a ela é perguntar `vip ? luxuoso : padrao` em cada um deles —
// e é justamente essa forma que produz o defeito que a OS proíbe: basta UMA
// linha esquecida para a tela sair metade dourada e metade padrão, e nenhuma
// suíte de widget percebe, porque cada linha isolada continua correta.
//
// Aqui a pergunta é feita UMA VEZ, por quem monta a tela, e o resultado é um
// [ConjuntoDeIcones] inteiro. A tela pede o ícone pela CHAVE SEMÂNTICA
// ([IconeAjustes]) e nunca sabe que arquivo — ou que glifo — está por trás. Não
// existe caminho de código em que ela consiga misturar os dois conjuntos:
// misturar exigiria duas instâncias de [ConjuntoDeIcones] na mesma árvore, e a
// tela só recebe uma.
//
// ---------------------------------------------------------------------------
// AS CHAVES SÃO ESTÁVEIS, E DUAS FAMÍLIAS DELAS
// ---------------------------------------------------------------------------
//
// [IconeAjustes.variaveis] são as chaves que o Tema Real pode redesenhar: as
// dezesseis ações do §5 da OS, mais os cinco cabeçalhos de seção e as poucas
// linhas próprias desta tela.
//
// [IconeAjustes.invariantes] são as que ele NÃO pode: as setas e o `check` (são
// afordância de direção, não símbolo — dourar uma seta não a torna mais seta), e
// as duas ações destrutivas, `sair` e `excluirConta`, porque a §11.4 é explícita
// em que ação destrutiva não pode parecer prêmio VIP. Elas existem no contrato,
// e não fora dele, para que a varredura possa exigir que TODO ícone da tela
// venha daqui — uma chave que ficasse de fora seria exatamente o buraco por onde
// a mistura voltaria.
library;

import 'package:flutter/material.dart';

/// Cada ícone da tela de Ajustes, pela AÇÃO que ele nomeia.
///
/// Nome de chave é contrato: renomear um valor daqui quebra o conjunto padrão e
/// o conjunto real no mesmo commit, que é o comportamento desejado.
enum IconeAjustes {
  // --- §5 da OS: as ações que o Tema Real redesenha --------------------------
  editarPerfil,
  assinaturaVip,
  fichasECompras,
  musica,
  efeitosSonoros,
  vibracao,
  notificacoes,
  animacoes,
  ordenarCartas,
  mao,
  presencaOnline,
  convites,
  jogadoresBloqueados,
  comoJogar,
  suporte,
  avaliarAplicativo,

  // --- superfície própria desta tela, também redesenhável --------------------
  secaoConta,
  secaoSomENotificacoes,
  secaoJogo,
  secaoPrivacidade,
  secaoGeral,
  tituloAjustes,
  confirmarDescarte,
  chatPublico,
  idioma,
  termosEPrivacidade,
  orientacaoMesa,
  saldoDeFichas,

  // --- afordância e ação destrutiva: INVARIANTES entre os temas --------------
  voltar,
  avancar,
  expandir,
  confirmar,
  sair,
  excluirConta;

  /// As chaves que o Tema Real pode redesenhar.
  static const Set<IconeAjustes> variaveis = {
    editarPerfil,
    assinaturaVip,
    fichasECompras,
    musica,
    efeitosSonoros,
    vibracao,
    notificacoes,
    animacoes,
    ordenarCartas,
    mao,
    presencaOnline,
    convites,
    jogadoresBloqueados,
    comoJogar,
    suporte,
    avaliarAplicativo,
    secaoConta,
    secaoSomENotificacoes,
    secaoJogo,
    secaoPrivacidade,
    secaoGeral,
    tituloAjustes,
    confirmarDescarte,
    chatPublico,
    idioma,
    termosEPrivacidade,
    orientacaoMesa,
    saldoDeFichas,
  };

  /// As chaves que os dois temas desenham IGUAL, por decisão registrada.
  static Set<IconeAjustes> get invariantes =>
      values.toSet().difference(variaveis);

  bool get ehVariavel => variaveis.contains(this);
}

/// De onde sai o desenho de um ícone.
///
/// Duas formas, e só duas: glifo da fonte de ícones do framework, ou arquivo de
/// imagem empacotado no aplicativo. NÃO existe uma terceira que carregue por
/// URL — a §6 da OS proíbe, e a proibição vale por construção, não por revisão
/// de código: não há campo onde uma URL caberia.
@immutable
sealed class FonteDeIcone {
  const FonteDeIcone();
}

/// Glifo do `Icons` do Flutter. É o que o Tema Padrão usa em toda a tela.
@immutable
final class IconeMaterial extends FonteDeIcone {
  const IconeMaterial(this.dados);

  final IconData dados;

  @override
  bool operator ==(Object outro) =>
      outro is IconeMaterial && outro.dados == dados;

  @override
  int get hashCode => dados.hashCode;
}

/// Arquivo empacotado, endereçado pela chave de asset do `pubspec.yaml`.
///
/// [chave] é o caminho como o bundle o conhece (`assets/…`), não o caminho no
/// disco do repositório — são diferentes, e confundir os dois é o erro que faz
/// o ícone sumir só no aplicativo instalado.
@immutable
final class IconeDeAsset extends FonteDeIcone {
  const IconeDeAsset(this.chave);

  final String chave;

  @override
  bool operator ==(Object outro) =>
      outro is IconeDeAsset && outro.chave == chave;

  @override
  int get hashCode => chave.hashCode;
}

/// Erro de construção de um conjunto: falta chave.
class ConjuntoDeIconesIncompleto implements Exception {
  const ConjuntoDeIconesIncompleto(this.faltando);

  final Set<IconeAjustes> faltando;

  @override
  String toString() {
    final nomes = faltando.map((k) => k.name).toList()..sort();
    return 'ConjuntoDeIconesIncompleto: $nomes';
  }
}

/// Um tema de iconografia INTEIRO.
///
/// A completude é verificada na CONSTRUÇÃO, e é aí que mora a garantia da §7:
/// não existe conjunto meio pronto para a tela consumir. Um conjunto ao qual
/// falte uma chave não chega a existir — ele lança.
@immutable
class ConjuntoDeIcones {
  ConjuntoDeIcones(Map<IconeAjustes, FonteDeIcone> fontes)
      : _fontes = Map.unmodifiable(fontes) {
    final faltando =
        IconeAjustes.values.toSet().difference(_fontes.keys.toSet());
    if (faltando.isNotEmpty) throw ConjuntoDeIconesIncompleto(faltando);
  }

  final Map<IconeAjustes, FonteDeIcone> _fontes;

  /// A fonte de desenho de [chave].
  ///
  /// Nunca devolve nulo: se o conjunto existe, ele está completo.
  FonteDeIcone operator [](IconeAjustes chave) => _fontes[chave]!;

  Iterable<MapEntry<IconeAjustes, FonteDeIcone>> get entradas => _fontes.entries;

  /// As chaves de asset servidas por este conjunto. Vazio no Tema Padrão.
  Set<String> get assetsUsados => {
        for (final f in _fontes.values)
          if (f is IconeDeAsset) f.chave,
      };
}

/// Qual dos dois temas de iconografia está em vigor.
enum TemaIconografia { padrao, realVip }

/// O CONJUNTO PADRÃO — os ícones que o jogador público vê hoje.
///
/// Os valores são exatamente os que a tela usava antes desta OS, glifo a glifo.
/// Nenhum foi removido, substituído ou "melhorado": a §2.1 é explícita, e o
/// portão de CI compara esta tabela com a lista congelada.
final ConjuntoDeIcones conjuntoPadraoDeAjustes = ConjuntoDeIcones({
  IconeAjustes.editarPerfil: const IconeMaterial(Icons.edit_rounded),
  IconeAjustes.assinaturaVip:
      const IconeMaterial(Icons.workspace_premium_rounded),
  IconeAjustes.fichasECompras:
      const IconeMaterial(Icons.monetization_on_outlined),
  IconeAjustes.musica: const IconeMaterial(Icons.music_note_rounded),
  IconeAjustes.efeitosSonoros: const IconeMaterial(Icons.graphic_eq_rounded),
  IconeAjustes.vibracao: const IconeMaterial(Icons.vibration_rounded),
  IconeAjustes.notificacoes:
      const IconeMaterial(Icons.notifications_active_outlined),
  IconeAjustes.animacoes: const IconeMaterial(Icons.auto_awesome_motion_rounded),
  IconeAjustes.ordenarCartas: const IconeMaterial(Icons.sort_rounded),
  IconeAjustes.mao: const IconeMaterial(Icons.pan_tool_alt_outlined),
  IconeAjustes.presencaOnline: const IconeMaterial(Icons.visibility_outlined),
  IconeAjustes.convites: const IconeMaterial(Icons.person_add_alt_1_rounded),
  IconeAjustes.jogadoresBloqueados: const IconeMaterial(Icons.block_rounded),
  IconeAjustes.comoJogar: const IconeMaterial(Icons.menu_book_outlined),
  IconeAjustes.suporte: const IconeMaterial(Icons.support_agent_rounded),
  IconeAjustes.avaliarAplicativo: const IconeMaterial(Icons.star_rate_rounded),
  IconeAjustes.secaoConta: const IconeMaterial(Icons.person_outline_rounded),
  IconeAjustes.secaoSomENotificacoes:
      const IconeMaterial(Icons.volume_up_outlined),
  IconeAjustes.secaoJogo: const IconeMaterial(Icons.style_outlined),
  IconeAjustes.secaoPrivacidade: const IconeMaterial(Icons.shield_outlined),
  IconeAjustes.secaoGeral: const IconeMaterial(Icons.tune_rounded),
  IconeAjustes.tituloAjustes: const IconeMaterial(Icons.settings_rounded),
  IconeAjustes.confirmarDescarte: const IconeMaterial(Icons.fact_check_outlined),
  IconeAjustes.chatPublico: const IconeMaterial(Icons.forum_outlined),
  IconeAjustes.idioma: const IconeMaterial(Icons.language_rounded),
  IconeAjustes.termosEPrivacidade: const IconeMaterial(Icons.policy_outlined),
  IconeAjustes.orientacaoMesa:
      const IconeMaterial(Icons.screen_rotation_outlined),
  IconeAjustes.saldoDeFichas: const IconeMaterial(Icons.monetization_on_rounded),
  IconeAjustes.voltar: const IconeMaterial(Icons.chevron_left_rounded),
  IconeAjustes.avancar: const IconeMaterial(Icons.chevron_right_rounded),
  IconeAjustes.expandir: const IconeMaterial(Icons.expand_more_rounded),
  IconeAjustes.confirmar: const IconeMaterial(Icons.check_rounded),
  IconeAjustes.sair: const IconeMaterial(Icons.logout_rounded),
  IconeAjustes.excluirConta: const IconeMaterial(Icons.person_remove_outlined),
});

/// Desenha um ícone do conjunto, seja ele glifo ou arquivo.
///
/// SEMPRE DECORATIVO. Os dois ramos saem da árvore semântica — o glifo porque
/// `Icon` sem `semanticLabel` já não gera nó, o arquivo porque
/// `excludeFromSemantics` é passado explicitamente. É o que impede o leitor de
/// tela de anunciar o nome de um arquivo ao lado de "Assinatura VIP", e o que
/// faz o nome acessível ser IDÊNTICO nos dois temas: em ambos ele vem do texto.
class IconeDeAjustes extends StatelessWidget {
  const IconeDeAjustes({
    super.key,
    required this.conjunto,
    required this.chave,
    required this.cor,
    required this.tamanho,
  });

  final ConjuntoDeIcones conjunto;
  final IconeAjustes chave;
  final Color cor;
  final double tamanho;

  @override
  Widget build(BuildContext context) {
    final fonte = conjunto[chave];
    switch (fonte) {
      case IconeMaterial(:final dados):
        return Icon(dados, color: cor, size: tamanho);
      case IconeDeAsset(chave: final caminho):
        return Image.asset(
          caminho,
          width: tamanho,
          height: tamanho,
          fit: BoxFit.contain,
          excludeFromSemantics: true,
          // O tema é decisão de CONJUNTO, tomada antes da montagem (ver
          // `resolucao_tema_ajustes.dart`). Se mesmo assim um arquivo falhar
          // aqui, o buraco fica do tamanho do ícone e não derruba a tela: a §7
          // manda a falha não bloquear Ajustes.
          errorBuilder: (_, __, ___) => SizedBox(
            width: tamanho,
            height: tamanho,
          ),
        );
    }
  }
}
