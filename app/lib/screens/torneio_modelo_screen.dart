import 'package:flutter/material.dart';

import 'torneios_models.dart';
import 'torneios_screens.dart';

// TELA 7 — CRIAR / EDITAR MODELO DE TORNEIO
class ModeloTorneioScreen extends StatefulWidget {
  final ModeloTorneioForm initial;
  final VoidCallback onVoltar;
  final ValueChanged<ModeloTorneioForm> onSalvar;

  const ModeloTorneioScreen({
    super.key,
    required this.initial,
    required this.onVoltar,
    required this.onSalvar,
  });

  @override
  State<ModeloTorneioScreen> createState() => _ModeloTorneioScreenState();
}

class _ModeloTorneioScreenState extends State<ModeloTorneioScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nome;
  late final TextEditingController _descricao;
  late final TextEditingController _imagem;
  late final TextEditingController _valorEntrada;
  late final TextEditingController _minJogadores;
  late final TextEditingController _maxJogadores;
  late final TextEditingController _rodadas;
  late final TextEditingController _metaPontos;
  late final TextEditingController _duracaoMin;
  late final TextEditingController _horario;
  late final TextEditingController _fuso;
  late final TextEditingController _maxEdicoes;
  late final TextEditingController _antecedenciaHoras;
  late final TextEditingController _encerraMin;
  late final TextEditingController _prazoCancelamentoMin;
  late final TextEditingController _checkinAbreMin;
  late final TextEditingController _checkinFechaMin;
  late final TextEditingController _toleranciaMin;
  late final TextEditingController _abandono;
  late final TextEditingController _desconexao;
  late final TextEditingController _conduta;

  late ModalidadeTorneio _modalidade;
  late TipoParticipacao _participacao;
  late TipoAcesso _acesso;
  late TipoEntrada _entrada;
  late Recorrencia _recorrencia;
  late bool _espectadores;
  late bool _pausado;
  late bool _listaEspera;
  late bool _entradaAutomatica;
  late bool _permiteDesistencia;
  late bool _devolveFichas;
  late bool _eliminaAusente;
  late bool _convocaLista;
  late bool _ativo;
  late Map<String, bool> _notificacoes;
  late List<PremiacaoVM> _premios;
  late List<String> _desempates;

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    _nome = TextEditingController(text: i.nome);
    _descricao = TextEditingController(text: i.descricao);
    _imagem = TextEditingController(text: i.imagemUrl ?? '');
    _valorEntrada = TextEditingController(text: '${i.valorEntrada}');
    _minJogadores = TextEditingController(text: '${i.minJogadores}');
    _maxJogadores = TextEditingController(text: '${i.maxJogadores}');
    _rodadas = TextEditingController(text: '${i.rodadas}');
    _metaPontos = TextEditingController(text: '${i.metaPontos}');
    _duracaoMin = TextEditingController(text: '${i.duracaoEstimada.inMinutes}');
    _horario = TextEditingController(text: i.horario);
    _fuso = TextEditingController(text: i.fusoHorario);
    _maxEdicoes = TextEditingController(text: i.maxEdicoes?.toString() ?? '');
    _antecedenciaHoras = TextEditingController(text: '${i.antecedenciaInscricao.inHours}');
    _encerraMin = TextEditingController(text: '${i.encerramentoInscricao.inMinutes}');
    _prazoCancelamentoMin = TextEditingController(text: '${i.prazoCancelamentoSemPenalidade.inMinutes}');
    _checkinAbreMin = TextEditingController(text: '${i.checkinAbertura.inMinutes}');
    _checkinFechaMin = TextEditingController(text: '${i.checkinEncerramento.inMinutes}');
    _toleranciaMin = TextEditingController(text: '${i.tolerancia.inMinutes}');
    _abandono = TextEditingController(text: i.regrasAbandono);
    _desconexao = TextEditingController(text: i.regrasDesconexao);
    _conduta = TextEditingController(text: i.regrasConduta);
    _modalidade = i.modalidade;
    _participacao = i.participacao;
    _acesso = i.acesso;
    _entrada = i.entrada;
    _recorrencia = i.recorrencia;
    _espectadores = i.espectadoresPermitidos;
    _pausado = i.pausado;
    _listaEspera = i.listaEspera;
    _entradaAutomatica = i.entradaAutomaticaListaEspera;
    _permiteDesistencia = i.permiteDesistencia;
    _devolveFichas = i.devolveFichas;
    _eliminaAusente = i.eliminaPorAusencia;
    _convocaLista = i.convocaListaEspera;
    _ativo = i.ativo;
    _notificacoes = Map<String, bool>.from(i.notificacoes);
    _premios = List<PremiacaoVM>.from(i.premiacoes);
    _desempates = List<String>.from(i.criteriosDesempate);
  }

  @override
  void dispose() {
    for (final c in [
      _nome,
      _descricao,
      _imagem,
      _valorEntrada,
      _minJogadores,
      _maxJogadores,
      _rodadas,
      _metaPontos,
      _duracaoMin,
      _horario,
      _fuso,
      _maxEdicoes,
      _antecedenciaHoras,
      _encerraMin,
      _prazoCancelamentoMin,
      _checkinAbreMin,
      _checkinFechaMin,
      _toleranciaMin,
      _abandono,
      _desconexao,
      _conduta,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  int _n(TextEditingController c, {int fallback = 0}) => int.tryParse(c.text.trim()) ?? fallback;

  @override
  Widget build(BuildContext context) {
    return TorneiosShell(
      title: widget.initial.templateId == null ? 'Novo modelo' : 'Editar modelo',
      subtitle: 'configuração visual · o servidor valida ao salvar',
      onBack: widget.onVoltar,
      scroll: true,
      bottom: _barraSalvar(),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _statusModelo(),
            const TorneioSectionTitle('Identidade'),
            _card([
              _campo(_nome, 'Nome do torneio', obrigatorio: true, icon: Icons.emoji_events_rounded),
              _campo(_descricao, 'Descrição', obrigatorio: true, maxLines: 3, icon: Icons.notes_rounded),
              _campo(_imagem, 'Imagem / URL opcional', icon: Icons.image_outlined),
            ]),
            const TorneioSectionTitle('Formato da competição'),
            _card([
              _enumDropdown<ModalidadeTorneio>(
                label: 'Modalidade',
                value: _modalidade,
                values: ModalidadeTorneio.values,
                labelOf: (v) => v.label,
                onChanged: (v) => setState(() => _modalidade = v),
              ),
              _enumDropdown<TipoParticipacao>(
                label: 'Participação',
                value: _participacao,
                values: TipoParticipacao.values,
                labelOf: (v) => v == TipoParticipacao.dupla ? 'Duplas' : 'Individual',
                onChanged: (v) => setState(() => _participacao = v),
              ),
              _enumDropdown<TipoAcesso>(
                label: 'Acesso',
                value: _acesso,
                values: TipoAcesso.values,
                labelOf: (v) => switch (v) { TipoAcesso.publico => 'Público', TipoAcesso.vip => 'VIP', TipoAcesso.misto => 'Misto' },
                onChanged: (v) => setState(() => _acesso = v),
              ),
              _enumDropdown<TipoEntrada>(
                label: 'Entrada',
                value: _entrada,
                values: TipoEntrada.values,
                labelOf: (v) => v == TipoEntrada.gratuito ? 'Gratuita' : 'Fichas',
                onChanged: (v) => setState(() => _entrada = v),
              ),
              if (_entrada == TipoEntrada.fichas) _campo(_valorEntrada, 'Valor em fichas', number: true, obrigatorio: true, icon: Icons.local_activity_rounded),
              Row(
                children: [
                  Expanded(child: _campo(_minJogadores, 'Mínimo', number: true, obrigatorio: true)),
                  const SizedBox(width: 9),
                  Expanded(child: _campo(_maxJogadores, 'Máximo', number: true, obrigatorio: true)),
                ],
              ),
              Row(
                children: [
                  Expanded(child: _campo(_rodadas, 'Rodadas', number: true, obrigatorio: true)),
                  const SizedBox(width: 9),
                  Expanded(child: _campo(_metaPontos, 'Meta de pontos', number: true, obrigatorio: true)),
                ],
              ),
              _campo(_duracaoMin, 'Duração estimada (min)', number: true, obrigatorio: true, icon: Icons.schedule_rounded),
              _toggle('Espectadores permitidos', _espectadores, (v) => setState(() => _espectadores = v), icon: Icons.visibility_rounded),
            ]),
            const TorneioSectionTitle('Agenda e recorrência'),
            _card([
              _enumDropdown<Recorrencia>(
                label: 'Recorrência',
                value: _recorrencia,
                values: Recorrencia.values,
                labelOf: (v) => switch (v) {
                  Recorrencia.unico => 'Único',
                  Recorrencia.semanal => 'Semanal',
                  Recorrencia.quinzenal => 'Quinzenal',
                  Recorrencia.mensal => 'Mensal',
                  Recorrencia.ultimoDiaDoMes => 'Último dia do mês',
                  Recorrencia.dataEspecial => 'Data especial',
                },
                onChanged: (v) => setState(() => _recorrencia = v),
              ),
              Row(
                children: [
                  Expanded(child: _campo(_horario, 'Horário', obrigatorio: true, icon: Icons.access_time_rounded)),
                  const SizedBox(width: 9),
                  Expanded(child: _campo(_maxEdicoes, 'Máx. edições', number: true)),
                ],
              ),
              _campo(_fuso, 'Fuso horário', obrigatorio: true, icon: Icons.public_rounded),
              _readOnlyDate('Início da recorrência', widget.initial.inicioRecorrencia),
              _readOnlyDate('Fim da recorrência', widget.initial.fimRecorrencia),
              _readOnlyInfo('Exceções programadas', '${widget.initial.excecoes.length} data(s)'),
              _toggle('Modelo pausado', _pausado, (v) => setState(() => _pausado = v), icon: Icons.pause_circle_outline_rounded),
            ]),
            const TorneioSectionTitle('Inscrições e lista de espera'),
            _card([
              Row(
                children: [
                  Expanded(child: _campo(_antecedenciaHoras, 'Abre antes (h)', number: true, obrigatorio: true)),
                  const SizedBox(width: 9),
                  Expanded(child: _campo(_encerraMin, 'Encerra antes (min)', number: true, obrigatorio: true)),
                ],
              ),
              _toggle('Ativar lista de espera', _listaEspera, (v) => setState(() => _listaEspera = v), icon: Icons.hourglass_bottom_rounded),
              _toggle('Entrada automática da lista', _entradaAutomatica, (v) => setState(() => _entradaAutomatica = v), enabled: _listaEspera),
              _toggle('Permitir desistência', _permiteDesistencia, (v) => setState(() => _permiteDesistencia = v), icon: Icons.exit_to_app_rounded),
              _toggle('Devolver fichas no prazo', _devolveFichas, (v) => setState(() => _devolveFichas = v), enabled: _permiteDesistencia),
              _campo(_prazoCancelamentoMin, 'Prazo sem penalidade (min)', number: true, obrigatorio: true),
            ]),
            const TorneioSectionTitle('Check-in e ausência'),
            _card([
              Row(
                children: [
                  Expanded(child: _campo(_checkinAbreMin, 'Abre antes (min)', number: true, obrigatorio: true)),
                  const SizedBox(width: 9),
                  Expanded(child: _campo(_checkinFechaMin, 'Fecha antes (min)', number: true, obrigatorio: true)),
                ],
              ),
              _campo(_toleranciaMin, 'Tolerância (min)', number: true, obrigatorio: true, icon: Icons.timer_outlined),
              _toggle('Eliminar por ausência', _eliminaAusente, (v) => setState(() => _eliminaAusente = v), icon: Icons.person_off_rounded),
              _toggle('Convocar lista de espera', _convocaLista, (v) => setState(() => _convocaLista = v), enabled: _listaEspera),
            ]),
            const TorneioSectionTitle('Premiações por colocação'),
            _premiacoes(),
            const TorneioSectionTitle('Desempate'),
            _desempatesWidget(),
            const TorneioSectionTitle('Regras de conduta e segurança'),
            _card([
              _campo(_abandono, 'Regra de abandono', maxLines: 3, obrigatorio: true),
              _campo(_desconexao, 'Regra de desconexão', maxLines: 3, obrigatorio: true),
              _campo(_conduta, 'Regra de conduta', maxLines: 3, obrigatorio: true),
            ]),
            const TorneioSectionTitle('Notificações'),
            _notificacoesWidget(),
            const SizedBox(height: 105),
          ],
        ),
      ),
    );
  }

  Widget _statusModelo() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF492568), Color(0xFF24152D)]),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: TorneiosPalette.amethyst.withValues(alpha: .48)),
      ),
      child: Row(
        children: [
          const Icon(Icons.tune_rounded, color: TorneiosPalette.gold, size: 34),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Modelo recorrente', style: TextStyle(color: TorneiosPalette.goldHi, fontWeight: FontWeight.w900)),
                Text('Todas as decisões finais serão validadas pelo Claude.', style: TextStyle(color: Color(0xFFD3C0E4), fontSize: 10.5)),
              ],
            ),
          ),
          Switch(value: _ativo, onChanged: (v) => setState(() => _ativo = v), activeColor: TorneiosPalette.gold),
        ],
      ),
    );
  }

  Widget _barraSalvar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 10),
      decoration: const BoxDecoration(color: Color(0xF20D0805), border: Border(top: BorderSide(color: TorneiosPalette.border))),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(child: OutlinedButton(onPressed: widget.onVoltar, style: OutlinedButton.styleFrom(foregroundColor: TorneiosPalette.textMuted, side: const BorderSide(color: TorneiosPalette.border), padding: const EdgeInsets.symmetric(vertical: 13)), child: const Text('Cancelar'))),
            const SizedBox(width: 9),
            Expanded(flex: 2, child: FilledButton.icon(onPressed: _salvar, style: FilledButton.styleFrom(backgroundColor: TorneiosPalette.gold, foregroundColor: const Color(0xFF321E04), padding: const EdgeInsets.symmetric(vertical: 13)), icon: const Icon(Icons.save_rounded), label: const Text('Salvar modelo', style: TextStyle(fontWeight: FontWeight.w900)))),
          ],
        ),
      ),
    );
  }

  Widget _card(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(color: TorneiosPalette.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: TorneiosPalette.border)),
      child: Column(children: [for (var i = 0; i < children.length; i++) ...[children[i], if (i != children.length - 1) const SizedBox(height: 10)]]),
    );
  }

  Widget _campo(
    TextEditingController controller,
    String label, {
    bool obrigatorio = false,
    bool number = false,
    int maxLines = 1,
    IconData? icon,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: number ? TextInputType.number : maxLines > 1 ? TextInputType.multiline : TextInputType.text,
      maxLines: maxLines,
      style: const TextStyle(color: TorneiosPalette.text, fontSize: 12),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: TorneiosPalette.textMuted, fontSize: 11),
        prefixIcon: icon == null ? null : Icon(icon, color: TorneiosPalette.amethyst, size: 19),
        filled: true,
        fillColor: Colors.black.withValues(alpha: .18),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: TorneiosPalette.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: TorneiosPalette.amethyst)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: TorneiosPalette.danger)),
      ),
      validator: obrigatorio
          ? (value) {
              if (value == null || value.trim().isEmpty) return 'Obrigatório';
              if (number && int.tryParse(value) == null) return 'Número inválido';
              return null;
            }
          : null,
    );
  }

  Widget _enumDropdown<T>({
    required String label,
    required T value,
    required List<T> values,
    required String Function(T) labelOf,
    required ValueChanged<T> onChanged,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      dropdownColor: const Color(0xFF1B100B),
      style: const TextStyle(color: TorneiosPalette.text, fontSize: 12),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: TorneiosPalette.textMuted, fontSize: 11),
        filled: true,
        fillColor: Colors.black.withValues(alpha: .18),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: TorneiosPalette.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: TorneiosPalette.amethyst)),
      ),
      items: [for (final v in values) DropdownMenuItem<T>(value: v, child: Text(labelOf(v)))],
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }

  Widget _toggle(String label, bool value, ValueChanged<bool> onChanged, {IconData? icon, bool enabled = true}) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      value: value,
      onChanged: enabled ? onChanged : null,
      activeColor: TorneiosPalette.gold,
      secondary: icon == null ? null : Icon(icon, color: enabled ? TorneiosPalette.amethyst : TorneiosPalette.textMuted, size: 20),
      title: Text(label, style: TextStyle(color: enabled ? TorneiosPalette.text : TorneiosPalette.textMuted, fontSize: 11.5)),
      dense: true,
    );
  }

  Widget _readOnlyDate(String label, DateTime? date) => _readOnlyInfo(label, date == null ? 'não definido' : '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}');

  Widget _readOnlyInfo(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: .18), borderRadius: BorderRadius.circular(12), border: Border.all(color: TorneiosPalette.border)),
      child: Row(children: [Expanded(child: Text(label, style: const TextStyle(color: TorneiosPalette.textMuted, fontSize: 11))), Text(value, style: const TextStyle(color: TorneiosPalette.text, fontSize: 11.5, fontWeight: FontWeight.w700)), const SizedBox(width: 6), const Icon(Icons.chevron_right_rounded, color: TorneiosPalette.amethyst, size: 18)]),
    );
  }

  Widget _premiacoes() {
    return Column(
      children: [
        for (var index = 0; index < _premios.length; index++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: TorneiosPalette.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: TorneiosPalette.border)),
              child: Row(
                children: [
                  CircleAvatar(backgroundColor: TorneiosPalette.gold.withValues(alpha: .15), child: Text('${_premios[index].posicao}º', style: const TextStyle(color: TorneiosPalette.gold, fontWeight: FontWeight.w900))),
                  const SizedBox(width: 10),
                  Expanded(child: Text(_premios[index].valorLabel, style: const TextStyle(color: TorneiosPalette.text, fontSize: 11.5, fontWeight: FontWeight.w700))),
                  IconButton(
                    tooltip: 'Remover premiação',
                    onPressed: _premios.length <= 1 ? null : () => setState(() => _premios.removeAt(index)),
                    icon: const Icon(Icons.delete_outline_rounded, color: TorneiosPalette.danger, size: 20),
                  ),
                ],
              ),
            ),
          ),
        OutlinedButton.icon(
          onPressed: () => setState(() => _premios.add(PremiacaoVM(rewardId: 'novo-${_premios.length + 1}', posicao: _premios.length + 1, tipo: TipoPremio.fichas, valorLabel: 'Nova premiação', statusEntrega: 'pendente'))),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Adicionar colocação'),
          style: OutlinedButton.styleFrom(foregroundColor: TorneiosPalette.amethyst, side: BorderSide(color: TorneiosPalette.amethyst.withValues(alpha: .5))),
        ),
      ],
    );
  }

  Widget _desempatesWidget() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: TorneiosPalette.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: TorneiosPalette.border)),
      child: ReorderableListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _desempates.length,
        onReorder: (oldIndex, newIndex) {
          setState(() {
            if (newIndex > oldIndex) newIndex--;
            final item = _desempates.removeAt(oldIndex);
            _desempates.insert(newIndex, item);
          });
        },
        itemBuilder: (context, index) => ListTile(
          key: ValueKey('${_desempates[index]}-$index'),
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(radius: 15, backgroundColor: TorneiosPalette.purple.withValues(alpha: .20), child: Text('${index + 1}', style: const TextStyle(color: TorneiosPalette.amethyst, fontSize: 11, fontWeight: FontWeight.w900))),
          title: Text(_desempates[index], style: const TextStyle(color: TorneiosPalette.text, fontSize: 11.5)),
          trailing: const Icon(Icons.drag_handle_rounded, color: TorneiosPalette.textMuted),
        ),
      ),
    );
  }

  Widget _notificacoesWidget() {
    const labels = {
      'anuncio': 'Anúncio do torneio',
      'inscricoes_abertas': 'Inscrições abertas',
      'lembrete_24h': 'Lembrete de 24 horas',
      'checkin': 'Abertura do check-in',
      'mesa_pronta': 'Mesa pronta',
      'resultado': 'Resultado e premiação',
    };
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: TorneiosPalette.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: TorneiosPalette.border)),
      child: Column(
        children: [
          for (final key in labels.keys)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _notificacoes[key] ?? false,
              onChanged: (v) => setState(() => _notificacoes[key] = v),
              activeColor: TorneiosPalette.gold,
              secondary: const Icon(Icons.notifications_active_rounded, color: TorneiosPalette.amethyst, size: 19),
              title: Text(labels[key]!, style: const TextStyle(color: TorneiosPalette.text, fontSize: 11.5)),
              dense: true,
            ),
        ],
      ),
    );
  }

  void _salvar() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final i = widget.initial;
    widget.onSalvar(
      ModeloTorneioForm(
        templateId: i.templateId,
        nome: _nome.text.trim(),
        descricao: _descricao.text.trim(),
        imagemUrl: _imagem.text.trim().isEmpty ? null : _imagem.text.trim(),
        modalidade: _modalidade,
        participacao: _participacao,
        acesso: _acesso,
        entrada: _entrada,
        valorEntrada: _entrada == TipoEntrada.gratuito ? 0 : _n(_valorEntrada),
        minJogadores: _n(_minJogadores, fallback: 4),
        maxJogadores: _n(_maxJogadores, fallback: 32),
        rodadas: _n(_rodadas, fallback: 3),
        duracaoEstimada: Duration(minutes: _n(_duracaoMin, fallback: 120)),
        metaPontos: _n(_metaPontos, fallback: 1500),
        espectadoresPermitidos: _espectadores,
        recorrencia: _recorrencia,
        horario: _horario.text.trim(),
        fusoHorario: _fuso.text.trim(),
        inicioRecorrencia: i.inicioRecorrencia,
        fimRecorrencia: i.fimRecorrencia,
        maxEdicoes: _maxEdicoes.text.trim().isEmpty ? null : _n(_maxEdicoes),
        excecoes: i.excecoes,
        pausado: _pausado,
        antecedenciaInscricao: Duration(hours: _n(_antecedenciaHoras, fallback: 24)),
        encerramentoInscricao: Duration(minutes: _n(_encerraMin, fallback: 30)),
        listaEspera: _listaEspera,
        entradaAutomaticaListaEspera: _entradaAutomatica,
        permiteDesistencia: _permiteDesistencia,
        devolveFichas: _devolveFichas,
        prazoCancelamentoSemPenalidade: Duration(minutes: _n(_prazoCancelamentoMin, fallback: 120)),
        checkinAbertura: Duration(minutes: _n(_checkinAbreMin, fallback: 30)),
        checkinEncerramento: Duration(minutes: _n(_checkinFechaMin, fallback: 5)),
        tolerancia: Duration(minutes: _n(_toleranciaMin, fallback: 5)),
        eliminaPorAusencia: _eliminaAusente,
        convocaListaEspera: _convocaLista,
        premiacoes: List.unmodifiable(_premios),
        criteriosDesempate: List.unmodifiable(_desempates),
        regrasAbandono: _abandono.text.trim(),
        regrasDesconexao: _desconexao.text.trim(),
        regrasConduta: _conduta.text.trim(),
        notificacoes: Map.unmodifiable(_notificacoes),
        ativo: _ativo,
      ),
    );
  }
}
