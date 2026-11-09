include("pseudo.jl")
using .Pseudo
# Direct IR codegen must reject an undefined variable.
invalid = [Pseudo.ir(:print, Pseudo.ir(:load, "not_defined"))]
try
    Pseudo.generate_ir(invalid)
    error("REGRESSION: generate_ir accepted invalid IR")
catch err
    occursin("REGRESSION", sprint(showerror, err)) && rethrow()
end
# Both public entrypoints should reject the same IR.
try
    Pseudo.generate(invalid)
    error("REGRESSION: generate accepted invalid IR")
catch err
    occursin("REGRESSION", sprint(showerror, err)) && rethrow()
end
println("ABT 0.10.9: IR boundary regression checks passed")
