// auditoria.ts — a CONFERENCIA DE INTEGRIDADE da identidade publica.
//
// OS de integracao Identidade Publica x Ranking v1, secoes 15, 16 e 17.
//
// POR QUE MORA NO DOMINIO SOCIAL, e nao no de ranking. A regra de reconciliacao
// da OS e uma so — "a Identidade Publica vence" — e quem a aplica tem que ser
// quem tem autoridade para decidir qual e o id certo. Colocar a auditoria em
// `functions-ranking` faria o dominio que perdeu a autoridade de emissao voltar
// a opinar sobre qual identidade e a valida, por uma porta lateral.
//
// POR QUE E UM MODULO PURO. Ele nao le o Firestore: recebe o inventario ja lido
// e CLASSIFICA. Tres consequencias, e as tres sao o ponto:
//
//   1. E impossivel este arquivo mutar producao. Nao tem `set`, nao tem `db()`,
//      nao tem `firebase-admin`. §15 exige que a primeira execucao seja
//      read-only; aqui nao existe execucao que nao seja.
//   2. Roda com `node --test`, sem emulador, sobre fixtures que descrevem
//      exatamente os sete defeitos que §15 nomeia.
//   3. O runner que le o banco de verdade (`scripts/auditar-identidade.js`) fica
//      pequeno o bastante para ser lido inteiro antes de rodar.
//
// O QUE ESTE MODULO NAO FAZ, E NAO DEVE PASSAR A FAZER: corrigir. §15 e §16 sao
// explicitas — a primeira execucao e dry-run, a migracao e outra OS, e o caso
// 16.5 (mesmo publicId em dois UIDs) e conflito CRITICO que ninguem resolve
// automaticamente. `planoDeReconciliacao` diz o que DEVERIA acontecer; quem
// executa e uma decisao humana registrada.

// ---------------------------------------------------------------------------
// O INVENTARIO
// ---------------------------------------------------------------------------

/// `playerIdentities/{uid}` — o mapa canonico.
export interface IdentidadeLida {
  readonly uid: string;
  readonly publicId: string | null;
}

/// `publicIdIndex/{publicId}` — o mapa reverso canonico.
export interface ReversoLido {
  readonly publicId: string;
  readonly uid: string | null;
}

/// `publicProfiles/{publicId}` — o perfil publico.
export interface PerfilLido {
  readonly publicId: string;
}

/// Um documento COMPETITIVO que referencia identidade: `rankingPlayers/{uid}` ou
/// `rankingStandings/{seasonId|uid}`.
///
/// Os dois entram na mesma forma de proposito. O que a auditoria pergunta e
/// sempre a mesma coisa — "este `publicPlayerId` bate com o canonico deste uid?"
/// — e um tipo por colecao faria a mesma pergunta ser escrita duas vezes.
export interface ProjecaoCompetitivaLida {
  readonly colecao: string;
  readonly documentoId: string;
  readonly uid: string | null;
  readonly publicPlayerId: string | null;
}

export interface Inventario {
  readonly identidades: ReadonlyArray<IdentidadeLida>;
  readonly reversos: ReadonlyArray<ReversoLido>;
  readonly perfis: ReadonlyArray<PerfilLido>;
  readonly projecoes: ReadonlyArray<ProjecaoCompetitivaLida>;
  /// UIDs que o sistema conhece por OUTRO caminho que nao a identidade publica
  /// — tipicamente `users/{uid}`. E o que permite responder ao item 1 de §15
  /// ("UID sem identidade publica"), que por definicao nao aparece em
  /// `playerIdentities`.
  readonly uidsConhecidos: ReadonlyArray<string>;
}

// ---------------------------------------------------------------------------
// OS ACHADOS
// ---------------------------------------------------------------------------

/// Os sete defeitos de §15, um codigo por item, na ordem da OS.
export type TipoDeAchado =
  /// 1. UID sem identidade publica.
  | "uid_sem_identidade"
  /// 2. UID associado a mais de um publicId.
  | "uid_com_dois_ids"
  /// 3. Mesmo publicId associado a UIDs diferentes.
  | "id_compartilhado"
  /// 4. Documento competitivo apontando para publicId inexistente.
  | "projecao_aponta_para_id_inexistente"
  /// 5. Ranking com publicId diferente do canonico.
  | "projecao_divergente_do_canonico"
  /// 6. publicProfile orfao.
  | "perfil_orfao"
  /// 7. Projecao competitiva orfa.
  | "projecao_orfa";

/// Quao grave e, e quem pode resolver.
///
/// A distincao existe porque §16.5 e §16.4 mandam NAO resolver sozinho, e um
/// relatorio que misturasse esses casos com os automatizaveis convidaria alguem
/// a rodar tudo de uma vez.
export type Severidade =
  /// A regra canonica de §16 resolve, e a resolucao e obvia e reversivel.
  | "reconciliavel"
  /// §16.4 e §16.5: exige decisao humana registrada. NUNCA automatico.
  | "critico";

export interface Achado {
  readonly tipo: TipoDeAchado;
  readonly severidade: Severidade;
  /// A chave sobre a qual o achado fala: um uid, um publicId ou um caminho de
  /// documento. Serve para ordenar e deduplicar o relatorio.
  readonly chave: string;
  readonly detalhe: string;
  /// O que §16 manda fazer. Texto, e nao acao — ver o cabecalho deste arquivo.
  readonly reconciliacao: string;
}

export interface Relatorio {
  readonly achados: ReadonlyArray<Achado>;
  readonly totais: Readonly<Record<TipoDeAchado, number>>;
  readonly criticos: number;
  /// `true` quando nao ha nada a reconciliar. E o unico estado em que uma
  /// migracao futura seria desnecessaria.
  readonly integro: boolean;
  readonly conferidos: Readonly<{
    identidades: number;
    reversos: number;
    perfis: number;
    projecoes: number;
    uidsConhecidos: number;
  }>;
}

const TIPOS: ReadonlyArray<TipoDeAchado> = [
  "uid_sem_identidade",
  "uid_com_dois_ids",
  "id_compartilhado",
  "projecao_aponta_para_id_inexistente",
  "projecao_divergente_do_canonico",
  "perfil_orfao",
  "projecao_orfa",
];

// ---------------------------------------------------------------------------
// A CONFERENCIA
// ---------------------------------------------------------------------------

/// Classifica o inventario nos sete defeitos de §15. NAO MUTA NADA.
///
/// A ORDEM DAS CONFERENCIAS SEGUE A ORDEM DA OS, e nao a conveniencia do
/// codigo, para que o relatorio possa ser lido lado a lado com o documento.
export function auditar(inventario: Inventario): Relatorio {
  const achados: Achado[] = [];

  // O canonico, indexado. `playerIdentities` e enderecada por uid, entao dois
  // documentos para o mesmo uid sao impossiveis POR CONSTRUCAO — o defeito 2 nao
  // pode nascer ali. Ele nasce da DISCORDANCIA entre o mapa e o mapa reverso, que
  // e onde ele e procurado abaixo.
  const canonicoDe = new Map<string, string>();
  for (const i of inventario.identidades) {
    if (typeof i.publicId === "string" && i.publicId.length > 0) {
      canonicoDe.set(i.uid, i.publicId);
    }
  }

  // ---- 1. UID sem identidade publica -------------------------------------
  for (const uid of inventario.uidsConhecidos) {
    if (!canonicoDe.has(uid)) {
      achados.push({
        tipo: "uid_sem_identidade",
        severidade: "reconciliavel",
        chave: uid,
        detalhe: `o jogador ${uid} existe no sistema e nao tem identidade publica.`,
        reconciliacao:
          "provisionar pelo mecanismo oficial (garantirIdentidade). Nao cunhar " +
          "de nenhum outro lugar, e nao derivar do uid.",
      });
    }
  }

  // ---- 2. UID com mais de um publicId ------------------------------------
  // A fonte do conflito e o indice reverso: dois documentos de `publicIdIndex`
  // apontando para o MESMO uid significam dois ids historicos vivos. §16.4:
  // "Nao escolher silenciosamente pelo mais recente."
  const idsPorUid = new Map<string, string[]>();
  for (const r of inventario.reversos) {
    if (typeof r.uid !== "string" || r.uid.length === 0) continue;
    const lista = idsPorUid.get(r.uid);
    if (lista === undefined) idsPorUid.set(r.uid, [r.publicId]);
    else lista.push(r.publicId);
  }
  for (const [uid, ids] of idsPorUid) {
    if (ids.length < 2) continue;
    const canonico = canonicoDe.get(uid) ?? null;
    achados.push({
      tipo: "uid_com_dois_ids",
      severidade: "critico",
      chave: uid,
      detalhe:
        `o jogador ${uid} tem ${ids.length} ids publicos no indice reverso ` +
        `(${[...ids].sort().join(", ")}); o canonico em playerIdentities e ` +
        `${canonico ?? "NENHUM"}.`,
      reconciliacao:
        "§16.4 — conflito auditavel. O canonico de playerIdentities vence; os " +
        "demais viram historico e NAO sao apagados sem decisao registrada. " +
        "Nao escolher pelo mais recente.",
    });
  }

  // ---- 3. Mesmo publicId em UIDs diferentes ------------------------------
  // O pior caso possivel: duas pessoas com a mesma identidade publica. §16.5
  // manda tratar como conflito critico e NAO sobrescrever ninguem.
  const uidsPorId = new Map<string, Set<string>>();
  for (const [uid, publicId] of canonicoDe) {
    const set = uidsPorId.get(publicId) ?? new Set<string>();
    set.add(uid);
    uidsPorId.set(publicId, set);
  }
  for (const r of inventario.reversos) {
    if (typeof r.uid !== "string" || r.uid.length === 0) continue;
    const set = uidsPorId.get(r.publicId) ?? new Set<string>();
    set.add(r.uid);
    uidsPorId.set(r.publicId, set);
  }
  for (const [publicId, uids] of uidsPorId) {
    if (uids.size < 2) continue;
    achados.push({
      tipo: "id_compartilhado",
      severidade: "critico",
      chave: publicId,
      detalhe:
        `o id publico ${publicId} esta associado a ${uids.size} UIDs ` +
        `(${[...uids].sort().join(", ")}).`,
      reconciliacao:
        "§16.5 — conflito CRITICO de integridade. Nao sobrescrever " +
        "automaticamente um jogador com o outro. Exige decisao humana, e o " +
        "historico competitivo de ambos fica intocado ate ela.",
    });
  }

  // ---- 4, 5 e 7. As projecoes competitivas -------------------------------
  const idsExistentes = new Set<string>([
    ...inventario.reversos.map((r) => r.publicId),
    ...canonicoDe.values(),
  ]);

  for (const p of inventario.projecoes) {
    const caminho = `${p.colecao}/${p.documentoId}`;
    const temUid = typeof p.uid === "string" && p.uid.length > 0;
    const temId =
      typeof p.publicPlayerId === "string" && p.publicPlayerId.length > 0;

    // 7. Projecao orfa: nao da para dizer de quem ela e.
    if (!temUid) {
      achados.push({
        tipo: "projecao_orfa",
        severidade: "reconciliavel",
        chave: caminho,
        detalhe: `${caminho} nao carrega uid — nao ha a quem reconciliar.`,
        reconciliacao:
          "documento competitivo sem dono. Investigar a origem antes de " +
          "qualquer acao; NAO apagar, porque pode carregar historico.",
      });
      continue;
    }

    const canonico = canonicoDe.get(p.uid as string) ?? null;

    // §16.1 — projecao sem publicId. Nao e defeito de identidade: e uma
    // projecao incompleta, e a reconciliacao dela e trivial.
    if (!temId) {
      achados.push({
        tipo: "projecao_divergente_do_canonico",
        severidade: "reconciliavel",
        chave: caminho,
        detalhe: `${caminho} nao tem publicPlayerId; o canonico de ${p.uid} e ${canonico ?? "NENHUM"}.`,
        reconciliacao:
          canonico === null
            ? "§16.1 + §15.1 — provisionar a identidade primeiro, e so entao " +
              "preencher a projecao."
            : "§16.1 — associar ao identificador canonico da Identidade Publica.",
      });
      continue;
    }

    // 4. Aponta para um id que nao existe em lugar nenhum.
    if (!idsExistentes.has(p.publicPlayerId as string)) {
      achados.push({
        tipo: "projecao_aponta_para_id_inexistente",
        severidade: "reconciliavel",
        chave: caminho,
        detalhe:
          `${caminho} aponta para o id ${p.publicPlayerId}, que nao existe nem em ` +
          "playerIdentities nem em publicIdIndex.",
        reconciliacao:
          "§16.3 — a Identidade Publica vence. Reapontar para o canonico do uid; " +
          "NAO criar o id faltante para 'salvar' a referencia.",
      });
      continue;
    }

    // 5. Existe, mas nao e o do jogador. E o defeito que as duas autoridades
    //    paralelas produziriam: dois ids validos, um por dominio.
    if (canonico !== null && p.publicPlayerId !== canonico) {
      achados.push({
        tipo: "projecao_divergente_do_canonico",
        severidade: "reconciliavel",
        chave: caminho,
        detalhe:
          `${caminho} usa ${p.publicPlayerId}, e o canonico de ${p.uid} e ${canonico}.`,
        reconciliacao:
          "§16.3 — a Identidade Publica vence, e NAO se cria um id novo. " +
          "§17: rating, colocacao, liga, posicao e ledger NAO sao tocados — a " +
          "referencia publica muda, a carreira competitiva nao recomeca.",
      });
      continue;
    }

    // Sem canonico e com id na projecao: o id veio de algum lugar, e nao foi de
    // `playerIdentities`. E o rastro mais direto de uma segunda autoridade.
    if (canonico === null) {
      achados.push({
        tipo: "projecao_divergente_do_canonico",
        severidade: "critico",
        chave: caminho,
        detalhe:
          `${caminho} carrega o id ${p.publicPlayerId} para ${p.uid}, que NAO tem ` +
          "identidade canonica. O id foi emitido por outra autoridade.",
        reconciliacao:
          "§16.4 — conflito auditavel. Provisionar a identidade canonica e " +
          "decidir, por registro, o destino do id historico. Nao promover o id " +
          "da projecao a canonico automaticamente.",
      });
    }
  }

  // ---- 6. Perfil publico orfao -------------------------------------------
  const idsComDono = new Set<string>([
    ...canonicoDe.values(),
    ...inventario.reversos
      .filter((r) => typeof r.uid === "string" && r.uid.length > 0)
      .map((r) => r.publicId),
  ]);
  for (const perfil of inventario.perfis) {
    if (!idsComDono.has(perfil.publicId)) {
      achados.push({
        tipo: "perfil_orfao",
        severidade: "reconciliavel",
        chave: perfil.publicId,
        detalhe:
          `publicProfiles/${perfil.publicId} nao tem uid correspondente em ` +
          "playerIdentities nem em publicIdIndex.",
        reconciliacao:
          "perfil sem dono. NAO apagar automaticamente: o id nao pode ser " +
          "reutilizado (§3.1), e um perfil orfao e a unica prova de que ele ja " +
          "foi emitido.",
      });
    }
  }

  const totais = Object.fromEntries(
    TIPOS.map((t) => [t, achados.filter((a) => a.tipo === t).length])
  ) as Record<TipoDeAchado, number>;

  return {
    achados,
    totais,
    criticos: achados.filter((a) => a.severidade === "critico").length,
    integro: achados.length === 0,
    conferidos: {
      identidades: inventario.identidades.length,
      reversos: inventario.reversos.length,
      perfis: inventario.perfis.length,
      projecoes: inventario.projecoes.length,
      uidsConhecidos: inventario.uidsConhecidos.length,
    },
  };
}

/// O relatorio em texto, para o runner imprimir.
///
/// Separado de `auditar` porque formatar nao e classificar: o teste prova a
/// classificacao sobre a ESTRUTURA, e nao sobre a aparencia de uma string.
export function relatorioComoTexto(r: Relatorio): string {
  const linhas: string[] = [];
  linhas.push("AUDITORIA DE IDENTIDADE PUBLICA — DRY-RUN (nada foi alterado)");
  linhas.push("");
  linhas.push(
    `conferidos: ${r.conferidos.identidades} identidades, ` +
      `${r.conferidos.reversos} reversos, ${r.conferidos.perfis} perfis, ` +
      `${r.conferidos.projecoes} projecoes competitivas, ` +
      `${r.conferidos.uidsConhecidos} uids conhecidos.`
  );
  linhas.push("");

  if (r.integro) {
    linhas.push("NENHUM ACHADO. As duas linhas convergem para a mesma identidade.");
    return linhas.join("\n");
  }

  linhas.push(`${r.achados.length} achado(s), dos quais ${r.criticos} critico(s).`);
  linhas.push("");
  for (const tipo of TIPOS) {
    const doTipo = r.achados.filter((a) => a.tipo === tipo);
    if (doTipo.length === 0) continue;
    linhas.push(`## ${tipo} (${doTipo.length})`);
    for (const a of doTipo) {
      linhas.push(`  [${a.severidade}] ${a.chave}`);
      linhas.push(`     ${a.detalhe}`);
      linhas.push(`     -> ${a.reconciliacao}`);
    }
    linhas.push("");
  }
  if (r.criticos > 0) {
    linhas.push(
      "HA CONFLITOS CRITICOS. §16.4 e §16.5: nenhum deles se resolve " +
        "automaticamente, e nenhuma migracao deve rodar antes de uma decisao " +
        "humana registrada."
    );
  }
  return linhas.join("\n");
}
