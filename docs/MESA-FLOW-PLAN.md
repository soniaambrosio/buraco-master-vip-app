# MesaFlowPlan — plano único de travessia

`app/lib/screens/mesa_flow_plan.dart` é a fachada da camada visual/contratual para a ação **CRIAR MESA**.

Em vez de o host recalcular modalidade, número de jogadores, pote, preparação e aparência em callbacks diferentes, ele deve criar uma única vez:

`MesaFlowPlan.fromVm(configMesaVm)`

O plano reúne:

- `MesaConfigContract` — snapshot completo das escolhas;
- `MesaConfigValidation` — coerência da camada visual;
- `PreparandoPartidaVM` — participantes/contexto da transição;
- `MesaLaunchSpec` — valores que precisam chegar ao runtime;
- `MesaRendererContract` — contexto da sala separado da pele visual.

## Host Flutter limpo

Foi criado `app/lib/screens/mesa_flow_preview_host.dart` como substituto preparado para o `_ConfigMesaPreviewHost` legado de `main.dart`.

Esse host:

- mantém o tipo escolhido em **Onde jogar** sem reintroduzir seletor de ambiente;
- recalcula o pote quando muda 2/4 jogadores ou aposta;
- mantém código/copiar, espectadores e cadeiras da Privada;
- recebe callbacks visuais de convite e ações Silenciar/Bloquear/Denunciar;
- exibe **STBL** corretamente no modal de regras;
- constrói `MesaFlowPlan` uma única vez ao criar a mesa;
- recusa configuração visual incoerente;
- usa o `PreparandoPartidaVM` já derivado do contrato;
- usa a pele pública para Pública e premium para VIP/Privada;
- não abre silenciosamente o motor histórico de quatro assentos quando o usuário selecionou 1 × 1.

Ele continua propositalmente mock: servidor, saldo, assinatura, Passe Convidado, criação/entrada de sala e autoridade não foram implementados nessa camada.

## Trava importante do modo 2 jogadores

`MesaFlowPlan.podeUsarRuntimeLegado` somente é verdadeiro para configuração válida com **4 jogadores**.

O motivo é deliberado: `app/lib/mesa.dart` ainda nasceu estruturalmente com quatro assentos. A camada Flutter não deve fingir que uma seleção 1 × 1 já possui suporte autoritativo no motor.

Para 2 jogadores:

- a configuração visual funciona;
- aposta/pote usam 2 participantes;
- a preparação mostra/distribui para 2 participantes;
- o plano retorna `precisaMotorDoisJogadores == true`;
- o host limpo não abre o motor antigo como se a partida fosse 2 × 2;
- a abertura do runtime real fica condicionada ao adaptador autoritativo do motor/servidor.

Isso transforma uma incompatibilidade silenciosa em uma fronteira explícita.

## Peles do renderer

- Pública → `publica`;
- VIP → `premium`;
- Privada → `premium`.

A Privada continua com `MesaRuntimeContext.privada`. Reutilizar a pele premium não concede semântica de Mesa VIP ao ambiente privado.

## Uso esperado na integração

1. substituir o host legado pelo `MesaFlowPreviewHost` ou portar sua cadeia sem redesenhar a UI;
2. criar `MesaFlowPlan` a partir do VM aprovado;
3. se `plan.valido == false`, não criar/iniciar sala;
4. validar no backend assinatura, Passe Convidado, saldo, aposta e autoridade;
5. alimentar `plan.preparacao` com ocupantes reais;
6. preparar a sala;
7. para 4 jogadores, adaptar `plan.renderer.skin` ao renderer canônico;
8. para 2 jogadores, somente liberar a mesa após o motor autoritativo suportar 1 × 1;
9. manter `plan.renderer.context` vivo para chat, espectadores, código e controles privados.

Testes:

- `app/test/mesa_flow_plan_test.dart`;
- `app/test/mesa_flow_preview_host_test.dart`.
