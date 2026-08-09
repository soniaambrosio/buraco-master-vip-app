# Varredura final — fluxo de configuração de mesas

Data: 09/08/2026
Branch: `codex/configuracao-mesas-fluxo`

## Objetivo

Conferir o caminho visual completo antes da integração de servidor/Firebase pelo Claude, eliminando ambiguidades entre Mesa Pública, Mesa VIP e Mesa Privada.

## Fluxo oficial

`Início → Onde jogar → Configurar ambiente escolhido → Preparando partida → Mesa`

A escolha do ambiente acontece uma única vez em **Onde jogar**.

## Verificações concluídas

- Mesa Pública não exibe seletor de tipo de mesa;
- Mesa Pública não exibe aposta, espectadores, código ou cadeiras;
- Mesa Pública mostra `GRÁTIS` no cabeçalho e botão final dedicado;
- Mesa VIP possui aposta opcional em moedas e cálculo visual do pote;
- Mesa VIP não herda código nem cadeiras da Mesa Privada;
- Mesa Privada possui código, espectadores, cadeiras e aposta;
- dono e convidado já presente ficam protegidos contra abertura acidental da cadeira;
- somente vagas livres/reservadas podem alternar entre Travada e Liberada;
- no modo de 2 jogadores, a camada visual da Privada mostra somente os dois lugares aplicáveis;
- Mesa Privada possui resumo antes da criação;
- botão voltar retorna ao seletor de ambiente;
- Treino permanece fora do configurador e abre o fluxo próprio de treino;
- a sigla visível do configurador foi uniformizada para `STBL`.

## Quarentena do lobby privado legado

O `main.dart` ainda contém `_OnlineLobbyHost`, criado anteriormente como prova de conexão do servidor.

Ele **não pertence ao fluxo visual aprovado de criação da Mesa Privada**. Enquanto a integração final não é feita, a opção visual da Mesa Privada usa o identificador interno `privada_config`, que evita cair no atalho legado `id == 'privada'` e encaminha a navegação para `ConfigurarMesaScreen`.

Essa quarentena é intencional: preserva a prova técnica do servidor sem permitir que ela substitua ou pule a nova tela aprovada.

Na ligação final, o Claude deve retirar o atalho legado e conectar o botão **CRIAR MESA PRIVADA** ao serviço real de criação da sala.

## Contrato completo da configuração

Foi criado `app/lib/screens/mesa_config_contract.dart` para congelar todas as escolhas antes de atravessar a fronteira UI → preparação/servidor/motor.

O contrato preserva:
- tipo de mesa;
- modalidade (`ABERTO`, `FECHADO`, `STBL`);
- 2 ou 4 jogadores;
- meta de pontos;
- tempo por jogada;
- chat;
- aposta e pote;
- espectadores;
- código da sala;
- estado das cadeiras;
- custo de criação.

Esse contrato não implementa servidor nem economia. Ele existe para impedir que uma configuração escolhida desapareça durante a ligação final.

## Achados da varredura: Configurar → Preparando → Mesa

A inspeção encontrou dependências reais que pertencem à integração, não à tela aprovada:

1. **Preparando partida ainda usa mock de quatro jogadores.** O `PreparandoPartidaVM.mock()` atual nasce com quatro nomes fixos. A ligação deve construir o VM a partir do contrato, respeitando 2 ou 4 jogadores e os ocupantes reais.
2. **O host atual não transporta todas as escolhas até a mesa.** Hoje a prévia repassa principalmente modalidade, meta e tempo; modo, chat, aposta, espectadores, código e cadeiras precisam atravessar a fronteira pelo contrato novo.
3. **A mesa de motor atual trabalha estruturalmente com quatro assentos.** O modo de 2 jogadores exige ligação/adequação no motor autoritativo; não deve ser falsificado pela UI.
4. **`MesaVariant` atual possui apenas `publica` e `vip`.** A Privada é um ambiente de criação/acesso, e sua aparência efetiva de mesa deve ser ligada conscientemente na integração, sem o host decidir por `else = VIP` de forma implícita.
5. **Existem duas implementações chamadas `MesaScreen` no repositório.** O `main.dart` importa `app/lib/mesa.dart`; `app/lib/screens/mesa_screen.dart` é outra implementação visual. A integração deve escolher uma fonte canônica e evitar conectar a configuração à classe errada.
6. **Ainda há texto legado `SBTL` fora do configurador.** O produto usa `STBL`; a ligação final deve normalizar os textos/contratos remanescentes sem mudar a regra do jogo.

## Sigla da modalidade

A sigla oficial do produto é **STBL**. Ocorrências antigas de `SBTL` são texto legado. A regra do jogo não deve ser alterada por causa da correção de nomenclatura.

## Preparando partida

A tela `PreparandoPartidaScreen` continua propositalmente desacoplada de servidor e motor. Ela recebe callbacks de preparação e conclusão, portanto pode ser mantida como transição única depois da configuração.

A integração deve alimentar jogadores/estado reais e executar a preparação autoritativa por callback; não deve redesenhar a tela.

## Portão para o Claude

A camada visual está fechada quando:

- Pública, VIP e Privada são navegáveis sem seletor duplicado;
- aposta/pote respondem ao modo 2/4 jogadores no configurador;
- código/copiar, espectadores e cadeiras funcionam no mock;
- a Privada não cai no lobby legado antes de ser configurada;
- o snapshot `MesaConfigContract` preserva todas as escolhas;
- a nomenclatura visível do configurador usa STBL.

Na integração, o Claude deve então:

- usar `MesaConfigContract` como referência de entrada;
- ligar permissões VIP e saldo;
- validar/debitar custo e aposta no backend autoritativo;
- criar/entrar na sala real e gerar o código real;
- ligar ocupação e trava/liberação de cadeiras;
- construir `PreparandoPartidaVM` com 2 ou 4 jogadores reais;
- ligar matchmaking e espectadores;
- transportar chat, modalidade, meta e tempo;
- resolver o suporte real do motor a 2 jogadores;
- escolher a implementação canônica da mesa;
- preservar integralmente o layout e a hierarquia visual aprovados.
