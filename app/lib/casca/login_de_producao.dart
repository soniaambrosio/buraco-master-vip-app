// login_de_producao.dart — a tela pública de entrada.
//
// ---------------------------------------------------------------------------
// O QUE ESTA TELA NÃO FAZ
// ---------------------------------------------------------------------------
//
// Não assina `authStateChanges()`. Não guarda usuário. Não navega para a Home.
//
// Os três são a mesma decisão vista de ângulos diferentes: esta tela não tem
// opinião sobre quem está logado. Ela dispara um comando e volta a esperar. A
// troca para a Home acontece porque a sessão viu o fluxo de autenticação mudar e
// a casca redesenhou — não porque este arquivo mandou.
//
// A diferença aparece no caso difícil: se o login for concluído por fora (uma
// sessão restaurada chegando atrasada, por exemplo), a Home aparece do mesmo
// jeito. Uma tela que navegasse sozinha ficaria parada esperando o próprio
// botão ser apertado.
//
// ---------------------------------------------------------------------------
// SÓ O QUE FUNCIONA VIRA BOTÃO
// ---------------------------------------------------------------------------
//
// A lista de provedores vem de `ComandosDeAutenticacao.provedoresDisponiveis`,
// que responde sobre ESTE build. Vazia — Firebase que não subiu, configuração
// ausente — a tela não desenha botão nenhum e diz o motivo. §4.3 proíbe o botão
// que parece funcionar e não leva a lugar nenhum.

import 'package:flutter/material.dart';

import '../sessao/comandos_de_autenticacao.dart';
import 'escopo_autenticacao.dart';

const Color _ouro = Color(0xFFEFB94A);
const Color _carta = Color(0xFF1C130C);
const Color _borda = Color(0x33EFB94A);

class LoginDeProducao extends StatefulWidget {
  const LoginDeProducao({super.key});

  @override
  State<LoginDeProducao> createState() => _LoginDeProducaoState();
}

class _LoginDeProducaoState extends State<LoginDeProducao> {
  /// O provedor cujo pedido está em voo, ou `null`.
  ///
  /// Guardar QUAL provedor, e não um `bool`, é o que deixa o indicador de
  /// progresso no botão certo quando houver mais de um.
  ProvedorDeLogin? _emVoo;

  /// A última falha, já redigida pelo adaptador.
  String? _recado;

  Future<void> _entrar(ProvedorDeLogin provedor) async {
    if (_emVoo != null) return; // dois toques não abrem dois pedidos
    final comandos = EscopoAutenticacao.de(context);
    setState(() {
      _emVoo = provedor;
      _recado = null;
    });

    final resultado = await comandos.entrar(provedor);

    if (!mounted) return;
    setState(() {
      _emVoo = null;
      // Cancelar não é erro: quem fechou o seletor de contas sabe o que fez, e
      // não precisa de uma mensagem vermelha explicando.
      _recado = resultado.desfecho == DesfechoDeLogin.falhou
          ? resultado.mensagem
          : null;
    });
    // Sucesso NÃO navega. Ver o cabeçalho.
  }

  @override
  Widget build(BuildContext context) {
    final provedores = EscopoAutenticacao.de(context).provedoresDisponiveis;

    return Scaffold(
      backgroundColor: Colors.black,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF241812), Color(0xFF120A06), Color(0xFF000000)],
            stops: [0, .55, 1],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('👑', style: TextStyle(fontSize: 52)),
                    const SizedBox(height: 8),
                    const Text(
                      'BURACO MASTER VIP',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _ouro,
                        fontSize: 25,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'o buraco como se joga na vida real',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .54),
                        fontSize: 12.5,
                      ),
                    ),
                    const SizedBox(height: 30),
                    if (provedores.isEmpty)
                      const _SemProvedor()
                    else
                      _CartaDeEntrada(
                        provedores: provedores,
                        emVoo: _emVoo,
                        onEntrar: _entrar,
                      ),
                    if (_recado != null) ...[
                      const SizedBox(height: 14),
                      _Recado(texto: _recado!),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CartaDeEntrada extends StatelessWidget {
  const _CartaDeEntrada({
    required this.provedores,
    required this.emVoo,
    required this.onEntrar,
  });

  final List<ProvedorDeLogin> provedores;
  final ProvedorDeLogin? emVoo;
  final ValueChanged<ProvedorDeLogin> onEntrar;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _carta,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borda),
      ),
      child: Column(
        children: [
          const Text('🔐', style: TextStyle(fontSize: 30)),
          const SizedBox(height: 10),
          const Text(
            'Entre para jogar',
            style: TextStyle(
              color: _ouro,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'sua conta guarda seu progresso e é o que te identifica nas mesas',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: .58),
              fontSize: 12.5,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 18),
          for (final provedor in provedores) ...[
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: _ouro,
                  foregroundColor: const Color(0xFF3A2606),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                // Qualquer pedido em voo desabilita TODOS os botões: dois
                // provedores acionados junto virariam duas sessões disputando
                // a mesma raiz.
                onPressed: emVoo != null ? null : () => onEntrar(provedor),
                child: emVoo == provedor
                    ? const SizedBox(
                        width: 19,
                        height: 19,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF3A2606),
                        ),
                      )
                    : Text(
                        provedor.rotulo,
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

/// Nenhum provedor operacional neste build. Estado terminal e honesto: não há
/// botão porque não há o que apertar.
class _SemProvedor extends StatelessWidget {
  const _SemProvedor();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _carta,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x55E05B5B)),
      ),
      child: const Column(
        children: [
          Text('⚠️', style: TextStyle(fontSize: 30)),
          SizedBox(height: 10),
          Text(
            'Este aplicativo está mal configurado',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFFF6C9C9),
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Ele saiu sem serviço de contas, então não há como entrar. '
            'Nenhuma tentativa aqui resolve — é preciso uma nova versão.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFFB9A886),
              fontSize: 12.5,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _Recado extends StatelessWidget {
  const _Recado({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0x33E05B5B),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x55E05B5B)),
      ),
      child: Text(
        texto,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Color(0xFFF6C9C9), fontSize: 12.5),
      ),
    );
  }
}
