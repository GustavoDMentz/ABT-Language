include(joinpath(@__DIR__, "..", "src", "ABT.jl"))
path = tempname() * ".csv"
try
 open(path, "w") do io
  println(io, "nome,valor")
  for i in 1:100000
   println(io, "item", i, ",", i)
  end
 end
 schema = ABT.abt_std_schema("nome", "texto", "valor", "inteiro")
 table = ABT.abt_std_csv(path, schema, "erro")
 println("table_bytes=", Base.summarysize(table))
 summary = Base.invokelatest(ABT.abt_std_summarize, table, "valor")
 @assert summary.quantidade == 100000
 @assert summary.soma == 5000050000
 println("rows=", summary.quantidade, " sum=", summary.soma)
finally
 isfile(path) && rm(path)
end
