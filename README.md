# Qwen3.6-27B - Instalacao e Configuracao para PC Fraco

Este repositorio contem scripts para baixar, instalar e testar **Qwen3.6-27B** em formato GGUF (llama.cpp), com foco em desenvolvimento e uso local em hardware limitado.

## Requisitos minimos

### CPU only

- RAM: 32GB+ (recomendado 48GB+)
- Disco: 60GB+ livres (SSD recomendado)
- CPU: processador multi-core moderno

### Com GPU

- GPU: 8GB+ VRAM (recomendado 12GB+)
- RAM: 32GB+ (recomendado 64GB+ para Q8)
- Disco: 60GB+ livres

## Modelos disponiveis (GGUF)

Repositorio recomendado: <https://huggingface.co/unsloth/Qwen3.6-27B-GGUF>

| Chave | Arquivo | Tamanho | RAM minima | VRAM minima | Uso recomendado |
|------|---------|---------|------------|-------------|----------------|
| QWEN3_6_27B_Q4_K_M | Qwen3.6-27B-Q4_K_M.gguf | ~17GB | 32GB | 8GB | Equilibrio para codigos |
| QWEN3_6_27B_Q8_0 | Qwen3.6-27B-Q8_0.gguf | ~29GB | 48GB | 12GB | Maior fidelidade |

## Inicio rapido

### Windows (PowerShell)

```powershell
# 1) Instalar dependencias
\scripts\install.ps1

# 2) Listar modelos
\scripts\download-model.ps1 -List

# 3) Baixar Q4 (recomendado)
\scripts\download-model.ps1 -Version QWEN3_6_27B_Q4_K_M

# 4) Rodar com perfil Q4 4K
\scripts\run-llamacpp.ps1 -Profile Q4_K_M_4K
```

### Linux/Mac (Bash)

```bash
chmod +x scripts/install.sh
./scripts/install.sh

chmod +x scripts/download-model.sh
./scripts/download-model.sh QWEN3_6_27B_Q4_K_M

chmod +x scripts/run-llamacpp.sh
./scripts/run-llamacpp.sh --profile Q4_K_M_4K
```

## Perfis (2 por quantizacao)

Os perfis ficam em config/dev-config.json.

- Q4_K_M_4K
- Q4_K_M_8K
- Q8_0_4K
- Q8_0_8K

Voce pode sobrescrever o contexto manualmente:

```powershell
\scripts\run-llamacpp.ps1 -Profile Q4_K_M_4K -CtxSize 8192
```

```bash
./scripts/run-llamacpp.sh --profile Q4_K_M_4K --ctx-size 8192
```

## Dicas rapidas

- 8K com Q8_0 e pesado; se travar, reduza o contexto para 4096.
- Para economizar VRAM, reduza --gpu-layers.
- Para testes de harness, prefira GGUF com configuracao explicita.

## Estrutura do repositorio

```
.
├── README.md
├── scripts/
│   ├── install.sh
│   ├── install.ps1
│   ├── download-model.sh
│   ├── download-model.ps1
│   ├── run-llamacpp.sh
│   ├── run-llamacpp.ps1
│   ├── run-ollama.sh
│   └── run-ollama.ps1
├── config/
│   ├── hardware-config.yaml
│   ├── model-config.json
│   └── dev-config.json
└── models/
```

## Recursos

- <https://huggingface.co/unsloth/Qwen3.6-27B-GGUF>
- <https://github.com/ggerganov/llama.cpp>

## Avisos

- A primeira execucao pode ser lenta enquanto o modelo carrega.
- Se ocorrer "Out of memory", reduza o contexto ou use Q4_K_M.
