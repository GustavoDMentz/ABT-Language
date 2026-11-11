# Tutorial 5 — sequências FASTA

**Objetivo:** validar FASTA, contar bases e calcular GC. **Pré-requisito:** FASTX.jl e BioSequences.jl no ambiente Julia. **Arquivos:** `applications/bio/sample.fasta`, `applications/bio/conteudo_gc.abt`; para alinhamento, `applications/science/amostras.fasta`.

```abt
sequencias = ler_fasta("applications/bio/sample.fasta", "DNA", "rejeitar", "normalizar")
resultado = descrever_sequencias(sequencias)
mostrar resultado
```

Execute `bin/abt run applications/bio/conteudo_gc.abt`. O registro inclui contagens de A/C/G/T/N, total de bases e GC percentual. `ler_fasta` exige alfabeto, ambiguidade e política de caixa explícitos; a leitura e a validação das bases ocorrem ao consumir o handle. Para métricas por registro e alinhamento, execute `bin/abt run docs/examples/bioinformatica.abt` e consulte [bioinformática](../standard-library/science.md).
