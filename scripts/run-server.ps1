# Servidor llama.cpp com API OpenAI-compativel
# Roda em background, acesse via http://localhost:PORT
# Chat: http://localhost:PORT
# API:  http://localhost:PORT/v1

param(
    [string]$ModelVersion = "",

    # Presets de contexto/qualidade:
    #   32k-q8  = 32K contexto, KV q8_0, 14 layers  (recomendado)
    #   48k-q8  = 48K contexto, KV q8_0, 12 layers
    #   64k-q4  = 64K contexto, KV q4_0, 14 layers
    #   96k-q4  = 96K contexto, KV q4_0, 12 layers  (teto absoluto)
    # Presets de velocidade maxima (menos layers na RAM = mais rapido):
    #   fast-8k  = 8K contexto, KV q8_0, 15 layers  (mais rapido possivel)
    #   fast-16k = 16K contexto, KV q8_0, 14 layers (equilibrio velocidade/contexto)
    [ValidateSet("32k-q8", "48k-q8", "64k-q4", "96k-q4", "fast-8k", "fast-16k")]
    [string]$Preset = "32k-q8",

    [int]$GpuLayers    = -1,
    [int]$Threads       = 6,
    [int]$CtxSize       = 0,
    [string]$KvCache    = "",
    [switch]$FlashAttn,
    [switch]$CpuOnly,

    # Renomeado de $Host (reservado pelo PowerShell) para $BindHost
    [string]$BindHost   = "127.0.0.1",
    [int]$Port          = 8080,
    [int]$ParallelSlots = 1,

    # Controle de thinking do Qwen3:
    # full   = raciocinio completo (padrao)
    # medium = budget ~1000 tokens de raciocinio
    # low    = budget ~300 tokens de raciocinio
    # off    = sem raciocinio interno (mais rapido)
    [ValidateSet("full", "medium", "low", "off")]
    [string]$Thinking = "full",

    [switch]$Background
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot  = (Resolve-Path (Join-Path $scriptDir "..")).Path

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "llama-server Qwen3.6-27B" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Carregar config
$configPath = Join-Path $repoRoot "config/model-config.json"
$config = Get-Content $configPath | ConvertFrom-Json

# Detectar modelo
if ([string]::IsNullOrEmpty($ModelVersion)) {
    $ModelVersion = "QWEN3_6_27B_Q4_K_M"
}

$modelInfo = $config.models.$ModelVersion
if (-not $modelInfo) {
    Write-Host "Modelo nao encontrado: $ModelVersion" -ForegroundColor Red
    exit 1
}

$modelPath = Join-Path $repoRoot (Join-Path "models" (Join-Path $modelInfo.name $modelInfo.file))
if (-not (Test-Path $modelPath)) {
    Write-Host "Arquivo do modelo nao encontrado: $modelPath" -ForegroundColor Red
    Write-Host "Baixe primeiro: .\scripts\download-model.ps1 -Version $ModelVersion" -ForegroundColor Yellow
    exit 1
}

# Aplicar preset
switch ($Preset) {
    "32k-q8" {
        if ($CtxSize   -eq 0)  { $CtxSize   = 32768 }
        if ($KvCache   -eq "") { $KvCache   = "q8_0" }
        if ($GpuLayers -eq -1) { $GpuLayers = 14 }
        if (-not $FlashAttn)   { $FlashAttn = $true }
    }
    "48k-q8" {
        if ($CtxSize   -eq 0)  { $CtxSize   = 49152 }
        if ($KvCache   -eq "") { $KvCache   = "q8_0" }
        if ($GpuLayers -eq -1) { $GpuLayers = 13 }
        if (-not $FlashAttn)   { $FlashAttn = $true }
    }
    "64k-q4" {
        if ($CtxSize   -eq 0)  { $CtxSize   = 65536 }
        if ($KvCache   -eq "") { $KvCache   = "q4_0" }
        if ($GpuLayers -eq -1) { $GpuLayers = 14 }
        if (-not $FlashAttn)   { $FlashAttn = $true }
    }
    "96k-q4" {
        if ($CtxSize   -eq 0)  { $CtxSize   = 98304 }
        if ($KvCache   -eq "") { $KvCache   = "q4_0" }
        if ($GpuLayers -eq -1) { $GpuLayers = 13 }
        if (-not $FlashAttn)   { $FlashAttn = $true }
    }
    "fast-8k" {
        # Velocidade maxima: contexto pequeno libera mais VRAM pro modelo
        if ($CtxSize   -eq 0)  { $CtxSize   = 8192 }
        if ($KvCache   -eq "") { $KvCache   = "q8_0" }
        if ($GpuLayers -eq -1) { $GpuLayers = 15 }
        if (-not $FlashAttn)   { $FlashAttn = $true }
    }
    "fast-16k" {
        # Equilibrio: bom contexto com velocidade melhor que os presets grandes
        if ($CtxSize   -eq 0)  { $CtxSize   = 16384 }
        if ($KvCache   -eq "") { $KvCache   = "q8_0" }
        if ($GpuLayers -eq -1) { $GpuLayers = 14 }
        if (-not $FlashAttn)   { $FlashAttn = $true }
    }
}

if ($CpuOnly) { $GpuLayers = 0 }

# Encontrar llama-server.exe
$serverExe = $null
$candidates = @(
    "llama.cpp\build\bin\Release\llama-server.exe",
    "llama.cpp\build\bin\Debug\llama-server.exe",
    "llama.cpp\bin\llama-server.exe",
    "llama-server.exe"
)
foreach ($c in $candidates) {
    $full = Join-Path $repoRoot $c
    if (Test-Path $full) { $serverExe = $full; break }
}

if (-not $serverExe) {
    Write-Host "llama-server.exe nao encontrado." -ForegroundColor Red
    Write-Host "Rode primeiro: .\scripts\setup-llamacpp.ps1" -ForegroundColor Yellow
    exit 1
}

# Montar argumentos (renomeado de $args para $cmdArgs)
$cmdArgs = @(
    "-m",         "`"$modelPath`"",
    "--threads",  $Threads,
    "--ctx-size", $CtxSize,
    "--parallel", $ParallelSlots,
    "--host",     $BindHost,
    "--port",     $Port
)

if ($GpuLayers -gt 0) {
    $cmdArgs += "--n-gpu-layers", $GpuLayers
}

if (-not [string]::IsNullOrEmpty($KvCache)) {
    $cmdArgs += "--cache-type-k", $KvCache
    $cmdArgs += "--cache-type-v", $KvCache
}

if ($FlashAttn) {
    $cmdArgs += "--flash-attn", "on"
}

switch ($Thinking) {
    "off"    { $cmdArgs += "--no-thinking" }
    "low"    { $cmdArgs += "-sp", "Think very briefly before answering, use at most 300 tokens of internal reasoning." }
    "medium" { $cmdArgs += "-sp", "Think step by step but be concise, use at most 1000 tokens of internal reasoning." }
}

# Resumo
Write-Host "Preset    : $Preset" -ForegroundColor Green
Write-Host "Thinking  : $Thinking" -ForegroundColor Green
Write-Host "Modelo    : $($modelInfo.name)" -ForegroundColor Green
Write-Host "Contexto  : $CtxSize tokens" -ForegroundColor Green
Write-Host "KV Cache  : $KvCache" -ForegroundColor Green
Write-Host "GPU Layers: $GpuLayers" -ForegroundColor Green
Write-Host "Threads   : $Threads" -ForegroundColor Green
Write-Host ""
Write-Host "Endereco  : http://${BindHost}:${Port}" -ForegroundColor Cyan
Write-Host "Chat      : http://${BindHost}:${Port}" -ForegroundColor Cyan
Write-Host "API       : http://${BindHost}:${Port}/v1/chat/completions" -ForegroundColor Cyan
Write-Host ""

if ($Background) {
    Write-Host "Iniciando em background..." -ForegroundColor Yellow
    $argStr = $cmdArgs -join " "
    Start-Process -FilePath $serverExe -ArgumentList $argStr -WindowStyle Hidden
    Write-Host "[OK] Servidor rodando em background." -ForegroundColor Green
    Write-Host "Para parar: Get-Process llama-server | Stop-Process" -ForegroundColor Gray
} else {
    Write-Host "Iniciando servidor (Ctrl+C para parar)..." -ForegroundColor Yellow
    Write-Host "Comando: $serverExe $($cmdArgs -join ' ')" -ForegroundColor Gray
    Write-Host ""
    & $serverExe $cmdArgs
}
