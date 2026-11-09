using Random, TOML
include("pseudo.jl")
using .Pseudo
const INVALID_SEED=0xBAD118
function invalid_case(id)
 r=MersenneTwister(INVALID_SEED+id)
 n=rand(r,1:999)
 k=mod(id-1,8)+1
 if k==1; return "indent", "xs=[$n]\nxs\n  filtrar onde valor > 0\n    mostrar"
 elseif k==2; return "unknown_step", "xs=[$n]\nxs\n  ordenar por valor\n  mostrar"
 elseif k==3; return "missing_terminal", "xs=[$n]\nxs\n  limitar a 1"
 elseif k==4; return "missing_delimiter", "xs=[$n]\nxs\n  transformar valor+1\n  mostrar"
 elseif k==5; return "trailing_terminal", "xs=[$n]\nxs\n  mostrar 1"
 elseif k==6; return "bad_character", "mostrar [$n] @"
 elseif k==7; return "unclosed_block", "se verdadeiro { mostrar $n"
 else; return "tab_indent", "xs=[$n]\nxs\n\tlimitar a 1\n\tmostrar"
 end
end
function main()
 accepted=0; categories=Dict{String,Int}(); failures=String[]
 for id in 1:1000
  category,src=invalid_case(id)
  categories[category]=get(categories,category,0)+1
  rejected=false
  try
   ast=Pseudo.parse_program(Pseudo.tokenize(src))
   Pseudo.validate_ir(Pseudo.lower_ir(ast))
  catch e
   rejected=true
  end
  if !rejected
   accepted+=1; push!(failures,"$id $category $(repr(src))")
  end
 end
 write("invalid_accepted.log",join(failures,"\n"))
 open("invalid_summary.toml","w") do io
  TOML.print(io,Dict("seed"=>string(INVALID_SEED),"executed"=>1000,"rejected"=>1000-accepted,"accepted"=>accepted,"categories"=>categories))
 end
 println("invalid executed=1000 rejected=$(1000-accepted) accepted=$accepted")
 accepted==0 || exit(1)
end
main()
