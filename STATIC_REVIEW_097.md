# ABT 0.9.7 — static semantics and adversarial audit

## Corrections
1. Function bodies now accept only parameters, local bindings and declared ABT functions. Reading implicit top-level variables (including forward declarations) is rejected. This is an intentional PoC restriction that resolves the call-time-vs-lexical capture ambiguity without pretending to support closures.
2. Python namespace construction now occurs inside the generated main function, not when the generated file is included. Imports themselves remain in source order.

## Newly found by static inspection — NOT FIXED
1. **Import namespace divergence**: `Julia` namespace may be referenced as a value (`mostrar Julia`) even though the generator does not bind `Julia` as a runtime value. Likewise, a Python import in a conditional is prohibited, but the namespace exists in generated main before its first import; accessing `Python` before import can diverge. Requires explicit namespace restrictions.
2. **Function argument evaluation order**: generated Julia calls `abt_invoke(f, arg1, arg2)`; Julia evaluates function arguments in order, but expressions with external effects need runtime differential verification.
3. **Repeated include collision**: generated top-level helper and main names are fixed. Repeated inclusion can redefine methods and change behavior.
4. **External object field access**: interpreter and generated code may dispatch through different module contexts for opaque Julia/Python objects. Needs runtime verification.
5. **Aggregate predicate binding**: `value` and `valor` are rebound inside generator comprehension; collision with an outer binding or a nested expression can diverge. Needs focused tests.

## Verification
Static source inspection and ZIP integrity only. No Julia interpreter installed here. Regression tests provided but not executed. These fixes do not prove full equivalence.
