# Script de Download de Modelo GLM-4.7 para Windows
# Baixa modelos quantizados do Hugging Face

param(
    [string]$Version = "Q4_K_S",

    [string]$OutputDir = "models",

    [switch]$All,

    [switch]$List
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = (Resolve-Path (Join-Path $scriptDir "..")).Path

if ([System.IO.Path]::IsPathRooted($OutputDir)) {
    $resolvedOutputDir = $OutputDir
}
else {
    $resolvedOutputDir = Join-Path $repoRoot $OutputDir
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Download Modelo GLM-4.7" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Carregar configuração de modelos
$configPath = Join-Path $repoRoot "config/model-config.json"
if (-not (Test-Path $configPath)) {
    Write-Host "Erro: Arquivo de configuração não encontrado: $configPath" -ForegroundColor Red
    exit 1
}

$config = Get-Content $configPath | ConvertFrom-Json
$availableModelKeys = @($config.models.PSObject.Properties.Name)

if ($List) {
    Write-Host "Modelos disponíveis:" -ForegroundColor Green
    foreach ($modelKey in $availableModelKeys) {
        $info = $config.models.$modelKey
        $source = if ($info.source) { $info.source } elseif ($info.tag) { "ollama" } else { "huggingface" }
        Write-Host "  - $modelKey [$source] -> $($info.name)" -ForegroundColor White
    }
    Write-Host ""
    Write-Host "Exemplos:" -ForegroundColor Yellow
    Write-Host "  .\scripts\download-model.ps1 -Version QWEN_CODER_14B_OLLAMA" -ForegroundColor White
    Write-Host "  .\scripts\download-model.ps1 -All" -ForegroundColor White
    exit 0
}

function Ensure-HuggingFaceCli {
    Write-Host "Verificando huggingface-cli..." -ForegroundColor Yellow
    try {
        $hfVersion = huggingface-cli --version 2>&1
        Write-Host "huggingface-cli encontrado!" -ForegroundColor Green
    }
    catch {
        Write-Host "huggingface-cli não encontrado. Instalando..." -ForegroundColor Yellow
        pip install "huggingface-hub[cli]" --quiet
    }
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

function Ensure-Ollama {
    Write-Host "Verificando Ollama..." -ForegroundColor Yellow
    $script:OllamaCommand = Resolve-OllamaCommand
    if (-not $script:OllamaCommand) {
        Write-Host "Ollama não encontrado!" -ForegroundColor Red
        Write-Host "Instale com: winget install Ollama.Ollama" -ForegroundColor Yellow
        Write-Host "Ou baixe de: https://ollama.ai/download" -ForegroundColor Yellow
        exit 1
    }

    try {
        $ollamaVersion = & $script:OllamaCommand --version 2>&1
        Write-Host "Ollama encontrado: $ollamaVersion" -ForegroundColor Green
    }
    catch {
        Write-Host "Ollama não encontrado!" -ForegroundColor Red
        Write-Host "Instale com: winget install Ollama.Ollama" -ForegroundColor Yellow
        exit 1
    }
}

function Get-FreeSpaceGB {
    param(
        [string]$Path
    )

    try {
        $resolvedPath = Resolve-Path -Path $Path -ErrorAction SilentlyContinue
        $probePath = if ($resolvedPath) { $resolvedPath.Path } else { (Resolve-Path -Path ".").Path }
        $qualifier = Split-Path -Path $probePath -Qualifier
        if (-not $qualifier) {
            return $null
        }

        $driveName = $qualifier.TrimEnd(':')
        $drive = Get-PSDrive -Name $driveName -ErrorAction SilentlyContinue
        if ($drive) {
            return ($drive.Free / 1GB)
        }
    }
    catch {
        return $null
    }

    return $null
}

if ($All) {
    $modelsToDownload = $availableModelKeys
}
else {
    if ($availableModelKeys -notcontains $Version) {
        Write-Host "Erro: Versão '$Version' não encontrada!" -ForegroundColor Red
        Write-Host "Versões disponíveis: $($availableModelKeys -join ', ')" -ForegroundColor Yellow
        Write-Host "Use -List para ver detalhes dos modelos." -ForegroundColor Yellow
        exit 1
    }

    $modelsToDownload = @($Version)
}

$needsHuggingFace = $false
$needsOllama = $false
foreach ($modelKey in $modelsToDownload) {
    $info = $config.models.$modelKey
    $source = if ($info.source) { $info.source } elseif ($info.tag) { "ollama" } else { "huggingface" }
    if ($source -eq "huggingface") { $needsHuggingFace = $true }
    if ($source -eq "ollama") { $needsOllama = $true }
}

if ($needsHuggingFace) {
    Ensure-HuggingFaceCli
}

if ($needsOllama) {
    Ensure-Ollama
}

$downloaded = @()
$failed = @()

foreach ($modelKey in $modelsToDownload) {
    $modelInfo = $config.models.$modelKey
    $source = if ($modelInfo.source) { $modelInfo.source } elseif ($modelInfo.tag) { "ollama" } else { "huggingface" }

    Write-Host "" 
    Write-Host "----------------------------------------" -ForegroundColor Cyan
    Write-Host "Modelo: $modelKey" -ForegroundColor Cyan
    Write-Host "Nome: $($modelInfo.name)" -ForegroundColor Green
    Write-Host "Fonte: $source" -ForegroundColor Yellow
    Write-Host "Tamanho aproximado: $($modelInfo.size_gb) GB" -ForegroundColor Yellow
    Write-Host "RAM mínima: $($modelInfo.min_ram_gb) GB" -ForegroundColor Yellow
    Write-Host "VRAM mínima: $($modelInfo.min_vram_gb) GB" -ForegroundColor Yellow
    Write-Host "Descrição: $($modelInfo.description)" -ForegroundColor Gray

    $freeSpace = Get-FreeSpaceGB -Path $resolvedOutputDir
    if ($null -ne $freeSpace -and $freeSpace -lt ($modelInfo.size_gb * 1.2)) {
        Write-Host "AVISO: Espaço em disco pode ser insuficiente!" -ForegroundColor Red
        Write-Host "  Espaço livre: $([math]::Round($freeSpace, 2)) GB" -ForegroundColor Yellow
        Write-Host "  Espaço necessário: ~$($modelInfo.size_gb) GB" -ForegroundColor Yellow
        $confirm = Read-Host "Continuar download deste modelo? (s/N)"
        if ($confirm -ne "s" -and $confirm -ne "S") {
            Write-Host "Pulando $modelKey por escolha do usuário." -ForegroundColor Yellow
            continue
        }
    }

    try {
        if ($source -eq "huggingface") {
            if (-not (Test-Path $resolvedOutputDir)) {
                New-Item -ItemType Directory -Path $resolvedOutputDir | Out-Null
                Write-Host "Diretório '$resolvedOutputDir' criado." -ForegroundColor Green
            }

            $modelPath = Join-Path $resolvedOutputDir $modelInfo.name
            Write-Host "Iniciando download com huggingface-cli..." -ForegroundColor Yellow

            if ($modelInfo.repo -and $modelInfo.file) {
                Write-Host "Baixando arquivo: $($modelInfo.file)" -ForegroundColor Gray
                Write-Host "Repositório: $($modelInfo.repo)" -ForegroundColor Gray

                if (-not (Test-Path $modelPath)) {
                    New-Item -ItemType Directory -Path $modelPath | Out-Null
                }

                huggingface-cli download $modelInfo.repo $modelInfo.file --local-dir $modelPath --local-dir-use-symlinks False
                $downloaded += "$modelKey -> $modelPath"
            }
            elseif ($modelInfo.repo) {
                Write-Host "Baixando de: $($modelInfo.repo)" -ForegroundColor Gray
                huggingface-cli download $modelInfo.repo --local-dir $modelPath --local-dir-use-symlinks False
                $downloaded += "$modelKey -> $modelPath"
            }
            else {
                throw "Configuração inválida para ${modelKey}: repo ausente"
            }
        }
        elseif ($source -eq "ollama") {
            if (-not $modelInfo.tag) {
                throw "Configuração inválida para ${modelKey}: tag ausente"
            }

            Write-Host "Iniciando download com Ollama..." -ForegroundColor Yellow
            Write-Host "Tag: $($modelInfo.tag)" -ForegroundColor Gray
            & $script:OllamaCommand pull $modelInfo.tag
            if ($LASTEXITCODE -ne 0) {
                throw "Falha no ollama pull para tag '$($modelInfo.tag)'"
            }
            $downloaded += "$modelKey -> ollama:$($modelInfo.tag)"
        }
        else {
            throw "Fonte de download não suportada: $source"
        }

        Write-Host "[OK] Download concluído para $modelKey" -ForegroundColor Green
    }
    catch {
        Write-Host "[ERRO] Falha ao baixar ${modelKey}: $($_.Exception.Message)" -ForegroundColor Red
        $failed += "$modelKey"
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Resumo de downloads" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

if ($downloaded.Count -gt 0) {
    Write-Host "Concluídos:" -ForegroundColor Green
    foreach ($item in $downloaded) {
        Write-Host "  - $item" -ForegroundColor White
    }
}

if ($failed.Count -gt 0) {
    Write-Host "Falhas:" -ForegroundColor Red
    foreach ($item in $failed) {
        Write-Host "  - $item" -ForegroundColor White
    }
}

Write-Host ""
Write-Host "Próximos passos:" -ForegroundColor Yellow
Write-Host "  - Liste os modelos locais do Ollama: ollama list" -ForegroundColor White
Write-Host "  - Execute com Ollama: ollama run <tag>" -ForegroundColor White
Write-Host "  - Execute GLM via GGUF: .\scripts\run-llamacpp.ps1" -ForegroundColor White
Write-Host ""
