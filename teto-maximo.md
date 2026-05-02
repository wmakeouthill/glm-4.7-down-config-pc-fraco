# Teto de Contexto - Qwen3.6-27B Q4_K_M no seu PC

**Hardware:** Ryzen 5 5600X (6 cores) / 32 GB RAM / RTX 4060 8 GB VRAM

---

## Como a VRAM e consumida

Ao rodar um modelo local, a VRAM e ocupada por tres coisas ao mesmo tempo:

```
[  overhead Windows/driver ~0.5 GB  ]
[  modelo (layers na GPU)           ]  <- fixo, definido por -GpuLayers
[  KV cache                         ]  <- cresce conforme a conversa avanca
```

Se a soma das tres ultrapassar 8 GB, o programa trava com erro OOM (Out of Memory).

### Por que o KV cache cresce durante a conversa?

O modelo precisa "lembrar" de cada token anterior para gerar o proximo.
Essa memoria e o KV cache (Key-Value cache). A cada token gerado, ele cresce:

```
KV cache = tokens gerados x layers x tamanho por layer
```

Com -CtxSize 32768 e q8_0, o KV cache pode chegar a ~1.1 GB quando o contexto
encher completamente. Por isso nao da pra usar 100% da VRAM so com o modelo.

---

## Por que -Threads 6 e nao 12?

O Ryzen 5 5600X tem 6 nucleos fisicos e 12 threads logicos (Hyperthreading).
Para inferencia de LLM, o gargalo e memoria, nao computacao.

Usar 12 threads faz os nucleos competirem pela mesma banda de memoria RAM,
aumentando latencia e reduzindo tokens/segundo. 6 threads (um por nucleo fisico)
da throughput melhor na pratica.

---

## Por que layer tem esse tamanho (~470 MB)?

O modelo Q4_K_M tem 17 GB no total, distribuidos em ~36 layers de transformer.

```
17 GB / 36 layers = ~472 MB por layer
```

Cada layer contem as matrizes de pesos de atencao e FFN daquela camada.
Layers na GPU rodam em paralelo nos CUDA cores (rapido).
Layers na RAM rodam na CPU (mais lento, mas funciona).

---

## O que e KV cache quantizado?

O KV cache armazena vetores de atencao em ponto flutuante. Por padrao usa fp16
(16 bits por valor). Quantizar reduz isso:

| Modo | Bits | KB por token | Por que funciona                              |
|------|------|-------------|-----------------------------------------------|
| fp16 | 16   | 72 KB       | precisao maxima, referencia                   |
| q8_0 | 8   | 36 KB       | erro < 0.1%, imperceptivel na pratica         |
| q4_0 | 4   | 18 KB       | erro pequeno, visivel so em contextos >50K    |

O modelo em si nao e afetado - ele continua Q4_K_M.
So os vetores temporarios de atencao sao quantizados.

---

## O que e Flash Attention?

O calculo padrao de atencao precisa materializar uma matriz de tamanho
(ctx x ctx) na VRAM durante a geracao. Para 32K de contexto isso e enorme.

Flash Attention reformula o calculo em blocos menores que cabem no cache
do chip, sem nunca materializar a matriz inteira. Resultado: menos VRAM
usada nos picos de computacao, sem nenhuma perda de qualidade.

---

## Comandos prontos

### 32K - KV q8_0 + Flash Attention (recomendado para uso geral)

14 layers = ~6.6 GB de modelo. Sobram ~0.9 GB para KV cache apos overhead.
Com q8_0, o KV cache de 32K cabe em ~1.1 GB -> margem suficiente durante uso normal.

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

Reduzido para 12 layers (~5.6 GB) porque 48K de contexto com q8_0
consome ~1.6 GB de KV ao encher. Precisa de mais margem.

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

Volta para 14 layers porque q4_0 corta o KV cache pela metade em relacao ao q8_0.
64K com q4_0 = ~1.1 GB de KV, mesma margem do preset de 32K q8_0.

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

12 layers pela mesma logica do 48K q8_0: contexto gigante precisa de margem maior.
96K com q4_0 = ~1.6 GB de KV ao encher completamente.

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

## Tabela comparativa

| Preset  | Layers | Modelo GPU | KV cheio | Total+overhead | Margem |
|---------|--------|-----------|---------|----------------|--------|
| 32K q8  | 14     | ~6.6 GB   | ~1.1 GB | ~8.2 GB        | ok*    |
| 48K q8  | 12     | ~5.6 GB   | ~1.6 GB | ~7.7 GB        | ok     |
| 64K q4  | 14     | ~6.6 GB   | ~1.1 GB | ~8.2 GB        | ok*    |
| 96K q4  | 12     | ~5.6 GB   | ~1.6 GB | ~7.7 GB        | ok     |

*O KV cache so chega ao maximo se voce usar o contexto inteiro.
Na pratica conversas normais usam bem menos tokens.

---

## Regra geral para calcular seus proprios presets

```
VRAM disponivel = 8.0 GB - 0.5 GB (overhead) = 7.5 GB
VRAM para modelo = layers x 472 MB
VRAM para KV     = CtxSize x (72 KB se fp16 / 36 KB se q8_0 / 18 KB se q4_0)
                   dividido por 36 (total de layers) x layers na GPU

Soma deve ficar abaixo de 7.5 GB com folga de pelo menos 0.5 GB.
```

---

## Se der OOM

Reduza -GpuLayers em 2 e tente de novo. O modelo continua funcionando,
so mais lento (as layers extras rodam na RAM pelo CPU).
A qualidade das respostas nao muda, so a velocidade de geracao.

---

## Referencia de flags

| Flag       | Valores aceitos         | O que faz                            |
|------------|------------------------|--------------------------------------|
| -KvCache   | q8_0, q4_0, q4_1, q5_0 | Quantiza KV cache para reduzir VRAM |
| -FlashAttn | switch (sem valor)      | Flash Attention - menos picos VRAM  |
| -GpuLayers | numero inteiro          | Layers do modelo carregadas na GPU   |
| -CtxSize   | numero inteiro          | Limite maximo de tokens no contexto  |
| -Threads   | numero inteiro          | Nucleos fisicos usados na CPU        |
