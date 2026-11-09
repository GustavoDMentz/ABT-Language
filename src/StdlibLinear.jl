# Solve an explicitly Float64, square, symmetric positive definite system.
function abt_std_solve_spd(rows, terms)
 rows isa AbstractVector && !isempty(rows) ||
  error("ABT resolver_sistema_spd: matriz deve ser lista não vazia")
 terms isa AbstractVector && length(terms) == length(rows) ||
  error("ABT resolver_sistema_spd: vetor deve ter o tamanho da matriz")
 n = length(rows)
 matrix = Matrix{Float64}(undef, n, n)
 vector = Vector{Float64}(undef, n)
 for i in 1:n
  row = rows[i]
  row isa AbstractVector && length(row) == n ||
   error("ABT resolver_sistema_spd: linha $i deve ter $n valores")
  for j in 1:n
   value = row[j]
   typeof(value) === Float64 && isfinite(value) ||
    error("ABT resolver_sistema_spd: matriz[$i,$j] deve ser Float64 finito")
   matrix[i,j] = value
  end
  value = terms[i]
  typeof(value) === Float64 && isfinite(value) ||
   error("ABT resolver_sistema_spd: vetor[$i] deve ser Float64 finito")
  vector[i] = value
 end
 for j in 1:n, i in 1:j-1
  matrix[i,j] == matrix[j,i] ||
   error("ABT resolver_sistema_spd: matriz não simétrica em [$i,$j]")
 end
 la = try
  Base.require(Base.PkgId(Base.UUID("37e2e46d-f89d-539d-b4ee-838fcccc9c8e"), "LinearAlgebra"))
 catch err
  error("ABT resolver_sistema_spd: LinearAlgebra indisponível: " * sprint(showerror, err))
 end
 solution = try
  symmetric = Base.invokelatest(la.Symmetric, matrix)
  factor = Base.invokelatest(la.cholesky, symmetric)
  Base.invokelatest(\, factor, vector)
 catch err
  error("ABT resolver_sistema_spd: fatoração/solução: " * sprint(showerror, err))
 end
 all(isfinite, solution) || error("ABT resolver_sistema_spd: solução não finita")
 residual = Base.invokelatest(la.norm, matrix * solution - vector)
 isfinite(residual) || error("ABT resolver_sistema_spd: resíduo não finito")
 return (; solucao=collect(solution), residuo_norma=residual)
end
