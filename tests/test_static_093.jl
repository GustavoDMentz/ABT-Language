using Test
include(joinpath(@__DIR__, "..", "pseudo.jl"))
using .Pseudo

struct PlusOne end
(::PlusOne)(x) = x + 1

@testset "ABT 0.9.3 — static guards and callable dispatch" begin
    plain = Pseudo.generate(Pseudo.parse_program(Pseudo.tokenize("mostrar 1")))
    @test !occursin("struct ABTPythonNamespace", plain)
    @test !occursin("import PythonCall", plain)
    @test occursin("abt_invoke(fn, args...)", plain)

    py = Pseudo.generate(Pseudo.parse_program(Pseudo.tokenize("usar Python.numpy\nmostrar Python.numpy.sum([1,2])")))
    @test occursin("function abt_import_python!", py)
    @test occursin("abt_load_pythoncall!", py)

    src = Pseudo.parse_program(Pseudo.tokenize("mostrar f(2)"))
    @test Pseudo.execute(src; env=Dict{String,Any}("f" => PlusOne())) == ["3"]
    @test_throws Exception Pseudo.execute(src; env=Dict{String,Any}("f" => 3))
    @test_throws Exception Pseudo.generate(Pseudo.parse_program(Pseudo.tokenize("mostrar ausente(2)")))
    @test_throws Exception Pseudo.generate(Pseudo.parse_program(Pseudo.tokenize("x = 3\nmostrar x(2)")))
end
