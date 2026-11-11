# ABT 0.11.7 — evolução de coleções com rigor semântico

## Resultado verificado

O baseline da versão anterior foi executado antes das mudanças: **34 PASS, 2 PROBE, 0 PARTIAL, 0 FAIL, 0 TIMEOUT** (`logs/historical/baseline_evolucao.log`, `logs/test_logs_evolucao_baseline/`). Após as mudanças, a execução integral final iniciou **37 scripts**: **35 PASS, 2 PROBE, 0 PARTIAL, 0 FAIL, 0 TIMEOUT** (`logs/historical/full_evolucao_final.log`, `logs/test_logs/summary.json`). `tests/runtests_legacy.jl` rodou dentro de `tests/runtests.jl`. Nenhum teste foi marcado como `Broken`/ignorado.

`tests/test_collections_117.jl` registrou 30 casos de contrato/diferenciais, 300 composições determinísticas com semente `0xAB7117` e 5 asserções adicionais: **335 verificações aprovadas**. A suíte anterior de 1.000 casos diferenciais também passou. As duas sondas exploratórias foram executadas; `tests/audit_adversarial.jl` continuou com dois `FINDING` sobre os limites de confiança de Python (`getattr` dinâmico e `os.system`). Isso não é uma certificação de segurança.

Três arquivos `.abt` foram executados pela CLI no interpretador e no Julia gerado com otimização ligada/desligada; as saídas foram idênticas (`logs/historical/cli_examples_results.json`). Um predicado não booleano foi testado pela CLI e produziu erro explícito com código de saída 1.

## O que mudou

Três expressões composicionais foram acrescentadas: `filtrar coleção onde predicado`, `transformar coleção com expressão` e `limitar coleção a quantidade`. O contrato completo está em `ESPECIFICACAO_COLECOES_117.md`; as escolhas de IR e execução estão em `DECISOES_ARQUITETURAIS_117.md`.

O lexer não reserva as palavras novas. O parser as reconhece apenas no formato da operação, preservando identificadores antigos. AST, IR, validação estrutural, inferência semântica, interpretador, passagem do otimizador e gerador Julia receberam os três casos necessários. O IR expressa composição por aninhamento, sem reordenação ou fusão. Julia `map`, `filter` e fatiamento de vetor executam as operações; não foi criado um runtime paralelo.

Comparação concreta: em 0.11.6, seleção e transformação de uma coleção não formavam uma nova coleção por uma expressão ABT autocontida; exigiam lógica manual ou uma chamada externa. Agora `limitar (transformar (filtrar dados onde valor > 2) com valor * 10) a 2` produz `[30, 40]` como uma única expressão, mantendo visíveis o predicado, a transformação e o limite.

## Divergência encontrada e correção

O caso determinístico 1 de composição revelou uma divergência com vetor vazio: `mostrar transformar (filtrar xs onde ...) com valor + n` imprimia `Any[]` no interpretador e `Int64[]` no Julia gerado. A causa era a inferência de tipo da closure no `map` gerado, embora nenhum elemento tivesse sido transformado. O contrato foi fixado: transformar vetor vazio retorna `Any[]` e não executa a expressão. Ambos os caminhos agora implementam isso explicitamente. Os 300 casos foram repetidos e passaram antes da execução integral final.

## Cobertura e limites

Os testes novos cobrem composição entre as três operações e a agregação existente, vetores vazios, limite zero e acima do tamanho, ordem de efeitos em funções por elemento, nomes Unicode, imports e escopo herdados, entradas não vetoriais, predicado incompatível, limite inválido e IR malformado. Interpretador e código gerado foram comparados com otimização ligada/desligada para cada caso diferencial. Programas válidos da versão anterior continuaram aprovados.

O escopo desta etapa é deliberadamente pequeno: não há agrupamento por chave, ordenação declarativa, carregamento CSV, valores ausentes automáticos, paralelismo, fusão de pipelines ou inferência de esquema. As operações aceitam `Vector`, não tabelas arbitrárias nem proxies Python. A saída de `mostrar` ainda expõe a representação Julia de vetores, inclusive `Any[]` no caso vazio; esse comportamento foi fixado para equivalência, mas não constitui uma API tabular estável. PythonCall permanece opcional e não transforma o ABT em sandbox.

O pacote de origem não contém arquivo `LICENSE`; esta etapa não altera titularidade ou termos de distribuição. Não foram introduzidas dependências obrigatórias nem código de licença incompatível com MIT.

## Reprodução no Ubuntu com Julia 1.13.3

Dentro da pasta `abt_v116`, com PythonCall 0.9.37 e NumPy 2.5.1 para a rodada obrigatória de Python:

```sh
export JULIA_DEPOT_PATH="$PWD/.julia_depot"
export JULIA_PYTHONCALL_EXE=/usr/bin/python3
julia --startup-file=no -e 'using Pkg; Pkg.add("PythonCall")'
ABT_REQUIRE_PYTHON=1 python3 tests/run_all_tests.py --julia julia --timeout 180
python3 tools/run_cli_examples.py --julia julia
julia --startup-file=no pseudo.jl examples/colecoes_pipeline.abt
julia --startup-file=no tests/test_collections_117.jl
```

Nesta sessão, o launcher juliaup não podia criar lockfile sob a restrição de escrita; os comandos foram executados com `<JULIA_BIN>` no lugar de `julia`. O cache `.julia_depot/` foi excluído do ZIP entregue; o comando de instalação acima o reconstrói.
