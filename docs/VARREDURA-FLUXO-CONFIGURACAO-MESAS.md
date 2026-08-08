# Varredura final — fluxo de configuração de mesas

Data: 08/08/2026
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
- Mesa Privada possui resumo antes da criação;
- botão voltar retorna ao seletor de ambiente;
- Treino permanece fora do configurador e abre o fluxo próprio de treino.

## Quarentena do lobby privado legado

O `main.dart` ainda contém `_OnlineLobbyHost`, criado anteriormente como prova de conexão do servidor.

Ele **não pertence ao fluxo visual aprovado de criação da Mesa Privada**. Enquanto a integração final não é feita, a opção visual da Mesa Privada usa o identificador interno `privada_config`, que evita cair no atalho legado `id == 'privada'` e encaminha a navegação para `ConfigurarMesaScreen`.

Essa quarentena é intencional: preserva a prova técnica do servidor sem permitir que ela substitua ou pule a nova tela aprovada.

Na ligação final, o Claude deve retirar o atalho legado e conectar o botão **CRIAR MESA PRIVADA** ao serviço real de criação da sala.

## Sigla da modalidade

A sigla oficial do produto é **STBL**. Qualquer ocorrência antiga de `SBTL` deve ser tratada como texto legado e uniformizada durante a ligação final, sem alterar a regra do jogo.

## Preparando partida

A tela `PreparandoPartidaScreen` continua propositalmente desacoplada de servidor e motor. Ela recebe callbacks de preparação e conclusão, portanto pode ser mantida como transição única depois da configuração.

A integração deve apenas alimentar os jogadores/estado reais e executar a preparação autoritativa por callback; não deve redesenhar a tela.

## Portão para o Claude

A UI somente será considerada pronta para ligação quando:

- Pública, VIP e Privada forem navegáveis sem retorno a seletor duplicado;
- aposta/pote atualizarem corretamente para 2 e 4 jogadores;
- código/copiar, espectadores e cadeiras funcionarem no mock;
- não houver caminho ativo que pule a configuração aprovada;
- a nomenclatura STBL estiver uniforme no fluxo entregue.

Depois disso, a responsabilidade do Claude é exclusivamente integrar estado real, permissões VIP, saldo, aposta, sala, matchmaking, servidor/Firebase e callbacks, preservando o layout e a hierarquia visual aprovados.
