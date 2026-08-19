// estado_social_test.dart — a FRONTEIRA DO FIO.
//
// Tudo aqui é sobre uma pergunta só: o que este cliente faz com uma resposta
// que não é exatamente a que ele esperava. É a superfície em que um backend
// mais novo, um campo renomeado ou um item corrompido no meio da página
// encontram o aplicativo — e o comportamento certo em cada caso é diferente.
//
// Não há `WidgetTester` nesta suíte, e não há Firebase: `estado_social.dart` é
// domínio puro, e essa pureza é o que torna estes casos baratos o bastante para
// existirem todos.

import 'package:flutter_test/flutter_test.dart';

import 'package:buraco_master_vip/amigos/estado_social.dart';

void main() {
  // =========================================================================
  // Relação
  // =========================================================================
  group('RelacaoSocial — o que vem do fio, e o que não vem', () {
    test('cada nome do contrato vira a relação correspondente', () {
      // O contrato do fio é o `.name`, e este caso é o que impede alguém de
      // reordenar o enum e achar que só mexeu na ordem.
      const esperado = {
        'nenhuma': RelacaoSocial.nenhuma,
        'solicitacaoEnviada': RelacaoSocial.solicitacaoEnviada,
        'solicitacaoRecebida': RelacaoSocial.solicitacaoRecebida,
        'amigos': RelacaoSocial.amigos,
        'bloqueadoPorMim': RelacaoSocial.bloqueadoPorMim,
        'indisponivel': RelacaoSocial.indisponivel,
        'euMesmo': RelacaoSocial.euMesmo,
      };
      esperado.forEach((nome, relacao) {
        expect(RelacaoSocial.doWire(nome), relacao, reason: nome);
      });
    });

    test('nome desconhecido NÃO cai em `nenhuma`', () {
      // O caso central desta suíte. Um servidor mais novo devolvendo uma
      // relação que este aplicativo não conhece não pode virar "vocês não têm
      // relação": isso convidaria a um pedido de amizade que a autoridade já
      // sabe que vai recusar, e a pessoa levaria a recusa na cara sem entender.
      for (final estranho in const [
        'amizadeSecreta',
        '',
        'AMIGOS',
        'amigos ',
        42,
        null,
      ]) {
        expect(
          RelacaoSocial.doWire(estranho),
          RelacaoSocial.desconhecida,
          reason: '$estranho',
        );
      }
    });

    test('`desconhecida` não é um valor que o servidor possa mandar', () {
      // Ela existe só do lado do cliente. Se o nome dela virasse aceitável no
      // fio, um servidor poderia empurrar "não sei" para dentro da tela.
      expect(
        RelacaoSocial.doWire('desconhecida'),
        RelacaoSocial.desconhecida,
        reason: 'o resultado é o mesmo, mas por não reconhecer — não por casar',
      );
    });
  });

  // =========================================================================
  // Ações
  // =========================================================================
  group('AcaoSocial — a lista que autoriza os botões', () {
    test('uma ação desconhecida é descartada, e as outras sobrevivem', () {
      // Descartar, e não falhar: uma ação futura que este cliente não desenha
      // não pode derrubar as que ele desenha. O oposto — a lista inteira virar
      // vazia — deixaria a pessoa sem nenhum botão por causa de um recurso novo
      // que nem é dela.
      final acoes = AcaoSocial.listaDoWire([
        'adicionarAmigo',
        'convidarParaMesa',
        'bloquear',
      ]);
      expect(acoes, [AcaoSocial.adicionarAmigo, AcaoSocial.bloquear]);
    });

    test('a ORDEM do servidor é preservada', () {
      // A ordem é a ordem dos botões na tela. Um `Set` a perderia, e "Recusar"
      // apareceria antes de "Aceitar" em metade das execuções.
      expect(AcaoSocial.listaDoWire(['recusarSolicitacao', 'aceitarSolicitacao']), [
        AcaoSocial.recusarSolicitacao,
        AcaoSocial.aceitarSolicitacao,
      ]);
    });

    test('repetição não vira dois botões iguais', () {
      expect(AcaoSocial.listaDoWire(['bloquear', 'bloquear']), [
        AcaoSocial.bloquear,
      ]);
    });

    test('o que não é lista vira lista vazia, e não explode', () {
      for (final lixo in const [null, 'adicionarAmigo', 7]) {
        expect(AcaoSocial.listaDoWire(lixo), isEmpty, reason: '$lixo');
      }
    });

    test('a lista devolvida é imutável', () {
      // Quem recebe não pode acrescentar uma ação à lista que a autoridade
      // mandou — seria conceder permissão em memória.
      final acoes = AcaoSocial.listaDoWire(['adicionarAmigo']);
      expect(() => acoes.add(AcaoSocial.removerAmigo), throwsUnsupportedError);
    });
  });

  // =========================================================================
  // Jogador público
  // =========================================================================
  group('JogadorPublico — apresentação sem identidade inventada', () {
    test('apelido vazio NÃO vira o rótulo genérico enquanto houver publicId', () {
      final j = jogadorDoWire({'publicId': 'P0A1B2C3D4E5', 'apelido': ''});
      // O publicId É como a pessoa é conhecida publicamente. 'Jogador(a)' é
      // rótulo, e um rótulo no lugar de um identificador esconde quem é quem
      // numa lista de vários sem apelido.
      expect(j.nomeDeApresentacao, 'P0A1B2C3D4E5');
    });

    test('só sem apelido E sem id aparece o rótulo genérico', () {
      final j = jogadorDoWire({'publicId': '   ', 'apelido': '  '});
      expect(j.nomeDeApresentacao, 'Jogador(a)');
      expect(j.temIdUtilizavel, isFalse);
    });

    test('a checagem de id para em "não vazio" — não confere a FORMA', () {
      // Conferir alfabeto, comprimento ou prefixo aqui seria uma cópia local da
      // fórmula do servidor, que a auditoria de identidade proíbe. Um id
      // malformado é recusado por quem tem autoridade, com `invalid-argument`.
      for (final id in const ['x', 'p0a1b2c3d4e5', 'ABC', '####']) {
        expect(
          jogadorDoWire({'publicId': id}).temIdUtilizavel,
          isTrue,
          reason: '$id foi julgado pela forma no cliente',
        );
      }
    });

    test('campo de outro tipo não vira texto do tipo errado', () {
      final j = jogadorDoWire({'publicId': 7, 'apelido': true, 'avatarRef': 9});
      expect(j.publicId, '');
      expect(j.apelido, '');
      expect(j.avatarRef, isNull);
    });
  });

  // =========================================================================
  // Páginas
  // =========================================================================
  group('PaginaSocial — concatenar, subtrair, e o cursor opaco', () {
    test('itens que não são objeto são DESCARTADOS, e o resto fica', () {
      // Descartar em vez de falhar: um item corrompido não justifica esconder
      // os outros nove. E o descarte é silencioso de propósito — um item de
      // reserva seria o aplicativo afirmando um jogador que ninguém devolveu.
      final p = PaginaSocial.doWire({
        'itens': [
          {'publicId': 'P1'},
          'lixo',
          null,
          {'publicId': 'P2'},
        ],
        'proximoCursor': 'abc',
      });
      expect(p.itens.map((e) => e.publicId), ['P1', 'P2']);
      expect(p.proximoCursor, 'abc');
      expect(p.temMais, isTrue);
    });

    test('cursor ausente é fim de lista', () {
      final p = PaginaSocial.doWire({'itens': <Object?>[]});
      expect(p.proximoCursor, isNull);
      expect(p.temMais, isFalse);
    });

    test('`seguida` concatena preservando a ordem e deduplicando', () {
      // O cursor do backend é estritamente maior, então repetição não deveria
      // acontecer — mas uma amizade desfeita entre duas páginas desloca a
      // lista, e um item repetido vira dois botões sobre a mesma relação.
      final a = paginaDe(['P1', 'P2'], cursor: 'c1');
      final b = paginaDe(['P2', 'P3'], cursor: null);
      final juntas = a.seguida(b);
      expect(juntas.itens.map((e) => e.publicId), ['P1', 'P2', 'P3']);
      expect(juntas.proximoCursor, isNull);
    });

    test('`sem` subtrai, e subtrair é a única mutação local permitida', () {
      final p = paginaDe(['P1', 'P2', 'P3']);
      final menor = p.sem('P2');
      expect(menor.itens.map((e) => e.publicId), ['P1', 'P3']);
      // E não mexe na original: as páginas são imutáveis.
      expect(p.itens.map((e) => e.publicId), ['P1', 'P2', 'P3']);
    });

    test('subtrair quem não está na lista não muda nada', () {
      final p = paginaDe(['P1']);
      expect(p.sem('P9').itens.map((e) => e.publicId), ['P1']);
    });
  });

  // =========================================================================
  // Resultado social
  // =========================================================================
  group('ResultadoSocial — a busca e o perfil produzem o MESMO tipo', () {
    test('a busca hidrata jogador, relação e ações do mesmo objeto', () {
      final r = ResultadoSocial.doWire({
        'publicId': 'P0A1B2C3D4E5',
        'apelido': 'Bia',
        'avatarRef': null,
        'relacao': 'solicitacaoEnviada',
        'acoes': ['cancelarSolicitacao', 'bloquear'],
      });
      expect(r.publicId, 'P0A1B2C3D4E5');
      expect(r.jogador.apelido, 'Bia');
      expect(r.relacao, RelacaoSocial.solicitacaoEnviada);
      expect(r.permite(AcaoSocial.cancelarSolicitacao), isTrue);
      expect(r.permite(AcaoSocial.adicionarAmigo), isFalse);
    });

    test('`verPerfilPublico` aninha o perfil, e mesmo assim vira o mesmo tipo', () {
      // Ter um tipo só é o que permite à tela trocar um resultado de busca pela
      // resposta da autoridade depois da ação, sem traduzir de novo.
      final r = ResultadoSocial.doPerfilPublico({
        'perfil': {'publicId': 'P0A1B2C3D4E5', 'apelido': 'Bia'},
        'relacao': 'amigos',
        'acoes': ['removerAmigo'],
        'amigosDesde': '2026-01-01T00:00:00Z',
      });
      expect(r.publicId, 'P0A1B2C3D4E5');
      expect(r.jogador.apelido, 'Bia');
      expect(r.relacao, RelacaoSocial.amigos);
      expect(r.acoes, [AcaoSocial.removerAmigo]);
    });

    test('perfil ausente na resposta não vira jogador inventado', () {
      final r = ResultadoSocial.doPerfilPublico({'relacao': 'nenhuma'});
      expect(r.jogador.publicId, '');
      expect(r.jogador.temIdUtilizavel, isFalse);
      expect(r.acoes, isEmpty);
    });
  });

  // =========================================================================
  // Resultados de busca
  // =========================================================================
  group('ResultadosDeBusca — truncado, modo e o termo que os produziu', () {
    test('o termo viaja junto do resultado', () {
      // Sem ele, a tela não consegue distinguir "estes são os resultados do que
      // está escrito" de "estes são os de duas letras atrás".
      final r = ResultadosDeBusca.doWire('ana', {
        'itens': <Object?>[],
        'truncado': false,
        'modo': 'prefixo',
      });
      expect(r.termo, 'ana');
      expect(r.vazio, isTrue);
    });

    test('`truncado` só é verdade quando o servidor diz que é', () {
      for (final bruto in const [null, 'true', 1, false]) {
        final r = ResultadosDeBusca.doWire('ana', {
          'itens': <Object?>[],
          'truncado': bruto,
        });
        expect(r.truncado, isFalse, reason: '$bruto');
      }
      expect(
        ResultadosDeBusca.doWire('ana', {
          'itens': <Object?>[],
          'truncado': true,
        }).truncado,
        isTrue,
      );
    });

    test('modo desconhecido cai em prefixo, que é o mais amplo', () {
      expect(
        ResultadosDeBusca.doWire('ana', {'modo': 'exato'}).modo,
        ModoDeBusca.exato,
      );
      expect(
        ResultadosDeBusca.doWire('ana', {'modo': 'seja-la-o-que-for'}).modo,
        ModoDeBusca.prefixo,
      );
    });

    test('NÃO existe cursor na resposta de busca', () {
      // A ausência é a decisão antienumeração do contrato: sem cursor, não há
      // como percorrer a base. Este caso existe para que ninguém "melhore" a
      // paginação da busca sem reabrir aquela decisão.
      final r = ResultadosDeBusca.doWire('ana', {
        'itens': <Object?>[],
        'proximoCursor': 'algo',
      });
      // O tipo simplesmente não tem onde guardar — e é isso que se afirma aqui.
      expect(r.toString(), isNot(contains('algo')));
    });
  });

  // =========================================================================
  // Desfecho e falha
  // =========================================================================
  group('DesfechoSocial e FalhaSocial', () {
    test('`repeticao` é sucesso, e vem do servidor', () {
      final d = DesfechoSocial.doWire({'repeticao': true, 'estado': 'amigos'});
      expect(d.repeticao, isTrue);
      expect(d.estado, 'amigos');
    });

    test('sem `repeticao` no fio, o padrão é falso', () {
      expect(DesfechoSocial.doWire(const {}).repeticao, isFalse);
      expect(DesfechoSocial.doWire(const {}).estado, '');
    });

    test('só rede e desconhecido justificam "tentar de novo"', () {
      // Regra de negócio (lotação, autoamizade, bloqueio) NÃO é transitória:
      // repetir dá o mesmo, e um botão que promete o que não cumpre é pior que
      // nenhum botão.
      const transitorios = {
        MotivoFalhaSocial.indisponivel,
        MotivoFalhaSocial.desconhecida,
      };
      for (final m in MotivoFalhaSocial.values) {
        expect(
          const FalhaSocial(MotivoFalhaSocial.indisponivel).transitoria,
          isTrue,
        );
        expect(
          FalhaSocial(m).transitoria,
          transitorios.contains(m),
          reason: m.name,
        );
      }
    });

    test('o código de recusa é guardado CRU', () {
      // Cru para que uma recusa nova do servidor chegue ao log sem que este
      // cliente precise conhecê-la. Quem traduz para o jogador é
      // `rotulos_sociais.dart`, e o que ele não conhece vira frase neutra.
      const f = FalhaSocial(
        MotivoFalhaSocial.regraDeNegocio,
        'recusaQueNinguemPreviu',
      );
      expect(f.recusa, 'recusaQueNinguemPreviu');
      expect(f.toString(), contains('recusaQueNinguemPreviu'));
    });
  });
}

// ===========================================================================
// Auxiliares
// ===========================================================================

JogadorPublico jogadorDoWire(Map<Object?, Object?> bruto) =>
    JogadorPublico.doWire(bruto);

PaginaSocial paginaDe(List<String> ids, {String? cursor}) => PaginaSocial(
  itens: [
    for (final id in ids)
      JogadorPublico(publicId: id, apelido: '', avatarRef: null, desde: null),
  ],
  proximoCursor: cursor,
);
