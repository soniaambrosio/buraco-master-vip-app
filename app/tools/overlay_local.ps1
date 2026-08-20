# overlay_local.ps1 - reproduz o overlay do CI (.github/workflows/build.yml) num
# scaffold `app_build/` ja existente, para rodar `flutter analyze` e `flutter test`
# na maquina. Nao versiona nada: `/app_build/` esta no .gitignore.
#
# Somente ASCII: o Windows PowerShell 5.1 le .ps1 sem BOM como ANSI, e acento
# dentro de string quebra o parser.
#
# Uso (a partir da raiz do repositorio):
#   powershell -File app/tools/overlay_local.ps1
$ErrorActionPreference = 'Stop'

$raiz = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$app = Join-Path $raiz 'app'
$build = Join-Path $raiz 'app_build'

if (-not (Test-Path (Join-Path $build 'pubspec.yaml'))) {
  throw "app_build nao encontrado em $build; gere o scaffold com flutter create antes."
}

function Copiar($de, $para) {
  if (-not (Test-Path $de)) { return }
  New-Item -ItemType Directory -Force -Path $para | Out-Null
  robocopy $de $para /E /NFL /NDL /NJH /NJS /NP | Out-Null
  if ($LASTEXITCODE -ge 8) { throw "robocopy falhou: $de -> $para" }
}

Copiar (Join-Path $app 'lib') (Join-Path $build 'lib')
Copiar (Join-Path $app 'test') (Join-Path $build 'test')

# Assets: o CI copia SUBDIRETORIO por SUBDIRETORIO, nunca `app/assets/` inteiro.
# Isso importa: existem dois .dart soltos na raiz de app/assets/ (arquivos fora de
# lugar de outra sessao) que o CI nunca embarca. Copiar a pasta toda os levaria
# para dentro de app_build/assets/, onde o analyzer os enxerga e acusa erro que o
# CI nao tem.
foreach ($dir in (Get-ChildItem (Join-Path $app 'assets') -Directory)) {
  Copiar $dir.FullName (Join-Path $build "assets\$($dir.Name)")
}
Get-ChildItem (Join-Path $build 'assets') -File | Remove-Item -Force

# O portao de recompensas de torneios le as seeds a partir de test/torneios/data/.
Copiar (Join-Path $app 'data\torneios') (Join-Path $build 'test\torneios\data')

# Idem para colecoes: as suites de test/colecoes/ leem os seeds por
# test/suporte/seeds.dart, que procura primeiro em test/<dominio>/data/.
Copiar (Join-Path $app 'data\colecoes') (Join-Path $build 'test\colecoes\data')

# Assets DECLARADOS no pubspec que sao ARQUIVO, e nao pasta - hoje o catalogo de
# colecoes. Mesma regra de tools/ci/copiar_assets_de_dados.sh, e pelo mesmo
# motivo: lista digitada em cinco lugares diverge, declaracao lida nao. Sem esta
# copia, asset declarado nao existe e `flutter test` falha ao montar o bundle -
# nao no assert, no carregamento.
$dentroDeAssets = $false
foreach ($linha in (Get-Content (Join-Path $app 'pubspec.yaml'))) {
  if ($linha -match '^\s*assets:\s*$') { $dentroDeAssets = $true; continue }
  if ($dentroDeAssets -and $linha -match '^\s*-\s*(\S+)\s*$') {
    $entrada = $Matches[1]
    if ($entrada.EndsWith('/')) { continue }
    $relativo = $entrada -replace '/', '\'
    $de = Join-Path $app $relativo
    if (-not (Test-Path $de)) {
      throw "pubspec declara o asset '$entrada', que nao existe em app/."
    }
    $para = Join-Path $build (Split-Path $relativo -Parent)
    New-Item -ItemType Directory -Force -Path $para | Out-Null
    Copy-Item $de $para -Force
    Write-Host "  asset de dados: $entrada"
    continue
  }
  if ($dentroDeAssets -and $linha -match '^\s*[^\s#-]') { $dentroDeAssets = $false }
}

# O widget_test.dart que vem do `flutter create` tem erro pre-existente e
# derrubaria a suite inteira; o proprio CI evita roda-lo.
Remove-Item (Join-Path $build 'test\widget_test.dart') -ErrorAction SilentlyContinue

Write-Output 'overlay aplicado em app_build'
