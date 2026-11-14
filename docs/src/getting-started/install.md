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

Saída 0 significa sucesso; 1 indica erro de compilação ou execução; 2 indica uso incorreto, arquivo ausente ou ambiente incompatível.

## Perfis de execução

O perfil decide como o Julia compila o programa. Ele nunca muda o resultado: saídas, erros e códigos de saída são idênticos em todos os perfis (há testes para isso).

| Perfil | Como usar | Quando |
|---|---|---|
| `padrao` | nada a fazer (é o padrão desde a 0.15.0) | Recomendado para tudo: programas curtos iniciam tão rápido quanto no `rapido`, e operações científicas (FASTA, FASTQ, alinhamento) rodam com código compilado. |
| `rapido` | `abt --perfil rapido run arquivo.abt` | Só se a menor latência possível em programas muito curtos importar mais que qualquer outra coisa. Operações científicas ficam dezenas a centenas de vezes mais lentas. |

A opção pode vir em qualquer posição (`abt run arquivo.abt --perfil rapido` também funciona) e aceita a forma `--perfil=rapido`.

**Variável de ambiente.** `ABT_JULIA_COMPILE` continua aceita e escolhe diretamente o modo de compilação do Julia: `yes` (o mesmo do perfil `padrao`), `min` (o mesmo do `rapido`), `all` ou `no`. **Precedência:** `--perfil` na linha de comando, depois `ABT_JULIA_COMPILE`, depois o perfil `padrao`. Valores inválidos encerram com código 2 e uma mensagem; nada é executado. `abt doctor` mostra o modo efetivo e de onde ele veio.

Até a 0.14.0 o padrão era `--compile=min`. A mudança é só de desempenho: quem definia `ABT_JULIA_COMPILE=min` continua com o comportamento anterior. Medições e metodologia: `docs/RELATORIO_DESEMPENHO_0150.md`.

Se `doctor` disser que Julia não foi encontrada, ajuste `ABT_JULIA` ou o `PATH`. Se indicar versão incompatível, selecione exatamente Julia 1.13.3. Para falhas de pacote, resolva as dependências Julia no ambiente do projeto; a mensagem com `--depurar` inclui a causa técnica.
