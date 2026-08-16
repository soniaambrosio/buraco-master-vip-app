// bancada_online.dart — a bancada compartilhada dos testes da mesa online.
//
// NÃO é um arquivo `_test.dart`: ele não declara caso nenhum, e o coletor do
// `flutter test` não o recolhe. É só o cenário.
//
// ---------------------------------------------------------------------------
// O QUE É FALSO AQUI, E O QUE NÃO É
// ---------------------------------------------------------------------------
//
// Falsas são as QUATRO PONTAS DO MUNDO, que são exatamente as costuras que a
// arquitetura já expunha:
//
//   * o fluxo de autenticação (`ComandosDeAutenticacao`);
//   * a fonte de identidade pública;
//   * o provedor de credencial;
//   * o canal WebSocket.
//
// Tudo entre elas é produção: a `RaizDoAplicativo` de verdade, a
// `SessaoDoJogador` de verdade, a `PonteSessaoOnline` de verdade e o
// `OnlineService` de verdade. Um teste que trocasse o `OnlineService` por um
// dublê provaria o dublê — e o que está sob julgamento nesta OS é justamente
// se a tela fala com o transporte real pelo protocolo real.
//
// NENHUM CASO ABRE REDE. O endereço é sintético e o canal é de mentira: não há
// socket, não há servidor de homologação e não se cria estado em produção.
//
// ---------------------------------------------------------------------------
// AS VISÕES DE MENTIRA SÃO CÓPIAS DO CONTRATO, NÃO INVENÇÕES
// ---------------------------------------------------------------------------
//
// [visaoDeJogo] e [visaoDeLobby] reproduzem campo a campo o que
// `visaoDoAssento`/`visao` do servidor emitem (repo `buraco-servidor`, ref
// `claude/produtor-encerramento-autoritativo-v1`, SHA
// 16a692bbe95597536b3f9975ecf32e1bde58ebcb). Inclusive as asperezas: a carta
// carrega `eh_coringa` com sublinhado, e `placar`/`jogosDupla` são chaveados
// por `nos`/`eles` ABSOLUTOS — assentos 0 e 2 são `nos`, 1 e 3 são `eles`,
// independentemente de onde o leitor da visão está sentado.
//
// Se um dia essas visões deixarem de bater com o servidor, é aqui que a
// divergência tem de aparecer — e não numa tela em produção.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:buraco_master_vip/casca/raiz_do_aplicativo.dart';
import 'package:buraco_master_vip/services/online_service.dart';
import 'package:buraco_master_vip/services/ponte_sessao_online.dart';
import 'package:buraco_master_vip/sessao/comandos_de_autenticacao.dart';
import 'package:buraco_master_vip/sessao/credencial_de_sessao.dart';
import 'package:buraco_master_vip/sessao/fonte_identidade.dart';
import 'package:buraco_master_vip/sessao/identidade_publica_sessao.dart';
import 'package:buraco_master_vip/sessao/sessao_do_jogador.dart';

// ===========================================================================
// As pontas do mundo
// ===========================================================================

class FonteFalsa implements FonteDeIdentidade {
  String apelido = 'Ana';
  int chamadas = 0;

  @override
  Future<IdentidadePublica> obterMinhaIdentidade() {
    chamadas++;
    return Future<IdentidadePublica>.value(
      IdentidadePublica(
        publicId: 'P0A1B2C3D4E5',
        apelido: apelido,
        avatarRef: null,
        criada: false,
        estado: EstadoPerfil.ativo,
        limites: LimitesSociais.desconhecidos,
        edicao: MetadadosDeEdicao.desconhecidos,
      ),
    );
  }
}

class CredencialFalsa implements FonteDeCredencial {
  String? token = 'token-de-teste';
  int pedidos = 0;

  @override
  Future<String?> obterToken() async {
    pedidos++;
    return token;
  }
}

class AutenticacaoFalsa implements ComandosDeAutenticacao {
  AutenticacaoFalsa(this._fluxo);

  final StreamController<String?> _fluxo;

  int entradas = 0;
  int saidas = 0;
  String uidQueVaiEntrar = 'uid-A';

  @override
  List<ProvedorDeLogin> get provedoresDisponiveis => const [
    ProvedorDeLogin.google,
  ];

  @override
  Future<ResultadoDeLogin> entrar(ProvedorDeLogin provedor) async {
    entradas++;
    _fluxo.add(uidQueVaiEntrar);
    return const ResultadoDeLogin.entrou();
  }

  @override
  Future<void> sair() async {
    saidas++;
    _fluxo.add(null);
  }
}

/// Canal WebSocket de mentira: guarda o que o app escreveu e deixa o teste
/// empurrar mensagens do "servidor" para dentro do app.
class CanalFalso extends StreamChannelMixin implements WebSocketChannel {
  final _doServidor = StreamController<dynamic>.broadcast();
  final List<String> enviadas = [];
  bool fechado = false;

  List<Map<String, dynamic>> get mensagens =>
      enviadas.map((s) => jsonDecode(s) as Map<String, dynamic>).toList();

  /// Só as jogadas — o miolo de `{tipo:'jogada', jogada:{...}}`.
  List<Map<String, dynamic>> get jogadas => mensagens
      .where((m) => m['tipo'] == 'jogada')
      .map((m) => (m['jogada'] as Map).cast<String, dynamic>())
      .toList();

  List<Map<String, dynamic>> doTipo(String tipo) =>
      mensagens.where((m) => m['tipo'] == tipo).toList();

  void servidorEnvia(Map<String, dynamic> msg) =>
      _doServidor.add(jsonEncode(msg));

  /// A conexão cai do lado de lá.
  void servidorDerruba() => _doServidor.close();

  @override
  Future<void> get ready => Future<void>.value();
  @override
  Stream<dynamic> get stream => _doServidor.stream;
  @override
  WebSocketSink get sink => _SinkFalso(this);
  @override
  int? get closeCode => null;
  @override
  String? get closeReason => null;
  @override
  String? get protocol => null;
  @override
  void pipe(dynamic other) => throw UnimplementedError();
}

class _SinkFalso implements WebSocketSink {
  _SinkFalso(this._canal);
  final CanalFalso _canal;

  @override
  void add(dynamic data) => _canal.enviadas.add(data as String);
  @override
  Future<void> close([int? closeCode, String? closeReason]) async {
    _canal.fechado = true;
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}
  @override
  Future<void> addStream(Stream<dynamic> stream) async {}
  @override
  Future<void> get done => Future<void>.value();
}

/// Endereço sintético. Não existe, não é resolvido e nenhum teste toca a rede.
const String kEndpointDeTeste = 'wss://servidor-de-teste.invalido';

// ===========================================================================
// A bancada
// ===========================================================================

class Bancada {
  Bancada({String? uidInicial}) {
    sessao = SessaoDoJogador(
      fonte: fonte,
      uids: fluxo.stream,
      uidInicial: uidInicial,
      credenciais: credenciais,
    );
    online = criarOnlineServiceDaSessao(
      sessao,
      endpoint: Uri.parse(kEndpointDeTeste),
      abrirCanal: (url) {
        aberturas++;
        final c = CanalFalso();
        canais.add(c);
        return c;
      },
    );
    autenticacao = AutenticacaoFalsa(fluxo);
  }

  final fluxo = StreamController<String?>.broadcast();
  final fonte = FonteFalsa();
  final credenciais = CredencialFalsa();
  final List<CanalFalso> canais = [];

  /// Quantas vezes o transporte tentou ABRIR um canal — inclusive as que
  /// falharam. É o número que responde "abriu socket duplicado?".
  int aberturas = 0;

  late final SessaoDoJogador sessao;
  late final OnlineService online;
  late final AutenticacaoFalsa autenticacao;

  CanalFalso get canal => canais.last;

  Widget get aplicativo => RaizDoAplicativo(
    sessao: sessao,
    autenticacao: autenticacao,
    online: online,
    duracaoDaSplash: const Duration(milliseconds: 20),
    somNaSplash: false,
    limiteDeResolucao: const Duration(seconds: 8),
  );

  void fechar() {
    online.dispose();
    sessao.dispose();
    fluxo.close();
  }
}

// ===========================================================================
// Visões — cópias do contrato do servidor
// ===========================================================================

/// Uma carta no formato que o servidor manda DENTRO da visão de assento.
///
/// `eh_coringa` com sublinhado não é descuido: é o nome do campo no
/// `criarCarta` do servidor, e `visaoDoAssento` publica `suaMao`, `lixoTopo`,
/// `lixoAberto` e `jogosDupla` CRUS — sem passar pelo `cartaPublica`, que é a
/// forma usada só para quem assiste.
Map<String, dynamic> carta(
  String id,
  String? naipe,
  String valor, {
  bool coringa = false,
}) => {
  'id': id,
  'naipe': naipe,
  'valor': valor,
  'eh_coringa': coringa,
};

/// A visão de LOBBY, como `salas.visao` a monta quando ainda não há jogo.
Map<String, dynamic> visaoDeLobby({
  int voceAssento = 0,
  String codigo = 'BURACO-0001',
  bool criador = true,
}) => {
  'lobby': true,
  'codigo': codigo,
  'modalidade': 'aberto',
  'metaPontos': 3000,
  'voceAssento': voceAssento,
  'criador': criador,
  'assentos': [
    {'apelido': 'Ana', 'tipo': 'humano', 'ehVoce': voceAssento == 0},
    {'vazio': true},
    {'vazio': true},
    {'vazio': true},
  ],
};

/// A visão de JOGO, como `visaoDoAssento` a monta.
///
/// Os campos e os nomes são os do servidor. Os valores são pequenos de
/// propósito — o que se prova aqui é o transporte de autoridade, não a regra
/// do Buraco.
Map<String, dynamic> visaoDeJogo({
  int voceAssento = 0,
  bool suaVez = true,
  bool jaComprou = false,
  int rodada = 1,
  Map<String, dynamic>? placar,
  List<Map<String, dynamic>>? suaMao,
  Map<String, dynamic>? lixoTopo,
  List<Map<String, dynamic>>? lixoAberto,
  int monteQtd = 60,
  int mortosQtd = 2,
  bool encerrada = false,
  bool rodadaEncerrada = false,
  String? duplaQueBateu,
  Map<String, dynamic>? pontosRodada,
  String? precisaUsarTopo,
  Map<String, dynamic>? jogosDupla,
  List<Map<String, dynamic>>? assentos,
  int? versaoEstado,
}) => {
  'voceAssento': voceAssento,
  'modalidade': 'aberto',
  'metaPontos': 3000,
  'rodada': rodada,
  'placar': placar ?? {'nos': 120, 'eles': 45},
  'encerrada': encerrada,
  'rodadaEncerrada': rodadaEncerrada,
  'duplaQueBateu': duplaQueBateu,
  'pontosRodada': pontosRodada,
  'rodadasVulneravel': {'nos': 0, 'eles': 0},
  'vez': suaVez ? voceAssento : (voceAssento + 1) % 4,
  'suaVez': suaVez,
  'jaComprou': jaComprou,
  'precisaUsarTopo': precisaUsarTopo,
  'suaMao':
      suaMao ??
      [
        carta('c1', 'copas', '7'),
        carta('c2', 'copas', '8'),
        carta('c3', 'espadas', 'K'),
      ],
  'assentos':
      assentos ??
      [
        {
          'apelido': 'Ana',
          'tipo': 'humano',
          'dupla': 'nos',
          'qtdCartas': 3,
          'ehVoce': voceAssento == 0,
        },
        {
          'apelido': 'Bot 2',
          'tipo': 'bot',
          'dupla': 'eles',
          'qtdCartas': 11,
          'ehVoce': voceAssento == 1,
        },
        {
          'apelido': 'Bia',
          'tipo': 'humano',
          'dupla': 'nos',
          'qtdCartas': 9,
          'ehVoce': voceAssento == 2,
        },
        {
          'apelido': 'Bot 4',
          'tipo': 'bot',
          'dupla': 'eles',
          'qtdCartas': 11,
          'ehVoce': voceAssento == 3,
        },
      ],
  'monteQtd': monteQtd,
  'lixoQtd': lixoAberto?.length ?? (lixoTopo == null ? 0 : 1),
  'lixoTopo': lixoTopo ?? carta('L1', 'ouros', '5'),
  'lixoAberto': lixoAberto,
  'mortosQtd': mortosQtd,
  'mortoPego': const {'nos': false, 'eles': false},
  'jogosDupla':
      jogosDupla ??
      {
        'nos': [
          [
            carta('n1', 'paus', '4'),
            carta('n2', 'paus', '5'),
            carta('n3', 'paus', '6'),
          ],
        ],
        'eles': <List<Map<String, dynamic>>>[],
      },
  if (versaoEstado != null) 'versaoEstado': versaoEstado,
};
