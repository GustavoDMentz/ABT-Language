include("pseudo.jl")
using .Pseudo

# Adversarial optimizer inputs: malformed IR must not leak indexing/type errors.
bad = [
    Pseudo.ir(:print),
    Pseudo.ir(:store, "x"),
    Pseudo.ir(:print, Pseudo.ir(:binary, "+", Pseudo.ir(:constant, 1))),
    Pseudo.ir(:branch, Pseudo.ir(:constant, true), 12, Pseudo.IR[]),
    Pseudo.ir(:function, "f", ["x", 3], Pseudo.IR[]),
    Pseudo.ir(:print, Pseudo.ir(:call, Pseudo.ir(:load, "f"), "bad")),
]
for node in bad
    try
        Pseudo.optimize_ir(Pseudo.IR[node])
        error("REGRESSION: malformed IR accepted by optimizer")
    catch err
        msg = sprint(showerror, err)
        occursin("REGRESSION", msg) && rethrow()
        occursin("Semantic error: malformed IR", msg) || rethrow()
    end
end

# Valid input remains optimizable; public generator must accept its output.
valid = Pseudo.IR[
    Pseudo.ir(:store, "x", Pseudo.ir(:constant, 4)),
    Pseudo.ir(:branch, Pseudo.ir(:constant, true),
        Pseudo.IR[Pseudo.ir(:print, Pseudo.ir(:load, "x"))], Pseudo.IR[])
]
optimized = Pseudo.optimize_ir(valid)
@assert length(optimized) == 2
@assert optimized[2].op == :print
Meta.parse(Pseudo.generate(optimized))
println("ABT 0.11.2 optimizer boundary regressions passed")
