function abt_sc_reals(xs,op)
 xs isa AbstractVector && !isempty(xs) && all(x -> typeof(x)===Float64 && isfinite(x),xs) || error("ABT $op: esperado lista não vazia de Float64 finitos")
 return Float64[x for x in xs]
end
function abt_sc_matrix(rows,op)
 rows isa AbstractVector && !isempty(rows) && first(rows) isa AbstractVector && !isempty(first(rows)) || error("ABT $op: matriz deve ter linhas e colunas")
 width=length(first(rows)); a=Matrix{Float64}(undef,length(rows),width)
 for (i,row) in enumerate(rows)
  row isa AbstractVector && length(row)==width || error("ABT $op: matriz irregular na linha $i")
  a[i,:]=abt_sc_reals(row,op)
 end
 return a
end
abt_sc_rows(a)=[collect(a[i,:]) for i in axes(a,1)]
abt_sc_la()=Base.require(Base.PkgId(Base.UUID("37e2e46d-f89d-539d-b4ee-838fcccc9c8e"),"LinearAlgebra"))
function abt_sc_finite(a,op)
 all(isfinite,a) || error("ABT $op: resultado não finito")
 return a
end
function abt_sc_product(a,b)
 x=abt_sc_matrix(a,"produto_matricial"); y=abt_sc_matrix(b,"produto_matricial")
 size(x,2)==size(y,1) || error("ABT produto_matricial: dimensões incompatíveis")
 return abt_sc_rows(abt_sc_finite(x*y,"produto_matricial"))
end
abt_sc_transpose(a)=abt_sc_rows(permutedims(abt_sc_matrix(a,"transpor_matriz")))
function abt_sc_det(a)
 x=abt_sc_matrix(a,"determinante_matriz"); size(x,1)==size(x,2) || error("ABT determinante_matriz: matriz deve ser quadrada")
 value=Base.invokelatest(abt_sc_la().det,x)
 isfinite(value) || error("ABT determinante_matriz: resultado não finito")
 return value
end
function abt_sc_rank(a,tolerance)
 typeof(tolerance)===Float64 && isfinite(tolerance) && tolerance>=0 || error("ABT posto_matriz: tolerância absoluta Float64 não negativa")
 x=abt_sc_matrix(a,"posto_matriz")
 return Base.invokelatest(abt_sc_la().rank,x;atol=tolerance,rtol=0.0)
end
function abt_sc_decompose(a,method)
 method in ("qr","svd","autovalores_simetricos") || error("ABT decompor_matriz: método inválido")
 x=abt_sc_matrix(a,"decompor_matriz")
 if method=="autovalores_simetricos"
  size(x,1)==size(x,2) && x==permutedims(x) || error("ABT decompor_matriz: autovalores exigem matriz simétrica exata")
 end
 la=abt_sc_la()
 return Base.invokelatest(abt_sc_decompose_loaded,x,method,la)
end
function abt_sc_decompose_loaded(x,method,la)
 if method=="qr"
  f=la.qr(x); r=Matrix(f.R); q=Matrix(f.Q)[:,1:size(r,1)]
  return (; metodo=method,Q=abt_sc_rows(abt_sc_finite(q,"decompor_matriz")),R=abt_sc_rows(abt_sc_finite(r,"decompor_matriz")))
 elseif method=="svd"
  f=la.svd(x)
  return (; metodo=method,U=abt_sc_rows(abt_sc_finite(f.U,"decompor_matriz")),singulares=abt_sc_finite(collect(f.S),"decompor_matriz"),Vt=abt_sc_rows(abt_sc_finite(f.Vt,"decompor_matriz")))
 end
 f=la.eigen(la.Symmetric(x))
 return (; metodo=method,valores=abt_sc_finite(collect(f.values),"decompor_matriz"),vetores=abt_sc_rows(abt_sc_finite(f.vectors,"decompor_matriz")))
end
function abt_sc_solve(a,b)
 x=abt_sc_matrix(a,"resolver_sistema"); y=abt_sc_reals(b,"resolver_sistema")
 size(x,1)==size(x,2)==length(y) || error("ABT resolver_sistema: matriz quadrada e vetor compatível obrigatórios")
 try
  la=abt_sc_la()
  return Base.invokelatest(x,y,la) do a,b,l
   solution=l.lu(a;check=true)\b
   abt_sc_finite(solution,"resolver_sistema")
   residual=l.norm(a*solution-b); isfinite(residual) || error("resíduo não finito")
   return (; solucao=collect(solution),residuo_norma=residual)
  end
 catch err
  error("ABT resolver_sistema: " * sprint(showerror,err))
 end
end
function abt_sc_adjust(values,method,alpha)
 ps=abt_sc_reals(values,"ajustar_valores_p")
 all(p -> 0<=p<=1,ps) || error("ABT ajustar_valores_p: valores-p fora de [0,1]")
 typeof(alpha)===Float64 && 0<alpha<1 || error("ABT ajustar_valores_p: alpha Float64 em (0,1)")
 method in ("bonferroni","holm","bh","by") || error("ABT ajustar_valores_p: método inválido")
 mt=Base.require(Base.PkgId(Base.UUID("f8716d33-7c4a-5097-896f-ce0ecbd3ef6b"),"MultipleTesting"))
 return Base.invokelatest(ps,method,alpha,mt) do p,m,a,lib
  algorithm=m=="bonferroni" ? lib.Bonferroni() : m=="holm" ? lib.Holm() : m=="bh" ? lib.BenjaminiHochberg() : lib.BenjaminiYekutieli()
  adjusted=lib.adjust(p,algorithm)
  return (; metodo=m,controle=m in ("bonferroni","holm") ? "FWER" : "FDR",alpha=a,originais=p,ajustados=collect(adjusted),rejeitar=collect(adjusted .<= a))
 end
end
function abt_sc_minimize(coefficients,lower,upper,rtol,atol,limit)
 c=abt_sc_reals(coefficients,"minimizar_polinomio")
 all(x -> typeof(x)===Float64 && isfinite(x),(lower,upper,rtol,atol)) || error("ABT minimizar_polinomio: limites e tolerâncias Float64 finitos obrigatórios")
 lower<upper && rtol>=0 && atol>0 || error("ABT minimizar_polinomio: intervalo ou tolerâncias inválidos")
 typeof(limit)===Int64 && limit>0 || error("ABT minimizar_polinomio: limite de iterações inteiro positivo")
 optim=Base.require(Base.PkgId(Base.UUID("429524aa-4258-5aef-a3af-852621145aeb"),"Optim"))
 return Base.invokelatest(c,lower,upper,rtol,atol,limit,optim) do coefficients,l,u,r,a,n,lib
  objective(x)=begin
   value=evalpoly(x,coefficients); isfinite(value) || error("ABT minimizar_polinomio: objetivo não finito")
   value
  end
  result=lib.optimize(objective,l,u,lib.Brent();rel_tol=r,abs_tol=a,iterations=n)
  return (; solucao=lib.minimizer(result),valor_objetivo=lib.minimum(result),iteracoes=lib.iterations(result),convergiu=lib.converged(result),status=lib.converged(result) ? "convergiu" : "limite_iteracoes")
 end
end
