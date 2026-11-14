# ABT 0.14.0 — benchmark de bioinformática em processo (execuções aquecidas).
# Compara as operações ABT com Julia direta (FASTX.jl / BioAlignments.jl) sobre dados sintéticos
# gerados com semente fixa. A Julia direta NÃO valida o alfabeto nem cada qualidade como a ABT:
# a diferença inclui essa validação e a camada ABT, não apenas "overhead de interpretação".
#   julia --project=. benchmarks/benchmark_bio_0140.jl [saida.json]
using ABT, Random, Statistics, JSON
const fx = Base.require(Base.PkgId(Base.UUID("c2308a5c-f048-11e8-3e8a-31650f418d12"), "FASTX"))
const bio = Base.require(Base.PkgId(Base.UUID("7e6ae17a-c86d-528c-b3b9-7f778a29fe59"), "BioSequences"))
const al = Base.require(Base.PkgId(Base.UUID("00701ae9-d1dc-5365-b64a-a3a3ebf5695e"), "BioAlignments"))

function make_fastq(path, n, len)
    rng = MersenneTwister(140)
    open(path, "w") do io
        for i in 1:n
            println(io, "@r$i"); println(io, join(rand(rng, "ACGT", len))); println(io, "+")
            println(io, join(Char(33 + rand(rng, 20:40)) for _ in 1:len))
        end
    end
end
function make_fasta(path, n, len)
    rng = MersenneTwister(141)
    open(path, "w") do io
        for i in 1:n
            println(io, ">s$i"); println(io, join(rand(rng, "ACGT", len + rand(rng, 0:50))))
        end
    end
end
# Linha de base: Julia direta, sem validação de alfabeto.
function direct_fastq_metrics(path)
    rows = NamedTuple[]
    open(path) do io
        reader = fx.FASTQ.Reader(io)
        for rec in reader
            seq = fx.sequence(String, rec)
            q = Int.(collect(fx.quality_scores(rec, fx.FASTQ.SANGER_QUAL_ENCODING)))
            gc = count(c -> c == 'G' || c == 'C', seq)
            push!(rows, (; id=String(fx.identifier(rec)), n=length(seq), gc=100.0 * gc / length(seq), q=sum(q) / length(q)))
        end
        close(reader)
    end
    return rows
end
function direct_fasta_lengths(path)
    lengths = Int[]
    open(path) do io
        reader = fx.FASTA.Reader(io)
        for rec in reader; push!(lengths, length(fx.FASTA.sequence(String, rec))); end
        close(reader)
    end
    return (; n=length(lengths), min=minimum(lengths), max=maximum(lengths), mean=mean(lengths))
end
function direct_align(a, b)
    model = al.AffineGapScoreModel(; match=2, mismatch=-1, gap_open=-3, gap_extend=-1)
    return al.score(al.pairalign(al.GlobalAlignment(), bio.LongDNA{2}(a), bio.LongDNA{2}(b), model))
end

function measure(f; runs=5)
    f()  # aquecimento (compilação)
    times = Float64[]; allocs = Int[]
    for _ in 1:runs
        GC.gc()
        push!(allocs, @allocated f())
        push!(times, @elapsed f())
    end
    return (; mediana_s=median(times), minimo_s=minimum(times), alocado_mib=median(allocs) / 2^20)
end

function main(out)
    dir = mktempdir()
    fq = joinpath(dir, "reads.fastq"); fa = joinpath(dir, "seqs.fasta")
    make_fastq(fq, 20_000, 100); make_fasta(fa, 20_000, 150)
    rng = MersenneTwister(142)
    a1 = join(rand(rng, "ACGT", 1000)); b1 = join(rand(rng, "ACGT", 1000))
    a2 = join(rand(rng, "ACGT", 2000)); b2 = join(rand(rng, "ACGT", 2000))
    handle_q = ABT.abt_sc_fastq(fq, "DNA", "rejeitar", "phred33")
    handle_f = ABT.abt_std_fasta(fa, "DNA", "rejeitar", "exigir_maiusculas")
    scheme = ABT.abt_bio_nucleotide_scoring(2, -1, -3, -1)
    results = Dict{String,Any}()
    results["maquina"] = (; cpu=Sys.CPU_NAME, nucleos=Sys.CPU_THREADS, julia=string(VERSION), memoria_gib=round(Sys.total_memory() / 2^30; digits=1))
    results["fastq_metricas_20k_leituras_100pb"] = (; abt=measure(() -> ABT.abt_sc_fastq_metrics(handle_q)), julia_direta=measure(() -> direct_fastq_metrics(fq)))
    results["fastq_resumo_20k_leituras_100pb"] = (; abt=measure(() -> ABT.abt_sc_fastq_summary(handle_q)))
    results["fasta_comprimentos_20k_sequencias"] = (; abt=measure(() -> ABT.abt_bio_length_summary(handle_f)), julia_direta=measure(() -> direct_fasta_lengths(fa)))
    results["alinhamento_global_1000x1000"] = (; abt=measure(() -> ABT.abt_bio_align_pair(a1, b1, "global", scheme); runs=3), julia_direta=measure(() -> direct_align(a1, b1); runs=3))
    results["alinhamento_global_2000x2000"] = (; abt=measure(() -> ABT.abt_bio_align_pair(a2, b2, "global", scheme); runs=3), julia_direta=measure(() -> direct_align(a2, b2); runs=3))
    results["gc_motivo_traducao_100kb"] = let s = join(rand(rng, "ACGT", 99_999)); (; abt=measure(() -> (ABT.abt_bio_gc_content(s), ABT.abt_bio_motif_positions(s, "ACGTAC"), ABT.abt_bio_translate_frame(s, 1)))) end
    open(out, "w") do io; JSON.print(io, results, 2); end
    println(JSON.json(results, 2))
end
main(isempty(ARGS) ? joinpath(@__DIR__, "results", "benchmark_bio_0140_warm.json") : ARGS[1])
