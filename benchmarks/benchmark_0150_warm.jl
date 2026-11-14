# ABT 0.15.0 — benchmark em processo: primeira execução (inclui compilação) e execuções aquecidas.
#   julia --project=. benchmarks/benchmark_0150_warm.jl [saida.json]
# Para cada cenário mede o programa ABT via ABT.execute (o mesmo caminho da CLI) e, quando há,
# a implementação Julia metodologicamente equivalente de benchmarks/direct_equivalents_0150.jl.
using ABT, Random, Statistics, JSON
include(joinpath(@__DIR__, "direct_equivalents_0150.jl"))

function build(dir)
    rng = MersenneTwister(150)
    open(joinpath(dir, "reads.fastq"), "w") do io
        for i in 1:20_000
            println(io, "@r$i"); println(io, String(rand(rng, collect("ACGT"), 100))); println(io, "+")
            println(io, String([Char(33 + rand(rng, 15:40)) for _ in 1:100]))
        end
    end
    open(joinpath(dir, "seqs.fasta"), "w") do io
        for i in 1:20_000
            println(io, ">s$i"); println(io, String(rand(rng, collect("ACGT"), 150 + rand(rng, 0:50))))
        end
    end
    dna = [String(rand(rng, collect("ACGT"), 1000)) for _ in 1:2]
    prot = [String(rand(rng, collect("ACDEFGHIKLMNPQRSTVWY"), 400)) for _ in 1:2]
    pequenos = join(1:100, ", ")
    numeros = join(rand(rng, 1:1000, 20_000), ", ")
    programs = [
        "trivial" => "mostrar 1\n",
        "aritmetica" => "função passo(a, b) {\n    retornar (a * 3 + b * 7) - (a + b) / 2\n}\nxs = [$pequenos]\ntotal = 0\npara cada a em xs {\n    para cada b em xs {\n        total = total + passo(a, b)\n    }\n}\nmostrar total\n",
        "listas" => "dados = [$numeros]\npares = filtrar dados onde valor > 500\ndobrados = transformar pares com valor * 2\nmostrar soma de dobrados\nmostrar media de dados\nmostrar contar(sem_duplicatas(dados))\nmostrar limitar ordenar(dados) a 3\n",
        "fasta" => "g = ler_fasta(\"$dir/seqs.fasta\", \"DNA\", \"rejeitar\", \"exigir_maiusculas\")\nmostrar resumir_comprimentos(g)\n",
        "fastq" => "l = ler_fastq(\"$dir/reads.fastq\", \"DNA\", \"rejeitar\", \"phred33\")\nmostrar resumir_fastq(l)\n",
        "metricas" => "l = ler_fastq(\"$dir/reads.fastq\", \"DNA\", \"rejeitar\", \"phred33\")\nm = metricas_leituras(filtrar_fastq(l, 50, 25, 0))\nmostrar contar(m)\n",
        "alinhamento_dna" => "mostrar alinhar_par(\"$(dna[1])\", \"$(dna[2])\", \"global\", pontuacao_dna(2, -1, -3, -1)).pontuacao\n",
        "alinhamento_proteina" => "mostrar alinhar_par(\"$(prot[1])\", \"$(prot[2])\", \"global\", pontuacao_proteina(\"BLOSUM62\", -10, -1)).pontuacao\n",
    ]
    direct = Dict(
        "fasta" => () -> direct_length_summary(joinpath(dir, "seqs.fasta")),
        "fastq" => () -> direct_fastq_summary(joinpath(dir, "reads.fastq")),
        "alinhamento_dna" => () -> direct_align(dna[1], dna[2], AffineGapScoreModel(; match=2, mismatch=-1, gap_open=-3, gap_extend=-1)),
        "alinhamento_proteina" => () -> direct_protein_align(prot[1], prot[2], AffineGapScoreModel(BLOSUM62; gap_open=-10, gap_extend=-1)),
    )
    return programs, direct
end

function measure(f; runs=5)
    first = @elapsed f()
    times = Float64[]
    for _ in 1:runs
        GC.gc(); push!(times, @elapsed f())
    end
    return (; primeira_s=round(first; digits=4), aquecida_mediana_s=round(median(times); digits=4),
            aquecida_minima_s=round(minimum(times); digits=4), alocado_mib=round((@allocated f()) / 2^20; digits=2))
end

function main(out)
    dir = mktempdir()
    programs, direct = build(dir)
    results = Dict{String,Any}("maquina" => (; cpu=Sys.CPU_NAME, nucleos=Sys.CPU_THREADS, julia=string(VERSION),
                                              memoria_gib=round(Sys.total_memory() / 2^30; digits=1),
                                              compile=Base.JLOptions().compile_enabled))
    for (name, source) in programs
        run_abt() = ABT.execute(ABT.parse_program(ABT.tokenize(source)))
        row = Dict{String,Any}("abt" => measure(run_abt))
        haskey(direct, name) && (row["julia_equivalente"] = measure(direct[name]))
        results[name] = row
        println(name, " => ", row)
    end
    open(out, "w") do io; JSON.print(io, results, 2); end
end
main(isempty(ARGS) ? joinpath(@__DIR__, "results", "benchmark_0150_warm.json") : ARGS[1])
