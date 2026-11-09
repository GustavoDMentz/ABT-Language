# Aplicações ABT 0.11.8

Execute a partir da raiz do projeto com Julia 1.13.3 e `Pkg.instantiate()` no projeto Julia. CSV.jl e Tables.jl são usados pela camada tabular; FASTX.jl e BioSequences.jl pela camada biológica. PythonCall é opcional para outras aplicações ABT e para testes históricos de interoperabilidade. Contratos: [tabelas](../docs/ARQUIVOS_TABELAS_0118.md) e [bioinformática](../docs/BIOINFORMATICA_0118.md).

```sh
export ABT_JULIA=/caminho/julia-1.13.3/bin/julia
"$ABT_JULIA" --project=. -e 'import Pkg; Pkg.instantiate()'
bin/abt run applications/statistics/descritiva.abt
bin/abt run applications/data/resumo_csv.abt
bin/abt run applications/bio/conteudo_gc.abt
bin/abt run applications/bio/por_registro.abt
bin/abt run applications/data/vendas.abt
```

## Estatística

[Fonte](statistics/descritiva.abt). Calcula indicadores descritivos de uma lista numérica e apresenta um registro. Saída da amostra:

```text
(resumo = (quantidade = 6, soma = 120, media = 20.0, mediana = 19.5, desvio_padrao = 6.48074069840786, minimo = 12, maximo = 30), quantidade_maior_igual_18 = 4)
```

## CSV

[Fonte](data/resumo_csv.abt) e [dados](data/sample.csv). O esquema declara `nome` e `grupo` como texto e `valor` como real. O programa filtra grupo A e valor ≥10, depois calcula contagem, soma e média. CSV.jl trata aspas e quebras de linha dentro de campos; ABT rejeita cabeçalho, tipos e campos inconsistentes. Para outro arquivo:

```sh
ABT_CSV_PATH=/caminho/dados.csv bin/abt run applications/data/resumo_csv.abt
```

Saída da amostra:

```text
(registros = 5, selecionados_grupo_A_valor_maior_igual_10 = 2, soma = 32.0, media = 16.0)
```

## DNA

[Resumo agregado](bio/conteudo_gc.abt), [análise por registro](bio/por_registro.abt) e [FASTA](bio/sample.fasta). As duas aplicações usam `ler_fasta`, FASTX.jl e BioSequences.jl sem PythonCall. Para outro arquivo:

```sh
ABT_FASTA_PATH=/caminho/sequencias.fasta bin/abt run applications/bio/conteudo_gc.abt
```

Saída da amostra:

```text
(sequencias = 1, bases = 12, A = 4, C = 2, G = 3, T = 3, N = 0, GC_percentual = 41.666666666666664)
```

`descrever_sequencias` processa o FASTA em fluxo; `registros_fasta` materializa uma lista com identificador, descrição, sequência original e métricas. O contrato completo está em [Bioinformática](../docs/BIOINFORMATICA_0118.md).

`bin/abt run applications/bio/por_registro.abt` apresenta [três amostras](bio/amostras_multiplas.fasta) com GC de 50%, 100% e 0%:

```text
[(identificador = "alfa", descricao = "alfa amostra A", sequencia = "ACGT", comprimento = 4, A = 1, C = 1, G = 1, T = 1, U = 0, N = 0, GC_percentual = 50.0), (identificador = "beta", descricao = "beta amostra B", sequencia = "GGGG", comprimento = 4, A = 0, C = 0, G = 4, T = 0, U = 0, N = 0, GC_percentual = 100.0), (identificador = "gama", descricao = "gama amostra C", sequencia = "AAAA", comprimento = 4, A = 4, C = 0, G = 0, T = 0, U = 0, N = 0, GC_percentual = 0.0)]
```

## Vendas tabulares

[Fonte](data/vendas.abt) e [dados](data/vendas.csv). Declara quatro colunas, filtra região Sul, cria uma coluna numérica derivada e compõe um relatório. Para outro arquivo com o mesmo esquema:

```sh
ABT_VENDAS_PATH=/caminho/vendas.csv bin/abt run applications/data/vendas.abt
```

Saída da amostra:

```text
(regiao = "Sul", resumo = (quantidade = 3, soma = 20, media = 6.666666666666667, minimo = 4, maximo = 10), produtos = ["Caderno", "Lápis", "Borracha"])
```

## Resumos agrupados e JSON

[Vendas por região](data/vendas_por_regiao_json.abt) combina CSV com esquema, `resumir_grupos` e `codificar_json`. [Qualidade de lotes](data/qualidade_lotes_json.abt) usa [dados com uma medida ausente](data/qualidade_lotes.csv) e a política explícita `ignorar_linha`. Ambos produzem uma linha JSON com relatório completo; as operações retornam dados e não imprimem por conta própria. Contratos e comandos: [Extensões Julia](../docs/EXTENSOES_JULIA_0118.md).

```sh
bin/abt run applications/data/vendas_por_regiao_json.abt
bin/abt run applications/data/qualidade_lotes_json.abt
```

O primeiro relatório contém `Sul: quantidade=3, soma=10` e `Norte: quantidade=1, soma=8`. O segundo contém `A: quantidade=3, soma=30.0`, `B: quantidade=1, soma=7.5`, `linhas_lidas=5` e `linhas_ignoradas=1`. `test_extensions.py` compara todos os campos do JSON com esses resultados nos três modos de execução.

## Extensões modulares

[Distribuição de vendas](data/distribuicao_vendas.abt) combina CSV.jl, `contar_categorias` com StatsBase.jl e JSON.jl. Saída da amostra: Sul 3/4 (0,75), Norte 1/4 (0,25), quatro linhas lidas e nenhuma ignorada. [Rede de condutâncias](engineering/rede_condutancias.abt) usa `resolver_sistema_spd` com LinearAlgebra; duas tensões ficam aproximadamente 1,0, com resíduo próximo de zero. Cada programa devolve valores estruturados e só a última instrução os apresenta como JSON. Contratos: [arquitetura de extensões](../docs/ARQUITETURA_EXTENSOES_0118.md).

```sh
bin/abt run applications/data/distribuicao_vendas.abt
bin/abt run applications/engineering/rede_condutancias.abt
```

## Testes

`python3 test_applications.py --julia "$ABT_JULIA"` executa aplicações e casos válidos/inválidos no interpretador e, para os casos marcados, nos dois modos de Julia gerada. `test_tables_large.jl` gera e resume 100 mil registros; seu pico de RSS pode ser medido com `/usr/bin/time -v`. Os resultados estruturados ficam em `applications/test_results.json`, e a regressão histórica em `test_logs/summary.json`. Consulte os resultados antes de declarar aprovação.
