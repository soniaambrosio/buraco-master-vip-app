// ordem_da_visao_test.dart — a matriz de ordem e deduplicação da visão.
//
// O que está sob julgamento aqui é a POLÍTICA: dado um envelope e o que já
// aconteceu nesta conexão, o que se faz com ele. Os casos de ponta a ponta —
// transporte real, socket falso, tela montada — moram em `mesa_online_test.dart`
// e provam que esta política está de fato no caminho.
//
// A separação é útil por um motivo concreto: dois dos três defeitos que a prova
// negativa da OS injeta (marcador reiniciado no lugar errado, deduplicação que
// engole o evento terminal) são invisíveis numa tela e evidentes aqui.
//
// O contrato do servidor está em `buraco-servidor`, ref
// `claude/versionamento-visao-autoritativa-v1`, SHA
// 7e7572b3471bcec2a6968e6084f56dd407cef601 — `docs/VERSIONAMENTO-VISAO-V1.md`.

import 'package:flutter_test/flutter_test.dart';

import 'package:buraco_master_vip/services/ordem_da_visao.dart';

// ===========================================================================
// Envelopes — o carimbo é IRMÃO de `visao`
// ===========================================================================

Map<String, dynamic> visao({bool encerrada = false, int rodada = 1}) => {
  'voceAssento': 0,
  'rodada': rodada,
  'encerrada': encerrada,
};

Map<String, dynamic> envelope({
  int? versaoEstado,
  String? eventoId,
  bool encerrada = false,
  int rodada = 1,
}) => {
  'tipo': 'estado',
  'visao': visao(encerrada: encerrada, rodada: rodada),
  if (versaoEstado != null) 'versaoEstado': versaoEstado,
  if (eventoId != null) 'eventoId': eventoId,
};

/// Avalia e devolve só a conduta — a maior parte dos casos só quer isso.
CondutaDaVisao conduta(OrdemDaVisao o, Map<String, dynamic> e) =>
    o.avaliar(e).conduta;

void main() {
  // =========================================================================
  // 1 — Leitura do carimbo
  // =========================================================================
  group('leitura do carimbo', () {
    test('o par completo é lido do envelope, não da visão', () {
      final lido = OrdemDaVisao.lerCarimbo(
        envelope(versaoEstado: 7, eventoId: 'ev-7'),
      );
      expect(lido, isA<VisaoVersionada>());
      expect((lido as VisaoVersionada).versaoEstado, 7);
      expect(lido.eventoId, 'ev-7');
    });

    test('carimbo DENTRO da visão não é carimbo', () {
      // O servidor nunca faz isto. Se alguém fizer, não vale — o campo lá
      // dentro passaria pela lista de permissão do espectador, e por isso o
      // contrato o mantém fora.
      final lido = OrdemDaVisao.lerCarimbo({
        'tipo': 'estado',
        'visao': {'voceAssento': 0, 'versaoEstado': 99, 'eventoId': 'ev-99'},
      });
      expect(lido, isA<VisaoSemCarimbo>());
    });

    test('nenhum dos dois campos: envelope legado', () {
      expect(OrdemDaVisao.lerCarimbo(envelope()), isA<VisaoSemCarimbo>());
    });

    test('(0, null) é "não há estado autoritativo", e não a primeira versão', () {
      final lido = OrdemDaVisao.lerCarimbo({
        'tipo': 'estado',
        'visao': visao(),
        'versaoEstado': 0,
        'eventoId': null,
      });
      expect(lido, isA<VisaoSemEstadoAutoritativo>());
    });

    test('versão sem evento é carimbo quebrado, não legado', () {
      final lido = OrdemDaVisao.lerCarimbo(envelope(versaoEstado: 4));
      expect(lido, isA<VisaoComCarimboIlegivel>());
      expect((lido as VisaoComCarimboIlegivel).campo, 'eventoId');
    });

    test('evento sem versão é carimbo quebrado', () {
      final lido = OrdemDaVisao.lerCarimbo(envelope(eventoId: 'ev-1'));
      expect(lido, isA<VisaoComCarimboIlegivel>());
      expect((lido as VisaoComCarimboIlegivel).campo, 'versaoEstado');
    });

    test('versão de tipo errado ou negativa é ilegível', () {
      for (final v in <Object>['7', 7.5, -1]) {
        final lido = OrdemDaVisao.lerCarimbo({
          'tipo': 'estado',
          'visao': visao(),
          'versaoEstado': v,
          'eventoId': 'ev',
        });
        expect(lido, isA<VisaoComCarimboIlegivel>(), reason: 'versão $v');
      }
    });

    test('evento vazio ou de tipo errado é ilegível', () {
      for (final id in <Object>['', 123, <String>[]]) {
        final lido = OrdemDaVisao.lerCarimbo({
          'tipo': 'estado',
          'visao': visao(),
          'versaoEstado': 3,
          'eventoId': id,
        });
        expect(lido, isA<VisaoComCarimboIlegivel>(), reason: 'evento $id');
      }
    });
  });

  // =========================================================================
  // 2 — Ordem
  // =========================================================================
  group('ordem', () {
    test('a primeira visão versionada entra', () {
      final o = OrdemDaVisao();
      expect(
        conduta(o, envelope(versaoEstado: 1, eventoId: 'a')),
        CondutaDaVisao.aceitar,
      );
      expect(o.versaoAceita, 1);
    });

    test('sequência crescente entra inteira', () {
      final o = OrdemDaVisao();
      for (var v = 1; v <= 5; v++) {
        expect(
          conduta(o, envelope(versaoEstado: v, eventoId: 'ev-$v')),
          CondutaDaVisao.aceitar,
          reason: 'versão $v',
        );
      }
      expect(o.versaoAceita, 5);
    });

    test('10 → 12 → 11: a atrasada é descartada e não move o marcador', () {
      final o = OrdemDaVisao();
      expect(
        conduta(o, envelope(versaoEstado: 10, eventoId: 'a')),
        CondutaDaVisao.aceitar,
      );
      expect(
        conduta(o, envelope(versaoEstado: 12, eventoId: 'b')),
        CondutaDaVisao.aceitar,
      );
      expect(
        conduta(o, envelope(versaoEstado: 11, eventoId: 'c')),
        CondutaDaVisao.atrasada,
      );
      expect(
        o.versaoAceita,
        12,
        reason: 'a atrasada não pode puxar o relógio para trás',
      );
      expect(o.eventoAceito, 'b');
    });

    test('duplicata exata não reaplica', () {
      final o = OrdemDaVisao();
      o.avaliar(envelope(versaoEstado: 3, eventoId: 'x'));
      final d = o.avaliar(envelope(versaoEstado: 3, eventoId: 'x'));
      expect(d.conduta, CondutaDaVisao.duplicada);
      expect(d.aplicaSnapshot, isFalse);
      expect(
        d.temAutoridade,
        isTrue,
        reason: 'ela não muda o estado, mas continua falando pelo servidor',
      );
    });

    test('mesma versão com outro eventoId não substitui o estado', () {
      final o = OrdemDaVisao();
      o.avaliar(envelope(versaoEstado: 3, eventoId: 'x'));
      final d = o.avaliar(envelope(versaoEstado: 3, eventoId: 'y'));
      expect(d.conduta, CondutaDaVisao.inconsistente);
      expect(d.aplicaSnapshot, isFalse);
      expect(d.temAutoridade, isFalse);
      expect(
        o.eventoAceito,
        'x',
        reason: 'entre duas emissões que se dizem o mesmo estado, adivinhar '
            'seria inventar autoridade — o marcador fica como estava',
      );
    });

    test('metadados malformados não contaminam o marcador nem o estado', () {
      final o = OrdemDaVisao();
      o.avaliar(envelope(versaoEstado: 8, eventoId: 'bom'));
      for (final quebrado in [
        envelope(versaoEstado: 99), // sem evento
        envelope(eventoId: 'só-o-evento'), // sem versão
        {
          'tipo': 'estado',
          'visao': visao(),
          'versaoEstado': 'noventa',
          'eventoId': 'z',
        },
      ]) {
        final d = o.avaliar(quebrado);
        expect(d.conduta, CondutaDaVisao.ilegivel);
        expect(d.temAutoridade, isFalse);
      }
      expect(o.versaoAceita, 8);
      expect(o.eventoAceito, 'bom');
    });

    test('(0, null) é descartado sem mexer no marcador', () {
      final o = OrdemDaVisao();
      o.avaliar(envelope(versaoEstado: 5, eventoId: 'a'));
      final d = o.avaliar({
        'tipo': 'estado',
        'visao': visao(),
        'versaoEstado': 0,
        'eventoId': null,
      });
      expect(d.conduta, CondutaDaVisao.semEstadoAutoritativo);
      expect(d.temAutoridade, isFalse);
      expect(o.versaoAceita, 5);
    });

    test('a decisão nunca fabrica versão nem eventoId', () {
      final o = OrdemDaVisao();
      for (final d in [
        o.avaliar(envelope()), // legado
        o.avaliar(envelope(versaoEstado: 99)), // ilegível
      ]) {
        expect(d.versaoEstado, isNull);
        expect(d.eventoId, isNull);
      }
    });
  });

  // =========================================================================
  // 3 — Modo legado
  // =========================================================================
  group('modo legado', () {
    test('sem carimbo nenhum, tudo entra — é o servidor de produção de hoje', () {
      final o = OrdemDaVisao();
      expect(conduta(o, envelope(rodada: 1)), CondutaDaVisao.aceitar);
      expect(conduta(o, envelope(rodada: 2)), CondutaDaVisao.aceitar);
      expect(
        o.versaoAceita,
        isNull,
        reason: 'sem número no fio, não se inventa um',
      );
    });

    test('visão sem carimbo DEPOIS de uma carimbada é recusada', () {
      final o = OrdemDaVisao();
      expect(
        conduta(o, envelope(versaoEstado: 2, eventoId: 'a')),
        CondutaDaVisao.aceitar,
      );
      final d = o.avaliar(envelope());
      expect(d.conduta, CondutaDaVisao.legadaTardia);
      expect(d.temAutoridade, isFalse);
      expect(o.versaoAceita, 2);
    });

    test('a tolerância volta quando a projeção reinicia', () {
      // Não é indulgência: reiniciar a projeção é dizer "o retrato que eu tinha
      // não vale mais". A geração seguinte recomeça a negociação do zero.
      final o = OrdemDaVisao();
      o.avaliar(envelope(versaoEstado: 2, eventoId: 'a'));
      o.reiniciarProjecao();
      expect(conduta(o, envelope()), CondutaDaVisao.aceitar);
    });

    test('legado e carimbado na mesma projeção: o carimbado fecha a porta', () {
      final o = OrdemDaVisao();
      expect(conduta(o, envelope()), CondutaDaVisao.aceitar);
      expect(
        conduta(o, envelope(versaoEstado: 40, eventoId: 'a')),
        CondutaDaVisao.aceitar,
      );
      expect(conduta(o, envelope()), CondutaDaVisao.legadaTardia);
    });
  });

  // =========================================================================
  // 4 — Escopo do marcador
  // =========================================================================
  group('escopo do marcador', () {
    test('reiniciar a projeção aceita o reenvio da versão vigente', () {
      // É a reconexão. O servidor NÃO cria versão nova para quem volta (a
      // reconexão não muta a sala), então ele reenvia a vigente. Com o marcador
      // sobrevivendo, isso viraria "duplicata" e a mesa ficaria em branco.
      final o = OrdemDaVisao();
      o.avaliar(envelope(versaoEstado: 12, eventoId: 'v12'));
      o.reiniciarProjecao();
      final d = o.avaliar(envelope(versaoEstado: 12, eventoId: 'v12'));
      expect(d.conduta, CondutaDaVisao.aceitar);
      expect(d.aplicaSnapshot, isTrue);
    });

    test('mesa nova pode começar com versão numericamente MENOR', () {
      // Outra sala tem contador próprio. Recusar o 3 por ser menor que o 50 da
      // sala anterior deixaria a pessoa numa mesa que nunca desenha.
      final o = OrdemDaVisao();
      o.avaliar(envelope(versaoEstado: 50, eventoId: 'sala-A'));
      o.reiniciarMesa();
      expect(
        conduta(o, envelope(versaoEstado: 3, eventoId: 'sala-B')),
        CondutaDaVisao.aceitar,
      );
    });

    test('dentro da MESMA geração o marcador não reinicia sozinho', () {
      // O defeito que a prova negativa injeta: qualquer reinício silencioso
      // aqui faria a próxima atrasada passar.
      final o = OrdemDaVisao();
      for (var v = 1; v <= 20; v++) {
        o.avaliar(envelope(versaoEstado: v, eventoId: 'ev-$v'));
      }
      expect(o.versaoAceita, 20);
      expect(
        conduta(o, envelope(versaoEstado: 19, eventoId: 'ev-19')),
        CondutaDaVisao.atrasada,
      );
      expect(
        conduta(o, envelope(versaoEstado: 1, eventoId: 'ev-1')),
        CondutaDaVisao.atrasada,
      );
    });
  });

  // =========================================================================
  // 5 — Encerramento: snapshot e efeito são coisas diferentes
  // =========================================================================
  group('encerramento', () {
    test('a visão não terminal não despacha nada', () {
      final o = OrdemDaVisao();
      final d = o.avaliar(envelope(versaoEstado: 1, eventoId: 'a'));
      expect(o.talvezEncerramento(d, visao()), isNull);
    });

    test('um único envelope terminal aplica o snapshot E despacha o efeito', () {
      // O defeito que isto pega: deduplicar o efeito perguntando ao MARCADOR
      // ("já vi esta versão?"). Ele acabou de ser comprometido por `avaliar`,
      // então responderia SIM — e o encerramento seria engolido pela própria
      // aplicação do retrato que o trouxe.
      final o = OrdemDaVisao();
      final env = envelope(versaoEstado: 13, eventoId: 'fim-13', encerrada: true);
      final d = o.avaliar(env);
      expect(d.aplicaSnapshot, isTrue);
      final aviso = o.talvezEncerramento(d, env['visao'] as Map<String, dynamic>);
      expect(aviso, isNotNull);
      expect(aviso!.eventoId, 'fim-13');
      expect(aviso.versaoEstado, 13);
    });

    test('encerramento retransmitido não despacha de novo', () {
      final o = OrdemDaVisao();
      final env = envelope(versaoEstado: 13, eventoId: 'fim-13', encerrada: true);
      final v = env['visao'] as Map<String, dynamic>;

      final primeira = o.avaliar(env);
      expect(o.talvezEncerramento(primeira, v), isNotNull);

      final segunda = o.avaliar(env);
      expect(segunda.conduta, CondutaDaVisao.duplicada);
      expect(o.talvezEncerramento(segunda, v), isNull);
    });

    test('o efeito NÃO é descartado só por a visão já ter sido aplicada', () {
      // §6 da OS, ao pé da letra. O snapshot já entrou (`avaliar` devolveu
      // `aceitar` e o marcador andou); o efeito ainda não saiu. A retransmissão
      // chega como duplicata — e tem de despachar, porque o livro dos efeitos
      // está limpo para aquele `eventoId`.
      //
      // Um `if (duplicada) return;` antes do passo terminal derruba este caso, e
      // é exatamente o terceiro defeito da prova negativa.
      final o = OrdemDaVisao();
      final env = envelope(versaoEstado: 13, eventoId: 'fim-13', encerrada: true);
      final v = env['visao'] as Map<String, dynamic>;

      final aplicada = o.avaliar(env);
      expect(aplicada.aplicaSnapshot, isTrue); // snapshot aplicado…
      // …e o efeito NÃO foi despachado aqui.

      final reenvio = o.avaliar(env);
      expect(reenvio.conduta, CondutaDaVisao.duplicada);
      expect(reenvio.aplicaSnapshot, isFalse);
      expect(
        o.talvezEncerramento(reenvio, v),
        isNotNull,
        reason: 'a duplicata não reaplica o retrato, mas ainda declara o fim',
      );
    });

    test('reconexão reaplica o retrato terminal sem repetir o efeito', () {
      // A assimetria dos dois livros, medida. O marcador reinicia (senão a mesa
      // fica em branco); o livro dos efeitos não (senão o resultado aparece
      // duas vezes para quem só caiu e voltou).
      final o = OrdemDaVisao();
      final env = envelope(versaoEstado: 13, eventoId: 'fim-13', encerrada: true);
      final v = env['visao'] as Map<String, dynamic>;

      final antes = o.avaliar(env);
      expect(o.talvezEncerramento(antes, v), isNotNull);

      o.reiniciarProjecao();

      final depois = o.avaliar(env);
      expect(
        depois.aplicaSnapshot,
        isTrue,
        reason: 'a mesa precisa voltar a ser desenhada',
      );
      expect(
        o.talvezEncerramento(depois, v),
        isNull,
        reason: 'mas o diálogo, a navegação e o som já aconteceram',
      );
    });

    test('sair da mesa libera o efeito da PRÓXIMA partida', () {
      final o = OrdemDaVisao();
      final a = envelope(versaoEstado: 13, eventoId: 'fim-A', encerrada: true);
      o.talvezEncerramento(o.avaliar(a), a['visao'] as Map<String, dynamic>);

      o.reiniciarMesa();

      final b = envelope(versaoEstado: 4, eventoId: 'fim-B', encerrada: true);
      expect(
        o.talvezEncerramento(o.avaliar(b), b['visao'] as Map<String, dynamic>),
        isNotNull,
      );
    });

    test('visão atrasada ou ilegível não despacha encerramento', () {
      final o = OrdemDaVisao();
      o.avaliar(envelope(versaoEstado: 20, eventoId: 'a'));

      final atrasada = envelope(
        versaoEstado: 5,
        eventoId: 'velho',
        encerrada: true,
      );
      expect(
        o.talvezEncerramento(
          o.avaliar(atrasada),
          atrasada['visao'] as Map<String, dynamic>,
        ),
        isNull,
      );

      final quebrada = envelope(versaoEstado: 30, encerrada: true);
      expect(
        o.talvezEncerramento(
          o.avaliar(quebrada),
          quebrada['visao'] as Map<String, dynamic>,
        ),
        isNull,
      );
    });

    test('no modo legado o efeito sai uma vez, sem eventoId inventado', () {
      final o = OrdemDaVisao();
      final env = envelope(encerrada: true);
      final v = env['visao'] as Map<String, dynamic>;

      final aviso = o.talvezEncerramento(o.avaliar(env), v);
      expect(aviso, isNotNull);
      expect(aviso!.eventoId, isNull);
      expect(aviso.versaoEstado, isNull);

      expect(o.talvezEncerramento(o.avaliar(env), v), isNull);
    });

    test('dois encerramentos distintos despacham dois avisos', () {
      // O UUID é sorteado e nunca reaproveitado para outra mutação. Duas
      // emissões terminais diferentes são dois fins.
      final o = OrdemDaVisao();
      for (final id in ['fim-1', 'fim-2']) {
        final env = envelope(
          versaoEstado: id == 'fim-1' ? 10 : 11,
          eventoId: id,
          encerrada: true,
        );
        expect(
          o.talvezEncerramento(
            o.avaliar(env),
            env['visao'] as Map<String, dynamic>,
          ),
          isNotNull,
          reason: id,
        );
      }
    });
  });

  // =========================================================================
  // 6 — Colisão nominal: versaoEstado ≠ versaoEstadoFinal
  // =========================================================================
  group('versaoEstadoFinal não participa da ordenação', () {
    test('o número de rodada do encerramento não ordena coisa nenhuma', () {
      // `versaoEstadoFinal` já existia no envelope de encerramento do servidor,
      // vale `jogo.rodada` e conta RODADAS. Ordenar por ele faria a mesa
      // descartar toda emissão que não virasse a rodada — quase todas.
      final o = OrdemDaVisao();
      o.avaliar(envelope(versaoEstado: 40, eventoId: 'a'));

      final comFinalAlto = {
        'tipo': 'estado',
        'visao': visao(),
        'versaoEstado': 41,
        'eventoId': 'b',
        'versaoEstadoFinal': 9999,
      };
      expect(conduta(o, comFinalAlto), CondutaDaVisao.aceitar);
      expect(o.versaoAceita, 41);

      final comFinalBaixo = {
        'tipo': 'estado',
        'visao': visao(),
        'versaoEstado': 40,
        'eventoId': 'a',
        'versaoEstadoFinal': 1,
      };
      expect(
        conduta(o, comFinalBaixo),
        CondutaDaVisao.atrasada,
        reason: 'quem decide é versaoEstado (40 < 41), não versaoEstadoFinal',
      );
    });

    test('versaoEstadoFinal sozinho não é carimbo', () {
      final lido = OrdemDaVisao.lerCarimbo({
        'tipo': 'estado',
        'visao': visao(),
        'versaoEstadoFinal': 7,
      });
      expect(
        lido,
        isA<VisaoSemCarimbo>(),
        reason: 'ele não é a versão da visão, e não pode ser lido como uma',
      );
    });
  });
}
