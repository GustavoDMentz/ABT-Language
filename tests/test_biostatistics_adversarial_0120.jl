using Test
include(joinpath(@__DIR__, "..", "src", "ABT.jl"))
import .ABT
import CSV, Statistics, Distributions, HypothesisTests, StatsBase

@testset "bioestatística adversarial 0.12.0" begin
    small = ABT.abt_std_stat_summary([1, 2])
    @test small.variancia == 0.5
    ci = ABT.abt_std_mean_ci([1, 2], 0.95)
    margin = Distributions.quantile(Distributions.TDist(1), 0.975) * Statistics.std([1.0,2.0]) / sqrt(2)
    @test ci.inferior ≈ 1.5 - margin
    @test ci.superior ≈ 1.5 + margin

    x = [1,1,2,3]; y = [1,2,2,3]
    ranks_x = [1.5,1.5,3.0,4.0]; ranks_y = [1.0,2.5,2.5,4.0]
    @test ABT.abt_std_correlation(x,y,"spearman").coeficiente ≈ Statistics.cor(ranks_x,ranks_y)
    @test_throws "variável constante" ABT.abt_std_correlation([1,1,1], [1,2,3], "spearman")

    left = ABT.abt_std_t_test([1,2,3], [3,4,5], "welch", "menor", 0)
    right = ABT.abt_std_t_test([1,2,3], [3,4,5], "welch", "maior", 0)
    @test left.p_valor ≈ Distributions.cdf(Distributions.TDist(left.graus_liberdade), left.estatistica)
    @test right.p_valor ≈ Distributions.ccdf(Distributions.TDist(right.graus_liberdade), right.estatistica)
    @test left.p_valor + right.p_valor ≈ 1.0
    paired = ABT.abt_std_t_test([1,4,6,9], [2,3,5,7], "pareado", "bilateral", 0)
    @test paired.estatistica ≈ HypothesisTests.OneSampleTTest([-1.0,1.0,1.0,2.0]).t
    @test paired.graus_liberdade == 3.0
    @test_throws "diferenças constantes" ABT.abt_std_t_test([1,2,3],[2,3,4],"pareado","bilateral",0)

    ties = ABT.abt_std_nonparametric([1,1,2,2],[2,2,3,3],"mann_whitney","bilateral")
    @test ties.p_valor ≈ HypothesisTests.pvalue(HypothesisTests.MannWhitneyUTest([1,1,2,2],[2,2,3,3]))
    zeros = ABT.abt_std_nonparametric([1,2,3],[1,2,3],"wilcoxon_pareado","bilateral")
    @test zeros.p_valor == 1.0 # HypothesisTests defines this degenerate exact result.
    @test_throws "pares exigem mesmo tamanho" ABT.abt_std_nonparametric([1,2,3],[1,2],"wilcoxon_pareado","bilateral")

    fisher = ABT.abt_std_proportions(8,10,3,10,"maior")
    exact = sum(binomial(big(11),k)*binomial(big(9),10-k) for k in 8:10)/binomial(big(20),10)
    @test fisher.p_valor ≈ Float64(exact)
    @test ABT.abt_std_proportions(8,10,3,10,"menor").p_valor > 0.99
    @test_throws "total combinado excede Int64" ABT.abt_std_proportions(1,typemax(Int64),1,1,"bilateral")
    @test_throws "contagens fora do domínio" ABT.abt_std_proportions(-1,10,1,10,"bilateral")

    @test ABT.abt_std_distribution_probability("poisson",[3],-1).resultado == 0.0
    @test ABT.abt_std_distribution_quantile("binomial",Any[0,0.5],0.5).resultado == 0
    @test_throws "quantidade ou domínio" ABT.abt_std_distribution_probability("binomial",Any[10,1.1],5)
    @test_throws "contagem deve ser Int64" ABT.abt_std_distribution_probability("binomial",Any[10,0.5],5.0)
    @test_throws "quantil de fronteira" ABT.abt_std_distribution_quantile("normal",[0,1],0)
    @test_throws "não finito" ABT.abt_std_stat_summary([1e308,-1e308])
    @test_throws "variância zero" ABT.abt_std_normality([2,2,2])
    @test_throws "no máximo 5000" ABT.abt_std_normality(collect(1:5001))

    schema = ABT.abt_std_schema("y","real","x1","real","x2","real")
    mktemp() do path, io
        write(io,"y,x1,x2\n2,1,2\n4,2,4\n6,3,6\n8,4,8\n")
        flush(io)
        table=ABT.abt_std_csv(path,schema,"erro")
        @test_throws "preditores colineares" ABT.abt_std_linear_regression(table,"y",["x1","x2"])
        @test_throws "resposta inexistente" ABT.abt_std_linear_regression(table,"z",["x1"])
    end
    mktemp() do path, io
        write(io,"y,x1,x2\n2,1,2\n4,2,4\n")
        flush(io)
        table=ABT.abt_std_csv(path,schema,"erro")
        @test_throws "observações insuficientes" ABT.abt_std_linear_regression(table,"y",["x1","x2"])
    end
    mktemp() do path, io
        write(io,"y,x1,x2\n2,1,2\n4,erro,4\n6,3,6\n8,4,8\n")
        flush(io)
        table=ABT.abt_std_csv(path,schema,"erro")
        @test_throws "invalid real value" ABT.abt_std_linear_regression(table,"y",["x1","x2"])
    end
end
