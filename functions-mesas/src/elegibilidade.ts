// elegibilidade.ts — "HA ASSINATURA VIGENTE AGORA?", E SO ISSO.
//
// Modulo puro. Recebe o documento `playerEntitlements/{uid}` ja lido e o
// instante, e devolve um booleano.
//
// ===========================================================================
// ESTE ARQUIVO NAO E UM SEGUNDO LEITOR DE ASSINATURA
// ===========================================================================
//
// A OS proibe, com todas as letras, "criar outro leitor de assinatura". Vale a
// pena ser preciso sobre o que existe aqui e o que nao existe, porque a
// diferenca e a linha inteira:
//
//   O QUE NAO EXISTE AQUI: consulta a Google, interpretacao de RTDN, decisao
//   de estado, escrita em `playerEntitlements`, politica de carencia, mapa de
//   `SUBSCRIPTION_STATE_*`. Nada disso. A autoridade que PRODUZ o direito e o
//   codebase `billing`, e ela continua sendo a unica.
//
//   O QUE EXISTE AQUI: a leitura do documento que aquela autoridade ja
//   escreveu, aplicando a MESMA regra de vigencia que ela documenta —
//   estado com acesso E prazo ainda correndo.
//
// A alternativa seria `require("../functions-billing/entitlement")`, e ela nao
// serve: cada codebase e uma unidade de implantacao independente, com seu
// proprio `source` em firebase.json. Um `require` para fora do diretorio
// compila na bancada e quebra no deploy, que empacota so o diretorio do
// codebase.
//
// O preco de nao importar e o espelho poder envelhecer. O antidoto e
// `test/elegibilidade.test.js`, que LE `functions-billing/entitlement.js` e
// falha se a lista de estados com acesso divergir. E o mesmo padrao que
// `functions-conta/src/plano.ts` usa para `STATUS_INSCRICAO_ATIVA`.
//
// ===========================================================================
// A VIGENCIA E TEMPORAL, E POR ISSO ELA NAO SE GUARDA
// ===========================================================================
//
// `vipAtivo: true` gravado no documento NAO basta, e nao e por desconfianca do
// Billing: e porque o campo descreve o estado no instante em que foi escrito, e
// esse instante ja passou. Uma assinatura cancelada vigente tem `vipAtivo:
// true` e `expiraEm` no futuro — ate o dia em que `expiraEm` fica no passado,
// sem que ninguem escreva nada.
//
// E a mesma disciplina de `EntitlementVip.vigenteEm` no dominio Dart e do
// `PortaoVip`: guardar FATOS, recomputar a vigencia contra o relogio a cada
// leitura, nunca guardar `liberado: true`.

/// Estados do direito compativeis com TER acesso.
///
/// ESPELHO de `ESTADOS_COM_ACESSO` em `functions-billing/entitlement.js`.
/// Conferido por teste contra o arquivo original.
///
/// Os tres, e o motivo de cada um:
///   ativo ................ o caso comum;
///   em_carencia .......... a cobranca falhou e a Google ainda esta tentando;
///                          cortar o acesso aqui puniria quem trocou de cartao;
///   cancelado_vigente .... a renovacao foi desligada e o periodo JA PAGO
///                          continua valendo. Quem encerra e `expiraEm`.
export const ESTADOS_COM_ACESSO: readonly string[] = Object.freeze([
  "ativo",
  "em_carencia",
  "cancelado_vigente",
]);

/// O recorte de `playerEntitlements/{uid}` que esta autoridade le.
///
/// Deliberadamente estreito. `produto`, `origem`, `plano`, o token da compra e
/// a subcolecao `interno/billing` NAO sao lidos: eles pertencem ao Billing, e
/// ler o que nao se usa e o primeiro passo para depender do que nao se
/// deveria.
export type DocumentoEntitlement = {
  estado?: unknown;
  expiraEm?: unknown;
};

/// Ha assinatura VIP vigente neste instante?
///
/// Fecha em `false` para tudo que nao for claramente um direito vigente:
/// documento ausente, estado fora da lista, `expiraEm` ausente, `expiraEm` que
/// nao e data. Um direito que nao da para provar nao e um direito.
///
/// A fronteira e ESTRITA (`agora < expiraEm`): no instante exato do vencimento
/// o acesso ja acabou. Mesma escolha de `vigenteEm` e do passe de cortesia —
/// se as tres divergissem, o jogador veria comportamentos diferentes no mesmo
/// segundo.
export function assinaturaVigente(
  doc: DocumentoEntitlement | null | undefined,
  agora: string,
): boolean {
  if (!doc) return false;

  const estado = doc.estado;
  if (typeof estado !== "string" || !ESTADOS_COM_ACESSO.includes(estado)) return false;

  const expira = doc.expiraEm;
  if (typeof expira !== "string") return false;

  const fim = Date.parse(expira);
  const t = Date.parse(agora);
  if (!Number.isFinite(fim) || !Number.isFinite(t)) return false;

  return t < fim;
}
