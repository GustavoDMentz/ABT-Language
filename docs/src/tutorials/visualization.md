# Tutorial 6 — visualização científica

**Objetivo:** construir um gráfico e exportá-lo. **Pré-requisito:** Cairo.jl disponível. **Arquivos:** `applications/science/experimento.csv` e `applications/science/visualizacao.abt`.

```abt
dados = ler_csv("applications/science/experimento.csv", esquema("tratamento", "texto", "resposta", "real", "tempo", "inteiro"), "erro")
serie = filtrar_tabela(dados, "tratamento", "==", "controle")
figura = grafico(serie, "tempo", "resposta", "linha")
mostrar salvar_figura(figura, ambiente("ABT_FIGURA_PATH", "/tmp/abt-resposta.png"))
```

Execute `ABT_FIGURA_PATH=/tmp/abt-resposta.png bin/abt run applications/science/visualizacao.abt`. A saída é um registro `arquivo = "/tmp/abt-resposta.png"` e `pontos = 4`; o PNG é gravado no caminho escolhido. `grafico` retorna uma especificação reutilizável; somente `salvar_figura` escreve arquivo. Tabelas vazias e eixos não numéricos são erro. Veja [visualização](../standard-library/science.md).
