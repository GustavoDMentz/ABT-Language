include("pseudo.jl")
using .Pseudo
using Test

@testset "ABT 0.10.0 static namespace identity" begin
    src = "usar Python.numpy\nmostrar Python.numpy"
    generated = generate(parse_program(tokenize(src)))
    @test occursin("abt_namespace_token = Ref{Nothing}(nothing)", generated)
    @test occursin("obj.token === abt_namespace_token", generated)
    @test !occursin("obj isa NamedTuple && haskey(obj, :modules) && haskey(obj, :prefix)", generated)
end
