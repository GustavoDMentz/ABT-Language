# Compilador, IR e execução

## Da fonte ao AST

`tokenize` produz `Token(kind, lexeme, line, col)`. Comentários e espaços são ignorados; strings, números, identificadores e operadores são reconhecidos por padrões explícitos. `expand_pipelines` transforma linhas indentadas em operações de coleção antes de `parse_program`. O parser recursivo descendente constrói `Node(kind, args)` e reporta token e posição em erros de sintaxe.

## IR e validação

`lower_ir` converte AST em instruções `IR(op, operands)`: `:store`, `:print`, `:branch`, `:foreach`, `:function`, `:return`, imports e expressões como `:constant`, `:load`, `:binary`, `:call`, `:filter`, `:map`, `:limit`. `validate_ir` primeiro verifica forma estrutural, ciclos, profundidade e operandos; depois valida nomes, atribuição definida, aridade e alguns tipos conhecidos. `:unknown` representa tipo que não pode ser provado estaticamente; as pré-condições de valores são verificadas durante a execução. Entradas IR externas passam pelo mesmo validador.

Funções de nível superior são coletadas antes do fluxo de instruções. As atribuições locais de função sombreiam nomes externos em toda a invocação; um nome lido antes da atribuição local é erro. Ambos os ramos de um condicional precisam definir um novo nome para garanti-lo depois. Um laço pode não executar e não garante novos nomes fora do corpo.

## Dois modos de execução

`execute` valida o IR derivado do AST e interpreta `Node`. `generate` valida o IR, pode aplicar `optimize_ir` e emite Julia por `_generate_validated_ir`. A otimização é conservadora: comparações de literais numéricos e ramos com condição booleana literal, sem reordenar operações com efeitos. Identificadores ABT são codificados em nomes internos Julia, evitando captura acidental por palavras Julia. `Base.invokelatest` é usado em pontos de carregamento tardio para contornar world age, não como mecanismo de coerção.

Para inspecionar tokens, AST, IR e Julia gerada:

```bash
julia --project=. pseudo.jl examples/pipeline_basico.abt --explain --no-run
julia --project=. pseudo.jl examples/pipeline_basico.abt --emit-julia /tmp/pipeline.jl --no-run
julia --project=. pseudo.jl examples/pipeline_basico.abt --emit-julia /tmp/pipeline-plain.jl --no-opt --no-run
```

O primeiro comando é diagnóstico da interface legada; a execução cotidiana usa `bin/abt`. Testes diferenciais em `tests/` comparam interpretador, Julia sem otimização e Julia otimizada, além de valores de referência das bibliotecas científicas.
