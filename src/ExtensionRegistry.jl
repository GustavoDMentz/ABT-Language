# A new operation needs an implementation file and one entry here. This file
# is loaded by the interpreter; only a used implementation is emitted to Julia.
include("StdlibAnalytics.jl")
include("StdlibJSON.jl")
include("StdlibStats.jl")
include("StdlibLinear.jl")
include("StdlibBatch.jl")

const ABT_EXTENSION_SPECS = (
 resumir_grupos=(domain="dados", arity=4, static_args=(:unknown, :string, :string, :string),
                 return_kind=:unknown, implementation=abt_std_group_summary,
                 generated="abt_std_group_summary", source="StdlibAnalytics.jl",
                 input="tabela tipada, grupo texto, valor numérico, política de ausentes",
                 output="registro com grupos e contagem de linhas", errors="colunas/tipos/ausentes/soma inválidos",
                 dependencies="CSV.jl via tabela", loading="tabela já criada; sem novo pacote"),
 codificar_json=(domain="json", arity=2, static_args=(:unknown, :string),
                 return_kind=:string, implementation=abt_std_json,
                 generated="abt_std_json", source="StdlibJSON.jl",
                 input="valor ABT e política de ausentes", output="texto JSON",
                 errors="tipo/ciclo/ausente/número inválido", dependencies="JSON.jl 1.13.4",
                 loading="JSON.jl apenas na chamada"),
 contar_categorias=(domain="estatistica", arity=3, static_args=(:unknown, :string, :string),
                   return_kind=:unknown, implementation=abt_std_category_counts,
                   generated="abt_std_category_counts", source="StdlibStats.jl",
                   input="tabela tipada, coluna texto, política de ausentes",
                   output="registro com frequências e proporções", errors="coluna/tipo/ausentes/biblioteca",
                   dependencies="StatsBase.jl 0.34.13", loading="StatsBase.jl apenas na chamada com dados"),
 resolver_sistema_spd=(domain="algebra", arity=2, static_args=(:list, :list),
                       return_kind=:unknown, implementation=abt_std_solve_spd,
                       generated="abt_std_solve_spd", source="StdlibLinear.jl",
                       input="matriz quadrada simétrica definida positiva e vetor Float64",
                       output="registro com solução e norma do resíduo",
                       errors="forma/tipo/finitude/simetria/positividade/biblioteca",
                       dependencies="LinearAlgebra (Julia stdlib)", loading="já importada pelo núcleo; sem pacote externo"),
 agrupar_dados=(domain="dados", arity=4, static_args=(:unknown,:string,:string,:string), return_kind=:unknown,
                implementation=abt_std_group_data, generated="abt_std_group_data", source="StdlibBatch.jl",
                input="tabela, grupo, valor, política", output="grupos com valores", errors="colunas/tipos/ausentes", dependencies="DataFrames.jl", loading="sob demanda"),
 testar_grupos=(domain="estatistica", arity=4, static_args=(:unknown,:string,:string,:string), return_kind=:unknown,
                implementation=abt_std_test_groups, generated="abt_std_test_groups", source="StdlibBatch.jl",
                input="grupos, A, B, método", output="resultado de teste t bilateral", errors="amostras/método", dependencies="HypothesisTests.jl", loading="sob demanda"),
 categorias=(domain="dados", arity=4, static_args=(:unknown,:string,:list,:string), return_kind=:unknown,
             implementation=abt_std_categories, generated="abt_std_categories", source="StdlibBatch.jl",
             input="tabela, coluna, níveis, política", output="contagens ordenadas", errors="níveis/ausentes", dependencies="CategoricalArrays.jl", loading="sob demanda"),
 probabilidade_normal=(domain="estatistica", arity=3, static_args=(:number,:number,:number), return_kind=:unknown,
                      implementation=abt_std_normal_tail, generated="abt_std_normal_tail", source="StdlibBatch.jl",
                      input="média, desvio, limiar", output="probabilidade acima", errors="parâmetros", dependencies="Distributions.jl", loading="sob demanda"),
 grafico=(domain="visualizacao", arity=4, static_args=(:unknown,:string,:string,:string), return_kind=:unknown,
          implementation=abt_std_chart, generated="abt_std_chart", source="StdlibBatch.jl",
          input="tabela, eixo x, eixo y, modo", output="especificação de figura", errors="eixos/dados", dependencies="tabela ABT", loading="sem pacote"),
 salvar_figura=(domain="visualizacao", arity=2, static_args=(:unknown,:string), return_kind=:unknown,
                implementation=abt_std_save_chart, generated="abt_std_save_chart", source="StdlibBatch.jl",
                input="gráfico ABT, caminho", output="arquivo e pontos", errors="formato/IO", dependencies="Cairo.jl", loading="sob demanda"),
 alinhar_sequencias=(domain="bioinformatica", arity=8, static_args=(:unknown,:string,:string,:string,:number,:number,:number,:number), return_kind=:unknown,
                    implementation=abt_std_align_fasta, generated="abt_std_align_fasta", source="StdlibBatch.jl",
                    input="FASTA, IDs, modo, pontuações explícitas", output="métricas de alinhamento", errors="ID/modo/pontuação", dependencies="BioAlignments.jl", loading="sob demanda"),
)

function abt_extension_catalog()
 return [(name=String(name), domain=spec.domain, arity=spec.arity,
          input=spec.input, output=spec.output, dependencies=spec.dependencies,
          loading=spec.loading) for (name, spec) in pairs(ABT_EXTENSION_SPECS)]
end
