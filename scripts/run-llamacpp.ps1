# Script de Execucao Qwen3.6-27B com llama.cpp para Windows
# Otimizado para hardware limitado

param(
    [string]$ModelVersion = "",
    [string]$Profile = "",
    [int]$CtxSize = 0,
    [int]$Threads = 0,
    [int]$GpuLayers = -1,
    [switch]$CpuOnly = $false,
    [string]$Prompt = "",
    [ValidateSet("", "q8_0", "q4_0", "q4_1", "q5_0")]
    [string]$KvCache = "",
    [switch]$FlashAttn,

    # Controle de thinking do Qwen3:
    # full   = raciocinio completo (padrao, mais lento)
    # medium = budget ~1000 tokens de raciocinio
    # low    = budget ~300 tokens de raciocinio
    # off    = sem raciocinio interno (mais rapido)
    [ValidateSet("full", "medium", "low", "off")]
    [string]$Thinking = "full"
)

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Executando Qwen3.6-27B com llama.cpp" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Carregar configurações
$modelConfig = "config/model-config.json"
$devConfigPath = "config/dev-config.json"

if (-not (Test-Path $modelConfig)) {
    Write-Host "Erro: Arquivo de configuração não encontrado: $modelConfig" -ForegroundColor Red
    exit 1
}

$config = Get-Content $modelConfig | ConvertFrom-Json
$availableModelKeys = @($config.models.PSObject.Properties.Name)

# Carregar perfil (opcional)
$profileSettings = $null
$profileModelKey = $null
if (-not [string]::IsNullOrEmpty($Profile)) {
    if (-not (Test-Path $devConfigPath)) {
        Write-Host "Erro: Arquivo de perfis nao encontrado: $devConfigPath" -ForegroundColor Red
        exit 1
    }

    $devConfig = Get-Content $devConfigPath | ConvertFrom-Json
    $profile = $devConfig.profiles.$Profile
    if (-not $profile) {
        $profileKeys = @($devConfig.profiles.PSObject.Properties.Name)
        Write-Host "Erro: Perfil '$Profile' nao encontrado." -ForegroundColor Red
        Write-Host "Perfis disponiveis: $($profileKeys -join ', ')" -ForegroundColor Yellow
        exit 1
    }

    $profileSettings = $profile.settings
    $profileModelKey = $profile.model_key
}

# Configuracoes base
$temperature = $config.default_settings.temperature
$topP = $config.default_settings.top_p
$topK = $config.default_settings.top_k
$repeatPenalty = $config.default_settings.repeat_penalty
$ctxDefault = $config.default_settings.ctx_size
$threadsDefault = $config.default_settings.threads
$gpuLayersDefault = $config.default_settings.gpu_layers

if ($profileSettings) {
    if ($profileSettings.temperature) { $temperature = $profileSettings.temperature }
    if ($profileSettings.top_p) { $topP = $profileSettings.top_p }
    if ($profileSettings.top_k) { $topK = $profileSettings.top_k }
    if ($profileSettings.repeat_penalty) { $repeatPenalty = $profileSettings.repeat_penalty }
    if ($profileSettings.ctx_size) { $ctxDefault = $profileSettings.ctx_size }
    if ($profileSettings.threads) { $threadsDefault = $profileSettings.threads }
    if ($profileSettings.gpu_layers -ne $null) { $gpuLayersDefault = $profileSettings.gpu_layers }
}

function Resolve-ModelPath {
    param(
        [string]$ModelKey
    )

    $modelsDir = "models"
    $modelInfo = $config.models.$ModelKey
    if (-not $modelInfo) {
        return $null
    }

    if ($modelInfo.file -and $modelInfo.name) {
        $candidate = Join-Path (Join-Path $modelsDir $modelInfo.name) $modelInfo.file
        if (Test-Path $candidate) {
            return $candidate
        }
    }

    if ($modelInfo.name) {
        $candidateDir = Join-Path $modelsDir $modelInfo.name
        if (Test-Path $candidateDir) {
            $gguf = Get-ChildItem -Path $candidateDir -Filter "*.gguf" -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($gguf) {
                return $gguf.FullName
            }
            return $candidateDir
        }
    }

    if ($modelInfo.file) {
        $found = Get-ChildItem -Path $modelsDir -Recurse -Filter $modelInfo.file -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($found) {
            return $found.FullName
        }
    }

    return $null
}

# Detectar modelo disponível
if ([string]::IsNullOrEmpty($ModelVersion)) {
    if (-not [string]::IsNullOrEmpty($profileModelKey)) {
        $ModelVersion = $profileModelKey
    }
}

if ([string]::IsNullOrEmpty($ModelVersion)) {
    $preferredOrder = @("QWEN3_6_27B_Q4_K_M", "QWEN3_6_27B_Q8_0")
    foreach ($candidate in $preferredOrder) {
        $candidatePath = Resolve-ModelPath -ModelKey $candidate
        if ($candidatePath) {
            $ModelVersion = $candidate
            break
        }
    }
}

if ([string]::IsNullOrEmpty($ModelVersion)) {
    Write-Host "Erro: Nenhum modelo encontrado em 'models/'" -ForegroundColor Red
    Write-Host "Baixe um modelo primeiro: .\scripts\download-model.ps1 -Version QWEN3_6_27B_Q4_K_M" -ForegroundColor Yellow
    exit 1
}

# Encontrar arquivo do modelo
$modelPath = $null
if ($availableModelKeys -contains $ModelVersion) {
    $modelPath = Resolve-ModelPath -ModelKey $ModelVersion
    if (-not $modelPath) {
        Write-Host "Erro: Modelo nao encontrado para a chave: $ModelVersion" -ForegroundColor Red
        exit 1
    }
} else {
    $modelsDir = "models"
    $modelDirs = Get-ChildItem -Path $modelsDir -Directory -ErrorAction SilentlyContinue
    foreach ($dir in $modelDirs) {
        if ($dir.Name -like "*$ModelVersion*") {
            $ggufFiles = Get-ChildItem -Path $dir.FullName -Filter "*.gguf" -ErrorAction SilentlyContinue
            if ($ggufFiles) {
                $modelPath = $ggufFiles[0].FullName
                break
            }
            $modelPath = $dir.FullName
            break
        }
    }
}

if (-not $modelPath -or -not (Test-Path $modelPath)) {
    Write-Host "Erro: Modelo nao encontrado para versao: $ModelVersion" -ForegroundColor Red
    exit 1
}

Write-Host "Modelo: $modelPath" -ForegroundColor Green

# Detectar hardware e ajustar parâmetros
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
    if (-not $hasGpu -and -not $profileSettings) {
        $CtxSize = $config.low_resource_settings.ctx_size
        Write-Host "Modo CPU-only: usando contexto reduzido ($CtxSize)" -ForegroundColor Yellow
    } else {
        $CtxSize = $ctxDefault
    }
}

if ($Threads -eq 0) {
    if ($threadsDefault -gt 0) {
        $Threads = $threadsDefault
    } else {
        $cpuCores = (Get-WmiObject Win32_Processor).NumberOfCores
        $Threads = [math]::Max(2, [math]::Floor($cpuCores / 2))
    }
    Write-Host "Threads: $Threads" -ForegroundColor Gray
}

if ($GpuLayers -eq -1) {
    if ($hasGpu -and -not $CpuOnly) {
        if ($gpuLayersDefault -gt 0) {
            $GpuLayers = $gpuLayersDefault
        } else {
            $GpuLayers = 10
        }
        Write-Host "GPU Layers: $GpuLayers" -ForegroundColor Gray
    } else {
        $GpuLayers = 0
        Write-Host "Modo CPU-only: GPU Layers = 0" -ForegroundColor Yellow
    }
}

if ($CpuOnly) {
    $GpuLayers = 0
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
    "--temp", $temperature,
    "--top-p", $topP,
    "--top-k", $topK,
    "--repeat-penalty", $repeatPenalty,
    "--jinja"
)

if ($GpuLayers -gt 0) {
    $cmdArgs += "--n-gpu-layers", $GpuLayers
    # Offload de camadas MoE para CPU (economiza VRAM)
    $cmdArgs += "-ot", "`.ffn_.*_exps.=CPU"
}

if (-not [string]::IsNullOrEmpty($KvCache)) {
    $cmdArgs += "--cache-type-k", $KvCache
    $cmdArgs += "--cache-type-v", $KvCache
}

if ($FlashAttn) {
    $cmdArgs += "--flash-attn", "on"
}

switch ($Thinking) {
    "off" { $cmdArgs += "--no-thinking" }
    { $_ -in "low", "medium" } {
        $spContent = if ($Thinking -eq "low") {
            "Think very briefly before answering, use at most 300 tokens of internal reasoning."
        } else {
            "Think step by step but be concise, use at most 1000 tokens of internal reasoning."
        }
        # -sp espera arquivo, nao string direta
        $spFile = Join-Path $PSScriptRoot "llama-sp-tmp.txt"
        $spContent | Out-File -FilePath $spFile -Encoding utf8 -NoNewline
        $cmdArgs += "-sp", $spFile
    }
    # "full" = padrao, nenhuma flag adicional
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
