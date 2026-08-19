# Evidência — conexão autenticada do cliente (V1)

Complemento de [CLIENTE-SERVIDOR-AUTH-CONTRATO-V1.md](CLIENTE-SERVIDOR-AUTH-CONTRATO-V1.md).
Aqui está o que foi observado, o que foi executado e o que **não** foi possível
executar nesta máquina.

---

## 1. Gate zero

| # | Exigência | Resultado |
|---|---|---|
| 1 | base, árvore limpa, refs remotas | `origin/consolidacao/apk-geral-bmv` = `0cea0d6d68f2c93613b985f4aa85800d77cf42d7`, **igual** ao SHA da OS. `fetch` com refspec explícito. Árvore limpa |
| 2 | mapear criações de WebSocket/HTTP e endpoints | **uma só**: `WebSocketChannel.connect` em `online_service.dart:62`, com `const servidorUrl = 'wss://buraco-servidor-production.up.railway.app'` na linha 22. Nenhum outro cliente de rede no `app/` |
| 3 | provar qual cliente a mesa jogável chama | `OnlineService` é instanciado **num único lugar**: `_OnlineLobbyHost` em `main.dart:1049`, alcançado pelo botão "online" do seletor de mesa |
| 4 | a folha `ws-auth` já é alcançável pela base? | **NÃO.** `git merge-base --is-ancestor 13582dd 0cea0d6` → falso. A folha está **dois commits à frente** da base, não atrás |
| 5 | congelar SHA, comparar diff, incorporar o mínimo | congelado `13582ddfa0f9b8cccc81b20e51705bf666ca8754` (prefixo `13582dd` confere). Diff: 5 arquivos, +1133/−39. Incorporado por cherry-pick `-x` em dois commits identificados |
| 6 | registrar o contrato do servidor | `buraco-servidor @ 71199e81ff44d41c8fcdb41cd866b38c0cf14fee`, conferido como ponta exata de `seguranca/ws-auth-identidade`. **Lido, não alterado, não publicado** |

Nenhuma condição de parada foi atingida: a folha existe no remoto, o SHA começa
por `13582dd`, e o contrato observado **não diverge** do servidor congelado.

### Correção de base

A branch de trabalho nasceu apontando para `fb9edb5` — o `main` placeholder do
repositório, não a base da OS. Foi reapontada para `0cea0d6` antes de qualquer
edição. É o problema conhecido de worktree deste repositório.

### Verificação da incorporação

```
git diff 13582ddfa0f9b8cccc81b20e51705bf666ca8754 HEAD   → vazio
```

A árvore ficou **idêntica** à folha congelada antes de começar o trabalho novo.

---

## 2. O que a base já tinha, e o que faltava

A folha `ws-auth` já entregava credencial antes do socket, protocolo 2, fila
presa até autenticar, renovação e estados terminais. O que **faltava** para o
app publicável — e é o que esta OS fez:

| Item da OS | Antes | Agora |
|---|---|---|
| endereço explícito e validado | `const` gravada no código | `--dart-define` + validação por perfil |
| release falha cedo com endereço ruim | nada impedia | recusado no CI **e** em execução |
| dev/teste só por configuração explícita | não existia | `BMV_PERMITIR_ENDPOINT_INSEGURO`, sem efeito em release |
| backoff com jitter | sem jitter (2,4,…12s) | metade fixa + metade sorteada |
| limite de tentativas | **infinito** | 6, depois `semConexao` |
| geração de sessão | não existia | toda entrada tardia confere |
| renovação coordenada | uma trava frouxa | uma renovação por vez, de verdade |
| mensagens de sessão antiga | entravam | descartadas |
| projeção autorizada | qualquer `estado` era aceito | exige assento; apagada em logout/recusa |
| redação de segredos | só o cuidado no caminho normal | utilitário aplicado no caminho anormal |

### Defeito encontrado pelo próprio portão

O teste que repete `authExpirou` cinco vezes reprovou a primeira implementação:
**seis** pedidos de token em vez de dois. A trava de renovação era solta quando
o token chegava, e não quando a renovação terminava — deixando uma janela em que
os avisos seguintes disparavam pedidos novos. Era a tempestade de refresh, só
que mais curta. Corrigido; a trava agora cai em `_aoAutenticar` ou numa falha.

---

## 3. Cobertura dos testes exigidos (§6 da OS)

Servidor **falso** em memória (`_CanalFalso`), credencial injetada. Nenhum teste
abre socket de verdade nem toca produção.

| # | Exigido | Onde | Provas |
|---|---|---|---|
| 1 | endpoint válido/inválido por perfil | `conexao_producao_test.dart` §1 | 8 |
| 2 | protocolo 1 recusado, 2 aceito | §2 | 3 |
| 3 | token válido, expirado, inválido, refresh concorrente | §3 | 5 |
| 4 | ausência de identidade autodeclarada | §4 | 2 |
| 5 | redação de token, UID, e-mail, purchaseToken, secrets | §5 | 6 |
| 6 | queda em jogo, reconexão, cancelamento no logout, limite | §6 | 7 |
| 7 | rebuild/rotação sem duplicar socket | §7 | 4 |
| 8 | mensagens atrasadas de sessão antiga descartadas | §8 | 3 |
| 9 | jogador e espectador só com projeção autorizada | §9 | 5 |
| 10 | testes existentes, `analyze` e suíte completa verdes | abaixo | — |

Sobre o **item 9**: o servidor congelado não tem papel de espectador — só envia
`estado` para conexão com assento e credencial válida agora. "Espectador" ali é
uma conexão sem assento, que **não recebe projeção nenhuma**. O app espelha
exatamente isso; nada foi inventado para preencher um papel que o contrato não
define.

---

## 4. Execução

Rodado em scaffold local (`flutter create` + overlay de `app/lib`, como o CI
faz), Flutter 3.41.4 · Dart 3.11.1.

```
flutter test test/teste_motor.dart test/torneios/reward_grants_test.dart \
             test/online_auth_test.dart test/conexao_producao_test.dart
→ 286 testes, 286 verdes
```

| Suíte | Testes |
|---|---|
| `teste_motor.dart` | 132 |
| `torneios/reward_grants_test.dart` | 80 |
| `online_auth_test.dart` | 31 |
| `conexao_producao_test.dart` | **43** (novos) |
| **total** | **286** |

```
flutter analyze lib test
→ 105 issues — EXATAMENTE a linha de base anterior
```

Nenhum apontamento novo, e nenhum nos arquivos desta OS. A base de comparação
foi medida na árvore da folha congelada, antes das mudanças: também 105.

### Alvos explícitos, não `flutter test` puro

`teste_motor.dart` **não casa** com o glob `*_test.dart` do `flutter test`. Sem
alvo explícito, a execução acha 111 testes e passa — escondendo 132. Os números
acima são de alvos nomeados, como o CI faz.

### Dois testes existentes ajustados

Ambos por mudança real de comportamento, não para fazer passar:

1. **URL do socket** — a suíte comparava com `OnlineService.servidorUrl`, que
   deixou de existir quando o endereço saiu do código. Passou a comparar com o
   endereço injetado no cenário.
2. **"servidor mudo não pendura o app"** — a suíte afirmava que o status deixava
   de ser `autenticando`. Com o backoff inicial mais curto (0,25–0,5s contra os
   2s antigos), a tentativa **seguinte** já começa dentro da janela do teste, e
   o status volta a `autenticando` legitimamente. A prova passou a afirmar o que
   realmente importa: o socket mudo é **abandonado** e uma tentativa nova
   começa — que é o oposto de pendurar.

O harness da suíte incorporada também recebeu o endereço injetado (uma linha),
porque o construtor deixou de ter endereço embutido.

---

## 5. O que NÃO foi executado

| Item | Por quê |
|---|---|
| `flutter build apk` local | falha por symlink nesta máquina (exige Modo de Desenvolvedor). Medição de APK é do CI — limitação conhecida da máquina, não desta entrega |
| execução dos portões novos no CI | o CI deste repositório só dispara por `workflow_dispatch`, e workflow novo só roda depois de chegar na branch padrão. Os passos foram escritos, não observados verdes |
| conexão contra o servidor real | proibido pela OS (nenhum teste atinge produção) e impossível: o servidor autenticado **não está implantado** — o que está no ar é a era pré-auth |

O portão de configuração do CI foi conferido por leitura, não por execução. Ele
é shell puro, sem dependência nova.

---

## 6. Fronteira respeitada

- **OS 1** (casca, rotas, menus): não tocada. As mudanças em `main.dart` estão
  todas dentro de `_OnlineLobbyHost` — o host da conexão — mais uma redação no
  erro de login, que é tratamento de credencial.
- **OS 3** (Crashlytics, workflows de release): nenhum Crashlytics. Em
  `build.yml` entraram **dois passos isolados** e o `--dart-define` no build —
  o mínimo indispensável ao contrato de endereço, que a OS permite
  explicitamente. Nada de assinatura, versionamento ou publicação foi alterado.
- **Servidor, regras, economia, Billing, Play Console**: intocados. O repositório
  do servidor foi aberto **somente para leitura** do SHA congelado.

---

## 7. Pendências que esta entrega não fecha

Não são defeitos desta OS — são o que fica para quem for implantar.

1. **A implantação tem de ser coordenada.** Não existe compatibilidade cruzada,
   de propósito: este app não joga contra o servidor em produção hoje, e o app
   publicado hoje não joga contra o servidor novo. Ordem em
   `docs/WS-AUTH-IDENTIDADE.md` do repositório do servidor, §5.
2. **`FIREBASE_PROJECT_ID` precisa existir no Railway** antes do servidor subir —
   sem ele o verificador recusa toda credencial.
3. **`BMV_SERVIDOR_URL` precisa ser definida** como variável de repositório se o
   host mudar. O padrão do workflow aponta para o host atual.
4. **Retomada de assento não existe** no servidor: quem cai vira bot e não
   reassume. Pré-existente, fora do escopo.
5. **Contas legadas `j-<random>`**: corte limpo, sem migração — decisão fechada
   no repositório do servidor. Nada neste app envia identificador legado, e nada
   deve passar a enviar.
