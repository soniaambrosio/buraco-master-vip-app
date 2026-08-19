# Homologação independente — ligação do motor canônico à Casca V2 (P0)

Veredito: **APROVADA**, com duas correções de laudo aplicadas nesta branch e
duas observações registradas.

---

## 1. Gate Zero

| Item | Resultado |
|---|---|
| Candidata `origin/claude/ligacao-motor-canonico-casca-v2-p0` | `4b3c460951f83229facd7635550a1f0663e6c1da` — conferido duas vezes (fetch local e `git ls-remote` direto no remoto) |
| Base `origin/claude/perfil-ranking-estado-canonico-v1-cac971` | `bc74e30a148a56b00ca7db691a378584efaa5207` — idem |
| Ancestralidade | `merge-base(bc74e30, 4b3c460) == bc74e30` — descendência linear, sem merge |
| Árvore | limpa antes de qualquer edição |
| Branch de trabalho | `homologacao/ligacao-motor-canonico-casca-v2-p0`, criada em `4b3c460` |

**Divergência de contagem, registrada:** a OS fala em "nove arquivos declarados".
A entrega declara **doze** na §9 do próprio laudo, e o delta tem **treze**
(os doze mais o `docs/`). Nenhum arquivo falta — o delta é superconjunto do que a
OS esperava. Vale o SHA, e a divergência é de escrituração da OS, não da candidata.

Commits auditados (cinco, `bc74e30..4b3c460`):

```
c4f7447  test(casca): caracterizar o caminho atual antes de ligar a mesa online
bb4ff62  feat(mesa-online): contrato de apresentacao e adaptador da visao
6d93816  feat(mesa-online): porta unica de comandos, com idempotencia de interface
b249c63  feat(casca): a mesa online real substitui o aviso de "proxima fatia"
4b3c460  docs: registrar a ligacao da Casca V2 a mesa online
```

Delta: 13 arquivos, +5254 / −71. As 71 remoções são todas em
`lobby_online.dart` (o resumo em texto que a mesa substituiu). **Nenhuma suíte
existente foi modificada ou removida.**

---

## 2. Onde mora a autoridade

A autoridade da partida é o **servidor Node/Railway**. No cliente ela tem um
único depositário:

```
servidor  ──{tipo:'estado', visao:{…}}──▶  OnlineService.visao   (Map cru, trocado inteiro)
                                                 │
                                   AdaptadorVisaoOnline.ler()    ← única porta de LEITURA
                                                 │
                                        EstadoMesaOnline         (derivado, imutável, só-leitura)
                                                 │
                                        MesaOnlineScreen         (desenha)
                                                 │ gesto
                                   PortaDeComandosOnline         ← única porta de SAÍDA
                                                 │
                                          OnlineService ─────────▶ servidor
```

`OnlineService.visao` é o único objeto que detém estado autoritativo de partida.
`EstadoMesaOnline` é derivação sem vida própria: é reconstruído a cada `build` a
partir do mapa cru e não é armazenado em campo de estado de nenhum widget.

`lib/casca/` **não contém uma única ocorrência de `Jogo` ou `MotorPartida`**
(verificado por varredura). Os dois arquivos de produção que importam
`lib/mesa.dart` — `home_de_producao.dart` e `onde_jogar_de_producao.dart` —
o fazem só para o botão **Treino**, que é o caminho local e não fala com rede.

---

## 3. Matriz das provas exigidas (§4 da OS)

| # | Prova | Veredito | Onde se comprova |
|---|---|---|---|
| 1 | Autoridade única de regras e estado | ✅ | `OnlineService.visao`; auditoria estrutural + §2 acima |
| 2 | Casca traduz gesto em comando, não decide jogada | ✅ | `porta_de_comandos_online_test.dart` §1 (6 casos) |
| 3 | Nenhuma tela com 2ª mão/monte/lixo/turno/placar | ✅ | único estado local é `Set<String> _selecionadas`; `mesa_online_test.dart` "a mão alheia não aparece" |
| 4 | Comando inválido recusado pelo motor, sem conserto visual | ✅ | "recusa de regra preserva o estado autoritativo"; "a recusa preserva o estado autoritativo" |
| 5 | Render derivado da resposta canônica | ✅ | `AdaptadorVisaoOnline.ler()` é a única leitura; auditoria §5 proíbe a tela indexar o mapa cru |
| 6 | Reconstrução não reinicia nem duplica o motor | ✅ | "abrir e fechar o lobby não constrói um segundo transporte"; "atualizações seguintes não empilham mesa nenhuma" |
| 7 | Navegação, autenticação e geração de sessão preservadas | ✅ | `ligacao_mesa_caracterizacao_test.dart` grupo `transporte`; suíte da Casca V2 do baseline intacta |
| 8 | Sessão invalidada não continua comandando | ✅ | `encerrarSessao()` limpa `visao`+`meuAssento` e sobe a geração; "logout EM PARTIDA encerra a capacidade de jogar", "trocar de conta elimina a pilha e o estado visual anterior" |
| 9 | Falha do produtor não vira fallback de demonstração | ✅ | "falha terminal oferece ação explícita, sem laço"; nenhuma ocorrência de demo/maquete em `lib/casca/` |
| 10 | Duplo toque não produz duas transições | ✅ | "duplo toque não envia duas intenções" (3 toques → 1 mensagem); trava por intenção pendente, não por igualdade |
| 11 | Término refletido sem segunda decisão local | ✅ | grupo `desfecho` (4 casos), incl. "partida encerrada sem quem bateu não anuncia vencedor" |
| 12 | Mocks restritos a teste ou prévia identificada | ✅ | `auditoria_casca_test.dart` (baseline) grupo "a raiz de produção não alcança maquete", que varre o código alcançável e agora alcança também os arquivos novos |
| 13 | Nenhum caminho de produção instancia motor alternativo | ✅ | `auditoria_mesa_online_test.dart` §1 |

---

## 4. Verificação contra o contrato real do servidor

Conferido por leitura direta de `buraco-servidor`, `server.js` no SHA citado
pela entrega (`16a692bbe95597536b3f9975ecf32e1bde58ebcb`) — repositório **lido,
nunca alterado**. `visaoDoAssento` confere campo a campo com a §3 do laudo:

- `placar` e `jogosDupla` são chaveados por `nos`/`eles` **absolutos** — a
  correção de dupla relativa da entrega ataca um defeito real;
- `versaoEstado` de fato **não existe** na visão daquele SHA;
- `jogadorId` e `avatarTipo/avatarId/avatarVer` **são** injetados em
  `assentos[i]` (linhas 4270–4283), e o adaptador de fato os ignora —
  a afirmação da entrega procede e está coberta por teste;
- a visão de lobby (`{lobby, codigo, criador, assentos[…|{vazio:true}]}`) e o
  `{erro:"mesa não encontrada"}` conferem com os ramos de `lobby_online.dart`.

**Duas divergências encontradas**, ambas de declaração e não de comportamento:
`rodadasVulneravel` e `mortoPego` existem em `visaoDoAssento` e não constavam
nem da tabela §3 nem da lista de omissões §7. Corrigido nesta branch.

---

## 5. Execuções

Ambiente: overlay reproduzido **passo a passo** a partir de
`.github/workflows/ci-os-integracao.yml` (scaffold, `pubspec` do repo, overlay de
`lib/`, assets sem `.dart`, suítes + seeds, remoção do `widget_test.dart`).

| Execução | Candidata `4b3c460` | Baseline `bc74e30` |
|---|---|---|
| `flutter analyze --no-fatal-infos --no-fatal-warnings` | **exit 0** — 101 issues | **exit 0** — 98 issues |
| `flutter test` (glob `*_test.dart`) | **exit 0** — **855 passed** | **exit 0** — **749 passed** |
| Suítes fora do glob (`teste_*.dart`, 7 arquivos) | **exit 0** — **549 passed** | — |

Total exercitado na candidata: **1404 casos, todos verdes.**

Comparação de `analyze` item a item: os **3** issues novos são todos `info`,
todos em arquivo de **teste** (`bancada_online.dart`,
`porta_de_comandos_online_test.dart`), **nenhum em código de produção**, e
**nenhum issue do baseline desapareceu** — não houve mascaramento.

Diferença de ambiente registrada: o Flutter desta máquina é **3.41.4**; o CI pina
**3.44.8**. Os portões rodaram na versão local.

---

## 6. Observações que ficam abertas

1. **`EstadoMesaOnline.substitui` não tem chamador em produção.** É mecanismo
   correto e testado para um campo que o servidor não emite; ligá-lo hoje seria
   um portão que não filtra nada. Quem descarta mensagem de socket antigo é o
   crachá de geração do `OnlineService`, esse sim ligado e testado. A §8 do laudo
   foi precisada nesta branch para não deixar dúvida.

2. **O selo de "vulnerável · precisa N+" não é desenhado.** O servidor manda o
   dado; desenhá-lo pede a regra do mínimo por nível de vulnerabilidade, que esta
   OS proíbe tocar. Registrado como ausência declarada, não como esquecimento.

3. Um caso de teste foi **removido dentro da própria branch** (`b249c63`): ele
   afirmava a *presença* do defeito ("o caminho online termina no aviso de fatia
   seguinte"). Foi substituído pelo seu oposto no mesmo commit. Isso é disciplina
   de teste de caracterização, e **não** redução de cobertura: o arquivo é novo na
   branch e o baseline nunca teve o caso.

---

## 7. O que esta homologação NÃO fez

Perfil Publicável não integrado; nenhuma regra do Buraco alterada; nenhuma tela
redesenhada; Billing, Functions, Rules e produção intocados; nenhuma RC composta;
sem PR, sem deploy, sem APK/AAB. O repositório `buraco-servidor` foi apenas lido.
