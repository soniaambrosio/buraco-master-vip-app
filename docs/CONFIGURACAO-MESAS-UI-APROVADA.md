# Configuração de Mesas — UI aprovada

## Regra de navegação

A escolha do ambiente acontece somente em **Onde jogar**. A tela seguinte não pode voltar a oferecer Pública / VIP / Privada.

Fluxo aprovado:

`Onde jogar → Configurar ambiente escolhido → Preparando/espera → Partida`

Ao tocar em voltar na configuração, o jogador retorna a **Onde jogar** para trocar de ambiente.

## Mesa Pública

Título: **Configurar Mesa Pública**

Identidade: `🌎 Mesa Pública · GRÁTIS`

Mostrar somente:
- Modalidade: Aberto / Fechado / STBL;
- Ver regras das modalidades;
- Modo: 2 jogadores / 4 jogadores;
- Pontos: 1.500 / 3.000;
- Tempo por jogada: 15s / 30s / 45s;
- Chat: Completo / Só balões / Desligado.

Não mostrar:
- aposta;
- espectadores;
- código da sala;
- cadeiras;
- seletor de tipo de mesa.

A gratuidade deve ficar evidente no cabeçalho. O rodapé deve priorizar a ação **Criar mesa pública**, sem repetir escolhas de ambiente.

## Mesa VIP

Título: **Configurar Mesa VIP**

Identidade: `💎 Mesa VIP · LOUNGE PREMIUM`

Mostrar:
- Modalidade: Aberto / Fechado / STBL;
- Ver regras das modalidades;
- Modo: 2 jogadores / 4 jogadores;
- Pontos: 1.500 / 3.000;
- **Aposta em moedas**: Grátis / 500 / 1.000 / 5.000;
- Pote em jogo = aposta × quantidade de jogadores;
- Tempo por jogada: 15s / 30s / 45s;
- Chat: Completo / Só balões / Desligado.

Não herdar controles exclusivos da Privada, como código da sala e cadeiras.

## Mesa Privada

Título: **Configurar Mesa Privada**

Identidade: `🔑 Mesa Privada · VIP cria`

Além das configurações de jogo, manter a camada extra aprovada:
- aposta em moedas;
- espectadores;
- código da sala com ação de copiar;
- cadeiras individualmente travadas/liberadas;
- indicação de convidado que entrou por código;
- cadeira reservada aguardando convidado;
- cadeira aberta para qualquer jogador online.

A integração real com servidor, saldo, criação do código, ocupação de cadeiras, permissões VIP e matchmaking será feita posteriormente pelo Claude, preservando esta UI.

## Fronteira de responsabilidade

Esta branch fecha a camada visual Flutter e o contrato de interação. O Claude deve conectar estado, Firebase/servidor, moedas, aposta, VIP, sala e callbacks sem redesenhar nem reinterpretar o fluxo aprovado.
