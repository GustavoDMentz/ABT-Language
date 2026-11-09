using Test
include(joinpath(@__DIR__, "..", "pseudo.jl"))
using .Pseudo

parse(src) = Pseudo.parse_program(Pseudo.tokenize(src))
compile(src) = Pseudo.generate(parse(src))
@testset "ABT 0.9.4 static adversarial" begin
    @test_throws Exception compile("função f(x) { retornar x }\nf = 7\nmostrar f(1)")
    @test_throws Exception compile("f = 7\nfunção f(x) { retornar x }")
    @test_throws Exception compile("função f(x) { retornar x }\nfunção g(f) { retornar f }")
    @test_throws Exception compile("função f(x) { retornar x }\npara cada f em [1] { mostrar f }")
    @test_throws Exception compile("se verdadeiro { função f(x) { retornar x } }")
    @test_throws Exception parse("__abt_output__ = 7")
    @test_throws Exception compile("mostrar inexistente(2)")
    @test Pseudo.execute(parse("mostrar dobro(3)\nfunção dobro(x) { retornar x * 2 }")) == ["6"]
    @test occursin("function __abt_user_", compile("mostrar dobro(3)\nfunção dobro(x) { retornar x * 2 }"))
    @test Pseudo.execute(parse("end = 3\nmostrar end")) == ["3"]
    @test !occursin(r"(?m)^end =", compile("end = 3\nmostrar end"))
    @test occursin("__abt_user_656e64", compile("end = 3\nmostrar end"))
    @test Pseudo.execute(parse("função f(x) { retornar x }\ng = f\nmostrar g(5)")) == ["5"]
    @test occursin("__abt_user_", compile("média = [1, 2, 3]\nmostrar soma de média"))
end
