module ABT

import Statistics
import LinearAlgebra
import TOML
include("StdlibRender.jl")
include("Stdlib.jl")
include("StdlibBio.jl")
include("ExtensionRegistry.jl")
const ABT_BIO_NAMES = Set(("ler_fasta", "descrever_sequencias", "registros_fasta", "alinhar_sequencias"))
const ABT_STDLIB_NAMES = union(Set(("descrever", "registro", "falhar", "ambiente", "ler_texto", "linhas_texto", "aparar", "maiusculas", "inicia_com", "comprimento_texto", "contar_caractere", "esquema", "ler_csv", "coluna", "linhas_tabela", "filtrar_tabela", "transformar_tabela", "resumir_coluna")), ABT_BIO_NAMES, Set(String.(keys(ABT_EXTENSION_SPECS))))
const ABT_STDLIB = Dict{String,Any}(
 "descrever" => (xs -> abt_std_describe(xs, Statistics)),
 "registro" => abt_std_record,
 "falhar" => abt_std_fail,
 "ambiente" => abt_std_environment,
 "ler_texto" => abt_std_text,
 "linhas_texto" => abt_std_lines,
 "aparar" => abt_std_strip,
 "maiusculas" => abt_std_uppercase,
 "inicia_com" => abt_std_startswith,
 "comprimento_texto" => abt_std_text_length,
 "contar_caractere" => abt_std_char_count,
 "esquema" => abt_std_schema,
 "ler_csv" => abt_std_csv,
 "coluna" => abt_std_column,
 "linhas_tabela" => abt_std_table_rows,
 "filtrar_tabela" => abt_std_filter_table,
 "transformar_tabela" => abt_std_transform_table,
 "resumir_coluna" => abt_std_summarize,
 "ler_fasta" => abt_std_fasta,
 "descrever_sequencias" => abt_std_fasta_summary,
 "registros_fasta" => abt_std_fasta_records)
for (name, spec) in pairs(ABT_EXTENSION_SPECS)
 ABT_STDLIB[String(name)] = spec.implementation
end

# Public, explicitly allowed Julia functions. No dynamic eval or arbitrary imports.
const JULIA_BRIDGE = Dict{String,Dict{String,Int}}(
 "Statistics" => Dict("mean"=>1, "median"=>1, "std"=>1, "var"=>1, "cor"=>2, "cov"=>2),
 "LinearAlgebra" => Dict("norm"=>1, "dot"=>2, "cross"=>2, "normalize"=>1),
 "Base" => Dict("sum"=>1, "prod"=>1, "maximum"=>1, "minimum"=>1,
                "sort"=>1, "reverse"=>1, "length"=>1, "unique"=>1,
                "collect"=>1, "Float64"=>1, "Int64"=>1,
                "String"=>1, "Bool"=>1, "error"=>1),
)

# An explicit call surface for optional Julia packages. Julia's own project and
# manifest remain responsible for installation and dependency resolution.
const ABT_PACKAGE_FILE = joinpath(@__DIR__, "..", "ABT.packages.toml")
Base.include_dependency(ABT_PACKAGE_FILE)
function abt_package_specs(path::String)
 isfile(path) || return Dict{String,NamedTuple{(:uuid,:version,:functions),Tuple{String,String,Dict{String,Int}}}}()
 raw = TOML.parsefile(path)
 Set(keys(raw)) == Set(["julia"]) || error("ABT package manifest: expected only [julia] tables")
 raw["julia"] isa AbstractDict || error("ABT package manifest: [julia] must contain module tables")
 result = Dict{String,NamedTuple{(:uuid,:version,:functions),Tuple{String,String,Dict{String,Int}}}}()
 for (name, entry) in raw["julia"]
  occursin(r"^[A-Za-z][A-Za-z_0-9]*$", name) || error("ABT package manifest: invalid module name '$name'")
  entry isa AbstractDict && Set(keys(entry)) == Set(["uuid", "version", "functions"]) ||
   error("ABT package manifest: $name requires uuid, version and functions")
  uuid = entry["uuid"]; version = entry["version"]; functions = entry["functions"]
  uuid isa String && version isa String && functions isa AbstractDict ||
   error("ABT package manifest: invalid types for $name")
  Base.UUID(uuid); VersionNumber(version)
  isempty(functions) && error("ABT package manifest: $name has no declared functions")
  calls = Dict{String,Int}()
  for (fn, arity) in functions
   occursin(r"^[^\W\d]\w*$", fn) && arity isa Int && 0 <= arity <= 32 ||
    error("ABT package manifest: invalid function declaration $name.$fn")
   calls[fn] = arity
  end
  haskey(JULIA_BRIDGE, name) && error("ABT package manifest: built-in module $name cannot be redefined")
  result[name] = (uuid=uuid, version=version, functions=calls)
 end
 result
end
const ABT_PACKAGES = abt_package_specs(ABT_PACKAGE_FILE)
julia_functions(mod::String) = haskey(JULIA_BRIDGE, mod) ? JULIA_BRIDGE[mod] : ABT_PACKAGES[mod].functions
julia_supported(mod::String) = haskey(JULIA_BRIDGE, mod) || haskey(ABT_PACKAGES, mod)
# PythonCall is optional: importing ABT itself never requires PythonCall.jl.
# Shared loader defined in bridge_runtime.jl; no Python dependency at module load.
const PYTHONCALL_CACHE = Ref{Any}(nothing)
python_runtime() = abt_load_pythoncall!(PYTHONCALL_CACHE)
const PYTHON_IMPORT_PATTERN = r"^[A-Za-z_][A-Za-z_0-9]*(\.[A-Za-z_][A-Za-z_0-9]*)*$"
function checked_python_path(path::String)
 occursin(PYTHON_IMPORT_PATTERN, path) || error("Semantic error: invalid Python module path '$path'")
 startswith(path, "_") && error("Semantic error: private Python module '$path'")
 any(startswith(part, "_") for part in split(path, '.')) && error("Semantic error: private Python module component '$path'")
 return path
end
# Shared interpreter bridge; generated helper remains separate and is checked by regression tests.
include("Runtime/Bridge.jl")

const JULIA_MODULES = Dict{String,Module}(
 "Statistics"=>Statistics, "LinearAlgebra"=>LinearAlgebra, "Base"=>Base)

export tokenize, parse_program, execute, generate, lower_ir, validate_ir, optimize_ir, explain, render_diagnostic

const KEYWORDS = Dict(
 "mostrar"=>"SHOW", "show"=>"SHOW", "media"=>"AVG", "média"=>"AVG", "average"=>"AVG",
 "soma"=>"SUM", "sum"=>"SUM", "de"=>"OF", "of"=>"OF", "onde"=>"WHERE", "where"=>"WHERE",
 "valor"=>"VALUE", "value"=>"VALUE", "é"=>"IS", "is"=>"IS", "maior"=>"ABOVE", "above"=>"ABOVE",
 "menor"=>"BELOW", "below"=>"BELOW", "que"=>"THAN", "than"=>"THAN",
 "se"=>"IF", "if"=>"IF", "senao"=>"ELSE", "senão"=>"ELSE", "else"=>"ELSE",
 "para"=>"FOR", "for"=>"FOR", "cada"=>"EACH", "each"=>"EACH", "em"=>"IN", "in"=>"IN",
 "verdadeiro"=>"TRUE", "true"=>"TRUE", "falso"=>"FALSE", "false"=>"FALSE",
 "e"=>"AND", "and"=>"AND", "ou"=>"OR", "or"=>"OR",
 "função"=>"FUNCTION", "funcao"=>"FUNCTION", "function"=>"FUNCTION",
 "retornar"=>"RETURN", "return"=>"RETURN", "usar"=>"USE")

struct Token
 kind::String
 lexeme::String
 line::Int
 col::Int
end
struct Node
 kind::Symbol
 args::Vector{Any}
end
node(kind, args...) = Node(kind, Any[args...])

function tokenize(src::String)
 tokens = Token[]
 line, col = 1, 1
 i = firstindex(src)
 while i <= lastindex(src)
  c = src[i]
  if c == '\n'
   line += 1; col = 1; i = nextind(src, i); continue
  end
  if c == ' ' || c == '\t' || c == '\r'
   col += 1; i = nextind(src, i); continue
  end
  if c == '#'
   while i <= lastindex(src) && src[i] != '\n'; i = nextind(src, i); end
   continue
  end
  rest = SubString(src, i)
  m = match(r"^(?:\d+(?:\.\d+)?)", rest)
  kind = ""
  lexeme = ""
  if m !== nothing
   kind, lexeme = "NUMBER", m.match
  elseif c == '"'
   m = match(r"^\"(?:\\.|[^\"\\])*\"", rest)
   m === nothing && error("Unterminated string at $line:$col")
   kind, lexeme = "STRING", m.match
  else
   m = match(r"^[^\W\d]\w*", rest)
   if m !== nothing
    lexeme = m.match; kind = get(KEYWORDS, lowercase(lexeme), "IDENT")
   else
    m = match(r"^(?:==|!=|>=|<=|[=+*/^><\-{},;\[\]().])", rest)
    m === nothing && error("Unexpected character $(repr(c)) at $line:$col")
    lexeme = m.match; kind = lexeme
   end
  end
  push!(tokens, Token(kind, lexeme, line, col))
  i = nextind(src, i, length(lexeme)); col += length(lexeme)
 end
 push!(tokens, Token("EOF", "", line, col))
 return expand_pipelines(tokens, src)
end

# A pipeline is lowered to the existing collection expressions before parsing.
# Original token locations are retained for source-level diagnostics.
function expand_pipelines(tokens::Vector{Token}, src::String)
 rawlines = split(src, '\n')
 lines = Vector{Vector{Token}}()
 for t in tokens[1:end-1]
  if isempty(lines) || lines[end][1].line != t.line
   push!(lines, Token[t])
  else
   push!(lines[end], t)
  end
 end
 out = Token[]; i = 1
 function syntax(t::Token, cause)
  error("Pipeline error at $(t.line):$(t.col): $cause")
 end
 function expression_line(ts)
  p = Parser(vcat(ts, Token("EOF", "", ts[end].line, ts[end].col + length(ts[end].lexeme))), 1)
  try
   expr(p)
   return at(p, "EOF")
  catch
   return false
  end
 end
 while i <= length(lines)
  source = lines[i]
  if i < length(lines) && lines[i+1][1].col > source[1].col && expression_line(source)
   stepcol = lines[i+1][1].col
   for line in (source[1].line, lines[i+1][1].line)
    occursin(r"^\s*\t", rawlines[line]) && syntax(lines[i+1][1], "tabs in pipeline indentation are unsupported")
   end
   current = copy(source); j = i + 1; terminal = false
   while j <= length(lines)
    step = lines[j]; col = step[1].col
    occursin(r"^\s*\t", rawlines[step[1].line]) && syntax(step[1], "tabs in pipeline indentation are unsupported")
    col < stepcol && break
    col != stepcol && syntax(step[1], "inconsistent indentation; expected column $stepcol")
    first = step[1]; word = lowercase(first.lexeme)
    if first.kind == "SHOW"
     length(step) == 1 || syntax(first, "mostrar is terminal and takes no argument")
     terminal = true; j += 1; break
    end
    word in ("filtrar", "transformar", "limitar") || syntax(first, "unknown pipeline step '$(first.lexeme)'")
    delimiter = word == "filtrar" ? "WHERE" : word == "transformar" ? "com" : "a"
    length(step) >= 3 || syntax(first, "incomplete $word step")
    second = step[2]
    (second.kind == delimiter || (second.kind == "IDENT" && lowercase(second.lexeme) == delimiter)) ||
      syntax(second, "expected '$delimiter' after $word")
    operand = step[3:end]
    expression_line(operand) || syntax(operand[1], "invalid expression in $word step")
    current = vcat(Token[Token("IDENT", word, first.line, first.col), Token("(", "(", first.line, first.col)],
                   current, Token[Token(")", ")", first.line, first.col), second], operand)
    j += 1
   end
   terminal || syntax(lines[min(j, length(lines))][1], "pipeline requires terminal mostrar at column $stepcol")
   append!(out, Token[Token("SHOW", "mostrar", source[1].line, source[1].col)])
   append!(out, current)
   i = j
  else
   append!(out, source); i += 1
  end
 end
 push!(out, tokens[end]); out
end

mutable struct Parser
 tokens::Vector{Token}
 pos::Int
end
at(p::Parser, kinds...) = p.tokens[p.pos].kind in kinds
# Aggregate names are contextual, but only in unambiguous identifier positions.
const CONTEXT_NAMES = ("SUM", "AVG")
function take_name(p::Parser)
 t = p.tokens[p.pos]
 t.kind in ("IDENT", CONTEXT_NAMES...) || error("Expected IDENT, got $(repr(t.lexeme)) at $(t.line):$(t.col)")
 startswith(t.lexeme, "__abt_") && error("Reserved ABT internal identifier: $(t.lexeme)")
 p.pos += 1
 return t.lexeme
end
function take(p::Parser, expected::Union{Nothing,String}=nothing)
 t = p.tokens[p.pos]
 expected !== nothing && t.kind != expected && error("Expected $expected, got $(repr(t.lexeme)) at $(t.line):$(t.col)")
 p.pos += 1
 return t.lexeme
end
function parse_program(tokens::Vector{Token})
 p = Parser(tokens, 1); result = Node[]
 while !at(p, "EOF")
  if at(p, ";"); take(p); continue; end
  push!(result, statement(p))
 end
 return result
end
function block(p)
 take(p, "{"); items = Node[]
 while !at(p, "}")
  at(p, "EOF") && error("Unclosed block")
  if at(p, ";"); take(p); continue; end
  push!(items, statement(p))
 end
 take(p, "}"); items
end
function statement(p)
 if at(p, "USE")
  take(p); root = take_name(p); take(p, "."); mod = take_name(p)
  if root == "Python"
   parts = String[mod]
   while at(p, ".")
    take(p); push!(parts, take_name(p))
   end
   path = checked_python_path(join(parts, "."))
   return node(:import_python, path)
  end
  root == "Julia" || error("Semantic error: only Julia and Python modules are supported")
  julia_supported(mod) || error("Semantic error: unsupported Julia module '$mod'")
  return node(:import_julia, mod)
 elseif at(p, "SHOW")
  take(p); return node(:show, expr(p))
 elseif at(p, "IF")
  take(p); condition = expr(p); yes = block(p)
  no = Node[]
  if at(p, "ELSE"); take(p); no = block(p); end
  return node(:if, condition, yes, no)
 elseif at(p, "FUNCTION")
  take(p); name = take_name(p); take(p, "(")
  params = String[]
  if !at(p, ")")
   push!(params, take_name(p))
   while at(p, ","); take(p); push!(params, take_name(p)); end
  end
  take(p, ")"); return node(:function, name, params, block(p))
 elseif at(p, "RETURN")
  take(p); return node(:return, expr(p))
 elseif at(p, "FOR")
  take(p); take(p, "EACH"); name = take_name(p); take(p, "IN")
  collection = expr(p); return node(:for, name, collection, block(p))
 else
  name = take_name(p); take(p, "="); return node(:assign, name, expr(p))
 end
end
expr(p) = disjunction(p)
function disjunction(p)
 n = conjunction(p)
 while at(p, "OR")
  op = take(p); n = node(:bin, op, n, conjunction(p))
 end
 n
end
function conjunction(p)
 n = compare(p)
 while at(p, "AND")
  op = take(p); n = node(:bin, op, n, compare(p))
 end
 n
end
function compare(p)
 n = add(p)
 while at(p, "IS", ">", "<", ">=", "<=", "==", "!=")
  op = take(p)
  if op in ("is", "é")
   if at(p, "ABOVE", "BELOW")
    direction = take(p)
    if at(p, "THAN"); take(p); end
    op = direction in ("above", "maior") ? ">" : "<"
   else
    op = "=="
   end
  end
  n = node(:bin, op, n, add(p))
 end
 n
end
function add(p)
 n = mul(p)
 while at(p, "+", "-")
  op = take(p); n = node(:bin, op, n, mul(p))
 end
 n
end
function mul(p)
 n = unary(p)
 while at(p, "*", "/")
  op = take(p); n = node(:bin, op, n, unary(p))
 end
 n
end
function unary(p)
 if at(p, "+", "-")
  op = take(p); return node(:unary, op, unary(p))
 end
 return power(p)
end
function power(p)
 n = atom(p)
 if at(p, "^")
  take(p); return node(:bin, "^", n, unary(p))
 end
 n
end
function collection_form(p::Parser, word::String, delimiter::String)
 p.tokens[p.pos].kind == "IDENT" && lowercase(p.tokens[p.pos].lexeme) == word || return false
 p.pos < length(p.tokens) || return false
 next = p.tokens[p.pos + 1].kind
 next in ("IDENT", "SUM", "AVG", "[", "NUMBER", "STRING", "TRUE", "FALSE") && return true
 next == "(" || return false
 depth = 0
 for i in p.pos + 1:length(p.tokens)
  kind = p.tokens[i].kind
  if kind == "("; depth += 1
  elseif kind == ")"
   depth -= 1
   if depth == 0
    i < length(p.tokens) || return false
    following = p.tokens[i + 1]
    return following.kind == delimiter || (following.kind == "IDENT" && lowercase(following.lexeme) == delimiter)
   end
  end
 end
 return false
end
function atom(p)
 if collection_form(p, "filtrar", "WHERE")
  take(p, "IDENT"); source = atom(p); take(p, "WHERE")
  return node(:filter, source, expr(p))
 elseif collection_form(p, "transformar", "com")
  take(p, "IDENT"); source = atom(p)
  lowercase(take(p, "IDENT")) == "com" || error("Expected 'com' after collection")
  return node(:map, source, expr(p))
 elseif collection_form(p, "limitar", "a")
  take(p, "IDENT"); source = atom(p)
  lowercase(take(p, "IDENT")) == "a" || error("Expected 'a' after collection")
  return node(:limit, source, atom(p))
 elseif at(p, "AVG", "SUM") && p.pos < length(p.tokens) && p.tokens[p.pos+1].kind == "OF"
  op = take(p); take(p, "OF"); source = atom(p)
  condition = nothing
  if at(p, "WHERE"); take(p); condition = expr(p); end
  return node(:agg, op in ("average", "media", "média") ? :avg : :sum, source, condition)
 elseif at(p, "NUMBER")
  s = take(p); return node(:lit, occursin('.', s) ? Base.parse(Float64, s) : Base.parse(Int64, s))
 elseif at(p, "STRING")
  s = take(p); return node(:lit, Base.unescape_string(chop(s; head=1, tail=1)))
 elseif at(p, "TRUE", "FALSE")
  return node(:lit, lowercase(take(p)) in ("true", "verdadeiro"))
 elseif at(p, "[")
  take(p); items = Node[]
  if !at(p, "]")
   push!(items, expr(p))
   while at(p, ","); take(p); push!(items, expr(p)); end
  end
  take(p, "]"); return node(:list, items)
 elseif at(p, "(")
  take(p); n = expr(p); take(p, ")"); return n
 elseif at(p, "IDENT", "VALUE", "SUM", "AVG")
  n = node(:var, take(p))
  while at(p, "OF", ".", "(")
   if at(p, "(")
    take(p); args = Node[]
    if !at(p, ")")
     push!(args, expr(p))
     while at(p, ","); take(p); push!(args, expr(p)); end
    end
    take(p, ")"); n = node(:call, n, args)
   elseif at(p, "OF", ".")
   if at(p, ".")
    take(p); property = take_name(p); n = node(:prop, n, property)
   else
    take(p); target = atom(p)
    n.kind == :var || error("Invalid property access")
    n = node(:prop, target, n.args[1])
   end
   end
  end
  return n
 end
 t = p.tokens[p.pos]; error("Unexpected token $(repr(t.lexeme)) at $(t.line):$(t.col)")
end

# Names assigned in a function belong to that invocation, including inside IF/FOR.
# Nested functions are not part of the ABT 0.9.x contract.
function abt_local_writes(nodes::Vector{Node})
 names = Set{String}()
 function visit(items)
  for n in items
   if n.kind == :assign || n.kind == :for
    push!(names, n.args[1])
   end
   if n.kind == :if
    visit(n.args[2]); visit(n.args[3])
   elseif n.kind == :for
    visit(n.args[3])
   end
  end
 end
 visit(nodes)
 return names
end
struct ABTReturn
 value::Any
end
struct ABTFunction
 params::Vector{String}
 body::Vector{Node}
end

function abt_unary(op, value)
 (typeof(value) === Int64 || typeof(value) === Float64) ||
  error("Semantic error: unary $op requires a number")
 return op == "+" ? +value : -value
end

function evalnode(n::Node, env::Dict{String,Any})
 k, a = n.kind, n.args
 if k == :lit; return a[1]; end
 if k == :var
  haskey(env, a[1]) || error("Undefined variable: $(a[1])")
  return env[a[1]]
 end
 if k == :list; return [evalnode(x, env) for x in a[1]]; end
 if k == :call
  fn = evalnode(a[1], env)
  values = [evalnode(x, env) for x in a[2]]
  if fn isa ABTFunction
   length(values) == length(fn.params) || error("Runtime error: wrong argument count")
   localenv = Dict{String,Any}(k => v for (k,v) in env if v isa ABTFunction || k in ABT_STDLIB_NAMES)
   localenv["__abt_output__"] = get(env, "__abt_output__", String[])
   for (name, value) in zip(fn.params, values); localenv[name] = value; end
   returned = execute_unchecked(fn.body; env=localenv, output=get(env, "__abt_output__", String[]), in_function=true)
   return returned isa ABTReturn ? returned.value : nothing
  end
  # Julia callable structs, closures and Python proxy objects share one invocation path.
  return abt_invoke(fn, values...)
 end
 if k == :prop
  target = evalnode(a[1], env)
  return abt_external_field(target, a[2])
 end
 if k == :unary
  return abt_unary(a[1], evalnode(a[2], env))
 end
 if k == :bin
  op = a[1]; left = evalnode(a[2], env)
  if op in ("and", "e") && !left; return false; end
  if op in ("or", "ou") && left; return true; end
  right = evalnode(a[3], env)
  if op == "+"; return left + right
  elseif op == "-"; return left - right
  elseif op == "*"; return left * right
  elseif op == "^"; return left ^ right
  elseif op == "/"; return left / right
  elseif op == ">"; return left > right
  elseif op == "<"; return left < right
  elseif op == ">="; return left >= right
  elseif op == "<="; return left <= right
  elseif op == "=="; return left == right
  elseif op == "!="; return left != right
  elseif op in ("and", "e"); return Bool(left && right)
  elseif op in ("or", "ou"); return Bool(left || right)
  end
 end
 if k == :agg
  values = evalnode(a[2], env)
  total = 0; count = 0
  for value in values
   scope = copy(env); scope["value"] = value; scope["valor"] = value
   if a[3] === nothing || evalnode(a[3], scope)
    total += value; count += 1
   end
  end
  if a[1] == :sum; return total; end
  count > 0 || error("Cannot average an empty selection")
  return total / count
 end
 if k in (:filter, :map, :limit)
  values = evalnode(a[1], env)
  values isa Vector || error("Semantic error: collection operation requires a Vector")
  if k == :limit
   count = evalnode(a[2], env)
   typeof(count) === Int64 && count >= 0 || error("Semantic error: limit requires a nonnegative Int64")
   return values[1:min(count, length(values))]
  end
  function with_value(value)
   scope = copy(env); scope["value"] = value; scope["valor"] = value
   return evalnode(a[2], scope)
  end
  if k == :filter
   return filter(values) do value
    selected = with_value(value)
    selected isa Bool || error("Semantic error: filter predicate must be Bool")
    selected
   end
  end
  isempty(values) && return Any[]
  return map(with_value, values)
 end
 error("Unsupported expression: $k")
end
function execute_unchecked(nodes::Vector{Node}; env=Dict{String,Any}(), output=String[], in_function=false)
 env["__abt_output__"] = output
 # Top-level declarations are available before their textual occurrence.
 if !in_function
  for declaration in nodes
   if declaration.kind == :function
    env[declaration.args[1]] = ABTFunction(declaration.args[2], declaration.args[3])
   end
  end
 end
 for n in nodes
  a = n.args
  if n.kind == :assign
   env[a[1]] = evalnode(a[2], env)
  elseif n.kind == :show
   push!(output, Base.invokelatest(abt_std_render, evalnode(a[1], env)))
  elseif n.kind == :import_python
   path = checked_python_path(a[1]); py = python_runtime()
   # Keep Python objects on the Python side, without eager array conversions.
   modules = get!(env, "Python") do
    ABTPythonNamespace()
   end
   abt_import_python!(modules, path, py.pyimport)
  elseif n.kind == :import_julia
   # Deliberately narrow initial bridge; no eval of user-supplied code.
   modules = get!(env, "Julia") do
    Dict{String,Any}()
   end
   modules[a[1]] = haskey(JULIA_MODULES, a[1]) ? JULIA_MODULES[a[1]] :
    abt_load_julia_package(a[1], ABT_PACKAGES[a[1]].uuid, ABT_PACKAGES[a[1]].version)
  elseif n.kind == :function
   # Already registered in the top-level declaration pass.
   in_function && error("Runtime error: nested function declaration")
  elseif n.kind == :return
   in_function || error("Runtime error: RETURN outside function")
   return ABTReturn(evalnode(a[1], env))
  elseif n.kind == :if
   result = execute_unchecked(evalnode(a[1], env) ? a[2] : a[3]; env, output, in_function)
   result isa ABTReturn && return result
  elseif n.kind == :for
   for v in evalnode(a[2], env)
    env[a[1]] = v
    result = execute_unchecked(a[3]; env, output, in_function)
    result isa ABTReturn && return result
   end
  end
 end
 output
end

# Validate before interpreting so both execution paths agree on definite assignment.
function execute(nodes::Vector{Node}; env=Dict{String,Any}(), output=String[])
 any(startswith(k, "__abt_") for k in keys(env)) &&
  error("Semantic error: reserved internal environment key")
 declarations = Set(n.args[1] for n in nodes if n.kind == :function)
 runtime_env = Dict{String,Any}(k => v for (k,v) in ABT_STDLIB if !(k in declarations))
 merge!(runtime_env, env)
 validate_ir(lower_ir(nodes); initial_names=Dict{String,Symbol}(k => :unknown for k in keys(env)))
 return execute_unchecked(nodes; env=runtime_env, output)
end

quotejl(s::AbstractString) = repr(String(s))
# ABT identifiers never enter generated Julia source as bare user-controlled names.
# Hex-encoded UTF-8 avoids Julia keywords, Unicode normalization surprises,
# helper collisions, and accidental capture of imported symbols.
abt_julia_name(s::AbstractString) = "__abt_user_" * bytes2hex(codeunits(String(s)))

# A semantic, structured IR. This is deliberately unoptimized; the code
# generator remains AST-based in v0.3 until equivalence is fully tested.
struct IR
 op::Symbol
 operands::Vector{Any}
end
function abt_ir_local_writes(items::Vector{IR})
 names = Set{String}()
 function visit(xs)
  for n in xs
   if n.op == :store || n.op == :foreach
    push!(names, n.operands[1])
   end
   if n.op == :branch
    visit(n.operands[2]); visit(n.operands[3])
   elseif n.op == :foreach
    visit(n.operands[3])
   end
  end
 end
 visit(items)
 return names
end

ir(op, operands...) = IR(op, Any[operands...])

function lower_expr(n::Node)
 a = n.args
 if n.kind == :lit; return ir(:constant, a[1]); end
 if n.kind == :var; return ir(:load, a[1]); end
 if n.kind == :list; return ir(:list, [lower_expr(x) for x in a[1]]); end
 if n.kind == :prop; return ir(:field, lower_expr(a[1]), a[2]); end
 if n.kind == :unary; return ir(:unary, a[1], lower_expr(a[2])); end
 if n.kind == :bin
  op = get(Dict("and"=>"&&", "e"=>"&&", "or"=>"||", "ou"=>"||"), a[1], a[1])
  return ir(:binary, op, lower_expr(a[2]), lower_expr(a[3]))
 end
 if n.kind == :call; return ir(:call, lower_expr(a[1]), [lower_expr(x) for x in a[2]]); end
 if n.kind == :agg
  predicate = a[3] === nothing ? nothing : lower_expr(a[3])
  return ir(:aggregate, a[1], lower_expr(a[2]), predicate)
 end
 if n.kind == :filter; return ir(:filter, lower_expr(a[1]), lower_expr(a[2])); end
 if n.kind == :map; return ir(:map, lower_expr(a[1]), lower_expr(a[2])); end
 if n.kind == :limit; return ir(:limit, lower_expr(a[1]), lower_expr(a[2])); end
 error("Unknown expression node: $(n.kind)")
end
function lower_ir(nodes::Vector{Node})
 result = IR[]
 for n in nodes
  a = n.args
  if n.kind == :assign
   push!(result, ir(:store, a[1], lower_expr(a[2])))
  elseif n.kind == :show
   push!(result, ir(:print, lower_expr(a[1])))
  elseif n.kind == :if
   push!(result, ir(:branch, lower_expr(a[1]), lower_ir(a[2]), lower_ir(a[3])))
  elseif n.kind == :import_julia
   push!(result, ir(:import_julia, a[1]))
  elseif n.kind == :import_python
   push!(result, ir(:import_python, a[1]))
  elseif n.kind == :function
   push!(result, ir(:function, a[1], a[2], lower_ir(a[3])))
  elseif n.kind == :return
   push!(result, ir(:return, lower_expr(a[1])))
  elseif n.kind == :for
   push!(result, ir(:foreach, a[1], lower_expr(a[2]), lower_ir(a[3])))
  else
   error("Unknown statement node: $(n.kind)")
  end
 end
 result
end


# v0.4: all code generation consumes the IR, never the AST.
# The checker verifies names, basic expression types, and control flow.
# :unknown means a type cannot yet be established statically.
# Only values with an exact, portable Julia source representation are legal IR literals.
# In particular, string(x) is NOT a serializer for arbitrary external objects.
function abt_literal_source(value)
 if value === nothing
  return "nothing"
 elseif value isa Bool
  return value ? "true" : "false"
 elseif value isa String
  return quotejl(value)
 elseif typeof(value) === Int64
  return string(value)
 elseif typeof(value) === Float64
  if isnan(value)
   return "NaN"
  elseif isinf(value)
   return signbit(value) ? "-Inf" : "Inf"
  end
  return repr(value)
 end
 error("Semantic error: unsupported IR constant type '$(typeof(value))'")
end

# Check the public IR boundary before semantic inference or code emission.
# Malformed caller-supplied IR must not leak BoundsError/MethodError from internals.
function abt_check_ir_shape(program::Vector{IR})
 const_budget = 100_000 # Maximum expanded visits per expression; bounded work for shared DAGs.
 visits = Ref(0)
 function tick!()
  visits[] += 1
  visits[] <= const_budget || error("Semantic error: malformed IR: structural validation budget exceeded")
 end
 # IR nodes are immutable, but their operand vectors are mutable and can
 # contain cycles. Guard the graph before any recursive semantic walk.
 active = IdDict{Any,Bool}()
 visited = IdDict{Any,Bool}()
 function inspect(value, depth)
  depth > 256 && error("Semantic error: malformed IR: nesting limit exceeded")
  if value isa IR
   inspect(value.operands, depth + 1)
  elseif value isa AbstractVector
   haskey(active, value) && error("Semantic error: malformed IR: cyclic operand graph")
   haskey(visited, value) && return
   active[value] = true
   try
    for item in value
     (item isa IR || item isa AbstractVector) && inspect(item, depth + 1)
    end
   finally
    delete!(active, value)
   end
   visited[value] = true
  end
 end
 inspect(program, 0)
 expression_shapes = Dict(:constant => 1, :load => 1, :field => 2,
                          :call => 2, :list => 1, :binary => 3, :unary => 2, :aggregate => 3,
                          :filter => 2, :map => 2, :limit => 2)
 statement_shapes = Dict(:store => 2, :print => 1, :branch => 3,
                         :import_julia => 1, :import_python => 1,
                         :function => 3, :return => 1, :foreach => 3)
 fail(where, msg) = error("Semantic error: malformed IR at $where: $msg")
 function vector_of_ir(value, where)
  value isa Vector{IR} || fail(where, "expected Vector{IR} sequence")
  return value
 end
 function name(value, where)
  value isa String && !isempty(value) || fail(where, "expected nonempty string name")
 end
 function expression(n::IR, where)
  tick!()
  expected = get(expression_shapes, n.op, nothing)
  expected === nothing && fail(where, "unknown expression opcode $(n.op)")
  length(n.operands) == expected || fail(where, "$(n.op) expects $expected operands")
  a = n.operands
  if n.op == :load
   name(a[1], where)
  elseif n.op == :field
   a[1] isa IR || fail(where, "field parent must be IR")
   expression(a[1], where * ".parent"); name(a[2], where)
  elseif n.op == :call
   a[1] isa IR || fail(where, "call target must be IR")
   expression(a[1], where * ".target")
   for (i, child) in enumerate(vector_of_ir(a[2], where))
    expression(child, "$where.arg[$i]")
   end
  elseif n.op == :list
   for (i, child) in enumerate(vector_of_ir(a[1], where))
    expression(child, "$where.item[$i]")
   end
  elseif n.op == :unary
   a[1] in ("+", "-") || fail(where, "unknown unary operator")
   a[2] isa IR || fail(where, "unary operand must be IR")
   expression(a[2], "$where.operand")
  elseif n.op == :binary
   a[1] isa String || fail(where, "binary operator must be string")
   for i in 2:3
    a[i] isa IR || fail(where, "binary operand must be IR")
    expression(a[i], "$where.operand[$i]")
   end
  elseif n.op == :aggregate
   a[1] in (:sum, :avg) || fail(where, "unknown aggregate operation")
   a[2] isa IR || fail(where, "aggregate collection must be IR")
   expression(a[2], where * ".collection")
   if a[3] !== nothing
    a[3] isa IR || fail(where, "aggregate predicate must be IR or nothing")
    expression(a[3], where * ".predicate")
   end
  elseif n.op in (:filter, :map, :limit)
   for i in 1:2
    a[i] isa IR || fail(where, "$(n.op) operand must be IR")
    expression(a[i], "$where.operand[$i]")
   end
  end
 end
 function statements(items, where)
  for (i, n) in enumerate(vector_of_ir(items, where))
   at = "$where[$i]"
   expected = get(statement_shapes, n.op, nothing)
   expected === nothing && fail(at, "unknown statement opcode $(n.op)")
   length(n.operands) == expected || fail(at, "$(n.op) expects $expected operands")
   a = n.operands
   if n.op in (:store, :foreach)
    name(a[1], at)
   elseif n.op in (:import_julia, :import_python)
    name(a[1], at)
   elseif n.op == :function
    name(a[1], at)
    a[2] isa Vector{String} && all(!isempty, a[2]) || fail(at, "invalid parameter list")
   end
   if n.op in (:store, :print, :return)
    index = n.op == :store ? 2 : 1
    a[index] isa IR || fail(at, "expected expression IR")
    visits[] = 0
    expression(a[index], at * ".expr")
   elseif n.op == :branch
    a[1] isa IR || fail(at, "expected condition IR")
    visits[] = 0
    expression(a[1], at * ".condition")
    statements(a[2], at * ".yes"); statements(a[3], at * ".no")
   elseif n.op == :foreach
    a[2] isa IR || fail(at, "expected iterable IR")
    visits[] = 0
    expression(a[2], at * ".iterable")
    statements(a[3], at * ".body")
   elseif n.op == :function
    statements(a[3], at * ".body")
   end
  end
 end
 statements(program, "program")
 return program
end

function abt_check_initial_names(initial_names)
 initial_names isa AbstractDict || error("Semantic error: initial_names must be a dictionary")
 allowed = Set((:unknown, :external, :number, :bool, :string, :list))
 checked = Dict{String,Symbol}()
 for (key, kind) in initial_names
  key isa String && !isempty(key) || error("Semantic error: invalid initial variable name")
  (key in ("Python", "Julia") || startswith(key, "__julia_")) &&
   error("Semantic error: reserved initial variable name '$key'")
  any(iscntrl, key) && error("Semantic error: control character in initial variable name")
  kind isa Symbol && kind in allowed ||
   error("Semantic error: invalid initial variable kind for '$key'")
  checked[key] = kind
 end
 return checked
end

function validate_ir(program::Vector{IR}; initial_names=Dict{String,Symbol}())
 abt_check_ir_shape(program)
 initial_names = abt_check_initial_names(initial_names)
 signatures = Dict{String,Int}()
 python_imports = Set{String}()
 const_reserved = ("Python", "Julia")
 function collect_functions(items::Vector{IR})
  for n in items
   if n.op == :function
    name, params = n.operands[1:2]
    name in const_reserved && error("Semantic error: reserved namespace '$name'")
    any(p in const_reserved for p in params) && error("Semantic error: reserved namespace parameter")
    haskey(signatures, name) && error("Semantic error: duplicate function '$name'")
    length(unique(params)) == length(params) || error("Semantic error: duplicate parameter in '$name'")
    any(p in keys(signatures) for p in params) && error("Semantic error: function-name parameter collision")
    signatures[name] = length(params)
   end
  end
 end
 collect_functions(program)
 top_writes = abt_ir_local_writes(program)
 function field_path(n::IR)
  if n.op == :load; return String[n.operands[1]]; end
  if n.op == :field; return vcat(field_path(n.operands[1]), String[n.operands[2]]); end
  return String[]
 end
 function infer(n::IR, names::Dict{String,Symbol})
  a = n.operands
  if n.op == :constant
   abt_literal_source(a[1]) # Reject non-serializable constants at validation time.
   return a[1] isa Bool ? :bool : a[1] isa Number ? :number : :string
  elseif n.op == :load
   haskey(names, a[1]) || error("Semantic error: undefined variable '$(a[1])'")
   a[1] in ("Python", "Julia") && error("Semantic error: namespace '$(a[1])' cannot be used as a value")
   return names[a[1]]
  elseif n.op == :call
   target = a[1]
   path = field_path(target)
   if !isempty(path) && path[1] == "Python"
    infer(target, names)
    foreach(x -> infer(x, names), a[2]); return :external
   end
   if target.op == :load && get(names, target.operands[1], :missing) == :external
    foreach(x -> infer(x, names), a[2]); return :external
   end
   if target.op == :field && !(length(path) == 3 && path[1] == "Julia") && infer(target.operands[1], names) == :external
    startswith(target.operands[2], "_") && error("Semantic error: private external attribute")
    foreach(x -> infer(x, names), a[2]); return :external
   end
   target = a[1]
   if target.op == :field
    # Explicit namespace, imported module, whitelisted function and arity.
    parent = target.operands[1]
    parent.op == :field && parent.operands[1].op == :load &&
     parent.operands[1].operands[1] == "Julia" ||
     error("Semantic error: unsupported external function")
    mod = parent.operands[2]
    fn = target.operands[2]
    julia_supported(mod) || error("Semantic error: unsupported Julia module '$mod'")
    get(names, "__julia_" * mod, :missing) == :imported ||
     error("Semantic error: Julia.$mod not imported")
    haskey(julia_functions(mod), fn) ||
     error("Semantic error: unsupported external function Julia.$mod.$fn")
    expected = julia_functions(mod)[fn]
    length(a[2]) == expected ||
     error("Semantic error: external function Julia.$mod.$fn expects $expected arguments, got $(length(a[2]))")
    foreach(x -> infer(x, names), a[2])
    return :unknown
   end
   target.op == :load || error("Semantic error: function call requires a named function")
   name = target.operands[1]
   if haskey(signatures, name)
    length(a[2]) == signatures[name] || error("Semantic error: function '$name' expects $(signatures[name]) arguments, got $(length(a[2]))")
   else
    # Dynamically supplied callable values (e.g. a Julia functor in the interpreter env).
    # Known non-callable values are rejected; unknown types are checked at runtime.
    kind = get(names, name, :missing)
    kind == :missing && error("Semantic error: undefined function '$name'")
    kind in (:unknown, :external, :abt_builtin) || error("Semantic error: value '$name' is not callable")
    if kind == :abt_builtin
     if name == "descrever"
      length(a[2]) == 1 || error("Semantic error: descrever expects 1 argument")
      collection = infer(a[2][1], names)
      collection in (:list, :unknown) || error("Semantic error: descrever expects a collection")
     elseif name in ("registro", "esquema")
      length(a[2]) >= 2 && iseven(length(a[2])) ||
       error("Semantic error: $name expects name/value pairs")
      for i in 1:2:length(a[2])
       keytype = infer(a[2][i], names)
       keytype in (:string, :unknown) || error("Semantic error: registro field name must be text")
      end
     end
     extension = get(ABT_EXTENSION_SPECS, Symbol(name), nothing)
     expected = extension === nothing ? get(Dict("falhar"=>1, "ambiente"=>2, "ler_texto"=>1, "linhas_texto"=>1,
                         "aparar"=>1, "maiusculas"=>1, "inicia_com"=>2,
                         "comprimento_texto"=>1, "contar_caractere"=>2,
                         "ler_csv"=>3, "coluna"=>2, "linhas_tabela"=>1,
                         "filtrar_tabela"=>4, "transformar_tabela"=>6,
                         "resumir_coluna"=>2, "ler_fasta"=>4,
                         "descrever_sequencias"=>1, "registros_fasta"=>1), name, -1) : extension.arity
     (name == "ler_csv" && length(a[2]) == 4) || expected < 0 || length(a[2]) == expected ||
      error("Semantic error: $name expects $expected arguments")
     argtypes = [infer(argument, names) for argument in a[2]]
     if extension !== nothing
      for (i, (actual, required)) in enumerate(zip(argtypes, extension.static_args))
       required == :unknown && continue
       actual in (required, :unknown, :external) ||
        error("Semantic error: $name argument $i expects $required")
      end
      return extension.return_kind
     end
     return :unknown
    end
   end
   foreach(x -> infer(x, names), a[2])
   return :unknown
  elseif n.op == :list
   foreach(x -> infer(x, names), a[1])
   return :list
  elseif n.op == :field
   startswith(a[2], "_") && error("Semantic error: private external attribute")
   path = field_path(n)
   if !isempty(path) && path[1] == "Python"
    get(names, "Python", :missing) == :python_namespace ||
      error("Semantic error: Python namespace used before import")
    length(path) >= 2 || error("Semantic error: incomplete Python reference")
    any(join(path[2:i], ".") in python_imports for i in 2:length(path)) ||
      error("Semantic error: Python module not imported for " * join(path, "."))
    return :external
   end
   if !isempty(path) && path[1] == "Julia"
    length(path) == 3 || error("Semantic error: Julia references require module and function")
    mod, fn = path[2], path[3]
    get(names, "__julia_" * mod, :missing) == :imported ||
      error("Semantic error: Julia.$mod not imported")
    julia_supported(mod) && haskey(julia_functions(mod), fn) ||
      error("Semantic error: unsupported Julia reference Julia.$mod.$fn")
    return :unknown
   end
   parent = infer(a[1], names)
   return parent == :external ? :external : :unknown
  elseif n.op == :unary
   kind = infer(a[2], names)
   kind in (:number, :unknown) || error("Semantic error: unary '$(a[1])' requires a number")
   return :number
  elseif n.op == :binary
   left = infer(a[2], names); right = infer(a[3], names)
   op = a[1]
   if op in ("+", "-", "*", "/", "^")
    (left in (:number, :unknown) && right in (:number, :unknown)) ||
      error("Semantic error: arithmetic '$op' requires numbers")
    return :number
   elseif op in ("&&", "||")
    (left in (:bool, :unknown) && right in (:bool, :unknown)) ||
      error("Semantic error: logical '$op' requires booleans")
    return :bool
   elseif op in (">", "<", ">=", "<=")
    (left in (:number, :unknown) && right in (:number, :unknown)) ||
      error("Semantic error: comparison '$op' requires numbers")
    return :bool
   elseif op in ("==", "!=")
    return :bool
   end
   error("Semantic error: unknown operator '$op'")
  elseif n.op == :aggregate
   collection = infer(a[2], names)
   collection in (:list, :unknown) ||
     error("Semantic error: aggregate requires a collection")
   if a[3] !== nothing
    localnames = copy(names)
    localnames["valor"] = :unknown
    localnames["value"] = :unknown
    pred = infer(a[3], localnames)
    pred in (:bool, :unknown) ||
      error("Semantic error: WHERE condition must be boolean")
   end
   return :number
  elseif n.op in (:filter, :map, :limit)
   collection = infer(a[1], names)
   collection in (:list, :unknown) ||
     error("Semantic error: collection operation requires a Vector")
   if n.op == :limit
    quantity = infer(a[2], names)
    quantity in (:number, :unknown) ||
      error("Semantic error: limit requires a nonnegative Int64")
   else
    localnames = copy(names)
    localnames["valor"] = :unknown
    localnames["value"] = :unknown
    result = infer(a[2], localnames)
    n.op == :filter && !(result in (:bool, :unknown)) &&
      error("Semantic error: filter predicate must be Bool")
   end
   return :list
  end
  error("Semantic error: unknown IR expression $(n.op)")
 end
 function check(items::Vector{IR}, names::Dict{String,Symbol}; in_function=false, nested=false)
  for n in items
   a = n.operands
   if n.op == :import_python
    nested && error("Semantic error: Python imports must be at top level")
    checked_python_path(a[1])
    names["Python"] = :python_namespace
    push!(python_imports, a[1])
   elseif n.op == :import_julia
    nested && error("Semantic error: Julia imports must be at top level")
    julia_supported(a[1]) || error("Semantic error: unsupported Julia module '$(a[1])'")
    names["Julia"] = :julia_namespace
    names["__julia_" * a[1]] = :imported
   elseif n.op == :store
    haskey(signatures, a[1]) && error("Semantic error: cannot reassign function '$(a[1])'")
    a[1] in const_reserved && error("Semantic error: reserved namespace '$(a[1])'")
    names[a[1]] = infer(a[2], names)
   elseif n.op == :print
    infer(a[1], names)
   elseif n.op == :function
    nested && error("Semantic error: nested function declarations are not supported")
    # Functions have explicit inputs: parameters and declared ABT functions.
    # No implicit captures of mutable top-level variables. This prevents
    # interpreter call-time lookup from disagreeing with Julia lexical capture,
    # including forward references and reassignment between calls.
    localnames = Dict{String,Symbol}(name => :unknown for name in keys(signatures))
    for builtin in ABT_STDLIB_NAMES
     (haskey(signatures, builtin) || builtin in top_writes || haskey(initial_names, builtin)) ||
      (localnames[builtin] = :abt_builtin)
    end
    # A local assignment shadows the outer binding throughout the function.
    # Remove inherited bindings so reads before assignment fail validation.
    for localname in abt_ir_local_writes(a[3])
     delete!(localnames, localname)
    end
    for param in a[2]
     haskey(signatures, param) && error("Semantic error: parameter shadows function '$param'")
     localnames[param] = :unknown
    end
    check(a[3], localnames; in_function=true, nested=true)
   elseif n.op == :return
    in_function || error("Semantic error: RETURN outside function")
    infer(a[1], names)
   elseif n.op == :branch
    typ = infer(a[1], names)
    typ in (:bool, :unknown) || error("Semantic error: IF condition must be boolean")
    yes = copy(names); no = copy(names)
    check(a[2], yes; in_function, nested=true); check(a[3], no; in_function, nested=true)
    # A name is guaranteed after IF only if defined in both branches.
    for name in intersect(Set(keys(yes)), Set(keys(no)))
     names[name] = yes[name] == no[name] ? yes[name] : :unknown
    end
   elseif n.op == :foreach
    haskey(signatures, a[1]) && error("Semantic error: loop variable shadows function '$(a[1])'")
    a[1] in const_reserved && error("Semantic error: reserved namespace loop variable")
    typ = infer(a[2], names)
    typ in (:list, :unknown) || error("Semantic error: FOR requires a collection")
    localnames = copy(names); localnames[a[1]] = :unknown
    check(a[3], localnames; in_function, nested=true)
    # Iteration may execute zero times, so newly defined names do not escape.
    for name in keys(names)
     if haskey(localnames, name) && names[name] != localnames[name]
      names[name] = :unknown
     end
    end
   else
    error("Semantic error: unknown IR statement $(n.op)")
   end
  end
 end
 known_names = copy(initial_names)
 for builtin in ABT_STDLIB_NAMES
  haskey(known_names, builtin) || haskey(signatures, builtin) || (known_names[builtin] = :abt_builtin)
 end
 for name in keys(signatures); known_names[name] = :unknown; end
 check(program, known_names)
 return program
end

# Conservative optimization: only comparisons of numeric literals and
# branches whose condition is a literal Bool. No speculative arithmetic.
function optimize_ir(program::Vector{IR})
 abt_check_ir_shape(program)
 function expr(n::IR)
  a = n.operands
  if n.op == :unary
   return ir(:unary, a[1], expr(a[2]))
  elseif n.op == :binary
   left, right = expr(a[2]), expr(a[3])
   op = a[1]
   if left.op == :constant && right.op == :constant &&
      typeof(left.operands[1]) in (Int64, Float64) &&
      typeof(right.operands[1]) in (Int64, Float64) &&
      (left.operands[1] isa Int64 || isfinite(left.operands[1])) &&
      (right.operands[1] isa Int64 || isfinite(right.operands[1])) &&
      op in (">", "<", ">=", "<=", "==", "!=")
    x, y = left.operands[1], right.operands[1]
    result = op == ">" ? x > y : op == "<" ? x < y :
             op == ">=" ? x >= y : op == "<=" ? x <= y :
             op == "==" ? x == y : x != y
    return ir(:constant, result)
   end
   return ir(:binary, op, left, right)
  elseif n.op == :call
   return ir(:call, expr(a[1]), [expr(x) for x in a[2]])
  elseif n.op == :list
   return ir(:list, [expr(x) for x in a[1]])
  elseif n.op == :aggregate
   return ir(:aggregate, a[1], expr(a[2]), a[3] === nothing ? nothing : expr(a[3]))
  elseif n.op in (:filter, :map, :limit)
   return ir(n.op, expr(a[1]), expr(a[2]))
  elseif n.op == :field
   return ir(:field, expr(a[1]), a[2])
  end
  return n
 end
 function stmts(items::Vector{IR})
  out = IR[]
  for n in items
   a = n.operands
   if n.op == :branch
    cond = expr(a[1])
    yes, no = stmts(a[2]), stmts(a[3])
    if cond.op == :constant && cond.operands[1] isa Bool
     append!(out, cond.operands[1] ? yes : no)
    else
     push!(out, ir(:branch, cond, yes, no))
    end
   elseif n.op == :store
    push!(out, ir(:store, a[1], expr(a[2])))
   elseif n.op == :print
    push!(out, ir(:print, expr(a[1])))
   elseif n.op == :function
    push!(out, ir(:function, a[1], a[2], stmts(a[3])))
   elseif n.op == :return
    push!(out, ir(:return, expr(a[1])))
   elseif n.op == :foreach
    push!(out, ir(:foreach, a[1], expr(a[2]), stmts(a[3])))
   else
    push!(out, n)
   end
  end
  out
 end
 return stmts(program)
end

function julia_ir_expr(n::IR)
 a = n.operands
 if n.op == :constant
  return abt_literal_source(a[1])
 elseif n.op == :load
  return a[1] in ("Python", "Julia") ? a[1] : abt_julia_name(a[1])
 elseif n.op == :call
  return "abt_invoke(" * julia_ir_expr(a[1]) * (isempty(a[2]) ? "" : ", " * join(julia_ir_expr.(a[2]), ", ")) * ")"
 elseif n.op == :list
  return "[" * join(julia_ir_expr.(a[1]), ", ") * "]"
 elseif n.op == :field
  if n.operands[1].op == :load && n.operands[1].operands[1] == "Python"
   return "abt_external_field(Python, " * quotejl(a[2]) * ")"
  end
  if n.operands[1].op == :field && n.operands[1].operands[1].op == :load && n.operands[1].operands[1].operands[1] == "Julia"
   return julia_ir_expr(n.operands[1]) * "." * a[2]
  elseif n.operands[1].op == :load && n.operands[1].operands[1] == "Julia"
   return a[2] == "Base" ? "Base" : "__abt_julia_module_" * a[2]
  end
  return "abt_external_field(" * julia_ir_expr(a[1]) * ", " * quotejl(a[2]) * ")"
 elseif n.op == :unary
  return "abt_unary(" * quotejl(a[1]) * ", " * julia_ir_expr(a[2]) * ")"
 elseif n.op == :binary
  return "(" * julia_ir_expr(a[2]) * " $(a[1]) " * julia_ir_expr(a[3]) * ")"
 elseif n.op == :aggregate
  src = julia_ir_expr(a[2])
  predicate = a[3] === nothing ? "true" : julia_ir_expr(a[3])
  fn = a[1] == :sum ? "pseudo_sum" : "pseudo_average"
  value_name = abt_julia_name("value"); valor_name = abt_julia_name("valor")
  return "$fn(($value_name for $value_name in $src if let $valor_name = $value_name; $predicate; end))"
 elseif n.op in (:filter, :map)
  src = julia_ir_expr(a[1]); body = julia_ir_expr(a[2])
  value_name = abt_julia_name("value"); valor_name = abt_julia_name("valor")
  helper = n.op == :filter ? "abt_filter" : "abt_map"
  return "$helper($src, $value_name -> (let $valor_name = $value_name; $body; end))"
 elseif n.op == :limit
  return "abt_limit(" * julia_ir_expr(a[1]) * ", " * julia_ir_expr(a[2]) * ")"
 end
 error("Unsupported IR expression: $(n.op)")
end

function _generate_validated_ir(program::Vector{IR})
 # Imports are module-level; all ABT helper names and program state are local
 # to a fresh let scope, so repeated include does not redefine ABT methods.
 lines = ["# Generated by ABT 0.13.0 (IR backend)"]
 has_python = any(n.op == :import_python for n in program)
 # Julia module bindings are local to this program. Loading a module may still
 # initialize global package state, but never creates a host-module import binding.
 push!(lines, "let")
 function references(value, name)
  if value isa IR
   value.op == :load && value.operands[1] == name && return true
   return any(x -> references(x, name), value.operands)
  elseif value isa AbstractVector
   return any(x -> references(x, name), value)
  end
  return false
 end
 function contains_print(value)
  if value isa IR
   value.op == :print && return true
   return any(contains_print, value.operands)
  elseif value isa AbstractVector
   return any(contains_print, value)
  end
  return false
 end
 declared = Set(n.operands[1] for n in program if n.op == :function)
 used_builtins = [name for name in ABT_STDLIB_NAMES if
                  !(name in declared) && references(program, name)]
 if !isempty(used_builtins) || contains_print(program)
  append!(lines, String.(split(read(joinpath(@__DIR__, "StdlibRender.jl"), String), '\n')))
 end
 if !isempty(used_builtins)
  append!(lines, String.(split(read(joinpath(@__DIR__, "Stdlib.jl"), String), '\n')))
  if any(name -> name in ABT_BIO_NAMES, used_builtins)
   append!(lines, String.(split(read(joinpath(@__DIR__, "StdlibBio.jl"), String), '\n')))
  end
  included_sources = Set{String}()
  if any(name -> haskey(ABT_EXTENSION_SPECS, Symbol(name)) &&
                 ABT_EXTENSION_SPECS[Symbol(name)].source == "StdlibBiostatistics.jl", used_builtins)
   push!(lines, "Statistics = Base.require(Base.PkgId(Base.UUID(\"10745b16-79ce-11e8-11f9-7d13ad32a3b2\"), \"Statistics\"))")
  end
  for (name, spec) in pairs(ABT_EXTENSION_SPECS)
   if String(name) in used_builtins && !(spec.source in included_sources)
    append!(lines, String.(split(read(joinpath(@__DIR__, spec.source), String), '\n')))
    push!(included_sources, spec.source)
   end
  end
  if "descrever" in used_builtins
   push!(lines, "__abt_std_statistics = Base.require(Base.PkgId(Base.UUID(\"10745b16-79ce-11e8-11f9-7d13ad32a3b2\"), \"Statistics\"))")
   push!(lines, abt_julia_name("descrever") * " = xs -> abt_std_describe(xs, __abt_std_statistics)")
  end
  if "registro" in used_builtins
   push!(lines, abt_julia_name("registro") * " = abt_std_record")
  end
  for (name, impl) in (("falhar", "abt_std_fail"), ("ambiente", "abt_std_environment"), ("ler_texto", "abt_std_text"),
                       ("linhas_texto", "abt_std_lines"), ("aparar", "abt_std_strip"),
                       ("maiusculas", "abt_std_uppercase"), ("inicia_com", "abt_std_startswith"),
                       ("comprimento_texto", "abt_std_text_length"),
                       ("contar_caractere", "abt_std_char_count"), ("esquema", "abt_std_schema"),
                       ("ler_csv", "abt_std_csv"), ("coluna", "abt_std_column"),
                       ("linhas_tabela", "abt_std_table_rows"),
                       ("filtrar_tabela", "abt_std_filter_table"),
                       ("transformar_tabela", "abt_std_transform_table"),
                       ("resumir_coluna", "abt_std_summarize"),
                       ("ler_fasta", "abt_std_fasta"),
                       ("descrever_sequencias", "abt_std_fasta_summary"),
                       ("registros_fasta", "abt_std_fasta_records"))
   name in used_builtins && push!(lines, abt_julia_name(name) * " = " * impl)
  end
  for (name, spec) in pairs(ABT_EXTENSION_SPECS)
   String(name) in used_builtins && push!(lines, abt_julia_name(String(name)) * " = " * spec.generated)
  end
 end
 append!(lines, [
  "function pseudo_sum(xs)", "    total = 0", "    for x in xs", "        total += x", "    end", "    return total", "end",
  "function pseudo_average(xs)", "    total = 0", "    count = 0", "    for x in xs", "        total += x", "        count += 1", "    end", "    count > 0 || error(\"Cannot average an empty selection\")", "    return total / count", "end",
  "function abt_filter(xs, predicate)",
  "    xs isa Vector || error(\"Semantic error: collection operation requires a Vector\")",
  "    return filter(xs) do value",
  "        selected = predicate(value)",
  "        selected isa Bool || error(\"Semantic error: filter predicate must be Bool\")",
  "        selected",
  "    end",
  "end",
  "function abt_map(xs, transform)",
  "    xs isa Vector || error(\"Semantic error: collection operation requires a Vector\")",
  "    isempty(xs) && return Any[]",
  "    return map(transform, xs)",
  "end",
  "function abt_limit(xs, count)",
  "    xs isa Vector || error(\"Semantic error: collection operation requires a Vector\")",
  "    typeof(count) === Int64 && count >= 0 || error(\"Semantic error: limit requires a nonnegative Int64\")",
  "    return xs[1:min(count, length(xs))]",
  "end",
  "function abt_unary(op, value)",
  "    (typeof(value) === Int64 || typeof(value) === Float64) || error(\"Semantic error: unary \$op requires a number\")",
  "    return op == \"+\" ? +value : -value",
  "end",
  "abt_invoke(fn, args...) = Base.invokelatest(fn, args...)"
 ])
 if any(n.op == :import_julia && haskey(ABT_PACKAGES, n.operands[1]) for n in program)
  append!(lines, [
   "function abt_load_julia_package(name, uuid, version)",
   "    mod = try",
   "        Base.require(Base.PkgId(Base.UUID(uuid), name))",
   "    catch err",
   "        error(\"ABT package '\$name' unavailable: \" * sprint(showerror, err))",
   "    end",
   "    got = Base.pkgversion(mod)",
   "    string(got) == version || error(\"ABT package '\$name' version mismatch: expected \$version, got \$got\")",
   "    return mod",
   "end"
  ])
 end
 if has_python
  # An unforgeable per-program token distinguishes namespace views from user values.
  # No type declarations in local scopes; Python imports stay ordered.
  append!(lines, [
   "function abt_load_pythoncall!(cache)",
   "    cache[] !== nothing && return cache[]",
   "    deps = Module(gensym(:ABTPythonDeps))",
   "    try",
   "        Core.eval(deps, :(import PythonCall))",
   "    catch err",
   "        error(\"Interop Python indisponível: verifique PythonCall.jl. Causa: \" * sprint(showerror, err))",
   "    end",
   "    cache[] = Base.invokelatest(getfield, deps, :PythonCall)",
   "    return cache[]",
   "end",
   "abt_namespace_token = Ref{Nothing}(nothing)",
   "abt_namespace(modules, prefix) = (token=abt_namespace_token, modules=modules, prefix=prefix)",
   "function abt_import_python!(ns, path, pyimport)",
   "    occursin(r\"^[A-Za-z][A-Za-z_0-9]*(\\.[A-Za-z][A-Za-z_0-9]*)*\$\", path) || error(\"ABT interop: caminho de módulo inválido: \$path\")",
   "    any(startswith(part, \"_\") for part in split(path, '.')) && error(\"ABT interop: componente privado: \$path\")",
   "    obj = Base.invokelatest(pyimport, path)",
   "    ns.modules[path] = obj",
   "    nothing",
   "end",
   "function abt_external_field(obj, field)",
   "    startswith(field, \"_\") && error(\"ABT interop: atributo privado não permitido: \$field\")",
   "    if obj isa NamedTuple && haskey(obj, :token) && obj.token === abt_namespace_token && haskey(obj, :modules) && haskey(obj, :prefix)",
   "        path = isempty(obj.prefix) ? field : obj.prefix * \".\" * field",
   "        if any(startswith(k, path * \".\") for k in keys(obj.modules))",
   "            return abt_namespace(obj.modules, path)",
   "        elseif haskey(obj.modules, path)",
   "            return obj.modules[path]",
   "        elseif haskey(obj.modules, obj.prefix)",
   "            return abt_external_field(obj.modules[obj.prefix], field)",
   "        end",
   "        error(\"ABT interop: módulo ou atributo não importado: \" * path)",
   "    end",
   "    pymod = parentmodule(typeof(obj))",
   "    if nameof(pymod) == :PythonCall && isdefined(pymod, :Py) && obj isa getfield(pymod, :Py)",
   "        return Base.invokelatest(getfield(pymod, :pygetattr), obj, field)",
   "    end",
   "    obj isa AbstractDict ? obj[field] : getproperty(obj, Symbol(field))",
   "end"
  ])
 else
  append!(lines, [
   "function abt_external_field(obj, field)",
   "    startswith(field, \"_\") && error(\"ABT interop: atributo privado não permitido: \$field\")",
   "    return obj isa AbstractDict ? obj[field] : getproperty(obj, Symbol(field))",
   "end"
  ])
 end
 push!(lines, "function __abt_program_main__()")
 if any(n.op == :import_python for n in program)
  push!(lines, "    Python = abt_namespace(Dict{String,Any}(), \"\")")
  push!(lines, "    __abt_pythoncall_cache__ = Ref{Any}(nothing)")
 end
 function emit(items::Vector{IR}, depth=1)
  pad = repeat("    ", depth)
  for n in items
   a = n.operands
   if n.op == :import_python
    # Import inside a per-program private module, never the caller's module.
    # Evaluate only on reaching the ABT import instruction.
    push!(lines, pad * "abt_import_python!(Python, " * quotejl(a[1]) * ", abt_load_pythoncall!(__abt_pythoncall_cache__).pyimport)")
   elseif n.op == :import_julia
    # Resolve by exact stdlib PkgId, not @eval import in the host module.
    # A local binding is assigned only when the ABT import is reached.
    if haskey(ABT_PACKAGES, a[1])
     spec = ABT_PACKAGES[a[1]]
     push!(lines, pad * "__abt_julia_module_" * a[1] * " = abt_load_julia_package(" *
      join(quotejl.([a[1], spec.uuid, spec.version]), ", ") * ")")
    elseif a[1] == "Base"
     push!(lines, pad * "nothing  # Base is always available")
    else
     uuid = Dict("Statistics" => "10745b16-79ce-11e8-11f9-7d13ad32a3b2",
                 "LinearAlgebra" => "37e2e46d-f89d-539d-b4ee-838fcccc9c8e")[a[1]]
     push!(lines, pad * "__abt_julia_module_" * a[1] * " = Base.require(Base.PkgId(Base.UUID(\"" * uuid * "\"), \"" * a[1] * "\"))")
    end
   elseif n.op == :store
    push!(lines, pad * abt_julia_name(a[1]) * " = " * julia_ir_expr(a[2]))
   elseif n.op == :print
    push!(lines, pad * "Base.invokelatest(println, abt_std_render(" * julia_ir_expr(a[1]) * "))")
   elseif n.op == :branch
    push!(lines, pad * "if " * julia_ir_expr(a[1]))
    emit(a[2], depth+1)
    if !isempty(a[3])
     push!(lines, pad * "else")
     emit(a[3], depth+1)
    end
    push!(lines, pad * "end")
   elseif n.op == :function
    push!(lines, pad * "function " * abt_julia_name(a[1]) * "(" * join(abt_julia_name.(a[2]), ", ") * ")")
    # Julia closures otherwise mutate captured outer variables on assignment.
    localwrites = setdiff(abt_ir_local_writes(a[3]), Set{String}(a[2]))
    for localname in sort!(collect(localwrites))
     push!(lines, pad * "    local " * abt_julia_name(localname))
    end
    emit(a[3], depth+1)
    # ABT functions without explicit return evaluate to nothing, not Julia's
    # last statement value.
    push!(lines, pad * "    return nothing")
    push!(lines, pad * "end")
   elseif n.op == :return
    push!(lines, pad * "return " * julia_ir_expr(a[1]))
   elseif n.op == :foreach
    # A loop iterator in Julia has its own scope; ABT updates the binding.
    temp = "__abt_iter_" * string(length(lines))
    push!(lines, pad * "for " * temp * " in " * julia_ir_expr(a[2]))
    push!(lines, pad * "    " * abt_julia_name(a[1]) * " = " * temp)
    emit(a[3], depth+1)
    push!(lines, pad * "end")
   else
    error("Unsupported IR statement: $(n.op)")
   end
  end
 end
 # Hoist declarations so forward calls behave like the validated ABT program.
 emit([n for n in program if n.op == :function])
 emit([n for n in program if n.op != :function])
 push!(lines, "end")
 push!(lines, "__abt_program_main__()")
 push!(lines, "end")
 return join(lines, "\n") * "\n"
end

# Public IR entrypoint cannot bypass semantic validation.
# _generate_validated_ir is an implementation detail and must only receive checked IR.
generate_ir(program::Vector{IR}) = _generate_validated_ir(validate_ir(program))
function generate(program::Vector{IR}; optimize::Bool=true)
 validated = validate_ir(program)
 return _generate_validated_ir(optimize ? optimize_ir(validated) : validated)
end
generate(program::Vector{Node}; optimize::Bool=true) = generate(lower_ir(program); optimize)

function treeprint(io::IO, value; depth=0)
 pad = repeat("  ", depth)
 if value isa Node || value isa IR
  name = value isa Node ? value.kind : value.op
  args = value isa Node ? value.args : value.operands
  println(io, pad, name)
  for x in args; treeprint(io, x; depth=depth+1); end
 elseif value isa AbstractVector
  println(io, pad, "[")
  for x in value; treeprint(io, x; depth=depth+1); end
  println(io, pad, "]")
 elseif value === nothing
  println(io, pad, "∅")
 else
  println(io, pad, repr(value))
 end
end

function explain(source::String; io::IO=stdout)
 toks = tokenize(source)
 ast = parse_program(toks)
 representation = lower_ir(ast)
 validated = validate_ir(representation)
 optimized = optimize_ir(validated)
 generated = _generate_validated_ir(optimized)
 println(io, "=== 1. TOKENS ===")
 for t in toks
  println(io, rpad(t.kind, 12), " ", repr(t.lexeme), " @", t.line, ":", t.col)
 end
 println(io, "\n=== 2. AST ===")
 treeprint(io, ast)
 println(io, "\n=== 3. IR (validated, not optimized) ===")
 treeprint(io, representation)
 println(io, "\n=== 4. OPTIMIZED IR ===")
 treeprint(io, optimized)
 println(io, "\n=== 5. GENERATED JULIA ===")
 print(io, generated)
 return nothing
end

# Diagnósticos são apresentação; não alteram a semântica do compilador.
const DIAGNOSTIC_CATALOG = Dict(
 "E000" => ("erro de compilação ou execução", "", ""),
 "E021" => ("variável não definida", "Confira o nome da variável.", "A variável não existe. Minha bola de cristal também não."),
 "E010" => ("erro de sintaxe", "A sintaxe precisa de uma revisão.", "A gramática apresentou uma objeção formal. E tem razão."),
 "E052" => ("quantidade incorreta de argumentos", "Confira os argumentos da chamada.", "A função pediu uma quantidade de argumentos. Você trouxe outra. O restante vem por Sedex?"),
)

function diagnostic_code(msg::AbstractString)
 lower = lowercase(msg)
 if occursin("undefined variable", lower) || occursin("variável não definida", lower)
  return "E021"
 elseif occursin("Expected ", msg) || occursin("Unexpected token", msg) || occursin("Pipeline error", msg)
  return "E010"
 elseif occursin("wrong argument count", lower) || occursin("expects ", lower)
  return "E052"
 end
 return "E000"
end

function diagnostic_detail(msg::AbstractString, code::AbstractString)
 if code == "E052"
  m = match(r"function '([^']+)' expects (\d+) arguments, got (\d+)", msg)
  m !== nothing && return "A função '$(m.captures[1])' espera $(m.captures[2]) argumentos, mas recebeu $(m.captures[3])."
 elseif code == "E021"
  m = match(r"undefined variable '([^']+)'", msg)
  m !== nothing && return "A variável '$(m.captures[1])' não foi definida."
 elseif code == "E010"
  m = match(r"Expected ([^,]+), got (.+)", msg)
  m !== nothing && return "Era esperado $(m.captures[1]), mas foi encontrado $(m.captures[2])."
 end
 return replace(msg, "Semantic error:" => "Erro semântico:", "Parse error:" => "Erro de sintaxe:")
end

function render_diagnostic(err; humor::AbstractString="dry", source::AbstractString="")
 humor in ("off", "dry", "roast") || throw(ArgumentError("modo de humor inválido"))
 msg = sprint(showerror, err)
 fatal = err isa OutOfMemoryError || err isa StackOverflowError || occursin("Internal error", msg)
 if fatal
  return "ABT[FATAL] — falha grave\n" * msg * "\nExecução interrompida."
 end
 code = diagnostic_code(msg)
 heading, dry, roast = DIAGNOSTIC_CATALOG[code]
 header = "Erro ABT[" * code * "] — " * heading * "\n\n" * diagnostic_detail(msg, code)
 joke = humor == "dry" ? dry : humor == "roast" ? roast : ""
 return isempty(joke) ? header : header * "\n\nABT: " * joke
end

function main(args=ARGS)
 isempty(args) && error("Usage: julia pseudo.jl FILE [--emit-julia FILE] [--no-run] [--tokens] [--ast] [--explain]")
 source = read(args[1], String)
 t0 = time_ns()
 toks = tokenize(source)
 ast = parse_program(toks)
 representation = validate_ir(lower_ir(ast))
 elapsed = (time_ns() - t0) / 1e6
 if "--explain" in args
  explain(source)
 elseif "--tokens" in args
  foreach(t -> println("$(t.kind) $(repr(t.lexeme)) @$(t.line):$(t.col)"), toks)
 end
 if "--ast" in args && !("--explain" in args); treeprint(stdout, ast); end
 if "--emit-julia" in args
  ix = findfirst(==("--emit-julia"), args)
  ix < length(args) || error("--emit-julia requires a filename")
  write(args[ix+1], generate(representation; optimize=!("--no-opt" in args)))
  println("Julia generated: ", args[ix+1])
 end
 if !("--no-run" in args)
  foreach(println, execute(ast))
 end
 if "--time" in args; println(stderr, "Lexer + parser: ", round(elapsed; digits=3), " ms (includes first-call JIT)"); end
end
end # module
