// endpoint_servidor.dart — de onde sai o endereço do servidor online.
//
// ---------------------------------------------------------------------------
// POR QUE ISSO EXISTE
//
// O endereço do servidor era uma `const` no meio do código de conexão. Isso tem
// três problemas que só aparecem quando o app é publicado:
//
//   1. o binário publicado carrega o endereço gravado em pedra — apontar um
//      build para homologação exige editar código e recompilar;
//   2. nada impedia um build de release sair apontando para `localhost` ou para
//      o `10.0.2.2` do emulador, e o defeito só apareceria no celular de quem
//      instalou;
//   3. nada impedia `ws://` (sem TLS) num app publicado, que é a credencial
//      viajando em claro.
//
// Agora o endereço vem da configuração do build (`--dart-define`) e passa por
// uma validação que RECUSA, no perfil de release, tudo que não seja um endpoint
// seguro e alcançável de fora. Sem endereço válido o app não abre socket nenhum:
// falha cedo, com estado seguro e mensagem que a pessoa entende — em vez de
// ficar girando contra um host que não existe.
//
//   flutter build apk --release --dart-define=BMV_SERVIDOR_URL=wss://exemplo.tld
//
// O valor NÃO é segredo (é um endereço público), mas também não é para viver no
// código-fonte: ele muda por ambiente, e o código não.
// ---------------------------------------------------------------------------

import 'package:flutter/foundation.dart' show kReleaseMode;

/// Perfil do build sob o qual o endpoint está sendo resolvido.
///
/// Existe separado de `kReleaseMode` porque o teste precisa exercitar as duas
/// políticas sem recompilar o mundo em modo release.
enum PerfilDeBuild {
  /// Build publicável (loja). Política fechada: só endpoint seguro e externo.
  release,

  /// Build de desenvolvimento/teste. Aceita endereço local, mas **apenas** com
  /// autorização explícita no build — nunca por omissão.
  desenvolvimento,
}

/// Endpoint recusado. A mensagem é escrita para ser mostrada a uma pessoa e
/// **não** carrega segredo: o endereço não é credencial, e credencial nenhuma
/// chega até aqui.
class EndpointInvalido implements Exception {
  const EndpointInvalido(this.motivo);

  /// Motivo legível. É o que a UI mostra.
  final String motivo;

  @override
  String toString() => 'EndpointInvalido: $motivo';
}

/// Resolve e valida o endereço do servidor online.
class EndpointServidor {
  const EndpointServidor._();

  /// Endereço vindo da configuração do build. Vazio quando não foi passado —
  /// e vazio é recusado em toda parte, de propósito.
  static const String urlConfigurada =
      String.fromEnvironment('BMV_SERVIDOR_URL');

  /// Autorização explícita para endereço local/sem TLS. Só tem efeito FORA do
  /// release: num build publicável ela é ignorada, senão bastaria ligá-la por
  /// engano para publicar um app que fala em claro.
  static const bool permitirEndpointInseguro =
      bool.fromEnvironment('BMV_PERMITIR_ENDPOINT_INSEGURO');

  /// Nomes que só existem dentro da máquina de quem desenvolve.
  static const Set<String> _hostsLocais = {
    'localhost',
    '127.0.0.1',
    '0.0.0.0',
    '::1',
    '::',
    // Android emulator (10.0.2.2) e Genymotion (10.0.3.2) apontam para o host
    // da máquina de desenvolvimento. Num celular de verdade não resolvem nada.
    '10.0.2.2',
    '10.0.3.2',
  };

  /// O endpoint efetivo deste build. Lança [EndpointInvalido] se a configuração
  /// não servir — quem chama transforma isso em estado seguro, não em crash.
  static Uri resolver() => validar(
        urlConfigurada,
        perfil: kReleaseMode
            ? PerfilDeBuild.release
            : PerfilDeBuild.desenvolvimento,
        permitirInseguro: permitirEndpointInseguro,
      );

  /// Valida um endereço sob uma política de perfil. Função pura: é ela que o
  /// teste exercita.
  static Uri validar(
    String bruto, {
    required PerfilDeBuild perfil,
    bool permitirInseguro = false,
  }) {
    final texto = bruto.trim();
    if (texto.isEmpty) {
      throw const EndpointInvalido(
        'o endereço do servidor não foi configurado neste build',
      );
    }

    final Uri url;
    try {
      url = Uri.parse(texto);
    } catch (_) {
      throw const EndpointInvalido('o endereço do servidor é inválido');
    }

    // A autorização de endereço local NUNCA vale num build publicável. Ligar a
    // chave por engano não pode ser suficiente para publicar um app inseguro.
    final frouxo =
        permitirInseguro && perfil == PerfilDeBuild.desenvolvimento;

    // ---- credencial não viaja na URL ----
    // Estas duas recusas valem em TODO perfil, inclusive desenvolvimento: um
    // `?token=` no endereço acaba em log de proxy, histórico e relatório de
    // erro. O servidor também ignora identidade vinda da URL — aqui é a mesma
    // regra, do lado de cá.
    if (url.userInfo.isNotEmpty) {
      throw const EndpointInvalido(
        'o endereço do servidor não pode carregar usuário ou senha',
      );
    }
    if (url.hasQuery || url.hasFragment) {
      throw const EndpointInvalido(
        'o endereço do servidor não pode carregar parâmetros',
      );
    }

    final esquema = url.scheme.toLowerCase();
    if (esquema.isEmpty || !url.hasAuthority) {
      throw const EndpointInvalido(
        'o endereço do servidor precisa começar com wss://',
      );
    }

    // ---- esquema ----
    // `https` é aceito e normalizado para `wss`: quem configura costuma copiar
    // o endereço do painel de hospedagem, que mostra o https.
    const seguros = {'wss', 'https'};
    const insegurosConhecidos = {'ws', 'http'};
    if (!seguros.contains(esquema)) {
      if (insegurosConhecidos.contains(esquema)) {
        if (!frouxo) {
          throw const EndpointInvalido(
            'o endereço do servidor precisa usar wss:// (conexão cifrada)',
          );
        }
      } else {
        throw const EndpointInvalido(
          'o endereço do servidor precisa começar com wss://',
        );
      }
    }

    // ---- host ----
    final host = url.host.toLowerCase();
    if (host.isEmpty) {
      throw const EndpointInvalido('o endereço do servidor não tem host');
    }
    if (_ehLocal(host) && !frouxo) {
      throw const EndpointInvalido(
        'este build está apontando para um servidor local, que não existe fora '
        'da máquina de desenvolvimento',
      );
    }

    // Normaliza para o esquema de WebSocket, tirando barra final e qualquer
    // resto de caminho vazio.
    final esquemaFinal = switch (esquema) {
      'https' => 'wss',
      'http' => 'ws',
      _ => esquema,
    };
    var caminho = url.path;
    if (caminho == '/') caminho = '';

    return Uri(
      scheme: esquemaFinal,
      host: url.host,
      port: url.hasPort ? url.port : null,
      path: caminho,
    );
  }

  /// Host que só resolve dentro da máquina de desenvolvimento: nomes locais,
  /// a faixa de loopback inteira (127.0.0.0/8) e os atalhos de emulador.
  static bool _ehLocal(String host) {
    final limpo = host.replaceAll('[', '').replaceAll(']', '');
    if (_hostsLocais.contains(limpo)) return true;
    // `.local` é mDNS — nome de máquina na rede de casa, não endereço público.
    if (limpo.endsWith('.local')) return true;
    // 127.0.0.0/8 inteiro, não só o 127.0.0.1.
    final partes = limpo.split('.');
    if (partes.length == 4 && partes[0] == '127') {
      return partes.every((p) {
        final n = int.tryParse(p);
        return n != null && n >= 0 && n <= 255;
      });
    }
    return false;
  }
}
