#!/bin/bash
# Script de Detecção de Hardware para Linux/Mac
# Detecta automaticamente as especificações da máquina

set -e

echo "========================================"
echo "Detecção de Hardware"
echo "========================================"
echo ""

# Detectar CPU
echo "CPU:"
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    CPU_NAME=$(lscpu | grep "Model name" | cut -d: -f2 | xargs)
    CPU_CORES=$(nproc)
    CPU_THREADS=$(lscpu | grep "^CPU(s):" | awk '{print $2}')
elif [[ "$OSTYPE" == "darwin"* ]]; then
    CPU_NAME=$(sysctl -n machdep.cpu.brand_string)
    CPU_CORES=$(sysctl -n hw.physicalcpu)
    CPU_THREADS=$(sysctl -n hw.logicalcpu)
else
    CPU_NAME="Desconhecido"
    CPU_CORES=$(nproc 2>/dev/null || echo "?")
    CPU_THREADS=$(nproc 2>/dev/null || echo "?")
fi

echo "  Nome: $CPU_NAME"
echo "  Cores físicos: $CPU_CORES"
echo "  Threads: $CPU_THREADS"
echo ""

# Detectar RAM
echo "RAM:"
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    RAM_TOTAL_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    RAM_TOTAL_GB=$(echo "scale=2; $RAM_TOTAL_KB / 1024 / 1024" | bc)
    RAM_FREE_KB=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
    RAM_FREE_GB=$(echo "scale=2; $RAM_FREE_KB / 1024 / 1024" | bc)
elif [[ "$OSTYPE" == "darwin"* ]]; then
    RAM_TOTAL_BYTES=$(sysctl -n hw.memsize)
    RAM_TOTAL_GB=$(echo "scale=2; $RAM_TOTAL_BYTES / 1024 / 1024 / 1024" | bc)
    RAM_FREE_GB=$(vm_stat | grep "Pages free" | awk '{print $3}' | sed 's/\.//')
    RAM_FREE_GB=$(echo "scale=2; $RAM_FREE_GB * 4096 / 1024 / 1024 / 1024" | bc)
else
    RAM_TOTAL_GB="?"
    RAM_FREE_GB="?"
fi

echo "  Total: ${RAM_TOTAL_GB} GB"
echo "  Livre: ${RAM_FREE_GB} GB"
echo ""

# Detectar GPU
echo "GPU:"
VRAM_GB=0
GPU_NAME=""
if command -v nvidia-smi &> /dev/null; then
    GPU_INFO=$(nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv,noheader 2>/dev/null)
    if [ $? -eq 0 ]; then
        while IFS=',' read -r name memory driver; do
            GPU_NAME=$(echo "$name" | xargs)
            GPU_MEM=$(echo "$memory" | xargs)
            GPU_DRIVER=$(echo "$driver" | xargs)
            
            echo "  Nome: $GPU_NAME"
            echo "  VRAM: $GPU_MEM"
            echo "  Driver: $GPU_DRIVER"
            
            # Extrair VRAM em GB
            if echo "$GPU_MEM" | grep -q "MiB"; then
                VRAM_MB=$(echo "$GPU_MEM" | grep -oP '\d+' | head -1)
                VRAM_GB=$(echo "scale=2; $VRAM_MB / 1024" | bc)
            fi
        done <<< "$GPU_INFO"
    else
        echo "  GPU NVIDIA não detectada"
    fi
else
    echo "  GPU NVIDIA não detectada (nvidia-smi não encontrado)"
fi
echo ""

# Detectar espaço em disco
echo "Disco:"
df -h | grep -E "^/dev/|^/System" | awk '{print "  " $6 ": " $4 " livres de " $2}' || \
df -h . | tail -1 | awk '{print "  " $1 ": " $4 " livres de " $2}'
echo ""

# Recomendações
echo "========================================"
echo "Recomendações"
echo "========================================"
echo ""

# Determinar modelo recomendado
RECOMMENDED_MODEL="Q4_K_S"
RECOMMENDED_GPU_LAYERS=0
RECOMMENDED_CTX_SIZE=2048
CUDA_ARCH="75"  # Padrão

RAM_TOTAL_INT=$(echo "$RAM_TOTAL_GB" | cut -d. -f1)
VRAM_INT=$(echo "$VRAM_GB" | cut -d. -f1)

# Detectar arquitetura CUDA baseada na GPU
if [ -n "$GPU_NAME" ]; then
    if echo "$GPU_NAME" | grep -qiE "RTX 40|RTX 4060|RTX 4070|RTX 4080|RTX 4090"; then
        CUDA_ARCH="89"  # Ada Lovelace
    elif echo "$GPU_NAME" | grep -qiE "RTX 30|RTX 3060|RTX 3070|RTX 3080|RTX 3090"; then
        CUDA_ARCH="86"  # Ampere
    elif echo "$GPU_NAME" | grep -qiE "RTX 20|RTX 2060|RTX 2070|RTX 2080"; then
        CUDA_ARCH="75"  # Turing
    fi
fi

if [ "$VRAM_INT" -ge 24 ] && [ "$RAM_TOTAL_INT" -ge 128 ]; then
    RECOMMENDED_MODEL="UD-Q2_K_XL"
    RECOMMENDED_GPU_LAYERS=20
    RECOMMENDED_CTX_SIZE=16384
elif [ "$VRAM_INT" -ge 16 ] && [ "$RAM_TOTAL_INT" -ge 64 ]; then
    RECOMMENDED_MODEL="Q4_K_M"
    RECOMMENDED_GPU_LAYERS=15
    RECOMMENDED_CTX_SIZE=8192
elif [ "$VRAM_INT" -ge 8 ] && [ "$RAM_TOTAL_INT" -ge 32 ]; then
    # Caso especial: 8GB VRAM + 32GB RAM (como RTX 4060)
    RECOMMENDED_MODEL="Q4_K_S"
    RECOMMENDED_GPU_LAYERS=6  # Usar algumas camadas na GPU, resto em CPU
    RECOMMENDED_CTX_SIZE=4096  # Contexto adequado para código
    echo "[INFO] Configuração otimizada para desenvolvimento/codificação"
elif [ "$VRAM_INT" -ge 12 ] && [ "$RAM_TOTAL_INT" -ge 48 ]; then
    RECOMMENDED_MODEL="Q4_K_S"
    RECOMMENDED_GPU_LAYERS=10
    RECOMMENDED_CTX_SIZE=4096
elif [ "$RAM_TOTAL_INT" -ge 32 ]; then
    RECOMMENDED_MODEL="Q4_K_S"
    RECOMMENDED_GPU_LAYERS=0
    RECOMMENDED_CTX_SIZE=2048
    echo "[AVISO] Hardware muito limitado. Considere usar modelos menores ou serviços em nuvem."
else
    echo "[AVISO] Hardware insuficiente. Recomenda-se pelo menos 32GB de RAM."
fi

echo "Modelo recomendado: $RECOMMENDED_MODEL"
echo "GPU Layers recomendado: $RECOMMENDED_GPU_LAYERS"
echo "Contexto recomendado: $RECOMMENDED_CTX_SIZE"
echo ""

# Gerar configuração
echo "Gerando configuração em config/hardware-config.yaml..."

# Criar diretório config se não existir
mkdir -p config

# Fazer backup se já existir
if [ -f "config/hardware-config.yaml" ]; then
    cp "config/hardware-config.yaml" "config/hardware-config.yaml.backup"
    echo "  Backup criado: config/hardware-config.yaml.backup"
fi

# Detectar OS
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS_TYPE="linux"
elif [[ "$OSTYPE" == "darwin"* ]]; then
    OS_TYPE="macos"
else
    OS_TYPE="linux"
fi

# Calcular threads recomendado
RECOMMENDED_THREADS=$((CPU_CORES / 2))
if [ "$RECOMMENDED_THREADS" -lt 2 ]; then
    RECOMMENDED_THREADS=2
fi

# Calcular espaço em disco
DISK_SPACE=$(df -BG . | tail -1 | awk '{print $4}' | sed 's/G//' || echo "500")

cat > config/hardware-config.yaml <<EOF
# Configuração de Hardware
# Gerado automaticamente em $(date '+%Y-%m-%d %H:%M:%S')

hardware:
  gpu:
    available: $([ "$VRAM_GB" != "0" ] && echo "true" || echo "false")
    vram_gb: $VRAM_GB
    cuda_arch: "$CUDA_ARCH"  # Detectado automaticamente
  
  cpu:
    cores: $CPU_CORES
    threads: $CPU_THREADS
  
  ram_gb: $RAM_TOTAL_INT
  
  disk_space_gb: $DISK_SPACE
  
  os: "$OS_TYPE"

auto_config:
  recommended_model: "$RECOMMENDED_MODEL"
  recommended_gpu_layers: $RECOMMENDED_GPU_LAYERS
  recommended_ctx_size: $RECOMMENDED_CTX_SIZE
  recommended_threads: $RECOMMENDED_THREADS
EOF

echo "[OK] Configuração salva!"
echo ""

echo "Próximos passos:"
echo "  1. Revise a configuração: config/hardware-config.yaml"
echo "  2. Baixe o modelo: ./scripts/download-model.sh $RECOMMENDED_MODEL"
echo "  3. Execute: ./scripts/run-llamacpp.sh"
echo ""
