include(joinpath(@__DIR__, "..", "pseudo.jl"))
using .Pseudo

# No global helper declarations: repeated inclusion is expected to be isolated.
p = parse_program(tokenize("mostrar 2 + 3"))
g = generate(p)
@assert occursin("\nlet\n", g)
@assert !occursin("import PythonCall", g)
@assert occursin("__abt_program_main__()", g)

# Import only when reached in the ABT program, never at generated-file load.
p2 = parse_program(tokenize("mostrar 7\nusar Python.math\nmostrar Python.math.sqrt(4)"))
g2 = generate(p2)
@assert occursin("abt_load_pythoncall!(__abt_pythoncall_cache__).pyimport", g2)
@assert first(findfirst("abt_std_render(7)", g2)) < first(findfirst("abt_import_python!(Python, \"math\"", g2))
@assert !occursin("struct ABTPythonNamespace", g2)
println("Static source assertions passed (not differential execution tests).")
