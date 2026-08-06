# =============================================================================
# GERA A NOVA CHAVE DE UPLOAD + O CERTIFICADO .PEM PARA A PLAY CONSOLE
#
# Contexto: a chave de upload registrada hoje na Play Console tem
#   SHA-1   32:6B:CA:26:34:29:45:41:D5:DA:21:17:DB:87:80:91:32:D2:D9:9C
#   SHA-256 AB:7A:51:93:E6:CA:FD:16:04:56:4B:3E:4B:8C:61:60:19:2C:22:28:D1:9B:32:D0:0C:5A:A5:9E:CB:FA:83:E8
# e a chave privada correspondente nao foi localizada. Sem ela, nenhum AAB novo
# passa. O caminho oficial e pedir a REDEFINICAO da chave de upload, enviando o
# certificado publico de uma chave NOVA. Este script cria essa chave nova.
#
# O QUE ESTE SCRIPT NAO FAZ: escolher sua senha. O keytool vai pedir a senha
# interativamente, e ela fica so com voce. Nao existe senha escrita aqui dentro,
# e nao deve existir.
#
# IMPORTANTE: isto NAO mexe na chave de assinatura do app administrada pelo
# Google (Play App Signing). Essa continua intacta — e ela que assina o que
# chega no celular dos jogadores. A chave de upload so serve para provar, no
# momento do envio, que o AAB veio de voce.
#
# Uso:
#   powershell -ExecutionPolicy Bypass -File keystore\gerar-chave-upload.ps1 -Alias <alias>
#
# O alias e obrigatorio e NAO tem valor padrao de proposito: ele vai para o
# secret BMV_UPLOAD_KEY_ALIAS e, junto com a senha, e parte do que protege a
# keystore. Nada disso fica escrito no repositorio. Anote o alias no mesmo
# gerenciador de senhas onde voce guardar a senha.
# =============================================================================

param(
  [Parameter(Mandatory = $true, HelpMessage = 'Alias da chave (vai para o secret BMV_UPLOAD_KEY_ALIAS)')]
  [ValidateNotNullOrEmpty()]
  [string]$Alias
)

$ErrorActionPreference = 'Stop'

$alias      = $Alias
$arquivoJks = Join-Path $PSScriptRoot 'buraco-master-vip-upload.jks'
$arquivoPem = Join-Path $PSScriptRoot 'upload_certificate.pem'

# --- localizar o keytool -----------------------------------------------------
$keytool = $null
$candidatos = @(
  'C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe',
  "$env:LOCALAPPDATA\Programs\Android Studio\jbr\bin\keytool.exe",
  "$env:JAVA_HOME\bin\keytool.exe"
)
foreach ($c in $candidatos) {
  if ($c -and (Test-Path $c)) { $keytool = $c; break }
}
if (-not $keytool) {
  $cmd = Get-Command keytool -ErrorAction SilentlyContinue
  if ($cmd) { $keytool = $cmd.Source }
}
if (-not $keytool) {
  throw 'keytool nao encontrado. Instale o Android Studio ou um JDK e rode de novo.'
}
Write-Host "keytool: $keytool" -ForegroundColor DarkGray

# --- nao sobrescrever uma chave existente ------------------------------------
# Perder uma chave de upload por sobrescrita e um problema serio e irreversivel:
# a redefinicao so pode ser pedida uma vez a cada 12 meses.
if (Test-Path $arquivoJks) {
  throw "Ja existe $arquivoJks. Se for realmente para recomeçar, mova o arquivo antigo para um lugar seguro ANTES de rodar de novo."
}

# --- gerar a chave -----------------------------------------------------------
# RSA 4096 e validade de 10000 dias (~27 anos): a Play Console exige que a
# chave de upload seja valida bem alem de 2033.
Write-Host ''
Write-Host 'O keytool vai pedir uma senha. Escolha uma senha forte e GUARDE-A' -ForegroundColor Yellow
Write-Host 'num gerenciador de senhas, junto com o alias que voce escolheu.' -ForegroundColor Yellow
Write-Host 'Sem eles, esta chave tambem se perde.' -ForegroundColor Yellow
Write-Host ''

& $keytool -genkeypair `
  -v `
  -keystore $arquivoJks `
  -alias $alias `
  -keyalg RSA `
  -keysize 4096 `
  -validity 10000 `
  -dname 'CN=Buraco Master VIP, OU=Upload, O=Sonia Ambrosio, L=Sao Paulo, ST=SP, C=BR'

if ($LASTEXITCODE -ne 0) { throw 'keytool -genkeypair falhou.' }

# --- exportar o certificado publico (.pem) para a Play Console ---------------
& $keytool -exportcert -rfc `
  -keystore $arquivoJks `
  -alias $alias `
  -file $arquivoPem

if ($LASTEXITCODE -ne 0) { throw 'keytool -exportcert falhou.' }

# --- impressoes digitais da chave NOVA ---------------------------------------
Write-Host ''
Write-Host '================ IMPRESSOES DIGITAIS DA CHAVE NOVA ================' -ForegroundColor Cyan
& $keytool -list -v -keystore $arquivoJks -alias $alias | Select-String -Pattern 'SHA1:|SHA256:|Valid'
Write-Host '===================================================================' -ForegroundColor Cyan

# --- base64 para o GitHub Secret ---------------------------------------------
$base64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($arquivoJks))
$arquivoB64 = Join-Path $PSScriptRoot 'buraco-master-vip-upload.jks.b64'
Set-Content -Path $arquivoB64 -Value $base64 -Encoding ascii -NoNewline

Write-Host ''
Write-Host 'Pronto. Arquivos gerados (NENHUM deles vai para o git):' -ForegroundColor Green
Write-Host "  $arquivoJks   <- a chave privada. NUNCA compartilhe, faca backup."
Write-Host "  $arquivoPem   <- o certificado PUBLICO. E este que vai para a Play Console."
Write-Host "  $arquivoB64   <- conteudo do secret BMV_UPLOAD_KEYSTORE_B64."
Write-Host ''
Write-Host 'Proximos passos em docs/PLAY-BILLING-TESTE-INTERNO.md, secao'
Write-Host '"Redefinicao da chave de upload".' -ForegroundColor Green
