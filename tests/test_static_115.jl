include(joinpath(@__DIR__, "..", "pseudo.jl"))
using .Pseudo

function rejects_malformed(f)
    try
        f()
    catch err
        @assert occursin("Semantic error: malformed IR", sprint(showerror, err))
        return
    end
    error("REGRESSION: malformed IR was accepted")
end

# Vector{Any} can contain IR nodes but is not a Vector{IR}.
# Optimizer and other downstream functions explicitly require Vector{IR}.
wrong_args = Pseudo.ir(:call, Pseudo.ir(:load, "f"), Any[Pseudo.ir(:constant, 1)])
wrong_list = Pseudo.ir(:list, Any[Pseudo.ir(:constant, 1)])
wrong_branch = Pseudo.ir(:branch, Pseudo.ir(:constant, true), Any[Pseudo.ir(:print, Pseudo.ir(:constant, 1))], Pseudo.IR[])
wrong_fn = Pseudo.ir(:function, "f", Any["x"], Pseudo.IR[])
for node in (Pseudo.ir(:print, wrong_args), Pseudo.ir(:print, wrong_list), wrong_branch, wrong_fn)
    program = Pseudo.IR[node]
    rejects_malformed(() -> Pseudo.validate_ir(program))
    rejects_malformed(() -> Pseudo.optimize_ir(program))
    rejects_malformed(() -> Pseudo.generate_ir(program))
end

# Correctly typed containers remain legal.
good = Pseudo.IR[Pseudo.ir(:print, Pseudo.ir(:list, Pseudo.IR[Pseudo.ir(:constant, 1)]))]
@assert Pseudo.validate_ir(good) === good
@assert Pseudo.optimize_ir(good) isa Vector{Pseudo.IR}
println("ABT 0.11.5 typed IR containers regressions passed")
