# Implementações Julia diretas metodologicamente equivalentes às operações ABT medidas:
# mesma leitura (FASTX), mesmas validações (identificador vazio/duplicado, caixa, alfabeto,
# qualidades Phred, GC definido) e o mesmo resultado. Usadas pelo benchmark 0.15.0.
using FASTX, BioAlignments, BioSequences, Statistics
import FASTX: sequence, identifier, quality_scores

function direct_length_summary(path)
    seen = Set{String}(); lengths = Int[]
    open(FASTA.Reader, path) do reader
        for record in reader
            id = String(identifier(record)); isempty(id) && error("identificador vazio")
            id in seen && error("identificador duplicado"); push!(seen, id)
            s = sequence(String, record); isempty(s) && error("sequência vazia")
            any(b -> 0x61 <= b <= 0x7a, codeunits(s)) && error("minúsculas")
            all(b -> b == 0x41 || b == 0x43 || b == 0x47 || b == 0x54, codeunits(s)) || error("base inválida")
            push!(lengths, length(s))
        end
    end
    isempty(lengths) && error("nenhum registro")
    sorted = sort(lengths); total = sum(sorted)
    cumulative = 0; n50 = sorted[end]
    for n in Iterators.reverse(sorted); cumulative += n; if 2cumulative >= total; n50 = n; break; end; end
    return (; sequencias=length(sorted), bases=total, minimo=sorted[1], maximo=sorted[end], media=total / length(sorted), mediana=median(sorted), n50)
end

function direct_fastq_metrics(path)
    rows = NamedTuple[]
    open(FASTQ.Reader, path) do reader
        for record in reader
            id = String(identifier(record)); isempty(id) && error("identificador vazio")
            s = sequence(String, record)
            all(b -> b == 0x41 || b == 0x43 || b == 0x47 || b == 0x54, codeunits(s)) || error("base inválida")
            q = Int.(collect(quality_scores(record, FASTQ.SANGER_QUAL_ENCODING)))
            length(q) == length(s) && all(x -> 0 <= x <= 93, q) || error("qualidade inválida")
            gc = count(b -> b == 0x43 || b == 0x47, codeunits(s)); acgt = length(s)
            push!(rows, (; identificador=id, comprimento=length(s), GC_percentual=100.0 * gc / acgt, N=0,
                         phred_medio=sum(q) / length(q), phred_minimo=minimum(q),
                         percentual_q20=100.0 * count(>=(20), q) / length(q), percentual_q30=100.0 * count(>=(30), q) / length(q)))
        end
    end
    return rows
end

function direct_fastq_summary(path)
    n = 0; bases = 0; qsum = 0; qmin = 93; qmax = 0; counts = zeros(Int, 5)
    open(FASTQ.Reader, path) do reader
        for record in reader
            n += 1; s = sequence(String, record)
            all(b -> b == 0x41 || b == 0x43 || b == 0x47 || b == 0x54, codeunits(s)) || error("base inválida")
            q = Int.(collect(quality_scores(record, FASTQ.SANGER_QUAL_ENCODING)))
            for (i, c) in enumerate("ACGTN"); counts[i] += count(==(c), s); end
            bases += length(s); qsum += sum(q); qmin = min(qmin, minimum(q)); qmax = max(qmax, maximum(q))
        end
    end
    return (; registros=n, bases, phred_medio=qsum / bases, phred_minimo=qmin, phred_maximo=qmax)
end

function direct_align(a, b, model)
    r = pairalign(GlobalAlignment(), LongDNA{2}(a), LongDNA{2}(b), model)
    columns = collect(alignment(r))   # o mesmo trabalho que a ABT faz para montar o resultado
    return (; score=score(r), matches=count(((x, y),) -> x == y, columns), length=length(columns))
end

function direct_protein_align(a, b, model)
    r = pairalign(GlobalAlignment(), LongAA(a), LongAA(b), model)
    columns = collect(alignment(r))
    return (; score=score(r), length=length(columns))
end
