# ---------------------------------------------------------------------------
# CODIGO EXECUTAVEL — o analisador lexico do contrato de conteudo.
#
#   uso:  tr -d '\r\000' < <arquivo> |
#         awk -v ling=js|dart|sh|json -v agulhas=<lista> -f codigo_executavel.awk
#
# Le UM arquivo do stdin, classifica CADA caractere como CODIGO ou INERTE, e
# responde, para cada agulha da lista, se ela ocorre ANCORADA EM CODIGO.
#
# ---------------------------------------------------------------------------
# POR QUE ELE EXISTE
# ---------------------------------------------------------------------------
#
# Ate a OS 40-C2 o contrato buscava a agulha sobre o arquivo com as LINHAS de
# comentario removidas por expressao regular. A rehomologacao OS 40-R2 mediu o
# que sobrava: bastava mudar a agulha de lugar. Comentario de BLOCO, comentario
# no fim de uma linha de codigo, string, texto de template, expressao regular e
# `reason:` de mensagem continuavam satisfazendo o contrato — e com a guarda
# funcional trivializada ao lado, a arvore ficava verde.
#
# Remover mais formas de comentario com mais expressao regular nao fecha isso:
# uma varredura sem estado nao sabe se um `//` esta dentro de uma string, nem se
# uma aspa esta dentro de um comentario. O que fecha e ler o arquivo com ESTADO,
# caractere a caractere, que e o que este arquivo faz.
#
# ---------------------------------------------------------------------------
# A REGRA, EM UMA LINHA
# ---------------------------------------------------------------------------
#
#   uma agulha CONTA quando ao menos UM caractere da ocorrencia e CODIGO.
#
# Nao e "a agulha nao pode encostar em string". `test("PF-01:` encosta de
# proposito: `test(` e codigo e `"PF-01:` e o literal do nome do caso. O que a
# regra recusa e a ocorrencia INTEIRAMENTE contida em regiao inerte — que e a
# forma de toda forja: prosa que imita programa.
#
# Consequencia direta, e ela e uma decisao: UMA AGULHA PRECISA DE ANCORA. Uma
# agulha que so existe como conteudo de string — `T01 CONTROLE`, sozinho — passa
# a ser recusada com INERTE, e o contrato tem de cita-la junto da chamada que a
# produz (`esperar 0 "T01 CONTROLE`). E o proprio verificador quem avisa: a
# mensagem distingue "nunca esteve la" de "esta la, mas so como texto".
#
# ---------------------------------------------------------------------------
# O QUE E INERTE, POR LINGUAGEM
# ---------------------------------------------------------------------------
#
#   js/dart   comentario de linha `//` e `///`, comentario de bloco, string
#             simples, dupla, template (js) e tripla (dart), e literal de
#             expressao regular (js). O `r'...'` do dart e string crua.
#   sh        comentario `#` em inicio de palavra, `'...'` (cru, sem escape) e
#             `"..."`.
#   json      NADA e inerte, exceto o par de chave de comentario `"//...": ...`,
#             que e como este repositorio comenta JSON. JSON nao tem codigo: um
#             manifesto e dado do primeiro ao ultimo byte, e exigir "ancora de
#             codigo" nele reprovaria todo `exigealvo` que existe.
#
# INTERPOLACAO E CODIGO, E ISSO E EXPLICITO. Dentro de `${...}` (dart, js e o
# `"..."` do sh, mais o `$(...)` do sh) o que esta escrito EXECUTA, entao volta a
# valer como codigo. O TEXTO LITERAL do template, em volta, continua inerte — e
# a campanha da OS 40-C2 prova as duas metades separadamente. O `$nome` simples
# do dart NAO conta como codigo: e um nome, e nao uma expressao.
#
# DELIMITADOR E INERTE. A aspa que abre a string pertence ao literal. Se ela
# contasse como codigo, uma string qualquer teria ancora e voltaria a satisfazer
# o contrato — que e exatamente o buraco a fechar.
#
# ---------------------------------------------------------------------------
# SAIDA
# ---------------------------------------------------------------------------
#
#   PROVAS    <n>        quantas linhas casam com `CONTA_ERE` (a contagem de
#                        declaracoes de caso; sai sempre, e antes das demais)
#   AUSENTE   <agulha>   nao ocorre em lugar nenhum do arquivo
#   INERTE    <agulha>   ocorre, mas SO em comentario/string/template/regex
#   SEMCODIGO            o arquivo inteiro foi classificado como inerte
#   ABERTO    <estado>   o arquivo terminou dentro de comentario ou de string
#   SEMCASO   <id>       `CASO` foi pedido e o caso NAO e declarado em codigo
#   SEMLINGUA <ling>     linguagem nao reconhecida (o chamador reprova)
#
# SEMCODIGO e ABERTO sao a sentinela: um comentario de bloco sem fechar apagaria
# o arquivo inteiro, e toda busca por ausencia ficaria verde. Aqui ela fica
# VERMELHA, que e o unico jeito de uma guarda textual morrer com barulho.
# ---------------------------------------------------------------------------

BEGIN {
  if (ling != "js" && ling != "dart" && ling != "sh" && ling != "json") {
    print "SEMLINGUA\t" ling
    saiu = 1
    exit 0
  }
  n = 0
  if (agulhas != "") {
    while ((getline uma < agulhas) > 0) {
      sub(/\r$/, "", uma)
      if (uma == "") continue
      n++
      ag[n] = uma
      viu[n] = 0
      codigo[n] = 0
    }
    close(agulhas)
  }
  st = "cod"       # cod | lin | blo | str | rgx
  topo = 0         # pilha de interpolacoes abertas
  q = ""; tri = 0; cru = 0; itp = 0
  classe = 0       # dentro de [...] de uma regex
  prev = ""        # ultimo caractere significativo de codigo
  temcodigo = 0
  jsonpula = 0     # 0 nada | 1 procurando o valor | 2 dentro do valor

  # A CONTAGEM DE DECLARACOES VEM NA MESMA LEITURA, E SOBRE CODIGO. Era uma
  # segunda varredura do mesmo arquivo (`tr | grep -c`), e ela contava a linha
  # CRUA: comentario, string e corpo de heredoc engordavam `provas` de graca. A
  # OS 40-R3 mediu isso — vinte e sete casos apagados e repostos por um heredoc.
  # Agora a linha so conta quando o trecho que casa esta em CODIGO.
  #
  # O padrao chega pelo AMBIENTE porque `-v` interpreta sequencias de escape, e o
  # `\(` do contador padrao viraria abre-parentese de grupo — a contagem passaria
  # a medir outra coisa, em silencio.
  conta = ENVIRON["CONTA_ERE"]
  provas = 0

  # ---------------------------------------------------------------------------
  # ESCOPO POR CASO (OS 40-C3)
  # ---------------------------------------------------------------------------
  #
  # Com `CASO` definido, as agulhas so contam DENTRO do corpo daquele caso. E a
  # unica forma de exigir que o titulo e a afirmacao semantica morem no MESMO
  # caso: sem isso, distribuir os dois entre dois casos-isca satisfaz uma busca
  # plana, por melhor ancorada que ela esteja.
  #
  # O corpo comeca na DECLARACAO — uma chamada de abertura, em codigo, cujo
  # primeiro literal comeca pelo identificador — e termina na declaracao
  # seguinte, qualquer que seja ela. Um identificador que so exista dentro de uma
  # string nunca abre corpo nenhum: quem abre e a CHAMADA, e ela e codigo.
  caso_alvo = ENVIRON["CASO"]
  dentro = (caso_alvo == "") ? 1 : 0
  achou_caso = 0
  esperando_id = 0     # uma chamada de abertura acabou de ser lida
  capturando = 0       # estamos dentro do literal que carrega o identificador
  idbuf = ""
  palavra = ""         # identificador de codigo sendo acumulado
}

# ---------------------------------------------------------------------------

function abrestr(qq, ttri, ccru, iitp) {
  if (esperando_id) { esperando_id = 0; capturando = 1; idbuf = "" }
  q = qq; tri = ttri; cru = ccru; itp = iitp; st = "str"
}

function empilha(abre, fecha) {
  topo++
  pq[topo] = q; ptri[topo] = tri; pcru[topo] = cru; pitp[topo] = itp
  pabre[topo] = abre; pfecha[topo] = fecha; pdep[topo] = 1
  st = "cod"
}

function desempilha() {
  q = pq[topo]; tri = ptri[topo]; cru = pcru[topo]; itp = pitp[topo]
  topo--
  st = "str"
}

function marca(k, tipo,   _i) {
  for (_i = 0; _i < k; _i++) masc = masc tipo
  if (tipo == "C") temcodigo = 1
}

# ---------------------------------------------------------------------------

{
  linha = $0
  len = length(linha)
  masc = ""
  i = 1

  if (st == "lin") st = "cod"     # comentario de linha morre no fim da linha

  if (ling == "json") lexjson()
  else                lexcod()

  # O corpo do heredoc comeca na linha SEGUINTE a que o abriu.
  if (her_pend != "") { st = "her"; her_word = her_pend; her_pend = "" }

  # ---- a contagem de declaracoes, SOBRE CODIGO -------------------------
  #
  # Depois de lexar, e nao antes: o que decide se a linha conta e a mascara. Uma
  # declaracao dentro de comentario, de string ou de corpo de heredoc casa com o
  # padrao e NAO conta, porque o trecho que casou e inerte.
  if (conta != "" && match(linha, conta) > 0) {
    if (index(substr(masc, RSTART, RLENGTH), "C") > 0) provas++
  }

  # ---- as agulhas, sobre ESTA linha ------------------------------------
  #
  # Por LINHA, e nao sobre o arquivo inteiro: nenhum valor da fonte unica
  # carrega quebra de linha, entao toda ocorrencia possivel cabe numa linha so.
  #
  # `dentro` e lido DEPOIS de lexar a linha: assim a propria linha da declaracao
  # do caso alvo ja conta como corpo, e a linha da declaracao SEGUINTE ja nao
  # conta mais. Na duvida, para fora — que e o lado fail-closed.
  if (dentro) {
    for (j = 1; j <= n; j++) {
      tam = length(ag[j])
      de = 1
      while (de <= len) {
        p = index(substr(linha, de), ag[j])
        if (p == 0) break
        pos = de + p - 1
        viu[j] = 1
        if (index(substr(masc, pos, tam), "C") > 0) codigo[j] = 1
        de = pos + 1
      }
    }
  }
}

# ---------------------------------------------------------------------------
# O LEXER DE CODIGO — js, dart e sh
# ---------------------------------------------------------------------------

function lexcod(   c, d, t3, c2, qh, corte) {
  # ---- corpo de heredoc: inerte da abertura ao terminador ----------------
  #
  # O corpo de um heredoc e TEXTO, e a OS 40-R3 mediu o que custa trata-lo como
  # codigo: vinte e sete casos apagados e a contagem de `provas` reposta por um
  # heredoc de trinta linhas que ninguem executa.
  if (st == "her") {
    marca(len, ".")
    corte = linha
    if (her_tab) sub(/^\t+/, "", corte)
    if (corte == her_word) st = "cod"
    i = len + 1
    return
  }

  while (i <= len) {
    c = substr(linha, i, 1)
    d = (i < len) ? substr(linha, i + 1, 1) : ""

    if (st == "lin") { marca(len - i + 1, "."); i = len + 1; continue }

    if (st == "blo") {
      if (c == "*" && d == "/") { marca(2, "."); i += 2; st = "cod"; continue }
      marca(1, "."); i++; continue
    }

    if (st == "rgx") {
      if (c == "\\" && d != "") { marca(2, "."); i += 2; continue }
      if (c == "[") classe = 1
      else if (c == "]") classe = 0
      else if (c == "/" && !classe) { marca(1, "."); i++; st = "cod"; prev = "/"; continue }
      marca(1, "."); i++; continue
    }

    if (st == "str") {
      if (!cru && c == "\\" && d != "") {
        if (capturando) idbuf = idbuf substr(linha, i, 2)
        marca(2, "."); i += 2; continue
      }
      if (itp && c == "$" && d == "{") { marca(2, "."); i += 2; empilha("{", "}"); continue }
      if (itp && ling == "sh" && c == "$" && d == "(") { marca(2, "."); i += 2; empilha("(", ")"); continue }
      if (c == q) {
        if (tri) {
          t3 = substr(linha, i, 3)
          if (t3 == q q q) { marca(3, "."); i += 3; st = "cod"; prev = "q"; fecha_id(); continue }
          if (capturando) idbuf = idbuf c
          marca(1, "."); i++; continue
        }
        marca(1, "."); i++; st = "cod"; prev = "q"; fecha_id(); continue
      }
      if (capturando) idbuf = idbuf c
      marca(1, "."); i++; continue
    }

    # ---- st == "cod" ----------------------------------------------------
    if (topo > 0) {
      if (c == pfecha[topo]) {
        pdep[topo]--
        if (pdep[topo] == 0) { marca(1, "."); i++; desempilha(); continue }
        marca(1, "C"); i++; prev = c; continue
      }
      if (c == pabre[topo]) { pdep[topo]++; marca(1, "C"); i++; prev = c; continue }
    }

    if (ling == "js" || ling == "dart") {
      if (c == "/" && d == "/") { fecha_palavra(""); marca(2, "."); i += 2; st = "lin"; continue }
      if (c == "/" && d == "*") { fecha_palavra(""); marca(2, "."); i += 2; st = "blo"; continue }
      if (ling == "js" && c == "/" && regexpode()) {
        fecha_palavra(""); marca(1, "."); i++; st = "rgx"; classe = 0; continue
      }
      if (ling == "dart" && c == "r" && (d == "'" || d == "\"") && !identchar(prev)) {
        fecha_palavra("")
        marca(1, ".")
        i++
        c = d
        t3 = substr(linha, i, 3)
        if (t3 == c c c) { marca(3, "."); i += 3; abrestr(c, 1, 1, 0); continue }
        marca(1, "."); i++; abrestr(c, 0, 1, 0); continue
      }
      if (c == "'" || c == "\"") {
        fecha_palavra("")
        if (ling == "dart") {
          t3 = substr(linha, i, 3)
          if (t3 == c c c) { marca(3, "."); i += 3; abrestr(c, 1, 0, 1); continue }
        }
        marca(1, "."); i++; abrestr(c, 0, 0, (ling == "dart") ? 1 : 0); continue
      }
      if (ling == "js" && c == "`") { fecha_palavra(""); marca(1, "."); i++; abrestr("`", 0, 0, 1); continue }
    }

    if (ling == "sh") {
      if (c == "#" && inicioDePalavra()) { fecha_palavra(""); marca(len - i + 1, "."); i = len + 1; continue }
      # BARRA INVERTIDA FORA DE STRING escapa o proximo caractere. `echo \<<EOF`
      # nao abre corpo nenhum: o que sobra e `<EOF`, redirecionamento de ENTRADA,
      # e o shell real segue executando a linha seguinte (OS 40-C7).
      if (c == "\\") {
        fecha_palavra("")
        marca(1, "C"); i++
        if (i <= len) { marca(1, "C"); i++ }
        continue
      }
      # ARITMETICA `$((...))`: ali o par e DESLOCAMENTO. Sem este estado,
      # `x=$((1<<2))` abria um heredoc que nunca fecha, o arquivo inteiro virava
      # INERTE e o contrato reprovava a arvore integra (OS 40-C7).
      if (c == "$" && d == "(" && substr(linha, i + 2, 1) == "(") {
        fecha_palavra("")
        marca(3, "C"); i += 3; arit++; prev = "("
        continue
      }
      if (arit > 0 && c == ")" && d == ")") { marca(2, "C"); i += 2; arit--; prev = ")"; continue }
      # `<<WORD`, `<<-WORD`, `<<'WORD'` — e NAO `<<<` (here-string), nem o par do
      # MEIO de um `<<<`, que era lido como abertura ao avancar um caractere, nem
      # `<<` dentro de aritmetica.
      if (arit == 0 && c == "<" && d == "<" && substr(linha, i + 2, 1) != "<" && prev != "<") {
        fecha_palavra("")
        marca(2, "."); i += 2
        her_tab = 0
        if (substr(linha, i, 1) == "-") { her_tab = 1; marca(1, "."); i++ }
        qh = substr(linha, i, 1)
        if (qh == "'" || qh == "\"") { marca(1, "."); i++ } else qh = ""
        her_pend = ""
        while (i <= len) {
          c2 = substr(linha, i, 1)
          if (qh != "" && c2 == qh) { marca(1, "."); i++; break }
          if (qh == "" && !identchar(c2)) break
          her_pend = her_pend c2
          marca(1, "."); i++
        }
        continue
      }
      if (c == "$" && d == "'") { fecha_palavra(""); marca(2, "."); i += 2; abrestr("'", 0, 0, 0); continue }
      if (c == "'") { fecha_palavra(""); marca(1, "."); i++; abrestr("'", 0, 1, 0); continue }
      if (c == "\"") { fecha_palavra(""); marca(1, "."); i++; abrestr("\"", 0, 0, 1); continue }
      if (c == "`") { fecha_palavra(""); marca(1, "."); i++; abrestr("`", 0, 0, 1); continue }
    }

    marca(1, "C")
    if (identchar(c)) palavra = palavra c
    else fecha_palavra(c)
    if (c != " " && c != "\t") prev = c
    i++
  }
}

# `fecha_palavra <proximo>` — o identificador de codigo acabou. Se ele e uma
# CHAMADA DE ABERTURA de caso, o proximo literal carrega o identificador.
#
# Para js/dart a abertura so vale colada no parentese (`test(`); para sh a
# chamada e um comando e os argumentos vem depois (`esperar 0 "T27 ..."`), entao
# a espera atravessa as palavras seguintes ate o primeiro literal.
function fecha_palavra(prox) {
  if (palavra != "") {
    if (esperando_bare) {
      esperando_bare = 0
      id_de(palavra)
    } else if (ehAbertura(palavra)) {
      # `caso_ativo T58` — o identificador e a PALAVRA seguinte, e nao um
      # literal. Em `sh` o embrulho do caso vem ANTES da chamada que o mede, e
      # e ele quem delimita o corpo: a sabotagem de um caso mora entre o
      # embrulho e o `esperar`, nao depois dele.
      if (ling == "sh" && palavra == "caso_ativo") esperando_bare = 1
      else if (ling == "sh" || prox == "(") esperando_id = 1
    }
  }
  palavra = ""
}

function ehAbertura(p) {
  if (ling == "js" || ling == "dart") return (p == "test" || p == "testWidgets")
  if (ling == "sh") return (p == "caso_ativo" || p == "esperar" || p == "esperar_igual" || p == "ok" || p == "nok")
  return 0
}

# `id_de <identificador>` — abre ou fecha corpo. Um identificador igual ao alvo
# abre; qualquer outro fecha. Reabrir com o mesmo identificador e inofensivo, e
# acontece de proposito: o embrulho abre e a chamada medida confirma.
function id_de(id) {
  sub(/[ \t:,].*$/, "", id)
  if (id == "") return
  if (caso_alvo == "") return
  if (id == caso_alvo) { dentro = 1; achou_caso = 1 }
  else                 { dentro = 0 }
}

function fecha_id() {
  if (!capturando) return
  capturando = 0
  id_de(idbuf)
}

# `/` abre expressao regular, e nao divisao, quando o ultimo caractere
# significativo NAO pode terminar um operando. Regra determinista e conservadora:
# na duvida, REGEX — porque tratar regex como codigo e o que deixa a agulha
# passar, e tratar divisao como regex so torna a guarda mais exigente.
function regexpode() {
  if (prev == "") return 1
  if (identchar(prev)) return 0
  if (prev == ")" || prev == "]" || prev == "q") return 0
  return 1
}

function identchar(c) {
  return (c ~ /^[A-Za-z0-9_$]$/)
}

function inicioDePalavra(   a) {
  if (i == 1) return 1
  a = substr(linha, i - 1, 1)
  return (a == " " || a == "\t" || a == ";" || a == "&" || a == "|" || a == "(")
}

# ---------------------------------------------------------------------------
# O LEXER DE JSON — so o par de chave de comentario e inerte
# ---------------------------------------------------------------------------

function lexjson(   c, d) {
  while (i <= len) {
    c = substr(linha, i, 1)
    d = (i < len) ? substr(linha, i + 1, 1) : ""

    if (st == "str") {
      if (c == "\\" && d != "") { marca(2, jsontipo()); jsontexto = jsontexto substr(linha, i, 2); i += 2; continue }
      if (c == "\"") {
        marca(1, jsontipo()); i++; st = "cod"
        if (jsonpula == 2) jsonpula = 0
        else if (jsonpula == 0 && substr(jsontexto, 1, 2) == "//") { jsonpula = 1; apagaChave() }
        continue
      }
      marca(1, jsontipo()); jsontexto = jsontexto c; i++; continue
    }

    if (c == "\"") {
      chaveini = i
      jsontexto = ""
      marca(1, jsontipo()); i++; st = "str"; continue
    }
    if (jsonpula == 1 && c == ":") { marca(1, "."); i++; jsonpula = 2; continue }
    if (jsonpula > 0 && (c == " " || c == "\t")) { marca(1, "."); i++; continue }
    if (jsonpula == 2) {
      marca(1, ".")
      i++
      if (c == "," || c == "}" || c == "]") jsonpula = 0
      continue
    }
    marca(1, "C"); i++
  }
}

function jsontipo() {
  return (jsonpula == 0) ? "C" : "."
}

# A chave de comentario ja foi marcada como codigo quando foi lida: so ao fechar
# a aspa se descobre que ela era prosa. Reescreve o trecho dela na mascara.
function apagaChave(   novo) {
  novo = substr(masc, 1, chaveini - 1)
  while (length(novo) < i - 1) novo = novo "."
  masc = novo substr(masc, i)
}

# ---------------------------------------------------------------------------

END {
  if (saiu) exit 0
  print "PROVAS\t" provas
  if (st == "blo") print "ABERTO\tcomentario de bloco"
  else if (st == "str") print "ABERTO\tstring"
  else if (st == "her") print "ABERTO\tcorpo de heredoc"
  if (caso_alvo != "" && !achou_caso) print "SEMCASO\t" caso_alvo
  if (!temcodigo) print "SEMCODIGO"
  for (j = 1; j <= n; j++) {
    if (codigo[j]) continue
    if (viu[j]) print "INERTE\t" ag[j]
    else print "AUSENTE\t" ag[j]
  }
}
