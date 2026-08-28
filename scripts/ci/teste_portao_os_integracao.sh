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

classificar_workflow() {
  local arq="$1" saida="$2"
  local n=0 passo=0 bruta linha nu espremida fim_heredoc='' resto
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

      # Dentro de heredoc NADA é código: é dado que o shell entrega a outro
      # programa. Uma invocação escondida aí é texto, e texto não roda.
      if [ -n "$fim_heredoc" ]; then
        [ "$nu" = "$fim_heredoc" ] && fim_heredoc=''
        printf '%s\t%s\tHEREDOC\t%s\n' "$n" "$passo" "$espremida"
        continue
      fi

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

      printf '%s\t%s\tCODIGO\t%s\n' "$n" "$passo" "$espremida"

      # ABERTURA DE HEREDOC, depois de classificar a própria linha: o `<<` mora
      # numa linha de código, e o que vira dado é o que vem DEPOIS dela.
      case "$nu" in
        *'<<'*)
          resto="${nu##*<<}"
          resto="${resto#-}"
          resto="${resto#"${resto%%[![:blank:]]*}"}"
          resto="${resto%%[[:blank:]]*}"
          # AS ASPAS SAEM POR VARIAVEL, e nao por barra invertida dentro de
          # `"..."`. `\'` ali nao e escape em sh: a analise lexica do proprio
          # contrato de conteudo lê aquilo como uma string que nunca fecha, e um
          # arquivo "aberto" faz TODA agulha virar texto inerte.
          resto="${resto//$ASPA_SIMPLES/}"
          resto="${resto//$ASPA_DUPLA/}"
          [ -n "$resto" ] && fim_heredoc="$resto"
          ;;
      esac
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
          if (modo == "mover")    { guardada = L[i]; continue }
          if (modo == "antes")    { print rec extra; print L[i]; continue }
          if (modo == "depois")   { print L[i]; print rec extra; continue }
        }
        print L[i]
        if (modo == "purga_depois" && esp(L[i]) == extra2) print rec extra
        if (modo == "mover" && guardada != "" && L[i] ~ /flutter analyze --no-fatal-infos/) {
          print guardada; guardada = ""
        }
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
}

vetores_do_passo_zero portaoci
vetores_do_passo_zero autverif
vetores_do_passo_zero contratosui

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

printf '\n----------------------------------------\n'
printf 'casos ok: %d | casos com falha: %d\n' "$passou" "$falhou"

if [ "$falhou" -eq 0 ]; then
  printf 'TESTE DO PORTÃO: VERDE\n'
  exit 0
fi

printf 'TESTE DO PORTÃO: VERMELHO\n'
exit 1
