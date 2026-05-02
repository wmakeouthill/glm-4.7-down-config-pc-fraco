# Baixa o build pre-compilado do llama.cpp com suporte CUDA para Windows
# Funciona com RTX 4060 (CUDA 12.x)

$ErrorActionPreference = "Stop"

$targetDir = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path | Split-Path -Parent) "llama.cpp\build\bin\Release"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Setup llama.cpp (CUDA/Windows)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

if (Test-Path (Join-Path $targetDir "llama-cli.exe")) {
    Write-Host "llama-cli.exe ja encontrado em: $targetDir" -ForegroundColor Green
    Write-Host "Para reinstalar, delete a pasta llama.cpp\ e rode novamente." -ForegroundColor Gray
    exit 0
}

Write-Host "Buscando ultima versao no GitHub..." -ForegroundColor Yellow

try {
    $release = Invoke-RestMethod -Uri "https://api.github.com/repos/ggerganov/llama.cpp/releases/latest" -Headers @{ "User-Agent" = "llama-setup" }
} catch {
    Write-Host "Erro ao acessar GitHub API: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Verifique sua conexao com a internet." -ForegroundColor Yellow
    exit 1
}

$version = $release.tag_name
Write-Host "Versao encontrada: $version" -ForegroundColor Green

# Encontrar asset correto: binario principal (llama-bXXXX-bin-win-cuda/cublas-*-x64.zip)
# Excluir pacotes "cudart-*" que sao so DLLs de runtime, nao os executaveis
$asset = $release.assets | Where-Object {
    $_.name -match "^llama-" -and
    $_.name -match "bin-win" -and
    $_.name -match "x64" -and
    $_.name -match "cuda|cublas" -and
    $_.name -notmatch "^cudart" -and
    $_.name -match "\.zip$"
} | Sort-Object { $_.name -match "cuda" } -Descending | Select-Object -First 1

if (-not $asset) {
    # Fallback: qualquer zip win x64 que nao seja cudart
    $asset = $release.assets | Where-Object {
        $_.name -match "^llama-" -and
        $_.name -match "win" -and
        $_.name -match "x64" -and
        $_.name -notmatch "^cudart" -and
        $_.name -match "\.zip$"
    } | Select-Object -First 1
}

if (-not $asset) {
    Write-Host "" -ForegroundColor Red
    Write-Host "Nao foi possivel encontrar build CUDA automaticamente." -ForegroundColor Red
    Write-Host "Baixe manualmente em: https://github.com/ggerganov/llama.cpp/releases/latest" -ForegroundColor Yellow
    Write-Host "Procure por: llama-*-bin-win-cuda-cu12*-x64.zip" -ForegroundColor Yellow
    Write-Host "Extraia os .exe para: $targetDir" -ForegroundColor Yellow
    exit 1
}

Write-Host "Asset: $($asset.name)" -ForegroundColor Gray
Write-Host "Tamanho: $([math]::Round($asset.size / 1MB, 1)) MB" -ForegroundColor Gray
Write-Host ""

$tempZip = Join-Path $env:TEMP "llama-cpp-cuda.zip"
$tempExtract = Join-Path $env:TEMP "llama-cpp-extract"

Write-Host "Baixando..." -ForegroundColor Yellow
try {
    Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $tempZip -UseBasicParsing
} catch {
    Write-Host "Erro no download: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host "Extraindo..." -ForegroundColor Yellow

if (Test-Path $tempExtract) {
    Remove-Item $tempExtract -Recurse -Force
}
Expand-Archive -Path $tempZip -DestinationPath $tempExtract -Force

# Criar diretorio de destino
if (-not (Test-Path $targetDir)) {
    New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
}

# Copiar todos os .exe e .dll para o destino
$exes = Get-ChildItem -Path $tempExtract -Recurse -Include "*.exe", "*.dll"
foreach ($file in $exes) {
    Copy-Item $file.FullName -Destination $targetDir -Force
}

# Limpar temporarios
Remove-Item $tempZip -Force -ErrorAction SilentlyContinue
Remove-Item $tempExtract -Recurse -Force -ErrorAction SilentlyContinue

Write-Host ""
if (Test-Path (Join-Path $targetDir "llama-cli.exe")) {
    Write-Host "[OK] llama-cli.exe instalado em: $targetDir" -ForegroundColor Green
    Write-Host ""
    Write-Host "Pronto para rodar o modelo:" -ForegroundColor Yellow
    Write-Host "  .\scripts\run-llamacpp.ps1 -ModelVersion QWEN3_6_27B_Q4_K_M -GpuLayers 16 -Threads 6 -CtxSize 32768 -KvCache q8_0 -FlashAttn" -ForegroundColor White
} else {
    Write-Host "[AVISO] llama-cli.exe nao encontrado apos extracao." -ForegroundColor Red
    Write-Host "Verifique o conteudo extraido e copie os .exe para: $targetDir" -ForegroundColor Yellow
}
Write-Host ""
