#!/bin/bash
# Script de Execução de Modelos com Ollama para Linux/Mac
# Usa o catálogo em config/model-config.json

set -e

MODEL_VERSION="${1:-QWEN_CODER_14B_OLLAMA}"

if [[ "$1" == "--list" || "$1" == "-l" ]]; then
    LIST_MODE=true
else
    LIST_MODE=false
fi

echo "========================================"
echo "Executando Modelo com Ollama"
echo "========================================"
echo ""

# Verificar configuração
CONFIG_PATH="config/model-config.json"
if [ ! -f "$CONFIG_PATH" ]; then
    echo "[ERRO] Arquivo de configuração não encontrado: $CONFIG_PATH"
    exit 1
fi

if ! command -v python3 &> /dev/null; then
    echo "[ERRO] python3 não encontrado (necessário para ler config JSON)"
    exit 1
fi

if [ "$LIST_MODE" = true ]; then
    echo "Modelos Ollama disponíveis:"
    python3 - <<'PY'
import json

with open('config/model-config.json', 'r', encoding='utf-8') as f:
    cfg = json.load(f)

for key, info in cfg.get('models', {}).items():
    source = info.get('source') or ('ollama' if info.get('tag') else 'huggingface')
    if source == 'ollama':
        print(f"  - {key} -> {info.get('tag', '')} ({info.get('name', '')})")
PY
    echo ""
    echo "Exemplo: ./scripts/run-ollama.sh QWEN_CODER_14B_OLLAMA"
    exit 0
fi

# Verificar se Ollama está instalado
echo "Verificando Ollama..."
if ! command -v ollama &> /dev/null; then
    echo "[ERRO] Ollama não encontrado!"
    echo ""
    echo "Instale o Ollama de: https://ollama.ai/download"
    echo "Ou use: curl https://ollama.ai/install.sh | sh"
    exit 1
fi

echo "[OK] Ollama encontrado: $(ollama --version)"

MODEL_META=$(python3 - <<PY
import json
import sys

model_key = "$MODEL_VERSION"
with open('$CONFIG_PATH', 'r', encoding='utf-8') as f:
    cfg = json.load(f)

models = cfg.get('models', {})
if model_key not in models:
    print('NOT_FOUND')
    sys.exit(0)

info = models[model_key]
source = info.get('source') or ('ollama' if info.get('tag') else 'huggingface')
tag = info.get('tag', '')
name = info.get('name', '')
print(f"{source}|{tag}|{name}")
PY
)

if [ "$MODEL_META" = "NOT_FOUND" ]; then
    echo "[ERRO] Modelo não suportado: $MODEL_VERSION"
    echo "Use --list para ver as opções de Ollama."
    exit 1
fi

IFS='|' read -r MODEL_SOURCE OLLAMA_MODEL MODEL_NAME <<< "$MODEL_META"

if [ "$MODEL_SOURCE" != "ollama" ]; then
    echo "[ERRO] O modelo '$MODEL_VERSION' está configurado para Hugging Face (GGUF), não para Ollama."
    echo "Use: ./scripts/run-llamacpp.sh para modelos GGUF."
    echo "Ou escolha uma chave *_OLLAMA com: ./scripts/run-ollama.sh --list"
    exit 1
fi

if [ -z "$OLLAMA_MODEL" ]; then
    echo "[ERRO] Configuração inválida: tag Ollama ausente para '$MODEL_VERSION'"
    exit 1
fi

echo "[OK] Modelo: $OLLAMA_MODEL"
echo "[OK] Nome: $MODEL_NAME"
echo ""

# Verificar se modelo está disponível
echo "Verificando se modelo está disponível..."
if ! ollama list | grep -q "$OLLAMA_MODEL"; then
    echo "[INFO] Modelo não encontrado localmente. Baixando..."
    ollama pull "$OLLAMA_MODEL"
fi

echo ""
echo "Iniciando Ollama..."
echo "Digite 'exit' ou Ctrl+C para sair"
echo ""

ollama run "$OLLAMA_MODEL"
