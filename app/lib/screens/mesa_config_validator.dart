import 'configurar_mesa_screen.dart';
import 'mesa_config_contract.dart';

class MesaConfigValidation {
  final List<String> erros;

  const MesaConfigValidation(this.erros);

  bool get ok => erros.isEmpty;
}

/// Valida apenas coerência do contrato visual. Não substitui validação
/// autoritativa de saldo, assinatura, aposta ou regras no servidor.
MesaConfigValidation validarMesaConfig(MesaConfigContract config) {
  final erros = <String>[];

  if (!config.poteCoerente) {
    erros.add('POTE_INCOERENTE');
  }

  if (config.pontos != 1500 && config.pontos != 3000) {
    erros.add('META_INVALIDA');
  }

  if (!const [15, 30, 45].contains(config.tempoSegundos)) {
    erros.add('TEMPO_INVALIDO');
  }

  if (config.quantidadeJogadores != 2 && config.quantidadeJogadores != 4) {
    erros.add('QUANTIDADE_JOGADORES_INVALIDA');
  }

  switch (config.tipo) {
    case TipoMesa.publica:
      if (config.apostaMoedas != null || config.poteMoedas != null) {
        erros.add('PUBLICA_NAO_PODE_TER_APOSTA');
      }
      if (config.espectadores != null) {
        erros.add('PUBLICA_NAO_CONFIGURA_ESPECTADORES');
      }
      if (config.codigoSala != null || config.cadeiras != null) {
        erros.add('PUBLICA_NAO_PODE_TER_SALA_PRIVADA');
      }
      break;

    case TipoMesa.vip:
      if (!config.jogadorEhVip) {
        erros.add('VIP_EXIGE_ASSINANTE');
      }
      if (config.apostaMoedas == null || config.poteMoedas == null) {
        erros.add('VIP_EXIGE_OPCAO_DE_APOSTA');
      }
      if (config.codigoSala != null || config.cadeiras != null) {
        erros.add('VIP_NAO_PODE_HERDAR_PRIVADA');
      }
      break;

    case TipoMesa.privada:
      if (!config.jogadorEhVip) {
        erros.add('CRIAR_PRIVADA_EXIGE_VIP');
      }
      if (config.apostaMoedas == null || config.poteMoedas == null) {
        erros.add('PRIVADA_EXIGE_OPCAO_DE_APOSTA');
      }
      if (config.espectadores == null) {
        erros.add('PRIVADA_EXIGE_OPCAO_ESPECTADORES');
      }
      if (config.codigoSala == null || config.codigoSala!.trim().isEmpty) {
        erros.add('PRIVADA_EXIGE_CODIGO');
      }
      if (config.cadeiras == null ||
          config.cadeiras!.length < config.quantidadeJogadores) {
        erros.add('PRIVADA_CADEIRAS_INSUFICIENTES');
      }
      break;
  }

  return MesaConfigValidation(List<String>.unmodifiable(erros));
}
