# ABT 0.9.8 — static namespace hardening / ninth adversarial pass

## Fixes (source inspection, not Julia-executed)
- Reject bare `Python` / `Julia` namespace values. These are access roots, not first-class values.
- Require Python import before a Python attribute reference, including when import occurs later in source.
- Restrict Julia namespace references to an imported, allowlisted `Julia.Module.function` path. Prevent printing a module root that generated Julia doesn't bind.
- Function invocation interpreter environment now includes declared ABT functions and explicit parameters, not arbitrary ambient top-level bindings; this follows the no-implicit-captures contract from 0.9.7.
- Add focused regression source `test_static_098.jl`.

## New static findings — NOT FIXED
1. **High — branch-sensitive import state:** `python_imports` is a single mutable set captured by the validator. It is updated while checking either branch and may leak a conditional import to subsequent checks even though nested imports are rejected. Check nested rejection occurs first; this should be validated for early abort and future extensions. More generally `names` merge and `python_imports` are not an explicit flow-state data structure.
2. **High — `Julia` module alias codegen:** `Julia.Statistics.mean` becomes `Statistics.mean` in emitted code, while interpreter looks up `JULIA_MODULES["Statistics"]`. Consistency depends on actual exported module names and their loading; no runtime proof.
3. **High — function names and namespace names:** function declaration hoisting + imported module names can still interact with codegen's fixed helper identifiers. Repeated `include` redefines global helpers and main method; no per-program isolation.
4. **Medium — predicate lexical capture:** aggregate predicate uses generated comprehension `let` and names `value` / `valor`; nested predicates and mutation/capture semantics need a differential test.
5. **Medium — Python import execution order:** generated code imports `PythonCall` at module load even if the ABT import is later. This can fail before ABT statements that precede the import, unlike interpreter execution.
6. **Medium — function-scoped namespace use:** current contract forbids capturing imported Python/Julia namespaces, so a function that references them is rejected; document as an intentional PoC limitation rather than implying full interoperability inside ABT functions.
7. **Medium — interpreter environment:** only `ABTFunction` values are retained, so externally injected callable values used in functions may be rejected at runtime despite validation with custom `initial_names`. Explicitly define injected-name semantics.

## Verification
Python `py_compile` for patch script and ZIP CRC can be checked here. No Julia runtime available, therefore tests are provided but not claimed to pass. Continue static remediation before runtime validation.
