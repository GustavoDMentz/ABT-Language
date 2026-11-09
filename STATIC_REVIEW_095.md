# ABT 0.9.5 — static remediation and new adversarial pass

## Applied
- Generated user program now runs in `__abt_program_main__()`, removing top-level soft-scope differences for `if`/`for` assignments.
- Julia imports remain at module scope, because Julia disallows `import` inside a function.
- Loop iteration uses an internal temporary and assigns to the ABT variable inside the loop, matching the interpreter's update of an existing binding.
- Generated `pseudo_average` now starts with integer `0`, matching the interpreter; both still use Julia's `/` and may overflow identically on ordinary fixed-width integer sums.

## NEW adversarial findings (not yet fixed)
1. **Function local/global semantics**: the interpreter copies its current environment at function invocation, while generated Julia functions capture outer lexical bindings. A function that assigns to a variable that also exists outside can modify its *local* copy in the interpreter, while Julia may modify the captured outer binding. Requires a deliberate lexical-scope contract, not a cosmetic patch.
2. **Loop variable after an empty iteration**: validator permits an existing variable to be read after an empty loop, but generator may treat the loop-assigned name as a captured local; verify runtime behavior.
3. **Import temporal semantics**: Julia module imports are emitted before the program, whereas interpreter executes import statements in source order. Static validator generally prevents early use but function hoisting can expose differences.
4. **Aggregate numeric edge cases**: matching accumulator initialization does not guarantee identical behavior for Python proxies, `BigInt`, custom numeric types or overflow-sensitive operations.
5. **Generated module namespace**: a generated file defines fixed helper names at module scope and is not designed for repeated inclusion in the same module; isolation is not yet specified.

## Status
Static source review only. Julia executable is unavailable in this environment. No runtime success claimed. These are limitations of the current proof of concept.
