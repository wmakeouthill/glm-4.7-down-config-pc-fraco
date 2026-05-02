# Teto de Contexto — Qwen3.6-27B Q4_K_M no seu PC

**Hardware:** Ryzen 5 5600X (6 cores) / 32 GB RAM / RTX 4060 8 GB VRAM

---

## Por que o contexto é limitado pela VRAM?

O modelo pesa ~17 GB. Com 14 layers na GPU, ocupa **~6.6 GB de VRAM**.
Os **1.4 GB restantes** vão para o **KV cache** — que cresce com cada token gerado.

Em fp16 (padrão), cada token consome ~72 KB de VRAM no KV cache.
Com 1.4 GB disponíveis → limite natural de ~20K tokens sem nenhum truque.

---

## As técnicas

### 1. KV Cache Quantizado (`-KvCache`)

Quantiza só o cache de atenção (K e V), **não o modelo em si**. O modelo continua Q4_K_M.

| Modo     | KB por token | Redução | Qualidade                         |
|----------|-------------|---------|-----------------------------------|
| fp16     | 72 KB       | —       | referência                        |
| `q8_0`   | 36 KB       | 2x      | imperceptível                     |
| `q4_0`   | 18 KB       | 4x      | leve em conversas >50K tokens     |

### 2. Flash Attention (`-FlashAttn`)

Reformula o cálculo de atenção para usar memória de forma mais eficiente durante a geração.
Sem custo de qualidade. Sempre usar junto com KV quantizado.

### 3. Defragmentação do KV cache (`--defrag-thold`)

Em conversas longas, o KV cache fragmenta e desperdiça VRAM. Ativar desfragmentação automática com threshold de 10% resolve isso.
Já embutido nos comandos abaixo via `$env:LLAMA_ARG_DEFRAG_THOLD`.

---

## Comandos prontos

### 32K — KV q8_0 + Flash Attention (recomendado para uso geral)

Melhor custo-benefício. Sem perda de qualidade perceptível. Contexto suficiente para arquivos grandes, documentos longos, conversas estendidas.

```powershell
.\scripts\run-llamacpp.ps1 `
    -ModelVersion QWEN3_6_27B_Q4_K_M `
    -GpuLayers 16 `
    -Threads 6 `
    -CtxSize 32768 `
    -KvCache q8_0 `
    -FlashAttn
```

### 48K — KV q8_0 + Flash Attention

Para projetos maiores. Ainda sem degradação de qualidade com q8_0.

```powershell
.\scripts\run-llamacpp.ps1 `
    -ModelVersion QWEN3_6_27B_Q4_K_M `
    -GpuLayers 14 `
    -Threads 6 `
    -CtxSize 49152 `
    -KvCache q8_0 `
    -FlashAttn
```

### 64K — KV q4_0 + Flash Attention

Contexto de 64K tokens (~48K palavras). Leve degradação em conversas muito longas, imperceptível até ~50K tokens.

```powershell
.\scripts\run-llamacpp.ps1 `
    -ModelVersion QWEN3_6_27B_Q4_K_M `
    -GpuLayers 16 `
    -Threads 6 `
    -CtxSize 65536 `
    -KvCache q4_0 `
    -FlashAttn
```

### 96K — KV q4_0 + Flash Attention (teto absoluto)

Máximo que a VRAM suporta. Usar quando precisar processar arquivos inteiros de código, livros, transcrições longas. Se degradar qualidade no final, prefira o de 64K.

```powershell
.\scripts\run-llamacpp.ps1 `
    -ModelVersion QWEN3_6_27B_Q4_K_M `
    -GpuLayers 14 `
    -Threads 6 `
    -CtxSize 98304 `
    -KvCache q4_0 `
    -FlashAttn
```

---

## Tabela comparativa

| Preset      | CtxSize | KV Cache | GPU Layers | VRAM estimada | Qualidade            | Uso ideal                          |
|-------------|---------|----------|-----------|---------------|----------------------|------------------------------------|
| **32K q8**  | 32 768  | q8_0     | 16        | ~7.3 GB       | sem perda            | uso geral, recomendado             |
| **48K q8**  | 49 152  | q8_0     | 14        | ~7.4 GB       | sem perda            | documentos e projetos grandes      |
| **64K q4**  | 65 536  | q4_0     | 16        | ~7.0 GB       | leve em >50K tokens  | codebases, livros, transcrições    |
| **96K q4**  | 98 304  | q4_0     | 14        | ~7.2 GB       | leve em >50K tokens  | teto absoluto, arquivos imensos    |

---

## Se der OOM

Reduza `-GpuLayers` em 2 e tente de novo. O modelo continua funcionando — só mais lento, com mais layers rodando na RAM.

## Referência de flags adicionadas ao script

| Flag           | Valores aceitos                | O que faz                                 |
|----------------|-------------------------------|-------------------------------------------|
| `-KvCache`     | `q8_0`, `q4_0`, `q4_1`, `q5_0` | Quantiza KV cache para reduzir VRAM      |
| `-FlashAttn`   | switch (sem valor)             | Flash Attention — menos memória na atenção |
