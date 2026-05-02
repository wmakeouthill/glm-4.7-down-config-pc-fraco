# Teto de Contexto - Qwen3.6-27B Q4_K_M no seu PC

**Hardware:** Ryzen 5 5600X (6 cores) / 32 GB RAM / RTX 4060 8 GB VRAM

---

## Como a RTX 4060 entra no processo

A placa de video nao tem "layers" proprias. O que ela tem e VRAM (8 GB de memoria
de video) e CUDA cores (unidades de calculo paralelo).

O parametro -GpuLayers diz ao llama.cpp: "carregue X layers do modelo dentro
da VRAM e use os CUDA cores para processar essas layers". As layers que nao
couberem ficam na RAM e sao processadas pela CPU - mais lento, mas funciona.

Para a GPU ser usada, o llama.cpp precisa de dois componentes:

- ggml-cuda.dll      : o backend que fala com os CUDA cores
- cudart64_12.dll    : o runtime CUDA (DLLs da NVIDIA que ggml-cuda.dll depende)

Se o cudart64_12.dll estiver ausente, o ggml-cuda.dll nao carrega e o programa
cai silenciosamente para CPU sem dar erro claro. Foi exatamente o que aconteceu
aqui: o setup baixou os executaveis mas nao o pacote cudart separado.

O log correto com GPU ativa mostra:

```
load_backend: loaded CUDA backend from ggml-cuda.dll   <- deve aparecer isso
load_backend: loaded CPU backend from ggml-cpu-haswell.dll
```

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

13 layers e o maximo calculado: L = 7675 / (472 + 96) = 13.5 -> 13.
12 layers deixava um layer preso na CPU sem necessidade.

```powershell
.\scripts\run-llamacpp.ps1 `
    -ModelVersion QWEN3_6_27B_Q4_K_M `
    -GpuLayers 13 `
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

```powershell
.\scripts\run-llamacpp.ps1 `
    -ModelVersion QWEN3_6_27B_Q4_K_M `
    -GpuLayers 14 `
    -Threads 6 `
    -CtxSize 65536 `
    -KvCache q4_0 `
    -FlashAttn `
    -Thinking low
```

```powershell
.\scripts\run-llamacpp.ps1 `
    -ModelVersion QWEN3_6_27B_Q4_K_M `
    -GpuLayers 14 `
    -Threads 6 `
    -CtxSize 65536 `
    -KvCache q4_0 `
    -FlashAttn `
    -Thinking medium
```

### 96K - KV q4_0 + Flash Attention (teto absoluto)

Mesmo denominador do 48K q8_0 (ambos consomem 96 MiB de KV por layer):
L = 7675 / (472 + 96) = 13.5 -> 13 layers. Corrigido de 12 para 13.

```powershell
.\scripts\run-llamacpp.ps1 `
    -ModelVersion QWEN3_6_27B_Q4_K_M `
    -GpuLayers 13 `
    -Threads 6 `
    -CtxSize 98304 `
    -KvCache q4_0 `
    -FlashAttn
```

---

## Comandos - DeepSeek-R1-Distill-Qwen-7B Q5_K_M (5.44 GB)

Modelo 100% na GPU. 28 layers, ~194 MiB por layer.
VRAM disponivel para KV = 7675 - 5440 = 2235 MiB.

Formula: teto_tokens = VRAM_KV / (layers x bytes_KV/token)
  q8_0: 2235 MiB / (28 x 2 KB) = ~40960 tokens -> 40K
  q4_0: 2235 MiB / (28 x 1 KB) = ~81920 tokens -> 80K

### 32K - KV q8_0 + Flash Attention (recomendado)

```powershell
.\scripts\run-llamacpp.ps1 `
    -ModelVersion DEEPSEEK_R1_DISTILL_7B_Q5_K_M `
    -GpuLayers 9999 `
    -Threads 6 `
    -CtxSize 32768 `
    -KvCache q8_0 `
    -FlashAttn
```

### 40K - KV q8_0 + Flash Attention (teto q8_0)

```powershell
.\scripts\run-llamacpp.ps1 `
    -ModelVersion DEEPSEEK_R1_DISTILL_7B_Q5_K_M `
    -GpuLayers 9999 `
    -Threads 6 `
    -CtxSize 40960 `
    -KvCache q8_0 `
    -FlashAttn
```

### 64K - KV q4_0 + Flash Attention

```powershell
.\scripts\run-llamacpp.ps1 `
    -ModelVersion DEEPSEEK_R1_DISTILL_7B_Q5_K_M `
    -GpuLayers 9999 `
    -Threads 6 `
    -CtxSize 65536 `
    -KvCache q4_0 `
    -FlashAttn
```

### 80K - KV q4_0 + Flash Attention (teto absoluto)

```powershell
.\scripts\run-llamacpp.ps1 `
    -ModelVersion DEEPSEEK_R1_DISTILL_7B_Q5_K_M `
    -GpuLayers 9999 `
    -Threads 6 `
    -CtxSize 81920 `
    -KvCache q4_0 `
    -FlashAttn
```

---

## Comandos - GLM-4-9B-chat Q4_K_M (6.25 GB)

Modelo 100% na GPU. 40 layers, ~156 MiB por layer.
VRAM disponivel para KV = 7675 - 6250 = 1425 MiB.

Formula:
  q8_0: 1425 MiB / (40 x 2 KB) = ~18350 tokens -> 18K
  q4_0: 1425 MiB / (40 x 1 KB) = ~36700 tokens -> 36K

### 16K - KV q8_0 + Flash Attention (recomendado)

```powershell
.\scripts\run-llamacpp.ps1 `
    -ModelVersion GLM_4_9B_Q4_K_M `
    -GpuLayers 9999 `
    -Threads 6 `
    -CtxSize 16384 `
    -KvCache q8_0 `
    -FlashAttn
```

### 18K - KV q8_0 + Flash Attention (teto q8_0)

```powershell
.\scripts\run-llamacpp.ps1 `
    -ModelVersion GLM_4_9B_Q4_K_M `
    -GpuLayers 9999 `
    -Threads 6 `
    -CtxSize 18432 `
    -KvCache q8_0 `
    -FlashAttn
```

### 32K - KV q4_0 + Flash Attention

```powershell
.\scripts\run-llamacpp.ps1 `
    -ModelVersion GLM_4_9B_Q4_K_M `
    -GpuLayers 9999 `
    -Threads 6 `
    -CtxSize 32768 `
    -KvCache q4_0 `
    -FlashAttn
```

### 36K - KV q4_0 + Flash Attention (teto absoluto)

```powershell
.\scripts\run-llamacpp.ps1 `
    -ModelVersion GLM_4_9B_Q4_K_M `
    -GpuLayers 9999 `
    -Threads 6 `
    -CtxSize 36864 `
    -KvCache q4_0 `
    -FlashAttn
```

---

## Tabela comparativa

| Preset  | Layers | Modelo GPU | KV cheio | Total+overhead | Margem   |
|---------|--------|-----------|---------|----------------|----------|
| 32K q8  | 14     | 6608 MiB  | 896 MiB | 8016 MiB       | 171 MiB  |
| 48K q8  | 13     | 6136 MiB  | 1248 MiB| 7896 MiB       | 291 MiB  |
| 64K q4  | 14     | 6608 MiB  | 896 MiB | 8016 MiB       | 171 MiB  |
| 96K q4  | 13     | 6136 MiB  | 1248 MiB| 7896 MiB       | 291 MiB  |
| fast-8k | 15     | 7080 MiB  | 240 MiB | 7832 MiB       | 355 MiB  |
| fast-16k| 14     | 6608 MiB  | 448 MiB | 7568 MiB       | 619 MiB  |

*A margem conta o KV cache ao encher o contexto inteiro.
Na pratica conversas normais usam bem menos tokens.

Formula usada:
  L_max = VRAM_disponivel / (472 MiB/layer + ctx x bytes_KV/layer)
  VRAM disponivel = 8187 - 512 (overhead) = 7675 MiB

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

## O que fizemos para evitar OOM

OOM (Out of Memory) acontece quando a soma de tudo que esta na VRAM ultrapassa
os 8 GB fisicos da placa. Tomamos quatro decisoes especificas para evitar isso:

**1. Desconto do overhead do Windows**
Nao calculamos com os 8 GB cheios. Descontamos ~0.5 GB que o Windows/driver
sempre reserva para o desktop e WDDM. Trabalhar com 7.5 GB como teto real.

**2. Layers conservadoras (nao encher a VRAM so com o modelo)**
A primeira versao dos comandos usava 16 layers (~7.5 GB) sem margem para o
KV cache crescer. Corrigimos para 12-14 layers (~5.6-6.6 GB), deixando
0.9-1.3 GB livres para o KV cache durante a conversa.

**3. KV cache quantizado (-KvCache q8_0 / q4_0)**
O KV cache em fp16 (padrao) para 96K de contexto ocuparia ~6.9 GB sozinho -
mais do que a margem disponivel. Com q4_0 isso cai para ~1.6 GB.
Sem essa tecnica, contextos acima de 16K seriam inviavies nessa placa.

**4. Flash Attention (-FlashAttn)**
Durante o calculo de atencao, o metodo padrao materializa uma matriz gigante
na VRAM (cresce com o quadrado do contexto). Flash Attention faz o mesmo
calculo em blocos pequenos, evitando picos de uso que causariam OOM momentaneo
mesmo com espaco medio suficiente.

A combinacao das quatro medidas permite contextos de 96K em uma GPU de 8 GB
que, no calculo ingenue, so comportaria ~20K tokens.

---

## Se der OOM mesmo assim

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
