function abt_sc_columns(table,names,op)
 abt_std_istable(table) || error("ABT $op: esperado tabela tipada")
 names isa AbstractVector && !isempty(names) && all(x -> x isa String && x in table.columns,names) && length(unique(names))==length(names) || error("ABT $op: colunas existentes, únicas e não vazias obrigatórias")
 return Int[findfirst(==(name),table.columns) for name in names]
end
function abt_sc_select(table,names)
 indices=abt_sc_columns(table,names,"selecionar_colunas")
 keys=Tuple(Symbol.(names))
 rows=(NamedTuple{keys}(Tuple(getproperty(row,k) for k in keys)) for row in table.rows)
 return abt_std_table(rows,String.(names),table.types[indices],table.source)
end
function abt_sc_rename(table,old,new)
 indices=abt_sc_columns(table,old,"renomear_colunas")
 new isa AbstractVector && length(new)==length(old) && all(x -> x isa String && occursin(r"^[^\W\d]\w*$",x) && !startswith(x,"_"),new) || error("ABT renomear_colunas: nomes novos inválidos")
 columns=copy(table.columns); columns[indices]=new
 length(unique(columns))==length(columns) || error("ABT renomear_colunas: nomes duplicados")
 keys=Tuple(Symbol.(columns))
 rows=(NamedTuple{keys}(Tuple(row)) for row in table.rows)
 return abt_std_table(rows,columns,copy(table.types),table.source)
end
function abt_sc_sort(table,names,directions,policy)
 abt_sc_columns(table,names,"ordenar_tabela")
 directions isa AbstractVector && length(directions)==length(names) && all(x -> x in ("crescente","decrescente"),directions) || error("ABT ordenar_tabela: uma direção explícita por coluna")
 policy in ("erro","primeiro","ultimo") || error("ABT ordenar_tabela: política de ausentes inválida")
 rows=abt_std_table_rows(table)
 policy=="erro" && any(row -> any(n -> ismissing(getproperty(row,Symbol(n))),names),rows) && error("ABT ordenar_tabela: valor ausente")
 function less(a,b)
  for (name,direction) in zip(names,directions)
   x=getproperty(a,Symbol(name)); y=getproperty(b,Symbol(name))
   isequal(x,y) && continue
   ismissing(x) && return policy=="primeiro"
   ismissing(y) && return policy=="ultimo"
   return direction=="crescente" ? isless(x,y) : isless(y,x)
  end
  return false
 end
 sort!(rows;lt=less,alg=Base.Sort.MergeSort)
 return abt_std_table(rows,copy(table.columns),copy(table.types),table.source)
end
function abt_sc_unique(table,names)
 abt_sc_columns(table,names,"remover_duplicatas")
 rows=abt_std_table_rows(table)
 selected=unique(row -> Tuple(getproperty(row,Symbol(n)) for n in names),rows)
 return abt_std_table(selected,copy(table.columns),copy(table.types),table.source)
end
function abt_sc_join(left,right,names,mode)
 li=abt_sc_columns(left,names,"juntar_tabelas"); ri=abt_sc_columns(right,names,"juntar_tabelas")
 left.types[li]==right.types[ri] || error("ABT juntar_tabelas: tipos das chaves incompatíveis")
 mode in ("interna","esquerda") || error("ABT juntar_tabelas: modo deve ser interna ou esquerda")
 extra=setdiff(right.columns,String.(names))
 isempty(intersect(left.columns,extra)) || error("ABT juntar_tabelas: renomeie colunas não chave sobrepostas")
 a=abt_std_table_rows(left); b=abt_std_table_rows(right)
 any(row -> any(n -> ismissing(getproperty(row,Symbol(n))),names),vcat(a,b)) && error("ABT juntar_tabelas: chaves ausentes não permitidas")
 df=Base.require(Base.PkgId(Base.UUID("a93c6f00-e57d-5684-b7b6-d8193f3e46c0"),"DataFrames"))
 return Base.invokelatest(left,right,a,b,names,mode,extra,df) do l,r,ar,br,ns,m,ex,lib
  # Explicit schemas also construct typed columns when the input is empty.
  column_type(t)=t=="texto" ? String : t=="inteiro" ? Int64 : t=="real" ? Float64 : Bool
  frame(t,rows)=lib.DataFrame([Symbol(n)=>Union{Missing,column_type(k)}[getproperty(row,Symbol(n)) for row in rows] for (n,k) in zip(t.columns,t.types)])
  fa=frame(l,ar); fb=frame(r,br)
  merged=m=="interna" ? lib.innerjoin(fa,fb;on=Symbol.(ns),order=:left,matchmissing=:error) : lib.leftjoin(fa,fb;on=Symbol.(ns),order=:left,matchmissing=:error)
  columns=vcat(l.columns,ex); types=vcat(l.types,[r.types[findfirst(==(n),r.columns)] for n in ex])
  lib.select!(merged,Symbol.(columns))
  return abt_std_table([NamedTuple(row) for row in lib.eachrow(merged)],columns,types,"junção")
 end
end
function abt_sc_export(table,path,missing_text)
 abt_std_istable(table) || error("ABT exportar_csv: esperado tabela tipada")
 path isa String && !isempty(path) || error("ABT exportar_csv: caminho não vazio obrigatório")
 missing_text isa String && !isempty(missing_text) || error("ABT exportar_csv: marcador de ausente não vazio obrigatório")
 rows=abt_std_table_rows(table)
 any(row -> any(v -> v isa String && v==missing_text,Tuple(row)),rows) && error("ABT exportar_csv: marcador colide com texto existente")
 csv=Base.require(Base.PkgId(Base.UUID("336ed68f-0bac-5ca0-87d4-7b16caf5d00b"),"CSV"))
 try
  Base.invokelatest(csv.write,path,rows;header=table.columns,missingstring=missing_text)
 catch err
  error("ABT exportar_csv: arquivo '$path': " * sprint(showerror,err))
 end
 return (; arquivo=path,linhas=length(rows),marcador_ausente=missing_text)
end
