# Arquitetura modular de operações Julia no ABT 0.11.8

## Auditoria do fluxo atual

1. O lexer/parser converte a chamada ABT em IR `:call`. A operação mantém nome ABT comum; nenhuma palavra reservada nova foi criada.
2. A validação estrutural do IR continua antes da análise semântica. A análise resolve nomes com as regras atuais de escopo, inclusive funções e variáveis do usuário que sombreiam nomes de biblioteca. Somente uma chamada que resolve para um builtin consulta `ABT_EXTENSION_SPECS` para aridade e tipos estaticamente conhecidos. Ela **não executa** a implementação nem carrega pacote.
3. O interpretador recebe a função Julia registrada em `ABT_STDLIB`. Seu corpo valida valores dinâmicos e chama o pacote especializado somente quando a operação é alcançada.
4. O gerador Julia usa o mesmo registro para incluir o arquivo de implementação apenas quando a operação aparece no programa e não foi declarada como função do usuário. O código gerado chama exatamente a mesma função Julia da interpretação.
5. A implementação retorna um valor ABT. `mostrar` é a operação separada de apresentação; `codificar_json` retorna texto reutilizável.

Antes desta mudança, `src/ABT.jl` continha a lista de nomes, bindings do interpretador, aridades e bindings do gerador. As operações de bioinformática ainda estão nas listas históricas. As novas operações estão inteiramente no registro de `src/ExtensionRegistry.jl`: uma entrada nomeia domínio, aridade, tipos estáticos, retorno, função, arquivo fonte, dependências, carregamento e erros. Adicionar uma operação registrada exige implementar sua função e acrescentar **uma entrada** no registro; `src/ABT.jl` e `src/CLI.jl` não precisam ser editados. Isso reduz pontos de falha entre backends sem reescrever as operações históricas.

`src/Stdlib.jl` concentra tabela tipada e valores ABT comuns; `StdlibBio.jl` executa FASTX/BioSequences; `StdlibAnalytics.jl` e `StdlibJSON.jl` são extensões anteriores. `StdlibStats.jl` e `StdlibLinear.jl` têm corpos independentes. Não há loader de plugins externos: o registro é parte versionada do projeto e suas fontes são código confiável. A interoperabilidade Julia explícita permanece separada. ABT não é sandbox.

A auditoria também encontrou uma falha de distribuição: `install.py` copiava apenas os arquivos do núcleo antigo, deixando de fora `Stdlib*.jl`, o registro e o `Manifest.toml`. A lista instalada foi completada e o instalador agora instancia o projeto antes de pré-compilar. Marcadores da lista antiga são aceitos para atualização/desinstalação após verificação de integridade, sem descartar alterações do usuário. O teste de CLI instalada cobre agora o catálogo e uma operação da nova extensão.

`StatsBase.jl` é requerido dentro de `contar_categorias` depois da validação dos dados. A operação vazia retorna vazia sem carregá-lo. `JSON.jl` também é requerido na chamada de `codificar_json`. `LinearAlgebra` já era importada pelo núcleo para a interoperabilidade Julia explícita; a nova operação não acrescenta pacote externo, e não alegamos carregamento tardio onde ele não existe. `CSV.jl` é requerido por `ler_csv` conforme o contrato de tabelas existente.

## Contratos das duas operações novas

### `contar_categorias(tabela, coluna, politica_ausentes)` — StatsBase.jl

- Entrada: tabela tipada ABT, nome de coluna texto declarada como `texto`, política exatamente `"erro"` ou `"ignorar_linha"`. Dados da coluna devem ser texto ou ausentes. Não há conversão de números para rótulos.
- Resultado: registro `categorias`, `linhas_lidas`, `linhas_ignoradas`. `categorias` é lista de registros `(categoria, quantidade, proporcao)`. StatsBase.jl calcula contagens; ABT preserva a ordem de primeira ocorrência dos rótulos. `proporcao = quantidade / número de linhas aceitas`, em Float64. Nenhum valor é impresso.
- Ausência: `erro` rejeita com registro e coluna; `ignorar_linha` descarta a linha, incrementa o contador e calcula proporções somente sobre linhas aceitas. Tabela vazia ou todas as linhas ignoradas devolvem categorias vazias, sem divisão por zero.
- Falhas de tabela e pacote são traduzidas em diagnóstico da operação, preservando causa técnica. A implementação materializa a coluna em memória para chamar `StatsBase.countmap`; memória cresce com linhas aceitas.

### `resolver_sistema_spd(matriz, vetor)` — LinearAlgebra

- Entrada: matriz como lista não vazia de listas quadradas, vetor do mesmo tamanho. Todos os elementos devem ser **Float64 finitos**. Simetria exata é exigida; a matriz deve ser definida positiva. Isso define unicamente a solução sem tolerância arbitrária nem conversão implícita.
- A operação usa fatoração de Cholesky de LinearAlgebra e retorna `(solucao, residuo_norma)`, com solução Float64 e norma euclidiana do resíduo `A*x - b`. A ordem dos índices é a ordem das listas ABT. Entradas vazias, retangulares, assimétricas, não finitas, inteiras ou não positivas são erros.
- A convenção numérica é a aritmética Float64 de Julia/LAPACK. Pequenos resíduos por arredondamento são esperados. Resultados não finitos são rejeitados. Falhas de fatoração e biblioteca são convertidas em diagnóstico ABT com a causa original.

## Escopo, nomes e descoberta

Os nomes públicos permanecem funções comuns. Uma variável ou função ABT declarada com o mesmo nome segue as regras de sombreamento existentes; o registro só se aplica quando o nome resolve para a função de biblioteca. `abt operacoes` lista as operações registradas, domínio, contrato resumido e pacote necessário. Para usar um pacote Julia de maneira explícita, o mecanismo `usar Julia.Pacote` existente permanece disponível conforme a lista e as regras de import do projeto.

Nomes qualificados ABT, como `Estatistica.contar_categorias`, não foram adicionados: a gramática atual reserva caminhos qualificados para módulos externos explicitamente importados. Reutilizá-los para builtins criaria uma segunda interpretação do mesmo caminho e exigiria mudança no núcleo. O domínio fica no catálogo, sem alterar a resolução de nomes.

## Como integrar uma operação nova

1. Definir um contrato ABT antes de escrever código: tipos, ausência, vazio, ordem, precisão, efeitos e erros. Escolher um nome público que não seja palavra reservada.
2. Criar `src/StdlibDominio.jl` com uma função que valida valores em tempo de execução, usa uma biblioteca Julia quando necessário e retorna somente valores ABT. Se o pacote é opcional ou pesado, carregá-lo dentro da chamada com `Base.require` e tratar a falha. Usar `Base.invokelatest` somente na primeira chamada a métodos definidos por pacote carregado tardiamente, devido ao world age de Julia.
3. Acrescentar `include("StdlibDominio.jl")` e uma entrada em `ABT_EXTENSION_SPECS` de `src/ExtensionRegistry.jl`. `static_args` usa `:string`, `:list` ou `:unknown`; valores ainda desconhecidos são validados dinamicamente. `return_kind` só deve afirmar um tipo que o contrato sempre devolve.
4. Declarar a dependência em `Project.toml`/`Manifest.toml` se a operação precisa dela, preservando PythonCall como opcional. Registrar domínio, fonte gerada, pacote, política de carga e mapeamento de erro.
5. Adicionar testes de êxito, erro, vazio, sombreamento e equivalência dos três backends; medir custo de inicialização e RSS em processos independentes. Executar `test_modular_extensions.py` e `run_all_tests.py`.

O arquivo fonte é incluído no módulo ABT durante seu carregamento; ele deve **apenas definir funções e constantes baratas**. O pacote especializado deve ser carregado na chamada. Não há análise de confiança de código de terceiros nem isolamento de recursos.

## Aplicações e roadmap

`applications/data/distribuicao_vendas.abt` combina CSV.jl, StatsBase.jl e JSON.jl em seis linhas ABT. `applications/engineering/rede_condutancias.abt` resolve uma pequena rede de condutâncias com LinearAlgebra e produz JSON em cinco linhas. Os dados permanecem valores ABT; nenhuma aplicação manipula `Dict`, `DataFrame`, fatoração ou objeto interno de pacote.

Prioridades seguintes: (1) integrar as operações históricas ao registro apenas quando houver alteração funcional que justifique o risco; (2) tornar tabelas e contagens por categoria streaming se um caso real demonstrar gargalo de memória; (3) definir contratos de leitura JSON e junções tabulares antes de novas dependências; (4) avaliar HypothesisTests, HTTP e visualização com aplicações e efeitos explicitados. Essas são propostas, não funcionalidades implementadas.
