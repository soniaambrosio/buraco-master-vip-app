#!/usr/bin/env bash
#
# TESTE DO PRÓPRIO PORTÃO — gate `portaoci` de `ci-os-integracao.yml`.
#
#   uso: bash scripts/ci/teste_portao_os_integracao.sh
#
# Roda sem GitHub Actions, sem rede, sem Flutter e sem Node: só bash e um
# diretório temporário. É o único lugar onde o agregador — a peça que decide se
# TODO o resto foi verde — é ele mesmo verificado.
#
# A matriz cobre os treze casos exigidos pela OS, mais as invariantes de fonte
# única. Cada caso é identificável por nome na saída, para que uma mutação
# derrube um caso nomeado e não apenas "o teste".
#
# Exit 0 = matriz inteira passou. Exit 1 = ao menos um caso falhou.

set -u

AQUI="$(cd "$(dirname "$0")" && pwd)"
RAIZ="$(cd "$AQUI/../.." && pwd)"
PORTAO="$AQUI/portao_os_integracao.sh"
FONTE="$AQUI/gates_os_integracao.txt"
YML="$RAIZ/.github/workflows/ci-os-integracao.yml"

# MODO `--guarda <yml>` (OS 40-C5) — só a autoridade léxica dos passos zero.
#
# É a porta pela qual a FASE A do contrato de conteúdo chama esta mesma guarda,
# no caminho oficial, sem uma segunda cópia do analisador. Ela não precisa do
# agregador nem da fonte única, e por isso a exigência de arquivo obrigatório
# abaixo não vale aqui: cobrar o agregador para responder sobre o workflow faria
# a FASE A reprovar por um arquivo que ela não estava perguntando.
MODO_GUARDA=0
YML_GUARDA=''
case "${1:-}" in
  --guarda)
    MODO_GUARDA=1
    YML_GUARDA="${2:-}"
    if [ -z "$YML_GUARDA" ] || [ ! -f "$YML_GUARDA" ]; then
      printf 'teste do portão: --guarda exige o caminho de um workflow legível\n' >&2
      exit 2
    fi
    ;;
esac

if [ "$MODO_GUARDA" -eq 0 ]; then
  for arquivo in "$PORTAO" "$FONTE" "$YML"; do
    if [ ! -f "$arquivo" ]; then
      printf 'teste do portão: arquivo obrigatório ausente: %s\n' "$arquivo" >&2
      exit 1
    fi
  done
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
RES="$TMP/resultados"

passou=0
falhou=0

ok()  { passou=$((passou + 1)); printf '  ok    %s\n' "$1"; }
nok() { falhou=$((falhou + 1)); printf '  FALHA %s\n' "$1"; }

# A relação vem do PRODUTOR CANÔNICO, e não de uma segunda leitura da fonte.
# Até a OS 32 este `sed | awk` era gêmeo do que vivia dentro do agregador e do
# que vivia no passo de evidência do YAML: três leitores da mesma fonte, e três
# oportunidades de divergir. Divergência entre leitores é a forma original do
# CI-02, só que um degrau mais fundo — a fonte era única e a LEITURA não era.
#
# `--listar` devolve exatamente a relação que o veredito percorre. Se ele
# recusar a fonte, aqui não há como fingir que leu: a matriz inteira aborta.
gates_da_fonte() {
  bash "$PORTAO" --listar "$FONTE"
}

# Lido UMA vez: `reset_verde` roda a cada caso, e reabrir sed+awk vinte vezes
# custa mais que a matriz inteira em máquina onde `fork` é caro.
GATES_FONTE=''
[ "$MODO_GUARDA" -eq 0 ] && GATES_FONTE="$(gates_da_fonte)"

reset_verde() {
  rm -rf "$RES"
  mkdir -p "$RES"
  local g
  for g in $GATES_FONTE; do
    printf '0\n' > "$RES/exit_$g"
  done
}

# esperar <exit-esperado> <descrição> [regex que a saída DEVE conter]
esperar() {
  local esperado="$1" desc="$2" agulha="${3:-}" real
  bash "$PORTAO" "$FONTE" "$RES" > "$TMP/saida.txt" 2>&1
  real=$?
  if [ "$real" != "$esperado" ]; then
    nok "$desc — esperado exit $esperado, obtido $real"
    sed 's/^/        | /' "$TMP/saida.txt"
    return
  fi
  if [ -n "$agulha" ] && ! grep -qE "$agulha" "$TMP/saida.txt"; then
    nok "$desc — exit $real correto, mas a saída não identifica o gate (/$agulha/)"
    sed 's/^/        | /' "$TMP/saida.txt"
    return
  fi
  ok "$desc (exit $real)"
}

contem_gate() {
  local g
  for g in $GATES_FONTE; do [ "$g" = "$1" ] && return 0; done
  return 1
}

# ---------------------------------------------------------------------------
# OS PASSOS ZERO PROTEGIDOS — A RELAÇÃO MORA AQUI (OS 40-C5)
# ---------------------------------------------------------------------------
#
# A OS 40-C4 congelou UMA invocação: a da testemunha do `contratosui`, no passo
# `0b`. A OS 40-R5 mediu o preço de ser só uma. A execução real de
# `autoridade_verificadores.sh` foi retirada do passo `0a` e substituída por
# evidência fabricada — e a cadeia oficial inteira ficou VERDE: `portaoci`
# 53/53, FASE A exit 0, agregador 64/64, FASE B 17 contratos, `t_autverif.log`
# e `exit_autverif` aceitos sem que a autoridade rodasse uma linha. Nada no
# caminho oficial perguntava se AQUELA invocação tinha acontecido.
#
# A relação abaixo é a autoridade, e ela NÃO É DERIVADA DO WORKFLOW. Uma lista
# lida de lá encolheria junto com ele: apagar o passo apagaria a exigência de
# que o passo exista, que é a forma mais barata de uma guarda desligar a si
# mesma. Cada chave é um passo zero que PRODUZ EVIDÊNCIA OBRIGATÓRIA, e
# `guarda_passo_zero_sem_relacao` reprova o passo zero que produzir evidência
# sem estar escrito aqui.
readonly PASSOS_ZERO_PROTEGIDOS='portaoci autverif contratosui'

# Quem lê a evidência produzida pelos passos zero. A ordem entre produtor e
# consumidor é metade da propriedade: evidência consumida antes de nascer é
# evidência de outra corrida.
readonly CONSUMIDOR_DA_EVIDENCIA='scripts/ci/verificar_contrato_suites.sh'

# `campo_do_passo <chave> <campo>` — devolve em `CAMPO` o literal congelado.
#
# SÓ DOIS CAMPOS SÃO ESCRITOS POR EXTENSO: o número do passo e a linha de
# invocação, espremida — o YAML alinha em colunas, e uma guarda que dependesse
# da largura do alinhamento reprovaria na próxima vez que alguém alinhasse a
# tabela. Os outros cinco (núcleo, captura, purga, log e marcador) são
# DERIVADOS da chave. Derivá-los impede o erro silencioso de uma tabela manual:
# cobrar o artefato de uma chave contra a invocação de outra.
CAMPO=''
campo_do_passo() {
  local chave="$1" campo="$2" invocacao='' passo='' resto=''
  case "$chave" in
    portaoci)
      passo='0'
      invocacao='bash scripts/ci/teste_portao_os_integracao.sh 2>&1 | tee t_portaoci.log'
      ;;
    autverif)
      passo='0a'
      invocacao='bash scripts/ci/autoridade_verificadores.sh . .github/workflows/ci-os-integracao.yml 2>&1 | tee t_autverif.log'
      ;;
    contratosui)
      passo='0b'
      invocacao='bash scripts/ci/testemunha_contratosui.sh scripts/ci/teste_contrato_suites.sh 2>&1 | tee t_contratosui.log'
      ;;
    *)
      CAMPO=''
      return 1
      ;;
  esac
  case "$campo" in
    passo)     CAMPO="$passo" ;;
    invocacao) CAMPO="$invocacao" ;;
    # O NÚCLEO é o que identifica uma CHAMADA ao produtor, e não uma menção a
    # ele. `if [ ! -f scripts/ci/autoridade_verificadores.sh ]` cita o arquivo e
    # não o executa; `bash scripts/ci/autoridade_verificadores.sh` executa.
    nucleo)
      resto="${invocacao#bash }"
      CAMPO="bash ${resto%% *}"
      ;;
    captura)   CAMPO='echo ${PIPESTATUS[0]} > exit_'"$chave" ;;
    purga)     CAMPO="rm -f t_$chave.log exit_$chave" ;;
    log)       CAMPO="t_$chave.log" ;;
    marcador)  CAMPO="exit_$chave" ;;
    *)
      CAMPO=''
      return 1
      ;;
  esac
  return 0
}

# `classificar_workflow <yml> <saida>` — um registro por linha:
#
#   <linha>\t<passo>\t<CODIGO|COMENTARIO|HEREDOC|PASSO>\t<conteúdo espremido>
#
# É a diferença entre "o texto está no arquivo" e "o CI executa aquilo". Uma
# linha comentada, uma linha dentro de heredoc e uma linha viva são três coisas
# distintas, e as três se parecem para um `grep`.
#
# A LEITURA É FEITA SÓ COM EXPANSÃO DE PARÂMETRO, sem `sed`/`awk`/`tr` por
# linha. Não é microotimização: são novecentas linhas de YAML, e um `fork` por
# linha nesta plataforma custa mais que a matriz inteira do agregador — uma
# bancada que ninguém roda antes de commitar é uma bancada que não guarda nada.
ASPA_SIMPLES="'"
ASPA_DUPLA='"'

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

classificar_workflow() {
  local arq="$1" saida="$2"
  local n=0 passo=0 bruta linha nu espremida fim_heredoc=''
  local base=0 aguarda_base=0 pref sh_linha alvo TABC
  local acumulada='' continuando=0 her_tabs=0 tem_op=0
  TABC="$(printf '\t')"
  {
    while IFS= read -r bruta || [ -n "$bruta" ]; do
      n=$((n + 1))
      linha="${bruta%$'\r'}"
      nu="${linha#"${linha%%[![:blank:]]*}"}"
      espremida="${nu//$'\t'/ }"
      while [ "$espremida" != "${espremida//  / }" ]; do
        espremida="${espremida//  / }"
      done
      espremida="${espremida% }"

      # O BLOCO `run: |` E O UNICO LUGAR DO WORKFLOW ONDE MORA SHELL, e o YAML
      # entrega o bloco DEDENTADO ao bash. A indentacao do bloco e ESTRUTURA; o
      # que sobra depois dela e CONTEUDO, e o shell a enxerga. Sem essa conta o
      # terminador era comparado contra a linha inteiramente aparada, e um `EOF`
      # indentado fechava aqui um corpo que o shell mantem ABERTO — purga,
      # invocacao e captura viravam dado e a guarda as via vivas (OS 40-R8, E2).
      #
      # Nao e um parser de YAML: e o recorte do bloco literal, medido pela
      # indentacao da primeira linha do bloco. Um arquivo sem `run: |` — os `.sh`
      # que esta mesma leitura audita — fica com base zero e nada muda.
      if [ "$aguarda_base" -eq 1 ] && [ -n "$nu" ]; then
        pref="${linha%%[![:blank:]]*}"
        base=${#pref}
        aguarda_base=0
      fi
      sh_linha="$linha"
      if [ "$base" -gt 0 ] && [ -n "$nu" ]; then
        pref="${linha:0:$base}"
        case "$pref" in
          # DEDENT ESTRUTURAL = FIM DO BLOCO `run:` (OS 40-C9). Uma linha nao
          # vazia MENOS indentada que a base do bloco literal esta FORA dele:
          # e YAML estrutural, nao conteudo shell. Cada `run:` do Actions e um
          # script e um processo proprios, e o estado shell do bloco anterior —
          # heredoc aberto, continuacao fisica, linha logica em curso — morre no
          # EOF daquele script; ele NAO atravessa a fronteira nem alcanca o bloco
          # seguinte. Era o falso verde `NX5` da OS 40-R9: `cat <<true` no fim de
          # um bloco mantinha `fim_heredoc` vivo e o bloco seguinte sumia como
          # HEREDOC. O reset vem ANTES do ramo que consome corpo de heredoc, e e
          # disparado SO pela indentacao: `run: |` ou `- name:` dentro de um corpo
          # de heredoc estao MAIS indentados que a base, nao chegam aqui, e
          # continuam dado. Num `.sh` a base e zero e este ramo nao roda.
          *[![:blank:]]*)
            base=0
            fim_heredoc=''
            her_tabs=0
            acumulada=''
            continuando=0
            ;;
          *) sh_linha="${linha:$base}" ;;
        esac
      fi

      # Dentro de heredoc NADA é código: é dado que o shell entrega a outro
      # programa. Uma invocação escondida aí é texto, e texto não roda.
      #
      # O TERMINADOR FECHA PELA COLUNA REAL. Sem `<<-` ele tem de estar na
      # coluna zero do shell; com `<<-` o shell remove TABULACOES iniciais, e
      # somente elas — espaco nao vale como tab.
      if [ -n "$fim_heredoc" ]; then
        alvo="$sh_linha"
        if [ "$her_tabs" -eq 1 ]; then
          while [ "${alvo#"$TABC"}" != "$alvo" ]; do alvo="${alvo#"$TABC"}"; done
        fi
        [ "$alvo" = "$fim_heredoc" ] && fim_heredoc=''
        printf '%s\t%s\tHEREDOC\t%s\n' "$n" "$passo" "$espremida"
        continue
      fi

      case "$nu" in
        'run: |' | 'run: |-' | 'run: |+')
          aguarda_base=1
          base=0
          ;;
      esac

      if [ "$continuando" -eq 0 ]; then
        case "$linha" in
          '      - name: '*)
            passo=$((passo + 1))
            printf '%s\t%s\tPASSO\t%s\n' "$n" "$passo" "$espremida"
            continue
            ;;
        esac

        case "$nu" in
          '#'*)
            printf '%s\t%s\tCOMENTARIO\t%s\n' "$n" "$passo" "$espremida"
            continue
            ;;
        esac
        acumulada="$sh_linha"
      else
        # LINHA FISICA QUE CONTINUA A ANTERIOR: o shell ja apagou a quebra, e o
        # comando e um so. A decisao vale sobre a linha LOGICA inteira.
        acumulada="$acumulada$sh_linha"
      fi

      # ABERTURA DE HEREDOC, decidida ANTES de imprimir a classe: uma linha que
      # esta leitura nao consegue decidir com seguranca NAO pode sair como
      # CODIGO, porque a classe dela e o que a guarda usa para responder.
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

      # BARRA INVERTIDA NO FIM DA LINHA apaga a QUEBRA: o comando segue na linha
      # fisica seguinte, que continua sendo CODIGO EXECUTAVEL e tem de ser
      # auditada como tal. Entrar em HEREDOC aqui escondia a continuacao inteira
      # (OS 40-R8, E3).
      if [ "$ABERTURA_CONTINUA" -eq 1 ]; then
        acumulada="${acumulada%\\}"
        continuando=1
        printf '%s\t%s\tCODIGO\t%s\n' "$n" "$passo" "$espremida"
        continue
      fi
      continuando=0

      if [ "$tem_op" -eq 1 ] && [ "$ABERTURA_AMBIGUA" -eq 1 ]; then
        printf '%s\t%s\tAMBIGUO\t%s\n' "$n" "$passo" "$espremida"
        acumulada=''
        continue
      fi

      printf '%s\t%s\tCODIGO\t%s\n' "$n" "$passo" "$espremida"
      if [ -n "$ABERTURA_HEREDOC" ]; then
        fim_heredoc="$ABERTURA_HEREDOC"
        her_tabs="$ABERTURA_TABS"
      fi
      acumulada=''
    done < "$arq"
  } > "$saida"
}

# `guarda_passo_zero <registro> <chave>` — exit 0 só quando a invocação oficial
# daquele passo zero está VIVA, ÚNICA, exata, no passo certo, precedida da purga
# da evidência anterior, ligada ao `tee` real, com o código de saída do PRODUTOR
# capturado logo em seguida, antes de quem consome a evidência dela, e sem que
# nenhuma outra linha do workflow escreva aquele log ou aquele marcador.
#
# É a propriedade decisiva da OS 40-C5, por extenso: texto, comentário, heredoc,
# `echo`, arquivo preexistente ou marcador fabricado NÃO substituem a execução.
#
# Cada recusa é NOMEADA e traz a chave. Uma guarda que responde "não" sem dizer
# qual das dez perguntas falhou, e para qual passo, é uma guarda que ninguém
# consegue consertar sem afrouxar.
guarda_passo_zero() {
  local reg="$1" chave="$2" ruim=0
  local invocacao captura nucleo purga log marcador passo_alvo
  local ln passo tipo texto nome_corrente='' nome_inv=''
  local linha_inv=0 passo_inv=0 vivas=0
  local linha_cap=0 passo_cap=0 capturas=0
  local linha_pur=0 passo_pur=0 purgas=0
  local passo_consumidor=0 entre=0

  if ! campo_do_passo "$chave" invocacao; then
    printf 'PASSO ZERO [%s]: a chave nao tem registro congelado nesta guarda\n' "$chave"
    return 1
  fi
  invocacao="$CAMPO"
  campo_do_passo "$chave" captura;  captura="$CAMPO"
  campo_do_passo "$chave" nucleo;   nucleo="$CAMPO"
  campo_do_passo "$chave" purga;    purga="$CAMPO"
  campo_do_passo "$chave" log;      log="$CAMPO"
  campo_do_passo "$chave" marcador; marcador="$CAMPO"
  campo_do_passo "$chave" passo;    passo_alvo="$CAMPO"

  while IFS=$'\t' read -r ln passo tipo texto; do
    case "$tipo" in
      PASSO)
        nome_corrente="$texto"
        ;;
      CODIGO)
        if [ "$texto" = "$invocacao" ]; then
          vivas=$((vivas + 1))
          if [ "$linha_inv" -eq 0 ]; then
            linha_inv="$ln"; passo_inv="$passo"; nome_inv="$nome_corrente"
          fi
        fi
        if [ "$texto" = "$captura" ]; then
          capturas=$((capturas + 1))
          [ "$linha_cap" -eq 0 ] && { linha_cap="$ln"; passo_cap="$passo"; }
        fi
        if [ "$texto" = "$purga" ]; then
          purgas=$((purgas + 1))
          [ "$linha_pur" -eq 0 ] && { linha_pur="$ln"; passo_pur="$passo"; }
        fi
        case "$texto" in
          *"$nucleo"*)
            if [ "$texto" != "$invocacao" ]; then
              printf 'PASSO ZERO [%s]: chamada do produtor com forma NAO OFICIAL na linha %s: %s\n' \
                "$chave" "$ln" "$texto"
              ruim=1
            fi
            case "$texto" in
              echo*|printf*|*'echo '*"$nucleo"*|*'printf '*"$nucleo"*)
                printf 'PASSO ZERO [%s]: a linha %s IMPRIME a invocacao em vez de executa-la: %s\n' \
                  "$chave" "$ln" "$texto"
                ruim=1
                ;;
            esac
            case "$texto" in
              *'|| true'*|*'|| :'*|*'||true'*|*'|| /bin/true'*|*'|| echo'*|*'; true'*|*'|| exit 0'*)
                printf 'PASSO ZERO [%s]: a linha %s neutraliza o codigo de saida do produtor: %s\n' \
                  "$chave" "$ln" "$texto"
                ruim=1
                ;;
            esac
            ;;
        esac
        # A EVIDÊNCIA SÓ NASCE DA INVOCAÇÃO OFICIAL. Fora da tríade
        # purga/invocação/captura, nenhuma linha viva pode tocar `t_<chave>.log`
        # nem escrever `exit_<chave>`: foi por aí que a R5 entrou — a autoridade
        # não rodou, e o log e o marcador foram fabricados por um `echo`.
        if [ "$texto" != "$invocacao" ] && [ "$texto" != "$captura" ] && [ "$texto" != "$purga" ]; then
          case "$texto" in
            *"$log"* | *"> $marcador"* | *">$marcador"*)
              printf 'PASSO ZERO [%s]: a linha %s escreve a evidencia de %s fora da invocacao oficial: %s\n' \
                "$chave" "$ln" "$chave" "$texto"
              ruim=1
              ;;
          esac
        fi
        case "$texto" in
          *"$CONSUMIDOR_DA_EVIDENCIA"*)
            [ "$passo_consumidor" -eq 0 ] && passo_consumidor="$passo"
            ;;
        esac
        ;;
      COMENTARIO | HEREDOC)
        case "$texto" in
          *"$nucleo"*)
            printf 'PASSO ZERO [%s]: a invocacao aparece como %s na linha %s — texto nao executa: %s\n' \
              "$chave" "$tipo" "$ln" "$texto"
            ruim=1
            ;;
        esac
        ;;
    esac
  done < "$reg"

  if [ "$vivas" -eq 0 ]; then
    printf 'PASSO ZERO [%s]: o workflow nao tem a invocacao oficial VIVA: %s\n' "$chave" "$invocacao"
    ruim=1
  elif [ "$vivas" -gt 1 ]; then
    printf 'PASSO ZERO [%s]: a invocacao oficial aparece %s vezes — duplicada, e o exit lido nao e o de ninguem\n' \
      "$chave" "$vivas"
    ruim=1
  fi

  if [ "$capturas" -ne 1 ]; then
    printf 'PASSO ZERO [%s]: a captura oficial do codigo de saida aparece %s vez(es): %s\n' \
      "$chave" "$capturas" "$captura"
    ruim=1
  fi

  # A PURGA DA EVIDÊNCIA ANTERIOR. Sem ela, um `t_<chave>.log` e um
  # `exit_<chave>` que sobrevivam ao checkout viram evidência desta corrida — e
  # `atime` não serve de prova, porque a FASE A ABRE o log durante as próprias
  # leituras: acesso não é execução.
  if [ "$purgas" -ne 1 ]; then
    printf 'PASSO ZERO [%s]: a purga da evidencia anterior aparece %s vez(es): %s\n' \
      "$chave" "$purgas" "$purga"
    ruim=1
  fi

  if [ "$linha_inv" -gt 0 ]; then
    # O PASSO CERTO. Mover a invocação para outro passo a tira do lugar em que a
    # evidência é produzida antes de ser consumida — e trocar o TÍTULO do passo,
    # mantendo o código, é a mesma sabotagem pela outra ponta.
    case "$nome_inv" in
      *"\"$passo_alvo "*) ;;
      *)
        printf 'PASSO ZERO [%s]: a invocacao esta no passo "%s", e nao no passo %s\n' \
          "$chave" "$nome_inv" "$passo_alvo"
        ruim=1
        ;;
    esac

    # A CAPTURA VEM LOGO DEPOIS, no mesmo passo, e SEM NADA NO MEIO. Uma linha
    # entre as duas troca o `PIPESTATUS` que é lido: o exit deixa de ser o do
    # produtor sem que uma letra da invocação mude.
    if [ "$linha_cap" -le "$linha_inv" ] || [ "$passo_cap" -ne "$passo_inv" ]; then
      printf 'PASSO ZERO [%s]: a captura do codigo de saida nao vem logo depois da invocacao (linha %s contra %s)\n' \
        "$chave" "$linha_cap" "$linha_inv"
      ruim=1
    else
      entre="$(awk -F'\t' -v a="$linha_inv" -v b="$linha_cap" \
        '$3 == "CODIGO" && $1 > a && $1 < b { n++ } END { print n + 0 }' "$reg")"
      if [ "$entre" -ne 0 ]; then
        printf 'PASSO ZERO [%s]: ha %s linha(s) de codigo entre a invocacao e a captura do PIPESTATUS\n' \
          "$chave" "$entre"
        ruim=1
      fi
    fi

    # A PURGA VEM ANTES, no mesmo passo, e também SEM NADA NO MEIO. Purga depois
    # da execução apaga a evidência recém-produzida; purga em outro passo não
    # garante ordem nenhuma.
    if [ "$linha_pur" -eq 0 ] || [ "$linha_pur" -ge "$linha_inv" ] || [ "$passo_pur" -ne "$passo_inv" ]; then
      printf 'PASSO ZERO [%s]: a purga nao vem antes da invocacao, no mesmo passo (linha %s contra %s)\n' \
        "$chave" "$linha_pur" "$linha_inv"
      ruim=1
    else
      entre="$(awk -F'\t' -v a="$linha_pur" -v b="$linha_inv" \
        '$3 == "CODIGO" && $1 > a && $1 < b { n++ } END { print n + 0 }' "$reg")"
      if [ "$entre" -ne 0 ]; then
        printf 'PASSO ZERO [%s]: ha %s linha(s) de codigo entre a purga e a invocacao\n' "$chave" "$entre"
        ruim=1
      fi
    fi

    # ANTES DE QUEM CONSOME. A FASE A e a FASE B leem o que este passo produziu.
    if [ "$passo_consumidor" -eq 0 ]; then
      printf 'PASSO ZERO [%s]: o workflow nao tem nenhum consumidor vivo de %s\n' \
        "$chave" "$CONSUMIDOR_DA_EVIDENCIA"
      ruim=1
    elif [ "$passo_inv" -ge "$passo_consumidor" ]; then
      printf 'PASSO ZERO [%s]: a invocacao (passo %s) nao vem antes de quem consome a evidencia dela (passo %s)\n' \
        "$chave" "$passo_inv" "$passo_consumidor"
      ruim=1
    fi
  fi

  return "$ruim"
}

# `guarda_passo_zero_sem_relacao <registro>` — nenhum passo zero pode produzir
# evidência obrigatória sem estar na relação congelada acima.
#
# É o que fecha a saída de emergência da tabela manual: acrescentar um passo
# `0d` que escreve `exit_<gate>` e não é guardado por ninguém seria repetir a
# R5 com outro nome. A relação é a autoridade; o workflow é o guardado.
guarda_passo_zero_sem_relacao() {
  local reg="$1" ruim=0
  local ln passo tipo texto nome_corrente='' chave achou k
  while IFS=$'\t' read -r ln passo tipo texto; do
    if [ "$tipo" = "PASSO" ]; then
      nome_corrente="$texto"
      continue
    fi
    [ "$tipo" = "CODIGO" ] || continue
    case "$nome_corrente" in
      '- name: "0'*) ;;
      *) continue ;;
    esac
    case "$texto" in
      *'> exit_'*) ;;
      *) continue ;;
    esac
    chave="${texto##*> exit_}"
    chave="${chave%% *}"
    chave="${chave%%;*}"
    # A ASPA SAI POR VARIÁVEL, e não por barra invertida dentro de `"..."` — a
    # mesma armadilha que `classificar_workflow` documenta logo acima. Escrito
    # como `\"` aqui, o analisador léxico do contrato de conteúdo lê a linha
    # seguinte como string aberta, e doze declarações desta suíte deixam de ser
    # contadas: o piso de `provas` cai sem que uma linha suma do arquivo.
    chave="${chave%%$ASPA_DUPLA*}"
    achou=0
    for k in $PASSOS_ZERO_PROTEGIDOS; do
      [ "$k" = "$chave" ] && achou=1
    done
    if [ "$achou" -eq 0 ]; then
      printf 'PASSO ZERO: o passo %s produz "exit_%s" na linha %s e a chave nao esta na relacao protegida (%s)\n' \
        "$nome_corrente" "$chave" "$ln" "$PASSOS_ZERO_PROTEGIDOS"
      ruim=1
    fi
  done < "$reg"
  return "$ruim"
}

# `guarda_invocacao_passo_zero <yml>` — a guarda inteira, sobre todas as chaves.
#
# O YAML é classificado UMA vez e percorrido por chave: são novecentas linhas, e
# reclassificar por chave triplicaria o custo da guarda que a FASE A também
# chama, no caminho oficial, a cada execução.
guarda_invocacao_passo_zero() {
  local yml="$1" reg="$TMP/classificado.txt" k ruim=0
  classificar_workflow "$yml" "$reg"
  # LINHA INDECIDIVEL REPROVA (OS 40-C7). Uma citacao que nao fecha, duas
  # aberturas na mesma linha ou um delimitador que esta leitura nao sabe
  # representar sao motivo de RECUSA, e nao de escolha silenciosa de classe.
  local ambiguas
  ambiguas="$(awk -F'	' '$3 == "AMBIGUO" { printf "%s ", $1 }' "$reg")"
  if [ -n "$ambiguas" ]; then
    printf 'PASSO ZERO: linha(s) que a leitura lexica nao consegue decidir com seguranca: %s
' "$ambiguas"
    ruim=1
  fi
  for k in $PASSOS_ZERO_PROTEGIDOS; do
    guarda_passo_zero "$reg" "$k" || ruim=1
  done
  guarda_passo_zero_sem_relacao "$reg" || ruim=1
  return "$ruim"
}

# MODO `--guarda`: só a autoridade léxica dos passos zero, sobre o YAML
# informado, e nada mais.
#
# É por aqui que o CAMINHO OFICIAL chama esta guarda uma segunda vez, de dentro
# da FASE A do contrato de conteúdo — que roda sob `bash -e` e derruba o job.
# Sem esse segundo chamador, desligar a guarda seria desligar o `portaoci`, e
# `portaoci` é o passo `0`: quem apaga o passo apaga quem reclamaria dele. NÃO É
# UM SEGUNDO ANALISADOR — é o mesmo arquivo, o mesmo classificador e a mesma
# relação congelada, chamados de dois lugares.
if [ "$MODO_GUARDA" -eq 1 ]; then
  guarda_invocacao_passo_zero "$YML_GUARDA"
  exit $?
fi

printf '== invariantes da fonte única ==\n'

# A fonte tem que continuar declarando TODO gate que já era obrigatório antes
# desta OS. Remover um deles é uma regressão silenciosa de cobertura.
#
# [COMPOSICAO canonica] `regras` saiu desta lista e entrou `colecoesemu`, e a
# GUARDA NÃO AFROUXOU: é a mesma suíte, sob o único nome que algum passo do
# workflow de fato produz. O gate foi renomeado em `c86aa9d`; esta fonte única
# nasceu depois, em `835fe99`, já com o nome velho — um erro de transcrição, e
# não um gate perdido. Como `regras` nunca teve produtor, o agregador o via
# como "NÃO EXECUTADO" e reprovava: o portão não tinha como ficar verde por um
# fantasma, que é justamente a pressão que leva alguém a afrouxar o agregador.
#
# Trocar o nome aqui mantém intacto o que I1 protege — a suíte das Rules não
# pode sair da fonte única em silêncio —, e PN-10 passou a exigir, por si, que
# nenhum gate declarado fique sem produtor.
HERDADOS="analyze motor resil encerr torneios mtorneios integr colarte colfire \
colkit social casca cascaaud billing torneiosfn socialdom socialfn socialemu colecoesemu"
faltando=""
for g in $HERDADOS; do
  contem_gate "$g" || faltando="$faltando $g"
done
if [ -z "$faltando" ]; then
  ok "I1 — os 19 gates herdados continuam na fonte única"
else
  nok "I1 — gate herdado removido da fonte única:$faltando"
fi

# Os quatro do defeito CI-02: executavam e o agregador não os percorria.
faltando=""
for g in rankingfn rankingint identint auditident; do
  contem_gate "$g" || faltando="$faltando $g"
done
if [ -z "$faltando" ]; then
  ok "I2 — rankingfn/rankingint/identint/auditident são obrigatórios (CI-02)"
else
  nok "I2 — gate do CI-02 fora da fonte única:$faltando"
fi

# As suítes que esta OS traz para dentro do portão (CI-01).
faltando=""
for g in cascavisao cascamesaaud cascav2 cascaligacao cascamesa cascaporta \
         rkbarreira rkestado rkperfil rkleitor rkregressao composicao portaoci; do
  contem_gate "$g" || faltando="$faltando $g"
done
if [ -z "$faltando" ]; then
  ok "I3 — as 12 suítes novas + o teste do portão são obrigatórios (CI-01)"
else
  nok "I3 — suíte nova fora da fonte única:$faltando"
fi

# A suíte TRANSACIONAL do passe de cortesia. Obrigatória, e com produtor no
# YAML: sem uma das duas coisas ela é uma suíte que roda sem ninguém ler, que
# é exatamente o defeito CI-02.
if contem_gate passeint; then
  ok "I4a — passeint (transação do passe) é obrigatório na fonte única"
else
  nok "I4a — passeint saiu da fonte única; a suíte transacional do passe ficou sem portão"
fi

if grep -q "exit_passeint" "$YML" && grep -q "nao_passeint" "$YML"; then
  ok "I4b — o YAML produz exit_passeint e prova a ausência com nao_passeint"
else
  nok "I4b — o YAML não produz exit_passeint e/ou não escreve nao_passeint quando a suíte some"
fi

# O gerador de PNG continua FORA do portão, como decidido antes desta OS.
if contem_gate colevid; then
  nok "I4 — colevid entrou no portão; ele é informativo por decisão registrada"
else
  ok "I4 — colevid segue informativo, fora da fonte única"
fi

# Fonte única de verdade: o YAML não pode carregar uma segunda cópia da lista.
# Este é o caso que a mutação "manter listas diferentes entre evidência e
# agregador" derruba.
if grep -qE 'for k in [a-z]+ [a-z]+ [a-z]+' "$YML" \
   || grep -qE 'GATES="[a-z]+ [a-z]+' "$YML"; then
  nok "I5 — o YAML ainda tem uma lista de gates embutida; a fonte deixou de ser única"
else
  ok "I5 — o YAML não embute lista de gates"
fi

if grep -q 'scripts/ci/gates_os_integracao.txt' "$YML" \
   && grep -q 'scripts/ci/portao_os_integracao.sh' "$YML"; then
  ok "I6 — evidência e agregador apontam para a fonte única no YAML"
else
  nok "I6 — o YAML não referencia a fonte única e/ou o agregador"
fi

# O YAML tem que PARSEAR. Um workflow invalido nao roda gate nenhum — e o
# GitHub ainda cria um run vermelho de ZERO jobs, que se parece com falha de
# teste sem ser. Foi assim que esta OS perdeu dois runs: uma continuacao com
# barra invertida deixou uma linha na coluna 0, e uma linha na coluna 0 encerra
# o bloco escalar do `run:` e invalida o arquivo inteiro.
#
# Checagem sem rede e sem dependencia: fora as chaves de topo e os comentarios,
# nenhuma linha do workflow pode comecar na coluna 0.
intrusas="$(grep -nE '^[^ #]' "$YML" \
  | grep -vE '^[0-9]+:(name|on|permissions|jobs|env|defaults|concurrency|run-name):' || true)"
if [ -z "$intrusas" ]; then
  ok "I7 — nenhuma linha na coluna 0 quebra um bloco do YAML"
else
  nok "I7 — linha na coluna 0 invalida o YAML (encerra o bloco de \`run:\`):"
  printf '%s\n' "$intrusas" | sed 's/^/        | /'
fi

# OS COMPOSIÇÃO LOJA/CASCA + FUNCTIONS. Os DOIS lados editaram esta fonte
# única, em hunks diferentes, e é aqui que um `ours`/`theirs` sobre o arquivo
# inteiro apagaria os gates de um deles sem produzir conflito nenhum para
# investigar. I8 quebra nos DOIS sentidos, de propósito: é o que faz o teste do
# portão reprovar quando metade da composição some.
faltando=""
for g in cascaloja rkpagina composloja; do
  contem_gate "$g" || faltando="$faltando $g"
done
if [ -z "$faltando" ]; then
  ok "I8a — a composição da Loja é obrigatória (cascaloja/rkpagina/composloja)"
else
  nok "I8a — lado da LOJA amputado da fonte única:$faltando"
fi

faltando=""
for g in contafn contaemu mesasfn economiafn proveni composneg; do
  contem_gate "$g" || faltando="$faltando $g"
done
if [ -z "$faltando" ]; then
  ok "I8b — a composição das Functions canônicas é obrigatória"
else
  nok "I8b — lado das FUNCTIONS amputado da fonte única:$faltando"
fi

# Produtor sem alvo é o degrau seguinte ao gate fantasma: o passo existe, o
# agregador percorre, e a suíte que ele diz rodar não está mais lá.
if grep -q 'ferramentas/composicao/loja_functions.test.js' "$YML" \
   && grep -q 'roda rkpagina' "$YML" \
   && grep -q 'fetch-depth: 0' "$YML"; then
  ok "I8c — o YAML produz composloja/rkpagina, e o checkout é fundo"
else
  nok "I8c — falta o produtor da composição no YAML e/ou o checkout deixou de ser fundo"
fi

# -----------------------------------------------------------------------------
# OS 32 — a fonte única passou a carregar CONTRATO DE CONTEÚDO, e o YAML deixou
# de ter até a forma de uma segunda autoridade.
# -----------------------------------------------------------------------------

# I5 pega a lista literal. I9 pega o degrau anterior: a CONSTRUÇÃO. Uma
# atribuição `GATES=` que não derive do produtor canônico, ou um `for k in` que
# itere qualquer coisa que não seja a expansão de uma variável, é o YAML voltando
# a decidir quais gates existem — mesmo que a lista ainda esteja curta hoje.
mau_gates="$(grep -nE '^[[:space:]]*GATES=' "$YML" | grep -vE 'GATES="\$\(' || true)"
mau_laco="$(grep -nE '^[[:space:]]*for k in ' "$YML" | grep -vE 'for k in \$[A-Za-z_]' || true)"
if [ -z "$mau_gates" ] && [ -z "$mau_laco" ]; then
  ok "I9 — no YAML, \`GATES=\` deriva do produtor e \`for k in\` itera variável"
else
  nok "I9 — o YAML voltou a construir a relação de gates por conta própria:"
  printf '%s\n' "$mau_gates" "$mau_laco" | grep . | sed 's/^/        | /'
fi

# O produtor canônico tem de ser QUEM o YAML chama. Sem isto, I9 ficaria verde
# num workflow que não lê a fonte de jeito nenhum.
if grep -q 'portao_os_integracao.sh --listar' "$YML"; then
  ok "I9b — a evidência lê a fonte pelo produtor canônico (\`--listar\`)"
else
  nok "I9b — o passo de evidência não chama mais \`portao_os_integracao.sh --listar\`"
fi

# O verificador de CONTEÚDO e a matriz dele. `contratosui` sem produtor seria
# gate fantasma; produtor sem gate seria CI-02 outra vez.
#
# A INVOCAÇÃO DO PASSO ZERO NÃO É MAIS UM `grep`, e a razão está medida. Até a
# OS 40-C3 esta prova procurava a linha `bash scripts/ci/teste_contrato_suites.sh`
# — a chamada DIRETA à matriz. A C3 trocou o executor pela TESTEMUNHA EXTERNA,
# que passou a receber a matriz como argumento, e a agulha deixou de casar: o
# `portaoci` reprovou a árvore íntegra, e a rehomologação OS 40-R4 encerrou em
# FAIL por regressão fail-closed. Um portão que reprova o repositório correto é
# a pressão mais forte que existe para alguém afrouxar o portão.
#
# A correção não é atualizar a agulha. Uma agulha textual não distingue a linha
# VIVA da linha comentada, da que está dentro de um `echo`, da que mora num
# heredoc, da duplicada, nem da que foi movida para outro passo — e cada uma
# dessas é uma forma de desligar a testemunha conservando o texto. Quem responde
# é `guarda_invocacao_passo_zero`, definida acima: ela classifica o YAML linha a
# linha e cobra a invocação oficial VIVA, ÚNICA, com os argumentos exatos, no
# passo correto, ligada ao `tee` real, antes de quem consome a evidência dela, e
# sem nada entre a chamada e a captura do código de saída.
#
# [OS 40-C5] A guarda deixou de valer só para o `0b`. A R5 mostrou que a MESMA
# forja aplicada ao `0a` — execução retirada, `t_autverif.log` e `exit_autverif`
# fabricados — atravessava a cadeia oficial inteira em verde. A pergunta passou
# a ser feita para TODOS os passos zero protegidos, e um passo zero que produza
# evidência sem estar na relação congelada também reprova.
faltando=""
contem_gate contratosui || faltando=" contratosui-fora-da-fonte"
contem_gate autverif    || faltando="$faltando autverif-fora-da-fonte"
contem_gate portaoci    || faltando="$faltando portaoci-fora-da-fonte"
guarda_invocacao_passo_zero "$YML" > "$TMP/i10.txt" 2>&1 \
  || faltando="$faltando invocacao-de-passo-zero-desligada"
[ "$(grep -c 'scripts/ci/verificar_contrato_suites\.sh' "$YML")" -ge 2 ] \
  || faltando="$faltando verificador-sem-as-duas-fases"
grep -qE 'verificar_contrato_suites\.sh [^|]*\.github/workflows/ci-os-integracao\.yml \.$' "$YML" \
  || faltando="$faltando fase-B-ausente"
if [ -z "$faltando" ]; then
  ok "I10 — o contrato de conteúdo tem gate, invocação oficial viva e as duas fases no YAML"
else
  nok "I10 — a guarda de conteúdo foi desligada:$faltando"
  sed 's/^/        | /' "$TMP/i10.txt"
fi

# E a fonte única tem de continuar carregando o contrato das suítes protegidas.
# Esta é a metade textual da garantia; a comportamental é o gate `contratosui`.
sem_contrato=""
for g in comunicacao chatdom portaoci contratosui; do
  awk -v alvo="$g" '
    $0 == alvo { dentro = 1; next }
    dentro && /^[[:blank:]]+suite[[:blank:]]/ { achou = 1 }
    dentro && /^[^[:blank:]#]/ { dentro = 0 }
    END { exit(achou ? 0 : 1) }
  ' "$FONTE" || sem_contrato="$sem_contrato $g"
done
if [ -z "$sem_contrato" ]; then
  ok "I11 — as quatro suítes protegidas continuam com contrato na fonte única"
else
  nok "I11 — suíte protegida sem contrato de conteúdo na fonte única:$sem_contrato"
fi

printf '\n== a invocação de cada passo zero, sabotada de vinte maneiras ==\n'

# UMA GUARDA QUE NUNCA REPROVOU NÃO É GUARDA. I10 prova que a árvore íntegra
# passa; sem os vetores abaixo, um `guarda_invocacao_passo_zero` que devolvesse
# zero para tudo passaria em I10 do mesmo jeito — e foi exatamente assim que a
# invocação oficial ficou sem prova nenhuma entre a C3 e a R4, e assim que a
# invocação do passo `0a` ficou sem prova nenhuma entre a C4 e a R5.
#
# Cada vetor parte de uma CÓPIA descartável do workflow íntegro, declara quantas
# invocações oficiais devem restar, aplica UMA sabotagem e confere a
# pós-condição antes de julgar. Uma sabotagem que não aconteceu não pode virar
# verde: é o mesmo instrumento que `teste_contrato_suites.sh` usa, e pela mesma
# razão.
#
# O CASAMENTO É POR LINHA ESPREMIDA, e não por expressão regular. Foi assim que
# a agulha da C3 envelheceu: uma ERE escrita à mão deixou de casar quando o
# executor mudou, o portão reprovou a árvore íntegra e a OS 40-R4 encerrou em
# FAIL por regressão fail-closed. Aqui a âncora é o MESMO literal congelado que
# a guarda cobra — se um envelhecer, os dois envelhecem juntos, e o controle
# `00` acusa antes de qualquer vetor mentir.

# ---------------------------------------------------------------------------
# A FALSA ABERTURA DE HEREDOC — o instrumento da OS 40-C6
# ---------------------------------------------------------------------------
#
# O PAR `menor-menor` É MONTADO, e nunca escrito colado neste arquivo fora de
# string. Não é estilo: o leitor de código vivo da autoridade externa procura o
# par por texto, e um par solto aqui abriria para ele um heredoc que nunca
# fecha — o arquivo inteiro viraria dado, e as decisões materiais desta suíte
# apareceriam zero vezes num repositório intacto.
MENOR2='<''<'

# A OCORRÊNCIA TEXTUAL QUE NÃO É ABERTURA. O resto depois do par é `$ALVO`, e
# `$` não é caractere de identificador — logo, não é delimitador de heredoc,
# nem para `vivas_de` nem, desde a OS 40-C6, para `classificar_workflow`. Era
# com uma linha desta forma que a OS 40-R6 cegava o classificador: tudo o que
# vinha depois virava HEREDOC, a contagem de passos congelava, e a escrita
# posterior de um log ou de um marcador deixava de ser inspecionada.
FALSA_ABERTURA="echo \"deslocamento $MENOR2 \$ALVO\""

# A OCORRÊNCIA QUE A OS 40-C6 AINDA DEIXAVA PASSAR — e a razão desta OS. Aqui o
# resto depois do par é um IDENTIFICADOR PURO, e a aspa que o fecha era apagada
# antes da decisão: `echo "diagnostico <<ALVO"` virava, para as duas leituras,
# a mesma coisa que `cat <<ALVO`. O shell executa a linha seguinte; elas
# jogavam o resto do arquivo na classe HEREDOC.
FALSA_ABERTURA_CITADA="echo \"diagnostico ${MENOR2}ALVO\""

# A MESMA FORMA, ENTRE ASPAS SIMPLES. A `HD03` da C6 usava um resto que já era
# recusado por outro motivo (a aspa sobrava sozinha); esta usa o caso que
# escapava, e num comando que o CI de fato roda.
FALSA_ABERTURA_SIMPLES="grep -n '${MENOR2}ALVO' scripts/ci/portao_os_integracao.sh"

# A ENTRADA QUE NÃO PODE SER DECIDIDA: a citação não fecha na linha, e com ela
# não há como saber com que estado a próxima linha começaria. Fail-closed
# explícito é a única saída honesta — escolher uma leitura aqui seria escolher
# por conveniência.
LINHA_AMBIGUA="echo \"abre ${MENOR2}FIM"

# [OS 40-C8] ANSI-C QUOTING. `$'...'` nao e aspa simples crua: ali a barra
# invertida ESCAPA o proximo caractere, inclusive a aspa. A OS 40-R8 (E1) usou
# exatamente esta linha para fechar a citacao cedo, achar o par em contexto de
# codigo e jogar a linha SEGUINTE — que o shell executa — na classe HEREDOC.
FALSA_ABERTURA_ANSI="echo \$'a\\'b ${MENOR2}true '"

# [OS 40-C8] CONTINUACAO FISICA DE LINHA. A barra invertida no fim apaga a
# QUEBRA: o comando segue na linha fisica seguinte, que ainda EXECUTA. Entrar
# em HEREDOC ao fim da primeira escondia a continuacao inteira (OS 40-R8, E3).
CONTINUACAO_ABERTA="cat ${MENOR2}FIM_DA_SONDA \\"

FORJA_ARQ=''
FORJA_DIG=''
FORJA_MOTIVO=''
FORJA_CHAVE=''

# `conta_linha <arquivo> <literal>` — quantas linhas do arquivo, lidas como o
# classificador as lê (sem `\r`, sem recuo, brancos espremidos), são EXATAMENTE
# aquele literal.
conta_linha() {
  ALVO_LIT="$2" awk '
    function esp(s,   l) {
      l = s; sub(/\r$/, "", l); gsub(/\t/, " ", l)
      sub(/^ +/, "", l); gsub(/  +/, " ", l); sub(/ +$/, "", l)
      return l
    }
    esp($0) == ENVIRON["ALVO_LIT"] { n++ }
    END { print n + 0 }
  ' "$1"
}

# `forjar_passo <chave> <nome>` — a cópia íntegra, com a âncora conferida ANTES
# da sabotagem: a invocação oficial daquela chave tem de casar exatamente uma
# vez. Âncora que casa outro número é âncora que envelheceu, e medir com ela é
# medir outra coisa.
forjar_passo() {
  local viu
  FORJA_CHAVE="$1"
  FORJA_ARQ="$TMP/$2"
  FORJA_DIG=''
  FORJA_MOTIVO=''
  cp "$YML" "$FORJA_ARQ"
  if ! campo_do_passo "$FORJA_CHAVE" invocacao; then
    FORJA_MOTIVO="a chave '$FORJA_CHAVE' nao tem registro congelado"
    return 1
  fi
  viu="$(conta_linha "$FORJA_ARQ" "$CAMPO")"
  if [ "$viu" -ne 1 ]; then
    FORJA_MOTIVO="a invocacao oficial de '$FORJA_CHAVE' casa $viu vez(es) na copia integra"
    return 1
  fi
  FORJA_DIG="$(tr -d '\r' < "$FORJA_ARQ" | sha256sum)"
  return 0
}

# `sabotar <modo> [extra] [extra2]` — UMA transformação sobre a cópia.
#
# Todos os modos localizam a linha pela forma espremida, e não por posição nem
# por regex: o YAML alinha em colunas, e uma sonda presa ao alinhamento mede a
# tabela, não o programa.
sabotar() {
  [ -n "$FORJA_MOTIVO" ] && return 1
  campo_do_passo "$FORJA_CHAVE" invocacao
  MODO_SAB="$1" EXTRA_SAB="${2:-}" EXTRA2_SAB="${3:-}" ALVO_SAB="$CAMPO" awk '
    function esp(s,   l) {
      l = s; sub(/\r$/, "", l); gsub(/\t/, " ", l)
      sub(/^ +/, "", l); gsub(/  +/, " ", l); sub(/ +$/, "", l)
      return l
    }
    { n++; li = $0; sub(/\r$/, "", li); L[n] = li }
    END {
      modo = ENVIRON["MODO_SAB"]
      extra = ENVIRON["EXTRA_SAB"]
      extra2 = ENVIRON["EXTRA2_SAB"]
      alvo = ENVIRON["ALVO_SAB"]
      inv = 0; tit = 0; guardada = ""
      for (i = 1; i <= n; i++) if (esp(L[i]) == alvo) { inv = i; break }
      for (i = inv; i >= 1; i--) if (L[i] ~ /^      - name: /) { tit = i; break }
      for (i = 1; i <= n; i++) {
        match(L[i], /^ */); rec = substr(L[i], 1, RLENGTH)
        if (modo == "titulo" && i == tit) {
          print "      - name: \"9z — passo renomeado pela sonda\""
          continue
        }
        if ((modo == "apagar_outra" || modo == "purga_depois") && esp(L[i]) == extra) continue
        if (modo == "trocar_outra" && esp(L[i]) == extra) { print rec extra2; continue }
        if (i == inv) {
          if (modo == "apagar")   continue
          if (modo == "trocar")   { print rec extra; continue }
          if (modo == "duplicar") { print L[i]; print L[i]; continue }
          # O `<` `<` SAI PARTIDO, e nao por estilo: o leitor de codigo vivo da
          # autoridade externa procura `<<` por texto, e um par colado AQUI
          # abriria para ela um heredoc que nunca fecha — o arquivo inteiro
          # viraria dado, e as decisoes materiais desta suite apareceriam zero
          # vezes num repositorio intacto.
          if (modo == "heredoc")  { print rec "cat <" "<FIM_DA_FORJA > /dev/null"; print L[i]; print "FIM_DA_FORJA"; continue }
          # [OS 40-C8] O MESMO EMBRULHO COM O TERMINADOR INDENTADO. Sem `<<-` o
          # shell so fecha o corpo com o delimitador na COLUNA ZERO; dois espacos
          # a mais nao fecham nada, e a invocacao segue sendo dado. Comparar o
          # terminador contra a linha aparada fazia esta forma parecer viva
          # (OS 40-R8, E2).
          if (modo == "heredoc_ind") { print rec "cat <" "<FIM_DA_FORJA > /dev/null"; print rec "  FIM_DA_FORJA"; print L[i]; print rec "FIM_DA_FORJA"; continue }
          if (modo == "mover")    { guardada = L[i]; continue }
          if (modo == "antes")    { print rec extra; print L[i]; continue }
          if (modo == "depois")   { print L[i]; print rec extra; continue }
        }
        # [OS 40-C6] `prologo` — o bloco entra ANTES do primeiro passo do
        # workflow, e nao colado na invocacao: uma ocorrencia textual anterior
        # so mede o que se quer medir se ela nao violar, de quebra, a ordem
        # purga/invocacao/captura que a guarda ja cobrava.
        if (modo == "prologo" && posto == 0 && L[i] ~ /^      - name: /) {
          m = split(extra, PART, "~")
          for (j = 1; j <= m; j++) print PART[j]
          posto = 1
        }
        print L[i]
        if (modo == "purga_depois" && esp(L[i]) == extra2) print rec extra
        if (modo == "mover" && guardada != "" && L[i] ~ /flutter analyze --no-fatal-infos/) {
          print guardada; guardada = ""
        }
      }
      # [OS 40-C6] `apendice` — o bloco entra DEPOIS de tudo, inclusive depois
      # de quem consome a evidencia. E a posicao em que a OS 40-R6 fez o
      # escape material: com a falsa abertura ali, a guarda parava de enxergar
      # a linha seguinte e a cadeia oficial ficava verde.
      if (modo == "apendice") {
        m = split(extra, PART, "~")
        for (j = 1; j <= m; j++) print PART[j]
      }
    }
  ' "$FORJA_ARQ" > "$FORJA_ARQ.novo" && mv "$FORJA_ARQ.novo" "$FORJA_ARQ"
}

# `esperar_passo <exit> <desc> <invocações restantes | -> [agulha]` — o veredito.
#
# `-` significa CONTROLE: a cópia não pode ter mudado um byte. Sem controle, uma
# guarda que reprovasse SEMPRE passaria em todos os vetores e a seção inteira
# deixaria de medir.
esperar_passo() {
  local esperado="$1" desc="$2" n="$3" agulha="${4:-}" real agora viu
  if [ -n "$FORJA_MOTIVO" ]; then
    nok "$desc — INSTRUMENTO INVÁLIDO: $FORJA_MOTIVO"
    return
  fi
  agora="$(tr -d '\r' < "$FORJA_ARQ" | sha256sum)"
  if [ "$n" = "-" ]; then
    if [ "$agora" != "$FORJA_DIG" ]; then
      nok "$desc — INSTRUMENTO INVÁLIDO: o controle mudou o workflow, e ele não devia mudar"
      return
    fi
  else
    if [ "$agora" = "$FORJA_DIG" ]; then
      nok "$desc — INSTRUMENTO INVÁLIDO: a sabotagem não mudou um byte da cópia"
      return
    fi
    campo_do_passo "$FORJA_CHAVE" invocacao
    viu="$(conta_linha "$FORJA_ARQ" "$CAMPO")"
    if [ "$viu" -ne "$n" ]; then
      nok "$desc — INSTRUMENTO INVÁLIDO: a invocação oficial aparece $viu vez(es), e o vetor declara $n"
      return
    fi
  fi
  guarda_invocacao_passo_zero "$FORJA_ARQ" > "$TMP/guarda.txt" 2>&1
  real=$?
  if [ "$real" != "$esperado" ]; then
    nok "$desc — esperado exit $esperado, obtido $real"
    sed 's/^/        | /' "$TMP/guarda.txt"
    return
  fi
  if [ -n "$agulha" ] && ! grep -qF "$agulha" "$TMP/guarda.txt"; then
    nok "$desc — exit $real correto, mas a recusa não é a esperada (/$agulha/)"
    sed 's/^/        | /' "$TMP/guarda.txt"
    return
  fi
  ok "$desc (exit $real)"
}

# `esperar_classe <arquivo> <linha espremida> <classe> <descrição>` — a
# PÓS-CONDIÇÃO INDEPENDENTE de cada falsa abertura (OS 40-C6).
#
# Contar só o exit do arnês não basta, e a OS 40-R6 mostrou por quê: um vetor
# de falsa abertura pode terminar VERMELHO por efeito colateral — porque a
# cegueira escondeu, de quebra, a própria invocação canônica — e ficar verde
# sem que a linha decisiva tenha sido sequer olhada. Aqui a pergunta é direta:
# em que classe o classificador pôs AQUELA linha.
esperar_classe() {
  local arq="$1" alvo="$2" esperada="$3" desc="$4" vista
  if [ -n "$FORJA_MOTIVO" ]; then
    nok "$desc — INSTRUMENTO INVÁLIDO: $FORJA_MOTIVO"
    return
  fi
  classificar_workflow "$arq" "$TMP/classes.txt"
  vista="$(ALVO_CL="$alvo" awk -F'	' '
    $4 == ENVIRON["ALVO_CL"] { print $3; achou = 1; exit }
    END { if (!achou) print "AUSENTE" }
  ' "$TMP/classes.txt")"
  if [ "$vista" = "$esperada" ]; then
    ok "$desc (classe $vista)"
  else
    nok "$desc — esperado $esperada, obtido $vista"
  fi
}

# `vetores_do_passo_zero <chave>` — os vinte e um vetores, sobre UMA chave.
#
# A mesma bateria para os três passos zero, e de propósito: cobertura desigual
# entre passos é o convite para a sabotagem migrar para o passo menos medido —
# que foi, letra por letra, o que a R5 fez com o `0a` depois de a C4 fechar o
# `0b`.
vetores_do_passo_zero() {
  local chave="$1" invocacao captura nucleo purga log marcador script sem_tee
  campo_do_passo "$chave" invocacao; invocacao="$CAMPO"
  campo_do_passo "$chave" captura;   captura="$CAMPO"
  campo_do_passo "$chave" nucleo;    nucleo="$CAMPO"
  campo_do_passo "$chave" purga;     purga="$CAMPO"
  campo_do_passo "$chave" log;       log="$CAMPO"
  campo_do_passo "$chave" marcador;  marcador="$CAMPO"
  script="${nucleo#bash }"
  sem_tee="${invocacao%% 2>&1*}"

  printf '\n  -- passo zero de %s --\n' "$chave"

  # 00 — CONTROLE. Sem ele, uma guarda que reprovasse SEMPRE passaria nos vinte
  # vetores abaixo e a seção inteira deixaria de medir.
  forjar_passo "$chave" "pz00_$chave.yml"
  esperar_passo 0 "PZ00[$chave] CONTROLE — cópia íntegra do workflow => guarda VERDE" '-'

  # 01 — a invocação simplesmente sumiu. É o núcleo do escape da R5.
  forjar_passo "$chave" "pz01_$chave.yml" && sabotar apagar
  esperar_passo 1 "PZ01[$chave] — invocação ausente => VERMELHO" 0 \
    'nao tem a invocacao oficial VIVA'

  # 02 — a invocação virou comentário. O texto continua no arquivo, e o CI não
  # executa uma linha sequer dela.
  forjar_passo "$chave" "pz02_$chave.yml" && sabotar trocar "# $invocacao"
  esperar_passo 1 "PZ02[$chave] — invocação comentada => VERMELHO" 0 'aparece como COMENTARIO'

  # 03 — `echo` da invocação: ela é IMPRESSA, e não executada.
  forjar_passo "$chave" "pz03_$chave.yml" && sabotar trocar "echo $invocacao"
  esperar_passo 1 "PZ03[$chave] — invocação dentro de um echo => VERMELHO" 0 'IMPRIME a invocacao'

  # 04 — a invocação dentro de heredoc: é dado entregue a outro programa. É a
  # forma que satisfaz a autocobrança textual da própria autoridade.
  forjar_passo "$chave" "pz04_$chave.yml" && sabotar heredoc
  esperar_passo 1 "PZ04[$chave] — invocação dentro de heredoc => VERMELHO" 1 'aparece como HEREDOC'

  # 05 — a invocação guardada numa string. Nunca é executada, e um `grep` acha.
  forjar_passo "$chave" "pz05_$chave.yml" && sabotar trocar "FORJA_DA_SONDA=\"$invocacao\""
  esperar_passo 1 "PZ05[$chave] — invocação dentro de uma string => VERMELHO" 0 'forma NAO OFICIAL'

  # 06 — duplicada. Com duas chamadas na mesma pipeline de passo, o
  # `PIPESTATUS` lido não é o de nenhuma das duas com certeza.
  forjar_passo "$chave" "pz06_$chave.yml" && sabotar duplicar
  esperar_passo 1 "PZ06[$chave] — invocação duplicada => VERMELHO" 2 'duplicada'

  # 07 — deslocada para um passo depois de quem consome a evidência dela.
  forjar_passo "$chave" "pz07_$chave.yml" && sabotar mover
  esperar_passo 1 "PZ07[$chave] — invocação movida para depois do consumidor => VERMELHO" 1 \
    'nao vem antes de quem consome'

  # 08 — o `tee` real removido: a evidência do run deixa de nascer da execução.
  forjar_passo "$chave" "pz08_$chave.yml" && sabotar trocar "$sem_tee"
  esperar_passo 1 "PZ08[$chave] — tee real removido => VERMELHO" 0 'forma NAO OFICIAL'

  # 09 — o `tee` apontado para OUTRO arquivo: o produtor roda, e o consumidor
  # continua lendo o log que sobrou.
  forjar_passo "$chave" "pz09_$chave.yml" && sabotar trocar "$sem_tee 2>&1 | tee t_forjado.log"
  esperar_passo 1 "PZ09[$chave] — tee enviado para outro arquivo => VERMELHO" 0 'forma NAO OFICIAL'

  # 10 — o caminho do produtor trocado: o `tee` é o mesmo, e quem roda é outro.
  forjar_passo "$chave" "pz10_$chave.yml" \
    && sabotar trocar "${invocacao/$script/scripts/ci/isca_de_produtor.sh}"
  esperar_passo 1 "PZ10[$chave] — caminho do produtor trocado => VERMELHO" 0 \
    'nao tem a invocacao oficial VIVA'

  # 11 — argumento ACRESCENTADO: um diretório escolhido por quem chama é o
  # atalho que o produtor externo existe para não ter.
  forjar_passo "$chave" "pz11_$chave.yml" \
    && sabotar trocar "$sem_tee /tmp/preparado 2>&1 | tee $log"
  esperar_passo 1 "PZ11[$chave] — argumento acrescentado => VERMELHO" 0 'forma NAO OFICIAL'

  # 12 — `|| true`: o vermelho do produtor vira verde sem uma letra da invocação
  # mudar de lugar.
  forjar_passo "$chave" "pz12_$chave.yml" && sabotar trocar "$invocacao || true"
  esperar_passo 1 "PZ12[$chave] — || true anexado => VERMELHO" 0 'neutraliza o codigo de saida'

  # 13 — a mesma neutralização com `; true`, que um casamento por `||` não pega.
  forjar_passo "$chave" "pz13_$chave.yml" && sabotar trocar "$invocacao ; true"
  esperar_passo 1 "PZ13[$chave] — ; true anexado => VERMELHO" 0 'neutraliza o codigo de saida'

  # 14 — a captura pelo `$?`, que numa pipeline é o código do `tee`, e o `tee`
  # é sempre zero. O produtor reprova e o marcador diz que passou.
  forjar_passo "$chave" "pz14_$chave.yml" \
    && sabotar trocar_outra "$captura" "echo \$? > $marcador"
  esperar_passo 1 "PZ14[$chave] — exit do tee capturado no lugar do produtor => VERMELHO" 1 \
    'a captura oficial do codigo de saida aparece 0 vez'

  # 15 — o marcador FABRICADO antes da execução verdadeira.
  forjar_passo "$chave" "pz15_$chave.yml" && sabotar antes "echo 0 > $marcador"
  esperar_passo 1 "PZ15[$chave] — marcador fabricado antes da execução => VERMELHO" 1 \
    'escreve a evidencia'

  # 16 — o LOG fabricado antes da execução verdadeira. É a metade da R5 que a
  # FASE B não pegava: o log tinha uma linha, e a linha dizia o placar certo.
  forjar_passo "$chave" "pz16_$chave.yml" \
    && sabotar antes "echo 'casos ok: 999' > $log"
  esperar_passo 1 "PZ16[$chave] — log fabricado antes da execução => VERMELHO" 1 \
    'escreve a evidencia'

  # 17 — a captura afastada da invocação: o `PIPESTATUS` lido passa a ser o de
  # outra linha, e o exit do produtor deixa de chegar ao portão.
  forjar_passo "$chave" "pz17_$chave.yml" && sabotar depois 'echo intruso | tee -a t_intruso.log'
  esperar_passo 1 "PZ17[$chave] — linha intrusa entre a invocação e a captura => VERMELHO" 1 \
    'entre a invocacao e a captura'

  # 18 — a purga da evidência anterior removida: log e marcador de OUTRA corrida
  # passam a poder sobreviver até o consumidor.
  forjar_passo "$chave" "pz18_$chave.yml" && sabotar apagar_outra "$purga"
  esperar_passo 1 "PZ18[$chave] — purga da evidência anterior removida => VERMELHO" 1 \
    'a purga da evidencia anterior aparece 0 vez'

  # 19 — a purga deslocada para DEPOIS da captura: ela apaga a evidência que
  # acabou de nascer, e não a que sobrou.
  forjar_passo "$chave" "pz19_$chave.yml" && sabotar purga_depois "$purga" "$captura"
  esperar_passo 1 "PZ19[$chave] — purga deslocada para depois da captura => VERMELHO" 1 \
    'a purga nao vem antes da invocacao'

  # 20 — o TÍTULO do passo trocado, com o código intacto. O passo deixa de ser o
  # passo zero declarado, e a ordem congelada deixa de valer.
  forjar_passo "$chave" "pz20_$chave.yml" && sabotar titulo
  esperar_passo 1 "PZ20[$chave] — título do passo trocado => VERMELHO" 1 'e nao no passo'

  # -------------------------------------------------------------------------
  # 21 a 25 — A FALSA ABERTURA DE HEREDOC (OS 40-C6)
  # -------------------------------------------------------------------------
  #
  # A OS 40-C5 endureceu `vivas_de` e deixou este classificador assimétrico:
  # qualquer resto não vazio depois do par abria heredoc. A OS 40-R6 mediu o
  # preço — uma ocorrência textual jogava TODAS as linhas seguintes na classe
  # HEREDOC, congelava a contagem de passos, escondia a escrita posterior do log
  # e do marcador, e a cadeia oficial inteira ficava VERDE: `portaoci` 101/101,
  # `autverif` 82/82, FASE A com 17 contratos, guarda `--guarda` com exit 0 e
  # agregador 64/64, com a evidência de um passo zero fabricada por um `echo`.
  #
  # CADA VETOR FAZ DUAS PERGUNTAS. O exit da guarda diz que ela reprovou; a
  # `esperar_classe` diz que ela reprovou POR TER OLHADO a linha decisiva. Sem a
  # segunda, um vermelho por efeito colateral — a cegueira escondendo, de
  # quebra, a própria invocação canônica — passaria por detecção.

  # 21 — falsa abertura DEPOIS de tudo, e o marcador fabricado logo em seguida.
  forjar_passo "$chave" "pz21_$chave.yml" && sabotar apendice \
    "      - name: \"9z — apêndice da sonda\"~        run: |~          $FALSA_ABERTURA~          echo 0 > $marcador"
  esperar_classe "$FORJA_ARQ" "echo 0 > $marcador" CODIGO \
    "PZ21[$chave] — a escrita posterior do marcador continua sendo CÓDIGO"
  esperar_passo 1 "PZ21[$chave] — falsa abertura escondendo o marcador fabricado => VERMELHO" 1 \
    'escreve a evidencia'

  # 22 — falsa abertura e, depois dela, um passo zero material NOVO. Com o
  # classificador cego, o próprio título deixava de contar como passo.
  forjar_passo "$chave" "pz22_$chave.yml" && sabotar apendice \
    "      - name: \"9z — apêndice da sonda\"~        run: |~          $FALSA_ABERTURA~      - name: \"0d — passo zero fora da relação\"~        run: |~          echo 0 > exit_${chave}intruso"
  esperar_classe "$FORJA_ARQ" '- name: "0d — passo zero fora da relação"' PASSO \
    "PZ22[$chave] — o título do passo novo continua sendo PASSO: a contagem não congelou"
  esperar_passo 1 "PZ22[$chave] — falsa abertura escondendo passo zero fora da relação => VERMELHO" 1 \
    'nao esta na relacao protegida'

  # 23 — o escape material inteiro: log E marcador forjados atrás da cegueira.
  forjar_passo "$chave" "pz23_$chave.yml" && sabotar apendice \
    "      - name: \"9z — apêndice da sonda\"~        run: |~          $FALSA_ABERTURA~          echo 'casos ok: 999' > $log~          echo 0 > $marcador"
  esperar_classe "$FORJA_ARQ" "echo 'casos ok: 999' > $log" CODIGO \
    "PZ23[$chave] — a forja do log posterior continua sendo CÓDIGO"
  esperar_passo 1 "PZ23[$chave] — falsa abertura escondendo log e marcador forjados => VERMELHO" 1 \
    'escreve a evidencia'

  # 24 — A METADE QUE FALHAVA PARA O OUTRO LADO. Antes da correção, uma
  # ocorrência textual ANTERIOR aos passos protegidos punha as três invocações
  # canônicas em HEREDOC e a guarda REPROVAVA o workflow íntegro. Um portão que
  # reprova a árvore correta é a pressão mais forte que existe para afrouxá-lo.
  forjar_passo "$chave" "pz24_$chave.yml" && sabotar prologo \
    "      - name: \"9y — diagnóstico anterior\"~        run: |~          $FALSA_ABERTURA~          echo diagnostico"
  esperar_classe "$FORJA_ARQ" "$invocacao" CODIGO \
    "PZ24[$chave] — ocorrência textual ANTERIOR não esconde a invocação canônica"
  esperar_passo 0 "PZ24[$chave] — ocorrência textual anterior => guarda VERDE" 1

  # 25 — E O HEREDOC DE VERDADE CONTINUA SENDO HEREDOC. A correção fecha a falsa
  # abertura sem afrouxar a verdadeira: o corpo segue inerte, e depois do
  # delimitador a classificação volta a ser código.
  forjar_passo "$chave" "pz25_$chave.yml" && sabotar apendice \
    "      - name: \"9w — heredoc real da sonda\"~        run: |~          cat $MENOR2 FIM_DA_SONDA > /dev/null~          echo 0 > $marcador~          FIM_DA_SONDA~          echo apos-o-delimitador"
  esperar_classe "$FORJA_ARQ" "echo 0 > $marcador" HEREDOC \
    "PZ25[$chave] — o corpo do heredoc REAL continua sendo dado, e não código"
  esperar_classe "$FORJA_ARQ" 'echo apos-o-delimitador' CODIGO \
    "PZ25[$chave] — depois do delimitador real a classificação volta a ser código"
  esperar_passo 0 "PZ25[$chave] — heredoc real com o marcador no corpo => guarda VERDE" 1

  # -------------------------------------------------------------------------
  # OS 40-C7 — A FALSA ABERTURA COM DELIMITADOR CITADO
  # -------------------------------------------------------------------------
  #
  # Os vetores `PZ21`-`PZ25` usam a forma cujo resto já era incompatível
  # (`$ALVO`). A OS 40-R7 mostrou que ela não era a forma perigosa: bastava que
  # o texto citado fosse um IDENTIFICADOR para as duas leituras voltarem a abrir
  # um heredoc que o shell não abre. Estes repetem a bateria material com a
  # forma que escapava — e são eles que separam a C6 da C7.

  # 26 — marcador fabricado atrás da falsa abertura CITADA.
  forjar_passo "$chave" "pz26_$chave.yml" && sabotar apendice \
    "      - name: \"9z — apêndice da sonda\"~        run: |~          $FALSA_ABERTURA_CITADA~          echo 0 > $marcador"
  esperar_classe "$FORJA_ARQ" "echo 0 > $marcador" CODIGO \
    "PZ26[$chave] — falsa abertura CITADA: a escrita posterior do marcador continua sendo CÓDIGO"
  esperar_passo 1 "PZ26[$chave] — falsa abertura CITADA escondendo o marcador fabricado => VERMELHO" 1 \
    'escreve a evidencia'

  # 27 — passo zero material NOVO atrás da falsa abertura citada.
  forjar_passo "$chave" "pz27_$chave.yml" && sabotar apendice \
    "      - name: \"9z — apêndice da sonda\"~        run: |~          $FALSA_ABERTURA_CITADA~      - name: \"0d — passo zero fora da relação\"~        run: |~          echo 0 > exit_${chave}intruso"
  esperar_classe "$FORJA_ARQ" '- name: "0d — passo zero fora da relação"' PASSO \
    "PZ27[$chave] — falsa abertura CITADA: o título do passo novo continua sendo PASSO"
  esperar_passo 1 "PZ27[$chave] — falsa abertura CITADA escondendo passo zero fora da relação => VERMELHO" 1 \
    'nao esta na relacao protegida'

  # 28 — o escape material da R7 por inteiro: log E marcador forjados.
  forjar_passo "$chave" "pz28_$chave.yml" && sabotar apendice \
    "      - name: \"9z — apêndice da sonda\"~        run: |~          $FALSA_ABERTURA_CITADA~          echo 'casos ok: 999' > $log~          echo 0 > $marcador"
  esperar_classe "$FORJA_ARQ" "echo 'casos ok: 999' > $log" CODIGO \
    "PZ28[$chave] — falsa abertura CITADA: a forja do log posterior continua sendo CÓDIGO"
  esperar_passo 1 "PZ28[$chave] — falsa abertura CITADA escondendo log e marcador forjados => VERMELHO" 1 \
    'escreve a evidencia'

  # 29 — a mesma forma ENTRE ASPAS SIMPLES, num comando que o CI de fato roda.
  forjar_passo "$chave" "pz29_$chave.yml" && sabotar apendice \
    "      - name: \"9z — apêndice da sonda\"~        run: |~          $FALSA_ABERTURA_SIMPLES~          echo 0 > $marcador"
  esperar_classe "$FORJA_ARQ" "echo 0 > $marcador" CODIGO \
    "PZ29[$chave] — falsa abertura entre ASPAS SIMPLES: a escrita posterior continua sendo CÓDIGO"
  esperar_passo 1 "PZ29[$chave] — falsa abertura entre aspas simples escondendo o marcador => VERMELHO" 1 \
    'escreve a evidencia'

  # 30 — E O OUTRO LADO: a mesma ocorrência ANTES dos passos protegidos não pode
  # reprovar o workflow íntegro. Antes da C7 ela punha as três invocações
  # canônicas em HEREDOC e a guarda recusava a árvore correta.
  forjar_passo "$chave" "pz30_$chave.yml" && sabotar prologo \
    "      - name: \"9y — diagnóstico anterior\"~        run: |~          $FALSA_ABERTURA_CITADA~          echo diagnostico"
  esperar_classe "$FORJA_ARQ" "$invocacao" CODIGO \
    "PZ30[$chave] — ocorrência CITADA anterior não esconde a invocação canônica"
  esperar_passo 0 "PZ30[$chave] — ocorrência CITADA anterior => guarda VERDE" 1

  # 31 — A ENTRADA INDECIDÍVEL FALHA EXPLICITAMENTE. Uma citação que não fecha
  # na linha não pode ser classificada por conveniência: nem CÓDIGO, nem
  # HEREDOC. Ela sai como AMBIGUO, e a guarda recusa dizendo qual linha é.
  forjar_passo "$chave" "pz31_$chave.yml" && sabotar apendice \
    "      - name: \"9z — apêndice da sonda\"~        run: |~          $LINHA_AMBIGUA~          echo 0 > $marcador"
  esperar_classe "$FORJA_ARQ" "$LINHA_AMBIGUA" AMBIGUO \
    "PZ31[$chave] — citação que não fecha é classificada como AMBIGUO"
  esperar_passo 1 "PZ31[$chave] — linha indecidível => VERMELHO, com a linha nomeada" 1 \
    'nao consegue decidir'

  # -------------------------------------------------------------------------
  # OS 40-C8 — OS TRES EIXOS QUE A OS 40-R8 MEDIU E A C7 NAO COBRIA
  # -------------------------------------------------------------------------

  # 32 — ANSI-C quoting (E1). A linha e um `echo` comum para o shell, e a
  # sabotagem seguinte EXECUTA. Ela nao pode virar corpo de heredoc.
  forjar_passo "$chave" "pz32_$chave.yml" && sabotar apendice \
    "      - name: \"9z — apêndice da sonda\"~        run: |~          $FALSA_ABERTURA_ANSI~          echo 0 > $marcador"
  esperar_classe "$FORJA_ARQ" "echo 0 > $marcador" CODIGO \
    "PZ32[$chave] — ANSI-C quoting não cega o restante: a escrita posterior continua sendo CÓDIGO"
  esperar_passo 1 "PZ32[$chave] — ANSI-C quoting escondendo o marcador fabricado => VERMELHO" 1 \
    'escreve a evidencia'

  # 33 — continuação física (E3). A segunda linha física é o MESMO comando, o
  # shell a executa, e ela tem de ser auditada como código.
  forjar_passo "$chave" "pz33_$chave.yml" && sabotar apendice \
    "      - name: \"9z — apêndice da sonda\"~        run: |~          $CONTINUACAO_ABERTA~          ; echo 0 > $marcador~          FIM_DA_SONDA"
  esperar_classe "$FORJA_ARQ" "; echo 0 > $marcador" CODIGO \
    "PZ33[$chave] — continuação física: a linha seguinte continua sendo CÓDIGO"
  esperar_passo 1 "PZ33[$chave] — continuação física escondendo o marcador fabricado => VERMELHO" 1 \
    'escreve a evidencia'

  # 34 — terminador indentado (E2). O corpo NAO fecha em coluna diferente de
  # zero: a invocação canônica fica inerte, e a guarda tem de dizer isso.
  forjar_passo "$chave" "pz34_$chave.yml" && sabotar heredoc_ind
  esperar_passo 1 "PZ34[$chave] — terminador indentado deixa a invocação inerte => VERMELHO" 1 \
    'aparece como HEREDOC'
}

vetores_do_passo_zero portaoci
vetores_do_passo_zero autverif
vetores_do_passo_zero contratosui

printf '\n== a regra canônica do delimitador, e a matriz de falsas aberturas ==\n'

# ---------------------------------------------------------------------------
# POR QUE ESTA SEÇÃO EXISTE (OS 40-C6)
# ---------------------------------------------------------------------------
#
# Há DUAS leituras de código vivo nesta árvore, e elas têm de decidir igual
# sobre a mesma pergunta: `vivas_de`, em `scripts/ci/autoridade_verificadores.sh`,
# e `classificar_workflow`, aqui. A OS 40-C5 endureceu a primeira e esqueceu a
# segunda, e a OS 40-R6 mediu o preço dessa assimetria.
#
# A correção reusaria a função se pudesse. Não pode: a autoridade externa é um
# programa que EXECUTA ao ser lido — dar `source` nela para pegar uma função
# rodaria a autoridade inteira dentro do gate que ela audita —, e um terceiro
# arquivo só para hospedar o predicado seria um caminho a mais, fora do teto
# desta OS. A equivalência é então DEMONSTRADA, em dois eixos independentes:
#
#   HD01  comparação explícita — o bloco de aceitação do delimitador é extraído
#         dos DOIS arquivos e comparado LETRA POR LETRA. Divergir vira vermelho
#         aqui, e não silêncio na próxima OS.
#   HD02  equivalência nominal — `vivas_de` é EXTRAÍDA do arquivo da autoridade
#         e executada sobre o MESMO corpus de amostras. Comparar o texto das
#         duas expressões não bastaria; o que se compara é a DECISÃO.
#
# E cada amostra tem PÓS-CONDIÇÃO PRÓPRIA (HD03 em diante): qual classe recebeu
# a linha decisiva. Um arnês que só olhasse o exit não distinguiria "a guarda
# enxergou e recusou" de "a guarda recusou por outro motivo".

FORJA_MOTIVO=''
EU="$AQUI/teste_portao_os_integracao.sh"
AUTORIDADE_EXTERNA="$AQUI/autoridade_verificadores.sh"

# `leitura_do_heredoc <arquivo>` — a FUNÇÃO INTEIRA `abertura_de_heredoc`, do
# cabeçalho ao fecho, como está escrita no arquivo.
#
# NÃO É O BLOCO DE ACEITAÇÃO, e a diferença é a lição da OS 40-R7. Até a C6 esta
# comparação pegava só o `case` final; a descoberta do operador e o tratamento
# das aspas — que era ONDE a decisão errava — ficavam de fora. Duas leituras
# podiam concordar letra por letra no pedaço comparado e estar as duas erradas
# no pedaço que não era.
leitura_do_heredoc() {
  awk '
    { l = $0; sub(/\r$/, "", l) }
    l == "abertura_de_heredoc() {" { dentro = 1 }
    dentro { print l }
    dentro && l == "}" { exit }
  ' "$1"
}

# `espremer <arquivo>` — a mesma normalização que `classificar_workflow` aplica,
# para que as duas leituras possam ser comparadas linha a linha.
espremer() {
  awk '{
    l = $0; sub(/\r$/, "", l); gsub(/\t/, " ", l)
    sub(/^ +/, "", l); gsub(/  +/, " ", l); sub(/ +$/, "", l)
    print l
  }' "$1"
}

leitura_do_heredoc "$EU" > "$TMP/leitura_aqui.txt"
leitura_do_heredoc "$AUTORIDADE_EXTERNA" > "$TMP/leitura_la.txt"
if [ ! -s "$TMP/leitura_aqui.txt" ]; then
  nok "HD01 — a leitura de abertura de heredoc não foi encontrada NESTE arquivo"
elif [ ! -s "$TMP/leitura_la.txt" ]; then
  nok "HD01 — a leitura de abertura de heredoc não foi encontrada na autoridade externa"
elif cmp -s "$TMP/leitura_aqui.txt" "$TMP/leitura_la.txt"; then
  ok "HD01 — a leitura INTEIRA do heredoc é LETRA POR LETRA a mesma nas duas autoridades"
else
  nok "HD01 — a leitura de abertura de heredoc DIVERGIU entre o classificador e a autoridade"
  diff -u "$TMP/leitura_la.txt" "$TMP/leitura_aqui.txt" | sed 's/^/        | /'
fi

# ---------------------------------------------------------------------------
# AS AMOSTRAS — a matriz ampliada de falsas aberturas
# ---------------------------------------------------------------------------
#
# NENHUMA AMOSTRA TEM LINHA EM BRANCO, e é de propósito: `vivas_de` descarta
# linha em branco, e a comparação de HD02 é linha a linha.
AMOSTRA=''
AMOSTRAS=''
amostra() { AMOSTRA="$TMP/amostra_$1"; : > "$AMOSTRA"; AMOSTRAS="$AMOSTRAS $1"; }
linha_da_amostra() { printf '%s\n' "$1" >> "$AMOSTRA"; }

# 1. o par entre ASPAS SIMPLES.
amostra aspas_simples
linha_da_amostra '      - name: "0 — passo protegido"'
linha_da_amostra '        run: |'
linha_da_amostra "          grep -n '$MENOR2' scripts/ci/portao_os_integracao.sh"
linha_da_amostra '          echo 0 > exit_portaoci'

# 2. o par entre ASPAS DUPLAS, com resto que não é identificador.
amostra aspas_duplas
linha_da_amostra '      - name: "0 — passo protegido"'
linha_da_amostra '        run: |'
linha_da_amostra "          $FALSA_ABERTURA"
linha_da_amostra '          echo 0 > exit_portaoci'

# 3. o par em COMENTÁRIO — e com resto que SERIA um delimitador válido. É a
#    amostra que separa "o texto está no arquivo" de "o shell abre um heredoc".
amostra comentario
linha_da_amostra '      - name: "0 — passo protegido"'
linha_da_amostra '        run: |'
linha_da_amostra "          # nota: $MENOR2 AQUI seria uma abertura de verdade"
linha_da_amostra '          echo 0 > exit_portaoci'

# 4. CANDIDATO COM CONTEÚDO ADICIONAL INCOMPATÍVEL.
amostra resto_incompativel
linha_da_amostra '      - name: "0 — passo protegido"'
linha_da_amostra '        run: |'
linha_da_amostra "          printf '%s' 'a $MENOR2 b)'"
linha_da_amostra '          echo 0 > exit_portaoci'

# 5. o par EMBUTIDO EM COMANDO DE DIAGNÓSTICO — deslocamento aritmético, cujo
#    resto começa por dígito.
amostra diagnostico
linha_da_amostra '      - name: "0 — passo protegido"'
linha_da_amostra '        run: |'
linha_da_amostra "          awk 'BEGIN { print 2 $MENOR2 3 }' > /dev/null"
linha_da_amostra '          echo 0 > exit_portaoci'

# 6. falsa abertura ANTES do passo protegido.
amostra falsa_antes
linha_da_amostra '      - name: "9y — diagnóstico anterior"'
linha_da_amostra '        run: |'
linha_da_amostra "          $FALSA_ABERTURA"
linha_da_amostra '      - name: "0 — passo protegido"'
linha_da_amostra '        run: |'
linha_da_amostra '          bash scripts/ci/teste_portao_os_integracao.sh 2>&1 | tee t_portaoci.log'

# 7. falsa abertura DEPOIS do passo protegido, com titulo posterior: e a amostra
#    que prova que a contagem de passos nao congela.
amostra falsa_depois
linha_da_amostra '      - name: "0 — passo protegido"'
linha_da_amostra '        run: |'
linha_da_amostra '          bash scripts/ci/teste_portao_os_integracao.sh 2>&1 | tee t_portaoci.log'
linha_da_amostra "          $FALSA_ABERTURA"
linha_da_amostra '      - name: "9z — passo posterior"'
linha_da_amostra '        run: |'
linha_da_amostra '          echo 0 > exit_portaoci'

# 8. HEREDOC REAL — corpo ignorado, fechamento correto, e volta ao código.
amostra heredoc_real
linha_da_amostra '      - name: "9w — heredoc real"'
linha_da_amostra '        run: |'
linha_da_amostra "          cat $MENOR2 FIM_DA_AMOSTRA > /dev/null"
linha_da_amostra '          echo 0 > exit_portaoci'
linha_da_amostra '          FIM_DA_AMOSTRA'
linha_da_amostra '          echo apos-o-delimitador'

# 9. HEREDOC REAL com `-` e delimitador CITADO: as duas formas que a gramática
#    canônica aceita, e que a correção não pode ter quebrado.
amostra heredoc_citado
linha_da_amostra '      - name: "9w — heredoc real citado"'
linha_da_amostra '        run: |'
linha_da_amostra "          cat $MENOR2-'FIM_DA_AMOSTRA' > /dev/null"
linha_da_amostra '          echo 0 > exit_portaoci'
linha_da_amostra '          FIM_DA_AMOSTRA'
linha_da_amostra '          echo apos-o-delimitador'

# HD02 — A EQUIVALÊNCIA NOMINAL, sobre o corpus inteiro.
#
# A função é EXTRAÍDA por recorte de texto, e não pelo `source` do arquivo
# inteiro: dar `source` na autoridade externa a EXECUTARIA aqui dentro, e o
# gate passaria a conter o programa que ele audita.
sed -n '/^vivas_de() {/,/^}$/p' "$AUTORIDADE_EXTERNA" > "$TMP/vivas_de.sh"
if [ ! -s "$TMP/vivas_de.sh" ]; then
  nok "HD02 — nao foi possivel extrair a leitura de codigo vivo da autoridade externa"
else
  . "$TMP/vivas_de.sh"
  for a in $AMOSTRAS; do
    vivas_de "$TMP/amostra_$a" "$TMP/vivas_$a"
    classificar_workflow "$TMP/amostra_$a" "$TMP/cls_$a"
    espremer "$TMP/vivas_$a" > "$TMP/vivas_esp_$a"
    awk -F'\t' '$3 != "HEREDOC" && $3 != "COMENTARIO" { print $4 }' "$TMP/cls_$a" > "$TMP/cod_$a"
    if [ ! -s "$TMP/vivas_esp_$a" ]; then
      nok "HD02[$a] — a leitura da autoridade nao devolveu uma linha sequer: a amostra nao mede nada"
    elif cmp -s "$TMP/vivas_esp_$a" "$TMP/cod_$a"; then
      ok "HD02[$a] — as duas leituras concordam sobre o que é código vivo"
    else
      nok "HD02[$a] — o classificador e a autoridade DIVERGEM sobre a mesma amostra"
      diff -u "$TMP/vivas_esp_$a" "$TMP/cod_$a" | sed 's/^/        | /'
    fi
  done
fi

# HD03 em diante — a pós-condição de cada amostra, nominal e independente.
esperar_classe "$TMP/amostra_aspas_simples" 'echo 0 > exit_portaoci' CODIGO \
  "HD03 — o par entre ASPAS SIMPLES não abre heredoc: a linha seguinte é código"
esperar_classe "$TMP/amostra_aspas_duplas" 'echo 0 > exit_portaoci' CODIGO \
  "HD04 — o par entre ASPAS DUPLAS não abre heredoc: a linha seguinte é código"
esperar_classe "$TMP/amostra_comentario" "# nota: $MENOR2 AQUI seria uma abertura de verdade" COMENTARIO \
  "HD05 — o par em COMENTÁRIO é classificado como comentário"
esperar_classe "$TMP/amostra_comentario" 'echo 0 > exit_portaoci' CODIGO \
  "HD06 — o par em COMENTÁRIO não abre heredoc: a linha seguinte é código"
esperar_classe "$TMP/amostra_resto_incompativel" 'echo 0 > exit_portaoci' CODIGO \
  "HD07 — candidato com conteúdo adicional incompatível não abre heredoc"
esperar_classe "$TMP/amostra_diagnostico" 'echo 0 > exit_portaoci' CODIGO \
  "HD08 — o par embutido em comando de diagnóstico não abre heredoc"
esperar_classe "$TMP/amostra_falsa_antes" 'bash scripts/ci/teste_portao_os_integracao.sh 2>&1 | tee t_portaoci.log' CODIGO \
  "HD09 — ocorrência textual ANTERIOR não esconde a invocação canônica"
esperar_classe "$TMP/amostra_falsa_antes" '- name: "0 — passo protegido"' PASSO \
  "HD10 — ocorrência textual ANTERIOR não esconde o título do passo protegido"
esperar_classe "$TMP/amostra_falsa_depois" '- name: "9z — passo posterior"' PASSO \
  "HD11 — ocorrência textual POSTERIOR não congela a contagem de passos"
esperar_classe "$TMP/amostra_falsa_depois" 'echo 0 > exit_portaoci' CODIGO \
  "HD12 — ocorrência textual POSTERIOR não esconde a escrita do marcador"
esperar_classe "$TMP/amostra_heredoc_real" 'echo 0 > exit_portaoci' HEREDOC \
  "HD13 — o corpo do heredoc REAL continua sendo dado, e não código"
esperar_classe "$TMP/amostra_heredoc_real" 'echo apos-o-delimitador' CODIGO \
  "HD14 — depois do delimitador REAL a classificação volta a ser código"
esperar_classe "$TMP/amostra_heredoc_citado" 'echo 0 > exit_portaoci' HEREDOC \
  "HD15 — heredoc real com recuo e delimitador citado continua reconhecido"
esperar_classe "$TMP/amostra_heredoc_citado" 'echo apos-o-delimitador' CODIGO \
  "HD16 — o fechamento do delimitador citado devolve a classificação ao código"

printf '\n== o operador de heredoc, contra o SHELL REAL ==\n'

# ---------------------------------------------------------------------------
# HD17 — O CORPUS DO OPERADOR (OS 40-C7)
# ---------------------------------------------------------------------------
#
# A matriz `HD03`-`HD16` mede a CLASSE da linha decisiva sobre amostras de
# workflow. Esta mede a decisão CRUA, linha a linha, contra três testemunhas
# independentes ao mesmo tempo:
#
#   1. o SHELL REAL — a sentinela da linha seguinte executa, ou não;
#   2. a leitura DESTE arquivo;
#   3. a leitura da AUTORIDADE EXTERNA, extraída e executada num SUBSHELL.
#
# A terceira roda em subshell de propósito: dar `source` na leitura de lá dentro
# deste processo substituiria a leitura daqui no meio da matriz, e a comparação
# passaria a medir a mesma função duas vezes.
#
# POR QUE ELA EXISTE. A OS 40-R7 mediu o preço de comparar as duas leituras
# entre si sem um terceiro oráculo: as duas removiam as aspas antes de decidir,
# erravam igual, e por isso CONCORDAVAM. Concordância não é correção. O shell
# real é o único árbitro que não herda o defeito.
#
# O PAR É MONTADO A PARTIR DE `@@`, e nunca escrito colado no corpus: o
# analisador léxico do contrato de conteúdo lê este arquivo, e um par solto aqui
# teria de ser decidido por ele antes de esta suíte poder medir coisa alguma.
CORPUS_OPERADOR="$(cat <<'CORPUS_DO_OPERADOR'
FIM_DA_SONDA|cat @@FIM_DA_SONDA
FIM_DA_SONDA|cat @@ FIM_DA_SONDA
FIM_DA_SONDA|cat @@-FIM_DA_SONDA
FIM_DA_SONDA|cat @@'FIM_DA_SONDA'
FIM_DA_SONDA|cat @@"FIM_DA_SONDA"
FIM_DA_SONDA|cat @@-'FIM_DA_SONDA'
FIM_DA_SONDA|cat @@-"FIM_DA_SONDA"
FIM_DA_SONDA|cat @@\FIM_DA_SONDA
FIM_DA_SONDA|cat @@FIM_DA_SONDA > /dev/null
FIM_DA_SONDA|EVIDENCIA="$(cat @@'FIM_DA_SONDA'
NAO|echo "diagnostico @@ALVO"
NAO|echo 'diagnostico @@ALVO'
NAO|grep -n '@@ALVO' arquivo.sh
NAO|grep -n "@@EOF" arquivo.sh
NAO|printf '%s' "veja @@FIM"
NAO|echo "a@@b"
NAO|echo "use: cmd @@HEREDOC_NAME para abrir"
NAO|awk 'BEGIN{print 2 @@ 3}'
NAO|echo "deslocamento @@ $ALVO"
NAO|grep -n '@@' arquivo.sh
NAO|case "$nu" in *'@@'*) :;; esac
NAO|resto="${nu##*@@}"
NAO|x=$((1@@2))
NAO|x=$((1 @@ N))
NAO|sed -e 's/@@X//' f
NAO|node -e "console.log(1@@2)"
NAO|cat @@<palavra
NAO|echo \@@EOF
NAO|foo bar # comentario com @@AQUI
AMB|echo "abre @@FIM
AMB|echo 'abre @@FIM
AMB|cat @@A @@B
AMB|cat @@2FIM
AMB|cat @@FIM-DA-SONDA
NAO|echo $'a\'b @@true '
NAO|echo $'texto @@FIM_DA_SONDA'
NAO|x=$'a\'b'; echo ok
AMB|cat @@FIM_DA_SONDA "aberta
AMB|cat @@FIM_DA_SONDA 'aberta
CORPUS_DO_OPERADOR
)"
CORPUS_OPERADOR="${CORPUS_OPERADOR//@@/$MENOR2}"

# `shell_abre <linha>` — o SHELL REAL como oráculo, e não uma opinião sobre ele.
# A sentinela da linha seguinte só nasce se aquela linha EXECUTAR: dentro de um
# corpo de heredoc ela é dado, e nenhum arquivo aparece.
shell_abre() {
  rm -f "$TMP/sentinela_shell"
  {
    printf '%s\n' "$1"
    printf 'printf x > "%s"\n' "$TMP/sentinela_shell"
  } > "$TMP/oraculo.sh"
  bash "$TMP/oraculo.sh" > /dev/null 2>&1
  [ ! -f "$TMP/sentinela_shell" ]
}

# `veredito_de <linha>` — `NAO`, `AMB` ou o delimitador, pela leitura DESTE
# arquivo.
veredito_de() {
  abertura_de_heredoc "$1"
  if [ "$ABERTURA_AMBIGUA" -eq 1 ]; then printf 'AMB'
  elif [ -n "$ABERTURA_HEREDOC" ]; then printf '%s' "$ABERTURA_HEREDOC"
  else printf 'NAO'; fi
}

cp "$TMP/leitura_la.txt" "$TMP/leitura_la.sh"
printf '%s\n' 'veredito_de() {' >> "$TMP/leitura_la.sh"
printf '%s\n' '  abertura_de_heredoc "$1"' >> "$TMP/leitura_la.sh"
printf '%s\n' '  if [ "$ABERTURA_AMBIGUA" -eq 1 ]; then printf AMB' >> "$TMP/leitura_la.sh"
printf '%s\n' '  elif [ -n "$ABERTURA_HEREDOC" ]; then printf %s "$ABERTURA_HEREDOC"' >> "$TMP/leitura_la.sh"
printf '%s\n' '  else printf NAO; fi' >> "$TMP/leitura_la.sh"
printf '%s\n' '}' >> "$TMP/leitura_la.sh"

hd=17
while IFS='|' read -r esperado linha; do
  [ -z "$esperado" ] && continue
  aqui="$(veredito_de "$linha")"
  la="$( . "$TMP/leitura_la.sh"; veredito_de "$linha" )"
  if [ "$aqui" != "$esperado" ]; then
    nok "HD$hd — esta leitura respondeu '$aqui' e o esperado era '$esperado': $linha"
  elif [ "$la" != "$esperado" ]; then
    nok "HD$hd — a autoridade externa respondeu '$la' e o esperado era '$esperado': $linha"
  elif [ "$esperado" = 'AMB' ]; then
    ok "HD$hd — entrada indecidível recusada pelas duas leituras: $linha"
  elif [ "$esperado" = 'NAO' ]; then
    if shell_abre "$linha"; then
      nok "HD$hd — o SHELL REAL abriu heredoc onde as leituras disseram que não: $linha"
    else
      ok "HD$hd — o par não é operador, e o shell real segue executando: $linha"
    fi
  else
    if shell_abre "$linha"; then
      ok "HD$hd — abertura real reconhecida como '$esperado', e o shell real concorda: $linha"
    else
      nok "HD$hd — as leituras abriram '$esperado' e o SHELL REAL não abriu: $linha"
    fi
  fi
  hd=$((hd + 1))
done <<CORPUS_MEDIDO
$CORPUS_OPERADOR
CORPUS_MEDIDO

printf '\n== matriz do agregador ==\n'

# 1 — todos os gates com exit 0 -> verde.
reset_verde
esperar 0 "C01 — todos os obrigatórios em exit 0 => VERDE"

# 2 — gate Flutter de ranking com exit 1 -> vermelho.
reset_verde
printf '1\n' > "$RES/exit_rkleitor"
esperar 1 "C02 — suíte Flutter de ranking (rkleitor) exit 1 => VERMELHO" \
          'rkleitor +VERMELHO'

# 3 — gate da composição com exit 1 -> vermelho.
reset_verde
printf '1\n' > "$RES/exit_composicao"
esperar 1 "C03 — composicao exit 1 => VERMELHO" 'composicao +VERMELHO'

# 4..7 — os quatro gates que escapavam do agregador antes desta OS.
for g in rankingfn rankingint identint auditident; do
  reset_verde
  printf '1\n' > "$RES/exit_$g"
  esperar 1 "C0? — $g exit 1 => VERMELHO (CI-02)" "$g +VERMELHO"
done

# 8 — marcador nao_<gate> -> vermelho.
# O gate usado como cobaia é `colecoesemu` (era `regras`, o nome aposentado —
# ver a nota em I1). O caso mede o AGREGADOR, e não aquela suíte: qualquer gate
# real serve, e um gate irreal media o nada.
reset_verde
rm -f "$RES/exit_colecoesemu"
printf 'firebase/testes/package.json ausente\n' > "$RES/nao_colecoesemu"
esperar 1 "C08 — marcador nao_colecoesemu => VERMELHO (CI-03)" 'colecoesemu +NAO EXECUTADO'

# 8b — marcador CONVIVENDO com um exit 0 remanescente: o marcador vence.
reset_verde
printf 'passo abortou antes de rodar\n' > "$RES/nao_socialemu"
esperar 1 "C08b — nao_socialemu ao lado de exit 0 => VERMELHO" 'socialemu +NAO EXECUTADO'

# 9 — gate sem exit e sem marcador -> vermelho.
reset_verde
rm -f "$RES/exit_casca"
esperar 1 "C09 — casca sem exit e sem marcador => VERMELHO (CI-03)" 'casca +NAO EXECUTADO'

# 10 — exit vazio -> vermelho.
reset_verde
: > "$RES/exit_motor"
esperar 1 "C10 — exit_motor vazio => VERMELHO" 'motor +INVALIDO'

# 10b — exit só com espaço em branco também é vazio.
reset_verde
printf '   \n\n' > "$RES/exit_motor"
esperar 1 "C10b — exit_motor só com espaços => VERMELHO" 'motor +INVALIDO'

# 11 — exit não numérico -> vermelho.
reset_verde
printf 'ok\n' > "$RES/exit_analyze"
esperar 1 "C11 — exit_analyze não numérico => VERMELHO" 'analyze +INVALIDO'

# 11b — conteúdo que tentaria virar comando se algo fosse interpretado.
reset_verde
printf '0; rm -rf /\n' > "$RES/exit_billing"
esperar 1 "C11b — exit_billing com injeção de comando => VERMELHO, sem interpretar" \
          'billing +INVALIDO'

# 12 — gate desconhecido não apaga nem substitui um obrigatório.
reset_verde
printf '1\n' > "$RES/exit_gate_fantasma"
esperar 0 "C12a — gate desconhecido vermelho NÃO reprova o portão" 'gate_fantasma +IGNORADO'

reset_verde
rm -f "$RES/exit_composicao"
printf '0\n' > "$RES/exit_composicao_extra"
esperar 1 "C12b — gate desconhecido verde NÃO substitui composicao ausente" \
          'composicao +NAO EXECUTADO'

# 13 — tudo restaurado para zero -> verde de novo.
reset_verde
esperar 0 "C13 — obrigatórios restaurados em exit 0 => VERDE novamente"

printf '\n== fonte única inválida (falha fechada) ==\n'

# Fonte vazia não pode ser "nenhum obrigatório, logo verde".
reset_verde
: > "$TMP/vazia.txt"
bash "$PORTAO" "$TMP/vazia.txt" "$RES" > /dev/null 2>&1
[ "$?" = "2" ] && ok "C14 — fonte sem nenhum gate => exit 2 (reprova)" \
                || nok "C14 — fonte sem nenhum gate deveria dar exit 2"

# Nome com travessia de caminho reprova antes de virar leitura de arquivo.
printf '../../etc/passwd\n' > "$TMP/travessia.txt"
bash "$PORTAO" "$TMP/travessia.txt" "$RES" > /dev/null 2>&1
[ "$?" = "2" ] && ok "C15 — nome de gate com travessia de caminho => exit 2" \
                || nok "C15 — nome de gate com travessia deveria dar exit 2"

# Gate duplicado na fonte é erro de manutenção, não silêncio.
printf 'analyze\nanalyze\n' > "$TMP/dup.txt"
bash "$PORTAO" "$TMP/dup.txt" "$RES" > /dev/null 2>&1
[ "$?" = "2" ] && ok "C16 — gate duplicado na fonte => exit 2" \
                || nok "C16 — gate duplicado deveria dar exit 2"

# Fonte inexistente reprova.
bash "$PORTAO" "$TMP/nao_existe.txt" "$RES" > /dev/null 2>&1
[ "$?" = "2" ] && ok "C17 — fonte única ausente => exit 2" \
                || nok "C17 — fonte única ausente deveria dar exit 2"

# Diretório de resultados inexistente reprova.
bash "$PORTAO" "$FONTE" "$TMP/sem_dir" > /dev/null 2>&1
[ "$?" = "2" ] && ok "C18 — diretório de resultados ausente => exit 2" \
                || nok "C18 — diretório ausente deveria dar exit 2"


printf '\n== fronteira de bloco run: cada run: e um script proprio (OS 40-C9) ==\n'

# ---------------------------------------------------------------------------
# RB01-RB14 — O ESTADO SHELL NAO ATRAVESSA A FRONTEIRA DO BLOCO `run:`
# ---------------------------------------------------------------------------
#
# Cada `run:` do Actions e um script e um processo shell proprios: um heredoc,
# uma continuacao fisica ou uma citacao aberta ao fim de um bloco morre no EOF
# daquele script e NAO alcanca o bloco seguinte. A OS 40-R9 mediu o falso verde
# `NX5`: `cat <<true` no fim de um bloco punha o bloco seguinte inteiro na classe
# HEREDOC, e a escrita forjada de evidencia sumia da guarda.
#
# CADA CASO E MEDIDO EM TRES ORACULOS INDEPENDENTES:
#   1. o SHELL REAL — cada bloco `run:` extraido como script separado e
#      executado; a sentinela da carga nasce, ou nao;
#   2. `classificar_workflow`, desta suite;
#   3. `vivas_de`, extraida da AUTORIDADE EXTERNA e rodada aqui.
# O resultado vem primeiro do shell real; so depois se compara as leituras.

RB="$TMP/rb"; mkdir -p "$RB"
RB_ARQ=''
rb_novo()  { RB_ARQ="$RB/$1.yml"; : > "$RB_ARQ"; }
rb_l()     { printf '%s\n' "$1" >> "$RB_ARQ"; }
rb_passo() { rb_l "      - name: \"$1\""; rb_l "        run: |${2:-}"; }

# vivas_de vem da autoridade externa, extraida por texto e rodada em SUBSHELL:
# dar source nela no processo principal executaria a autoridade inteira.
sed -n '/^vivas_de() {/,/^}$/p' "$AUTORIDADE_EXTERNA" > "$TMP/vivas_rb.sh"
if [ ! -s "$TMP/vivas_rb.sh" ]; then
  nok "RB00 — nao foi possivel extrair vivas_de da autoridade externa"
else
  . "$TMP/vivas_rb.sh"
fi

# `rb_extrai <yml>` — reparte o workflow em um script por bloco `run:`, dedentado
# pela base do bloco, exatamente como o Actions entrega ao bash. E um oraculo
# INDEPENDENTE de classificar_workflow: nao chama nada desta suite.
rb_extrai() {
  rm -f "$RB"/b_*.sh
  RBD="$RB" awk '
    { line=$0; sub(/\r$/,"",line); match(line,/^ */); i=RLENGTH; nu=substr(line,i+1)
      if (aguarda && nu!="") { base=i; aguarda=0; inb=1 }
      if (inb) {
        if (nu!="" && i<base) { inb=0 }
        else { print substr(line,base+1) >> (ENVIRON["RBD"] "/b_" nb ".sh"); next }
      }
      if (nu=="run: |" || nu=="run: |-" || nu=="run: |+") { nb++; aguarda=1; base=0; inb=0; next }
    }' "$1"
}

# `esperar_sentinela <yml> <sentinela> <EXISTE|AUSENTE> <desc>` — o shell real,
# um bloco por processo.
esperar_sentinela() {
  local yml="$1" sen="$2" quer="$3" desc="$4" b real
  case "$yml" in */*) : ;; *) yml="$RB/$yml.yml" ;; esac
  rb_extrai "$yml"
  rm -f "$RB"/S_*
  for b in "$RB"/b_*.sh; do [ -e "$b" ] || continue; ( cd "$RB" && bash "$b" ) >/dev/null 2>&1; done
  if [ -e "$RB/$sen" ]; then real=EXISTE; else real=AUSENTE; fi
  if [ "$real" = "$quer" ]; then
    ok "$desc (shell real: $real)"
  else
    nok "$desc — shell real deu $real, esperado $quer"
  fi
}

# `esperar_sentinela_sh <arq> <sentinela> <EXISTE|AUSENTE> <desc>` — arquivo
# inteiro como UM script (o caso `.sh`, sem repartir por `run:`).
esperar_sentinela_sh() {
  local arq="$1" sen="$2" quer="$3" desc="$4" real
  rm -f "$RB"/S_*
  ( cd "$RB" && bash "$arq" ) >/dev/null 2>&1
  if [ -e "$RB/$sen" ]; then real=EXISTE; else real=AUSENTE; fi
  if [ "$real" = "$quer" ]; then
    ok "$desc (shell real, script unico: $real)"
  else
    nok "$desc — shell real deu $real, esperado $quer"
  fi
}

# `esperar_viva <yml> <linha crua> <SIM|NAO> <desc>` — a segunda leitura.
esperar_viva() {
  local yml="$1" linha="$2" quer="$3" desc="$4" real
  vivas_de "$yml" "$RB/vivas.out"
  if grep -qF -- "$linha" "$RB/vivas.out"; then real=SIM; else real=NAO; fi
  if [ "$real" = "$quer" ]; then
    ok "$desc (vivas_de: $real)"
  else
    nok "$desc — vivas_de deu $real, esperado $quer"
  fi
}

# RB01 — heredoc aberto na ULTIMA linha do bloco; proximo bloco comeca com carga.
rb_novo RB01
rb_passo "RB01a — abre heredoc no fim do bloco"
rb_l "          echo topo > S_RB01a"
rb_l "          cat <<FIM_RB01"
rb_passo "RB01b — bloco seguinte"
rb_l "          echo VIVO > S_RB01b"
esperar_sentinela RB01 S_RB01b EXISTE "RB01 — a carga do bloco seguinte executa"
esperar_classe "$RB/RB01.yml" 'echo VIVO > S_RB01b' CODIGO "RB01 — carga do bloco seguinte e CODIGO"
esperar_viva "$RB/RB01.yml" 'echo VIVO > S_RB01b' SIM "RB01 — carga do bloco seguinte e viva"

# RB02 — mesma coisa com `run: |-` no bloco que abre.
rb_novo RB02
rb_passo "RB02a" "-"
rb_l "          cat <<FIM_RB02"
rb_passo "RB02b"
rb_l "          echo VIVO > S_RB02"
esperar_sentinela RB02 S_RB02 EXISTE "RB02 — run: |- nao deixa o estado atravessar"
esperar_classe "$RB/RB02.yml" 'echo VIVO > S_RB02' CODIGO "RB02 — carga apos run: |- e CODIGO"

# RB03 — `run: |+`.
rb_novo RB03
rb_passo "RB03a" "+"
rb_l "          cat <<FIM_RB03"
rb_passo "RB03b"
rb_l "          echo VIVO > S_RB03"
esperar_sentinela RB03 S_RB03 EXISTE "RB03 — run: |+ nao deixa o estado atravessar"
esperar_classe "$RB/RB03.yml" 'echo VIVO > S_RB03' CODIGO "RB03 — carga apos run: |+ e CODIGO"

# RB04 — `cat <<-FIM` sem terminador ao fim do bloco.
rb_novo RB04
rb_passo "RB04a"
rb_l "          cat <<-FIM_RB04"
rb_passo "RB04b"
rb_l "          echo VIVO > S_RB04"
esperar_sentinela RB04 S_RB04 EXISTE "RB04 — cat <<- sem terminador nao atravessa"
esperar_classe "$RB/RB04.yml" 'echo VIVO > S_RB04' CODIGO "RB04 — carga apos <<- aberto e CODIGO"

# RB05 — barra de continuacao como ultimo caractere shell do bloco A.
rb_novo RB05
rb_passo "RB05a"
rb_l "          echo antes > S_RB05a"
rb_l "          echo cont \\"
rb_passo "RB05b"
rb_l "          echo VIVO > S_RB05"
if grep -qE 'echo cont \\$' "$RB/RB05.yml"; then
  ok "RB05 — a barra de continuacao chegou intacta ao vetor"
else
  nok "RB05 — a barra de continuacao NAO chegou ao vetor"
fi
esperar_sentinela RB05 S_RB05 EXISTE "RB05 — continuacao no fim do bloco nao concatena com o proximo"
esperar_classe "$RB/RB05.yml" 'echo VIVO > S_RB05' CODIGO "RB05 — carga do proximo bloco e CODIGO"
esperar_viva "$RB/RB05.yml" 'echo VIVO > S_RB05' SIM "RB05 — carga do proximo bloco e viva"

# RB06 — heredoc REAL, com terminador dentro do MESMO bloco: corpo inerte,
# codigo posterior vive.
rb_novo RB06
rb_passo "RB06 heredoc fechado no bloco"
rb_l "          cat <<FIM_RB06"
rb_l "          echo NAO > S_RB06body"
rb_l "          FIM_RB06"
rb_l "          echo VIVO > S_RB06"
esperar_sentinela RB06 S_RB06 EXISTE "RB06 — codigo apos o terminador executa"
esperar_sentinela RB06 S_RB06body AUSENTE "RB06 — o corpo do heredoc nao executa"
esperar_classe "$RB/RB06.yml" 'echo NAO > S_RB06body' HEREDOC "RB06 — corpo do heredoc e HEREDOC"
esperar_classe "$RB/RB06.yml" 'echo VIVO > S_RB06' CODIGO "RB06 — codigo apos o terminador e CODIGO"

# RB07 — texto `run: |` DENTRO do corpo de um heredoc: nao encerra nem reinicia.
rb_novo RB07
rb_passo "RB07 run no corpo"
rb_l "          cat <<FIM_RB07"
rb_l "          run: |"
rb_l "          echo NAO > S_RB07body"
rb_l "          FIM_RB07"
rb_l "          echo VIVO > S_RB07"
esperar_sentinela RB07 S_RB07body AUSENTE "RB07 — o corpo com texto run: | nao executa"
esperar_classe "$RB/RB07.yml" 'echo NAO > S_RB07body' HEREDOC "RB07 — apos texto run: | no corpo, a linha segue HEREDOC"
esperar_classe "$RB/RB07.yml" 'echo VIVO > S_RB07' CODIGO "RB07 — depois do terminador real volta a CODIGO"

# RB08 — texto `- name:` DENTRO do corpo de um heredoc: nao cria passo.
rb_novo RB08
rb_passo "RB08 name no corpo"
rb_l "          cat <<FIM_RB08"
rb_l "          - name: fake"
rb_l "          echo NAO > S_RB08body"
rb_l "          FIM_RB08"
rb_l "          echo VIVO > S_RB08"
esperar_classe "$RB/RB08.yml" '- name: fake' HEREDOC "RB08 — - name: no corpo do heredoc e HEREDOC, nao PASSO"
esperar_classe "$RB/RB08.yml" 'echo VIVO > S_RB08' CODIGO "RB08 — depois do terminador real volta a CODIGO"

# RB09 — string shell contendo `run: |`: nao e fronteira.
rb_novo RB09
rb_passo "RB09 string com run"
rb_l "          echo \"run: |\" > /dev/null"
rb_l "          echo VIVO > S_RB09"
esperar_sentinela RB09 S_RB09 EXISTE "RB09 — a carga apos a string executa"
esperar_classe "$RB/RB09.yml" 'echo "run: |" > /dev/null' CODIGO "RB09 — string com run: | e CODIGO, nao fronteira"
esperar_classe "$RB/RB09.yml" 'echo VIVO > S_RB09' CODIGO "RB09 — a carga seguinte e CODIGO"

# RB10 — dois blocos integros consecutivos: nenhum vazamento.
rb_novo RB10
rb_passo "RB10a"; rb_l "          echo A > S_RB10a"
rb_passo "RB10b"; rb_l "          echo B > S_RB10b"
esperar_sentinela RB10 S_RB10a EXISTE "RB10 — primeiro bloco executa"
esperar_sentinela RB10 S_RB10b EXISTE "RB10 — segundo bloco executa"
esperar_classe "$RB/RB10.yml" 'echo A > S_RB10a' CODIGO "RB10 — primeiro bloco e CODIGO"
esperar_classe "$RB/RB10.yml" 'echo B > S_RB10b' CODIGO "RB10 — segundo bloco e CODIGO"

# RB11 — bloco novo comeca com linha vazia e comentario: base e estado corretos.
rb_novo RB11
rb_passo "RB11"
rb_l ""
rb_l "          # comentario antes do primeiro comando"
rb_l "          echo VIVO > S_RB11"
esperar_sentinela RB11 S_RB11 EXISTE "RB11 — a carga apos vazia+comentario executa"
esperar_classe "$RB/RB11.yml" '# comentario antes do primeiro comando' COMENTARIO "RB11 — o comentario e COMENTARIO"
esperar_classe "$RB/RB11.yml" 'echo VIVO > S_RB11' CODIGO "RB11 — a carga apos vazia+comentario e CODIGO"

# RB12 — arquivo `.sh` (coluna zero) com texto `run: |`: nenhum reset artificial;
# o arquivo inteiro e UM script.
rb_novo RB12
rb_l "cat <<FIM_RB12"
rb_l "run: |"
rb_l "echo NAO > S_RB12body"
rb_l "FIM_RB12"
rb_l "echo VIVO > S_RB12"
esperar_sentinela_sh "$RB/RB12.yml" S_RB12 EXISTE "RB12 — .sh inteiro e um script; o codigo apos o terminador executa"
esperar_sentinela_sh "$RB/RB12.yml" S_RB12body AUSENTE "RB12 — o corpo do heredoc no .sh nao executa"
esperar_classe "$RB/RB12.yml" 'echo NAO > S_RB12body' HEREDOC "RB12 — sem reset artificial: corpo segue HEREDOC apesar do texto run: |"

# RB13 — ambiguidade REAL antes da fronteira: fail-closed no bloco de origem, sem
# contaminar o seguinte.
rb_novo RB13
rb_passo "RB13a ambiguidade"
rb_l "          echo topo > S_RB13a"
rb_l "          cat <<FIM_RB13 \"aberta"
rb_passo "RB13b"
rb_l "          echo VIVO > S_RB13b"
esperar_classe "$RB/RB13.yml" 'cat <<FIM_RB13 "aberta' AMBIGUO "RB13 — a citacao que nao fecha e AMBIGUO (fail-closed na origem)"
esperar_classe "$RB/RB13.yml" 'echo VIVO > S_RB13b' CODIGO "RB13 — o bloco seguinte nao e contaminado: CODIGO"
esperar_sentinela RB13 S_RB13b EXISTE "RB13 — o bloco seguinte, como script proprio, executa"

# RB14 — tres blocos; o primeiro termina em heredoc aberto; os dois seguintes
# sao classificados independentemente.
rb_novo RB14
rb_passo "RB14a"; rb_l "          cat <<FIM_RB14"
rb_passo "RB14b"; rb_l "          echo B > S_RB14b"
rb_passo "RB14c"; rb_l "          echo C > S_RB14c"
esperar_sentinela RB14 S_RB14b EXISTE "RB14 — segundo bloco executa"
esperar_sentinela RB14 S_RB14c EXISTE "RB14 — terceiro bloco executa"
esperar_classe "$RB/RB14.yml" 'echo B > S_RB14b' CODIGO "RB14 — segundo bloco e CODIGO"
esperar_classe "$RB/RB14.yml" 'echo C > S_RB14c' CODIGO "RB14 — terceiro bloco e CODIGO"

printf '\n== autoprotecao: a correcao de fronteira esta viva (OS 40-C9) ==\n'

# A prova de que o instrumento pega o que deve: duas mutacoes temporarias, em
# COPIAS FORA do toplevel (dentro de $TMP, destruido no trap), extraidas e
# rodadas em SUBSHELL. Falha de copia ou de extracao vira FAIL.
auto_classe() {  # <copia.sh> <yml> <linha espremida> -> ecoa a classe daquela linha
  local copia="$1" yml="$2" linha="$3" t
  t="$(mktemp)" || { printf 'SEM_MKTEMP'; return; }
  awk '/^abertura_de_heredoc\(\) \{/,/^\}$/' "$copia" >  "$t"
  awk '/^classificar_workflow\(\) \{/,/^\}$/' "$copia" >> "$t"
  if ! grep -q 'ABERTURA_AMBIGUA' "$t"; then rm -f "$t"; printf 'EXTRACAO_VAZIA'; return; fi
  (
    ASPA_SIMPLES="'"; ASPA_DUPLA='"'
    . "$t"
    o="$(mktemp)"
    classificar_workflow "$yml" "$o"
    awk -F'\t' -v L="$linha" '$4==L{print $3; f=1; exit} END{if(!f)print "AUSENTE"}' "$o"
    rm -f "$o"
  )
  rm -f "$t"
}

if [ ! -r "$0" ]; then
  nok "AUTO — nao consigo ler a propria fonte ($0) para as mutacoes"
else
  # Prova de vida da bancada: na COPIA INTACTA a carga do bloco B ja e CODIGO.
  auto_intacta="$(auto_classe "$0" "$RB/RB01.yml" 'echo VIVO > S_RB01b')"
  if [ "$auto_intacta" = CODIGO ]; then
    ok "AUTO-0 — copia extraida INTACTA classifica a carga do bloco B como CODIGO"
  else
    nok "AUTO-0 — extracao da propria fonte falhou ou divergiu: obtido '$auto_intacta'"
  fi

  # MUTACAO A — remove o reset da fronteira (restaura o vazamento NX5). A carga
  # do bloco B tem de voltar a HEREDOC; se continuar CODIGO, a correcao nao era
  # load-bearing e o instrumento estaria morto.
  mutA="$TMP/mutA_$$.sh"
  sed -e "/^            fim_heredoc=''$/d" \
      -e '/^            her_tabs=0$/d' \
      -e "/^            acumulada=''$/d" \
      -e '/^            continuando=0$/d' "$0" > "$mutA"
  if cmp -s "$0" "$mutA"; then
    nok "AUTO-A — INSTRUMENTO INVALIDO: a mutacao que remove o reset nao mudou um byte"
  else
    resA="$(auto_classe "$mutA" "$RB/RB01.yml" 'echo VIVO > S_RB01b')"
    if [ "$resA" = HEREDOC ]; then
      ok "AUTO-A — sem o reset da fronteira o bloco B some como HEREDOC: a correcao e load-bearing"
    else
      nok "AUTO-A — esperado HEREDOC na copia sem reset (vazamento), obtido '$resA'"
    fi
  fi
  rm -f "$mutA"

  # MUTACAO B — reset INDISCRIMINADO por TEXTO: zera o estado sempre que a linha
  # parece `run: |`/`- name:`, sem olhar indentacao. RB07 pega: o texto `run: |`
  # no CORPO de um heredoc passaria a reiniciar o bloco e o dado viraria codigo.
  mutB="$TMP/mutB_$$.sh"
  sed '/if \[ -n "\$fim_heredoc" \]; then/a\
        case "$nu" in "run: |"*|"- name:"*) fim_heredoc="" ;; esac' "$0" > "$mutB"
  if cmp -s "$0" "$mutB"; then
    nok "AUTO-B — INSTRUMENTO INVALIDO: a mutacao do reset indiscriminado nao mudou um byte"
  else
    resB="$(auto_classe "$mutB" "$RB/RB07.yml" 'echo NAO > S_RB07body')"
    if [ "$resB" = CODIGO ]; then
      ok "AUTO-B — reset indiscriminado por texto transforma corpo de heredoc em codigo: RB07 pega"
    else
      nok "AUTO-B — esperado CODIGO na copia com reset indiscriminado (bug), obtido '$resB'"
    fi
  fi
  rm -f "$mutB"
fi
printf '\n----------------------------------------\n'
printf 'casos ok: %d | casos com falha: %d\n' "$passou" "$falhou"

if [ "$falhou" -eq 0 ]; then
  printf 'TESTE DO PORTÃO: VERDE\n'
  exit 0
fi

printf 'TESTE DO PORTÃO: VERMELHO\n'
exit 1
