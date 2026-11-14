# Auditoria de abstração da ABT 0.13.0

## Escopo e método

Revisão do lexer, parser, AST/IR, validação, interpretador, geração Julia, biblioteca padrão, registro de extensões, pontes Julia/Python, operações científicas, 36 programas `.abt` em `applications/`, `examples/` e `docs/examples/`, testes e documentação oficial. O nível abaixo classifica **cada programa pelo problema mais alto encontrado**, não cada linha. Chamadas de interoperabilidade em fixtures de testes são examinadas separadamente, pois testam deliberadamente a ponte.

| Nível | Programas | Interpretação |
| --- | ---: | --- |
| 0 — Nativo | 30 | Usam sintaxe e operações ABT apropriadas. |
| 1 — Verbosidade | 4 | API ABT existe, mas parâmetros posicionais dificultam a leitura. |
| 2 — Lacuna | 1 | Operação fundamental de contagem exigia Julia. |
| 3 — Acoplamento | 0 | Nenhum programa depende de tipo Julia para usar uma operação ABT. |
| 4 — Interoperabilidade intencional | 1 | Demonstra pacote externo como recurso avançado. |

### Matriz auditável de ocorrências

| Nível / prioridade | Arquivo e linha original | Código auditado | Impacto e proposta | Compatibilidade |
| --- | --- | --- | --- | --- |
| 2 / alta — corrigido | `applications/statistics/descritiva.abt:2,6` | `usar Julia.Base`; `Julia.Base.length(altos)` | Contar uma lista filtrada exigia conhecer `Base.length`. `contar(lista)` substitui essa chamada no programa e no tutorial. | Aditivo; `Julia.Base.length` continua disponível. |
| 1 / média | `applications/data/vendas.abt:6` | `transformar_tabela(sul, "unidades", "unidades_dobradas", "*", 2, "inteiro")` | Seis posições misturam intenção, operador e tipo. Estudar opções nomeadas, preservando tipo de destino explícito. | Manter assinatura atual; proposta, não alteração nesta auditoria. |
| 1 / média | `docs/examples/tabelas.abt:8` | `transformar_tabela(dados, "valor", "dobro", "*", 2.0, "real")` | Mesmo contrato posicional do caso anterior. | Mesma exigência de compatibilidade. |
| 1 / média | `applications/science/alinhamento.abt:3` | `alinhar_sequencias(..., "global", 2, -1, -3, -1)` | Pontuações posicionais são difíceis de reconhecer. Propor um registro de opções nomeadas; não ocultar método ou escores. | Preservar os oito argumentos atuais. |
| 1 / média | `docs/examples/bioinformatica.abt:4` | `alinhar_sequencias(..., "global", 2, -1, -3, -1)` | Mesmo caso de alinhamento. | Preservar exemplo até haver nova API testada. |
| 4 / deliberado | `examples/pacote_dates.abt:1–4` | `usar Julia.Dates`; `Julia.Dates.Date(...)`; `Julia.Dates.year(...)` | Exemplo explicitamente dedicado à ponte para pacotes Julia. Manter na seção avançada. | Não remover nem converter em operação ABT artificial. |

Fora dos 36 programas, `docs/src/manual/syntax.md:25` ensina conversão explícita por `Julia.Base.Float64` após import. Essa é uma lacuna conceitual de nível 2 na documentação do uso comum, mas **não** justifica criar conversões sem definir tratamento de texto inválido, overflow, frações e arredondamento. Permanece na categoria B. `docs/src/manual/interop.md` e `docs/src/tutorials/julia.md` são seções avançadas deliberadas (nível 4).

Os outros 30 arquivos `.abt` são nativos: `applications/bio/` (2), `applications/biostatistics/` (3), `applications/data/` exceto `vendas.abt` (5), `applications/engineering/` (1), `applications/science/` exceto `alinhamento.abt` (2), `applications/scientific_0130/` (4), `docs/examples/` exceto `tabelas.abt` e `bioinformatica.abt` (8), e `examples/` exceto `pacote_dates.abt` (5). As fixtures `tests/test_interop*.jl`, `tests/test_python_bridge.jl`, `tests/test_packages_foundation.jl` e os exemplos `.pseudo` de Julia/Python exercitam interoperabilidade intencional; não contam como vazamento dos programas idiomáticos.

## Núcleo e operações existentes

- Listas já oferecem `filtrar`, `transformar`, `limitar` e agregações contextuais `soma de` e `media de`; pipelines preservam a mesma ordem e semântica. `descrever` retorna quantidade, soma, média, mediana, desvio e extremos para vetor numérico válido.
- Texto oferece `linhas_texto`, `aparar`, `maiusculas`, `inicia_com`, `comprimento_texto` e `contar_caractere`. `contar_caractere` conta um caractere em texto; não substitui contagem de elementos de lista.
- Tabelas têm esquema e política de ausentes explícitos, acesso a colunas/linhas, filtro, transformação, resumo, ordenação e deduplicação por operações especializadas. Materializar ou percorrer uma tabela lazy só para obter número de linhas teria custo e efeitos próprios; `contar(lista)` não deve aceitar tabelas implicitamente.
- A ponte `usar Julia.Módulo` é explícita; PythonCall carrega apenas quando solicitado. O uso de `Base.length` **dentro** da implementação ABT não contamina a API pública.
- As assinaturas científicas longas, como `alinhar_sequencias` (oito argumentos), carregam escolhas metodológicas reais. Encurtá-las com padrões implícitos seria uma perda de rigor.

| Capacidade fundamental | Estado observado | Decisão |
| --- | --- | --- |
| Contagem | `descrever` e resumos tabulares incluem contagens; faltava contar uma lista arbitrária. | Categoria A: `contar(lista)` estrito. |
| Soma e agregações | `soma de` e resumos existentes. | Reutilizar. |
| Mínimo e máximo | `descrever` e `resumir_coluna` cobriam amostras/tabelas; faltava extremo genérico de lista. | **Implementado (segunda etapa):** `minimo(lista)` e `maximo(lista)`. Lista numérica finita não vazia; vazio, texto, ausente e não finito são erros; o resultado é o próprio elemento (tipo preservado, empate → primeira ocorrência). |
| Ordenação e duplicatas | `ordenar_tabela` e `remover_duplicatas` cobrem tabelas; listas só tinham `Julia.Base.sort`/`unique`. | **Implementado:** `ordenar(lista[, direcao])` (números ou textos, nunca misturados; estável; `crescente`/`decrescente` como em `ordenar_tabela`) e `sem_duplicatas(lista)` (primeira ocorrência; igualdade `isequal`). Tabelas continuam com as operações próprias. |
| Conversões | Só pela ponte Julia. | **Implementado:** `para_inteiro`, `para_real`, `para_texto`. Sem arredondamento (real com fração é erro), sem perda de precisão (inteiro inexato em `Float64` é erro), texto estrito (sem espaços, sem separadores), sem coerção de booleano. Arredondar continua sem operação; ver B abaixo. |
| Listas e registros | Filtro, transformação, limite, criação de registro e acesso a campos. | Reutilizar; não criar mutação implícita. |
| Ausentes | CSV/tabelas exigem política explícita. | Preservar; não inferir política em operações novas. |
| Texto | Leitura, linhas, aparar, maiúsculas, prefixo e contagem de caracteres. | Reutilizar. |

## Defeitos e limites do núcleo

O lexer reconhece palavras-chave com `lowercase(lexeme)`, mas alguns ramos posteriores interpretam o lexeme original. Assim, caixa alta pode mudar o significado de `AVERAGE` ou falhar em `IS`, `AND` e `OR`, apesar de o token ser reconhecido. A correção deve conservar o lexeme original para diagnóstico e usar a forma canônica para semântica. É um defeito de consistência, não uma nova sintaxe.

Reprodução antes da correção: `mostrar AVERAGE OF [2, 4]` devolvia `6` (soma); `mostrar 2 IS 2` e `mostrar true AND false` falhavam com operador desconhecido. Depois da normalização no parser, retornam `3.0`, `true` e `false`, respectivamente. `tests/test_abstraction_keywords.jl` verifica a mesma sequência no interpretador e em Julia gerada com e sem otimização.

`Token` guarda linha e coluna, enquanto `Node` e IR não preservam essa origem. Melhorar a localização de erros semânticos exigiria mudança coordenada nas estruturas e consumidores; fica como proposta arquitetural. O gerador embute parte da ponte Python em fonte próprio, enquanto o interpretador usa `Runtime/Bridge.jl`; a paridade precisa continuar coberta por testes, mas a duplicação não é vazamento confirmado para o usuário.

Mensagens de erro ainda combinam textos portugueses da CLI com causas técnicas em inglês emitidas por algumas operações da biblioteca. A revisão global de diagnósticos pertence à categoria B: exige preservar categorias, informação causal e testes existentes, sem trocar mensagens isoladamente para obter uniformidade superficial. A nova operação `contar` identifica o valor inválido como **lista**, sem exigir que o usuário conheça o tipo Julia usado internamente.

## Segunda etapa: operações fundamentais de lista e conversões

Implementadas na categoria B depois que o contrato de cada caso-limite foi decidido. Todas seguem o padrão de `contar`: erro de tipo identifica a operação pública e pede "uma lista"; a validação estática rejeita aridade errada e tipos conhecidos incorretos; o interpretador e a Julia gerada (com e sem otimização) executam a mesma implementação de `src/Stdlib.jl`.

| Operação | Decisão de contrato | Alternativa descartada e motivo |
| --- | --- | --- |
| `minimo`, `maximo` | Somente `Int64`/`Float64` finitos; retorna o elemento, não uma cópia convertida; empate → primeira ocorrência. | Promover tudo a `Float64`: perderia precisão em inteiros grandes e tornaria o tipo dependente do conteúdo. Aceitar texto: duplicaria `ordenar` sem um caso de uso. |
| `ordenar` | Só números ou só textos; estável; direção `crescente`/`decrescente` em texto, como `ordenar_tabela`; segunda posição opcional. | Parâmetro booleano `reverso`: opaco e inconsistente com `ordenar_tabela`. Ordenar listas mistas: exigiria uma ordem total arbitrária entre texto e número. |
| `sem_duplicatas` | Primeira ocorrência, ordem preservada, igualdade `isequal` (`1` e `1.0` iguais, `0.0` e `-0.0` distintos); aceita qualquer lista, inclusive de listas. | Igualdade por tipo e valor: contradiz `1 == 1.0` da própria linguagem. |
| `para_inteiro` | Inteiro; real inteiro representável; texto `[+-]?[0-9]+` na faixa. | Truncar ou arredondar reais: o usuário escolheria sem perceber; arredondamento exige operação própria com regra de empate. Tolerar espaços: `aparar` já existe e compõe. |
| `para_real` | Real; inteiro exato em `Float64`; texto decimal ou científico finito. | Aceitar `NaN`/`Inf`: valores não finitos já são rejeitados pela biblioteca estatística. |
| `para_texto` | Texto, número e booleano; mesma representação de `mostrar` para escalares. | Converter listas/registros: a apresentação de coleções pertence a `mostrar` e não tem contrato textual estável. |

Cobertura: `tests/test_abstraction_lists.jl` (valores, erros, composição com `filtrar`/`transformar`, paridade nos três modos, estabilidade, nomes de usuário idênticos aos novos nomes, ponte `Julia.Base` intacta).

### Achado novo: listas literais mistas divergem entre backends

Reprodução (já presente em `main`): `mostrar [1, 1.0]` apresenta `[1, 1.0]` no interpretador, onde a lista é `Vector{Any}`, e `[1.0, 1.0]` na Julia gerada, onde o literal é promovido a `Vector{Float64}`. Listas homogêneas não são afetadas. **Não foi corrigido nesta etapa**: emitir `Any[...]` na geração alinharia o tipo observável, mas muda o desempenho e a tipagem do código gerado para todos os programas; a decisão é arquitetural (categoria C) e requer benchmarks. Os testes novos verificam os casos mistos chamando a implementação diretamente, e os casos de lista homogênea nos três modos.

## Prioridades e decisões

| Categoria | Decisão |
| --- | --- |
| A — Correção imediata | Adicionar `contar(lista)` com contrato estrito e paridade entre backends; trocar a chamada Julia desnecessária no programa descritivo; corrigir a interpretação inconsistente de palavras-chave já aceitas. |
| B — Evolução planejada | **Feito:** extremos, ordenação/deduplicação de listas e conversões explícitas (seção seguinte). **Pendente:** opções nomeadas para `transformar_tabela` e `alinhar_sequencias` com migração aditiva (a política de tipos e os escores científicos permanecem explícitos); arredondamento (`arredondar`, `piso`, `teto`) com regra de empate definida; extremos e ordenação por chave de registro; uniformização do idioma dos diagnósticos. |
| C — Proposta arquitetural | Carregar spans de origem pelo AST/IR para diagnósticos precisos; considerar mudanças de sintaxe somente após definição formal de benefício, gramática, compatibilidade e paridade. |

## Política de nomes PT/EN

As palavras-chave existentes aceitam formas portuguesas e inglesas registradas no lexer; sua semântica deve ser idêntica independentemente da caixa reconhecida. Novas operações de biblioteca comuns recebem nome canônico em português. Não criar automaticamente um alias inglês: cada alias aumenta a superfície pública e pode colidir com identificadores. Aliases existentes e a ponte explícita continuam compatíveis. Mensagens de erro ABT devem identificar a operação pública; a padronização integral do idioma dos diagnósticos fica para uma revisão própria, sem mudar categorias de erro nesta auditoria.

## Critério para acompanhar a evolução

Uma melhoria de abstração só é considerada implementada quando o caso de uso real foi atualizado, testes de entrada válida/inválida e paridade dos três modos passaram, a documentação descreve o contrato, e as suítes históricas permaneceram compatíveis. Os itens B e C acima são **propostas**, não funcionalidades disponíveis.

## Validação executada

Ambiente: Linux, Julia 1.13.3; PythonCall opcional disponível e exercitado. A execução histórica da versão anterior terminou com **43 PASS, 2 PROBE, 1 TIMEOUT, 0 FAIL** usando `--compile=min`. O timeout foi no diferencial de 1.000 casos; sua repetição isolada com compilação Julia padrão concluiu **1.000 PASS, 0 FAIL**. Isso registra o custo de compilação mínima sem classificar um caso não concluído como aprovado naquela execução.

Após as correções, a suíte histórica completa terminou com **46 PASS, 2 PROBE, 0 PARTIAL, 0 FAIL, 0 TIMEOUT**. As duas sondas são exploratórias e seu estado não garante ausência de achados. O diferencial de 1.000 casos concluiu na suíte; os novos testes de abstração e de palavras-chave passaram nos modos interpretado e Julia gerada com e sem otimização. Os 36 programas `.abt` versionados passaram por análise e validação estrutural. A validação da documentação terminou com **49 PASS, 0 FAIL, 0 SKIP**, incluindo PythonCall, e a geração do site de documentação concluiu sem erro.

O script de aplicações terminou com **112 PASS, 0 FAIL, 0 TIMEOUT**, incluindo o exemplo de estatística atualizado e casos CSV, DNA, registros e erros nos três modos quando aplicável. O diferencial de bioestatística terminou com **19 PASS, 0 FAIL**, incluindo três aplicações completas nos três modos. O diferencial científico da versão 0.13.0 terminou com **16 PASS, 0 FAIL**, incluindo visualização e arquivo PNG. Os logs produzidos localmente podem conter caminhos do ambiente de teste e não são parte da API nem desta documentação publicada.

### Reprodução

Na raiz do clone, com `ABT_JULIA` apontando para Julia 1.13.3:

```sh
export ABT_JULIA=/caminho/para/julia-1.13.3/bin/julia
python3 tests/run_all_tests.py --julia "$ABT_JULIA" --timeout 180
python3 tests/test_applications.py --julia "$ABT_JULIA"
ABT_JULIA="$ABT_JULIA" python3 tests/test_scientific_backends_0130.py
ABT_JULIA="$ABT_JULIA" python3 tests/test_biostatistics_backends.py
python3 tools/validate_docs.py
```

Para reproduzir a interoperabilidade Python, instale PythonCall no ambiente Julia de teste e configure seu Python conforme a documentação de instalação; a biblioteca é opcional para programas ABT que não a importam.
