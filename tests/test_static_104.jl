include(joinpath(@__DIR__, "..", "pseudo.jl"))
using .Pseudo
src = "mostrar 7\nusar Python.numpy\nmostrar Python.numpy.mean([1,2,3])"
code = Pseudo.generate(Pseudo.parse_program(Pseudo.tokenize(src)))
@assert !occursin("@eval import PythonCall", code)
@assert occursin("abt_load_pythoncall!(__abt_pythoncall_cache__).pyimport", code)
@assert first(findfirst("abt_std_render(7)", code)) < first(findfirst("abt_import_python!(Python", code))
plain = Pseudo.generate(Pseudo.parse_program(Pseudo.tokenize("mostrar 7")))
@assert !occursin("PythonCall", plain)
println("Static 0.10.4 regression checks updated for 0.10.6")
