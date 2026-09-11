# OS 40-C9 — A fronteira de `run:` encerra o estado shell (fail-closed)

**Base:** `76221a5981f17761ed2516462eec858af02d01f7` (C8)
**Autoridade:** OS 40-R9 — contraexemplo material `NX5`

## 1. O defeito

Cada `run:` de um workflow do GitHub Actions é um **script e um processo shell
próprios**. Um heredoc aberto no bloco A termina no EOF do script A; ele nunca
consome a primeira linha do bloco B. As duas leituras de código vivo desta
árvore — `classificar_workflow` (em `teste_portao_os_integracao.sh`) e
`vivas_de` (em `autoridade_verificadores.sh`) — não sabiam disso: o ramo que
consome corpo de heredoc rodava **antes** do reconhecimento estrutural do fim do
bloco, e `fim_heredoc` atravessava a fronteira YAML.

A OS 40-R9 mediu o preço em `NX5`: uma única linha `cat <<true` no fim de um
bloco `run:` deixava `fim_heredoc` ativo, e **todo o bloco seguinte** — a escrita
de log e de marcador forjados de `exit_portaoci` — sumia na classe `HEREDOC`.
Com isso montava-se um falso verde material do `portaoci`, o gate que guarda o
próprio CI.

## 2. A correção

O recorte do bloco literal `run: |` que a C8 introduziu já detectava o **dedent
estrutural**: uma linha não vazia menos indentada que a base do bloco está fora
dele. A C8 usava essa detecção só para zerar `base`; a C9 estende **exatamente
esse ramo** para descartar o estado shell que o bloco carregava:

```sh
case "$pref" in
  *[![:blank:]]*)
    base=0
    fim_heredoc=''
    her_tabs=0
    acumulada=''
    continuando=0
    ;;
  *) sh_linha="${linha:$base}" ;;
esac
```

O reset é **estrutural**, disparado só pela indentação, e vem **antes** do ramo
que consome corpo de heredoc:

- `run: |` ou `- name:` **dentro** de um corpo de heredoc estão mais indentados
  que a base, não chegam a este ramo, e continuam sendo dado (RB07, RB08);
- num arquivo `.sh` a base é zero e o ramo nunca roda: o arquivo inteiro segue
  sendo um único script (RB12);
- um heredoc aberto no fim de um bloco alcança só o EOF daquele bloco; o estado
  morre ali e não contamina o seguinte (RB01–RB04, RB14);
- uma continuação física (`\`) no fim do bloco também não concatena com o
  próximo (RB05); ambiguidade real segue fail-closed na origem, sem contaminar o
  bloco seguinte (RB13).

`abertura_de_heredoc` **não mudou** — as duas cópias continuam byte a byte
idênticas. A alteração é a mesma nas duas leituras.

## 3. As provas

- **RB01–RB14** — a matriz de fronteira, cada caso medido em três oráculos:
  o **shell real** (cada `run:` extraído e executado como script separado, com
  sentinela), `classificar_workflow` e `vivas_de`. O resultado vem primeiro do
  shell real.
- **NX1, NX2, NX4, NX5** — o contraexemplo da R9 e suas variantes, cada um com o
  controle pareado sem `cat <<true`: vetor e controle têm o **mesmo veredito e a
  mesma causa nominal**. `NX5` reprova nos três oráculos (`--guarda` nomeando as
  duas linhas forjadas; `verificar_contrato_suites` porque a guarda de passo zero
  caiu), e `vivas_de` expõe as duas linhas do bloco B como código.
- **E1–E4, V1, V1′, V2, V3** — os quatro eixos que a C8 fechou permanecem
  fechados, sem regressão nem expectativa invertida.
- **Autoproteção** — duas mutações em cópias externas: remover o reset restaura o
  vazamento (o bloco B volta a `HEREDOC`); um reset indiscriminado por texto,
  sem olhar indentação, transforma corpo de heredoc em código e é pego por RB07.

## 4. Escopo

Só mudam, em relação à C8, os cinco scripts de CI e este documento. O reset foi
aplicado em `classificar_workflow` e `vivas_de`; os digestos e os pisos de
`portaoci` (`sha256`, `casos` 248→293, `provas` 74→92) e o `sha256` de `autverif`
acompanham a mudança de conteúdo. `.github/workflows/**`, o produto,
`scripts/ci/codigo_executavel.awk` e o documento histórico da C8 permanecem
byte a byte idênticos.

O achado `NX3` (marcador de gate não protegido escrito de passo comum) **não** é
tratado aqui: a C9 apenas garante que sua correção de fronteira não o piora nem o
mascara. O enquadramento de `NX3` é decisão da Central.
