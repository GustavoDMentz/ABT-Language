# ABT 0.11.6 — auditoria semântica diferencial

## Método e cobertura

`tests/test_differential_1000.jl` gera exatamente 1.000 programas com `MersenneTwister(0xAB7116)` e os executa no interpretador, no Julia gerado sem otimização e no Julia gerado com otimização. Cada caso compara a sequência completa de saídas ABT, `stderr`, classe e mensagem da exceção original. Apenas o `LoadError` acrescentado por `include_string` para indicar a posição do código gerado é removido na comparação; nenhuma mensagem interna ou saída é normalizada. O identificador do caso e o programa completo são gravados em `logs/historical/differential_results.toml` se houver divergência. `--case ID` reproduz um caso individualmente.

| Categoria | Casos |
|---|---:|
| Aritmética | 250 |
| Condicionais e lógica | 150 |
| Laços e escopo | 150 |
| Funções | 150 |
| Agregações | 150 |
| Nomes Unicode | 100 |
| Interoperabilidade Julia | 50 |

A sonda `tests/test_semantic_adversarial.jl` acrescenta casos mínimos de recursão, referência antecipada a função, curto-circuito, erro em argumento, divisão por zero, coleções vazias, sombreamento, imports Julia repetidos, imports Python pai/filho em ambas as ordens, imports repetidos, objeto Python e oito entradas inválidas. As suítes históricas `test_static_109..116.jl` cobrem IR profundo, compartilhado e cíclico e orçamento de validação. `tests/test_bridge_092.jl` e `tests/test_adversarial_093.jl` verificam importação parcial e resolução de namespace com importador simulado.

O programa ABT autocontido expõe os valores calculados por `show` e pelos erros. A linguagem atual não oferece reflexão de tipos nem acesso ao ambiente interno do código gerado; por isso a comparação de tipos observáveis se limita a representações distintas como `1`/`1.0` e às categorias de exceção. A suíte não afirma equivalência de estado interno não observável. Também não instrumenta escrita externa arbitrária de bibliotecas Python; a sonda Python usa funções NumPy sem esse tipo de efeito.

## Defeito reproduzido e correção

Caso mínimo: `usar Python.numpy\nshow Python.numpy.sum([1,2,3])`, sem importar PythonCall antes de executar o ABT. O interpretador produzia `PythonCall.Py(Ptr{Nothing}(...))`, enquanto o código Julia gerado produzia `6`. A causa era a chamada a `string` em uma função compilada antes de PythonCall registrar os métodos de formatação de `Py`. A correção mínima foi usar `Base.invokelatest(string, valor)` ao transformar a expressão de `show` em saída no interpretador. O carregador também lê o binding recém-importado com `Base.invokelatest(getfield, ...)`, eliminando o aviso de acesso em world age antigo. A regressão está em `tests/test_semantic_adversarial.jl` e foi executada com `--depwarn=error`.

`tests/test_static_107.jl` tinha uma asserção textual para a antiga leitura direta do binding; foi atualizada para verificar a forma agora necessária. Nenhum teste válido foi removido.

## Revisão das correções anteriores

- `Base.invokelatest` continua necessário no importador Python, no acesso a atributos `Py`, nas chamadas e na impressão de valores de bibliotecas carregadas durante a execução. Ele preserva a exceção original; os testes diferenciais comparam tipo e mensagem. Seu uso universal em `abt_invoke` também cobre funções ABT que não precisam dele, com custo de despacho dinâmico e menor inferência de tipos. Não foi alterado porque separar caminhos por tipo introduziria complexidade sem defeito reproduzido; desempenho intensivo permanece um risco a medir se o projeto passar a usá-lo.
- A resolução de módulos pai e submódulos explicitamente importados mantém ambos acessíveis. Imports fracassados só publicam o módulo após sucesso de `pyimport`. Os testes de ordem de importação e repetição passaram.
- `Julia.Módulo.função(...)` é validado como caminho completo; referências parciais usadas como valores continuam rejeitadas. `Statistics` e `LinearAlgebra` são carregados pelos UUIDs da biblioteca padrão, mantendo PythonCall opcional.
- Identificadores do usuário são codificados em hex UTF-8 no Julia gerado. A superfície textual rejeita o prefixo interno `__abt_`; nomes Unicode diferentes permanecem distintos. Os testes de IR e `initial_names` preservam as barreiras existentes.
- `pygetattr` é usado para objetos `PythonCall.Py`, depois do bloqueio de acesso direto a atributos que começam com `_`. Chamadas dinâmicas de bibliotecas Python podem contornar essa regra; o ABT não oferece sandbox. `tests/audit_adversarial.jl` ainda registra dois `FINDING` exploratórios sobre `getattr(..., "__dict__")` e `os.system`.

## Resultado e reprodução

A execução integral final iniciou **36 scripts**: **34 PASS, 2 PROBE, 0 PARTIAL, 0 FAIL, 0 TIMEOUT**. `tests/runtests_legacy.jl` foi executado por inclusão em `tests/runtests.jl`. Não houve casos `Broken`/ignorados. A suíte diferencial registrou **1.000 PASS e 0 divergências**. As duas sondas exploratórias foram executadas; `tests/audit_adversarial.jl` manteve os dois `FINDING` de limites de confiança descritos acima, sem falha de processo.

Os resultados estruturados estão em `logs/test_logs/summary.json` e `logs/historical/differential_results.toml`. `logs/historical/full_semantic_run_final.log` registra o runner; logs por script estão em `logs/test_logs/`. `logs/historical/semantic_adversarial_depwarn.log` registra a sonda com avisos tratados como erros. `logs/test_logs_baseline/` preserva a linha de base da auditoria anterior.

No Ubuntu com Julia 1.13.3, a partir desta pasta:

```sh
export JULIA_DEPOT_PATH="$PWD/.julia_depot"
export JULIA_PYTHONCALL_EXE=/usr/bin/python3
julia --startup-file=no -e 'using Pkg; Pkg.add("PythonCall")'
ABT_REQUIRE_PYTHON=1 python3 tests/run_all_tests.py --julia julia --timeout 180
julia --startup-file=no tests/test_differential_1000.jl --case 731
julia --startup-file=no --depwarn=error tests/test_semantic_adversarial.jl
```

PythonCall 0.9.37 e NumPy 2.5.1 foram usados nesta auditoria. O executável `julia` via juliaup não funcionou sob a restrição de escrita desta sessão; aqui foi usado diretamente `<JULIA_BIN>`. A instalação de PythonCall é necessária para reproduzir a rodada com `ABT_REQUIRE_PYTHON=1`, mas continua opcional para a execução normal do ABT.
