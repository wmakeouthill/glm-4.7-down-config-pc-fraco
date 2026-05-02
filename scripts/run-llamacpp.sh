clear#!/bin/bash
# Script de Execucao Qwen3.6-27B com llama.cpp para Linux/Mac
# Otimizado para hardware limitado

set -e

MODEL_VERSION=""
PROFILE=""
CTX_SIZE="0"
THREADS="0"
GPU_LAYERS="-1"
CPU_ONLY="false"
PROMPT=""

USE_FLAGS=false
if [[ "${1:-}" == --* ]]; then
    USE_FLAGS=true
fi

if [ "$USE_FLAGS" = false ]; then
    MODEL_VERSION="${1:-}"
    CTX_SIZE="${2:-0}"
    THREADS="${3:-0}"
    GPU_LAYERS="${4:--1}"
    CPU_ONLY="${5:-false}"
    PROMPT="${6:-}"
else
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --model)
                MODEL_VERSION="$2"
                shift 2
                ;;
            --profile)
                PROFILE="$2"
                shift 2
                ;;
            --ctx-size)
                CTX_SIZE="$2"
                shift 2
                ;;
            --threads)
                THREADS="$2"
                shift 2
                ;;
            --gpu-layers)
                GPU_LAYERS="$2"
                shift 2
                ;;
            --cpu-only)
                CPU_ONLY="true"
                shift
                ;;
            --prompt)
                PROMPT="$2"
                shift 2
                ;;
            *)
                shift
                ;;
        esac
    done
fi

echo "========================================"
echo "Executando Qwen3.6-27B com llama.cpp"
echo "========================================"
echo ""

MODEL_CONFIG="config/model-config.json"
DEV_CONFIG="config/dev-config.json"

if [ ! -f "$MODEL_CONFIG" ]; then
    echo "[ERRO] Arquivo de configuracao nao encontrado: $MODEL_CONFIG"
    exit 1
fi

if ! command -v python3 &> /dev/null; then
    echo "[ERRO] python3 nao encontrado (necessario para ler config JSON)"
    exit 1
fi

# Carregar configuracoes base
DEFAULT_SETTINGS=$(python3 - <<'PY'
import json

with open('config/model-config.json', 'r', encoding='utf-8') as f:
    cfg = json.load(f)

settings = cfg.get('default_settings', {})
print(
    f"{settings.get('ctx_size', 4096)}|{settings.get('temperature', 0.7)}|"
    f"{settings.get('top_p', 0.95)}|{settings.get('top_k', 40)}|"
    f"{settings.get('repeat_penalty', 1.1)}|{settings.get('threads', 6)}|"
    f"{settings.get('gpu_layers', 6)}"
)
PY
)

IFS='|' read -r DEFAULT_CTX DEFAULT_TEMP DEFAULT_TOP_P DEFAULT_TOP_K DEFAULT_REPEAT DEFAULT_THREADS DEFAULT_GPU_LAYERS <<< "$DEFAULT_SETTINGS"

# Carregar perfil (opcional)
if [ -n "$PROFILE" ]; then
    PROFILE_META=$(python3 - <<PY
import json

profile_key = "$PROFILE"
with open('config/dev-config.json', 'r', encoding='utf-8') as f:
    cfg = json.load(f)

profiles = cfg.get('profiles', {})
profile = profiles.get(profile_key)
if not profile:
    print('NOT_FOUND')
else:
    settings = profile.get('settings', {})
    def get_val(key):
        val = settings.get(key)
        return '' if val is None else val

    print(
        "FOUND|{model_key}|{ctx}|{temp}|{top_p}|{top_k}|{rep}|{thr}|{gpu}".format(
            model_key=profile.get('model_key', ''),
            ctx=get_val('ctx_size'),
            temp=get_val('temperature'),
            top_p=get_val('top_p'),
            top_k=get_val('top_k'),
            rep=get_val('repeat_penalty'),
            thr=get_val('threads'),
            gpu=get_val('gpu_layers'),
        )
    )
PY
)

    if [ "$PROFILE_META" = "NOT_FOUND" ]; then
        PROFILE_LIST=$(python3 - <<'PY'
import json

with open('config/dev-config.json', 'r', encoding='utf-8') as f:
    cfg = json.load(f)

print(' '.join(cfg.get('profiles', {}).keys()))
PY
)
        echo "[ERRO] Perfil nao encontrado: $PROFILE"
        echo "Perfis disponiveis: $PROFILE_LIST"
        exit 1
    fi

    IFS='|' read -r PROFILE_STATUS PROFILE_MODEL PROFILE_CTX PROFILE_TEMP PROFILE_TOP_P PROFILE_TOP_K PROFILE_REPEAT PROFILE_THREADS PROFILE_GPU <<< "$PROFILE_META"

    if [ -z "$MODEL_VERSION" ] && [ -n "$PROFILE_MODEL" ]; then
        MODEL_VERSION="$PROFILE_MODEL"
    fi

    if [ -n "$PROFILE_CTX" ]; then DEFAULT_CTX="$PROFILE_CTX"; fi
    if [ -n "$PROFILE_TEMP" ]; then DEFAULT_TEMP="$PROFILE_TEMP"; fi
    if [ -n "$PROFILE_TOP_P" ]; then DEFAULT_TOP_P="$PROFILE_TOP_P"; fi
    if [ -n "$PROFILE_TOP_K" ]; then DEFAULT_TOP_K="$PROFILE_TOP_K"; fi
    if [ -n "$PROFILE_REPEAT" ]; then DEFAULT_REPEAT="$PROFILE_REPEAT"; fi
    if [ -n "$PROFILE_THREADS" ]; then DEFAULT_THREADS="$PROFILE_THREADS"; fi
    if [ -n "$PROFILE_GPU" ]; then DEFAULT_GPU_LAYERS="$PROFILE_GPU"; fi
fi

MODEL_KEYS=$(python3 - <<'PY'
import json

with open('config/model-config.json', 'r', encoding='utf-8') as f:
    cfg = json.load(f)

print(' '.join(cfg.get('models', {}).keys()))
PY
)

resolve_model_path() {
    python3 - <<PY
import json
import os

model_key = "$1"
models_dir = "models"

with open('config/model-config.json', 'r', encoding='utf-8') as f:
    cfg = json.load(f)

info = cfg.get('models', {}).get(model_key)
if not info:
    print("")
    raise SystemExit

name = info.get('name', '')
file_name = info.get('file', '')

if name and file_name:
    candidate = os.path.join(models_dir, name, file_name)
    if os.path.exists(candidate):
        print(candidate)
        raise SystemExit

if name:
    candidate_dir = os.path.join(models_dir, name)
    if os.path.isdir(candidate_dir):
        for root, _, files in os.walk(candidate_dir):
            for fn in files:
                if fn.endswith('.gguf'):
                    print(os.path.join(root, fn))
                    raise SystemExit
        print(candidate_dir)
        raise SystemExit

if file_name:
    for root, _, files in os.walk(models_dir):
        if file_name in files:
            print(os.path.join(root, file_name))
            raise SystemExit

print("")
PY
}

# Detectar modelo disponivel
if [ -z "$MODEL_VERSION" ]; then
    for candidate in "QWEN3_6_27B_Q4_K_M" "QWEN3_6_27B_Q8_0"; do
        MODEL_PATH=$(resolve_model_path "$candidate")
        if [ -n "$MODEL_PATH" ]; then
            MODEL_VERSION="$candidate"
            break
        fi
    done
fi

if [ -z "$MODEL_VERSION" ]; then
    echo "[ERRO] Nenhum modelo encontrado em 'models/'"
    echo "Baixe um modelo primeiro: ./scripts/download-model.sh QWEN3_6_27B_Q4_K_M"
    exit 1
fi

MODEL_PATH=""
if echo " $MODEL_KEYS " | grep -q " $MODEL_VERSION "; then
    MODEL_PATH=$(resolve_model_path "$MODEL_VERSION")
else
    GGUF_FILE=$(find "models" -name "*$MODEL_VERSION*.gguf" | head -1)
    if [ -n "$GGUF_FILE" ]; then
        MODEL_PATH="$GGUF_FILE"
    else
        MODEL_DIR=$(find "models" -type d -name "*$MODEL_VERSION*" | head -1)
        if [ -n "$MODEL_DIR" ]; then
            GGUF_IN_DIR=$(find "$MODEL_DIR" -name "*.gguf" | head -1)
            if [ -n "$GGUF_IN_DIR" ]; then
                MODEL_PATH="$GGUF_IN_DIR"
            else
                MODEL_PATH="$MODEL_DIR"
            fi
        fi
    fi
fi

if [ -z "$MODEL_PATH" ] || [ ! -e "$MODEL_PATH" ]; then
    echo "[ERRO] Modelo nao encontrado para versao: $MODEL_VERSION"
    exit 1
fi

echo "[OK] Modelo: $MODEL_PATH"

# Detectar GPU
HAS_GPU=false
if [ "$CPU_ONLY" != "true" ] && command -v nvidia-smi &> /dev/null; then
    if nvidia-smi &> /dev/null; then
        HAS_GPU=true
        echo "[OK] GPU NVIDIA detectada!"
        nvidia-smi --query-gpu=name,memory.total --format=csv,noheader | head -1
    fi
fi

# Ajustar parametros baseados no hardware
if [ "$CTX_SIZE" = "0" ]; then
    if [ "$HAS_GPU" = false ] && [ -z "$PROFILE" ]; then
        LOW_RES_CTX=$(python3 - <<'PY'
import json

with open('config/model-config.json', 'r', encoding='utf-8') as f:
    cfg = json.load(f)

print(cfg.get('low_resource_settings', {}).get('ctx_size', 2048))
PY
)
        CTX_SIZE="$LOW_RES_CTX"
        echo "[INFO] Modo CPU-only: usando contexto reduzido ($CTX_SIZE)"
    else
        CTX_SIZE="$DEFAULT_CTX"
    fi
fi

if [ "$THREADS" = "0" ]; then
    if [ -n "$DEFAULT_THREADS" ] && [ "$DEFAULT_THREADS" != "0" ]; then
        THREADS="$DEFAULT_THREADS"
    else
        CPU_CORES=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)
        THREADS=$((CPU_CORES / 2))
        if [ "$THREADS" -lt 2 ]; then
            THREADS=2
        fi
    fi
    echo "[INFO] Threads: $THREADS"
fi

if [ "$GPU_LAYERS" = "-1" ]; then
    if [ "$HAS_GPU" = true ] && [ "$CPU_ONLY" != "true" ]; then
        if [ -n "$DEFAULT_GPU_LAYERS" ] && [ "$DEFAULT_GPU_LAYERS" != "0" ]; then
            GPU_LAYERS="$DEFAULT_GPU_LAYERS"
        else
            GPU_LAYERS=10
        fi
        echo "[INFO] GPU Layers: $GPU_LAYERS"
    else
        GPU_LAYERS=0
        echo "[INFO] Modo CPU-only: GPU Layers = 0"
    fi
fi

if [ "$CPU_ONLY" = "true" ]; then
    GPU_LAYERS=0
fi

# Encontrar executavel llama.cpp
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
    echo "[ERRO] Executavel llama.cpp nao encontrado!"
    echo "Procurei em:"
    for path in "${POSSIBLE_PATHS[@]}"; do
        echo "  - $path"
    done
    echo ""
    echo "Opcoes:"
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
    "--top-k" "$DEFAULT_TOP_K"
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
