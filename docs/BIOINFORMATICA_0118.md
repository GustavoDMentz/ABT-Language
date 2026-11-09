# ABT 0.11.8 — bioinformática

## Auditoria e dependências

A aplicação anterior percorria `linhas_texto(ler_texto(...))`, materializava o arquivo inteiro e implementava um parser FASTA restrito em 51 linhas ABT. O mecanismo de imports explícitos de Julia permanece disponível, mas sua exposição direta faria cada aplicação repetir decisões de alfabeto, identificadores e GC. Por isso a integração usa funções da biblioteca ABT, ligadas aos mesmos helpers no interpretador e no gerador. FASTX.jl fornece o leitor de registros; BioSequences.jl fornece `LongDNA`/`LongRNA` e as bases tipadas. A [documentação FASTX](https://biojulia.dev/FASTX.jl/stable/fasta/) informa que registros podem conter caracteres inválidos, portanto a biblioteca ABT valida cada base conforme a política explícita antes da construção tipada. BioSequences.jl aceita mais códigos IUPAC em 4 bits; a política `permitir_N` continua restrita somente a `N`.

Alterações: `src/StdlibBio.jl` concentra os contratos, a leitura e as contagens; `src/ABT.jl` liga três funções ABT a essa biblioteca em ambos os backends; `src/StdlibRender.jl` apresenta a fonte sem revelar seu marcador interno; `Project.toml` e `Manifest.toml` registram as duas dependências. Não houve alteração de lexer, parser, IR, validação estrutural ou sintaxe. Durante o teste inicial, a comparação direta com `DNA_N` numa sequência de 2 bits produziu erro de codificação; a contagem de `N` passou a ser calculada como comprimento menos as quatro bases canônicas. O caso com DNA sem `N` e os casos com `N` em DNA/RNA passaram depois dessa correção.

## Contrato

A gramática, o IR e as regras de escopo não mudaram. As funções abaixo são operações comuns da biblioteca ABT, com a mesma implementação no interpretador e no Julia gerado. FASTX.jl 2.2.0 e BioSequences.jl 3.5.2 constam em `Project.toml`; PythonCall não participa dessa API. O carregamento dos dois pacotes ocorre na primeira análise, não ao abrir um programa ABT comum.

```abt
arquivo = ler_fasta("dados.fasta", "DNA", "rejeitar", "normalizar")
mostrar descrever_sequencias(arquivo)
mostrar registros_fasta(arquivo)
```

`ler_fasta(caminho, alfabeto, ambiguidades, caixa)` exige caminho textual não vazio e arquivo existente. O alfabeto é exatamente `"DNA"` ou `"RNA"`. A política de ambiguidades é `"rejeitar"` ou `"permitir_N"`; apenas `N` é aceito nesta última. A política de caixa é `"exigir_maiusculas"` ou `"normalizar"`. A normalização afeta somente a análise: o campo `sequencia` em `registros_fasta` preserva o texto original. Não há inferência de alfabeto ou de política.

`ler_fasta` devolve um valor ABT que representa a fonte, sem deixar um arquivo aberto. `descrever_sequencias` reabre o arquivo, percorre registros com FASTX.jl e computa contagens usando BioSequences.jl, sem armazenar todas as sequências. A saída tem `sequencias`, `bases`, `A`, `C`, `G`, `T` para DNA ou `U` para RNA, `N` e `GC_percentual`. O percentual é `100*(C+G)/(A+C+G+T/U)`, excluindo `N` do denominador. Um registro sem base não ambígua é erro, porque seu GC é indefinido. O arquivo sem registros, sequências vazias, identificadores vazios ou duplicados, bases fora do conjunto permitido e caixa incompatível também são erros. Identificadores duplicados são detectados mantendo um conjunto de nomes, de modo que a memória da análise agregada cresce com a quantidade de identificadores, além da maior sequência lida.

`registros_fasta` usa as mesmas validações e devolve uma lista de registros com `identificador`, `descricao`, `sequencia`, `comprimento`, contagens `A/C/G/T/U/N` e `GC_percentual`. A lista é materializada; use `descrever_sequencias` para arquivos grandes. Erros incluem o caminho e, quando conhecido, o índice do registro, seu identificador e a posição da base. Erros originados no parser conservam sua causa. O conteúdo é validado ao chamar uma das funções de análise, pois a fonte é preguiçosa. Se o arquivo mudar entre chamadas, cada chamada vê seu conteúdo no momento da leitura.

## Aplicações

- `applications/bio/conteudo_gc.abt`: relatório agregado, com caminho configurável por `ABT_FASTA_PATH`.
- `applications/bio/por_registro.abt`: composição e conteúdo GC por registro, mesma entrada.

Ambas usam as mesmas operações reutilizáveis e aceitam FASTA real, sem parser escrito em ABT. A aplicação antiga de GC tinha 51 linhas; a nova tem 4. A segunda aplicação tem 3 linhas.

## Reprodução no Ubuntu com Julia 1.13.3

```sh
julia --project=. -e 'using Pkg; Pkg.instantiate()'
ABT_JULIA=julia bin/abt run applications/bio/conteudo_gc.abt
ABT_JULIA=julia bin/abt run applications/bio/por_registro.abt
ABT_JULIA=julia python3 tests/test_bio.py --julia julia
python3 tools/audit_bio_results.py
ABT_JULIA=julia python3 tests/test_applications.py --julia julia
JULIA_CONDAPKG_BACKEND=Null JULIA_PYTHONCALL_EXE=/usr/bin/python3 ABT_REQUIRE_PYTHON=1 \
  python3 tests/run_all_tests.py --julia julia --timeout 300
python3 benchmarks/benchmark_bio.py --julia julia --repetitions 3
```

O comando de regressão com Python requer PythonCall.jl no depot Julia e NumPy no Python indicado. Sem eles, as suítes opcionais devem ser registradas como não executadas ou parciais, nunca como aprovadas. O teste da nova API biológica não depende de PythonCall.

## Limites e prioridades

Esta camada não aceita aminoácidos, FASTQ nem todos os códigos IUPAC; requer contrato explícito antes de expandir alfabetos. O identificador FASTA é a chave de unicidade; descrições podem repetir. `registros_fasta` materializa o arquivo. `descrever_sequencias` percorre o arquivo inteiro a cada chamada. Dados provenientes de arquivos são confiados ao runtime e bibliotecas Julia; o ABT não fornece sandbox. Próximos passos: perfis de qualidade FASTQ com política explícita, análise por janela e operações de fluxo composicionais, conforme necessidades de aplicações reais.

## Validação executada

Ambiente: Ubuntu Linux, Julia 1.13.3, FASTX.jl 2.2.0, BioSequences.jl 3.5.2, Python do sistema com NumPy para os testes legados opcionais. O `tests/test_bio.py` final executou 21 casos em três modos (interpretador, Julia gerada sem otimização e Julia gerada otimizada): **63 PASS, 0 FAIL**. As saídas bem-sucedidas coincidiram exatamente; `tools/audit_bio_results.py` comparou a linha de diagnóstico ABT dos erros e encontrou **0 divergências**. O aplicativo por registro, com três amostras, passou nos mesmos três modos. `tests/test_applications.py` executou **109 PASS, 0 FAIL, 0 TIMEOUT** antes da inclusão do caso da segunda aplicação, que foi executado separadamente (**3 PASS**). A regressão histórica final, com PythonCall ligado ao Python local, terminou em **39 PASS, 2 PROBE, 0 PARTIAL, 0 FAIL, 0 TIMEOUT**. As duas sondas exploratórias não são declarações de aprovação. Resultados completos: `logs/test_logs/bio_results.json`, `logs/test_logs/bio_parity_audit.json`, `applications/test_results.json`, `applications/bio_app_results.json` e `logs/test_logs/summary.json`.

A primeira regressão histórica havia produzido 35 PASS, 2 PROBE, 3 PARTIAL e 1 FAIL porque PythonCall tentou resolver um ambiente Conda sem acesso à rede. `logs/test_logs/bio_historical_initial.log` e `logs/test_logs/bio_historical_initial_summary.json` preservam esse resultado. A repetição com `JULIA_CONDAPKG_BACKEND=Null` e `JULIA_PYTHONCALL_EXE=/usr/bin/python3` passou integralmente; isso foi uma correção de ambiente, não do ABT.

## Desempenho e memória

`benchmarks/benchmark_bio.py` criou FASTA determinísticos de 100, 100.000 e 1.000.000 de bases, distribuídos respectivamente por 1, 10 e 100 registros. Cada combinação de tamanho, backend e `--compile` foi executada em **três processos independentes**, totalizando **36 PASS, 0 FAIL**. O código Julia gerado foi emitido antes do cronômetro; usa a otimização padrão do gerador. `/usr/bin/time -v` mediu o processo inteiro. A tabela mostra mediana de tempo real, faixa mínimo–máximo, medianas de CPU usuário/sistema e mediana do pico de RSS. Arquivo bruto: `logs/test_logs/bio_benchmark.json`; comando e saída: `logs/test_logs/bio_benchmark_final.log`.

| Bases | Backend | Compile | Real mediana [mín–máx] (s) | CPU usuário/sistema (s) | RSS pico mediano (MiB) |
|---:|---|---|---:|---:|---:|
| 100 | Interpretador | min | 0,86 [0,86–0,87] | 0,81 / 0,13 | 304,6 |
| 100 | Interpretador | all | 6,07 [5,85–6,60] | 5,90 / 0,19 | 395,3 |
| 100 | Julia gerada | min | 0,49 [0,49–0,50] | 0,46 / 0,12 | 289,8 |
| 100 | Julia gerada | all | 1,74 [1,73–1,80] | 1,69 / 0,13 | 313,0 |
| 100.000 | Interpretador | min | 2,80 [2,78–2,84] | 2,74 / 0,15 | 320,5 |
| 100.000 | Interpretador | all | 5,77 [5,75–5,88] | 5,64 / 0,19 | 392,7 |
| 100.000 | Julia gerada | min | 2,45 [2,43–2,46] | 2,40 / 0,13 | 297,3 |
| 100.000 | Julia gerada | all | 1,75 [1,73–1,77] | 1,71 / 0,13 | 313,1 |
| 1.000.000 | Interpretador | min | 20,20 [20,10–20,55] | 20,11 / 0,15 | 314,9 |
| 1.000.000 | Interpretador | all | 6,18 [6,09–6,18] | 6,05 / 0,20 | 419,7 |
| 1.000.000 | Julia gerada | min | 20,33 [19,82–20,45] | 20,13 / 0,13 | 297,4 |
| 1.000.000 | Julia gerada | all | 1,89 [1,88–1,91] | 1,85 / 0,13 | 313,3 |

O tempo inclui inicialização de Julia, carregamento tardio dos pacotes, abertura, leitura FASTA, validação e contagem; **não é tempo de I/O isolado**. O RSS é do processo inteiro, não o tamanho da estrutura ABT nem alocação interna Julia. Uma sonda inicial com 1 milhão de bases competia com outras suítes e foi interrompida; seu log está em `logs/test_logs/bio_benchmark_exploratory.log` e não entra na tabela. A repetição acima ocorreu depois do término das outras suítes.

`all` compensa no código gerado já em 100.000 bases e no interpretador em 1 milhão; para 100 bases o custo de compilação domina. O resumo percorre o arquivo sem materializar todos os registros: entre 100.000 e 1.000.000 de bases, o RSS mediano do Julia gerado com `all` mudou de 313,1 para 313,3 MiB, mas isso **não prova memória constante**. O maior registro e o conjunto de identificadores ainda consomem memória; `registros_fasta` materializa todos os resultados. Uma segunda análise relê o arquivo, evitando cache implícito e preservando o contrato preguiçoso.
