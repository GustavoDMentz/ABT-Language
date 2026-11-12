# ABT 0.13.0 — etapa científica, validação e limites

## Escopo e decisões

A base auditada foi `036a711` (main 0.12.0), com 42 operações públicas. Esta branch acrescenta 20 operações e atualiza a versão candidata para 0.13.0. A [matriz inicial](AUDITORIA.md) registra capacidades anteriores, lacunas e a divisão da missão. A gramática, o IR e a semântica das operações antigas não foram alterados. O registro existente em `ExtensionRegistry.jl` continua a alimentar interpretador, validação estática e geração Julia; cada fonte nova é emitida somente se utilizada.

Foram reutilizados FASTX.jl, BioSequences.jl, CSV.jl, DataFrames.jl, LinearAlgebra e Cairo.jl. As únicas dependências adicionadas ao projeto são MultipleTesting.jl 0.6.0 e Optim.jl 2.3.2. PythonCall continua opcional. Não foi introduzida uma segunda biblioteca gráfica.

| Família | Operações adicionadas | Contrato central |
|---|---|---|
| Bioinformática | `ler_fastq`, `resumir_fastq`, `registros_fastq`, `frequencias_kmers`, `complemento_reverso`, `traduzir_dna` | DNA e Phred33 explícitos; resumo FASTQ em fluxo; materialização apenas por `registros_fastq`. |
| Tabelas | `selecionar_colunas`, `renomear_colunas`, `ordenar_tabela`, `remover_duplicatas`, `juntar_tabelas`, `exportar_csv` | Esquemas tipados existentes, política de ausentes explícita, chaves compatíveis, ordenação estável. |
| Estatística | `ajustar_valores_p` | Bonferroni/Holm (FWER), BH/BY (FDR); valores-p e alpha válidos; ordem original preservada. |
| Álgebra | `produto_matricial`, `transpor_matriz`, `determinante_matriz`, `posto_matriz`, `decompor_matriz`, `resolver_sistema` | Matrizes retangulares Float64 finitas, dimensões verificadas, fatorações Julia. |
| Otimização | `minimizar_polinomio` | Polinômio escalar, intervalo/tolerâncias/iterações explícitos; Optim/Brent e status estruturado. |

As aplicações em `applications/scientific_0130/` usam dados sintéticos versionados: sequenciamento FASTQ com qualidade e k-mers por leitura; expressão gênica com CSV tipado e ajuste BH; solução de sistema e SVD; gráfico de medidas biomédicas exportado em PNG. Os dados da aplicação de expressão ilustram correção de valores-p e **não** constituem análise diferencial validada de RNA-seq.

Durante os testes da nova decomposição QR, uma matriz 3×2 expôs fatores com dimensões incompatíveis quando `Q` era materializada completa e `R` compacta. A correção seleciona as colunas de `Q` correspondentes às linhas de `R`; o teste de regressão verifica `Q * R ≈ A` para matriz retangular. Nenhuma operação anterior foi modificada.

## Validação executada

Ambiente: Linux x86-64, Julia 1.13.3, depot Julia isolado sobre cache existente. Os testes não usam PythonCall nas operações novas; a regressão incluiu a ponte PythonCall. Resultados estruturados e logs ficam em `logs/scientific_0130/`. Os caminhos pessoais foram anonimizados nos logs versionados.

| Grupo | Resultado | Evidência |
|---|---|---|
| Novas operações Julia, casos válidos/inválidos e comparação com bibliotecas | 54 PASS, 0 FAIL | `unit.log` |
| Interpretador e duas variantes de Julia gerada, incluindo quatro aplicações | 16 PASS, 0 FAIL | `backends-final.log`, `backends.json` |
| Regressão Julia histórica, incluindo 1.000 diferenciais e PythonCall | 44 PASS, 2 PROBE, 0 PARTIAL/FAIL/TIMEOUT | `historical/summary.json` |
| Instalação e CLI | 11 PASS, 0 FAIL/SKIP | `install.log` |
| Semântica e desempenho da CLI | 5 PASS, 0 FAIL/SKIP | `perf-semantics.log` |
| Aplicações históricas | 112 PASS, 0 FAIL/TIMEOUT | `applications.log`, `applications.json` |
| Bioinformática histórica | 63 PASS, 0 FAIL | `bio.log`, `bio.json` |
| Extensões em lote | 33 PASS, 0 FAIL | `batch.log`, `python/batch_118_results.json` |
| Extensões anteriores (CSV/JSON) | 45 PASS, 0 FAIL | `extensions.log`, `extensions.json` |
| Extensões modulares | 51 PASS, 0 FAIL | `modular.log`, `python/modular_results.json` |
| Bioestatística nos três backends | 19 PASS, 0 FAIL | `biostatistics-backends.log` |
| Figura histórica em três backends | 6 PASS: três saídas PNG idênticas, paridade observável, SVG e formato inválido | `chart.log`, `python/batch_chart_results.json` |
| Documentação: catálogo, links, CLI, exemplos e blocos | 49 PASS, 0 FAIL/SKIP; build Documenter PASS | `docs-validation.json`, `docs-build.log` |
| Benchmark científico | 12 processos concluídos, 0 erro/timeout | `benchmark-run.log`, `benchmark.json` |

As duas sondas históricas (`break_abt.jl`, `audit_adversarial.jl`) são exploratórias; código zero não prova ausência de problemas. A comparação das novas operações exige estrutura exata e tolerância relativa/absoluta de 1e-10 somente em números de ponto flutuante. Em erro, exige saída não zero e o nome da operação no diagnóstico. O Fontconfig inicialmente emitiu avisos porque o cache padrão não era gravável; a rodada final usa cache temporário gravável e mantém a comparação de `stderr` sem ocultar avisos.

Os testes diretos incluem FASTQ vazio, truncado, qualidade e bases inválidas; colunas ausentes, junção sem correspondência, chave ausente e tabela vazia; matrizes incompatíveis e singular; valores-p fora de domínio; otimização sem convergência. Os quatro programas novos foram executados nos três modos, com conferência de conteúdo e assinatura PNG na aplicação gráfica.

## Benchmark representativo

`python3 benchmarks/scientific_0130.py` criou três processos independentes por cenário, medindo estágio de carga, preparo, primeira chamada (inclui compilação Julia e carga tardia), 20 chamadas repetidas e pico RSS com `/usr/bin/time -v`. Valores abaixo são medianas; o JSON contém todas as repetições. A linha direta Julia executa o algoritmo da biblioteca; a linha ABT também inclui despacho e apresentação. Esta comparação não isola cada parcela do overhead.

| Trabalho | Modo | Carga (s) | Preparo (s) | Primeira chamada (s) | 20 chamadas (s) | RSS máximo mediano (MiB) |
|---|---|---:|---:|---:|---:|---:|
| Ajuste BH | Julia direta | 0,523 | 0,000 | 0,706 | 0,011 | 325,6 |
| Ajuste BH | ABT interpretado | 0,047 | 1,344 | 4,864 | 0,817 | 393,4 |
| Sistema 2×2 | Julia direta | 0,015 | 0,000 | 0,270 | 0,015 | 238,7 |
| Sistema 2×2 | ABT interpretado | 0,048 | 1,490 | 4,158 | 0,013 | 348,3 |

O tempo total do processo, preservado em `benchmark.json`, também inclui a inicialização Julia anterior ao primeiro carimbo de tempo. Três repetições são suficientes para uma observação inicial, não para uma afirmação geral de desempenho. A primeira chamada ABT é dominada por compilação/carga; em chamadas aquecidas o custo varia muito entre operações. O RSS é do processo inteiro. A diferença de medianas, cerca de 67,8 MiB para BH e 109,6 MiB para matriz, é somente uma estimativa por cenário, não memória incremental exata atribuível ao ABT. Este benchmark não mede instalação, código gerado ou arquivos grandes.

## Limites e próximas etapas

O processamento FASTQ agregado lê em fluxo, mas `registros_fastq`, ordenação, junção e algumas operações tabulares materializam dados. Qualidade é Phred+33 e DNA é maiúsculo; outros alfabetos/codificações exigem API explícita. A álgebra é Float64, sem matrizes esparsas ou precisão configurável. O método de otimização é uma busca escalar local, sem garantia de mínimo global. Não há contrato de callback ABT equivalente nos três backends para funções arbitrárias. Agrupamentos multichave, transformações tabulares gerais e histograma/boxplot/barras/mapa de calor configuráveis permanecem para outra etapa. A visualização reutiliza a operação de linha/pontos já existente. Interoperabilidade Julia/Python pressupõe código e pacotes confiáveis; ABT não é sandbox.

## Reprodução no Ubuntu com Julia 1.13.3

Na raiz do repositório, com `julia --version` mostrando `julia version 1.13.3`:

```sh
export ABT_JULIA="$(command -v julia)"
julia --project=. -e 'import Pkg; Pkg.instantiate()'
bin/abt run applications/scientific_0130/sequenciamento.abt
bin/abt run applications/scientific_0130/expressao.abt
bin/abt run applications/scientific_0130/algebra.abt
bin/abt run applications/scientific_0130/visualizacao.abt
julia --project=. tests/test_scientific_0130.jl
python3 tests/test_scientific_backends_0130.py
python3 tests/run_all_tests.py --julia "$ABT_JULIA" --timeout 300 --log-dir logs/scientific_0130/historical
ABT_TEST_JULIA="$ABT_JULIA" python3 -m unittest tests.test_install_cli tests.test_perf_semantics
ABT_DOC_VALIDATION_OUTPUT=logs/scientific_0130/docs-validation.json python3 tools/validate_docs.py
julia --project=docs -e 'import Pkg; Pkg.instantiate()'
julia --project=docs docs/make.jl
python3 benchmarks/scientific_0130.py --julia "$ABT_JULIA" --repetitions 3 --iterations 20
```

Para a ponte PythonCall opcional, configure um Python compatível e rode a regressão com `JULIA_CONDAPKG_BACKEND=Null` e `JULIA_PYTHONCALL_EXE=$(command -v python3)`. Os testes Python legados possuem saídas individuais em `logs/scientific_0130/`; use `ABT_TEST_LOG_DIR=logs/scientific_0130/python` para preservar resultados históricos ao executá-los novamente.
