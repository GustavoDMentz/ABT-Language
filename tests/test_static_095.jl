include(joinpath(@__DIR__, "..", "pseudo.jl"))
using .Pseudo

function generated(source)
    return generate(parse_program(tokenize(source)))
end

# Source-level regression checks; run with Julia.
code = generated("x = 1\npara cada y em [2, 3] { x = x + y }\nmostrar x")
@assert occursin("function __abt_program_main__()", code)
@assert occursin("__abt_program_main__()", code)
@assert occursin("__abt_iter_", code)
@assert occursin("pseudo_average(xs)", code)
@assert occursin("total = 0", code)
println("ABT 0.9.5 static generation checks passed")
