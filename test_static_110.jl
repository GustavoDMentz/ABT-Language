include("pseudo.jl")
using .Pseudo

# Reject constants that cannot be emitted faithfully as Julia source.
for value in (Dict("a" => 1), [1,2], 1//2, :symbol)
    program = [Pseudo.ir(:print, Pseudo.ir(:constant, value))]
    for generator in (Pseudo.generate_ir, Pseudo.generate)
        try
            generator(program)
            error("REGRESSION: unsupported literal accepted: $(typeof(value))")
        catch err
            occursin("REGRESSION", sprint(showerror, err)) && rethrow()
            occursin("unsupported IR constant", sprint(showerror, err)) || rethrow()
        end
    end
end
for value in (nothing, true, false, "a\nb", Int64(-4), Float64(-0.0), NaN, Inf, -Inf)
    program = [Pseudo.ir(:print, Pseudo.ir(:constant, value))]
    generated = Pseudo.generate_ir(program)
    Meta.parse(generated) # syntax check, not execution
end
# Regression: dollar signs in generated helper must survive template construction.
program = [Pseudo.ir(:import_python, "math")]
generated = Pseudo.generate_ir(program)
@assert occursin("atributo privado não permitido: \$field", generated)
@assert occursin("caminho de módulo inválido: \$path", generated)
Meta.parse(generated)
println("ABT 0.11.0: static regressions passed")
