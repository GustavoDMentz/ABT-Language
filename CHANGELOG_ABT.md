# ABT — correction and adversarial audit log

- 0.9.3: callable objects, optional bridge, exception identity (prior audit).
- 0.9.4: function reassignment, identifier encoding, forward declarations (prior audit).
- 0.9.5: generated main function, loop binding, accumulator alignment (prior audit).
- 0.9.6: function-local writes and definite-assignment checks (prior audit).
- 0.9.7: no implicit global captures; Python namespace construction at runtime (prior audit).
- 0.9.8: namespace-as-value rejection, Python import temporal checks, Julia allowlisted path validation, interpreter function environment tightening. Ninth static audit in STATIC_REVIEW_098.md.

All changes after 0.9.2 are **statically reviewed, not runtime-certified** in this environment.

## 0.9.9 — static isolation and lazy Python loading
- Wrap generated helpers/main in a fresh `let` scope for repeated inclusion.
- Move generated PythonCall import to the ABT import execution point.
- Replace generated global Python namespace struct with a local namespace representation.
- Add `test_static_099.jl` and `STATIC_REVIEW_099.md`.
- Tenth static audit: see outstanding high-priority findings in `STATIC_REVIEW_099.md`.
- Ensure generated ABT functions explicitly return `nothing` on fallthrough.

## 0.10.0 — namespace identity
- Identidade de namespace gerado via token privado por programa.
- 11ª auditoria: imports Julia antecipados e ambientes externos ainda pendentes; hipótese sobre operadores booleanos descartada após rechecagem.

## 0.10.1 — 12ª rodada
- Imports Julia emitidos em ordem de execução com `@eval import` dentro da função principal.
- Teste de regressão estático e auditoria de resolução de namespaces sobrepostos.

## 0.10.2 — 13ª rodada
- Corrigida prioridade de módulos Python importados exatamente sobre namespaces virtuais de descendentes.
- Testes de regressão adicionados (`test_static_102.jl`).
- Nova auditoria em `STATIC_REVIEW_102.md`: importações Julia via `@eval` ainda contaminam o módulo hospedeiro.
- Correções inspecionadas estaticamente; execução Julia pendente.

## 0.10.3 — isolamento de importações Julia
- Removido `@eval import` de módulos Julia do código gerado.
- Referências Julia usam vínculos locais carregados por `Base.require(PkgId)`.
- 14ª auditoria: `@eval import PythonCall` ainda vaza para o módulo hospedeiro; ver `STATIC_REVIEW_103.md`.

## 0.10.4 — isolamento do import Python no gerador
- Substituído `@eval import PythonCall` por `Core.eval` de `import PythonCall` em módulo privado por programa.
- Acrescentado `test_static_104.jl` e `STATIC_REVIEW_104.md`.
- Próximo achado: interpretador ainda importa PythonCall no módulo `Pseudo`.

## 0.10.5 — PythonCall loader parity
- Interpreter loads PythonCall into a private module, not Pseudo.
- Generated code initializes its PythonCall module variable before first use.
- 16th static review: shared Python state and package-loading compatibility remain open.

## 0.10.6 — 17ª rodada
- Centralização da política de carregamento tardio PythonCall (`abt_load_pythoncall!`) nos dois backends.
- Contrato explícito de estado Python compartilhado e caches locais de referência.
- Teste `test_static_106.jl`; nova hipótese adversarial documentada em `STATIC_REVIEW_106.md`.

## 0.10.7 — rodada 18
- Uniformizada mensagem de falha de importação PythonCall entre interpretador e gerador.
- Nova auditoria: diferença na proteção de atributos privados no código gerado sem Python (`STATIC_REVIEW_107.md`).

## 0.10.8 — 20ª auditoria estática ampla
- Corrigida a ausência de bloqueio de atributos privados no código gerado sem Python.
- `execute` passa a copiar o ambiente externo e rejeitar chaves internas reservadas.
- Adicionado `test_static_108.jl` e `STATIC_REVIEW_108.md`.
- Novos riscos H1–H7 registrados; não foram declarados resolvidos.

## 0.10.9 — rodada 21
- `generate_ir` público valida IR; emissão interna separada para IR já validado.
- Constant folding limitado a números primitivos finitos.
- Auditoria ampla em `STATIC_REVIEW_109.md` e regressão `test_static_109.jl`.
- Julia não executado; bridge duplicado permanece pendente.

## 0.11.0 — rodada 22
- Validação e serialização conservadora de constantes IR; rejeição de objetos arbitrários.
- Correção de interpolação prematura de `$field` e `$path` em templates Julia gerados.
- Alinhamento de diagnósticos do bridge e `test_static_110.jl`.
- Nova auditoria em `STATIC_REVIEW_110.md`; Julia não executado.

## 0.11.1 — 23ª rodada
- Pré-validação estrutural recursiva de IR antes da validação semântica; erros contextualizados por caminho.
- Regressões de IR malformado adicionadas em `test_static_111.jl`.
- Nova auditoria em `STATIC_REVIEW_111.md`. Testes Julia não executados.

## 0.11.2 — 24ª auditoria
- `optimize_ir` agora verifica a estrutura recursiva do IR antes de acessar operandos; mantém a transformação independente da resolução de nomes.
- Adicionado `test_static_112.jl` para IR malformado e otimização de ramo válido.
- Auditoria estática: ainda pendentes equivalência dinâmica da ponte Python, contratos de efeitos/erros, carregamento de módulos e validação de `initial_names`.

## 0.11.3 — 25ª rodada
- Validação estrita de `initial_names` na entrada pública de `validate_ir`.
- Rejeição de tipos semânticos inválidos e de nomes de namespaces internos/reservados.
- Regressões `test_static_113.jl`; auditoria `STATIC_REVIEW_113.md`.
- Execução Julia pendente.

## 0.11.4 — 26ª rodada
- Detecta ciclos em vetores de operandos de IR antes da validação recursiva.
- Adiciona limite defensivo de aninhamento para IR manual.
- Valida a estrutura na entrada pública de `optimize_ir`.
- Adiciona `test_static_114.jl` e `STATIC_REVIEW_114.md` (não executados em Julia).

## 0.11.5 — 27ª auditoria
- Exigir `Vector{IR}` em sequências internas e `Vector{String}` em parâmetros de função no verificador de forma, evitando que IR previamente aceito cause `MethodError` em rotinas tipadas.
- Adicionar `test_static_115.jl` e `STATIC_REVIEW_115.md`.
- Testes Julia ainda não executados.

## 0.11.6
- Limit expanded IR structural validation work to 100,000 visits; add adversarial shared-DAG regression.
- Document limitations of checks without Julia runtime.
