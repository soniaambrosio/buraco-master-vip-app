# Varredura final — fluxo de configuração de mesas

Data: 09/08/2026
Branch: `codex/configuracao-mesas-fluxo`

## Objetivo

Conferir o caminho visual completo antes da integração de servidor/Firebase pelo Claude, eliminando ambiguidades entre Mesa Pública, Mesa VIP e Mesa Privada.

## Fluxo oficial

`Início → Onde jogar → Configurar ambiente escolhido → Preparando partida → Mesa`

A escolha do ambiente acontece uma única vez em **Onde jogar**.

Para a Mesa Privada existe também a rota de convidado:

`Onde jogar → Tenho um código → localizar sala → validar VIP/Passe Convidado → ocupar cadeira`

O código **não é autorização**. Criar Mesa Privada exige VIP, e jogar sentado nela também exige VIP ativo, salvo Passe Convidado VIP ocasional e válido.

## Verificações concluídas

- Mesa Pública não exibe seletor de tipo de mesa;
- Mesa Pública não exibe aposta, espectadores, código ou cadeiras;
- Mesa Pública mostra `GRÁTIS` no cabeçalho e botão final dedicado;
- Mesa VIP possui aposta opcional em moedas e cálculo visual do pote;
- Mesa VIP não herda código nem cadeiras da Mesa Privada;
- Mesa Privada possui código, espectadores, cadeiras e aposta;
- Mesa Privada identifica dono, parceiro e oponentes;
- no modo de 2 jogadores, a Privada mostra dono + oponente, sem parceiro fictício;
- dono e participante já presente ficam protegidos contra abertura acidental da cadeira;
- somente vagas livres/reservadas podem alternar entre Travada e Liberada;
- vaga liberada deve ser completada somente por jogador elegível VIP/Passe;
- participante ocupado registra visualmente VIP ativo ou Passe Convidado;
- o código apenas localiza a sala e não concede benefício;
- espectadores podem ser não VIP quando autorizados pelo dono;
- a opção de chat completo aparece como **Livre** na Privada;
- a UI possui componentes para **Silenciar**, **Bloquear** e **Denunciar**;
- bloqueio não deve expulsar automaticamente alguém de partida válida;
- Mesa Privada possui resumo antes da criação;
- botão voltar retorna ao seletor de ambiente;
- Treino permanece fora do configurador e abre o fluxo próprio de treino;
- a sigla visível do configurador foi uniformizada para `STBL`;
- o mock de **Onde jogar** abre como VIP apenas para permitir inspeção de todas as telas; a integração real deve passar o status da conta explicitamente.

## Proposta de valor da Mesa Privada

Frase-guia aprovada:

**Monte sua mesa. Escolha seu parceiro. Escolha seus adversários. E resolvam no baralho.**

A Mesa Privada deixa de ser apenas uma sala com senha e passa a ser o ambiente social premium do produto. O dono monta a composição da partida, reserva lugares e decide quais vagas podem receber outros jogadores elegíveis.

## Passe Convidado VIP

O Passe Convidado é exceção promocional, não acesso permanente. A UI reconhece o estado, mas o backend deve ser a fonte de verdade para:
- emissão;
- validade;
- limite de uso;
- consumo;
- idempotência;
- elegibilidade do convidado.

O passe deve ser ocasional/limitado para funcionar como aquisição e experimentação do VIP, sem permitir que um assinante mantenha três jogadores gratuitos de forma recorrente.

## Chat livre com proteção

Na Privada, `ChatMesa.completo` é apresentado como **Livre**.

A interface Flutter deixa preparados os comandos sociais por jogador:
- Silenciar para mim;
- Bloquear jogador;
- Denunciar.

O dono controla a formação da mesa, mas não recebe poder para expulsar adversário arbitrariamente durante uma partida válida. Ações de moderação, persistência de bloqueio e tratamento de denúncia pertencem à integração/autorização do sistema.

## Quarentena do lobby privado legado

O `main.dart` ainda contém `_OnlineLobbyHost`, criado anteriormente como prova de conexão do servidor.

Ele **não pertence ao fluxo visual aprovado de criação da Mesa Privada**. Enquanto a integração final não é feita, a opção visual usa o identificador interno `privada_config`, evitando o atalho antigo que pulava `ConfigurarMesaScreen`.

Na ligação final, o Claude deve retirar o atalho legado de criação e conectar:
- **CRIAR MESA PRIVADA** → criação autoritativa da sala;
- **TENHO UM CÓDIGO** → localizar sala e, antes de ocupar cadeira, validar VIP ativo ou Passe Convidado válido.

## Contrato completo da configuração

`app/lib/screens/mesa_config_contract.dart` congela as escolhas antes da fronteira UI → preparação/servidor/motor.

O contrato preserva:
- tipo de mesa;
- status VIP do jogador;
- modalidade (`ABERTO`, `FECHADO`, `STBL`);
- 2 ou 4 jogadores;
- meta de pontos;
- tempo por jogada;
- chat;
- aposta e pote;
- espectadores;
- código da sala;
- cadeiras e estado de acesso;
- custo de criação.

Também expõe:
- quantidade de jogadores;
- cadeiras ativas para 2/4 jogadores;
- coerência aposta × jogadores = pote;
- exigência de VIP dos participantes da Privada;
- possibilidade controlada de Passe Convidado;
- regra de espectador não VIP.

## Validador de fronteira

`app/lib/screens/mesa_config_validator.dart` detecta inconsistências visuais antes da integração, inclusive cadeira ocupada da Privada sem VIP nem Passe Convidado.

Isso é defesa de apresentação. Assinatura, passe, saldo, aposta e autorização continuam obrigatoriamente validados no backend.

## Adaptador para Preparando partida

`app/lib/screens/preparando_partida_config_adapter.dart` transforma o contrato em `PreparandoPartidaVM`.

Ele preserva:
- Pública/VIP/Privada no título;
- modalidade;
- 2/4 jogadores;
- meta;
- tempo;
- aposta;
- espectadores na Privada;
- contexto VIP.

Os mocks de preparação agora tratam todos os jogadores da Mesa VIP e da Mesa Privada como VIP. Participantes reais com Passe Convidado serão representados a partir do estado autoritativo na integração.

## Achados ainda pertencentes à integração/refino final

1. **O host atual ainda chama o mock antigo de Preparando partida.** O adaptador novo está pronto, mas `main.dart` deve ser ligado ao `MesaConfigContract` na integração.
2. **O host atual não transporta todas as escolhas até a mesa.** Modo, chat, aposta, espectadores, código e cadeiras devem atravessar pelo contrato.
3. **A animação antiga de distribuição possui quatro destinos fixos.** Ela precisa acompanhar as posições reais quando o modo for 2 jogadores antes do fechamento definitivo desse trecho visual.
4. **A mesa de motor atual trabalha estruturalmente com quatro assentos.** Suporte autoritativo a 2 jogadores pertence ao motor/servidor e não deve ser falsificado pela UI.
5. **`MesaVariant` possui apenas `publica` e `vip`.** A aparência efetiva da Privada deve ser ligada conscientemente.
6. **Existem duas implementações chamadas `MesaScreen`.** O `main.dart` usa `app/lib/mesa.dart`; a integração deve escolher fonte canônica.
7. **Ainda há texto legado `SBTL` fora do configurador.** O produto usa `STBL`; normalizar texto não pode alterar regra do jogo.

## Portão para o Claude

A camada visual estará fechada quando:
- Pública, VIP e Privada forem navegáveis sem seletor duplicado;
- aposta/pote responderem ao modo 2/4;
- a Privada permitir montar parceiro/oponentes por cadeira;
- VIP/Passe estiver explicitado em todas as rotas de ocupação;
- chat Livre + Silenciar/Bloquear/Denunciar estiverem prontos como componentes;
- código/copiar e espectadores funcionarem no mock;
- a Privada não cair no lobby legado antes de ser configurada;
- `MesaConfigContract` preservar as escolhas;
- o adaptador de preparação respeitar 2/4 jogadores e o contexto VIP;
- o validador rejeitar contratos incoerentes;
- a animação visual de preparação respeitar 2/4 participantes;
- a nomenclatura visível usar STBL.

Na integração, o Claude deve:
- usar `MesaConfigContract` como referência de entrada;
- validar VIP/Passe Convidado por cadeira no backend;
- ligar saldo, custo e aposta autoritativamente;
- criar/entrar na sala e gerar código real;
- ligar convites, ocupação e trava/liberação de cadeiras;
- construir `PreparandoPartidaVM` com participantes reais;
- ligar matchmaking e espectadores;
- transportar chat, modalidade, meta e tempo;
- persistir bloqueios e registrar denúncias;
- resolver suporte real do motor a 2 jogadores;
- escolher implementação canônica da mesa;
- preservar integralmente o layout e a hierarquia visual aprovados.
