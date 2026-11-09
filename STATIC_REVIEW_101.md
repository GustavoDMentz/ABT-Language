# ABT 0.10.1 — 12ª inspeção estática adversarial

## Correção
- Removida antecipação de `import Statistics`, `LinearAlgebra` e `Base` na geração Julia.
- `usar Julia.Módulo` agora emite `@eval import Módulo` no ponto correspondente dentro de `__abt_program_main__()`. A importação ocorre somente ao executar a instrução.
- Mantida a validação de importação anterior ao uso no código ABT.

## Nova quebra identificada — alta prioridade
**Namespaces Python em importações de prefixos sobrepostos:** a implementação de `abt_external_field` prioriza a existência de descendentes (`any(startswith(k, path * "."))`) antes de procurar o módulo exato. Quando `Python.pkg` e `Python.pkg.sub` foram importados, acessar `Python.pkg` pode devolver uma *view* intermediária em vez do módulo Python efetivo. Isso pode alterar o comportamento de chamadas e acesso a atributos do pacote. O interpretador usa `bridge_runtime.jl`; é necessário comparar a prioridade de resolução dos dois caminhos e escolher uma regra única.

## Limitações adicionais
- `@eval import` introduz um binding no módulo hospedeiro, apesar do `let` isolar os helpers. A ordem de execução é corrigida, mas isolamento completo do host não foi demonstrado.
- Importações repetidas têm cache/efeitos determinados pelo carregador Julia; o interpretador usa módulos já carregados em `Pseudo`.
- Testes Julia não executados neste ambiente. A inspeção de texto e a integridade do ZIP não comprovam correção em runtime.
