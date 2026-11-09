# Explicit conversion from ABT values to JSON-compatible Julia values.
function abt_std_json_value(value, policy, active, path)
 if value === missing
  policy == "nulo" || error("ABT codificar_json: $path: valor ausente")
  return nothing
 elseif abt_std_istable(value)
  try
   rows = [abt_std_json_value(row, policy, active, "$path.registros[$i]") for (i,row) in enumerate(value.rows)]
   return (; colunas=copy(value.columns), registros=rows)
  catch err
   abt_std_table_error("codificar_json", value, err)
  end
 elseif value isa NamedTuple
  values = map(pair -> abt_std_json_value(last(pair), policy, active, "$path.$(first(pair))"), collect(pairs(value)))
  return NamedTuple{keys(value)}(Tuple(values))
 elseif value isa AbstractVector
  haskey(active, value) && error("ABT codificar_json: $path: coleção cíclica")
  active[value] = true
  try
   return [abt_std_json_value(item, policy, active, "$path[$i]") for (i,item) in enumerate(value)]
  finally
   delete!(active, value)
  end
 elseif value isa String || value isa Bool || typeof(value) === Int64
  return value
 elseif typeof(value) === Float64 && isfinite(value)
  return value
 end
 error("ABT codificar_json: $path: tipo não suportado ou número não finito ($(typeof(value)))")
end

function abt_std_json(value, missing_policy)
 missing_policy in ("erro", "nulo") || error("ABT codificar_json: política de ausentes deve ser erro ou nulo")
 normalized = abt_std_json_value(value, missing_policy, IdDict{Any,Bool}(), "valor")
 json = try
  Base.require(Base.PkgId(Base.UUID("682c06a0-de6a-54ab-a142-c8b1cf79cde6"), "JSON"))
 catch err
  error("ABT codificar_json: biblioteca JSON indisponível: " * sprint(showerror, err))
 end
 try
  return Base.invokelatest(json.json, normalized)
 catch err
  error("ABT codificar_json: biblioteca JSON: " * sprint(showerror, err))
 end
end
