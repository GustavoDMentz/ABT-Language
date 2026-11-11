# Auditoria final independente — ABT 0.12.0

Data: 11/11/2026. Base remota `main`: `edf76af28d08d36be46b3c684fd54efb165f4fb4`; branch examinada: `feat/abt-biostatistics-0120`, PR #1. Ambiente: Linux x86_64, Julia 1.13.3, Python 3.12.3. As verificações abaixo foram executadas nesta auditoria; os logs ficam em `logs/audit_0120/`.

## Revisão técnica e estatística

O diff registra as operações em `src/ExtensionRegistry.jl` e compartilha a implementação `src/StdlibBiostatistics.jl` entre interpretador e Julia gerada. `Project.toml` declara diretamente GLM, HypothesisTests, Distributions e StatsBase; `Manifest.toml` fixa as versões. O instalador copia o novo módulo. O carregamento das bibliotecas é tardio. As três aplicações usam dados sintéticos e retornam registros estruturados.

Comparei independentemente intervalos t com o quantil da distribuição Student, Spearman com postos médios explícitos para empates, caudas de Welch com CDF/CCDF, teste pareado com `OneSampleTTest`, Mann–Whitney com `HypothesisTests`, e a cauda superior de Fisher com soma hipergeométrica em `BigInt`. Também confrontei coeficientes, erros-padrão, intervalos e R² da regressão com GLM na suíte direta. Esses casos e as verificações de entradas inválidas estão em `tests/test_biostatistics_adversarial_0120.jl` e `tests/test_biostatistics_0120.jl`.

**Defeito encontrado:** `teste_proporcoes(1, typemax(Int64), 1, 1, "bilateral")` passava pela validação das contagens, mas a soma dos totais excedia `Int64` dentro da biblioteca e produzia um `DomainError` técnico. A correção mínima rejeita explicitamente `total_a > typemax(Int64) - total_b` antes da chamada externa, com diagnóstico `ABT teste_proporcoes: total combinado excede Int64`. Um caso adversarial direto e um caso nos três backends reproduzem a regressão.

O teste de Wilcoxon com todos os pares iguais retorna valor-p 1 conforme `HypothesisTests`; a suíte fixa esse comportamento sem atribuir evidência científica a uma amostra degenerada. OLS com ajuste numericamente perfeito pode manter resíduo de arredondamento, e sua inferência segue as convenções de GLM. Não introduzi limiar arbitrário para redefinir ajuste perfeito.

## Execuções desta auditoria

Os comandos abaixo usam `JULIA` como caminho absoluto para Julia 1.13.3. Nesta máquina, o depot utilizado foi `/tmp/abt-tabular-depot:/home/gumentz/.codex/.chatgpt-projects/g-p-6aed28c64c608191837b0b5384a649bb/abt_v116/.julia_depot`; em outra instalação, o depot padrão da Julia é suficiente após `Pkg.instantiate()`. A opção de PythonCall é usada apenas para os testes legados de interoperabilidade.

```bash
cd /caminho/para/ABT-Language
export JULIA=/caminho/para/julia-1.13.3/bin/julia
export ABT_JULIA="$JULIA" ABT_TEST_JULIA="$JULIA"
export JULIA_CONDAPKG_BACKEND=Null JULIA_PYTHONCALL_EXE=/usr/bin/python3
"$JULIA" --project=. -e 'import Pkg; Pkg.instantiate()'
"$JULIA" --project=. --startup-file=no tests/test_biostatistics_0120.jl
"$JULIA" --project=. --startup-file=no tests/test_biostatistics_adversarial_0120.jl
python3 tests/test_biostatistics_backends.py
python3 tests/run_all_tests.py --julia "$JULIA" --timeout 180
python3 tests/test_extensions.py --julia "$JULIA"
python3 tests/test_modular_extensions.py --julia "$JULIA"
python3 tests/test_batch_118.py
python3 tests/test_install_cli.py
python3 tests/test_applications.py --julia "$JULIA"
```

| Verificação | Resultado observado |
|---|---:|
| Comparação direta com bibliotecas Julia | 33 PASS, 0 FAIL |
| Adversariais adicionais | 30 PASS, 0 FAIL |
| Diferencial interpretador / gerado sem otimização / gerado otimizado | 19 casos × 3 modos, 0 divergências |
| Histórico completo | 43 PASS, 2 PROBE, 0 PARTIAL, 0 FAIL, 0 TIMEOUT |
| Extensões anteriores | 45 PASS, 0 FAIL |
| Extensões modulares | 51 PASS, 0 FAIL |
| Lote científico anterior | 33 PASS, 0 FAIL |
| Instalação e CLI | 10 PASS, 0 FAIL |
| Aplicações anteriores, incluindo CSV, DNA e casos inválidos | 112 PASS, 0 FAIL, 0 TIMEOUT |

O comparador diferencial verifica estrutura JSON, tipos, campos, ordem das listas e valores. Somente pontos flutuantes recebem tolerância relativa/absoluta de `1e-12`; erros são comparados pelo diagnóstico ABT, pois os wrappers do interpretador e do Julia gerado formatam as pilhas de forma distinta. As três aplicações novas constam entre os 19 casos diferenciais. `break_abt.jl` e `audit_adversarial.jl` permanecem sondas exploratórias e não são contabilizados como aprovação funcional.

## Limites

Os testes não provam correção para toda entrada. Operações estatísticas preservam as premissas científicas e as limitações de precisão documentadas em `docs/BIOESTATISTICA_0120.md`. A regressão materializa as colunas necessárias e exige preditores numéricos com posto completo. O acesso a bibliotecas Julia/Python pressupõe código confiável e não é sandbox. O repositório não configura checks obrigatórios nem regras de branch no GitHub; portanto a aprovação desta auditoria dependeu das execuções locais registradas, não de CI remoto.
