# Tutorial 6 — bioinformática avançada (0.14.0)

**Objetivo:** analisar sequências, alinhá-las e filtrar leituras de sequenciamento escrevendo apenas ABT. **Pré-requisito:** FASTX.jl, BioSequences.jl e BioAlignments.jl no ambiente Julia (`Pkg.instantiate()`). **Arquivos:** `applications/bioinformatics_0140/`, dados sintéticos versionados sem significado biológico. Nenhum exemplo abaixo importa Julia.

## 1. Sequências como texto

Sequências são textos em **maiúsculas**; `maiusculas` (já existente) converte quando necessário. Posições começam em 1 e o fim é incluído.

```abt
sequencia = "ATGGCCATTGTAATGGGCCGCTGA"
mostrar conteudo_gc(sequencia)
mostrar composicao_sequencia(sequencia)
mostrar transcrever_dna(subsequencia(sequencia, 1, 12))
mostrar traduzir_quadro(sequencia, 1)
mostrar localizar_motivo(sequencia, "ATG")
```

`conteudo_gc` divide G+C pelas bases A, C, G e T/U; `N` não entra no denominador e uma sequência só de `N` é erro. `transcrever_dna` troca T por U na fita codificante; não calcula o complemento da fita molde (`complemento_reverso` existe para isso). `traduzir_quadro` usa o código genético padrão no quadro escolhido (1, 2 ou 3) e ignora uma a duas bases finais incompletas; bases ambíguas são erro, porque um códon com `N` não tem tradução única. `localizar_motivo` faz busca exata e devolve todas as posições, inclusive sobrepostas. Para validar antes de processar:

```abt
mostrar validar_sequencia("ACGT", "DNA", "rejeitar")
mostrar validar_sequencia("ACGN", "DNA", "rejeitar")
mostrar validar_sequencia("ACGN", "DNA", "permitir_N")
mostrar validar_sequencia("ACDEFG", "proteina", "rejeitar")
```

## 2. Alinhamento com pontuação explícita

O esquema de pontuação é um valor ABT criado por `pontuacao_dna` ou `pontuacao_proteina` e passado a `alinhar_par`. Nada é padrão: acertos, erros e penalidades de gap mudam o significado do resultado. Um gap de comprimento *k* custa `abertura + k * extensao`.

```abt
dna = pontuacao_dna(2, -1, -3, -1)
resultado = alinhar_par("ACGTTTACGT", "ACGACGT", "global", dna)
mostrar resultado.pontuacao
mostrar resultado.aberturas_gap
mostrar resultado.identidade_percentual
mostrar resultado.alinhamento_a
mostrar resultado.alinhamento_b
```

O modo `global` alinha as sequências inteiras; `local` procura o melhor trecho e informa `inicio_a`, `fim_a`, `inicio_b` e `fim_b`. A **identidade** é `correspondencias / comprimento_alinhamento`; a **similaridade** conta as colunas com escore de substituição positivo (em DNA coincide com a identidade). `insercoes` são resíduos da primeira sequência sem par; `delecoes`, da segunda.

Para proteínas a matriz de substituição é uma escolha científica explícita (`BLOSUM62` ou `PAM250`, vindas da BioAlignments.jl):

```abt
a = "HEAGAWGHEE"
b = "PAWHEAE"
para cada matriz em ["BLOSUM62", "PAM250"] {
    r = alinhar_par(a, b, "global", pontuacao_proteina(matriz, -10, -1))
    mostrar registro("matriz", matriz, "pontuacao", r.pontuacao, "similaridade", r.similaridade_percentual)
}
```

Sequências proteicas só aceitam os 20 aminoácidos padrão; `X`, `B`, `Z` e `*` são erro em `alinhar_par`. O alinhamento usa memória proporcional ao produto dos comprimentos; não é adequado a sequências genômicas inteiras. Quando há vários alinhamentos ótimos, a pontuação é única, mas as posições dos gaps podem diferir.

## 3. Composição com listas, filtros e pipelines

As operações recebem e devolvem valores comuns; registros de `registros_fasta` entram direto nas novas operações.

```abt
genes = registros_fasta(ler_fasta("applications/bioinformatics_0140/data/genes.fasta", "DNA", "permitir_N", "exigir_maiusculas"))
ricos = filtrar genes onde valor.GC_percentual >= 50
mostrar transformar ricos com valor.identificador
ricos
    transformar com conteudo_gc(valor.sequencia)
    limitar a 2
    mostrar
```

`registros_fasta` carrega as sequências em memória. Para apenas comprimentos, `resumir_comprimentos` lê em fluxo e guarda só os tamanhos:

```abt
genes = ler_fasta("applications/bioinformatics_0140/data/genes.fasta", "DNA", "permitir_N", "exigir_maiusculas")
mostrar resumir_comprimentos(genes)
```

O N50 é o menor comprimento tal que as sequências desse tamanho ou maiores cobrem metade das bases do conjunto.

## 4. Qualidade de FASTQ

`metricas_leituras` devolve uma linha por leitura sem a sequência (menos memória que `registros_fastq`). `filtrar_fastq` apenas declara critérios; a seleção ocorre em fluxo quando o leitor é consumido por `resumir_fastq`, `registros_fastq`, `metricas_leituras` ou `exportar_fastq`. Filtros sucessivos se combinam com E lógico. O Phred médio é a média aritmética dos escores Phred+33, não a média das probabilidades de erro.

```abt
leituras = ler_fastq("applications/bioinformatics_0140/data/leituras.fastq", "DNA", "permitir_N", "phred33")
aprovadas = filtrar_fastq(leituras, 24, 30, 1)
mostrar resumir_fastq(aprovadas)
mostrar transformar (metricas_leituras(aprovadas)) com valor.identificador
excelentes = filtrar metricas_leituras(leituras) onde valor.percentual_q30 >= 90
mostrar soma de transformar excelentes com 1
saida = exportar_fastq(aprovadas, ambiente("ABT_FASTQ_SAIDA", "/tmp/abt-tutorial-014.fastq"))
mostrar saida.leituras_escritas
```

## 5. Erros

Entradas inválidas nunca são corrigidas em silêncio. Cada mensagem nomeia a operação e a causa:

```text
ABT conteudo_gc: base inválida 'Z' na posição 4 (esperado A, C, G, T/U ou N em maiúsculas)
ABT traduzir_quadro: o quadro 2 não contém códon completo
ABT alinhar_par: nenhum alinhamento local com pontuação positiva
ABT FASTQ: arquivo 'leituras.fastq': ABT FASTQ registro 3: esperado DNA maiúsculo, alfabeto ACGT
```

## Desempenho e memória

Operações sobre texto (`conteudo_gc`, `subsequencia`, `localizar_motivo`) são imediatas. `resumir_comprimentos`, `resumir_fastq`, `filtrar_fastq` e `exportar_fastq` leem em fluxo; `metricas_leituras` guarda uma linha por leitura (sem as sequências); `registros_fasta` e `registros_fastq` guardam as sequências; `alinhar_par` usa memória proporcional ao produto dos comprimentos. A CLI inicia rápido com `--compile=min`, mas esse modo executa de forma interpretada o código Julia ainda não pré-compilado: para ler arquivos grandes ou alinhar sequências, use `ABT_JULIA_COMPILE=all bin/abt run programa.abt` (custa cerca de 8 s de partida). Números medidos em `docs/BENCHMARK_BIOINFORMATICA_0140.md`.

## Limitações desta etapa

Sem arquivos FASTA de proteínas (`ler_fasta` aceita DNA e RNA), sem códigos IUPAC em motivos, sem fita reversa nem tabelas genéticas alternativas na tradução, sem alinhamento múltiplo ou de leituras a um genoma, sem tratamento de pares de leituras. Essas capacidades exigiriam contratos próprios e não foram simuladas. Consulte a [referência](../standard-library/bio0140.md) e os programas completos em `applications/bioinformatics_0140/`.
