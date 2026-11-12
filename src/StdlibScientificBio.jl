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
function abt_sc_fastq_walk(handle, materialize)
 handle isa NamedTuple && keys(handle) == (:__abt_fastq__,:path,:alphabet,:ambiguity,:encoding) && handle.__abt_fastq__ === true || error("ABT FASTQ: esperado ler_fastq")
 fx = Base.require(Base.PkgId(Base.UUID("c2308a5c-f048-11e8-3e8a-31650f418d12"), "FASTX"))
 try
  return Base.invokelatest(abt_sc_fastq_loaded, handle, materialize, fx)
 catch err
  error("ABT FASTQ: arquivo '$(handle.path)': " * sprint(showerror, err))
 end
end
function abt_sc_fastq_loaded(handle, materialize, fx)
 rows = NamedTuple[]; counts = zeros(Int,5); records=0; bases=0; quality_sum=0; qmin=93; qmax=0
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
    for i in eachindex(counts); counts[i]=Base.checked_add(counts[i],local_counts[i]); end
    bases=Base.checked_add(bases,length(seq)); quality_sum=Base.checked_add(quality_sum,sum(scores))
    qmin=min(qmin,minimum(scores)); qmax=max(qmax,maximum(scores))
    materialize && push!(rows,(; identificador=id,sequencia=seq,comprimento=length(seq),A=local_counts[1],C=local_counts[2],G=local_counts[3],T=local_counts[4],N=local_counts[5],phred_minimo=minimum(scores),phred_maximo=maximum(scores),phred_medio=sum(scores)/length(scores)))
   end
  finally
   close(reader)
  end
 end
 records>0 || error("arquivo sem registros")
 materialize && return rows
 return (; registros=records,bases,A=counts[1],C=counts[2],G=counts[3],T=counts[4],N=counts[5],phred_minimo=qmin,phred_maximo=qmax,phred_medio=quality_sum/bases)
end
abt_sc_fastq_summary(x)=abt_sc_fastq_walk(x,false)
abt_sc_fastq_records(x)=abt_sc_fastq_walk(x,true)
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
