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

## Mesa Privada — proposta de valor aprovada

Título: **Configurar Mesa Privada**

Identidade: `🔑 Mesa Privada · VIP`

Mensagem central:

**Monte sua mesa. Escolha seu parceiro. Escolha seus adversários. E resolvam no baralho.**

A Mesa Privada é o ambiente social premium do Buraco Master VIP. O dono não recebe apenas um código: ele monta a própria partida, decide quem será seu parceiro, escolhe os adversários, reserva vagas específicas e pode liberar lugares restantes para outros jogadores elegíveis.

### Regra VIP das cadeiras

- criar Mesa Privada exige VIP ativo;
- **todo jogador que ocupar uma cadeira da Mesa Privada precisa ter VIP ativo**;
- possuir o código da sala não concede benefício VIP e não libera a cadeira por si só;
- exceção promocional: **Passe Convidado VIP**, ocasional, limitado e validado pelo backend;
- o Passe Convidado não pode funcionar como acesso permanente nem se renovar automaticamente;
- cadeira liberada para matchmaking só pode ser preenchida por jogador VIP ou por participante com Passe Convidado VIP válido;
- espectadores podem ser não VIP quando o dono permitir, pois assistir não equivale a ocupar uma cadeira.

A ação **TENHO UM CÓDIGO** pode ser exibida antes da validação de assinatura: o código localiza a sala. A autorização para sentar acontece depois, de forma autoritativa, exigindo VIP ativo ou Passe Convidado VIP válido.

### Montagem da turma

No modo de 4 jogadores, a UI identifica claramente:
- **DONO**;
- **PARCEIRO**;
- **OPONENTE**;
- **OPONENTE**.

No modo de 2 jogadores:
- **DONO**;
- **OPONENTE**.

O dono pode convidar diretamente para cada vaga e decidir quais vagas livres ficam travadas ou liberadas. Um participante já presente não deve virar vaga pública por toque acidental.

Regra de leitura das cadeiras:
- **Travada**: vaga reservada ao convite do dono;
- **Liberada**: o sistema pode completar com jogador elegível online;
- participante ocupado exibe seu estado de acesso VIP/Passe;
- o criador permanece protegido na própria cadeira.

### Chat da Mesa Privada

A opção equivalente a `ChatMesa.completo` é apresentada ao usuário como **Livre** na Mesa Privada.

O chat livre existe para preservar a resenha e a provocação saudável do jogo presencial, mas não transforma a sala em ambiente sem regras. Cada jogador deve ter acesso, pelo menu do avatar do outro participante, a:
- **Silenciar para mim** — para de exibir/entregar as mensagens daquele jogador apenas para quem silenciou;
- **Bloquear jogador** — impede novas interações e convites futuros conforme política da conta;
- **Denunciar** — envia ocorrência ao sistema para análise/moderação.

Bloquear alguém durante uma partida válida **não expulsa automaticamente o jogador da partida** e não pode ser usado para alterar o resultado esportivo. O dono controla a composição da mesa, mas não vira moderador com poder de remover adversário simplesmente porque está perdendo.

### Controles exclusivos da Privada

Além das configurações de jogo, manter:
- aposta em moedas;
- espectadores;
- código da sala com ação de copiar;
- montagem de parceiro/oponentes por cadeira;
- convite direto para vaga vazia;
- cadeiras travadas/liberadas;
- indicação de VIP ativo ou Passe Convidado VIP válido;
- resumo antes da criação.

Ordem visual aprovada:
1. identidade e proposta de valor;
2. regra VIP/Passe Convidado;
3. modalidade, modo, pontos, aposta, tempo;
4. chat **Livre / Só balões / Desligado** + proteção Silenciar/Bloquear/Denunciar;
5. **Monte sua partida** — dono, parceiro e oponentes;
6. acesso por código;
7. espectadores;
8. resumo da mesa;
9. ação **CRIAR MESA PRIVADA**.

## Passe Convidado VIP

O Passe Convidado é ferramenta de aquisição/marketing, não uma quarta modalidade de acesso permanente. A UI apenas reconhece sua existência; emissão, quantidade, validade, consumo, idempotência e elegibilidade são decisões autoritativas do backend.

Diretriz de produto: ele deve ser raro/ocasional, com duração curta ou limitado a partida(s), para permitir experimentação do ambiente VIP sem criar uma rota de carona recorrente.

## Fronteira de responsabilidade

A branch fecha a camada visual Flutter, os contratos e os componentes de interação. O Claude deve conectar estado real, assinatura VIP, Passe Convidado, servidor/Firebase, moedas, aposta, código, convites, cadeiras, matchmaking, chat, bloqueios e denúncias **sem redesenhar nem reinterpretar a experiência aprovada**.

Regras de autoridade que não podem ficar apenas no cliente:
- validação do VIP ativo;
- validade/consumo do Passe Convidado;
- autorização para ocupar cadeira;
- saldo, custo e aposta;
- criação/entrada da sala;
- persistência de bloqueio;
- registro e tratamento de denúncias.
