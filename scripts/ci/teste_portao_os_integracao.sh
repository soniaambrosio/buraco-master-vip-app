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

for arquivo in "$PORTAO" "$FONTE" "$YML"; do
  if [ ! -f "$arquivo" ]; then
    printf 'teste do portão: arquivo obrigatório ausente: %s\n' "$arquivo" >&2
    exit 1
  fi
done

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
GATES_FONTE="$(gates_da_fonte)"

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
# A INVOCAÇÃO OFICIAL DA TESTEMUNHA DO `contratosui` — O PASSO ZERO (OS 40-C4)
# ---------------------------------------------------------------------------
#
# O que o CI de fato executa, por extenso, e ESPREMIDO — o YAML alinha em
# colunas, e uma guarda que dependesse da largura do alinhamento reprovaria na
# próxima vez que alguém alinhasse a tabela.
readonly INVOCACAO_OFICIAL='bash scripts/ci/testemunha_contratosui.sh scripts/ci/teste_contrato_suites.sh 2>&1 | tee t_contratosui.log'
readonly CAPTURA_OFICIAL='echo ${PIPESTATUS[0]} > exit_contratosui'
# O NÚCLEO é o que identifica uma CHAMADA à testemunha, e não uma menção a ela.
# `if [ ! -f scripts/ci/testemunha_contratosui.sh ]` cita o arquivo e não o
# executa; `bash scripts/ci/testemunha_contratosui.sh` executa.
readonly NUCLEO_INVOCACAO='bash scripts/ci/testemunha_contratosui.sh'
readonly PASSO_DA_TESTEMUNHA='0b'
readonly CONSUMIDOR_DA_EVIDENCIA='scripts/ci/verificar_contrato_suites.sh'

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

# `guarda_invocacao_testemunha <yml>` — exit 0 só quando a invocação oficial
# está viva, única, exata, no passo certo, ligada ao `tee` real, antes de quem
# consome a evidência dela, e com o código de saída capturado logo em seguida.
#
# Cada recusa é NOMEADA. Uma guarda que responde "não" sem dizer qual das oito
# perguntas falhou é uma guarda que ninguém consegue consertar sem afrouxar.
guarda_invocacao_testemunha() {
  local yml="$1" reg="$TMP/classificado.txt" ruim=0
  local ln passo tipo texto
  local linha_inv=0 passo_inv=0 vivas=0
  local linha_cap=0 passo_cap=0 capturas=0
  local passo_consumidor=0 evidencia_antes=0 entre=0

  classificar_workflow "$yml" "$reg"

  while IFS=$'\t' read -r ln passo tipo texto; do
    case "$tipo" in
      CODIGO)
        if [ "$texto" = "$INVOCACAO_OFICIAL" ]; then
          vivas=$((vivas + 1))
          [ "$linha_inv" -eq 0 ] && { linha_inv="$ln"; passo_inv="$passo"; }
        fi
        if [ "$texto" = "$CAPTURA_OFICIAL" ]; then
          capturas=$((capturas + 1))
          [ "$linha_cap" -eq 0 ] && { linha_cap="$ln"; passo_cap="$passo"; }
        fi
        case "$texto" in
          *"$NUCLEO_INVOCACAO"*)
            if [ "$texto" != "$INVOCACAO_OFICIAL" ]; then
              printf 'INVOCACAO: chamada da testemunha com forma NAO OFICIAL na linha %s: %s\n' "$ln" "$texto"
              ruim=1
            fi
            case "$texto" in
              echo*|printf*|*'echo '*"$NUCLEO_INVOCACAO"*|*'printf '*"$NUCLEO_INVOCACAO"*)
                printf 'INVOCACAO: a linha %s IMPRIME a invocacao em vez de executa-la: %s\n' "$ln" "$texto"
                ruim=1
                ;;
            esac
            case "$texto" in
              *'|| true'*|*'|| :'*|*'||true'*|*'|| /bin/true'*|*'|| echo'*|*'; true'*|*'|| exit 0'*)
                printf 'INVOCACAO: a linha %s neutraliza o codigo de saida da testemunha: %s\n' "$ln" "$texto"
                ruim=1
                ;;
            esac
            ;;
        esac
        case "$texto" in
          *"$CONSUMIDOR_DA_EVIDENCIA"*)
            [ "$passo_consumidor" -eq 0 ] && passo_consumidor="$passo"
            ;;
        esac
        ;;
      COMENTARIO | HEREDOC)
        case "$texto" in
          *"$NUCLEO_INVOCACAO"*)
            printf 'INVOCACAO: a invocacao aparece como %s na linha %s — texto nao executa: %s\n' "$tipo" "$ln" "$texto"
            ruim=1
            ;;
        esac
        ;;
    esac
  done < "$reg"

  if [ "$vivas" -eq 0 ]; then
    printf 'INVOCACAO: o workflow nao tem a invocacao oficial VIVA: %s\n' "$INVOCACAO_OFICIAL"
    ruim=1
  elif [ "$vivas" -gt 1 ]; then
    printf 'INVOCACAO: a invocacao oficial aparece %s vezes — duplicada, e o exit lido nao e o de ninguem\n' "$vivas"
    ruim=1
  fi

  if [ "$capturas" -ne 1 ]; then
    printf 'INVOCACAO: a captura oficial do codigo de saida aparece %s vez(es): %s\n' "$capturas" "$CAPTURA_OFICIAL"
    ruim=1
  fi

  if [ "$linha_inv" -gt 0 ]; then
    # O PASSO CERTO. Mover a invocação para outro passo a tira do lugar em que a
    # evidência é produzida antes de ser consumida.
    passo_nome="$(awk -F'\t' -v p="$passo_inv" '$3 == "PASSO" && $2 == p { print $4 }' "$reg")"
    case "$passo_nome" in
      *"\"$PASSO_DA_TESTEMUNHA "*) ;;
      *)
        printf 'INVOCACAO: a invocacao esta no passo "%s", e nao no passo %s\n' "$passo_nome" "$PASSO_DA_TESTEMUNHA"
        ruim=1
        ;;
    esac

    # A CAPTURA VEM LOGO DEPOIS, no mesmo passo, e SEM NADA NO MEIO. Uma linha
    # entre as duas troca o `PIPESTATUS` que é lido: o exit deixa de ser o da
    # testemunha sem que uma letra da invocação mude.
    if [ "$linha_cap" -le "$linha_inv" ] || [ "$passo_cap" -ne "$passo_inv" ]; then
      printf 'INVOCACAO: a captura do codigo de saida nao vem logo depois da invocacao (linha %s contra %s)\n' \
        "$linha_cap" "$linha_inv"
      ruim=1
    else
      entre="$(awk -F'\t' -v a="$linha_inv" -v b="$linha_cap" \
        '$3 == "CODIGO" && $1 > a && $1 < b { n++ } END { print n + 0 }' "$reg")"
      if [ "$entre" -ne 0 ]; then
        printf 'INVOCACAO: ha %s linha(s) de codigo entre a invocacao e a captura do PIPESTATUS\n' "$entre"
        ruim=1
      fi
    fi

    # A EVIDÊNCIA NÃO PODE NASCER ANTES DA EXECUÇÃO. Um `exit_contratosui` ou um
    # `t_contratosui.log` escrito antes da invocação é resultado fabricado.
    evidencia_antes="$(awk -F'\t' -v a="$linha_inv" '
      $3 == "CODIGO" && $1 < a && ($4 ~ /> *exit_contratosui/ || $4 ~ /t_contratosui\.log/) { n++ }
      END { print n + 0 }' "$reg")"
    if [ "$evidencia_antes" -ne 0 ]; then
      printf 'INVOCACAO: %s linha(s) criam evidencia de contratosui ANTES da execucao verdadeira\n' "$evidencia_antes"
      ruim=1
    fi

    # ANTES DE QUEM CONSOME. A FASE A e a FASE B leem o que este passo produziu.
    if [ "$passo_consumidor" -eq 0 ]; then
      printf 'INVOCACAO: o workflow nao tem nenhum consumidor vivo de %s\n' "$CONSUMIDOR_DA_EVIDENCIA"
      ruim=1
    elif [ "$passo_inv" -ge "$passo_consumidor" ]; then
      printf 'INVOCACAO: a invocacao (passo %s) nao vem antes de quem consome a evidencia dela (passo %s)\n' \
        "$passo_inv" "$passo_consumidor"
      ruim=1
    fi
  fi

  return "$ruim"
}

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
# é `guarda_invocacao_testemunha`, logo abaixo: ela classifica o YAML linha a
# linha e cobra a invocação oficial VIVA, ÚNICA, com os argumentos exatos, no
# passo correto, ligada ao `tee` real, antes de quem consome a evidência dela, e
# sem nada entre a chamada e a captura do código de saída.
faltando=""
contem_gate contratosui || faltando=" contratosui-fora-da-fonte"
guarda_invocacao_testemunha "$YML" > "$TMP/i10.txt" 2>&1 \
  || faltando="$faltando invocacao-oficial-desligada"
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

printf '\n== a invocação oficial da testemunha, sabotada de onze maneiras ==\n'

# UMA GUARDA QUE NUNCA REPROVOU NÃO É GUARDA. I10 prova que a árvore íntegra
# passa; sem os vetores abaixo, um `guarda_invocacao_testemunha` que devolvesse
# zero para tudo passaria em I10 do mesmo jeito — e foi exatamente assim que a
# invocação oficial ficou sem prova nenhuma entre a C3 e a R4.
#
# Cada vetor parte de uma CÓPIA descartável do workflow íntegro, declara a
# âncora que pretende atingir, aplica UMA sabotagem e confere a pós-condição
# antes de julgar. Uma sabotagem que não aconteceu não pode virar verde: é o
# mesmo instrumento que `teste_contrato_suites.sh` usa, e pela mesma razão.

readonly LINHA_INVOCACAO_ERE='^ *bash scripts/ci/testemunha_contratosui\.sh scripts/ci/teste_contrato_suites\.sh 2>&1 \| tee t_contratosui\.log'
readonly LINHA_CAPTURA_ERE='^ *echo \$\{PIPESTATUS\[0\]\} > exit_contratosui'

FORJA_DIG=''
FORJA_MOTIVO=''
FORJA_ARQ=''

# `forjar <nome> <ere> <n>` — a cópia íntegra, com a âncora conferida ANTES da
# sabotagem. Âncora que casa um número diferente do declarado é âncora que
# envelheceu, e medir com ela é medir outra coisa.
forjar() {
  local nome="$1" ere="$2" n="$3" viu
  FORJA_ARQ="$TMP/$nome"
  FORJA_DIG=''
  FORJA_MOTIVO=''
  cp "$YML" "$FORJA_ARQ"
  viu="$(grep -cE "$ere" "$FORJA_ARQ")" || viu=0
  if [ "$viu" -ne "$n" ]; then
    FORJA_MOTIVO="a âncora /$ere/ casa $viu vez(es) na cópia e o vetor declara $n"
    return 1
  fi
  FORJA_DIG="$(tr -d '\r' < "$FORJA_ARQ" | sha256sum)"
  return 0
}

# `esperar_invocacao <exit> <desc> <ere-pos> <n-pos> [agulha]` — o veredito.
#
# `<ere-pos>` vazio significa CONTROLE: a cópia não pode ter mudado um byte.
esperar_invocacao() {
  local esperado="$1" desc="$2" ere="$3" n="${4:-}" agulha="${5:-}" real agora viu
  if [ -n "$FORJA_MOTIVO" ]; then
    nok "$desc — INSTRUMENTO INVÁLIDO: $FORJA_MOTIVO"
    return
  fi
  agora="$(tr -d '\r' < "$FORJA_ARQ" | sha256sum)"
  if [ -z "$ere" ]; then
    if [ "$agora" != "$FORJA_DIG" ]; then
      nok "$desc — INSTRUMENTO INVÁLIDO: o controle mudou o workflow, e ele não devia mudar"
      return
    fi
  else
    if [ "$agora" = "$FORJA_DIG" ]; then
      nok "$desc — INSTRUMENTO INVÁLIDO: a sabotagem não mudou um byte da cópia"
      return
    fi
    viu="$(grep -cE "$ere" "$FORJA_ARQ")" || viu=0
    if [ "$viu" -ne "$n" ]; then
      nok "$desc — INSTRUMENTO INVÁLIDO: a pós-condição /$ere/ aparece $viu vez(es), e o vetor declara $n"
      return
    fi
  fi
  guarda_invocacao_testemunha "$FORJA_ARQ" > "$TMP/guarda.txt" 2>&1
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

# A00 — CONTROLE. Sem ele, uma guarda que reprovasse SEMPRE passaria nos onze
# vetores abaixo e a seção inteira deixaria de medir.
forjar a00.yml "$LINHA_INVOCACAO_ERE" 1
esperar_invocacao 0 "A00 CONTROLE — cópia íntegra do workflow => guarda VERDE" ''

# A01 — a invocação simplesmente sumiu.
if forjar a01.yml "$LINHA_INVOCACAO_ERE" 1; then
  sed -i "\|bash scripts/ci/testemunha_contratosui.sh scripts/ci/teste_contrato_suites.sh|d" "$FORJA_ARQ"
fi
esperar_invocacao 1 "A01 — invocação ausente => VERMELHO" "$LINHA_INVOCACAO_ERE" 0 \
  'nao tem a invocacao oficial VIVA'

# A02 — a invocação virou comentário. O texto continua no arquivo, e o CI não
# executa uma linha sequer dela.
if forjar a02.yml "$LINHA_INVOCACAO_ERE" 1; then
  sed -i "s|^\( *\)bash scripts/ci/testemunha_contratosui.sh|\1# bash scripts/ci/testemunha_contratosui.sh|" "$FORJA_ARQ"
fi
esperar_invocacao 1 "A02 — invocação comentada => VERMELHO" '^ *# bash scripts/ci/testemunha_contratosui' 1 \
  'aparece como COMENTARIO'

# A03 — `echo` da invocação: ela é IMPRESSA, e não executada.
if forjar a03.yml "$LINHA_INVOCACAO_ERE" 1; then
  sed -i "s|^\( *\)bash scripts/ci/testemunha_contratosui.sh|\1echo bash scripts/ci/testemunha_contratosui.sh|" "$FORJA_ARQ"
fi
esperar_invocacao 1 "A03 — invocação dentro de um echo => VERMELHO" '^ *echo bash scripts/ci/testemunha_contratosui' 1 \
  'IMPRIME a invocacao'

# A04 — a invocação dentro de heredoc. É dado entregue a outro programa, e o
# `grep` que a C3 usava não sabia a diferença.
if forjar a04.yml "$LINHA_INVOCACAO_ERE" 1; then
  awk '
    { l = $0; sub(/\r$/, "", l) }
    l ~ /^ *bash scripts\/ci\/testemunha_contratosui\.sh scripts\/ci\/teste_contrato_suites\.sh/ {
      print "          cat <<FIMDOHEREDOC > /dev/null"
      print l
      print "FIMDOHEREDOC"
      next
    }
    { print l }
  ' "$FORJA_ARQ" > "$FORJA_ARQ.novo" && mv "$FORJA_ARQ.novo" "$FORJA_ARQ"
fi
esperar_invocacao 1 "A04 — invocação dentro de heredoc => VERMELHO" '^FIMDOHEREDOC' 1 \
  'aparece como HEREDOC'

# A05 — duplicada. Com duas chamadas na mesma pipeline de passo, o
# `PIPESTATUS` lido não é o de nenhuma das duas com certeza.
if forjar a05.yml "$LINHA_INVOCACAO_ERE" 1; then
  awk '
    { l = $0; sub(/\r$/, "", l) }
    { print l }
    l ~ /^ *bash scripts\/ci\/testemunha_contratosui\.sh scripts\/ci\/teste_contrato_suites\.sh/ { print l }
  ' "$FORJA_ARQ" > "$FORJA_ARQ.novo" && mv "$FORJA_ARQ.novo" "$FORJA_ARQ"
fi
esperar_invocacao 1 "A05 — invocação duplicada => VERMELHO" "$LINHA_INVOCACAO_ERE" 2 \
  'duplicada'

# A06 — deslocada para um passo depois de quem consome a evidência dela.
if forjar a06.yml "$LINHA_INVOCACAO_ERE" 1; then
  awk '
    { l = $0; sub(/\r$/, "", l) }
    l ~ /^ *bash scripts\/ci\/testemunha_contratosui\.sh scripts\/ci\/teste_contrato_suites\.sh/ { guardada = l; next }
    { print l }
    l ~ /flutter analyze --no-fatal-infos/ && guardada != "" { print guardada; guardada = "" }
  ' "$FORJA_ARQ" > "$FORJA_ARQ.novo" && mv "$FORJA_ARQ.novo" "$FORJA_ARQ"
fi
esperar_invocacao 1 "A06 — invocação movida para outro passo => VERMELHO" "$LINHA_INVOCACAO_ERE" 1 \
  'nao vem antes de quem consome'

# A07 — o `tee` real removido: a evidência do run deixa de nascer da execução.
if forjar a07.yml "$LINHA_INVOCACAO_ERE" 1; then
  awk '
    { l = $0; sub(/\r$/, "", l) }
    l ~ /^ *bash scripts\/ci\/testemunha_contratosui\.sh scripts\/ci\/teste_contrato_suites\.sh/ {
      sub(/ 2>&1 .*$/, "", l)
    }
    { print l }
  ' "$FORJA_ARQ" > "$FORJA_ARQ.novo" && mv "$FORJA_ARQ.novo" "$FORJA_ARQ"
fi
esperar_invocacao 1 "A07 — argumentos removidos (o tee real) => VERMELHO" "$LINHA_INVOCACAO_ERE" 0 \
  'forma NAO OFICIAL'

# A08 — argumento TROCADO: a testemunha continua sendo chamada, e passa a
# observar outra matriz.
if forjar a08.yml "$LINHA_INVOCACAO_ERE" 1; then
  sed -i "s|testemunha_contratosui.sh scripts/ci/teste_contrato_suites.sh|testemunha_contratosui.sh scripts/ci/isca_de_matriz.sh|" "$FORJA_ARQ"
fi
esperar_invocacao 1 "A08 — argumento trocado por outra matriz => VERMELHO" 'isca_de_matriz\.sh' 1 \
  'forma NAO OFICIAL'

# A09 — argumento ACRESCENTADO: um diretório de evidência escolhido por quem
# chama é o atalho que a própria testemunha existe para não ter.
if forjar a09.yml "$LINHA_INVOCACAO_ERE" 1; then
  sed -i "s|teste_contrato_suites.sh 2>&1|teste_contrato_suites.sh /tmp/preparado 2>\&1|" "$FORJA_ARQ"
fi
esperar_invocacao 1 "A09 — argumento acrescentado => VERMELHO" '/tmp/preparado' 1 \
  'forma NAO OFICIAL'

# A10 — a testemunha substituída pela chamada DIRETA à matriz. É a forma exata
# que existia antes da C3: a matriz volta a emitir o próprio boletim.
if forjar a10.yml "$LINHA_INVOCACAO_ERE" 1; then
  sed -i "s|bash scripts/ci/testemunha_contratosui.sh scripts/ci/teste_contrato_suites.sh|bash scripts/ci/teste_contrato_suites.sh|" "$FORJA_ARQ"
fi
esperar_invocacao 1 "A10 — testemunha trocada por chamada direta à matriz => VERMELHO" \
  '^ *bash scripts/ci/teste_contrato_suites\.sh 2>&1' 1 'nao tem a invocacao oficial VIVA'

# A11 — `|| true`: o vermelho da testemunha vira verde sem uma letra da
# invocação mudar de lugar.
if forjar a11.yml "$LINHA_INVOCACAO_ERE" 1; then
  sed -i "s|tee t_contratosui.log|tee t_contratosui.log \|\| true|" "$FORJA_ARQ"
fi
esperar_invocacao 1 "A11 — || true anexado à invocação => VERMELHO" 'tee t_contratosui\.log \|\| true' 1 \
  'neutraliza o codigo de saida'

# A12 — a mesma neutralização com `; true`, que um casamento por `||` não pega.
if forjar a12.yml "$LINHA_INVOCACAO_ERE" 1; then
  sed -i "s|tee t_contratosui.log|tee t_contratosui.log ; true|" "$FORJA_ARQ"
fi
esperar_invocacao 1 "A12 — ; true anexado à invocação => VERMELHO" 'tee t_contratosui\.log ; true' 1 \
  'neutraliza o codigo de saida'

# A13 — evidência FABRICADA antes da execução verdadeira.
if forjar a13.yml "$LINHA_CAPTURA_ERE" 1; then
  awk '
    { l = $0; sub(/\r$/, "", l) }
    l ~ /^ *bash scripts\/ci\/testemunha_contratosui\.sh scripts\/ci\/teste_contrato_suites\.sh/ {
      print "          echo 0 > exit_contratosui"
    }
    { print l }
  ' "$FORJA_ARQ" > "$FORJA_ARQ.novo" && mv "$FORJA_ARQ.novo" "$FORJA_ARQ"
fi
esperar_invocacao 1 "A13 — exit_contratosui fabricado ANTES da execução => VERMELHO" \
  '^ *echo 0 > exit_contratosui' 1 'ANTES da execucao verdadeira'

# A14 — a captura afastada da invocação: o `PIPESTATUS` lido passa a ser o de
# outra linha, e o exit da testemunha deixa de chegar ao portão.
if forjar a14.yml "$LINHA_CAPTURA_ERE" 1; then
  awk '
    { l = $0; sub(/\r$/, "", l) }
    l ~ /^ *echo \$\{PIPESTATUS\[0\]\} > exit_contratosui/ {
      print "          echo intruso | tee -a t_intruso.log"
    }
    { print l }
  ' "$FORJA_ARQ" > "$FORJA_ARQ.novo" && mv "$FORJA_ARQ.novo" "$FORJA_ARQ"
fi
esperar_invocacao 1 "A14 — linha intrusa entre a invocação e a captura => VERMELHO" \
  '^ *echo intruso \| tee -a t_intruso\.log' 1 'entre a invocacao e a captura'

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
