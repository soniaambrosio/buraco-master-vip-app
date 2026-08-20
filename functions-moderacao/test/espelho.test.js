/**
 * espelho.test.js — o dominio de comunicacao NAO pode divergir da AUTORIDADE
 * DOS TIPOS DE MESA.
 *
 * ===========================================================================
 * POR QUE EXISTE UM ESPELHO, E POR QUE ELE NAO E PREGUICA
 * ===========================================================================
 *
 * `app/lib/comunicacao/ambiente.dart` precisa traduzir o par de dimensoes do
 * servidor (`tipoPartida` x `categoriaCompetitiva`) num tipo de mesa, e o tipo
 * de mesa num ambiente. Essa traducao JA EXISTE, em
 * `functions-mesas/src/tipos.ts` (`traduzirDoServidor`), e aquela e a
 * autoridade.
 *
 * A alternativa a copiar seria importar. Ela nao serve, e o motivo e de
 * implantacao: cada codebase de Functions tem `source` proprio em
 * firebase.json, e o `firebase deploy` empacota SO o diretorio do codebase. Um
 * `require("../functions-mesas/src/tipos")` compila na bancada e quebra no
 * deploy. E o mesmo raciocinio — com as mesmas palavras — que
 * `functions-mesas/src/elegibilidade.ts` ja registra para
 * `ESTADOS_COM_ACESSO`, e que `functions-conta/src/plano.ts` registra para
 * `STATUS_INSCRICAO_ATIVA`.
 *
 * O preco de nao importar e o espelho envelhecer em silencio. ESTE ARQUIVO E O
 * ANTIDOTO: ele LE os arquivos originais como texto e reprova se qualquer valor
 * divergir.
 *
 * A VARREDURA E SOBRE CODIGO, e nao sobre prosa: os dois arquivos explicam em
 * comentario o que fazem, e procurar no texto cru daria falso positivo em cima
 * da propria explicacao.
 */

"use strict";

const test = require("node:test");
const { describe } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("fs");
const path = require("path");

const RAIZ = path.resolve(__dirname, "..", "..");

const TIPOS_TS = fs.readFileSync(
  path.join(RAIZ, "functions-mesas", "src", "tipos.ts"),
  "utf8"
);
const POLITICA_TS = fs.readFileSync(
  path.join(RAIZ, "functions-mesas", "src", "politica.ts"),
  "utf8"
);
const AMBIENTE_DART = fs.readFileSync(
  path.join(RAIZ, "app", "lib", "comunicacao", "ambiente.dart"),
  "utf8"
);

/** Tira comentario de linha e de bloco. Mantem string, que aqui interessa. */
function soCodigo(fonte) {
  return fonte
    .replace(/\/\*[\s\S]*?\*\//g, " ")
    .replace(/^[ \t]*\/\/\/.*$/gm, " ")
    .replace(/^[ \t]*\/\/.*$/gm, " ");
}

const TIPOS = soCodigo(TIPOS_TS);
const POLITICA = soCodigo(POLITICA_TS);
const AMBIENTE = soCodigo(AMBIENTE_DART);

// A trava contra si mesma: se o recorte comer o arquivo, toda assercao de
// presenca passaria por vacuidade e este arquivo viraria decoracao.
describe("ESP-0 — o recorte nao comeu os arquivos", () => {
  test("ESP-00 sobra codigo suficiente nos tres", () => {
    assert.ok(TIPOS.length > 800, "tipos.ts virou nada depois do recorte");
    assert.ok(POLITICA.length > 800, "politica.ts virou nada");
    assert.ok(AMBIENTE.length > 800, "ambiente.dart virou nada");
  });
});

describe("ESP-A — os quatro tipos de mesa", () => {
  test("ESP-A-01 os valores de `TIPO_MESA` sao os que o dominio espelha", () => {
    // O lado TS: `PUBLICA: "publica"`, etc.
    const esperado = {
      PUBLICA: "publica",
      VIP_RANQUEADA: "vipRanqueada",
      PRIVADA: "privada",
      TREINO: "treino",
    };
    for (const [chave, valor] of Object.entries(esperado)) {
      assert.match(
        TIPOS,
        new RegExp(chave + ':\\s*"' + valor + '"'),
        "functions-mesas/src/tipos.ts nao declara " + chave + ' = "' + valor + '"'
      );
    }

    // O lado Dart: as constantes nomeadas de ambiente.dart.
    const dart = {
      kTipoMesaPublica: "publica",
      kTipoMesaVipRanqueada: "vipRanqueada",
      kTipoMesaPrivada: "privada",
      kTipoMesaTreino: "treino",
    };
    for (const [nome, valor] of Object.entries(dart)) {
      assert.match(
        AMBIENTE,
        new RegExp("const String " + nome + " = '" + valor + "';"),
        "ambiente.dart nao espelha " + nome
      );
    }
  });

  test("ESP-A-02 nenhum tipo novo entrou sem espelho", () => {
    // Conta as chaves do objeto `TIPO_MESA` no TS. Um quinto tipo criado la
    // reprova aqui — que e o unico jeito de a ausencia de um espelho aparecer.
    const bloco = TIPOS.slice(
      TIPOS.indexOf("export const TIPO_MESA = {"),
      TIPOS.indexOf("} as const;", TIPOS.indexOf("export const TIPO_MESA = {"))
    );
    const chaves = [...bloco.matchAll(/^\s*([A-Z_]+):\s*"/gm)].map((m) => m[1]);
    assert.deepEqual(chaves.sort(), [
      "PRIVADA",
      "PUBLICA",
      "TREINO",
      "VIP_RANQUEADA",
    ]);
  });
});

describe("ESP-B — as duas dimensoes do servidor", () => {
  test("ESP-B-01 topologia e categoria tem os mesmos valores nos dois lados", () => {
    for (const [chave, valor] of Object.entries({
      PUBLICA: "publica",
      PRIVADA: "privada",
      SIMULADA: "simulada",
    })) {
      assert.match(TIPOS, new RegExp(chave + ':\\s*"' + valor + '"'));
    }
    for (const [nome, valor] of Object.entries({
      kTopologiaPublica: "publica",
      kTopologiaPrivada: "privada",
      kTopologiaSimulada: "simulada",
      kCategoriaCasual: "casual",
      kCategoriaVipRanqueada: "vip_ranqueada",
    })) {
      assert.match(
        AMBIENTE,
        new RegExp("const String " + nome + " = '" + valor + "';"),
        "ambiente.dart nao espelha " + nome
      );
    }
  });

  test("ESP-B-02 a TABELA de traducao e a mesma, linha por linha", () => {
    // O caso decisivo e `privada x vip_ranqueada`, que NAO resolve: seria sala
    // fechada alimentando o Ranking. Se um dos lados passasse a resolve-lo, o
    // outro concederia o ambiente errado — e o errado aqui e o unico com texto
    // livre.
    //
    // A COMPARACAO E TEXTUAL, e nao por execucao, de proposito: executar
    // exigiria carregar o bundle Dart (`npm run build:domain`), e esta suite
    // nao pode depender de `dart compile js` — e a mesma regra que o
    // package.json ja declara para os outros arquivos puros. O que se compara
    // aqui e a FONTE das duas autoridades.
    // O recorte vai de um `export` ao PROXIMO, e nao ate um comentario: o
    // `soCodigo` acima ja apagou os comentarios, entao procurar por um deles
    // aqui devolveria -1 — e um `slice(i, -1)` silencioso comeria a ultima
    // chave da funcao, fazendo a assercao final falhar por um motivo que nao
    // tem nada a ver com o que ela mede.
    const inicioTs = TIPOS.indexOf("export function traduzirDoServidor");
    const tsTraducao = TIPOS.slice(
      inicioTs,
      TIPOS.indexOf("export ", inicioTs + 10)
    );
    const dartTraducao = AMBIENTE.slice(
      AMBIENTE.indexOf("String? tipoDeMesaDoServidor"),
      AMBIENTE.indexOf("AmbienteDeComunicacao? ambienteDoServidor")
    );

    assert.ok(tsTraducao.length > 200, "traduzirDoServidor nao foi localizada");
    assert.ok(dartTraducao.length > 200, "tipoDeMesaDoServidor nao foi localizada");

    // Cada fato da tabela vira um PAR de buscas: uma no TypeScript, uma no
    // Dart. Um lado que mude sem o outro deixa um dos dois sem casar.
    const fatos = [
      // 1. SIMULADA resolve ANTES da categoria, nos dois lados. Deixar a
      //    categoria mandar aqui faria uma mesa simulada mal configurada virar
      //    ambiente competitivo.
      [/SIMULADA\)\s*return TIPO_MESA\.TREINO/, /kTopologiaSimulada\)\s*return kTipoMesaTreino/],
      // 2. PUBLICA x casual -> publica.
      [/CASUAL\)\s*return TIPO_MESA\.PUBLICA/, /kCategoriaCasual\)\s*return kTipoMesaPublica/],
      // 3. PUBLICA x vip_ranqueada -> vipRanqueada.
      [
        /VIP_RANQUEADA\)\s*return TIPO_MESA\.VIP_RANQUEADA/,
        /kCategoriaVipRanqueada\)\s*\{[\s\S]{0,60}return kTipoMesaVipRanqueada/,
      ],
      // 4. PRIVADA x casual -> privada, e SO casual.
      [
        /PRIVADA\)\s*\{[\s\S]{0,400}CASUAL\)\s*return TIPO_MESA\.PRIVADA;/,
        /kTopologiaPrivada\)\s*\{[\s\S]{0,400}kCategoriaCasual\)\s*return kTipoMesaPrivada;/,
      ],
    ];
    for (const [naTs, noDart] of fatos) {
      assert.match(tsTraducao, naTs, "tipos.ts nao casa com " + naTs);
      assert.match(dartTraducao, noDart, "ambiente.dart nao casa com " + noDart);
    }

    // 5. Nenhum dos dois tem um `default` que conceda: o ultimo `return` e
    //    `null` nos dois. E o que garante que uma combinacao nova nasca
    //    RECUSADA em vez de cair no primeiro ramo parecido.
    assert.match(tsTraducao.trim(), /return null;\s*\}$/);
    assert.match(dartTraducao.trim(), /return null;\s*\}$/);
  });
});

describe("ESP-C — a configuracao de chat", () => {
  test("ESP-C-01 os tres modos tem os mesmos valores nos dois lados", () => {
    // `CHATS_CANONICOS` em politica.ts x `ModoDeComunicacao` em ambiente.dart.
    for (const valor of ["completo", "apenas_emotes", "desligado"]) {
      assert.ok(
        POLITICA.includes('"' + valor + '"'),
        "politica.ts nao declara " + valor
      );
      assert.ok(
        AMBIENTE.includes("('" + valor + "')"),
        "ambiente.dart nao declara " + valor
      );
    }
  });

  test("ESP-C-02 `completo` e exclusivo da Privada NOS DOIS LADOS", () => {
    // Lado da AUTORIDADE DOS TIPOS: `chatsPermitidos` devolve o vocabulario
    // inteiro so para a Privada.
    assert.match(
      POLITICA,
      /export function chatsPermitidos[\s\S]{0,400}TIPO_MESA\.PRIVADA[\s\S]{0,80}CHATS_CANONICOS/,
      "politica.ts nao restringe `completo` a Privada"
    );
    assert.match(
      POLITICA,
      /return Object\.freeze\(\["apenas_emotes", "desligado"\]\)/,
      "politica.ts nao devolve a lista restrita para os demais tipos"
    );

    // Lado da AUTORIDADE DE COMUNICACAO: `modoPermitidoNoAmbiente` responde
    // `true` para `completo` SO na Mesa Privada, e `permissaoDe` so devolve
    // texto livre naquele par.
    //
    // A leitura aqui e textual pela mesma razao de ESP-B-02 (esta suite nao
    // carrega o bundle Dart). O COMPORTAMENTO das duas funcoes e provado por
    // execucao em app/test/comunicacao/comunicacao_test.dart — MAT-01 e MAT-04.
    // Este caso guarda a FONTE; aquele guarda o resultado.
    assert.match(
      AMBIENTE,
      /if \(modo == ModoDeComunicacao\.completo\) \{\s*return ambiente == AmbienteDeComunicacao\.mesaPrivada;/,
      "ambiente.dart nao restringe `completo` a Mesa Privada"
    );
    assert.match(
      AMBIENTE,
      /case AmbienteDeComunicacao\.mesaPrivada:[\s\S]{0,300}ModoDeComunicacao\.completo =>[\s\S]{0,120}textoLivre: true/,
      "ambiente.dart nao concede texto livre na Mesa Privada"
    );
    // E o par mesaPublica/mesaVip NAO tem `textoLivre: true` em ramo nenhum.
    const ramoDasMesasControladas = AMBIENTE.slice(
      AMBIENTE.indexOf("case AmbienteDeComunicacao.mesaPublica:"),
      AMBIENTE.indexOf("case AmbienteDeComunicacao.mesaPrivada:")
    );
    assert.ok(ramoDasMesasControladas.length > 100, "ramo nao localizado");
    assert.equal(
      ramoDasMesasControladas.includes("textoLivre: true"),
      false,
      "Mesa Publica/VIP ganhou texto livre"
    );
  });

  test("ESP-C-03 o padrao da configuracao NAO e `completo`", () => {
    // O padrao anterior era `completo`, e concedia texto livre a quem nao pediu
    // nada — inclusive na Mesa Publica.
    assert.match(
      POLITICA,
      /let chat = tem\(CAMPO\.CHAT\) \? "apenas_emotes" : "desligado";/,
      "politica.ts voltou a ter padrao `completo`"
    );
  });
});
