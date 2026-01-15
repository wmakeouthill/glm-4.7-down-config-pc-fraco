#!/bin/bash
# Script de Execução GLM-4.7 com Ollama para Linux/Mac
# Mais simples, mas pode ser menos eficiente em hardware limitado

set -e

MODEL_VERSION="${1:-Q4_K_S}"

echo "========================================"
echo "Executando GLM-4.7 com Ollama"
echo "========================================"
echo ""

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

# Mapear versão para modelo Ollama
case "$MODEL_VERSION" in
    "UD-Q2_K_XL")
        OLLAMA_MODEL="unsloth/GLM-4.7-UD-Q2_K_XL:latest"
        ;;
    "Q4_K_M")
        OLLAMA_MODEL="glm-4.7-q4_k_m"
        ;;
    "Q4_K_S")
        OLLAMA_MODEL="glm-4.7-q4_k_s"
        ;;
    "Q5_K_M")
        OLLAMA_MODEL="glm-4.7-q5_k_m"
        ;;
    *)
        echo "[ERRO] Versão não suportada: $MODEL_VERSION"
        echo "Versões disponíveis: UD-Q2_K_XL, Q4_K_M, Q4_K_S, Q5_K_M"
        exit 1
        ;;
esac

echo "[OK] Modelo: $OLLAMA_MODEL"
echo ""

# Verificar se modelo está disponível
echo "Verificando se modelo está disponível..."
if ! ollama list | grep -q "$MODEL_VERSION"; then
    echo "[INFO] Modelo não encontrado localmente. Baixando..."
    echo "Isso pode demorar muito tempo (100GB+)."
    echo ""
    
    # Criar Modelfile
    cat > Modelfile <<EOF
FROM $OLLAMA_MODEL
PARAMETER temperature 1.0
PARAMETER top_p 0.95
PARAMETER num_ctx 4096
PARAMETER num_predict 8192
EOF
    
    echo "[INFO] Criando modelo Ollama..."
    ollama create glm-4.7 -f Modelfile || {
        echo "[INFO] Erro ao criar modelo. Tentando baixar diretamente..."
        ollama pull "$OLLAMA_MODEL"
    }
fi

echo ""
echo "Iniciando Ollama..."
echo "Digite 'exit' ou Ctrl+C para sair"
echo ""

ollama run glm-4.7
