# Script de Download de Modelo GLM-4.7 para Windows
# Baixa modelos quantizados do Hugging Face

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("UD-Q2_K_XL", "Q4_K_M", "Q4_K_S", "Q5_K_M")]
    [string]$Version = "Q4_K_S",
    
    [string]$OutputDir = "models"
)

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Download Modelo GLM-4.7" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Carregar configuração de modelos
$configPath = "config/model-config.json"
if (-not (Test-Path $configPath)) {
    Write-Host "Erro: Arquivo de configuração não encontrado: $configPath" -ForegroundColor Red
    exit 1
}

$config = Get-Content $configPath | ConvertFrom-Json

# Verificar se a versão existe
if (-not $config.models.$Version) {
    Write-Host "Erro: Versão '$Version' não encontrada!" -ForegroundColor Red
    Write-Host "Versões disponíveis: $($config.models.PSObject.Properties.Name -join ', ')" -ForegroundColor Yellow
    exit 1
}

$modelInfo = $config.models.$Version
Write-Host "Modelo selecionado: $($modelInfo.name)" -ForegroundColor Green
Write-Host "Tamanho aproximado: $($modelInfo.size_gb) GB" -ForegroundColor Yellow
Write-Host "RAM mínima: $($modelInfo.min_ram_gb) GB" -ForegroundColor Yellow
Write-Host "VRAM mínima: $($modelInfo.min_vram_gb) GB" -ForegroundColor Yellow
Write-Host "Descrição: $($modelInfo.description)" -ForegroundColor Gray
Write-Host ""

# Verificar espaço em disco
$drive = (Get-Item $OutputDir -ErrorAction SilentlyContinue).PSDrive.Name
if ($drive) {
    $freeSpace = (Get-PSDrive $drive).Free / 1GB
    if ($freeSpace -lt ($modelInfo.size_gb * 1.2)) {
        Write-Host "AVISO: Espaço em disco pode ser insuficiente!" -ForegroundColor Red
        Write-Host "  Espaço livre: $([math]::Round($freeSpace, 2)) GB" -ForegroundColor Yellow
        Write-Host "  Espaço necessário: ~$($modelInfo.size_gb) GB" -ForegroundColor Yellow
        $confirm = Read-Host "Continuar mesmo assim? (s/N)"
        if ($confirm -ne "s" -and $confirm -ne "S") {
            exit 0
        }
    }
}

# Criar diretório de saída
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir | Out-Null
    Write-Host "Diretório '$OutputDir' criado." -ForegroundColor Green
}

# Verificar se huggingface-cli está instalado
Write-Host "Verificando huggingface-cli..." -ForegroundColor Yellow
try {
    $hfVersion = huggingface-cli --version 2>&1
    Write-Host "huggingface-cli encontrado!" -ForegroundColor Green
} catch {
    Write-Host "huggingface-cli não encontrado. Instalando..." -ForegroundColor Yellow
    pip install "huggingface-hub[cli]" --quiet
}

# Baixar modelo
Write-Host ""
Write-Host "Iniciando download..." -ForegroundColor Yellow
Write-Host "Isso pode demorar muito tempo (100GB+)." -ForegroundColor Yellow
Write-Host ""

$modelPath = Join-Path $OutputDir $modelInfo.name

if ($modelInfo.repo) {
    # Modelo do tipo unsloth (diretório completo)
    Write-Host "Baixando de: $($modelInfo.repo)" -ForegroundColor Gray
    huggingface-cli download $modelInfo.repo --local-dir $modelPath --local-dir-use-symlinks False
} else {
    # Modelo GGUF específico
    Write-Host "Baixando arquivo: $($modelInfo.file)" -ForegroundColor Gray
    Write-Host "Repositório: $($modelInfo.repo)" -ForegroundColor Gray
    
    $filePath = Join-Path $modelPath $modelInfo.file
    if (-not (Test-Path $modelPath)) {
        New-Item -ItemType Directory -Path $modelPath | Out-Null
    }
    
    huggingface-cli download $modelInfo.repo $modelInfo.file --local-dir $modelPath --local-dir-use-symlinks False
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Download concluído!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Modelo salvo em: $modelPath" -ForegroundColor Green
Write-Host ""
Write-Host "Próximo passo: Execute o modelo com:" -ForegroundColor Yellow
Write-Host "  .\scripts\run-llamacpp.ps1" -ForegroundColor White
Write-Host ""
