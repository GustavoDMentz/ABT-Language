include(joinpath(@__DIR__, "..", "pseudo.jl"))
using .Pseudo

function rejects(f)
    try
        f()
    catch err
        @assert occursin("Semantic error:", sprint(showerror, err))
        return
    end
    error("REGRESSION: malformed IR was accepted")
end

# An immutable IR can still be cyclic through its mutable operands vector.
cyclic = Pseudo.ir(:print, Pseudo.ir(:constant, 1))
cyclic.operands[1] = cyclic
program = Pseudo.IR[cyclic]
rejects(() -> Pseudo.validate_ir(program))
rejects(() -> Pseudo.optimize_ir(program))
rejects(() -> Pseudo.generate_ir(program))

# Mutual recursion through expression nodes.
a = Pseudo.ir(:field, Pseudo.ir(:load, "x"), "y")
b = Pseudo.ir(:field, a, "z")
a.operands[1] = b
rejects(() -> Pseudo.validate_ir(Pseudo.IR[Pseudo.ir(:print, a)]))

# Malformed input must not reach the optimizer's positional operand access.
rejects(() -> Pseudo.optimize_ir(Pseudo.IR[Pseudo.ir(:binary, "+")]))

# Shared subexpressions are not cycles.
shared = Pseudo.ir(:constant, 3)
valid = Pseudo.IR[Pseudo.ir(:print, Pseudo.ir(:list, Pseudo.IR[shared, shared]))]
@assert Pseudo.validate_ir(valid) === valid
@assert Pseudo.optimize_ir(valid) isa Vector{Pseudo.IR}
println("ABT 0.11.4 cycle and optimizer boundary regressions passed")
