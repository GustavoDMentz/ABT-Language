# Shared deterministic presentation. No program state is stored here.
abt_std_istable(x) = x isa NamedTuple && keys(x) == (:__abt_table__, :rows, :columns, :types, :source) &&
                     x.__abt_table__ === true
function abt_std_table_error(operation, table, err)
 message = sprint(showerror, err)
 startswith(message, "ABT ") && throw(err)
 error("ABT $operation: file '$(table.source)': cause: " * message)
end
function abt_std_render(x, nested=false)
 if x isa NamedTuple && keys(x) == (:__abt_fasta__, :path, :alphabet, :ambiguity, :case_policy) && x.__abt_fasta__ === true
  return "fasta(arquivo=" * repr(x.path) * ", alfabeto=" * repr(x.alphabet) * ")"
 elseif abt_std_istable(x)
  try
   return "tabela(" * join((abt_std_render(row, true) for row in x.rows), ", ") * ")"
  catch err
   abt_std_table_error("mostrar", x, err)
  end
 elseif x isa NamedTuple
  content = join((string(k) * " = " * abt_std_render(v, true) for (k,v) in pairs(x)), ", ")
  return "(" * content * (length(x) == 1 ? "," : "") * ")"
 elseif x isa AbstractVector
  return "[" * join((abt_std_render(v, true) for v in x), ", ") * "]"
 elseif x isa String
  return nested ? repr(x) : x
 elseif x === missing
  return "ausente"
 end
 return Base.invokelatest(string, x)
end
