# Bioinformática e visualização

Todas as assinaturas abaixo são chamadas ABT, não assinaturas Julia internas. Não há argumentos opcionais além dos indicados. Os arquivos de exemplo são executados a partir da raiz do repositório pelo validador da documentação.

## `ler_fasta`

`ler_fasta(caminho, alfabeto, ambiguidade, caixa)`

Declara leitura FASTA validada.

- **Parâmetros e padrões:** Alfabeto `DNA`/`RNA`; ambiguidade `rejeitar`/`permitir_N`; caixa `exigir_maiusculas`/`normalizar`.
- **Retorno:** Handle FASTA ABT reutilizável.
- **Pré-condições, ausentes, erros e limites:** Arquivo inexistente e políticas inválidas são erros; conteúdo é validado ao percorrer.
- **Efeitos:** Verifica existência do arquivo; leitura posterior.
- **Dependência Julia:** FASTX.jl e BioSequences.jl sob demanda.
- **Exemplo executável:** [`docs/examples/bioinformatica.abt`](../examples/programs.md#bioinformatica).
- **Operações relacionadas nesta seção:** `descrever_sequencias`, `registros_fasta`, `alinhar_sequencias`, `grafico`, `salvar_figura`.

## `descrever_sequencias`

`descrever_sequencias(fasta)`

Resume composição de sequências.

- **Parâmetros e padrões:** Handle de `ler_fasta`.
- **Retorno:** Registro de bases, contagens e GC%.
- **Pré-condições, ausentes, erros e limites:** Arquivo vazio, ID duplicado, base inválida ou GC indefinido são erros; política vem do handle.
- **Efeitos:** Lê FASTA em fluxo.
- **Dependência Julia:** FASTX.jl e BioSequences.jl.
- **Exemplo executável:** [`docs/examples/bioinformatica.abt`](../examples/programs.md#bioinformatica).
- **Operações relacionadas nesta seção:** `ler_fasta`, `registros_fasta`, `alinhar_sequencias`, `grafico`, `salvar_figura`.

## `registros_fasta`

`registros_fasta(fasta)`

Materializa métricas por registro FASTA.

- **Parâmetros e padrões:** Handle de `ler_fasta`.
- **Retorno:** Lista de registros com ID, sequência, contagens e GC%.
- **Pré-condições, ausentes, erros e limites:** Mesma validação do resumo; materializa as sequências.
- **Efeitos:** Lê e materializa FASTA.
- **Dependência Julia:** FASTX.jl e BioSequences.jl.
- **Exemplo executável:** [`docs/examples/bioinformatica.abt`](../examples/programs.md#bioinformatica).
- **Operações relacionadas nesta seção:** `ler_fasta`, `descrever_sequencias`, `alinhar_sequencias`, `grafico`, `salvar_figura`.

## `alinhar_sequencias`

`alinhar_sequencias(fasta, id_a, id_b, modo, acerto, erro, abertura, extensao)`

Alinha duas sequências nomeadas.

- **Parâmetros e padrões:** IDs distintos; modo `global`/`local`; quatro pontuações Int64 explícitas.
- **Retorno:** Registro com escore, correspondências, diferenças, inserções e deleções.
- **Pré-condições, ausentes, erros e limites:** IDs ausentes, políticas inválidas e pontuações fora do contrato são erros; não escolhe matriz científica implicitamente.
- **Efeitos:** Lê FASTA e calcula alinhamento.
- **Dependência Julia:** BioAlignments.jl e BioSequences.jl sob demanda.
- **Exemplo executável:** [`docs/examples/bioinformatica.abt`](../examples/programs.md#bioinformatica).
- **Operações relacionadas nesta seção:** `ler_fasta`, `descrever_sequencias`, `registros_fasta`, `grafico`, `salvar_figura`.

## `grafico`

`grafico(tabela, eixo_x, eixo_y, modo)`

Constrói especificação de gráfico.

- **Parâmetros e padrões:** Dois eixos numéricos; modo `linha`/`pontos`.
- **Retorno:** Registro de especificação com coordenadas.
- **Pré-condições, ausentes, erros e limites:** Tabela vazia, ausente, eixo inexistente ou tipo incompatível são erros.
- **Efeitos:** Percorre e materializa coordenadas; não grava arquivo.
- **Dependência Julia:** Tabelas ABT.
- **Exemplo executável:** [`docs/examples/visualizacao.abt`](../examples/programs.md#visualizacao).
- **Operações relacionadas nesta seção:** `ler_fasta`, `descrever_sequencias`, `registros_fasta`, `alinhar_sequencias`, `salvar_figura`.

## `salvar_figura`

`salvar_figura(figura, caminho)`

Exporta gráfico ABT como PNG ou SVG.

- **Parâmetros e padrões:** Especificação de `grafico`; caminho textual terminado em `.png` ou `.svg`.
- **Retorno:** Registro `arquivo`, `pontos`.
- **Pré-condições, ausentes, erros e limites:** Formato, IO ou especificação inválidos são erros; não altera os dados originais.
- **Efeitos:** Escreve arquivo no caminho informado.
- **Dependência Julia:** Cairo.jl sob demanda.
- **Exemplo executável:** [`docs/examples/visualizacao.abt`](../examples/programs.md#visualizacao).
- **Operações relacionadas nesta seção:** `ler_fasta`, `descrever_sequencias`, `registros_fasta`, `alinhar_sequencias`, `grafico`.
