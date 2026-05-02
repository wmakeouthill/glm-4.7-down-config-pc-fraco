# Teto de Contexto - Qwen3.6-27B Q4_K_M no seu PC

**Hardware:** Ryzen 5 5600X (6 cores) / 32 GB RAM / RTX 4060 8 GB VRAM

---

## Por que o contexto e limitado pela VRAM?

O modelo pesa ~17 GB. Com 12 layers na GPU, ocupa ~5.6 GB de VRAM.

**Conta real de VRAM disponivel:**

```
8.0 GB  VRAM total da RTX 4060
- 0.5 GB  overhead Windows/driver/WDDM (sempre reservado)
= 7.5 GB  disponivel de fato
- X GB    modelo (layers na GPU)
- Y GB    KV cache (cresce com cada token gerado durante a conversa)
```

O KV cache NAO e fixo - ele cresce conforme a conversa avanca.
Com 32K de contexto e q8_0, chega a ~1.1 GB ao encher o contexto todo.
Por isso nunca preencher 100% da VRAM so com o modelo.

---

## As tecnicas para maximizar contexto

### 1. KV Cache Quantizado (-KvCache)

Quantiza so o cache de atencao (K e V), nao o modelo em si. O modelo continua Q4_K_M.

| Modo   | KB por token | Reducao | Qualidade                     |
|--------|-------------|---------|-------------------------------|
| fp16   | 72 KB       | 1x      | referencia                    |
| q8_0   | 36 KB       | 2x      | imperceptivel                 |
| q4_0   | 18 KB       | 4x      | leve em conversas >50K tokens |

### 2. Flash Attention (-FlashAttn on)

Reformula o calculo de atencao para usar memoria de forma mais eficiente durante a geracao.
Sem custo de qualidade. Sempre usar junto com KV quantizado.

---

## Comandos prontos (layers corrigidos com overhead do Windows)

### 32K - KV q8_0 + Flash Attention (recomendado para uso geral)

Melhor custo-beneficio. Sem perda de qualidade perceptivel.
Contexto para arquivos grandes, documentos longos, conversas estendidas.

```powershell
.\scripts\run-llamacpp.ps1 `
    -ModelVersion QWEN3_6_27B_Q4_K_M `
    -GpuLayers 14 `
    -Threads 6 `
    -CtxSize 32768 `
    -KvCache q8_0 `
    -FlashAttn
```

### 48K - KV q8_0 + Flash Attention

Para projetos maiores. Ainda sem degradacao de qualidade com q8_0.

```powershell
.\scripts\run-llamacpp.ps1 `
    -ModelVersion QWEN3_6_27B_Q4_K_M `
    -GpuLayers 12 `
    -Threads 6 `
    -CtxSize 49152 `
    -KvCache q8_0 `
    -FlashAttn
```

### 64K - KV q4_0 + Flash Attention

Contexto de 64K tokens (~48K palavras). Leve degradacao em conversas muito longas,
imperceptivel ate ~50K tokens. q4_0 compensa bem a reducao de layers.

```powershell
.\scripts\run-llamacpp.ps1 `
    -ModelVersion QWEN3_6_27B_Q4_K_M `
    -GpuLayers 14 `
    -Threads 6 `
    -CtxSize 65536 `
    -KvCache q4_0 `
    -FlashAttn
```

### 96K - KV q4_0 + Flash Attention (teto absoluto)

Maximo que a VRAM suporta com seguranca. Para codebases inteiras, livros, transcricoes longas.
Se degradar qualidade no final da conversa, prefira o de 64K.

```powershell
.\scripts\run-llamacpp.ps1 `
    -ModelVersion QWEN3_6_27B_Q4_K_M `
    -GpuLayers 12 `
    -Threads 6 `
    -CtxSize 98304 `
    -KvCache q4_0 `
    -FlashAttn
```

---

## Tabela comparativa (corrigida)

| Preset     | CtxSize | KV Cache | GPU Layers | VRAM modelo | +KV cheio | Total estimado | Uso ideal                       |
|------------|---------|----------|-----------|-------------|-----------|----------------|---------------------------------|
| 32K q8     | 32 768  | q8_0     | 14        | ~5.9 GB     | ~1.1 GB   | ~7.0 GB        | uso geral, recomendado          |
| 48K q8     | 49 152  | q8_0     | 12        | ~5.1 GB     | ~1.6 GB   | ~6.7 GB        | documentos e projetos grandes   |
| 64K q4     | 65 536  | q4_0     | 14        | ~5.9 GB     | ~1.1 GB   | ~7.0 GB        | codebases, livros, transcricoes |
| 96K q4     | 98 304  | q4_0     | 12        | ~5.1 GB     | ~1.6 GB   | ~6.7 GB        | teto absoluto, arquivos imensos |

Todos os presets deixam ~0.5-1.0 GB de margem apos o overhead do Windows (~0.5 GB).

---

## Se der OOM

Reduza -GpuLayers em 2 e tente de novo. O modelo continua funcionando,
so mais lento (mais layers rodando na RAM). A qualidade de resposta nao muda.

---

## Referencia de flags

| Flag         | Valores aceitos                  | O que faz                              |
|--------------|----------------------------------|----------------------------------------|
| -KvCache     | q8_0, q4_0, q4_1, q5_0          | Quantiza KV cache para reduzir VRAM    |
| -FlashAttn   | switch (sem valor)               | Flash Attention - menos memoria        |
| -GpuLayers   | numero inteiro                   | Quantas layers do modelo vao pra GPU   |
| -CtxSize     | numero inteiro                   | Tamanho maximo do contexto em tokens   |
