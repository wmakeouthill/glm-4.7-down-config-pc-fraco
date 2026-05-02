# Baixa o build pre-compilado do llama.cpp com suporte CUDA para Windows
# Funciona com RTX 4060 (CUDA 12.x)
# Requer DOIS pacotes: binarios principais + cudart (runtime CUDA)

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
Write-Host ""

# --- Pacote 1: binarios principais (llama-bXXXX-bin-win-cuda-*-x64.zip) ---
$assetMain = $release.assets | Where-Object {
    $_.name -match "^llama-b" -and
    $_.name -match "bin-win" -and
    $_.name -match "x64" -and
    $_.name -match "cuda|cublas" -and
    $_.name -match "\.zip$"
} | Select-Object -First 1

if (-not $assetMain) {
    Write-Host "Nao foi possivel encontrar o pacote de binarios CUDA." -ForegroundColor Red
    Write-Host "Baixe manualmente: https://github.com/ggerganov/llama.cpp/releases/latest" -ForegroundColor Yellow
    Write-Host "Arquivo: llama-*-bin-win-cuda-*-x64.zip" -ForegroundColor Yellow
    exit 1
}

# --- Pacote 2: cudart (DLLs do runtime CUDA - obrigatorio para GPU funcionar) ---
$assetCudart = $release.assets | Where-Object {
    $_.name -match "^cudart-" -and
    $_.name -match "win" -and
    $_.name -match "x64" -and
    $_.name -match "\.zip$"
} | Select-Object -First 1

# Criar diretorio de destino
if (-not (Test-Path $targetDir)) {
    New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
}

function Install-Asset {
    param($Asset, $Label)

    $tempZip = Join-Path $env:TEMP "llama-$Label.zip"
    $tempExtract = Join-Path $env:TEMP "llama-$Label-extract"

    Write-Host "[$Label] $($Asset.name)" -ForegroundColor Gray
    Write-Host "[$Label] Tamanho: $([math]::Round($Asset.size / 1MB, 1)) MB" -ForegroundColor Gray
    Write-Host "[$Label] Baixando..." -ForegroundColor Yellow

    Invoke-WebRequest -Uri $Asset.browser_download_url -OutFile $tempZip -UseBasicParsing

    Write-Host "[$Label] Extraindo..." -ForegroundColor Yellow
    if (Test-Path $tempExtract) { Remove-Item $tempExtract -Recurse -Force }
    Expand-Archive -Path $tempZip -DestinationPath $tempExtract -Force

    $files = Get-ChildItem -Path $tempExtract -Recurse -Include "*.exe", "*.dll"
    foreach ($file in $files) {
        Copy-Item $file.FullName -Destination $targetDir -Force
    }

    Remove-Item $tempZip -Force -ErrorAction SilentlyContinue
    Remove-Item $tempExtract -Recurse -Force -ErrorAction SilentlyContinue

    Write-Host "[$Label] OK" -ForegroundColor Green
    Write-Host ""
}

Install-Asset -Asset $assetMain -Label "binarios"

if ($assetCudart) {
    Install-Asset -Asset $assetCudart -Label "cudart"
} else {
    Write-Host "[cudart] Pacote nao encontrado na release - GPU pode nao funcionar." -ForegroundColor Yellow
    Write-Host "[cudart] Se a GPU nao carregar, instale o CUDA Toolkit 12.x:" -ForegroundColor Yellow
    Write-Host "         https://developer.nvidia.com/cuda-downloads" -ForegroundColor Gray
    Write-Host ""
}

if (Test-Path (Join-Path $targetDir "llama-cli.exe")) {
    Write-Host "[OK] llama-cli.exe instalado em: $targetDir" -ForegroundColor Green

    $hasCuda = Test-Path (Join-Path $targetDir "ggml-cuda.dll")
    if ($hasCuda) {
        Write-Host "[OK] ggml-cuda.dll presente - GPU ativa" -ForegroundColor Green
    } else {
        Write-Host "[AVISO] ggml-cuda.dll nao encontrado - GPU pode nao carregar" -ForegroundColor Yellow
    }

    Write-Host ""
    Write-Host "Pronto para rodar:" -ForegroundColor Yellow
    Write-Host "  .\scripts\run-llamacpp.ps1 -ModelVersion QWEN3_6_27B_Q4_K_M -GpuLayers 16 -Threads 6 -CtxSize 32768 -KvCache q8_0 -FlashAttn" -ForegroundColor White
} else {
    Write-Host "[ERRO] llama-cli.exe nao encontrado apos extracao." -ForegroundColor Red
}
Write-Host ""
