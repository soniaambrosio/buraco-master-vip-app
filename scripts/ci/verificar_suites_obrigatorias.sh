#!/usr/bin/env bash
# verificar_suites_obrigatorias.sh — impede que uma suite obrigatoria seja
# desligada em silencio, e que o PISO e o CONTEUDO da suite de alvos sejam
# afrouxados dentro do proprio arquivo que eles guardam.
#
# uso: verificar_suites_obrigatorias.sh <raiz_do_app> [workflow]
#
#   raiz_do_app  arvore em que as suites vivem — `app_build` no CI, `app` num
#                checkout normal.
#   workflow     opcional. Quando dado, as checagens de registro no CI tambem
#                rodam. No CI ele e sempre dado.
#
# ---------------------------------------------------------------------------
# O QUE ELE FECHA
# ---------------------------------------------------------------------------
#
# (1) INSTRUMENTACAO. O auxiliar `roda` do workflow escreve `nao_<chave>`
# quando a suite nao esta no disco, e o portao trata isso como NAO EXECUTADO —
# que nao reprova. Para os gates que dependem de codebase opcional isso e o
# comportamento certo, e este script NAO o altera: ele olha so a lista de
# `test/suites_obrigatorias.txt`, e para essa lista a ausencia e falha.
#
# (2) AUTORIDADE EXTERNA DO PISO E DO CONTEUDO. `a11y_alvos_amigos_test.dart`
# declara o piso de 48 pontos e os 75 casos DENTRO de si. Enquanto os dois
# morarem so la, baixar o piso para 40 ou trocar a suite por um caso trivial e
# uma edicao de UM arquivo, e a cadeia fica verde. O contrato
# `test/contrato_alvos_amigos.txt` guarda os dois fora da suite, e os CARIMBOS
# abaixo guardam o contrato fora do contrato: para afrouxar e preciso mexer no
# contrato, neste shell e na guarda Dart — tres arquivos, duas naturezas de
# autoridade, tudo no diff.
#
# (3) O CORPO DA GUARDA DART. Este script confere a impressao digital da REGIAO
# DE DECISAO de `test/ci/suites_obrigatorias_test.dart`; a guarda Dart confere a
# regiao de decisao DESTE arquivo. Neutralizar um dos dois — trocar a decisao
# final por `exit 0`, esvaziar o corpo, manter as mensagens e tirar o veredito —
# e visto pelo outro. As duas impressoes moram FORA das regioes que elas medem,
# senao cada edicao mudaria a impressao que a mede e o par nunca fecharia.
#
# ELE FALHA POR CONTA PROPRIA, com exit diferente de zero, em vez de depender de
# ser somado num portao la na frente. Um verificador cuja reprovacao precisa de
# outro passo para virar vermelho herda o defeito que veio consertar.
#
# ---------------------------------------------------------------------------
# ATE ONDE ELE ALCANCA
# ---------------------------------------------------------------------------
#
# Ele pega: apagar a suite, renomea-la, tirar a linha `roda` do workflow, tirar
# a chave de uma das duas listas de gate, esvaziar o manifesto, apagar o
# manifesto, apagar o contrato, baixar o piso no contrato ou na suite, mudar a
# contagem de casos ou de declaracoes, recarimbar a impressao dos 75 casos so no
# contrato, e neutralizar a guarda Dart.
#
# Ele NAO pega quem apagar o passo que o invoca. Nenhuma verificacao dentro de
# um workflow pode cobrir a propria remocao do workflow — a raiz de confianca
# termina ali. Quem cobre a remocao do PASSO e a guarda Dart, que le o workflow;
# e, se as duas cairem juntas, `matriz_amigos_test.dart`, que exige a existencia
# das duas e roda como gate proprio.

set -u

raiz="${1:-app_build}"
workflow="${2:-}"

# ===========================================================================
# OS CARIMBOS
# ===========================================================================
#
# Vivem AQUI, e nao dentro da regiao de decisao, por dois motivos:
#
#   * o de sempre — o contrato nao pode ser a unica testemunha de si mesmo;
#   * o aritmetico — `DIGEST_DECISAO_GUARDA` mede a guarda Dart, e a guarda Dart
#     mede a regiao de decisao DESTE arquivo. Se os carimbos morassem dentro da
#     regiao, atualizar um mudaria o que o outro mede, e o par nunca fecharia.
readonly CHAVE_MINIMA="a11yamigos"
readonly CHAVE_TESTEMUNHA="testemunha"
# A impressao digital do ARQUIVO INTEIRO da testemunha externa.
#
# Ela mora AQUI, fora da regiao de decisao, pelo motivo de sempre: dentro, cada
# recarimbo mudaria a regiao que a guarda Dart mede, e o par nunca fecharia.
#
# E ela e do arquivo INTEIRO, e nao de uma regiao: a testemunha nao tem
# marcador, e nao pode ter — o ataque que ela existe para pegar e justamente o
# codigo que se esconde fora da regiao analisada.
readonly DIGEST_TESTEMUNHA="d2d2db4d42e5d787799c7d7a3b0eb44ec56d088f0f3afc7e2fef82587bfd6e8b"
readonly PISO_CARIMBADO="48.0"
readonly CASOS_CARIMBADOS="75"
readonly DECLARACOES_CARIMBADAS="30"
readonly COMPARACOES_CARIMBADAS="17"
readonly DIGEST_CARIMBADO="f5f1d3879b9a5745b364298114eb8a911e474b1325163d72e89b24b6652e3ad6"
readonly DIGEST_DECISAO_GUARDA="c68a6c4d88774a072c242316fad4cbd8a9e96ad8b21f70999eaa39331b63afbe"

readonly MARCA_INICIO_DART="// ---8<--- DECISAO INICIO"
readonly MARCA_FIM_DART="// ---8<--- DECISAO FIM"

# ---8<--- DECISAO INICIO
manifesto="$raiz/test/suites_obrigatorias.txt"
contrato="$raiz/test/contrato_alvos_amigos.txt"
guarda="$raiz/test/ci/suites_obrigatorias_test.dart"
alvos="$raiz/test/amigos/a11y_alvos_amigos_test.dart"
# A testemunha externa vive UM NIVEL ACIMA da raiz do app, como o proprio
# workflow: no CI a raiz e `app_build` e o repositorio e o pai dela.
testemunha="$raiz/../scripts/ci/testemunha_amigos.js"

falhas=0
erro() {
  echo "SUITE OBRIGATORIA: $*"
  falhas=1
}

# A impressao digital das linhas ENTRE dois marcadores, com CR fora.
#
# Tirar o CR nao e zelo: o repositorio e editado no Windows, onde o checkout
# grava CRLF, e a mesma regiao daria duas impressoes diferentes conforme a
# maquina. A guarda Dart normaliza igual.
digest_regiao() { # digest_regiao <arquivo> <marca_inicio> <marca_fim>
  tr -d '\r' < "$1" | awk -v ini="$2" -v fim="$3" '
    index($0, ini) { dentro = 1; next }
    index($0, fim) { dentro = 0 }
    dentro { print }
  ' | sha256sum | awk '{ print $1 }'
}

# O valor de uma chave do contrato — primeira coluna a chave, segunda o valor.
valor_do_contrato() { # valor_do_contrato <chave>
  tr -d '\r' < "$contrato" |
    awk -v k="$1" '$1 == k { print $2; achou = 1; exit } END { if (!achou) print "" }'
}

if [ ! -f "$manifesto" ]; then
  echo "SUITE OBRIGATORIA: manifesto ausente em '$manifesto'"
  exit 1
fi

conteudo_workflow=""
if [ -n "$workflow" ]; then
  if [ ! -f "$workflow" ]; then
    echo "SUITE OBRIGATORIA: workflow ausente em '$workflow'"
    exit 1
  fi
  conteudo_workflow="$(tr -d '\r' < "$workflow")"
fi

# ---------------------------------------------------------------------------
# 1 — O manifesto e as suites que ele lista
# ---------------------------------------------------------------------------
entradas=0
tem_chave_minima=0

while IFS= read -r bruta || [ -n "$bruta" ]; do
  linha="$(printf '%s' "$bruta" | tr -d '\r')"
  case "$linha" in
    '' | '#'*) continue ;;
  esac

  chave="$(printf '%s\n' "$linha" | awk '{print $1}')"
  caminho="$(printf '%s\n' "$linha" | awk '{print $2}')"
  sobra="$(printf '%s\n' "$linha" | awk '{print $3}')"

  if [ -z "$chave" ] || [ -z "$caminho" ] || [ -n "$sobra" ]; then
    erro "linha malformada no manifesto: '$linha'"
    continue
  fi

  entradas=$((entradas + 1))
  [ "$chave" = "$CHAVE_MINIMA" ] && tem_chave_minima=1

  if [ -f "$raiz/$caminho" ]; then
    echo "ok   arquivo    $chave  $raiz/$caminho"
  else
    erro "suite removida ou renomeada: '$raiz/$caminho' (gate $chave)"
  fi

  [ -z "$conteudo_workflow" ] && continue

  if printf '%s\n' "$conteudo_workflow" |
    grep -Eq "^[[:space:]]*roda[[:space:]]+$chave[[:space:]]+$caminho[[:space:]]*$"; then
    echo "ok   roda       $chave  $caminho"
  else
    erro "o workflow nao tem a linha 'roda $chave $caminho'"
  fi

  if printf '%s\n' "$conteudo_workflow" | grep -E '^[[:space:]]*GATES="' |
    grep -qw -- "$chave"; then
    echo "ok   evidencia  $chave"
  else
    erro "a chave '$chave' esta fora da lista GATES da evidencia"
  fi

  if printf '%s\n' "$conteudo_workflow" | grep -E '^[[:space:]]*for k in ' |
    grep -qw -- "$chave"; then
    echo "ok   portao     $chave"
  else
    erro "a chave '$chave' esta fora da lista do portao"
  fi
done < "$manifesto"

if [ "$entradas" -eq 0 ]; then
  erro "manifesto sem nenhuma entrada — a lista foi esvaziada"
fi

if [ "$tem_chave_minima" -eq 0 ]; then
  erro "o manifesto nao lista mais o gate '$CHAVE_MINIMA'"
fi

# ---------------------------------------------------------------------------
# 2 — O contrato externo dos alvos
# ---------------------------------------------------------------------------
if [ ! -f "$contrato" ]; then
  erro "contrato ausente em '$contrato' — o piso e os casos voltaram a morar so dentro da suite"
else
  c_piso="$(valor_do_contrato piso)"
  c_casos="$(valor_do_contrato casos)"
  c_decl="$(valor_do_contrato declaracoes)"
  c_comp="$(valor_do_contrato comparacoes)"
  c_digest="$(valor_do_contrato digest)"
  c_suite="$(valor_do_contrato suite)"

  [ "$c_piso" = "$PISO_CARIMBADO" ] ||
    erro "o piso do contrato e '$c_piso' e o carimbado e '$PISO_CARIMBADO'"
  [ "$c_casos" = "$CASOS_CARIMBADOS" ] ||
    erro "o contrato declara '$c_casos' casos e o carimbado e $CASOS_CARIMBADOS"
  [ "$c_decl" = "$DECLARACOES_CARIMBADAS" ] ||
    erro "o contrato declara '$c_decl' declaracoes e o carimbado e $DECLARACOES_CARIMBADAS"
  [ "$c_comp" = "$COMPARACOES_CARIMBADAS" ] ||
    erro "o contrato declara '$c_comp' comparacoes com o piso e o carimbado e $COMPARACOES_CARIMBADAS"
  [ "$c_digest" = "$DIGEST_CARIMBADO" ] ||
    erro "a impressao dos casos foi recarimbada so no contrato ('$c_digest')"
  [ "$c_suite" = "test/amigos/a11y_alvos_amigos_test.dart" ] ||
    erro "o contrato aponta para outra suite: '$c_suite'"

  # As identidades: numeradas, em ordem, sem buraco e sem repetida.
  listadas="$(tr -d '\r' < "$contrato" | awk '$1 == "caso" { print $2 }')"
  quantas="$(printf '%s' "$listadas" | grep -c '[0-9]' || true)"
  if [ "$quantas" != "$CASOS_CARIMBADOS" ]; then
    erro "o contrato tem $quantas linhas 'caso' para $CASOS_CARIMBADOS casos"
  elif [ "$listadas" != "$(seq -f '%02g' 1 "$CASOS_CARIMBADOS")" ]; then
    erro "as linhas 'caso' do contrato estao fora de ordem, repetidas ou com buraco"
  fi

  nomes="$(tr -d '\r' < "$contrato" |
    sed -n 's/^caso[[:space:]][0-9][0-9][[:space:]]//p')"
  unicos="$(printf '%s\n' "$nomes" | sort -u | wc -l)"
  todos="$(printf '%s\n' "$nomes" | wc -l)"
  [ "$unicos" = "$todos" ] ||
    erro "o contrato repete identidade de caso ($todos linhas, $unicos distintas)"
fi

# ---------------------------------------------------------------------------
# 3 — A suite de alvos concorda com o contrato
# ---------------------------------------------------------------------------
if [ ! -f "$alvos" ]; then
  erro "a suite de alvos sumiu de '$alvos'"
else
  if tr -d '\r' < "$alvos" |
    grep -Eq "^const double _piso = $PISO_CARIMBADO;\$"; then
    echo "ok   piso       $PISO_CARIMBADO declarado na suite"
  else
    erro "a suite nao declara mais 'const double _piso = $PISO_CARIMBADO;'"
  fi

  declaradas="$(tr -d '\r' < "$alvos" | grep -c 'testWidgets(' || true)"
  [ "$declaradas" = "$DECLARACOES_CARIMBADAS" ] ||
    erro "a suite tem $declaradas sitios 'testWidgets(' e o carimbado e $DECLARACOES_CARIMBADAS"

  comparacoes="$(tr -d '\r' < "$alvos" | grep -c 'greaterThanOrEqualTo(_piso)' || true)"
  [ "$comparacoes" = "$COMPARACOES_CARIMBADAS" ] ||
    erro "a suite compara area com o piso $comparacoes vezes e o carimbado e $COMPARACOES_CARIMBADAS"
fi

# ---------------------------------------------------------------------------
# 4 — A guarda Dart continua com corpo
# ---------------------------------------------------------------------------
if [ ! -f "$guarda" ]; then
  erro "a guarda Dart sumiu de '$guarda'"
else
  d_guarda="$(digest_regiao "$guarda" "$MARCA_INICIO_DART" "$MARCA_FIM_DART")"
  if [ "$d_guarda" = "$DIGEST_DECISAO_GUARDA" ]; then
    echo "ok   guarda     regiao de decisao intacta"
  else
    erro "a regiao de decisao da guarda Dart mudou (agora $d_guarda)"
  fi
fi

# ---------------------------------------------------------------------------
# 5 — A TESTEMUNHA EXTERNA continua no disco, e continua registrada
# ---------------------------------------------------------------------------
#
# Este bloco existe por um motivo so: nenhuma guarda cobre a propria remocao.
# A testemunha le arquivos INTEIROS e EXECUTA os comandos oficiais — e é
# exatamente por isso que apaga-la seria o ataque barato: some o unico
# conferente que sabe se alguma suite rodou, e a cadeia de digests continua
# batendo, porque ela nunca foi medida por ninguem.
#
# Quem cobre a remocao DESTE bloco e a guarda Dart, que carimba a regiao de
# decisao deste arquivo. Os dois juntos so caem num diff que apaga os dois.
if [ ! -f "$testemunha" ]; then
  erro "a testemunha externa sumiu de '$testemunha' — sem ela ninguem confere se as suites RODARAM"
else
  d_testemunha="$(tr -d '\r' < "$testemunha" | sha256sum | awk '{ print $1 }')"
  if [ "$d_testemunha" = "$DIGEST_TESTEMUNHA" ]; then
    echo "ok   testemunha $testemunha"
  else
    erro "a testemunha externa foi alterada (agora $d_testemunha). Forjar relatorio dentro dela — trocar o comando oficial por um \`cat\` de evidencia pronta, adiantar o marcador, fixar o desafio num literal — cai aqui."
  fi
fi

if [ -n "$conteudo_workflow" ]; then
  if printf '%s\n' "$conteudo_workflow" | grep -q -- "testemunha_amigos.js"; then
    echo "ok   invocada   $CHAVE_TESTEMUNHA"
  else
    erro "o workflow nao invoca mais a testemunha externa"
  fi

  if printf '%s\n' "$conteudo_workflow" | grep -E '^[[:space:]]*GATES="' |
    grep -qw -- "$CHAVE_TESTEMUNHA"; then
    echo "ok   evidencia  $CHAVE_TESTEMUNHA"
  else
    erro "a chave '$CHAVE_TESTEMUNHA' esta fora da lista GATES da evidencia"
  fi

  if printf '%s\n' "$conteudo_workflow" | grep -E '^[[:space:]]*for k in ' |
    grep -qw -- "$CHAVE_TESTEMUNHA"; then
    echo "ok   portao     $CHAVE_TESTEMUNHA"
  else
    erro "a chave '$CHAVE_TESTEMUNHA' esta fora da lista do portao"
  fi
fi

if [ "$falhas" -eq 0 ]; then
  echo "suites obrigatorias: $entradas conferida(s), contrato conferido, tudo no lugar"
else
  echo "suites obrigatorias: REPROVADO"
fi

exit "$falhas"
# ---8<--- DECISAO FIM
