#!/bin/bash
# Script de Instalação GLM-4.7 para Linux/Mac
# Este script instala todas as dependências necessárias

set -e

echo "========================================"
echo "Instalação GLM-4.7 - Linux/Mac"
echo "========================================"
echo ""

# Detectar sistema operacional
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS="linux"
    echo "[INFO] Sistema operacional: Linux"
elif [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macos"
    echo "[INFO] Sistema operacional: macOS"
else
    echo "[ERRO] Sistema operacional não suportado: $OSTYPE"
    exit 1
fi

# Verificar se Python está instalado
echo "[1/6] Verificando Python..."
if command -v python3 &> /dev/null; then
    PYTHON_VERSION=$(python3 --version)
    echo "[OK] Python encontrado: $PYTHON_VERSION"
    PYTHON_CMD="python3"
    PIP_CMD="pip3"
elif command -v python &> /dev/null; then
    PYTHON_VERSION=$(python --version)
    echo "[OK] Python encontrado: $PYTHON_VERSION"
    PYTHON_CMD="python"
    PIP_CMD="pip"
else
    echo "[ERRO] Python não encontrado! Instale Python 3.10+"
    exit 1
fi

# Verificar se pip está instalado
echo "[2/6] Verificando pip..."
if ! command -v $PIP_CMD &> /dev/null; then
    echo "[INFO] pip não encontrado. Instalando..."
    $PYTHON_CMD -m ensurepip --upgrade
fi
echo "[OK] pip encontrado: $($PIP_CMD --version)"

# Instalar dependências do sistema (Linux)
if [[ "$OS" == "linux" ]]; then
    echo "[3/6] Instalando dependências do sistema (Linux)..."
    if command -v apt-get &> /dev/null; then
        sudo apt-get update
        sudo apt-get install -y build-essential cmake git curl
    elif command -v yum &> /dev/null; then
        sudo yum install -y gcc gcc-c++ cmake git curl
    elif command -v pacman &> /dev/null; then
        sudo pacman -S --noconfirm base-devel cmake git curl
    else
        echo "[AVISO] Gerenciador de pacotes não reconhecido. Instale manualmente: build-essential, cmake, git"
    fi
    echo "[OK] Dependências do sistema instaladas"
elif [[ "$OS" == "macos" ]]; then
    echo "[3/6] Verificando Homebrew (macOS)..."
    if ! command -v brew &> /dev/null; then
        echo "[AVISO] Homebrew não encontrado. Instale de: https://brew.sh"
    else
        brew install cmake git || true
    fi
    echo "[OK] Dependências do sistema verificadas"
fi

# Instalar dependências Python
echo "[4/6] Instalando dependências Python..."
$PIP_CMD install --upgrade pip
$PIP_CMD install huggingface-hub "huggingface-hub[cli]" hf-transfer
echo "[OK] Dependências Python instaladas"

# Verificar CUDA (opcional)
echo "[5/6] Verificando CUDA..."
if command -v nvidia-smi &> /dev/null; then
    echo "[OK] GPU NVIDIA detectada!"
    nvidia-smi --query-gpu=name,memory.total --format=csv,noheader
    CUDA_AVAILABLE=true
else
    echo "[INFO] GPU NVIDIA não detectada. Continuando sem CUDA..."
    CUDA_AVAILABLE=false
fi

# Instalar/Compilar llama.cpp
echo "[6/6] Configurando llama.cpp..."
if [ -d "llama.cpp" ]; then
    echo "[INFO] Diretório llama.cpp já existe. Atualizando..."
    cd llama.cpp
    git pull || true
    cd ..
else
    echo "[INFO] Baixando llama.cpp..."
    git clone https://github.com/ggerganov/llama.cpp.git
fi

if [ -d "llama.cpp" ]; then
    echo "[INFO] Compilando llama.cpp..."
    cd llama.cpp
    
    # Configurar build
    if [ "$CUDA_AVAILABLE" = true ]; then
        echo "[INFO] Compilando com suporte CUDA..."
        cmake -B build -DGGML_CUDA=ON
    else
        echo "[INFO] Compilando sem CUDA (CPU only)..."
        cmake -B build
    fi
    
    # Compilar
    cmake --build build --config Release -j$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)
    
    cd ..
    echo "[OK] llama.cpp compilado com sucesso!"
fi

# Criar diretório de modelos
echo ""
echo "Criando diretório de modelos..."
mkdir -p models
echo "[OK] Diretório 'models' criado"

echo ""
echo "========================================"
echo "Instalação concluída!"
echo "========================================"
echo ""
echo "Próximos passos:"
echo "  1. Configure seu hardware em: config/hardware-config.yaml"
echo "  2. Baixe um modelo: ./scripts/download-model.sh Q4_K_S"
echo "  3. Execute o modelo: ./scripts/run-llamacpp.sh"
echo ""
