// estado_social.dart — o ESTADO CANÔNICO da descoberta social no cliente.
//
// Domínio puro: não importa Flutter, não importa Firebase, não lê relógio e não
// faz I/O. É a mesma disciplina de `sessao/identidade_publica_sessao.dart`, e
// pelo mesmo motivo — os casos que importam (relação desconhecida, ação que o
// servidor não ofereceu, resposta vencida) precisam ser encenáveis sem emulador.
//
// ---------------------------------------------------------------------------
// POR QUE ESTA PASTA NÃO É `lib/social/`
// ---------------------------------------------------------------------------
//
// `app/lib/social/` NÃO É CLIENTE. É o domínio das Cloud Functions sociais
// escrito em Dart e compilado para JS (`dart compile js -o
// functions-social/lib/domain_bundle.js app/lib/social/js_bridge.dart`). Uma
// tela que o importasse levaria para dentro do aplicativo a autoridade que mora
// no servidor — inclusive o cunhador de `publicId` —, e
// `test/sessao/auditoria_identidade_test.dart` reprova exatamente isso.
//
// Então este arquivo NÃO reusa `RelacaoVista` nem `AcaoSocial` daquele domínio:
// ele declara os seus próprios, hidratados pelo `.name` que vem no fio. A
// duplicação é deliberada e é a fronteira. O que a torna segura é que o cliente
// nunca DECIDE relação nem ação: ele só traduz o que a autoridade mandou.
//
// ---------------------------------------------------------------------------
// A REGRA QUE ORGANIZA O ARQUIVO INTEIRO: A INTERFACE NÃO INVENTA PERMISSÃO
// ---------------------------------------------------------------------------
//
// Existe [RelacaoSocial] e existe [AcaoSocial], e é tentador derivar a segunda
// da primeira — "se somos amigos, então dá para remover". O servidor já faz
// essa dedução (`acoesDisponiveis` em `lib/social/amizade.dart`), e refazê-la
// aqui criaria uma segunda política que diverge da primeira no dia em que uma
// sanção nova entrar: o servidor pararia de oferecer "adicionar amigo" a quem
// está com restrição social, e a tela continuaria desenhando o botão.
//
// Por isso [ResultadoSocial.acoes] vem do fio, e é ELA que decide quais botões
// aparecem. A relação serve para escrever o RÓTULO ("Amigos", "Pedido
// enviado"), que é outra coisa: rótulo descreve, botão autoriza.
//
// ---------------------------------------------------------------------------
// `publicId` CONTINUA OPACO
// ---------------------------------------------------------------------------
//
// Nada aqui conhece alfabeto, comprimento ou prefixo do identificador público.
// A única exigência é a de qualquer identificador opaco — ser texto não vazio
// depois de `trim` —, e quem recusa malformado é o servidor
// (`invalid-argument`). Ver o cabeçalho de `navegacao_perfil_publico.dart`.

/// Como o observador se relaciona com o jogador exibido, segundo o SERVIDOR.
///
/// Espelha `RelacaoVista` do domínio social pelo `.name`, e não pelo índice: o
/// contrato do fio é o nome, e um enum reordenado de um lado só não pode
/// silenciosamente virar outra relação.
enum RelacaoSocial {
  nenhuma,
  solicitacaoEnviada,
  solicitacaoRecebida,
  amigos,

  /// O próprio jogador bloqueou o alvo — ele sabe, foi ele quem fez.
  bloqueadoPorMim,

  /// Interação impossível, sem dizer por quê.
  ///
  /// UM ESTADO PARA DOIS FATOS DIFERENTES (o outro me bloqueou; há sanção
  /// social), e a indistinção é a política: a tela não pode escrever "Fulano
  /// bloqueou você".
  indisponivel,

  /// É o próprio perfil.
  euMesmo,

  /// O servidor mandou um nome que este cliente não conhece.
  ///
  /// EXISTE SÓ AQUI, e não no domínio do servidor, porque só o cliente pode
  /// ficar velho em relação ao seu backend. Cai em "não sei dizer", que a tela
  /// desenha sem rótulo — e NUNCA em [nenhuma], que faria uma relação
  /// desconhecida ser apresentada como "vocês não têm relação" e convidaria a
  /// um pedido de amizade que o servidor já sabe que vai recusar.
  desconhecida;

  static RelacaoSocial doWire(Object? nome) {
    for (final r in RelacaoSocial.values) {
      if (r == RelacaoSocial.desconhecida) continue;
      if (r.name == nome) return r;
    }
    return RelacaoSocial.desconhecida;
  }
}

/// Uma ação que o SERVIDOR declarou disponível para aquele jogador.
///
/// A tela desenha um botão por item desta lista, e nenhum a mais. `desbloquear`
/// e `editarPerfil` entram no vocabulário porque a autoridade pode devolvê-los;
/// não terem porta nesta fatia é assunto de quem desenha, não de quem traduz —
/// e uma ação que o cliente não sabe desenhar tem de ser vista como conhecida e
/// ignorada, nunca como corrompendo a lista inteira.
enum AcaoSocial {
  adicionarAmigo,
  cancelarSolicitacao,
  aceitarSolicitacao,
  recusarSolicitacao,
  removerAmigo,
  bloquear,
  desbloquear,
  editarPerfil;

  /// `null` para nome desconhecido — e quem hidrata a lista DESCARTA o nulo.
  ///
  /// Descartar é o comportamento certo: uma ação futura que este cliente não
  /// implementa não pode virar um botão sem rótulo, e também não pode derrubar
  /// as outras seis que ele entende.
  static AcaoSocial? doWire(Object? nome) {
    for (final a in AcaoSocial.values) {
      if (a.name == nome) return a;
    }
    return null;
  }

  static List<AcaoSocial> listaDoWire(Object? bruto) {
    if (bruto is! List) return const [];
    final fora = <AcaoSocial>[];
    for (final item in bruto) {
      final a = AcaoSocial.doWire(item);
      // `contains` e não `Set`: a lista é minúscula (nunca passou de três) e a
      // ORDEM do servidor é a ordem em que os botões aparecem.
      if (a != null && !fora.contains(a)) fora.add(a);
    }
    return List.unmodifiable(fora);
  }
}

/// A apresentação pública de um jogador, como as listas sociais a devolvem.
///
/// NÃO TEM UID, e não tem por onde ter: o backend nunca o publica (a trava
/// `exigirRespostaSegura` transforma o vazamento em erro), e esta classe só
/// conhece os quatro campos que o fio traz.
class JogadorPublico {
  const JogadorPublico({
    required this.publicId,
    required this.apelido,
    required this.avatarRef,
    required this.desde,
  });

  /// Identificador público. OPACO — transportado e exibido, nunca calculado.
  final String publicId;

  /// Pode ser VAZIO: o backend devolve vazio para quem ainda não escolheu
  /// apelido, e usar o uid como substituto é proibido. Quem exibe decide o
  /// fallback VISUAL — ver [nomeDeApresentacao].
  final String apelido;

  final String? avatarRef;

  /// `amigosDesde` na lista de amigos; `solicitadaEm` nas de solicitação.
  /// Ausente nos resultados de busca, de propósito: "amigos desde" não é
  /// informação de descoberta.
  final String? desde;

  /// Há identificador com que falar deste jogador?
  ///
  /// A checagem para em "trim não vazio" DE PROPÓSITO. Conferir a FORMA aqui
  /// seria uma cópia local da fórmula do servidor — a mesma que a auditoria de
  /// identidade proíbe. Um id malformado é recusado por quem tem autoridade.
  bool get temIdUtilizavel => publicId.trim().isNotEmpty;

  /// Como chamar esta pessoa na tela.
  ///
  /// FALLBACK DE APRESENTAÇÃO, e não de identidade: apelido, senão o próprio
  /// identificador público (que É como ela é conhecida publicamente), senão um
  /// rótulo genérico. O uid não entra em nenhum dos três — ele nem chega aqui.
  String get nomeDeApresentacao {
    final a = apelido.trim();
    if (a.isNotEmpty) return a;
    final id = publicId.trim();
    if (id.isNotEmpty) return id;
    return 'Jogador(a)';
  }

  static JogadorPublico doWire(Map<Object?, Object?> bruto) => JogadorPublico(
    publicId: _texto(bruto['publicId']),
    apelido: _texto(bruto['apelido']),
    avatarRef: bruto['avatarRef'] is String
        ? bruto['avatarRef'] as String
        : null,
    desde: bruto['desde'] is String ? bruto['desde'] as String : null,
  );
}

/// Um jogador MAIS o estado social dele em relação a quem está olhando.
///
/// É o que a busca devolve e o que `verPerfilPublico` devolve. As duas fontes
/// produzem o MESMO tipo porque produzem a mesma coisa — apresentação pública
/// somada à vista da relação —, e ter um tipo só é o que permite a uma tela
/// mostrar um resultado de busca e, depois da ação, substituí-lo pela resposta
/// da autoridade sem traduzir de novo.
class ResultadoSocial {
  const ResultadoSocial({
    required this.jogador,
    required this.relacao,
    required this.acoes,
  });

  final JogadorPublico jogador;
  final RelacaoSocial relacao;

  /// As ações que o SERVIDOR ofereceu. A tela desenha estas, e só estas.
  final List<AcaoSocial> acoes;

  String get publicId => jogador.publicId;

  bool permite(AcaoSocial a) => acoes.contains(a);

  ResultadoSocial comRelacao(RelacaoSocial nova, List<AcaoSocial> novasAcoes) =>
      ResultadoSocial(jogador: jogador, relacao: nova, acoes: novasAcoes);

  static ResultadoSocial doWire(Map<Object?, Object?> bruto) => ResultadoSocial(
    jogador: JogadorPublico.doWire(bruto),
    relacao: RelacaoSocial.doWire(bruto['relacao']),
    acoes: AcaoSocial.listaDoWire(bruto['acoes']),
  );

  /// Hidrata a resposta de `verPerfilPublico`, cujo formato aninha o perfil.
  static ResultadoSocial doPerfilPublico(Map<Object?, Object?> bruto) {
    final perfil = bruto['perfil'] is Map
        ? (bruto['perfil'] as Map).cast<Object?, Object?>()
        : const <Object?, Object?>{};
    return ResultadoSocial(
      jogador: JogadorPublico.doWire(perfil),
      relacao: RelacaoSocial.doWire(bruto['relacao']),
      acoes: AcaoSocial.listaDoWire(bruto['acoes']),
    );
  }
}

/// Em que modo o servidor atendeu a consulta.
enum ModoDeBusca {
  exato,
  prefixo;

  static ModoDeBusca doWire(Object? nome) =>
      nome == 'exato' ? ModoDeBusca.exato : ModoDeBusca.prefixo;
}

/// A resposta de `buscarJogadoresPorApelido`.
class ResultadosDeBusca {
  const ResultadosDeBusca({
    required this.termo,
    required this.itens,
    required this.truncado,
    required this.modo,
  });

  /// O termo que PRODUZIU estes resultados.
  ///
  /// Guardado junto porque a caixa de texto muda enquanto a resposta viaja: sem
  /// ele, a tela não consegue distinguir "estes são os resultados do que está
  /// escrito" de "estes são os resultados de duas letras atrás".
  final String termo;

  final List<ResultadoSocial> itens;

  /// Havia mais VISÍVEIS do que o teto. Não há cursor, e a ausência é
  /// deliberada: a busca não percorre a base. O convite é refinar o termo.
  final bool truncado;

  final ModoDeBusca modo;

  bool get vazio => itens.isEmpty;

  static ResultadosDeBusca doWire(String termo, Map<Object?, Object?> bruto) =>
      ResultadosDeBusca(
        termo: termo,
        itens: _itens(bruto['itens'], ResultadoSocial.doWire),
        truncado: bruto['truncado'] == true,
        modo: ModoDeBusca.doWire(bruto['modo']),
      );
}

/// Uma página de lista social (amigos ou solicitações).
class PaginaSocial {
  const PaginaSocial({required this.itens, required this.proximoCursor});

  static const PaginaSocial vazia = PaginaSocial(
    itens: [],
    proximoCursor: null,
  );

  final List<JogadorPublico> itens;

  /// Cursor OPACO. O cliente devolve o que recebeu, sem interpretar — se a
  /// ordenação do servidor mudar, nenhum cliente quebra.
  final String? proximoCursor;

  bool get temMais => proximoCursor != null;

  /// Concatena a página seguinte, preservando a ordem do servidor.
  ///
  /// DEDUPLICA POR `publicId`. O cursor do backend é estritamente maior, então
  /// repetição não deveria acontecer — mas uma amizade desfeita entre duas
  /// páginas desloca a lista, e um item repetido na tela vira dois botões que
  /// operam sobre a mesma relação, com o segundo sempre respondendo `repeticao`.
  PaginaSocial seguida(PaginaSocial proxima) {
    final vistos = itens.map((e) => e.publicId).toSet();
    return PaginaSocial(
      itens: [...itens, ...proxima.itens.where((e) => vistos.add(e.publicId))],
      proximoCursor: proxima.proximoCursor,
    );
  }

  /// Remove um jogador da lista sem ir ao servidor.
  ///
  /// É a única mutação local permitida, e ela só SUBTRAI. Ver o cabeçalho de
  /// `leitor_social.dart`, seção "o cliente não guarda grafo".
  PaginaSocial sem(String publicId) => PaginaSocial(
    itens: itens.where((e) => e.publicId != publicId).toList(growable: false),
    proximoCursor: proximoCursor,
  );

  static PaginaSocial doWire(Map<Object?, Object?> bruto) => PaginaSocial(
    itens: _itens(bruto['itens'], JogadorPublico.doWire),
    proximoCursor: bruto['proximoCursor'] is String
        ? bruto['proximoCursor'] as String
        : null,
  );
}

/// Convite de mesa entregue somente ao destinatário autenticado.
class ConviteMesa {
  const ConviteMesa({
    required this.conviteId,
    required this.codigo,
    required this.tipoMesa,
    required this.expiraEm,
    required this.remetente,
  });

  final String conviteId;
  final String codigo;
  final String tipoMesa;
  final DateTime? expiraEm;
  final JogadorPublico remetente;

  static ConviteMesa doWire(Map<Object?, Object?> bruto) {
    final remetente = bruto['remetente'] is Map
        ? (bruto['remetente'] as Map).cast<Object?, Object?>()
        : const <Object?, Object?>{};
    return ConviteMesa(
      conviteId: _texto(bruto['conviteId']),
      codigo: _texto(bruto['codigo']),
      tipoMesa: _texto(bruto['tipoMesa']),
      expiraEm: DateTime.tryParse(_texto(bruto['expiraEm']))?.toUtc(),
      remetente: JogadorPublico.doWire(remetente),
    );
  }
}

class RespostaConviteMesa {
  const RespostaConviteMesa({
    required this.aceito,
    required this.repeticao,
    required this.expirado,
    required this.codigo,
    required this.tipoMesa,
  });

  final bool aceito;
  final bool repeticao;
  final bool expirado;
  final String? codigo;
  final String? tipoMesa;

  static RespostaConviteMesa doWire(Map<Object?, Object?> bruto) =>
      RespostaConviteMesa(
        aceito: bruto['aceito'] == true,
        repeticao: bruto['repeticao'] == true,
        expirado: bruto['expirado'] == true,
        codigo: bruto['codigo'] is String ? bruto['codigo'] as String : null,
        tipoMesa: bruto['tipoMesa'] is String
            ? bruto['tipoMesa'] as String
            : null,
      );
}

/// O desfecho de uma operação sobre a relação (§ `respostaDaOperacao`).
class DesfechoSocial {
  const DesfechoSocial({required this.repeticao, required this.estado});

  /// O desfecho pedido JÁ VALIA. Vem como sucesso, e não como erro: devolver
  /// erro faria a tela tentar de novo, e a próxima tentativa "falharia" igual.
  final bool repeticao;

  /// O estado final da relação no banco (`nenhuma`, `pendente`, `amigos`).
  ///
  /// INFORMATIVO. Não é daqui que saem os botões: o estado do BANCO não conhece
  /// bloqueio nem sanção, e a vista que a tela precisa é a de
  /// `verPerfilPublico`. Ver `leitor_social.dart`.
  final String estado;

  static DesfechoSocial doWire(Map<Object?, Object?> bruto) => DesfechoSocial(
    repeticao: bruto['repeticao'] == true,
    estado: _texto(bruto['estado']),
  );
}

/// Por que uma operação social falhou.
enum MotivoFalhaSocial {
  /// Sem sessão válida. Repetir com a mesma credencial não resolve.
  naoAutenticado,

  /// Rede, timeout, cold start. Repetir resolve.
  indisponivel,

  /// Permissão negada.
  recusado,

  /// O jogador procurado não existe, ou não pode ser exposto. Conta removida e
  /// conta inexistente respondem IGUAL, de propósito.
  naoEncontrado,

  /// O pedido não tinha forma de pedido — termo curto demais, longo demais, ou
  /// inutilizável. Repetir o MESMO texto não resolve; mudar o texto resolve.
  pedidoInvalido,

  /// O servidor recusou por regra de negócio (lotação, autoamizade, bloqueio).
  regraDeNegocio,

  /// Veio resposta, e ela não tem a forma do contrato.
  respostaInvalida,

  desconhecida;

  bool get transitoria =>
      this == MotivoFalhaSocial.indisponivel ||
      this == MotivoFalhaSocial.desconhecida;
}

/// Falha de uma operação social.
class FalhaSocial implements Exception {
  const FalhaSocial(this.motivo, [this.recusa = '']);

  final MotivoFalhaSocial motivo;

  /// O código de recusa do domínio (`consultaMuitoCurta`, `limiteDeAmigos`…),
  /// quando o servidor o mandou. Vazio quando não veio.
  ///
  /// Guardado CRU, e traduzido para texto só na borda: uma recusa nova do
  /// servidor precisa poder chegar até o log sem que este arquivo a conheça.
  final String recusa;

  bool get transitoria => motivo.transitoria;

  @override
  String toString() =>
      'FalhaSocial(${motivo.name}${recusa.isEmpty ? '' : ': $recusa'})';
}

String _texto(Object? v) => v is String ? v : '';

/// Hidrata uma lista do fio, DESCARTANDO o que não for objeto.
///
/// Descarta em vez de falhar porque um item corrompido no meio da página não
/// justifica esconder os outros nove — e porque a alternativa (um item de
/// placeholder) seria o aplicativo afirmando a existência de um jogador que
/// ninguém devolveu.
List<T> _itens<T>(Object? bruto, T Function(Map<Object?, Object?>) hidratar) {
  if (bruto is! List) return const [];
  final fora = <T>[];
  for (final item in bruto) {
    if (item is Map) fora.add(hidratar(item.cast<Object?, Object?>()));
  }
  return List.unmodifiable(fora);
}
