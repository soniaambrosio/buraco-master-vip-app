# Bloco 1 — Fechar o Motor de Partidas — evidência de validação

OS "Integração Final Backend ↔ Flutter". Base: `claude/motor-partidas-resiliencia-3a775f`
(`6917331`). Branch de integração: `integracao/os-final-backend-flutter`.
Data da execução: **10/08/2026**.

Este documento existe porque a §18 da OS exige que o que não rodou seja
declarado como **NÃO EXECUTADO com motivo**, e nunca contado como verde. Ele
registra as duas coisas: o que rodou e passou, e o que não rodou e por quê.

---

## 1. O que foi entregue

Quatro commits, **somente aditivos** (+484 linhas, nenhuma removida):

| Commit | Conteúdo |
|---|---|
| `3673316` | `.github/workflows/ci-os-integracao.yml` — pipeline de validação da OS |
| `ba8aec1` | `app/lib/motor/encerramento_partida.dart` + `MotorPartida.encerramento` |
| `6a22e15` | `app/test/teste_encerramento.dart` — ENCERR-01..07 |
| `0eeba69` | correção do cabeçalho de status da suíte, após a execução real |

O patch `0001` do hand-off **não existia como `.patch`**: veio como arquivo
solto `ci-os-integracao.yml`, e foi reconstruído em commit próprio, com o mesmo
conteúdo. Os patches `0002` e `0003` aplicaram limpo (`git am --keep-cr`).

---

## 2. EXECUTADO — validação local (evidência aceita pela Sônia em 10/08/2026)

Harness idêntico ao do CI: `flutter create` + overlay de `app/lib` sobre
`app_build/` (diretório gitignorado), cópia das suítes e dos seeds de torneios.
Toolchain da máquina: **Flutter 3.41.4 / Dart 3.11.1** (o CI pina 3.44.8 — ver
a ressalva na §4).

```
flutter analyze --no-fatal-infos --no-fatal-warnings ....... exit 0

   0 ERROS.
   105 issues, todas info/warning e todas PRÉ-EXISTENTES, concentradas em
   lib/screens (deprecated_member_use de withOpacity/activeColor,
   unnecessary_underscores, dois unused_field). Nenhuma em lib/motor/.

flutter test test/teste_motor.dart ......................... 132 verdes
flutter test test/teste_motor_resiliencia.dart ............. 181 verdes
flutter test test/torneios/reward_grants_test.dart .........  80 verdes
flutter test test/teste_encerramento.dart ..................   7 verdes
                                                             ────────────
                                                             400 verdes
```

A suíte nova, item a item:

| Caso | O que prova |
|---|---|
| ENCERR-01 | partida não encerrada → a porta é `null` (nunca desfecho inventado) |
| ENCERR-02 | encerrada → vencedora é a dupla de maior placar; `versaoEstado` e `partidaId` atravessam |
| ENCERR-03 | a vencedora vem do PLACAR, não de quem bateu a última rodada |
| ENCERR-04 | `metaPontos` e `modalidade` atravessam; `duplaQueBateu` ausente vira `null` |
| ENCERR-05 | `toJson`/`deJson` ida e volta preserva o desfecho |
| ENCERR-06 | `deJson` recusa envelope inválido (id vazio, vencedora fora de {nos,eles}, versão não numérica) |
| ENCERR-07 | varredura: o desfecho não carrega nenhum id de carta |

Conferência manual complementar: o comentário do DTO afirma que só existe
vencedor único quando a partida encerra. Isso confere com `app/lib/mesa.dart`,
que só marca `encerrada` quando `(n >= metaPontos || e >= metaPontos) && n != e`
— empate exato na meta força rodada extra. Logo o desempate defensivo
`nos >= eles` do DTO nunca decide nada no caminho real.

---

## 3. NÃO EXECUTADO — GitHub Actions (§18)

**O portão de CI da OS não rodou, e não pôde rodar.** Motivo técnico, medido
neste repositório:

1. **Push não dispara run.** Os runs do repositório são todos
   `event: workflow_dispatch`. Uma branch já foi publicada antes com um workflow
   declarando `on: push`, e o GitHub não criou run algum — nem check-run, nem
   erro visível.
2. **`workflow_dispatch` só aparece para workflows presentes na branch padrão.**
   Um workflow novo, criado numa branch de trabalho, não é dispachável enquanto
   não chegar em `main`.

Combinando as duas: `ci-os-integracao.yml` só ficaria dispachável depois de um
merge em `main` — que a própria OS proíbe (§21, "sem merge em `main` nem em
`consolidacao/*`"). **A condição "só concluir o bloco após CI verde" é, hoje,
inalcançável neste repositório.** É uma contradição interna da OS, não uma falha
do bloco.

Decisão da Sônia em 10/08/2026: **aceitar a execução local da §2 como evidência
do Bloco 1**, e **não** alterar `main` só para destravar o `workflow_dispatch`.
O workflow fica commitado e pronto; quando a autoridade de validação for
resolvida, ele roda sem alteração.

Consequência honesta: os gates abaixo continuam **NÃO EXECUTADOS**.

| Gate do workflow | Status | Motivo |
|---|---|---|
| `analyze` + 4 suítes **no runner do CI** | NÃO EXECUTADO | workflow não dispachável (acima). Equivalente rodado localmente — §2 |
| Emulator Suite (Firestore Rules / Functions / Auth) | NÃO EXECUTADO | a branch ainda não tem `firebase.json`/`firestore.rules`/`functions`; chegam nos blocos de consolidação. O próprio workflow já reporta isso como NÃO EXECUTADO, nunca como "passou" |
| Publicação de evidência em `ci-evidencias` | NÃO EXECUTADO | depende do run |

---

## 4. Ressalvas registradas

- **Versão do toolchain:** a validação da §2 rodou em Flutter 3.41.4; o workflow
  pina 3.44.8. As suítes são de lógica pura (sem widget), então a divergência é
  de baixo risco — mas não é zero, e continua não medida.
- **`MotorPartida.jogo` segue público.** Privatizar tocaria a UI; o hand-off
  tratou isso como pendência documentada e não como mudança destrutiva (§25). A
  porta canônica existe; a barreira de compilador, não.
- **Duplicidade de contrato a resolver antes do Bloco 4.** A branch
  `integracao/motores-torneios-partidas-v1` já contém
  `app/lib/motor/desfecho_partida.dart` (`DesfechoCanonicoPartida`, com
  `MotivoEncerramento`, `OrdemDeEncerramento`, `LadoDaMesa`) e
  `app/lib/integracao/adaptador_partida_torneio.dart`. Ou seja, a lacuna que o
  hand-off descreveu como "única lacuna de código desta OS" só era lacuna vista
  da branch de resiliência. Decisão da Sônia em 10/08/2026:
  **`DesfechoCanonicoPartida` sobrevive como contrato canônico único** e absorve
  integralmente as garantias de `EncerramentoPartida`; a duplicidade só é
  eliminada depois de comprovado, item a item, que nada se perde.
