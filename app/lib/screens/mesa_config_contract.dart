import 'configurar_mesa_screen.dart';
import 'mesa_privada_social.dart';

/// Snapshot imutável da configuração aprovada antes de atravessar a fronteira
/// UI -> preparação/servidor/motor.
///
/// A função deste contrato é impedir que uma escolha feita na tela desapareça
/// durante a ligação final. Ele não cria sala, não mexe em saldo e não conhece
/// Firebase/servidor.
class MesaConfigContract {
  final TipoMesa tipo;
  final bool jogadorEhVip;
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
    required this.jogadorEhVip,
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
      jogadorEhVip: vm.ehVip,
      modalidade: vm.modalidade,
      modo: vm.modo,
      pontos: vm.pontos,
      tempoSegundos: vm.tempo,
      chat: vm.chat,
      apostaMoedas: vm.aposta?.valor,
      poteMoedas: vm.aposta?.pote,
      espectadores: vm.espectadores,
      codigoSala: vm.codigo,
      cadeiras: vm.cadeiras == null
          ? null
          : List<CadeiraVM>.unmodifiable(vm.cadeiras!),
      custoCriar: vm.custoCriar,
    );
  }

  int get quantidadeJogadores => modo == ModoJogo.dois ? 2 : 4;

  bool get temAposta => apostaMoedas != null && apostaMoedas! > 0;

  /// Regra comercial aprovada: em Mesa Privada, ocupar uma cadeira exige VIP.
  /// O Passe Convidado VIP é uma exceção promocional curta e validada pelo
  /// backend; o código da sala, sozinho, nunca concede o benefício.
  bool get exigeVipDosParticipantes =>
      tipo == TipoMesa.privada && MesaPrivadaPolicy.exigeVipParaJogar;

  bool get permitePasseConvidadoVip =>
      tipo == TipoMesa.privada && MesaPrivadaPolicy.permitePasseConvidadoVip;

  bool get espectadorPodeSerNaoVip =>
      tipo == TipoMesa.privada && !MesaPrivadaPolicy.espectadorPrecisaVip;

  bool get poteCoerente {
    if (apostaMoedas == null || poteMoedas == null) {
      return apostaMoedas == null && poteMoedas == null;
    }
    return poteMoedas == apostaMoedas! * quantidadeJogadores;
  }

  /// Na configuração de 2 jogadores, somente as duas primeiras posições fazem
  /// parte da mesa. O contrato não altera a lista original recebida do servidor.
  List<CadeiraVM>? get cadeirasAtivas {
    if (cadeiras == null) return null;
    final limite = quantidadeJogadores < cadeiras!.length
        ? quantidadeJogadores
        : cadeiras!.length;
    return List<CadeiraVM>.unmodifiable(cadeiras!.take(limite));
  }

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
