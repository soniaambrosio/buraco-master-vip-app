// auditoria.test.js — os SETE defeitos de §15, um fixture por defeito.
//
// OS de integracao Identidade Publica x Ranking v1, secoes 15, 16 e 17.
//
// Roda sobre `lib/auditoria.js` JA COMPILADO, como chaves.test.js: o alvo do
// teste e o que vai para producao. Nao precisa de emulador — o modulo e puro de
// proposito, e essa pureza e ela propria uma garantia de §15 ("a primeira
// execucao deve ser obrigatoriamente dry-run/read-only"): um modulo sem acesso
// ao banco nao tem como deixar de ser dry-run.
//
// O ULTIMO BLOCO NAO TESTA CLASSIFICACAO: ele le o RUNNER e prova que nao ha
// verbo de escrita nele. E a metade da garantia que a pureza do modulo nao
// cobre, porque o runner e quem toca o Firestore.

'use strict';

const assert = require('node:assert/strict');
const { test, describe } = require('node:test');
const fs = require('node:fs');
const path = require('node:path');

const { auditar, relatorioComoTexto } = require('../lib/auditoria');

const VAZIO = {
  identidades: [],
  reversos: [],
  perfis: [],
  projecoes: [],
  uidsConhecidos: [],
};

/// Um inventario integro: um jogador, com os tres documentos e a projecao
/// competitiva coerente. Cada teste abaixo estraga UMA coisa a partir daqui.
const SADIO = {
  identidades: [{ uid: 'u1', publicId: 'P0123456789AB' }],
  reversos: [{ publicId: 'P0123456789AB', uid: 'u1' }],
  perfis: [{ publicId: 'P0123456789AB' }],
  projecoes: [
    {
      colecao: 'rankingPlayers',
      documentoId: 'u1',
      uid: 'u1',
      publicPlayerId: 'P0123456789AB',
    },
  ],
  uidsConhecidos: ['u1'],
};

const tipos = (r) => r.achados.map((a) => a.tipo).sort();

describe('auditoria: o caso integro', () => {
  test('inventario vazio nao inventa achado', () => {
    const r = auditar(VAZIO);
    assert.equal(r.integro, true);
    assert.equal(r.achados.length, 0);
    assert.equal(r.criticos, 0);
  });

  test('as duas linhas convergindo produzem ZERO achados', () => {
    // E o estado que a OS quer ao fim da consolidacao: um jogador, um id, e a
    // projecao competitiva concordando com o canonico.
    const r = auditar(SADIO);
    assert.equal(r.integro, true, JSON.stringify(r.achados, null, 2));
  });

  test('o relatorio conta o que conferiu, e nao so o que achou', () => {
    // Auditoria que so diz "nada encontrado" e indistinguivel de auditoria que
    // nao rodou.
    const r = auditar(SADIO);
    assert.deepEqual(r.conferidos, {
      identidades: 1,
      reversos: 1,
      perfis: 1,
      projecoes: 1,
      uidsConhecidos: 1,
    });
    assert.match(relatorioComoTexto(r), /NENHUM ACHADO/);
    assert.match(relatorioComoTexto(r), /DRY-RUN \(nada foi alterado\)/);
  });
});

describe('auditoria: §15.1 — UID sem identidade publica', () => {
  test('um jogador conhecido e sem identidade e reportado', () => {
    const r = auditar({ ...SADIO, uidsConhecidos: ['u1', 'u2'] });
    assert.deepEqual(tipos(r), ['uid_sem_identidade']);
    assert.equal(r.achados[0].chave, 'u2');
    assert.equal(r.achados[0].severidade, 'reconciliavel');
    assert.match(r.achados[0].reconciliacao, /garantirIdentidade/);
    // §8: nunca derivar do uid. A reconciliacao TEM que dizer isso, porque e
    // exatamente o atalho que alguem tomaria.
    assert.match(r.achados[0].reconciliacao, /nao derivar do uid/i);
  });

  test('identidade com publicId vazio conta como ausente', () => {
    // String vazia e o defeito que §8 nomeia. Se a auditoria a aceitasse como
    // identidade, o unico caso em que ela precisa gritar seria o unico em que
    // ela ficaria calada.
    const r = auditar({
      ...VAZIO,
      identidades: [{ uid: 'u1', publicId: '' }],
      uidsConhecidos: ['u1'],
    });
    assert.deepEqual(tipos(r), ['uid_sem_identidade']);
  });
});

describe('auditoria: §15.2 — UID com mais de um publicId', () => {
  test('dois ids historicos para o mesmo jogador sao CRITICOS', () => {
    const r = auditar({
      ...SADIO,
      reversos: [
        { publicId: 'P0123456789AB', uid: 'u1' },
        { publicId: 'PANTIGO00001', uid: 'u1' },
      ],
      perfis: [{ publicId: 'P0123456789AB' }, { publicId: 'PANTIGO00001' }],
    });
    const achado = r.achados.find((a) => a.tipo === 'uid_com_dois_ids');
    assert.ok(achado, 'o conflito de dois ids nao foi detectado');
    assert.equal(achado.severidade, 'critico');
    assert.equal(r.criticos >= 1, true);
  });

  test('§16.4 — o relatorio proibe escolher pelo mais recente', () => {
    // A OS e literal nesse ponto, e a auditoria e o unico lugar onde essa
    // instrucao chega a quem for reconciliar.
    const r = auditar({
      ...SADIO,
      reversos: [
        { publicId: 'P0123456789AB', uid: 'u1' },
        { publicId: 'PANTIGO00001', uid: 'u1' },
      ],
      perfis: [{ publicId: 'P0123456789AB' }, { publicId: 'PANTIGO00001' }],
    });
    const achado = r.achados.find((a) => a.tipo === 'uid_com_dois_ids');
    assert.match(achado.reconciliacao, /mais recente/);
    assert.match(achado.detalhe, /PANTIGO00001/);
    assert.match(achado.detalhe, /P0123456789AB/);
  });
});

describe('auditoria: §15.3 — mesmo publicId em UIDs diferentes', () => {
  test('duas pessoas com a mesma identidade publica sao CRITICO', () => {
    const r = auditar({
      ...VAZIO,
      identidades: [
        { uid: 'u1', publicId: 'PCOLIDIDO0001' },
        { uid: 'u2', publicId: 'PCOLIDIDO0001' },
      ],
      perfis: [{ publicId: 'PCOLIDIDO0001' }],
      uidsConhecidos: ['u1', 'u2'],
    });
    const achado = r.achados.find((a) => a.tipo === 'id_compartilhado');
    assert.ok(achado);
    assert.equal(achado.severidade, 'critico');
    assert.equal(achado.chave, 'PCOLIDIDO0001');
    assert.match(achado.detalhe, /u1/);
    assert.match(achado.detalhe, /u2/);
  });

  test('§16.5 — nao sobrescrever automaticamente um jogador com o outro', () => {
    const r = auditar({
      ...VAZIO,
      identidades: [
        { uid: 'u1', publicId: 'PCOLIDIDO0001' },
        { uid: 'u2', publicId: 'PCOLIDIDO0001' },
      ],
      uidsConhecidos: ['u1', 'u2'],
    });
    const achado = r.achados.find((a) => a.tipo === 'id_compartilhado');
    assert.match(achado.reconciliacao, /Nao sobrescrever/i);
    assert.match(achado.reconciliacao, /decisao humana/i);
    // §17: reconciliar identidade nunca mexe em historico competitivo.
    assert.match(achado.reconciliacao, /historico competitivo/i);
  });

  test('a colisao e vista mesmo quando so o indice reverso a mostra', () => {
    const r = auditar({
      ...VAZIO,
      reversos: [
        { publicId: 'PCOLIDIDO0001', uid: 'u1' },
        { publicId: 'PCOLIDIDO0001', uid: 'u2' },
      ],
    });
    assert.ok(r.achados.some((a) => a.tipo === 'id_compartilhado'));
  });
});

describe('auditoria: §15.4 — projecao apontando para id inexistente', () => {
  test('ranking com id que nao existe em lugar nenhum', () => {
    const r = auditar({
      ...SADIO,
      projecoes: [
        {
          colecao: 'rankingStandings',
          documentoId: '2026-A|u1',
          uid: 'u1',
          publicPlayerId: 'PFANTASMA0001',
        },
      ],
    });
    const achado = r.achados.find(
      (a) => a.tipo === 'projecao_aponta_para_id_inexistente'
    );
    assert.ok(achado);
    assert.equal(achado.chave, 'rankingStandings/2026-A|u1');
    // O atalho errado seria criar o id faltante. A reconciliacao diz para nao.
    assert.match(achado.reconciliacao, /NAO criar o id faltante/);
  });
});

describe('auditoria: §15.5 — ranking com publicId diferente do canonico', () => {
  test('o defeito exato que as duas autoridades produziriam', () => {
    // Dois ids VALIDOS para o mesmo jogador, um por dominio. Antes desta OS,
    // este seria o estado normal do sistema, e nao um achado.
    const r = auditar({
      ...SADIO,
      reversos: [
        { publicId: 'P0123456789AB', uid: 'u1' },
        { publicId: 'PDORANKING001', uid: 'u1' },
      ],
      perfis: [{ publicId: 'P0123456789AB' }, { publicId: 'PDORANKING001' }],
      projecoes: [
        {
          colecao: 'rankingPlayers',
          documentoId: 'u1',
          uid: 'u1',
          publicPlayerId: 'PDORANKING001',
        },
      ],
    });
    const achado = r.achados.find(
      (a) => a.tipo === 'projecao_divergente_do_canonico'
    );
    assert.ok(achado);
    assert.match(achado.reconciliacao, /Identidade Publica vence/);
    assert.match(achado.reconciliacao, /NAO se cria um id novo/);
  });

  test('§17 — a reconciliacao nao reinicia a carreira competitiva', () => {
    const r = auditar({
      ...SADIO,
      projecoes: [
        {
          colecao: 'rankingPlayers',
          documentoId: 'u1',
          uid: 'u1',
          publicPlayerId: 'PDIVERGENTE1',
        },
        { colecao: 'rankingPlayers', documentoId: 'x', uid: 'u1', publicPlayerId: null },
      ],
      reversos: [
        { publicId: 'P0123456789AB', uid: 'u1' },
        { publicId: 'PDIVERGENTE1', uid: 'u1' },
      ],
    });
    const divergente = r.achados.find(
      (a) => a.tipo === 'projecao_divergente_do_canonico' && /PDIVERGENTE1/.test(a.detalhe)
    );
    assert.match(divergente.reconciliacao, /rating, colocacao, liga, posicao e ledger NAO sao tocados/);
    assert.match(divergente.reconciliacao, /carreira competitiva nao recomeca/);
  });

  test('projecao SEM publicId cai em §16.1, e nao em erro', () => {
    const r = auditar({
      ...SADIO,
      projecoes: [
        {
          colecao: 'rankingPlayers',
          documentoId: 'u1',
          uid: 'u1',
          publicPlayerId: null,
        },
      ],
    });
    const achado = r.achados.find(
      (a) => a.tipo === 'projecao_divergente_do_canonico'
    );
    assert.match(achado.reconciliacao, /§16\.1/);
    assert.equal(achado.severidade, 'reconciliavel');
  });

  test('id na projecao para jogador SEM canonico e CRITICO', () => {
    // O rastro mais direto de uma segunda autoridade: o id existe, o jogador
    // existe, e nao foi `playerIdentities` quem emitiu.
    const r = auditar({
      ...VAZIO,
      reversos: [{ publicId: 'PEMITIDOFORA', uid: 'u9' }],
      projecoes: [
        {
          colecao: 'rankingPlayers',
          documentoId: 'u9',
          uid: 'u9',
          publicPlayerId: 'PEMITIDOFORA',
        },
      ],
      uidsConhecidos: ['u9'],
    });
    const achado = r.achados.find(
      (a) => a.tipo === 'projecao_divergente_do_canonico'
    );
    assert.equal(achado.severidade, 'critico');
    assert.match(achado.detalhe, /emitido por outra autoridade/);
  });
});

describe('auditoria: §15.6 — publicProfile orfao', () => {
  test('perfil sem dono e reportado', () => {
    const r = auditar({ ...SADIO, perfis: [{ publicId: 'PSEMDONO0001' }] });
    const achado = r.achados.find((a) => a.tipo === 'perfil_orfao');
    assert.ok(achado);
    assert.equal(achado.chave, 'PSEMDONO0001');
  });

  test('§3.1 — o id nao e reutilizavel, entao o orfao NAO e apagado', () => {
    const r = auditar({ ...SADIO, perfis: [{ publicId: 'PSEMDONO0001' }] });
    const achado = r.achados.find((a) => a.tipo === 'perfil_orfao');
    assert.match(achado.reconciliacao, /NAO apagar automaticamente/);
    assert.match(achado.reconciliacao, /nao pode ser reutilizado/);
  });

  test('o perfil do jogador sadio NAO e confundido com orfao', () => {
    assert.equal(
      auditar(SADIO).achados.some((a) => a.tipo === 'perfil_orfao'),
      false
    );
  });
});

describe('auditoria: §15.7 — projecao competitiva orfa', () => {
  test('documento competitivo sem uid e reportado', () => {
    const r = auditar({
      ...SADIO,
      projecoes: [
        {
          colecao: 'rankingStandings',
          documentoId: '2026-A|???',
          uid: null,
          publicPlayerId: 'P0123456789AB',
        },
      ],
    });
    const achado = r.achados.find((a) => a.tipo === 'projecao_orfa');
    assert.ok(achado);
    assert.match(achado.reconciliacao, /NAO apagar/);
  });
});

describe('auditoria: o relatorio', () => {
  test('conta por tipo, e os sete tipos existem no total', () => {
    const r = auditar(VAZIO);
    assert.deepEqual(Object.keys(r.totais).sort(), [
      'id_compartilhado',
      'perfil_orfao',
      'projecao_aponta_para_id_inexistente',
      'projecao_divergente_do_canonico',
      'projecao_orfa',
      'uid_com_dois_ids',
      'uid_sem_identidade',
    ]);
  });

  test('o texto avisa quando ha critico', () => {
    const r = auditar({
      ...VAZIO,
      identidades: [
        { uid: 'u1', publicId: 'PCOLIDIDO0001' },
        { uid: 'u2', publicId: 'PCOLIDIDO0001' },
      ],
      uidsConhecidos: ['u1', 'u2'],
    });
    const texto = relatorioComoTexto(r);
    assert.match(texto, /HA CONFLITOS CRITICOS/);
    assert.match(texto, /nenhuma migracao deve rodar/);
  });

  test('auditar duas vezes o mesmo inventario da o mesmo relatorio', () => {
    // Dry-run que muda de resposta entre execucoes nao serve para decidir
    // migracao nenhuma.
    const entrada = {
      ...SADIO,
      uidsConhecidos: ['u1', 'u2', 'u3'],
      perfis: [{ publicId: 'P0123456789AB' }, { publicId: 'PORFAO000001' }],
    };
    assert.deepEqual(auditar(entrada), auditar(entrada));
  });

  test('auditar NAO muta o inventario recebido', () => {
    // A prova mais direta de "read-only" no nivel do modulo.
    const entrada = JSON.parse(JSON.stringify(SADIO));
    const copia = JSON.parse(JSON.stringify(entrada));
    auditar(entrada);
    assert.deepEqual(entrada, copia);
  });
});

describe('auditoria: o runner e read-only (§15)', () => {
  const RUNNER = path.join(__dirname, '..', 'scripts', 'auditar-identidade.js');

  test('o script existe e nao contem verbo de escrita', () => {
    const texto = fs.readFileSync(RUNNER, 'utf8');
    // Sem comentarios: o cabecalho do proprio arquivo cita os verbos para dizer
    // que nao os usa.
    const codigo = texto
      .replace(/\/\*[\s\S]*?\*\//g, '')
      .split('\n')
      .filter((l) => !l.trim().startsWith('*') && !l.trim().startsWith('//'))
      .join('\n');

    for (const verbo of [
      '.set(',
      '.update(',
      '.create(',
      '.delete(',
      '.add(',
      '.commit(',
      'runTransaction',
      'bulkWriter',
      'batch(',
    ]) {
      assert.equal(
        codigo.includes(verbo),
        false,
        `o runner da auditoria usa "${verbo}" — ele tem que ser read-only.`
      );
    }
  });

  test('o script recusa rodar fora do emulador sem consentimento explicito', () => {
    const codigo = fs.readFileSync(RUNNER, 'utf8');
    assert.match(codigo, /FIRESTORE_EMULATOR_HOST/);
    assert.match(codigo, /--eu-sei-que-e-producao/);
  });

  test('o modulo de auditoria nao importa firebase-admin', () => {
    // A pureza e o que torna "dry-run" uma propriedade estrutural em vez de uma
    // promessa.
    const fonte = fs.readFileSync(
      path.join(__dirname, '..', 'src', 'auditoria.ts'),
      'utf8'
    );
    assert.equal(fonte.includes('from "firebase-admin'), false);
    assert.equal(fonte.includes('getFirestore'), false);
  });
});
