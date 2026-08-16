// trilha_operacional.dart — o "como chegamos aqui" que acompanha a falha.
//
// Breadcrumb aqui é ENUM, não string livre. Isso não é preciosismo: é o que
// torna a promessa de baixa cardinalidade demonstrável em vez de prometida.
// O conjunto de marcos possíveis é finito e está inteiro neste arquivo, então
// nenhum ponto do app consegue injetar `tela_perfil_do_uid_abc123` na trilha.
//
// Pelo mesmo motivo, marco NÃO carrega valor. Um marco diz que algo
// aconteceu, nunca com quem nem com qual carta.

/// Marcos operacionais que o app pode registrar. Lista fechada de propósito.
enum MarcoOperacional {
  appIniciado,
  firebaseIniciado,
  firebaseIndisponivel,
  coletorIniciado,
  coletorIndisponivel,
  sessaoAutenticada,
  sessaoEncerrada,
  telaInicio,
  telaMesa,
  telaLoja,
  telaRanking,
  telaPerfil,
  telaConfiguracoes,
  telaTorneios,
  telaSaguao,
  partidaIniciada,
  partidaEncerrada,
  onlineConectando,
  onlineConectado,
  onlineQueda,
  onlineReconectando,
  compraIniciada,
  compraConcluida,
  compraCancelada,
  appEmSegundoPlano,
  appRetomado,
}

/// Últimos marcos, em ordem de acontecimento. Buffer circular de tamanho fixo:
/// nunca cresce, então não vira vazamento de memória num app que fica horas
/// aberto numa mesa.
class TrilhaOperacional {
  TrilhaOperacional({this.capacidade = 25})
      : assert(capacidade > 0, 'capacidade da trilha precisa ser positiva');

  final int capacidade;
  final List<MarcoOperacional> _marcos = <MarcoOperacional>[];

  void registrar(MarcoOperacional marco) {
    _marcos.add(marco);
    if (_marcos.length > capacidade) {
      _marcos.removeRange(0, _marcos.length - capacidade);
    }
  }

  /// Cópia imutável, do mais antigo para o mais recente.
  List<MarcoOperacional> get marcos => List<MarcoOperacional>.unmodifiable(_marcos);

  List<String> get nomes => _marcos.map((m) => m.name).toList(growable: false);

  bool get vazia => _marcos.isEmpty;

  void limpar() => _marcos.clear();

  @override
  String toString() => nomes.join(' > ');
}
