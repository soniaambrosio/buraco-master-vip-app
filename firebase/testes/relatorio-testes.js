// relatorio-testes.js — le o relatorio do `node --test` e decide se ele PROVA
// que a suite rodou inteira.
//
// POR QUE ISTO EXISTE:
//
// O exit code do `node --test` responde "alguma asercao falhou?". Ele NAO
// responde "a suite rodou inteira?". Sao perguntas diferentes, e a segunda e a
// unica que um portao de homologacao pode aceitar como verde. Tres desfechos
// medidos neste repositorio saem com codigo 0 sem ter provado nada:
//
//   1. `describe({skip:true})` — o bloco inteiro sai de cena. Medido no node 24
//      com um describe de DOIS casos mais um caso solto pulado:
//
//        ﹣ bloco pulado (0.7ms) # SKIP     <- describe com DOIS casos dentro
//        ﹣ solto pulado (0.7ms) # SKIP
//        ✔ roda (0.1ms)
//        ℹ tests 2
//        ℹ skipped 1
//
//      `tests 2` conta o caso solto e o que rodou. Os DOIS casos de dentro do
//      describe pulado nao entram em contador NENHUM. Por isso a leitura tem
//      tres frentes — diretiva `# SKIP`, rodape `skipped` e total `tests` contra
//      um piso esperado —, e nao uma so: cada uma enxerga um pedaco cego das
//      outras.
//
//   2. CANCELAMENTO. Quando um `before` de suite estoura, os filhos saem com
//      'test did not finish before its parent and was cancelled'. Foi o que se
//      viu na linha de base desta OS: bundle social ausente, `functions/not-found`
//      no pai, e dezenas de casos cancelados embaixo.
//
//   3. SUITE ENCURTADA. Um arquivo que some do alvo, ou um `--test` que nao
//      casa com o glob, derruba o total sem derrubar o exit code. O piso
//      `esperado` e a rede contra isso.
//
// O prefixo do rodape muda com o reporter — `#` no TAP, `ℹ` no spec, que e o
// padrao desde o node 22 mesmo com a saida redirecionada. Aceitar so o `#` era,
// ele proprio, um portao que nunca fecharia.

'use strict';

/// Marcador que o proprio node imprime na linha de cada caso que morreu junto
/// com o pai. E a unica evidencia de cancelamento que aparece ANTES do rodape —
/// e, quando o processo e morto no meio, a unica que chega a existir.
const MARCA_CANCELAMENTO = /was cancelled\b/i;

/// Os contadores do rodape, em qualquer um dos dois reporters.
function contador(texto, nome) {
  const achado = texto.match(
    new RegExp(String.raw`^\s*(?:#|ℹ)\s*${nome}\s+(\d+)\s*$`, 'm'),
  );
  return achado ? Number(achado[1]) : null;
}

/// Le o texto bruto do relatorio. Nao decide nada: so extrai.
function lerRelatorio(texto) {
  const linhas = String(texto).split('\n');
  return {
    tests: contador(texto, 'tests'),
    suites: contador(texto, 'suites'),
    pass: contador(texto, 'pass'),
    fail: contador(texto, 'fail'),
    cancelled: contador(texto, 'cancelled'),
    skipped: contador(texto, 'skipped'),
    todo: contador(texto, 'todo'),
    diretivasSkip: linhas.filter((l) => /#\s*SKIP\b/i.test(l)),
    linhasCanceladas: linhas.filter((l) => MARCA_CANCELAMENTO.test(l)),
  };
}

/// Decide se o relatorio pode virar portao verde.
///
/// `esperado` e PISO, e nao igualdade: um caso novo legitimo nao pode ficar
/// devendo uma edicao neste arquivo para o portao voltar a fechar, mas um caso
/// que SOME tem que derrubar. O modo de falha real desta OS e a suite encolher
/// em silencio, nao crescer.
function conferirRelatorio(relatorio, opcoes = {}) {
  const { esperado = null, alvo = null } = opcoes;
  const problemas = [];
  const onde = alvo ? ` do alvo \`${alvo}\`` : '';

  // Rodape ausente = o `node --test` nao chegou ao fim. Processo morto, emulador
  // derrubado no meio, pipe quebrado. Sem rodape nao ha o que aprovar.
  if (relatorio.tests === null) {
    problemas.push(
      'O relatorio do `node --test` nao tem rodape: a execucao nao chegou ao fim.\n' +
      '  E o sintoma de suite interrompida — processo morto, emulador derrubado\n' +
      '  no meio ou saida truncada. Nenhum teste pode ser considerado valido.',
    );
    return { ok: false, problemas };
  }

  if (relatorio.fail > 0) {
    problemas.push(`${relatorio.fail} teste(s) falharam${onde}.`);
  }

  if (relatorio.cancelled > 0 || relatorio.linhasCanceladas.length > 0) {
    problemas.push(
      `Houve teste CANCELADO${onde} — ${relatorio.cancelled} no rodape, ` +
      `${relatorio.linhasCanceladas.length} marcado(s) na saida.\n` +
      '  Um caso cancelado nao provou nem passou: ele foi abandonado quando o pai\n' +
      '  morreu. Contar isso como verde e exatamente o falso verde que este portao\n' +
      '  existe para impedir. Primeiras linhas:\n' +
      relatorio.linhasCanceladas.slice(0, 5).map((l) => `    ${l.trim()}`).join('\n'),
    );
  }

  if (relatorio.skipped > 0 || relatorio.diretivasSkip.length > 0) {
    problemas.push(
      `Houve teste PULADO${onde} — ${relatorio.skipped} no rodape, ` +
      `${relatorio.diretivasSkip.length} com diretiva SKIP.\n` +
      '  Este alvo alega provar chamada real as Cloud Functions; pular aqui e\n' +
      '  declarar integracao onde nao houve chamada. Quem quer pular roda o alvo\n' +
      '  de Regras, que nao alega provar Function nenhuma. Primeiras linhas:\n' +
      relatorio.diretivasSkip.slice(0, 5).map((l) => `    ${l.trim()}`).join('\n'),
    );
  }

  if (esperado !== null && relatorio.tests < esperado) {
    problemas.push(
      `A suite${onde} rodou ${relatorio.tests} caso(s), e o piso e ${esperado}.\n` +
      '  Faltou suite. Um `describe` pulado inteiro nao soma no rodape `skipped`,\n' +
      '  entao o total e a UNICA frente que enxerga esse buraco. Se a suite\n' +
      '  encolheu de proposito, baixe o piso no `package.json` junto da mudanca.',
    );
  }

  return { ok: problemas.length === 0, problemas };
}

/// As tres classes de desfecho que um portao precisa saber distinguir, mais os
/// dois extremos. Quem le um vermelho pergunta antes de tudo "e defeito meu ou
/// da maquina?"; um rotulo unico obriga a ler o log inteiro para descobrir.
const CLASSE = {
  OK: 'OK',
  FUNCIONAL: 'FALHA-FUNCIONAL',
  INFRA: 'INFRAESTRUTURA',
  INCOMPLETA: 'SUITE-INCOMPLETA',
  INDETERMINADA: 'INDETERMINADA',
};

/// Decide a classe, o exit code e o texto. Funcao PURA — e por isso que a
/// precedencia entre as classes da para provar em teste unitario, sem subir
/// emulador nenhum.
///
/// A PRECEDENCIA NAO E ARBITRARIA. O caso que a define e o da linha de base
/// desta OS: o bundle social faltava, a Function respondeu `not-found`, o pai
/// estourou (fail=1) e 60+ filhos foram CANCELADOS. Se `fail` viesse primeiro,
/// aquilo sairia rotulado como falha funcional — mandando alguem cacar asercao
/// quebrada quando o defeito era ambiente, e declarando "a suite rodou" sobre
/// uma suite que nao rodou. Por isso cancelamento vem ANTES de falha:
///
///   um caso cancelado nao produziu veredito nenhum, e uma execucao com casos
///   cancelados nao e um veredito funcional — e uma execucao que nao terminou.
///
/// A falha real continua impressa na saida e o exit segue diferente de zero, que
/// e o que §11 exige: a camada de robustez nao ESCONDE a falha funcional, ela so
/// se recusa a chamar de "suite executada" uma suite que foi interrompida.
function classificar(entrada) {
  const { relatorio, esperado, alvo = null, codigo = 0, temRecibo = true } = entrada;

  if (!temRecibo) {
    return codigo !== 0
      ? {
        classe: CLASSE.INFRA,
        exit: 3,
        problemas: [
          `O processo saiu com codigo ${codigo} sem que a suite deixasse recibo: o\n`
          + '  ambiente nao subiu, e NENHUM teste chegou a ser executado.\n\n'
          + '  Isto NAO e uma falha de teste. O motivo esta na saida do emulador logo\n'
          + '  acima — tipicamente porta ocupada, codebase que nao carregou ou java\n'
          + '  ausente. Nenhum resultado parcial desta execucao e valido.',
        ],
      }
      : {
        classe: CLASSE.INCOMPLETA,
        exit: 5,
        problemas: ['O processo saiu com codigo 0 sem deixar recibo: o comando '
          + 'interno nao chegou ao fim. Um exit 0 sem recibo e um verde que ninguem provou.'],
      };
  }

  if (typeof esperado !== 'number' || !Number.isFinite(esperado)) {
    return {
      classe: CLASSE.INCOMPLETA,
      exit: 5,
      problemas: ['A suite rodou sem piso de casos (`--esperado=N`). O piso e a unica '
        + 'frente que enxerga um `describe` pulado inteiro, que nao soma no rodape.'],
    };
  }

  const conferencia = conferirRelatorio(relatorio, { esperado, alvo });
  const cancelou = relatorio.cancelled > 0 || relatorio.linhasCanceladas.length > 0;

  if (cancelou) {
    const extra = relatorio.fail > 0
      ? ['\nHouve TAMBEM ' + relatorio.fail + ' falha(s) de asercao, impressa(s) na saida '
        + 'acima. Elas continuam valendo — mas com casos cancelados esta execucao nao e '
        + 'um veredito sobre o codigo, e sim uma execucao que nao terminou.']
      : [];
    return { classe: CLASSE.INCOMPLETA, exit: 5, problemas: [...conferencia.problemas, ...extra] };
  }

  if (relatorio.fail > 0) {
    return { classe: CLASSE.FUNCIONAL, exit: codigo || 1, problemas: conferencia.problemas };
  }

  if (!conferencia.ok) {
    return { classe: CLASSE.INCOMPLETA, exit: 5, problemas: conferencia.problemas };
  }

  if (codigo !== 0) {
    return {
      classe: CLASSE.INDETERMINADA,
      exit: codigo,
      problemas: ['O relatorio esta integro e mesmo assim o processo saiu com codigo '
        + `${codigo}. Algo fora da suite quebrou — o proprio exec, o npm ou o shell.`],
    };
  }

  return { classe: CLASSE.OK, exit: 0, problemas: [] };
}

/// Uma linha so, para o log do portao (§9 da OS pede exatamente estes campos).
function resumir(relatorio) {
  const n = (v) => (v === null ? '?' : v);
  return (
    `tests=${n(relatorio.tests)} pass=${n(relatorio.pass)} fail=${n(relatorio.fail)} ` +
    `skipped=${n(relatorio.skipped)} cancelled=${n(relatorio.cancelled)} ` +
    `todo=${n(relatorio.todo)}`
  );
}

module.exports = {
  lerRelatorio, conferirRelatorio, classificar, resumir, CLASSE, MARCA_CANCELAMENTO,
};
