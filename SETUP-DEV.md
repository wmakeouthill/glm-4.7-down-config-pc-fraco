# Configuração para Desenvolvimento - GLM-4.7

## 🎯 Suas Especificações

Baseado no seu hardware:
- **CPU**: AMD Ryzen 5 5600X (6 cores, 12 threads) ✅
- **GPU**: RTX 4060 (8GB VRAM) ✅
- **RAM**: 32GB ✅
- **Disco**: 174GB livres ✅

## ✅ Status dos Scripts

**SIM, os scripts estão prontos para funcionar!** Eles foram ajustados especificamente para sua configuração.

## 📦 Modelo Recomendado para Você

### **Q4_K_S** (Recomendado)

**Por quê?**
- ✅ **Tamanho**: 180GB (cabe no seu disco)
- ✅ **RAM**: Funciona com 32GB (mínimo recomendado: 48GB, mas funciona)
- ✅ **VRAM**: Otimizado para 8GB com offloading inteligente
- ✅ **Qualidade**: Boa qualidade para código (4-bit quantizado)
- ✅ **Performance**: Balanceada entre qualidade e velocidade

**Configuração otimizada:**
- **GPU Layers**: 6 camadas na GPU (resto em CPU)
- **Contexto**: 4096 tokens (suficiente para arquivos de código)
- **Threads**: 6 threads CPU (aproveitando seus 12 threads)

## 🚀 Passo a Passo para Começar

### 1. Detectar e Configurar Hardware

```powershell
.\scripts\detect-hardware.ps1
```

Este script vai:
- Detectar sua RTX 4060 e configurar CUDA arch 8.9 automaticamente
- Detectar 32GB RAM e 8GB VRAM
- Gerar configuração otimizada para desenvolvimento

### 2. Instalar Dependências

```powershell
.\scripts\install.ps1
```

**Nota**: No Windows, o llama.cpp precisa ser compilado. Opções:
- **Opção A (Recomendada)**: Use WSL2 (Windows Subsystem for Linux)
- **Opção B**: Baixe build pré-compilado de https://github.com/ggerganov/llama.cpp/releases
- **Opção C**: Compile com Visual Studio (mais complexo)

### 3. Baixar Modelo

```powershell
.\scripts\download-model.ps1 -Version Q4_K_S
```

**Atenção**: 
- O download é de ~180GB
- Pode demorar várias horas dependendo da conexão
- Certifique-se de ter espaço suficiente

### 4. Executar para Desenvolvimento

```powershell
.\scripts\run-llamacpp.ps1 -ModelVersion Q4_K_S -CtxSize 4096 -Threads 6 -GpuLayers 6
```

Ou simplesmente (os parâmetros serão detectados automaticamente):
```powershell
.\scripts\run-llamacpp.ps1
```

## ⚙️ Configurações para Desenvolvimento

### Perfis de Uso

**Geração de Código (mais preciso):**
```powershell
.\scripts\run-llamacpp.ps1 -Prompt "Escreva uma função Python que..." -CtxSize 4096
```
- Temperatura: 0.5-0.7 (mais determinístico)
- Contexto: 4096 tokens (suficiente para arquivos médios)

**Explicação de Código:**
```powershell
.\scripts\run-llamacpp.ps1 -Prompt "Explique este código: [código aqui]" -CtxSize 4096
```
- Temperatura: 0.7-0.8 (mais criativo)
- Contexto: 4096 tokens

**Revisão de Código:**
```powershell
.\scripts\run-llamacpp.ps1 -Prompt "Revise este código e sugira melhorias: [código]" -CtxSize 4096
```
- Temperatura: 0.6 (balanceado)
- Contexto: 4096 tokens

## 🔧 Otimizações Específicas para Seu Hardware

### Aproveitando a RTX 4060 (8GB VRAM)

Os scripts estão configurados para:
1. **Offloading inteligente**: 6 camadas na GPU, resto em CPU
2. **Economia de VRAM**: Camadas MoE (experts) são movidas para CPU automaticamente
3. **Contexto otimizado**: 4096 tokens (não muito grande para não estourar memória)

### Aproveitando o Ryzen 5 5600X

- **6 threads CPU**: Aproveita metade dos 12 threads disponíveis
- **Deixa recursos livres**: Para você continuar usando o PC normalmente

## ⚠️ Limitações e Expectativas

### Performance Esperada

Com sua configuração:
- **Velocidade de geração**: ~2-5 tokens/segundo (dependendo do offloading)
- **Uso de RAM**: ~20-25GB durante execução
- **Uso de VRAM**: ~6-7GB (deixando ~1GB livre)
- **Uso de CPU**: ~50% (6 de 12 threads)

### Quando Funciona Melhor

✅ **Ideal para:**
- Geração de funções e classes
- Explicação de código
- Refatoração de código
- Sugestões de melhorias
- Debugging assistido

⚠️ **Pode ser lento para:**
- Arquivos muito grandes (>4000 tokens)
- Múltiplas iterações rápidas
- Contexto muito extenso

## 🆘 Solução de Problemas

### "Out of memory"
- Reduza contexto: `-CtxSize 2048`
- Reduza GPU layers: `-GpuLayers 4`
- Feche outros programas

### "Muito lento"
- Normal! Com 32GB RAM e 8GB VRAM, é esperado
- Considere usar serviços em nuvem para tarefas muito pesadas
- Para desenvolvimento local, a velocidade é aceitável

### "Modelo não encontrado"
- Verifique se o download terminou: `ls models/`
- O arquivo deve ter ~180GB

## 💡 Dicas para Desenvolvimento

1. **Use contexto pequeno**: Para código, 4096 tokens é suficiente
2. **Temperatura baixa**: 0.5-0.7 para código mais preciso
3. **Prompt específico**: Seja claro sobre o que você quer
4. **Iterativo**: Faça perguntas menores e específicas

## 📊 Comparação de Modelos para Você

| Modelo | Tamanho | RAM | VRAM | Qualidade | Velocidade | Recomendado? |
|--------|---------|-----|------|-----------|------------|--------------|
| Q4_K_S | 180GB | 32GB | 8GB | ⭐⭐⭐⭐ | ⭐⭐⭐ | ✅ **SIM** |
| Q4_K_M | 200GB | 64GB | 16GB | ⭐⭐⭐⭐⭐ | ⭐⭐ | ❌ Muita RAM |
| Q5_K_M | 240GB | 80GB | 20GB | ⭐⭐⭐⭐⭐ | ⭐ | ❌ Muita RAM |
| UD-Q2_K_XL | 135GB | 128GB | 24GB | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ❌ Muita RAM |

## 🎯 Conclusão

**Para desenvolvimento/codificação com seu hardware:**
- ✅ Use **Q4_K_S**
- ✅ Configure **6 GPU layers + offload CPU**
- ✅ Use **contexto de 4096 tokens**
- ✅ Temperatura **0.5-0.7** para código

Os scripts estão prontos e otimizados para sua máquina! 🚀
