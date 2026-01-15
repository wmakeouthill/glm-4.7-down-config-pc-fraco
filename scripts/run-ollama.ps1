# Script de Execução GLM-4.7 com Ollama para Windows
# Mais simples, mas pode ser menos eficiente em hardware limitado

param(
    [string]$ModelVersion = "Q4_K_S"
)

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Executando GLM-4.7 com Ollama" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Verificar se Ollama está instalado
Write-Host "Verificando Ollama..." -ForegroundColor Yellow
try {
    $ollamaVersion = ollama --version 2>&1
    Write-Host "Ollama encontrado: $ollamaVersion" -ForegroundColor Green
} catch {
    Write-Host "Ollama não encontrado!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Instale o Ollama de: https://ollama.ai/download" -ForegroundColor Yellow
    Write-Host "Ou use: winget install Ollama.Ollama" -ForegroundColor Yellow
    exit 1
}

# Mapear versão para modelo Ollama
$ollamaModelMap = @{
    "UD-Q2_K_XL" = "unsloth/GLM-4.7-UD-Q2_K_XL:latest"
    "Q4_K_M" = "glm-4.7-q4_k_m"
    "Q4_K_S" = "glm-4.7-q4_k_s"
    "Q5_K_M" = "glm-4.7-q5_k_m"
}

$ollamaModel = $ollamaModelMap[$ModelVersion]

if (-not $ollamaModel) {
    Write-Host "Versão não suportada: $ModelVersion" -ForegroundColor Red
    Write-Host "Versões disponíveis: $($ollamaModelMap.Keys -join ', ')" -ForegroundColor Yellow
    exit 1
}

Write-Host "Modelo: $ollamaModel" -ForegroundColor Green
Write-Host ""

# Verificar se modelo está disponível
Write-Host "Verificando se modelo está disponível..." -ForegroundColor Yellow
$models = ollama list 2>&1
if ($models -notmatch $ModelVersion) {
    Write-Host "Modelo não encontrado localmente. Baixando..." -ForegroundColor Yellow
    Write-Host "Isso pode demorar muito tempo (100GB+)." -ForegroundColor Yellow
    Write-Host ""
    
    # Criar Modelfile
    $modelfile = @"
FROM $ollamaModel
PARAMETER temperature 1.0
PARAMETER top_p 0.95
PARAMETER num_ctx 4096
PARAMETER num_predict 8192
"@
    
    $modelfilePath = "Modelfile"
    $modelfile | Out-File -FilePath $modelfilePath -Encoding UTF8
    
    Write-Host "Criando modelo Ollama..." -ForegroundColor Yellow
    ollama create glm-4.7 -f $modelfilePath
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Erro ao criar modelo. Tentando baixar diretamente..." -ForegroundColor Yellow
        ollama pull $ollamaModel
    }
}

Write-Host ""
Write-Host "Iniciando Ollama..." -ForegroundColor Yellow
Write-Host "Digite 'exit' ou Ctrl+C para sair" -ForegroundColor Gray
Write-Host ""

ollama run glm-4.7
