# Modelos 100% GPU - RTX 4060 8 GB

Modelos que cabem inteiros na VRAM. Nenhuma layer na RAM = maxima velocidade.

**Hardware:** Ryzen 5 5600X / 32 GB RAM / RTX 4060 8 GB VRAM

---

## Modelos disponiveis

| Chave                       | Modelo                          | Tamanho | Layers GPU | Velocidade estimada |
|-----------------------------|---------------------------------|---------|------------|---------------------|
| QWEN3_8B_Q5_K_M             | Qwen3-8B Q5_K_M                 | 5.85 GB | 36/36      | 15-25 t/s           |
| DEEPSEEK_R1_DISTILL_7B_Q5_K_M | DeepSeek-R1-Distill-Qwen-7B Q5 | 5.44 GB | 28/28      | 20-30 t/s           |
| GLM_4_9B_Q4_K_M             | GLM-4-9B-chat Q4_K_M            | 6.25 GB | 40/40      | 12-20 t/s           |

Para colocar o modelo 100% na GPU, use `-GpuLayers 9999` (llama.cpp carrega o maximo possivel).

---

## 1. Download dos modelos

### Qwen3-8B Q5_K_M (raciocinio geral, instrucoes, codigo)

```powershell
.\scripts\download-model.ps1 -Version QWEN3_8B_Q5_K_M
```

### DeepSeek-R1-Distill-Qwen-7B Q5_K_M (raciocinio / coding, melhor benchmark)

```powershell
.\scripts\download-model.ps1 -Version DEEPSEEK_R1_DISTILL_7B_Q5_K_M
```

### GLM-4-9B-chat Q4_K_M (chat multilingue, born to serve)

```powershell
.\scripts\download-model.ps1 -Version GLM_4_9B_Q4_K_M
```

---

## 2. Rodar com llama-cli (modo interativo)

### Qwen3-8B - padrao (thinking completo)

```powershell
.\scripts\run-llamacpp.ps1 `
    -ModelVersion QWEN3_8B_Q5_K_M `
    -GpuLayers 9999 `
    -Threads 6 `
    -CtxSize 32768 `
    -KvCache q8_0 `
    -FlashAttn
```

### Qwen3-8B - thinking desativado (mais rapido)

```powershell
.\scripts\run-llamacpp.ps1 `
    -ModelVersion QWEN3_8B_Q5_K_M `
    -GpuLayers 9999 `
    -Threads 6 `
    -CtxSize 32768 `
    -KvCache q8_0 `
    -FlashAttn `
    -Thinking off
```

### Qwen3-8B - contexto maximo 96K

```powershell
.\scripts\run-llamacpp.ps1 `
    -ModelVersion QWEN3_8B_Q5_K_M `
    -GpuLayers 9999 `
    -Threads 6 `
    -CtxSize 98304 `
    -KvCache q4_0 `
    -FlashAttn
```

---

### DeepSeek-R1-Distill-7B - raciocinio completo (padrao)

```powershell
.\scripts\run-llamacpp.ps1 `
    -ModelVersion DEEPSEEK_R1_DISTILL_7B_Q5_K_M `
    -GpuLayers 9999 `
    -Threads 6 `
    -CtxSize 32768 `
    -KvCache q8_0 `
    -FlashAttn
```

### DeepSeek-R1-Distill-7B - contexto maximo 96K

```powershell
.\scripts\run-llamacpp.ps1 `
    -ModelVersion DEEPSEEK_R1_DISTILL_7B_Q5_K_M `
    -GpuLayers 9999 `
    -Threads 6 `
    -CtxSize 98304 `
    -KvCache q4_0 `
    -FlashAttn
```

---

### GLM-4-9B - chat padrao

```powershell
.\scripts\run-llamacpp.ps1 `
    -ModelVersion GLM_4_9B_Q4_K_M `
    -GpuLayers 9999 `
    -Threads 6 `
    -CtxSize 32768 `
    -KvCache q8_0 `
    -FlashAttn
```

### GLM-4-9B - contexto maximo 96K

```powershell
.\scripts\run-llamacpp.ps1 `
    -ModelVersion GLM_4_9B_Q4_K_M `
    -GpuLayers 9999 `
    -Threads 6 `
    -CtxSize 98304 `
    -KvCache q4_0 `
    -FlashAttn
```

---

## 3. Rodar como servidor (API OpenAI-compativel)

Acesse em: `http://localhost:8080` (chat) e `http://localhost:8080/v1` (API)

### Qwen3-8B - servidor 32K (recomendado)

```powershell
.\scripts\run-server.ps1 -ModelVersion QWEN3_8B_Q5_K_M -Preset 32k-q8 -GpuLayers 9999
```

### DeepSeek-R1-Distill-7B - servidor 32K

```powershell
.\scripts\run-server.ps1 -ModelVersion DEEPSEEK_R1_DISTILL_7B_Q5_K_M -Preset 32k-q8 -GpuLayers 9999
```

### GLM-4-9B - servidor 32K

```powershell
.\scripts\run-server.ps1 -ModelVersion GLM_4_9B_Q4_K_M -Preset 32k-q8 -GpuLayers 9999
```

### Qualquer modelo - servidor rapido 8K (maximo t/s)

```powershell
.\scripts\run-server.ps1 -ModelVersion QWEN3_8B_Q5_K_M -Preset fast-8k -GpuLayers 9999
```

### Servidor em background

```powershell
.\scripts\run-server.ps1 -ModelVersion QWEN3_8B_Q5_K_M -Preset 32k-q8 -GpuLayers 9999 -Background
# Para parar: Get-Process llama-server | Stop-Process
```

---

## 4. Tabela de VRAM por preset (modelos GPU-only)

Com o modelo 100% na GPU sobra mais VRAM para contexto do que nos presets do Qwen3.6-27B.

| Modelo         | Tamanho | VRAM modelo | Sobra para KV | Contexto max q8_0 | Contexto max q4_0 |
|----------------|---------|-------------|---------------|-------------------|-------------------|
| Qwen3-8B       | 5.85 GB | ~5850 MiB   | ~1325 MiB     | ~37K              | ~74K              |
| DeepSeek-R1-7B | 5.44 GB | ~5440 MiB   | ~1735 MiB     | ~62K              | ~124K             |
| GLM-4-9B       | 6.25 GB | ~6250 MiB   | ~925 MiB      | ~23K              | ~46K              |

*VRAM disponivel = 8187 - 512 (overhead) = 7675 MiB*
*KV por layer q8_0 = 2 KB/token, q4_0 = 1 KB/token*
*Esses sao os tetos teoricos - use -CtxSize com margem de seguranca*

---

## 5. Qual modelo escolher?

| Caso de uso                        | Recomendado                     |
|------------------------------------|---------------------------------|
| Raciocinio / matematica / codigo   | DeepSeek-R1-Distill-7B Q5_K_M  |
| Chat geral / instrucoes            | Qwen3-8B Q5_K_M                 |
| Chat multilingue (PT/EN/ZH)        | GLM-4-9B Q4_K_M                 |
| Velocidade maxima (todos os usos)  | DeepSeek-R1-Distill-7B Q5_K_M  |

---

## 6. Bônus: MoE 35B na GPU+RAM

O Qwen3.6-35B-A3B e um modelo MoE (Mixture of Experts): 35B parametros totais mas
so 3B ativos por token. Com o flag `-ot` os experts ficam na RAM e a atencao na GPU.

```powershell
# Download
.\scripts\download-model.ps1 -Version QWEN3_6_35B_A3B_Q4_K_M

# Rodar (atencao na GPU, experts na RAM)
.\scripts\run-llamacpp.ps1 `
    -ModelVersion QWEN3_6_35B_A3B_Q4_K_M `
    -GpuLayers 9999 `
    -Threads 6 `
    -CtxSize 8192 `
    -KvCache q8_0 `
    -FlashAttn
```

Velocidade: ~3-6 t/s (experts na RAM sao o gargalo). Qualidade: nivel 35B.
Requer 22 GB livres na RAM alem dos 8 GB de VRAM.
