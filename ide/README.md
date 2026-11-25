# ABT IDE

IDE mínima para escrever e executar programas ABT no navegador. Funciona em **Linux, macOS e Windows** e só usa a biblioteca padrão do Python (3.8 ou superior).

## Requisitos

- Python 3.8+.
- A ABT instalada (`abt --version`). A IDE procura o comando no `PATH`, em `ABT_BIN` e na pasta padrão da instalação (`~/.local/bin/abt` no Linux/macOS, `%LOCALAPPDATA%\ABT\bin\abt.cmd` no Windows).

## Como abrir

Linux e macOS:

```bash
python3 ide/abt_ide.py
```

Windows: dê dois cliques em `ide\abrir_ide.bat` ou use `py -3 ide\abt_ide.py`.

O navegador abre em `http://127.0.0.1:8765`. Opções: `--porta N` e `--sem-navegador`.

## O que tem

- Editor com destaque de sintaxe, números de linha e indentação automática.
- **Executar** (`Ctrl+Enter`, `abt run`) e **Verificar** (`Ctrl+Shift+Enter`, `abt check`). Erros com posição (`linha:coluna`) viram links para a linha.
- Novo, Abrir…, Salvar (baixa o `.abt`) e **Baixar .txt** (salva a saída do programa; `# arquivo: nome.txt` na primeira linha define o nome).
- Menu de exemplos (`ide/exemplos/*.abt`): núcleo da linguagem, estatística, tabelas, ensaio clínico, regressão, DNA/proteína, FASTQ e uma ficha para preencher e baixar como `.txt`. Os dados usados ficam em `ide/exemplos/dados/` e aparecem para o programa como `dados/arquivo`.

Para adicionar um exemplo, salve um `.abt` em `ide/exemplos/` com um comentário na primeira linha (vira o título no menu).

## Segurança

Executar um programa ABT roda código na sua máquina, com os seus privilégios. Por isso o servidor escuta só em `127.0.0.1`, recusa `Host` diferente e exige um token gerado a cada execução. Não exponha a porta em rede. Cada execução usa uma pasta temporária, com limite de 60 s.

## Testes

```bash
python3 -m unittest discover -s ide -p "test_*.py"
```

Rodam no CI em Linux e Windows (`.github/workflows/ide.yml`) e não precisam da ABT instalada: usam um `abt` de mentira.
