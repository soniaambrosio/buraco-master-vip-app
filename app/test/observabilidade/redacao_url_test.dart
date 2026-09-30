// redacao_url_test.dart — URL com segredo não sai do dispositivo.
//
// ---------------------------------------------------------------------------
// POR QUE ESTA SUÍTE EXISTE
// ---------------------------------------------------------------------------
//
// A redação tinha um furo que atravessava as DUAS defesas ao mesmo tempo, e
// atravessava justamente porque elas se atrapalhavam:
//
//     https://servidor.tld/ws?token=abc123&uid=xyz
//
// A negação por NOME casa `chave: valor` em texto livre. Numa URL, a primeira
// coisa que ela encontra é `https` seguido de `:` — e `https` não é chave
// proibida. O casamento então consome `//servidor.tld/ws?token=abc123&uid=xyz`
// inteiro como se fosse o "valor" de um campo inofensivo, devolve o trecho
// intacto e, por tê-lo consumido, nunca chega a olhar o `token=` lá dentro.
//
// A negação por FORMA também não alcança: o blob opaco exige 24 caracteres
// seguidos de `[A-Za-z0-9_-]`, e `/`, `.`, `?`, `=` e `&` quebram a corrida em
// pedaços curtos. Nem `abc123` nem `xyz` chegam perto do piso.
//
// Resultado: o segredo saía inteiro para o painel do coletor.
//
// A resposta é uma terceira leitura, POSICIONAL: numa URL, o que vem depois de
// `?chave=`, `&chave=` ou `#chave=` é valor de parâmetro, e valor de parâmetro
// é segredo pela POSIÇÃO — não depende do nome do campo nem do formato do
// valor. Ela roda antes de tudo, porque precisa chegar ao `token=` antes que o
// casamento por nome engula a URL inteira.
//
// Os casos abaixo estão divididos em três blocos, e os três são obrigatórios:
//   · REGRESSÃO POSITIVA — o segredo tem de sumir;
//   · REGRESSÃO NEGATIVA — o diagnóstico tem de sobreviver;
//   · PROVA ATÉ O COLETOR — o que chega ao destino não contém o segredo.

import 'dart:convert';

import 'package:buraco_master_vip/observability/coletor.dart';
import 'package:buraco_master_vip/observability/evento_falha.dart';
import 'package:buraco_master_vip/observability/identidade_build.dart';
import 'package:buraco_master_vip/observability/manifesto_build.dart';
import 'package:buraco_master_vip/observability/observabilidade.dart';
import 'package:buraco_master_vip/observability/redacao.dart';
import 'package:flutter_test/flutter_test.dart';

const IdentidadeBuild _identidade = IdentidadeBuild(
  versionName: '1.4.2',
  versionCode: 412,
  sha: '891c0b3461516db880355a30fc388f05106e43c1',
  branch: 'correcao/os49-1-redacao-query-crashlytics-v1',
  ambiente: AmbienteBuild.producao,
  flutterVersion: '3.44.8',
  dartVersion: '3.11.1',
);

/// Erro com causa aninhada — o caminho clássico de vazamento.
class _ErroComCausa implements Exception {
  _ErroComCausa(this.mensagem, [this.causa]);
  final String mensagem;
  final Object? causa;
  @override
  String toString() => '_ErroComCausa: $mensagem';
}

void main() {
  const r = Redator();

  // ------------------------------------------------------------------ dados
  //
  // Os valores são CURTOS e alfanuméricos mistos de propósito. Um `purchaseToken`
  // de verdade seria pego pelo blob opaco, um JWT pela forma, um número de 16
  // dígitos pelos dígitos longos — e o teste passaria sem exercitar a regra
  // nova. Aqui nada, além da leitura posicional, tem como pegar `abc123`.
  const segredoCurto = 'abc123';
  const uidCurto = 'xyz789';
  const host = 'https://servidor.tld/ws';
  const urlDoLaudo = '$host?token=$segredoCurto&uid=$uidCurto';

  group('regressão positiva — o valor de parâmetro sempre some', () {
    test('o caso do laudo: token e uid na mesma URL', () {
      final saida = r.texto('falha ao abrir socket em $urlDoLaudo');

      expect(saida, isNot(contains(segredoCurto)));
      expect(saida, isNot(contains(uidCurto)));
      expect(saida, isNot(contains(urlDoLaudo)));
      expect(saida, contains(marcaRedacao));
    });

    test('não depende do nome do parâmetro — a defesa é pela posição', () {
      // `t` não está (e nunca estará) na lista de chaves proibidas. Se a
      // proteção dependesse do nome, este caso vazaria.
      final saida = r.texto('GET https://api.tld/v1/entrar?t=$segredoCurto');
      expect(saida, isNot(contains(segredoCurto)));
    });

    test('parâmetros sensíveis, um por um', () {
      for (final parametro in <String>[
        'token',
        'id_token',
        'access_token',
        'refresh_token',
        'uid',
        'user_id',
        'apiKey',
        'senha',
        'password',
        'secret',
        'authorization',
        'session',
        'purchaseToken',
        'signature',
      ]) {
        final saida = r.texto('$host?$parametro=$segredoCurto');
        expect(
          saida,
          isNot(contains(segredoCurto)),
          reason: 'o valor de `$parametro` chegou inteiro ao coletor',
        );
        expect(
          saida,
          contains(parametro),
          reason: 'o NOME de `$parametro` deveria sobreviver ao filtro',
        );
      }
    });

    test('fragmento também carrega credencial (OAuth implícito)', () {
      // No fluxo implícito o provedor devolve o token DEPOIS do `#`, que nem
      // chega a ser enviado ao servidor — e é exatamente por isso que ele
      // acaba colado em texto de diagnóstico.
      final saida = r.texto(
        'redirecionou para https://app.tld/callback#access_token=$segredoCurto&token_type=Bearer',
      );
      expect(saida, isNot(contains(segredoCurto)));
    });

    test('todos os parâmetros somem, não só o primeiro', () {
      final saida = r.texto('$host?a=$segredoCurto&b=$uidCurto&c=k9m2p');
      expect(saida, isNot(contains(segredoCurto)));
      expect(saida, isNot(contains(uidCurto)));
      expect(saida, isNot(contains('k9m2p')));
    });

    test('valor percent-encoded não escapa', () {
      final saida = r.texto('$host?token=YWJjMTIz%3D%3D&uid=$uidCurto');
      expect(saida, isNot(contains('YWJjMTIz')));
      expect(saida, isNot(contains(uidCurto)));
    });

    test('a URL some dentro de uma exceção aninhada', () {
      final elos = r.cadeiaDeCausas(
        _ErroComCausa(
          'não foi possível entrar na mesa',
          _ErroComCausa('handshake recusado', StateError(urlDoLaudo)),
        ),
      );
      expect(elos.join('\n'), isNot(contains(segredoCurto)));
      expect(elos.join('\n'), isNot(contains(uidCurto)));
    });

    test('a URL some dentro de um valor de contexto', () {
      final ctx = r.contexto(<String, Object?>{'endpoint': urlDoLaudo});
      expect('${ctx.values}', isNot(contains(segredoCurto)));
      expect('${ctx.values}', isNot(contains(uidCurto)));
    });

    test('a URL some dentro de um stack trace', () {
      // Stack trace usa só os padrões inequívocos. A leitura posicional é um
      // deles justamente para que este caminho também esteja coberto.
      final saida = r.stack(
        '#0  Conexao.abrir (package:buraco_master_vip/services/online.dart:88:5)\n'
        '#1  <asynchronous suspension> ao conectar em $urlDoLaudo',
      );
      expect(saida, isNot(contains(segredoCurto)));
      expect(saida, isNot(contains(uidCurto)));
    });

    test('redigir duas vezes dá o mesmo resultado', () {
      final uma = r.texto('conectando em $urlDoLaudo');
      final duas = r.texto(uma);
      expect(duas, uma);
    });
  });

  group('regressão negativa — o diagnóstico continua legível', () {
    test('esquema, host e caminho sobrevivem', () {
      final saida = r.texto('falha ao abrir socket em $urlDoLaudo');
      expect(saida, contains('https://servidor.tld/ws'));
    });

    test('o NOME do parâmetro sobrevive — saber que havia um token é legítimo', () {
      final saida = r.texto(urlDoLaudo);
      expect(saida, contains('token'));
      expect(saida, contains('uid'));
    });

    test('a saída completa, fixada — o formato é contrato, não acaso', () {
      // Igualdade exata de propósito: qualquer mudança no que sai daqui passa
      // a exigir uma decisão consciente, e não some num `contains`.
      //
      // O `uid` aparece com `:` e o `token` com `=`, e isso NÃO é defeito. A
      // leitura posicional deixa `?token=[REDIGIDO]&uid=[REDIGIDO]`; em
      // seguida, a negação por chave passa e reconhece `uid=[REDIGIDO]` como
      // par nomeado de chave proibida — ela reescreve todo par que reconhece
      // no formato canônico `chave: [REDIGIDO]`, e é o mesmo comportamento que
      // a suíte de redação já fixa para texto livre. O `token` escapa dessa
      // segunda passada porque foi consumido dentro do casamento do `https:`
      // que abre a URL. O que importa ao diagnóstico — os dois NOMES e o
      // destino — sobrevive nos dois caminhos.
      expect(
        r.texto(urlDoLaudo),
        'https://servidor.tld/ws?token=$marcaRedacao&uid: $marcaRedacao',
      );
    });

    test('URL sem parâmetro nenhum não é tocada', () {
      const limpa = 'https://servidor.tld/ws/mesa/publica';
      expect(r.texto(limpa), limpa);
    });

    test('prosa com interrogação não vira redação', () {
      const prosa = 'a partida caiu? o placar continuava 2 a 1.';
      expect(r.texto(prosa), prosa);
    });

    test('SHA de commit continua inteiro', () {
      final saida = r.texto('build ${_identidade.sha} caiu em $urlDoLaudo');
      expect(saida, contains(_identidade.sha));
    });

    test('stack trace preserva pacote, arquivo e linha', () {
      final saida = r.stack(
        '#0  Conexao.abrir (package:buraco_master_vip/services/online.dart:88:5)',
      );
      expect(saida, contains('package:buraco_master_vip/services/online.dart'));
      expect(saida, contains('88:5'));
    });

    test('o manifesto de build continua sem segredos — o gate não passa a reprovar', () {
      // `semSegredos` é o auto-teste do gate de release e roda pelos mesmos
      // padrões inequívocos. Se a leitura posicional casasse com algum campo
      // do manifesto, TODA release passaria a reprovar.
      final manifesto = ManifestoBuild(
        identidade: _identidade,
        artefatos: <String, String>{
          'build/app/outputs/flutter-apk/app-arm64-v8a-release.apk':
              '9f2b7c1d4e6a8b0c2d4e6f8a0b2c4d6e8f0a2b4c6d8e0f2a4b6c8d0e2f4a6b8c',
        },
        simbolos: <String, String>{
          'build/simbolos/app.android-arm64.symbols':
              '1a3c5e7902468ace1357bdf02468ace1357bdf02468ace1357bdf02468ace13',
        },
      );
      expect(manifesto.semSegredos, isTrue);
    });
  });

  group('prova até o coletor — o que chega ao destino', () {
    late ColetorEmMemoria memoria;

    setUp(() => memoria = ColetorEmMemoria());
    tearDown(() => Observabilidade.instancia.desinstalar());

    Future<Observabilidade> instalar() => Observabilidade.instalar(
          identidade: _identidade,
          coletorReal: memoria,
          forcarColetorReal: true,
          instalarHooks: false,
        );

    test('nenhuma URL sensível chega intacta ao coletor', () async {
      final obs = await instalar();

      // Cada linha é um caminho DIFERENTE de entrada no evento: mensagem,
      // erro, causa aninhada e valor de contexto.
      obs.registrarFalha(
        _ErroComCausa('queda de conexão', StateError('destino $urlDoLaudo')),
        mensagem: 'não foi possível reconectar em $urlDoLaudo',
        contexto: <String, Object?>{
          'endpoint': urlDoLaudo,
          'ultimaTentativa': 'https://servidor.tld/ws?uid=$uidCurto',
        },
      );

      expect(memoria.eventos, hasLength(1));

      // A varredura é sobre o JSON INTEIRO do evento — é o que o coletor
      // serializa e manda. Nenhum campo fica de fora por esquecimento.
      final serializado = jsonEncode(memoria.eventos.single.paraJson());
      expect(serializado, isNot(contains(segredoCurto)));
      expect(serializado, isNot(contains(uidCurto)));
      expect(serializado, isNot(contains(urlDoLaudo)));

      // E o evento ainda serve para investigar: identidade e host continuam lá.
      expect(serializado, contains(_identidade.sha));
      expect(serializado, contains('servidor.tld'));
    });

    test('o evento montado direto por EventoFalha.de também está limpo', () async {
      final evento = EventoFalha.de(
        erro: StateError(urlDoLaudo),
        stack: StackTrace.fromString('#0 abrir ($urlDoLaudo)'),
        identidade: _identidade,
        severidade: Severidade.fatal,
        origem: OrigemFalha.zona,
        contexto: <String, Object?>{'endpoint': urlDoLaudo},
        mensagem: 'socket recusado: $urlDoLaudo',
      );

      final serializado = jsonEncode(evento.paraJson());
      expect(serializado, isNot(contains(segredoCurto)));
      expect(serializado, isNot(contains(uidCurto)));
    });
  });
}
