# Bibliotecas Julia e Python

`usar Julia.Módulo` importa um módulo permitido antes da chamada. O núcleo reconhece `Statistics`, `LinearAlgebra` e `Base` com funções e aridades explícitas. `ABT.packages.toml` declara APIs adicionais por nome, UUID, versão e aridade; a instalação continua responsabilidade do projeto Julia e de seu `Manifest.toml`.

```abt
usar Julia.Statistics
mostrar Julia.Statistics.mean([1, 2, 3])
```

O import deve estar no nível superior. Um caminho `Julia.Módulo.função(...)` só é válido quando o módulo foi importado e a função declarada com a aridade correta. Não há `eval` arbitrário de código Julia fornecido pelo programa. `examples/pacote_dates.abt` demonstra um pacote da biblioteca padrão declarado no manifesto opcional.

`usar Python.modulo` importa PythonCall sob demanda. Os objetos Python permanecem na ponte e não são convertidos automaticamente em listas ABT. Caminhos de import têm validação de formato e componentes privados são rejeitados. O runtime PythonCall e eventuais pacotes Python precisam ser configurados separadamente. A ponte não é sandbox: bibliotecas importadas podem ter efeitos externos.

```abt
usar Python.math
mostrar Python.math.sqrt(9)
```

`check` valida nomes, importações declaradas e estrutura sem executar o pacote. Falhas reais de carregamento ou chamadas aparecem durante `run`. Para APIs especializadas, prefira as [operações ABT](../standard-library/index.md), que retornam valores estruturados e expõem contratos próprios.
