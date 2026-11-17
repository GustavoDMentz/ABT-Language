# Bibliotecas Julia e Python

`usar Julia.Módulo` importa um módulo permitido antes da chamada. O núcleo reconhece `Statistics`, `LinearAlgebra` e `Base` com funções e aridades explícitas. `ABT.packages.toml` declara APIs adicionais por nome, UUID, versão e aridade; a instalação continua responsabilidade do projeto Julia e de seu `Manifest.toml`.

```abt
usar Julia.Statistics
mostrar Julia.Statistics.mean([1, 2, 3])
```

O import deve estar no nível superior. Um caminho `Julia.Módulo.função(...)` só é válido quando o módulo foi importado e a função declarada com a aridade correta. Não há `eval` arbitrário de código Julia fornecido pelo programa. `examples/pacote_dates.abt` demonstra um pacote da biblioteca padrão declarado no manifesto opcional.

| Módulo incluído na ponte | Funções permitidas (aridade) |
|---|---|
| `Statistics` | `mean(1)`, `median(1)`, `std(1)`, `var(1)`, `cor(2)`, `cov(2)` |
| `LinearAlgebra` | `norm(1)`, `dot(2)`, `cross(2)`, `normalize(1)` |
| `Base` | `sum(1)`, `prod(1)`, `maximum(1)`, `minimum(1)`, `sort(1)`, `reverse(1)`, `length(1)`, `unique(1)`, `collect(1)`, `Float64(1)`, `Int64(1)`, `String(1)`, `Bool(1)`, `error(1)` |

`ABT.packages.toml` também declara `Dates.Date(1)`, `Dates.year(1)` e `PythonCall.pyconvert(2)` com UUID e versão fixos; esses módulos só funcionam se resolvidos no ambiente Julia. Uma aridade listada é a superfície ABT permitida, não a lista de todos os métodos Julia existentes.

`usar Python.modulo` importa PythonCall sob demanda. Os objetos Python permanecem na ponte e não são convertidos automaticamente em listas ABT. Caminhos de import têm validação de formato e componentes privados são rejeitados; o acesso a atributos iniciados por `_` também é rejeitado. A ponte usa `pygetattr` para atributos de objetos Python e só publica o namespace após import bem-sucedido. O runtime PythonCall e eventuais pacotes Python precisam ser configurados separadamente. A ponte não é sandbox: bibliotecas importadas podem ter efeitos externos.

## Segurança de execução

Um programa ABT roda com os privilégios de quem o executa: pode ler e gravar arquivos (`ler_texto`, `exportar_csv`, `salvar_figura`), consultar variáveis de ambiente (`ambiente`) e, com Python, chamar o sistema. Por isso a CLI aplica estas regras:

- **Módulos Python permitidos por padrão:** `numpy`, `scipy`, `pandas`, `math`, `cmath`, `statistics`, `random`, `json`, `re`, `datetime`, `decimal`, `fractions`, `itertools`, `collections`, `string`, `textwrap`, `operator`, `functools`, `Bio`, `sklearn` e `matplotlib`. Qualquer outro (como `os` ou `subprocess`) é recusado com um erro de segurança.
- **`--permitir-python`** (ou `ABT_PERMITIR_PYTHON=1`) libera qualquer módulo: use só em programas em que você confia.
- **`--seguro`** bloqueia `usar Python`, `ambiente` e qualquer leitura ou escrita fora da pasta do programa (links simbólicos são resolvidos). Prevalece sobre `--permitir-python`.

```bash
abt --seguro run programa.abt
abt --permitir-python run programa_confiavel.abt
```

As bibliotecas da lista, como `pandas` e `numpy`, ainda podem ler e gravar arquivos: a lista reduz o risco, não o elimina. Para programas desconhecidos, use `--seguro`.

As variáveis `ABT_JULIA` (qual Julia executar) e `ABT_PERMITIR_PYTHON` vêm do ambiente: quem controla o ambiente já controla a execução. Não as defina em ambientes compartilhados nem herdadas de fontes que você não controla. Na instalação integrada, `ABT_JULIA` não é necessária: o `abt` usa a Julia embutida.

```abt
usar Python.math
mostrar Python.math.sqrt(9)
```

`check` valida nomes, importações declaradas e estrutura sem executar o pacote. Falhas reais de carregamento ou chamadas aparecem durante `run`. Para APIs especializadas, prefira as [operações ABT](../standard-library/index.md), que retornam valores estruturados e expõem contratos próprios.
