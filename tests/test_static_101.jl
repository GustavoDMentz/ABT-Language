# Static regression for ordered Julia imports; requires Julia to run.
include(joinpath(@__DIR__, "..", "pseudo.jl"))
using .Pseudo
src = "mostrar 1\nusar Julia.Statistics\nmostrar Julia.Statistics.mean([2, 4])"
code = generate(parse_program(tokenize(src)))
@assert !occursin("\nimport Statistics\n", code)
@assert occursin("Base.require(Base.PkgId", code)
@assert findfirst("abt_std_render(1)", code) !== nothing
@assert first(findfirst("abt_std_render(1)", code)) < first(findfirst("__abt_julia_module_Statistics = Base.require", code))
println("ABT 0.10.1 import-order static regression OK")
