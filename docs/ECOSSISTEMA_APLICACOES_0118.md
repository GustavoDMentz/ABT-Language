# ABT 0.11.8 — aplicações e ecossistema

Esta avaliação registra a primeira rodada das aplicações. A evolução posterior nesta mesma cópia acrescentou as funções de biblioteca `descrever` e `registro`, sem sintaxe nova; veja [ABSTRACAO_BIBLIOTECA_0118.md](ABSTRACAO_BIBLIOTECA_0118.md) para os contratos, testes e limites atualizados.

## Capacidades confirmadas na implementação

O lexer/parser de `src/ABT.jl` reconhece literais inteiros, decimais, texto, booleanos e listas; atribuição; `mostrar`; `se ... { } senao { }`; `para cada ... em ... { }`; funções nomeadas e `retornar`. Há operadores `+`, `-`, `*`, `/`, comparações `> < >= <= == !=` e lógicos `e`/`ou` com curto-circuito. Não há operador módulo, índice `[]` de acesso, atribuição a campos, `try/catch`, `break`/`continue` nem chamada livre como comando. Blocos usam chaves; a indentação é sintaxe apenas para pipelines de coleções, terminados por `mostrar`.

Listas podem ser filtradas, transformadas, limitadas e agregadas por `soma de`/`média de`. `valor` existe apenas durante a operação de coleção. Laços aceitam coleções classificadas como lista ou tipo desconhecido, mas a operação `filtrar` exige um `Vector` Julia em tempo de execução. Não há leitura/gravação de arquivo nativa do ABT nem import de arquivos ABT como módulos. Os programas de dados usam chamadas externas explícitas para arquivos.

`usar Julia.Módulo` permite chamadas de funções com nomes e aridades declarados. `Statistics`, `LinearAlgebra` e `Base` têm uma superfície fixa; `ABT.packages.toml` acrescenta pacotes opcionais com UUID, versão exata e funções/arity. Julia gerencia instalação e dependências. A declaração por si só não instala o pacote. O carregamento ocorre ao alcançar o import. `usar Python.módulo` carrega PythonCall somente quando necessário; funções e atributos públicos de objetos Python são acessíveis explicitamente. Objetos Python continuam objetos externos até conversão explícita com `PythonCall.pyconvert`. Os dois runtimes executam código externo confiável; ABT não fornece sandbox.

Para as aplicações, a superfície Julia `Base` ganhou somente `collect`, referências aos tipos `Float64`, `Int64`, `String`, `Bool` e `error`, todos com uma chamada declarada. `collect` converte o iterador Python em `Vector` ABT; as referências de tipo são usadas em `pyconvert`; `error` permite validação explícita de entrada. `ABT.packages.toml` declara somente `PythonCall.pyconvert` da versão local 0.9.37. PythonCall continua opcional para programas sem esse import. Nenhuma regra de sintaxe, inferência, execução ou validação foi relaxada.

## Três aplicações

As [fontes, dados, saídas e instruções](../applications/README.md) foram testadas com Julia 1.13.3 e Python 3 do sistema. Estatística calcula indicadores de uma amostra ABT; CSV lê registros reais com aspas, valida esquema, filtra e resume; DNA lê FASTA, valida o alfabeto e calcula GC. O código mostra duas limitações de ergonomia: conversões explícitas de `Py` para valores Julia e ausência de uma API de arquivos/linhas própria do ABT. O CSV é materializado em memória antes do laço.

## Avaliação de pacotes no ambiente local

Disponibilidade foi verificada com `Base.find_package` no depot usado pelos testes. “Ausente” significa **não instalado aqui**, não incompatível com ABT. As capacidades citadas abaixo vêm da documentação dos mantenedores, mas nenhuma integração ausente foi declarada funcional sem execução.

| Pacote | Estado verificado | Integração possível e menor passo coerente | Dependências adicionais |
|:---|:---|:---|:---|
| `Statistics` | **Funciona**: já integrado e usado no programa estatístico. | `mean`, `median`, `std`, `var`, `cor`, `cov` já estão declarados. | Biblioteca padrão Julia. |
| `CSV.jl` | **Não testado; ausente** no depot. | Instalar num projeto Julia, declarar UUID/versão e chamadas como `CSV.File(path)`; adaptar acesso a linhas/colunas conforme o contrato ABT, sem supor que uma tabela seja `Vector`. [Documentação CSV.jl](https://csv.juliadata.org/latest/). | Pacote CSV.jl e dependências resolvidas por Julia; `DataFrames.jl` só se a aplicação exigir um DataFrame. |
| `DataFrames.jl` | **Não testado; ausente**. | Instalar/declarar e definir operações de tabela explícitas; o pipeline ABT atual é para `Vector`, não para `DataFrame`. [Documentação DataFrames.jl](https://dataframes.juliadata.org/stable/). | Pacote DataFrames.jl e dependências Julia. |
| `JSON3.jl` | **Não testado; ausente**. | Declarar `read`/`write` com aridades claras após instalar; decidir representação ABT de objetos JSON e tratamento de campos antes de expor API mais ampla. [Documentação JSON3.jl](https://quinnj.github.io/JSON3.jl/dev/). | Pacote JSON3.jl e dependências Julia. |
| `BioSequences.jl` | **Não testado; ausente**. | Declarar construtores/operadores de sequências após instalar e definir a conversão para tipos observáveis ABT. [Documentação BioSequences.jl](https://biojulia.dev/BioSequences.jl/stable/). | Pacote BioSequences.jl. Para leitura FASTA robusta, avaliar também [FASTX.jl](https://biojulia.dev/FASTX.jl/stable/fasta/). |

O programa CSV usa o módulo `csv` da biblioteca padrão Python porque `CSV.jl` não estava disponível e a interface atual já permite esse import explícito. O programa de DNA usa Python para ler/contar caracteres; não alega oferecer a validação completa de FASTX ou BioSequences.

## Testes e limites

Execução: `python3 tests/test_applications.py --julia "$ABT_JULIA"`, com `JULIA_CONDAPKG_BACKEND=Null`, `JULIA_PYTHONCALL_EXE=/usr/bin/python3` e o depot local configurados. A primeira rodada, antes das funções `descrever` e `registro`, teve **25 PASS, 0 FAIL, 0 TIMEOUT**. O arquivo `applications/test_results.json` é atualizado pela rodada mais recente e deve ser consultado para os resultados atuais.

A suíte histórica foi executada com `python3 tests/run_all_tests.py --julia "$ABT_JULIA" --timeout 180`: **38 PASS, 2 PROBE, 0 PARTIAL, 0 FAIL, 0 TIMEOUT**. Inclui o diferencial determinístico de 1.000 casos. As duas `PROBE` são sondas exploratórias, não provas de ausência de defeitos. O resumo estruturado e os logs individuais estão em `logs/test_logs/`.

Limitações demonstradas: a CLI pode mostrar `PyException` sem texto amigável da causa Python; não há gerenciamento de arquivo com escopo no ABT, então as aplicações fecham arquivos explicitamente após materializá-los; o CSV inteiro é carregado em memória; listas ABT não oferecem append/índice; o programa de estatística tem amostra literal; o parser FASTA desta aplicação aceita apenas A/C/G/T e não tenta cobrir toda a especificação FASTA.

## Roadmap priorizado

1. **Ergonomia de dados básica:** uma API explícita, pequena e testada para arquivo/linhas e acesso a elementos/registro, preservando a distinção entre `Vector`, iterador e tabela. Isso evita materialização e chamadas Python verbosas nos programas de dados.
2. **Diagnósticos de interoperabilidade:** apresentar a causa de `PyException` sem perder a categoria de erro e sem divergência entre interpretador e Julia gerada.
3. **CSV.jl opcional:** instalar em ambiente isolado, declarar superfície mínima e testar leitura/filtragem em ambos os backends; avaliar `DataFrames.jl` somente se operações tabulares justificarem seu custo.
4. **FASTX.jl + BioSequences.jl opcionais:** usar parser FASTA e tipos biológicos para arquivos grandes/alfabetos ambíguos, após definir conversão e política de erros observáveis.
5. **JSON3.jl opcional:** depois de estabilizar campos e coleções externas, definir mapeamento ABT de objetos JSON antes de expor `read`/`write`.

Cada passo deve ter um programa real e teste diferencial antes de ampliar a linguagem. Nenhum pacote ausente foi instalado nesta etapa.
