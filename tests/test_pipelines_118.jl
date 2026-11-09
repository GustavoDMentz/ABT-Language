using Test
include("test_differential_1000.jl")

const PIPELINE_CASES = [
 ("basic", "dados=[1,2,3,4,5]\ndados\n    filtrar onde valor > 2\n    transformar com valor * 10\n    limitar a 2\n    mostrar"),
 ("empty", "[]\n  filtrar onde valor > 0\n  transformar com valor + 1\n  limitar a 2\n  mostrar"),
 ("shadow", "x=99\n[1,2]\n  transformar com valor + 1\n  mostrar\nmostrar x"),
 ("block", "function f(xs) {\nxs\n  filtrar onde valor > 1\n  mostrar\n}\nmostrar f([1,2,3])"),
 ("effects", "function f(x) { show x; return x*2 }\n[1,2,3]\n  transformar com f(valor)\n  mostrar"),
 ("incompatible", "3\n  filtrar onde valor > 1\n  mostrar"),
 ("bad_predicate", "[1,2]\n  filtrar onde valor + 1\n  mostrar"),
 ("bad_limit", "[1,2]\n  limitar a (0-1)\n  mostrar"),
 ("limit_before_map", "[1,2,3]\n  limitar a 1\n  transformar com valor * 10\n  mostrar"),
]
@testset "ABT 0.11.8 pipeline differential" begin
 for (id, (category, source)) in enumerate(PIPELINE_CASES)
  ok, reason, _ = run_one(id, category, source)
  @test ok || error("$category: $reason")
 end
end
@testset "ABT 0.11.8 pipeline diagnostics" begin
 bad = [
  ("x=[1]\nx\n  filtrar onde valor > 0", "terminal mostrar"),
  ("x=[1]\nx\n  filtrar onde valor > 0\n    mostrar", "inconsistent indentation"),
  ("x=[1]\nx\n  ordenar por valor\n  mostrar", "unknown pipeline step"),
  ("x=[1]\nx\n  filtrar valor > 0\n  mostrar", "expected 'WHERE'"),
  ("x=[1]\nx\n  transformar com\n  mostrar", "incomplete transformar"),
  ("x=[1]\nx\n  mostrar 1", "mostrar is terminal"),
  ("x=[1]\nx\n\tfiltrar onde valor > 0\n\tmostrar", "tabs in pipeline"),
 ]
 for (source, message) in bad
  err = try tokenize(source); nothing catch e; e end
  @test err isa Exception && occursin(message, sprint(showerror, err))
 end
end

@testset "ABT 0.11.8 seeded pipelines" begin
 rng = MersenneTwister(0xAB7118)
 for id in 1:100
  a, b, c = rand(rng, 0:20), rand(rng, 0:20), rand(rng, 0:20)
  source = "xs=[$a,$b,$c]\nxs\n  filtrar onde valor >= $b\n  transformar com valor + $a\n  limitar a $(id % 4)\n  mostrar"
  ok, reason, _ = run_one(id, "seeded", source)
  @test ok || error("case $id: $reason\n$source")
 end
end
