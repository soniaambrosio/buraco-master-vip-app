import 'configurar_mesa_screen.dart';
import 'mesa_config_contract.dart';
import 'preparando_partida_screen.dart';

/// Converte a configuração escolhida pelo jogador em um VM de preparação sem
/// consultar servidor/Firebase. A integração real apenas substitui os jogadores
/// mockados pelos ocupantes autoritativos da sala.
PreparandoPartidaVM prepararPartidaDaConfiguracao(
  MesaConfigContract config, {
  List<JogadorPreparacaoVM>? jogadores,
}) {
  final participantes = jogadores ?? _jogadoresMock(config.quantidadeJogadores);
  final limite = config.quantidadeJogadores < participantes.length
      ? config.quantidadeJogadores
      : participantes.length;
  final ativos = List<JogadorPreparacaoVM>.unmodifiable(
    participantes.take(limite),
  );

  return PreparandoPartidaVM(
    titulo: _titulo(config.tipo),
    subtitulo: _subtitulo(config),
    ehVip: config.jogadorEhVip,
    jogadores: ativos,
  );
}

String _titulo(TipoMesa tipo) {
  switch (tipo) {
    case TipoMesa.publica:
      return 'SUA MESA PÚBLICA VAI COMEÇAR';
    case TipoMesa.vip:
      return 'SUA MESA VIP VAI COMEÇAR';
    case TipoMesa.privada:
      return 'SUA MESA PRIVADA VAI COMEÇAR';
  }
}

String _subtitulo(MesaConfigContract config) {
  final partes = <String>[
    _modalidade(config.modalidade),
    '${config.quantidadeJogadores} jogadores',
    '${_numero(config.pontos)} pontos',
    '${config.tempoSegundos}s',
  ];

  if (config.apostaMoedas != null) {
    partes.add(
      config.apostaMoedas == 0
          ? 'sem aposta'
          : 'aposta ${_numero(config.apostaMoedas!)}',
    );
  }

  if (config.tipo == TipoMesa.privada && config.espectadores != null) {
    partes.add(
      config.espectadores! ? 'com espectadores' : 'sem espectadores',
    );
  }

  return partes.join(' • ');
}

String _modalidade(ModalidadeJogo modalidade) {
  switch (modalidade) {
    case ModalidadeJogo.aberto:
      return 'Aberto';
    case ModalidadeJogo.fechado:
      return 'Fechado';
    case ModalidadeJogo.sbtl:
      return 'STBL';
  }
}

String _numero(int valor) {
  final texto = valor.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < texto.length; i++) {
    final restante = texto.length - i;
    buffer.write(texto[i]);
    if (restante > 1 && restante % 3 == 1) buffer.write('.');
  }
  return buffer.toString();
}

List<JogadorPreparacaoVM> _jogadoresMock(int quantidade) {
  if (quantidade == 2) {
    return const [
      JogadorPreparacaoVM(
        id: 'voce',
        nome: 'Você',
        avatar: '👑',
        ehVip: true,
        pronto: true,
        posicao: PosicaoJogador.baixo,
      ),
      JogadorPreparacaoVM(
        id: 'adversario',
        nome: 'Adversário',
        avatar: '🧔🏻',
        ehVip: false,
        pronto: true,
        posicao: PosicaoJogador.topo,
      ),
    ];
  }

  return const [
    JogadorPreparacaoVM(
      id: 'parceiro',
      nome: 'Parceiro',
      avatar: '👩🏼',
      ehVip: true,
      pronto: true,
      posicao: PosicaoJogador.topo,
    ),
    JogadorPreparacaoVM(
      id: 'adversario-direita',
      nome: 'Adversário',
      avatar: '🧔🏽',
      ehVip: false,
      pronto: true,
      posicao: PosicaoJogador.direita,
    ),
    JogadorPreparacaoVM(
      id: 'voce',
      nome: 'Você',
      avatar: '👑',
      ehVip: true,
      pronto: true,
      posicao: PosicaoJogador.baixo,
    ),
    JogadorPreparacaoVM(
      id: 'adversario-esquerda',
      nome: 'Adversário',
      avatar: '👩🏽',
      ehVip: false,
      pronto: true,
      posicao: PosicaoJogador.esquerda,
    ),
  ];
}
