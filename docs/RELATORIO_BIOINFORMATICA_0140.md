# ABT 0.14.0 — expansão de bioinformática: relatório

## 1. Estado inicial auditado

Base: `d5070e8` (`main`, ABT 0.13.0, 62 operações públicas). Bioinformática existente: `ler_fasta`, `descrever_sequencias`, `registros_fasta`, `alinhar_sequencias` (FASTA por identificador, 8 argumentos posicionais, retorna escore e contagens), `ler_fastq`, `resumir_fastq`, `registros_fastq`, `frequencias_kmers`, `complemento_reverso`, `traduzir_dna` (quadro 1 fixo). Integração: FASTX.jl (leitura em fluxo), BioSequences.jl (alfabetos, tradução) e BioAlignments.jl (`pairalign`, modelo afim), todos carregados sob demanda. Lacunas encontradas: nenhuma operação de conteúdo GC, transcrição, subsequência, motivos ou validação de alfabeto sobre texto; alinhamento só via FASTA e sem identidade, similaridade, gaps ou alinhamento textual; sem matrizes de substituição nem proteínas; sem métricas por leitura, filtros de FASTQ, exportação nem estatísticas de comprimento. Suíte de referência antes das mudanças: ver seção 7.

## 2. Operações reutilizadas

Mantidas sem alteração de contrato: todas as operações da 0.13.0. `ler_fasta`, `ler_fastq`, `resumir_fastq`, `registros_fastq` passaram a aceitar leitores filtrados e a `descrever_sequencias`/`registros_fasta` foi acrescentado um callback interno opcional; o comportamento observável (valores, erros, ordem) permaneceu idêntico, o que as suítes de regressão confirmam. As bibliotecas Julia não foram substituídas nem reimplementadas: o alinhamento usa `BioAlignments.pairalign`, a tradução usa `BioSequences.translate`.

## 3. Novas operações (14; total 76)

`conteudo_gc`, `composicao_sequencia`, `transcrever_dna`, `traduzir_quadro`, `subsequencia`, `localizar_motivo`, `validar_sequencia`, `pontuacao_dna`, `pontuacao_proteina`, `alinhar_par`, `resumir_comprimentos`, `metricas_leituras`, `filtrar_fastq`, `exportar_fastq`. Contratos completos (assinatura, tipos, erros, ambiguidades, memória, limites) em `docs/src/standard-library/bio0140.md`; tutorial em `docs/src/tutorials/bioinformatics-advanced.md`.

## 4. Decisões de abstração

- **Esquema de pontuação como valor ABT.** `pontuacao_dna(...)` e `pontuacao_proteina(...)` devolvem registros passados a `alinhar_par`. Resolve as assinaturas longas sem argumentos nomeados (a gramática atual não os tem) e sem esconder parâmetros metodológicos: nenhum valor de pontuação tem padrão. Convenção de gap documentada e testada: custo de k = `abertura + k*extensao`.
- **Matrizes:** somente `BLOSUM62` e `PAM250`, as tabelas da BioAlignments.jl, conferidas contra valores publicados; nenhuma tabela foi digitada à mão. Resíduos fora dos 20 aminoácidos padrão são erro, não são mapeados em silêncio.
- **Sequências são texto em maiúsculas**, como em `frequencias_kmers`/`complemento_reverso`; não há tipo "sequência" novo nem tipos Julia expostos.
- **Filtros de FASTQ são valores** (`filtrar_fastq` devolve um leitor) e se acumulam; compõem com todas as operações FASTQ e preservam o fluxo. Filtrar listas de registros continua possível com `filtrar ... onde`.
- **Sem alterações de parser, IR ou gerador**; as operações entram pelo registro de extensões.
- **Duplicações evitadas:** `alinhar_sequencias` (FASTA) permanece; `alinhar_par` cobre texto/registros. `metricas_leituras` não repete `registros_fastq`: omite a sequência para reduzir memória.

## 5. Dependências

Nenhuma nova. FASTX.jl, BioSequences.jl e BioAlignments.jl já constavam em `Project.toml`. Versão do projeto: 0.14.0.

## 6. Aplicações completas (`applications/bioinformatics_0140/`)

A: `analise_sequencias.abt` (FASTA, comprimentos/N50, GC, motivos, RNA, tradução), B `alinhamento.abt` (global/local, DNA e BLOSUM62/PAM250) e C `qualidade_sequenciamento.abt` (FASTQ, métricas, filtros, exportação e releitura). Dados sintéticos pequenos e versionados. `tests/test_applications_0140.py` executa cada uma no interpretador, em Julia sem otimização e em Julia otimizada, compara com saídas esperadas versionadas, confere números-chave com Python puro e verifica que FASTA/FASTQ vazios, truncados ou inválidos falham com a mesma causa nos três modos.

## 7. Resultados dos testes (Linux, Julia 1.13.3, sem PythonCall)

- Unitário novo `tests/test_bioinformatics_0140.jl`: 405 verificações (GC, composição, transcrição, tradução, subsequência, motivos, validação, valores publicados das matrizes, casos analíticos de alinhamento, 200 comparações com um oráculo de programação dinâmica afim independente escrito no teste, FASTQ/FASTA malformados e vazios, paridade nos três backends): todas PASS.
- Aplicações 0.14: 27 PASS, 0 FAIL. Aplicações anteriores: 112 PASS, 0 FAIL (em 4 grupos paralelos). Diferencial bioestatística: 19 PASS. Diferencial científico 0.13: 16 PASS.
- Suíte histórica na `main` antes das mudanças (execução anterior, 0.13.0): 42 PASS, 2 PROBE, 4 PARTIAL, 0 FAIL. Suíte completa com as mudanças: 40 PASS, 2 PROBE, 4 PARTIAL e **1 FAIL**, `test_scientific_0130.jl`, que fixava o tamanho do catálogo de extensões em 41 (passou a 55); o número esperado foi atualizado e o teste isolado passou (54/54). A suíte completa **não** foi repetida depois dessa correção de uma linha. As 4 PARTIAL são as de PythonCall ausente.
- Validação da documentação: 57 PASS, 1 FAIL (exemplo `Python.math` de `manual/interop.md`, por falta de PythonCall). Referência gerada em dia (76 operações). Verificação de privacidade: passou. O build do site (Documenter) não foi executado localmente (ambiente `docs/` não instanciado); fica a cargo do CI do PR.

## 8. Equivalência entre backends

Interpretador, Julia sem otimização e Julia otimizada produzem a mesma saída, os mesmos erros (mensagem/causa) e os mesmos registros em todas as operações novas e nas três aplicações. Um defeito real foi encontrado e corrigido durante o desenvolvimento: arquivos incluídos no código gerado ficam dentro de um bloco `let`, onde `const` é ilegal; as novas bibliotecas não usam `const`.

## 9. Benchmarks

Ver `docs/BENCHMARK_BIOINFORMATICA_0140.md`. Resumo: após otimizar os laços de leitura (tipos fixados, validação por tabela de bytes, contagem em uma passada) as operações FASTA/FASTQ ficaram 2 a 7 vezes mais rápidas que antes, mas ainda 5 a 12 vezes mais lentas que Julia direta sem validação; o alinhamento é praticamente igual à Julia direta (+10–20%). **Achado:** o `--compile=min` padrão da CLI torna cargas de dados muito lentas (48 s a 4 min contra ~8 s com `ABT_JULIA_COMPILE=all`); o padrão não foi alterado.

## 10. Limitações e pendências

Não implementado: FASTA de proteínas em `ler_fasta`, motivos IUPAC/regex, fita reversa e códigos genéticos alternativos na tradução, alinhamento múltiplo, mapeamento a genomas, pares de leituras, BLOSUM/PAM além das duas requisitadas, argumentos nomeados (exigem mudança de gramática: proposta separada). Pendência de desempenho: modo de compilação adaptativo ou pré-compilação (PackageCompiler). O Phred médio é aritmético, não baseado em probabilidade de erro. Alinhamentos ótimos empatados: a pontuação é única, as posições dos gaps seguem a BioAlignments.jl.

## 11. Compatibilidade

Aditivo. Nenhuma operação removida ou alterada de contrato; nomes novos podem ser usados como identificadores de usuário (testado). Programas existentes passam. Conflitos de integração esperados com o PR #7 (abstração), que também altera contagem de operações, índice e `ABT_STDLIB_NAMES`; resolver na ordem de merge.
