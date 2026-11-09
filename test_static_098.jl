include("pseudo.jl")
using .Pseudo

function must_reject(src, fragment)
    try
        generate(parse_program(tokenize(src)))
    catch e
        @assert occursin(fragment, sprint(showerror, e)) (src, e)
        return
    end
    error("Unexpected static acceptance: " * src)
end
must_reject("mostrar Julia", "undefined variable")
must_reject("usar Julia.Statistics\nmostrar Julia", "cannot be used as a value")
must_reject("mostrar Python.numpy.mean([1,2,3])\nusar Python.numpy", "before import")
must_reject("usar Python.numpy\nmostrar Python", "cannot be used as a value")
must_reject("usar Julia.Statistics\nmostrar Julia.Statistics", "require module and function")
must_reject("usar Julia.Statistics\nmostrar Julia.Statistics.nonexistent", "unsupported Julia reference")

src = "usar Julia.Statistics\nmostrar Julia.Statistics.mean([1,2,3])"
@assert occursin("Statistics.mean", generate(parse_program(tokenize(src))))
println("0.9.8 static namespace regressions passed")
