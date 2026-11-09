# Shared implementation: included by the interpreter and embedded in generated Julia.
# No output or implicit conversions occur in these analytical operations.
function abt_std_record(args...)
 length(args) >= 2 && iseven(length(args)) ||
  error("ABT registro: expected one or more name/value pairs")
 keys = String[]
 values = Any[]
 for i in 1:2:length(args)
  key = args[i]
  key isa String && occursin(r"^[^\W\d]\w*$", key) && !startswith(key, "_") ||
   error("ABT registro: invalid field name")
  key in keys && error("ABT registro: duplicate field '$key'")
  push!(keys, key)
  push!(values, args[i+1])
 end
 return NamedTuple{Tuple(Symbol.(keys))}(Tuple(values))
end

function abt_std_describe(xs, stats)
 xs isa Vector || error("ABT descrever: expected a Vector of finite real numbers")
 length(xs) >= 2 || error("ABT descrever: at least two values required")
 all(x -> (typeof(x) === Int64 || typeof(x) === Float64) && isfinite(x), xs) ||
  error("ABT descrever: expected finite Int64 or Float64 values without missing values")
 total = 0
 for x in xs
  if typeof(total) === Int64 && typeof(x) === Int64
   total = try
    Base.checked_add(total, x)
   catch err
    err isa OverflowError || rethrow()
    error("ABT descrever: sum overflow")
   end
  else
   total += x
  end
  isfinite(total) || error("ABT descrever: nonfinite sum")
 end
 average = stats.mean(xs)
 median = stats.median(xs)
 deviation = stats.std(xs)
 all(isfinite, (average, median, deviation)) || error("ABT descrever: nonfinite result")
 return (quantidade=length(xs), soma=total, media=average,
         mediana=median, desvio_padrao=deviation,
         minimo=minimum(xs), maximo=maximum(xs))
end

# CSV is loaded only when used. CSV.Rows implements the Tables.jl interface and
# is re-iterable, so reading/filtering does not materialize the whole file.
abt_std_table(rows, columns, types, source) =
 (; __abt_table__=true, rows=rows, columns=columns, types=types, source=source)

function abt_std_text(path)
 path isa String && !isempty(path) || error("ABT ler_texto: path must be nonempty text")
 try
  return read(path, String)
 catch err
  error("ABT ler_texto: file '$path': " * sprint(showerror, err))
 end
end

function abt_std_environment(name, fallback)
 name isa String && !isempty(name) || error("ABT ambiente: variable name must be nonempty text")
 fallback isa String || error("ABT ambiente: fallback must be text")
 return get(ENV, name, fallback)
end

function abt_std_text_arg(operation, value)
 value isa String || error("ABT $operation: expected text")
 return value
end
abt_std_lines(value) = readlines(IOBuffer(abt_std_text_arg("linhas_texto", value)))
abt_std_strip(value) = String(strip(abt_std_text_arg("aparar", value)))
abt_std_uppercase(value) = uppercase(abt_std_text_arg("maiusculas", value))
function abt_std_startswith(value, prefix)
 return startswith(abt_std_text_arg("inicia_com", value), abt_std_text_arg("inicia_com", prefix))
end
abt_std_text_length(value) = length(abt_std_text_arg("comprimento_texto", value))
function abt_std_char_count(value, character)
 value = abt_std_text_arg("contar_caractere", value)
 character = abt_std_text_arg("contar_caractere", character)
 length(character) == 1 || error("ABT contar_caractere: expected exactly one character")
 return count(==(only(character)), value)
end
function abt_std_fail(message)
 message isa String || error("ABT falhar: expected text")
 error("ABT: " * message)
end

function abt_std_schema(args...)
 result = abt_std_record(args...)
 for (name, kind) in pairs(result)
  kind isa String && kind in ("texto", "inteiro", "real", "booleano") ||
   error("ABT esquema: column '$name' requires texto, inteiro, real or booleano")
 end
 return result
end

function abt_std_convert(raw, kind::String, policy::String, path::String, row::Int, column::String)
 if raw === missing
  policy == "permitir" && return missing
  error("ABT CSV: file '$path', row $row, column '$column': missing field")
 end
 raw isa String || error("ABT CSV: file '$path', row $row, column '$column': expected text field")
 try
  if kind == "texto"
   return raw
  elseif kind == "inteiro"
   return parse(Int64, raw)
  elseif kind == "real"
   value = parse(Float64, raw)
   isfinite(value) || error("nonfinite number")
   return value
  else
   raw == "true" && return true
   raw == "false" && return false
   error("expected true or false")
  end
 catch err
  error("ABT CSV: file '$path', row $row, column '$column': invalid $kind value " * repr(raw) * "; cause: " * sprint(showerror, err))
 end
end

function abt_std_csv_row(raw, columns, types, policy, path, index)
 values = ntuple(i -> abt_std_convert(Base.invokelatest(getproperty, raw, Symbol(columns[i])), types[i],
                  policy, path, index, columns[i]), length(columns))
 return NamedTuple{Tuple(Symbol.(columns))}(values)
end

function abt_std_csv(path, schema, policy, delimiter=",")
 path isa String && !isempty(path) || error("ABT ler_csv: path must be nonempty text")
 schema isa NamedTuple && !isempty(schema) || error("ABT ler_csv: nonempty explicit schema required")
 policy in ("erro", "permitir") || error("ABT ler_csv: missing policy must be erro or permitir")
 delimiter isa String && length(delimiter) == 1 || error("ABT ler_csv: delimiter must be one character")
 separator = only(delimiter)
 columns = collect(String.(keys(schema))); types = String[]
 for (name, kind) in pairs(schema)
  kind isa String && kind in ("texto", "inteiro", "real", "booleano") ||
   error("ABT ler_csv: invalid type for column '$name'")
  push!(types, kind)
 end
 try
  csv = Base.require(Base.PkgId(Base.UUID("336ed68f-0bac-5ca0-87d4-7b16caf5d00b"), "CSV"))
  tables = Base.require(Base.PkgId(Base.UUID("bd369af6-aec1-5ad0-b16a-f7cc5008161c"), "Tables"))
  header_rows = Base.invokelatest(csv.Rows, path; header=false, limit=1, types=String, delim=separator,
                                  missingstring=nothing, strict=true, normalizenames=false)
  first_header = Base.invokelatest(iterate, header_rows)
  first_header === nothing && error("empty file or missing header")
  raw_header = collect(Base.invokelatest(Tuple, first_header[1]))
  all(x -> x isa String && !isempty(x), raw_header) || error("empty or missing header name")
  length(unique(raw_header)) == length(raw_header) || error("duplicate header")
  raw_header == columns || error("header does not match explicit schema; found " * repr(raw_header))
  raw_rows = Base.invokelatest(csv.Rows, path; types=String, missingstring=nothing, delim=separator,
                               strict=true, normalizenames=false)
  parsed = Base.invokelatest(tables.schema, raw_rows)
  collect(String.(Base.invokelatest(getproperty, parsed, :names))) == columns ||
   error("CSV header changed during reading")
  converted = (abt_std_csv_row(raw, columns, types, policy, path, index + 1)
               for (index, raw) in enumerate(raw_rows))
  return abt_std_table(converted, columns, types, path)
 catch err
  msg = sprint(showerror, err)
  startswith(msg, "ABT ") && rethrow()
  error("ABT ler_csv: file '$path': " * msg)
 end
end

function abt_std_column(table, name)
 abt_std_istable(table) || error("ABT coluna: expected a table")
 name isa String && name in table.columns || error("ABT coluna: unknown column " * repr(name))
 try
  return [getproperty(row, Symbol(name)) for row in table.rows]
 catch err
  abt_std_table_error("coluna", table, err)
 end
end
function abt_std_table_rows(table)
 abt_std_istable(table) || error("ABT linhas_tabela: expected a table")
 try
  return collect(table.rows)
 catch err
  abt_std_table_error("linhas_tabela", table, err)
 end
end

function abt_std_filter_table(table, name, operator, value)
 abt_std_istable(table) || error("ABT filtrar_tabela: expected a table")
 name isa String && name in table.columns || error("ABT filtrar_tabela: unknown column " * repr(name))
 operator isa String && operator in ("==", "!=", ">", ">=", "<", "<=") ||
  error("ABT filtrar_tabela: unsupported operator")
 kind = table.types[findfirst(==(name), table.columns)]
 kind == "booleano" && !(operator in ("==", "!=")) &&
  error("ABT filtrar_tabela: boolean columns support only == and !=")
 valid = kind == "texto" ? value isa String : kind == "inteiro" ? typeof(value) === Int64 :
         kind == "real" ? typeof(value) === Float64 && isfinite(value) : value isa Bool
 valid || error("ABT filtrar_tabela: incompatible comparison value for '$name'")
 predicate(row) = begin
  x = getproperty(row, Symbol(name))
  x === missing && error("ABT filtrar_tabela: missing value in column '$name'; choose an explicit missing policy")
  operator == "==" ? x == value : operator == "!=" ? x != value :
  operator == ">" ? x > value : operator == ">=" ? x >= value :
  operator == "<" ? x < value : x <= value
 end
 return abt_std_table(Iterators.filter(predicate, table.rows), table.columns, table.types, table.source)
end

function abt_std_transform_table(table, source, destination, operator, operand, destination_type)
 abt_std_istable(table) || error("ABT transformar_tabela: expected a table")
 source isa String && source in table.columns || error("ABT transformar_tabela: unknown source column " * repr(source))
 destination isa String && occursin(r"^[^\W\d]\w*$", destination) &&
  !startswith(destination, "_") && !(destination in table.columns) ||
  error("ABT transformar_tabela: invalid or existing destination column")
 operator isa String && operator in ("+", "-", "*", "/") ||
  error("ABT transformar_tabela: unsupported operator")
 source_type = table.types[findfirst(==(source), table.columns)]
 source_type in ("inteiro", "real") || error("ABT transformar_tabela: numeric source required")
 destination_type isa String && destination_type in ("inteiro", "real") ||
  error("ABT transformar_tabela: numeric destination type required")
 (source_type == "inteiro" ? typeof(operand) === Int64 : typeof(operand) === Float64 && isfinite(operand)) ||
  error("ABT transformar_tabela: incompatible operand")
 function transform(row)
  x = getproperty(row, Symbol(source))
  x === missing && error("ABT transformar_tabela: missing value in column '$source'")
  result = operator == "+" ? (source_type == "inteiro" ? Base.checked_add(x, operand) : x + operand) :
           operator == "-" ? (source_type == "inteiro" ? Base.checked_sub(x, operand) : x - operand) :
           operator == "*" ? (source_type == "inteiro" ? Base.checked_mul(x, operand) : x * operand) : x / operand
  (destination_type == "inteiro" ? typeof(result) === Int64 :
   typeof(result) === Float64 && isfinite(result)) ||
   error("ABT transformar_tabela: result does not match declared type '$destination_type'")
  return merge(row, NamedTuple{(Symbol(destination),)}((result,)))
 end
 return abt_std_table(Iterators.map(transform, table.rows),
                      vcat(table.columns, [destination]), vcat(table.types, [destination_type]), table.source)
end

function abt_std_summarize(table, name)
 abt_std_istable(table) || error("ABT resumir_coluna: expected a table")
 name isa String && name in table.columns || error("ABT resumir_coluna: unknown column " * repr(name))
 kind = table.types[findfirst(==(name), table.columns)]
 kind in ("inteiro", "real") || error("ABT resumir_coluna: numeric column required")
 count = 0; total = kind == "inteiro" ? Int64(0) : Float64(0)
 low = nothing; high = nothing
 try
 for (index, row) in enumerate(table.rows)
  x = getproperty(row, Symbol(name))
  x === missing && error("ABT resumir_coluna: file '$(table.source)', row $(index+1), column '$name': missing value")
  total = try
   kind == "inteiro" ? Base.checked_add(total, x) : total + x
  catch err
   err isa OverflowError || rethrow()
   error("ABT resumir_coluna: file '$(table.source)', row $(index+1), column '$name': sum overflow")
  end
  isfinite(total) || error("ABT resumir_coluna: file '$(table.source)', row $(index+1), column '$name': nonfinite total")
  low = low === nothing ? x : min(low, x)
  high = high === nothing ? x : max(high, x)
 count += 1
 end
 catch err
  abt_std_table_error("resumir_coluna", table, err)
 end
 count > 0 || error("ABT resumir_coluna: empty table")
 return (quantidade=count, soma=total, media=total/count, minimo=low, maximo=high)
end
