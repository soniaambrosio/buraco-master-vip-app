'use strict';
/**
 * PROVAS DO §16 — proveniência de SHA das Functions.
 *
 * A maior parte roda contra um REPOSITÓRIO DE CAIXA DE AREIA construído aqui
 * mesmo, e não contra o repositório real. Sem isso não haveria como provar as
 * recusas que importam: árvore suja, SHA de outro commit, arquivo editado à
 * mão, codebase sem carimbo. Um teste que só verifica o caminho feliz sobre a
 * própria árvore não distingue "o mecanismo funciona" de "hoje está tudo igual".
 *
 * PROV-11 e PROV-12 rodam contra a árvore REAL: são elas que amarram o
 * mecanismo às nove codebases desta composição.
 */

const { test, describe, before, after } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const P = require('./proveniencia.js');
const { AMBIENTE_PROIBIDO } = require('./gerar.js');

const GERAR = path.join(__dirname, 'gerar.js');
const VERIFICAR = path.join(__dirname, 'verificar.js');
const RAIZ_REAL = P.RAIZ;

// ---------------------------------------------------------------------------
// Caixa de areia
// ---------------------------------------------------------------------------

let caixa;

function git(args, cwd) {
  const r = spawnSync('git', args, { cwd: cwd || caixa, encoding: 'utf8', shell: false });
  if (r.status !== 0) throw new Error('git ' + args.join(' ') + ' falhou: ' + r.stderr);
  return (r.stdout || '').trim();
}

/** Roda um dos CLIs contra a caixa. `env` extra é mesclado ao ambiente. */
function rodar(script, opcoes) {
  const { raiz = caixa, env = {} } = opcoes || {};
  const limpo = Object.assign({}, process.env);
  // O ambiente do CI real pode ter `GITHUB_SHA` definida; a caixa parte de um
  // ambiente SEM nenhuma das proibidas, para que só o que o caso injeta conte.
  for (const k of AMBIENTE_PROIBIDO) delete limpo[k];
  const r = spawnSync(process.execPath, [script, '--raiz', raiz], {
    cwd: raiz,
    encoding: 'utf8',
    shell: false,
    env: Object.assign(limpo, env),
  });
  return { status: r.status, saida: (r.stdout || '') + (r.stderr || '') };
}

const SOURCES = ['fx-a', 'fx-b'];

function manifesto(sources) {
  const lista = (sources || SOURCES).map((s) => ({
    codebase: s.replace('fx-', 'cb'),
    source: s,
  }));
  return JSON.stringify({ functions: lista }, null, 2);
}

before(() => {
  caixa = fs.mkdtempSync(path.join(os.tmpdir(), 'prov-'));
  git(['init', '-q', '-b', 'principal']);
  git(['config', 'user.email', 'caixa@exemplo.invalido']);
  git(['config', 'user.name', 'Caixa De Areia']);
  for (const s of SOURCES) {
    fs.mkdirSync(path.join(caixa, s));
    fs.writeFileSync(path.join(caixa, s, 'index.js'), '// codigo\n');
  }
  fs.writeFileSync(path.join(caixa, 'firebase.json'), manifesto());
  fs.writeFileSync(path.join(caixa, '.gitignore'), 'proveniencia.json\n');
  git(['add', '-A']);
  git(['commit', '-q', '-m', 'base']);
});

after(() => {
  try {
    fs.rmSync(caixa, { recursive: true, force: true });
  } catch (e) {
    /* a caixa é temporária: não falhar a suíte por causa da faxina */
  }
});

/** Devolve a caixa ao estado limpo entre casos. */
function limpar() {
  for (const s of SOURCES) {
    const p = path.join(caixa, s, P.NOME_DO_ARQUIVO);
    if (fs.existsSync(p)) fs.unlinkSync(p);
  }
  fs.writeFileSync(path.join(caixa, 'firebase.json'), manifesto());
  git(['checkout', '-q', '--', '.']);
}

// ---------------------------------------------------------------------------

describe('§16 — proveniencia: o caminho que deve funcionar', () => {
  test('PROV-01 gera para TODAS as codebases do manifesto, com o SHA de HEAD', () => {
    limpar();
    const g = rodar(GERAR);
    assert.equal(g.status, 0, g.saida);

    const sha = git(['rev-parse', 'HEAD']);
    for (const s of SOURCES) {
      const doc = JSON.parse(fs.readFileSync(path.join(caixa, s, P.NOME_DO_ARQUIVO), 'utf8'));
      assert.equal(doc.sha, sha, s + ' tem de carregar o SHA de HEAD');
      assert.equal(doc.source, s);
    }
    assert.equal(rodar(VERIFICAR).status, 0);
  });

  test('PROV-02 o conteudo e deterministico — mesma entrada, mesmos bytes', () => {
    limpar();
    rodar(GERAR);
    const antes = SOURCES.map((s) => fs.readFileSync(path.join(caixa, s, P.NOME_DO_ARQUIVO)));
    rodar(GERAR);
    const depois = SOURCES.map((s) => fs.readFileSync(path.join(caixa, s, P.NOME_DO_ARQUIVO)));
    // Sem carimbo de tempo, sem maquina, sem usuario. É esta pureza que permite
    // verificar por RE-RENDERIZAÇÃO em vez de por conferencia de campos — e é a
    // re-renderizacao que fecha a porta do valor manual.
    assert.deepEqual(depois, antes);
  });

  test('PROV-03 nao vaza segredo: so SHA publico, codebase e caminho', () => {
    limpar();
    rodar(GERAR);
    for (const s of SOURCES) {
      const bruto = fs.readFileSync(path.join(caixa, s, P.NOME_DO_ARQUIVO), 'utf8');
      const doc = JSON.parse(bruto);
      assert.deepEqual(
        Object.keys(doc).sort(),
        ['_aviso', 'codebase', 'gerador', 'origemDoValor', 'sha', 'source'],
        'campo novo exige revisao: proveniencia nao carrega dado de ambiente'
      );
      for (const suspeito of ['key', 'token', 'secret', 'senha', 'password', 'private']) {
        assert.ok(!bruto.toLowerCase().includes(suspeito), 'contem "' + suspeito + '"');
      }
    }
  });
});

describe('§16 — proveniencia: as recusas', () => {
  test('PROV-04 arvore SUJA reprova a geracao', () => {
    limpar();
    fs.writeFileSync(path.join(caixa, SOURCES[0], 'index.js'), '// alterado sem commit\n');
    const g = rodar(GERAR);
    assert.equal(g.status, 1, 'carimbar sobre arvore suja e mentir sobre o artefato');
    assert.match(g.saida, /nao commitada/);
    git(['checkout', '-q', '--', '.']);
  });

  test('PROV-05 codebase SEM carimbo reprova a verificacao', () => {
    limpar();
    rodar(GERAR);
    fs.unlinkSync(path.join(caixa, SOURCES[1], P.NOME_DO_ARQUIVO));
    const v = rodar(VERIFICAR);
    assert.equal(v.status, 1, 'ausencia nao e "nada a verificar"');
    assert.match(v.saida, /SEM proveniencia/);
  });

  test('PROV-06 SHA de OUTRO commit reprova, ainda que bem formado', () => {
    limpar();
    rodar(GERAR);
    const alvo = path.join(caixa, SOURCES[0], P.NOME_DO_ARQUIVO);
    const doc = JSON.parse(fs.readFileSync(alvo, 'utf8'));
    doc.sha = 'a'.repeat(40); // 40 hex, plausivel, e falso
    fs.writeFileSync(alvo, JSON.stringify(doc, null, 2) + '\n');
    const v = rodar(VERIFICAR);
    assert.equal(v.status, 1);
    assert.match(v.saida, /carimbado com aaaaaaa/);
  });

  test('PROV-07 valor manual nao entra: nem por argumento, nem por ambiente', () => {
    limpar();
    // (a) POR ARGUMENTO — nao existe flag que carregue valor, e flag
    //     desconhecida reprova em vez de ser tolerada.
    const porArg = spawnSync(process.execPath, [GERAR, '--raiz', caixa, '--sha', 'b'.repeat(40)], {
      cwd: caixa,
      encoding: 'utf8',
      shell: false,
    });
    assert.notEqual(porArg.status, 0, 'nenhuma flag pode informar o SHA');
    assert.match((porArg.stdout || '') + (porArg.stderr || ''), /argumento nao aceito/);

    // (b) POR AMBIENTE — o gerador RECUSA rodar com elas presentes, em vez de
    //     ignora-las em silencio: ignorar deixaria alguem concluir que leu.
    for (const chave of ['PROVENIENCIA_SHA', 'GITHUB_SHA', 'GIT_SHA']) {
      const r = rodar(GERAR, { env: { [chave]: 'c'.repeat(40) } });
      assert.equal(r.status, 1, chave + ' tinha de reprovar');
      assert.match(r.saida, /variavel/);
    }
  });

  test('PROV-08 edicao a mao com o SHA CERTO ainda reprova', () => {
    limpar();
    rodar(GERAR);
    const alvo = path.join(caixa, SOURCES[0], P.NOME_DO_ARQUIVO);
    const doc = JSON.parse(fs.readFileSync(alvo, 'utf8'));
    doc.observacao = 'implantado a mao, confia';
    fs.writeFileSync(alvo, JSON.stringify(doc, null, 2) + '\n');
    // O SHA continua CORRETO. A comparacao e de BYTES, e nao de campos — e por
    // isso o campo inventado nao passa.
    const v = rodar(VERIFICAR);
    assert.equal(v.status, 1);
    assert.match(v.saida, /editado a mao/);
  });

  test('PROV-09 codebases com SHAs DIFERENTES entre si reprovam', () => {
    limpar();
    rodar(GERAR);
    const shaVelho = git(['rev-parse', 'HEAD']);
    fs.writeFileSync(path.join(caixa, SOURCES[0], 'index.js'), '// avancou\n');
    git(['add', '-A']);
    git(['commit', '-q', '-m', 'avanca']);
    // Regera SO a primeira: `fx-a` fica no commit novo e `fx-b` no velho. É
    // EXATAMENTE o defeito que motiva o §16 — nove deploys separados podendo
    // carregar nove codigos diferentes, sem ninguem perceber.
    const shaNovo = git(['rev-parse', 'HEAD']);
    assert.notEqual(shaVelho, shaNovo);
    fs.writeFileSync(
      path.join(caixa, 'fx-a', P.NOME_DO_ARQUIVO),
      P.conteudo({ sha: shaNovo, codebase: 'cba', source: 'fx-a' })
    );

    const v = rodar(VERIFICAR);
    assert.equal(v.status, 1);
    // `fx-b` ficou para tras, e reprova pelo carimbo velho.
    assert.match(v.saida, /cbb: carimbado com/);
  });

  test('PROV-10 carimbo SOBRANDO, de pasta fora do manifesto, reprova', () => {
    limpar();
    rodar(GERAR);
    // `fx-b` sai do manifesto e fica com o carimbo.
    fs.writeFileSync(path.join(caixa, 'firebase.json'), manifesto(['fx-a']));
    const v = rodar(VERIFICAR);
    assert.equal(v.status, 1, 'pasta que saiu do deploy nao segue parecendo provada');
    assert.match(v.saida, /SOBRANDO/);
    limpar();
  });
});

describe('§16 — a arvore REAL desta composicao', () => {
  test('PROV-11 a relacao de codebases sai de firebase.json, e sao as 9', () => {
    const lista = P.codebases(RAIZ_REAL);
    assert.equal(lista.length, 9, 'as nove codebases implantaveis da composicao');
    assert.deepEqual(lista.map((c) => c.codebase), [
      'billing',
      'colecoes',
      'conta',
      'economia',
      'mesas',
      'moderacao',
      'ranking',
      'social',
      'torneios',
    ]);
    // A relacao NAO pode estar escrita no modulo: se estivesse, uma codebase
    // nova poderia ser implantada sem proveniencia — o defeito CI-02 de novo,
    // agora na versao "a lista do deploy e a lista da prova divergiram".
    const fonte = fs.readFileSync(path.join(__dirname, 'proveniencia.js'), 'utf8');
    for (const c of lista) {
      assert.ok(
        !fonte.includes("'" + c.codebase + "'") && !fonte.includes('"' + c.codebase + '"'),
        'o modulo NAO pode conter a codebase ' + c.codebase + ' escrita a mao'
      );
    }
  });

  test('PROV-13 o predeploy de TODA codebase carrega os dois passos, na frente', () => {
    // Sem isto o mecanismo inteiro vira OPCIONAL: bastaria alguem tirar os dois
    // passos do `predeploy` para voltar a implantar sem carimbo, e nenhuma
    // outra prova reclamaria. Eles tem de ser os PRIMEIROS — carimbar depois do
    // build ainda daria o valor certo, mas verificar depois do deploy nao
    // verificaria coisa nenhuma.
    const real = JSON.parse(fs.readFileSync(path.join(RAIZ_REAL, 'firebase.json'), 'utf8'));
    for (const e of real.functions) {
      const passos = e.predeploy || [];
      assert.deepEqual(
        passos.slice(0, 2),
        ['node ferramentas/proveniencia/gerar.js', 'node ferramentas/proveniencia/verificar.js'],
        e.codebase + ': o deploy tem de passar pela proveniencia antes de qualquer coisa'
      );
    }
  });

  test('PROV-12 toda source existe, e nenhum `ignore` exclui o carimbo', () => {
    const real = JSON.parse(fs.readFileSync(path.join(RAIZ_REAL, 'firebase.json'), 'utf8'));
    for (const e of real.functions) {
      assert.ok(fs.existsSync(path.join(RAIZ_REAL, e.source)), 'source ' + e.source + ' nao existe');
      // Se o `ignore` do deploy excluisse o arquivo, ele seria gerado, seria
      // verificado, e NAO subiria — a prova valeria exatamente zero.
      for (const padrao of e.ignore || []) {
        assert.notEqual(padrao, P.NOME_DO_ARQUIVO);
        assert.notEqual(padrao, '*.json');
        assert.notEqual(padrao, '**/*.json');
      }
    }
  });
});
