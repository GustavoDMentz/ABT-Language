# Frequencies for a typed text column. The library counts; ABT fixes order and policy.
function abt_std_category_counts(table, column, missing_policy)
 abt_std_istable(table) || error("ABT contar_categorias: esperado tabela")
 column isa String && column in table.columns ||
  error("ABT contar_categorias: coluna inexistente " * repr(column))
 missing_policy in ("erro", "ignorar_linha") ||
  error("ABT contar_categorias: política de ausentes deve ser erro ou ignorar_linha")
 table.types[findfirst(==(column), table.columns)] == "texto" ||
  error("ABT contar_categorias: coluna deve ser texto")
 values = String[]
 order = String[]
 seen = Set{String}()
 read_count = 0
 skipped = 0
 try
  for row in table.rows
   read_count = Base.checked_add(read_count, 1)
   value = getproperty(row, Symbol(column))
   if value === missing
    missing_policy == "erro" &&
     error("ABT contar_categorias: registro $read_count, coluna '$column': valor ausente")
    skipped = Base.checked_add(skipped, 1)
    continue
   end
   value isa String || error("ABT contar_categorias: registro $read_count: valor incompatível")
   push!(values, value)
   if !(value in seen)
    push!(order, value)
    push!(seen, value)
   end
  end
 catch err
  abt_std_table_error("contar_categorias", table, err)
 end
 isempty(values) && return (; categorias=NamedTuple[], linhas_lidas=read_count, linhas_ignoradas=skipped)
 stats = try
  Base.require(Base.PkgId(Base.UUID("2913bbd2-ae8a-5f71-8c99-4fb6c76f3a91"), "StatsBase"))
 catch err
  error("ABT contar_categorias: StatsBase indisponível: " * sprint(showerror, err))
 end
 counts = try
  Base.invokelatest(stats.countmap, values)
 catch err
  error("ABT contar_categorias: StatsBase: " * sprint(showerror, err))
 end
 categories = [(; categoria=name, quantidade=counts[name], proporcao=counts[name]/length(values)) for name in order]
 return (; categorias=categories, linhas_lidas=read_count, linhas_ignoradas=skipped)
end
