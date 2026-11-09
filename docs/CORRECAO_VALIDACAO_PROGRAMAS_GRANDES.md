# Correção da validação estrutural em programas grandes

## Causa raiz

`abt_check_ir_shape` em `src/ABT.jl` somava em um único contador global as visitas de todos os comandos e expressões do programa. O teto de 100.000 visitas foi criado para impedir trabalho exponencial ao expandir um grafo IR compartilhado dentro de uma expressão. Porém, um programa plano de atribuições simples também consumia várias visitas por linha. Assim, o validador rejeitava uma entrada válida por seu comprimento total, antes da execução. A checagem estrutural ainda fazia uma passagem prévia para detectar ciclos, seguida das verificações de forma e da análise semântica; essas passagens são lineares para um programa plano. Não foi encontrada recursão profunda no caso de incrementos: a profundidade de cada expressão é constante.

## Alteração

O orçamento de expansão agora é reiniciado em cada **expressão raiz** de um comando. As chamadas recursivas dentro da mesma expressão continuam compartilhando o contador, portanto o caso adversarial de DAG com expansão exponencial ainda é rejeitado. A passagem prévia de detecção de ciclos, o limite de aninhamento, a validação de opcodes/operandos e a análise semântica permanecem ativas. Comandos sequenciais deixam de competir por um orçamento global. A mudança não afeta parser, IR, execução, sintaxe ou semântica ABT.

`test_static_116.jl` agora verifica os dois lados: um DAG compartilhado malformado continua excedendo o orçamento; 100.000 atribuições IR planas passam pela validação. O programa executável de 100.000 linhas também retornou `100000` nos dois modos de compilação.

## Medições locais antes e depois

Uma execução por cenário após a correção, com processo novo, `/usr/bin/time -v`, Julia 1.13.3 e mesmo depot do benchmark anterior. Tempo real em segundos e RSS máximo do **processo inteiro** em MiB. Os dados anteriores de 10.000 abaixo são uma execução registrada; o benchmark original contém dez repetições e suas estatísticas em [BENCHMARK_ESCALABILIDADE.md](BENCHMARK_ESCALABILIDADE.md). O tempo de uma falha mede a tentativa abortada, não uma execução correta.

| Incrementos | Modo | Antes: status / tempo / RSS | Depois: status / tempo / RSS |
|---:|:---:|:---|:---|
| 10.000 | min | correto / 16,122 s / 285,3 MiB | correto / 16,821 s / 285,7 MiB |
| 10.000 | all | correto / 4,482 s / 387,5 MiB | correto / 4,418 s / 386,6 MiB |
| 100.000 | min | erro de orçamento / 119,891 s / 444,2 MiB | correto / 166,177 s / 467,8 MiB |
| 100.000 | all | erro de orçamento / 4,862 s / 499,4 MiB | correto / 6,347 s / 494,4 MiB |
| 1.000.000 | min | não medido | timeout em 180,101 s; RSS indisponível |
| 1.000.000 | all | não medido | correto / 36,015 s / 2.227,4 MiB |

O caso de 1.000.000 em `min` **não** foi aprovado: não produziu saída antes do limite de 180 s. Um milhão em `all` produziu exatamente `1000000`. O benchmark antes da correção não tentou 1.000.000 porque 100.000 já falhava. Não há base para afirmar ganho de desempenho em 10.000 a partir de uma única rodada após a mudança; as diferenças observadas são pequenas diante da variação normal de inicialização/JIT.

Os dados estruturados estão em `benchmarks/scalability/results.json` (antes) e `benchmarks/scalability/after_fix.json` (depois). A saída completa de `/usr/bin/time -v` e stdout da rodada posterior estão em `benchmarks/scalability/after_fix_raw/`. O script reproduzível é `benchmarks/scalability/measure_validation_fix.py`; ele verifica a saída exata e registra falhas e timeout separadamente. Para reproduzir no Ubuntu:

```bash
export ABT_JULIA=/caminho/para/julia-1.13.3/bin/julia
export JULIA_DEPOT_PATH=/caminho/para/depot-julia-com-abt
python3 benchmarks/scalability/measure_validation_fix.py
python3 run_all_tests.py --julia "$ABT_JULIA" --timeout 180
```

Para testes Python opcionais sem instalação Conda pela rede, esta rodada também usou `JULIA_CONDAPKG_BACKEND=Null` e `JULIA_PYTHONCALL_EXE=/usr/bin/python3`, onde PythonCall e NumPy já estavam disponíveis. O teste adversarial sem essa configuração falhou por tentativa de acesso à rede do CondaPkg; isso não é regressão da validação IR.

## Regressão final

A suíte completa `run_all_tests.py` foi executada após a alteração: **38 PASS, 2 PROBE, 0 PARTIAL, 0 FAIL, 0 TIMEOUT**. Isso inclui `test_static_116.jl`, o teste diferencial determinístico de 1.000 casos, testes de interoperabilidade, pipelines, legados e adversariais. `PROBE` identifica duas sondas exploratórias; não equivale a prova de ausência de problemas. O resumo estruturado está em `benchmarks/scalability/regression_final_summary.json`, e os logs individuais em `test_logs/`.

Uma primeira rodada, sem configuração do Python local, teve 34 PASS, 3 PARTIAL, 1 FAIL e 2 PROBE. A falha ocorreu porque CondaPkg tentou obter metadados pela rede bloqueada. O resumo e o log dessa ocorrência foram preservados em `benchmarks/scalability/regression_initial_summary.json` e `regression_initial_semantic_adversarial.log`. A segunda rodada usou:

```bash
JULIA_CONDAPKG_BACKEND=Null JULIA_PYTHONCALL_EXE=/usr/bin/python3 \
  python3 run_all_tests.py --julia "$ABT_JULIA" --timeout 180
```

## Limites remanescentes

Uma expressão individual com DAG compartilhado de expansão excessiva ainda é rejeitada, intencionalmente. O limite de aninhamento de 256 níveis também permanece. A execução de um milhão de atribuições em `min` é lenta demais para o teto de 180 s desta medição; seu resultado permanece inconclusivo nesse modo. Programas com milhões de linhas demandam memória substancial devido ao próprio tamanho do AST/IR e ao runtime Julia. Nenhuma otimização de execução ou alteração de linguagem foi feita.
