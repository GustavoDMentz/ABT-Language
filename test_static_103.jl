include("pseudo.jl")
using .Pseudo
src = "usar Julia.Statistics\nmostrar Julia.Statistics.mean([2, 4])"
generated = generate(parse_program(tokenize(src)))
@assert !occursin("@eval import Statistics", generated)
@assert occursin("Base.require(Base.PkgId", generated)
@assert occursin("__abt_julia_module_Statistics.mean", generated)
@assert !occursin("@eval import LinearAlgebra", generated)
println("Static import-isolation checks passed")
