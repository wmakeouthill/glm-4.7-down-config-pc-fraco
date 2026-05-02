#!/bin/bash
# Script de Download de Modelo Qwen3.6-27B para Linux/Mac
# Baixa modelos quantizados do Hugging Face

set -e

VERSION="${1:-QWEN3_6_27B_Q4_K_M}"
OUTPUT_DIR="${2:-models}"

echo "========================================"
echo "Download Modelo Qwen3.6-27B"
echo "========================================"
echo ""

# Carregar configuracao de modelos
CONFIG_PATH="config/model-config.json"
if [ ! -f "$CONFIG_PATH" ]; then
    echo "[ERRO] Arquivo de configuração não encontrado: $CONFIG_PATH"
    exit 1
fi

OS_NAME=$(uname -s 2>/dev/null || echo "")
PYTHON_CMD=()
if [[ "$OS_NAME" == MINGW* || "$OS_NAME" == MSYS* || "$OS_NAME" == CYGWIN* ]]; then
    if command -v python &> /dev/null; then
        PYTHON_CMD=("python")
    elif command -v py &> /dev/null; then
        PYTHON_CMD=("py" "-3")
    elif command -v python3 &> /dev/null; then
        PYTHON_CMD=("python3")
    fi
else
    if command -v python3 &> /dev/null; then
        PYTHON_CMD=("python3")
    elif command -v python &> /dev/null; then
        PYTHON_CMD=("python")
    elif command -v py &> /dev/null; then
        PYTHON_CMD=("py" "-3")
    fi
fi

if [ ${#PYTHON_CMD[@]} -eq 0 ]; then
    echo "[ERRO] Python nao encontrado (necessario para ler config JSON)"
    exit 1
fi

run_python() {
    "${PYTHON_CMD[@]}" "$@"
}

# Validar versão
VALID_VERSIONS=$(run_python - <<'PY'
import json

with open('config/model-config.json', 'r', encoding='utf-8') as f:
    cfg = json.load(f)

print(' '.join(cfg.get('models', {}).keys()))
PY
)

if ! echo " ${VALID_VERSIONS} " | grep -q " ${VERSION} "; then
    echo "[ERRO] Versão inválida: $VERSION"
    echo "Versões disponíveis: ${VALID_VERSIONS}"
    exit 1
fi

# Extrair informações do modelo (usando Python para parse JSON)
MODEL_INFO=$(run_python -c "
import json
import sys

with open('$CONFIG_PATH', 'r') as f:
    config = json.load(f)
    model = config['models']['$VERSION']
    print(f\"{model['name']}|{model.get('repo', '')}|{model.get('file', '')}|{model['size_gb']}|{model['min_ram_gb']}|{model['min_vram_gb']}|{model['description']}\")
" 2>/dev/null)

if [ -z "$MODEL_INFO" ]; then
    echo "[ERRO] Não foi possível carregar informações do modelo"
    exit 1
fi

IFS='|' read -r MODEL_NAME MODEL_REPO MODEL_FILE MODEL_SIZE MIN_RAM MIN_VRAM DESCRIPTION <<< "$MODEL_INFO"

echo "Modelo selecionado: $MODEL_NAME"
echo "Tamanho aproximado: $MODEL_SIZE GB"
echo "RAM mínima: $MIN_RAM GB"
echo "VRAM mínima: $MIN_VRAM GB"
echo "Descrição: $DESCRIPTION"
echo ""

# Verificar espaco em disco
AVAILABLE_SPACE=$(df -BG "$OUTPUT_DIR" 2>/dev/null | tail -1 | awk '{print $4}' | sed 's/G//')
if [ -n "$AVAILABLE_SPACE" ]; then
    NEEDED_SPACE=$(run_python - <<PY
import math

try:
    size = float("$MODEL_SIZE")
    print(int(math.ceil(size * 1.2)))
except Exception:
    print("")
PY
)
    if [ -n "$NEEDED_SPACE" ] && [ "$AVAILABLE_SPACE" -lt "$NEEDED_SPACE" ]; then
        echo "[AVISO] Espaco em disco pode ser insuficiente!"
        echo "  Espaco livre: ${AVAILABLE_SPACE} GB"
        echo "  Espaco necessario: ~${MODEL_SIZE} GB"
        read -p "Continuar mesmo assim? (s/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Ss]$ ]]; then
            exit 0
        fi
    fi
fi

# Criar diretório de saída
mkdir -p "$OUTPUT_DIR"
echo "[OK] Diretório '$OUTPUT_DIR' criado/verificado"

# Verificar se huggingface-cli esta instalado
echo "Verificando huggingface-cli..."
HF_CLI_MODE=""
if command -v huggingface-cli &> /dev/null; then
    HF_CLI_MODE="binary"
else
    HF_CLI_MODE=$(run_python - <<'PY'
import importlib.util

def has(module):
    return importlib.util.find_spec(module) is not None

if has("huggingface_hub.hf_cli"):
    print("hf_cli")
elif has("huggingface_hub.commands.huggingface_cli"):
    print("commands")
else:
    print("none")
PY
    )
fi

if [ -z "$HF_CLI_MODE" ] || [ "$HF_CLI_MODE" = "none" ]; then
    echo "[INFO] huggingface-cli nao encontrado. Instalando..."
    run_python -m pip install "huggingface-hub" hf-transfer

    if command -v huggingface-cli &> /dev/null; then
        HF_CLI_MODE="binary"
    else
        HF_CLI_MODE=$(run_python - <<'PY'
import importlib.util

def has(module):
    return importlib.util.find_spec(module) is not None

if has("huggingface_hub.hf_cli"):
    print("hf_cli")
elif has("huggingface_hub.commands.huggingface_cli"):
    print("commands")
else:
    print("none")
PY
        )
    fi
fi

if [ -z "$HF_CLI_MODE" ] || [ "$HF_CLI_MODE" = "none" ]; then
    echo "[ERRO] huggingface-cli nao disponivel. Verifique a instalacao do huggingface-hub."
    exit 1
fi

run_hf_cli() {
    if [ "$HF_CLI_MODE" = "binary" ]; then
        huggingface-cli "$@"
        return
    fi

    if [ "$HF_CLI_MODE" = "hf_cli" ]; then
        run_python -m huggingface_hub.hf_cli "$@"
        return
    fi

    if [ "$HF_CLI_MODE" = "commands" ]; then
        run_python - "$@" <<'PY'
import sys

try:
    from huggingface_hub.commands.huggingface_cli import main
except Exception as exc:
    raise SystemExit(exc)

sys.exit(main())
PY
        return
    fi

    echo "[ERRO] Nenhuma forma valida de executar huggingface-cli."
    exit 1
}

echo "[OK] huggingface-cli encontrado"

# Baixar modelo
echo ""
echo "Iniciando download..."
echo "Isso pode demorar algum tempo dependendo da conexao."
echo ""

MODEL_PATH="$OUTPUT_DIR/$MODEL_NAME"

if [ -n "$MODEL_REPO" ] && [ -z "$MODEL_FILE" ]; then
    # Modelo do tipo unsloth (diretório completo)
    echo "Baixando de: $MODEL_REPO"
    run_hf_cli download "$MODEL_REPO" --local-dir "$MODEL_PATH" --local-dir-use-symlinks False
elif [ -n "$MODEL_REPO" ] && [ -n "$MODEL_FILE" ]; then
    # Modelo GGUF específico
    echo "Baixando arquivo: $MODEL_FILE"
    echo "Repositório: $MODEL_REPO"
    
    mkdir -p "$MODEL_PATH"
    run_hf_cli download "$MODEL_REPO" "$MODEL_FILE" --local-dir "$MODEL_PATH" --local-dir-use-symlinks False
else
    echo "[ERRO] Configuração de modelo inválida"
    exit 1
fi

echo ""
echo "========================================"
echo "Download concluido!"
echo "========================================"
echo ""
echo "Modelo salvo em: $MODEL_PATH"
echo ""
echo "Próximo passo: Execute o modelo com:"
echo "  ./scripts/run-llamacpp.sh"
echo ""
