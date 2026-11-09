using ABT
using Test

@testset "registro de extensões" begin
    catalog = ABT.abt_extension_catalog()
    @test length(catalog) == length(unique(row.name for row in catalog))
    @test all(row.arity > 0 && !isempty(row.dependencies) && !isempty(row.domain) for row in catalog)
    @test all(length(spec.static_args) == spec.arity && isfile(joinpath(@__DIR__, "..", "src", spec.source))
              for spec in values(ABT.ABT_EXTENSION_SPECS))
    @test issubset(Set(("resumir_grupos", "codificar_json", "contar_categorias", "resolver_sistema_spd")), Set(row.name for row in catalog))

    stats_id = Base.PkgId(Base.UUID("2913bbd2-ae8a-5f71-8c99-4fb6c76f3a91"), "StatsBase")
    @test !haskey(Base.loaded_modules, stats_id)
    source = "dados = ler_csv(\"arquivo_inexistente.csv\", esquema(\"grupo\", \"texto\"), \"erro\")\nmostrar contar_categorias(dados, \"grupo\", \"erro\")\n"
    ir = ABT.validate_ir(ABT.lower_ir(ABT.parse_program(ABT.tokenize(source))))
    @test !haskey(Base.loaded_modules, stats_id)
    @test occursin("abt_std_category_counts", ABT.generate(ir))
    @test !haskey(Base.loaded_modules, stats_id)
    simple = ABT.validate_ir(ABT.lower_ir(ABT.parse_program(ABT.tokenize("mostrar 1\n"))))
    @test !occursin("abt_std_category_counts", ABT.generate(simple))
end
