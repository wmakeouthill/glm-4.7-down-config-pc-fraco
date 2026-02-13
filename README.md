# GLM-4.7 - Instalação e Configuração para PC Fraco

Este repositório contém scripts automatizados para baixar, instalar e testar modelos locais em máquinas com recursos limitados.

Atualmente, os scripts estão prontos para uso com **GLM-4.7** (GGUF/llama.cpp) e modelos **Ollama** (Qwen, GLM leve, DeepSeek, Codestral), com foco em validar se o PC aguenta cada perfil de modelo.

## 📋 Requisitos Mínimos

### Hardware Mínimo (CPU Only)

- **RAM**: 32GB+ (recomendado 64GB+)
- **Disco**: 200GB+ de espaço livre (SSD recomendado)
- **CPU**: Processador multi-core moderno

### Hardware Recomendado (com GPU)

- **GPU**: 8GB+ VRAM (recomendado 16GB+)
- **RAM**: 64GB+ (recomendado 128GB+)
- **Disco**: 300GB+ de espaço livre (NVMe SSD recomendado)
- **CUDA**: Compatível com CUDA 11.8+ ou 12.1+

## 🎯 Versões de Modelo Disponíveis

O GLM-4.7 está disponível em várias quantizações para diferentes capacidades de hardware:

| Versão | Tamanho | RAM Mínima | VRAM Mínima | Uso Recomendado |
|--------|---------|------------|-------------|-----------------|
| **UD-Q2_K_XL** (2-bit) | ~135GB | 128GB | 24GB | Máquinas potentes com GPU |
| **Q4_K_M** (4-bit) | ~200GB | 64GB | 16GB | Máquinas moderadas |
| **Q4_K_S** (4-bit) | ~180GB | 48GB | 12GB | Máquinas modestas |
| **Q5_K_M** (5-bit) | ~240GB | 80GB | 20GB | Melhor qualidade |

## 🧠 Comparativo Prático para Codificação

Critério de escolha entre famílias de modelos para desenvolvimento local:

| Critério | Qwen3-Coder (32B/80B MoE) | GLM-4.7 (Reasoning) | MiniMax M2.1 |
|----------|----------------------------|---------------------|--------------|
| Ponto forte | Lógica pura e algoritmos | Arquitetura e documentação | Velocidade e iteração de agentes |
| Python | SOTA (state-of-the-art) | Excelente | Muito bom |
| React/Angular | Código funcional, mas seco | Superior (UI/UX e componentização) | Rápido, mas às vezes incompleto |
| Java / .NET | Ótimo em métodos isolados | Líder em padrões corporativos | Bom para refatoração rápida |
| “Vibe” Opus | “Gênio matemático” | “Arquiteto sênior” | “Dev júnior muito rápido” |

> Observação: o quadro acima é um guia prático de escolha por perfil de tarefa. Neste repositório, você pode usar tanto modelos GGUF (Hugging Face + llama.cpp) quanto modelos Ollama (Qwen/GLM/DeepSeek/Codestral).

## 🚀 Início Rápido

### Windows (PowerShell)

```powershell
# 1. Instalar dependências
.\scripts\install.ps1

# 2. Ver modelos disponíveis
.\scripts\download-model.ps1 -List

# 3A. Baixar modelo Ollama (ex.: Qwen3)
.\scripts\download-model.ps1 -Version QWEN3_CODER_OLLAMA

# 3B. Baixar modelo Ollama 14B leve (Qwen 2.5 Coder 14B)
.\scripts\download-model.ps1 -Version QWEN_CODER_14B_OLLAMA

# 3C. Baixar modelo GGUF GLM-4.7
.\scripts\download-model.ps1 -Version Q4_K_S -OutputDir .\models

# 4A. Rodar modelo Ollama pelo script
.\scripts\run-ollama.ps1 -ModelVersion QWEN3_CODER_OLLAMA

# 4B. Rodar modelo GGUF no llama.cpp
.\scripts\run-llamacpp.ps1
```

### Linux/Mac (Bash)

```bash
# 1. Instalar dependências
chmod +x scripts/install.sh
./scripts/install.sh

# 2. Baixar modelo GGUF GLM-4.7
chmod +x scripts/download-model.sh
./scripts/download-model.sh Q4_K_S

# 3. Executar GGUF com llama.cpp
chmod +x scripts/run-llamacpp.sh
./scripts/run-llamacpp.sh

# 4. Ver modelos Ollama e rodar um modelo
chmod +x scripts/run-ollama.sh
./scripts/run-ollama.sh --list
./scripts/run-ollama.sh QWEN3_CODER_OLLAMA
```

## 🧪 Comandos Prontos (Copy/Paste)

### 1) Lista de chaves de modelo

Na raiz do projeto:

```powershell
.\scripts\download-model.ps1 -List
.\scripts\run-ollama.ps1 -List
```

Se estiver dentro de `scripts`:

```powershell
.\download-model.ps1 -List
.\run-ollama.ps1 -List
```

### 2) Download de modelos Ollama (Windows)

```powershell
# Qwen3-Coder (latest)
.\scripts\download-model.ps1 -Version QWEN3_CODER_OLLAMA

# Qwen 2.5 Coder 14B (leve/intermediário)
.\scripts\download-model.ps1 -Version QWEN_CODER_14B_OLLAMA

# Qwen 2.5 Coder 7B
.\scripts\download-model.ps1 -Version QWEN_CODER_7B_OLLAMA

# GLM-4 9B (leve)
.\scripts\download-model.ps1 -Version GLM_4_9B_OLLAMA

# DeepSeek Coder V2 16B
.\scripts\download-model.ps1 -Version DEEPSEEK_CODER_V2_16B_OLLAMA

# Codestral 22B
.\scripts\download-model.ps1 -Version CODESTRAL_22B_OLLAMA
```

### 2.1) Teste rápido (Qwen 7B vs GLM 4 9B)

```powershell
# Baixar os dois modelos para comparação
.\scripts\download-model.ps1 -Version QWEN_CODER_7B_OLLAMA
.\scripts\download-model.ps1 -Version GLM_4_9B_OLLAMA

# Rodar Qwen Coder 7B
.\scripts\run-ollama.ps1 -ModelVersion QWEN_CODER_7B_OLLAMA

# Rodar GLM 4 9B
.\scripts\run-ollama.ps1 -ModelVersion GLM_4_9B_OLLAMA
```

### 3) Download de modelos GGUF (Hugging Face)

```powershell
.\scripts\download-model.ps1 -Version Q4_K_S -OutputDir .\models
.\scripts\download-model.ps1 -Version Q4_K_M -OutputDir .\models
.\scripts\download-model.ps1 -Version Q5_K_M -OutputDir .\models
.\scripts\download-model.ps1 -Version UD-Q2_K_XL -OutputDir .\models
```

### 4) Rodar os modelos com facilidade

```powershell
# Rodar via script (Ollama)
.\scripts\run-ollama.ps1 -ModelVersion QWEN3_CODER_OLLAMA

# Rodar via Ollama direto
ollama run qwen3-coder

# Rodar GGUF com llama.cpp
.\scripts\run-llamacpp.ps1
```

### 5) Se o comando `ollama` não for reconhecido

```powershell
# Validar versão por caminho absoluto
& "$env:LOCALAPPDATA\Programs\Ollama\ollama.exe" --version

# Listar modelos instalados
& "$env:LOCALAPPDATA\Programs\Ollama\ollama.exe" list

# Rodar modelo direto
& "$env:LOCALAPPDATA\Programs\Ollama\ollama.exe" run qwen3-coder
```

### 6) Modelos no Git

- Para modelos GGUF, use uma pasta local como `models/` e adicione no `.gitignore`.
- Para modelos Ollama, os arquivos ficam no storage do Ollama (fora da pasta do projeto por padrão).

## 📁 Estrutura do Repositório

```
.
├── README.md                 # Este arquivo
├── scripts/
│   ├── install.sh            # Instalação Linux/Mac
│   ├── install.ps1           # Instalação Windows
│   ├── download-model.sh     # Download modelo (Linux/Mac)
│   ├── download-model.ps1    # Download modelo (Windows)
│   ├── run-llamacpp.sh       # Executar com llama.cpp (Linux/Mac)
│   ├── run-llamacpp.ps1      # Executar com llama.cpp (Windows)
│   ├── run-ollama.sh         # Executar com Ollama (Linux/Mac)
│   └── run-ollama.ps1        # Executar com Ollama (Windows)
├── config/
│   ├── hardware-config.yaml  # Configuração de hardware
│   └── model-config.json     # Configurações do modelo
└── models/                   # Diretório para modelos baixados
```

## ⚙️ Configuração

### 1. Configurar Hardware

Edite `config/hardware-config.yaml` com as especificações da sua máquina:

```yaml
hardware:
  gpu:
    available: true
    vram_gb: 8
    cuda_arch: "75"  # Para RTX 2060, 2070, 2080
  ram_gb: 32
  cpu_cores: 8
  disk_space_gb: 500
```

### 2. Escolher Versão do Modelo

Baseado no seu hardware, escolha a versão adequada:

- **PC muito fraco (32GB RAM, sem GPU)**: Use `Q4_K_S` ou considere modelos menores
- **PC moderado (64GB RAM, GPU 8-16GB)**: Use `Q4_K_M`
- **PC potente (128GB+ RAM, GPU 24GB+)**: Use `UD-Q2_K_XL` ou `Q5_K_M`

## 🔧 Métodos de Execução

### Opção 1: llama.cpp (Recomendado para hardware limitado)

O `llama.cpp` oferece melhor controle sobre offloading CPU/GPU e quantização.

**Vantagens:**

- Suporte a offloading inteligente
- Menor uso de memória
- Melhor para hardware limitado

### Opção 2: Ollama (Mais simples)

O Ollama é mais fácil de usar, mas pode ser menos eficiente em hardware limitado.

**Vantagens:**

- Instalação mais simples
- Interface mais amigável
- Gerenciamento automático de modelos

## 📝 Exemplos de Uso

### Executar com contexto pequeno (economiza memória)

```bash
./scripts/run-llamacpp.sh --ctx-size 4096 --threads 4
```

### Executar apenas em CPU

```bash
./scripts/run-llamacpp.sh --cpu-only
```

### Executar com offloading parcial para CPU

```bash
./scripts/run-llamacpp.sh --gpu-layers 10
```

## 🐛 Solução de Problemas

### Erro: "Out of memory"

- Reduza o `--ctx-size` (tamanho do contexto)
- Use uma versão mais quantizada do modelo
- Reduza `--gpu-layers` para fazer mais offload para CPU

### Erro: "CUDA not found"

- Verifique se o CUDA está instalado: `nvidia-smi`
- Recompile o llama.cpp com suporte CUDA

### Modelo muito lento

- Aumente `--threads` (número de threads CPU)
- Use mais camadas na GPU se tiver VRAM disponível
- Considere usar uma versão mais leve do modelo

## 📚 Recursos Adicionais

- [Documentação oficial GLM-4.7](https://huggingface.co/zai-org/GLM-4.7)
- [llama.cpp GitHub](https://github.com/ggerganov/llama.cpp)
- [Ollama Documentation](https://ollama.ai/docs)
- [Modelos quantizados no Hugging Face](https://huggingface.co/bartowski/zai-org_GLM-4.7-GGUF)

## 📄 Licença

Este repositório contém scripts de instalação e configuração. O modelo GLM-4.7 possui sua própria licença - consulte o repositório oficial.

## 🤝 Contribuições

Contribuições são bem-vindas! Sinta-se à vontade para abrir issues ou pull requests.

## ⚠️ Avisos

- Modelos grandes podem demorar muito para baixar (100GB+)
- A primeira execução pode ser lenta enquanto o modelo carrega
- Certifique-se de ter espaço em disco suficiente antes de baixar
- Em hardware muito limitado, considere usar modelos menores ou serviços em nuvem
