#!/usr/bin/env bash
#
# AUTORIDADE EXTERNA DOS VERIFICADORES — gate `autverif`.
#
#   uso: bash scripts/ci/autoridade_verificadores.sh <raiz> [workflow]
#
# ---------------------------------------------------------------------------
# POR QUE ELA EXISTE
# ---------------------------------------------------------------------------
#
# Esta arvore tem uma cadeia de guardas, e cada elo dela responde pelo elo de
# baixo. O agregador e provado por `teste_portao_os_integracao.sh`; o contrato de
# conteudo e provado por `teste_contrato_suites.sh`; a matriz e observada por
# `testemunha_contratosui.sh`. TRES PECAS ficavam de fora dessa contabilidade —
# e sao justamente as que decidem:
#
#   scripts/ci/verificar_contrato_suites.sh   decide se a suite ainda PROVA
#   scripts/ci/portao_os_integracao.sh        decide se o CI inteiro e VERDE
#   scripts/ci/codigo_executavel.awk          decide o que e CODIGO e o que e TEXTO
#
# [OS 40-C5] SAO QUATRO. A quarta entrou depois, pela mesma razao e um andar
# acima:
#
#   scripts/ci/teste_portao_os_integracao.sh  decide se a EXECUCAO de cada passo
#                                             zero esta viva, unica e ordenada
#
# Nenhuma delas tinha digest proprio, inventario proprio nem prova de que suas
# decisoes materiais continuam la. A rehomologacao OS 40-R4 mediu o preco disso
# na campanha `V01`–`V10`: tirar `contratosui` dos mapas de piso (`V04`),
# neutralizar a comparacao de piso (`V06`) e combinar a neutralizacao com uma
# declaracao movida para heredoc (`V06 + E01`) conservavam a cadeia oficial
# inteiramente VERDE. Quem decide nao pode ser a unica peca sem quem a verifique.
#
# ---------------------------------------------------------------------------
# DE ONDE VEM A AUTORIDADE, E POR QUE ELA NAO USA O LEXER
# ---------------------------------------------------------------------------
#
# O inventario, os digestos, as decisoes materiais e os pisos minimos estao
# ESCRITOS AQUI, por extenso, e nao sao derivados de nenhum dos tres arquivos
# protegidos. Uma lista lida deles encolheria junto com eles.
#
# E a leitura de codigo vivo e PROPRIA. Ela NAO chama `codigo_executavel.awk`:
# um verificador que usasse o lexer para provar que o lexer nao foi trocado
# confiaria exatamente no trecho cuja neutralizacao ele deve detectar. Aqui o
# comentario de linha e o corpo de heredoc sao removidos por um leitor com
# estado escrito neste arquivo, e o lexer e medido POR COMPORTAMENTO — sondas
# sinteticas, com resposta conhecida, na secao 6.
#
# ---------------------------------------------------------------------------
# O QUE ELA NAO E
# ---------------------------------------------------------------------------
#
# Ela NAO se guarda. Quem responde por este arquivo e a cadeia de sempre: o gate
# `autverif` na fonte unica (com digest, piso e `exige`), o passo proprio no
# workflow, e os vetores da matriz `teste_contrato_suites.sh` que o sabotam e
# exigem vermelho. Uma peca que assinasse o proprio boletim seria o defeito que
# a testemunha do `contratosui` veio consertar, de volta um andar acima.
#
# Exit 0 = tudo no lugar. Exit 1 = ao menos uma recusa.

set -u

raiz="${1:-.}"
workflow="${2:-}"

# ---------------------------------------------------------------------------
# O INVENTARIO CONGELADO — os tres, nominalmente
# ---------------------------------------------------------------------------
# [OS 40-C5] O QUARTO ENTROU, e nao por simetria. `teste_portao_os_integracao.sh`
# deixou de ser so a matriz do agregador: e nele que mora a RELACAO CONGELADA
# dos passos zero protegidos e a guarda lexica que responde se a execucao de
# cada um deles esta viva. A OS 40-R5 tirou a execucao do passo `0a` e forjou a
# evidencia; a partir daqui, quem apagar aquela relacao muda um arquivo com
# digesto E com decisoes materiais congelados FORA dele — a fonte unica tem a
# outra metade, e as duas teriam de cair juntas.
readonly INVENTARIO="\
scripts/ci/verificar_contrato_suites.sh \
scripts/ci/portao_os_integracao.sh \
scripts/ci/codigo_executavel.awk \
scripts/ci/teste_portao_os_integracao.sh"

# ---------------------------------------------------------------------------
# OS DIGESTOS NORMALIZADOS — `tr -d '\r' | sha256sum`
# ---------------------------------------------------------------------------
#
# Normalizado, e nao byte a byte: o indice do git guarda LF, a arvore de
# trabalho no Windows tem CRLF e o runner do Actions ve LF. Assinar os bytes
# crus valeria numa plataforma e mentiria na outra.
#
# UM registro por arquivo, e a unicidade e conferida: dois registros para o
# mesmo caminho deixariam a comparacao depender de qual deles fosse lido
# primeiro.
DIGESTOS="$(cat <<'DIGESTOS_CONGELADOS'
scripts/ci/verificar_contrato_suites.sh 571b12c5ed78664691a11e04f4177f3cd45dd099aa86260d3f29e69cc6e9dd84
scripts/ci/portao_os_integracao.sh 1c97a3048b630ec3799f05be3932edc46d0f7598af47b1087767ca8b4cdf66d2
scripts/ci/codigo_executavel.awk 4ebdcebb72e37959d2825acf7805980fc4a0c36418307f0b8336262a8efa541e
scripts/ci/teste_portao_os_integracao.sh de368b1850a32070b1c812c8ce73ce32853fee552aa0998108616a283bb13ab7
DIGESTOS_CONGELADOS
)"
readonly DIGESTOS

# ---------------------------------------------------------------------------
# AS DECISOES MATERIAIS — literais que tem de continuar VIVOS, na quantidade
# ---------------------------------------------------------------------------
#
# Uma linha `@ <arquivo>` abre um bloco; cada linha seguinte e `<n> <literal>`,
# e o literal tem de aparecer em EXATAMENTE `n` linhas de CODIGO VIVO daquele
# arquivo. Cardinalidade exata, e nao piso: a mais e sabotagem que atinge mais
# do que declara; a menos e decisao apagada.
#
# Comentario nao conta, e corpo de heredoc tambem nao. Preservar a MENSAGEM e
# apagar a DECISAO e a forja mais barata contra busca textual — e e ela que
# `V07` (remocao de `erro()` preservando mensagens) exercita.
EXIGENCIAS="$(cat <<'DECISOES_MATERIAIS'
@ scripts/ci/verificar_contrato_suites.sh
1 erro() {
1 falhas=1
1 exit "$falhas"
4 -lt "$piso"
1 readonly PISOS_PROVAS=
1 readonly PISOS_CASOS=
1 readonly PISOS_EXIGE=
1 readonly PISOS_EXIGENOCASO=
1 readonly CONTRATOS_MINIMOS=
1 LEXICO="$(dirname "$0")/codigo_executavel.awk"
1 if [ ! -s "$LEXICO" ]; then
1 tr -d '\r\000' < "$1" | awk -v ling="$LINGUA" -v agulhas="$2" -f "$LEXICO"
1 if [ "$sha_real" = "$sha_esperado" ]; then
1 if [ "$PROVAS_REAIS" -ge "$provas_esperadas" ]; then
1 if [ "$maior" -ge "$casos_esperados" ]; then
1 elif [ "$carimbo" -nt "$log" ]; then
1 GUARDA_PASSO_ZERO="$(dirname "$0")/teste_portao_os_integracao.sh"
1 bash "$GUARDA_PASSO_ZERO" --guarda "$workflow"
@ scripts/ci/portao_os_integracao.sh
1 if [ "$valor" = "0" ]; then
6 falhou=1
1 printf 'resultado: VERDE\n'
1 exit 1
1 erro "gate duplicado em
1 erro "fonte única não declara nenhum gate obrigatório
1 if [ -e "$f_nao" ]; then
@ scripts/ci/codigo_executavel.awk
1 if (viu[j]) print "INERTE\t" ag[j]
1 else print "AUSENTE\t" ag[j]
1 if (!temcodigo) print "SEMCODIGO"
3 print "ABERTO\t
1 if (caso_alvo != "" && !achou_caso) print "SEMCASO\t" caso_alvo
9 st = "cod"
1 if (ling != "js" && ling != "dart" && ling != "sh" && ling != "json") {
@ scripts/ci/teste_portao_os_integracao.sh
1 readonly PASSOS_ZERO_PROTEGIDOS='portaoci autverif contratosui'
1 readonly CONSUMIDOR_DA_EVIDENCIA=
1 campo_do_passo() {
1 guarda_passo_zero() {
1 guarda_passo_zero_sem_relacao() {
1 guarda_invocacao_passo_zero() {
1 guarda_passo_zero "$reg" "$k" || ruim=1
1 guarda_passo_zero_sem_relacao "$reg" || ruim=1
1 guarda_invocacao_passo_zero "$YML_GUARDA"
1 vetores_do_passo_zero portaoci
1 vetores_do_passo_zero autverif
1 vetores_do_passo_zero contratosui
2 abertura_de_heredoc() {
1 abertura_de_heredoc "$acumulada"
1 case "$delim" in
6 ABERTURA_AMBIGUA=1
1 esperar_classe() {
1 leitura_do_heredoc() {
1 cmp -s "$TMP/leitura_aqui.txt" "$TMP/leitura_la.txt"
1 shell_abre() {
2 if shell_abre "$linha"; then
1 cmp -s "$TMP/vivas_esp_$a" "$TMP/cod_$a"
1 if [ "$vista" = "$esperada" ]; then
1 if (modo == "apendice") {
1 if (modo == "prologo" && posto == 0 && L[i] ~ /^      - name: /) {
1 linha_da_amostra() { printf '%s\n' "$1" >> "$AMOSTRA"; }
1 if [ "$ctx" = 'S' ]; then
2 ABERTURA_CONTINUA=1
1 if [ "$ctx" != 'C' ]; then
1 ABERTURA_TABS="$tabs"
1 base=${#pref}
1 if (modo == "heredoc_ind")
DECISOES_MATERIAIS
)"
readonly EXIGENCIAS

# ---------------------------------------------------------------------------
# OS PISOS DOS PISOS — as chaves que os mapas do verificador nao podem perder
# ---------------------------------------------------------------------------
#
# `V04` retirava `contratosui` dos mapas de piso: a chave sumia, `piso_de`
# devolvia vazio, a comparacao nao rodava, e nada reprovava. O mapa e um dado, e
# um dado que ninguem confere e um dado que pode encolher.
#
# Aqui a chave e OBRIGATORIA e o valor tem PISO. Um numero menor do que o
# congelado abaixo e regressao de prova, mesmo que a comparacao continue escrita.
readonly MINIMOS_PROVAS="comunicacao:83 chatdom:60 portaoci:74 contratosui:82 rankingfn:57 autverif:35"
readonly MINIMOS_CASOS="comunicacao:81 portaoci:248 contratosui:68 rankingfn:465 autverif:102"
readonly MINIMOS_EXIGE="comunicacao:35 chatdom:6 portaoci:55 contratosui:29 rankingfn:15 autverif:24"
readonly MINIMOS_EXIGENOCASO="comunicacao:3 contratosui:5"

# A propria invocacao, que o workflow tem de continuar carregando. Apagar o
# passo desta autoridade nao pode ser silencioso — e a mesma razao pela qual
# `verificar_contrato_suites.sh` cobra a dele.
readonly INVOCACAO_PROPRIA='scripts/ci/autoridade_verificadores.sh'
readonly GATE_PROPRIO='autverif'

TMPA="$(mktemp -d)" || { printf 'AUTORIDADE: sem diretorio temporario\n'; exit 1; }
trap 'rm -rf "$TMPA"' EXIT

verdes=0
falhas=0

ok() {
  verdes=$((verdes + 1))
  printf 'ok   %s\n' "$*"
}

recusa() {
  falhas=$((falhas + 1))
  printf 'AUTORIDADE: %s\n' "$*"
}

# ---------------------------------------------------------------------------
# O LEITOR DE CODIGO VIVO — proprio, e de proposito
# ---------------------------------------------------------------------------
#
# `vivas_de <arquivo> <destino>` — escreve em `<destino>` so as linhas que o
# interpretador de fato executa: sem comentario de linha inteira, e sem corpo de
# heredoc. E o minimo que separa "o texto esta no arquivo" de "o programa faz
# aquilo", e ele NAO passa pelo lexer que esta autoridade tem de medir.
# `abertura_de_heredoc <linha>` — o delimitador do heredoc que ESTA LINHA abre de
# verdade, devolvido em `ABERTURA_HEREDOC`, e vazio quando ela nao abre nenhum.
# Em `ABERTURA_AMBIGUA` vai `1` quando a linha NAO pode ser decidida com
# seguranca — e ai quem chama reprova, em vez de escolher uma leitura.
#
# POR QUE E CARACTERE A CARACTERE (OS 40-C7). Ate a OS 40-C6 as duas leituras
# recortavam o sufixo com `${nu##*<<}` e APAGAVAM todas as aspas antes de
# perguntar se o que sobrou parecia um identificador. A OS 40-R7 mediu o preco: a
# aspa apagada era justamente a de FECHAMENTO, que e a UNICA coisa que separa
#
#     cat <<ALVO                  o par e operador de redirecionamento
#     echo "diagnostico <<ALVO"   o par e texto, e nao abre nada
#
# Apagada a aspa, as duas formas viravam a mesma, e `echo "diagnostico <<ALVO"`
# cegava as duas leituras: o resto do workflow ia para a classe HEREDOC, a
# contagem de passos congelava, um passo zero material novo sumia e a escrita
# posterior de log e de marcador deixava de ser vista — com a cadeia oficial
# inteira VERDE.
#
# A ORDEM E A CORRECAO: primeiro achar o OPERADOR fora de regiao inerte, e SO
# DEPOIS ler a citacao que pertence ao token do delimitador. Nao ha parser de
# shell aqui, nem de YAML: ha a maquina de estados minima que distingue codigo de
# aspa simples, de aspa dupla, de comentario, de expansao `${...}` e de
# aritmetica `$((...))` — que e onde o par tambem aparece sem abrir corpo algum.
#
# A REFERENCIA E `scripts/ci/codigo_executavel.awk`, o lexer com estado que o
# contrato de conteudo ja usa, e a concordancia com ele e com o SHELL REAL e
# medida caso a caso pela matriz `HD`.
abertura_de_heredoc() {
  local linha="$1"
  local n=${#linha}
  local i=0 j=0 c='' d='' ctx='C' pilha='' delim='' parte='' aberta=0
  local achadas=0 inicio=1 tabs=0
  ABERTURA_HEREDOC=''
  ABERTURA_AMBIGUA=0
  ABERTURA_TABS=0
  ABERTURA_CONTINUA=0
  while [ "$i" -lt "$n" ]; do
    c="${linha:$i:1}"

    # ASPA SIMPLES CRUA: nada la dentro e operador, nem sequer a barra invertida.
    if [ "$ctx" = 'Q' ]; then
      [ "$c" = "'" ] && { ctx="${pilha:0:1}"; pilha="${pilha:1}"; }
      i=$((i + 1))
      continue
    fi
    # ANSI-C QUOTING NAO E ASPA CRUA (OS 40-C8). Em `$'...'` a barra invertida
    # ESCAPA o proximo caractere, inclusive a aspa que fecharia o literal.
    # Tratar os dois como o mesmo estado fechava a citacao cedo, achava o par
    # `<<` em contexto de codigo e abria um corpo que o shell real NAO abre — e
    # a linha seguinte, que o shell EXECUTA, sumia da auditoria (OS 40-R8, E1).
    # `codigo_executavel.awk` ja separava os dois casos, e continua sendo a
    # referencia desta distincao.
    if [ "$ctx" = 'S' ]; then
      if [ "$c" = '\' ]; then
        [ "$((i + 1))" -ge "$n" ] && ABERTURA_CONTINUA=1
        i=$((i + 2))
        continue
      fi
      [ "$c" = "'" ] && { ctx="${pilha:0:1}"; pilha="${pilha:1}"; }
      i=$((i + 1))
      continue
    fi
    # EXPANSAO DE PARAMETRO: `${nu##*<<}` e um nome com corte, e nao um comando.
    if [ "$ctx" = 'P' ]; then
      [ "$c" = '}' ] && { ctx="${pilha:0:1}"; pilha="${pilha:1}"; }
      i=$((i + 1))
      continue
    fi
    # ARITMETICA: `$((1<<2))` e deslocamento, e nao abre corpo nenhum.
    if [ "$ctx" = 'A' ]; then
      if [ "${linha:$i:2}" = '))' ]; then
        ctx="${pilha:0:1}"; pilha="${pilha:1}"; i=$((i + 2))
        continue
      fi
      i=$((i + 1))
      continue
    fi

    # Daqui para baixo o contexto e CODIGO ou ASPA DUPLA. A barra invertida
    # escapa o proximo caractere nos dois: `echo \<<EOF` nao abre heredoc, e o
    # shell real concorda — o que sobra ali e `<EOF`, redirecionamento de
    # ENTRADA.
    #
    # NO FIM DA LINHA ela nao escapa caractere nenhum: apaga a QUEBRA. A linha
    # logica continua na linha FISICA seguinte, que ainda e codigo executavel, e
    # o corpo de um heredoc aberto aqui so comeca DEPOIS dela (OS 40-C8; era o
    # escape E3 da OS 40-R8).
    if [ "$c" = '\' ]; then
      [ "$((i + 1))" -ge "$n" ] && ABERTURA_CONTINUA=1
      i=$((i + 2)); inicio=0; continue
    fi
    if [ "${linha:$i:3}" = '$((' ]; then
      pilha="$ctx$pilha"; ctx='A'; i=$((i + 3)); inicio=0
      continue
    fi
    # SUBSTITUICAO DE COMANDO VOLTA A SER CODIGO, inclusive dentro de aspas
    # duplas: `DIGESTOS="$(cat <<'DIGESTOS_CONGELADOS'` abre um heredoc de
    # verdade, e este repositorio tem oito linhas assim.
    if [ "${linha:$i:2}" = '$(' ]; then
      pilha="$ctx$pilha"; ctx='C'; i=$((i + 2)); inicio=1
      continue
    fi
    if [ "${linha:$i:2}" = '${' ]; then
      pilha="$ctx$pilha"; ctx='P'; i=$((i + 2)); inicio=0
      continue
    fi
    # O par `$` + aspa simples so abre ANSI-C em CODIGO. Dentro de aspas duplas
    # ele e literal, e o shell real nao lhe da tratamento nenhum.
    if [ "$ctx" = 'C' ] && [ "${linha:$i:2}" = "\$'" ]; then
      pilha="$ctx$pilha"; ctx='S'; i=$((i + 2)); inicio=0
      continue
    fi
    if [ "$ctx" = 'D' ]; then
      [ "$c" = '"' ] && { ctx="${pilha:0:1}"; pilha="${pilha:1}"; }
      i=$((i + 1))
      continue
    fi

    case "$c" in
      "'") pilha="$ctx$pilha"; ctx='Q'; i=$((i + 1)); inicio=0; continue ;;
      '"') pilha="$ctx$pilha"; ctx='D'; i=$((i + 1)); inicio=0; continue ;;
      '`') ABERTURA_AMBIGUA=1; return 0 ;;
      '#') [ "$inicio" -eq 1 ] && break; i=$((i + 1)); inicio=0; continue ;;
      '(') pilha="$ctx$pilha"; ctx='C'; i=$((i + 1)); inicio=1; continue ;;
      ')') [ -n "$pilha" ] && { ctx="${pilha:0:1}"; pilha="${pilha:1}"; }
           i=$((i + 1)); inicio=1; continue ;;
    esac

    # HERE-STRING nao abre corpo: `cat <<<palavra` le a palavra, e a linha
    # seguinte continua sendo codigo.
    if [ "${linha:$i:3}" = '<<<' ]; then i=$((i + 3)); inicio=1; continue; fi

    if [ "${linha:$i:2}" = '<<' ]; then
      j=$((i + 2))
      # `<<-` e a UNICA forma em que o shell remove indentacao do terminador, e
      # remove somente TABULACOES. Guardar isso aqui e o que permite ao chamador
      # fechar o corpo pela coluna real, e nao por linha aparada (OS 40-C8, E2).
      tabs=0
      [ "${linha:$j:1}" = '-' ] && { tabs=1; j=$((j + 1)); }
      while [ "$j" -lt "$n" ]; do
        case "${linha:$j:1}" in
          [[:blank:]]) j=$((j + 1)) ;;
          *) break ;;
        esac
      done
      # O TOKEN DO DELIMITADOR, e so ele. A citacao e lida AQUI, depois de o
      # operador ja ter sido achado: `<<'FIM'`, `<<"FIM"` e `<<\FIM` sao o mesmo
      # delimitador `FIM`, e a aspa que fecha pertence a ESTE token.
      delim=''
      aberta=0
      while [ "$j" -lt "$n" ]; do
        d="${linha:$j:1}"
        case "$d" in
          "'" | '"')
            j=$((j + 1)); parte=''
            while [ "$j" -lt "$n" ] && [ "${linha:$j:1}" != "$d" ]; do
              parte="$parte${linha:$j:1}"
              j=$((j + 1))
            done
            [ "$j" -ge "$n" ] && { aberta=1; break; }
            j=$((j + 1)); delim="$delim$parte"
            ;;
          '\')
            j=$((j + 1)); delim="$delim${linha:$j:1}"; j=$((j + 1))
            ;;
          [[:blank:]] | ';' | '&' | '|' | '<' | '>' | '(' | ')' | '#')
            break
            ;;
          *)
            delim="$delim$d"; j=$((j + 1))
            ;;
        esac
      done
      # CITACAO QUE NAO FECHA NA LINHA: o token do delimitador nao esta inteiro
      # aqui, e adivinhar qual e seria escolher por conveniencia.
      [ "$aberta" -eq 1 ] && { ABERTURA_AMBIGUA=1; return 0; }
      case "$delim" in
        '') ;;
        *[!A-Za-z0-9_]* | [0-9]*)
          # O SHELL ABRE, e esta leitura nao sabe representar. Fechar aqui e a
          # unica saida honesta: dizer "nao abre" deixaria o corpo do heredoc
          # ser lido como codigo.
          ABERTURA_AMBIGUA=1
          return 0
          ;;
        *)
          achadas=$((achadas + 1))
          if [ -z "$ABERTURA_HEREDOC" ]; then
            ABERTURA_HEREDOC="$delim"
            ABERTURA_TABS="$tabs"
          fi
          ;;
      esac
      i="$j"; inicio=1
      continue
    fi

    case "$c" in
      [[:blank:]] | ';' | '&' | '|' | '<' | '>') inicio=1 ;;
      *) inicio=0 ;;
    esac
    i=$((i + 1))
  done

  # DUAS ABERTURAS NA MESMA LINHA sao dois corpos empilhados, e esta leitura so
  # sabe seguir um.
  if [ "$achadas" -gt 1 ]; then
    ABERTURA_HEREDOC=''
    ABERTURA_AMBIGUA=1
    return 0
  fi
  # A LINHA QUE ACABA DENTRO DE UMA CITACAO E INDECIDIVEL, E ISSO NAO DEPENDE DE
  # JA TER ACHADO UM DELIMITADOR (OS 40-C8). Antes a conferencia estava presa a
  # `achadas -eq 0`, e uma linha que abrisse heredoc saia com o delimitador e
  # ambiguidade ZERO mesmo terminando com aspa aberta (OS 40-R8, E4). A
  # ambiguidade passa a ter PRECEDENCIA sobre a abertura encontrada.
  #
  # `pilha` sozinha NAO e indecidivel: `X="$(cat <<'EOF'` termina em contexto de
  # CODIGO, dentro de uma substituicao que continua na linha seguinte, e o shell
  # real ABRE o corpo ali mesmo. So e indecidivel quando a linha acaba DENTRO de
  # citacao ou expansao — e ai `ctx` deixa de ser 'C'.
  if [ "$ctx" != 'C' ]; then
    ABERTURA_HEREDOC=''
    ABERTURA_AMBIGUA=1
  elif [ "$achadas" -eq 0 ] && [ -n "$pilha" ]; then
    ABERTURA_AMBIGUA=1
  fi
  return 0
}

vivas_de() {
  local arq="$1" destino="$2"
  local bruta linha nu fim_heredoc='' ambiguas=0
  local base=0 aguarda_base=0 pref sh_linha alvo TABV
  local acumulada='' continuando=0 her_tabs=0 tem_op=0
  TABV="$(printf '\t')"
  {
    while IFS= read -r bruta || [ -n "$bruta" ]; do
      linha="${bruta%$'\r'}"
      nu="${linha#"${linha%%[![:blank:]]*}"}"
      # MESMO RECORTE DE BLOCO DA OUTRA LEITURA (OS 40-C8): esta funcao tambem e
      # chamada sobre o workflow, onde o shell so recebe o bloco `run: |` ja
      # dedentado. Num `.sh` nao ha bloco, a base fica zero e nada muda.
      if [ "$aguarda_base" -eq 1 ] && [ -n "$nu" ]; then
        pref="${linha%%[![:blank:]]*}"
        base=${#pref}
        aguarda_base=0
      fi
      sh_linha="$linha"
      if [ "$base" -gt 0 ] && [ -n "$nu" ]; then
        pref="${linha:0:$base}"
        case "$pref" in
          *[![:blank:]]*) base=0 ;;
          *) sh_linha="${linha:$base}" ;;
        esac
      fi
      # O TERMINADOR FECHA PELA COLUNA REAL: coluna zero sem `<<-`, e com `<<-`
      # apenas TABULACOES iniciais sao removidas pelo shell.
      if [ -n "$fim_heredoc" ]; then
        alvo="$sh_linha"
        if [ "$her_tabs" -eq 1 ]; then
          while [ "${alvo#"$TABV"}" != "$alvo" ]; do alvo="${alvo#"$TABV"}"; done
        fi
        [ "$alvo" = "$fim_heredoc" ] && fim_heredoc=''
        continue
      fi
      case "$nu" in
        'run: |' | 'run: |-' | 'run: |+')
          aguarda_base=1
          base=0
          ;;
      esac
      if [ "$continuando" -eq 0 ]; then
        case "$nu" in
          '#'* | '') continue ;;
        esac
        acumulada="$sh_linha"
      else
        acumulada="$acumulada$sh_linha"
      fi
      tem_op=0
      case "$acumulada" in
        *'<<'*) tem_op=1 ;;
      esac
      ABERTURA_HEREDOC=''
      ABERTURA_AMBIGUA=0
      ABERTURA_TABS=0
      ABERTURA_CONTINUA=0
      case "$acumulada" in
        *'<<'* | *\\) abertura_de_heredoc "$acumulada" ;;
      esac
      # A CONTINUACAO FISICA CONTINUA VIVA: o comando e um so, e a linha
      # seguinte ainda executa (OS 40-C8).
      if [ "$ABERTURA_CONTINUA" -eq 1 ]; then
        acumulada="${acumulada%\\}"
        continuando=1
        printf '%s\n' "$linha"
        continue
      fi
      continuando=0
      if [ "$tem_op" -eq 1 ] && [ "$ABERTURA_AMBIGUA" -eq 1 ]; then
        ambiguas=$((ambiguas + 1))
        acumulada=''
        continue
      fi
      printf '%s\n' "$linha"
      if [ -n "$ABERTURA_HEREDOC" ]; then
        fim_heredoc="$ABERTURA_HEREDOC"
        her_tabs="$ABERTURA_TABS"
      fi
      acumulada=''
    done < "$arq"
  } > "$destino"
  # LINHA INDECIDIVEL REPROVA (OS 40-C7): quem chama recusa, em vez de seguir
  # com uma leitura que ela mesma nao consegue justificar.
  [ "$ambiguas" -eq 0 ]
}

# `mapa_de <arquivo> <nome>` — o valor de um `readonly NOME="..."` que pode
# continuar em mais de uma linha, devolvido em `MAPA`. Sem `source`: nada vindo
# de arquivo e interpretado aqui.
MAPA=''
mapa_de() {
  local arq="$1" nome="$2" bruta linha juntando=0
  MAPA=''
  while IFS= read -r bruta || [ -n "$bruta" ]; do
    linha="${bruta%$'\r'}"
    if [ "$juntando" -eq 0 ]; then
      case "$linha" in
        "readonly $nome="*)
          linha="${linha#"readonly $nome="}"
          linha="${linha#\"}"
          juntando=1
          ;;
        *) continue ;;
      esac
    fi
    case "$linha" in
      *'\')
        MAPA="$MAPA${linha%\\} "
        continue
        ;;
    esac
    MAPA="$MAPA${linha%\"}"
    return 0
  done < "$arq"
  return 1
}

# `valor_no_mapa <mapa> <chave>` — devolve em `VALOR` o numero congelado ali.
VALOR=''
valor_no_mapa() {
  local par
  VALOR=''
  for par in $1; do
    case "$par" in
      "$2":*) VALOR="${par#*:}"; return 0 ;;
    esac
  done
  return 1
}

printf '== 1. inventario e unicidade do registro ==\n'

n_inv=0
for arq in $INVENTARIO; do
  n_inv=$((n_inv + 1))
  if [ ! -s "$raiz/$arq" ]; then
    recusa "o verificador '$arq' esta ausente ou vazio — a peca que decide sumiu"
    continue
  fi
  registros="$(grep -c "^$arq " <<REGISTROS
$DIGESTOS
REGISTROS
)" || registros=0
  if [ "$registros" -eq 0 ]; then
    recusa "o verificador '$arq' NAO tem digesto no inventario desta autoridade"
  elif [ "$registros" -gt 1 ]; then
    recusa "o verificador '$arq' tem $registros registros de digesto — o inventario e ambiguo"
  fi
done

n_dig="$(grep -c . <<CONTAGEM_DIGESTOS
$DIGESTOS
CONTAGEM_DIGESTOS
)" || n_dig=0
if [ "$n_dig" -ne "$n_inv" ]; then
  recusa "o inventario tem $n_inv verificador(es) e $n_dig registro(s) de digesto"
else
  ok "inventario    $n_inv verificador(es), um registro cada"
fi

printf '\n== 2. os digestos normalizados ==\n'

for arq in $INVENTARIO; do
  [ -s "$raiz/$arq" ] || continue
  esperado="$(awk -v a="$arq" '$1 == a { print $2; exit }' <<LEITURA_DIGESTO
$DIGESTOS
LEITURA_DIGESTO
)"
  real="$(tr -d '\r' < "$raiz/$arq" | sha256sum)"
  real="${real%% *}"
  if [ -z "$esperado" ]; then
    continue
  elif [ "$real" = "$esperado" ]; then
    ok "digesto      $arq  ${real:0:16}..."
  else
    recusa "o conteudo de '$arq' mudou e o digesto desta autoridade nao."
    recusa "  congelado $esperado"
    recusa "  no disco  $real"
  fi
done

printf '\n== 3. as decisoes materiais, em codigo vivo ==\n'

arq_atual=''
vivo=''
while IFS= read -r reg; do
  [ -z "$reg" ] && continue
  case "$reg" in
    '@ '*)
      arq_atual="${reg#@ }"
      vivo="$TMPA/vivo_${arq_atual##*/}"
      if [ -s "$raiz/$arq_atual" ]; then
        vivas_de "$raiz/$arq_atual" "$vivo" ||
          recusa "ha linha indecidivel em '$arq_atual': citacao aberta, duas aberturas de heredoc na mesma linha ou delimitador fora da gramatica"
      else
        vivo=''
      fi
      continue
      ;;
  esac
  [ -z "$arq_atual" ] && continue
  if [ -z "$vivo" ]; then
    recusa "nao ha como conferir as decisoes de '$arq_atual': o arquivo nao esta la"
    continue
  fi
  esperadas="${reg%% *}"
  literal="${reg#* }"
  viu="$(grep -cF -- "$literal" "$vivo")" || viu=0
  if [ "$viu" -eq "$esperadas" ]; then
    ok "decisao      ${arq_atual##*/}  $esperadas x  $literal"
  else
    recusa "a decisao material '$literal' aparece $viu vez(es) em codigo vivo de '$arq_atual', e o congelado e $esperadas"
  fi
done <<TODAS_AS_EXIGENCIAS
$EXIGENCIAS
TODAS_AS_EXIGENCIAS

printf '\n== 4. os pisos que o verificador nao pode perder ==\n'

verificador="$raiz/scripts/ci/verificar_contrato_suites.sh"
if [ ! -s "$verificador" ]; then
  recusa "sem o verificador nao ha pisos a conferir"
else
  for dupla in PISOS_PROVAS:MINIMOS_PROVAS PISOS_CASOS:MINIMOS_CASOS \
               PISOS_EXIGE:MINIMOS_EXIGE PISOS_EXIGENOCASO:MINIMOS_EXIGENOCASO; do
    nome_mapa="${dupla%%:*}"
    nome_min="${dupla#*:}"
    if ! mapa_de "$verificador" "$nome_mapa"; then
      recusa "o verificador nao declara mais o mapa '$nome_mapa' — os pisos daquele eixo deixaram de existir"
      continue
    fi
    declarado="$MAPA"
    eval "minimos=\$$nome_min"
    for par in $minimos; do
      chave="${par%%:*}"
      minimo="${par#*:}"
      if ! valor_no_mapa "$declarado" "$chave"; then
        recusa "'$chave' saiu de '$nome_mapa' — sem a chave, a comparacao daquele gate nao roda e nada reprova"
        continue
      fi
      case "$VALOR" in
        '' | *[!0-9]*)
          recusa "o piso de '$chave' em '$nome_mapa' nao e um numero: '$VALOR'"
          continue
          ;;
      esac
      if [ "$VALOR" -lt "$minimo" ]; then
        recusa "o piso de '$chave' em '$nome_mapa' caiu de $minimo para $VALOR"
      else
        ok "piso         $nome_mapa  $chave $VALOR >= $minimo"
      fi
    done
  done
fi

printf '\n== 5. o tratamento do codigo de saida ==\n'

vivo_verif="$TMPA/vivo_verificar_contrato_suites.sh"
if [ -s "$vivo_verif" ]; then
  # SAIDA ANTECIPADA VERDE. Um `exit 0` no meio do verificador aprova tudo o que
  # viria depois, e nenhuma mensagem muda de lugar.
  antecipadas="$(grep -cE '^[[:blank:]]*exit 0([[:blank:]]|$)' "$vivo_verif")" || antecipadas=0
  if [ "$antecipadas" -ne 0 ]; then
    recusa "o verificador tem $antecipadas 'exit 0' em codigo vivo — saida antecipada verde"
  else
    ok "saida        o verificador nao tem nenhum 'exit 0' antecipado"
  fi
  ultima="$(grep -E '^[[:blank:]]*exit ' "$vivo_verif" | tail -1)"
  ultima="${ultima#"${ultima%%[![:blank:]]*}"}"
  if [ "$ultima" = 'exit "$falhas"' ]; then
    ok "saida        o verificador termina em exit \"\$falhas\""
  else
    recusa "o ultimo 'exit' do verificador e '$ultima', e nao 'exit \"\$falhas\"'"
  fi
else
  recusa "sem o verificador nao ha codigo de saida a conferir"
fi

vivo_portao="$TMPA/vivo_portao_os_integracao.sh"
if [ -s "$vivo_portao" ]; then
  for codigo in 1 2; do
    n="$(grep -cE "^[[:blank:]]*exit $codigo([[:blank:]]|$)" "$vivo_portao")" || n=0
    if [ "$n" -eq 0 ]; then
      recusa "o agregador nao tem mais nenhum 'exit $codigo' — o veredito daquele eixo sumiu"
    else
      ok "saida        o agregador reprova com exit $codigo ($n ocorrencia(s))"
    fi
  done
else
  recusa "sem o agregador nao ha codigo de saida a conferir"
fi

printf '\n== 6. o lexer, medido por COMPORTAMENTO ==\n'

lexico="$raiz/scripts/ci/codigo_executavel.awk"
if [ ! -s "$lexico" ]; then
  recusa "o analisador lexico esta ausente — nao ha o que sondar"
else
  # AS SONDAS SAO A DEFESA CONTRA "TROCA DO LEXER POR BUSCA TEXTUAL SIMPLES".
  # Um digesto so prova que o arquivo nao mudou; um `grep` so prova que uma
  # palavra continua escrita. Isto aqui prova que ele AINDA DISTINGUE codigo de
  # texto — e nenhum recarimbo satisfaz uma resposta que precisa ser calculada.
  printf 'const ALVO = 1;\n' > "$TMPA/vivo.js"
  printf '// const ALVO = 1;\n' > "$TMPA/morto.js"
  printf '/* comentario que nunca fecha\nconst ALVO = 1;\n' > "$TMPA/aberto.js"
  printf 'const ALVO = 1;\n' > "$TMPA/desconhecido.py"
  printf 'const ALVO =\n' > "$TMPA/agulha.txt"

  sondar() {
    tr -d '\r\000' < "$1" | awk -v ling="$2" -v agulhas="$TMPA/agulha.txt" -f "$lexico"
  }

  saida="$(sondar "$TMPA/vivo.js" js)"
  case "$saida" in
    *AUSENTE* | *INERTE*) recusa "a sonda: o lexer nao reconhece uma agulha em CODIGO ($saida)" ;;
    *) ok "sonda        agulha em codigo executavel e aceita" ;;
  esac

  saida="$(sondar "$TMPA/morto.js" js)"
  case "$saida" in
    *INERTE*) ok "sonda        agulha so em comentario e recusada como INERTE" ;;
    *) recusa "a sonda: o lexer ACEITOU uma agulha que so existe em comentario ($saida) — ele virou busca textual" ;;
  esac

  saida="$(sondar "$TMPA/aberto.js" js)"
  case "$saida" in
    *ABERTO*) ok "sonda        comentario de bloco sem fechar responde ABERTO" ;;
    *) recusa "a sonda: o lexer nao acusa leitura ABERTA ($saida) — ausencia viraria verde" ;;
  esac

  saida="$(sondar "$TMPA/desconhecido.py" py)"
  case "$saida" in
    *SEMLINGUA*) ok "sonda        extensao fora do vocabulario responde SEMLINGUA" ;;
    *) recusa "a sonda: o lexer nao recusa linguagem desconhecida ($saida)" ;;
  esac
fi

printf '\n== 7. os tres, e esta autoridade, no caminho oficial ==\n'

fonte="$raiz/scripts/ci/gates_os_integracao.txt"
if [ ! -s "$fonte" ]; then
  recusa "a fonte unica esta ausente em '$fonte'"
elif grep -q "^$GATE_PROPRIO\$" "$fonte" || grep -q "^$GATE_PROPRIO"$'\r'"\$" "$fonte"; then
  ok "fonte        o gate '$GATE_PROPRIO' continua declarado na fonte unica"
else
  recusa "o gate '$GATE_PROPRIO' saiu da fonte unica — esta autoridade ficaria sem portao"
fi

if [ -z "$workflow" ]; then
  printf 'ok   workflow     nao informado: as conferencias de caminho oficial nao rodam\n'
elif [ ! -s "$workflow" ]; then
  recusa "o workflow informado esta ausente em '$workflow'"
else
  # SOBRE CODIGO VIVO, e nao sobre o texto do arquivo (OS 40-C5).
  #
  # Ate aqui esta secao lia o YAML inteiro com `grep -F`. A OS 40-R5 mostrou o
  # preco: um literal posto em heredoc satisfaz busca textual e nao executa uma
  # linha. Era uma das duas metades do escape — a outra, a que decide, e a
  # guarda lexica dos passos zero, que responde por ORDEM, unicidade e forma.
  # Esta continua respondendo so pela PRESENCA, e agora pela presenca em codigo
  # que roda. As duas leituras sao independentes, e e de proposito.
  vivo_workflow="$TMPA/vivo_workflow"
  vivas_de "$workflow" "$vivo_workflow" ||
    recusa "ha linha indecidivel no workflow: citacao aberta, duas aberturas de heredoc na mesma linha ou delimitador fora da gramatica"
  for alvo in scripts/ci/verificar_contrato_suites.sh scripts/ci/portao_os_integracao.sh \
              scripts/ci/teste_portao_os_integracao.sh "$INVOCACAO_PROPRIA"; do
    if grep -Fq -- "$alvo" "$vivo_workflow"; then
      ok "workflow     $alvo continua no caminho oficial"
    else
      recusa "o workflow nao referencia mais '$alvo' em codigo vivo — a peca saiu do caminho oficial"
    fi
  done
  if grep -Fq -- "exit_$GATE_PROPRIO" "$vivo_workflow"; then
    ok "workflow     o passo produz exit_$GATE_PROPRIO"
  else
    recusa "o workflow nao produz 'exit_$GATE_PROPRIO' — gate declarado sem produtor"
  fi
fi

printf '\n----------------------------------------\n'
printf 'casos ok: %d | casos com falha: %d\n' "$verdes" "$falhas"

if [ "$falhas" -eq 0 ]; then
  printf 'AUTORIDADE DOS VERIFICADORES: VERDE\n'
  exit 0
fi

printf 'AUTORIDADE DOS VERIFICADORES: VERMELHO\n'
exit 1
