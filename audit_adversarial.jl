using Test
include("pseudo.jl")
using .Pseudo
compile_abt(s) = generate(validate_ir(lower_ir(parse_program(tokenize(s)))))
function probe(name, src; expect_reject=false)
    println("\n=== ", name, " ===")
    try
        code = compile_abt(src)
        println("COMPILES; generated relevant lines:")
        for line in split(code, '\n')
            (occursin("__abt_py",line) || occursin("PythonCall",line) || occursin("getproperty",line)) && println("  ",line)
        end
        expect_reject && println("FINDING: accepted code that should be rejected by a strict boundary")
    catch e
        println("REJECTED: ", sprint(showerror,e))
        !expect_reject && println("FINDING: valid-looking code rejected or unsupported")
    end
end
probe("Nested Python import: generated namespace mapping", "usar Python.Bio.Seq\nmostrar Python.Bio.Seq.Seq(\"ACGT\")")
probe("Python module root collision", "usar Python.numpy\nusar Python.numpy.linalg\nmostrar Python.numpy.linalg.norm([3,4])")
probe("Indirect function reference", "usar Python.numpy\nf = Python.numpy.sum\nmostrar f([1,2,3])")
probe("External object method", "usar Python.numpy\na = Python.numpy.array([1,2])\nmostrar a.sum()")
probe("Rebinding reserved namespace", "usar Python.numpy\nPython = 3\nmostrar Python.numpy.sum([1])"; expect_reject=true)
probe("Private attribute via dynamic lookup", "usar Python.builtins\nmostrar Python.builtins.getattr(Python.builtins, \"__dict__\")"; expect_reject=true)
probe("Arbitrary code via generic import", "usar Python.os\nmostrar Python.os.system(\"true\")"; expect_reject=true)
println("\nNOTE: This is an audit probe, not a passing regression suite. Inspect findings and run optional runtime comparisons.")
