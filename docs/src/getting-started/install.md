# Instalação, atualização e CLI

## Requisitos

- Ubuntu/Linux x86_64 com Julia **1.13.3** instalada separadamente.
- Python 3 para executar `tools/install.py` e `tools/uninstall.py`; PythonCall só é necessário se o programa importar Python.
- Acesso às dependências declaradas em `Project.toml` e fixadas em `Manifest.toml` na primeira instalação.

Na raiz do clone:

```bash
export ABT_JULIA=/caminho/para/julia-1.13.3/bin/julia
python3 tools/install.py
~/.local/bin/abt doctor
```

O instalador coloca ABT em `~/.local/share/abt` e cria `~/.local/bin/abt`. Use `python3 tools/install.py` novamente para atualizar. Para remover, execute `python3 tools/uninstall.py` a partir de uma cópia do repositório. O instalador não altera o `PATH`; inclua `~/.local/bin` manualmente se necessário. Sem instalação, use `bin/abt` na raiz do clone.

## Primeiro programa

```bash
printf 'mostrar "Olá, mundo!"\n' > ola.abt
bin/abt run ola.abt
bin/abt check ola.abt
```

Saídas esperadas: `Olá, mundo!` e `Programa ABT válido.`. `check` analisa sem executar operações nem carregar pacotes opcionais.

| Comando | Efeito |
|---|---|
| `abt arquivo.abt`, `abt run arquivo.abt`, `abt executar arquivo.abt` | Executa no interpretador. |
| `abt check arquivo.abt`, `abt verificar arquivo.abt` | Faz análise léxica, sintática e semântica. |
| `abt operacoes` | Lista as operações modulares registradas. |
| `abt doctor` | Confere instalação e Julia. |
| `abt --help`, `abt --version` | Ajuda e versão; `--ajuda` e `--versao` são equivalentes. |
| `abt --depurar run arquivo.abt` | Inclui exceção técnica e pilha no diagnóstico. |

Saída 0 significa sucesso; 1 indica erro de compilação ou execução; 2 indica uso incorreto, arquivo ausente ou ambiente incompatível. `ABT_JULIA_COMPILE=all abt run arquivo.abt` troca o modo de compilação Julia; `min` é o padrão. O programa ABT e sua semântica não mudam.

Se `doctor` disser que Julia não foi encontrada, ajuste `ABT_JULIA` ou o `PATH`. Se indicar versão incompatível, selecione exatamente Julia 1.13.3. Para falhas de pacote, resolva as dependências Julia no ambiente do projeto; a mensagem com `--depurar` inclui a causa técnica.
