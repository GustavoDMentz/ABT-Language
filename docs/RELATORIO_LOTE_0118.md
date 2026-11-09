# ABT 0.11.8 — relatório do lote integrado

## Escopo e alterações

O parser agora aceita sinais prefixos `+`/`-` e exponenciação `^`; `e` precede `ou`. A semântica formal está em [LOTE_CIENTIFICO_0118.md](LOTE_CIENTIFICO_0118.md). O interpretador, o IR, a validação, a otimização conservadora e o gerador Julia receberam apenas o suporte correspondente. Os sinais exigem valores numéricos; tipos comprovadamente inválidos são rejeitados antes da geração. As operações novas usam `src/ExtensionRegistry.jl` e `src/StdlibBatch.jl`, com um único registro para interpretador e código gerado. O gerador inclui o arquivo de implementação uma vez mesmo quando o programa usa várias operações do lote. Listas, matrizes e registros existentes atenderam às três aplicações; nenhuma mudança ergonômica adicional foi introduzida sem defeito reproduzido. O instalador foi atualizado para distribuir `src/StdlibBatch.jl`: um teste isolado reproduziu a falha de pré-compilação sem esse arquivo; após a correção, os 9 testes do instalador passaram.

Pacotes integrados nesta entrega: DataFrames.jl 1.8.2, CategoricalArrays.jl 1.1.1, HypothesisTests.jl 0.12.2, Distributions.jl 0.25.134, BioAlignments.jl 3.1.0 e Cairo.jl 1.1.1. CairoMakie.jl 0.15.17 foi instalado e avaliado, mas sua pré-compilação consumiu cerca de 3 GB de RSS, praticamente todo o swap disponível e não terminou dentro do limite operacional local; foi removido do projeto. A biblioteca Cairo.jl, já presente como dependência transitiva durante a avaliação, sustenta a exportação determinística PNG/SVG. JSON3.jl duplicaria a operação JSON já existente; HTTP.jl não é necessário para as aplicações deste lote.

## Validação

- Suíte diferencial consolidada: **33 PASS, 0 FAIL**, cobrindo sinais, precedência, entradas inválidas, gráfico estruturado, categorias, testes t e aplicações de estatística e biologia nos três backends. Resultado estruturado: `logs/test_logs/batch_118_results.json`.
- Exportação gráfica: **6 PASS, 0 FAIL** — PNG nos três backends, paridade exata de `stdout` e SHA-256, SVG válido e rejeição de extensão inválida. Resultado: `logs/test_logs/batch_chart_results.json`.
- Instalador isolado: **9 PASS, 0 FAIL** após correção da lista de arquivos (`logs/test_logs/batch_install_final.log`).
- Extensões legadas: **45 PASS, 0 FAIL** (`logs/test_logs/batch_extensions_final.json`). Extensões modulares: **51 PASS, 0 FAIL** (`logs/test_logs/modular_results.json`).
- Aplicações legadas: **112 PASS, 0 FAIL, 0 TIMEOUT**; resultado por caso e backend em `applications/test_results.json`, saída em `logs/test_logs/batch_applications_final.log`.
- Suíte histórica final: **41 PASS, 2 PROBE, 0 PARTIAL, 0 FAIL, 0 TIMEOUT**. As duas sondas são exploratórias e não contam como aprovação. Resultado estruturado: `logs/test_logs/summary.json`; log consolidado: `logs/test_logs/batch_historical_final.log`.
- A primeira tentativa histórica, sem configuração explícita de Python, teve 36 PASS, 2 sondas exploratórias, 3 PARTIAL, 1 FAIL e 1 TIMEOUT. Os resultados parciais/falha vieram da tentativa de CondaPkg baixar Python em ambiente sem rede; o timeout veio da pré-compilação de Makie iniciada por um teste de CLI. Essas falhas não foram contadas como aprovação. O log foi preservado em `logs/test_logs/batch_historical_before_python_env.log` e o resumo em `logs/test_logs/summary_before_python_env.json`. A execução final usa PythonCall com o Python 3.12.3 e NumPy 2.5.1 do sistema, via `JULIA_CONDAPKG_BACKEND=Null` e `JULIA_PYTHONCALL_EXE=/usr/bin/python3`.

## Desempenho representativo

Ubuntu/Linux x86-64, kernel 7.0.0-42-generic, Julia 1.13.3; duas execuções independentes por cenário, `--compile=min --compiled-modules=existing`, dependências já instaladas e cache de fontes em `/tmp/abt-fontcache`. Tempo é de processo completo, medido por `/usr/bin/time -v`. RSS é do processo inteiro, não alocação interna nem tamanho do ABT em disco. A tabela mostra as duas observações; não extrapola para carga fria de instalação ou pré-compilação.

| Cenário | Tempo real (s) | CPU usuário (s) | CPU sistema (s) | Pico RSS (MiB) |
| --- | ---: | ---: | ---: | ---: |
| Mínimo | 0,74 / 0,73 | 0,72 / 0,72 | 0,10 / 0,09 | 254,8 / 255,1 |
| Estatística | 4,30 / 4,61 | 3,61 / 3,68 | 0,36 / 0,32 | 504,5 / 502,0 |
| Visualização | 3,57 / 2,41 | 3,22 / 2,18 | 0,21 / 0,23 | 382,9 / 370,3 |
| Biologia | 1,76 / 1,29 | 1,57 / 1,18 | 0,16 / 0,16 | 331,0 / 325,8 |

O processo estatístico tem o maior custo neste conjunto porque carrega CSV, DataFrames, CategoricalArrays, HypothesisTests, Distributions e JSON. O programa mínimo não carrega essas bibliotecas. Os dados brutos, inclusive comandos e saídas, estão em `logs/test_logs/batch_benchmark.json`; o script é `benchmarks/benchmark_batch_118.py`.

## Reprodução no Ubuntu com Julia 1.13.3

A partir da raiz deste projeto:

```bash
julia --project=. --startup-file=no -e 'using Pkg; Pkg.instantiate()'
export JULIA_CONDAPKG_BACKEND=Null
export JULIA_PYTHONCALL_EXE=/usr/bin/python3
export XDG_CACHE_HOME=/tmp/abt-fontcache
mkdir -p "$XDG_CACHE_HOME"
# Para executar também os testes Python opcionais em uma instalação nova:
julia --project=@v1.13 --startup-file=no -e 'using Pkg; Pkg.add("PythonCall")'
python3 tests/test_batch_118.py
python3 tests/test_chart_118.py
python3 tests/run_all_tests.py --julia julia --timeout 240
ABT_TEST_JULIA="$(command -v julia)" python3 tests/test_install_cli.py
python3 tests/test_applications.py --julia julia
python3 tests/test_extensions.py --julia julia
python3 tests/test_modular_extensions.py --julia julia
python3 benchmarks/benchmark_batch_118.py
julia --project=. --startup-file=no src/CLI.jl applications/science/estatistica.abt
julia --project=. --startup-file=no src/CLI.jl applications/science/visualizacao.abt
julia --project=. --startup-file=no src/CLI.jl applications/science/alinhamento.abt
```

PythonCall continua opcional: só os testes de interoperabilidade Python precisam dele. Sem PythonCall/NumPy, esses testes são parciais ou inconclusivos, nunca aprovados. Para reproduzir exatamente os tempos desta máquina, use o mesmo `JULIA_DEPOT_PATH` registrado nos comandos do JSON bruto e `--compile=min --compiled-modules=existing`.

## Limitações e prioridades

`agrupar_dados` e `grafico` materializam colunas; arquivos muito grandes ainda podem exigir agrupamento e agregação em streaming. A visualização tem apenas linhas e pontos, com escala linear e largura 640×480; não substitui uma biblioteca de visualização científica completa. O gráfico converte coordenadas numéricas para `Float64` na apresentação, uma limitação a considerar para inteiros muito grandes. Testes t dependem das hipóteses científicas documentadas pela biblioteca; o ABT exige a escolha `welch` ou `student`, mas não infere se os dados as satisfazem. O alinhamento exige pontuações explícitas e devolve métricas, sem escolher parâmetros biológicos. As integrações Julia/Python executam bibliotecas confiáveis no processo; ABT não é sandbox.

Prioridades seguintes: (1) política explícita para dados grandes em agrupamento/gráfico; (2) avaliação de backend gráfico completo numa máquina com mais RAM; (3) intervalos de confiança e diagnósticos estatísticos adicionais apenas quando solicitados por aplicações reais.
