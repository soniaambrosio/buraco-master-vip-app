'use strict';
/**
 * A SUPERFÍCIE DE IMPLANTAÇÃO DO BILLING — declarada UMA vez.
 *
 * ============================================================================
 * POR QUE ESTE ARQUIVO NASCE
 * ============================================================================
 *
 * A composição canônica uniu duas linhagens de billing, e cada uma trouxe a
 * própria lista de funções implantadas:
 *
 *   linhagem comercial (propriedade opaca da compra)
 *       7 exports, com `prepararCompraPlay` e `migrarEntitlementsLegado`
 *
 *   linhagem P0 (censo, backfill de hash, diagnóstico)
 *       8 exports, com as três ferramentas administrativas, e SEM a migração —
 *       retirada por decisão de segurança registrada em `index.js`
 *
 * O merge produziu a união correta (9 exports: a migração ficou de fora, como a
 * decisão manda), mas deixou DUAS listas escritas à mão para descrevê-la:
 * `SUPERFICIE_PRODUCAO`, em `superficieDeploy.test.js`, já atualizada; e a lista
 * literal dentro do caso `X2` de `adversarial.test.js`, herdada da linhagem
 * comercial e nunca revista.
 *
 * Duas autoridades para a mesma coisa é o defeito, e não o sintoma. Enquanto
 * existirem duas, alterar a superfície torna uma delas mentirosa — e qual das
 * duas mente não é decidível lendo o código.
 *
 * NÃO É AFROUXAMENTO. As duas provas continuam existindo e continuam medindo o
 * que mediam: `superficieDeploy.test.js` confere o que o projeto implanta, `X2`
 * confere o que o módulo exporta. O que deixou de existir é a SEGUNDA CÓPIA da
 * relação — é exatamente o mesmo remédio que a fonte única de gates do CI
 * aplicou ao portão.
 */

/**
 * As seis funções que PODEM existir no projeto implantado.
 *
 * Mudar esta lista é decisão de produto, não de arrumação: cada entrada é uma
 * unidade que recebe tráfego real de pagante ou escreve no direito VIP.
 */
const SUPERFICIE_PRODUCAO = [
  // [COMPOSICAO canonica] DECISAO DE SUPERFICIE, e nao heranca de merge.
  //
  // `prepararCompraPlay` chegou com a correcao P0 da propriedade da compra. Ela
  // e quem EMITE o identificador opaco que o cliente entrega a Play como
  // `obfuscatedAccountId`, e sem o qual a Google nao devolve vinculo nenhum na
  // resposta autoritativa. Deixa-la fora do deploy nao seria 'menos superficie':
  // seria toda compra chegando sem dono e `validarCompraPlay` recusando com
  // `vinculo_ausente` — a loja parada, e por um motivo que ninguem ligaria ao
  // alvo de deploy.
  //
  // Nao e credencial e nao e escolhivel pelo cliente (o payload da chamada nem e
  // lido), entao expo-la nao devolve poder a quem tem o token.
  'prepararCompraPlay',
  'validarCompraPlay',
  'notificacoesPlay',
  'reconciliarEntitlements',
  'concederFichasMensais',
  'reconciliarEntitlementDoJogador',
];

/**
 * Ferramentas administrativas: existem no fonte, NÃO são implantadas.
 *
 * Todas exigem `claim` de admin, e o backfill exige ainda uma frase de
 * confirmação. Mesmo assim ficam fora do projeto: o portão de admin protege
 * quem chama, e não remove a superfície de quem nunca deveria estar exposto.
 */
const FERRAMENTAS_ADMIN = [
  'diagnosticarPopulacaoVip',
  'backfillPurchaseTokenHash',
  'diagnosticarMetadadosLegados',
];

/**
 * O que `index.js` exporta: a superfície implantável mais as ferramentas.
 *
 * Derivado, e não uma terceira lista — é o que `X2` compara contra o módulo
 * carregado de verdade.
 */
const EXPORTS_DO_MODULO = [...SUPERFICIE_PRODUCAO, ...FERRAMENTAS_ADMIN].sort();

/**
 * O que foi RETIRADO, e por quê.
 *
 * Uma lista de ausências parece cerimônia até o dia em que alguém reexporta um
 * dos nomes "porque o teste antigo falava dele". `X2` compara contra
 * `EXPORTS_DO_MODULO`, então a volta de qualquer um destes já reprova; o que
 * esta relação acrescenta é o MOTIVO, no lugar onde a pergunta aparece.
 */
const RETIRADOS = {
  migrarEntitlementsLegado:
    'Retirada por SEGURANCA, e nao por arrumacao (ver index.js): era callable de ' +
    'escrita em massa sobre `playerEntitlements/`, a colecao que decide quem tem ' +
    'VIP. O censo mediu a populacao legada e ela e ZERO — `usuarios/` sem nenhum ' +
    'portador, `playerEntitlements/` vazia, `compras/` sem compra real. ' +
    'Ferramenta de migracao sem finalidade remanescente e superficie de ataque ' +
    'pura: o risco fica, o beneficio nao existe. O MODULO CONTINUA NA ARVORE — ' +
    '`migracaoLegado.js` e `test/migracao.test.js` seguem como biblioteca ' +
    'dormente e testada. O que se retirou foi a EXPOSICAO.',
};

module.exports = { SUPERFICIE_PRODUCAO, FERRAMENTAS_ADMIN, EXPORTS_DO_MODULO, RETIRADOS };
