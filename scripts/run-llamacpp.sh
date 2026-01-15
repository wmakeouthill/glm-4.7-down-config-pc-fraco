#!/bin/bash
# Script de Execução GLM-4.7 com llama.cpp para Linux/Mac
# Otimizado para hardware limitado

set -e

# Parâmetros
MODEL_VERSION="${1:-}"
CTX_SIZE="${2:-0}"
THREADS="${3:-0}"
GPU_LAYERS="${4:--1}"
CPU_ONLY="${5:-false}"
PROMPT="${6:-}"

echo "========================================"
echo "Executando GLM-4.7 com llama.cpp"
echo "========================================"
echo ""

# Carregar configurações
MODEL_CONFIG="config/model-config.json"

if [ ! -f "$MODEL_CONFIG" ]; then
    echo "[ERRO] Arquivo de configuração não encontrado: $MODEL_CONFIG"
    exit 1
fi

# Detectar modelo disponível
if [ -z "$MODEL_VERSION" ]; then
    # Tentar encontrar modelo automaticamente
    MODELS_DIR="models"
    if [ -d "$MODELS_DIR" ]; then
        # Tentar encontrar a versão mais leve primeiro
        for version in "Q4_K_S" "Q4_K_M" "Q5_K_M" "UD-Q2_K_XL"; do
            FOUND=$(find "$MODELS_DIR" -type d -name "*$version*" | head -1)
            if [ -n "$FOUND" ]; then
                MODEL_VERSION="$version"
                echo "[OK] Modelo detectado automaticamente: $(basename "$FOUND")"
                break
            fi
        done
        
        if [ -z "$MODEL_VERSION" ]; then
            # Usar primeiro modelo encontrado
            FIRST_MODEL=$(find "$MODELS_DIR" -maxdepth 1 -type d | grep -v "^$MODELS_DIR$" | head -1)
            if [ -n "$FIRST_MODEL" ]; then
                MODEL_VERSION=$(basename "$FIRST_MODEL")
                echo "[INFO] Usando primeiro modelo encontrado: $MODEL_VERSION"
            fi
        fi
    fi
    
    if [ -z "$MODEL_VERSION" ]; then
        echo "[ERRO] Nenhum modelo encontrado em 'models/'"
        echo "Baixe um modelo primeiro: ./scripts/download-model.sh Q4_K_S"
        exit 1
    fi
fi

# Encontrar arquivo do modelo
MODEL_PATH=""
MODELS_DIR="models"

# Procurar por arquivo .gguf
GGUF_FILE=$(find "$MODELS_DIR" -name "*$MODEL_VERSION*.gguf" | head -1)
if [ -n "$GGUF_FILE" ]; then
    MODEL_PATH="$GGUF_FILE"
else
    # Procurar por diretório do modelo
    MODEL_DIR=$(find "$MODELS_DIR" -type d -name "*$MODEL_VERSION*" | head -1)
    if [ -n "$MODEL_DIR" ]; then
        # Procurar .gguf dentro do diretório
        GGUF_IN_DIR=$(find "$MODEL_DIR" -name "*.gguf" | head -1)
        if [ -n "$GGUF_IN_DIR" ]; then
            MODEL_PATH="$GGUF_IN_DIR"
        else
            MODEL_PATH="$MODEL_DIR"
        fi
    fi
fi

if [ -z "$MODEL_PATH" ] || [ ! -e "$MODEL_PATH" ]; then
    echo "[ERRO] Modelo não encontrado para versão: $MODEL_VERSION"
    exit 1
fi

echo "[OK] Modelo: $MODEL_PATH"

# Detectar hardware e ajustar parâmetros
DEFAULT_SETTINGS=$(python3 -c "
import json
with open('$MODEL_CONFIG', 'r') as f:
    config = json.load(f)
    settings = config['default_settings']
    print(f\"{settings['ctx_size']}|{settings['temperature']}|{settings['top_p']}|{settings['repeat_penalty']}\")
" 2>/dev/null)

IFS='|' read -r DEFAULT_CTX DEFAULT_TEMP DEFAULT_TOP_P DEFAULT_REPEAT <<< "$DEFAULT_SETTINGS"

# Detectar GPU
HAS_GPU=false
if [ "$CPU_ONLY" != "true" ] && command -v nvidia-smi &> /dev/null; then
    if nvidia-smi &> /dev/null; then
        HAS_GPU=true
        echo "[OK] GPU NVIDIA detectada!"
        nvidia-smi --query-gpu=name,memory.total --format=csv,noheader | head -1
    fi
fi

# Ajustar parâmetros baseados no hardware
if [ "$CTX_SIZE" = "0" ]; then
    if [ "$HAS_GPU" = true ]; then
        CTX_SIZE="$DEFAULT_CTX"
    else
        LOW_RES_CTX=$(python3 -c "
import json
with open('$MODEL_CONFIG', 'r') as f:
    config = json.load(f)
    print(config['low_resource_settings']['ctx_size'])
" 2>/dev/null)
        CTX_SIZE="$LOW_RES_CTX"
        echo "[INFO] Modo CPU-only: usando contexto reduzido ($CTX_SIZE)"
    fi
fi

if [ "$THREADS" = "0" ]; then
    CPU_CORES=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)
    THREADS=$((CPU_CORES / 2))
    if [ "$THREADS" -lt 2 ]; then
        THREADS=2
    fi
    echo "[INFO] Threads: $THREADS (baseado em $CPU_CORES cores)"
fi

if [ "$GPU_LAYERS" = "-1" ]; then
    if [ "$HAS_GPU" = true ] && [ "$CPU_ONLY" != "true" ]; then
        # Tentar usar algumas camadas na GPU
        GPU_LAYERS=10
        echo "[INFO] GPU Layers: $GPU_LAYERS"
    else
        GPU_LAYERS=0
        echo "[INFO] Modo CPU-only: GPU Layers = 0"
    fi
fi

# Encontrar executável llama.cpp
LLAMA_EXE=""
POSSIBLE_PATHS=(
    "llama.cpp/build/bin/llama-cli"
    "llama.cpp/build/bin/main"
    "llama.cpp/bin/llama-cli"
    "llama.cpp/bin/main"
)

for path in "${POSSIBLE_PATHS[@]}"; do
    if [ -f "$path" ] && [ -x "$path" ]; then
        LLAMA_EXE="$path"
        break
    fi
done

if [ -z "$LLAMA_EXE" ]; then
    echo "[ERRO] Executável llama.cpp não encontrado!"
    echo "Procurei em:"
    for path in "${POSSIBLE_PATHS[@]}"; do
        echo "  - $path"
    done
    echo ""
    echo "Opções:"
    echo "  1. Execute: ./scripts/install.sh (compila automaticamente)"
    echo "  2. Compile manualmente: cd llama.cpp && cmake -B build && cmake --build build"
    exit 1
fi

# Construir comando
CMD_ARGS=(
    "-m" "$MODEL_PATH"
    "--threads" "$THREADS"
    "--ctx-size" "$CTX_SIZE"
    "--temp" "$DEFAULT_TEMP"
    "--top-p" "$DEFAULT_TOP_P"
    "--repeat-penalty" "$DEFAULT_REPEAT"
    "--jinja"
)

if [ "$GPU_LAYERS" -gt 0 ]; then
    CMD_ARGS+=("--n-gpu-layers" "$GPU_LAYERS")
    # Offload de camadas MoE para CPU (economiza VRAM)
    CMD_ARGS+=("-ot" ".ffn_.*_exps.=CPU")
fi

if [ -n "$PROMPT" ]; then
    CMD_ARGS+=("-p" "$PROMPT")
fi

# Executar
echo ""
echo "Executando llama.cpp..."
echo "Comando: $LLAMA_EXE ${CMD_ARGS[*]}"
echo ""

"$LLAMA_EXE" "${CMD_ARGS[@]}"
