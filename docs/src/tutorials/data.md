# Tutorial 2 — CSV tipado e JSON

**Objetivo:** ler CSV, declarar esquema, agrupar e produzir relatório JSON. **Pré-requisito:** [instalação](../getting-started/install.md) com CSV.jl e JSON.jl resolvidos. **Arquivos:** `applications/data/vendas.csv` e `applications/data/vendas_por_regiao_json.abt`.

```abt
caminho = ambiente("ABT_VENDAS_PATH", "applications/data/vendas.csv")
colunas = esquema("produto", "texto", "regiao", "texto", "unidades", "inteiro", "preco", "real")
vendas = ler_csv(caminho, colunas, "erro")
resumo = resumir_grupos(vendas, "regiao", "unidades", "erro")
relatorio = registro("fonte", "vendas", "unidade", "itens", "resumo", resumo)
mostrar codificar_json(relatorio, "erro")
```

Execute `bin/abt run applications/data/vendas_por_regiao_json.abt`. A saída é uma linha JSON com `fonte:"vendas"` e um `resumo` por região. O esquema deve repetir a ordem e os nomes do cabeçalho; alterar `unidades` para `real` muda o contrato de conversão e não é inferido. `ler_csv` devolve tabela reutilizável; `resumir_grupos` calcula dados; `mostrar` apenas apresenta. Para filtros e transformações, veja [tabelas](../standard-library/tables.md).
