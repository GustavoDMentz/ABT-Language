using Random, TOML
include("test_differential_1000.jl")
const META_SEED=0xAB7A118
function main()
 r=MersenneTwister(META_SEED); counts=Dict{String,Int}(); failures=String[]
 for id in 1:200
  xs=rand(r,0:20,rand(r,0:8)); lit="["*join(xs,",")*"]"; expected_repr=isempty(xs) ? "Any[]" : string(xs)
  programs=(
   ("filter_true","$lit\n  filtrar onde verdadeiro\n  mostrar",expected_repr),
   ("identity","$lit\n  transformar com valor\n  mostrar",expected_repr),
   ("limit_size","$lit\n  limitar a $(length(xs))\n  mostrar",expected_repr),
  )
  for (category,source,expected) in programs
   counts[category]=get(counts,category,0)+1
   try
    ast=parse_program(tokenize(source)); observed=execute(ast)
    ok,reason,_=run_one(id,category,source)
    (ok && observed==[expected]) || push!(failures,"$id $category expected=$(repr(expected)) observed=$(repr(observed)) reason=$reason source=$(repr(source))")
   catch e
    push!(failures,"$id $category $(sprint(showerror,e))")
   end
  end
 end
 source="function origin() { mostrar 7; retornar [1,2] }\norigin()\n  transformar com valor+1\n  mostrar"
 counts["single_evaluation"]=1
 try
  ast=parse_program(tokenize(source)); observed=execute(ast)
  ok,reason,_=run_one(1,"single_evaluation",source)
  (ok && observed==["7","[2, 3]"]) || push!(failures,"single_evaluation observed=$(repr(observed)) reason=$reason")
 catch e
  push!(failures,"single_evaluation $(sprint(showerror,e))")
 end
 write("metamorphic_failures.log",join(failures,"\n"))
 open("metamorphic_summary.toml","w") do io
  TOML.print(io,Dict("seed"=>string(META_SEED),"executed"=>sum(values(counts)),"failures"=>length(failures),"categories"=>counts))
 end
 println("metamorphic executed=$(sum(values(counts))) failures=$(length(failures))")
 isempty(failures) || exit(1)
end
main()
