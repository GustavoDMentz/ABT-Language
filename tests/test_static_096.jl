include(joinpath(@__DIR__, "..", "pseudo.jl"))
using .Pseudo

function check_case(src, expected)
 nodes = parse_program(tokenize(src))
 actual = execute(nodes)
 @assert actual == expected (src, actual, expected)
 generated = generate(nodes)
 @assert occursin("local __abt_user_", generated)
 return generated
end

# Local writes do not mutate a captured outer variable.
check_case("x = 10\nfunção alterar() { x = 99; retornar x }\nmostrar alterar()\nmostrar x", ["99", "10"])
# Local shadowing applies before the first assignment.
for source in ["x = 10\nfunção f() { mostrar x; x = 2 }\nmostrar f()",
               "x = 10\nfunção f() { x = x + 1; retornar x }\nmostrar f()"]
 try
  generate(parse_program(tokenize(source)))
  error("Expected semantic rejection: " * source)
 catch err
  occursin("undefined variable", sprint(showerror, err)) || rethrow()
 end
end
println("Static 0.9.6 contract checks passed (interpreter + generated source inspection).")
