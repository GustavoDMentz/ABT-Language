# FASTA contracts shared by the interpreter and generated Julia.
abt_std_isfasta(x) = x isa NamedTuple && keys(x) == (:__abt_fasta__, :path, :alphabet, :ambiguity, :case_policy) && x.__abt_fasta__ === true

function abt_std_fasta(path, alphabet, ambiguity, case_policy)
 path isa String && !isempty(path) || error("ABT ler_fasta: arquivo deve ser texto não vazio")
 alphabet in ("DNA", "RNA") || error("ABT ler_fasta: alfabeto deve ser DNA ou RNA")
 ambiguity in ("rejeitar", "permitir_N") || error("ABT ler_fasta: política de ambiguidade deve ser rejeitar ou permitir_N")
 case_policy in ("exigir_maiusculas", "normalizar") || error("ABT ler_fasta: política de caixa deve ser exigir_maiusculas ou normalizar")
 isfile(path) || error("ABT ler_fasta: arquivo '$path' não existe")
 return (; __abt_fasta__=true, path, alphabet, ambiguity, case_policy)
end

function abt_std_fasta_walk(handle, materialize)
 abt_std_isfasta(handle) || error("ABT FASTA: esperado valor produzido por ler_fasta")
 fastx = Base.require(Base.PkgId(Base.UUID("c2308a5c-f048-11e8-3e8a-31650f418d12"), "FASTX"))
 bio = Base.require(Base.PkgId(Base.UUID("7e6ae17a-c86d-528c-b3b9-7f778a29fe59"), "BioSequences"))
 return Base.invokelatest(abt_std_fasta_walk_loaded, handle, materialize, fastx, bio)
end

function abt_std_fasta_walk_loaded(handle, materialize, fastx, bio)
 seen = Set{String}()
 rows = NamedTuple[]
 totals = zeros(Int, 6) # A, C, G, T/U, N, bases
 count_records = 0
 alphabet = handle.alphabet
 allowed = alphabet == "DNA" ? "ACGT" : "ACGU"
 handle.ambiguity == "permitir_N" && (allowed *= "N")
 try
  open(handle.path, "r") do io
   reader = fastx.FASTA.Reader(io)
   try
    for record in reader
     count_records = Base.checked_add(count_records, 1)
     id = String(fastx.FASTA.identifier(record))
     isempty(id) && error("registro $count_records: identificador vazio")
     id in seen && error("registro $count_records: identificador duplicado '$id'")
     push!(seen, id)
     description = String(fastx.FASTA.description(record))
     original = fastx.FASTA.sequence(String, record)
     isempty(original) && error("registro $count_records '$id': sequência vazia")
     if handle.case_policy == "exigir_maiusculas" && original != uppercase(original)
      error("registro $count_records '$id': bases minúsculas não permitidas")
     end
     sequence = handle.case_policy == "normalizar" ? uppercase(original) : original
     for (position, base) in enumerate(sequence)
      base in allowed || error("registro $count_records '$id': base inválida '$base' na posição $position para $alphabet")
     end
     typed = if alphabet == "DNA"
      handle.ambiguity == "permitir_N" ? bio.LongDNA{4}(sequence) : bio.LongDNA{2}(sequence)
     else
      handle.ambiguity == "permitir_N" ? bio.LongRNA{4}(sequence) : bio.LongRNA{2}(sequence)
     end
     symbols = alphabet == "DNA" ? (bio.DNA_A, bio.DNA_C, bio.DNA_G, bio.DNA_T) :
                                   (bio.RNA_A, bio.RNA_C, bio.RNA_G, bio.RNA_U)
     canonical = ntuple(i -> count(==(symbols[i]), typed), 4)
     counts = (canonical..., length(typed) - sum(canonical))
     denominator = Base.checked_add(Base.checked_add(counts[1], counts[2]), Base.checked_add(counts[3], counts[4]))
     denominator > 0 || error("registro $count_records '$id': GC indefinido sem bases não ambíguas")
     values = (counts..., length(typed))
     for i in 1:6
      totals[i] = Base.checked_add(totals[i], values[i])
     end
     if materialize
      metrics = (; identificador=id, descricao=description, sequencia=original,
                  comprimento=length(typed), A=counts[1], C=counts[2], G=counts[3],
                  T=alphabet == "DNA" ? counts[4] : 0, U=alphabet == "RNA" ? counts[4] : 0,
                  N=counts[5], GC_percentual=100.0 * (counts[2] + counts[3]) / denominator)
      push!(rows, metrics)
     end
    end
   finally
    close(reader)
   end
  end
 catch err
  message = sprint(showerror, err)
  startswith(message, "ABT FASTA:") && rethrow()
  error("ABT FASTA: arquivo '$(handle.path)': " * message)
 end
 count_records > 0 || error("ABT FASTA: arquivo '$(handle.path)': nenhum registro")
 if materialize
  return rows
 end
 denominator = Base.checked_add(Base.checked_add(totals[1], totals[2]), Base.checked_add(totals[3], totals[4]))
 common = (; sequencias=count_records, bases=totals[6], A=totals[1], C=totals[2], G=totals[3])
 if alphabet == "DNA"
  return (; common..., T=totals[4], N=totals[5], GC_percentual=100.0 * (totals[2] + totals[3]) / denominator)
 end
 return (; common..., U=totals[4], N=totals[5], GC_percentual=100.0 * (totals[2] + totals[3]) / denominator)
end

abt_std_fasta_summary(handle) = abt_std_fasta_walk(handle, false)
abt_std_fasta_records(handle) = abt_std_fasta_walk(handle, true)
