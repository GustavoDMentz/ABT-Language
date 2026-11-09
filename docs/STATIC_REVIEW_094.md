# ABT 0.9.4 — static remediation and repeat audit

## Changes
- All user-defined names in generated Julia are encoded as hex UTF-8 with a reserved prefix. This avoids Julia keywords (`end`), helper-name collisions and Unicode identifier hazards.
- Top-level function declarations are hoisted in both the interpreter and code generator. Forward calls are now consistent.
- Function names cannot be rebound by assignments or loop variables, or shadowed by parameters. This avoids the semantic check consulting an obsolete function signature.
- Nested function declarations are explicitly rejected rather than being inconsistently executed.
- Internal `__abt_` names are rejected in the parser.
- Function symbols are included in the initial validation environment to allow passing functions as values.

## Further static adversarial observations (NOT resolved)
1. **Top-level Julia soft scope:** emitted `for`/`if` assignments may have different binding semantics from interpreter dictionaries, especially when invoked via `include` or REPL. The generated program needs a single explicit top-level function or consistent `global` handling.
2. **Branch binding:** validator merges types after `if` but does not represent runtime control-flow state or dominance fully. In particular, branch-local functions and assignments require stronger CFG analysis.
3. **Python security:** rejecting private attributes is not a sandbox; public attributes can execute arbitrary Python code. Not safe for untrusted packages.
4. **External objects:** equality, formatting and exception details can differ between the interpreter and generated Julia.
5. **Numeric semantics:** aggregate means use different accumulator types (`0` vs `0.0`), potentially diverging on large integers or exotic numeric types.
6. **Caching:** no bounded disk-cache implementation; do not claim precompiled binaries or near-zero startup latency.

## Validation status
Static inspection and source-level consistency checks performed. Julia runtime unavailable here. All executable tests are **pending** on a Julia installation. Do not promote this to a stable release.
