# ABT 0.11.8 — primeira camada de abstração

## Auditoria das três aplicações

O núcleo já fornece listas, funções, filtros, transformações, agregações e import explícito. As aplicações mostram que isso ainda deixa trabalho repetitivo ao programador.

| Impacto | Limitação observada | Evidência nas aplicações |
|:---|:---|:---|
| Alto | Falta um valor estruturado simples para agrupar resultados. | Estatística, CSV e DNA imprimiam cada métrica separadamente. |
| Alto | Não há operação analítica composta. | Estatística precisava chamar média, mediana, desvio padrão, mínimo e máximo individualmente. |
| Alto | Arquivos e registros externos exigem interop verbosa. | CSV e DNA ainda expõem chamadas PythonCall/Python e conversões explícitas. |
| Médio | `mostrar` aceita valores, mas não define apresentação estável de relatórios. | Um registro agora aparece inteiro, porém usa a representação Julia de `NamedTuple`. |
| Médio | Dados ausentes, esquema tabular e colunas tipadas não são conceitos ABT. | O CSV precisa validar cabeçalho/campos manualmente; número inválido produz `PyException` pouco clara. |
| Médio | `filtrar`/`transformar` exigem `Vector`; iteradores externos precisam ser materializados. | O CSV inteiro é carregado antes da filtragem. |

Os comandos de import e os contratos do parser permanecem os descritos em [ECOSSISTEMA_APLICACOES_0118.md](ECOSSISTEMA_APLICACOES_0118.md). A diretriz desta evolução é acrescentar operações de biblioteca como funções ABT comuns, sem criar uma palavra reservada para cada domínio.

## Implementado nesta etapa

**Sintaxe existente usada:** chamadas `nome(argumentos)`, atribuição, acesso `valor.campo` e `mostrar valor`. Não foi introduzido token ou regra gramatical. `descrever` e `registro` são funções da pequena biblioteca padrão ABT, com implementações compartilhadas entre interpretador e Julia gerada em `src/Stdlib.jl`. A Julia gerada incorpora somente as funções usadas pelo programa; continua executável sem carregar o módulo ABT.

### `registro(nome, valor, ...)`

- Entrada: um ou mais pares alternados. Cada nome deve ser texto não vazio, um identificador válido e não privado; nomes repetidos são erro.
- Saída: registro Julia `NamedTuple` imutável, com ordem de campos preservada. Valores não são convertidos nem copiados.
- Uso: guardar, acessar `r.campo`, aninhar em outro registro, passar a funções e apresentar com um único `mostrar r`.
- Erros: aridade ímpar/zero, nome não textual, inválido ou duplicado. Um campo inexistente produz erro de propriedade Julia, sem criação implícita.

### `descrever(dados)`

- Entrada: `Vector` com pelo menos dois valores, cada um exatamente `Int64` ou `Float64` finito. `Bool`, texto, `nothing`, valores ausentes externos, `NaN` e infinitos são rejeitados sem coerção.
- Saída: registro com `quantidade`, `soma`, `media`, `mediana`, `desvio_padrao`, `minimo`, `maximo`, nessa ordem. O desvio padrão é **amostral** (`Statistics.std`, divisor `n-1`). Cálculo não imprime nada.
- Erros: tipo incompatível, menos de dois elementos, soma inteira com overflow, soma ou resultado estatístico não finito. A validação do ABT checa a aridade e rejeita entrada escalar quando pode prová-la; valores dinâmicos são checados em tempo de execução.
- Implementação: cálculo é feito pelas funções Julia `Statistics` e `Base`. O laço adicional verifica overflow inteiro e não finitude; não substitui os algoritmos estatísticos de Julia.

`mostrar` continua sendo exclusivamente apresentação. Ele recebe o registro já calculado e o imprime em uma chamada. A representação textual de `NamedTuple` é observável nos testes atuais, mas ainda não é um formato de exportação versionado; não a use como protocolo de dados.

## Composição e compatibilidade

Exemplo executado:

```abt
dados = [1, 2, 3]
resumo = descrever(dados)
resultado = registro("nome", "amostra", "estatisticas", resumo)
mostrar resultado.estatisticas.media
mostrar resultado
```

Funções ABT declaradas pelo usuário com o nome `descrever` continuam possíveis e prevalecem sobre o nome da biblioteca; o caso foi testado nos dois backends. A biblioteca é adicionada como valor inicial apenas quando o nome não foi declarado como função pelo programa. Atribuições locais ainda podem sombreá-la. Não houve mudança na semântica de listas, escopos, imports, avaliação de argumentos ou apresentação de valores antigos.

As três aplicações usam agora `registro` para compor saídas completas; a estatística também usa `descrever`. O código estatístico caiu de 24 para 7 linhas sem perder métricas. CSV e DNA reduziram comandos de apresentação, mas ainda têm respectivamente 54 e 60 linhas e muitas chamadas de interop. O ganho de abstração nesses dois casos é **parcial**, demonstrando que uma biblioteca de arquivos/dados é a próxima prioridade. Isso não é apresentado como conclusão de toda a missão arquitetural.

## Validação

`tests/test_applications.py` verificou **58 PASS, 0 FAIL, 0 TIMEOUT**: as três aplicações no interpretador e na Julia gerada com/sem otimização, acesso a campos, aninhamento de registros, uso da biblioteca em função, sombreamento por função do usuário, preservação da regra de não captura e rejeição de aridades, nomes, tipos, coleção pequena, valor ausente, NaN, infinito e overflow. Os casos de CSV e DNA continuam cobrindo entradas válidas, inválidas e extremas. Resultados estruturados: `applications/test_results.json`. A regressão histórica e diferencial registrou **38 PASS, 2 PROBE, 0 PARTIAL, 0 FAIL, 0 TIMEOUT** em `logs/test_logs/summary.json`; os três testes históricos iniciados antes do último ajuste foram repetidos e passaram, com resultados em `applications/final_scope_reruns.json`. `PROBE` identifica sondas exploratórias, não suítes aprovadas.

Reprodução no diretório do projeto, com Julia 1.13.3 e as dependências opcionais de interoperabilidade já instaladas:

```sh
export ABT_JULIA=/caminho/para/julia-1.13.3/bin/julia
python3 tests/test_applications.py
python3 tests/run_all_tests.py --julia "$ABT_JULIA" --timeout 120
```

## Próximas camadas propostas — não implementadas

1. **Arquivos e dados tabulares:** leitor explícito que retorna registros de texto com esquema declarado, distingue campo vazio de valor ausente e não infere tipos sem autorização. Usar CSV.jl quando disponível ou um adaptador opcional com contrato equivalente. Definir iteração sem exigir materialização de todo arquivo.
2. **Conversão tipada e diagnóstico externo:** operações explícitas para converter texto em número/data, com erro ABT que preserva a causa da biblioteca; nenhum parse silencioso de colunas.
3. **Texto e bioinformática:** operações de texto reutilizáveis, depois FASTX.jl/BioSequences.jl opcionais para leitura e validação de FASTA; não promover o parser restrito da aplicação a implementação geral do formato.
4. **Apresentação/exportação:** renderização determinística de registros/listas/tabelas, separada de cálculo, e exportação em formato definido (por exemplo JSON3.jl opcional) sem depender de `string(NamedTuple)` como protocolo.
5. **Pacotes Julia:** enriquecer o manifesto atual com contratos de tipo/retorno e tratamento de erros testados antes de expor tabelas, sequências e outros objetos externos como valores ABT comuns.

Cada etapa exige teste diferencial, casos inválidos e um programa real. Não há nova sintaxe proposta nesta primeira implementação; caso uma futura gramática seja necessária, deverá vir acompanhada de análise de conflitos com funções, campos e pipelines.
