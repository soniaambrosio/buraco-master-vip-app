# OS 36-R1 — Rehomologação dos alvos tocáveis da Home, Onde Jogar e Perfil

**Veredito final: FAIL.** Auditoria só-leitura de 2026-08-25. Nada foi editado na candidata;
nenhum PR, merge, push ou deploy. Laudo visual:
`https://claude.ai/code/artifact/ef501cc4-e0d6-4595-8f9f-723ecea37be1`

| Item | Referência |
|---|---|
| Candidata | `correcao/os36-c1-avatar-hitbox-48dp-v1` |
| SHA | `9ce23d572d66b2d7c16e7a98434ad1e83217988c` |
| Gate anterior | `b52ad6849478a83f25dd57cf8d93d5f98d691d71` |
| Base | `bf5a9e7ed0a51ae2c55f249d87c930bb88e76a0c` |

---

## Gate Zero — passou nos dez itens

- Duas consultas remotas independentes (`ls-remote`), SHAs idênticos nas duas.
- `b52ad68` é **pai direto** de `9ce23d5`; `bf5a9e7` é ancestral (6 commits).
- `remote.origin.fetch` completo: 228 heads remotos = 228 refs locais.
- Árvore limpa antes e depois; suíte e `lib/` conferidos por `hash-object` no fim.
- Bancada por `git archive`: **510 de 510 arquivos byte a byte** contra os blobs.
- Diff sobre o gate anterior: **2 arquivos, +306/−23** (`perfil_screen.dart` e a suíte).

## As quatro provas obrigatórias

| Comando | Placar | Exit |
|---|---|---|
| `flutter test test/casca/a11y_alvos_da_casca_test.dart` | 50 / 50 | 0 |
| `flutter test test/casca` | 297 / 297 | 0 |
| `flutter test` | 1381 / 1381 | 0 |
| `dart analyze lib test` | 106 issues · 13 warning · 93 info · **0 erro** | 2 |

As 38 declarações da OS rendem 50 casos executados: a matriz comum roda 6 casos em 3 telas.
O exit 2 do `dart analyze` é o padrão dele com infos; o CI usa `--no-fatal-infos
--no-fatal-warnings`.

## O instrumento, e a calibração

Medir o retângulo de um `SemanticsNode` não é medir alvo tocável. A sonda varre o retângulo
**anunciado** de 1 em 1 ponto e pergunta se o ponto chega ao `RenderObject` do controle.

| Ponto de calibração | Por dedo (`tapAt` + callback) | Por hit-test |
|---|---|---|
| Trocar avatar · 360 dp · 100% | 2304 / 2304 · 48,0 × 48,0 | 2304 / 2304 · 48,0 × 48,0 |
| Configurações · 320 dp · 200% | 1920 / 2304 · 40,0 × 48,0 | 1920 / 2304 · 40,0 × 48,0 |

A mesma sonda, rodada no gate anterior `b52ad68`, devolve **1890 / 2304 · 42,0 × 45,0** para o
"Trocar avatar" — o achado da OS 36, reproduzido. É isso que autoriza acreditar nos 48 da
candidata.

## Avatar — o item que a C1 veio fechar: PASS

- Área efetiva **48,00 × 48,00**, sólida, **0 buracos** em 2304 pontos.
- Quatro cantos e centro respondem, um toque cada, **0 vizinhos** acionados.
- Cabe dentro de **todos** os `RenderBox` ancestrais.
- Nas 36 células da matriz (e nas variantes nome curto/extenso × avatar simples/moldura
  equipada × próprio/visitado), os cantos respondem em todas.

O desenho não se mexeu, medido de dois jeitos:

| Medida | Base `b52ad68` | Candidata `9ce23d5` |
|---|---|---|
| Disco dourado | 34,00 × 34,00 @ 208,70 | idêntico |
| Ícone de câmera | 18,00 × 18,00 @ 216,78 | idêntico |
| Avatar de 96 | 96,00 × 96,00 @ 132,81 | idêntico |
| `Stack` pai | 126,00 × 126,00 @ 117,66 | idêntico |
| PNG do Perfil inteiro | 147 880 B · `225cb636…` | **mesmo SHA-256** |

Nenhum pixel mudou.

## A matriz — 36 células, todo alvo varrido ponto a ponto

Nas 36 células: **0 alvos anônimos, 0 sem papel de botão, 0 com papel de botão sem ação de
toque, 0 sobreposições entre vizinhos, 0 centros mortos.** Duas células reprovam pelo piso
efetivo — Perfil próprio e Perfil visitado, ambas em **320 dp / texto 200%**.

### O achado

A barra superior do Perfil é um `Row` de 296 pontos com `[Voltar 48] + ["Perfil" a 34 px] +
[Configurações 48]`. Em 320 dp / 200% não cabe. O `Row` transborda, e um `RenderBox`
**recusa hit-test fora do próprio `size`** — os 8 pontos que passam de x=308 são desenhados,
anunciados como parte de um alvo de 48, e inertes.

**"Configurações" recebe 40 × 48.** Nas duas superfícies de produção. É o mesmo mecanismo que
a OS 36 encontrou no avatar.

**Herdado, não regressão.** O `_botaoTopo` é idêntico entre `b52ad68` e `9ce23d5` — o commit da
candidata só tocou o bloco do avatar —, e a mesma sonda no gate anterior devolve o mesmo
1920/2304. Também não havia como o portão pegar: a suíte roda numa superfície **fixa** de
360 × 2000 lógicos (1080 × 6000 físicos, dpr 3) e nunca varia largura nem escala de texto.

### Os dois recortes que NÃO são defeito

- **Os 4 cartões de Onde jogar** anunciam 12 pontos de altura a mais do que recebem, em todas
  as células: é a `margin: only(bottom: 12)` do cartão — o vão *entre* cartões. Área efetiva
  em centenas de pontos.
- **O CTA "Jogar" da Home** anuncia a largura da linha e entrega os 300 da arte (300 × 75
  efetivos), constante em toda escala.

### Ressalvas visuais, sem perda de toque

- Em 320 dp / 200%, a `Column` do ladrilho da grade da Home estoura **25 px por baixo**
  (`inicio_screen.dart:845`). Os 15 alvos seguem inteiros; o que sai da caixa é o rótulo.
  Efeito colateral medido: `tester.tap(find.text('Jogar'))` deixa de acertar o alvo.
- A `PerfilVM.mock` estoura à direita a partir de 150% (114, 74, 206, 22 e 154 px conforme a
  célula). Essas seções **não são desenhadas pela casca de produção**, que não tem autoridade
  que as informe.

## Campanha negativa — 12 mutações, em cópias descartáveis

| # | Mutação | Resultado | Casos reprovados |
|---|---|---|---|
| — | Controle · árvore intacta | verde 50/50 | 0 |
| M1a | Um alvo cai para 47 dp (barra inferior) | **VERMELHO** | 2 |
| M1b | O piso global `kAlvoMinimoDeToque` cai para 47 | **VERMELHO** | 3 |
| M2 | O botão Voltar de Onde jogar perde o nome | **VERMELHO** | 4 |
| M3 | A Home perde a ação semântica de toque | **VERMELHO** | 5 |
| M4 | Opção bloqueada anunciada como habilitada | **VERMELHO** | 2 |
| M5 | O hitbox do avatar volta a ser recortado pelo pai | **VERMELHO** | 3 |
| M6 | O alvo do avatar cresce para 96 × 96 | equivalente | 0 |
| M6b | O alvo do avatar cresce para 200 × 200 | **VERMELHO** | 2 |
| M6c | Item da barra inferior alargado para 140 | inerte | 0 |
| M7 | A navegação inferior perde o estado selecionado | **ESCAPOU** | 0 |
| M8 | A suíte direcionada é apagada | ver abaixo | — |

**M6 sobreviveu, mas não escapou.** Dentro do `Stack` de 126 × 126 não existe vizinho tocável:
o mascote e o selo de nível são decoração sem `onTap`, e o alvo tocável mais próximo
("Editar apelido", em 193,5 / 196) está a 130 pontos. Um alvo grande o bastante para alcançá-lo
necessariamente transborda o pai — foi o que M6b provou, com 2 casos vermelhos. A propriedade
está guardada pela contenção, não pela sobreposição.
**M6c é inerte por outra razão:** medido, o item da barra continua **90 × 48** com
`largura: 140` aplicado. `Expanded` impõe largura apertada e o `ConstrainedBox` do `AlvoMinimo`
é clampado por ela — o helper só ergue o piso no eixo livre.

**M7 é escape real.** A suíte lê `d.flagsCollection.isSelected` para dentro do campo
`selecionado` do próprio modelo e **nunca afirma nada sobre ele**; as únicas asserções de
`Tristate` são sobre `habilitado`. O produto está certo (`selecionados: 1` em todas as
células) — o que falta é o portão. E é o atributo que sustenta "não depender apenas de cor ou
ícone".

**M8 — dívida herdada, medida nos dois portões.** Reprova só na forma literal
`flutter test <caminho>` (exit 1). Nos portões reais, não:
- `build.yml` roda `flutter test test/casca` por glob → medido com a suíte apagada:
  **247 / 247, exit 0**;
- `ci-os-integracao.yml` guarda cada gate com `[ ! -f ]` e grava `nao_a11ycasca`; o passo de
  veredito se chama, literalmente, *"só falha em gate que REALMENTE rodou e falhou"*.

O `.github/` é idêntico entre gate anterior e candidata. Nenhum dos dois workflows dispara
nesta branch: `build.yml` só em `main`/`master`/`codex/inicio-ui`, `ci-os-integracao.yml` só em
`integracao/os-final-backend-flutter` — os dois mais `workflow_dispatch`.

## Veredito

```
HOME:              PASS   (ressalva visual: estouro de 25 px do ladrilho em 320 dp / 200%)
ONDE JOGAR:        PASS
PERFIL PRÓPRIO:    FAIL   ("Configurações" entrega 40 × 48 em 320 dp / 200%)
PERFIL VISITADO:   FAIL   (mesmo controle, mesma célula)
AVATAR:            PASS   (48,00 × 48,00 reais; PNG byte a byte idêntico ao da base)
RESPONSIVIDADE:    FAIL   (34 de 36 células limpas no piso efetivo; 2 abaixo)
CAMPANHA NEGATIVA: FAIL   (8 das 10 pedidas reprovam; M7 escapa)
VEREDITO FINAL:    FAIL
```

Não é BLOCKED: o Gate Zero passou nos dez itens e a medição foi possível do começo ao fim.

E é preciso dizer com a mesma clareza: **a OS 36-C1 fez exatamente o que lhe foi pedido, e o
fez certo.** O que reprova a candidata são duas coisas que ela herdou e que esta OS — não a
OS 36 — é a primeira a medir.

### O caminho mais curto para o verde

1. Fazer o `Row` de `_topo` caber: o título "Perfil" em `Expanded` com
   `TextOverflow.ellipsis`, ou `Flexible` no lugar do `Spacer`.
2. Afirmar `selecionado` na suíte: a aba corrente é `Tristate.isTrue` e as demais não são — o
   campo já é lido, só falta a expectativa.
3. Estender a suíte para ao menos 320 dp e 200% de texto, ou registrar por escrito que a
   superfície de 360 × 2000 é o contrato do portão.

---

## Bancada e limites declarados

`git -c core.autocrlf=false archive 9ce23d5` extraído em **C: (NTFS)**, `flutter create` +
`pubspec` do repositório + overlay de `lib`, assets, testes e seeds, exatamente como o
`ci-os-integracao.yml` monta. A raiz do repositório fica um nível acima do scaffold, porque
duas suítes leem `../.github/…` e `../functions-social/…`.

Flutter local **3.41.4**; o CI fixa **3.44.8** — base e candidata foram medidas na mesma versão,
então a comparação vale, mas números absolutos podem diferir no CI.

Toda mutação rodou em cópia descartável. A bancada canônica foi conferida por `hash-object` no
fim e está idêntica aos blobs de `9ce23d5`.
