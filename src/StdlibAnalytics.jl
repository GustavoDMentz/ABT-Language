# Typed, deterministic grouping over the existing lazy table value.
function abt_std_group_summary(table, group_name, value_name, missing_policy)
 abt_std_istable(table) || error("ABT resumir_grupos: esperado tabela")
 group_name isa String && group_name in table.columns || error("ABT resumir_grupos: coluna de grupo inexistente " * repr(group_name))
 value_name isa String && value_name in table.columns || error("ABT resumir_grupos: coluna de valor inexistente " * repr(value_name))
 group_name != value_name || error("ABT resumir_grupos: grupo e valor devem ser colunas distintas")
 missing_policy in ("erro", "ignorar_linha") || error("ABT resumir_grupos: política de ausentes deve ser erro ou ignorar_linha")
 table.types[findfirst(==(group_name), table.columns)] == "texto" || error("ABT resumir_grupos: coluna de grupo deve ser texto")
 kind = table.types[findfirst(==(value_name), table.columns)]
 kind in ("inteiro", "real") || error("ABT resumir_grupos: coluna de valor deve ser numérica")
 order = String[]
 groups = Dict{String,Tuple{Int,Any,Any,Any}}()
 read_count = 0
 skipped = 0
 try
  for row in table.rows
   read_count = Base.checked_add(read_count, 1)
   group = getproperty(row, Symbol(group_name))
   value = getproperty(row, Symbol(value_name))
   if group === missing || value === missing
    if missing_policy == "erro"
     name = group === missing ? group_name : value_name
     error("ABT resumir_grupos: registro $read_count, coluna '$name': valor ausente")
    end
    skipped = Base.checked_add(skipped, 1)
    continue
   end
   group isa String || error("ABT resumir_grupos: registro $read_count: grupo incompatível")
   (kind == "inteiro" ? typeof(value) === Int64 : typeof(value) === Float64 && isfinite(value)) ||
    error("ABT resumir_grupos: registro $read_count: valor incompatível ou não finito")
   if haskey(groups, group)
    n, total, low, high = groups[group]
    total = try
     kind == "inteiro" ? Base.checked_add(total, value) : total + value
    catch err
     err isa OverflowError || rethrow()
     error("ABT resumir_grupos: registro $read_count, coluna '$value_name': soma excede Int64")
    end
    isfinite(total) || error("ABT resumir_grupos: registro $read_count: soma não finita")
    groups[group] = (Base.checked_add(n, 1), total, min(low, value), max(high, value))
   else
    push!(order, group)
    groups[group] = (1, value, value, value)
   end
  end
 catch err
  abt_std_table_error("resumir_grupos", table, err)
 end
 summaries = [begin
  n, total, low, high = groups[group]
  (; grupo=group, quantidade=n, soma=total, media=total/n, minimo=low, maximo=high)
 end for group in order]
 return (; grupos=summaries, linhas_lidas=read_count, linhas_ignoradas=skipped)
end
