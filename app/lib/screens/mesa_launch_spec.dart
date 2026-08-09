import 'configurar_mesa_screen.dart';
import 'mesa_config_contract.dart';

/// Contrato puramente de UI para a fronteira Preparando -> Mesa.
///
/// Não cria sala, não valida autoridade e não instancia o motor. Ele existe para
/// impedir que o host transforme silenciosamente uma Mesa Privada em VIP ou
/// descarte escolhas feitas no configurador antes da integração final.
enum MesaVisualVariant { publica, vip, privada }

class MesaLaunchSpec {
  final MesaVisualVariant visualVariant;
  final String modalidade;
  final int quantidadeJogadores;
  final int metaPontos;
  final int tempoSegundos;
  final ChatMesa chat;
  final int? apostaMoedas;
  final int? poteMoedas;
  final bool? espectadores;
  final String? codigoSala;
  final int custoCriar;

  const MesaLaunchSpec({
    required this.visualVariant,
    required this.modalidade,
    required this.quantidadeJogadores,
    required this.metaPontos,
    required this.tempoSegundos,
    required this.chat,
    required this.apostaMoedas,
    required this.poteMoedas,
    required this.espectadores,
    required this.codigoSala,
    required this.custoCriar,
  });

  factory MesaLaunchSpec.fromConfig(MesaConfigContract config) {
    return MesaLaunchSpec(
      visualVariant: switch (config.tipo) {
        TipoMesa.publica => MesaVisualVariant.publica,
        TipoMesa.vip => MesaVisualVariant.vip,
        TipoMesa.privada => MesaVisualVariant.privada,
      },
      modalidade: config.modalidadeCodigo,
      quantidadeJogadores: config.quantidadeJogadores,
      metaPontos: config.pontos,
      tempoSegundos: config.tempoSegundos,
      chat: config.chat,
      apostaMoedas: config.apostaMoedas,
      poteMoedas: config.poteMoedas,
      espectadores: config.espectadores,
      codigoSala: config.codigoSala,
      custoCriar: config.custoCriar,
    );
  }

  bool get ehPublica => visualVariant == MesaVisualVariant.publica;
  bool get ehVip => visualVariant == MesaVisualVariant.vip;
  bool get ehPrivada => visualVariant == MesaVisualVariant.privada;

  /// O app atual só expõe MesaVariant.publica/vip no motor visual legado.
  /// A integração NÃO deve usar `else => vip` para a Privada. Esta propriedade
  /// obriga o chamador a reconhecer que Privada ainda precisa de decisão
  /// explícita de apresentação antes de instanciar a MesaScreen canônica.
  bool get exigeResolucaoDeVariantPrivada => ehPrivada;
}
