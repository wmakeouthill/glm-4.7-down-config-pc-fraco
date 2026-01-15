# Script de Detecção de Hardware para Windows
# Detecta automaticamente as especificações da máquina

$ErrorActionPreference = "Continue"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Detecção de Hardware" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Detectar CPU
Write-Host "CPU:" -ForegroundColor Yellow
$cpu = Get-WmiObject Win32_Processor
$cpuName = $cpu.Name
$cpuCores = $cpu.NumberOfCores
$cpuThreads = $cpu.NumberOfLogicalProcessors
Write-Host "  Nome: $cpuName" -ForegroundColor White
Write-Host "  Cores físicos: $cpuCores" -ForegroundColor White
Write-Host "  Threads: $cpuThreads" -ForegroundColor White
Write-Host ""

# Detectar RAM
Write-Host "RAM:" -ForegroundColor Yellow
$ram = Get-WmiObject Win32_ComputerSystem
$ramTotalGB = [math]::Round($ram.TotalPhysicalMemory / 1GB, 2)
$ramFreeGB = [math]::Round((Get-WmiObject Win32_OperatingSystem).FreePhysicalMemory / 1MB, 2)
Write-Host "  Total: $ramTotalGB GB" -ForegroundColor White
Write-Host "  Livre: $ramFreeGB GB" -ForegroundColor White
Write-Host ""

# Detectar GPU
Write-Host "GPU:" -ForegroundColor Yellow
$gpuName = ""
$vramGB = 0
try {
    $gpu = nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv,noheader 2>&1
    if ($LASTEXITCODE -eq 0) {
        $gpuLines = $gpu -split "`n"
        foreach ($line in $gpuLines) {
            if ($line.Trim()) {
                $parts = $line -split ","
                $gpuName = $parts[0].Trim()
                $gpuMem = $parts[1].Trim()
                $gpuDriver = $parts[2].Trim()
                Write-Host "  Nome: $gpuName" -ForegroundColor White
                Write-Host "  VRAM: $gpuMem" -ForegroundColor White
                Write-Host "  Driver: $gpuDriver" -ForegroundColor White
                
                # Extrair VRAM em GB
                if ($gpuMem -match "(\d+)\s*MiB") {
                    $vramMB = [int]$matches[1]
                    $vramGB = [math]::Round($vramMB / 1024, 2)
                }
            }
        }
    } else {
        Write-Host "  GPU NVIDIA não detectada" -ForegroundColor Gray
        $vramGB = 0
    }
} catch {
    Write-Host "  GPU NVIDIA não detectada" -ForegroundColor Gray
    $vramGB = 0
}
Write-Host ""

# Detectar espaço em disco
Write-Host "Disco:" -ForegroundColor Yellow
$drives = Get-PSDrive -PSProvider FileSystem
foreach ($drive in $drives) {
    $freeGB = [math]::Round($drive.Free / 1GB, 2)
    $usedGB = [math]::Round(($drive.Used + $drive.Free) / 1GB, 2)
    Write-Host "  $($drive.Name): $freeGB GB livres de $usedGB GB" -ForegroundColor White
}
Write-Host ""

# Recomendações
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Recomendações" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Determinar modelo recomendado
$recommendedModel = "Q4_K_S"
$recommendedGpuLayers = 0
$recommendedCtxSize = 2048

# Ajustar CUDA arch baseado na GPU detectada
$cudaArch = "75"  # Padrão
if ($gpuName -match "RTX 40|RTX 4060|RTX 4070|RTX 4080|RTX 4090") {
    $cudaArch = "89"  # Ada Lovelace
} elseif ($gpuName -match "RTX 30|RTX 3060|RTX 3070|RTX 3080|RTX 3090") {
    $cudaArch = "86"  # Ampere
} elseif ($gpuName -match "RTX 20|RTX 2060|RTX 2070|RTX 2080") {
    $cudaArch = "75"  # Turing
}

if ($vramGB -ge 24 -and $ramTotalGB -ge 128) {
    $recommendedModel = "UD-Q2_K_XL"
    $recommendedGpuLayers = 20
    $recommendedCtxSize = 16384
} elseif ($vramGB -ge 16 -and $ramTotalGB -ge 64) {
    $recommendedModel = "Q4_K_M"
    $recommendedGpuLayers = 15
    $recommendedCtxSize = 8192
} elseif ($vramGB -ge 8 -and $ramTotalGB -ge 32) {
    # Caso especial: 8GB VRAM + 32GB RAM (como RTX 4060)
    $recommendedModel = "Q4_K_S"
    $recommendedGpuLayers = 6  # Usar algumas camadas na GPU, resto em CPU
    $recommendedCtxSize = 4096  # Contexto adequado para código
    Write-Host "Configuração otimizada para desenvolvimento/codificação" -ForegroundColor Green
} elseif ($vramGB -ge 12 -and $ramTotalGB -ge 48) {
    $recommendedModel = "Q4_K_S"
    $recommendedGpuLayers = 10
    $recommendedCtxSize = 4096
} elseif ($ramTotalGB -ge 32) {
    $recommendedModel = "Q4_K_S"
    $recommendedGpuLayers = 0
    $recommendedCtxSize = 2048
    Write-Host "AVISO: Hardware muito limitado. Considere usar modelos menores ou serviços em nuvem." -ForegroundColor Yellow
}

Write-Host "Modelo recomendado: $recommendedModel" -ForegroundColor Green
Write-Host "GPU Layers recomendado: $recommendedGpuLayers" -ForegroundColor Green
Write-Host "Contexto recomendado: $recommendedCtxSize" -ForegroundColor Green
Write-Host ""

# Gerar configuração
Write-Host "Gerando configuração em config/hardware-config.yaml..." -ForegroundColor Yellow

$configContent = @"
# Configuração de Hardware
# Gerado automaticamente em $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

hardware:
  gpu:
    available: $($vramGB -gt 0)
    vram_gb: $vramGB
    cuda_arch: "$cudaArch"  # Detectado automaticamente
  
  cpu:
    cores: $cpuCores
    threads: $cpuThreads
  
  ram_gb: $ramTotalGB
  
  disk_space_gb: $([math]::Round((Get-PSDrive -PSProvider FileSystem | Measure-Object Free -Sum).Sum / 1GB, 2))
  
  os: "windows"

auto_config:
  recommended_model: "$recommendedModel"
  recommended_gpu_layers: $recommendedGpuLayers
  recommended_ctx_size: $recommendedCtxSize
  recommended_threads: $([math]::Max(2, [math]::Floor($cpuThreads / 2)))
"@

# Criar diretório config se não existir
if (-not (Test-Path "config")) {
    New-Item -ItemType Directory -Path "config" | Out-Null
}

# Fazer backup se já existir
if (Test-Path "config/hardware-config.yaml") {
    $backupPath = "config/hardware-config.yaml.backup"
    Copy-Item "config/hardware-config.yaml" $backupPath -Force
    Write-Host "  Backup criado: $backupPath" -ForegroundColor Gray
}

$configContent | Out-File -FilePath "config/hardware-config.yaml" -Encoding UTF8
Write-Host "[OK] Configuração salva!" -ForegroundColor Green
Write-Host ""

Write-Host "Próximos passos:" -ForegroundColor Yellow
Write-Host "  1. Revise a configuração: config/hardware-config.yaml" -ForegroundColor White
Write-Host "  2. Baixe o modelo: .\scripts\download-model.ps1 -Version $recommendedModel" -ForegroundColor White
Write-Host "  3. Execute: .\scripts\run-llamacpp.ps1" -ForegroundColor White
Write-Host ""
