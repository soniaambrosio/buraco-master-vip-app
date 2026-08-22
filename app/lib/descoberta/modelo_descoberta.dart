// modelo_descoberta.dart — o retrato da descoberta, TIPADO.
//
// ---------------------------------------------------------------------------
// POR QUE A UI NÃO LÊ O MAPA CRU
// ---------------------------------------------------------------------------
//
// `Map<String, dynamic>` numa tela custa caro de três jeitos, e os três já
// aconteceram neste aplicativo:
//
//   1. `m['jogadores'] as int` estoura em produção quando o campo vem nulo, e
//      o teste que "passou" usava um mapa escrito à mão que sempre tinha o
//      campo;
//   2. cada tela conclui por conta própria o que significa um campo ausente, e
//      duas telas concluem coisas diferentes a partir do mesmo nada;
//   3. um campo novo do servidor — inclusive um que NÃO deveria estar ali —
//      atravessa até a tela sem que ninguém precise ter decidido nada.
//
// Aqui a decisão acontece UMA vez, na fronteira (`adaptador_descoberta.dart`),
// e o que sai dela é imutável e completo. Se um retrato não pôde ser
// construído, ele não existe — não existe meio-retrato.
//
// ---------------------------------------------------------------------------
// A ÚNICA TRADUÇÃO `sbtl` → `STBL` DO APLICATIVO
// ---------------------------------------------------------------------------
//
// `ModalidadeDeMesa.chave` é o que trafega. `ModalidadeDeMesa.rotulo` é o que a
// jogadora lê. Nenhuma tela, filtro, semântica ou mensagem de erro deve montar
// esse texto por conta própria: quem quiser exibir modalidade lê `rotulo`.
//
// É por isso que a chave é `private` para efeito de apresentação — não existe
// caminho conveniente para imprimir `sbtl` sem escrever `.chave`, e a suíte
// varre o código-fonte procurando exatamente isso.

import 'contrato_descoberta.dart';

/// As três modalidades do motor. A lista é FECHADA: modalidade desconhecida
/// recusa o retrato inteiro, e não vira "outra".
enum ModalidadeDeMesa {
  aberto('aberto', 'Aberto'),
  fechado('fechado', 'Fechado'),

  /// A modalidade-mãe. O motor a chama de `sbtl`; a jogadora a conhece como
  /// STBL, e é STBL que aparece em toda superfície visível.
  sbtl('sbtl', 'STBL');

  const ModalidadeDeMesa(this.chave, this.rotulo);

  /// Como o servidor a nomeia. Só o transporte e o adaptador usam isto.
  final String chave;

  /// Como a jogadora a lê. Todo texto visível vem daqui.
  final String rotulo;

  /// `null` para chave desconhecida — quem chama decide, e no adaptador a
  /// decisão é recusar o retrato.
  static ModalidadeDeMesa? daChave(String? chave) {
    for (final m in ModalidadeDeMesa.values) {
      if (m.chave == chave) return m;
    }
    return null;
  }
}

/// Estado de ingresso de uma mesa. Enumeração FECHADA (contrato §estadoIngresso).
enum EstadoDeIngresso {
  /// Não iniciada e com vaga. É a única que aceita ingresso.
  aguardando('aguardando', 'Aguardando jogadores'),

  /// Não iniciada e sem vaga.
  cheia('cheia', 'Mesa completa'),

  /// Iniciada. Aparece na lista, e não aceita ingresso.
  emAndamento('em_andamento', 'Partida em andamento');

  const EstadoDeIngresso(this.chave, this.rotulo);

  final String chave;
  final String rotulo;

  static EstadoDeIngresso? daChave(String? chave) {
    for (final e in EstadoDeIngresso.values) {
      if (e.chave == chave) return e;
    }
    return null;
  }
}

/// Quem ocupa um assento. Bot é bot e não conta como jogador.
enum TipoDeOcupante {
  humano('humano'),
  bot('bot');

  const TipoDeOcupante(this.chave);
  final String chave;

  static TipoDeOcupante? daChave(String? chave) {
    for (final t in TipoDeOcupante.values) {
      if (t.chave == chave) return t;
    }
    return null;
  }
}

/// Uma das quatro posições de uma mesa, já sanitizada pelo servidor.
///
/// NÃO EXISTE CAMPO DE IDENTIDADE AQUI, e não é por esquecimento: o servidor
/// não envia `jogadorId` (que é o uid), e este modelo não tem onde guardá-lo.
/// Acrescentar o campo exigiria mexer aqui, no adaptador e no contrato — três
/// lugares, e a suíte reprova nos três.
class AssentoPublico {
  const AssentoPublico({
    required this.assento,
    required this.ocupado,
    required this.tipo,
    required this.apelido,
    required this.avatarGaleria,
  });

  /// Índice do assento, 0..3.
  final int assento;
  final bool ocupado;

  /// `null` quando o assento está livre.
  final TipoDeOcupante? tipo;

  /// Apelido já cortado pelo servidor. `null` quando livre.
  final String? apelido;

  /// Índice do avatar de catálogo, ou `null`. Avatar de FOTO não atravessa:
  /// ele é servido por uma rota que carrega o uid no caminho.
  final int? avatarGaleria;

  bool get ehHumano => tipo == TipoDeOcupante.humano;
  bool get ehBot => tipo == TipoDeOcupante.bot;

  /// Frase para leitor de tela. A posição é dita por extenso porque "assento 2"
  /// não quer dizer nada para quem não vê a mesa desenhada.
  String get descricaoAcessivel {
    final posicao = 'Posição ${assento + 1}';
    if (!ocupado) return '$posicao, livre';
    if (ehBot) return '$posicao, robô';
    final nome = apelido;
    if (nome == null || nome.isEmpty) return '$posicao, ocupada';
    return '$posicao, $nome';
  }
}

/// Uma mesa pública, como o servidor a projetou.
class MesaPublica {
  const MesaPublica({
    required this.codigo,
    required this.nome,
    required this.modalidade,
    required this.metaPontos,
    required this.capacidade,
    required this.jogadores,
    required this.bots,
    required this.ocupados,
    required this.vagas,
    required this.assentos,
    required this.estadoIngresso,
    required this.ingressavel,
    required this.aguardandoHa,
    required this.revisao,
  });

  /// Identificador OPACO. Serve para a OS 38.3 pedir ingresso — e para mais
  /// nada. Não é exibido, não é parseado e não carrega estrutura.
  final String codigo;

  /// Identificação pública derivada pelo servidor ("Mesa de Ana").
  final String nome;

  final ModalidadeDeMesa modalidade;
  final int metaPontos;
  final int capacidade;

  /// Assentos ocupados por HUMANO. É medida da MESA, não de presença.
  final int jogadores;
  final int bots;
  final int ocupados;
  final int vagas;

  /// Sempre quatro, na ordem dos assentos.
  final List<AssentoPublico> assentos;

  final EstadoDeIngresso estadoIngresso;

  /// Vem do servidor. NÃO é recalculado a partir de `vagas`: mesa em andamento
  /// pode ter assento vazio e mesmo assim não aceitar ninguém.
  final bool ingressavel;

  /// Há quanto tempo a mesa espera.
  final Duration aguardandoHa;

  /// Revisão desta mesa, da sequência única do servidor.
  final int revisao;

  /// "2/4" — humanos sobre capacidade.
  String get ocupacaoCurta => '$jogadores/$capacidade';
}

/// Contagens de uma modalidade. Todas por PESSOA, nunca por assento.
class PresencaDeModalidade {
  const PresencaDeModalidade({
    required this.mesas,
    required this.mesasComVagas,
    required this.jogadores,
    required this.jogadoresAguardando,
    required this.jogadoresEmAndamento,
  });

  final int mesas;
  final int mesasComVagas;
  final int jogadores;
  final int jogadoresAguardando;
  final int jogadoresEmAndamento;

  static const vazia = PresencaDeModalidade(
    mesas: 0,
    mesasComVagas: 0,
    jogadores: 0,
    jogadoresAguardando: 0,
    jogadoresEmAndamento: 0,
  );
}

/// O bloco de presença do retrato.
///
/// TODOS os números vêm do servidor. Nenhum é somado, derivado ou completado
/// aqui — em particular [jogadoresOnlineTotal], que a Home mostra e que NÃO é
/// a soma das modalidades: quem está na Home, no Perfil ou assistindo também
/// está online, e nenhum deles aparece em modalidade nenhuma.
class PresencaAgregada {
  const PresencaAgregada({
    required this.jogadoresOnlineTotal,
    required this.espectadoresOnline,
    required this.jogadoresEmMesasPublicas,
    required this.jogadoresEmMesasPublicasAguardando,
    required this.jogadoresEmMesasPublicasEmAndamento,
    required this.mesasPublicas,
    required this.mesasPublicasComVagas,
    required this.porModalidade,
  });

  /// Pessoas no aplicativo agora. É este, e só este, que a Home exibe.
  final int jogadoresOnlineTotal;
  final int espectadoresOnline;
  final int jogadoresEmMesasPublicas;
  final int jogadoresEmMesasPublicasAguardando;
  final int jogadoresEmMesasPublicasEmAndamento;
  final int mesasPublicas;
  final int mesasPublicasComVagas;

  /// Uma entrada por modalidade, sempre as três.
  final Map<ModalidadeDeMesa, PresencaDeModalidade> porModalidade;

  PresencaDeModalidade de(ModalidadeDeMesa m) =>
      porModalidade[m] ?? PresencaDeModalidade.vazia;
}

/// O retrato inteiro. Imutável, completo, de uma geração só.
class RetratoDaDescoberta {
  const RetratoDaDescoberta({
    required this.geracao,
    required this.revisao,
    required this.geradoEm,
    required this.mesas,
    required this.presenca,
  });

  /// Identifica o PROCESSO que produziu o retrato. Revisões de gerações
  /// diferentes NÃO são comparáveis — ver `estado_descoberta.dart`.
  final String geracao;

  /// Estritamente crescente dentro de uma geração.
  final int revisao;

  /// Carimbo ISO do servidor, cru. Não é usado para decidir nada: quem decide
  /// ordem é a revisão. Fica para diagnóstico.
  final String geradoEm;

  /// Já na ordem do servidor. O aplicativo NUNCA reordena.
  final List<MesaPublica> mesas;

  final PresencaAgregada presenca;

  String get esquema => ContratoDaDescoberta.esquema;

  bool get vazio => mesas.isEmpty;

  bool get temIngressavel => mesas.any((m) => m.ingressavel);
}
