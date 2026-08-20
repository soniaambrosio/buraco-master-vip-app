// js_bridge.dart — expoe o dominio de moderacao para as Cloud Functions.
//
// MESMO MOTIVO DO BRIDGE DE TORNEIOS: as Functions rodam em Node/TypeScript e a
// decisao de moderacao e escrita em Dart. Reescrever "o que e uma denuncia
// valida" em TypeScript criaria uma SEGUNDA implementacao das mesmas regras, e
// as duas divergiriam no primeiro dia em que alguem apertasse um limite so de um
// lado — com o agravante de que, aqui, a versao frouxa e uma porta de abuso.
//
// `dart compile js` transforma ESTE arquivo (e o dominio que ele importa) num
// bundle que o Node carrega. A regra existe uma vez so, em Dart, testada pela
// mesma suite que o app usa (app/test/moderacao/).
//
// FRONTEIRA: aqui so entra conversao de tipo. Nenhuma decisao mora neste
// arquivo. Autenticacao, transacao e escrita sao do TypeScript; regra e do
// dominio; este arquivo e so o cabo entre os dois.
//
// Compilar com:
//   dart compile js -O2 -o functions-moderacao/lib/domain_bundle.js \
//       lib/moderacao/js_bridge.dart

import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import '../chat/mensagem.dart';
import '../chat/porta.dart';
import '../chat/superficie.dart';
import '../comunicacao/ambiente.dart';
import '../comunicacao/catalogo.dart';
import '../comunicacao/evento.dart';
import '../comunicacao/limites.dart';
import '../comunicacao/porta.dart';
import '../social/identidade_publica.dart';
import 'denuncia.dart';
import 'relacao_social.dart';
import 'sancao.dart';

/// Objeto global que o Node enxerga como `globalThis.bmvModeracao`.
@JS('bmvModeracao')
external set _bmvModeracao(JSObject valor);

typedef _Ponte = String Function(String);

Map<String, Object?> _entrada(String json) =>
    (jsonDecode(json) as Map).cast<String, Object?>();

/// Converte nome de enum, devolvendo `null` quando o cliente mandou algo que nao
/// existe — em vez de estourar. Valor desconhecido e entrada invalida, e entrada
/// invalida merece recusa estruturada, nao erro 500.
T? _porNome<T extends Enum>(List<T> valores, Object? nome) {
  if (nome is! String) return null;
  for (final v in valores) {
    if (v.name == nome) return v;
  }
  return null;
}

DateTime? _instante(Object? v) {
  if (v is! String) return null;
  return DateTime.tryParse(v)?.toUtc();
}

// ------------------------------------------------------------------ denuncia

String avaliarDenunciaJson(String json) {
  final e = _entrada(json);

  final tipo = _porNome(TipoDenuncia.values, e['tipo']);
  if (tipo == null) {
    return jsonEncode(const VereditoDenuncia.recusada(
            RecusaDenuncia.categoriaInvalidaParaTipo, ['tipo'])
        .toJson());
  }

  final categoria = _porNome(CategoriaDenuncia.values, e['categoria']);
  if (categoria == null) {
    return jsonEncode(const VereditoDenuncia.recusada(
            RecusaDenuncia.categoriaInvalidaParaTipo, ['categoria'])
        .toJson());
  }

  final ref = (e['referencias'] as Map?)?.cast<String, Object?>() ?? const {};

  final veredito = avaliarDenuncia(
    denuncianteUid: (e['denuncianteUid'] as String?) ?? '',
    denunciadoUid: (e['denunciadoUid'] as String?) ?? '',
    tipo: tipo,
    categoria: categoria,
    reportIntentId: (e['reportIntentId'] as String?) ?? '',
    comentario: e['comentario'] as String?,
    referencias: ReferenciasDenuncia(
      matchId: ref['matchId'] as String?,
      roomId: ref['roomId'] as String?,
      messageId: ref['messageId'] as String?,
    ),
    jaNaJanela: (e['jaNaJanela'] as num?)?.toInt() ?? 0,
  );

  // A chave so acompanha o veredito aceito: calcular sobre entrada invalida
  // estouraria, e nao ha documento a criar de qualquer maneira.
  return jsonEncode({
    ...veredito.toJson(),
    if (veredito.aceita)
      'chave': chaveDeDenuncia(
        denuncianteUid: e['denuncianteUid']! as String,
        reportIntentId: e['reportIntentId']! as String,
      ),
    'esquema': kEsquemaDenuncia,
  });
}

/// Traduz o status interno no status que o denunciante pode ver.
String statusPublicoJson(String json) {
  final e = _entrada(json);
  final s = _porNome(StatusDenuncia.values, e['status']);
  return jsonEncode({
    'publico': (s ?? StatusDenuncia.recebida).publico.name,
  });
}

// ------------------------------------------------------------ relacao social

String avaliarBloqueioJson(String json) {
  final e = _entrada(json);
  return jsonEncode(avaliarBloqueio(
    bloqueadorUid: (e['bloqueadorUid'] as String?) ?? '',
    bloqueadoUid: (e['bloqueadoUid'] as String?) ?? '',
    jaBloqueados: (e['jaBloqueados'] as num?)?.toInt() ?? 0,
  ).toJson());
}

String avaliarMuteJson(String json) {
  final e = _entrada(json);
  return jsonEncode(avaliarMute(
    donoUid: (e['donoUid'] as String?) ?? '',
    alvoUid: (e['alvoUid'] as String?) ?? '',
  ).toJson());
}

String avaliarContatoJson(String json) {
  final e = _entrada(json);
  return jsonEncode(avaliarContato(
    origemBloqueouDestino: e['origemBloqueouDestino'] == true,
    destinoBloqueouOrigem: e['destinoBloqueouOrigem'] == true,
    origemComChatSilenciado: e['origemComChatSilenciado'] == true,
    origemComRestricaoSocial: e['origemComRestricaoSocial'] == true,
  ).toJson());
}

// -------------------------------------------------------------------- sancao

String avaliarSancaoJson(String json) {
  final e = _entrada(json);

  final tipo = _porNome(TipoSancao.values, e['tipo']);
  if (tipo == null) {
    return jsonEncode(const VereditoSancao.recusada(
            RecusaSancao.identificadorInvalido, ['tipo'])
        .toJson());
  }

  final inicio = _instante(e['inicio']);
  if (inicio == null) {
    return jsonEncode(const VereditoSancao.recusada(
            RecusaSancao.prazoAusente, ['inicio'])
        .toJson());
  }

  final fimBruto = e['fim'];
  final fim = _instante(fimBruto);
  if (fimBruto != null && fim == null) {
    return jsonEncode(
        const VereditoSancao.recusada(RecusaSancao.prazoAusente, ['fim'])
            .toJson());
  }

  return jsonEncode(avaliarSancao(
    userId: (e['userId'] as String?) ?? '',
    responsavel: (e['responsavel'] as String?) ?? '',
    tipo: tipo,
    motivo: (e['motivo'] as String?) ?? '',
    inicio: inicio,
    fim: fim,
  ).toJson());
}

/// Dobra o historico de sancoes no efeito vigente em `agora`.
///
/// O servidor manda `agora` porque e ele quem congela o instante da operacao —
/// ver o comentario de topo de sancao.dart.
String consolidarSancoesJson(String json) {
  final e = _entrada(json);
  final agora = _instante(e['agora']);
  if (agora == null) {
    return jsonEncode({'erro': 'agora ausente ou sem fuso'});
  }

  final lista = (e['sancoes'] as List?) ?? const [];
  final sancoes = <Sancao>[];
  for (final item in lista) {
    sancoes.add(Sancao.fromMap((item as Map).cast<String, Object?>()));
  }

  return jsonEncode(
      consolidar((e['userId'] as String?) ?? '', sancoes, agora).toJson());
}

// ---------------------------------------------------------------------- chat
//
// POR QUE O CHAT ATRAVESSA POR ESTE BUNDLE, e nao por um proprio: o bundle e por
// CODEBASE de Functions, e a decisao de envio de mensagem e hospedada em
// functions-moderacao — porque ela precisa consultar `avaliarContato`, bloqueio e
// `playerModeration`, que ja moram ali. Um segundo bundle significaria um segundo
// artefato de deploy carregando a MESMA copia do dominio de moderacao.
//
// A fronteira deste arquivo nao muda: aqui so entra conversao de tipo.

/// Reconstroi o canal a partir do JSON.
///
/// Devolve `null` quando o TypeScript nao encontrou o documento do canal — e a
/// porta trata `null` como [RecusaMensagem.canalDesconhecido]. Nao inventar canal
/// aqui e o ponto: quem abre canal e o motor de partidas.
CanalDeChat? _canal(Object? bruto) {
  if (bruto is! Map) return null;
  final m = bruto.cast<String, Object?>();

  final superficie = SuperficieChat.porWire(m['superficie']);
  if (superficie == null) return null;

  final lista = (m['participantes'] as List?) ?? const [];
  final participantes = <ParticipanteDoCanal>[];
  for (final item in lista) {
    if (item is! Map) continue;
    final p = item.cast<String, Object?>();
    final uid = p['uid'];
    if (uid is! String) continue;
    // Papel desconhecido vira `foraDoCanal`, e nao `jogadorSentado`: falhar
    // fechado e o que impede um valor novo no documento do canal virar direito de
    // fala por descuido.
    final papel = PapelNoCanal.values.firstWhere(
      (v) => v.wire == p['papel'],
      orElse: () => PapelNoCanal.foraDoCanal,
    );
    participantes.add(ParticipanteDoCanal(uid: uid, papel: papel));
  }

  return CanalDeChat(
    canalId: (m['canalId'] as String?) ?? '',
    superficie: superficie,
    participantes: participantes,
    // Ausente vira FECHADO. Um documento de canal sem o campo nao autoriza fala.
    aberto: m['aberto'] == true,
  );
}

String avaliarEnvioChatJson(String json) {
  final e = _entrada(json);

  final contatos = <ParDeContato>[];
  for (final item in (e['contatos'] as List?) ?? const []) {
    if (item is! Map) continue;
    final c = item.cast<String, Object?>();
    final uid = c['uid'];
    if (uid is! String) continue;
    contatos.add(ParDeContato(
      uid: uid,
      autorBloqueou: c['autorBloqueou'] == true,
      bloqueouOAutor: c['bloqueouOAutor'] == true,
    ));
  }

  final s = (e['sancao'] as Map?)?.cast<String, Object?>() ?? const {};

  // Só as CHAVES do payload atravessam. O valor nao interessa para a trava da
  // §10/§13 — a presenca do campo e que recusa — e mandar os valores obrigaria a
  // serializar dado arbitrario do cliente por dentro do dominio sem necessidade.
  final campos = <String, Object?>{};
  for (final k in (e['camposDoPayload'] as List?) ?? const []) {
    if (k is String) campos[k] = null;
  }

  final veredito = avaliarEnvio(
    autorUid: (e['autorUid'] as String?) ?? '',
    intentId: (e['intentId'] as String?) ?? '',
    conteudoBruto: e['conteudo'],
    superficiePedida: e['superficie'],
    canal: _canal(e['canal']),
    sancao: SancaoDoAutor(
      chatSilenciado: s['chatSilenciado'] == true,
      restricaoSocial: s['restricaoSocial'] == true,
      suspenso: s['suspenso'] == true,
    ),
    contatos: contatos,
    payloadCru: campos,
    autorPublicId: e['autorPublicId'] as String?,
  );

  return jsonEncode({
    ...veredito.toJson(),
    'esquema': kEsquemaChat,
  });
}

/// A classificação da §11, exposta para que o laudo e o teste do TypeScript leiam
/// a MESMA tabela que o dominio aplica — em vez de uma segunda copia em prosa.
String politicaDeSuperficiesJson(String json) => jsonEncode({
      'superficies': [
        for (final s in SuperficieChat.values)
          {
            'superficie': s.wire,
            'politica': politicaDe(s).wire,
            'aceitaTextoLivre': superficieAceitaTextoLivre(s),
          },
      ],
      'limiteMensagem': kLimiteMensagem,
      'esquema': kEsquemaChat,
    });

// -------------------------------------------------------------- comunicacao
//
// A OS de Comunicacao Controlada acrescenta QUATRO portas a esta ponte, e
// nenhuma delas decide coisa alguma aqui: a decisao inteira mora em
// app/lib/comunicacao/porta.dart, e o que existe abaixo e conversao de tipo.
//
// A porta do chat livre (`avaliarEnvioChat`) CONTINUA exportada e continua sendo
// chamada — ela e a autoridade sobre texto, e `avaliarComunicacao` a consome. Nao
// se remove um ingresso provado para pendurar outro no lugar.

/// Reconstroi o canal COM AMBIENTE.
///
/// `null` quando o documento nao existe, quando a superficie e desconhecida ou
/// quando o AMBIENTE e desconhecido — e as tres viram
/// `RecusaMensagem.canalDesconhecido` na porta. Ambiente ilegivel nao vira
/// "publica": um canal cujo ambiente ninguem sabe ler nao autoriza nada.
CanalDeComunicacao? _canalDeComunicacao(Object? bruto) {
  if (bruto is! Map) return null;
  final m = bruto.cast<String, Object?>();

  final base = _canal(bruto);
  if (base == null) return null;

  final ambiente = AmbienteDeComunicacao.porWire(m['ambiente']);
  if (ambiente == null) return null;

  return CanalDeComunicacao(
    canal: base,
    ambiente: ambiente,
    // Ausente e desconhecido viram `desligado` (ver `modoPorWire`). Um canal sem
    // modo declarado nao concede comunicacao nenhuma.
    modo: modoPorWire(m['modo']),
  );
}

DateTime _agora(Object? v) {
  if (v is String) {
    final t = DateTime.tryParse(v);
    if (t != null) return t.toUtc();
  }
  // Sem instante nao ha decisao temporal possivel — e inventar `DateTime.now()`
  // aqui furaria a disciplina de relogio unico da operacao. A epoca faz toda
  // janela de ritmo parecer vencida e todo direito parecer expirado: o desfecho
  // conservador nas duas contas.
  return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
}

String avaliarComunicacaoJson(String json) {
  final e = _entrada(json);

  final contatos = <ParDeContato>[];
  for (final item in (e['contatos'] as List?) ?? const []) {
    if (item is! Map) continue;
    final c = item.cast<String, Object?>();
    final uid = c['uid'];
    if (uid is! String) continue;
    contatos.add(ParDeContato(
      uid: uid,
      autorBloqueou: c['autorBloqueou'] == true,
      bloqueouOAutor: c['bloqueouOAutor'] == true,
    ));
  }

  final silenciaram = <String>[];
  for (final uid in (e['silenciaramOAutor'] as List?) ?? const []) {
    if (uid is String) silenciaram.add(uid);
  }

  final campos = <String>[];
  for (final k in (e['camposDoPayload'] as List?) ?? const []) {
    if (k is String) campos.add(k);
  }

  final s = (e['sancao'] as Map?)?.cast<String, Object?>() ?? const {};

  final veredito = avaliarComunicacao(
    autorUid: (e['autorUid'] as String?) ?? '',
    intentId: (e['intentId'] as String?) ?? '',
    tipoPedido: e['tipo'],
    itemIdPedido: e['itemId'],
    conteudoBruto: e['conteudo'],
    canal: _canalDeComunicacao(e['canal']),
    sancao: SancaoDoAutor(
      chatSilenciado: s['chatSilenciado'] == true,
      restricaoSocial: s['restricaoSocial'] == true,
      suspenso: s['suspenso'] == true,
    ),
    agora: _agora(e['agora']),
    contatos: contatos,
    silenciaramOAutor: silenciaram,
    camposDoPayload: campos,
    autorPublicId: e['autorPublicId'] as String?,
    // O documento de `playerEntitlements/{uid}` COMO ESTA. Quem decide vigencia
    // e `EntitlementVip.vigenteEm`, dentro da porta.
    entitlementBruto: (e['entitlement'] as Map?)?.cast<String, Object?>(),
    ritmo: EstadoDeRitmo.fromJson(e['ritmo']),
    versaoDeCatalogoDoCliente:
        (e['versaoDeCatalogoDoCliente'] as num?)?.toInt() ?? kVersaoDoCatalogo,
  );

  return jsonEncode(veredito.toJson());
}

String avaliarEventoDeSistemaJson(String json) {
  final e = _entrada(json);
  return jsonEncode(avaliarEventoDeSistema(
    eventoIdPedido: e['eventoId'],
    canal: _canalDeComunicacao(e['canal']),
    intentId: (e['intentId'] as String?) ?? '',
    // Decidido pelo EXECUTOR (claim `motorDePartidas` ou `admin`), nunca lido do
    // payload de um jogador. Ausente e `false`.
    autoridadeConfirmada: e['autoridadeConfirmada'] == true,
  ).toJson());
}

/// A MATRIZ da §2, exposta inteira.
///
/// Existe para que o teste do TypeScript e o laudo leiam a MESMA tabela que a
/// porta aplica, em vez de uma segunda copia em prosa — o mesmo motivo de
/// [politicaDeSuperficiesJson].
String politicaDeAmbientesJson(String json) => jsonEncode({
      'ambientes': [
        for (final a in AmbienteDeComunicacao.values)
          {
            'ambiente': a.wire,
            'ehMesa': a.ehMesa,
            'ehSaguao': a.ehSaguao,
            'modos': [
              for (final m in ModoDeComunicacao.values)
                {
                  'modo': m.wire,
                  'permitidoNoAmbiente': modoPermitidoNoAmbiente(a, m),
                  ...permissaoDe(a, m).toJson(),
                },
            ],
          },
      ],
      'tiposDeMesa': {
        for (final t in const [
          kTipoMesaPublica,
          kTipoMesaVipRanqueada,
          kTipoMesaPrivada,
          kTipoMesaTreino,
        ])
          t: ambienteDeTipoDeMesa(t)?.wire,
      },
      'ritmo': ConfiguracaoDeRitmo.padrao.toJson(),
      'versaoDoCatalogo': kVersaoDoCatalogo,
      'versaoDoContrato': kVersaoContratoComunicacao,
      'esquema': kEsquemaComunicacao,
    });

/// O `messageId` derivado de autor + intencao, e nada mais.
///
/// EXISTE PARA A REPETICAO, e nao por conveniencia. O executor precisa saber,
/// ANTES de decidir qualquer coisa, se este pedido ja virou mensagem — porque
/// um retry nao pode ser barrado pelo anti-spam.
///
/// A derivacao continua sendo do dominio: o executor nao calcula digest nenhum.
String idDeMensagemJson(String json) {
  final e = _entrada(json);
  return jsonEncode({
    'messageId': mensagemIdDe(
      autorUid: (e['autorUid'] as String?) ?? '',
      intentId: (e['intentId'] as String?) ?? '',
    ),
  });
}

/// Resolve o AMBIENTE a partir do que o servidor de mesas declara.
///
/// Existe para que `definirCanalDeChat` (TypeScript) nao carregue uma copia da
/// tabela de traducao. O TypeScript le documentos e grava; a tabela mora no
/// dominio, e o teste de espelho a amarra a `functions-mesas/src/tipos.ts`.
///
/// Devolve tambem `exigeSalaRegistrada`: quando o ambiente resolvido for a Mesa
/// Privada, o executor AINDA precisa encontrar a sala em `salasPrivadas` antes
/// de conceder o ambiente. Sinalizar isso aqui evita que o executor precise
/// saber qual ambiente e especial.
String resolverAmbienteJson(String json) {
  final e = _entrada(json);
  final tipoDeMesa = tipoDeMesaDoServidor(
    tipoPartida: e['tipoPartida'],
    categoriaCompetitiva: e['categoriaCompetitiva'],
  );
  final ambiente = ambienteDeTipoDeMesa(tipoDeMesa);
  final modo = modoPorWire(e['modo']);

  return jsonEncode({
    'tipoDeMesa': tipoDeMesa,
    'ambiente': ambiente?.wire,
    'superficie': ambiente == null ? null : superficieDe(ambiente).wire,
    'exigeSalaRegistrada': ambiente == AmbienteDeComunicacao.mesaPrivada,
    'modoPermitidoNoAmbiente':
        ambiente != null && modoPermitidoNoAmbiente(ambiente, modo),
    'aceitaComunicacao':
        ambiente != null && permissaoDe(ambiente, modo).algumaCoisa,
  });
}

/// Normaliza um  digitado ou copiado, para que a autoridade de
/// moderacao possa RESOLVER o alvo pelo indice reverso (§9.3).
///
/// A funcao vem de app/lib/social/identidade_publica.dart — a mesma que
/// functions-social usa. NAO ha copia: o arquivo entra neste bundle por import,
/// e um reparo de digitacao corrigido la vale aqui no mesmo commit.
String normalizarPublicIdJson(String json) {
  final e = _entrada(json);
  return jsonEncode({'publicId': normalizarIdPublico(e['publicId'])});
}

/// O catalogo autoritativo, para leitura.
///
/// Serve ao cliente (que precisa saber o que oferecer), ao teste e ao laudo. Nao
/// aceita filtro do cliente: quem pergunta recebe o catalogo inteiro, e a decisao
/// de aceitar ou nao um item premium continua sendo tomada no ENVIO, contra o
/// direito vigente naquele instante.
String catalogoJson(String json) => jsonEncode({
      'versao': kVersaoDoCatalogo,
      'itens': [for (final i in catalogoV1) i.toJson()],
      'eventosDeSistema': [
        for (final ev in catalogoDeEventosDeSistema) ev.toJson(),
      ],
    });

void main() {
  final api = <String, _Ponte>{
    'avaliarDenuncia': avaliarDenunciaJson,
    'statusPublico': statusPublicoJson,
    'avaliarBloqueio': avaliarBloqueioJson,
    'avaliarMute': avaliarMuteJson,
    'avaliarContato': avaliarContatoJson,
    'avaliarSancao': avaliarSancaoJson,
    'consolidarSancoes': consolidarSancoesJson,
    'avaliarEnvioChat': avaliarEnvioChatJson,
    'politicaDeSuperficies': politicaDeSuperficiesJson,
    'avaliarComunicacao': avaliarComunicacaoJson,
    'avaliarEventoDeSistema': avaliarEventoDeSistemaJson,
    'politicaDeAmbientes': politicaDeAmbientesJson,
    'resolverAmbiente': resolverAmbienteJson,
    'idDeMensagem': idDeMensagemJson,
    'normalizarPublicId': normalizarPublicIdJson,
    'catalogo': catalogoJson,
  };

  final exportado = JSObject();
  api.forEach((nome, fn) {
    exportado.setProperty(
        nome.toJS, ((JSString entrada) => fn(entrada.toDart).toJS).toJS);
  });
  _bmvModeracao = exportado;
}
