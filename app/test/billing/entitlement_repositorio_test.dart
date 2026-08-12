// entitlement_repositorio_test.dart — a leitura de `playerEntitlements/{uid}`.
//
// Usa `fake_cloud_firestore`, o mesmo duble que o adaptador de colecoes ja usa,
// para exercitar a leitura sem subir emulador.
//
// O ponto sob teste nao e "sabe ler um mapa". E que TODO caminho de duvida —
// documento ausente, campo faltando, estado desconhecido, prazo ausente —
// termina em "sem VIP". Um repositorio que concedesse por descuido entregaria
// acesso pago a quem nao comprou, e nenhum outro ponto do sistema pegaria isso:
// este e o unico lugar por onde o direito entra no aplicativo.

import 'package:buraco_master_vip/billing/entitlement_repositorio.dart';
import 'package:buraco_master_vip/elegibilidade/entitlement.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

const _uid = 'jogador-1';
final _agora = DateTime.utc(2026, 8, 12, 12);

/// O documento publico, no formato que `documentosDeEntitlement` grava:
/// instantes como STRING ISO-8601, nao Timestamp.
Map<String, dynamic> _doc({
  required bool vipAtivo,
  required String estado,
  String? expiraEm,
  String origem = 'play',
}) =>
    <String, dynamic>{
      'uid': _uid,
      'vipAtivo': vipAtivo,
      'estado': estado,
      'produtoId': 'assinatura.de.teste',
      'origem': origem,
      'inicioEm': _agora.subtract(const Duration(days: 1)).toIso8601String(),
      'expiraEm': expiraEm,
      'renovacaoAutomatica': true,
      'atualizadoEm': _agora.toIso8601String(),
      'esquema': 1,
    };

void main() {
  late FakeFirebaseFirestore db;
  late EntitlementRepositorio repo;

  setUp(() {
    db = FakeFirebaseFirestore();
    repo = EntitlementRepositorio(firestore: db);
  });

  Future<void> gravar(Map<String, dynamic> dados) =>
      db.collection(EntitlementRepositorio.colecao).doc(_uid).set(dados);

  test('documento ausente nao concede nada', () async {
    final e = await repo.ler(_uid);

    expect(e.estado, EstadoEntitlement.nuncaTeve);
    expect(e.vigenteEm(_agora), isFalse);
  });

  test('assinatura ativa e vigente concede', () async {
    await gravar(_doc(
      vipAtivo: true,
      estado: 'ativo',
      expiraEm: _agora.add(const Duration(days: 30)).toIso8601String(),
    ));

    final e = await repo.ler(_uid);

    expect(e.estado, EstadoEntitlement.ativo);
    expect(e.produtoId, 'assinatura.de.teste');
    expect(e.vigenteEm(_agora), isTrue);
  });

  test('assinatura vencida nao concede, mesmo com vipAtivo gravado', () async {
    await gravar(_doc(
      vipAtivo: true,
      estado: 'ativo',
      expiraEm: _agora.subtract(const Duration(minutes: 1)).toIso8601String(),
    ));

    expect((await repo.ler(_uid)).vigenteEm(_agora), isFalse);
  });

  test('prazo ausente nao concede', () async {
    // Dado incompleto recusa: o unico produto VIP previsto e assinatura, e
    // assinatura sempre tem vencimento.
    await gravar(_doc(vipAtivo: true, estado: 'ativo', expiraEm: null));

    expect((await repo.ler(_uid)).vigenteEm(_agora), isFalse);
  });

  test('estado que a plataforma inventar vira recusa explicita', () async {
    await gravar(_doc(
      vipAtivo: true,
      estado: 'SUBSCRIPTION_STATE_QUE_AINDA_NAO_EXISTE',
      expiraEm: _agora.add(const Duration(days: 30)).toIso8601String(),
    ));

    final e = await repo.ler(_uid);

    expect(e.estado, EstadoEntitlement.desconhecido);
    expect(e.vigenteEm(_agora), isFalse);
  });

  test('o uid vem do CAMINHO, nao do corpo do documento', () async {
    // Um registro copiado de outra pessoa nao pode se passar pelo dono.
    await gravar(<String, dynamic>{
      ..._doc(
        vipAtivo: true,
        estado: 'ativo',
        expiraEm: _agora.add(const Duration(days: 30)).toIso8601String(),
      ),
      'uid': 'outro-jogador',
    });

    expect((await repo.ler(_uid)).uid, _uid);
  });

  test('Timestamp do Firestore e normalizado em vez de virar "sem prazo"',
      () async {
    // Rede de seguranca: se algum dia o instante for gravado como Timestamp, o
    // app nao pode simplesmente parar de reconhecer assinante pagante.
    await gravar(<String, dynamic>{
      ..._doc(vipAtivo: true, estado: 'ativo', expiraEm: null),
      'expiraEm': Timestamp.fromDate(_agora.add(const Duration(days: 30))),
    });

    expect((await repo.ler(_uid)).vigenteEm(_agora), isTrue);
  });

  test('observar entrega a mudanca quando o backend reescreve o documento',
      () async {
    final vistos = <bool>[];
    final assinatura = repo
        .observar(_uid)
        .listen((e) => vistos.add(e.vigenteEm(_agora)));
    addTearDown(assinatura.cancel);

    await Future<void>.delayed(Duration.zero);
    await gravar(_doc(
      vipAtivo: true,
      estado: 'ativo',
      expiraEm: _agora.add(const Duration(days: 30)).toIso8601String(),
    ));
    await Future<void>.delayed(Duration.zero);

    // Uma expiracao chegando por RTDN enquanto a tela esta aberta.
    await gravar(_doc(vipAtivo: false, estado: 'expirado', expiraEm: null));
    await Future<void>.delayed(Duration.zero);

    expect(vistos, containsAllInOrder(<bool>[true, false]));
  });
}
