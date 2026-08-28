// autoridade_a11yterm.js — a autoridade EXTERNA e FAIL-CLOSED da cadeia
// `a11yterm`. OS 20-C2.
//
// ---------------------------------------------------------------------------
// POR QUE ELA EXISTE, SE JA HAVIA CONTRATO E TESTEMUNHA
// ---------------------------------------------------------------------------
//
// A OS 20-C1 pos as afirmacoes sobre os workflows DENTRO da suite Dart, e as
// protegeu com `if (!arquivo.existsSync()) return;`. A intencao era nao afirmar
// besteira quando a raiz do repositorio nao esta alcancavel. O efeito foi
// outro: apagar, mover ou renomear um workflow virou CONFORMIDADE. O GitHub
// continua executando `.github/workflows/apk.yml` depois de `build.yml` ser
// renomeado; o contrato, nao — ele para de fiscalizar e fica verde.
//
// Ausencia nao pode ser silencio. Esta autoridade e o caminho executavel que
// permanece alcancavel quando um workflow some, e ela trata como VERMELHO:
//
//   * arquivo canonico ausente, ilegivel, vazio ou nao classificavel;
//   * portador alternativo, renomeado, duplicado ou oculto da cadeia;
//   * invocacao obrigatoria sem portador canonico UNICO;
//   * invocacao que existe como TEXTO mas nao como COMANDO VIVO;
//   * decisao que nao chega ao codigo de saida do passo;
//   * um workflow que deixou de cobrar a integridade do outro.
//
// ---------------------------------------------------------------------------
// A SEGUNDA NATUREZA
// ---------------------------------------------------------------------------
//
// A suite protegida nao pode aprovar a si mesma: nem seus nomes, nem sua
// cardinalidade, nem seus pisos, nem a MATERIA dos seus corpos. Por isso a
// obrigacao de cada um dos vinte e um casos homologados mora num MANIFESTO de
// dados — `.github/gates/a11yterm.manifesto.json` —, e quem a cobra e este
// programa, que nao e Dart, nao roda no executor do Flutter e nao depende da
// suite para nada.
//
// A OBRIGACAO NAO E UM DIGEST. Um digest e recalculavel: quem edita o corpo
// recarimba o numero e segue verde. A obrigacao daqui e nominal e material —
// "o caso X exercita `_atravessarOTeto`, le `getSemantics` e afirma sobre
// `isButton`" —, e nenhum `expect(1, 1)` a satisfaz. Para satisfaze-la sem
// escrever o teste seria preciso APAGAR a obrigacao do manifesto; e o
// manifesto e fixado, em numero e em conteudo, pela fonte unica de gates em
// Dart, que por sua vez tem seus literais fixados aqui. Nenhuma das duas
// pontas se edita sozinha.
//
// Uso:
//   node .github/scripts/autoridade_a11yterm.js [raizDoRepositorio]
//
// Sai 0 se tudo bate; 1 com os motivos impressos, em qualquer outro caso.

'use strict';

/// A contrabarra, escrita sem contrabarra: este arquivo atravessa camadas
/// que reprocessam escapes, e um literal partido aqui vira erro de sintaxe.
const BARRA = String.fromCharCode(92);

const fs = require('fs');
const path = require('path');

const RAIZ = path.resolve(process.argv[2] || '.');
const CAMINHO_MANIFESTO = '.github/gates/a11yterm.manifesto.json';
const DIR_WORKFLOWS = '.github/workflows';

const erros = [];
const reprova = (m) => erros.push(m);

const abs = (p) => path.join(RAIZ, p);

/// O conteudo normalizado em LF, ou `null` se o arquivo NAO EXISTE.
///
/// Qualquer outro erro de leitura e reprovacao com o codigo real: um arquivo
/// ilegivel nao e um arquivo conforme, e confundi-lo com ausencia esconderia a
/// diferenca entre "sumiu" e "nao consigo ler".
function ler(p) {
  try {
    return fs.readFileSync(abs(p), 'utf8').replace(/\r\n/g, '\n');
  } catch (e) {
    if (e.code === 'ENOENT') return null;
    reprova(`nao consegui ler ${p}: ${e.code}`);
    return null;
  }
}

// ===========================================================================
// 1. O MANIFESTO — fail-closed em todas as formas de sumir
// ===========================================================================

const bruto = ler(CAMINHO_MANIFESTO);
if (bruto === null) {
  reprova(
    `${CAMINHO_MANIFESTO} nao existe. Ele e a autoridade externa da cadeia ` +
      `a11yterm: sem ele nao ha o que conferir, e "nada a conferir" nao e ` +
      `aprovacao.`,
  );
}
if (bruto !== null && !bruto.trim()) {
  reprova(`${CAMINHO_MANIFESTO} esta vazio — manifesto vazio nao e manifesto`);
}

let M = null;
if (bruto && bruto.trim()) {
  try {
    M = JSON.parse(bruto);
  } catch (e) {
    reprova(`${CAMINHO_MANIFESTO} nao e JSON valido: ${e.message}`);
  }
}

/// Um manifesto ao qual falta qualquer chave estrutural e um manifesto
/// NAO CLASSIFICAVEL, e isso reprova. Reduzir o manifesto a `{}` nao pode
/// deixar esta autoridade sem trabalho.
const CHAVES = [
  'versao',
  'caminhoCanonicoDaSuite',
  'fonteUnicaDeGates',
  'testemunha',
  'autoridadeExige',
  'autoridade',
  'marcasDaCadeia',
  'workflowsCanonicos',
  'invocacoes',
  'invocacoesCompartilhadas',
  'pisos',
  'casosProtegidos',
  'literaisFixadosNaFonteDeGates',
];
if (M) {
  for (const k of CHAVES) {
    if (!(k in M)) reprova(`o manifesto perdeu a chave obrigatoria "${k}"`);
  }
}
if (!M) {
  // Sem manifesto nao ha como continuar: qualquer conferencia adiante leria
  // `undefined` e passaria por "nada errado encontrado".
  for (const e of erros) console.log(`AUTORIDADE a11yterm REPROVOU: ${e}`);
  process.exit(1);
}

// ===========================================================================
// 2. LER YAML COMO SHELL — comando VIVO, e nao presenca textual
// ===========================================================================
//
// Um `grep` no YAML nao distingue o comando que roda do nome dele escrito num
// comentario, numa string de `echo`, num heredoc de documentacao ou num ramo
// que nunca e alcancado. Distinguir e o trabalho desta secao.

/// Os blocos escalares de `run:` do workflow, com a linha em que comecam.
///
/// O YAML nao e interpretado: o que interessa e o TEXTO de shell que o passo
/// executa, e ele e o bloco indentado que segue `run: |`.
function blocosRun(texto) {
  const linhas = texto.split('\n');
  const saida = [];
  for (let i = 0; i < linhas.length; i++) {
    const m = /^(\s*)run:\s*\|[-+]?\s*$/.exec(linhas[i]);
    if (!m) continue;
    const recuo = m[1].length;
    const corpo = [];
    let j = i + 1;
    for (; j < linhas.length; j++) {
      const l = linhas[j];
      if (l.trim() === '') {
        corpo.push('');
        continue;
      }
      const r = /^(\s*)/.exec(l)[1].length;
      if (r <= recuo) break;
      corpo.push(l);
    }
    saida.push({ linha: i + 1, corpo: corpo.join('\n') });
    i = j - 1;
  }
  return saida;
}

/// Substitui um trecho por espacos, preservando as quebras de linha.
///
/// Apagar mudaria os deslocamentos e faria a contagem de linhas mentir; o
/// branco mantem a geometria do arquivo e some com o conteudo.
const branquear = (s) => s.replace(/[^\n]/g, ' ');

/// O shell sem comentarios `#`, respeitando aspas.
function semComentarios(sh) {
  let fora = '';
  let aspa = null;
  for (let i = 0; i < sh.length; i++) {
    const c = sh[i];
    if (aspa) {
      fora += c;
      if (c === BARRA && aspa === '"') {
        fora += sh[i + 1] === undefined ? '' : sh[i + 1];
        i++;
        continue;
      }
      if (c === aspa) aspa = null;
      continue;
    }
    if (c === "'" || c === '"') {
      aspa = c;
      fora += c;
      continue;
    }
    if (c === '#') {
      // `#` so abre comentario no comeco de uma palavra.
      const ant = i > 0 ? sh[i - 1] : '\n';
      if (ant === '\n' || ant === ' ' || ant === '\t' || ant === ';') {
        let j = i;
        while (j < sh.length && sh[j] !== '\n') j++;
        fora += branquear(sh.slice(i, j));
        i = j - 1;
        continue;
      }
    }
    fora += c;
  }
  return fora;
}

/// O shell sem os CORPOS de heredoc.
///
/// O delimitador e o corpo somem; a linha do `<<` fica. Um comando escrito
/// dentro de `<<'EOF' ... EOF` e dado de entrada para outro programa, e nao
/// executado — plantar `roda_obrigatorio a11yterm ...` ali e presenca textual,
/// nao invocacao.
function semHeredocs(sh) {
  const linhas = sh.split('\n');
  const saida = [];
  let fim = null;
  for (const l of linhas) {
    if (fim !== null) {
      saida.push(branquear(l));
      if (l.trim() === fim) fim = null;
      continue;
    }
    const m = /<<-?\s*(['"]?)([A-Za-z_][A-Za-z0-9_]*)\1/.exec(l);
    saida.push(l);
    if (m) fim = m[2];
  }
  return saida.join('\n');
}

/// O shell com os ramos comprovadamente INALCANCAVEIS branqueados.
///
/// Nao e analise de fluxo: e o reconhecimento das condicoes constantemente
/// falsas com que se aposenta um comando sem apaga-lo. `if false; then CMD;
/// fi` mantem o texto e nao roda nada.
function semRamosMortos(sh) {
  const linhas = sh.split('\n');
  const morta = /^\s*(if|elif)\s+(false|\[\s*(0|1)\s*(-eq|=)\s*(1|0)\s*\]|\[\s*"?0"?\s*=\s*"?1"?\s*\]|test\s+0\s+-eq\s+1)\s*;?\s*(then)?\s*$/;
  const saida = [];
  let dentro = false;
  let nivel = 0;
  for (const l of linhas) {
    if (dentro) {
      if (/^\s*if\b/.test(l)) nivel++;
      if (/^\s*(fi|else|elif)\b/.test(l) && nivel === 0) {
        dentro = false;
        saida.push(l);
        continue;
      }
      if (/^\s*fi\b/.test(l)) nivel--;
      saida.push(branquear(l));
      continue;
    }
    if (morta.test(l)) {
      dentro = true;
      nivel = 0;
      saida.push(branquear(l));
      continue;
    }
    saida.push(l);
  }
  return saida.join('\n');
}

/// Para cada caractere do shell, se ele esta DENTRO de um literal de string.
///
/// Serve a uma pergunta so: o comando COMECA dentro de aspas? `echo
/// "roda_obrigatorio a11yterm ..."` imprime o comando e nao o executa — o
/// texto comeca dentro da string. Ja `echo "$v" > exit_a11ytermat` grava o
/// marcador de verdade: ele comeca FORA, e so carrega uma string no meio.
/// Perguntar se o trecho inteiro sobrevive ao branqueamento confundiria os
/// dois casos, e reprovaria o segundo.
function mascaraDeString(sh) {
  const m = new Array(sh.length).fill(false);
  let aspa = null;
  for (let i = 0; i < sh.length; i++) {
    const c = sh[i];
    if (aspa) {
      m[i] = true;
      if (c === BARRA && aspa === '"') {
        if (i + 1 < sh.length) m[i + 1] = true;
        i++;
        continue;
      }
      if (c === aspa) aspa = null;
      continue;
    }
    if (c === "'" || c === '"') {
      aspa = c;
      m[i] = true;
      continue;
    }
  }
  return m;
}

/// O texto de shell que o passo REALMENTE executa.
function vivo(sh) {
  return semRamosMortos(semHeredocs(semComentarios(sh)));
}

/// As linhas vivas de um workflow inteiro, ja unidas.
function shellVivoDe(texto) {
  return blocosRun(texto)
    .map((b) => vivo(b.corpo))
    .join('\n');
}

/// A linha de comando esta VIVA e nao foi neutralizada?
///
/// Devolve `null` se estiver tudo bem, ou o motivo da recusa.
function neutralizada(linha) {
  const l = linha.trim();
  // `echo ... > arquivo` GRAVA — e como o marcador nasce. O que nao vale e
  // imprimir o comando na tela e chamar isso de execucao.
  if (/^(echo|printf|:)\s/.test(l) && !/>/.test(l)) {
    return 'virou impressao, nao comando';
  }
  if (/\|\|\s*(true|:)\s*$/.test(l)) return 'terminada em `|| true`';
  if (/\|\|\s*(echo|printf)\b/.test(l)) return 'terminada em `|| echo`';
  if (/\|\s*(true|cat\s*>\s*\/dev\/null)\s*$/.test(l)) {
    return 'canalizada para um neutralizador';
  }
  if (/&\s*$/.test(l) && !/&&\s*$/.test(l)) return 'jogada para segundo plano';
  if (/>\s*\/dev\/null\s+2>&1\s*$/.test(l) && /^\s*node\b/.test(l)) {
    return 'com a saida inteira descartada';
  }
  return null;
}

/// Onde a invocacao aparece VIVA, dentro dos blocos `run:` do workflow.
///
/// A busca e feita sobre o shell vivo E fora de string. As duas coisas: o
/// primeiro filtro derruba comentario, heredoc e ramo morto; o segundo derruba
/// o comando escrito como argumento de outro comando.
function ocorrenciasVivas(texto, comando) {
  const achadas = [];
  for (const b of blocosRun(texto)) {
    const v = vivo(b.corpo);
    const mascara = mascaraDeString(v);
    let de = v.indexOf(comando);
    while (de >= 0) {
      const linha = b.linha + v.slice(0, de).split('\n').length - 1;
      const inicioDaLinha = v.lastIndexOf('\n', de) + 1;
      let fimDaLinha = v.indexOf('\n', de);
      if (fimDaLinha < 0) fimDaLinha = v.length;
      const emString = mascara[de];
      achadas.push({
        linha,
        texto: v.slice(inicioDaLinha, fimDaLinha),
        emString,
        motivo: emString
          ? 'escrita dentro de string'
          : neutralizada(v.slice(inicioDaLinha, fimDaLinha)),
      });
      de = v.indexOf(comando, de + 1);
    }
  }
  return achadas;
}

// ===========================================================================
// 3. INVENTARIO DOS WORKFLOWS — existencia, unicidade e portador alternativo
// ===========================================================================
//
// O provedor executa TODO arquivo `.yml`/`.yaml` que estiver direto em
// `.github/workflows/`, com o nome que for. Renomear `build.yml` para
// `apk.yml` nao desliga nada la; desliga aqui, se a fiscalizacao olhar so para
// o nome antigo. Por isso o inventario e feito nos dois sentidos: o que TEM de
// existir, e o que existe e nao devia carregar esta cadeia.

const dirWf = abs(DIR_WORKFLOWS);
let presentes = [];
try {
  presentes = fs
    .readdirSync(dirWf, { withFileTypes: true })
    .filter((d) => d.isFile())
    .map((d) => d.name)
    .filter((n) => /\.(yml|yaml)$/i.test(n))
    .map((n) => `${DIR_WORKFLOWS}/${n}`)
    .sort();
} catch (e) {
  reprova(
    `nao consegui inventariar ${DIR_WORKFLOWS}: ${e.code}. Sem inventario ` +
      `nao ha como saber quem carrega a cadeia a11yterm.`,
  );
}

if (!presentes.length) {
  reprova(
    `${DIR_WORKFLOWS} nao tem nenhum workflow. Um inventario vazio nao ` +
      `aprova coisa nenhuma: ele prova que a fiscalizacao inteira sumiu.`,
  );
}

const canonicos = (M.workflowsCanonicos || []).map((w) => w.caminho);
const textoDe = new Map();

for (const w of M.workflowsCanonicos || []) {
  const t = ler(w.caminho);
  if (t === null) {
    reprova(
      `${w.caminho} (${w.papel}) NAO EXISTE. Apagar, mover ou renomear sao a ` +
        `mesma coisa daqui, e nenhuma delas e conformidade: o provedor ` +
        `continua rodando o arquivo renomeado, e a fiscalizacao para.`,
    );
    continue;
  }
  if (!t.trim()) {
    reprova(`${w.caminho} esta vazio — workflow vazio nao executa portao algum`);
    continue;
  }
  // Nao classificavel: um arquivo que nao declara passos nao e o workflow que
  // o manifesto nomeia, ainda que tenha o nome dele.
  if (!/^\s*(jobs|on)\s*:/m.test(t) || !blocosRun(t).length) {
    reprova(
      `${w.caminho} nao e classificavel como workflow: nao tem \`jobs:\`/\`on:\`` +
        ` ou nao tem um unico bloco \`run:\`. Esvaziar o arquivo e o mesmo que ` +
        `apaga-lo, com a vantagem de o caminho continuar existindo.`,
    );
    continue;
  }
  textoDe.set(w.caminho, t);
}

// -- portador alternativo, renomeado, duplicado ou oculto ------------------
//
// Qualquer workflow FORA da lista canonica que carregue uma marca da cadeia e
// um portador alternativo. Ele e vermelho tanto quando nasceu de um `mv` do
// canonico quanto quando e uma copia plantada ao lado dele: nos dois casos a
// cadeia passa a ter dois donos, e um deles nao esta sob contrato.

const permitidos = new Set([
  ...canonicos,
  ...(M.workflowsPermitidosSemCadeia || []),
]);

for (const p of presentes) {
  if (canonicos.includes(p)) continue;
  const t = ler(p);
  if (t === null || !t.trim()) continue;
  const vivoTexto = shellVivoDe(t);
  const marcas = (M.marcasDaCadeia || []).filter(
    (m) => vivoTexto.includes(m) || t.includes(m),
  );
  if (marcas.length) {
    reprova(
      `${p} carrega marcas da cadeia a11yterm (${marcas.join(', ')}) e NAO e ` +
        `um portador canonico. Renomear o workflow, duplicar o conteudo dele ` +
        `ou plantar as invocacoes num arquivo alternativo mantem o provedor ` +
        `executando e tira a cadeia do contrato.`,
    );
  }
  if (!permitidos.has(p)) {
    // Nao e erro por si so — o repositorio pode ganhar workflows. O que se
    // registra e que ele foi inventariado e nao carrega a cadeia.
    console.log(`autoridade a11yterm: ${p} inventariado, sem marcas da cadeia`);
  }
}

// -- extensao trocada -------------------------------------------------------
//
// `build.yaml` ao lado de um `build.yml` ausente e a renomeacao mais barata de
// todas: o provedor executa igual, e um contrato que so conhece `.yml` fica
// cego. O inventario acima ja pega o arquivo pela marca; esta conferencia diz
// o nome do ataque.
for (const c of canonicos) {
  const base = c.replace(/\.(yml|yaml)$/i, '');
  for (const alt of [`${base}.yaml`, `${base}.yml`]) {
    if (alt === c) continue;
    if (presentes.includes(alt)) {
      reprova(
        `${alt} existe ao lado do caminho canonico ${c}. Trocar a extensao ` +
          `nao desliga o workflow no provedor; desliga so a fiscalizacao.`,
      );
    }
  }
}

// -- as invocacoes obrigatorias, com portador canonico UNICO ---------------

for (const inv of M.invocacoes || []) {
  const donos = [];
  for (const p of presentes) {
    const t = p === inv.portador ? textoDe.get(p) : ler(p);
    if (!t) continue;
    const oc = ocorrenciasVivas(t, inv.comando);
    const boas = oc.filter((o) => !o.motivo);
    if (boas.length) donos.push({ arquivo: p, quantas: boas.length });
  }

  const t = textoDe.get(inv.portador);
  if (!t) {
    // O portador ja foi reprovado por ausencia/ilegibilidade acima. Sem texto
    // nao ha como conferir a invocacao, e a falta dela nao pode passar calada.
    reprova(
      `a invocacao "${inv.id}" nao pode ser conferida: o portador ` +
        `${inv.portador} nao esta legivel`,
    );
    continue;
  }

  const oc = ocorrenciasVivas(t, inv.comando);
  const vivas = oc.filter((o) => !o.motivo);

  if (!oc.length) {
    reprova(
      `${inv.portador} nao tem a invocacao obrigatoria "${inv.id}": ` +
        `\`${inv.comando}\``,
    );
  } else if (!vivas.length) {
    reprova(
      `${inv.portador} tem "${inv.id}" como TEXTO, e nao como comando vivo: ` +
        oc.map((o) => `linha ${o.linha} ${o.motivo}`).join('; '),
    );
  }

  const emOutros = donos.filter((d) => d.arquivo !== inv.portador);
  if (emOutros.length) {
    reprova(
      `a invocacao "${inv.id}" tem portador DUPLICADO: alem de ` +
        `${inv.portador}, aparece viva em ` +
        emOutros.map((d) => d.arquivo).join(', '),
    );
  }
  const total = donos.reduce((s, d) => s + d.quantas, 0);
  if (total > 1) {
    reprova(
      `a invocacao "${inv.id}" aparece viva ${total} vezes. Portador canonico ` +
        `UNICO quer dizer uma, e nao "pelo menos uma": duas chamadas permitem ` +
        `neutralizar a que decide e deixar a que enfeita.`,
    );
  }
}

// -- invocacoes COMPARTILHADAS pelos dois portadores canonicos -------------
//
// A testemunha e a autoridade sao chamadas de proposito nos DOIS workflows: e
// exatamente isso que faz cada portao reprovar o sumico do outro. Para elas,
// "portador unico" seria a exigencia errada. A certa e: viva em CADA canonico,
// uma vez so em cada um, e em nenhum arquivo fora da lista canonica.

for (const inv of M.invocacoesCompartilhadas || []) {
  for (const c of canonicos) {
    const t = textoDe.get(c);
    if (!t) {
      reprova(
        'a invocacao compartilhada "' +
          inv.id +
          '" nao pode ser conferida em ' +
          c +
          ': o portador nao esta legivel',
      );
      continue;
    }
    const oc = ocorrenciasVivas(t, inv.comando);
    const vivas = oc.filter((o) => !o.motivo);
    if (!oc.length) {
      reprova(
        c + ' nao tem a invocacao obrigatoria "' + inv.id + '": ' + inv.comando,
      );
    } else if (!vivas.length) {
      reprova(
        c +
          ' tem "' +
          inv.id +
          '" como TEXTO, e nao como comando vivo: ' +
          oc.map((o) => 'linha ' + o.linha + ' ' + o.motivo).join('; '),
      );
    } else if (vivas.length > 1) {
      reprova(
        c +
          ' chama "' +
          inv.id +
          '" ' +
          vivas.length +
          ' vezes. Duas chamadas permitem neutralizar a que decide e deixar a ' +
          'que enfeita.',
      );
    }
  }
  for (const p of presentes) {
    if (canonicos.includes(p)) continue;
    const t = ler(p);
    if (!t) continue;
    if (ocorrenciasVivas(t, inv.comando).some((o) => !o.motivo)) {
      reprova(
        p +
          ' e um portador NAO CANONICO da invocacao "' +
          inv.id +
          '" — plantar a chamada num workflow alternativo da a cadeia um dono ' +
          'fora do contrato',
      );
    }
  }
}

// ===========================================================================
// 4. O CONSUMO DO EXIT — a decisao tem de chegar ao codigo de saida do passo
// ===========================================================================
//
// Tres listas de gate e uma tabela vermelha no log nao valem nada se o passo
// terminar em `exit 0`. Cada portador declara no manifesto as marcas
// estruturais que provam que a decisao dele e aplicada, e elas sao procuradas
// no SHELL VIVO — nao no arquivo, onde um comentario as reporia de graca.

for (const w of M.workflowsCanonicos || []) {
  const t = textoDe.get(w.caminho);
  if (!t) continue;
  const vv = shellVivoDe(t);
  for (const c of w.consumoDoExit || []) {
    if (!new RegExp(c.regex, c.flags || '').test(vv)) {
      reprova(
        `${w.caminho}: a prova de consumo do exit "${c.id}" nao esta mais no ` +
          `shell vivo do passo. ${c.porque}`,
      );
    }
  }
  for (const c of w.proibidoNoVivo || []) {
    if (new RegExp(c.regex, c.flags || '').test(vv)) {
      reprova(`${w.caminho}: ${c.porque} (padrao "${c.id}" apareceu vivo)`);
    }
  }
}

// ===========================================================================
// 5. O CRUZAMENTO — cada portao reprova a ausencia ou o desvio do outro
// ===========================================================================
//
// Este e o ponto do §5.9 da OS: apagar `build.yml` tem de ficar vermelho por
// um caminho que AINDA EXECUTA, e o unico que ainda executa e o outro
// workflow. Como os dois chamam ESTA autoridade, e ela confere os dois
// arquivos, o gate alcancavel por qualquer um deles reprova o sumico do
// companheiro. O que se confere aqui e que a chamada existe viva nos dois.

for (const cr of M.cruzamento || []) {
  const t = textoDe.get(cr.portador);
  if (!t) {
    reprova(
      `o cruzamento "${cr.portador} fiscaliza ${cr.exigeIntegridadeDe}" nao ` +
        `pode ser conferido: o portador nao esta legivel`,
    );
    continue;
  }
  const oc = ocorrenciasVivas(t, cr.comando);
  const vivas = oc.filter((o) => !o.motivo);
  if (!vivas.length) {
    reprova(
      `${cr.portador} deixou de chamar a autoridade externa viva. Sem ela, ` +
        `apagar ou desviar ${cr.exigeIntegridadeDe} deixa de ter caminho ` +
        `executavel que reprove` +
        (oc.length ? ` (a chamada aparece, mas ${oc[0].motivo})` : ''),
    );
  }
}

// ===========================================================================
// 6. OS PISOS, FIXADOS EM TRES NATUREZAS
// ===========================================================================
//
// Os numeros homologados vivem aqui como LITERAIS, no manifesto como dados e
// na fonte unica de gates como literais Dart. Baixar um piso exige editar as
// tres, e as tres se cobram: e isso que impede o "recarimbo coordenado" de
// uma peca so. Um piso derivado — lido do tamanho da propria lista — encolhe
// junto com ela e aprova qualquer remocao; por isso nenhum destes e derivado.

const PISOS_HOMOLOGADOS = {
  a11yterm: 49,
  relacaoNominalOriginal: 21,
  casosDaCorrecao: 10,
  casosPorNome: 31,
  casosDaMatriz: 2,
  combinacoesDaMatriz: 9,
  testemunha: 21,
};

for (const [k, v] of Object.entries(PISOS_HOMOLOGADOS)) {
  const doManifesto = M.pisos ? M.pisos[k] : undefined;
  if (doManifesto !== v) {
    reprova(
      `o piso "${k}" vale ${v} nesta autoridade e ${doManifesto} no ` +
        `manifesto. Divergiram: nenhum dos dois e autoridade enquanto isso ` +
        `durar, e baixar o piso numa peca so e exatamente o ataque.`,
    );
  }
}

// ===========================================================================
// 7. A FONTE UNICA DE GATES — os literais que nao podem encolher
// ===========================================================================

const fonte = ler(M.fonteUnicaDeGates);
if (fonte === null) {
  reprova(
    `${M.fonteUnicaDeGates} nao existe. Ela e a fonte unica de gates: sem ` +
      `ela nao ha contrato nominal, e a ausencia dele nao e aprovacao.`,
  );
}

/// O Dart sem comentarios, respeitando aspas.
function semComentariosDart(fonteTexto) {
  let saida = '';
  let i = 0;
  let aspa = null;
  while (i < fonteTexto.length) {
    const c = fonteTexto[i];
    const prox = i + 1 < fonteTexto.length ? fonteTexto[i + 1] : '';
    if (aspa) {
      saida += c;
      if (c === BARRA) {
        saida += prox;
        i += 2;
        continue;
      }
      if (c === aspa) aspa = null;
      i++;
      continue;
    }
    if (c === '/' && prox === '/') {
      while (i < fonteTexto.length && fonteTexto[i] !== '\n') i++;
      continue;
    }
    if (c === '/' && prox === '*') {
      i += 2;
      while (
        i < fonteTexto.length &&
        !(fonteTexto[i] === '*' && fonteTexto[i + 1] === '/')
      ) {
        i++;
      }
      i += 2;
      continue;
    }
    if (c === "'" || c === '"') {
      aspa = c;
      saida += c;
      i++;
      continue;
    }
    saida += c;
    i++;
  }
  return saida;
}

const fonteCodigo = fonte === null ? '' : semComentariosDart(fonte);

if (fonte !== null) {
  for (const lit of M.literaisFixadosNaFonteDeGates || []) {
    if (!fonteCodigo.includes(lit.texto)) {
      reprova(
        `${M.fonteUnicaDeGates} perdeu o literal "${lit.texto}" — ${lit.porque}`,
      );
    }
  }
}

// ===========================================================================
// 8. A SUITE PROTEGIDA — a MATERIA de cada um dos vinte e um casos
// ===========================================================================
//
// POR QUE OBRIGACAO NOMINAL, E NAO DIGEST.
//
// A OS 20-R2 trocou os vinte e um corpos por `expect(1, 1)` e recarimbou a
// assinatura: os dois portoes seguiram verdes. Um digest e recalculavel por
// quem edita, e por isso nao protege materia nenhuma — ele so registra que
// alguem editou.
//
// O que esta secao cobra e outra coisa: cada caso tem uma obrigacao PROPRIA,
// escrita em termos das operacoes que ele exercita e dos resultados que ele
// observa. `expect(1, 1)` nao contem `_atravessarOTeto`, nao chama
// `getSemantics`, nao afirma sobre `isButton` e nao encontra
// `SplashOficialScreen`. Para satisfazer a obrigacao sem escrever o teste
// seria preciso APAGAR a obrigacao — e o numero e a identidade delas estao
// fixados aqui, no manifesto e na fonte de gates ao mesmo tempo.
//
// Nao entram como criterio: tamanho do corpo, contagem de caracteres,
// `contains('expect(')` solto, quantidade de `expect`, digest, titulo do
// teste, presenca de string ou comentario explicativo.

/// Um literal de string simples em [i], se houver.
function literalEm(s, i) {
  while (i < s.length && (s[i] === ' ' || s[i] === '\n' || s[i] === '\r')) i++;
  if (i >= s.length) return null;
  const aspa = s[i];
  if (aspa !== "'" && aspa !== '"') return null;
  let texto = '';
  i++;
  while (i < s.length) {
    const c = s[i];
    if (c === BARRA) {
      texto += s[i + 1] === undefined ? '' : s[i + 1];
      i += 2;
      continue;
    }
    if (c === aspa) return { texto, fim: i + 1 };
    texto += c;
    i++;
  }
  return null;
}

/// Do `{` em [i] ate a chave que o fecha, pulando strings.
function fimDoBloco(s, i) {
  let nivel = 0;
  let aspa = null;
  while (i < s.length) {
    const c = s[i];
    if (aspa) {
      if (c === BARRA) {
        i += 2;
        continue;
      }
      if (c === aspa) aspa = null;
      i++;
      continue;
    }
    if (c === "'" || c === '"') {
      aspa = c;
      i++;
      continue;
    }
    if (c === '{') nivel++;
    if (c === '}') {
      nivel--;
      if (nivel === 0) return i;
    }
    i++;
  }
  return s.length;
}

/// Os casos declarados, com o nome completo montado pelos grupos que os contem.
///
/// Mesma leitura que a fonte de gates faz em Dart, refeita aqui de proposito:
/// duas naturezas independentes que concordam valem mais do que uma que se
/// confirma sozinha.
function casosDeclarados(codigo) {
  const saida = [];
  const grupos = [];
  const decl = /\b(group|testWidgets|test)\s*\(/g;
  let m;
  while ((m = decl.exec(codigo)) !== null) {
    while (grupos.length && grupos[grupos.length - 1].fim < m.index) {
      grupos.pop();
    }
    const lido = literalEm(codigo, decl.lastIndex);
    if (!lido) continue;
    let j = lido.fim;
    while (j < codigo.length && codigo[j] !== '{') {
      if (codigo[j] === ';') break;
      j++;
    }
    if (j >= codigo.length || codigo[j] !== '{') continue;
    const fim = fimDoBloco(codigo, j);
    if (m[1] === 'group') {
      grupos.push({ nome: lido.texto, fim });
      continue;
    }
    const prefixo = grupos.map((g) => g.nome).join(' ');
    saida.push({
      nome: prefixo ? prefixo + ' ' + lido.texto : lido.texto,
      grupo: prefixo,
      literal: !lido.texto.includes('$'),
      corpo: codigo.slice(j + 1, fim),
    });
  }
  return saida;
}

/// O corpo da DECLARACAO do auxiliar privado [nome], se ela existir.
function corpoDoAuxiliar(codigo, nome) {
  const re = new RegExp('\\b' + nome + '\\s*\\(', 'g');
  let o;
  while ((o = re.exec(codigo)) !== null) {
    let j = re.lastIndex;
    let nivel = 1;
    while (j < codigo.length && nivel > 0) {
      if (codigo[j] === '(') nivel++;
      if (codigo[j] === ')') nivel--;
      j++;
    }
    while (j < codigo.length && codigo[j] !== '{' && codigo[j] !== ';') j++;
    if (j < codigo.length && codigo[j] === '{') {
      return codigo.slice(j + 1, fimDoBloco(codigo, j));
    }
  }
  return null;
}

/// O corpo mais o dos auxiliares privados que ele chama — UM nivel.
///
/// Fundo o bastante para nao confundir delegacao com esvaziamento (os seis
/// casos de escala delegam de proposito), e raso o bastante para nao virar um
/// interpretador de Dart.
function corpoNoAlcance(corpo, codigo) {
  let b = corpo;
  const chamada = /\b(_[A-Za-z0-9_]+)\s*\(/g;
  const vistos = new Set();
  let m;
  while ((m = chamada.exec(corpo)) !== null) {
    if (vistos.has(m[1])) continue;
    vistos.add(m[1]);
    const aux = corpoDoAuxiliar(codigo, m[1]);
    if (aux !== null) b += aux;
  }
  return b;
}

const caminhoSuite = 'app/' + M.caminhoCanonicoDaSuite;
const suiteBruta = ler(caminhoSuite);
if (suiteBruta === null) {
  reprova(
    caminhoSuite +
      ' nao existe. Apagar, mover ou renomear a suite protegida sao a mesma ' +
      'coisa daqui, e nenhuma delas e conformidade.',
  );
}

if (suiteBruta !== null) {
  const codigo = semComentariosDart(suiteBruta);
  const casos = casosDeclarados(codigo);
  const porNome = new Map(casos.map((c) => [c.nome, c]));
  const protegidos = M.casosProtegidos || [];

  // -- cardinalidade, contra literais e nao contra as proprias listas -------
  if (protegidos.length !== PISOS_HOMOLOGADOS.relacaoNominalOriginal) {
    reprova(
      'o manifesto declara ' +
        protegidos.length +
        ' casos protegidos, e a relacao homologada sao ' +
        PISOS_HOMOLOGADOS.relacaoNominalOriginal +
        '. Reduzir a relacao E o ataque, nao a correcao dele.',
    );
  }

  const escritos = casos.filter((c) => c.literal).length;
  const daMatriz = casos.filter((c) => !c.literal).length;
  if (escritos < PISOS_HOMOLOGADOS.casosPorNome) {
    reprova(
      caminhoSuite +
        ' tem ' +
        escritos +
        ' casos escritos por nome, e o piso e ' +
        PISOS_HOMOLOGADOS.casosPorNome,
    );
  }
  if (daMatriz !== PISOS_HOMOLOGADOS.casosDaMatriz) {
    reprova(
      'os casos gerados pela matriz sao ' +
        PISOS_HOMOLOGADOS.casosDaMatriz +
        ', e vieram ' +
        daMatriz,
    );
  }
  const total = escritos + daMatriz * PISOS_HOMOLOGADOS.combinacoesDaMatriz;
  if (total < PISOS_HOMOLOGADOS.a11yterm) {
    reprova(
      caminhoSuite +
        ' declara ' +
        total +
        ' casos executaveis, e o piso e ' +
        PISOS_HOMOLOGADOS.a11yterm,
    );
  }

  const nomes = casos.map((c) => c.nome);
  if (new Set(nomes).size !== nomes.length) {
    reprova(
      'ha nome repetido em ' +
        caminhoSuite +
        ': duplicar repoe contagem sem repor prova',
    );
  }
  if (/\bskip\s*:/.test(codigo)) {
    reprova(
      caminhoSuite + ' ganhou um `skip` — caso desligado nao prova nada',
    );
  }
  if (/\bsolo\s*:\s*true/.test(codigo)) {
    reprova(caminhoSuite + ' ganhou `solo: true` — ele cala todos os outros');
  }

  // -- a obrigacao material, caso a caso -----------------------------------
  for (const p of protegidos) {
    const c = porNome.get(p.nome);
    if (!c) {
      reprova(
        'o caso protegido no ' +
          p.ordem +
          ' "' +
          p.nome +
          '" nao e mais declarado em ' +
          caminhoSuite,
      );
      continue;
    }
    if (!c.literal) {
      reprova(
        'o caso "' +
          p.nome +
          '" deixou de ter nome literal — nome montado em execucao esconde a ' +
          'remocao do caso',
      );
    }
    if (c.grupo !== p.grupo) {
      reprova(
        'o caso "' +
          p.caso +
          '" mudou de grupo: o contrato diz "' +
          p.grupo +
          '" e a suite diz "' +
          c.grupo +
          '". Mover um caso de grupo troca o que ele exercita sem tocar no ' +
          'nome dele.',
      );
    }
    const alcance = corpoNoAlcance(c.corpo, codigo);
    const faltando = (p.exige || []).filter((tok) => !alcance.includes(tok));
    if (faltando.length) {
      reprova(
        'o caso "' +
          p.nome +
          '" perdeu a materia que o define. Faltam, no corpo dele ou no ' +
          'auxiliar que ele chama: ' +
          faltando.join(' , ') +
          '. ' +
          p.porque,
      );
    }
    // Constante nao e afirmacao. Um corpo em que todo `expect` compara
    // literais consigo mesmos passa em qualquer contagem e nao observa nada.
    const afirmacoes = (alcance.match(/expect\s*\(/g) || []).length;
    const minimo = p.afirmacoesMinimas || 1;
    if (afirmacoes < minimo) {
      reprova(
        'o caso "' +
          p.nome +
          '" tem ' +
          afirmacoes +
          ' afirmacoes, e o contrato dele pede ' +
          minimo,
      );
    }
    for (const proibido of M.afirmacoesConstantes || []) {
      if (alcance.includes(proibido)) {
        reprova(
          'o caso "' +
            p.nome +
            '" contem a afirmacao constante `' +
            proibido +
            '`, que e verdadeira sem observar coisa alguma',
        );
      }
    }
  }

  // -- os nomes protegidos vivem SO no caminho canonico --------------------
  const iscas = [];
  const varrer = (dir) => {
    let itens = [];
    try {
      itens = fs.readdirSync(abs(dir), { withFileTypes: true });
    } catch {
      return;
    }
    for (const it of itens) {
      const p = dir + '/' + it.name;
      if (it.isDirectory()) {
        varrer(p);
      } else if (it.name.endsWith('_test.dart') && p !== caminhoSuite) {
        const t = ler(p);
        if (t === null) continue;
        const outros = new Set(
          casosDeclarados(semComentariosDart(t)).map((c) => c.nome),
        );
        for (const pr of protegidos) {
          if (outros.has(pr.nome)) iscas.push(p + ': "' + pr.nome + '"');
        }
      }
    }
  };
  varrer('app/test');
  if (iscas.length) {
    reprova(
      'casos protegidos declarados FORA do caminho canonico — o portao ' +
        'executaria um arquivo e a prova estaria em outro: ' +
        iscas.join(' | '),
    );
  }
}

// ===========================================================================
// 9. A TESTEMUNHA — ela existe, le a fonte unica e nao carrega piso proprio
// ===========================================================================

const eu = ler(M.autoridade);
if (eu === null) {
  reprova(
    M.autoridade +
      ' nao existe no caminho que o manifesto declara — a autoridade esta ' +
      'rodando de outro lugar',
  );
} else {
  for (const marca of M.autoridadeExige || []) {
    if (!eu.includes(marca.texto)) {
      reprova(
        M.autoridade +
          ' perdeu "' +
          marca.texto +
          '" — ' +
          marca.porque +
          '. Esvaziar a autoridade e o ataque que ela nao pega sozinha: quem ' +
          'confere esta mesma lista, de fora, e a fonte unica de gates.',
      );
    }
  }
}

const testemunha = ler(M.testemunha);
if (testemunha === null) {
  reprova(
    M.testemunha +
      ' nao existe. Sem ela os dois portoes voltam a acreditar no proprio ' +
      'codigo de saida.',
  );
} else {
  for (const marca of M.testemunhaExige || []) {
    if (!testemunha.includes(marca.texto)) {
      reprova(M.testemunha + ' perdeu "' + marca.texto + '" — ' + marca.porque);
    }
  }
}

// ===========================================================================
// 10. ESTA AUTORIDADE NAO APROVA UMA ARVORE VAZIA
// ===========================================================================
//
// Uma varredura que nao achou nada devolve zero achados, e zero achados
// parecem zero problemas. As contagens abaixo sao o piso da propria medicao:
// sem elas, apagar meio repositorio deixaria este programa verde.

if (presentes.length < (M.workflowsCanonicos || []).length) {
  reprova(
    'o inventario achou ' +
      presentes.length +
      ' workflows, e os canonicos sozinhos ja sao ' +
      (M.workflowsCanonicos || []).length,
  );
}
if ((M.invocacoes || []).length < (M.minimos || {}).invocacoes) {
  reprova(
    'o manifesto declara ' +
      (M.invocacoes || []).length +
      ' invocacoes obrigatorias, e o minimo homologado e ' +
      (M.minimos || {}).invocacoes +
      ' — reduzir a lista de obrigacoes e afrouxar o portao sem tocar nele',
  );
}
if (
  (M.invocacoesCompartilhadas || []).length <
  (M.minimos || {}).invocacoesCompartilhadas
) {
  reprova(
    'o manifesto declara ' +
      (M.invocacoesCompartilhadas || []).length +
      ' invocacoes compartilhadas, e o minimo homologado e ' +
      (M.minimos || {}).invocacoesCompartilhadas,
  );
}
if ((M.cruzamento || []).length < (M.minimos || {}).cruzamento) {
  reprova(
    'o manifesto declara ' +
      (M.cruzamento || []).length +
      ' cruzamentos, e o minimo homologado e ' +
      (M.minimos || {}).cruzamento,
  );
}
if ((M.literaisFixadosNaFonteDeGates || []).length < (M.minimos || {}).literais) {
  reprova(
    'o manifesto fixa ' +
      (M.literaisFixadosNaFonteDeGates || []).length +
      ' literais na fonte de gates, e o minimo homologado e ' +
      (M.minimos || {}).literais,
  );
}

const MINIMOS_HOMOLOGADOS = {
  autoridadeExige: 10,
  invocacoes: 4,
  invocacoesCompartilhadas: 2,
  cruzamento: 2,
  literais: 27,
  obrigacoesMateriais: 21,
};
for (const [k, v] of Object.entries(MINIMOS_HOMOLOGADOS)) {
  const doManifesto = (M.minimos || {})[k];
  if (doManifesto !== v) {
    reprova(
      'o minimo "' +
        k +
        '" vale ' +
        v +
        ' nesta autoridade e ' +
        doManifesto +
        ' no manifesto — reduzir o numero de obrigacoes e o ataque que ' +
        'nenhuma contagem interna pega',
    );
  }
}
const comObrigacao = (M.casosProtegidos || []).filter(
  (p) => (p.exige || []).length > 0,
).length;
if (comObrigacao < MINIMOS_HOMOLOGADOS.obrigacoesMateriais) {
  reprova(
    'so ' +
      comObrigacao +
      ' dos casos protegidos tem obrigacao material, e o homologado sao ' +
      MINIMOS_HOMOLOGADOS.obrigacoesMateriais +
      '. Esvaziar a lista `exige` de um caso e trivializar o corpo dele com ' +
      'permissao.',
  );
}

// ===========================================================================

if (erros.length) {
  for (const e of erros) console.log('AUTORIDADE a11yterm REPROVOU: ' + e);
  console.log('AUTORIDADE a11yterm: ' + erros.length + ' motivo(s).');
  process.exit(1);
}
console.log(
  'autoridade a11yterm: ' +
    presentes.length +
    ' workflows inventariados, ' +
    (M.invocacoes || []).length +
    ' invocacoes de portador unico, ' +
    (M.invocacoesCompartilhadas || []).length +
    ' compartilhadas pelos dois portoes, ' +
    (M.casosProtegidos || []).length +
    ' casos protegidos com obrigacao material.',
);
