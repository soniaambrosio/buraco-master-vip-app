// vinculo_compra_test.dart — a amarra entre a conta e a compra da Play.
//
// O QUE ESTA SUITE COBRE, E POR QUE ELA NAO EXISTIA
//
// A linhagem comercial entregou o cliente de Billing inteiro — catalogo, fluxo,
// validacao, reentrega — e NENHUM teste dela chamava `comprar()`. Os contadores
// `assinaturasAbertas` e `consumiveisAbertos` existiam no duble e nunca eram
// afirmados. O caminho que abre o dialogo da Play, que e por onde o dinheiro
// entra, era o unico sem prova.
//
// A composicao com a correcao P0 pos uma decisao nova exatamente ali: antes de
// abrir a compra, o aplicativo precisa obter do backend o identificador opaco
// que amarra a compra a conta. Sem ele a Google nao devolve dono, e o backend —
// corretamente — recusa. Um jogador que pagasse nessa situacao receberia
// `permission-denied` por uma compra ja cobrada.
//
// Por isso as tres recusas provadas aqui acontecem ANTES do dialogo, e nenhuma
// delas cobra nada de ninguem.
//
// A NUMERACAO E A DA OS (secao 15), para conferencia direta.

import 'package:buraco_master_vip/billing/catalogo.dart';
import 'package:buraco_master_vip/billing/servico_billing.dart';
import 'package:buraco_master_vip/billing/sessao.dart';
import 'package:buraco_master_vip/billing/validacao.dart';
import 'package:buraco_master_vip/billing/vinculo.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'dart:convert';
import 'dart:io';

import 'apoio/dubles.dart';

const _catalogoDeTeste = CatalogoBilling(
  assinaturas: <String>{'assinatura.de.teste'},
);

const _uidA = 'jogador-A';
const _uidB = 'jogador-B';

/// Identificadores com a forma que `prepararCompraPlay` emite: hexadecimal de
/// 48 caracteres. Visualmente distinguiveis para que uma falha diga de cara
/// qual conta estava em jogo.
const _vinculoA = '11111111111111111111111111111111111111111111aaaa';
const _vinculoB = '22222222222222222222222222222222222222222222bbbb';

final _produtoAssinatura = ProductDetails(
  id: 'assinatura.de.teste',
  title: 'VIP',
  description: 'assinatura de teste',
  price: 'R\$ 19,90',
  rawPrice: 19.90,
  currencyCode: 'BRL',
);

final _produtoConsumivel = ProductDetails(
  id: 'fichas.de.teste',
  title: 'Fichas',
  description: 'pacote de teste',
  price: 'R\$ 9,90',
  rawPrice: 9.90,
  currencyCode: 'BRL',
);

/// Sessao que troca de dono no meio do processo, como um logout/login faz.
class _SessaoMutavel implements SessaoJogador {
  _SessaoMutavel(this.uid);

  @override
  String? uid;
}

class _Cenario {
  _Cenario({String? uid = _uidA, String? vinculo = _vinculoA})
      : loja = LojaPlayFalsa(estaDisponivel: true),
        preparador = PreparadorFixo(vinculo),
        sessao = _SessaoMutavel(uid) {
    servico = ServicoBilling(
      loja: loja,
      validador: ValidadorRoteirizado((_) => const ResultadoValidacao(aprovada: true)),
      sessao: sessao,
      preparador: preparador,
      catalogo: _catalogoDeTeste,
      registrador: diario.add,
    );
  }

  final LojaPlayFalsa loja;
  final PreparadorFixo preparador;
  final _SessaoMutavel sessao;
  final List<String> diario = <String>[];
  late final ServicoBilling servico;
}

/// O codigo de `loja_play.dart`, SEM comentarios.
///
/// Varrer o arquivo inteiro faria a busca casar com a propria prosa — o
/// cabecalho daquele arquivo cita `applicationUserName` tres vezes explicando o
/// que ele faz. Um teste estrutural que se satisfaz com o proprio comentario nao
/// prova nada.
String _codigoDaLojaPlay() {
  final bruto = File('lib/billing/loja_play.dart').readAsStringSync();
  final linhas = const LineSplitter().convert(bruto);
  final semComentario =
      linhas.where((l) => !l.trimLeft().startsWith('//')).join(' ');
  // Espacos colapsados: uma chamada quebrada em duas linhas (`x.instance` numa,
  // `.metodo(` na outra) viraria `x.instance .metodo(` e escaparia da busca. Ja
  // aconteceu — foi assim que este teste ficou vermelho quando o seam entrou.
  return semComentario.replaceAll(RegExp(r'[ ]+'), ' ').replaceAll(' .', '.');
}

void main() {
  // =========================================================================
  group('VINC-1..3 — o dialogo da Play NAO abre sem amarra', () {
    test('1. sem sessao, a compra nao e aberta', () async {
      final c = _Cenario(uid: null);
      addTearDown(c.servico.descartar);

      final abriu = await c.servico.comprar(_produtoAssinatura);

      expect(abriu, isFalse);
      expect(c.loja.assinaturasAbertas, 0, reason: 'a Play foi aberta sem sessao');
      // E nem se gastou a chamada de preparacao: sem sessao ela responderia
      // `unauthenticated` de qualquer jeito.
      expect(c.preparador.chamadas, 0);
    });

    test('2. preparacao que falha impede a compra', () async {
      // `null` e o que o preparador real devolve quando a rede cai, quando a
      // funcao ainda nao foi publicada ou quando o backend recusa.
      final c = _Cenario(vinculo: null);
      addTearDown(c.servico.descartar);

      final abriu = await c.servico.comprar(_produtoAssinatura);

      expect(abriu, isFalse);
      expect(c.loja.assinaturasAbertas, 0);
      expect(c.preparador.chamadas, 1, reason: 'a preparacao precisa ter sido tentada');
    });

    test('3. vinculo mal formado impede a compra', () async {
      // Nao e paranoia: a Play Billing Library TRUNCA valores acima de 64, e um
      // identificador truncado nunca mais bate com o que o backend gravou. Abrir
      // a compra assim cobraria por um `permission-denied` garantido.
      for (final torto in <String>[
        'MAIUSCULAS_NAO_SAO_HEXADECIMAIS_1111111111111111',
        'curto',
        'f' * 65,
        '',
        'zz11111111111111111111111111111111111111111111zz',
      ]) {
        final c = _Cenario(vinculo: torto);
        addTearDown(c.servico.descartar);

        final abriu = await c.servico.comprar(_produtoAssinatura);

        expect(abriu, isFalse, reason: 'aceitou "$torto"');
        expect(c.loja.assinaturasAbertas, 0, reason: 'abriu a Play com "$torto"');
      }
    });
  });

  // =========================================================================
  group('VINC-4..5 — o que chega a Play e exatamente o que o backend concedeu', () {
    test('4. vinculo valido chega ao parametro da compra', () async {
      final c = _Cenario();
      addTearDown(c.servico.descartar);

      final abriu = await c.servico.comprar(_produtoAssinatura);

      expect(abriu, isTrue);
      expect(c.loja.assinaturasAbertas, 1);
      expect(c.loja.vinculosRecebidos, <String>[_vinculoA]);
    });

    test('4b. o consumivel tambem leva a amarra', () async {
      // `ProductPurchase` devolve o identificador na RAIZ da resposta, e o
      // backend o confere igual. Deixar o avulso de fora abriria a mesma porta
      // em metade do catalogo.
      final c = _Cenario();
      addTearDown(c.servico.descartar);

      await c.servico.comprar(_produtoConsumivel);

      expect(c.loja.consumiveisAbertos, 1);
      expect(c.loja.vinculosRecebidos, <String>[_vinculoA]);
    });

    test('5. o valor entregue e o do backend, sem transformacao', () async {
      // Sem recorte, sem normalizacao, sem prefixo. Qualquer transformacao aqui
      // faria o identificador deixar de bater com o indice do backend, e a
      // compra seria recusada por `vinculo_desconhecido`.
      const concedido = 'abcdef0123456789abcdef0123456789abcdef0123456789';
      final c = _Cenario(vinculo: concedido);
      addTearDown(c.servico.descartar);

      await c.servico.comprar(_produtoAssinatura);

      expect(c.loja.vinculosRecebidos.single, concedido);
    });
  });

  // =========================================================================
  group('VINC-6..8 — nada de identificavel viaja para a Google', () {
    test('6..8. uid, e-mail e publicId nao aparecem no que vai a Play', () async {
      // O proprio plugin avisa, na documentacao de `launchBillingFlow`, que
      // dado em claro neste campo faz a Google BLOQUEAR a compra. O valor e
      // opaco por construcao — bytes aleatorios do backend —, e este teste fixa
      // isso como contrato em vez de confianca.
      final c = _Cenario();
      addTearDown(c.servico.descartar);

      await c.servico.comprar(_produtoAssinatura);

      final enviado = c.loja.vinculosRecebidos.single;
      for (final agulha in <String>[
        _uidA,
        'jogador',
        'sonia@exemplo.invalid',
        '@',
        'publicId',
        'BMV-',
      ]) {
        expect(enviado.contains(agulha), isFalse,
            reason: 'o identificador carrega "$agulha"');
      }
      // So hexadecimal minusculo: nao ha onde esconder texto.
      expect(RegExp(r'^[0-9a-f]+$').hasMatch(enviado), isTrue);
    });

    test('9. a tela nao consegue substituir o identificador', () async {
      // `comprar()` aceita produto e plano-base, e mais nada. Nao ha parametro
      // por onde uma tela, um widget ou um deep link injetem o vinculo — e essa
      // ausencia E a garantia. Se um dia aparecer um, este teste nao compila.
      final c = _Cenario();
      addTearDown(c.servico.descartar);

      await c.servico.comprar(_produtoAssinatura, ofertaPlanoBase: 'oferta-mensal');

      expect(c.loja.vinculosRecebidos.single, _vinculoA,
          reason: 'o unico caminho para o vinculo e o preparador autenticado');
    });
  });

  // =========================================================================
  group('VINC-10..12 — o vinculo pertence a CONTA, nao ao processo', () {
    test('10. contas diferentes obtem identificadores distintos', () async {
      final a = _Cenario(uid: _uidA, vinculo: _vinculoA);
      final b = _Cenario(uid: _uidB, vinculo: _vinculoB);
      addTearDown(a.servico.descartar);
      addTearDown(b.servico.descartar);

      await a.servico.comprar(_produtoAssinatura);
      await b.servico.comprar(_produtoAssinatura);

      expect(a.loja.vinculosRecebidos.single, _vinculoA);
      expect(b.loja.vinculosRecebidos.single, _vinculoB);
      expect(a.loja.vinculosRecebidos.single,
          isNot(equals(b.loja.vinculosRecebidos.single)));
    });

    test('11. encerrar() elimina o vinculo de A', () async {
      final c = _Cenario();
      addTearDown(c.servico.descartar);

      await c.servico.comprar(_produtoAssinatura);
      expect(c.preparador.chamadas, 1);

      // O logout desliga o servico.
      await c.servico.encerrar();

      // A proxima compra tem de PREPARAR DE NOVO: se o vinculo tivesse
      // sobrevivido ao logout, ele estaria disponivel para a proxima conta.
      await c.servico.comprar(_produtoAssinatura);
      expect(c.preparador.chamadas, 2,
          reason: 'o vinculo sobreviveu ao logout');
    });

    test('12. a compra de B nao reutiliza o vinculo de A', () async {
      // O caso que fecha o defeito: A e B no MESMO processo, sem reinicio.
      final c = _Cenario(uid: _uidA, vinculo: _vinculoA);
      addTearDown(c.servico.descartar);

      await c.servico.comprar(_produtoAssinatura);
      expect(c.loja.vinculosRecebidos, <String>[_vinculoA]);

      // Troca de conta sem passar por `encerrar()` — o caso mais hostil, porque
      // nada avisou o servico. Quem percebe e o proprio cache, que e escopado
      // ao uid.
      c.sessao.uid = _uidB;
      c.preparador.vinculo = _vinculoB;

      await c.servico.comprar(_produtoAssinatura);

      expect(c.loja.vinculosRecebidos, <String>[_vinculoA, _vinculoB],
          reason: 'B comprou com o identificador de A');
      expect(c.preparador.chamadas, 2);
    });

    test('13. repetir a compra na mesma sessao nao reprepara, e nao muda de valor', () async {
      // O outro lado de 11 e 12: dentro de UMA sessao o identificador e estavel,
      // e a preparacao nao vira uma chamada por compra. Autoridade coerente
      // significa as duas coisas — nao trocar, e nao pedir de novo a toa.
      final c = _Cenario();
      addTearDown(c.servico.descartar);

      await c.servico.comprar(_produtoAssinatura);
      await c.servico.comprar(_produtoAssinatura);
      await c.servico.comprar(_produtoConsumivel);

      expect(c.preparador.chamadas, 1);
      expect(c.loja.vinculosRecebidos, <String>[_vinculoA, _vinculoA, _vinculoA]);
    });

    test('13b. preparacao que falhou nao fica em cache negativo', () async {
      // Se a primeira tentativa cair a rede, a segunda tem de tentar de novo —
      // um cache de `null` deixaria o jogador sem poder comprar ate reiniciar.
      final c = _Cenario(vinculo: null);
      addTearDown(c.servico.descartar);

      expect(await c.servico.comprar(_produtoAssinatura), isFalse);
      c.preparador.vinculo = _vinculoA;
      expect(await c.servico.comprar(_produtoAssinatura), isTrue);

      expect(c.preparador.chamadas, 2);
      expect(c.loja.vinculosRecebidos, <String>[_vinculoA]);
    });
  });

  // =========================================================================
  group('VINC-4c — a implementacao REAL entrega o vinculo ao plugin', () {
    // POR QUE ESTE TESTE E ESTRUTURAL, E POR QUE ISSO E UMA LIMITACAO ADMITIDA.
    //
    // Todos os outros testes desta suite passam pelo duble `LojaPlayFalsa`, que
    // recebe `vinculoDaConta` como parametro e o registra. Isso prova que o
    // SERVICO entrega o vinculo a porta — e nao prova nada sobre o que
    // `LojaPlayReal` faz com ele, porque aquela classe chama
    // `InAppPurchase.instance` direto e exige canal de plataforma.
    //
    // A prova negativa C6 encontrou exatamente essa lacuna: apagar
    // `applicationUserName` de `loja_play.dart` deixava os quinze testes verdes.
    // Enquanto `LojaPlayReal` nao receber o plugin por injecao, ler o codigo e a
    // unica prova disponivel — e uma prova fraca e melhor que a ausencia dela.

    test('4c. as duas compras passam o vinculo como applicationUserName', () {
      final codigo = _codigoDaLojaPlay();

      // O parametro precisa aparecer DUAS vezes: assinatura e consumivel.
      final ocorrencias =
          RegExp('applicationUserName: vinculoDaConta').allMatches(codigo).length;
      expect(ocorrencias, 2,
          reason: 'assinatura e consumivel precisam entregar o vinculo ao plugin');

      // E precisa estar dentro dos dois construtores de parametro de compra.
      expect(codigo.contains('GooglePlayPurchaseParam('), isTrue);
      expect(codigo.contains('PurchaseParam('), isTrue);
    });

    test('4c-b. nenhuma compra e aberta sem o parametro', () {
      // O ALVO DESTA CONTAGEM MUDOU COM O SEAM, e a mudanca vale registro.
      //
      // Antes, `LojaPlayReal` chamava `InAppPurchase.instance.buy*` direto, e a
      // conta era contra o singleton. Hoje ela chama `_plugin.buy*`, e quem toca
      // o singleton e `PluginDaPlayReal` — que nao monta parametro nenhum, so
      // repassa. Contar o singleton passou a medir o transporte em vez da regra.
      //
      // A invariante nao mudou: toda abertura de compra em `LojaPlayReal` leva a
      // amarra da conta.
      final codigo = _codigoDaLojaPlay();
      final compras = RegExp(r'_plugin.buy').allMatches(codigo).length;
      final vinculos =
          RegExp('applicationUserName: vinculoDaConta').allMatches(codigo).length;
      expect(compras, 2, reason: 'assinatura e consumivel');
      expect(vinculos, compras,
          reason: 'ha compra aberta sem amarra de conta em loja_play.dart');
    });
  });

  // =========================================================================
  group('VINC-14..15 — o resto do fluxo continua igual', () {
    test('14. a compra normal segue validar -> reconhecer -> completar', () async {
      // A amarra e um passo A MAIS, e nao um passo no lugar de outro. O veredito
      // continua sendo do backend, e a finalizacao continua acontecendo so
      // depois dele.
      final validadas = <CompraParaValidar>[];
      final loja = LojaPlayFalsa(estaDisponivel: true);
      final servico = ServicoBilling(
        loja: loja,
        validador: ValidadorRoteirizado((c) {
          validadas.add(c);
          return const ResultadoValidacao(aprovada: true);
        }),
        sessao: _SessaoMutavel(_uidA),
        preparador: PreparadorFixo(_vinculoA),
        catalogo: _catalogoDeTeste,
        registrador: (_) {},
      );
      addTearDown(servico.descartar);
      await servico.iniciar();

      final abriu = await servico.comprar(_produtoAssinatura);
      expect(abriu, isTrue);
      expect(loja.vinculosRecebidos, <String>[_vinculoA]);

      // A Play entrega a compra pelo fluxo, como faria de verdade. Os auxiliares
      // sao os mesmos da suite existente: `compraFalsa` monta o `PurchaseDetails`
      // e `cederAoLaco` espera o servico drenar o stream.
      loja.entregar(<PurchaseDetails>[
        compraFalsa('assinatura.de.teste', token: 'token_sintetico_composicao'),
      ]);
      await cederAoLaco();

      expect(validadas, hasLength(1), reason: 'o backend precisa ter sido consultado');
      expect(loja.finalizadas, hasLength(1),
          reason: 'a compra so se finaliza depois do veredito');
    });

    test('15. restore nao fabrica vinculo para compra antiga', () async {
      // Restaurar nao e comprar. O aplicativo nao pode "reassociar" uma compra
      // antiga entregando o vinculo da sessao atual: a propriedade daquela
      // compra e o que a Google devolver, e se ela nao trouxer identificador o
      // backend falha fechado e o caso vai para recuperacao separada.
      final c = _Cenario();
      addTearDown(c.servico.descartar);
      await c.servico.iniciar();

      await c.servico.restaurar();

      expect(c.loja.restauracoes, 1);
      expect(c.preparador.chamadas, 0,
          reason: 'o restore preparou um vinculo — isso e reassociar compra antiga');
      expect(c.loja.vinculosRecebidos, isEmpty);
    });
  });
}
