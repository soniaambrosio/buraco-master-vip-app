import 'configurar_mesa_screen.dart';

/// Snapshot imutável da configuração aprovada antes de atravessar a fronteira
/// UI -> preparação/servidor/motor.
///
/// A função deste contrato é impedir que uma escolha feita na tela desapareça
/// durante a ligação final. Ele não cria sala, não mexe em saldo e não conhece
/// Firebase/servidor.
class MesaConfigContract {
  final TipoMesa tipo;
  final ModalidadeJogo modalidade;
  final ModoJogo modo;
  final int pontos;
  final int tempoSegundos;
  final ChatMesa chat;
  final int? apostaMoedas;
  final int? poteMoedas;
  final bool? espectadores;
  final String? codigoSala;
  final List<CadeiraVM>? cadeiras;
  final int custoCriar;

  const MesaConfigContract({
    required this.tipo,
    required this.modalidade,
    required this.modo,
    required this.pontos,
    required this.tempoSegundos,
    required this.chat,
    required this.apostaMoedas,
    required this.poteMoedas,
    required this.espectadores,
    required this.codigoSala,
    required this.cadeiras,
    required this.custoCriar,
  });

  factory MesaConfigContract.fromVm(ConfigMesaVM vm) {
    return MesaConfigContract(
      tipo: vm.tipo,
      modalidade: vm.modalidade,
      modo: vm.modo,
      pontos: vm.pontos,
      tempoSegundos: vm.tempo,
      chat: vm.chat,
      apostaMoedas: vm.aposta?.valor,
      poteMoedas: vm.aposta?.pote,
      espectadores: vm.espectadores,
      codigoSala: vm.codigo,
      cadeiras: vm.cadeiras == null ? null : List<CadeiraVM>.unmodifiable(vm.cadeiras!),
      custoCriar: vm.custoCriar,
    );
  }

  int get quantidadeJogadores => modo == ModoJogo.dois ? 2 : 4;

  String get modalidadeCodigo {
    switch (modalidade) {
      case ModalidadeJogo.aberto:
        return 'ABERTO';
      case ModalidadeJogo.fechado:
        return 'FECHADO';
      case ModalidadeJogo.sbtl:
        return 'STBL';
    }
  }

  String get tipoCodigo {
    switch (tipo) {
      case TipoMesa.publica:
        return 'publica';
      case TipoMesa.vip:
        return 'vip';
      case TipoMesa.privada:
        return 'privada';
    }
  }
}
