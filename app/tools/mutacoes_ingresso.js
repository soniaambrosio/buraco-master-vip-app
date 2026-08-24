// mutacoes_ingresso.js — PROVAS NEGATIVAS da OS 38.3 (§16).
//
// ---------------------------------------------------------------------------
// O QUE ESTA CAMPANHA MEDE
// ---------------------------------------------------------------------------
//
// A §16 lista as maneiras de o ingresso ficar errado em silêncio. Cada uma
// vira uma MUTAÇÃO: uma edição cirúrgica no código de produção que desfaz
// exatamente aquele invariante. Se a suíte continuar verde, a defesa não
// existe — existe a intenção dela, escrita num comentário.
//
// Os itens 1 a 13 da §16 são da DESCOBERTA (filtros, UID, ordenação, Meta,
// modalidade, ocupação, vagas, presença, expiração, deduplicação, tradução
// STBL). Eles já têm campanha própria e herdada — `mutacoes_descoberta.js`,
// 26 mutações — e repeti-los aqui só faria a mesma medida custar duas vezes.
// Esta campanha cobre os itens 14 a 29, que são do INGRESSO.
//
// ---------------------------------------------------------------------------
// A ORDEM DA BATERIA É DE PROPÓSITO
// ---------------------------------------------------------------------------
//
// `bateria()` para na PRIMEIRA suíte vermelha. Pôr as rápidas primeiro não
// afrouxa nada — uma mutação pega por qualquer suíte conta, e o ponto não é
// quem acusa, é que a mutação MORRA — e faz a campanha inteira caber em horas
// em vez de dias.
//
// ---------------------------------------------------------------------------
// TRÊS TRAVAS ANTI-VÁCUO, e as três param o processo
// ---------------------------------------------------------------------------
//
//   1. a âncora tem de aparecer EXATAMENTE uma vez no arquivo;
//   2. o arquivo tem de mudar de bytes depois da troca;
//   3. tem de haver mutação carregada — uma campanha que lê zero e diz "tudo
//      certo" é o pior resultado possível, porque parece rigor e é vácuo.
//
// E um VERDE DE PARTIDA: se a árvore já estiver vermelha, mutação não prova
// nada, e a campanha para antes de começar.
//
// ---------------------------------------------------------------------------
// FIM DE LINHA
// ---------------------------------------------------------------------------
//
// Nesta árvore convivem arquivos em LF e em CRLF. A comparação é feita SEMPRE
// em LF, e a escrita devolve o fim de linha que o arquivo tinha. Reescrever
// tudo em LF mudaria o arquivo inteiro, e aí a reversão deixaria de ser
// reversão.
//
// Uso:  node tools/mutacoes_ingresso.js            (campanha completa)
//       node tools/mutacoes_ingresso.js --conferir (só as âncoras)

'use strict';

const fs = require('fs');
const path = require('path');
const { spawnSync } = require('child_process');

process.chdir(path.join(__dirname, '..'));

const SUITES = [
  'test/ingresso/contrato_e_estado_test.dart',
  'test/ingresso/escolha_assento_test.dart',
  'test/ingresso/transporte_ingresso_test.dart',
  'test/ingresso/navegacao_ingresso_test.dart',
  'test/descoberta/lobby_publico_test.dart',
];

const MUTACOES = [
  // --- §16.14 — o envio do assento ----------------------------------------
  {
    id: 'I01',
    nome: 'o pedido NUNCA leva o assento escolhido',
    arquivo: 'lib/services/online_service.dart',
    de: "      if (assento != null) ContratoDoIngresso.campoAssento: assento,\n",
    para: '',
  },
  {
    id: 'I02',
    nome: 'o ingresso automático manda `assento: null` explícito',
    arquivo: 'lib/services/online_service.dart',
    de: '      if (assento != null) ContratoDoIngresso.campoAssento: assento,',
    para: '      ContratoDoIngresso.campoAssento: assento,',
  },

  // --- §16.15 — a validação do ACK ----------------------------------------
  {
    id: 'I03',
    nome: 'o ACK sem assento válido passa a valer',
    arquivo: 'lib/ingresso/estado_ingresso.dart',
    de: '    if (!ContratoDoIngresso.ehAssentoPedido(assento)) {',
    para: '    if (false) {',
  },

  // --- §16.16 — solicitado == confirmado ----------------------------------
  {
    id: 'I04',
    nome: 'o assento confirmado deixa de precisar bater com o pedido',
    arquivo: 'lib/ingresso/estado_ingresso.dart',
    de:
      '    if (intencao.explicita && !reconexao && confirmado != intencao.assento) {',
    para: '    if (false) {',
  },
  {
    id: 'I05',
    nome: 'a RECONEXÃO deixa de ser reconhecida (o titular não volta)',
    arquivo: 'lib/ingresso/estado_ingresso.dart',
    de:
      '    final reconexao = bruto[ContratoDoIngresso.campoReconexao] == true;',
    para: '    const reconexao = false;',
  },

  // --- §16.17 — recusa sem fallback ---------------------------------------
  {
    id: 'I06',
    nome: 'a recusa é ENGOLIDA (a tela fica esperando para sempre)',
    arquivo: 'lib/ingresso/estado_ingresso.dart',
    de:
      '    final codigo = bruto[ContratoDoIngresso.campoCodigoDeRecusa];\n' +
      '    final motivo = bruto[ContratoDoIngresso.campoMotivo];\n' +
      '    return _recusar(',
    para:
      '    final codigo = bruto[ContratoDoIngresso.campoCodigoDeRecusa];\n' +
      '    final motivo = bruto[ContratoDoIngresso.campoMotivo];\n' +
      '    if (codigo != null || motivo != null) return false;\n' +
      '    return _recusar(',
  },
  {
    id: 'I07',
    nome: 'a recusa passa a conceder assento (o fallback silencioso)',
    arquivo: 'lib/ingresso/estado_ingresso.dart',
    de:
      '    _fase = FaseDoIngresso.recusado;\n' +
      '    _confirmado = null;',
    para:
      '    _fase = FaseDoIngresso.recusado;\n' +
      '    _confirmado = IngressoConfirmado(\n' +
      '      codigo: _intencao?.codigo ?? "",\n' +
      '      assento: _intencao?.assento ?? 0,\n' +
      '      reconexao: false,\n' +
      '    );',
  },

  // --- §16.19 — a trava do toque duplo ------------------------------------
  {
    id: 'I08',
    nome: 'o toque duplo passa a mandar dois pedidos',
    arquivo: 'lib/ingresso/estado_ingresso.dart',
    de: '    if (_fase == FaseDoIngresso.solicitando) return false;\n    if (codigo.isEmpty) return false;',
    para: '    if (codigo.isEmpty) return false;',
  },

  // --- §16.20 — o descarte da resposta atrasada ---------------------------
  {
    id: 'I09',
    nome: 'a resposta de uma conexão anterior passa a valer',
    arquivo: 'lib/ingresso/estado_ingresso.dart',
    de:
      '    if (geracaoDeTransporte != _geracaoDeTransporte) return false;\n' +
      '    if (intencao.geracaoDeTransporte != geracaoDeTransporte) return false;\n' +
      '\n' +
      '    if (bruto is! Map) return false;',
    para: '    if (bruto is! Map) return false;',
  },
  {
    id: 'I10',
    nome: 'a intenção SOBREVIVE à troca de conexão',
    arquivo: 'lib/ingresso/estado_ingresso.dart',
    de:
      '    if (_fase == FaseDoIngresso.solicitando) {\n' +
      '      _intencao = null;\n' +
      '      _recusa = null;\n' +
      '      _fase = FaseDoIngresso.ocioso;\n' +
      '    }',
    para: '    // sobrevive',
  },

  // --- §16.21 — a invalidação A → B ---------------------------------------
  {
    id: 'I11',
    nome: 'a confirmação de A SOBREVIVE à troca de conta',
    arquivo: 'lib/services/online_service.dart',
    de: '    ingresso.encerrarSessao();\n',
    para: '',
  },
  {
    id: 'I12',
    nome: 'a queda da conexão não mata o pedido em voo',
    arquivo: 'lib/services/online_service.dart',
    de:
      '    // um pedido que ninguém repetiu.\n' +
      '    ingresso.definirGeracaoDeTransporte(_geracaoTransporte);',
    para: '    // um pedido que ninguém repetiu.',
  },

  // --- §16.22 — a navegação otimista --------------------------------------
  {
    id: 'I12b',
    nome: 'a QUEDA da conexão deixa o pedido em voo travado para sempre',
    arquivo: 'lib/services/online_service.dart',
    de: '    ingresso.cancelar();\n    if (_estadoTerminal) return;',
    para: '    if (_estadoTerminal) return;',
  },
  {
    id: 'I13',
    nome: 'a confirmação passa a ser consumível MAIS DE UMA VEZ',
    arquivo: 'lib/ingresso/estado_ingresso.dart',
    de:
      '    final c = _confirmado;\n' +
      '    _confirmado = null;\n' +
      '    return c;',
    para: '    return _confirmado;',
  },
  {
    id: 'I14',
    nome: 'o destino é EMPILHADO em vez de substituir o seletor',
    arquivo: 'lib/casca/escolha_assento_de_producao.dart',
    de: '          Navigator.of(context).pushReplacement(',
    para: '          Navigator.of(context).push(',
  },
  {
    id: 'I15',
    nome: 'sair da tela NÃO invalida a intenção pendente',
    arquivo: 'lib/casca/escolha_assento_de_producao.dart',
    de: '    _srv?.ingresso.cancelar();',
    para: '    // _srv?.ingresso.cancelar();',
  },

  // --- §16.18 — a proteção de concorrência (classificação da recusa) ------
  {
    id: 'I16',
    nome: 'o CÓDIGO da recusa deixa de ser lido (só o texto vale)',
    arquivo: 'lib/ingresso/modelo_ingresso.dart',
    de: '    switch (codigo) {',
    para: '    switch (null) {',
  },
  {
    id: 'I17',
    nome: 'o acento passa a decidir se a recusa é conhecida',
    arquivo: 'lib/ingresso/contrato_ingresso.dart',
    de: '      final i = de.indexOf(c);\n      buffer.write(i == -1 ? c : para[i]);',
    para: '      buffer.write(c);',
  },

  // --- §16.23 — a reconexão pelo assento pertencente ----------------------
  {
    id: 'I18',
    nome: 'a reentrada automática passa a mandar preferência de assento',
    arquivo: 'lib/services/online_service.dart',
    de: "      _bruto({'tipo': 'entrarMesa', 'codigo': codigo, 'apelido': _meuApelido});",
    para:
      "      _bruto({'tipo': 'entrarMesa', 'codigo': codigo, 'apelido': _meuApelido, 'assento': 0});",
  },

  // --- §16.24 — o anúncio da recusa ---------------------------------------
  {
    id: 'I19',
    nome: 'a linha de estado deixa de ser região viva (recusa muda)',
    arquivo: 'lib/screens/escolha_assento_screen.dart',
    de: '      liveRegion: true,\n      label: texto,',
    para: '      label: texto,',
  },
  {
    id: 'I20',
    nome: 'o ingresso confirmado deixa de ser anunciado',
    arquivo: 'lib/screens/escolha_assento_screen.dart',
    de: '    if (fase == FaseDoIngresso.confirmado && c != null) return c.anuncio;',
    para: '    if (false) return null;',
  },

  // --- §16.25 — o alvo de 48 dp -------------------------------------------
  {
    id: 'I21',
    nome: 'o piso de toque da cadeira cai para 30 dp',
    arquivo: 'lib/screens/escolha_assento_screen.dart',
    de: '      constraints: const BoxConstraints(minHeight: _alvoMinimo),\n      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),',
    para: '      constraints: const BoxConstraints(minHeight: 30),\n      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),',
  },
  {
    id: 'I22',
    nome: 'a cadeira perde a AÇÃO de toque (inerte para o leitor de tela)',
    arquivo: 'lib/screens/escolha_assento_screen.dart',
    de:
      '      button: true,\n' +
      '      enabled: true,\n' +
      '      selected: false,\n' +
      '      label: fraseDoAssento(m, a),\n' +
      '      child: Material(',
    para:
      '      button: true,\n' +
      '      enabled: true,\n' +
      '      selected: false,\n' +
      '      label: fraseDoAssento(m, a),\n' +
      '      excludeSemantics: true,\n' +
      '      child: Material(',
  },
  {
    id: 'I23',
    nome: 'a cadeira OCUPADA passa a ser escolhível',
    arquivo: 'lib/screens/escolha_assento_screen.dart',
    de: '    final escolhivel = !a.ocupado && m.ingressavel && !emVoo && escolher != null;',
    para: '    final escolhivel = m.ingressavel && !emVoo && escolher != null;',
  },
  {
    id: 'I24',
    nome: 'a cadeira PEDIDA é desenhada como OCUPADA antes do ACK',
    arquivo: 'lib/screens/escolha_assento_screen.dart',
    de: '    final livre = !a.ocupado;\n    final rotulo = livre\n        ? \'Livre\'',
    para: '    final livre = !a.ocupado && !selecionado;\n    final rotulo = livre\n        ? \'Livre\'',
  },
  {
    id: 'I25',
    nome: 'a mesa NÃO ingressável passa a ser clicável no Lobby',
    arquivo: 'lib/screens/lobby_publico_screen.dart',
    de: '    final tocavel = escolher != null && m.ingressavel;',
    para: '    final tocavel = escolher != null;',
  },

  // --- §16.27 · §16.28 · §16.29 — registro, execução e agregador ----------
  {
    id: 'I26',
    // A âncora inclui a linha ANTERIOR porque `ingrtransp` também aparece no
    // comentário que explica o gate — e âncora ambígua para a campanha antes
    // de ela medir qualquer coisa.
    nome: 'o gate `ingrtransp` sai da FONTE ÚNICA (a suíte deixa de rodar)',
    arquivo: '../scripts/ci/gates_os_integracao.txt',
    de: 'ingrassento\ningrtransp',
    para: 'ingrassento\n#ingrtransp',
  },
  {
    id: 'I27',
    nome: 'o passo que EXECUTA `ingrnav` some do workflow',
    arquivo: '../.github/workflows/ci-os-integracao.yml',
    de: '          roda ingrnav      test/ingresso/navegacao_ingresso_test.dart',
    para: '          # roda ingrnav      test/ingresso/navegacao_ingresso_test.dart',
  },

  // --- §4 — a proveniência do servidor ------------------------------------
  {
    id: 'I28',
    nome: 'o contrato passa a apontar para OUTRO servidor',
    arquivo: 'lib/ingresso/contrato_ingresso.dart',
    de: "  static const shaDoServidor = '8a0ee4b76ac915705e2e1a37237666a4aab41c39';",
    para: "  static const shaDoServidor = '13ea6f1df29681ec709a32d91391564d4bb3d491';",
  },
  {
    id: 'I29',
    nome: 'o limite superior do assento some (assento 9 passa a ser pedido)',
    arquivo: 'lib/ingresso/contrato_ingresso.dart',
    de: '      v is int && v >= assentoMinimo && v <= assentoMaximo;',
    para: '      v is int && v >= assentoMinimo;',
  },
];

// ---------------------------------------------------------------------------
// mecânica
// ---------------------------------------------------------------------------

const paraLf = (s) => s.split('\r\n').join('\n');

function lerNormalizado(caminho) {
  const bruto = fs.readFileSync(caminho, 'utf8');
  return { bruto, crlf: bruto.includes('\r\n'), texto: paraLf(bruto) };
}

function escrever(caminho, texto, crlf) {
  fs.writeFileSync(caminho, crlf ? texto.split('\n').join('\r\n') : texto, 'utf8');
}

/** Roda a bateria inteira, em série. Devolve `true` se TUDO passou.
 *
 *  EM SÉRIE de propósito: `flutter test` sem argumento roda os arquivos em
 *  paralelo no mesmo `build/`, e duas execuções disputando
 *  `build/unit_test_assets` travam sem mensagem útil.
 *
 *  `stdio: ignore` na entrada porque o `flutter` é um `.bat` que lê stdin. */
function bateria() {
  for (const suite of SUITES) {
    const r = spawnSync('flutter', ['test', suite, '--reporter', 'compact'], {
      encoding: 'utf8',
      shell: true,
      stdio: ['ignore', 'pipe', 'pipe'],
      timeout: 1800000,
    });
    // TIMEOUT NÃO É DETECÇÃO, e não é escape: é medição perdida. `status`
    // nulo (morto por sinal) aborta a campanha em vez de virar número.
    if (r.status === null) {
      console.error(`BATERIA MORTA em ${suite} — sem veredito.`);
      process.exit(1);
    }
    if (r.status !== 0) return false;
  }
  return true;
}

function conferirAncoras() {
  let ruins = 0;
  for (const m of MUTACOES) {
    if (!fs.existsSync(m.arquivo)) {
      console.log(`  ${m.id} ARQUIVO AUSENTE: ${m.arquivo}`);
      ruins++;
      continue;
    }
    const n = lerNormalizado(m.arquivo).texto.split(paraLf(m.de)).length - 1;
    if (n !== 1) {
      console.log(`  ${m.id} ANCORAS=${n} em ${m.arquivo}`);
      ruins++;
    }
  }
  console.log(`ancoras conferidas: ${MUTACOES.length} | com problema: ${ruins}`);
  if (MUTACOES.length === 0) {
    console.error('NENHUMA MUTACAO CARREGADA — a campanha nao mede nada.');
    return false;
  }
  return ruins === 0;
}

// ---------------------------------------------------------------------------
// execução
// ---------------------------------------------------------------------------

if (process.argv.includes('--conferir')) {
  process.exit(conferirAncoras() ? 0 : 1);
}

console.log('conferindo âncoras antes de gastar bateria…');
if (!conferirAncoras()) process.exit(1);

console.log('\nverde de partida…');
if (!bateria()) {
  console.error('A ÁRVORE JÁ ESTÁ VERMELHA. Mutação não prova nada aqui.');
  process.exit(1);
}
console.log(`base verde · ${MUTACOES.length} mutações\n`);

const escaparam = [];
let pegas = 0;

for (const m of MUTACOES) {
  const antes = lerNormalizado(m.arquivo);
  const de = paraLf(m.de);
  const para = paraLf(m.para);
  const partes = antes.texto.split(de);
  if (partes.length !== 2) {
    console.error(`${m.id} ANCORA AMBIGUA/AUSENTE (${partes.length - 1})`);
    process.exit(1);
  }
  const mutado = partes[0] + para + partes[1];
  if (mutado === antes.texto) {
    console.error(`${m.id} NAO ALTEROU O ARQUIVO`);
    process.exit(1);
  }

  escrever(m.arquivo, mutado, antes.crlf);
  let sobreviveu;
  try {
    sobreviveu = bateria();
  } finally {
    fs.writeFileSync(m.arquivo, antes.bruto, 'utf8'); // reverte SEMPRE
  }

  if (sobreviveu) {
    escaparam.push(m);
    console.log(`ESCAPOU ${m.id}  ${m.nome}`);
  } else {
    pegas++;
    console.log(`PEGA    ${m.id}  ${m.nome}`);
  }
}

console.log('\nverde de chegada…');
if (!bateria()) {
  console.error('A REVERSÃO FALHOU: a árvore ficou vermelha.');
  process.exit(1);
}
console.log(`detectadas: ${pegas}/${MUTACOES.length}`);
for (const m of escaparam) console.log(`  ESCAPOU ${m.id}: ${m.nome}`);
process.exit(escaparam.length === 0 ? 0 : 1);
