include(joinpath(@__DIR__, "..", "pseudo.jl"))
using .Pseudo

function rejected(src)
    try
        generate(parse_program(tokenize(src)))
    catch e
        @assert occursin("undefined variable", sprint(showerror, e))
        return
    end
    error("Expected static rejection: " * src)
end

rejected("função f() { retornar x }\nx = 10\nmostrar f()")
rejected("x = 10\nfunção f() { retornar x }\nmostrar f()")

src = "função f(x) { retornar x + 1 }\nmostrar f(10)"
nodes = parse_program(tokenize(src))
@assert execute(nodes) == ["11"]
@assert occursin("function __abt_program_main__()", generate(nodes))

py = "usar Python.numpy\nmostrar Python.numpy.mean([1, 2, 3])"
code = generate(parse_program(tokenize(py)))
@assert occursin("    Python = abt_namespace(Dict{String,Any}(), \"\")", code)
@assert !occursin("\nPython = abt_namespace(Dict{String,Any}(), \"\")", code)
println("0.9.7 regression checks passed")
