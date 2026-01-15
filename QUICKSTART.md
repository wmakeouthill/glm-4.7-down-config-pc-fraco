# Guia Rápido - GLM-4.7

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
# Baixar modelo (use a versão recomendada pelo detect-hardware)
.\scripts\download-model.ps1 -Version Q4_K_S

# Executar
.\scripts\run-llamacpp.ps1
```

**Linux/Mac:**
```bash
# Baixar modelo (use a versão recomendada pelo detect-hardware)
chmod +x scripts/download-model.sh
./scripts/download-model.sh Q4_K_S

# Executar
chmod +x scripts/run-llamacpp.sh
./scripts/run-llamacpp.sh
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
- Liste modelos: `ls models/`
- Baixe novamente: `.\scripts\download-model.ps1 -Version Q4_K_S`

### "llama.cpp não encontrado"
- **Windows**: Use WSL2 ou baixe build pré-compilado
- **Linux**: Execute `./scripts/install.sh` novamente
- **Mac**: Instale Xcode Command Line Tools: `xcode-select --install`

## 📚 Mais Informações

Para mais detalhes, consulte o [README.md](README.md) completo.
