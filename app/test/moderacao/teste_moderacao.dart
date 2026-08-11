// teste_moderacao.dart — o domínio de moderação (OS de Moderação §21).
//
// Só decisão pura: nada aqui sobe emulador nem toca Firestore. Os casos de
// AUTORIZAÇÃO (quem lê, quem escreve, quem é admin) ficam em
// firebase/testes/moderacao.test.js, porque quem os prova é a regra, não o Dart.

import 'package:flutter_test/flutter_test.dart';
import 'package:buraco_master_vip/moderacao/denuncia.dart';
import 'package:buraco_master_vip/moderacao/relacao_social.dart';
import 'package:buraco_master_vip/moderacao/sancao.dart';
import 'package:buraco_master_vip/moderacao/validacao.dart';

const denunciante = 'uidDenunciante';
const denunciado = 'uidDenunciado';

DateTime utc(int ano, [int mes = 1, int dia = 1, int hora = 0]) =>
    DateTime.utc(ano, mes, dia, hora);

void main() {
  // =========================================================== DENÚNCIA
  group('DEN — denúncia', () {
    test('DEN-01 denúncia de perfil válida é aceita', () {
      final v = avaliarDenuncia(
        denuncianteUid: denunciante,
        denunciadoUid: denunciado,
        tipo: TipoDenuncia.perfil,
        categoria: CategoriaDenuncia.nomeOfensivo,
        reportIntentId: 'intent-1',
        comentario: 'o apelido é um xingamento',
      );
      expect(v.aceita, isTrue);
      expect(v.recusa, isNull);
    });

    test('DEN-02 auto-denúncia é recusada', () {
      final v = avaliarDenuncia(
        denuncianteUid: denunciante,
        denunciadoUid: denunciante,
        tipo: TipoDenuncia.perfil,
        categoria: CategoriaDenuncia.outro,
        reportIntentId: 'intent-1',
      );
      expect(v.aceita, isFalse);
      expect(v.recusa, RecusaDenuncia.autoDenuncia);
    });

    test('DEN-03 categoria de chat não vale em denúncia de partida', () {
      final v = avaliarDenuncia(
        denuncianteUid: denunciante,
        denunciadoUid: denunciado,
        tipo: TipoDenuncia.partida,
        categoria: CategoriaDenuncia.insulto, // é de mensagem
        reportIntentId: 'intent-1',
        referencias: const ReferenciasDenuncia(matchId: 'm1'),
      );
      expect(v.recusa, RecusaDenuncia.categoriaInvalidaParaTipo);
    });

    test('DEN-04 comentário acima do limite é recusado', () {
      final v = avaliarDenuncia(
        denuncianteUid: denunciante,
        denunciadoUid: denunciado,
        tipo: TipoDenuncia.perfil,
        categoria: CategoriaDenuncia.outro,
        reportIntentId: 'intent-1',
        comentario: 'x' * (kLimiteComentario + 1),
      );
      expect(v.recusa, RecusaDenuncia.comentarioLongo);
    });

    test('DEN-05 UID adulterado é recusado', () {
      for (final ruim in ['', 'com/barra', 'com|pipe', 'x' * 200, 'a b']) {
        final v = avaliarDenuncia(
          denuncianteUid: denunciante,
          denunciadoUid: ruim,
          tipo: TipoDenuncia.perfil,
          categoria: CategoriaDenuncia.outro,
          reportIntentId: 'intent-1',
        );
        expect(v.recusa, RecusaDenuncia.identificadorInvalido,
            reason: 'aceitou "$ruim"');
      }
    });

    test('DEN-06 denúncia de mensagem exige messageId e roomId', () {
      final semNada = avaliarDenuncia(
        denuncianteUid: denunciante,
        denunciadoUid: denunciado,
        tipo: TipoDenuncia.mensagem,
        categoria: CategoriaDenuncia.insulto,
        reportIntentId: 'intent-1',
      );
      expect(semNada.recusa, RecusaDenuncia.referenciaAusente);
      expect(semNada.falhas, containsAll(['messageId', 'roomId']));

      final completa = avaliarDenuncia(
        denuncianteUid: denunciante,
        denunciadoUid: denunciado,
        tipo: TipoDenuncia.mensagem,
        categoria: CategoriaDenuncia.insulto,
        reportIntentId: 'intent-1',
        referencias: const ReferenciasDenuncia(messageId: 'msg1', roomId: 'sala1'),
      );
      expect(completa.aceita, isTrue);
    });

    test('DEN-07 denúncia de partida exige matchId', () {
      final v = avaliarDenuncia(
        denuncianteUid: denunciante,
        denunciadoUid: denunciado,
        tipo: TipoDenuncia.partida,
        categoria: CategoriaDenuncia.combinacao,
        reportIntentId: 'intent-1',
      );
      expect(v.recusa, RecusaDenuncia.referenciaAusente);
      expect(v.falhas, ['matchId']);
    });

    test('DEN-08 referência presente porém malformada é recusada', () {
      final v = avaliarDenuncia(
        denuncianteUid: denunciante,
        denunciadoUid: denunciado,
        tipo: TipoDenuncia.partida,
        categoria: CategoriaDenuncia.combinacao,
        reportIntentId: 'intent-1',
        referencias: const ReferenciasDenuncia(matchId: '../outra/mesa'),
      );
      expect(v.recusa, RecusaDenuncia.referenciaIncoerente);
    });

    test('DEN-09 reportIntentId ausente ou malformado é recusado', () {
      for (final ruim in ['', 'a|b', 'x' * 200]) {
        final v = avaliarDenuncia(
          denuncianteUid: denunciante,
          denunciadoUid: denunciado,
          tipo: TipoDenuncia.perfil,
          categoria: CategoriaDenuncia.outro,
          reportIntentId: ruim,
        );
        expect(v.recusa, RecusaDenuncia.intencaoInvalida, reason: 'aceitou "$ruim"');
      }
    });

    test('DEN-10 limite por janela é aplicado', () {
      final v = avaliarDenuncia(
        denuncianteUid: denunciante,
        denunciadoUid: denunciado,
        tipo: TipoDenuncia.perfil,
        categoria: CategoriaDenuncia.outro,
        reportIntentId: 'intent-1',
        jaNaJanela: kLimiteDenunciasPorJanela,
      );
      expect(v.recusa, RecusaDenuncia.limiteAtingido);
    });

    test('DEN-11 pedido malformado não é medido contra a cota', () {
      // Se o freio viesse antes da forma, dava para queimar a cota de alguém
      // mandando lixo em nome dele. A recusa tem que ser de FORMA.
      final v = avaliarDenuncia(
        denuncianteUid: denunciante,
        denunciadoUid: denunciante, // auto-denúncia
        tipo: TipoDenuncia.perfil,
        categoria: CategoriaDenuncia.outro,
        reportIntentId: 'intent-1',
        jaNaJanela: kLimiteDenunciasPorJanela + 50,
      );
      expect(v.recusa, RecusaDenuncia.autoDenuncia);
    });

    test('DEN-12 a chave é determinista: retry converge no mesmo documento', () {
      final a = chaveDeDenuncia(
          denuncianteUid: denunciante, reportIntentId: 'intent-1');
      final b = chaveDeDenuncia(
          denuncianteUid: denunciante, reportIntentId: 'intent-1');
      final c = chaveDeDenuncia(
          denuncianteUid: denunciante, reportIntentId: 'intent-2');
      expect(a, b, reason: 'mesmo pedido tem que dar a mesma chave');
      expect(a, isNot(c), reason: 'pedidos distintos não podem colidir');
    });

    test('DEN-13 a chave isola denunciantes com o mesmo intentId', () {
      // `reportIntentId` nasce no aparelho; dois aparelhos podem sortear igual.
      final a = chaveDeDenuncia(denuncianteUid: 'uidA', reportIntentId: 'i1');
      final b = chaveDeDenuncia(denuncianteUid: 'uidB', reportIntentId: 'i1');
      expect(a, isNot(b));
    });

    test('DEN-14 componente com o separador não vira chave', () {
      expect(() => chaveComposta(['uid|forjado', 'i1']), throwsArgumentError);
    });

    test('DEN-15 o status público não revela o resultado da investigação', () {
      expect(StatusDenuncia.procedente.publico, StatusPublicoDenuncia.concluida);
      expect(
          StatusDenuncia.improcedente.publico, StatusPublicoDenuncia.concluida);
      expect(StatusDenuncia.arquivada.publico, StatusPublicoDenuncia.concluida);
      expect(StatusDenuncia.recebida.publico, StatusPublicoDenuncia.emAnalise);
      expect(StatusDenuncia.emAnalise.publico, StatusPublicoDenuncia.emAnalise);
    });
  });

  // =========================================================== BLOQUEIO
  group('BLQ — bloqueio', () {
    test('BLQ-01 A bloqueia B', () {
      final v = avaliarBloqueio(bloqueadorUid: 'uidA', bloqueadoUid: 'uidB');
      expect(v.aceita, isTrue);
    });

    test('BLQ-02 auto-bloqueio é recusado', () {
      final v = avaliarBloqueio(bloqueadorUid: 'uidA', bloqueadoUid: 'uidA');
      expect(v.recusa, RecusaBloqueio.autoBloqueio);
    });

    test('BLQ-03 UID inválido é recusado', () {
      final v = avaliarBloqueio(bloqueadorUid: 'uidA', bloqueadoUid: 'b/c');
      expect(v.recusa, RecusaBloqueio.identificadorInvalido);
    });

    test('BLQ-04 teto de bloqueios', () {
      final v = avaliarBloqueio(
          bloqueadorUid: 'uidA', bloqueadoUid: 'uidB',
          jaBloqueados: kLimiteBloqueios);
      expect(v.recusa, RecusaBloqueio.limiteAtingido);
    });

    test('BLQ-05 o bloqueado não alcança o bloqueador', () {
      // A bloqueou B. B tenta falar com A.
      final v = avaliarContato(
        origemBloqueouDestino: false, // B não bloqueou A
        destinoBloqueouOrigem: true, // A bloqueou B
      );
      expect(v.permitido, isFalse);
      expect(v.motivo, MotivoContatoRecusado.bloqueadoPeloDestino);
    });

    test('BLQ-06 quem bloqueou também não fala com o bloqueado', () {
      final v = avaliarContato(
        origemBloqueouDestino: true,
        destinoBloqueouOrigem: false,
      );
      expect(v.permitido, isFalse);
      expect(v.motivo, MotivoContatoRecusado.bloqueouODestino);
    });

    test('BLQ-07 o bloqueio é UNILATERAL no registro', () {
      // A bloquear B não cria bloqueio de B sobre A: são dois fatos separados, e
      // a consulta de contato é quem os combina.
      final aBloqueiaB = true;
      final bBloqueiaA = false;

      // B falando com A: barrado (A bloqueou B).
      expect(
          avaliarContato(
                  origemBloqueouDestino: bBloqueiaA,
                  destinoBloqueouOrigem: aBloqueiaB)
              .permitido,
          isFalse);

      // Agora A desbloqueia B. Nada mais barra o contato — prova de que nunca
      // existiu um bloqueio "espelhado" de B sobre A.
      expect(
          avaliarContato(
                  origemBloqueouDestino: false, destinoBloqueouOrigem: false)
              .permitido,
          isTrue);
    });

    test('BLQ-08 sem bloqueio e sem sanção, o contato é liberado', () {
      final v = avaliarContato(
          origemBloqueouDestino: false, destinoBloqueouOrigem: false);
      expect(v.permitido, isTrue);
      expect(v.motivo, isNull);
    });

    test('BLQ-09 sanção administrativa barra o contato mesmo sem bloqueio', () {
      expect(
          avaliarContato(
            origemBloqueouDestino: false,
            destinoBloqueouOrigem: false,
            origemComChatSilenciado: true,
          ).motivo,
          MotivoContatoRecusado.chatSilenciadoPorSancao);

      expect(
          avaliarContato(
            origemBloqueouDestino: false,
            destinoBloqueouOrigem: false,
            origemComRestricaoSocial: true,
          ).motivo,
          MotivoContatoRecusado.restricaoSocial);
    });
  });

  // =========================================================== MUTE
  group('MUT — silêncio pessoal', () {
    test('MUT-01 mute pessoal é aceito', () {
      expect(avaliarMute(donoUid: 'uidA', alvoUid: 'uidB').aceita, isTrue);
    });

    test('MUT-02 auto-mute é recusado', () {
      expect(avaliarMute(donoUid: 'uidA', alvoUid: 'uidA').recusa,
          RecusaMute.autoMute);
    });

    test('MUT-03 UID inválido é recusado', () {
      expect(avaliarMute(donoUid: 'uidA', alvoUid: '').recusa,
          RecusaMute.identificadorInvalido);
    });
  });

  // =========================================================== SANÇÃO
  group('SAN — sanção administrativa', () {
    Sancao mute({
      DateTime? inicio,
      DateTime? fim,
      StatusSancao status = StatusSancao.ativa,
      String user = 'uidA',
    }) =>
        Sancao(
          sancaoId: 's1',
          userId: user,
          tipo: TipoSancao.muteTemporario,
          motivo: 'assédio no chat',
          inicio: inicio ?? utc(2026, 1, 1),
          fim: fim ?? utc(2026, 1, 8),
          responsavel: 'uidAdmin',
          status: status,
        );

    test('SAN-01 mute temporário sem prazo é recusado', () {
      final v = avaliarSancao(
        userId: 'uidA',
        responsavel: 'uidAdmin',
        tipo: TipoSancao.muteTemporario,
        motivo: 'assédio',
        inicio: utc(2026),
      );
      expect(v.recusa, RecusaSancao.prazoAusente);
    });

    test('SAN-02 prazo que não avança é recusado', () {
      final v = avaliarSancao(
        userId: 'uidA',
        responsavel: 'uidAdmin',
        tipo: TipoSancao.muteTemporario,
        motivo: 'assédio',
        inicio: utc(2026, 1, 10),
        fim: utc(2026, 1, 5),
      );
      expect(v.recusa, RecusaSancao.prazoNoPassado);
    });

    test('SAN-03 suspensão permanente com prazo é contradição', () {
      final v = avaliarSancao(
        userId: 'uidA',
        responsavel: 'uidAdmin',
        tipo: TipoSancao.suspensaoPermanente,
        motivo: 'reincidência',
        inicio: utc(2026),
        fim: utc(2027),
      );
      expect(v.recusa, RecusaSancao.prazoEmSancaoPermanente);
    });

    test('SAN-04 advertência não precisa de prazo', () {
      final v = avaliarSancao(
        userId: 'uidA',
        responsavel: 'uidAdmin',
        tipo: TipoSancao.advertencia,
        motivo: 'primeira ocorrência',
        inicio: utc(2026),
      );
      expect(v.aceita, isTrue);
    });

    test('SAN-05 motivo em branco é recusado', () {
      final v = avaliarSancao(
        userId: 'uidA',
        responsavel: 'uidAdmin',
        tipo: TipoSancao.advertencia,
        motivo: '   ',
        inicio: utc(2026),
      );
      expect(v.recusa, RecusaSancao.motivoAusente);
    });

    test('SAN-06 vigência respeita a janela', () {
      final s = mute();
      expect(s.vigenteEm(utc(2025, 12, 31)), isFalse, reason: 'antes do início');
      expect(s.vigenteEm(utc(2026, 1, 4)), isTrue, reason: 'dentro');
      expect(s.vigenteEm(utc(2026, 1, 8)), isFalse, reason: 'no instante do fim');
      expect(s.vigenteEm(utc(2026, 2, 1)), isFalse, reason: 'depois');
    });

    test('SAN-07 revogada não vale, mesmo dentro da janela', () {
      expect(mute(status: StatusSancao.revogada).vigenteEm(utc(2026, 1, 4)),
          isFalse);
    });

    test('SAN-08 consolidar mantém o término MAIS DISTANTE', () {
      final curta = Sancao(
        sancaoId: 's1', userId: 'uidA', tipo: TipoSancao.muteTemporario,
        motivo: 'a', inicio: utc(2026, 1, 1), fim: utc(2026, 1, 3),
        responsavel: 'adm',
      );
      final longa = Sancao(
        sancaoId: 's2', userId: 'uidA', tipo: TipoSancao.muteTemporario,
        motivo: 'b', inicio: utc(2026, 1, 1), fim: utc(2026, 1, 20),
        responsavel: 'adm',
      );
      // Ordem invertida de propósito: a mais curta chega depois.
      final e = consolidar('uidA', [longa, curta], utc(2026, 1, 2));
      expect(e.chatSilenciadoAte, utc(2026, 1, 20),
          reason: 'punir de novo não pode encurtar a punição anterior');
    });

    test('SAN-09 sanção expirada some do estado consolidado', () {
      final e = consolidar('uidA', [mute()], utc(2026, 2, 1));
      expect(e.semRestricao, isTrue);
      expect(e.chatSilenciadoEm(utc(2026, 2, 1)), isFalse);
    });

    test('SAN-10 o instante é o MESMO em todas as checagens da operação', () {
      // §17 da OS: sanção que expira no meio da operação. Congelar `agora` num
      // valor e passá-lo adiante é o que impede a primeira checagem dizer
      // "silenciado" e a seguinte dizer "livre".
      final e = consolidar('uidA', [mute()], utc(2026, 1, 4));
      final agora = utc(2026, 1, 4);
      expect(e.chatSilenciadoEm(agora), isTrue);
      expect(e.chatSilenciadoEm(agora), isTrue);
      expect(e.socialRestritoEm(agora), isFalse);
      expect(e.suspensoEm(agora), isFalse);
    });

    test('SAN-11 consolidar ignora sanção de outro jogador', () {
      final e = consolidar('uidA', [mute(user: 'uidB')], utc(2026, 1, 4));
      expect(e.semRestricao, isTrue);
    });

    test('SAN-12 suspensão permanente domina e não expira', () {
      final perma = Sancao(
        sancaoId: 's9', userId: 'uidA', tipo: TipoSancao.suspensaoPermanente,
        motivo: 'reincidência', inicio: utc(2026, 1, 1),
        responsavel: 'adm',
      );
      final e = consolidar('uidA', [perma], utc(2099, 1, 1));
      expect(e.suspensaoPermanente, isTrue);
      expect(e.suspensoEm(utc(2099, 1, 1)), isTrue);
    });

    test('SAN-13 instante sem fuso é recusado', () {
      expect(
        () => Sancao(
          sancaoId: 's1', userId: 'uidA', tipo: TipoSancao.advertencia,
          motivo: 'a', inicio: DateTime(2026), responsavel: 'adm',
        ),
        throwsArgumentError,
      );
      final e = consolidar('uidA', const [], utc(2026));
      expect(() => e.chatSilenciadoEm(DateTime(2026)), throwsArgumentError);
    });

    test('SAN-14 ida e volta por JSON preserva a sanção', () {
      final s = mute();
      final volta = Sancao.fromMap(s.toJson());
      expect(volta.sancaoId, s.sancaoId);
      expect(volta.tipo, s.tipo);
      expect(volta.inicio, s.inicio);
      expect(volta.fim, s.fim);
      expect(volta.status, s.status);
      expect(volta.inicio.isUtc, isTrue);
    });

    test('SAN-15 ida e volta por JSON preserva o estado consolidado', () {
      final e = consolidar('uidA', [mute()], utc(2026, 1, 4));
      final volta = EstadoModeracao.fromMap(e.toJson());
      expect(volta.userId, 'uidA');
      expect(volta.chatSilenciadoAte, e.chatSilenciadoAte);
      expect(volta.chatSilenciadoEm(utc(2026, 1, 4)), isTrue);
    });
  });
}
