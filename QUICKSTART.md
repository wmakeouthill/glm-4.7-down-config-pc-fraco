# Guia Rápido - GLM-4.7 + Ollama

Este guia rápido te ajuda a começar em poucos minutos.

## 🚀 Início Rápido (3 passos)

### Passo 1: Detectar Hardware

**Windows:**

```powershell
.\scripts\detect-hardware.ps1
```

**Linux/Mac:**

```bash
chmod +x scripts/detect-hardware.sh
./scripts/detect-hardware.sh
```

Este script detecta automaticamente seu hardware e gera uma configuração otimizada.

### Passo 2: Instalar Dependências

**Windows:**

```powershell
.\scripts\install.ps1
```

**Linux/Mac:**

```bash
chmod +x scripts/install.sh
./scripts/install.sh
```

### Passo 3: Baixar e Executar Modelo

**Windows:**

```powershell
# Ver modelos disponíveis
.\scripts\download-model.ps1 -List

# Baixar modelo GGUF GLM-4.7 (llama.cpp)
.\scripts\download-model.ps1 -Version Q4_K_S

# Executar GGUF
.\scripts\run-llamacpp.ps1
```

**Windows (Ollama - recomendado para Qwen/GLM leves):**

```powershell
# Qwen3-Coder (latest)
.\scripts\download-model.ps1 -Version QWEN3_CODER_OLLAMA

# Qwen 2.5 Coder 14B (14B leve/intermediário)
.\scripts\download-model.ps1 -Version QWEN_CODER_14B_OLLAMA

# Qwen 2.5 Coder 7B
.\scripts\download-model.ps1 -Version QWEN_CODER_7B_OLLAMA

# Rodar diretamente pelo script
.\scripts\run-ollama.ps1 -ModelVersion QWEN3_CODER_OLLAMA
```

**Linux/Mac:**

```bash
# Baixar modelo GGUF GLM-4.7
chmod +x scripts/download-model.sh
./scripts/download-model.sh Q4_K_S

# Executar GGUF
chmod +x scripts/run-llamacpp.sh
./scripts/run-llamacpp.sh
```

**Linux/Mac (Ollama - recomendado para Qwen/GLM leves):**

```bash
# Rodar listagem de modelos Ollama disponíveis
chmod +x scripts/run-ollama.sh
./scripts/run-ollama.sh --list

# Rodar modelo específico
./scripts/run-ollama.sh QWEN3_CODER_OLLAMA
```

### Passo 4 (opcional): comandos se você estiver dentro da pasta scripts

```powershell
.\download-model.ps1 -List
.\download-model.ps1 -Version QWEN3_CODER_OLLAMA
.\run-ollama.ps1 -ModelVersion QWEN3_CODER_OLLAMA
```

### Passo 5 (Windows): se `ollama` não for reconhecido no terminal

```powershell
& "$env:LOCALAPPDATA\Programs\Ollama\ollama.exe" --version
& "$env:LOCALAPPDATA\Programs\Ollama\ollama.exe" list
& "$env:LOCALAPPDATA\Programs\Ollama\ollama.exe" run qwen3-coder
```

## 📊 Escolhendo a Versão do Modelo

Baseado no seu hardware:

| Hardware | Versão Recomendada |
|----------|-------------------|
| 32GB RAM, sem GPU | Q4_K_S (pode ser lento) |
| 48GB RAM, GPU 12GB | Q4_K_S |
| 64GB RAM, GPU 16GB | Q4_K_M |
| 128GB RAM, GPU 24GB+ | UD-Q2_K_XL ou Q5_K_M |

## ⚡ Dicas para Hardware Limitado

1. **Use contexto pequeno**: Reduza `--ctx-size` para 2048 ou 4096
2. **CPU-only**: Se não tiver GPU, use `--cpu-only` ou `GPU_LAYERS=0`
3. **Menos threads**: Em máquinas com poucos cores, use menos threads
4. **Versão mais leve**: Prefira Q4_K_S sobre Q4_K_M se tiver pouca RAM

## 🆘 Problemas Comuns

### "Out of memory"

- Use uma versão mais quantizada (Q4_K_S)
- Reduza o contexto: `--ctx-size 2048`
- Use CPU-only: `--cpu-only`

### "Modelo não encontrado"

- Verifique se o download foi concluído
- Liste modelos Ollama: `ollama list`
- Ou por caminho absoluto no Windows: `& "$env:LOCALAPPDATA\Programs\Ollama\ollama.exe" list`
- Baixe novamente: `.\scripts\download-model.ps1 -Version Q4_K_S`

### "llama.cpp não encontrado"

- **Windows**: Use WSL2 ou baixe build pré-compilado
- **Linux**: Execute `./scripts/install.sh` novamente
- **Mac**: Instale Xcode Command Line Tools: `xcode-select --install`

## 📚 Mais Informações

Para mais detalhes, consulte o [README.md](README.md) completo.
