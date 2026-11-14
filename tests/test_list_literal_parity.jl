using Test
include(joinpath(@__DIR__, "..", "pseudo.jl"))
using .Pseudo

# Um literal de lista deve preservar o tipo de cada elemento nos três modos.
# Antes, a Julia gerada promovia `[1, 1.0]` a Float64 enquanto o interpretador
# preservava `[1, 1.0]`.
const SOURCE = """
x = 2
mostrar [1, 1.0]
mostrar [1, 2.5, x]
mostrar [x, x + 0.5]
mostrar [1, "a", verdadeiro]
mostrar [[1], [2.0, 3]]
mostrar []
mostrar [1, 2, 3]
mostrar [1.5, 2.5]
mostrar soma de [1, 2.5]
mostrar media de [1, 2.5]
mostrar descrever([1, 2.5, 3])
mostrar transformar [1, 2.5] com valor * 2
"""

@testset "Literais de lista: paridade de tipos entre backends" begin
    program = parse_program(tokenize(SOURCE))
    expected = execute(program)
    @test expected[1] == "[1, 1.0]"
    @test expected[2] == "[1, 2.5, 2]"
    for optimize in (false, true)
        code = generate(program; optimize)
        output = split(strip(read(`$(Base.julia_cmd()) --startup-file=no -e $code`, String)), '\n')
        @test output == expected
    end
end
