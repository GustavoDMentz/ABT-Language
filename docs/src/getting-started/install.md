# Instalação, atualização e CLI

## Instalação em um comando (Linux x86_64)

```bash
curl -fsSL https://github.com/GustavoDMentz/ABT-Language/releases/latest/download/instalar.sh | sh
```

O pacote já traz a Julia 1.13.3 e todos os pacotes: **não é preciso instalar Julia nem Python, nem usar `sudo`**. O instalador confere a soma SHA-256, coloca a ABT em `~/.local/share/abt`, cria `~/.local/bin/abt` e não toca no seu `~/.julia`.

- **Requisitos:** Linux x86_64, `tar`, `xz`, `sha256sum`, `curl` ou `wget` e cerca de 2 GB livres. O download tem cerca de 200 MB.
- **Primeira instalação:** leva alguns minutos, porque os pacotes são pré-compilados para o seu computador (uma única vez).
- **PATH:** o instalador não altera o `PATH`. Se `~/.local/bin` não estiver nele, o instalador avisa como incluir.
- **Sem internet:** baixe o pacote `abt-X.Y.Z-linux-x86_64.tar.xz` e o `.sha256` da página de releases e execute `sh instalar.sh --arquivo abt-X.Y.Z-linux-x86_64.tar.xz`.
- **Integridade e procedência:** o instalador só baixa por HTTPS e confere a soma SHA-256. Um `--arquivo` sem o `.sha256` ao lado é recusado (use `--sha256 HEX`, ou `--sem-verificacao` se aceita o risco). A soma vem da mesma release do pacote; para confirmar também que ele foi construído pelo workflow do repositório, use `--verificar-atestacao` (exige o GitHub CLI, `gh`).

```bash
abt doctor
```

`abt doctor` informa que a Julia usada é a embutida. Quem define `ABT_JULIA` continua usando a própria Julia.

| Comando | Efeito |
|---|---|
| `abt atualizar` | Baixa e instala a versão mais recente; se algo falhar, a instalação anterior é restaurada. |
| `abt reparar` | Pré-compila de novo. Use se a pasta da instalação foi movida (o `abt` avisa). |
| `abt desinstalar` | Remove a ABT e o comando `abt`, após confirmação (`--sim` dispensa). |

Esses três comandos só existem na instalação integrada. Detalhes de arquitetura, medições e limites: `docs/RELATORIO_INSTALADOR_INTEGRADO.md`.

## Instalação em um comando (Windows 10/11 x64)

No PowerShell (não precisa ser administrador):

```powershell
irm https://raw.githubusercontent.com/GustavoDMentz/ABT-Language/main/tools/instalar.ps1 | iex
```

Como no Linux, o pacote traz a Julia 1.13.3 e todos os pacotes: **não é preciso instalar Julia nem Python**. O instalador confere a soma SHA-256, instala em `%LOCALAPPDATA%\ABT`, adiciona a pasta `bin` ao `PATH` do **usuário** (abra um novo terminal depois) e não toca em nenhuma Julia que você já tenha.

- **Requisitos:** Windows 10 (1803) ou 11 de 64 bits e alguns GB livres. O download tem cerca de 330 MB.
- **Primeira instalação:** leva alguns minutos, porque os pacotes são pré-compilados para o seu computador (uma única vez).
- **Sem alterar o PATH:** defina `$env:ABT_SEM_PATH = '1'` antes do comando; o instalador diz qual pasta você deve adicionar.
- **Sem internet:** baixe `abt-X.Y.Z-windows-x86_64.zip` e o `.sha256` da página de releases e use `$env:ABT_ARQUIVO = 'C:\caminho\abt-X.Y.Z-windows-x86_64.zip'` antes do comando.
- **Integridade e procedência:** o instalador só baixa por HTTPS e confere a soma SHA-256. Um `ABT_ARQUIVO` sem o `.sha256` ao lado é recusado (defina `$env:ABT_SHA256`, ou `$env:ABT_SEM_VERIFICACAO = '1'` se aceita o risco). Para confirmar também que o pacote foi construído pelo workflow do repositório, defina `$env:ABT_VERIFICAR_ATESTACAO = '1'` (exige o GitHub CLI, `gh`). O `abt.cmd` não deve ser chamado por outros programas com argumentos vindos de fontes não confiáveis.
- **Outro lugar:** `$env:ABT_PREFIXO = 'D:\ferramentas\abt'`.

Os comandos `abt`, `abt doctor`, `abt atualizar`, `abt reparar` e `abt desinstalar` funcionam como no Linux. Diferenças no Windows: `--perfil` só é reconhecido como **primeiro** argumento (`abt --perfil rapido run arquivo.abt`), as mensagens do lançador saem sem acentos, e `abt desinstalar` termina a remoção da pasta alguns segundos depois de devolver o prompt. Dois exemplos da documentação gravam em `/tmp/...`; no Windows isso vira a pasta `\tmp` da unidade atual, que precisa existir (`mkdir \tmp`).

## Instalação a partir do código-fonte

Para desenvolver a ABT, use um clone do repositório com uma Julia instalada por você:

- Ubuntu/Linux x86_64 com Julia **1.13.3** instalada separadamente.
- Python 3 para executar `tools/install.py` e `tools/uninstall.py`; PythonCall só é necessário se o programa importar Python.
- Acesso às dependências declaradas em `Project.toml` e fixadas em `Manifest.toml` na primeira instalação.

Na raiz do clone:

```bash
export ABT_JULIA=/caminho/para/julia-1.13.3/bin/julia
python3 tools/install.py
~/.local/bin/abt doctor
```

O instalador coloca ABT em `~/.local/share/abt` e cria `~/.local/bin/abt`. Use `python3 tools/install.py` novamente para atualizar. Para remover, execute `python3 tools/uninstall.py` a partir de uma cópia do repositório. O instalador não altera o `PATH`; inclua `~/.local/bin` manualmente se necessário. Sem instalação, use `bin/abt` na raiz do clone. Não misture os dois instaladores na mesma pasta: o integrado recusa uma instalação feita por `tools/install.py` e explica como removê-la.

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

Na instalação integrada a Julia vem junto. Na instalação a partir do código, se `doctor` disser que Julia não foi encontrada, ajuste `ABT_JULIA` ou o `PATH`. Se indicar versão incompatível, selecione exatamente Julia 1.13.3. Para falhas de pacote, resolva as dependências Julia no ambiente do projeto; a mensagem com `--depurar` inclui a causa técnica.
