using Test
include("test_differential_1000.jl")

const EXAMPLES_117 = [
    ("filter", "mostrar filtrar [1,2,3,4] onde valor > 2"),
    ("map", "mostrar transformar [1,2,3] com valor * 10"),
    ("limit", "mostrar limitar [1,2,3] a 2"),
    ("composition", "dados=[1,2,3,4]\nmostrar limitar (transformar (filtrar dados onde valor > 2) com valor * 10) a 1"),
    ("aggregate_composition", "dados=[1,2,3,4]\nmostrar soma de (transformar (filtrar dados onde valor > 1) com valor * 2)"),
    ("empty_filter", "mostrar filtrar [] onde média de [] > 0"),
    ("empty_map", "mostrar transformar [] com média de []"),
    ("empty_limit", "mostrar limitar [] a 3"),
    ("zero_limit", "mostrar limitar [1,2] a 0"),
    ("oversized_limit", "mostrar limitar [1,2] a 20"),
    ("nested_bindings", "x=99\nmostrar transformar (transformar [1,2] com valor + 1) com valor * 2\nmostrar x"),
    ("alias_value", "mostrar filtrar [1,2,3] onde value > 1"),
    ("unicode", "números=[1,2,3]\nmostrar transformar números com valor + 1"),
    ("function_effect_order", "function dobro(x) { show x; return x*2 }\nmostrar transformar [1,2,3] com dobro(valor)"),
    ("filter_effect_order", "function teste(x) { show x; return x > 1 }\nmostrar filtrar [1,2,3] onde teste(valor)"),
    ("function_return", "function recorte(xs) { return limitar (filtrar xs onde valor > 1) a 1 }\nmostrar recorte([1,2,3])"),
    ("legacy_identifier_filter", "filtrar=7\nmostrar filtrar"),
    ("legacy_identifier_map", "function transformar(x) { return x+1 }\nmostrar transformar(2)"),
    ("legacy_identifier_limit", "limitar=4\nmostrar limitar"),
    ("non_bool_predicate", "x=[1,2]\nmostrar filtrar x onde valor + 1"),
    ("non_vector_filter", "mostrar filtrar 3 onde valor > 1"),
    ("non_vector_map", "mostrar transformar 3 com valor + 1"),
    ("non_vector_limit", "mostrar limitar 3 a 1"),
    ("negative_limit", "mostrar limitar [1,2] a (0 - 1)"),
    ("fractional_limit", "mostrar limitar [1,2] a 1.5"),
    ("boolean_limit", "mostrar limitar [1,2] a true"),
    ("error_in_map", "mostrar transformar [1,2] com média de []"),
    ("error_in_filter", "mostrar filtrar [1,2] onde média de [] > 0"),
    ("invalid_composition", "mostrar filtrar (transformar [1,2] com valor * 2) onde valor + 1"),
    ("legacy_identifier_with", "com=8\nmostrar com"),
]

@testset "ABT 0.11.7 collections differential" begin
    for (id, (category, source)) in enumerate(EXAMPLES_117)
        ok, reason, _ = run_one(id, category, source)
        @test ok || error("$category: $reason")
    end
end

@testset "ABT 0.11.7 deterministic composition" begin
    rng = MersenneTwister(0xAB7117)
    for id in 1:300
        a, b, c = rand(rng, 0:20), rand(rng, 0:20), rand(rng, 0:20)
        source = if id <= 100
            "xs=[$a,$b,$c,5]\nmostrar limitar (transformar (filtrar xs onde valor > $b) com valor + $a) a $(id % 6)"
        elseif id <= 200
            "xs=[$a,$b,$c]\nmostrar soma de (transformar (filtrar xs onde valor >= $a) com valor * 2)"
        else
            "xs=[$a,$b,$c]\nmostrar transformar (limitar xs a $(id % 5)) com valor - $b"
        end
        ok, reason, _ = run_one(id, "composition_seeded", source)
        @test ok || error("case $id: $reason\n$source")
    end
end

@testset "ABT 0.11.7 contracts" begin
    src = "dados=[1,2,3,4]\nresultado=limitar (transformar (filtrar dados onde valor > 2) com valor * 10) a 1\nmostrar dados\nmostrar resultado"
    @test execute(parse_program(tokenize(src))) == ["[1, 2, 3, 4]", "[30]"]
    for source in ("mostrar filtrar [1,2]", "mostrar transformar [1,2]", "mostrar limitar [1,2]")
        @test_throws Exception parse_program(tokenize(source))
    end
    malformed = Pseudo.IR[Pseudo.ir(:print, Pseudo.ir(:filter, Pseudo.ir(:constant, 1)))]
    err = try Pseudo.validate_ir(malformed); nothing catch e; e end
    @test err isa ErrorException && occursin("filter expects 2 operands", sprint(showerror, err))
end
