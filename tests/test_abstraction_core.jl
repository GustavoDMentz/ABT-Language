using Test
include(joinpath(@__DIR__, "..", "pseudo.jl"))
using .Pseudo

function count_generated_output(source; optimize=true)
    code = generate(parse_program(tokenize(source)); optimize)
    strip(read(`$(Base.julia_cmd()) --startup-file=no -e $code`, String))
end

function validate_count_source(source)
    validate_ir(lower_ir(parse_program(tokenize(source))))
end

@testset "contar: contrato de lista ABT" begin
    @test ABT.abt_std_count(Int[]) === Int64(0)
    @test ABT.abt_std_count([1, "x", missing]) === Int64(3)
    @test typeof(ABT.abt_std_count([1])) === Int64
    @test_throws ErrorException ABT.abt_std_count("abc")
    @test_throws ErrorException ABT.abt_std_count((; valor=1))
    table = ABT.abt_std_table(Iterators.repeated((; valor=1)), ["valor"], ["inteiro"], "teste")
    @test_throws ErrorException ABT.abt_std_count(table)

    @test Pseudo.execute(parse_program(tokenize("mostrar contar([])\nmostrar contar([1, 2, 3])"))) == ["0", "3"]
    for optimized in (false, true)
        @test count_generated_output("mostrar contar([])\nmostrar contar([1, 2, 3])"; optimize=optimized) == "0\n3"
    end

    filtered = "mostrar contar(filtrar([1, 2, 3, 4]) onde valor > 2)"
    @test Pseudo.execute(parse_program(tokenize(filtered))) == ["2"]
    for optimized in (false, true)
        @test count_generated_output(filtered; optimize=optimized) == "2"
    end

    pipeline = "[1, 2, 3, 4]\n  filtrar onde valor > 2\n  mostrar"
    @test Pseudo.execute(parse_program(tokenize(pipeline))) == ["[3, 4]"]
    for optimized in (false, true)
        @test count_generated_output(pipeline; optimize=optimized) == "[3, 4]"
    end

    @test_throws ErrorException validate_count_source("mostrar contar()")
    @test_throws ErrorException validate_count_source("mostrar contar([1], [2])")
    @test_throws ErrorException validate_count_source("mostrar contar(\"texto\")")
    @test_throws ErrorException Pseudo.execute(parse_program(tokenize("mostrar contar(registro(\"x\", 1))")))
end
