// conjunto_real_vip.dart — o Tema Real VIP: o que ele exige, e a chave que o
// liga.
//
// ---------------------------------------------------------------------------
// O REGISTRO ESTÁ CUMPRIDO — OS 28 ARQUIVOS EXISTEM
// ---------------------------------------------------------------------------
//
// Este arquivo nasceu como REGISTRO de uma dívida: declarava exatamente quais
// arquivos o Tema Real precisava — nome, pasta, desenho previsto — e mantinha
// [kConjuntoRealVipRegistrado] em `false`, porque a arte não existia em ref
// nenhuma do repositório. Enquanto a chave era `false`, a resolução de tema
// devolvia o Tema Padrão para todo mundo, inclusive para o assinante VIP em dia.
// Isso nunca foi degradação: é a §7, fallback POR CONJUNTO.
//
// A dívida foi paga. Os 28 WebP lossless 256×256 com alfa real entraram em
// `app/assets/ajustes/real/`, o diretório foi declarado em `app/pubspec.yaml` e
// a origem de cada um está em `docs/ORIGEM-ICONES-TEMA-REAL.md`. A chave está em
// `true`, e o assinante VIP completo e vigente vê a tela luxuosa.
//
// ---------------------------------------------------------------------------
// A CHAVE NÃO É UM INTERRUPTOR DE APARÊNCIA
// ---------------------------------------------------------------------------
//
// [kConjuntoRealVipRegistrado] responde "esta build declara o conjunto?", e não
// "quem vê o quê". Quem vê é decidido por `resolverTemaDeAjustes`, e a chave é
// apenas a PRIMEIRA das duas condições: a segunda é
// [conjuntoRealDisponivel], que abre os 28 arquivos de verdade antes de a tela
// nascer. Virar a chave sem a arte não acende nada — só troca o motivo do
// fallback de `conjuntoNaoRegistrado` para `conjuntoIncompleto`.
//
// O portão de CI `temavip` guarda os dois lados: reprova quem virar a chave sem
// os arquivos, quem acrescentar arquivo sem chave, e quem deixar a tela sair
// metade dourada. Não há como ativar pela metade.
library;

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import 'iconografia_ajustes.dart';

/// O conjunto luxuoso está registrado nesta árvore?
///
/// `true` desde que os 28 arquivos aprovados entraram em
/// `app/assets/ajustes/real/` e o diretório foi declarado no `pubspec.yaml`.
///
/// Com ela desligada, ninguém — nem o assinante em dia — recebe o Tema Real, e a
/// tela inteira usa o Tema Padrão. É PROIBIDO virá-la sem os arquivos, e virá-la
/// não bastaria: [conjuntoRealDisponivel] ainda abre os 28 antes de decidir. O
/// gate `temavip` confere os dois lados.
const bool kConjuntoRealVipRegistrado = true;

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
