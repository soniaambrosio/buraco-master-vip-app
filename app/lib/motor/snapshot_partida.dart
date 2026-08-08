// snapshot_partida.dart — SERIALIZAÇÃO E RETOMADA DO MOTOR (OS-01 §9).
//
// Problema que este arquivo resolve: hoje o `Jogo` (mesa.dart) só existe em
// memória. Se o jogador cai, não há como devolvê-lo ao estado REAL da partida —
// o cliente teria que reconstruir de palpite, que é exatamente o defeito que a
// ordem de serviço proíbe ("o jogador deve retornar ao estado real da partida
// sem reconstrução incorreta pelo cliente").
//
// Garantias desta camada:
//   1. DETERMINISMO — o mesmo estado produz sempre o MESMO mapa, com as chaves
//      na mesma ordem. Dois snapshots do mesmo estado são byte-a-byte iguais,
//      o que permite comparar "a mão mudou entre o t1 e o t2?" com um hash.
//   2. FIDELIDADE — inclui os escalares privados do motor (obrigação do topo do
//      lixo, mortos convertidos, iniciador da rodada, rodada já contada,
//      contador de ids). Sem eles a partida retomada joga diferente.
//   3. RECUSA DE ESTADO IMPOSSÍVEL — restaurar roda a auditoria de integridade
//      do próprio motor. Snapshot corrompido NÃO abre a mesa: levanta
//      ErroSnapshot preservando o código auditável.
//
// Nada aqui decide regra de jogo. É codec puro.

import '../mesa.dart';

/// Versão do FORMATO do snapshot (não é a versão do estado da partida).
/// Sobe quando o formato deixa de ser lido pela versão anterior.
const int kVersaoFormatoSnapshot = 1;

/// Falha ao capturar ou restaurar um snapshot.
///
/// [codigo] é estável e auditável (entra no log); [detalhe] é humano.
class ErroSnapshot implements Exception {
  final String codigo;
  final String detalhe;
  const ErroSnapshot(this.codigo, this.detalhe);

  @override
  String toString() => 'ErroSnapshot($codigo): $detalhe';
}

/// Codec do estado completo de uma partida.
class SnapshotPartida {
  const SnapshotPartida._();

  // ---------- carta ----------

  static Map<String, Object?> _carta(Carta c) => {
        'id': c.id,
        'naipe': c.naipe,
        'valor': c.valor,
        'coringa': c.ehCoringa,
      };

  static Carta _lerCarta(Object? raw, String onde) {
    if (raw is! Map) {
      throw ErroSnapshot('CARTA_MALFORMADA', 'carta não é objeto em $onde');
    }
    final id = raw['id'];
    final valor = raw['valor'];
    if (id is! String || id.isEmpty || valor is! String || valor.isEmpty) {
      throw ErroSnapshot('CARTA_MALFORMADA', 'id/valor ausente em $onde');
    }
    final naipe = raw['naipe'];
    if (naipe != null && naipe is! String) {
      throw ErroSnapshot('CARTA_MALFORMADA', 'naipe inválido em $onde');
    }
    return Carta(id, naipe as String?, valor, raw['coringa'] == true);
  }

  static List<Object?> _cartas(List<Carta> cs) => [for (final c in cs) _carta(c)];

  static List<Carta> _lerCartas(Object? raw, String onde) {
    if (raw is! List) {
      throw ErroSnapshot('ZONA_MALFORMADA', '$onde não é lista');
    }
    return [for (final e in raw) _lerCarta(e, onde)];
  }

  static List<List<Carta>> _lerGrupos(Object? raw, String onde) {
    if (raw is! List) {
      throw ErroSnapshot('ZONA_MALFORMADA', '$onde não é lista');
    }
    return [for (var i = 0; i < raw.length; i++) _lerCartas(raw[i], '$onde[$i]')];
  }

  // ---------- captura ----------

  /// Mapa determinístico com TODO o estado da partida.
  ///
  /// A ordem das cartas dentro de cada zona é preservada: ela é significativa
  /// (topo do monte, topo do lixo, ordem da mão escolhida pelo jogador).
  static Map<String, Object?> capturar(Jogo j) => {
        'versaoFormato': kVersaoFormatoSnapshot,
        // mesa
        'modalidade': j.modalidade,
        'metaPontos': j.metaPontos,
        'apelidos': List<String>.from(j.apelidos),
        'avatares': List<String>.from(j.avatares),
        'mascotes': List<String>.from(j.mascotes),
        // zonas de cartas
        'maos': [for (final m in j.maos) _cartas(m)],
        'monte': _cartas(j.monte),
        'lixo': _cartas(j.lixo),
        'mortos': [for (final m in j.mortos) _cartas(m)],
        'jogosNos': [for (final g in j.jogosDupla['nos']!) _cartas(g)],
        'jogosEles': [for (final g in j.jogosDupla['eles']!) _cartas(g)],
        // turno
        'vez': j.vez,
        'jaComprou': j.jaComprou,
        'lixoTopoObrigatorio': j.lixoTopoObrigatorio,
        // rodada
        'rodada': j.rodada,
        'rodadaEncerrada': j.rodadaEncerrada,
        'duplaQueBateu': j.duplaQueBateu,
        'assentoQueBateu': j.assentoQueBateu,
        'mortoPegoNos': j.mortoPego['nos'] ?? false,
        'mortoPegoEles': j.mortoPego['eles'] ?? false,
        // placar
        'placarNos': j.placar['nos'] ?? 0,
        'placarEles': j.placar['eles'] ?? 0,
        'encerrada': j.encerrada,
        'pontosRodada': j.pontosRodada,
        // vulnerabilidade
        'rodadasVulneravelNos': j.rodadasVulneravel['nos'] ?? 0,
        'rodadasVulneravelEles': j.rodadasVulneravel['eles'] ?? 0,
        'primeiraBaixadaNos': j.primeiraBaixadaFeita['nos'] ?? false,
        'primeiraBaixadaEles': j.primeiraBaixadaFeita['eles'] ?? false,
        // bloqueio crítico
        'integridadeErro': j.integridadeErro,
        // escalares privados do motor
        'interno': j.estadoInternoParaSnapshot(),
      };

  // ---------- restauração ----------

  static int _int(Map<String, Object?> m, String k, {int padrao = 0}) {
    final v = m[k];
    if (v == null) return padrao;
    if (v is num) return v.toInt();
    throw ErroSnapshot('CAMPO_INVALIDO', '$k deveria ser número');
  }

  static String _str(Map<String, Object?> m, String k, String padrao) {
    final v = m[k];
    if (v == null) return padrao;
    if (v is String) return v;
    throw ErroSnapshot('CAMPO_INVALIDO', '$k deveria ser texto');
  }

  /// Texto opcional que precisa SER texto quando presente.
  ///
  /// `as String?` num valor numérico lança `TypeError`, que é falha de
  /// programa. Aqui vira [ErroSnapshot], que é decisão de domínio.
  static String? _strOpcional(Map<String, Object?> m, String k) {
    final v = m[k];
    if (v == null) return null;
    if (v is String) return v;
    throw ErroSnapshot('CAMPO_INVALIDO', '$k deveria ser texto ou nulo');
  }

  // ---------- campos internos obrigatórios ----------
  //
  // Os cinco escalares do bloco `interno` existem porque MUDAM o que é legal no
  // turno. Deixá-los cair num default quando faltam é o pior desfecho possível:
  // a partida reabre parecendo idêntica e jogando diferente — some a obrigação
  // do topo do lixo, a carta proibida volta a poder ser descartada, o -100 do
  // morto reaparece. Melhor recusar a restauração do que aproximá-la.

  static int _internoInt(Map<String, Object?> m, String k) {
    if (!m.containsKey(k)) {
      throw ErroSnapshot('INTERNO_INCOMPLETO', 'campo obrigatório "$k" ausente');
    }
    final v = m[k];
    if (v is num) return v.toInt();
    throw ErroSnapshot('INTERNO_INVALIDO', '"$k" deveria ser número, veio ${v.runtimeType}');
  }

  static bool _internoBool(Map<String, Object?> m, String k) {
    if (!m.containsKey(k)) {
      throw ErroSnapshot('INTERNO_INCOMPLETO', 'campo obrigatório "$k" ausente');
    }
    final v = m[k];
    if (v is bool) return v;
    throw ErroSnapshot('INTERNO_INVALIDO', '"$k" deveria ser booleano, veio ${v.runtimeType}');
  }

  /// Texto que pode ser nulo, mas cuja CHAVE é obrigatória.
  ///
  /// A distinção importa: `null` significa "não há pendência", enquanto chave
  /// ausente significa "o snapshot não sabe" — e as duas coisas não podem ser
  /// confundidas.
  static String? _internoTextoOuNulo(Map<String, Object?> m, String k) {
    if (!m.containsKey(k)) {
      throw ErroSnapshot('INTERNO_INCOMPLETO', 'campo obrigatório "$k" ausente');
    }
    final v = m[k];
    if (v == null || v is String) return v as String?;
    throw ErroSnapshot('INTERNO_INVALIDO', '"$k" deveria ser texto ou nulo, veio ${v.runtimeType}');
  }

  /// Valida o bloco `interno` inteiro antes de qualquer coisa ser aplicada.
  static Map<String, Object?> _validarInterno(Object? bruto) {
    if (bruto is! Map) {
      throw const ErroSnapshot('ESTRUTURA_INVALIDA', 'bloco "interno" ausente');
    }
    final m = Map<String, Object?>.from(bruto);
    return {
      'contadorIds': _internoInt(m, 'contadorIds'),
      'lixoUnicoCompradoId': _internoTextoOuNulo(m, 'lixoUnicoCompradoId'),
      'mortosConvertidos': _internoInt(m, 'mortosConvertidos'),
      'iniciadorRodada': _internoInt(m, 'iniciadorRodada'),
      'rodadaContada': _internoBool(m, 'rodadaContada'),
    };
  }

  static List<String> _listaTexto(Object? raw, String onde, int tamanho) {
    if (raw is! List || raw.length != tamanho) {
      throw ErroSnapshot('CAMPO_INVALIDO', '$onde deveria ter $tamanho itens');
    }
    return [
      for (final e in raw)
        if (e is String) e else throw ErroSnapshot('CAMPO_INVALIDO', '$onde tem item não-texto'),
    ];
  }

  /// Reconstrói o `Jogo` a partir de um snapshot.
  ///
  /// Recusa (lança [ErroSnapshot]) quando o formato é desconhecido, a estrutura
  /// está fora do contrato, ou o estado reconstruído reprova na auditoria de
  /// integridade do motor. Nunca "conserta" inventando carta.
  static Jogo restaurar(Map<String, Object?> json) {
    final versao = _int(json, 'versaoFormato', padrao: -1);
    if (versao != kVersaoFormatoSnapshot) {
      throw ErroSnapshot('VERSAO_FORMATO_INCOMPATIVEL',
          'snapshot na versão $versao, este motor lê $kVersaoFormatoSnapshot');
    }

    // Valida o bloco interno ANTES de construir qualquer coisa: se ele estiver
    // incompleto, a restauração inteira é inválida e nada deve ser montado.
    final interno = _validarInterno(json['interno']);

    final apelidos = _listaTexto(json['apelidos'], 'apelidos', 4);
    final avatares = _listaTexto(json['avatares'], 'avatares', 4);
    final mascotes = _listaTexto(json['mascotes'], 'mascotes', 4);

    // O construtor distribui uma partida nova; sobrescrevemos tudo em seguida.
    final j = Jogo(apelidos, avatares, mascotes);

    final maos = _lerGrupos(json['maos'], 'maos');
    if (maos.length != 4) {
      throw ErroSnapshot('ESTRUTURA_INVALIDA', 'esperava 4 mãos, veio ${maos.length}');
    }

    j.modalidade = _str(json, 'modalidade', 'ABERTO');
    j.metaPontos = _int(json, 'metaPontos', padrao: 1500);

    j.maos = maos;
    j.monte = _lerCartas(json['monte'], 'monte');
    j.lixo = _lerCartas(json['lixo'], 'lixo');
    j.mortos = _lerGrupos(json['mortos'], 'mortos');
    j.jogosDupla = {
      'nos': _lerGrupos(json['jogosNos'], 'jogosNos'),
      'eles': _lerGrupos(json['jogosEles'], 'jogosEles'),
    };

    j.vez = _int(json, 'vez');
    if (j.vez < 0 || j.vez > 3) {
      throw ErroSnapshot('ESTRUTURA_INVALIDA', 'assento da vez fora de 0..3: ${j.vez}');
    }
    j.jaComprou = json['jaComprou'] == true;
    j.lixoTopoObrigatorio = _strOpcional(json, 'lixoTopoObrigatorio');

    j.rodada = _int(json, 'rodada');
    j.rodadaEncerrada = json['rodadaEncerrada'] == true;
    j.duplaQueBateu = _strOpcional(json, 'duplaQueBateu');
    j.assentoQueBateu = json['assentoQueBateu'] == null ? null : _int(json, 'assentoQueBateu');
    j.mortoPego = {
      'nos': json['mortoPegoNos'] == true,
      'eles': json['mortoPegoEles'] == true,
    };

    j.placar = {
      'nos': _int(json, 'placarNos'),
      'eles': _int(json, 'placarEles'),
    };
    j.encerrada = json['encerrada'] == true;
    final pr = json['pontosRodada'];
    if (pr == null) {
      j.pontosRodada = null;
    } else if (pr is Map) {
      j.pontosRodada = Map<String, dynamic>.from(pr);
    } else {
      throw const ErroSnapshot(
          'CAMPO_INVALIDO', 'pontosRodada deveria ser objeto ou nulo');
    }

    j.rodadasVulneravel = {
      'nos': _int(json, 'rodadasVulneravelNos'),
      'eles': _int(json, 'rodadasVulneravelEles'),
    };
    j.primeiraBaixadaFeita = {
      'nos': json['primeiraBaixadaNos'] == true,
      'eles': json['primeiraBaixadaEles'] == true,
    };

    j.aplicarEstadoInternoDeSnapshot(interno);

    // Auditoria do PRÓPRIO motor: é ela quem diz se este estado é possível.
    j.integridadeErro = null;
    if (!j.auditarIntegridade()) {
      throw ErroSnapshot('SNAPSHOT_CORROMPIDO', j.integridadeErro ?? 'integridade reprovada');
    }

    // Um snapshot tirado de uma mesa JÁ bloqueada continua bloqueado: o bloqueio
    // é informação da partida, não sujeira do transporte.
    final erroOriginal = json['integridadeErro'];
    if (erroOriginal is String && erroOriginal.isNotEmpty) {
      j.integridadeErro = erroOriginal;
    }
    return j;
  }

  // ---------- impressão digital ----------

  /// Hash estável (FNV-1a 64 bits, em hexadecimal) de um snapshot.
  ///
  /// Serve para o diagnóstico: dois eventos com a mesma impressão viram prova de
  /// que o estado NÃO mudou entre eles, sem precisar guardar as cartas no log.
  static String impressao(Map<String, Object?> snapshot) =>
      _fnv1a(_canonico(snapshot));

  /// Impressão digital de um conjunto de cartas (ex.: a mão de um assento).
  ///
  /// Independe da ordem — responde "são as MESMAS cartas?", que é a pergunta da
  /// reclamação "caí e quando voltei minha mão estava diferente".
  static String impressaoDeCartas(List<Carta> cartas) {
    final ids = [for (final c in cartas) c.id]..sort();
    return _fnv1a('${ids.length}:${ids.join(",")}');
  }

  /// Texto canônico e determinístico de uma estrutura JSON.
  ///
  /// Mapas saem com as chaves ordenadas, então a impressão não depende da ordem
  /// de inserção de quem montou o mapa (útil para snapshots que voltaram da rede).
  static String _canonico(Object? v) {
    if (v == null) return 'n';
    if (v is num) return 'i${v.toString()}';
    if (v is bool) return v ? 'T' : 'F';
    if (v is String) return 's${v.length}:$v';
    if (v is List) return '[${[for (final e in v) _canonico(e)].join(",")}]';
    if (v is Map) {
      final chaves = [for (final k in v.keys) k.toString()]..sort();
      return '{${[for (final k in chaves) '$k=${_canonico(v[k])}'].join(",")}}';
    }
    return 's${v.toString()}';
  }

  static String _fnv1a(String s) {
    // FNV-1a de 64 bits em duas metades de 32 bits: Dart web não tem inteiro de
    // 64 bits nativo, então a aritmética é feita em 32 bits para o resultado ser
    // idêntico no celular e no navegador.
    var h1 = 0x811c9dc5, h2 = 0xcbf29ce4;
    for (final u in s.codeUnits) {
      h1 = ((h1 ^ u) * 0x01000193) & 0xffffffff;
      h2 = ((h2 ^ (u + 0x9e3779b9)) * 0x01000193) & 0xffffffff;
    }
    final a = h1.toRadixString(16).padLeft(8, '0');
    final b = h2.toRadixString(16).padLeft(8, '0');
    return '$a$b';
  }
}
