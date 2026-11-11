using Test
include(joinpath(@__DIR__, "..", "src", "ABT.jl"))
import .ABT
import Statistics, HypothesisTests, StatsBase, Distributions, GLM

@testset "bioestatística comparada com Julia" begin
 x = [1,2,3,4,5]
 summary = ABT.abt_std_stat_summary(x)
 @test summary.n == 5
 @test summary.media ≈ Statistics.mean(x)
 @test summary.variancia ≈ Statistics.var(x)
 @test summary.q1 ≈ Statistics.quantile(x, .25)
 ci = ABT.abt_std_mean_ci(x, .95)
 @test [ci.inferior,ci.superior] ≈ collect(HypothesisTests.confint(HypothesisTests.OneSampleTTest(x);level=.95))
 @test ABT.abt_std_correlation(x,[2,3,5,7,11],"spearman").coeficiente ≈ StatsBase.corspearman(x,[2,3,5,7,11])
 t = ABT.abt_std_t_test([1,2,3,4],[2,3,4,5],"welch","bilateral",0)
 @test t.p_valor ≈ HypothesisTests.pvalue(HypothesisTests.UnequalVarianceTTest([1,2,3,4],[2,3,4,5]))
 @test ABT.abt_std_t_test([1,2,3,4],[2,3,4,5],"welch","menor",0).p_valor ≈
       HypothesisTests.pvalue(HypothesisTests.UnequalVarianceTTest([1,2,3,4],[2,3,4,5]);tail=:left)
 @test ABT.abt_std_nonparametric([1,2,3],[4,5,6],"mann_whitney","bilateral").p_valor ≈
       HypothesisTests.pvalue(HypothesisTests.MannWhitneyUTest([1,2,3],[4,5,6]))
 @test ABT.abt_std_normality([1,2,3,4,5]).p_valor ≈ HypothesisTests.pvalue(HypothesisTests.ShapiroWilkTest([1,2,3,4,5]))
 @test ABT.abt_std_proportions(8,10,3,10,"bilateral").p_valor ≈ HypothesisTests.pvalue(HypothesisTests.FisherExactTest(8,2,3,7))
 @test ABT.abt_std_distribution_probability("binomial",Any[10,.5],5).resultado ≈ Distributions.cdf(Distributions.Binomial(10,.5),5)
 @test ABT.abt_std_distribution_probability("normal",[0,1],0).resultado ≈ Distributions.cdf(Distributions.Normal(0,1),0)
 @test ABT.abt_std_distribution_probability("poisson",[3],2).resultado ≈ Distributions.cdf(Distributions.Poisson(3),2)
 @test ABT.abt_std_distribution_quantile("student_t",[4],.975).resultado ≈ Distributions.quantile(Distributions.TDist(4),.975)
 @test ABT.abt_std_distribution_quantile("binomial",Any[10,.5],.5).resultado == Distributions.quantile(Distributions.Binomial(10,.5),.5)
 @test ABT.abt_std_distribution_quantile("poisson",[3],.5).resultado == Distributions.quantile(Distributions.Poisson(3),.5)
 schema = ABT.abt_std_schema("resposta","real","idade","inteiro","exposicao","inteiro")
 table = ABT.abt_std_csv(joinpath(@__DIR__,"..","applications","biostatistics","regressao.csv"),schema,"erro")
 model = ABT.abt_std_linear_regression(table,"resposta",["idade","exposicao"])
 rows = collect(table.rows)
 matrix = hcat(ones(length(rows)),[r.idade for r in rows],[r.exposicao for r in rows])
 direct = GLM.lm(matrix,[r.resposta for r in rows])
 @test [c.estimativa for c in model.coeficientes] ≈ GLM.coef(direct)
 @test [c.erro_padrao for c in model.coeficientes] ≈ GLM.stderror(direct)
 @test [c.p_valor for c in model.coeficientes] ≈ GLM.coeftable(direct).cols[4]
 @test hcat([c.inferior for c in model.coeficientes], [c.superior for c in model.coeficientes]) ≈ GLM.confint(direct)
 @test model.r_quadrado ≈ GLM.r2(direct)
 @test_throws ErrorException ABT.abt_std_linear_regression(table,"resposta",["idade","idade"])
 mktemp() do path, io
  write(io,"resposta,idade,exposicao\n1.0,20,0\n2.0,30,1\n3.0,,0\n4.0,50,1\n")
  flush(io)
  incomplete=ABT.abt_std_csv(path,schema,"permitir")
  @test_throws ErrorException ABT.abt_std_linear_regression(incomplete,"resposta",["idade","exposicao"])
 end
 @test_throws ErrorException ABT.abt_std_stat_summary([1,missing,3])
 @test_throws ErrorException ABT.abt_std_correlation([1,1,1],[1,2,3],"pearson")
 @test_throws ErrorException ABT.abt_std_mean_ci([2,2,2],.95)
 @test_throws ErrorException ABT.abt_std_t_test([1,2],[3,4],"pareado","bilateral",NaN)
 @test_throws ErrorException ABT.abt_std_proportions(11,10,2,10,"bilateral")
 @test_throws ErrorException ABT.abt_std_normality([1,1,1])
 @test_throws ErrorException ABT.abt_std_stat_summary([1.0,Inf])
 @test_throws ErrorException ABT.abt_std_t_test([1,2],[3,4],"welch","inválida",0)
 @test_throws ErrorException ABT.abt_std_distribution_quantile("normal",[0,1],1)
end
