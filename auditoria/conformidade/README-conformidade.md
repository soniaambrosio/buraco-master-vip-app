# C8 — Conformidade Dart × Node (como reproduzir)

**Objetivo:** rodar os MESMOS vetores canônicos no motor Dart (`app/lib/rules/`) e
nas funções de regra do servidor deployado (`buraco-servidor/server.js`), e
classificar as divergências. Diagnóstico e documentação apenas — **o servidor
não é alterado nem sofre deploy**.

## Artefatos (nesta pasta, no repo do APP — nunca no repo do servidor)
- `servidor_regras_extraidas.js` — extrato VERBATIM e sem segredos das funções de
  regra do servidor (origem: `buraco-servidor/server.js@be72bb6`, sha256
  `c43c3e98…`). Só lógica pura: `validarSequencia`, `validarTrinca`, `validarJogo`,
  `finalizar`, `valorCarta`, `pontuarDupla` (adaptação pura de `pontuarDuplaJogo`).
- `node_harness.js` — roda os vetores no extrato e gera os dois arquivos abaixo.
- `resultados_node.json` — resultados do lado Node (proveniência).
- `../../app/test/conformidade_fixture.dart` — fixture lido pelo teste Dart
  (`c8FixtureJson`), com `hashRegrasNode` travando o extrato.

## Reproduzir o lado Node
```
node auditoria/conformidade/node_harness.js
```
Offline; não sobe o servidor, não abre porta, não acessa rede/produção.

## Portão no CI (lado Dart)
`app/test/teste_motor.dart` grupo **C8**: `C8-HASH` (confere `hashRegrasNode` +
`versaoSpec`) e `C8-CONFORMIDADE` (roda o motor canônico nos mesmos vetores e
exige que o conjunto de divergências críticas seja EXATAMENTE `{CRIT-01, CRIT-02}`).

## Segurança
Nada de `dados/`, `.env`, `contas.json`, avatares, tokens ou URLs de produção é
lido ou copiado. Vetores 100% sintéticos. Extrato revisado (sem I/O, sem rede).

## Regenerar o extrato a partir de um clone só-leitura
1. `git clone --depth 1 https://github.com/soniaambrosio/buraco-servidor` (só leitura).
2. Conferir `sha256sum server.js` e as linhas de origem no cabeçalho do extrato.
3. Rodar a varredura de segredos (grep por chave/token/senha/URL/process.env).
4. `node auditoria/conformidade/node_harness.js` e revisar o diff.
