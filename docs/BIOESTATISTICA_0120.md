# ABT 0.12.0 — bioestatística modular

## Inventário anterior

A versão 0.11.8 já continha `descrever` (n, soma, média, mediana, desvio, extremos), `resumir_coluna`, `resumir_grupos`, `contar_categorias`, `agrupar_dados`, `testar_grupos` (Welch/Student bilaterais) e `probabilidade_normal` (cauda superior). `HypothesisTests`, `Distributions` e `StatsBase` já constavam de `Project.toml`/`Manifest.toml`. As operações são declaradas em `src/ExtensionRegistry.jl` com aridade e tipos estáticos; o interpretador usa a implementação registrada e o gerador inclui a mesma fonte Julia apenas quando a operação é usada. `ABT.packages.toml` controla chamadas Julia explícitas e não registra operações da biblioteca ABT. As aplicações existentes em `applications/science/` e `applications/statistics/` usam CSV tipado, testes t e descrições.

## Bibliotecas

- `Statistics` (stdlib) fornece médias, variâncias amostrais, quantis e Pearson.
- `HypothesisTests.jl 0.12.2` fornece intervalos t, testes t, Mann–Whitney, Wilcoxon pareado, Shapiro–Wilk e Fisher exato.
- `StatsBase.jl 0.34.13` fornece Spearman.
- `Distributions.jl 0.25.134` fornece probabilidades e quantis.
- `GLM.jl 1.9.5` foi adicionada para regressão linear. `StatsModels.jl 0.7.10` é dependência transitiva de GLM; nenhuma API de fórmula é exposta por ABT, por isso não foi adicionada como dependência direta.

Todos os pacotes externos são carregados na chamada da operação. `Manifest.toml` fixa as versões resolvidas. Python não é necessário.

## Operações e contratos

Todas exigem números `Int64`/`Float64` finitos e rejeitam `ausente`, salvo contagens estritamente `Int64`. Resultados são registros reutilizáveis; `mostrar` é responsável pela apresentação. Erros de domínio geram diagnóstico `ABT <operação>:`. O tipo `Float64` governa os cálculos e sua precisão.

| Operação | Assinatura | Resultado e condições |
|---|---|---|
| `resumo_estatistico(xs)` | lista, n ≥ 2 | n, média, mediana, variância amostral, desvio, mínimo, máximo, quartis 25%/75% (método padrão de `Statistics.quantile`). |
| `intervalo_confianca_media(xs, nivel)` | n ≥ 2, `0 < nivel < 1`, variância > 0 | IC t bilateral da média; não representa intervalo preditivo. |
| `correlacao(xs, ys, metodo)` | listas pareadas, n ≥ 3, `pearson`/`spearman`, ambas não constantes | coeficiente e n; nenhum valor-p é inferido. |
| `teste_t(xs, ys, metodo, alternativa, diferenca_nula)` | `uma_amostra` (ys = `[]`), `pareado`, `welch` ou `student`; alternativa `bilateral`, `menor`, `maior`; n ≥ 2 por amostra | estatística, graus de liberdade, valor-p. Para pares, a diferença é `xs - ys`; `menor` testa diferença abaixo da hipótese nula e `maior` acima. `student` pressupõe variâncias iguais; Welch não. Variância zero é erro. |
| `teste_nao_parametrico(xs, ys, metodo, alternativa)` | `mann_whitney` ou `wilcoxon_pareado`, n ≥ 2; pares exigem tamanhos iguais | valor-p conforme `HypothesisTests`; empates e zeros seguem o método da biblioteca, sem troca silenciosa de método. |
| `teste_normalidade(xs)` | 3 ≤ n ≤ 5000, variância > 0 | Shapiro–Wilk e valor-p. Rejeição não prova uma distribuição alternativa. |
| `teste_proporcoes(sa, na, sb, nb, alternativa)` | contagens inteiras, `0 ≤ s ≤ n`, `n > 0` | teste exato de Fisher 2×2; proporções observadas e valor-p. `menor` testa proporção A inferior à B e `maior` superior. Sem aproximação qui-quadrado. |
| `probabilidade_distribuicao(modelo, parametros, valor)` | `normal` [média, desvio>0], `student_t` [graus>0], `binomial` [ensaios inteiros≥0, p∈[0,1]], `poisson` [taxa≥0] | CDF `P(X ≤ valor)`; binomial/Poisson exigem valor inteiro. |
| `quantil_distribuicao(modelo, parametros, p)` | mesmos modelos, `0 < p < 1` | quantil da biblioteca; fronteiras 0/1 são rejeitadas por poderem ser infinitas ou ambíguas. |
| `regressao_linear(tabela, resposta, preditores)` | tabela tipada, resposta e preditores numéricos explícitos, sem ausentes, n > parâmetros, posto completo, resposta não constante | OLS com intercepto, coeficientes, erros-padrão, valores-p, IC 95%, R² e n. Preditores categóricos ainda não são suportados; codificação deve ser explícita no CSV/esquema. |

Os testes científicos pressupõem independência e desenho amostral adequado, que ABT não consegue verificar. Nenhuma correção por múltiplas comparações é aplicada. O valor-p não é tamanho de efeito. Regressão usa inferência clássica de OLS, sem ajuste robusto de heterocedasticidade. Os resultados não devem ser interpretados clinicamente sem validação do desenho e dos dados.

## Aplicações reproduzíveis

Dados em `applications/biostatistics/*.csv` são sintéticos e não representam conclusões clínicas.

```bash
export ABT_JULIA=/caminho/para/julia-1.13.3/bin/julia
julia --project=. -e 'import Pkg; Pkg.instantiate()'
bin/abt run applications/biostatistics/ensaio_clinico.abt
bin/abt run applications/biostatistics/correlacao_biomedica.abt
bin/abt run applications/biostatistics/regressao_clinica.abt
```

Cada programa imprime um registro JSON completo em uma linha. Nesta execução, o ensaio retornou médias 12.12 (controle) e 10.4 (tratamento), a correlação retornou Pearson 0.9918405049944308 e Spearman 1.0, e a regressão retornou R² 0.9891214853740421 com n=8. Esses valores são apenas verificações reproduzíveis dos dados sintéticos. O primeiro compara dois grupos e calcula um IC; o segundo informa Pearson/Spearman; o terceiro ajusta dois preditores numéricos.

## Testes

```bash
julia --project=. --startup-file=no tests/test_biostatistics_0120.jl
ABT_JULIA=/caminho/para/julia-1.13.3/bin/julia python3 tests/test_biostatistics_backends.py
JULIA_CONDAPKG_BACKEND=Null JULIA_PYTHONCALL_EXE=/usr/bin/python3 ABT_JULIA=/caminho/para/julia-1.13.3/bin/julia python3 tests/run_all_tests.py --julia "$ABT_JULIA" --timeout 180
```

A suíte direta compara valores, erros-padrão, valores-p e intervalos com as bibliotecas Julia. A suíte de backends compara JSON estruturado, com tolerância relativa/absoluta de 1e-12 apenas para valores de ponto flutuante. Erros são comparados pela categoria diagnóstica e código de saída. Logs e contagens desta execução ficam em `logs/test_logs/biostatistics_direct.log`, `logs/test_logs/biostatistics_backends.log` e `logs/test_logs/biostatistics_backends.json`.

## Validação executada em 10/11/2026

Ambiente: Ubuntu Linux, Julia 1.13.3, Python 3 em `/usr/bin/python3` apenas para os testes legados de interoperabilidade. `GLM 1.9.5` e `StatsModels 0.7.10` foram instalados no ambiente Julia; `StatsModels` permanece transitivo. A instalação usa `Project.toml` e `Manifest.toml` deste repositório.

| Suíte | Resultado |
|---|---:|
| Comparação direta com Julia (inclui coeficientes, erros-padrão, valores-p e IC de GLM) | 33 PASS, 0 FAIL |
| Diferencial ABT / Julia sem otimização / Julia otimizado | 16 casos × 3 backends, 0 divergências |
| Histórico completo | 42 PASS, 2 PROBE, 0 PARTIAL, 0 FAIL, 0 TIMEOUT |
| Extensões anteriores | 45 PASS, 0 FAIL |
| Extensões modulares | 51 PASS, 0 FAIL |
| Lote científico anterior | 33 PASS, 0 FAIL |
| Instalação e CLI (inclui atualização da instalação anterior) | 10 PASS, 0 FAIL |
| Aplicações anteriores (estatística, CSV, DNA) | 9 execuções PASS, 0 FAIL |
| CLI pública | 20 PASS, 0 FAIL |

Os dois `PROBE` (`break_abt.jl` e `audit_adversarial.jl`) são sondas exploratórias e não são contados como aprovação funcional. Nenhum teste foi ignorado na execução histórica final. A suíte diferencial compara JSON estruturado, sem tratar mudanças de tipo, campos ou erros como equivalentes. Somente números de ponto flutuante usam tolerância de 1e-12. Os três programas novos foram executados nos três backends.

A primeira execução de desenvolvimento revelou dois problemas corrigidos: o instalador não copiava o novo módulo, e uma entrada do teste diferencial usava `ausente` como literal, que a gramática não possui. Também houve uma execução histórica interrompida após um `PARTIAL` causado por PythonCall sem configuração de ambiente; a execução integral repetida com `JULIA_CONDAPKG_BACKEND=Null` e `JULIA_PYTHONCALL_EXE=/usr/bin/python3` terminou sem `PARTIAL`. Nenhum desses resultados intermediários foi contado como aprovação final.

Os resultados estruturados da execução final estão em `logs/biostatistics_0120/historical/summary.json` e `logs/test_logs/biostatistics_backends.json`; os logs históricos individuais desta rodada foram copiados para `logs/biostatistics_0120/historical/`. Os arquivos históricos já presentes em `logs/test_logs/` foram restaurados após a cópia.

### Limites remanescentes

A regressão aceita apenas colunas numéricas tipadas e não codifica fatores automaticamente. O teste t e OLS usam inferência paramétrica clássica; ABT não verifica independência, normalidade dos resíduos, heterocedasticidade nem confundimento. O teste de normalidade usa a faixa 3–5000 de `HypothesisTests`. Valores `Int64` são promovidos a `Float64` para cálculo, com a precisão correspondente. A leitura CSV e a regressão materializam as colunas necessárias. O acesso a bibliotecas Julia e Python é confiável e não constitui sandbox.
