// abertura_falsa.dart — a arte da abertura, dublê, para os testes de widget.
//
// ---------------------------------------------------------------------------
// POR QUE ELA PRECISA EXISTIR
// ---------------------------------------------------------------------------
//
// O runtime da Rive desta versão é NATIVO: uma biblioteca dinâmica baixada no
// build da plataforma alvo. Dentro de `flutter test` ela não existe — e o
// pacote não apenas lança, ele REPORTA o erro ao framework. `flutter_test`
// trata erro reportado como reprovação, então qualquer caso que montasse o
// aplicativo de verdade cairia por causa do ambiente, e não do que ele afirma.
//
// Este dublê é o que devolve os casos ao que eles são: a abertura carrega, a
// timeline termina quando mandam terminar, e o que se mede é o portão duplo.
//
// Ele também torna possível o que a arte real não deixaria observar: a timeline
// que termina DUAS vezes, a que não termina nunca, a que só termina depois de a
// tela sair da árvore, e as quatro maneiras de a arte não carregar.

import 'dart:async';

import 'package:buraco_master_vip/casca/splash/contrato_da_abertura.dart';
import 'package:flutter/widgets.dart';

/// A chave da arte desenhada pelo dublê. Serve para o teste afirmar que a
/// abertura está mostrando ARTE, e não só o fundo estático.
const ValueKey<String> kChaveDaArteFalsa = ValueKey<String>('arte-da-abertura');

class AberturaFalsa implements FonteDaAbertura {
  AberturaFalsa({
    this.falha,
    this.duracaoDaTimeline,
    this.atrasoDoCarregamento = Duration.zero,
  });

  /// Quando não é nula, `carregar()` lança esta falha.
  final FalhaDaAbertura? falha;

  /// Quando a timeline avisa que terminou. Nula = NUNCA termina sozinha, que é
  /// o caso em que só o relógio de segurança pode salvar a abertura.
  final Duration? duracaoDaTimeline;

  /// Quanto o carregamento demora. Serve para o caso em que a tela sai da
  /// árvore antes de a arte ficar pronta.
  final Duration atrasoDoCarregamento;

  int carregamentos = 0;
  ArteFalsa? ultima;

  @override
  Future<AberturaCarregada> carregar() async {
    carregamentos++;
    if (atrasoDoCarregamento > Duration.zero) {
      await Future<void>.delayed(atrasoDoCarregamento);
    }
    final motivo = falha;
    if (motivo != null) throw motivo;
    return ultima = ArteFalsa(duracaoDaTimeline);
  }
}

class ArteFalsa implements AberturaCarregada {
  ArteFalsa(Duration? duracao) {
    if (duracao != null) _relogio = Timer(duracao, concluirAgora);
  }

  final Completer<void> _fim = Completer<void>();
  Timer? _relogio;

  /// Quantas vezes a arte foi devolvida. Mais de uma vez é defeito; zero, com a
  /// tela desmontada, é vazamento.
  int descartes = 0;

  bool get descartada => descartes > 0;

  /// A timeline chegou ao fim. Chamar duas vezes é de propósito nos testes de
  /// corrida — o segundo aviso não pode virar uma segunda saída.
  void concluirAgora() {
    if (!_fim.isCompleted) _fim.complete();
  }

  @override
  Future<void> get concluida => _fim.future;

  @override
  Widget desenhar() => const SizedBox.expand(key: kChaveDaArteFalsa);

  @override
  void descartar() {
    descartes++;
    _relogio?.cancel();
    _relogio = null;
    // Igual à arte real: quem espera o fim não pode ficar pendurado num objeto
    // que já morreu.
    concluirAgora();
  }
}
