using Test
include(joinpath(@__DIR__, "..", "pseudo.jl"))
using .Pseudo

@testset "ABT 0.8 — interoperabilidade Julia Statistics" begin
    source = read(joinpath(@__DIR__, "..", "examples", "julia_statistics.pseudo"), String)
    ast = parse_program(tokenize(source))
    ir = validate_ir(lower_ir(ast))
    @test execute(ast) == ["25.0"]
    generated = generate(ir)
    @test strip(read(`$(Base.julia_cmd()) --startup-file=no -e $generated`, String)) == "25.0"
    @test_throws Exception validate_ir(lower_ir(parse_program(tokenize("mostrar Julia.Statistics.mean([1,2])"))))
    @test_throws Exception validate_ir(lower_ir(parse_program(tokenize("usar Julia.Statistics\nmostrar Julia.Statistics.mean([1,2], [3,4])"))))
    @test_throws Exception parse_program(tokenize("usar Julia.Foo"))
end
