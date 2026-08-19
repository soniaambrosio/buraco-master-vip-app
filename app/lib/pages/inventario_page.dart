// inventario_page.dart — a vitrine do que o jogador JA POSSUI.
//
// Primeira superficie produtiva do modulo de colecoes. O dominio e o contrato
// existiam desde a entrega do Kit Pioneiros 2026 e nao tinham nenhuma tela
// consumindo — o jogador recebia os itens e nao tinha onde ve-los.
//
// O QUE ESTA TELA NAO E
// Nao e loja. Nao ha preco, saldo, compra, oferta nem cadeado, e nada aqui
// concede coisa alguma. Um item so e desenhado se
// [InventarioUsuario.possui] disser que e do jogador — a lista vem de
// [montarInventarioVM], que itera o INVENTARIO e nunca o catalogo. Um item que
// o jogador nao tem simplesmente nao existe nesta tela, e nem como silhueta.
//
// Tambem nao e a inspecao ampliada de cosmeticos: tocar num item nao abre zoom.
// Aquilo tem responsabilidade propria e fica de fora de proposito.
//
// AS REGRAS DE ARTE SAO DO CONTRATO, NAO DESTE ARQUIVO
// [RegrasDeExibicao] existe porque as artes 03, 04, 05, 07 e 08 ocupam quase
// todo o canvas de 1254x1254. Este arquivo LE aquelas constantes em vez de
// repetir os valores: `cover`, clip oval ou padding menor cortariam faixa,
// asas, cetro, coroa ou base.

import 'package:flutter/material.dart';

import '../colecoes/colecao_inventario.dart';
import '../colecoes/colecao_ui_contract.dart';
import '../services/inventario_service.dart';
import '../sessao/escopo_sessao.dart';

/// Paleta local. Fundo escuro neutro, como [RegrasDeExibicao.fundoEscuroNeutro]
/// exige: a arte tem alpha real e foi aprovada sobre preto/dourado.
const _fundo = Color(0xFF120D07);
const _superficie = Color(0xFF1F1710);
const _ouro = Color(0xFFD9A94A);
const _texto = Color(0xFFF3E9D6);
const _textoFraco = Color(0xFFB09A78);

class InventarioPage extends StatefulWidget {
  const InventarioPage({super.key, this.serviceParaTeste});

  /// Injeta um serviço já pronto. Só os testes usam: em produção a página cria
  /// o seu, ligado ao Firestore real.
  final InventarioService? serviceParaTeste;

  @override
  State<InventarioPage> createState() => _InventarioPageState();
}

class _InventarioPageState extends State<InventarioPage> {
  late final InventarioService _service =
      widget.serviceParaTeste ?? InventarioService();

  InventarioVM _vm = const InventarioVM.carregando();

  /// UID com que o VM atual foi montado. É o que distingue "a sessão mudou" de
  /// "o widget reconstruiu" — sem isto, um `build` viraria consulta.
  String? _uidCarregado;
  bool _jaCarregou = false;

  /// Item cuja equipagem está em voo. Bloqueia o botão daquele card só, e não a
  /// tela inteira: travar tudo por uma escrita de um item faria a lista piscar.
  String? _equipando;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final uid = EscopoSessao.identidadeDe(context).uid;
    if (_jaCarregou && uid == _uidCarregado) return;
    _jaCarregou = true;
    _uidCarregado = uid;
    _carregar();
  }

  Future<void> _carregar() async {
    final uid = _uidCarregado;
    setState(() => _vm = const InventarioVM.carregando());
    try {
      final vm = await _service.carregar(uid);
      // null = esta leitura foi superada por outra mais nova (troca de conta, ou
      // um "tentar de novo" durante uma leitura lenta). Sair sem `setState`
      // deixa a leitura vencedora mandar no que aparece.
      if (vm == null || !mounted) return;
      setState(() => _vm = vm);
    } on InventarioIndisponivel catch (e) {
      if (!mounted) return;
      setState(() => _vm = InventarioVM.erro(e.motivo));
    } catch (_) {
      if (!mounted) return;
      setState(() =>
          _vm = const InventarioVM.erro('Não consegui carregar teus itens agora.'));
    }
  }

  Future<void> _equipar(String itemId) async {
    // Lido da sessão canônica NO MOMENTO DO TOQUE, e não do campo desta tela: se
    // a conta trocou entre o desenho do card e o toque, o pedido tem de sair com
    // o dono atual — e o serviço recusa, porque o inventário em memória é do
    // outro. O campo serviria para a comparação de recarga, não para autorizar
    // uma escrita.
    final uid = EscopoSessao.identidadeDe(context).uid;
    if (uid == null || _equipando != null) return;
    setState(() => _equipando = itemId);
    try {
      final resultado = await _service.equipar(uid, itemId);
      if (!mounted) return;
      setState(() {
        _vm = resultado.vm;
        _equipando = null;
      });
      if (!resultado.aceita) {
        _avisar(_motivoDaRecusa(resultado.recusa!));
      }
    } on InventarioIndisponivel catch (e) {
      if (!mounted) return;
      setState(() => _equipando = null);
      _avisar(e.motivo);
    }
  }

  /// Traduz a recusa do domínio. Cada motivo tem texto próprio: "não deu certo"
  /// para tudo transformaria uma regra explicada em chamado de suporte.
  static String _motivoDaRecusa(RecusaEquipagem recusa) => switch (recusa) {
        RecusaEquipagem.itemInexistente =>
          'Esta peça não existe nesta versão do jogo.',
        RecusaEquipagem.itemNaoPossuido => 'Esta peça não é tua.',
        RecusaEquipagem.itemNaoEquipavel =>
          'Esta peça é de exibição — não vai para a vitrine.',
        RecusaEquipagem.itemDesabilitado =>
          'Esta peça está indisponível no momento. Ela continua tua.',
        RecusaEquipagem.slotDesconhecido =>
          'Ainda não há lugar na vitrine para esta peça.',
        RecusaEquipagem.slotCheio =>
          'Esse lugar da vitrine está cheio. Tira uma peça antes.',
        RecusaEquipagem.jaEquipado => 'Esta peça já está na tua vitrine.',
        RecusaEquipagem.naoEstavaEquipado =>
          'Esta peça não estava na tua vitrine.',
      };

  void _avisar(String texto) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(texto),
        duration: const Duration(milliseconds: 1800),
        backgroundColor: const Color(0xFF2A1B0E),
      ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _fundo,
      appBar: AppBar(
        backgroundColor: _fundo,
        foregroundColor: _texto,
        elevation: 0,
        title: const Text('Meus itens'),
        actions: [
          if (_vm.estado == EstadoInventario.pronto)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  '${_vm.totalItens} ${_vm.totalItens == 1 ? "peça" : "peças"}',
                  style: const TextStyle(color: _textoFraco, fontSize: 13),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(child: _corpo()),
    );
  }

  Widget _corpo() => switch (_vm.estado) {
        EstadoInventario.carregando =>
          const Center(child: CircularProgressIndicator(color: _ouro)),
        EstadoInventario.semSessao => const _Recado(
            icone: Icons.lock_outline,
            titulo: 'Entra na tua conta',
            corpo: 'Teus itens ficam guardados na tua conta.',
          ),
        // Vazio é vazio: nenhuma oferta, nenhum "veja o que você poderia ter".
        EstadoInventario.vazio => const _Recado(
            icone: Icons.inventory_2_outlined,
            titulo: 'Nada por aqui ainda',
            corpo: 'Quando você ganhar peças de coleção, elas aparecem aqui.',
          ),
        EstadoInventario.erro => _Recado(
            icone: Icons.cloud_off,
            titulo: 'Não deu para carregar',
            corpo: _vm.mensagemErro ?? '',
            aoTentarDeNovo: _carregar,
          ),
        EstadoInventario.pronto => _lista(),
      };

  Widget _lista() {
    return RefreshIndicator(
      color: _ouro,
      backgroundColor: _superficie,
      onRefresh: _carregar,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          for (final grupo in _vm.grupos) _Grupo(
            grupo: grupo,
            equipando: _equipando,
            aoEquipar: _equipar,
          ),
          if (_vm.temItensSemDefinicao) _AvisoVersao(quantos: _vm.itensSemDefinicao),
        ],
      ),
    );
  }
}

/// Cabeçalho + grade de uma coleção.
class _Grupo extends StatelessWidget {
  const _Grupo({
    required this.grupo,
    required this.equipando,
    required this.aoEquipar,
  });

  final GrupoInventario grupo;
  final String? equipando;
  final void Function(String itemId) aoEquipar;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Text(
                grupo.displayName,
                style: const TextStyle(
                  color: _texto,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            // "3 de 10" é contagem, não convite: diz o tamanho do acervo, e não
            // oferece o que falta.
            Text(
              '${grupo.possuidos} de ${grupo.totalNaColecao}',
              style: const TextStyle(color: _textoFraco, fontSize: 13),
            ),
          ],
        ),
        if (grupo.completa)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              'Coleção completa',
              style: TextStyle(
                  color: _ouro, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: grupo.itens.length,
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 180,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.72,
          ),
          itemBuilder: (_, i) {
            final item = grupo.itens[i];
            return _Card(
              item: item,
              ocupado: equipando != null,
              emVoo: equipando == item.id,
              aoEquipar: () => aoEquipar(item.id),
            );
          },
        ),
      ],
    );
  }
}

/// Um item possuído.
class _Card extends StatelessWidget {
  const _Card({
    required this.item,
    required this.ocupado,
    required this.emVoo,
    required this.aoEquipar,
  });

  final RecompensaVM item;

  /// Alguma equipagem está em voo (talvez de outro card).
  final bool ocupado;

  /// É ESTE card que está em voo.
  final bool emVoo;

  final VoidCallback aoEquipar;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _superficie,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: item.equipped ? _ouro : Colors.white10,
          width: item.equipped ? 1.6 : 1,
        ),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Semantics(
              label: item.accessibilityLabel,
              image: true,
              child: _Arte(assetPath: item.assetPath),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            item.displayName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _texto, fontSize: 12, height: 1.2),
          ),
          const SizedBox(height: 6),
          _acao(),
        ],
      ),
    );
  }

  /// A ação segue a autoridade, e não a estética.
  ///
  /// `canEquip` já é `owned && equipável && habilitado && !equipado`, calculado
  /// em [RecompensaVM.de]. Item que não é equipável (o Baú) não ganha botão
  /// desabilitado: ganha um rótulo dizendo o que ele é. Botão cinza convida a
  /// insistir numa ação que não existe.
  Widget _acao() {
    if (item.equipped) {
      return const _Selo(texto: 'Na vitrine', cor: _ouro);
    }
    if (!item.canEquip) {
      return _Selo(
        texto: item.slot == null ? 'Peça de exibição' : 'Indisponível',
        cor: _textoFraco,
      );
    }
    return SizedBox(
      height: 30,
      child: FilledButton(
        onPressed: ocupado ? null : aoEquipar,
        style: FilledButton.styleFrom(
          backgroundColor: _ouro,
          foregroundColor: const Color(0xFF241A0B),
          padding: EdgeInsets.zero,
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
        child: emVoo
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Color(0xFF241A0B)),
              )
            : const Text('Equipar'),
      ),
    );
  }
}

/// A arte da peça, sob as regras de [RegrasDeExibicao].
class _Arte extends StatelessWidget {
  const _Arte({required this.assetPath});

  /// null quando a arte não é do bundle. Nenhuma peça é assim hoje.
  final String? assetPath;

  @override
  Widget build(BuildContext context) {
    final caminho = assetPath;
    if (caminho == null) {
      // Fonte remota sem resolvedor: mostra a ausência em vez de um quadrado
      // vazio que parece arte quebrada.
      return const Center(
        child: Icon(Icons.image_not_supported_outlined, color: _textoFraco),
      );
    }
    return LayoutBuilder(
      builder: (_, restricoes) {
        // A margem sai da constante do contrato, e não de um número escolhido
        // aqui: as artes que encostam na borda ficariam cortadas.
        final lado = restricoes.biggest.shortestSide;
        return Padding(
          padding: EdgeInsets.all(lado * RegrasDeExibicao.paddingVisualMinimo),
          child: Image.asset(
            caminho,
            // `contain`, nunca `cover`: `cover` recorta faixa, asas e cetro.
            fit: BoxFit.contain,
            // Sem `color` e sem container pintado atrás: o PNG tem alpha real e
            // o fundo é da tela, não da peça.
            filterQuality: FilterQuality.medium,
            errorBuilder: (_, __, ___) => const Center(
              child: Icon(Icons.broken_image_outlined, color: _textoFraco),
            ),
          ),
        );
      },
    );
  }
}

class _Selo extends StatelessWidget {
  const _Selo({required this.texto, required this.cor});

  final String texto;
  final Color cor;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 30,
        child: Center(
          child: Text(
            texto,
            style: TextStyle(color: cor, fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ),
      );
}

/// Estado sem lista: sessão ausente, acervo vazio ou falha.
class _Recado extends StatelessWidget {
  const _Recado({
    required this.icone,
    required this.titulo,
    required this.corpo,
    this.aoTentarDeNovo,
  });

  final IconData icone;
  final String titulo;
  final String corpo;
  final VoidCallback? aoTentarDeNovo;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icone, color: _textoFraco, size: 46),
            const SizedBox(height: 16),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: _texto, fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              corpo,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _textoFraco, fontSize: 14, height: 1.4),
            ),
            if (aoTentarDeNovo != null) ...[
              const SizedBox(height: 20),
              FilledButton(
                onPressed: aoTentarDeNovo,
                style: FilledButton.styleFrom(
                  backgroundColor: _ouro,
                  foregroundColor: const Color(0xFF241A0B),
                ),
                child: const Text('Tentar de novo'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Há peças possuídas que esta versão do aplicativo não sabe desenhar.
///
/// Dito em voz alta de propósito: some-las faria o jogador contar menos itens do
/// que realmente tem e concluir que perdeu alguma coisa.
class _AvisoVersao extends StatelessWidget {
  const _AvisoVersao({required this.quantos});

  final int quantos;

  @override
  Widget build(BuildContext context) {
    final peca = quantos == 1 ? 'peça' : 'peças';
    final nova = quantos == 1 ? 'nova' : 'novas';
    final pronome = quantos == 1 ? 'vê-la' : 'vê-las';
    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _superficie,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.system_update_alt, color: _textoFraco, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Você tem mais $quantos $peca $nova. Atualiza o jogo para $pronome.',
              style: const TextStyle(color: _textoFraco, fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
