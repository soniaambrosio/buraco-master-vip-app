// identidade_publica_sessao.dart — o ESTADO CANÔNICO da identidade pública.
//
// Este arquivo é DOMÍNIO PURO: não importa Flutter, não importa Firebase, não
// lê relógio e não faz I/O. É o que torna os quinze casos da OS testáveis sem
// emulador e sem `WidgetTester`.
//
// ---------------------------------------------------------------------------
// A INVERSÃO QUE ESTA OS PEDE
// ---------------------------------------------------------------------------
//
// O fluxo proibido era:
//
//     abrir Ranking -> obter/criar identidade -> as outras telas funcionam
//
// que faz a identidade do jogador depender de qual botão ele apertou primeiro.
// O fluxo desta camada é:
//
//     sessão autenticada -> identidade -> Ranking, Perfil, Social, Descoberta
//
// A identidade pertence ao JOGADOR AUTENTICADO. Nenhuma tela a cria, garante ou
// inicializa; todas apenas leem o estado que mora aqui.
//
// ---------------------------------------------------------------------------
// `publicId` É OPACO — E ISSO É UMA DECISÃO, NÃO UM DESCUIDO
// ---------------------------------------------------------------------------
//
// A autoridade única de `publicId` é o backend (`social:obterMinhaIdentidade`).
// Este arquivo NÃO conhece o alfabeto, o comprimento nem o prefixo do id: se
// conhecesse, teria uma cópia local da fórmula do servidor, que é exatamente o
// que a OS proíbe — e a cópia divergiria no primeiro dia em que o formato
// mudasse de um lado só.
//
// A única exigência sobre o valor é a que vale para qualquer identificador
// opaco: ser uma string não vazia. Um `publicId` ausente, vazio ou de outro tipo
// é RESPOSTA INVÁLIDA (e vira falha explícita), nunca um motivo para o cliente
// inventar um substituto.
//
// Em especial, e por isso não existe nenhum `?? uid` neste arquivo: o `uid` do
// Firebase é identidade INTERNA e não substitui a pública em nenhuma hipótese.

/// Em que ponto do ciclo de vida a identidade pública da sessão está.
///
/// A OS §6 pede que o estado saiba dizer, no mínimo: sessão não autenticada,
/// identidade não carregada, carregando, disponível e falha transitória.
///
/// NÃO EXISTE UMA FASE "ausente" — e a omissão é deliberada. §6 só a pede "caso
/// esse estado faça parte do contrato real do backend", e não faz:
/// `obterMinhaIdentidade` é get-or-create (ver `garantirIdentidade` em
/// functions-social), então uma sessão autenticada que obtém resposta com
/// sucesso SEMPRE tem `publicId`. Inventar a fase aqui criaria um estado que
/// nenhum caminho real produz, e um estado inalcançável é código morto que
/// mente sobre o contrato.
///
/// O que existe de verdade é um perfil público NÃO EXPONÍVEL (conta desativada
/// ou sancionada). Isso não é ausência de identidade: o `publicId` continua
/// válido. Por isso mora em [IdentidadePublica.exponivel], e não numa fase.
enum FaseIdentidade {
  /// Ninguém autenticado. Não há identidade pública a exibir, e não haverá
  /// enquanto não houver login.
  naoAutenticado,

  /// Há sessão autenticada, mas a identidade ainda não foi pedida.
  naoCarregada,

  /// A consulta a `obterMinhaIdentidade` está em voo.
  carregando,

  /// Identidade canônica em mãos.
  disponivel,

  /// A consulta falhou. A sessão autenticada CONTINUA VÁLIDA — §10: falha de
  /// identidade não derruba o resto da sessão.
  falha,
}

/// Estado de exposição do perfil público, tal como o backend o reporta.
///
/// Espelha `EstadoPerfilPublico` do domínio social. Um valor desconhecido é
/// tratado como [indisponivel], e não como ativo: um estado que este código não
/// entende pode ser exatamente "banido", e expor por desconhecimento seria o
/// pior desfecho.
enum EstadoPerfil {
  ativo,
  indisponivel;

  static EstadoPerfil porNome(Object? nome) =>
      nome == 'ativo' ? EstadoPerfil.ativo : EstadoPerfil.indisponivel;
}

/// Por que a obtenção da identidade falhou.
///
/// A separação entre transitório e definitivo existe para a UI: só o primeiro
/// justifica oferecer "tentar de novo".
enum MotivoFalhaIdentidade {
  /// O backend recusou por falta de autenticação. Não adianta repetir com a
  /// mesma credencial.
  naoAutenticado,

  /// Rede, timeout, indisponibilidade, `aborted`. Repetir resolve.
  indisponivel,

  /// Permissão negada. Repetir não resolve.
  recusado,

  /// Veio resposta, mas sem `publicId` utilizável. NÃO é motivo para fabricar
  /// um id: é motivo para falhar visivelmente.
  respostaInvalida,

  /// Qualquer outra. Tratada como transitória por prudência — negar o retry a
  /// um erro desconhecido deixaria o jogador preso sem saída.
  desconhecida;

  bool get transitoria =>
      this == MotivoFalhaIdentidade.indisponivel ||
      this == MotivoFalhaIdentidade.desconhecida;
}

/// Falha ao obter a identidade pública.
class FalhaIdentidade implements Exception {
  const FalhaIdentidade(this.motivo, [this.detalhe = '']);

  final MotivoFalhaIdentidade motivo;
  final String detalhe;

  bool get transitoria => motivo.transitoria;

  @override
  String toString() =>
      'FalhaIdentidade(${motivo.name}${detalhe.isEmpty ? '' : ': $detalhe'})';
}

/// Limites sociais que o backend publica junto da identidade (§ contrato de
/// `obterMinhaIdentidade`).
///
/// Vêm do servidor, e não de constantes locais, porque o servidor é quem os
/// aplica — uma cópia no cliente vira mensagem de erro mentirosa no dia em que
/// um limite mudar.
class LimitesSociais {
  const LimitesSociais({
    required this.amigos,
    required this.solicitacoesEnviadas,
    required this.paginaMaxima,
  });

  final int amigos;
  final int solicitacoesEnviadas;
  final int paginaMaxima;

  static const LimitesSociais desconhecidos = LimitesSociais(
    amigos: 0,
    solicitacoesEnviadas: 0,
    paginaMaxima: 0,
  );

  static LimitesSociais doWire(Object? bruto) {
    final m = bruto is Map ? bruto : const {};
    int n(Object? v) => v is num ? v.toInt() : 0;
    return LimitesSociais(
      amigos: n(m['amigos']),
      solicitacoesEnviadas: n(m['solicitacoesEnviadas']),
      paginaMaxima: n(m['paginaMaxima']),
    );
  }
}

/// Metadados que só a resposta do PRÓPRIO perfil carrega (§31-E do contrato
/// social): o que a tela de edição precisa saber antes de deixar o jogador
/// digitar.
class MetadadosDeEdicao {
  const MetadadosDeEdicao({
    required this.apelidoMinimo,
    required this.apelidoMaximo,
    required this.catalogoDeAvatarDisponivel,
  });

  final int apelidoMinimo;
  final int apelidoMaximo;
  final bool catalogoDeAvatarDisponivel;

  static const MetadadosDeEdicao desconhecidos = MetadadosDeEdicao(
    apelidoMinimo: 0,
    apelidoMaximo: 0,
    catalogoDeAvatarDisponivel: false,
  );

  static MetadadosDeEdicao doWire(Object? bruto) {
    final m = bruto is Map ? bruto : const {};
    int n(Object? v) => v is num ? v.toInt() : 0;
    return MetadadosDeEdicao(
      apelidoMinimo: n(m['apelidoMinimo']),
      apelidoMaximo: n(m['apelidoMaximo']),
      catalogoDeAvatarDisponivel: m['catalogoDeAvatarDisponivel'] == true,
    );
  }
}

/// A identidade pública canônica de quem está autenticado.
///
/// Imutável de propósito: o estado da sessão é substituído, nunca remendado no
/// lugar. Um objeto mutável compartilhado por Ranking, Perfil e Social deixaria
/// qualquer um dos três alterar o que os outros dois leem.
class IdentidadePublica {
  const IdentidadePublica({
    required this.publicId,
    required this.apelido,
    required this.avatarRef,
    required this.criada,
    required this.estado,
    required this.limites,
    required this.edicao,
  });

  /// Identificador público. OPACO: o cliente o transporta e o exibe, nunca o
  /// calcula, deriva ou repara.
  final String publicId;

  /// Apelido de apresentação. Pode ser VAZIO — o backend devolve vazio quando o
  /// jogador ainda não escolheu um, e §31-F proíbe usar o uid como substituto.
  /// Quem exibe decide o texto de fallback VISUAL (ex.: mostrar o publicId),
  /// que é outra coisa: fallback de apresentação não é fallback de identidade.
  final String apelido;

  final String? avatarRef;

  /// A identidade acabou de nascer nesta chamada. Informativo (boas-vindas,
  /// telemetria); não muda nenhuma decisão desta camada.
  final bool criada;

  final EstadoPerfil estado;
  final LimitesSociais limites;
  final MetadadosDeEdicao edicao;

  /// O perfil pode ser exposto a terceiros?
  bool get exponivel => estado == EstadoPerfil.ativo;

  /// Hidrata a resposta de `obterMinhaIdentidade`.
  ///
  /// LANÇA [FalhaIdentidade] quando não há `publicId` utilizável, em vez de
  /// devolver um objeto meio-pronto. É a trava que garante que nenhum caminho
  /// desta camada produza identidade sem autoridade do servidor: se o campo não
  /// veio, o estado vira falha explícita — nunca um id fabricado, nunca o uid,
  /// nunca string vazia.
  factory IdentidadePublica.doWire(Map<Object?, Object?> bruto) {
    final id = bruto['publicId'];
    if (id is! String || id.isEmpty) {
      throw const FalhaIdentidade(
        MotivoFalhaIdentidade.respostaInvalida,
        'resposta sem publicId utilizável',
      );
    }

    final perfil = bruto['perfil'] is Map
        ? (bruto['perfil'] as Map)
        : const <Object?, Object?>{};

    return IdentidadePublica(
      publicId: id,
      apelido: perfil['apelido'] is String ? perfil['apelido'] as String : '',
      avatarRef: perfil['avatarRef'] is String
          ? perfil['avatarRef'] as String
          : null,
      criada: bruto['criada'] == true,
      estado: EstadoPerfil.porNome(bruto['estado']),
      limites: LimitesSociais.doWire(bruto['limites']),
      edicao: MetadadosDeEdicao.doWire(bruto['edicao']),
    );
  }
}

/// Fotografia imutável do estado canônico de identidade da sessão.
///
/// É ISTO que Ranking, Perfil, Social e Descoberta leem. Todos leem o MESMO
/// objeto: não existe `identidadeDoRanking`, `identidadeDoPerfil` nem
/// `identidadeDoSocial`.
class EstadoIdentidadeSessao {
  const EstadoIdentidadeSessao._({
    required this.fase,
    required this.uid,
    required this.identidade,
    required this.falha,
  });

  /// Ninguém autenticado. É também o estado de partida e o estado pós-logout.
  static const EstadoIdentidadeSessao deslogado = EstadoIdentidadeSessao._(
    fase: FaseIdentidade.naoAutenticado,
    uid: null,
    identidade: null,
    falha: null,
  );

  const EstadoIdentidadeSessao.naoCarregada(String this.uid)
    : fase = FaseIdentidade.naoCarregada,
      identidade = null,
      falha = null;

  const EstadoIdentidadeSessao.carregando(String this.uid)
    : fase = FaseIdentidade.carregando,
      identidade = null,
      falha = null;

  const EstadoIdentidadeSessao.disponivel(
    String this.uid,
    IdentidadePublica this.identidade,
  ) : fase = FaseIdentidade.disponivel,
      falha = null;

  const EstadoIdentidadeSessao.falhou(
    String this.uid,
    FalhaIdentidade this.falha,
  ) : fase = FaseIdentidade.falha,
      identidade = null;

  final FaseIdentidade fase;

  /// UID do Firebase da sessão a que este estado pertence.
  ///
  /// Guardado para que o próprio estado saiba de QUEM ele é. É o que permite a
  /// um teste (e a um assert) provar que o estado do jogador B não carrega
  /// resquício do jogador A.
  final String? uid;

  final IdentidadePublica? identidade;
  final FalhaIdentidade? falha;

  bool get autenticado => uid != null;

  /// O `publicId` canônico, ou `null` quando não há identidade resolvida.
  ///
  /// NULL É A RESPOSTA CERTA quando não há identidade. Não devolve uid, não
  /// devolve string vazia, não devolve id provisório: §5 exige que "se a
  /// identidade canônica não estiver disponível, o estado represente exatamente
  /// isso". Um fallback aqui seria invisível para quem chama e faria o jogador
  /// aparecer no Social com o identificador errado.
  String? get publicId =>
      fase == FaseIdentidade.disponivel ? identidade?.publicId : null;

  /// Vale a pena oferecer "tentar de novo"?
  bool get podeTentarDeNovo =>
      fase == FaseIdentidade.falha && (falha?.transitoria ?? false);
}
