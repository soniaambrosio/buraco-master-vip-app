# HANDOFF CLAUDE — Fluxo de Mesas

Data: 10/08/2026
Branch de origem: `codex/configuracao-mesas-fluxo`

## Leitura obrigatória

Antes de codar, ler integralmente:

1. `docs/OS-CLAUDE-INTEGRACAO-FLUXO-MESAS.md`
2. `docs/OS-CLAUDE-ADENDO-ORIENTACAO-MESA.md`
3. `docs/OS-CLAUDE-ADENDO-CELEBRACAO-VITORIA.md`
4. todos os documentos e arquivos apontados pela OS principal.

Os adendos de orientação e celebração de vitória são requisitos de produto e possuem o mesmo peso dos demais critérios de aceite.

## Regra de execução

Criar branch própria de integração a partir do head atual desta branch.

Não redesenhar as telas aprovadas.

Não fazer merge, release ou publicação sem autorização.

## Resultado esperado

Entregar o fluxo real:

`Onde jogar → Configurar → Preparando → Mesa → Resultado`

com Pública/VIP/Privada, 2/4 jogadores, contratos preservados, Mesa Privada social VIP, entrada por código, suporte autoritativo do motor, Mesa canônica com orientação **Vertical / Horizontal / Automática** e celebração final da dupla vencedora.

A troca de orientação deve ser puramente visual, sem reiniciar partida, timer, conexão, chat, mão, aposta ou sala.

No resultado final confirmado, a dupla vencedora deve receber a celebração padrão preparada no Flutter: confete para destacar os vencedores e `sons/vitoria.mp3` tocado uma única vez nos dispositivos dos integrantes vencedores, respeitando a preferência de efeitos sonoros. O resultado autoritativo deve fornecer `eventoId` e assentos vencedores; rebuild/reconexão não pode repetir a comemoração.

Efeitos de vitória premium podem substituir ou enriquecer a camada cosmética, mas o confete padrão gratuito é o fallback obrigatório e nunca altera regra, placar ou recompensa.

Ao finalizar, informar:

- branch;
- commit/hash remoto;
- arquivos alterados;
- testes executados e resultados;
- pendências reais;
- confirmação explícita de que a UI aprovada não foi redesenhada.
