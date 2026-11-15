# Instalador integrado da ABT (Linux x86_64)

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

## Limites conhecidos

- Só Linux x86_64. macOS e Windows ficam para a Fase 2.
- O instalador exige `tar`, `xz`, `sha256sum` e `curl` ou `wget`.
- A pré-compilação exige espaço em disco (cerca de 2 GB) e alguns minutos; sem rede, use `--arquivo`.
- Gráficos (Cairo) precisam de fontes no sistema para desenhar texto; os contêineres do workflow instalam `fontconfig` e uma fonte, e essa dependência ainda não foi verificada em uma máquina sem fontes.
- PythonCall continua opcional e não faz parte do pacote.
- O `tools/install.py` (instalação a partir do código-fonte, exige Julia externa) continua disponível para desenvolvimento.
- O workflow de release ainda não foi executado no GitHub; o fluxo foi validado localmente com a Julia real num ambiente isolado.
