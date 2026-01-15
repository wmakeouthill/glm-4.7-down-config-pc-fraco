# GLM-4.7 - Instalação e Configuração para PC Fraco

Este repositório contém scripts automatizados para instalar e configurar o modelo GLM-4.7 em máquinas com recursos limitados.

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

## 🚀 Início Rápido

### Windows (PowerShell)

```powershell
# 1. Instalar dependências
.\scripts\install.ps1

# 2. Baixar modelo (escolha a versão adequada)
.\scripts\download-model.ps1 -Version "Q4_K_S"

# 3. Executar o modelo
.\scripts\run-llamacpp.ps1
```

### Linux/Mac (Bash)

```bash
# 1. Instalar dependências
chmod +x scripts/install.sh
./scripts/install.sh

# 2. Baixar modelo (escolha a versão adequada)
chmod +x scripts/download-model.sh
./scripts/download-model.sh Q4_K_S

# 3. Executar o modelo
chmod +x scripts/run-llamacpp.sh
./scripts/run-llamacpp.sh
```

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
