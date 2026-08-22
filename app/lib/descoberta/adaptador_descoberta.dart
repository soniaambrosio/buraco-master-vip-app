// adaptador_descoberta.dart — a FRONTEIRA entre o mapa cru e o modelo tipado.
//
// ---------------------------------------------------------------------------
// FAIL-CLOSED, E O QUE ISSO CUSTA DE PROPÓSITO
// ---------------------------------------------------------------------------
//
// Este arquivo tem uma regra só: OU o retrato inteiro é construído, OU ele não
// existe. Não há retrato parcial, não há campo completado por padrão, não há
// mesa descartada individualmente para "salvar o resto".
//
// A alternativa — tolerar o que não se entende — parece generosa e é o oposto
// disso. Um retrato com uma mesa mal-formada tolerada vira uma lista em que
// falta uma mesa e ninguém sabe; um `vagas` negativo tolerado vira "0 vagas"
// numa mesa que na verdade está quebrada. Recusar transforma um defeito
// silencioso num estado que a tela mostra e alguém investiga.
//
// E recusar NÃO apaga o que já valia: quem chama guarda o último retrato válido
// (ver `estado_descoberta.dart`). Uma resposta ruim não esvazia a lista.
//
// ---------------------------------------------------------------------------
// A VARREDURA DE CHAVE PROIBIDA
// ---------------------------------------------------------------------------
//
// O servidor monta a projeção campo a campo e a suíte de lá varre o payload
// atrás de uid. Esta é a segunda tranca, do lado de cá: se um dia a projeção
// regredir e mandar `jogadorId`, o retrato inteiro é recusado — o dado não
// chega ao modelo de apresentação e não chega à memória de nada que desenhe.
//
// A varredura é RECURSIVA e olha CHAVES, em qualquer profundidade. Olhar só o
// primeiro nível deixaria passar um uid dentro de um assento, que é exatamente
// onde ele moraria.

import 'contrato_descoberta.dart';
import 'modelo_descoberta.dart';

/// Por que um retrato foi recusado. Serve para o log e para o teste afirmar a
/// CAUSA, e não só "deu null" — que passaria com qualquer defeito.
enum RecusaDeRetrato {
  naoEhMapa,
  esquemaDesconhecido,
  campoAusente,
  tipoIncorreto,
  campoDesconhecido,
  chaveProibida,
  numeroNegativo,
  capacidadeInvalida,
  assentosInvalidos,
  modalidadeDesconhecida,
  ingressoDesconhecido,
  presencaIncoerente,
}

/// Resultado da tradução: um dos dois lados é nulo, nunca os dois.
class LeituraDoRetrato {
  const LeituraDoRetrato.aceito(this.retrato) : recusa = null;
  const LeituraDoRetrato.recusado(this.recusa) : retrato = null;

  final RetratoDaDescoberta? retrato;
  final RecusaDeRetrato? recusa;

  bool get ok => retrato != null;
}

/// Exceção interna do parse. Não escapa deste arquivo.
class _Recusa implements Exception {
  _Recusa(this.motivo);
  final RecusaDeRetrato motivo;
}

/// Traduz a mensagem `mesas` do servidor no retrato tipado.
class AdaptadorDaDescoberta {
  const AdaptadorDaDescoberta._();

  /// A única porta. `bruto` é a mensagem inteira, incluindo `tipo`.
  static LeituraDoRetrato ler(Object? bruto) {
    try {
      return LeituraDoRetrato.aceito(_lerRetrato(bruto));
    } on _Recusa catch (e) {
      return LeituraDoRetrato.recusado(e.motivo);
    }
  }

  // --- primitivas -----------------------------------------------------------

  static Never _recusar(RecusaDeRetrato motivo) => throw _Recusa(motivo);

  static Map<String, Object?> _mapa(Object? v) {
    if (v is! Map) _recusar(RecusaDeRetrato.tipoIncorreto);
    final saida = <String, Object?>{};
    for (final e in v.entries) {
      final k = e.key;
      if (k is! String) _recusar(RecusaDeRetrato.tipoIncorreto);
      saida[k] = e.value;
    }
    return saida;
  }

  /// Inteiro ESTRITO. `num` que não é inteiro, `String` numérica e `bool` são
  /// recusados — aceitar `"2"` seria aceitar um servidor que mudou de tipo sem
  /// mudar de versão, e é assim que um contrato morre em silêncio.
  static int _inteiro(Map<String, Object?> m, String campo) {
    if (!m.containsKey(campo)) _recusar(RecusaDeRetrato.campoAusente);
    final v = m[campo];
    if (v is! int) _recusar(RecusaDeRetrato.tipoIncorreto);
    return v;
  }

  /// Inteiro que não pode ser negativo. Contagem negativa é defeito, não dado.
  static int _contagem(Map<String, Object?> m, String campo) {
    final v = _inteiro(m, campo);
    if (v < 0) _recusar(RecusaDeRetrato.numeroNegativo);
    return v;
  }

  static bool _booleano(Map<String, Object?> m, String campo) {
    if (!m.containsKey(campo)) _recusar(RecusaDeRetrato.campoAusente);
    final v = m[campo];
    if (v is! bool) _recusar(RecusaDeRetrato.tipoIncorreto);
    return v;
  }

  static String _texto(Map<String, Object?> m, String campo) {
    if (!m.containsKey(campo)) _recusar(RecusaDeRetrato.campoAusente);
    final v = m[campo];
    if (v is! String) _recusar(RecusaDeRetrato.tipoIncorreto);
    if (v.isEmpty) _recusar(RecusaDeRetrato.tipoIncorreto);
    return v;
  }

  static String? _textoOuNulo(Map<String, Object?> m, String campo) {
    if (!m.containsKey(campo)) _recusar(RecusaDeRetrato.campoAusente);
    final v = m[campo];
    if (v == null) return null;
    if (v is! String) _recusar(RecusaDeRetrato.tipoIncorreto);
    return v;
  }

  static int? _inteiroOuNulo(Map<String, Object?> m, String campo) {
    if (!m.containsKey(campo)) _recusar(RecusaDeRetrato.campoAusente);
    final v = m[campo];
    if (v == null) return null;
    if (v is! int) _recusar(RecusaDeRetrato.tipoIncorreto);
    return v;
  }

  /// Lista FECHADA: nem falta, nem sobra. Sobrar é tão grave quanto faltar —
  /// campo novo não anunciado é mudança de contrato sem versão.
  static void _exigirChaves(Map<String, Object?> m, Set<String> esperadas) {
    for (final k in esperadas) {
      if (!m.containsKey(k)) _recusar(RecusaDeRetrato.campoAusente);
    }
    for (final k in m.keys) {
      if (!esperadas.contains(k)) _recusar(RecusaDeRetrato.campoDesconhecido);
    }
  }

  /// Varredura recursiva por chave proibida. Ver o cabeçalho.
  static void _exigirSemChaveProibida(Object? v) {
    if (v is Map) {
      for (final e in v.entries) {
        final k = e.key;
        if (k is String && ContratoDaDescoberta.chavesProibidas.contains(k)) {
          _recusar(RecusaDeRetrato.chaveProibida);
        }
        _exigirSemChaveProibida(e.value);
      }
      return;
    }
    if (v is List) {
      for (final item in v) {
        _exigirSemChaveProibida(item);
      }
    }
  }

  // --- retrato --------------------------------------------------------------

  static RetratoDaDescoberta _lerRetrato(Object? bruto) {
    if (bruto is! Map) _recusar(RecusaDeRetrato.naoEhMapa);
    final raiz = _mapa(bruto);

    // A varredura vem ANTES de qualquer leitura. Se há chave proibida, nada
    // deste payload deve ser interpretado — nem para decidir se é recusado.
    _exigirSemChaveProibida(raiz);

    // `tipo` é do envelope do transporte e não faz parte do contrato do
    // retrato; retirá-lo aqui é o que deixa a lista de campos ser FECHADA.
    final semTipo = Map<String, Object?>.from(raiz)..remove('tipo');
    _exigirChaves(semTipo, ContratoDaDescoberta.camposDoRetrato);

    if (_texto(semTipo, 'esquema') != ContratoDaDescoberta.esquema) {
      _recusar(RecusaDeRetrato.esquemaDesconhecido);
    }

    final geracao = _texto(semTipo, 'geracao');
    final revisao = _contagem(semTipo, 'revisao');
    final geradoEm = _texto(semTipo, 'geradoEm');

    final brutas = semTipo['mesas'];
    if (brutas is! List) _recusar(RecusaDeRetrato.tipoIncorreto);
    final mesas = <MesaPublica>[];
    for (final b in brutas) {
      mesas.add(_lerMesa(b));
    }

    final presenca = _lerPresenca(semTipo['presenca']);

    // COERÊNCIA ENTRE OS DOIS BLOCOS. O servidor já garante isto (a suíte de lá
    // afirma no mesmo retrato), então uma divergência aqui significa que o que
    // chegou não é um retrato coerente — e um retrato incoerente é pior que
    // nenhum, porque a tela mostraria dois números que se contradizem.
    if (presenca.mesasPublicas != mesas.length) {
      _recusar(RecusaDeRetrato.presencaIncoerente);
    }
    if (presenca.mesasPublicasComVagas > presenca.mesasPublicas) {
      _recusar(RecusaDeRetrato.presencaIncoerente);
    }
    if (presenca.jogadoresEmMesasPublicas > presenca.jogadoresOnlineTotal) {
      _recusar(RecusaDeRetrato.presencaIncoerente);
    }
    if (presenca.espectadoresOnline > presenca.jogadoresOnlineTotal) {
      _recusar(RecusaDeRetrato.presencaIncoerente);
    }
    if (presenca.jogadoresEmMesasPublicasAguardando +
            presenca.jogadoresEmMesasPublicasEmAndamento !=
        presenca.jogadoresEmMesasPublicas) {
      _recusar(RecusaDeRetrato.presencaIncoerente);
    }

    return RetratoDaDescoberta(
      geracao: geracao,
      revisao: revisao,
      geradoEm: geradoEm,
      mesas: List.unmodifiable(mesas),
      presenca: presenca,
    );
  }

  static MesaPublica _lerMesa(Object? bruto) {
    final m = _mapa(bruto);
    _exigirChaves(m, ContratoDaDescoberta.camposDaMesa);

    final capacidade = _contagem(m, 'capacidade');
    if (capacidade != ContratoDaDescoberta.capacidadeDaMesa) {
      _recusar(RecusaDeRetrato.capacidadeInvalida);
    }

    final modalidade = ModalidadeDeMesa.daChave(_texto(m, 'modalidade'));
    if (modalidade == null) _recusar(RecusaDeRetrato.modalidadeDesconhecida);

    final estado = EstadoDeIngresso.daChave(_texto(m, 'estadoIngresso'));
    if (estado == null) _recusar(RecusaDeRetrato.ingressoDesconhecido);

    final brutos = m['assentos'];
    if (brutos is! List) _recusar(RecusaDeRetrato.assentosInvalidos);
    if (brutos.length != ContratoDaDescoberta.capacidadeDaMesa) {
      _recusar(RecusaDeRetrato.assentosInvalidos);
    }
    final assentos = <AssentoPublico>[];
    for (var i = 0; i < brutos.length; i++) {
      assentos.add(_lerAssento(brutos[i], i));
    }

    final jogadores = _contagem(m, 'jogadores');
    final bots = _contagem(m, 'bots');
    final ocupados = _contagem(m, 'ocupados');
    final vagas = _contagem(m, 'vagas');

    // ARITMÉTICA DA MESA. As quatro contagens descrevem a MESMA mesa e têm de
    // fechar entre si e com os assentos. Um retrato que não fecha aqui não é
    // "quase certo": ele descreve duas mesas diferentes ao mesmo tempo.
    if (ocupados > capacidade) _recusar(RecusaDeRetrato.presencaIncoerente);
    if (jogadores + bots != ocupados) {
      _recusar(RecusaDeRetrato.presencaIncoerente);
    }
    if (vagas != capacidade - ocupados) {
      _recusar(RecusaDeRetrato.presencaIncoerente);
    }
    if (assentos.where((a) => a.ocupado).length != ocupados) {
      _recusar(RecusaDeRetrato.presencaIncoerente);
    }
    if (assentos.where((a) => a.ehHumano).length != jogadores) {
      _recusar(RecusaDeRetrato.presencaIncoerente);
    }

    return MesaPublica(
      codigo: _texto(m, 'codigo'),
      nome: _texto(m, 'nome'),
      modalidade: modalidade,
      metaPontos: _contagem(m, 'metaPontos'),
      capacidade: capacidade,
      jogadores: jogadores,
      bots: bots,
      ocupados: ocupados,
      vagas: vagas,
      assentos: List.unmodifiable(assentos),
      estadoIngresso: estado,
      ingressavel: _booleano(m, 'ingressavel'),
      aguardandoHa: Duration(milliseconds: _contagem(m, 'aguardandoHaMs')),
      revisao: _contagem(m, 'revisao'),
    );
  }

  static AssentoPublico _lerAssento(Object? bruto, int esperado) {
    final m = _mapa(bruto);
    _exigirChaves(m, ContratoDaDescoberta.camposDoAssento);

    // A POSIÇÃO TEM DE BATER COM O ÍNDICE. O contrato diz "índice = número do
    // assento"; se as duas coisas discordarem, desenhar a mesa colocaria gente
    // em cadeira errada — e a mesa é o lugar onde isso importa.
    final assento = _contagem(m, 'assento');
    if (assento != esperado) _recusar(RecusaDeRetrato.assentosInvalidos);

    final ocupado = _booleano(m, 'ocupado');
    final tipoBruto = _textoOuNulo(m, 'tipo');
    final apelido = _textoOuNulo(m, 'apelido');
    final avatar = _inteiroOuNulo(m, 'avatarGaleria');

    if (avatar != null && avatar <= 0) {
      _recusar(RecusaDeRetrato.numeroNegativo);
    }

    TipoDeOcupante? tipo;
    if (ocupado) {
      tipo = TipoDeOcupante.daChave(tipoBruto);
      // Ocupado sem tipo conhecido é assento que não se sabe descrever.
      if (tipo == null) _recusar(RecusaDeRetrato.assentosInvalidos);
    } else {
      // LIVRE NÃO CARREGA NADA. Assento livre com apelido ou avatar é resíduo
      // de alguém que saiu, e desenhá-lo mostraria um fantasma sentado.
      if (tipoBruto != null || apelido != null || avatar != null) {
        _recusar(RecusaDeRetrato.assentosInvalidos);
      }
    }

    return AssentoPublico(
      assento: assento,
      ocupado: ocupado,
      tipo: tipo,
      apelido: apelido,
      avatarGaleria: avatar,
    );
  }

  static PresencaAgregada _lerPresenca(Object? bruto) {
    final m = _mapa(bruto);
    _exigirChaves(m, ContratoDaDescoberta.camposDaPresenca);

    final porModalidadeBruto = _mapa(m['porModalidade']);
    // AS TRÊS, SEMPRE. Faltar uma faria o filtro dela mostrar contagem zero
    // sem que zero fosse verdade.
    if (porModalidadeBruto.length != ModalidadeDeMesa.values.length) {
      _recusar(RecusaDeRetrato.campoAusente);
    }
    final porModalidade = <ModalidadeDeMesa, PresencaDeModalidade>{};
    for (final modalidade in ModalidadeDeMesa.values) {
      final entrada = porModalidadeBruto[modalidade.chave];
      if (entrada == null) _recusar(RecusaDeRetrato.campoAusente);
      final e = _mapa(entrada);
      _exigirChaves(e, ContratoDaDescoberta.camposDaModalidade);
      final mesas = _contagem(e, 'mesas');
      final comVagas = _contagem(e, 'mesasComVagas');
      final jogadores = _contagem(e, 'jogadores');
      final aguardando = _contagem(e, 'jogadoresAguardando');
      final emAndamento = _contagem(e, 'jogadoresEmAndamento');
      if (comVagas > mesas) _recusar(RecusaDeRetrato.presencaIncoerente);
      if (aguardando + emAndamento != jogadores) {
        _recusar(RecusaDeRetrato.presencaIncoerente);
      }
      porModalidade[modalidade] = PresencaDeModalidade(
        mesas: mesas,
        mesasComVagas: comVagas,
        jogadores: jogadores,
        jogadoresAguardando: aguardando,
        jogadoresEmAndamento: emAndamento,
      );
    }

    return PresencaAgregada(
      jogadoresOnlineTotal: _contagem(m, 'jogadoresOnlineTotal'),
      espectadoresOnline: _contagem(m, 'espectadoresOnline'),
      jogadoresEmMesasPublicas: _contagem(m, 'jogadoresEmMesasPublicas'),
      jogadoresEmMesasPublicasAguardando: _contagem(
        m,
        'jogadoresEmMesasPublicasAguardando',
      ),
      jogadoresEmMesasPublicasEmAndamento: _contagem(
        m,
        'jogadoresEmMesasPublicasEmAndamento',
      ),
      mesasPublicas: _contagem(m, 'mesasPublicas'),
      mesasPublicasComVagas: _contagem(m, 'mesasPublicasComVagas'),
      porModalidade: Map.unmodifiable(porModalidade),
    );
  }
}
