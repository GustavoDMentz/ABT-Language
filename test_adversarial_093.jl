using Test
include("pseudo.jl")
using .Pseudo
const P = Pseudo

@testset "ABT adversarial 0.9.2 — isolated bridge, no Python required" begin
    # Parent/submodule collision and repeat import; use mock importer.
    ns = P.ABTPythonNamespace()
    calls = String[]
    importer(path) = (push!(calls,path); path == "pkg" ? Dict("value" => 7) : path == "pkg.sub" ? Dict("value" => 11) : error("missing"))
    P.abt_import_python!(ns, "pkg.sub", importer)
    P.abt_import_python!(ns, "pkg", importer)
    @test P.abt_external_field(P.abt_external_field(ns,"pkg"),"value") == 7
    @test P.abt_external_field(P.abt_external_field(P.abt_external_field(ns,"pkg"),"sub"),"value") == 11
    @test_throws Exception P.abt_import_python!(ns, "pkg.missing", importer)
    @test !haskey(ns.modules, "pkg.missing")
    @test_throws Exception P.abt_import_python!(ns, "pkg.__secret", importer)
    @test_throws Exception P.abt_external_field(ns, "__class__")
end

@testset "ABT adversarial 0.9.2 — generated code structural checks" begin
    for src in [
        "mostrar 1",
        "usar Python.numpy\nmostrar Python.numpy.sum([1,2,3])",
        "usar Python.numpy.linalg\nusar Python.numpy\nmostrar Python.numpy.linalg.norm([3,4])",
    ]
        code = P.generate(P.parse_program(P.tokenize(src)))
        if occursin("usar Python", src)
            @test occursin("function abt_import_python!", code)
            @test occursin("abt_invoke(fn, args...)", code)
        else
            @test !occursin("struct ABTPythonNamespace", code)
            @test occursin("abt_invoke(fn, args...)", code)
        end
        @test !occursin("include(\"bridge_runtime.jl\")", code)
    end
end

struct LocalCallable end
(::LocalCallable)(x) = x + 1

@testset "ABT adversarial 0.9.2 — callable objects and import semantics" begin
    # Julia callable structs are valid callables; current interpreter rejects them.
    source = "mostrar f(2)"
    ast = P.parse_program(P.tokenize(source))
    @test P.execute(ast; env=Dict{String,Any}("f" => LocalCallable())) == ["3"]
end
