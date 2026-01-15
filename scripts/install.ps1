# Script de Instalação GLM-4.7 para Windows
# Este script instala todas as dependências necessárias

param(
    [switch]$SkipCuda = $false,
    [switch]$SkipLlamaCpp = $false
)

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Instalação GLM-4.7 - Windows" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Verificar se Python está instalado
Write-Host "[1/5] Verificando Python..." -ForegroundColor Yellow
try {
    $pythonVersion = python --version 2>&1
    Write-Host "Python encontrado: $pythonVersion" -ForegroundColor Green
} catch {
    Write-Host "Python não encontrado! Instale Python 3.10+ de https://www.python.org/" -ForegroundColor Red
    exit 1
}

# Verificar se pip está instalado
Write-Host "[2/5] Verificando pip..." -ForegroundColor Yellow
try {
    $pipVersion = pip --version 2>&1
    Write-Host "pip encontrado: $pipVersion" -ForegroundColor Green
} catch {
    Write-Host "pip não encontrado! Instalando pip..." -ForegroundColor Yellow
    python -m ensurepip --upgrade
}

# Instalar dependências Python
Write-Host "[3/5] Instalando dependências Python..." -ForegroundColor Yellow
$packages = @(
    "huggingface-hub",
    "huggingface-hub[cli]",
    "hf-transfer"
)

foreach ($package in $packages) {
    Write-Host "  Instalando $package..." -ForegroundColor Gray
    pip install $package --quiet
}

Write-Host "Dependências Python instaladas!" -ForegroundColor Green

# Verificar CUDA (opcional)
if (-not $SkipCuda) {
    Write-Host "[4/5] Verificando CUDA..." -ForegroundColor Yellow
    try {
        $nvidiaSmi = nvidia-smi 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "GPU NVIDIA detectada!" -ForegroundColor Green
            $gpuInfo = nvidia-smi --query-gpu=name,memory.total --format=csv,noheader
            Write-Host "  $gpuInfo" -ForegroundColor Gray
        } else {
            Write-Host "GPU NVIDIA não detectada. Continuando sem CUDA..." -ForegroundColor Yellow
        }
    } catch {
        Write-Host "nvidia-smi não encontrado. Continuando sem CUDA..." -ForegroundColor Yellow
    }
}

# Instalar/Compilar llama.cpp (opcional)
if (-not $SkipLlamaCpp) {
    Write-Host "[5/5] Configurando llama.cpp..." -ForegroundColor Yellow
    
    if (Test-Path "llama.cpp") {
        Write-Host "  Diretório llama.cpp já existe. Pulando download..." -ForegroundColor Gray
    } else {
        Write-Host "  Baixando llama.cpp..." -ForegroundColor Gray
        git clone https://github.com/ggerganov/llama.cpp.git
        if ($LASTEXITCODE -ne 0) {
            Write-Host "  Erro ao clonar llama.cpp. Certifique-se de ter Git instalado." -ForegroundColor Red
            Write-Host "  Você pode baixar manualmente de: https://github.com/ggerganov/llama.cpp" -ForegroundColor Yellow
        }
    }
    
    if (Test-Path "llama.cpp") {
        Write-Host "  Para compilar llama.cpp no Windows, você precisa:" -ForegroundColor Yellow
        Write-Host "    1. Instalar Visual Studio com C++ tools" -ForegroundColor Gray
        Write-Host "    2. Ou usar builds pré-compilados de: https://github.com/ggerganov/llama.cpp/releases" -ForegroundColor Gray
        Write-Host "    3. Ou usar WSL2 (Windows Subsystem for Linux)" -ForegroundColor Gray
    }
}

# Criar diretório de modelos
Write-Host ""
Write-Host "Criando diretório de modelos..." -ForegroundColor Yellow
if (-not (Test-Path "models")) {
    New-Item -ItemType Directory -Path "models" | Out-Null
    Write-Host "  Diretório 'models' criado!" -ForegroundColor Green
} else {
    Write-Host "  Diretório 'models' já existe." -ForegroundColor Gray
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Instalação concluída!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Próximos passos:" -ForegroundColor Yellow
Write-Host "  1. Configure seu hardware em: config/hardware-config.yaml" -ForegroundColor White
Write-Host "  2. Baixe um modelo: .\scripts\download-model.ps1 -Version Q4_K_S" -ForegroundColor White
Write-Host "  3. Execute o modelo: .\scripts\run-llamacpp.ps1" -ForegroundColor White
Write-Host ""
