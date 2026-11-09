include("pseudo.jl")
using .Pseudo
@assert !isdefined(Pseudo, :PythonCall)
src = "usar Python.math\nmostrar Python.math.sqrt(9)"
code = Pseudo.generate(Pseudo.parse_program(Pseudo.tokenize(src)))
init = findfirst("__abt_pythoncall_cache__ = Ref{Any}(nothing)", code)
check = findfirst("abt_load_pythoncall!(__abt_pythoncall_cache__).pyimport", code)
@assert init !== nothing && check !== nothing && first(init) < first(check)
println("Static 0.10.5 regression checks updated for 0.10.6")
