# Pacote de Publicação Google Play — V1

**OS:** Pacote de Publicação Google Play V1 — Buraco Master VIP
**Base auditada:** `consolidacao/apk-geral-bmv` @ `0cea0d6`
**Data:** 2026-08-14
**Escopo:** elementos de publicação que independem do AAB definitivo.
**Regra desta auditoria:** nada afirmado por suposição. Cada linha aponta evidência
em código/configuração, ou está marcada **A CONFIRMAR**.

> **Aviso de leitura.** Este documento não descreve um app pronto para produção com
> a ficha faltando. Ele descreve um app cujo pipeline atual é **de teste** e cuja
> ficha de loja **não existe em lugar nenhum do repositório**. A seção 8 resume.

---

## 0. Achados que mudam o enquadramento da OS

Antes da ficha, quatro fatos verificados que determinam o que é possível declarar:

| # | Achado | Evidência |
|---|---|---|
| 0.1 | O pipeline produz **APK**, não **AAB**. A Play exige AAB para apps novos. | [.github/workflows/build.yml:493](.github/workflows/build.yml:493) — `flutter build apk --release --split-per-abi`. Nenhuma ocorrência de `appbundle`/`aab` no workflow. |
| 0.2 | O `applicationId` é de **POC**: `com.buracomastervip.poc.buraco_master_vip`. Uma vez publicado, o package name é **imutável para sempre**. | [.github/workflows/build.yml:16](.github/workflows/build.yml:16); confirmado no gradle gerado (`applicationId = "com.buracomastervip.poc.buraco_master_vip"`). |
| 0.3 | O app é assinado com **keystore de teste**, com as senhas **em texto claro no workflow versionado**. | [build.yml:20-24](.github/workflows/build.yml:20) — `BMV_STORE_PASSWORD: bmvtest2026`. Keystore em `keystore/buraco-master-vip-test.jks.b64`. |
| 0.4 | O ícone do app é o **ícone padrão do Flutter**. Nenhum passo do pipeline troca o launcher icon. | `grep -i "icon\|launcher\|mipmap"` no workflow → **zero ocorrências**. Manifest gerado usa `android:icon="@mipmap/ic_launcher"`, e os PNGs são os do scaffold. |

Consequência: **0.1 e 0.2 são bloqueadores duros**. 0.3 e 0.4 são bloqueadores de
release. Nenhum deles é resolvido pela ficha de loja.

---

## 1. Ficha da Loja (metadados textuais)

Nenhum texto de ficha existe no repositório. A busca por arquivos de listing
(`store`, `listing`, `fastlane`, `metadata`) não retornou nada. O que segue separa
**o que o código comprova** de **o que precisa ser decidido pela Sônia**.

| Campo | Situação | Evidência / Observação |
|---|---|---|
| **Nome do app** | **PENDENTE** — decisão | Único nome real no código: `title: 'Buraco Master VIP'` em [app/lib/main.dart:75](app/lib/main.dart:75). Mas o `android:label` instalado é **"BMV Teste"** ([build.yml:304](.github/workflows/build.yml:304)). Limite da Play: 30 caracteres. `Buraco Master VIP` = 17 ✅ |
| **Descrição curta** (80 car.) | **PENDENTE** — não existe | Nenhuma fonte no repo. Proposta na §1.1 (requer aprovação). |
| **Descrição completa** (4000 car.) | **PENDENTE** — não existe | Idem. Só pode ser escrita depois de fechar §7 (o que de fato funciona). |
| **Categoria** | **PENDENTE** — decisão | Não declarada em lugar nenhum. Sugestão técnica: `Jogos › Cartas`. |
| **Tags** | **PENDENTE** — decisão | A Play permite até 5 tags, escolhidas de lista fechada no Console. Não há fonte no repo. |
| **Contato de suporte (e-mail)** | **PENDENTE** — não existe | Obrigatório. No app, Suporte é stub: `onSuporte: () => _aviso('Suporte — em breve.')` em [app/lib/main.dart:737](app/lib/main.dart:737). |
| **Site** | **A CONFIRMAR** | Existe um domínio vivo usado pelo pipeline antigo: `soniaambrosio.github.io/buraco-master-vip`. Serve como site? Decisão da Sônia. |
| **Política de privacidade (URL)** | **PENDENTE** — não existe | **Obrigatório para publicar.** No app: `onTermos: () => _aviso('Termos e privacidade — em breve.')` em [app/lib/main.dart:738](app/lib/main.dart:738). Nenhum HTML/MD de política no repo. |
| **URL de exclusão de conta** | **PENDENTE** — não existe | **Obrigatório**, porque o app tem login (Firebase Auth). Busca por `deleteAccount\|excluirConta\|exclusão de conta` no repo → **nenhuma implementação**. Existe branch `claude/player-account-deletion-flow-d04d45` **não mesclada** → ver §8, DEPENDE DE OUTRA OS. |
| **Anúncios** | **PRONTO** — declarar **"Não contém anúncios"** | Nenhum SDK de anúncio. Dependências completas do build: `firebase_core`, `firebase_auth`, `google_sign_in`, `audioplayers`, `web_socket_channel`, `shared_preferences` ([build.yml:146](.github/workflows/build.yml:146)), e os imports do código batem exatamente com essa lista. Sem AdMob/Unity/AppLovin. |
| **Compras no app** | **CONFLITO** — ver §7.1 | A Play pergunta se há compras. Hoje: a Loja **exibe preços em R$** ([app/lib/screens/loja_screen.dart:37-100](app/lib/screens/loja_screen.dart:37)) mas **não há `in_app_purchase`** no build. Declarar "sim" é falso; publicar a tela como está é risco de reprovação. |
| **Classificação indicativa** | **PENDENTE** — questionário | Ver §5. Depende de fechar "há chat?" e "há compras?". |
| **Países / distribuição** | **PENDENTE** — decisão | Único idioma suportado no código: `enum Idioma { ptBR }` em [app/lib/screens/configuracoes_screen.dart:5](app/lib/screens/configuracoes_screen.dart:5). Sugere Brasil (+ Portugal), mas é decisão comercial, não técnica. |

### 1.1 Textos propostos (rascunho — **não aprovados**)

Marcados como proposta justamente porque a OS proíbe inventar. Só valem depois que
§7 definir o que o app entrega de verdade.

- **Descrição curta (rascunho, 62 car.):**
  `Buraco clássico em português, com mesas, ranking e torneios.`
  ⚠️ "torneios" e "ranking" hoje são telas de prévia com dados mock (§7).

- **Descrição completa:** **não redigida de propósito.** Escrever agora produziria
  uma descrição de funcionalidades que não funcionam — exatamente o que a política
  de *Misrepresentation* da Play reprova. Fica bloqueada até §7.

---

## 2. Data Safety (Segurança dos dados)

Cada linha aponta o código que a sustenta. Onde não há prova, está **A CONFIRMAR**.

### 2.1 Coleta de dados — verificado

| Dado | Coletado? | Evidência | Finalidade | Obrigatório? |
|---|---|---|---|---|
| **E-mail** | **SIM** | `GoogleSignIn(scopes: const ['email'])` — [app/lib/main.dart:43-46](app/lib/main.dart:43). Lido em `u.email` — [main.dart:645](app/lib/main.dart:645), exibido em [main.dart:1763](app/lib/main.dart:1763). | Login / identificação da conta | Sim (não há modo convidado com conta) |
| **Nome** | **SIM** | `u.displayName` — [main.dart:644](app/lib/main.dart:644), [perfil_service.dart:63-64](app/lib/services/perfil_service.dart:63), exibido em [main.dart:1758](app/lib/main.dart:1758). | Identidade do jogador | Sim, se logar |
| **Foto de perfil** | **SIM** | `u.photoURL` carregado via `NetworkImage` — [main.dart:1744-1745](app/lib/main.dart:1744). | Avatar | Sim, se logar |
| **ID de usuário (UID)** | **SIM** | `FirebaseAuth.instance.currentUser` — [main.dart:642](app/lib/main.dart:642), [main.dart:1545](app/lib/main.dart:1545). | Conta | Sim |
| **Apelido (nickname)** | **SIM — enviado a servidor próprio** | Enviado ao WebSocket em `criarMesa`/`entrarMesa` — [online_service.dart:108-118](app/lib/services/online_service.dart:108). | Multiplayer | Sim, no online |
| **Preferências do app** | **SIM — só local** | `SharedPreferences` — [configuracoes_service.dart:36,61](app/lib/services/configuracoes_service.dart:36). Não sai do aparelho. | Configuração | — |

### 2.2 Não coletado — verificado por ausência

| Dado | Evidência da ausência |
|---|---|
| Localização | Nenhum plugin de localização nas 6 dependências ([build.yml:146](.github/workflows/build.yml:146)). |
| Contatos / agenda | Idem. |
| Fotos / câmera / microfone | Idem. Nenhum `image_picker`, `camera`, `permission_handler`. |
| Analytics / uso do app | Sem `firebase_analytics`. |
| Crash logs / diagnóstico | Sem `firebase_crashlytics`. |
| Info financeira / pagamento | Sem `in_app_purchase`, sem SDK de billing. |
| Histórico de partidas no servidor | Sem `cloud_firestore` na build. Os comentários do código confirmam que persistência é "Fase B" — [perfil_service.dart:8-13](app/lib/services/perfil_service.dart:8). |

### 2.3 Compartilhamento com terceiros

| Destino | Compartilha? | Evidência |
|---|---|---|
| **Google (Firebase Auth / Google Sign-In)** | **SIM** | Projeto `buraco-master-vip`, config em [main.dart:55-61](app/lib/main.dart:55); `serverClientId` em [main.dart:45-46](app/lib/main.dart:45). |
| **Servidor de partidas (Railway)** | **SIM — apelido** | `wss://buraco-servidor-production.up.railway.app` — [online_service.dart:22-23](app/lib/services/online_service.dart:22). |
| Redes de anúncio | **NÃO** | Sem SDK (§2.2). |

⚠️ **Ponto de atenção:** o servidor Railway é **infraestrutura própria da Sônia**, não
um terceiro. Na taxonomia da Play isso é *coleta*, não *compartilhamento*. Mas o
código-fonte do servidor **não está neste repositório** — a declaração sobre o que
ele armazena e por quanto tempo **não pode ser feita a partir deste repo**.

### 2.4 Criptografia, retenção e exclusão

| Item | Situação | Evidência |
|---|---|---|
| **Criptografia em trânsito** | **SIM — verificado** | WebSocket em `wss://` (TLS) — [online_service.dart:23](app/lib/services/online_service.dart:23). Firebase Auth é HTTPS por padrão. Nenhum `usesCleartextTraffic` no manifest (o manifest não declara nada — §3). |
| Ressalva de cleartext | **Observação** | Helpers de imagem aceitam `http://` — [hall_screen.dart:428](app/lib/screens/hall_screen.dart:428), [inicio_screen.dart:944](app/lib/screens/inicio_screen.dart:944), [ranking_screen.dart:1130](app/lib/screens/ranking_screen.dart:1130). Na prática o Android 9+ bloqueia cleartext por padrão, então o caminho falha em vez de trafegar em claro. Não é falha de segurança, mas é código morto a limpar. |
| **Criptografia em repouso** | **A CONFIRMAR** | Fora deste repo. Depende do Firebase (criptografado por padrão) e do servidor Railway (**sem fonte auditável aqui**). |
| **Retenção** | **A CONFIRMAR** | Nenhuma política de retenção existe em código ou documento. Precisa ser **definida**, não descoberta. |
| **Exclusão de dados pelo usuário** | **NÃO EXISTE** | Busca no repo por exclusão de conta → nenhuma implementação. O único "Sair da conta" ([configuracoes_screen.dart:890](app/lib/screens/configuracoes_screen.dart:890)) faz `signOut`, não apaga nada — [main.dart:712-715](app/lib/main.dart:712). |

**Veredito da §2:** o formulário de Data Safety **pode ser preenchido** para o app
tal como está hoje, com uma exceção: tudo que depende do **servidor Railway**
(retenção, repouso, o que é gravado) é **A CONFIRMAR** e exige auditoria do repo
`buraco-servidor`, que não está aqui.

---

## 3. Permissões Android

**Evidência direta** (scaffold reproduzido localmente com `flutter create`, mesmos
parâmetros do CI — `--org com.buracomastervip.poc --project-name buraco_master_vip`):

- O `AndroidManifest.xml` principal **não declara nenhum `<uses-permission>`**.
- `INTERNET` aparece **apenas** no manifest de *debug*
  (`android/app/src/debug/AndroidManifest.xml`), que **não entra no release**.
- O manifest principal declara apenas um `<queries>` para `ACTION_PROCESS_TEXT`
  (padrão do engine Flutter).

| Permissão | Origem esperada | Status |
|---|---|---|
| `INTERNET` | Merge do manifest das libs Firebase / Play Services | **A CONFIRMAR** |
| `ACCESS_NETWORK_STATE` | Idem | **A CONFIRMAR** |
| `WAKE_LOCK` | Play Services | **A CONFIRMAR** |
| Qualquer outra | — | **A CONFIRMAR** |

**Não afirmo a lista final.** O app não declara permissões por conta própria; tudo
vem do *manifest merger* das dependências, e o merged manifest só existe depois de
um build. Método exato para fechar isso, sem suposição:

```bash
aapt2 dump permissions app-arm64-v8a-release.apk
```

O APK já é produzido pelo CI ([build.yml:493](.github/workflows/build.yml:493)) e
publicado como release `latest`. Um passo de dump no workflow encerra este item.

---

## 4. SDKs de terceiros — **PRONTO** (lista fechada e verificada)

Fonte única: [build.yml:146](.github/workflows/build.yml:146), cruzada com todos os
`package:` importados em `app/lib` (as duas listas batem exatamente).

| SDK | Versão | Coleta dado pessoal? |
|---|---|---|
| `firebase_core` | livre | Não diretamente |
| `firebase_auth` | livre | **Sim** — e-mail, UID, nome, foto |
| `google_sign_in` | `^6.2.1` | **Sim** — e-mail, perfil Google |
| `audioplayers` | livre | Não |
| `web_socket_channel` | livre | Transporte (apelido) |
| `shared_preferences` | livre | Não (só local) |
| `jni` | **travado em 1.0.0** | Transitiva. Override em [build.yml](.github/workflows/build.yml) — o 1.0.1 quebra o gradle. |

Ausências relevantes e confirmadas: **sem** analytics, **sem** crashlytics, **sem**
rede de anúncios, **sem** billing, **sem** Firestore.

⚠️ Note que `firebase_core`, `firebase_auth`, `audioplayers`, `web_socket_channel` e
`shared_preferences` entram **sem pin de versão**. O build não é reproduzível no
tempo — daqui a um mês o mesmo commit pode resolver versões diferentes. Não é
bloqueador de publicação, mas é risco de release.

---

## 5. Classificação indicativa (IARC)

O questionário não pode ser respondido com honestidade até fechar dois pontos:

| Pergunta do IARC | Resposta baseada em evidência |
|---|---|
| Violência / sexo / drogas / linguagem | **Não** — jogo de cartas. |
| **Os usuários interagem entre si?** | **SIM** — multiplayer por WebSocket ([online_service.dart](app/lib/services/online_service.dart)). Isso por si só já obriga declaração de interação social. |
| **Há chat / troca de mensagens?** | **NÃO, hoje.** Existem *ajustes* de chat (`ChatMesa { completo, soBaloes, desligado }` — [configurar_mesa_screen.dart:9](app/lib/screens/configurar_mesa_screen.dart:9); "Chat público só para maiores" — [configuracoes_screen.dart:301](app/lib/screens/configuracoes_screen.dart:301)), mas **nenhuma implementação de chat** existe no código. São interruptores que não ligam em nada. |
| **Compartilha localização?** | **Não** (§2.2). |
| **Há compras digitais?** | **Ver §7.1** — a resposta honesta hoje é *não*, mas a tela diz que sim. |
| Elementos de **jogo de azar / simulação de aposta** | **A CONFIRMAR** — há economia de fichas/moedas e Loja. Isso costuma cair em "simulated gambling", que altera a faixa etária. Precisa de leitura da política com o produto na mão. |

**Status: PENDENTE**, dependente de §7.1 e da decisão sobre chat.

---

## 6. Auditoria de assets

### 6.1 Assets de loja (obrigatórios pela Play) — **nenhum existe**

Busca no repositório inteiro por `*icon*`, `*feature*`, `*store*`, `*512*`,
`*1024*` → único resultado: `keystore/debug.keystore.b64` (falso positivo).

| Asset | Requisito Play | Situação |
|---|---|---|
| **Ícone da loja** | 512×512 PNG 32-bit, sem transparência | **NÃO EXISTE** |
| **Feature graphic** | 1024×500 PNG/JPG, sem transparência | **NÃO EXISTE** |
| **Screenshots de telefone** | mín. 2, máx. 8; lado menor ≥ 320px, maior ≤ 3840px | **NÃO EXISTEM** |
| Screenshots de tablet 7"/10" | só se distribuir para tablet | **NÃO EXISTEM** — decisão pendente |
| Vídeo promocional (YouTube) | opcional | Não existe |

**Candidato a ícone:** `app/assets/splash/logo_splash_oficial.webp` (1,3 MB). É
`.webp`, e a Play exige **PNG 32-bit**. Precisa de conversão e recorte quadrado —
e o arquivo é de splash, proporção não garantida para ícone. **A CONFIRMAR** se a
arte-fonte em alta resolução existe fora do repo.

### 6.2 Assets do app — auditados

| Pasta | Arquivos | Empacotado no APK? | Evidência |
|---|---|---|---|
| `baralho/` | 56 | ✅ (trava exige ≥55) | [build.yml:62-69](.github/workflows/build.yml:62) |
| `perfil/` | 23 | ✅ (trava exige ≥23) | build.yml:72-78 |
| `ranking/` (+`selos/`) | 25 | ✅ | build.yml:80-90 |
| `inicio/` | 11 | ✅ (trava exige ≥11) | build.yml:99-106 |
| `configurar_mesa/` | 8 | ✅ (trava exige ≥8) | build.yml:107-114 |
| `sons/` | 8 | ✅ | build.yml:55-60 |
| `hall/` | 1 | ✅ | build.yml:92-96 |
| `torneios/` (capas + premiação) | 20 | ✅ | build.yml:122-143 |
| `splash/` | 2 | ✅ | build.yml:323-331 |
| `mesa_vip/` | 2 | ❌ **NÃO** | `grep mesa_vip` no workflow ativo → **zero ocorrências**. Não é copiado nem declarado. Coerente com o fato de `mesa_vip_preview_screen.dart` ser código morto (§6.4). |
| `loja/` | 0 (pasta não existe) | ❌ **NÃO** | Duplo defeito: build.yml:115-119 copia com `2>/dev/null \|\| true` (falha em silêncio, e a pasta nem existe) **e** `assets/loja/` **não está no bloco de declaração do pubspec** (build.yml:364-378). Se a arte da Loja chegar amanhã, ela **não será empacotada** — e o build não vai avisar. |

O ponto forte aqui: o pipeline tem **travas de contagem** que abortam o build se
faltar arte. Isso é bom e deve ser mantido.

### 6.3 Divergência de workflows — **corrigir**

Existem **dois** `build.yml`:

- `build.yml` (raiz do repo) — **cópia obsoleta**, 6 dependências a menos
  (`web_socket_channel` e `shared_preferences` faltando). Se alguém rodar por ela,
  o build quebra, porque o código importa os dois.
- `.github/workflows/build.yml` — **o que realmente roda**.

O da raiz deve ser removido. Ele não é executado pelo GitHub Actions, mas induz erro
de leitura — inclusive nesta auditoria, na primeira passada.

### 6.4 Código morto (limpeza, não bloqueador)

Verificado por análise de alcançabilidade de imports:

- `app/lib/screens/mesa_vip_preview_screen.dart` — **0 referências**.
- `app/lib/torneios/reward_grants.dart` — **0 referências**.
- `app/lib/app/lib/` — pasta duplicada aninhada (`screens/amigos_screen.dart`,
  `widgets/convite_vip.dart`). O `cp -R app/lib/. app_build/lib/` a copia para dentro
  do build.
- `.github/workflows/` contém **arquivos `.dart`** (`main.dart`,
  `screens/como_jogar_screen.dart`, `loja_screen.dart`,
  `configuracoes_screen.dart`) — fonte fora de lugar, dentro do diretório de
  workflows.

Isso confirma e atualiza o que [app/lib/VARREDURA-BOTOES.md](app/lib/VARREDURA-BOTOES.md)
já registrava.

---

## 7. Roteiro de screenshots finais

### 7.1 Bloqueio que precede o roteiro — leia antes de fotografar

Duas evidências que tornam parte do roteiro arriscada:

**(a) A Loja exibe preços reais para compras que não existem.**
`R$ 19,90`, `R$ 49,90`, `R$ 149,90`, `R$ 4,90`… em
[loja_screen.dart:37-100](app/lib/screens/loja_screen.dart:37). Não há
`in_app_purchase` no build (§4). O botão "Assinar" apenas liga um booleano local:
`setState(() => _ehVip = true)` — [main.dart:830](app/lib/main.dart:830) e
[main.dart:595](app/lib/main.dart:595). Um screenshot da Loja com preços é uma
oferta de compra que o app não cumpre.

**(b) Os números do Perfil são de demonstração.**
`static const bool statsDemo = true` — [perfil_service.dart:20](app/lib/services/perfil_service.dart:20).
O próprio comentário do arquivo diz: *"números de exemplo aprovados
(marketing/screenshots)"* ([perfil_service.dart:18](app/lib/services/perfil_service.dart:18)).
Além disso há **30 chamadas `.mock(`** espalhadas pelas telas. Ranking, Saguão,
Amigos, Hall e Recompensas são prévias com dados fabricados.

A política de *Misrepresentation* da Play exige que screenshots reflitam a
experiência real. Fotografar Ranking/Perfil/Loja hoje documenta dados inventados.

> **Recomendação:** o roteiro abaixo está pronto para execução, mas **a captura só
> deve acontecer depois** que a OS de dados reais rodar, ou com `statsDemo = false`
> e a Loja fora do conjunto. Entrego o roteiro completo porque foi pedido; sinalizo
> o risco porque é real.

### 7.2 Roteiro — 8 telas, na ordem de prioridade da OS

Todas as rotas foram confirmadas no código. Máximo da Play = 8, então este conjunto
já ocupa o limite; Torneios ficou de fora (§7.3).

| # | Tela | Rota verificada | O que enquadrar | Observação |
|---|---|---|---|---|
| 1 | **Início** | `SplashOficialScreen → _InicioPreviewHost` — [main.dart:79-81](app/lib/main.dart:79) | Identidade visual dourada, jogador logado, acessos principais | Primeira imagem da ficha. É a que converte. |
| 2 | **Mesa** | `_abrirMesa()` — [main.dart:273](app/lib/main.dart:273); motor em `app/lib/mesa.dart` | Mão aberta, jogos baixados, monte/lixo, placar | **A tela mais importante.** É a única com lógica real. |
| 3 | **Ranking** | `_abrirRanking()` — [main.dart:267](app/lib/main.dart:267) | Pódio + lista com selos | ⚠️ dados mock |
| 4 | **Perfil** | `_abrirPerfil()` → `PerfilPage` — [main.dart:261](app/lib/main.dart:261) | Avatar real do Google, conquistas, vitrine | ⚠️ `statsDemo = true` |
| 5 | **Social — Saguão** | `SaguaoScreen` — [main.dart:445](app/lib/main.dart:445) | Salas, jogadores online, mesas abertas | ⚠️ mock |
| 6 | **Social — Amigos** | `AmigosScreen` — [main.dart:574](app/lib/main.dart:574) | Lista de amigos, convites | ⚠️ mock. Alternativa a #5 se preferir 1 só de Social. |
| 7 | **Loja / VIP** | Loja VIP host — [main.dart:771-830](app/lib/main.dart:771) | Planos VIP e benefícios | 🚫 **ver §7.1(a)** — capturar **sem** os preços, ou não capturar |
| 8 | **Hall dos Imortais** | `HallScreen` — [main.dart:967](app/lib/main.dart:967) | Painel de glória (`assets/hall/painel_gloria.webp`) | ⚠️ mock. Diferencial visual forte. |

### 7.3 Fora do conjunto, com justificativa

- **Torneios** (`TorneiosPreviewPage` — [main.dart:373](app/lib/main.dart:373)):
  a memória do projeto registra que os cinco torneios **não abrem inscrição** até a
  definição de lotação, fases, meta, janelas e premiação. Fotografar torneio hoje
  promete o que não abre. Fica fora da V1.
- **Mesa VIP** (`mesa_vip_preview_screen.dart`): **código morto**, 0 referências
  (§6.4). Não é alcançável pelo usuário — não pode ser fotografada.

### 7.4 Especificação técnica da captura

| Parâmetro | Valor |
|---|---|
| Aparelho | Telefone Android real, arm64 (o APK do CI é `app-arm64-v8a-release.apk`) |
| Build | **release**, nunca debug (o banner já está desligado — `debugShowCheckedModeBanner: false`, [main.dart:76](app/lib/main.dart:76)) |
| Orientação | Retrato |
| Resolução | 1080×1920 ou 1080×2400 (dentro do exigido: lado menor ≥320, maior ≤3840) |
| Formato | PNG 24-bit ou JPEG, **sem transparência** |
| Proporção | Máx. 2:1 |
| Barra de status | Limpa: sem notificações, bateria cheia, hora redonda |
| Conta usada | Conta Google real de vitrine, com nome e foto apresentáveis (o app mostra `displayName`, `email` e `photoURL` — §2.1) |
| ⚠️ E-mail à vista | [main.dart:1763](app/lib/main.dart:1763) exibe o e-mail na tela. **Não fotografar o e-mail pessoal da Sônia** — usar conta de vitrine. |

---

## 8. Entrega final

### ✅ PRONTO — decidido, com evidência, pode ir ao Console hoje

| Item | Declaração |
|---|---|
| **Anúncios** | "Não contém anúncios" — sem SDK de anúncio (§1, §4) |
| **Lista de SDKs terceiros** | 6 diretos + `jni` travado — lista fechada e verificada (§4) |
| **Dados NÃO coletados** | Localização, contatos, fotos, câmera, microfone, analytics, crash logs, dados financeiros (§2.2) |
| **Dados coletados (lado app)** | E-mail, nome, foto, UID, apelido — cada um com linha de código (§2.1) |
| **Criptografia em trânsito** | Sim — `wss://` + HTTPS (§2.4) |
| **Auditoria de assets do app** | Completa, com travas de contagem no CI (§6.2) |
| **Roteiro de screenshots** | 8 telas, rotas confirmadas, spec técnica fechada (§7) |
| **Idioma** | pt-BR único (`enum Idioma { ptBR }`) |

### ⏳ PENDENTE — depende de decisão da Sônia ou de trabalho nesta OS

| Item | O que falta | Bloqueia publicação? |
|---|---|---|
| Nome na loja | Decidir entre `Buraco Master VIP` e o atual `BMV Teste` | **Sim** |
| Descrição curta / completa | Redigir — **bloqueado por §7.1** | **Sim** |
| Categoria e tags | Decidir (sugestão: Jogos › Cartas) | **Sim** |
| E-mail de suporte | Definir endereço | **Sim** |
| **Política de privacidade** | Redigir + hospedar. Nada existe. | **Sim** |
| **URL de exclusão de conta** | Não existe fluxo nem página | **Sim** |
| **Ícone 512×512 PNG** | Não existe; fonte candidata é `.webp` de splash | **Sim** |
| **Feature graphic 1024×500** | Não existe | **Sim** |
| **Screenshots** | Não existem; roteiro pronto, captura bloqueada por §7.1 | **Sim** |
| Países / distribuição | Decisão comercial | **Sim** |
| Classificação indicativa | Questionário — depende de chat e compras (§5) | **Sim** |
| Compras no app | Resolver §7.1(a): remover preços **ou** implementar billing | **Sim** |
| Retenção de dados | Definir política (não existe) | **Sim** |
| Permissões finais | Rodar `aapt2 dump permissions` no APK do CI (§3) | Não, mas trava o Data Safety |
| Limpeza: `build.yml` da raiz | Remover cópia obsoleta (§6.3) | Não |
| Limpeza: código morto | `mesa_vip_preview_screen.dart`, `reward_grants.dart`, `app/lib/app/`, `.dart` em `.github/workflows/` (§6.4) | Não |
| Declarar `assets/loja/` no pubspec | Passo de cópia existe, declaração não — arte da Loja não seria empacotada (§6.2) | Não |
| Pin de versões | 5 dependências sem pin (§4) | Não |

### 🔗 DEPENDE DE OUTRA OS — fora do alcance deste repositório/OS

| Item | Onde vive | Por quê |
|---|---|---|
| **Migrar APK → AAB** | OS de build | §0.1 — bloqueador duro |
| **`applicationId` de produção** | OS de build | §0.2 — `.poc.` é permanente após publicar |
| **Keystore de produção** | OS de build/segurança | §0.3 — senhas em texto claro no repo |
| **Ícone do launcher no app** | OS de build | §0.4 — hoje é o ícone padrão do Flutter |
| **Fluxo de exclusão de conta** | branch `claude/player-account-deletion-flow-d04d45` (**não mesclada**) | Alimenta a URL obrigatória da §1 |
| **Google Play Billing** | branch `integracao/play-billing-flutter` / `claude/google-play-billing-flutter-4a45e9` (**não mescladas**) | Resolve §7.1(a) |
| **Retenção/repouso no servidor** | repo `buraco-servidor` (**não está aqui**) | Fecha os A CONFIRMAR da §2.4 |
| **Dados reais (fim do mock)** | OS de Firestore/persistência | Desbloqueia a captura de screenshots (§7.1b) |
| **Torneios: abertura de inscrição** | OS de torneios | Mantém Torneios fora da V1 (§7.3) |
| **Fórmula de ranking** | OS de ranking | Ranking não pontua sem ela |

---

## 9. Caminho crítico sugerido

Ordem que destrava mais coisa por passo:

1. **Decidir o `applicationId` de produção** — é irreversível e trava tudo abaixo.
2. **Migrar o pipeline para AAB + keystore de produção + ícone real.**
3. **Resolver a Loja** (remover preços da V1 é o caminho mais curto).
4. **Publicar política de privacidade e página de exclusão de conta.**
5. **Desligar `statsDemo` / ligar dados reais**, então **capturar os screenshots**.
6. **Preencher Data Safety** (já mapeado aqui) e o **IARC**.
7. **Redigir as descrições** — por último, descrevendo só o que ficou de pé.

---

*Auditoria sem deploy e sem alteração de produção, conforme a OS. Nenhum arquivo de*
*código foi modificado; este documento é a única adição.*
