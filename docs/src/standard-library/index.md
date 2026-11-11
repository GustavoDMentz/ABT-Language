# Índice da biblioteca padrão

A fonte de verdade dos nomes públicos é `ABT.ABT_STDLIB_NAMES` em `src/ABT.jl`, formada pelas operações básicas, bioinformáticas e por `ABT_EXTENSION_SPECS` em `src/ExtensionRegistry.jl`. Na versão 0.12.0 há **42 operações**. `abt operacoes` mostra as extensões modulares; não lista todas as operações básicas. A validação documental compara o conjunto completo com as seções abaixo.

| Domínio | Operações |
|---|---|
| [Núcleo, texto e ambiente](core.md) | `registro`, `descrever`, `falhar`, `ambiente`, `ler_texto`, `linhas_texto`, `aparar`, `maiusculas`, `inicia_com`, `comprimento_texto`, `contar_caractere` |
| [CSV e tabelas](tables.md) | `esquema`, `ler_csv`, `coluna`, `linhas_tabela`, `filtrar_tabela`, `transformar_tabela`, `resumir_coluna` |
| [Estatística e bioestatística](statistics.md) | `resumo_estatistico`, `intervalo_confianca_media`, `correlacao`, `teste_t`, `teste_nao_parametrico`, `teste_normalidade`, `teste_proporcoes`, `probabilidade_distribuicao`, `quantil_distribuicao`, `regressao_linear`, `probabilidade_normal` |
| [Dados, JSON e álgebra](data.md) | `resumir_grupos`, `contar_categorias`, `agrupar_dados`, `testar_grupos`, `categorias`, `codificar_json`, `resolver_sistema_spd` |
| [Bioinformática e visualização](science.md) | `ler_fasta`, `descrever_sequencias`, `registros_fasta`, `alinhar_sequencias`, `grafico`, `salvar_figura` |

As operações retornam valores. A instrução `mostrar` apresenta um valor de modo determinístico; exportar uma figura é uma operação separada. Bibliotecas científicas têm carregamento tardio, mas precisam estar resolvidas no ambiente Julia. Não há política universal implícita para ausentes: cada operação declara seu contrato.

Os [programas de referência](../examples/programs.md) usam dados sintéticos ou arquivos do próprio repositório e são executados automaticamente. Para hipóteses e limitações de inferência, consulte [semântica e limites](../reference/semantics.md).
