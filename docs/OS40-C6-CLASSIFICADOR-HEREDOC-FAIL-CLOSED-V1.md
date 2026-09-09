# OS 40-C6 — Correção fail-closed do classificador contra falsa abertura de heredoc

**Gate afetado:** `portaoci` (`scripts/ci/teste_portao_os_integracao.sh`)

**Autoridade do defeito:** OS 40-R6 (FAIL). **Base:** OS 40-C5, commit `282dc77e`.

---

## 1. O defeito

Esta árvore tem **duas** leituras de código vivo, e as duas respondem à mesma
pergunta: quais linhas de um arquivo o interpretador de fato executa.

| Leitura | Arquivo | Serve a |
|---|---|---|
| `vivas_de` | `scripts/ci/autoridade_verificadores.sh` | gate `autverif` |
| `classificar_workflow` | `scripts/ci/teste_portao_os_integracao.sh` | gate `portaoci` e a guarda dos passos zero |

A OS 40-C5 endureceu a **primeira**: ela passou a abrir corpo de heredoc apenas
quando o resto da linha, depois do par `menor-menor`, é um identificador de
verdade. A **segunda** ficou como estava — aceitava qualquer resto não vazio.

A OS 40-R6 mediu o preço dessa assimetria. Uma ocorrência **textual** do par,
que não abre heredoc nenhum para o shell, jogava todas as linhas seguintes na
classe `HEREDOC` para o classificador. E, na classe `HEREDOC`:

* a contagem de passos **congela** — um `- name:` posterior deixa de ser passo;
* a escrita posterior de `t_<gate>.log` e de `exit_<gate>` **deixa de ser
  inspecionada** pela guarda que existe justamente para proibi-la;
* um passo zero material **novo** deixa de ser visto por
  `guarda_passo_zero_sem_relacao`.

O escape era material: com a falsa abertura depois do consumidor da evidência,
um passo acrescentado ao fim do workflow podia sobrescrever log e marcador de um
passo zero protegido e a cadeia oficial inteira continuava **verde**.

A mesma assimetria falhava também para o outro lado: uma ocorrência textual
**anterior** aos passos protegidos punha as três invocações canônicas em
`HEREDOC` e a guarda **reprovava o workflow íntegro**.

## 2. A correção

`classificar_workflow` passou a aplicar a **mesma condição de reconhecimento de
delimitador** já usada por `vivas_de`:

```sh
case "$resto" in
  '' | *[!A-Za-z0-9_]* | [0-9]*) ;;
  *) fim_heredoc="$resto" ;;
esac
```

Nada mais mudou no classificador. Não há parser de shell nem de YAML novo: o
escopo é exatamente a assimetria comprovada pela R6.

### Por que não é reuso direto da função

`vivas_de` mora num script que **executa ao ser lido**. Dar `source` nele para
tomar emprestada uma função rodaria a autoridade externa inteira dentro do gate
que ela audita. Um terceiro arquivo só para hospedar o predicado seria um
caminho a mais, fora do teto nominal desta OS.

Por isso a equivalência é **demonstrada**, e em dois eixos independentes:

* **`HD01` — comparação explícita.** O bloco de aceitação é extraído dos dois
  arquivos e comparado **letra por letra**. Divergir vira vermelho aqui, e não
  silêncio na próxima OS.
* **`HD02` — equivalência nominal.** `vivas_de` é **extraída por recorte de
  texto** do arquivo da autoridade e executada sobre o **mesmo corpus** de
  amostras. O que se compara é a decisão, não a semelhança das expressões.

## 3. As regressões

### Matriz de falsas aberturas (`HD03`–`HD16`, sobre amostras sintéticas)

Cada amostra tem **pós-condição própria**: em que classe o classificador pôs a
linha decisiva. Contar só o exit do arnês não distingue "a guarda enxergou e
recusou" de "a guarda recusou por outro motivo".

| Caso | Amostra | Pós-condição |
|---|---|---|
| HD03 | par entre aspas simples | a linha seguinte é `CODIGO` |
| HD04 | par entre aspas duplas | a linha seguinte é `CODIGO` |
| HD05/HD06 | par em comentário | a linha é `COMENTARIO`; a seguinte é `CODIGO` |
| HD07 | candidato com conteúdo adicional incompatível | a linha seguinte é `CODIGO` |
| HD08 | par embutido em comando de diagnóstico | a linha seguinte é `CODIGO` |
| HD09/HD10 | falsa abertura **antes** dos passos protegidos | invocação canônica é `CODIGO`; título é `PASSO` |
| HD11/HD12 | falsa abertura **depois** dos passos protegidos | `- name:` posterior é `PASSO`; a escrita do marcador é `CODIGO` |
| HD13/HD14 | heredoc **real** | o corpo é `HEREDOC`; depois do delimitador volta a `CODIGO` |
| HD15/HD16 | heredoc real com recuo e delimitador citado | idem |

### Vetores materiais (`PZ21`–`PZ25`, sobre o workflow real, nas três chaves)

Rodam para `portaoci`, `autverif` e `contratosui`, cada um com o exit da guarda
**e** a classe da linha decisiva.

| Vetor | O que faz | Esperado |
|---|---|---|
| PZ21 | falsa abertura no fim + marcador fabricado | VERMELHO, e a escrita é `CODIGO` |
| PZ22 | falsa abertura no fim + passo zero fora da relação | VERMELHO, e o título é `PASSO` |
| PZ23 | falsa abertura no fim + log **e** marcador forjados | VERMELHO, e a forja é `CODIGO` |
| PZ24 | ocorrência textual **anterior** aos passos protegidos | VERDE, e a invocação é `CODIGO` |
| PZ25 | heredoc **real** com o marcador no corpo | VERDE, corpo `HEREDOC`, depois `CODIGO` |

## 4. O que esta correção NÃO faz

A guarda é **léxica**, e continua sendo. Ela responde por presença viva,
unicidade, forma, ordem e passo — **não** por alcançabilidade dinâmica.

* Uma invocação canônica sob `if: false` continua **lexicamente viva** e a
  guarda continua **verde**. Quem fecha esse caso é o agregador, por ausência do
  artefato real: `NAO EXECUTADO` reprova.
* Um `exit_<gate>` vazio continua reprovando no agregador, e não aqui.

Declarar que esta guarda prova execução seria trocar uma propriedade léxica por
uma dinâmica que ela não tem. Os dois limites permanecem **fail-closed**, e por
outra peça.
