include("pseudo.jl")
using .Pseudo

base = Pseudo.IR[Pseudo.ir(:print, Pseudo.ir(:load, "provided"))]
for names in (
    42,
    Dict(1 => :unknown),
    Dict("" => :unknown),
    Dict("provided" => :bogus),
    Dict("provided" => "unknown"),
    Dict("Python" => :unknown),
    Dict("Julia" => :external),
    Dict("__julia_Statistics" => :unknown),
    Dict("bad\nname" => :unknown),
)
    try
        Pseudo.validate_ir(base; initial_names=names)
        error("REGRESSION: invalid initial_names accepted")
    catch err
        msg = sprint(showerror, err)
        occursin("REGRESSION", msg) && rethrow()
        occursin("Semantic error:", msg) || rethrow()
    end
end
for kind in (:unknown, :external, :number, :bool, :string, :list)
    @assert Pseudo.validate_ir(base; initial_names=Dict("provided" => kind)) === base
end
@assert Pseudo.validate_ir(Pseudo.IR[Pseudo.ir(:print, Pseudo.ir(:constant, 1))]) isa Vector{Pseudo.IR}
println("ABT 0.11.3 initial_names boundary regressions passed")
