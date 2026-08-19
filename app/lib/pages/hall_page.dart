import 'package:flutter/material.dart';

import '../hall/hall_contract.dart';
import '../screens/hall_screen.dart';
import '../services/hall_service.dart';
import 'perfil_page.dart';
import 'ranking_page.dart';

/// Controlador do Hall dos Imortais (camada de lógica).
///
/// Substitui o `_HallPreviewHost` que vivia no `main.dart` e desenhava
/// `HallVM.mock()`. Quem é imortal vem do [HallService]; a camada Flutter só
/// posiciona o que recebeu sobre a arte oficial.
class HallPage extends StatefulWidget {
  const HallPage({super.key, this.service = const HallSemFonte()});

  /// Fonte do quadro. O padrão é a implementação honesta de “ainda não há fonte
  /// oficial”; trocar por uma fonte real é trocar este argumento.
  final HallService service;

  @override
  State<HallPage> createState() => _HallPageState();
}

class _HallPageState extends State<HallPage> {
  HallEstado _estado = HallEstado.carregando;
  HallVM _vm = HallVM.vazio;
  String? _erro;

  /// Numera as buscas: resposta de um pedido antigo (ou de uma tela já
  /// descartada) é ignorada em vez de sobrescrever a atual.
  int _geracao = 0;
  bool _descartado = false;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  @override
  void dispose() {
    _descartado = true;
    _geracao++;
    super.dispose();
  }

  Future<void> _carregar() async {
    final geracao = ++_geracao;
    setState(() {
      _estado = HallEstado.carregando;
      _erro = null;
    });

    try {
      final quadro = await widget.service.quadro();
      if (_ignorar(geracao)) return;
      setState(() {
        _vm = _paraVM(quadro);
        _estado = quadro.semHonrados ? HallEstado.vazio : HallEstado.disponivel;
      });
    } on HallIndisponivel catch (e) {
      if (_ignorar(geracao)) return;
      setState(() {
        _vm = HallVM.vazio;
        _estado = HallEstado.indisponivel;
        _erro = e.motivo;
      });
    } catch (_) {
      if (_ignorar(geracao)) return;
      setState(() {
        _vm = HallVM.vazio;
        _estado = HallEstado.erro;
        _erro = 'Não consegui abrir o Hall agora.';
      });
    }
  }

  bool _ignorar(int geracao) => _descartado || !mounted || geracao != _geracao;

  /// Tradução DTO → view-model. Não escolhe nem ordena nada: cada categoria
  /// recebe o homenageado que veio, e as estatísticas já vêm formatadas.
  HallVM _paraVM(HallQuadro quadro) {
    return HallVM(
      honrados: [
        for (final h in quadro.honrados)
          HonradoHall(
            categoria: h.categoria,
            id: h.id,
            nome: h.nome,
            avatar: h.avatar,
            avatar2: h.avatar2,
            stats: [for (final e in h.estatisticas) EstatHall(e)],
          ),
      ],
    );
  }

  void _aviso(String texto) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(texto),
          duration: const Duration(milliseconds: 1500),
          backgroundColor: const Color(0xFF2A1B0E),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return HallScreen(
      vm: _vm,
      estado: _estado,
      mensagemErro: _erro,
      onRecarregar: _carregar,
      onVoltar: () => Navigator.of(context).maybePop(),
      // A própria HallScreen abre o modal de regras; o host antigo abria um
      // SEGUNDO diálogo por cima, e os dois empilhavam. Aqui o callback só
      // registra a intenção.
      onVerRegras: () {},
      onVerPerfil: (id) {
        if (id.isEmpty) {
          _aviso('Este jogador ainda não tem perfil público.');
          return;
        }
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => PerfilPage(ehMeuPerfil: false, publicIdVisitado: id),
          ),
        );
      },
      // Presentear mexe em economia, que esta OS não pode tocar.
      onPresentear: (id) =>
          _aviso('Escolha um presente para homenagear este jogador 👑'),
      onEnviarPresente: (id, presenteId) =>
          _aviso('Envio de presente depende da economia — ainda não ligado.'),
      onNav: (destino) {
        switch (destino) {
          case 'ranking':
            Navigator.of(context).pushReplacement(
              MaterialPageRoute<void>(builder: (_) => const RankingPage()),
            );
            break;
          case 'perfil':
            Navigator.of(context).pushReplacement(
              MaterialPageRoute<void>(builder: (_) => const PerfilPage()),
            );
            break;
          case 'estatisticas':
            _aviso('Minhas estatísticas — ainda não publicadas por uma fonte.');
            break;
          case 'presentes':
            _aviso('Inventário de presentes depende da economia.');
            break;
          default:
            break;
        }
      },
    );
  }
}
