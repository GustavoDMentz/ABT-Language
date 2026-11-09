# Reorganização estrutural do repositório ABT-Language

## Escopo e linha de base

Esta reorganização parte do commit `55b79287a1f087158cfd0a52e83c3a9deef049b1` de `main`. A cópia foi obtida do repositório público e modificada localmente; nenhum arquivo de `sources/` do projeto ChatGPT foi alterado. Antes da movimentação, a raiz continha **207 arquivos regulares**. Havia testes Julia e Python, scripts de benchmark, documentação histórica e resultados misturados com os manifestos e adaptadores de execução. As pastas `test_logs`, `test_logs_baseline`, `test_logs_correction`, `test_logs_evolucao_baseline` e `perf_logs` também ficavam na raiz.

O [inventário completo](INVENTARIO_REORGANIZACAO.csv) registra, para cada um dos 207 arquivos da raiz original, o destino e a classificação por propósito.

## Nova organização

| Destino | Conteúdo |
| --- | --- |
| `src/` | Núcleo ABT, runtime e extensões existentes; conteúdo sem mudança semântica. |
| `applications/` | Aplicações por domínio e seus dados; estrutura preservada. |
| `tests/` | Testes Julia/Python, sondas e executor integral. |
| `benchmarks/` | Scripts, cenários de escalabilidade e resultados de benchmark. |
| `docs/` | Especificações, relatórios atuais e auditorias históricas. |
| `logs/` | Logs, resultados estruturados de execução e diretórios históricos de evidência. |
| `tools/` | Instalação, remoção e auxiliares de desenvolvimento. |
| `examples/`, `bin/`, `vscode/` | Exemplos, CLI e integração com VS Code existentes. |

Os dados das aplicações permaneceram junto aos respectivos domínios em `applications/`; os arquivos didáticos de `examples/` continuam sendo fixtures de compatibilidade para testes legados. Não foi criada uma pasta `tests/fixtures/` vazia nem duplicados esses dados.

Foram movidos **201 arquivos da raiz** e **5 diretórios de evidência**. Nada foi eliminado por aparente duplicação. Os 29 arquivos de evidência que uma nova execução sobrescreveu foram preservados com seus bytes originais em `logs/baseline_repository/`. Os seis arquivos regulares mantidos na raiz são `Project.toml` e `Manifest.toml` (ambiente Julia), `ABT.packages.toml` (catálogo de pacotes), `README.md` (entrada do projeto), `pseudo.jl` e `bridge_runtime.jl` (adaptadores de compatibilidade usados pela suíte histórica). `.vscode/` permaneceu na raiz por ser configuração reconhecida pelo editor.

Dentro do antigo `perf_logs/`, três programas ABT de carga e duas sondas Julia foram classificados como cenários de benchmark e colocados em `benchmarks/scenarios/`; as medições e saídas históricas ficaram em `logs/perf_logs/`.

## Referências e integridade

Os executores agora resolvem a raiz a partir de seus novos diretórios. O executor integral descobre `tests/test_*.jl` e grava saídas em `logs/test_logs/`. Os testes Julia incluem os adaptadores legados por caminho explícito e continuam usando fixtures de `examples/`. O instalador e desinstalador foram movidos para `tools/`; o instalador continua copiando apenas os arquivos de distribuição registrados em `FILES`. O teste isolado de atualização foi ajustado para copiar o instalador na mesma estrutura. `.vscode/tasks.json`, README e documentação referenciam os novos caminhos. `bin/abt`, os módulos em `src/` e as aplicações não foram alterados.

Os geradores de resultados novos foram apontados para `logs/test_logs/` ou arquivos `current_*`, deixando os dados antigos em `logs/historical/` e `benchmarks/results/`. O teste de 1.000 casos diferenciais foi repetido após esse ajuste de saída: **1000 PASS, 0 FAIL**; `logs/structural_differential_rerun.log` e `logs/test_logs/differential_results.toml` registram a execução.

O primeiro teste da CLI encontrou uma restrição do ambiente de auditoria: o depot padrão de Julia estava em uma área somente leitura. A execução com `JULIA_DEPOT_PATH` gravável passou; essa condição é de ambiente e não uma falha do projeto.

Uma execução adicional de `tests/test_perf_semantics.py` encontrou um defeito antigo na fixture de instalação: ela copiava só `ABT.jl` e `Runtime/Bridge.jl`, embora o módulo carregue outros arquivos de `src/`. A fixture agora copia `src/` completo; o caso de invalidação do manifesto passou na repetição isolada (`logs/structural_perf_manifest_rerun.log`). Na mesma execução concorrente, o teste de SIGINT excedeu seu prazo de 15 segundos; repetido isoladamente, passou em 0,858 s (`logs/structural_perf_interrupt_rerun.log`). A primeira execução com falhas permanece em `logs/structural_perf_semantics.log` e não é apresentada como aprovação.

Após a correção da fixture, a suíte completa de semântica de desempenho foi repetida: **5 testes aprovados, 0 falhas e 0 erros** (`logs/structural_perf_semantics_final.log`).

A sonda adicional `benchmarks/verify_benchmark_equivalence_118.jl` executou, mas retornou **1**: o caso `collection_0` compara textualmente `Any[]` emitido pela função Julia de referência com `[]` apresentado pelo ABT. O código das duas implementações e seus valores não foram alterados nesta reorganização. O log antigo `11/11 equivalent` foi preservado em `logs/historical/benchmark_equivalence.log`; o resultado atual e o código de saída estão em `logs/structural_benchmark_equivalence.log`. Esta sonda **não é declarada aprovada**. A comparação textual requer auditoria separada antes de qualquer afirmação de equivalência.

## Validação e comparação

| Suíte | Antes da reorganização | Depois | Evidência |
| --- | --- | --- | --- |
| Instalação/CLI | 9 PASS, 0 FAIL | 9 PASS, 0 FAIL | `logs/structural_install.log` |
| CLI direta | `bin/abt` operacional | `doctor` e pipeline didático: códigos 0, saída `[30, 40]` | `logs/structural_cli_final.log` |
| Diferenciais e exportação gráfica do lote científico | 33 PASS + 6 PASS, 0 FAIL | 33 PASS + 6 PASS, 0 FAIL | `logs/structural_batch.log`, `logs/structural_chart.log` |
| Semântica de desempenho | 5 testes aprovados | 5 testes aprovados após correção da fixture | `logs/structural_perf_semantics_final.log` |
| Bioinformática | 63 PASS, 0 FAIL | 63 PASS, 0 FAIL | `logs/test_logs/bio_results.json`, `logs/structural_bio.log` |
| Aplicações | 112 PASS, 0 FAIL | 112 PASS, 0 FAIL, 0 TIMEOUT | `applications/test_results.json`, `logs/structural_applications.log` |
| Extensões | 45 PASS, 0 FAIL | 45 PASS, 0 FAIL | `logs/structural_extensions.log` |
| Extensões modulares | 51 PASS, 0 FAIL | 51 PASS, 0 FAIL | `logs/structural_modular.log` |
| Histórica completa | 41 PASS, 2 PROBE, 0 FAIL | 41 PASS, 2 PROBE, 0 PARTIAL, 0 FAIL, 0 TIMEOUT | `logs/test_logs/summary.json`, `logs/structural_historical.log` |
| Benchmark representativo | Quatro cenários, duas execuções cada | 8/8 processos com código zero e saída correta | `logs/test_logs/batch_benchmark.json`, `logs/structural_benchmark.log` |
| Sonda histórica de equivalência de benchmark | Log anterior: 11/11 | Falhou em `collection_0` por comparação textual de lista vazia | `logs/structural_benchmark_equivalence.log` |

`PROBE` indica sonda exploratória e não aprovação. Os resultados anteriores são da última execução documentada no repositório, com Julia 1.13.3 e PythonCall configurado. Tempos de benchmark são medições de processo completo e não garantem equivalência numérica entre máquinas.

| Cenário | Tempo real após mudança, duas execuções (s) | Pico RSS do processo (KiB) |
| --- | ---: | ---: |
| Mínimo | 0,89 / 0,61 | 239112 / 239192 |
| Estatística | 6,80 / 7,38 | 493904 / 495452 |
| Visualização | 3,15 / 2,17 | 370232 / 369756 |
| Biologia | 2,27 / 2,95 | 339340 / 343552 |

As medições ocorreram junto das suítes de regressão, portanto não são uma comparação controlada de desempenho com o estado anterior. Servem para verificar que os quatro cenários ainda executam e para registrar custo aproximado de processo.

Não foram repetidas nesta reorganização as campanhas extensas de escalabilidade, estresse de 10.000 casos, medições de bioinformática em larga escala e todos os scripts históricos de benchmark. Seus arquivos e resultados anteriores foram preservados; apenas o benchmark representativo e a sonda de equivalência acima foram executados. Nenhuma aprovação é atribuída às campanhas não executadas aqui.

## Comandos

A partir da raiz da cópia reorganizada, com Julia 1.13.3 disponível:

```bash
export JULIA_DEPOT_PATH=/caminho/gravavel/para/depot
export JULIA_CONDAPKG_BACKEND=Null
export JULIA_PYTHONCALL_EXE=/usr/bin/python3
export ABT_JULIA=/caminho/para/julia
bin/abt doctor
bin/abt run examples/pipeline_basico.abt
ABT_TEST_JULIA="$ABT_JULIA" python3 tests/test_install_cli.py
python3 tests/test_applications.py --julia "$ABT_JULIA"
python3 tests/test_extensions.py --julia "$ABT_JULIA"
python3 tests/test_modular_extensions.py --julia "$ABT_JULIA"
python3 tests/run_all_tests.py --julia "$ABT_JULIA" --timeout 180
python3 benchmarks/benchmark_batch_118.py
```

## Atenção manual

Ferramentas externas que chamavam scripts pela localização antiga precisam usar `tests/`, `benchmarks/` ou `tools/` conforme o arquivo. Logs históricos preservam os comandos e caminhos da execução original; esses registros não foram reescritos como se a medição antiga tivesse sido produzida pela nova estrutura. Nenhuma dependência, gramática, IR ou contrato de biblioteca foi alterado.
