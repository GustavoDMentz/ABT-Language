# Extensões Julia do ABT 0.11.8

Este documento registra a etapa inicial de agrupamento e JSON. O estado atual está em [Arquitetura modular](ARQUITETURA_EXTENSOES_0118.md).

## Arquitetura e decisão

`src/Stdlib.jl` implementa tabelas tipadas sobre CSV.jl e Tables.jl; `src/StdlibBio.jl` implementa FASTA e sequências. Antes desta extensão, cada operação aparecia em quatro listas de `src/ABT.jl`: nomes reconhecidos, ambiente do interpretador, aridade semântica e bindings do código gerado. A geração já insere o código de biblioteca somente quando o programa o utiliza. Essa duplicação tornava fácil registrar uma operação em apenas um backend.

`ABT_EXTENSION_SPECS` reúne, para as **duas operações novas**, nome, aridade, função, fonte gerada e descrições de entrada, saída, erros e carregamento. O interpretador e o gerador usam a mesma implementação Julia. A biblioteca histórica continua como estava; não há mecanismo geral de plugins ou carregamento de código de terceiros. As duas fontes são embutidas no Julia gerado somente quando usadas. JSON.jl é carregado por `Base.require` no primeiro `codificar_json` da execução.

## Operações implementadas

### `resumir_grupos(tabela, coluna_grupo, coluna_valor, politica_ausentes)`

- `tabela`: tabela tipada de `ler_csv`. `coluna_grupo`: texto que nomeia coluna declarada como `texto`. `coluna_valor`: texto que nomeia coluna distinta, declarada como `inteiro` ou `real`. O esquema continua obrigatório no `ler_csv`.
- `politica_ausentes`: exatamente `"erro"` ou `"ignorar_linha"`. A primeira rejeita o primeiro registro com qualquer uma das duas colunas ausente; a segunda descarta **a linha inteira** e conta o descarte. Não há imputação nem coerção.
- Retorno: registro `(grupos, linhas_lidas, linhas_ignoradas)`. `grupos` é lista de registros `(grupo, quantidade, soma, media, minimo, maximo)`. Uma passagem pelos registros, inclusive quando a tabela é uma transformação preguiçosa; a lista de grupos é materializada. Grupos aparecem na ordem da primeira ocorrência. Dentro de cada grupo, soma e extremos seguem a ordem de entrada.
- Tabela vazia: `grupos = []`, contadores zero. Inteiros usam soma com verificação de overflow em `Int64`; média é `Float64`. Valores `real` devem ser `Float64` finitos. Soma real não finita é erro, sem arredondamento adicional. A precisão da soma real é a da aritmética sequencial `Float64` de Julia.
- Erros de esquema, coluna, tipo, ausência, overflow e leitura são reportados como erro da operação ABT; a camada tabular preserva o caminho do arquivo e a causa de leitura. A operação não altera a tabela de origem e não imprime.

### `codificar_json(valor, politica_ausentes)`

- `politica_ausentes`: exatamente `"erro"` ou `"nulo"`. `missing` vira erro ou JSON `null` explicitamente. Não há conversão de texto para número nem inferência de esquema.
- Aceita texto, booleano, `Int64`, `Float64` finito, listas, registros ABT e tabelas tipadas. Tabela é codificada como objeto `{"colunas":[...],"registros":[...]}`. Registros respeitam a ordem declarada dos campos; listas preservam a ordem. O retorno é **texto JSON**, reutilizável como valor ABT; `mostrar` apenas o apresenta.
- Tabelas são materializadas durante a codificação: uso de memória cresce com o número de registros. Valor ausente sem política de nulo, número não finito, tipo não suportado e lista cíclica são erros com caminho do valor. Falhas de JSON.jl são traduzidas para diagnóstico ABT com a causa.
- JSON.jl v1.13.4 é a única dependência direta adicionada. A codificação não faz chamada de rede nem usa PythonCall.

## Pacotes avaliados

Versões e compatibilidade abaixo foram lidas do registro General local (snapshot de 5/11/2026); compatibilidade declarada **não equivale a instalação ou teste de execução**. A versão instalada/testada aparece separadamente.

| Família | Pacote | Registro local / Julia | Estado e decisão |
|---|---|---|---|
| Dados | DataFrames.jl | 1.8.2 / 1.10–1 | Não instalado; tabelas atuais bastam para o resumo agrupado. Avaliar quando operações de junção forem especificadas. |
| Dados | CategoricalArrays.jl | 1.1.1 / 1.6–1 | Não instalado; rótulos textuais têm ordem explícita por primeira ocorrência. |
| Estatística | StatsBase.jl | 0.34.13 / 1.10–1 | Não instalado nesta etapa inicial; instalado e usado posteriormente em `contar_categorias`. |
| Estatística | HypothesisTests.jl | 0.12.2 / 1.10–1 | Não instalado; exige contratos explícitos de testes, hipóteses e dados faltantes. |
| JSON/HTTP | JSON3.jl | 1.14.4 / 1.6–1 | Não instalado; [o projeto oficial indica migração para JSON.jl v1](https://github.com/quinnj/JSON3.jl). |
| JSON/HTTP | JSON.jl | 1.13.4 | **Instalado e usado** para serialização explícita. |
| JSON/HTTP | HTTP.jl | 2.15.0 / 1.10–1 | Não instalado; contrato de rede, erros e confiança ainda não foi especificado. |
| Matemática | LinearAlgebra | biblioteca padrão Julia | Já disponível; sem operação nova. |
| Bio | BioAlignments.jl | 3.1.0 / 1 | Não instalado; modelos de alinhamento precisam de contrato científico. |
| Bio | GenomicFeatures.jl | 3.1.0 / 1 | Não instalado; intervalos e coordenadas precisam de convenções explícitas. |
| Visualização | CairoMakie.jl | 0.15.17 / 1.10–1 | Não instalado; saída gráfica e custo de inicialização não justificam inclusão agora. |

## Aplicações

`applications/data/vendas_por_regiao_json.abt` combina CSV tipado, resumo agrupado e JSON em seis linhas ABT. `applications/data/qualidade_lotes_json.abt` usa a mesma composição com ausência explícita e contabilizada, também em seis linhas. Nenhum programa acessa `DataFrame`, `Dict` ou detalhes de JSON.jl. As versões anteriores de vendas precisavam filtrar cada grupo e construir o registro de relatório manualmente; a operação comum mantém o cálculo independente da apresentação.

```sh
export ABT_JULIA=/caminho/julia-1.13.3/bin/julia
"$ABT_JULIA" --project=. -e 'import Pkg; Pkg.instantiate()'
bin/abt run applications/data/vendas_por_regiao_json.abt
bin/abt run applications/data/qualidade_lotes_json.abt
python3 test_extensions.py --julia "$ABT_JULIA"
python3 benchmark_extensions.py --julia "$ABT_JULIA" --repetitions 5
python3 run_all_tests.py --julia "$ABT_JULIA"
```

`test_extensions.py` guarda comandos, programas gerados de casos de teste, saídas e erros de cada backend em `test_logs/extensions_results.json`. `benchmark_extensions.py` guarda medições por processo e resumos em `test_logs/extensions_benchmark.json`; usa `/usr/bin/time -v`. `run_all_tests.py` registra a regressão em `test_logs/`.

Para repetir um caso individual com a mesma entrada determinística, use `python3 test_extensions.py --julia "$ABT_JULIA" --case overflow --output test_logs/overflow_repetido.json`. Os caminhos temporários dos arquivos gerados em uma execução não persistem; o script reconstrói os casos e o JSON de resultados preserva o fonte ABT de cada um.

## Limites e roadmap

1. Contrato para seleção e junção de tabelas antes de considerar DataFrames.jl. Manter esquema, ordem, ausência e cardinalidade explícitos.
2. Leitura JSON com esquema ABT explícito e política de chaves desconhecidas; a codificação atual é unidirecional.
3. Operações estatísticas especializadas somente depois de definir hipóteses, convenções numéricas e resultados estruturados.
4. HTTP, alinhamentos e gráficos somente com casos reais e contratos de efeitos, erros e recursos. Interoperabilidade Julia/Python existente executa código de confiança do usuário e não constitui sandbox.

Os resultados efetivos dos testes e do benchmark são registrados em `docs/RESULTADOS_EXTENSOES_0118.md` após a execução.
