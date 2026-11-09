using Test
include(joinpath(@__DIR__, "..", "pseudo.jl"))
using .Pseudo

function compiled(src)
    ast = parse_program(tokenize(src))
    ir = validate_ir(lower_ir(ast))
    return ast, generate(ir)
end

@testset "ABT 0.8.1 — bibliotecas Julia" begin
    src = read(joinpath(@__DIR__, "..", "examples", "julia_libraries.pseudo"), String)
    ast, generated = compiled(src)
    @test execute(ast) == ["[1, 2, 2, 3]", "[3, 1, 2]", "8", "2.0", "2.0", "5.0", "11", "1.0"]
    @test split(strip(read(`$(Base.julia_cmd()) --startup-file=no -e $generated`, String)), '\n') == execute(ast)
    for (code, needle) in [
        ("usar Julia.Foo", "unsupported"),
        ("usar Julia.Base\nmostrar Julia.Base.eval(1)", "unsupported external function"),
        ("mostrar Julia.Base.sum([1,2])", "not imported"),
        ("usar Julia.LinearAlgebra\nmostrar Julia.LinearAlgebra.dot([1,2])", "expects 2"),
        ("usar Julia.Statistics\nmostrar Julia.Statistics.mean([1,2], [3,4])", "expects 1"),
        ("usar Julia.Base\nmostrar Julia.Base.sort([1], [2])", "expects 1"),
    ]
        err = try
            compiled(code)
            nothing
        catch e
            e
        end
        @test err isa Exception
        @test occursin(needle, sprint(showerror, err))
    end
    # Each module must be explicitly imported; importing another is insufficient.
    @test_throws Exception compiled("usar Julia.Base\nmostrar Julia.Statistics.mean([1,2])")
end
