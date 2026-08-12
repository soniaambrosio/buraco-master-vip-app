// busca_apelido_test.dart — o domínio da BUSCA por apelido público.
//
// SÓ DECISÃO PURA, como `teste_social.dart`: nada aqui sobe emulador nem toca
// Firestore. Quem prova que a consulta corre sobre o índice certo, que o `list`
// de `publicProfiles` está fechado e que a resposta real não carrega UID é
// `firebase/testes/social.test.js`, contra o Emulator Suite.
//
// O NOME DO ARQUIVO TERMINA EM `_test.dart`, e isso é deliberado. `flutter test`
// só coleta esse sufixo, e os seis arquivos do projeto que usam o prefixo
// `teste_` — inclusive `teste_social.dart`, ao lado deste — ficam fora do glob
// padrão e precisam ser invocados por caminho explícito. Uma suíte nova que
// nascesse `teste_busca.dart` estaria fora do portão no dia em que existisse um
// portão. Corrigir os seis é frente própria; não repetir o padrão custa nada.

import 'package:flutter_test/flutter_test.dart';

import 'package:buraco_master_vip/social/amizade.dart';
import 'package:buraco_master_vip/social/apresentacao.dart';
import 'package:buraco_master_vip/social/busca_apelido.dart';
import 'package:buraco_master_vip/social/erros_sociais.dart';
import 'package:buraco_master_vip/social/identidade_publica.dart';

const uidEu = 'uidObservador';
const uidOutro = 'uidOutroJogador';
const uidTerceiro = 'uidTerceiroJogador';

const pidOutro = 'PCDEFGHJKMNPQ';
const pidTerceiro = 'PRSTVWXYZ0123';

/// Compara duas strings por PONTO DE CÓDIGO, e não por unidade UTF-16.
///
/// EXISTE PORQUE `String.compareTo` NÃO SERVE AQUI. Dart compara unidades
/// UTF-16, e o Firestore ordena strings por bytes UTF-8 — que é ordem de ponto
/// de código. As duas discordam exatamente na faixa que interessa a este
/// arquivo: um emoji (U+1F388) começa com a unidade 0xD83C, que é MENOR que a
/// unidade 0xFF21 de um caractere de largura completa — embora o ponto de código
/// do emoji seja muito maior.
///
/// Afirmar a faixa do prefixo com `compareTo` daria uma prova sobre o Dart, e
/// não sobre o banco. Esta função afirma sobre o banco.
int compararPorPontoDeCodigo(String a, String b) {
  final ra = a.runes.toList(growable: false);
  final rb = b.runes.toList(growable: false);
  for (var i = 0; i < ra.length && i < rb.length; i++) {
    if (ra[i] != rb[i]) return ra[i].compareTo(rb[i]);
  }
  return ra.length.compareTo(rb.length);
}

CandidatoDeBusca candidato({
  String publicId = pidOutro,
  String uidAlvo = uidOutro,
  EstadoAmizade estado = EstadoAmizade.nenhuma,
  String? solicitanteUid,
  bool euBloqueeiOAlvo = false,
  bool alvoMeBloqueou = false,
}) =>
    CandidatoDeBusca(
      publicId: publicId,
      uidAlvo: uidAlvo,
      estado: estado,
      solicitanteUid: solicitanteUid,
      euBloqueeiOAlvo: euBloqueeiOAlvo,
      alvoMeBloqueou: alvoMeBloqueou,
    );

List<ResultadoDeBusca> projetar(
  List<CandidatoDeBusca> candidatos, {
  bool chatSilenciado = false,
  bool restricaoSocial = false,
}) =>
    projetarResultadosDeBusca(
      uidObservador: uidEu,
      candidatos: candidatos,
      observadorComChatSilenciado: chatSilenciado,
      observadorComRestricaoSocial: restricaoSocial,
    );

void main() {
  // ===================================================== NORMALIZAÇÃO (§5)
  group('NRM — normalização da consulta', () {
    test('NRM-01 caixa alta e baixa produzem a MESMA chave', () {
      expect(chaveDeBusca('MARIA'), chaveDeBusca('maria'));
      expect(chaveDeBusca('MaRiA'), 'maria');
    });

    test('NRM-02 espaços de borda e espaços repetidos colapsam', () {
      expect(chaveDeBusca('  Dona   Maria  '), 'dona maria');
      expect(chaveDeBusca('Dona\tMaria'), 'dona maria');
      // Espaço interno ÚNICO não some: "Dona Maria" e "DonaMaria" são apelidos
      // diferentes, e colapsá-los faria a busca por um devolver o outro.
      expect(chaveDeBusca('DonaMaria'), isNot(chaveDeBusca('Dona Maria')));
    });

    test('NRM-03 acento é dobrado, e o resto do Unicode é preservado', () {
      expect(chaveDeBusca('Ávila'), 'avila');
      expect(chaveDeBusca('ÁVILA'), chaveDeBusca('avila'));
      expect(chaveDeBusca('Ação'), 'acao');
      // Emoji não é acento e não tem dobra: continua na chave, em minúscula.
      expect(chaveDeBusca('Ana🎈'), 'ana🎈');
    });

    test('NRM-04 entrada vazia (ou só espaço) é recusada', () {
      for (final vazio in ['', '   ', '\t\t']) {
        final c = avaliarConsultaDeBusca(termo: vazio);
        expect(c.aceita, isFalse, reason: 'vazio: "$vazio"');
        expect(c.recusa, ErroSocial.consultaInvalida);
      }
    });

    test('NRM-05 termo curto demais é recusado, e o corte é DEPOIS do trim', () {
      expect(avaliarConsultaDeBusca(termo: 'ab').recusa,
          ErroSocial.consultaMuitoCurta);
      // Seis caracteres brutos, dois visíveis. Medir antes de normalizar
      // aprovaria esta consulta.
      expect(avaliarConsultaDeBusca(termo: '  ab  ').recusa,
          ErroSocial.consultaMuitoCurta);
      expect(avaliarConsultaDeBusca(termo: 'abc').aceita, isTrue);
    });

    test('NRM-06 termo longo demais é recusado', () {
      expect(avaliarConsultaDeBusca(termo: 'x' * kConsultaMaxima).aceita, isTrue);
      expect(avaliarConsultaDeBusca(termo: 'x' * (kConsultaMaxima + 1)).recusa,
          ErroSocial.consultaMuitoLonga);
    });

    test('NRM-07 o comprimento conta RUNAS, não unidades UTF-16', () {
      // 24 emojis são 48 unidades UTF-16 e 24 caracteres visíveis. Contar
      // unidades recusaria um apelido que a gravação aceita.
      expect(avaliarConsultaDeBusca(termo: '🎈' * kConsultaMaxima).aceita, isTrue);
      expect(
          avaliarConsultaDeBusca(termo: '🎈' * (kConsultaMaxima + 1)).recusa,
          ErroSocial.consultaMuitoLonga);
    });

    test('NRM-08 caractere de controle é recusado como inválido, não como curto',
        () {
      // ESCRITOS COMO ESCAPE, e nao como o caractere literal: colados de
      // verdade, alguns deles desaparecem no editor, no diff e no terminal — que
      // é exatamente o que os torna úteis para impersonação, e o que faria uma
      // revisão jurar que este mapa tem entradas repetidas.
      // ESCRITOS COMO ESCAPE, e nao como o caractere literal: colados de
      // verdade, alguns deles desaparecem no editor, no diff e no terminal —
      // que e exatamente o que os torna uteis para impersonacao, e o que faria
      // uma revisao jurar que este mapa tem entradas repetidas.
      final proibidos = {
        'nova linha (C0)': '\n',
        'tabulacao vertical (C0)': '\u000B',
        'DEL': '\u007F',
        'C1': '\u0090',
        'espaco de largura zero': '\u200B',
        'marca de direcao': '\u200F',
        'override RTL': '\u202E',
        'juntador de palavra': '\u2060',
        'isolamento direcional': '\u2066',
        'BOM': '\uFEFF',
      };
      proibidos.forEach((nome, caractere) {
        final c = avaliarConsultaDeBusca(termo: 'ana${caractere}bia');
        expect(c.aceita, isFalse, reason: nome);
        // O código é `consultaInvalida`, e não `consultaMuitoCurta`: o problema
        // não é o tamanho, e mandar a pessoa digitar mais não resolveria.
        expect(c.recusa, ErroSocial.consultaInvalida, reason: nome);
      });
    });

    test('NRM-09 termo que não é texto é recusado', () {
      for (final lixo in <Object?>[null, 42, true, ['ana'], {'a': 1}]) {
        expect(avaliarConsultaDeBusca(termo: lixo).recusa,
            ErroSocial.consultaInvalida,
            reason: '$lixo');
      }
    });

    test('NRM-EQ a normalização da BUSCA é a mesma da GRAVAÇÃO', () {
      // §5: "A normalização usada na gravação/indexação e na busca deve ser
      // exatamente a mesma." A prova compara, para o mesmo texto bruto, a chave
      // que a busca procura com o `apelidoOrdenacao` que a gravação grava —
      // pelos DOIS caminhos de escrita que existem.
      for (final bruto in [
        'Maria',
        '  Dona   Maria  ',
        'ÁVILA',
        'José da Silva',
        'Ação',
        'ana🎈',
        'ZÉCA',
      ]) {
        final apelidoGravado = normalizarApelido(bruto);

        // Caminho 1: o perfil inicial (`perfilPublicoInicial`).
        final perfil = PerfilPublico(
          publicId: pidOutro,
          apelido: apelidoGravado,
          avatarRef: null,
          estado: EstadoPerfilPublico.ativo,
          criadoEm: '',
          atualizadoEm: '',
        );
        expect(chaveDeBusca(bruto), perfil.apelidoOrdenacao,
            reason: 'gravação inicial divergiu para "$bruto"');
        expect(chaveDeBusca(bruto), perfil.toJson()['apelidoOrdenacao'],
            reason: 'o documento gravado divergiu para "$bruto"');

        // Caminho 2: a troca de apelido (`atualizarPerfilPublico`).
        final atualizacao =
            avaliarAtualizacaoDeApresentacao(apelidoBruto: bruto, agoraIso: '');
        expect(atualizacao.aceita, isTrue, reason: bruto);
        expect(chaveDeBusca(bruto), atualizacao.campos!['apelidoOrdenacao'],
            reason: 'a atualização divergiu para "$bruto"');

        // E a busca EXATA por aquele texto encontra aquela chave.
        final consulta = avaliarConsultaDeBusca(termo: bruto, modo: 'exato');
        expect(consulta.aceita, isTrue, reason: bruto);
        expect(consulta.chaveInicio, atualizacao.campos!['apelidoOrdenacao'],
            reason: 'a consulta exata não casaria com o gravado: "$bruto"');
      }
    });

    test('NRM-EQ2 o que a busca aceita é o que a gravação aceita', () {
      // O crivo de forma é o MESMO (mínimo, máximo, controle), e o teste é a
      // contraprova: não existe termo que a busca aceite e que nunca pudesse ter
      // sido gravado como apelido, nem o contrário.
      for (final texto in [
        'ab',
        'abc',
        'x' * kApelidoMaximo,
        'x' * (kApelidoMaximo + 1),
        '   ',
        'a\nb',
        'Dona   Maria',
        '🎈🎈🎈',
      ]) {
        final buscavel = avaliarConsultaDeBusca(termo: texto).aceita;
        final gravavel = recusaDeApelido(normalizarApelido(texto)) == null;
        expect(buscavel, gravavel,
            reason: '"$texto" é gravável=$gravavel mas buscável=$buscavel');
      }
    });
  });

  // ========================================================= MODALIDADE (§6)
  group('MOD — modalidade da busca', () {
    test('MOD-01 o padrão é prefixo', () {
      expect(avaliarConsultaDeBusca(termo: 'ana').modo, ModoBusca.prefixo);
      expect(avaliarConsultaDeBusca(termo: 'ana', modo: null).modo,
          ModoBusca.prefixo);
    });

    test('MOD-02 o modo exato compara igualdade: a faixa é um ponto', () {
      final c = avaliarConsultaDeBusca(termo: 'Ana', modo: 'exato');
      expect(c.modo, ModoBusca.exato);
      expect(c.chaveInicio, 'ana');
      expect(c.chaveFim, c.chaveInicio);
    });

    test('MOD-03 o modo prefixo fecha a faixa com U+10FFFF', () {
      final c = avaliarConsultaDeBusca(termo: 'Ana', modo: 'prefixo');
      expect(c.chaveInicio, 'ana');
      expect(c.chaveFim, 'ana$kFimDaFaixa');
      expect(kFimDaFaixa.runes.single, 0x10FFFF);
    });

    test('MOD-04 modo desconhecido é RECUSADO, e não tratado como padrão', () {
      // §9 pede "validação estrita dos parâmetros". Um `modo: 'contem'` aceito
      // como prefixo faria o cliente acreditar em uma busca que não existe.
      for (final ruim in ['contem', 'fuzzy', 'PREFIXO', '', 7, true]) {
        expect(avaliarConsultaDeBusca(termo: 'ana', modo: ruim).recusa,
            ErroSocial.consultaInvalida,
            reason: '$ruim');
      }
    });

    test('MOD-05 a faixa do prefixo alcança qualquer sufixo, inclusive emoji',
        () {
      final c = avaliarConsultaDeBusca(termo: 'ana');
      for (final apelido in ['Ana', 'Ana Bia', 'Ánax', 'Ana🎈', 'Ana\uFF21', 'anaz']) {
        final chave = chaveDeBusca(apelido);
        expect(compararPorPontoDeCodigo(chave, c.chaveInicio) >= 0, isTrue,
            reason: '"$apelido" caiu abaixo do início da faixa');
        expect(compararPorPontoDeCodigo(chave, c.chaveFim) <= 0, isTrue,
            reason: '"$apelido" caiu acima do fim da faixa');
      }
    });

    test('MOD-06 U+F8FF NÃO serviria de sentinela — é o defeito que se evitou',
        () {
      // O idiom mais citado para prefixo no Firestore fecha a faixa em U+F8FF,
      // que fica ABAIXO de qualquer emoji. Este teste existe para que, se alguém
      // "simplificar" a constante um dia, a razão apareça como falha.
      expect(compararPorPontoDeCodigo(chaveDeBusca('Ana🎈'), 'ana') > 0,
          isTrue,
          reason: 'com U+F8FF, um apelido com emoji sumiria da busca');
      expect(compararPorPontoDeCodigo(chaveDeBusca('Ana🎈'), 'ana$kFimDaFaixa') < 0,
          isTrue);
    });

    test('MOD-07 quem está fora do prefixo fica fora da faixa', () {
      final c = avaliarConsultaDeBusca(termo: 'ana');
      for (final fora in ['Amanda', 'Bia', 'Zeca', 'an ']) {
        final chave = chaveDeBusca(fora);
        final dentro = compararPorPontoDeCodigo(chave, c.chaveInicio) >= 0 &&
            compararPorPontoDeCodigo(chave, c.chaveFim) <= 0;
        expect(dentro, isFalse, reason: '"$fora" não devia casar com "ana"');
      }
    });

    test('MOD-08 não há curinga: `*` e `%` são texto comum', () {
      // Um apelido pode conter os dois, e a faixa os compara literalmente. Se
      // algum dia forem interpretados, esta consulta deixa de ser recusada por
      // não casar com nada e passa a casar com tudo.
      final c = avaliarConsultaDeBusca(termo: '***');
      expect(c.aceita, isTrue);
      expect(c.chaveInicio, '***');
      expect(compararPorPontoDeCodigo(chaveDeBusca('Ana'), c.chaveFim) > 0, isTrue,
          reason: '"Ana" não pode casar com a consulta "***"');
    });
  });

  // ============================================================= LIMITES (§9)
  group('LIM — limites e anti-enumeração', () {
    test('LIM-01 o limite tem padrão e teto', () {
      expect(avaliarConsultaDeBusca(termo: 'ana').limite, kResultadosPadrao);
      expect(avaliarConsultaDeBusca(termo: 'ana', limite: 5).limite, 5);
      expect(avaliarConsultaDeBusca(termo: 'ana', limite: 100000).limite,
          kResultadosMaximo);
    });

    test('LIM-02 limite absurdo cai no padrão em vez de virar erro', () {
      for (final ruim in <Object?>[0, -3, null, 'muitos', 2.7]) {
        final n = avaliarConsultaDeBusca(termo: 'ana', limite: ruim).limite;
        expect(n >= 1 && n <= kResultadosMaximo, isTrue, reason: '$ruim');
      }
      expect(avaliarConsultaDeBusca(termo: 'ana', limite: -3).limite,
          kResultadosPadrao);
    });

    test('LIM-03 o teto da busca é menor que o das listas do próprio jogador',
        () {
      // A lista de amigos é do jogador; a busca é uma janela para a base
      // inteira. Os dois tetos não têm por que ser iguais, e o da busca é o
      // menor de propósito.
      expect(kResultadosMaximo, lessThan(kLimiteAmigos));
      expect(kResultadosPadrao, lessThanOrEqualTo(kResultadosMaximo));
    });

    test('LIM-04 o mínimo da consulta é o mínimo do apelido', () {
      // Amarrados, e não escolhidos em separado: um mínimo de busca menor que o
      // mínimo de apelido só serviria para varrer.
      expect(kConsultaMinima, kApelidoMinimo);
      expect(kConsultaMaxima, kApelidoMaximo);
    });

    test('LIM-05 a v1 não tem cursor, e isso é contrato', () {
      // A constante existe para que a AUSÊNCIA seja afirmável. Uma busca
      // paginada percorreria a base em passos de vinte.
      expect(kSemCursor, isTrue);
      expect(avaliarConsultaDeBusca(termo: 'ana').toJson().keys,
          isNot(contains('cursor')));
    });

    test('LIM-06 não existe consulta que case com tudo', () {
      // As três formas óbvias de pedir "todos": vazio, um caractere e curinga.
      expect(avaliarConsultaDeBusca(termo: '').aceita, isFalse);
      expect(avaliarConsultaDeBusca(termo: 'a').aceita, isFalse);
      expect(avaliarConsultaDeBusca(termo: '*').aceita, isFalse);
    });
  });

  // ================================================== RESULTADO (§7 e §10)
  group('RES — o resultado público', () {
    test('RES-01 o resultado tem exatamente três chaves, e nenhuma é UID', () {
      final r = projetar([candidato()]).single;
      expect(r.toJson().keys.toSet(), {'publicId', 'relacao', 'acoes'});
      expect(r.toJson().toString().contains(uidOutro), isFalse);
      expect(r.toJson().toString().contains(uidEu), isFalse);
    });

    test('RES-02 o candidato carrega UID e o resultado não', () {
      // A fronteira em uma linha: o UID entra na projeção e não sai dela.
      final c = candidato();
      expect(c.uidAlvo, uidOutro);
      expect(projetar([c]).single.toJson().values.join(), isNot(contains('uid')));
    });

    test('RES-03 a ordem de entrada é preservada', () {
      // Ela vem do `orderBy` do banco. Reordenar aqui faria o resultado depender
      // de quantos itens o filtro de bloqueio removeu.
      final saida = projetar([
        candidato(publicId: pidTerceiro, uidAlvo: uidTerceiro),
        candidato(publicId: pidOutro, uidAlvo: uidOutro),
      ]);
      expect(saida.map((r) => r.publicId), [pidTerceiro, pidOutro]);
    });

    test('RES-04 a projeção é determinística', () {
      final entrada = [
        candidato(estado: EstadoAmizade.amigos),
        candidato(publicId: pidTerceiro, uidAlvo: uidTerceiro),
      ];
      final a = projetar(entrada).map((r) => r.toJson()).toList();
      final b = projetar(entrada).map((r) => r.toJson()).toList();
      expect(a, b);
    });

    test('RES-05 lista vazia é lista vazia, não erro', () {
      expect(projetar(const []), isEmpty);
    });
  });

  // ================================================== GRAFO SOCIAL (§10)
  group('SOC — estado social no resultado', () {
    test('SOC-01 sem relação: pode adicionar', () {
      final r = projetar([candidato()]).single;
      expect(r.relacao, RelacaoVista.nenhuma);
      expect(r.acoes, {AcaoSocial.adicionarAmigo, AcaoSocial.bloquear});
    });

    test('SOC-02 amizade existente aparece como amigos', () {
      final r = projetar([candidato(estado: EstadoAmizade.amigos)]).single;
      expect(r.relacao, RelacaoVista.amigos);
      expect(r.acoes, {AcaoSocial.removerAmigo, AcaoSocial.bloquear});
    });

    test('SOC-03 solicitação que EU enviei', () {
      final r = projetar([
        candidato(estado: EstadoAmizade.pendente, solicitanteUid: uidEu),
      ]).single;
      expect(r.relacao, RelacaoVista.solicitacaoEnviada);
      expect(r.acoes, {AcaoSocial.cancelarSolicitacao, AcaoSocial.bloquear});
    });

    test('SOC-04 solicitação que EU recebi', () {
      final r = projetar([
        candidato(estado: EstadoAmizade.pendente, solicitanteUid: uidOutro),
      ]).single;
      expect(r.relacao, RelacaoVista.solicitacaoRecebida);
      expect(r.acoes, {
        AcaoSocial.aceitarSolicitacao,
        AcaoSocial.recusarSolicitacao,
        AcaoSocial.bloquear,
      });
    });

    test('SOC-05 depois de desfazer a amizade, volta a ser "nenhuma"', () {
      // O documento canônico some na remoção, e o candidato chega com
      // `estado: nenhuma`. A busca não guarda memória da amizade antiga.
      final r = projetar([candidato(estado: EstadoAmizade.nenhuma)]).single;
      expect(r.relacao, RelacaoVista.nenhuma);
      expect(r.acoes, contains(AcaoSocial.adicionarAmigo));
    });

    test('SOC-06 o próprio perfil aparece, sem ação social', () {
      final r = projetar([candidato(uidAlvo: uidEu)]).single;
      expect(r.relacao, RelacaoVista.euMesmo);
      expect(r.acoes, {AcaoSocial.editarPerfil});
    });

    test('SOC-07 o resultado NÃO é fonte de amizade — só reflete o canônico',
        () {
      // Mesmo par, dois estados canônicos diferentes, dois rótulos diferentes.
      // Não há nada na busca que decida a relação; ela só lê.
      final comAmizade =
          projetar([candidato(estado: EstadoAmizade.amigos)]).single;
      final sem = projetar([candidato(estado: EstadoAmizade.nenhuma)]).single;
      expect(comAmizade.relacao, isNot(sem.relacao));
    });
  });

  // ===================================================== BLOQUEIO (§8)
  group('BLQ — bloqueio e descoberta', () {
    test('BLQ-01 quem me bloqueou NÃO aparece na busca', () {
      // É a proteção central de §8: sem isso, a busca devolveria ao bloqueado o
      // acesso que o bloqueio tirou.
      expect(projetar([candidato(alvoMeBloqueou: true)]), isEmpty);
    });

    test('BLQ-02 quem EU bloqueei também não aparece', () {
      expect(projetar([candidato(euBloqueeiOAlvo: true)]), isEmpty);
    });

    test('BLQ-03 bloqueio some mesmo quando a amizade ainda não foi desfeita',
        () {
      // A faxina do gatilho é assíncrona. Durante a janela, o documento canônico
      // ainda diz "amigos" — e a busca não pode usar isso para exibir alguém que
      // acabou de bloquear ou de ser bloqueado.
      expect(
          projetar([
            candidato(estado: EstadoAmizade.amigos, alvoMeBloqueou: true),
          ]),
          isEmpty);
      expect(
          projetar([
            candidato(estado: EstadoAmizade.amigos, euBloqueeiOAlvo: true),
          ]),
          isEmpty);
    });

    test('BLQ-04 a ausência não diz QUEM bloqueou quem', () {
      // As duas direções produzem exatamente o mesmo resultado observável: uma
      // lista sem aquela pessoa. Se uma delas devolvesse "indisponível" e a
      // outra nada, a diferença contaria de que lado veio o bloqueio.
      final meBloqueou = projetar([candidato(alvoMeBloqueou: true)]);
      final euBloquei = projetar([candidato(euBloqueeiOAlvo: true)]);
      expect(meBloqueou.map((r) => r.toJson()), euBloquei.map((r) => r.toJson()));
      expect(meBloqueou, isEmpty);
    });

    test('BLQ-05 a descoberta não vira rota para contornar o bloqueio', () {
      // Não há resultado, logo não há publicId, logo não há a que mandar pedido
      // de amizade. E se o publicId vier de outro lugar, quem recusa é
      // `enviarSolicitacaoAmizade`, que relê o bloqueio dentro da transação.
      final saida = projetar([
        candidato(alvoMeBloqueou: true),
        candidato(publicId: pidTerceiro, uidAlvo: uidTerceiro),
      ]);
      expect(saida.map((r) => r.publicId), [pidTerceiro]);
      expect(saida.any((r) => r.acoes.contains(AcaoSocial.adicionarAmigo)),
          isTrue,
          reason: 'quem não bloqueou continua alcançável');
    });

    test('BLQ-06 bloqueio não apaga os OUTROS resultados', () {
      final saida = projetar([
        candidato(publicId: pidOutro, uidAlvo: uidOutro, alvoMeBloqueou: true),
        candidato(publicId: pidTerceiro, uidAlvo: uidTerceiro),
      ]);
      expect(saida.length, 1);
      expect(saida.single.publicId, pidTerceiro);
    });
  });

  // ===================================================== SANÇÃO (§8, §10)
  group('SAN — sanção social do pesquisador', () {
    test('SAN-01 restrição social deixa ver, e não deixa agir', () {
      // Ocultar tudo faria a busca parecer quebrada; a sanção é sobre AGIR.
      final r = projetar([candidato()], restricaoSocial: true).single;
      expect(r.relacao, RelacaoVista.indisponivel);
      expect(r.acoes, isEmpty);
    });

    test('SAN-02 silêncio de chat também esteriliza o resultado', () {
      final r = projetar([candidato()], chatSilenciado: true).single;
      expect(r.relacao, RelacaoVista.indisponivel);
      expect(r.acoes, isEmpty);
    });

    test('SAN-03 sanção NÃO oculta, bloqueio oculta — e são coisas diferentes',
        () {
      expect(projetar([candidato()], restricaoSocial: true).length, 1);
      expect(projetar([candidato(alvoMeBloqueou: true)]), isEmpty);
    });

    test('SAN-04 o resultado sob sanção não conta por que está indisponível',
        () {
      final r = projetar([candidato()], restricaoSocial: true).single;
      final texto = r.toJson().toString();
      for (final vazamento in [
        'restricao',
        'sancao',
        'silenciado',
        'bloque',
        uidEu,
        uidOutro,
      ]) {
        expect(texto.toLowerCase().contains(vazamento.toLowerCase()), isFalse,
            reason: '$vazamento vazou no resultado');
      }
    });
  });

  // ===================================================== CÓDIGOS (§18)
  group('ERB — códigos de erro da busca', () {
    test('ERB-01 os três códigos novos existem e têm nome estável', () {
      for (final esperado in [
        'consultaInvalida',
        'consultaMuitoCurta',
        'consultaMuitoLonga',
      ]) {
        expect(ErroSocial.values.map((e) => e.name), contains(esperado));
      }
    });

    test('ERB-02 nenhum código anterior foi renomeado nem removido', () {
      // §17: preservar o contrato da OS anterior. O `.name` é o contrato.
      const anteriores = [
        'identidadeNaoEncontrada',
        'perfilPublicoNaoDisponivel',
        'perfilPublicoInvalido',
        'autoAmizadeInvalida',
        'jaSaoAmigos',
        'solicitacaoJaExiste',
        'solicitacaoNaoEncontrada',
        'naoEDestinatario',
        'naoERemetente',
        'relacaoBloqueada',
        'limiteAmigos',
        'limiteSolicitacoes',
        'apelidoInvalido',
        'avatarInvalido',
        'identificadorInvalido',
      ];
      final agora = ErroSocial.values.map((e) => e.name).toSet();
      for (final nome in anteriores) {
        expect(agora, contains(nome), reason: '$nome sumiu do contrato');
      }
    });
  });
}
