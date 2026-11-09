using Test
include(joinpath(@__DIR__, "..", "pseudo.jl"))
using .Pseudo

const B = Pseudo
compile092(s) = generate(parse_program(tokenize(s)))

@testset "ABT 0.9.2 — namespace adversarial without Python" begin
    ns = B.ABTPythonNamespace()
    registry = Dict("numpy" => Dict("sum" => sum), "numpy.linalg" => Dict("norm" => x -> sum(abs2, x)^0.5))
    importer(path) = get(registry, path) do; error("missing $path"); end
    B.abt_import_python!(ns, "numpy", importer)
    B.abt_import_python!(ns, "numpy.linalg", importer)
    @test B.abt_external_field(B.abt_external_field(ns, "numpy"), "sum")([1,2,3]) == 6
    @test B.abt_external_field(B.abt_external_field(B.abt_external_field(ns, "numpy"), "linalg"), "norm")([3,4]) == 5
    B.abt_import_python!(ns, "numpy", importer)
    @test length(ns.modules) == 2
    @test_throws Exception B.abt_import_python!(ns, "numpy.missing", importer)
    @test !haskey(ns.modules, "numpy.missing")
    @test_throws Exception B.abt_external_field(ns, "__dict__")
    @test_throws Exception B.abt_import_python!(ns, "numpy.__private", importer)
    ns2 = B.ABTPythonNamespace()
    B.abt_import_python!(ns2, "numpy.linalg", importer)
    B.abt_import_python!(ns2, "numpy", importer)
    @test B.abt_external_field(B.abt_external_field(ns2, "numpy"), "sum")([1,2]) == 3
end

@testset "ABT 0.9.2 — generated bridge and validation" begin
    for source in [
        "usar Python.numpy\nusar Python.numpy.linalg\nmostrar Python.numpy.linalg.norm([3,4])",
        "usar Python.numpy.linalg\nusar Python.numpy\nmostrar Python.numpy.sum([1,2])",
        "usar Python.Bio.Seq\nmostrar Python.Bio.Seq.Seq(\"ACGT\")",
        "usar Python.numpy\nf = Python.numpy.sum\nmostrar f([1,2,3])",
        "usar Python.numpy\na = Python.numpy.array([1,2])\nmostrar a.sum()",
    ]
        generated = compile092(source)
        @test occursin("function abt_import_python!", generated)
        @test occursin("Python = abt_namespace(", generated)
        @test occursin("abt_invoke(", generated)
        @test findfirst("function abt_import_python!", generated).start < findfirst("Python = abt_namespace(", generated).start
    end
    for source in [
        "usar Python.numpy\nPython = 4",
        "usar Python.numpy\nmostrar Python.numpy.__dict__",
        "usar Python.numpy\nmostrar Python.numpy.pi()", # dynamic: allowed statically, must fail at runtime
    ][1:2]
        @test_throws Exception compile092(source)
    end
    @test occursin("abt_invoke(fn, args...)", compile092("mostrar 1"))
    @test !occursin("struct ABTPythonNamespace", compile092("mostrar 1"))
end

@testset "ABT 0.9.2 — Python differential mandatory if requested" begin
    available = try
        @eval import PythonCall
        PythonCall.pyimport("numpy")
        true
    catch e
        @info "PythonCall/NumPy unavailable" exception=(e, catch_backtrace())
        false
    end
    if !available
        if get(ENV, "ABT_REQUIRE_PYTHON", "0") == "1"
            @test available
        else
            @test_skip available
        end
    else
        cases = [
            "usar Python.numpy\nusar Python.numpy.linalg\nmostrar Python.numpy.sum([1,2,3])",
            "usar Python.numpy.linalg\nusar Python.numpy\nmostrar Python.numpy.linalg.norm([3,4])",
            "usar Python.numpy\nf = Python.numpy.sum\nmostrar f([1,2,3])",
            "usar Python.numpy\na = Python.numpy.array([1,2,3])\nmostrar a.sum()",
            "usar Python.numpy\nmostrar Python.numpy.sum([1,2,3])",
        ]
        for source in cases
            ast = parse_program(tokenize(source))
            expected = join(execute(ast), "\n")
            path = tempname() * ".jl"
            try
                write(path, compile092(source))
                actual = read(`$(Base.julia_cmd()) --startup-file=no $path`, String)
                @test strip(actual) == strip(expected)
            finally
                rm(path; force=true)
            end
        end
        bad = "usar Python.numpy\nmostrar Python.numpy.pi()"
        @test_throws Exception execute(parse_program(tokenize(bad)))
    end
end
