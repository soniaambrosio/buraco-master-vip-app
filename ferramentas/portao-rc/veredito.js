// veredito.js — a decisao do portao de Release Candidate, em funcao PURA.
//
// POR QUE ISTO E UM ARQUIVO SEPARADO, e nao um trecho do orquestrador:
//
// A pergunta que o portao responde ("esta RC pode seguir?") e uma regra de
// negocio, e nao um efeito de execucao. Se ela morasse dentro do caminho que
// sobe Emulator Suite, compila Dart e roda Flutter, provar "teste verde +
// cleanup vermelho reprova" custaria uma execucao completa de dezenas de
// minutos — e regra que so da para provar caro acaba nao sendo provada. Aqui
// ela e uma funcao de dados para dados, com teste unitario proprio.
//
// A REGRA CENTRAL, e o motivo de o portao existir:
//
//     ausencia de prova NAO e aprovacao.
//
// Um portao ingenuo pergunta "alguma suite falhou?". Essa pergunta sai verde
// quando a suite nao rodou, quando ela encolheu, quando o ambiente nao subiu e
// quando a execucao terminou prendendo recurso. As quatro situacoes sao
// respostas diferentes de "a RC esta apta", e nenhuma delas e "sim".
//
// AS CINCO REPROVACOES DURAS (regras da OS, uma a uma):
//
//   1. suite executou e falhou .......... reprova (o caso obvio)
//   2. suite OBRIGATORIA nao executou ... reprova (ausencia de prova)
//   3. suite executou incompleta ........ reprova (pulou/cancelou/encolheu)
//   4. cleanup vermelho ................. reprova AINDA QUE tudo esteja verde:
//      processo orfao, trava residual, porta nao drenada, arvore suja
//   5. recibo de outra execucao ......... nao pode ser lido como esta execucao
//
// A 4 e a que separa este portao de um script de CI comum. Uma execucao que
// termina deixando a JVM do Firestore segurando a 8080, ou a trava do emulador
// no /tmp, nao e verde: ela acabou de sabotar a proxima execucao e a maquina de
// quem herdar o turno. O resultado dos testes continua valendo — mas ESTA
// EXECUCAO nao pode ser apresentada como sucesso.

'use strict';

/// Estado de uma suite no catalogo. E o eixo "rodou ou nao rodou", separado do
/// eixo "passou ou falhou" de proposito: as duas perguntas tem respostas
/// independentes, e confundi-las e exatamente o falso verde.
const ESTADO = {
  /// Rodou ate o fim e deixou relatorio. So aqui `veredito` faz sentido.
  EXECUTADA: 'EXECUTADA',
  /// O codigo da suite nao esta nesta arvore (outra branch, outro repositorio).
  AUSENTE: 'AUSENTE',
  /// O codigo esta aqui, mas o ambiente impediu (java ausente, build quebrado,
  /// porta ocupada). Diferente de AUSENTE: aqui ha o que rodar, e nao rodou.
  IMPEDIDA: 'IMPEDIDA',
  /// O operador restringiu a execucao (`--apenas=`). Nunca vira verde global.
  NAO_SOLICITADA: 'NAO_SOLICITADA',
};

/// Veredito de uma suite que EXECUTOU.
const SUITE = {
  PASS: 'PASS',
  /// Rodou inteira e uma asercao falhou. O unico vermelho que fala do codigo.
  FALHA: 'FALHA',
  /// Rodou, mas nao inteira: pulou, cancelou, encolheu abaixo do piso ou nao
  /// deixou rodape. Nao e defeito de codigo — e ausencia de prova.
  INCOMPLETA: 'INCOMPLETA',
};

/// Codigos de saida do portao. A faixa e propria, e nao herdada do `node --test`,
/// porque quem consome isto e um pipeline de release: ele precisa rotear
/// "conserte o codigo" para o time e "conserte a maquina" para a infra sem ler o
/// log inteiro.
const SAIDA = {
  PASS: 0,
  /// Alguma suite rodou inteira e reprovou. Vá olhar o codigo.
  FALHA_FUNCIONAL: 1,
  /// Uso incorreto do proprio portao (alvo inexistente, argumento invalido).
  USO: 2,
  /// Ferramenta ou preparo impediu suite obrigatoria. Vá olhar a maquina.
  AMBIENTE: 4,
  /// Ausencia de prova: obrigatoria ausente da arvore, nao solicitada, ou suite
  /// que rodou incompleta. Vá olhar o escopo da execucao.
  SEM_PROVA: 5,
  /// Testes ok, encerramento nao. Vá limpar o ambiente antes da proxima.
  CLEANUP: 6,
};

/// A PRECEDENCIA NAO E ARBITRARIA, e e a mesma de `relatorio-testes.js` um nivel
/// abaixo — o portao de RC herda a doutrina do portao de suite:
///
///   SEM_PROVA vem antes de FALHA_FUNCIONAL porque uma execucao com suite
///   obrigatoria faltando nao e um veredito sobre o codigo. Anunciar
///   "falha funcional" ali mandaria alguem cacar asercao quebrada quando o que
///   houve foi cobertura incompleta — e, pior, declararia que o resto foi
///   provado.
///
///   CLEANUP vem por ULTIMO porque ele so precisa conseguir transformar VERDE em
///   vermelho. Se ja existe vermelho de suite, o diagnostico dele e mais util, e
///   o cleanup segue registrado no recibo sem sequestrar o codigo de saida.
const PRECEDENCIA = [
  SAIDA.SEM_PROVA,
  SAIDA.AMBIENTE,
  SAIDA.FALHA_FUNCIONAL,
  SAIDA.CLEANUP,
];

/// Uma reprovacao, com endereco. `codigo` decide o exit; `titulo` e o que aparece
/// no topo do relatorio; `detalhe` e o que a pessoa de plantao le em seguida.
function reprovacao(codigo, escopo, titulo, detalhe) {
  return { codigo, escopo, titulo, detalhe };
}

/// Olha UMA suite e devolve as reprovacoes que ela produz.
///
/// Separado de `decidir` para que o teste unitario consiga fixar o
/// comportamento de cada estado sem montar um catalogo inteiro em volta.
function avaliarSuite(s) {
  const nome = `${s.chave}${s.titulo ? ` (${s.titulo})` : ''}`;

  if (s.estado === ESTADO.EXECUTADA) {
    if (s.veredito === SUITE.FALHA) {
      return [reprovacao(
        SAIDA.FALHA_FUNCIONAL, s.chave,
        `${nome}: a suite rodou inteira e REPROVOU`,
        s.falhaOriginal
          ? `Falha original preservada (nao reescrita por esta camada):\n${s.falhaOriginal}`
          : 'A suite saiu com codigo diferente de zero e nao deixou texto de falha.',
      )];
    }

    if (s.veredito === SUITE.INCOMPLETA) {
      return [reprovacao(
        SAIDA.SEM_PROVA, s.chave,
        `${nome}: a suite rodou, mas NAO INTEIRA`,
        (s.problemas && s.problemas.length
          ? s.problemas.join('\n')
          : 'A suite nao deixou relatorio integro.')
        + '\n\nPulo, cancelamento ou encolhimento nao sao verde: sao ausencia de\n'
        + 'prova. O exit code do runner responde "algo falhou?"; esta linha\n'
        + 'responde "tudo rodou?", que e a unica pergunta que um portao aceita.',
      )];
    }

    return [];
  }

  // Daqui para baixo a suite NAO executou. So reprova se for obrigatoria — e a
  // obrigatoriedade e declarada no catalogo, nunca inferida aqui.
  if (!s.obrigatoria) return [];

  if (s.estado === ESTADO.IMPEDIDA) {
    return [reprovacao(
      SAIDA.AMBIENTE, s.chave,
      `${nome}: suite OBRIGATORIA impedida pelo ambiente`,
      `${s.motivo || 'motivo nao registrado'}\n\n`
      + 'O codigo desta suite esta na arvore: havia o que rodar, e nao rodou.\n'
      + 'Isto nao e verde nem vermelho de teste — e uma RC sem veredito sobre\n'
      + 'esta frente.',
    )];
  }

  if (s.estado === ESTADO.NAO_SOLICITADA) {
    return [reprovacao(
      SAIDA.SEM_PROVA, s.chave,
      `${nome}: suite OBRIGATORIA fora da execucao pedida`,
      `${s.motivo || 'restringida por --apenas/--pular'}\n\n`
      + 'Uma execucao parcial pode ser util para depurar, mas nao pode assinar\n'
      + 'uma RC: o portao so responde "apta" sobre o conjunto obrigatorio inteiro.',
    )];
  }

  // AUSENTE
  return [reprovacao(
    SAIDA.SEM_PROVA, s.chave,
    `${nome}: suite OBRIGATORIA ausente desta arvore`,
    `${s.motivo || 'o codigo da suite nao foi encontrado'}\n\n`
    + 'Declarada obrigatoria no catalogo e inexistente no commit sob teste. Ou a\n'
    + 'base esta errada, ou o catalogo esta desatualizado — as duas hipoteses\n'
    + 'reprovam, porque nenhuma delas prova a frente que a suite cobre.',
  )];
}

/// Olha o encerramento e devolve as reprovacoes de cleanup.
///
/// Os quatro sinais sao independentes de proposito. Uma trava residual sem porta
/// presa acontece quando o processo morreu depois do dreno; uma porta presa sem
/// trava acontece quando o ocupante nunca passou pelo runner. Colapsar os dois
/// num booleano so perderia justamente a informacao que diz onde ir mexer.
function avaliarCleanup(a) {
  const fora = [];
  if (!a) return fora;

  if (a.trava && a.trava.residual) {
    fora.push(reprovacao(
      SAIDA.CLEANUP, 'cleanup/trava',
      'TRAVA RESIDUAL do Emulator Suite',
      `Sobrou o arquivo de trava:\n  ${a.trava.caminho}\n`
      + (a.trava.dono ? `  dono registrado: alvo=${a.trava.dono.alvo} pid=${a.trava.dono.pid}\n` : '')
      + '\nA trava existe para impedir duas execucoes simultaneas. Sobrevivendo a\n'
      + 'esta, ela bloqueia a proxima sem proteger nada — e quem esbarrar nela vai\n'
      + 'ler "ambiente ocupado" sem ocupante.',
    ));
  }

  if (a.orfaos && a.orfaos.length > 0) {
    fora.push(reprovacao(
      SAIDA.CLEANUP, 'cleanup/orfaos',
      `${a.orfaos.length} PROCESSO(S) ORFAO(S) sobreviveram a execucao`,
      a.orfaos.map((o) => `  pid ${o.pid}  ${o.descricao || ''}`).join('\n')
      + '\n\nSao processos que ESTA execucao subiu e nao derrubou. No Windows a JVM\n'
      + 'do Firestore nao morre junto com o `firebase` que a abriu: ela fica\n'
      + 'segurando porta, e a proxima execucao encontra "ambiente ocupado" sem\n'
      + 'ninguem para culpar.',
    ));
  }

  // "quando aplicavel": so cobra dreno se alguma suite chegou a subir emulador.
  // Cobrar de uma execucao que nunca abriu porta seria reprovar por um recurso
  // que ela nao tocou — e o primeiro reflexo de quem fosse barrado assim seria
  // desligar o portao.
  if (a.portas && a.portas.aplicavel && !a.portas.drenadas) {
    fora.push(reprovacao(
      SAIDA.CLEANUP, 'cleanup/portas',
      'PORTAS NAO DRENADAS depois da execucao',
      (a.portas.presas || []).map((p) => `  ${String(p.nome).padEnd(10)} ${p.porta}`).join('\n')
      + '\n\nOs emuladores continuaram escutando depois do limite de dreno. So o\n'
      + 'estado LISTENING conta aqui: sockets em TIME_WAIT nao impedem nada e nao\n'
      + 'sao medidos (ver `ambiente-emulador.js`, teste de bind e nao de netstat).',
    ));
  }

  // Cleanup que falhou UM NIVEL ABAIXO, dentro de um `runner-emulador.js`
  // (classe CLEANUP-INCOMPLETO, exit 6 dele): a suite passou inteira e as portas
  // ficaram presas depois dela.
  //
  // Registrado a parte do dreno do portao de proposito. O portao mede as portas
  // no FIM de tudo, e ate la elas ja podem ter drenado sozinhas — o rabo dura
  // segundos. Se so o retrato final valesse, o estrago sumiria do recibo: a
  // suite seguinte esperou, o dreno depois acusou "ok", e ninguem saberia que
  // uma execucao entregou o ambiente preso para a proxima.
  if (a.suitesComCleanupRuim && a.suitesComCleanupRuim.length > 0) {
    fora.push(reprovacao(
      SAIDA.CLEANUP, 'cleanup/suite',
      `${a.suitesComCleanupRuim.length} suite(s) terminaram com o ambiente preso`,
      a.suitesComCleanupRuim.map((c) => `  ${c}`).join('\n')
      + '\n\nO runner destas suites saiu com classe CLEANUP-INCOMPLETO: os testes\n'
      + 'passaram e o ENCERRAMENTO falhou. Que as portas tenham drenado depois nao\n'
      + 'apaga o fato — no intervalo, a execucao seguinte esbarraria nelas.',
    ));
  }

  if (a.arvore && !a.arvore.limpa) {
    fora.push(reprovacao(
      SAIDA.CLEANUP, 'cleanup/arvore',
      'ARVORE SUJA ao fim da execucao',
      (a.arvore.sujeira || []).map((l) => `  ${l}`).join('\n')
      + '\n\nO portao encena o ambiente do CI para rodar (seeds de `app/data` viram\n'
      + '`app/test/**/data/`, e a suite de evidencias regenera PNG). Encenacao que\n'
      + 'nao e desfeita vira commit acidental — e um arquivo de teste versionado\n'
      + 'por engano faz a proxima execucao provar outra coisa.',
    ));
  }

  return fora;
}

/// A decisao global. Recebe o catalogo ja executado e o retrato do ambiente;
/// devolve veredito, exit code e a lista inteira de motivos.
///
/// `execucao` carrega a identidade desta corrida (ver `recibo.js`). Ela entra
/// aqui porque a regra "recibo antigo nao pode ser confundido com execucao
/// atual" e uma regra de veredito, e nao de arquivo: um recibo cujo
/// `execucaoId` nao seja o desta corrida nao descreve esta corrida, e tratar os
/// dois como a mesma coisa e o quinto falso verde da lista la de cima.
function decidir(entrada) {
  const { suites = [], ambiente = null, execucao = null } = entrada;

  const reprovacoes = [];

  for (const s of suites) reprovacoes.push(...avaliarSuite(s));
  reprovacoes.push(...avaliarCleanup(ambiente));

  if (execucao && execucao.reciboConflitante) {
    reprovacoes.push(reprovacao(
      SAIDA.SEM_PROVA, 'recibo',
      'RECIBO DE OUTRA EXECUCAO encontrado no lugar do desta',
      `esperado execucaoId=${execucao.execucaoId}\n`
      + `encontrado execucaoId=${execucao.reciboConflitante}\n\n`
      + 'Um recibo que sobrou de uma corrida anterior descreve outra arvore e\n'
      + 'outro ambiente. Lido como se fosse desta, ele aprova uma RC que ninguem\n'
      + 'testou — que e o mais silencioso dos falsos verdes, porque tem documento.',
    ));
  }

  const aprovada = reprovacoes.length === 0;

  // O exit sai da PRECEDENCIA, e nao da ordem em que os problemas apareceram:
  // a ordem de execucao das suites nao pode mudar a classe do vermelho.
  let saida = SAIDA.PASS;
  if (!aprovada) {
    const presentes = new Set(reprovacoes.map((r) => r.codigo));
    saida = PRECEDENCIA.find((c) => presentes.has(c)) ?? SAIDA.FALHA_FUNCIONAL;
  }

  return {
    veredito: aprovada ? 'PASS' : 'FAIL',
    saida,
    reprovacoes,
    resumo: resumirCatalogo(suites),
  };
}

/// Os numeros que o cabecalho do relatorio mostra. `testes` soma so o que
/// EXECUTOU: somar o piso de uma suite que nao rodou daria a uma RC sem prova a
/// aparencia estatistica de uma RC testada.
function resumirCatalogo(suites) {
  const conta = (f) => suites.filter(f).length;
  const testes = suites.reduce(
    (t, s) => t + ((s.estado === ESTADO.EXECUTADA && s.contagem && s.contagem.testes) || 0), 0,
  );
  const falhas = suites.reduce(
    (t, s) => t + ((s.estado === ESTADO.EXECUTADA && s.contagem && s.contagem.falhou) || 0), 0,
  );
  return {
    total: suites.length,
    executadas: conta((s) => s.estado === ESTADO.EXECUTADA),
    naoExecutadas: conta((s) => s.estado !== ESTADO.EXECUTADA),
    obrigatorias: conta((s) => s.obrigatoria),
    obrigatoriasNaoExecutadas: conta((s) => s.obrigatoria && s.estado !== ESTADO.EXECUTADA),
    testes,
    falhas,
  };
}

module.exports = {
  ESTADO, SUITE, SAIDA, PRECEDENCIA,
  decidir, avaliarSuite, avaliarCleanup, resumirCatalogo,
};
