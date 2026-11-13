# Bioinformática com sequências FASTA

Este tutorial lê uma sequência de DNA, valida as bases e calcula contagens e conteúdo GC. Ele usa os arquivos versionados `applications/bio/sample.fasta` e `applications/bio/conteudo_gc.abt`.

## Antes de começar

A instalação do projeto precisa incluir FASTX.jl e BioSequences.jl. Execute a aplicação a partir da raiz do repositório para que o caminho relativo do FASTA seja encontrado.

## Leia e descreva

```abt
sequencias = ler_fasta("applications/bio/sample.fasta", "DNA", "rejeitar", "normalizar")
resultado = descrever_sequencias(sequencias)
mostrar resultado
```

## Resultado esperado

Execute `bin/abt run applications/bio/conteudo_gc.abt`. O arquivo de exemplo tem uma sequência de 12 bases: A=4, C=2, G=3, T=3 e N=0. O resultado inclui `sequencias = 1`, `bases = 12` e `GC_percentual` próximo de `41.66666666666667`.

## Contratos e limites

`ler_fasta` exige alfabeto, política de ambiguidade e política de caixa explícitos. A leitura e a validação das bases ocorrem ao consumir o leitor. `descrever_sequencias` calcula o resumo; `mostrar` apenas o apresenta. Bases inválidas produzem diagnóstico em vez de serem corrigidas silenciosamente.

Para métricas por registro e alinhamento, execute `bin/abt run docs/examples/bioinformatica.abt`. Consulte [operações de bioinformática](../standard-library/science.md), [FASTQ e DNA no ABT 0.13.0](../standard-library/scientific0130.md) e [limites semânticos](../reference/semantics.md).
