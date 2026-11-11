#!/usr/bin/env python3
"""Generate the checked-in ABT operation reference from reviewed contracts."""
from pathlib import Path
import argparse

ROOT = Path(__file__).resolve().parent.parent
DEST = ROOT / "docs/src/standard-library"

# name | exact ABT call | purpose | parameters | result | preconditions, missing and errors |
# effect | Julia dependency | runnable example. No information is inferred from a name.
SECTIONS = {
"core": ("Núcleo, texto e ambiente", """
registro|registro("campo", valor, ...)|Cria um registro reutilizável com campos nomeados.|Um ou mais pares nome textual/valor; nomes válidos, distintos e sem prefixo `_`; sem valores padrão.|Registro com campos na ordem informada.|Aridade par, nomes válidos e sem duplicação; valores ausentes podem ser armazenados; erros de nome e aridade.|Nenhum.|Base Julia.|nucleo.abt
descrever|descrever(lista)|Resume números reais finitos.|Lista com ao menos dois `Int64` ou `Float64`; sem padrão.|Registro `quantidade`, `soma`, `media`, `mediana`, `desvio_padrao`, `minimo`, `maximo`.|Rejeita ausentes, valores não finitos, soma com overflow e lista curta.|Nenhum.|Statistics (stdlib).|nucleo.abt
falhar|falhar(mensagem)|Interrompe o programa com erro explícito.|`mensagem`: texto; sem padrão.|Não retorna normalmente.|Tipo não textual gera erro; a mensagem informada aparece no diagnóstico.|Lança erro e encerra a execução corrente.|Base Julia.|falhar.abt
ambiente|ambiente(nome, fallback)|Lê uma variável de ambiente.|Nome e valor alternativo: textos; sem padrão.|Texto do ambiente ou `fallback` quando a variável não existe.|Nome vazio e fallback não textual são erros; não distingue variável vazia de ausente por inferência.|Lê o ambiente do processo.|Base Julia.|nucleo.abt
ler_texto|ler_texto(caminho)|Lê um arquivo UTF-8 completo.|Caminho textual não vazio; sem padrão.|Texto integral do arquivo.|Arquivo ausente ou inválido gera erro com caminho e causa; não introduz valor ausente.|Lê arquivo; materializa o conteúdo.|Base Julia.|nucleo.abt
linhas_texto|linhas_texto(texto)|Separa texto em linhas.|Um texto; sem padrão.|Lista de textos.|Entrada não textual é erro; não interpreta CSV.|Nenhum.|Base Julia.|nucleo.abt
aparar|aparar(texto)|Remove espaços nas bordas do texto.|Um texto; sem padrão.|Texto aparado.|Entrada não textual é erro.|Nenhum.|Base Julia.|nucleo.abt
maiusculas|maiusculas(texto)|Converte texto para maiúsculas segundo Julia.|Um texto; sem padrão.|Texto convertido.|Entrada não textual é erro; Unicode segue `uppercase` da Julia.|Nenhum.|Base Julia.|nucleo.abt
inicia_com|inicia_com(texto, prefixo)|Verifica prefixo textual.|Dois textos; sem padrão.|Booleano.|Entradas não textuais são erro.|Nenhum.|Base Julia.|nucleo.abt
comprimento_texto|comprimento_texto(texto)|Conta caracteres Unicode do texto.|Um texto; sem padrão.|Inteiro.|Entrada não textual é erro; não conta bytes.|Nenhum.|Base Julia.|nucleo.abt
contar_caractere|contar_caractere(texto, caractere)|Conta ocorrências de um caractere.|Dois textos; segundo argumento deve ter comprimento um.|Inteiro.|Caractere vazio ou com mais de uma unidade de caractere é erro.|Nenhum.|Base Julia.|nucleo.abt
"""),
"tables": ("Arquivos, CSV e tabelas", """
esquema|esquema("coluna", "tipo", ...)|Declara nomes e tipos de colunas explicitamente.|Pares nome/tipo; tipos `texto`, `inteiro`, `real`, `booleano`; sem padrão.|Registro de esquema.|Rejeita nomes duplicados, pares incompletos e tipo desconhecido; não infere tipos.|Nenhum.|Base Julia.|tabelas.abt
ler_csv|ler_csv(caminho, esquema, politica[, delimitador])|Abre CSV com esquema explícito e linhas iteráveis.|Caminho, esquema, política `erro`/`permitir`; delimitador textual de um caractere, padrão `,`.|Valor tabela ABT com fonte, colunas, tipos e iterador.|Cabeçalho deve coincidir exatamente; vazio, duplicado, tipo inválido e ausente sob `erro` são erros. Conversão ocorre ao percorrer linhas.|Lê arquivo sob demanda; não materializa todas as linhas inicialmente.|CSV.jl e Tables.jl sob demanda.|tabelas.abt
coluna|coluna(tabela, nome)|Materializa uma coluna de tabela.|Tabela ABT e nome textual existente; sem padrão.|Lista dos valores, inclusive `missing` se permitido.|Coluna inexistente ou CSV inválido gera erro contextual; materializa a coluna.|Lê linhas da fonte.|Tabelas ABT/CSV.jl.|tabelas.abt
linhas_tabela|linhas_tabela(tabela)|Materializa os registros de tabela.|Tabela ABT; sem padrão.|Lista de registros.|Falhas de leitura ou conversão da fonte são erros; ausentes seguem o esquema da tabela.|Lê e materializa linhas.|Tabelas ABT/CSV.jl.|tabelas.abt
filtrar_tabela|filtrar_tabela(tabela, coluna, operador, valor)|Produz tabela filtrada sem materialização imediata.|Operador textual `==`, `!=`, `>`, `>=`, `<`, `<=`; valor deve ter tipo exato da coluna.|Nova tabela ABT iterável.|Coluna desconhecida, tipo incompatível e ausente na coluna filtrada são erros; booleano aceita apenas igualdade/desigualdade.|Lê a fonte quando consumida.|Tabelas ABT/CSV.jl.|tabelas.abt
transformar_tabela|transformar_tabela(tabela, origem, destino, operador, operando, tipo)|Cria coluna numérica derivada.|Origem numérica, nome novo, operador `+`, `-`, `*`, `/`, operando do tipo da origem, destino `inteiro`/`real`.|Nova tabela ABT iterável com coluna adicional.|Ausente, overflow, divisão incompatível ou resultado diferente do tipo declarado são erros; não converte silenciosamente.|Lê a fonte quando consumida.|Tabelas ABT/CSV.jl.|tabelas.abt
resumir_coluna|resumir_coluna(tabela, coluna)|Resume uma coluna numérica.|Tabela e coluna `inteiro`/`real`; sem padrão.|Registro `quantidade`, `soma`, `media`, `minimo`, `maximo`.|Tabela vazia, ausente, overflow e total não finito são erros.|Percorre a fonte.|Tabelas ABT/CSV.jl.|tabelas.abt
"""),
"statistics": ("Estatística e bioestatística", """
resumo_estatistico|resumo_estatistico(xs)|Resume amostra com quartis.|Lista de números finitos, n ≥ 2; sem padrão.|Registro com n, média, mediana, variância amostral, desvio, extremos e quartis 25/75%.|Ausente, tipo incompatível ou resultado não finito são erros; quartis usam `Statistics.quantile`.|Nenhum.|Statistics (stdlib).|estatistica.abt
intervalo_confianca_media|intervalo_confianca_media(xs, nivel)|Calcula intervalo t bilateral da média.|Lista numérica n ≥ 2; nível numérico estritamente entre 0 e 1.|Registro n, nível, média, limites inferior/superior e método.|Variância zero, ausente, nível inválido e intervalo não finito são erros.|Nenhum.|HypothesisTests.jl sob demanda.|estatistica.abt
correlacao|correlacao(xs, ys, metodo)|Calcula Pearson ou Spearman.|Listas pareadas n ≥ 3; método `pearson`/`spearman`.|Registro método, n e coeficiente.|Tamanhos diferentes, constante, ausente e número não finito são erros; empates de Spearman seguem StatsBase.|Nenhum.|Statistics; StatsBase.jl para Spearman.|estatistica.abt
teste_t|teste_t(xs, ys, metodo, alternativa, diferenca_nula)|Executa teste t configurado explicitamente.|Método `uma_amostra` (`ys=[]`), `pareado`, `welch` ou `student`; alternativa `bilateral`, `menor`, `maior`; diferença nula finita.|Registro método, alternativa, tamanhos, hipótese nula, estatística, graus de liberdade e valor-p.|n ≥ 2; pareado usa `xs-ys`; variância zero, ausente, tamanho e inferência não finita são erros. `menor`/`maior` referem-se à diferença A−B.|Nenhum.|HypothesisTests.jl sob demanda.|estatistica.abt
teste_nao_parametrico|teste_nao_parametrico(xs, ys, metodo, alternativa)|Testa amostras sem hipótese paramétrica t.|Método `mann_whitney` ou `wilcoxon_pareado`; alternativa bilateral/menor/maior.|Registro método, alternativa, tamanhos e valor-p.|n ≥ 2; pares de mesmo tamanho; empates e zeros seguem HypothesisTests; ausentes e método inválido são erros.|Nenhum.|HypothesisTests.jl sob demanda.|estatistica.abt
teste_normalidade|teste_normalidade(xs)|Executa Shapiro–Wilk.|Lista numérica com 3 a 5000 valores.|Registro estatística e valor-p.|Variância zero, ausente, tamanho ou inferência não finita são erros.|Nenhum.|HypothesisTests.jl sob demanda.|estatistica.abt
teste_proporcoes|teste_proporcoes(sa, na, sb, nb, alternativa)|Compara duas proporções por Fisher exato 2×2.|Quatro contagens `Int64`; alternativa bilateral/menor/maior.|Registro de contagens, proporções e valor-p.|0 ≤ sucessos ≤ totais positivos; soma dos totais deve caber em Int64; ausente, overflow ou alternativa inválida são erros.|Nenhum.|HypothesisTests.jl sob demanda.|estatistica.abt
probabilidade_distribuicao|probabilidade_distribuicao(modelo, parametros, valor)|Calcula CDF, `P(X ≤ valor)`.|Modelo `normal`, `student_t`, `binomial` ou `poisson`; parâmetros explícitos em lista.|Registro de modelo, parâmetros, valor e resultado.|Desvios/graus/taxas/probabilidades têm domínios próprios; modelos discretos exigem contagem inteira; inválidos são erros.|Nenhum.|Distributions.jl sob demanda.|estatistica.abt
quantil_distribuicao|quantil_distribuicao(modelo, parametros, p)|Calcula quantil de distribuição.|Mesmos modelos/parâmetros da CDF; 0 < p < 1.|Registro de modelo, parâmetros, probabilidade e quantil.|Fronteiras 0/1, ausentes e parâmetros inválidos são erros; quantil discreto segue Distributions.|Nenhum.|Distributions.jl sob demanda.|estatistica.abt
regressao_linear|regressao_linear(tabela, resposta, preditores)|Ajusta OLS com intercepto.|Tabela tipada, resposta textual e lista de preditores numéricos distintos.|Registro com n, nomes, coeficientes, erros-padrão, valores-p, IC 95% e R².|n > número de parâmetros, posto completo, resposta variável e sem ausentes; matriz singular ou inferência inválida são erros. Fatores não são codificados implicitamente.|Percorre e materializa colunas necessárias.|GLM.jl e LinearAlgebra.|modelagem.abt
probabilidade_normal|probabilidade_normal(media, desvio, limiar)|Calcula cauda superior normal.|Três números finitos; desvio > 0.|Registro com probabilidade acima do limiar.|Ausente, desvio não positivo e número não finito são erros.|Nenhum.|Distributions.jl sob demanda.|estatistica.abt
"""),
"data": ("Dados, JSON e álgebra", """
resumir_grupos|resumir_grupos(tabela, grupo, valor, politica)|Resume valores por grupo.|Grupo textual, valor numérico, política explícita de ausentes.|Registro com grupos e contagem de linhas.|Coluna/tipo/ausente inválido ou soma inválida são erros; ordem segue primeira ocorrência.|Percorre a fonte.|CSV.jl via tabela ABT.|dados.abt
contar_categorias|contar_categorias(tabela, coluna, politica)|Calcula frequências e proporções categóricas.|Tabela, coluna textual e política de ausentes.|Registro estruturado de categorias.|Rejeita coluna, tipo ou política inválidos; ausentes tratados pela política informada.|Percorre a fonte.|StatsBase.jl sob demanda.|dados.abt
agrupar_dados|agrupar_dados(tabela, grupo, valor, politica)|Agrupa valores numéricos para análises posteriores.|Grupo textual, valor numérico, política `erro`/`ignorar_linha`.|Registro `grupos`, `linhas_lidas`, `linhas_ignoradas`.|Tipo ou coluna inválida, ausente sob `erro` e valor não finito são erros; grupos preservam ordem de aparição.|Percorre e materializa grupos.|DataFrames.jl sob demanda.|grupos.abt
testar_grupos|testar_grupos(grupos, nome_a, nome_b, metodo)|Compara dois grupos com teste t bilateral.|Resultado de `agrupar_dados`; nomes distintos; método `welch`/`student`.|Registro com médias, n, estatística e valor-p.|Ambos os grupos devem existir e ter ≥ 2 valores finitos; não escolhe método automaticamente.|Nenhum.|HypothesisTests.jl sob demanda.|grupos.abt
categorias|categorias(tabela, coluna, niveis, politica)|Conta níveis categóricos explícitos.|Coluna textual; lista não vazia de níveis únicos; política `erro`/`ignorar_linha`.|Registro com contagens na ordem dos níveis e linhas ignoradas.|Valores fora dos níveis, ausentes sob `erro` e níveis repetidos são erros.|Percorre a fonte.|CategoricalArrays.jl sob demanda.|dados.abt
codificar_json|codificar_json(valor, politica)|Serializa valor ABT em JSON textual.|Valor estruturado e política explícita de ausentes.|Texto JSON.|Ciclos, tipos não suportados, números não finitos e ausentes sob política de erro são rejeitados.|Nenhum.|JSON.jl sob demanda.|dados.abt
resolver_sistema_spd|resolver_sistema_spd(matriz, vetor)|Resolve sistema linear simétrico definido positivo.|Lista de listas `Float64` quadrada e vetor `Float64` compatível.|Registro com solução e norma do resíduo.|Forma, tipo, finitude, simetria ou positividade inválidas são erros; sem coerção implícita.|Nenhum.|LinearAlgebra (stdlib).|dados.abt
"""),
"science": ("Bioinformática e visualização", """
ler_fasta|ler_fasta(caminho, alfabeto, ambiguidade, caixa)|Declara leitura FASTA validada.|Alfabeto `DNA`/`RNA`; ambiguidade `rejeitar`/`permitir_N`; caixa `exigir_maiusculas`/`normalizar`.|Handle FASTA ABT reutilizável.|Arquivo inexistente e políticas inválidas são erros; conteúdo é validado ao percorrer.|Verifica existência do arquivo; leitura posterior.|FASTX.jl e BioSequences.jl sob demanda.|bioinformatica.abt
descrever_sequencias|descrever_sequencias(fasta)|Resume composição de sequências.|Handle de `ler_fasta`.|Registro de bases, contagens e GC%.|Arquivo vazio, ID duplicado, base inválida ou GC indefinido são erros; política vem do handle.|Lê FASTA em fluxo.|FASTX.jl e BioSequences.jl.|bioinformatica.abt
registros_fasta|registros_fasta(fasta)|Materializa métricas por registro FASTA.|Handle de `ler_fasta`.|Lista de registros com ID, sequência, contagens e GC%.|Mesma validação do resumo; materializa as sequências.|Lê e materializa FASTA.|FASTX.jl e BioSequences.jl.|bioinformatica.abt
alinhar_sequencias|alinhar_sequencias(fasta, id_a, id_b, modo, acerto, erro, abertura, extensao)|Alinha duas sequências nomeadas.|IDs distintos; modo `global`/`local`; quatro pontuações Int64 explícitas.|Registro com escore, correspondências, diferenças, inserções e deleções.|IDs ausentes, políticas inválidas e pontuações fora do contrato são erros; não escolhe matriz científica implicitamente.|Lê FASTA e calcula alinhamento.|BioAlignments.jl e BioSequences.jl sob demanda.|bioinformatica.abt
grafico|grafico(tabela, eixo_x, eixo_y, modo)|Constrói especificação de gráfico.|Dois eixos numéricos; modo `linha`/`pontos`.|Registro de especificação com coordenadas.|Tabela vazia, ausente, eixo inexistente ou tipo incompatível são erros.|Percorre e materializa coordenadas; não grava arquivo.|Tabelas ABT.|visualizacao.abt
salvar_figura|salvar_figura(figura, caminho)|Exporta gráfico ABT como PNG ou SVG.|Especificação de `grafico`; caminho textual terminado em `.png` ou `.svg`.|Registro `arquivo`, `pontos`.|Formato, IO ou especificação inválidos são erros; não altera os dados originais.|Escreve arquivo no caminho informado.|Cairo.jl sob demanda.|visualizacao.abt
"""),
}

def rows(block):
    result = []
    for line in block.strip().splitlines():
        parts = line.split("|")
        if len(parts) != 9:
            raise ValueError(f"expected 9 fields: {line}")
        result.append(parts)
    return result

def render(key, title, block):
    data = rows(block)
    names = [r[0] for r in data]
    lines = [f"# {title}", "", "Todas as assinaturas abaixo são chamadas ABT, não assinaturas Julia internas. Não há argumentos opcionais além dos indicados. Os arquivos de exemplo são executados a partir da raiz do repositório pelo validador da documentação.", ""]
    for name, signature, purpose, params, result, contract, effect, dependency, example in data:
        related = ", ".join(f"`{n}`" for n in names if n != name) or "—"
        lines += [f"## `{name}`", "", f"`{signature}`", "", purpose, "",
                  f"- **Parâmetros e padrões:** {params}", f"- **Retorno:** {result}",
                  f"- **Pré-condições, ausentes, erros e limites:** {contract}",
                  f"- **Efeitos:** {effect}", f"- **Dependência Julia:** {dependency}",
                  f"- **Exemplo executável:** [`docs/examples/{example}`](../examples/programs.md#{Path(example).stem}).",
                  f"- **Operações relacionadas nesta seção:** {related}.", ""]
    return "\n".join(lines)

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    for key, (title, block) in SECTIONS.items():
        target = DEST / f"{key}.md"
        content = render(key, title, block)
        if args.check:
            if not target.is_file() or target.read_text() != content:
                raise SystemExit(f"reference out of date: {target}")
        else:
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(content)
    examples = ["# Programas de referência", "", "Cada bloco abaixo é o conteúdo integral de um arquivo em `docs/examples/`. Execute com `bin/abt run docs/examples/NOME.abt` a partir da raiz. `falhar.abt` termina deliberadamente com código 1; os demais devem terminar com 0.", ""]
    for path in sorted((ROOT / "docs/examples").glob("*.abt")):
        examples += [f"## {path.stem}", "", f"Arquivo: `docs/examples/{path.name}`.", "", "```abt", path.read_text().rstrip(), "```", ""]
    target = ROOT / "docs/src/examples/programs.md"
    content = "\n".join(examples)
    if args.check:
        if not target.is_file() or target.read_text() != content:
            raise SystemExit(f"examples page out of date: {target}")
    else:
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(content)
    print("Reference synchronized:", sum(len(rows(b)) for _, b in SECTIONS.values()), "operations")

if __name__ == "__main__":
    main()
