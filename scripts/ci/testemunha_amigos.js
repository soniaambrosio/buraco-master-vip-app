#!/usr/bin/env node
'use strict';

// ===========================================================================
// testemunha_amigos.js — TESTEMUNHA EXTERNA de execução, cobertura e pisos.
// ===========================================================================
//
// uso:
//   node scripts/ci/testemunha_amigos.js --raiz <repo> --app <raiz do app>
//   node scripts/ci/testemunha_amigos.js --conferir <marcador.json>
//
// ---------------------------------------------------------------------------
// POR QUE ELA EXISTE, E POR QUE É DE OUTRA NATUREZA
// ---------------------------------------------------------------------------
//
// A cadeia que já existia — `contrato_alvos_amigos.txt`, o verificador shell e
// a guarda Dart — prova COISAS SOBRE ARQUIVOS. Nenhuma das três sabe dizer se a
// suíte RODOU: as três leem fonte, contam sítios e conferem impressões digitais.
// Um `flutter test` que nunca foi invocado passa por todas elas.
//
// E as três compartilham dois oráculos que, por isso, não podem ser reusados
// aqui:
//
//   * a REGIÃO entre `DECISAO INICIO` e `DECISAO FIM`. Tudo o que estiver fora
//     dela é invisível para as duas impressões digitais que se cruzam. Código
//     antes do INICIO, código depois do FIM, um SEGUNDO bloco depois de um
//     primeiro FIM, o sanduíche `FIM / carga / INICIO`, um `return` anterior, uma
//     função declarada e nunca chamada — nada disso move nenhum dos dois
//     digests;
//   * as listas que elas próprias verificam (`_minimas`, `_pisosDeDeclaracao`,
//     as linhas `caso NN` do contrato). Uma lista que é ao mesmo tempo a
//     pergunta e a resposta não testemunha nada.
//
// Esta testemunha:
//
//   1. lê ARQUIVOS INTEIROS, nunca regiões delimitadas por comentário;
//   2. EXECUTA os comandos oficiais, e lê o código de saída de verdade;
//   3. consome o RELATÓRIO DE MÁQUINA que o `flutter test` produziu
//      (`--reporter json`), e não a fonte da suíte;
//   4. carrega expectativas literais PRÓPRIAS — o piso, as contagens, as 75
//      identidades, os nove pontos —, escritas aqui e em nenhum outro lugar;
//   5. amarra tudo a um DESAFIO desta corrida, para que relatório, log e
//      marcador de uma corrida anterior não sirvam;
//   6. trata erro de parser, arquivo ausente e tipo inesperado como REPROVAÇÃO,
//      nunca como conformidade.
//
// ---------------------------------------------------------------------------
// ATÉ ONDE ELA ALCANÇA
// ---------------------------------------------------------------------------
//
// Ela NÃO cobre a própria remoção — nenhuma guarda cobre. Quem cobre a remoção
// dela é o verificador do passo 0, que exige este arquivo no disco e a chave
// `testemunha` registrada nas duas listas de gate do workflow; e quem cobre a
// remoção DESSA exigência é a guarda Dart, que carimba a região de decisão do
// verificador. A raiz de confiança termina em quem apagar os três no mesmo
// diff — o que é exatamente o ponto: deixa de ser silencioso.

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const { spawnSync } = require('child_process');

// ===========================================================================
// EXPECTATIVAS LITERAIS PRÓPRIAS
// ===========================================================================
//
// Escritas AQUI. Nenhuma delas é lida do produto, da suíte, da matriz, do
// contrato ou das guardas — se fossem, esta testemunha estaria conferindo um
// arquivo contra ele mesmo.

/// O piso de toque, em pontos lógicos.
///
/// DECLARADO, e não medido. Ele não é derivado do alvo que a suíte mede, nem
/// lido de `contrato_alvos_amigos.txt`, nem do `_piso` das suítes, nem do
/// `PISO_CARIMBADO` do shell, nem do `_pisoCarimbado` da guarda Dart. Baixar o
/// piso para 40 nos cinco pontos conhecidos e recarimbar aquelas três
/// autoridades deixa ESTA linha de pé, e é ela que reprova.
const PISO_DP = 48;

/// A fração da altura da tela que a lista SEMPRE conserva.
///
/// DECLARADA, e não derivada. Não é lida da matriz, do produto, do contrato,
/// do shell nem da guarda Dart: baixar `_fracaoMinimaDaLista` para 0.20 e
/// recarimbar tudo o que for interno deixa ESTA linha de pé, e é ela que
/// reprova.
const FRACAO_MINIMA_DA_LISTA = 0.4;

/// A altura, em pontos, do telefone em que a fração é medida.
///
/// Ela existe porque `expect(viewport, moreOrLessEquals(_alturaReal))` é uma
/// igualdade entre DUAS COISAS QUE O ATACANTE CONTROLA: mudar `_alturaReal`
/// para 2000 e montar a 2000 satisfaz a igualdade e mede outro aparelho. Esta
/// âncora externa é o que impede a mudança coordenada.
const ALTURA_REAL_ESPERADA = 640.0;

/// O TETO do que o cabeçalho pode ocupar — conferido por DESIGUALDADE.
///
/// Nunca por igualdade. Baixar `_fracaoMaximaDoCabecalho` de 0.6 para 0.59 dá
/// MAIS espaço à lista: é melhoria, e uma autoridade que reprovasse isso
/// estaria guardando o número em vez da propriedade — o mesmo erro que a §8
/// proíbe no eixo dos 48 dp. O que se exige é o teto, e a aritmética que liga
/// as duas pontas: piso da lista + teto do cabeçalho nunca passa de 1.
const TETO_MAXIMO_DO_CABECALHO = 0.6;

/// O analisador de causalidade, que usa a AST OFICIAL do Dart.
const ANALISADOR_AST = 'scripts/ci/analisar_m4.dart';

/// A altura, em pontos lógicos, do telefone em que o alcance é provado.
const ALTURA_TELEFONE_DP = 640;

/// Os NOVE pontos dimensionais da matriz: largura em dp x escala de texto em %.
///
/// Eles são conferidos contra o que o RELATÓRIO DE MÁQUINA mostra ter rodado, e
/// não contra a fonte da matriz. Reduzir os nove a um, ou tirar o eixo do
/// telefone, reprova aqui mesmo que todos os digests sejam realinhados junto.
const PONTOS = [
  [320, 100], [320, 150], [320, 200],
  [360, 100], [360, 150], [360, 200],
  [412, 100], [412, 150], [412, 200],
];

/// Quantos casos cada ponto dimensional produz: cinco de medida (M1..M5) e
/// quatro de alcance e toque (T1..T4).
const CASOS_POR_PONTO = 9;

/// Os casos da matriz que NÃO carregam sufixo dimensional (grupos 3 a 7).
const CASOS_SEM_PONTO = 15;

/// Os ALVOS, com a contagem de casos que cada um tem de produzir AO RODAR.
///
/// `casos` é o número de casos REAIS do relatório — o evento sintético de
/// carga ("loading …", que o runner marca `hidden`) não conta. São igualdades,
/// e não pisos: uma suíte que encolhe reprova, e uma que cresce sem decisão
/// registrada também.
const ALVOS = [
  { chave: 'a11yamigos',   alvo: 'test/amigos/a11y_alvos_amigos_test.dart',    casos: 75 },
  { chave: 'matrizamigos', alvo: 'test/amigos/matriz_amigos_test.dart',        casos: 96 },
  { chave: 'casca',        alvo: 'test/casca/casca_producao_test.dart',        casos: 30 },
  { chave: 'cascaaud',     alvo: 'test/casca/auditoria_casca_test.dart',       casos: 19 },
  { chave: 'cascav2',      alvo: 'test/casca/homologacao_casca_v2_test.dart',  casos: 13 },
  { chave: 'suitesobrig',  alvo: 'test/ci/suites_obrigatorias_test.dart',      casos: 17 },
  { chave: 'amigos',       alvo: 'test/amigos',                                casos: 272 },
  { chave: 'integral',     alvo: null,                                         casos: 1522 },
];

/// Os arquivos congelados por impressão digital do CONTEÚDO INTEIRO.
///
/// Inteiro mesmo: do primeiro byte ao último, normalizado só para LF. Não há
/// marcador, não há região, não há "daqui até ali". É esta escolha que fecha os
/// nove escapes que a região deixava abertos — nenhum deles sobrevive a um
/// digest que não tem borda.
///
/// Os caminhos são relativos à RAIZ DO REPOSITÓRIO, e não à raiz do app: o que
/// se congela é a fonte versionada, nunca a cópia que o overlay do CI espalhou
/// em `app_build`.
/// O verificador shell NÃO entra aqui, e a ausência é decisão.
///
/// Ele carimba ESTA testemunha por arquivo inteiro. Se ela o carimbasse de
/// volta, cada edição de um moveria o carimbo do outro e o par nunca
/// fecharia — o mesmo laço que obrigou os carimbos existentes a morarem fora
/// das regiões que medem. A corrente é acíclica de propósito:
///
///   testemunha  -> guarda Dart, produto, suítes, contrato, manifesto
///   shell       -> testemunha
///   guarda Dart -> região de decisão do shell
///
/// O shell continua auditado aqui, e sobre o ARQUIVO INTEIRO: região única,
/// nada vivo depois do FIM, nenhum `exit 0`, nenhum `return` solto, nenhuma
/// função órfã, executor dentro da região. O que a impressão digital daria a
/// mais é "mudou alguma coisa" — e disso a guarda Dart já cuida, medindo a
/// região onde a decisão mora.
const CONGELADOS = {
  'scripts/ci/analisar_m4.dart':
    'e7922c221dc0ea75de0535f7fb542918a22ec246721b7279d97645b81185e3a2',
  'app/lib/casca/amigos_de_producao.dart':
    '7fb796b62e79b05e2585cabf5e21905b8223db08ba1d7ed357f127ac3d1c6a54',
  'app/test/amigos/a11y_alvos_amigos_test.dart':
    'b8620b704504baba248c3039d4939f4a561f33ad4a5e18ac8bcb36f2bdd3a169',
  'app/test/amigos/matriz_amigos_test.dart':
    'dea3755b09770f40e2e64122b1b2cabe47dad2ef467b263760135fa4b616751b',
  'app/test/casca/homologacao_casca_v2_test.dart':
    '23bd4f322130bfaf35df3795a92d96677cc0c6bb30f9fd7b813133c94d197daf',
  'app/test/ci/suites_obrigatorias_test.dart':
    '1e785e534abc9e912b7925866f3ad734d9315a10ba1d07409c5cab4c7c74df00',
  'app/test/contrato_alvos_amigos.txt':
    '7b57b61428445c2386ea85a005a4fe87c7e085ec6682f91b26db10b422746268',
  'app/test/suites_obrigatorias.txt':
    '7124f9e8c1560aa126b401c22aeb5556d5313cb5646068686714788e4e080b25',
};

/// Os PONTOS DO PISO no produto e nas suítes, com o valor que cada um tem de
/// carregar.
///
/// Escritos como número, comparados contra `PISO_DP`. Baixar qualquer um para
/// 40 reprova, e recarimbar contrato, shell e guarda Dart não ajuda: nenhuma
/// das três é lida aqui.
const PONTOS_DO_PISO = [
  { arquivo: 'app/lib/casca/amigos_de_producao.dart', padrao: 'height: 48,', minimo: 1 },
  { arquivo: 'app/lib/casca/amigos_de_producao.dart', padrao: 'BoxConstraints(minWidth: 48, minHeight: 48)', minimo: 2 },
  { arquivo: 'app/lib/casca/amigos_de_producao.dart', padrao: 'BoxConstraints(minHeight: 48, minWidth: 160)', minimo: 1 },
  { arquivo: 'app/test/amigos/a11y_alvos_amigos_test.dart', padrao: 'const double _piso = 48.0;', minimo: 1 },
  { arquivo: 'app/test/amigos/matriz_amigos_test.dart', padrao: 'const double _piso = 48.0;', minimo: 1 },
];

/// Quantas vezes a suíte de alvos COMPARA área medida com o piso.
///
/// Piso declarado e nunca comparado é decoração. Este número vive aqui porque
/// as outras três autoridades o carregam como `comparacoes`, e uma quarta cópia
/// independente é o que impede que as três sejam recarimbadas juntas.
/// O inventário do caso 1c: a cena inteira, na ordem em que o foco a percorre.
///
/// A suíte compara por IGUALDADE EXATA E ORDENADA, e não por `contains` — e
/// esta cópia existe para que a própria lista da suíte não seja a única
/// testemunha de si mesma. Um item retirado, um acrescentado, um duplicado ou
/// a ordem trocada divergem daqui, e realinhar a impressão digital do arquivo
/// não faz esta conferência passar.
///
/// As duas cadeias vazias são as linhas de Bia e de Caio: a linha é anunciada
/// por extenso pelo nó da linha, e o alvo em si não carrega nome próprio.
const INVENTARIO_1C = [
  'Voltar',
  'Aparecer offline',
  'Copiar',
  'Usar um código',
  'Buscar por apelido ou código…',
  'Online',
  'Todos',
  'Pedidos',
  '',
  'Chamar pra jogar',
  '',
  'Chamar pra jogar',
  'Carregar mais',
];

const COMPARACOES_COM_O_PISO = 17;

/// As afirmações materiais que a suíte de alvos tem de continuar fazendo.
///
/// São TOKENS DE CÓDIGO, contados na fonte inteira. Preservar os 75 nomes e
/// esvaziar os corpos derruba estes mínimos antes de qualquer digest.
const MATERIA_DOS_ALVOS = [
  { rotulo: 'piso de 48x48 comparado',        padrao: 'greaterThanOrEqualTo(_piso)', minimo: 17 },
  { rotulo: 'papel de botão',                 padrao: 'isButton',                    minimo: 1 },
  { rotulo: 'papel de campo',                 padrao: 'isTextField',                 minimo: 1 },
  { rotulo: 'estado de seleção',              padrao: 'isSelected',                  minimo: 1 },
  { rotulo: 'toque semântico',                padrao: 'SemanticsAction.tap',         minimo: 1 },
  { rotulo: 'hit test na borda',              padrao: 'hitTest',                     minimo: 1 },
  { rotulo: 'navegação por publicId',         padrao: 'publicId',                    minimo: 8 },
  { rotulo: 'nenhum uid na árvore',           padrao: "isNot(contains('uid'))",      minimo: 1 },
];

/// O que a Casca V2 tem de continuar provando MATERIALMENTE.
///
/// `listarAmigos` e `listarOnline` são contados dentro de `expect(` — remover
/// só os `expect` e deixar as chamadas de pé derruba estes mínimos sem depender
/// de nenhuma igualdade de arquivo.
const MATERIA_DA_CASCA_V2 = [
  { rotulo: 'expect sobre listarOnline',  padrao: "expect(b.social.chamadasDe('listarOnline')", minimo: 1 },
  { rotulo: 'expect sobre listarAmigos',  padrao: "expect(b.social.chamadasDe('listarAmigos')", minimo: 1 },
];

/// O que a matriz tem de continuar provando MATERIALMENTE.
const MATERIA_DA_MATRIZ = [
  { rotulo: 'eixo das larguras',      padrao: 'const _larguras = <double>[320, 360, 412];', minimo: 1 },
  { rotulo: 'eixo das escalas',       padrao: 'const _escalas = <double>[1.0, 1.5, 2.0];',  minimo: 1 },
  { rotulo: 'telefone de 640',        padrao: 'const _alturaReal = 640.0;',                 minimo: 1 },
  { rotulo: 'crescimento do texto',   padrao: 'TextScaler',                                 minimo: 1 },
  { rotulo: 'sem rolagem horizontal', padrao: 'Axis.horizontal',                            minimo: 1 },
  { rotulo: 'com rolagem vertical',   padrao: 'Axis.vertical',                              minimo: 1 },
  { rotulo: 'centro alcançável',      padrao: 'ensureVisible',                              minimo: 4 },
  { rotulo: 'aba inicial é Online',   padrao: "_porNome(alvos, 'Online').selecionado",      minimo: 1 },
];

/// A chave desta testemunha na fonte única de gates do workflow.
/// As entradas que o manifesto tem de continuar listando.
///
/// Escritas AQUI, e não lidas de `suites_obrigatorias.txt`: esvaziar o
/// manifesto e realinhar todo digest tocado deixa o arquivo existindo, bem
/// formado, e guardando nada. É esta cópia que reprova.
/// A quebra de linha, montada por código.
///
/// Escrita assim de propósito: este arquivo é gerado e remendado por
/// ferramentas que colapsam barra invertida, e uma quebra de linha que
/// depende de escape é a primeira coisa que se perde no caminho.
const QUEBRA = String.fromCharCode(10);

const MINIMAS_DO_MANIFESTO = [
  ['a11yamigos', 'test/amigos/a11y_alvos_amigos_test.dart'],
  ['matrizamigos', 'test/amigos/matriz_amigos_test.dart'],
  ['cascav2', 'test/casca/homologacao_casca_v2_test.dart'],
  ['suitesobrig', 'test/ci/suites_obrigatorias_test.dart'],
];

/// O que pode viver ANTES da região de decisão do verificador shell.
///
/// Só isto: atribuição de constante carimbada, o `set -u` e a leitura dos dois
/// argumentos. Qualquer outra linha viva ali é código que roda ANTES da decisão
/// e que nenhum dos dois carimbos cruzados alcança — o ponto cego que a §9 manda
/// eliminar.
///
/// A guarda Dart não precisa desta regra: ela é congelada por arquivo inteiro,
/// e ali o preâmbulo já entra no digest. O shell não pode ser congelado por
/// esta testemunha porque é ELE quem a carimba, e os dois se medindo por
/// arquivo inteiro nunca fechariam.
///
/// A regra é de FORMA: ela não diz quais constantes existem — isso seria
/// conferir a lista contra ela mesma — e sim que nada além de declaração pode
/// preceder a decisão.
const PREAMBULO_PERMITIDO = [
  /^readonly [A-Z_]+=/,
  /^set -u$/,
  /^raiz=/,
  /^workflow=/,
];

const CHAVE_DO_GATE = 'testemunha';

/// O caminho canônico desta testemunha, relativo à raiz do repositório.
const CAMINHO_PROPRIO = 'scripts/ci/testemunha_amigos.js';

/// O workflow que carrega a fonte única de gates.
const WORKFLOW = '.github/workflows/ci-os-integracao.yml';

// ===========================================================================
// DISCIPLINA DE REPROVAÇÃO
// ===========================================================================
//
// Toda leitura, todo parser e toda conversão passam por aqui. NADA é tratado
// como conformidade por omissão: arquivo ausente, JSON quebrado, campo com tipo
// inesperado e exceção de qualquer natureza viram falha com código próprio.
// Um `catch` que segue em frente é a forma mais barata de um portão mentir.

const falhas = [];
const notas = [];

function reprovar(codigo, mensagem) {
  falhas.push({ codigo, mensagem });
  console.log(`REPROVA  ${codigo}  ${mensagem}`);
}

function anotar(mensagem) {
  notas.push(mensagem);
  console.log(`ok       ${mensagem}`);
}

/// Executa [fn] e converte QUALQUER exceção em reprovação.
///
/// O valor de retorno em caso de exceção é `undefined`, e quem chama tem de
/// tratar isso — nunca seguir como se tivesse dado certo.
function protegido(codigo, oque, fn) {
  try {
    return fn();
  } catch (e) {
    reprovar(codigo, `${oque}: ${e && e.message ? e.message : String(e)}`);
    return undefined;
  }
}

/// O conteúdo INTEIRO de um arquivo, normalizado para LF.
///
/// A normalização não é zelo: o repositório é editado no Windows, com
/// `core.autocrlf`, e o CI roda no Linux. Sem ela a mesma árvore daria duas
/// impressões digitais conforme a máquina, e um gate que dá falso vermelho é
/// desligado na primeira semana.
function lerInteiro(abs) {
  if (!fs.existsSync(abs)) throw new Error(`arquivo ausente: ${abs}`);
  const st = fs.statSync(abs);
  if (!st.isFile()) throw new Error(`não é arquivo: ${abs}`);
  return fs.readFileSync(abs, 'utf8').replace(/\r/g, '');
}

function impressao(texto) {
  if (typeof texto !== 'string') throw new Error('impressão de não-texto');
  return crypto.createHash('sha256').update(texto, 'utf8').digest('hex');
}

function contar(texto, agulha) {
  if (typeof texto !== 'string' || typeof agulha !== 'string' || !agulha) {
    throw new Error('contagem com argumento inesperado');
  }
  let n = 0;
  let i = 0;
  for (;;) {
    const k = texto.indexOf(agulha, i);
    if (k < 0) return n;
    n += 1;
    i = k + agulha.length;
  }
}

// ===========================================================================
// COBERTURA INTEGRAL DO ARQUIVO — os nove escapes que a região deixava abertos
// ===========================================================================
//
// As linhas VIVAS de um arquivo: sem comentário de linha inteira e sem linha
// vazia. Comentário de fim de linha fica, de propósito — `exit 0  # temporário`
// é código, não comentário.
function linhasVivas(texto, marcaDeComentario) {
  return texto
    .split('\n')
    .map((l, i) => ({ n: i + 1, t: l.trim() }))
    .filter((l) => l.t !== '' && !l.t.startsWith(marcaDeComentario));
}

/// Confere que as marcas de região não escondem nada — e que NADA depende
/// delas para ser visto.
///
/// Os nove escapes de §9 morrem aqui e no digest do arquivo inteiro:
///
///   1. código ANTES do INICIO      -> entra no digest do inteiro
///   2. código DEPOIS do FIM        -> `vivasDepois`
///   3. SEGUNDO bloco após um FIM   -> `inicios !== 1`
///   4. sanduíche FIM / carga /     -> a ordem `iFim > iIni` mais `inicios===1`
///      INICIO                         e `fins===1`
///   5. `return` anterior           -> `retornoAntesDaDecisao`
///   6. função declarada e nunca    -> `funcoesOrfas`
///      chamada
///   7. mapa/manifesto/lista        -> os mínimos de MATERIA_* e de `_minimas`
///      esvaziados
///   8. executor retirado da região -> `exigeNaRegiao`
///   9. região vazia                -> `vivasDentro.length === 0`
function auditarRegiao(rotulo, texto, marcaIni, marcaFim, marcaDeComentario, exigeNaRegiao, preambuloPermitido) {
  const linhas = texto.split('\n');
  const inicios = linhas.filter((l) => l.includes(marcaIni)).length;
  const fins = linhas.filter((l) => l.includes(marcaFim)).length;

  if (inicios !== 1) {
    reprovar('REGIAO_INICIO_DUPLICADO', `${rotulo}: ${inicios} marcas de início (esperada 1) — um segundo bloco esconde código de quem digere só o primeiro`);
    return;
  }
  if (fins !== 1) {
    reprovar('REGIAO_FIM_DUPLICADO', `${rotulo}: ${fins} marcas de fim (esperada 1) — o sanduíche "FIM / carga / INICIO" vive exatamente aqui`);
    return;
  }

  const iIni = linhas.findIndex((l) => l.includes(marcaIni));
  const iFim = linhas.findIndex((l) => l.includes(marcaFim));
  if (!(iFim > iIni)) {
    reprovar('REGIAO_FORA_DE_ORDEM', `${rotulo}: o FIM (linha ${iFim + 1}) não vem depois do INICIO (linha ${iIni + 1})`);
    return;
  }

  const antes = linhas.slice(0, iIni).join(String.fromCharCode(10));
  if (preambuloPermitido !== undefined) {
    const intrusas = linhasVivas(antes, marcaDeComentario).filter(
      (l) => !preambuloPermitido.some((re) => re.test(l.t)),
    );
    if (intrusas.length > 0) {
      reprovar(
        'CODIGO_ANTES_DO_INICIO',
        rotulo +
          ': ' +
          intrusas.length +
          ' linha(s) viva(s) antes do INICIO que não são declaração, a começar por ' +
          intrusas[0].t.slice(0, 60) +
          ' (linha ' +
          intrusas[0].n +
          ') — código ali roda antes da decisão e não entra em carimbo nenhum',
      );
    }
  }

  const dentro = linhas.slice(iIni + 1, iFim).join('\n');
  const depois = linhas.slice(iFim + 1).join('\n');
  const vivasDentro = linhasVivas(dentro, marcaDeComentario);
  const vivasDepois = linhasVivas(depois, marcaDeComentario);

  if (vivasDentro.length === 0) {
    reprovar('REGIAO_VAZIA', `${rotulo}: a região de decisão não tem uma linha viva — as duas impressões digitais que se cruzam continuariam batendo sobre o vazio`);
  }
  if (vivasDepois.length > 0) {
    reprovar('CODIGO_DEPOIS_DO_FIM', `${rotulo}: ${vivasDepois.length} linha(s) viva(s) depois do FIM, a começar por "${vivasDepois[0].t.slice(0, 60)}" (linha ${iFim + 1 + vivasDepois[0].n})`);
  }

  for (const exigido of exigeNaRegiao) {
    if (!dentro.includes(exigido)) {
      reprovar('EXECUTOR_FORA_DA_REGIAO', `${rotulo}: "${exigido}" não está mais dentro da região de decisão — mover o executor para fora a torna invisível para quem carimba a região`);
    }
  }

  anotar(`${rotulo}: região única, em ordem, com ${vivasDentro.length} linha(s) viva(s) e nada depois do FIM`);
}

/// A auditoria estrutural do verificador shell, sobre o ARQUIVO INTEIRO.
///
/// Ela não olha a região: olha o script todo, e é por isso que pega o que a
/// região não pega.
/// [linha] chama [nome]?
///
/// Varredura literal, com borda conferida caractere a caractere. Montar uma
/// expressão regular a partir de um nome lido do arquivo seria deixar o arquivo
/// auditado escolher a linguagem da auditoria — e um nome com parêntese derruba
/// a testemunha em vez de reprovar o arquivo.
function invoca(linha, nome) {
  const ehIdent = (c) => c !== undefined && /[A-Za-z0-9_]/.test(c);
  let i = 0;
  for (;;) {
    const k = linha.indexOf(nome, i);
    if (k < 0) return false;
    const antes = k === 0 ? undefined : linha[k - 1];
    const depois = linha[k + nome.length];
    if (!ehIdent(antes) && !ehIdent(depois)) return true;
    i = k + 1;
  }
}

function auditarShell(rotulo, texto) {
  const vivas = linhasVivas(texto, '#');

  // (a) NENHUM `exit 0` vivo. O verificador sai com o próprio veredito
  // (`exit "$falhas"`) e com `exit 1` nos abortos; um `exit 0` em qualquer
  // lugar é uma saída verde plantada, e antes da decisão é o ataque clássico.
  const saidasZero = vivas.filter((l) => /^exit\s+0\s*$/.test(l.t) || /;\s*exit\s+0\s*$/.test(l.t));
  if (saidasZero.length > 0) {
    reprovar('SAIDA_ZERO_PLANTADA', `${rotulo}: "exit 0" vivo na linha ${saidasZero[0].n} — o script passa a sair verde sem decidir`);
  }

  // (b) NENHUM `return` no corpo principal. As funções deste script não
  // retornam valor; um `return` de primeiro nível encerra a leitura do arquivo
  // e deixa a decisão inalcançável, sem mudar uma linha da região.
  let profundidade = 0;
  for (const l of vivas) {
    const abre = contar(l.t, '{');
    const fecha = contar(l.t, '}');
    if (profundidade === 0 && /^return(\s|$)/.test(l.t)) {
      reprovar('RETORNO_ANTES_DA_DECISAO', `${rotulo}: "return" de primeiro nível na linha ${l.n} — tudo abaixo dele deixa de ser executado`);
    }
    profundidade += abre - fecha;
    if (profundidade < 0) profundidade = 0;
  }

  // (c) NENHUMA função órfã. Declarar `decidir() { ... }` e nunca chamá-la
  // mantém o corpo no arquivo, mantém o digest da região, e não executa nada.
  const declaradas = [];
  for (const l of vivas) {
    const m = l.t.match(/^([A-Za-z_][A-Za-z0-9_]*)\s*\(\)\s*\{/);
    if (m) declaradas.push({ nome: m[1], n: l.n });
  }
  for (const d of declaradas) {
    const chamadas = vivas.filter((l) => l.n !== d.n && invoca(l.t, d.nome));
    if (chamadas.length === 0) {
      reprovar('FUNCAO_ORFA', `${rotulo}: a função "${d.nome}" (linha ${d.n}) é declarada e nunca chamada — corpo presente, execução nenhuma`);
    }
  }

  anotar(`${rotulo}: ${vivas.length} linhas vivas, ${declaradas.length} função(ões), todas chamadas, sem "exit 0" nem "return" solto`);
}

/// A auditoria estrutural da guarda Dart, sobre o ARQUIVO INTEIRO.
function auditarDart(rotulo, texto, minimoDeCasos) {
  const vivas = linhasVivas(texto, '//');

  if (!/\bvoid\s+main\s*\(\s*\)\s*\{/.test(texto)) {
    reprovar('MAIN_AUSENTE', `${rotulo}: não há "void main()" — a suíte não declara nada para o runner`);
    return;
  }

  const iMain = texto.indexOf('void main()');
  const corpo = texto.slice(iMain);
  const casos = contar(corpo, 'test(') - contar(corpo, 'testWidgets(');
  const widgets = contar(corpo, 'testWidgets(');
  const total = casos + widgets;
  if (total < minimoDeCasos) {
    reprovar('GUARDA_ESVAZIADA', `${rotulo}: ${total} declaração(ões) de caso dentro de main(), e o mínimo desta testemunha é ${minimoDeCasos}`);
  }

  // Um `return;` de primeiro nível dentro de main(), antes dos grupos, deixa
  // a suíte com zero caso registrado e verde.
  const linhasDoCorpo = corpo.split('\n');
  const iPrimeiroGrupo = linhasDoCorpo.findIndex((l) => l.trim().startsWith('group('));
  const antes = iPrimeiroGrupo < 0 ? linhasDoCorpo : linhasDoCorpo.slice(0, iPrimeiroGrupo);
  const retorno = antes.findIndex((l) => /^\s{0,4}return\s*;/.test(l));
  if (retorno >= 0) {
    reprovar('RETORNO_ANTES_DOS_GRUPOS', `${rotulo}: "return;" dentro de main() antes do primeiro group() — nenhum caso chega a ser registrado`);
  }

  anotar(`${rotulo}: main() com ${total} declaração(ões) de caso e ${vivas.length} linhas vivas`);
}

// ===========================================================================
// O DESAFIO DESTA CORRIDA
// ===========================================================================
//
// Sem ele, um relatório verde de ontem serve de prova hoje. O desafio é
// sorteado agora, gasto num livro-caixa, viaja no NOME de cada relatório e é
// selado no marcador. Um marcador antigo carrega um desafio que já foi gasto, e
// o modo `--conferir` o recusa por isso.

function sortearDesafio(dirSaida) {
  const livro = path.join(dirSaida, 'desafios_gastos.txt');
  const desafio = crypto.randomBytes(16).toString('hex');

  let gastos = [];
  if (fs.existsSync(livro)) {
    gastos = lerInteiro(livro).split('\n').map((l) => l.trim()).filter(Boolean);
  }
  if (gastos.includes(desafio)) {
    // Impossível por sorteio, e possível por sabotagem: quem fixar o desafio
    // num literal cai aqui na segunda corrida.
    reprovar('DESAFIO_REAPROVEITADO', `o desafio ${desafio} já consta no livro-caixa — desafio reutilizado não prova corrida nenhuma`);
    return null;
  }
  fs.appendFileSync(livro, desafio + '\n', 'utf8');
  return desafio;
}

// ===========================================================================
// EXECUÇÃO VIVA
// ===========================================================================
//
// Uma invocação por alvo, exata, com o comando oficial. O relatório é escrito
// pelo PRÓPRIO `flutter test`, por redireção — a testemunha não o compõe, não o
// reescreve e não o completa. Se ele não existir, se vier vazio, se não parsear
// ou se for mais velho que o carimbo, isso é reprovação, nunca conformidade.

function comandoOficial(alvo) {
  return alvo === null
    ? 'flutter test --reporter json'
    : `flutter test ${alvo} --reporter json`;
}

function executar(raizApp, dirSaida, desafio, carimboMs, item) {
  const rel = path.join(dirSaida, `relatorio_${item.chave}_${desafio}.json`);
  const err = path.join(dirSaida, `erro_${item.chave}_${desafio}.log`);
  const linha = `${comandoOficial(item.alvo)} > "${rel}" 2> "${err}"`;

  const r = spawnSync(linha, {
    cwd: raizApp,
    shell: true,
    encoding: 'utf8',
    maxBuffer: 256 * 1024 * 1024,
    env: { ...process.env, BMV_DESAFIO: desafio },
  });

  if (r.error) {
    reprovar('INVOCACAO_FALHOU', `${item.chave}: o comando oficial não chegou a rodar — ${r.error.message}`);
    return null;
  }
  const saida = typeof r.status === 'number' ? r.status : null;
  if (saida === null) {
    reprovar('SEM_CODIGO_DE_SAIDA', `${item.chave}: o processo terminou por sinal (${r.signal}) e não há código de saída real`);
    return null;
  }

  if (!fs.existsSync(rel)) {
    reprovar('RELATORIO_AUSENTE', `${item.chave}: o comando rodou e não deixou relatório em ${rel}`);
    return null;
  }
  const st = fs.statSync(rel);
  if (st.size === 0) {
    reprovar('RELATORIO_VAZIO', `${item.chave}: relatório de zero byte — nada foi executado`);
    return null;
  }
  if (st.mtimeMs < carimboMs) {
    reprovar('LOG_REAPROVEITADO', `${item.chave}: o relatório é ANTERIOR ao carimbo desta corrida (${new Date(st.mtimeMs).toISOString()} < ${new Date(carimboMs).toISOString()})`);
    return null;
  }

  return { rel, saida, comando: comandoOficial(item.alvo), mtimeMs: st.mtimeMs };
}

/// Lê o relatório de máquina e devolve o que ELE diz — nunca o que se esperava.
function lerRelatorio(chave, rel) {
  const bruto = protegido('RELATORIO_ILEGIVEL', `${chave}: leitura do relatório`, () => lerInteiro(rel));
  if (bruto === undefined) return null;

  const inicios = new Map();
  const fins = [];
  let done = null;
  let comecou = false;
  let suites = 0;
  let ruido = 0;

  for (const l of bruto.split('\n')) {
    const t = l.trim();
    if (!t) continue;
    if (t[0] !== '{') { ruido += 1; continue; }
    let o;
    try {
      o = JSON.parse(t);
    } catch (e) {
      // Uma linha que COMEÇA como JSON e não parseia é relatório corrompido, e
      // não ruído de `pub`. Isso reprova.
      reprovar('RELATORIO_CORROMPIDO', `${chave}: linha de evento não parseia — "${t.slice(0, 80)}"`);
      return null;
    }
    if (o === null || typeof o !== 'object' || typeof o.type !== 'string') {
      reprovar('EVENTO_DE_TIPO_INESPERADO', `${chave}: evento sem "type" de texto`);
      return null;
    }
    if (o.type === 'start') comecou = true;
    if (o.type === 'suite') suites += 1;
    if (o.type === 'testStart') {
      if (!o.test || typeof o.test.id !== 'number' || typeof o.test.name !== 'string') {
        reprovar('EVENTO_DE_TIPO_INESPERADO', `${chave}: testStart sem id numérico ou nome de texto`);
        return null;
      }
      inicios.set(o.test.id, o.test.name);
    }
    if (o.type === 'testDone') {
      if (typeof o.testID !== 'number' || typeof o.result !== 'string') {
        reprovar('EVENTO_DE_TIPO_INESPERADO', `${chave}: testDone sem testID numérico ou result de texto`);
        return null;
      }
      fins.push(o);
    }
    if (o.type === 'done') done = o;
  }

  if (!comecou) {
    reprovar('RELATORIO_SEM_ABERTURA', `${chave}: nenhum evento "start" — o runner não chegou a abrir`);
    return null;
  }
  if (done === null) {
    reprovar('RELATORIO_SEM_FECHAMENTO', `${chave}: nenhum evento "done" — a execução foi interrompida, e um relatório truncado não é resultado`);
    return null;
  }
  if (done.success !== true) {
    reprovar('EXECUCAO_VERMELHA', `${chave}: o runner declarou success=${JSON.stringify(done.success)}`);
  }

  const reais = [];
  for (const f of fins) {
    const nome = inicios.get(f.testID);
    if (nome === undefined) {
      reprovar('RELATORIO_INCOERENTE', `${chave}: testDone para o id ${f.testID} sem testStart correspondente`);
      return null;
    }
    if (f.hidden === true) continue;
    reais.push({ nome, resultado: f.result });
  }

  return { reais, suites, ruido, done };
}

// ===========================================================================
// AS IDENTIDADES CONGELADAS
// ===========================================================================
//
// Transcritas do RELATÓRIO DE MÁQUINA de uma corrida real, e guardadas aqui
// como literal. Elas NÃO são lidas de `contrato_alvos_amigos.txt` nem da fonte
// da suíte: é justamente a divergência entre esta cópia e aquelas que denuncia
// um recarimbo feito só de um lado.
//
// A ordem é a ordem contratada. Comparar como conjunto deixaria passar uma
// suíte reordenada, e a ordem de foco é uma afirmação da própria OS 17.

const NOMES_DOS_75 = [
  "1 — o piso de 48 pontos 1a — o Voltar mede ao menos 48x48 (media 44x44 na base)",
  "1 — o piso de 48 pontos 1b — nenhum alvo mede menos de 48x48 — todos + carregar mais",
  "1 — o piso de 48 pontos 1b — nenhum alvo mede menos de 48x48 — pedidos recebidos",
  "1 — o piso de 48 pontos 1b — nenhum alvo mede menos de 48x48 — pedidos enviados",
  "1 — o piso de 48 pontos 1b — nenhum alvo mede menos de 48x48 — busca com resultado",
  "1 — o piso de 48 pontos 1b — nenhum alvo mede menos de 48x48 — busca truncada",
  "1 — o piso de 48 pontos 1b — nenhum alvo mede menos de 48x48 — falha de lista",
  "1 — o piso de 48 pontos 1b — nenhum alvo mede menos de 48x48 — falha de busca",
  "1 — o piso de 48 pontos 1b — nenhum alvo mede menos de 48x48 — vazio",
  "1 — o piso de 48 pontos 1b — nenhum alvo mede menos de 48x48 — carregando",
  "1 — o piso de 48 pontos 1b — nenhum alvo mede menos de 48x48 — fora do escopo",
  "1 — o piso de 48 pontos 1c — o inventário nominal preserva os controles essenciais",
  "1 — o piso de 48 pontos 1d — recebidas oferece Aceitar e Recusar, ambos no piso",
  "2 — a área nova não invade a do vizinho 2a — nenhuma interseção parcial — todos + carregar mais",
  "2 — a área nova não invade a do vizinho 2a — nenhuma interseção parcial — pedidos recebidos",
  "2 — a área nova não invade a do vizinho 2a — nenhuma interseção parcial — pedidos enviados",
  "2 — a área nova não invade a do vizinho 2a — nenhuma interseção parcial — busca com resultado",
  "2 — a área nova não invade a do vizinho 2a — nenhuma interseção parcial — busca truncada",
  "2 — a área nova não invade a do vizinho 2a — nenhuma interseção parcial — falha de lista",
  "2 — a área nova não invade a do vizinho 2a — nenhuma interseção parcial — falha de busca",
  "2 — a área nova não invade a do vizinho 2a — nenhuma interseção parcial — vazio",
  "2 — a área nova não invade a do vizinho 2a — nenhuma interseção parcial — carregando",
  "2 — a área nova não invade a do vizinho 2a — nenhuma interseção parcial — fora do escopo",
  "2 — a área nova não invade a do vizinho 2b — o botão ampliado continua CABENDO na linha dele",
  "2 — a área nova não invade a do vizinho 2c — Aceitar e Recusar continuam separados",
  "3 — tocar na borda nova aciona o controle certo 3a — os quatro cantos do Voltar voltam",
  "3 — tocar na borda nova aciona o controle certo 3b — as bordas de cada aba trocam para a aba daquele rótulo",
  "3 — tocar na borda nova aciona o controle certo 3c — os cantos de Aceitar aceitam, e com o publicId da linha",
  "3 — tocar na borda nova aciona o controle certo 3d — os cantos de Recusar recusam, e nunca aceitam",
  "3 — tocar na borda nova aciona o controle certo 3e — a borda ampliada do botão NÃO abre o Perfil da linha",
  "3 — tocar na borda nova aciona o controle certo 3f — os cantos de Limpar busca limpam a busca",
  "3 — tocar na borda nova aciona o controle certo 3g — a borda da linha abre o Perfil daquele publicId",
  "3 — tocar na borda nova aciona o controle certo 3h — a borda de Adicionar solicita amizade, com o publicId da busca",
  "3 — tocar na borda nova aciona o controle certo 3i — a borda de Cancelar cancela o pedido enviado",
  "3 — tocar na borda nova aciona o controle certo 3j — a borda de Tentar de novo relê a lista",
  "3 — tocar na borda nova aciona o controle certo 3k — a borda de Carregar mais pagina com o cursor",
  "4 — a semântica exemplar continua de pé 4a — as abas continuam declarando papel e seleção",
  "4 — a semântica exemplar continua de pé 4b — as linhas continuam anunciadas por extenso, e o avatar continua fora",
  "4 — a semântica exemplar continua de pé 4c — os botões continuam com papel de botão e habilitados",
  "4 — a semântica exemplar continua de pé 4d — o campo de busca continua campo, com o tooltip de limpar",
  "4 — a semântica exemplar continua de pé 4e — nenhum anúncio duplicado — todos + carregar mais",
  "4 — a semântica exemplar continua de pé 4f — a ordem de foco desce a tela — todos + carregar mais",
  "4 — a semântica exemplar continua de pé 4g — nenhum UID na árvore — todos + carregar mais",
  "4 — a semântica exemplar continua de pé 4e — nenhum anúncio duplicado — pedidos recebidos",
  "4 — a semântica exemplar continua de pé 4f — a ordem de foco desce a tela — pedidos recebidos",
  "4 — a semântica exemplar continua de pé 4g — nenhum UID na árvore — pedidos recebidos",
  "4 — a semântica exemplar continua de pé 4e — nenhum anúncio duplicado — pedidos enviados",
  "4 — a semântica exemplar continua de pé 4f — a ordem de foco desce a tela — pedidos enviados",
  "4 — a semântica exemplar continua de pé 4g — nenhum UID na árvore — pedidos enviados",
  "4 — a semântica exemplar continua de pé 4e — nenhum anúncio duplicado — busca com resultado",
  "4 — a semântica exemplar continua de pé 4f — a ordem de foco desce a tela — busca com resultado",
  "4 — a semântica exemplar continua de pé 4g — nenhum UID na árvore — busca com resultado",
  "4 — a semântica exemplar continua de pé 4e — nenhum anúncio duplicado — busca truncada",
  "4 — a semântica exemplar continua de pé 4f — a ordem de foco desce a tela — busca truncada",
  "4 — a semântica exemplar continua de pé 4g — nenhum UID na árvore — busca truncada",
  "4 — a semântica exemplar continua de pé 4e — nenhum anúncio duplicado — falha de lista",
  "4 — a semântica exemplar continua de pé 4f — a ordem de foco desce a tela — falha de lista",
  "4 — a semântica exemplar continua de pé 4g — nenhum UID na árvore — falha de lista",
  "4 — a semântica exemplar continua de pé 4e — nenhum anúncio duplicado — falha de busca",
  "4 — a semântica exemplar continua de pé 4f — a ordem de foco desce a tela — falha de busca",
  "4 — a semântica exemplar continua de pé 4g — nenhum UID na árvore — falha de busca",
  "4 — a semântica exemplar continua de pé 4e — nenhum anúncio duplicado — vazio",
  "4 — a semântica exemplar continua de pé 4f — a ordem de foco desce a tela — vazio",
  "4 — a semântica exemplar continua de pé 4g — nenhum UID na árvore — vazio",
  "4 — a semântica exemplar continua de pé 4e — nenhum anúncio duplicado — carregando",
  "4 — a semântica exemplar continua de pé 4f — a ordem de foco desce a tela — carregando",
  "4 — a semântica exemplar continua de pé 4g — nenhum UID na árvore — carregando",
  "4 — a semântica exemplar continua de pé 4e — nenhum anúncio duplicado — fora do escopo",
  "4 — a semântica exemplar continua de pé 4f — a ordem de foco desce a tela — fora do escopo",
  "4 — a semântica exemplar continua de pé 4g — nenhum UID na árvore — fora do escopo",
  "5 — vazio, carregando, erro e conteúdo 5a — vazio diz a frase da aba, e não desenha alvo de lista",
  "5 — vazio, carregando, erro e conteúdo 5b — carregando mostra o progresso",
  "5 — vazio, carregando, erro e conteúdo 5c — erro oferece Tentar de novo, no piso",
  "5 — vazio, carregando, erro e conteúdo 5d — conteúdo continua desenhando quem o servidor mandou",
  "5 — vazio, carregando, erro e conteúdo 5e — fora do escopo diz o motivo, e o Voltar continua no piso",
];

const NOMES_DA_CASCA_V2 = [
  "navegação não sobrevive à troca de sessão o botão voltar não recupera a rota privada depois do logout",
  "navegação não sobrevive à troca de sessão a troca de conta não herda a navegação da conta anterior",
  "navegação não sobrevive à troca de sessão é a GERAÇÃO que derruba a pilha, e não a troca de tela",
  "a Home não pisca em quadro nenhum antes da sessão responder",
  "transporte abrir o lobby não notifica ancestral durante o build",
  "transporte sair e voltar ao lobby não abre um segundo socket",
  "transporte o logout cancela uma reconexão JÁ AGENDADA",
  "transporte o logout no meio da autenticação fecha o socket em aberto",
  "transporte protocolo incompatível é terminal — não vira laço",
  "transporte o recado de estado terminal cabe na linha — REGRESSÃO",
  "transporte descartar a raiz solta o ouvinte da ponte",
  "os três bloqueados avisam, e nenhum deles navega",
  "Amigos navega, e o que abre consulta a autoridade",
];

// ===========================================================================
// AS CONFERÊNCIAS
// ===========================================================================

function conferirIdentidades(chave, reais, esperados) {
  if (reais.length !== esperados.length) {
    reprovar('CONTAGEM_DE_IDENTIDADES', `${chave}: ${reais.length} identidades no relatório, e esta testemunha contratou ${esperados.length}`);
    return;
  }
  const vistos = new Set();
  let divergencias = 0;
  for (let i = 0; i < esperados.length; i += 1) {
    const obtido = reais[i].nome;
    if (vistos.has(obtido)) {
      reprovar('IDENTIDADE_DUPLICADA', `${chave}: a identidade "${obtido}" aparece mais de uma vez`);
    }
    vistos.add(obtido);
    if (obtido !== esperados[i]) {
      divergencias += 1;
      if (divergencias <= 3) {
        reprovar('IDENTIDADE_FORA_DE_ORDEM', `${chave}: na posição ${i + 1} rodou "${obtido}" e o contratado é "${esperados[i]}"`);
      }
    }
  }
  if (divergencias > 3) {
    reprovar('IDENTIDADE_FORA_DE_ORDEM', `${chave}: mais ${divergencias - 3} divergência(s) de identidade não listada(s)`);
  }
  if (divergencias === 0) {
    anotar(`${chave}: as ${esperados.length} identidades rodaram, na ordem contratada, sem repetida`);
  }
}

/// Os pontos dimensionais que REALMENTE rodaram, extraídos do relatório.
///
/// Nada aqui vem da fonte da matriz: o sufixo "— 320 dp @ 150%" é produzido
/// pelo laço ao registrar o caso, então ele só existe no relatório se o laço
/// existir e tiver rodado. Reduzir os nove pontos a um reprova aqui mesmo que
/// todo digest tocado seja realinhado junto.
function conferirPontosDimensionais(reais) {
  const re = /— (\d+) dp @ (\d+)%$/;
  const contagem = new Map();
  let semPonto = 0;
  for (const r of reais) {
    const m = r.nome.match(re);
    if (!m) { semPonto += 1; continue; }
    const k = `${m[1]}x${m[2]}`;
    contagem.set(k, (contagem.get(k) || 0) + 1);
  }

  const esperados = PONTOS.map(([w, s]) => `${w}x${s}`);
  for (const k of esperados) {
    const n = contagem.get(k) || 0;
    if (n !== CASOS_POR_PONTO) {
      reprovar('PONTO_DIMENSIONAL', `matriz: o ponto ${k.replace('x', ' dp @ ')}% rodou ${n} caso(s), e o contratado é ${CASOS_POR_PONTO}`);
    }
  }
  for (const k of contagem.keys()) {
    if (!esperados.includes(k)) {
      reprovar('PONTO_DIMENSIONAL_INTRUSO', `matriz: rodou o ponto ${k.replace('x', ' dp @ ')}%, que não está entre os nove contratados`);
    }
  }
  if (contagem.size !== PONTOS.length) {
    reprovar('PONTOS_DIMENSIONAIS', `matriz: ${contagem.size} ponto(s) dimensional(is) no relatório, e os contratados são ${PONTOS.length}`);
  }
  if (semPonto !== CASOS_SEM_PONTO) {
    reprovar('CASOS_SEM_PONTO', `matriz: ${semPonto} caso(s) sem sufixo dimensional, e o contratado é ${CASOS_SEM_PONTO}`);
  }

  const temTelefone = esperados.every((k) => (contagem.get(k) || 0) === CASOS_POR_PONTO);
  if (temTelefone && contagem.size === PONTOS.length && semPonto === CASOS_SEM_PONTO) {
    anotar(`matriz: os ${PONTOS.length} pontos dimensionais rodaram, ${CASOS_POR_PONTO} casos cada, mais ${CASOS_SEM_PONTO} casos sem eixo`);
  }
}

function conferirMateria(raiz, arquivo, itens, rotulo) {
  const texto = protegido('MATERIA_ILEGIVEL', `${rotulo}: leitura de ${arquivo}`, () => lerInteiro(path.join(raiz, arquivo)));
  if (texto === undefined) return;
  for (const it of itens) {
    const n = contar(texto, it.padrao);
    if (n < it.minimo) {
      reprovar('MATERIA_PERDIDA', `${rotulo}: "${it.rotulo}" aparece ${n} vez(es) em ${arquivo}, e o mínimo desta testemunha é ${it.minimo}`);
    }
  }
  anotar(`${rotulo}: as ${itens.length} afirmações materiais continuam na fonte de ${arquivo}`);
}

/// O inventário do caso 1c continua exato e na ordem?
function conferirInventario1c(raiz) {
  const alvo = 'app/test/amigos/a11y_alvos_amigos_test.dart';
  const texto = protegido('INVENTARIO_ILEGIVEL', 'inventário 1c: leitura', () => lerInteiro(path.join(raiz, alvo)));
  if (texto === undefined) return;

  const iCaso = texto.indexOf('1c — o inventário nominal');
  if (iCaso < 0) {
    reprovar('CASO_1C_AUSENTE', 'o caso 1c sumiu da suíte de alvos — o inventário nominal não é mais afirmado por ninguém');
    return;
  }
  const marca = 'expect(_alvos(tester).map((a) => a.nome).toList(), <String>[';
  const iLista = texto.indexOf(marca, iCaso);
  if (iLista < 0) {
    reprovar('INVENTARIO_1C_AUSENTE', 'o caso 1c não compara mais a lista inteira de nomes — trocar a igualdade exata por `contains` cai aqui');
    return;
  }
  const iFim = texto.indexOf(']);', iLista);
  if (iFim < 0) {
    reprovar('INVENTARIO_1C_ABERTO', 'a lista do caso 1c não fecha — fonte inesperada, e isso é reprovação, não conformidade');
    return;
  }

  // Os literais entre aspas simples, na ordem em que aparecem. Comentário de
  // fim de linha fica de fora porque não é literal.
  const corpo = texto.slice(iLista + marca.length, iFim);
  const itens = [];
  for (const linha of corpo.split(QUEBRA)) {
    const semComentario = linha.split('//')[0];
    const m = semComentario.match(/'([^']*)'\s*,/);
    if (m) itens.push(m[1]);
  }

  if (itens.length !== INVENTARIO_1C.length) {
    reprovar('INVENTARIO_1C_TAMANHO', `o caso 1c lista ${itens.length} controles, e esta testemunha contratou ${INVENTARIO_1C.length}`);
    return;
  }
  for (let i = 0; i < INVENTARIO_1C.length; i += 1) {
    if (itens[i] !== INVENTARIO_1C[i]) {
      reprovar('INVENTARIO_1C_DIVERGE', `o caso 1c tem "${itens[i]}" na posição ${i + 1}, e o contratado é "${INVENTARIO_1C[i]}"`);
      return;
    }
  }
  anotar(`inventário do caso 1c: ${itens.length} controles, exatos e na ordem contratada`);
}

function conferirPisos(raiz) {
  if (PISO_DP !== 48) {
    reprovar('PISO_ADULTERADO', `o piso literal desta testemunha é ${PISO_DP}, e o contratado pela OS 17 é 48`);
  }
  for (const p of PONTOS_DO_PISO) {
    const texto = protegido('PISO_ILEGIVEL', `piso: leitura de ${p.arquivo}`, () => lerInteiro(path.join(raiz, p.arquivo)));
    if (texto === undefined) continue;
    const n = contar(texto, p.padrao);
    if (n < p.minimo) {
      reprovar('PISO_REBAIXADO', `${p.arquivo}: "${p.padrao}" aparece ${n} vez(es), e o mínimo é ${p.minimo} — o piso de ${PISO_DP} dp foi afrouxado neste ponto`);
    }
  }
  const alvos = protegido('PISO_ILEGIVEL', 'piso: leitura da suíte de alvos', () => lerInteiro(path.join(raiz, 'app/test/amigos/a11y_alvos_amigos_test.dart')));
  if (alvos !== undefined) {
    const n = contar(alvos, 'greaterThanOrEqualTo(_piso)');
    if (n !== COMPARACOES_COM_O_PISO) {
      reprovar('COMPARACOES_COM_O_PISO', `a suíte de alvos compara área com o piso ${n} vez(es), e esta testemunha contratou ${COMPARACOES_COM_O_PISO}`);
    }
  }
  anotar(`piso de ${PISO_DP} dp: declarado nesta testemunha e conferido nos ${PONTOS_DO_PISO.length} pontos, sem consultar contrato, shell ou guarda Dart`);
}

/// O manifesto continua listando o que esta OS declarou obrigatório?
function conferirManifesto(raiz) {
  const texto = protegido('MANIFESTO_ILEGIVEL', 'manifesto: leitura', () => lerInteiro(path.join(raiz, 'app/test/suites_obrigatorias.txt')));
  if (texto === undefined) return;
  const entradas = texto
    .split(QUEBRA)
    .map((l) => l.trim())
    .filter((l) => l !== '' && !l.startsWith('#'))
    .map((l) => l.split(/\s+/));
  if (entradas.length === 0) {
    reprovar('MANIFESTO_ESVAZIADO', 'o manifesto não tem uma entrada — a lista foi esvaziada');
    return;
  }
  for (const [chave, caminho] of MINIMAS_DO_MANIFESTO) {
    const achou = entradas.some((e) => e[0] === chave && e[1] === caminho);
    if (!achou) {
      reprovar('MANIFESTO_ENCOLHEU', `o manifesto não lista mais "${chave} ${caminho}"`);
    }
  }
  anotar(`manifesto: ${entradas.length} entrada(s), com as ${MINIMAS_DO_MANIFESTO.length} desta OS de pé`);
}

/// Onde mora o `package_config.json` que resolve `package:analyzer`.
///
/// DESCOBERTO a partir do `flutter` do PATH, e nunca fixado: o caminho muda
/// entre máquinas e entre versões do SDK. Se não achar, isto é REPROVAÇÃO — a
/// testemunha não cai num analisador mais fraco por baixo. Um portão que
/// degrada em silêncio quando a ferramenta some é pior que um portão ausente,
/// porque continua imprimindo verde.
function pacoteDoAnalisador() {
  const sep = process.platform === 'win32' ? ';' : ':';
  const nomes = process.platform === 'win32' ? ['flutter.bat', 'flutter.exe', 'flutter'] : ['flutter'];
  for (const dir of (process.env.PATH || '').split(sep)) {
    if (!dir) continue;
    for (const n of nomes) {
      const alvo = path.join(dir, n);
      if (!fs.existsSync(alvo)) continue;
      const raizFlutter = path.dirname(path.dirname(alvo));
      const pc = path.join(raizFlutter, 'packages', 'flutter_tools', '.dart_tool', 'package_config.json');
      if (fs.existsSync(pc)) return pc;
    }
  }
  return null;
}

/// A CAUSALIDADE de M4, pela AST oficial do Dart.
///
/// Contar tokens responde "o texto está lá?" — pergunta sobre o arquivo, não
/// sobre a execução. Dá para conservar todos os tokens e desligar a cadeia:
/// movê-los para comentário, string ou helper morto; pôr um `return` antes da
/// afirmação; calcular a razão e entregar outra coisa ao `expect`; ou medir de
/// verdade e afirmar em seguida uma constante escrita à mão. Nenhum desses
/// move um `grep`.
function conferirCausalidadeDeM4(raiz) {
  const pc = pacoteDoAnalisador();
  if (pc === null) {
    reprovar('AST_INDISPONIVEL', 'não achei o package_config do flutter_tools a partir do PATH — sem a AST oficial esta testemunha NÃO afirma causalidade nenhuma');
    return;
  }
  if (!fs.existsSync(path.join(raiz, ANALISADOR_AST))) {
    reprovar('ANALISADOR_AUSENTE', `o analisador ${ANALISADOR_AST} sumiu`);
    return;
  }

  const r = spawnSync(
    `dart --packages="${pc}" ${ANALISADOR_AST} app/test/amigos/matriz_amigos_test.dart app/lib/casca/amigos_de_producao.dart`,
    { cwd: raiz, shell: true, encoding: 'utf8', maxBuffer: 32 * 1024 * 1024 },
  );
  if (r.error || typeof r.status !== 'number' || r.status !== 0) {
    reprovar('AST_FALHOU', `o analisador saiu com ${r.status} — ${(r.stderr || '').trim().slice(0, 300)}`);
    return;
  }

  const j = protegido('AST_ILEGIVEL', 'saída do analisador', () => JSON.parse(r.stdout));
  if (j === undefined) return;
  if (j === null || typeof j !== 'object' || j.ok !== true) {
    reprovar('AST_SEM_VEREDITO', 'o analisador não devolveu ok=true');
    return;
  }

  // --- as constantes, contra os literais desta testemunha ---
  const c = j.constantes || {};
  if (c._fracaoMinimaDaLista !== FRACAO_MINIMA_DA_LISTA) {
    reprovar('PISO_DA_LISTA_DIVERGE', `a matriz declara _fracaoMinimaDaLista = ${c._fracaoMinimaDaLista} e esta testemunha contratou ${FRACAO_MINIMA_DA_LISTA}`);
  }
  if (c._alturaReal !== ALTURA_REAL_ESPERADA) {
    reprovar('ALTURA_REAL_DIVERGE', `a matriz declara _alturaReal = ${c._alturaReal} e a âncora externa é ${ALTURA_REAL_ESPERADA}`);
  }
  if (typeof c._fracaoMaximaDoCabecalho !== 'number') {
    reprovar('TETO_ILEGIVEL', 'não consegui ler _fracaoMaximaDoCabecalho no produto');
  } else {
    // DESIGUALDADE, nunca igualdade: 0.59 é melhoria e passa.
    if (c._fracaoMaximaDoCabecalho > TETO_MAXIMO_DO_CABECALHO) {
      reprovar('TETO_DO_CABECALHO_ELEVADO', `_fracaoMaximaDoCabecalho subiu para ${c._fracaoMaximaDoCabecalho}, acima do teto de ${TETO_MAXIMO_DO_CABECALHO} — o cabeçalho passa a poder engolir a fatia da lista`);
    }
    if (FRACAO_MINIMA_DA_LISTA + c._fracaoMaximaDoCabecalho > 1.0000001) {
      reprovar('ARITMETICA_IMPOSSIVEL', `piso da lista ${FRACAO_MINIMA_DA_LISTA} + teto do cabeçalho ${c._fracaoMaximaDoCabecalho} passa de 1 — a garantia não cabe na tela`);
    }
  }

  // --- a cadeia causal ---
  const m = j.m4 || {};
  if (m.encontrado !== true) {
    reprovar('M4_AUSENTE', `o caso M4 não foi localizado: ${m.motivo}`);
    return;
  }
  const exigir = (cond, codigo, msg) => { if (!cond) reprovar(codigo, msg); };
  exigir(typeof m.fonteDaLista === 'string' && m.fonteDaLista.includes('getRect') && m.fonteDaLista.includes('ListView'),
    'SEM_GEOMETRIA_REAL', `M4 não liga nenhuma variável ao retângulo real da ListView (achei: ${m.fonteDaLista})`);
  exigir(typeof m.fonteDaViewport === 'string' && m.fonteDaViewport.includes('getSize'),
    'VIEWPORT_NAO_MEDIDA', `M4 não mede a viewport na árvore (achei: ${m.fonteDaViewport})`);
  exigir(m.fracaoVar !== null && typeof m.fonteDaFracao === 'string' && m.fonteDaFracao.includes('/'),
    'SEM_RAZAO', 'M4 não calcula a razão entre a lista e a viewport');
  exigir(m.expectRecebeAFracao === true,
    'EXPECT_NAO_CONSOME_A_RAZAO', 'M4 calcula a razão e entrega OUTRA coisa ao expect — a medição vira decoração');
  exigir(m.matcher === 'greaterThanOrEqualTo',
    'MATCHER_TROCADO', `M4 compara com "${m.matcher}" em vez de greaterThanOrEqualTo`);
  exigir(m.piso === '_fracaoMinimaDaLista',
    'PISO_NAO_E_A_CONSTANTE', `M4 compara contra "${m.piso}" em vez do piso declarado`);
  exigir(m.alcancavel === true,
    'AFIRMACAO_INALCANCAVEL', `há um retorno na instrução ${m.indiceDoRetorno} antes do expect na ${m.indiceDoExpect}`);
  exigir(m.afirmaViewportContratada === true,
    'SUPERFICIE_NAO_CONFERIDA', 'M4 não afirma que a superfície medida é a do telefone contratado — medir a 2000 passaria');
  exigir(m.alturaMontada === '_alturaReal',
    'MONTAGEM_EM_ALTURA_ERRADA', `M4 monta com altura "${m.alturaMontada}" em vez de _alturaReal`);
  exigir(m.cadeiaCompleta === true,
    'CADEIA_INCOMPLETA', 'a cadeia causal de M4 não fecha');

  if (m.cadeiaCompleta === true) {
    const onde = m.viaHelper === null ? 'no próprio corpo' : `no helper "${m.viaHelper}", que M4 chama`;
    anotar(`causalidade de M4 (AST oficial): ${m.fonteDaLista} -> ${m.fonteDaFracao} -> expect(${m.fracaoVar}, ${m.matcher}(${m.piso})), ${onde}, alcançável`);
  }
}

function conferirCongelados(raiz) {
  for (const [rel, esperado] of Object.entries(CONGELADOS)) {
    const texto = protegido('CONGELADO_ILEGIVEL', `congelado: ${rel}`, () => lerInteiro(path.join(raiz, rel)));
    if (texto === undefined) continue;
    if (esperado === null || typeof esperado !== 'string' || esperado.length !== 64) {
      reprovar('CARIMBO_AUSENTE', `${rel}: esta testemunha não carrega impressão digital para o arquivo — um congelado sem carimbo não congela nada`);
      continue;
    }
    const obtido = impressao(texto);
    if (obtido !== esperado) {
      reprovar('ARQUIVO_ALTERADO', `${rel}: a impressão do ARQUIVO INTEIRO é ${obtido} e a carimbada é ${esperado}`);
    }
  }
  anotar(`${Object.keys(CONGELADOS).length} arquivo(s) conferido(s) por impressão do conteúdo inteiro — sem marcador, sem região, sem borda`);
}

/// A testemunha está registrada na fonte única de gates que já existia?
///
/// Não se cria lista nova: a chave entra nas DUAS listas do workflow (a da
/// evidência e a do portão), que é onde esta família de gates sempre morou.
function conferirRegistro(raiz) {
  const wf = protegido('WORKFLOW_ILEGIVEL', 'registro: leitura do workflow', () => lerInteiro(path.join(raiz, WORKFLOW)));
  if (wf === undefined) return;
  const linhas = wf.split('\n');

  const naEvidencia = linhas
    .filter((l) => l.trim().startsWith('GATES="'))
    .some((l) => l.split(/[\s"]+/).includes(CHAVE_DO_GATE));
  if (!naEvidencia) {
    reprovar('GATE_FORA_DA_EVIDENCIA', `a chave "${CHAVE_DO_GATE}" está fora da lista GATES da evidência`);
  }

  const noPortao = linhas
    .filter((l) => l.trim().startsWith('for k in '))
    .some((l) => l.split(/[\s;]+/).includes(CHAVE_DO_GATE));
  if (!noPortao) {
    reprovar('GATE_FORA_DO_PORTAO', `a chave "${CHAVE_DO_GATE}" está fora da lista do portão — o gate rodaria, falharia, e ninguém olharia`);
  }

  const invocacoes = linhas.filter((l) => l.includes('testemunha_amigos.js'));
  if (invocacoes.length === 0) {
    reprovar('TESTEMUNHA_NAO_INVOCADA', 'o workflow não invoca esta testemunha em passo nenhum');
  }

  // A invocacao oficial NAO pode carregar bandeira que reduza a corrida. Uma
  // corrida restrita por `--alvos` nao sela marcador, mas ainda sai 0 quando o
  // pouco que rodou passa — pôr essa bandeira no workflow transformaria o gate
  // numa corrida de brinquedo com cara de verde.
  for (const l of invocacoes) {
    for (const bandeira of ['--alvos', '--conferir']) {
      if (l.includes(bandeira)) {
        reprovar('INVOCACAO_REDUZIDA', `a invocacao no workflow carrega "${bandeira}" — o gate deixaria de provar a corrida inteira`);
      }
    }
  }

  if (!fs.existsSync(path.join(raiz, CAMINHO_PROPRIO))) {
    reprovar('TESTEMUNHA_FORA_DO_CAMINHO', `esta testemunha não está em ${CAMINHO_PROPRIO} — o verificador do passo 0 a procura ali`);
  }

  anotar(`registro: "${CHAVE_DO_GATE}" nas duas listas de gate e invocada no workflow`);
}

// ===========================================================================
// O MARCADOR
// ===========================================================================
//
// Escrito UMA vez, DEPOIS de tudo, e só quando não há falha. Marcador
// antecipado é a mentira mais barata que um portão pode contar: ele afirma um
// resultado que ainda não existe.

function selarMarcador(dirSaida, desafio, carimboMs, corridas) {
  const marcador = {
    testemunha: 'testemunha_amigos.js',
    desafio,
    carimboIso: new Date(carimboMs).toISOString(),
    seladoIso: new Date().toISOString(),
    pisoDeclarado: PISO_DP,
    alturaDoTelefone: ALTURA_TELEFONE_DP,
    pontosDimensionais: PONTOS.length,
    corridas,
    conferencias: notas.length,
    veredito: 'VERDE',
  };
  const arq = path.join(dirSaida, `marcador_${desafio}.json`);
  fs.writeFileSync(arq, JSON.stringify(marcador, null, 2) + '\n', 'utf8');
  return arq;
}

/// Recusa um marcador reapresentado.
///
/// Um marcador só vale para a ÚLTIMA corrida: o desafio dele tem de ser a
/// última linha do livro-caixa. Guardar o marcador verde de ontem e mostrá-lo
/// hoje cai aqui.
function conferirMarcador(arq) {
  const bruto = protegido('MARCADOR_ILEGIVEL', `conferência: leitura de ${arq}`, () => lerInteiro(arq));
  if (bruto === undefined) return;
  const m = protegido('MARCADOR_CORROMPIDO', `conferência: parser de ${arq}`, () => JSON.parse(bruto));
  if (m === undefined) return;
  if (m === null || typeof m !== 'object' || typeof m.desafio !== 'string') {
    reprovar('MARCADOR_SEM_DESAFIO', `${arq}: o marcador não carrega desafio de texto`);
    return;
  }
  const livro = path.join(path.dirname(arq), 'desafios_gastos.txt');
  const gastos = protegido('LIVRO_ILEGIVEL', 'conferência: leitura do livro-caixa', () => lerInteiro(livro));
  if (gastos === undefined) return;
  const linhas = gastos.split('\n').map((l) => l.trim()).filter(Boolean);
  if (linhas.length === 0) {
    reprovar('LIVRO_VAZIO', 'o livro-caixa não registra desafio nenhum');
    return;
  }
  if (linhas[linhas.length - 1] !== m.desafio) {
    reprovar('MARCADOR_REAPROVEITADO', `o marcador carrega o desafio ${m.desafio}, que não é o da última corrida (${linhas[linhas.length - 1]})`);
    return;
  }
  if (m.veredito !== 'VERDE') {
    reprovar('MARCADOR_NAO_VERDE', `o marcador declara veredito "${m.veredito}"`);
    return;
  }
  anotar(`marcador ${path.basename(arq)}: desafio corrente, veredito VERDE`);
}

// ===========================================================================
// A CORRIDA
// ===========================================================================

function argumento(nome, padrao) {
  const i = process.argv.indexOf(nome);
  if (i < 0) return padrao;
  const v = process.argv[i + 1];
  if (v === undefined || v.startsWith('--')) {
    reprovar('ARGUMENTO_SEM_VALOR', `${nome} foi passado sem valor`);
    return padrao;
  }
  return v;
}

function main() {
  const conferir = argumento('--conferir', null);
  if (conferir !== null) {
    conferirMarcador(conferir);
    return encerrar('conferência de marcador');
  }

  const raiz = path.resolve(argumento('--raiz', process.cwd()));
  const raizApp = path.resolve(argumento('--app', path.join(raiz, 'app_build')));
  const dirSaida = path.resolve(argumento('--saida', path.join(raiz, '.testemunha')));
  const restricao = argumento('--alvos', null);

  if (!fs.existsSync(raiz)) return reprovarEEncerrar('RAIZ_AUSENTE', `a raiz do repositório não existe: ${raiz}`);
  if (!fs.existsSync(raizApp)) return reprovarEEncerrar('APP_AUSENTE', `a raiz do app não existe: ${raizApp}`);
  fs.mkdirSync(dirSaida, { recursive: true });

  const carimboMs = Date.now();
  const desafio = sortearDesafio(dirSaida);
  if (desafio === null) return encerrar('desafio');

  console.log(`testemunha externa — desafio ${desafio}`);
  console.log(`  raiz do repo : ${raiz}`);
  console.log(`  raiz do app  : ${raizApp}`);
  console.log(`  carimbo      : ${new Date(carimboMs).toISOString()}`);
  console.log('');

  // -------------------------------------------------------------------
  // 1 — Cobertura integral dos arquivos
  // -------------------------------------------------------------------
  console.log('--- 1. cobertura integral dos arquivos ---');
  const shell = protegido('SHELL_ILEGIVEL', 'verificador shell', () => lerInteiro(path.join(raiz, 'scripts/ci/verificar_suites_obrigatorias.sh')));
  if (shell !== undefined) {
    auditarRegiao('verificador shell', shell, '# ---8<--- DECISAO INICIO', '# ---8<--- DECISAO FIM', '#', ['exit "$falhas"'], PREAMBULO_PERMITIDO);
    auditarShell('verificador shell', shell);
  }
  const guarda = protegido('GUARDA_ILEGIVEL', 'guarda Dart', () => lerInteiro(path.join(raiz, 'app/test/ci/suites_obrigatorias_test.dart')));
  if (guarda !== undefined) {
    auditarRegiao('guarda Dart', guarda, '// ---8<--- DECISAO INICIO', '// ---8<--- DECISAO FIM', '//', ['void main()']);
    auditarDart('guarda Dart', guarda, 17);
  }
  conferirManifesto(raiz);
  conferirCongelados(raiz);
  conferirRegistro(raiz);

  // -------------------------------------------------------------------
  // 2 — Os pisos, e a matéria que eles guardam
  // -------------------------------------------------------------------
  console.log('');
  console.log('--- 2. pisos externos e matéria ---');
  conferirPisos(raiz);
  conferirInventario1c(raiz);
  conferirCausalidadeDeM4(raiz);
  conferirMateria(raiz, 'app/test/amigos/a11y_alvos_amigos_test.dart', MATERIA_DOS_ALVOS, 'alvos');
  conferirMateria(raiz, 'app/test/amigos/matriz_amigos_test.dart', MATERIA_DA_MATRIZ, 'matriz');
  conferirMateria(raiz, 'app/test/casca/homologacao_casca_v2_test.dart', MATERIA_DA_CASCA_V2, 'casca V2');

  // -------------------------------------------------------------------
  // 3 — Execução viva
  // -------------------------------------------------------------------
  console.log('');
  console.log('--- 3. execução viva dos comandos oficiais ---');
  const pedidos = restricao === null ? null : restricao.split(',').map((s) => s.trim()).filter(Boolean);
  const corridas = [];
  for (const item of ALVOS) {
    if (pedidos !== null && !pedidos.includes(item.chave)) continue;
    console.log(`  > ${item.chave}: ${comandoOficial(item.alvo)}`);
    const r = executar(raizApp, dirSaida, desafio, carimboMs, item);
    if (r === null) continue;
    const rel = lerRelatorio(item.chave, r.rel);
    if (rel === null) continue;

    if (r.saida !== 0) {
      reprovar('CODIGO_DE_SAIDA', `${item.chave}: o comando oficial saiu com ${r.saida}`);
    }
    if (rel.reais.length !== item.casos) {
      reprovar('CONTAGEM_DE_CASOS', `${item.chave}: rodaram ${rel.reais.length} casos reais, e esta testemunha contratou ${item.casos}`);
    }
    const vermelhos = rel.reais.filter((c) => c.resultado !== 'success');
    if (vermelhos.length > 0) {
      reprovar('CASOS_VERMELHOS', `${item.chave}: ${vermelhos.length} caso(s) não passaram, a começar por "${vermelhos[0].nome}"`);
    }

    if (item.chave === 'a11yamigos') conferirIdentidades('alvos', rel.reais, NOMES_DOS_75);
    if (item.chave === 'cascav2') conferirIdentidades('casca V2', rel.reais, NOMES_DA_CASCA_V2);
    if (item.chave === 'matrizamigos') conferirPontosDimensionais(rel.reais);

    corridas.push({
      chave: item.chave,
      comando: r.comando,
      saida: r.saida,
      casos: rel.reais.length,
      suites: rel.suites,
      relatorio: path.basename(r.rel),
      relatorioIso: new Date(r.mtimeMs).toISOString(),
    });
    anotar(`${item.chave}: exit ${r.saida}, ${rel.reais.length} casos reais em ${rel.suites} suíte(s), relatório de ${new Date(r.mtimeMs).toISOString()}`);
  }

  // -------------------------------------------------------------------
  // 4 — O marcador, só no fim, e só se houver o que selar
  // -------------------------------------------------------------------
  console.log('');
  if (pedidos !== null) {
    console.log(`PARCIAL — restrita a [${pedidos.join(', ')}]; nenhum marcador é selado numa corrida restrita.`);
    return encerrar('corrida restrita');
  }
  if (falhas.length === 0) {
    const arq = selarMarcador(dirSaida, desafio, carimboMs, corridas);
    console.log(`marcador selado: ${arq}`);
  }
  return encerrar('corrida completa');
}

function reprovarEEncerrar(codigo, msg) {
  reprovar(codigo, msg);
  return encerrar('abortada');
}

function encerrar(oque) {
  console.log('');
  console.log(`testemunha (${oque}): ${notas.length} conferência(s) ok, ${falhas.length} reprovação(ões)`);
  if (falhas.length > 0) {
    console.log('VEREDITO: VERMELHO');
    for (const f of falhas) console.log(`  ${f.codigo}: ${f.mensagem}`);
    process.exitCode = 1;
    return;
  }
  console.log('VEREDITO: VERDE');
  process.exitCode = 0;
}

// Nem uma exceção escapa daqui. Um `throw` que subisse até o topo mataria o
// processo com rastro de pilha, e rastro de pilha não é veredito — quem lê o log
// precisa ver a REPROVAÇÃO, e o portão precisa do código de saída certo.
try {
  main();
} catch (e) {
  reprovar('TESTEMUNHA_QUEBROU', 'a própria testemunha lançou: ' + (e && e.stack ? e.stack : String(e)));
  console.log('');
  console.log('VEREDITO: VERMELHO');
  process.exitCode = 1;
}
