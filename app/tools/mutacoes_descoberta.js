// mutacoes_descoberta.js — PROVAS NEGATIVAS da OS 38.2 (§15).
//
// ---------------------------------------------------------------------------
// O QUE ESTA CAMPANHA MEDE
// ---------------------------------------------------------------------------
//
// A §15 lista as maneiras de a entrega ficar errada em silêncio. Cada uma vira
// uma MUTAÇÃO: uma edição cirúrgica no código de produção que desfaz
// exatamente aquele invariante. Se a suíte continuar verde, a defesa não
// existe — existe a intenção dela, escrita num comentário.
//
// A bateria que julga são as cinco suítes da família 38.2 mais a suíte da
// Casca. Uma mutação pega por qualquer uma delas conta: o ponto não é quem
// acusa, é que a mutação MORRA.
//
// ---------------------------------------------------------------------------
// POR QUE EM NODE, E NÃO EM SHELL
// ---------------------------------------------------------------------------
//
// A primeira versão era `bash` chamando `node -e '...'`. Entre a heredoc, as
// aspas do shell e as escapes do JavaScript havia três camadas de citação sobre
// o mesmo texto, e cada correção quebrava outra coisa: âncora com quebra de
// linha chegando alterada ao processo, `\r\n` virando quebra de verdade dentro
// do fonte, e a campanha reportando "âncora ausente" para código que estava
// exatamente onde deveria. Um arquivo só, numa língua só, não tem camada
// nenhuma — e é o mesmo desenho das campanhas do `buraco-servidor`.
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
// Nesta árvore convivem arquivos em LF e em CRLF — o mesmo repositório,
// editado por ferramentas diferentes. A comparação é feita SEMPRE em LF, e a
// escrita devolve o fim de linha que o arquivo tinha. Reescrever tudo em LF
// mudaria o arquivo inteiro, e aí a reversão deixaria de ser reversão.
//
// Uso:  node tools/mutacoes_descoberta.js            (campanha completa)
//       node tools/mutacoes_descoberta.js --conferir (só as âncoras)

'use strict';

const fs = require('fs');
const path = require('path');
const { spawnSync } = require('child_process');

process.chdir(path.join(__dirname, '..'));

const SUITES = [
  'test/descoberta/contrato_e_adaptador_test.dart',
  'test/descoberta/estado_e_agente_test.dart',
  'test/descoberta/presenca_na_home_test.dart',
  'test/descoberta/apresentacao_stbl_test.dart',
  'test/descoberta/lobby_publico_test.dart',
  'test/casca/casca_producao_test.dart',
];

const MUTACOES = [
  // --- §3.1 — a presença nasce na Home -------------------------------------
  {
    id: 'M01',
    nome: 'a ponte deixa de conectar na construção (partida fria não conecta)',
    arquivo: 'lib/services/ponte_sessao_online.dart',
    de: '    // usou uma vez.\n    _talvezConectar();',
    para: '    // usou uma vez.',
  },
  {
    id: 'M02',
    nome: 'volta a exigir que o jogador tenha PEDIDO para conectar',
    arquivo: 'lib/services/ponte_sessao_online.dart',
    de:
      '    if (_descartada) return;\n' +
      '    if (!sessao.estado.autenticado) return;\n' +
      '    online.conectar();',
    para:
      '    if (_descartada) return;\n' +
      '    if (!sessao.estado.autenticado) return;\n' +
      '    if (!online.querConectado) return;\n' +
      '    online.conectar();',
  },
  {
    id: 'M03',
    nome: 'o ritmo da descoberta nunca começa',
    arquivo: 'lib/services/online_service.dart',
    de: '    _agenteDaDescoberta.iniciar();',
    para: '    // _agenteDaDescoberta.iniciar();',
  },

  // --- §7 — geração e revisão ----------------------------------------------
  {
    id: 'M04',
    nome: 'revisão IGUAL passa a ser aceita (retrato atrasado entra)',
    arquivo: 'lib/descoberta/estado_descoberta.dart',
    de: '      if (novo.revisao <= atual.revisao) {',
    para: '      if (novo.revisao < atual.revisao) {',
  },
  {
    id: 'M05',
    nome: 'revisões de GERAÇÕES diferentes passam a ser comparadas',
    arquivo: 'lib/descoberta/estado_descoberta.dart',
    de: '    if (atual != null && atual.geracao == novo.geracao) {',
    para: '    if (atual != null) {',
  },
  {
    id: 'M06',
    nome: 'resposta de transporte anterior passa a valer',
    arquivo: 'lib/descoberta/estado_descoberta.dart',
    de: '    if (geracaoDeTransporte != _geracaoDeTransporte) {',
    para: '    if (false) {',
  },
  {
    id: 'M07',
    nome: 'o retrato SOBREVIVE ao logout (vaza para a conta seguinte)',
    arquivo: 'lib/services/online_service.dart',
    de: '    descoberta.encerrarSessao();\n    desligar(); // sobe',
    para: '    desligar(); // sobe',
  },

  // --- §6.2 — as duas projeções não se tocam -------------------------------
  {
    id: 'M08',
    nome: 'a lista de mesas passa a sobrescrever a visão da MESA',
    arquivo: 'lib/services/online_service.dart',
    de:
      '        descoberta.aplicar(msg, geracaoDeTransporte: _geracaoTransporte);\n' +
      '        notifyListeners();',
    para:
      '        descoberta.aplicar(msg, geracaoDeTransporte: _geracaoTransporte);\n' +
      "        visao = <String, dynamic>{'lobby': true};\n" +
      '        notifyListeners();',
  },

  // --- §9 — o número da Home -----------------------------------------------
  {
    id: 'M09',
    nome: 'o banner aparece mesmo sem número (desconhecido vira banner)',
    arquivo: 'lib/casca/home_de_producao.dart',
    de:
      '      lobby: jogadoresOnline == null\n' +
      '          ? null\n' +
      '          : LobbyBanner(\n' +
      "              titulo: 'Lobby Público',",
    para: "      lobby: LobbyBanner(\n              titulo: 'Lobby Público',",
  },
  {
    id: 'M10',
    // A primeira versão desta mutação mirava `home_de_producao.dart`
    // (`online: jogadoresOnline ?? 0`) e ESCAPOU — não por falta de defesa,
    // mas porque a guarda ANTERIOR (`lobby: null`) já impedia o cartão de
    // existir, e o `?? 0` virava código morto sob aquele host. Mutação
    // inalcançável não mede nada, por mais que mude bytes.
    //
    // A camada VISUAL é onde a defesa precisa existir por si: ela é usada por
    // outros hosts e pelo catálogo. É lá que a mutação agora bate, e é lá que
    // o caso HM-11b a espera.
    nome: 'DESCONHECIDO vira ZERO na tela',
    arquivo: 'lib/screens/inicio_screen.dart',
    de:
      '                          if (lobby.online != null) ...[\n' +
      "                            const TextSpan(text: '🟢 '),\n" +
      '                            TextSpan(text: textoDePresenca(lobby.online!)),',
    para:
      '                          if (true) ...[\n' +
      "                            const TextSpan(text: '🟢 '),\n" +
      '                            TextSpan(text: textoDePresenca(lobby.online ?? 0)),',
  },
  {
    id: 'M10b',
    // E o host continua com mutação própria: as duas guardas são
    // independentes, e cada uma precisa do seu caso.
    nome: 'DESCONHECIDO vira ZERO no host da Home',
    arquivo: 'lib/casca/home_de_producao.dart',
    de:
      '      lobby: jogadoresOnline == null\n' +
      '          ? null\n' +
      '          : LobbyBanner(\n' +
      "              titulo: 'Lobby Público',\n" +
      "              subtitulo: 'veja as mesas abertas agora',\n" +
      '              online: jogadoresOnline,',
    para:
      '      lobby: LobbyBanner(\n' +
      "              titulo: 'Lobby Público',\n" +
      "              subtitulo: 'veja as mesas abertas agora',\n" +
      '              online: jogadoresOnline ?? 0,',
  },
  {
    id: 'M11',
    nome: 'o total passa a ser a SOMA das modalidades',
    arquivo: 'lib/casca/home_de_producao.dart',
    de: '    final jogadoresOnline = online?.descoberta.jogadoresOnlineTotal;',
    para:
      '    final p = online?.descoberta.retrato?.presenca;\n' +
      '    final jogadoresOnline = p == null\n' +
      '        ? null\n' +
      '        : ModalidadeDeMesa.values\n' +
      '              .map((m) => p.de(m).jogadores)\n' +
      '              .fold<int>(0, (a, b) => a + b);',
  },

  // --- §3.2 — a apresentação de STBL ---------------------------------------
  {
    id: 'M12',
    nome: 'STBL vira Sbtl',
    arquivo: 'lib/descoberta/modelo_descoberta.dart',
    de: "  sbtl('sbtl', 'STBL');",
    para: "  sbtl('sbtl', 'Sbtl');",
  },
  {
    id: 'M13',
    nome: 'o rótulo passa a ser a CHAVE CRUA',
    arquivo: 'lib/descoberta/modelo_descoberta.dart',
    de: "  sbtl('sbtl', 'STBL');",
    para: "  sbtl('sbtl', 'sbtl');",
  },
  {
    id: 'M14',
    nome: 'o filtro passa a exibir a chave em vez do rótulo',
    arquivo: 'lib/screens/lobby_publico_screen.dart',
    de: '  String get rotulo => modalidade?.rotulo ?? _rotuloLiteral;',
    para: '  String get rotulo => modalidade?.chave ?? _rotuloLiteral;',
  },

  // --- §11.1 — a ordem é do servidor ---------------------------------------
  {
    id: 'M15',
    nome: 'o cliente REORDENA a lista por vagas',
    arquivo: 'lib/screens/lobby_publico_screen.dart',
    de: '    final visiveis = retrato.mesas.where(_filtro.aceita).toList();',
    para:
      '    final visiveis = retrato.mesas.where(_filtro.aceita).toList()\n' +
      '      ..sort((a, b) => b.vagas.compareTo(a.vagas));',
  },

  // --- §11.2 — as contagens são do servidor --------------------------------
  {
    id: 'M16',
    nome: 'a contagem do filtro passa a ser calculada da LISTA',
    arquivo: 'lib/screens/lobby_publico_screen.dart',
    de: '      _ => p.de(f.modalidade!).mesas,',
    para:
      '      _ => widget.retrato!.mesas\n' +
      '          .where((m) => m.modalidade == f.modalidade)\n' +
      '          .length,',
  },

  // --- §6.3 — a fronteira fail-closed --------------------------------------
  {
    id: 'M17',
    nome: 'a varredura de chave proibida some (uid atravessa)',
    arquivo: 'lib/descoberta/adaptador_descoberta.dart',
    de: '    _exigirSemChaveProibida(raiz);',
    para: '    // _exigirSemChaveProibida(raiz);',
  },
  {
    id: 'M18',
    nome: 'campo desconhecido passa a ser tolerado',
    arquivo: 'lib/descoberta/adaptador_descoberta.dart',
    de:
      '    for (final k in m.keys) {\n' +
      '      if (!esperadas.contains(k)) _recusar(RecusaDeRetrato.campoDesconhecido);\n' +
      '    }',
    para: '    // campo desconhecido tolerado',
  },
  {
    id: 'M19',
    nome: 'número negativo passa a ser aceito',
    arquivo: 'lib/descoberta/adaptador_descoberta.dart',
    de:
      '    final v = _inteiro(m, campo);\n' +
      '    if (v < 0) _recusar(RecusaDeRetrato.numeroNegativo);\n' +
      '    return v;',
    para: '    return _inteiro(m, campo);',
  },

  // --- §11.3 — ingresso não pertence a esta OS -----------------------------
  {
    id: 'M20',
    nome: 'o Lobby passa a EXECUTAR ingresso',
    arquivo: 'lib/casca/lobby_publico_de_producao.dart',
    de: '      onEscolherMesa: null,',
    para:
      '      onEscolherMesa: (codigo) =>\n' +
      "          online.entrarMesa(codigo: codigo, apelido: 'Jogador'),",
  },

  // --- §13 — acessibilidade -------------------------------------------------
  {
    id: 'M21',
    nome: 'o Voltar perde o nome',
    arquivo: 'lib/screens/lobby_publico_screen.dart',
    de: "            tooltip: 'Voltar',",
    para: '            tooltip: null,',
  },
  {
    id: 'M22',
    nome: 'o filtro perde PAPEL e ESTADO de seleção',
    arquivo: 'lib/screens/lobby_publico_screen.dart',
    de:
      '      child: Semantics(\n' +
      '        button: true,\n' +
      '        selected: selecionado,\n' +
      '        label: rotulo,',
    para: '      child: Semantics(\n        label: rotulo,',
  },
  {
    id: 'M23',
    nome: 'o piso de toque do filtro cai para 30 dp',
    arquivo: 'lib/screens/lobby_publico_screen.dart',
    de: '              constraints: const BoxConstraints(minHeight: _alvoMinimo),',
    para: '              constraints: const BoxConstraints(minHeight: 30),',
  },
  {
    id: 'M24',
    nome: 'o filtro perde a AÇÃO de toque (inerte para o leitor de tela)',
    arquivo: 'lib/screens/lobby_publico_screen.dart',
    de:
      '      child: Semantics(\n' +
      '        button: true,\n' +
      '        selected: selecionado,\n' +
      '        label: rotulo,\n' +
      '        child: Material(',
    para:
      '      child: Semantics(\n' +
      '        button: true,\n' +
      '        selected: selecionado,\n' +
      '        label: rotulo,\n' +
      '        excludeSemantics: true,\n' +
      '        child: Material(',
  },

  // --- §15 — a suíte obrigatória não pode ser desregistrada ----------------
  {
    id: 'M25',
    // A âncora inclui a linha ANTERIOR porque a palavra `deschome` também
    // aparece no comentário que explica o gate — e âncora ambígua para a
    // campanha antes de ela medir qualquer coisa.
    nome: 'o gate `deschome` sai da fonte única (a suíte deixa de rodar no CI)',
    arquivo: '../scripts/ci/gates_os_integracao.txt',
    de: 'descestado\ndeschome',
    para: 'descestado\n#deschome',
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
      timeout: 600000,
    });
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
