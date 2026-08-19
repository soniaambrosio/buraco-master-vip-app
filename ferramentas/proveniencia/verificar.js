#!/usr/bin/env node
'use strict';
/**
 * VERIFICADOR da proveniência. Roda DEPOIS do gerador e ANTES do deploy.
 *
 *   uso: node ferramentas/proveniencia/verificar.js [--raiz <dir>]
 *
 * A verificação não confere campos: ela RE-RENDERIZA o conteúdo esperado a
 * partir de `git rev-parse HEAD` e compara BYTE A BYTE. É isso que torna
 * indetectável-impossível um SHA plausível digitado à mão — não existe valor
 * manual que sobreviva a uma comparação com o que o git diz agora.
 *
 * As cinco formas de ficar verde por omissão estão fechadas, cada uma com caso
 * próprio na suíte:
 *
 *   • codebase sem arquivo ................ reprova (não é "nada a verificar")
 *   • arquivo com SHA de outro commit ..... reprova (byte a byte)
 *   • arquivo editado à mão ............... reprova (byte a byte)
 *   • codebases carimbadas com SHA DIFERENTE entre si .... reprova
 *   • arquivo sobrando, de codebase que saiu do firebase.json ... reprova
 *
 * Exit codes: 0 tudo confere; 1 divergência; 2 erro de uso/ambiente.
 */

const fs = require('node:fs');
const path = require('node:path');
const P = require('./proveniencia.js');

function principal(argv) {
  let raiz = P.RAIZ;
  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === '--raiz') {
      raiz = path.resolve(argv[++i] || '');
      continue;
    }
    console.error(`verificar.js: argumento nao aceito: ${JSON.stringify(argv[i])}`);
    return 2;
  }

  const sha = P.shaDaArvore(raiz);
  const lista = P.codebases(raiz);
  const problemas = [];

  for (const { codebase, source } of lista) {
    const destino = P.caminho(raiz, source);
    if (!fs.existsSync(destino)) {
      problemas.push(`${codebase}: SEM proveniencia (${source}/${P.NOME_DO_ARQUIVO} ausente)`);
      continue;
    }
    const lido = fs.readFileSync(destino, 'utf8');
    const esperado = P.conteudo({ sha, codebase, source });
    if (lido !== esperado) {
      // Só para a mensagem — a DECISÃO já foi tomada pela comparação de bytes.
      let dica = 'conteudo diverge do render canonico';
      try {
        const j = JSON.parse(lido);
        if (j.sha && j.sha !== sha) dica = `carimbado com ${j.sha}, e HEAD e ${sha}`;
        else if (j.codebase !== codebase) dica = `carimbado como codebase ${j.codebase}`;
        else dica = 'mesmo sha, porem bytes diferentes (editado a mao?)';
      } catch { dica = 'nao e JSON valido'; }
      problemas.push(`${codebase}: ${dica}`);
      continue;
    }
  }

  // A DIVERGÊNCIA ENTRE CODEBASES — nove deploys separados carregando nove
  // códigos diferentes — é o defeito que motiva tudo isto, e ela NÃO ganha
  // verificação própria aqui. De propósito: cada arquivo é comparado contra o
  // render de `git rev-parse HEAD`, então a codebase que ficou para trás já
  // reprova sozinha, no laço acima. Uma segunda checagem do tipo "todos os SHAs
  // são iguais entre si" seria INALCANÇÁVEL — só chegaria nela o caso em que
  // todos já são iguais a HEAD —, e guarda inalcançável é guarda que ninguém
  // consegue provar. PROV-09 mede a divergência pelo caminho que existe.

  // Arquivo sobrando: uma pasta que saiu do firebase.json e ficou com carimbo
  // continuaria parecendo implantável e provada. Não fica.
  const declaradas = new Set(lista.map((c) => c.source));
  for (const entrada of fs.readdirSync(raiz, { withFileTypes: true })) {
    if (!entrada.isDirectory()) continue;
    const p = path.join(raiz, entrada.name, P.NOME_DO_ARQUIVO);
    if (fs.existsSync(p) && !declaradas.has(entrada.name)) {
      problemas.push(`${entrada.name}: proveniencia SOBRANDO — a pasta nao esta em firebase.json`);
    }
  }

  if (problemas.length > 0) {
    console.error('PROVENIENCIA REPROVADA:');
    for (const p of problemas) console.error(`  - ${p}`);
    return 1;
  }

  console.log(`proveniencia OK: ${lista.length} codebase(s), todas em ${sha}`);
  return 0;
}

if (require.main === module) {
  try {
    process.exit(principal(process.argv.slice(2)));
  } catch (e) {
    console.error(`verificar.js: ${e.message}`);
    process.exit(2);
  }
}

module.exports = { principal };
