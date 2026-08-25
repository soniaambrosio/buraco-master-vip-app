/**
 * campanha_chat_ritmo.js — O ARNES DA CAMPANHA NEGATIVA.
 *
 * OS 48 — Destino canonico de `chatRitmo/{uid}` na exclusao de conta v1.
 *
 *   uso (a partir da raiz do repositorio, com o emulador JA de pe):
 *     node ferramentas/exclusao/campanha_chat_ritmo.js
 *
 *   uso normal, que sobe o emulador uma vez so:
 *     bash ferramentas/exclusao/campanha.sh
 *
 * ===========================================================================
 * O QUE ESTE ARNES AFIRMA, E O QUE ELE RECUSA AFIRMAR
 * ===========================================================================
 *
 * Ele afirma UMA coisa por mutacao: com esta sabotagem aplicada, o portao
 * `contafn` (ou `contaemu`) REPROVA. Nao afirma que reprovou pelo caso certo —
 * para isso o laudo imprime o nome do caso que caiu, e o campo `mata` da
 * mutacao, lado a lado, para conferencia humana.
 *
 * O QUE ELE RECUSA A CHAMAR DE "PEGA":
 *
 *   1. ANCORA AUSENTE OU AMBIGUA. Se o trecho `de` nao ocorrer exatamente uma
 *      vez, a campanha inteira PARA com exit 2. A alternativa — seguir e contar
 *      como sobrevivente, ou pior, como pega — ja produziu laudo mentiroso em
 *      OS anterior desta arvore, quando uma ancora casou com o comentario da
 *      remocao em vez do codigo.
 *
 *   2. FALHA DE COMPILACAO. `tsc` reprovando NAO e a suite reprovando. Uma
 *      mutacao que nao compila e uma mutacao que nao foi testada, e ela sai no
 *      laudo como INVALIDA — nao como pega.
 *
 *   3. BASELINE VERMELHO. Antes da primeira mutacao, e depois da ultima, a
 *      arvore intacta tem de dar VERDE nos dois portoes. Sem esse cerco, uma
 *      campanha em que tudo reprova por um motivo alheio (dependencia faltando,
 *      emulador fora) se leria como 100% de mortalidade.
 *
 *   4. TIMEOUT. Um portao que estoura o prazo devolve status proprio e sai como
 *      INVALIDO. Contar timeout como reprovacao e o modo mais silencioso de uma
 *      campanha comprar cobertura que nao tem.
 *
 * ===========================================================================
 * A RESTAURACAO
 * ===========================================================================
 *
 * O conteudo original de cada arquivo e lido UMA vez, no comeco, e guardado em
 * memoria. Toda mutacao e desfeita restaurando o buffer inteiro — e nao
 * aplicando a troca inversa, que erraria em silencio se a mutacao tivesse
 * casado noutro lugar. `finally` restaura tudo mesmo se o processo falhar no
 * meio, e o fim da campanha confere byte a byte que a arvore voltou ao que era.
 */

"use strict";

const { execFileSync } = require("node:child_process");
const fs = require("node:fs");
const path = require("node:path");

const { MUTACOES } = require("./mutacoes_chat_ritmo");

const RAIZ = path.resolve(__dirname, "..", "..");
const CONTA = path.join(RAIZ, "functions-conta");

/// Prazo por execucao de portao. Generoso de proposito: o custo de um prazo
/// curto e um INVALIDO que parece escape.
const PRAZO_MS = 10 * 60 * 1000;

// ---------------------------------------------------------------------------
// EXECUCAO DE COMANDO
// ---------------------------------------------------------------------------

const RESULTADO = {
  VERDE: "verde",
  VERMELHO: "vermelho",
  INVALIDO: "invalido",
};

function rodar(comando, args, opcoes = {}) {
  try {
    const saida = execFileSync(comando, args, {
      cwd: opcoes.cwd || RAIZ,
      encoding: "utf8",
      timeout: PRAZO_MS,
      stdio: ["ignore", "pipe", "pipe"],
      shell: process.platform === "win32",
    });
    return { estado: RESULTADO.VERDE, saida };
  } catch (e) {
    // `killed` distingue prazo estourado de suite vermelha. Sem essa distincao,
    // um portao que travou entra no laudo como mutacao pega.
    if (e.killed || e.signal) {
      return { estado: RESULTADO.INVALIDO, saida: String(e.stdout || "") + String(e.stderr || ""), motivo: "prazo estourado" };
    }
    return {
      estado: RESULTADO.VERMELHO,
      saida: String(e.stdout || "") + String(e.stderr || ""),
    };
  }
}

/// Compila. Devolve `null` em sucesso, ou a mensagem do compilador.
function compilar() {
  const r = rodar("npx", ["tsc"], { cwd: CONTA });
  return r.estado === RESULTADO.VERDE ? null : r.saida.trim().split("\n").slice(0, 4).join(" | ");
}

/// Roda um portao e devolve o estado + os casos que cairam.
function portao(nome) {
  const args =
    nome === "contafn"
      ? [
          "--test",
          "test/inventario.test.js",
          "test/plano.test.js",
          "test/reautenticacao.test.js",
          "test/diario.test.js",
        ]
      : ["--test", "--test-name-pattern=freio de rajada", "test/integracao.emulador.test.js"];

  const r = rodar("node", args, { cwd: CONTA });
  return { ...r, casos: casosQueCairam(r.saida) };
}

/// Os nomes dos casos reprovados, lidos do relatorio do `node --test`.
function casosQueCairam(saida) {
  const nomes = [];
  const re = /^\s*✖ (.+?) \(\d/gm;
  let m;
  while ((m = re.exec(saida)) !== null) {
    const nome = m[1].trim();
    if (!nomes.includes(nome)) nomes.push(nome);
  }
  return nomes;
}

// ---------------------------------------------------------------------------
// A ARVORE ORIGINAL
// ---------------------------------------------------------------------------

const ARQUIVOS = [...new Set(MUTACOES.map((m) => m.arquivo))];
const ORIGINAL = new Map();
for (const rel of ARQUIVOS) {
  ORIGINAL.set(rel, fs.readFileSync(path.join(RAIZ, rel), "utf8"));
}

function restaurarTudo() {
  for (const [rel, conteudo] of ORIGINAL) {
    fs.writeFileSync(path.join(RAIZ, rel), conteudo);
  }
}

/// Aplica UMA mutacao, com a mesma exigencia nas duas formas de ancora: exatamente
/// uma ocorrencia.
///
/// `de` e literal e e a forma padrao. `deRegex` existe para o caso em que o
/// trecho a substituir e um VALOR INTEIRO longo demais para copiar — a
/// justificativa da matriz, por exemplo, tem mais de mil caracteres, e uma
/// mutacao que so trocasse o comeco dela seria mutante EQUIVALENTE: o argumento
/// continuaria escrito, e um "escape" desses nao mede cobertura nenhuma.
function aplicar(mutacao) {
  const alvo = path.join(RAIZ, mutacao.arquivo);
  const texto = ORIGINAL.get(mutacao.arquivo);

  if (mutacao.deRegex) {
    const re = new RegExp(mutacao.deRegex, "g");
    const achados = texto.match(re);
    if (!achados) {
      throw new Error(`${mutacao.id}: ancora (regex) AUSENTE em ${mutacao.arquivo}`);
    }
    if (achados.length > 1) {
      throw new Error(
        `${mutacao.id}: ancora (regex) AMBIGUA em ${mutacao.arquivo} (${achados.length} ocorrencias)`
      );
    }
    fs.writeFileSync(alvo, texto.replace(new RegExp(mutacao.deRegex), mutacao.para));
    return;
  }

  const partes = texto.split(mutacao.de);
  if (partes.length === 1) {
    throw new Error(`${mutacao.id}: ancora AUSENTE em ${mutacao.arquivo}`);
  }
  if (partes.length > 2) {
    throw new Error(
      `${mutacao.id}: ancora AMBIGUA em ${mutacao.arquivo} (${partes.length - 1} ocorrencias)`
    );
  }
  fs.writeFileSync(alvo, partes[0] + mutacao.para + partes[1]);
}

// ---------------------------------------------------------------------------
// A CAMPANHA
// ---------------------------------------------------------------------------

function linha(c = "-") {
  return c.repeat(78);
}

function main() {
  console.log(linha("="));
  console.log("CAMPANHA NEGATIVA — destino de `chatRitmo/{uid}` na exclusao de conta");
  console.log(linha("="));

  // --- cerco 1: a arvore intacta e verde nos dois portoes -------------------
  const erroBase = compilar();
  if (erroBase) {
    console.error("BASELINE INVALIDO: a arvore intacta nao compila.");
    console.error(erroBase);
    return 2;
  }
  for (const nome of ["contafn", "contaemu"]) {
    const r = portao(nome);
    if (r.estado !== RESULTADO.VERDE) {
      console.error(`BASELINE VERMELHO em ${nome}: a campanha nao mede nada assim.`);
      console.error(r.casos.join("\n") || r.saida.slice(-2000));
      return 2;
    }
    console.log(`baseline ${nome}: VERDE`);
  }

  // --- as mutacoes ----------------------------------------------------------
  const laudo = [];
  try {
    for (const m of MUTACOES) {
      restaurarTudo();
      aplicar(m);

      const erro = compilar();
      if (erro) {
        laudo.push({ ...m, veredito: "INVALIDA", detalhe: `nao compila: ${erro}` });
        console.log(`${m.id}  INVALIDA (nao compila)`);
        continue;
      }

      const r = portao(m.portao);
      if (r.estado === RESULTADO.VERMELHO) {
        laudo.push({ ...m, veredito: "PEGA", detalhe: r.casos.join(" ; ") || "(caso nao nomeado)" });
        console.log(`${m.id}  PEGA      [${m.portao}]  ${r.casos[0] || ""}`);
      } else if (r.estado === RESULTADO.INVALIDO) {
        laudo.push({ ...m, veredito: "INVALIDA", detalhe: r.motivo || "execucao invalida" });
        console.log(`${m.id}  INVALIDA (${r.motivo})`);
      } else {
        laudo.push({ ...m, veredito: "ESCAPE", detalhe: "o portao ficou VERDE com a sabotagem aplicada" });
        console.log(`${m.id}  ESCAPE    [${m.portao}]  <<< o portao nao viu`);
      }
    }
  } finally {
    restaurarTudo();
  }

  // --- cerco 2: a arvore voltou, byte a byte --------------------------------
  for (const [rel, conteudo] of ORIGINAL) {
    const agora = fs.readFileSync(path.join(RAIZ, rel), "utf8");
    if (agora !== conteudo) {
      console.error(`RESTAURACAO FALHOU em ${rel}`);
      return 2;
    }
  }
  const erroFim = compilar();
  if (erroFim) {
    console.error("a arvore restaurada nao compila — a campanha deixou residuo.");
    return 2;
  }
  console.log("arvore restaurada byte a byte: OK");

  // --- o laudo --------------------------------------------------------------
  const escapes = laudo.filter((l) => l.veredito === "ESCAPE");
  const invalidas = laudo.filter((l) => l.veredito === "INVALIDA");
  const pegas = laudo.filter((l) => l.veredito === "PEGA");

  console.log("");
  console.log(linha("="));
  console.log(`LAUDO: ${pegas.length} pegas, ${escapes.length} escapes, ${invalidas.length} invalidas, de ${MUTACOES.length}`);
  console.log(linha("="));
  for (const l of laudo) {
    console.log(`${l.id}  ${l.veredito.padEnd(9)} ${l.portao}`);
    console.log(`      esperado: ${l.mata}`);
    console.log(`      observado: ${l.detalhe}`);
  }

  if (escapes.length > 0 || invalidas.length > 0) {
    console.error("");
    console.error("CAMPANHA REPROVADA: escape ou mutacao invalida.");
    return 1;
  }
  console.log("");
  console.log("CAMPANHA APROVADA: nenhuma sabotagem sobreviveu.");
  return 0;
}

process.exit(main());
