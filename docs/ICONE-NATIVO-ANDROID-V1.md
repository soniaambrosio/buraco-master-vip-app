# Canonização do ícone nativo Android e da starting window — V1

Elimina o ícone padrão do Flutter que aparecia antes da Splash Rive, em todo cold
start do Android 12+.

Base: `claude/integracao-splash-rive-constelacao-v1` @ `2ffe4ff` — o commit
homologado da abertura, onde este defeito foi registrado como residual nº 2.
Nada da abertura foi tocado: o `.riv`, o `.svg` e a duração continuam byte a byte
e milissegundo a milissegundo os mesmos.

---

## 1. O defeito, e por que ele não era um descuido de arte

O projeto host Android **não é versionado**. Os três workflows montam `android/`
na hora com `flutter create` e remendam o scaffold. Então o ícone do aplicativo
nunca foi uma decisão deste repositório: era o que o template do Flutter deixava.

O que o template do Flutter 3.44.8 entrega em `app/src/main/res` — conferido
lendo a própria tag, e reconfirmado rodando `flutter create` com o 3.41.4 local,
que produz **os mesmos cinco arquivos com os mesmos SHA-256**:

| recurso | existe? |
|---|---|
| `mipmap-{m,h,xh,xxh,xxxh}dpi/ic_launcher.png` | sim — logotipo do Flutter |
| `mipmap-anydpi-v26/ic_launcher.xml` (ícone adaptativo) | **não** |
| camada `foreground` / `background` | **não** |
| camada `monochrome` (ícone temático, Android 13+) | **não** |
| `values-v31/styles.xml` (SplashScreen API) | **não** |
| `android:roundIcon` no manifesto | **não** |

Os cinco bitmaps padrão, por SHA-256 — a lista que virou trava no `build.yml`:

```
c7c0c0189145e4e32a401c61c9bdc615754b0264e7afae24e834bb81049eaf81  mdpi     48x48
6a7c8f0d703e3682108f9662f813302236240d3f8f638bb391e32bfb96055fef  hdpi     72x72
e14aa40904929bf313fded22cf7e7ffcbf1d1aac4263b5ef1be8bfce650397aa  xhdpi    96x96
4d470bf22d5c17d84edc5f82516d1ba8a1c09559cd761cefb792f86d9f52b540  xxhdpi  144x144
3c34e1f298d0c9ea3455d46db6b7759c8211a49e9ec6e44b635fc5c87dfb4180  xxxhdpi 192x192
```

**Onde isso vazava para o jogador.** A partir da API 31 o Android não desenha mais
a janela de partida a partir de `windowBackground`: quem manda é a SplashScreen
API. Sem `values-v31`, o sistema **infere** a janela — pega a cor do
`launch_background` (que a entrega anterior já tinha acertado em `#050B1E`) e
carimba no centro **o ícone do aplicativo**. Fundo certo, marca errada, em todo
cold start, antes da abertura do jogo.

Não havia como corrigir isso só trocando um PNG: a inferência do sistema depende
do ícone ser adaptativo ou não, e **muda entre a API 31 e a 36**. Duas versões do
Android desenhariam coisas diferentes a partir dos mesmos recursos.

---

## 2. A arte: de onde ela veio, e por que não foi encomendada

O ícone oficial **já existia e já está aprovado** — é o que a Play mostra hoje
para o aplicativo publicado. Ele não estava no git, o que quase levou à conclusão
errada de que precisava ser criado.

Trilha da procedência, do que está publicado até o arquivo commitado:

1. `Downloads/Buraco VIP - Google Play package2.zip` → `Buraco VIP.apk`, o pacote
   publicado. `aapt2 dump resources` mostra `mipmap/ic_launcher` nas cinco
   densidades **mais** `anydpi-v26`, e um `mipmap/ic_maskable`.
2. O `raw/web_app_manifest` desse APK declara `name: "Buraco Master VIP"` — é o
   mesmo aplicativo, não um homônimo — e aponta as fontes:
   `icon-192.png`, `icon-512.png`, `icon-maskable-512.png`.
3. `https://soniaambrosio.github.io/buraco-master-vip/icon-512.png` — 512×512,
   332.948 bytes, `sha256 de466e5a953d30dede7bba55ea64740f6066757830c6548d4a724fa54fd6b59f`.
   (`icon-maskable-512.png` é **byte a byte o mesmo arquivo**: o manifesto da PWA
   declara como "maskable" uma arte que não é. Só a `any` foi usada aqui.)

Esse arquivo virou `branding/fonte/icone_oficial_bmv_512.png`. É a **única** fonte:
todo o resto é derivado dele por `tools/branding/gerar_icones_android.mjs`.

### Geometria medida na arte, não estimada

| medida | valor |
|---|---|
| fundo fora da moldura | `#0C0804` |
| início da moldura dourada | 23 px das bordas |
| arco do canto | centro `(113,113)`, raio 90 px |
| assunto (coroa + cartas) | x 99..410, y 52..461 |

### Por que a arte entra a 78 dp num canvas de 108 dp

O ícone adaptativo tem canvas de 108 dp, janela de máscara de 72 dp e safe zone de
66 dp. As duas pontas se fecham num intervalo estreito:

- **≥ 72 dp**, senão a camada de fundo aparece na quina de alguma máscara;
- **≤ 82,8 dp**, senão o assunto sai da safe zone (com margem de 52 px na arte,
  `512·(1 − 66/S)/2 ≤ 52` exige `S ≤ 82,8`).

78 dp fica no meio: a janela mostra 92,3% da arte, a safe zone exige 39,4 px de
margem e a menor margem do assunto é 51 px. O gerador **reprova** se uma arte
futura violar qualquer uma das duas pontas, em vez de produzir um recurso torto.

---

## 3. O que foi entregue

```
branding/
  fonte/icone_oficial_bmv_512.png        arte oficial, fonte única
  MANIFESTO.sha256                       24 arquivos, conferido antes de copiar
  android/res/
    mipmap-{5 densidades}/ic_launcher.png            ícone herdado (API < 26)
    mipmap-{5 densidades}/ic_launcher_foreground.png camada de frente
    mipmap-anydpi-v26/ic_launcher.xml                ícone adaptativo
    drawable-{5 densidades}/ic_launcher_monochrome.png  ícone temático (Android 13+)
    drawable-{5 densidades}/splash_icon.png          ícone da starting window
    values-v31/styles.xml                            SplashScreen API, tema claro
    values-night-v31/styles.xml                      SplashScreen API, tema escuro
tools/branding/
  png.mjs                    codec PNG mínimo (esta máquina não tem ImageMagick)
  gerar_icones_android.mjs   gerador determinístico
```

### As três decisões que valem registro

**1. Os recursos são commitados, não gerados no CI.** Gerar no runner exigiria um
decodificador de imagem e faria o resultado depender da versão da ferramenta. Com
o arquivo commitado, `sha256sum -c` no `build.yml` dá prova byte a byte — e é
exatamente o modo de falha silencioso que já mordeu este projeto (asset novo que
não era copiado e nunca chegava ao APK, sem erro de compilação).

**2. O fundo do ícone adaptativo é `@color/splash_background`, a MESMA cor da
janela de partida.** Não é coincidência estética: é o valor que o Android 12+
compara com o fundo da starting window para decidir se pode descartar a camada de
fundo do ícone. Duas cores diferentes aqui reintroduziriam a emenda visual.

**3. `windowSplashScreenAnimatedIcon` é declarado explicitamente.** Sem ele, o
sistema desenha uma composição *inferida* do ícone adaptativo — e a heurística
dessa inferência não é a mesma na API 31 e na 36. Declarando o drawable, as duas
versões desenham o mesmo, e o contorno do emblema é nosso, não do sistema.

A camada monocromática sai só do assunto, sem a moldura: reduzida a uma cor, a
moldura vira quatro arcos soltos, e a diretriz do ícone temático é silhueta
legível.

### O que foi auditado e deliberadamente NÃO feito

`android:roundIcon` não foi adicionado. Ele só é lido na API 25, e o piso real do
aplicativo é 24 (o passo `minSdk 23` do workflow é letra morta — o
`MinSdkVersionMigration` do Flutter o reverte). Na API 26+ o ícone adaptativo já
responde por qualquer forma de máscara, e na 24–25 o bitmap herdado responde.
Acrescentar o atributo exigiria cirurgia no manifesto para cobrir uma única versão
de Android.

---

## 4. Os portões no `build.yml`

**Antes de copiar** (`MARCA NATIVA — ícone oficial e starting window do Android 12+`):

- `sha256sum -c branding/MANIFESTO.sha256` — 24 arquivos;
- `@color/splash_background` tem de existir (o passo anterior é quem escreve);
- o `ic_launcher` do scaffold tem de **mudar** de hash: prova de substituição,
  não de cópia;
- nenhum dos cinco SHA-256 do Flutter pode sobreviver, e cada `ic_launcher.png`
  tem de passar de 3 kB — ordem de grandeza que separa ilustração de logotipo
  chapado mesmo que a lista de SHA envelheça com o pin do Flutter.

**Depois de construir** (`PORTÃO DA MARCA — nenhum branding do Flutter dentro do APK`),
lendo a tabela de recursos do APK assinado com `aapt2`:

- `mipmap/ic_launcher` tem variante `anydpi-v26` (virou adaptativo);
- `ic_launcher_foreground`, `ic_launcher_monochrome` e `splash_icon` existem nas
  cinco densidades;
- `style/LaunchTheme` tem variante `v31`;
- `color/splash_background` é `#ff050b1e`;
- a camada de frente empacotada passa de 20 kB.

Os **bytes** dos PNG dentro do APK não servem de prova: o AGP recomprime PNG no
release, então o SHA muda com pixel idêntico. Por isso a trava de bytes fica sobre
o arquivo commitado, e a trava dentro do artefato é estrutural.

`branding/** -text` no `.gitattributes` pela mesma razão do `.svg` da constelação:
com `core.autocrlf=true`, o checkout reescreveria as quebras dos `.xml` e o
manifesto reprovaria um repositório íntegro.

---

## 5. A prova em runtime

APK de release construído na bancada local (`flutter build apk --release
--split-per-abi`, x86_64, versionCode 4001, minSdk 24, targetSdk 36) e instalado
em dois emuladores:

| | API 36 (Android 16) | API 31 (Android 12) |
|---|---|---|
| AVD | `Medium_Phone_API_36.1` | `BMV_API_31` (Pixel 5, google_apis) |
| tela | 1080×2400 @ 420 dpi | 1080×2340 @ 440 dpi |

**808 quadros varridos**, em 17 rodadas de cold start com o processo morto antes
de cada uma (`am force-stop`), animações do sistema esticadas 10× para que a
passagem nativo→Flutter não caísse entre duas amostras.

### O veredito

**Nenhum quadro do aplicativo tem um único pixel do logotipo do Flutter.** O
detector procura as três cores lidas do próprio `ic_launcher` do template —
`#54C5F8`, `#01579B`, `#29B6F6`, com tolerância de 12 por canal.

Os únicos quadros da varredura com esse azul são os da **gaveta do lançador**, e
lá ele vem dos ícones do Chrome e do Messages: na tela cheia da gaveta da API 31
são 31 pixels, e **dentro da caixa do ícone do BMV são 0**. Na gaveta da API 36 o
azul não aparece em lugar nenhum da tela.

### A sequência, quadro a quadro

Cold start na API 36, resolução nativa (`api36_r1`):

| quadro | o que está na tela | % de `#050B1E` |
|---|---|---|
| 000 | lançador | 0,0 |
| 001 | **janela de partida: medalhão do BMV sobre `#050B1E`** | 92,0 |
| 002 | fusão — medalhão saindo, constelação entrando | 94,0 |
| 003 | **Splash Master VIP** (Rive + constelação) | 76,4 |
| 004+ | Login | 0,0 |

O fundo nunca muda de cor entre a janela de partida e a abertura: é isso que
significa "sem ruptura visual", e o quadro 002 mostra as duas camadas
sobrepostas no mesmo `#050B1E`.

O medalhão medido no quadro 001: 504×504 px numa tela de 1080 a 420 dpi = 192 dp,
recortado em círculo pelo sistema.

### O que foi provado, e por qual caminho

- **API 36**, lançado por `am start` e também **por toque no ícone da gaveta**:
  medalhão do BMV na janela de partida nos dois caminhos.
- **API 36 em modo escuro** (`cmd uimode night yes`): mesma janela de partida —
  `values-night-v31` responde.
- **API 31**, lançado **por toque no ícone da gaveta**: medalhão do BMV na janela
  de partida (`api31_toque/08.png`).
- **Ícone do lançador**: a gaveta das duas versões mostra "BMV Teste" com o ícone
  adaptativo do BMV, mascarado em círculo — nenhum resquício do Flutter.
- **Camada monocromática**: `aapt2 dump xmltree` sobre o `ic_launcher.xml`
  compilado dentro do APK mostra as três camadas — `background`, `foreground` e
  `monochrome`. A aparência do ícone temático não foi exercitada no aparelho
  porque o lançador do emulador não expõe o interruptor de ícones temáticos; o
  que está provado é que o recurso existe, é referenciado e foi empacotado.

### A diferença entre a API 31 e a 36 que vale registrar

Na **API 31, `adb shell am start` NÃO desenha o ícone** — a janela de partida sai
só com o fundo `#050B1E`. Medido em cinco rodadas: os quadros nativos dão 94% a
99% de `#050B1E` e o realce da diferença mostra tela limpa, sem ícone.

Isso não é defeito da configuração: no Android 12 o estilo da janela de partida
vem de quem lança. O lançador pede `SPLASH_SCREEN_STYLE_ICON`; um lançamento por
shell fica com o estilo vazio, e `am start` da API 31 nem aceita a opção
(`Unknown option: --splashscreen-show-icon`). Lançado pelo toque no ícone — o
caminho do jogador — o medalhão aparece. Na API 36 os dois caminhos desenham o
ícone.

Consequência para quem for reproduzir isto: **medir a janela de partida da API 31
com `am start` dá falso negativo**. Tem de ser pelo lançador.

Em nenhum dos dois caminhos, em nenhuma das duas versões, apareceu marca do
Flutter.

---

## 6. O residual que esta entrega NÃO resolve

Os dois portões novos vivem no `build.yml`, e **o `build.yml` não constrói APK
nesta base** — é o residual nº 1 do laudo da abertura, intocado aqui porque é de
outra frente. O passo "Add Firebase + Google Sign-In + Audio deps" monta as
dependências com uma lista digitada em `flutter pub add` que não tem
`cloud_firestore`, `cloud_functions` nem `firebase_app_check`; o analyze reprova
antes de chegar perto do ícone.

Enquanto isso não for corrigido, os portões da marca existem mas nunca rodam no
CI. A bancada local foi montada do jeito que o `ci-os-integracao.yml` já faz —
`cp app/pubspec.yaml app/pubspec.lock` — e é assim que o APK desta prova saiu.
Os dois passos foram executados à mão contra esse APK e passaram; o que falta é o
CI conseguir chegar até eles.
