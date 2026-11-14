using Test
include(joinpath(@__DIR__, "..", "pseudo.jl"))
using .Pseudo

# Paridade interpretador / Julia gerada (sem e com otimização) para as operações
# fundamentais de lista e as conversões explícitas.
function generated_output(source; optimize)
    code = generate(parse_program(tokenize(source)); optimize)
    strip(read(`$(Base.julia_cmd()) --startup-file=no -e $code`, String))
end
interpreted(source) = join(execute(parse_program(tokenize(source))), "\n")
validate_source(source) = validate_ir(lower_ir(parse_program(tokenize(source))))

function parity(source, expected)
    @test interpreted(source) == expected
    for optimize in (false, true)
        @test generated_output(source; optimize) == expected
    end
end
function generated_fails(source, fragment; optimize)
    code = generate(parse_program(tokenize(source)); optimize)
    err = IOBuffer()
    ok = success(pipeline(ignorestatus(`$(Base.julia_cmd()) --startup-file=no -e $code`); stderr=err)) &&
         !occursin("ERROR", String(take!(copy(err))))
    return occursin(fragment, String(take!(err)))
end
function fails_everywhere(source, fragment)
    err = try interpreted(source); nothing catch e; sprint(showerror, e) end
    @test err !== nothing && occursin(fragment, err)
    for optimize in (false, true)
        @test generated_fails(source, fragment; optimize)
    end
end

@testset "minimo e maximo" begin
    parity("mostrar minimo([3, 1, 2])\nmostrar maximo([3, 1, 2])", "1\n3")
    parity("mostrar minimo([2.5, 1.5, 3.5])\nmostrar maximo([2.5, 1.5, 3.5])", "1.5\n3.5")
    parity("mostrar minimo([2, 1.5, 3])\nmostrar maximo([2, 2.5, 1])", "1.5\n2.5")
    # Empate numérico: vence a primeira ocorrência, preservando seu tipo.
    parity("mostrar minimo([1, 1.0])\nmostrar maximo([1.0, 1])", "1\n1.0")
    parity("mostrar maximo(filtrar [1, 5, 9] onde valor < 9)", "5")
    fails_everywhere("mostrar minimo([])", "lista vazia")
    fails_everywhere("mostrar maximo([\"a\", \"b\"])", "números finitos")
    fails_everywhere("mostrar minimo([1, 0.0 / 0.0])", "números finitos")
    fails_everywhere("mostrar maximo(registro(\"x\", 1))", "esperada uma lista")
    @test_throws ErrorException validate_source("mostrar minimo()")
    @test_throws ErrorException validate_source("mostrar maximo([1], [2])")
    @test_throws ErrorException validate_source("mostrar minimo(\"texto\")")
end

@testset "ordenar" begin
    parity("mostrar ordenar([3, 1, 2])\nmostrar ordenar([3, 1, 2], \"decrescente\")", "[1, 2, 3]\n[3, 2, 1]")
    parity("mostrar ordenar([\"b\", \"a\", \"c\"])", "[\"a\", \"b\", \"c\"]")
    parity("mostrar ordenar([2, 1.5, 1])", "[1, 1.5, 2]")
    # Estabilidade: valores iguais de tipos distintos mantêm a ordem original.
    parity("mostrar ordenar([1.0, 1, 0])", "[0, 1.0, 1]")
    parity("mostrar ordenar([1, 1.0], \"decrescente\")", "[1, 1.0]")
    parity("mostrar ordenar([])", "[]")
    parity("mostrar contar(ordenar(filtrar [3, 1, 2] onde valor > 1))", "2")
    fails_everywhere("mostrar ordenar([1, \"a\"])", "só de números")
    fails_everywhere("mostrar ordenar([1, 2], \"asc\")", "direção")
    # Texto vindo de `ambiente` tem tipo estático desconhecido: o erro ocorre na execução.
    fails_everywhere("mostrar ordenar(ambiente(\"ABT_VARIAVEL_INEXISTENTE\", \"abc\"))", "esperada uma lista")
    @test_throws ErrorException validate_source("mostrar ordenar(\"abc\")")
    @test_throws ErrorException validate_source("mostrar ordenar()")
    @test_throws ErrorException validate_source("mostrar ordenar([1], \"crescente\", 3)")
    @test_throws ErrorException validate_source("mostrar ordenar([1], 3)")
end

@testset "sem_duplicatas" begin
    parity("mostrar sem_duplicatas([3, 1, 3, 2, 1])", "[3, 1, 2]")
    parity("mostrar sem_duplicatas([\"a\", \"b\", \"a\"])", "[\"a\", \"b\"]")
    # Igualdade `isequal`: 1 e 1.0 são iguais (vence a primeira ocorrência); 0.0 e -0.0 são distintos.
    parity("mostrar sem_duplicatas([1, 1.0, 1])", "[1]")
    parity("mostrar sem_duplicatas([1.0, 1])", "[1.0]")
    parity("mostrar sem_duplicatas([0.0, -0.0])", "[0.0, -0.0]")
    parity("mostrar sem_duplicatas([[1], [1], [2]])", "[[1], [2]]")
    parity("mostrar sem_duplicatas([])", "[]")
    fails_everywhere("mostrar sem_duplicatas(ambiente(\"ABT_VARIAVEL_INEXISTENTE\", \"aab\"))", "esperada uma lista")
    @test_throws ErrorException validate_source("mostrar sem_duplicatas()")
end

@testset "conversões explícitas" begin
    parity("mostrar para_inteiro(\"42\")\nmostrar para_inteiro(3.0)\nmostrar para_inteiro(-7)", "42\n3\n-7")
    parity("mostrar para_real(\"2.5\")\nmostrar para_real(2)\nmostrar para_real(\"1e3\")", "2.5\n2.0\n1000.0")
    parity("mostrar para_texto(3)\nmostrar para_texto(2.5)\nmostrar para_texto(verdadeiro)\nmostrar para_texto(\"x\")", "3\n2.5\ntrue\nx")
    parity("mostrar soma de transformar [\"1\", \"2\"] com para_inteiro(valor)", "3")
    fails_everywhere("mostrar para_inteiro(2.5)", "não é um inteiro")
    fails_everywhere("mostrar para_inteiro(\"2.5\")", "texto inválido")
    fails_everywhere("mostrar para_inteiro(\" 2\")", "texto inválido")
    fails_everywhere("mostrar para_inteiro(\"99999999999999999999\")", "fora da faixa")
    fails_everywhere("mostrar para_inteiro(verdadeiro)", "esperado inteiro")
    fails_everywhere("mostrar para_real(\"abc\")", "texto inválido")
    fails_everywhere("mostrar para_real(\"1e999\")", "fora da faixa")
    fails_everywhere("mostrar para_real(verdadeiro)", "esperado inteiro")
    fails_everywhere("mostrar para_real(9007199254740993)", "não é exato")
    fails_everywhere("mostrar para_texto([1])", "esperado texto")
    @test_throws ErrorException validate_source("mostrar para_inteiro()")
    @test_throws ErrorException validate_source("mostrar para_real(1, 2)")
    @test_throws ErrorException validate_source("mostrar para_texto()")
end

@testset "compatibilidade: ponte Julia explícita continua disponível" begin
    parity("usar Julia.Base\nmostrar Julia.Base.sort([3, 1, 2])\nmostrar Julia.Base.unique([1, 1])", "[1, 2, 3]\n[1]")
    # Identificadores de usuário com os novos nomes continuam válidos.
    parity("minimo = 5\nmostrar minimo + 1", "6")
    parity("função ordenar(x) { retornar x }\nmostrar ordenar(2)", "2")
end
