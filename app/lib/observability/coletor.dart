// coletor.dart — para onde a falha vai depois de redigida.
//
// A camada é agnóstica de fornecedor de propósito. Trocar de coletor (ou ficar
// sem nenhum) não pode mudar uma linha de captura, de redação ou de
// deduplicação — é o que garante que a suíte de testes exercite o mesmo
// caminho de código que roda em produção.
//
// Contrato de TODA implementação: nenhum método pode lançar. Ainda assim,
// quem chama trata como se pudesse (ver `Observabilidade._protegido`), porque
// coletor de terceiro não é código nosso.

import 'evento_falha.dart';
import 'identidade_build.dart';
import 'trilha_operacional.dart';

/// Destino de eventos de falha.
abstract class ColetorDeFalhas {
  /// Nome curto para diagnóstico ("nulo", "memoria", "crashlytics").
  String get nome;

  /// Prepara o coletor. Devolve `true` se ficou apto a receber eventos.
  ///
  /// Devolver `false` (ou lançar) NÃO é fatal: o app segue sem coletor.
  Future<bool> iniciar(IdentidadeBuild identidade);

  /// Entrega um evento já redigido.
  Future<void> enviar(EventoFalha evento);

  /// Registra um marco operacional.
  Future<void> marco(MarcoOperacional marco);
}

/// Coletor que não faz nada. É o padrão em debug e em teste, e é o destino
/// para onde a instalação cai quando o coletor real não inicializa.
///
/// Existe para que "sem coletor" seja um objeto com o mesmo comportamento de
/// sempre, e não um `null` espalhando `if` pelo caminho de captura.
class ColetorNulo implements ColetorDeFalhas {
  const ColetorNulo();

  @override
  String get nome => 'nulo';

  @override
  Future<bool> iniciar(IdentidadeBuild identidade) async => true;

  @override
  Future<void> enviar(EventoFalha evento) async {}

  @override
  Future<void> marco(MarcoOperacional marco) async {}
}

/// Coletor que só acumula em memória. É o que os testes inspecionam, e
/// serve também para a tela de diagnóstico interna.
class ColetorEmMemoria implements ColetorDeFalhas {
  ColetorEmMemoria({this.capacidade = 100});

  final int capacidade;
  final List<EventoFalha> _eventos = <EventoFalha>[];
  final List<MarcoOperacional> _marcos = <MarcoOperacional>[];
  IdentidadeBuild? identidadeRecebida;
  int vezesIniciado = 0;

  List<EventoFalha> get eventos => List<EventoFalha>.unmodifiable(_eventos);
  List<MarcoOperacional> get marcos => List<MarcoOperacional>.unmodifiable(_marcos);
  List<EventoFalha> get fatais => _eventos.where((e) => e.ehFatal).toList();
  List<EventoFalha> get naoFatais => _eventos.where((e) => !e.ehFatal).toList();

  @override
  String get nome => 'memoria';

  @override
  Future<bool> iniciar(IdentidadeBuild identidade) async {
    vezesIniciado++;
    identidadeRecebida = identidade;
    return true;
  }

  @override
  Future<void> enviar(EventoFalha evento) async {
    _eventos.add(evento);
    if (_eventos.length > capacidade) {
      _eventos.removeRange(0, _eventos.length - capacidade);
    }
  }

  @override
  Future<void> marco(MarcoOperacional marco) async => _marcos.add(marco);

  void limpar() {
    _eventos.clear();
    _marcos.clear();
  }
}
