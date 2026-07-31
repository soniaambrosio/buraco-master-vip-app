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
      mostrarAdmin: true,
      onAbrirAdmin: _abrirAdmin,
      onAbrirCenariosMock: _abrirCenariosMock,
    );
  }


  void _abrirCenariosMock() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF130B08),
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * .78,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              const Text('Cenários de validação visual', style: TextStyle(color: TorneiosPalette.goldHi, fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 5),
              const Text('Disponíveis somente no host mock. O Claude substitui pelos estados reais.', style: TextStyle(color: TorneiosPalette.textMuted, fontSize: 10.5)),
              const TorneioSectionTitle('Modal de inscrição'),
              _cenarioTile(
                sheetContext,
                icon: Icons.person_rounded,
                title: 'Inscrição individual',
                subtitle: 'gratuita · regras obrigatórias',
                onTap: () => _abrirInscricao('copa-rapida'),
              ),
              _cenarioTile(
                sheetContext,
                icon: Icons.groups_2_rounded,
                title: 'Inscrição em dupla',
                subtitle: 'escolha de parceiro online/offline',
                onTap: () => _abrirInscricao('quarta-vulnerabilidade'),
              ),
              for (final motivo in MotivoInscricaoRecusada.values)
                _cenarioTile(
                  sheetContext,
                  icon: Icons.block_rounded,
                  title: 'Recusa: ${motivo.name}',
                  subtitle: 'mensagem amigável recebida do Claude',
                  onTap: () => showInscricaoTorneioModal(
                    context: context,
                    vm: TorneiosMockData.inscricao('quarta-vulnerabilidade', recusa: motivo),
                    callbacks: _callbacks,
                  ),
                ),
              const TorneioSectionTitle('Sala de espera · 9 estados'),
              for (final status in StatusParticipante.values)
                _cenarioTile(
                  sheetContext,
                  icon: Icons.hourglass_bottom_rounded,
                  title: status.label,
                  subtitle: 'estado oficial do participante',
                  onTap: () => _abrirSalaComStatus('sexta-master-vip', status),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cenarioTile(
    BuildContext sheetContext, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: ListTile(
        tileColor: TorneiosPalette.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(13),
          side: const BorderSide(color: TorneiosPalette.border),
        ),
        leading: Icon(icon, color: TorneiosPalette.amethyst),
        title: Text(title, style: const TextStyle(color: TorneiosPalette.text, fontSize: 11.5, fontWeight: FontWeight.w800)),
        subtitle: Text(subtitle, style: const TextStyle(color: TorneiosPalette.textMuted, fontSize: 9.5)),
        trailing: const Icon(Icons.chevron_right_rounded, color: TorneiosPalette.gold),
        onTap: () {
          Navigator.of(sheetContext).pop();
          Future<void>.delayed(const Duration(milliseconds: 180), onTap);
        },
      ),
    );
  }

  void _abrirSalaComStatus(String id, StatusParticipante status) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SalaEsperaTorneioScreen(
          vm: TorneiosMockData.salaComStatus(id, status),
          callbacks: _callbacks,
          onVoltar: () => Navigator.of(context).pop(),
          onVerClassificacao: () => _abrirClassificacao(id),
        ),
      ),
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

  void _abrirAdmin() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AdminTorneiosScreen(
          torneios: TorneiosMockData.admin(),
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
