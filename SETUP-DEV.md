# Configuracao para Desenvolvimento - Qwen3.6-27B

Este guia descreve o setup recomendado para usar Qwen3.6-27B em tarefas de codigo.

## Recomendacao principal

- Modelo: **QWEN3_6_27B_Q4_K_M** (equilibrio entre qualidade e memoria)
- Perfil: **Q4_K_M_4K**

## Passo a passo (Windows)

```powershell
\scripts\detect-hardware.ps1
\scripts\install.ps1
\scripts\download-model.ps1 -Version QWEN3_6_27B_Q4_K_M
\scripts\run-llamacpp.ps1 -Profile Q4_K_M_4K
```

## Perfis disponiveis

| Perfil | Quantizacao | Contexto |
|--------|-------------|----------|
| Q4_K_M_4K | 4-bit | 4096 |
| Q4_K_M_8K | 4-bit | 8192 |
| Q8_0_4K | 8-bit | 4096 |
| Q8_0_8K | 8-bit | 8192 |

Voce pode sobrescrever o contexto com `-CtxSize`.

## Dicas

- Para 8K, teste primeiro Q4_K_M_8K antes de tentar Q8_0_8K.
- Se ocorrer OOM, reduza contexto e GPU layers.
- Para harness de programacao, prefira GGUF pela previsibilidade de quantizacao.
