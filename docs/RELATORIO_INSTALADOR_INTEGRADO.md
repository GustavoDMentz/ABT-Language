# Instalador integrado da ABT (Linux x86_64 e Windows x64)

Objetivo: instalar a ABT **sem** que a pessoa baixe a Julia separadamente.

```bash
curl -fsSL https://github.com/GustavoDMentz/ABT-Language/releases/latest/download/instalar.sh | sh
```

O comando baixa um pacote com a Julia 1.13.3, a ABT e os pacotes Julia, confere a soma SHA-256, instala em `~/.local/share/abt` (sem `sudo`, sem Python, sem tocar no `~/.julia`) e cria o comando `~/.local/bin/abt`.

## Comandos

| Comando | O que faz |
|---|---|
| `abt atualizar` | Baixa e instala a versão mais recente. Se algo falhar, a instalação anterior é restaurada. |
| `abt reparar` | Pré-compila de novo. Necessário se a pasta da instalação foi movida. |
| `abt desinstalar [--sim]` | Remove a ABT e o link do comando. Não toca no `~/.julia`. |
| `abt doctor` | Mostra se a Julia usada é a embutida ou uma externa. |

Opções do `tools/instalar.sh`: `--prefixo`, `--bin`, `--versao`, `--arquivo` (instalação sem internet, com `--sha256` ou um `.sha256` ao lado), `--forcar`.

A Julia embutida tem prioridade. Quem define `ABT_JULIA` continua usando a sua própria Julia, como antes.

## Arquitetura

```text
~/.local/share/abt/
  bin/abt                  lançador (usa runtime/ e depot/ quando existem)
  runtime/julia/           Julia 1.13.3 oficial, sem alterações
  depot/                   pacotes e artefatos (JULIA_DEPOT_PATH privado, modo offline)
  src/ Project.toml Manifest.toml ABT.packages.toml
  libexec/instalar.sh      atende atualizar, reparar e desinstalar
  .abt-install.json        marcador (schema 2): versão, plataforma, prefixo, pasta do comando
  .abt-prefixo             caminho em que os caches foram gerados
```

O pacote publicado **não** contém caches pré-compilados. O instalador os gera no destino.

## Por que pré-compilar no destino (medição da Fase 0)

Em Ubuntu x86_64, com 4 núcleos:

| Experimento | Resultado |
|---|---|
| Mover só o depot | caches continuam válidos |
| Mover só o código da ABT | só o cache do próprio ABT invalida (cerca de 15 s) |
| Mover a Julia | invalida os caches de todos os pacotes |
| Primeira execução após mover tudo | 3 min 37 s (recompila 182 pacotes) |

Como o caminho da Julia muda de usuário para usuário, não dá para entregar o depot pré-compilado. A instalação leva alguns minutos, uma vez. O lançador avisa quando detecta que a pasta foi movida (`abt reparar`).

Instalação somente leitura não funciona sem caches válidos: a Julia grava arquivos em `depot/compiled` ao recompilar.

## Tamanhos (ABT 0.15.0)

| Item | Valor |
|---|---|
| Download (`.tar.xz`) | cerca de 205 MB |
| Instalado | cerca de 1,6 GB (Julia 1,1 GB, depot 0,5 GB) |
| Pré-compilação no destino | cerca de 3,5 min (4 núcleos) |
| `abt --version` / `mostrar 1` depois de instalado | 0,2 s / 0,4 s |

## Como o pacote é gerado e publicado

- `tools/construir_bundle.sh` monta o pacote (baixa a Julia com SHA-256 fixado, ou usa `--julia-dir`), instancia o depot sem pré-compilar e remove registro e caches.
- `.github/workflows/release.yml`, ao criar a tag `vX.Y.Z` (igual à versão de `Project.toml`): roda `tests/test_bundle_installer.py`, constrói o pacote, instala em contêineres limpos (Ubuntu 22.04 e 24.04, Debian 12, Fedora 40) como usuário comum, executa os exemplos de `docs/examples` e publica o pacote, o `.sha256`, `VERSION` e `instalar.sh` na release.
- `tests/test_bundle_installer.py` usa uma Julia falsa e cobre integridade, troca atômica com rollback, conflitos de link, atualização, reparo e desinstalação.

## Licenças e verificação de origem

- O pacote inclui `THIRD_PARTY_NOTICES.md`, gerado a partir do `Manifest.toml`: lista a Julia e os pacotes com versão e indica onde está o texto de cada licença (`runtime/julia/LICENSE.md`, `depot/packages/*/*/LICENSE*` e `depot/artifacts/*/share/licenses`).
- O workflow de release gera um atestado de procedência do pacote (`actions/attest-build-provenance`), verificável com `gh attestation verify <arquivo> --repo GustavoDMentz/ABT-Language`. Esse passo ainda não foi exercitado (depende da primeira release) e não bloqueia a publicação se falhar. A integridade do download continua garantida pelo SHA-256.

## Windows

```powershell
irm https://raw.githubusercontent.com/GustavoDMentz/ABT-Language/main/tools/instalar.ps1 | iex
```

- `bin/abt.cmd` é o lançador (Julia e depot embutidos, `--perfil`, `doctor`, `atualizar`, `reparar`, `desinstalar`). `tools/instalar.ps1` instala, atualiza, repara e desinstala; `tools/construir_bundle.ps1` monta o `.zip`.
- Instala em `%LOCALAPPDATA%\ABT` e acrescenta `bin` ao `PATH` **do usuário** (não é preciso administrador). Sem `-ExecutionPolicy`: o comando de instalação baixa texto e o executa em memória, e o `abt.cmd` chama o PowerShell com `-ExecutionPolicy Bypass` só para manutenção.
- Os arquivos `.ps1` e `.cmd` são ASCII de propósito: o Windows PowerShell 5.1 e o `cmd` leem arquivos sem BOM na página de código local. O `abt.cmd` põe o console em UTF-8 enquanto roda e restaura a página de código ao sair.
- O instalador baixa com `curl.exe` (incluído no Windows 10 1803+) e extrai com o `tar.exe` do sistema (bsdtar), por isso não usa `Expand-Archive`, que é lento para 1,5 GB.
- Medidas no runner `windows-latest`: pacote de cerca de 300 MB; construção do pacote em cerca de 4 min; pré-compilação no destino em cerca de 4 min.
- O `abt.cmd` em execução não pode ser apagado por `abt desinstalar` (o `cmd.exe` leria a linha seguinte de um arquivo inexistente); o script apaga todo o resto e agenda a remoção final da pasta para poucos segundos depois.
- Limites: `--perfil` só como primeiro argumento; mensagens do lançador sem acentos; Windows ARM roda o pacote x64 por emulação (não testado); caminhos muito longos dependem do suporte do Windows (a instalação em `%LOCALAPPDATA%\ABT` cabe com folga no limite de 260 caracteres); antivírus podem examinar a pré-compilação e deixá-la mais lenta.
- **macOS:** não é suportado por enquanto. Binários sem assinatura e notarização são bloqueados pelo Gatekeeper, e assinar exige conta paga da Apple.
- Teste: `tests/windows_instalacao.ps1` (Windows PowerShell 5.1, sem Julia no `PATH`) instala o pacote em uma pasta com espaço e acentos, roda os exemplos de `docs/examples`, confere saída em UTF-8, perfis, atualização forçada por cima, mover a pasta e `abt reparar`, e desinstalação com limpeza do `PATH`. O workflow `release.yml` o executa a cada tag e sob demanda (`plataforma=windows`; com `publicar_em=vX.Y.Z` anexa os arquivos a uma release existente).

## Limites conhecidos

- Só Linux x86_64. macOS e Windows ficam para a Fase 2.
- O instalador exige `tar`, `xz`, `sha256sum` e `curl` ou `wget`.
- A pré-compilação exige espaço em disco (cerca de 2 GB) e alguns minutos; sem rede, use `--arquivo`.
- Gráficos (Cairo) precisam de fontes no sistema para desenhar texto; os contêineres do workflow instalam `fontconfig` e uma fonte, e essa dependência ainda não foi verificada em uma máquina sem fontes.
- PythonCall continua opcional e não faz parte do pacote.
- O `tools/install.py` (instalação a partir do código-fonte, exige Julia externa) continua disponível para desenvolvimento.
- O workflow de release ainda não foi executado no GitHub; o fluxo foi validado localmente com a Julia real num ambiente isolado.
