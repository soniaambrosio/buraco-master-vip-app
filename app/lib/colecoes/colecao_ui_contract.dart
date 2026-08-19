// colecao_ui_contract.dart — contrato unico entre a logica e a camada visual.
//
// Camada pura: sem Firestore, sem Cloud Functions e sem import de
// flutter/material, de proposito. A etapa visual (ChatGPT/Codex) consome ESTE
// arquivo e nada abaixo dele.
//
// POR QUE UM CONTRATO E NAO WIDGETS
// A ordem de servico separa as responsabilidades: a logica e o Firebase sao
// desta entrega, a apresentacao definitiva vem depois, ja aprovada. Um contrato
// unico evita integracao parcial — a tela nao precisa aprender Firestore, regra
// de elegibilidade ou formato de documento para funcionar, e trocar a tela nao
// pede mudanca na logica.
//
// REGRA DURA: nenhum widget deve consultar Firestore diretamente nem decidir
// elegibilidade por conta propria. A tela recebe [ColecaoVM] pronto e devolve
// intencao por [ColecaoCallbacks].

import 'colecao_arte.dart';
import 'colecao_campanha.dart';
import 'colecao_catalogo.dart';
import 'colecao_inventario.dart';
import 'colecao_resgate.dart';

/// Estados possiveis da experiencia de colecao. Enumerados de forma exaustiva
/// para que a tela nao precise inferir nada a partir de campos nulos.
enum EstadoColecao {
  /// Campanha desligada (feature flag ou status): nao mostrar nada.
  inactive,

  /// Consultando campanha, elegibilidade e inventario.
  loading,

  /// Campanha valendo, jogador sem direito. A tela so aparece se
  /// [ColecaoVM.visibilidade] for teaser.
  notEligible,

  /// Tem direito e ainda nao resgatou: e o estado do convite.
  eligibleUnclaimed,

  /// Chamada de resgate em curso. Botao deve ficar bloqueado.
  claiming,

  /// Resgate concluido AGORA, nesta sessao: dispara a revelacao.
  claimed,

  /// Ja havia resgatado antes. Mesmo inventario, sem revelacao e sem erro.
  alreadyClaimed,

  /// Falha temporaria. [ColecaoVM.mensagemErro] explica e onRetry esta ativo.
  recoverableError,
}

/// Regras de exibicao que a arte exige. Vivem no contrato, e nao num comentario
/// de tela, porque valem para QUALQUER superficie que renderizar estes PNGs.
///
/// As artes 03, 04, 05, 07 e 08 ocupam praticamente todo o canvas de
/// 1254x1254: sem a margem interna abaixo, faixa, asas, cetro e base encostam
/// na borda do container e parecem cortadas.
abstract final class RegrasDeExibicao {
  /// A peca inteira sempre aparece. `BoxFit.cover`, crop automatico, clip oval
  /// ou mascara sao proibidos: cortariam faixa, asas, cetro, coroa ou base.
  static const usarBoxFitContain = true;

  /// Margem interna minima do container, em fracao do lado (8%).
  static const paddingVisualMinimo = 0.08;

  /// Os PNGs tem alpha real. Nunca inserir placa branca, preta ou xadrez atras
  /// da propria arte — o fundo e da tela, nao da peca.
  static const preservarTransparencia = true;

  /// Fundo escuro neutro (preto/dourado/roxo) e o contexto aprovado. Testar
  /// tambem sobre fundo claro para detectar halos.
  static const fundoEscuroNeutro = true;

  /// Nao precachear a colecao inteira na abertura do aplicativo: sao ~27 MB.
  /// No carrossel, antecipar apenas o item seguinte.
  static const precachearTudoNaAbertura = false;
}

/// Textos provisorios em pt-BR, conforme a ordem de servico. Ficam no contrato
/// para que a etapa visual nao invente copy nem duplique string solta em widget.
/// A redacao final e decisao da Sonia.
abstract final class TextosColecao {
  static const title = 'KIT PIONEIROS 2026';
  static const subtitle = 'Você fez parte do começo.';
  static const body =
      'Uma coleção exclusiva para quem esteve presente no início do Buraco Master VIP.';
  static const claimButton = 'Abrir meu Kit Pioneiro';
  static const successTitle = 'Coleção desbloqueada';
  static const successBody = 'Este legado é seu para sempre.';
  static const inventoryButton = 'Ver meus itens';
  static const retryMessage =
      'Não foi possível concluir agora. Tente novamente; seu kit não será duplicado.';
}

/// Eventos de telemetria. Carregam apenas identificadores tecnicos: nenhum dado
/// pessoal, nenhum apelido, nenhum e-mail.
enum EventoColecao {
  offerSeen('pioneer_offer_seen'),
  claimStarted('pioneer_claim_started'),
  claimSuccess('pioneer_claim_success'),
  claimAlreadyCompleted('pioneer_claim_already_completed'),
  claimError('pioneer_claim_error'),
  itemEquipped('pioneer_item_equipped'),
  inventoryOpened('pioneer_inventory_opened');

  final String wire;
  const EventoColecao(this.wire);

  /// Monta o payload do evento. [result] e [rewardId] entram apenas quando o
  /// evento os tem; campos nulos sao omitidos para nao poluir o funil.
  Map<String, Object> payload({
    required String campaignId,
    required String appVersion,
    String? rewardId,
    String? result,
  }) =>
      <String, Object>{
        'campaignId': campaignId,
        'appVersion': appVersion,
        'rewardId': ?rewardId,
        'result': ?result,
      };
}

/// View model de uma recompensa. Tudo que a tela precisa para desenhar um card,
/// sem consultar catalogo, inventario ou Firestore.
class RecompensaVM {
  final String id;
  final String displayName;

  /// De onde vem a arte. A superficie deve passar por [ResolvedorDeArte] em vez
  /// de assumir arquivo local: hoje toda arte e de bundle, mas uma colecao
  /// futura pode ser remota sem que o [id] mude.
  final FonteArte arte;

  final String category;

  /// Slot de equipagem; null quando o item nao e equipavel.
  final String? slot;

  final bool owned;
  final bool equipped;

  /// true quando `onEquip` esta disponivel agora. false tanto para item nao
  /// possuido quanto para item nao equipavel — a tela nao precisa distinguir
  /// para decidir se habilita o botao.
  final bool canEquip;

  final int sortOrder;
  final String accessibilityLabel;

  const RecompensaVM({
    required this.id,
    required this.displayName,
    required this.arte,
    required this.category,
    required this.slot,
    required this.owned,
    required this.equipped,
    required this.canEquip,
    required this.sortOrder,
    required this.accessibilityLabel,
  });

  /// Caminho no bundle, ou null quando a arte e remota. Atalho para as
  /// superficies que so lidam com arte empacotada — hoje, todas.
  String? get assetPath => arte.assetPath;

  /// Projeta um item do catalogo contra o inventario do jogador.
  factory RecompensaVM.de(ColecaoItem item, InventarioUsuario inventario) {
    final owned = inventario.possui(item.itemId);
    final equipped = inventario.estaEquipado(item.itemId);
    return RecompensaVM(
      id: item.itemId,
      displayName: item.displayName,
      arte: item.arte,
      category: item.categoria,
      slot: item.slot,
      owned: owned,
      equipped: equipped,
      canEquip: owned && item.equipavel && item.enabled && !equipped,
      sortOrder: item.sortOrder,
      accessibilityLabel: item.accessibilityLabel,
    );
  }
}

/// Estado completo da experiencia, pronto para render.
class ColecaoVM {
  final EstadoColecao estado;

  final String campaignId;
  final String titulo;

  /// O que o nao elegivel enxerga. Em [VisibilidadeCatalogo.hidden] com estado
  /// [EstadoColecao.notEligible], a tela nao deve aparecer.
  final VisibilidadeCatalogo visibilidade;

  /// Recompensas na ordem de apresentacao.
  final List<RecompensaVM> recompensas;

  /// Arte de abertura (o Bau). null quando a colecao nao declara uma.
  final String? heroAssetPath;

  /// Peca que fecha a experiencia (Emblema, com a Coroa como alternativa).
  final String? fechamentoAssetPath;

  /// Preenchida somente em [EstadoColecao.recoverableError].
  final String? mensagemErro;

  const ColecaoVM({
    required this.estado,
    required this.campaignId,
    required this.titulo,
    required this.visibilidade,
    required this.recompensas,
    this.heroAssetPath,
    this.fechamentoAssetPath,
    this.mensagemErro,
  });

  /// Quantos itens o jogador possui desta colecao.
  int get possuidos => recompensas.where((r) => r.owned).length;

  /// A colecao esta completa.
  bool get completa => recompensas.isNotEmpty && possuidos == recompensas.length;

  /// A tela deve ser exibida. Em `inactive` nunca; em `notEligible` apenas no
  /// modo teaser. Centralizado aqui para que nenhuma superficie reimplemente a
  /// regra e erre o sinal.
  bool get deveAparecer => switch (estado) {
        EstadoColecao.inactive => false,
        EstadoColecao.notEligible => visibilidade == VisibilidadeCatalogo.teaser,
        _ => true,
      };

  /// O botao de resgate esta ativo.
  bool get podeResgatar => estado == EstadoColecao.eligibleUnclaimed;

  /// Estado de conclusao, com ou sem revelacao.
  bool get resgatado =>
      estado == EstadoColecao.claimed || estado == EstadoColecao.alreadyClaimed;
}

/// Intencoes que a tela devolve. Nenhuma delas grava nada por conta propria: o
/// implementador chama a camada segura e emite um [ColecaoVM] novo.
class ColecaoCallbacks {
  /// Aciona o resgate. Ignorar quando [ColecaoVM.podeResgatar] for false.
  final void Function() onClaim;

  /// Repete apos [EstadoColecao.recoverableError].
  final void Function() onRetry;

  /// Equipa um item. A exclusividade de slot e resolvida por
  /// [InventarioUsuario.equipar]; a tela nao decide quem sai.
  final void Function(String itemId) onEquip;

  final void Function(String itemId) onUnequip;

  /// Leva as categorias existentes do inventario, ja atualizadas.
  final void Function() onOpenInventory;

  final void Function() onClose;

  const ColecaoCallbacks({
    required this.onClaim,
    required this.onRetry,
    required this.onEquip,
    required this.onUnequip,
    required this.onOpenInventory,
    required this.onClose,
  });
}

/// Monta o [ColecaoVM] a partir do estado apurado pela logica.
///
/// Funcao pura: mesma entrada, mesma tela. E o unico ponto onde catalogo,
/// campanha e inventario viram apresentacao — se a tela precisar de um dado
/// novo, ele entra aqui, nao numa consulta solta no widget.
///
/// [situacao] vem de [prepararResgate] quando ja houve uma tentativa; null
/// significa que o resgate ainda nao foi acionado nesta sessao.
ColecaoVM montarColecaoVM({
  required CampanhaColecao campanha,
  required CatalogoColecoes catalogo,
  required InventarioUsuario inventario,
  required VeredictoElegibilidade veredicto,
  required bool featureFlagLigada,
  SituacaoResgate? situacao,
  bool emAndamento = false,
  String? mensagemErro,
}) {
  final colecao = catalogo.colecao(campanha.collectionId);
  final recompensas = colecao.ativos
      .map((item) => RecompensaVM.de(item, inventario))
      .toList(growable: false);

  ColecaoVM vm(EstadoColecao estado) => ColecaoVM(
        estado: estado,
        campaignId: campanha.campaignId,
        titulo: campanha.displayName,
        visibilidade: campanha.catalogVisibility,
        recompensas: recompensas,
        heroAssetPath: catalogo.buscarItem(ColecaoItemIds.pioneerChest)?.assetPath,
        fechamentoAssetPath:
            catalogo.buscarItem(ColecaoItemIds.pioneerEmblem)?.assetPath,
        mensagemErro: estado == EstadoColecao.recoverableError
            ? (mensagemErro ?? TextosColecao.retryMessage)
            : null,
      );

  // Ordem deliberada. Flag desligada vence tudo: nem erro, nem resgate em
  // andamento pode fazer a campanha aparecer.
  if (!featureFlagLigada || !campanha.status.concede) {
    // Quem ja resgatou continua vendo o proprio acervo mesmo com a campanha
    // encerrada — o inventario e permanente, a campanha e que tem prazo.
    if (inventario.possuiTodos(campanha.rewardIds)) {
      return vm(EstadoColecao.alreadyClaimed);
    }
    return vm(EstadoColecao.inactive);
  }

  if (mensagemErro != null) return vm(EstadoColecao.recoverableError);
  if (emAndamento) return vm(EstadoColecao.claiming);

  return switch (situacao) {
    SituacaoResgate.concedido || SituacaoResgate.reconciliado => vm(EstadoColecao.claimed),
    SituacaoResgate.jaResgatado => vm(EstadoColecao.alreadyClaimed),
    SituacaoResgate.recusado => vm(EstadoColecao.notEligible),
    null => _semTentativa(vm, veredicto, inventario, campanha),
  };
}

ColecaoVM _semTentativa(
  ColecaoVM Function(EstadoColecao) vm,
  VeredictoElegibilidade veredicto,
  InventarioUsuario inventario,
  CampanhaColecao campanha,
) {
  if (inventario.possuiTodos(campanha.rewardIds)) {
    return vm(EstadoColecao.alreadyClaimed);
  }
  return veredicto.elegivel
      ? vm(EstadoColecao.eligibleUnclaimed)
      : vm(EstadoColecao.notEligible);
}

// ---------------------------------------------------------------------------
// INVENTARIO DO JOGADOR
// ---------------------------------------------------------------------------
//
// [montarColecaoVM], acima, projeta UMA CAMPANHA: existe para responder "voce
// tem direito a este kit, quer abrir?". O inventario responde outra pergunta —
// "o que ja e meu?" — e por isso tem projecao propria em vez de reaproveitar a
// de campanha com campos nulos.
//
// A DIFERENCA QUE IMPORTA: aqui nao existe elegibilidade, nao existe resgate e
// nao existe convite. Um item so aparece se [InventarioUsuario.possui] disser
// que o jogador o possui — a posse vem de `users/{uid}/inventory`, gravada
// exclusivamente pelo servidor (ver colecao_firebase.dart e firestore.rules).
// Nenhuma linha abaixo concede, precifica ou desbloqueia nada.

/// Estados da superficie de inventario. Exaustivos pelo mesmo motivo de
/// [EstadoColecao]: a tela nao deve inferir nada a partir de lista vazia.
enum EstadoInventario {
  /// Sem jogador autenticado. Nao existe de quem ler posse, e devolver um
  /// inventario vazio seria afirmar que o jogador nao tem nada — que e
  /// diferente de nao saber.
  semSessao,

  /// Lendo catalogo e inventario.
  carregando,

  /// Leitura concluida: o jogador realmente nao possui nenhum item.
  vazio,

  /// Ha itens possuidos em [InventarioVM.grupos].
  pronto,

  /// A leitura falhou. [InventarioVM.mensagemErro] explica e onRecarregar
  /// esta ativo.
  erro,
}

/// Os itens que o jogador possui de UMA colecao.
///
/// Agrupar por colecao e decisao de apresentacao, nao de dominio: o inventario
/// e uma lista plana em `users/{uid}/inventory`, e o agrupamento so existe
/// porque uma vitrine com dezenas de pecas soltas nao se le.
class GrupoInventario {
  final String collectionId;
  final String displayName;

  /// Raridade declarada no catalogo. String vazia quando o catalogo nao a
  /// declara — nunca um valor inventado.
  final String raridade;

  /// A colecao e permanente (nao revogavel).
  final bool permanente;

  /// Apenas os itens POSSUIDOS, na ordem de apresentacao do catalogo.
  final List<RecompensaVM> itens;

  /// Quantos itens a colecao oferece hoje. Serve para o "3 de 10"; vem do
  /// catalogo, nao de contagem do inventario.
  final int totalNaColecao;

  const GrupoInventario({
    required this.collectionId,
    required this.displayName,
    required this.raridade,
    required this.permanente,
    required this.itens,
    required this.totalNaColecao,
  });

  int get possuidos => itens.length;

  int get equipados => itens.where((i) => i.equipped).length;

  /// O jogador possui tudo que a colecao oferece.
  bool get completa => totalNaColecao > 0 && possuidos >= totalNaColecao;
}

/// Estado completo do inventario, pronto para render.
class InventarioVM {
  final EstadoInventario estado;

  /// Colecoes das quais o jogador possui ao menos um item. Colecao sem nenhum
  /// item possuido NAO aparece: o inventario mostra o que e dele, e nao um
  /// catalogo do que falta — isto aqui nao e vitrine de loja.
  final List<GrupoInventario> grupos;

  /// Itens presentes no inventario que o catalogo desta versao do aplicativo
  /// nao conhece.
  ///
  /// Contados e nao desenhados: sem definicao nao ha nome, arte nem slot, e
  /// desenhar um card com id cru seria pior do que dizer honestamente que ha
  /// pecas que esta versao ainda nao sabe mostrar. Acontece quando o servidor
  /// concede uma colecao mais nova que o aplicativo instalado.
  final int itensSemDefinicao;

  /// Preenchida somente em [EstadoInventario.erro].
  final String? mensagemErro;

  const InventarioVM({
    required this.estado,
    required this.grupos,
    this.itensSemDefinicao = 0,
    this.mensagemErro,
  });

  const InventarioVM.semSessao()
      : estado = EstadoInventario.semSessao,
        grupos = const <GrupoInventario>[],
        itensSemDefinicao = 0,
        mensagemErro = null;

  const InventarioVM.carregando()
      : estado = EstadoInventario.carregando,
        grupos = const <GrupoInventario>[],
        itensSemDefinicao = 0,
        mensagemErro = null;

  const InventarioVM.erro(String mensagem)
      : estado = EstadoInventario.erro,
        grupos = const <GrupoInventario>[],
        itensSemDefinicao = 0,
        mensagemErro = mensagem;

  int get totalItens =>
      grupos.fold(0, (soma, grupo) => soma + grupo.possuidos);

  int get totalEquipados =>
      grupos.fold(0, (soma, grupo) => soma + grupo.equipados);

  bool get temItens => totalItens > 0;

  /// Ha pecas possuidas que esta versao nao sabe desenhar.
  bool get temItensSemDefinicao => itensSemDefinicao > 0;
}

/// Intencoes que a tela de inventario devolve.
///
/// Nao ha `onClaim` de proposito. Conceder e ato da campanha, e mistura-lo aqui
/// transformaria a vitrine do jogador numa segunda superficie de oferta.
///
/// TAMBEM NAO HA `onUnequip`, e a razao e de autoridade, nao de escopo.
/// [InventarioUsuario.desequipar] existe e decide corretamente, mas
/// [ColecaoRepositorio.aplicarEquipagem] — o unico caminho de escrita — SEMPRE
/// marca um item como equipado no mesmo lote. Nao ha, hoje, como persistir um
/// desequipar puro. Declarar o callback assim mesmo entregaria a tela um botao
/// que muda a interface e nao muda o servidor: o item voltaria equipado na
/// proxima leitura, e o jogador leria isso como perda do item.
///
/// Na pratica o jogador nao fica preso: todo slot desta colecao tem
/// `maxAtivos: 1`, entao equipar outra peca do mesmo slot troca a ativa — e a
/// troca TEM caminho de escrita. Quando o repositorio ganhar um desequipar
/// proprio, o callback entra aqui.
class InventarioCallbacks {
  /// Equipa um item possuido. A exclusividade de slot e resolvida por
  /// [InventarioUsuario.equipar]; a tela nao decide quem sai.
  final void Function(String itemId) onEquip;

  /// Repete a leitura apos [EstadoInventario.erro].
  final void Function() onRecarregar;

  final void Function() onClose;

  const InventarioCallbacks({
    required this.onEquip,
    required this.onRecarregar,
    required this.onClose,
  });
}

/// Projeta o inventario do jogador contra o catalogo.
///
/// Funcao pura, como [montarColecaoVM]: mesma entrada, mesma tela. E o UNICO
/// lugar onde posse vira apresentacao.
///
/// A iteracao parte do INVENTARIO e nao do catalogo — de proposito. Varrer o
/// catalogo e perguntar "possui?" produziria a lista de tudo que existe, com os
/// nao possuidos marcados; e a estrutura de uma loja, e mais cedo ou mais tarde
/// alguem desenharia os cadeados. Partindo do inventario, um item que o jogador
/// nao tem simplesmente nao existe nesta tela.
InventarioVM montarInventarioVM({
  required CatalogoColecoes catalogo,
  required InventarioUsuario inventario,
}) {
  final porColecao = <String, List<RecompensaVM>>{};
  var semDefinicao = 0;

  for (final possuido in inventario.itens) {
    final definicao = catalogo.buscarItem(possuido.itemId);
    if (definicao == null) {
      semDefinicao++;
      continue;
    }
    (porColecao[definicao.collectionId] ??= <RecompensaVM>[])
        .add(RecompensaVM.de(definicao, inventario));
  }

  final grupos = <GrupoInventario>[];
  for (final entrada in porColecao.entries) {
    final definicao = catalogo.buscarColecao(entrada.key);
    final itens = entrada.value
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    grupos.add(GrupoInventario(
      collectionId: entrada.key,
      // O `??` e defensivo e nao deveria disparar: o `collectionId` veio de uma
      // definicao que o proprio catalogo devolveu. Se disparar, mostra o id cru
      // em vez de um nome bonito e falso.
      displayName: definicao?.displayName ?? entrada.key,
      raridade: definicao?.rarity ?? '',
      permanente: definicao?.permanente ?? false,
      itens: List.unmodifiable(itens),
      totalNaColecao: definicao?.ativos.length ?? itens.length,
    ));
  }

  // Ordem estavel: sem isto a tela reordenaria os grupos a cada leitura, porque
  // a ordem de um Map segue a de insercao, que segue a do Firestore.
  grupos.sort((a, b) => a.collectionId.compareTo(b.collectionId));

  return InventarioVM(
    estado: grupos.isEmpty ? EstadoInventario.vazio : EstadoInventario.pronto,
    grupos: List.unmodifiable(grupos),
    itensSemDefinicao: semDefinicao,
  );
}
