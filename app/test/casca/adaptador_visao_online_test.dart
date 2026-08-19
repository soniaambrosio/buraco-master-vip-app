// adaptador_visao_online_test.dart — a fronteira entre o fio e a tela.
//
// O que se prova aqui é RECUSA, principalmente. Um adaptador que aceita tudo
// não precisa de teste: ele nunca falha. O risco desta camada é o oposto —
// aceitar demais e desenhar uma mesa que o servidor não descreveu.
//
// Os casos se organizam em quatro perguntas:
//
//   1. a visão íntegra vira o estado certo, com a dupla RELATIVA a quem lê?
//   2. a visão quebrada é recusada em vez de completada com zero?
//   3. carta alheia consegue atravessar por algum caminho?
//   4. as capacidades espelham `validarVez` do servidor?

import 'package:flutter_test/flutter_test.dart';

import 'package:buraco_master_vip/casca/mesa_online/estado_mesa_online.dart';

import 'bancada_online.dart';

/// Lê uma visão e exige que ela tenha sido aceita como partida.
EstadoMesaOnline aceita(Map<String, dynamic> visao, {int? assento}) {
  final r = AdaptadorVisaoOnline.ler(visao, assentoDaConexao: assento);
  expect(
    r,
    isA<VisaoDeJogo>(),
    reason: r is VisaoRecusada ? 'recusada em ${r.campo}: ${r.motivo}' : null,
  );
  return (r as VisaoDeJogo).estado;
}

/// Lê uma visão e exige que ela tenha sido recusada no campo [campo].
VisaoRecusada recusa(
  Map<String, dynamic> visao,
  String campo, {
  int? assento,
}) {
  final r = AdaptadorVisaoOnline.ler(visao, assentoDaConexao: assento);
  expect(r, isA<VisaoRecusada>());
  final recusada = r as VisaoRecusada;
  expect(recusada.campo, campo);
  expect(recusada.motivo, isNotEmpty);
  return recusada;
}

void main() {
  // =========================================================================
  // 1 — a visão íntegra
  // =========================================================================
  group('visão íntegra', () {
    test('o lobby é reconhecido como lobby', () {
      expect(
        AdaptadorVisaoOnline.ler(visaoDeLobby(), assentoDaConexao: 0),
        isA<VisaoDeLobby>(),
      );
    });

    test('a visão de jogo vira estado completo', () {
      final e = aceita(visaoDeJogo(), assento: 0);

      expect(e.meuAssento, 0);
      expect(e.modalidade, 'aberto');
      expect(e.metaPontos, 3000);
      expect(e.rodada, 1);
      expect(e.suaVez, isTrue);
      expect(e.jaComprou, isFalse);
      expect(e.minhaMao, hasLength(3));
      expect(e.minhaMao.first.id, 'c1');
      expect(e.assentos, hasLength(4));
      expect(e.monteQtd, 60);
      expect(e.mortosQtd, 2);
      expect(e.lixoTopo?.id, 'L1');
      expect(e.encerrada, isFalse);
    });

    test('o curinga é lido de eh_coringa E de coringa', () {
      // `eh_coringa` é a forma da visão de assento; `coringa` é a de
      // `cartaPublica`. As duas são do servidor.
      final comSublinhado = CartaOnline.talvezDe({
        'id': 'x',
        'naipe': null,
        'valor': 'JOKER',
        'eh_coringa': true,
      });
      final semSublinhado = CartaOnline.talvezDe({
        'id': 'y',
        'naipe': 'paus',
        'valor': '2',
        'coringa': true,
      });
      expect(comSublinhado!.coringa, isTrue);
      expect(comSublinhado.naipe, isNull);
      expect(semSublinhado!.coringa, isTrue);
    });

    test('a modalidade fechada não publica o lixo inteiro, e isso não é vazio', () {
      final e = aceita(visaoDeJogo(), assento: 0);
      expect(
        e.lixoAberto,
        isNull,
        reason: 'nulo quer dizer "não é visível", nunca "está vazio"',
      );

      final aberta = aceita(
        visaoDeJogo(lixoAberto: [carta('L1', 'ouros', '5')]),
        assento: 0,
      );
      expect(aberta.lixoAberto, hasLength(1));
    });
  });

  // =========================================================================
  // 2 — a dupla relativa: o defeito que o resumo em texto tinha
  // =========================================================================
  group('a dupla é relativa a quem lê', () {
    test('no assento 0 a minha dupla é nos', () {
      final e = aceita(visaoDeJogo(voceAssento: 0), assento: 0);
      expect(e.minhaDupla, Dupla.nos);
      expect(e.meusPontos, 120);
      expect(e.pontosAdversarios, 45);
    });

    test('no assento 1 a minha dupla é eles — e o placar vira junto', () {
      final e = aceita(visaoDeJogo(voceAssento: 1), assento: 1);
      expect(e.minhaDupla, Dupla.eles);
      expect(
        e.meusPontos,
        45,
        reason:
            'o resumo anterior desenhava placar.nos como "Nós" para todo '
            'mundo, e mostrava o placar do adversário a quem sentasse nos '
            'assentos ímpares',
      );
      expect(e.pontosAdversarios, 120);
    });

    test('os jogos baixados também viram com a dupla', () {
      final noZero = aceita(visaoDeJogo(voceAssento: 0), assento: 0);
      expect(noZero.meusJogos, hasLength(1));
      expect(noZero.jogosAdversarios, isEmpty);

      final noUm = aceita(visaoDeJogo(voceAssento: 1), assento: 1);
      expect(noUm.meusJogos, isEmpty);
      expect(noUm.jogosAdversarios, hasLength(1));
    });
  });

  // =========================================================================
  // 3 — a recusa
  // =========================================================================
  group('visão inválida é recusada, não completada', () {
    test('visão ausente', () {
      final r = AdaptadorVisaoOnline.ler(null, assentoDaConexao: 0);
      expect(r, isA<VisaoRecusada>());
      expect((r as VisaoRecusada).campo, 'visao');
    });

    test('sem assento declarado', () {
      final v = visaoDeJogo()..remove('voceAssento');
      recusa(v, 'voceAssento');
    });

    test('assento da visão diferente do assento da conexão', () {
      // Este é o caso perigoso: a visão é ÍNTEGRA, só que de outra pessoa.
      recusa(visaoDeJogo(voceAssento: 2), 'voceAssento', assento: 0);
    });

    test('mão ilegível', () {
      recusa(visaoDeJogo(suaMao: null)..['suaMao'] = 'nada', 'suaMao');
    });

    test('uma carta quebrada invalida a mão inteira', () {
      final v = visaoDeJogo();
      v['suaMao'] = [
        carta('c1', 'copas', '7'),
        {'naipe': 'copas'}, // sem id e sem valor
      ];
      recusa(
        v,
        'suaMao',
      );
    });

    test('placar sem uma das duplas', () {
      recusa(visaoDeJogo(placar: {'nos': 10}), 'placar');
    });

    test('placar com texto no lugar do número', () {
      recusa(visaoDeJogo(placar: {'nos': '10', 'eles': 0}), 'placar');
    });

    test('contagens negativas ou ausentes', () {
      final semMonte = visaoDeJogo()..remove('monteQtd');
      recusa(semMonte, 'monteQtd');
      recusa(visaoDeJogo(monteQtd: -1), 'monteQtd');
      recusa(visaoDeJogo(mortosQtd: -3), 'mortosQtd');
    });

    test('sem modalidade, sem rodada, sem vez', () {
      recusa(visaoDeJogo()..remove('modalidade'), 'modalidade');
      recusa(visaoDeJogo()..remove('rodada'), 'rodada');
      recusa(visaoDeJogo()..remove('vez'), 'vez');
    });

    test('lugares da mesa incompletos', () {
      recusa(visaoDeJogo(assentos: []), 'assentos');
      recusa(
        visaoDeJogo(
          assentos: [
            {'apelido': 'Ana'}, // sem qtdCartas
          ],
        ),
        'assentos',
      );
    });

    test('jogos baixados ilegíveis', () {
      recusa(visaoDeJogo(jogosDupla: {'nos': []}), 'jogosDupla');
      recusa(
        visaoDeJogo(
          jogosDupla: {
            'nos': [
              ['isto não é carta'],
            ],
            'eles': [],
          },
        ),
        'jogosDupla',
      );
    });

    test('topo do lixo presente mas ilegível', () {
      final v = visaoDeJogo();
      v['lixoTopo'] = {'naipe': 'copas'}; // sem id nem valor
      recusa(v, 'lixoTopo');
    });

    test('topo do lixo ausente é lixo vazio, e isso é legítimo', () {
      final v = visaoDeJogo(lixoTopo: null);
      v['lixoTopo'] = null;
      final e = aceita(v, assento: 0);
      expect(e.lixoTopo, isNull);
    });

    test('a recusa não cita conteúdo da visão', () {
      // O motivo vai para a tela. Se ele repetisse o valor recebido, a
      // mensagem de erro viraria o vazamento que o resto do arquivo evita.
      final v = visaoDeJogo();
      v['suaMao'] = [
        carta('id-secreto-da-carta', 'copas', '7'),
        {'lixo': 1},
      ];
      final r = recusa(v, 'suaMao');
      expect(r.motivo.contains('id-secreto-da-carta'), isFalse);
    });
  });

  // =========================================================================
  // 4 — o que NÃO atravessa
  // =========================================================================
  group('carta alheia não atravessa', () {
    test('do outro assento só vem a contagem', () {
      final e = aceita(visaoDeJogo(), assento: 0);
      final outro = e.assentos[1];
      expect(outro.qtdCartas, 11);
      expect(outro.ehVoce, isFalse);
      // `AssentoOnline` não tem campo de cartas: não existe expressão que
      // devolva a mão do assento 1.
      expect(e.minhaMao, hasLength(3));
    });

    test('um campo com a mão alheia na visão é simplesmente ignorado', () {
      // Um servidor com defeito (ou uma resposta forjada) pode mandar mais do
      // que devia. O adaptador é uma LISTA DE PERMISSÃO: o que ele não lê não
      // chega à tela.
      final v = visaoDeJogo();
      v['maos'] = [
        [carta('secreta-1', 'copas', 'A')],
        [carta('secreta-2', 'paus', 'K')],
      ];
      v['monte'] = [carta('secreta-3', 'ouros', 'Q')];
      final e = aceita(v, assento: 0);

      final idsVisiveis = <String>{
        ...e.minhaMao.map((c) => c.id),
        ...e.jogosPorDupla.values.expand((js) => js).expand((j) => j).map(
          (c) => c.id,
        ),
        if (e.lixoTopo != null) e.lixoTopo!.id,
        ...?e.lixoAberto?.map((c) => c.id),
      };
      expect(idsVisiveis.contains('secreta-1'), isFalse);
      expect(idsVisiveis.contains('secreta-2'), isFalse);
      expect(idsVisiveis.contains('secreta-3'), isFalse);
    });

    test('jogadorId e avatar não entram no estado de apresentação', () {
      final v = visaoDeJogo(
        assentos: [
          {
            'apelido': 'Ana',
            'tipo': 'humano',
            'dupla': 'nos',
            'qtdCartas': 3,
            'ehVoce': true,
            'jogadorId': 'uid-secreto',
            'avatarTipo': 'foto',
            'avatarId': 'abc',
          },
          {'apelido': 'B', 'tipo': 'bot', 'dupla': 'eles', 'qtdCartas': 11},
          {'apelido': 'C', 'tipo': 'humano', 'dupla': 'nos', 'qtdCartas': 9},
          {'apelido': 'D', 'tipo': 'bot', 'dupla': 'eles', 'qtdCartas': 11},
        ],
      );
      final e = aceita(v, assento: 0);
      expect(e.assentos.first.apelido, 'Ana');
      // Não há onde guardar `jogadorId` — a classe não tem o campo.
      expect(e.assentos.first.ehBot, isFalse);
      expect(e.assentos[1].ehBot, isTrue);
    });
  });

  // =========================================================================
  // 5 — as capacidades espelham validarVez
  // =========================================================================
  group('capacidades', () {
    test('minha vez, ainda não comprei: compro e não descarto', () {
      final e = aceita(visaoDeJogo(suaVez: true, jaComprou: false));
      final c = e.capacidades(conectado: true);
      expect(c.podeComprar, isTrue);
      expect(c.podeBaixar, isFalse);
      expect(c.podeDescartar, isFalse);
    });

    test('minha vez, já comprei: baixo e descarto, não compro de novo', () {
      final e = aceita(visaoDeJogo(suaVez: true, jaComprou: true));
      final c = e.capacidades(conectado: true);
      expect(c.podeComprar, isFalse);
      expect(c.podeBaixar, isTrue);
      expect(c.podeDescartar, isTrue);
    });

    test('vez de outro: nada', () {
      final e = aceita(visaoDeJogo(suaVez: false, jaComprou: false));
      final c = e.capacidades(conectado: true);
      expect(c.podeComprar, isFalse);
      expect(c.podeBaixar, isFalse);
      expect(c.podeDescartar, isFalse);
    });

    test('rodada ou partida encerrada barram tudo, mesmo sendo minha vez', () {
      final rodada = aceita(visaoDeJogo(suaVez: true, rodadaEncerrada: true));
      expect(rodada.capacidades(conectado: true).podeComprar, isFalse);

      final partida = aceita(visaoDeJogo(suaVez: true, encerrada: true));
      expect(partida.capacidades(conectado: true).podeComprar, isFalse);
    });

    test('sem conexão autenticada não há capacidade nenhuma', () {
      final e = aceita(visaoDeJogo(suaVez: true, jaComprou: true));
      final c = e.capacidades(conectado: false);
      expect(c.podeComprar, isFalse);
      expect(c.podeBaixar, isFalse);
      expect(c.podeDescartar, isFalse);
      expect(c.conectado, isFalse);
    });

    test('a obrigação do topo destaca a carta, mas não bloqueia o descarte', () {
      final e = aceita(
        visaoDeJogo(suaVez: true, jaComprou: true, precisaUsarTopo: 'L1'),
      );
      expect(e.precisaUsarTopo, 'L1');
      expect(
        e.capacidades(conectado: true).podeDescartar,
        isTrue,
        reason:
            'quem julga a obrigação é o servidor; um bloqueio local seria uma '
            'segunda opinião sobre a regra, e a errada travaria a pessoa',
      );
    });
  });

  // =========================================================================
  // 6 — ordem entre visões
  // =========================================================================
  group('ordem', () {
    test('sem versão declarada, a mais nova é a última que chegou', () {
      final a = aceita(visaoDeJogo(rodada: 1));
      final b = aceita(visaoDeJogo(rodada: 2));
      expect(b.substitui(a), isTrue);
      expect(a.substitui(b), isTrue);
      expect(
        a.versaoEstado,
        isNull,
        reason:
            'o servidor de 16a692b não manda versaoEstado, e a ausência não '
            'vira número inventado',
      );
    });

    test('com versão declarada, a maior substitui', () {
      final v1 = aceita(visaoDeJogo(versaoEstado: 1));
      final v2 = aceita(visaoDeJogo(versaoEstado: 2));
      expect(v2.substitui(v1), isTrue);
    });

    test('com versão declarada, a menor é recusada', () {
      final v1 = aceita(visaoDeJogo(versaoEstado: 1));
      final v2 = aceita(visaoDeJogo(versaoEstado: 2));
      expect(v1.substitui(v2), isFalse);
    });

    test('versão igual passa — é a retransmissão depois de reconectar', () {
      final a = aceita(visaoDeJogo(versaoEstado: 7));
      final b = aceita(visaoDeJogo(versaoEstado: 7));
      expect(b.substitui(a), isTrue);
    });

    test('a primeira visão sempre entra', () {
      final e = aceita(visaoDeJogo(versaoEstado: 99));
      expect(e.substitui(null), isTrue);
    });
  });
}
