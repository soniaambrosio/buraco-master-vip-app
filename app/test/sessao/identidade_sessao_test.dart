// identidade_sessao_test.dart — os casos da OS que se provam SEM widget.
//
// Cobre A, E, F, G, H, I, J, K, L e M. Os casos que dependem de tela (B, C, D,
// O, e a metade visual de E) ficam em `telas_consomem_identidade_test.dart`; a
// prova estrutural (N) fica em `auditoria_identidade_test.dart`.
//
// A FONTE É FALSA E CONTROLADA À MÃO. Nenhum destes casos é encenável contra a
// Cloud Function real: "resposta atrasada de A chega depois do login de B" exige
// segurar uma resposta no ar por tempo indeterminado, e é exatamente o cenário
// que mais importa provar.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:buraco_master_vip/sessao/fonte_identidade.dart';
import 'package:buraco_master_vip/sessao/identidade_publica_sessao.dart';
import 'package:buraco_master_vip/sessao/sessao_do_jogador.dart';

/// Fonte de identidade com o relógio na mão do teste.
///
/// Cada chamada devolve um `Completer` que o teste resolve quando quiser — é o
/// que permite encenar concorrência, atraso e falha de forma determinística, sem
/// `Future.delayed` e sem flakiness.
class FonteFalsa implements FonteDeIdentidade {
  final List<Completer<IdentidadePublica>> pendentes = [];
  int chamadas = 0;

  @override
  Future<IdentidadePublica> obterMinhaIdentidade() {
    chamadas++;
    final c = Completer<IdentidadePublica>();
    pendentes.add(c);
    return c.future;
  }

  void responder(String publicId, {String apelido = '', int indice = -1}) {
    final c = pendentes[indice < 0 ? pendentes.length - 1 : indice];
    c.complete(_identidade(publicId, apelido));
  }

  void falhar({
    MotivoFalhaIdentidade motivo = MotivoFalhaIdentidade.indisponivel,
    int indice = -1,
  }) {
    final c = pendentes[indice < 0 ? pendentes.length - 1 : indice];
    c.completeError(FalhaIdentidade(motivo, 'encenado pelo teste'));
  }
}

IdentidadePublica _identidade(String publicId, [String apelido = '']) =>
    IdentidadePublica(
      publicId: publicId,
      apelido: apelido,
      avatarRef: null,
      criada: false,
      estado: EstadoPerfil.ativo,
      limites: LimitesSociais.desconhecidos,
      edicao: MetadadosDeEdicao.desconhecidos,
    );

void main() {
  late FonteFalsa fonte;
  late StreamController<String?> auth;
  late SessaoDoJogador sessao;

  setUp(() {
    fonte = FonteFalsa();
    auth = StreamController<String?>.broadcast();
    sessao = SessaoDoJogador(fonte: fonte, uids: auth.stream);
  });

  tearDown(() {
    sessao.dispose();
    auth.close();
  });

  /// Entrega o uid ao controller e deixa o stream girar.
  Future<void> logar(String? uid) async {
    auth.add(uid);
    await Future<void>.delayed(Duration.zero);
  }

  // =========================================================================
  // CASO A — sessão autenticada
  // =========================================================================
  group('CASO A — sessão autenticada', () {
    test(
      'obterMinhaIdentidade é a entrada, e o estado passa a expor o publicId',
      () async {
        expect(sessao.estado.fase, FaseIdentidade.naoAutenticado);
        expect(sessao.publicId, isNull);

        await logar('uid-A');
        // O LOGIN sozinho já dispara a busca. Nenhuma tela foi aberta.
        expect(fonte.chamadas, 1);
        expect(sessao.estado.fase, FaseIdentidade.carregando);

        fonte.responder('P0A1B2C3D4E5', apelido: 'Sônia');
        await Future<void>.delayed(Duration.zero);

        expect(sessao.estado.fase, FaseIdentidade.disponivel);
        // Exatamente o que o backend devolveu — nada normalizado, nada remontado.
        expect(sessao.publicId, 'P0A1B2C3D4E5');
        expect(sessao.estado.identidade!.apelido, 'Sônia');
        expect(sessao.estado.uid, 'uid-A');
      },
    );

    test(
      'a identidade se resolve sem nenhuma tela ter sido construída',
      () async {
        await logar('uid-A');
        fonte.responder('P0A1B2C3D4E5');
        await Future<void>.delayed(Duration.zero);
        // Não há `WidgetTester` neste teste: não existe árvore de widgets, logo
        // nenhum `initState` participou. Abrir Ranking não é pré-condição.
        expect(sessao.publicId, 'P0A1B2C3D4E5');
      },
    );
  });

  // =========================================================================
  // CASO E — ordem independente
  // =========================================================================
  group('CASO E — a ordem dos consumidores não altera a identidade', () {
    test('Ranking→Social e Social→Ranking chegam ao mesmo publicId', () async {
      await logar('uid-A');
      fonte.responder('P0A1B2C3D4E5');
      await Future<void>.delayed(Duration.zero);

      // "Ranking depois Social": dois consumidores lendo em sequência.
      final ordem1 = [sessao.publicId, sessao.publicId];
      // "Social depois Ranking": a ordem inversa, mesma sessão.
      final ordem2 = [sessao.publicId, sessao.publicId];

      expect(ordem1, ordem2);
      expect(ordem1.toSet(), {'P0A1B2C3D4E5'});
      // E nenhuma das leituras gerou consulta nova.
      expect(fonte.chamadas, 1);
    });

    test('garantirCarregada em qualquer ordem não muda o resultado', () async {
      await logar('uid-A');
      // Não se pode AGUARDAR antes de responder: a future só resolve quando o
      // teste soltar a resposta. Os pedidos são registrados primeiro.
      final ranking = sessao.garantirCarregada();
      final social = sessao.garantirCarregada();
      fonte.responder('P0A1B2C3D4E5');
      await Future.wait([ranking, social]);
      await sessao.garantirCarregada(); // "Perfil", depois de pronto

      expect(sessao.publicId, 'P0A1B2C3D4E5');
      expect(fonte.chamadas, 1);
    });
  });

  // =========================================================================
  // CASO F — deduplicação
  // =========================================================================
  group('CASO F — deduplicação', () {
    test('três consumidores simultâneos produzem UMA chamada', () async {
      await logar('uid-A');
      expect(fonte.chamadas, 1); // a do próprio login

      // Perfil, Ranking e Social pedem enquanto a primeira ainda está em voo.
      final f1 = sessao.garantirCarregada();
      final f2 = sessao.garantirCarregada();
      final f3 = sessao.garantirCarregada();

      expect(fonte.chamadas, 1, reason: 'nenhuma chamada redundante');
      expect(fonte.pendentes.length, 1);

      fonte.responder('P0A1B2C3D4E5');
      await Future.wait([f1, f2, f3]);

      expect(sessao.publicId, 'P0A1B2C3D4E5');
      expect(fonte.chamadas, 1);
    });

    test('o carregamento em andamento é COMPARTILHADO, não repetido', () async {
      await logar('uid-A');
      final a = sessao.garantirCarregada();
      final b = sessao.garantirCarregada();
      // Mesma future, literalmente — é o que "compartilhar o carregamento em
      // andamento" quer dizer.
      expect(identical(a, b), isTrue);
    });

    test('recarregar durante um voo não abre uma segunda chamada', () async {
      await logar('uid-A');
      sessao.recarregar();
      sessao.recarregar();
      expect(fonte.chamadas, 1);
    });
  });

  // =========================================================================
  // CASO G — cache de sessão
  // =========================================================================
  group('CASO G — cache de sessão em memória', () {
    test('navegar e voltar não reconsulta', () async {
      await logar('uid-A');
      fonte.responder('P0A1B2C3D4E5');
      await Future<void>.delayed(Duration.zero);
      expect(fonte.chamadas, 1);

      // "abrir Ranking, voltar, abrir Social, voltar, abrir Ranking de novo"
      for (var i = 0; i < 10; i++) {
        await sessao.garantirCarregada();
        expect(sessao.publicId, 'P0A1B2C3D4E5');
      }

      expect(fonte.chamadas, 1, reason: 'o cache de sessão serviu todas');
    });

    test(
      'reemissão do mesmo uid (refresh de token) não invalida o cache',
      () async {
        await logar('uid-A');
        fonte.responder('P0A1B2C3D4E5');
        await Future<void>.delayed(Duration.zero);

        await logar('uid-A'); // o stream de auth repete em renovação de token
        expect(fonte.chamadas, 1);
        expect(sessao.publicId, 'P0A1B2C3D4E5');
      },
    );
  });

  // =========================================================================
  // CASO H — logout
  // =========================================================================
  group('CASO H — logout', () {
    test('logout remove a identidade e o publicId da sessão', () async {
      await logar('uid-A');
      fonte.responder('P0A1B2C3D4E5');
      await Future<void>.delayed(Duration.zero);
      expect(sessao.publicId, 'P0A1B2C3D4E5');

      await logar(null);

      expect(sessao.estado.fase, FaseIdentidade.naoAutenticado);
      expect(sessao.publicId, isNull);
      expect(sessao.estado.identidade, isNull);
      expect(sessao.estado.uid, isNull);
      expect(sessao.estado.autenticado, isFalse);
    });

    test('depois do logout, garantirCarregada não consulta nada', () async {
      await logar('uid-A');
      fonte.responder('P0A1B2C3D4E5');
      await Future<void>.delayed(Duration.zero);
      await logar(null);

      await sessao.garantirCarregada();
      await sessao.recarregar();

      expect(
        fonte.chamadas,
        1,
        reason: 'sessão encerrada não busca identidade',
      );
      expect(sessao.publicId, isNull);
    });
  });

  // =========================================================================
  // CASO I — troca A → B
  // =========================================================================
  group('CASO I — troca de usuário A → B', () {
    test('B recebe a própria identidade e nunca a de A', () async {
      await logar('uid-A');
      fonte.responder('PAAAAAAAAAAA');
      await Future<void>.delayed(Duration.zero);
      expect(sessao.publicId, 'PAAAAAAAAAAA');

      await logar(null);
      // ENTRE OS DOIS LOGINS o publicId de A já não existe mais.
      expect(sessao.publicId, isNull);

      await logar('uid-B');
      // E no instante seguinte ao login de B, tampouco: B começa sem identidade,
      // não com a herdada.
      expect(sessao.publicId, isNull);
      expect(sessao.estado.uid, 'uid-B');

      fonte.responder('PBBBBBBBBBBB');
      await Future<void>.delayed(Duration.zero);

      expect(sessao.publicId, 'PBBBBBBBBBBB');
      expect(sessao.estado.uid, 'uid-B');
    });

    test(
      'troca direta A→B, sem logout intermediário, também não vaza',
      () async {
        await logar('uid-A');
        fonte.responder('PAAAAAAAAAAA');
        await Future<void>.delayed(Duration.zero);

        await logar('uid-B'); // troca de conta sem passar por deslogado
        expect(sessao.publicId, isNull, reason: 'o cache de A foi invalidado');
        expect(sessao.estado.uid, 'uid-B');

        fonte.responder('PBBBBBBBBBBB');
        await Future<void>.delayed(Duration.zero);
        expect(sessao.publicId, 'PBBBBBBBBBBB');
      },
    );
  });

  // =========================================================================
  // CASO J — resposta atrasada
  // =========================================================================
  group('CASO J — resposta atrasada de A não contamina B', () {
    test('o roteiro exato da OS: A pede, logout, B loga, A responde', () async {
      // 1. consulta da identidade de A iniciada
      await logar('uid-A');
      expect(fonte.chamadas, 1);
      final vooDeA = 0;

      // 2. logout
      await logar(null);

      // 3. login de B
      await logar('uid-B');
      expect(fonte.chamadas, 2);
      final vooDeB = 1;

      // 4. a resposta de A chega ATRASADA — depois de B já estar na sessão
      fonte.responder('PAAAAAAAAAAA', indice: vooDeA);
      await Future<void>.delayed(Duration.zero);

      // O estado de B permanece intacto: a resposta de A foi descartada.
      expect(sessao.estado.uid, 'uid-B');
      expect(
        sessao.publicId,
        isNull,
        reason: 'B ainda espera a própria identidade',
      );
      expect(sessao.estado.fase, FaseIdentidade.carregando);

      // E B continua conseguindo receber a dele.
      fonte.responder('PBBBBBBBBBBB', indice: vooDeB);
      await Future<void>.delayed(Duration.zero);
      expect(sessao.publicId, 'PBBBBBBBBBBB');
    });

    test(
      'resposta atrasada de A que chega depois de B já estar resolvido',
      () async {
        await logar('uid-A');
        await logar('uid-B');
        fonte.responder('PBBBBBBBBBBB', indice: 1);
        await Future<void>.delayed(Duration.zero);
        expect(sessao.publicId, 'PBBBBBBBBBBB');

        // A resposta zumbi de A chega agora.
        fonte.responder('PAAAAAAAAAAA', indice: 0);
        await Future<void>.delayed(Duration.zero);

        expect(
          sessao.publicId,
          'PBBBBBBBBBBB',
          reason: 'a identidade de B não foi sobrescrita',
        );
        expect(sessao.estado.uid, 'uid-B');
      },
    );

    test('falha atrasada de A não derruba a sessão de B', () async {
      await logar('uid-A');
      await logar('uid-B');
      fonte.responder('PBBBBBBBBBBB', indice: 1);
      await Future<void>.delayed(Duration.zero);

      fonte.falhar(indice: 0); // A falha, tarde demais para importar
      await Future<void>.delayed(Duration.zero);

      expect(sessao.estado.fase, FaseIdentidade.disponivel);
      expect(sessao.publicId, 'PBBBBBBBBBBB');
    });

    test('logout não é desfeito por uma resposta em voo', () async {
      await logar('uid-A');
      await logar(null);

      fonte.responder('PAAAAAAAAAAA', indice: 0);
      await Future<void>.delayed(Duration.zero);

      expect(sessao.estado.fase, FaseIdentidade.naoAutenticado);
      expect(
        sessao.publicId,
        isNull,
        reason: 'a sessão encerrada não ressuscita',
      );
    });
  });

  // =========================================================================
  // CASO K — falha transitória
  // =========================================================================
  group('CASO K — falha transitória', () {
    test(
      'o estado de erro é explícito e nenhum publicId é inventado',
      () async {
        await logar('uid-A');
        fonte.falhar();
        await Future<void>.delayed(Duration.zero);

        expect(sessao.estado.fase, FaseIdentidade.falha);
        expect(sessao.estado.falha!.motivo, MotivoFalhaIdentidade.indisponivel);
        expect(sessao.estado.falha!.transitoria, isTrue);
        expect(sessao.estado.podeTentarDeNovo, isTrue);

        // NADA foi fabricado: nem uid, nem string vazia, nem id provisório.
        expect(sessao.publicId, isNull);
        expect(sessao.estado.identidade, isNull);
        // A sessão autenticada SOBREVIVE à falha de identidade (§10).
        expect(sessao.estado.autenticado, isTrue);
        expect(sessao.estado.uid, 'uid-A');
      },
    );

    test(
      'depois da falha, garantirCarregada é inerte — rebuild não vira loop',
      () async {
        await logar('uid-A');
        fonte.falhar();
        await Future<void>.delayed(Duration.zero);
        expect(fonte.chamadas, 1);

        // Cem reconstruções de widget chamando o caminho de leitura/garantia.
        for (var i = 0; i < 100; i++) {
          await sessao.garantirCarregada();
        }

        expect(
          fonte.chamadas,
          1,
          reason: 'só o retry EXPLÍCITO tenta de novo, nunca o build',
        );
        expect(sessao.estado.fase, FaseIdentidade.falha);
      },
    );

    test('resposta sem publicId vira falha, e não identidade vazia', () async {
      // A trava de `IdentidadePublica.doWire`, no formato em que ela chega do
      // wire: sem o campo, não há identidade — e não há substituto.
      expect(
        () => IdentidadePublica.doWire(const {'criada': true}),
        throwsA(
          isA<FalhaIdentidade>().having(
            (e) => e.motivo,
            'motivo',
            MotivoFalhaIdentidade.respostaInvalida,
          ),
        ),
      );
      expect(
        () => IdentidadePublica.doWire(const {'publicId': ''}),
        throwsA(isA<FalhaIdentidade>()),
      );
      expect(
        () => IdentidadePublica.doWire(const {'publicId': 42}),
        throwsA(isA<FalhaIdentidade>()),
      );
    });

    test('falha não transitória não oferece retry', () async {
      await logar('uid-A');
      fonte.falhar(motivo: MotivoFalhaIdentidade.recusado);
      await Future<void>.delayed(Duration.zero);

      expect(sessao.estado.fase, FaseIdentidade.falha);
      expect(sessao.estado.podeTentarDeNovo, isFalse);
      expect(sessao.publicId, isNull);
    });
  });

  // =========================================================================
  // CASO L — retry
  // =========================================================================
  group('CASO L — retry', () {
    test('depois do erro, o retry explícito resolve a identidade', () async {
      await logar('uid-A');
      fonte.falhar();
      await Future<void>.delayed(Duration.zero);
      expect(sessao.estado.fase, FaseIdentidade.falha);

      final tentativa = sessao.recarregar();
      expect(fonte.chamadas, 2);
      expect(sessao.estado.fase, FaseIdentidade.carregando);

      fonte.responder('P0A1B2C3D4E5');
      await tentativa;

      expect(sessao.estado.fase, FaseIdentidade.disponivel);
      expect(sessao.publicId, 'P0A1B2C3D4E5');
      expect(sessao.estado.falha, isNull);
    });

    test(
      'dois retries seguidos não deixam duas requisições concorrentes',
      () async {
        await logar('uid-A');
        fonte.falhar();
        await Future<void>.delayed(Duration.zero);

        sessao.recarregar();
        sessao.recarregar();
        sessao.recarregar();

        expect(
          fonte.chamadas,
          2,
          reason: '1 do login + 1 do retry deduplicado',
        );
        expect(fonte.pendentes.where((c) => !c.isCompleted).length, 1);
      },
    );

    test(
      'retry que falha de novo volta a um estado de falha retentável',
      () async {
        await logar('uid-A');
        fonte.falhar();
        await Future<void>.delayed(Duration.zero);

        sessao.recarregar();
        fonte.falhar();
        await Future<void>.delayed(Duration.zero);

        expect(sessao.estado.fase, FaseIdentidade.falha);
        expect(sessao.estado.podeTentarDeNovo, isTrue);
        expect(sessao.publicId, isNull);
        expect(fonte.chamadas, 2);
      },
    );
  });

  // =========================================================================
  // CASO M — nenhum fallback para uid
  // =========================================================================
  group('CASO M — uid NÃO é substituto de publicId', () {
    test(
      'em toda fase sem identidade, publicId é null — nunca o uid',
      () async {
        // não autenticado
        expect(sessao.publicId, isNull);

        // autenticado, ainda carregando
        await logar('uid-A');
        expect(sessao.estado.uid, 'uid-A');
        expect(sessao.publicId, isNull);
        expect(sessao.publicId, isNot('uid-A'));

        // falhou
        fonte.falhar();
        await Future<void>.delayed(Duration.zero);
        expect(sessao.publicId, isNull);
        expect(sessao.publicId, isNot('uid-A'));

        // logout
        await logar(null);
        expect(sessao.publicId, isNull);
      },
    );

    test(
      'com identidade disponível, publicId é o do servidor e não o uid',
      () async {
        await logar('uid-A');
        fonte.responder('P0A1B2C3D4E5');
        await Future<void>.delayed(Duration.zero);

        expect(sessao.publicId, 'P0A1B2C3D4E5');
        expect(sessao.publicId, isNot(sessao.estado.uid));
        // E o publicId não é derivável do uid por fatia, prefixo ou sufixo.
        expect(sessao.publicId!.toUpperCase().contains('UID-A'), isFalse);
      },
    );

    test('apelido vazio não faz o uid virar nome nem identidade', () async {
      await logar('uid-A');
      fonte.responder('P0A1B2C3D4E5', apelido: '');
      await Future<void>.delayed(Duration.zero);

      expect(sessao.estado.identidade!.apelido, '');
      expect(sessao.estado.identidade!.apelido, isNot('uid-A'));
      expect(sessao.publicId, 'P0A1B2C3D4E5');
    });
  });

  // =========================================================================
  // Notificação — o que os consumidores observam
  // =========================================================================
  group('notificação do estado', () {
    test('cada transição relevante notifica exatamente uma vez', () async {
      var avisos = 0;
      sessao.addListener(() => avisos++);

      await logar('uid-A'); // naoCarregada + carregando
      final aposLogin = avisos;
      expect(aposLogin, greaterThan(0));

      fonte.responder('P0A1B2C3D4E5');
      await Future<void>.delayed(Duration.zero);
      expect(avisos, aposLogin + 1); // disponível

      await logar(null);
      expect(avisos, aposLogin + 2); // deslogado
    });

    test('resposta descartada NÃO notifica ninguém', () async {
      await logar('uid-A');
      await logar('uid-B');
      fonte.responder('PBBBBBBBBBBB', indice: 1);
      await Future<void>.delayed(Duration.zero);

      var avisos = 0;
      sessao.addListener(() => avisos++);

      fonte.responder('PAAAAAAAAAAA', indice: 0); // a zumbi de A
      await Future<void>.delayed(Duration.zero);

      expect(avisos, 0, reason: 'nenhuma tela é reconstruída por lixo');
    });
  });
}
