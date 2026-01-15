#!/bin/bash
# Script de Download de Modelo GLM-4.7 para Linux/Mac
# Baixa modelos quantizados do Hugging Face

set -e

VERSION="${1:-Q4_K_S}"
OUTPUT_DIR="${2:-models}"

echo "========================================"
echo "Download Modelo GLM-4.7"
echo "========================================"
echo ""

# Validar versão
VALID_VERSIONS=("UD-Q2_K_XL" "Q4_K_M" "Q4_K_S" "Q5_K_M")
if [[ ! " ${VALID_VERSIONS[@]} " =~ " ${VERSION} " ]]; then
    echo "[ERRO] Versão inválida: $VERSION"
    echo "Versões disponíveis: ${VALID_VERSIONS[*]}"
    exit 1
fi

# Carregar configuração de modelos
CONFIG_PATH="config/model-config.json"
if [ ! -f "$CONFIG_PATH" ]; then
    echo "[ERRO] Arquivo de configuração não encontrado: $CONFIG_PATH"
    exit 1
fi

# Extrair informações do modelo (usando Python para parse JSON)
MODEL_INFO=$(python3 -c "
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

# Verificar espaço em disco
AVAILABLE_SPACE=$(df -BG "$OUTPUT_DIR" 2>/dev/null | tail -1 | awk '{print $4}' | sed 's/G//')
if [ -n "$AVAILABLE_SPACE" ] && [ "$AVAILABLE_SPACE" -lt "$(echo "$MODEL_SIZE * 1.2" | bc)" ]; then
    echo "[AVISO] Espaço em disco pode ser insuficiente!"
    echo "  Espaço livre: ${AVAILABLE_SPACE} GB"
    echo "  Espaço necessário: ~${MODEL_SIZE} GB"
    read -p "Continuar mesmo assim? (s/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Ss]$ ]]; then
        exit 0
    fi
fi

# Criar diretório de saída
mkdir -p "$OUTPUT_DIR"
echo "[OK] Diretório '$OUTPUT_DIR' criado/verificado"

# Verificar se huggingface-cli está instalado
echo "Verificando huggingface-cli..."
if ! command -v huggingface-cli &> /dev/null; then
    echo "[INFO] huggingface-cli não encontrado. Instalando..."
    pip3 install "huggingface-hub[cli]" hf-transfer
fi
echo "[OK] huggingface-cli encontrado"

# Baixar modelo
echo ""
echo "Iniciando download..."
echo "Isso pode demorar muito tempo (100GB+)."
echo ""

MODEL_PATH="$OUTPUT_DIR/$MODEL_NAME"

if [ -n "$MODEL_REPO" ] && [ -z "$MODEL_FILE" ]; then
    # Modelo do tipo unsloth (diretório completo)
    echo "Baixando de: $MODEL_REPO"
    huggingface-cli download "$MODEL_REPO" --local-dir "$MODEL_PATH" --local-dir-use-symlinks False
elif [ -n "$MODEL_REPO" ] && [ -n "$MODEL_FILE" ]; then
    # Modelo GGUF específico
    echo "Baixando arquivo: $MODEL_FILE"
    echo "Repositório: $MODEL_REPO"
    
    mkdir -p "$MODEL_PATH"
    huggingface-cli download "$MODEL_REPO" "$MODEL_FILE" --local-dir "$MODEL_PATH" --local-dir-use-symlinks False
else
    echo "[ERRO] Configuração de modelo inválida"
    exit 1
fi

echo ""
echo "========================================"
echo "Download concluído!"
echo "========================================"
echo ""
echo "Modelo salvo em: $MODEL_PATH"
echo ""
echo "Próximo passo: Execute o modelo com:"
echo "  ./scripts/run-llamacpp.sh"
echo ""
