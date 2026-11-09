include("pseudo.jl")
using .Pseudo

# Public entrypoints must reject malformed IR consistently, without internal exceptions.
bad = [
    Pseudo.ir(:print),
    Pseudo.ir(:store, "x"),
    Pseudo.ir(:print, Pseudo.ir(:binary, "+", Pseudo.ir(:constant, 1))),
    Pseudo.ir(:print, Pseudo.ir(:call, Pseudo.ir(:load, "f"), "not a list")),
    Pseudo.ir(:print, Pseudo.ir(:field, Pseudo.ir(:load, "x"), 123)),
    Pseudo.ir(:branch, Pseudo.ir(:constant, true), 12, Pseudo.IR[]),
    Pseudo.ir(:function, "f", ["x", 2], Pseudo.IR[]),
    Pseudo.ir(:print, Pseudo.ir(:aggregate, :invalid, Pseudo.ir(:list, Pseudo.IR[]), nothing)),
]
for broken in bad, generator in (Pseudo.generate_ir, Pseudo.generate)
    try
        generator(Pseudo.IR[broken])
        error("REGRESSION: malformed IR accepted")
    catch err
        message = sprint(showerror, err)
        occursin("REGRESSION", message) && rethrow()
        occursin("Semantic error: malformed IR", message) || rethrow()
    end
end
# Well-formed IR must still generate code.
program = Pseudo.IR[Pseudo.ir(:store, "x", Pseudo.ir(:constant, 4)),
                    Pseudo.ir(:print, Pseudo.ir(:load, "x"))]
Meta.parse(Pseudo.generate(program))
println("ABT 0.11.1 structural IR regressions passed")
