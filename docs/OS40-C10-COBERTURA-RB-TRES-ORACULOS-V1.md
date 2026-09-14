# OS 40-C10 — Cobertura autêntica de RB01–RB14 nos três oráculos

**Base:** `90e8f9de68011378fb2715e974aee4070c6ac78b` (C9)
**Autoridade:** achado da Central pós-publicação da C9

## 1. O que esta OS faz

Completa a matriz RB01–RB14 para que **cada caso** tenha prova direta e nomeada
nos três eixos:

1. **shell real** — cada bloco `run:` extraído e executado como script separado;
2. **`classificar_workflow`** — extraído da própria suíte;
3. **`vivas_de`** — extraído da autoridade real e executado em subshell.

É uma correção de **testes e documentação**. A lógica de produção dos dois
leitores **não muda**: `abertura_de_heredoc`, o corpo de `classificar_workflow` e
o corpo de `vivas_de` permanecem byte a byte idênticos à C9.

## 2. Erratas do documento e do adendo da C9

Registradas aqui de forma **aditiva** (o documento da C9 não é editado):

1. A frase da C9 *"CADA CASO E MEDIDO EM TRES ORACULOS INDEPENDENTES"* descrevia
   a **intenção**, não a implementação publicada.
2. Na suíte publicada pela C9, apenas **RB01 e RB05** tinham chamada direta a
   `vivas_de`; os demais casos não exercitavam a segunda leitura por caso.
3. **RB08** não tinha execução própria contra o shell real (só duas asserções de
   `classificar_workflow`).
4. As *"42 asserções RB"* do adendo eram 42 verificações heterogêneas, não 14
   casos × 3 oráculos. E o diff da C9 continha **três caminhos de CI**
   (`teste_portao_os_integracao.sh`, `autoridade_verificadores.sh`,
   `gates_os_integracao.txt`) **e um documento** — quatro caminhos no total —,
   e não "cinco scripts de CI e este documento" como a redação da C9 sugeria.
5. A C10 completa a prova **sem alterar a semântica** do classificador nem da
   autoridade. A equivalência textual do ramo de reset continua sendo evidência
   útil, mas agora é **complementada** pela medição direta de `vivas_de` nos 14
   vetores.

Nada disso indica falha funcional da correção de fronteira da C9: a semântica
estava certa; faltava a **prova por caso** no eixo `vivas_de` e o eixo do shell
real em RB08.

## 3. A cobertura acrescentada

Para cada RB01–RB14, a C10 garante ao menos uma asserção nomeada `RBnn [oráculo]`
em cada eixo. Em particular acrescenta:

- **shell real:** RB07 (código após o terminador executa), RB08 (corpo não
  executa; código após o terminador executa);
- **`classificar_workflow`:** RB12 (código após o terminador é `CODIGO`);
- **`vivas_de`:** todos os casos que não tinham (RB02–RB04, RB06–RB14), com
  **ausências testadas como ausência** (corpo de heredoc e comentário não são
  emitidos por `vivas_de`), nunca inferidas da presença de outra linha.

Para **RB13**, o eixo `vivas_de` é medido com preservação do código de saída: a
função **recusa** pela ambiguidade do bloco A (`RC != 0`) **e**, ainda assim,
analisa o bloco B independentemente (a carga do bloco B aparece na saída
produzida).

## 4. Autoproteção (além de AUTO-0/A/B da C9)

- **AUTO-C** — remover o ramo de reset da fronteira **de `vivas_de`** (numa cópia
  externa da autoridade) faz **RB02, RB04 e RB14** perderem a carga do bloco B:
  ela vira corpo do heredoc aberto no bloco anterior. Prova que a cobertura de
  `vivas_de` é load-bearing, e não herdada da igualdade textual do reset. A cópia
  intacta dá `SIM`; a mutada dá `NAO`.
- **AUTO-D** — adulterar o vetor **RB08** para que a linha que deveria ser corpo
  fique **fora** do heredoc (executável) é **detectado pelo oráculo do shell
  real**: a sentinela passa a nascer (`EXISTE`), enquanto o RB08 legítimo dá
  `AUSENTE`.

As funções são sempre **extraídas dos arquivos reais** e rodadas em subshell;
as cópias mutadas ficam sob o `mktemp -d` da suíte (destruído no `trap`), e a
árvore rastreada nunca é editada pelas mutações. Uma mutação que não mude bytes é
`INSTRUMENTO INVÁLIDO` e reprova.

## 5. Contadores e escopo

`teste_portao_os_integracao.sh` sobe pelo número real de novas asserções:
`casos` 293→320, `provas` 92→98. Atualizados no mesmo commit o digest normalizado
de `teste_portao` (em `gates_os_integracao.txt` e no bloco de digestos de
`autoridade_verificadores.sh`) e o digest de `autverif`. Nenhum número foi
alterado por exclusão.

Mudam apenas: este documento, `teste_portao_os_integracao.sh` (só a seção de
testes), `gates_os_integracao.txt` (digest/pisos) e `autoridade_verificadores.sh`
(só o digest congelado de `teste_portao` e o seu próprio, por consequência).
`.github/workflows/**`, o produto, `codigo_executavel.awk`,
`teste_contrato_suites.sh`, `verificar_contrato_suites.sh`, os documentos
históricos C8 e C9, e os corpos de `abertura_de_heredoc`, `classificar_workflow`
e `vivas_de` permanecem byte a byte idênticos à C9. NX3 não é tratado.
