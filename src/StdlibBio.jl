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

function abt_std_fasta_walk(handle, materialize, on_record=nothing)
 abt_std_isfasta(handle) || error("ABT FASTA: esperado valor produzido por ler_fasta")
 fastx = Base.require(Base.PkgId(Base.UUID("c2308a5c-f048-11e8-3e8a-31650f418d12"), "FASTX"))
 bio = Base.require(Base.PkgId(Base.UUID("7e6ae17a-c86d-528c-b3b9-7f778a29fe59"), "BioSequences"))
 return Base.invokelatest(abt_std_fasta_walk_loaded, handle, materialize, fastx, bio, on_record)
end

function abt_std_fasta_walk_loaded(handle, materialize, fastx, bio, on_record=nothing)
 seen = Set{String}()
 rows = NamedTuple[]
 totals = zeros(Int, 6) # A, C, G, T/U, N, bases
 count_records = 0
 alphabet = handle.alphabet
 allowed = alphabet == "DNA" ? "ACGT" : "ACGU"
 handle.ambiguity == "permitir_N" && (allowed *= "N")
 table = fill(false, 256)
 for byte in codeunits(allowed); table[byte + 1] = true; end
 try
  # Sem `do`-closure: variáveis atribuídas dentro de um closure ficam em caixas (Core.Box) e o laço perde estabilidade de tipos.
  io = open(handle.path, "r")
  try
   reader = fastx.FASTA.Reader(io)
   try
    # Barreira de função: o FASTX é carregado em tempo de execução, então o tipo do leitor é
    # desconhecido aqui. A função abaixo é especializada para o tipo concreto do leitor e das
    # funções do FASTX, o que torna o laço estável em tipos (sem despacho dinâmico por registro).
    count_records = abt_std_fasta_scan(reader, fastx.FASTA.identifier, fastx.FASTA.description, fastx.FASTA.sequence,
                                       handle, materialize, on_record, table, allowed, alphabet, seen, rows, totals)
   finally
    close(reader)
   end
  finally
   close(io)
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

# Laço de leitura FASTA (ver a barreira de função em abt_std_fasta_walk_loaded).
# Mensagens de erro e resultados idênticos aos da versão em linha.
function abt_std_fasta_scan(reader, identifier_of, description_of, sequence_of, handle, materialize, on_record,
                            table, allowed, alphabet, seen, rows, totals)
 count_records = 0
 for record in reader
  count_records = Base.checked_add(count_records, 1)
  id = String(identifier_of(record))
  isempty(id) && error("registro $count_records: identificador vazio")
  id in seen && error("registro $count_records: identificador duplicado '$id'")
  push!(seen, id)
  description = String(description_of(record))
  original = sequence_of(String, record)::String
  isempty(original) && error("registro $count_records '$id': sequência vazia")
  # Caminho rápido sem copiar a sequência: em texto ASCII, "minúscula" é exatamente um byte a-z.
  # Fora do ASCII mantém-se a comparação com uppercase (mesmo resultado e mesma mensagem).
  if handle.case_policy == "exigir_maiusculas" &&
     (isascii(original) ? any(b -> 0x61 <= b <= 0x7a, codeunits(original)) : original != uppercase(original))
   error("registro $count_records '$id': bases minúsculas não permitidas")
  end
  sequence = handle.case_policy == "normalizar" ? uppercase(original) : original
  # Caminho rápido por tabela de bytes; a busca da primeira base inválida só ocorre em caso de erro.
  if !all(b -> table[b + 1], codeunits(sequence))
   for (position, base) in enumerate(sequence)
    base in allowed || error("registro $count_records '$id': base inválida '$base' na posição $position para $alphabet")
   end
  end
  # Todas as bases já foram validadas como ASCII do alfabeto: uma única passada conta A, C, G e T/U.
  fourth = alphabet == "DNA" ? UInt8('T') : UInt8('U')
  na = 0; nc = 0; ng = 0; nt = 0
  for byte in codeunits(sequence)
   if byte == 0x41; na += 1
   elseif byte == 0x43; nc += 1
   elseif byte == 0x47; ng += 1
   elseif byte == fourth; nt += 1
   end
  end
  canonical = (na, nc, ng, nt)
  typed = sequence
  counts = (canonical..., length(typed) - sum(canonical))
  denominator = Base.checked_add(Base.checked_add(counts[1], counts[2]), Base.checked_add(counts[3], counts[4]))
  denominator > 0 || error("registro $count_records '$id': GC indefinido sem bases não ambíguas")
  values = (counts..., length(typed))
  on_record === nothing || on_record(id, length(typed))
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
 return count_records
end

abt_std_fasta_summary(handle) = abt_std_fasta_walk(handle, false)
abt_std_fasta_records(handle) = abt_std_fasta_walk(handle, true)
