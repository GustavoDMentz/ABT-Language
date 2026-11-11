# Tutorial 4 — comparação e regressão

**Objetivo:** comparar grupos e ajustar um modelo linear com dados sintéticos. **Pré-requisito:** dependências Julia do `Project.toml`. **Arquivos:** `applications/biostatistics/ensaio.csv`, `regressao.csv`, `ensaio_clinico.abt` e `regressao_clinica.abt`.

```abt
t = ler_csv("applications/biostatistics/ensaio.csv", esquema("grupo", "texto", "biomarcador", "real"), "erro")
controle = coluna(filtrar_tabela(t, "grupo", "==", "controle"), "biomarcador")
tratamento = coluna(filtrar_tabela(t, "grupo", "==", "tratamento"), "biomarcador")
resultado = registro("controle", resumo_estatistico(controle), "tratamento", resumo_estatistico(tratamento), "comparacao", teste_t(tratamento, controle, "welch", "bilateral", 0))
mostrar codificar_json(resultado, "erro")
```

Execute `bin/abt run applications/biostatistics/ensaio_clinico.abt` para o relatório completo; ele inclui média `12.12` no controle e `10.4` no tratamento. Execute `bin/abt run applications/biostatistics/regressao_clinica.abt` para OLS com `idade` e `exposicao`; a amostra tem `n=8` e R² aproximadamente `0.9891214853740421`. Escolha de teste, desenho amostral e interpretação clínica continuam responsabilidade do analista. Veja [bioestatística](../standard-library/statistics.md) e [limites](../reference/semantics.md).
