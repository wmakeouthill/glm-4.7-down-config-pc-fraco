# Script de Execução GLM-4.7 com llama.cpp para Windows
# Otimizado para hardware limitado

param(
    [string]$ModelVersion = "",
    [int]$CtxSize = 0,
    [int]$Threads = 0,
    [int]$GpuLayers = -1,
    [switch]$CpuOnly = $false,
    [string]$Prompt = ""
)

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Executando GLM-4.7 com llama.cpp" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Carregar configurações
$hardwareConfig = "config/hardware-config.yaml"
$modelConfig = "config/model-config.json"

if (-not (Test-Path $modelConfig)) {
    Write-Host "Erro: Arquivo de configuração não encontrado: $modelConfig" -ForegroundColor Red
    exit 1
}

$config = Get-Content $modelConfig | ConvertFrom-Json

# Detectar modelo disponível
if ([string]::IsNullOrEmpty($ModelVersion)) {
    # Tentar encontrar modelo automaticamente
    $modelsDir = "models"
    if (Test-Path $modelsDir) {
        $availableModels = Get-ChildItem -Path $modelsDir -Directory | Select-Object -ExpandProperty Name
        if ($availableModels.Count -gt 0) {
            # Tentar encontrar a versão mais leve primeiro
            $preferredOrder = @("Q4_K_S", "Q4_K_M", "Q5_K_M", "UD-Q2_K_XL")
            foreach ($pref in $preferredOrder) {
                $found = $availableModels | Where-Object { $_ -like "*$pref*" }
                if ($found) {
                    $ModelVersion = $pref
                    Write-Host "Modelo detectado automaticamente: $($found[0])" -ForegroundColor Green
                    break
                }
            }
            if ([string]::IsNullOrEmpty($ModelVersion)) {
                $ModelVersion = $availableModels[0]
                Write-Host "Usando primeiro modelo encontrado: $ModelVersion" -ForegroundColor Yellow
            }
        }
    }
    
    if ([string]::IsNullOrEmpty($ModelVersion)) {
        Write-Host "Erro: Nenhum modelo encontrado em 'models/'" -ForegroundColor Red
        Write-Host "Baixe um modelo primeiro: .\scripts\download-model.ps1 -Version Q4_K_S" -ForegroundColor Yellow
        exit 1
    }
}

# Encontrar arquivo do modelo
$modelPath = $null
$modelsDir = "models"
$modelDirs = Get-ChildItem -Path $modelsDir -Directory -ErrorAction SilentlyContinue

foreach ($dir in $modelDirs) {
    if ($dir.Name -like "*$ModelVersion*") {
        # Procurar arquivo .gguf
        $ggufFiles = Get-ChildItem -Path $dir.FullName -Filter "*.gguf" -ErrorAction SilentlyContinue
        if ($ggufFiles) {
            $modelPath = $ggufFiles[0].FullName
            break
        }
        # Se não encontrar .gguf, pode ser diretório unsloth
        $modelPath = $dir.FullName
        break
    }
}

if (-not $modelPath -or -not (Test-Path $modelPath)) {
    Write-Host "Erro: Modelo não encontrado para versão: $ModelVersion" -ForegroundColor Red
    exit 1
}

Write-Host "Modelo: $modelPath" -ForegroundColor Green

# Detectar hardware e ajustar parâmetros
$defaultSettings = $config.default_settings

# Detectar GPU
$hasGpu = $false
if (-not $CpuOnly) {
    try {
        $nvidiaSmi = nvidia-smi 2>&1
        if ($LASTEXITCODE -eq 0) {
            $hasGpu = $true
            Write-Host "GPU NVIDIA detectada!" -ForegroundColor Green
        }
    } catch {
        $hasGpu = $false
    }
}

# Ajustar parâmetros baseados no hardware
if ($CtxSize -eq 0) {
    if ($hasGpu) {
        $CtxSize = $defaultSettings.ctx_size
    } else {
        $CtxSize = $config.low_resource_settings.ctx_size
        Write-Host "Modo CPU-only: usando contexto reduzido ($CtxSize)" -ForegroundColor Yellow
    }
}

if ($Threads -eq 0) {
    $cpuCores = (Get-WmiObject Win32_Processor).NumberOfCores
    $Threads = [math]::Max(2, [math]::Floor($cpuCores / 2))
    Write-Host "Threads: $Threads (baseado em $cpuCores cores)" -ForegroundColor Gray
}

if ($GpuLayers -eq -1) {
    if ($hasGpu -and -not $CpuOnly) {
        # Tentar usar algumas camadas na GPU
        $GpuLayers = 10
        Write-Host "GPU Layers: $GpuLayers" -ForegroundColor Gray
    } else {
        $GpuLayers = 0
        Write-Host "Modo CPU-only: GPU Layers = 0" -ForegroundColor Yellow
    }
}

# Encontrar executável llama.cpp
$llamaExe = $null
$possiblePaths = @(
    "llama.cpp\build\bin\Release\llama-cli.exe",
    "llama.cpp\build\bin\Debug\llama-cli.exe",
    "llama.cpp\bin\llama-cli.exe",
    "llama-cli.exe"
)

foreach ($path in $possiblePaths) {
    if (Test-Path $path) {
        $llamaExe = $path
        break
    }
}

if (-not $llamaExe) {
    Write-Host "Erro: Executável llama.cpp não encontrado!" -ForegroundColor Red
    Write-Host "Procurei em:" -ForegroundColor Yellow
    foreach ($path in $possiblePaths) {
        Write-Host "  - $path" -ForegroundColor Gray
    }
    Write-Host ""
    Write-Host "Opções:" -ForegroundColor Yellow
    Write-Host "  1. Compile o llama.cpp (veja README.md)" -ForegroundColor White
    Write-Host "  2. Baixe build pré-compilado: https://github.com/ggerganov/llama.cpp/releases" -ForegroundColor White
    Write-Host "  3. Use WSL2 para executar scripts Linux" -ForegroundColor White
    exit 1
}

# Construir comando
$cmdArgs = @(
    "-m", "`"$modelPath`"",
    "--threads", $Threads,
    "--ctx-size", $CtxSize,
    "--temp", $defaultSettings.temperature,
    "--top-p", $defaultSettings.top_p,
    "--repeat-penalty", $defaultSettings.repeat_penalty,
    "--jinja"
)

if ($GpuLayers -gt 0) {
    $cmdArgs += "--n-gpu-layers", $GpuLayers
    # Offload de camadas MoE para CPU (economiza VRAM)
    $cmdArgs += "-ot", "`.ffn_.*_exps.=CPU"
}

if (-not [string]::IsNullOrEmpty($Prompt)) {
    $cmdArgs += "-p", "`"$Prompt`""
}

# Executar
Write-Host ""
Write-Host "Executando llama.cpp..." -ForegroundColor Yellow
Write-Host "Comando: $llamaExe $($cmdArgs -join ' ')" -ForegroundColor Gray
Write-Host ""

& $llamaExe $cmdArgs
