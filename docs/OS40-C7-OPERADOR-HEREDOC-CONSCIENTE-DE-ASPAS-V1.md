# OS 40-C7 — Operador de heredoc consciente de aspas

**Gates afetados:** `portaoci` (`scripts/ci/teste_portao_os_integracao.sh`) e
`autverif` (`scripts/ci/autoridade_verificadores.sh`)

**Autoridade do defeito:** OS 40-R7 (FAIL). **Base:** OS 40-C6, commit `a2c42a4a`.

---

## 1. O defeito

A OS 40-C6 igualou as duas leituras de código vivo desta árvore —
`classificar_workflow`, na matriz do passo zero, e `vivas_de`, na autoridade
externa — e provou a igualdade comparando, letra por letra, o bloco de aceitação
do delimitador. As duas passaram a fazer, em essência, isto:

```sh
resto="${nu##*<<}"
resto="${resto//$aspa_simples/}"
resto="${resto//$aspa_dupla/}"
case "$resto" in
  '' | *[!A-Za-z0-9_]* | [0-9]*) ;;
  *) fim_heredoc="$resto" ;;
esac
```

A remoção das aspas existe para aceitar `<<'EOF'` e `<<"EOF"`. Ela apaga,
porém, **qualquer** aspa — inclusive a de **fechamento** de uma string que
contenha o par. E é essa aspa a única coisa que separa

```sh
cat <<ALVO                  # o par é operador de redirecionamento
echo "diagnostico <<ALVO"   # o par é texto, e não abre corpo nenhum
```

Apagada a aspa, as duas formas viram a mesma. A OS 40-R7 reproduziu o preço
sobre o workflow real, com **uma** linha acrescentada:

| Consequência medida na base `a2c42a4a` | |
|---|---|
| restante do workflow | classe `HEREDOC` |
| contagem de passos | congelada (`passo_max` 34 de 36) |
| passo zero material novo (`0d`/`exit_novogate`) | invisível |
| escrita posterior de `t_portaoci.log` e `exit_portaoci` | invisível |
| guarda `--guarda` | exit `0` |
| `autverif` | `91/91`, exit `0` |
| FASE A | 17 contratos, exit `0` |

E a assimetria continuava valendo para o outro lado: a mesma ocorrência
**antes** dos passos protegidos punha as três invocações canônicas em `HEREDOC`
e a guarda **reprovava o workflow íntegro**.

A C6 fechou apenas o subconjunto cujo resto já continha caractere incompatível
(`$ALVO`, `b)`, `3`). O caso natural — texto citado que é um identificador puro
— continuava aberto, e é o que qualquer pessoa escreve num diagnóstico.

### Por que a bancada da C6 não pegava

- `HD01` comparava **só** o bloco `case "$resto" in`. As seis linhas de
  normalização, onde a decisão errava, ficavam de fora.
- `HD02` comparava a **decisão** das duas leituras. As duas erravam igual, logo
  concordavam. Concordância não é correção.
- As amostras de aspas escolhiam restos já recusados por outro motivo
  (`$ALVO` tem `$`; `<<' arquivo` deixa o resto vazio) — nunca um identificador
  puro entre aspas.

---

## 2. A correção

O reconhecimento passa a ocorrer em **duas etapas, nesta ordem**:

1. achar o **operador** `<<` fora de região inerte;
2. só então ler a **citação** que pertence ao token do delimitador.

É proibido, por construção, remover as aspas antes da etapa 1 — não há mais
recorte por `${nu##*<<}`.

`abertura_de_heredoc <linha>` é uma máquina de estados caractere a caractere,
**idêntica letra por letra nos dois arquivos**, que distingue código de:

- aspa simples (`'...'`), onde nada é operador;
- aspa dupla (`"..."`), com `$(...)` voltando a ser código — é assim que
  `DIGESTOS="$(cat <<'DIGESTOS_CONGELADOS'` continua abrindo de verdade;
- expansão de parâmetro `${...}`, onde `${nu##*<<}` é um nome com corte;
- aritmética `$((...))`, onde `1<<2` é deslocamento;
- comentário `#` em início de palavra;
- barra invertida, que escapa o caractere seguinte (`echo \<<EOF` não abre
  nada: o que sobra é `<EOF`, redirecionamento de entrada);
- here-string `<<<`, que não abre corpo.

Ela devolve o delimitador em `ABERTURA_HEREDOC` — e, quando **não consegue
decidir**, devolve `ABERTURA_AMBIGUA=1`. Falham fechado, explicitamente:

- citação que não fecha na linha;
- duas aberturas na mesma linha;
- delimitador fora da gramática (`<<2FIM`, `<<FIM-DA-AMOSTRA`), que o shell
  abre e esta leitura não sabe representar.

A linha indecidível sai com a classe `AMBIGUO` — nem `CODIGO`, nem `HEREDOC` —
e a guarda a recusa **pelo número da linha**. `vivas_de` retorna não-zero e a
autoridade externa recusa pelo nome do arquivo.

### O lexer do contrato de conteúdo

`scripts/ci/codigo_executavel.awk` é a referência arquitetural desta correção, e
tinha três divergências próprias contra o shell real, todas fechadas aqui:
`x=$((1<<2))` abria heredoc espúrio (faltava o estado de aritmética),
`cat <<<palavra` abria pelo par do **meio** do `<<<`, e `echo \<<EOF` não
tratava a barra invertida fora de string. A primeira era material: um
deslocamento aritmético num `.sh` auditado tornava o arquivo inteiro `INERTE`.
Foi ela que mantinha o piso de provas de `autverif` em **14** — com o lexer
corrigido, o mesmo arquivo da base conta **35**.

---

## 3. As provas

**`HD01`** compara agora a **função inteira** nos dois arquivos, letra por
letra: descoberta do operador, estado de aspas e extração do delimitador.

**`HD02`** extrai `vivas_de` **e** `abertura_de_heredoc` da autoridade externa e
as executa num **subshell** — antes, a leitura de lá era medida com a função
daqui.

**`HD17`–`HD51`** são o corpus do operador, com **três** testemunhas por linha:
o veredito daqui, o veredito da autoridade externa e o **shell real**, que
executa uma sentinela na linha seguinte. Um oráculo externo é o que faltava: as
duas leituras concordavam justamente onde estavam erradas.

**`PZ26`–`PZ31`**, nas três chaves protegidas, repetem a bateria material da
R7 com a forma que escapava — entre aspas duplas e entre aspas simples —, mais
o controle do outro lado (ocorrência anterior tem de ficar **verde**) e a
entrada indecidível (tem de sair `AMBIGUO` e ser recusada pelo número da linha).

Nenhum caso anterior foi removido, substituído ou reduzido.

| Medida | C6 | C7 |
|---|---:|---:|
| casos de `portaoci` | 158 | 228 |
| provas de `portaoci` | 67 | 74 |
| relações de `portaoci` | 37 | 49 |
| casos de `autverif` | 91 | 96 |
| provas de `autverif` | 14 | 35 |
| relações de `autverif` | 14 | 18 |
| `exige` na fonte única | 173 | 189 |
| atributos indentados | 294 | 310 |

As três relações de conteúdo que apontavam para construções deletadas
(`case "$resto" in`, `regra_do_delimitador`, `cmp` dos dois recortes de regra)
foram **substituídas** — não removidas — pelas relações sobre o código que
tomou o lugar delas. O total sobe nos dois gates.

---

## 4. O que esta OS não faz

A guarda continua **léxica**. Ela responde por texto que executa, e não por
alcançabilidade dinâmica: `Y01` (invocação viva porém inalcançável) e `Y03`
(marcador vazio) seguem verdes nela e **fail-closed no agregador**, por
artefato ausente ou inválido. Nada aqui muda isso.
