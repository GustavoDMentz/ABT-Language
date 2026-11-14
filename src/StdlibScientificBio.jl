# Explicit DNA contracts; package loading remains inside operation calls.
function abt_sc_dna(text, operation; allow_n=false)
 text isa String && !isempty(text) || error("ABT $operation: sequência deve ser texto não vazio")
 allowed = allow_n ? "ACGTN" : "ACGT"
 all(c -> c in allowed, text) || error("ABT $operation: esperado DNA maiúsculo, alfabeto $allowed")
 return text
end
function abt_sc_fastq(path, alphabet, ambiguity, encoding)
 path isa String && isfile(path) || error("ABT ler_fastq: arquivo inexistente")
 alphabet == "DNA" || error("ABT ler_fastq: alfabeto suportado: DNA")
 ambiguity in ("rejeitar", "permitir_N") || error("ABT ler_fastq: política de ambiguidade inválida")
 encoding == "phred33" || error("ABT ler_fastq: codificação deve ser phred33 explícita")
 return (; __abt_fastq__=true, path, alphabet, ambiguity, encoding)
end
# Um leitor FASTQ pode carregar filtros explícitos (filtrar_fastq); leituras que não os
# satisfazem são ignoradas em todas as operações, sem materializar o arquivo.
function abt_sc_isfastq(handle)
 handle isa NamedTuple || return false
 base = (:__abt_fastq__,:path,:alphabet,:ambiguity,:encoding)
 (keys(handle) == base || keys(handle) == (base..., :filtros)) && handle.__abt_fastq__ === true
end
function abt_sc_fastq_passes(handle, length_value, scores, n_count)
 haskey(handle, :filtros) || return true
 for f in handle.filtros
  length_value >= f.comprimento_minimo || return false
  sum(scores) / length(scores) >= f.phred_medio_minimo || return false
  n_count <= f.maximo_N || return false
 end
 return true
end
function abt_sc_fastq_filter(handle, minimum_length, minimum_phred, maximum_n)
 abt_sc_isfastq(handle) || error("ABT filtrar_fastq: esperado valor produzido por ler_fastq ou filtrar_fastq")
 typeof(minimum_length) === Int64 && minimum_length >= 0 || error("ABT filtrar_fastq: comprimento mínimo deve ser inteiro não negativo")
 (typeof(minimum_phred) === Int64 || typeof(minimum_phred) === Float64) && isfinite(minimum_phred) && 0 <= minimum_phred <= 93 ||
  error("ABT filtrar_fastq: Phred médio mínimo deve ser número entre 0 e 93")
 typeof(maximum_n) === Int64 && maximum_n >= 0 || error("ABT filtrar_fastq: máximo de N deve ser inteiro não negativo")
 criterion = (; comprimento_minimo=minimum_length, phred_medio_minimo=Float64(minimum_phred), maximo_N=maximum_n)
 previous = haskey(handle, :filtros) ? handle.filtros : ()
 return (; __abt_fastq__=true, path=handle.path, alphabet=handle.alphabet, ambiguity=handle.ambiguity,
          encoding=handle.encoding, filtros=(previous..., criterion))
end
# mode: false (resumo), true (registros com sequência), :metrics (métricas sem sequência),
# :stream (apenas repassa leituras ao sink e devolve a contagem).
# sink(id, descrição, sequência, escores) recebe cada leitura aprovada (exportação em fluxo).
function abt_sc_fastq_walk(handle, materialize, sink=nothing)
 abt_sc_isfastq(handle) || error("ABT FASTQ: esperado ler_fastq")
 fx = Base.require(Base.PkgId(Base.UUID("c2308a5c-f048-11e8-3e8a-31650f418d12"), "FASTX"))
 try
  return Base.invokelatest(abt_sc_fastq_loaded, handle, materialize, fx, sink)
 catch err
  msg = sprint(showerror, err)
  startswith(msg, "ABT FASTQ:") && rethrow()
  error("ABT FASTQ: arquivo '$(handle.path)': " * msg)
 end
end
function abt_sc_fastq_loaded(handle, materialize, fx, sink=nothing)
 rows = NamedTuple[]; counts = zeros(Int,5); records=0; kept=0; bases=0; quality_sum=0; qmin=93; qmax=0
 open(handle.path) do io
  reader=fx.FASTQ.Reader(io)
  try
   for rec in reader
    records=Base.checked_add(records,1)
    id=String(fx.identifier(rec)); isempty(id) && error("registro $records: identificador vazio")
    seq=fx.sequence(String,rec)
    abt_sc_dna(seq,"FASTQ registro $records";allow_n=handle.ambiguity=="permitir_N")
    scores=Int.(collect(fx.quality_scores(rec,fx.FASTQ.SANGER_QUAL_ENCODING)))
    length(scores)==length(seq) && all(q -> 0<=q<=93,scores) || error("registro $records: qualidades Phred inválidas")
    local_counts=[count(==(b),seq) for b in "ACGTN"]
    abt_sc_fastq_passes(handle, length(seq), scores, local_counts[5]) || continue
    kept=Base.checked_add(kept,1)
    sink === nothing || sink(id, String(fx.description(rec)), seq, scores)
    for i in eachindex(counts); counts[i]=Base.checked_add(counts[i],local_counts[i]); end
    bases=Base.checked_add(bases,length(seq)); quality_sum=Base.checked_add(quality_sum,sum(scores))
    qmin=min(qmin,minimum(scores)); qmax=max(qmax,maximum(scores))
    if materialize === true
     push!(rows,(; identificador=id,sequencia=seq,comprimento=length(seq),A=local_counts[1],C=local_counts[2],G=local_counts[3],T=local_counts[4],N=local_counts[5],phred_minimo=minimum(scores),phred_maximo=maximum(scores),phred_medio=sum(scores)/length(scores)))
    elseif materialize === :metrics
     acgt = local_counts[1]+local_counts[2]+local_counts[3]+local_counts[4]
     acgt > 0 || error("registro $records '$id': GC indefinido sem bases A, C, G ou T")
     push!(rows,(; identificador=id,comprimento=length(seq),GC_percentual=100.0*(local_counts[2]+local_counts[3])/acgt,N=local_counts[5],phred_medio=sum(scores)/length(scores),phred_minimo=minimum(scores),percentual_q20=100.0*count(>=(20),scores)/length(scores),percentual_q30=100.0*count(>=(30),scores)/length(scores)))
    end
   end
  finally
   close(reader)
  end
 end
 records>0 || error("arquivo sem registros")
 if materialize === true || materialize === :metrics
  return rows
 end
 materialize === :stream && return kept
 kept>0 || error("nenhuma leitura satisfaz os filtros de filtrar_fastq")
 return (; registros=kept,bases,A=counts[1],C=counts[2],G=counts[3],T=counts[4],N=counts[5],phred_minimo=qmin,phred_maximo=qmax,phred_medio=quality_sum/bases)
end
abt_sc_fastq_summary(x)=abt_sc_fastq_walk(x,false)
abt_sc_fastq_records(x)=abt_sc_fastq_walk(x,true)
abt_sc_fastq_metrics(x)=abt_sc_fastq_walk(x,:metrics)
function abt_sc_fastq_export(handle, path)
 abt_sc_isfastq(handle) || error("ABT exportar_fastq: esperado valor produzido por ler_fastq ou filtrar_fastq")
 path isa String && !isempty(path) || error("ABT exportar_fastq: caminho deve ser texto não vazio")
 abspath(path) == abspath(handle.path) && error("ABT exportar_fastq: o destino não pode ser o próprio arquivo de entrada")
 written = Ref(0)
 try
  open(path, "w") do out
   sink = function (id, description, sequence, scores)
    println(out, "@", isempty(description) ? id : description)  # FASTX: a descrição já contém o cabeçalho completo
    println(out, sequence); println(out, "+")
    println(out, String(Char.(scores .+ 33)))
   end
   written[] = abt_sc_fastq_walk(handle, :stream, sink)
  end
 catch err
  msg = sprint(showerror, err)
  startswith(msg, "ABT FASTQ:") && rethrow()
  error("ABT exportar_fastq: arquivo '$path': " * msg)
 end
 return (; arquivo=path, leituras_escritas=written[])
end
function abt_sc_kmers(text,k)
 abt_sc_dna(text,"frequencias_kmers")
 typeof(k)===Int64 && 1<=k<=length(text) || error("ABT frequencias_kmers: k deve ser inteiro entre 1 e comprimento")
 bio=Base.require(Base.PkgId(Base.UUID("7e6ae17a-c86d-528c-b3b9-7f778a29fe59"),"BioSequences"))
 return Base.invokelatest(abt_sc_kmers_loaded,text,k,bio)
end
function abt_sc_kmers_loaded(text,k,bio)
 seq=bio.LongDNA{2}(text); counts=Dict{String,Int}()
 for i in 1:length(seq)-k+1
  word=String(seq[i:i+k-1]); counts[word]=Base.checked_add(get(counts,word,0),1)
 end
 total=length(seq)-k+1
 return (; k,total,frequencias=[(; sequencia=word,quantidade=counts[word],frequencia=counts[word]/total) for word in sort!(collect(keys(counts)))])
end
function abt_sc_reverse(text)
 abt_sc_dna(text,"complemento_reverso";allow_n=true)
 bio=Base.require(Base.PkgId(Base.UUID("7e6ae17a-c86d-528c-b3b9-7f778a29fe59"),"BioSequences"))
 return Base.invokelatest(b -> String(b.reverse_complement(b.LongDNA{4}(text))),bio)
end
function abt_sc_translate(text)
 abt_sc_dna(text,"traduzir_dna")
 length(text)%3==0 || error("ABT traduzir_dna: comprimento deve ser múltiplo de 3; quadro 1 explícito")
 bio=Base.require(Base.PkgId(Base.UUID("7e6ae17a-c86d-528c-b3b9-7f778a29fe59"),"BioSequences"))
 return Base.invokelatest(b -> String(b.translate(b.LongDNA{2}(text))),bio)
end
