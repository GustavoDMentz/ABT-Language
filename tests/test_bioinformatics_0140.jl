using Test
include(joinpath(@__DIR__, "..", "pseudo.jl"))
using .Pseudo
using Random

# ABT 0.14.0 — bioinformática. Oráculos independentes: contas analíticas, valores
# publicados das matrizes e uma programação dinâmica afim (Gotoh) escrita aqui,
# sem usar BioAlignments.

interpreted(source) = join(execute(parse_program(tokenize(source))), "\n")
function generated(source; optimize)
    code = generate(parse_program(tokenize(source)); optimize)
    strip(read(`$(Base.julia_cmd()) --startup-file=no --project=$(dirname(@__DIR__)) -e $code`, String))
end
function parity(source, expected)
    @test interpreted(source) == expected
    for optimize in (false, true)
        @test generated(source; optimize) == expected
    end
end
function fails(source, fragment)
    err = try interpreted(source); nothing catch e; sprint(showerror, e) end
    @test err !== nothing && occursin(fragment, err)
end
fails_all(source, fragment) = begin
    fails(source, fragment)
    for optimize in (false, true)
        code = generate(parse_program(tokenize(source)); optimize)
        err = IOBuffer()
        run(pipeline(ignorestatus(`$(Base.julia_cmd()) --startup-file=no --project=$(dirname(@__DIR__)) -e $code`); stderr=err))
        @test occursin(fragment, String(take!(err)))
    end
end
validate_source(source) = validate_ir(lower_ir(parse_program(tokenize(source))))

# --- Oráculo de alinhamento afim (custo de gap de comprimento k = abertura + k*extensão) ---
const NEG = typemin(Int) ÷ 4
function gotoh(a::String, b::String, score::Function, open::Int, ext::Int; local_mode=false)
    n, m = length(a), length(b)
    M = fill(NEG, n + 1, m + 1); X = fill(NEG, n + 1, m + 1); Y = fill(NEG, n + 1, m + 1)
    M[1, 1] = 0
    if !local_mode
        for i in 1:n; X[i + 1, 1] = open + i * ext; end
        for j in 1:m; Y[1, j + 1] = open + j * ext; end
    end
    best = 0
    for i in 1:n, j in 1:m
        prev = max(M[i, j], X[i, j], Y[i, j])
        local_mode && (prev = max(prev, 0))
        M[i + 1, j + 1] = score(a[i], b[j]) + prev
        X[i + 1, j + 1] = max(M[i, j + 1] + open + ext, X[i, j + 1] + ext, Y[i, j + 1] + open + ext)
        Y[i + 1, j + 1] = max(M[i + 1, j] + open + ext, Y[i + 1, j] + ext, X[i + 1, j] + open + ext)
        local_mode && (best = max(best, M[i + 1, j + 1]))
    end
    local_mode && return best
    return max(M[n + 1, m + 1], X[n + 1, m + 1], Y[n + 1, m + 1])
end

# Valores publicados (NCBI) das matrizes, conferidos antes de usá-las como oráculo.
const BLOSUM62_PUBLISHED = Dict(('A','A')=>4, ('W','W')=>11, ('C','C')=>9, ('A','R')=>-1, ('R','A')=>-1,
                                ('W','C')=>-2, ('I','L')=>2, ('D','E')=>2, ('P','W')=>-4)
const PAM250_PUBLISHED = Dict(('A','A')=>2, ('W','W')=>17, ('C','C')=>12, ('W','C')=>-8, ('C','W')=>-8,
                              ('A','R')=>-2, ('F','Y')=>7, ('L','I')=>2)
const AA = collect("ACDEFGHIKLMNPQRSTVWY")
function matrix_lookup(name)
    align = Base.require(Base.PkgId(Base.UUID("00701ae9-d1dc-5365-b64a-a3a3ebf5695e"), "BioAlignments"))
    bio = Base.require(Base.PkgId(Base.UUID("7e6ae17a-c86d-528c-b3b9-7f778a29fe59"), "BioSequences"))
    matrix = name == "BLOSUM62" ? align.BLOSUM62 : align.PAM250
    return (x, y) -> Base.invokelatest(getindex, matrix, bio.AminoAcid(x), bio.AminoAcid(y))
end

@testset "sequências: conteúdo GC, composição, transcrição" begin
    @test ABT.abt_bio_gc_content("GGCC") === 100.0
    @test ABT.abt_bio_gc_content("ATAT") === 0.0
    @test ABT.abt_bio_gc_content("ATGC") === 50.0
    @test ABT.abt_bio_gc_content("ATGCN") === 50.0        # N fora do denominador
    @test ABT.abt_bio_gc_content("GGCU") === 75.0
    @test_throws ErrorException ABT.abt_bio_gc_content("")
    @test_throws ErrorException ABT.abt_bio_gc_content("NNN")
    @test_throws ErrorException ABT.abt_bio_gc_content("acgt")
    @test_throws ErrorException ABT.abt_bio_gc_content("ACGX")
    @test_throws ErrorException ABT.abt_bio_gc_content("ACGTU")
    @test_throws ErrorException ABT.abt_bio_gc_content(1)
    @test ABT.abt_bio_composition("ATGCGTACGTAG") ==
          (; comprimento=12, A=3, C=2, G=4, T=3, N=0, GC_percentual=50.0)
    @test ABT.abt_bio_composition("AUGN") == (; comprimento=4, A=1, C=0, G=1, U=1, N=1, GC_percentual=100.0 / 3)
    @test ABT.abt_bio_transcribe("ATGCN") == "AUGCN"
    @test_throws ErrorException ABT.abt_bio_transcribe("AUG")
    @test_throws ErrorException ABT.abt_bio_transcribe("")
    @test_throws ErrorException ABT.abt_bio_transcribe("ATX")
end

@testset "sequências: tradução, subsequência, motivos, validação" begin
    # Código genético padrão (tabela publicada): ATG=M TGG=W TTT=F TAA=* GGC=G
    @test ABT.abt_bio_translate_frame("ATGTGGTTTTAAGGC", 1) == "MWF*G"
    @test ABT.abt_bio_translate_frame("AATGTGGTTT", 2) == "MWF"
    @test ABT.abt_bio_translate_frame("AAATGTGG", 3) == "MW"
    @test ABT.abt_bio_translate_frame("AUGUGGUUU", 1) == "MWF"     # RNA
    @test ABT.abt_bio_translate_frame("ATGTGGTTTA", 1) == "MWF"    # resto parcial ignorado
    @test_throws ErrorException ABT.abt_bio_translate_frame("AT", 1)
    @test_throws ErrorException ABT.abt_bio_translate_frame("ATG", 2)
    @test_throws ErrorException ABT.abt_bio_translate_frame("ATG", 0)
    @test_throws ErrorException ABT.abt_bio_translate_frame("ATG", 4)
    @test_throws ErrorException ABT.abt_bio_translate_frame("ATG", 1.0)
    @test_throws ErrorException ABT.abt_bio_translate_frame("ATN", 1)
    @test_throws ErrorException ABT.abt_bio_translate_frame("", 1)
    @test ABT.abt_bio_subsequence("ACGTACGT", 2, 5) == "CGTA"
    @test ABT.abt_bio_subsequence("ACGT", 1, 4) == "ACGT"
    @test ABT.abt_bio_subsequence("ACGT", 3, 3) == "G"
    @test_throws ErrorException ABT.abt_bio_subsequence("ACGT", 0, 2)
    @test_throws ErrorException ABT.abt_bio_subsequence("ACGT", 2, 5)
    @test_throws ErrorException ABT.abt_bio_subsequence("ACGT", 3, 2)
    @test_throws ErrorException ABT.abt_bio_subsequence("ACGT", 1.0, 2)
    @test_throws ErrorException ABT.abt_bio_subsequence("", 1, 1)
    @test ABT.abt_bio_motif_positions("ACGACGACG", "ACGACG") == [1, 4]      # sobreposição
    @test ABT.abt_bio_motif_positions("AAAA", "AA") == [1, 2, 3]
    @test ABT.abt_bio_motif_positions("ACGT", "TT") == Int64[]
    @test ABT.abt_bio_motif_positions("ACG", "ACGT") == Int64[]
    @test typeof(ABT.abt_bio_motif_positions("ACG", "A")) == Vector{Int64}
    @test_throws ErrorException ABT.abt_bio_motif_positions("ACG", "")
    @test_throws ErrorException ABT.abt_bio_motif_positions("acg", "A")
    @test_throws ErrorException ABT.abt_bio_motif_positions("ACG", "a")
    @test ABT.abt_bio_is_valid("ACGT", "DNA", "rejeitar")
    @test !ABT.abt_bio_is_valid("ACGN", "DNA", "rejeitar")
    @test ABT.abt_bio_is_valid("ACGN", "DNA", "permitir_N")
    @test !ABT.abt_bio_is_valid("ACGU", "DNA", "rejeitar")
    @test ABT.abt_bio_is_valid("ACGU", "RNA", "rejeitar")
    @test ABT.abt_bio_is_valid("ACDEFGHIKLMNPQRSTVWY", "proteina", "rejeitar")
    @test !ABT.abt_bio_is_valid("ACDX", "proteina", "rejeitar")
    @test ABT.abt_bio_is_valid("ACDX", "proteina", "permitir_X")
    @test !ABT.abt_bio_is_valid("", "DNA", "rejeitar")
    @test !ABT.abt_bio_is_valid("acgt", "DNA", "rejeitar")
    @test_throws ErrorException ABT.abt_bio_is_valid("A", "xyz", "rejeitar")
    @test_throws ErrorException ABT.abt_bio_is_valid("A", "DNA", "talvez")
    @test_throws ErrorException ABT.abt_bio_is_valid("A", "proteina", "permitir_N")
    @test_throws ErrorException ABT.abt_bio_is_valid("A", "DNA", "permitir_X")
    @test_throws ErrorException ABT.abt_bio_is_valid(1, "DNA", "rejeitar")
end

@testset "matrizes de substituição: valores publicados" begin
    for ((x, y), expected) in BLOSUM62_PUBLISHED
        @test matrix_lookup("BLOSUM62")(x, y) == expected
    end
    for ((x, y), expected) in PAM250_PUBLISHED
        @test matrix_lookup("PAM250")(x, y) == expected
    end
    for name in ("BLOSUM62", "PAM250")
        lookup = matrix_lookup(name)
        @test all(lookup(x, y) == lookup(y, x) for x in AA, y in AA)     # simetria
    end
end

@testset "pontuação e alinhamento: casos analíticos" begin
    dna = ABT.abt_bio_nucleotide_scoring(2, -1, -3, -1)
    r = ABT.abt_bio_align_pair("ACGTACGT", "ACGTACGT", "global", dna)
    @test r.pontuacao == 16 && r.correspondencias == 8 && r.substituicoes == 0
    @test r.identidade_percentual == 100.0 && r.similaridade_percentual == 100.0
    @test r.comprimento_alinhamento == 8 && r.aberturas_gap == 0 && r.extensoes_gap == 0
    @test (r.inicio_a, r.fim_a, r.inicio_b, r.fim_b) == (1, 8, 1, 8)
    # um gap de comprimento 3: 7 acertos*2 + (-3 + 3*(-1)) = 8
    g = ABT.abt_bio_align_pair("ACGTTTACGT", "ACGACGT", "global", dna)
    @test g.pontuacao == 8
    @test g.aberturas_gap == 1 && g.extensoes_gap == 2 && g.insercoes == 3 && g.delecoes == 0
    @test g.comprimento_alinhamento == 10 && g.correspondencias == 7
    @test replace(g.alinhamento_a, "-" => "") == "ACGTTTACGT"
    @test replace(g.alinhamento_b, "-" => "") == "ACGACGT"
    @test length(g.alinhamento_a) == length(g.alinhamento_b) == g.comprimento_alinhamento
    @test g.identidade_percentual == 70.0
    # substituição única: 3 acertos*2 - 1
    s = ABT.abt_bio_align_pair("ACGT", "AGGT", "global", dna)
    @test s.pontuacao == 5 && s.substituicoes == 1 && s.correspondencias == 3
    @test s.identidade_percentual == 75.0
    # local: melhor trecho ACGT (4*2)
    l = ABT.abt_bio_align_pair("TTACGTAA", "GGACGTCC", "local", dna)
    @test l.pontuacao == 8 && l.alinhamento_a == "ACGT" && (l.inicio_a, l.fim_a, l.inicio_b, l.fim_b) == (3, 6, 3, 6)
    @test_throws ErrorException ABT.abt_bio_align_pair("AAAA", "CCCC", "local", dna)   # sem alinhamento positivo
    # RNA
    @test ABT.abt_bio_align_pair("ACGU", "ACGU", "global", dna).pontuacao == 8
    # proteína: valores analíticos da matriz
    b62 = ABT.abt_bio_protein_scoring("BLOSUM62", -10, -1)
    p250 = ABT.abt_bio_protein_scoring("PAM250", -10, -1)
    @test ABT.abt_bio_align_pair("AW", "AW", "global", b62).pontuacao == 4 + 11
    @test ABT.abt_bio_align_pair("AW", "AW", "global", p250).pontuacao == 2 + 17
    # duas substituições (W/C = -8, duas vezes) ou dois gaps em torno de W/W: 2*(-10-1) + 17 = -5
    @test ABT.abt_bio_align_pair("CW", "WC", "global", p250).pontuacao == max(-8 + -8, 2 * (-10 - 1) + 17) == -5
    sim = ABT.abt_bio_align_pair("IL", "LI", "global", b62)  # I/L = 2 (positivo): similares, não idênticos
    @test sim.correspondencias == 0 && sim.similaridade_percentual == 100.0 && sim.identidade_percentual == 0.0
end

@testset "alinhamento contra oráculo de programação dinâmica" begin
    rng = MersenneTwister(2026)
    for trial in 1:40
        open = rand(rng, -6:0); ext = rand(rng, -3:0)
        for mode in ("global", "local")
            a = join(rand(rng, collect("ACGT"), rand(rng, 4:14))); b = join(rand(rng, collect("ACGT"), rand(rng, 4:14)))
            match, mism = rand(rng, 1:4), rand(rng, -3:0)
            scoring = ABT.abt_bio_nucleotide_scoring(match, mism, open, ext)
            expected = gotoh(a, b, (x, y) -> x == y ? match : mism, open, ext; local_mode=mode == "local")
            if mode == "local" && expected == 0
                @test_throws ErrorException ABT.abt_bio_align_pair(a, b, mode, scoring)
                continue
            end
            @test ABT.abt_bio_align_pair(a, b, mode, scoring).pontuacao == expected
        end
    end
    for name in ("BLOSUM62", "PAM250"), trial in 1:15, mode in ("global", "local")
        open = rand(rng, -12:-4); ext = rand(rng, -3:0)
        a = join(rand(rng, AA, rand(rng, 5:15))); b = join(rand(rng, AA, rand(rng, 5:15)))
        lookup = matrix_lookup(name)
        expected = gotoh(a, b, lookup, open, ext; local_mode=mode == "local")
        scoring = ABT.abt_bio_protein_scoring(name, open, ext)
        result = ABT.abt_bio_align_pair(a, b, mode, scoring)
        @test result.pontuacao == expected
        # as colunas do alinhamento devem reproduzir a pontuação pelo mesmo modelo de gaps
        total = 0; in_gap = :none
        for (x, y) in zip(result.alinhamento_a, result.alinhamento_b)
            if x == '-'
                total += ext + (in_gap == :a ? 0 : open); in_gap = :a
            elseif y == '-'
                total += ext + (in_gap == :b ? 0 : open); in_gap = :b
            else
                total += lookup(x, y); in_gap = :none
            end
        end
        @test total == result.pontuacao
    end
end

@testset "alinhamento: contratos e erros" begin
    dna = ABT.abt_bio_nucleotide_scoring(2, -1, -3, -1)
    b62 = ABT.abt_bio_protein_scoring("BLOSUM62", -10, -1)
    @test_throws ErrorException ABT.abt_bio_nucleotide_scoring(0, -1, -3, -1)
    @test_throws ErrorException ABT.abt_bio_nucleotide_scoring(2, 1, -3, -1)
    @test_throws ErrorException ABT.abt_bio_nucleotide_scoring(2, -1, 1, -1)
    @test_throws ErrorException ABT.abt_bio_nucleotide_scoring(2.0, -1, -3, -1)
    @test_throws ErrorException ABT.abt_bio_protein_scoring("BLOSUM45", -10, -1)
    @test_throws ErrorException ABT.abt_bio_protein_scoring("BLOSUM62", 5, -1)
    @test_throws ErrorException ABT.abt_bio_protein_scoring("BLOSUM62", -10, -1.0)
    @test_throws ErrorException ABT.abt_bio_align_pair("ACGT", "ACGT", "semiglobal", dna)
    @test_throws ErrorException ABT.abt_bio_align_pair("ACGT", "ACGT", "global", (; x=1))
    @test_throws ErrorException ABT.abt_bio_align_pair("", "ACGT", "global", dna)
    @test_throws ErrorException ABT.abt_bio_align_pair("ACGT", "", "global", dna)
    @test_throws ErrorException ABT.abt_bio_align_pair("ACGN", "ACGT", "global", dna)
    @test_throws ErrorException ABT.abt_bio_align_pair("acgt", "ACGT", "global", dna)
    @test_throws ErrorException ABT.abt_bio_align_pair("ACGT", "ACGU", "global", dna)
    @test_throws ErrorException ABT.abt_bio_align_pair("ACGT", "AC1T", "global", dna)
    @test_throws ErrorException ABT.abt_bio_align_pair("ACGX", "ACGT", "global", b62)
    @test_throws ErrorException ABT.abt_bio_align_pair("ACGB", "ACGT", "global", b62)
    @test_throws ErrorException ABT.abt_bio_align_pair(1, "ACGT", "global", dna)
    # esquema de proteína forjado com chaves erradas é rejeitado
    @test_throws ErrorException ABT.abt_bio_align_pair("AW", "AW", "global", (; __abt_pontuacao__=true, tipo="proteina", matriz="BLOSUM62"))
end

function write_fixture(dir, name, text)
    path = joinpath(dir, name); write(path, text); path
end

@testset "FASTQ: métricas, filtros e exportação" begin
    mktempdir() do dir
        reads = write_fixture(dir, "r.fastq", "@r1 desc um\nACGTAC\n+\nIIIIII\n@r2\nAACCGG\n+\n??????\n@r3\nACNNAC\n+\n5555!!\n@r4\nGGGG\n+\n####\n")
        handle = ABT.abt_sc_fastq(reads, "DNA", "permitir_N", "phred33")
        metrics = ABT.abt_sc_fastq_metrics(handle)
        @test [m.identificador for m in metrics] == ["r1", "r2", "r3", "r4"]
        @test metrics[1] == (; identificador="r1", comprimento=6, GC_percentual=50.0, N=0, phred_medio=40.0, phred_minimo=40, percentual_q20=100.0, percentual_q30=100.0)
        @test metrics[2].phred_medio == 30.0 && metrics[2].percentual_q30 == 100.0
        # r3: qualidades '5'=20, '!'=0 -> média (20*4+0*2)/6; N excluído do GC; Q20 = 4/6, Q30 = 0
        @test metrics[3].N == 2 && metrics[3].GC_percentual == 50.0
        @test metrics[3].phred_medio ≈ 80 / 6 && metrics[3].percentual_q20 ≈ 100 * 4 / 6 && metrics[3].percentual_q30 == 0.0
        @test metrics[4].GC_percentual == 100.0 && metrics[4].phred_minimo == 2
        f = ABT.abt_sc_fastq_filter(handle, 5, 20, 0)
        @test [m.identificador for m in ABT.abt_sc_fastq_metrics(f)] == ["r1", "r2"]
        @test ABT.abt_sc_fastq_summary(f).registros == 2
        @test ABT.abt_sc_fastq_summary(f).phred_medio == 35.0
        f2 = ABT.abt_sc_fastq_filter(f, 6, 40, 0)                     # filtros se acumulam (E)
        @test [m.identificador for m in ABT.abt_sc_fastq_metrics(f2)] == ["r1"]
        @test [r.identificador for r in ABT.abt_sc_fastq_records(f2)] == ["r1"]
        @test [m.identificador for m in ABT.abt_sc_fastq_metrics(ABT.abt_sc_fastq_filter(handle, 0, 0, 2))] == ["r1", "r2", "r3", "r4"]
        @test [m.identificador for m in ABT.abt_sc_fastq_metrics(ABT.abt_sc_fastq_filter(handle, 0, 0, 1))] == ["r1", "r2", "r4"]
        none = ABT.abt_sc_fastq_filter(handle, 100, 0, 0)
        @test ABT.abt_sc_fastq_metrics(none) == NamedTuple[]
        @test ABT.abt_sc_fastq_records(none) == NamedTuple[]
        @test_throws ErrorException ABT.abt_sc_fastq_summary(none)
        # leitor sem filtro: resumo antigo inalterado
        plain = ABT.abt_sc_fastq_summary(ABT.abt_sc_fastq(reads, "DNA", "permitir_N", "phred33"))
        @test plain.registros == 4 && plain.bases == 22 && plain.N == 2
        # exportação: só as leituras aprovadas, cabeçalho preservado, releitura idêntica
        out = joinpath(dir, "saida.fastq")
        result = ABT.abt_sc_fastq_export(f, out)
        @test result == (; arquivo=out, leituras_escritas=2)
        @test read(out, String) == "@r1 desc um\nACGTAC\n+\nIIIIII\n@r2\nAACCGG\n+\n??????\n"
        reread = ABT.abt_sc_fastq_metrics(ABT.abt_sc_fastq(out, "DNA", "rejeitar", "phred33"))
        @test reread == ABT.abt_sc_fastq_metrics(f)
        @test_throws ErrorException ABT.abt_sc_fastq_export(f, reads)    # destino = origem
        @test_throws ErrorException ABT.abt_sc_fastq_export(f, "")
        @test_throws ErrorException ABT.abt_sc_fastq_export((; x=1), out)
        @test ABT.abt_sc_fastq_export(none, joinpath(dir, "vazio.fastq")).leituras_escritas == 0
        @test read(joinpath(dir, "vazio.fastq"), String) == ""
        # parâmetros inválidos
        @test_throws ErrorException ABT.abt_sc_fastq_filter(handle, -1, 0, 0)
        @test_throws ErrorException ABT.abt_sc_fastq_filter(handle, 1.5, 0, 0)
        @test_throws ErrorException ABT.abt_sc_fastq_filter(handle, 1, 94, 0)
        @test_throws ErrorException ABT.abt_sc_fastq_filter(handle, 1, NaN, 0)
        @test_throws ErrorException ABT.abt_sc_fastq_filter(handle, 1, 0, -1)
        @test_throws ErrorException ABT.abt_sc_fastq_filter("x", 1, 0, 0)
        @test_throws ErrorException ABT.abt_sc_fastq_metrics("x")
        # arquivos malformados
        empty = write_fixture(dir, "vazio_in.fastq", "")
        @test_throws ErrorException ABT.abt_sc_fastq_metrics(ABT.abt_sc_fastq(empty, "DNA", "rejeitar", "phred33"))
        trunc = write_fixture(dir, "trunc.fastq", "@r1\nACGT\n+\nII\n")
        @test_throws ErrorException ABT.abt_sc_fastq_metrics(ABT.abt_sc_fastq(trunc, "DNA", "rejeitar", "phred33"))
        badbase = write_fixture(dir, "base.fastq", "@r1\nACXT\n+\nIIII\n")
        @test_throws ErrorException ABT.abt_sc_fastq_metrics(ABT.abt_sc_fastq(badbase, "DNA", "rejeitar", "phred33"))
        allN = write_fixture(dir, "n.fastq", "@r1\nNNNN\n+\nIIII\n")
        @test_throws ErrorException ABT.abt_sc_fastq_metrics(ABT.abt_sc_fastq(allN, "DNA", "permitir_N", "phred33"))
        @test ABT.abt_sc_fastq_metrics(ABT.abt_sc_fastq_filter(ABT.abt_sc_fastq(allN, "DNA", "permitir_N", "phred33"), 0, 0, 3)) == NamedTuple[]
    end
end

@testset "FASTA: comprimentos e N50" begin
    mktempdir() do dir
        # comprimentos 2, 3, 4, 5, 6, 10 -> total 30; N50: 10 sozinho já cobre 15? 10 < 15; 10+6=16 >= 15 -> 6
        fasta = write_fixture(dir, "l.fasta", ">a\nAC\n>b\nACG\n>c\nACGT\n>d\nACGTA\n>e\nACGTAC\n>f\nACGTACGTAC\n")
        handle = ABT.abt_std_fasta(fasta, "DNA", "rejeitar", "exigir_maiusculas")
        r = ABT.abt_bio_length_summary(handle)
        @test r == (; sequencias=6, bases=30, minimo=2, maximo=10, media=5.0, mediana=4.5, n50=6)
        one = write_fixture(dir, "um.fasta", ">x\nACGTACGT\n")
        @test ABT.abt_bio_length_summary(ABT.abt_std_fasta(one, "DNA", "rejeitar", "exigir_maiusculas")) ==
              (; sequencias=1, bases=8, minimo=8, maximo=8, media=8.0, mediana=8.0, n50=8)
        # sequência multilinha conta uma só
        multi = write_fixture(dir, "m.fasta", ">x\nACGT\nACGT\n>y\nAC\n")
        @test ABT.abt_bio_length_summary(ABT.abt_std_fasta(multi, "DNA", "rejeitar", "exigir_maiusculas")).maximo == 8
        # mesmas validações de ler_fasta
        empty = write_fixture(dir, "e.fasta", "")
        @test_throws ErrorException ABT.abt_bio_length_summary(ABT.abt_std_fasta(empty, "DNA", "rejeitar", "exigir_maiusculas"))
        bad = write_fixture(dir, "b.fasta", ">x\nACGX\n")
        @test_throws ErrorException ABT.abt_bio_length_summary(ABT.abt_std_fasta(bad, "DNA", "rejeitar", "exigir_maiusculas"))
        dup = write_fixture(dir, "d.fasta", ">x\nACGT\n>x\nACGT\n")
        @test_throws ErrorException ABT.abt_bio_length_summary(ABT.abt_std_fasta(dup, "DNA", "rejeitar", "exigir_maiusculas"))
        @test_throws ErrorException ABT.abt_bio_length_summary("x")
        # o resumo antigo continua idêntico (callback é aditivo)
        @test ABT.abt_std_fasta_summary(handle).sequencias == 6
    end
end

@testset "validação estática e paridade entre backends" begin
    @test_throws ErrorException validate_source("mostrar conteudo_gc()")
    @test_throws ErrorException validate_source("mostrar conteudo_gc(1)")
    @test_throws ErrorException validate_source("mostrar conteudo_gc(\"A\", \"B\")")
    @test_throws ErrorException validate_source("mostrar traduzir_quadro(\"ATG\")")
    @test_throws ErrorException validate_source("mostrar traduzir_quadro(\"ATG\", \"1\")")
    @test_throws ErrorException validate_source("mostrar subsequencia(\"ACGT\", 1)")
    @test_throws ErrorException validate_source("mostrar alinhar_par(\"A\", \"A\", \"global\")")
    @test_throws ErrorException validate_source("mostrar pontuacao_proteina(1, -1, -1)")
    @test_throws ErrorException validate_source("mostrar filtrar_fastq(1, 2, 3)")
    # composição: resultados entram em listas, registros, filtros e condições
    program = """
sequencias = ["ATGCGT", "AAATTT", "GGGCCC", "ATATGC"]
ricas = filtrar sequencias onde conteudo_gc(valor) >= 50
mostrar soma de transformar ricas com 1
mostrar transformar sequencias com conteudo_gc(valor)
mostrar transformar ricas com transcrever_dna(valor)
se validar_sequencia("ATGC", "DNA", "rejeitar") {
    mostrar traduzir_quadro("ATGTGGTTT", 1)
}
mostrar localizar_motivo("ACGACGACG", "ACGACG")
mostrar subsequencia("ACGTACGT", 2, 5)
mostrar composicao_sequencia("ATGCGTACGTAG")
esquema_dna = pontuacao_dna(2, -1, -3, -1)
r = alinhar_par("ACGTTTACGT", "ACGACGT", "global", esquema_dna)
mostrar r.pontuacao
mostrar registro("identidade", r.identidade_percentual, "gaps", r.aberturas_gap)
l = alinhar_par("TTACGTAA", "GGACGTCC", "local", esquema_dna)
mostrar l.alinhamento_a
p = alinhar_par("AW", "AW", "global", pontuacao_proteina("PAM250", -10, -1))
mostrar p.pontuacao
"""
    expected = interpreted(program)
    @test split(expected, "\n")[1] == "2"
    @test occursin("MWF", expected) && occursin("(identidade = 70.0, gaps = 1)", expected)
    for optimize in (false, true)
        @test generated(program; optimize) == expected
    end
    # erros: mesma causa no interpretador e na Julia gerada
    fails_all("mostrar conteudo_gc(ambiente(\"ABT_X_INEXISTENTE\", \"ACGZ\"))", "base inválida")
    fails_all("mostrar traduzir_quadro(\"AT\", 1)", "códon completo")
    fails_all("mostrar subsequencia(\"ACGT\", 3, 9)", "fora de")
    fails_all("mostrar alinhar_par(\"ACGT\", \"ACGT\", \"global\", registro(\"a\", 1))", "pontuacao_dna")
    fails_all("mostrar pontuacao_proteina(\"BLOSUM45\", -1, -1)", "BLOSUM62 ou PAM250")
    # novos nomes não impedem identificadores de usuário nem a ponte Julia
    parity("conteudo_gc = 3\nmostrar conteudo_gc + 1", "4")
    parity("usar Julia.Base\nmostrar Julia.Base.length(localizar_motivo(\"AAAA\", \"AA\"))", "3")
end

@testset "FASTQ/FASTA nos três modos" begin
    root = dirname(@__DIR__)
    program = """
leituras = ler_fastq("$(root)/applications/scientific_0130/data/reads.fastq", "DNA", "rejeitar", "phred33")
mostrar metricas_leituras(leituras)
boas = filtrar_fastq(leituras, 6, 35, 0)
mostrar resumir_fastq(boas)
mostrar soma de transformar metricas_leituras(boas) com 1
fasta = ler_fasta("$(root)/applications/science/amostras.fasta", "DNA", "rejeitar", "exigir_maiusculas")
mostrar resumir_comprimentos(fasta)
"""
    expected = interpreted(program)
    @test occursin("registros = 1", expected) && occursin("n50 = 12", expected)
    for optimize in (false, true)
        @test generated(program; optimize) == expected
    end
    mktempdir() do dir
        out = joinpath(dir, "o.fastq")
        export_program = """
leituras = ler_fastq("$(root)/applications/scientific_0130/data/reads.fastq", "DNA", "rejeitar", "phred33")
mostrar exportar_fastq(filtrar_fastq(leituras, 6, 35, 0), "$out")
"""
        @test occursin("leituras_escritas = 1", interpreted(export_program))
        content = read(out, String); rm(out)
        for optimize in (false, true)
            @test occursin("leituras_escritas = 1", generated(export_program; optimize))
            @test read(out, String) == content; rm(out)
        end
    end
end
