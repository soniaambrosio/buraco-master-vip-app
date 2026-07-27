# Perfil VIP — entrega da camada visual

Implementação visual baseada em:

- `CONTRATO-TELA-PERFIL.md`
- `perfil-prototipo-LUXO.html`
- `perfil-visual-LUXO.png`

## Arquivos da UI

- `app/lib/screens/perfil_screen.dart`
- `app/assets/perfil/*.webp`

## Ponto de entrada temporário

O item **Perfil** da grade e da navegação inferior da Home abre a tela com `PerfilVM.mock()`.
Esse mock existe apenas para validação visual do piloto.

## Integração do Claude

Na etapa de integração:

1. Substituir a origem do `PerfilVM.mock()` pelo view-model real.
2. Ligar os callbacks já expostos por `PerfilScreen` aos serviços/rotas existentes.
3. Se os models finais já estiverem em `lib/models`, mover as classes de contrato para esses arquivos e manter a tela somente como consumidora.
4. Não é necessário redesenhar o layout.

## Estados contemplados

- normal
- carregando
- erro
- perfil vazio por listas/contadores zerados
- dono do perfil
- visitante
- bottom-sheet de presentes

## CI

O workflow passou a copiar todos os arquivos de `app/lib` e os assets de `app/assets/perfil`, declarando a pasta no `pubspec.yaml` criado durante o build.
