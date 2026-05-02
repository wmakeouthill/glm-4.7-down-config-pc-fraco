# Guia Rapido - Qwen3.6-27B (GGUF)

Este guia ajuda a iniciar em poucos minutos usando Qwen3.6-27B com llama.cpp.

## Inicio rapido (3 passos)

### Passo 1: Detectar hardware

**Windows:**

```powershell
\scripts\detect-hardware.ps1
```

**Linux/Mac:**

```bash
chmod +x scripts/detect-hardware.sh
./scripts/detect-hardware.sh
```

### Passo 2: Instalar dependencias

**Windows:**

```powershell
\scripts\install.ps1
```

**Linux/Mac:**

```bash
chmod +x scripts/install.sh
./scripts/install.sh
```

### Passo 3: Baixar e executar

**Windows:**

```powershell
\scripts\download-model.ps1 -List
\scripts\download-model.ps1 -Version QWEN3_6_27B_Q4_K_M

\scripts\run-llamacpp.ps1 -Profile Q4_K_M_4K
```

**Linux/Mac:**

```bash
chmod +x scripts/download-model.sh
./scripts/download-model.sh QWEN3_6_27B_Q4_K_M

chmod +x scripts/run-llamacpp.sh
./scripts/run-llamacpp.sh --profile Q4_K_M_4K
```

## Perfis disponiveis

- Q4_K_M_4K
- Q4_K_M_8K
- Q8_0_4K
- Q8_0_8K

## Dicas para hardware limitado

1. Use contexto menor: `--ctx-size 4096`
2. CPU-only: `--cpu-only`
3. Menos GPU layers: `--gpu-layers 2`
4. Para testes rapidos, prefira Q4_K_M

## Problemas comuns

### "Out of memory"

- Reduza o contexto para 4096
- Use Q4_K_M
- Reduza GPU layers

### "Modelo nao encontrado"

- Verifique se o download terminou
- Baixe novamente: `\scripts\download-model.ps1 -Version QWEN3_6_27B_Q4_K_M`

### "llama.cpp nao encontrado"

- Windows: use WSL2 ou baixe build pre-compilado
- Linux: execute `./scripts/install.sh` novamente
- Mac: instale Xcode Command Line Tools: `xcode-select --install`

Para mais detalhes, consulte o [README.md](README.md).
