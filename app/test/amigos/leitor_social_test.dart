// leitor_social_test.dart — o leitor do grafo social, e as regras que ele
// existe para sustentar.
//
// A suíte está organizada pelas AFIRMAÇÕES da OS, e não pelos métodos da
// classe. Cada grupo abaixo é uma propriedade que, se quebrar, produz um defeito
// que o jogador vê:
//
//   * a tela aberta dez vezes emite UMA consulta;
//   * uma resposta atrasada não sobrescreve o que já está na tela;
//   * a lista de amigos de A não aparece para B;
//   * uma ação aceita SUBTRAI a linha e RELÊ a relação da autoridade;
//   * nada — em nenhum caminho — ADICIONA jogador a lista nenhuma;
//   * as ações desenhadas nunca são deduzidas do estado.

import 'package:flutter_test/flutter_test.dart';

import 'package:buraco_master_vip/amigos/estado_social.dart';
import 'package:buraco_master_vip/amigos/leitor_social.dart';

import 'bancada_social.dart';

void main() {
  late TransporteSocialFalso t;
  late LeitorSocial leitor;

  setUp(() {
    t = TransporteSocialFalso();
    leitor = LeitorSocial(transporte: t);
  });

  tearDown(() => leitor.dispose());

  // =========================================================================
  // Carga e deduplicação
  // =========================================================================
  group('carga — abrir a tela não é perguntar de novo', () {
    test(
      '`garantir` consulta uma vez; as nove seguintes não consultam',
      () async {
        t.respostaAmigos = paginaFalsa([jogadorFalso('P1', apelido: 'Bia')]);
        await leitor.garantir(QualLista.amigos);
        for (var i = 0; i < 9; i++) {
          await leitor.garantir(QualLista.amigos);
        }
        expect(t.chamadasDe('listarAmigos'), 1);
        expect(leitor.amigos.itens.single.apelido, 'Bia');
      },
    );

    test('três "tentar de novo" simultâneos viram UMA chamada', () async {
      // O retry é idempotente por deduplicação de voo, e não por sorte de
      // timing: sem isso, três toques rápidos abrem três chamadas e a última a
      // chegar decide o que fica na tela.
      t.manual = true;
      final a = leitor.recarregar(QualLista.amigos);
      final b = leitor.recarregar(QualLista.amigos);
      final c = leitor.recarregar(QualLista.amigos);
      expect(t.chamadasDe('listarAmigos'), 1);
      t.responder(0, paginaFalsa([jogadorFalso('P1')]));
      await Future.wait([a, b, c]);
      expect(t.chamadasDe('listarAmigos'), 1);
    });

    test('listas diferentes são pedidos concorrentes legítimos', () async {
      // A deduplicação é POR LISTA. Um contador único faria abrir "Recebidos"
      // cancelar a carga de "Amigos" que ainda estava em voo.
      t.manual = true;
      final a = leitor.garantir(QualLista.amigos);
      final r = leitor.garantir(QualLista.recebidas);
      expect(t.chamadasDe('listarAmigos'), 1);
      expect(t.chamadasDe('listarRecebidas'), 1);
      t.responder(1, paginaFalsa([jogadorFalso('PR')]));
      t.responder(0, paginaFalsa([jogadorFalso('PA')]));
      await Future.wait([a, r]);
      expect(leitor.amigos.itens.single.publicId, 'PA');
      expect(leitor.recebidas.itens.single.publicId, 'PR');
    });

    test('lista vazia CONFIRMADA é diferente de lista não carregada', () async {
      // Sem a fase, "você ainda não tem amigos" apareceria também durante o
      // carregamento e depois de uma falha — três situações, uma frase, e duas
      // delas mentindo.
      expect(leitor.amigos.fase, FaseSocial.naoCarregada);
      expect(leitor.amigos.vaziaEConfirmada, isFalse);
      await leitor.garantir(QualLista.amigos);
      expect(leitor.amigos.fase, FaseSocial.pronta);
      expect(leitor.amigos.vaziaEConfirmada, isTrue);
    });
  });

  // =========================================================================
  // Respostas atrasadas
  // =========================================================================
  group('resposta vencida — quem chega por último não é quem manda', () {
    test('a resposta do pedido antigo é descartada', () async {
      t.manual = true;
      final antigo = leitor.recarregar(QualLista.amigos);
      // Um recarregar novo, enquanto o primeiro ainda voa. Como há voo em
      // curso, o leitor devolve o MESMO future — então forço a situação
      // trocando a sessão, que é o caminho real em que dois voos coexistem.
      leitor.aoMudarSessao(1);
      final novo = leitor.recarregar(QualLista.amigos);
      expect(t.chamadasDe('listarAmigos'), 2);

      // O ANTIGO chega DEPOIS do novo — a ordem que produz o defeito.
      t.responder(1, paginaFalsa([jogadorFalso('PNOVO')]));
      await novo;
      t.responder(0, paginaFalsa([jogadorFalso('PVELHO')]));
      await antigo;

      expect(
        leitor.amigos.itens.single.publicId,
        'PNOVO',
        reason: 'a resposta da sessão anterior sobrescreveu a atual',
      );
    });

    test(
      'falhar no "carregar mais" NÃO derruba a lista que está na tela',
      () async {
        t.respostaAmigos = paginaFalsa([
          jogadorFalso('P1'),
        ], proximoCursor: 'c1');
        await leitor.garantir(QualLista.amigos);
        expect(leitor.amigos.temMais, isTrue);

        t.proximaFalha = const FalhaSocial(MotivoFalhaSocial.indisponivel);
        await leitor.carregarMais(QualLista.amigos);

        expect(leitor.amigos.fase, FaseSocial.pronta);
        expect(leitor.amigos.itens.single.publicId, 'P1');
        expect(leitor.amigos.carregandoMais, isFalse);
      },
    );

    test('`carregarMais` manda o cursor OPACO, exatamente como veio', () async {
      t.respostaAmigos = paginaFalsa([
        jogadorFalso('P1'),
      ], proximoCursor: 'W1lhIiwiUDEiXQ');
      await leitor.garantir(QualLista.amigos);
      t.respostaAmigos = paginaFalsa([jogadorFalso('P2')]);
      await leitor.carregarMais(QualLista.amigos);

      final pedido = t.chamadas.lastWhere((c) => c.metodo == 'listarAmigos');
      expect(pedido.cursor, 'W1lhIiwiUDEiXQ');
      expect(leitor.amigos.itens.map((e) => e.publicId), ['P1', 'P2']);
    });

    test('um RECARREGAR substitui a página; não concatena', () async {
      // Concatenar num recarregar deixaria na tela, para sempre, quem foi
      // removido no servidor — nenhuma concatenação subtrai.
      t.respostaAmigos = paginaFalsa([jogadorFalso('P1'), jogadorFalso('P2')]);
      await leitor.garantir(QualLista.amigos);
      t.respostaAmigos = paginaFalsa([jogadorFalso('P1')]);
      await leitor.recarregar(QualLista.amigos);
      expect(leitor.amigos.itens.map((e) => e.publicId), ['P1']);
    });
  });

  // =========================================================================
  // Troca de sessão
  // =========================================================================
  group('troca de sessão — nada de A sobra para B', () {
    test('as três listas e a busca são esvaziadas', () async {
      t.respostaAmigos = paginaFalsa([jogadorFalso('P1')]);
      t.respostaDaBusca = const ResultadosDeBusca(
        termo: 'ana',
        itens: [],
        truncado: false,
        modo: ModoDeBusca.prefixo,
      );
      await leitor.garantir(QualLista.amigos);
      await leitor.buscar('ana');
      expect(leitor.amigos.itens, isNotEmpty);
      expect(leitor.busca.resultados, isNotNull);

      leitor.aoMudarSessao(1);

      expect(leitor.amigos.itens, isEmpty);
      expect(leitor.amigos.fase, FaseSocial.naoCarregada);
      expect(leitor.busca.resultados, isNull);
      expect(leitor.busca.termo, '');
    });

    test('a mesma geração não reinicia nada', () async {
      t.respostaAmigos = paginaFalsa([jogadorFalso('P1')]);
      await leitor.garantir(QualLista.amigos);
      leitor.aoMudarSessao(0);
      expect(leitor.amigos.itens, isNotEmpty);
    });

    test('a vista de UM jogador em voo não atravessa a troca', () async {
      // Sem limpar `_vistasEmVoo`, um pedido da conta NOVA sobre o mesmo
      // publicId receberia, por deduplicação, o `null` da conta velha — e a
      // faixa social ficaria em branco sem motivo.
      t.manual = true;
      final velha = leitor.vistaDe('P1');
      leitor.aoMudarSessao(1);
      final nova = leitor.vistaDe('P1');
      expect(t.chamadasDe('verPerfil'), 2, reason: 'a nova reusou o voo velho');

      t.responder(0, resultadoFalso('P1', relacao: RelacaoSocial.amigos));
      t.responder(1, resultadoFalso('P1', relacao: RelacaoSocial.nenhuma));
      expect(
        await velha,
        isNull,
        reason: 'a resposta da conta que saiu passou',
      );
      expect((await nova)!.relacao, RelacaoSocial.nenhuma);
    });
  });

  // =========================================================================
  // Busca
  // =========================================================================
  group('busca — o termo, o vencido e o vazio', () {
    test('termo vazio não gasta chamada', () async {
      await leitor.buscar('   ');
      expect(t.chamadasDe('buscar'), 0);
      expect(leitor.busca.fase, FaseSocial.naoCarregada);
    });

    test('o termo vai APARADO, mas não normalizado', () async {
      // Aparar borda é higiene do campo de texto. Dobrar acento ou baixar caixa
      // seria uma segunda `chaveDeBusca`, e a busca deixaria de encontrar o que
      // a gravação indexou no dia em que as duas divergissem.
      await leitor.buscar('  Ana Lúcia  ');
      expect(t.chamadas.single.termo, 'Ana Lúcia');
    });

    test(
      'os resultados anteriores FICAM enquanto a nova consulta corre',
      () async {
        t.respostaDaBusca = ResultadosDeBusca(
          termo: 'an',
          itens: [resultadoFalso('P1', apelido: 'Ana')],
          truncado: false,
          modo: ModoDeBusca.prefixo,
        );
        await leitor.buscar('an');
        expect(leitor.busca.resultados!.itens, hasLength(1));

        t.manual = true;
        final voo = leitor.buscar('ana');
        expect(leitor.busca.emVoo, isTrue);
        expect(
          leitor.busca.resultados!.itens,
          hasLength(1),
          reason: 'a lista sumiu e voltou a cada letra',
        );
        t.responder(0, null);
        await voo;
      },
    );

    test('a resposta de um termo abandonado não aparece', () async {
      t.manual = true;
      final primeira = leitor.buscar('an');
      final segunda = leitor.buscar('ana');

      // A segunda chega primeiro; a primeira chega depois — e não pode vencer.
      t.responder(1, null);
      await segunda;
      t.responder(0, null);
      await primeira;

      expect(leitor.busca.termo, 'ana');
      expect(leitor.busca.resultados!.termo, 'ana');
    });

    test('"ninguém encontrado" só existe com a fase pronta', () async {
      expect(leitor.busca.semResultados, isFalse);
      t.proximaFalha = const FalhaSocial(MotivoFalhaSocial.indisponivel);
      await leitor.buscar('ana');
      expect(leitor.busca.fase, FaseSocial.falha);
      expect(
        leitor.busca.semResultados,
        isFalse,
        reason: 'uma busca que FALHOU não pode afirmar que não há ninguém',
      );
    });

    test('limpar a busca descarta o que estava em voo', () async {
      t.manual = true;
      final voo = leitor.buscar('ana');
      leitor.limparBusca();
      t.responder(0, null);
      await voo;
      expect(leitor.busca.resultados, isNull);
      expect(leitor.busca.fase, FaseSocial.naoCarregada);
    });
  });

  // =========================================================================
  // Ações — o coração da OS
  // =========================================================================
  group('ação aceita — subtrai, relê, e NUNCA adiciona', () {
    setUp(() {
      t.respostaRecebidas = paginaFalsa([
        jogadorFalso('P1', apelido: 'Bia'),
        jogadorFalso('P2', apelido: 'Caio'),
      ]);
    });

    test('aceitar SUBTRAI da lista de recebidas', () async {
      await leitor.garantir(QualLista.recebidas);
      await leitor.agir(AcaoSocial.aceitarSolicitacao, 'P1');
      expect(leitor.recebidas.itens.map((e) => e.publicId), ['P2']);
    });

    test('aceitar NÃO adiciona ninguém à lista de amigos', () async {
      // A regra que impede o grafo local de existir. Quem entra na lista de
      // amigos é a próxima leitura de `listarAmigos` — e é por isso que a lista
      // fica VENCIDA em vez de remendada.
      t.respostaAmigos = paginaFalsa([jogadorFalso('P9', apelido: 'Ana')]);
      await leitor.garantir(QualLista.amigos);
      await leitor.garantir(QualLista.recebidas);
      final antes = t.chamadasDe('listarAmigos');

      await leitor.agir(AcaoSocial.aceitarSolicitacao, 'P1');

      expect(leitor.amigos.itens.map((e) => e.publicId), [
        'P9',
      ], reason: 'o leitor inseriu um amigo por conta própria');
      expect(
        leitor.amigos.fase,
        FaseSocial.naoCarregada,
        reason: 'a lista não foi marcada como vencida',
      );
      expect(
        t.chamadasDe('listarAmigos'),
        antes,
        reason: 'vencer a lista não pode, por si, disparar consulta',
      );

      // E quem volta à aba consulta de novo — é o `garantir` da tela.
      await leitor.garantir(QualLista.amigos);
      expect(t.chamadasDe('listarAmigos'), antes + 1);
    });

    test('a vista devolvida vem da AUTORIDADE, e não do desfecho', () async {
      // O desfecho traz o estado do BANCO (`amigos`), que não conhece bloqueio
      // nem sanção. Aqui o banco diz "amigos" e a autoridade diz "indisponível"
      // — e é a autoridade que tem de chegar à tela.
      t.respostaDaAcao = const DesfechoSocial(
        repeticao: false,
        estado: 'amigos',
      );
      t.perfis['P1'] = resultadoFalso(
        'P1',
        relacao: RelacaoSocial.indisponivel,
        acoes: const [],
      );
      await leitor.garantir(QualLista.recebidas);
      final r = await leitor.agir(AcaoSocial.aceitarSolicitacao, 'P1');

      expect(r.desfecho.estado, 'amigos');
      expect(r.vista!.relacao, RelacaoSocial.indisponivel);
      expect(r.vista!.acoes, isEmpty);
    });

    test(
      'a releitura que falha vira "não sei" — nunca uma relação deduzida',
      () async {
        await leitor.garantir(QualLista.recebidas);

        // A AÇÃO PASSA e a RELEITURA FALHA — a única ordem que interessa aqui.
        // Em modo manual, o voo 0 é a ação e o voo 1 é o `verPerfilPublico` que
        // vem depois dela.
        t.manual = true;
        final voo = leitor.agir(AcaoSocial.recusarSolicitacao, 'P1');
        t.responder(0, null);
        // Um passe do laço de eventos para que `agir` retome e emita a releitura.
        await Future<void>.delayed(Duration.zero);
        t.falhar(1, const FalhaSocial(MotivoFalhaSocial.indisponivel));
        final r = await voo;

        expect(
          r.vista,
          isNull,
          reason:
              'sem resposta da autoridade, a relação foi deduzida do desfecho',
        );
        // E a subtração aconteceu MESMO ASSIM: a ação foi aceita, e a linha que
        // ficasse na tela seria um botão respondendo `repeticao` para sempre.
        expect(leitor.recebidas.itens.map((e) => e.publicId), ['P2']);
      },
    );

    test('`repeticao` chega como sucesso, e não como erro', () async {
      t.respostaDaAcao = const DesfechoSocial(
        repeticao: true,
        estado: 'amigos',
      );
      final r = await leitor.agir(AcaoSocial.adicionarAmigo, 'P1');
      expect(r.repeticao, isTrue);
    });

    test('a ação recusada PROPAGA a falha — não some em silêncio', () async {
      t.proximaFalha = const FalhaSocial(
        MotivoFalhaSocial.regraDeNegocio,
        'limiteDeAmigos',
      );
      await expectLater(
        leitor.agir(AcaoSocial.adicionarAmigo, 'P1'),
        throwsA(
          isA<FalhaSocial>().having(
            (e) => e.recusa,
            'recusa',
            'limiteDeAmigos',
          ),
        ),
      );
    });

    test('publicId vazio nem sai do aparelho', () async {
      await expectLater(
        leitor.agir(AcaoSocial.adicionarAmigo, '   '),
        throwsA(isA<FalhaSocial>()),
      );
      expect(t.totalDeChamadas, 0);
    });

    test('`adicionarAmigo` não subtrai de lista nenhuma', () async {
      // Ela CRIA uma pendência enviada, e criar é o que o leitor se proíbe de
      // fazer sem passar pela autoridade.
      t.respostaEnviadas = paginaFalsa([jogadorFalso('PX')]);
      await leitor.garantir(QualLista.enviadas);
      await leitor.agir(AcaoSocial.adicionarAmigo, 'P1');
      expect(leitor.enviadas.itens.map((e) => e.publicId), ['PX']);
    });

    test('a linha da BUSCA é trocada pela vista nova da autoridade', () async {
      // "Estado da amizade refletido de volta na UI", na tela de descoberta.
      t.respostaDaBusca = ResultadosDeBusca(
        termo: 'bia',
        itens: [
          resultadoFalso(
            'P1',
            apelido: 'Bia',
            relacao: RelacaoSocial.nenhuma,
            acoes: const [AcaoSocial.adicionarAmigo],
          ),
          resultadoFalso('P2', apelido: 'Biana'),
        ],
        truncado: false,
        modo: ModoDeBusca.prefixo,
      );
      await leitor.buscar('bia');
      t.perfis['P1'] = resultadoFalso(
        'P1',
        apelido: 'Bia',
        relacao: RelacaoSocial.solicitacaoEnviada,
        acoes: const [AcaoSocial.cancelarSolicitacao],
      );

      await leitor.agir(AcaoSocial.adicionarAmigo, 'P1');

      final itens = leitor.busca.resultados!.itens;
      expect(
        itens,
        hasLength(2),
        reason: 'a lista de resultados mudou de tamanho',
      );
      expect(itens[0].relacao, RelacaoSocial.solicitacaoEnviada);
      expect(itens[0].acoes, [AcaoSocial.cancelarSolicitacao]);
      // E o vizinho NÃO foi tocado.
      expect(itens[1].relacao, RelacaoSocial.nenhuma);
      expect(itens[1].acoes, [AcaoSocial.adicionarAmigo]);
    });
  });

  // =========================================================================
  // Vista de um jogador
  // =========================================================================
  group('vistaDe — a relação de UM, sem cache', () {
    test(
      'dois pedidos simultâneos do mesmo id compartilham a chamada',
      () async {
        t.manual = true;
        final a = leitor.vistaDe('P1');
        final b = leitor.vistaDe('P1');
        expect(t.chamadasDe('verPerfil'), 1);
        t.responder(0, resultadoFalso('P1', relacao: RelacaoSocial.amigos));
        expect((await a)!.relacao, RelacaoSocial.amigos);
        expect((await b)!.relacao, RelacaoSocial.amigos);
      },
    );

    test('pedidos SEQUENCIAIS consultam de novo — não há cache', () async {
      // Uma relação guardada é um botão que afirma uma permissão que pode já
      // não valer. As listas têm cache; a relação não tem, e a diferença é
      // deliberada.
      await leitor.vistaDe('P1');
      await leitor.vistaDe('P1');
      expect(t.chamadasDe('verPerfil'), 2);
    });

    test('id vazio não consulta', () async {
      expect(await leitor.vistaDe('  '), isNull);
      expect(t.totalDeChamadas, 0);
    });
  });

  group('presença, indicação e convites — estado remoto, nunca inventado', () {
    test(
      'presença publica a preferência remota e offline invalida a aba',
      () async {
        t.respostaOnline = paginaFalsa([jogadorFalso('P1')]);
        await leitor.garantir(QualLista.online);
        t.respostaAparecerOffline = true;

        await leitor.atualizarPresenca();
        expect(leitor.aparecerOffline, isTrue);

        await leitor.definirAparecerOffline(false);
        expect(leitor.aparecerOffline, isFalse);
        expect(leitor.online.fase, FaseSocial.naoCarregada);
        expect(t.chamadasDe('definirAparecerOffline'), 1);
      },
    );

    test('indicação apara o código e vazio nem sai do aparelho', () async {
      await leitor.registrarIndicacao('  P0ABCDEFGHJKM  ');
      expect(
        t.chamadas.lastWhere((c) => c.metodo == 'registrarIndicacao').termo,
        'P0ABCDEFGHJKM',
      );
      await expectLater(
        leitor.registrarIndicacao('   '),
        throwsA(isA<FalhaSocial>()),
      );
      expect(t.chamadasDe('registrarIndicacao'), 1);
    });

    test(
      'responder convite é autoritativo e subtrai só o convite respondido',
      () async {
        final remetente = jogadorFalso('P1', apelido: 'Bia');
        t.respostaConvites = [
          ConviteMesa(
            conviteId: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
            codigo: 'BURACO-1234',
            tipoMesa: 'privada',
            expiraEm: DateTime.utc(2030),
            remetente: remetente,
          ),
          ConviteMesa(
            conviteId: 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
            codigo: 'BURACO-5678',
            tipoMesa: 'privada',
            expiraEm: DateTime.utc(2030),
            remetente: remetente,
          ),
        ];
        await leitor.carregarConvitesMesa();
        expect(leitor.convitesMesa.itens, hasLength(2));

        final resposta = await leitor.responderConviteMesa(
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          aceitar: true,
        );
        expect(resposta.aceito, isTrue);
        expect(
          leitor.convitesMesa.itens.single.conviteId,
          'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
        );
        expect(t.chamadasDe('responderConviteMesa'), 1);
      },
    );
  });
}
