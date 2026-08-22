// onde_jogar_de_producao.dart — o seletor de mesa, com o catálogo honesto.
//
// ---------------------------------------------------------------------------
// DUAS DAS QUATRO OPÇÕES NÃO EXISTEM
// ---------------------------------------------------------------------------
//
// O host anterior usava `OndeJogarVM.mock()` e ligava as quatro. Mesa Pública e
// Mesa VIP prometiam "as cadeiras enchem com qualquer jogador online" e
// "matchmaking entre VIPs" — e as duas caíam, depois de uma tela de configuração
// e de uma animação de cadeiras enchendo, na MESMA partida local contra três
// robôs. Não é uma tela incompleta: é uma que afirma o contrário do que faz.
//
// Sobram as duas que fazem o que dizem:
//
//   Treino — partida local contra robôs. O motor é real e roda no aparelho.
//   Online por código — conecta no servidor, cria ou entra numa mesa. É a
//   trilha autenticada de verdade, com credencial da sessão.
//
// As outras duas continuam listadas e BLOQUEADAS, com a nota dizendo o motivo.
// A tela já sabia desenhar opção bloqueada; o que faltava era usar isso para
// dizer a verdade em vez de para vender assinatura.

import 'package:flutter/material.dart';

import '../mesa.dart' show MesaScreen;
import '../screens/onde_jogar_screen.dart';
import 'lobby_online.dart';
import 'lobby_publico_de_producao.dart';

class OndeJogarDeProducao extends StatelessWidget {
  const OndeJogarDeProducao({super.key});

  /// O catálogo do que este build entrega. Não é `mock`: é a lista real, e ela
  /// cresce quando o matchmaking existir.
  static const OndeJogarVM catalogo = OndeJogarVM(
    opcoes: [
      OpcaoMesa(
        id: 'treino',
        icone: '🤖',
        titulo: 'Treino',
        descricao:
            'Você e 3 robôs, no seu aparelho. A partida é completa e vale para '
            'aprender — só não conta ponto com ninguém.',
      ),
      OpcaoMesa(
        id: 'privada',
        icone: '🔑',
        titulo: 'Mesa por código',
        badge: 'ONLINE',
        corBadge: CorBadge.verde,
        descricao:
            'Crie uma mesa e compartilhe o código, ou entre no código de alguém. '
            'É jogo online de verdade, no servidor.',
      ),
      // [DESCOBERTA §10] DESBLOQUEADA — e a descrição diz exatamente o que ela
      // entrega hoje, nem mais nem menos.
      //
      // Ela estava bloqueada com a nota "o pareamento automático ainda não
      // existe", e isso era verdade. Continua sendo: entrar numa mesa pública é
      // a OS 38.3. O que passou a existir é a LISTA — quem está jogando, em que
      // mesa, com quantas vagas — e ver isso é útil por si só.
      //
      // Prometer "entre e jogue" aqui seria repetir o defeito que esta tela
      // existe para não ter: uma opção que afirma o contrário do que faz.
      OpcaoMesa(
        id: 'publica',
        icone: '🌎',
        titulo: 'Mesa Pública',
        badge: 'ONLINE',
        corBadge: CorBadge.verde,
        descricao:
            'Veja as mesas públicas abertas agora, quem está sentado e quantas '
            'vagas faltam. Entrar numa delas chega na próxima atualização.',
      ),
      OpcaoMesa(
        id: 'vip',
        icone: '💎',
        titulo: 'Mesa VIP',
        descricao:
            'O lounge de assinantes, com pareamento entre VIPs. Depende da mesa '
            'pública, e chega junto com ela.',
        nota: '🔒 Ainda não disponível',
        bloqueado: true,
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return OndeJogarScreen(
      vm: catalogo,
      onVoltar: () => Navigator.of(context).maybePop(),
      onEscolher: (id) {
        switch (id) {
          case 'treino':
            Navigator.of(
              context,
            ).push(MaterialPageRoute<void>(builder: (_) => const MesaScreen()));
          case 'privada':
            Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const LobbyOnline()),
            );
          // [DESCOBERTA §10] O caminho real: Entrar em mesa → Lobby Público.
          case 'publica':
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const LobbyPublicoDeProducao(),
              ),
            );
          default:
            // Bloqueada. A tela desenha o cadeado mas REPASSA o toque — ela não
            // tem opinião sobre o que está disponível —, então é aqui que a
            // opção sem destino para de verdade. Vale também para um id novo
            // que entre na lista antes de existir tela para ele.
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                const SnackBar(
                  content: Text(
                    'Esta modalidade ainda não está disponível nesta versão.',
                  ),
                  duration: Duration(milliseconds: 1600),
                  backgroundColor: Color(0xFF2A1B0E),
                ),
              );
        }
      },
    );
  }
}
