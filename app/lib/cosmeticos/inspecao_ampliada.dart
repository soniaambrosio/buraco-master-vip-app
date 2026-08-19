// inspecao_ampliada.dart — ver o item de perto, e SÓ ver.
//
// ---------------------------------------------------------------------------
// O QUE ESTE ARQUIVO É, E O QUE ELE DELIBERADAMENTE NÃO É
// ---------------------------------------------------------------------------
//
// A vitrine de cosméticos desenha cada item em 68x98 pixels dentro de um card
// de 130 de largura. A arte que a pessoa está prestes a comprar — uma moldura
// de Pérola Negra, um dorso Neon, um mascote Dragão de Cartas — chega a ela do
// tamanho de uma unha. Comprar às cegas é o que essa miniatura pede.
//
// A inspeção ampliada resolve isso do jeito mais barato possível: um toque na
// ARTE abre a mesma arte grande, centralizada, por cima de tudo. E é só.
//
// O QUE ELA NÃO FAZ, e por que a ausência é o recurso:
//
//   não compra          não equipa         não seleciona
//   não altera saldo    não chama backend  não altera inventário
//
// Isso não é uma promessa escrita num comentário: é uma propriedade da FORMA
// deste arquivo. [InspecaoAmpliada] e [AlvoDeInspecao] não recebem callback
// nenhum — não há `VoidCallback`, `ValueChanged` nem `Function` em campo algum
// aqui dentro. Um widget sem saída não tem como acionar compra: para
// transformar inspeção em compra seria preciso ACRESCENTAR um parâmetro, e a
// auditoria estrutural da suíte reprova exatamente isso.
//
// Pelo mesmo motivo o único `import` é o do Material. Nada de serviço, nada de
// Firebase, nada de carteira. Um arquivo que não conhece o backend não o chama.
//
// ---------------------------------------------------------------------------
// POR QUE O ALVO DE TOQUE É IRMÃO DO BOTÃO, E NUNCA SEU ANCESTRAL
// ---------------------------------------------------------------------------
//
// O risco real desta funcionalidade é o toque ambíguo: a pessoa quer ver a
// moldura de perto e acaba comprando. Envolver o CARD inteiro num detector e
// confiar na arena de gestos do Flutter para o botão ganhar seria apostar num
// detalhe de implementação.
//
// Aqui a garantia é estrutural. [AlvoDeInspecao] envolve SOMENTE a região da
// arte, que é IRMÃ da linha de ações no `Column` do card — nunca ancestral
// dela. Dois nós irmãos não disputam o mesmo toque: um toque em Comprar nunca
// atravessa o alvo de ampliação, e um toque na arte nunca alcança Comprar,
// porque as áreas são disjuntas por construção do layout.
//
// A suíte prova isso com `find.descendant`: se alguém um dia envolver o card
// inteiro, o botão passa a ser descendente do alvo e o caso reprova.
//
// ---------------------------------------------------------------------------
// TRÊS SAÍDAS, E NENHUMA DELAS OPCIONAL
// ---------------------------------------------------------------------------
//
// Fecha por toque fora (`barrierDismissible`), pelo X (o `IconButton`) e pelo
// voltar do sistema (a rota de diálogo, que não é interceptada por `PopScope`
// nenhum). Uma inspeção que prende a pessoa é pior do que não existir, e por
// isso os três caminhos têm caso próprio na suíte.

import 'package:flutter/material.dart';

/// A que família de cosmético o item pertence.
///
/// A lista cobre as oito categorias que a OS enumera. Três delas — [mesa],
/// [balao] e [efeitoDeEntrada] — ainda não têm catálogo nesta base: a Loja
/// vende dorsos, molduras, avatares, mascotes, efeitos de vitória e emojis. Os
/// valores existem mesmo assim porque a inspeção é a MESMA para todas, e a
/// suíte exercita as oito pelo widget compartilhado. Quando a vitrine de
/// feltros nascer, ela não inaugura comportamento: só passa a categoria.
///
/// [colecionavel] é a saída honesta para o que chega sem família declarada — a
/// vitrine do Perfil identifica cada slot por `String`, e inventar "Moldura"
/// para um slot desconhecido seria afirmar o que ninguém conferiu.
enum CategoriaInspecao {
  moldura,
  verso,
  mesa,
  mascote,
  emoji,
  balao,
  presente,
  efeitoDeEntrada,
  efeitoDeVitoria,
  avatar,
  colecionavel,
}

extension CategoriaInspecaoRotulo on CategoriaInspecao {
  String get rotulo {
    switch (this) {
      case CategoriaInspecao.moldura:
        return 'Moldura';
      case CategoriaInspecao.verso:
        return 'Verso de carta';
      case CategoriaInspecao.mesa:
        return 'Mesa e feltro';
      case CategoriaInspecao.mascote:
        return 'Mascote';
      case CategoriaInspecao.emoji:
        return 'Emoji';
      case CategoriaInspecao.balao:
        return 'Balão';
      case CategoriaInspecao.presente:
        return 'Presente';
      case CategoriaInspecao.efeitoDeEntrada:
        return 'Efeito de entrada';
      case CategoriaInspecao.efeitoDeVitoria:
        return 'Efeito de vitória';
      case CategoriaInspecao.avatar:
        return 'Avatar';
      case CategoriaInspecao.colecionavel:
        return 'Colecionável';
    }
  }
}

/// Os nomes de slot que cada família reconhece.
///
/// O mapa é indexado PELA FAMÍLIA, e não pelo nome do slot, embora a consulta
/// vá no sentido contrário. Não é capricho: um mapa `{'avatar': ...}` colocaria
/// a palavra `avatar` seguida de dois-pontos no código de produção, que é
/// exatamente a forma que a auditoria da identidade pública persegue para
/// impedir que um segundo dono do avatar nasça sem ninguém ver. Indexar pela
/// família diz a mesma coisa e não se parece com o defeito.
const Map<CategoriaInspecao, List<String>> _slotsConhecidos = {
  CategoriaInspecao.avatar: ['avatar'],
  CategoriaInspecao.moldura: ['moldura'],
  CategoriaInspecao.mascote: ['mascote'],
  CategoriaInspecao.verso: ['dorso', 'verso'],
  CategoriaInspecao.mesa: ['mesa', 'feltro'],
  CategoriaInspecao.balao: ['balao'],
  CategoriaInspecao.emoji: ['emoji'],
  CategoriaInspecao.presente: ['presente'],
  CategoriaInspecao.efeitoDeVitoria: ['efeito'],
  CategoriaInspecao.efeitoDeEntrada: ['entrada'],
};

/// A família de um slot da vitrine do Perfil.
///
/// O slot chega como `String` livre, e por isso a função é TOTAL: o que esta
/// lista não conhece vira [CategoriaInspecao.colecionavel] e continua
/// inspecionável. Chutar "Moldura" para um slot desconhecido seria afirmar
/// sobre o item algo que ninguém conferiu — e a arte, que é o que a pessoa quer
/// ver, aparece do mesmo jeito.
CategoriaInspecao familiaDoSlot(String slot) {
  for (final entrada in _slotsConhecidos.entries) {
    if (entrada.value.contains(slot)) return entrada.key;
  }
  return CategoriaInspecao.colecionavel;
}

/// Em que pé o item está PARA QUEM OLHA.
///
/// A OS exige as três primeiras. [disponivel] é a quarta, e não é enfeite: na
/// vitrine da Loja o estado mais comum é "existe, está à venda, não é seu" — e
/// chamá-lo de bloqueado seria mentir sobre um cadeado que não existe.
enum EstadoInspecao { bloqueado, disponivel, adquirido, equipado }

extension EstadoInspecaoRotulo on EstadoInspecao {
  /// O que o selo diz.
  ///
  /// Nenhum destes textos é um convite a agir. "Comprar" e "Equipar" são
  /// palavras dos BOTÕES do card, e não podem aparecer numa tela que não faz
  /// nem uma coisa nem outra — a suíte varre este arquivo atrás delas.
  String get rotulo {
    switch (this) {
      case EstadoInspecao.bloqueado:
        return '🔒 Bloqueado';
      case EstadoInspecao.disponivel:
        return 'Ainda não é seu';
      case EstadoInspecao.adquirido:
        return 'Você tem este item';
      case EstadoInspecao.equipado:
        return '✓ Em uso';
    }
  }
}

/// O item, reduzido ao que a inspeção precisa saber.
///
/// Repare no que NÃO está aqui: preço, moeda, saldo, se dá para presentear.
/// Nada disso é necessário para ver a arte de perto, e tudo isso é o que uma
/// tela precisaria para virar uma tela de compra.
@immutable
class ItemInspecionavel {
  /// Identidade do item — usada só para distinguir uma inspeção da seguinte.
  final String id;

  final String nome;
  final CategoriaInspecao categoria;
  final EstadoInspecao estado;

  /// A arte: um caminho `assets/...` ou um glifo (emoji) desenhado como texto.
  ///
  /// A vitrine do Perfil guarda mascote como `'🦊'` e moldura como
  /// `'assets/perfil/vitrine_moldura.webp'` no MESMO campo, e a inspeção tem
  /// de aceitar os dois sem que a chamadora precise saber qual é qual.
  final String previa;

  /// Linha livre de contexto — raridade, quantidade recebida. Texto puro.
  final String? detalhe;

  const ItemInspecionavel({
    required this.id,
    required this.nome,
    required this.categoria,
    required this.estado,
    required this.previa,
    this.detalhe,
  });
}

/// Abre a inspeção ampliada de [item] por cima da tela atual.
///
/// Devolve `Future<void>`: não há resultado a colher, porque não há decisão a
/// tomar. Quem chama não fica sabendo COMO fechou, e isso é de propósito —
/// nenhum dos três caminhos de saída pode ter consequência diferente dos
/// outros dois.
Future<void> abrirInspecaoAmpliada(BuildContext context, ItemInspecionavel item) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Fechar a inspeção de ${item.nome}',
    barrierColor: const Color(0xD9000000),
    builder: (_) => InspecaoAmpliada(item: item),
  );
}

/// A região tocável que abre a inspeção.
///
/// Envolve SOMENTE a arte. Ver o cabeçalho do arquivo para o porquê de isso
/// ser uma garantia e não um cuidado.
class AlvoDeInspecao extends StatelessWidget {
  final ItemInspecionavel item;
  final Widget child;

  const AlvoDeInspecao({super.key, required this.item, required this.child});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Ampliar ${item.nome}',
      child: GestureDetector(
        // Opaco para que o espaço vazio em volta de uma arte estreita — um
        // dorso de carta ocupa metade do quadrado — também abra a inspeção.
        behavior: HitTestBehavior.opaque,
        onTap: () => abrirInspecaoAmpliada(context, item),
        child: child,
      ),
    );
  }
}

/// O conteúdo da inspeção.
///
/// Público de propósito: a suíte monta este widget direto, sem passar pela
/// Loja nem pelo Perfil, para provar as onze categorias e os quatro estados
/// sem depender de catálogo nenhum.
class InspecaoAmpliada extends StatelessWidget {
  static const _ouro = Color(0xFFEFB94A);
  static const _ouroClaro = Color(0xFFF6E2A6);
  static const _textoSec = Color(0xFFB6A884);

  final ItemInspecionavel item;

  const InspecaoAmpliada({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    // A arte acompanha a altura da tela, e nunca passa de 260: acima disso o
    // cabeçalho e o selo começam a ser empurrados para fora em telefones
    // baixos, e uma inspeção que estoura o layout não é uma inspeção.
    final altura = (MediaQuery.sizeOf(context).height * .34).clamp(140.0, 260.0);

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 26),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 380),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF2A1C10), Color(0xFF140C06)],
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _ouro.withValues(alpha: .55), width: 1.4),
          boxShadow: const [
            BoxShadow(color: Colors.black87, blurRadius: 26, offset: Offset(0, 8)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _cabecalho(context),
            SizedBox(
              height: altura,
              child: Semantics(
                image: true,
                label: '${item.nome}, ${item.categoria.rotulo}, ampliado',
                child: _arte(),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              item.nome,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _ouroClaro,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (item.detalhe != null) ...[
              const SizedBox(height: 4),
              Text(
                item.detalhe!,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: _textoSec, fontSize: 12),
              ),
            ],
            const SizedBox(height: 10),
            Align(alignment: Alignment.center, child: _selo()),
          ],
        ),
      ),
    );
  }

  Widget _cabecalho(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            item.categoria.rotulo,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _ouro,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.6,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Fechar',
          onPressed: () => Navigator.of(context).pop(),
          // `semanticLabel` E `tooltip`, e não um dos dois: o tooltip vira a
          // propriedade `tooltip` do nó de semântica, que um leitor de tela
          // pode anunciar depois — ou não anunciar. O rótulo é o que garante
          // que o botão tenha NOME para quem navega sem enxergar, e é por ele
          // que a suíte encontra a saída.
          icon: const Icon(
            Icons.close_rounded,
            color: _ouroClaro,
            size: 22,
            semanticLabel: 'Fechar',
          ),
        ),
      ],
    );
  }

  /// A arte, na proporção em que foi desenhada.
  ///
  /// `BoxFit.contain` é a regra e não tem exceção: `cover` recortaria a
  /// moldura pelas bordas e `fill` esticaria o dorso até virar outro desenho.
  /// Ampliar um item e mostrar uma versão distorcida dele é pior do que a
  /// miniatura, porque a miniatura pelo menos não mente sobre a forma.
  Widget _arte() {
    if (item.previa.startsWith('assets/')) {
      return Image.asset(
        item.previa,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        errorBuilder: (_, _, _) => const Center(
          child: Icon(Icons.auto_awesome_rounded, color: _ouro, size: 72),
        ),
      );
    }
    // Emoji e glifos: o `FittedBox` cresce o texto até o limite da caixa sem
    // deformá-lo, que é o mesmo contrato do `contain`.
    return FittedBox(
      fit: BoxFit.contain,
      child: Text(item.previa, style: const TextStyle(fontSize: 96)),
    );
  }

  Widget _selo() {
    final cor = switch (item.estado) {
      EstadoInspecao.bloqueado => const Color(0xFF8A7C5E),
      EstadoInspecao.disponivel => _ouro,
      EstadoInspecao.adquirido => const Color(0xFFB98BFF),
      EstadoInspecao.equipado => const Color(0xFF5BE0A2),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: cor.withValues(alpha: .6)),
      ),
      child: Text(
        item.estado.rotulo,
        textAlign: TextAlign.center,
        style: TextStyle(color: cor, fontSize: 12, fontWeight: FontWeight.w900),
      ),
    );
  }
}
