import 'package:flutter/material.dart';

void main() => runApp(const BuracoApp());

class BuracoApp extends StatelessWidget {
  const BuracoApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Buraco Master VIP',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
      home: const TelaInicial(),
    );
  }
}

class TelaInicial extends StatelessWidget {
  const TelaInicial({super.key});
  @override
  Widget build(BuildContext context) {
    const dourado = Color(0xFFEFB94A);
    return Scaffold(
      body: Container(
        // mesa de feltro (verde) com brilho central — a estética do jogo
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.15,
            colors: [Color(0xFF1E5C3A), Color(0xFF0C3A22), Color(0xFF06231A)],
            stops: [0.0, 0.6, 1.0],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Spacer(),
                // logo (coroa) com moldura dourada — Fase 0 usa emoji; a arte real entra depois
                Container(
                  width: 168,
                  height: 168,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: dourado, width: 3),
                    color: Colors.black.withOpacity(0.18),
                    boxShadow: [
                      BoxShadow(color: dourado.withOpacity(0.35), blurRadius: 34, spreadRadius: 2),
                    ],
                  ),
                  child: const Text('👑', style: TextStyle(fontSize: 92)),
                ),
                const SizedBox(height: 24),
                const Text(
                  'BURACO MASTER VIP',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: dourado,
                    fontSize: 27,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.6,
                    shadows: [Shadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 2))],
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'a mesa de família — agora nativa ✨',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Login com Google entra na próxima fatia 👍')),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: dourado,
                        foregroundColor: const Color(0xFF3A2606),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Entrar com Google',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Fase 0 · prova de conceito',
                    style: TextStyle(color: Colors.white38, fontSize: 12)),
                const SizedBox(height: 26),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
