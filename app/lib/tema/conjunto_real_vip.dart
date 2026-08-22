// conjunto_real_vip.dart — o Tema Real VIP: o que ele exige, e por que ele
// ainda não está ativo.
//
// ---------------------------------------------------------------------------
// ESTE ARQUIVO É UM REGISTRO, NÃO UMA PROMESSA
// ---------------------------------------------------------------------------
//
// O Tema Real é servido por ARQUIVO, e arquivo não se inventa em código. A §5 da
// OS descreve dezesseis desenhos ("pena ou espelho real", "diamante coroado",
// "lira dourada"…) e a §6 proíbe gerar ou incorporar ícone novo sem origem,
// aprovação e registro. Hoje o repositório não tem NENHUM deles: a varredura de
// `app/assets/` nas 203 refs remotas devolve doze diretórios — baralho, loja,
// perfil, ranking, torneios, coleções, início, configurar_mesa, hall, mesa_vip,
// splash, sons — e nenhum ícone de Ajustes em nenhum deles.
//
// Então este arquivo faz a única coisa honesta possível: declara EXATAMENTE
// quais arquivos o Tema Real precisa, com que nome, em que pasta, e deixa
// [kConjuntoRealVipRegistrado] em `false`. Enquanto ele for `false`, a
// resolução de tema devolve o Tema Padrão para todo mundo — inclusive para o
// assinante VIP em dia. Não é degradação: é a §7, fallback POR CONJUNTO.
//
// ---------------------------------------------------------------------------
// COMO ATIVAR, NO DIA EM QUE OS DESENHOS EXISTIREM
// ---------------------------------------------------------------------------
//
//   1. colocar os 28 arquivos em `app/assets/ajustes/real/`, com os nomes de
//      [arquivosExigidos] — nome estável, sem texto embutido, fundo
//      transparente, legível em 18 px sobre fundo escuro;
//   2. declarar `assets/ajustes/real/` em `app/pubspec.yaml` — NÃO está lá
//      hoje, e não pode estar: o Flutter reprova o build quando um diretório
//      declarado não existe, então declarar antes da arte quebraria a árvore
//      inteira por causa de um tema que ninguém ainda vê;
//   3. registrar a origem de cada arquivo em `docs/ORIGEM-ICONES-TEMA-REAL.md`;
//   4. virar [kConjuntoRealVipRegistrado] para `true`, no MESMO commit.
//
// O portão de CI `temavip` reprova quem virar a chave sem os arquivos, e reprova
// quem acrescentar arquivo sem chave. Não há como ativar pela metade.
library;

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import 'iconografia_ajustes.dart';

/// O conjunto luxuoso está registrado nesta árvore?
///
/// `false` enquanto os arquivos da §5 não existirem. É a chave da §7: com ela
/// desligada, ninguém — nem o assinante em dia — recebe o Tema Real, e a tela
/// inteira usa o Tema Padrão. É PROIBIDO virá-la sem os arquivos; o gate
/// `temavip` confere os dois lados.
const bool kConjuntoRealVipRegistrado = false;

/// Onde os arquivos do Tema Real moram no bundle.
///
/// Prefixo de CHAVE DE ASSET (o que o `rootBundle` conhece), e não caminho de
/// disco: no repositório eles ficam em `app/assets/ajustes/real/`.
const String kPrefixoAssetsReais = 'assets/ajustes/real/';

/// Nome de arquivo de cada chave variável.
///
/// A tabela é a lista de compras da §5, e é ela que o gate de CI percorre. Os
/// nomes são derivados da CHAVE, não do desenho — "diamante coroado" pode virar
/// "coroa com diamante" na segunda versão da arte sem que uma linha de código
/// mude, e é para isso que o nome do arquivo acompanha a ação, não o motivo.
const Map<IconeAjustes, String> arquivosDoTemaReal = {
  IconeAjustes.editarPerfil: 'editar_perfil.webp',
  IconeAjustes.assinaturaVip: 'assinatura_vip.webp',
  IconeAjustes.fichasECompras: 'fichas_e_compras.webp',
  IconeAjustes.musica: 'musica.webp',
  IconeAjustes.efeitosSonoros: 'efeitos_sonoros.webp',
  IconeAjustes.vibracao: 'vibracao.webp',
  IconeAjustes.notificacoes: 'notificacoes.webp',
  IconeAjustes.animacoes: 'animacoes.webp',
  IconeAjustes.ordenarCartas: 'ordenar_cartas.webp',
  IconeAjustes.mao: 'mao.webp',
  IconeAjustes.presencaOnline: 'presenca_online.webp',
  IconeAjustes.convites: 'convites.webp',
  IconeAjustes.jogadoresBloqueados: 'jogadores_bloqueados.webp',
  IconeAjustes.comoJogar: 'como_jogar.webp',
  IconeAjustes.suporte: 'suporte.webp',
  IconeAjustes.avaliarAplicativo: 'avaliar_aplicativo.webp',
  IconeAjustes.secaoConta: 'secao_conta.webp',
  IconeAjustes.secaoSomENotificacoes: 'secao_som_e_notificacoes.webp',
  IconeAjustes.secaoJogo: 'secao_jogo.webp',
  IconeAjustes.secaoPrivacidade: 'secao_privacidade.webp',
  IconeAjustes.secaoGeral: 'secao_geral.webp',
  IconeAjustes.tituloAjustes: 'titulo_ajustes.webp',
  IconeAjustes.confirmarDescarte: 'confirmar_descarte.webp',
  IconeAjustes.chatPublico: 'chat_publico.webp',
  IconeAjustes.idioma: 'idioma.webp',
  IconeAjustes.termosEPrivacidade: 'termos_e_privacidade.webp',
  IconeAjustes.orientacaoMesa: 'orientacao_mesa.webp',
  IconeAjustes.saldoDeFichas: 'saldo_de_fichas.webp',
};

/// As chaves de asset que o Tema Real exige, na ordem das chaves.
List<String> get chavesDeAssetDoTemaReal => [
      for (final chave in IconeAjustes.values)
        if (arquivosDoTemaReal[chave] case final nome?)
          '$kPrefixoAssetsReais$nome',
    ];

/// Os caminhos NO REPOSITÓRIO, para quem confere disco (o gate de CI).
List<String> get arquivosExigidos =>
    [for (final chave in chavesDeAssetDoTemaReal) 'app/$chave'];

/// O CONJUNTO REAL VIP.
///
/// As chaves variáveis vêm de arquivo; as invariantes repetem, de propósito, o
/// glifo do Tema Padrão — ver a §11.4 sobre `sair` e `excluirConta` e o
/// cabeçalho de [IconeAjustes] sobre as setas.
final ConjuntoDeIcones conjuntoRealVipDeAjustes = ConjuntoDeIcones({
  for (final chave in IconeAjustes.values)
    chave: _fonteReal(chave),
});

FonteDeIcone _fonteReal(IconeAjustes chave) {
  final nome = arquivosDoTemaReal[chave];
  if (nome == null) return conjuntoPadraoDeAjustes[chave];
  return IconeDeAsset('$kPrefixoAssetsReais$nome');
}

/// O conjunto luxuoso está INTEIRO neste bundle?
///
/// Carrega os arquivos, um a um, e só responde `true` se TODOS abrirem. É a
/// pré-checagem que sustenta a §7: a decisão de tema acontece antes da montagem
/// da tela, então não existe o estado "meia tela dourada" — se um arquivo falta,
/// a resposta é `false` e a tela inteira nasce padrão.
///
/// Devolve `false` — nunca lança — em qualquer falha: arquivo ausente, ilegível
/// ou vazio. O diagnóstico fica com quem chama, sanitizado.
Future<bool> conjuntoRealDisponivel({
  AssetBundle? bundle,
  bool registrado = kConjuntoRealVipRegistrado,
}) async {
  if (!registrado) return false;
  final b = bundle ?? rootBundle;
  for (final chave in chavesDeAssetDoTemaReal) {
    try {
      final dados = await b.load(chave);
      if (dados.lengthInBytes == 0) return false;
    } catch (_) {
      return false;
    }
  }
  return true;
}
