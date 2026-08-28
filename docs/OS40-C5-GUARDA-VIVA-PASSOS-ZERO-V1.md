# OS 40-C5 — a execução de cada passo zero, viva e insubstituível

A OS 40-C4 congelou **uma** invocação: a da testemunha do `contratosui`, no passo
`0b` do `ci-os-integracao.yml`. A rehomologação OS 40-R5 mediu o preço de ser só
uma. A execução real de `scripts/ci/autoridade_verificadores.sh` foi retirada do
passo `0a` e substituída por evidência fabricada — um `t_autverif.log` de uma
linha e um `exit_autverif` com zero dentro —, e **a cadeia oficial inteira ficou
verde**: `portaoci` 53/53, FASE A exit 0, agregador 64/64, FASE B 17 contratos.

O detector material da R5 confirmou que a autoridade não tinha rodado: hash e
`mtime` do log e do marcador permaneceram inalterados, o log forjado tinha uma
linha e a execução real produz oitenta e três. A própria autoridade não resolvia
o escape: a autocobrança dela era `grep -F` sobre o YAML inteiro, e um literal
posto em heredoc satisfaz busca textual sem executar uma linha.

## A propriedade

> O caminho oficial só pode ficar verde se `autoridade_verificadores.sh` tiver
> sido realmente executada pela invocação **viva, única e exata** do passo `0a`,
> com a saída ligada ao `tee` real e o código de saída do **produtor**
> propagado, antes de qualquer consumidor aceitar `t_autverif.log` ou
> `exit_autverif`.

Texto, comentário, heredoc, `echo`, arquivo preexistente ou marcador fabricado
**não** substituem a execução.

## O desenho

A guarda da C4 foi **generalizada, e não duplicada**. `guarda_invocacao_testemunha`
virou `guarda_passo_zero <registro> <chave>`, e a relação dos passos protegidos
mora em `scripts/ci/teste_portao_os_integracao.sh`, escrita por extenso:

```sh
readonly PASSOS_ZERO_PROTEGIDOS='portaoci autverif contratosui'
```

Ela **não é derivada do workflow**: uma lista lida de lá encolheria junto com
ele — apagar o passo apagaria a exigência de que o passo exista. Só dois campos
são literais (o número do passo e a linha de invocação, espremida); núcleo,
captura, purga, log e marcador são **derivados da chave**, para que a guarda não
possa cobrar o artefato de uma chave contra a invocação de outra.

Para cada chave, a guarda classifica o YAML linha a linha (código, comentário,
heredoc, passo) e cobra:

| | |
|---|---|
| invocação | viva, **única**, com a forma oficial exata |
| passo | o título tem de ser o passo declarado (`0`, `0a`, `0b`) |
| purga | `rm -f t_<k>.log exit_<k>` exatamente uma vez, antes, no mesmo passo, sem nada no meio |
| `tee` | ligado ao log oficial, e não a outro arquivo |
| captura | `${PIPESTATUS[0]}` do produtor, logo depois, sem nada no meio |
| evidência | **nenhuma outra linha viva** escreve aquele log ou aquele marcador |
| ordem | o passo vem antes do consumidor (`verificar_contrato_suites.sh`) |
| relação | passo zero que produza `exit_<gate>` sem estar na relação reprova |

`guarda_passo_zero_sem_relacao` fecha a saída de emergência da tabela manual:
acrescentar um passo `0d` que escreve evidência obrigatória e não é guardado por
ninguém seria repetir a R5 com outro nome.

## Dois chamadores, e por quê

A guarda é chamada **de dois lugares do caminho oficial**:

1. o passo `0`, pelo gate `portaoci` (invariante `I10`);
2. a **FASE A** do contrato de conteúdo, no passo `0c`, pelo modo `--guarda`.

Não é um segundo analisador — é o mesmo arquivo, o mesmo classificador e a mesma
relação congelada. O segundo chamador existe porque o primeiro mora no passo `0`:
quem apaga o passo apaga quem reclamaria dele. A FASE A roda sob `bash -e` e
derruba o job.

## A evidência é fresca por construção

Cada passo zero purga o log e o marcador **antes** de executar. `atime` não serve
de prova — a FASE A **abre** o log durante as próprias leituras, e acesso não é
execução. A FASE B continua exigindo log posterior ao `carimbo_execucao` deste
run; a purga fecha a metade que o carimbo não cobre, que é o marcador.

## O quarto verificador

`scripts/ci/teste_portao_os_integracao.sh` entrou no inventário de
`autoridade_verificadores.sh` — com digesto próprio e decisões materiais
congeladas **fora dele**. Quem apagar a relação dos passos zero muda um arquivo
guardado em dois lugares independentes: a fonte única (digest, piso de casos e
vinte e duas relações `exige`) e o inventário da autoridade externa. Os dois
teriam de cair juntos.

A seção 7 da autoridade deixou de ler o YAML por `grep -F` sobre o texto: passou
a ler **código vivo**. Fecha a metade textual da autocobrança; a metade que
decide continua sendo a guarda léxica.

## Duas armadilhas medidas, e registradas no código

**`\"` dentro de `"..."` abre uma string para o analisador léxico.**
`chave="${chave%%\"*}"` fez o `codigo_executavel.awk` ler o resto do arquivo como
string aberta: doze declarações desta suíte deixaram de ser contadas e o piso de
`provas` caiu sem que uma linha saísse do arquivo. A aspa sai por variável
(`$ASPA_DUPLA`), como o próprio classificador já documentava.

**`<<` colado abre um heredoc para o leitor de código vivo da autoridade.**
Um `cat <<FIM > /dev/null` dentro do programa `awk` dos vetores fazia
`vivas_de` engolir três quartos do arquivo — as decisões materiais dele
apareciam zero vezes num repositório intacto. O par sai partido (`"cat <" "<FIM"`),
e `vivas_de` passou a só abrir heredoc com **palavra de verdade**: `*)` e `}`,
que aparecem depois de `<<` dentro de aspas, não são delimitadores.

## Placares desta árvore

| | antes (C4) | agora |
|---|---|---|
| `portaoci` | 53/53 | **101/101** |
| autoridade `autverif` | 66/66 | **82/82** |
| FASE A | exit 0 | exit 0 |
| FASE B | 17 contratos | 17 contratos |
| vetores de passo zero | 15 (só `0b`) | **63** (21 × 3 passos) |
| `exige` de `portaoci` | 6 | **22** |
| `exige` de `autverif` | 11 | **14** |

Nenhum piso desceu. Digest, piso de casos e piso de relações subiram no mesmo
commit — um piso que fica para trás deixa de notar que os vetores sumiram.

## O ataque da R5, repetido

Numa bancada que extrai os passos zero do próprio YAML e os executa como o
Actions os executa:

| | árvore íntegra | forja no `0a` (a da R5) | forja no `0b` (a da C4) |
|---|---|---|---|
| passo `0` (`exit_portaoci`) | `0` | **`1`** | **`1`** |
| passo `0c` (FASE A) | exit 0 | **exit 1** | **exit 1** |
| `t_autverif.log` | reescrito, **99 linhas** | reescrito, **1 linha** | reescrito, 99 linhas |
| `exit_autverif` | reescrito nesta corrida | fabricado, `0` | reescrito nesta corrida |
| FASE B | 17 contratos, exit 0 | não alcançada | não alcançada |
| agregador | 64/64 VERDE | não alcançado | não alcançado |
| **exit final** | **0 (VERDE)** | **1 (VERMELHO)** | **1 (VERMELHO)** |

O log é o discriminador material: noventa e nove linhas quando a autoridade
roda, uma quando o `echo` a substitui. O marcador **não** serve para isso — o
`0\n` de uma corrida verde é a mesma cadeia de bytes da evidência plantada, e
por isso o veredito de "reescrito" é por `mtime`.

A forja do `0b` continua vermelha, e nela a autoridade do `0a` roda de verdade:
o fechamento da C4 é preservado, e não trocado por este.

## Campanha nominal

Vinte e oito sabotagens, cada uma em cópia descartável, com âncora conferida
antes e efeito conferido depois. **28 detectadas, 0 escapes, 0 inconclusivas**;
controle inicial e final verdes; bancada restaurada e conferida por hash.

Vinte e cinco caem na guarda léxica, com recusa nominal — invocação ausente,
comentada, em `echo`, em heredoc, em string, duplicada, movida, com o `tee`
retirado ou desviado, com argumento a mais ou a menos, com o caminho trocado,
com `|| true` ou `; true`, com o exit do `tee` no lugar do produtor, com log ou
marcador escritos fora da invocação oficial, com o título do passo trocado, e
com um passo zero novo fora da relação.

Três caem nos outros elos, e são justamente os que provam por que a guarda
precisa de **dois** chamadores: apagar a guarda e neutralizá-la com saída
antecipada são acusadas pela FASE A (ausência do arquivo, e digest que mudou sem
a assinatura acompanhar); reutilizar artefatos de corrida anterior é acusada
pela FASE B, que data a evidência contra o carimbo deste run.
