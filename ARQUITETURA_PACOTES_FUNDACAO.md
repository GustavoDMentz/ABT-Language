# ABT — fundação de pacotes e limites da evolução

## Estado real antes da mudança

O código identificado como ABT 0.11.8 concentra lexer, expansão de pipelines, parser, AST, IR, validação, otimização conservadora, interpretador, geração Julia e CLI em `pseudo.jl`. `bridge_runtime.jl` contém os acessos externos compartilhados. `PythonCall` é carregado apenas ao executar `usar Python...`; Julia é o runtime principal. Os imports Julia antes desta fatia eram `Base`, `Statistics` e `LinearAlgebra`, com funções e aridades enumeradas em `JULIA_BRIDGE`. Identificadores de usuário recebem nomes Julia codificados em hexadecimal no gerador; funções ABT possuem escopo local. O IR público é validado antes de executar ou gerar. Pipelines são expandidos para as operações existentes antes do parser.

Baseline local antes da mudança: 36 testes PASS, 2 sondas PROBE, 0 PARTIAL, 0 FAIL e 0 TIMEOUT (`foundation_baseline.log`). Julia 1.13.3; ambiente Julia com PythonCall 0.9.37. Python: NumPy 2.5.1 e pandas 3.0.3 instalados; Biopython, Streamlit e PyTorch ausentes. No ambiente Julia usado, `Pkg.status()` listou PythonCall; DataFrames.jl, CSV.jl, DataFramesMeta.jl, QuadGK.jl e Symbolics.jl não estavam instalados. `Dates`, `Statistics` e `LinearAlgebra` são bibliotecas padrão Julia disponíveis.

## Fatia vertical implementada — Fase A

`ABT.packages.toml` declara um módulo Julia pelo nome exato, UUID, versão exata e mapa de funções para aridades. O manifesto não instala nada; Julia `Project.toml`/`Manifest.toml` e Pkg continuam responsáveis por dependências. O ABT lê o manifesto ao carregar `Pseudo`; editar o arquivo exige reiniciar o processo. Os pacotes declarados só são carregados quando a instrução `usar Julia.Nome` é alcançada. Imports ausentes, funções não declaradas e aridade incorreta são erros. Não há busca por nomes semelhantes, conversão automática nem import implícito.

Gramática acrescentada: **nenhum token novo**. A instrução já existente `usar Julia.Identificador` aceita agora nomes declarados no manifesto. A chamada já existente `Julia.Identificador.função(argumentos)` exige que a função e a aridade constem no manifesto. A versão de exemplo declara `Dates.Date/1` e `Dates.year/1`. A chamada recebe e retorna valores Julia originais; a impressão usa o contrato de `mostrar` já existente. Não há serialização especial de objetos estrangeiros.

Formato exato:

```toml
[julia.Dates]
uuid = "ade2ca70-3891-5945-98fb-dc099432e06a"
version = "1.11.0"
functions = { Date = 1, year = 1 }
```

Somente a tabela `julia` é aceita. Cada módulo deve declarar `uuid`, `version` e `functions`; aridades inteiras de 0 a 32. Nomes devem ser representáveis pela gramática ABT. Módulos embutidos não podem ser redefinidos. Versão é comparada exatamente com `Base.pkgversion` após `Base.require`; portanto a inicialização Julia do pacote pode ocorrer antes de detectar incompatibilidade. Para evitar esse efeito, o ambiente deve ser resolvido previamente com o `Manifest.toml` do Julia. O ABT não é sandbox.

O contrato de equivalência foi verificado com `Dates`: interpretador, Julia gerado sem otimização e com otimização exibiram os mesmos resultados. O pacote e sua versão são incorporados ao Julia gerado, de modo que esse código não precisa ler o manifesto original. A importação é mantida na ordem do programa; chamadas externas opacas não são reordenadas.

## Matriz de compatibilidade e riscos

| Área | Estado | Risco ou decisão |
|---|---|---|
| ABT 0.11.8 legado | Suítes históricas preservadas | Regressão será verificada na execução final. |
| Julia `Base`, `Statistics`, `LinearAlgebra` | Contratos existentes preservados | Lista antiga de funções permanece explícita. |
| Pacotes Julia opcionais | Manifesto fino com UUID, versão e aridade | A versão só é conferida após `Base.require`; pacotes têm efeitos de inicialização próprios. |
| PythonCall | Opcional, carregamento tardio existente | Objetos Python mantêm identidade/proxy; código externo tem efeitos próprios. |
| DataFrames/CSV | Não implementados nesta fatia | Missing, cópias, tipos, ordenação e agregação ainda exigem contrato formal. |
| Blocos Python nativos | Não implementados | Sintaxe candidata exige gramática de indentação e escopos separados; parser ABT não deve analisar Python. |
| Unicode matemático | Identificadores Unicode simples existentes | Normalização Unicode, sobrescritos e multiplicação implícita não foram especificados. |
| Biopython/Streamlit | Não implementados | Dependências ausentes; contratos de alfabeto biológico e estado reativo não estão definidos. |
| Auditoria obrigatória | Não implementada | Não existe ainda formato/retensão/privacidade e equivalência observacional entre backends; não se anuncia rastreio inexistente. |

## Próximas fases e critério de avanço

Fase B precisa de contrato para colunas, `missing`, materialização, ordem, agrupamento e cópias antes da sintaxe tabular. Fase C precisa de contrato de entradas/saídas para um bloco Python e de uma decisão sobre traceback e mutabilidade. Fase D precisa escolher semânticas matemáticas e biológicas sem inferência. Fase E precisa modelar chaves, reruns e estado do Streamlit. Nenhuma dessas construções candidatas foi implementada ou aceita pelo compilador nesta entrega.

O registro mínimo obrigatório da Fase de auditoria requer desenho específico para fonte, sequência observada, limites de retenção e privacidade. Um log somente no interpretador seria semanticamente enganoso, pois o código Julia gerado não produziria os mesmos eventos. Por isso não foi adicionado um log parcial que aparentasse cumprir a exigência.

## Reprodução da fatia

No Ubuntu com Julia 1.13.3, usando o projeto extraído:

```bash
export JULIA_DEPOT_PATH=/caminho/para/depot-julia
julia --startup-file=no test_packages_foundation.jl
julia --startup-file=no pseudo.jl examples/pacote_dates.abt
ABT_REQUIRE_PYTHON=1 python3 run_all_tests.py --julia julia --timeout 180
```

O teste `test_packages_foundation.jl` também compara os dois modos de geração com o interpretador, verifica imports repetidos, ausência de import, função ausente, aridade, versão incompatível, pacote ausente e manifesto malformado. As suítes de Python exigem PythonCall e NumPy; sem elas, executar sem `ABT_REQUIRE_PYTHON=1` e registrar eventuais skips separadamente.
