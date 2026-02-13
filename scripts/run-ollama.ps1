# Script de Execução de Modelos com Ollama para Windows
# Usa o catálogo em config/model-config.json

param(
    [string]$ModelVersion = "QWEN_CODER_14B_OLLAMA",

    [switch]$List
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = (Resolve-Path (Join-Path $scriptDir "..")).Path

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Executando Modelo com Ollama" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Carregar configuração de modelos
$configPath = Join-Path $repoRoot "config/model-config.json"
if (-not (Test-Path $configPath)) {
    Write-Host "Erro: Arquivo de configuração não encontrado: $configPath" -ForegroundColor Red
    exit 1
}

$config = Get-Content $configPath | ConvertFrom-Json
$allModelKeys = @($config.models.PSObject.Properties.Name)

$ollamaModelKeys = @()
foreach ($key in $allModelKeys) {
    $info = $config.models.$key
    $source = if ($info.source) { $info.source } elseif ($info.tag) { "ollama" } else { "huggingface" }
    if ($source -eq "ollama") {
        $ollamaModelKeys += $key
    }
}

if ($List) {
    Write-Host "Modelos Ollama disponíveis:" -ForegroundColor Green
    foreach ($modelKey in $ollamaModelKeys) {
        $info = $config.models.$modelKey
        Write-Host "  - $modelKey -> $($info.tag) ($($info.name))" -ForegroundColor White
    }
    Write-Host ""
    Write-Host "Exemplo:" -ForegroundColor Yellow
    Write-Host "  .\scripts\run-ollama.ps1 -ModelVersion QWEN_CODER_14B_OLLAMA" -ForegroundColor White
    exit 0
}

function Resolve-OllamaCommand {
    $command = Get-Command ollama -ErrorAction SilentlyContinue
    if ($command) {
        return $command.Source
    }

    $candidates = @(
        (Join-Path $env:LOCALAPPDATA "Programs\Ollama\ollama.exe"),
        (Join-Path $env:ProgramFiles "Ollama\ollama.exe"),
        (Join-Path ${env:ProgramFiles(x86)} "Ollama\ollama.exe")
    )

    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path $candidate)) {
            return $candidate
        }
    }

    return $null
}

# Verificar se Ollama está instalado
Write-Host "Verificando Ollama..." -ForegroundColor Yellow
$ollamaCommand = Resolve-OllamaCommand
if (-not $ollamaCommand) {
    Write-Host "Ollama não encontrado!" -ForegroundColor Red
    Write-Host "" 
    Write-Host "Instale o Ollama de: https://ollama.ai/download" -ForegroundColor Yellow
    Write-Host "Ou use: winget install Ollama.Ollama" -ForegroundColor Yellow
    exit 1
}

try {
    $ollamaVersion = & $ollamaCommand --version 2>&1
    Write-Host "Ollama encontrado: $ollamaVersion" -ForegroundColor Green
}
catch {
    Write-Host "Ollama não encontrado!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Instale o Ollama de: https://ollama.ai/download" -ForegroundColor Yellow
    Write-Host "Ou use: winget install Ollama.Ollama" -ForegroundColor Yellow
    exit 1
}

if ($allModelKeys -notcontains $ModelVersion) {
    Write-Host "Modelo não suportado: $ModelVersion" -ForegroundColor Red
    Write-Host "Use -List para ver as opções de Ollama." -ForegroundColor Yellow
    exit 1
}

$modelInfo = $config.models.$ModelVersion
$modelSource = if ($modelInfo.source) { $modelInfo.source } elseif ($modelInfo.tag) { "ollama" } else { "huggingface" }

if ($modelSource -ne "ollama") {
    Write-Host "O modelo '$ModelVersion' está configurado para Hugging Face (GGUF), não para Ollama." -ForegroundColor Red
    Write-Host "Use: .\scripts\run-llamacpp.ps1 para modelos GGUF." -ForegroundColor Yellow
    Write-Host "Ou escolha uma chave *_OLLAMA usando: .\scripts\run-ollama.ps1 -List" -ForegroundColor Yellow
    exit 1
}

$ollamaModel = $modelInfo.tag

if (-not $ollamaModel) {
    Write-Host "Configuração inválida: tag Ollama ausente para '$ModelVersion'." -ForegroundColor Red
    exit 1
}

Write-Host "Modelo: $ollamaModel" -ForegroundColor Green
Write-Host ""

# Verificar se modelo está disponível
Write-Host "Verificando se modelo está disponível..." -ForegroundColor Yellow
$models = & $ollamaCommand list 2>&1
if ($models -notmatch [regex]::Escape($ollamaModel)) {
    Write-Host "Modelo não encontrado localmente. Baixando..." -ForegroundColor Yellow
    & $ollamaCommand pull $ollamaModel
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Erro ao baixar o modelo '$ollamaModel' via Ollama." -ForegroundColor Red
        exit 1
    }
}

Write-Host ""
Write-Host "Iniciando Ollama..." -ForegroundColor Yellow
Write-Host "Digite 'exit' ou Ctrl+C para sair" -ForegroundColor Gray
Write-Host ""

& $ollamaCommand run $ollamaModel
