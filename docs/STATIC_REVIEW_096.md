# ABT 0.9.6 — local bindings and another adversarial inspection

## Applied (source-level; Julia not executed here)
- Assignments and loop targets in functions are local to that invocation, including nested IF/FOR blocks.
- The interpreter removes inherited outer bindings for those names before evaluating the body, then binds parameters.
- The validator removes inherited names for function-local write targets, rejecting read-before-write cases rather than silently reading the outer variable.
- The Julia generator emits explicit `local` declarations at the beginning of each generated function to prevent accidental mutation of captured bindings.
- Added `tests/test_static_096.jl` covering mutation isolation and read-before-write rejection.

## NEW adversarial findings (unfixed)
1. **Forward global reads in function bodies**: the validator checks a function body at its textual declaration using the current name map, but generated Julia functions are hoisted. A function referencing a global declared later can be rejected despite a later call when the binding exists. Conversely, allowing such reads blindly could allow calls before initialization. Requires a precise temporal name-resolution contract.
2. **Nested function captures and call-time globals**: interpreter uses a copy of the call-time environment; generated Julia functions capture lexical bindings. A global that is reassigned between calls may have different behavior if Julia resolves a local variable in a different scope. Requires runtime verification and a defined capture policy.
3. **Loop write semantics and definite assignment**: a local name written only in a zero-iteration loop is uninitialized; validator's conservative path merging should be checked against Julia's runtime errors, especially if the name was previously initialized.
4. **Python import time**: generator creates a Python namespace at module scope while interpreter constructs it on first import. Function hoisting and import order remain potentially divergent.
5. **Repeated inclusion**: fixed global helper names and `__abt_program_main__` collide when the generated file is included multiple times in one module.
6. **Generated code contains Python/Julia attribute paths without a complete ABI/escaping contract**: external properties and import module names require additional review for correctness and safety.

## Scope and verification
This is a proof of concept. Static review cannot prove complete equivalence or discover every bug. No Julia runtime was available in this environment, so the new regression test is supplied but **not executed**.
