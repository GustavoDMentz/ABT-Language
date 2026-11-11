# Estatística e bioestatística

Todas as assinaturas abaixo são chamadas ABT, não assinaturas Julia internas. Não há argumentos opcionais além dos indicados. Os arquivos de exemplo são executados a partir da raiz do repositório pelo validador da documentação.

## `resumo_estatistico`

`resumo_estatistico(xs)`

Resume amostra com quartis.

- **Parâmetros e padrões:** Lista de números finitos, n ≥ 2; sem padrão.
- **Retorno:** Registro com n, média, mediana, variância amostral, desvio, extremos e quartis 25/75%.
- **Pré-condições, ausentes, erros e limites:** Ausente, tipo incompatível ou resultado não finito são erros; quartis usam `Statistics.quantile`.
- **Efeitos:** Nenhum.
- **Dependência Julia:** Statistics (stdlib).
- **Exemplo executável:** [`docs/examples/estatistica.abt`](../examples/programs.md#estatistica).
- **Operações relacionadas nesta seção:** `intervalo_confianca_media`, `correlacao`, `teste_t`, `teste_nao_parametrico`, `teste_normalidade`, `teste_proporcoes`, `probabilidade_distribuicao`, `quantil_distribuicao`, `regressao_linear`, `probabilidade_normal`.

## `intervalo_confianca_media`

`intervalo_confianca_media(xs, nivel)`

Calcula intervalo t bilateral da média.

- **Parâmetros e padrões:** Lista numérica n ≥ 2; nível numérico estritamente entre 0 e 1.
- **Retorno:** Registro n, nível, média, limites inferior/superior e método.
- **Pré-condições, ausentes, erros e limites:** Variância zero, ausente, nível inválido e intervalo não finito são erros.
- **Efeitos:** Nenhum.
- **Dependência Julia:** HypothesisTests.jl sob demanda.
- **Exemplo executável:** [`docs/examples/estatistica.abt`](../examples/programs.md#estatistica).
- **Operações relacionadas nesta seção:** `resumo_estatistico`, `correlacao`, `teste_t`, `teste_nao_parametrico`, `teste_normalidade`, `teste_proporcoes`, `probabilidade_distribuicao`, `quantil_distribuicao`, `regressao_linear`, `probabilidade_normal`.

## `correlacao`

`correlacao(xs, ys, metodo)`

Calcula Pearson ou Spearman.

- **Parâmetros e padrões:** Listas pareadas n ≥ 3; método `pearson`/`spearman`.
- **Retorno:** Registro método, n e coeficiente.
- **Pré-condições, ausentes, erros e limites:** Tamanhos diferentes, constante, ausente e número não finito são erros; empates de Spearman seguem StatsBase.
- **Efeitos:** Nenhum.
- **Dependência Julia:** Statistics; StatsBase.jl para Spearman.
- **Exemplo executável:** [`docs/examples/estatistica.abt`](../examples/programs.md#estatistica).
- **Operações relacionadas nesta seção:** `resumo_estatistico`, `intervalo_confianca_media`, `teste_t`, `teste_nao_parametrico`, `teste_normalidade`, `teste_proporcoes`, `probabilidade_distribuicao`, `quantil_distribuicao`, `regressao_linear`, `probabilidade_normal`.

## `teste_t`

`teste_t(xs, ys, metodo, alternativa, diferenca_nula)`

Executa teste t configurado explicitamente.

- **Parâmetros e padrões:** Método `uma_amostra` (`ys=[]`), `pareado`, `welch` ou `student`; alternativa `bilateral`, `menor`, `maior`; diferença nula finita.
- **Retorno:** Registro método, alternativa, tamanhos, hipótese nula, estatística, graus de liberdade e valor-p.
- **Pré-condições, ausentes, erros e limites:** n ≥ 2; pareado usa `xs-ys`; variância zero, ausente, tamanho e inferência não finita são erros. `menor`/`maior` referem-se à diferença A−B.
- **Efeitos:** Nenhum.
- **Dependência Julia:** HypothesisTests.jl sob demanda.
- **Exemplo executável:** [`docs/examples/estatistica.abt`](../examples/programs.md#estatistica).
- **Operações relacionadas nesta seção:** `resumo_estatistico`, `intervalo_confianca_media`, `correlacao`, `teste_nao_parametrico`, `teste_normalidade`, `teste_proporcoes`, `probabilidade_distribuicao`, `quantil_distribuicao`, `regressao_linear`, `probabilidade_normal`.

## `teste_nao_parametrico`

`teste_nao_parametrico(xs, ys, metodo, alternativa)`

Testa amostras sem hipótese paramétrica t.

- **Parâmetros e padrões:** Método `mann_whitney` ou `wilcoxon_pareado`; alternativa bilateral/menor/maior.
- **Retorno:** Registro método, alternativa, tamanhos e valor-p.
- **Pré-condições, ausentes, erros e limites:** n ≥ 2; pares de mesmo tamanho; empates e zeros seguem HypothesisTests; ausentes e método inválido são erros.
- **Efeitos:** Nenhum.
- **Dependência Julia:** HypothesisTests.jl sob demanda.
- **Exemplo executável:** [`docs/examples/estatistica.abt`](../examples/programs.md#estatistica).
- **Operações relacionadas nesta seção:** `resumo_estatistico`, `intervalo_confianca_media`, `correlacao`, `teste_t`, `teste_normalidade`, `teste_proporcoes`, `probabilidade_distribuicao`, `quantil_distribuicao`, `regressao_linear`, `probabilidade_normal`.

## `teste_normalidade`

`teste_normalidade(xs)`

Executa Shapiro–Wilk.

- **Parâmetros e padrões:** Lista numérica com 3 a 5000 valores.
- **Retorno:** Registro estatística e valor-p.
- **Pré-condições, ausentes, erros e limites:** Variância zero, ausente, tamanho ou inferência não finita são erros.
- **Efeitos:** Nenhum.
- **Dependência Julia:** HypothesisTests.jl sob demanda.
- **Exemplo executável:** [`docs/examples/estatistica.abt`](../examples/programs.md#estatistica).
- **Operações relacionadas nesta seção:** `resumo_estatistico`, `intervalo_confianca_media`, `correlacao`, `teste_t`, `teste_nao_parametrico`, `teste_proporcoes`, `probabilidade_distribuicao`, `quantil_distribuicao`, `regressao_linear`, `probabilidade_normal`.

## `teste_proporcoes`

`teste_proporcoes(sa, na, sb, nb, alternativa)`

Compara duas proporções por Fisher exato 2×2.

- **Parâmetros e padrões:** Quatro contagens `Int64`; alternativa bilateral/menor/maior.
- **Retorno:** Registro de contagens, proporções e valor-p.
- **Pré-condições, ausentes, erros e limites:** 0 ≤ sucessos ≤ totais positivos; soma dos totais deve caber em Int64; ausente, overflow ou alternativa inválida são erros.
- **Efeitos:** Nenhum.
- **Dependência Julia:** HypothesisTests.jl sob demanda.
- **Exemplo executável:** [`docs/examples/estatistica.abt`](../examples/programs.md#estatistica).
- **Operações relacionadas nesta seção:** `resumo_estatistico`, `intervalo_confianca_media`, `correlacao`, `teste_t`, `teste_nao_parametrico`, `teste_normalidade`, `probabilidade_distribuicao`, `quantil_distribuicao`, `regressao_linear`, `probabilidade_normal`.

## `probabilidade_distribuicao`

`probabilidade_distribuicao(modelo, parametros, valor)`

Calcula CDF, `P(X ≤ valor)`.

- **Parâmetros e padrões:** Modelo `normal`, `student_t`, `binomial` ou `poisson`; parâmetros explícitos em lista.
- **Retorno:** Registro `modelo`, `parametros`, `entrada` e `resultado` (probabilidade acumulada).
- **Pré-condições, ausentes, erros e limites:** Desvios/graus/taxas/probabilidades têm domínios próprios; modelos discretos exigem contagem inteira; inválidos são erros.
- **Efeitos:** Nenhum.
- **Dependência Julia:** Distributions.jl sob demanda.
- **Exemplo executável:** [`docs/examples/estatistica.abt`](../examples/programs.md#estatistica).
- **Operações relacionadas nesta seção:** `resumo_estatistico`, `intervalo_confianca_media`, `correlacao`, `teste_t`, `teste_nao_parametrico`, `teste_normalidade`, `teste_proporcoes`, `quantil_distribuicao`, `regressao_linear`, `probabilidade_normal`.

## `quantil_distribuicao`

`quantil_distribuicao(modelo, parametros, p)`

Calcula quantil de distribuição.

- **Parâmetros e padrões:** Mesmos modelos/parâmetros da CDF; 0 < p < 1.
- **Retorno:** Registro `modelo`, `parametros`, `entrada` (p) e `resultado` (quantil).
- **Pré-condições, ausentes, erros e limites:** Fronteiras 0/1, ausentes e parâmetros inválidos são erros; quantil discreto segue Distributions.
- **Efeitos:** Nenhum.
- **Dependência Julia:** Distributions.jl sob demanda.
- **Exemplo executável:** [`docs/examples/estatistica.abt`](../examples/programs.md#estatistica).
- **Operações relacionadas nesta seção:** `resumo_estatistico`, `intervalo_confianca_media`, `correlacao`, `teste_t`, `teste_nao_parametrico`, `teste_normalidade`, `teste_proporcoes`, `probabilidade_distribuicao`, `regressao_linear`, `probabilidade_normal`.

## `regressao_linear`

`regressao_linear(tabela, resposta, preditores)`

Ajusta OLS com intercepto.

- **Parâmetros e padrões:** Tabela tipada, resposta textual e lista de preditores numéricos distintos.
- **Retorno:** Registro com n, nomes, coeficientes, erros-padrão, valores-p, IC 95% e R².
- **Pré-condições, ausentes, erros e limites:** n > número de parâmetros, posto completo, resposta variável e sem ausentes; matriz singular ou inferência inválida são erros. Fatores não são codificados implicitamente.
- **Efeitos:** Percorre e materializa colunas necessárias.
- **Dependência Julia:** GLM.jl e LinearAlgebra.
- **Exemplo executável:** [`docs/examples/modelagem.abt`](../examples/programs.md#modelagem).
- **Operações relacionadas nesta seção:** `resumo_estatistico`, `intervalo_confianca_media`, `correlacao`, `teste_t`, `teste_nao_parametrico`, `teste_normalidade`, `teste_proporcoes`, `probabilidade_distribuicao`, `quantil_distribuicao`, `probabilidade_normal`.

## `probabilidade_normal`

`probabilidade_normal(media, desvio, limiar)`

Calcula cauda superior normal.

- **Parâmetros e padrões:** Três números finitos; desvio > 0.
- **Retorno:** Registro com probabilidade acima do limiar.
- **Pré-condições, ausentes, erros e limites:** Ausente, desvio não positivo e número não finito são erros.
- **Efeitos:** Nenhum.
- **Dependência Julia:** Distributions.jl sob demanda.
- **Exemplo executável:** [`docs/examples/estatistica.abt`](../examples/programs.md#estatistica).
- **Operações relacionadas nesta seção:** `resumo_estatistico`, `intervalo_confianca_media`, `correlacao`, `teste_t`, `teste_nao_parametrico`, `teste_normalidade`, `teste_proporcoes`, `probabilidade_distribuicao`, `quantil_distribuicao`, `regressao_linear`.
