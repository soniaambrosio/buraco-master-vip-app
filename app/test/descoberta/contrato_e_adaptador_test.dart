// contrato_e_adaptador_test.dart — a FRONTEIRA do retrato (OS 38.2 §14.1).
//
// DOIS TRABALHOS, e os dois existem porque revisão de código não os garante:
//
// 1. O CONTRATO NÃO DIVERGIU. `contrato/descoberta-mesas-v1.json` existe
//    IDÊNTICO neste repositório e em `buraco-servidor`. Esta suíte afirma o
//    digest dele e compara, campo a campo, com as constantes que o aplicativo
//    usa. Editar uma cópia e não a outra reprova aqui E na suíte do servidor —
//    que é o único jeito de impedir que o vocabulário do fio passe a discordar
//    em silêncio entre dois repositórios que ninguém compila junto.
//
// 2. O ADAPTADOR É FAIL-CLOSED. Cada defeito possível de um retrato tem caso
//    próprio, e o esperado é sempre o mesmo: NADA entra. A prova de que o uid
//    não atravessa não é ler a lista branca — é mandar um retrato com uid e
//    ver o retrato inteiro ser recusado.
//
// O digest é sobre o conteúdo NORMALIZADO em LF. Sem normalizar, a mesma
// árvore reprovaria no Windows (CRLF pelo autocrlf) e passaria no CI — o
// contrário de um teste útil.

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:buraco_master_vip/descoberta/adaptador_descoberta.dart';
import 'package:buraco_master_vip/descoberta/contrato_descoberta.dart';
import 'package:buraco_master_vip/descoberta/modelo_descoberta.dart';

import 'retrato_de_teste.dart';

/// O digest do contrato congelado pela OS 38.1.
///
/// Mudou? Então o contrato mudou. Se a mudança é intencional, atualize este
/// valor NA MESMA alteração — e no repositório do servidor também, senão a
/// suíte de lá reprova. Ler o que mudou antes de atualizar é o ponto inteiro
/// deste caso existir.
const String kDigestDoContrato =
    'a528c9e465a815f4aebb284b30744a17a02badbc0d48bc7d9b0ba368c0c5c63b';

/// Onde o contrato mora, visto de onde o `flutter test` roda.
///
/// Funciona nos DOIS lugares: local, o CWD é `app/`; no CI, é `app_build/`,
/// que é irmão de `app/` na raiz do repositório. Nos dois, `../contrato` é a
/// mesma pasta.
File get arquivoDoContrato =>
    File('../contrato/descoberta-mesas-v1.json');

void main() {
  // =========================================================================
  group('CONTRATO — proveniência e não-divergência', () {
    // =======================================================================

    test('CT-01 o contrato existe onde o teste o procura', () {
      expect(
        arquivoDoContrato.existsSync(),
        isTrue,
        reason:
            'contrato/descoberta-mesas-v1.json não foi encontrado a partir de '
            '${Directory.current.path}. Ele é copiado da OS 38.1 e tem de '
            'viajar junto com o repositório.',
      );
    });

    test('CT-02 o digest do contrato é o da OS 38.1', () {
      final cru = arquivoDoContrato
          .readAsStringSync()
          .replaceAll('\r\n', '\n');
      final digest = sha256.convert(utf8.encode(cru)).toString();
      expect(
        digest,
        kDigestDoContrato,
        reason:
            'contrato/descoberta-mesas-v1.json mudou. Ele é a cópia do contrato '
            'do servidor (buraco-servidor @ d1de8a7). Se a mudança é '
            'intencional, atualize o digest AQUI e no servidor, na mesma '
            'alteração.',
      );
    });

    test('CT-03 o vocabulário do fio é o do contrato', () {
      final j = _contrato();
      final proto = j['protocoloWebSocket']! as Map<String, dynamic>;
      expect(proto['pedidoDoCliente'], ContratoDaDescoberta.pedidoDeMesas);
      expect(proto['respostaDoServidor'], ContratoDaDescoberta.respostaDeMesas);
      expect(proto['pulsoDoCliente'], ContratoDaDescoberta.pulsoDePresenca);
      expect(proto['reciboDoPulso'], ContratoDaDescoberta.reciboDePulso);
      expect(j['esquema'], ContratoDaDescoberta.esquema);
      expect(j['versao'], ContratoDaDescoberta.versao);
    });

    test('CT-04 os limites de frequência são os do contrato', () {
      final ritmo = (_contrato()['protocoloWebSocket']
          as Map<String, dynamic>)['ritmoMinimoMs'] as Map<String, dynamic>;
      expect(
        ritmo['descobrirMesas'],
        ContratoDaDescoberta.ritmoMinimoDeMesas.inMilliseconds,
      );
      expect(
        ritmo['presenca_ping'],
        ContratoDaDescoberta.ritmoMinimoDePulso.inMilliseconds,
      );
    });

    test('CT-05 as recusas de ritmo são as do contrato', () {
      final recusas = (_contrato()['protocoloWebSocket']
          as Map<String, dynamic>)['recusas'] as Map<String, dynamic>;
      expect(
        recusas['ritmoDeDescoberta'],
        ContratoDaDescoberta.recusaDeRitmoDeMesas,
      );
      expect(
        recusas['ritmoDePresenca'],
        ContratoDaDescoberta.recusaDeRitmoDePulso,
      );
    });

    test('CT-06 as listas FECHADAS de campos são as do contrato', () {
      final j = _contrato();
      expect(
        _conjunto(j['respostaMesas'], 'campos'),
        ContratoDaDescoberta.camposDoRetrato,
      );
      expect(_conjunto(j['mesa'], 'campos'), ContratoDaDescoberta.camposDaMesa);
      expect(
        _conjunto(j['assento'], 'campos'),
        ContratoDaDescoberta.camposDoAssento,
      );
      expect(
        _conjunto(j['presenca'], 'campos'),
        ContratoDaDescoberta.camposDaPresenca,
      );
      final porMod =
          (j['presenca']! as Map<String, dynamic>)['porModalidade']!
              as Map<String, dynamic>;
      expect(
        (porMod['campos']! as List).cast<String>().toSet(),
        ContratoDaDescoberta.camposDaModalidade,
      );
    });

    test('CT-07 as modalidades e o estado de ingresso são os do contrato', () {
      final j = _contrato();
      final porMod =
          (j['presenca']! as Map<String, dynamic>)['porModalidade']!
              as Map<String, dynamic>;
      expect(
        (porMod['chaves']! as List).cast<String>().toSet(),
        ModalidadeDeMesa.values.map((m) => m.chave).toSet(),
      );
      final ingresso = j['estadoIngresso']! as Map<String, dynamic>;
      expect(
        (ingresso['valores']! as List).cast<String>().toSet(),
        EstadoDeIngresso.values.map((e) => e.chave).toSet(),
      );
      expect(
        (j['assento']! as Map<String, dynamic>)['tipos'],
        containsAll(TipoDeOcupante.values.map((t) => t.chave)),
      );
    });

    test('CT-08 a capacidade declarada é quatro, nos dois lados', () {
      expect(ContratoDaDescoberta.capacidadeDaMesa, 4);
      // O contrato descreve a lista de assentos como "quatro posições sempre".
      final nota = (_contrato()['assento']! as Map<String, dynamic>)['//']
          as String;
      expect(nota.toLowerCase(), contains('quatro'));
    });

    test('CT-09 o contrato lista o que é proibido, e o app recusa tudo', () {
      final proibidos = ((_contrato()['proibidoNoFio']!
                  as Map<String, dynamic>)['itens']!
              as List)
          .cast<String>()
          .where((s) => !s.contains(' '))
          .toSet();
      // Todo item de uma palavra do contrato tem de estar na varredura do app.
      for (final p in proibidos) {
        expect(
          ContratoDaDescoberta.chavesProibidas,
          contains(p),
          reason: 'o contrato proíbe "$p" e o adaptador não o varre',
        );
      }
    });
  });

  // =========================================================================
  group('REGISTRO — a suíte não pode sumir do portão', () {
    // =======================================================================
    //
    // A §15 exige que "apagar, renomear ou desregistrar a suíte obrigatória"
    // fique VERMELHO. Sem estes casos, remover as cinco linhas da fonte única
    // de gates deixaria as suítes existindo, verdes e IRRELEVANTES: elas
    // simplesmente não rodariam no CI, e ninguém saberia.
    //
    // Os cinco gates são conferidos por UMA suíte só — esta. É de propósito:
    // se cada suíte guardasse a própria inscrição, apagar a suíte apagaria o
    // guarda dela junto, que é exatamente o buraco.

    const gates = [
      'descadapt',
      'descestado',
      'deschome',
      'descstbl',
      'desclobby',
    ];

    test('RG-10 os cinco gates estão na FONTE ÚNICA', () {
      final fonte = File('../scripts/ci/gates_os_integracao.txt');
      expect(
        fonte.existsSync(),
        isTrue,
        reason: 'a fonte única de gates não foi encontrada a partir de '
            '${Directory.current.path}',
      );
      // Só as linhas que VALEM como gate: em branco e comentário são ignoradas
      // pelo agregador, então `#deschome` não conta como inscrito.
      final inscritos = fonte
          .readAsLinesSync()
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty && !l.startsWith('#'))
          .toSet();
      for (final g in gates) {
        expect(
          inscritos,
          contains(g),
          reason:
              'o gate "$g" saiu de scripts/ci/gates_os_integracao.txt. A suíte '
              'continuaria verde e o CI não a rodaria.',
        );
      }
    });

    test('RG-11 cada gate tem um passo que o EXECUTA no workflow', () {
      final wf = File('../.github/workflows/ci-os-integracao.yml');
      expect(wf.existsSync(), isTrue);
      final texto = wf.readAsStringSync();
      for (final g in gates) {
        expect(
          RegExp('roda\\s+$g\\s+test/').hasMatch(texto),
          isTrue,
          reason:
              'não há `roda $g test/...` no workflow. Inscrever sem executar '
              'faz o agregador reprovar por NÃO EXECUTADO — o que é melhor que '
              'verde falso, mas não é o que se quer.',
        );
      }
    });

    test('RG-12 os arquivos apontados pelo workflow EXISTEM', () {
      final wf = File(
        '../.github/workflows/ci-os-integracao.yml',
      ).readAsStringSync();
      for (final g in gates) {
        final m = RegExp('roda\\s+$g\\s+(test/[^\\s]+)').firstMatch(wf);
        expect(m, isNotNull, reason: 'gate $g sem caminho');
        final caminho = m!.group(1)!;
        expect(
          File(caminho).existsSync(),
          isTrue,
          reason:
              'o workflow manda rodar "$caminho" e o arquivo não existe. '
              'Renomear a suíte sem atualizar o workflow deixaria o gate '
              'ausente, e ausência é reprovação — mas só no CI, tarde demais.',
        );
      }
    });
  });

  // =========================================================================
  group('ADAPTADOR — o que entra', () {
    // =======================================================================

    test('AD-01 retrato bem formado entra inteiro', () {
      final r = _aceito(
        retratoDeMesas(
          mesas: [
            mesa(codigo: 'M-01', humanos: 3, apelidos: ['Ana', 'Bruno', 'Caio']),
            mesa(codigo: 'M-02', modalidade: 'aberto', humanos: 1),
          ],
        ),
      );
      expect(r.mesas, hasLength(2));
      expect(r.geracao, 'ger-1');
      expect(r.revisao, 1);
      expect(r.mesas.first.codigo, 'M-01');
      expect(r.mesas.first.jogadores, 3);
      expect(r.mesas.first.modalidade, ModalidadeDeMesa.sbtl);
      expect(r.mesas[1].modalidade, ModalidadeDeMesa.aberto);
      expect(r.presenca.jogadoresEmMesasPublicas, 4);
      expect(r.presenca.mesasPublicas, 2);
    });

    test('AD-02 lista vazia é retrato válido, e não ausência de retrato', () {
      final r = _aceito(retratoDeMesas(mesas: const []));
      expect(r.mesas, isEmpty);
      expect(r.vazio, isTrue);
      expect(r.presenca.mesasPublicas, 0);
    });

    test('AD-03 os quatro assentos chegam na ordem, com livre e ocupado', () {
      final r = _aceito(
        retratoDeMesas(
          mesas: [
            mesa(codigo: 'M-01', humanos: 2, apelidos: ['Ana', 'Bruno']),
          ],
        ),
      );
      final a = r.mesas.first.assentos;
      expect(a, hasLength(4));
      expect(a.map((x) => x.assento), [0, 1, 2, 3]);
      expect(a.map((x) => x.ocupado), [true, true, false, false]);
      expect(a[0].apelido, 'Ana');
      expect(a[2].apelido, isNull);
      expect(a[2].tipo, isNull);
    });

    test('AD-04 bot é ocupante e NÃO é jogador', () {
      final r = _aceito(
        retratoDeMesas(
          mesas: [mesa(codigo: 'M-01', humanos: 1, bots: 3, iniciada: true)],
        ),
      );
      final m = r.mesas.first;
      expect(m.jogadores, 1);
      expect(m.bots, 3);
      expect(m.ocupados, 4);
      expect(m.vagas, 0);
      expect(m.assentos[1].ehBot, isTrue);
      expect(m.assentos[1].ehHumano, isFalse);
      expect(m.estadoIngresso, EstadoDeIngresso.emAndamento);
      expect(m.ingressavel, isFalse);
    });

    test('AD-05 avatar de galeria atravessa; ausência vira nulo', () {
      final r = _aceito(
        retratoDeMesas(
          mesas: [
            mesa(
              codigo: 'M-01',
              humanos: 2,
              apelidos: ['Ana', 'Bruno'],
              avatares: [7, null],
            ),
          ],
        ),
      );
      expect(r.mesas.first.assentos[0].avatarGaleria, 7);
      expect(r.mesas.first.assentos[1].avatarGaleria, isNull);
    });

    test('AD-06 `aguardandoHaMs` vira Duration', () {
      final r = _aceito(
        retratoDeMesas(
          mesas: [mesa(codigo: 'M-01', aguardandoHaMs: 125000)],
        ),
      );
      expect(r.mesas.first.aguardandoHa, const Duration(milliseconds: 125000));
    });
  });

  // =========================================================================
  group('ADAPTADOR — o que NÃO entra (fail-closed)', () {
    // =======================================================================

    test('AD-07 não-mapa', () {
      _recusado('isto não é um retrato', RecusaDeRetrato.naoEhMapa);
      _recusado(const <Object?>[], RecusaDeRetrato.naoEhMapa);
      _recusado(null, RecusaDeRetrato.naoEhMapa);
    });

    test('AD-08 esquema desconhecido', () {
      final p = retratoDeMesas()..['esquema'] = 'descoberta-mesas-v2';
      _recusado(p, RecusaDeRetrato.esquemaDesconhecido);
    });

    test('AD-09 campo obrigatório ausente', () {
      final p = retratoDeMesas()..remove('revisao');
      _recusado(p, RecusaDeRetrato.campoAusente);
    });

    test('AD-10 campo DESCONHECIDO reprova — sobrar é tão grave quanto faltar', () {
      final p = retratoDeMesas()..['novidade'] = 1;
      _recusado(p, RecusaDeRetrato.campoDesconhecido);
    });

    test('AD-11 tipo incorreto: número que veio como texto', () {
      final p = retratoDeMesas()..['revisao'] = '3';
      _recusado(p, RecusaDeRetrato.tipoIncorreto);
    });

    test('AD-12 CHAVE PROIBIDA em qualquer profundidade', () {
      // 1º nível
      _recusado(
        retratoDeMesas()..['uid'] = 'uid-vazado',
        RecusaDeRetrato.chaveProibida,
      );
      // dentro da mesa
      final m = mesa(codigo: 'M-01')..['jogadorId'] = 'uid-vazado';
      _recusado(
        retratoDeMesas(mesas: [m]),
        RecusaDeRetrato.chaveProibida,
      );
      // dentro do ASSENTO, que é onde ele moraria
      final m2 = mesa(codigo: 'M-02');
      (m2['assentos']! as List).first as Map<String, Object?>
        ..['jogadorId'] = 'uid-vazado';
      _recusado(
        retratoDeMesas(mesas: [m2]),
        RecusaDeRetrato.chaveProibida,
      );
      // dentro da presença
      final p = retratoDeMesas();
      (p['presenca']! as Map<String, Object?>)['admissaoId'] = 'adm-1';
      _recusado(p, RecusaDeRetrato.chaveProibida);
    });

    test('AD-13 estado do motor no payload também é recusado', () {
      final m = mesa(codigo: 'M-01')..['jogo'] = {'rodada': 1};
      _recusado(retratoDeMesas(mesas: [m]), RecusaDeRetrato.chaveProibida);
    });

    test('AD-14 número negativo', () {
      final m = mesa(codigo: 'M-01')..['vagas'] = -1;
      _recusado(retratoDeMesas(mesas: [m]), RecusaDeRetrato.numeroNegativo);
    });

    test('AD-15 capacidade diferente de quatro', () {
      final m = mesa(codigo: 'M-01')..['capacidade'] = 6;
      _recusado(
        retratoDeMesas(mesas: [m]),
        RecusaDeRetrato.capacidadeInvalida,
      );
    });

    test('AD-16 vetor de assentos com tamanho errado', () {
      final m = mesa(codigo: 'M-01');
      (m['assentos']! as List).removeLast();
      _recusado(
        retratoDeMesas(mesas: [m]),
        RecusaDeRetrato.assentosInvalidos,
      );
    });

    test('AD-17 índice do assento que não bate com a posição', () {
      final m = mesa(codigo: 'M-01');
      ((m['assentos']! as List)[2] as Map<String, Object?>)['assento'] = 3;
      _recusado(
        retratoDeMesas(mesas: [m]),
        RecusaDeRetrato.assentosInvalidos,
      );
    });

    test('AD-18 assento LIVRE carregando apelido é fantasma', () {
      final m = mesa(codigo: 'M-01');
      ((m['assentos']! as List)[3] as Map<String, Object?>)['apelido'] = 'Zé';
      _recusado(
        retratoDeMesas(mesas: [m]),
        RecusaDeRetrato.assentosInvalidos,
      );
    });

    test('AD-19 modalidade desconhecida', () {
      final m = mesa(codigo: 'M-01', modalidade: 'rapida');
      _recusado(
        retratoDeMesas(mesas: [m]),
        RecusaDeRetrato.modalidadeDesconhecida,
      );
    });

    test('AD-20 estado de ingresso desconhecido', () {
      final m = mesa(codigo: 'M-01')..['estadoIngresso'] = 'quase_cheia';
      _recusado(
        retratoDeMesas(mesas: [m]),
        RecusaDeRetrato.ingressoDesconhecido,
      );
    });

    test('AD-21 aritmética da mesa que não fecha', () {
      // jogadores + bots != ocupados
      final m = mesa(codigo: 'M-01', humanos: 2)..['jogadores'] = 3;
      _recusado(
        retratoDeMesas(mesas: [m]),
        RecusaDeRetrato.presencaIncoerente,
      );
      // vagas que não é capacidade - ocupados
      final m2 = mesa(codigo: 'M-02', humanos: 1)..['vagas'] = 2;
      _recusado(
        retratoDeMesas(mesas: [m2]),
        RecusaDeRetrato.presencaIncoerente,
      );
    });

    test('AD-22 presença incoerente: público maior que o total', () {
      final p = retratoDeMesas(mesas: [mesa(codigo: 'M-01', humanos: 3)]);
      (p['presenca']! as Map<String, Object?>)['jogadoresOnlineTotal'] = 1;
      _recusado(p, RecusaDeRetrato.presencaIncoerente);
    });

    test('AD-23 presença incoerente: os pedaços não somam o todo', () {
      final p = retratoDeMesas(mesas: [mesa(codigo: 'M-01', humanos: 3)]);
      (p['presenca']! as Map<String, Object?>)['jogadoresEmMesasPublicasAguardando'] =
          0;
      _recusado(p, RecusaDeRetrato.presencaIncoerente);
    });

    test('AD-24 presença incoerente: mesasPublicas discorda da lista', () {
      final p = retratoDeMesas(mesas: [mesa(codigo: 'M-01')]);
      (p['presenca']! as Map<String, Object?>)['mesasPublicas'] = 5;
      _recusado(p, RecusaDeRetrato.presencaIncoerente);
    });

    test('AD-25 falta uma modalidade em porModalidade', () {
      final p = retratoDeMesas();
      ((p['presenca']! as Map<String, Object?>)['porModalidade']!
              as Map<String, Object?>)
          .remove('fechado');
      _recusado(p, RecusaDeRetrato.campoAusente);
    });

    test('AD-26 uma recusa NÃO produz retrato pela metade', () {
      final leitura = AdaptadorDaDescoberta.ler(
        retratoDeMesas()..['esquema'] = 'outro',
      );
      expect(leitura.ok, isFalse);
      expect(leitura.retrato, isNull);
      expect(leitura.recusa, isNotNull);
    });
  });
}

// ---------------------------------------------------------------------------
// auxiliares
// ---------------------------------------------------------------------------

Map<String, dynamic> _contrato() =>
    jsonDecode(arquivoDoContrato.readAsStringSync()) as Map<String, dynamic>;

Set<String> _conjunto(Object? bloco, String chave) =>
    ((bloco! as Map<String, dynamic>)[chave]! as List).cast<String>().toSet();

RetratoDaDescoberta _aceito(Object? bruto) {
  final leitura = AdaptadorDaDescoberta.ler(bruto);
  expect(
    leitura.ok,
    isTrue,
    reason: 'esperava aceitar, mas recusou por ${leitura.recusa}',
  );
  return leitura.retrato!;
}

void _recusado(Object? bruto, RecusaDeRetrato esperada) {
  final leitura = AdaptadorDaDescoberta.ler(bruto);
  expect(leitura.ok, isFalse, reason: 'esperava recusar, mas aceitou');
  expect(leitura.recusa, esperada);
}
