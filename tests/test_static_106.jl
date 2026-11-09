include(joinpath(@__DIR__, "..", "pseudo.jl"))
using .Pseudo
@assert !isdefined(Pseudo, :PythonCall)
src = "usar Python.math\nmostrar Python.math.sqrt(9)"
code = Pseudo.generate(Pseudo.parse_program(Pseudo.tokenize(src)))
@assert occursin("abt_load_pythoncall!(__abt_pythoncall_cache__).pyimport", code)
@assert !occursin("__abt_pythoncall_module__", code)
@assert occursin("__abt_pythoncall_cache__ = Ref{Any}(nothing)", code)
@assert !occursin("sys.modules", code)
println("Static 0.10.6 checks OK")
