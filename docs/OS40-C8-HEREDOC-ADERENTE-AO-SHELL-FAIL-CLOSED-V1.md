# OS 40-C8 — Heredoc aderente ao shell e fail-closed

**Base:** `db822eb08da8054f5427558173d16b3f46f33931` (OS 40-C7, congelada)
**Autoridade:** OS 40-R8 — `FAIL` da C7
**Escopo:** `scripts/ci/` — o reconhecedor léxico e o que ele alimenta.
`scripts/ci/codigo_executavel.awk` **não foi tocado**: ele já estava certo sobre
`$'…'` e é a referência desta correção.

---

## 1. O que a OS 40-R8 mediu

A C7 tornou as duas cópias de `abertura_de_heredoc` idênticas letra por letra —
e isso continua verdade aqui. O que ela não fez foi torná-las aderentes ao
**shell real**. A rehomologação independente reproduziu quatro divergências, com
controle pareado em cada uma:

| | Eixo | O que o shell faz | O que a C7 fazia |
|---|---|---|---|
| E1 | ANSI-C quoting | `echo $'a\'b <<true '` é um `echo`; a linha seguinte **executa** | abria heredoc `true`; a linha seguinte sumia |
| E2 | terminador indentado | sem `<<-`, só fecha na **coluna zero** | comparava contra a linha aparada e fechava cedo |
| E3 | continuação física | a barra no fim apaga a **quebra**; o comando segue | entrava em `HEREDOC` ao fim da primeira linha física |
| E4 | citação aberta com abertura | indecidível | devolvia o delimitador com ambiguidade **zero** |

E1 e E3 escondiam sabotagem de evidência e um passo zero material inteiro com
`portaoci`, `autverif` e FASE A **verdes**. E2 deixava o produtor protegido
inerte e a guarda o via vivo. E4 é conformidade fail-closed, sem falso verde
isolado.

---

## 2. O que mudou

### 2.1 `abertura_de_heredoc` — o estado `S`

Havia um único estado de aspa simples, no qual a barra invertida nunca escapa.
Isso é correto para `'…'` e errado para `$'…'`. Agora são dois:

- `Q` — aspa crua: nada lá dentro é operador, nem a barra;
- `S` — ANSI-C: a barra **escapa** o próximo caractere, inclusive a aspa.

O par `$` + aspa só abre `S` em contexto de **código**. Dentro de aspas duplas
ele é literal, e o shell real não lhe dá tratamento nenhum. É a mesma separação
que `codigo_executavel.awk` já fazia com `cru=0` / `cru=1`.

### 2.2 `abertura_de_heredoc` — a continuação física

A barra invertida no fim da linha não escapa caractere nenhum: apaga a
**quebra**. O reconhecedor passa a sinalizar isso em `ABERTURA_CONTINUA`, e os
dois chamadores acumulam a **linha lógica** antes de decidir. A linha física
seguinte continua sendo código executável e é auditada como tal.

### 2.3 `abertura_de_heredoc` — a ambiguidade tem precedência

A conferência de citação aberta estava presa a `achadas -eq 0`: qualquer linha
que abrisse um heredoc válido escapava dela. Agora a linha que **acaba dentro de
uma citação ou expansão** (`ctx` deixa de ser `C`) é `AMBIGUO`, e
`ABERTURA_HEREDOC` é limpo — a ambiguidade vence a abertura.

`pilha` sozinha **não** é indecidível, e isto é deliberado:
`X="$(cat <<'EOF'` termina em contexto de código dentro de uma substituição que
continua, e o shell real abre o corpo ali mesmo. Tratá-la como ambígua seria a
recusa indiscriminada que esta OS proíbe.

### 2.4 Os dois chamadores — coluna real do terminador

`classificar_workflow` e `vivas_de` passam a recortar o bloco `run: |` pela
indentação da sua primeira linha. A indentação do bloco é **estrutura**; o que
sobra depois dela é **conteúdo**, e o shell a enxerga. Sobre esse resto:

- sem `<<-`, o terminador só fecha na coluna zero;
- com `<<-`, o shell remove **tabulações** iniciais, e somente elas.

Não é um parser de YAML. Um arquivo sem `run: |` — os `.sh` que esta mesma
leitura audita — fica com base zero e nada muda.

---

## 3. Provas

O corpus obrigatório de 45 amostras da C7 continua **integral e verde** contra o
shell real, e nenhuma expectativa foi invertida. Acrescentam-se:

- cinco linhas ao corpus do operador (`HD`): ANSI-C que não abre, ANSI-C sem
  escape, e as duas formas de citação aberta sobre uma abertura válida;
- `PZ32` (ANSI-C), `PZ33` (continuação física) e `PZ34` (terminador indentado),
  materiais, nas três chaves protegidas, cada um com o controle que prova que o
  instrumento continua vivo.

### 3.1 Uma nota sobre a fixture `V1`

A OS 40-R8 registrou `V1` — `echo $'a\'b <<XPTO '` antes dos passos protegidos,
sem terminador — com resultado obrigatório "guarda diferente de `0`". Aquele
resultado descrevia a C7: lá a linha cegava o arquivo e a guarda reprovava.

Com E1 fechado, essa linha é o que o shell sempre disse que ela era: um `echo`.
Medido nesta bancada, a sentinela da linha seguinte executa. O workflow que a
contém está **íntegro**, e `exit 0` é a resposta correta — exigir vermelho ali
seria exatamente a "recusa indiscriminada de `<<`" que a seção 1 desta OS
proíbe.

A propriedade que `V1` defende — *invocação protegida não pode desaparecer como
texto* — continua viva e provada: com um heredoc que o shell **realmente** abre
(`cat <<XPTO`) antes dos passos, a guarda reprova com
`a invocacao aparece como HEREDOC … texto nao executa`. É a mesma causa nominal
que `PZ34` cobra. A Central decide se reescreve a fixture; a candidata não
inverte expectativa por conta própria.

---

## 4. Limites, ditos

A guarda continua **léxica**. Ela responde sobre o que o shell leria, não sobre
o que a execução faria: alcançabilidade dinâmica não virou propriedade dela.
`Y01` e `Y03` seguem fail-closed no agregador, por artefato ausente ou inválido.

Produto intacto: nenhum arquivo de Flutter, Firebase, Functions, servidor, web,
assets ou dados foi tocado, e `.github/workflows` não mudou.
