# ADENDO À OS CLAUDE — Orientação da Mesa

Data: 09/08/2026  
Origem: feedback real de testadores anterior à migração para Flutter.

Este adendo é **obrigatório** e complementa `docs/OS-CLAUDE-INTEGRACAO-FLUXO-MESAS.md`.

## 1. Decisão de produto

O jogador deve poder escolher como deseja jogar a partida:

- **Vertical**;
- **Horizontal**;
- **Automática**.

O padrão continua sendo **Vertical**, preservando a mesa já aprovada.

A opção **Automática** acompanha a orientação física do aparelho enquanto a Mesa estiver aberta.

## 2. Escopo da orientação

A preferência vale para a **Mesa de jogo**.

As demais telas — Início, Perfil, Ranking, Loja, Onde jogar, Configurar Mesa etc. — não devem ser obrigadas a acompanhar a rotação da partida.

Ao sair da Mesa, restaurar o comportamento vertical do app.

## 3. Não é permitido apenas girar a tela vertical

O layout horizontal deve ser uma composição responsiva própria da mesma Mesa, usando a largura adicional de forma útil.

Não fazer um `RotatedBox`/rotação visual de 90° da árvore vertical.

A orientação horizontal deve preservar:

- legibilidade das cartas;
- tamanho confortável da mão;
- jogos baixados;
- monte/lixo/mortos;
- avatares e timer;
- placar/meta/rodada;
- chat e ações sociais;
- controles de turno;
- identidade visual Pública/Premium;
- contexto Privada quando aplicável.

Vertical e Horizontal representam **a mesma partida e o mesmo estado**, apenas com disposição visual diferente.

## 4. Troca durante a partida

O jogador pode mudar a orientação pelo menu da própria Mesa sem abandonar a partida.

A troca de orientação não pode:

- reiniciar rodada;
- recriar o motor;
- trocar `matchId`/sala;
- reiniciar timer de turno;
- alterar mão, lixo, jogos, mortos ou placar;
- derrubar/recriar conexão online;
- limpar chat;
- consumir aposta novamente;
- gerar novo evento de entrada na partida.

É uma mudança exclusivamente de apresentação.

## 5. Configurações

Adicionar em **Configurações → JOGO**:

**Orientação da mesa**

Opções visíveis:

- 📱 Vertical
- 📲 Horizontal
- 🔄 Automática

A preferência deve ser persistida localmente e aplicada na próxima partida.

Também disponibilizar a mesma escolha no menu da Mesa para alteração imediata.

A persistência inicial pode ser local. Sincronização de preferência com conta/servidor é opcional e não deve bloquear esta entrega.

## 6. Componentes Flutter já preparados

Foram adicionados:

- `app/lib/screens/mesa_orientation_contract.dart`
- `app/lib/screens/mesa_orientation_widgets.dart`
- `app/lib/services/mesa_orientation_service.dart`
- `app/test/mesa_orientation_contract_test.dart`

### `MesaOrientationContract`

Define:

- `MesaOrientacaoPreferida.vertical`
- `MesaOrientacaoPreferida.horizontal`
- `MesaOrientacaoPreferida.automatica`
- resolução da orientação efetiva;
- orientações de dispositivo permitidas por preferência.

### `MesaOrientationService`

Persiste a preferência via `SharedPreferences`, com default **Vertical**.

### `MesaOrientacaoSelector`

Componente visual reutilizável para Configurações e menu da Mesa.

### `MesaOrientationGuard`

Aplica a preferência apenas enquanto a Mesa estiver aberta e restaura `portraitUp` ao sair.

O guard não deve ser usado para recriar `MesaScreen`/motor a cada rotação. A árvore de estado autoritativo precisa permanecer estável.

## 7. Integração com a Mesa canônica

A Mesa canônica continua sendo:

`app/lib/mesa.dart::MesaScreen`

Não criar uma terceira MesaScreen.

Refatorar a camada de apresentação da Mesa canônica para separar, quando necessário:

- `_buildMesaVertical(...)`
- `_buildMesaHorizontal(...)`

ou equivalente arquitetural limpo, compartilhando o mesmo estado/controlador/motor.

A escolha do layout deve ser feita abaixo da camada de estado, de forma que girar não reexecute inicialização de partida.

## 8. Compatibilidade com ambiente

A orientação é independente do tipo da sala:

- Pública Vertical/Horizontal/Automática;
- VIP Vertical/Horizontal/Automática;
- Privada Vertical/Horizontal/Automática;
- Treino Vertical/Horizontal/Automática, quando usar a Mesa canônica.

Pele e contexto continuam conforme os contratos existentes:

- Pública → pele pública;
- VIP → pele premium;
- Privada → pele premium + contexto privado preservado.

## 9. Responsividade

Validar pelo menos:

- celular estreito em retrato;
- celular comum em retrato;
- celular comum em paisagem;
- aparelho com proporção muito larga;
- texto/escala de fonte sem clipping crítico;
- safe areas/notch/navigation bar;
- teclado/chat aberto em paisagem;
- mão longa com scroll horizontal;
- jogos baixados com muitas cartas;
- 2 e 4 jogadores.

Não reduzir cartas a ponto de perder legibilidade apenas para fazer o horizontal caber.

## 10. Critérios de aceite

A entrega só pode ser considerada concluída quando:

1. o usuário consegue selecionar Vertical/Horizontal/Automática;
2. a escolha persiste entre aberturas do app;
3. a Mesa abre na preferência salva;
4. Vertical mantém a composição visual aprovada;
5. Horizontal possui layout próprio e legível;
6. Automática acompanha o aparelho durante a Mesa;
7. trocar orientação não reinicia estado da partida;
8. sair da Mesa não deixa o restante do app preso em paisagem;
9. Pública, VIP e Privada mantêm seus contextos corretos nas duas orientações;
10. testes/análise relevantes passam e o resultado é registrado no relatório final.

## 11. Testes

Além da OS principal, executar:

- `app/test/mesa_orientation_contract_test.dart`;
- testes de widget da configuração quando a opção for inserida;
- testes da Mesa vertical;
- testes da Mesa horizontal;
- teste de mudança de orientação durante uma partida sem reconstrução do estado autoritativo.

Não declarar esse feedback resolvido apenas com o enum/preferência: a entrega final exige o **layout horizontal real da Mesa canônica**.
