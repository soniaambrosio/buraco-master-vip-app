#!/usr/bin/env bash
#
# CONTRATO DE CONTEUDO DAS SUITES PROTEGIDAS — gate `contratosui`.
#
#   uso: verificar_contrato_suites.sh <raiz> [workflow] [dir_resultados]
#
#     raiz            raiz do repositorio (`.` num checkout normal).
#     workflow        opcional. Sem ele, as conferencias de registro no CI nao
#                     rodam. No CI ele e SEMPRE dado.
#     dir_resultados  opcional. Com ele, roda tambem a FASE B (abaixo).
#
# ---------------------------------------------------------------------------
# POR QUE ESTE ARQUIVO EXISTE
# ---------------------------------------------------------------------------
#
# A fonte unica `scripts/ci/gates_os_integracao.txt` ja respondia duas das tres
# perguntas que um portao precisa responder sobre uma suite obrigatoria:
#
#   1. o ARQUIVO esta la?  -> o auxiliar `roda` escreve `nao_<gate>` quando nao
#                             esta, e o agregador reprova NAO EXECUTADO
#   2. ela foi EXECUTADA?  -> so `exit_<gate>` valendo exatamente `0` passa
#   3. ela ainda PROVA?    -> NINGUEM PERGUNTAVA
#
# A terceira e o buraco que a rehomologacao da OS 30 mediu em outra linhagem:
# trocar o corpo de uma suite obrigatoria por um unico `expect(1, 1)` — mantendo
# nome, caminho, sufixo `_test.dart` e o registro no workflow — deixava TODOS os
# portoes verdes, com dezenas de provas a menos no run. Arquivo presente,
# execucao registrada, conteudo esvaziado.
#
# Este script fecha a terceira pergunta, e a fecha DENTRO da autoridade que ja
# existe: o contrato mora em linhas indentadas sob o gate, na fonte unica de
# sempre. Nao ha segundo manifesto e nao ha segunda relacao de gates — a relacao
# vem de `portao_os_integracao.sh --listar`, o unico leitor.
#
# ---------------------------------------------------------------------------
# O CONTRATO
# ---------------------------------------------------------------------------
#
#   <gate>                                  <- na margem, como sempre
#       suite      <caminho relativo a raiz do repo>          (REPETIVEL)
#       executor   <trecho literal que o workflow tem de conter>
#       sha256     <64 hex do conteudo, com TODO CR removido>
#       provas     <piso ESTATICO de declaracoes de caso>
#       conta      <ERE das declaracoes>     (opcional; padrao = Dart)
#       casos      <piso de casos EXECUTADOS, lido do log>   (opcional)
#       contador   <ERE com numero, no log>  (opcional; padrao = `+N` do Flutter)
#       exige      <literal de codigo que tem de continuar la>   (repetivel)
#       alvo       <manifesto que o executor roda>            (opcional)
#       exigealvo  <literal que tem de continuar no alvo>     (repetivel; exige `alvo`)
#
# ---------------------------------------------------------------------------
# UM GATE PODE GUARDAR MAIS DE UMA SUITE (OS 40-C1)
# ---------------------------------------------------------------------------
#
# `suite` e REPETIVEL, e `sha256`/`provas`/`conta`/`exige` pertencem a suite
# declarada acima deles. Os demais atributos sao do GATE, e podem aparecer em
# qualquer ordem — as conferencias que dependem deles sao feitas no fim da
# entrada, e nao na hora da leitura.
#
# Um gate de codebase — `npm test`, `pytest`, `go test` — roda VARIOS arquivos
# de uma vez. Ate esta OS o vocabulario so sabia falar de um, e a metade nao
# declarada ficava sem assinatura, sem piso e sem `exige`: era possivel tirar do
# alvo a suite que guarda a outra e nada ficava vermelho.
#
# ---------------------------------------------------------------------------
# `alvo` — QUANDO O EXECUTOR NAO NOMEIA O ARQUIVO
# ---------------------------------------------------------------------------
#
# O contrato sempre exigiu que o `executor` CITASSE a suite: sem isso ele
# aceitaria um passo que roda outra coisa — produtor sem alvo, o degrau seguinte
# ao gate fantasma. Mas um passo que roda `npm test` nao cita arquivo nenhum:
# quem nomeia as suites e o `package.json`. Sem `alvo`, um gate de codebase so
# entraria no contrato afrouxando aquela exigencia.
#
# `alvo` fecha a cadeia INTEIRA, elo por elo, em vez de afrouxar:
#
#   executor  ->  cita o diretorio do alvo          (o passo roda AQUELE codebase)
#   alvo      ->  nomeia CADA suite declarada       (o comando oficial roda AQUELAS suites)
#   exigealvo ->  literais que continuam no alvo    (o comando oficial nao mudou de forma)
#
# A busca dentro do alvo ignora comentario, e conhece a chave de comentario de
# JSON (`"//..."`, usada neste repositorio para documentar `scripts`): repetir o
# caminho de uma suite numa chave de prosa nao pode substituir roda-la.
#
# O alvo NAO tem `sha256`, e isso e decisao. Um `package.json` muda por versao de
# dependencia, e um digest que reprova a cada bump vira pressao para afrouxar a
# guarda. O que esta OS congela do alvo e o COMANDO OFICIAL, por `exigealvo` —
# nominal, legivel no diff, e imune a bump.
#
# `provas` e ESTATICO de proposito: a guarda precisa reprovar sem executar a
# suite que ela guarda, e ANTES dela. `casos` e o mesmo piso do outro lado — lido
# do log da execucao — e existe porque contagem estatica nao ve caso gerado em
# laco: a suite da Comunicacao declara 71 `test(` e executa 81.
#
# `exige` casa por literal INCLUINDO o parentese da chamada, e a busca IGNORA
# linha de comentario. Sem isso, uma suite esvaziada cujos comentarios
# repetissem os literais satisfaria o contrato sem provar nada — a forja mais
# barata que existe contra busca textual.
#
# A assinatura e sobre o conteudo com TODO CR removido: o indice do git guarda
# LF, a arvore de trabalho no Windows tem CRLF (`core.autocrlf=true`) e o runner
# do Actions ve LF. Assinar os bytes crus valeria numa plataforma e mentiria na
# outra.
#
# ---------------------------------------------------------------------------
# AS DUAS FASES
# ---------------------------------------------------------------------------
#
# FASE A (sempre) — estatica. Roda ANTES de Flutter, de Node e de emulador, e
# FALHA POR CONTA PROPRIA, com exit diferente de zero. Um verificador cuja
# reprovacao precisa ser somada num portao la na frente herda o defeito que veio
# consertar.
#
# FASE B (so com <dir_resultados>) — o log. Fecha as duas formas de ficar verde
# sem ter rodado: marcador FABRICADO (um `exit_<gate>` com `0` dentro e nenhum
# log ao lado) e evidencia de OUTRA EXECUCAO (um log mais velho que o carimbo que
# o proprio run escreveu). E onde `casos` e conferido.
#
# ---------------------------------------------------------------------------
# ATE ONDE ELE ALCANCA
# ---------------------------------------------------------------------------
#
# Ele NAO pega quem apagar o passo que o invoca do workflow — nenhuma
# verificacao dentro de um workflow cobre a propria remocao do workflow. O que
# ele faz e nao deixar isso ser silencioso: a chave `contratosui` esta na fonte
# unica, o agregador reprova por ausencia de resultado, e a FASE A exige que a
# propria invocacao continue escrita no YAML.

set -u

raiz="${1:-.}"
workflow="${2:-}"
dir_resultados="${3:-}"

fonte="$raiz/scripts/ci/gates_os_integracao.txt"
agregador="$raiz/scripts/ci/portao_os_integracao.sh"

# ---------------------------------------------------------------------------
# O QUE ESTE SCRIPT EXIGE DE SI MESMO
#
# Escrito AQUI, e nao so na fonte unica, pela mesma razao que a fonte unica nao
# se guarda sozinha: esvaziar o contrato no arquivo de dados seria a saida
# silenciosa que este script veio fechar. A fonte pode CRESCER com decisoes
# futuras; nao pode encolher ate zero, nem perder estas chaves, nem rebaixar
# estes pisos.
# ---------------------------------------------------------------------------
#
# `PISOS_PROVAS` e sobre a SOMA das declaracoes das suites do gate — um gate com
# uma suite so, que e o caso de todos menos `rankingfn`, se comporta como sempre.
readonly CONTRATOS_MINIMOS="comunicacao chatdom portaoci contratosui rankingfn autverif"
readonly PISOS_PROVAS="comunicacao:83 chatdom:60 portaoci:67 contratosui:82 rankingfn:57 autverif:14"
readonly PISOS_CASOS="comunicacao:81 portaoci:158 contratosui:68 rankingfn:465 autverif:91"

# `PISOS_EXIGE` — QUANTAS relacoes de conteudo cada gate tem de continuar tendo.
#
# A rehomologacao OS 40-R2 mediu o buraco que faltava: TIRAR UMA LINHA `exige` DA
# FONTE nao reprovava nada. As relacoes protegiam a suite, e nada protegia as
# relacoes — o manifesto guardava a si mesmo. Com a afirmacao apagada no mesmo
# commit, a arvore ficava inteiramente verde.
#
# Este piso e a metade generica da defesa, e vale para os dezesseis contratos:
# uma relacao a menos reprova aqui, do lado de fora, mesmo que ninguem tenha
# escrito o conjunto nominal daquele gate. A outra metade — o conjunto NOMINAL
# EXATO — esta em `RELACOES_CONGELADAS`, logo abaixo.
readonly PISOS_EXIGE="comunicacao:35 chatdom:6 portaoci:37 contratosui:29 rankingfn:15 \
avatarcanon:4 avatarhml:4 perfilvis:4 rknavpub:4 compavrank:3 compnavpub:3 \
socialestado:3 socialleitor:3 socialtela:2 audsocial:4 a11yamigos:3 autverif:14"

# ---------------------------------------------------------------------------
# `RELACOES_CONGELADAS` — O CONJUNTO NOMINAL EXATO DA FOLHA (OS 40-C2)
# ---------------------------------------------------------------------------
#
# Contagem sozinha nao basta. Com um piso e so um piso, trocar uma relacao por
# outra, renomear uma, ou DUPLICAR outra para conservar a quantidade continua
# passando — e trocar uma exigencia de `PF-01` por uma da superficie, tambem.
# O que fecha isso e o conjunto, POR SUITE, escrito por extenso e FORA do bloco
# que ele guarda.
#
# A comparacao e de IGUALDADE EXATA, linha a linha e na ordem: retirada,
# renomeacao, duplicacao, reordenacao e troca entre as duas suites do gate
# reprovam todas pelo mesmo caminho, cada uma nomeando o que mudou. E a
# cardinalidade sai de graca e por suite — SETE em `passe.test.js` (as de
# `PF-01`) e OITO em `superficie.test.js`, quinze no gate.
#
# RECIPROCIDADE: `SUITES_CONGELADAS` e `ALVOS_CONGELADOS` fecham as outras duas
# pontas. Sem elas, renomear a suite na fonte faria o conjunto congelado dela
# deixar de casar com qualquer coisa — e um conjunto que nao casa com nada nao
# reprova nada. Com elas, alvo, suite e afirmacao respondem um pelo outro.
#
# Formato: uma linha `@ <gate> <suite>` abre um bloco; as linhas seguintes sao as
# relacoes daquele bloco, uma por linha, LITERAIS. Nenhuma relacao pode comecar
# com `@ ` — nenhuma comeca, e a fonte reprova se alguem escrever uma.
readonly SUITES_CONGELADAS="rankingfn:functions-ranking/test/passe.test.js,functions-ranking/test/superficie.test.js"
readonly ALVOS_CONGELADOS="rankingfn:functions-ranking/package.json"

RELACOES_CONGELADAS="$(cat <<'RELACOES_DA_FOLHA'
@ rankingfn functions-ranking/test/passe.test.js
test("PF-01:
SUPERFICIE_IMPLANTADA = {
[...esperados].sort(),
casosDeclaradosEm(GUARDA)
corpoDoCaso(GUARDA, "SF-01")
corpoDoCaso(GUARDA, "SF-02")
GUARDA = "functions-ranking/test/superficie.test.js"
@ rankingfn functions-ranking/test/superficie.test.js
test("SF-01:
test("SF-02:
test("SF-03:
const ALVO_OFICIAL =
casosDeclaradosEm(PASSE).includes("PF-01")
corpoDoCaso(PASSE, "PF-01")
listaLiteral(fonte, codebase, "'")
pkg.scripts.test,
RELACOES_DA_FOLHA
)"
readonly RELACOES_CONGELADAS

# ---------------------------------------------------------------------------
# `CASOS_CONGELADOS` — O CONJUNTO NOMINAL DE `exigenocaso`, POR CASO (OS 40-C4)
# ---------------------------------------------------------------------------
#
# `exigenocaso` existia, era LIDO, e era acumulado em `exigenocaso_do_gate` — e
# ninguem nunca comparava aquele numero com coisa alguma. A rehomologacao OS
# 40-R4 mediu o preco disso no escape `S10`: tirar da fonte a relacao
# `expect(v.aceita, isTrue,` do bloco `ESP-02`, trocar a afirmacao funcional da
# suite por uma trivial e recarimbar os digests permitidos deixava a cadeia
# estatica inteiramente VERDE. A guarda POR CASO — a unica que distingue "o
# titulo e a afirmacao estao no mesmo caso" de "estao em dois casos-isca" —
# podia ser desligada uma linha por vez, sem reprovar nada.
#
# O que fecha isso e o mesmo mecanismo de `RELACOES_CONGELADAS`, um nivel
# abaixo: o conjunto exato, POR SUITE, escrito por extenso e FORA do manifesto
# que ele guarda. A comparacao e de IGUALDADE EXATA, linha a linha e na ordem —
# retirada, renomeacao, duplicacao, reordenacao, troca de caso e troca de suite
# reprovam todas pelo mesmo caminho, cada uma nomeando o que mudou.
#
# `PISOS_EXIGENOCASO`, logo abaixo, e a metade generica: a CARDINALIDADE por
# gate, cobrada mesmo onde ninguem escreveu o conjunto nominal. Sao as duas
# metades da mesma defesa, como `PISOS_EXIGE` e `RELACOES_CONGELADAS`.
#
# Formato: uma linha `& <gate> <suite>` abre um bloco; dentro dele, `@ <caso>`
# abre um caso e as linhas seguintes sao as relacoes daquele caso, LITERAIS. E
# exatamente o acumulado que o leitor monta em `casos_lista`.
CASOS_CONGELADOS="$(cat <<'CASOS_DA_FOLHA'
& comunicacao app/test/comunicacao/comunicacao_test.dart
@ ESP-02
for (final especie in catalogados.entries) {
canal: canalDe(ambiente: mesa.value, modo: modoDe(mesa.value)),
expect(v.aceita, isTrue,
& contratosui scripts/ci/teste_contrato_suites.sh
@ T27
'posterior ao carimbo' "$TMP/res"
@ T42
"$(printf '%s\n' $CONTRATADOS | sort | tr '\n' ' ')"
"$(printf '%s\n' $CONTRATADOS_CONGELADOS | sort | tr '\n' ' ')"
@ T58
rm -f "$W/scripts/ci/testemunha_contratosui.sh"
@ T59
sed -i 's|scripts/ci/testemunha_contratosui.sh|scripts/ci/isca.sh|g' "$W/$YML_W"
CASOS_DA_FOLHA
)"
readonly CASOS_CONGELADOS

# QUANTAS relacoes `exigenocaso` cada gate tem de continuar tendo. A metade
# generica de `CASOS_CONGELADOS`: vale para o gate inteiro, e reprova a retirada
# de uma linha mesmo antes de olhar QUAL linha era.
readonly PISOS_EXIGENOCASO="comunicacao:3 contratosui:5"

readonly CONTA_PADRAO='^[[:blank:]]*(test|testWidgets)\('
readonly CONTADOR_PADRAO='\+[0-9]+'

# A propria invocacao, que o workflow tem de continuar carregando.
readonly INVOCACAO='scripts/ci/verificar_contrato_suites.sh'

falhas=0
erro() {
  printf 'CONTRATO DE SUITE: %s\n' "$*"
  falhas=1
}

piso_de() {
  local tabela="$1" alvo="$2" par
  for par in $tabela; do
    case "$par" in
      "$alvo":*) printf '%s' "${par#*:}"; return 0 ;;
    esac
  done
  printf '%s' ''
}

# Espaco em branco espremido: o YAML alinha `roda <gate>  <caminho>` em colunas,
# e um contrato que dependesse da largura do alinhamento reprovaria na proxima
# vez que alguem alinhasse a tabela.
espremer() {
  printf '%s' "$1" | tr -s '[:blank:]' ' ' | sed -e 's/^ //' -e 's/ $//'
}

if [ ! -f "$fonte" ] || [ ! -r "$fonte" ]; then
  printf 'CONTRATO DE SUITE: fonte unica ausente ou ilegivel em %s\n' "$fonte"
  exit 1
fi

if [ ! -f "$agregador" ] || [ ! -r "$agregador" ]; then
  printf 'CONTRATO DE SUITE: agregador ausente em %s\n' "$agregador"
  exit 1
fi

# A RELACAO DE GATES VEM DO AGREGADOR, nao de um `sed | awk` local. Reimplementar
# a leitura aqui criaria o segundo leitor, e dois leitores sao duas autoridades
# em potencial: foi de duas listas escritas a mao que o CI-02 nasceu.
if ! GATES_DA_FONTE="$(bash "$agregador" --listar "$fonte" 2>&1)"; then
  printf 'CONTRATO DE SUITE: o agregador recusou a fonte unica:\n%s\n' "$GATES_DA_FONTE"
  exit 1
fi

eh_gate() {
  local g
  for g in $GATES_DA_FONTE; do [ "$g" = "$1" ] && return 0; done
  return 1
}

conteudo_workflow=''
workflow_espremido=''
if [ -n "$workflow" ]; then
  if [ ! -f "$workflow" ]; then
    printf 'CONTRATO DE SUITE: workflow ausente em %s\n' "$workflow"
    exit 1
  fi
  conteudo_workflow="$(tr -d '\r' < "$workflow")"
  # Normalizado UMA vez, e comparado depois com casamento de padrao do proprio
  # bash. Um `grep` por entrada custava quatro processos sobre quarenta KB, e
  # esta guarda e chamada trinta e quatro vezes pela matriz que a verifica.
  workflow_espremido=$'\n'"$(printf '%s\n' "$conteudo_workflow" |
    tr -s '[:blank:]' ' ' | sed -e 's/^ //' -e 's/ $//')"$'\n'

  # A AUTORIDADE LEXICA DOS PASSOS ZERO, NO CAMINHO OFICIAL (OS 40-C5)
  # -------------------------------------------------------------------------
  #
  # O casamento por LINHA ESPREMIDA que este verificador faz mais abaixo — o
  # `executor` de cada gate — responde "o texto esta no arquivo". A OS 40-R5
  # mostrou o que essa pergunta nao cobre: a execucao real de
  # `autoridade_verificadores.sh` foi retirada do passo `0a`, `t_autverif.log` e
  # `exit_autverif` foram fabricados por `echo`, e o caminho oficial inteiro
  # ficou VERDE. Uma linha em heredoc satisfaz busca textual; ela nao executa.
  #
  # Quem responde "aquilo RODOU" e `guarda_invocacao_passo_zero`, que classifica
  # o workflow linha a linha. NAO E UMA SEGUNDA COPIA DO ANALISADOR: e o mesmo
  # arquivo, chamado no modo `--guarda`. O segundo chamador existe porque o
  # primeiro e o gate `portaoci`, que mora no passo `0` — quem apaga o passo
  # apaga quem reclamaria dele. Este passo roda sob `bash -e` e derruba o job.
  GUARDA_PASSO_ZERO="$(dirname "$0")/teste_portao_os_integracao.sh"
  if [ ! -s "$GUARDA_PASSO_ZERO" ]; then
    erro "a guarda dos passos zero esta ausente em '$GUARDA_PASSO_ZERO'"
  elif ! bash "$GUARDA_PASSO_ZERO" --guarda "$workflow"; then
    erro "a guarda dos passos zero reprovou o workflow: evidencia obrigatoria sem execucao viva"
  else
    printf 'ok   passo0     a invocacao viva de cada passo zero protegido esta no lugar\n'
  fi
fi

# ---------------------------------------------------------------------------
# FASE A — o contrato, conferido sem executar nada
# ---------------------------------------------------------------------------

contratados=''
com_contrato=0

# ---------------------------------------------------------------------------
# A BUSCA DA AGULHA — codigo executavel, e nao texto que se parece com codigo
# ---------------------------------------------------------------------------
#
# Ate a OS 40-C2 a busca acontecia sobre o arquivo com as LINHAS de comentario
# removidas por expressao regular. A rehomologacao OS 40-R2 mediu o que sobrava:
# comentario de BLOCO, comentario no fim de uma linha de codigo, string, texto de
# template, expressao regular e `reason:` de mensagem continuavam satisfazendo o
# contrato. Bastava mudar a agulha de lugar, recarimbar o `sha256` e trivializar
# a guarda ao lado — e a arvore inteira ficava verde.
#
# Mais expressao regular nao fecha isso, e por um motivo que nao e de esforco:
# uma varredura sem estado nao sabe se um `//` esta dentro de uma string, nem se
# uma aspa esta dentro de um comentario. Quem responde e um LEXER — leitura
# caractere a caractere, com estado —, e ele mora em `codigo_executavel.awk`.
#
# A regra que ele aplica, e a decisao que ela carrega, estao escritas la. Aqui
# fica so o que este script precisa saber: A AGULHA CONTA QUANDO AO MENOS UM
# CARACTERE DA OCORRENCIA E CODIGO. `test("PF-01:` conta porque `test(` e codigo;
# o mesmo texto dentro de outra string nao conta, porque a ocorrencia inteira e
# conteudo de literal.
#
# O NUL sai junto com o CR na entrada do lexer: ha .dart neste repositorio com
# NUL no meio de um literal (a suite da Comunicacao prova a recusa de caractere
# de controle usando o proprio caractere de controle).
# A ASSINATURA NAO PASSA POR AQUI: ela le o arquivo direto, byte a byte.
LEXICO="$(dirname "$0")/codigo_executavel.awk"
if [ ! -s "$LEXICO" ]; then
  printf 'CONTRATO DE SUITE: analisador lexico ausente em %s — a guarda foi desligada\n' "$LEXICO"
  exit 1
fi

AGULHAS="$(mktemp)" || {
  printf 'CONTRATO DE SUITE: nao ha diretorio temporario para a lista de agulhas\n'
  exit 1
}
AG_A="$AGULHAS.a"
AG_B="$AGULHAS.b"
AG_OUT="$AGULHAS.out"
trap 'rm -f "$AGULHAS" "$AG_A" "$AG_B" "$AG_OUT"' EXIT

# A LINGUAGEM VEM DA EXTENSAO, e uma extensao desconhecida REPROVA. Adivinhar
# "deve ser codigo" seria a porta de saida: bastaria renomear a suite para uma
# extensao que o lexer nao conhece e a agulha voltaria a valer em qualquer lugar.
# Devolve em `LINGUA` — sem substituicao de comando, que e um fork por chamada.
lingua_de() {
  case "$1" in
    *.js | *.mjs | *.cjs | *.ts) LINGUA='js' ;;
    *.dart) LINGUA='dart' ;;
    *.sh | *.bash) LINGUA='sh' ;;
    *.json) LINGUA='json' ;;
    *) LINGUA='' ;;
  esac
}

# `analisar <arquivo> <lista>` — o veredito do lexer, uma linha por resposta.
#
# `CONTA_ERE` vai pelo AMBIENTE, e nao por `-v`: o `awk` interpreta sequencias de
# escape no valor de `-v`, e o `\(` do contador padrao viraria abre-parentese de
# grupo — a contagem passaria a medir outra coisa, em silencio.
analisar() {
  lingua_de "$1"
  if [ -z "$LINGUA" ]; then
    printf 'SEMLINGUA\t%s\n' "$1"
    return 0
  fi
  tr -d '\r\000' < "$1" | awk -v ling="$LINGUA" -v agulhas="$2" -f "$LEXICO"
}

# `conferir_agulhas <arquivo> <lista> <onde> [ere-de-contagem]` — reprova, e diz
# por que. Devolve QUANTAS agulhas falharam, e deixa em `PROVAS_REAIS` a
# contagem de declaracoes que a mesma leitura apurou.
#
# `<onde>` ja traz a preposicao ("de 'app/...'", "do alvo '...'"): as mensagens
# desta guarda sao lidas por uma matriz de casos, e trocar a frase e trocar o que
# aquela matriz mede.
#
# O laco le de um ARQUIVO, e nao de um cano nem de uma substituicao de comando:
# `erro` incrementa `falhas`, e um subshell levaria o incremento embora — o modo
# mais silencioso de um verificador inteiro deixar de reprovar.
conferir_agulhas() {
  local arq="$1" lista="$2" onde="$3" ere="${4:-}" tipo agulha faltou=0
  PROVAS_REAIS=0
  CONTA_ERE="$ere" analisar "$arq" "$lista" > "$AG_OUT"
  while IFS=$'\t' read -r tipo agulha; do
    case "$tipo" in
      '') continue ;;
      PROVAS) PROVAS_REAIS="$agulha"; continue ;;
      AUSENTE) erro "o bloco $agulha sumiu $onde" ;;
      INERTE) erro "o bloco $agulha aparece $onde SO como comentario, string, template ou regex — e texto, e nao codigo executavel" ;;
      SEMCODIGO) erro "a analise lexica nao achou uma linha de codigo $onde — o arquivo inteiro e texto inerte" ;;
      ABERTO) erro "a leitura $onde termina dentro de $agulha — codigo aberto, e ausencia nao pode virar verde" ;;
      SEMLINGUA) erro "o verificador nao sabe ler $onde: extensao fora de .js/.ts/.dart/.sh/.json" ;;
      *) erro "resposta desconhecida do analisador lexico $onde: '$tipo'" ;;
    esac
    faltou=$((faltou + 1))
  done < "$AG_OUT"
  return "$faltou"
}

# `relacoes_de <gate> <suite>` — o conjunto congelado daquele par, devolvido em
# `RELACOES_DA_SUITE`. So expansao de parametro, sem `awk` por chamada: esta
# guarda e chamada dezesseis vezes por execucao, e a matriz de
# `teste_contrato_suites.sh` a executa cinquenta e sete vezes.
relacoes_de() {
  local todo=$'\n'"$RELACOES_CONGELADAS" marca=$'\n'"@ $1 $2"$'\n'
  RELACOES_DA_SUITE=''
  case "$todo" in
    *"$marca"*) ;;
    *) return 0 ;;
  esac
  RELACOES_DA_SUITE="${todo#*"$marca"}"
  case "$RELACOES_DA_SUITE" in
    *$'\n@ '*) RELACOES_DA_SUITE="${RELACOES_DA_SUITE%%$'\n@ '*}" ;;
  esac
  RELACOES_DA_SUITE="${RELACOES_DA_SUITE%$'\n'}"
}

# `gate_congelado <gate>` — o gate tem conjunto nominal escrito aqui?
gate_congelado() {
  case $'\n'"$RELACOES_CONGELADAS" in
    *$'\n'"@ $1 "*) return 0 ;;
  esac
  return 1
}

# `casos_congelados_de <gate> <suite>` — o bloco `@ caso`/relacoes daquele par,
# devolvido em `CASOS_DA_SUITE_CONGELADOS`. Mesma mecanica de `relacoes_de`, um
# nivel abaixo, e pela mesma razao: so expansao de parametro, sem um `awk` por
# chamada.
casos_congelados_de() {
  local todo=$'\n'"$CASOS_CONGELADOS" marca=$'\n'"& $1 $2"$'\n'
  CASOS_DA_SUITE_CONGELADOS=''
  case "$todo" in
    *"$marca"*) ;;
    *) return 0 ;;
  esac
  CASOS_DA_SUITE_CONGELADOS="${todo#*"$marca"}"
  case "$CASOS_DA_SUITE_CONGELADOS" in
    *$'\n& '*) CASOS_DA_SUITE_CONGELADOS="${CASOS_DA_SUITE_CONGELADOS%%$'\n& '*}" ;;
  esac
  CASOS_DA_SUITE_CONGELADOS="${CASOS_DA_SUITE_CONGELADOS%$'\n'}"
}

# `suite_com_casos_congelados <gate> <suite>` — este par tem bloco escrito aqui?
#
# Existe para separar as duas recusas: "a suite perdeu os casos que ela tinha" e
# "a fonte inventou casos que ninguem decidiu". Sem a distincao, acrescentar um
# `caso` novo numa suite qualquer passaria despercebido.
suite_com_casos_congelados() {
  case $'\n'"$CASOS_CONGELADOS" in
    *$'\n'"& $1 $2"$'\n'*) return 0 ;;
  esac
  return 1
}

# `contar <texto>` — linhas nao vazias, devolvidas em `QUANTAS`. Mesma razao.
contar() {
  local l
  QUANTAS=0
  while IFS= read -r l; do
    [ -n "$l" ] && QUANTAS=$((QUANTAS + 1))
  done <<CONTAGEM
$1
CONTAGEM
# `conferir_caso <arquivo> <id> <bloco>` — as exigencias que tem de morar DENTRO
# do corpo daquele caso.
#
# Existe porque busca plana nao distingue "o titulo e a afirmacao estao no mesmo
# caso" de "estao em dois casos-isca". A OS 40-R3 mediu a diferenca: `ESP-02`
# apagado, a redacao dele emprestada por um literal morto e um caso-isca
# conservando a contagem deixavam a FASE A inteiramente verde.
#
# E o `SEMCASO` e a metade que fecha a outra ponta: o corpo so existe se houver
# uma CHAMADA de abertura, em codigo, cujo primeiro literal traga o
# identificador. Titulo em comentario, em string ou em lista morta nao declara
# caso nenhum.
conferir_caso() {
  local arq="$1" id="$2" bloco="$3" tipo agulha faltou=0
  [ -z "$id" ] && return 0
  printf '%s' "$bloco" > "$AGULHAS"
  CASO="$id" analisar "$arq" "$AGULHAS" > "$AG_OUT"
  while IFS=$'\t' read -r tipo agulha; do
    case "$tipo" in
      '' | PROVAS) continue ;;
      SEMCASO) erro "o caso $agulha nao e DECLARADO EM CODIGO em '$suite' (gate $chave) — titulo em comentario, string ou literal morto nao declara caso" ;;
      AUSENTE) erro "a afirmacao $agulha sumiu do CORPO do caso $id em '$suite' (gate $chave)" ;;
      INERTE) erro "a afirmacao $agulha aparece no corpo do caso $id em '$suite' (gate $chave) SO como comentario, string, template ou regex" ;;
      ABERTO) erro "a leitura de '$suite' (gate $chave) termina dentro de $agulha" ;;
      SEMLINGUA) erro "o verificador nao sabe ler '$suite' (gate $chave)" ;;
      *) erro "resposta desconhecida do analisador lexico no caso $id: '$tipo'" ;;
    esac
    faltou=$((faltou + 1))
  done < "$AG_OUT"
  if [ "$faltou" -eq 0 ]; then
    contar "$bloco"
    printf 'ok   caso       %-12s %s com %s afirmacao(oes) no corpo\n' "$chave" "$id" "$QUANTAS"
  fi
  casos_do_gate="$casos_do_gate $id"
  contar "$bloco"
  exigenocaso_do_gate=$((exigenocaso_do_gate + QUANTAS))
}

# `percorrer_casos <arquivo>` — le o acumulado `@ <id>` / afirmacoes da suite.
percorrer_casos() {
  local arq="$1" ln id_atual='' bloco=''
  [ -z "$casos_lista" ] && return 0
  while IFS= read -r ln; do
    case "$ln" in
      '@ '*)
        conferir_caso "$arq" "$id_atual" "$bloco"
        id_atual="${ln#@ }"
        bloco=''
        ;;
      '') continue ;;
      *) bloco="$bloco$ln
" ;;
    esac
  done <<CASOS_DA_SUITE
$casos_lista
CASOS_DA_SUITE
  conferir_caso "$arq" "$id_atual" "$bloco"
}
}

# `conferir_suite` — o bloco de UMA suite, fechado.
#
# So o que depende do proprio arquivo mora aqui. O que depende de atributo do
# GATE (`executor`, `alvo`) e conferido no fim da entrada, sobre a relacao de
# caminhos acumulada — assim a ordem em que os atributos aparecem na fonte deixa
# de importar, e os contratos que ja existiam, que declaram `executor` DEPOIS de
# `suite`, continuam valendo palavra por palavra.
conferir_suite() {
  [ "$suite_aberta" -eq 0 ] && return 0
  suite_aberta=0
  suites_do_gate=$((suites_do_gate + 1))

  local arquivo=''
  if [ -z "$suite" ]; then
    erro "a entrada '$chave' nao declara 'suite'"
  else
    caminhos_do_gate="$caminhos_do_gate $suite"
    arquivo="$raiz/$suite"
    if [ -f "$arquivo" ]; then
      printf 'ok   arquivo    %-12s %s\n' "$chave" "$suite"
    else
      erro "suite removida ou renomeada: '$suite' (gate $chave)"
      arquivo=''
    fi
  fi

  # As validacoes de formato sao casamento de padrao do proprio bash, e nao um
  # `printf | grep` por atributo. Nao e microotimizacao: sao quatro processos por
  # suite, dezesseis suites por execucao e cinquenta e sete execucoes na matriz
  # que confere esta guarda — e uma bancada que leva meia hora e uma bancada que
  # ninguem roda antes de commitar.
  if [ -z "$sha_esperado" ]; then
    erro "a entrada '$chave' nao declara 'sha256'"
  elif [ "${#sha_esperado}" -ne 64 ] || [ -z "${sha_esperado##*[!0-9a-f]*}" ]; then
    erro "o 'sha256' de '$chave' nao e um digest de 64 hex: '$sha_esperado'"
    sha_esperado=''
  fi
  if [ -z "$provas_esperadas" ]; then
    erro "a entrada '$chave' nao declara 'provas'"
  elif [ -z "${provas_esperadas##*[!0-9]*}" ]; then
    erro "o 'provas' de '$chave' nao e um numero: '$provas_esperadas'"
    provas_esperadas=''
  else
    provas_do_gate=$((provas_do_gate + provas_esperadas))
  fi
  if [ -z "$exige_lista" ]; then
    erro "a entrada '$chave' nao declara nenhum 'exige'"
  fi
  contar "$exige_lista"
  exige_do_gate=$((exige_do_gate + QUANTAS))

  # ---- o conjunto NOMINAL, congelado fora do bloco que ele guarda ---------
  #
  # Roda ANTES de olhar o arquivo, e roda mesmo com a suite ausente: uma relacao
  # adulterada nao pode ficar escondida atras de um arquivo que sumiu.
  #
  # Igualdade EXATA, na ordem. Retirada, renomeacao, duplicacao para conservar a
  # quantidade, reordenacao e troca de uma exigencia entre as duas suites do gate
  # reprovam todas aqui, e a mensagem diz qual das cinco foi.
  if gate_congelado "$chave"; then
    local congeladas n_falta n_extra n_dec n_cong
    relacoes_de "$chave" "$suite"
    congeladas="$RELACOES_DA_SUITE"
    if [ -z "$congeladas" ]; then
      erro "a suite '$suite' (gate $chave) nao esta na relacao congelada — suite trocada, renomeada ou acrescentada sem decisao"
    elif [ "$exige_lista" = "$congeladas" ]; then
      contar "$congeladas"
      printf 'ok   relacoes   %-12s %s nominal(is)  %s\n' "$chave" \
        "$QUANTAS" "$suite"
    else
      printf '%s\n' "$congeladas" > "$AG_A"
      printf '%s\n' "$exige_lista" > "$AG_B"
      contar "$congeladas"; n_cong=$QUANTAS
      contar "$exige_lista"; n_dec=$QUANTAS
      erro "as relacoes 'exige' de '$suite' (gate $chave) nao sao as congeladas"
      n_falta=0
      while IFS= read -r sumida; do
        [ -z "$sumida" ] && continue
        erro "  a relacao congelada sumiu da fonte: $sumida"
        n_falta=$((n_falta + 1))
      done <<RELACOES_QUE_SUMIRAM
$(grep -Fxv -f "$AG_B" "$AG_A")
RELACOES_QUE_SUMIRAM
      n_extra=0
      while IFS= read -r extra; do
        [ -z "$extra" ] && continue
        erro "  a fonte declara uma relacao que nao esta congelada: $extra"
        n_extra=$((n_extra + 1))
      done <<RELACOES_INVENTADAS
$(grep -Fxv -f "$AG_A" "$AG_B")
RELACOES_INVENTADAS
      if [ "$n_falta" -eq 0 ] && [ "$n_extra" -eq 0 ]; then
        if [ "$n_dec" -ne "$n_cong" ]; then
          erro "  a cardinalidade mudou: $n_dec declarada(s) contra $n_cong congelada(s) — relacao duplicada"
        else
          erro "  mesmos literais e mesma cardinalidade: a ORDEM das relacoes mudou"
        fi
      fi
    fi
  fi

  # ---- o conjunto NOMINAL DE `exigenocaso`, por caso (OS 40-C4) -----------
  #
  # Mesma mecanica do bloco acima, um nivel abaixo, e pela mesma razao: sem ele,
  # `exigenocaso` era acumulado e nunca comparado com nada — e era possivel
  # tirar uma relacao POR CASO, trivializar a afirmacao correspondente na suite,
  # recarimbar o digest e conservar a cadeia estatica inteira verde. E o escape
  # `S10` da OS 40-R4.
  #
  # Roda ANTES de olhar o arquivo, e roda mesmo com a suite ausente: uma relacao
  # de caso adulterada nao pode ficar escondida atras de um arquivo que sumiu.
  local casos_declarados="${casos_lista%$'\n'}"
  if suite_com_casos_congelados "$chave" "$suite"; then
    local casos_cong n_falta_c n_extra_c n_dec_c n_cong_c
    casos_congelados_de "$chave" "$suite"
    casos_cong="$CASOS_DA_SUITE_CONGELADOS"
    if [ "$casos_declarados" = "$casos_cong" ]; then
      contar "$casos_cong"
      printf 'ok   exigenocaso %-11s %s linha(s) nominal(is)  %s\n' "$chave" \
        "$QUANTAS" "$suite"
    else
      printf '%s\n' "$casos_cong" > "$AG_A"
      printf '%s\n' "$casos_declarados" > "$AG_B"
      contar "$casos_cong"; n_cong_c=$QUANTAS
      contar "$casos_declarados"; n_dec_c=$QUANTAS
      erro "as relacoes por caso de '$suite' (gate $chave) nao sao as congeladas"
      n_falta_c=0
      while IFS= read -r sumida_c; do
        [ -z "$sumida_c" ] && continue
        erro "  a linha congelada de 'caso'/'exigenocaso' sumiu da fonte: $sumida_c"
        n_falta_c=$((n_falta_c + 1))
      done <<CASOS_QUE_SUMIRAM
$(grep -Fxv -f "$AG_B" "$AG_A")
CASOS_QUE_SUMIRAM
      n_extra_c=0
      while IFS= read -r extra_c; do
        [ -z "$extra_c" ] && continue
        erro "  a fonte declara uma linha de caso que nao esta congelada: $extra_c"
        n_extra_c=$((n_extra_c + 1))
      done <<CASOS_INVENTADOS
$(grep -Fxv -f "$AG_A" "$AG_B")
CASOS_INVENTADOS
      if [ "$n_falta_c" -eq 0 ] && [ "$n_extra_c" -eq 0 ]; then
        if [ "$n_dec_c" -ne "$n_cong_c" ]; then
          erro "  a cardinalidade por caso mudou: $n_dec_c declarada(s) contra $n_cong_c congelada(s) — relacao duplicada"
        else
          erro "  mesmos literais e mesma cardinalidade: a ORDEM ou o CASO de destino mudou"
        fi
      fi
    fi
  elif [ -n "$casos_declarados" ]; then
    erro "a suite '$suite' (gate $chave) declara 'caso'/'exigenocaso' e NAO esta no conjunto congelado — relacao por caso acrescentada, movida de suite ou renomeada sem decisao"
  fi

  [ -z "$arquivo" ] && return 0

  local sha_real
  sha_real="$(tr -d '\r' < "$arquivo" | sha256sum)"
  sha_real="${sha_real%% *}"
  if [ -n "$sha_esperado" ]; then
    if [ "$sha_real" = "$sha_esperado" ]; then
      printf 'ok   assinatura %-12s %s...\n' "$chave" "${sha_real:0:16}"
    else
      erro "o conteudo de '$suite' (gate $chave) mudou e a assinatura nao."
      erro "  esperado $sha_esperado"
      erro "  no disco $sha_real"
      erro "  se a mudanca e legitima, atualize 'sha256' na fonte NO MESMO commit"
    fi
  fi

  # UMA leitura do arquivo responde as duas perguntas: quantas declaracoes ele
  # ainda tem, e se cada agulha do contrato esta em codigo executavel. Eram duas
  # varreduras, e o arquivo e o mesmo.
  local faltando=0
  printf '%s\n' "$exige_lista" > "$AGULHAS"
  conferir_agulhas "$arquivo" "$AGULHAS" "de '$suite' (gate $chave)" "${conta_ere:-$CONTA_PADRAO}"
  faltando=$?

  if [ -n "$provas_esperadas" ]; then
    if [ "$PROVAS_REAIS" -ge "$provas_esperadas" ]; then
      printf 'ok   provas     %-12s %s >= %s\n' "$chave" "$PROVAS_REAIS" "$provas_esperadas"
    else
      erro "'$suite' (gate $chave) tem $PROVAS_REAIS declaracoes e o piso e $provas_esperadas"
    fi
  fi

  # ---- as exigencias POR CASO, dentro do corpo de cada uma ---------------
  percorrer_casos "$arquivo"

  contar "$exige_lista"
  if [ "$faltando" -eq 0 ] && [ -n "$exige_lista" ]; then
    printf 'ok   blocos     %-12s %s em codigo executavel\n' "$chave" \
      "$QUANTAS"
  fi
}

conferir_entrada() {
  [ -z "$chave" ] && return 0
  if [ "$suite_aberta" -eq 0 ] &&
     [ -z "$executor$casos_esperados$contador_ere$alvo$exigealvo_lista" ]; then
    return 0
  fi

  com_contrato=$((com_contrato + 1))
  contratados="$contratados $chave"

  if ! eh_gate "$chave"; then
    erro "'$chave' tem contrato e NAO e um gate obrigatorio da fonte unica"
  fi

  # ---- as suites (a ultima ainda esta aberta) ----------------------------
  conferir_suite
  if [ "$suites_do_gate" -eq 0 ]; then
    erro "a entrada '$chave' nao declara 'suite'"
  fi

  # ---- a outra ponta da reciprocidade: QUAIS suites, e QUAL alvo ---------
  #
  # `RELACOES_CONGELADAS` congela as afirmacoes POR SUITE. Sozinho isso teria um
  # jeito de morrer calado: renomear a suite na fonte faria o conjunto daquela
  # suite deixar de casar com qualquer bloco — e um conjunto que nao casa com
  # nada nao reprova nada. Aqui se fecha o triangulo: alvo, suite e afirmacao
  # respondem um pelo outro, e nenhum dos tres pode mudar sozinho.
  local congelado
  congelado="$(piso_de "$SUITES_CONGELADAS" "$chave")"
  if [ -n "$congelado" ]; then
    local declaradas
    declaradas="$(espremer "$caminhos_do_gate")"
    declaradas="${declaradas// /,}"
    if [ "$declaradas" = "$congelado" ]; then
      printf 'ok   suites     %-12s %s\n' "$chave" "$congelado"
    else
      erro "as suites de '$chave' nao sao as congeladas"
      erro "  congeladas $congelado"
      erro "  na fonte   ${declaradas:-(nenhuma)}"
    fi
  fi
  congelado="$(piso_de "$ALVOS_CONGELADOS" "$chave")"
  if [ -n "$congelado" ] && [ "$alvo" != "$congelado" ]; then
    erro "o 'alvo' de '$chave' nao e o congelado: '${alvo:-(nenhum)}' em vez de '$congelado'"
  fi

  # ---- o executor --------------------------------------------------------
  if [ -z "$executor" ]; then
    erro "a entrada '$chave' nao declara 'executor'"
  elif [ -z "$alvo" ]; then
    # O executor tem de apontar para a suite que ele diz rodar. Sem isto, o
    # contrato aceitaria um passo que roda outra coisa: produtor sem alvo, que e
    # o degrau seguinte ao gate fantasma.
    #
    # COM `alvo`, este elo muda de lugar e nao some: quem nomeia a suite passa a
    # ser o alvo, e o executor e cobrado de citar o alvo. Ver o bloco `alvo`,
    # logo abaixo.
    local citada
    for citada in $caminhos_do_gate; do
      local rel="${citada#app/}"
      case "$executor" in
        *"$rel"*) ;;
        *) erro "o 'executor' de '$chave' nao cita a suite '$rel'" ;;
      esac
    done
  fi

  # ---- o alvo: o executor roda o codebase, e o codebase roda as suites ---
  if [ -z "$alvo" ] && [ -n "$exigealvo_lista" ]; then
    erro "a entrada '$chave' tem 'exigealvo' e nao declara 'alvo'"
  fi
  if [ -n "$alvo" ]; then
    if [ -z "$exigealvo_lista" ]; then
      erro "a entrada '$chave' declara 'alvo' e nenhum 'exigealvo' — alvo sem congelamento"
    fi
    local arq_alvo="$raiz/$alvo"
    if [ ! -f "$arq_alvo" ]; then
      erro "o 'alvo' de '$chave' nao existe: '$alvo'"
    else
      local dir_alvo="${alvo%/*}"
      [ "$dir_alvo" = "$alvo" ] && dir_alvo='.'

      if [ -n "$executor" ]; then
        case "$executor" in
          *"$dir_alvo"*)
            printf 'ok   alvo       %-12s %s (rodado por %s)\n' "$chave" "$alvo" "$dir_alvo"
            ;;
          *) erro "o 'executor' de '$chave' nao cita o alvo '$dir_alvo'" ;;
        esac
      fi

      local caminho rel_alvo faltando_alvo=0

      # CADA suite declarada tem de estar NOMEADA no alvo. E aqui que "a suite
      # saiu do comando oficial" vira vermelho — e o gate continuaria verde se
      # esta linha nao existisse, porque uma suite que nao roda nao reclama.
      #
      # A leitura do alvo tambem passa pelo lexer, em modo `json`: la NADA e
      # inerte, exceto o par de chave de comentario `"//...": ...` — que e como
      # este repositorio documenta `scripts`. Repetir o caminho de uma suite numa
      # chave de prosa continua nao substituindo roda-la, e agora quem sabe disso
      # e um leitor com estado, e nao um casamento de linha.
      local no_alvo t a
      for caminho in $caminhos_do_gate; do
        rel_alvo="${caminho#"$dir_alvo"/}"
        printf '%s\n' "$rel_alvo" > "$AGULHAS"
        analisar "$arq_alvo" "$AGULHAS" > "$AG_OUT"
        no_alvo=1
        while IFS=$'\t' read -r t a; do
          case "$t" in '' | PROVAS) continue ;; esac
          no_alvo=0
        done < "$AG_OUT"
        if [ "$no_alvo" -eq 1 ]; then
          printf 'ok   no alvo    %-12s %s\n' "$chave" "$rel_alvo"
        else
          erro "o alvo '$alvo' nao roda a suite '$rel_alvo' (gate $chave)"
        fi
      done

      printf '%s\n' "$exigealvo_lista" > "$AGULHAS"
      conferir_agulhas "$arq_alvo" "$AGULHAS" "do alvo '$alvo' (gate $chave)"
      faltando_alvo=$?
      contar "$exigealvo_lista"
      if [ "$faltando_alvo" -eq 0 ] && [ -n "$exigealvo_lista" ]; then
        printf 'ok   comando    %-12s %s literal(is) no alvo\n' "$chave" \
          "$QUANTAS"
      fi
    fi
  fi

  if [ -n "$conteudo_workflow" ] && [ -n "$executor" ]; then
    local alvo_esp
    alvo_esp="$(espremer "$executor")"
    case "$workflow_espremido" in
      *$'\n'"$alvo_esp"$'\n'*)
        printf 'ok   executor   %-12s %s\n' "$chave" "$alvo_esp"
        ;;
      *) erro "o workflow nao tem a linha do executor de '$chave': '$alvo_esp'" ;;
    esac

    # O marcador pode ser escrito LITERALMENTE (`echo ... > exit_proveni`) ou
    # pelo auxiliar `roda`, que o monta como "exit_$k". Aceitar so a forma
    # literal reprovaria toda suite Flutter do workflow — e reprovar por engano
    # e a pressao que leva alguem a afrouxar a guarda.
    case "$conteudo_workflow$workflow_espremido" in
      *"exit_$chave"* | *$'\n'"roda $chave "*)
        printf 'ok   marcador   %-12s exit_%s\n' "$chave" "$chave"
        ;;
      *) erro "o workflow nao produz 'exit_$chave' — gate declarado sem produtor" ;;
    esac
  fi

  # ---- os pisos escritos AQUI nao podem ser rebaixados na fonte ----------
  #
  # Sobre a SOMA das `provas` das suites do gate: um gate de uma suite so — que
  # e o caso de todos menos `rankingfn` — se comporta exatamente como antes.
  local piso
  piso="$(piso_de "$PISOS_EXIGE" "$chave")"
  if [ -n "$piso" ]; then
    if [ "$exige_do_gate" -lt "$piso" ]; then
      erro "o piso de relacoes de conteudo de '$chave' caiu de $piso para $exige_do_gate na fonte"
    else
      printf 'ok   piso       %-12s exige %s >= %s\n' "$chave" "$exige_do_gate" "$piso"
    fi
  fi
  # `exigenocaso` tem piso PROPRIO, e nao herda o de `exige`. Sao vocabularios
  # diferentes: `exige` cobra o arquivo inteiro, `exigenocaso` cobra o CORPO de
  # um caso nomeado. Ate a OS 40-C4 o segundo era acumulado e nunca comparado —
  # o piso de `exige` continuava satisfeito enquanto a guarda por caso era
  # desmontada linha a linha.
  piso="$(piso_de "$PISOS_EXIGENOCASO" "$chave")"
  if [ -n "$piso" ]; then
    if [ "$exigenocaso_do_gate" -lt "$piso" ]; then
      erro "o piso de relacoes POR CASO de '$chave' caiu de $piso para $exigenocaso_do_gate na fonte"
    else
      printf 'ok   piso       %-12s exigenocaso %s >= %s\n' "$chave" "$exigenocaso_do_gate" "$piso"
    fi
  fi
  piso="$(piso_de "$PISOS_PROVAS" "$chave")"
  if [ -n "$piso" ]; then
    if [ "$provas_do_gate" -lt "$piso" ]; then
      erro "o piso de provas de '$chave' foi baixado de $piso para $provas_do_gate na fonte"
    else
      printf 'ok   piso       %-12s provas %s >= %s\n' "$chave" "$provas_do_gate" "$piso"
    fi
  fi
  piso="$(piso_de "$PISOS_CASOS" "$chave")"
  if [ -n "$piso" ]; then
    if [ -z "$casos_esperados" ]; then
      erro "a entrada '$chave' deixou de declarar 'casos' (piso $piso)"
    elif ! printf '%s' "$casos_esperados" | grep -Eq '^[0-9]+$'; then
      erro "o 'casos' de '$chave' nao e um numero: '$casos_esperados'"
      casos_esperados=''
    elif [ "$casos_esperados" -lt "$piso" ]; then
      erro "o piso de casos de '$chave' foi baixado de $piso para $casos_esperados na fonte"
    else
      printf 'ok   piso       %-12s casos %s >= %s\n' "$chave" "$casos_esperados" "$piso"
    fi
  fi

  # ---- FASE B — o log da execucao ---------------------------------------
  [ -z "$dir_resultados" ] && return 0

  local log="$dir_resultados/t_$chave.log"
  if [ ! -s "$log" ]; then
    erro "o gate '$chave' nao deixou log ('$log' ausente ou vazio) — marcador sem execucao"
    return 0
  fi

  local carimbo="$dir_resultados/carimbo_execucao"
  if [ ! -f "$carimbo" ]; then
    erro "carimbo de execucao ausente em '$carimbo' — sem ele nao ha como datar a evidencia"
  elif [ "$carimbo" -nt "$log" ]; then
    erro "o log de '$chave' e ANTERIOR ao carimbo deste run: evidencia de outra execucao"
  else
    printf 'ok   log        %-12s posterior ao carimbo\n' "$chave"
  fi

  if [ -n "$casos_esperados" ]; then
    local ere_contador maior n
    ere_contador="${contador_ere:-$CONTADOR_PADRAO}"
    maior=0
    for n in $(grep -aoE "$ere_contador" "$log" | grep -oE '[0-9]+'); do
      [ "$n" -gt "$maior" ] && maior="$n"
    done
    if [ "$maior" -ge "$casos_esperados" ]; then
      printf 'ok   casos      %-12s %s >= %s (no log)\n' "$chave" "$maior" "$casos_esperados"
    else
      erro "'$chave' executou $maior caso(s) e o piso e $casos_esperados — a suite encolheu"
    fi
  fi
}

chave=''
suite=''
executor=''
sha_esperado=''
provas_esperadas=''
casos_esperados=''
conta_ere=''
casos_lista=''
caso_aberto=0
casos_do_gate=''
exigenocaso_do_gate=0
contador_ere=''
exige_lista=''
alvo=''
exigealvo_lista=''
suite_aberta=0
suites_do_gate=0
provas_do_gate=0
caminhos_do_gate=''
exige_do_gate=0

# `abrir_suite` — comeca um bloco de suite, fechando o anterior se houver.
#
# O bloco tambem abre SOZINHO no primeiro atributo de suite que chegar sem
# `suite` declarada. Sem isso, uma fonte que perdesse todas as linhas `suite`
# reprovaria com "atributo antes de qualquer suite" — uma mensagem que fala do
# LEITOR, e nao do contrato. Assim ela continua reprovando por onde de fato
# falhou: "a entrada nao declara 'suite'".
abrir_suite() {
  conferir_suite
  suite_aberta=1
  suite=''
  sha_esperado=''
  provas_esperadas=''
  conta_ere=''
  casos_lista=''
  caso_aberto=0
  exige_lista=''
}

# A leitura e feita SO com expansao de parametro, sem `sed`/`awk`/`tr` por
# linha. Nao e microotimizacao: a versao com um pipe por linha custava ~800
# processos por execucao, e esta guarda e chamada trinta e quatro vezes pela
# propria matriz de `teste_contrato_suites.sh` — uma bancada que leva vinte
# minutos e uma bancada que ninguem roda antes de commitar.
while IFS= read -r bruta || [ -n "$bruta" ]; do
  linha="${bruta//$'\r'/}"
  nu="${linha#"${linha%%[![:blank:]]*}"}"
  case "$nu" in
    '' | '#'*) continue ;;
  esac

  case "$linha" in
    [[:blank:]]*)
      if [ -z "$chave" ]; then
        erro "atributo de contrato antes de qualquer gate: '$linha'"
        continue
      fi
      nome="${nu%%[[:blank:]]*}"
      valor="${nu#"$nome"}"
      valor="${valor#"${valor%%[![:blank:]]*}"}"
      valor="${valor%"${valor##*[![:blank:]]}"}"
      if [ -z "$valor" ]; then
        erro "atributo '$nome' sem valor no contrato de '$chave'"
        continue
      fi
      case "$nome" in
        suite)
          # REPETIVEL: uma segunda `suite` fecha o bloco anterior e abre outro.
          abrir_suite
          suite="$valor"
          ;;
        executor)
          [ -n "$executor" ] && erro "'executor' repetido em '$chave'"
          executor="$valor"
          ;;
        sha256)
          [ "$suite_aberta" -eq 0 ] && abrir_suite
          [ -n "$sha_esperado" ] && erro "'sha256' repetido em '$chave'"
          sha_esperado="$valor"
          ;;
        provas)
          [ "$suite_aberta" -eq 0 ] && abrir_suite
          [ -n "$provas_esperadas" ] && erro "'provas' repetido em '$chave'"
          provas_esperadas="$valor"
          ;;
        casos)
          [ -n "$casos_esperados" ] && erro "'casos' repetido em '$chave'"
          casos_esperados="$valor"
          ;;
        conta)
          [ "$suite_aberta" -eq 0 ] && abrir_suite
          [ -n "$conta_ere" ] && erro "'conta' repetido em '$chave'"
          conta_ere="$valor"
          ;;
        contador)
          [ -n "$contador_ere" ] && erro "'contador' repetido em '$chave'"
          contador_ere="$valor"
          ;;
        exige)
          [ "$suite_aberta" -eq 0 ] && abrir_suite
          if [ -z "$exige_lista" ]; then
            exige_lista="$valor"
          else
            exige_lista="$exige_lista
$valor"
          fi
          ;;
        # `caso` abre um escopo, e `exigenocaso` pertence ao caso aberto acima
        # dele — mesma gramatica de `suite`/`exige`, um nivel abaixo.
        caso)
          [ "$suite_aberta" -eq 0 ] && abrir_suite
          casos_lista="$casos_lista@ $valor
"
          caso_aberto=1
          ;;
        exigenocaso)
          [ "$suite_aberta" -eq 0 ] && abrir_suite
          if [ "$caso_aberto" -eq 0 ]; then
            erro "'exigenocaso' antes de qualquer 'caso' no contrato de '$chave'"
          else
            casos_lista="$casos_lista$valor
"
          fi
          ;;
        alvo)
          [ -n "$alvo" ] && erro "'alvo' repetido em '$chave'"
          alvo="$valor"
          ;;
        exigealvo)
          if [ -z "$exigealvo_lista" ]; then
            exigealvo_lista="$valor"
          else
            exigealvo_lista="$exigealvo_lista
$valor"
          fi
          ;;
        *) erro "atributo desconhecido '$nome' no contrato de '$chave'" ;;
      esac
      continue
      ;;
  esac

  conferir_entrada

  chave="$nu"
  suite=''
  executor=''
  sha_esperado=''
  provas_esperadas=''
  casos_esperados=''
  conta_ere=''
  casos_lista=''
  caso_aberto=0
  contador_ere=''
  exige_lista=''
  alvo=''
  exigealvo_lista=''
  suite_aberta=0
  suites_do_gate=0
  provas_do_gate=0
  caminhos_do_gate=''
  casos_do_gate=''
  exigenocaso_do_gate=0
  exige_do_gate=0
done < "$fonte"

conferir_entrada

# ---------------------------------------------------------------------------
# O contrato nao pode encolher ate zero, nem perder as chaves minimas
# ---------------------------------------------------------------------------

if [ "$com_contrato" -eq 0 ]; then
  erro "nenhum gate da fonte unica carrega contrato — a protecao de conteudo foi esvaziada"
fi

for k in $CONTRATOS_MINIMOS; do
  achou=0
  for c in $contratados; do
    [ "$c" = "$k" ] && achou=1
  done
  if [ "$achou" -eq 0 ]; then
    erro "o gate '$k' perdeu o contrato de conteudo na fonte unica"
  fi
done

# ---------------------------------------------------------------------------
# A propria invocacao continua no workflow
# ---------------------------------------------------------------------------

if [ -n "$conteudo_workflow" ]; then
  if printf '%s\n' "$conteudo_workflow" | grep -Fq -- "$INVOCACAO"; then
    printf 'ok   invocacao  %-12s %s\n' '(este)' "$INVOCACAO"
  else
    erro "o workflow nao invoca mais '$INVOCACAO' — a guarda foi desligada"
  fi
fi

if [ "$falhas" -eq 0 ]; then
  printf 'contrato de suites: %d conferido(s), tudo no lugar\n' "$com_contrato"
else
  printf 'contrato de suites: REPROVADO\n'
fi

exit "$falhas"
