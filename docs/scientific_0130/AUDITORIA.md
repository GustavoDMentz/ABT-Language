# Auditoria inicial e escopo da primeira etapa 0.13.0

Base: `036a711`, main 0.12.0; 42 operações públicas. Branch `feat/abt-scientific-libraries-0130`. Nenhuma alteração de gramática planejada. Esta PR é a primeira etapa da expansão 0.13.0; não será integrada automaticamente.

| Família | Estado inicial | Evidência e decisão |
|---|---|---|
| FASTA e contagens | implementado | FASTX/BioSequences; leitura iterável, resumo e registros em StdlibBio |
| FASTQ, k-mers, complemento, tradução | ausente | adicionar contratos explícitos sobre FASTX/BioSequences |
| Tabelas CSV tipadas | implementado | CSV.Rows/Tables, filtro, transformação aritmética e resumo |
| Junções, seleção, ordenação, exportação | ausente | integrar sem inferência de esquema |
| Agrupamento | parcialmente implementado | grupo textual único; múltiplas chaves/agregações ficam para etapa seguinte |
| Estatística clássica | implementado | Statistics, StatsBase, HypothesisTests, Distributions, GLM |
| Múltiplas comparações | ausente | MultipleTesting: Bonferroni, Holm, BH e BY |
| Álgebra linear | parcialmente implementado | apenas solução SPD; ampliar matrizes Float64 explícitas |
| Objetivos ABT como callbacks | ausente | ABTFunction é um valor do interpretador, sem interface callable equivalente ao código gerado |
| Otimização | ausente | subconjunto: polinômio univariado com coeficientes Float64 e intervalo/tolerâncias/limite explícitos; Optim/Brent |
| Gráficos | parcialmente implementado | Cairo PNG/SVG linhas/pontos já utilizável; seis modalidades configuráveis ficam para etapa seguinte |
| CairoMakie | experimental | avaliação anterior incompleta por recursos, registrada em logs/test_logs/cairomakie_evaluation.txt; não reinstalar outra biblioteca gráfica nesta etapa |

O registro `ABT_EXTENSION_SPECS` alimenta aridade, validação estática, interpretador e geração. Os novos arquivos são incluídos apenas quando suas operações aparecem no código gerado. Pacotes externos só são carregados durante chamadas. A instalação usa Julia 1.13.3 e um depot isolado; o cache temporário de trabalhos anteriores não estava mais disponível. PythonCall permanece opcional no produto, obrigatório na rodada de testes de interoperabilidade.

A suíte histórica reúne testes Julia em processos independentes, testes Python de CLI/aplicações/extensões e 1.000 casos diferenciais. Novas execuções devem escrever em `logs/scientific_0130`, sem substituir evidências históricas. A referência oficial é gerada por `tools/generate_docs_reference.py` e conferida contra o catálogo real.

Fontes primárias consultadas: [FASTX FASTQ](https://biojulia.dev/FASTX.jl/dev/fastq/), [MultipleTesting](https://github.com/juliangehring/MultipleTesting.jl), [Optim minimização](https://julianlsolvers.github.io/Optim.jl/latest/user/minimization/). As APIs efetivas serão verificadas também no código das versões instaladas.
