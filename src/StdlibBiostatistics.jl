# Scientific operations use the same extension registry in both backends.
abt_bio_number(x) = (typeof(x) === Int64 || typeof(x) === Float64) && isfinite(x)
function abt_bio_require(name, uuid)
 try
  return Base.invokelatest(Base.require, Base.PkgId(Base.UUID(uuid), name))
 catch err
  error("ABT extensão $name indisponível: " * sprint(showerror, err))
 end
end
function abt_bio_numbers(xs, operation; minimum=2)
 xs isa Vector && length(xs) >= minimum || error("ABT $operation: esperado vetor com ao menos $minimum números")
 all(abt_bio_number, xs) || error("ABT $operation: valores ausentes, não finitos ou incompatíveis")
 values = Float64.(xs)
 all(isfinite, values) || error("ABT $operation: conversão numérica não finita")
 return values
end
abt_bio_variable(xs) = (v = Statistics.var(xs); isfinite(v) && v > 0)

function abt_std_stat_summary(xs)
 values = abt_bio_numbers(xs, "resumo_estatistico")
 n = length(values)
 mean_value = Statistics.mean(values)
 variance = Statistics.var(values)
 result = (; n=n, media=mean_value, mediana=Statistics.median(values),
            variancia=variance, desvio_padrao=sqrt(variance), minimo=minimum(values),
            maximo=maximum(values), q1=Statistics.quantile(values, 0.25),
            q3=Statistics.quantile(values, 0.75))
 all(isfinite, Tuple(result)[2:end]) || error("ABT resumo_estatistico: resultado não finito")
 return result
end

function abt_bio_level(level, operation)
 abt_bio_number(level) && 0 < level < 1 || error("ABT $operation: nível deve estar entre 0 e 1")
 return Float64(level)
end

function abt_std_mean_ci(xs, level)
 values = abt_bio_numbers(xs, "intervalo_confianca_media")
 confidence = abt_bio_level(level, "intervalo_confianca_media")
 abt_bio_variable(values) || error("ABT intervalo_confianca_media: variância zero ou não finita")
 ht = abt_bio_require("HypothesisTests", "09f84164-cd44-5f33-b23f-e6b0d136a0d5")
 return Base.invokelatest(abt_std_mean_ci_loaded, values, confidence, ht)
end
function abt_std_mean_ci_loaded(values, level, ht)
 try
  bounds = ht.confint(ht.OneSampleTTest(values); level=level)
  all(isfinite,bounds) || error("intervalo não finito")
  return (; n=length(values), nivel=level, media=Statistics.mean(values),
          inferior=Float64(bounds[1]), superior=Float64(bounds[2]), metodo="t_student")
 catch err
  error("ABT intervalo_confianca_media: " * sprint(showerror, err))
 end
end

function abt_std_correlation(xs, ys, method)
 x = abt_bio_numbers(xs, "correlacao"; minimum=3)
 y = abt_bio_numbers(ys, "correlacao"; minimum=3)
 length(x) == length(y) || error("ABT correlacao: vetores devem ter o mesmo tamanho")
 abt_bio_variable(x) && abt_bio_variable(y) || error("ABT correlacao: variável constante ou variância não finita")
 method in ("pearson", "spearman") || error("ABT correlacao: método deve ser pearson ou spearman")
 if method == "pearson"
  value = Statistics.cor(x, y)
 else
  sb = abt_bio_require("StatsBase", "2913bbd2-ae8a-5f71-8c99-4fb6c76f3a91")
  value = Base.invokelatest(sb.corspearman, x, y)
 end
 isfinite(value) || error("ABT correlacao: correlação indefinida")
 return (; metodo=method, n=length(x), coeficiente=Float64(value))
end

function abt_bio_tail(alternative, operation)
 alternative in ("bilateral", "menor", "maior") || error("ABT $operation: alternativa deve ser bilateral, menor ou maior")
 return alternative == "bilateral" ? :both : alternative == "menor" ? :left : :right
end

function abt_std_t_test(xs, ys, method, alternative, null_value)
 x = abt_bio_numbers(xs, "teste_t")
 method in ("uma_amostra", "pareado", "welch", "student") || error("ABT teste_t: método inválido")
 y = method == "uma_amostra" ? (ys isa Vector && isempty(ys) ? Float64[] : error("ABT teste_t: segunda amostra deve ser []")) : abt_bio_numbers(ys, "teste_t")
 method == "pareado" && length(x) != length(y) && error("ABT teste_t: amostras pareadas exigem mesmo tamanho")
 abt_bio_number(null_value) || error("ABT teste_t: hipótese nula deve ser finita")
 tail = abt_bio_tail(alternative, "teste_t")
 if method == "uma_amostra"
  abt_bio_variable(x) || error("ABT teste_t: variância zero ou não finita")
 elseif method == "pareado"
  abt_bio_variable(x .- y) || error("ABT teste_t: diferenças constantes ou variância não finita")
 else
  abt_bio_variable(x) && abt_bio_variable(y) || error("ABT teste_t: variância zero ou não finita")
 end
 ht = abt_bio_require("HypothesisTests", "09f84164-cd44-5f33-b23f-e6b0d136a0d5")
 return Base.invokelatest(abt_std_t_test_loaded, x, y, method, alternative, tail, Float64(null_value), ht)
end
function abt_std_t_test_loaded(x,y,method,alternative,tail,null_value,ht)
 try
  test = method == "uma_amostra" ? ht.OneSampleTTest(x, null_value) :
         method == "pareado" ? ht.OneSampleTTest(x, y, null_value) :
         method == "welch" ? ht.UnequalVarianceTTest(x, y, null_value) :
         ht.EqualVarianceTTest(x, y, null_value)
  p=Float64(ht.pvalue(test;tail=tail))
  isfinite(test.t) && isfinite(test.df) && isfinite(p) || error("inferência não finita")
  return (; metodo=method, alternativa=alternative, n_a=length(x), n_b=length(y),
          hipotese_nula=null_value, estatistica=Float64(test.t),
          graus_liberdade=Float64(test.df), p_valor=p)
 catch err
  error("ABT teste_t: " * sprint(showerror, err))
 end
end

function abt_std_nonparametric(xs, ys, method, alternative)
 x = abt_bio_numbers(xs, "teste_nao_parametrico")
 y = abt_bio_numbers(ys, "teste_nao_parametrico")
 method in ("mann_whitney", "wilcoxon_pareado") || error("ABT teste_nao_parametrico: método inválido")
 method == "wilcoxon_pareado" && length(x) != length(y) && error("ABT teste_nao_parametrico: pares exigem mesmo tamanho")
 tail = abt_bio_tail(alternative, "teste_nao_parametrico")
 ht = abt_bio_require("HypothesisTests", "09f84164-cd44-5f33-b23f-e6b0d136a0d5")
 return Base.invokelatest(abt_std_nonparametric_loaded, x,y,method,alternative,tail,ht)
end
function abt_std_nonparametric_loaded(x,y,method,alternative,tail,ht)
 try
  test = method == "mann_whitney" ? ht.MannWhitneyUTest(x,y) : ht.SignedRankTest(x,y)
  p=Float64(ht.pvalue(test; tail=tail))
  isfinite(p) || error("valor-p não finito")
  return (; metodo=method, alternativa=alternative, n_a=length(x), n_b=length(y), p_valor=p)
 catch err
  error("ABT teste_nao_parametrico: " * sprint(showerror, err))
 end
end

function abt_std_normality(xs)
 x = abt_bio_numbers(xs, "teste_normalidade"; minimum=3)
 length(x) <= 5000 || error("ABT teste_normalidade: Shapiro-Wilk suporta no máximo 5000 valores")
 abt_bio_variable(x) || error("ABT teste_normalidade: variância zero ou não finita")
 ht = abt_bio_require("HypothesisTests", "09f84164-cd44-5f33-b23f-e6b0d136a0d5")
 return Base.invokelatest(abt_std_normality_loaded,x,ht)
end
function abt_std_normality_loaded(x,ht)
 try
  test=ht.ShapiroWilkTest(x)
  p=Float64(ht.pvalue(test))
  isfinite(test.W) && isfinite(p) || error("inferência não finita")
  return (; metodo="shapiro_wilk", n=length(x), estatistica=Float64(test.W), p_valor=p)
 catch err
  error("ABT teste_normalidade: " * sprint(showerror, err))
 end
end

function abt_std_proportions(success_a,total_a,success_b,total_b,alternative)
 all(x -> typeof(x)===Int64,(success_a,total_a,success_b,total_b)) ||
  error("ABT teste_proporcoes: contagens devem ser Int64")
 total_a > 0 && total_b > 0 && 0 <= success_a <= total_a && 0 <= success_b <= total_b ||
  error("ABT teste_proporcoes: contagens fora do domínio")
 total_a <= typemax(Int64) - total_b ||
  error("ABT teste_proporcoes: total combinado excede Int64")
 tail=abt_bio_tail(alternative,"teste_proporcoes")
 ht=abt_bio_require("HypothesisTests", "09f84164-cd44-5f33-b23f-e6b0d136a0d5")
 return Base.invokelatest(abt_std_proportions_loaded,success_a,total_a,success_b,total_b,alternative,tail,ht)
end
function abt_std_proportions_loaded(sa,na,sb,nb,alternative,tail,ht)
 try
  test=ht.FisherExactTest(sa,na-sa,sb,nb-sb)
  p=Float64(ht.pvalue(test;tail=tail))
  isfinite(p) || error("valor-p não finito")
  return (; metodo="fisher_exato", alternativa=alternative, sucessos_a=sa, total_a=na,
          sucessos_b=sb, total_b=nb, proporcao_a=sa/na, proporcao_b=sb/nb,
          p_valor=p)
 catch err
  error("ABT teste_proporcoes: " * sprint(showerror,err))
 end
end

function abt_std_distribution(name, parameters, value, quantile)
 name in ("normal", "student_t", "binomial", "poisson") || error("ABT distribuição: modelo inválido")
 parameters isa Vector || error("ABT distribuição: parâmetros devem ser uma lista")
 all(abt_bio_number, parameters) || error("ABT distribuição: parâmetros inválidos")
 abt_bio_number(value) || error("ABT distribuição: valor inválido")
 if quantile
  0 <= value <= 1 || error("ABT distribuição: probabilidade deve estar entre 0 e 1")
  value in (0,1) && error("ABT distribuição: quantil de fronteira não finito ou indefinido")
 end
 valid = name == "normal" ? length(parameters)==2 && parameters[2]>0 :
         name == "student_t" ? length(parameters)==1 && parameters[1]>0 :
         name == "binomial" ? length(parameters)==2 && typeof(parameters[1])===Int64 && parameters[1]>=0 && 0<=parameters[2]<=1 :
         length(parameters)==1 && parameters[1]>=0
 valid || error("ABT distribuição: quantidade ou domínio dos parâmetros inválido")
 dist=abt_bio_require("Distributions", "31c24e10-a181-5473-b8eb-7969acd0382f")
 return Base.invokelatest(abt_std_distribution_loaded,name,parameters,value,quantile,dist)
end
function abt_std_distribution_loaded(name,parameters,value,quantile,dist)
 try
  model = name == "normal" ? dist.Normal(parameters...) : name == "student_t" ? dist.TDist(parameters...) :
          name == "binomial" ? dist.Binomial(parameters...) : dist.Poisson(parameters...)
  if !quantile && name in ("binomial","poisson")
   typeof(value)===Int64 || error("contagem deve ser Int64")
  end
  result = quantile ? dist.quantile(model,Float64(value)) : dist.cdf(model,value)
  isfinite(result) || error("resultado não finito")
  return (; modelo=name, parametros=copy(parameters), entrada=value, resultado=result)
 catch err
  error("ABT distribuição: " * sprint(showerror, err))
 end
end
abt_std_distribution_probability(name,parameters,value) = abt_std_distribution(name,parameters,value,false)
abt_std_distribution_quantile(name,parameters,value) = abt_std_distribution(name,parameters,value,true)

function abt_std_linear_regression(table, response, predictors)
 abt_std_istable(table) || error("ABT regressao_linear: esperado tabela tipada")
 response isa String && response in table.columns || error("ABT regressao_linear: resposta inexistente")
 predictors isa Vector && !isempty(predictors) && all(x -> x isa String && x in table.columns, predictors) ||
  error("ABT regressao_linear: preditores devem ser colunas explícitas existentes")
 length(unique(predictors)) == length(predictors) && !(response in predictors) ||
  error("ABT regressao_linear: preditores distintos da resposta são obrigatórios")
 names = [response; predictors]
 all(name -> table.types[findfirst(==(name),table.columns)] in ("inteiro","real"), names) ||
  error("ABT regressao_linear: resposta e preditores devem ser numéricos")
 columns = [Float64[] for _ in names]
 count = 0
 try
  for row in table.rows
   count += 1
   for (i,name) in enumerate(names)
    value = getproperty(row,Symbol(name))
    abt_bio_number(value) || error("ABT regressao_linear: linha $count, coluna '$name': valor ausente ou inválido")
    converted = Float64(value)
    isfinite(converted) || error("ABT regressao_linear: linha $count, coluna '$name': conversão não finita")
    push!(columns[i],converted)
   end
  end
 catch err
  abt_std_table_error("regressao_linear",table,err)
 end
 count > length(predictors)+1 || error("ABT regressao_linear: observações insuficientes para os parâmetros")
 abt_bio_variable(columns[1]) || error("ABT regressao_linear: resposta constante ou variância não finita")
 X = hcat(ones(Float64,count),columns[2:end]...)
 la = abt_bio_require("LinearAlgebra", "37e2e46d-f89d-539d-b4ee-838fcccc9c8e")
 Base.invokelatest(la.rank,X) == size(X,2) || error("ABT regressao_linear: preditores colineares")
 glm = abt_bio_require("GLM", "38e38edf-8417-5370-95a0-9cbb8c7f171a")
 return Base.invokelatest(abt_std_linear_regression_loaded,X,columns[1],response,predictors,glm)
end
function abt_std_linear_regression_loaded(X,y,response,predictors,glm)
 try
  model = glm.lm(X,y)
  ct = glm.coeftable(model)
  bounds = glm.confint(model)
  coefficients = [(; nome=name, estimativa=Float64(glm.coef(model)[i]),
                   erro_padrao=Float64(glm.stderror(model)[i]),
                   p_valor=Float64(ct.cols[4][i]), inferior=Float64(bounds[i,1]),
                   superior=Float64(bounds[i,2])) for (i,name) in enumerate(["intercepto"; predictors])]
  all(c -> all(isfinite,(c.estimativa,c.erro_padrao,c.p_valor,c.inferior,c.superior)),coefficients) ||
   error("inferência não finita; verifique variabilidade residual")
  fit = Float64(glm.r2(model))
  isfinite(fit) || error("R² não finito")
  return (; n=length(y), resposta=response, preditores=copy(predictors), coeficientes=coefficients,
          r_quadrado=fit, nivel=0.95)
 catch err
  error("ABT regressao_linear: " * sprint(showerror,err))
 end
end
