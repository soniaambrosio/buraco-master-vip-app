import 'package:flutter/material.dart';

import '../screens/torneio_modelo_screen.dart';
import '../screens/torneios_models.dart';
import '../screens/torneios_screens.dart';

/// Host visual sobre mocks. O Claude troca apenas a fonte dos VMs e os callbacks.
class TorneiosPreviewPage extends StatefulWidget {
  const TorneiosPreviewPage({super.key});

  @override
  State<TorneiosPreviewPage> createState() => _TorneiosPreviewPageState();
}

class _TorneiosPreviewPageState extends State<TorneiosPreviewPage> {
  void _toast(String texto) {
    if (!mounted) return;
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

  TorneiosCallbacks get _callbacks => TorneiosCallbacks(
        onAbrirDetalhes: _abrirDetalhes,
        onInscrever: _abrirInscricao,
        onConfirmarInscricao: (id, {parceiroId, required regrasLidas}) {
          _toast('Inscrição confirmada em $id${parceiroId == null ? '' : ' com $parceiroId'} (mock)');
        },
        onConvidarParceiro: (id, playerId) => _toast('Convite enviado para $playerId em $id'),
        onAceitarConvite: (id) => _toast('Dupla confirmada em $id'),
        onCancelarConvite: (id) => _toast('Convite cancelado em $id'),
        onCancelarInscricao: (id) => _toast('Cancelamento solicitado em $id'),
        onFazerCheckin: (id) {
          _toast('Check-in realizado (mock)');
          _abrirSala(id);
        },
        onEntrarSalaEspera: _abrirSala,
        onEntrarNaMesa: _previewMesaExistente,
        onVerClassificacao: _abrirClassificacao,
        onVerResultado: _abrirResultado,
        onResgatarPremio: (id) => _toast('Resgate de $id enviado ao Claude'),
        onCompartilharConquista: (id) => _toast('Cartão de conquista preparado para $id'),
        onFiltrarCentral: (filtros) => _toast('${filtros.length} filtro(s) ativo(s)'),
        onCriarModelo: () => _abrirModelo(null),
        onEditarModelo: _abrirModelo,
        onSalvarModelo: (form) => _toast('Modelo “${form.nome}” pronto para persistência'),
        onAcaoAdmin: (id, acao) => _toast('${acao.name} em $id — registro fica com o Claude'),
      );

  @override
  Widget build(BuildContext context) {
    return CentralTorneiosScreen(
      torneios: TorneiosMockData.cards(),
      callbacks: _callbacks,
      onVoltar: () => Navigator.of(context).maybePop(),
      // SEM `autoridade` e SEM `onAbrirAdmin`, e as duas ausências são a
      // entrega desta OS neste arquivo.
      //
      // Aqui estava `mostrarAdmin: true` — um literal, no host, decidindo que
      // quem abrisse a Central administrava torneios. E estava
      // `onAbrirCenariosMock`, que punha na barra de uma tela de produto um
      // atalho de laboratório com trinta e tantos estados encenados.
      //
      // Este host não tem sessão em escopo, logo não tem autoridade nenhuma a
      // oferecer — e o padrão `SemPapel` da Central é exatamente essa verdade.
      // Quando a Central for ligada à Casca de produção, quem a construir passa
      // `autoridadeAdministrativaDe(sessao)` (ver
      // `casca/autoridade_administrativa_de_producao.dart`); até lá, ninguém
      // vê a área de gestão, que é o correto e não uma pendência.
    );
  }


  void _abrirDetalhes(String id) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TorneioDetalhesScreen(
          vm: TorneiosMockData.detalhes(id),
          callbacks: _callbacks,
          onVoltar: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  void _abrirInscricao(String id) {
    showInscricaoTorneioModal(
      context: context,
      vm: TorneiosMockData.inscricao(id),
      callbacks: _callbacks,
    );
  }

  void _abrirSala(String id) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SalaEsperaTorneioScreen(
          vm: TorneiosMockData.sala(id),
          callbacks: _callbacks,
          onVoltar: () => Navigator.of(context).pop(),
          onVerClassificacao: () => _abrirClassificacao(id),
        ),
      ),
    );
  }

  void _abrirClassificacao(String id) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ClassificacaoTorneioScreen(
          vm: TorneiosMockData.classificacaoVM(id),
          callbacks: _callbacks,
          onVoltar: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  void _abrirResultado(String id) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ResultadoTorneioScreen(
          vm: TorneiosMockData.resultado(id),
          callbacks: _callbacks,
          onVoltar: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  void _abrirModelo(String? templateId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ModeloTorneioScreen(
          initial: TorneiosMockData.modelo(id: templateId),
          onVoltar: () => Navigator.of(context).pop(),
          onSalvar: (form) {
            _callbacks.onSalvarModelo(form);
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }

  void _previewMesaExistente(String tournamentId, String confrontoId) {
    final faixa = FaixaTorneioMesaVM(
      nomeTorneio: TorneiosMockData.card(tournamentId).nome,
      rodada: 3,
      mesaLabel: 'Mesa 7 — Ametista',
      faseOuPosicao: 'Classificatória',
      pontuacaoAcumulada: 4680,
    );
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF140C08),
        title: const Text('Mesa existente', style: TextStyle(color: TorneiosPalette.goldHi)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FaixaTorneioMesa(vm: faixa),
            const SizedBox(height: 14),
            const Text(
              'A faixa acima entra discretamente na MesaScreen aprovada. Nenhuma carta encolhe e nenhum layout novo de mesa foi criado.',
              style: TextStyle(color: TorneiosPalette.text, fontSize: 12, height: 1.4),
            ),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Entendi'))],
      ),
    );
  }
}
