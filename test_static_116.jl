include("pseudo.jl")
using .Pseudo

# Shared acyclic DAG with exponentially many expanded visits.
leaf = let node = Pseudo.ir(:constant, 1)
    for _ in 1:20
        node = Pseudo.ir(:binary, "+", node, node)
    end
    node
end
program = Pseudo.IR[Pseudo.ir(:print, leaf)]
try
    Pseudo.validate_ir(program)
    error("REGRESSION: expanded DAG accepted without a work bound")
catch err
    @assert occursin("structural validation budget exceeded", sprint(showerror, err))
end

# Ordinary IR remains accepted.
normal = Pseudo.IR[Pseudo.ir(:print, Pseudo.ir(:constant, 2))]
@assert Pseudo.validate_ir(normal) === normal
@assert Pseudo.optimize_ir(normal) isa Vector{Pseudo.IR}
# A long flat program must not consume the per-expression DAG work budget.
many = Pseudo.IR[Pseudo.ir(:store, "x", Pseudo.ir(:constant, 0))]
append!(many, (Pseudo.ir(:store, "x", Pseudo.ir(:binary, "+", Pseudo.ir(:load, "x"), Pseudo.ir(:constant, 1))) for _ in 1:100_000))
@assert Pseudo.validate_ir(many) === many
println("ABT 0.11.6 validation budget regressions passed")
