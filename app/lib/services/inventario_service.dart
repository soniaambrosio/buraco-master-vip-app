// inventario_service.dart — origem dos dados do Inventario do jogador.
//
// Compoe as DUAS autoridades que ja existiam e nunca haviam se encontrado numa
// tela:
//
//   1. QUAIS ITENS EXISTEM  → `data/colecoes/catalogo.seed.json`, lido do
//      bundle. E o mesmo arquivo que as suites de `test/colecoes/` validam, e
//      que `tools/android/bin/verificar_assets.dart` confere contra a arte.
//   2. O QUE O JOGADOR POSSUI → [ColecaoRepositorio.carregarInventario], que le
//      `users/{uid}/inventory` no Firestore.
//
// A separacao nao e cerimonia: o catalogo e a mesma coisa para todo mundo e
// pode viajar no APK; a posse e de UMA pessoa, muda sozinha e so o servidor
// grava. Guardar posse no bundle seria conceder pelo cliente; buscar catalogo
// no Firestore custaria uma viagem de rede para ler um dado que ja esta no
// aparelho.
//
// ESTE ARQUIVO NAO CONCEDE NADA. Nao ha compra, preco, saldo nem resgate: as
// unicas escritas possiveis daqui sao de equipagem, e mesmo essas quem decide e
// o dominio ([InventarioUsuario.equipar]).

import 'package:flutter/services.dart' show rootBundle;

import '../colecoes/colecao_catalogo.dart';
import '../colecoes/colecao_firebase.dart';
import '../colecoes/colecao_inventario.dart';
import '../colecoes/colecao_repositorio.dart';
import '../colecoes/colecao_ui_contract.dart';

/// Catalogo canonico das colecoes, empacotado no aplicativo.
///
/// O arquivo ja era a fonte da verdade do modulo; o que faltava era ele chegar
/// ao runtime — ate aqui so os testes o liam, direto do disco. Declarado em
/// `pubspec.yaml` item a item, e nao pela pasta `data/colecoes/`, para que os
/// outros seeds daquele diretorio (manifesto de arte, relatorio de otimizacao
/// de PNG) NAO entrem no APK: sao insumos de build e de auditoria, nao de
/// execucao.
const kAssetCatalogoColecoes = 'data/colecoes/catalogo.seed.json';

/// O inventario nao pode ser lido. Texto curto, ja em portugues e exibivel.
class InventarioIndisponivel implements Exception {
  final String motivo;

  /// true quando repetir tem chance de resolver. Vem de
  /// [FalhaBackend.vaiAdiantarRepetir] — a tela nao reclassifica erro.
  final bool podeTentarDeNovo;

  const InventarioIndisponivel(this.motivo, {this.podeTentarDeNovo = false});

  @override
  String toString() => 'InventarioIndisponivel: $motivo';
}

/// Resultado de um pedido de equipagem, ja traduzido para a tela.
class EquipagemAplicada {
  /// Inventario projetado depois da troca.
  final InventarioVM vm;

  /// null quando deu certo; preenchido quando o dominio recusou.
  final RecusaEquipagem? recusa;

  /// Itens que sairam do slot para dar lugar ao novo.
  final List<String> desequipados;

  const EquipagemAplicada({
    required this.vm,
    this.recusa,
    this.desequipados = const <String>[],
  });

  bool get aceita => recusa == null;
}

/// Origem dos dados do Inventario (camada de logica).
///
/// Guarda o catalogo e o ultimo inventario lido porque equipar EXIGE os dois:
/// [InventarioUsuario.equipar] precisa do inventario atual para saber quem
/// ocupa o slot, e do catalogo para saber a regra do slot. Deixar esse estado
/// na tela obrigaria o widget a fazer trabalho de dominio.
class InventarioService {
  final ColecaoRepositorio _repositorio;
  final Future<String> Function(String) _lerAsset;

  /// Cache do catalogo. Imutavel e igual para todos os jogadores: relido a cada
  /// abertura seria decodificar 8 KB de JSON sem motivo.
  CatalogoColecoes? _catalogo;

  /// Ultimo inventario lido. E de UM jogador — ver [_uidCarregado].
  InventarioUsuario? _inventario;

  /// De quem e o [_inventario] em memoria.
  ///
  /// Existe pela mesma razao que `EstadoIdentidadeSessao.uid`: sem isto, trocar
  /// de conta no mesmo processo mostraria ao jogador B o acervo do jogador A
  /// ate a primeira leitura terminar.
  String? _uidCarregado;

  /// Numero do pedido de leitura mais recente.
  ///
  /// `Future` nao se cancela em Dart: uma leitura lenta CONTINUA e vai terminar,
  /// mesmo que o jogador ja tenha trocado de conta. O contador e o que permite
  /// reconhecer a resposta que chegou tarde e descarta-la em vez de aplica-la.
  int _geracao = 0;

  InventarioService({
    ColecaoRepositorio? repositorio,
    Future<String> Function(String)? lerAsset,
  })  : _repositorio = repositorio ?? ColecaoRepositorioFirebase(),
        _lerAsset = lerAsset ?? rootBundle.loadString;

  /// Catalogo do bundle, decodificado uma vez por processo.
  Future<CatalogoColecoes> carregarCatalogo() async =>
      _catalogo ??= CatalogoColecoes.fromSeedJson(
        await _lerAsset(kAssetCatalogoColecoes),
      );

  /// Le a posse e projeta.
  ///
  /// [uid] e o UID do Firebase — `users/{uid}/inventory` e indexado por ele.
  /// NAO e o `publicId`: aquele e opaco, serve para exibir e transportar, e usa-lo
  /// aqui consultaria um caminho que nao existe.
  ///
  /// [uid] nulo ou vazio devolve [EstadoInventario.semSessao] em vez de um
  /// inventario vazio: nao ter itens e nao saber se tem sao coisas diferentes, e
  /// so uma delas deve ser dita ao jogador.
  ///
  /// Devolve null quando a leitura foi SUPERADA por outra mais nova. Nesse caso
  /// nada e escrito em memoria e a tela deve ignorar a resposta.
  Future<InventarioVM?> carregar(String? uid) async {
    final geracao = ++_geracao;

    if (uid == null || uid.isEmpty) {
      _esquecer();
      return const InventarioVM.semSessao();
    }

    // Some com o acervo do dono anterior ANTES da leitura, e nao depois: entre o
    // pedido e a resposta ha um frame em que a tela desenha o que estiver aqui.
    if (_uidCarregado != uid) _esquecer();

    final catalogo = await carregarCatalogo();

    final InventarioUsuario inventario;
    try {
      inventario =
          await _aoServidor(() => _repositorio.carregarInventario(uid: uid));
    } catch (_) {
      // Erro de uma leitura ja superada nao vai a tela: mostrar "sem conexao"
      // do jogador A por cima do acervo de B, que carregou bem, seria falar do
      // pedido errado.
      if (geracao != _geracao) return null;
      rethrow;
    }

    // O PONTO DA TRAVA. Sem esta linha, uma resposta atrasada de A que chega
    // DEPOIS da de B sobrescreve `_inventario` e `_uidCarregado` com os de A: o
    // jogador B passa a ver o acervo de A, e `equipar` passa a aceitar itens de
    // A em nome de B. Comparar `uid` nao bastaria — duas leituras do MESMO uid
    // tambem podem se cruzar, e a mais velha venceria.
    if (geracao != _geracao) return null;

    _inventario = inventario;
    _uidCarregado = uid;
    return montarInventarioVM(catalogo: catalogo, inventario: inventario);
  }

  /// Equipa um item, com a decisao no dominio e a escrita no repositorio.
  ///
  /// Ordem deliberada: o dominio decide, o servidor grava, e so entao o estado
  /// em memoria muda. Atualizar antes da confirmacao mostraria a troca feita e a
  /// desfaria na proxima leitura.
  Future<EquipagemAplicada> equipar(String uid, String itemId) async {
    final geracao = _geracao;
    final catalogo = await carregarCatalogo();
    final atual = _inventario;
    if (atual == null || _uidCarregado != uid) {
      throw const InventarioIndisponivel(
        'Recarrega teus itens antes de equipar.',
        podeTentarDeNovo: true,
      );
    }

    final resultado = atual.equipar(itemId, catalogo);
    if (!resultado.aceita) {
      // Recusa do dominio nao vai ao servidor: nada mudou, e o VM devolvido e o
      // mesmo de antes para que a tela nao pisque.
      return EquipagemAplicada(
        vm: montarInventarioVM(catalogo: catalogo, inventario: atual),
        recusa: resultado.recusa,
      );
    }

    await _aoServidor(() => _repositorio.aplicarEquipagem(
          uid: uid,
          itemIdEquipado: itemId,
          itemIdsDesequipados: resultado.desequipados,
        ));

    // A gravacao no servidor foi de A e estava certa — era item de A, no caminho
    // de A. O que nao pode acontecer e o resultado dela virar o estado em
    // memoria depois que a sessao virou B.
    if (geracao != _geracao || _uidCarregado != uid) {
      throw const InventarioIndisponivel(
        'A sessão mudou enquanto isso. Recarrega teus itens.',
        podeTentarDeNovo: true,
      );
    }

    final novo = resultado.inventario!;
    _inventario = novo;
    return EquipagemAplicada(
      vm: montarInventarioVM(catalogo: catalogo, inventario: novo),
      desequipados: resultado.desequipados,
    );
  }

  void _esquecer() {
    _inventario = null;
    _uidCarregado = null;
  }

  /// Traduz [ErroColecao] em algo exibivel, preservando a classificacao de
  /// "adianta repetir" que o repositorio ja fez.
  static Future<T> _aoServidor<T>(Future<T> Function() acao) async {
    try {
      return await acao();
    } on ErroColecao catch (e) {
      throw InventarioIndisponivel(
        _mensagem(e.falha),
        podeTentarDeNovo: e.falha.vaiAdiantarRepetir,
      );
    }
  }

  static String _mensagem(FalhaBackend falha) => switch (falha) {
        FalhaBackend.naoAutenticado =>
          'Entra na tua conta para ver teus itens.',
        FalhaBackend.recusado => 'Estes itens não estão disponíveis para ti.',
        FalhaBackend.naoEncontrado => 'Não encontrei teus itens agora.',
        FalhaBackend.precondicaoFalhou =>
          'Teus itens estão em manutenção. Tenta mais tarde.',
        FalhaBackend.indisponivel =>
          'Sem conexão para carregar teus itens agora.',
        FalhaBackend.desconhecida => 'Não consegui carregar teus itens agora.',
      };
}
