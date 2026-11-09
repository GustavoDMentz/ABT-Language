# ABT 0.9.9 — tenth static adversarial review

## Changes (inspected, NOT Julia-executed)
1. Generated helpers, namespace helper and main function now reside in a fresh `let` scope. This avoids redefining the same helper functions when two generated ABT programs are included in one Julia module.
2. The generated Python namespace uses a lightweight NamedTuple rather than a global struct, allowing helpers to be scoped to `let`.
3. `PythonCall` is no longer imported at generated-file load. The emitted `@eval import PythonCall` occurs at the textual ABT Python import statement. This preserves earlier program side effects if import fails, although it still adds a binding to the host module when reached.
4. No PythonCall import or Python namespace helpers are emitted for Julia-only programs.
5. Added `test_static_099.jl` source assertions.

## Tenth adversarial pass: new issues / unresolved
**HIGH — generated Python namespace representation differs from interpreter.** Interpreter uses `ABTPythonNamespace`; generator uses a NamedTuple with `modules` and `prefix`. Common paths have matching logic, but a crafted external object that is a NamedTuple with those keys may be misclassified as a namespace. A unique internal sentinel or sealed type outside local scope is needed for strict equivalence.

**HIGH — Julia import timing is still eager.** `import Statistics` and other Julia imports are emitted at file scope. The interpreter imports only on reaching the ABT `usar Julia...` statement. If import side effects matter, ordering differs. For current allowlisted stdlib modules this is a limited practical issue, but still a semantic discrepancy.

**HIGH — validator's definite assignment for loops is unsound.** If a loop modifies an existing variable, the validator degrades its type to `:unknown`, but the generated Julia variable may be uninitialized or behave differently in zero iterations. A flow-sensitive, explicit assignment-state analysis is needed.

**HIGH — generated output differs from interpreter for `nothing`, booleans, and some collections.** Julia `println` and interpreter `string` may agree for common scalars but are not a complete ABT serialization contract, especially for PythonCall proxy values.

**FIXED BY INSPECTION — function fallthrough.** Generated ABT functions now end with explicit `return nothing`, matching interpreter behavior on fallthrough.

**MEDIUM — PythonCall lazy import still modifies global module state** when first reached; repeated include is free of ABT helper collisions, but PythonCall itself remains a shared module binding.

## Verification
ZIP CRC and Python static inspection only. Julia is not installed here. Do not claim runtime tests pass.
