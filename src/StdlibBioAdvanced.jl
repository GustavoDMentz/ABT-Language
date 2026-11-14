# ABT 0.14.0: sequências, pontuação e alinhamento par a par.
# Contratos estritos: texto em MAIÚSCULAS, sem coerção silenciosa, erros que nomeiam a operação.
# Pacotes Julia (BioSequences, BioAlignments) são carregados apenas na chamada.

# O código gerado fica dentro de um bloco let: sem `const` neste arquivo.
abt_bio_aa() = "ACDEFGHIKLMNPQRSTVWY"

function abt_bio_text(operation, value; what="sequência")
 value isa String && !isempty(value) || error("ABT $operation: $what deve ser texto não vazio")
 return value
end

# Valida um ácido nucleico e devolve :DNA ou :RNA. Sequências sem T nem U são DNA.
function abt_bio_nucleic(operation, text; allow_n=false)
 abt_bio_text(operation, text)
 allowed = allow_n ? "ACGTUN" : "ACGTU"
 for (position, base) in enumerate(text)
  base in allowed || error("ABT $operation: base inválida '$base' na posição $position (esperado $(allow_n ? "A, C, G, T/U ou N" : "A, C, G, T/U") em maiúsculas)")
 end
 has_t = 'T' in text; has_u = 'U' in text
 has_t && has_u && error("ABT $operation: a sequência mistura T (DNA) e U (RNA)")
 return has_u ? :RNA : :DNA
end

function abt_bio_counts(text)
 a = count(==('A'), text); c = count(==('C'), text); g = count(==('G'), text)
 t = count(==('T'), text); u = count(==('U'), text); n = count(==('N'), text)
 return (; A=a, C=c, G=g, T=t, U=u, N=n)
end

function abt_bio_gc(operation, counts)
 denominator = counts.A + counts.C + counts.G + counts.T + counts.U
 denominator > 0 || error("ABT $operation: GC indefinido, a sequência não tem bases A, C, G, T ou U")
 return 100.0 * (counts.C + counts.G) / denominator
end

function abt_bio_gc_content(text)
 abt_bio_nucleic("conteudo_gc", text; allow_n=true)
 return abt_bio_gc("conteudo_gc", abt_bio_counts(text))
end

function abt_bio_composition(text)
 kind = abt_bio_nucleic("composicao_sequencia", text; allow_n=true)
 c = abt_bio_counts(text)
 gc = abt_bio_gc("composicao_sequencia", c)
 return kind == :DNA ?
  (; comprimento=length(text), A=c.A, C=c.C, G=c.G, T=c.T, N=c.N, GC_percentual=gc) :
  (; comprimento=length(text), A=c.A, C=c.C, G=c.G, U=c.U, N=c.N, GC_percentual=gc)
end

function abt_bio_transcribe(text)
 abt_bio_nucleic("transcrever_dna", text; allow_n=true) == :DNA ||
  error("ABT transcrever_dna: a sequência contém U; esperado DNA")
 return replace(text, 'T' => 'U')
end

function abt_bio_translate_frame(text, frame)
 typeof(frame) === Int64 && 1 <= frame <= 3 || error("ABT traduzir_quadro: quadro deve ser inteiro 1, 2 ou 3")
 kind = abt_bio_nucleic("traduzir_quadro", text; allow_n=false)
 start = frame
 length(text) - start + 1 >= 3 || error("ABT traduzir_quadro: o quadro $frame não contém códon completo")
 complete = (length(text) - start + 1) ÷ 3
 coding = text[start:start + 3 * complete - 1]
 bio = Base.require(Base.PkgId(Base.UUID("7e6ae17a-c86d-528c-b3b9-7f778a29fe59"), "BioSequences"))
 return Base.invokelatest(abt_bio_translate_loaded, coding, kind, bio)
end
function abt_bio_translate_loaded(coding, kind, bio)
 sequence = kind == :DNA ? bio.LongDNA{2}(coding) : bio.LongRNA{2}(coding)
 return String(bio.translate(sequence))
end

function abt_bio_subsequence(text, first_index, last_index)
 abt_bio_text("subsequencia", text)
 typeof(first_index) === Int64 && typeof(last_index) === Int64 ||
  error("ABT subsequencia: início e fim devem ser inteiros")
 characters = collect(text)
 1 <= first_index <= last_index <= length(characters) ||
  error("ABT subsequencia: intervalo $first_index:$last_index fora de 1:$(length(characters)) (índices a partir de 1, fim incluído)")
 return String(characters[first_index:last_index])
end

function abt_bio_motif_positions(text, motif)
 abt_bio_text("localizar_motivo", text)
 abt_bio_text("localizar_motivo", motif; what="motivo")
 all(c -> 'A' <= c <= 'Z', text) || error("ABT localizar_motivo: a sequência deve conter apenas letras maiúsculas")
 all(c -> 'A' <= c <= 'Z', motif) || error("ABT localizar_motivo: o motivo deve conter apenas letras maiúsculas")
 sequence = collect(text); pattern = collect(motif)
 positions = Int64[]
 for start in 1:(length(sequence) - length(pattern) + 1)
  view(sequence, start:start + length(pattern) - 1) == pattern && push!(positions, Int64(start))
 end
 return positions
end

function abt_bio_is_valid(text, alphabet, policy)
 text isa String || error("ABT validar_sequencia: a sequência deve ser texto")
 alphabet in ("DNA", "RNA", "proteina") || error("ABT validar_sequencia: alfabeto deve ser DNA, RNA ou proteina")
 policy in ("rejeitar", "permitir_N", "permitir_X") ||
  error("ABT validar_sequencia: ambiguidade deve ser rejeitar, permitir_N (DNA/RNA) ou permitir_X (proteina)")
 (policy == "permitir_N" && alphabet == "proteina") && error("ABT validar_sequencia: proteina usa permitir_X, não permitir_N")
 (policy == "permitir_X" && alphabet != "proteina") && error("ABT validar_sequencia: DNA/RNA usam permitir_N, não permitir_X")
 isempty(text) && return false
 allowed = alphabet == "DNA" ? "ACGT" : alphabet == "RNA" ? "ACGU" : abt_bio_aa()
 policy == "permitir_N" && (allowed *= "N")
 policy == "permitir_X" && (allowed *= "X")
 return all(c -> c in allowed, text)
end

# Esquemas de pontuação são valores ABT (registros) reutilizáveis.
function abt_bio_gap_arguments(operation, open_score, extend_score)
 typeof(open_score) === Int64 && typeof(extend_score) === Int64 ||
  error("ABT $operation: abertura e extensão devem ser inteiros")
 open_score <= 0 && extend_score <= 0 ||
  error("ABT $operation: abertura e extensão são penalidades e devem ser menores ou iguais a zero; um gap de comprimento k custa abertura + k*extensão")
end
function abt_bio_nucleotide_scoring(match_score, mismatch_score, open_score, extend_score)
 typeof(match_score) === Int64 && typeof(mismatch_score) === Int64 ||
  error("ABT pontuacao_dna: acerto e erro devem ser inteiros")
 match_score > 0 && mismatch_score <= 0 || error("ABT pontuacao_dna: acerto deve ser positivo e erro menor ou igual a zero")
 abt_bio_gap_arguments("pontuacao_dna", open_score, extend_score)
 return (; __abt_pontuacao__=true, tipo="nucleotideos", matriz="acerto_erro", acerto=match_score, erro=mismatch_score,
          abertura=open_score, extensao=extend_score)
end
function abt_bio_protein_scoring(matrix, open_score, extend_score)
 matrix in ("BLOSUM62", "PAM250") || error("ABT pontuacao_proteina: matriz deve ser BLOSUM62 ou PAM250")
 abt_bio_gap_arguments("pontuacao_proteina", open_score, extend_score)
 return (; __abt_pontuacao__=true, tipo="proteina", matriz=matrix, abertura=open_score, extensao=extend_score)
end
function abt_bio_is_scoring(x)
 x isa NamedTuple && haskey(x, :__abt_pontuacao__) && x.__abt_pontuacao__ === true && haskey(x, :tipo) &&
  (x.tipo == "nucleotideos" ? keys(x) == (:__abt_pontuacao__, :tipo, :matriz, :acerto, :erro, :abertura, :extensao) :
   x.tipo == "proteina" ? keys(x) == (:__abt_pontuacao__, :tipo, :matriz, :abertura, :extensao) : false)
end

function abt_bio_align_pair(first_text, second_text, mode, scoring)
 abt_bio_is_scoring(scoring) || error("ABT alinhar_par: o esquema deve vir de pontuacao_dna ou pontuacao_proteina")
 mode in ("global", "local") || error("ABT alinhar_par: modo deve ser global ou local")
 if scoring.tipo == "nucleotideos"
  abt_bio_nucleic("alinhar_par", first_text); abt_bio_nucleic("alinhar_par", second_text)
  ('T' in first_text * second_text && 'U' in first_text * second_text) &&
   error("ABT alinhar_par: as sequências devem ser ambas DNA ou ambas RNA")
 else
  for text in (first_text, second_text)
   abt_bio_text("alinhar_par", text)
   for (position, residue) in enumerate(text)
    residue in abt_bio_aa() || error("ABT alinhar_par: resíduo inválido '$residue' na posição $position (aminoácidos padrão em maiúsculas: $(abt_bio_aa()))")
   end
  end
 end
 bio = Base.require(Base.PkgId(Base.UUID("7e6ae17a-c86d-528c-b3b9-7f778a29fe59"), "BioSequences"))
 align = Base.require(Base.PkgId(Base.UUID("00701ae9-d1dc-5365-b64a-a3a3ebf5695e"), "BioAlignments"))
 return Base.invokelatest(abt_bio_align_loaded, first_text, second_text, mode, scoring, bio, align)
end

function abt_bio_align_loaded(first_text, second_text, mode, scoring, bio, align)
 protein = scoring.tipo == "proteina"
 rna = !protein && ('U' in first_text || 'U' in second_text)
 make(text) = protein ? bio.LongAA(text) : rna ? bio.LongRNA{2}(text) : bio.LongDNA{2}(text)
 model = if protein
  matrix = scoring.matriz == "BLOSUM62" ? align.BLOSUM62 : align.PAM250
  align.AffineGapScoreModel(matrix; gap_open=scoring.abertura, gap_extend=scoring.extensao)
 else
  align.AffineGapScoreModel(; match=scoring.acerto, mismatch=scoring.erro, gap_open=scoring.abertura, gap_extend=scoring.extensao)
 end
 kind = mode == "global" ? align.GlobalAlignment() : align.LocalAlignment()
 result = try
  align.pairalign(kind, make(first_text), make(second_text), model)
 catch err
  error("ABT alinhar_par: " * sprint(showerror, err))
 end
 pair = align.alignment(result)
 columns = collect(pair)
 isempty(columns) && error("ABT alinhar_par: nenhum alinhamento local com pontuação positiva")
 gap_char(x) = bio.isgap(x)
 letters_a = IOBuffer(); letters_b = IOBuffer()
 matches = 0; substitutions = 0; gaps_in_b = 0; gaps_in_a = 0; similar = 0
 gap_openings = 0; previous = :none
 matrix_value(x, y) = protein ? (scoring.matriz == "BLOSUM62" ? align.BLOSUM62[x, y] : align.PAM250[x, y]) : (x == y ? scoring.acerto : scoring.erro)
 for (x, y) in columns
  if gap_char(x)
   gaps_in_a += 1; print(letters_a, '-'); print(letters_b, Char(y))
   previous == :gap_a || (gap_openings += 1); previous = :gap_a
  elseif gap_char(y)
   gaps_in_b += 1; print(letters_a, Char(x)); print(letters_b, '-')
   previous == :gap_b || (gap_openings += 1); previous = :gap_b
  else
   print(letters_a, Char(x)); print(letters_b, Char(y)); previous = :pair
   x == y ? (matches += 1) : (substitutions += 1)
   matrix_value(x, y) > 0 && (similar += 1)
  end
 end
 total = length(columns)
 anchors_a = pair.a.aln.anchors
 gap_columns = gaps_in_a + gaps_in_b
 return (; modo=mode, pontuacao=Int64(align.score(result)),
         comprimento_alinhamento=total, correspondencias=matches, substituicoes=substitutions,
         insercoes=gaps_in_b, delecoes=gaps_in_a, aberturas_gap=gap_openings,
         extensoes_gap=gap_columns - gap_openings,
         identidade_percentual=100.0 * matches / total,
         similaridade_percentual=100.0 * similar / total,
         inicio_a=anchors_a[1].seqpos + 1, fim_a=anchors_a[end].seqpos,
         inicio_b=anchors_a[1].refpos + 1, fim_b=anchors_a[end].refpos,
         alinhamento_a=String(take!(letters_a)), alinhamento_b=String(take!(letters_b)))
end

# Comprimentos de sequências de um FASTA em fluxo: só os comprimentos ficam em memória.
function abt_bio_length_summary(handle)
 abt_std_isfasta(handle) || error("ABT resumir_comprimentos: esperado valor produzido por ler_fasta")
 lengths = Int64[]
 abt_std_fasta_walk(handle, false, (id, n) -> push!(lengths, Int64(n)))
 sorted = sort(lengths)
 total = sum(sorted)
 middle = length(sorted)
 median = isodd(middle) ? Float64(sorted[(middle + 1) ÷ 2]) : (sorted[middle ÷ 2] + sorted[middle ÷ 2 + 1]) / 2
 cumulative = Int64(0); n50 = sorted[end]
 for n in Iterators.reverse(sorted)
  cumulative += n
  if 2 * cumulative >= total
   n50 = n; break
  end
 end
 return (; sequencias=length(sorted), bases=total, minimo=sorted[1], maximo=sorted[end],
          media=total / length(sorted), mediana=median, n50=n50)
end
