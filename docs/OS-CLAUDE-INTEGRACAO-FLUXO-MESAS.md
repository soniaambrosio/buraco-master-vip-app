# ORDEM DE SERVIÇO — Integração do fluxo de mesas

Data: 09/08/2026  
Origem visual/contratual: `codex/configuracao-mesas-fluxo`  
Base original da branch: `consolidacao/apk-geral-bmv`

## 1. Objetivo

Integrar ao app real o novo fluxo de mesas já fechado na camada Flutter, preservando integralmente a experiência aprovada:

`Início → Onde jogar → Configurar ambiente escolhido → Preparando partida → Mesa`

A tarefa é de **ligação autoritativa**, não de redesign.

A integração deve conectar estado real, assinatura VIP, Passe Convidado VIP, saldo, apostas, criação/entrada de sala, convites, cadeiras, matchmaking, espectadores, chat, moderação e motor, mantendo a UI e a hierarquia visual existentes.

---

## 2. Regra de execução

Criar uma branch própria de integração a partir do head atual de `codex/configuracao-mesas-fluxo`.

Não fazer merge direto em `consolidacao/apk-geral-bmv` antes de:

- concluir a integração;
- executar análise/testes;
- revisar conflitos com branches paralelas;
- entregar relatório final com branch, commits, testes e pendências reais.

Não apagar nem sobrescrever trabalho de outras sessões/branches sem revisão explícita.

---

## 3. Leitura obrigatória antes de codar

Ler integralmente, nesta ordem:

1. `docs/CONFIGURACAO-MESAS-UI-APROVADA.md`
2. `docs/VARREDURA-FLUXO-CONFIGURACAO-MESAS.md`
3. `docs/MESA-CANONICA-E-FRONTEIRA.md`
4. `docs/MESA-FLOW-PLAN.md`
5. `app/lib/screens/configurar_mesa_screen.dart`
6. `app/lib/screens/mesa_privada_social.dart`
7. `app/lib/screens/mesa_config_contract.dart`
8. `app/lib/screens/mesa_config_validator.dart`
9. `app/lib/screens/preparando_partida_config_adapter.dart`
10. `app/lib/screens/preparando_partida_screen.dart`
11. `app/lib/screens/mesa_launch_spec.dart`
12. `app/lib/screens/mesa_renderer_contract.dart`
13. `app/lib/screens/mesa_flow_plan.dart`
14. `app/lib/screens/mesa_flow_preview_host.dart`
15. `app/lib/mesa.dart`
16. trechos relevantes de `app/lib/main.dart`
17. testes relacionados em `app/test/`

Antes de alterar `app/lib/mesa.dart`, conferir também qualquer trabalho paralelo de Motor de Partidas que ainda não esteja incorporado nesta branch para não duplicar, regredir ou sobrescrever resiliência já desenvolvida.

---

## 4. Decisões de produto que são contrato

### 4.1 Onde jogar

A escolha do ambiente acontece **uma única vez** em `Onde jogar`.

Ambientes:

- **Mesa Pública** — aberta a todos;
- **Mesa VIP** — somente jogadores VIP;
- **Mesa Privada** — ambiente social premium;
- **Treino** — fluxo próprio/offline.

Não reintroduzir seletor Pública/VIP/Privada dentro de `ConfigurarMesaScreen`.

### 4.2 Mesa Pública

Preservar:

- Aberto / Fechado / STBL;
- 2 / 4 jogadores;
- 1.500 / 3.000 pontos;
- 15 / 30 / 45 segundos;
- chat Completo / Só balões / Desligado;
- sem aposta;
- sem código;
- sem cadeiras privadas;
- sem configuração privada de espectadores;
- criação gratuita.

### 4.3 Mesa VIP

Preservar:

- somente jogador VIP pode ocupar cadeira;
- sem anúncios;
- aposta opcional `0 / 500 / 1.000 / 5.000` moedas;
- pote = aposta × jogadores;
- sem código/cadeiras da Privada;
- custo de criação visual atual: 250 moedas — não alterar monetização sem nova decisão de produto.

### 4.4 Mesa Privada

Proposta de valor:

**Monte sua mesa. Escolha seu parceiro. Escolha seus adversários. E resolvam no baralho.**

No modo 4 jogadores, os papéis são:

- DONO;
- PARCEIRO;
- OPONENTE;
- OPONENTE.

No modo 2 jogadores:

- DONO;
- OPONENTE.

O dono pode:

- convidar para cadeira específica;
- reservar cadeira;
- liberar vaga para matchmaking elegível;
- decidir se espectadores são permitidos.

O dono **não** ganha poder para expulsar arbitrariamente adversário de partida válida.

Custo de criação visual atual: 500 moedas — não alterar sem nova decisão de produto.

---

## 5. Regra VIP da Mesa Privada

Criar Mesa Privada exige VIP ativo.

**Toda pessoa que ocupa cadeira na Mesa Privada também precisa estar elegível:**

- VIP ativo; ou
- Passe Convidado VIP válido.

O código da sala **somente localiza a mesa**. Código não é autorização para ocupar cadeira.

Fluxo de convidado:

`Onde jogar → TENHO UM CÓDIGO → localizar sala → validar VIP/Passe → ocupar cadeira`

### Passe Convidado VIP

É exceção promocional, rara e controlada.

Backend deve ser fonte de verdade para:

- emissão;
- validade;
- limite de uso;
- consumo;
- idempotência;
- elegibilidade.

Não criar passe permanente ou renovação automática implícita.

Espectador pode ser não VIP quando o dono permitir, pois assistir não equivale a ocupar cadeira.

---

## 6. Chat da Mesa Privada

Na Privada, `ChatMesa.completo` é apresentado como **Livre**.

A integração deve ligar os componentes já preparados:

- **Silenciar para mim** — efeito local/individual;
- **Bloquear jogador** — impedir novas interações/convites conforme política de conta;
- **Denunciar** — registrar ocorrência para moderação.

Regras:

- bloquear durante partida válida não expulsa automaticamente o jogador;
- denúncia não altera placar/resultados por si só;
- persistência de bloqueio e denúncia deve ser autoritativa;
- tocar no menu social não pode provocar ação de jogo.

---

## 7. Cadeia obrigatória de contratos

Ao tocar em **CRIAR MESA**, usar como fachada:

`MesaFlowPlan.fromVm(configMesaVm)`

O plano reúne:

- `MesaConfigContract` — snapshot imutável das escolhas;
- `MesaConfigValidation` — coerência visual;
- `PreparandoPartidaVM` — transição com participantes/contexto;
- `MesaLaunchSpec` — parâmetros que precisam chegar ao runtime;
- `MesaRendererContract` — contexto da sala separado da pele visual.

Não voltar a recalcular manualmente essas escolhas em callbacks espalhados pelo `main.dart`.

Antes de chamar backend/motor:

- se `plan.valido == false`, não criar/iniciar sala;
- backend ainda deve validar tudo novamente de forma autoritativa.

---

## 8. Separação contexto × pele visual

Regra já fechada:

- Pública → contexto `publica` + pele pública;
- VIP → contexto `vip` + pele premium;
- Privada → contexto `privada` + pele premium.

A Privada reutilizar pele premium **não pode** apagar o contexto privado.

Código, cadeiras, parceiro/oponentes, espectadores, Passe Convidado e chat social dependem de `context == privada`.

Eliminar semanticamente o padrão perigoso:

`publica ? MesaVariant.publica : MesaVariant.vip`

Se o renderer legado ainda exigir `MesaVariant.vip` para a pele premium da Privada, manter em paralelo o contexto privado completo através dos contratos/estado de runtime.

---

## 9. Mesa canônica

A implementação canônica de runtime é:

`app/lib/mesa.dart::MesaScreen`

`app/lib/screens/mesa_screen.dart` é implementação paralela/protótipo e deve permanecer em quarentena durante esta OS.

Não criar uma terceira `MesaScreen`.

---

## 10. Substituição do host legado

O `_ConfigMesaPreviewHost` de `main.dart` é legado e ainda possui problemas conhecidos:

- usa `PreparandoPartidaVM.mock(...)`;
- preserva somente parte da configuração;
- converte não-Pública implicitamente em pele VIP;
- contém `SBTL` visível no modal;
- não leva modo/chat/aposta/espectadores/código/cadeiras ao runtime.

Usar `MesaFlowPreviewHost` como referência de arquitetura e substituir o comportamento legado pelo fluxo baseado em `MesaFlowPlan`.

O novo fluxo deve usar **STBL** em toda nomenclatura visível.

Não restaurar o lobby privado antigo como tela de criação.

---

## 11. Entrada por código

A ação `TENHO UM CÓDIGO` já existe na UI.

Ligação esperada:

1. receber código;
2. localizar sala real;
3. carregar contexto da Mesa Privada;
4. verificar se existe cadeira compatível/reservada/liberada;
5. validar VIP ativo ou Passe Convidado válido;
6. somente então autorizar ocupação;
7. alimentar preparação com os participantes reais.

Pode reutilizar serviços existentes de conexão quando apropriado, mas não pode reapresentar ao usuário o lobby legado que mistura criação e entrada e pula o configurador aprovado.

---

## 12. Criação de sala e economia

Para VIP/Privada e apostas:

- nunca confiar no saldo exibido no cliente;
- verificar saldo autoritativamente;
- validar custo de criação;
- validar aposta;
- impedir débito/concessão duplicados;
- vincular transação à sala/partida;
- tratar retry/reconexão sem duplicação;
- só refletir estado confirmado na UI.

O cliente não é autoridade para VIP, Passe, saldo, pote nem ocupação.

---

## 13. Preparando partida

Manter `PreparandoPartidaScreen` desacoplada.

Ela deve receber participantes reais por `PreparandoPartidaVM` e usar callback para preparação autoritativa.

Já está corrigida para distribuir visualmente apenas às posições presentes:

- 2 participantes → 2 destinos;
- 4 participantes → 4 destinos.

Não voltar a quatro destinos fixos.

Falha de som nunca pode bloquear entrada na partida.

Falha de preparação deve permitir retry sem duplicar criação/aposta.

---

## 14. Modo 2 jogadores — BLOQUEADOR real

A UI, o pote e a preparação já suportam 2 jogadores.

O runtime/motor histórico ainda nasceu com estrutura de quatro assentos.

`MesaFlowPlan.podeUsarRuntimeLegado` só libera o runtime legado para 4 jogadores.

Para 2 jogadores:

- não inserir robôs/jogadores invisíveis apenas para satisfazer estrutura antiga;
- não abrir silenciosamente mesa 2 × 2;
- implementar/adaptar suporte autoritativo real a 1 × 1 no motor/servidor;
- reconciliar essa alteração com trabalhos paralelos do Motor de Partidas antes de editar `mesa.dart`.

Critério: uma partida marcada como 2 jogadores deve ter exatamente dois participantes esportivos e duas posições válidas em toda a cadeia.

---

## 15. Matchmaking

### Pública

Preencher lugares conforme regras públicas e disponibilidade, sem herdar controles de Privada.

### VIP

Somente participantes VIP elegíveis.

### Privada

- cadeira travada: não completar automaticamente;
- cadeira liberada: matchmaking apenas entre jogadores elegíveis para Privada;
- preservar papel da cadeira (parceiro/oponente);
- nunca substituir dono ou convidado confirmado por toque acidental/atualização de estado.

---

## 16. Espectadores

Na Privada, respeitar escolha do dono.

Espectador:

- não ocupa cadeira;
- não participa de aposta como jogador;
- não recebe cartas privadas;
- não pode executar ação de jogo;
- pode ser não VIP quando permitido.

Garantir visão recortada e ausência de vazamento de mão/cartas privadas.

---

## 17. Navegação

Fluxo ativo obrigatório:

`Splash/Inicio → Onde jogar → Configurar → Preparando → Mesa`

Quarentenar/remover atalhos mortos que abrem configurador diretamente sem passar por `Onde jogar`, desde que comprovadamente não sejam necessários a outro fluxo ativo.

Não fazer faxina destrutiva em código legado sem teste de referência.

---

## 18. Testes obrigatórios

Antes de declarar concluído, executar no mínimo:

- `dart format` nos arquivos alterados;
- `flutter analyze`;
- suíte de testes Flutter relevante;
- testes de motor afetados;
- testes do servidor/backend afetado;
- testes de idempotência/economia quando houver débito/aposta;
- testes de reconexão/duplicidade quando a sala for criada ou iniciada.

Executar especificamente os testes de contrato/fluxo desta branch, incluindo:

- `configurar_mesa_ui_contract_test.dart`;
- `mesa_launch_spec_test.dart`;
- `mesa_flow_plan_test.dart`;
- `mesa_flow_preview_host_test.dart`;
- testes da preparação 2/4 jogadores.

Se algum teste existente falhar, não mascarar nem remover teste para obter verde. Identificar regressão ou incompatibilidade.

---

## 19. Casos de aceite funcionais

Validar pelo menos:

### Pública 4 jogadores

- configura;
- cria/entra em matchmaking;
- preparação recebe 4;
- mesa recebe modalidade/meta/tempo/chat corretos.

### Pública 2 jogadores

- exatamente 2 participantes;
- preparação 2;
- runtime 1 × 1 real.

### VIP 4 jogadores com aposta

- gate VIP;
- aposta e pote coerentes;
- débito idempotente;
- preparação 4;
- pele premium;
- contexto VIP preservado.

### Privada 4 jogadores

- dono escolhe parceiro/oponentes;
- convites por cadeira;
- cadeira travada/liberada funciona;
- todos os jogadores validam VIP/Passe;
- espectador segue escolha do dono;
- chat Livre funciona;
- Silenciar/Bloquear/Denunciar estão ligados;
- preparação recebe os participantes corretos;
- pele premium + contexto privado preservados.

### Privada por código

- código localiza sala;
- não VIP sem passe não ocupa cadeira;
- VIP entra;
- Passe Convidado válido entra dentro das regras;
- passe inválido/expirado é recusado;
- código sozinho nunca concede acesso.

### Privada 2 jogadores

- DONO + OPONENTE;
- não mostrar parceiro fictício;
- motor 1 × 1 real;
- pote e aposta calculados por 2;
- preparação distribui para 2.

---

## 20. Proibições

Não:

- redesenhar as telas;
- alterar textos/ordem/hierarquia aprovados sem necessidade técnica real;
- reintroduzir seletor de tipo no configurador;
- remover a aposta VIP;
- alterar custos 250/500 sem decisão de produto;
- permitir carona ilimitada de não VIP na Privada;
- transformar código em autorização;
- transformar dono em moderador capaz de expulsar adversário por vontade própria;
- transformar Privada semanticamente em VIP;
- usar `screens/mesa_screen.dart` como runtime concorrente;
- fingir suporte 2 jogadores com quatro assentos invisíveis;
- editar backend/bundle gerado manualmente sem fonte canônica confirmada;
- fazer merge/publicação/release apenas para “testar”.

---

## 21. Entrega esperada do Claude

Ao concluir, responder com:

1. branch de trabalho;
2. commit final e SHA remoto;
3. lista de arquivos alterados;
4. resumo de como cada contrato foi ligado;
5. como Pública/VIP/Privada chegam ao runtime;
6. solução real do modo 2 jogadores;
7. solução de VIP/Passe por cadeira;
8. solução de aposta/custo/idempotência;
9. solução de código/convites/cadeiras;
10. solução de chat/bloqueio/denúncia;
11. testes executados e resultados exatos;
12. `flutter analyze` exato;
13. qualquer pendência real — sem chamar de concluído se ainda depender de mock, stub ou host legado;
14. confirmação de que não houve merge/publicação/release não autorizados.

## 22. Definição de pronto

Só considerar esta OS concluída quando o caminho real respeitar:

`Onde jogar → Configuração aprovada → validação autoritativa → preparação coerente → Mesa canônica`

sem perder nenhuma escolha, sem burlar VIP/Passe, sem cair em lobby legado e sem simular 1 × 1 sobre motor 2 × 2.

A UI aprovada deve chegar ao final **visualmente intacta**.