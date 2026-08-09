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

## Trava importante do modo 2 jogadores

`MesaFlowPlan.podeUsarRuntimeLegado` somente é verdadeiro para configuração válida com **4 jogadores**.

O motivo é deliberado: `app/lib/mesa.dart` ainda nasceu estruturalmente com quatro assentos. A camada Flutter não deve fingir que uma seleção 1 × 1 já possui suporte autoritativo no motor.

Para 2 jogadores:

- a configuração visual funciona;
- aposta/pote usam 2 participantes;
- a preparação mostra/distribui para 2 participantes;
- o plano retorna `precisaMotorDoisJogadores == true`;
- a abertura do runtime real fica condicionada ao adaptador autoritativo do motor/servidor.

Isso transforma uma incompatibilidade silenciosa em uma fronteira explícita.

## Peles do renderer

- Pública → `publica`;
- VIP → `premium`;
- Privada → `premium`.

A Privada continua com `MesaRuntimeContext.privada`. Reutilizar a pele premium não concede semântica de Mesa VIP ao ambiente privado.

## Uso esperado na integração

1. criar `MesaFlowPlan` a partir do VM aprovado;
2. se `plan.valido == false`, não criar/iniciar sala;
3. validar no backend assinatura, Passe Convidado, saldo, aposta e autoridade;
4. alimentar `plan.preparacao` com ocupantes reais;
5. preparar a sala;
6. para 4 jogadores, adaptar `plan.renderer.skin` ao renderer canônico;
7. para 2 jogadores, somente liberar a mesa após o motor autoritativo suportar 1 × 1;
8. manter `plan.renderer.context` vivo para chat, espectadores, código e controles privados.

Os testes de contrato ficam em `app/test/mesa_flow_plan_test.dart`.
