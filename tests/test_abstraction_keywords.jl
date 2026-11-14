using Test
include(joinpath(@__DIR__, "..", "pseudo.jl"))
using .Pseudo

const UPPERCASE_SOURCE = """
MOSTRAR AVERAGE OF [2, 4]
MOSTRAR MÉDIA DE [2, 4]
MOSTRAR 2 IS 2
MOSTRAR 3 IS ABOVE 2
MOSTRAR TRUE AND FALSE
MOSTRAR FALSE OR TRUE
MOSTRAR 2 É MAIOR QUE 1
MOSTRAR SOMA DE [2, 4]
"""

@testset "Palavras-chave aceitas preservam a semântica em qualquer caixa" begin
    expected = ["3.0", "3.0", "true", "true", "false", "true", "true", "6"]
    program = parse_program(tokenize(UPPERCASE_SOURCE))
    @test execute(program) == expected
    for optimized in (false, true)
        code = generate(program; optimize=optimized)
        output = split(strip(read(`$(Base.julia_cmd()) --startup-file=no -e $code`, String)), '\n')
        @test output == expected
    end
end
