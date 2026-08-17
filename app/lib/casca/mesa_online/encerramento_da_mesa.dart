// encerramento_da_mesa.dart — o EFEITO terminal da mesa online.
//
// ===========================================================================
// RETRATO E EFEITO SÃO COISAS DIFERENTES
// ===========================================================================
//
// A mesa JÁ desenha o desfecho: com `encerrada: true` na visão, o painel de
// resultado aparece e o placar passa a dizer "Partida encerrada". Isso é
// RETRATO — idempotente por natureza, e OBRIGADO a se repetir: quem cai e volta
// precisa ver a mesa de novo, inteira, inclusive o fim.
//
// O que este arquivo apresenta é o EFEITO: o aviso que interrompe, acontece UMA
// vez por encerramento e oferece a saída. Ele não pode se repetir — nem no
// reenvio, nem na reconexão —, e é por isso que não nasce da visão. Nasce do
// livro dos efeitos terminais (`LivroDeEfeitosTerminais`), o único lugar do
// aplicativo em que o fim declarado pelo servidor tem identidade suficiente
// (`eventoId`) e ciclo de vida próprio para se saber se aquele fim já foi
// APRESENTADO — que não é a mesma coisa que ter chegado.
//
// Inferir o efeito do retrato seria trocar as duas idempotências de lugar, e o
// resultado é visível: o diálogo voltaria a cada reconexão, para quem só caiu.
//
// ===========================================================================
// O QUE ESTE AVISO NÃO FAZ
// ===========================================================================
//
//   * NÃO LÊ A VISÃO. `EncerramentoAutoritativo.visao` viaja junto e não é
//     tocado aqui. Montar um texto a partir dele seria uma segunda leitura do
//     mapa cru fora do adaptador — e um segundo lugar onde o resultado é
//     interpretado, livre para divergir do primeiro. O resultado que a pessoa
//     lê é o da mesa, atrás do aviso, que veio do adaptador como sempre veio.
//   * NÃO CONTA PONTO, não concede conquista e não pontua ranking. Quem declara
//     o desfecho é o servidor.
//   * NÃO NAVEGA POR CONTA PRÓPRIA. Sair da mesa continua sendo gesto da
//     pessoa, e vai pelo mesmo caminho de sempre (a porta de comandos). Um
//     aviso que arrastasse a pessoa para outra tela tiraria dela o placar que
//     ela acabou de querer ver.
//   * NÃO TOCA SOM. A casca de produção não tem camada de áudio — o áudio do
//     aplicativo vive em `lib/mesa.dart`, que é a partida local e não passa por
//     aqui. Criar uma para esta fatia seria linguagem nova, que a OS proíbe.

import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/online_service.dart' show EncerramentoAutoritativo;

/// O que aconteceu com uma tentativa de apresentar o encerramento.
///
/// Existe porque quem chama precisa saber se pode CONFIRMAR o consumo. Enquanto
/// `apresentar` devolvia `void`, "chamei o apresentador" e "o aviso apareceu"
/// eram a mesma coisa para o chamador — e não são: um contexto que saiu da
/// árvore, uma rota sem navegador ou uma desistência no meio do caminho fazem a
/// chamada voltar sem que nada tenha sido mostrado. Confirmar ali marcaria como
/// visto um aviso que ninguém viu, que é exatamente o defeito que esta entrega
/// corrige.
enum ResultadoDaApresentacao {
  /// O aviso entrou na árvore. Só isto autoriza confirmar o consumo.
  apresentado,

  /// Tentou e não deu: não há navegador onde inserir o diálogo. O efeito volta
  /// a ficar pendente e espera a próxima entrada legítima na mesa.
  recusado,

  /// Nem tentou — o contexto já não estava montado quando a vez chegou. Vale o
  /// mesmo que [recusado] para quem chama; a distinção é de diagnóstico, e
  /// separa "a mesa sumiu debaixo do aviso" de "a mesa está lá e o aviso não
  /// coube".
  cancelado,
}

/// A paleta é a da mesa, repetida aqui pelos dois valores que o aviso usa.
/// Ele desenha SOBRE a mesa, e um cartão claro sobre o feltro verde seria uma
/// segunda linguagem visual.
const Color _feltro = Color(0xFF143D28);
const Color _ouroClaro = Color(0xFFF6E2A6);
const Color _texto = Color(0xFFEFE3CC);

/// Quem apresenta o encerramento para a pessoa.
///
/// É interface por duas razões. A de teste: o caso consegue provar QUANTAS
/// vezes o efeito aconteceu sem depender de diálogo desenhado, e um contador é
/// prova melhor do que um `find` numa árvore. A de projeto: o dono do ciclo de
/// vida da mesa não precisa saber o que é `showDialog` para saber QUANDO o
/// encerramento é seu.
abstract interface class ApresentadorDeEncerramento {
  /// Apresenta [encerramento] uma vez. Quem garante o "uma vez" é quem chama —
  /// a deduplicação por `eventoId` mora no `OnlineService`, e um segundo livro
  /// aqui seria uma segunda autoridade sobre o mesmo fato.
  ///
  /// [aoSairDaMesa] é a saída que o aviso oferece. Vem de fora porque sair da
  /// mesa é comando, e comando sai por uma porta só.
  ///
  /// O RETORNO COMPLETA ASSIM QUE O AVISO ENTRA NA ÁRVORE, e não quando a
  /// pessoa o fecha. Esperar o fechamento adiaria a confirmação do consumo pelo
  /// tempo que ela levasse lendo o placar — e nesse intervalo o aviso já está
  /// na tela, então tratá-lo como "ainda não apresentado" só criaria a chance
  /// de um segundo diálogo sobre o primeiro.
  Future<ResultadoDaApresentacao> apresentar(
    BuildContext context,
    EncerramentoAutoritativo encerramento, {
    required VoidCallback aoSairDaMesa,
  });
}

/// O aviso de produção: um diálogo sobre a mesa, com a saída.
class DialogoDeEncerramento implements ApresentadorDeEncerramento {
  const DialogoDeEncerramento();

  @override
  Future<ResultadoDaApresentacao> apresentar(
    BuildContext context,
    EncerramentoAutoritativo encerramento, {
    required VoidCallback aoSairDaMesa,
  }) async {
    // AS DUAS CONFERÊNCIAS ANTES DE TENTAR. Quem chama espera este método
    // acabar para decidir se marca o aviso como visto, e um `showDialog` que
    // estoure — ou que insira nada — mentiria pelas duas vias possíveis: a
    // exceção sobe por um `addPostFrameCallback` e vira erro sem dono, e o
    // sucesso silencioso confirma um diálogo que não existe.
    if (!context.mounted) return ResultadoDaApresentacao.cancelado;
    // `rootNavigator: true` porque é o que o `showDialog` abaixo usa por padrão:
    // conferir um navegador e empurrar noutro seria conferir o lugar errado.
    if (Navigator.maybeOf(context, rootNavigator: true) == null) {
      return ResultadoDaApresentacao.recusado;
    }

    // `encerramento` não é lido: ver o cabeçalho. Ele viaja na assinatura
    // porque a identidade do fim é do contrato, e um apresentador de
    // diagnóstico (ou o do teste) precisa dela.
    //
    // NÃO SE ESPERA O FUTURO: `showDialog` só completa quando a pessoa fecha o
    // aviso, e a inserção da rota já aconteceu quando ele volta. Aguardar aqui
    // seguraria a confirmação do consumo enquanto o diálogo estivesse aberto —
    // isto é, exatamente durante a janela em que um segundo diálogo seria pior.
    unawaited(
      showDialog<void>(
        context: context,
        // FECHÁVEL DE PROPÓSITO. O resultado está na mesa, atrás. Um aviso
        // intransponível prenderia justamente quem só quer conferir o placar
        // antes de decidir se sai.
        builder: (dialogo) => AlertDialog(
          backgroundColor: _feltro,
          title: const Text(
            'Fim da partida',
            style: TextStyle(color: _ouroClaro, fontWeight: FontWeight.w900),
          ),
          content: const Text(
            'O servidor encerrou esta partida. O resultado está na mesa, atrás '
            'deste aviso.',
            style: TextStyle(color: _texto, fontSize: 13, height: 1.35),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogo).pop(),
              child: const Text(
                'Ver a mesa',
                style: TextStyle(color: _texto, fontWeight: FontWeight.w700),
              ),
            ),
            TextButton(
              onPressed: () {
                // Fecha ANTES de sair: a saída troca o corpo da rota, e um
                // diálogo ainda montado sobre o lobby ficaria falando de uma
                // partida que não está mais na tela.
                Navigator.of(dialogo).pop();
                aoSairDaMesa();
              },
              child: const Text(
                'Sair da mesa',
                style: TextStyle(
                  color: _ouroClaro,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    return ResultadoDaApresentacao.apresentado;
  }
}
