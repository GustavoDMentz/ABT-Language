# ABT 0.11.6 — 28ª rodada

## Fix
Bound expanded IR shape-validation visits to 100,000, including statements and expressions. This prevents exponential traversal of acyclic shared subexpressions. It deliberately rejects excessively large expanded programs rather than memoizing by identity (which can hide context-dependent errors).

## Active checks performed in this environment
Python-based source assertions, ZIP CRC verification, and a separate adversarial DAG simulation. These are **not** Julia execution tests. The Julia regression is supplied as `tests/test_static_116.jl` and must be run with Julia.

## Remaining risks
- Python bridge duplication between interpreter and generated runtime.
- No dynamic interpreter/generated equivalence test performed.
- Julia module-loading compatibility unverified.
- Optimizer can still expand shared DAGs after validation; budget protects validator only.
