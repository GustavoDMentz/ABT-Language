# Programas de referência

Cada bloco abaixo é o conteúdo integral de um arquivo em `docs/examples/`. Execute com `bin/abt run docs/examples/NOME.abt` a partir da raiz. `falhar.abt` termina deliberadamente com código 1; os demais devem terminar com 0.

## bioinformatica

Arquivo: `docs/examples/bioinformatica.abt`.

```abt
sequencias = ler_fasta("applications/science/amostras.fasta", "DNA", "rejeitar", "exigir_maiusculas")
mostrar descrever_sequencias(sequencias)
mostrar registros_fasta(sequencias)
mostrar alinhar_sequencias(sequencias, "amostra_a", "amostra_b", "global", 2, -1, -3, -1)
```

## bioinformatica_avancada

Arquivo: `docs/examples/bioinformatica_avancada.abt`.

```abt
# Executar da raiz do repositório. Dados sintéticos versionados.
sequencia = "ATGGCCATTGTAATGGGCCGCTGA"
mostrar conteudo_gc(sequencia)
mostrar composicao_sequencia(sequencia)
mostrar transcrever_dna(subsequencia(sequencia, 1, 12))
mostrar traduzir_quadro(sequencia, 1)
mostrar localizar_motivo(sequencia, "ATG")
mostrar validar_sequencia(sequencia, "DNA", "rejeitar")

dna = pontuacao_dna(2, -1, -3, -1)
alinhamento = alinhar_par(sequencia, "ATGGCCATTGAATGGGCCGCTGA", "global", dna)
mostrar alinhamento.pontuacao
mostrar alinhamento.alinhamento_b
mostrar alinhar_par("HEAGAWGHEE", "PAWHEAE", "global", pontuacao_proteina("BLOSUM62", -10, -1)).pontuacao

genes = ler_fasta("applications/bioinformatics_0140/data/genes.fasta", "DNA", "permitir_N", "exigir_maiusculas")
mostrar resumir_comprimentos(genes)

leituras = ler_fastq("applications/bioinformatics_0140/data/leituras.fastq", "DNA", "permitir_N", "phred33")
aprovadas = filtrar_fastq(leituras, 24, 30, 1)
mostrar resumir_fastq(aprovadas)
mostrar transformar (metricas_leituras(aprovadas)) com valor.GC_percentual
mostrar exportar_fastq(aprovadas, ambiente("ABT_FASTQ_SAIDA", "/tmp/abt-doc-014.fastq")).leituras_escritas
```

## cientifico

Arquivo: `docs/examples/cientifico.abt`.

```abt
fastq = ler_fastq("applications/scientific_0130/data/reads.fastq", "DNA", "rejeitar", "phred33")
q = resumir_fastq(fastq)
registros = registros_fastq(fastq)
k = frequencias_kmers("ACGTAC", 2)
reverso = complemento_reverso("ACGTN")
proteina = traduzir_dna("ATGGAA")
a = [[2.0, 0.0], [0.0, 3.0]]
produto = produto_matricial(a, a)
t = transpor_matriz(a)
d = determinante_matriz(a)
posto = posto_matriz(a, 0.0)
svd = decompor_matriz(a, "svd")
solucao = resolver_sistema(a, [2.0, 3.0])
ajuste = ajustar_valores_p([0.01, 0.04, 0.2], "holm", 0.05)
otimo = minimizar_polinomio([1.0, -2.0, 1.0], -2.0, 3.0, 0.00000001, 0.0000000001, 100)
dados = ler_csv("applications/scientific_0130/data/expressao.csv", esquema("gene", "texto", "log2fc", "real", "p_valor", "real"), "erro")
selecao = selecionar_colunas(dados, ["gene", "p_valor"])
renomeado = renomear_colunas(selecao, ["p_valor"], ["probabilidade"])
ordenado = ordenar_tabela(renomeado, ["probabilidade"], ["crescente"], "erro")
unicos = remover_duplicatas(ordenado, ["gene"])
juncao = juntar_tabelas(unicos, selecao, ["gene"], "interna")
saida = exportar_csv(juncao, "/tmp/abt-docs-scientific.csv", "NA")
mostrar registro("fastq", q, "registros", registros, "k", k, "reverso", reverso, "proteina", proteina, "produto", produto, "transposta", t, "determinante", d, "posto", posto, "svd", svd.singulares, "solucao", solucao, "ajuste", ajuste, "otimo", otimo, "saida", saida)
```

## dados

Arquivo: `docs/examples/dados.abt`.

```abt
vendas = ler_csv("applications/data/vendas.csv", esquema("produto", "texto", "regiao", "texto", "unidades", "inteiro", "preco", "real"), "erro")
mostrar resumir_grupos(vendas, "regiao", "unidades", "erro")
mostrar contar_categorias(vendas, "regiao", "erro")
grupos = agrupar_dados(vendas, "regiao", "preco", "erro")
mostrar grupos
mostrar categorias(vendas, "regiao", ["Norte", "Sul"], "erro")
mostrar codificar_json(registro("regioes", coluna(vendas, "regiao")), "erro")
mostrar resolver_sistema_spd([[2.0, -1.0], [-1.0, 2.0]], [1.0, 1.0])
```

## estatistica

Arquivo: `docs/examples/estatistica.abt`.

```abt
mostrar resumo_estatistico([1, 2, 3, 4, 5])
mostrar intervalo_confianca_media([1, 2, 3, 4, 5], 0.95)
mostrar correlacao([1, 2, 3, 4], [2, 4, 5, 8], "pearson")
mostrar teste_t([1, 2, 3, 4], [2, 3, 5, 7], "welch", "bilateral", 0)
mostrar teste_nao_parametrico([1, 2, 3], [4, 5, 6], "mann_whitney", "bilateral")
mostrar teste_normalidade([1, 2, 3, 4, 5])
mostrar teste_proporcoes(8, 10, 3, 10, "bilateral")
mostrar probabilidade_distribuicao("normal", [0, 1], 0)
mostrar quantil_distribuicao("normal", [0, 1], 0.975)
mostrar probabilidade_normal(0, 1, 1)
```

## falhar

Arquivo: `docs/examples/falhar.abt`.

```abt
mostrar falhar("erro demonstrativo")
```

## grupos

Arquivo: `docs/examples/grupos.abt`.

```abt
dados = ler_csv("applications/biostatistics/ensaio.csv", esquema("grupo", "texto", "biomarcador", "real"), "erro")
grupos = agrupar_dados(dados, "grupo", "biomarcador", "erro")
mostrar testar_grupos(grupos, "controle", "tratamento", "welch")
```

## modelagem

Arquivo: `docs/examples/modelagem.abt`.

```abt
dados = ler_csv("applications/biostatistics/regressao.csv", esquema("resposta", "real", "idade", "inteiro", "exposicao", "inteiro"), "erro")
mostrar regressao_linear(dados, "resposta", ["idade", "exposicao"])
```

## nucleo

Arquivo: `docs/examples/nucleo.abt`.

```abt
# Executar da raiz do repositório.
texto = ler_texto("applications/data/sample.csv")
mostrar comprimento_texto(aparar(" ABT "))
mostrar maiusculas("abt")
mostrar inicia_com(texto, "nome")
mostrar contar_caractere("banana", "a")
mostrar contar([1, 2, 3])
amostra = [30, 12, 18, 12, 24]
mostrar minimo(amostra)
mostrar maximo(amostra)
mostrar ordenar(amostra)
mostrar ordenar(amostra, "decrescente")
mostrar sem_duplicatas(amostra)
mostrar para_inteiro("42") + 1
mostrar para_real("2.5") * 2
mostrar para_texto(3.5)
mostrar linhas_texto("a\nb")
mostrar ambiente("ABT_DOC_NOME", "documentacao")
mostrar registro("categoria", "exemplo", "n", 2)
mostrar descrever([1, 2, 3, 4])
```

## tabelas

Arquivo: `docs/examples/tabelas.abt`.

```abt
arquivo = "applications/data/sample.csv"
tipos = esquema("nome", "texto", "grupo", "texto", "valor", "real")
dados = ler_csv(arquivo, tipos, "erro")
mostrar coluna(dados, "nome")
mostrar linhas_tabela(dados)
selecionados = filtrar_tabela(dados, "valor", ">", 10.0)
mostrar resumir_coluna(selecionados, "valor")
alterados = transformar_tabela(dados, "valor", "dobro", "*", 2.0, "real")
mostrar coluna(alterados, "dobro")
```

## visualizacao

Arquivo: `docs/examples/visualizacao.abt`.

```abt
dados = ler_csv("applications/science/experimento.csv", esquema("tratamento", "texto", "resposta", "real", "tempo", "inteiro"), "erro")
figura = grafico(dados, "tempo", "resposta", "linha")
mostrar salvar_figura(figura, ambiente("ABT_DOC_FIGURE_PATH", "/tmp/abt-doc-figura.png"))
```
