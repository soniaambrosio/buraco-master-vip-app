// O gatilho de crash controlado não pode vazar para a loja.
//
// A garantia não é este teste — é `bool.fromEnvironment`, que é `const` e faz
// o AOT descartar o corpo do método numa build sem o define. Este teste existe
// para que a garantia continue sendo essa: se alguém trocar a constante por um
// campo, uma variável de ambiente lida em runtime ou uma preferência salva, o
// teste continua passando aqui e a proteção some. Por isso ele afirma sobre o
// VALOR PADRÃO e sobre a ausência de efeito, que é o que se pode observar.
//
// A prova de que o código não está no binário comercial é outra, e está na
// evidência: `strings` no `libapp.so` de uma build sem o define não acha o
// marcador.

import 'package:buraco_master_vip/observability/coletor.dart';
import 'package:buraco_master_vip/observability/gatilho_homologacao.dart';
import 'package:buraco_master_vip/observability/identidade_build.dart';
import 'package:buraco_master_vip/observability/observabilidade.dart';
import 'package:buraco_master_vip/observability/redacao.dart';
import 'package:flutter_test/flutter_test.dart';

const IdentidadeBuild identidade = IdentidadeBuild(
  versionName: '1.0.0',
  versionCode: 141,
  sha: '14cf1edb6bd78fccefe3a8ae584ee76bad830e46',
  branch: 'claude/crashlytics-android-operacional-v1',
  ambiente: AmbienteBuild.homologacao,
);

void main() {
  test('sem o --dart-define, o gatilho está DESARMADO', () {
    // A suíte roda sem `BMV_CRASH_HOMOLOGACAO`, que é a configuração de
    // qualquer build comercial.
    expect(GatilhoHomologacao.armado, isFalse);
  });

  test('desarmado, armarSePedido não faz absolutamente nada', () async {
    final memoria = ColetorEmMemoria();
    final obs = await Observabilidade.instalar(
      identidade: identidade,
      coletorReal: memoria,
      forcarColetorReal: true,
      instalarHooks: false,
    );

    GatilhoHomologacao.armarSePedido(obs);

    expect(memoria.eventos, isEmpty,
        reason: 'build comercial não pode nem registrar que o gatilho existe');
    obs.desinstalar();
  });

  test('o marcador sobrevive à redação', () {
    // O [Redator] apaga sequências opacas de 24 caracteres ou mais. Um
    // marcador longo sumiria justamente do evento que ele deveria marcar —
    // e a homologação ficaria sem como achar a ocorrência no painel.
    expect(GatilhoHomologacao.marcador.length, lessThan(24));
    const r = Redator();
    expect(r.texto('falha ${GatilhoHomologacao.marcador} controlada'),
        contains(GatilhoHomologacao.marcador));
    expect(r.texto('${const CrashDeHomologacao(GatilhoHomologacao.marcador)}'),
        contains(GatilhoHomologacao.marcador));
  });

  test('a exceção tem tipo próprio, para o painel agrupar e filtrar', () {
    const e = CrashDeHomologacao(GatilhoHomologacao.marcador);
    expect(e.runtimeType.toString(), 'CrashDeHomologacao');
    expect('$e', contains('BMV-HOMOLOG-CRASH'));
  });

  test('a espera dá tempo do Crashlytics nativo iniciar', () {
    // Quebrar antes disso perde o relatório: o SDK ainda não tem onde gravar.
    // O sintoma vira "não chegou ao painel", que manda a investigação para o
    // lado errado.
    expect(GatilhoHomologacao.espera.inSeconds, greaterThanOrEqualTo(5));
  });

  test('a descrição avisa quando a build está armada', () {
    // Em build desarmada a frase é tranquilizadora; em armada, é um aviso.
    expect(GatilhoHomologacao.descrever(identidade), contains('gatilho'));
    expect(GatilhoHomologacao.descrever(identidade),
        GatilhoHomologacao.armado ? contains('Não publicar') : contains('normal'));
  });
}
