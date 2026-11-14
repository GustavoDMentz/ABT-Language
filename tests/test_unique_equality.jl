using Test
using Random
include(joinpath(@__DIR__, "..", "pseudo.jl"))
using .Pseudo

# Contrato de `sem_duplicatas`: dois elementos são duplicados quando são iguais segundo o
# operador `==` da própria ABT (não segundo `isequal` de Julia). Este teste compara
# Julia (`==` e `isequal`), o interpretador e a Julia gerada (sem e com otimização).

# Matriz de casos: (expressão A, expressão B). Para cada par o programa mostra `A == B` e
# o tamanho de sem_duplicatas([A, B]); a regra é: tamanho 1 se `==` for verdadeiro, 2 caso contrário.
const CASES = [
    ("1", "1.0"), ("0.0", "-0.0"), ("0.0 / 0.0", "0.0 / 0.0"), ("verdadeiro", "1"), ("falso", "0"),
    ("[1]", "[1.0]"), ("[0.0]", "[-0.0]"), ("[0.0 / 0.0]", "[0.0 / 0.0]"), ("[1, [2.0]]", "[1.0, [2]]"),
    ("registro(\"a\", 1)", "registro(\"a\", 1.0)"), ("registro(\"a\", 1)", "registro(\"b\", 1)"),
    ("\"a\"", "\"a\""), ("\"a\"", "\"A\""), ("\"1\"", "1"),
    ("9007199254740993", "9007199254740992.0"), ("9007199254740992", "9007199254740992.0"),
    ("1.0 / 0.0", "1.0 / 0.0"), ("-1.0 / 0.0", "1.0 / 0.0"), ("2", "3"), ("[]", "[]"),
]
program = join(("mostrar $a == $b\nmostrar contar(sem_duplicatas([$a, $b]))" for (a, b) in CASES), "\n")
# `contar` vem do mesmo PR; mantém a consulta no próprio idioma ABT.

interpreted(source) = split(join(execute(parse_program(tokenize(source))), "\n"), "\n")
function generated(source; optimize)
    code = generate(parse_program(tokenize(source)); optimize)
    split(strip(read(`$(Base.julia_cmd()) --startup-file=no -e $code`, String)), "\n")
end

@testset "sem_duplicatas segue o == da ABT nos três modos" begin
    reference = interpreted(program)
    for (i, (a, b)) in enumerate(CASES)
        equal = reference[2i - 1] == "true"
        @test reference[2i] == (equal ? "1" : "2")          # o contrato
    end
    # casos explicitamente discutidos
    index(a, b) = findfirst(==((a, b)), CASES)
    @test reference[2index("1", "1.0")] == "1"
    @test reference[2index("0.0", "-0.0")] == "1"           # 0.0 == -0.0
    @test reference[2index("0.0 / 0.0", "0.0 / 0.0")] == "2" # NaN != NaN: nenhum NaN é removido
    @test reference[2index("[0.0 / 0.0]", "[0.0 / 0.0]")] == "2"
    @test reference[2index("verdadeiro", "1")] == "1"
    @test reference[2index("9007199254740993", "9007199254740992.0")] == "2"   # igualdade exata, sem arredondar
    @test reference[2index("\"1\"", "1")] == "2"            # texto nunca é igual a número
    for optimize in (false, true)
        @test generated(program; optimize) == reference
    end
end

@testset "sem_duplicatas: valores devolvidos, ordem e primeira ocorrência" begin
    run(src) = join(execute(parse_program(tokenize(src))), "|")
    @test run("mostrar sem_duplicatas([-0.0, 0.0])") == "[-0.0]"
    @test run("mostrar sem_duplicatas([0.0, -0.0, 0.0])") == "[0.0]"
    @test run("mostrar sem_duplicatas([1.0, 1, 1.0])") == "[1.0]"
    @test run("mostrar sem_duplicatas([2, 1, 2.0, 1.0, 3])") == "[2, 1, 3]"
    @test run("mostrar sem_duplicatas([0.0 / 0.0, 1, 0.0 / 0.0])") == "[NaN, 1, NaN]"
    @test run("mostrar sem_duplicatas([registro(\"a\", 1), registro(\"a\", 1.0)])") == "[(a = 1,)]"
end

@testset "sem_duplicatas: ausentes e tipos não numéricos" begin
    # `missing` não tem literal ABT; chega por CSV. Ausentes são iguais entre si (como em remover_duplicatas).
    result = ABT.abt_std_unique(Any[missing, 1, missing, 2])
    @test length(result) == 3 && ismissing(result[1]) && result[2:3] == [1, 2]
    @test ABT.abt_std_unique(Any["a", "a"]) == Any["a"]
    @test_throws ErrorException ABT.abt_std_unique("aab")
    @test_throws ErrorException ABT.abt_std_unique((; a=1))
end

# Oráculo independente: varredura quadrática com `==` de Julia (sem hash, sem isequal).
function brute_force(values)
    kept = Any[]
    for x in values
        any(y -> (ismissing(x) && ismissing(y)) || (!ismissing(x) && !ismissing(y) && (x == y) === true), kept) || push!(kept, x)
    end
    return kept
end
same_result(a, b) = length(a) == length(b) && all(((x, y),) -> (ismissing(x) && ismissing(y)) || (x isa Float64 && y isa Float64 && isnan(x) && isnan(y)) || (x === y) || isequal(x, y), zip(a, b))

@testset "sem_duplicatas contra oráculo de varredura com ==" begin
    rng = MersenneTwister(1411)
    pool = Any[0, 1, 2, -1, 0.0, -0.0, 1.0, 2.0, 2.5, NaN, Inf, -Inf, true, false, "a", "A", "1", 9007199254740993, 9007199254740992.0,
               9007199254740992, [1], [1.0], [0.0], [-0.0], [NaN], Any[1, "a"], Any[1.0, "a"], (a=1,), (a=1.0,), (b=1,), missing]
    for _ in 1:400
        values = Any[rand(rng, pool) for _ in 1:rand(rng, 0:14)]
        @test same_result(ABT.abt_std_unique(values), brute_force(values))
    end
    # a saída é uma subsequência da entrada (ordem relativa preservada, nada novo)
    values = Any[rand(rng, pool) for _ in 1:200]
    out = ABT.abt_std_unique(values)
    cursor = 1
    for x in out
        found = findnext(v -> (ismissing(v) && ismissing(x)) || isequal(v, x), values, cursor)
        @test found !== nothing
        found === nothing && break
        cursor = found + 1
    end
end
