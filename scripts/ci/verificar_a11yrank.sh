#!/usr/bin/env bash
#
# CONTRATO EXTERNO DO GATE A11Y DO RANKING — `a11yrank` e `a11yguard`.
#
#   uso: verificar_a11yrank.sh <raiz> [workflow] [dir_resultados]
#
#     raiz            raiz do repositorio (`.` num checkout normal)
#     workflow        opcional. Sem ele, as conferencias de fiacao nao rodam.
#                     No CI ele e SEMPRE dado.
#     dir_resultados  opcional. Com ele roda tambem a FASE B (o log e o
#                     marcador da execucao real).
#
# ---------------------------------------------------------------------------
# POR QUE ESTE ARQUIVO EXISTE
# ---------------------------------------------------------------------------
#
# A OS 19-R1 mediu seis falsos verdes, e cinco deles tinham a mesma raiz: a
# unica autoridade sobre o gate era o PROPRIO WORKFLOW. Quem edita o workflow
# edita, no mesmo gesto, a regra e o juiz.
#
#   S4  tirar `a11yguard` da lista obrigatoria -> a guarda podia falhar e o
#       portao nao olhava o resultado dela
#   S5  baixar `MINIMO=35` -> a suite podia encolher a vontade
#   S6  tirar `roda a11yrank` e forjar um log com `+35` -> gate sem execucao
#   S9  trocar `exit $fail` por `exit 0` -> o portao inteiro parava de decidir
#   S17 apagar o `fail=1` da ausencia de marcador, preservando a mensagem ->
#       o texto continuava dizendo "AUSENTE" e o job passava
#
# O sexto era de codigo, e nao de fiacao: S13, restaurar `width: 44` fixo na
# coluna de colocacao. Quem fecha aquele e o grupo A5 da suite; quem impede a
# A5 de ser esvaziada e este arquivo.
#
# A CORRECAO E DE LUGAR, NAO DE TEXTO. O caminho canonico, o piso, os nomes das
# provas e a assinatura do conteudo passam a morar FORA do YAML, num arquivo
# versionado que o workflow apenas INVOCA — e cuja propria invocacao esta entre
# as coisas que ele confere. Guarda que nao sobrevive a propria remocao nao e
# guarda.
#
# ---------------------------------------------------------------------------
# ATE ONDE ELE ALCANCA
# ---------------------------------------------------------------------------
#
# O piso vive em DOIS lugares de proposito: aqui e no passo da guarda. Baixar
# um dos dois reprova. Baixar os dois exige editar dois arquivos no mesmo
# commit — que e uma decisao visivel no diff, e nao um numero que escorrega.
# Este e o limite declarado desta folha: ela nao tem uma terceira camada.
#
# Ele tambem NAO cobre a remocao do passo que o invoca de dentro de um
# workflow que ninguem roda. O que ele faz e nao deixar isso ser silencioso: a
# invocacao esta escrita aqui, conferida contra o YAML, e some junto com a
# mensagem que a denuncia.

set -u

raiz="${1:-.}"
workflow="${2:-}"
resultados="${3:-}"

# ---------------------------------------------------------------------------
# O CONTRATO
# ---------------------------------------------------------------------------

# Caminho CANONICO da suite, no repositorio.
readonly SUITE='app/test/ranking/a11y_ranking_cabecalho_escala_test.dart'

# Onde a mesma suite tem de chegar no overlay que o CI monta.
readonly SUITE_OVERLAY='app_build/test/ranking/a11y_ranking_cabecalho_escala_test.dart'

# Assinatura do conteudo, com TODO CR removido.
#
# O indice do git guarda LF, a arvore de trabalho no Windows tem CRLF e o
# runner do Actions ve LF. Assinar os bytes crus valeria numa plataforma e
# mentiria na outra.
readonly SHA_SUITE='b78f2dbb9d557136494f0d0f89883a22b239546121356bb985fdedee1dd57da6'

# Piso de casos EXECUTADOS. Nao e contagem de `testWidgets(` no fonte: o grupo
# A4 declara 4 casos que o laco expande em 12, e o grupo A5 declara 2 que o
# laco expande em 15. Contar declaracao mediria a coisa errada.
readonly PISO_CASOS=55

# Piso de DECLARACOES no fonte. Existe para que apagar um bloco inteiro
# reprove ja na fase estatica, antes de qualquer execucao.
readonly PISO_DECLARACOES=34

# A matriz geometrica, e ela e a lista da OS.
readonly LARGURAS='320 360 412'
readonly ESCALAS='100 150 175 200'

# A linha do executor, como o workflow tem de escreve-la. O caminho e do
# ARQUIVO: um passo que rodasse o diretorio `test/ranking` satisfaria "a suite
# rodou" sem que ninguem soubesse qual arquivo produziu o placar.
readonly EXECUTOR='roda a11yrank   test/ranking/a11y_ranking_cabecalho_escala_test.dart'

# A invocacao DESTE arquivo, no YAML.
readonly INVOCACAO='bash scripts/ci/verificar_a11yrank.sh'

# Literais que tem de continuar no CODIGO da suite. A busca IGNORA linha de
# comentario: repetir os literais num comentario e a forja mais barata que
# existe contra busca textual, e uma suite esvaziada com os comentarios
# intactos satisfaria o contrato sem provar nada.
exigidos() {
  cat <<'LITERAIS'
group('A5 — geometria da coluna de colocação'
const double kPisoDaColocacao = 44;
for (final larguraDp in const [320.0, 360.0, 412.0])
for (final escala in const [1.0, 1.5, 1.75, 2.0])
testWidgets('A5 $rotulo — a coluna da colocação reserva largura '
testWidgets('A5p ${larguraDp.toInt()}dp — a largura reservada cresce '
final esperada = kPisoDaColocacao * escala;
closeTo(esperada, 0.5)
await rolarAte(tester, find.text('#123')),
inicioDoNome(tester, nomeLongo),
greaterThan(anterior),
closeTo(escalas[i], 0.02),
alturaPorEscala[escala]! / escala,
List<ColunaDeColocacao> colunasDe(WidgetTester tester, String texto)
Future<bool> rolarAte(WidgetTester tester, Finder alvo)
group('A1 — estrutura por cabeçalhos'
group('A4 — escala de texto'
group('RANKING-01 — nenhuma maquete no caminho'
for (final escala in const [1.0, 1.5, 2.0])
group('A6 — o contrato externo continua sendo autoridade'
final verificador = File('../scripts/ci/verificar_a11yrank.sh');
LITERAIS
}

# ---------------------------------------------------------------------------

falhas=0
erro() {
  printf 'A11YRANK: %s\n' "$1"
  falhas=$((falhas + 1))
}
ok() { printf 'ok   %-12s %s\n' "$1" "$2"; }

arquivo="$raiz/$SUITE"

# ---------------------------------------------------------------------------
# FASE A — o contrato, conferido sem executar nada
# ---------------------------------------------------------------------------

corpo=''
if [ ! -f "$arquivo" ]; then
  erro "suite AUSENTE ou RENOMEADA: '$SUITE' nao existe"
else
  ok arquivo "$SUITE"

  sha_real="$(tr -d '\r' < "$arquivo" | sha256sum | awk '{print $1}')"
  if ! printf %s "$SHA_SUITE" | grep -Eq "^[0-9a-f]{64}$"; then
    erro "SHA_SUITE nao e um digest de 64 hex: '$SHA_SUITE'"
  elif [ "$sha_real" != "$SHA_SUITE" ]; then
    erro "o conteudo de '$SUITE' mudou e a assinatura nao."
    erro "  esperado $SHA_SUITE"
    erro "  no disco $sha_real"
    erro "  se a mudanca e legitima, atualize SHA_SUITE NO MESMO commit"
  else
    ok assinatura "${sha_real:0:16}..."
  fi

  # O overlay que o CI monta tem de receber a MESMA suite. Um arquivo-isca no
  # overlay rodaria no lugar do canonico sem que nada aqui mudasse.
  if [ -d "$raiz/app_build" ]; then
    if [ ! -f "$raiz/$SUITE_OVERLAY" ]; then
      erro "a suite nao chegou ao overlay: '$SUITE_OVERLAY'"
    else
      sha_overlay="$(tr -d '\r' < "$raiz/$SUITE_OVERLAY" | sha256sum | awk '{print $1}')"
      if [ "$sha_overlay" != "$sha_real" ]; then
        erro "o overlay tem OUTRA suite: $sha_overlay"
      else
        ok overlay "$SUITE_OVERLAY"
      fi
    fi
  fi

  # O corpo SEM COMENTARIO, lido uma vez so.
  corpo="$(tr -d '\r\000' < "$arquivo" | grep -avE '^[[:blank:]]*//')"

  # `skip` desliga o caso mantendo o titulo — o placar cai e o nome fica.
  if printf '%s' "$corpo" | grep -qE '\bskip[[:blank:]]*:'; then
    erro "a suite tem 'skip:' — caso desligado com o titulo preservado"
  else
    ok semskip 'nenhum caso desligado'
  fi

  faltando=0
  while IFS= read -r padrao; do
    [ -z "$padrao" ] && continue
    case "$corpo" in
      *"$padrao"*) ;;
      *)
        erro "o bloco protegido sumiu de '$SUITE': $padrao"
        faltando=$((faltando + 1))
        ;;
    esac
  done <<CONTRATO
$(exigidos)
CONTRATO
  [ "$faltando" -eq 0 ] && ok blocos "$(exigidos | grep -c .) conferido(s)"

  declaracoes="$(printf '%s' "$corpo" | grep -cE '^[[:blank:]]*(test|testWidgets)\(')"
  if [ "$declaracoes" -lt "$PISO_DECLARACOES" ]; then
    erro "a suite tem $declaracoes declaracoes e o piso e $PISO_DECLARACOES"
  else
    ok declaracoes "$declaracoes >= $PISO_DECLARACOES"
  fi

  # UNICIDADE dos titulos declarados. Dois casos com o mesmo nome fazem o
  # placar somar e a evidencia mentir sobre o que foi provado.
  duplicados="$(printf '%s' "$corpo" \
    | grep -oE "^[[:blank:]]*(test|testWidgets)\('[^']+'" \
    | sed -E "s/^[[:blank:]]*(test|testWidgets)\('//" \
    | sort | uniq -d)"
  if [ -n "$duplicados" ]; then
    erro "titulos declarados em duplicata: $duplicados"
  else
    ok unicidade 'nenhum titulo declarado em duplicata'
  fi
fi

# ORIGEM UNICA. As provas geometricas nao podem existir em outro arquivo: um
# arquivo-isca com os nomes certos satisfaria qualquer busca por nome e o
# executor continuaria apontando para o canonico — ou, pior, deixaria de
# apontar.
if [ -d "$raiz/app/test" ]; then
  intrusos="$(grep -rl "geometria da coluna de colocação" "$raiz/app/test" 2>/dev/null \
    | grep -v "a11y_ranking_cabecalho_escala_test.dart" || true)"
  if [ -n "$intrusos" ]; then
    erro "as provas geometricas aparecem fora do arquivo canonico: $intrusos"
  else
    ok origem 'as provas geometricas so existem no arquivo canonico'
  fi
fi

# ---------------------------------------------------------------------------
# FIACAO — o workflow
# ---------------------------------------------------------------------------

if [ -n "$workflow" ]; then
  if [ ! -f "$workflow" ]; then
    erro "workflow ausente em '$workflow'"
  else
    # AS LINHAS DE COMENTARIO SAEM ANTES DE QUALQUER BUSCA.
    #
    # A campanha desta OS pegou o defeito: o comentario do passo 2c EXPLICA a
    # sabotagem S9 citando `exit $fail`, e a conferencia do veredito casava com
    # a explicacao em vez de casar com o codigo — trocar `exit $fail` por
    # `exit 0` passava batido. Prova de ausencia que le comentario prova o
    # contrario do que diz.
    yml="$(tr -d '\r' < "$workflow" | grep -vE '^[[:blank:]]*#')"
    espremido="$(printf '%s\n' "$yml" | tr -s '[:blank:]' ' ' | sed -e 's/^ //' -e 's/ $//')"

    conferir_yml() { # conferir_yml <rotulo> <literal> <mensagem>
      if printf '%s' "$espremido" | grep -qF "$(printf '%s' "$2" | tr -s '[:blank:]' ' ')"; then
        ok "$1" "$2"
      else
        erro "$3"
      fi
    }

    conferir_yml executor "$EXECUTOR" \
      "o workflow nao roda a suite pelo caminho canonico: '$EXECUTOR'"
    conferir_yml invocacao "$INVOCACAO" \
      "o workflow deixou de invocar este verificador: '$INVOCACAO'"
    conferir_yml alvoguarda "ALVO=\"$SUITE\"" \
      "o passo da guarda perdeu o caminho canonico"
    conferir_yml pisoguarda "MINIMO=$PISO_CASOS" \
      "o piso do passo da guarda nao e $PISO_CASOS — piso rebaixado de um lado"
    conferir_yml marcador 'echo $st > exit_a11yguard' \
      "o passo da guarda deixou de gravar 'exit_a11yguard'"
    conferir_yml decisaoausencia 'echo "gate a11yguard = AUSENTE' \
      "a mensagem de ausencia da guarda sumiu"

    # A DECISAO, e nao a mensagem. A S17 preservou o texto e apagou o `fail=1`
    # de dentro do ramo; a S9 trocou `exit $fail` por `exit 0`.
    if printf '%s' "$yml" | grep -A3 'gate a11yguard = AUSENTE' | grep -q 'fail=1'; then
      ok decisao 'a ausencia da guarda ainda reprova'
    else
      erro "a ausencia de 'exit_a11yguard' deixou de reprovar (mensagem sem decisao)"
    fi
    if printf '%s' "$espremido" | grep -qF 'exit $fail'; then
      ok veredito 'o portao ainda deriva o veredito do exit'
    else
      erro "o portao final nao termina em 'exit \$fail' — decisao neutralizada"
    fi

    # A LISTA OBRIGATORIA. Os dois nomes tem de estar na linha do `for k in`.
    lista="$(printf '%s\n' "$yml" | grep -E '^[[:blank:]]*for k in [a-z]' | head -1)"
    if [ -z "$lista" ]; then
      erro "o portao final perdeu a lista de gates obrigatorios"
    else
      for chave in a11yrank a11yguard; do
        case " $lista " in
          *" $chave "*) ok obrigatorio "$chave na lista do portao" ;;
          *) erro "'$chave' saiu da lista de gates obrigatorios do portao" ;;
        esac
      done
    fi

    # A evidencia publicada tem de citar os dois.
    evid="$(printf '%s\n' "$yml" | grep -E '^[[:blank:]]*GATES=' | head -1)"
    for chave in a11yrank a11yguard; do
      case " $evid " in
        *" $chave "*) ;;
        *) erro "'$chave' saiu da relacao de evidencia publicada" ;;
      esac
    done
  fi
fi

# ---------------------------------------------------------------------------
# FASE B — a execucao real
# ---------------------------------------------------------------------------

if [ -n "$resultados" ]; then
  log="$resultados/t_a11yrank.log"
  carimbo="$resultados/carimbo_execucao"

  for chave in a11yrank a11yguard; do
    marcador="$resultados/exit_$chave"
    if [ ! -f "$marcador" ]; then
      erro "marcador AUSENTE: 'exit_$chave' — gate sem execucao registrada"
    else
      v="$(tr -d ' \r\n' < "$marcador")"
      if [ "$v" != "0" ]; then
        erro "o gate '$chave' terminou em $v"
      else
        ok marcador "exit_$chave = 0"
      fi
    fi
  done

  # MARCADOR NAO BASTA, e LOG TAMBEM NAO. Os dois juntos, e datados.
  if [ ! -s "$log" ]; then
    erro "o gate 'a11yrank' nao deixou log ('$log' ausente ou vazio) — marcador sem execucao"
  else
    if [ ! -f "$carimbo" ]; then
      erro "carimbo de execucao ausente em '$carimbo' — sem ele nao ha como datar a evidencia"
    elif [ "$carimbo" -nt "$log" ]; then
      erro "o log de 'a11yrank' e ANTERIOR ao carimbo deste run: evidencia de outra execucao"
    else
      ok log 'posterior ao carimbo'
    fi

    # O PLACAR REAL. `+N` do reporter expandido, o maior que aparecer.
    maior=0
    for n in $(grep -oE '\+[0-9]+' "$log" | tr -d '+'); do
      [ "$n" -gt "$maior" ] && maior="$n"
    done
    if [ "$maior" -lt "$PISO_CASOS" ]; then
      erro "a suite executou $maior casos e o piso e $PISO_CASOS"
    else
      ok casos "$maior >= $PISO_CASOS"
    fi

    # AS PROVAS GEOMETRICAS, UMA A UMA, PELO NOME. E isto que faz retirar uma
    # largura ou uma escala reprovar NOMINALMENTE, e nao so pela contagem.
    ausentes=0
    for l in $LARGURAS; do
      for e in $ESCALAS; do
        nome="A5 ${l}dp @ ${e}% — a coluna da colocação reserva largura escalável"
        case "$(cat "$log")" in
          *"$nome"*) ;;
          *) erro "a prova geometrica nao foi executada: '$nome'"
             ausentes=$((ausentes + 1)) ;;
        esac
      done
      nome="A5p ${l}dp — a largura reservada cresce estritamente com a escala"
      case "$(cat "$log")" in
        *"$nome"*) ;;
        *) erro "a prova de progressao nao foi executada: '$nome'"
           ausentes=$((ausentes + 1)) ;;
      esac
    done
    [ "$ausentes" -eq 0 ] && ok geometria '15 provas geometricas executadas'

    # UNICIDADE do que EXECUTOU. O placar soma nomes repetidos sem reclamar.
    repetidos="$(grep -oE '^[0-9:]+ \+[0-9]+: .*$' "$log" \
      | sed -E 's/^[0-9:]+ \+[0-9]+(-[0-9]+)?: //' \
      | grep -v '^All tests passed' \
      | sort | uniq -d)"
    if [ -n "$repetidos" ]; then
      erro "casos executados com nome repetido: $repetidos"
    else
      ok unicidadeexec 'nenhum caso executado em duplicata'
    fi
  fi
fi

# ---------------------------------------------------------------------------

if [ "$falhas" -eq 0 ]; then
  printf 'contrato a11yrank: tudo no lugar\n'
  exit 0
fi
printf 'contrato a11yrank: %s problema(s)\n' "$falhas"
exit 1
