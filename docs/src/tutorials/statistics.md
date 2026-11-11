# Tutorial 3 — estatística descritiva

**Objetivo:** obter resumo e selecionar observações. **Pré-requisito:** [instalação](../getting-started/install.md). **Arquivo:** `applications/statistics/descritiva.abt`; não usa arquivo de dados externo.

```abt
usar Julia.Base
dados = [12, 15, 18, 21, 24, 30]
resumo = descrever(dados)
altos = filtrar dados onde valor >= 18
resultado = registro("resumo", resumo, "quantidade_maior_igual_18", Julia.Base.length(altos))
mostrar resultado
```

Execute `bin/abt run applications/statistics/descritiva.abt`. O registro apresentado inclui `quantidade = 6`, `soma = 120`, `media = 20.0` e `quantidade_maior_igual_18 = 4`. `descrever` exige ao menos dois números finitos; `resumo_estatistico` acrescenta quartis e variância amostral, e `intervalo_confianca_media` calcula IC t com nível explícito. Veja [referência estatística](../standard-library/statistics.md).
