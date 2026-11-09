include("pseudo.jl")
using .Pseudo
src = "usar Python.math\nmostrar Python.math.sqrt(9)"
code = Pseudo.generate(Pseudo.parse_program(Pseudo.tokenize(src)))
@assert occursin("catch err", code)
@assert occursin("Interop Python indisponível: verifique PythonCall.jl. Causa:", code)
@assert occursin("sprint(showerror, err)", code)
@assert occursin("cache[] = Base.invokelatest(getfield, deps, :PythonCall)", code)
@assert !occursin("@eval import PythonCall", code)
println("Static 0.10.7 checks OK")
