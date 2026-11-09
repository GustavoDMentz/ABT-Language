# ABT 0.11.8 — arquivos e tabelas tipadas

## Decisão arquitetural

A gramática não mudou. Todas as operações são funções ABT comuns e usam o mesmo IR, validador, interpretador e gerador Julia. `registro` e `descrever` permanecem disponíveis. `CSV.jl` 1.3 e `Tables.jl` 1.14 são dependências do projeto Julia; `DataFrames.jl` não é necessária. CSV.jl analisa aspas, delimitadores e registros com quebras de linha. ABT não implementa um parser CSV. A biblioteca é carregada somente quando `ler_csv` é chamada. PythonCall continua opcional e não é usado pelas novas aplicações de CSV e DNA.

## Contratos

| Função | Entrada explícita | Resultado / erro |
|:---|:---|:---|
| `ambiente(nome, padrao)` | Dois textos | Valor da variável de ambiente ou texto padrão. |
| `ler_texto(caminho)` | Caminho textual não vazio | Conteúdo UTF-8; erro ABT com arquivo e causa de E/S. |
| `esquema(nome, tipo, ...)` | Pares; tipos `texto`, `inteiro`, `real`, `booleano` | Registro ordenado e validado; nomes duplicados ou inválidos são erro. |
| `ler_csv(caminho, esquema, politica[, delimitador])` | Caminho, esquema explícito, `erro` ou `permitir`; delimitador de um caractere, padrão `,` | Tabela re-iterável; valida cabeçalho exato e duplicações antes de retornar. Valores são convertidos ao iterar. O delimitador é explícito, sem autodetecção. |
| `linhas_tabela(tabela)` | Tabela | Vetor materializado de registros com campos do esquema. |
| `coluna(tabela, nome)` | Tabela e coluna existente | Vetor materializado dos valores da coluna. |
| `filtrar_tabela(tabela, coluna, operador, valor)` | Operador `==`, `!=`, `>`, `>=`, `<`, `<=`; valor do tipo declarado | Nova tabela lazy; ordem das linhas preservada. Ausente na coluna filtrada é erro. |
| `transformar_tabela(tabela, origem, destino, operador, operando, tipo)` | Origem numérica, destino novo, `+`, `-`, `*` ou `/`, operando do tipo de origem, tipo de destino `inteiro` ou `real` | Nova tabela lazy com coluna calculada; resultado fora do tipo declarado ou não finito é erro. Inteiros usam operações verificadas contra overflow. |
| `resumir_coluna(tabela, nome)` | Coluna numérica sem ausentes | Registro `quantidade`, `soma`, `media`, `minimo`, `maximo`; tabela vazia, ausente, overflow ou soma não finita é erro. |
| `falhar(mensagem)` | Texto | Interrompe explicitamente com diagnóstico ABT. |

`inteiro` significa `Int64`; `real`, `Float64`; `booleano` aceita apenas `true` ou `false`. Não há inferência de tipos nem conversão silenciosa. Campo CSV sem conteúdo e sem aspas vira `missing`; `""` vira texto vazio. `politica="erro"` rejeita ausentes no acesso à linha; `"permitir"` conserva o valor ausente, que é exibido como `ausente`. Campos textuais vazios são válidos; campos numéricos vazios entre aspas são inválidos. Linhas com mais ou menos campos são erros do CSV.jl em modo estrito. A posição de `ABT CSV: row N` é o número lógico do registro CSV, incluindo o cabeçalho; para registros com quebra de linha entre aspas, não é a linha física. O erro de parse do CSV.jl mantém sua posição própria e a causa original.

Filtros booleanos aceitam apenas `==` e `!=`; comparações de ordem em texto seguem a ordem lexical Julia, e em números seguem a ordem do tipo declarado.

A tabela retém um iterador CSV re-iterável. `ler_csv`, `filtrar_tabela` e `transformar_tabela` não carregam todas as linhas convertidas em um vetor. `coluna`, `linhas_tabela` e `mostrar tabela` materializam a saída solicitada; resumos percorrem a tabela sem materializar colunas. Reiterar pode reler e recalcular, portanto arquivos modificados entre iterações não têm semântica de snapshot. Use arquivos estáveis durante o programa.

`mostrar` usa um formatador ABT recursivo e determinístico para registros, listas e tabelas; não depende de `string(NamedTuple)`. Uma chamada apresenta a estrutura completa. Texto isolado mantém a apresentação anterior sem aspas; texto dentro de uma estrutura é citado. Isso é apresentação, não formato de exportação versionado.

## Aplicações e redução de código

| Aplicação | Antes | Agora | Observação |
|:---|---:|---:|:---|
| Estatística | 7 | 7 | Já usava `descrever`. |
| CSV | 54 | 12 | Sem PythonCall; esquema, filtro e resumo declarados. |
| DNA | 60 | 51 | Sem PythonCall; usa leitura e operações gerais de texto, mas ainda valida FASTA no programa. |
| Vendas | nova | 9 | Esquema tipado, filtro, transformação, agregação e relatório. |

A maior redução é no CSV. O DNA ainda tem laços e validações explícitos porque não foi introduzido um parser FASTA específico ou uma dependência biológica nesta etapa.

## Reprodução no Ubuntu

```sh
cd /caminho/abt_perf_0118
export ABT_JULIA=/caminho/julia-1.13.3/bin/julia
"$ABT_JULIA" --project=. -e 'import Pkg; Pkg.instantiate()'
bin/abt run applications/data/resumo_csv.abt
bin/abt run applications/bio/conteudo_gc.abt
bin/abt run applications/data/vendas.abt
python3 test_applications.py --julia "$ABT_JULIA"
python3 run_all_tests.py --julia "$ABT_JULIA" --timeout 120
/usr/bin/time -v "$ABT_JULIA" --project=. test_tables_large.jl
```

Os testes de interoperabilidade históricos ainda exigem PythonCall no depot Julia. Os testes de CSV e DNA novos não exigem PythonCall.

A sonda `test_tables_large.jl` gerou **100.000 registros**, verificou `quantidade=100000` e `soma=5000050000`, e registrou `table_bytes=3366808` por `Base.summarysize` e pico de **368420 KiB RSS** em `/usr/bin/time -v` (`applications/test_tables_large.log`). `summarysize` mede a estrutura Julia alcançável pela tabela, inclusive buffers do CSV.jl; RSS mede o processo Julia inteiro, com compilador e pacotes. Esses números não são intercambiáveis nem demonstram memória constante. O teste confirma que o resumo percorre o iterador sem criar um vetor de linhas convertidas.

A bateria `test_applications.py` terminou com **109 PASS, 0 FAIL, 0 TIMEOUT**: 51 execuções no interpretador, 29 na Julia gerada sem otimização e 29 na Julia gerada com otimização. Os casos incluem aplicações completas, acesso a registros, CSV malformado, Unicode, delimitador explícito, ausentes, rejeição de ordem booleana e comparação entre backends. Evidência: `applications/test_results.json` e `applications/test_run_0118_tables_final.log`.

A regressão histórica completa terminou com **39 PASS, 2 PROBE, 0 PARTIAL, 0 FAIL, 0 TIMEOUT** (`test_logs/summary.json`, `test_logs/tables_regression_final.log`). `PROBE` designa sondas exploratórias, sem aprovação formal de suas hipóteses. O executor ativa `--project` para carregar CSV.jl/Tables.jl do manifesto. O teste diferencial de 1.000 casos e os arquivos `test_static_*.jl` fazem parte dessa rodada.

Durante a auditoria, a apresentação nova revelou uma regressão real com objetos Python carregados tardiamente: `string` era chamada em um mundo Julia anterior ao método de PythonCall e mostrava um ponteiro. O formatador agora usa `Base.invokelatest(string, valor)` no ramo genérico. O teste diferencial da ponte Python passou após a correção. Três testes estáticos e duas asserções legadas procuravam a grafia antiga de `mostrar` no Julia gerado; foram atualizados para verificar o valor apresentado e a ordem relativa aos imports, sem remover suas verificações. A sonda de tabela grande passou a rodar com o projeto Julia ativo no executor histórico.

## Limites e prioridades

- A validação de linhas é lazy: um arquivo pode ser aceito no cabeçalho e falhar quando uma operação percorrer a linha inválida. Essa falha não é ignorada.
- `mostrar tabela` imprime todas as linhas; para arquivos grandes, apresente um resumo. Não há paginação ou exportação tabular nesta camada.
- A tabela usa a representação interna de um registro com iterador. O contrato público são as funções acima; seu formato interno não é API.
- Não há política de ignorar valores ausentes em agregações. O programa deve decidir como tratá-los antes de resumir.
- Filtros tabulares cobrem comparação de uma coluna com valor. Expressões compostas ainda exigem composição sequencial; predicados arbitrários podem ser propostos após revisar equivalência de chamadas ABT nos backends.
- A leitura de texto inteiro é adequada ao aplicativo DNA atual, mas não a FASTA gigantes. Próxima prioridade: iterador de linhas de arquivo e, se necessário, adaptador FASTX.jl opcional, com contrato próprio para bases ambíguas.
