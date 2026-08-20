// chat_test.dart — o domínio do Chat Livre Seguro V1.
//
// Só decisão pura: nada aqui sobe emulador nem toca Firestore. Os casos que
// dependem de AUTORIZAÇÃO (quem lê `chatMessages`, quem escreve `chatChannels`)
// ficam em firebase/testes/chat.test.js, porque quem os prova é a regra, não o
// Dart. Os casos que dependem de AUTENTICAÇÃO e de idempotência REAL (anônimo
// recusado, retry sob transação, concorrência) ficam em
// functions-moderacao/test/integracao.chat.emulador.test.js, porque quem os prova
// é o servidor.
//
// O NOME DO ARQUIVO TERMINA EM `_test.dart` de propósito. Os arquivos com prefixo
// `teste_` deste repositório ficam FORA do glob padrão do `flutter test` e só
// rodam porque o CI os nomeia um por um. Uma suíte nova nascer invisível para
// `flutter test` seria começar com o defeito que a §16 manda evitar.

import 'package:buraco_master_vip/chat/mensagem.dart';
import 'package:buraco_master_vip/chat/porta.dart';
import 'package:buraco_master_vip/chat/superficie.dart';
import 'package:buraco_master_vip/moderacao/relacao_social.dart';
import 'package:flutter_test/flutter_test.dart';

const autor = 'uidAutor';
const outro = 'uidOutro';
const terceiro = 'uidTerceiro';
const plateia = 'uidPlateia';
const publicIdDoAutor = 'BMV-7K2M';

/// Mesa com o autor e [outros] sentados, e [espectadores] assistindo.
CanalDeChat mesa({
  String canalId = 'sala7',
  List<String> outros = const [outro],
  List<String> espectadores = const [],
  bool aberto = true,
  SuperficieChat superficie = SuperficieChat.mesaPrivada,
  bool autorSentado = true,
  bool autorEspectador = false,
}) =>
    CanalDeChat(
      canalId: canalId,
      superficie: superficie,
      aberto: aberto,
      participantes: [
        if (autorSentado)
          const ParticipanteDoCanal(
              uid: autor, papel: PapelNoCanal.jogadorSentado),
        if (autorEspectador)
          const ParticipanteDoCanal(
              uid: autor, papel: PapelNoCanal.espectador),
        for (final u in outros)
          ParticipanteDoCanal(uid: u, papel: PapelNoCanal.jogadorSentado),
        for (final u in espectadores)
          ParticipanteDoCanal(uid: u, papel: PapelNoCanal.espectador),
      ],
    );

VereditoEnvio enviar({
  String autorUid = autor,
  String intentId = 'intent-1',
  Object? conteudo = 'boa jogada',
  Object? superficie = 'mesa_privada',
  CanalDeChat? canal,
  SancaoDoAutor sancao = const SancaoDoAutor(),
  List<ParDeContato> contatos = const [],
  Map<String, Object?> payload = const {},
  String? publicId = publicIdDoAutor,
}) =>
    avaliarEnvio(
      autorUid: autorUid,
      intentId: intentId,
      conteudoBruto: conteudo,
      superficiePedida: superficie,
      canal: canal ?? mesa(),
      sancao: sancao,
      contatos: contatos,
      payloadCru: payload,
      autorPublicId: publicId,
    );

void main() {
  // ===================================================== SUPERFÍCIES (§11)
  group('SUP — classificação de superfícies', () {
    test('SUP-01 a classificação cobre TODAS as superfícies do enum', () {
      // Sem este caso, acrescentar valor ao enum sem classificá-lo passaria em
      // silêncio — e `politicaDe` é um switch exaustivo, então o Dart só reclama
      // em tempo de compilação se ninguém puser um `default`.
      for (final s in SuperficieChat.values) {
        expect(() => politicaDe(s), returnsNormally,
            reason: '${s.name} sem política declarada');
      }
    });

    test('SUP-02 SÓ a Mesa Privada aceita texto livre', () {
      // A correção canônica: texto livre exige círculo restrito, entre pessoas
      // convidadas e individualmente elegíveis. Só a Mesa Privada é isso.
      expect(superficieAceitaTextoLivre(SuperficieChat.mesaPrivada), isTrue);

      for (final s in [
        SuperficieChat.mesaPublica,
        SuperficieChat.mesaVip,
        SuperficieChat.saguaoPublico,
        SuperficieChat.salaoVip,
        SuperficieChat.espectadorDeMesa,
      ]) {
        expect(superficieAceitaTextoLivre(s), isFalse, reason: s.name);
      }
    });

    test('SUP-02b exatamente UMA superfície aceita texto livre', () {
      // Contagem, e não lista: acrescentar uma superfície liberada sem decisão
      // de produto reprova aqui, mesmo que o caso acima não a mencione.
      final liberadas =
          SuperficieChat.values.where(superficieAceitaTextoLivre).toList();
      expect(liberadas, [SuperficieChat.mesaPrivada]);
    });

    test('SUP-03 as superfícies de falas prontas são recusa DECIDIDA', () {
      // Não é lacuna: o produto decidiu que elas usam mensagens previamente
      // cadastradas, reações e emojis autorizados. `decisaoAusente` continua
      // existindo no enum para a superfície que aparecer amanhã, mas NENHUMA
      // está nesse estado hoje — e é isso que este caso fixa.
      for (final s in SuperficieChat.values) {
        expect(politicaDe(s), isNot(PoliticaSuperficie.decisaoAusente),
            reason: '${s.name} ficou sem decisão de produto');
      }
      expect(politicaDe(SuperficieChat.saguaoPublico),
          PoliticaSuperficie.naoLiberado);
      expect(politicaDe(SuperficieChat.salaoVip),
          PoliticaSuperficie.naoLiberado);
      expect(politicaDe(SuperficieChat.mesaVip),
          PoliticaSuperficie.naoLiberado);
      expect(politicaDe(SuperficieChat.espectadorDeMesa),
          PoliticaSuperficie.naoLiberado);
    });

    test('SUP-03b o valor antigo `mesa_de_partida` NÃO ressuscita', () {
      // Ele colapsava três superfícies com políticas diferentes. Aceitá-lo como
      // sinônimo de qualquer uma delas seria manter o defeito com outro nome.
      expect(SuperficieChat.porWire('mesa_de_partida'), isNull);
      expect(enviar(superficie: 'mesa_de_partida').recusa,
          RecusaMensagem.superficieNaoAceitaChat);
    });

    test('SUP-04 superfície desconhecida no wire é recusa, não default', () {
      expect(SuperficieChat.porWire('mesa_secreta'), isNull);
      expect(SuperficieChat.porWire(null), isNull);
      expect(SuperficieChat.porWire(42), isNull);

      final v = enviar(superficie: 'mesa_secreta');
      expect(v.aceita, isFalse);
      expect(v.recusa, RecusaMensagem.superficieNaoAceitaChat);
    });

    test('SUP-05 saguão recusado mesmo com canal de saguão coerente', () {
      // O canal bater com a superfície não vira permissão: a política é anterior.
      final v = enviar(
        superficie: 'saguao_publico',
        canal: mesa(superficie: SuperficieChat.saguaoPublico),
      );
      expect(v.aceita, isFalse);
      expect(v.recusa, RecusaMensagem.superficieNaoAceitaChat);
    });
  });

  // ======================================================== CONTEÚDO (§6)
  group('CNT — conteúdo', () {
    test('CNT-01 texto livre comum é aceito, e chega aparado', () {
      final v = enviar(conteudo: '   joguei o 3 de paus   ');
      expect(v.aceita, isTrue);
      expect(v.conteudo, 'joguei o 3 de paus');
    });

    test('CNT-02 texto livre é livre: frase arbitrária não é filtrada', () {
      // A OS proíbe lista de frases prontas e proíbe filtro moral de palavras
      // nesta entrega. Este caso existe para que quem for "melhorar" o chat
      // depois veja que a ausência de filtro é decisão, não esquecimento.
      for (final frase in [
        'vamos de novo?',
        'que sorte a sua, hein',
        'ganhei de você fácil',
        'jogada horrível essa aí',
      ]) {
        expect(enviar(conteudo: frase).aceita, isTrue, reason: frase);
      }
    });

    test('CNT-03 vazio e só-espaço são recusados', () {
      expect(enviar(conteudo: '').recusa, RecusaMensagem.conteudoVazio);
      expect(enviar(conteudo: '    ').recusa, RecusaMensagem.conteudoVazio);
      // O outro lado da moeda: um unico caractere visivel JA e mensagem. Sem
      // este par, "recusa vazio" poderia estar recusando tudo.
      expect(enviar(conteudo: 'a').aceita, isTrue);
    });

    test('CNT-04 payload estrutural no lugar de texto é recusa própria', () {
      // Recusa PRÓPRIA e não "vazio": no log, `conteudoNaoTexto` é o sinal de
      // que alguém tentou passar objeto por conteúdo.
      expect(enviar(conteudo: {'a': 1}).recusa,
          RecusaMensagem.conteudoNaoTexto);
      expect(enviar(conteudo: ['a']).recusa, RecusaMensagem.conteudoNaoTexto);
      expect(enviar(conteudo: 42).recusa, RecusaMensagem.conteudoNaoTexto);
      expect(enviar(conteudo: null).recusa, RecusaMensagem.conteudoNaoTexto);
      expect(enviar(conteudo: true).recusa, RecusaMensagem.conteudoNaoTexto);
    });

    test('CNT-05 o limite é exatamente kLimiteMensagem', () {
      expect(enviar(conteudo: 'a' * kLimiteMensagem).aceita, isTrue);
      expect(enviar(conteudo: 'a' * (kLimiteMensagem + 1)).recusa,
          RecusaMensagem.conteudoAcimaDoLimite);
    });

    test('CNT-06 o tamanho é medido em pontos de código, não em UTF-16', () {
      // 300 emojis fora do BMP: `String.length` diria 600 e recusaria uma
      // mensagem que tem 300 caracteres na tela. É a divergência que faria
      // cliente e servidor recusarem coisas diferentes.
      final emojis = '\u{1F0A1}' * kLimiteMensagem;
      expect(emojis.length, kLimiteMensagem * 2,
          reason: 'premissa do caso: são pares surrogados');
      expect(tamanhoDeMensagem(emojis), kLimiteMensagem);
      expect(enviar(conteudo: emojis).aceita, isTrue);

      final umDemais = '\u{1F0A1}' * (kLimiteMensagem + 1);
      expect(enviar(conteudo: umDemais).recusa,
          RecusaMensagem.conteudoAcimaDoLimite);
    });

    test('CNT-07 caractere de controle é recusado, e NÃO removido', () {
      for (final s in [
        'linha1\nlinha2',
        'volta\rcursor',
        'tab\tdentro',
        'nulo\u0000aqui',
        'c1\u0085aqui',
        'sep\u2028aqui',
        'sep\u2029aqui',
        'del\u007Faqui',
      ]) {
        final v = enviar(conteudo: s);
        expect(v.recusa, RecusaMensagem.conteudoComCaractereDeControle,
            reason: s.codeUnits.toString());
        // Remover em silêncio entregaria ao jogador um texto diferente do que
        // ele escreveu, e faria a evidência de uma denúncia divergir do digitado.
        expect(v.conteudo, isNull);
      }
    });

    test('CNT-08 emoji, acento e pontuação passam intactos', () {
      const rico = 'É isso aí! 🎉 açúcar, coração — "aspas" & <tags>';
      final v = enviar(conteudo: rico);
      expect(v.aceita, isTrue);
      // Nada de escapar, nada de sanitizar: o conteúdo é texto opaco. Quem
      // renderiza trata como texto — ver o contrato de `MensagemPublica`.
      expect(v.conteudo, rico);
    });
  });

  // ================================================= AUTORIA E PAYLOAD (§4,§5)
  group('AUT — autoria e payload', () {
    test('AUT-01 UID de terceiro no payload RECUSA o pedido', () {
      // A prova negativa que a §5 exige: a mensagem não vira do terceiro, e a
      // chamada não segue em silêncio.
      final v = enviar(payload: {'autorUid': terceiro, 'conteudo': 'oi'});
      expect(v.aceita, isFalse);
      expect(v.recusa, RecusaMensagem.payloadComCampoProibido);
      expect(v.camposProibidos, ['autorUid']);
      expect(v.messageId, isNull);
    });

    test('AUT-02 a autoria é o parâmetro autenticado, e o id muda com ele', () {
      // Não existe parâmetro por onde entre um autor alegado: a assinatura de
      // `avaliarEnvio` só tem `autorUid`. Dois autores diferentes com a MESMA
      // intenção produzem ids diferentes — logo o id não é do cliente.
      // A mesma mesa para os dois, montada explicitamente: os dois estão
      // sentados, então a única diferença entre as duas chamadas é QUEM assina.
      const mesmaMesa = CanalDeChat(
        canalId: 'sala7',
        superficie: SuperficieChat.mesaPrivada,
        participantes: [
          ParticipanteDoCanal(uid: autor, papel: PapelNoCanal.jogadorSentado),
          ParticipanteDoCanal(uid: outro, papel: PapelNoCanal.jogadorSentado),
        ],
      );

      final a = enviar(autorUid: autor, canal: mesmaMesa);
      final b = enviar(autorUid: outro, canal: mesmaMesa);
      expect(a.aceita, isTrue);
      expect(b.aceita, isTrue);
      expect(a.messageId, isNot(b.messageId));
    });

    test('AUT-03 cliente não escolhe messageId nem timestamp', () {
      for (final campo in ['messageId', 'mensagemId', 'enviadaEm', 'timestamp']) {
        final v = enviar(payload: {campo: 'valor-escolhido'});
        expect(v.recusa, RecusaMensagem.payloadComCampoProibido,
            reason: campo);
        expect(v.camposProibidos, [campo]);
      }
    });

    test('AUT-04 campo de transporte no payload é recusado (§10)', () {
      for (final campo in [
        'socketId',
        'connectionId',
        'geracao',
        'tentativa',
        'ip',
        'sessionId',
      ]) {
        expect(enviar(payload: {campo: 'x'}).recusa,
            RecusaMensagem.payloadComCampoProibido,
            reason: campo);
      }
    });

    test('AUT-05 estado de moderação no payload é recusado', () {
      // Sem isto, um cliente mandaria `chatSilenciadoAte: null` na tentativa de
      // se declarar livre.
      for (final campo in [
        'chatSilenciadoAte',
        'suspensaoPermanente',
        'playerModeration',
        'claims',
        'admin',
        'token',
      ]) {
        expect(enviar(payload: {campo: 'x'}).recusa,
            RecusaMensagem.payloadComCampoProibido,
            reason: campo);
      }
    });

    test('AUT-06 vários campos proibidos aparecem TODOS, ordenados', () {
      final v = enviar(payload: {'socketId': 1, 'autorUid': 2, 'token': 3});
      expect(v.camposProibidos, ['autorUid', 'socketId', 'token']);
    });

    test('AUT-07 os campos legítimos do pedido NÃO são proibidos', () {
      // O contrário do caso acima: a trava não pode recusar o próprio pedido.
      final v = enviar(payload: {
        'intentId': 'intent-1',
        'canalId': 'sala7',
        'superficie': 'mesa_privada',
        'conteudo': 'oi',
      });
      expect(v.aceita, isTrue);
    });

    test('AUT-08 sem identidade pública, recusa em vez de expor o UID', () {
      expect(enviar(publicId: null).recusa,
          RecusaMensagem.identidadePublicaAusente);
      expect(enviar(publicId: '').recusa,
          RecusaMensagem.identidadePublicaAusente);
    });

    test('AUT-09 intenção inválida é recusada', () {
      for (final id in ['', 'com|pipe', 'com/barra', 'com espaço', 'a' * 200]) {
        expect(enviar(intentId: id).recusa, RecusaMensagem.intencaoInvalida,
            reason: id);
      }
    });
  });

  // ==================================================== IDEMPOTÊNCIA (§9)
  group('IDE — idempotência', () {
    test('IDE-01 mesma intenção e mesmo contexto: MESMO id', () {
      final a = enviar(intentId: 'i-1', conteudo: 'oi');
      final b = enviar(intentId: 'i-1', conteudo: 'oi');
      expect(a.messageId, b.messageId);
      expect(a.impressao, b.impressao);
    });

    test('IDE-02 o id é função de autor+intenção, e NÃO do conteúdo', () {
      // Importa para a barreira: o id é a chave da reserva, então ele tem que
      // ser o mesmo para o retry. É a `impressao` que carrega o conteúdo.
      final a = enviar(intentId: 'i-1', conteudo: 'texto A');
      final b = enviar(intentId: 'i-1', conteudo: 'texto B');
      expect(a.messageId, b.messageId);
      expect(a.impressao, isNot(b.impressao),
          reason: 'texto diferente tem que mudar a impressão, senão a '
              'intenção reaproveitada passaria por repetição');
    });

    test('IDE-03 intenções diferentes: ids diferentes', () {
      expect(enviar(intentId: 'i-1').messageId,
          isNot(enviar(intentId: 'i-2').messageId));
    });

    test('IDE-04 a impressão muda com o canal', () {
      final a = enviar(canal: mesa(canalId: 'sala7'));
      final b = enviar(canal: mesa(canalId: 'sala9'));
      expect(a.impressao, isNot(b.impressao));
    });

    test('IDE-05 o messageId é OPACO: não carrega o UID (§13)', () {
      final id = mensagemIdDe(autorUid: autor, intentId: 'i-1');
      expect(id, isNot(contains(autor)));
      expect(id, isNot(contains('|')));
      expect(id, hasLength(32));
      expect(RegExp(r'^[0-9a-f]{32}$').hasMatch(id), isTrue);
    });

    test('IDE-06 reconexão não muda o id: o socket não entra na derivação', () {
      // §10: uma reconexão legítima não pode transformar a mesma intenção em
      // outra mensagem. Como campo de transporte é RECUSADO no payload, não há
      // por onde ele influenciar o id — e este caso fixa isso.
      final antes = enviar(intentId: 'i-1', conteudo: 'oi').messageId;
      final depois = enviar(intentId: 'i-1', conteudo: 'oi').messageId;
      expect(antes, depois);
    });
  });

  // ======================================================= BLOQUEIO (§7)
  group('BLQ — bloqueio', () {
    test('BLQ-01 sem bloqueio, a mesa toda recebe', () {
      final v = enviar(
        canal: mesa(outros: const [outro, terceiro]),
        contatos: const [],
      );
      expect(v.aceita, isTrue);
      expect(v.destinatarios, [outro, terceiro]);
    });

    test('BLQ-02 A bloqueou B: B sai da entrega (A→B recusado)', () {
      final v = enviar(
        canal: mesa(outros: const [outro, terceiro]),
        contatos: const [ParDeContato(uid: outro, autorBloqueou: true)],
      );
      expect(v.aceita, isTrue);
      expect(v.destinatarios, [terceiro]);
    });

    test('BLQ-03 B bloqueou A: B sai da entrega (B→A recusado)', () {
      final v = enviar(
        canal: mesa(outros: const [outro, terceiro]),
        contatos: const [ParDeContato(uid: outro, bloqueouOAutor: true)],
      );
      expect(v.aceita, isTrue);
      expect(v.destinatarios, [terceiro]);
    });

    test('BLQ-04 mesa de dois com bloqueio: a mensagem é RECUSADA', () {
      // Aceitar e não entregar a ninguém deixaria o jogador falando com uma
      // parede acreditando que foi lido.
      final v = enviar(
        canal: mesa(outros: const [outro]),
        contatos: const [ParDeContato(uid: outro, bloqueouOAutor: true)],
      );
      expect(v.aceita, isFalse);
      expect(v.recusa, RecusaMensagem.contatoRecusado);
      expect(v.motivoContato, MotivoContatoRecusado.bloqueadoPeloDestino);
      expect(v.destinatarios, isEmpty);
    });

    test('BLQ-05 na direção inversa o motivo canônico é o outro', () {
      final v = enviar(
        canal: mesa(outros: const [outro]),
        contatos: const [ParDeContato(uid: outro, autorBloqueou: true)],
      );
      expect(v.recusa, RecusaMensagem.contatoRecusado);
      expect(v.motivoContato, MotivoContatoRecusado.bloqueouODestino);
    });

    test('BLQ-06 desbloquear volta a permitir', () {
      final bloqueado = enviar(
        canal: mesa(outros: const [outro]),
        contatos: const [ParDeContato(uid: outro, autorBloqueou: true)],
      );
      expect(bloqueado.aceita, isFalse);

      final liberado = enviar(
        canal: mesa(outros: const [outro]),
        contatos: const [ParDeContato(uid: outro)],
      );
      expect(liberado.aceita, isTrue);
      expect(liberado.destinatarios, [outro]);
    });

    test('BLQ-07 par sem leitura é tratado como SEM bloqueio', () {
      // Ausência de documento é o estado normal de duas pessoas que nunca se
      // bloquearam. Tratar como bloqueio calaria a mesa inteira.
      final v = enviar(canal: mesa(outros: const [outro]), contatos: const []);
      expect(v.destinatarios, [outro]);
    });

    test('BLQ-08 a decisão do par é a de avaliarContato, não uma cópia', () {
      // Consumir e não redecidir (§7). Se `avaliarContato` mudar de opinião,
      // este caso muda com ela — que é exatamente o acoplamento desejado.
      for (final par in [
        const ParDeContato(uid: outro, autorBloqueou: true),
        const ParDeContato(uid: outro, bloqueouOAutor: true),
        const ParDeContato(uid: outro, autorBloqueou: true, bloqueouOAutor: true),
      ]) {
        final canonico = avaliarContato(
          origemBloqueouDestino: par.autorBloqueou,
          destinoBloqueouOrigem: par.bloqueouOAutor,
        );
        final v = enviar(canal: mesa(outros: const [outro]), contatos: [par]);
        expect(v.aceita, canonico.permitido);
        expect(v.motivoContato, canonico.motivo);
      }
    });
  });

  // ======================================================== SANÇÃO (§8)
  group('SAN — sanção', () {
    test('SAN-01 chat silenciado impede o envio para a mesa INTEIRA', () {
      // Sanção não é por par: ela cala o autor para todos.
      final v = enviar(
        canal: mesa(outros: const [outro, terceiro]),
        sancao: const SancaoDoAutor(chatSilenciado: true),
      );
      expect(v.aceita, isFalse);
      expect(v.recusa, RecusaMensagem.contatoRecusado);
      expect(v.motivoContato, MotivoContatoRecusado.chatSilenciadoPorSancao);
      expect(v.destinatarios, isEmpty);
    });

    test('SAN-02 restrição social impede o envio', () {
      final v = enviar(sancao: const SancaoDoAutor(restricaoSocial: true));
      expect(v.recusa, RecusaMensagem.contatoRecusado);
      expect(v.motivoContato, MotivoContatoRecusado.restricaoSocial);
    });

    test('SAN-03 suspensão impede o envio, com recusa própria', () {
      // `MotivoContatoRecusado` não tem valor para suspensão — aquele enum foi
      // escrito para rotas sociais, que nunca consultaram `suspensoAte`. O chat
      // nasce fechado, e o motivo é distinguível no log.
      final v = enviar(sancao: const SancaoDoAutor(suspenso: true));
      expect(v.aceita, isFalse);
      expect(v.recusa, RecusaMensagem.suspensaoImpedeChat);
      expect(v.motivoContato, isNull);
    });

    test('SAN-04 sem sanção, envio permitido', () {
      expect(enviar(sancao: const SancaoDoAutor()).aceita, isTrue);
    });

    test('SAN-05 sanção vence bloqueio na recusa reportada', () {
      // Qualquer uma recusa; a ordem só decide qual motivo o jogador lê. O
      // silenciado precisa saber que está silenciado, não que "alguém te
      // bloqueou" — que seria informação sobre terceiro, além de errada.
      final v = enviar(
        canal: mesa(outros: const [outro]),
        sancao: const SancaoDoAutor(chatSilenciado: true),
        contatos: const [ParDeContato(uid: outro, bloqueouOAutor: true)],
      );
      expect(v.motivoContato, MotivoContatoRecusado.chatSilenciadoPorSancao);
    });
  });

  // ===================================================== CANAL E PAPEL (§10,§11)
  group('CAN — canal e papel', () {
    test('CAN-01 canal ausente é recusa, não criação', () {
      final v = avaliarEnvio(
        autorUid: autor,
        intentId: 'i-1',
        conteudoBruto: 'oi',
        superficiePedida: 'mesa_privada',
        canal: null,
        sancao: const SancaoDoAutor(),
        contatos: const [],
        autorPublicId: publicIdDoAutor,
      );
      expect(v.recusa, RecusaMensagem.canalDesconhecido);
    });

    test('CAN-02 canal fechado não aceita fala', () {
      expect(enviar(canal: mesa(aberto: false)).recusa,
          RecusaMensagem.canalFechado);
    });

    test('CAN-03 superfície pedida tem que bater com a do canal', () {
      // Sem isto, alguém mandaria `mesa_privada` sobre um canal de saguão e
      // escaparia da classificação da §11 pelo nome do campo.
      final v = enviar(
        superficie: 'mesa_privada',
        canal: mesa(superficie: SuperficieChat.saguaoPublico),
      );
      expect(v.recusa, RecusaMensagem.canalInvalido);
    });

    test('CAN-04 ESPECTADOR NÃO FALA', () {
      final v = enviar(
        canal: mesa(autorSentado: false, autorEspectador: true),
      );
      expect(v.aceita, isFalse);
      expect(v.recusa, RecusaMensagem.papelSemDireitoDeFala);
    });

    test('CAN-05 ESPECTADOR NÃO RECEBE', () {
      // A direção que se esquece. Receber é metade de conversar.
      final v = enviar(
        canal: mesa(outros: const [outro], espectadores: const [plateia]),
      );
      expect(v.aceita, isTrue);
      expect(v.destinatarios, [outro]);
      expect(v.destinatarios, isNot(contains(plateia)));
    });

    test('CAN-06 quem não está no canal não fala', () {
      final v = enviar(canal: mesa(autorSentado: false));
      expect(v.recusa, RecusaMensagem.papelSemDireitoDeFala);
    });

    test('CAN-07 mesa sem mais ninguém sentado: sem destinatários', () {
      final v = enviar(canal: mesa(outros: const []));
      expect(v.recusa, RecusaMensagem.semDestinatarios);
    });

    test('CAN-08 só espectadores na mesa: sem destinatários', () {
      final v = enviar(
        canal: mesa(outros: const [], espectadores: const [plateia]),
      );
      expect(v.recusa, RecusaMensagem.semDestinatarios);
    });

    test('CAN-09 o autor nunca é destinatário de si mesmo', () {
      final v = enviar(canal: mesa(outros: const [outro]));
      expect(v.destinatarios, isNot(contains(autor)));
    });
  });

  // ==================================================== PROJEÇÃO (§13)
  group('PRJ — projeção e vazamento', () {
    MensagemPublica projecao() => const MensagemPublica(
          messageId: 'd0d9544f7185ad8d945ce892865a471c',
          autorPublicId: publicIdDoAutor,
          superficie: 'mesa_privada',
          canalId: 'sala7',
          conteudo: 'boa jogada',
          enviadaEm: '2026-08-18T00:00:00.000Z',
        );

    test('PRJ-01 a projeção não carrega UID interno', () {
      final json = projecao().toJson();
      expect(caminhosProibidosNaEntrega(json), isEmpty);
      expect(json.keys, isNot(contains('autorUid')));
      expect(json.values.whereType<String>(), isNot(contains(autor)));
    });

    test('PRJ-02 a projeção não carrega token, socket nem IP', () {
      final json = projecao().toJson();
      for (final proibido in ['token', 'idToken', 'socketId', 'ip', 'sessionId']) {
        expect(json.keys, isNot(contains(proibido)));
      }
    });

    test('PRJ-03 a projeção não carrega destinatários nem participantes', () {
      // Entregar a lista de destinatários contaria a cada jogador quem NÃO
      // recebeu — que é o mesmo que publicar quem bloqueou quem.
      final json = projecao().toJson();
      expect(json.keys, isNot(contains('destinatarios')));
      expect(json.keys, isNot(contains('participantes')));
    });

    test('PRJ-04 a projeção tem EXATAMENTE os campos previstos', () {
      // Lista fechada: um campo novo na projeção reprova aqui e obriga quem o
      // acrescentou a justificá-lo. É o que impede o vazamento por acréscimo.
      expect(
        projecao().toJson().keys.toSet(),
        {
          'messageId',
          'autorPublicId',
          'superficie',
          'canalId',
          'conteudo',
          'enviadaEm',
          'esquema',
        },
      );
    });

    test('PRJ-05 a trava acha vazamento EM PROFUNDIDADE', () {
      // O teste estrutural que a §13 pede, e não um fixture bonitinho: o
      // vazamento real está um nível abaixo de onde se olha.
      final sujo = {
        'mensagem': projecao().toJson(),
        'canal': {
          'canalId': 'sala7',
          'participantes': [autor, outro],
        },
      };
      final achados = caminhosProibidosNaEntrega(sujo);
      expect(achados, contains('canal.participantes'));
    });

    test('PRJ-06 a trava acha vazamento dentro de lista', () {
      final sujo = {
        'mensagens': [
          projecao().toJson(),
          {...projecao().toJson(), 'autorUid': autor},
        ],
      };
      expect(caminhosProibidosNaEntrega(sujo), ['mensagens[1].autorUid']);
    });

    test('PRJ-07 estado administrativo de terceiro é vazamento', () {
      for (final campo in [
        'playerModeration',
        'chatSilenciadoAte',
        'suspensoAte',
        'blocks',
        'sanctions',
        'entitlements',
        'cpf',
      ]) {
        expect(caminhosProibidosNaEntrega({campo: 'x'}), [campo],
            reason: campo);
      }
    });

    test('PRJ-08 a projeção não sugere marcação ativa', () {
      // §6: HTML, Markdown e link não são executados. A ausência de campo que
      // sugira marcação é contrato — um `formato: "html"` convidaria o primeiro
      // renderizador a interpretar texto escrito por outro jogador.
      final chaves = projecao().toJson().keys.map((k) => k.toLowerCase());
      for (final suspeito in ['html', 'markdown', 'rich', 'formato', 'render']) {
        expect(chaves.any((k) => k.contains(suspeito)), isFalse,
            reason: suspeito);
      }
    });
  });

  // ================================================ COERÊNCIA DAS TRAVAS
  group('TRV — coerência das listas de trava', () {
    test('TRV-01 o que é proibido na entrega é proibido no envio', () {
      // As duas listas têm propósitos diferentes (uma guarda o pedido, a outra a
      // entrega), mas a identidade interna e o transporte têm que estar nas
      // duas. Sem este caso, uma lista cresceria e a outra não.
      const essenciais = {
        'uid',
        'autorUid',
        'senderUid',
        'token',
        'idToken',
        'socketId',
        'connectionId',
        'sessionId',
        'ip',
        'playerModeration',
        'chatSilenciadoAte',
        'suspensoAte',
        'suspensaoPermanente',
      };
      for (final campo in essenciais) {
        expect(kCamposProibidosNoEnvio, contains(campo),
            reason: '$campo ausente na trava de ENVIO');
        expect(kChavesProibidasNaEntrega, contains(campo),
            reason: '$campo ausente na trava de ENTREGA');
      }
    });

    test('TRV-02 os campos legítimos do pedido não estão na trava de envio', () {
      for (final campo in ['intentId', 'canalId', 'superficie', 'conteudo']) {
        expect(kCamposProibidosNoEnvio, isNot(contains(campo)), reason: campo);
      }
    });
  });
}
